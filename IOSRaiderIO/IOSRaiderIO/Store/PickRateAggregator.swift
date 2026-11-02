import Foundation

nonisolated struct TalentPickRate: Identifiable, Hashable, Sendable {
    let talent: TalentPick
    let count: Int
    let total: Int

    var id: Int { talent.id }

    /// 0…1. Zero when there are no players, so the UI never shows NaN or infinity.
    var rate: Double { total > 0 ? Double(count) / Double(total) : 0 }
}

nonisolated struct TalentGroupRates: Identifiable, Hashable, Sendable {
    let tree: TalentTree
    let rates: [TalentPickRate]

    var id: TalentTree { tree }
}

nonisolated struct NamedCount: Identifiable, Hashable, Sendable {
    let name: String
    let count: Int

    var id: String { name }
}

nonisolated struct PopularBuild: Sendable {
    /// Players whose talents were counted.
    let playersCounted: Int
    /// Players skipped: no talent data, or their current loadout is for another spec.
    let playersSkipped: Int
    let groups: [TalentGroupRates]
    let heroTrees: [NamedCount]
    /// Hero tree id (Raidbots `subTreeId`) used by most counted players.
    var mostCommonHeroTreeId: Int?
    /// The exact import string shared by the most counted players.
    let mostCommonImportString: String?
    let mostCommonImportStringCount: Int

    static let empty = PopularBuild(
        playersCounted: 0, playersSkipped: 0, groups: [], heroTrees: [],
        mostCommonImportString: nil, mostCommonImportStringCount: 0
    )
}

nonisolated enum PickRateAggregator {
    /// - Parameter talents: one element per player; `nil` means the profile could not be loaded.
    /// A player counts only if they have talents and the loadout is for `specId`.
    /// Rates are sorted by count (descending), ties by talent name, then by id for a stable order.
    static func aggregate(_ talents: [PlayerTalents?], specId: Int) -> PopularBuild {
        let valid = talents.compactMap { $0 }.filter { $0.hasTalents && $0.specId == specId }
        let total = valid.count

        var counts: [Int: Int] = [:]
        var representative: [Int: TalentPick] = [:]
        var heroCounts: [String: Int] = [:]
        var importCounts: [String: Int] = [:]

        for player in valid {
            // Count each talent at most once per player.
            var seen = Set<Int>()
            for pick in player.picks where seen.insert(pick.id).inserted {
                counts[pick.id, default: 0] += 1
                if representative[pick.id] == nil { representative[pick.id] = pick }
            }
            if let hero = player.heroTreeName { heroCounts[hero, default: 0] += 1 }
            if let string = player.importString { importCounts[string, default: 0] += 1 }
        }

        let rates = counts.compactMap { id, count -> TalentPickRate? in
            guard let talent = representative[id] else { return nil }
            return TalentPickRate(talent: talent, count: count, total: total)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.talent.name != rhs.talent.name { return lhs.talent.name < rhs.talent.name }
            return lhs.id < rhs.id
        }

        let groups = TalentTree.allCases.compactMap { tree -> TalentGroupRates? in
            let inTree = rates.filter { $0.talent.tree == tree }
            return inTree.isEmpty ? nil : TalentGroupRates(tree: tree, rates: inTree)
        }

        let heroTrees = heroCounts
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }

        let topImport = importCounts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }

        var heroIdCounts: [Int: Int] = [:]
        for player in valid {
            if let id = player.heroTreeId { heroIdCounts[id, default: 0] += 1 }
        }
        let topHeroId = heroIdCounts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key

        return PopularBuild(
            playersCounted: total,
            playersSkipped: talents.count - total,
            groups: groups,
            heroTrees: heroTrees,
            mostCommonHeroTreeId: topHeroId,
            mostCommonImportString: topImport?.key,
            mostCommonImportStringCount: topImport?.value ?? 0
        )
    }
}
