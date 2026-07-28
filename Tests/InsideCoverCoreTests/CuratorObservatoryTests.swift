import XCTest
@testable import InsideCoverCore

final class CuratorObservatoryTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(
        year: 2026,
        month: 7,
        day: 27,
        hour: 16
    ))!

    func testSnapshotJoinsCandidateSelectionIntentionAndEncounterWithoutCopyingProse() throws {
        let secret = "SECRET CALENDAR TITLE AT 40.7128"
        let candidate = page(
            id: "observatory-door",
            sourceID: "source-door",
            metadata: [
                "calendarTitle": secret,
                "locationLabel": secret
            ],
            copy: secret
        ).withResolvedPageCapabilities()
        let rejected = page(id: "observatory-disabled", sourceID: "source-disabled")
        let intention = sessionIntention()
        let receipt = causalReceipt(
            id: "observatory-opportunity",
            sourceID: candidate.sourceID,
            selectedAt: now
        )
        let visible = receipt.applying(
            to: intention.applying(to: candidate, role: .door)
        )
        let preferences = CuratorSurfacePreferences(
            disabledSourceIDs: [rejected.sourceID]
        )

        let snapshot = CuratorObservatory.snapshot(
            day: day,
            candidates: [candidate, rejected],
            visibleSurfaces: [visible],
            inputs: .empty,
            preferences: preferences,
            now: now
        )

        XCTAssertEqual(snapshot.candidateCount, 2)
        XCTAssertEqual(snapshot.eligibleCandidateCount, 1)
        XCTAssertEqual(snapshot.rejectedCandidateCount, 1)
        XCTAssertEqual(snapshot.rejectionCounts["dismissed-or-disabled"], 1)
        XCTAssertEqual(snapshot.intention?.id, intention.id)
        XCTAssertEqual(snapshot.intention?.movement, .freshSight)
        XCTAssertEqual(snapshot.exposures.first?.surfaceID, candidate.id)
        XCTAssertEqual(snapshot.exposures.first?.role, .door)
        XCTAssertEqual(snapshot.exposures.first?.causalOpportunityID, receipt.id)
        XCTAssertEqual(snapshot.exposures.first?.encounterMode, candidate.livedEncounterContract.mode)
        XCTAssertFalse(String(reflecting: snapshot).contains(secret))
    }

    func testInteractionOnlyNeverAppearsAsLivedSupport() {
        let receipt = causalReceipt(
            id: "interaction-only",
            sourceID: "source-door",
            selectedAt: now
        )
        let visible = receipt.applying(
            to: sessionIntention().applying(
                to: page(id: "interaction-page", sourceID: receipt.chosenSourceID)
                    .withResolvedPageCapabilities(),
                role: .door
            )
        )
        let ledger = CausalCurationLedger(
            opportunities: [opportunity(from: receipt)],
            outcomes: [CausalCurationOutcome(
                id: "interaction-outcome",
                opportunityID: receipt.id,
                occurredAt: now.addingTimeInterval(60),
                kind: .participated,
                value: 0.3,
                evidenceLine: "Opened inside the Book."
            )]
        )
        var inputs = BookSourceInputs.empty
        inputs.readerAliveness = ReaderAlivenessModel(causalLedger: ledger)

        let snapshot = CuratorObservatory.snapshot(
            day: day,
            candidates: [visible],
            visibleSurfaces: [visible],
            inputs: inputs,
            now: now.addingTimeInterval(120)
        )

        XCTAssertEqual(snapshot.exposures.first?.outcomeState, .interactionOnly)
        XCTAssertEqual(snapshot.exposures.first?.qualifiedOutcomeCount, 0)
        XCTAssertEqual(snapshot.causal.interactionOnlyOutcomeCount, 1)
        XCTAssertEqual(snapshot.causal.livedSupportCount, 0)
        XCTAssertEqual(snapshot.northStar.causalOutcomeCount, 0)
    }

    func testCounterEvidenceRemainsVisibleBesideLaterSupport() {
        let receipt = causalReceipt(
            id: "mixed-opportunity",
            sourceID: "source-door",
            selectedAt: now
        )
        let visible = receipt.applying(
            to: sessionIntention().applying(
                to: page(id: "mixed-page", sourceID: receipt.chosenSourceID)
                    .withResolvedPageCapabilities(),
                role: .door
            )
        )
        let ledger = CausalCurationLedger(
            opportunities: [opportunity(from: receipt)],
            outcomes: [
                CausalCurationOutcome(
                    id: "mixed-declined",
                    opportunityID: receipt.id,
                    occurredAt: now.addingTimeInterval(60),
                    kind: .declined,
                    value: 0,
                    evidenceLine: "Not today."
                ),
                CausalCurationOutcome(
                    id: "mixed-lived",
                    opportunityID: receipt.id,
                    occurredAt: now.addingTimeInterval(3_600),
                    kind: .livedEvidence,
                    value: 0.82,
                    evidenceLine: "Something later returned from life."
                )
            ]
        )
        var inputs = BookSourceInputs.empty
        inputs.readerAliveness = ReaderAlivenessModel(causalLedger: ledger)

        let snapshot = CuratorObservatory.snapshot(
            day: day,
            candidates: [visible],
            visibleSurfaces: [visible],
            inputs: inputs,
            now: now.addingTimeInterval(7_200)
        )

        XCTAssertEqual(snapshot.exposures.first?.outcomeState, .mixed)
        XCTAssertEqual(snapshot.exposures.first?.qualifiedOutcomeCount, 2)
        XCTAssertEqual(snapshot.causal.counterEvidenceCount, 1)
        XCTAssertEqual(snapshot.causal.livedSupportCount, 1)
        XCTAssertEqual(snapshot.causal.unresolvedOpportunityCount, 0)
    }

    func testSnapshotIsBoundedWithoutLosingOpportunityCounts() {
        let candidates = (0..<140).map {
            page(id: "bounded-\($0)", sourceID: "bounded-source-\($0)")
        }

        let snapshot = CuratorObservatory.snapshot(
            day: day,
            candidates: candidates,
            visibleSurfaces: [],
            inputs: .empty,
            now: now
        )

        XCTAssertEqual(snapshot.candidateCount, 140)
        XCTAssertEqual(snapshot.candidates.count, CuratorObservatory.maxCandidateRows)
    }

    func testColdStartKeepsDeclaredPriorsSeparateFromCausalEvidence() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            selfFact(
                questionID: "onboarding-most-alive",
                answer: "Outside somewhere"
            ),
            selfFact(
                questionID: "onboarding-magic-source",
                answer: "Wild weather"
            ),
            selfFact(
                questionID: "time-budget",
                answer: "Ten minutes"
            )
        ]

        let snapshot = CuratorObservatory.snapshot(
            day: day,
            candidates: [],
            visibleSurfaces: [],
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(snapshot.version, 2)
        XCTAssertEqual(snapshot.coldStart.stage, .seeded)
        XCTAssertEqual(snapshot.coldStart.onboardingPriorCount, 2)
        XCTAssertEqual(snapshot.coldStart.boundaryCount, 1)
        XCTAssertEqual(snapshot.coldStart.qualifiedOutcomeCount, 0)
        XCTAssertEqual(snapshot.coldStart.answeredHighValueQuestionCount, 1)
        XCTAssertFalse(snapshot.coldStart.missingHighValueQuestionIDs.contains("time-budget"))
        XCTAssertTrue(snapshot.coldStart.missingHighValueQuestionIDs.contains("leaving-home"))
    }

    func testExposureShowsTheCausalEffectActuallyAppliedByRanking() throws {
        let treatmentReceipts = (0..<3).map {
            causalReceipt(
                id: "effect-treatment-\($0)",
                sourceID: "source-a",
                selectedAt: now.addingTimeInterval(Double(-7_200 - $0 * 300))
            )
        }
        let controlReceipts = (0..<3).map {
            causalReceipt(
                id: "effect-control-\($0)",
                sourceID: "source-b",
                selectedAt: now.addingTimeInterval(Double(-5_400 - $0 * 300))
            )
        }
        let receipts = treatmentReceipts + controlReceipts
        let outcomes = receipts.map { receipt in
            CausalCurationOutcome(
                id: "outcome-\(receipt.id)",
                opportunityID: receipt.id,
                occurredAt: receipt.selectedAt.addingTimeInterval(120),
                kind: .livedEvidence,
                value: receipt.chosenSourceID == "source-a" ? 0.9 : 0.1,
                evidenceLine: nil
            )
        }
        let ledger = CausalCurationLedger(
            opportunities: receipts.map(opportunity(from:)),
            outcomes: outcomes
        )
        var inputs = BookSourceInputs.empty
        inputs.readerAliveness = ReaderAlivenessModel(causalLedger: ledger)
        let visibleReceipt = try XCTUnwrap(treatmentReceipts.first)
        let visible = visibleReceipt.applying(
            to: sessionIntention().applying(
                to: page(id: "effect-visible", sourceID: "source-a")
                    .withResolvedPageCapabilities(),
                role: .door
            )
        )

        let snapshot = CuratorObservatory.snapshot(
            day: day,
            candidates: [visible],
            visibleSurfaces: [visible],
            inputs: inputs,
            now: now
        )
        let effect = try XCTUnwrap(snapshot.exposures.first?.causalEffect)

        XCTAssertTrue(effect.isLearned)
        XCTAssertEqual(effect.treatmentCount, 3)
        XCTAssertEqual(effect.controlCount, 3)
        XCTAssertGreaterThan(effect.estimatedUplift, 0)
        XCTAssertEqual(
            effect.appliedMultiplier,
            ledger.multiplier(
                movement: visibleReceipt.movement,
                role: visibleReceipt.role,
                sourceID: visibleReceipt.chosenSourceID,
                contextKey: visibleReceipt.contextKey,
                now: now
            ),
            accuracy: 0.000_001
        )
    }

    private var day: BookDay {
        BookDay(id: BookDay.id(for: now), date: now, pages: [])
    }

    private func page(
        id: String,
        sourceID: String,
        metadata: [String: String] = [:],
        copy: String = "A small ordinary possibility."
    ) -> SurfacePage {
        var metadata = metadata
        metadata["noveltyKey"] = id
        return SurfacePage(
            id: id,
            type: .wonderCompass,
            sourceID: sourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: 70,
            prompt: copy,
            detail: copy,
            payload: BookPagePayload(
                headline: copy,
                body: copy,
                metadata: metadata
            )
        )
    }

    private func sessionIntention() -> BookSessionIntention {
        BookSessionIntention(
            id: "observatory-session",
            dayID: day.id,
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: ["evidence-page"],
            evidenceReason: "A private reason that the Observatory must not copy.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(6 * 3_600),
            seed: "observatory-seed"
        )
    }

    private func causalReceipt(
        id: String,
        sourceID: String,
        selectedAt: Date
    ) -> CausalCurationReceipt {
        let candidates = [
            CausalCurationCandidate(
                sourceID: "source-a",
                armID: "freshSight-door-source-a",
                weight: 1
            ),
            CausalCurationCandidate(
                sourceID: "source-b",
                armID: "freshSight-door-source-b",
                weight: 1
            ),
            CausalCurationCandidate(
                sourceID: sourceID,
                armID: "freshSight-door-\(sourceID)",
                weight: 1
            )
        ]
        let uniqueCandidates = Dictionary(grouping: candidates, by: \.sourceID)
            .compactMap { $0.value.first }
            .sorted { $0.sourceID < $1.sourceID }
        return CausalCurationReceipt(
            id: id,
            policyVersion: CausalCurationReceipt.currentPolicyVersion,
            sessionID: "session-\(id)",
            movement: .freshSight,
            role: .door,
            chosenSourceID: sourceID,
            chosenArmID: "freshSight-door-\(sourceID)",
            contextKey: "ctx-observatory",
            propensity: 1 / Double(uniqueCandidates.count),
            candidates: uniqueCandidates,
            pressureCost: 0.08,
            selectedAt: selectedAt,
            chosenType: .wonderCompass,
            typePropensity: 0.5,
            pagePropensityWithinType: 0.5,
            pageCandidateCountWithinType: 2
        )
    }

    private func opportunity(from receipt: CausalCurationReceipt) -> CausalCurationOpportunity {
        CausalCurationOpportunity(
            id: receipt.id,
            policyVersion: receipt.policyVersion,
            sessionID: receipt.sessionID,
            movement: receipt.movement,
            role: receipt.role,
            selectedSourceID: receipt.chosenSourceID,
            selectedArmID: receipt.chosenArmID,
            contextKey: receipt.contextKey,
            propensity: receipt.propensity,
            candidates: receipt.candidates,
            pressureCost: receipt.pressureCost,
            selectedAt: receipt.selectedAt,
            dayID: BookDay.id(for: receipt.selectedAt)
        )
    }

    private func selfFact(questionID: String, answer: String) -> SelfFact {
        SelfFact(
            id: "observatory-\(questionID)",
            questionID: questionID,
            question: questionID,
            answer: answer,
            bookTranslation: answer,
            sensitivity: .comfort,
            usePermission: .privateContext,
            tags: ["curation"],
            createdAt: now,
            updatedAt: now
        )
    }
}
