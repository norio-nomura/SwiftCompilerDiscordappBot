//
//  Sword+extension.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/14/18.
//

import Dispatch
import Sword

extension Message {
    func log(_ message: String) {
        App.log("\(id): " + message)
    }

    // AnswerID for Request
    fileprivate static var answerID = AnswerIDs()
    fileprivate struct AnswerIDs {
        private var requestAnswerMap = [Snowflake: Snowflake]()
        private let queue = DispatchQueue(label: "answeredMessages")
        subscript(for requestID: Snowflake) -> Snowflake? {
            get { return queue.sync { requestAnswerMap[requestID] } }
            set { queue.sync { requestAnswerMap[requestID] = newValue } }
        }
    }

    func answer(
        with content: String,
        stdout: String? = nil,
        stderr: String? = nil,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        let files: [(name: String, content: String?)] = [("stdout.txt", stdout), ("stderr.txt", stderr)]
        let fields = files
            .parallelCompactMap { file in
                upload(file.content, as: file.name).map { (file.name, $0) }
            }
            .map { ["name": $0.0, "value": $0.1, "inline": true] }
        let message = fields.isEmpty ? ["content": content] : ["content": content, "embed": ["fields": fields]]
        if let answerID = Message.answerID[for: id] {
            channel.editMessage(answerID, with: message, then: completion)
        } else {
            let requestID = id
            reply(with: message) { answer, error in
                Message.answerID[for: requestID] = answer?.id
                completion?(answer, error)
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

    func deleteAnswer() {
        channel.deleteAnswer(for: id)
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
        if let answerID = Message.answerID[for: requestID] {
            deleteMessage(answerID) {
                if let error = $0 {
                    App.log("failed to delete message: \(answerID) with error: \(error)")
                }
            }
            Message.answerID[for: requestID] = nil
        }
    }
}

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}
