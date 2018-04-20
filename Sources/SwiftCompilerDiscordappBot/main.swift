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
            let (args, status, content, stdoutFile, stderrFile) = result
            message.log("executed: \(args), status: \(status)")
            message.answer(with: content)
            message.answerStdout(with: stdoutFile)
            message.answerStderr(with: stderrFile)
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
        message.deleteAnswers()
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

    // Does bot have replied?
    let replies = App.repliedRequests[message.id]
    if let lastReplyID = replies.stderrID ?? replies.stdoutID ?? replies.replyID {
        // MARK: check some one posts messages after bot's replies
        channel.getMessages(with: ["after": lastReplyID, "limit": 1]) { messages, error in
            let isSomeMessagesArePostedSinceBotReplied = messages?.count ?? 1 > 0
            do {
                try App.executeSwift(with: options, swiftCode) { result in
                    let (args, status, content, stdoutFile, stderrFile) = result
                    message.log("executed: \(args), status: \(status)")
                    if replies.replyID != nil {
                        message.answer(with: content)
                    } else if !isSomeMessagesArePostedSinceBotReplied {
                        message.answer(with: content)
                    }
                    message.deleteStdoutAnswer()
                    message.deleteStderrAnswer()
                    if !isSomeMessagesArePostedSinceBotReplied {
                        if let stdoutFile = stdoutFile {
                            message.answerStdout(with: stdoutFile)
                        }
                        if let stderrFile = stderrFile {
                            message.answerStderr(with: stderrFile)
                        }
                    }
                }
            } catch {
                if let replyID = replies.replyID {
                    channel.editMessage(replyID, with: ["content": "\(error)"])
                } else if !isSomeMessagesArePostedSinceBotReplied {
                    message.answer(with: error)
                }
            }
        }
    } else {
        do {
            try App.executeSwift(with: options, swiftCode) { result in
                let (args, status, content, stdoutFile, stderrFile) = result
                message.log("executed: \(args), status: \(status)")
                message.answer(with: content)
                message.answerStdout(with: stdoutFile)
                message.answerStderr(with: stderrFile)
            }
        } catch {
            message.answer(with: error)
        }
    }
}

App.bot.on(.messageDelete) { data in
    guard let (messageID, channel) = data as? (Snowflake, TextChannel) else { return }
    channel.deleteAnswer(for: messageID)
    channel.deleteStdoutAnswer(for: messageID)
    channel.deleteStderrAnswer(for: messageID)
}

signal(SIGTERM) { _ in
    App.bot.disconnect()
    exit(EXIT_SUCCESS)
}

App.bot.connect()
