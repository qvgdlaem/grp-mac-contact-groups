import SwiftUI

@main
struct GRPApp: App {
    var body: some Scene {
        WindowGroup("GRP") { ContentView(model: Model(preferences: .standard)) }
            .defaultSize(width: 1580, height: 880)
    }
}
