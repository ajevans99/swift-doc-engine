// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocEngine",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "DocEngine", targets: ["DocEngine"])
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
        .testTarget(
            name: "DocEngineTests",
            dependencies: ["DocEngine"],
            resources: [.copy("Fixtures")]
        )
    ]
)
