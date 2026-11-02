import Foundation
@testable import MyApp

/// Anchor for locating the test bundle (which contains the Fixtures folder).
final class TestBundleToken {}

enum TestFixtures {
    static let bundle = Bundle(for: TestBundleToken.self)

    static func data(_ name: String) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw APIError.decoding("Missing test fixture \(name).json")
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try RaiderIODecoding.decode(type, from: data(name))
    }

    static func client() throws -> FixtureRaiderIOClient {
        try FixtureRaiderIOClient(bundle: bundle)
    }
}

/// Builds small, readable test inputs.
enum Make {
    static func pick(_ id: Int, _ name: String, tree: TalentTree = .specTree, hero: String? = nil) -> TalentPick {
        TalentPick(id: id, nodeId: id * 10, spellId: id * 100, name: name, icon: nil,
                   rank: 1, maxRank: 1, tree: tree, heroTreeName: hero)
    }

    static func talents(specId: Int = 65, hero: String? = nil, importString: String? = nil, _ picks: [TalentPick]) -> PlayerTalents {
        PlayerTalents(specId: specId, importString: importString, heroTreeName: hero, picks: picks)
    }

    static func player(_ name: String, region: String = "eu", realm: String = "draenor") -> TopPlayer {
        TopPlayer(
            key: PlayerKey(region: region, realmSlug: realm, name: name),
            name: name, realmName: realm.capitalized, regionShortName: region.uppercased(),
            classId: 2, className: "Paladin", specId: 65, specName: "Holy",
            bestKeyLevel: 20, runCount: 1
        )
    }
}

/// Client whose responses are scripted per test (errors, call counting).
nonisolated final class StubRaiderIOClient: RaiderIOClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _profileCalls = 0
    private var _rankingsCalls = 0

    let base: FixtureRaiderIOClient
    let profileError: APIError?
    let rankingsError: APIError?

    init(base: FixtureRaiderIOClient, profileError: APIError? = nil, rankingsError: APIError? = nil) {
        self.base = base
        self.profileError = profileError
        self.rankingsError = rankingsError
    }

    var profileCalls: Int { lock.withLock { _profileCalls } }
    var rankingsCalls: Int { lock.withLock { _rankingsCalls } }

    func staticData(expansionId: Int) async throws -> StaticData {
        try await base.staticData(expansionId: expansionId)
    }

    func specRankings(season: String, region: RegionFilter, classSlug: String, specSlug: String, page: Int) async throws -> SpecRankingsResponse {
        lock.withLock { _rankingsCalls += 1 }
        if let rankingsError { throw rankingsError }
        return try await base.specRankings(season: season, region: region, classSlug: classSlug, specSlug: specSlug, page: page)
    }

    func profile(for key: PlayerKey) async throws -> CharacterProfile {
        lock.withLock { _profileCalls += 1 }
        if let profileError { throw profileError }
        return try await base.profile(for: key)
    }

    func talentTrees() async throws -> [SpecTalentTree] {
        try await base.talentTrees()
    }
}
