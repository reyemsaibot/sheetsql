import Foundation

struct WorkbookGroup: Identifiable {
    let id: UUID
    let source: String
    var sheets: [Sheet]
}
