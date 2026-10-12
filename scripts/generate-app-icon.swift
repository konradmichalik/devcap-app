// Renders the app icon PNGs. Usage:
//   swift scripts/generate-app-icon.swift DevcapApp/Assets.xcassets/AppIcon.appiconset

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha,
        ]
    )!
}

func render(size: Int, draw: (CGContext, CGFloat) -> Void) -> CGImage {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
    draw(context, CGFloat(size))
    return context.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("write failed: \(path)") }
}

/// Keep the geometry in sync with `DevcapGlyph` (DevcapApp/Views/DevcapBrand.swift).
/// The glyph in its 64 unit space. Content bounds are x 14.5...49.5, y 6.5...57.5.
func drawGlyph(_ c: CGContext, unit: CGFloat, origin: CGPoint, tint: CGColor, accent: CGColor) {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * unit, y: origin.y + y * unit) }

    c.setLineWidth(7 * unit)
    c.setLineCap(.round)
    c.setStrokeColor(tint)
    c.strokeEllipse(in: CGRect(x: p(18, 26).x, y: p(18, 26).y, width: 28 * unit, height: 28 * unit))
    c.move(to: p(46, 54))
    c.addLine(to: p(46, 12))
    c.strokePath()

    c.setFillColor(accent)
    c.fillEllipse(in: CGRect(x: p(40.5, 6.5).x, y: p(40.5, 6.5).y, width: 11 * unit, height: 11 * unit))
}

func appIcon(size: Int) -> CGImage {
    render(size: size) { c, s in
        let f = s / 1024
        let body = CGRect(x: 100 * f, y: 100 * f, width: 824 * f, height: 824 * f)
        let path = CGPath(roundedRect: body, cornerWidth: 184 * f, cornerHeight: 184 * f, transform: nil)

        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 12 * f), blur: 28 * f, color: color(0x000000, 0.35))
        c.addPath(path)
        c.setFillColor(color(0x12141A))
        c.fillPath()
        c.restoreGState()

        c.saveGState()
        c.addPath(path)
        c.clip()
        let gradient = CGGradient(
            colorsSpace: space, colors: [color(0x2A303A), color(0x12141A)] as CFArray, locations: [0, 1]
        )!
        c.drawLinearGradient(
            gradient, start: CGPoint(x: body.minX, y: body.minY), end: CGPoint(x: body.maxX, y: body.maxY), options: []
        )
        c.addPath(path)
        c.setStrokeColor(color(0xFFFFFF, 0.12))
        c.setLineWidth(4 * f)
        c.strokePath()
        c.restoreGState()

        let unit = (824 * 0.53 * f) / 51
        let origin = CGPoint(x: s / 2 - 32 * unit, y: s / 2 - 32 * unit)
        drawGlyph(c, unit: unit, origin: origin, tint: color(0xF4F5F7), accent: color(0x5EEAD4))
    }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/generate-app-icon.swift <AppIcon.appiconset>\n".utf8))
    exit(1)
}
let base = CommandLine.arguments[1]
for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(appIcon(size: size), to: "\(base)/icon_\(size)x\(size).png")
}
