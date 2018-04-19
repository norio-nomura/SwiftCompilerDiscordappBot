import Foundation
import Sword

#if os(macOS)
setlinebuf(Darwin.stdout)
setlinebuf(Darwin.stderr)
#else
setlinebuf(Glibc.stdout)
setlinebuf(Glibc.stderr)
#endif

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

    // Trigger Typing Indicator
    App.bot.setTyping(for: message.channel.id)

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
#if os(macOS)
    // execute in docker
    let temp = tempURL.path
    let docker = ["docker", "run", "--rm", "-v", "\(temp):\(temp)", "-w", temp, "norionomura/swift:41"]
    let (status, output, error) = execute(docker + args, in: tempURL)
#elseif os(Linux)
    let (status, output, error) = execute(args, in: tempURL)
#endif

    message.log("executed: \(args), status: \(status)")

    // build message
    var attachOutput = false, attachError = false
    var content = ""
    var remain = 2000
    func append<S: StringProtocol>(_ string: S, _ count: Int = 0) {
        content += string
        remain -= count == 0 ? string.count : count
    }
    // MARK: check exit status
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
    message.reply(with: content)

    // post files
    func reply(_ string: String, as filename: String) {
        do {
            let outputFileURL = tempURL.appendingPathComponent(filename)
            try string.write(to: outputFileURL, atomically: true, encoding: .utf8)
            message.reply(with: ["file": outputFileURL.path])
        } catch {
            message.loggedReply(with: "failed to write `\(filename)` with error: \(error)")
        }
    }
    if attachOutput {
        reply(output, as: "stdout.txt")
    }
    if attachError {
        reply(error, as: "stderr.txt")
    }
}

signal(SIGTERM) { _ in
    App.bot.disconnect()
    exit(EXIT_SUCCESS)
}

App.bot.connect()
