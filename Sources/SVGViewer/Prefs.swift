import SwiftUI

enum Prefs {
    static let background = "background"
    static let customColor = "customColor"
    static let checkerSize = "checkerSize"
    static let openZoom = "openZoom"
    static let zoomStep = "zoomStep"
    static let autoReload = "autoReload"
    static let showStatusBar = "showStatusBar"
    static let exportScale = "exportScale"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            background: BackgroundStyle.checkerboard.rawValue,
            customColor: "#FFFFFF",
            checkerSize: 12,
            openZoom: OpenZoom.fit.rawValue,
            zoomStep: 1.25,
            autoReload: true,
            showStatusBar: true,
            exportScale: 2,
        ])
    }
}

enum OpenZoom: String, CaseIterable, Identifiable {
    case fit, actual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fit: "Zoom to Fit"
        case .actual: "Actual Size"
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case checkerboard, light, dark, window, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .checkerboard: "Checkerboard"
        case .light: "Light"
        case .dark: "Dark"
        case .window: "Window"
        case .custom: "Custom Color"
        }
    }

    var symbol: String {
        switch self {
        case .checkerboard: "checkerboard.rectangle"
        case .light: "sun.max"
        case .dark: "moon"
        case .window: "macwindow"
        case .custom: "paintpalette"
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let r = CGFloat((v >> (hasAlpha ? 24 : 16)) & 0xff) / 255
        let g = CGFloat((v >> (hasAlpha ? 16 : 8)) & 0xff) / 255
        let b = CGFloat((v >> (hasAlpha ? 8 : 0)) & 0xff) / 255
        let a = hasAlpha ? CGFloat(v & 0xff) / 255 : 1
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
