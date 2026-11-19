// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "sebbu-cache",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .watchOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(
            name: "SebbuCache",
            targets: ["SebbuCache"]
        ),
        .library(
            name: "SebbuCacheFoundation",
            targets: ["SebbuCacheFoundation"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-numerics", from: "1.1.1"),
        .package(url: "https://github.com/MarSe32m/sebbu-deflate", from: "1.26.2")
    ],
    targets: [
        .target(
            name: "SebbuCache",
            dependencies: [
                .product(name: "ComplexModule", package: "swift-numerics"),
                .product(name: "RealModule", package: "swift-numerics")
            ]
        ),
        .target(
            name: "SebbuCacheFoundation",
            dependencies: [
                .product(name: "SebbuDeflate", package: "sebbu-deflate"),
                .product(name: "SebbuDeflateFoundation", package: "sebbu-deflate"),
                "SebbuCache"
            ]
        ),
        .testTarget(
            name: "SebbuCacheTests",
            dependencies: [
                "SebbuCache",
                .product(name: "ComplexModule", package: "swift-numerics"),
                .product(name: "RealModule", package: "swift-numerics")
            ]
        ),
        .testTarget(
            name: "SebbuCacheFoundationTests",
            dependencies: ["SebbuCache", "SebbuCacheFoundation"]
        ),
    ]
)
