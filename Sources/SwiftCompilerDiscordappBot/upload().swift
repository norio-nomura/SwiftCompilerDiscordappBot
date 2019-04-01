//
//  upload().swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/22/18.
//

import Dispatch
import Foundation

enum Uploader: String {
    case fileio = "file.io"
    case ptpbpw = "ptpb.pw"
}

let uploader = ProcessInfo.processInfo.environment["UPLOADER"].flatMap(Uploader.init(rawValue:)) ?? .ptpbpw

func upload(_ text: String?, as filename: String) -> String? {
    switch uploader {
    case .fileio:
        return Fileio.upload(text, as: filename)
    case .ptpbpw:
        return Ptpbpw.upload(text, as: filename)
    }
}

// MARK: - https://file.io

struct Fileio {
    static let url = URL(string: "https://file.io/")!

    static func upload(_ text: String?, as filename: String) -> String? {
        guard let payload: FileioPayload = upload0(text, name: "file", as: filename, to: url),
            payload.success else { return nil }
        return payload.link
    }

    private struct FileioPayload: Decodable {
        var success: Bool
        var key: String
        var link: String
        var expiry: String
    }
}

// MARK: - https://ptpb.pw

struct Ptpbpw {
    static let ptpbpwURL = URL(string: "https://ptpb.pw")!

    static func upload(_ text: String?, as filename: String) -> String? {
        guard let payload: PtpbpwPayload = upload0(text, name: "c", as: filename, to: ptpbpwURL),
            payload.status == "created" else { return nil }
        App.log("Uploaded `\(payload.url)` that can be deleted by `curl -X DELETE https://ptpb.pw/\(payload.uuid)`.")
        return payload.url + "/text"
    }

    private struct PtpbpwPayload: Decodable {
        var date: String
        var digest: String
        var long: String
        var short: String
        var size: Int
        var status: String
        var url: String
        var uuid: String
    }
}

let session = URLSession.shared

private func upload0<T: Decodable>(_ text: String?, name: String, as filename: String, to url: URL) -> T? {
    guard let text = text else { return nil }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue("application/json", forHTTPHeaderField: "accept")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()
    data.append("--\(boundary)\r\n")
    data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
    data.append("Content-Type: application/octet-stream\r\n\r\n")
    data.append(text)
    data.append("\r\n--\(boundary)--\r\n")

    var payload: T?
    let semaphore = DispatchSemaphore(value: 0)
    let task = session.uploadTask(with: request, from: data) { data, response, error in
        defer { semaphore.signal() }
        if let error = error {
            App.log("failed to upload `\(filename)` with error: \(error)")
            return
        }
        guard let httpURLResponse = response as? HTTPURLResponse else {
            App.log("unknown response: \(String(describing: response))")
            return
        }
        guard (200...299).contains(httpURLResponse.statusCode) else {
            App.log("server error status: \(httpURLResponse.statusCode)")
            return
        }
        guard let data = data else {
            App.log("failed to unwrap data returned from \(url)")
            return
        }
        do {
            payload = try JSONDecoder().decode(T.self, from: data)
        } catch {
            App.log("failed to decode response with error: \(error)")
        }
    }
    task.resume()
    semaphore.wait()

    return payload
}

extension Data {
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}
