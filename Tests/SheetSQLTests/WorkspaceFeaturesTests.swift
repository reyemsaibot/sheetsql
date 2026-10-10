import XCTest
@testable import SheetSQL

final class WorkspaceFeaturesTests: XCTestCase {
    func testSQLParametersAreDetectedAndSafelySubstituted() {
        XCTAssertEqual(SQLParameters.names(in: "SELECT * FROM Data WHERE Region = :region AND n > :min"), ["min", "region"])
        XCTAssertEqual(SQLParameters.substitute("SELECT :name, :n, :empty", values: ["name": "O'Reilly", "n": "12", "empty": "NULL"]), "SELECT 'O''Reilly', 12, NULL")
    }

    func testExcelExportCreatesAnXLSXArchive() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SheetSQL-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }
        try ExcelExport.write(QueryResult(columns: ["Name", "Amount"], rows: [["Nord", "12.5"]], numericColumns: [1]), to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 100)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-t", "-q", url.path]
        try unzip.run()
        unzip.waitUntilExit()
        XCTAssertEqual(unzip.terminationStatus, 0)
    }

    func testWorkspaceSnapshotRoundTrip() throws {
        let snapshot = WorkspaceSnapshot(sql: "SELECT 1", sqlFilePath: nil, history: ["SELECT 1"], favorites: [FavoriteQuery(name: "Test", sql: "SELECT 1")], filePaths: ["/tmp/data.xlsx"])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        XCTAssertEqual(decoded.sql, snapshot.sql)
        XCTAssertEqual(decoded.favorites, snapshot.favorites)
        XCTAssertEqual(decoded.filePaths, snapshot.filePaths)
    }

    func testSheetProfilerClassifiesColumnsAndCountsEmptyValues() {
        let sheet = Sheet(name: "Data", source: "fixture", columns: ["Name", "Amount"], rows: [[.text(" Nord "), .number(12)], [.null, .number(18)]])
        let profiles = SheetProfiler.profile(sheet)
        XCTAssertEqual(profiles[0].type, "Text")
        XCTAssertEqual(profiles[0].nonEmpty, 1)
        XCTAssertEqual(profiles[0].empty, 1)
        XCTAssertEqual(profiles[0].distinct, 1)
        XCTAssertEqual(profiles[1].type, "Zahl")
        XCTAssertEqual(profiles[1].minimum, "12")
        XCTAssertEqual(profiles[1].maximum, "18")
    }

    func testDatabaseValidationRejectsWritesAndAcceptsSelects() async throws {
        let database = Database()
        let sourceURL = URL(fileURLWithPath: "/tmp/data.xlsx")
        let added = try await database.add([Sheet(name: "Data", source: "fixture", sourceURL: sourceURL, columns: ["value"], rows: [[.number(1)]])])
        XCTAssertEqual(added.first?.sourceURL, sourceURL)
        try await database.validate("SELECT * FROM Data")
        await XCTAssertThrowsErrorAsync { try await database.validate("DELETE FROM Data") }
    }

    @MainActor
    func testResultComparisonCountsChangedAndAddedRows() {
        let model = Workspace()
        model.result = QueryResult(columns: ["id", "value"], rows: [["1", "old"]])
        model.resultSQL = "SELECT old"
        model.openResultTab()
        model.result = QueryResult(columns: ["id", "value"], rows: [["1", "new"], ["2", "added"]])
        model.compareWithPrevious()
        XCTAssertEqual(model.comparison?.changedCells, 1)
        XCTAssertEqual(model.comparison?.addedRows, 1)
        XCTAssertEqual(model.comparison?.removedRows, 0)
    }
}

private func XCTAssertThrowsErrorAsync(_ expression: @escaping () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do { try await expression(); XCTFail("Expected an error", file: file, line: line) }
    catch { }
}
