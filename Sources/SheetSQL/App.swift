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
    @Published var workspaceURL: URL?
    @Published var savedSQL: String?
    var resultSQL = ""
    var nextResultTabNumber = 1
    var displayedResult: QueryResult { activePresentation.applying(to: activeResult) }
    @Published var busy = false
    @Published var error: String?
    @Published var status = "Bereit"
    @Published var history: [String] = []
    @Published var favorites: [FavoriteQuery] = []
    @Published var comparison: ResultComparison?
    @Published var hasWorkspace = false
    @Published var profileRequested = false
    @Published var joinBuilderRequested = false
    @Published var cleaningDemoRequested = false
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
        guard let query = resolvedSQL() else { busy = false; return }
        Task {
            do {
                try await database.validate(query)
                result = try await database.query(query)
                resultSQL = query
                history.removeAll { $0 == query }; history.insert(query, at: 0); history = Array(history.prefix(15))
                status = "\(result.rows.count.formatted()) Zeilen · \(Int(result.seconds * 1000)) ms"; busy = false
            } catch { fail(error) }
        }
    }
    func resolvedSQL() -> String? {
        let names = SQLParameters.names(in: sql)
        guard !names.isEmpty else { return sql }
        let alert = NSAlert(); alert.messageText = "Abfrageparameter"
        alert.informativeText = "Bitte Werte für die Parameter eingeben. Die SQL-Abfrage im Editor bleibt unverändert."
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        var fields: [(String, NSTextField)] = []
        for name in names {
            let field = NSTextField(string: "")
            field.placeholderString = "Wert für :\(name)"
            let row = NSStackView(views: [NSTextField(labelWithString: ":\(name)"), field])
            row.spacing = 10; row.distribution = .fill
            stack.addArrangedSubview(row); fields.append((name, field))
        }
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: CGFloat(names.count * 32))
        alert.accessoryView = stack
        alert.addButton(withTitle: "Ausführen"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return SQLParameters.substitute(sql, values: Dictionary(uniqueKeysWithValues: fields.map { ($0.0, $0.1.stringValue) }))
    }
    func validateCurrentSQL() {
        guard let query = resolvedSQL() else { return }
        Task { do { try await database.validate(query); status = "SQL ist gültig" } catch { fail(error) } }
    }
    func toggleFavorite(_ query: String, name: String? = nil) {
        if let index = favorites.firstIndex(where: { $0.sql == query }) { favorites.remove(at: index) }
        else { favorites.insert(FavoriteQuery(name: name ?? "Abfrage \(favorites.count + 1)", sql: query), at: 0) }
    }
    func isFavorite(_ query: String) -> Bool { favorites.contains { $0.sql == query } }
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
    func exportExcel() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]; panel.nameFieldStringValue = "SheetSQL-Ergebnis.xlsx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ExcelExport.write(displayedResult, to: url.pathExtension.lowercased() == "xlsx" ? url : url.appendingPathExtension("xlsx")); status = "Excel-Ergebnis gespeichert" } catch { fail(error) }
    }
    func compareWithPrevious() {
        guard !activeResult.columns.isEmpty else { return }
        let candidates = resultTabs.filter { $0.id != selectedResultTab }
        let other = candidates.last
        let left = other?.result ?? result
        let right = activeResult
        let shared = left.columns.filter { right.columns.contains($0) }
        let count = min(left.rows.count, right.rows.count)
        var changed = 0
        for row in 0..<count {
            for column in shared {
                if let a = left.columns.firstIndex(of: column), let b = right.columns.firstIndex(of: column), left.rows[row][a] != right.rows[row][b] { changed += 1 }
            }
        }
        comparison = ResultComparison(leftTitle: other?.title ?? "Vorheriges Ergebnis", rightTitle: selectedResultTab == nil ? "Aktuelles Ergebnis" : (resultTabs.first { $0.id == selectedResultTab }?.title ?? "Aktuelles Ergebnis"), leftRows: left.rows.count, rightRows: right.rows.count, sharedColumns: shared, changedCells: changed, addedRows: max(0, right.rows.count - left.rows.count), removedRows: max(0, left.rows.count - right.rows.count))
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
                CommandMenu("Arbeitsbereich") {
                    Button("Arbeitsbereich öffnen …") { workspace.openWorkspace() }.keyboardShortcut("o", modifiers: [.command, .control])
                    Button("Arbeitsbereich speichern") { _ = workspace.saveWorkspace() }.keyboardShortcut("s", modifiers: [.command, .control])
                    Button("Arbeitsbereich speichern unter …") { _ = workspace.saveWorkspace(asNew: true) }.keyboardShortcut("s", modifiers: [.command, .control, .shift])
                }
                CommandMenu("Ergebnis") {
                    Button("In neuem Tab öffnen") { workspace.openResultTab() }
                        .keyboardShortcut("t", modifiers: [.command, .option]).disabled(workspace.activeResult.columns.isEmpty)
                    Button("Ergebnis-Tab schließen") {
                        if let id = workspace.selectedResultTab { workspace.closeResultTab(id) }
                    }.disabled(workspace.selectedResultTab == nil)
                    Button("Als Excel exportieren …") { workspace.exportExcel() }.keyboardShortcut("e", modifiers: [.command]).disabled(workspace.activeResult.columns.isEmpty)
                    Button("Mit vorherigem Ergebnis vergleichen") { workspace.compareWithPrevious() }.disabled(workspace.activeResult.columns.isEmpty)
                }
                CommandMenu("Abfrage") {
                    Button("SQL ausführen") { workspace.run() }.keyboardShortcut(.return, modifiers: .command).disabled(workspace.busy)
                    Button("SQL prüfen") { workspace.validateCurrentSQL() }.keyboardShortcut("l", modifiers: .command).disabled(workspace.busy)
                }
                CommandMenu("Werkzeuge") {
                    Button("Spaltenprofil öffnen") { workspace.profileRequested = true }.disabled(workspace.selectedSheet == nil)
                    Button("JOIN-Builder öffnen") { workspace.joinBuilderRequested = true }.disabled(workspace.sheets.count < 2)
                    Button("Datenbereinigung-Demo öffnen") { workspace.cleaningDemoRequested = true }
                }
            }
    }
}
struct ContentView: View {
    @ObservedObject var model: Workspace
    @State private var profileSheet: Sheet?
    @State private var showJoinBuilder = false
    @State private var showCleaningDemo = false
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
            .sheet(item: $profileSheet) { sheet in ProfileView(sheet: sheet) }
            .sheet(isPresented: $showJoinBuilder) { JoinBuilderView(sheets: model.sheets) { model.sql = $0; model.showSQLConsole(); model.editorController.focus() } }
            .sheet(isPresented: $showCleaningDemo) { DataCleaningDemoView() }
            .onChange(of: model.profileRequested) { _, requested in
                if requested { profileSheet = model.selectedSheet; model.profileRequested = false }
            }
            .onChange(of: model.joinBuilderRequested) { _, requested in
                if requested { showJoinBuilder = true; model.joinBuilderRequested = false }
            }
            .onChange(of: model.cleaningDemoRequested) { _, requested in
                if requested { showCleaningDemo = true; model.cleaningDemoRequested = false }
            }
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
            Menu {
                Section("Verlauf") {
                    ForEach(model.history, id: \.self) { query in Button(String(query.prefix(90))) { model.sql = query } }
                }
                Button(model.isFavorite(model.sql) ? "Favorit entfernen" : "Aktuelle Abfrage als Favorit speichern") { model.toggleFavorite(model.sql) }
                if !model.favorites.isEmpty {
                    Divider()
                    Section("Favoriten") {
                        ForEach(model.favorites) { favorite in Button(favorite.name) { model.sql = favorite.sql } }
                    }
                }
            } label: {
                Label("Verlauf", systemImage: "clock.arrow.circlepath")
            }
            .menuStyle(.borderedButton)
            Menu {
                Button { profileSheet = model.selectedSheet } label: { Label("Spaltenprofil", systemImage: "chart.bar.xaxis") }
                    .disabled(model.selectedSheet == nil)
                Button { showJoinBuilder = true } label: { Label("JOIN-Builder", systemImage: "arrow.triangle.merge") }
                    .disabled(model.sheets.count < 2)
                Button { showCleaningDemo = true } label: { Label("Datenbereinigung-Demo", systemImage: "wand.and.stars") }
            } label: {
                Label("Werkzeuge", systemImage: "wrench.and.screwdriver")
            }
            .menuStyle(.borderedButton)
            .help("Profiling, JOIN-Builder und Datenbereinigung")
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
                Button { model.exportExcel() } label: { Label("Excel exportieren", systemImage: "tablecells") }.disabled(model.activeResult.columns.isEmpty || model.busy)
                Button { model.compareWithPrevious() } label: { Label("Vergleichen", systemImage: "square.2.layers.3d") }.disabled(model.activeResult.columns.isEmpty)
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
        .sheet(item: $model.comparison) { comparison in ComparisonView(comparison: comparison) }
    }
}

private struct ComparisonView: View {
    let comparison: ResultComparison
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ergebnisvergleich").font(.title2.bold())
            Text("\(comparison.leftTitle)  ↔  \(comparison.rightTitle)").foregroundStyle(.secondary)
            HStack {
                metric("Zeilen links", comparison.leftRows)
                metric("Zeilen rechts", comparison.rightRows)
                metric("Geänderte Zellen", comparison.changedCells)
                metric("Neue Zeilen", comparison.addedRows)
                metric("Entfernte Zeilen", comparison.removedRows)
            }
            Text("Gemeinsame Spalten: \(comparison.sharedColumns.isEmpty ? "keine" : comparison.sharedColumns.joined(separator: ", "))")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }.padding(24).frame(width: 620, height: 230)
    }
    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading) { Text(String(value)).font(.title3.bold()); Text(label).font(.caption).foregroundStyle(.secondary) }
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
