import AppKit
import MacSnapCore

/// Floating preview thumbnail that appears after capture
/// - Click: Opens larger preview for editing
/// - Drag: Dismisses the thumbnail
/// - Two-finger swipe: Dismisses the thumbnail
public class CapturePreviewWindow: NSWindow {
    private let imageView: NSImageView
    private let captureResult: CaptureResult
    private var dismissTimer: Timer?
    private let duration: Double
    private var isDismissing = false

    private let thumbnailSize: NSSize
    private let screenPadding: CGFloat = 20

    // Drag tracking
    private var dragStartLocation: NSPoint?
    private var initialWindowFrame: NSRect?
    private var isDragging = false
    private let dismissThreshold: CGFloat = 80

    // Global event monitors for drag without focus
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    public var onDismiss: ((CapturePreviewAction) -> Void)?

    public enum CapturePreviewAction {
        case save
        case edit
        case delete
    }

    public init(result: CaptureResult, duration: Double = 5.0) {
        self.captureResult = result
        self.duration = duration

        let nsImage = NSImage(cgImage: result.image, size: NSSize(
            width: result.image.width,
            height: result.image.height
        ))

        let imageAspect = CGFloat(result.image.width) / CGFloat(result.image.height)

        // Thumbnail size
        let thumbMaxWidth: CGFloat = 140
        let thumbMaxHeight: CGFloat = 100
        var thumbWidth = thumbMaxWidth
        var thumbHeight = thumbWidth / imageAspect
        if thumbHeight > thumbMaxHeight {
            thumbHeight = thumbMaxHeight
            thumbWidth = thumbHeight * imageAspect
        }
        self.thumbnailSize = NSSize(width: thumbWidth, height: thumbHeight)

        // Create image view
        imageView = NSImageView(frame: NSRect(origin: .zero, size: thumbnailSize))
        imageView.image = nsImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true

        // Position in bottom-right corner
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowFrame = NSRect(
            x: screenFrame.maxX - thumbnailSize.width - screenPadding,
            y: screenFrame.minY + screenPadding,
            width: thumbnailSize.width,
            height: thumbnailSize.height
        )

        super.init(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = false

        // Container view
        let containerView = NSView(frame: NSRect(origin: .zero, size: thumbnailSize))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 10
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.5
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -3)
        containerView.layer?.shadowRadius = 10

        imageView.frame = containerView.bounds.insetBy(dx: 4, dy: 4)
        imageView.autoresizingMask = [.width, .height]
        containerView.addSubview(imageView)

        self.contentView = containerView
    }

    public func show() {
        // Start off-screen
        let finalFrame = self.frame
        var startFrame = finalFrame
        startFrame.origin.x += 60
        self.setFrame(startFrame, display: false)
        self.alphaValue = 0

        self.orderFront(nil)

        // Slide in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(finalFrame, display: true)
            self.animator().alphaValue = 1
        }

        startDismissTimer()
        setupEventMonitors()
    }

    private func setupEventMonitors() {
        // Local monitor for when app is active
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .scrollWheel]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }

        // Global monitor for when app is not active (window still visible)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .scrollWheel]) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func removeEventMonitors() {
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        // Check if mouse is over this window
        guard frame.contains(mouseLocation) || isDragging else { return }

        switch event.type {
        case .leftMouseDown:
            handleMouseDown(at: mouseLocation)
        case .leftMouseDragged:
            handleMouseDragged(to: mouseLocation)
        case .leftMouseUp:
            handleMouseUp(at: mouseLocation)
        case .scrollWheel:
            handleScrollWheel(event)
        default:
            break
        }
    }

    private func handleMouseDown(at location: NSPoint) {
        guard !isDismissing else { return }
        dragStartLocation = location
        initialWindowFrame = self.frame
        isDragging = false
        dismissTimer?.invalidate()
    }

    private func handleMouseDragged(to location: NSPoint) {
        guard let startLocation = dragStartLocation,
              let initialFrame = initialWindowFrame else { return }

        let deltaX = location.x - startLocation.x
        let deltaY = location.y - startLocation.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        // Start dragging after small threshold
        if !isDragging && distance > 3 {
            isDragging = true
        }

        guard isDragging else { return }

        // Move window
        var newFrame = initialFrame
        newFrame.origin.x += deltaX
        newFrame.origin.y += deltaY
        self.setFrame(newFrame, display: true)

        // Fade based on distance
        let fadeProgress = min(1, distance / dismissThreshold)
        self.alphaValue = 1.0 - (fadeProgress * 0.6)
    }

    private func handleMouseUp(at location: NSPoint) {
        guard let startLocation = dragStartLocation else {
            dragStartLocation = nil
            return
        }

        let deltaX = location.x - startLocation.x
        let deltaY = location.y - startLocation.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        if isDragging && distance >= dismissThreshold {
            // Dismiss with swipe
            let direction = CGPoint(x: deltaX / max(distance, 1), y: deltaY / max(distance, 1))
            dismissWithSwipe(direction: direction)
        } else if isDragging {
            // Snap back
            if let initialFrame = initialWindowFrame {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    self.animator().setFrame(initialFrame, display: true)
                    self.animator().alphaValue = 1.0
                } completionHandler: { [weak self] in
                    self?.startDismissTimer()
                }
            }
        } else if !isDragging && distance < 5 {
            // Click - open preview
            openInPreview()
        }

        isDragging = false
        dragStartLocation = nil
        initialWindowFrame = nil
    }

    private func handleScrollWheel(_ event: NSEvent) {
        guard !isDismissing else { return }

        // Two-finger swipe detection
        let threshold: CGFloat = 15
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        if abs(deltaX) > threshold || abs(deltaY) > threshold {
            let magnitude = sqrt(deltaX * deltaX + deltaY * deltaY)
            let direction = CGPoint(
                x: deltaX / magnitude,
                y: -deltaY / magnitude  // Invert for natural direction
            )
            dismissWithSwipe(direction: direction)
        }
    }

    private func openInPreview() {
        dismissTimer?.invalidate()
        dismiss(action: .edit)
    }

    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss(action: .save)
        }
    }

    private func dismissWithSwipe(direction: CGPoint) {
        guard !isDismissing else { return }
        isDismissing = true
        dismissTimer?.invalidate()
        removeEventMonitors()

        let swipeDistance: CGFloat = 150
        var finalFrame = self.frame
        finalFrame.origin.x += direction.x * swipeDistance
        finalFrame.origin.y += direction.y * swipeDistance

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(finalFrame, display: true)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.onDismiss?(.save)
        })
    }

    private func dismiss(action: CapturePreviewAction) {
        guard !isDismissing else { return }
        isDismissing = true
        dismissTimer?.invalidate()
        removeEventMonitors()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            var frame = self.frame
            frame.origin.x += 50
            self.animator().setFrame(frame, display: true)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.onDismiss?(action)
        })
    }

    public func cancelTimer() {
        dismissTimer?.invalidate()
    }

    deinit {
        removeEventMonitors()
    }

    override public var canBecomeKey: Bool { false }  // Don't steal focus
}
