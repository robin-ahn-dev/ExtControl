// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ExtControl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ExtControl",
            path: "Sources/ExtControl"
        )
    ]
)
