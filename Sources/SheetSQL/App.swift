import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class Workspace: ObservableObject {
    @Published var sheets: [Sheet] = []
    @Published var selected: String?
    @Published var sql = "-- Wähle ein Arbeitsblatt oder lade die Beispieldaten.\nSELECT * FROM \"Umsaetze\";"
    @Published var result = QueryResult() { didSet { resultPresentation = ResultPresentation(); selectedResultTab = nil; isSQLConsoleVisible = true } }
    @Published var resultPresentation = ResultPresentation()
    @Published var resultTabs: [ResultTab] = []
    @Published var selectedResultTab: UUID?
    @Published var isSQLConsoleVisible = true
    @Published var sqlFileURL: URL?
    @Published var savedSQL: String?
    var resultSQL = ""
    var nextResultTabNumber = 1
    var displayedResult: QueryResult { activePresentation.applying(to: activeResult) }
    @Published var busy = false
    @Published var error: String?
    @Published var status = "Bereit"
    @Published var history: [String] = []
    @Published var hasWorkspace = false
    let editorController = SQLEditorController()
    let database = Database()
    var selectedSheet: Sheet? { sheets.first { $0.name == selected } }
    var sqlCompletionWords: [String] {
        let keywords = [
            "SELECT", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER",
            "ON", "AS", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN",
            "GROUP BY", "HAVING", "ORDER BY", "ASC", "DESC", "LIMIT", "OFFSET", "DISTINCT",
            "WITH", "UNION", "UNION ALL", "CASE", "WHEN", "THEN", "ELSE", "END",
            "COUNT", "SUM", "AVG", "MIN", "MAX", "COALESCE", "ROW_NUMBER", "OVER", "PARTITION BY"
        ]
        let identifiers = sheets.flatMap { sheet in [sheet.name] + sheet.columns }
        return Array(Set(keywords + identifiers)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    func addSheets(_ imported: [Sheet]) async throws {
        sheets = try await database.add(imported)
        selected = sheets.last?.name
        hasWorkspace = true
    }
    func closeFile(_ sheet: Sheet) {
        guard !busy else { return }
        busy = true; error = nil
        Task {
            do {
                try await removeWorkbook(sheet.workbookID)
                status = "\(sheet.source) geschlossen"; busy = false
            } catch { fail(error) }
        }
    }
    func removeWorkbook(_ id: UUID) async throws {
        sheets = try await database.removeWorkbook(id)
        if selectedSheet == nil { selected = sheets.first?.name }
        hasWorkspace = !sheets.isEmpty
        if !hasWorkspace {
            resultTabs.removeAll()
            selectedResultTab = nil
            isSQLConsoleVisible = true
        }
        result = QueryResult()
    }
    func insertColumn(_ column: String, from sheet: Sheet) {
        selectedResultTab = nil; isSQLConsoleVisible = true
        selected = sheet.name
        editorController.insertIdentifier(column)
    }
    func insertTable(_ sheet: Sheet) {
        selectedResultTab = nil; isSQLConsoleVisible = true
        selected = sheet.name
        editorController.insertIdentifier(sheet.name)
    }
    func createSelect(for sheet: Sheet) {
        selectedResultTab = nil; isSQLConsoleVisible = true
        selected = sheet.name
        sql = "SELECT *\nFROM \(quoted(sheet.name))\nLIMIT 1000;"
        editorController.focus()
    }
    func openEditor(for sheet: Sheet) {
        selected = sheet.name
        let query = "SELECT *\nFROM \(quoted(sheet.name));"
        sql = query
        guard !busy else { return }
        busy = true; error = nil
        Task {
            do {
                let fetched = try await database.query(query)
                result = fetched
                resultSQL = query
                history.removeAll { $0 == query }
                history.insert(query, at: 0)
                history = Array(history.prefix(15))
                status = "\(fetched.rows.count.formatted()) Zeilen · \(Int(fetched.seconds * 1000)) ms"
                busy = false
                openResultTab()
            } catch { fail(error) }
        }
    }
    /// Switch to the SQL console without changing or closing saved result tabs.
    func showSQLConsole() {
        isSQLConsoleVisible = true
    }
    func formatSQL() {
        sql = SQLFormatter.format(sql)
        editorController.focus()
    }
    func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        status = "In Zwischenablage kopiert"
    }
    func open() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!, UTType(filenameExtension: "xlsm")!]
        guard panel.runModal() == .OK else { return }
        load(panel.urls)
    }
    func load(_ urls: [URL]) {
        guard !busy else { return }; busy = true; error = nil; status = "Excel-Dateien werden gelesen …"
        Task {
            do {
                let imported = try await Task.detached { try urls.flatMap { try Excel.read($0) } }.value
                try await addSheets(imported)
                // A user-imported workbook starts with a clean SQL console.
                // Demo data is the only source that installs an example query.
                sql = ""
                savedSQL = nil
                sqlFileURL = nil
                resultTabs.removeAll()
                resultSQL = ""
                result = QueryResult()
                status = "\(imported.count) Arbeitsblätter importiert"; busy = false
            } catch { fail(error) }
        }
    }
    func preview(_ sheet: Sheet) { selectedResultTab = nil; isSQLConsoleVisible = true; selected = sheet.name; sql = "SELECT * FROM \(quoted(sheet.name))\nLIMIT 1000;"; run() }
    func run() {
        guard !busy else { return }; busy = true; error = nil
        let query = sql
        Task {
            do {
                result = try await database.query(query)
                resultSQL = query
                history.removeAll { $0 == query }; history.insert(query, at: 0); history = Array(history.prefix(15))
                status = "\(result.rows.count.formatted()) Zeilen · \(Int(result.seconds * 1000)) ms"; busy = false
            } catch { fail(error) }
        }
    }
    func fail(_ problem: Error) { error = problem.localizedDescription; busy = false; status = "Aktion fehlgeschlagen" }
    func demo() {
        guard !busy else { return }; busy = true; error = nil
        Task {
            do {
                let data = Sheet(name: "Umsaetze", source: "Beispieldaten", columns: ["Region", "Produkt", "Monat", "Umsatz", "Menge"], rows: [
                    [.text("Nord"), .text("Studio"), .text("2026-01"), .number(12400), .number(31)],
                    [.text("Süd"), .text("Studio"), .text("2026-01"), .number(18800), .number(47)],
                    [.text("West"), .text("Team"), .text("2026-01"), .number(9600), .number(16)],
                    [.text("Nord"), .text("Team"), .text("2026-02"), .number(15600), .number(26)],
                    [.text("Süd"), .text("Studio"), .text("2026-02"), .number(22000), .number(55)],
                    [.text("West"), .text("Studio"), .text("2026-02"), .number(11200), .number(28)]])
                try await addSheets([data])
                sql = "SELECT Region,\n       SUM(Umsatz) AS Gesamtumsatz,\n       SUM(Menge) AS Verkaufte_Einheiten\nFROM \(quoted(sheets.last!.name))\nGROUP BY Region\nORDER BY Gesamtumsatz DESC;"
                busy = false; run()
            } catch { fail(error) }
        }
    }
    func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.commaSeparatedText]; panel.nameFieldStringValue = "SheetSQL-Ergebnis.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ("\u{FEFF}" + displayedResult.csv).write(to: url, atomically: true, encoding: .utf8) } catch { fail(error) }
    }
}

@main
struct SheetSQLApp: App {
    @StateObject private var workspace = Workspace()

    init() {
        // Set the icon at runtime as well as in Info.plist. This makes the
        // Dock update immediately even when LaunchServices has cached an
        // older icon for the bundle identifier.
        if let url = Bundle.module.url(forResource: "SheetSQLDockIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: workspace).frame(minWidth: 960, minHeight: 660)
                .onOpenURL { workspace.openURL($0) }
        }.defaultSize(width: 1240, height: 820)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Excel-Datei öffnen …") { workspace.open() }.keyboardShortcut("o").disabled(workspace.busy)
                    Button("Ausgewählte Excel-Datei schließen") {
                        if let sheet = workspace.selectedSheet { workspace.closeFile(sheet) }
                    }.keyboardShortcut("w", modifiers: [.command, .shift])
                        .disabled(workspace.busy || workspace.selectedSheet == nil)
                }
                CommandGroup(after: .newItem) {
                    Divider()
                    Button("SQL-Datei laden …") { workspace.openSQL() }.keyboardShortcut("o", modifiers: [.command, .shift])
                    Button("SQL speichern") { workspace.saveSQL() }.keyboardShortcut("s")
                    Button("SQL speichern unter …") { workspace.saveSQL(asNew: true) }.keyboardShortcut("s", modifiers: [.command, .shift])
                }
                CommandMenu("Ergebnis") {
                    Button("In neuem Tab öffnen") { workspace.openResultTab() }
                        .keyboardShortcut("t", modifiers: [.command, .option]).disabled(workspace.activeResult.columns.isEmpty)
                    Button("Ergebnis-Tab schließen") {
                        if let id = workspace.selectedResultTab { workspace.closeResultTab(id) }
                    }.disabled(workspace.selectedResultTab == nil)
                }
                CommandMenu("Abfrage") { Button("SQL ausführen") { workspace.run() }.keyboardShortcut(.return, modifiers: .command).disabled(workspace.busy) }
            }
    }
}
struct ContentView: View {
    @ObservedObject var model: Workspace
    private let accent = Color(red: 0.18, green: 0.48, blue: 0.39)
    var body: some View {
        HSplitView {
            sidebar.frame(minWidth: 220, idealWidth: 255, maxWidth: 340)
            VStack(spacing: 0) {
                workspaceTabs
                // Keep the query actions available while a result tab is selected too.
                // The result view is maximized below, but its tab can still be closed
                // or switched to the SQL console without losing the command bar.
                if model.hasWorkspace {
                    sqlCommandBar
                    Divider()
                }
                if !model.hasWorkspace {
                    welcome
                } else if model.isSQLConsoleVisible {
                    // Do not keep a zero-height editor in the result view. On macOS
                    // it can still participate in hit testing and cover the tab bar.
                    editor
                    Divider()
                    results
                } else {
                    // A result tab is a full workspace view. The SQL console remains
                    // reachable through the tab strip above it.
                    results
                }
                Divider()
                HStack {
                    if model.busy { ProgressView().controlSize(.small) } else { Circle().fill(accent).frame(width: 6, height: 6) }
                    Text(model.status)
                    Spacer()
                    Text("SQLite · \(model.sheets.count) Tabellen")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.tint(accent)
            .alert("SheetSQL", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AppMark(size: 38)
                Text("SheetSQL").font(.title2.bold())
            }.padding(22)
            HStack { Text("ARBEITSBLÄTTER").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); Text("\(model.sheets.count)").font(.caption.monospacedDigit()) }.padding(.horizontal, 20).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(workbooks) { workbook in
                        workbookView(workbook)
                    }
                }.padding(.horizontal, 10)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 8) {
                Label("Ein Blatt = eine SQL-Tabelle", systemImage: "lightbulb")
                Text("Über Menüs, + und × kannst du Spalten einfügen, Tabellen verwenden und Dateien schließen.").foregroundStyle(.secondary)
            }.font(.caption).padding(18)
            Button { model.open() } label: { Label("Excel-Datei öffnen", systemImage: "folder.badge.plus").frame(maxWidth: .infinity).padding(.vertical, 6) }.disabled(model.busy).padding(16)
        }.background(Color(nsColor: .controlBackgroundColor))
    }
    var workbooks: [WorkbookGroup] {
        var result: [WorkbookGroup] = []
        for sheet in model.sheets {
            if let index = result.firstIndex(where: { $0.id == sheet.workbookID }) {
                result[index].sheets.append(sheet)
            } else {
                result.append(WorkbookGroup(id: sheet.workbookID, source: sheet.source, sheets: [sheet]))
            }
        }
        return result
    }
    @ViewBuilder
    func workbookView(_ workbook: WorkbookGroup) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(workbook.sheets) { sheet in
                    DisclosureGroup {
                        ForEach(sheet.columns, id: \.self) { column in
                            ColumnSidebarRow(column: column, sheet: sheet, model: model)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "shippingbox").foregroundStyle(.green)
                                Text(sheet.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            }
                            .contextMenu {
                                Button("SELECT-Anweisung erstellen") { model.createSelect(for: sheet) }
                                Button("Tabellenname einfügen") { model.insertTable(sheet) }
                                Button("Tabellenname kopieren") { model.copyToPasteboard(quoted(sheet.name)) }
                                Divider()
                                Button("Editor öffnen") { model.openEditor(for: sheet) }
                            }
                            Spacer()
                            Button { model.insertTable(sheet) } label: {
                                Image(systemName: "plus.circle.fill").foregroundStyle(accent)
                            }.buttonStyle(.borderless).help("\(quoted(sheet.name)) einfügen")
                        }.padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
                            .background(model.selected == sheet.name ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }.padding(.leading, 7)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cylinder").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workbook.source).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text("\(workbook.sheets.count) Arbeitsblatt\(workbook.sheets.count == 1 ? "" : "ätter") · \(workbook.sheets.reduce(0) { $0 + $1.rows.count }) Zeilen")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { model.closeFile(workbook.sheets[0]) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.borderless).help("Datei schließen: \(workbook.source)")
            }.padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).background(workbook.sheets.contains { $0.name == model.selected } ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
    var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            AppMark(size: 82)
            Text("Von Excel zur Antwort.").font(.largeTitle.weight(.semibold))
            Text("Öffne eine Arbeitsmappe und stelle Fragen an deine Daten.\nFiltern, aggregieren und Arbeitsblätter per JOIN verbinden.").multilineTextAlignment(.center).foregroundStyle(.secondary).lineSpacing(5)
            HStack(spacing: 12) {
                Button("Excel-Datei öffnen …") { model.open() }.buttonStyle(.borderedProminent)
                Button("Mit Beispieldaten starten") { model.demo() }
            }.controlSize(.large).disabled(model.busy)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            SQLEditor(text: $model.sql, controller: model.editorController, suggestions: model.sqlCompletionWords).padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                .frame(height: 175)
            Text("SELECT, JOIN, GROUP BY, CTEs und Fensterfunktionen · ⌘↵ zum Ausführen").font(.caption).foregroundStyle(.secondary)
        }.padding(20)
    }
    var sqlCommandBar: some View {
        HStack(spacing: 10) {
            Label(model.sqlFileURL?.lastPathComponent ?? "SQL-Abfrage", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)
            if model.sqlFileURL != nil && model.sql != model.savedSQL { Text("•").help("Ungespeicherte Änderungen") }
            Spacer()
            Button { model.openSQL() } label: { Label("Laden", systemImage: "folder") }
                .buttonStyle(.bordered)
                .help("SQL-Datei laden (⇧⌘O)")
            Button { model.saveSQL() } label: { Label("Speichern", systemImage: "square.and.arrow.down") }
                .buttonStyle(.bordered)
                .help("SQL speichern (⌘S)")
            Button { model.formatSQL() } label: { Label("Formatieren", systemImage: "text.line.first.and.arrowtriangle.forward") }
                .buttonStyle(.bordered)
                .help("SQL formatieren")
            Menu { ForEach(model.history, id: \.self) { sql in Button(String(sql.prefix(90))) { model.sql = sql } } } label: {
                Label("Verlauf", systemImage: "clock.arrow.circlepath")
            }
            .menuStyle(.borderedButton)
            Button { model.run() } label: { Label("Ausführen", systemImage: "play.fill") }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .zIndex(2)
    }
    @ViewBuilder
    var workspaceTabs: some View {
        if !model.resultTabs.isEmpty {
                HStack(spacing: 8) {
                    Button("SQL-Konsole") { model.showSQLConsole() }
                        .tint(model.isSQLConsoleVisible ? accent : .secondary)
                        .buttonStyle(.bordered)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(model.isSQLConsoleVisible ? accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .help("Zur SQL-Konsole wechseln")
                    ForEach(model.resultTabs) { tab in
                        HStack(spacing: 5) {
                            Button(tab.title) { model.showResultTab(tab.id) }
                                .help(tab.query)
                                .buttonStyle(.bordered)
                                .contentShape(Rectangle())
                            Button { model.closeResultTab(tab.id) } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                                .buttonStyle(.plain)
                                .help("Ergebnis-Tab schließen")
                        }
                        .padding(.leading, 9)
                        .padding(.vertical, 3)
                        .padding(.trailing, 2)
                        .background(model.selectedResultTab == tab.id && !model.isSQLConsoleVisible ? accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .foregroundStyle(.primary)
                .background(Color(nsColor: .windowBackgroundColor))
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(Divider(), alignment: .bottom)
                .zIndex(3)
        }
    }
    var results: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Ergebnis", systemImage: "tablecells").font(.headline)
                Text("\(model.displayedResult.rows.count) von \(model.activeResult.rows.count) Zeilen").font(.caption).foregroundStyle(.secondary)
                TextField("Ergebnis durchsuchen", text: Binding(
                    get: { model.activePresentation.searchText },
                    set: { model.activePresentation.searchText = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)
                .help("Alle sichtbaren Spalten durchsuchen")
                if model.activeResult.truncated { Text("Auf 10.000 Zeilen begrenzt – auch im Export").font(.caption).foregroundStyle(.orange) }
                Spacer()
                Button { model.openResultTab() } label: { Label("In neuem Tab", systemImage: "plus.square.on.square") }.disabled(model.activeResult.columns.isEmpty)
                Button { model.export() } label: { Label("CSV exportieren", systemImage: "square.and.arrow.up") }.disabled(model.activeResult.columns.isEmpty || model.busy)
            }.padding(16)
            if model.activePresentation.isActive {
                HStack {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(model.activePresentation.filters.keys.sorted(), id: \.self) { column in
                                Button {
                                    model.activePresentation.filters.removeValue(forKey: column)
                                } label: {
                                    Text("\(model.activeResult.columns[column]) \(model.activePresentation.filters[column]!.label)  ×").lineLimit(1)
                                }.help("Diesen Filter entfernen")
                            }
                            if let column = model.activePresentation.sortColumn {
                                Text("\(model.activeResult.columns[column]) \(model.activePresentation.ascending ? "↑" : "↓")").foregroundStyle(.secondary)
                            }
                            ForEach(model.activePresentation.additionalSortColumns.keys.sorted(), id: \.self) { column in
                                Text("\(model.activeResult.columns[column]) \(model.activePresentation.additionalSortColumns[column]! ? "↑²" : "↓²")").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Zurücksetzen") { model.activePresentation = ResultPresentation() }
                }.font(.caption).padding(.horizontal, 16).padding(.bottom, 10)
            }
            if model.activeResult.columns.isEmpty {
                ContentUnavailableView("Bereit für deine Abfrage", systemImage: "text.magnifyingglass", description: Text("SQL eingeben und auf Ausführen klicken."))
            } else { ResultGrid(result: model.displayedResult, presentation: $model.activePresentation).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.frame(maxHeight: .infinity)
    }
}

private struct AppMark: View {
    let size: CGFloat

    private var icon: Image {
        guard let url = Bundle.module.url(forResource: "SheetSQLIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return Image(systemName: "square.grid.2x2")
        }
        return Image(nsImage: image)
    }

    var body: some View {
        icon
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ColumnSidebarRow: View {
    let column: String
    let sheet: Sheet
    @ObservedObject var model: Workspace
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "cube").foregroundStyle(.green)
            Text(column).lineLimit(1)
            Spacer()
            if isHovering {
                Button { model.insertColumn(column, from: sheet) } label: {
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("\(quoted(column)) einfügen")
            }
        }
        .font(.system(size: 12))
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Spaltenname einfügen") { model.insertColumn(column, from: sheet) }
            Button("Spaltenname kopieren") { model.copyToPasteboard(quoted(column)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { isHovering = $0 }
        .help("Optionen für \(quoted(column))")
    }
}
