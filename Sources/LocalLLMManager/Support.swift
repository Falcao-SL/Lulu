import Foundation

enum LuluPaths {
    static let root: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".lulu", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var log: URL { root.appendingPathComponent("engine.log") }
    static var session: URL { root.appendingPathComponent("session.json") }
    static var models: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("models", isDirectory: true) }
}

enum Format {
    private static let bytesFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.includesUnit = true
        return formatter
    }()

    private static let tokensFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func bytes(_ value: UInt64) -> String {
        bytesFormatter.string(fromByteCount: Int64(clamping: value)) ?? "0 MB"
    }

    static func tokens(_ value: Int) -> String {
        tokensFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func rate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    static func tail(_ url: URL, maxBytes: Int = 8192, lines: Int = 18) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let size = handle.seekToEndOfFile()
        let window = UInt64(maxBytes)
        handle.seek(toFileOffset: size > window ? size - window : 0)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: false).suffix(lines).joined(separator: "\n")
    }
}

enum Machine {
    static let performanceCores: Int = {
        var count: Int32 = 0
        var length = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.physicalcpu", &count, &length, nil, 0) == 0, count > 0 {
            return Int(count)
        }
        return max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
    }()

    static func executable(_ candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

struct Session: Codable {
    var pid: Int32
    var port: Int
    var modelPath: String
    var engineID: String
    var context: Int
}

enum Shell {
    /// Roda fora da thread principal. `onChunk` pode chegar em qualquer fila.
    static func run(executable: String, arguments: [String], extraEnv: [String: String] = [:], onChunk: @escaping (String) -> Void) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = path
        for (key, value) in extraEnv {
            environment[key] = value
        }
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            onChunk(error.localizedDescription + "\n")
            return 1
        }
        let semaphore = DispatchSemaphore(value: 0)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onChunk(text)
        }
        process.terminationHandler = { _ in
            semaphore.signal()
        }
        semaphore.wait()
        pipe.fileHandleForReading.readabilityHandler = nil
        let rest = pipe.fileHandleForReading.readDataToEndOfFile()
        if !rest.isEmpty, let text = String(data: rest, encoding: .utf8) {
            onChunk(text)
        }
        return process.terminationStatus
    }
}
