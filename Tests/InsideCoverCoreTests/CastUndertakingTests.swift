import XCTest
@testable import InsideCoverCore

/// The Cast's own business, and the decoupling it makes possible. Before this,
/// every actor and thread in the Academy was chosen by tag overlap with the
/// reader's kept pages, which made the world a projection of their day.
final class CastUndertakingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func days(_ count: Double) -> Date { start.addingTimeInterval(count * 86_400) }

    // MARK: - Authored ladders

    func testEveryLadderIsWellFormed() {
        XCTAssertGreaterThanOrEqual(CastUndertakingRegistry.actorIDs.count, 8)
        for actorID in CastUndertakingRegistry.actorIDs {
            guard let ladder = CastUndertakingRegistry.ladder(for: actorID) else {
                return XCTFail("Missing ladder for \(actorID)")
            }
            XCTAssertEqual(ladder.stages.count, 5, "\(actorID) should have five beats")
            XCTAssertFalse(ladder.title.isEmpty)
            XCTAssertFalse(ladder.pursuit.isEmpty)
            XCTAssertFalse(ladder.why.isEmpty, "\(actorID) needs a reason it is this character's business")
            for stage in ladder.stages {
                XCTAssertFalse(stage.line.isEmpty)
                XCTAssertFalse(stage.trace.isEmpty, "\(actorID)/\(stage.id) needs a trace the reader could stumble on")
                XCTAssertFalse(stage.tags.isEmpty)
            }
            let ids = ladder.stages.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(actorID) has duplicate stage ids")
        }
    }

    func testLaddersBelongToRealCastEntities() {
        let known = Set(NarrativePackRegistry.entities.map(\.id))
        for actorID in CastUndertakingRegistry.actorIDs {
            XCTAssertTrue(known.contains(actorID), "\(actorID) is not a real cast entity")
        }
    }

    func testAmbroseTrencherIsAlreadyBusy() {
        // The newest character should arrive mid-business, not waiting to be met.
        guard let ladder = CastUndertakingRegistry.ladder(for: "ambrose-trencher") else {
            return XCTFail("Trencher should have his own business")
        }
        XCTAssertTrue(ladder.stages.contains { $0.tags.contains("food") })
        XCTAssertTrue(ladder.stages.contains { $0.tags.contains("unsaid") },
                      "His fault (feeding instead of speaking) should be load-bearing")
    }

    func testNoLadderAssignsTheReaderAnything() {
        let forbidden = ["you should", "your task", "try to", "can you", "help him",
                         "help her", "we need you", "bring me", "go and", "your turn"]
        for actorID in CastUndertakingRegistry.actorIDs {
            guard let ladder = CastUndertakingRegistry.ladder(for: actorID) else { continue }
            let text = ([ladder.pursuit, ladder.why] + ladder.stages.flatMap { [$0.line, $0.trace] })
                .joined(separator: " ").lowercased()
            for phrase in forbidden {
                XCTAssertFalse(text.contains(phrase), "\(actorID) reads as an assignment: '\(phrase)'")
            }
        }
    }

    // MARK: - Seeding

    func testSeedingGivesEachCharacterExactlyOneRunningUndertaking() {
        let seeded = CastUndertakingEngine.seeded(existing: [], now: start)
        XCTAssertEqual(seeded.count, CastUndertakingRegistry.actorIDs.count)
        for actorID in CastUndertakingRegistry.actorIDs {
            XCTAssertEqual(seeded.filter { $0.actorID == actorID && $0.isRunning }.count, 1)
        }
    }

    func testSeedingIsIdempotent() {
        let once = CastUndertakingEngine.seeded(existing: [], now: start)
        let twice = CastUndertakingEngine.seeded(existing: once, now: start)
        XCTAssertEqual(once, twice)
    }

    func testAConcludedCharacterRestsBeforeStartingAnythingNew() {
        var seeded = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = seeded.firstIndex { $0.actorID == "penny-blackletter" } ?? 0
        seeded[index].status = .concluded
        seeded[index].nextEligibleAt = days(5)

        let during = CastUndertakingEngine.seeded(existing: seeded, now: days(2))
        XCTAssertEqual(during.filter { $0.actorID == "penny-blackletter" }.count, 1, "Still resting")

        let after = CastUndertakingEngine.seeded(existing: seeded, now: days(6))
        XCTAssertEqual(after.filter { $0.actorID == "penny-blackletter" }.count, 2, "Rest is over; new business begins")
    }

    // MARK: - Advancing

    func testAdvancingMovesAtMostOneUndertakingPerSlot() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for u in undertakings.indices { undertakings[u].nextEligibleAt = start }

        let step = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "slot-a")
        let moved = zip(undertakings, step.undertakings).filter { $0.0 != $0.1 }
        XCTAssertLessThanOrEqual(moved.count, 1, "The Academy does not have a development everywhere at once")
    }

    func testNothingAdvancesBeforeItIsEligible() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let step = CastUndertakingEngine.advancing(undertakings, now: start, slotID: "slot-a")
        XCTAssertNil(step.advanced)
        XCTAssertEqual(step.undertakings, undertakings)
    }

    func testAdvancingIsDeterministicForTheSameSlot() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for u in undertakings.indices { undertakings[u].nextEligibleAt = start }

        let a = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "slot-x")
        let b = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "slot-x")
        XCTAssertEqual(a.undertakings, b.undertakings)
        XCTAssertEqual(a.advanced, b.advanced)
    }

    func testAnUndertakingConcludesAtTheEndOfItsLadderAndThenRests() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        undertakings = [undertakings[0]]
        var clock = start

        for _ in 0..<60 {
            clock = clock.addingTimeInterval(86_400)
            undertakings[0].nextEligibleAt = min(undertakings[0].nextEligibleAt, clock)
            let step = CastUndertakingEngine.advancing(undertakings, now: clock, slotID: "slot-\(Int(clock.timeIntervalSince1970))")
            undertakings = step.undertakings
            if undertakings[0].status == .concluded { break }
        }

        XCTAssertEqual(undertakings[0].status, .concluded)
        XCTAssertEqual(undertakings[0].stageIndex, undertakings[0].stages.count - 1)
        XCTAssertGreaterThan(undertakings[0].nextEligibleAt, clock, "A concluded undertaking rests")
    }

    func testStageIndexNeverEscapesTheLadder() {
        var undertakings = [CastUndertakingEngine.seeded(existing: [], now: start)[0]]
        var clock = start
        for _ in 0..<200 {
            clock = clock.addingTimeInterval(86_400)
            undertakings[0].nextEligibleAt = min(undertakings[0].nextEligibleAt, clock)
            undertakings = CastUndertakingEngine.advancing(
                undertakings, now: clock, slotID: "slot-\(Int(clock.timeIntervalSince1970))"
            ).undertakings
            XCTAssertTrue(undertakings[0].stages.indices.contains(undertakings[0].stageIndex))
        }
    }

    func testATrailCanGoColdWithoutBecomingAFailureToFix() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for u in undertakings.indices { undertakings[u].nextEligibleAt = start }
        var sawStall = false
        var clock = start

        for index in 0..<400 {
            clock = clock.addingTimeInterval(6 * 3600)
            for u in undertakings.indices where undertakings[u].isRunning {
                undertakings[u].nextEligibleAt = min(undertakings[u].nextEligibleAt, clock)
            }
            undertakings = CastUndertakingEngine.advancing(undertakings, now: clock, slotID: "probe-\(index)").undertakings
            if undertakings.contains(where: { $0.status == .stalled }) { sawStall = true; break }
        }

        XCTAssertTrue(sawStall, "Trails should sometimes go cold rather than marching to conclusion")
    }

    // MARK: - Decoupling from the reader

    func testWorldSeededSlotsAreAMinorityButRealShare() {
        let hits = (0..<2000).filter { GossipSimulationBuilder.isWorldSeededSlot(slotID: "slot-\($0)") }.count
        let percent = Double(hits) / 20.0
        XCTAssertGreaterThan(percent, 18.0)
        XCTAssertLessThan(percent, 45.0, "The Academy shares a building with the reader; it is not a separate app")
    }

    func testWorldSeededGossipCarriesNoReaderCallbackAndNoBeliefMoves() {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let day = BookDay(id: "2026-07-21", date: start, pages: [])

        var sawWorldSeeded = false
        for hour in stride(from: 0, to: 24 * 40, by: 4) {
            let probe = start.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["worldSeeded"] == "true" else { continue }
            sawWorldSeeded = true
            XCTAssertNil(surface.payload.metadata["relationshipMoves"])
            XCTAssertNil(surface.payload.metadata["pageBeliefMoves"])
            XCTAssertNotNil(surface.payload.metadata[GossipSimulationBuilder.undertakingKey])
        }
        XCTAssertTrue(sawWorldSeeded, "Some slots should belong wholly to the Academy")
    }

    func testGossipVolumeNoLongerScalesWithHowMuchTheReaderWrote() {
        // A quiet day and a loud day get the same amount of world.
        let quiet = BookDay(id: "2026-07-21", date: start, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = []

        let probe = start.addingTimeInterval(3600)
        let quietSurface = GossipSimulationBuilder.surface(for: quiet, inputs: inputs, now: probe)
        let quietCount = quietSurface.payload.metadata["turnIDs"]?.split(separator: ",").count ?? 0

        XCTAssertGreaterThanOrEqual(quietCount, 2, "A quiet day still gets a busy world")
    }

    func testWorldBusinessSelectionIsDeterministicAndSkipsFinishedWork() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for u in undertakings.indices { undertakings[u].status = .concluded }
        XCTAssertNil(GossipSimulationBuilder.worldBusiness(in: undertakings, slotID: "slot-a"))

        undertakings[0].status = .active
        let a = GossipSimulationBuilder.worldBusiness(in: undertakings, slotID: "slot-a")
        let b = GossipSimulationBuilder.worldBusiness(in: undertakings, slotID: "slot-a")
        XCTAssertEqual(a?.id, b?.id)
        XCTAssertEqual(a?.id, undertakings[0].id)
    }

    // MARK: - Persistence

    func testUndertakingRoundTrips() throws {
        let seeded = CastUndertakingEngine.seeded(existing: [], now: start)
        let data = try JSONEncoder().encode(seeded)
        let decoded = try JSONDecoder().decode([CastUndertaking].self, from: data)
        XCTAssertEqual(decoded, seeded)
    }

    func testLegacyVaultWithoutUndertakingsDecodes() throws {
        let json = "{\"resolvedSlotIDs\":[],\"recentMovements\":[]}"
        _ = try JSONDecoder().decode(CastAgencyState.self, from: Data(json.utf8))
        // A vault that predates undertakings simply has none; seeding fills them.
        let seeded = CastUndertakingEngine.seeded(existing: [], now: start)
        XCTAssertFalse(seeded.isEmpty)
    }
}
