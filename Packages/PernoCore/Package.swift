// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PernoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PernoCore", targets: ["PernoCore"]),
    ],
    targets: [
        .target(name: "PernoCore"),
        .testTarget(name: "PernoCoreTests", dependencies: ["PernoCore"]),
    ]
)
