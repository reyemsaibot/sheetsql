import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Workspace
    @State private var limitText = ""
    @FocusState private var limitFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Abfrage").font(.title3.weight(.semibold))
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("Maximale Ergebniszeilen")
                    .frame(width: 205, alignment: .leading)
                TextField("10.000", text: $limitText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
                    .focused($limitFocused)
                    .onSubmit { apply() }
            }
            Text("Standard: 10.000. Höhere Werte können mehr Speicher benötigen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Übernehmen") { apply() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560, height: 190)
        .onAppear {
            limitText = String(model.resultLimit)
            limitFocused = true
        }
    }
    private func apply() {
        guard let value = Int(limitText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { limitText = String(model.resultLimit); return }
        model.resultLimit = value; model.status = "Ergebnislimit: \(value.formatted()) Zeilen"
    }
}

struct QueryPlanView: View {
    let result: QueryResult
    @Environment(\.dismiss) private var dismiss
    private var rows: [PlanRow] { result.rows.map { PlanRow(values: $0) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Abfrageplan").font(.title2.bold()); Spacer(); Button("Fertig") { dismiss() } }
            Text("SQLite erklärt, wie Tabellen gelesen und JOINs ausgeführt werden.").foregroundStyle(.secondary)
            Table(rows) {
                TableColumn("id") { Text($0.value(at: 0)) }
                TableColumn("parent") { Text($0.value(at: 1)) }
                TableColumn("notused") { Text($0.value(at: 2)) }
                TableColumn("detail") { Text($0.value(at: 3)) }
            }.frame(minHeight: 260)
        }.padding(24).frame(width: 760, height: 420)
    }
}

private struct PlanRow: Identifiable {
    let id = UUID()
    let values: [String?]
    func value(at index: Int) -> String { guard index < values.count else { return "" }; return values[index] ?? "NULL" }
}

struct PivotBuilderView: View {
    let sheet: Sheet
    let onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var groupColumn = ""
    @State private var valueColumn = ""
    @State private var aggregate = "SUM"
    private var sql: String {
        guard !groupColumn.isEmpty, !valueColumn.isEmpty else { return "" }
        let alias = "\(aggregate.lowercased())_\(valueColumn)"
        return "SELECT \(quoted(groupColumn)),\n       \(aggregate)(\(quoted(valueColumn))) AS \(quoted(alias))\nFROM \(quoted(sheet.name))\nGROUP BY \(quoted(groupColumn))\nORDER BY \(quoted(alias)) DESC;"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gruppierungsassistent").font(.title2.bold())
            Text("Erzeuge eine typische Pivot-Auswertung aus einem Arbeitsblatt.").foregroundStyle(.secondary)
            Picker("Gruppieren nach", selection: $groupColumn) { ForEach(sheet.columns, id: \.self) { Text($0).tag($0) } }
            Picker("Wert", selection: $valueColumn) { ForEach(sheet.columns, id: \.self) { Text($0).tag($0) } }
            Picker("Aggregation", selection: $aggregate) { Text("SUM").tag("SUM"); Text("AVG").tag("AVG"); Text("MIN").tag("MIN"); Text("MAX").tag("MAX"); Text("COUNT").tag("COUNT") }.pickerStyle(.segmented)
            GroupBox("SQL-Vorschau") { Text(sql.isEmpty ? "Bitte Spalten auswählen." : sql).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(8) }
            HStack { Spacer(); Button("Abbrechen") { dismiss() }; Button("In SQL-Editor übernehmen") { onInsert(sql); dismiss() }.buttonStyle(.borderedProminent).disabled(sql.isEmpty) }
        }.padding(24).frame(width: 650)
        .onAppear { groupColumn = sheet.columns.first ?? ""; valueColumn = sheet.columns.dropFirst().first ?? sheet.columns.first ?? "" }
    }
}
