import AppKit
import MacSnapCore

/// Controller that manages area selection across multiple screens
public class AreaSelectorWindow: NSObject {
    private var overlayWindows: [ScreenOverlayWindow] = []
    private var selectionState = SelectionState()
    private var controlPanelWindow: ControlPanelWindow?

    public var onSelection: ((CGRect) -> Void)?
    public var onCancel: (() -> Void)?

    /// Optional preset region to show (in CG coordinates)
    public var presetRegion: CGRect?

    /// When true, capture immediately after selection (no Enter confirmation)
    public var captureImmediately: Bool = false

    /// When true, show dimension input fields in overlay
    public var showDimensionInput: Bool = false

    public override init() {
        super.init()
    }

    func showControlPanel() {
        guard showDimensionInput else { return }

        if controlPanelWindow == nil {
            controlPanelWindow = ControlPanelWindow(selectionState: selectionState)
            controlPanelWindow?.onCapture = { [weak self] in
                self?.captureCurrentSelection()
            }
            controlPanelWindow?.onCancel = { [weak self] in
                self?.handleCancel()
            }
            controlPanelWindow?.onDimensionChange = { [weak self] width, height in
                self?.updateSelectionSize(width: width, height: height)
            }
        }

        controlPanelWindow?.updatePosition()
        controlPanelWindow?.orderFront(nil)
    }

    func hideControlPanel() {
        controlPanelWindow?.orderOut(nil)
    }

    func updateControlPanelPosition() {
        controlPanelWindow?.updatePosition()
    }

    private func captureCurrentSelection() {
        if let rect = selectionState.selectionRectInScreenCoords, rect.width > 5 && rect.height > 5 {
            // Convert to CG coordinates
            guard let primaryScreen = NSScreen.screens.first else { return }
            let primaryHeight = primaryScreen.frame.height
            let cgRect = CGRect(
                x: rect.origin.x,
                y: primaryHeight - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            cleanup()
            onSelection?(cgRect)
        }
    }

    private func updateSelectionSize(width: Double, height: Double) {
        guard let start = selectionState.startScreenPoint else { return }

        let screenBounds = Self.combinedScreenBounds()

        // Cap dimensions to screen size
        var newWidth = min(width, Double(screenBounds.width))
        var newHeight = min(height, Double(screenBounds.height))

        // Calculate initial end point
        var newX = start.x
        var newY = start.y

        // Adjust X position if needed
        if newX + CGFloat(newWidth) > screenBounds.maxX {
            newX = screenBounds.maxX - CGFloat(newWidth)
        }
        if newX < screenBounds.minX {
            newX = screenBounds.minX
            newWidth = min(newWidth, Double(screenBounds.maxX - newX))
        }

        // Adjust Y position if needed
        if newY + CGFloat(newHeight) > screenBounds.maxY {
            newY = screenBounds.maxY - CGFloat(newHeight)
        }
        if newY < screenBounds.minY {
            newY = screenBounds.minY
            newHeight = min(newHeight, Double(screenBounds.maxY - newY))
        }

        selectionState.startScreenPoint = NSPoint(x: newX, y: newY)
        selectionState.currentScreenPoint = NSPoint(x: newX + newWidth, y: newY + newHeight)

        for window in overlayWindows {
            window.contentView?.needsDisplay = true
        }
        updateControlPanelPosition()
    }

    /// Returns the combined bounds of all screens
    static func combinedScreenBounds() -> CGRect {
        var combined = CGRect.zero
        for screen in NSScreen.screens {
            combined = combined.union(screen.frame)
        }
        return combined
    }

    public func startSelection() {
        let config = ConfigManager.shared.config

        selectionState.captureImmediately = captureImmediately
        selectionState.showDimensionInput = showDimensionInput

        // Register with HotkeyManager so CMD+SHIFT+2 can trigger capture
        HotkeyManager.shared.isAreaSelectionActive = true
        HotkeyManager.shared.areaSelectionCaptureHandler = { [weak self] in
            self?.captureCurrentSelection()
        }

        // Get pre-captured images
        var preCapturedImages: [CGDirectDisplayID: CGImage] = [:]
        if config.capture.preserveHoverStates {
            for (displayID, image) in HotkeyManager.shared.pendingCapturedImages {
                let displayBounds = CGDisplayBounds(displayID)
                if image.width > 0 && image.height > 0 &&
                   CGFloat(image.width) >= displayBounds.width {
                    preCapturedImages[displayID] = image
                }
            }
        }

        // If we have a preset region, convert from CG to NS coordinates
        if let cgRect = presetRegion, cgRect.width > 0 && cgRect.height > 0 {
            if let primaryScreen = NSScreen.screens.first {
                let primaryHeight = primaryScreen.frame.height
                let nsY = primaryHeight - cgRect.origin.y - cgRect.height
                let nsRect = CGRect(x: cgRect.origin.x, y: nsY, width: cgRect.width, height: cgRect.height)

                selectionState.startScreenPoint = NSPoint(x: nsRect.minX, y: nsRect.minY)
                selectionState.currentScreenPoint = NSPoint(x: nsRect.maxX, y: nsRect.maxY)
                selectionState.isSelecting = false
                selectionState.hasPresetRegion = true
            }
        }

        // Create overlay windows
        let screens = NSScreen.screens

        for (index, screen) in screens.enumerated() {
            let displayID = getDisplayID(for: screen)
            let frozenImage = preCapturedImages[displayID]

            let overlay = ScreenOverlayWindow(
                screen: screen,
                screenIndex: index,
                selectionState: selectionState,
                controller: self,
                frozenBackground: frozenImage,
                backingScaleFactor: screen.backingScaleFactor
            )
            overlay.onSelectionComplete = { [weak self] rect in
                self?.handleSelection(rect)
            }
            overlay.onCancel = { [weak self] in
                self?.handleCancel()
            }
            overlayWindows.append(overlay)
        }

        for overlay in overlayWindows {
            overlay.orderFrontRegardless()
        }
        overlayWindows.first?.makeKey()

        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()

        // Show control panel immediately if preset region exists
        if selectionState.hasPresetRegion && showDimensionInput {
            showControlPanel()
        }
    }

    private func getDisplayID(for screen: NSScreen) -> CGDirectDisplayID {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return screenNumber ?? CGMainDisplayID()
    }

    private func handleSelection(_ rect: CGRect) {
        cleanup()
        onSelection?(rect)
    }

    private func handleCancel() {
        cleanup()
        onCancel?()
    }

    private func cleanup() {
        // Unregister from HotkeyManager
        HotkeyManager.shared.isAreaSelectionActive = false
        HotkeyManager.shared.areaSelectionCaptureHandler = nil

        NSCursor.pop()
        controlPanelWindow?.orderOut(nil)
        controlPanelWindow = nil
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}

/// Floating control panel window for dimension input
class ControlPanelWindow: NSPanel {
    private let selectionState: SelectionState
    private var widthField: NSTextField!
    private var heightField: NSTextField!

    var onCapture: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDimensionChange: ((Double, Double) -> Void)?

    init(selectionState: SelectionState) {
        self.selectionState = selectionState

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver + 1
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupContent()
    }

    private func setupContent() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 50))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        container.layer?.cornerRadius = 10

        // W: label
        let wLabel = NSTextField(labelWithString: "W:")
        wLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        wLabel.textColor = .white
        wLabel.frame = NSRect(x: 15, y: 15, width: 24, height: 20)
        container.addSubview(wLabel)

        // Width field
        widthField = NSTextField(string: "")
        widthField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        widthField.frame = NSRect(x: 42, y: 12, width: 65, height: 26)
        widthField.alignment = .center
        widthField.bezelStyle = .roundedBezel
        widthField.target = self
        widthField.action = #selector(dimensionChanged)
        container.addSubview(widthField)

        // H: label
        let hLabel = NSTextField(labelWithString: "H:")
        hLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        hLabel.textColor = .white
        hLabel.frame = NSRect(x: 117, y: 15, width: 22, height: 20)
        container.addSubview(hLabel)

        // Height field
        heightField = NSTextField(string: "")
        heightField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        heightField.frame = NSRect(x: 142, y: 12, width: 65, height: 26)
        heightField.alignment = .center
        heightField.bezelStyle = .roundedBezel
        heightField.target = self
        heightField.action = #selector(dimensionChanged)
        container.addSubview(heightField)

        // Capture button
        let button = NSButton(title: "Capture", target: self, action: #selector(captureClicked))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 215, y: 10, width: 65, height: 30)
        container.addSubview(button)

        self.contentView = container
    }

    @objc private func dimensionChanged() {
        guard let width = Double(widthField.stringValue),
              let height = Double(heightField.stringValue),
              width > 0, height > 0 else { return }
        onDimensionChange?(width, height)
    }

    @objc private func captureClicked() {
        onCapture?()
    }

    func updatePosition() {
        guard let rect = selectionState.selectionRectInScreenCoords else { return }

        // Update dimension fields
        widthField.stringValue = "\(Int(rect.width))"
        heightField.stringValue = "\(Int(rect.height))"

        // Position below the selection rectangle
        let panelWidth: CGFloat = 290
        let panelHeight: CGFloat = 50
        var panelX = rect.midX - panelWidth / 2
        var panelY = rect.minY - panelHeight - 20

        // Get screen bounds
        if let screen = NSScreen.main {
            let screenFrame = screen.frame

            // Keep on screen horizontally
            panelX = max(screenFrame.minX + 10, min(panelX, screenFrame.maxX - panelWidth - 10))

            // If no room below, put above
            if panelY < screenFrame.minY + 10 {
                panelY = rect.maxY + 20
            }
        }

        self.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: true)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel?()
        } else if event.keyCode == 36 || event.keyCode == 76 { // Enter
            onCapture?()
        } else if event.keyCode == 19 && event.modifierFlags.contains([.command, .shift]) {
            // CMD+SHIFT+2 - capture current selection
            onCapture?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// Shared selection state
class SelectionState {
    var isSelecting = false
    var startScreenPoint: NSPoint?
    var currentScreenPoint: NSPoint?
    var hasPresetRegion = false
    var captureImmediately = false
    var showDimensionInput = false

    // Corner dragging
    var isDraggingCorner = false
    var activeCorner: Corner?
    var isDraggingRegion = false
    var dragOffset: NSPoint = .zero

    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var selectionRectInScreenCoords: CGRect? {
        guard let start = startScreenPoint, let current = currentScreenPoint else {
            return nil
        }

        // Round to integers to ensure pixel-aligned capture
        // This ensures the captured size matches what the user sees in the dimension panel
        let x = round(min(start.x, current.x))
        let y = round(min(start.y, current.y))
        let width = round(abs(current.x - start.x))
        let height = round(abs(current.y - start.y))

        guard width > 0 && height > 0 else { return nil }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Overlay window for a single screen
class ScreenOverlayWindow: NSWindow {
    let targetScreen: NSScreen
    let screenIndex: Int
    let selectionState: SelectionState
    weak var controller: AreaSelectorWindow?
    private var overlayView: ScreenOverlayView!

    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen, screenIndex: Int, selectionState: SelectionState, controller: AreaSelectorWindow, frozenBackground: CGImage? = nil, backingScaleFactor: CGFloat = 2.0) {
        self.targetScreen = screen
        self.screenIndex = screenIndex
        self.selectionState = selectionState
        self.controller = controller

        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.setFrame(frame, display: false)
        self.level = .screenSaver
        self.isOpaque = frozenBackground != nil
        self.backgroundColor = frozenBackground != nil ? .black : .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        overlayView = ScreenOverlayView(frame: NSRect(origin: .zero, size: frame.size))
        overlayView.screenFrame = frame
        overlayView.selectionState = selectionState
        overlayView.screenIndex = screenIndex
        overlayView.controller = controller
        overlayView.frozenBackground = frozenBackground
        overlayView.backingScaleFactor = backingScaleFactor
        overlayView.onSelectionComplete = { [weak self] rect in
            self?.onSelectionComplete?(rect)
        }
        overlayView.onCancel = { [weak self] in
            self?.onCancel?()
        }

        self.contentView = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// View for a single screen overlay
class ScreenOverlayView: NSView {
    var screenFrame: CGRect = .zero
    var screenIndex: Int = 0
    var selectionState: SelectionState!
    weak var controller: AreaSelectorWindow?
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    var frozenBackground: CGImage?
    var backingScaleFactor: CGFloat = 2.0

    private var dimensionLabel: NSTextField?

    private let handleSize: CGFloat = 12
    private let handleHitArea: CGFloat = 20

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // Dimension label while dragging
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        label.isBezeled = false
        label.drawsBackground = true
        label.isHidden = true
        addSubview(label)
        dimensionLabel = label
    }

    private func cornerAt(_ point: NSPoint) -> SelectionState.Corner? {
        guard let rect = selectionState.selectionRectInScreenCoords else { return nil }

        let viewRect = CGRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: rect.origin.y - screenFrame.origin.y,
            width: rect.width,
            height: rect.height
        )

        let corners: [(SelectionState.Corner, CGPoint)] = [
            (.bottomLeft, CGPoint(x: viewRect.minX, y: viewRect.minY)),
            (.bottomRight, CGPoint(x: viewRect.maxX, y: viewRect.minY)),
            (.topLeft, CGPoint(x: viewRect.minX, y: viewRect.maxY)),
            (.topRight, CGPoint(x: viewRect.maxX, y: viewRect.maxY))
        ]

        for (corner, cornerPoint) in corners {
            let hitRect = CGRect(
                x: cornerPoint.x - handleHitArea/2,
                y: cornerPoint.y - handleHitArea/2,
                width: handleHitArea,
                height: handleHitArea
            )
            if hitRect.contains(point) {
                return corner
            }
        }

        return nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        let windowPoint = event.locationInWindow
        let viewPoint = convert(windowPoint, from: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        // Check for corner drag
        if selectionState.hasPresetRegion {
            if let corner = cornerAt(viewPoint) {
                selectionState.isDraggingCorner = true
                selectionState.activeCorner = corner
                return
            }

            // Check for region drag
            if let rect = selectionState.selectionRectInScreenCoords, rect.contains(screenPoint) {
                selectionState.isDraggingRegion = true
                selectionState.dragOffset = NSPoint(
                    x: screenPoint.x - rect.origin.x,
                    y: screenPoint.y - rect.origin.y
                )
                return
            }

            // Clicking outside - start new selection
            selectionState.hasPresetRegion = false
            controller?.hideControlPanel()
        }

        // Start new selection
        selectionState.isSelecting = true
        selectionState.startScreenPoint = screenPoint
        selectionState.currentScreenPoint = screenPoint
        dimensionLabel?.isHidden = false
        notifyAllOverlays()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }

        let windowPoint = event.locationInWindow
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        if selectionState.isDraggingCorner {
            handleCornerDrag(to: screenPoint)
            return
        }

        if selectionState.isDraggingRegion {
            handleRegionDrag(to: screenPoint)
            return
        }

        guard selectionState.isSelecting else { return }

        // Clamp to screen bounds during initial selection
        let screenBounds = AreaSelectorWindow.combinedScreenBounds()
        var clampedPoint = screenPoint
        clampedPoint.x = max(screenBounds.minX, min(clampedPoint.x, screenBounds.maxX))
        clampedPoint.y = max(screenBounds.minY, min(clampedPoint.y, screenBounds.maxY))

        selectionState.currentScreenPoint = clampedPoint

        if let rect = selectionState.selectionRectInScreenCoords {
            updateDimensionLabel(width: Int(rect.width), height: Int(rect.height), screenPoint: clampedPoint)
        }

        notifyAllOverlays()
    }

    private func handleCornerDrag(to screenPoint: NSPoint) {
        guard let corner = selectionState.activeCorner,
              let rect = selectionState.selectionRectInScreenCoords else { return }

        let screenBounds = AreaSelectorWindow.combinedScreenBounds()
        let minSelectionSize: CGFloat = 10

        // Clamp screen point to screen bounds
        var clampedPoint = screenPoint
        clampedPoint.x = max(screenBounds.minX, min(clampedPoint.x, screenBounds.maxX))
        clampedPoint.y = max(screenBounds.minY, min(clampedPoint.y, screenBounds.maxY))

        var newStart = selectionState.startScreenPoint ?? .zero
        var newEnd = selectionState.currentScreenPoint ?? .zero

        // Ensure start is bottom-left, end is top-right
        let minX = min(rect.minX, rect.maxX)
        let minY = min(rect.minY, rect.maxY)
        let maxX = max(rect.minX, rect.maxX)
        let maxY = max(rect.minY, rect.maxY)

        switch corner {
        case .bottomLeft:
            // Ensure minimum size
            let newX = min(clampedPoint.x, maxX - minSelectionSize)
            let newY = min(clampedPoint.y, maxY - minSelectionSize)
            newStart = NSPoint(x: newX, y: newY)
            newEnd = NSPoint(x: maxX, y: maxY)
        case .bottomRight:
            let newX = max(clampedPoint.x, minX + minSelectionSize)
            let newY = min(clampedPoint.y, maxY - minSelectionSize)
            newStart = NSPoint(x: minX, y: newY)
            newEnd = NSPoint(x: newX, y: maxY)
        case .topLeft:
            let newX = min(clampedPoint.x, maxX - minSelectionSize)
            let newY = max(clampedPoint.y, minY + minSelectionSize)
            newStart = NSPoint(x: newX, y: minY)
            newEnd = NSPoint(x: maxX, y: newY)
        case .topRight:
            let newX = max(clampedPoint.x, minX + minSelectionSize)
            let newY = max(clampedPoint.y, minY + minSelectionSize)
            newStart = NSPoint(x: minX, y: minY)
            newEnd = NSPoint(x: newX, y: newY)
        }

        selectionState.startScreenPoint = newStart
        selectionState.currentScreenPoint = newEnd

        controller?.updateControlPanelPosition()
        notifyAllOverlays()
    }

    private func handleRegionDrag(to screenPoint: NSPoint) {
        guard let rect = selectionState.selectionRectInScreenCoords else { return }

        let screenBounds = AreaSelectorWindow.combinedScreenBounds()

        var newX = screenPoint.x - selectionState.dragOffset.x
        var newY = screenPoint.y - selectionState.dragOffset.y

        // Clamp to keep entire rectangle within screen bounds
        newX = max(screenBounds.minX, min(newX, screenBounds.maxX - rect.width))
        newY = max(screenBounds.minY, min(newY, screenBounds.maxY - rect.height))

        selectionState.startScreenPoint = NSPoint(x: newX, y: newY)
        selectionState.currentScreenPoint = NSPoint(x: newX + rect.width, y: newY + rect.height)

        controller?.updateControlPanelPosition()
        notifyAllOverlays()
    }

    override func mouseUp(with event: NSEvent) {
        if selectionState.isDraggingCorner {
            selectionState.isDraggingCorner = false
            selectionState.activeCorner = nil
            return
        }

        if selectionState.isDraggingRegion {
            selectionState.isDraggingRegion = false
            return
        }

        guard selectionState.isSelecting else { return }

        selectionState.isSelecting = false
        dimensionLabel?.isHidden = true

        guard let screenRect = selectionState.selectionRectInScreenCoords,
              screenRect.width > 5 && screenRect.height > 5 else {
            onCancel?()
            return
        }

        if selectionState.captureImmediately {
            completeSelection(with: screenRect)
            return
        }

        // Show preset and control panel
        selectionState.hasPresetRegion = true
        controller?.showControlPanel()
        notifyAllOverlays()
    }

    private func completeSelection(with screenRect: CGRect) {
        guard let primaryScreen = NSScreen.screens.first else {
            onCancel?()
            return
        }

        let primaryHeight = primaryScreen.frame.height
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: primaryHeight - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )

        onSelectionComplete?(cgRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            selectionState.isSelecting = false
            selectionState.hasPresetRegion = false
            onCancel?()
        } else if event.keyCode == 36 || event.keyCode == 76 { // Enter
            if !selectionState.captureImmediately {
                if let rect = selectionState.selectionRectInScreenCoords, rect.width > 5 && rect.height > 5 {
                    completeSelection(with: rect)
                }
            }
        } else if event.keyCode == 19 && event.modifierFlags.contains([.command, .shift]) {
            // cmd+shift+2 - capture current selection (same as Enter for area mode)
            if !selectionState.captureImmediately {
                if let rect = selectionState.selectionRectInScreenCoords, rect.width > 5 && rect.height > 5 {
                    completeSelection(with: rect)
                }
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw background
        if let frozenImage = frozenBackground {
            let nsImage = NSImage(size: bounds.size)
            nsImage.addRepresentation(NSBitmapImageRep(cgImage: frozenImage))
            nsImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1.0)
            NSColor.black.withAlphaComponent(0.3).setFill()
            bounds.fill()
        } else {
            NSColor.black.withAlphaComponent(0.3).setFill()
            bounds.fill()
        }

        guard let screenRect = selectionState.selectionRectInScreenCoords else { return }

        let viewRect = CGRect(
            x: screenRect.origin.x - screenFrame.origin.x,
            y: screenRect.origin.y - screenFrame.origin.y,
            width: screenRect.width,
            height: screenRect.height
        )

        guard viewRect.intersects(bounds) else { return }

        let clippedRect = viewRect.intersection(bounds)

        // Draw clear selection area
        if let frozenImage = frozenBackground {
            let scaleX = CGFloat(frozenImage.width) / bounds.width
            let scaleY = CGFloat(frozenImage.height) / bounds.height

            let sourceRect = CGRect(
                x: clippedRect.origin.x * scaleX,
                y: CGFloat(frozenImage.height) - (clippedRect.origin.y + clippedRect.height) * scaleY,
                width: clippedRect.width * scaleX,
                height: clippedRect.height * scaleY
            )

            if let croppedImage = frozenImage.cropping(to: sourceRect) {
                let selectionImage = NSImage(size: clippedRect.size)
                selectionImage.addRepresentation(NSBitmapImageRep(cgImage: croppedImage))
                selectionImage.draw(in: clippedRect, from: .zero, operation: .copy, fraction: 1.0)
            }
        } else {
            NSColor.clear.setFill()
            clippedRect.fill(using: .copy)
        }

        // Dashed white border
        NSColor.white.setStroke()
        let borderPath = NSBezierPath(rect: clippedRect)
        borderPath.lineWidth = 2
        borderPath.setLineDash([6, 4], count: 2, phase: 0)
        borderPath.stroke()

        // Draw corner handles
        if selectionState.hasPresetRegion {
            drawCornerHandles(for: viewRect)
        }
    }

    private func drawCornerHandles(for viewRect: CGRect) {
        let corners = [
            CGPoint(x: viewRect.minX, y: viewRect.minY),
            CGPoint(x: viewRect.maxX, y: viewRect.minY),
            CGPoint(x: viewRect.minX, y: viewRect.maxY),
            CGPoint(x: viewRect.maxX, y: viewRect.maxY)
        ]

        for corner in corners {
            if bounds.contains(corner) {
                // White fill with border
                let handleRect = CGRect(
                    x: corner.x - handleSize/2,
                    y: corner.y - handleSize/2,
                    width: handleSize,
                    height: handleSize
                )

                NSColor.white.setFill()
                NSBezierPath(ovalIn: handleRect).fill()

                NSColor.darkGray.setStroke()
                let strokePath = NSBezierPath(ovalIn: handleRect)
                strokePath.lineWidth = 1.5
                strokePath.stroke()
            }
        }
    }

    private func notifyAllOverlays() {
        for window in NSApp.windows {
            if let overlay = window as? ScreenOverlayWindow {
                overlay.contentView?.needsDisplay = true
            }
        }
    }

    private func updateDimensionLabel(width: Int, height: Int, screenPoint: NSPoint) {
        guard let label = dimensionLabel else { return }

        label.stringValue = "  \(width) × \(height)  "
        label.sizeToFit()

        let viewPoint = NSPoint(
            x: screenPoint.x - screenFrame.origin.x,
            y: screenPoint.y - screenFrame.origin.y
        )

        var labelX = viewPoint.x + 15
        var labelY = viewPoint.y + 25

        if labelX + label.frame.width > bounds.maxX - 10 {
            labelX = viewPoint.x - label.frame.width - 15
        }
        if labelY + label.frame.height > bounds.maxY - 10 {
            labelY = viewPoint.y - label.frame.height - 15
        }
        if labelX < 10 { labelX = 10 }
        if labelY < 10 { labelY = 10 }

        label.frame.origin = NSPoint(x: labelX, y: labelY)
    }

}
