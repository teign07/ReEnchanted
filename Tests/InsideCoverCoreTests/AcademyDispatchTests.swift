import XCTest
@testable import InsideCoverCore

/// Irregular because the world is, not because a randomiser says so.
///
/// The distinction these lock down is the difference between the Academy having
/// a voice and the Academy being a slot machine: no blanks, no near-misses,
/// nothing lost by not looking, and no way to reroll by reopening the app.
final class AcademyDispatchTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func hours(_ count: Double) -> Date { start.addingTimeInterval(count * 3600) }

    private func advancedUndertakings() -> [CastUndertaking] {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for index in undertakings.indices { undertakings[index].stageIndex = 2 }
        return undertakings
    }

    private func maturePlaces() -> [String: PlaceState] {
        var places: [String: PlaceState] = [:]
        for index in 0..<PlaceState.reputationThreshold {
            places = PlaceMemoryEngine.recording(
                places,
                incident: PlaceIncident(id: "i-\(index)", line: "An argument.",
                                        participantIDs: ["penny-blackletter"], tags: ["argument"],
                                        occurredAt: start),
                placeID: "location-great-hall"
            )
        }
        return places
    }

    // MARK: - Never a blank pull

    func testAnIdleAcademySaysNothingAtAll() {
        for hour in 0..<200 {
            let dispatch = AcademyDispatchDesk.next(
                undertakings: [], questions: [], places: [:], pressures: [],
                alreadySaidIDs: [], lastSpokeAt: nil, now: hours(Double(hour))
            )
            XCTAssertNil(dispatch, "There is no such thing as an empty dispatch")
        }
    }

    func testEveryDispatchCarriesRealContent() {
        var said = Set<String>()
        var last: Date?
        for hour in stride(from: 0, to: 2000, by: 1) {
            let now = hours(Double(hour))
            guard let dispatch = AcademyDispatchDesk.next(
                undertakings: advancedUndertakings(), questions: [], places: maturePlaces(),
                pressures: [], alreadySaidIDs: said, lastSpokeAt: last, now: now
            ) else { continue }
            XCTAssertFalse(dispatch.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertGreaterThan(dispatch.line.count, 20, "A remark should actually say something")
            said.insert(dispatch.id)
            last = now
        }
        XCTAssertFalse(said.isEmpty, "With real business, it should sometimes speak")
    }

    func testNothingEverReportsThatThereWasNothingToReport() {
        let all = AcademyDispatchDesk.candidates(
            undertakings: advancedUndertakings(), questions: [],
            places: maturePlaces(), pressures: [], now: start
        )
        for dispatch in all {
            let text = dispatch.line.lowercased()
            for blank in ["nothing happened", "no news", "quiet day", "check back", "nothing to report"] {
                XCTAssertFalse(text.contains(blank), "A blank is a near-miss: '\(blank)'")
            }
        }
    }

    // MARK: - Not a lever

    func testReopeningCannotRerollForABetterLine() {
        let undertakings = advancedUndertakings()
        let a = AcademyDispatchDesk.next(
            undertakings: undertakings, questions: [], places: maturePlaces(), pressures: [],
            alreadySaidIDs: [], lastSpokeAt: nil, now: start.addingTimeInterval(60)
        )
        let b = AcademyDispatchDesk.next(
            undertakings: undertakings, questions: [], places: maturePlaces(), pressures: [],
            alreadySaidIDs: [], lastSpokeAt: nil, now: start.addingTimeInterval(900)
        )
        XCTAssertEqual(a, b, "Within the same hour the answer must not change")
    }

    func testItNeverBecomesADripFeed() {
        var said = Set<String>()
        var last: Date?
        var spoke = 0
        for hour in 0..<48 {
            let now = hours(Double(hour))
            guard let dispatch = AcademyDispatchDesk.next(
                undertakings: advancedUndertakings(), questions: [], places: maturePlaces(),
                pressures: [], alreadySaidIDs: said, lastSpokeAt: last, now: now
            ) else { continue }
            said.insert(dispatch.id)
            last = now
            spoke += 1
        }
        XCTAssertLessThanOrEqual(spoke, Int(48 / AcademyDispatchDesk.minimumHoursBetween) + 1)
    }

    func testACooldownIsRespected() {
        XCTAssertNil(AcademyDispatchDesk.next(
            undertakings: advancedUndertakings(), questions: [], places: maturePlaces(),
            pressures: [], alreadySaidIDs: [], lastSpokeAt: start, now: start.addingTimeInterval(600)
        ))
    }

    func testTheSameRemarkIsNeverMadeTwice() {
        let undertakings = advancedUndertakings()
        var said = Set<String>()
        var last: Date?
        for hour in stride(from: 0, to: 1000, by: 1) {
            let now = hours(Double(hour))
            guard let dispatch = AcademyDispatchDesk.next(
                undertakings: undertakings, questions: [], places: maturePlaces(),
                pressures: [], alreadySaidIDs: said, lastSpokeAt: last, now: now
            ) else { continue }
            XCTAssertFalse(said.contains(dispatch.id))
            said.insert(dispatch.id)
            last = now
        }
    }

    // MARK: - Irregular, but from contingency

    func testItOftenHoldsBackEvenWithSomethingToSay() {
        // The withheld item is not lost — it stays eligible — so silence costs
        // the reader nothing. This is what keeps it from being a reward.
        var silentHours = 0
        for hour in stride(from: 0, to: 400, by: 6) {
            if AcademyDispatchDesk.next(
                undertakings: advancedUndertakings(), questions: [], places: maturePlaces(),
                pressures: [], alreadySaidIDs: [], lastSpokeAt: nil, now: hours(Double(hour))
            ) == nil {
                silentHours += 1
            }
        }
        XCTAssertGreaterThan(silentHours, 0, "It should not fire every single time it could")
    }

    func testWhichRemarkVariesRatherThanFollowingAFixedOrder() {
        var seen = Set<String>()
        for hour in stride(from: 0, to: 800, by: 6) {
            if let dispatch = AcademyDispatchDesk.next(
                undertakings: advancedUndertakings(), questions: [], places: maturePlaces(),
                pressures: [], alreadySaidIDs: [], lastSpokeAt: nil, now: hours(Double(hour))
            ) {
                seen.insert(dispatch.id)
            }
        }
        XCTAssertGreaterThan(seen.count, 1, "The voice should not become predictable")
    }

    // MARK: - Ranking

    func testTheBookBeingWrongOutranksOrdinaryGossip() {
        guard var question = ContestedQuestionEngine.opening(
            movements: [], undertakings: CastUndertakingEngine.seeded(existing: [], now: start),
            places: maturePlaces(), entities: NarrativePackRegistry.entities,
            existing: [], now: start
        ) else { return XCTFail("Expected a question") }
        question = ContestedQuestionEngine.complicating(question, withTrace: "A scorch mark.", now: start)

        let all = AcademyDispatchDesk.candidates(
            undertakings: advancedUndertakings(), questions: [question],
            places: maturePlaces(), pressures: [], now: start
        )
        XCTAssertTrue(all.contains { $0.kind == .embarrassment })

        var last: Date?
        var found: AcademyDispatch?
        for hour in stride(from: 0, to: 200, by: 1) {
            if let dispatch = AcademyDispatchDesk.next(
                undertakings: advancedUndertakings(), questions: [question],
                places: maturePlaces(), pressures: [], alreadySaidIDs: [],
                lastSpokeAt: last, now: hours(Double(hour))
            ) { found = dispatch; break }
            last = nil
        }
        XCTAssertEqual(found?.kind, .embarrassment,
                       "The Book being wrong in public is the most interesting thing available")
    }

    func testAnArgumentIsReportedWithoutBeingSettled() {
        guard let question = ContestedQuestionEngine.opening(
            movements: [], undertakings: CastUndertakingEngine.seeded(existing: [], now: start),
            places: maturePlaces(), entities: NarrativePackRegistry.entities,
            existing: [], now: start
        ) else { return XCTFail("Expected a question") }

        let all = AcademyDispatchDesk.candidates(
            undertakings: [], questions: [question], places: [:], pressures: [], now: start
        )
        guard let argument = all.first(where: { $0.kind == .argument }) else {
            return XCTFail("Expected an argument dispatch")
        }
        let text = argument.line.lowercased()
        XCTAssertTrue(text.contains("not agree") || text.contains("nobody has settled"))
        for verdict in ["was right", "the answer is", "turns out", "we now know"] {
            XCTAssertFalse(text.contains(verdict))
        }
    }

    func testCollateralComplaintsCanSurface() {
        let pressures = WorldPressureEngine.minting(
            into: [],
            relationshipField: ["penny-blackletter|wicker-eddies": {
                var tie = RelationshipTie(); tie.add(tension: 20); return tie
            }()],
            advancedUndertaking: nil, castName: { $0 }, now: start
        )
        let all = AcademyDispatchDesk.candidates(
            undertakings: [], questions: [], places: [:], pressures: pressures, now: start
        )
        XCTAssertTrue(all.contains { $0.kind == .collateral })
    }

    func testCandidateIDsAreUnique() {
        let all = AcademyDispatchDesk.candidates(
            undertakings: advancedUndertakings(), questions: [],
            places: maturePlaces(), pressures: [], now: start
        )
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
    }
}
