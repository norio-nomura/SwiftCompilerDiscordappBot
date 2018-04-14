import Foundation
import Sword

#if os(macOS)
setlinebuf(Darwin.stdout)
setlinebuf(Darwin.stderr)
#else
setlinebuf(Glibc.stdout)
setlinebuf(Glibc.stderr)
#endif

let environment = ProcessInfo.processInfo.environment
guard let discordToken = environment["DISCORD_TOKEN"], !discordToken.isEmpty else {
    fatalError("Can't find `DISCORD_TOKEN` environment variable!")
}

let timeout = environment["TIMEOUT"].flatMap({ Int($0) }) ?? 60

let regexForCodeblock = try! NSRegularExpression(pattern: "```[a-zA-Z]*\\n([\\s\\S]*?\\n)```",
                                                 options: [.anchorsMatchLines, .dotMatchesLineSeparators])

let regexForVersion = try! NSRegularExpression(pattern: "^.*\\(([^\\)]*)\\)$",
                                               options: [.anchorsMatchLines])


let (_, version, _) = execute(["swift", "--version"])
let playing = regexForVersion.firstMatch(in: version).last ?? version

let bot = Sword(token: discordToken)

print("🤖online")
bot.editStatus(to: "online", playing: playing)

bot.on(.guildAvailable) { data in
    guard let guild = data as? Guild else {
        return
    }
    guild.setNickname(to: playing.replacingOccurrences(of: "-RELEASE", with: "")) { error in
        if let error = error {
            print("failed to change nickname with error: \(error)")
        }
    }
}

bot.on(.messageCreate) { data in
    guard let message = data as? Message,
        message.author?.id != bot.user?.id,
        !(message.author?.isBot ?? false),
        message.mentions.contains(where: { $0.id == bot.user?.id }) else { return }

    let match = regexForCodeblock.firstMatch(in: message.content)
    guard match.count > 1 else {
        return
    }
    let code = match[1]

    let sessionUUID = UUID().uuidString
#if os(macOS)
    let tempURL = URL(fileURLWithPath: "/tmp").appendingPathComponent(sessionUUID)
#elseif os(Linux)
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(sessionUUID)
#endif
    let mainSwiftURL = tempURL.appendingPathComponent("main.swift")
    do {
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
        try code.write(to: mainSwiftURL, atomically: true, encoding: .utf8)
    } catch {
        message.reply(with: "failed to write `main.swift` with error: \(error)")
        return
    }

    defer {
        do {
            try FileManager.default.removeItem(at: tempURL)
        } catch {
            message.reply(with: "failed to remove temporary directory with error: \(error)")
        }
    }

#if os(macOS)
    let temp = tempURL.path
    // execute in docker
    let args = ["docker", "run", "--rm", "-v", "\(temp):\(temp)", "-w", temp, "norionomura/swift:41",
                "timeout", "\(timeout)", "swift", "main.swift"]
#elseif os(Linux)
    let args = ["timeout", "\(timeout)", "swift", "main.swift"]
#endif
    let (status, output, error) = execute(args, in: tempURL)

    if status == 124 {
        message.reply(with: "execution timeout")
    }

    func codeblock<S: CustomStringConvertible>(_ string: S) -> String {
        return """
            ```
            \(string)
            ```

            """
    }

    let contentsLimit = 1950
    if !output.isEmpty {
        if output.count > contentsLimit {
            let code = output[..<output.index(output.startIndex, offsetBy: contentsLimit)]
            message.reply(with: codeblock(code))
            do {
                let outputFileURL = tempURL.appendingPathComponent("stdout.txt")
                try output.write(to: outputFileURL, atomically: true, encoding: .utf8)
                message.reply(with: ["file": outputFileURL.path])
            } catch {
                message.reply(with: "failed to write `stdout.txt` with error: \(error)")
            }
        } else {
            message.reply(with: codeblock(output))
        }
    }
    if !error.isEmpty {
        if error.count > contentsLimit {
            let code = error[..<error.index(error.startIndex, offsetBy: contentsLimit)]
            message.reply(with: "error:\n" + codeblock(code))
            do {
                let errorFileURL = tempURL.appendingPathComponent("stderr.txt")
                try error.write(to: errorFileURL, atomically: true, encoding: .utf8)
                message.reply(with: ["file": errorFileURL.path])
            } catch {
                message.reply(with: "failed to write `stdout.txt` with error: \(error)")
            }
        } else {
            message.reply(with: "error:\n" + codeblock(error))
        }
    }
}

bot.connect()
