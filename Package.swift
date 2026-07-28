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
        .target(
            name: "iPadMirrorShared",
            path: "Sources/iPadMirrorShared"
        ),
        .executableTarget(
            name: "iPadMirrorMac",
            dependencies: ["iPadMirrorShared"],
            path: "Sources/iPadMirrorMac"
        ),
        .testTarget(
            name: "iPadMirrorMacTests",
            dependencies: ["iPadMirrorMac"],
            path: "Tests/iPadMirrorMacTests"
        )
    ]
)
