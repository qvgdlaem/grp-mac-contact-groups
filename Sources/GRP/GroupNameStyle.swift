import AppKit
import SwiftUI

// Always draw colored names against this explicit opaque surface, including
// selected sidebar rows, so selection/accent colors can't destroy text contrast.
struct GroupNameText: View {
    @Environment(\.colorScheme) private var scheme
    let group: ContactGroup
    let colorNumber: Int
    var surface: Bool = false
    private var background: NSColor {
        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)!
        var resolved = NSColor.textBackgroundColor
        appearance.performAsCurrentDrawingAppearance { resolved = NSColor.textBackgroundColor.usingColorSpace(.sRGB) ?? .white }
        return resolved
    }
    private var ink: Color {
        if GroupColorLibrary.color(number: colorNumber).hex == 0 {
            return scheme == .dark ? .white : .black
        }
        let bg = background
        let rgb = GroupColorLibrary.color(number: colorNumber).rgb.readable(on: PaletteRGB(r: bg.redComponent, g: bg.greenComponent, b: bg.blueComponent))
        return Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
    }
    var body: some View {
        Text(group.name).fontWeight(.medium).foregroundStyle(ink)
            .padding(.horizontal, surface ? 5 : 0).padding(.vertical, surface ? 2 : 0)
            .background(Color(nsColor: background), in: RoundedRectangle(cornerRadius: 4))
            .help("Family: \(group.groupFamily.name) · Color \(colorNumber): \(GroupColorLibrary.color(number: colorNumber).name)")
            .accessibilityValue("Family \(group.groupFamily.name), color \(colorNumber), \(GroupColorLibrary.color(number: colorNumber).name)")
    }
}

// The same label treatment in the rail, contact rows and open cards.
// Row/rail tags are informational; only the open-card tag has a remove button.
struct GroupTag: View {
    @Environment(\.colorScheme) private var scheme
    let group: ContactGroup
    let colorNumber: Int
    var compact = false
    var onRemove: (() -> Void)?
    var disabled = false

    var body: some View {
        HStack(spacing: 7) {
            GroupNameText(group: group, colorNumber: colorNumber)
                .font(.system(size: compact ? 13 : 14, weight: .medium))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AccessibleText.ink(for: scheme))
                }.buttonStyle(.plain).disabled(disabled)
                    .help("Remove from \(group.name)")
                    .accessibilityLabel("Remove from \(group.name)")
            }
        }
        .padding(.horizontal, compact ? 6 : 9).padding(.vertical, compact ? 2 : 4)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
    }
}
