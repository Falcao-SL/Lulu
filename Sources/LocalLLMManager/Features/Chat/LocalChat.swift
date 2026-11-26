import Foundation

struct ChatInputCapabilities: Encodable {
    var image = false
    var audio = false

    func allows(_ attachment: ChatAttachment) -> Bool {
        switch attachment.kind {
        case .image: return image && ["png", "jpeg"].contains(attachment.format)
        case .audio: return audio && ["wav", "mp3", "flac"].contains(attachment.format)
        }
    }
}

struct ChatAttachment: Codable {
    enum Kind: String, Codable { case image, audio }

    static let maxFileBytes = 4 * 1024 * 1024
    static let maxConversationBytes = 12 * 1024 * 1024

    let kind: Kind
    let format: String
    let data: Data
    let name: String?
    let size: Int?
}

struct ChatMessage: Decodable, Encodable {
    enum Role: String, Codable {
        case user, assistant
    }

    let role: Role
    let content: String
    let attachments: [ChatAttachment]?

    private enum CodingKeys: String, CodingKey { case role, content, attachments }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        guard let attachments, !attachments.isEmpty else {
            try container.encode(content, forKey: .content)
            return
        }
        var parts = container.nestedUnkeyedContainer(forKey: .content)
        let prompt = content.isEmpty ? "Describe the attached media." : content
        try parts.encode(["type": "text", "text": prompt])
        for attachment in attachments { try parts.encode(MediaPart(attachment: attachment)) }
    }

    private struct MediaPart: Encodable {
        let attachment: ChatAttachment
        private enum Keys: String, CodingKey { case type, image_url, input_audio }

        func encode(to encoder: Encoder) throws {
            var part = encoder.container(keyedBy: Keys.self)
            let base64 = attachment.data.base64EncodedString()
            switch attachment.kind {
            case .image:
                try part.encode("image_url", forKey: .type)
                try part.encode(["url": "data:image/\(attachment.format);base64,\(base64)"], forKey: .image_url)
            case .audio:
                try part.encode("input_audio", forKey: .type)
                try part.encode(["data": base64, "format": attachment.format], forKey: .input_audio)
            }
        }
    }
}

struct LocalChatEndpoint: Sendable {
    let port: Int
    let modelID: String
    let key: String

    private struct Request: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream = true
        let max_tokens = 512
    }

    private struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }

            let delta: Delta
            let finish_reason: String?
        }

        struct APIError: Decodable {
            let message: String
        }

        let choices: [Choice]?
        let error: APIError?
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    @MainActor
    func stream(_ messages: [ChatMessage], onText: (String) async throws -> Void) async throws {
        guard let url = URL(string: "http://127.0.0.1:\(port)/v1/chat/completions") else {
            throw Failure(message: "The local server address is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(Request(model: modelID, messages: messages))

        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 120
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw Failure(message: "The local server could not start the conversation (HTTP \(status)).")
        }

        let decoder = JSONDecoder()
        var finished = false
        var hasText = false
        for try await line in bytes.lines where line.hasPrefix("data:") {
            try Task.checkCancellation()
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" {
                finished = true
                break
            }
            let chunk = try decoder.decode(Chunk.self, from: Data(payload.utf8))
            if let error = chunk.error { throw Failure(message: error.message) }
            if let choice = chunk.choices?.first {
                if let text = choice.delta.content, !text.isEmpty, hasText || text != "</think>" {
                    hasText = true
                    try await onText(text)
                }
                finished = finished || choice.finish_reason != nil
            }
        }
        guard hasText else {
            throw Failure(message: "The model returned no text. Try a shorter prompt or another model.")
        }
        guard finished else {
            throw Failure(message: "The local server ended the stream before finishing its response.")
        }
    }
}
