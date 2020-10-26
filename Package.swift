// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LaserDisc",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LaserDisc",
            targets: ["LaserDisc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/envoy/Embassy.git", .branch("expose-parsed-headers")),
        .package(url: "https://github.com/envoy/Ambassador.git", from: "4.0.5")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LaserDisc",
            dependencies: ["Embassy", "Ambassador"]),
        .testTarget(
            name: "LaserDiscTests",
            dependencies: ["LaserDisc"]),
    ]
)
