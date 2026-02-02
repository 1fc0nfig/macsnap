import Foundation

/// Main configuration model for MacSnap
public struct AppConfig: Codable, Equatable {
    public var version: String
    public var output: OutputConfig
    public var capture: CaptureConfig
    public var shortcuts: ShortcutsConfig
    public var advanced: AdvancedConfig
    public var customRegion: CustomRegionConfig
    public var areaRegion: AreaRegionConfig

    public init(
        version: String = "1.1",
        output: OutputConfig = OutputConfig(),
        capture: CaptureConfig = CaptureConfig(),
        shortcuts: ShortcutsConfig = ShortcutsConfig(),
        advanced: AdvancedConfig = AdvancedConfig(),
        customRegion: CustomRegionConfig = CustomRegionConfig(),
        areaRegion: AreaRegionConfig = AreaRegionConfig()
    ) {
        self.version = version
        self.output = output
        self.capture = capture
        self.shortcuts = shortcuts
        self.advanced = advanced
        self.customRegion = customRegion
        self.areaRegion = areaRegion
    }
}

/// Output configuration
public struct OutputConfig: Codable, Equatable {
    public var directory: String
    public var format: ImageFormat
    public var jpgQuality: Int
    public var filenameTemplate: String
    public var organize: OrganizeMode
    public var clipboardEnabled: Bool
    public var fileEnabled: Bool

    public init(
        directory: String = "~/Pictures/macsnap",
        format: ImageFormat = .png,
        jpgQuality: Int = 90,
        filenameTemplate: String = "macsnap_{datetime}_{mode}",
        organize: OrganizeMode = .byDate,
        clipboardEnabled: Bool = true,
        fileEnabled: Bool = true
    ) {
        self.directory = directory
        self.format = format
        self.jpgQuality = jpgQuality
        self.filenameTemplate = filenameTemplate
        self.organize = organize
        self.clipboardEnabled = clipboardEnabled
        self.fileEnabled = fileEnabled
    }

    /// Returns the expanded directory path
    public var expandedDirectory: String {
        return NSString(string: directory).expandingTildeInPath
    }
}

/// Image format options
public enum ImageFormat: String, Codable, CaseIterable {
    case png
    case jpg
    case webp

    public var fileExtension: String {
        return rawValue
    }

    public var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpg: return "public.jpeg"
        case .webp: return "org.webmproject.webp"
        }
    }
}

/// File organization mode
public enum OrganizeMode: String, Codable, CaseIterable {
    case flat
    case byDate = "by-date"
    case byApp = "by-app"

    public var displayName: String {
        switch self {
        case .flat: return "Flat (no subfolders)"
        case .byDate: return "By Date (YYYY-MM-DD)"
        case .byApp: return "By App"
        }
    }
}

/// Capture configuration
public struct CaptureConfig: Codable, Equatable {
    public var includeCursor: Bool
    public var includeShadow: Bool
    public var retinaScale: RetinaScale
    public var soundEnabled: Bool
    public var showNotification: Bool
    public var showPreview: Bool
    public var previewDuration: Double
    public var preserveHoverStates: Bool

    public init(
        includeCursor: Bool = false,
        includeShadow: Bool = true,
        retinaScale: RetinaScale = .auto,
        soundEnabled: Bool = false,
        showNotification: Bool = true,
        showPreview: Bool = true,
        previewDuration: Double = 5.0,
        preserveHoverStates: Bool = true
    ) {
        self.includeCursor = includeCursor
        self.includeShadow = includeShadow
        self.retinaScale = retinaScale
        self.soundEnabled = soundEnabled
        self.showNotification = showNotification
        self.showPreview = showPreview
        self.previewDuration = previewDuration
        self.preserveHoverStates = preserveHoverStates
    }

    // Custom decoder to handle missing fields with defaults
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeCursor = try container.decodeIfPresent(Bool.self, forKey: .includeCursor) ?? false
        includeShadow = try container.decodeIfPresent(Bool.self, forKey: .includeShadow) ?? true
        retinaScale = try container.decodeIfPresent(RetinaScale.self, forKey: .retinaScale) ?? .auto
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
        showNotification = try container.decodeIfPresent(Bool.self, forKey: .showNotification) ?? true
        showPreview = try container.decodeIfPresent(Bool.self, forKey: .showPreview) ?? true
        previewDuration = try container.decodeIfPresent(Double.self, forKey: .previewDuration) ?? 5.0
        preserveHoverStates = try container.decodeIfPresent(Bool.self, forKey: .preserveHoverStates) ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case includeCursor, includeShadow, retinaScale, soundEnabled, showNotification, showPreview, previewDuration, preserveHoverStates
    }
}

/// Retina scale options
public enum RetinaScale: String, Codable, CaseIterable {
    case auto
    case oneX = "1x"
    case twoX = "2x"

    public var displayName: String {
        switch self {
        case .auto: return "Auto (native)"
        case .oneX: return "1x (72 DPI)"
        case .twoX: return "2x (144 DPI)"
        }
    }
}

/// Shortcuts configuration
public struct ShortcutsConfig: Codable, Equatable {
    public var fullScreen: String
    public var areaSelect: String
    public var windowCapture: String
    public var customRegion: String
    public var enabled: Bool

    public init(
        fullScreen: String = "cmd+shift+1",
        areaSelect: String = "cmd+shift+2",
        windowCapture: String = "cmd+shift+3",
        customRegion: String = "cmd+shift+4",
        enabled: Bool = true
    ) {
        self.fullScreen = fullScreen
        self.areaSelect = areaSelect
        self.windowCapture = windowCapture
        self.customRegion = customRegion
        self.enabled = enabled
    }
}

/// Custom region configuration
public struct CustomRegionConfig: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var isSet: Bool

    public init(
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        isSet: Bool = false
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isSet = isSet
    }

    public var rect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public mutating func setFromRect(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
        self.isSet = true
    }
}

/// Advanced configuration
public struct AdvancedConfig: Codable, Equatable {
    public var launchAtLogin: Bool
    public var showInDock: Bool
    public var showInMenuBar: Bool
    public var disableNativeShortcuts: Bool

    public init(
        launchAtLogin: Bool = false,
        showInDock: Bool = false,
        showInMenuBar: Bool = true,
        disableNativeShortcuts: Bool = true
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.showInMenuBar = showInMenuBar
        self.disableNativeShortcuts = disableNativeShortcuts
    }

    // Custom decoder to handle missing showInMenuBar field in existing configs
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showInDock = try container.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
        showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        disableNativeShortcuts = try container.decodeIfPresent(Bool.self, forKey: .disableNativeShortcuts) ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin, showInDock, showInMenuBar, disableNativeShortcuts
    }
}

/// Area region configuration - persistent area capture region
public struct AreaRegionConfig: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var isSet: Bool

    public init(
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        isSet: Bool = false
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isSet = isSet
    }

    public var rect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public mutating func setFromRect(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
        self.isSet = true
    }

    public mutating func reset() {
        self.x = 0
        self.y = 0
        self.width = 0
        self.height = 0
        self.isSet = false
    }
}
