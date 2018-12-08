// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

var package = Package(
    name: "Libraries",
    products: [
        .library(
            name: "Libraries",
            type: .dynamic,
            targets: ["Libraries"]),
    ],
    dependencies: [
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", .branch("master"))
    ],
    targets: [
        .target(
            name: "Libraries",
            dependencies: ["SwiftBacktrace"]),
        .target(
            name: "Run",
            dependencies: ["Libraries"]),
        .testTarget(
            name: "LibrariesTests",
            dependencies: ["Libraries"])
    ]
)

guard let swiftVersion = ProcessInfo.processInfo.environment["SWIFT_VERSION"] else { exit(0) }
#if canImport(TensorFlow)
if swiftVersion < "DEVELOPMENT-2018-10-05-a" {
    package.dependencies.append(.package(url: "https://github.com/ReactiveX/RxSwift.git", from: "4.1.2"))
    package.targets[0].dependencies.append("RxSwift")
}
#else
if swiftVersion < "DEVELOPMENT-SNAPSHOT-2018-09-18-a" && swiftVersion < "5.0" {
    package.dependencies.append(.package(url: "https://github.com/ReactiveX/RxSwift.git", from: "4.1.2"))
    package.targets[0].dependencies.append("RxSwift")
}
if swiftVersion < "DEVELOPMENT-SNAPSHOT-2018-11-13-a" && swiftVersion < "5.0" {
    package.dependencies.append(.package(url: "https://github.com/taketo1024/SwiftyMath.git", from: "0.3.0"))
    package.targets[0].dependencies.append("SwiftyMath")
}
package.dependencies.append(.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"))
package.targets[0].dependencies.append("Vapor")
#endif
