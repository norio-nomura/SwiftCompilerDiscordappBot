import Foundation
import Sword

#if os(macOS)
setlinebuf(Darwin.stdout)
setlinebuf(Darwin.stderr)
#else
setlinebuf(Glibc.stdout)
setlinebuf(Glibc.stderr)
#endif

// MARK: configuration
let environment = ProcessInfo.processInfo.environment
guard let discordToken = environment["DISCORD_TOKEN"], !discordToken.isEmpty else {
    fatalError("Can't find `DISCORD_TOKEN` environment variable!")
}

let timeout = environment["TIMEOUT"].flatMap({ Int($0) }) ?? 30

// MARK: edit status
let regexForVersion = try! NSRegularExpression(pattern: "^.*\\(([^\\)]*)\\)$",
                                               options: [.anchorsMatchLines])


let (_, version, _) = execute(["swift", "--version"])
let playing = regexForVersion.firstMatch(in: version).last ?? version

let bot = Sword(token: discordToken)

bot.editStatus(to: "online", playing: playing)
print("🤖 is online and playing \(playing).")

// MARK: update nickname
bot.on(.guildAvailable) { data in
    guard let guild = data as? Guild else { return }
    print("🤖 Guild Available: \(guild.name)")
    guild.setNickname(to: playing.replacingOccurrences(of: "-RELEASE", with: "")) { error in
        if let error = error {
            print("🤖 failed to change nickname in guild: \(guild.name), error: \(error)")
        }
    }
}

// MARK: regular expressions
let regexForFirstLine = try! NSRegularExpression(pattern: "^(.*?)$",
                                                 options: [.anchorsMatchLines, .dotMatchesLineSeparators])
let regexForCodeblock = try! NSRegularExpression(pattern: "^```.*?\\n([\\s\\S]*?\\n)```",
                                                 options: [.anchorsMatchLines, .dotMatchesLineSeparators])

bot.on(.messageCreate) { data in
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
            ```Usage:
              @\((bot.user?.username)!) [SWIFTC_OPTIONS]
              `\u{200b}`\u{200b}`\u{200b}
              [Swift Code]
              `\u{200b}`\u{200b}`\u{200b}

            ```
            """)
    }

    // MARK: first line is used to options for swift
    let firstLine = regexForFirstLine.firstMatch(in: message.content)[1]
    var optionsString = message.mentions.reduce(firstLine) {
        // remove mentions
        $0.replacingOccurrences(of: "<@\($1.id)>", with: "").replacingOccurrences(of: "<@!\($1.id)>", with: "")
    }
    var options = optionsString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

    // MARK: parse codeblock
    let swiftCode = regexForCodeblock.firstMatch(in: message.content).last ?? ""

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
    let args = ["timeout", "--signal=KILL", "\(timeout)", "swift"] + options
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
            let code = output[..<output.index(output.startIndex, offsetBy: contentsLimit)]
            message.reply(with: statusMessage + codeblock(code))
            do {
                let outputFileURL = tempURL.appendingPathComponent("stdout.txt")
                try output.write(to: outputFileURL, atomically: true, encoding: .utf8)
                message.reply(with: ["file": outputFileURL.path])
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
            let code = error[..<error.index(error.startIndex, offsetBy: contentsLimit)]
            message.reply(with: statusMessage + "error output:\n" + codeblock(code))
            do {
                let errorFileURL = tempURL.appendingPathComponent("stderr.txt")
                try error.write(to: errorFileURL, atomically: true, encoding: .utf8)
                message.reply(with: ["file": errorFileURL.path])
            } catch {
                message.loggedReply(with: "failed to write `stdout.txt` with error: \(error)")
            }
        } else {
            message.reply(with: statusMessage + "error output:\n" + codeblock(error))
        }
    }
}

bot.connect()
