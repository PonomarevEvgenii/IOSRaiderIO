import Foundation

nonisolated enum TalentTree: String, CaseIterable, Identifiable, Sendable {
    case classTree, specTree, heroTree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classTree: "Class talents"
        case .specTree: "Spec talents"
        case .heroTree: "Hero talents"
        }
    }
}

/// One chosen talent. `id` is the trait entry id, which is unique per choice
/// (the two options of a choice node have different entry ids).
nonisolated struct TalentPick: Identifiable, Hashable, Sendable {
    let id: Int
    let nodeId: Int
    let spellId: Int
    let name: String
    let icon: String?
    let rank: Int
    let maxRank: Int
    let tree: TalentTree
    /// Hero tree name (e.g. "Lightsmith") for hero talents, otherwise nil.
    let heroTreeName: String?
    /// Position in the in-game tree (Raider.IO `node.posX/posY`).
    var posX: Int = 0
    var posY: Int = 0
    var isChoiceNode = false
    var isActive = false
}

/// Talents of one player, converted from the Raider.IO DTO.
nonisolated struct PlayerTalents: Sendable {
    let specId: Int?
    let importString: String?
    let heroTreeName: String?
    /// Raider.IO `active_hero_tree.id`, equal to Raidbots `subTreeId`.
    var heroTreeId: Int?
    let picks: [TalentPick]

    init(specId: Int?, importString: String?, heroTreeName: String?, heroTreeId: Int? = nil, picks: [TalentPick]) {
        self.specId = specId
        self.importString = importString
        self.heroTreeName = heroTreeName
        self.heroTreeId = heroTreeId
        self.picks = picks
    }

    init(dto: TalentLoadoutDTO?) {
        let heroName = dto?.activeHeroTree?.name
        let groups: [(TalentTree, [TalentEntryDTO]?)] = [
            (.classTree, dto?.classTalents),
            (.specTree, dto?.specTalents),
            (.heroTree, dto?.heroTalents),
        ]
        var picks: [TalentPick] = []
        for (tree, entries) in groups {
            for entry in entries ?? [] {
                let index = entry.entryIndex ?? 0
                // Skip malformed entries and nodes without a spell (e.g. the hero tree selection node).
                guard entry.node.entries.indices.contains(index),
                      let spell = entry.node.entries[index].spell else { continue }
                let choice = entry.node.entries[index]
                picks.append(TalentPick(
                    id: choice.id,
                    nodeId: entry.node.id,
                    spellId: spell.id,
                    name: spell.name,
                    icon: spell.icon,
                    rank: entry.rank,
                    maxRank: choice.maxRanks ?? entry.rank,
                    tree: tree,
                    heroTreeName: tree == .heroTree ? heroName : nil,
                    posX: entry.node.posX ?? 0,
                    posY: entry.node.posY ?? 0,
                    isChoiceNode: entry.node.type == 2,
                    isActive: choice.type == 1
                ))
            }
        }
        self.init(
            specId: dto?.loadoutSpecId,
            importString: dto?.loadoutText.flatMap { $0.isEmpty ? nil : $0 },
            heroTreeName: heroName,
            heroTreeId: dto?.activeHeroTree?.id,
            picks: picks
        )
    }

    var hasTalents: Bool { !picks.isEmpty }

    func picks(in tree: TalentTree) -> [TalentPick] {
        picks.filter { $0.tree == tree }
    }
}
