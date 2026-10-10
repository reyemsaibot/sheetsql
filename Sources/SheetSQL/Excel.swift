import Foundation

struct Sheet: Identifiable, Sendable {
    var id: String { name }
    var workbookID = UUID()
    let name: String
    let source: String
    let sourceURL: URL?
    let columns: [String]
    let rows: [[Cell]]
    init(workbookID: UUID = UUID(), name: String, source: String, sourceURL: URL? = nil, columns: [String], rows: [[Cell]]) {
        self.workbookID = workbookID; self.name = name; self.source = source; self.sourceURL = sourceURL; self.columns = columns; self.rows = rows
    }
}
enum Cell: Sendable, Equatable {
    case text(String), number(Double), null
    var display: String {
        switch self {
        case .text(let s): s
        case .number(let n): n.formatted(.number.grouping(.never).precision(.fractionLength(0...10)))
        case .null: ""
        }
    }
}
struct AppError: LocalizedError { let message: String; var errorDescription: String? { message } }
final class XMLTree: NSObject, XMLParserDelegate {
    final class Node {
        let tag: String; let attributes: [String: String]
        var text = ""; var children: [Node] = []
        init(_ tag: String, _ attributes: [String: String]) { self.tag = tag; self.attributes = attributes }
        func all(_ tag: String) -> [Node] { children.flatMap { ($0.tag == tag ? [$0] : []) + $0.all(tag) } }
        var content: String { text + children.map(\.content).joined() }
    }
    var root = Node("root", [:]); var stack: [Node] = []
    static func parse(_ data: Data) throws -> Node {
        let delegate = XMLTree(); delegate.stack = [delegate.root]
        let parser = XMLParser(data: data); parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw AppError(message: "Die Excel-XML-Daten sind beschädigt.") }
        return delegate.root
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let node = Node(name.components(separatedBy: ":").last!, attributes)
        stack.last?.children.append(node); stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) { stack.removeLast() }
}
enum Excel {
    static func member(_ path: String, in url: URL, optional: Bool = false) throws -> Data {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, path]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            if optional { return Data("<empty/>".utf8) }
            throw AppError(message: "Die Datei kann nicht gelesen werden. Bitte eine unverschlüsselte .xlsx-Datei verwenden.")
        }
        guard data.count < 150_000_000 else { throw AppError(message: "Dieses Arbeitsblatt ist für die erste Version zu groß (150 MB XML).") }
        return data
    }
    static func read(_ url: URL) throws -> [Sheet] {
        guard ["xlsx", "xlsm"].contains(url.pathExtension.lowercased()) else { throw AppError(message: "Bitte .xlsx oder .xlsm verwenden. Alte .xls-Dateien zuerst in Excel konvertieren.") }
        let book = try XMLTree.parse(member("xl/workbook.xml", in: url))
        let relations = try XMLTree.parse(member("xl/_rels/workbook.xml.rels", in: url))
        let shared = try XMLTree.parse(member("xl/sharedStrings.xml", in: url, optional: true)).all("si").map(\.content)
        let styles = try XMLTree.parse(member("xl/styles.xml", in: url, optional: true))
        let customFormats = Dictionary(uniqueKeysWithValues: styles.all("numFmt").compactMap { node -> (String, String)? in
            guard let id = node.attributes["numFmtId"], let code = node.attributes["formatCode"] else { return nil }; return (id, code)
        })
        let dateStyles = (styles.all("cellXfs").first?.children ?? []).map { node in
            let id = node.attributes["numFmtId"] ?? "0"
            if let n = Int(id), (14...22).contains(n) || (45...47).contains(n) { return true }
            let code = (customFormats[id] ?? "").replacingOccurrences(of: "\"[^\"]*\"|\\\\.", with: "", options: .regularExpression).lowercased()
            return code.contains("yy") || code.contains("dd") || code.contains("hh")
        }
        let date1904 = ["1", "true"].contains(book.all("workbookPr").first?.attributes["date1904"] ?? "")
        let workbookID = UUID()
        var result: [Sheet] = []
        for sheet in book.all("sheet") {
            guard let name = sheet.attributes["name"], let rid = sheet.attributes["r:id"],
                  let relation = relations.all("Relationship").first(where: { $0.attributes["Id"] == rid }),
                  let target = relation.attributes["Target"], relation.attributes["TargetMode"] != "External" else { continue }
            let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
            let xml = try XMLTree.parse(member(path, in: url))
            var rows: [[Cell]] = []
            for row in xml.all("row") {
                var values: [Cell] = []
                for cell in row.children where cell.tag == "c" {
                    let letters = (cell.attributes["r"] ?? "").prefix(while: { $0.isLetter })
                    let index = letters.utf8.reduce(0) { $0 * 26 + Int($1) - 64 } - 1
                    guard index >= 0 && index < 16_384 else { continue }
                    while values.count <= index { values.append(.null) }
                    let value = cell.all("v").first?.content ?? ""
                    switch cell.attributes["t"] ?? "n" {
                    case "s": values[index] = Int(value).flatMap { shared.indices.contains($0) ? .text(shared[$0]) : nil } ?? .null
                    case "inlineStr": values[index] = .text(cell.all("is").first?.content ?? "")
                    case "b": values[index] = .number(value == "1" ? 1 : 0)
                    case "str", "e", "d": values[index] = .text(value)
                    default:
                        if let number = Double(value), number.isFinite {
                            let style = Int(cell.attributes["s"] ?? "0") ?? 0
                            if dateStyles.indices.contains(style), dateStyles[style] {
                                let serial = date1904 ? number + 1462 : (number < 60 ? number + 1 : number)
                                let date = Date(timeIntervalSince1970: (serial - 25569) * 86400)
                                values[index] = .text(date.ISO8601Format())
                            } else { values[index] = .number(number) }
                        }
                    }
                }
                if values.contains(where: { $0 != .null }) { rows.append(values) }
            }
            guard let header = rows.first else { continue }
            let width = rows.map(\.count).max() ?? 0
            var used = Set<String>()
            let columns = (0..<width).map { index -> String in
                let raw = index < header.count ? header[index].display.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let base = raw.isEmpty ? "Spalte_\(index + 1)" : raw
                var name = base; var n = 2
                while used.contains(name.lowercased()) { name = "\(base)_\(n)"; n += 1 }
                used.insert(name.lowercased()); return name
            }
            result.append(Sheet(workbookID: workbookID, name: name, source: url.lastPathComponent, sourceURL: url, columns: columns, rows: rows.dropFirst().map { $0 + Array(repeating: .null, count: width - $0.count) }))
        }
        guard !result.isEmpty else { throw AppError(message: "Keine Arbeitsblätter mit Daten gefunden.") }
        return result
    }
}
