import XCTest
@testable import InsideCoverCore

/// The causal layer keys uplift on movement, desk role, and context together,
/// and required three resolved treatment *and* three resolved control
/// opportunities inside one such cell before it would speak. A reader meets a
/// family in whichever role the desk had free that day, so their evidence
/// scatters: `CompoundingCurationTests` showed one family accumulating 64, 17
/// and 8 treatment rows in three separate role cells. A reader who opens the
/// Book twice a week would never fill any single one, and the loop stayed inert
/// for precisely the readers it most needed to reach.
///
/// Evidence is now pooled and discounted by how far it travelled from the
/// question being asked. These tests pin both halves of that bargain: thin
/// scattered evidence becomes readable, and borrowed evidence never gets to
/// impersonate local proof.
final class CausalEvidencePoolingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_050_000_000)
    private let recordedContext = "ctx-rain-evening"
    private let unseenContext = "ctx-clear-morning"
    private let living = "rain-door"
    private let hollow = "other-door"

    // MARK: - Evidence too scattered to read before

    func testEvidenceSpreadAcrossRolesIsReadableEvenThoughNoSingleCellIs() {
        // Two treatment and two control opportunities in each of the three desk
        // roles. Every cell sits below the old three-and-three gate, so the old
        // estimator returned nothing at all and the multiplier stayed at 1.
        var ledger = CausalCurationLedger()
        for (index, role) in BookSessionRole.allCases.enumerated() {
            for pair in 0..<2 {
                add(
                    to: &ledger,
                    id: "spread-\(role.rawValue)-\(pair)",
                    winner: living,
                    role: role,
                    at: now.addingTimeInterval(Double(index * 10 + pair) * -3_600)
                )
                add(
                    to: &ledger,
                    id: "spread-control-\(role.rawValue)-\(pair)",
                    winner: hollow,
                    role: role,
                    at: now.addingTimeInterval(Double(index * 10 + pair) * -3_600 - 600)
                )
            }
        }

        let estimate = ledger.estimate(
            movement: .freshSight,
            role: .door,
            sourceID: living,
            contextKey: unseenContext,
            now: now
        )

        XCTAssertEqual(estimate.treatmentCount, 6)
        XCTAssertEqual(estimate.controlCount, 6)
        XCTAssertFalse(
            estimate.usedExactContext,
            "Nothing was recorded in these conditions, so the reading is borrowed."
        )
        XCTAssertTrue(estimate.hasEnoughEvidence)
        XCTAssertLessThan(
            estimate.effectiveTreatmentSamples,
            Double(estimate.treatmentCount),
            "Borrowed rows were counted as though they had been recorded here."
        )
        XCTAssertGreaterThan(
            ledger.multiplier(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: unseenContext,
                now: now
            ),
            1,
            "A reader whose evidence is spread across roles still cannot be read."
        )
    }

    /// The one place pooling could have tightened rather than loosened things.
    /// Three opportunities sharing a movement and role but not a context used to
    /// qualify through the old broad-context branch, and must still qualify.
    func testTheOldBroadContextFloorStillQualifies() {
        var ledger = CausalCurationLedger()
        for index in 0..<3 {
            add(
                to: &ledger,
                id: "broad-\(index)",
                winner: living,
                at: now.addingTimeInterval(Double(index) * -3_600)
            )
            add(
                to: &ledger,
                id: "broad-control-\(index)",
                winner: hollow,
                at: now.addingTimeInterval(Double(index) * -3_600 - 600)
            )
        }

        let estimate = ledger.estimate(
            movement: .freshSight,
            role: .door,
            sourceID: living,
            contextKey: unseenContext,
            now: now
        )

        XCTAssertTrue(estimate.hasEnoughEvidence)
        XCTAssertGreaterThan(
            ledger.multiplier(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: unseenContext,
                now: now
            ),
            1
        )
    }

    // MARK: - What pooling must never buy

    func testAHandfulOfDistantOpportunitiesCannotMoveTheDesk() {
        var ledger = CausalCurationLedger()
        for index in 0..<2 {
            add(
                to: &ledger,
                id: "distant-\(index)",
                winner: living,
                movement: .exactLanguage,
                at: now.addingTimeInterval(Double(index) * -3_600)
            )
            add(
                to: &ledger,
                id: "distant-control-\(index)",
                winner: hollow,
                movement: .exactLanguage,
                at: now.addingTimeInterval(Double(index) * -3_600 - 600)
            )
        }

        let estimate = ledger.estimate(
            movement: .freshSight,
            role: .door,
            sourceID: living,
            contextKey: unseenContext,
            now: now
        )

        XCTAssertEqual(estimate.treatmentCount, 2)
        XCTAssertFalse(
            estimate.hasEnoughEvidence,
            "Two opportunities from an unrelated session intention became a reading."
        )
        XCTAssertEqual(
            ledger.multiplier(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: unseenContext,
                now: now
            ),
            1
        )
    }

    /// Evidence from a different session intention is admitted, but only a great
    /// deal of it can speak: a family's effect is partly its own property, and
    /// partly the movement it was serving.
    func testCrossMovementEvidenceSpeaksOnlyInBulk() {
        func multiplier(fromCount count: Int) -> Double {
            var ledger = CausalCurationLedger()
            for index in 0..<count {
                add(
                    to: &ledger,
                    id: "bulk-\(index)",
                    winner: living,
                    movement: .exactLanguage,
                    at: now.addingTimeInterval(Double(index) * -3_600)
                )
                add(
                    to: &ledger,
                    id: "bulk-control-\(index)",
                    winner: hollow,
                    movement: .exactLanguage,
                    at: now.addingTimeInterval(Double(index) * -3_600 - 600)
                )
            }
            return ledger.multiplier(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: unseenContext,
                now: now
            )
        }

        XCTAssertEqual(multiplier(fromCount: 5), 1, "Five distant rows should stay silent.")
        XCTAssertGreaterThan(
            multiplier(fromCount: 30),
            1,
            "A large body of cross-movement evidence should eventually be readable."
        )
    }

    /// The same number of opportunities says more when it was recorded in the
    /// conditions being asked about. Borrowed evidence enlarges the posterior
    /// less, so its interval stays wider and it remains harder to act on.
    func testLocalEvidenceOutranksTheSameAmountOfBorrowedEvidence() {
        func estimate(sameRole: Bool) -> CausalUpliftEstimate {
            var ledger = CausalCurationLedger()
            for index in 0..<6 {
                add(
                    to: &ledger,
                    id: "weight-\(index)",
                    winner: living,
                    role: sameRole ? .door : .horizon,
                    contextKey: recordedContext,
                    at: now.addingTimeInterval(Double(index) * -3_600)
                )
                add(
                    to: &ledger,
                    id: "weight-control-\(index)",
                    winner: hollow,
                    role: sameRole ? .door : .horizon,
                    contextKey: recordedContext,
                    at: now.addingTimeInterval(Double(index) * -3_600 - 600)
                )
            }
            return ledger.estimate(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: recordedContext,
                now: now
            )
        }

        let local = estimate(sameRole: true)
        let borrowed = estimate(sameRole: false)

        XCTAssertTrue(local.usedExactContext)
        XCTAssertFalse(borrowed.usedExactContext)
        XCTAssertEqual(local.treatmentCount, borrowed.treatmentCount)
        XCTAssertGreaterThan(
            local.effectiveTreatmentSamples,
            borrowed.effectiveTreatmentSamples
        )
        XCTAssertGreaterThan(
            local.conservativeLowerBound,
            borrowed.conservativeLowerBound,
            "Borrowed evidence produced just as confident a reading as local evidence."
        )
    }

    // MARK: - Resolution semantics the index must preserve

    /// Silence is only evidence once the reader has come back later. An
    /// unanswered opportunity stays unresolved until then, and cannot be counted
    /// as a failure the family earned.
    func testSilenceResolvesOnlyAfterTheReaderReturns() {
        let selectedAt = now.addingTimeInterval(-30 * 86_400)
        var unreturned = CausalCurationLedger()
        add(to: &unreturned, id: "silent", winner: living, at: selectedAt, outcome: nil)
        add(to: &unreturned, id: "silent-control", winner: hollow, at: selectedAt, outcome: nil)
        unreturned.lastRecordedAt = selectedAt.addingTimeInterval(86_400)

        var returned = unreturned
        returned.lastRecordedAt = selectedAt.addingTimeInterval(20 * 86_400)

        XCTAssertEqual(
            unreturned.estimate(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: recordedContext,
                now: now
            ).treatmentCount,
            0,
            "An opportunity the reader never answered was counted anyway."
        )
        XCTAssertEqual(
            returned.estimate(
                movement: .freshSight,
                role: .door,
                sourceID: living,
                contextKey: recordedContext,
                now: now
            ).treatmentCount,
            1,
            "A matured silence should resolve once the reader has returned since."
        )
    }

    // MARK: - Fixtures

    /// Records one logged draw and, unless `outcome` is nil, its resolved
    /// outcome. The winner is scored well and the loser poorly, so a reading
    /// has something to find.
    private func add(
        to ledger: inout CausalCurationLedger,
        id: String,
        winner: String,
        role: BookSessionRole = .door,
        movement: BookReenchantmentMovement = .freshSight,
        contextKey: String? = nil,
        at selectedAt: Date,
        outcome: Double? = -1
    ) {
        ledger.opportunities.append(CausalCurationOpportunity(
            id: id,
            policyVersion: CausalCurationReceipt.currentPolicyVersion,
            sessionID: "session-\(id)",
            movement: movement,
            role: role,
            selectedSourceID: winner,
            selectedArmID: "\(movement.rawValue)-\(role.rawValue)-\(winner)",
            contextKey: contextKey ?? recordedContext,
            propensity: 0.5,
            candidates: [living, hollow].map {
                CausalCurationCandidate(
                    sourceID: $0,
                    armID: "\(movement.rawValue)-\(role.rawValue)-\($0)",
                    weight: 1
                )
            },
            pressureCost: 0,
            selectedAt: selectedAt,
            dayID: BookDay.id(for: selectedAt)
        ))
        guard let outcome else { return }
        let value = outcome < 0 ? (winner == living ? 0.9 : 0.1) : outcome
        ledger.outcomes.append(CausalCurationOutcome(
            id: "outcome-\(id)",
            opportunityID: id,
            occurredAt: selectedAt.addingTimeInterval(120),
            kind: .livedEvidence,
            value: value,
            evidenceLine: nil
        ))
        ledger.lastRecordedAt = max(
            ledger.lastRecordedAt ?? selectedAt,
            selectedAt.addingTimeInterval(120)
        )
    }
}
