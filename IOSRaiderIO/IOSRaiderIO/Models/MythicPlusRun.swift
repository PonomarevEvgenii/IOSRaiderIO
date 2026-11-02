import Foundation

/// Response of `GET https://raider.io/api/mythic-plus/rankings/specs` (the site's spec leaderboard,
/// public but undocumented). 100 characters per page, sorted by M+ score.
nonisolated struct SpecRankingsResponse: Decodable, Sendable {
    let rankings: SpecRankings
}

nonisolated struct SpecRankings: Decodable, Sendable {
    let rankedCharacters: [RankedCharacter]
}

nonisolated struct RankedCharacter: Decodable, Sendable {
    let rank: Int
    let score: Double
    let character: RosterCharacter
    let runs: [RankedRun]?

    var topPlayer: TopPlayer {
        TopPlayer(
            key: character.playerKey,
            name: character.name,
            realmName: character.realm.name,
            regionShortName: character.region.shortName,
            classId: character.characterClass.id,
            className: character.characterClass.name,
            specId: character.spec?.id ?? 0,
            specName: character.spec?.name ?? "",
            bestKeyLevel: runs?.map(\.mythicLevel).max() ?? 0,
            runCount: runs?.count ?? 0,
            score: score,
            rank: rank
        )
    }
}

nonisolated struct RankedRun: Decodable, Sendable {
    let mythicLevel: Int
}

nonisolated struct RosterCharacter: Decodable, Sendable {
    let id: Int
    let name: String
    let characterClass: NamedReference
    let spec: NamedReference?
    let realm: RealmReference
    let region: RegionReference

    enum CodingKeys: String, CodingKey {
        case id, name, spec, realm, region
        case characterClass = "class"
    }

    var playerKey: PlayerKey {
        PlayerKey(region: region.slug, realmSlug: realm.slug, name: name)
    }
}

nonisolated struct NamedReference: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct RealmReference: Decodable, Hashable, Sendable {
    let name: String
    let slug: String
}

nonisolated struct RegionReference: Decodable, Hashable, Sendable {
    let slug: String
    let shortName: String
}
