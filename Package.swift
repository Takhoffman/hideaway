// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hideaway",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hideaway", targets: ["Hideaway"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "Hideaway",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(name: "HideawayTests", dependencies: ["Hideaway"])
    ]
)
