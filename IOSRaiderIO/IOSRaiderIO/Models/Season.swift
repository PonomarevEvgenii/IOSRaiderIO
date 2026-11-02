import Foundation

/// Response of `GET /api/v1/mythic-plus/static-data?expansion_id=…`.
nonisolated struct StaticData: Decodable, Sendable {
    let seasons: [Season]
}

nonisolated struct Season: Decodable, Identifiable, Hashable, Sendable {
    nonisolated struct RegionStarts: Decodable, Hashable, Sendable {
        let us: Date?
    }

    let slug: String
    let name: String
    let isMainSeason: Bool
    let starts: RegionStarts

    var id: String { slug }

    /// The latest main season that has already started.
    /// Non-main entries (e.g. "-cutoffs" or event seasons) are ignored.
    static func current(in seasons: [Season], now: Date = .now) -> Season? {
        seasons
            .filter { season in
                guard season.isMainSeason, let start = season.starts.us else { return false }
                return start <= now
            }
            .max { ($0.starts.us ?? .distantPast) < ($1.starts.us ?? .distantPast) }
    }
}
