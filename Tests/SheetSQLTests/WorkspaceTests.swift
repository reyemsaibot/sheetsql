import XCTest
import AppKit
@testable import SheetSQL

@MainActor
private final class TestEditor: NSTextView {
    private let manager: UndoManager = { let manager = UndoManager(); manager.groupsByEvent = false; return manager }()
    override var undoManager: UndoManager? { manager }
}

final class WorkspaceTests: XCTestCase {
    @MainActor
    func testSQLCompletionIncludesKeywordsTablesAndColumns() {
        let model = Workspace()
        model.sheets = [Sheet(name: "Umsaetze", source: "test.xlsx", columns: ["Region", "Umsatz"], rows: [])]
        XCTAssertTrue(model.sqlCompletionWords.contains("SELECT"))
        XCTAssertTrue(model.sqlCompletionWords.contains("Umsaetze"))
        XCTAssertTrue(model.sqlCompletionWords.contains("Region"))
        XCTAssertEqual(SQLCompletion.candidates(model.sqlCompletionWords, matching: "reg"), ["Region"])
    }

    func testSQLCompletionOnlyTriggersForTypedIdentifierCharacters() {
        XCTAssertTrue(SQLCompletion.shouldOffer(for: "P"))
        XCTAssertTrue(SQLCompletion.shouldOffer(for: "_"))
        XCTAssertFalse(SQLCompletion.shouldOffer(for: ""))
        XCTAssertFalse(SQLCompletion.shouldOffer(for: " "))
        XCTAssertFalse(SQLCompletion.shouldOffer(for: "OPLANT"))
    }

    @MainActor
    func testImportAndClosePreserveSQLAndGroupByWorkbook() async throws {
        let model = Workspace()
        let firstID = UUID(), secondID = UUID()
        let first = Sheet(workbookID: firstID, name: "Data", source: "same.xlsx", columns: ["Value"], rows: [[.number(1)]])
        let sibling = Sheet(workbookID: firstID, name: "Details", source: "same.xlsx", columns: ["Value"], rows: [[.number(2)]])
        let second = Sheet(workbookID: secondID, name: "Data", source: "same.xlsx", columns: ["Value"], rows: [[.number(3)]])
        model.sql = "SELECT \"Value\" FROM \"Data\" WHERE \"Value\" > 0;"
        let original = model.sql
        try await model.addSheets([first, sibling])
        try await model.addSheets([second])
        XCTAssertEqual(model.sql, original)
        XCTAssertTrue(model.history.isEmpty)
        model.selected = "Data"
        try await model.removeWorkbook(firstID)
        XCTAssertEqual(model.sheets.map(\.name), ["Data_2"])
        XCTAssertEqual(model.selected, "Data_2")
        XCTAssertEqual(model.sql, original)
        let remaining = try await model.database.query("SELECT * FROM Data_2")
        XCTAssertEqual(remaining.rows, [["3.0"]])
        for name in ["Data", "Details"] {
            do { _ = try await model.database.query("SELECT * FROM \(quoted(name))"); XCTFail("Closed table remains") } catch { }
        }
        try await model.removeWorkbook(secondID)
        XCTAssertTrue(model.sheets.isEmpty)
        XCTAssertNil(model.selected)
        XCTAssertFalse(model.hasWorkspace)
        XCTAssertEqual(model.sql, original)
        try await model.addSheets([first])
        XCTAssertEqual(model.sheets.map(\.name), ["Data"])
        await model.database.close()
    }

    @MainActor
    func testColumnInsertionUsesCursorSelectionAndUndo() {
        let editor = TestEditor()
        editor.allowsUndo = true
        let controller = SQLEditorController()
        controller.editor = editor
        editor.string = "SELECT * FROM Data WHERE "
        editor.setSelectedRange(NSRange(location: 7, length: 1))
        editor.undoManager?.beginUndoGrouping()
        controller.insertIdentifier("0MATERIAL")
        editor.undoManager?.endUndoGrouping()
        XCTAssertEqual(editor.string, "SELECT \"0MATERIAL\" FROM Data WHERE ")
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.undoManager?.beginUndoGrouping()
        controller.insertIdentifier("Base Unit of Measure")
        editor.undoManager?.endUndoGrouping()
        XCTAssertEqual(editor.string, "SELECT \"0MATERIAL\" FROM Data WHERE \"Base Unit of Measure\"")
        editor.undoManager?.beginUndoGrouping()
        controller.insertIdentifier("A\"B")
        editor.undoManager?.endUndoGrouping()
        XCTAssertTrue(editor.string.hasSuffix("\"A\"\"B\""))
        XCTAssertEqual(editor.selectedRange().length, 0)
        XCTAssertTrue(editor.undoManager?.canUndo ?? false)
        editor.undoManager?.undo()
        XCTAssertTrue(editor.string.hasSuffix("\"Base Unit of Measure\""))
    }

    @MainActor
    func testTableActionsUseTheSelectedSheet() {
        let model = Workspace()
        let sheet = Sheet(name: "Sales Data", source: "Sales.xlsx", columns: ["Net Value"], rows: [])
        model.sheets = [sheet]
        model.selectedResultTab = UUID()
        model.createSelect(for: sheet)
        XCTAssertEqual(model.sql, "SELECT *\nFROM \"Sales Data\"\nLIMIT 1000;")
        XCTAssertEqual(model.selected, "Sales Data")
        XCTAssertNil(model.selectedResultTab)

        model.copyToPasteboard("\"Net Value\"")
        XCTAssertEqual(model.status, "In Zwischenablage kopiert")
    }

    func testSQLFormatterPreservesStructure() {
        let raw = "select Region,sum(Umsatz) as total from Umsaetze where Region = 'Nord' and Umsatz > 100 order by total desc limit 5"
        XCTAssertEqual(SQLFormatter.format(raw), "SELECT Region,\n  sum(Umsatz) AS total\nFROM Umsaetze\nWHERE Region = 'Nord'\n  AND Umsatz > 100\nORDER BY total DESC\nLIMIT 5")
    }
}
