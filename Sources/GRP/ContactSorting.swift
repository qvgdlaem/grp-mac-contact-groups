import Foundation

struct CardDates: Equatable, Sendable {
    let created: Date?
    let modified: Date?
    static let demo: [String: CardDates] = [
        "demo-alex": .init(created: Date(timeIntervalSince1970: 1704067200), modified: Date(timeIntervalSince1970: 1735689600)),
        "demo-jamie": .init(created: Date(timeIntervalSince1970: 1719792000), modified: Date(timeIntervalSince1970: 1727740800)),
        "demo-morgan": .init(created: Date(timeIntervalSince1970: 1672531200), modified: Date(timeIntervalSince1970: 1711929600))
    ]
}

enum ContactSort: String, CaseIterable, Identifiable {
    case name, createdNewest, createdOldest, modifiedNewest, modifiedOldest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return "Name (A–Z)"
        case .createdNewest: return "Created · newest first"
        case .createdOldest: return "Created · oldest first"
        case .modifiedNewest: return "Last modified · newest first"
        case .modifiedOldest: return "Last modified · oldest first"
        }
    }
    var usesDates: Bool { self != .name }
    var dateLabel: String { self == .createdNewest || self == .createdOldest ? "Created" : "Modified" }
    func date(for id: String, in dates: [String: CardDates]) -> Date? {
        switch self {
        case .name: return nil
        case .createdNewest, .createdOldest: return dates[id]?.created
        case .modifiedNewest, .modifiedOldest: return dates[id]?.modified
        }
    }
    func sorted(_ people: [Person], dates: [String: CardDates]) -> [Person] {
        people.sorted { left, right in
            if usesDates {
                let a = date(for: left.id, in: dates), b = date(for: right.id, in: dates)
                switch (a, b) {
                case (.some(let a), .some(let b)) where a != b:
                    return self == .createdNewest || self == .modifiedNewest ? a > b : a < b
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
            }
            let comparison = left.name.localizedStandardCompare(right.name)
            return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
        }
    }
}
