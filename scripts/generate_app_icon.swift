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

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

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

    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "DevSessionsIcon", code: 2)
    }
    NSGraphicsContext.current = graphics

    let cg = graphics.cgContext
    let size = CGFloat(pixels)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()

    // Deep plum background.
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0x1A1028).cgColor,
            color(0x2B1742).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(
        background,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // Soft light behind the ring.
    let glowCenter = CGPoint(x: size * 0.72, y: size * 0.78)
    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0x8B5CF6, alpha: 0.30).cgColor,
            color(0x8B5CF6, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    cg.drawRadialGradient(
        glow,
        startCenter: glowCenter,
        startRadius: 0,
        endCenter: glowCenter,
        endRadius: size * 0.55,
        options: []
    )

    let center = CGPoint(x: size / 2, y: size / 2)
    let radius = size * 0.325
    let lineWidth = size * 0.095
    let degrees: CGFloat = .pi / 180

    // Ring with a 50-degree gap at the top-right.
    let ring = CGMutablePath()
    ring.addArc(
        center: center,
        radius: radius,
        startAngle: 70 * degrees,
        endAngle: 380 * degrees,
        clockwise: false
    )
    let ringOutline = ring.copy(
        strokingWithWidth: lineWidth,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 10
    )

    cg.saveGState()
    cg.addPath(ringOutline)
    cg.clip()

    let ringGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0x8B7CF6).cgColor,
            color(0xF3A6C8).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(
        ringGradient,
        start: CGPoint(x: center.x - radius, y: center.y - radius),
        end: CGPoint(x: center.x + radius, y: center.y + radius),
        options: []
    )
    cg.restoreGState()

    // The active-session dot sits in the gap.
    let dotAngle = 45 * degrees
    let dotCenter = CGPoint(
        x: center.x + radius * cos(dotAngle),
        y: center.y + radius * sin(dotAngle)
    )
    let dotRadius = lineWidth * 0.58

    cg.saveGState()
    cg.setShadow(
        offset: .zero,
        blur: size * 0.035,
        color: color(0xFFC29B, alpha: 0.65).cgColor
    )
    cg.setFillColor(color(0xFFC29B).cgColor)
    cg.fillEllipse(
        in: CGRect(
            x: dotCenter.x - dotRadius,
            y: dotCenter.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )
    )
    cg.restoreGState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DevSessionsIcon", code: 3)
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
