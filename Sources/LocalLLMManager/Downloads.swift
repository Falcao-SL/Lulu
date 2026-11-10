import Foundation
import Security

enum TokenStore {
    private static let service = "com.falcaosl.lulu"
    private static let account = "huggingface"

    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    static func save(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var insert = query
        insert[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(insert as CFDictionary, nil)
    }

    /// Token da UI, ou o que já estiver no ambiente. Não ecoa o valor do ambiente.
    static func effective() -> String? {
        let stored = load().trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }
        let env = ProcessInfo.processInfo.environment
        let fallback = env["HF_TOKEN"] ?? env["HUGGING_FACE_HUB_TOKEN"] ?? ""
        return fallback.isEmpty ? nil : fallback
    }
}

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
    var laboratory: String { baseModel.split(separator: "/").first.map(String.init) ?? "Não informado" }
    var quantization: String { ModelMetadata.quantization(in: id + " " + tags.joined(separator: " ")) ?? "Não informada" }
    var format: String {
        let value = (id + " " + library + " " + tags.joined(separator: " ")).lowercased()
        if value.contains("gguf") { return "GGUF" }
        if value.contains("mlx") { return "MLX" }
        return library.isEmpty ? "Formato não informado" : library
    }
}

struct ListedFile: Identifiable, Equatable {
    var path: String
    var size: Int64
    var selected: Bool
    var id: String { path }
}

enum DownloadState: String, Codable {
    case queued, running, paused, failed, done
}

struct DownloadPart: Codable, Equatable, Identifiable {
    var path: String
    var size: Int64
    var received: Int64
    var done: Bool
    var id: String { path }
}

struct DownloadJob: Codable, Equatable, Identifiable {
    var id: UUID
    var repo: String
    var destination: String
    var files: [DownloadPart]
    var state: DownloadState
    var error: String?

    var received: Int64 { files.reduce(0) { $0 + ($1.done ? $1.size : $1.received) } }
    var total: Int64 { files.reduce(0) { $0 + max($1.size, $1.received) } }
}

enum DownloadStore {
    static var url: URL { LuluPaths.root.appendingPathComponent("downloads.json") }

    static func load() -> [DownloadJob] {
        guard let data = try? Data(contentsOf: url),
              var jobs = try? JSONDecoder().decode([DownloadJob].self, from: data) else { return [] }
        for index in jobs.indices where jobs[index].state == .running {
            jobs[index].state = .paused
        }
        return jobs
    }

    static func save(_ jobs: [DownloadJob]) {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

enum Hub {
    static func parseRepo(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if let url = URL(string: text), let host = url.host, host.contains("huggingface.co") {
            let skipped: Set<String> = ["tree", "blob", "resolve", "main"]
            var parts: [String] = []
            for piece in url.path.split(separator: "/") {
                let name = String(piece)
                if !skipped.contains(name) { parts.append(name) }
            }
            guard parts.count >= 2 else { return nil }
            text = parts[0] + "/" + parts[1]
        }
        let pieces = text.split(separator: "/").map(String.init)
        guard pieces.count == 2 else { return nil }
        let repo = pieces[0] + "/" + pieces[1]
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
        let data = try await get(url, token: token)
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let error = object["error"] as? String {
            throw HubError(message: error)
        }
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        let files = rows.compactMap { row -> ListedFile? in
            guard (row["type"] as? String) == "file", let path = row["path"] as? String, safe(path) else { return nil }
            return ListedFile(path: path, size: int64(row["size"]), selected: false)
        }.sorted { $0.path < $1.path }
        return markDefaults(files)
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

    private static func markDefaults(_ files: [ListedFile]) -> [ListedFile] {
        var copy = files
        let gguf = copy.filter { $0.path.lowercased().hasSuffix(".gguf") && !$0.path.lowercased().contains("mmproj") }
        if !gguf.isEmpty {
            let preferred = gguf.first { rank($0.path) > 0 } ?? gguf.min { $0.size < $1.size }
            if let preferred, let index = copy.firstIndex(where: { $0.path == preferred.path }) {
                copy[index].selected = true
            }
            if copy.contains(where: { $0.selected }) {
                for index in copy.indices where copy[index].path.lowercased().contains("mmproj") && copy[index].path.lowercased().hasSuffix(".gguf") {
                    copy[index].selected = true
                }
            }
            return copy
        }
        for index in copy.indices {
            copy[index].selected = keepMLX(copy[index].path)
        }
        return copy
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
        return name.hasSuffix(".safetensors") || name.hasSuffix(".json") || name.hasSuffix(".txt") || name.hasSuffix(".model") || name.hasSuffix(".tiktoken") || name.contains("tokenizer")
    }

    private static func get(_ url: URL, token: String?) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Lulu", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 {
            throw HubError(message: "O Hugging Face recusou o acesso. Modelos fechados pedem um token.")
        }
        if status >= 400 {
            throw HubError(message: "O Hugging Face respondeu HTTP \(status).")
        }
        return data
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

enum TransferEvent {
    case progress(UUID, String, Int64, Int64)
    case finished(UUID, String)
    case failed(UUID, String)
    case paused(UUID)
}

/// Um arquivo por vez, gravado em disco, retomado com HTTP Range.
final class HFTransfers: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    var onEvent: ((TransferEvent) -> Void)?

    private var session: URLSession!
    private var task: URLSessionDataTask?
    private var handle: FileHandle?
    private var jobID: UUID?
    private var relativePath = ""
    private var incomplete: URL?
    private var finalURL: URL?
    private var received: Int64 = 0
    private var expected: Int64 = 0
    private var lastEmit = 0.0
    private var stopIsPause = false
    private var closed = false
    private var generation = 0

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 60 * 60 * 24
        config.httpMaximumConnectionsPerHost = 2
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }

    var busy: Bool { task != nil }

    func start(job: UUID, repo: String, path: String, destination: URL, token: String?) throws {
        guard task == nil else { return }
        guard let remote = Hub.resolveURL(repo: repo, path: path) else { throw URLError(.badURL) }
        let folder = destination.appendingPathComponent(path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let final = destination.appendingPathComponent(path)
        let partial = final.appendingPathExtension("incomplete")
        if !FileManager.default.fileExists(atPath: partial.path) {
            FileManager.default.createFile(atPath: partial.path, contents: nil)
        }
        let file = try FileHandle(forWritingTo: partial)
        let existing = Int64(try file.seekToEnd())
        var request = URLRequest(url: remote)
        request.setValue("Lulu", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if existing > 0 {
            request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range")
        }
        generation += 1
        jobID = job
        relativePath = path
        incomplete = partial
        finalURL = final
        handle = file
        received = existing
        expected = existing
        closed = false
        stopIsPause = false
        let started = session.dataTask(with: request)
        started.taskDescription = String(generation)
        task = started
        started.resume()
    }

    private func owns(_ dataTask: URLSessionTask) -> Bool {
        dataTask.taskDescription == String(generation)
    }

    func pause() {
        stopIsPause = true
        task?.cancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard owns(dataTask), let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            fail("O Hugging Face recusou o arquivo. Se o modelo é fechado, guarde a chave.")
            completionHandler(.cancel)
            return
        }
        if http.statusCode == 404 {
            fail("Arquivo não encontrado no repositório.")
            completionHandler(.cancel)
            return
        }
        if http.statusCode != 200 && http.statusCode != 206 {
            fail("HTTP \(http.statusCode) ao baixar \(relativePath).")
            completionHandler(.cancel)
            return
        }
        if http.statusCode == 200, received > 0 {
            try? handle?.truncate(atOffset: 0)
            received = 0
        }
        let length = http.expectedContentLength
        if length > 0 {
            expected = received + length
        }
        if let range = http.value(forHTTPHeaderField: "Content-Range"),
           let total = range.split(separator: "/").last,
           let value = Int64(total), value > 0 {
            expected = value
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard owns(dataTask), !closed else { return }
        handle?.write(data)
        received += Int64(data.count)
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastEmit > 0.25, let jobID else { return }
        lastEmit = now
        emit(.progress(jobID, relativePath, received, expected))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard owns(task) else { return }
        let job = jobID
        let path = relativePath
        let bytes = received
        let total = expected
        closeHandle()
        self.task = nil
        guard let job, !closed else { return }
        closed = true
        if let error = error as NSError? {
            if error.code == NSURLErrorCancelled && stopIsPause {
                emit(.paused(job))
            } else if error.code != NSURLErrorCancelled {
                emit(.failed(job, error.localizedDescription))
            }
            return
        }
        guard bytes > 0, total == 0 || bytes >= total else {
            emit(.failed(job, "O arquivo \(path) chegou incompleto."))
            return
        }
        guard let incomplete, let finalURL else { return }
        do {
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: incomplete, to: finalURL)
            emit(.finished(job, path))
        } catch {
            emit(.failed(job, error.localizedDescription))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        var next = request
        if let host = request.url?.host, host != "huggingface.co", !host.hasSuffix(".huggingface.co") {
            next.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        completionHandler(next)
    }

    private func fail(_ message: String) {
        guard let jobID, !closed else { return }
        closed = true
        closeHandle()
        let current = task
        task = nil
        emit(.failed(jobID, message))
        current?.cancel()
    }

    private func closeHandle() {
        try? handle?.close()
        handle = nil
    }

    private func emit(_ event: TransferEvent) {
        let callback = onEvent
        DispatchQueue.main.async {
            callback?(event)
        }
    }
}
