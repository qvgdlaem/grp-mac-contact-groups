import Foundation

struct GroupFamily: Equatable, Sendable {
    let key: String
    let name: String
    init(groupName: String) {
        name = groupName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "Unnamed"
        key = name.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct PaletteRGB: Equatable, Sendable {
    let r: Double, g: Double, b: Double
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 255) / 255
        g = Double((hex >> 8) & 255) / 255
        b = Double(hex & 255) / 255
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    private var luminance: Double {
        func linear(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
    func contrast(with other: Self) -> Double {
        (max(luminance, other.luminance) + 0.05) / (min(luminance, other.luminance) + 0.05)
    }
    // Preserve the palette hue where possible; raw yellow/sky blue cannot serve
    // as small text on white. The base swatch stays exact in the color library.
    func readable(on background: Self, minimumContrast: Double = 4.5) -> Self {
        guard contrast(with: background) < minimumContrast else { return self }
        let black = Self(0x000000), white = Self(0xFFFFFF)
        let target = black.contrast(with: background) >= white.contrast(with: background) ? black : white
        for step in 1...100 {
            let t = Double(step) / 100
            let color = Self(r: r + (target.r - r) * t, g: g + (target.g - g) * t, b: b + (target.b - b) * t)
            if color.contrast(with: background) >= minimumContrast { return color }
        }
        return target
    }
}

struct GroupPaletteColor: Identifiable, Sendable {
    let id: Int
    let name: String
    let hex: UInt32
    var rgb: PaletteRGB { PaletteRGB(hex) }
}

enum GroupColorLibrary {
    // Stable public numbers. Append new entries; never renumber existing ones.
    // Palette attribution: Masataka Okabe and Kei Ito, Color Universal Design.
    static let colors: [GroupPaletteColor] = [
        .init(id: 1, name: "Blue", hex: 0x0072B2),
        .init(id: 2, name: "Orange", hex: 0xE69F00),
        .init(id: 3, name: "Bluish green", hex: 0x009E73),
        .init(id: 4, name: "Reddish purple", hex: 0xCC79A7),
        .init(id: 5, name: "Sky blue", hex: 0x56B4E9),
        .init(id: 6, name: "Vermilion", hex: 0xD55E00),
        .init(id: 7, name: "Yellow", hex: 0xF0E442),
        .init(id: 8, name: "Black", hex: 0x000000)
    ]
    static func color(number: Int) -> GroupPaletteColor { colors.first { $0.id == number } ?? colors[0] }

    static func assigning(families: [String], saved: [String: Int], library: [GroupPaletteColor] = colors) -> [String: Int] {
        guard !library.isEmpty else { return saved }
        let valid = Set(library.map(\.id))
        var assignments = saved.filter { valid.contains($0.value) }
        var usage = Dictionary(uniqueKeysWithValues: library.map { ($0.id, 0) })
        for number in assignments.values { usage[number, default: 0] += 1 }
        for family in Set(families).sorted() where assignments[family] == nil {
            let number = library.min {
                usage[$0.id, default: 0] == usage[$1.id, default: 0] ? $0.id < $1.id : usage[$0.id, default: 0] < usage[$1.id, default: 0]
            }!.id
            assignments[family] = number
            usage[number, default: 0] += 1
        }
        return assignments
    }
}

extension ContactGroup {
    var groupFamily: GroupFamily { GroupFamily(groupName: name) }
}
