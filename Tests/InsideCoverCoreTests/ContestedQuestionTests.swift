import XCTest
@testable import InsideCoverCore

/// A culture of interpretation, not a debate minigame. Several characters hold
/// different positions on the same disputed event, the Book is a participant
/// rather than the referee, and later evidence is allowed to embarrass it.
final class ContestedQuestionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func days(_ count: Double) -> Date { start.addingTimeInterval(count * 86_400) }

    private var entities: [NarrativeWorldEntity] { NarrativePackRegistry.entities }
    private var undertakings: [CastUndertaking] { CastUndertakingEngine.seeded(existing: [], now: start) }

    private func maturePlace(tag: String = "argument") -> [String: PlaceState] {
        var places: [String: PlaceState] = [:]
        for index in 0..<PlaceState.reputationThreshold {
            places = PlaceMemoryEngine.recording(
                places,
                incident: PlaceIncident(
                    id: "i-\(index)", line: "An argument.",
                    participantIDs: ["penny-blackletter"], tags: [tag], occurredAt: start
                ),
                placeID: "location-great-hall"
            )
        }
        return places
    }

    private func opened() -> ContestedQuestion? {
        ContestedQuestionEngine.opening(
            movements: [], undertakings: undertakings, places: maturePlace(),
            entities: entities, existing: [], now: start
        )
    }

    // MARK: - Opening

    func testAQuestionOpensWithSeveralDifferingPositions() {
        guard let question = opened() else { return XCTFail("Expected a contested question") }
        XCTAssertGreaterThanOrEqual(question.positions.count, ContestedQuestion.minimumPositions)
        XCTAssertLessThanOrEqual(question.positions.count, ContestedQuestion.maximumPositions)
        XCTAssertEqual(Set(question.positions.map(\.holderID)).count, question.positions.count)
        XCTAssertFalse(question.question.isEmpty)
    }

    func testOnlyOneArgumentRunsAtATime() {
        guard let first = opened() else { return XCTFail("Expected a question") }
        let second = ContestedQuestionEngine.opening(
            movements: [], undertakings: undertakings, places: maturePlace(),
            entities: entities, existing: [first], now: days(1)
        )
        XCTAssertNil(second, "A society with four simultaneous scandals is a soap opera")
    }

    func testOpeningIsDeterministic() {
        XCTAssertEqual(opened(), opened())
    }

    func testPositionsAreGroundedInRealBusinessRatherThanInvented() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        let undertakingIDs = Set(undertakings.map(\.id))
        for position in question.positions {
            XCTAssertFalse(position.groundedInIDs.isEmpty)
            for id in position.groundedInIDs {
                XCTAssertTrue(undertakingIDs.contains(id), "Position cites something that does not exist")
            }
        }
    }

    func testNoQuestionWithoutRunningBusiness() {
        XCTAssertNil(ContestedQuestionEngine.opening(
            movements: [], undertakings: [], places: [:],
            entities: entities, existing: [], now: start
        ))
    }

    // MARK: - The Book is a participant, not the referee

    func testTheBookHoldsAProvisionalOpinionAndSaysItIsAGuess() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        XCTAssertFalse(question.bookPosition.isEmpty)
        XCTAssertNotNil(question.bookBackedHolderID)
        XCTAssertTrue(question.bookPosition.lowercased().contains("guess"),
                      "The Book must flag its own reading as provisional")
    }

    func testTheBookBacksSomebodyWhoIsActuallySpeaking() {
        guard let question = opened(), let backed = question.bookBackedHolderID else {
            return XCTFail("Expected a backed position")
        }
        XCTAssertTrue(question.speakingPositions.contains { $0.holderID == backed })
    }

    // MARK: - Embarrassment

    func testPhysicalEvidenceCanContradictTheBook() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        let complicated = ContestedQuestionEngine.complicating(
            question, withTrace: "The room disagrees: it has stopped being a shortcut.", now: days(4)
        )
        XCTAssertEqual(complicated.status, .complicated)
        XCTAssertEqual(complicated.embarrassedHolderID, question.bookBackedHolderID)
        XCTAssertNotNil(complicated.contradictingEvidence)
    }

    func testEmbarrassmentBecomesAnOrdinaryFaultAndRepairEpisode() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        let complicated = ContestedQuestionEngine.complicating(question, withTrace: "A scorch mark.", now: days(4))
        guard let fault = ContestedQuestionEngine.faultEpisode(from: complicated, now: days(4)) else {
            return XCTFail("Expected a fault episode — the Book was wrong in public")
        }
        XCTAssertEqual(fault.kind, .prematurePattern)
        XCTAssertFalse(fault.admission.isEmpty)
        XCTAssertFalse(fault.repair.isEmpty)
        XCTAssertTrue(fault.repair.lowercased().contains("both"),
                      "The repair should leave both readings standing, not pick the other side")
    }

    func testAnUncomplicatedQuestionProducesNoFault() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        XCTAssertNil(ContestedQuestionEngine.faultEpisode(from: question, now: days(1)))
    }

    func testComplicatingIsIdempotentAndOnlyAppliesToAnOpenQuestion() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        let once = ContestedQuestionEngine.complicating(question, withTrace: "A trace.", now: days(4))
        let twice = ContestedQuestionEngine.complicating(once, withTrace: "A different trace.", now: days(5))
        XCTAssertEqual(once, twice, "A question can only be embarrassed once")
    }

    // MARK: - Faults gate testimony

    func testAFaultCanStopACharacterTestifying() {
        // Trencher will not let anyone finish thanking him, so he will not
        // speak while he is being thanked.
        guard let trencher = entities.first(where: { $0.id == "ambrose-trencher" }) else {
            return XCTFail("Trencher should exist")
        }
        let reason = ContestedQuestionEngine.silenceReason(for: trencher, seed: "seed", isSubject: false)
        XCTAssertEqual(reason, .faultPreventsIt)
    }

    func testTheSubjectOfTheQuestionAlwaysSpeaks() {
        guard let trencher = entities.first(where: { $0.id == "ambrose-trencher" }) else {
            return XCTFail("Trencher should exist")
        }
        XCTAssertEqual(
            ContestedQuestionEngine.silenceReason(for: trencher, seed: "seed", isSubject: true),
            .none
        )
    }

    func testASilentHolderIsStillAParticipant() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        for position in question.positions where !position.isSpeaking {
            XCTAssertFalse(position.claim.isEmpty, "The shape of a refusal is information")
        }
    }

    func testMostCharactersSimplyHaveAnOpinion() {
        var speaking = 0
        for entity in DisagreementEngine.eligible(from: entities) {
            if ContestedQuestionEngine.silenceReason(for: entity, seed: "s", isSubject: false) == .none {
                speaking += 1
            }
        }
        let eligible = DisagreementEngine.eligible(from: entities).count
        XCTAssertGreaterThan(speaking * 2, eligible, "Silence should be the exception")
    }

    // MARK: - Resting

    func testAnArgumentRestsUnresolvedRatherThanBeingSettled() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        XCTAssertEqual(ContestedQuestionEngine.resting(question, now: days(5)).status, .open)
        let rested = ContestedQuestionEngine.resting(question, now: days(40))
        XCTAssertEqual(rested.status, .restingUnresolved)
        XCTAssertFalse(rested.isLive)
    }

    func testNoSurfaceEverAnnouncesAWinner() {
        guard let question = opened() else { return XCTFail("Expected a question") }
        let complicated = ContestedQuestionEngine.complicating(question, withTrace: "A scorch mark.", now: days(4))
        let text = ([complicated.question, complicated.bookPosition]
            + complicated.positions.map(\.claim)
            + [complicated.contradictingEvidence ?? ""])
            .joined(separator: " ").lowercased()
        for verdict in ["was right", "was proven", "the answer is", "case closed", "we now know", "confirmed that"] {
            XCTAssertFalse(text.contains(verdict), "A contested question must not resolve: '\(verdict)'")
        }
    }

    // MARK: - Persistence

    func testQuestionRoundTrips() throws {
        guard let question = opened() else { return XCTFail("Expected a question") }
        let data = try JSONEncoder().encode([question])
        XCTAssertEqual(try JSONDecoder().decode([ContestedQuestion].self, from: data), [question])
    }
}
