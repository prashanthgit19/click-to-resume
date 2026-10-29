#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let assets = root.appendingPathComponent("DevSessions/Assets.xcassets", isDirectory: true)
let iconSet = assets.appendingPathComponent("AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "DevSessionsIcon", code: 1)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    let start = NSColor(srgbRed: 0.11, green: 0.16, blue: 0.21, alpha: 1)
    let end = NSColor(srgbRed: 0.035, green: 0.055, blue: 0.075, alpha: 1)
    NSGradient(starting: start, ending: end)?.draw(in: bounds, angle: -90)

    let scale = CGFloat(pixels)
    let lineWidth = max(scale * 0.075, 1.15)

    let chevron = NSBezierPath()
    chevron.lineWidth = lineWidth
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.move(to: NSPoint(x: scale * 0.27, y: scale * 0.62))
    chevron.line(to: NSPoint(x: scale * 0.44, y: scale * 0.50))
    chevron.line(to: NSPoint(x: scale * 0.27, y: scale * 0.38))
    NSColor(srgbRed: 0.94, green: 0.96, blue: 0.97, alpha: 1).setStroke()
    chevron.stroke()

    let underscore = NSBezierPath()
    underscore.lineWidth = lineWidth
    underscore.lineCapStyle = .round
    underscore.move(to: NSPoint(x: scale * 0.53, y: scale * 0.38))
    underscore.line(to: NSPoint(x: scale * 0.73, y: scale * 0.38))
    NSColor(srgbRed: 0.34, green: 0.88, blue: 0.78, alpha: 1).setStroke()
    underscore.stroke()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DevSessionsIcon", code: 2)
    }
    return data
}

for entry in sizes {
    let data = try drawIcon(pixels: entry.pixels)
    try data.write(to: iconSet.appendingPathComponent(entry.name))
}

let images: [[String: String]] = [
    ["filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"],
    ["filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"],
    ["filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"],
    ["filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"],
    ["filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"],
    ["filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"],
    ["filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"],
    ["filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"],
    ["filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"],
    ["filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"]
]

let iconContents: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1]
]
let iconJSON = try JSONSerialization.data(
    withJSONObject: iconContents,
    options: [.prettyPrinted, .sortedKeys]
)
try iconJSON.write(to: iconSet.appendingPathComponent("Contents.json"))

let assetsContents: [String: Any] = [
    "info": ["author": "xcode", "version": 1]
]
let assetsJSON = try JSONSerialization.data(
    withJSONObject: assetsContents,
    options: [.prettyPrinted, .sortedKeys]
)
try assetsJSON.write(to: assets.appendingPathComponent("Contents.json"))

print("Generated \(sizes.count) app icon sizes in \(iconSet.path)")
