// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Libraries",
    products: [
        .library(
            name: "Libraries",
            type: .dynamic,
            targets: ["Libraries"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "4.1.2"),
        // SwiftNIO is not yet buildable with Swift 4.2
        // .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "Libraries",
            dependencies: ["RxSwift"]),
        .target(
            name: "Run",
            dependencies: ["Libraries"]),
        .testTarget(
            name: "LibrariesTests",
            dependencies: ["Libraries"])
    ]
)
