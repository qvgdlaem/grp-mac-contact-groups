import SwiftUI

// Semantic .primary/.secondary can be translucent. Ordinary app text is always
// opaque black or white; group-family colors are the intentional exception.
enum AccessibleText {
    static func ink(for scheme: ColorScheme) -> Color {
        let value: Double = scheme == .dark ? 1 : 0
        return Color(.sRGB, red: value, green: value, blue: value, opacity: 1)
    }
}

struct AppTextSurface: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.075) : .white
    }
}

struct ContactSelectionSurface: ShapeStyle {
    let selected: Bool
    func resolve(in environment: EnvironmentValues) -> Color {
        if environment.colorScheme == .dark {
            return selected ? Color(red: 0.08, green: 0.19, blue: 0.29) : Color(red: 0.075, green: 0.075, blue: 0.075)
        }
        return selected ? Color(red: 0.88, green: 0.94, blue: 1) : .white
    }
}
