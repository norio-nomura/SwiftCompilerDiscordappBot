// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCompilerDiscordappBot",
    dependencies: [
        .package(url: "https://github.com/Azoy/Sword", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "SwiftCompilerDiscordappBot",
            dependencies: ["Sword"]
        ),
    ]
)
