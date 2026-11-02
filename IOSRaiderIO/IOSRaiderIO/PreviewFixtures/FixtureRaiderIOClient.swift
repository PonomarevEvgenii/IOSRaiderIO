import Foundation

/// Serves the real Raider.IO responses saved as JSON fixtures. No network.
/// Lives in the app target so `#Preview`s can use it; the test target reuses it with its own bundle.
nonisolated struct FixtureRaiderIOClient: RaiderIOClient {
    /// Expansion id of `fixture_static_data.json`; other ids return no seasons, like the real API.
    static let fixtureExpansionId = 11

    let staticDataFixture: StaticData
    /// First 10 entries of the world Holy Paladin leaderboard.
    let rankingsFixture: SpecRankingsResponse
    let profileFixture: CharacterProfile
    /// Holy Paladin only (subset of the Raidbots file).
    let talentTreesFixture: [SpecTalentTree]

    init(bundle: Bundle) throws {
        staticDataFixture = try Self.decode("fixture_static_data", in: bundle)
        rankingsFixture = try Self.decode("fixture_spec_rankings", in: bundle)
        profileFixture = try Self.decode("fixture_profile", in: bundle)
        talentTreesFixture = try Self.decode("fixture_talent_trees", in: bundle)
    }

    func talentTrees() async throws -> [SpecTalentTree] {
        talentTreesFixture
    }

    static func decode<T: Decodable>(_ name: String, in bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw APIError.decoding("Missing fixture \(name).json")
        }
        return try RaiderIODecoding.decode(T.self, from: Data(contentsOf: url))
    }

    func staticData(expansionId: Int) async throws -> StaticData {
        expansionId == Self.fixtureExpansionId ? staticDataFixture : StaticData(seasons: [])
    }

    /// The fixture is page 0 of the world Holy Paladin leaderboard; anything else is empty.
    func specRankings(season: String, region: RegionFilter, classSlug: String, specSlug: String, page: Int) async throws -> SpecRankingsResponse {
        guard region == .world, classSlug == "paladin", specSlug == "holy", page == 0 else {
            return SpecRankingsResponse(rankings: SpecRankings(rankedCharacters: []))
        }
        return rankingsFixture
    }

    /// Only the character saved in the fixture exists; everyone else is "not found".
    func profile(for key: PlayerKey) async throws -> CharacterProfile {
        let fixture = profileFixture
        guard key.region.caseInsensitiveCompare(fixture.region) == .orderedSame,
              key.name.caseInsensitiveCompare(fixture.name) == .orderedSame else {
            throw APIError.notFound
        }
        return fixture
    }
}

extension BuildStore {
    /// Store for `#Preview`s, backed by the JSON fixtures in the app bundle.
    static func preview(favorites: [TopPlayer] = []) -> BuildStore {
        let client: any RaiderIOClient
        do {
            client = try FixtureRaiderIOClient(bundle: .main)
        } catch {
            preconditionFailure("Preview fixtures missing: \(error)")
        }
        return BuildStore(client: client, favoritesStorage: InMemoryFavoritesStorage(favorites), settings: nil)
    }
}

extension SpecSelection {
    /// Holy Paladin: matches the rankings fixture, and the profile fixture is a Holy Paladin.
    static var previewHolyPaladin: SpecSelection {
        let paladin = GameClass(
            id: 2, name: "Paladin", colorHex: "F48CBA", icon: "classicon_paladin",
            specs: [Spec(id: 65, name: "Holy", role: .healer, icon: "spell_holy_holybolt")]
        )
        return SpecSelection(gameClass: paladin, spec: paladin.specs[0])
    }
}

extension TopPlayer {
    /// The character from `fixture_profile.json`.
    static let previewFixturePlayer = TopPlayer(
        key: PlayerKey(region: "eu", realmSlug: "draenor", name: "Moadzarella"),
        name: "Moadzarella", realmName: "Draenor", regionShortName: "EU",
        classId: 2, className: "Paladin", specId: 65, specName: "Holy",
        bestKeyLevel: 24, runCount: 8,
        score: 4334.09, rank: 5 // values from fixture_spec_rankings.json
    )
}
