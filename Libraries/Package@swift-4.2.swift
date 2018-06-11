// swift-tools-version:4.2
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
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "4.1.2"),
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", .branch("master"))
    ],
    targets: [
        .target(
            name: "Libraries",
            dependencies: ["RxSwift", "SwiftBacktrace"]),
        .target(
            name: "Run",
            dependencies: ["Libraries"]),
        .testTarget(
            name: "LibrariesTests",
            dependencies: ["Libraries"])
    ]
)

#if !canImport(TensorFlow)
package.dependencies.append(.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"))
package.targets[0].dependencies.append("Vapor")
#endif
