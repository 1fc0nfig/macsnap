import ArgumentParser
import Foundation
import MacSnapCore

/// Capture screenshots from the command line
struct CaptureCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "capture",
        abstract: "Capture a screenshot"
    )

    @Argument(help: "Capture mode: full, area, window")
    var mode: String = "full"

    @Option(name: .shortAndLong, help: "Output format: png, jpg, webp")
    var format: String?

    @Option(name: .shortAndLong, help: "JPG quality (1-100)")
    var quality: Int?

    @Option(name: .shortAndLong, help: "Output file path (overrides default)")
    var output: String?

    @Option(name: .long, help: "Delay in seconds before capture")
    var delay: Int?

    @Flag(name: .long, help: "Skip copying to clipboard")
    var noClipboard: Bool = false

    @Flag(name: .long, help: "Skip saving to file")
    var noFile: Bool = false

    @Flag(name: .long, help: "Print file path to stdout after capture")
    var printPath: Bool = false

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    func run() throws {
        // Parse capture mode
        guard let captureMode = CaptureMode(rawValue: mode) else {
            throw ValidationError("Invalid capture mode '\(mode)'. Use: full, area, window")
        }

        // Override config temporarily
        var config = ConfigManager.shared.config

        if let format = format {
            guard let imageFormat = ImageFormat(rawValue: format.lowercased()) else {
                throw ValidationError("Invalid format '\(format)'. Use: png, jpg, webp")
            }
            config.output.format = imageFormat
        }

        if let quality = quality {
            guard quality >= 1 && quality <= 100 else {
                throw ValidationError("Quality must be between 1 and 100")
            }
            config.output.jpgQuality = quality
        }

        if noClipboard {
            config.output.clipboardEnabled = false
        }

        if noFile {
            config.output.fileEnabled = false
        }

        // Handle delay
        if let delay = delay, delay > 0 {
            if verbose {
                print("Capturing in \(delay) seconds...")
            }
            for i in (1...delay).reversed() {
                if verbose {
                    print("\(i)...")
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }

        // Perform capture
        let result: CaptureResult

        switch captureMode {
        case .fullScreen:
            if verbose {
                print("Capturing full screen...")
            }
            result = try CaptureEngine.shared.captureFullScreen()

        case .area:
            // CLI area capture requires coordinates or interactive mode
            print("Error: Area capture requires interactive mode. Use the MacSnap app for area selection.")
            throw ExitCode.failure

        case .window:
            // List windows and let user select
            let windows = CaptureEngine.shared.getWindows()
            if windows.isEmpty {
                print("No windows available for capture")
                throw ExitCode.failure
            }

            if verbose {
                print("Available windows:")
                for (index, window) in windows.enumerated() {
                    print("  \(index + 1). \(window.displayTitle)")
                }
            }

            // Capture frontmost window
            if let frontWindow = windows.first {
                if verbose {
                    print("Capturing: \(frontWindow.displayTitle)")
                }
                result = try CaptureEngine.shared.captureWindow(frontWindow.windowID)
            } else {
                throw ValidationError("No window to capture")
            }

        case .timed:
            // Timed capture with delay
            let delaySeconds = delay ?? 5
            if verbose {
                print("Timed capture in \(delaySeconds) seconds...")
            }
            for i in (1...delaySeconds).reversed() {
                print("\(i)...")
                Thread.sleep(forTimeInterval: 1)
            }
            result = try CaptureEngine.shared.captureFullScreen()

        case .custom:
            // Custom region capture requires saved region or interactive mode
            let config = ConfigManager.shared.config
            if config.customRegion.isSet {
                if verbose {
                    let rect = config.customRegion.rect
                    print("Capturing custom region: \(Int(rect.width))x\(Int(rect.height)) at (\(Int(rect.origin.x)), \(Int(rect.origin.y)))...")
                }
                result = try CaptureEngine.shared.captureArea(config.customRegion.rect)
            } else {
                print("Error: No custom region defined. Use the MacSnap app to define a custom region first.")
                throw ExitCode.failure
            }
        }

        // Process result
        if config.output.clipboardEnabled {
            if ClipboardManager.shared.copyToClipboard(result.image) {
                if verbose {
                    print("Copied to clipboard")
                }
            }
        }

        if config.output.fileEnabled {
            let savedURL: URL

            if let outputPath = output {
                // Use specified output path
                let url = URL(fileURLWithPath: outputPath)
                savedURL = try FileWriter.shared.save(result, to: url)
            } else {
                // Use default path
                savedURL = try FileWriter.shared.save(result)
            }

            if printPath {
                print(savedURL.path)
            } else if verbose {
                let size = FileWriter.shared.getFileSize(savedURL) ?? 0
                print("Saved to: \(savedURL.path)")
                print("Size: \(FileWriter.shared.formatFileSize(size))")
                print("Dimensions: \(result.width) x \(result.height)")
            }
        }

        if verbose {
            print("Done!")
        }
    }
}
