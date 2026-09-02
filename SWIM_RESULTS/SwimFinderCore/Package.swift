// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwimFinderCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwimFinderCore", targets: ["SwimFinderCore"])
    ],
    targets: [
        .target(name: "SwimFinderCore"),
        .testTarget(name: "SwimFinderCoreTests", dependencies: ["SwimFinderCore"])
    ]
)
