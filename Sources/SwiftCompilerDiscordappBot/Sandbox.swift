//
//  Sandbox.swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/12/18.
//

import Foundation

struct Sandbox {
    let hostRootURL: URL
    let rootURL: URL
    let code: String
    let dockerImage: String
    let timeout: Int
    let codeFilename = "main.swift"
}

extension Sandbox {
    func execute(_ completion: (String, String) -> Void) {
        let tempPath = "temp/\(UUID().uuidString)"
        let tempURL = rootURL.appendingPathComponent(tempPath)
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            let mainSwiftURL = tempURL.appendingPathComponent(codeFilename)
            try code.write(to: mainSwiftURL, atomically: true, encoding: .utf8)
        } catch {
            completion("", "failed to write /usercode/main.swift with error: \(error)")
            return
        }
        defer {
            do { try FileManager.default.removeItem(at: tempURL) } catch {}
        }
        let hostRootDir = hostRootURL.appendingPathComponent(tempPath).path
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = [
            "docker", "run",
            "--rm",
            "--stop-timeout", String(timeout),
            "-v", "\(hostRootDir):/usercode",
            "-w", "/usercode",
            dockerImage,
            "sh", "-c", "swift --version && swift \(codeFilename)"
        ]
        let stdoutPipe = Pipe(), stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.launch()
        process.waitUntilExit()
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        completion(stdout, stderr)
    }
}
