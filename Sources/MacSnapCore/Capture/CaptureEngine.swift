import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

/// Core screenshot capture engine using CoreGraphics
public final class CaptureEngine {
    public static let shared = CaptureEngine()

    private init() {}

    // MARK: - Permission Check

    /// Checks if screen recording permission is granted
    /// Uses CGPreflightScreenCaptureAccess on macOS 10.15+ for accurate check
    public func hasScreenCapturePermission() -> Bool {
        // Use the modern API for checking screen capture permission (macOS 10.15+)
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }

        // Fallback: Try to capture a window list and check if we get window content
        // CGDisplayCreateImage alone is not reliable as it returns wallpaper without permission
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        guard let windows = windowList, !windows.isEmpty else {
            return false
        }

        // Try to capture a small area - if we only get wallpaper, permission is not granted
        if let image = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 100, height: 100),
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            // Check if image has actual content (not just a solid color)
            return image.width > 0 && image.height > 0
        }

        return false
    }

    /// Requests screen recording permission by triggering the system dialog
    /// On macOS 12.3+ we use ScreenCaptureKit which properly triggers the permission dialog
    public func requestScreenCapturePermission() {
        // On macOS 12.3+, ScreenCaptureKit is the ONLY reliable way to trigger
        // the screen recording permission dialog and register the app in TCC.
        // The older CoreGraphics APIs (CGRequestScreenCaptureAccess, CGWindowListCreateImage)
        // no longer trigger the permission dialog on macOS 14 Sonoma and later.
        if #available(macOS 12.3, *) {
            // SCShareableContent.getExcludingDesktopWindows triggers the permission prompt
            // This is the modern, Apple-recommended way to request screen recording permission
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
                if let error = error {
                    // Error is expected if permission is denied - that's fine,
                    // the important thing is that the dialog was shown and the app
                    // is now registered in System Settings > Screen Recording
                    Logger.debug("ScreenCaptureKit permission request completed: \(error.localizedDescription)")
                } else {
                    Logger.debug("ScreenCaptureKit permission granted, found \(content?.displays.count ?? 0) displays")
                }
            }
        } else if #available(macOS 10.15, *) {
            // Fallback for macOS 10.15 - 12.2
            CGRequestScreenCaptureAccess()
            _ = CGWindowListCreateImage(
                CGRect(x: 0, y: 0, width: 1, height: 1),
                .optionOnScreenOnly,
                kCGNullWindowID,
                []
            )
        } else {
            // Fallback for older macOS
            _ = CGDisplayCreateImage(CGMainDisplayID())
        }
    }

    // MARK: - Screen Information

    /// Returns information about all available screens
    public func getScreens() -> [ScreenInfo] {
        var screens: [ScreenInfo] = []
        let maxDisplays: UInt32 = 16
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let result = CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)
        guard result == .success else { return screens }

        let mainDisplayID = CGMainDisplayID()

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let bounds = CGDisplayBounds(displayID)
            let isMain = displayID == mainDisplayID

            screens.append(ScreenInfo(
                displayID: displayID,
                frame: bounds,
                isMain: isMain
            ))
        }

        return screens
    }

    /// Returns the main screen info
    public func mainScreen() -> ScreenInfo? {
        return getScreens().first { $0.isMain }
    }

    /// Returns the screen containing the current cursor position
    public func screenAtCursor() -> ScreenInfo? {
        let mouseLocation = getMouseLocationInCGCoordinates()
        return getScreens().first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    /// Returns the display ID for the screen containing the cursor
    public func displayAtCursor() -> CGDirectDisplayID {
        let mouseLocation = getMouseLocationInCGCoordinates()
        var displayCount: UInt32 = 0
        var displayID: CGDirectDisplayID = CGMainDisplayID()

        // Find display containing cursor
        CGGetDisplaysWithPoint(mouseLocation, 1, &displayID, &displayCount)

        return displayCount > 0 ? displayID : CGMainDisplayID()
    }

    /// Get mouse location in CoreGraphics coordinates (origin at top-left of primary display)
    public func getMouseLocationInCGCoordinates() -> CGPoint {
        // NSEvent.mouseLocation gives us coordinates in NS coordinate system:
        // - Origin at bottom-left of PRIMARY screen
        // - Y increases upward
        //
        // CG coordinate system:
        // - Origin at top-left of PRIMARY screen
        // - Y increases downward
        //
        // Conversion: cgY = primaryScreenHeight - nsY

        let nsMouseLocation = NSEvent.mouseLocation

        // Primary screen is always the first one in NSScreen.screens
        // It has its origin at (0, 0) in NS coordinates
        guard let primaryScreen = NSScreen.screens.first else {
            return nsMouseLocation
        }

        let primaryHeight = primaryScreen.frame.height
        let cgY = primaryHeight - nsMouseLocation.y

        return CGPoint(x: nsMouseLocation.x, y: cgY)
    }

    // MARK: - Coordinate Conversion Helpers

    /// Convert NS coordinates to CG coordinates
    /// NS: origin at bottom-left of primary screen, Y up
    /// CG: origin at top-left of primary screen, Y down
    public func nsRectToCGRect(_ nsRect: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else {
            return nsRect
        }

        let primaryHeight = primaryScreen.frame.height
        return CGRect(
            x: nsRect.origin.x,
            y: primaryHeight - nsRect.origin.y - nsRect.height,
            width: nsRect.width,
            height: nsRect.height
        )
    }

    /// Convert CG coordinates to NS coordinates
    /// CG: origin at top-left of primary screen, Y down
    /// NS: origin at bottom-left of primary screen, Y up
    public func cgRectToNSRect(_ cgRect: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else {
            return cgRect
        }

        let primaryHeight = primaryScreen.frame.height
        return CGRect(
            x: cgRect.origin.x,
            y: primaryHeight - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    // MARK: - Window Information

    /// Returns list of all capturable windows
    public func getWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return windows
        }

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowDict[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Skip windows at certain layers (menu bar, dock, etc.)
            guard layer == 0 else { continue }

            let ownerName = windowDict[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = windowDict[kCGWindowName as String] as? String ?? ""
            let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool ?? true

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Skip very small windows
            guard bounds.width >= 50 && bounds.height >= 50 else { continue }

            windows.append(WindowInfo(
                windowID: windowID,
                ownerName: ownerName,
                windowName: windowName,
                bounds: bounds,
                layer: layer,
                isOnScreen: isOnScreen
            ))
        }

        return windows
    }

    /// Returns the frontmost window (excluding our own app)
    public func getFrontmostWindow(excludingBundleID: String? = nil) -> WindowInfo? {
        return getWindows().first { window in
            if let bundleID = excludingBundleID {
                return window.ownerName != bundleID
            }
            return true
        }
    }

    // MARK: - Full Screen Capture

    /// Captures the entire screen where the cursor is located
    /// If a pre-captured image is available (from hotkey), uses that to preserve hover states
    public func captureFullScreen(displayID: CGDirectDisplayID? = nil, usePreCaptured: Bool = true) throws -> CaptureResult {
        let targetDisplay = displayID ?? displayAtCursor()

        // Check for pre-captured image from hotkey (preserves hover states)
        if usePreCaptured, let preCapturedImage = HotkeyManager.shared.pendingCapturedImages[targetDisplay] {
            let bounds = CGDisplayBounds(targetDisplay)
            HotkeyManager.shared.clearPendingCaptures()

            return CaptureResult(
                image: preCapturedImage,
                mode: .fullScreen,
                captureRect: bounds,
                sourceApp: nil
            )
        }

        // Fallback: capture now if no pre-captured image
        guard let image = CGDisplayCreateImage(targetDisplay) else {
            if !hasScreenCapturePermission() {
                throw CaptureError.capturePermissionDenied
            }
            throw CaptureError.captureFailed
        }

        let bounds = CGDisplayBounds(targetDisplay)
        HotkeyManager.shared.clearPendingCaptures()

        return CaptureResult(
            image: image,
            mode: .fullScreen,
            captureRect: bounds,
            sourceApp: nil
        )
    }

    /// Captures a specific display by index (0 = primary, 1 = secondary, etc.)
    public func captureScreen(index: Int) throws -> CaptureResult {
        let screens = getScreens()
        guard index >= 0 && index < screens.count else {
            throw CaptureError.noScreensAvailable
        }

        let screen = screens[index]
        return try captureFullScreen(displayID: screen.displayID)
    }

    /// Captures all screens combined
    public func captureAllScreens() throws -> CaptureResult {
        let screens = getScreens()
        guard !screens.isEmpty else {
            throw CaptureError.noScreensAvailable
        }

        // Calculate the combined bounds
        var combinedBounds = CGRect.zero
        for screen in screens {
            combinedBounds = combinedBounds.union(screen.frame)
        }

        guard let image = CGWindowListCreateImage(
            combinedBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            if !hasScreenCapturePermission() {
                throw CaptureError.capturePermissionDenied
            }
            throw CaptureError.captureFailed
        }

        return CaptureResult(
            image: image,
            mode: .fullScreen,
            captureRect: combinedBounds,
            sourceApp: nil
        )
    }

    // MARK: - Area Capture

    /// Captures a specific rectangular area (in CG coordinates)
    /// Uses pre-captured images if available to preserve hover states
    public func captureArea(_ rect: CGRect, usePreCaptured: Bool = true) throws -> CaptureResult {
        guard rect.width > 0 && rect.height > 0 else {
            throw CaptureError.invalidRect
        }

        Logger.debug("CaptureEngine: captureArea rect: \(rect)")

        // Try to use pre-captured images to preserve hover states
        if usePreCaptured, !HotkeyManager.shared.pendingCapturedImages.isEmpty {
            if let croppedImage = cropFromPreCapturedImages(rect: rect) {
                Logger.debug("CaptureEngine: Using pre-captured image, size: \(croppedImage.width)x\(croppedImage.height)")
                HotkeyManager.shared.clearPendingCaptures()

                return CaptureResult(
                    image: croppedImage,
                    mode: .area,
                    captureRect: rect,
                    sourceApp: nil
                )
            }
        }

        // Fallback: capture now
        let config = ConfigManager.shared.config

        var imageOptions: CGWindowImageOption = [.bestResolution]
        if !config.capture.includeShadow {
            imageOptions.insert(.boundsIgnoreFraming)
        }

        guard let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            imageOptions
        ) else {
            if !hasScreenCapturePermission() {
                throw CaptureError.capturePermissionDenied
            }
            throw CaptureError.captureFailed
        }

        Logger.debug("CaptureEngine: Captured image size: \(image.width)x\(image.height)")
        HotkeyManager.shared.clearPendingCaptures()

        return CaptureResult(
            image: image,
            mode: .area,
            captureRect: rect,
            sourceApp: nil
        )
    }

    /// Crops a rectangle from pre-captured display images
    /// Supports multi-monitor captures by compositing images from multiple displays
    private func cropFromPreCapturedImages(rect: CGRect) -> CGImage? {
        let pendingImages = HotkeyManager.shared.pendingCapturedImages

        // Find all displays that intersect with the capture rect
        var overlappingDisplays: [(displayID: CGDirectDisplayID, image: CGImage, bounds: CGRect, intersection: CGRect)] = []

        for (displayID, image) in pendingImages {
            let displayBounds = CGDisplayBounds(displayID)
            let intersection = rect.intersection(displayBounds)

            if intersection.width > 0 && intersection.height > 0 {
                overlappingDisplays.append((displayID, image, displayBounds, intersection))
            }
        }

        guard !overlappingDisplays.isEmpty else {
            return nil
        }

        // If only one display, use simple cropping
        if overlappingDisplays.count == 1 {
            let display = overlappingDisplays[0]
            return cropSingleDisplay(image: display.image, displayBounds: display.bounds, captureRect: rect)
        }

        // Multiple displays - need to composite
        return compositeMultipleDisplays(displays: overlappingDisplays, captureRect: rect)
    }

    /// Crops from a single display image
    private func cropSingleDisplay(image: CGImage, displayBounds: CGRect, captureRect: CGRect) -> CGImage? {
        // Calculate the crop rect relative to the display image
        // Account for Retina scaling
        let scaleX = CGFloat(image.width) / displayBounds.width
        let scaleY = CGFloat(image.height) / displayBounds.height

        let cropRect = CGRect(
            x: (captureRect.origin.x - displayBounds.origin.x) * scaleX,
            y: (captureRect.origin.y - displayBounds.origin.y) * scaleY,
            width: captureRect.width * scaleX,
            height: captureRect.height * scaleY
        )

        // Ensure crop rect is within image bounds
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let safeCropRect = cropRect.intersection(imageRect)

        guard safeCropRect.width > 0 && safeCropRect.height > 0 else {
            return nil
        }

        return image.cropping(to: safeCropRect)
    }

    /// Composites images from multiple displays into a single image
    private func compositeMultipleDisplays(
        displays: [(displayID: CGDirectDisplayID, image: CGImage, bounds: CGRect, intersection: CGRect)],
        captureRect: CGRect
    ) -> CGImage? {
        // Determine the scale factor from the first display (assume all displays have same scale)
        guard let firstDisplay = displays.first else { return nil }
        let scaleX = CGFloat(firstDisplay.image.width) / firstDisplay.bounds.width
        let scaleY = CGFloat(firstDisplay.image.height) / firstDisplay.bounds.height

        // Create output image at the scaled resolution
        let outputWidth = Int(captureRect.width * scaleX)
        let outputHeight = Int(captureRect.height * scaleY)

        guard outputWidth > 0 && outputHeight > 0 else { return nil }

        // Create a bitmap context for compositing
        guard let colorSpace = firstDisplay.image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: outputWidth,
                height: outputHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            Logger.error("Failed to create graphics context for multi-monitor composite")
            return nil
        }

        // Fill with black background (for any gaps between monitors)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        // Draw each display's contribution
        for display in displays {
            let displayScaleX = CGFloat(display.image.width) / display.bounds.width
            let displayScaleY = CGFloat(display.image.height) / display.bounds.height

            // Calculate what portion of this display to crop
            let intersection = display.intersection

            // Source rect in the display's image (scaled coordinates)
            let sourceRect = CGRect(
                x: (intersection.origin.x - display.bounds.origin.x) * displayScaleX,
                y: (intersection.origin.y - display.bounds.origin.y) * displayScaleY,
                width: intersection.width * displayScaleX,
                height: intersection.height * displayScaleY
            )

            // Destination rect in the output image (scaled coordinates)
            // Note: CGContext has origin at bottom-left, but our capture rect uses top-left origin
            let destX = (intersection.origin.x - captureRect.origin.x) * scaleX
            let destY = CGFloat(outputHeight) - (intersection.origin.y - captureRect.origin.y + intersection.height) * scaleY
            let destRect = CGRect(
                x: destX,
                y: destY,
                width: intersection.width * scaleX,
                height: intersection.height * scaleY
            )

            // Crop the portion from the display image
            if let croppedPortion = display.image.cropping(to: sourceRect) {
                context.draw(croppedPortion, in: destRect)
            }
        }

        return context.makeImage()
    }

    /// Captures a custom region (stored region that user can reuse)
    public func captureCustomRegion(_ region: CustomRegion) throws -> CaptureResult {
        let result = try captureArea(region.rect)
        return CaptureResult(
            image: result.image,
            mode: .custom,
            captureRect: region.rect,
            sourceApp: nil
        )
    }

    // MARK: - Window Capture

    /// Captures a specific window by ID
    /// Uses pre-captured images if available to preserve hover states
    public func captureWindow(_ windowID: CGWindowID, usePreCaptured: Bool = true) throws -> CaptureResult {
        // Get window info for metadata and bounds
        let windows = getWindows()
        let windowInfo = windows.first { $0.windowID == windowID }

        // Try to use pre-captured images to preserve hover states
        if usePreCaptured,
           !HotkeyManager.shared.pendingCapturedImages.isEmpty,
           let bounds = windowInfo?.bounds,
           let croppedImage = cropFromPreCapturedImages(rect: bounds) {

            Logger.debug("CaptureEngine: Using pre-captured image for window, size: \(croppedImage.width)x\(croppedImage.height)")
            HotkeyManager.shared.clearPendingCaptures()

            return CaptureResult(
                image: croppedImage,
                mode: .window,
                captureRect: bounds,
                sourceApp: windowInfo?.ownerName
            )
        }

        // Fallback: capture window directly
        let config = ConfigManager.shared.config

        // Build image options for window capture
        // .bestResolution: Capture at native resolution
        // .boundsIgnoreFraming: Exclude shadow/frame (tighter bounds)
        // Note: Do NOT use .shouldBeOpaque as it fills transparent areas with white
        var imageOptions: CGWindowImageOption = [.bestResolution]
        if !config.capture.includeShadow {
            imageOptions.insert(.boundsIgnoreFraming)
        }

        guard let image = CGWindowListCreateImage(
            CGRect.null,
            .optionIncludingWindow,
            windowID,
            imageOptions
        ) else {
            if !hasScreenCapturePermission() {
                throw CaptureError.capturePermissionDenied
            }
            throw CaptureError.windowNotFound
        }

        HotkeyManager.shared.clearPendingCaptures()

        return CaptureResult(
            image: image,
            mode: .window,
            captureRect: windowInfo?.bounds ?? .zero,
            sourceApp: windowInfo?.ownerName
        )
    }

    /// Captures the window under the cursor
    public func captureWindowUnderCursor() throws -> CaptureResult {
        let mouseLocation = getMouseLocationInCGCoordinates()

        let windows = getWindows()
        guard let targetWindow = windows.first(where: { window in
            window.bounds.contains(mouseLocation)
        }) else {
            throw CaptureError.windowNotFound
        }

        return try captureWindow(targetWindow.windowID)
    }
}

// MARK: - Custom Region

/// Represents a user-defined capture region
public struct CustomRegion: Codable, Equatable {
    public let name: String
    public let rect: CGRect

    public init(name: String, rect: CGRect) {
        self.name = name
        self.rect = rect
    }

    enum CodingKeys: String, CodingKey {
        case name
        case x, y, width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        rect = CGRect(x: x, y: y, width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(rect.origin.x, forKey: .x)
        try container.encode(rect.origin.y, forKey: .y)
        try container.encode(rect.width, forKey: .width)
        try container.encode(rect.height, forKey: .height)
    }
}
