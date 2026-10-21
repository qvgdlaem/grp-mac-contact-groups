import Foundation

enum MembershipState: String {
    case none, some, all
    var symbol: String {
        switch self { case .none: return "square"; case .some: return "minus.square.fill"; case .all: return "checkmark.square.fill" }
    }
    var description: String {
        switch self { case .none: return "None"; case .some: return "Some"; case .all: return "All" }
    }
    static func state(people: [Person], groupID: String) -> Self {
        let count = people.filter { $0.groupIDs.contains(groupID) }.count
        return count == 0 ? .none : count == people.count ? .all : .some
    }
}
struct BulkMembershipChange: Equatable, Sendable {
    let personID: String
    let accountID: String
    let groupID: String
    let member: Bool
}
enum BulkGroups {
    static func toggling(groupID: String, people: [Person], targets: [String: Bool]) -> [String: Bool] {
        var next = targets
        let original = MembershipState.state(people: people, groupID: groupID)
        let displayed = targets[groupID].map { $0 ? MembershipState.all : .none } ?? original
        let target = displayed != .all
        if (target && original == .all) || (!target && original == .none) { next.removeValue(forKey: groupID) }
        else { next[groupID] = target }
        return next
    }

    // Validate the whole request before the first write. Groups only affect cards
    // in their own account; same-named groups in other accounts stay independent.
    static func plan(snapshot: Snapshot, personIDs: Set<String>, targets: [String: Bool]) throws -> [BulkMembershipChange] {
        let people = snapshot.people.filter { personIDs.contains($0.id) }
        guard !people.isEmpty, Set(people.map(\.id)) == personIDs else { throw failure("A selected contact is no longer available. Refresh and select again.") }
        var changes: [BulkMembershipChange] = []
        for id in targets.keys.sorted() {
            guard let group = snapshot.groups.first(where: { $0.id == id }) else { throw failure("A selected group is no longer available. Reopen bulk Groups.") }
            let eligible = people.filter { $0.accountID == group.accountID }
            guard !eligible.isEmpty else { throw failure("This group belongs to another account. Reopen bulk Groups.") }
            for person in eligible.sorted(by: { $0.id < $1.id }) where person.groupIDs.contains(id) != targets[id]! {
                changes.append(.init(personID: person.id, accountID: person.accountID, groupID: id, member: targets[id]!))
            }
        }
        return changes
    }
    static func failure(_ text: String) -> NSError {
        NSError(domain: "GRP.Bulk", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
