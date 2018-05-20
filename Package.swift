// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var package = Package(
    name: "SwiftCompilerDiscordappBot",
    dependencies: [
        .package(url: "https://github.com/norio-nomura/Sword", .branch("patch-for-swift-bot")),
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", .branch("master"))
    ],
    targets: [
        .target(
            name: "SwiftCompilerDiscordappBot",
            dependencies: ["SwiftBacktrace", "Sword"]
        ),
    ]
)

let useYams = (ProcessInfo.processInfo.environment["USE_YAMS"] ?? "yes") == "yes" 

if useYams {
    package.dependencies.append(.package(url: "https://github.com/jpsim/Yams", from: "1.0.0"))
    package.targets[0].dependencies.append("Yams")
}
