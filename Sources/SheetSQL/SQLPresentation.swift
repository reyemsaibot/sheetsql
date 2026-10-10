import AppKit

enum SQLSyntaxHighlighter {
    static func apply(to storage: NSTextStorage?, source: String) {
        guard let storage else { return }
        let full = NSRange(source.startIndex..., in: source)
        apply("--[^\\n]*", color: .secondaryLabelColor, to: storage, source: source, range: full)
        apply("'(?:''|[^'])*'|\\\"(?:\\\"\\\"|[^\\\"])*\\\"", color: .systemTeal, to: storage, source: source, range: full)
        let keywords = "SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AS|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|WITH|RECURSIVE|CASE|WHEN|THEN|ELSE|END|AND|OR|NOT|IN|IS|NULL|ASC|DESC|OVER|PARTITION"
        apply("\\b(?:\(keywords))\\b", color: .systemBlue, options: [.caseInsensitive], font: .monospacedSystemFont(ofSize: 14, weight: .semibold), to: storage, source: source, range: full)
        apply("\\b(?:COUNT|SUM|AVG|MIN|MAX|COALESCE|CAST|SUBSTR|LENGTH|LOWER|UPPER)\\s*(?=\\()", color: .systemPurple, options: [.caseInsensitive], to: storage, source: source, range: full)
    }
    private static func apply(_ pattern: String, color: NSColor, options: NSRegularExpression.Options = [], font: NSFont? = nil, to storage: NSTextStorage, source: String, range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        for match in regex.matches(in: source, range: range) {
            storage.addAttribute(.foregroundColor, value: color, range: match.range)
            if let font { storage.addAttribute(.font, value: font, range: match.range) }
        }
    }
}

enum SQLFormatter {
    static func format(_ sql: String) -> String {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sql }
        var output = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let clauses = ["SELECT", "FROM", "WHERE", "GROUP BY", "HAVING", "ORDER BY", "LIMIT", "OFFSET", "UNION ALL", "UNION"]
        for clause in clauses {
            output = output.replacingOccurrences(of: "(?i)\\s*\\b\(clause)\\b\\s*", with: "\n\(clause) ", options: .regularExpression)
        }
        output = output.replacingOccurrences(of: "(?i)\\s*\\b(LEFT|RIGHT|INNER|OUTER|CROSS)?\\s*JOIN\\b\\s*", with: "\n$1JOIN ", options: .regularExpression)
        output = output.replacingOccurrences(of: "(?i)\\s*\\b(AND|OR)\\b\\s*", with: "\n  $1 ", options: .regularExpression)
        output = output.replacingOccurrences(of: ",\\s*", with: ",\n  ", options: .regularExpression)
        return uppercaseKeywords(in: output).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func uppercaseKeywords(in sql: String) -> String {
        let keywords = ["SELECT", "FROM", "WHERE", "GROUP", "BY", "HAVING", "ORDER", "LIMIT", "OFFSET", "UNION", "ALL", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "CROSS", "ON", "AS", "AND", "OR", "ASC", "DESC", "WITH", "DISTINCT"]
        var output = "", buffer = "", inSingleQuote = false, inDoubleQuote = false
        func appendBuffer() {
            var formatted = buffer
            for keyword in keywords {
                formatted = formatted.replacingOccurrences(of: "(?i)\\b\(keyword)\\b", with: keyword, options: .regularExpression)
            }
            output += formatted
            buffer = ""
        }
        for character in sql {
            if character == "'" && !inDoubleQuote { appendBuffer(); inSingleQuote.toggle(); output.append(character) }
            else if character == "\"" && !inSingleQuote { appendBuffer(); inDoubleQuote.toggle(); output.append(character) }
            else if inSingleQuote || inDoubleQuote { output.append(character) }
            else { buffer.append(character) }
        }
        appendBuffer()
        return output
    }
}
