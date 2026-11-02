import SwiftUI

struct SettingsView: View {
    @Environment(BuildStore.self) private var store
    /// Same key as `MyApp`, which applies `preferredColorScheme`.
    @AppStorage(AppSettings.darkModeKey) private var isDarkMode = false

    var body: some View {
        // Needed for `$store.filters.region`; the store persists the region on change.
        @Bindable var store = store
        Form {
            Section("Appearance") {
                Toggle(isOn: $isDarkMode) {
                    Label("Dark mode", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                }
            }
            Section {
                Picker("Region", selection: $store.filters.region) {
                    ForEach(RegionFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Leaderboard region")
            } footer: {
                Text("The top \(Filters.playerCount) players of each spec by Mythic+ score in this region. Saved between launches.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground(.gray)
        .navigationTitle("Settings")
    }
}

enum AppSettings {
    static let darkModeKey = "isDarkMode"
    static let regionKey = "leaderboardRegion"
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(BuildStore.preview())
}
