// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LaserDisc",
    products: [
        .library(
            name: "LaserDisc",
            targets: ["LaserDisc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/envoy/Embassy.git", .branch("fix-memory-leaks")),
        .package(url: "https://github.com/envoy/Ambassador.git", from: "4.0.5")
    ],
    targets: [
        .target(
            name: "LaserDisc",
            dependencies: ["Embassy", "Ambassador"]),
        .testTarget(
            name: "LaserDiscTests",
            dependencies: ["LaserDisc"]),
    ]
)
