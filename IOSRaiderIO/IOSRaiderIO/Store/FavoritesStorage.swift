import Foundation

protocol FavoritesStorage {
    func load() -> [TopPlayer]
    func save(_ favorites: [TopPlayer])
}

/// Persists favorites as JSON in UserDefaults.
struct UserDefaultsFavoritesStorage: FavoritesStorage {
    var defaults: UserDefaults = .standard
    var key = "favoritePlayers.v1"

    func load() -> [TopPlayer] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([TopPlayer].self, from: data)) ?? []
    }

    func save(_ favorites: [TopPlayer]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Non-persistent storage for previews and tests.
final class InMemoryFavoritesStorage: FavoritesStorage {
    private(set) var stored: [TopPlayer]

    init(_ initial: [TopPlayer] = []) {
        stored = initial
    }

    func load() -> [TopPlayer] { stored }
    func save(_ favorites: [TopPlayer]) { stored = favorites }
}
