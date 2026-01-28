import AppKit
import MacSnapCore

/// Window picker overlay for selecting a window to capture
public class WindowPickerController {
    private var overlayWindows: [WindowHighlightOverlay] = []
    private var frozenBackgroundWindows: [FrozenBackgroundWindow] = []
    private var escapeMonitor: Any?
    private var globalMouseMonitor: Any?
    private var isCleanedUp = false

    public var onWindowSelected: ((WindowInfo) -> Void)?
    public var onCancel: (() -> Void)?

    public init() {}

    public func startPicking() {
        let windows = CaptureEngine.shared.getWindows()
        let config = ConfigManager.shared.config

        guard !windows.isEmpty else {
            Logger.debug("No windows available to pick")
            onCancel?()
            return
        }

        // Get pre-captured images to show as frozen background (preserves hover states visually)
        // Only use if preserveHoverStates is enabled AND we have valid images
        var preCapturedImages: [CGDirectDisplayID: CGImage] = [:]
        if config.capture.preserveHoverStates {
            // Validate that pre-captured images are not blank (permission issue)
            for (displayID, image) in HotkeyManager.shared.pendingCapturedImages {
                let displayBounds = CGDisplayBounds(displayID)
                if image.width > 0 && image.height > 0 &&
                   CGFloat(image.width) >= displayBounds.width {
                    preCapturedImages[displayID] = image
                }
            }
        }

        // Create frozen background windows for each screen (only if we have valid images)
        if !preCapturedImages.isEmpty {
            for screen in NSScreen.screens {
                let displayID = getDisplayID(for: screen)
                let frozenImage = preCapturedImages[displayID]

                let bgWindow = FrozenBackgroundWindow(screen: screen, frozenBackground: frozenImage)
                bgWindow.orderFrontRegardless()
                frozenBackgroundWindows.append(bgWindow)
            }
        }

        // Create highlight overlays for each window
        for windowInfo in windows {
            guard let overlay = WindowHighlightOverlay(windowInfo: windowInfo) else {
                continue
            }
            overlay.onClick = { [weak self] info in
                self?.selectWindow(info)
            }
            overlay.show()
            overlayWindows.append(overlay)
        }

        // Monitor for ESC key (local)
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancel()
                return nil
            }
            return event
        }

        // Also add global monitor for ESC when app is not focused
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancel()
            }
        }

        NSCursor.pointingHand.push()
        Logger.debug("Window picker started with \(overlayWindows.count) windows")
    }

    /// Gets the CGDirectDisplayID for an NSScreen
    private func getDisplayID(for screen: NSScreen) -> CGDirectDisplayID {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return screenNumber ?? CGMainDisplayID()
    }

    private func selectWindow(_ windowInfo: WindowInfo) {
        Logger.debug("Window selected: \(windowInfo.displayTitle)")
        // Store callback before cleanup
        let callback = onWindowSelected
        cleanup()
        // Call callback after cleanup is complete
        DispatchQueue.main.async {
            callback?(windowInfo)
        }
    }

    private func cancel() {
        Logger.debug("Window picker cancelled")
        let callback = onCancel
        cleanup()
        DispatchQueue.main.async {
            callback?()
        }
    }

    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true

        NSCursor.pop()

        // Remove monitors first
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }

        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }

        // Close overlay windows
        let windows = overlayWindows
        overlayWindows.removeAll()

        for overlay in windows {
            overlay.orderOut(nil)
        }

        // Close frozen background windows
        let bgWindows = frozenBackgroundWindows
        frozenBackgroundWindows.removeAll()

        for bgWindow in bgWindows {
            bgWindow.orderOut(nil)
        }
    }

    deinit {
        if !isCleanedUp {
            cleanup()
        }
    }
}

/// Overlay window that highlights a single window
class WindowHighlightOverlay: NSWindow {
    let windowInfo: WindowInfo
    var onClick: ((WindowInfo) -> Void)?

    init?(windowInfo: WindowInfo) {
        self.windowInfo = windowInfo

        // Validate bounds
        guard windowInfo.bounds.width > 0 && windowInfo.bounds.height > 0 else {
            return nil
        }

        // Multi-monitor coordinate conversion:
        //
        // Window bounds from CGWindowListCopyWindowInfo are in CG coordinates:
        // - Origin at TOP-LEFT of primary display
        // - Y increases DOWNWARD
        //
        // NSWindow frames use NS coordinates:
        // - Origin at BOTTOM-LEFT of primary display
        // - Y increases UPWARD
        //
        // Conversion formula: nsY = primaryScreenHeight - cgY - windowHeight

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return nil
        }

        // Primary screen is the one containing the menu bar (origin at 0,0 in NS coordinates)
        // In NS coordinates, primary screen always has origin.y = 0
        let primaryScreen = screens.first!
        let primaryHeight = primaryScreen.frame.height

        // Convert CG coordinates to NS coordinates
        let cgBounds = windowInfo.bounds
        let nsY = primaryHeight - cgBounds.origin.y - cgBounds.height

        let frame = CGRect(
            x: cgBounds.origin.x,
            y: nsY,
            width: cgBounds.width,
            height: cgBounds.height
        )

        // Validate converted frame
        guard frame.width > 0 && frame.height > 0 else {
            return nil
        }

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Create content view safely
        let highlightView = HighlightView(frame: NSRect(origin: .zero, size: frame.size))
        highlightView.windowInfo = windowInfo
        highlightView.onClick = { [weak self] in
            guard let self = self else { return }
            self.onClick?(self.windowInfo)
        }
        self.contentView = highlightView
    }

    func show() {
        self.orderFront(nil)
    }

    override var canBecomeKey: Bool { true }
}

/// View that displays window highlight and info
class HighlightView: NSView {
    var windowInfo: WindowInfo?
    var onClick: (() -> Void)?
    var isHovered = false

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard bounds.width > 0 && bounds.height > 0 else { return }

        // Draw highlight overlay
        let overlayColor = isHovered
            ? NSColor.systemBlue.withAlphaComponent(0.4)
            : NSColor.systemBlue.withAlphaComponent(0.15)

        overlayColor.setFill()
        bounds.fill()

        // Draw border
        let borderColor = isHovered
            ? NSColor.systemBlue
            : NSColor.systemBlue.withAlphaComponent(0.5)

        borderColor.setStroke()
        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        borderPath.lineWidth = isHovered ? 3 : 2
        borderPath.stroke()

        // Draw window title label
        guard let info = windowInfo, bounds.width > 40 && bounds.height > 30 else { return }

        let labelText = info.displayTitle
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]

        let textSize = labelText.size(withAttributes: attrs)
        let padding: CGFloat = 6
        let maxLabelWidth = bounds.width - 20
        let labelWidth = min(textSize.width + padding * 2, maxLabelWidth)
        let labelHeight = textSize.height + padding

        guard labelWidth > 0 && labelHeight > 0 else { return }

        let labelRect = CGRect(
            x: (bounds.width - labelWidth) / 2,
            y: (bounds.height - labelHeight) / 2,
            width: labelWidth,
            height: labelHeight
        )

        // Label background
        NSColor.black.withAlphaComponent(0.75).setFill()
        let labelPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        labelPath.fill()

        // Label text
        let textRect = CGRect(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + (labelHeight - textSize.height) / 2,
            width: labelWidth - padding * 2,
            height: textSize.height
        )

        let truncatedText = truncateText(labelText, toWidth: textRect.width, attributes: attrs)
        truncatedText.draw(in: textRect, withAttributes: attrs)
    }

    private func truncateText(_ text: String, toWidth width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> String {
        guard width > 0 else { return "" }
        var truncated = text
        while truncated.size(withAttributes: attributes).width > width && truncated.count > 4 {
            truncated = String(truncated.dropLast(4)) + "..."
        }
        return truncated
    }
}

/// Fullscreen window that shows frozen background to preserve hover states visually
class FrozenBackgroundWindow: NSWindow {
    init(screen: NSScreen, frozenBackground: CGImage?) {
        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.setFrame(frame, display: false)
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) - 1) // Below highlight overlays
        self.isOpaque = frozenBackground != nil
        self.backgroundColor = frozenBackground != nil ? .black : .clear
        self.ignoresMouseEvents = true // Let clicks through to highlight overlays
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let bgView = FrozenBackgroundView(frame: NSRect(origin: .zero, size: frame.size))
        bgView.frozenBackground = frozenBackground
        self.contentView = bgView
    }
}

/// View that displays the frozen background image with dimming
class FrozenBackgroundView: NSView {
    var frozenBackground: CGImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let frozenImage = frozenBackground {
            // Create NSImage with correct size (in points, not pixels)
            // This ensures proper Retina handling and coordinate conversion
            let nsImage = NSImage(size: bounds.size)
            nsImage.addRepresentation(NSBitmapImageRep(cgImage: frozenImage))

            // Draw the image - NSImage handles coordinate conversion automatically
            nsImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1.0)

            // Draw semi-transparent dimming overlay
            NSColor.black.withAlphaComponent(0.2).setFill()
            bounds.fill()
        } else {
            // Fallback: semi-transparent overlay
            NSColor.black.withAlphaComponent(0.2).setFill()
            bounds.fill()
        }
    }
}
