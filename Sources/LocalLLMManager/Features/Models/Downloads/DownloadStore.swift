import Foundation

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
