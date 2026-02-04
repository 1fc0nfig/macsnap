import Foundation

/// Manages configuration persistence and access
public final class ConfigManager {
    public static let shared = ConfigManager()

    private let configDirectory: URL
    private let configFileURL: URL
    private var cachedConfig: AppConfig?

    /// Notification posted when configuration changes
    public static let configDidChangeNotification = Notification.Name("MacSnapConfigDidChange")

    private init() {
        if let overrideDirectory = ProcessInfo.processInfo.environment["MACSNAP_CONFIG_DIR"],
           !overrideDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expandedPath = NSString(string: overrideDirectory).expandingTildeInPath
            self.configDirectory = URL(fileURLWithPath: expandedPath, isDirectory: true)
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            self.configDirectory = homeDir.appendingPathComponent(".config/macsnap")
        }
        self.configFileURL = configDirectory.appendingPathComponent("config.json")
    }

    /// Current configuration (loads from disk if not cached)
    public var config: AppConfig {
        get {
            if let cached = cachedConfig {
                return cached
            }
            let loaded = loadConfig()
            cachedConfig = loaded
            return loaded
        }
        set {
            cachedConfig = newValue
            saveConfig(newValue)
            NotificationCenter.default.post(name: Self.configDidChangeNotification, object: nil)
        }
    }

    /// Loads configuration from disk, returns default if not found
    public func loadConfig() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            let defaultConfig = AppConfig()
            saveConfig(defaultConfig)
            return defaultConfig
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            Logger.warning("Error loading config: \(error.localizedDescription). Using defaults.")
            return AppConfig()
        }
    }

    /// Saves configuration to disk
    @discardableResult
    public func saveConfig(_ config: AppConfig) -> Bool {
        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFileURL, options: .atomic)
            return true
        } catch {
            Logger.error("Error saving config: \(error.localizedDescription)")
            return false
        }
    }

    /// Resets configuration to defaults
    public func resetToDefaults() {
        config = AppConfig()
    }

    /// Updates a specific configuration value using a key path
    public func update<T>(_ keyPath: WritableKeyPath<AppConfig, T>, to value: T) {
        var current = config
        current[keyPath: keyPath] = value
        config = current
    }

    /// Gets configuration value by string key (for CLI)
    public func getValue(forKey key: String) -> Any? {
        let config = self.config
        let components = key.split(separator: ".").map(String.init)

        guard components.count >= 1 else { return nil }

        switch components[0] {
        case "output":
            guard components.count >= 2 else { return nil }
            switch components[1] {
            case "directory": return config.output.directory
            case "format": return config.output.format.rawValue
            case "jpgQuality": return config.output.jpgQuality
            case "filenameTemplate": return config.output.filenameTemplate
            case "organize": return config.output.organize.rawValue
            case "clipboardEnabled": return config.output.clipboardEnabled
            case "fileEnabled": return config.output.fileEnabled
            default: return nil
            }

        case "capture":
            guard components.count >= 2 else { return nil }
            switch components[1] {
            case "includeCursor": return config.capture.includeCursor
            case "includeShadow": return config.capture.includeShadow
            case "retinaScale": return config.capture.retinaScale.rawValue
            case "soundEnabled": return config.capture.soundEnabled
            case "showNotification": return config.capture.showNotification
            case "showPreview": return config.capture.showPreview
            case "previewDuration": return config.capture.previewDuration
            case "preserveHoverStates": return config.capture.preserveHoverStates
            default: return nil
            }

        case "shortcuts":
            guard components.count >= 2 else { return nil }
            switch components[1] {
            case "fullScreen": return config.shortcuts.fullScreen
            case "areaSelect": return config.shortcuts.areaSelect
            case "windowCapture": return config.shortcuts.windowCapture
            case "customRegion": return config.shortcuts.customRegion
            case "enabled": return config.shortcuts.enabled
            default: return nil
            }

        case "advanced":
            guard components.count >= 2 else { return nil }
            switch components[1] {
            case "launchAtLogin": return config.advanced.launchAtLogin
            case "showInDock": return config.advanced.showInDock
            case "showInMenuBar": return config.advanced.showInMenuBar
            case "disableNativeShortcuts": return config.advanced.disableNativeShortcuts
            default: return nil
            }

        case "version":
            return config.version

        default:
            return nil
        }
    }

    /// Sets configuration value by string key (for CLI)
    @discardableResult
    public func setValue(_ value: String, forKey key: String) -> Bool {
        var config = self.config
        let components = key.split(separator: ".").map(String.init)

        guard components.count >= 2 else { return false }

        switch components[0] {
        case "output":
            switch components[1] {
            case "directory":
                config.output.directory = value
            case "format":
                guard let format = ImageFormat(rawValue: value) else { return false }
                config.output.format = format
            case "jpgQuality":
                guard let quality = Int(value), quality >= 1, quality <= 100 else { return false }
                config.output.jpgQuality = quality
            case "filenameTemplate":
                config.output.filenameTemplate = value
            case "organize":
                guard let mode = OrganizeMode(rawValue: value) else { return false }
                config.output.organize = mode
            case "clipboardEnabled":
                guard let boolValue = Bool(value) else { return false }
                config.output.clipboardEnabled = boolValue
            case "fileEnabled":
                guard let boolValue = Bool(value) else { return false }
                config.output.fileEnabled = boolValue
            default:
                return false
            }

        case "capture":
            switch components[1] {
            case "includeCursor":
                guard let boolValue = Bool(value) else { return false }
                config.capture.includeCursor = boolValue
            case "includeShadow":
                guard let boolValue = Bool(value) else { return false }
                config.capture.includeShadow = boolValue
            case "retinaScale":
                guard let scale = RetinaScale(rawValue: value) else { return false }
                config.capture.retinaScale = scale
            case "soundEnabled":
                guard let boolValue = Bool(value) else { return false }
                config.capture.soundEnabled = boolValue
            case "showNotification":
                guard let boolValue = Bool(value) else { return false }
                config.capture.showNotification = boolValue
            case "showPreview":
                guard let boolValue = Bool(value) else { return false }
                config.capture.showPreview = boolValue
            case "previewDuration":
                guard let doubleValue = Double(value) else { return false }
                config.capture.previewDuration = doubleValue
            case "preserveHoverStates":
                guard let boolValue = Bool(value) else { return false }
                config.capture.preserveHoverStates = boolValue
            default:
                return false
            }

        case "shortcuts":
            switch components[1] {
            case "fullScreen":
                config.shortcuts.fullScreen = value
            case "areaSelect":
                config.shortcuts.areaSelect = value
            case "windowCapture":
                config.shortcuts.windowCapture = value
            case "customRegion":
                config.shortcuts.customRegion = value
            case "enabled":
                guard let boolValue = Bool(value) else { return false }
                config.shortcuts.enabled = boolValue
            default:
                return false
            }

        case "advanced":
            switch components[1] {
            case "launchAtLogin":
                guard let boolValue = Bool(value) else { return false }
                config.advanced.launchAtLogin = boolValue
            case "showInDock":
                guard let boolValue = Bool(value) else { return false }
                config.advanced.showInDock = boolValue
            case "showInMenuBar":
                guard let boolValue = Bool(value) else { return false }
                config.advanced.showInMenuBar = boolValue
            case "disableNativeShortcuts":
                guard let boolValue = Bool(value) else { return false }
                config.advanced.disableNativeShortcuts = boolValue
            default:
                return false
            }

        default:
            return false
        }

        self.config = config
        return true
    }

    /// Returns all configuration keys for listing
    public func allKeys() -> [String] {
        return [
            "output.directory",
            "output.format",
            "output.jpgQuality",
            "output.filenameTemplate",
            "output.organize",
            "output.clipboardEnabled",
            "output.fileEnabled",
            "capture.includeCursor",
            "capture.includeShadow",
            "capture.retinaScale",
            "capture.soundEnabled",
            "capture.showNotification",
            "capture.showPreview",
            "capture.previewDuration",
            "capture.preserveHoverStates",
            "shortcuts.fullScreen",
            "shortcuts.areaSelect",
            "shortcuts.windowCapture",
            "shortcuts.customRegion",
            "shortcuts.enabled",
            "advanced.launchAtLogin",
            "advanced.showInDock",
            "advanced.showInMenuBar",
            "advanced.disableNativeShortcuts"
        ]
    }

    /// Ensures output directory exists
    public func ensureOutputDirectoryExists() throws {
        let path = config.output.expandedDirectory
        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true
            )
        } else if !isDirectory.boolValue {
            throw ConfigError.outputPathNotDirectory
        }
    }
}

/// Configuration errors
public enum ConfigError: Error, LocalizedError {
    case outputPathNotDirectory
    case invalidKey(String)
    case invalidValue(String, String)

    public var errorDescription: String? {
        switch self {
        case .outputPathNotDirectory:
            return "Output path exists but is not a directory"
        case .invalidKey(let key):
            return "Invalid configuration key: \(key)"
        case .invalidValue(let value, let key):
            return "Invalid value '\(value)' for key '\(key)'"
        }
    }
}

// MARK: - Bool Extension for parsing
extension Bool {
    init?(_ string: String) {
        switch string.lowercased() {
        case "true", "yes", "1":
            self = true
        case "false", "no", "0":
            self = false
        default:
            return nil
        }
    }
}
