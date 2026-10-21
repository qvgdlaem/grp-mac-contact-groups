import Foundation

actor BulkStore {
    var snapshot = Snapshot.demo
    var calls: [BulkMembershipChange] = []
    let failAt: Int?
    init(failAt: Int? = nil) { self.failAt = failAt }
    func write(_ person: String, _ group: String, _ member: Bool) throws -> Snapshot {
        calls.append(.init(personID: person, accountID: "demo", groupID: group, member: member))
        if calls.count == failAt { throw BulkGroups.failure("Synthetic provider failure") }
        var people = snapshot.people
        let i = people.firstIndex { $0.id == person }!
        if member { people[i].groupIDs.insert(group) } else { people[i].groupIDs.remove(group) }
        snapshot = Snapshot(people: people, groups: snapshot.groups, accounts: snapshot.accounts)
        return snapshot
    }
}
@main
@MainActor
struct BulkGroupsChecks {
    static func require(_ condition: Bool, _ text: String) { if !condition { fatalError(text) } }
    static func main() async throws {
        let snapshot = Snapshot.demo
        let ids = Set(snapshot.people.map(\.id))
        require(MembershipState.state(people: snapshot.people, groupID: "demo-friends") == .some, "Mixed membership")
        require(MembershipState.state(people: [snapshot.people[0]], groupID: "demo-work") == .all, "All membership")
        require(MembershipState.state(people: snapshot.people, groupID: "missing") == .none, "None membership")
        let toAll = BulkGroups.toggling(groupID: "demo-friends", people: snapshot.people, targets: [:])
        require(toAll["demo-friends"] == true, "Click partial to apply to all")
        let toNone = BulkGroups.toggling(groupID: "demo-friends", people: snapshot.people, targets: toAll)
        require(toNone["demo-friends"] == false, "Click checked to remove from all")
        let emptyToggle = BulkGroups.toggling(groupID: "unused", people: snapshot.people, targets: [:])
        require(BulkGroups.toggling(groupID: "unused", people: snapshot.people, targets: emptyToggle).isEmpty, "Reverting untouched empty state removes staged target")
        let plan = try BulkGroups.plan(snapshot: snapshot, personIDs: ids, targets: ["demo-friends": true, "demo-family": false])
        require(plan.count == 3 && plan.filter(\.member).count == 2, "Skip existing desired states and leave untouched groups alone")
        let foreign = Person(id: "foreign", name: "Other", accountID: "other", account: "Other", company: "", emails: [], phones: [], groupIDs: [])
        let mixed = Snapshot(people: snapshot.people + [foreign], groups: snapshot.groups, accounts: snapshot.accounts)
        let isolated = try BulkGroups.plan(snapshot: mixed, personIDs: ids.union(["foreign"]), targets: ["demo-friends": true])
        require(isolated.count == 2 && !isolated.contains { $0.personID == "foreign" }, "Never apply a group across accounts")
        do { _ = try BulkGroups.plan(snapshot: snapshot, personIDs: ids.union(["gone"]), targets: [:]); fatalError("Missing selection must fail") } catch {}
        do { _ = try BulkGroups.plan(snapshot: snapshot, personIDs: ids, targets: ["gone": true]); fatalError("Missing group must fail") } catch {}
        let store = BulkStore()
        let model = Model(membershipWriter: { try await store.write($0, $1, $2) })
        model.live = true
        let success = await model.applyBulkMembership(personIDs: ids, targets: ["demo-friends": true, "demo-family": false])
        require(success && !model.busy && model.undo == nil, "Release state; don't offer single-write undo for a batch")
        require(model.snapshot.people.allSatisfy { $0.groupIDs.contains("demo-friends") && !$0.groupIDs.contains("demo-family") }, "Every desired change verified")
        require(model.snapshot.people[0].groupIDs.contains("demo-work"), "Untouched group preserved")
        let calls = await store.calls
        require(calls.count == 3, "No redundant mutations")
        let failing = BulkStore(failAt: 2)
        let stopped = Model(membershipWriter: { try await failing.write($0, $1, $2) })
        stopped.live = true
        let failure = await stopped.applyBulkMembership(personIDs: ids, targets: ["demo-friends": true, "demo-work": true])
        let failedCalls = await failing.calls
        require(!failure && failedCalls.count == 2 && !stopped.busy, "Stop at first failure, never replay writes")
        require(stopped.bulkReport?.contains("1 of 4") == true, "Clearly report partial success")
        require(stopped.snapshot.people.first { $0.id == "demo-jamie" }!.groupIDs.contains("demo-friends"), "Keep first confirmed change")
        let noop = Model(membershipWriter: { _, _, _ in snapshot })
        noop.live = true
        let verified = await noop.applyBulkMembership(personIDs: ids, targets: ["demo-friends": true])
        require(!verified && noop.bulkReport?.contains("0 of 2") == true, "Silent no-op never counted as saved")
        let sample = Model()
        let demo = await sample.applyBulkMembership(personIDs: ids, targets: ["demo-work": true])
        require(demo && sample.snapshot.people.allSatisfy { $0.groupIDs.contains("demo-work") }, "Sample mode remains local")
        print("Passed bulk tri-state, minimal plan, account isolation, verification, partial failure, no-op and demo checks (synthetic only).")
    }
}
