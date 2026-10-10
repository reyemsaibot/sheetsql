import Foundation

enum ResultFilter: Equatable {
    case equals(String?), excludes(String?), contains(String)
    func matches(_ value: String?) -> Bool {
        switch self {
        case .equals(let expected): return value == expected
        case .excludes(let excluded): return value != excluded
        case .contains(let fragment): return value?.localizedCaseInsensitiveContains(fragment) ?? false
        }
    }
    var label: String {
        switch self {
        case .equals(let value): return "= \(value.map { "\"\($0)\"" } ?? "NULL")"
        case .excludes(let value): return "≠ \(value.map { "\"\($0)\"" } ?? "NULL")"
        case .contains(let value): return "enthält \"\(value)\""
        }
    }
}
struct ResultPresentation {
    var filters: [Int: ResultFilter] = [:]
    var sortColumn: Int?
    var ascending = true
    var additionalSortColumns: [Int: Bool] = [:]
    var searchText = ""
    var isActive: Bool { !filters.isEmpty || sortColumn != nil || !additionalSortColumns.isEmpty || !searchText.isEmpty }
    func applying(to result: QueryResult) -> QueryResult {
        var output = result
        var indexed = result.rows.enumerated().filter { _, row in
            let filtersMatch = filters.allSatisfy { column, filter in row.indices.contains(column) && filter.matches(row[column]) }
            let searchMatch = searchText.isEmpty || row.contains { $0?.localizedCaseInsensitiveContains(searchText) ?? false }
            return filtersMatch && searchMatch
        }
        var sortKeys: [(Int, Bool)] = []
        if let column = sortColumn, result.columns.indices.contains(column) { sortKeys.append((column, ascending)) }
        sortKeys += additionalSortColumns
            .filter { result.columns.indices.contains($0.key) && $0.key != sortColumn }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
        if !sortKeys.isEmpty {
            indexed.sort { lhs, rhs in
                for (column, direction) in sortKeys {
                    let a = lhs.element[column], b = rhs.element[column]
                    let order: ComparisonResult
                    if a == b { order = .orderedSame }
                    else if a == nil { order = .orderedAscending }
                    else if b == nil { order = .orderedDescending }
                    else if result.numericColumns.contains(column), let x = Double(a!), let y = Double(b!) {
                        order = x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame
                    } else { order = a!.localizedStandardCompare(b!) }
                    if order != .orderedSame { return direction ? order == .orderedAscending : order == .orderedDescending }
                }
                return lhs.offset < rhs.offset
            }
        }
        output.rows = indexed.map(\.element)
        return output
    }
}
