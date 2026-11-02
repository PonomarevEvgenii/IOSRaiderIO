import Foundation
import Testing
@testable import MyApp

@MainActor
struct FavoritesTests {
    private func makeStore(_ storage: InMemoryFavoritesStorage = InMemoryFavoritesStorage()) throws -> BuildStore {
        BuildStore(client: try TestFixtures.client(), favoritesStorage: storage, classesBundle: Bundle(for: BuildStore.self))
    }

    @Test func addAndRemoveById() throws {
        let storage = InMemoryFavoritesStorage()
        let store = try makeStore(storage)
        let a = Make.player("Alpha")
        let b = Make.player("Bravo")

        store.toggleFavorite(a)
        store.toggleFavorite(b)
        #expect(store.favorites.map(\.id) == [a.id, b.id])
        #expect(storage.stored.map(\.id) == [a.id, b.id])

        store.toggleFavorite(a) // unstar
        #expect(store.favorites.map(\.id) == [b.id])
        #expect(store.isFavorite(a.id) == false)
        #expect(store.isFavorite(b.id))
    }

    @Test func removeByIdIsIndependentOfDisplayOrder() throws {
        let store = try makeStore()
        let players = ["Charlie", "Alpha", "Bravo"].map { Make.player($0) }
        players.forEach(store.toggleFavorite)

        // The list shows favorites sorted by name; deleting row 0 of that list must delete "Alpha",
        // even though "Alpha" is at index 1 in storage order.
        let displayed = store.favorites.sorted { $0.name < $1.name }
        store.removeFavorites(ids: IndexSet(integer: 0).map { displayed[$0].id })
        #expect(store.favorites.map(\.name) == ["Charlie", "Bravo"])
    }

    @Test func sameCharacterDifferentCasingIsSameFavorite() throws {
        let store = try makeStore()
        store.toggleFavorite(Make.player("Alpha"))
        #expect(store.isFavorite(Make.player("ALPHA").id))
    }

    @Test func regionPersistsAcrossStores() throws {
        let suite = "region-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = BuildStore(client: try TestFixtures.client(), favoritesStorage: InMemoryFavoritesStorage(), settings: defaults)
        #expect(first.filters.region == .world)
        first.filters.region = .eu

        let second = BuildStore(client: try TestFixtures.client(), favoritesStorage: InMemoryFavoritesStorage(), settings: defaults)
        #expect(second.filters.region == .eu)
    }

    @Test func favoritesPersistAcrossStores() throws {
        let suite = "favorites-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = UserDefaultsFavoritesStorage(defaults: defaults)

        let first = BuildStore(client: try TestFixtures.client(), favoritesStorage: storage)
        first.toggleFavorite(Make.player("Alpha"))

        let second = BuildStore(client: try TestFixtures.client(), favoritesStorage: storage)
        #expect(second.favorites.map(\.name) == ["Alpha"])
    }
}

@MainActor
struct BuildStoreLoadingTests {
    private let holyPaladin = SpecQuery(
        classId: 2, specId: 65, classSlug: "paladin", specSlug: "holy", region: .world, playerCount: 5
    )

    @Test func loadsTopFivePlayersFromLeaderboard() async throws {
        let store = BuildStore(client: try TestFixtures.client(), favoritesStorage: InMemoryFavoritesStorage())
        await store.loadSpec(holyPaladin)
        guard case .loaded(let result) = store.specState(for: holyPaladin) else {
            Issue.record("Expected loaded state, got \(store.specState(for: holyPaladin))")
            return
        }
        // Always the first 5 of the leaderboard, in rank order.
        #expect(result.players.count == 5)
        #expect(result.players.compactMap(\.rank) == [1, 2, 3, 4, 5])
        #expect(result.players.last?.name == "Moadzarella")
        // Only the 5th has a profile fixture; the other 4 are "not found" and skipped.
        #expect(result.build.playersCounted == 1)
        #expect(result.build.playersSkipped == 4)
    }

    @Test func emptyRegionGivesEmptyResult() async throws {
        let store = BuildStore(client: try TestFixtures.client(), favoritesStorage: InMemoryFavoritesStorage())
        let query = SpecQuery(classId: 2, specId: 65, classSlug: "paladin", specSlug: "holy", region: .kr, playerCount: 5)
        await store.loadSpec(query)
        guard case .loaded(let result) = store.specState(for: query) else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(result.players.isEmpty)
        #expect(result.build.playersCounted == 0)
    }

    @Test func secondLoadUsesCache() async throws {
        let stub = StubRaiderIOClient(base: try TestFixtures.client())
        let store = BuildStore(client: stub, favoritesStorage: InMemoryFavoritesStorage())
        await store.loadSpec(holyPaladin)
        let rankingsCalls = stub.rankingsCalls
        let profileCalls = stub.profileCalls
        await store.loadSpec(holyPaladin)
        #expect(stub.rankingsCalls == rankingsCalls)
        #expect(stub.profileCalls == profileCalls)

        // A smaller player count reuses the cached leaderboard and profiles.
        await store.loadSpec(SpecQuery(classId: 2, specId: 65, classSlug: "paladin", specSlug: "holy", region: .world, playerCount: 3))
        #expect(stub.rankingsCalls == rankingsCalls)
        #expect(stub.profileCalls == profileCalls)
    }

    @Test func rateLimitShowsError() async throws {
        let stub = StubRaiderIOClient(base: try TestFixtures.client(), profileError: .rateLimited)
        let store = BuildStore(client: stub, favoritesStorage: InMemoryFavoritesStorage())
        await store.loadSpec(holyPaladin)
        guard case .failed(let error) = store.specState(for: holyPaladin) else {
            Issue.record("Expected failed state")
            return
        }
        #expect(error == .rateLimited)
    }

    @Test func offlineShowsError() async throws {
        let stub = StubRaiderIOClient(base: try TestFixtures.client(), rankingsError: .offline)
        let store = BuildStore(client: stub, favoritesStorage: InMemoryFavoritesStorage())
        await store.loadSpec(holyPaladin)
        guard case .failed(let error) = store.specState(for: holyPaladin) else {
            Issue.record("Expected failed state")
            return
        }
        #expect(error == .offline)
    }

    @Test func serverErrorForOneProfileSkipsThatPlayer() async throws {
        let stub = StubRaiderIOClient(base: try TestFixtures.client(), profileError: .server(status: 500, message: nil))
        let store = BuildStore(client: stub, favoritesStorage: InMemoryFavoritesStorage())
        await store.loadSpec(holyPaladin)
        guard case .loaded(let result) = store.specState(for: holyPaladin) else {
            Issue.record("Expected loaded state")
            return
        }
        // The list still shows all 5 players; only the pick rate skips them.
        #expect(result.players.count == 5)
        #expect(result.build.playersCounted == 0)
        #expect(result.build.playersSkipped == 5)
    }

    @Test func cancelledLoadResetsToIdle() async throws {
        let store = BuildStore(client: try TestFixtures.client(), favoritesStorage: InMemoryFavoritesStorage())
        let task = Task { await store.loadSpec(holyPaladin) }
        task.cancel()
        await task.value
        switch store.specState(for: holyPaladin) {
        case .idle, .loaded: break // cancelled in time, or finished before the cancel was observed
        default: Issue.record("Unexpected state \(store.specState(for: holyPaladin))")
        }
    }
}
