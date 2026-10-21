// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WidgetKitCore",
    defaultLocalization: "ar",
    // macOS is listed only so `swift test` can run the package tests on the CI host.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WidgetKitCore", targets: ["WidgetKitCore"]),
    ],
    targets: [
        .target(
            name: "WidgetKitCore",
            resources: [.copy("Resources/TestSpecs"), .copy("Resources/Spec")]
        ),
        .testTarget(name: "WidgetKitCoreTests", dependencies: ["WidgetKitCore"]),
    ],
    // Swift 5 language mode, minimal concurrency checking (ADR-006).
    swiftLanguageModes: [.v5]
)
