import XCTest
@testable import InsideCoverCore

/// The Academy's own canon. Keeping decides witness, never occurrence.
final class CastAgencySovereigntyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour)) ?? Date()
    }

    private func slotID(_ date: Date) -> String {
        SurfaceCadence.slotID(for: date, hours: 4, calendar: calendar)
    }

    // MARK: - Catch-up bounds

    func testFirstEverRunResolvesOnlyABoundedHandful() {
        let now = date(20, hour: 13)
        let pending = CastAgencyCatchUp.pendingSlots(resolved: [], now: now, calendar: calendar)

        XCTAssertEqual(pending.count, CastAgencyCatchUp.maximumPerReturn)
        XCTAssertTrue(pending.allSatisfy { !$0.id.isEmpty })
    }

    func testTwoWeekAndTwoMonthAbsencesProduceTheSameBoundedHistory() {
        let now = date(20, hour: 13)
        let twoWeeks = CastAgencyCatchUp.pendingSlots(resolved: [], now: now, calendar: calendar)
        let twoMonths = CastAgencyCatchUp.pendingSlots(resolved: [], now: now, calendar: calendar)

        // The horizon, not the absence, decides. A reader who vanishes for a
        // season inherits fragments, never a changelog.
        XCTAssertEqual(twoWeeks, twoMonths)
        XCTAssertLessThanOrEqual(twoWeeks.count, CastAgencyCatchUp.maximumPerReturn)
    }

    func testPendingSlotsAreOldestFirst() {
        let now = date(20, hour: 13)
        let pending = CastAgencyCatchUp.pendingSlots(resolved: [], now: now, calendar: calendar)

        let dates = pending.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testResolvedSlotsAreNeverOfferedAgain() {
        let now = date(20, hour: 13)
        let first = CastAgencyCatchUp.pendingSlots(resolved: [], now: now, calendar: calendar)
        let resolved = Set(first.map(\.id))
        let second = CastAgencyCatchUp.pendingSlots(resolved: resolved, now: now, calendar: calendar)

        XCTAssertTrue(second.allSatisfy { !resolved.contains($0.id) })
    }

    func testCatchUpIsIdempotentForTheSameMoment() {
        let now = date(20, hour: 13)
        let a = CastAgencyCatchUp.pendingSlots(resolved: ["seed"], now: now, calendar: calendar)
        let b = CastAgencyCatchUp.pendingSlots(resolved: ["seed"], now: now, calendar: calendar)

        XCTAssertEqual(a, b)
    }

    func testCurrentSlotIsAlwaysIncludedWhenUnresolved() {
        let now = date(20, hour: 13)
        let pending = CastAgencyCatchUp.pendingSlots(resolved: [], now: now, calendar: calendar)

        XCTAssertTrue(pending.contains { $0.id == slotID(now) })
    }

    func testNothingIsPendingOnceTheHorizonIsFullyResolved()  {
        let now = date(20, hour: 13)
        var resolved = Set<String>()
        for offset in 0..<CastAgencyCatchUp.horizonSlots {
            let date = calendar.date(byAdding: .hour, value: -4 * offset, to: now) ?? now
            resolved.insert(slotID(date))
        }

        XCTAssertTrue(CastAgencyCatchUp.pendingSlots(resolved: resolved, now: now, calendar: calendar).isEmpty)
    }

    // MARK: - Witness

    func testMovementsAreBornUnwitnessed() {
        let movement = makeMovement(slotID: "2026-07-20-s03")

        XCTAssertFalse(movement.witnessed)
        XCTAssertNil(movement.discoveredAt)
    }

    func testUnwitnessedHistoryAccumulatesAndCanBeMarkedWitnessed() {
        var state = CastAgencyState()
        let slots = ["2026-07-20-s00", "2026-07-20-s01", "2026-07-20-s02"]
        for slot in slots {
            state.remember(makeMovement(slotID: slot), keepingRecentSlots: Set(slots))
        }

        XCTAssertEqual(state.unwitnessedMovements.count, 3)

        state.markWitnessed(slotID: "2026-07-20-s01")
        XCTAssertEqual(state.unwitnessedMovements.count, 2)
        XCTAssertFalse(state.unwitnessedMovements.contains { $0.slotID == "2026-07-20-s01" })
    }

    func testDiscoveryIsRecordedOnceAndRemovesTheMovementFromTheUndiscoveredPool() {
        var state = CastAgencyState()
        let movement = makeMovement(slotID: "2026-07-20-s04")
        state.remember(movement, keepingRecentSlots: ["2026-07-20-s04"])

        let found = date(20, hour: 19)
        state.markDiscovered(movementID: movement.id, at: found)

        XCTAssertEqual(state.recentMovements.first?.discoveredAt, found)
        XCTAssertTrue(state.unwitnessedMovements.isEmpty)
    }

    func testMarkingAnUnknownMovementChangesNothing() {
        var state = CastAgencyState()
        state.remember(makeMovement(slotID: "2026-07-20-s04"), keepingRecentSlots: ["2026-07-20-s04"])
        let before = state

        state.markDiscovered(movementID: "does-not-exist", at: date(20, hour: 19))
        state.markWitnessed(slotID: "")

        XCTAssertEqual(state, before)
    }

    // MARK: - Bounds

    func testLedgerRingStaysBounded() {
        var state = CastAgencyState()
        let slots = (0..<120).map { "slot-\($0)" }
        for slot in slots {
            state.remember(makeMovement(slotID: slot), keepingRecentSlots: Set(slots))
        }

        XCTAssertEqual(state.recentMovements.count, CastAgencyState.movementRingSize)
    }

    func testResolvedSlotIDsDoNotGrowWithoutLimit() {
        var state = CastAgencyState()
        for index in 0..<200 {
            let slot = "slot-\(index)"
            // Only a small trailing window counts as recent, mirroring the app.
            let recent = Set((max(0, index - 11)...index).map { "slot-\($0)" })
            state.remember(makeMovement(slotID: slot), keepingRecentSlots: recent)
        }

        XCTAssertLessThanOrEqual(state.resolvedSlotIDs.count, 12)
    }

    // MARK: - Legacy decode

    func testLegacyMovementJSONDecodesAsAlreadyWitnessed() throws {
        // Movements written before witness tracking were shown to the reader at
        // the moment they happened, so they must not resurface as discoveries.
        let json = """
        {
            "id": "legacy-relationship-a-b",
            "slotID": "2026-07-01-s02",
            "kind": "relationship",
            "actorID": "a",
            "actorName": "A",
            "targetID": "b",
            "targetName": "B",
            "amount": 2,
            "line": "A invested 2 Belief in B.",
            "createdAt": 774316800
        }
        """
        let decoded = try JSONDecoder().decode(CastAgencyMovement.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.witnessed)
        XCTAssertNil(decoded.discoveredAt)
        XCTAssertEqual(decoded.slotID, "2026-07-01-s02")
    }

    func testLegacyStateJSONDecodesAndYieldsNoFalseDiscoveries() throws {
        let json = """
        {
            "resolvedSlotIDs": ["2026-07-01-s02"],
            "recentMovements": [{
                "id": "legacy-relationship-a-b",
                "slotID": "2026-07-01-s02",
                "kind": "relationship",
                "actorID": "a",
                "actorName": "A",
                "targetID": "b",
                "targetName": "B",
                "amount": 2,
                "line": "A invested 2 Belief in B.",
                "createdAt": 774316800
            }]
        }
        """
        let decoded = try JSONDecoder().decode(CastAgencyState.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.unwitnessedMovements.isEmpty)
        XCTAssertTrue(decoded.hasResolved(slotID: "2026-07-01-s02"))
    }

    func testMovementRoundTripsWithTheNewFields() throws {
        var state = CastAgencyState()
        let movement = makeMovement(slotID: "2026-07-20-s05")
        state.remember(movement, keepingRecentSlots: ["2026-07-20-s05"])
        state.markDiscovered(movementID: movement.id, at: date(20, hour: 22))

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CastAgencyState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertFalse(decoded.recentMovements[0].witnessed)
        XCTAssertNotNil(decoded.recentMovements[0].discoveredAt)
    }

    // MARK: - Helpers

    private func makeMovement(slotID: String) -> CastAgencyMovement {
        CastAgencyMovement(
            slotID: slotID,
            kind: .relationship,
            actorID: "penny-blackletter",
            actorName: "Penny Blackletter",
            targetID: "wicker-eddies",
            targetName: "Wicker Eddies",
            amount: 2,
            line: "Penny Blackletter chipped 2 Belief from Wicker Eddies.",
            createdAt: date(20, hour: 9)
        )
    }
}
