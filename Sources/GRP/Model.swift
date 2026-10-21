import AppKit
import SwiftUI

struct MembershipUndo {
    let personID: String
    let groupID: String
    let member: Bool
}

@MainActor
final class Model: ObservableObject {
    @Published var snapshot = Snapshot.demo
    @Published var sort: ContactSort = .name
    @Published var cardDates = CardDates.demo
    @Published var datesLoading = false
    @Published var datesError: String?
    @Published var familyColorNumbers = GroupColorLibrary.assigning(families: Snapshot.demo.groups.map { $0.groupFamily.key }, saved: [:])
    @Published var selectedID: String?
    @Published var details: CardDetails?
    @Published var extras: CardExtras?
    @Published var detailsLoading = false
    @Published var detailError: String?
    @Published var extrasError: String?
    @Published var membershipError: String?
    @Published var bulkReport: String?
    @Published var connectionError: String?
    @Published var connecting = false
    @Published var live = false
    @Published var busy = false
    @Published var message = "Sample contacts · Connect Apple Contacts to use your address book"
    @Published var error: String?
    @Published var deletion: DeletePreview?
    @Published var undo: MembershipUndo?
    private let service: ContactService
    private let connectionLoader: @Sendable () async throws -> Snapshot
    private let membershipWriter: @Sendable (String, String, Bool) async throws -> Snapshot
    private let datesLoader: @MainActor () throws -> [String: CardDates]
    private let preferences: UserDefaults?
    private var datesTask: Task<Void, Never>?

    init(connectionLoader: (@Sendable () async throws -> Snapshot)? = nil,
         membershipWriter: (@Sendable (String, String, Bool) async throws -> Snapshot)? = nil,
         datesLoader: (@MainActor () throws -> [String: CardDates])? = nil,
         preferences: UserDefaults? = nil) {
        let service = ContactService()
        self.service = service
        self.datesLoader = datesLoader ?? { try ContactsAutomation.readCardDates() }
        self.preferences = preferences
        self.sort = ContactSort(rawValue: preferences?.string(forKey: "contactSort") ?? "") ?? .name
        self.connectionLoader = connectionLoader ?? { try await service.connect() }
        self.membershipWriter = membershipWriter ?? { try await service.setMembership(contactID: $0, groupID: $1, member: $2) }
    }
    private var detailTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var refreshPending = false
    var selected: Person? { snapshot.people.first { $0.id == selectedID } }

    func colorNumber(for group: ContactGroup) -> Int { familyColorNumbers[group.groupFamily.key] ?? 1 }

    private func updateGroupColors() {
        let saved = live ? preferences?.dictionary(forKey: "groupFamilyColorNumbers") as? [String: Int] ?? [:] : [:]
        familyColorNumbers = GroupColorLibrary.assigning(families: snapshot.groups.map { $0.groupFamily.key }, saved: saved)
        if live { preferences?.set(familyColorNumbers, forKey: "groupFamilyColorNumbers") }
    }

    func changeSort(_ value: ContactSort) {
        sort = value
        preferences?.set(value.rawValue, forKey: "contactSort")
        requestSortDates()
    }

    func requestSortDates() {
        datesTask?.cancel()
        guard sort.usesDates else { datesLoading = false; return }
        guard live else { cardDates = CardDates.demo; datesLoading = false; datesError = nil; return }
        datesTask = Task { await loadSortDates() }
    }

    func loadSortDates() async {
        guard live, sort.usesDates else { return }
        datesLoading = true
        datesError = nil
        // Give SwiftUI a chance to draw the progress state before Automation.
        await Task.yield()
        guard !Task.isCancelled else { return }
        defer { datesLoading = false }
        do {
            let loaded = try datesLoader()
            guard snapshot.people.isEmpty || snapshot.people.contains(where: { loaded[$0.id] != nil }) else {
                throw NSError(domain: "GRP.Dates", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Contacts returned no matching card dates. Refresh and retry."])
            }
            cardDates = loaded
        } catch {
            cardDates = [:]
            datesError = error.localizedDescription
        }
    }

    func connect() {
        Task { await establishConnection() }
    }

    // Kept separate from write operations so connection failures never produce
    // misleading save/delete warnings, and the retry action always re-enables.
    func establishConnection() async {
        guard !busy else { return }
        busy = true
        connecting = true
        connectionError = nil
        message = "Connecting to Apple Contacts…"
        defer { connecting = false; finishOperation() }
        do {
            let result = try await connectionLoader()
            snapshot = result
            live = true
            cardDates = [:]
            updateGroupColors()
            requestSortDates()
            undo = nil
            if let selectedID, !result.people.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
            message = "Connected to Apple Contacts · \(result.people.count.formatted()) contacts"
            loadDetails()
        } catch {
            live = false
            connectionError = error.localizedDescription
            message = "Apple Contacts is not connected. Try again or check Contacts access in System Settings."
        }
    }

    func refresh() {
        guard live, deletion == nil else { return }
        if busy { refreshPending = true; return }
        perform(success: "Contacts refreshed") { try await self.service.snapshot() }
    }

    func scheduleRefresh() {
        guard live else { return }
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    func loadDetails(preservingCurrent: Bool = false) {
        detailTask?.cancel()
        if !preservingCurrent || details?.id != selectedID {
            details = nil; extras = nil; detailError = nil; extrasError = nil
            membershipError = nil
        }
        guard let id = selectedID else { detailsLoading = false; return }
        if !live {
            details = CardDetails.demo(id)
            extras = .demo
            detailsLoading = false
            return
        }
        detailsLoading = details == nil
        detailTask = Task {
            do {
                let card = try await service.details(contactID: id)
                guard !Task.isCancelled, selectedID == id else { return }
                details = card
            } catch {
                guard !Task.isCancelled, selectedID == id else { return }
                detailError = error.localizedDescription
            }
            guard !Task.isCancelled, selectedID == id else { return }
            detailsLoading = false
            // Keep the ordinary card visible even if Automation permission is denied.
            do { extras = try ContactsAutomation.readExtras(contactID: id) }
            catch { extrasError = error.localizedDescription }
        }
    }

    func retryExtras() {
        guard live, let id = selectedID else { return }
        do { extras = try ContactsAutomation.readExtras(contactID: id); extrasError = nil }
        catch { extrasError = error.localizedDescription }
    }

    func setMembership(_ person: Person, group: ContactGroup, member: Bool, recordUndo: Bool = true) {
        Task { await applyMembership(person, group: group, member: member, recordUndo: recordUndo) }
    }

    func applyMembership(_ person: Person, group: ContactGroup, member: Bool, recordUndo: Bool = true) async {
        guard !busy else { return }
        deletion = nil
        membershipError = nil
        let previous = person.groupIDs.contains(group.id)
        guard previous != member else { return }
        let undoValue = MembershipUndo(personID: person.id, groupID: group.id, member: previous)
        if !live {
            var people = snapshot.people
            guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
            if member { people[index].groupIDs.insert(group.id) }
            else { people[index].groupIDs.remove(group.id) }
            snapshot = Snapshot(people: people, groups: snapshot.groups, accounts: snapshot.accounts)
            updateGroupColors()
            undo = recordUndo ? undoValue : nil
            message = "Sample group membership updated"
            return
        }
        busy = true
        message = "Saving group change in Apple Contacts…"
        defer { finishOperation() }
        do {
            let result = try await membershipWriter(person.id, group.id, member)
            guard try MembershipUpdate.matches(result, contactID: person.id, groupID: group.id,
                accountID: person.accountID, member: member) else { throw MembershipFailure.notRetained }
            snapshot = result
            updateGroupColors()
            requestSortDates()
            undo = recordUndo ? undoValue : nil
            message = member ? "Added to \(group.name)" : "Removed from \(group.name)"
            // A group change does not replace the field editor/notes or flash the card.
        } catch {
            undo = nil
            membershipError = error.localizedDescription
            self.error = error.localizedDescription
            message = "The group change was not confirmed"
        }
    }

    // Sequential verified writes: never retry a mutation or claim an atomic batch.
    // On a failure stop; confirmed earlier changes remain, and the UI reports it.
    func applyBulkMembership(personIDs: Set<String>, targets: [String: Bool]) async -> Bool {
        guard !busy else { return false }
        bulkReport = nil
        let plan: [BulkMembershipChange]
        do { plan = try BulkGroups.plan(snapshot: snapshot, personIDs: personIDs, targets: targets) }
        catch { bulkReport = error.localizedDescription; return false }
        guard !plan.isEmpty else { message = "No group changes needed"; return true }
        busy = true
        deletion = nil
        undo = nil
        membershipError = nil
        var confirmed = 0
        defer {
            updateGroupColors()
            requestSortDates()
            finishOperation()
        }
        for change in plan {
            message = "Saving group changes: \(confirmed) of \(plan.count) confirmed…"
            do {
                if live {
                    // A previous result may reveal a disappeared card/group/account.
                    guard snapshot.people.contains(where: { $0.id == change.personID && $0.accountID == change.accountID }),
                          snapshot.groups.contains(where: { $0.id == change.groupID && $0.accountID == change.accountID }) else {
                        throw BulkGroups.failure("A contact or group changed accounts or disappeared. Refresh before trying again.")
                    }
                    let result = try await membershipWriter(change.personID, change.groupID, change.member)
                    guard try MembershipUpdate.matches(result, contactID: change.personID, groupID: change.groupID,
                        accountID: change.accountID, member: change.member) else { throw MembershipFailure.notRetained }
                    snapshot = result
                } else {
                    var people = snapshot.people
                    guard let index = people.firstIndex(where: { $0.id == change.personID }) else { throw BulkGroups.failure("Sample contact unavailable") }
                    if change.member { people[index].groupIDs.insert(change.groupID) }
                    else { people[index].groupIDs.remove(change.groupID) }
                    snapshot = Snapshot(people: people, groups: snapshot.groups, accounts: snapshot.accounts)
                }
                confirmed += 1
            } catch {
                bulkReport = "Stopped after \(confirmed) of \(plan.count) group changes were confirmed. Earlier changes remain saved. The failed change may have reached Apple Contacts; refresh and check before retrying. \(error.localizedDescription)"
                message = "Bulk group update stopped · \(confirmed) confirmed"
                return false
            }
        }
        message = "\(live ? "Saved" : "Sample update:") \(confirmed) group changes across \(personIDs.count) selected contacts"
        return true
    }

    func undoMembership() {
        guard let last = undo,
              let person = snapshot.people.first(where: { $0.id == last.personID }),
              let group = snapshot.groups.first(where: { $0.id == last.groupID }) else { undo = nil; return }
        setMembership(person, group: group, member: last.member, recordUndo: false)
    }

    func editSelected() {
        guard live, let id = selectedID else { return }
        do { try ContactsAutomation.openEditor(contactID: id) }
        catch { self.error = error.localizedDescription }
    }

    func prepareDelete(_ person: Person) {
        guard live, !busy else { return }
        busy = true
        Task {
            defer { finishOperation() }
            do { deletion = try await service.previewDeletion(contactID: person.id) }
            catch { self.error = error.localizedDescription }
        }
    }

    func confirmDelete(_ preview: DeletePreview) {
        guard live else { return }
        deletion = nil
        perform(success: "Contact deleted from Apple Contacts") {
            let result = try await self.service.delete(preview)
            self.undo = nil
            return result
        }
    }

    private func finishOperation() {
        busy = false
        if refreshPending && deletion == nil { refreshPending = false; refresh() }
    }

    private func perform(success: String, _ action: @escaping @MainActor () async throws -> Snapshot) {
        guard !busy else { return }
        busy = true
        Task {
            defer { finishOperation() }
            do {
                snapshot = try await action()
                updateGroupColors()
                requestSortDates()
                message = success
                if let selectedID, !snapshot.people.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
                loadDetails(preservingCurrent: true)
            } catch {
                self.error = error.localizedDescription + " If this followed a save or delete, check Apple Contacts before retrying."
            }
        }
    }
}
