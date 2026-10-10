import XCTest
@testable import SheetSQL

final class ResultPresentationTests: XCTestCase {
    func testNumericSortingFilteringAndExport() {
        let source = QueryResult(columns: ["Region", "Wert"], rows: [["Nord", "10"], ["Süd", "2"], ["Nord", "-3"], ["Nord", nil]], numericColumns: [1])
        var state = ResultPresentation(filters: [0: .equals("Nord")], sortColumn: 1)
        XCTAssertEqual(state.applying(to: source).rows, [["Nord", nil], ["Nord", "-3"], ["Nord", "10"]])
        state.ascending = false
        let displayed = state.applying(to: source)
        XCTAssertEqual(displayed.rows, [["Nord", "10"], ["Nord", "-3"], ["Nord", nil]])
        XCTAssertFalse(displayed.csv.contains("Süd"))
        XCTAssertEqual(source.rows.count, 4)
        XCTAssertEqual(ResultPresentation().applying(to: source).rows, source.rows)
    }

    func testSearchAndAdditionalSort() {
        let result = QueryResult(columns: ["gruppe", "wert"], rows: [["B", "2"], ["A", "1"], ["B", "1"]], numericColumns: [1])
        var presentation = ResultPresentation(sortColumn: 0, ascending: true, additionalSortColumns: [1: true], searchText: "b")
        XCTAssertEqual(presentation.applying(to: result).rows, [["B", "1"], ["B", "2"]])
        presentation.searchText = "2"
        XCTAssertEqual(presentation.applying(to: result).rows, [["B", "2"]])
    }
    func testNullEmptyTextAndCombinedFilters() {
        let source = QueryResult(columns: ["Same", "Same"], rows: [[nil, "x"], ["", "x"], ["NULL", "x"], ["001", "X"], ["001", "y"]])
        XCTAssertEqual(ResultPresentation(filters: [0: .equals(nil)]).applying(to: source).rows, [[nil, "x"]])
        XCTAssertEqual(ResultPresentation(filters: [0: .equals("")]).applying(to: source).rows, [["", "x"]])
        XCTAssertEqual(ResultPresentation(filters: [0: .equals("001"), 1: .contains("x")]).applying(to: source).rows, [["001", "X"]])
        XCTAssertEqual(ResultPresentation(filters: [0: .excludes(nil)]).applying(to: source).rows.count, 4)
        XCTAssertTrue(ResultPresentation(filters: [1: .equals("missing")]).applying(to: source).rows.isEmpty)
    }
    @MainActor
    func testNewResultResetsViewAndPreservesSQL() {
        let model = Workspace()
        model.sql = "SELECT * FROM Data"
        model.resultPresentation = ResultPresentation(filters: [0: .equals("x")], sortColumn: 0)
        model.result = QueryResult(columns: ["a"], rows: [["y"]])
        XCTAssertFalse(model.resultPresentation.isActive)
        XCTAssertEqual(model.displayedResult.rows, [["y"]])
        XCTAssertEqual(model.sql, "SELECT * FROM Data")
    }
    func testSQLNumericMetadata() async throws {
        let database = Database()
        let result = try await database.query("SELECT 10 AS n, '001' AS code UNION ALL SELECT -2, '010'")
        XCTAssertEqual(result.numericColumns, [0])
        XCTAssertEqual(ResultPresentation(sortColumn: 0).applying(to: result).rows.first, ["-2", "010"])
        await database.close()
    }
}
