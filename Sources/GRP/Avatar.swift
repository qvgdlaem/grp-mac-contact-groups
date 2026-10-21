import AppKit
import SwiftUI

struct Avatar: View {
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { AccessibleText.ink(for: scheme) }
    let initials: String
    let photo: Data?
    let size: CGFloat
    var body: some View {
        Group {
            if let photo, let image = NSImage(data: photo) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.09)
                    Text(initials).font(.system(size: size * 0.34, weight: .semibold)).foregroundColor(ink)
                }
            }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
}

