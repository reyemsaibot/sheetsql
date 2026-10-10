import XCTest
@testable import SheetSQL

final class SheetSQLTests: XCTestCase {
    func testQueriesPreserveTextAndJoin() async throws {
        let db = Database()
        let sheets = try await db.add([
            Sheet(name: "Order Details", source: "test", columns: ["Code", "Amount"], rows: [[.text("001"), .number(12)], [.text("001"), .number(8)], [.null, .number(3)]]),
            Sheet(name: "Products", source: "test", columns: ["Code", "Name"], rows: [[.text("001"), .text("Desk")]])])
        XCTAssertEqual(sheets.count, 2)
        let result = try await db.query("SELECT p.Name, o.Code, SUM(o.Amount) FROM \"Order Details\" o JOIN Products p ON p.Code = o.Code GROUP BY p.Name, o.Code;")
        XCTAssertEqual(result.rows, [["Desk", "001", "20.0"]])
        for sql in ["DELETE FROM Products", "DROP TABLE Products", "ATTACH DATABASE '/tmp/no.db' AS x", "PRAGMA user_version = 1", "SELECT 1; SELECT 2"] {
            do { _ = try await db.query(sql); XCTFail("Should reject: \(sql)") } catch { }
        }
        let again = try await db.query("SELECT COUNT(*) FROM Products")
        XCTAssertEqual(again.rows, [["1"]])
        await db.close()
    }
    func testNamesLimitsAndCSV() async throws {
        let db = Database()
        let original = Sheet(name: "Data", source: "test", columns: ["Text"], rows: [[.text("a,\"b\"\nc")]])
        let added = try await db.add([original, original])
        XCTAssertEqual(added.map(\.name), ["Data", "Data_2"])
        let csv = try await db.query("SELECT * FROM Data")
        XCTAssertEqual(csv.csv, "\"Text\"\r\n\"a,\"\"b\"\"\nc\"")
        let result = try await db.query("WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<10002) SELECT x FROM n")
        XCTAssertTrue(result.truncated); XCTAssertEqual(result.rows.count, 10000)
        await db.close()
    }
    func testXLSXImport() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let parts = [
            "xl/workbook.xml": "<workbook xmlns:r='urn:r'><sheets><sheet name='Sales' r:id='rId1'/></sheets></workbook>",
            "xl/_rels/workbook.xml.rels": "<Relationships><Relationship Id='rId1' Target='worksheets/sheet1.xml'/></Relationships>",
            "xl/sharedStrings.xml": "<sst><si><t>Code</t></si><si><r><t>00</t></r><r><t>1</t></r></si></sst>",
            "xl/styles.xml": "<styleSheet><cellXfs><xf numFmtId='0'/><xf numFmtId='14'/></cellXfs></styleSheet>",
            "xl/worksheets/sheet1.xml": "<worksheet><sheetData><row r='1'><c r='A1' t='s'><v>0</v></c><c r='B1' t='inlineStr'><is><t>Code</t></is></c><c r='D1' t='inlineStr'><is><t>Date</t></is></c></row><row r='2'><c r='A2' t='s'><v>1</v></c><c r='B2'><f>3+4</f><v>7</v></c><c r='D2' s='1'><v>25569</v></c></row></sheetData></worksheet>"
        ]
        for (path, content) in parts { try content.write(to: dir.appendingPathComponent(path), atomically: true, encoding: .utf8) }
        let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip"); zip.currentDirectoryURL = dir
        zip.arguments = ["-qr", "fixture.xlsx", "xl"]; try zip.run(); zip.waitUntilExit()
        let sheets = try Excel.read(dir.appendingPathComponent("fixture.xlsx"))
        XCTAssertEqual(sheets[0].columns, ["Code", "Code_2", "Spalte_3", "Date"])
        XCTAssertEqual(sheets[0].rows[0], [.text("001"), .number(7), .null, .text("1970-01-01T00:00:00Z")])
    }
}
