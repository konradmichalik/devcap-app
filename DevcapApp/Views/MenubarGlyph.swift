import AppKit

/// The menu bar icon, drawn from the same 64 unit geometry as `DevcapGlyph`.
/// Monochrome states are template images, so the system tints them for light,
/// dark and wallpaper-tinted menu bars. Only `.fresh` carries a color.
enum MenubarGlyph {
    private static let side: CGFloat = 16

    static func image(for state: MenubarIconState, pulse: Bool = true) -> NSImage {
        let isTemplate = state != .fresh
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            draw(state: state, pulse: pulse, in: rect)
            return true
        }
        image.isTemplate = isTemplate
        image.accessibilityDescription = "devcap"
        return image
    }

    private static func draw(state: MenubarIconState, pulse: Bool, in rect: NSRect) {
        let unit = rect.height * 0.92 / GlyphGeometry.contentHeight
        let transform = GlyphGeometry.transform(
            unit: unit, origin: CGPoint(x: rect.midX - 32 * unit, y: rect.midY - 32 * unit)
        )

        (state == .fresh ? ink : NSColor.black).setStroke()

        let ring = NSBezierPath(ovalIn: GlyphGeometry.ring.applying(transform))
        ring.lineWidth = GlyphGeometry.lineWidth * unit
        ring.stroke()

        let stem = NSBezierPath()
        stem.move(to: GlyphGeometry.stemBottom.applying(transform))
        stem.line(to: GlyphGeometry.stemTop.applying(transform))
        stem.lineWidth = GlyphGeometry.lineWidth * unit
        stem.lineCapStyle = .round
        stem.stroke()

        // Replace instead of blend, so a dimmed dot does not show the stem through it.
        NSGraphicsContext.current?.compositingOperation = .copy
        dotColor(for: state, pulse: pulse).setFill()
        NSBezierPath(ovalIn: GlyphGeometry.dot.applying(transform)).fill()
    }

    /// Opaque, unlike `labelColor`, so ring and stem do not darken where they overlap.
    private static let ink = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
    }

    private static func dotColor(for state: MenubarIconState, pulse: Bool) -> NSColor {
        switch state {
        case .normal: NSColor.black
        case .empty: NSColor.black.withAlphaComponent(0.35)
        case .scanning: NSColor.black.withAlphaComponent(pulse ? 1 : 0.3)
        case .fresh: NSColor.brandMint
        }
    }
}
