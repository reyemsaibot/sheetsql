import AppKit
import UniformTypeIdentifiers

@MainActor
extension Workspace {
    func saveWorkspace(asNew: Bool = false) -> Bool {
        var destination: URL?
        if !asNew { destination = workspaceURL }
        if destination == nil {
            let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "sheetsql") ?? .data]; panel.nameFieldStringValue = "Arbeitsbereich.sheetsql"
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            destination = url.pathExtension.lowercased() == "sheetsql" ? url : url.appendingPathExtension("sheetsql")
            workspaceURL = destination
        }
        let paths = Array(Set(sheets.compactMap { $0.sourceURL?.path })).sorted()
        let snapshot = WorkspaceSnapshot(sql: sql, sqlFilePath: sqlFileURL?.path, history: history, favorites: favorites, filePaths: paths)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: destination!, options: .atomic)
            status = "Arbeitsbereich gespeichert: \(destination!.lastPathComponent)"
            return true
        } catch { fail(error); return false }
    }

    func openWorkspace() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "sheetsql") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(contentsOf: url))
            workspaceURL = url
            guard !snapshot.filePaths.isEmpty else { sql = snapshot.sql; history = snapshot.history; favorites = snapshot.favorites; status = "Arbeitsbereich geladen"; return }
            loadWorkspaceFiles(snapshot)
        } catch { fail(error) }
    }

    private func loadWorkspaceFiles(_ snapshot: WorkspaceSnapshot) {
        guard !busy else { return }; busy = true; error = nil; status = "Arbeitsbereich wird geladen …"
        let urls = snapshot.filePaths.map(URL.init(fileURLWithPath:))
        Task {
            do {
                let imported = try await Task.detached { try urls.flatMap { try Excel.read($0) } }.value
                try await addSheets(imported)
                sql = snapshot.sql; history = snapshot.history; favorites = snapshot.favorites
                if let path = snapshot.sqlFilePath { sqlFileURL = URL(fileURLWithPath: path); savedSQL = snapshot.sql }
                resultTabs.removeAll(); result = QueryResult(); busy = false; status = "Arbeitsbereich geladen"
            } catch { fail(error) }
        }
    }
}
