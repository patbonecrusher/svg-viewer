import SwiftUI

struct ContentView: View {
    @StateObject private var state: ViewerState
    @AppStorage(Prefs.showStatusBar) private var showStatusBar = true
    @AppStorage(Prefs.background) private var defaultBackground = BackgroundStyle.checkerboard
    @AppStorage(Prefs.customColor) private var customColorHex = "#FFFFFF"
    @AppStorage(Prefs.checkerSize) private var checkerSize = 12
    @Environment(\.colorScheme) private var colorScheme

    init(document: SVGDocument, fileURL: URL?) {
        _state = StateObject(wrappedValue: ViewerState(source: document.text, fileURL: fileURL))
    }

    private var background: Binding<BackgroundStyle> {
        Binding(get: { state.background ?? defaultBackground },
                set: { state.background = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                let resolved = ResolvedBackground(style: background.wrappedValue, customHex: customColorHex,
                                                  checkerSize: checkerSize, dark: colorScheme == .dark)
                Color(nsColor: resolved.base)
                SVGWebView(state: state, background: resolved)
                if let message = state.errorMessage {
                    ContentUnavailableView {
                        Label("Can’t Display SVG", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Reload") { state.reload() }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(40)
                }
            }
            if showStatusBar {
                Divider()
                StatusBar(state: state)
            }
        }
        .toolbar { ViewerToolbar(state: state, background: background) }
        .inspector(isPresented: $state.showSource) {
            SourceView(text: state.source)
                .inspectorColumnWidth(min: 260, ideal: 400, max: 900)
        }
        .focusedSceneValue(\.viewerState, state)
    }
}

struct ViewerToolbar: ToolbarContent {
    @ObservedObject var state: ViewerState
    let background: Binding<BackgroundStyle>

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                Picker("Background", selection: background) {
                    ForEach(BackgroundStyle.allCases) { style in
                        Label(style.title, systemImage: style.symbol).tag(style)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Background", systemImage: background.wrappedValue.symbol)
            }
            .help("Canvas background")
        }

        ToolbarItemGroup(placement: .automatic) {
            Button { state.zoomOut() } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                .help("Zoom Out (⌘−)")

            Menu {
                ForEach(ViewerState.presetZooms, id: \.self) { z in
                    Button("\(Int(z * 100))%") { state.setZoom(z) }
                }
                Divider()
                Button("Zoom to Fit") { state.zoomToFit() }
            } label: {
                Text(state.zoomText)
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .help("Zoom level")

            Button { state.zoomIn() } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
                .help("Zoom In (⌘+)")

            Toggle(isOn: Binding(get: { state.fitMode }, set: { _ in state.toggleFit() })) {
                Label("Zoom to Fit", systemImage: "arrow.down.right.and.arrow.up.left.rectangle")
            }
            .help(state.fitMode ? "Actual Size (⌘0)" : "Zoom to Fit (⌘9)")
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $state.showSource) {
                Label("Source", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .help("Show SVG source (⌥⌘U)")
        }
    }
}

struct StatusBar: View {
    @ObservedObject var state: ViewerState

    private var dimensions: String {
        guard state.naturalSize.width > 0 else { return "—" }
        let f = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2))
        return "\(state.naturalSize.width.formatted(f)) × \(state.naturalSize.height.formatted(f)) pt"
    }

    var body: some View {
        HStack(spacing: 16) {
            Label(dimensions, systemImage: "ruler")
            if let size = state.fileSize {
                Label(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file), systemImage: "doc")
            }
            Spacer()
            Text(state.fitMode ? "\(state.zoomText) · Fit" : state.zoomText)
                .monospacedDigit()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }
}

/// The canvas background, resolved to concrete colors so the page can paint it with CSS.
struct ResolvedBackground: Equatable {
    let base: NSColor
    let css: String

    init(style: BackgroundStyle, customHex: String, checkerSize: Int, dark: Bool) {
        switch style {
        case .checkerboard:
            let a = dark ? NSColor(white: 0.16, alpha: 1) : .white
            let b = dark ? NSColor(white: 0.22, alpha: 1) : NSColor(white: 0.85, alpha: 1)
            let s = checkerSize
            let tile = "linear-gradient(45deg, \(b.hexString) 25%, transparent 25%, transparent 75%, \(b.hexString) 75%)"
            base = a
            css = "background-color: \(a.hexString); background-image: \(tile), \(tile); "
                + "background-size: \(2 * s)px \(2 * s)px; background-position: 0 0, \(s)px \(s)px;"
        case .light:
            base = .white
            css = "background: #FFFFFF;"
        case .dark:
            base = .black
            css = "background: #000000;"
        case .window:
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            var color = NSColor.windowBackgroundColor
            appearance?.performAsCurrentDrawingAppearance {
                color = NSColor(cgColor: NSColor.windowBackgroundColor.cgColor) ?? .windowBackgroundColor
            }
            base = color
            css = "background: \(color.hexString);"
        case .custom:
            let color = NSColor(hex: customHex) ?? .white
            base = color
            css = "background: \(color.hexString);"
        }
    }
}
