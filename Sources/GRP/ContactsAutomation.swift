import AppKit
import Carbon
import Foundation

// Contacts automation for notes and verified membership saves. Card deletion
// continues through the native Contacts framework, not this scripting bridge.
@MainActor
enum ContactsAutomation {
    static let source = """
    on readextras(contactID)
        with timeout of 15 seconds
            tell application id "com.apple.AddressBook"
                if not (exists person id contactID) then error "This exact contact is no longer available. Refresh and try again." number 18002
                set p to person id contactID
                set cardNote to note of p
                if cardNote is missing value then set cardNote to ""
                set cardData to vcard of p
                if cardData is missing value then set cardData to ""
                return {cardNote, creation date of p, modification date of p, cardData}
            end tell
        end timeout
    end readextras
    """

    // Save through Apple Contacts, then verify with a fresh native read.
    static let membershipSource = """
    on changemembership(contactID, groupID, wantsMembership)
        with timeout of 20 seconds
            tell application id "com.apple.AddressBook"
                if unsaved then
                    error "Finish or cancel the current edits in Apple Contacts, then try again." number 18001
                end if
                if not (exists person id contactID) then
                    error "Apple Contacts cannot find this exact contact. Refresh and try again." number 18002
                end if
                if not (exists group id groupID) then
                    error "Apple Contacts cannot find this exact list. Refresh and try again." number 18003
                end if
                set targetPerson to person id contactID
                set targetGroup to group id groupID
                set wasMember to contactID is in (get id of every person of targetGroup)
                if wasMember is wantsMembership then return false
                if wantsMembership then
                    add targetPerson to targetGroup
                else
                    remove targetPerson from targetGroup
                end if
                save
                set nowMember to contactID is in (get id of every person of targetGroup)
                if nowMember is not wantsMembership then
                    error "Apple Contacts did not retain the requested group membership." number 18004
                end if
                if unsaved then
                    error "Apple Contacts still has unsaved changes. Check the list there before retrying." number 18005
                end if
                return true
            end tell
        end timeout
    end changemembership
    """

    private static func subroutineEvent(_ name: String, arguments: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASSubroutineEvent), targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: name), forKeyword: AEKeyword(keyASSubroutineName))
        let list = NSAppleEventDescriptor.list()
        for (index, argument) in arguments.enumerated() { list.insert(argument, at: index + 1) }
        event.setParam(list, forKeyword: AEKeyword(keyDirectObject))
        return event
    }

    static func event(contactID: String) -> NSAppleEventDescriptor {
        subroutineEvent("readextras", arguments: [.init(string: contactID)])
    }

    static func membershipEvent(contactID: String, groupID: String, member: Bool) -> NSAppleEventDescriptor {
        subroutineEvent("changemembership", arguments: [
            .init(string: contactID), .init(string: groupID), .init(boolean: member)
        ])
    }

    static func changeMembership(contactID: String, groupID: String, member: Bool) throws {
        guard let script = NSAppleScript(source: membershipSource) else { throw failure("Could not load the group-saving command.") }
        var error: NSDictionary?
        let result = script.executeAppleEvent(membershipEvent(contactID: contactID, groupID: groupID, member: member), error: &error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int ?? 0
            if number == -1743 {
                throw failure("To save group changes, allow GRP to control Contacts in System Settings → Privacy & Security → Automation, then try again.")
            }
            throw failure("The group change was not confirmed: \(error[NSAppleScript.errorMessage] as? String ?? "Contacts did not respond") (Contacts command \(number)).")
        }
        // Both true (changed) and false (already correct) are valid, verified outcomes.
        guard [DescType(typeBoolean), DescType(typeTrue), DescType(typeFalse)].contains(result.descriptorType) else {
            throw failure("Contacts returned an unexpected group-save response. Check the card before retrying.")
        }
    }

    static func readExtras(contactID: String) throws -> CardExtras {
        guard let script = NSAppleScript(source: source) else { throw failure("Could not load the Contacts reader.") }
        var error: NSDictionary?
        let result = script.executeAppleEvent(event(contactID: contactID), error: &error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int ?? 0
            if number == -1743 {
                throw failure("To show notes and all exported fields, allow GRP to control Contacts in System Settings → Privacy & Security → Automation, then click Retry.")
            }
            throw failure("Notes and exported fields could not be loaded: \(error[NSAppleScript.errorMessage] as? String ?? "Contacts did not respond") (\(number)).")
        }
        guard result.numberOfItems == 4 else { throw failure("Contacts returned incomplete notes and card data. Retry after refreshing.") }
        return CardExtras(note: result.atIndex(1)?.stringValue ?? "", created: result.atIndex(2)?.dateValue,
            modified: result.atIndex(3)?.dateValue, vcard: result.atIndex(4)?.stringValue ?? "")
    }

    static let datesSource = """
    on readcarddates()
        with timeout of 30 seconds
            tell application id "com.apple.AddressBook"
                set beforeIDs to get id of every person
                set createdDates to get creation date of every person
                set modifiedDates to get modification date of every person
                set afterIDs to get id of every person
                if beforeIDs is not afterIDs then error "Contacts changed while loading dates. Please retry." number 18010
                return {beforeIDs, createdDates, modifiedDates}
            end tell
        end timeout
    end readcarddates
    """

    static func datesEvent() -> NSAppleEventDescriptor { subroutineEvent("readcarddates", arguments: []) }

    static func parseDates(_ result: NSAppleEventDescriptor) throws -> [String: CardDates] {
        guard result.numberOfItems == 3, let ids = result.atIndex(1),
              let created = result.atIndex(2), let modified = result.atIndex(3),
              [ids, created, modified].allSatisfy({ $0.descriptorType == DescType(typeAEList) }),
              ids.numberOfItems == created.numberOfItems, ids.numberOfItems == modified.numberOfItems else {
            throw failure("Contacts returned incomplete card dates. Please retry.")
        }
        var dates: [String: CardDates] = [:]
        for index in 0..<ids.numberOfItems {
            guard let id = ids.atIndex(index + 1)?.stringValue, !id.isEmpty, dates[id] == nil else {
                throw failure("Contacts returned ambiguous card dates. Please retry.")
            }
            dates[id] = CardDates(created: created.atIndex(index + 1)?.dateValue, modified: modified.atIndex(index + 1)?.dateValue)
        }
        return dates
    }

    static func readCardDates() throws -> [String: CardDates] {
        guard let script = NSAppleScript(source: datesSource) else { throw failure("Could not load the card date reader.") }
        var error: NSDictionary?
        let result = script.executeAppleEvent(datesEvent(), error: &error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int ?? 0
            if number == -1743 {
                throw failure("To sort by card dates, allow GRP to control Contacts in System Settings → Privacy & Security → Automation, then retry.")
            }
            throw failure("Could not load card dates: \(error[NSAppleScript.errorMessage] as? String ?? "Contacts did not respond") (\(number)).")
        }
        return try parseDates(result)
    }

    static func editURL(contactID: String) -> URL? {
        // Preserve the identifier as one URL component, including :ABPerson.
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        guard let escaped = contactID.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "addressbook://\(escaped)?edit")
    }

    static func openEditor(contactID: String) throws {
        guard let url = editURL(contactID: contactID), NSWorkspace.shared.open(url) else {
            throw failure("Apple Contacts could not open this card. Refresh and try again.")
        }
    }
    private static func failure(_ text: String) -> NSError {
        NSError(domain: "GRP.Automation", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
