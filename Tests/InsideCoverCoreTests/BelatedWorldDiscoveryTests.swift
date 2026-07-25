import XCTest
@testable import InsideCoverCore

/// Silence only works if history can still be found. These lock the other half
/// of sovereignty: a discovery reports, it never re-spends, and it never asks
/// the reader to catch up.
final class BelatedWorldDiscoveryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour)) ?? Date()
    }

    private func movement(slot: String, created: Date, actor: String = "penny-blackletter") -> CastAgencyMovement {
        CastAgencyMovement(
            slotID: slot,
            kind: .relationship,
            actorID: actor,
            actorName: "Penny Blackletter",
            targetID: "wicker-eddies",
            targetName: "Wicker Eddies",
            amount: 2,
            line: "Penny Blackletter chipped 2 Belief from Wicker Eddies.",
            createdAt: created
        )
    }

    private func stateWithHistory(count: Int = 4) -> CastAgencyState {
        var state = CastAgencyState()
        let slots = (0..<count).map { "2026-07-20-s0\($0)" }
        for (index, slot) in slots.enumerated() {
            state.remember(
                movement(slot: slot, created: date(20, hour: index * 4), actor: "actor-\(index)"),
                keepingRecentSlots: Set(slots)
            )
        }
        return state
    }

    // MARK: - Selection

    func testNoDiscoveryWithoutEnoughUnmetHistory() {
        var state = CastAgencyState()
        state.remember(movement(slot: "a", created: date(20, hour: 1)), keepingRecentSlots: ["a"])

        let found = BelatedWorldDiscovery.candidate(
            in: state,
            currentSlotID: "2026-07-20-s05",
            now: date(20, hour: 22)
        )
        XCTAssertNil(found, "One lonely movement is not depth")
    }

    func testWitnessedAndDiscoveredMovementsAreNeverOffered() {
        var state = stateWithHistory()
        for movement in state.recentMovements {
            state.markWitnessed(slotID: movement.slotID)
        }

        XCTAssertNil(BelatedWorldDiscovery.candidate(
            in: state,
            currentSlotID: "2026-07-20-s05",
            now: date(20, hour: 22)
        ))
    }

    func testTheCurrentSlotIsNeverADiscovery() {
        // Current news is not a find. Only a passed slot can be belated.
        let state = stateWithHistory()
        for slot in state.recentMovements.map(\.slotID) {
            let found = BelatedWorldDiscovery.candidate(in: state, currentSlotID: slot, now: date(20, hour: 22))
            XCTAssertNotEqual(found?.slotID, slot)
        }
    }

    func testSelectionIsDeterministicSoRefreshCannotReroll() {
        let state = stateWithHistory()
        let a = BelatedWorldDiscovery.candidate(in: state, currentSlotID: "2026-07-20-s05", now: date(20, hour: 22))
        let b = BelatedWorldDiscovery.candidate(in: state, currentSlotID: "2026-07-20-s05", now: date(20, hour: 23))

        XCTAssertEqual(a, b)
    }

    func testDiscoveryIsUncommonAcrossManySlots() {
        let state = stateWithHistory(count: 6)
        var hits = 0
        for index in 0..<200 {
            if BelatedWorldDiscovery.candidate(
                in: state,
                currentSlotID: "probe-slot-\(index)",
                now: date(21, hour: 12)
            ) != nil {
                hits += 1
            }
        }

        // Most gossip stays current news; discovery is the exception.
        XCTAssertGreaterThan(hits, 0)
        XCTAssertLessThan(hits, 100, "Discovery should not dominate the gossip surface")
    }

    func testMarkingDiscoveredRemovesItFromTheOfferedPool() {
        var state = stateWithHistory(count: 6)
        // The gate is deterministic per slot, so probe until one opens rather
        // than assuming any particular slot is a discovery slot.
        let found = (0..<200).lazy.compactMap { index in
            BelatedWorldDiscovery.candidate(
                in: state,
                currentSlotID: "probe-slot-\(index)",
                now: self.date(20, hour: 22)
            )
        }.first
        guard let found else { return XCTFail("Expected a discovery from ample history") }

        state.markDiscovered(movementID: found.id, at: date(20, hour: 22))
        XCTAssertFalse(state.unwitnessedMovements.contains { $0.id == found.id })
    }

    // MARK: - Framing

    func testElapsedPhraseStaysVagueRatherThanBecomingATimestamp() {
        let now = date(24, hour: 12)
        XCTAssertEqual(BelatedWorldDiscovery.elapsedPhrase(from: date(24, hour: 2), to: now, calendar: calendar), "earlier today")
        XCTAssertEqual(BelatedWorldDiscovery.elapsedPhrase(from: date(23, hour: 2), to: now, calendar: calendar), "yesterday")
        XCTAssertEqual(BelatedWorldDiscovery.elapsedPhrase(from: date(21, hour: 2), to: now, calendar: calendar), "a few days ago")
        XCTAssertEqual(BelatedWorldDiscovery.elapsedPhrase(from: date(10, hour: 2), to: now, calendar: calendar), "last week")
    }

    func testFramingIsStableForTheSameMovement() {
        let subject = movement(slot: "2026-07-20-s01", created: date(20, hour: 4))
        let a = BelatedWorldDiscovery.framing(for: subject, now: date(21, hour: 9), calendar: calendar)
        let b = BelatedWorldDiscovery.framing(for: subject, now: date(21, hour: 9), calendar: calendar)

        XCTAssertEqual(a, b)
        XCTAssertTrue(a.detail.contains("Penny Blackletter"))
    }

    func testFramingNeverScoldsTheReaderForBeingAbsent() {
        // Absence is not a failure. The Academy reports; it does not reproach.
        let forbidden = ["should have", "you missed out", "come back", "don't forget",
                         "catch up", "sorry you", "if only you", "too late", "streak"]
        for index in 0..<40 {
            let subject = movement(slot: "slot-\(index)", created: date(20, hour: 3), actor: "actor-\(index)")
            let framing = BelatedWorldDiscovery.framing(for: subject, now: date(22, hour: 10), calendar: calendar)
            let text = "\(framing.headline) \(framing.prompt) \(framing.detail)".lowercased()
            for phrase in forbidden {
                XCTAssertFalse(text.contains(phrase), "Belated framing must not scold: found '\(phrase)'")
            }
        }
    }

    // MARK: - The surface reports, it does not re-spend

    func testBelatedSurfaceCarriesNoBeliefOrRelationshipMoves() {
        var inputs = BookSourceInputs.empty
        inputs.castAgency = stateWithHistory(count: 6)
        let day = BookDay(id: "2026-07-21", date: date(21, hour: 12), pages: [])

        // Probe slots until the deterministic gate yields a discovery.
        var belated: SurfacePage?
        for hour in stride(from: 0, to: 24 * 12, by: 4) {
            let probe = calendar.date(byAdding: .hour, value: hour, to: date(21, hour: 0)) ?? date(21, hour: 0)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            if surface.payload.metadata["belated"] == "true" {
                belated = surface
                break
            }
        }

        guard let belated else { return XCTFail("Expected at least one belated surface across many slots") }
        XCTAssertNil(belated.payload.metadata["relationshipMoves"])
        XCTAssertNil(belated.payload.metadata["pageBeliefMoves"])
        XCTAssertNotNil(belated.payload.metadata[GossipSimulationBuilder.discoveredMovementKey])
        XCTAssertEqual(belated.type, .gossip)
    }

    func testAnEmptyLedgerAlwaysProducesOrdinaryCurrentGossip() {
        let inputs = BookSourceInputs.empty
        let day = BookDay(id: "2026-07-21", date: date(21, hour: 12), pages: [])

        for hour in stride(from: 0, to: 48, by: 4) {
            let probe = calendar.date(byAdding: .hour, value: hour, to: date(21, hour: 0)) ?? date(21, hour: 0)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            XCTAssertNotEqual(surface.payload.metadata["belated"], "true")
        }
    }
}
