// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "liquid-local-driver",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "LiquidLocalDriver",
            targets: [
                "LiquidLocalDriver"
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/binarybirds/liquid-kit",
            branch: "dev"
        ),
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.48.0"
        ),
    ],
    targets: [
        .target(
            name: "LiquidLocalDriver",
            dependencies: [
                .product(
                    name: "LiquidKit",
                    package: "liquid-kit"
                ),
                .product(
                    name: "NIO",
                    package: "swift-nio"
                ),
            ]
        ),
        .testTarget(
            name: "LiquidLocalDriverTests",
            dependencies: [
                .product(
                    name: "LiquidKit",
                    package: "liquid-kit"
                ),
                .target(name: "LiquidLocalDriver"),
            ],
            exclude: [
                "./assets/"
            ]
        ),
    ]
)
