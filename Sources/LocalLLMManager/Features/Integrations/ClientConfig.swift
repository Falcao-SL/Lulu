import Darwin
import Foundation

enum ClientID: String, CaseIterable, Identifiable {
    case opencode, codex, claude, aider, zed, openbot, pi

    func supports(engine: String?) -> Bool {
        switch self {
        case .codex, .claude: return engine == nil || engine == "llama.cpp"
        case .openbot: return engine == nil || engine == "mlx-lm" || engine == "mlx-vlm"
        default: return true
        }
    }

    var route: String {
        switch self {
        case .codex: return "/v1/responses"
        case .claude: return "/v1/messages"
        default: return "/v1/chat/completions"
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opencode: return "OpenCode"
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        case .aider: return "Aider"
        case .zed: return "Zed"
        case .openbot: return "OpenBot"
        case .pi: return "Pi"
        }
    }
}

struct ClientNotice: Identifiable {
    let id = UUID()
    let client: ClientID
    let detail: String
}

struct ClientRequest {
    var port: Int
    var modelID: String
    var displayName: String
    var context: Int
    var vision: Bool
    var apiKey: String

    var baseURL: String { "http://127.0.0.1:\(port)/v1" }
    var origin: String { "http://127.0.0.1:\(port)" }
}

struct ClientRoots {
    var home: URL
    var piAgentDirectory: URL?

    static var real: ClientRoots {
        let directory = ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"].flatMap { path in
            path.isEmpty ? nil : URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return ClientRoots(home: FileManager.default.homeDirectoryForCurrentUser, piAgentDirectory: directory)
    }

    func file(_ parts: String...) -> URL {
        parts.reduce(home) { $0.appendingPathComponent($1) }
    }
}

enum ClientConfig {
    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    static func apply(_ client: ClientID, _ request: ClientRequest, roots: ClientRoots = .real) throws -> String {
        switch client {
        case .opencode:
            try OpenCodeClient.write(
                baseURL: request.baseURL,
                displayName: request.displayName,
                modelID: request.modelID,
                context: request.context,
                vision: request.vision,
                apiKey: request.apiKey,
                directory: roots.file(".config", "opencode")
            )
        case .codex:
            try writeCodex(request, file: roots.file(".codex", "config.toml"))
        case .claude:
            try writeClaude(request, file: roots.file(".claude", "settings.json"))
        case .aider:
            try writeAider(request, file: roots.file(".aider.conf.yml"))
        case .zed:
            try writeZed(request, file: roots.file(".config", "zed", "settings.json"))
        case .openbot:
            try writeOpenBot(request, file: roots.file("Library", "Application Support", "OpenBot", "openbot-custom-providers-v1.json"))
        case .pi:
            let directory = roots.piAgentDirectory ?? roots.file(".pi", "agent")
            try writePi(request, file: directory.appendingPathComponent("models.json"))
        }
        return message(client, request)
    }

    private static func message(_ client: ClientID, _ request: ClientRequest) -> String {
        let name = request.displayName
        switch client {
        case .opencode:
            return "OpenCode now uses \(name) at \(request.baseURL). Restart OpenCode if it is open."
        case .codex:
            return "Codex now uses \(name) at \(request.baseURL). Open a new Codex session."
        case .claude:
            return "Claude Code now uses \(name) at \(request.origin). Open a new session."
        case .aider:
            return "Aider now uses \(name) at \(request.baseURL)."
        case .zed:
            return "Zed now uses \(name) at \(request.baseURL). Add Lulu’s access key in Zed under Agent Settings → LLM Providers → Lulu, then select the model."
        case .openbot:
            return "Lulu is configured in OpenBot at \(request.baseURL). Choose \(name) in OpenBot’s model picker to use it."
        case .pi:
            return "Choose \(name) under Lulu in Pi’s /model picker. If Pi is already open, run /reload first."
        }
    }

    private static func writePi(_ request: ClientRequest, file: URL) throws {
        var root = try readJSON(file, client: "Pi")
        guard var providers = (root["providers"] ?? [:]) as? [String: Any] else {
            throw Failure(message: "Could not update Pi: models.json has an invalid providers object.")
        }
        let id = "lulu-local"
        let api = "openai-completions"
        if let current = providers[id] {
            guard let provider = current as? [String: Any],
                  provider["api"] as? String == api,
                  let address = (provider["baseUrl"] as? String).flatMap(URL.init(string:)),
                  address.scheme == "http", address.host == "127.0.0.1", address.path == "/v1" else {
                throw Failure(message: "A Pi provider already uses the lulu-local ID. Rename it in models.json before connecting Lulu.")
            }
        }
        let model: [String: Any] = [
            "id": request.modelID,
            "name": request.displayName,
            "input": request.vision ? ["text", "image"] : ["text"],
            "contextWindow": request.context,
            "maxTokens": max(1, min(4096, request.context / 4)),
            "cost": ["input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0],
        ]
        providers[id] = [
            "name": "Lulu",
            "baseUrl": request.baseURL,
            "api": api,
            "apiKey": request.apiKey.isEmpty ? "lulu-local" : request.apiKey,
            "compat": ["supportsStore": false, "maxTokensField": "max_tokens"],
            "models": [model],
        ]
        root["providers"] = providers
        try writePrivateJSON(root, to: file)
    }

    private static func writeOpenBot(_ request: ClientRequest, file: URL) throws {
        guard request.apiKey.isEmpty else {
            throw Failure(message: "OpenBot requires its own secure storage for API keys. Use an MLX model for automatic setup.")
        }
        var root: [String: Any] = ["version": 1, "providers": []]
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["version"] as? Int == 1 else {
                throw Failure(message: "The OpenBot provider settings could not be read as version 1.")
            }
            root = object
        }
        guard var providers = root["providers"] as? [[String: Any]] else {
            throw Failure(message: "OpenBot’s provider list has an unsupported format.")
        }
        let index = providers.firstIndex { $0["id"] as? String == "lulu-local" }
        var lulu = index.map { providers[$0] } ?? [:]
        if !lulu.isEmpty {
            guard (lulu["secret"] == nil || lulu["secret"] is NSNull),
                  let previousURL = (lulu["baseUrl"] as? String).flatMap(URL.init(string:)),
                  previousURL.scheme == "http", previousURL.host == "127.0.0.1" else {
                throw Failure(message: "An OpenBot provider already uses the Lulu Local ID. Rename that provider in OpenBot first.")
            }
        }
        var model: [String: Any] = ["id": request.modelID, "name": request.displayName]
        if (1_024...100_000_000).contains(request.context) { model["contextWindow"] = request.context }
        if request.vision { model["inputs"] = ["image"] }
        lulu["id"] = "lulu-local"
        lulu["name"] = "Lulu"
        lulu["baseUrl"] = request.baseURL
        lulu["models"] = [model]
        lulu["secret"] = NSNull()
        if let index { providers[index] = lulu }
        else { providers.append(lulu) }
        root["providers"] = providers
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeJSON(root, to: file)
    }

    private static func writeCodex(_ request: ClientRequest, file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let previous = FileManager.default.fileExists(atPath: file.path)
            ? try String(contentsOf: file, encoding: .utf8) : ""
        var lines = previous.components(separatedBy: "\n")
        let rootEnd = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
        let keys = ["model", "model_provider"]
        let root = lines[..<rootEnd].filter { line in
            let key = line.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces)
            return !keys.contains(key ?? "")
        }
        lines.replaceSubrange(..<rootEnd, with: [
            "model = \(tomlString(request.modelID))",
            "model_provider = \"lulu\"",
        ] + root)
        var text = lines.joined(separator: "\n")
        let block = """
        [model_providers.lulu]
        name = "Lulu"
        base_url = \(tomlString(request.baseURL))
        wire_api = "responses"
        requires_openai_auth = false
        experimental_bearer_token = \(tomlString(request.apiKey))
        """
        text = replaceTomlTable(text, header: "[model_providers.lulu]", with: block)
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    private static func replaceTomlTable(_ text: String, header: String, with block: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header }) {
            var end = start + 1
            while end < lines.count {
                let line = lines[end].trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("[") && line.hasSuffix("]") { break }
                end += 1
            }
            lines.replaceSubrange(start..<end, with: block.components(separatedBy: "\n"))
        } else {
            if lines.last != "" { lines.append("") }
            lines.append(contentsOf: block.components(separatedBy: "\n"))
        }
        var result = lines.joined(separator: "\n")
        if !result.hasSuffix("\n") { result.append("\n") }
        return result
    }

    private static func writeClaude(_ request: ClientRequest, file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Failure(message: "Could not update Claude Code: settings.json is not valid JSON.")
            }
            root = parsed
        }
        var env = root["env"] as? [String: Any] ?? [:]
        env["ANTHROPIC_BASE_URL"] = request.origin
        env["ANTHROPIC_AUTH_TOKEN"] = request.apiKey
        env["ANTHROPIC_MODEL"] = request.modelID
        env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
        root["env"] = env
        try writeJSON(root, to: file)
    }

    private static func writeAider(_ request: ClientRequest, file: URL) throws {
        let previous = FileManager.default.fileExists(atPath: file.path)
            ? try String(contentsOf: file, encoding: .utf8) : ""
        var lines = previous.components(separatedBy: "\n")
        let updates = [
            "openai-api-base": yamlString(request.baseURL),
            "openai-api-key": yamlString(request.apiKey),
            "model": yamlString("openai/" + request.modelID),
        ]
        for (key, value) in updates {
            let line = "\(key): \(value)"
            if let index = lines.firstIndex(where: { $0.hasPrefix("\(key):") || $0.hasPrefix("\(key) :") }) {
                lines[index] = line
            } else {
                lines.append(line)
            }
        }
        var text = lines.joined(separator: "\n")
        if !text.hasSuffix("\n") { text.append("\n") }
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    private static func writeZed(_ request: ClientRequest, file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var root = try readJSON(file, client: "Zed")
        var languages = root["language_models"] as? [String: Any] ?? [:]
        var providers = languages["openai_compatible"] as? [String: Any] ?? [:]
        var openai = providers["Lulu"] as? [String: Any] ?? [:]
        openai["api_url"] = request.baseURL
        openai.removeValue(forKey: "api_key")
        var models = openai["available_models"] as? [[String: Any]] ?? []
        models.removeAll { ($0["name"] as? String) == request.modelID || ($0["name"] as? String) == "lulu" }
        models.insert([
            "name": request.modelID,
            "display_name": request.displayName,
            "max_tokens": request.context,
            "capabilities": ["images": request.vision, "max_tokens_parameter": true],
        ], at: 0)
        openai["available_models"] = models
        providers["Lulu"] = openai
        languages["openai_compatible"] = providers
        root["language_models"] = languages
        try writeJSON(root, to: file)
    }

    static func readJSON(_ file: URL, client: String) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        let source = try String(contentsOf: file, encoding: .utf8)
        // Match string literals first so // and /* inside strings are preserved.
        let tokens = try NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/"#)
        let range = NSRange(source.startIndex..., in: source)
        var cleaned = source
        for token in tokens.matches(in: source, range: range).reversed() {
            guard let span = Range(token.range, in: cleaned), cleaned[span].hasPrefix("/") else { continue }
            cleaned.replaceSubrange(span, with: " ")
        }
        let commas = try NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|(,)(?=\s*[}\]])"#)
        for token in commas.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)).reversed() {
            if let span = Range(token.range(at: 1), in: cleaned) { cleaned.removeSubrange(span) }
        }
        guard let object = try? JSONSerialization.jsonObject(with: Data(cleaned.utf8)) as? [String: Any] else {
            throw Failure(message: "Could not update \(client): \(file.lastPathComponent) has invalid settings.")
        }
        return object
    }

    private static func writeJSON(_ object: [String: Any], to file: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        var text = String(decoding: data, as: UTF8.self)
        if !text.hasSuffix("\n") { text.append("\n") }
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    private static func writePrivateJSON(_ object: [String: Any], to file: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".lulu-\(UUID().uuidString).tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        try handle.write(contentsOf: data)
        try handle.write(contentsOf: Data([10]))
        try handle.close()
        guard rename(temporary.path, file.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    }

    private static func tomlString(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func yamlString(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
