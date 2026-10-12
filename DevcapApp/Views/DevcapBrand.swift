import SwiftUI

extension NSColor {
    /// Teal on light backgrounds, mint on dark ones, so the accent keeps contrast in both.
    static let brandMint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.369, green: 0.918, blue: 0.831, alpha: 1)
            : NSColor(srgbRed: 0.059, green: 0.624, blue: 0.541, alpha: 1)
    }
}

extension Color {
    static let brandMint = Color(nsColor: .brandMint)
}

/// Geometry of the mark in a 64 unit space. The app icon script keeps its own copy
/// (`scripts/generate-app-icon.swift`), because it cannot import app code.
enum GlyphGeometry {
    static let ring = CGRect(x: 18, y: 26, width: 28, height: 28)
    static let stemBottom = CGPoint(x: 46, y: 54)
    static let stemTop = CGPoint(x: 46, y: 12)
    static let dot = CGRect(x: 40.5, y: 6.5, width: 11, height: 11)
    static let lineWidth: CGFloat = 7
    /// Height of the drawn mark, to fit it into a box.
    static let contentHeight: CGFloat = 51

    static func transform(unit: CGFloat, origin: CGPoint = .zero) -> CGAffineTransform {
        CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: unit, y: unit)
    }
}

/// The devcap mark: a lowercase "d" built from a commit node (ring) and the
/// history line (stem), topped by the latest commit (dot). Drawn in a 64 unit
/// space so it stays in sync with the generated app and menu bar icons.
struct DevcapGlyph: View {
    var size: CGFloat
    var tint: Color = .primary
    var accent: Color = Color.brandMint

    var body: some View {
        Canvas { context, canvasSize in
            let unit = min(canvasSize.width, canvasSize.height) / 64
            let transform = GlyphGeometry.transform(unit: unit)
            let stroke = StrokeStyle(lineWidth: GlyphGeometry.lineWidth * unit, lineCap: .round)

            var stem = Path()
            stem.move(to: GlyphGeometry.stemBottom.applying(transform))
            stem.addLine(to: GlyphGeometry.stemTop.applying(transform))

            context.stroke(Path(ellipseIn: GlyphGeometry.ring.applying(transform)), with: .color(tint), style: stroke)
            context.stroke(stem, with: .color(tint), style: stroke)
            context.fill(Path(ellipseIn: GlyphGeometry.dot.applying(transform)), with: .color(accent))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct DevcapWordmark: View {
    var size: CGFloat = 17
    var showsGlyph = true

    var body: some View {
        HStack(spacing: size * 0.4) {
            if showsGlyph {
                DevcapGlyph(size: size * 1.2)
            }
            HStack(spacing: -size * 0.03) {
                Text("dev").fontWeight(.light)
                Text("cap").fontWeight(.heavy)
            }
            .font(.system(size: size))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("devcap")
    }
}
