import Foundation
import SQLite3

enum ClientID: String, CaseIterable, Identifiable {
    case opencode, codex, agy, cursor, claude, openclaude, deepseek, aider, zed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opencode: return "OpenCode"
        case .codex: return "Codex"
        case .agy: return "Antigravity"
        case .cursor: return "Cursor"
        case .claude: return "Claude Code"
        case .openclaude: return "OpenClaude"
        case .deepseek: return "DeepSeek"
        case .aider: return "Aider"
        case .zed: return "Zed"
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
    var engineID: String
    var liveID: Bool
    var apiKey: String

    var baseURL: String { "http://127.0.0.1:\(port)/v1" }
    var origin: String { "http://127.0.0.1:\(port)" }
}

struct ClientRoots {
    var home: URL

    static var real: ClientRoots {
        ClientRoots(home: FileManager.default.homeDirectoryForCurrentUser)
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
        case .agy:
            try writeAgy(request, roots: roots)
        case .cursor:
            try writeCursor(request, database: roots.file("Library", "Application Support", "Cursor", "User", "globalStorage", "state.vscdb"))
        case .claude:
            try writeClaude(request, file: roots.file(".claude", "settings.json"))
        case .openclaude:
            try writeOpenClaude(request, file: roots.file(".openclaude", "settings.json"))
        case .deepseek:
            try writeDeepSeek(request, roots: roots)
        case .aider:
            try writeAider(request, file: roots.file(".aider.conf.yml"))
        case .zed:
            try writeZed(request, file: roots.file(".config", "zed", "settings.json"))
        }
        return message(client, request)
    }

    private static func message(_ client: ClientID, _ request: ClientRequest) -> String {
        let name = request.displayName
        let estimate = request.liveID ? "" : " The server was stopped, so the model ID is an estimate."
        switch client {
        case .opencode:
            return "OpenCode now uses \(name) at \(request.baseURL).\(estimate) Restart OpenCode if it is open."
        case .codex:
            let protocolNote = request.engineID == "mlx-lm" ? " Codex uses /v1/responses, which mlx-lm does not support." : ""
            return "Codex now uses \(name) at \(request.baseURL).\(estimate)\(protocolNote) Open a new Codex session."
        case .agy:
            return "Antigravity now uses \(name) at \(request.origin).\(estimate) Open a new terminal to load the gateway."
        case .cursor:
            return "Cursor lists \(name) and points to \(request.baseURL).\(estimate) Close Cursor before configuring. Paste this access key under Models → OpenAI API Key: \(request.apiKey). Then restart Cursor and pick \(name)."
        case .claude:
            let protocolNote = request.engineID == "mlx-lm" ? " Claude Code uses /v1/messages, which mlx-lm does not support." : ""
            return "Claude Code now uses \(name) at \(request.origin).\(estimate)\(protocolNote) Open a new session."
        case .openclaude:
            return "OpenClaude now uses \(name) at \(request.baseURL).\(estimate) Restart OpenClaude."
        case .deepseek:
            return "DeepSeek Harness has a lulu provider at \(request.baseURL).\(estimate) Select lulu if it is not selected automatically."
        case .aider:
            return "Aider now uses \(name) at \(request.baseURL).\(estimate)"
        case .zed:
            return "Zed now uses \(name) at \(request.baseURL).\(estimate) Restart Zed."
        }
    }

    private static func writeCodex(_ request: ClientRequest, file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        if !text.isEmpty, !text.hasSuffix("\n") { text.append("\n") }
        let modelLine = "model = \(tomlString(request.modelID))"
        if text.range(of: #"(?m)^model\s*="#, options: .regularExpression) != nil {
            text = text.replacingOccurrences(of: #"(?m)^model\s*=.*$"#, with: modelLine, options: .regularExpression)
        } else {
            text = modelLine + "\n" + text
        }
        if text.range(of: #"(?m)^model_provider\s*="#, options: .regularExpression) != nil {
            text = text.replacingOccurrences(of: #"(?m)^model_provider\s*=.*$"#, with: "model_provider = \"lulu\"", options: .regularExpression)
        } else if let range = text.range(of: modelLine) {
            text.insert(contentsOf: "\nmodel_provider = \"lulu\"", at: range.upperBound)
        }
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

    private static func writeAgy(_ request: ClientRequest, roots: ClientRoots) throws {
        let settings = roots.file(".gemini", "antigravity-cli", "settings.json")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settings.path) {
            let data = try Data(contentsOf: settings)
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Failure(message: "Could not update Antigravity: settings.json is not valid JSON.")
            }
            root = parsed
        }
        root["model"] = request.modelID
        root.removeValue(forKey: "modelProvider")
        try writeJSON(root, to: settings)

        let zshrc = roots.file(".zshrc")
        let block = """
        # >>> lulu agy >>>
        export AGY_LLM_GATEWAY_URL=\(shellQuote(request.origin))
        export AGY_LLM_GATEWAY_API_KEY=\(shellQuote(request.apiKey))
        export AGY_LLM_GATEWAY_WIRE_PROTOCOL=openai
        export AGY_LLM_GATEWAY_MODELS=\(shellQuote(request.modelID))
        # <<< lulu agy <<<
        """
        try replaceMarkedBlock(in: zshrc, start: "# >>> lulu agy >>>", end: "# <<< lulu agy <<<", block: block)
    }

    private static func writeCursor(_ request: ClientRequest, database: URL) throws {
        guard FileManager.default.fileExists(atPath: database.path) else {
            throw Failure(message: "Cursor has no configuration on this Mac.")
        }
        var db: OpaquePointer?
        guard sqlite3_open_v2(database.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw Failure(message: "Could not open Cursor configuration.")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 3000)
        let key = "src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser"
        let raw = try sqliteText(db, "SELECT value FROM ItemTable WHERE key = ?", key)
        let updated = try rewriteCursor(raw, request)
        try sqliteUpdate(db, "UPDATE ItemTable SET value = ? WHERE key = ?", updated, key)
    }

    private static func rewriteCursor(_ raw: String, _ request: ClientRequest) throws -> String {
        guard let data = raw.data(using: .utf8),
              var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure(message: "Cursor configuration is not valid JSON.")
        }
        let listed = request.displayName
        root["openAIBaseUrl"] = request.baseURL
        root["useOpenAIKey"] = true

        var ai = root["aiSettings"] as? [String: Any] ?? [:]
        var added = ai["userAddedModels"] as? [String] ?? []
        if !added.contains(listed) { added.append(listed) }
        ai["userAddedModels"] = added

        var enabled = ai["modelOverrideEnabled"] as? [String] ?? []
        if !enabled.contains(listed) { enabled.append(listed) }
        ai["modelOverrideEnabled"] = enabled

        if var disabled = ai["modelOverrideDisabled"] as? [String] {
            disabled.removeAll { $0 == listed }
            ai["modelOverrideDisabled"] = disabled
        }

        var modelConfig = ai["modelConfig"] as? [String: Any] ?? [:]
        if var composer = modelConfig["composer"] as? [String: Any] {
            composer["modelName"] = listed
            if var selected = composer["selectedModels"] as? [[String: Any]], !selected.isEmpty {
                selected[0]["modelId"] = listed
                composer["selectedModels"] = selected
            } else {
                composer["selectedModels"] = [["modelId": listed, "parameters": []]]
            }
            modelConfig["composer"] = composer
            ai["modelConfig"] = modelConfig
        } else {
            throw Failure(message: "Could not find the Cursor model to replace.")
        }
        root["aiSettings"] = ai

        let out = try JSONSerialization.data(withJSONObject: root)
        return String(decoding: out, as: UTF8.self)
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

    private static func writeOpenClaude(_ request: ClientRequest, file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Failure(message: "Could not update OpenClaude: settings.json is not valid JSON.")
            }
            root = parsed
        }
        var env = root["env"] as? [String: Any] ?? [:]
        env["CLAUDE_CODE_USE_OPENAI"] = "1"
        env["OPENAI_BASE_URL"] = request.baseURL
        env["OPENAI_API_KEY"] = request.apiKey
        env["OPENAI_MODEL"] = request.modelID
        root["env"] = env
        root["model"] = request.modelID
        var limits = root["modelLimits"] as? [String: Any] ?? [:]
        let output = max(1024, min(8192, request.context / 2))
        limits[request.modelID] = ["contextWindow": request.context, "maxOutputTokens": output]
        root["modelLimits"] = limits
        try writeJSON(root, to: file)
    }

    private static func writeDeepSeek(_ request: ClientRequest, roots: ClientRoots) throws {
        let patch = roots.file(".dsh", "cordis.patch.yml")
        let input = request.vision ? "[text, image]" : "[text]"
        let block = """
        # >>> lulu >>>
        - id: llm-pi-ai
          config:
            providers:
              lulu:
                displayName: Lulu
                apiKeyEnv: LULU_API_KEY
                api: openai-completions
                baseURL: \(yamlString(request.baseURL))
                compat:
                  supportsDeveloperRole: false
                  maxTokensField: max_tokens
                models:
                  - id: \(yamlString(request.modelID))
                    name: \(yamlString(request.displayName))
                    contextWindow: \(request.context)
                    input: \(input)
        # <<< lulu <<<
        """
        try replaceMarkedBlock(in: patch, start: "# >>> lulu >>>", end: "# <<< lulu <<<", block: block)
        let env = roots.file(".dsh", ".env")
        var envText = (try? String(contentsOf: env, encoding: .utf8)) ?? ""
        let line = "LULU_API_KEY=\(request.apiKey)"
        if envText.range(of: #"(?m)^LULU_API_KEY=.*$"#, options: .regularExpression) != nil {
            envText = envText.replacingOccurrences(of: #"(?m)^LULU_API_KEY=.*$"#, with: line, options: .regularExpression)
        } else {
            if !envText.isEmpty, !envText.hasSuffix("\n") { envText.append("\n") }
            envText += line + "\n"
        }
        try Data(envText.utf8).write(to: env, options: .atomic)
    }

    private static func writeAider(_ request: ClientRequest, file: URL) throws {
        var lines = ((try? String(contentsOf: file, encoding: .utf8)) ?? "").components(separatedBy: "\n")
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
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Failure(message: "Could not update Zed: settings.json is not valid JSON.")
            }
            root = parsed
        }
        var languages = root["language_models"] as? [String: Any] ?? [:]
        var openai = languages["openai"] as? [String: Any] ?? [:]
        openai["api_url"] = request.baseURL
        openai["api_key"] = request.apiKey
        var models = openai["available_models"] as? [[String: Any]] ?? []
        models.removeAll { ($0["name"] as? String) == request.modelID || ($0["name"] as? String) == "lulu" }
        models.insert([
            "name": request.modelID,
            "display_name": request.displayName,
            "max_tokens": request.context,
        ], at: 0)
        openai["available_models"] = models
        languages["openai"] = openai
        root["language_models"] = languages
        try writeJSON(root, to: file)
    }

    private static func writeJSON(_ object: [String: Any], to file: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        var text = String(decoding: data, as: UTF8.self)
        if !text.hasSuffix("\n") { text.append("\n") }
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    private static func replaceMarkedBlock(in file: URL, start: String, end: String, block: String) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        if let startRange = text.range(of: start), let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) {
            text.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: block)
        } else {
            if !text.isEmpty, !text.hasSuffix("\n") { text.append("\n") }
            if !text.isEmpty { text.append("\n") }
            text += block
        }
        if !text.hasSuffix("\n") { text.append("\n") }
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    private static func sqliteText(_ db: OpaquePointer?, _ sql: String, _ key: String) throws -> String {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Failure(message: "Could not read Cursor configuration.")
        }
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, key)
        guard sqlite3_step(statement) == SQLITE_ROW, let raw = sqlite3_column_text(statement, 0) else {
            throw Failure(message: "Cursor configuration has no model entry.")
        }
        return String(cString: raw)
    }

    private static func sqliteUpdate(_ db: OpaquePointer?, _ sql: String, _ value: String, _ key: String) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Failure(message: "Could not save Cursor configuration.")
        }
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, value)
        bind(statement, 2, key)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw Failure(message: "Cursor is holding its configuration. Close Cursor and try again.")
        }
    }

    private static func bind(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
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
