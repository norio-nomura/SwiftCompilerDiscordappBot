import Foundation
import Sword

let environment = ProcessInfo.processInfo.environment
guard let discordToken = environment["DISCORD_TOKEN"], !discordToken.isEmpty else {
    fatalError("Can't find `DISCORD_TOKEN` environment variable!")
}

let timeout = environment["TIMEOUT"].flatMap({ Int($0) }) ?? 60

let regexForCodeblock = try! NSRegularExpression(pattern: "```[a-zA-Z]*\\n([\\s\\S]*?\\n)```",
                                                 options: [.anchorsMatchLines, .dotMatchesLineSeparators])

let regexForVersion = try! NSRegularExpression(pattern: "^.*\\(([^\\)]*)\\)$",
                                               options: [.anchorsMatchLines])


let (version, _) = execute(["swift", "--version"])
let playing = regexForVersion.firstMatch(in: version).last ?? version

let bot = Sword(token: discordToken)

print("🤖online")
bot.editStatus(to: "online", playing: playing)

bot.on(.messageCreate) { data in
    guard let message = data as? Message,
        message.author?.id != bot.user?.id,
        message.mentions.contains(where: { $0.id == bot.user?.id }) else { return }

    let match = regexForCodeblock.firstMatch(in: message.content)
    guard match.count > 1 else {
        return
    }
    let code = match[1]

    let sessionUUID = UUID().uuidString
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(sessionUUID)
    let mainSwiftURL = tempURL.appendingPathComponent("main.swift")
    do {
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
        try code.write(to: mainSwiftURL, atomically: true, encoding: .utf8)
    } catch {
        message.reply(with: "failed to write `main.swift` with error: \(error)")
    }

    let args = ["sh", "-c", "timeout \(timeout) swift main.swift || if [ $? -eq 124 ]; then echo timeout>&2; fi"]
    let (output, error) = execute(args, in: tempURL)

    var reply = ""
    if !output.isEmpty {
        reply += """
        ```
        \(output)
        ```

        """
    }
    if !error.isEmpty {
        reply += """
        error:
        ```
        \(error)
        ```

        """
    }
    message.reply(with: reply)
}

bot.connect()
