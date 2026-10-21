import SwiftUI

// Draw prompts ourselves: AppKit's native placeholder colors ignore SwiftUI's
// foreground color and become low-contrast gray in an inactive control.
struct AccessibleSearchField: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    let title: String
    var symbol = "magnifyingglass"
    private var ink: Color { AccessibleText.ink(for: scheme) }
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundColor(ink).accessibilityHidden(true)
            ZStack(alignment: .leading) {
                TextField("", text: $text).textFieldStyle(.plain).foregroundColor(ink).accessibilityLabel(title)
                if text.isEmpty { Text(title).foregroundColor(ink).allowsHitTesting(false).accessibilityHidden(true) }
            }
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(ink) }
                    .buttonStyle(.plain).accessibilityLabel("Clear \(title.lowercased())")
            }
        }.font(.system(size: 13)).padding(.horizontal, 9).padding(.vertical, 7)
            .background(AppTextSurface(), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ink.opacity(0.4), lineWidth: 1))
    }
}

struct AccessibleSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

struct AccessibleSegments<Value: Hashable>: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: Value
    let options: [AccessibleSegmentOption<Value>]
    let label: String
    private var ink: Color { AccessibleText.ink(for: scheme) }
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                Button { selection = option.value } label: {
                    Text(option.title).font(.system(size: 13, weight: selection == option.value ? .semibold : .regular))
                        .foregroundColor(ink).frame(maxWidth: .infinity).padding(.horizontal, 6).padding(.vertical, 5)
                        .background(ContactSelectionSurface(selected: selection == option.value), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selection == option.value ? Color.accentColor : ink.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(label): \(option.title)")
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }.accessibilityElement(children: .contain)
    }
}

struct AccessibleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        let ink = AccessibleText.ink(for: scheme)
        return configuration.label.foregroundColor(ink)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(ContactSelectionSurface(selected: primary || configuration.isPressed), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(primary ? Color.accentColor : ink.opacity(0.45), lineWidth: 1))
    }
}
