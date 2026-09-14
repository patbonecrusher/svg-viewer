import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let svgz = UTType(importedAs: "com.patlaplante.svgz")
}

struct SVGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.svg, .svgz] }

    var text: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = try Self.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    /// Turns raw file bytes (optionally gzip-compressed) into SVG source text.
    static func decode(_ raw: Data) throws -> String {
        let data = try gunzipIfNeeded(raw)
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    private static func gunzipIfNeeded(_ d: Data) throws -> Data {
        guard d.count > 18, d[d.startIndex] == 0x1f, d[d.startIndex + 1] == 0x8b else { return d }
        guard d[d.startIndex + 2] == 8 else { throw CocoaError(.fileReadCorruptFile) }
        let bytes = [UInt8](d)
        let flags = bytes[3]
        var i = 10
        if flags & 0x04 != 0 {                      // FEXTRA
            let xlen = Int(bytes[i]) | Int(bytes[i + 1]) << 8
            i += 2 + xlen
        }
        if flags & 0x08 != 0 {                      // FNAME
            while i < bytes.count, bytes[i] != 0 { i += 1 }
            i += 1
        }
        if flags & 0x10 != 0 {                      // FCOMMENT
            while i < bytes.count, bytes[i] != 0 { i += 1 }
            i += 1
        }
        if flags & 0x02 != 0 { i += 2 }             // FHCRC
        guard i < bytes.count - 8 else { throw CocoaError(.fileReadCorruptFile) }
        let body = Data(bytes[i..<(bytes.count - 8)])
        // gzip payload is raw DEFLATE, which is what Apple's .zlib algorithm expects.
        return try (body as NSData).decompressed(using: .zlib) as Data
    }
}
