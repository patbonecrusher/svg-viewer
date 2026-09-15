import SwiftUI

@main
struct SVGViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(viewing: SVGDocument.self) { config in
            ContentView(document: config.document, fileURL: config.fileURL)
        }
        .defaultSize(width: 960, height: 720)
        .commands { ViewerCommands() }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        Prefs.registerDefaults()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Debug/screenshot hooks: `-preferRetina YES` moves new windows to the highest-density screen,
        // `-windowSize 1280x800` sets their size. Both are no-ops unless passed on the command line.
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "preferRetina") || defaults.string(forKey: "windowSize") != nil else { return }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow, window.isVisible, !window.styleMask.contains(.utilityWindow) else { return }
            var frame = window.frame
            if let spec = defaults.string(forKey: "windowSize") {
                let parts = spec.lowercased().split(separator: "x").compactMap { Double($0) }
                if parts.count == 2 { frame.size = NSSize(width: parts[0], height: parts[1]) }
            }
            if defaults.bool(forKey: "preferRetina"),
               let screen = NSScreen.screens.max(by: { $0.backingScaleFactor < $1.backingScaleFactor }) {
                let v = screen.visibleFrame
                frame.origin = NSPoint(x: v.midX - frame.width / 2, y: v.midY - frame.height / 2)
            }
            window.setFrame(frame, display: true)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // A viewer has nothing to show in an untitled window; offer the Open panel instead.
        NSDocumentController.shared.openDocument(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSDocumentController.shared.openDocument(nil) }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
