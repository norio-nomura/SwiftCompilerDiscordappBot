//
//  Message+extension.swift
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
}
