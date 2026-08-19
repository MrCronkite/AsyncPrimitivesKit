// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "AsyncPrimitivesKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12) // опционально, если хочешь поддержку macOS
    ],
    products: [
        .library(
            name: "AsyncPrimitivesKit",
            targets: ["AsyncPrimitivesKit"]
        ),
    ],
    targets: [
        .target(
            name: "AsyncPrimitivesKit"
        ),
        .testTarget(
            name: "AsyncPrimitivesKitTests",
            dependencies: ["AsyncPrimitivesKit"]
        ),
    ]
)
