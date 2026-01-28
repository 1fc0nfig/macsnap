import Foundation
import AppKit
import CoreGraphics

/// Manages clipboard operations for captured images
public final class ClipboardManager {
    public static let shared = ClipboardManager()

    private init() {}

    /// Copies a CGImage to the system clipboard
    @discardableResult
    public func copyToClipboard(_ image: CGImage) -> Bool {
        Logger.debug("ClipboardManager: copyToClipboard called with CGImage \(image.width)x\(image.height)")

        // Create NSImage from CGImage
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: image.width,
            height: image.height
        ))

        return copyNSImageToClipboard(nsImage)
    }

    /// Copies an NSImage to the system clipboard using multiple formats for maximum compatibility
    @discardableResult
    public func copyNSImageToClipboard(_ image: NSImage) -> Bool {
        Logger.debug("ClipboardManager: copyNSImageToClipboard called with image size \(image.size), main thread: \(Thread.isMainThread)")

        // Clipboard operations must be on main thread
        if !Thread.isMainThread {
            var result = false
            DispatchQueue.main.sync {
                result = self.performClipboardCopy(image)
            }
            return result
        }

        return performClipboardCopy(image)
    }

    private func performClipboardCopy(_ image: NSImage, fileURL: URL? = nil) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Build list of types we'll provide
        var types: [NSPasteboard.PasteboardType] = [.tiff, .png]
        if fileURL != nil {
            types.append(.fileURL)
        }

        // Declare all types upfront - this is what clipboard history apps expect
        pasteboard.declareTypes(types, owner: nil)

        var success = false

        // Set TIFF data (most universal image format for pasteboard)
        if let tiffData = image.tiffRepresentation {
            success = pasteboard.setData(tiffData, forType: .tiff)
        }

        // Set PNG data
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }

        // Set file URL if provided
        if let fileURL = fileURL {
            pasteboard.setString(fileURL.absoluteString, forType: .fileURL)
        }

        return success
    }

    /// Copies an NSImage to the system clipboard (legacy method)
    @discardableResult
    public func copyToClipboard(_ image: NSImage) -> Bool {
        return copyNSImageToClipboard(image)
    }

    /// Copies image data to clipboard with specific format
    @discardableResult
    public func copyToClipboard(_ data: Data, as type: NSPasteboard.PasteboardType) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: type)
    }

    /// Copies PNG data to clipboard
    @discardableResult
    public func copyPNGToClipboard(_ image: CGImage) -> Bool {
        guard let pngData = createPNGData(from: image) else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Set both PNG and TIFF for compatibility
        var success = pasteboard.setData(pngData, forType: .png)

        // Also add TIFF representation
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation {
            success = pasteboard.setData(tiffData, forType: .tiff) || success
        }

        return success
    }

    /// Copies file URL to clipboard (for paste as file)
    @discardableResult
    public func copyFileURLToClipboard(_ fileURL: URL) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([fileURL as NSURL])
    }

    /// Copies both image and file URL to clipboard as a single clipboard entry
    /// Uses NSImage + file URL representation (not multiple objects) to avoid double-paste issues
    @discardableResult
    public func copyImageAndFileToClipboard(_ image: CGImage, fileURL: URL) -> Bool {
        Logger.debug("ClipboardManager: copyImageAndFileToClipboard for \(fileURL.lastPathComponent)")

        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: image.width,
            height: image.height
        ))

        // Use the unified method that creates single clipboard entry
        return performClipboardCopy(nsImage, fileURL: fileURL)
    }

    /// Copies NSImage and file URL to clipboard as a single clipboard entry
    @discardableResult
    public func copyImageAndFileToClipboard(_ image: NSImage, fileURL: URL) -> Bool {
        Logger.debug("ClipboardManager: copyImageAndFileToClipboard (NSImage) for \(fileURL.lastPathComponent)")
        return performClipboardCopy(image, fileURL: fileURL)
    }

    // MARK: - Helper Methods

    private func createPNGData(from image: CGImage) -> Data? {
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: image.width,
            height: image.height
        ))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
    }
}

// MARK: - NSPasteboard.PasteboardType Extension
extension NSPasteboard.PasteboardType {
    static let png = NSPasteboard.PasteboardType("public.png")
}
