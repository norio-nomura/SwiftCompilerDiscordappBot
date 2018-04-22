//
//  Array+extension.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/22/18.
//

import Dispatch

extension Array {
    func parallelCompactMap<T>(transform: @escaping ((Element) -> T?)) -> [T] {
        return parallelMap(transform: transform).compactMap { $0 }
    }

    func parallelFlatMap<T>(transform: @escaping ((Element) -> [T])) -> [T] {
        return parallelMap(transform: transform).flatMap { $0 }
    }

    func parallelMap<T>(transform: (Element) -> T) -> [T] {
        var result = ContiguousArray<T?>(repeating: nil, count: count)
        return result.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { idx in
                buffer[idx] = transform(self[idx])
            }
            return buffer.map { $0! }
        }
    }
}
