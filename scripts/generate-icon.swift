#!/usr/bin/env swift

import AppKit
import Foundation

// Icon sizes needed for macOS app icon
let sizes: [(size: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

func createIcon(size: Int, scale: Int) -> NSImage {
    let pixelSize = size * scale
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))

    image.lockFocus()

    // Background - rounded rectangle with subtle gradient (light gray to white)
    // This works well in both light and dark modes
    let bounds = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let cornerRadius = CGFloat(pixelSize) * 0.22 // macOS icon corner radius
    let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

    // Subtle gradient background (works in both light and dark mode)
    let gradient = NSGradient(colors: [
        NSColor(white: 0.98, alpha: 1.0),  // Near white
        NSColor(white: 0.92, alpha: 1.0),  // Light gray
    ])!
    gradient.draw(in: path, angle: -90)

    // Add subtle border for definition
    NSColor(white: 0.85, alpha: 1.0).setStroke()
    path.lineWidth = CGFloat(pixelSize) * 0.01
    path.stroke()

    // Use SF Symbol with accent color (system blue)
    let symbolSize = CGFloat(pixelSize) * 0.55
    let accentColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // System blue

    // Create symbol configuration with hierarchical rendering for proper coloring
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
        .applying(.init(paletteColors: [accentColor]))

    if let symbol = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {

        // Center the symbol
        let drawRect = NSRect(
            x: (CGFloat(pixelSize) - symbol.size.width) / 2,
            y: (CGFloat(pixelSize) - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(in: drawRect)
    } else {
        // Fallback: draw manually if SF Symbol config doesn't work
        let fallbackConfig = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
        if let symbol = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)?
            .withSymbolConfiguration(fallbackConfig) {

            // Manual tinting using CIFilter
            let tinted = NSImage(size: symbol.size)
            tinted.lockFocus()

            // Draw symbol
            symbol.draw(at: .zero, from: NSRect(origin: .zero, size: symbol.size), operation: .copy, fraction: 1.0)

            // Apply color overlay
            accentColor.setFill()
            NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)

            tinted.unlockFocus()

            let drawRect = NSRect(
                x: (CGFloat(pixelSize) - tinted.size.width) / 2,
                y: (CGFloat(pixelSize) - tinted.size.height) / 2,
                width: tinted.size.width,
                height: tinted.size.height
            )
            tinted.draw(in: drawRect)
        }
    }

    image.unlockFocus()
    return image
}

func saveAsPNG(_ image: NSImage, to url: URL) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }

    do {
        try pngData.write(to: url)
        return true
    } catch {
        print("Error saving \(url.path): \(error)")
        return false
    }
}

// Main execution
let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetDir = currentDir.appendingPathComponent("AppIcon.iconset")
let resourcesDir = currentDir.appendingPathComponent("Sources/MacSnap/Resources")

// Create iconset directory
try? fileManager.removeItem(at: iconsetDir)
try! fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// Create Resources directory if needed
try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

print("Generating app icons...")

for (size, scale, name) in sizes {
    let image = createIcon(size: size, scale: scale)
    let url = iconsetDir.appendingPathComponent(name)
    if saveAsPNG(image, to: url) {
        print("  Created \(name) (\(size * scale)x\(size * scale) pixels)")
    }
}

// Also save a large PNG for general use
let largeIcon = createIcon(size: 512, scale: 2)
let largePngUrl = resourcesDir.appendingPathComponent("AppIcon.png")
if saveAsPNG(largeIcon, to: largePngUrl) {
    print("  Created AppIcon.png (1024x1024 pixels)")
}

print("\nConverting to .icns...")

// Use iconutil to create .icns file
let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns").path
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath]

do {
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("  Created AppIcon.icns")

        // Clean up iconset directory
        try? fileManager.removeItem(at: iconsetDir)

        print("\nDone! Icon files created in Sources/MacSnap/Resources/")
        print("  - AppIcon.icns (for app bundle)")
        print("  - AppIcon.png (1024x1024 preview)")
    } else {
        print("Error: iconutil failed with status \(process.terminationStatus)")
    }
} catch {
    print("Error running iconutil: \(error)")
}
