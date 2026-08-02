import XCTest
@testable import InsideCoverCore

final class BookInterruptionBudgetTests: XCTestCase {
    private let day = "2026-07-23"
    private func candidate(
        _ id: String,
        _ window: BookInterruptionWindow,
        dayID: String? = nil,
        kind: BookInterruptionKind = .ordinary,
        specific: Bool = false,
        priority: Int = 0,
        expiresAt: Date? = nil
    ) -> BookInterruptionCandidate {
        BookInterruptionCandidate(
            id: id,
            dayID: dayID ?? day,
            window: window,
            kind: kind,
            isSpecific: specific,
            priority: priority,
            expiresAt: expiresAt
        )
    }
    func testCadenceAndOneSeatPerWindow() {
        let all = [candidate("m", .morning), candidate("m2", .morning), candidate("e", .evening)]
        XCTAssertEqual(BookInterruptionBudget.plan(candidates: all, cadence: .inside).winners.count, 0)
        XCTAssertEqual(BookInterruptionBudget.plan(candidates: all, cadence: .morning).winners.map(\.id), ["m"])
        XCTAssertEqual(BookInterruptionBudget.plan(candidates: all, cadence: .evening).winners.map(\.id), ["e"])
        XCTAssertEqual(BookInterruptionBudget.plan(candidates: all, cadence: .both).winners.count, 2)
    }
    func testSpecificContextReplacesGenericDeterministicallyAndConsumedSeatSuppresses() {
        let candidates = [candidate("ordinary", .morning), candidate("weather", .morning, specific: true)]
        XCTAssertEqual(BookInterruptionBudget.plan(candidates: candidates.reversed(), cadence: .morning).winners.map(\.id), ["weather"])
        XCTAssertTrue(BookInterruptionBudget.plan(candidates: candidates, cadence: .morning, consumed: ["\(day)|morning"]).winners.isEmpty)
    }

    func testAttentionSampleSurvivesInsideOnlyCadenceAndUsesExistingSeat() {
        let candidates = [
            candidate("ordinary", .morning),
            candidate(
                "attention",
                .morning,
                kind: .attention,
                specific: true,
                priority: 150
            )
        ]

        XCTAssertEqual(
            BookInterruptionBudget.plan(
                candidates: candidates,
                cadence: .inside
            ).winners.map(\.id),
            ["attention"]
        )
        XCTAssertEqual(
            BookInterruptionBudget.plan(
                candidates: candidates,
                cadence: .morning
            ).winners.map(\.id),
            ["attention"],
            "the sample replaces the ordinary whisper instead of stacking"
        )
    }

    func testConsumedSeatDoesNotLeakAcrossDayRollover() {
        let tomorrow = "2026-07-24"
        let candidates = [
            candidate("today", .morning),
            candidate("tomorrow", .morning, dayID: tomorrow)
        ]
        XCTAssertEqual(
            BookInterruptionBudget.plan(
                candidates: candidates,
                cadence: .morning,
                consumed: ["\(day)|morning"]
            ).winners.map(\.id),
            ["tomorrow"]
        )
    }

    func testDueFavorReplacesRatherThanStacksWithEveningReturn() {
        let candidates = [
            candidate("braid", .evening, kind: .braid),
            candidate("favor", .evening, kind: .favor, specific: true, priority: 100)
        ]
        let winners = BookInterruptionBudget.plan(candidates: candidates, cadence: .evening).winners
        XCTAssertEqual(winners.map(\.id), ["favor"])
        XCTAssertEqual(winners.map(\.kind), [.favor])
    }

    func testNearerSpecificHingeWinsBeforeIdentifierTieBreak() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let candidates = [
            candidate("alphabetically-first", .morning, specific: true, priority: 10, expiresAt: now.addingTimeInterval(7_200)),
            candidate("nearer", .morning, specific: true, priority: 10, expiresAt: now.addingTimeInterval(900))
        ]
        XCTAssertEqual(
            BookInterruptionBudget.plan(candidates: candidates, cadence: .morning).winners.map(\.id),
            ["nearer"]
        )
    }

    func testExternalAnchorDoorbellsAreDeliberatelyDisabled() {
        XCTAssertFalse(BookInterruptionBudget.externalAnchorNotificationsEnabled)
    }

    func testDelayedOutcomeUsesTheExistingSeatAndReplacesOnlyGenericCopy() {
        let candidates = [
            candidate("evening-copy", .evening, kind: .braid),
            candidate("outcome", .evening, kind: .outcome, specific: true, priority: 95)
        ]
        XCTAssertEqual(
            BookInterruptionBudget.plan(candidates: candidates, cadence: .evening).winners.map(\.id),
            ["outcome"]
        )
    }

    func testDelayedOutcomeDoesNotDisplaceAHigherPrioritySpecificHinge() {
        let candidates = [
            candidate("festival", .evening, kind: .festival, specific: true, priority: 120),
            candidate("outcome", .evening, kind: .outcome, specific: true, priority: 95)
        ]
        XCTAssertEqual(
            BookInterruptionBudget.plan(candidates: candidates, cadence: .evening).winners.map(\.id),
            ["festival"]
        )
    }

    func testWorkingTakesAGenericSeatButYieldsToAnotherContextualHinge() {
        let genericAndWorking = [
            candidate("braid", .evening, kind: .braid),
            candidate("working", .evening, kind: .working, specific: true, priority: 65)
        ]
        XCTAssertEqual(
            BookInterruptionBudget.plan(candidates: genericAndWorking, cadence: .evening).winners.map(\.id),
            ["working"]
        )

        let festivalAndWorking = [
            candidate("festival", .evening, kind: .festival, specific: true, priority: 120),
            candidate("working", .evening, kind: .working, specific: true, priority: 65)
        ]
        XCTAssertEqual(
            BookInterruptionBudget.plan(candidates: festivalAndWorking, cadence: .evening).winners.map(\.id),
            ["festival"]
        )
    }
}
