//
//  NSRegularExpression+extension.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/12/18.
//

import Foundation

func regex(
    pattern: String,
    options: NSRegularExpression.Options = [.anchorsMatchLines, .dotMatchesLineSeparators]
) -> NSRegularExpression {
    return try! .init(pattern: pattern, options: options) // swiftlint:disable:this force_try
}

extension NSRegularExpression {
    func firstMatch(in string: String, options: NSRegularExpression.MatchingOptions = []) -> [String] {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = firstMatch(in: string, options: options, range: range) else {
            return []
        }

        return (0..<match.numberOfRanges)
            .map(match.range(at:))
            .compactMap { Range.init($0, in: string) }
            .map { String(string[$0]) }
    }
}

#if (!swift(>=4.1) && swift(>=4.0)) || !swift(>=3.3)

extension Sequence {
    func compactMap<ElementOfResult>(
        _ transform: (Self.Element
        ) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
        return try flatMap(transform)
    }
}

#endif
