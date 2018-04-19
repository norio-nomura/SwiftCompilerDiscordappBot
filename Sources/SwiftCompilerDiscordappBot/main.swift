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
    let channel = message.channel

    // MARK: restrict to public channel
    guard channel.type == .guildText else {
        message.reply(with: "Sorry, I am not allowed to work on this channel.")
        return
    }

    // MARK: parse message
    let (options, swiftCode) = App.parse(message)
    guard !(options.isEmpty && swiftCode.isEmpty) else {
        message.reply(with: App.helpMessage) { reply, _ in
            App.repliedRequests[message.id].replyID = reply?.id
        }
        return
    }

    // MARK: Trigger Typing Indicator
    App.bot.setTyping(for: channel.id)

    do {
        try App.executeSwift(with: options, swiftCode) { result in
            let (args, status, content, stdoutFile, stderrFile) = result
            message.log("executed: \(args), status: \(status)")
            message.reply(with: content) { reply, _ in
                App.repliedRequests[message.id].replyID = reply?.id
            }
            if let stdoutFile = stdoutFile {
                message.reply(with: ["file": stdoutFile]) { reply, _ in
                    App.repliedRequests[message.id].stdoutID = reply?.id
                }
            }
            if let stderrFile = stderrFile {
                message.reply(with: ["file": stderrFile]) { reply, _ in
                    App.repliedRequests[message.id].stderrID = reply?.id
                }
            }
        }
    } catch {
        message.loggedReply(with: "\(error)") { reply, _ in
            App.repliedRequests[message.id].replyID = reply?.id
        }
    }
}

// MARK: - MessageUpdate
App.bot.on(.messageUpdate) { [weak bot = App.bot] data in
    guard let bot = bot else { return }
    guard let message = data as? Message else { return }
    let channel = message.channel

    // MARK: check replied
    let replies = App.repliedRequests[message.id]
    guard !(replies.replyID == nil && replies.stdoutID == nil && replies.stderrID == nil) else { return }

    // MARK: check mentions
    guard message.author?.id != bot.user?.id,
        !(message.author?.isBot ?? false),
        message.mentions.contains(where: { $0.id == bot.user?.id }) else { return }

    // MARK: parse message
    let (options, swiftCode) = App.parse(message)
    guard !(options.isEmpty && swiftCode.isEmpty) else {
        if let replyID = replies.replyID {
            channel.editMessage(replyID, with: ["content": App.helpMessage])
        }
        return
    }

    // MARK: Trigger Typing Indicator
    App.bot.setTyping(for: channel.id)

    // MARK: check some one posts messages after bot's replies
    let lastReplyID = replies.stderrID ?? replies.stdoutID ?? replies.replyID!
    channel.getMessages(with: ["after": lastReplyID, "limit": 1]) { messages, error in
        let isSomeMessagesArePostedSinceBotReplied = messages?.count ?? 1 > 0
        do {
            try App.executeSwift(with: options, swiftCode) { result in
                let (args, status, content, stdoutFile, stderrFile) = result
                message.log("executed: \(args), status: \(status)")
                if let replyID = replies.replyID {
                    channel.editMessage(replyID, with: ["content": content])
                } else if !isSomeMessagesArePostedSinceBotReplied {
                    message.reply(with: content)
                }
                if !isSomeMessagesArePostedSinceBotReplied {
                    if let stdoutID = replies.stdoutID {
                        channel.deleteMessage(stdoutID)
                    }
                    if let stderrID = replies.stderrID {
                        channel.deleteMessage(stderrID)
                    }
                    if let stdoutFile = stdoutFile {
                        message.reply(with: ["file": stdoutFile]) { reply, _ in
                            App.repliedRequests[message.id].stdoutID = reply?.id
                        }
                    }
                    if let stderrFile = stderrFile {
                        message.reply(with: ["file": stderrFile]) { reply, _ in
                            App.repliedRequests[message.id].stdoutID = reply?.id
                        }
                    }
                } else {
                    switch (replies.stdoutID, stdoutFile) {
                    case (let stdoutID?, nil): channel.deleteMessage(stdoutID)
                    case (let stdoutID?, _): channel.editMessage(stdoutID,
                                                                 with: ["content": "this stdout.txt is obsolete."])
                    default: break
                    }
                    switch (replies.stderrID, stderrFile) {
                    case (let stderrID?, nil): channel.deleteMessage(stderrID)
                    case (let stderrID?, _): channel.editMessage(stderrID,
                                                                 with: ["content": "this stderr.txt is obsolete."])
                    default: break
                    }
                }
            }
        } catch {
            if let replyID = replies.replyID {
                channel.editMessage(replyID, with: ["content": "\(error)"])
            } else if !isSomeMessagesArePostedSinceBotReplied {
                message.reply(with: "\(error)")
            }
        }
    }
}

signal(SIGTERM) { _ in
    App.bot.disconnect()
    exit(EXIT_SUCCESS)
}

App.bot.connect()
