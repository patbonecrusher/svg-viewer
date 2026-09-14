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
