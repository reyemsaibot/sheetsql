import Foundation
import AppKit

struct FavoriteQuery: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var sql: String
    init(id: UUID = UUID(), name: String, sql: String) {
        self.id = id; self.name = name; self.sql = sql
    }
}

struct WorkspaceSnapshot: Codable, Sendable {
    var version = 1
    var sql: String
    var sqlFilePath: String?
    var history: [String]
    var favorites: [FavoriteQuery]
    var filePaths: [String]
}

struct ResultComparison: Identifiable, Sendable {
    let id = UUID()
    let leftTitle: String
    let rightTitle: String
    let leftRows: Int
    let rightRows: Int
    let sharedColumns: [String]
    let changedCells: Int
    let addedRows: Int
    let removedRows: Int
}

enum SQLParameters {
    static func names(in sql: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!:):([A-Za-z_][A-Za-z0-9_]*)"#) else { return [] }
        let range = NSRange(sql.startIndex..., in: sql)
        return Array(Set(regex.matches(in: sql, range: range).compactMap { match in
            guard let nameRange = Range(match.range(at: 1), in: sql) else { return nil }
            return String(sql[nameRange])
        })).sorted()
    }

    static func literal(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare("NULL") == .orderedSame { return "NULL" }
        if Double(trimmed) != nil { return trimmed }
        return "'" + trimmed.replacingOccurrences(of: "'", with: "''") + "'"
    }

    static func substitute(_ sql: String, values: [String: String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!:):([A-Za-z_][A-Za-z0-9_]*)"#) else { return sql }
        let range = NSRange(sql.startIndex..., in: sql)
        let matches = regex.matches(in: sql, range: range)
        let output = NSMutableString(string: sql)
        for match in matches.reversed() {
            guard let nameRange = Range(match.range(at: 1), in: sql), let value = values[String(sql[nameRange])] else { continue }
            output.replaceCharacters(in: match.range, with: literal(value))
        }
        return output as String
    }
}
