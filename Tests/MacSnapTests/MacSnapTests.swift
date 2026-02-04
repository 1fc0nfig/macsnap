import XCTest
import Foundation
import CoreGraphics
@testable import MacSnapCore

private enum TestEnvironment {
    static let configDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("macsnap-tests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)

    static func bootstrap() {
        setenv("MACSNAP_CONFIG_DIR", configDirectory.path, 1)
        try? resetConfigDirectory()
    }

    static func resetConfigDirectory() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: configDirectory.path) {
            try fileManager.removeItem(at: configDirectory)
        }
        try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }
}

private let _testBootstrap: Void = {
    TestEnvironment.bootstrap()
    return ()
}()

private func makeTestImage(width: Int = 40, height: Int = 20) throws -> CGImage {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        throw XCTSkip("Unable to create test graphics context")
    }

    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else {
        throw XCTSkip("Unable to create test image")
    }

    return image
}

final class ConfigModelTests: XCTestCase {
    override func setUpWithError() throws {
        _ = _testBootstrap
    }

    func testAppConfigDefaultsMatchCurrentVersion() {
        let config = AppConfig()

        XCTAssertEqual(config.version, "1.3.0")
        XCTAssertEqual(config.output.directory, "~/Pictures/macsnap")
        XCTAssertEqual(config.output.format, .png)
        XCTAssertEqual(config.output.organize, .byDate)
        XCTAssertTrue(config.capture.preserveHoverStates)
        XCTAssertTrue(config.advanced.showInMenuBar)
        XCTAssertTrue(config.advanced.disableNativeShortcuts)
    }

    func testAppConfigCodableRoundTrip() throws {
        var config = AppConfig()
        config.output.format = .jpg
        config.output.jpgQuality = 82
        config.capture.showPreview = false
        config.advanced.showInDock = true
        config.customRegion.setFromRect(CGRect(x: 10, y: 20, width: 300, height: 200))

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: encoded)

        XCTAssertEqual(decoded, config)
    }

    func testCaptureConfigDecodingAppliesDefaultsForMissingFields() throws {
        let json = #"{"includeCursor":true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CaptureConfig.self, from: json)

        XCTAssertTrue(decoded.includeCursor)
        XCTAssertTrue(decoded.includeShadow)
        XCTAssertEqual(decoded.retinaScale, .auto)
        XCTAssertTrue(decoded.showNotification)
        XCTAssertTrue(decoded.showPreview)
        XCTAssertTrue(decoded.preserveHoverStates)
    }

    func testAdvancedConfigDecodingAppliesDefaultsForMissingFields() throws {
        let json = #"{"launchAtLogin":true,"showInDock":true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AdvancedConfig.self, from: json)

        XCTAssertTrue(decoded.launchAtLogin)
        XCTAssertTrue(decoded.showInDock)
        XCTAssertTrue(decoded.showInMenuBar)
        XCTAssertTrue(decoded.disableNativeShortcuts)
    }

    func testCustomAndAreaRegionHelpers() {
        var custom = CustomRegionConfig()
        var area = AreaRegionConfig()

        custom.setFromRect(CGRect(x: 1, y: 2, width: 3, height: 4))
        area.setFromRect(CGRect(x: 11, y: 12, width: 13, height: 14))

        XCTAssertTrue(custom.isSet)
        XCTAssertEqual(custom.rect, CGRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertTrue(area.isSet)
        XCTAssertEqual(area.rect, CGRect(x: 11, y: 12, width: 13, height: 14))

        area.reset()

        XCTAssertFalse(area.isSet)
        XCTAssertEqual(area.rect, .zero)
    }

    func testOutputExpandedDirectoryExpandsTilde() {
        let output = OutputConfig(directory: "~/Desktop/macsnap-tests")
        XCTAssertFalse(output.expandedDirectory.hasPrefix("~"))
        XCTAssertTrue(output.expandedDirectory.contains("Desktop/macsnap-tests"))
    }
}

final class ConfigManagerTests: XCTestCase {
    override func setUpWithError() throws {
        _ = _testBootstrap
        try TestEnvironment.resetConfigDirectory()
        ConfigManager.shared.resetToDefaults()
    }

    func testLoadConfigCreatesDefaultFileWhenMissing() throws {
        let manager = ConfigManager.shared
        let configPath = TestEnvironment.configDirectory.appendingPathComponent("config.json")

        if FileManager.default.fileExists(atPath: configPath.path) {
            try FileManager.default.removeItem(at: configPath)
        }

        let loaded = manager.loadConfig()

        XCTAssertEqual(loaded.version, "1.3.0")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
    }

    func testGetValueSupportsCurrentConfigKeys() {
        let manager = ConfigManager.shared

        XCTAssertEqual(manager.getValue(forKey: "output.format") as? String, "png")
        XCTAssertEqual(manager.getValue(forKey: "capture.showPreview") as? Bool, true)
        XCTAssertEqual(manager.getValue(forKey: "capture.preserveHoverStates") as? Bool, true)
        XCTAssertEqual(manager.getValue(forKey: "advanced.showInMenuBar") as? Bool, true)
        XCTAssertNil(manager.getValue(forKey: "advanced.unknown"))
        XCTAssertNil(manager.getValue(forKey: ""))
    }

    func testSetValueAcceptsTypedValuesAndBoolAliases() {
        let manager = ConfigManager.shared

        XCTAssertTrue(manager.setValue("jpg", forKey: "output.format"))
        XCTAssertTrue(manager.setValue("75", forKey: "output.jpgQuality"))
        XCTAssertTrue(manager.setValue("false", forKey: "capture.showPreview"))
        XCTAssertTrue(manager.setValue("yes", forKey: "capture.preserveHoverStates"))
        XCTAssertTrue(manager.setValue("0", forKey: "advanced.showInMenuBar"))

        XCTAssertEqual(manager.getValue(forKey: "output.format") as? String, "jpg")
        XCTAssertEqual(manager.getValue(forKey: "output.jpgQuality") as? Int, 75)
        XCTAssertEqual(manager.getValue(forKey: "capture.showPreview") as? Bool, false)
        XCTAssertEqual(manager.getValue(forKey: "capture.preserveHoverStates") as? Bool, true)
        XCTAssertEqual(manager.getValue(forKey: "advanced.showInMenuBar") as? Bool, false)
    }

    func testCanUpdateShortcutBindingsAndReadBackValues() {
        let manager = ConfigManager.shared

        XCTAssertTrue(manager.setValue("cmd+option+9", forKey: "shortcuts.fullScreen"))
        XCTAssertTrue(manager.setValue("ctrl+shift+a", forKey: "shortcuts.areaSelect"))
        XCTAssertTrue(manager.setValue("cmd+ctrl+w", forKey: "shortcuts.windowCapture"))
        XCTAssertTrue(manager.setValue("cmd+shift+f12", forKey: "shortcuts.customRegion"))
        XCTAssertTrue(manager.setValue("false", forKey: "shortcuts.enabled"))

        XCTAssertEqual(manager.getValue(forKey: "shortcuts.fullScreen") as? String, "cmd+option+9")
        XCTAssertEqual(manager.getValue(forKey: "shortcuts.areaSelect") as? String, "ctrl+shift+a")
        XCTAssertEqual(manager.getValue(forKey: "shortcuts.windowCapture") as? String, "cmd+ctrl+w")
        XCTAssertEqual(manager.getValue(forKey: "shortcuts.customRegion") as? String, "cmd+shift+f12")
        XCTAssertEqual(manager.getValue(forKey: "shortcuts.enabled") as? Bool, false)
    }

    func testCanUpdateEveryPublicSettingKeyAndPersistToDisk() {
        let manager = ConfigManager.shared
        let outputDirectory = TestEnvironment.configDirectory.appendingPathComponent("persisted-output", isDirectory: true).path

        let updates: [(key: String, value: String)] = [
            ("output.directory", outputDirectory),
            ("output.format", "jpg"),
            ("output.jpgQuality", "81"),
            ("output.filenameTemplate", "snap_{mode}_{counter}"),
            ("output.organize", "by-app"),
            ("output.clipboardEnabled", "false"),
            ("output.fileEnabled", "true"),
            ("capture.includeCursor", "true"),
            ("capture.includeShadow", "false"),
            ("capture.retinaScale", "1x"),
            ("capture.soundEnabled", "true"),
            ("capture.showNotification", "false"),
            ("capture.showPreview", "false"),
            ("capture.previewDuration", "3.5"),
            ("capture.preserveHoverStates", "false"),
            ("shortcuts.fullScreen", "cmd+1"),
            ("shortcuts.areaSelect", "cmd+2"),
            ("shortcuts.windowCapture", "cmd+3"),
            ("shortcuts.customRegion", "cmd+4"),
            ("shortcuts.enabled", "true"),
            ("advanced.launchAtLogin", "true"),
            ("advanced.showInDock", "true"),
            ("advanced.showInMenuBar", "false"),
            ("advanced.disableNativeShortcuts", "false")
        ]

        for update in updates {
            XCTAssertTrue(manager.setValue(update.value, forKey: update.key), "Failed setting \(update.key)")
        }

        XCTAssertEqual(manager.getValue(forKey: "output.format") as? String, "jpg")
        XCTAssertEqual(manager.getValue(forKey: "capture.retinaScale") as? String, "1x")
        let previewDuration = manager.getValue(forKey: "capture.previewDuration") as? Double
        XCTAssertEqual(previewDuration ?? -1, 3.5, accuracy: 0.0001)
        XCTAssertEqual(manager.getValue(forKey: "shortcuts.fullScreen") as? String, "cmd+1")
        XCTAssertEqual(manager.getValue(forKey: "advanced.showInMenuBar") as? Bool, false)

        let reloaded = manager.loadConfig()
        XCTAssertEqual(reloaded.output.directory, outputDirectory)
        XCTAssertEqual(reloaded.output.format, .jpg)
        XCTAssertEqual(reloaded.output.jpgQuality, 81)
        XCTAssertEqual(reloaded.output.filenameTemplate, "snap_{mode}_{counter}")
        XCTAssertEqual(reloaded.output.organize, .byApp)
        XCTAssertFalse(reloaded.output.clipboardEnabled)
        XCTAssertTrue(reloaded.output.fileEnabled)
        XCTAssertTrue(reloaded.capture.includeCursor)
        XCTAssertFalse(reloaded.capture.includeShadow)
        XCTAssertEqual(reloaded.capture.retinaScale, .oneX)
        XCTAssertTrue(reloaded.capture.soundEnabled)
        XCTAssertFalse(reloaded.capture.showNotification)
        XCTAssertFalse(reloaded.capture.showPreview)
        XCTAssertEqual(reloaded.capture.previewDuration, 3.5, accuracy: 0.0001)
        XCTAssertFalse(reloaded.capture.preserveHoverStates)
        XCTAssertEqual(reloaded.shortcuts.fullScreen, "cmd+1")
        XCTAssertEqual(reloaded.shortcuts.areaSelect, "cmd+2")
        XCTAssertEqual(reloaded.shortcuts.windowCapture, "cmd+3")
        XCTAssertEqual(reloaded.shortcuts.customRegion, "cmd+4")
        XCTAssertTrue(reloaded.shortcuts.enabled)
        XCTAssertTrue(reloaded.advanced.launchAtLogin)
        XCTAssertTrue(reloaded.advanced.showInDock)
        XCTAssertFalse(reloaded.advanced.showInMenuBar)
        XCTAssertFalse(reloaded.advanced.disableNativeShortcuts)
    }

    func testSetValueRejectsInvalidValues() {
        let manager = ConfigManager.shared

        XCTAssertFalse(manager.setValue("invalid", forKey: "output.format"))
        XCTAssertFalse(manager.setValue("101", forKey: "output.jpgQuality"))
        XCTAssertFalse(manager.setValue("not-a-number", forKey: "capture.previewDuration"))
        XCTAssertFalse(manager.setValue("maybe", forKey: "advanced.showInDock"))
        XCTAssertFalse(manager.setValue("true", forKey: "unknown.key"))
    }

    func testAllKeysIncludesNewlySupportedFields() {
        let keys = ConfigManager.shared.allKeys()

        XCTAssertTrue(keys.contains("capture.showPreview"))
        XCTAssertTrue(keys.contains("capture.previewDuration"))
        XCTAssertTrue(keys.contains("capture.preserveHoverStates"))
        XCTAssertTrue(keys.contains("advanced.showInMenuBar"))
    }

    func testEnsureOutputDirectoryExistsCreatesDirectory() throws {
        let manager = ConfigManager.shared
        let outputPath = TestEnvironment.configDirectory.appendingPathComponent("output-dir").path

        XCTAssertTrue(manager.setValue(outputPath, forKey: "output.directory"))

        try manager.ensureOutputDirectoryExists()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testEnsureOutputDirectoryExistsRejectsFilePath() throws {
        let manager = ConfigManager.shared
        let filePath = TestEnvironment.configDirectory.appendingPathComponent("not-a-directory").path
        FileManager.default.createFile(atPath: filePath, contents: Data("x".utf8))
        XCTAssertTrue(manager.setValue(filePath, forKey: "output.directory"))

        do {
            try manager.ensureOutputDirectoryExists()
            XCTFail("Expected ensureOutputDirectoryExists to throw")
        } catch let error as ConfigError {
            switch error {
            case .outputPathNotDirectory:
                break
            default:
                XCTFail("Unexpected ConfigError: \(error)")
            }
        }
    }

    func testConfigSetterPostsChangeNotification() {
        let expectation = expectation(forNotification: ConfigManager.configDidChangeNotification, object: nil)
        ConfigManager.shared.config = AppConfig()
        wait(for: [expectation], timeout: 1.0)
    }
}

final class FilenameGeneratorTests: XCTestCase {
    override func setUpWithError() throws {
        _ = _testBootstrap
        FilenameGenerator.shared.resetCounter()
    }

    func testTemplateVariablesAreReplacedDeterministically() {
        let timestamp = Date(timeIntervalSince1970: 1_706_280_652)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"

        let expectedDate = dateFormatter.string(from: timestamp)
        let expectedTime = timeFormatter.string(from: timestamp)
        let filename = FilenameGenerator.shared.generate(
            template: "{date}_{time}_{timestamp}_{mode}_{app}_{counter}",
            mode: .window,
            sourceApp: "Safari",
            timestamp: timestamp
        )

        XCTAssertEqual(filename, "\(expectedDate)_\(expectedTime)_1706280652_window_Safari_001")
    }

    func testCounterResetsWhenDateChanges() {
        let firstDate = Date(timeIntervalSince1970: 1_706_280_652)
        let nextDay = Date(timeIntervalSince1970: 1_706_367_052)

        let first = FilenameGenerator.shared.generate(template: "{counter}", mode: .fullScreen, sourceApp: nil, timestamp: firstDate)
        let second = FilenameGenerator.shared.generate(template: "{counter}", mode: .fullScreen, sourceApp: nil, timestamp: firstDate)
        let third = FilenameGenerator.shared.generate(template: "{counter}", mode: .fullScreen, sourceApp: nil, timestamp: nextDay)

        XCTAssertEqual(first, "001")
        XCTAssertEqual(second, "002")
        XCTAssertEqual(third, "001")
    }

    func testSanitizeForFilenameHandlesEdgeCases() {
        let generator = FilenameGenerator.shared
        let longName = String(repeating: "a", count: 250)

        XCTAssertEqual(generator.sanitizeForFilename("with/slash:and*chars"), "with-slash-and-chars")
        XCTAssertEqual(generator.sanitizeForFilename("..."), "screenshot")
        XCTAssertEqual(generator.sanitizeForFilename(""), "screenshot")
        XCTAssertEqual(generator.sanitizeForFilename(longName).count, 200)
    }

    func testGenerateForCaptureResultUsesCurrentTemplate() throws {
        try TestEnvironment.resetConfigDirectory()
        ConfigManager.shared.resetToDefaults()
        XCTAssertTrue(ConfigManager.shared.setValue("snap_{mode}", forKey: "output.filenameTemplate"))

        let result = CaptureResult(
            image: try makeTestImage(),
            mode: .fullScreen,
            captureRect: CGRect(x: 0, y: 0, width: 40, height: 20),
            sourceApp: nil
        )

        let filename = FilenameGenerator.shared.generate(for: result)
        XCTAssertEqual(filename, "snap_full")
    }

    func testAvailableVariablesCoversTemplateDocs() {
        let variables = Set(FilenameGenerator.availableVariables.map(\.variable))
        XCTAssertEqual(variables, Set(["{datetime}", "{date}", "{time}", "{timestamp}", "{mode}", "{app}", "{counter}"]))
    }
}

final class FileWriterTests: XCTestCase {
    override func setUpWithError() throws {
        _ = _testBootstrap
        try TestEnvironment.resetConfigDirectory()
        ConfigManager.shared.resetToDefaults()

        let outputPath = TestEnvironment.configDirectory.appendingPathComponent("captures", isDirectory: true).path
        XCTAssertTrue(ConfigManager.shared.setValue(outputPath, forKey: "output.directory"))
    }

    func testGetOutputPathFlatMode() throws {
        XCTAssertTrue(ConfigManager.shared.setValue("flat", forKey: "output.organize"))
        XCTAssertTrue(ConfigManager.shared.setValue("png", forKey: "output.format"))

        let url = try FileWriter.shared.getOutputPath(filename: "test", mode: .fullScreen, sourceApp: nil)

        XCTAssertEqual(url.lastPathComponent, "test.png")
        XCTAssertEqual(url.deletingLastPathComponent().path, ConfigManager.shared.config.output.expandedDirectory)
    }

    func testGetOutputPathByDateMode() throws {
        XCTAssertTrue(ConfigManager.shared.setValue("by-date", forKey: "output.organize"))

        let url = try FileWriter.shared.getOutputPath(filename: "by-date", mode: .fullScreen, sourceApp: nil)
        let dateDirectory = url.deletingLastPathComponent().lastPathComponent

        XCTAssertEqual(dateDirectory.count, 10)
        XCTAssertEqual(dateDirectory.filter({ $0 == "-" }).count, 2)
        XCTAssertEqual(url.lastPathComponent, "by-date.png")
    }

    func testGetOutputPathByAppModeSanitizesAppName() throws {
        XCTAssertTrue(ConfigManager.shared.setValue("by-app", forKey: "output.organize"))

        let url = try FileWriter.shared.getOutputPath(filename: "by-app", mode: .window, sourceApp: "Safari/Preview:Main")
        XCTAssertTrue(url.path.contains("Safari-Preview-Main"))

        let unknownURL = try FileWriter.shared.getOutputPath(filename: "by-app", mode: .window, sourceApp: nil)
        XCTAssertTrue(unknownURL.path.contains("/Unknown/"))
    }

    func testSaveImageWritesPngAndJpg() throws {
        let image = try makeTestImage(width: 24, height: 24)
        let outputDir = URL(fileURLWithPath: ConfigManager.shared.config.output.expandedDirectory)

        let pngURL = outputDir.appendingPathComponent("sample.png")
        let jpgURL = outputDir.appendingPathComponent("sample.jpg")

        try FileWriter.shared.saveImage(image, to: pngURL, format: .png)
        try FileWriter.shared.saveImage(image, to: jpgURL, format: .jpg)

        XCTAssertTrue(FileManager.default.fileExists(atPath: pngURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: jpgURL.path))
        XCTAssertGreaterThan(FileWriter.shared.getFileSize(pngURL) ?? 0, 0)
        XCTAssertGreaterThan(FileWriter.shared.getFileSize(jpgURL) ?? 0, 0)
    }

    func testSaveImageWebPFallbackProducesPngBytes() throws {
        let image = try makeTestImage(width: 24, height: 24)
        let outputDir = URL(fileURLWithPath: ConfigManager.shared.config.output.expandedDirectory)
        let webpURL = outputDir.appendingPathComponent("sample.webp")

        try FileWriter.shared.saveImage(image, to: webpURL, format: .webp)

        let data = try Data(contentsOf: webpURL)
        let pngSignature = [UInt8](data.prefix(8))
        XCTAssertEqual(pngSignature, [137, 80, 78, 71, 13, 10, 26, 10])
    }

    func testSaveCaptureResultToExplicitPath() throws {
        let result = CaptureResult(
            image: try makeTestImage(width: 16, height: 12),
            mode: .fullScreen,
            captureRect: CGRect(x: 0, y: 0, width: 16, height: 12)
        )
        let destination = TestEnvironment.configDirectory.appendingPathComponent("explicit/output.png")

        let savedURL = try FileWriter.shared.save(result, to: destination)

        XCTAssertEqual(savedURL.path, destination.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testFileSizeFormatting() {
        XCTAssertFalse(FileWriter.shared.formatFileSize(1_024).isEmpty)
        XCTAssertFalse(FileWriter.shared.formatFileSize(10_485_760).isEmpty)
    }
}

final class HotkeyAndCaptureTests: XCTestCase {
    func testHotkeyFormattingAndValidation() {
        XCTAssertEqual(HotkeyManager.formatShortcut("cmd+shift+1"), "⌘⇧1")
        XCTAssertEqual(HotkeyManager.formatShortcut("ctrl+alt+a"), "⌃⌥A")

        XCTAssertTrue(HotkeyManager.isValidShortcut("cmd+1"))
        XCTAssertTrue(HotkeyManager.isValidShortcut("ctrl+shift+f3"))
        XCTAssertFalse(HotkeyManager.isValidShortcut("cmd"))
        XCTAssertFalse(HotkeyManager.isValidShortcut("1"))
        XCTAssertFalse(HotkeyManager.isValidShortcut(""))
    }

    func testCaptureEnumsAndDisplayStrings() {
        XCTAssertEqual(CaptureMode.fullScreen.rawValue, "full")
        XCTAssertEqual(CaptureMode.custom.displayName, "Custom Region")
        XCTAssertEqual(ImageFormat.webp.utType, "org.webmproject.webp")
        XCTAssertEqual(OrganizeMode.byApp.displayName, "By App")
        XCTAssertEqual(RetinaScale.twoX.displayName, "2x (144 DPI)")
    }

    func testWindowInfoDisplayTitle() {
        let titled = WindowInfo(windowID: 1, ownerName: "Safari", windowName: "Docs", bounds: .zero, layer: 0, isOnScreen: true)
        let untitled = WindowInfo(windowID: 2, ownerName: "Finder", windowName: "", bounds: .zero, layer: 0, isOnScreen: true)

        XCTAssertEqual(titled.displayTitle, "Safari - Docs")
        XCTAssertEqual(untitled.displayTitle, "Finder")
    }

    func testCaptureResultProperties() throws {
        let result = CaptureResult(
            image: try makeTestImage(width: 100, height: 50),
            mode: .window,
            captureRect: CGRect(x: 1, y: 2, width: 100, height: 50),
            sourceApp: "Preview"
        )

        XCTAssertEqual(result.width, 100)
        XCTAssertEqual(result.height, 50)
        XCTAssertEqual(result.mode, .window)
        XCTAssertEqual(result.sourceApp, "Preview")
    }

    func testCaptureErrorDescriptionsExist() {
        XCTAssertTrue(CaptureError.capturePermissionDenied.errorDescription?.contains("permission") == true)
        XCTAssertTrue(CaptureError.windowNotFound.errorDescription?.contains("window") == true)
        XCTAssertNotNil(CaptureError.invalidRect.errorDescription)
    }

    func testCaptureEngineRejectsInvalidInputsBeforeSystemCapture() {
        XCTAssertThrowsError(try CaptureEngine.shared.captureArea(.zero)) { error in
            guard case CaptureError.invalidRect = error else {
                XCTFail("Expected invalidRect, got \(error)")
                return
            }
        }

        XCTAssertThrowsError(try CaptureEngine.shared.captureScreen(index: -1)) { error in
            guard case CaptureError.noScreensAvailable = error else {
                XCTFail("Expected noScreensAvailable, got \(error)")
                return
            }
        }

        let invalidRegion = CustomRegion(name: "invalid", rect: .zero)
        XCTAssertThrowsError(try CaptureEngine.shared.captureCustomRegion(invalidRegion)) { error in
            guard case CaptureError.invalidRect = error else {
                XCTFail("Expected invalidRect, got \(error)")
                return
            }
        }
    }
}
