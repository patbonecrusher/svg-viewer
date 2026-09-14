import SwiftUI

struct ViewerCommands: Commands {
    @FocusedValue(\.viewerState) private var state
    @AppStorage(Prefs.background) private var defaultBackground = BackgroundStyle.checkerboard

    private var background: Binding<BackgroundStyle> {
        Binding(get: { state?.background ?? defaultBackground },
                set: { state?.background = $0 })
    }

    private var showSource: Binding<Bool> {
        Binding(get: { state?.showSource ?? false },
                set: { state?.showSource = $0 })
    }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Export as PNG…") { state?.exportPNG() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(state == nil)
            Button("Reveal in Finder") { state?.revealInFinder() }
                .disabled(state?.fileURL == nil)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Image") { state?.copyImage() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(state == nil)
            Button("Copy SVG Source") { state?.copySource() }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(state == nil)
        }

        CommandGroup(before: .toolbar) {
            Button("Zoom In") { state?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(state == nil)
            Button("Zoom Out") { state?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(state == nil)
            Button("Actual Size") { state?.actualSize() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(state == nil)
            Button("Zoom to Fit") { state?.zoomToFit() }
                .keyboardShortcut("9", modifiers: .command)
                .disabled(state == nil)
            Divider()
            Menu("Background") {
                Picker("Background", selection: background) {
                    ForEach(BackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.inline)
            }
            .disabled(state == nil)
            Divider()
            Toggle("Show Source", isOn: showSource)
                .keyboardShortcut("u", modifiers: [.command, .option])
                .disabled(state == nil)
            Button("Reload") { state?.reload() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state?.fileURL == nil)
            Divider()
        }
    }
}
