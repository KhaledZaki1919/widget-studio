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
    dependencies: [
        // Offline prayer times and Qibla (brief §4.5, MIT). Pinned; update deliberately.
        .package(url: "https://github.com/batoulapps/adhan-swift", exact: "1.5.0"),
    ],
    targets: [
        .target(
            name: "WidgetKitCore",
            dependencies: [.product(name: "Adhan", package: "adhan-swift")],
            resources: [.copy("Resources/TestSpecs"), .copy("Resources/Templates"), .copy("Resources/Spec"), .copy("Prompts")]
        ),
        .testTarget(name: "WidgetKitCoreTests", dependencies: ["WidgetKitCore"], resources: [.copy("Fixtures")]),
    ],
    // Swift 5 language mode, minimal concurrency checking (ADR-006).
    swiftLanguageModes: [.v5]
)
