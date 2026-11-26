import Foundation

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
            fail("Hugging Face denied access to the file. Save a token for gated models.")
            completionHandler(.cancel)
            return
        }
        if http.statusCode == 404 {
            fail("File not found in the repository.")
            completionHandler(.cancel)
            return
        }
        if http.statusCode != 200 && http.statusCode != 206 {
            fail("HTTP \(http.statusCode) while downloading \(relativePath).")
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
            emit(.failed(job, "File \(path) was downloaded incompletely."))
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
