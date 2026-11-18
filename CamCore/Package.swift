// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CamCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CamCore", targets: ["CamCore"]),
    ],
    targets: [
        .target(name: "CamCore"),
        .testTarget(name: "CamCoreTests", dependencies: ["CamCore"]),
    ]
)
