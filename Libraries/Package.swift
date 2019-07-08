// swift-tools-version:5.1
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
        .package(url: "https://github.com/broadwaylamb/OpenCombine", from: "0.1.0"),
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", .branch("master"))
    ],
    targets: [
         .target(
             name: "Run",
             dependencies: ["Libraries"])
    ]
)

let librariesTarget = Target.target(
    name: "Libraries",
    dependencies: [
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOTLS", package: "swift-nio"),
        .product(name: "NIOWebSocket", package: "swift-nio"),
        .product(name: "OpenCombine", package: "OpenCombine"),
        .product(name: "StandardLibraryPreview", package: "swift-standard-library-preview"),
        .product(name: "SwiftBacktrace", package: "SwiftBacktrace"),
    ]
)

package.targets.append(librariesTarget)

// SE-0226 Package Manager Target Based Dependency Resolution is required to avoid error:
// ```
// error: multiple targets named 'TestHelpers' in: swift-argument-parser, swift-se0270-range-set
// ```
#if compiler(>=5.2)

package.dependencies.append(.package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"))
librariesTarget.dependencies.append(.product(name: "ArgumentParser", package: "swift-argument-parser"))

#endif
