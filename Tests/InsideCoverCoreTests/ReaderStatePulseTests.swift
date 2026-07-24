import XCTest
@testable import InsideCoverCore

final class ReaderStatePulseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_822_400)

    func testCurrentStateExpiresLikeWeatherInsteadOfBecomingIdentity() {
        var ledger = ReaderStatePulseLedger.empty
        ledger.record(pulse(
            id: "fresh",
            dimension: .aliveness,
            score: 8,
            at: now.addingTimeInterval(-2 * 3600)
        ))
        ledger.record(pulse(
            id: "stale",
            dimension: .wonder,
            score: 9,
            at: now.addingTimeInterval(-20 * 3600)
        ))
        ledger.record(pulse(
            id: "capacity",
            dimension: .capacity,
            score: 2,
            at: now.addingTimeInterval(-3 * 3600)
        ))

        let state = ledger.currentState(now: now)
        XCTAssertEqual(state.aliveness, 8)
        XCTAssertNil(state.wonder)
        XCTAssertEqual(state.capacity, 2)
        XCTAssertEqual(state.composite, 8)
    }

    func testAboutYouOffersAtMostOnePulsePerDayAndDoesNotDescribeItAsProfile() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: BookDay.id(for: now.addingTimeInterval(-86_400)),
            date: now.addingTimeInterval(-86_400),
            pages: [
                BookPage(type: .souvenir, promptText: "One", userInput: "A bright red leaf."),
                BookPage(type: .diary, promptText: "Two", userInput: "Rain on the fire escape.")
            ]
        )]

        let pages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let offered = try XCTUnwrap(pages.first {
            $0.payload.metadata["readerStatePulse"] == "true"
        })
        XCTAssertEqual(offered.type, .aboutYou)
        XCTAssertTrue(offered.payload.metadata["privacy"]?.contains("not a permanent profile fact") == true)
        XCTAssertFalse(offered.payload.metadata["pulseScores"]?.isEmpty ?? true)

        let dimension = try XCTUnwrap(offered.payload.metadata["pulseDimension"])
        var answered = inputs
        var ledger = ReaderStatePulseLedger.empty
        ledger.record(pulse(
            id: "answered",
            dimension: ReaderStatePulseDimension(rawValue: dimension) ?? .aliveness,
            score: 6,
            at: now,
            dayID: day.id
        ))
        answered.readerStatePulses = ledger
        let afterAnswer = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: answered,
            now: now
        )
        XCTAssertFalse(afterAnswer.contains {
            $0.payload.metadata["readerStatePulse"] == "true"
        })
    }

    func testDelayedPulseNamesTheExactSessionAndCausalReceipts() throws {
        let earlier = now.addingTimeInterval(-24 * 3600)
        let priorPage = BookPage(
            id: "kept-door",
            type: .wonderCompass,
            createdAt: earlier,
            promptText: "Notice one living thing.",
            userInput: "A crow rearranged the morning.",
            tags: [
                "book-session-id:session-1",
                "book-session:freshSight",
                "book-session-role:door",
                "causal-experiment:page-opportunity",
                "causal-movement-experiment:movement-opportunity"
            ],
            sourceID: "wonder-compass"
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: BookDay.id(for: earlier),
            date: earlier,
            pages: [
                priorPage,
                BookPage(type: .souvenir, createdAt: earlier, promptText: "Keep", userInput: "A second keep.")
            ]
        )]

        let pages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let pulsePage = try XCTUnwrap(pages.first {
            $0.payload.metadata["pulseDimension"] == ReaderStatePulseDimension.delayedOutcome.rawValue
        })
        XCTAssertEqual(pulsePage.payload.metadata["pulseTargetSessionID"], "session-1")
        XCTAssertEqual(pulsePage.payload.metadata["pulseTargetPageID"], "kept-door")
        XCTAssertEqual(pulsePage.payload.metadata["pulseTargetCausalOpportunityID"], "page-opportunity")
        XCTAssertEqual(pulsePage.payload.metadata["pulseTargetCausalMovementOpportunityID"], "movement-opportunity")
    }

    func testLongReadingTriangulatesAcrossDaysAndRequiresLivedProof() {
        var pulses = ReaderStatePulseLedger.empty
        for offset in 0..<14 {
            let day = now.addingTimeInterval(TimeInterval(offset - 13) * 86_400)
            let score = offset < 7 ? 2 : 8
            let dimension: ReaderStatePulseDimension = offset == 8 || offset == 12
                ? .delayedOutcome
                : .wonder
            pulses.record(pulse(
                id: "pulse-\(offset)",
                dimension: dimension,
                score: score,
                at: day
            ))
        }

        let reading = ReaderReenchantmentMeasure.reading(
            pulses: pulses,
            aliveness: .unwritten,
            longGame: nil,
            learning: ReaderLearningModel(),
            days: [],
            now: now
        )
        XCTAssertEqual(reading.direction, .brightening)
        XCTAssertGreaterThanOrEqual(reading.distinctMeasuredDays, 14)
        XCTAssertEqual(reading.livedProofCount, 2)
        XCTAssertEqual(reading.evidenceStreamCount, 2)
        XCTAssertGreaterThan(reading.sevenDayAverage ?? 0, reading.previousSevenDayAverage ?? 10)
    }

    func testEngagementAloneCannotDeclareAChangedLife() {
        var learning = ReaderLearningModel()
        for offset in 0..<20 {
            learning.record(ReaderLearningEvent(
                dayID: "day-\(offset)",
                occurredAt: now.addingTimeInterval(TimeInterval(-offset) * 3600),
                action: offset.isMultiple(of: 2) ? .opened : .acted,
                surfaceID: "surface-\(offset)",
                sourceID: "test",
                type: .wonderCompass,
                varietyKey: "test",
                hour: 12
            ))
        }
        let reading = ReaderReenchantmentMeasure.reading(
            pulses: .empty,
            aliveness: .unwritten,
            longGame: nil,
            learning: learning,
            days: [],
            now: now
        )

        XCTAssertEqual(reading.direction, .notEnoughEvidence)
        XCTAssertEqual(reading.livedProofCount, 0)
        XCTAssertEqual(reading.supportingSignalCount, 10)
    }

    func testLowCapacityFavorsSmallDoorsAndEasesHeavyPages() {
        let state = ReaderCurrentState(
            aliveness: 3,
            wonder: 2,
            hiddenMagic: nil,
            capacity: 2,
            freshestAnswerAt: now
        )
        let compass = surface(id: "compass", type: .wonderCompass)
        let research = surface(id: "research", type: .facultyResearch)

        XCTAssertGreaterThan(
            CuratorReaderStateAffinity.boost(for: compass, state: state, reading: .unwritten),
            CuratorReaderStateAffinity.boost(for: research, state: state, reading: .unwritten)
        )
    }

    private func pulse(
        id: String,
        dimension: ReaderStatePulseDimension,
        score: Int,
        at date: Date,
        dayID: String? = nil
    ) -> ReaderStatePulseRecord {
        ReaderStatePulseRecord(
            id: id,
            dimension: dimension,
            score: score,
            answerCode: "test",
            answerLine: "Test answer",
            note: nil,
            askedAt: date,
            answeredAt: date,
            dayID: dayID ?? BookDay.id(for: date),
            context: nil,
            facets: ["time:afternoon"],
            target: dimension == .delayedOutcome
                ? ReaderStatePulseTarget(
                    sessionID: "session-\(id)",
                    movement: .freshSight,
                    role: .door,
                    sourceID: "wonder-compass",
                    pageID: "page-\(id)",
                    causalOpportunityID: nil,
                    causalMovementOpportunityID: nil,
                    happenedAt: date.addingTimeInterval(-12 * 3600)
                )
                : nil
        )
    }

    private func surface(id: String, type: BookPageType) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 50,
            reason: "test",
            prompt: "test",
            detail: "test",
            payload: BookPagePayload(headline: "test", body: "test")
        )
    }
}
