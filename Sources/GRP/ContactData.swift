import Contacts
import Foundation

struct Account: Identifiable, Hashable, Sendable { let id: String; let name: String }
struct ContactValue: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let value: String
    init(id: String = UUID().uuidString, label: String, value: String) {
        self.id = id; self.label = label; self.value = value
    }
}
struct DetailSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let values: [ContactValue]
}
struct CardDetails: Sendable {
    let id: String
    let sections: [DetailSection]
    let photo: Data?
    static func demo(_ id: String) -> CardDetails {
        CardDetails(id: id, sections: [
            DetailSection(id: "work", title: "Work", values: [.init(label: "Company", value: "Studio North"), .init(label: "Job title", value: "Designer")]),
            DetailSection(id: "phones", title: "Phone", values: [.init(label: "Mobile", value: "+33 6 00 00 00 00")]),
            DetailSection(id: "email", title: "Email", values: [.init(label: "Work", value: "alex@example.com")]),
            DetailSection(id: "addresses", title: "Addresses", values: [.init(label: "Home", value: "12 rue des Fleurs\n75003 Paris\nFrance (FR)")]),
            DetailSection(id: "dates", title: "Dates", values: [.init(label: "Birthday", value: "14 May")])
        ], photo: nil)
    }
}
struct CardExtras: Sendable {
    let note: String
    let created: Date?
    let modified: Date?
    let vcard: String
    static let demo = CardExtras(note: "Met at the design workshop.\nPrefers email for introductions.", created: nil, modified: nil,
        vcard: "BEGIN:VCARD\nVERSION:3.0\nFN:Alex Martin\nEND:VCARD")
}
struct Person: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let accountID: String
    let account: String
    let company: String
    let emails: [String]
    let phones: [String]
    var groupIDs: Set<String>
    var initials: String {
        let parts = name.split(separator: " ")
        let chosen = parts.count > 1 ? [parts[0], parts[parts.count - 1]] : Array(parts.prefix(1))
        return chosen.compactMap(\.first).map(String.init).joined().uppercased()
    }
}
struct ContactGroup: Identifiable, Hashable, Sendable { let id: String; let name: String; let accountID: String }
enum LibrarySelection: Hashable { case all, ungrouped, group(String) }
struct Snapshot: Sendable {
    let people: [Person]
    let groups: [ContactGroup]
    let accounts: [Account]
    func groups(for person: Person) -> [ContactGroup] {
        groups.filter { $0.accountID == person.accountID && person.groupIDs.contains($0.id) }
    }
    func people(in selection: LibrarySelection, accountID: String = "", search: String = "") -> [Person] {
        people.filter { person in
            guard accountID.isEmpty || person.accountID == accountID else { return false }
            switch selection {
            case .all: break
            case .ungrouped: guard person.groupIDs.isEmpty else { return false }
            case .group(let id): guard person.groupIDs.contains(id) else { return false }
            }
            let text = ([person.name, person.company] + person.emails + person.phones + groups(for: person).map(\.name)).joined(separator: " ")
            return search.isEmpty || text.localizedCaseInsensitiveContains(search)
        }
    }
    static let demo = Snapshot(people: [
        .init(id: "demo-alex", name: "Alex Martin", accountID: "demo", account: "Sample account", company: "Studio North", emails: ["alex@example.com"], phones: ["+33 6 00 00 00 00"], groupIDs: ["demo-friends", "demo-work"]),
        .init(id: "demo-jamie", name: "Jamie Taylor", accountID: "demo", account: "Sample account", company: "", emails: ["jamie@example.com"], phones: [], groupIDs: []),
        .init(id: "demo-morgan", name: "Morgan Lee", accountID: "demo", account: "Sample account", company: "", emails: ["morgan@example.com"], phones: [], groupIDs: ["demo-family"])
    ], groups: [
        .init(id: "demo-family", name: "Family", accountID: "demo"),
        .init(id: "demo-friends", name: "Friends", accountID: "demo"),
        .init(id: "demo-work", name: "Work", accountID: "demo")
    ], accounts: [.init(id: "demo", name: "Sample account")])
}

// Notes require a restricted entitlement in CNContactStore. Read them through
// the user-authorized Contacts scripting interface, alongside the complete vCard.
enum ContactFields {
    static let detailKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey, CNContactTypeKey, CNContactNamePrefixKey,
        CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey,
        CNContactPreviousFamilyNameKey, CNContactNameSuffixKey, CNContactNicknameKey,
        CNContactOrganizationNameKey, CNContactDepartmentNameKey, CNContactJobTitleKey,
        CNContactPhoneticGivenNameKey, CNContactPhoneticMiddleNameKey,
        CNContactPhoneticFamilyNameKey, CNContactPhoneticOrganizationNameKey,
        CNContactBirthdayKey, CNContactNonGregorianBirthdayKey,
        CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey,
        CNContactDatesKey, CNContactUrlAddressesKey, CNContactRelationsKey,
        CNContactSocialProfilesKey, CNContactInstantMessageAddressesKey,
        CNContactImageDataKey, CNContactThumbnailImageDataKey
    ].map { $0 as CNKeyDescriptor }
    static func label(_ raw: String?, fallback: String) -> String {
        guard let raw, !raw.isEmpty else { return fallback }
        return CNLabeledValue<NSString>.localizedString(forLabel: raw)
    }
    static func date(_ components: DateComponents) -> String {
        var parts = components
        let hasYear = parts.year != nil
        let calendar = parts.calendar ?? Calendar(identifier: .gregorian)
        if parts.year == nil { parts.year = 2000 }
        if parts.month == nil { parts.month = 1 }
        if parts.day == nil { parts.day = 1 }
        guard let value = calendar.date(from: parts) else { return components.description }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(hasYear ? "yMMMMd" : "MMMMd")
        return formatter.string(from: value)
    }
    static func details(_ card: CNContact) -> CardDetails {
        var sections: [DetailSection] = []
        func add(_ id: String, _ title: String, _ values: [ContactValue]) {
            let populated = values.filter { !$0.value.isEmpty }
            if !populated.isEmpty { sections.append(.init(id: id, title: title, values: populated)) }
        }
        func scalar(_ label: String, _ value: String) -> ContactValue { .init(label: label, value: value) }
        add("name", "Name", [scalar("Prefix", card.namePrefix), scalar("First name", card.givenName),
            scalar("Middle name", card.middleName), scalar("Last name", card.familyName), scalar("Suffix", card.nameSuffix),
            scalar("Previous last name", card.previousFamilyName), scalar("Nickname", card.nickname),
            scalar("Phonetic first name", card.phoneticGivenName), scalar("Phonetic middle name", card.phoneticMiddleName),
            scalar("Phonetic last name", card.phoneticFamilyName)])
        add("work", "Work", [scalar("Company", card.organizationName), scalar("Department", card.departmentName),
            scalar("Job title", card.jobTitle), scalar("Phonetic company", card.phoneticOrganizationName),
            scalar("Card type", card.contactType == .organization ? "Company" : "Person")])
        add("phones", "Phone", card.phoneNumbers.map { .init(id: $0.identifier, label: label($0.label, fallback: "Phone"), value: $0.value.stringValue) })
        add("email", "Email", card.emailAddresses.map { .init(id: $0.identifier, label: label($0.label, fallback: "Email"), value: $0.value as String) })
        add("addresses", "Addresses", card.postalAddresses.map {
            let address = $0.value
            let formatted = CNPostalAddressFormatter.string(from: address, style: .mailingAddress)
            let code = address.isoCountryCode.isEmpty ? "" : "\nCountry code: \(address.isoCountryCode)"
            return .init(id: $0.identifier, label: label($0.label, fallback: "Address"), value: formatted + code)
        })
        add("urls", "Websites", card.urlAddresses.map { .init(id: $0.identifier, label: label($0.label, fallback: "Website"), value: $0.value as String) })
        var dates = card.dates.map { ContactValue(id: $0.identifier, label: label($0.label, fallback: "Date"), value: date($0.value as DateComponents)) }
        if let birthday = card.birthday { dates.insert(scalar("Birthday", date(birthday)), at: 0) }
        if let birthday = card.nonGregorianBirthday { dates.append(scalar("Alternate birthday", date(birthday))) }
        add("dates", "Dates", dates)
        add("relations", "Related people", card.contactRelations.map { .init(id: $0.identifier, label: label($0.label, fallback: "Related person"), value: $0.value.name) })
        add("social", "Social profiles", card.socialProfiles.map {
            let p = $0.value
            return .init(id: $0.identifier, label: label($0.label, fallback: p.service.isEmpty ? "Profile" : p.service),
                value: [p.service, p.username, p.urlString, p.userIdentifier.isEmpty ? "" : "User ID: \(p.userIdentifier)"].filter { !$0.isEmpty }.joined(separator: "\n"))
        })
        add("messaging", "Messaging", card.instantMessageAddresses.map {
            .init(id: $0.identifier, label: label($0.label, fallback: "Messaging"), value: [$0.value.service, $0.value.username].filter { !$0.isEmpty }.joined(separator: "\n"))
        })
        return CardDetails(id: card.identifier, sections: sections, photo: card.imageData ?? card.thumbnailImageData)
    }
}
