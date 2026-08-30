// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KoyomiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KoyomiCore", targets: ["KoyomiCore"])
    ],
    targets: [
        .target(name: "KoyomiCore"),
        .testTarget(name: "KoyomiCoreTests", dependencies: ["KoyomiCore"])
    ]
)
