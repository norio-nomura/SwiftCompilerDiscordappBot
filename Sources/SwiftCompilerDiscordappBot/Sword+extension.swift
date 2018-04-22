//
//  Sword+extension.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/14/18.
//

import Sword

extension Message {
    func log(_ message: String) {
        App.log("\(id): " + message)
    }

    func answer(
        with content: String,
        stdout: String? = nil,
        stderr: String? = nil,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        let fields = [(stdout, "stdout.txt"), (stderr, "stderr.txt")]
            .parallelCompactMap { upload($0.0, as: $0.1) }
            .map {["name": "stdout", "value": "\($0)", "inline": true]}
        let message = fields.isEmpty ? ["content": content] : ["content": content, "embeds": ["fields": fields]]
        if let replyID = App.repliedRequests[id].replyID {
            channel.editMessage(replyID, with: message, then: completion)
        } else {
            let messageID = self.id
            reply(with: message) { reply, error in
                App.repliedRequests[messageID].replyID = reply?.id
                completion?(reply, error)
            }
        }
    }

    func answerStdout(
        with filename: String?,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        guard let filename = filename else { return }
        let messageID = self.id
        if let stdoutID = App.repliedRequests[messageID].stdoutID {
            channel.deleteMessage(stdoutID)
            App.repliedRequests[messageID].stdoutID = nil
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[messageID].stdoutID = reply?.id
                completion?(reply, error)
            }
        } else {
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[messageID].stdoutID = reply?.id
                completion?(reply, error)
            }
        }
    }

    func answerStderr(
        with filename: String?,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        guard let filename = filename else { return }
        let messageID = self.id
        if let stderrID = App.repliedRequests[messageID].stderrID {
            channel.deleteMessage(stderrID)
            App.repliedRequests[messageID].stdoutID = nil
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[messageID].stderrID = reply?.id
                completion?(reply, error)
            }
        } else {
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[messageID].stderrID = reply?.id
                completion?(reply, error)
            }
        }
    }

    func answer(
        with error: Swift.Error,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        answer(with: "\(error)", then: completion)
        log("\(id): \(error)")
    }

    func deleteAnswers() {
        deleteAnswer()
        deleteStdoutAnswer()
        deleteStderrAnswer()
        App.repliedRequests[id] = (nil, nil, nil)
    }

    func deleteAnswer() {
        channel.deleteAnswer(for: id)
    }

    func deleteStdoutAnswer() {
        channel.deleteStdoutAnswer(for: id)
    }

    func deleteStderrAnswer() {
        channel.deleteStderrAnswer(for: id)
    }

    func parse() -> (options: [String], swiftCode: String) {
        // MARK: first line is used to options for swift
        let mentionedLine = Message.regexForMentionedLine.firstMatch(in: content)[1]
        let optionsString = mentions.reduce(mentionedLine) {
            // remove mentions
            $0.replacingOccurrences(of: "<@\($1.id)>", with: "").replacingOccurrences(of: "<@!\($1.id)>", with: "")
        }
        let options = optionsString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // MARK: parse codeblock
        let swiftCode = Message.regexForCodeblock.firstMatch(in: content).last ?? ""

        return (options, swiftCode)
    }

    private static let regexForCodeblock = regex(pattern: "^```.*?\\n([\\s\\S]*?\\n)```")
    private static let regexForMentionedLine = regex(pattern: "^.*?<@!?\(App.bot.user!.id)>(.*?)$")
}

extension TextChannel {
    func deleteAnswer(for requestID: Snowflake) {
        if let replyID = App.repliedRequests[requestID].replyID {
            deleteMessage(replyID) {
                if let error = $0 {
                    App.log("failed to delete message: \(replyID) with error: \(error)")
                }
            }
            App.repliedRequests[requestID].replyID = nil
        }
    }

    func deleteStdoutAnswer(for requestID: Snowflake) {
        if let stdoutID = App.repliedRequests[requestID].stdoutID {
            deleteMessage(stdoutID) {
                if let error = $0 {
                    App.log("failed to delete stdout answer: \(stdoutID) with error: \(error)")
                }
            }
            App.repliedRequests[requestID].stdoutID = nil
        }
    }

    func deleteStderrAnswer(for requestID: Snowflake) {
        if let stderrID = App.repliedRequests[requestID].stderrID {
            deleteMessage(stderrID) {
                if let error = $0 {
                    App.log("failed to delete stderr answer: \(stderrID) with error: \(error)")
                }
            }
            App.repliedRequests[requestID].stderrID = nil
        }
    }
}

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}
