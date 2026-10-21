import Foundation

enum GroupMatchMode: String, CaseIterable, Identifiable, Sendable {
    case all, any
    var id: String { rawValue }
    var title: String { self == .all ? "All (AND)" : "Any (OR)" }
}
enum GroupFilterRole: String, CaseIterable, Identifiable {
    case ignore, include, exclude
    var id: String { rawValue }
    var title: String {
        switch self { case .ignore: return "Ignore"; case .include: return "Include"; case .exclude: return "Exclude" }
    }
}

struct GroupFilter: Equatable, Sendable {
    var included: Set<String> = []
    var excluded: Set<String> = []
    var mode: GroupMatchMode = .all
    var noOtherGroups = false
    var isActive: Bool { !included.isEmpty || !excluded.isEmpty || noOtherGroups }

    func role(for id: String) -> GroupFilterRole {
        if excluded.contains(id) { return .exclude }
        return included.contains(id) ? .include : .ignore
    }
    mutating func setRole(_ role: GroupFilterRole, for id: String) {
        included.remove(id); excluded.remove(id)
        if role == .include { included.insert(id) }
        if role == .exclude { excluded.insert(id) }
    }
    func matches(_ memberships: Set<String>) -> Bool {
        guard memberships.isDisjoint(with: excluded) else { return false }
        if !included.isEmpty {
            switch mode {
            case .all: guard included.isSubset(of: memberships) else { return false }
            case .any: guard !memberships.isDisjoint(with: included) else { return false }
            }
        }
        return !noOtherGroups || memberships.isSubset(of: included)
    }
    func summary(groups: [ContactGroup], accounts: [Account]) -> String {
        func names(_ ids: Set<String>) -> String {
            ids.map { id -> String in
                guard let group = groups.first(where: { $0.id == id }) else { return "Unavailable group" }
                let duplicate = groups.contains { $0.id != id && $0.name == group.name }
                let account = accounts.first { $0.id == group.accountID }?.name ?? "Unknown account"
                return duplicate ? "\(group.name) (\(account))" : group.name
            }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { "“\($0)”" }.joined(separator: ", ")
        }
        if !isActive { return "No group filter" }
        var parts: [String] = []
        if noOtherGroups && included.isEmpty { parts.append("Ungrouped only") }
        else if !included.isEmpty { parts.append("\(mode == .all ? "All" : "Any") of \(names(included))") }
        else { parts.append("Any contact") }
        if !excluded.isEmpty { parts.append("excluding \(names(excluded))") }
        if noOtherGroups && !included.isEmpty { parts.append("no other groups") }
        return parts.joined(separator: "; ")
    }
}
