import Foundation
import Network

struct WebChatStatus: Encodable {
    let model: String?
    let selection: String?
    let ready: Bool
    let message: String
    var inputs = ChatInputCapabilities()
    var appearance = LuluAppearance.system
}

@MainActor
final class WebChatServer {
    private let route = "/" + UUID().uuidString + "/"
    private let status: () -> WebChatStatus
    private let endpoint: () async throws -> LocalChatEndpoint
    fileprivate let history: ChatHistory
    private var listener: NWListener?
    private var pending: [(Result<URL, Error>) -> Void] = []
    private var address: URL?
    fileprivate var generating = false

    init(status: @escaping () -> WebChatStatus, endpoint: @escaping () async throws -> LocalChatEndpoint,
         history: ChatHistory = ChatHistory(file: LuluPaths.root.appendingPathComponent("chats.sqlite3"))) {
        self.status = status
        self.endpoint = endpoint
        self.history = history
    }

    func start(completion: @escaping (Result<URL, Error>) -> Void) {
        if let address {
            completion(.success(address))
            return
        }
        pending.append(completion)
        guard listener == nil else { return }

        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
            let listener = try NWListener(using: params)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                MainActor.assumeIsolated {
                    guard let listener else { return }
                    self?.handle(state, from: listener)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated {
                    guard let self, let port = self.address?.port else {
                        connection.cancel()
                        return
                    }
                    WebChatConnection(connection, server: self, host: "127.0.0.1:\(port)", route: self.route).start()
                }
            }
            listener.start(queue: .main)
        } catch {
            complete(.failure(error))
        }
    }

    private func handle(_ state: NWListener.State, from listener: NWListener) {
        guard self.listener === listener else { return }
        switch state {
        case .ready:
            guard let port = listener.port,
                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)\(route)") else {
                listener.cancel()
                return
            }
            address = url
            complete(.success(url))
        case .failed(let error):
            address = nil
            self.listener = nil
            listener.cancel()
            complete(.failure(error))
        case .cancelled:
            address = nil
            self.listener = nil
            complete(.failure(LocalChatEndpoint.Failure(message: "The browser chat could not start.")))
        default:
            break
        }
    }

    private func complete(_ result: Result<URL, Error>) {
        let callbacks = pending
        pending.removeAll()
        for callback in callbacks { callback(result) }
    }

    fileprivate func currentStatus() -> WebChatStatus { status() }

    fileprivate func stream(_ input: WebChatInput, onText: (String) async throws -> Void) async throws {
        let state = status()
        guard state.ready, state.selection == input.selection else {
            throw LocalChatEndpoint.Failure(message: "The active model changed. Wait for it to be ready and send again.")
        }
        var bytes = 0
        for message in input.messages {
            guard let attachments = message.attachments, !attachments.isEmpty else { continue }
            guard message.role == .user, attachments.count <= 2 else {
                throw LocalChatEndpoint.Failure(message: "Attach up to two files to a message you send.")
            }
            for attachment in attachments {
                guard state.inputs.allows(attachment), !attachment.data.isEmpty,
                      attachment.data.count <= ChatAttachment.maxFileBytes else {
                    throw LocalChatEndpoint.Failure(message: "This attachment is unsupported or larger than 4 MB.")
                }
                bytes += attachment.data.count
            }
        }
        guard bytes <= ChatAttachment.maxConversationBytes else {
            throw LocalChatEndpoint.Failure(message: "Start a new chat to attach more files. This conversation reached 12 MB of attachments.")
        }
        let target = try await endpoint()
        try await target.stream(input.messages, onText: onText)
    }
}

private struct WebChatInput: Decodable {
    let selection: String
    let messages: [ChatMessage]
}

private struct HistorySelection: Decodable {
    let id: String
    let revision: Int?
}

@MainActor
private final class WebChatConnection {
    private let connection: NWConnection
    private let server: WebChatServer
    private let host: String
    private let route: String
    private var buffer = Data()
    private var reading = true
    private var generation: Task<Void, Never>?

    private static let headerEnd = Data("\r\n\r\n".utf8)
    private static let maxHeader = 8_192
    private static let maxBody = ChatAttachment.maxConversationBytes * 4 / 3 + 524_288
    private static let responseHeaders = """
    Connection: close\r
    Cache-Control: no-store\r
    X-Content-Type-Options: nosniff\r
    Referrer-Policy: no-referrer\r
    Content-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'\r

    """

    init(_ connection: NWConnection, server: WebChatServer, host: String, route: String) {
        self.connection = connection
        self.server = server
        self.host = host
        self.route = route
    }

    func start() {
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.reading else { return }
            self.connection.cancel()
        }
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, done, error in
            MainActor.assumeIsolated {
                if error != nil {
                    self.connection.cancel()
                    return
                }
                if let data { self.buffer.append(data) }
                if self.readRequest() { return }
                if done { self.connection.cancel() }
                else { self.receive() }
            }
        }
    }

    private func readRequest() -> Bool {
        guard let delimiter = buffer.range(of: Self.headerEnd) else {
            if buffer.count <= Self.maxHeader { return false }
            return fail("431 Request Header Fields Too Large")
        }
        guard delimiter.lowerBound <= Self.maxHeader,
              let head = String(data: buffer[..<delimiter.lowerBound], encoding: .utf8) else {
            return fail("400 Bad Request")
        }
        let lines = head.components(separatedBy: "\r\n")
        guard let first = lines.first else { return fail("400 Bad Request") }
        let request = first.split(separator: " ")
        guard request.count == 3, request[2] == "HTTP/1.1" else { return fail("400 Bad Request") }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return fail("400 Bad Request") }
            let name = pair[0].lowercased()
            guard headers[name] == nil else { return fail("400 Bad Request") }
            headers[name] = pair[1].trimmingCharacters(in: .whitespaces)
        }
        guard headers["host"] == host, headers["transfer-encoding"] == nil,
              let length = Int(headers["content-length"] ?? "0"), length >= 0 else {
            return fail("400 Bad Request")
        }
        guard length <= Self.maxBody else { return fail("413 Content Too Large") }
        let end = delimiter.upperBound + length
        guard buffer.count >= end else { return false }
        reading = false

        switch (request[0], request[1]) {
        case ("GET", Substring(route)) where length == 0:
            let html = WebChatPage.html(appearance: server.currentStatus().appearance)
            reply("200 OK", type: "text/html; charset=utf-8", data: Data(html.utf8))
        case ("GET", Substring(route + "status")) where length == 0:
            do {
                reply("200 OK", type: "application/json", data: try JSONEncoder().encode(server.currentStatus()))
            } catch {
                return fail("500 Internal Server Error")
            }
        case ("GET", Substring(route + "history")) where length == 0:
            handleHistory("history", data: Data())
        case ("POST", let path) where path.hasPrefix(route + "history/"):
            guard headers["origin"] == "http://" + host, headers["content-type"] == "application/json" else {
                return fail("403 Forbidden")
            }
            let data = Data(buffer[delimiter.upperBound..<end])
            buffer.removeAll()
            handleHistory(String(path.dropFirst(route.count)), data: data)
        case ("POST", Substring(route + "message")):
            guard headers["origin"] == "http://" + host, headers["content-type"] == "application/json" else {
                return fail("403 Forbidden")
            }
            guard let input = try? JSONDecoder().decode(WebChatInput.self, from: buffer[delimiter.upperBound..<end]),
                  input.messages.last?.role == .user, input.messages.count <= 200 else {
                return fail("400 Bad Request")
            }
            guard !server.generating else { return fail("409 Conflict", "A response is already being generated.") }
            buffer.removeAll()
            run(input)
        default:
            return fail("404 Not Found")
        }
        return true
    }

    private func handleHistory(_ operation: String, data: Data) {
        Task {
            do {
                let decoder = JSONDecoder()
                let encoder = JSONEncoder()
                encoder.outputFormatting = .withoutEscapingSlashes
                let result: Data
                switch operation {
                case "history":
                    result = try await encoder.encode(server.history.list())
                case "history/load":
                    let selection = try decoder.decode(HistorySelection.self, from: data)
                    result = try await encoder.encode(server.history.load(id: selection.id))
                case "history/save":
                    let chat = try decoder.decode(SavedChat.self, from: data)
                    result = try await encoder.encode(server.history.save(chat))
                case "history/delete":
                    let selection = try decoder.decode(HistorySelection.self, from: data)
                    try await server.history.delete(id: selection.id, revision: selection.revision ?? 0)
                    result = Data("{}".utf8)
                default:
                    _ = fail("404 Not Found")
                    return
                }
                reply("200 OK", type: "application/json", data: result)
            } catch let error as ChatHistory.Failure {
                let status: String
                switch error {
                case .conflict: status = "409 Conflict"
                case .missing: status = "404 Not Found"
                case .invalid: status = "400 Bad Request"
                case .database: status = "500 Internal Server Error"
                }
                _ = fail(status, error.localizedDescription)
            } catch is DecodingError {
                _ = fail("400 Bad Request", "Invalid conversation.")
            } catch {
                _ = fail("500 Internal Server Error", "Lulu could not access the local chat history.")
            }
        }
    }

    private func fail(_ status: String, _ message: String? = nil) -> Bool {
        reading = false
        reply(status, type: "text/plain; charset=utf-8", data: Data((message ?? status).utf8))
        return true
    }

    private func reply(_ status: String, type: String, data: Data) {
        var response = Data("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(data.count)\r\n\(Self.responseHeaders)\r\n".utf8)
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { [connection] _ in connection.cancel() })
    }

    private func run(_ input: WebChatInput) {
        server.generating = true
        generation = Task {
            defer {
                server.generating = false
                generation = nil
                connection.cancel()
            }
            let header = "HTTP/1.1 200 OK\r\nContent-Type: application/x-ndjson\r\nTransfer-Encoding: chunked\r\n\(Self.responseHeaders)\r\n"
            do {
                try await send(Data(header.utf8))
                try await server.stream(input) { text in try await self.event(["text": text]) }
                try await event(["done": "true"])
            } catch {
                if !Task.isCancelled { try? await event(["error": error.localizedDescription]) }
            }
            if !Task.isCancelled { try? await send(Data("0\r\n\r\n".utf8)) }
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] _, _, _, _ in
            MainActor.assumeIsolated { self?.generation?.cancel() }
        }
    }

    private func event(_ value: [String: String]) async throws {
        var json = try JSONEncoder().encode(value)
        json.append(10)
        var chunk = Data("\(String(json.count, radix: 16))\r\n".utf8)
        chunk.append(json)
        chunk.append(Data("\r\n".utf8))
        try await send(chunk)
    }

    private func send(_ data: Data) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (result: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { result.resume(throwing: error) }
                else { result.resume() }
            })
        }
    }
}
