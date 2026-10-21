import SwiftUI

struct ContactRow: View {
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { AccessibleText.ink(for: scheme) }
    let person: Person
    let groups: [ContactGroup]
    let colorNumbers: [String: Int]
    let selected: Bool
    let dateLabel: String?
    let date: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(initials: person.initials, photo: nil, size: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(person.name).foregroundColor(ink).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(person.account).foregroundColor(ink).font(.system(size: 12)).lineLimit(1)
                }
                if !person.company.isEmpty {
                    Text(person.company).foregroundColor(ink).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                }
                if groups.isEmpty {
                    Text("No groups assigned").foregroundColor(ink).font(.system(size: 13))
                } else {
                    FlowLayout(spacing: 5) {
                        ForEach(groups) { group in
                            GroupTag(group: group, colorNumber: colorNumbers[group.groupFamily.key] ?? 1, compact: true)
                        }
                    }
                }
                if !person.emails.isEmpty && !person.phones.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            emails.fixedSize(horizontal: true, vertical: false)
                            phones.fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: 5) { emails; phones }
                    }
                } else if !person.emails.isEmpty { emails }
                else if !person.phones.isEmpty { phones }
                if let dateLabel {
                    Text(date.map { "\(dateLabel) \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "\(dateLabel) date unavailable")
                        .font(.system(size: 12))
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundColor(ink)
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ContactSelectionSurface(selected: selected), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
    }

    private var emails: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(person.emails.enumerated()), id: \.offset) { _, email in
                Label { Text(email).fixedSize(horizontal: false, vertical: true) }
                    icon: { Image(systemName: "envelope") }
                    .font(.system(size: 14)).foregroundColor(ink)
            }
        }
    }

    private var phones: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(person.phones.enumerated()), id: \.offset) { _, number in
                Label { Text(number).fixedSize(horizontal: false, vertical: true) }
                    icon: { Image(systemName: "phone") }
                    .font(.system(size: 14)).foregroundColor(ink)
            }
        }
    }

}
