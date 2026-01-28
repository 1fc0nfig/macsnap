import XCTest
@testable import MacSnapCore

final class MacSnapTests: XCTestCase {

    // MARK: - Config Tests

    func testDefaultConfig() {
        let config = AppConfig()

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.output.directory, "~/Pictures/macsnap")
        XCTAssertEqual(config.output.format, .png)
        XCTAssertEqual(config.output.jpgQuality, 90)
        XCTAssertTrue(config.output.clipboardEnabled)
        XCTAssertTrue(config.output.fileEnabled)
    }

    func testConfigCodable() throws {
        let config = AppConfig()

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppConfig.self, from: data)

        XCTAssertEqual(config, decoded)
    }

    func testExpandedDirectory() {
        let config = OutputConfig(directory: "~/Pictures/test")
        let expanded = config.expandedDirectory

        XCTAssertFalse(expanded.contains("~"))
        XCTAssertTrue(expanded.contains("/Users/"))
    }

    func testConfigWithCustomRegion() throws {
        var config = AppConfig()

        // Initially no custom region
        XCTAssertFalse(config.customRegion.isSet)
        XCTAssertEqual(config.customRegion.width, 0)

        // Set a custom region
        config.customRegion.setFromRect(CGRect(x: 100, y: 200, width: 300, height: 400))

        XCTAssertTrue(config.customRegion.isSet)
        XCTAssertEqual(config.customRegion.x, 100)
        XCTAssertEqual(config.customRegion.y, 200)
        XCTAssertEqual(config.customRegion.width, 300)
        XCTAssertEqual(config.customRegion.height, 400)

        // Test encoding/decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppConfig.self, from: data)

        XCTAssertTrue(decoded.customRegion.isSet)
        XCTAssertEqual(decoded.customRegion.rect, config.customRegion.rect)
    }

    func testCustomRegionRect() {
        var regionConfig = CustomRegionConfig()
        regionConfig.setFromRect(CGRect(x: 10, y: 20, width: 100, height: 200))

        let rect = regionConfig.rect
        XCTAssertEqual(rect.origin.x, 10)
        XCTAssertEqual(rect.origin.y, 20)
        XCTAssertEqual(rect.width, 100)
        XCTAssertEqual(rect.height, 200)
    }

    // MARK: - Filename Generator Tests

    func testFilenameGeneratorBasic() {
        let generator = FilenameGenerator.shared
        generator.resetCounter()

        let filename = generator.generate(
            template: "test_{mode}",
            mode: .fullScreen,
            sourceApp: nil
        )

        XCTAssertEqual(filename, "test_full")
    }

    func testFilenameGeneratorWithApp() {
        let generator = FilenameGenerator.shared

        let filename = generator.generate(
            template: "{app}_{mode}",
            mode: .window,
            sourceApp: "Safari"
        )

        XCTAssertEqual(filename, "Safari_window")
    }

    func testFilenameGeneratorCounter() {
        let generator = FilenameGenerator.shared
        generator.resetCounter()

        let filename1 = generator.generate(
            template: "test_{counter}",
            mode: .fullScreen,
            sourceApp: nil
        )

        let filename2 = generator.generate(
            template: "test_{counter}",
            mode: .fullScreen,
            sourceApp: nil
        )

        XCTAssertEqual(filename1, "test_001")
        XCTAssertEqual(filename2, "test_002")
    }

    func testFilenameGeneratorSanitization() {
        let generator = FilenameGenerator.shared

        let filename = generator.generate(
            template: "{app}",
            mode: .window,
            sourceApp: "App/With:Bad*Chars"
        )

        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.contains(":"))
        XCTAssertFalse(filename.contains("*"))
    }

    func testSanitizeForFilename() {
        let generator = FilenameGenerator.shared

        XCTAssertEqual(generator.sanitizeForFilename("normal"), "normal")
        XCTAssertEqual(generator.sanitizeForFilename("with spaces"), "with spaces")
        XCTAssertEqual(generator.sanitizeForFilename("with/slash"), "with-slash")
        XCTAssertEqual(generator.sanitizeForFilename("with:colon"), "with-colon")
        XCTAssertEqual(generator.sanitizeForFilename(""), "screenshot")
        XCTAssertEqual(generator.sanitizeForFilename("..."), "screenshot")
    }

    func testFilenameGeneratorCustomMode() {
        let generator = FilenameGenerator.shared

        let filename = generator.generate(
            template: "snap_{mode}_{datetime}",
            mode: .custom,
            sourceApp: nil
        )

        XCTAssertTrue(filename.contains("custom"))
    }

    // MARK: - Image Format Tests

    func testImageFormatExtensions() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpg.fileExtension, "jpg")
        XCTAssertEqual(ImageFormat.webp.fileExtension, "webp")
    }

    func testImageFormatUTTypes() {
        XCTAssertEqual(ImageFormat.png.utType, "public.png")
        XCTAssertEqual(ImageFormat.jpg.utType, "public.jpeg")
    }

    func testImageFormatCaseIterable() {
        let allFormats = ImageFormat.allCases
        XCTAssertEqual(allFormats.count, 3)
        XCTAssertTrue(allFormats.contains(.png))
        XCTAssertTrue(allFormats.contains(.jpg))
        XCTAssertTrue(allFormats.contains(.webp))
    }

    // MARK: - Capture Mode Tests

    func testCaptureModeRawValues() {
        XCTAssertEqual(CaptureMode.fullScreen.rawValue, "full")
        XCTAssertEqual(CaptureMode.area.rawValue, "area")
        XCTAssertEqual(CaptureMode.window.rawValue, "window")
        XCTAssertEqual(CaptureMode.timed.rawValue, "timed")
        XCTAssertEqual(CaptureMode.custom.rawValue, "custom")
    }

    func testCaptureModeDisplayNames() {
        XCTAssertEqual(CaptureMode.fullScreen.displayName, "Full Screen")
        XCTAssertEqual(CaptureMode.area.displayName, "Selected Area")
        XCTAssertEqual(CaptureMode.window.displayName, "Window")
        XCTAssertEqual(CaptureMode.timed.displayName, "Timed Capture")
        XCTAssertEqual(CaptureMode.custom.displayName, "Custom Region")
    }

    func testCaptureModeShortcutDescriptions() {
        XCTAssertFalse(CaptureMode.fullScreen.shortcutDescription.isEmpty)
        XCTAssertFalse(CaptureMode.area.shortcutDescription.isEmpty)
        XCTAssertFalse(CaptureMode.window.shortcutDescription.isEmpty)
        XCTAssertFalse(CaptureMode.custom.shortcutDescription.isEmpty)
    }

    func testCaptureModeCaseIterable() {
        let allModes = CaptureMode.allCases
        XCTAssertEqual(allModes.count, 5)
    }

    // MARK: - Organize Mode Tests

    func testOrganizeModeValues() {
        XCTAssertEqual(OrganizeMode.flat.rawValue, "flat")
        XCTAssertEqual(OrganizeMode.byDate.rawValue, "by-date")
        XCTAssertEqual(OrganizeMode.byApp.rawValue, "by-app")
    }

    func testOrganizeModeDisplayNames() {
        XCTAssertFalse(OrganizeMode.flat.displayName.isEmpty)
        XCTAssertFalse(OrganizeMode.byDate.displayName.isEmpty)
        XCTAssertFalse(OrganizeMode.byApp.displayName.isEmpty)
    }

    // MARK: - Config Manager Tests

    func testConfigManagerGetValue() {
        let manager = ConfigManager.shared

        // Test getting various values
        XCTAssertNotNil(manager.getValue(forKey: "output.directory"))
        XCTAssertNotNil(manager.getValue(forKey: "output.format"))
        XCTAssertNotNil(manager.getValue(forKey: "capture.includeCursor"))
        XCTAssertNotNil(manager.getValue(forKey: "shortcuts.fullScreen"))
        XCTAssertNotNil(manager.getValue(forKey: "advanced.launchAtLogin"))

        // Test invalid key
        XCTAssertNil(manager.getValue(forKey: "invalid.key"))
        XCTAssertNil(manager.getValue(forKey: ""))
    }

    func testConfigManagerSetValue() {
        let manager = ConfigManager.shared

        // Save original value
        let originalFormat = manager.getValue(forKey: "output.format") as? String

        // Set new value
        XCTAssertTrue(manager.setValue("jpg", forKey: "output.format"))

        // Verify change
        XCTAssertEqual(manager.getValue(forKey: "output.format") as? String, "jpg")

        // Restore original
        if let original = originalFormat {
            manager.setValue(original, forKey: "output.format")
        }
    }

    func testConfigManagerSetInvalidValue() {
        let manager = ConfigManager.shared

        // Try to set invalid values
        XCTAssertFalse(manager.setValue("invalid", forKey: "output.format"))
        XCTAssertFalse(manager.setValue("abc", forKey: "output.jpgQuality"))
        XCTAssertFalse(manager.setValue("maybe", forKey: "capture.includeCursor"))
    }

    func testConfigManagerAllKeys() {
        let keys = ConfigManager.shared.allKeys()

        XCTAssertTrue(keys.contains("output.directory"))
        XCTAssertTrue(keys.contains("output.format"))
        XCTAssertTrue(keys.contains("capture.includeCursor"))
        XCTAssertTrue(keys.contains("shortcuts.fullScreen"))
        XCTAssertTrue(keys.contains("advanced.launchAtLogin"))

        // Should have reasonable number of keys
        XCTAssertGreaterThan(keys.count, 10)
    }

    // MARK: - Hotkey Tests

    func testHotkeyFormatting() {
        XCTAssertEqual(HotkeyManager.formatShortcut("cmd+shift+1"), "⌘⇧1")
        XCTAssertEqual(HotkeyManager.formatShortcut("command+shift+2"), "⌘⇧2")
        XCTAssertEqual(HotkeyManager.formatShortcut("ctrl+alt+a"), "⌃⌥A")
        XCTAssertEqual(HotkeyManager.formatShortcut("cmd+a"), "⌘A")
    }

    func testHotkeyValidation() {
        XCTAssertTrue(HotkeyManager.isValidShortcut("cmd+shift+1"))
        XCTAssertTrue(HotkeyManager.isValidShortcut("ctrl+a"))
        XCTAssertTrue(HotkeyManager.isValidShortcut("cmd+alt+shift+f1"))
        XCTAssertFalse(HotkeyManager.isValidShortcut("1")) // No modifier
        XCTAssertFalse(HotkeyManager.isValidShortcut("cmd")) // No key
        XCTAssertFalse(HotkeyManager.isValidShortcut("")) // Empty
    }

    // MARK: - Window Info Tests

    func testWindowInfoDisplayTitle() {
        let window1 = WindowInfo(
            windowID: 1,
            ownerName: "Safari",
            windowName: "Apple",
            bounds: .zero,
            layer: 0,
            isOnScreen: true
        )
        XCTAssertEqual(window1.displayTitle, "Safari - Apple")

        let window2 = WindowInfo(
            windowID: 2,
            ownerName: "Finder",
            windowName: "",
            bounds: .zero,
            layer: 0,
            isOnScreen: true
        )
        XCTAssertEqual(window2.displayTitle, "Finder")
    }

    func testWindowInfoWithBounds() {
        let bounds = CGRect(x: 100, y: 200, width: 800, height: 600)
        let window = WindowInfo(
            windowID: 123,
            ownerName: "TestApp",
            windowName: "Test Window",
            bounds: bounds,
            layer: 0,
            isOnScreen: true
        )

        XCTAssertEqual(window.windowID, 123)
        XCTAssertEqual(window.bounds.origin.x, 100)
        XCTAssertEqual(window.bounds.origin.y, 200)
        XCTAssertEqual(window.bounds.width, 800)
        XCTAssertEqual(window.bounds.height, 600)
    }

    // MARK: - Screen Info Tests

    func testScreenInfoCreation() {
        let screen = ScreenInfo(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            isMain: true
        )

        XCTAssertEqual(screen.displayID, 1)
        XCTAssertEqual(screen.frame.width, 1920)
        XCTAssertEqual(screen.frame.height, 1080)
        XCTAssertTrue(screen.isMain)
    }

    // MARK: - Capture Result Tests

    func testCaptureResultDimensions() {
        // Create a test image
        let width = 100
        let height = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
        let image = context.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let result = CaptureResult(
            image: image,
            mode: .fullScreen,
            captureRect: CGRect(x: 0, y: 0, width: 100, height: 50)
        )

        XCTAssertEqual(result.width, 100)
        XCTAssertEqual(result.height, 50)
        XCTAssertEqual(result.mode, .fullScreen)
        XCTAssertNil(result.sourceApp)
    }

    func testCaptureResultWithSourceApp() {
        let width = 100
        let height = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
        let image = context.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let result = CaptureResult(
            image: image,
            mode: .window,
            captureRect: CGRect(x: 0, y: 0, width: 100, height: 50),
            sourceApp: "Safari"
        )

        XCTAssertEqual(result.sourceApp, "Safari")
        XCTAssertEqual(result.mode, .window)
    }

    func testCaptureResultTimestamp() {
        let width = 10
        let height = 10
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
        let image = context.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let beforeCapture = Date()
        let result = CaptureResult(
            image: image,
            mode: .fullScreen,
            captureRect: .zero
        )
        let afterCapture = Date()

        XCTAssertGreaterThanOrEqual(result.timestamp, beforeCapture)
        XCTAssertLessThanOrEqual(result.timestamp, afterCapture)
    }

    // MARK: - Capture Error Tests

    func testCaptureErrorDescriptions() {
        XCTAssertNotNil(CaptureError.noScreensAvailable.errorDescription)
        XCTAssertNotNil(CaptureError.capturePermissionDenied.errorDescription)
        XCTAssertNotNil(CaptureError.captureFailed.errorDescription)
        XCTAssertNotNil(CaptureError.windowNotFound.errorDescription)
        XCTAssertNotNil(CaptureError.invalidRect.errorDescription)
        XCTAssertNotNil(CaptureError.cancelled.errorDescription)

        // Check they're meaningful
        XCTAssertTrue(CaptureError.capturePermissionDenied.errorDescription!.contains("permission"))
        XCTAssertTrue(CaptureError.windowNotFound.errorDescription!.contains("window"))
    }

    // MARK: - Custom Region Tests

    func testCustomRegionCodable() throws {
        let region = CustomRegion(
            name: "TestRegion",
            rect: CGRect(x: 100, y: 200, width: 300, height: 400)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(region)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomRegion.self, from: data)

        XCTAssertEqual(decoded.name, "TestRegion")
        XCTAssertEqual(decoded.rect.origin.x, 100)
        XCTAssertEqual(decoded.rect.origin.y, 200)
        XCTAssertEqual(decoded.rect.width, 300)
        XCTAssertEqual(decoded.rect.height, 400)
    }

    func testCustomRegionEquatable() {
        let region1 = CustomRegion(name: "Region1", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let region2 = CustomRegion(name: "Region1", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let region3 = CustomRegion(name: "Region2", rect: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertEqual(region1, region2)
        XCTAssertNotEqual(region1, region3)
    }

    // MARK: - Shortcuts Config Tests

    func testShortcutsConfigDefaults() {
        let shortcuts = ShortcutsConfig()

        XCTAssertEqual(shortcuts.fullScreen, "cmd+shift+1")
        XCTAssertEqual(shortcuts.areaSelect, "cmd+shift+2")
        XCTAssertEqual(shortcuts.windowCapture, "cmd+shift+3")
        XCTAssertEqual(shortcuts.customRegion, "cmd+shift+4")
        XCTAssertTrue(shortcuts.enabled)
    }

    func testShortcutsConfigCodable() throws {
        let shortcuts = ShortcutsConfig(
            fullScreen: "cmd+1",
            areaSelect: "cmd+2",
            windowCapture: "cmd+3",
            customRegion: "cmd+4",
            enabled: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(shortcuts)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ShortcutsConfig.self, from: data)

        XCTAssertEqual(decoded.fullScreen, "cmd+1")
        XCTAssertEqual(decoded.areaSelect, "cmd+2")
        XCTAssertEqual(decoded.windowCapture, "cmd+3")
        XCTAssertEqual(decoded.customRegion, "cmd+4")
        XCTAssertFalse(decoded.enabled)
    }

    // MARK: - Capture Engine Tests

    func testCaptureEngineGetScreens() {
        let screens = CaptureEngine.shared.getScreens()

        // Should have at least one screen
        XCTAssertGreaterThanOrEqual(screens.count, 1)

        // Should have exactly one main screen
        let mainScreens = screens.filter { $0.isMain }
        XCTAssertEqual(mainScreens.count, 1)
    }

    func testCaptureEngineMainScreen() {
        let mainScreen = CaptureEngine.shared.mainScreen()

        XCTAssertNotNil(mainScreen)
        XCTAssertTrue(mainScreen!.isMain)
        XCTAssertGreaterThan(mainScreen!.frame.width, 0)
        XCTAssertGreaterThan(mainScreen!.frame.height, 0)
    }

    func testCaptureEngineGetWindows() {
        let windows = CaptureEngine.shared.getWindows()

        // Note: might be 0 windows in headless test environment
        // but the function should not crash
        XCTAssertNotNil(windows)

        // If there are windows, check they have valid bounds
        for window in windows {
            XCTAssertGreaterThanOrEqual(window.bounds.width, 50)
            XCTAssertGreaterThanOrEqual(window.bounds.height, 50)
        }
    }

    func testCaptureEngineMouseLocation() {
        let location = CaptureEngine.shared.getMouseLocationInCGCoordinates()

        // Mouse location should be valid (could be anywhere)
        // Just verify it returns a point
        XCTAssertTrue(location.x.isFinite)
        XCTAssertTrue(location.y.isFinite)
    }

    func testCaptureEngineDisplayAtCursor() {
        let displayID = CaptureEngine.shared.displayAtCursor()

        // Should return a valid display ID
        XCTAssertGreaterThan(displayID, 0)
    }

    func testCaptureEngineScreenAtCursor() {
        let screen = CaptureEngine.shared.screenAtCursor()

        // Should find a screen (unless in very unusual setup)
        XCTAssertNotNil(screen)
    }

    // MARK: - Retina Scale Tests

    func testRetinaScaleValues() {
        XCTAssertEqual(RetinaScale.auto.rawValue, "auto")
        XCTAssertEqual(RetinaScale.oneX.rawValue, "1x")
        XCTAssertEqual(RetinaScale.twoX.rawValue, "2x")
    }

    func testRetinaScaleDisplayNames() {
        XCTAssertFalse(RetinaScale.auto.displayName.isEmpty)
        XCTAssertFalse(RetinaScale.oneX.displayName.isEmpty)
        XCTAssertFalse(RetinaScale.twoX.displayName.isEmpty)
    }

    // MARK: - Advanced Config Tests

    func testAdvancedConfigDefaults() {
        let advanced = AdvancedConfig()

        XCTAssertFalse(advanced.launchAtLogin)
        XCTAssertFalse(advanced.showInDock)
        XCTAssertFalse(advanced.disableNativeShortcuts)
    }

    // MARK: - Capture Config Tests

    func testCaptureConfigDefaults() {
        let capture = CaptureConfig()

        XCTAssertFalse(capture.includeCursor)
        XCTAssertTrue(capture.includeShadow)
        XCTAssertEqual(capture.retinaScale, .auto)
        XCTAssertFalse(capture.soundEnabled)
        XCTAssertTrue(capture.showNotification)
    }

    // MARK: - Output Config Tests

    func testOutputConfigDefaults() {
        let output = OutputConfig()

        XCTAssertEqual(output.directory, "~/Pictures/macsnap")
        XCTAssertEqual(output.format, .png)
        XCTAssertEqual(output.jpgQuality, 90)
        XCTAssertEqual(output.organize, .byDate)
        XCTAssertTrue(output.clipboardEnabled)
        XCTAssertTrue(output.fileEnabled)
    }

    func testOutputConfigExpandedDirectory() {
        let output = OutputConfig(directory: "~/Desktop/screenshots")
        let expanded = output.expandedDirectory

        XCTAssertFalse(expanded.hasPrefix("~"))
        XCTAssertTrue(expanded.contains("Desktop/screenshots"))
    }
}

// MARK: - Performance Tests

extension MacSnapTests {
    func testFilenameGeneratorPerformance() {
        let generator = FilenameGenerator.shared

        measure {
            for _ in 0..<1000 {
                _ = generator.generate(
                    template: "test_{datetime}_{mode}_{counter}",
                    mode: .fullScreen,
                    sourceApp: "TestApp"
                )
            }
        }
    }

    func testConfigEncodingPerformance() throws {
        let config = AppConfig()
        let encoder = JSONEncoder()

        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(config)
            }
        }
    }
}
