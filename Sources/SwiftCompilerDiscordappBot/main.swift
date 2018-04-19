import Foundation
import Sword

#if os(macOS)
setlinebuf(Darwin.stdout)
setlinebuf(Darwin.stderr)
#else
setlinebuf(Glibc.stdout)
setlinebuf(Glibc.stderr)
#endif

// MARK: - edit status
App.bot.editStatus(to: "online", playing: App.playing)
App.log("is online and playing \(App.playing).")

// MARK: - update nickname
App.bot.on(.guildAvailable) { data in
    guard let guild = data as? Guild else { return }
    App.log("Guild Available: \(guild.name)")
    guild.setNickname(to: App.nickname) { error in
        if let error = error {
            App.log("failed to change nickname in guild: \(guild.name), error: \(error)")
        }
    }
}

// MARK: - MessageCreate
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

    // MARK: parse message
    let (options, swiftCode) = App.parse(message)
    guard !(options.isEmpty && swiftCode.isEmpty) else {
        message.reply(with: App.helpMessage)
        return
    }

    // MARK: Trigger Typing Indicator
    App.bot.setTyping(for: message.channel.id)

    do {
        try App.executeSwift(with: options, swiftCode) { result in
            let (args, status, content, stdoutFile, stderrFile) = result
            message.log("executed: \(args), status: \(status)")
            message.reply(with: content)
            if let stdoutFile = stdoutFile {
                message.reply(with: ["file": stdoutFile])
            }
            if let stderrFile = stderrFile {
                message.reply(with: ["file": stderrFile])
            }
        }
    } catch {
        message.loggedReply(with: "\(error)")
    }
}

signal(SIGTERM) { _ in
    App.bot.disconnect()
    exit(EXIT_SUCCESS)
}

App.bot.connect()
