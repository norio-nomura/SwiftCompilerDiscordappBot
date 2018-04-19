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

    let (options, swiftCode) = App.parse(message)
    guard !(swiftCode.isEmpty && options.isEmpty) else {
        message.reply(with: App.helpMessage)
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

    defer {
        do {
            try FileManager.default.removeItem(at: tempURL)
        } catch {
            message.loggedReply(with: "failed to remove temporary directory with error: \(error)")
        }
    }

    do {
        let (args, status, content, files) = try App.executeSwift(with: options, swiftCode, in: tempURL)
        message.log("executed: \(args), status: \(status)")
        message.reply(with: content)
        files.forEach {
            message.reply(with: ["file": $0])
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
