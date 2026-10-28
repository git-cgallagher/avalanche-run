// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AvalancheRun",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "AvalancheRun", path: "Sources/AvalancheRun")
    ]
)
