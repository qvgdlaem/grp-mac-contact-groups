import SwiftUI

struct BulkGroupsPanel: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var model: Model
    let personIDs: Set<String>
    let onClose: () -> Void
    @State private var search = ""
    @State private var targets: [String: Bool] = [:]
    @State private var applying = false
    @State private var report: String?
    private var ink: Color { AccessibleText.ink(for: scheme) }
    private var people: [Person] { model.snapshot.people.filter { personIDs.contains($0.id) } }
    private var groups: [ContactGroup] {
        model.snapshot.groups.filter { group in
            people.contains { $0.accountID == group.accountID } && (search.isEmpty || group.name.localizedCaseInsensitiveContains(search) || account(group).localizedCaseInsensitiveContains(search))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func account(_ group: ContactGroup) -> String { model.snapshot.accounts.first { $0.id == group.accountID }?.name ?? "Unknown account" }
    private func eligible(_ group: ContactGroup) -> [Person] { people.filter { $0.accountID == group.accountID } }
    private func state(_ group: ContactGroup) -> MembershipState {
        if let target = targets[group.id] { return target ? .all : .none }
        return .state(people: eligible(group), groupID: group.id)
    }
    private var changes: [BulkMembershipChange] { (try? BulkGroups.plan(snapshot: model.snapshot, personIDs: personIDs, targets: targets)) ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Groups for \(personIDs.count) selected contacts").font(.title2.bold())
            Text("✓ All · − Some · □ None. Click a dash to add the group to everyone.")
                .font(.callout)
            Text("Each group applies only to selected cards in its account. Untouched groups stay as they are.").font(.callout)
            AccessibleSearchField(text: $search, title: "Find a group or account")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(groups) { group in
                        Button {
                            targets = BulkGroups.toggling(groupID: group.id, people: eligible(group), targets: targets)
                            report = nil
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: state(group).symbol).font(.system(size: 22)).frame(width: 26)
                                VStack(alignment: .leading, spacing: 4) {
                                    GroupTag(group: group, colorNumber: model.colorNumber(for: group), compact: true)
                                    Text("\(account(group)) · \(eligible(group).count) selected in this account").font(.caption)
                                }
                                Spacer()
                                if targets[group.id] != nil { Text("Changed").font(.caption.bold()) }
                            }.foregroundColor(ink).padding(8).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(applying)
                            .accessibilityLabel("\(group.name), \(account(group))")
                            .accessibilityValue("\(state(group).description) of \(eligible(group).count) selected contacts in this account")
                            .accessibilityHint(state(group) == .all ? "Remove from all selected cards in this account" : "Add to all selected cards in this account")
                    }
                    if groups.isEmpty { Text("No matching groups").padding(8) }
                }
            }
            Divider()
            if let report { Text(report).textSelection(.enabled) }
            if applying { Text(model.message).font(.callout) }
            else { Text("\(changes.filter(\.member).count) additions · \(changes.filter { !$0.member }.count) removals").font(.callout) }
            HStack {
                Button(targets.isEmpty ? "Close" : "Cancel") { onClose() }.disabled(applying).keyboardShortcut(.cancelAction)
                if !targets.isEmpty { Button("Reset changes") { targets = [:]; report = nil }.disabled(applying) }
                Spacer()
                Button("Apply") {
                    applying = true
                    let request = targets
                    Task {
                        let success = await model.applyBulkMembership(personIDs: personIDs, targets: request)
                        applying = false
                        targets = [:]
                        if success { onClose() } else { report = model.bulkReport }
                    }
                }.buttonStyle(AccessibleButtonStyle(primary: true)).disabled(applying || targets.isEmpty || model.busy)
            }
        }.padding(20).frame(width: 540, height: 580).foregroundColor(ink)
            .background(AppTextSurface()).buttonStyle(AccessibleButtonStyle())
            .interactiveDismissDisabled(applying)
    }
}
