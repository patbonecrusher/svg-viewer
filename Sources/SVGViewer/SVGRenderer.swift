import AppKit

/// Rasterizes SVG source with the system's native SVG support (NSImage/CoreSVG).
enum SVGRenderer {
    struct RenderError: LocalizedError {
        let errorDescription: String?
    }

    static func bitmap(source: String, size: CGSize, scale: Double, background: NSColor?) throws -> NSBitmapImageRep {
        guard let image = NSImage(data: Data(source.utf8)) else {
            throw RenderError(errorDescription: "This SVG could not be rasterized by the system renderer.")
        }
        image.size = size

        let pw = max(1, Int((size.width * scale).rounded()))
        let ph = max(1, Int((size.height * scale).rounded()))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            throw RenderError(errorDescription: "Could not create a bitmap of \(pw)×\(ph) pixels.")
        }
        rep.size = NSSize(width: pw, height: ph)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high

        let rect = NSRect(x: 0, y: 0, width: pw, height: ph)
        if let background {
            background.setFill()
            rect.fill()
        }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        ctx.flushGraphics()
        return rep
    }

    static func pngData(source: String, size: CGSize, scale: Double, background: NSColor?) throws -> Data {
        let rep = try bitmap(source: source, size: size, scale: scale, background: background)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw RenderError(errorDescription: "PNG encoding failed.")
        }
        return data
    }
}
