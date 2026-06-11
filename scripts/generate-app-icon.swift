#!/usr/bin/env swift

import AppKit
import Foundation

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = projectRoot.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawBaseIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024
    let background = roundedRect(canvas.insetBy(dx: 44 * scale, dy: 44 * scale), radius: 220 * scale)
    NSGradient(colors: [
        color(7, 20, 48),
        color(9, 92, 130),
        color(18, 197, 187)
    ])?.draw(in: background, angle: -42)

    // Soft inner glow.
    color(255, 255, 255, 0.12).setStroke()
    background.lineWidth = 6 * scale
    background.stroke()

    // Mac-style base slab.
    let slab = CGRect(x: 186 * scale, y: 228 * scale, width: 652 * scale, height: 350 * scale)
    let slabPath = roundedRect(slab, radius: 74 * scale)
    NSGradient(colors: [
        color(235, 245, 250),
        color(166, 198, 213),
        color(88, 139, 162)
    ])?.draw(in: slabPath, angle: 92)

    color(255, 255, 255, 0.72).setStroke()
    slabPath.lineWidth = 10 * scale
    slabPath.stroke()

    // Drive slot and activity light.
    let slot = roundedRect(CGRect(x: 292 * scale, y: 328 * scale, width: 284 * scale, height: 42 * scale), radius: 21 * scale)
    color(12, 39, 61, 0.82).setFill()
    slot.fill()

    let led = NSBezierPath(ovalIn: CGRect(x: 632 * scale, y: 324 * scale, width: 58 * scale, height: 58 * scale))
    color(22, 222, 172).setFill()
    led.fill()

    // Write pen nib overlay.
    let nib = NSBezierPath()
    nib.move(to: CGPoint(x: 618 * scale, y: 744 * scale))
    nib.line(to: CGPoint(x: 764 * scale, y: 598 * scale))
    nib.line(to: CGPoint(x: 688 * scale, y: 522 * scale))
    nib.line(to: CGPoint(x: 542 * scale, y: 668 * scale))
    nib.close()
    NSGradient(colors: [
        color(255, 255, 255),
        color(129, 229, 255)
    ])?.draw(in: nib, angle: -36)
    color(7, 42, 64, 0.34).setStroke()
    nib.lineWidth = 8 * scale
    nib.stroke()

    let nibTip = NSBezierPath()
    nibTip.move(to: CGPoint(x: 514 * scale, y: 638 * scale))
    nibTip.line(to: CGPoint(x: 542 * scale, y: 668 * scale))
    nibTip.line(to: CGPoint(x: 568 * scale, y: 610 * scale))
    nibTip.close()
    color(255, 207, 82).setFill()
    nibTip.fill()

    // NTFS blocks: simple data/write metaphor, no text.
    for (index, x) in [310, 386, 462].enumerated() {
        let block = roundedRect(
            CGRect(x: CGFloat(x) * scale, y: 458 * scale, width: 54 * scale, height: 54 * scale),
            radius: 14 * scale
        )
        color(index == 1 ? 22 : 255, index == 1 ? 222 : 255, index == 1 ? 172 : 255, index == 1 ? 0.92 : 0.76).setFill()
        block.fill()
    }

    // Subtle shadow at the bottom.
    let shadow = NSBezierPath(ovalIn: CGRect(x: 228 * scale, y: 176 * scale, width: 568 * scale, height: 70 * scale))
    color(0, 0, 0, 0.22).setFill()
    shadow.fill()

    return image
}

func pngData(from image: NSImage, size: Int) throws -> Data {
    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: CGRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    target.unlockFocus()

    guard
        let tiff = target.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "MacNTFSWriterIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    return data
}

let base = drawBaseIcon(size: 1024)
let iconFiles: [(String, Int)] = [
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

for (filename, size) in iconFiles {
    let outputURL = iconsetURL.appendingPathComponent(filename)
    try pngData(from: base, size: size).write(to: outputURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "MacNTFSWriterIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Created \(icnsURL.path)")
