#!/usr/bin/env swift

import AppKit
import CoreGraphics

// DMG Background Generator for MacSnap
// Creates a professional installer background with drag-to-Applications visual

let width: CGFloat = 660
let height: CGFloat = 400

// Use NSImage for easier drawing with proper coordinate system
let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Get current graphics context
guard let context = NSGraphicsContext.current?.cgContext else {
    print("Failed to get context")
    exit(1)
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

// Background gradient - subtle light gray to white
let gradientColors = [
    CGColor(gray: 0.96, alpha: 1.0),
    CGColor(gray: 0.92, alpha: 1.0)
]
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors as CFArray,
    locations: [0, 1]
)!

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: height),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Draw subtle arrow indicator between app position and Applications folder position
// App will be at x=140, Applications at x=500 (center positions)
// In NSView coordinates, y=0 is at bottom, so arrow at y=180 is in the middle area
let arrowY: CGFloat = 180
let arrowStartX: CGFloat = 220
let arrowEndX: CGFloat = 420

// Arrow color - MacSnap blue with transparency
let arrowColor = CGColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.25)
context.setStrokeColor(arrowColor)
context.setLineWidth(3)
context.setLineCap(.round)

// Draw arrow line
context.move(to: CGPoint(x: arrowStartX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.strokePath()

// Draw arrow head
context.move(to: CGPoint(x: arrowEndX - 15, y: arrowY + 10))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX - 15, y: arrowY - 10))
context.strokePath()

// Draw subtle drop zone indicator for Applications folder
let dropZoneRect = CGRect(x: 440, y: 115, width: 120, height: 130)
context.setStrokeColor(CGColor(gray: 0.8, alpha: 0.5))
context.setLineWidth(2)
context.setLineDash(phase: 0, lengths: [8, 4])
context.stroke(dropZoneRect.insetBy(dx: 5, dy: 5))
context.setLineDash(phase: 0, lengths: [])

// Draw text "Drag to install" near bottom
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 0.5, alpha: 1.0)
]
let text = "Drag MacSnap to Applications to install"
let attributedText = NSAttributedString(string: text, attributes: textAttributes)

// Calculate text position (centered horizontally, near bottom)
let textSize = attributedText.size()
let textX = (width - textSize.width) / 2
let textY: CGFloat = 50  // 50 points from bottom
attributedText.draw(at: NSPoint(x: textX, y: textY))

image.unlockFocus()

// Generate the image
guard let tiffData = image.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

// Save to file
let outputPath = "Resources/dmg-background.png"
let url = URL(fileURLWithPath: outputPath)
do {
    try pngData.write(to: url)
    print("DMG background created: \(outputPath)")
} catch {
    print("Failed to write file: \(error)")
    exit(1)
}
