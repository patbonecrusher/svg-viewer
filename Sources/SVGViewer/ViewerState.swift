import AppKit
import Combine
import SwiftUI

/// Per-window state: the SVG source plus zoom/background/inspector settings.
@MainActor
final class ViewerState: ObservableObject {
    @Published var source: String
    @Published var zoom: Double = 1
    @Published var fitMode: Bool
    @Published var naturalSize: CGSize = .zero
    @Published var background: BackgroundStyle?      // nil = follow the default in Settings
    @Published var showSource = false
    @Published var errorMessage: String?
    @Published private(set) var fileSize: Int?

    let fileURL: URL?
    private var watcher: FileWatcher?

    static let minZoom = 0.02
    static let maxZoom = 64.0
    static let presetZooms: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 8]

    init(source: String, fileURL: URL?) {
        self.source = source
        self.fileURL = fileURL
        self.fitMode = UserDefaults.standard.string(forKey: Prefs.openZoom) != OpenZoom.actual.rawValue
        // Launch argument `-showSource YES` opens the inspector (handy for testing and screenshots).
        self.showSource = UserDefaults.standard.bool(forKey: "showSource")
        updateFileSize()
        if let url = fileURL {
            watcher = FileWatcher(url: url) { [weak self] in
                guard UserDefaults.standard.bool(forKey: Prefs.autoReload) else { return }
                self?.reload()
            }
        }
    }

    // MARK: Zoom

    private var zoomStep: Double {
        let s = UserDefaults.standard.double(forKey: Prefs.zoomStep)
        return s > 1 ? s : 1.25
    }

    func zoomIn() { setZoom(zoom * zoomStep) }
    func zoomOut() { setZoom(zoom / zoomStep) }
    func actualSize() { setZoom(1) }
    func zoomToFit() { fitMode = true }
    func toggleFit() { fitMode ? actualSize() : zoomToFit() }
    func magnify(by amount: Double) { setZoom(zoom * (1 + amount)) }

    func setZoom(_ z: Double) {
        fitMode = false
        zoom = min(max(z, Self.minZoom), Self.maxZoom)
    }

    var zoomText: String { "\(Int((zoom * 100).rounded()))%" }

    // MARK: File actions

    func reload() {
        guard let url = fileURL else { return }
        do {
            source = try SVGDocument.decode(try Data(contentsOf: url))
            errorMessage = nil
            updateFileSize()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateFileSize() {
        guard let url = fileURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return }
        fileSize = attrs[.size] as? Int
    }

    func revealInFinder() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copySource() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(source, forType: .string)
    }

    func copyImage() {
        do {
            let rep = try SVGRenderer.bitmap(source: source, size: renderSize, scale: 2, background: nil)
            let image = NSImage(size: rep.size)
            image.addRepresentation(rep)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([image])
        } catch {
            presentError(error)
        }
    }

    func exportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? "Image") + ".png"

        let options = ExportOptions()
        let accessory = NSHostingView(rootView: ExportAccessoryView(options: options))
        accessory.frame = NSRect(origin: .zero, size: accessory.fittingSize)
        panel.accessoryView = accessory

        let size = renderSize
        let source = source
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try SVGRenderer.pngData(source: source, size: size,
                                                   scale: Double(options.scale),
                                                   background: options.opaque ? .white : nil)
                try data.write(to: url, options: .atomic)
            } catch {
                self?.presentError(error)
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    /// Size used for rasterizing; falls back to a sane default when the SVG has no measurable size.
    private var renderSize: CGSize {
        naturalSize.width > 0 && naturalSize.height > 0 ? naturalSize : CGSize(width: 512, height: 512)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

final class ExportOptions: ObservableObject {
    @Published var scale: Int = max(1, UserDefaults.standard.integer(forKey: Prefs.exportScale))
    @Published var opaque = false
}

struct ExportAccessoryView: View {
    @ObservedObject var options: ExportOptions

    var body: some View {
        Form {
            Picker("Scale:", selection: $options.scale) {
                ForEach([1, 2, 3, 4], id: \.self) { Text("\($0)×").tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("White background", isOn: $options.opaque)
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - Focused value plumbing so menu commands act on the key window.

struct ViewerStateKey: FocusedValueKey {
    typealias Value = ViewerState
}

extension FocusedValues {
    var viewerState: ViewerState? {
        get { self[ViewerStateKey.self] }
        set { self[ViewerStateKey.self] = newValue }
    }
}
