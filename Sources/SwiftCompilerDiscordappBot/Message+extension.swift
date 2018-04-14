//
//  Message+extension.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/14/18.
//

import Sword

extension Message {
    func loggedReply(
        with message: String,
        then completion: ((Message?, RequestError?) -> ())? = nil
    ) {
        reply(with: message, then: completion)
        print(message)
    }
}
