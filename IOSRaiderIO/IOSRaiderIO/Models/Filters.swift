import Foundation

nonisolated enum RegionFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case world, eu, us, kr, tw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .world: "World"
        case .eu: "EU"
        case .us: "US"
        case .kr: "KR"
        case .tw: "TW"
        }
    }
}

nonisolated struct Filters: Hashable, Sendable {
    /// Fixed number of players loaded per spec.
    static let playerCount = 5

    var region: RegionFilter = .world
    var playerCount: Int = Filters.playerCount
}

/// Everything that determines the result of a spec screen.
/// Results are stored per query, so a new query can never show the previous one's data.
nonisolated struct SpecQuery: Hashable, Sendable {
    let classId: Int
    let specId: Int
    /// Raider.IO slugs for the leaderboard request.
    var classSlug = ""
    var specSlug = ""
    let region: RegionFilter
    let playerCount: Int
}
