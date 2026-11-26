import Foundation

struct EngineSpeed {
    var prompt: Double?
    var predict: Double?
    var peak: Int?
}

enum Probe {
    static func chatInputs(for model: ModelItem, port: Int) async -> ChatInputCapabilities {
        if model.engineID == "llama.cpp", model.mmproj != nil,
           let (code, data) = await get(port, "/props"), code == 200,
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let modalities = object["modalities"] as? [String: Bool] {
            return ChatInputCapabilities(image: modalities["vision"] == true, audio: modalities["audio"] == true)
        }
        guard model.engineID == "mlx-vlm",
              let data = try? Data(contentsOf: URL(fileURLWithPath: model.path).appendingPathComponent("config.json")),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ChatInputCapabilities()
        }
        let vision = (config["vision_config"] as? [String: Any])?.isEmpty == false
            || config["image_token_id"] is Int || config["image_token_index"] is Int
        let audio = (config["audio_config"] as? [String: Any])?.isEmpty == false
            || (config["audio_encoder_config"] as? [String: Any])?.isEmpty == false
            || config["audio_token_id"] is Int || config["audio_token_index"] is Int
        return ChatInputCapabilities(image: vision, audio: audio)
    }

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.4
        config.timeoutIntervalForResource = 0.6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func classify(port: Int) async -> ServerPhase? {
        if let (code, data) = await get(port, "/health") {
            if let phase = healthPhase(code: code, data: data) { return phase }
        }
        if let (code, _) = await get(port, "/v1/models"), code == 200 {
            return .ready
        }
        return nil
    }

    private static func healthPhase(code: Int, data: Data) -> ServerPhase? {
        if code == 503 { return .starting }
        guard code == 200 else { return nil }
        let health = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        // mlx-vlm reports a healthy HTTP server before its startup model is ready.
        if let ready = health?["model_ready"] as? Bool { return ready ? .ready : .starting }
        switch (health?["status"] as? String)?.lowercased() {
        case "ok", "healthy", nil: return .ready
        default: return .starting
        }
    }

    static func servedModelID(port: Int, path: String) async -> String? {
        guard let (code, data) = await get(port, "/v1/models"), code == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = object["data"] as? [[String: Any]] else { return nil }
        let ids = rows.compactMap { $0["id"] as? String }
        let file = URL(fileURLWithPath: path)
        let resolved = file.resolvingSymlinksInPath().path
        let filename = file.lastPathComponent
        let stem = file.deletingPathExtension().lastPathComponent
        if let exact = ids.first(where: { $0 == resolved || $0 == path || $0 == filename || $0 == stem }) {
            return exact
        }
        return ids.first { id in
            let url = URL(fileURLWithPath: id)
            return url.lastPathComponent == filename || url.deletingPathExtension().lastPathComponent == stem
        } ?? (ids.count == 1 ? ids.first : nil)
    }

    static func supports(port: Int, path: String, key: String) async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        if path == "/v1/messages" {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        // A body without a model or message validates the route without starting generation.
        request.httpBody = Data("{}".utf8)
        guard let (_, response) = try? await session.data(for: request),
              let response = response as? HTTPURLResponse else { return false }
        return response.statusCode == 400 || response.statusCode == 422 || (200..<300).contains(response.statusCode)
    }

    static func speed(port: Int, engineID: String?) async -> EngineSpeed? {
        guard engineID == "llama.cpp" || engineID == "mlx-vlm",
              let (code, data) = await get(port, "/metrics"), code == 200 else { return nil }
        if engineID == "mlx-vlm" {
            guard let report = try? JSONDecoder().decode(MLXVLMReport.self, from: data) else { return nil }
            let average = report.summary.avg_decode_tok_s.flatMap { $0 > 0 ? $0 : nil }
            return EngineSpeed(prompt: report.latest?.prefill_tok_s, predict: average)
        }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var speed = EngineSpeed()
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let parts = line.split(separator: " ")
            guard parts.count >= 2, let value = Double(parts[1]), value.isFinite else { continue }
            switch parts[0] {
            case "llamacpp:prompt_tokens_seconds":
                speed.prompt = value
            case "llamacpp:predicted_tokens_seconds":
                speed.predict = value
            case "llamacpp:n_tokens_max":
                speed.peak = Int(exactly: value)
            default:
                break
            }
        }
        return speed
    }

    private struct MLXVLMReport: Decodable {
        struct Summary: Decodable { let avg_decode_tok_s: Double? }
        struct Latest: Decodable { let prefill_tok_s: Double? }
        let summary: Summary
        let latest: Latest?
    }

    private static func get(_ port: Int, _ path: String) async -> (Int, Data)? {
        guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { return nil }
        var request = URLRequest(url: url)
        let key = AccessKeyStore.load().trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        return (http.statusCode, data)
    }
}
