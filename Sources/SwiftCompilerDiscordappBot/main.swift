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
    if guild.members[App.bot.user!.id]?.nick != App.nickname {
        guild.setNickname(to: App.nickname) { error in
            if let error = error {
                App.log("failed to change nickname in guild: \(guild.name), error: \(error)")
            }
        }
    }
}

// MARK: - MessageCreate
App.bot.on(.messageCreate) { data in
    guard let message = data as? Message,
        !(message.author?.isBot ?? false),
        let botUser = App.bot.user,
        message.author != botUser,
        message.mentions.contains(botUser) else { return }

    // MARK: restrict to public channel
    guard message.channel.type == .guildText else {
        message.reply(with: "Sorry, I am not allowed to work on this channel.")
        return
    }

    // MARK: parse message
    let (options, swiftCode) = message.parse()
    guard !(options.isEmpty && swiftCode.isEmpty) else {
        message.answer(with: App.helpMessage)
        return
    }

    // MARK: Trigger Typing Indicator
    App.bot.setTyping(for: message.channel.id)

    do {
        try App.executeSwift(with: options, swiftCode) { result in
            let (args, status, content, stdoutFile, stderrFile, stdout, stderr) = result
            message.log("executed: \(args), status: \(status)")
            message.answer(with: content, stdout: stdout, stderr: stderr)
        }
    } catch {
        message.answer(with: error)
    }
}

// MARK: - MessageUpdate
App.bot.on(.messageUpdate) { data in
    guard let message = data as? Message,
        !(message.author?.isBot ?? false),
        let botUser = App.bot.user,
        message.author != botUser else { return }

    let channel = message.channel

    // MARK: restrict to public channel
    guard message.channel.type == .guildText else {
        message.reply(with: "Sorry, I am not allowed to work on this channel.")
        return
    }

    // MARK: check mentions
    guard message.mentions.contains(botUser) else {
        message.deleteAnswer()
        return
    }

    // MARK: parse message
    let (options, swiftCode) = message.parse()
    guard !(options.isEmpty && swiftCode.isEmpty) else {
        message.answer(with: App.helpMessage)
        return
    }

    // MARK: Trigger Typing Indicator
    App.bot.setTyping(for: channel.id)

    do {
        try App.executeSwift(with: options, swiftCode) { result in
            let (args, status, content, stdoutFile, stderrFile, stdout, stderr) = result
            message.log("executed: \(args), status: \(status)")
            message.answer(with: content, stdout: stdout, stderr: stderr)
        }
    } catch {
        message.answer(with: error)
    }
}

App.bot.on(.messageDelete) { data in
    guard let (messageID, channel) = data as? (Snowflake, TextChannel) else { return }
    channel.deleteAnswer(for: messageID)
}

signal(SIGTERM) { _ in
    App.bot.disconnect()
    exit(EXIT_SUCCESS)
}

App.bot.connect()
