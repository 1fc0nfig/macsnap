import Foundation
import ServiceManagement
import MacSnapCore

/// Manages the app's login item registration using SMAppService (macOS 13+)
final class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    /// Whether the app is currently registered as a login item
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister the app as a login item
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            // Sync config with actual state
            ConfigManager.shared.update(\.advanced.launchAtLogin, to: isEnabled)
        } catch {
            Logger.error("Failed to \(enabled ? "enable" : "disable") login item: \(error.localizedDescription)")
            // Sync config with actual state (may differ from what was requested)
            ConfigManager.shared.update(\.advanced.launchAtLogin, to: isEnabled)
        }
    }
}
