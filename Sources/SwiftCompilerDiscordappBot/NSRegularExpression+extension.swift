//
//  NSRegularExpression+extension.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/12/18.
//

import Foundation

extension NSRegularExpression {
    func firstMatch(in string: String, options: NSRegularExpression.MatchingOptions = []) -> NSTextCheckingResult? {
        return firstMatch(in: string, options: options, range: NSRange(string.startIndex..<string.endIndex, in: string))
    }
}
