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

    enum CodingKeys: String, CodingKey {
        case id, name, type, posX, posY, maxRanks, next, subTreeId, freeNode, entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        posX = try container.decode(Int.self, forKey: .posX)
        posY = try container.decode(Int.self, forKey: .posY)
        maxRanks = try container.decodeIfPresent(Int.self, forKey: .maxRanks)
        next = try container.decodeIfPresent([Int].self, forKey: .next)
        subTreeId = try container.decodeIfPresent(Int.self, forKey: .subTreeId)
        freeNode = try container.decodeIfPresent(Bool.self, forKey: .freeNode)
        // Raidbots sometimes ships empty `{}` entries (no id); skip them instead of failing the whole file.
        entries = try container.decode([LossyEntry].self, forKey: .entries).compactMap(\.value)
    }

    private struct LossyEntry: Decodable {
        let value: TreeEntryDTO?

        init(from decoder: Decoder) throws {
            value = try? TreeEntryDTO(from: decoder)
        }
    }
}

nonisolated struct TreeEntryDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let icon: String?
    /// "active" or "passive".
    let type: String?
    let maxRanks: Int?
}
