import SwiftUI

extension Color {
    /// Teal on light backgrounds, mint on dark ones, so the accent keeps contrast in both.
    static let brandMint = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.369, green: 0.918, blue: 0.831, alpha: 1)
            : NSColor(srgbRed: 0.059, green: 0.624, blue: 0.541, alpha: 1)
    })
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
            let stroke = StrokeStyle(lineWidth: 7 * unit, lineCap: .round)
            let ring = CGRect(x: 18 * unit, y: 26 * unit, width: 28 * unit, height: 28 * unit)

            var stem = Path()
            stem.move(to: CGPoint(x: 46 * unit, y: 54 * unit))
            stem.addLine(to: CGPoint(x: 46 * unit, y: 12 * unit))

            context.stroke(Path(ellipseIn: ring), with: .color(tint), style: stroke)
            context.stroke(stem, with: .color(tint), style: stroke)
            context.fill(
                Path(ellipseIn: CGRect(x: 40.5 * unit, y: 6.5 * unit, width: 11 * unit, height: 11 * unit)),
                with: .color(accent)
            )
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
