// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SVGViewer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SVGViewer", path: "Sources/SVGViewer"),
        .executableTarget(name: "MakeIcon", path: "Tools/MakeIcon"),
    ]
)
