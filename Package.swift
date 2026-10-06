// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sebbu-cache",
    products: [
        .library(
            name: "SebbuCache",
            targets: ["SebbuCache"]
        ),
    ],
    targets: [
        .target(
            name: "SebbuCache",
            swiftSettings: [
            ],
        ),
        .testTarget(
            name: "SebbuCacheTests",
            dependencies: ["SebbuCache"],
            swiftSettings: [
            ],
        ),
    ]
)
