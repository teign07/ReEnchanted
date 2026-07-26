import XCTest
@testable import InsideCoverCore

final class BookWorkingsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func openLedger(appetite: BookWorkingAppetite = .alive) -> BookWorkingLedger {
        BookWorkingLedger(authority: BookWorkingAuthority(
            isEnabled: true,
            appetite: appetite,
            allowsCalendarOpenings: true,
            allowsNotificationSummons: true,
            earliestHour: 17,
            latestHour: 22,
            grantedAt: date(2026, 7, 1),
            pausedUntil: nil
        ))
    }

    private func working(
        id: String,
        createdAt: Date,
        startsAt: Date,
        status: BookWorkingStatus = .arranged
    ) -> BookWorking {
        BookWorking(
            id: id,
            recipeID: "test",
            initiatorKind: .book,
            initiatorID: "the-book",
            initiatorName: "The Book",
            title: "A Test Opening",
            summons: "The Book moved.",
            invitation: "Notice one thing.",
            returnPrompt: "What happened?",
            createdAt: createdAt,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(40 * 60),
            status: status,
            effects: [
                BookWorkingEffect(
                    id: "\(id)-calendar",
                    kind: .calendarOpening,
                    status: .executed,
                    attemptedAt: createdAt,
                    detail: "written"
                )
            ]
        )
    }

    func testSealedPactCannotPrepareAWorking() {
        let now = date(2026, 7, 20, 10)
        let plan = BookWorkingEngine.reconcile(
            ledger: .empty,
            context: BookWorkingContext(now: now, calendarEvents: [], distressActive: false),
            calendar: calendar
        )
        XCTAssertNil(plan.newlyPrepared)
        XCTAssertNil(plan.ledger.current)
    }

    func testAlivePactPreparesAnAttributableWorkingInsideBoundedHours() throws {
        let now = date(2026, 7, 20, 10)
        let plan = BookWorkingEngine.reconcile(
            ledger: openLedger(),
            context: BookWorkingContext(now: now, calendarEvents: [], distressActive: false),
            calendar: calendar
        )
        let working = try XCTUnwrap(plan.newlyPrepared)
        let startHour = calendar.component(.hour, from: working.startsAt)
        XCTAssertGreaterThanOrEqual(startHour, 17)
        XCTAssertLessThan(startHour, 22)
        XCTAssertGreaterThanOrEqual(working.startsAt.timeIntervalSince(now), 3 * 3_600)
        XCTAssertFalse(working.initiatorName.isEmpty)
        XCTAssertEqual(Set(working.effects.map(\.kind)), Set(BookWorkingEffectKind.allCases))
    }

    func testPlannerAvoidsOccupiedCalendarTimeWithABuffer() throws {
        let now = date(2026, 7, 20, 10)
        let occupied = CalendarEventSignal(
            id: "busy-evening",
            title: "Private event",
            startsAt: date(2026, 7, 20, 16),
            endsAt: date(2026, 7, 20, 23),
            isAllDay: false
        )
        let working = try XCTUnwrap(BookWorkingEngine.reconcile(
            ledger: openLedger(),
            context: BookWorkingContext(now: now, calendarEvents: [occupied], distressActive: false),
            calendar: calendar
        ).newlyPrepared)
        XCTAssertFalse(calendar.isDate(working.startsAt, inSameDayAs: now))
        XCTAssertGreaterThanOrEqual(working.startsAt, occupied.endsAt!)
    }

    func testDistressAndRollingWeekLimitBothProduceSilence() {
        let now = date(2026, 7, 20, 10)
        XCTAssertNil(BookWorkingEngine.reconcile(
            ledger: openLedger(),
            context: BookWorkingContext(now: now, calendarEvents: [], distressActive: true),
            calendar: calendar
        ).newlyPrepared)

        var capped = openLedger()
        capped.history = (0..<3).map { offset in
            let hoursAgo = Double((offset + 2) * 40)
            let createdAt = now.addingTimeInterval(-hoursAgo * 3_600)
            return working(
                id: "recent-\(offset)",
                createdAt: createdAt,
                startsAt: createdAt.addingTimeInterval(4 * 3_600),
                status: .elapsed
            )
        }
        XCTAssertNil(BookWorkingEngine.reconcile(
            ledger: capped,
            context: BookWorkingContext(now: now, calendarEvents: [], distressActive: false),
            calendar: calendar
        ).newlyPrepared)
    }

    func testMinimumGapPreventsBurstingEvenBelowWeeklyLimit() {
        let now = date(2026, 7, 20, 10)
        var ledger = openLedger()
        ledger.history = [working(
            id: "yesterday",
            createdAt: now.addingTimeInterval(-24 * 3_600),
            startsAt: now.addingTimeInterval(-20 * 3_600),
            status: .elapsed
        )]
        XCTAssertNil(BookWorkingEngine.reconcile(
            ledger: ledger,
            context: BookWorkingContext(now: now, calendarEvents: [], distressActive: false),
            calendar: calendar
        ).newlyPrepared)
    }

    func testRevocationCancelsTheCurrentCausalChain() throws {
        let now = date(2026, 7, 20, 10)
        var ledger = openLedger()
        ledger.current = working(
            id: "current",
            createdAt: now,
            startsAt: date(2026, 7, 20, 18)
        )
        let cancelled = try XCTUnwrap(ledger.cancelCurrent(at: now.addingTimeInterval(60)))
        XCTAssertNil(ledger.current)
        XCTAssertEqual(cancelled.status, .cancelled)
        XCTAssertTrue(cancelled.effects.allSatisfy { $0.status == .cancelled })
        XCTAssertEqual(ledger.history.last?.id, "current")
    }

    func testElapsedWorkingReturnsAsTypedLivedEvidence() throws {
        let now = date(2026, 7, 21, 10)
        var ledger = openLedger()
        ledger.history = [working(
            id: "returned-working",
            createdAt: date(2026, 7, 20, 10),
            startsAt: date(2026, 7, 20, 18),
            status: .elapsed
        )]
        var inputs = BookSourceInputs()
        inputs.bookWorkings = ledger
        let surface = try XCTUnwrap(BookWorkingReturnPageSourceAdapter().candidates(
            for: BookDay(id: "2026-07-21", date: now, pages: []),
            context: CuratorContext.make(for: BookDay(id: "2026-07-21", date: now, pages: [])),
            inputs: inputs,
            now: now
        ).first)
        XCTAssertEqual(surface.payload.metadata["bookWorkingID"], "returned-working")
        let receipt = try XCTUnwrap(LivedQuestReceipt.from(
            surface: surface,
            readerInput: "A red kite over the pharmacy roof.",
            mediaAssets: [],
            completedAt: now
        ))
        XCTAssertEqual(receipt.kind, .bookWorking)
        XCTAssertEqual(receipt.questID, "returned-working")
        XCTAssertTrue(receipt.hasWrittenProof)
    }
}
