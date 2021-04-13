// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCompilerDiscordappBot",
    dependencies: [
        .package(url: "https://github.com/norio-nomura/Sword", .branch("patch-for-swift-bot")),
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", from: "1.0.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "SwiftCompilerDiscordappBot",
            dependencies: ["SwiftBacktrace", "Sword", "Yams"]
        ),
    ]
)
