import AppKit
import Carbon
import Foundation

@main
@MainActor
struct SortingPaletteChecks {
    nonisolated static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fatalError(message) }
    }
    static func person(_ id: String, _ name: String) -> Person {
        .init(id: id, name: name, accountID: "test", account: "Test", company: "", emails: [], phones: [], groupIDs: [])
    }
    static func dateResult(ids: [String], created: [Date?], modified: [Date?]) -> NSAppleEventDescriptor {
        let result = NSAppleEventDescriptor.list()
        let idList = NSAppleEventDescriptor.list(), createdList = NSAppleEventDescriptor.list(), modifiedList = NSAppleEventDescriptor.list()
        for (i, id) in ids.enumerated() { idList.insert(.init(string: id), at: i + 1) }
        for (i, date) in created.enumerated() { createdList.insert(date.map { .init(date: $0) } ?? .null(), at: i + 1) }
        for (i, date) in modified.enumerated() { modifiedList.insert(date.map { .init(date: $0) } ?? .null(), at: i + 1) }
        result.insert(idList, at: 1); result.insert(createdList, at: 2); result.insert(modifiedList, at: 3)
        return result
    }
    static func main() async throws {
        let people = [person("a", "Alpha"), person("b", "Beta"), person("c", "Gamma"), person("d", "Delta")]
        let dates: [String: CardDates] = [
            "a": .init(created: Date(timeIntervalSince1970: 300), modified: Date(timeIntervalSince1970: 100)),
            "b": .init(created: Date(timeIntervalSince1970: 100), modified: Date(timeIntervalSince1970: 400)),
            "c": .init(created: Date(timeIntervalSince1970: 200), modified: Date(timeIntervalSince1970: 200))
        ]
        require(ContactSort.createdNewest.sorted(people, dates: dates).map(\.id) == ["a", "c", "b", "d"], "Created newest; unknown last")
        require(ContactSort.createdOldest.sorted(people, dates: dates).map(\.id) == ["b", "c", "a", "d"], "Created oldest; unknown last")
        require(ContactSort.modifiedNewest.sorted(people, dates: dates).map(\.id) == ["b", "c", "a", "d"], "Modification newest uses modification, not creation")
        require(ContactSort.modifiedOldest.sorted(people, dates: dates).map(\.id) == ["a", "c", "b", "d"], "Modification oldest")
        require(ContactSort.name.sorted(people, dates: dates).map(\.id) == ["a", "b", "d", "c"], "Keep alphabetical option")
        let same = [person("z", "Same"), person("x", "Same")]
        require(ContactSort.createdNewest.sorted(same, dates: [:]).map(\.id) == ["x", "z"], "Equal or missing dates have a stable tie order")
        let day = Date(timeIntervalSince1970: 1700000000)
        let decoded = try ContactsAutomation.parseDates(dateResult(ids: ["a", "b"], created: [day, nil], modified: [nil, day]))
        require(decoded["a"]?.created == day && decoded["a"]?.modified == nil && decoded["b"]?.modified == day, "Parse exact timestamps and missing values")
        do { _ = try ContactsAutomation.parseDates(dateResult(ids: ["a"], created: [], modified: [day])); fatalError("Reject unaligned date arrays") } catch { }
        do { _ = try ContactsAutomation.parseDates(dateResult(ids: ["a", "a"], created: [day, day], modified: [day, day])); fatalError("Reject ambiguous card IDs") } catch { }
        require(ContactsAutomation.datesEvent().paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.numberOfItems == 0, "Bulk dates need a single event, no per-card execution")

        let names = ["Foo", "Foo Dog", "foo Cat", "Bar", "Baz Banjo", "Baz Guitar"]
        let families = names.map { GroupFamily(groupName: $0) }
        require(Set(families.map(\.key)).count == 3, "First word produces exactly three families")
        require(families[0].key == families[1].key && families[1].key == families[2].key, "Standalone and case variants share family")
        require(GroupFamily(groupName: "\tFoo\u{00A0}Dog ").key == "foo", "Normalize leading and Unicode whitespace")
        let colors = GroupColorLibrary.assigning(families: families.map(\.key), saved: [:])
        require(Set(colors.values).count == 3, "Use distinct available colors before recycling")
        require(colors == GroupColorLibrary.assigning(families: families.reversed().map(\.key), saved: [:]), "Allocation independent of fetch/filter order")
        let added = GroupColorLibrary.assigning(families: families.map(\.key) + ["aardvark"], saved: colors)
        require(colors.allSatisfy { added[$0.key] == $0.value }, "Adding a family must not recolor existing families")
        let eight = GroupColorLibrary.assigning(families: (1...8).map { "family\($0)" }, saved: [:])
        let nine = GroupColorLibrary.colors + [.init(id: 9, name: "Extension example", hex: 0x332288)]
        let expanded = GroupColorLibrary.assigning(families: Array(eight.keys) + ["new"], saved: eight, library: nine)
        require(expanded["new"] == 9 && eight.allSatisfy { expanded[$0.key] == $0.value }, "Append colors without changing the allocator or existing assignments")
        require(GroupColorLibrary.colors.count == Set(GroupColorLibrary.colors.map(\.id)).count, "Unique public palette IDs")
        for entry in GroupColorLibrary.colors {
            for bg in [UInt32(0xFFFFFF), 0xF5F5F5, 0x1E1E1E, 0x2C2C2C, 0x000000] {
                let background = PaletteRGB(bg)
                require(entry.rgb.readable(on: background).contrast(with: background) >= 4.5, "Readable palette text in both appearances")
            }
        }
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = NSAppearance(named: name)!
            appearance.performAsCurrentDrawingAppearance {
                let color = NSColor.textBackgroundColor.usingColorSpace(.sRGB)!
                let background = PaletteRGB(r: color.redComponent, g: color.greenComponent, b: color.blueComponent)
                for entry in GroupColorLibrary.colors {
                    require(entry.rgb.readable(on: background).contrast(with: background) >= 4.5,
                        "Check text against the actual macOS label surface")
                }
            }
        }
        let fake = Model(datesLoader: { CardDates.demo })
        fake.live = true; fake.sort = .createdNewest
        await fake.loadSortDates()
        require(fake.cardDates == CardDates.demo && fake.datesError == nil && !fake.datesLoading, "Date load populates and releases progress")
        let denied = Model(datesLoader: { throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Automation denied"]) })
        denied.live = true; denied.sort = .modifiedNewest
        await denied.loadSortDates()
        require(denied.datesError == "Automation denied" && denied.cardDates.isEmpty && !denied.datesLoading, "Denied access stays visible and does not sort on sample timestamps")
        print("Passed all four date sorts, missing dates, date parsing/recovery, group families, stable/extendable color IDs and light/dark text contrast checks (synthetic data only).")
    }
}
