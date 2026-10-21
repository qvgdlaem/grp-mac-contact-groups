import Foundation

enum MembershipFailure: LocalizedError {
    case notRetained
    var errorDescription: String? {
        "Apple Contacts did not confirm the requested group membership. Refresh and check the card in Apple Contacts before retrying."
    }
}

enum MembershipUpdate {
    static func matches(_ snapshot: Snapshot, contactID: String, groupID: String, accountID: String, member: Bool) throws -> Bool {
        guard let person = snapshot.people.first(where: { $0.id == contactID }),
              let group = snapshot.groups.first(where: { $0.id == groupID }) else { throw ContactFailure.unavailable }
        guard person.accountID == accountID, group.accountID == accountID else { throw ContactFailure.wrongAccount }
        return person.groupIDs.contains(groupID) == member
    }

    // Write once. Retry only fresh reads while Contacts' two APIs catch up.
    // Never silently replay writes, or invent a new group set in the UI.
    static func apply(contactID: String, groupID: String, accountID: String, member: Bool,
                      write: () async throws -> Void,
                      read: () async throws -> Snapshot,
                      pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(200)) }) async throws -> Snapshot {
        try await write()
        for attempt in 0..<4 {
            let result = try await read()
            if try matches(result, contactID: contactID, groupID: groupID, accountID: accountID, member: member) { return result }
            if attempt < 3 { try await pause() }
        }
        throw MembershipFailure.notRetained
    }
}
