import AppKit
import UniformTypeIdentifiers

@MainActor
extension Workspace {
    func openSQL() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText]
        panel.message = "SQL-Abfrage in den Editor laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openSQL(url)
    }
    func openSQL(_ url: URL) {
        if sql != savedSQL && !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let alert = NSAlert()
            alert.messageText = "Aktuelle SQL-Abfrage ersetzen?"
            alert.informativeText = "Die Abfrage im Editor enthält ungespeicherte Änderungen."
            alert.addButton(withTitle: "Speichern und laden")
            alert.addButton(withTitle: "Abbrechen")
            alert.addButton(withTitle: "Ohne Speichern laden")
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn { return }
            if answer == .alertFirstButtonReturn && !saveSQL() { return }
        }
        do { try readSQL(from: url) } catch { fail(error) }
    }
    func readSQL(from url: URL) throws {
        var encoding = String.Encoding.utf8
        let loaded = try String(contentsOf: url, usedEncoding: &encoding)
        sql = loaded.hasPrefix("\u{FEFF}") ? String(loaded.dropFirst()) : loaded
        savedSQL = sql; sqlFileURL = url; hasWorkspace = true; selectedResultTab = nil; isSQLConsoleVisible = true
        status = "SQL geladen: \(url.lastPathComponent)"
    }
    func writeSQL(to url: URL) throws {
        try sql.write(to: url, atomically: true, encoding: .utf8)
        savedSQL = sql; sqlFileURL = url
        status = "SQL gespeichert: \(url.lastPathComponent)"
    }
    @discardableResult
    func saveSQL(asNew: Bool = false) -> Bool {
        var destination = asNew ? nil : sqlFileURL
        if destination == nil {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText]
            panel.nameFieldStringValue = sqlFileURL?.lastPathComponent ?? "Abfrage.sql"
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            destination = url.pathExtension.lowercased() == "sql" ? url : url.appendingPathExtension("sql")
        }
        do { try writeSQL(to: destination!); return true } catch { fail(error); return false }
    }
    func openURL(_ url: URL) {
        if url.pathExtension.lowercased() == "sql" { openSQL(url) } else { load([url]) }
    }
}

struct ResultTab: Identifiable {
    let id = UUID()
    let title: String
    let query: String
    let result: QueryResult
    var presentation: ResultPresentation
}

@MainActor
extension Workspace {
    var activeResult: QueryResult { resultTabs.first { $0.id == selectedResultTab }?.result ?? result }
    var activePresentation: ResultPresentation {
        get { resultTabs.first { $0.id == selectedResultTab }?.presentation ?? resultPresentation }
        set {
            if let index = resultTabs.firstIndex(where: { $0.id == selectedResultTab }) {
                resultTabs[index].presentation = newValue
            } else { resultPresentation = newValue }
        }
    }
    var activeQuery: String { resultTabs.first { $0.id == selectedResultTab }?.query ?? resultSQL }
    func openResultTab() {
        guard !activeResult.columns.isEmpty else { return }
        let tab = ResultTab(title: "Ergebnis \(nextResultTabNumber)", query: activeQuery, result: activeResult, presentation: activePresentation)
        nextResultTabNumber += 1
        resultTabs.append(tab); selectedResultTab = tab.id; isSQLConsoleVisible = false
    }
    func showResultTab(_ id: UUID) {
        guard resultTabs.contains(where: { $0.id == id }) else { return }
        selectedResultTab = id
        isSQLConsoleVisible = false
    }
    func closeResultTab(_ id: UUID) {
        if selectedResultTab == id { selectedResultTab = nil; isSQLConsoleVisible = true }
        resultTabs.removeAll { $0.id == id }
    }
}
