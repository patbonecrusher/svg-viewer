import Combine
import SwiftUI
import WebKit

/// Transparent WebKit canvas that renders the SVG inline; all chrome stays native.
struct SVGWebView: NSViewRepresentable {
    @ObservedObject var state: ViewerState
    let background: ResolvedBackground

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeNSView(context: Context) -> ViewerWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "viewer")
        config.preferences.isElementFullscreenEnabled = false

        let webView = ViewerWebView(frame: .zero, configuration: config)
        webView.underPageBackgroundColor = background.base
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        webView.onMagnify = { [weak state] amount in state?.magnify(by: amount) }
        webView.onScrollZoom = { [weak state] delta in
            guard let state else { return }
            state.setZoom(state.zoom * exp(delta * 0.01))
        }
        webView.onSmartMagnify = { [weak state] in state?.toggleFit() }
        webView.onDropFiles = { urls in
            for url in urls {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            }
        }
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(ViewerPage.html(nonce: context.coordinator.nonce), baseURL: nil)

        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ nsView: ViewerWebView, context: Context) {
        nsView.underPageBackgroundColor = background.base
        context.coordinator.setBackground(background.css)
    }

    static func dismantleNSView(_ nsView: ViewerWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "viewer")
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let state: ViewerState
        weak var webView: WKWebView?
        /// Per-instance CSP nonce so SVG content can never smuggle in a script that runs.
        let nonce = UUID().uuidString
        private var ready = false
        private var lastReportedZoom: Double?
        private var backgroundCSS = ""
        private var cancellables = Set<AnyCancellable>()

        init(state: ViewerState) {
            self.state = state
            super.init()

            state.$source
                .dropFirst()
                .sink { [weak self] source in self?.sendSource(source) }
                .store(in: &cancellables)

            state.$fitMode
                .dropFirst()
                .removeDuplicates()
                .sink { [weak self] fit in
                    self?.evaluate(fit ? "viewer.fit()" : "viewer.setFitMode(false)")
                }
                .store(in: &cancellables)

            state.$zoom
                .dropFirst()
                .removeDuplicates()
                .sink { [weak self] zoom in
                    guard let self, !self.state.fitMode, zoom != self.lastReportedZoom else { return }
                    self.evaluate("viewer.setZoom(\(zoom))")
                }
                .store(in: &cancellables)
        }

        private func evaluate(_ js: String) {
            guard ready else { return }
            webView?.evaluateJavaScript(js) { _, error in
                if let error { NSLog("viewer js error: \(error)") }
            }
        }

        func setBackground(_ css: String) {
            guard css != backgroundCSS else { return }
            backgroundCSS = css
            evaluate("viewer.setBackground(\(jsLiteral(css)))")
        }

        private func jsLiteral(_ string: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed]) else { return "\"\"" }
            return String(decoding: data, as: UTF8.self)
        }

        private func sendSource(_ source: String) {
            evaluate("viewer.setSVG(\(jsLiteral(source)))")
        }

        // The only navigation allowed is our own about:blank page. Links inside the SVG open in the browser.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = action.request.url
            if action.navigationType == .other, url?.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }
            if action.navigationType == .linkActivated, let url, ["http", "https", "mailto"].contains(url.scheme ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(response.isForMainFrame ? .allow : .cancel)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            state.errorMessage = "The rendering process stopped unexpectedly (the file may be too complex). Reload to try again."
            ready = false
            webView.loadHTMLString(ViewerPage.html(nonce: nonce), baseURL: nil)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            handle(type: type, body: body)
        }

        private func handle(type: String, body: [String: Any]) {
            switch type {
            case "ready":
                ready = true
                evaluate("viewer.setBackground(\(jsLiteral(backgroundCSS)))")
                sendSource(state.source)
                if state.fitMode {
                    evaluate("viewer.fit()")
                } else {
                    evaluate("viewer.setZoom(\(state.zoom))")
                }
            case "size":
                if let w = body["w"] as? Double, let h = body["h"] as? Double {
                    state.naturalSize = CGSize(width: w, height: h)
                }
                state.errorMessage = nil
            case "zoom":
                if let z = body["value"] as? Double {
                    lastReportedZoom = z
                    if state.zoom != z { state.zoom = z }
                }
            case "error":
                state.errorMessage = body["message"] as? String ?? "Unable to display this file."
            default:
                break
            }
        }
    }
}

/// Breaks the retain cycle WKUserContentController would otherwise create with its handler.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

/// WKWebView subclass routing trackpad gestures to native zoom handling.
final class ViewerWebView: WKWebView {
    var onMagnify: ((Double) -> Void)?
    var onScrollZoom: ((Double) -> Void)?
    var onSmartMagnify: (() -> Void)?
    var onDropFiles: (([URL]) -> Void)?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        // Take over file drops so dragging an SVG onto the window opens it.
        unregisterDraggedTypes()
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func droppedFiles(_ sender: NSDraggingInfo) -> [URL] {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter { ["svg", "svgz"].contains($0.pathExtension.lowercased()) }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = droppedFiles(sender)
        guard !urls.isEmpty else { return false }
        onDropFiles?(urls)
        return true
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(event.magnification)
    }

    override func smartMagnify(with event: NSEvent) {
        onSmartMagnify?()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            onScrollZoom?(event.scrollingDeltaY)
        } else {
            super.scrollWheel(with: event)
        }
    }

    // Keep WebKit's "Reload"/"Inspect" context menu out of a viewer.
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.removeAllItems()
    }
}

enum ViewerPage {
    static func html(nonce: String) -> String {
        template.replacingOccurrences(of: "__NONCE__", with: nonce)
    }

    // CSP: no network, no scripts other than ours (blocks <script>, on* handlers and javascript: URLs
    // inside SVG content), inline styles allowed, data: URIs allowed for embedded bitmaps and fonts.
    private static let template = #"""
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; script-src 'nonce-__NONCE__'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
    <style>
      html, body { margin: 0; height: 100%; overflow: hidden;
                   -webkit-user-select: none; user-select: none; }
      #stage { position: absolute; inset: 0; overflow: auto; }
      #inner { display: flex; min-width: 100%; min-height: 100%; box-sizing: border-box; padding: 24px; }
      #holder { margin: auto; flex: none; line-height: 0; display: block !important; }
    </style>
    </head>
    <body>
    <div id="stage"><div id="inner"><div id="holder"></div></div></div>
    <script nonce="__NONCE__">
    (function () {
      const stage = document.getElementById('stage');
      const holder = document.getElementById('holder');
      // The SVG lives in a shadow root so its <style> rules cannot restyle this page.
      const shadow = holder.attachShadow({ mode: 'open' });
      window.onerror = (msg, src, line) => { post({ type: 'error', message: String(msg) + ' (line ' + line + ')' }); };
      const PAD = 24, MIN = 0.02, MAX = 64;
      let natural = { w: 300, h: 150 }, zoom = 1, fitMode = true, svg = null;

      function post(m) { try { window.webkit.messageHandlers.viewer.postMessage(m); } catch (e) {} }

      const UNITS = { '': 1, px: 1, pt: 96 / 72, pc: 16, mm: 96 / 25.4, cm: 96 / 2.54, in: 96,
                      em: 16, rem: 16, ex: 8, ch: 8, q: 96 / 25.4 / 4 };
      function parseLen(v) {
        if (!v) return null;
        const m = /^\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)\s*([a-z%]*)\s*$/i.exec(v);
        if (!m) return null;
        const u = m[2].toLowerCase();
        if (!(u in UNITS)) return null;            // percentages etc. fall back to viewBox
        const n = parseFloat(m[1]) * UNITS[u];
        return n > 0 ? n : null;
      }

      function measure(el) {
        let w = parseLen(el.getAttribute('width'));
        let h = parseLen(el.getAttribute('height'));
        const vb = el.viewBox && el.viewBox.baseVal;
        const hasVB = vb && vb.width > 0 && vb.height > 0;
        if (hasVB) {
          if (w == null && h == null) { w = vb.width; h = vb.height; }
          else if (w == null) { w = h * vb.width / vb.height; }
          else if (h == null) { h = w * vb.height / vb.width; }
        }
        if (w == null || h == null) {
          let b = null;
          try { b = el.getBBox(); } catch (e) {}
          if (b && b.width > 0 && b.height > 0) {
            if (w == null && h == null) { w = b.x + b.width; h = b.y + b.height; }
            else if (w == null) { w = h * b.width / b.height; }
            else { h = w * b.height / b.width; }
          }
          w = w || 300; h = h || 150;
        }
        return { w: w, h: h };
      }

      function apply() {
        if (!svg) return;
        const W = natural.w * zoom, H = natural.h * zoom;
        // !important so a stylesheet inside the SVG cannot override the viewer's sizing.
        svg.style.setProperty('width', W + 'px', 'important');
        svg.style.setProperty('height', H + 'px', 'important');
        svg.style.setProperty('display', 'block', 'important');
        holder.style.width = W + 'px';
        holder.style.height = H + 'px';
      }

      function setZoom(z, keepCenter) {
        z = Math.min(MAX, Math.max(MIN, z));
        const oldW = natural.w * zoom, oldH = natural.h * zoom;
        const cx = oldW ? (stage.scrollLeft + stage.clientWidth / 2) / oldW : 0.5;
        const cy = oldH ? (stage.scrollTop + stage.clientHeight / 2) / oldH : 0.5;
        zoom = z;
        apply();
        if (keepCenter !== false) {
          stage.scrollLeft = cx * natural.w * zoom - stage.clientWidth / 2;
          stage.scrollTop = cy * natural.h * zoom - stage.clientHeight / 2;
        }
        post({ type: 'zoom', value: zoom });
      }

      function parse(src) {
        try {
          const doc = new DOMParser().parseFromString(src, 'image/svg+xml');
          const err = doc.querySelector('parsererror');
          if (!err && doc.documentElement && doc.documentElement.localName === 'svg') {
            return { node: document.importNode(doc.documentElement, true) };
          }
          // Fall back to the lenient HTML parser for slightly malformed files.
          const tmp = document.createElement('div');
          tmp.innerHTML = src;
          const el = tmp.querySelector('svg');
          if (el) return { node: el };
          return { error: err ? err.textContent.split('\n')[0] : 'No <svg> element found in this file.' };
        } catch (e) {
          return { error: String(e) };
        }
      }

      window.viewer = {
        setSVG(src) {
          shadow.textContent = '';
          svg = null;
          const r = parse(src);
          if (r.error) { post({ type: 'error', message: r.error }); return; }
          svg = r.node;
          shadow.appendChild(svg);
          natural = measure(svg);
          if (!(svg.viewBox && svg.viewBox.baseVal && svg.viewBox.baseVal.width > 0)) {
            // Without a viewBox, CSS sizing would not scale the content.
            svg.setAttribute('viewBox', '0 0 ' + natural.w + ' ' + natural.h);
          }
          post({ type: 'size', w: natural.w, h: natural.h });
          if (fitMode) this.fit(); else setZoom(zoom, false);
        },
        setBackground(css) { document.body.style.cssText = css; },
        setZoom(z) { fitMode = false; setZoom(z, true); },
        setFitMode(f) { fitMode = !!f; if (fitMode) this.fit(); },
        fit() {
          fitMode = true;
          if (!svg) return;
          const z = Math.min((stage.clientWidth - 2 * PAD) / natural.w,
                             (stage.clientHeight - 2 * PAD) / natural.h);
          setZoom(z > 0 ? z : 1, false);
        }
      };

      new ResizeObserver(() => { if (fitMode) window.viewer.fit(); }).observe(stage);
      document.addEventListener('dragover', e => e.preventDefault());
      document.addEventListener('drop', e => e.preventDefault());
      post({ type: 'ready' });
    })();
    </script>
    </body>
    </html>
    """#
}
