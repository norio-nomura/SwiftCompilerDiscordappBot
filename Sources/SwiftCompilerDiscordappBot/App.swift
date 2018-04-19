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

