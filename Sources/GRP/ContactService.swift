import Contacts
import Foundation

// All Contacts operations run on this actor, away from the UI thread.
actor ContactService {
    private var store = CNContactStore()
    private let keys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor
    ]

    func connect() async throws -> Snapshot {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .denied, .restricted:
            throw ContactFailure.permission
        case .notDetermined:
            guard try await store.requestAccess(for: .contacts) else { throw ContactFailure.permission }
        default:
            break // Existing authorized access does not need another request.
        }
        return try snapshot()
    }

    // Never use unifiedContact(withIdentifier:) for mutation: its identifier may
    // refer to a linked aggregate instead of the account-specific card selected.
    private func contacts(matching predicate: NSPredicate, fetching requestedKeys: [CNKeyDescriptor]? = nil) throws -> [CNContact] {
        let request = CNContactFetchRequest(keysToFetch: requestedKeys ?? keys)
        request.predicate = predicate
        request.unifyResults = false
        var result: [CNContact] = []
        try store.enumerateContacts(with: request) { contact, _ in result.append(contact) }
        return result
    }

    private func exactContact(_ id: String) throws -> CNContact {
        let found = try contacts(matching: CNContact.predicateForContacts(withIdentifiers: [id]))
        guard found.count == 1, let card = found.first, card.identifier == id else {
            throw ContactFailure.unavailable
        }
        return card
    }

    private func accountID(for contactID: String) throws -> String {
        let containers = try store.containers(matching:
            CNContainer.predicateForContainerOfContact(withIdentifier: contactID))
        guard containers.count == 1, let container = containers.first else { throw ContactFailure.unavailable }
        return container.identifier
    }

    func snapshot() throws -> Snapshot {
        // Discard the store cache when reloading after external/AppleScript writes.
        store = CNContactStore()
        let containers = try store.containers(matching: nil)
        var people: [Person] = []
        var groups: [ContactGroup] = []
        for container in containers {
            let localGroups = try store.groups(matching:
                CNGroup.predicateForGroupsInContainer(withIdentifier: container.identifier))
            var memberships: [String: Set<String>] = [:]
            for group in localGroups {
                groups.append(ContactGroup(id: group.identifier, name: group.name, accountID: container.identifier))
                for member in try contacts(matching: CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)) {
                    memberships[member.identifier, default: []].insert(group.identifier)
                }
            }
            for card in try contacts(matching:
                CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)) {
                let personalName = [card.givenName, card.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                people.append(Person(id: card.identifier,
                    name: personalName.isEmpty ? (card.organizationName.isEmpty ? "Unnamed contact" : card.organizationName) : personalName,
                    accountID: container.identifier, account: container.name, company: card.organizationName,
                    emails: card.emailAddresses.map { $0.value as String },
                    phones: card.phoneNumbers.map { $0.value.stringValue },
                    groupIDs: memberships[card.identifier, default: []]))
            }
        }
        return Snapshot(people: people.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                        groups: groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                        accounts: containers.map { Account(id: $0.identifier, name: $0.name) })
    }

    func details(contactID: String) throws -> CardDetails {
        let found = try contacts(matching: CNContact.predicateForContacts(withIdentifiers: [contactID]),
                                 fetching: ContactFields.detailKeys)
        guard found.count == 1, let card = found.first, card.identifier == contactID else {
            throw ContactFailure.unavailable
        }
        return ContactFields.details(card)
    }

    func setMembership(contactID: String, groupID: String, member: Bool) async throws -> Snapshot {
        _ = try exactContact(contactID)
        let groups = try store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [groupID]))
        guard groups.count == 1, groups.first?.identifier == groupID else { throw ContactFailure.unavailable }
        let contactAccount = try accountID(for: contactID)
        let groupAccounts = try store.containers(matching: CNContainer.predicateForContainerOfGroup(withIdentifier: groupID))
        guard groupAccounts.count == 1, groupAccounts.first?.identifier == contactAccount else {
            throw ContactFailure.wrongAccount
        }
        return try await MembershipUpdate.apply(contactID: contactID, groupID: groupID, accountID: contactAccount, member: member,
            write: { try await ContactsAutomation.changeMembership(contactID: contactID, groupID: groupID, member: member) },
            read: { try self.snapshot() })
    }

    // Called AFTER membership saves, immediately before showing confirmation.
    // The preview is never reused from a previously opened field editor.
    func previewDeletion(contactID: String) throws -> DeletePreview {
        guard let before = store.currentHistoryToken else { throw ContactFailure.noHistory }
        let card = try exactContact(contactID)
        let containers = try store.containers(matching:
            CNContainer.predicateForContainerOfContact(withIdentifier: contactID))
        guard containers.count == 1, let container = containers.first else { throw ContactFailure.unavailable }
        let name = [card.givenName, card.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let preview = DeletePreview(id: card.identifier,
            name: name.isEmpty ? (card.organizationName.isEmpty ? "Unnamed contact" : card.organizationName) : name,
            account: container.name, historyToken: before)
        try DeleteGuard.validate(preview, exactID: card.identifier, currentToken: store.currentHistoryToken)
        return preview
    }

    func delete(_ preview: DeletePreview) throws -> Snapshot {
        let card = try exactContact(preview.id)
        try DeleteGuard.validate(preview, exactID: card.identifier, currentToken: store.currentHistoryToken)
        let request = CNSaveRequest()
        request.delete(card.mutableCopy() as! CNMutableContact)
        try store.execute(request)
        let remaining = try contacts(matching: CNContact.predicateForContacts(withIdentifiers: [preview.id]))
        guard !remaining.contains(where: { $0.identifier == preview.id }) else { throw ContactFailure.verification }
        return try snapshot()
    }
}
