import SwiftUI
import AppKit

private final class ActionMenuItem: NSMenuItem {
    let perform: @MainActor () -> Void
    init(_ title: String, action: @escaping @MainActor () -> Void) {
        perform = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("Not used") }
    @MainActor @objc private func invoke() { perform() }
}
private final class ResultTable: NSTableView {
    var contextMenu: ((Int, Int) -> NSMenu?)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point), column = column(at: point)
        guard row >= 0, column > 0 else { return nil }
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        return contextMenu?(row, column - 1)
    }
}
private final class ResultCell: NSTextField {
    weak var table: NSTableView?
    override func menu(for event: NSEvent) -> NSMenu? { table?.menu(for: event) }
}
struct ResultGrid: NSViewRepresentable {
    let result: QueryResult
    @Binding var presentation: ResultPresentation
    func makeCoordinator() -> Coordinator { Coordinator(presentation: $presentation) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let table = ResultTable(); table.usesAlternatingRowBackgroundColors = true; table.rowHeight = 28
        table.gridStyleMask = [.solidVerticalGridLineMask]; table.columnAutoresizingStyle = .noColumnAutoresizing
        table.dataSource = context.coordinator; table.delegate = context.coordinator
        table.contextMenu = { [weak coordinator = context.coordinator] row, column in coordinator?.cellMenu(row: row, column: column) }
        scroll.documentView = table; return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.result = result
        context.coordinator.presentation = $presentation
        if table.tableColumns.map(\.identifier.rawValue) != (0...result.columns.count).map(String.init) {
            for column in table.tableColumns { table.removeTableColumn(column) }
            for index in 0...result.columns.count {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
                column.width = index == 0 ? 55 : 170; column.minWidth = 45
                table.addTableColumn(column)
            }
        }
        for (index, column) in table.tableColumns.enumerated() {
            if index == 0 { column.title = "#"; continue }
            let key = index - 1
            let sort = presentation.sortColumn == key ? (presentation.ascending ? " ↑" : " ↓") : ""
            let secondary = presentation.additionalSortColumns[key].map { $0 ? " ↑²" : " ↓²" } ?? ""
            column.title = result.columns[key] + sort + secondary + (presentation.filters[key] == nil ? " ▾" : " ⏷•")
        }
        table.deselectAll(nil)
        table.reloadData()
    }
    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var result = QueryResult()
        var presentation: Binding<ResultPresentation>
        init(presentation: Binding<ResultPresentation>) { self.presentation = presentation }
        func numberOfRows(in tableView: NSTableView) -> Int { result.rows.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let index = Int(tableColumn?.identifier.rawValue ?? "0") ?? 0
            let value = index == 0 ? String(row + 1) : result.rows[row][index - 1]
            let text = ResultCell(labelWithString: value ?? "NULL")
            text.table = tableView
            text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            text.textColor = value == nil || index == 0 ? .secondaryLabelColor : .labelColor
            text.lineBreakMode = .byTruncatingTail; text.isSelectable = true; text.toolTip = value
            return text
        }
        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
            guard let index = Int(tableColumn.identifier.rawValue), index > 0, let header = tableView.headerView else { return }
            let menu = columnMenu(index - 1)
            let rect = header.headerRect(ofColumn: index)
            menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.maxY), in: header)
        }
        func columnMenu(_ column: Int) -> NSMenu {
            let menu = NSMenu(title: result.columns[column])
            menu.addItem(ActionMenuItem("Aufsteigend sortieren") { [self] in
                presentation.wrappedValue.sortColumn = column; presentation.wrappedValue.ascending = true
            })
            menu.addItem(ActionMenuItem("Absteigend sortieren") { [self] in
                presentation.wrappedValue.sortColumn = column; presentation.wrappedValue.ascending = false
            })
            menu.addItem(ActionMenuItem("Sortierung entfernen") { [self] in presentation.wrappedValue.sortColumn = nil })
            menu.addItem(ActionMenuItem("Als weitere Sortierung aufsteigend") { [self] in presentation.wrappedValue.additionalSortColumns[column] = true })
            menu.addItem(ActionMenuItem("Als weitere Sortierung absteigend") { [self] in presentation.wrappedValue.additionalSortColumns[column] = false })
            menu.addItem(ActionMenuItem("Weitere Sortierung entfernen") { [self] in presentation.wrappedValue.additionalSortColumns.removeValue(forKey: column) })
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem("Spalte filtern …") { [self] in showFilter(column) })
            menu.addItem(ActionMenuItem("Nur NULL-Werte") { [self] in presentation.wrappedValue.filters[column] = .equals(nil) })
            menu.addItem(ActionMenuItem("NULL-Werte ausschließen") { [self] in presentation.wrappedValue.filters[column] = .excludes(nil) })
            menu.addItem(ActionMenuItem("Spaltenfilter entfernen") { [self] in presentation.wrappedValue.filters.removeValue(forKey: column) })
            return menu
        }
        func cellMenu(row: Int, column: Int) -> NSMenu? {
            guard result.rows.indices.contains(row), result.columns.indices.contains(column) else { return nil }
            let value = result.rows[row][column]
            let menu = NSMenu()
            let title = NSMenuItem(title: "\(result.columns[column]): \(value ?? "NULL")", action: nil, keyEquivalent: "")
            title.isEnabled = false; menu.addItem(title)
            menu.addItem(ActionMenuItem("Nur diesen Wert anzeigen") { [self] in presentation.wrappedValue.filters[column] = .equals(value) })
            menu.addItem(ActionMenuItem("Diesen Wert ausschließen") { [self] in presentation.wrappedValue.filters[column] = .excludes(value) })
            menu.addItem(ActionMenuItem("Spalte filtern …") { [self] in showFilter(column) })
            menu.addItem(ActionMenuItem("Spaltenfilter entfernen") { [self] in presentation.wrappedValue.filters.removeValue(forKey: column) })
            return menu
        }
        private func showFilter(_ column: Int) {
            let alert = NSAlert()
            alert.messageText = "\(result.columns[column]) filtern"
            alert.informativeText = "Filter verschiedener Spalten werden mit UND kombiniert. Der Filter gilt für das geladene SQL-Ergebnis."
            alert.addButton(withTitle: "Anwenden"); alert.addButton(withTitle: "Abbrechen")
            let panel = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 72))
            let mode = NSPopUpButton(frame: NSRect(x: 0, y: 42, width: 340, height: 26))
            mode.addItems(withTitles: ["Enthält (Groß-/Kleinschreibung ignorieren)", "Ist gleich (exakt)", "Ist ungleich (exakt)"])
            let input = NSTextField(frame: NSRect(x: 0, y: 4, width: 340, height: 26))
            input.placeholderString = "Filterwert"
            if let filter = presentation.wrappedValue.filters[column] {
                switch filter {
                case .contains(let value): input.stringValue = value
                case .equals(let value): mode.selectItem(at: 1); input.stringValue = value ?? ""
                case .excludes(let value): mode.selectItem(at: 2); input.stringValue = value ?? ""
                }
            }
            panel.addSubview(mode); panel.addSubview(input); alert.accessoryView = panel
            alert.window.initialFirstResponder = input
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            switch mode.indexOfSelectedItem {
            case 1: presentation.wrappedValue.filters[column] = .equals(input.stringValue)
            case 2: presentation.wrappedValue.filters[column] = .excludes(input.stringValue)
            default: presentation.wrappedValue.filters[column] = .contains(input.stringValue)
            }
        }
    }
}
