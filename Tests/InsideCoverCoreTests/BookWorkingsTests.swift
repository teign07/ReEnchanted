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
        status: BookWorkingStatus = .arranged,
        grounding: BookWorkingGrounding? = nil
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
            ],
            grounding: grounding
        )
    }

    private func keptLine(_ index: Int, day: Int) -> BookPage {
        BookPage(
            id: "kept-\(index)",
            type: .souvenir,
            createdAt: date(2026, 7, day, 10 + (index % 6)),
            promptText: "Keep one exact detail.",
            userInput: "Exact ordinary detail number \(index) remained in the light.",
            tags: ["souvenir"]
        )
    }

    private func invitationCandidates(
        inputs: BookSourceInputs,
        now: Date? = nil,
        distress: Bool = false
    ) -> [SurfacePage] {
        let evaluationDate = now ?? date(2026, 7, 20, 10)
        let today = BookDay(
            id: BookDay.id(for: evaluationDate),
            date: evaluationDate,
            pages: []
        )
        var context = CuratorContext.make(for: today)
        if distress {
            context.distress = DistressSignals(isActive: true, reasons: ["test"])
        }
        return BookWorkingInvitationPageSourceAdapter().candidates(
            for: today,
            context: context,
            inputs: inputs,
            now: evaluationDate
        )
    }

    private func matureInvitationInputs() -> BookSourceInputs {
        let pages = (1...12).map { keptLine($0, day: (($0 - 1) / 4) + 1) }
        var inputs = BookSourceInputs.empty
        inputs.days = Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { id, pages in
                BookDay(id: id, date: pages[0].createdAt, pages: pages)
            }
        return inputs
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
        let wickerBusiness = try XCTUnwrap(
            CastUndertakingEngine.seeded(existing: [], now: now)
                .first(where: { $0.actorID == "wicker-eddies" })
        )
        let plan = BookWorkingEngine.reconcile(
            ledger: openLedger(),
            context: BookWorkingContext(
                now: now,
                calendarEvents: [],
                distressActive: false,
                activeUndertakings: [wickerBusiness]
            ),
            calendar: calendar
        )
        let working = try XCTUnwrap(plan.newlyPrepared)
        let startHour = calendar.component(.hour, from: working.startsAt)
        XCTAssertGreaterThanOrEqual(startHour, 17)
        XCTAssertLessThan(startHour, 22)
        XCTAssertGreaterThanOrEqual(working.startsAt.timeIntervalSince(now), 3 * 3_600)
        XCTAssertFalse(working.initiatorName.isEmpty)
        XCTAssertEqual(working.initiatorKind, .book)
        XCTAssertEqual(working.initiatorName, "The Book")
        XCTAssertEqual(Set(working.effects.map(\.kind)), Set(BookWorkingEffectKind.allCases))
    }

    func testFirstBookWorkingIsShapedByASafeKeptPageWithoutQuotingItOutside() throws {
        let now = date(2026, 7, 20, 10)
        let sourceWords = "The kitchen window held a small square of gold after the rain."
        let sourcePage = BookPage(
            id: "ordinary-source",
            type: .souvenir,
            createdAt: date(2026, 7, 19, 20),
            promptText: "Keep one exact detail.",
            userInput: sourceWords,
            tags: ["souvenir"]
        )
        let working = try XCTUnwrap(BookWorkingEngine.reconcile(
            ledger: openLedger(),
            context: BookWorkingContext(
                now: now,
                calendarEvents: [],
                distressActive: false,
                groundingPages: [sourcePage]
            ),
            calendar: calendar
        ).newlyPrepared)

        XCTAssertEqual(working.grounding?.sourcePageID, sourcePage.id)
        XCTAssertEqual(working.grounding?.lens, .weatherAndLight)
        XCTAssertEqual(working.invitation, BookWorkingGroundingLens.weatherAndLight.outsideInvitation)
        XCTAssertFalse(working.title.contains(sourceWords))
        XCTAssertFalse(working.summons.contains(sourceWords))
        XCTAssertFalse(working.invitation.contains(sourceWords))
    }

    func testGroundingRejectsSensitiveGeneratedAndOpenWritingPages() {
        let body = BookPage(
            id: "body",
            type: .body,
            createdAt: date(2026, 7, 18),
            promptText: "Body",
            userInput: "A private bodily detail lives here."
        )
        let sensitive = BookPage(
            id: "sensitive",
            type: .souvenir,
            createdAt: date(2026, 7, 19),
            promptText: "Souvenir",
            userInput: "A locally sensitive ordinary detail lives here.",
            privacy: .localSensitive
        )
        let generated = BookPage(
            id: "generated",
            type: .souvenir,
            createdAt: date(2026, 7, 20),
            promptText: "Souvenir",
            userInput: "The Book generated these words itself.",
            origin: .generated
        )
        let openWriting = BookPage(
            id: "open-writing",
            type: .plainPage,
            createdAt: date(2026, 7, 21),
            promptText: "",
            userInput: "Anything at all might be written here."
        )

        XCTAssertNil(BookWorkingGrounding.select(from: [body, sensitive, generated, openWriting]))
    }

    func testGroundingMovesToAnotherPageAfterOneHasAlreadyBeenUsed() throws {
        let older = BookPage(
            id: "older",
            type: .souvenir,
            createdAt: date(2026, 7, 17),
            promptText: "Keep one detail.",
            userInput: "A brass key warmed in the sun."
        )
        let newer = BookPage(
            id: "newer",
            type: .location,
            createdAt: date(2026, 7, 18),
            promptText: "Mark one place.",
            userInput: "The garden gate opened onto rain."
        )

        XCTAssertEqual(
            BookWorkingGrounding.select(from: [older, newer])?.sourcePageID,
            newer.id
        )
        XCTAssertEqual(
            BookWorkingGrounding.select(from: [older, newer], excluding: [newer.id])?.sourcePageID,
            older.id
        )
    }

    func testInvitationWaitsForAnEarnedReadBackAndTheSecondWeek() {
        let pages = (1...6).map { keptLine($0, day: (($0 - 1) / 2) + 1) }
        var inputs = BookSourceInputs.empty
        inputs.days = Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { id, pages in
                BookDay(id: id, date: pages[0].createdAt, pages: pages)
            }

        XCTAssertTrue(invitationCandidates(inputs: inputs).isEmpty)

        let firstReading = BookPage(
            id: "kept-first-reading",
            type: .bookNotices,
            createdAt: date(2026, 7, 4, 20),
            promptText: "I Read Back",
            userInput: "",
            tags: ["first-reading", "book-notices"]
        )
        inputs.days.append(BookDay(
            id: BookDay.id(for: firstReading.createdAt),
            date: firstReading.createdAt,
            pages: [firstReading]
        ))
        XCTAssertTrue(
            invitationCandidates(inputs: inputs, now: date(2026, 7, 7, 10)).isEmpty,
            "The Book must not ask for standing authority during its first week."
        )

        let invitation = invitationCandidates(inputs: inputs, now: date(2026, 7, 8, 10))
        XCTAssertEqual(invitation.first?.payload.metadata["bookWorkingInvitation"], "true")
        XCTAssertEqual(invitation.first?.payload.metadata["milestone"], "true")
        XCTAssertEqual(invitation.first?.payload.metadata["automaticRepeatRestDays"], "30")
        XCTAssertEqual(invitation.first?.payload.headline, "I Want Hands")
        XCTAssertTrue(invitation.first?.payload.body.contains("bite my own margins") == true)
    }

    func testMatureButNewArchiveStillWaitsForTheSecondWeek() {
        XCTAssertTrue(
            invitationCandidates(
                inputs: matureInvitationInputs(),
                now: date(2026, 7, 7, 10)
            ).isEmpty
        )
    }

    func testMatureArchiveCanReceiveInvitationWithoutHistoricalFirstReading() {
        XCTAssertEqual(invitationCandidates(inputs: matureInvitationInputs()).count, 1)
    }

    func testInvitationYieldsAfterPactOrDuringDistress() {
        var inputs = matureInvitationInputs()
        XCTAssertTrue(invitationCandidates(inputs: inputs, distress: true).isEmpty)

        inputs.bookWorkings = openLedger()
        XCTAssertTrue(invitationCandidates(inputs: inputs).isEmpty)
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
        let sourcePage = BookPage(
            id: "working-source",
            type: .souvenir,
            createdAt: date(2026, 7, 21, 9),
            promptText: "Keep one exact detail.",
            userInput: "A red kite crossed the pharmacy roof after rain.",
            tags: ["souvenir"]
        )
        var ledger = openLedger()
        ledger.history = [working(
            id: "returned-working",
            createdAt: date(2026, 7, 20, 10),
            startsAt: date(2026, 7, 20, 18),
            status: .elapsed,
            grounding: BookWorkingGrounding(
                sourcePageID: sourcePage.id,
                sourcePageType: sourcePage.type,
                lens: .weatherAndLight
            )
        )]
        var inputs = BookSourceInputs()
        inputs.bookWorkings = ledger
        let returnDay = BookDay(id: "2026-07-21", date: now, pages: [sourcePage])
        let surface = try XCTUnwrap(BookWorkingReturnPageSourceAdapter().candidates(
            for: returnDay,
            context: CuratorContext.make(for: returnDay),
            inputs: inputs,
            now: now
        ).first)
        XCTAssertEqual(surface.payload.metadata["bookWorkingID"], "returned-working")
        XCTAssertEqual(surface.payload.metadata["bookWorkingGroundingPageID"], sourcePage.id)
        XCTAssertTrue(surface.payload.body.contains(sourcePage.userInput))
        XCTAssertTrue(surface.detail.contains("not random"))

        inputs.days = []
        let withdrawnSurface = try XCTUnwrap(BookWorkingReturnPageSourceAdapter().candidates(
            for: BookDay(id: "2026-07-21", date: now, pages: []),
            context: CuratorContext.make(for: BookDay(id: "2026-07-21", date: now, pages: [])),
            inputs: inputs,
            now: now
        ).first)
        XCTAssertNil(withdrawnSurface.payload.metadata["bookWorkingGroundingPageID"])
        XCTAssertFalse(withdrawnSurface.payload.body.contains(sourcePage.userInput))

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
