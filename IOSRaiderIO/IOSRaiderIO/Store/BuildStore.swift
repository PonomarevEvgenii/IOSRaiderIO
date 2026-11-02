import Foundation
import Observation

/// Progress of a spec screen load, shown in the UI.
struct LoadProgress: Equatable {
    let message: String
    let completed: Int
    let total: Int
}

/// Result of a spec screen load.
struct SpecResult {
    let players: [TopPlayer]
    let requestedCount: Int
    let build: PopularBuild
}

enum SpecLoadState {
    case idle
    case loading(LoadProgress)
    case loaded(SpecResult)
    case failed(APIError)
}

enum ProfileLoadState {
    case idle
    case loading
    case loaded(CharacterProfile)
    case failed(APIError)
}

/// The single shared model. Created once in `MyApp` and injected with `.environment`.
@Observable
final class BuildStore {
    /// Highest expansion id verified to have seasons (11 = Midnight). The next id is probed first
    /// so a new expansion is picked up automatically.
    static let knownLatestExpansionId = 11

    let classes: [GameClass]
    let classesLoadError: String?

    /// The region is saved to `settings` on every change and restored at launch.
    var filters = Filters() {
        didSet {
            guard filters.region != oldValue.region else { return }
            settings?.set(filters.region.rawValue, forKey: AppSettings.regionKey)
        }
    }

    private(set) var favorites: [TopPlayer] = []
    private(set) var specStates: [SpecQuery: SpecLoadState] = [:]
    private(set) var profileStates: [String: ProfileLoadState] = [:]
    /// Full talent trees by spec id; empty until loaded.
    private(set) var talentTrees: [Int: SpecTalentTree] = [:]
    /// Set when the tree file could not be loaded; trees then show only the chosen talents.
    private(set) var talentTreesError: APIError?

    // Session caches (not observed; they only feed the observed states above).
    @ObservationIgnored private let client: any RaiderIOClient
    @ObservationIgnored private let favoritesStorage: any FavoritesStorage
    /// Where the chosen region is persisted; nil = not persisted (previews).
    @ObservationIgnored private let settings: UserDefaults?
    @ObservationIgnored private var season: Season?
    @ObservationIgnored private var rankingsCache: [String: SpecRankingsResponse] = [:]
    @ObservationIgnored private var profileCache: [String: CharacterProfile] = [:]
    /// Players Raider.IO doesn't know; cached so they aren't requested again.
    @ObservationIgnored private var missingProfiles: Set<String> = []
    /// Identifies the newest load per query so a cancelled, older load can't overwrite its state.
    @ObservationIgnored private var activeLoads: [SpecQuery: Int] = [:]
    @ObservationIgnored private var loadCounter = 0
    /// Shared download so several screens asking at once trigger one request.
    @ObservationIgnored private var talentTreesTask: Task<[Int: SpecTalentTree], Error>?

    init(
        client: any RaiderIOClient = LiveRaiderIOClient(),
        favoritesStorage: any FavoritesStorage = UserDefaultsFavoritesStorage(),
        classesBundle: Bundle = .main,
        settings: UserDefaults? = .standard
    ) {
        self.client = client
        self.favoritesStorage = favoritesStorage
        self.settings = settings
        do {
            classes = try ClassCatalog.load(from: classesBundle)
            classesLoadError = nil
        } catch {
            classes = []
            classesLoadError = String(describing: error)
        }
        favorites = favoritesStorage.load()
        if let saved = settings?.string(forKey: AppSettings.regionKey), let region = RegionFilter(rawValue: saved) {
            filters.region = region
        }
    }

    // MARK: - Lookups

    func query(for selection: SpecSelection) -> SpecQuery {
        SpecQuery(
            classId: selection.gameClass.id,
            specId: selection.spec.id,
            classSlug: selection.gameClass.slug,
            specSlug: selection.spec.slug,
            region: filters.region,
            playerCount: filters.playerCount
        )
    }

    func specState(for query: SpecQuery) -> SpecLoadState {
        specStates[query] ?? .idle
    }

    func profileState(for key: PlayerKey) -> ProfileLoadState {
        profileStates[key.id] ?? .idle
    }

    func cachedProfile(for key: PlayerKey) -> CharacterProfile? {
        profileCache[key.id]
    }

    func gameClass(id: Int) -> GameClass? {
        classes.first { $0.id == id }
    }

    // MARK: - Spec loading

    /// Loads top players and the pick-rate build for `query`.
    /// Does nothing if this query is already loaded (no refetch when navigating back and forth).
    /// Cancelling the calling task (leaving the screen) stops the load and resets it to `.idle`.
    func loadSpec(_ query: SpecQuery) async {
        if case .loaded = specState(for: query) { return }

        loadCounter += 1
        let token = loadCounter
        activeLoads[query] = token
        func update(_ state: SpecLoadState) {
            guard activeLoads[query] == token else { return }
            specStates[query] = state
        }

        update(.loading(LoadProgress(message: "Loading current season…", completed: 0, total: 0)))
        do {
            let season = try await currentSeason()

            // 1. The spec leaderboard is sorted by M+ score, so its first entries are the top players.
            update(.loading(LoadProgress(message: "Loading the \(query.region.title) leaderboard…", completed: 0, total: 0)))
            let rankings = try await specRankings(season: season.slug, query: query)
            var seen = Set<String>()
            let players = rankings.rankings.rankedCharacters
                .map(\.topPlayer)
                .filter { seen.insert($0.id).inserted }
                .prefix(query.playerCount)
                .map { $0 }

            // 2. Load talents for every player (concurrency is limited inside the client).
            let talents = try await loadTalents(for: players) { done in
                update(.loading(LoadProgress(
                    message: "Loading talents (\(done) of \(players.count) players)…",
                    completed: done, total: players.count
                )))
            }

            let build = PickRateAggregator.aggregate(talents, specId: query.specId)
            update(.loaded(SpecResult(
                players: players,
                requestedCount: query.playerCount,
                build: build
            )))
        } catch is CancellationError {
            update(.idle)
        } catch let error as APIError {
            update(.failed(error))
        } catch {
            update(Task.isCancelled ? .idle : .failed(.transport(error.localizedDescription)))
        }
        if activeLoads[query] == token { activeLoads[query] = nil }
    }

    /// Returns one entry per player, `nil` when the profile is unavailable.
    /// Stops with an error only for problems that affect every request (offline, rate limit).
    private func loadTalents(
        for players: [TopPlayer],
        progress: (Int) -> Void
    ) async throws -> [PlayerTalents?] {
        var results: [String: PlayerTalents?] = [:]
        var pending: [PlayerKey] = []
        for player in players {
            if let cached = profileCache[player.id] {
                results[player.id] = cached.talents
            } else if missingProfiles.contains(player.id) {
                results[player.id] = .some(nil)
            } else {
                pending.append(player.key)
            }
        }
        progress(results.count)

        let client = client
        try await withThrowingTaskGroup(of: (PlayerKey, Result<CharacterProfile, APIError>).self) { group in
            for key in pending {
                group.addTask {
                    do {
                        return (key, .success(try await client.profile(for: key)))
                    } catch let error as APIError {
                        return (key, .failure(error))
                    }
                }
            }
            for try await (key, result) in group {
                switch result {
                case .success(let profile):
                    profileCache[key.id] = profile
                    results[key.id] = profile.talents
                case .failure(let error):
                    if error.abortsBatch { throw error }
                    if error == .notFound { missingProfiles.insert(key.id) }
                    results[key.id] = .some(nil)
                }
                progress(results.count)
            }
        }
        return players.map { results[$0.id] ?? nil }
    }

    // MARK: - Player loading

    func loadProfile(for key: PlayerKey) async {
        if let cached = profileCache[key.id] {
            profileStates[key.id] = .loaded(cached)
            return
        }
        profileStates[key.id] = .loading
        do {
            let profile = try await client.profile(for: key)
            profileCache[key.id] = profile
            profileStates[key.id] = .loaded(profile)
        } catch is CancellationError {
            profileStates[key.id] = .idle
        } catch let error as APIError {
            profileStates[key.id] = .failed(error)
        } catch {
            profileStates[key.id] = Task.isCancelled ? .idle : .failed(.transport(error.localizedDescription))
        }
    }

    // MARK: - Talent trees

    /// Downloads the full talent trees once per session (~3 MB, all specs).
    func loadTalentTrees() async {
        if !talentTrees.isEmpty { return }
        let task: Task<[Int: SpecTalentTree], Error>
        if let existing = talentTreesTask {
            task = existing
        } else {
            let client = client
            task = Task {
                let trees = try await client.talentTrees()
                return Dictionary(trees.map { ($0.specId, $0) }, uniquingKeysWith: { first, _ in first })
            }
            talentTreesTask = task
        }
        do {
            talentTrees = try await task.value
            talentTreesError = nil
        } catch let error as APIError {
            talentTreesTask = nil
            talentTreesError = error
        } catch {
            talentTreesTask = nil
            if !Task.isCancelled { talentTreesError = .transport(error.localizedDescription) }
        }
    }

    // MARK: - Cached requests

    private func currentSeason() async throws -> Season {
        if let season { return season }
        for expansion in [Self.knownLatestExpansionId + 1, Self.knownLatestExpansionId] {
            let data = try await client.staticData(expansionId: expansion)
            if let found = Season.current(in: data.seasons) {
                season = found
                return found
            }
        }
        throw APIError.server(status: 200, message: "No current Mythic+ season found")
    }

    private func specRankings(season: String, query: SpecQuery) async throws -> SpecRankingsResponse {
        let key = "\(season)/\(query.region.rawValue)/\(query.classSlug)/\(query.specSlug)"
        if let cached = rankingsCache[key] { return cached }
        let fetched = try await client.specRankings(
            season: season, region: query.region,
            classSlug: query.classSlug, specSlug: query.specSlug, page: 0
        )
        rankingsCache[key] = fetched
        return fetched
    }

    // MARK: - Favorites

    func isFavorite(_ playerId: String) -> Bool {
        favorites.contains { $0.id == playerId }
    }

    func toggleFavorite(_ player: TopPlayer) {
        if isFavorite(player.id) {
            removeFavorites(ids: [player.id])
        } else {
            favorites.append(player)
            favoritesStorage.save(favorites)
        }
    }

    /// Removes by id, so it is safe to call from a sorted or filtered list.
    func removeFavorites(ids: some Collection<String>) {
        let ids = Set(ids)
        favorites.removeAll { ids.contains($0.id) }
        favoritesStorage.save(favorites)
    }
}
