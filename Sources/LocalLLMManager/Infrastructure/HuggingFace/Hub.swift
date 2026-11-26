import Foundation

struct HubHit: Identifiable, Equatable {
    var id: String
    var downloads: Int
    var likes: Int
    var author: String = ""
    var library: String = ""
    var task: String = ""
    var tags: [String] = []
    var baseModel: String = ""
    var license: String = ""
    var modified: String = ""
    var parameters: Int64 = 0

    var publisher: String { author.isEmpty ? String(id.split(separator: "/").first ?? "") : author }
    var laboratory: String { baseModel.split(separator: "/").first.map(String.init) ?? "Not provided" }
    var quantization: String { ModelMetadata.quantization(in: id + " " + tags.joined(separator: " ")) ?? "Not provided" }
    var format: String {
        let value = (id + " " + library + " " + tags.joined(separator: " ")).lowercased()
        if value.contains("gguf") { return "GGUF" }
        if value.contains("mlx") { return "MLX" }
        return library.isEmpty ? "Format not provided" : library
    }
}

struct ListedFile: Identifiable, Equatable {
    var path: String
    var size: Int64
    var selected: Bool
    var id: String { path }
}

enum Hub {
    static func parseRepo(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if let url = URL(string: text), let host = url.host?.lowercased() {
            guard ["huggingface.co", "www.huggingface.co"].contains(host),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
            let parts = url.path.split(separator: "/")
            guard parts.count >= 2, !["datasets", "spaces"].contains(String(parts[0])) else { return nil }
            text = parts[0] + "/" + parts[1]
        }
        let pieces = text.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, pieces.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        let repo = pieces.joined(separator: "/")
        guard repo.range(of: #"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else { return nil }
        return repo
    }

    static func search(_ query: String, author: String = "", format: String = "", sort: String = "downloads", token: String?) async throws -> [HubHit] {
        var components = URLComponents(string: "https://huggingface.co/api/models")!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "full", value: "true"),
            URLQueryItem(name: "config", value: "true"),
            URLQueryItem(name: "cardData", value: "true"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "sort", value: sort),
        ]
        if !author.isEmpty { components.queryItems?.append(URLQueryItem(name: "author", value: author)) }
        if !format.isEmpty { components.queryItems?.append(URLQueryItem(name: "filter", value: format)) }
        let data = try await get(components.url!, token: token)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap(decodeHit)
    }

    static func metadata(repo: String, token: String?) async throws -> HubHit? {
        guard let url = URL(string: "https://huggingface.co/api/models/\(repo)") else { return nil }
        let data = try await get(url, token: token)
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return decodeHit(row)
    }

    private static func decodeHit(_ row: [String: Any]) -> HubHit? {
            guard let id = row["id"] as? String else { return nil }
            let card = row["cardData"] as? [String: Any] ?? [:]
            let base = (card["base_model"] as? String) ?? (card["base_model"] as? [String])?.first ?? ""
            let tensors = row["safetensors"] as? [String: Any] ?? [:]
            return HubHit(id: id, downloads: int(row["downloads"]), likes: int(row["likes"]),
                          author: row["author"] as? String ?? "", library: row["library_name"] as? String ?? "",
                          task: row["pipeline_tag"] as? String ?? "", tags: row["tags"] as? [String] ?? [],
                          baseModel: base, license: card["license"] as? String ?? "",
                          modified: row["lastModified"] as? String ?? "", parameters: int64(tensors["total"]))
    }

    static func files(repo: String, token: String?) async throws -> [ListedFile] {
        let encoded = repo.split(separator: "/").map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        guard let url = URL(string: "https://huggingface.co/api/models/\(encoded)/tree/main?recursive=1") else {
            throw URLError(.badURL)
        }
        var next: URL? = url
        var visited = Set<URL>()
        var filesByPath: [String: ListedFile] = [:]
        while let page = next, visited.insert(page).inserted {
            let (data, response) = try await fetch(page, token: token)
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = object["error"] as? String {
                throw HubError(message: error)
            }
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw HubError(message: "Hugging Face returned an invalid file list.")
            }
            for row in rows {
                guard row["type"] as? String == "file", let path = row["path"] as? String, safe(path) else { continue }
                filesByPath[path] = ListedFile(path: path, size: int64(row["size"]), selected: false)
            }
            next = nextFilePage(response, relativeTo: page, path: url.path)
        }
        return markDefaults(filesByPath.values.sorted { $0.path < $1.path })
    }

    private static func nextFilePage(_ response: HTTPURLResponse, relativeTo url: URL, path: String) -> URL? {
        guard let header = response.value(forHTTPHeaderField: "Link") else { return nil }
        let relation = #/<([^>]+)>\s*;\s*rel="next"/#
        guard let target = header.firstMatch(of: relation)?.1,
              let next = URL(string: String(target), relativeTo: url)?.absoluteURL,
              next.scheme == "https", next.host == "huggingface.co", next.path == path else { return nil }
        return next
    }

    static func destination(repo: String, files: [ListedFile]) -> URL {
        let folder = repo.split(separator: "/").last.map(String.init) ?? repo
        let safeName = folder.replacingOccurrences(of: "..", with: "")
        let kind = files.contains { $0.path.lowercased().hasSuffix(".gguf") } ? "gguf" : "mlx"
        return LuluPaths.models.appendingPathComponent(kind, isDirectory: true).appendingPathComponent(safeName, isDirectory: true)
    }

    static func resolveURL(repo: String, path: String) -> URL? {
        let repoPart = repo.split(separator: "/").map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        let filePart = path.split(separator: "/").map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        return URL(string: "https://huggingface.co/\(repoPart)/resolve/main/\(filePart)")
    }

    static func safe(_ path: String) -> Bool {
        !path.hasPrefix("/") && !path.split(separator: "/").contains("..")
    }

    static func variants(_ files: [ListedFile]) -> [String] {
        files.filter {
            $0.path.lowercased().hasSuffix(".gguf")
                && !isAuxiliaryGGUF($0.path)
                && (shard($0.path)?.index ?? 1) == 1
        }.map(\.path)
    }

    static func isProjector(_ path: String) -> Bool {
        URL(fileURLWithPath: path).lastPathComponent.lowercased().contains("mmproj")
    }

    static func isAuxiliaryGGUF(_ path: String) -> Bool {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return isProjector(path) || ["mtp-", "dflash-", "eagle3-", "draft-"].contains { name.hasPrefix($0) }
    }

    static func shard(_ path: String) -> (prefix: String, index: Int, count: Int)? {
        let suffix = #/-([0-9]{5})-of-([0-9]{5})\.gguf$/#
        guard let match = path.firstMatch(of: suffix),
              let index = Int(match.1), let count = Int(match.2), index > 0, index <= count else {
            return nil
        }
        return (String(path[..<match.range.lowerBound]), index, count)
    }

    static func choosing(_ variant: String, in files: [ListedFile]) -> [ListedFile] {
        let split = shard(variant)
        let directory = (variant as NSString).deletingLastPathComponent
        let projectors = files.filter {
            isProjector($0.path) && $0.path.lowercased().hasSuffix(".gguf")
                && ($0.path as NSString).deletingLastPathComponent == directory
        }
        return files.map { file in
            var file = file
            let part = shard(file.path)
            file.selected = file.path == variant
                || (split != nil && part?.prefix == split?.prefix && part?.count == split?.count)
                || (projectors.count == 1 && file.path == projectors.first?.path)
            return file
        }
    }

    static func isDownloadable(_ files: [ListedFile]) -> Bool {
        let chosen = files.filter(\.selected)
        let gguf = variants(chosen)
        if !gguf.isEmpty {
            return gguf.allSatisfy { path in
                guard let split = shard(path) else { return true }
                let indices = chosen.compactMap { file -> Int? in
                    guard let part = shard(file.path), part.prefix == split.prefix,
                          part.count == split.count else { return nil }
                    return part.index
                }
                return Set(indices).count == split.count
            }
        }
        guard !chosen.contains(where: { $0.path.lowercased().hasSuffix(".gguf") }) else { return false }
        if let template = files.first(where: { $0.path == "chat_template.jinja" }), !template.selected {
            return false
        }
        return chosen.contains(where: { $0.path == "config.json" })
            && chosen.contains(where: { $0.path.lowercased().hasSuffix(".safetensors") })
    }

    private static func markDefaults(_ files: [ListedFile]) -> [ListedFile] {
        let options = Set(variants(files))
        let gguf = files.filter { options.contains($0.path) }
        if let preferred = gguf.sorted(by: {
            let first = rank($0.path), second = rank($1.path)
            return first == second ? $0.size < $1.size : first > second
        }).first {
            return choosing(preferred.path, in: files)
        }
        return files.map { file in
            var file = file
            file.selected = keepMLX(file.path)
            return file
        }
    }

    private static func rank(_ path: String) -> Int {
        let name = path.lowercased()
        if name.contains("q4_k_m") { return 5 }
        if name.contains("q4_k_s") { return 4 }
        if name.contains("q5_k_m") { return 3 }
        if name.contains("q4_0") { return 2 }
        if name.contains("q8_0") { return 1 }
        return 0
    }

    private static func keepMLX(_ path: String) -> Bool {
        let name = path.lowercased()
        if name.hasSuffix(".md") || name.hasSuffix(".gitattributes") || name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".webp") {
            return false
        }
        return name.hasSuffix(".safetensors") || name.hasSuffix(".json") || name.hasSuffix(".txt") || name.hasSuffix(".model") || name.hasSuffix(".tiktoken") || name.hasSuffix(".jinja") || name.contains("tokenizer")
    }

    private static func get(_ url: URL, token: String?) async throws -> Data {
        let (data, _) = try await fetch(url, token: token)
        return data
    }

    private static func fetch(_ url: URL, token: String?) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Lulu", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let status = http.statusCode
        if status == 401 || status == 403 {
            throw HubError(message: "Hugging Face denied access. Gated models require a token.")
        }
        if status >= 400 {
            throw HubError(message: "Hugging Face returned HTTP \(status).")
        }
        return (data, http)
    }

    private static func int(_ value: Any?) -> Int {
        switch value {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let number as NSNumber: return number.intValue
        default: return 0
        }
    }

    private static func int64(_ value: Any?) -> Int64 {
        switch value {
        case let number as Int: return Int64(number)
        case let number as Double: return Int64(number)
        case let number as NSNumber: return number.int64Value
        default: return 0
        }
    }
}

struct HubError: Error {
    var message: String
}
