import Testing
@testable import MyApp

struct PickRateTests {
    @Test func zeroPlayersHasNoRatesAndNoNaN() {
        let build = PickRateAggregator.aggregate([], specId: 65)
        #expect(build.playersCounted == 0)
        #expect(build.playersSkipped == 0)
        #expect(build.groups.isEmpty)
        // A rate with total 0 must be 0, not NaN or infinity.
        let rate = TalentPickRate(talent: Make.pick(1, "A"), count: 0, total: 0)
        #expect(rate.rate == 0)
        #expect(rate.rate.isFinite)
    }

    @Test func onePlayerHasEveryTalentAt100Percent() {
        let build = PickRateAggregator.aggregate(
            [Make.talents([Make.pick(1, "A"), Make.pick(2, "B", tree: .classTree)])],
            specId: 65
        )
        #expect(build.playersCounted == 1)
        let rates = build.groups.flatMap(\.rates)
        #expect(rates.count == 2)
        #expect(rates.allSatisfy { $0.rate == 1 })
    }

    @Test func allPlayersSameBuild() {
        let picks = [Make.pick(1, "A"), Make.pick(2, "B")]
        let players = (0..<5).map { _ in Make.talents(importString: "SAME", picks) }
        let build = PickRateAggregator.aggregate(players, specId: 65)
        #expect(build.playersCounted == 5)
        #expect(build.groups.flatMap(\.rates).allSatisfy { $0.count == 5 && $0.rate == 1 })
        #expect(build.mostCommonImportString == "SAME")
        #expect(build.mostCommonImportStringCount == 5)
    }

    @Test func sortedByRateWithTiesByName() {
        let players = [
            Make.talents([Make.pick(1, "Zeta"), Make.pick(2, "Alpha"), Make.pick(3, "Mid")]),
            Make.talents([Make.pick(1, "Zeta"), Make.pick(2, "Alpha")]),
            Make.talents([Make.pick(3, "Mid")]),
        ]
        let rates = PickRateAggregator.aggregate(players, specId: 65).groups.flatMap(\.rates)
        // Alpha and Zeta: 2 of 3 (tie → by name); Mid: 2 of 3 as well → all tied, alphabetical.
        #expect(rates.map(\.talent.name) == ["Alpha", "Mid", "Zeta"])

        let unequal = PickRateAggregator.aggregate([
            Make.talents([Make.pick(1, "Rare"), Make.pick(2, "Common")]),
            Make.talents([Make.pick(2, "Common")]),
        ], specId: 65).groups.flatMap(\.rates)
        #expect(unequal.map(\.talent.name) == ["Common", "Rare"])
        #expect(unequal.map(\.rate) == [1, 0.5])
    }

    @Test func playersWithoutTalentsOrOtherSpecAreSkipped() {
        let players: [PlayerTalents?] = [
            Make.talents([Make.pick(1, "A")]),
            nil, // profile missing
            Make.talents([]), // no talent data
            Make.talents(specId: 70, [Make.pick(9, "Ret talent")]), // current loadout is another spec
        ]
        let build = PickRateAggregator.aggregate(players, specId: 65)
        #expect(build.playersCounted == 1)
        #expect(build.playersSkipped == 3)
        #expect(build.groups.flatMap(\.rates).map(\.talent.name) == ["A"])
        #expect(build.groups.flatMap(\.rates).first?.rate == 1)
    }

    @Test func groupsByTreeAndCountsHeroTrees() {
        let players = [
            Make.talents(hero: "Lightsmith", [Make.pick(1, "C", tree: .classTree), Make.pick(2, "H", tree: .heroTree, hero: "Lightsmith")]),
            Make.talents(hero: "Herald of the Sun", [Make.pick(1, "C", tree: .classTree), Make.pick(3, "H2", tree: .heroTree, hero: "Herald of the Sun")]),
        ]
        let build = PickRateAggregator.aggregate(players, specId: 65)
        #expect(build.groups.map(\.tree) == [.classTree, .heroTree])
        #expect(build.heroTrees.map(\.name) == ["Herald of the Sun", "Lightsmith"])
        #expect(build.heroTrees.allSatisfy { $0.count == 1 })
    }

    @Test func duplicatePickInOnePlayerCountsOnce() {
        let build = PickRateAggregator.aggregate([Make.talents([Make.pick(1, "A"), Make.pick(1, "A")])], specId: 65)
        #expect(build.groups.flatMap(\.rates).first?.count == 1)
    }

    @Test func realProfileFixtureAggregates() throws {
        let profile = try TestFixtures.decode(CharacterProfile.self, "fixture_profile")
        let build = PickRateAggregator.aggregate([profile.talents], specId: 65)
        #expect(build.playersCounted == 1)
        #expect(build.groups.map(\.tree) == [.classTree, .specTree, .heroTree])
        #expect(build.groups.map { $0.rates.count } == [30, 30, 13])
    }
}
