import XCTest
@testable import SheetQL

final class SQLFilesAndTabsTests: XCTestCase {
    @MainActor
    func testSQLFileRoundTripAndReadFailure() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = Workspace(), url = folder.appendingPathComponent("Abfrage.sql")
        let query = "-- Umsätze\nSELECT \"0MATERIAL\" FROM \"Data\" WHERE \"Region\" = 'Süd';\n"
        model.sql = query
        try model.writeSQL(to: url)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), query)
        model.sql = "SELECT 2"
        try model.readSQL(from: url)
        XCTAssertEqual(model.sql, query)
        XCTAssertEqual(model.savedSQL, query)
        XCTAssertEqual(model.sqlFileURL, url)
        XCTAssertTrue(model.hasWorkspace)
        XCTAssertTrue(model.result.columns.isEmpty)
        XCTAssertThrowsError(try model.readSQL(from: folder.appendingPathComponent("missing.sql")))
        XCTAssertEqual(model.sql, query)
    }
    @MainActor
    func testTabsKeepResultsAndIndependentFilters() {
        let model = Workspace()
        model.result = QueryResult(columns: ["n"], rows: [["1"], ["2"]], numericColumns: [0])
        model.resultSQL = "SELECT n FROM Data"
        model.resultPresentation = ResultPresentation(filters: [0: .equals("1")])
        model.openResultTab()
        let id = model.selectedResultTab!
        XCTAssertEqual(model.resultTabs.count, 1)
        XCTAssertEqual(model.activeQuery, "SELECT n FROM Data")
        XCTAssertEqual(model.displayedResult.rows, [["1"]])

        // The tab bar's SQL console action must leave the saved tab intact and
        // restore the editor's current result.
        model.showSQLConsole()
        XCTAssertEqual(model.selectedResultTab, id)
        XCTAssertTrue(model.isSQLConsoleVisible)
        XCTAssertEqual(model.resultTabs.count, 1)
        XCTAssertEqual(model.activeResult.columns, ["n"])
        model.showResultTab(id)
        XCTAssertEqual(model.selectedResultTab, id)
        XCTAssertFalse(model.isSQLConsoleVisible)

        model.activePresentation.filters = [0: .equals("2")]
        XCTAssertEqual(model.displayedResult.rows, [["2"]])
        XCTAssertEqual(model.resultPresentation.filters[0], .equals("1"))
        model.result = QueryResult(columns: ["other"], rows: [["new"]])
        XCTAssertNil(model.selectedResultTab)
        model.selectedResultTab = id
        XCTAssertEqual(model.displayedResult.rows, [["2"]])
        XCTAssertEqual(model.activeResult.columns, ["n"])
        XCTAssertTrue(model.displayedResult.csv.contains("2"))
        model.closeResultTab(id)
        XCTAssertNil(model.selectedResultTab)
        XCTAssertEqual(model.displayedResult.rows, [["new"]])
        XCTAssertTrue(model.resultTabs.isEmpty)
    }
}
