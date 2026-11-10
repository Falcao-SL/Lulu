import Foundation

/// Writes the global OpenCode config so the running Lulu server is the default model.
enum OpenCodeClient {
    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    static func write(baseURL: String, displayName: String, modelID: String, context: Int, vision: Bool, directory: URL? = nil) throws {
        let directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jsonc = directory.appendingPathComponent("opencode.jsonc")
        let json = directory.appendingPathComponent("opencode.json")
        let target = FileManager.default.fileExists(atPath: jsonc.path) ? jsonc : json

        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: target.path) {
            let data = try Data(contentsOf: target)
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Failure(message: "Não reescrevi \(target.lastPathComponent): o arquivo não é JSON puro. Sem comentários, o Lulu consegue configurar o OpenCode.")
            }
            root = parsed
        }
        guard root["providers"] == nil || root["providers"] is [String: Any] else {
            throw Failure(message: "Não reescrevi o OpenCode: a chave providers não é um objeto.")
        }
        if root["$schema"] == nil {
            root["$schema"] = "https://opencode.ai/config.json"
        }

        var providers = root["providers"] as? [String: Any] ?? [:]
        let output = max(1024, min(8192, max(context, 1) / 2))
        var input = ["text"]
        if vision { input.append("image") }
        let model: [String: Any] = [
            "name": displayName,
            "modelID": modelID,
            "capabilities": [
                "tools": true,
                "input": input,
                "output": ["text"],
            ],
            "limit": [
                "context": context,
                "output": output,
            ],
        ]
        providers["lulu"] = [
            "name": "Lulu",
            "package": "@opencode/ai/providers/openai-compatible",
            "settings": ["baseURL": baseURL],
            "models": ["local": model],
        ] as [String: Any]
        root["providers"] = providers
        root["model"] = "lulu/local"

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        var text = String(decoding: data, as: UTF8.self)
        if !text.hasSuffix("\n") { text.append("\n") }
        try Data(text.utf8).write(to: target, options: .atomic)
    }

    static func fallbackID(engineID: String, path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if engineID == "llama.cpp" { return url.lastPathComponent }
        return url.resolvingSymlinksInPath().path
    }
}
