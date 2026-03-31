import Foundation
import ServiceManagement
import MacSnapCore

/// Manages the app's login item registration using SMAppService (macOS 13+)
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published var isEnabled: Bool

    private init() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
    }

    /// Register or unregister the app as a login item
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.error("Failed to \(enabled ? "enable" : "disable") login item: \(error.localizedDescription)")
        }
        refreshState()
    }

    /// Sync published state and config with the actual system state
    func refreshState() {
        let status = SMAppService.mainApp.status
        let systemState = status == .enabled || status == .requiresApproval
        isEnabled = systemState
        ConfigManager.shared.update(\.advanced.launchAtLogin, to: systemState)
    }
}
