import Darwin
import Foundation
import SQLite3

struct ChatSummary: Codable {
    let id: String
    let title: String
    let model: String
    let revision: Int
}

struct SavedChat: Codable {
    struct Message: Codable {
        let role: ChatMessage.Role
        let content: String
        let attachments: [ChatAttachment]?
    }

    let id: String
    let title: String
    let model: String
    let revision: Int
    let messages: [Message]
}

actor ChatHistory {
    enum Failure: LocalizedError {
        case invalid, missing, conflict, database

        var errorDescription: String? {
            switch self {
            case .invalid: return "Invalid conversation."
            case .missing: return "This conversation no longer exists."
            case .conflict: return "This conversation changed in another tab. Export your copy before reloading."
            case .database: return "Lulu could not access the local chat history."
            }
        }
    }

    private let file: URL
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(file: URL) { self.file = file }

    func list() throws -> [ChatSummary] {
        try withDatabase { db in
            try query(db, "SELECT id, title, model, revision FROM chats ORDER BY updated_at DESC, id") { statement in
                var results: [ChatSummary] = []
                while try next(statement) { results.append(summary(statement)) }
                return results
            }
        }
    }

    func load(id: String) throws -> SavedChat {
        guard UUID(uuidString: id) != nil else { throw Failure.invalid }
        return try withDatabase { db in
            try query(db, "SELECT id, title, model, revision, messages FROM chats WHERE id = ?") { statement in
                try bind(id, to: 1, in: statement)
                guard try next(statement) else { throw Failure.missing }
                let info = summary(statement)
                let count = Int(sqlite3_column_bytes(statement, 4))
                guard let bytes = sqlite3_column_blob(statement, 4) else { throw Failure.database }
                let data = Data(bytes: bytes, count: count)
                let messages = try JSONDecoder().decode([SavedChat.Message].self, from: data)
                return SavedChat(id: info.id, title: info.title, model: info.model, revision: info.revision, messages: messages)
            }
        }
    }

    func save(_ chat: SavedChat) throws -> ChatSummary {
        guard UUID(uuidString: chat.id) != nil, (0..<Int.max).contains(chat.revision),
              !chat.messages.isEmpty, chat.messages.count <= 200 else { throw Failure.invalid }
        let title = String(chat.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !title.isEmpty else { throw Failure.invalid }
        let model = String(chat.model.prefix(160))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = try encoder.encode(chat.messages)
        let revision = chat.revision + 1
        return try withDatabase { db in
            let sql = chat.revision == 0
                ? "INSERT INTO chats (title, model, messages, revision, updated_at, id) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO NOTHING"
                : "UPDATE chats SET title = ?, model = ?, messages = ?, revision = ?, updated_at = ? WHERE id = ? AND revision = ?"
            try query(db, sql) { statement in
                try bind(title, to: 1, in: statement)
                try bind(model, to: 2, in: statement)
                let result = data.withUnsafeBytes {
                    sqlite3_bind_blob(statement, 3, $0.baseAddress, Int32($0.count), Self.transient)
                }
                try requireOK(result)
                try requireOK(sqlite3_bind_int64(statement, 4, Int64(revision)))
                try requireOK(sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970))
                try bind(chat.id, to: 6, in: statement)
                if chat.revision > 0 { try requireOK(sqlite3_bind_int64(statement, 7, Int64(chat.revision))) }
                _ = try next(statement)
                guard sqlite3_changes(db) == 1 else { throw Failure.conflict }
            }
            return ChatSummary(id: chat.id, title: title, model: model, revision: revision)
        }
    }

    func delete(id: String, revision: Int) throws {
        guard UUID(uuidString: id) != nil, revision > 0 else { throw Failure.invalid }
        try withDatabase { db in
            try query(db, "DELETE FROM chats WHERE id = ? AND revision = ?") { statement in
                try bind(id, to: 1, in: statement)
                try requireOK(sqlite3_bind_int64(statement, 2, Int64(revision)))
                _ = try next(statement)
                guard sqlite3_changes(db) == 1 else { throw Failure.conflict }
            }
        }
    }

    private func withDatabase<T>(_ action: (OpaquePointer) throws -> T) throws -> T {
        let descriptor = open(file.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
        if descriptor >= 0 { close(descriptor) }
        else if errno != EEXIST { throw Failure.database }
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(file.path, &handle, SQLITE_OPEN_READWRITE, nil)
        defer { sqlite3_close(handle) }
        guard result == SQLITE_OK, let handle else { throw Failure.database }
        try requireOK(sqlite3_busy_timeout(handle, 2_000))
        try requireOK(sqlite3_exec(handle, """
            CREATE TABLE IF NOT EXISTS chats (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL,
                model TEXT NOT NULL,
                messages BLOB NOT NULL,
                revision INTEGER NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS chats_recent ON chats(updated_at DESC, id);
            """, nil, nil, nil))
        return try action(handle)
    }

    private func query<T>(_ db: OpaquePointer, _ sql: String, _ action: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        try requireOK(sqlite3_prepare_v2(db, sql, -1, &statement, nil))
        defer { sqlite3_finalize(statement) }
        guard let statement else { throw Failure.database }
        return try action(statement)
    }

    private func summary(_ statement: OpaquePointer) -> ChatSummary {
        ChatSummary(id: String(cString: sqlite3_column_text(statement, 0)),
                    title: String(cString: sqlite3_column_text(statement, 1)),
                    model: String(cString: sqlite3_column_text(statement, 2)),
                    revision: Int(sqlite3_column_int64(statement, 3)))
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) throws {
        try requireOK(sqlite3_bind_text(statement, index, value, -1, Self.transient))
    }

    private func next(_ statement: OpaquePointer) throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw Failure.database
        }
    }

    private func requireOK(_ result: Int32) throws {
        guard result == SQLITE_OK else { throw Failure.database }
    }
}
