// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SubtitleStudio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SubtitleStudio", targets: ["SubtitleStudio"])
    ],
    targets: [
        .executableTarget(
            name: "SubtitleStudio",
            path: "Sources/SubtitleStudio"
        )
    ]
)
