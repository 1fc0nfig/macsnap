import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Handles saving captured images to filesystem
public final class FileWriter {
    public static let shared = FileWriter()

    private init() {}

    /// Saves a capture result to the configured output directory
    @discardableResult
    public func save(_ result: CaptureResult) throws -> URL {
        let config = ConfigManager.shared.config
        let filename = FilenameGenerator.shared.generate(for: result)
        let outputPath = try getOutputPath(
            filename: filename,
            mode: result.mode,
            sourceApp: result.sourceApp
        )

        try saveImage(result.image, to: outputPath, format: config.output.format)
        return outputPath
    }

    /// Saves a capture result to a specific path
    @discardableResult
    public func save(_ result: CaptureResult, to path: URL) throws -> URL {
        let config = ConfigManager.shared.config
        try saveImage(result.image, to: path, format: config.output.format)
        return path
    }

    /// Saves a CGImage to a file
    public func saveImage(_ image: CGImage, to url: URL, format: ImageFormat) throws {
        let config = ConfigManager.shared.config

        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Create bitmap representation
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw FileWriterError.conversionFailed
        }

        // Convert to target format
        let imageData: Data?

        switch format {
        case .png:
            imageData = bitmap.representation(using: .png, properties: [:])

        case .jpg:
            let quality = CGFloat(config.output.jpgQuality) / 100.0
            imageData = bitmap.representation(using: .jpeg, properties: [
                .compressionFactor: quality
            ])

        case .webp:
            // WebP is not natively supported by NSBitmapImageRep, fallback to PNG
            // For full WebP support, consider using ImageIO with CGImageDestination
            imageData = bitmap.representation(using: .png, properties: [:])
        }

        guard let data = imageData else {
            throw FileWriterError.encodingFailed(format)
        }

        try data.write(to: url, options: .atomic)
    }

    /// Gets the full output path for a capture
    public func getOutputPath(filename: String, mode: CaptureMode, sourceApp: String?) throws -> URL {
        let config = ConfigManager.shared.config
        let baseDir = URL(fileURLWithPath: config.output.expandedDirectory)

        // Ensure base directory exists
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        // Determine subdirectory based on organization mode
        let subDir: String

        switch config.output.organize {
        case .flat:
            subDir = ""

        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            subDir = formatter.string(from: Date())

        case .byApp:
            if let app = sourceApp, !app.isEmpty {
                // Sanitize app name for filesystem
                let sanitized = app.replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                subDir = sanitized
            } else {
                subDir = "Unknown"
            }
        }

        // Build final path
        var outputDir = baseDir
        if !subDir.isEmpty {
            outputDir = baseDir.appendingPathComponent(subDir)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }

        let fullFilename = "\(filename).\(config.output.format.fileExtension)"
        return outputDir.appendingPathComponent(fullFilename)
    }

    /// Returns the size of an image file in bytes
    public func getFileSize(_ url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }

    /// Formats file size for display
    public func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// File writer errors
public enum FileWriterError: Error, LocalizedError {
    case conversionFailed
    case encodingFailed(ImageFormat)
    case writeFailed(Error)
    case directoryCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert image data"
        case .encodingFailed(let format):
            return "Failed to encode image as \(format.rawValue.uppercased())"
        case .writeFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
        }
    }
}
