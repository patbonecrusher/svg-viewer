# SVG Viewer

A native macOS viewer for `.svg` / `.svgz` files, written in Swift (SwiftUI + AppKit).
Rendering uses WebKit for full SVG fidelity (CSS, filters, gradients, fonts); everything
around it — menus, toolbar, Settings, document handling — is standard macOS.

## Build

```sh
./build.sh            # release build → build/SVG Viewer.app
./build.sh --open     # …and launch it
./build.sh debug
```

Requires Xcode 15+ (macOS 14 deployment target). No Xcode project — it's a Swift Package,
and `build.sh` assembles the `.app` bundle (Info.plist, generated icon, sandbox entitlements, signature).
Copy `build/SVG Viewer.app` to `/Applications` to make it available in Finder's *Open With*.

Signed / notarized / App Store builds: see [RELEASING.md](RELEASING.md).

## Features

- Document-based: Open, Open Recent, multiple windows, drag files onto the Dock icon or window
- Zoom in/out (⌘+ / ⌘−), actual size (⌘0), zoom to fit (⌘9), preset zoom levels,
  pinch-to-zoom, ⌘-scroll to zoom, double-tap to toggle fit/actual
- Backgrounds: checkerboard, light, dark, window, custom color (default in Settings, per-window override in View menu/toolbar)
- Source inspector (⌥⌘U) with Find (⌘F)
- Reloads automatically when the file changes on disk (⌘R to force)
- Export as PNG… (⇧⌘E) at 1–4×, Copy Image (⇧⌘C), Copy SVG Source (⌥⌘C), Reveal in Finder
- Settings (⌘,): default zoom on open, zoom step, status bar, auto-reload, export scale, background

## Layout

| Path | Purpose |
| --- | --- |
| `Sources/SVGViewer/SVGViewerApp.swift` | App entry, `DocumentGroup`, Settings scene, app delegate |
| `Sources/SVGViewer/SVGDocument.swift` | `FileDocument` for svg/svgz (gzip decoding) |
| `Sources/SVGViewer/ViewerState.swift` | Per-window state: zoom, background, export/copy actions |
| `Sources/SVGViewer/SVGWebView.swift` | Transparent `WKWebView` + JS zoom/fit engine, gesture handling |
| `Sources/SVGViewer/ContentView.swift` | Main view, toolbar, status bar, backgrounds |
| `Sources/SVGViewer/Commands.swift` | File/Edit/View menu items |
| `Sources/SVGViewer/SettingsView.swift` | Settings window |
| `Sources/SVGViewer/SVGRenderer.swift` | PNG rasterization via the system SVG renderer |
| `Tools/MakeIcon` | Generates the app icon at build time |

## Notes

- The app is sandboxed (App Store ready) and uses only public API.
- PNG export and Copy Image use the system renderer (CoreSVG), which supports fewer SVG features
  than WebKit (notably filters). On-screen display is always WebKit.
- Scripts inside SVG files are not executed.
