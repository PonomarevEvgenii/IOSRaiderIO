import Foundation

/// Response of `GET /api/v1/characters/profile?fields=talents:categorized,mythic_plus_scores_by_season:current`.
nonisolated struct CharacterProfile: Decodable, Sendable {
    let name: String
    let region: String
    let realm: String
    let activeSpecName: String?
    let profileUrl: URL?
    /// Character avatar from render.worldofwarcraft.com (public image).
    let thumbnailUrl: URL?
    let mythicPlusScoresBySeason: [SeasonScores]?
    let talentLoadout: TalentLoadoutDTO?
    /// `fields=mythic_plus_best_runs`: best timed/untimed key per dungeon this season.
    let mythicPlusBestRuns: [BestRun]?

    /// Overall M+ score for the current season, if Raider.IO returned one.
    var score: Double? { mythicPlusScoresBySeason?.first?.scores["all"] }

    var talents: PlayerTalents { PlayerTalents(dto: talentLoadout) }
}

nonisolated struct BestRun: Decodable, Identifiable, Sendable {
    let keystoneRunId: Int
    let dungeon: String
    let shortName: String?
    let mythicLevel: Int
    let completedAt: Date?
    let clearTimeMs: Int
    let parTimeMs: Int
    /// 0 = over time (depleted), 1–3 = timed with that many upgrades.
    let numKeystoneUpgrades: Int
    let score: Double?
    let iconUrl: URL?
    let url: URL?
    let affixes: [BestRunAffix]?

    var id: Int { keystoneRunId }
    var isTimed: Bool { numKeystoneUpgrades > 0 }
    /// Positive = finished under the timer by that many ms.
    var marginMs: Int { parTimeMs - clearTimeMs }
}

nonisolated struct BestRunAffix: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct SeasonScores: Decodable, Sendable {
    let season: String
    let scores: [String: Double]
}

/// `talentLoadout` with `talents:categorized`: separate class / spec / hero lists.
nonisolated struct TalentLoadoutDTO: Decodable, Sendable {
    let loadoutSpecId: Int?
    let loadoutText: String?
    let classTalents: [TalentEntryDTO]?
    let specTalents: [TalentEntryDTO]?
    let heroTalents: [TalentEntryDTO]?
    let activeHeroTree: HeroTreeDTO?
}

nonisolated struct HeroTreeDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct TalentEntryDTO: Decodable, Sendable {
    let node: TalentNodeDTO
    let entryIndex: Int?
    let rank: Int
}

nonisolated struct TalentNodeDTO: Decodable, Sendable {
    let id: Int
    /// 2 = choice node (two options in one slot).
    let type: Int?
    /// In-game tree coordinates; nodes are spaced ~600 units apart.
    let posX: Int?
    let posY: Int?
    let entries: [TalentNodeEntryDTO]
}

nonisolated struct TalentNodeEntryDTO: Decodable, Sendable {
    let id: Int
    /// 1 = active ability, 2 = passive.
    let type: Int?
    let maxRanks: Int?
    let spell: SpellDTO?
}

nonisolated struct SpellDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let icon: String?
}
