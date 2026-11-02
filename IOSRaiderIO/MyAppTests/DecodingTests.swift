import Foundation
import Testing
@testable import MyApp

/// Decodes every saved real Raider.IO response and the bundled classes.json.
struct DecodingTests {
    @Test func classesJSONHasAllClassesWithUniqueIds() throws {
        let classes = try ClassCatalog.load(from: Bundle(for: BuildStore.self))
        #expect(classes.count == 13)
        #expect(Set(classes.map(\.id)).count == classes.count)
        let specs = classes.flatMap(\.specs)
        #expect(specs.count == 40)
        #expect(Set(specs.map(\.id)).count == specs.count)
        #expect(specs.allSatisfy { !$0.icon.isEmpty })
    }

    @Test func classesJSONMatchesRaiderIONames() throws {
        // Names/ids taken from the leaderboard fixture must exist in classes.json, and slugs must match.
        let classes = try ClassCatalog.load(from: Bundle(for: BuildStore.self))
        let response = try TestFixtures.decode(SpecRankingsResponse.self, "fixture_spec_rankings")
        #expect(classes.first { $0.id == 2 }?.slug == "paladin")
        #expect(classes.first { $0.id == 6 }?.slug == "death-knight")
        #expect(classes.flatMap(\.specs).first { $0.id == 253 }?.slug == "beast-mastery")
        for entry in response.rankings.rankedCharacters {
            let character = entry.character
            let gameClass = try #require(classes.first { $0.id == character.characterClass.id })
            #expect(gameClass.name == character.characterClass.name)
            let spec = try #require(character.spec)
            #expect(gameClass.specs.contains { $0.id == spec.id && $0.name == spec.name })
        }
    }

    @Test func staticDataFixtureDecodesAndPicksCurrentSeason() throws {
        let data = try TestFixtures.decode(StaticData.self, "fixture_static_data")
        #expect(data.seasons.count == 3)
        let now = try Date("2026-11-02T00:00:00Z", strategy: .iso8601)
        #expect(Season.current(in: data.seasons, now: now)?.slug == "season-mn-2")
        // Before season 2 started, season 1 is the current main season.
        let earlier = try Date("2026-05-01T00:00:00Z", strategy: .iso8601)
        #expect(Season.current(in: data.seasons, now: earlier)?.slug == "season-mn-1")
    }

    @Test func specRankingsFixtureDecodes() throws {
        let response = try TestFixtures.decode(SpecRankingsResponse.self, "fixture_spec_rankings")
        let ranked = response.rankings.rankedCharacters
        #expect(ranked.count == 10)
        #expect(ranked.map(\.rank) == Array(1...10))
        // Sorted by score, descending.
        #expect(zip(ranked, ranked.dropFirst()).allSatisfy { $0.score >= $1.score })
        let fifth = ranked[4].topPlayer
        #expect(fifth.name == "Moadzarella")
        #expect(fifth.key.realmSlug == "draenor")
        #expect(fifth.key.region == "eu")
        #expect(fifth.specId == 65)
        #expect(fifth.bestKeyLevel == 24)
        #expect(fifth.rank == 5)
    }

    @Test func profileFixtureDecodesBestRuns() throws {
        let profile = try TestFixtures.decode(CharacterProfile.self, "fixture_profile")
        let runs = try #require(profile.mythicPlusBestRuns)
        #expect(runs.count == 8)
        let den = try #require(runs.first { $0.dungeon == "Den of Nalorakk" })
        #expect(den.mythicLevel == 24)
        #expect(den.clearTimeMs == 1674349)
        #expect(den.parTimeMs == 1920999)
        #expect(den.isTimed)
        #expect(den.marginMs == 246650)
        #expect(den.completedAt != nil)
        #expect(den.affixes?.map(\.name).contains("Tyrannical") == true)
    }

    @Test func profileFixtureDecodesCategorizedTalents() throws {
        let profile = try TestFixtures.decode(CharacterProfile.self, "fixture_profile")
        #expect(profile.name == "Moadzarella")
        #expect(profile.score == 4334.1)
        #expect(profile.profileUrl?.absoluteString == "https://raider.io/characters/eu/draenor/Moadzarella")

        let talents = profile.talents
        #expect(talents.specId == 65)
        #expect(talents.heroTreeName == "Lightsmith")
        #expect(talents.importString?.hasPrefix("CEEAAAAA") == true)
        #expect(talents.picks(in: .classTree).count == 30)
        #expect(talents.picks(in: .specTree).count == 30)
        #expect(talents.picks(in: .heroTree).count == 13)
        #expect(Set(talents.picks.map(\.id)).count == talents.picks.count)
    }

    @Test func notFoundFixtureDecodesAsErrorBody() throws {
        let body = try TestFixtures.decode(RaiderIOErrorBody.self, "fixture_profile_not_found")
        #expect(body.statusCode == 400)
        #expect(body.message == "Could not find requested character")
    }

    @Test func profileWithoutTalentsHasNoPicks() throws {
        let json = #"{"name":"A","region":"eu","realm":"Draenor","profile_url":"https://raider.io/x"}"#
        let profile = try RaiderIODecoding.decode(CharacterProfile.self, from: Data(json.utf8))
        #expect(profile.talents.hasTalents == false)
        #expect(profile.talents.importString == nil)
        #expect(profile.score == nil)
    }
}
