import Foundation
import SQLite3

enum SQLiteDatabaseError: LocalizedError {
    case open(path: String, message: String)
    case prepare(message: String)
    case step(message: String)

    var errorDescription: String? {
        switch self {
        case let .open(path, message):
            return "Could not open SQLite database at \(path): \(message)"
        case let .prepare(message):
            return "Could not prepare SQLite query: \(message)"
        case let .step(message):
            return "Could not read SQLite query: \(message)"
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(path: String, readOnly: Bool = true) throws {
        var database: OpaquePointer?
        let flags = (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE)
            | SQLITE_OPEN_NOMUTEX
        let result = path.withCString {
            sqlite3_open_v2($0, &database, flags, nil)
        }

        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let database {
                sqlite3_close(database)
            }
            throw SQLiteDatabaseError.open(path: path, message: message)
        }

        handle = database
        sqlite3_busy_timeout(database, 2_000)

        if !readOnly {
            // Codex's WAL-backed state database needs a writable connection to
            // read its WAL reliably. query_only prevents any data mutation.
            sqlite3_exec(database, "PRAGMA query_only = ON", nil, nil, nil)
        }
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func tableExists(_ table: String) throws -> Bool {
        var exists = false
        try query(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            bind: { statement in
                _ = table.withCString { name in
                    sqlite3_bind_text(statement, 1, name, -1, sqliteTransient)
                }
            },
            row: { _ in
                exists = true
            }
        )
        return exists
    }

    func query(
        _ sql: String,
        bind: (OpaquePointer) -> Void = { _ in },
        row: (OpaquePointer) -> Void
    ) throws {
        guard let handle else {
            throw SQLiteDatabaseError.open(path: "", message: "database is closed")
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.prepare(
                message: String(cString: sqlite3_errmsg(handle))
            )
        }
        defer { sqlite3_finalize(statement) }

        bind(statement)

        while true {
            let stepResult = sqlite3_step(statement)
            switch stepResult {
            case SQLITE_ROW:
                row(statement)
            case SQLITE_DONE:
                return
            default:
                throw SQLiteDatabaseError.step(
                    message: String(cString: sqlite3_errmsg(handle))
                )
            }
        }
    }

    func text(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        let charPointer = UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self)
        return String(cString: charPointer)
    }

    func int64(_ statement: OpaquePointer, _ index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func isNull(_ statement: OpaquePointer, _ index: Int32) -> Bool {
        sqlite3_column_type(statement, index) == SQLITE_NULL
    }
}
