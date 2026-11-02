import Foundation

/// Full talent tree of one spec from the public Raidbots file
/// `https://www.raidbots.com/static/data/live/talents.json` (no key).
/// Node and entry ids are the same as Raider.IO's `node.id` / `entries[].id`.
nonisolated struct SpecTalentTree: Decodable, Sendable {
    let specId: Int
    let classNodes: [TreeNodeDTO]
    let specNodes: [TreeNodeDTO]
    let heroNodes: [TreeNodeDTO]

    func nodes(for tree: TalentTree, heroTreeId: Int?) -> [TreeNodeDTO] {
        switch tree {
        case .classTree: classNodes
        case .specTree: specNodes
        case .heroTree: heroNodes.filter { $0.subTreeId == heroTreeId }
        }
    }
}

nonisolated struct TreeNodeDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    /// "single", "choice" or "tiered".
    let type: String?
    let posX: Int
    let posY: Int
    let maxRanks: Int?
    /// Ids of the nodes this one connects to (the lines in the tree).
    let next: [Int]?
    let subTreeId: Int?
    /// Granted for free (e.g. Lay on Hands); Raider.IO's categorized lists leave these out.
    let freeNode: Bool?
    let entries: [TreeEntryDTO]
}

nonisolated struct TreeEntryDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let icon: String?
    /// "active" or "passive".
    let type: String?
    let maxRanks: Int?
}
