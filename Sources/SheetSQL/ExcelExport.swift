import Foundation

enum ExcelExport {
    static func write(_ result: QueryResult, to url: URL) throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("sheetsql-xlsx-(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        try fm.createDirectory(at: directory.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: directory.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: directory.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)
        let files: [(String, String)] = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rootRelationships),
            ("xl/workbook.xml", workbook),
            ("xl/_rels/workbook.xml.rels", workbookRelationships),
            ("xl/worksheets/sheet1.xml", worksheet(result))
        ]
        for (relative, contents) in files {
            let file = directory.appendingPathComponent(relative)
            try contents.data(using: .utf8)!.write(to: file)
        }
        try? fm.removeItem(at: url)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-q", "-r", url.path, "."]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppError(message: "Die Excel-Datei konnte nicht erstellt werden.") }
    }

    private static var contentTypes: String { #"<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>"# }
    private static var rootRelationships: String { #"<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>"# }
    private static var workbook: String { #"<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Ergebnis" sheetId="1" r:id="rId1"/></sheets></workbook>"# }
    private static var workbookRelationships: String { #"<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>"# }
    private static func worksheet(_ result: QueryResult) -> String {
        var rows: [String] = []
        rows.append(row(result.columns.enumerated().map { (index, value) in cell(value, row: 1, column: index + 1, numeric: false) }))
        for (rowIndex, values) in result.rows.enumerated() {
            rows.append(row(values.enumerated().map { (index, value) in cell(value ?? "", row: rowIndex + 2, column: index + 1, numeric: result.numericColumns.contains(index)) }))
        }
        return #"<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>"# + rows.joined() + "</sheetData></worksheet>"
    }
    private static func row(_ cells: [String]) -> String { "<row>" + cells.joined() + "</row>" }
    private static func cell(_ value: String, row: Int, column: Int, numeric: Bool) -> String {
        let ref = columnName(column) + String(row)
        if numeric, Double(value) != nil { return "<c r=\"\(ref)\"><v>\(xml(value))</v></c>" }
        return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(xml(value))</t></is></c>"
    }
    private static func columnName(_ number: Int) -> String { var n = number, output = ""; while n > 0 { n -= 1; output = String(UnicodeScalar(65 + (n % 26))!) + output; n /= 26 }; return output }
    private static func xml(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;") }
}
