// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "posthog_flutter_tvos",
    platforms: [
        .tvOS("17.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "posthog-flutter-tvos", targets: ["posthog_flutter_tvos"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/PostHog/posthog-ios", exact: "3.98.2"),
    ],
    targets: [
        .target(
            name: "posthog_flutter_tvos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            path: "Sources/posthog_flutter",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
