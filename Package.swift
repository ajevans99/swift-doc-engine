// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocEngine",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "DocEngine", targets: ["DocEngine"]),
        .library(name: "MarkdownLintKit", targets: ["MarkdownLintKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "DocEngine",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .target(
            name: "MarkdownLintKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .testTarget(
            name: "DocEngineTests",
            dependencies: ["DocEngine"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "MarkdownLintKitTests",
            dependencies: ["MarkdownLintKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
