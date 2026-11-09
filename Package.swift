// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalLLMManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LocalLLMManager",
            path: "Sources/LocalLLMManager"
        )
    ]
)
