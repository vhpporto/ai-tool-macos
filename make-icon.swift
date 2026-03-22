#!/usr/bin/env swift
import AppKit
import CoreGraphics

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Background: dark rounded rect with subtle gradient
    let radius = s * 0.22
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Gradient background: near-black to dark red
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
        CGColor(red: 0.16, green: 0.05, blue: 0.05, alpha: 1)
    ] as CFArray
    let locations: [CGFloat] = [0, 1]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        ctx.drawLinearGradient(gradient,
            start: CGPoint(x: s * 0.2, y: s),
            end: CGPoint(x: s * 0.8, y: 0),
            options: [])
    }

    // Draw sparkles symbol — white with slight red tint
    let symbolSize = s * 0.55
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [
            NSColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 1),
            NSColor(red: 1.0, green: 0.75, blue: 0.75, alpha: 0.85),
        ]))
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let ox = (s - symbol.size.width) / 2
        let oy = (s - symbol.size.height) / 2
        symbol.draw(in: CGRect(x: ox, y: oy, width: symbol.size.width, height: symbol.size.height),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to save \(path)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

let iconsetPath = "Aura.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let img = renderIcon(size: size)
    savePNG(img, to: "\(iconsetPath)/\(name)")
    print("  \(name)")
}

print("Done. Run: iconutil -c icns \(iconsetPath)")
