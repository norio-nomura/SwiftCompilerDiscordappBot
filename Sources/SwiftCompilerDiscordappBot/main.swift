import Foundation
import Sword

let environment = ProcessInfo.processInfo.environment
guard let discordToken = environment["DISCORD_TOKEN"], !discordToken.isEmpty else {
    fatalError("Can't find `DISCORD_TOKEN` environment variable!")
}
guard let hostPwd = environment["HOST_PWD"], !hostPwd.isEmpty else {
    fatalError("Can't find `HOST_PWD` environment variable!")
}

let hostRootURL = URL(fileURLWithPath: hostPwd)
let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let regex = try! NSRegularExpression(pattern: "```[a-zA-Z]*\\n([\\s\\S]*?\\n)```",
                                     options: [.anchorsMatchLines, .dotMatchesLineSeparators])

let bot = Sword(token: discordToken)

print("🤖online")
bot.editStatus(to: "online", playing: "with Sword!")

bot.on(.messageCreate) { data in
    guard let message = data as? Message,
        message.author?.id != bot.user?.id,
        message.mentions.contains(where: { $0.id == bot.user?.id }) else { return }

    guard let match = regex.firstMatch(in: message.content),
        let range = Range(match.range(at: 1), in: message.content) else {
        return
    }
    let code = String(message.content[range])
    guard !code.isEmpty else { return }
    let sandbox = Sandbox(hostRootURL: hostRootURL,
                          rootURL: rootURL,
                          code: code,
                          dockerImage: "norionomura/swift:41",
                          timeout: 60)

    sandbox.execute { output, error in
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
            ```
            \(error)
            ```
            
            """
        }
        message.reply(with: reply)
    }
}

bot.connect()
