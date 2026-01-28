import AppKit
import MacSnapCore

/// Overlay window that shows countdown before capture
public class TimedCaptureOverlay: NSWindow {
    private var countdownLabel: NSTextField!
    private var remainingSeconds: Int
    private var timer: Timer?
    private var captureMode: CaptureMode

    public var onComplete: ((CaptureMode) -> Void)?
    public var onCancel: (() -> Void)?

    public init(delay: Int, mode: CaptureMode = .fullScreen) {
        self.remainingSeconds = delay
        self.captureMode = mode

        let size = NSSize(width: 200, height: 200)
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            return
        }

        let frame = NSRect(
            x: (screen.frame.width - size.width) / 2,
            y: (screen.frame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupUI()
    }

    private func setupUI() {
        let containerView = NSView(frame: contentView!.bounds)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 20
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor

        // Countdown label
        countdownLabel = NSTextField(labelWithString: "\(remainingSeconds)")
        countdownLabel.font = NSFont.systemFont(ofSize: 72, weight: .bold)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .center
        countdownLabel.frame = NSRect(x: 0, y: 60, width: 200, height: 80)
        containerView.addSubview(countdownLabel)

        // Mode label
        let modeLabel = NSTextField(labelWithString: captureMode.displayName)
        modeLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        modeLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        modeLabel.alignment = .center
        modeLabel.frame = NSRect(x: 0, y: 30, width: 200, height: 20)
        containerView.addSubview(modeLabel)

        // Cancel hint
        let cancelLabel = NSTextField(labelWithString: "Press ESC to cancel")
        cancelLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        cancelLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        cancelLabel.alignment = .center
        cancelLabel.frame = NSRect(x: 0, y: 10, width: 200, height: 16)
        containerView.addSubview(cancelLabel)

        contentView = containerView
    }

    public func startCountdown() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Monitor for ESC
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancel()
                return nil
            }
            return event
        }

        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            complete()
        } else {
            updateDisplay()
        }
    }

    private func updateDisplay() {
        // Animate the countdown
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            countdownLabel.animator().alphaValue = 0.3
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.countdownLabel.stringValue = "\(self.remainingSeconds)"

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                self.countdownLabel.animator().alphaValue = 1.0
            }
        }

        // Play tick sound if enabled
        let config = ConfigManager.shared.config
        if config.capture.soundEnabled {
            NSSound(named: NSSound.Name("Tink"))?.play()
        }
    }

    private func complete() {
        timer?.invalidate()
        timer = nil

        // Brief flash before capture
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.orderOut(nil)
            self.onComplete?(self.captureMode)
        }
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
        orderOut(nil)
        onCancel?()
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
}
