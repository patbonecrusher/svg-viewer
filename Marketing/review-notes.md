# App Review notes (Guideline 2.1 – Information Needed, reply 2026-09-16)

1. Screen recording: see attachment (MacBook Pro, macOS 26.6). Flow: launch → open an SVG → zoom (toolbar, ⌘-scroll) → zoom to fit / actual size → change background → open the source inspector → Settings → Export as PNG.

2. Purpose and audience: SVG Viewer is a lightweight, native macOS viewer for SVG vector graphics. macOS has no dedicated SVG viewer — Preview/Quick Look use a limited engine that ignores CSS, filters and embedded fonts, and a web browser offers no zoom controls, backgrounds or document workflow. SVG Viewer fills that gap for designers and developers who receive, review or produce SVG files: full-fidelity rendering, zoom and pan, switchable backgrounds to check transparency, a source inspector, PNG export, and automatic reload when the file changes on disk so it can sit next to an editor.

3. Setup and access: no setup, account or login. Launch the app and choose File → Open (or drag any .svg/.svgz onto the window or Dock icon). Any SVG works; sample files: https://github.com/patbonecrusher/svg-viewer/tree/main/Samples. Zoom: toolbar, View menu, pinch or ⌘-scroll. Background: toolbar menu. Source inspector: `</>` toolbar button or ⌥⌘U. Export: File → Export as PNG (⇧⌘E). Settings: ⌘,.

4. External services: none. Only Apple system frameworks (SwiftUI, AppKit, WebKit for rendering). No network requests, analytics, accounts, payments or AI services. SVG content is rendered under a strict Content Security Policy that blocks scripts and remote resources.

5. Regional differences: none. Identical functionality in all regions; English only.

6. Regulated industry / third-party material: not applicable. All code and artwork are original.
