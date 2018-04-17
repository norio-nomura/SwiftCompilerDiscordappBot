//
//  execute().swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/12/18.
//

import Dispatch
import Foundation

func execute(_ args: [String], in directory: URL? = nil) -> (status: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = args
    if let directory = directory {
        process.currentDirectoryPath = directory.path
    }
    var environment = ProcessInfo.processInfo.environment
    environment["DISCORD_TOKEN"] = nil
    environment["DYNO"] = nil
    environment["PORT"] = nil
    environment["TIMEOUT"] = nil
    process.environment = environment
    let stdoutPipe = Pipe(), stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    let group = DispatchGroup(), queue = DispatchQueue.global()
    var stdoutData: Data?, stderrData: Data?
    process.launch()
    queue.async(group: group) { process.waitUntilExit() }
    queue.async(group: group) { stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
    queue.async(group: group) { stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile() }
    group.wait()
    let stdout = stdoutData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    let stderr = stderrData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    return (process.terminationStatus, stdout, stderr)
}
