//
//  execute().swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/12/18.
//

import Foundation

func execute(_ args: [String], in directory: URL? = nil) -> (stdout: String, stderr: String) {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = args
    if let directory = directory {
        process.currentDirectoryPath = directory.path
    }
    var environment = ProcessInfo.processInfo.environment
    environment["DISCORD_TOKEN"] = nil
    environment["TIMEOUT"] = nil
    process.environment = environment
    let stdoutPipe = Pipe(), stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.launch()
    process.waitUntilExit()
    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (stdout, stderr)
}
