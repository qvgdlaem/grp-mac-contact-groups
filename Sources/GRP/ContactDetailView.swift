import SwiftUI

struct ContactDetailView: View {
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { AccessibleText.ink(for: scheme) }
    @ObservedObject var model: Model
    let person: Person
    private var assigned: [ContactGroup] { model.snapshot.groups(for: person) }
    private var available: [ContactGroup] {
        model.snapshot.groups.filter { $0.accountID == person.accountID && !person.groupIDs.contains($0.id) }
    }
    private var mainSections: [DetailSection] {
        let priority = ["phones", "email", "addresses", "urls", "dates"]
        return priority.compactMap { id in model.details?.sections.first { $0.id == id } }
    }
    private var otherSections: [DetailSection] {
        model.details?.sections.filter { !["phones", "email", "addresses", "urls", "dates"].contains($0.id) } ?? []
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                actions
                HStack(spacing: 20) {
                    Avatar(initials: person.initials, photo: model.details?.photo, size: 92)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(person.name).font(.system(size: 34, weight: .bold)).textSelection(.enabled)
                        Label(person.account, systemImage: "externaldrive").foregroundColor(ink)
                        if !person.company.isEmpty { Text(person.company).foregroundColor(ink) }
                    }
                }
                groupPanel
                if model.detailsLoading { ProgressView("Loading contact details…") }
                if let error = model.detailError {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(error).foregroundColor(ink)
                        Button("Retry contact details") { model.loadDetails() }
                    }
                }
                ForEach(mainSections) { DetailSectionView(section: $0) }
                notes
                ForEach(otherSections) { DetailSectionView(section: $0) }
                metadata
                Text("Cards are shown per account so each group change applies to the right record. Linked cards may appear separately.")
                    .font(.caption).foregroundColor(ink)
            }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(person.id)
        .background(AppTextSurface())
        .foregroundColor(ink)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if model.live {
                Button("Edit in Contacts…") { model.editSelected() }
                    .buttonStyle(AccessibleButtonStyle(primary: true)).disabled(model.busy)
                    .help("Open this exact card in Apple Contacts to edit or add any field")
                if model.busy {
                    Text("Saving changes…").font(.callout).foregroundColor(ink)
                } else {
                    Menu {
                        Button("Open full editor in Apple Contacts…", systemImage: "square.and.pencil") { model.editSelected() }
                        Divider()
                        Button("Delete contact…", systemImage: "trash", role: .destructive) { model.prepareDelete(person) }
                    } label: {
                        Label("Contact actions", systemImage: "ellipsis.circle").foregroundColor(ink)
                    }.frame(maxWidth: 260)
                }
            } else {
                Text("Connect Apple Contacts to edit or delete cards.").font(.callout).foregroundColor(ink)
            }
            Spacer(minLength: 0)
        }
    }

    private var groupPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Groups", systemImage: "folder").font(.headline)
                Spacer()
                Menu {
                    ForEach(available) { group in
                        Button(group.name) { model.setMembership(person, group: group, member: true) }
                    }
                    if available.isEmpty { Text("No other groups in this account") }
                } label: {
                    Label("Add to group", systemImage: "plus")
                }.fixedSize().disabled(available.isEmpty || model.busy)
            }
            if assigned.isEmpty {
                Text("No groups assigned").foregroundColor(ink)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(assigned) { group in
                        GroupTag(group: group, colorNumber: model.colorNumber(for: group),
                            onRemove: { model.setMembership(person, group: group, member: false) },
                            disabled: model.busy)
                    }
                }
            }
            if let error = model.membershipError {
                Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled)
            }
            Text(model.live ? "Changes save immediately to Apple Contacts." : "Sample memberships only. Connect Apple Contacts to make live changes.")
                .font(.caption).foregroundColor(ink)
            if model.snapshot.groups.allSatisfy({ $0.accountID != person.accountID }) {
                Text("Create a list in Apple Contacts, then refresh. Some account providers do not support editable lists.")
                    .font(.caption).foregroundColor(ink)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.14), lineWidth: 1))
    }

    @ViewBuilder private var notes: some View {
        if let extras = model.extras {
            if !extras.note.isEmpty {
                DetailSectionView(section: DetailSection(id: "notes", title: "Notes", values: [.init(label: "Notes", value: extras.note)]))
            }
        } else if let error = model.extrasError {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes & additional fields").font(.headline)
                Text(error).font(.callout).foregroundColor(ink)
                Button("Retry notes & additional fields") { model.retryExtras() }
            }
        }
    }

    private var metadata: some View {
        DisclosureGroup("Card information & all exported fields") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Card ID: \(person.id)").font(.caption).textSelection(.enabled)
                if let extras = model.extras {
                    if let created = extras.created { Text("Created: \(created.formatted(date: .long, time: .shortened))").font(.caption) }
                    if let modified = extras.modified { Text("Modified: \(modified.formatted(date: .long, time: .shortened))").font(.caption) }
                    if !extras.vcard.isEmpty {
                        Text("The complete card exported by Apple Contacts, including any provider-specific fields.").font(.caption).foregroundColor(ink)
                        ScrollView([.horizontal, .vertical]) {
                            Text(extras.vcard).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(height: 220)
                    }
                } else { Text("Additional fields appear after notes access is allowed.").font(.caption).foregroundColor(ink) }
            }.padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading)
        }.font(.callout).foregroundColor(ink)
    }
}

struct DetailSectionView: View {
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { AccessibleText.ink(for: scheme) }
    let section: DetailSection
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(section.values) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.label.uppercased()).font(.system(size: 12, weight: .semibold))
                        .tracking(1).foregroundColor(ink)
                    Text(entry.value).font(.system(size: 16)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 600).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews, width: bounds.width)
        for (index, item) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + item.minX, y: bounds.minY + item.minY),
                proposal: ProposedViewSize(item.size))
        }
    }
    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: max(width, 1), height: nil))
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
