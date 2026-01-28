import Foundation
import CoreGraphics

/// Capture mode types
public enum CaptureMode: String, CaseIterable {
    case fullScreen = "full"
    case area = "area"
    case window = "window"
    case timed = "timed"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .area: return "Selected Area"
        case .window: return "Window"
        case .timed: return "Timed Capture"
        case .custom: return "Custom Region"
        }
    }

    public var shortcutDescription: String {
        switch self {
        case .fullScreen: return "Capture entire screen"
        case .area: return "Select area to capture"
        case .window: return "Select window to capture"
        case .timed: return "Capture after delay"
        case .custom: return "Capture saved custom region"
        }
    }
}

/// Represents a screen/display
public struct ScreenInfo {
    public let displayID: CGDirectDisplayID
    public let frame: CGRect
    public let isMain: Bool

    public init(displayID: CGDirectDisplayID, frame: CGRect, isMain: Bool) {
        self.displayID = displayID
        self.frame = frame
        self.isMain = isMain
    }
}

/// Represents a window that can be captured
public struct WindowInfo {
    public let windowID: CGWindowID
    public let ownerName: String
    public let windowName: String
    public let bounds: CGRect
    public let layer: Int
    public let isOnScreen: Bool

    public init(
        windowID: CGWindowID,
        ownerName: String,
        windowName: String,
        bounds: CGRect,
        layer: Int,
        isOnScreen: Bool
    ) {
        self.windowID = windowID
        self.ownerName = ownerName
        self.windowName = windowName
        self.bounds = bounds
        self.layer = layer
        self.isOnScreen = isOnScreen
    }

    public var displayTitle: String {
        if windowName.isEmpty {
            return ownerName
        }
        return "\(ownerName) - \(windowName)"
    }
}

/// Result of a capture operation
public struct CaptureResult {
    public let image: CGImage
    public let mode: CaptureMode
    public let captureRect: CGRect
    public let timestamp: Date
    public let sourceApp: String?

    public init(
        image: CGImage,
        mode: CaptureMode,
        captureRect: CGRect,
        timestamp: Date = Date(),
        sourceApp: String? = nil
    ) {
        self.image = image
        self.mode = mode
        self.captureRect = captureRect
        self.timestamp = timestamp
        self.sourceApp = sourceApp
    }

    public var width: Int {
        return image.width
    }

    public var height: Int {
        return image.height
    }
}

/// Capture errors
public enum CaptureError: Error, LocalizedError {
    case noScreensAvailable
    case capturePermissionDenied
    case captureFailed
    case windowNotFound
    case invalidRect
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noScreensAvailable:
            return "No screens available for capture"
        case .capturePermissionDenied:
            return "Screen recording permission is required. Please enable it in System Preferences > Security & Privacy > Privacy > Screen Recording"
        case .captureFailed:
            return "Failed to capture screen"
        case .windowNotFound:
            return "The selected window could not be found"
        case .invalidRect:
            return "Invalid capture region"
        case .cancelled:
            return "Capture was cancelled"
        }
    }
}
