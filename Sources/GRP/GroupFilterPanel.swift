import SwiftUI

struct GroupFilterPanel: View {
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { AccessibleText.ink(for: scheme) }
    @Binding var filter: GroupFilter
    let groups: [ContactGroup]
    let accounts: [Account]
    let colorNumbers: [String: Int]
    let matchingCount: Int
    let onDone: () -> Void
    @State private var search = ""
    private var visibleGroups: [ContactGroup] {
        groups.filter { group in
            search.isEmpty || group.name.localizedCaseInsensitiveContains(search) ||
            (accounts.first { $0.id == group.accountID }?.name ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Filter by groups").font(.title2.bold())
                Spacer()
                Text(matchingCount == 1 ? "1 matching contact" : "\(matchingCount.formatted()) matching contacts").font(.callout)
            }
            Text("Include the groups you want, exclude those you don’t. Results update immediately.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Match included groups").font(.callout)
            AccessibleSegments(selection: $filter.mode,
                options: GroupMatchMode.allCases.map { AccessibleSegmentOption(value: $0, title: $0.title) },
                label: "Match included groups")
            Toggle("No other groups", isOn: $filter.noOtherGroups)
            Text(filter.noOtherGroups && filter.included.isEmpty
                ? "No included groups selected: only ungrouped contacts will match."
                : "When enabled, a card can belong only to the included groups.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            AccessibleSearchField(text: $search, title: "Find a group or account")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleGroups) { group in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                GroupTag(group: group, colorNumber: colorNumbers[group.groupFamily.key] ?? 1, compact: true)
                                Text(accounts.first { $0.id == group.accountID }?.name ?? "Unknown account").font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            AccessibleSegments(selection: Binding(
                                get: { filter.role(for: group.id) },
                                set: { filter.setRole($0, for: group.id) }
                            ), options: GroupFilterRole.allCases.map { AccessibleSegmentOption(value: $0, title: $0.title) },
                                label: "Rule for \(group.name)").frame(width: 216)
                        }
                    }
                    if visibleGroups.isEmpty { Text("No matching groups").font(.callout).padding(.vertical, 12) }
                }.padding(.vertical, 4).padding(.horizontal, 2)
            }.frame(minHeight: 90, idealHeight: 250, maxHeight: 300)
            Divider()
            Text(filter.summary(groups: groups, accounts: accounts)).font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Filters work within the selected account and text search. Choosing an account, a group or Ungrouped clears this filter.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Clear filter") { filter = GroupFilter() }
                Spacer()
                Button("Done", action: onDone).buttonStyle(AccessibleButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 540).frame(minHeight: 480, idealHeight: 630, maxHeight: 650).foregroundColor(ink).background(AppTextSurface()).buttonStyle(AccessibleButtonStyle())
    }
}
