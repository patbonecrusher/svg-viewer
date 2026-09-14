import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 460)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Prefs.openZoom) private var openZoom = OpenZoom.fit
    @AppStorage(Prefs.zoomStep) private var zoomStep = 1.25
    @AppStorage(Prefs.autoReload) private var autoReload = true
    @AppStorage(Prefs.showStatusBar) private var showStatusBar = true
    @AppStorage(Prefs.exportScale) private var exportScale = 2

    var body: some View {
        Form {
            Picker("When opening a file:", selection: $openZoom) {
                ForEach(OpenZoom.allCases) { Text($0.title).tag($0) }
            }
            Picker("Zoom step:", selection: $zoomStep) {
                Text("10%").tag(1.1)
                Text("25%").tag(1.25)
                Text("50%").tag(1.5)
                Text("100%").tag(2.0)
            }
            Toggle("Show status bar", isOn: $showStatusBar)
            Toggle("Reload automatically when the file changes on disk", isOn: $autoReload)
            Picker("Default export scale:", selection: $exportScale) {
                ForEach([1, 2, 3, 4], id: \.self) { Text("\($0)×").tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .frame(height: 300)
    }
}

private struct AppearanceSettings: View {
    @AppStorage(Prefs.background) private var background = BackgroundStyle.checkerboard
    @AppStorage(Prefs.customColor) private var customColorHex = "#FFFFFF"
    @AppStorage(Prefs.checkerSize) private var checkerSize = 12

    private var customColor: Binding<Color> {
        Binding(get: { Color(nsColor: NSColor(hex: customColorHex) ?? .white) },
                set: { customColorHex = NSColor($0).hexString })
    }

    var body: some View {
        Form {
            Picker("Default background:", selection: $background) {
                ForEach(BackgroundStyle.allCases) { style in
                    Label(style.title, systemImage: style.symbol).tag(style)
                }
            }
            .pickerStyle(.radioGroup)
            ColorPicker("Custom color:", selection: customColor, supportsOpacity: false)
                .disabled(background != .custom)
            Picker("Checkerboard size:", selection: $checkerSize) {
                Text("Small").tag(8)
                Text("Medium").tag(12)
                Text("Large").tag(20)
            }
            .disabled(background != .checkerboard)
            Text("The background can be overridden per window from the View menu or the toolbar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(height: 300)
    }
}
