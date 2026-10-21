import Carbon
import Foundation

actor FakeMembershipStore {
    private var snapshots: [Snapshot]
    private(set) var writes = 0
    private(set) var reads = 0
    init(_ snapshots: [Snapshot]) { self.snapshots = snapshots }
    func write() { writes += 1 }
    func read() -> Snapshot {
        let index = min(reads, snapshots.count - 1)
        reads += 1
        return snapshots[index]
    }
}

@main
@MainActor
struct MembershipChecks {
    nonisolated static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fatalError(message) }
    }
    static func removing(_ groupID: String, from personID: String) -> Snapshot {
        var people = Snapshot.demo.people
        let index = people.firstIndex { $0.id == personID }!
        people[index].groupIDs.remove(groupID)
        return Snapshot(people: people, groups: Snapshot.demo.groups, accounts: Snapshot.demo.accounts)
    }
    static func main() async throws {
        let before = Snapshot.demo
        let after = removing("demo-friends", from: "demo-alex")
        let delayed = FakeMembershipStore([before, after])
        let result = try await MembershipUpdate.apply(contactID: "demo-alex", groupID: "demo-friends", accountID: "demo", member: false,
            write: { await delayed.write() }, read: { await delayed.read() }, pause: {})
        require(result.people[0].groupIDs == ["demo-work"], "Remove exactly the requested membership; preserve other groups")
        let writeCount = await delayed.writes
        let readCount = await delayed.reads
        require(writeCount == 1 && readCount == 2, "Retry stale reads without replaying the write")

        let silentNoOp = FakeMembershipStore([before])
        do {
            _ = try await MembershipUpdate.apply(contactID: "demo-alex", groupID: "demo-friends", accountID: "demo", member: false,
                write: { await silentNoOp.write() }, read: { await silentNoOp.read() }, pause: {})
            fatalError("A no-op save must never report success")
        } catch MembershipFailure.notRetained { }
        let noOpWrites = await silentNoOp.writes
        let noOpReads = await silentNoOp.reads
        require(noOpWrites == 1 && noOpReads == 4, "Bound the verification reads")

        do {
            _ = try MembershipUpdate.matches(after, contactID: "demo-alex", groupID: "demo-friends", accountID: "other", member: false)
            fatalError("Wrong-account results must not be accepted")
        } catch ContactFailure.wrongAccount { }
        do {
            _ = try MembershipUpdate.matches(after, contactID: "missing-card", groupID: "demo-friends", accountID: "demo", member: false)
            fatalError("A missing contact is not a successful removal")
        } catch ContactFailure.unavailable { }

        let model = Model(membershipWriter: { _, _, _ in before })
        model.live = true
        model.details = .demo("demo-alex")
        await model.applyMembership(before.people[0], group: before.groups.first { $0.id == "demo-friends" }!, member: false)
        require(model.membershipError != nil && model.error != nil, "Silent no-op must produce an inline error and alert")
        require(model.undo == nil && !model.busy, "Do not record undo for unconfirmed writes; release the busy state")
        require(model.snapshot.people[0].groupIDs == before.people[0].groupIDs, "Do not optimistically remove a chip without confirmation")
        require(model.details != nil, "Keep fields visible during a membership failure")

        let success = Model(membershipWriter: { contact, group, member in
            require(contact == "demo-alex" && group == "demo-friends" && !member, "Send exact removal arguments")
            return after
        })
        success.live = true
        success.details = .demo("demo-alex")
        await success.applyMembership(before.people[0], group: before.groups.first { $0.id == "demo-friends" }!, member: false)
        require(success.membershipError == nil && success.snapshot.people[0].groupIDs == ["demo-work"], "Update chips from verified data")
        require(success.undo?.member == true && !success.busy, "Undo must restore the removed membership")
        require(success.details != nil && success.message == "Removed from Friends", "Keep the card visible and report verified success")
        let lastRemoved = removing("demo-family", from: "demo-morgan")
        require(lastRemoved.people(in: .ungrouped).contains { $0.id == "demo-morgan" }, "Removing the last membership must update Ungrouped")

        for desired in [true, false] {
            let contact = "person\"with\\special\ncharacters:ABPerson"
            let group = "group\"with\\special\ncharacters:ABGroup"
            let event = ContactsAutomation.membershipEvent(contactID: contact, groupID: group, member: desired)
            let args = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!
            require(args.numberOfItems == 3 && args.atIndex(1)?.stringValue == contact && args.atIndex(2)?.stringValue == group,
                "Pass identifiers as exact typed data")
            require(args.atIndex(3)?.descriptorType == DescType(typeBoolean) && args.atIndex(3)?.booleanValue == desired,
                "Pass an actual Apple event Boolean for add/remove")
        }
        print("Passed membership removal, delayed-read verification, silent no-op rejection, account isolation, UI error/undo, last-group and typed-event checks (synthetic data only).")
    }
}
