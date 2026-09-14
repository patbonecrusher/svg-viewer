import Foundation

/// Watches a file for changes, surviving atomic saves (rename/replace) done by most editors.
final class FileWatcher {
    private let url: URL
    private let handler: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(url: URL, handler: @escaping @MainActor () -> Void) {
        self.url = url
        self.handler = handler
        start()
    }

    deinit { stop() }

    private func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self, let current = self.source else { return }
            let events = current.data
            if events.contains(.delete) || events.contains(.rename) {
                // The editor replaced the file; re-open the new inode once it settles.
                self.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.start()
                    self?.fire()
                }
            } else {
                self.fire()
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func stop() {
        source?.cancel()
        source = nil
    }

    private func fire() {
        pending?.cancel()
        let work = DispatchWorkItem { [handler] in
            Task { @MainActor in handler() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
