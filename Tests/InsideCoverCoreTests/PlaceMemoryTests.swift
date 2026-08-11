import XCTest
@testable import InsideCoverCore

/// Rooms with history. The authored locations were already written as
/// characters (traits, quirks, faults, beliefs, goals), but had no memory.
final class PlaceMemoryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func hours(_ count: Double) -> Date { start.addingTimeInterval(count * 3600) }

    private func incident(_ index: Int, tags: [String], participants: [String] = ["penny-blackletter", "wicker-eddies"]) -> PlaceIncident {
        PlaceIncident(
            id: "incident-\(index)",
            line: "Something happened, for the \(index)th time.",
            participantIDs: participants,
            tags: tags,
            occurredAt: hours(Double(index))
        )
    }

    private func accumulate(_ count: Int, tags: [String], placeID: String = "location-great-hall") -> [String: PlaceState] {
        var states: [String: PlaceState] = [:]
        for index in 0..<count {
            states = PlaceMemoryEngine.recording(states, incident: incident(index, tags: tags), placeID: placeID)
        }
        return states
    }

    // MARK: - Accumulation

    func testIncidentsAccumulate() {
        let states = accumulate(3, tags: ["argument"])
        XCTAssertEqual(states["location-great-hall"]?.incidents.count, 3)
    }

    func testTheSameIncidentIsNeverRecordedTwice() {
        var states = PlaceMemoryEngine.recording([:], incident: incident(1, tags: ["argument"]), placeID: "location-kitchens")
        states = PlaceMemoryEngine.recording(states, incident: incident(1, tags: ["argument"]), placeID: "location-kitchens")
        XCTAssertEqual(states["location-kitchens"]?.incidents.count, 1)
    }

    func testIncidentListStaysBounded() {
        let states = accumulate(60, tags: ["argument"])
        XCTAssertEqual(states["location-great-hall"]?.incidents.count, PlaceState.maximumIncidents)
    }

    func testTheOldestIncidentsFallAwayFirst() {
        let states = accumulate(30, tags: ["argument"])
        let kept = states["location-great-hall"]?.incidents ?? []
        XCTAssertEqual(kept.first?.occurredAt, hours(Double(30 - PlaceState.maximumIncidents)))
    }

    // MARK: - Reputation

    func testARoomNeedsRepetitionBeforeItHasAReputation() {
        let thin = accumulate(PlaceState.reputationThreshold - 1, tags: ["argument"])
        XCTAssertFalse(thin["location-great-hall"]?.hasReputation ?? true)

        let earned = accumulate(PlaceState.reputationThreshold, tags: ["argument"])
        XCTAssertTrue(earned["location-great-hall"]?.hasReputation ?? false)
        XCTAssertEqual(earned["location-great-hall"]?.strongestReputationTag, "argument")
    }

    func testReputationCountsAreReadable() {
        let states = accumulate(5, tags: ["argument", "unsettled"])
        XCTAssertEqual(states["location-great-hall"]?.reputation(for: "argument"), 5)
        XCTAssertEqual(states["location-great-hall"]?.reputation(for: "food"), 0)
    }

    // MARK: - Favoured occupants

    func testSomebodyWhoKeepsTurningUpBecomesOneOfTheRoomsPeople() {
        var states: [String: PlaceState] = [:]
        for index in 0..<PlaceState.loyaltyThreshold {
            states = PlaceMemoryEngine.recording(
                states,
                incident: incident(index, tags: ["food"], participants: ["serenity-brown", "ambrose-trencher"]),
                placeID: "location-kitchens"
            )
        }
        let favored = states["location-kitchens"]?.favoredOccupantIDs ?? []
        XCTAssertTrue(favored.contains("ambrose-trencher"))
        XCTAssertTrue(favored.contains("serenity-brown"))
    }

    func testAPassingVisitorDoesNotBecomeAFavourite() {
        var states = accumulate(5, tags: ["argument"], placeID: "location-stacks")
        states = PlaceMemoryEngine.recording(
            states,
            incident: incident(99, tags: ["argument"], participants: ["zara-finch"]),
            placeID: "location-stacks"
        )
        XCTAssertFalse(states["location-stacks"]?.favoredOccupantIDs.contains("zara-finch") ?? true)
    }

    // MARK: - Refusal

    func testARoomWithAReputationBeginsRefusingSomething() {
        let states = accumulate(PlaceState.reputationThreshold, tags: ["argument"])
        XCTAssertNotNil(states["location-great-hall"]?.refusal)
    }

    func testRefusalIsStableOnceFormed() {
        let three = accumulate(PlaceState.reputationThreshold, tags: ["argument"])
        let many = accumulate(PlaceState.reputationThreshold + 8, tags: ["argument"])
        XCTAssertEqual(three["location-great-hall"]?.refusal, many["location-great-hall"]?.refusal)
    }

    func testRefusalIsDeterministicPerRoomAndTag() {
        XCTAssertEqual(
            PlaceMemoryEngine.refusal(for: "argument", placeID: "location-great-hall"),
            PlaceMemoryEngine.refusal(for: "argument", placeID: "location-great-hall")
        )
    }

    func testDifferentRoomsRefuseDifferentlyForTheSameTag() {
        let hall = PlaceMemoryEngine.refusal(for: "memory", placeID: "location-great-hall")
        let stacks = PlaceMemoryEngine.refusal(for: "memory", placeID: "location-stacks")
        let burrow = PlaceMemoryEngine.refusal(for: "memory", placeID: "location-book-burrow")
        XCTAssertGreaterThan(Set([hall, stacks, burrow]).count, 1)
    }

    func testARefusalNeverHardensIntoARule() {
        // A refusal is a behaviour the cast can argue about, not a mechanic.
        let forbidden = ["you must", "always", "never allowed", "rule:", "forbidden", "required"]
        for tag in ["argument", "food", "memory", "other"] {
            for place in ["location-great-hall", "location-kitchens", "location-stacks", "location-dorm"] {
                let text = PlaceMemoryEngine.refusal(for: tag, placeID: place).lowercased()
                for phrase in forbidden {
                    XCTAssertFalse(text.contains(phrase), "'\(phrase)' turns a refusal into a rule")
                }
            }
        }
    }

    // MARK: - Ambiguity

    func testTheBookNeverAdjudicatesWhetherARoomIsAlive() {
        var state = PlaceState(id: "location-great-hall")
        state.refusal = "no longer amplifies speeches, only interruptions"
        guard let reading = PlaceMemoryEngine.disagreement(about: state, placeName: "The Great Hall") else {
            return XCTFail("A room with a refusal should support both readings")
        }
        // Both readings must be offered; neither may be settled.
        XCTAssertFalse(reading.strange.isEmpty)
        XCTAssertFalse(reading.ordinary.isEmpty)
        let combined = "\(reading.strange) \(reading.ordinary)".lowercased()
        for verdict in ["is alive", "is sentient", "is conscious", "proves", "definitely"] {
            XCTAssertFalse(combined.contains(verdict), "The Book must stay agnostic: found '\(verdict)'")
        }
    }

    func testARoomWithoutARefusalHasNoDisagreementToOffer() {
        let state = PlaceState(id: "location-dorm")
        XCTAssertNil(PlaceMemoryEngine.disagreement(about: state, placeName: "The Dorm"))
    }

    // MARK: - Acting

    func testOnlyARoomWithBothHistoryAndARefusalMayActRatherThanHost() {
        var bare = PlaceState(id: "location-dorm")
        XCTAssertFalse(bare.mayActInsteadOfHost)
        bare.refusal = "has stopped being a shortcut"
        XCTAssertFalse(bare.mayActInsteadOfHost, "A refusal without history is an affectation")

        let earned = accumulate(PlaceState.reputationThreshold, tags: ["argument"])
        XCTAssertTrue(earned["location-great-hall"]?.mayActInsteadOfHost ?? false)
    }

    // MARK: - Persistence

    func testPlaceStateRoundTrips() throws {
        let states = accumulate(4, tags: ["argument", "unsettled"])
        let data = try JSONEncoder().encode(states)
        XCTAssertEqual(try JSONDecoder().decode([String: PlaceState].self, from: data), states)
    }

    func testLegacyPlaceStateDecodesWithoutTheOptionalFields() throws {
        let json = """
        {"id":"location-kitchens","incidents":[],"favoredOccupantIDs":[]}
        """
        let decoded = try JSONDecoder().decode(PlaceState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.id, "location-kitchens")
        XCTAssertNil(decoded.refusal)
    }

    func testEveryAuthoredLocationCanCarryState() {
        let locations = NarrativePackRegistry.entities.filter { $0.kind == .location }
        XCTAssertGreaterThanOrEqual(locations.count, 5)
        for location in locations {
            let states = accumulate(PlaceState.reputationThreshold, tags: ["argument"], placeID: location.id)
            XCTAssertNotNil(states[location.id]?.refusal, "\(location.id) should be able to acquire a refusal")
        }
    }
}
