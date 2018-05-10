//
//  App.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/19/18.
//

import Foundation
import Sword

struct App {
    static let swordOptions: SwordOptions = {
        var options = SwordOptions()
        switch environment["SWORD_LOGGING"] ?? "NO" {
        case "YES", "TRUE": options.willLog = true
        default: options.willLog = false
        }
        return options
    }()
    static let bot = Sword(token: discordToken, with: swordOptions)
    static var helpMessage: String {
        return """
        ```
        Usage:
        @\((bot.user?.username)!) [SWIFT_OPTIONS]
        `\u{200b}`\u{200b}`\u{200b}
        [Swift Code]
        `\u{200b}`\u{200b}`\u{200b}

        ```
        """
    }
    static let nickname = environment["NICKNAME"] ?? implicitNickname ?? ""
    static let playing = environment["SWIFT_VERSION"].map { "swift-" + $0 } ?? "unkown swift build"

    static func log(_ message: String) {
        print("🤖 " + message)
    }

    struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }

    // ExecutionResult
    typealias ExecutionResult = (args: [String], status: Int32, content: String, stdout: String?, stderr: String?)

    static func executeSwift( // swiftlint:disable:this function_body_length
        with options: [String],
        _ swiftCode: String,
        handler: (ExecutionResult) -> Void) throws {
        var options = options

        // MARK: create temporary directory
        let sessionUUID = UUID().uuidString
#if os(macOS)
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let directory = currentDirectoryURL.appendingPathComponent("temp").appendingPathComponent(sessionUUID)
#elseif os(Linux)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(sessionUUID)
#endif

        // create directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw Error(description: "failed to create temoprary directory with error: \(error)")
        }

        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                App.log("failed to remove temporary directory with error: \(error)")
            }
        }

        // setup input
        let input = swiftCode.isEmpty ? nil : swiftCode.data(using: .utf8)
        if input != nil {
            // support importing RxSwift
            options.insert(contentsOf: optionsForRxSwift, at: 0)
            if !options.contains("-") {
                options.append("-")
            }
        }

        // execute swift
        let args = ["timeout", "--signal=KILL", "\(timeout)", "swift"] + options
#if os(macOS)
        // execute in docker
        let temp = directory.path
        let docker = ["docker", "run"] +
            (input != nil ? ["-i"] : []) +
            ["--rm", "-v", "\(temp):\(temp)", "-w", temp, "norionomura/swift:41"]
        let (status, stdout, stderr) = execute(docker + args, in: directory, input: input)
#elseif os(Linux)
        let (status, stdout, stderr) = execute(args, in: directory, input: input)
#endif
        // build content
        var attachOutput = false, attachError = false
        var content = ""
        var remain = 2000

#if swift(>=4.1)
        func append<S: StringProtocol>(_ string: S, _ count: Int = 0) {
            content += string
            remain -= count == 0 ? string.count : count
        }
#else
        func append<S: StringProtocol>(_ string: S, _ count: Int = 0) where S.IndexDistance == Int {
            content += string
            remain -= count == 0 ? string.count : count
        }
#endif

        // check exit status
        if status == 9 {
            append("execution timeout with ")
        } else if status != 0 {
            append("exit status: \(status) with ")
        }
        if stdout.isEmpty && stderr.isEmpty {
            append("no output")
        }
        if !stdout.isEmpty {
            let header = status != 0 ? "stdout:```\n" : "```\n"
            let footer = "```"
            let limit = remain - header.count - footer.count
            let outputLength = stdout.count
            if outputLength > limit {
                let chopped = stdout[..<stdout.index(stdout.startIndex, offsetBy: limit)]
                append(header + chopped + footer, header.count + limit + footer.count)
                attachOutput = true
            } else {
                append(header + stdout + footer, header.count + outputLength + footer.count)
            }
        }
        if !stderr.isEmpty {
            let header = "stderr:```\n"
            let footer = "```"
            if remain > header.count + footer.count {
                let limit = remain - header.count - footer.count
                let errorLength = stderr.count
                if errorLength > limit {
                    let chopped = stderr[..<stderr.index(stderr.startIndex, offsetBy: limit)]
                    append(header + chopped + footer, header.count + limit + footer.count)
                    attachError = true
                } else {
                    append(header + stderr + footer, header.count + errorLength + footer.count)
                }
            } else {
                attachError = true
            }
        }

        let optionalStdout = attachOutput ? stdout : nil
        let optionalStderr = attachError ? stderr : nil
        handler((args, status, content, optionalStdout, optionalStderr))
    }

    // private
    private static let discordToken = { () -> String in
        guard let discordToken = environment["DISCORD_TOKEN"], !discordToken.isEmpty else {
            fatalError("Can't find `DISCORD_TOKEN` environment variable!")
        }
        return discordToken
    }()
    private static let environment = ProcessInfo.processInfo.environment
    private static let regexForVersionInfo = regex(pattern: "^(Apple )?Swift version (\\S+) \\(.*\\)$",
                                                   options: .anchorsMatchLines)
    private static let timeout = environment["TIMEOUT"].flatMap({ Int($0) }) ?? 30
    private static let versionInfo = execute(["swift", "--version"]).stdout
    private static let implicitNickname =  regexForVersionInfo.firstMatch(in: versionInfo).last.map { "swift-" + $0 }
    private static let optionsForRxSwift = { () -> [String] in
        let rxSwiftURL = URL(fileURLWithPath: "/RxSwift/.build/x86_64-unknown-linux/debug")
        return FileManager.default.fileExists(atPath: rxSwiftURL.appendingPathComponent("libRxSwift.so").path) ?
            ["-I", rxSwiftURL.path, "-L", rxSwiftURL.path, "-lRxSwift"] : []
    }()
}
