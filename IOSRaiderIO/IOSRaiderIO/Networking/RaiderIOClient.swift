import Foundation

/// Abstraction over the Raider.IO API so the store can run on fixtures in tests and previews.
nonisolated protocol RaiderIOClient: Sendable {
    func staticData(expansionId: Int) async throws -> StaticData
    /// Spec leaderboard (sorted by M+ score), 100 characters per page.
    func specRankings(season: String, region: RegionFilter, classSlug: String, specSlug: String, page: Int) async throws -> SpecRankingsResponse
    func profile(for key: PlayerKey) async throws -> CharacterProfile
    /// Full talent trees of every spec (Raidbots static data).
    func talentTrees() async throws -> [SpecTalentTree]
}

nonisolated enum RaiderIODecoding {
    /// Raider.IO uses snake_case keys and ISO 8601 dates with or without fractional seconds.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? Date(string, strategy: .iso8601) { return date }
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(string)")
        }
        return decoder
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(APIError) -> T {
        do {
            return try makeDecoder().decode(type, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }
}

/// Live client for https://raider.io/api (no key required).
/// An actor, so URL requests and JSON decoding happen off the main actor.
actor LiveRaiderIOClient: RaiderIOClient {
    static let userAgent = "WoWBuildBrowser/1.0 (iOS; SwiftUI app reading public Raider.IO data)"

    private let session: URLSession
    private let limiter: RequestLimiter
    private let baseURL = URL(string: "https://raider.io/api/v1")!
    /// Extra attempts after a 429 before giving up and showing the error.
    private let rateLimitRetries = 2

    init(session: URLSession = .shared, maxConcurrentRequests: Int = 3) {
        self.session = session
        self.limiter = RequestLimiter(maxConcurrent: maxConcurrentRequests)
    }

    func staticData(expansionId: Int) async throws -> StaticData {
        try await get("mythic-plus/static-data", query: ["expansion_id": String(expansionId)])
    }

    /// Not part of the documented v1 API (it's what raider.io's own leaderboard page uses),
    /// but public and key-free. Verified to return 100 characters per page for every spec tried.
    func specRankings(season: String, region: RegionFilter, classSlug: String, specSlug: String, page: Int) async throws -> SpecRankingsResponse {
        var components = URLComponents(string: "https://raider.io/api/mythic-plus/rankings/specs")
        components?.queryItems = [
            URLQueryItem(name: "region", value: region.rawValue),
            URLQueryItem(name: "season", value: season),
            URLQueryItem(name: "class", value: classSlug),
            URLQueryItem(name: "spec", value: specSlug),
            URLQueryItem(name: "page", value: String(page)),
        ]
        guard let url = components?.url else { throw APIError.transport("Invalid rankings URL") }
        return try await get(url)
    }

    func profile(for key: PlayerKey) async throws -> CharacterProfile {
        try await get("characters/profile", query: [
            "region": key.region,
            "realm": key.realmSlug,
            "name": key.name,
            "fields": "talents:categorized,mythic_plus_scores_by_season:current,mythic_plus_best_runs",
        ])
    }

    func talentTrees() async throws -> [SpecTalentTree] {
        guard let url = URL(string: "https://www.raidbots.com/static/data/live/talents.json") else {
            throw APIError.transport("Invalid talent tree URL")
        }
        return try await get(url)
    }

    private func get<T: Decodable & Sendable>(_ path: String, query: [String: String]) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw APIError.transport("Invalid URL for \(path)") }
        return try await get(url)
    }

    private func get<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var attempt = 0
        while true {
            let (data, response) = try await send(request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300:
                return try RaiderIODecoding.decode(T.self, from: data)
            case 429:
                // Back off exponentially (2 s, 4 s), honoring Retry-After when present.
                let retryAfter = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "Retry-After")
                    .flatMap(TimeInterval.init)
                let delay = retryAfter ?? pow(2, Double(attempt + 1))
                await limiter.pause(for: delay)
                guard attempt < rateLimitRetries else { throw APIError.rateLimited }
                attempt += 1
            default:
                let body = try? RaiderIODecoding.makeDecoder().decode(RaiderIOErrorBody.self, from: data)
                if status == 400 || status == 404, body?.message?.localizedCaseInsensitiveContains("could not find") == true {
                    throw APIError.notFound
                }
                throw APIError.server(status: status, message: body?.message)
            }
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await limiter.run { [session] in
                try await session.data(for: request)
            }
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                throw APIError.offline
            default:
                throw APIError.transport(error.localizedDescription)
            }
        }
    }
}
