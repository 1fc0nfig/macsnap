import AppKit
import SwiftUI
import MacSnapCore

/// Main application entry point
@main
struct MacSnapApp {
    // Store delegate at class level to prevent deallocation
    static var appDelegate: AppDelegate!

    static func main() {
        // Create and retain the delegate
        appDelegate = AppDelegate()

        // Get the shared application
        let app = NSApplication.shared
        app.delegate = appDelegate

        // Configure as menu bar only app (no dock icon)
        let config = ConfigManager.shared.config
        if !config.advanced.showInDock {
            app.setActivationPolicy(.accessory)
        }

        // Run the app - this blocks until the app terminates
        app.run()
    }
}
