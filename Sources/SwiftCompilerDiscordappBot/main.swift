import Foundation
import Sword

#if os(macOS)
setlinebuf(Darwin.stdout)
setlinebuf(Darwin.stderr)
#else
setlinebuf(Glibc.stdout)
setlinebuf(Glibc.stderr)
#endif

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

// MARK: edit status
App.bot.editStatus(to: "online", playing: App.playing)
print("🤖 is online and playing \(App.playing).")

// MARK: update nickname
App.bot.on(.guildAvailable) { data in
    guard let guild = data as? Guild else { return }
    print("🤖 Guild Available: \(guild.name)")
    guild.setNickname(to: App.nickname) { error in
        if let error = error {
            print("🤖 failed to change nickname in guild: \(guild.name), error: \(error)")
        }
    }
}

App.bot.on(.messageCreate) { [weak bot = App.bot] data in
    guard let bot = bot else { return }
    // MARK: check mentions
    guard let message = data as? Message,
        message.author?.id != bot.user?.id,
        !(message.author?.isBot ?? false),
        message.mentions.contains(where: { $0.id == bot.user?.id }) else { return }

    // MARK: restrict to public channel
    guard message.channel.type == .guildText else {
        message.reply(with: "Sorry, I am not allowed to work on this channel.")
        return
    }

    func replyHelp() {
        message.reply(with: """
            ```
            Usage:
              @\((bot.user?.username)!) [SWIFT_OPTIONS]
              `\u{200b}`\u{200b}`\u{200b}
              [Swift Code]
              `\u{200b}`\u{200b}`\u{200b}

            ```
            """)
    }

    var options: [String]
    let swiftCode: String
    (options, swiftCode) = App.parse(message)
    guard !(swiftCode.isEmpty && options.isEmpty) else {
        replyHelp()
        return
    }

    // MARK: create temporary directory
    let sessionUUID = UUID().uuidString
#if os(macOS)
    let tempURL = URL(fileURLWithPath: "/tmp").appendingPathComponent(sessionUUID)
#elseif os(Linux)
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(sessionUUID)
#endif
    do {
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        message.loggedReply(with: "failed to create temoprary directory with error: \(error)")
        return
    }

    defer {
        do {
            try FileManager.default.removeItem(at: tempURL)
        } catch {
            message.loggedReply(with: "failed to remove temporary directory with error: \(error)")
        }
    }

    // MARK: create main.swift
    if !swiftCode.isEmpty {
        let mainSwiftURL = tempURL.appendingPathComponent("main.swift")
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            try swiftCode.write(to: mainSwiftURL, atomically: true, encoding: .utf8)
            options.append("main.swift")
        } catch {
            message.loggedReply(with: "failed to write `main.swift` with error: \(error)")
            return
        }
    }

    // MARK: execute swift
    let args = ["timeout", "--signal=KILL", "\(App.timeout)", "swift"] + options
    message.log("executed: \(args)")
#if os(macOS)
    // execute in docker
    let temp = tempURL.path
    let docker = ["docker", "run", "--rm", "-v", "\(temp):\(temp)", "-w", temp, "norionomura/swift:41"]
    let (status, output, error) = execute(docker + args, in: tempURL)
#elseif os(Linux)
    let (status, output, error) = execute(args, in: tempURL)
#endif

    // MARK: check exit status
    if status == 9 {
        message.log("execution timeout: \(args)")
    } else if status != 0 {
        if output.isEmpty && error.isEmpty {
            message.reply(with: "exit status: \(status)")
        }
        message.log("exit status: \(status)")
    } else if output.isEmpty && error.isEmpty {
        message.reply(with: "no outputs")
        return
    }

    // MARK: reply
    func codeblock<S: CustomStringConvertible>(_ string: S) -> String {
        return "```\n\(string)```\n"
    }

    func string(from status: Int32) -> String {
        return status == 9 ? "execution timeout with " : "exit status: \(status), "
    }

    let contentsLimit = 1950
    if !output.isEmpty {
        let statusMessage = status != 0 ? (string(from: status) + "output:\n") : ""
        if output.count > contentsLimit {
            do {
                let code = output[..<output.index(output.startIndex, offsetBy: contentsLimit)]
                let content = statusMessage + codeblock(code)
                let outputFileURL = tempURL.appendingPathComponent("stdout.txt")
                try output.write(to: outputFileURL, atomically: true, encoding: .utf8)
                message.reply(with: ["content": content, "file": outputFileURL.path])
            } catch {
                message.loggedReply(with: "failed to write `stdout.txt` with error: \(error)")
            }
        } else {
            message.reply(with: statusMessage + codeblock(output))
        }
    }
    if !error.isEmpty {
        let statusMessage = status != 0 && output.isEmpty ? string(from: status) : ""
        if error.count > contentsLimit {
            do {
                let code = error[..<error.index(error.startIndex, offsetBy: contentsLimit)]
                let content = statusMessage + "error output:\n" + codeblock(code)
                let errorFileURL = tempURL.appendingPathComponent("stderr.txt")
                try error.write(to: errorFileURL, atomically: true, encoding: .utf8)
                message.reply(with: ["content": content, "file": errorFileURL.path])
            } catch {
                message.loggedReply(with: "failed to write `stdout.txt` with error: \(error)")
            }
        } else {
            message.reply(with: statusMessage + "error output:\n" + codeblock(error))
        }
    }
}

signal(SIGTERM) { _ in
    App.bot.disconnect()
    exit(EXIT_SUCCESS)
}

App.bot.connect()
