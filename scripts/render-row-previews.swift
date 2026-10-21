import AppKit
import SwiftUI

// Render the actual row view using synthetic data; never opens or fetches Contacts.
@main
@MainActor
struct RowPreviews {
    static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let groups: [ContactGroup] = [
            .init(id: "g1", name: "Friends Europe", accountID: "demo"),
            .init(id: "g2", name: "Friends Paris", accountID: "demo"),
            .init(id: "g3", name: "Design Collective", accountID: "demo"),
            .init(id: "g4", name: "University Alumni", accountID: "demo")
        ]
        let numbers = GroupColorLibrary.assigning(families: groups.map { $0.groupFamily.key }, saved: [:])
        let person = Person(id: "preview", name: "Alexandra Martin", accountID: "demo", account: "iCloud", company: "Studio North",
            emails: ["alexandra@example.com"], phones: ["+33 6 00 00 00 00", "+44 20 7946 0123"], groupIDs: Set(groups.map(\.id)))
        for scheme in [ColorScheme.light, .dark] {
            for width in [CGFloat(340), 500] {
                let content = VStack(alignment: .leading, spacing: 14) {
                    Text("CONTACT LIST · \(scheme == .dark ? "DARK" : "LIGHT") · \(Int(width)) PT")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(AccessibleText.ink(for: scheme))
                    ContactRow(person: person, groups: groups, colorNumbers: numbers, selected: false,
                        dateLabel: "Created", date: Date(timeIntervalSince1970: 1704067200))
                    ContactRow(person: person, groups: groups, colorNumbers: numbers, selected: true, dateLabel: nil, date: nil)
                }
                .padding(16).frame(width: width).background(AppTextSurface()).environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                _ = renderer.cgImage
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                guard let image = renderer.cgImage,
                      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "RowPreviews", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render row preview"])
                }
                let file = "rows-\(scheme == .dark ? "dark" : "light")-\(Int(width)).png"
                // Use a native hosting view for the final snapshot. ImageRenderer's
                // offscreen display list can omit neutral text on this macOS build.
                let host = NSHostingView(rootView: content)
                let size = NSSize(width: width, height: CGFloat(image.height) / renderer.scale)
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                    styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host
                host.frame = NSRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let native = bitmap.representation(using: .png, properties: [:]) ?? data
                    try native.write(to: directory.appendingPathComponent(file))
                } else { try data.write(to: directory.appendingPathComponent(file)) }
                window.orderOut(nil)
                print("Rendered \(file)")
            }
        }
        if CommandLine.arguments.contains("--app") {
            for scheme in [ColorScheme.light, .dark] {
                let model = Model()
                model.selectedID = "demo-alex"
                model.details = .demo("demo-alex")
                model.extras = .demo
                model.sort = .createdOldest
                let view = ContentView(model: model).environment(\.colorScheme, scheme)
                try capture(view, size: NSSize(width: 1480, height: 850),
                    to: directory.appendingPathComponent("disconnected-\(scheme == .dark ? "dark" : "light").png"))
                let query = GroupFilter(included: ["demo-friends", "demo-work"], excluded: ["demo-family"], noOtherGroups: true)
                try capture(ContentView(model: model, initialFilter: query).environment(\.colorScheme, scheme),
                    size: NSSize(width: 1480, height: 850),
                    to: directory.appendingPathComponent("filtered-\(scheme == .dark ? "dark" : "light").png"))
                let bulkModel = Model()
                var bulkPeople = Snapshot.demo.people
                bulkPeople[1].groupIDs = ["demo-work"]
                bulkModel.snapshot = Snapshot(people: bulkPeople, groups: Snapshot.demo.groups, accounts: Snapshot.demo.accounts)
                try capture(BulkGroupsPanel(model: bulkModel, personIDs: ["demo-alex", "demo-jamie"], onClose: {})
                    .environment(\.colorScheme, scheme), size: NSSize(width: 580, height: 620),
                    to: directory.appendingPathComponent("bulk-\(scheme == .dark ? "dark" : "light").png"))
                try capture(ContentView(model: bulkModel, initialSelection: ["demo-alex", "demo-jamie"])
                    .environment(\.colorScheme, scheme), size: NSSize(width: 1480, height: 850),
                    to: directory.appendingPathComponent("multi-\(scheme == .dark ? "dark" : "light").png"))
                let panel = GroupFilterPanel(filter: .constant(query), groups: Snapshot.demo.groups,
                    accounts: Snapshot.demo.accounts, colorNumbers: model.familyColorNumbers,
                    matchingCount: Snapshot.demo.people.filter { query.matches($0.groupIDs) }.count, onDone: {})
                    .environment(\.colorScheme, scheme)
                try capture(panel, size: NSSize(width: 540, height: 610),
                    to: directory.appendingPathComponent("filter-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
    static func capture<Content: View>(_ content: Content, size: NSSize, to file: URL) throws {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "Previews", code: 1, userInfo: [NSLocalizedDescriptionKey: "Native preview unavailable"])
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "Previews", code: 2)
        }
        try data.write(to: file)
        window.orderOut(nil)
        print("Rendered \(file.lastPathComponent)")
    }

}
