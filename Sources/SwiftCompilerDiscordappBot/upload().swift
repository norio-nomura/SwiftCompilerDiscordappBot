//
//  upload().swift
//  SwiftCompilerDiscordappBot
//
//  Created by Norio Nomura on 4/22/18.
//

import Dispatch
import Foundation

let uploaderURL = URL(string: "https://file.io/")!

#if os(macOS) || os(Linux) && swift(>=4.1)
let session = URLSession.shared
#else
let session = URLSession(configuration: .default)
#endif

func upload(_ text: String?, as filename: String) -> String? {
    guard let text = text else { return nil }

    var request = URLRequest(url: uploaderURL)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()
    data.append("--\(boundary)\r\n")
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
    data.append("Content-Type: text/plain\r\n\r\n")
    data.append(text)
    data.append("\r\n--\(boundary)--\r\n")

    var uploadedLink: String?
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
            App.log("failed to unwrap data returned from file.io")
            return
        }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            if payload.success {
                uploadedLink = payload.link
            }
        } catch {
            App.log("failed to decode payload with error: \(error)")
        }
    }
    task.resume()
    semaphore.wait()

    return uploadedLink
}

private struct Payload: Decodable {
    var success: Bool
    var key: String
    var link: String
    var expiry: String
}

extension Data {
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}
