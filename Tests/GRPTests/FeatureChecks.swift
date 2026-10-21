import Carbon
import Contacts
import Foundation

@main
@MainActor
struct FeatureChecks {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fatalError(message) }
    }
    static func main() {
        let alex = Snapshot.demo.people[0]
        require(Snapshot.demo.people(in: .ungrouped).map(\.id) == ["demo-jamie"], "Ungrouped must behave as a group")
        require(Snapshot.demo.people(in: .group("demo-friends")).map(\.id) == [alex.id], "Group selection must filter memberships")
        require(Snapshot.demo.people(in: .all, search: "Studio North").count == 1, "Company search")
        require(Snapshot.demo.people(in: .all, search: "Friends").count == 1, "Group name search")
        require(Snapshot.demo.groups(for: alex).map(\.name) == ["Friends", "Work"], "List badges must show every assigned group")
        var people = Snapshot.demo.people
        people[0].groupIDs.removeAll()
        let changed = Snapshot(people: people, groups: Snapshot.demo.groups, accounts: Snapshot.demo.accounts)
        require(changed.people(in: .ungrouped).count == 2, "Removing the last group must immediately update Ungrouped")
        require(changed.people(in: .all, accountID: "other").isEmpty, "Account filter must isolate contacts")
        let alienGroup = ContactGroup(id: "demo-friends", name: "Other account group", accountID: "other")
        let isolated = Snapshot(people: [alex], groups: [alienGroup], accounts: Snapshot.demo.accounts)
        require(isolated.groups(for: alex).isEmpty, "Group display must not leak across accounts")

        let card = CNMutableContact()
        card.givenName = "Sample"; card.middleName = "Middle"; card.familyName = "Contact"
        card.namePrefix = "Dr"; card.nameSuffix = "Jr"; card.previousFamilyName = "Former"
        card.nickname = "Nickname"; card.phoneticGivenName = "Phonetic"
        card.organizationName = "Company"; card.departmentName = "Department"; card.jobTitle = "Role"
        card.phoneNumbers = [CNLabeledValue(label: "Satellite", value: CNPhoneNumber(stringValue: "+1 555 0100"))]
        card.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "sample@example.com" as NSString)]
        let address = CNMutablePostalAddress()
        address.street = "12 Example Street"; address.city = "Paris"; address.postalCode = "75003"; address.country = "France"; address.isoCountryCode = "FR"
        card.postalAddresses = [CNLabeledValue(label: "Studio", value: address)]
        card.urlAddresses = [CNLabeledValue(label: "Portfolio", value: "https://example.com" as NSString)]
        card.birthday = DateComponents(month: 2, day: 29)
        card.contactRelations = [CNLabeledValue(label: "Collaborator", value: CNContactRelation(name: "Other Person"))]
        card.socialProfiles = [CNLabeledValue(label: "Professional", value: CNSocialProfile(urlString: "https://example.com/profile", username: "sample", userIdentifier: "123", service: "LinkedIn"))]
        card.instantMessageAddresses = [CNLabeledValue(label: "Chat", value: CNInstantMessageAddress(username: "sample", service: "Jabber"))]
        let details = ContactFields.details(card)
        let entries = details.sections.flatMap(\.values)
        require(entries.contains { $0.label == "Satellite" && $0.value == "+1 555 0100" }, "Keep custom phone labels")
        require(entries.contains { $0.label == "Studio" && $0.value.contains("Paris") && $0.value.contains("FR") }, "Show full postal addresses")
        require(entries.contains { $0.label == "Nickname" && $0.value == "Nickname" }, "Show extended name fields")
        require(entries.contains { $0.label == "Collaborator" && $0.value == "Other Person" }, "Show relationships")
        require(entries.contains { $0.value.contains("User ID: 123") }, "Preserve social profile identifiers")
        require(entries.contains { $0.label == "Birthday" && !$0.value.contains("2000") }, "Do not invent a year for a yearless birthday")
        require(!ContactFields.detailKeys.contains { String(describing: $0) == CNContactNoteKey }, "Do not request restricted notes without entitlement")

        let id = "record\"with\\special\ncharacters:ABPerson"
        let event = ContactsAutomation.event(contactID: id)
        require(event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.atIndex(1)?.stringValue == id, "Pass exact identifiers as data, never AppleScript text")
        let ordinaryID = "40051F05-3FCF-4619-9E2E-5E4CC0B38914:ABPerson"
        require(ContactsAutomation.editURL(contactID: ordinaryID) != nil, "Build a native editor URL for actual Contacts identifiers")
        let unusualURL = ContactsAutomation.editURL(contactID: "abc?injected#fragment/percent%:ABPerson")
        require(unusualURL?.query == "edit" && unusualURL?.fragment == nil, "Escape identifier characters in editor URLs")
        print("Passed contact filtering, group display, rich field mapping, yearless dates, safe Apple events and editor URL checks (synthetic data only).")
    }
}
