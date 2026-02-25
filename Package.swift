// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WhisperGUI", targets: ["WhisperGUI"])
    ],
    targets: [
        .executableTarget(
            name: "WhisperGUI",
            path: "Sources/WhisperGUI"
        )
    ]
)
