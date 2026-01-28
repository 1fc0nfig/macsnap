import AppKit
import MacSnapCore

/// Manages the menu bar status item and menu
public class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var recentCaptures: [URL] = []
    private let maxRecentCaptures = 5

    public weak var appDelegate: AppDelegate?

    public override init() {
        super.init()

        // Listen for config changes to show/hide menu bar icon
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: ConfigManager.configDidChangeNotification,
            object: nil
        )
    }

    @objc private func configDidChange() {
        let config = ConfigManager.shared.config
        if config.advanced.showInMenuBar {
            showMenuBarIcon()
        } else {
            hideMenuBarIcon()
        }
    }

    public func setup() {
        Logger.debug("Setting up menu bar")

        let config = ConfigManager.shared.config
        if config.advanced.showInMenuBar {
            showMenuBarIcon()
        }
    }

    private func showMenuBarIcon() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let statusItem = statusItem else {
            Logger.error("Failed to create status item")
            return
        }

        if let button = statusItem.button {
            let icon = createMenuBarIcon()
            button.image = icon
            button.image?.isTemplate = true
            button.toolTip = "MacSnap - Click to capture"
        } else {
            Logger.error("Status item has no button")
        }

        updateMenu()
    }

    private func hideMenuBarIcon() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    public func updateMenu() {
        let menu = NSMenu()
        let config = ConfigManager.shared.config

        // Capture options
        let fullScreenItem = NSMenuItem(
            title: "Capture Full Screen",
            action: #selector(captureFullScreen),
            keyEquivalent: ""
        )
        fullScreenItem.target = self
        fullScreenItem.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: nil)
        menu.addItem(fullScreenItem)

        let areaItem = NSMenuItem(
            title: "Capture Area...",
            action: #selector(captureArea),
            keyEquivalent: ""
        )
        areaItem.target = self
        areaItem.image = NSImage(systemSymbolName: "crop", accessibilityDescription: nil)

        // Show dimensions if area region is set
        if config.areaRegion.isSet {
            let rect = config.areaRegion.rect
            areaItem.title = "Capture Area (\(Int(rect.width))x\(Int(rect.height)))"
        }
        menu.addItem(areaItem)

        let windowItem = NSMenuItem(
            title: "Capture Window...",
            action: #selector(captureWindow),
            keyEquivalent: ""
        )
        windowItem.target = self
        windowItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        menu.addItem(windowItem)

        // Custom region capture (always fresh, never saved)
        let customItem = NSMenuItem(
            title: "Capture Custom Region...",
            action: #selector(captureCustomRegion),
            keyEquivalent: ""
        )
        customItem.target = self
        customItem.image = NSImage(systemSymbolName: "rectangle.badge.plus", accessibilityDescription: nil)
        menu.addItem(customItem)

        // Timed capture submenu
        let timedItem = NSMenuItem(title: "Timed Capture", action: nil, keyEquivalent: "")
        timedItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        let timedMenu = NSMenu()

        let delays = [3, 5, 10]
        for delay in delays {
            let delayItem = NSMenuItem(
                title: "\(delay) seconds",
                action: #selector(captureWithDelay(_:)),
                keyEquivalent: ""
            )
            delayItem.target = self
            delayItem.tag = delay
            timedMenu.addItem(delayItem)
        }
        timedItem.submenu = timedMenu
        menu.addItem(timedItem)

        menu.addItem(NSMenuItem.separator())

        // Recent captures
        if !recentCaptures.isEmpty {
            let recentItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
            recentItem.isEnabled = false
            menu.addItem(recentItem)

            for (index, url) in recentCaptures.prefix(maxRecentCaptures).enumerated() {
                let item = NSMenuItem(
                    title: url.lastPathComponent,
                    action: #selector(openRecentCapture(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                item.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Open output folder
        let openFolderItem = NSMenuItem(
            title: "Open Output Folder",
            action: #selector(openOutputFolder),
            keyEquivalent: "o"
        )
        openFolderItem.target = self
        openFolderItem.keyEquivalentModifierMask = [.command]
        openFolderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(openFolderItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(
            title: "About MacSnap",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit MacSnap",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    public func addRecentCapture(_ url: URL) {
        // Remove if already exists
        recentCaptures.removeAll { $0 == url }

        // Add to front
        recentCaptures.insert(url, at: 0)

        // Trim to max
        if recentCaptures.count > maxRecentCaptures {
            recentCaptures = Array(recentCaptures.prefix(maxRecentCaptures))
        }

        updateMenu()
    }

    // MARK: - Menu Actions

    @objc private func captureFullScreen() {
        appDelegate?.performCapture(mode: .fullScreen)
    }

    @objc private func captureArea() {
        appDelegate?.performCapture(mode: .area)
    }

    @objc private func captureWindow() {
        appDelegate?.performCapture(mode: .window)
    }

    @objc private func captureCustomRegion() {
        appDelegate?.performCapture(mode: .custom)
    }

    @objc private func captureWithDelay(_ sender: NSMenuItem) {
        let delay = sender.tag
        appDelegate?.performTimedCapture(delay: delay)
    }

    @objc private func openRecentCapture(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < recentCaptures.count else { return }

        let url = recentCaptures[index]
        NSWorkspace.shared.open(url)
    }

    @objc private func openOutputFolder() {
        let config = ConfigManager.shared.config
        let path = config.output.expandedDirectory
        let url = URL(fileURLWithPath: path)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        NSWorkspace.shared.open(url)
    }

    @objc private func showPreferences() {
        appDelegate?.showPreferences()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Menu Bar Icon

    private func createMenuBarIcon() -> NSImage {
        // Use SF Symbol for reliable display
        if let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "MacSnap") {
            return image
        }

        // Fallback: create a simple icon
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()

            // Simple screen rectangle
            let screenRect = NSRect(x: 2, y: 4, width: 14, height: 10)
            let path = NSBezierPath(roundedRect: screenRect, xRadius: 2, yRadius: 2)
            path.lineWidth = 1.5
            path.stroke()

            // Crosshair
            let crossPath = NSBezierPath()
            crossPath.move(to: NSPoint(x: 9, y: 6))
            crossPath.line(to: NSPoint(x: 9, y: 12))
            crossPath.move(to: NSPoint(x: 5, y: 9))
            crossPath.line(to: NSPoint(x: 13, y: 9))
            crossPath.lineWidth = 1
            crossPath.stroke()

            return true
        }

        return image
    }

    public func showCaptureNotification(savedTo url: URL) {
        let config = ConfigManager.shared.config
        guard config.capture.showNotification else { return }

        // Flash the menu bar icon briefly
        if let button = statusItem?.button {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                button.alphaValue = 0.3
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.1
                    button.alphaValue = 1.0
                }
            }
        }
    }
}
