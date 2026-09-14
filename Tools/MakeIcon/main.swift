// Generates the app icon (an .iconset folder) with CoreGraphics so the build has no binary assets.
import AppKit

let args = CommandLine.arguments
guard args.count > 1 else {
    FileHandle.standardError.write(Data("usage: MakeIcon <output.iconset>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Draws the icon in a 1024×1024 coordinate space (origin bottom-left).
func drawIcon(in ctx: CGContext, pixels: CGFloat) {
    ctx.scaleBy(x: pixels / 1024, y: pixels / 1024)

    // macOS icon grid: 824pt rounded square centered in the 1024 canvas.
    let square = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: square, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.30))
    ctx.setFillColor(rgb(40, 40, 60))
    ctx.addPath(shape)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: space,
                              colors: [rgb(255, 140, 66), rgb(233, 64, 112), rgb(120, 60, 190)] as CFArray,
                              locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 160, y: 900), end: CGPoint(x: 880, y: 140), options: [])

    // Subtle grid to suggest a canvas.
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.10))
    ctx.setLineWidth(3)
    for i in stride(from: 100.0, through: 924.0, by: 103) {
        ctx.move(to: CGPoint(x: i, y: 100)); ctx.addLine(to: CGPoint(x: i, y: 924))
        ctx.move(to: CGPoint(x: 100, y: i)); ctx.addLine(to: CGPoint(x: 924, y: i))
    }
    ctx.strokePath()

    // A Bézier path with anchors and handles: the universal "vector" glyph.
    let a0 = CGPoint(x: 270, y: 330), a1 = CGPoint(x: 754, y: 694)
    let c0 = CGPoint(x: 270, y: 720), c1 = CGPoint(x: 754, y: 304)

    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.55))
    ctx.setLineWidth(12)
    ctx.setLineCap(.round)
    ctx.move(to: a0); ctx.addLine(to: c0)
    ctx.move(to: a1); ctx.addLine(to: c1)
    ctx.strokePath()

    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: CGColor(gray: 0, alpha: 0.25))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
    ctx.setLineWidth(58)
    ctx.move(to: a0)
    ctx.addCurve(to: a1, control1: c0, control2: c1)
    ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Anchor points (filled circles) and control points (hollow squares).
    for p in [a0, a1] {
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: p.x - 46, y: p.y - 46, width: 92, height: 92))
        ctx.setFillColor(rgb(233, 64, 112))
        ctx.fillEllipse(in: CGRect(x: p.x - 24, y: p.y - 24, width: 48, height: 48))
    }
    for p in [c0, c1] {
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: p.x - 34, y: p.y - 34, width: 68, height: 68))
    }
    ctx.restoreGState()
}

let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

for v in variants {
    let px = v.points * v.scale
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let gc = NSGraphicsContext(bitmapImageRep: rep) else { exit(2) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    drawIcon(in: gc.cgContext, pixels: CGFloat(px))
    gc.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(v.points)x\(v.points)\(v.scale == 2 ? "@2x" : "").png"
    try rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}
print("wrote \(variants.count) icon sizes to \(outDir.path)")
