// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iPadMirrorMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "iPadMirrorMac", targets: ["iPadMirrorMac"])
    ],
    targets: [
        .executableTarget(
            name: "iPadMirrorMac",
            path: "Sources/iPadMirrorMac"
        )
    ]
)
