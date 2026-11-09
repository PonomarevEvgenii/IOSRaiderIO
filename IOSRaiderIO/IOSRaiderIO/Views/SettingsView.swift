import SwiftUI

struct SettingsView: View {
    @Environment(BuildStore.self) private var store
    /// Same key as `MyApp`, which applies `preferredColorScheme`.
    @AppStorage(AppSettings.darkModeKey) private var isDarkMode = false
    /// Same key as `MyApp`, which applies the locale.
    @AppStorage(AppSettings.languageKey) private var language = AppLanguage.english

    var body: some View {
        // Needed for `$store.filters.region`; the store persists the region on change.
        @Bindable var store = store
        Form {
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
            Section("Appearance") {
                Toggle(isOn: $isDarkMode) {
                    Label("Dark mode", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                }
            }
            Section("Language") {
                Picker(selection: $language) {
                    ForEach(AppLanguage.allCases) { Text(verbatim: $0.nativeName).tag($0) }
                } label: {
                    Label("Language", systemImage: "globe")
                }
            }
            .onChange(of: language, initial: true) { _, newValue in
                // Also used by non-SwiftUI strings and system UI on the next launch.
                UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
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
    static let languageKey = "appLanguage"
}

/// Languages the app is translated into. Raw values are locale identifiers.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case czech = "cs"
    case russian = "ru"

    var id: String { rawValue }

    /// Shown in its own language so it is recognizable whatever language is active.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .czech: "Čeština"
        case .russian: "Русский"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(BuildStore.preview())
}
