#!/usr/bin/env swift
import AppKit

_ = NSApplication.shared

func makeIcon(size: CGFloat) -> NSImage {
    let result = NSImage(size: NSSize(width: size, height: size))
    result.lockFocus()
    let s = size

    // ── Rounded-rect background with teal→blue gradient ──
    let pad      = s * 0.04
    let cornerR  = s * 0.22
    let bgRect   = NSRect(x: pad, y: pad, width: s - pad*2, height: s - pad*2)
    let bgPath   = NSBezierPath(roundedRect: bgRect, xRadius: cornerR, yRadius: cornerR)
    let gradient = NSGradient(
        colors: [NSColor(red: 0.0,  green: 0.77, blue: 0.83, alpha: 1),
                 NSColor(red: 0.04, green: 0.44, blue: 0.90, alpha: 1)],
        atLocations: [0, 1], colorSpace: .sRGB
    )!
    gradient.draw(in: bgPath, angle: -45)

    // ── White circular refresh arrow (SF Symbol) ──
    let arrowPt  = s * 0.50
    let arrowCfg = NSImage.SymbolConfiguration(pointSize: arrowPt, weight: .semibold)
    if let arrow = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)?
        .withSymbolConfiguration(arrowCfg) {
        let tinted = NSImage(size: arrow.size)
        tinted.lockFocus()
        arrow.draw(in: NSRect(origin: .zero, size: arrow.size))
        NSColor.white.set()
        NSRect(origin: .zero, size: arrow.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        let ox = (s - arrow.size.width)  / 2
        let oy = (s - arrow.size.height) / 2 + s * 0.03
        tinted.draw(at: NSPoint(x: ox, y: oy), from: .zero, operation: .sourceOver, fraction: 1)
    }

    // ── Yellow lightning bolt (SF Symbol, bottom-right) ──
    let boltPt  = s * 0.26
    let boltCfg = NSImage.SymbolConfiguration(pointSize: boltPt, weight: .bold)
    if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(boltCfg) {
        let tinted = NSImage(size: bolt.size)
        tinted.lockFocus()
        bolt.draw(in: NSRect(origin: .zero, size: bolt.size))
        NSColor(red: 1.0, green: 0.87, blue: 0.2, alpha: 1).set()
        NSRect(origin: .zero, size: bolt.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(at: NSPoint(x: s * 0.53, y: s * 0.07), from: .zero, operation: .sourceOver, fraction: 1)
    }

    result.unlockFocus()
    return result
}

func png(_ image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

let iconset = "scripts/Revive.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(CGFloat, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

for (sz, name) in specs {
    if let data = png(makeIcon(size: sz)) {
        let path = "\(iconset)/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
        print("✓ \(name).png")
    } else {
        print("⚠ failed: \(name)")
    }
}
print("✅ Iconset fertig")
