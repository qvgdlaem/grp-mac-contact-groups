import Foundation

@main
struct GroupFilterChecks {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fatalError(message) }
    }
    static func main() {
        let cards: [String: Set<String>] = [
            "none": [], "a": ["A"], "b": ["B"], "ab": ["A", "B"],
            "ac": ["A", "C"], "abc": ["A", "B", "C"], "d": ["D"]
        ]
        func results(_ filter: GroupFilter) -> Set<String> { Set(cards.filter { filter.matches($0.value) }.keys) }
        var query = GroupFilter()
        require(results(query) == Set(cards.keys), "An empty filter must not hide contacts")
        query.included = ["A", "B"]
        require(results(query) == ["ab", "abc"], "A AND B")
        query.excluded = ["C"]
        require(results(query) == ["ab"], "A AND B AND NOT C")
        query.mode = .any; query.excluded = []
        require(results(query) == ["a", "b", "ab", "ac", "abc"], "A OR B permits other memberships")
        query.noOtherGroups = true
        require(results(query) == ["a", "b", "ab"], "(A OR B) AND no other groups")
        query.mode = .all
        require(results(query) == ["ab"], "A AND B AND no others is the exact set")
        query = GroupFilter(excluded: ["C"])
        require(results(query) == ["none", "a", "b", "ab", "d"], "Exclusion only includes ungrouped contacts")
        query.noOtherGroups = true
        require(results(query) == ["none"], "No included groups plus No other groups means ungrouped only")
        query = GroupFilter(included: ["A"], excluded: ["A"])
        require(results(query).isEmpty, "Exclusion always wins if supplied contradictory data")
        query.setRole(.include, for: "A")
        require(query.included == ["A"] && query.excluded.isEmpty, "Include clears the exclusion for the same group")
        query.setRole(.exclude, for: "A")
        require(query.excluded == ["A"] && query.included.isEmpty, "Exclude clears the inclusion")
        query.setRole(.ignore, for: "A")
        require(!query.isActive, "Ignore removes the rule entirely")
        query = GroupFilter(included: ["missing"])
        require(results(query).isEmpty, "Do not silently drop unavailable included groups")
        let groups: [ContactGroup] = [
            .init(id: "A", name: "Friends", accountID: "cloud"), .init(id: "B", name: "Friends", accountID: "work"),
            .init(id: "C", name: "Archived", accountID: "cloud")
        ]
        let accounts = [Account(id: "cloud", name: "iCloud"), Account(id: "work", name: "Work")]
        query = GroupFilter(included: ["A", "B"], excluded: ["C"], mode: .any, noOtherGroups: true)
        let summary = query.summary(groups: groups, accounts: accounts)
        require(summary.contains("Friends (iCloud)") && summary.contains("Friends (Work)") && summary.contains("excluding") && summary.contains("no other groups"), "Summarize duplicate names with account identity and explicit rules")
        let alex = Snapshot.demo.people[0]
        let demoFilter = GroupFilter(included: ["demo-friends", "demo-work"])
        let list = Snapshot.demo.people(in: .all, search: "Studio").filter { demoFilter.matches($0.groupIDs) }
        require(list.map(\.id) == [alex.id], "Combine group logic with the normal text search")
        require(Snapshot.demo.people(in: .all, accountID: "other").filter { demoFilter.matches($0.groupIDs) }.isEmpty, "Preserve account filtering")
        print("Passed AND, OR, NOT, exclusive membership, empty/ungrouped filters, conflicting rules, missing groups, account names and text/account composition checks (synthetic data only).")
    }
}
