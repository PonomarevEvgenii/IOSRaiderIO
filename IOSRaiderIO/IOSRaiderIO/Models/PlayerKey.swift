import Foundation

/// Stable identity of a character: region + realm slug + name (case-insensitive).
nonisolated struct PlayerKey: Codable, Hashable, Sendable {
    let region: String
    let realmSlug: String
    let name: String

    var id: String { "\(region.lowercased())/\(realmSlug.lowercased())/\(name.lowercased())" }

    /// Public Raider.IO character page, e.g. https://raider.io/characters/eu/draenor/Name
    var raiderIOURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "raider.io"
        components.path = "/characters/\(region)/\(realmSlug)/\(name)"
        return components.url
    }

    static func == (lhs: PlayerKey, rhs: PlayerKey) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A player found in the top runs for a spec. Also the persisted favorite type.
nonisolated struct TopPlayer: Codable, Identifiable, Hashable, Sendable {
    let key: PlayerKey
    let name: String
    let realmName: String
    let regionShortName: String
    let classId: Int
    let className: String
    let specId: Int
    let specName: String
    /// Highest keystone level among the player's best runs.
    let bestKeyLevel: Int
    /// Number of best runs (one per dungeon) in the leaderboard entry.
    let runCount: Int
    /// Season M+ score from the leaderboard. Optional so older saved favorites still decode.
    var score: Double?
    /// Position in the spec leaderboard for the chosen region.
    var rank: Int?

    var id: String { key.id }
}
