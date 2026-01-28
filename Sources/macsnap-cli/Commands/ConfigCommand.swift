import ArgumentParser
import Foundation
import MacSnapCore

/// Get or set configuration values
struct ConfigCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Get or set configuration values"
    )

    @Argument(help: "Configuration key (e.g., output.directory)")
    var key: String

    @Argument(help: "Value to set (omit to get current value)")
    var value: String?

    func run() throws {
        if let value = value {
            // Set value
            if ConfigManager.shared.setValue(value, forKey: key) {
                print("\(key) = \(value)")
            } else {
                throw ValidationError("Failed to set '\(key)' to '\(value)'. Check that the key is valid and the value is appropriate.")
            }
        } else {
            // Get value
            if let value = ConfigManager.shared.getValue(forKey: key) {
                print("\(value)")
            } else {
                throw ValidationError("Unknown configuration key: \(key)")
            }
        }
    }
}

/// List all configuration values
struct ListConfigCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list-config",
        abstract: "List all configuration values"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    func run() throws {
        let config = ConfigManager.shared.config

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("MacSnap Configuration")
            print("=" .padding(toLength: 50, withPad: "=", startingAt: 0))
            print()

            print("[Output]")
            print("  directory         = \(config.output.directory)")
            print("  format            = \(config.output.format.rawValue)")
            print("  jpgQuality        = \(config.output.jpgQuality)")
            print("  filenameTemplate  = \(config.output.filenameTemplate)")
            print("  organize          = \(config.output.organize.rawValue)")
            print("  clipboardEnabled  = \(config.output.clipboardEnabled)")
            print("  fileEnabled       = \(config.output.fileEnabled)")
            print()

            print("[Capture]")
            print("  includeCursor     = \(config.capture.includeCursor)")
            print("  includeShadow     = \(config.capture.includeShadow)")
            print("  retinaScale       = \(config.capture.retinaScale.rawValue)")
            print("  soundEnabled      = \(config.capture.soundEnabled)")
            print("  showNotification  = \(config.capture.showNotification)")
            print()

            print("[Shortcuts]")
            print("  enabled           = \(config.shortcuts.enabled)")
            print("  fullScreen        = \(config.shortcuts.fullScreen)")
            print("  areaSelect        = \(config.shortcuts.areaSelect)")
            print("  windowCapture     = \(config.shortcuts.windowCapture)")
            print("  customRegion      = \(config.shortcuts.customRegion)")
            print()

            print("[Advanced]")
            print("  launchAtLogin          = \(config.advanced.launchAtLogin)")
            print("  showInDock             = \(config.advanced.showInDock)")
            print("  disableNativeShortcuts = \(config.advanced.disableNativeShortcuts)")
        }
    }
}

/// Reset configuration to defaults
struct ResetConfigCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "reset-config",
        abstract: "Reset configuration to defaults"
    )

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force: Bool = false

    func run() throws {
        if !force {
            print("This will reset all configuration to defaults. Continue? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled")
                return
            }
        }

        ConfigManager.shared.resetToDefaults()
        print("Configuration reset to defaults")
    }
}
