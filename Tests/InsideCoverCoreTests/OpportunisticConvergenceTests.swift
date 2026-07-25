import XCTest
@testable import InsideCoverCore

/// Convergence by steering, not by coincidence.
///
/// Measured over 180 simulated days, three independently advancing threads
/// coincided **zero** times — so a rule that waits for genuine coincidence
/// would never fire, and the temptation would be to loosen it until it was
/// firing on nothing. Instead the world prefers to advance business adjacent to
/// business already underway. Institutions behave this way.
final class OpportunisticConvergenceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func days(_ count: Double) -> Date { start.addingTimeInterval(count * 86_400) }

    private func allEligible() -> [CastUndertaking] {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for index in undertakings.indices { undertakings[index].nextEligibleAt = start }
        return undertakings
    }

    // MARK: - Heat

    func testNoHeatPreservesTheOldUniformBehaviourExactly() {
        let undertakings = allEligible()
        let plain = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "slot-a")
        let empty = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "slot-a", hotActorIDs: [])
        XCTAssertEqual(plain.advanced, empty.advanced)
    }

    func testHeatBiasesSelectionTowardBusyActorsAcrossManySlots() {
        let undertakings = allEligible()
        let hot: Set<String> = ["penny-blackletter"]

        var hotHits = 0, coldHits = 0
        for index in 0..<400 {
            let biased = CastUndertakingEngine.advancing(
                undertakings, now: days(1), slotID: "slot-\(index)", hotActorIDs: hot
            )
            guard let advanced = biased.advanced else { continue }
            if hot.contains(advanced.actorID) { hotHits += 1 } else { coldHits += 1 }
        }

        let share = Double(hotHits) / Double(max(1, hotHits + coldHits))
        // One hot actor out of ten should be well above its uniform 10% share.
        XCTAssertGreaterThan(share, 0.15, "Heat should actually steer the world")
        XCTAssertGreaterThan(coldHits, 0, "But every thread must stay reachable")
    }

    func testHeatNeverStarvesTheRestOfTheCast() {
        let undertakings = allEligible()
        let hot: Set<String> = ["penny-blackletter", "wicker-eddies"]
        var seen = Set<String>()
        for index in 0..<600 {
            if let advanced = CastUndertakingEngine.advancing(
                undertakings, now: days(1), slotID: "probe-\(index)", hotActorIDs: hot
            ).advanced {
                seen.insert(advanced.actorID)
            }
        }
        XCTAssertGreaterThan(seen.count, 4, "A hot pair must not monopolise the Academy")
    }

    func testHeatSelectionStaysDeterministic() {
        let undertakings = allEligible()
        let hot: Set<String> = ["penny-blackletter"]
        let a = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "x", hotActorIDs: hot)
        let b = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "x", hotActorIDs: hot)
        XCTAssertEqual(a.advanced, b.advanced)
    }

    func testEveryoneHotIsTheSameAsNobodyHot() {
        let undertakings = allEligible()
        let all = Set(undertakings.map(\.actorID))
        let a = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "y")
        let b = CastUndertakingEngine.advancing(undertakings, now: days(1), slotID: "y", hotActorIDs: all)
        XCTAssertEqual(a.advanced, b.advanced, "Uniform heat is no heat")
    }

    // MARK: - What counts as hot

    func testHotActorsComeFromPressuresPlacesAndRecentMovement() {
        let pressure = WorldPressureEngine.minting(
            into: [],
            relationshipField: ["penny-blackletter|wicker-eddies": {
                var tie = RelationshipTie(); tie.add(tension: 20); return tie
            }()],
            advancedUndertaking: nil, castName: { $0 }, now: start
        )

        var places: [String: PlaceState] = [:]
        for index in 0..<PlaceState.reputationThreshold {
            places = PlaceMemoryEngine.recording(
                places,
                incident: PlaceIncident(id: "i-\(index)", line: "x",
                                        participantIDs: ["serenity-brown"], tags: ["argument"],
                                        occurredAt: start),
                placeID: "location-great-hall"
            )
        }

        let movement = CastAgencyMovement(
            slotID: "s", kind: .relationship,
            actorID: "zara-finch", actorName: "Zara", targetID: "orion-blackthorn", targetName: "Orion",
            amount: 1, line: "x", createdAt: start
        )

        let hot = CastUndertakingEngine.hotActorIDs(
            pressures: pressure, places: places, recentMovements: [movement], now: start
        )
        XCTAssertTrue(hot.contains("penny-blackletter"), "live pressure")
        XCTAssertTrue(hot.contains("serenity-brown"), "a room has taken to them")
        XCTAssertTrue(hot.contains("zara-finch"), "moved recently")
        XCTAssertTrue(hot.contains("orion-blackthorn"), "was moved upon recently")
    }

    func testOldMovementsGoCold() {
        let movement = CastAgencyMovement(
            slotID: "s", kind: .relationship,
            actorID: "zara-finch", actorName: "Zara", targetID: "orion-blackthorn", targetName: "Orion",
            amount: 1, line: "x", createdAt: start
        )
        let hot = CastUndertakingEngine.hotActorIDs(
            pressures: [], places: [:], recentMovements: [movement], now: days(30)
        )
        XCTAssertTrue(hot.isEmpty, "Heat should fade, or the whole cast ends up permanently hot")
    }

    func testExpiredPressuresDoNotKeepActorsHot() {
        let pressure = WorldPressureEngine.minting(
            into: [],
            relationshipField: ["penny-blackletter|wicker-eddies": {
                var tie = RelationshipTie(); tie.add(tension: 20); return tie
            }()],
            advancedUndertaking: nil, castName: { $0 }, now: start
        )
        let hot = CastUndertakingEngine.hotActorIDs(
            pressures: pressure, places: [:], recentMovements: [], now: days(30)
        )
        XCTAssertTrue(hot.isEmpty)
    }

    // MARK: - Places pull incidents toward history

    func testARoomWithHistoryWinsAnAmbiguousIncident() {
        var places: [String: PlaceState] = [:]
        for index in 0..<4 {
            places = PlaceMemoryEngine.recording(
                places,
                incident: PlaceIncident(id: "i-\(index)", line: "An argument.",
                                        participantIDs: ["penny-blackletter"], tags: ["argument"],
                                        occurredAt: start),
                placeID: "location-great-hall"
            )
        }
        let chosen = PlaceMemoryEngine.preferredPlace(
            among: ["location-stacks", "location-great-hall", "location-dorm"],
            states: places,
            tags: ["argument"]
        )
        XCTAssertEqual(chosen, "location-great-hall", "Arguments should keep happening where arguments happen")
    }

    func testAFreshRoomIsStillReachable() {
        let chosen = PlaceMemoryEngine.preferredPlace(
            among: ["location-stacks", "location-dorm"],
            states: [:],
            tags: ["argument"]
        )
        XCTAssertNotNil(chosen, "With no history, any candidate room may take the incident")
    }

    func testPreferredPlaceIsDeterministicAndHandlesNoCandidates() {
        XCTAssertNil(PlaceMemoryEngine.preferredPlace(among: [], states: [:], tags: ["x"]))
        let a = PlaceMemoryEngine.preferredPlace(among: ["b", "a"], states: [:], tags: ["x"])
        let b = PlaceMemoryEngine.preferredPlace(among: ["b", "a"], states: [:], tags: ["x"])
        XCTAssertEqual(a, b)
    }

    // MARK: - The point of all this

    func testSteeringActuallyProducesSharedIncidentsOverTime() {
        // The measured failure of coincidence-detection was 0 convergences in
        // 180 days. Steering should do materially better than that.
        var undertakings = allEligible()
        var places: [String: PlaceState] = [:]
        let locations = NarrativePackRegistry.entities.filter { $0.kind == .location }
        var sharedIncidents = 0

        for day in 0..<180 {
            for slot in 0..<6 {
                let now = start.addingTimeInterval(Double(day) * 86_400 + Double(slot) * 4 * 3600)
                let hot = CastUndertakingEngine.hotActorIDs(
                    pressures: [], places: places, recentMovements: [], now: now
                )
                let step = CastUndertakingEngine.advancing(
                    undertakings, now: now, slotID: "sim-\(day)-\(slot)", hotActorIDs: hot
                )
                undertakings = step.undertakings
                guard let advanced = step.advanced, let stage = advanced.currentStage else { continue }

                let candidates = locations
                    .filter { !Set($0.tags).intersection(Set(stage.tags)).isEmpty }
                    .map(\.id)
                guard let placeID = PlaceMemoryEngine.preferredPlace(
                    among: candidates, states: places, tags: stage.tags
                ) else { continue }

                // A shared incident: this actor's business lands in a room that
                // already has history with somebody else.
                if let existing = places[placeID],
                   existing.incidents.contains(where: { !$0.participantIDs.contains(advanced.actorID) }) {
                    sharedIncidents += 1
                }
                places = PlaceMemoryEngine.recording(
                    places,
                    incident: PlaceIncident(id: "sim-\(day)-\(slot)", line: stage.line,
                                            participantIDs: [advanced.actorID], tags: stage.tags,
                                            occurredAt: now),
                    placeID: placeID
                )
                for index in undertakings.indices where undertakings[index].isRunning {
                    undertakings[index].nextEligibleAt = min(undertakings[index].nextEligibleAt, now)
                }
            }
        }

        XCTAssertGreaterThan(sharedIncidents, 0,
                             "Steering should make independently advancing threads meet in the same room")
    }
}
