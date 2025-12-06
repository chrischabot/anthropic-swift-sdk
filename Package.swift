// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnthropicSwift",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "AnthropicSwift",
            targets: ["AnthropicSwift"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "AnthropicSwift",
            dependencies: []
        ),
        .testTarget(
            name: "AnthropicSwiftTests",
            dependencies: ["AnthropicSwift"]
        ),
    ]
)
