import SwiftUI

@main
struct KBZHUApp: App {
    init() {
        Golos.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .preferredColorScheme(.light) // the design is a light-only theme
        }
    }
}
