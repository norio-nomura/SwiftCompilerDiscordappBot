// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "Libraries",
    products: [
        .library(
            name: "Libraries",
            type: .dynamic,
            targets: ["Libraries"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-standard-library-preview.git", from: "0.0.1"),
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", .branch("master"))
    ],
    targets: [
        .target(
            name: "Libraries",
            dependencies: ["NIO", "NIOTLS", "NIOHTTP1", "NIOConcurrencyHelpers", "NIOFoundationCompat", "NIOWebSocket", "SwiftBacktrace", "StandardLibraryPreview"]),
        .target(
            name: "Run",
            dependencies: ["Libraries"]),
        .testTarget(
            name: "LibrariesTests",
            dependencies: ["Libraries"])
    ]
)
