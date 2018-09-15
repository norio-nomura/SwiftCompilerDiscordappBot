import Foundation
import Sword
import SwiftBacktrace

setlinebuf(stdout)

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
        let messageAuthor = message.author,  // Author is nil if message is generated by Webhook.
        !(messageAuthor.isBot ?? false),
        let botUser = App.bot.user,
        message.author != botUser else { return }

    // MARK: check channel type
    switch message.channel.type {
    case .guildText:
        guard message.mentions.contains(botUser) else {
            return
        }
    case .dm: break
    default: return
    }

    // MARK: parse message
    let (options, swiftCode) = message.parse()
    guard !(options.isEmpty && swiftCode.isEmpty) else {
        message.answer(with: App.helpMessage) { _, error in
            if let error = error {
                App.log("failed to answer at \(#line) with error: \(error)")
            }
        }
        return
    }

    // MARK: Trigger Typing Indicator
    App.bot.setTyping(for: message.channel.id)

    do {
        try App.executeSwift(with: options, swiftCode) { result in
            let (status, content, stdout, stderr) = result
            message.log("executed `swift` with options: \(options), status: \(status)")
            message.answer(with: content, stdout: stdout, stderr: stderr) { _, error in
                if let error = error {
                    App.log("failed to answer at \(#line) with error: \(error)")
                }
            }
        }
    } catch {
        message.answer(with: error)
    }
}

// MARK: - MessageUpdate
App.bot.on(.messageUpdate) { data in
    guard let message = data as? Message,
        let messageAuthor = message.author,  // Author is nil if message is generated by Webhook.
        !(messageAuthor.isBot ?? false),
        let botUser = App.bot.user,
        message.author != botUser else { return }

    // MARK: check channel type
    switch message.channel.type {
    case .guildText:
        guard message.mentions.contains(botUser) else {
            message.deleteAnswer()
            return
        }
    case .dm: break
    default: return
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
            let (status, content, stdout, stderr) = result
            message.log("executed `swift` with options: \(options), status: \(status)")
            message.answer(with: content, stdout: stdout, stderr: stderr) { _, error in
                if let error = error {
                    App.log("failed to answer at \(#line) with error: \(error)")
                }
            }
        }
    } catch {
        message.answer(with: error) { _, error in
            if let error = error {
                App.log("failed to answer at \(#line) with error: \(error)")
            }
        }
    }
}

App.bot.on(.messageDelete) { data in
    guard let (messageID, channel) = data as? (Snowflake, TextChannel) else { return }
    channel.deleteAnswer(for: messageID)
}

let signalHandler: @convention(c) (Int32) -> Swift.Void = { signo in
    App.bot.disconnect()
    fputs(backtrace().joined(separator: "\n") + "\nsignal: \(signo)", stderr)
    fflush(stderr)
    exit(128 + signo)
}

// https://devcenter.heroku.com/articles/dynos#shutdown
handle(signal: SIGTERM, action: signalHandler)
// deadly
handle(signal: SIGSEGV, action: signalHandler)
handle(signal: SIGBUS, action: signalHandler)
handle(signal: SIGABRT, action: signalHandler)
handle(signal: SIGFPE, action: signalHandler)
handle(signal: SIGILL, action: signalHandler)
// EXC_BAD_INSTRUCTION
handle(signal: SIGUSR1, action: signalHandler)

App.bot.connect()
