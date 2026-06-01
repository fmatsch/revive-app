import AppKit

// Programmatic icon: türkiser Kreis mit Refresh-Pfeil + kleiner Blitz
enum ReviveIcon {

    // Template image for the menu bar (adapts to dark/light automatically)
    static func menuBarImage() -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let img = NSImage(systemSymbolName: "arrow.clockwise.circle.fill", accessibilityDescription: "Revive")!
            .withSymbolConfiguration(cfg)!
        img.isTemplate = true
        return img
    }

    // Coloured app icon (used for notifications / About panel)
    static func appIcon(size: CGFloat = 128) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let ctx = NSGraphicsContext.current!.cgContext

        // Background circle with gradient
        ctx.saveGState()
        let clipPath = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
        clipPath.addClip()

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 1).cgColor,
                NSColor(red: 0.05, green: 0.45, blue: 0.90, alpha: 1).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
        ctx.restoreGState()

        // Draw SF Symbol centered, white
        let symCfg = NSImage.SymbolConfiguration(pointSize: size * 0.58, weight: .semibold)
        if let sym = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)?
            .withSymbolConfiguration(symCfg) {
            sym.isTemplate = false
            // Tint white
            let tinted = NSImage(size: sym.size)
            tinted.lockFocus()
            NSColor.white.set()
            sym.draw(in: NSRect(origin: .zero, size: sym.size),
                     from: .zero,
                     operation: .sourceAtop,
                     fraction: 1.0)
            tinted.unlockFocus()

            let symOrigin = NSPoint(
                x: (size - sym.size.width) / 2,
                y: (size - sym.size.height) / 2 + size * 0.04
            )
            tinted.draw(at: symOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        // Small lightning bolt in bottom-right
        let boltCfg = NSImage.SymbolConfiguration(pointSize: size * 0.28, weight: .bold)
        if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(boltCfg) {
            let tinted = NSImage(size: bolt.size)
            tinted.lockFocus()
            NSColor(red: 1.0, green: 0.88, blue: 0.2, alpha: 1).set()
            bolt.draw(in: NSRect(origin: .zero, size: bolt.size),
                      from: .zero, operation: .sourceAtop, fraction: 1.0)
            tinted.unlockFocus()

            let boltOrigin = NSPoint(x: size * 0.55, y: size * 0.08)
            tinted.draw(at: boltOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()
        return image
    }
}
