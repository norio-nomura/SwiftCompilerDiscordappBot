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

    func loggedReply(
        with message: String,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        reply(with: message, then: completion)
        log(message)
    }

    func answer(
        with message: String,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        if let replyID = App.repliedRequests[id].replyID {
            channel.editMessage(replyID, with: ["content": message], then: completion)
        } else {
            let id = self.id
            reply(with: message) { reply, error in
                App.repliedRequests[id].replyID = reply?.id
                completion?(reply, error)
            }
        }
    }

    func answerStdout(
        with filename: String?,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ){
        guard let filename = filename else { return }
        let id = self.id
        if let stdoutID = App.repliedRequests[id].stdoutID {
            channel.deleteMessage(stdoutID)
            App.repliedRequests[id].stdoutID = nil
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[id].stdoutID = reply?.id
                completion?(reply, error)
            }
        } else {
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[id].stdoutID = reply?.id
                completion?(reply, error)
            }
        }
    }

    func answerStderr(
        with filename: String?,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ){
        guard let filename = filename else { return }
        let id = self.id
        if let stderrID = App.repliedRequests[id].stderrID {
            channel.deleteMessage(stderrID)
            App.repliedRequests[id].stdoutID = nil
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[id].stderrID = reply?.id
                completion?(reply, error)
            }
        } else {
            reply(with: ["file": filename]) { reply, error in
                App.repliedRequests[id].stderrID = reply?.id
                completion?(reply, error)
            }
        }
    }

    func answer(
        with error: Swift.Error,
        then completion: ((Message?, RequestError?) -> Void)? = nil
    ) {
        answer(with: "\(error)", then: completion)
        App.log("\(id): \(error)")
    }

    func deleteAnswers() {
        deleteAnswer()
        deleteStdoutAnswer()
        deleteStderrAnswer()
        App.repliedRequests[id] = (nil, nil, nil)
    }

    func deleteAnswer() {
        if let replyID = App.repliedRequests[id].replyID {
            channel.deleteMessage(replyID) {
                if let error = $0 {
                    App.log("failed to delete message: \(replyID) with error: \(error)")
                }
            }
            App.repliedRequests[id].replyID = nil
        }
    }

    func deleteStdoutAnswer() {
        if let stdoutID = App.repliedRequests[id].stdoutID {
            channel.deleteMessage(stdoutID) {
                if let error = $0 {
                    App.log("failed to delete stdout answer: \(stdoutID) with error: \(error)")
                }
            }
            App.repliedRequests[id].stdoutID = nil
        }
    }

    func deleteStderrAnswer() {
        if let stderrID = App.repliedRequests[id].stderrID {
            channel.deleteMessage(stderrID) {
                if let error = $0 {
                    App.log("failed to delete stderr answer: \(stderrID) with error: \(error)")
                }
            }
            App.repliedRequests[id].stderrID = nil
        }
    }
}

extension User: Equatable {
    public static func ==(lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}
