import AppKit
import Contacts
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { AccessibleText.ink(for: scheme) }
    @StateObject private var model: Model
    @State private var groupFilter: GroupFilter
    @State private var showGroupFilter = false
    @State private var selectedIDs: Set<String> = []
    @State private var bulkSelection: BulkSelection?

    init(model: Model, initialFilter: GroupFilter = GroupFilter(), initialSelection: Set<String>? = nil) {
        _model = StateObject(wrappedValue: model)
        _groupFilter = State(initialValue: initialFilter)
        _selectedIDs = State(initialValue: initialSelection ?? Set([model.selectedID].compactMap { $0 }))
    }
    @State private var library: LibrarySelection? = .all
    @State private var search = ""
    @State private var accountID = ""
    private var scope: LibrarySelection { library ?? .all }
    private var people: [Person] { model.sort.sorted(model.snapshot.people(in: scope, accountID: accountID, search: search).filter { groupFilter.matches($0.groupIDs) }, dates: model.cardDates) }
    private var groups: [ContactGroup] { model.snapshot.groups.filter { accountID.isEmpty || $0.accountID == accountID } }
    private var title: String {
        switch scope {
        case .all: return "All contacts"
        case .ungrouped: return "Ungrouped"
        case .group(let id): return model.snapshot.groups.first { $0.id == id }?.name ?? "Group"
        }
    }

    private var appContent: some View {
        VStack(spacing: 0) {
            if !model.live {
                connectionBanner.fixedSize(horizontal: false, vertical: true)
            }
            navigationContent.frame(maxWidth: .infinity, maxHeight: .infinity)
            statusBar
        }
        .navigationTitle("GRP")
        .toolbar {
            ToolbarItem {
                AccessibleSearchField(text: $search, title: "Search contacts").frame(width: 280)
            }
            ToolbarItemGroup {
                if model.busy { ProgressView().controlSize(.small) }
                Button("Refresh contacts", systemImage: "arrow.clockwise") { model.refresh() }
                    .disabled(!model.live || model.busy)
                Button("Undo group change", systemImage: "arrow.uturn.backward") { model.undoMembership() }
                    .disabled(model.undo == nil || model.busy)
            }
        }
    }

    var body: some View {
        scopeObservedContent
        .sheet(item: $bulkSelection) { selection in
            BulkGroupsPanel(model: model, personIDs: selection.ids, onClose: { bulkSelection = nil })
        }
        .sheet(item: $model.deletion) { preview in deletionConfirmation(preview) }
        .alert("Contacts operation stopped", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .CNContactStoreDidChange)) { _ in model.scheduleRefresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.scheduleRefresh() }
        .frame(minWidth: 1180, minHeight: 620)
        .foregroundColor(ink)
        .background(AppTextSurface())
        .buttonStyle(AccessibleButtonStyle())
    }

    private var selectionObservedContent: some View {
        accountObservedContent
        .onChange(of: selectedIDs) { _, ids in
            model.selectedID = ids.count == 1 ? ids.first : nil
        }
        .onChange(of: search) { _, _ in clearHiddenSelection() }
        .onChange(of: model.snapshot.people) { _, _ in
            // Keep the frozen batch selection while saved changes leave this view.
            if bulkSelection == nil { clearHiddenSelection() }
        }
        .onChange(of: bulkSelection) { _, value in if value == nil { clearHiddenSelection() } }
        .onChange(of: model.selectedID) { _, _ in model.loadDetails() }
    }

    private var scopeObservedContent: some View {
        selectionObservedContent
        .onChange(of: library) { _, value in
            if value != .all { groupFilter = GroupFilter() }
            clearHiddenSelection()
        }
        .onChange(of: groupFilter) { _, value in
            if value.isActive { library = .all }
            clearHiddenSelection()
        }
    }

    private var accountObservedContent: some View {
        appContent
        .onChange(of: model.live) { _, _ in groupFilter = GroupFilter(); library = .all }
        .onChange(of: accountID) { _, _ in
            groupFilter = GroupFilter()
            if case .group(let id) = scope, !groups.contains(where: { $0.id == id }) { library = .all }
            clearHiddenSelection()
        }
        .onChange(of: model.snapshot.accounts) { _, accounts in
            if !accountID.isEmpty && !accounts.contains(where: { $0.id == accountID }) { accountID = "" }
        }
        .onChange(of: model.snapshot.groups) { _, _ in
            if case .group(let id) = scope, !groups.contains(where: { $0.id == id }) { library = .all }
        }
    }

    private var navigationContent: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 205, ideal: 240, max: 340)
        } content: {
            contactList.navigationSplitViewColumnWidth(min: 340, ideal: 500, max: 800)
        } detail: {
            if selectedIDs.count > 1 {
                VStack(spacing: 16) {
                    Text("\(selectedIDs.count) contacts selected").font(.title2.bold())
                    Text("Use Groups for selected to review and apply group changes.")
                    Button("Groups for selected…") { bulkSelection = BulkSelection(ids: selectedIDs) }.disabled(model.busy)
                }.padding()
            } else if let person = model.selected {
                ContactDetailView(model: model, person: person)
            } else {
                ContentUnavailableView("A place for every contact", systemImage: "person.crop.rectangle.stack",
                    description: Text("Select a contact to see their details and edit their groups.").foregroundColor(ink))
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: model.live ? "checkmark.circle" : "info.circle")
            Text(model.message)
            Spacer()
            if !model.live { Text("Sample contacts") }
        }.font(.caption).foregroundColor(ink).padding(.horizontal, 16).padding(.vertical, 9)
            .background(AppTextSurface()).overlay(alignment: .top) { Divider() }
    }

    // A normal content button stays visible even when macOS collapses toolbar
    // labels or moves toolbar items into its overflow menu.
    private var connectionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.rectangle.stack").font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.connecting ? "Connecting to Apple Contacts…" : "Connect your Apple Contacts").font(.headline)
                    Text(model.connecting ? "If macOS asks, allow access to your contacts." : "You’re viewing sample contacts. Connect to load your contacts and groups.")
                        .font(.callout).foregroundColor(ink)
                }
                Spacer(minLength: 8)
                if model.connecting { ProgressView().controlSize(.small) }
                Button(model.connectionError == nil ? "Connect Apple Contacts" : "Try connecting again") { model.connect() }
                    .buttonStyle(AccessibleButtonStyle(primary: true)).disabled(model.busy)
            }
            if let error = model.connectionError {
                Text(error).font(.callout).foregroundColor(ink).textSelection(.enabled)
                Text("System Settings → Privacy & Security → Contacts → GRP. Enable access, then try connecting again.")
                    .font(.caption).foregroundColor(ink)
            }
        }.padding(.horizontal, 20).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $library) {
                Section {
                    sidebarRow("All contacts", icon: "person.2", count: model.snapshot.people(in: .all, accountID: accountID).count, selection: .all)
                        .tag(LibrarySelection.all)
                    sidebarRow("Ungrouped", icon: "person.crop.circle.badge.questionmark", count: model.snapshot.people(in: .ungrouped, accountID: accountID).count, selection: .ungrouped)
                        .tag(LibrarySelection.ungrouped)
                } header: { Text("Library").foregroundColor(ink) }
                Section {
                    ForEach(groups) { group in
                        HStack(spacing: 8) {
                            Image(systemName: "folder").foregroundColor(ink)
                            GroupTag(group: group, colorNumber: model.colorNumber(for: group), compact: true)
                        }
                            .tag(LibrarySelection.group(group.id))
                            .help("\(group.name) · \(model.snapshot.accounts.first { $0.id == group.accountID }?.name ?? "")")
                    }
                    if groups.isEmpty { Text("No groups in this account").foregroundColor(ink).font(.caption) }
                } header: { Text("Groups").foregroundColor(ink) }
            }.listStyle(.sidebar)
            Divider()
            Picker("Account", selection: $accountID) {
                Text("All accounts").tag("")
                ForEach(model.snapshot.accounts) { Text($0.name).tag($0.id) }
            }.labelsHidden().padding(12)
        }
    }

    private func sidebarRow(_ name: String, icon: String, count: Int, selection: LibrarySelection) -> some View {
        HStack {
            Label(name, systemImage: icon)
            Spacer(minLength: 4)
            Text(count.formatted()).font(.caption).monospacedDigit().foregroundColor(ink)
        }.foregroundColor(ink).padding(.horizontal, 4).padding(.vertical, 4)
            .background(ContactSelectionSurface(selected: scope == selection), in: RoundedRectangle(cornerRadius: 5))
    }

    private var contactList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2.bold())
                Spacer()
                Text(people.count.formatted()).foregroundColor(ink).monospacedDigit()
            }.padding(18)
            HStack {
                Button {
                    if !groupFilter.isActive, case .group(let id) = scope {
                        groupFilter.included = [id]
                    }
                    showGroupFilter = true
                } label: {
                    Label(groupFilter.isActive ? "Edit group filter" : "Group filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $showGroupFilter, arrowEdge: .bottom) {
                    GroupFilterPanel(filter: $groupFilter, groups: model.snapshot.groups,
                        accounts: model.snapshot.accounts, colorNumbers: model.familyColorNumbers,
                        matchingCount: people.count, onDone: { showGroupFilter = false })
                }
                Spacer()
                if groupFilter.isActive { Button("Clear") { groupFilter = GroupFilter() } }
            }.padding(.horizontal, 18).padding(.bottom, 10)
            if groupFilter.isActive {
                Text(groupFilter.summary(groups: model.snapshot.groups, accounts: model.snapshot.accounts))
                    .font(.callout).foregroundColor(ink).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(groupFilter.summary(groups: model.snapshot.groups, accounts: model.snapshot.accounts))
                    .padding(.horizontal, 18).padding(.bottom, 12)
            }
            HStack {
                Picker("Sort", selection: Binding(get: { model.sort }, set: { model.changeSort($0) })) {
                    ForEach(ContactSort.allCases) { Text($0.title).tag($0) }
                }.accessibilityLabel("Sort contacts")
                if model.datesLoading { ProgressView().controlSize(.small) }
            }.padding(.horizontal, 18).padding(.bottom, 12)
            if model.sort.usesDates {
                if let error = model.datesError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(error).font(.caption).foregroundColor(ink)
                        Button("Retry card dates") { model.requestSortDates() }.font(.caption)
                    }.padding(.horizontal, 18).padding(.bottom, 12)
                } else if !model.datesLoading {
                    let missing = people.filter { model.sort.date(for: $0.id, in: model.cardDates) == nil }.count
                    if missing > 0 { Text("Dates unavailable for \(missing) contacts (shown last).")
                        .font(.caption).foregroundColor(ink).padding(.horizontal, 18).padding(.bottom, 12) }
                }
            }
            Divider()
            HStack(spacing: 10) {
                Button {
                    if !people.isEmpty && selectedIDs == Set(people.map(\.id)) { selectedIDs = [] }
                    else { selectedIDs = Set(people.map(\.id)) }
                } label: {
                    Image(systemName: selectedIDs.isEmpty ? "square" : selectedIDs == Set(people.map(\.id)) ? "checkmark.square.fill" : "minus.square.fill")
                }.accessibilityLabel("Select or deselect all visible contacts")
                Text("\(selectedIDs.count) selected").font(.callout)
                Spacer()
                if !selectedIDs.isEmpty {
                    Button("Groups for selected…") { bulkSelection = BulkSelection(ids: selectedIDs) }.disabled(model.busy)
                    Button("Clear") { selectedIDs = [] }
                }
            }.padding(.horizontal, 18).padding(.vertical, 8)
            List(selection: $selectedIDs) {
                ForEach(people) { person in
                    HStack(alignment: .top, spacing: 4) {
                        Button {
                            if selectedIDs.contains(person.id) { selectedIDs.remove(person.id) }
                            else { selectedIDs.insert(person.id) }
                        } label: {
                            Image(systemName: selectedIDs.contains(person.id) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18)).foregroundColor(ink).padding(.top, 16)
                        }.buttonStyle(.plain).accessibilityLabel("Select \(person.name)")
                            .accessibilityValue(selectedIDs.contains(person.id) ? "Selected" : "Not selected")
                        ContactRow(person: person, groups: model.snapshot.groups(for: person), colorNumbers: model.familyColorNumbers,
                        selected: selectedIDs.contains(person.id),
                        dateLabel: model.sort.usesDates ? model.sort.dateLabel : nil,
                        date: model.sort.date(for: person.id, in: model.cardDates))
                    }
                        .tag(person.id)
                        .contextMenu {
                            Button("Edit in Apple Contacts…") { model.selectedID = person.id; model.editSelected() }.disabled(!model.live)
                            Button("Delete contact…", role: .destructive) { model.prepareDelete(person) }.disabled(!model.live || model.busy)
                        }
                }
            }.listStyle(.inset)
                .overlay {
                    if people.isEmpty {
                        ContentUnavailableView("No contacts here", systemImage: "person.crop.circle",
                            description: Text(search.isEmpty ? "Try another view or account." : "Try another name, company, group, phone or email.").foregroundColor(ink))
                    }
                }
        }.background(AppTextSurface())
    }

    private func clearHiddenSelection() {
        selectedIDs.formIntersection(Set(people.map(\.id)))
        if let id = model.selectedID, !people.contains(where: { $0.id == id }) { model.selectedID = nil }
    }

    private func deletionConfirmation(_ preview: DeletePreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete \(preview.name)?").font(.title2)
            Text("Account: \(preview.account)")
            Text("This deletes the card from this account and its synced devices. It cannot be undone in this app.")
            HStack {
                Spacer()
                Button("Cancel") { model.deletion = nil }.keyboardShortcut(.cancelAction)
                Button("Delete contact", role: .destructive) { model.confirmDelete(preview) }
            }
        }.padding(24).frame(width: 440)
    }
}


private struct BulkSelection: Identifiable, Equatable {
    let id = UUID()
    let ids: Set<String>
}
