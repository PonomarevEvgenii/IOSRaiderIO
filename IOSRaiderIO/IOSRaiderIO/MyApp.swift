import SwiftUI

@main struct MyApp: App {
    /// The only BuildStore instance; every view reads it via `@Environment(BuildStore.self)`.
    @State private var store = BuildStore()
    /// Written by the Settings tab (same key).
    @AppStorage(AppSettings.darkModeKey) private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
