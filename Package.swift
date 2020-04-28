// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "liquid-local-driver",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "LiquidLocalDriver", targets: ["LiquidLocalDriver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/binarybirds/liquid-kit.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "LiquidLocalDriver", dependencies: [
            .product(name: "LiquidKit", package: "liquid-kit"),
        ]),
        .testTarget(name: "LiquidLocalDriverTests", dependencies: ["LiquidLocalDriver"]),
    ]
)
