// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "ZKPMetal",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ZKPMetal",
            targets: ["ZKPMetal"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ZKPMetal",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Numerics", package: "swift-numerics"),
            ],
            resources: [
                .process("Shaders")
            ]
        ),
        .testTarget(
            name: "ZKPMetalTests",
            dependencies: ["ZKPMetal"]
        ),
    ]
)