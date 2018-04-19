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
    static let discordToken = { () -> String in
        guard let discordToken = environment["DISCORD_TOKEN"], !discordToken.isEmpty else {
            fatalError("Can't find `DISCORD_TOKEN` environment variable!")
        }
        return discordToken
    }()
    static let timeout = environment["TIMEOUT"].flatMap({ Int($0) }) ?? 30
    static let playing = environment["SWIFT_VERSION"].map { "swift-" + $0 } ?? "unkown swift build"
    static let versionInfo = execute(["swift", "--version"]).stdout
    static let nickname = regexForVersionInfo.firstMatch(in: versionInfo).last.map { "swift-" + $0 } ?? ""

    static let bot = Sword(token: discordToken)

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

    struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }

    static func executeSwift(
        with options: [String],
        _ swiftCode: String,
        in directory: URL
        ) throws -> (args: [String], status: Int32, content: String, files: [String]) {
        var options = options

        // create directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw Error(description: "failed to create temoprary directory with error: \(error)")
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
        let (status, output, error) = execute(docker + args, in: directory)
#elseif os(Linux)
        let (status, output, error) = execute(args, in: directory)
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
        if output.isEmpty && error.isEmpty {
            append("no output")
        }
        if !output.isEmpty {
            let header = status != 0 ? "stdout:```\n" : "```\n"
            let footer = "```"
            let limit = remain - header.count - footer.count
            let outputLength = output.count
            if outputLength > limit {
                let chopped = output[..<output.index(output.startIndex, offsetBy: limit)]
                append(header + chopped + footer, header.count + limit + footer.count)
                attachOutput = true
            } else {
                append(header + output + footer, header.count + outputLength + footer.count)
            }
        }
        if !error.isEmpty {
            let header = "stderr:```\n"
            let footer = "```"
            if remain > header.count + footer.count {
                let limit = remain - header.count - footer.count
                let errorLength = error.count
                if errorLength > limit {
                    let chopped = error[..<error.index(error.startIndex, offsetBy: limit)]
                    append(header + chopped + footer, header.count + limit + footer.count)
                    attachError = true
                } else {
                    append(header + error + footer, header.count + errorLength + footer.count)
                }
            } else {
                attachError = true
            }
        }

        // build files
        var files = [String]()
        func create(filename: String, with content: String) throws {
            do {
                let outputFileURL = directory.appendingPathComponent(filename)
                try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
                files.append(outputFileURL.path)
            } catch {
                throw Error(description: "failed to write `\(filename)` with error: \(error)")
            }
        }
        if attachOutput {
            try create(filename: "stdout.txt", with: output)
        }
        if attachError {
            try create(filename: "stderr.txt", with: error)
        }
        return (args, status, content, files)
    }

    // private
    private static let environment = ProcessInfo.processInfo.environment
    private static let regexForVersionInfo = regex(pattern: "^(Apple )?Swift version (\\S+) \\(.*\\)$",
                                                   options: .anchorsMatchLines)
    private static let regexForCodeblock = regex(pattern: "^```.*?\\n([\\s\\S]*?\\n)```")
    private static let regexForMentionedLine = regex(pattern: "^.*?<@!?\(bot.user!.id)>(.*?)$")

    private static func regex(
        pattern: String,
        options: NSRegularExpression.Options = [.anchorsMatchLines, .dotMatchesLineSeparators]
        ) -> NSRegularExpression {
        return try! .init(pattern: pattern, options: options)
    }
}

