import AppKit
import MacSnapCore
import UserNotifications

/// Main application delegate for MacSnap
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    private var preferencesWindow: NSWindow?
    private var areaSelectorWindow: AreaSelectorWindow?
    private var windowPicker: WindowPickerController?
    private var timedCaptureOverlay: TimedCaptureOverlay?
    private var capturePreviewWindow: CapturePreviewWindow?

    // Capture state - prevents multiple simultaneous captures
    private var isCaptureInProgress = false

    // File editing state
    private var directoryMonitor: DispatchSourceFileSystemObject?
    private var editingFileURL: URL?
    private var debounceTimer: Timer?

    /// Check if running as a proper app bundle (required for UserNotifications)
    private var isRunningInBundle: Bool {
        return Bundle.main.bundleIdentifier != nil
    }

    // MARK: - Application Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("Application starting...")

        // Setup menu bar
        menuBarController = MenuBarController()
        menuBarController.appDelegate = self
        menuBarController.setup()

        // Register hotkeys
        setupHotkeys()

        // Ensure output directory exists
        do {
            try ConfigManager.shared.ensureOutputDirectoryExists()
        } catch {
            Logger.warning("Could not create output directory: \(error.localizedDescription)")
        }

        // Check permissions
        checkPermissions()

        // Listen for config changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: ConfigManager.configDidChangeNotification,
            object: nil
        )

        Logger.info("Application ready")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        stopWatchingDirectory()
        HotkeyManager.shared.unregisterAll()
    }

    /// Called when user tries to open the app while it's already running
    /// (e.g., clicking the app icon in Finder, Spotlight, or Dock)
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Open preferences when user tries to re-open the app
        showPreferences()
        return true
    }

    // Track if we've shown the permission alert this session
    private var hasShownPermissionAlert = false

    // MARK: - Permissions

    private func checkPermissions() {
        let hasScreenRecording = CaptureEngine.shared.hasScreenCapturePermission()
        let hasAccessibility = HotkeyManager.shared.hasAccessibilityPermission()

        Logger.info("Permission check - Screen Recording: \(hasScreenRecording), Accessibility: \(hasAccessibility)")

        // Request both permissions at startup - macOS will show system dialogs for each

        // Request accessibility permission (shows system dialog with prompt)
        if !hasAccessibility {
            Logger.info("Requesting accessibility permission")
            HotkeyManager.shared.requestAccessibilityPermission()
        }

        // Request screen recording permission (shows system dialog via ScreenCaptureKit)
        // On macOS 14 Sonoma+, we MUST use ScreenCaptureKit to register the app in TCC
        // and trigger the permission dialog. We delay slightly to ensure the run loop is active.
        if !hasScreenRecording {
            Logger.info("Scheduling screen recording permission request")
            // Delay to allow accessibility dialog to be shown first, and ensure run loop is active
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Logger.info("Requesting screen recording permission")
                CaptureEngine.shared.requestScreenCapturePermission()
            }
        }

        // Request notification permission
        requestNotificationPermission()
    }

    private func showPermissionsRequiredAlert(needsScreenRecording: Bool, needsAccessibility: Bool) {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"

        var message = "MacSnap needs the following permissions to work:\n\n"
        if needsScreenRecording {
            message += "• Screen Recording - to capture screenshots\n"
        }
        if needsAccessibility {
            message += "• Accessibility - for global keyboard shortcuts\n"
        }
        message += "\nPlease grant these permissions in System Settings, then restart MacSnap."

        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            // Open the appropriate settings panel
            if needsScreenRecording {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            } else if needsAccessibility {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        let manager = HotkeyManager.shared

        manager.setHandler(for: .fullScreen) { [weak self] in
            self?.performCapture(mode: .fullScreen)
        }

        manager.setHandler(for: .area) { [weak self] in
            self?.performCapture(mode: .area)
        }

        manager.setHandler(for: .window) { [weak self] in
            self?.performCapture(mode: .window)
        }

        manager.setHandler(for: .custom) { [weak self] in
            self?.performCapture(mode: .custom)
        }

        manager.registerHotkeys()
        Logger.debug("Hotkeys registered")
    }

    @objc private func configDidChange() {
        HotkeyManager.shared.registerHotkeys()
    }

    // MARK: - Capture Actions

    public func performCapture(mode: CaptureMode) {
        // Prevent multiple simultaneous captures
        guard !isCaptureInProgress else {
            Logger.debug("Capture already in progress, ignoring")
            return
        }

        isCaptureInProgress = true

        switch mode {
        case .fullScreen:
            captureFullScreen()
        case .area:
            startAreaSelection()
        case .window:
            startWindowSelection()
        case .timed:
            performTimedCapture(delay: 5)
        case .custom:
            startAreaSelectionForCustomRegion()
        }
    }

    private func captureCompleted() {
        isCaptureInProgress = false
    }

    private func captureFullScreen() {
        // Capture immediately to preserve hover states and UI
        // No delay needed since there's no overlay to dismiss
        defer { captureCompleted() }
        do {
            let result = try CaptureEngine.shared.captureFullScreen()
            handleCaptureResult(result)
        } catch {
            handleCaptureError(error)
        }
    }

    private func startAreaSelection() {
        let config = ConfigManager.shared.config

        areaSelectorWindow = AreaSelectorWindow()
        areaSelectorWindow?.showDimensionInput = true  // Show W/H input in overlay

        // If area region is already set, show it as preset
        if config.areaRegion.isSet {
            areaSelectorWindow?.presetRegion = config.areaRegion.rect
        }

        areaSelectorWindow?.onSelection = { [weak self] rect in
            self?.areaSelectorWindow = nil

            // Save the selected area region for next time
            var updatedConfig = ConfigManager.shared.config
            updatedConfig.areaRegion.setFromRect(rect)
            ConfigManager.shared.config = updatedConfig

            // Update menu to show new dimensions
            self?.menuBarController.updateMenu()

            // Delay to ensure overlay is fully removed from screen buffer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                defer { self?.captureCompleted() }
                do {
                    let result = try CaptureEngine.shared.captureArea(rect)
                    self?.handleCaptureResult(result)
                } catch {
                    self?.handleCaptureError(error)
                }
            }
        }
        areaSelectorWindow?.onCancel = { [weak self] in
            self?.areaSelectorWindow = nil
            self?.captureCompleted()
        }
        areaSelectorWindow?.startSelection()
    }

    private func startAreaSelectionForCustomRegion() {
        // Custom Region: ALWAYS draw fresh, NEVER save, capture immediately after drawing
        areaSelectorWindow = AreaSelectorWindow()
        areaSelectorWindow?.captureImmediately = true  // No Enter confirmation needed

        areaSelectorWindow?.onSelection = { [weak self] rect in
            self?.areaSelectorWindow = nil

            // DO NOT save - custom region is always fresh
            // Capture immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                defer { self?.captureCompleted() }
                do {
                    let result = try CaptureEngine.shared.captureArea(rect)
                    let customResult = CaptureResult(
                        image: result.image,
                        mode: .custom,
                        captureRect: rect,
                        sourceApp: nil
                    )
                    self?.handleCaptureResult(customResult)
                } catch {
                    self?.handleCaptureError(error)
                }
            }
        }
        areaSelectorWindow?.onCancel = { [weak self] in
            self?.areaSelectorWindow = nil
            self?.captureCompleted()
        }
        areaSelectorWindow?.startSelection()
    }

    private func startWindowSelection() {
        windowPicker = WindowPickerController()
        windowPicker?.onWindowSelected = { [weak self] windowInfo in
            self?.windowPicker = nil
            defer { self?.captureCompleted() }
            do {
                let result = try CaptureEngine.shared.captureWindow(windowInfo.windowID)
                self?.handleCaptureResult(result)
            } catch {
                self?.handleCaptureError(error)
            }
        }
        windowPicker?.onCancel = { [weak self] in
            self?.windowPicker = nil
            self?.captureCompleted()
        }
        windowPicker?.startPicking()
    }

    public func performTimedCapture(delay: Int) {
        timedCaptureOverlay = TimedCaptureOverlay(delay: delay, mode: .fullScreen)
        timedCaptureOverlay?.onComplete = { [weak self] _ in
            self?.timedCaptureOverlay = nil
            defer { self?.captureCompleted() }
            do {
                let result = try CaptureEngine.shared.captureFullScreen()
                self?.handleCaptureResult(result)
            } catch {
                self?.handleCaptureError(error)
            }
        }
        timedCaptureOverlay?.onCancel = { [weak self] in
            self?.timedCaptureOverlay = nil
            self?.captureCompleted()
        }
        timedCaptureOverlay?.startCountdown()
    }

    // MARK: - Capture Result Handling

    private func handleCaptureResult(_ result: CaptureResult) {
        let config = ConfigManager.shared.config

        // Play sound immediately if enabled
        if config.capture.soundEnabled {
            NSSound(named: NSSound.Name("Blow"))?.play()
        }

        // Save file FIRST (so we have file URL for clipboard)
        var savedURL: URL?
        if config.output.fileEnabled {
            do {
                savedURL = try FileWriter.shared.save(result)
                menuBarController.addRecentCapture(savedURL!)
                Logger.debug("File saved to: \(savedURL!.path)")
            } catch {
                Logger.error("Failed to save file: \(error.localizedDescription)")
            }
        }

        // Copy to clipboard WITH file URL (required for clipboard history apps)
        if config.output.clipboardEnabled {
            let success: Bool
            if let fileURL = savedURL {
                success = ClipboardManager.shared.copyImageAndFileToClipboard(result.image, fileURL: fileURL)
            } else {
                success = ClipboardManager.shared.copyToClipboard(result.image)
            }
            if success {
                Logger.debug("Image copied to clipboard")
            } else {
                Logger.error("Failed to copy to clipboard")
            }
        }

        // Show preview if enabled, otherwise just notify
        if config.capture.showPreview {
            showCapturePreview(result, savedURL: savedURL)
        } else if let url = savedURL {
            menuBarController.showCaptureNotification(savedTo: url)
            if config.capture.showNotification {
                showSystemNotification(for: url)
            }
        }
    }

    private func showCapturePreview(_ result: CaptureResult, savedURL: URL?) {
        let config = ConfigManager.shared.config

        capturePreviewWindow = CapturePreviewWindow(
            result: result,
            duration: config.capture.previewDuration
        )

        capturePreviewWindow?.onDismiss = { [weak self] action in
            self?.capturePreviewWindow = nil

            switch action {
            case .save:
                // File already saved, clipboard already set - just show notification
                if let url = savedURL {
                    self?.menuBarController.showCaptureNotification(savedTo: url)
                    if config.capture.showNotification {
                        self?.showSystemNotification(for: url)
                    }
                }
            case .edit:
                self?.openInPreviewForEditing(result, existingURL: savedURL)
            case .delete:
                // Delete the already-saved file
                if let url = savedURL {
                    try? FileManager.default.removeItem(at: url)
                    Logger.debug("Screenshot deleted by user: \(url.lastPathComponent)")
                } else {
                    Logger.debug("Screenshot discarded by user")
                }
            }
        }

        capturePreviewWindow?.show()
    }

    private func openInPreviewForEditing(_ result: CaptureResult, existingURL: URL? = nil) {
        var fileURL: URL

        // Use existing URL if available, otherwise save/create temp
        if let existing = existingURL {
            fileURL = existing
        } else {
            let config = ConfigManager.shared.config
            if config.output.fileEnabled {
                do {
                    fileURL = try FileWriter.shared.save(result)
                    menuBarController.addRecentCapture(fileURL)
                } catch {
                    Logger.error("Failed to save file: \(error.localizedDescription)")
                    fileURL = createTempFile(for: result)
                }
            } else {
                fileURL = createTempFile(for: result)
            }
        }

        editingFileURL = fileURL

        // Start watching for changes
        startWatchingDirectory(fileURL.deletingLastPathComponent())

        // Open in Preview.app
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            if let error = error {
                Logger.error("Failed to open Preview: \(error.localizedDescription)")
                self?.stopWatchingDirectory()
            }
        }

        // Note: Clipboard already has the image from processCapture()
        // checkForEditedFile() will update clipboard when user saves edits
    }

    private func createTempFile(for result: CaptureResult) -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macsnap_edit_\(UUID().uuidString).png")

        let nsImage = NSImage(cgImage: result.image, size: NSSize(
            width: result.image.width,
            height: result.image.height
        ))

        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }

        return fileURL
    }

    // MARK: - File Watching

    private func startWatchingDirectory(_ directoryURL: URL) {
        stopWatchingDirectory()

        let fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.debounceTimer?.invalidate()
            self?.debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.checkForEditedFile()
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        directoryMonitor = source
    }

    private func stopWatchingDirectory() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        directoryMonitor?.cancel()
        directoryMonitor = nil
    }

    private func checkForEditedFile() {
        guard let fileURL = editingFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let modDate = attributes[.modificationDate] as? Date ?? Date.distantPast
            let timeSinceModified = Date().timeIntervalSince(modDate)

            guard timeSinceModified < 5 else { return }

            let imageData = try Data(contentsOf: fileURL)
            guard let nsImage = NSImage(data: imageData) else { return }

            // Use ClipboardManager for consistent single-entry clipboard behavior
            if ClipboardManager.shared.copyImageAndFileToClipboard(nsImage, fileURL: fileURL) {
                Logger.debug("Edited image copied to clipboard")

                if ConfigManager.shared.config.capture.soundEnabled {
                    NSSound(named: NSSound.Name("Blow"))?.play()
                }

                showEditCompleteNotification()
            }
        } catch {
            Logger.error("Error processing edited file: \(error.localizedDescription)")
        }
    }

    // MARK: - Finalize Capture

    private func finalizeCaptureResult(_ result: CaptureResult, skipClipboard: Bool = false) {
        let config = ConfigManager.shared.config
        var savedURL: URL?

        // Save to file
        if config.output.fileEnabled {
            do {
                savedURL = try FileWriter.shared.save(result)
                menuBarController.addRecentCapture(savedURL!)
            } catch {
                Logger.error("Failed to save file: \(error.localizedDescription)")
            }
        }

        // Copy to clipboard (with file URL if available) - skip if already copied
        if config.output.clipboardEnabled && !skipClipboard {
            let success: Bool
            if let fileURL = savedURL {
                // Copy with file URL so user can paste as file
                success = ClipboardManager.shared.copyImageAndFileToClipboard(result.image, fileURL: fileURL)
            } else {
                success = ClipboardManager.shared.copyToClipboard(result.image)
            }

            if !success {
                Logger.error("Failed to copy to clipboard")
            }
        }

        // Show notifications
        if let url = savedURL {
            menuBarController.showCaptureNotification(savedTo: url)

            if config.capture.showNotification {
                showSystemNotification(for: url)
            }
        }
    }

    // MARK: - Error Handling

    private func handleCaptureError(_ error: Error) {
        Logger.error("Capture error: \(error.localizedDescription)")

        if let captureError = error as? CaptureError,
           case .capturePermissionDenied = captureError {
            showPermissionAlert()
        }
    }

    // MARK: - Notifications

    private func showSystemNotification(for url: URL) {
        guard isRunningInBundle else { return }

        let content = UNMutableNotificationContent()
        content.title = "Screenshot Captured"
        content.body = url.lastPathComponent
        content.categoryIdentifier = "screenshot"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func showEditCompleteNotification() {
        guard isRunningInBundle else { return }

        let content = UNMutableNotificationContent()
        content.title = "Screenshot Updated"
        content.body = "Edited image copied to clipboard"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func requestNotificationPermission() {
        guard isRunningInBundle else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.warning("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "MacSnap needs screen recording permission to capture screenshots. Please enable it in System Settings > Privacy & Security > Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Preferences

    public func showPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
            let hostingView = NSHostingView(rootView: preferencesView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 540)

            preferencesWindow = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = "MacSnap Preferences"
            preferencesWindow?.contentView = hostingView
            preferencesWindow?.center()
            preferencesWindow?.isReleasedWhenClosed = false
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import SwiftUI
