import SwiftUI

struct ColumnProfile: Identifiable, Sendable {
    let id: String
    let name: String
    let type: String
    let nonEmpty: Int
    let empty: Int
    let distinct: Int
    let sample: String
    let minimum: String?
    let maximum: String?
}

struct JoinKeySuggestion: Identifiable, Sendable, Equatable {
    let id: String
    let leftColumn: String
    let rightColumn: String
    let score: Double
    let reason: String
}

enum SheetProfiler {
    static func profile(_ sheet: Sheet) -> [ColumnProfile] {
        sheet.columns.indices.map { index in
            let values = sheet.rows.compactMap { row -> String? in
                guard index < row.count, row[index] != .null else { return nil }
                return row[index].display
            }
            let numbers = values.compactMap(Double.init)
            let type: String
            if values.isEmpty { type = "leer" }
            else if numbers.count == values.count { type = "Zahl" }
            else { type = "Text" }
            return ColumnProfile(id: sheet.columns[index], name: sheet.columns[index], type: type,
                                 nonEmpty: values.count, empty: sheet.rows.count - values.count,
                                 distinct: Set(values).count, sample: values.prefix(3).joined(separator: " · "),
                                 minimum: numbers.isEmpty ? values.min() : numbers.min().map { $0.formatted(.number.precision(.fractionLength(0...6))) },
                                 maximum: numbers.isEmpty ? values.max() : numbers.max().map { $0.formatted(.number.precision(.fractionLength(0...6))) })
        }
    }

    static func profile(_ result: QueryResult) -> [ColumnProfile] {
        result.columns.indices.map { index in
            let values = result.rows.compactMap { row -> String? in
                guard index < row.count, let value = row[index] else { return nil }
                return value
            }
            let numbers = values.compactMap(Double.init)
            let type = values.isEmpty ? "leer" : (numbers.count == values.count ? "Zahl" : "Text")
            return ColumnProfile(id: result.columns[index], name: result.columns[index], type: type,
                                 nonEmpty: values.count, empty: result.rows.count - values.count,
                                 distinct: Set(values).count, sample: values.prefix(3).joined(separator: " · "),
                                 minimum: numbers.isEmpty ? values.min() : numbers.min().map { $0.formatted(.number.precision(.fractionLength(0...6))) },
                                 maximum: numbers.isEmpty ? values.max() : numbers.max().map { $0.formatted(.number.precision(.fractionLength(0...6))) })
        }
    }
}

enum JoinKeyDetector {
    static func suggestions(left: Sheet, right: Sheet) -> [JoinKeySuggestion] {
        var result: [JoinKeySuggestion] = []
        for leftColumn in left.columns {
            for rightColumn in right.columns {
                let leftKey = normalize(leftColumn)
                let rightKey = normalize(rightColumn)
                var score = 0.0
                var reasons: [String] = []
                if leftKey == rightKey { score += 0.75; reasons.append("gleicher Spaltenname") }
                else if leftKey.contains(rightKey) || rightKey.contains(leftKey) { score += 0.35; reasons.append("ähnlicher Spaltenname") }
                let overlap = valueOverlap(leftColumn, in: left, rightColumn, in: right)
                if overlap > 0.5 { score += 0.25; reasons.append("gemeinsame Werte") }
                if score >= 0.35 { result.append(JoinKeySuggestion(id: "\(leftColumn)|\(rightColumn)", leftColumn: leftColumn, rightColumn: rightColumn, score: score, reason: reasons.joined(separator: ", "))) }
            }
        }
        return result.sorted { $0.score > $1.score }
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression).replacingOccurrences(of: "id$", with: "", options: .regularExpression)
    }

    private static func valueOverlap(_ leftColumn: String, in left: Sheet, _ rightColumn: String, in right: Sheet) -> Double {
        guard let li = left.columns.firstIndex(of: leftColumn), let ri = right.columns.firstIndex(of: rightColumn) else { return 0 }
        let l = Set(left.rows.compactMap { li < $0.count ? $0[li].display : nil }.filter { !$0.isEmpty })
        let r = Set(right.rows.compactMap { ri < $0.count ? $0[ri].display : nil }.filter { !$0.isEmpty })
        guard !l.isEmpty, !r.isEmpty else { return 0 }
        return Double(l.intersection(r).count) / Double(min(l.count, r.count))
    }
}

struct JoinBuilderView: View {
    let sheets: [Sheet]
    let onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var left = ""
    @State private var right = ""
    @State private var leftColumn = ""
    @State private var rightColumn = ""
    @State private var joinType = "INNER JOIN"

    private var leftSheet: Sheet? { sheets.first { $0.name == left } }
    private var rightSheet: Sheet? { sheets.first { $0.name == right } }
    private var suggestions: [JoinKeySuggestion] {
        guard let leftSheet, let rightSheet else { return [] }
        return JoinKeyDetector.suggestions(left: leftSheet, right: rightSheet)
    }
    private var sql: String {
        guard !left.isEmpty, !right.isEmpty, !leftColumn.isEmpty, !rightColumn.isEmpty else { return "" }
        return "SELECT *\nFROM \(quoted(left)) AS l\n\(joinType) \(quoted(right)) AS r\n  ON l.\(quoted(leftColumn)) = r.\(quoted(rightColumn));"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("JOIN-Abfrage erstellen").font(.title2.bold())
            Text("Wähle zwei Arbeitsblätter und die passenden Spalten.").foregroundStyle(.secondary)
            HStack {
                picker("Linke Tabelle", selection: $left, values: sheets.map(\.name))
                picker("Rechte Tabelle", selection: $right, values: sheets.map(\.name))
            }
            Picker("Verknüpfung", selection: $joinType) {
                Text("INNER JOIN").tag("INNER JOIN")
                Text("LEFT JOIN").tag("LEFT JOIN")
                Text("FULL OUTER JOIN").tag("FULL OUTER JOIN")
            }.pickerStyle(.segmented)
            HStack {
                picker("Linke Spalte", selection: $leftColumn, values: leftSheet?.columns ?? [])
                picker("Rechte Spalte", selection: $rightColumn, values: rightSheet?.columns ?? [])
            }
            if let suggestion = suggestions.first {
                Button("Schlüsselvorschlag: \(suggestion.leftColumn) = \(suggestion.rightColumn) · \(suggestion.reason)") {
                    leftColumn = suggestion.leftColumn; rightColumn = suggestion.rightColumn
                }.buttonStyle(.bordered).help("Automatisch erkannter JOIN-Schlüssel")
            }
            GroupBox("Vorschau") {
                Text(sql.isEmpty ? "Bitte alle Felder auswählen." : sql)
                    .font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            HStack { Spacer(); Button("Abbrechen") { dismiss() }; Button("In SQL-Editor übernehmen") { onInsert(sql); dismiss() }.buttonStyle(.borderedProminent).disabled(sql.isEmpty) }
        }.padding(24).frame(width: 700)
        .onAppear {
            if left.isEmpty { left = sheets.first?.name ?? "" }
            if right.isEmpty { right = sheets.dropFirst().first?.name ?? sheets.first?.name ?? "" }
            leftColumn = leftSheet?.columns.first ?? ""
            rightColumn = rightSheet?.columns.first ?? ""
        }
        .onChange(of: left) { _, _ in leftColumn = leftSheet?.columns.first ?? "" }
        .onChange(of: right) { _, _ in rightColumn = rightSheet?.columns.first ?? "" }
    }

    private func picker(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Picker(title, selection: selection) { ForEach(values, id: \.self) { Text($0).tag($0) } }.labelsHidden() }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileView: View {
    let sheet: Sheet
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Spaltenprofil").font(.title2.bold()); Spacer(); Button("Fertig") { dismiss() } }
            Text("\(sheet.name) · \(sheet.rows.count.formatted()) Zeilen").foregroundStyle(.secondary)
            ProfileTableView(profiles: SheetProfiler.profile(sheet))
        }.padding(24).frame(width: 900, height: 500)
    }
}

struct ResultProfileView: View {
    let result: QueryResult
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Profil des SQL-Ergebnisses").font(.title2.bold()); Spacer(); Button("Fertig") { dismiss() } }
            Text("Aggregiertes Ergebnis · \(result.rows.count.formatted()) Zeilen").foregroundStyle(.secondary)
            ProfileTableView(profiles: SheetProfiler.profile(result))
        }.padding(24).frame(width: 900, height: 500)
    }
}

private struct ProfileTableView: View {
    let profiles: [ColumnProfile]
    var body: some View {
        Table(profiles) {
                TableColumn("Spalte", value: \.name)
                TableColumn("Typ", value: \.type)
                TableColumn("Nicht leer") { Text(String($0.nonEmpty)) }
                TableColumn("Leer") { Text(String($0.empty)) }
                TableColumn("Eindeutig") { Text(String($0.distinct)) }
                TableColumn("Beispiel") { Text($0.sample).lineLimit(1) }
                TableColumn("Min") { Text($0.minimum ?? "–") }
                TableColumn("Max") { Text($0.maximum ?? "–") }
        }.frame(minHeight: 300)
    }
}

struct DataCleaningDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var raw = "  Berlin  "
    @State private var trim = true
    @State private var uppercase = false
    @State private var replaceSpaces = false
    private var cleaned: String {
        var value = raw
        if trim { value = value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if uppercase { value = value.uppercased() }
        if replaceSpaces { value = value.replacingOccurrences(of: " ", with: "_") }
        return value
    }
    private var sqlExpression: String {
        let source = uppercase ? "UPPER(\"Spalte\")" : "\"Spalte\""
        let replacement = replaceSpaces ? "'_'" : "' '"
        return "TRIM(REPLACE(\(source), ' ', \(replacement)))"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Datenbereinigung – Demo").font(.title2.bold()); Spacer(); Button("Fertig") { dismiss() } }
            Text("Die Demo verändert keine Datei. Sie zeigt, wie eine Bereinigung vor der SQL-Abfrage aussehen kann.").foregroundStyle(.secondary)
            TextField("Rohwert", text: $raw)
            Toggle("Leerzeichen am Anfang und Ende entfernen", isOn: $trim)
            Toggle("Großschreibung anwenden", isOn: $uppercase)
            Toggle("Leerzeichen durch _ ersetzen", isOn: $replaceSpaces)
            GroupBox("Vorschau") { HStack { Text(raw).foregroundStyle(.secondary); Image(systemName: "arrow.right"); Text(cleaned).fontWeight(.semibold) }.frame(maxWidth: .infinity, alignment: .leading).padding(8) }
            GroupBox("SQL-Ausdruck") { Text(sqlExpression).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(8) }
            Spacer()
        }.padding(24).frame(width: 620, height: 420)
    }
}
