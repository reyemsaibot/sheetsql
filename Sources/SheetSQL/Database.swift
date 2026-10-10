import Foundation
import CSQLite

struct QueryResult: Sendable {
    var columns: [String] = []
    var rows: [[String?]] = []
    var numericColumns: Set<Int> = []
    var seconds: Double = 0
    var truncated = false
    var csv: String {
        func escape(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return ([columns.map(escape).joined(separator: ",")] + rows.map { $0.map { escape($0 ?? "") }.joined(separator: ",") }).joined(separator: "\r\n")
    }
}
func quoted(_ name: String) -> String { "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
actor Database {
    private var db: OpaquePointer?
    private var sheets: [Sheet] = []
    init() { sqlite3_open(":memory:", &db) }
    func close() { sqlite3_close(db); db = nil }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func failure() -> AppError { AppError(message: String(cString: sqlite3_errmsg(db))) }
    func add(_ incoming: [Sheet]) throws -> [Sheet] {
        try execute("BEGIN")
        var added: [Sheet] = []
        do {
            for input in incoming {
                var name = input.name; var i = 2
                while (sheets + added).contains(where: { $0.name.lowercased() == name.lowercased() }) || name.lowercased().hasPrefix("sqlite_") {
                    name = "\(input.name.lowercased().hasPrefix("sqlite_") ? "sheet" : input.name)_\(i)"; i += 1
                }
                let sheet = Sheet(workbookID: input.workbookID, name: name, source: input.source, sourceURL: input.sourceURL, columns: input.columns, rows: input.rows)
                // No column affinity: preserve numeric-looking text such as article codes and leading zeroes.
                try execute("CREATE TABLE \(quoted(name)) (\(sheet.columns.map(quoted).joined(separator: ",")))")
                var statement: OpaquePointer?
                let sql = "INSERT INTO \(quoted(name)) VALUES (\(Array(repeating: "?", count: sheet.columns.count).joined(separator: ",")))"
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
                defer { sqlite3_finalize(statement) }
                for row in sheet.rows {
                    sqlite3_reset(statement); sqlite3_clear_bindings(statement)
                    for (index, cell) in row.enumerated() {
                        switch cell {
                        case .null: sqlite3_bind_null(statement, Int32(index + 1))
                        case .number(let n): sqlite3_bind_double(statement, Int32(index + 1), n)
                        case .text(let text): _ = text.withCString { sqlite3_bind_text(statement, Int32(index + 1), $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
                        }
                    }
                    guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
                }
                added.append(sheet)
            }
            try execute("COMMIT"); sheets += added; return sheets
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func removeWorkbook(_ id: UUID) throws -> [Sheet] {
        let removed = sheets.filter { $0.workbookID == id }
        try execute("BEGIN")
        do {
            for sheet in removed { try execute("DROP TABLE \(quoted(sheet.name))") }
            try execute("COMMIT")
            sheets.removeAll { $0.workbookID == id }
            return sheets
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func query(_ sql: String) throws -> QueryResult {
        let start = Date()
        let deadline = UnsafeMutablePointer<Double>.allocate(capacity: 1)
        deadline.initialize(to: Date().timeIntervalSince1970 + 10)
        sqlite3_progress_handler(db, 1000, { context in
            guard let context else { return 0 }
            return Date().timeIntervalSince1970 > context.assumingMemoryBound(to: Double.self).pointee ? 1 : 0
        }, deadline)
        sqlite3_set_authorizer(db, { _, action, _, _, _, _ in
            switch action { case SQLITE_SELECT, SQLITE_READ, SQLITE_FUNCTION, SQLITE_RECURSIVE: return SQLITE_OK; default: return SQLITE_DENY }
        }, nil)
        defer {
            sqlite3_progress_handler(db, 0, nil, nil); sqlite3_set_authorizer(db, nil, nil)
            deadline.deinitialize(count: 1); deadline.deallocate()
        }
        var statement: OpaquePointer?
        guard let pointer = strdup(sql) else { throw AppError(message: "Nicht genügend Speicher.") }
        defer { free(pointer) }
        var tail: UnsafePointer<CChar>?
        guard sqlite3_prepare_v2(db, pointer, -1, &statement, &tail) == SQLITE_OK else { throw failure() }
        if let tail, !String(cString: tail).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sqlite3_finalize(statement)
            throw AppError(message: "Bitte nur eine SQL-Abfrage gleichzeitig ausführen.")
        }
        defer { sqlite3_finalize(statement) }
        guard statement != nil, sqlite3_column_count(statement) > 0, sqlite3_stmt_readonly(statement) != 0 else { throw AppError(message: "Bitte eine SELECT-Abfrage eingeben.") }
        var result = QueryResult(columns: (0..<sqlite3_column_count(statement)).map { String(cString: sqlite3_column_name(statement, $0)) })
        var numeric = Set<Int>(), nonnumeric = Set<Int>()
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { break }
            guard status == SQLITE_ROW else { throw failure() }
            if result.rows.count == 10_000 { result.truncated = true; break }
            for index in 0..<sqlite3_column_count(statement) {
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER, SQLITE_FLOAT: numeric.insert(Int(index))
                case SQLITE_NULL: break
                default: nonnumeric.insert(Int(index))
                }
            }
            result.rows.append((0..<sqlite3_column_count(statement)).map { index in
                guard sqlite3_column_type(statement, index) != SQLITE_NULL, let text = sqlite3_column_text(statement, index) else { return nil }
                return String(cString: text)
            })
        }
        result.numericColumns = numeric.subtracting(nonnumeric)
        result.seconds = Date().timeIntervalSince(start); return result
    }

    func validate(_ sql: String) throws {
        guard let pointer = strdup(sql) else { throw AppError(message: "Nicht genügend Speicher.") }
        defer { free(pointer) }
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        guard sqlite3_prepare_v2(db, pointer, -1, &statement, &tail) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        if let tail, !String(cString: tail).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError(message: "Bitte nur eine SQL-Abfrage gleichzeitig ausführen.")
        }
        guard statement != nil, sqlite3_column_count(statement) > 0, sqlite3_stmt_readonly(statement) != 0 else {
            throw AppError(message: "Bitte eine SELECT-Abfrage eingeben.")
        }
    }
}
