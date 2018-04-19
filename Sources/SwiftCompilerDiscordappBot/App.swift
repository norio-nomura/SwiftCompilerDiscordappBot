//
//  App.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/19/18.
//

import Dispatch
import Foundation
import Sword

struct App {
    static let bot = Sword(token: discordToken)
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
    static let nickname = regexForVersionInfo.firstMatch(in: versionInfo).last.map { "swift-" + $0 } ?? ""
    static let playing = environment["SWIFT_VERSION"].map { "swift-" + $0 } ?? "unkown swift build"

    static func log(_ message: String) {
        print("🤖 " + message)
    }

    static func parse(_ message: Message) -> (options: [String], swiftCode: String) {
        // MARK: first line is used to options for swift
        let mentionedLine = regexForMentionedLine.firstMatch(in: message.content)[1]
        let optionsString = message.mentions.reduce(mentionedLine) {
            // remove mentions
            $0.replacingOccurrences(of: "<@\($1.id)>", with: "").replacingOccurrences(of: "<@!\($1.id)>", with: "")
        }
        let options = optionsString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // MARK: parse codeblock
        let swiftCode = regexForCodeblock.firstMatch(in: message.content).last ?? ""

        return (options, swiftCode)
    }

    // Replied Requests
    static var repliedRequests = RepliedRequests()
    struct RepliedRequests {
        typealias Replies = (replyID: Snowflake?, stdoutID: Snowflake?, stderrID: Snowflake?)
        private var answeredMessages = [Snowflake: Replies]()
        private let queue = DispatchQueue(label: "answeredMessages")
        subscript(messageID: Snowflake) -> Replies {
            get { return queue.sync { answeredMessages[messageID] } ?? (nil, nil, nil) }
            set {
                switch newValue {
                case (nil, nil, nil): queue.sync { answeredMessages[messageID] = nil }
                default: queue.sync { answeredMessages[messageID] = newValue }
                }
            }
        }
    }

    struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }

    // executionResult
    typealias ExecutionResult = (args: [String], status: Int32, content: String, stdoutFile: String?, stderrFile: String?)

    static func executeSwift(
        with options: [String],
        _ swiftCode: String,
        handler: (ExecutionResult) -> Void) throws {
        var options = options

        // MARK: create temporary directory
        let sessionUUID = UUID().uuidString
#if os(macOS)
        let directory = URL(fileURLWithPath: "/tmp").appendingPathComponent(sessionUUID)
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

        // create main.swift
        if !swiftCode.isEmpty {
            let mainSwiftURL = directory.appendingPathComponent("main.swift")
            do {
                try swiftCode.write(to: mainSwiftURL, atomically: true, encoding: .utf8)
                options.append("main.swift")
            } catch {
                throw Error(description: "failed to write `main.swift` with error: \(error)")
            }
        }

        // execute swift
        let args = ["timeout", "--signal=KILL", "\(timeout)", "swift"] + options
#if os(macOS)
        // execute in docker
        let temp = directory.path
        let docker = ["docker", "run", "--rm", "-v", "\(temp):\(temp)", "-w", temp, "norionomura/swift:41"]
        let (status, stdout, stderr) = execute(docker + args, in: directory)
#elseif os(Linux)
        let (status, stdout, stderr) = execute(args, in: directory)
#endif
        // build content
        var attachOutput = false, attachError = false
        var content = ""
        var remain = 2000

        func append<S: StringProtocol>(_ string: S, _ count: Int = 0) {
            content += string
            remain -= count == 0 ? string.count : count
        }

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

        // build files
        var files = [String]()
        func create(filename: String, with content: String) throws -> String {
            do {
                let outputFileURL = directory.appendingPathComponent(filename)
                try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
                return outputFileURL.path
            } catch {
                throw Error(description: "failed to write `\(filename)` with error: \(error)")
            }
        }
        let stdoutFile = attachOutput ? try create(filename: "stdout.txt", with: stdout) : nil
        let stderrFile = attachError ? try create(filename: "stderr.txt", with: stderr) : nil
        handler((args, status, content, stdoutFile, stderrFile))
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
    private static let regexForCodeblock = regex(pattern: "^```.*?\\n([\\s\\S]*?\\n)```")
    private static let regexForMentionedLine = regex(pattern: "^.*?<@!?\(bot.user!.id)>(.*?)$")
    private static let timeout = environment["TIMEOUT"].flatMap({ Int($0) }) ?? 30
    private static let versionInfo = execute(["swift", "--version"]).stdout

    private static func regex(
        pattern: String,
        options: NSRegularExpression.Options = [.anchorsMatchLines, .dotMatchesLineSeparators]
        ) -> NSRegularExpression {
        return try! .init(pattern: pattern, options: options)
    }
}

