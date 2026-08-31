// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShiftTechoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ShiftTechoCore", targets: ["ShiftTechoCore"])
    ],
    targets: [
        .target(name: "ShiftTechoCore"),
        .testTarget(name: "ShiftTechoCoreTests", dependencies: ["ShiftTechoCore"])
    ]
)
