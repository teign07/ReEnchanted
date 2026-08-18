import XCTest
@testable import InsideCoverCore

final class BraidRecoveryStateTests: XCTestCase {
    func testFailureWithCapturedFragmentsEnablesRetryAndRecordsError() {
        var recovery = BraidRecoveryState()

        recovery.recordFailure("model unavailable", day: dayWithCapturedFragments())

        XCTAssertTrue(recovery.canRetry)
        XCTAssertEqual(recovery.retryActionTitle, "Try again")
        XCTAssertEqual(recovery.lastError, "model unavailable")
    }

    func testFailureWithoutCapturedFragmentsDoesNotEnableRetry() {
        var recovery = BraidRecoveryState()

        recovery.recordFailure("model unavailable", day: BookDay(id: "empty-day", date: Date(), pages: []))

        XCTAssertFalse(recovery.canRetry)
        XCTAssertNil(recovery.retryActionTitle)
        XCTAssertNil(recovery.lastError)
    }

    func testFailureAfterBookOfYouAlreadyExistsDoesNotEnableRetry() {
        var recovery = BraidRecoveryState()
        var day = dayWithCapturedFragments()
        day.pages.append(bookOfYouPage())

        recovery.recordFailure("model unavailable", day: day)

        XCTAssertFalse(recovery.canRetry)
        XCTAssertNil(recovery.retryActionTitle)
        XCTAssertNil(recovery.lastError)
    }

    func testBeginAttemptClearsRetryButKeepsLastErrorVisible() {
        var recovery = BraidRecoveryState()
        recovery.recordFailure("model unavailable", day: dayWithCapturedFragments())

        recovery.beginAttempt()

        XCTAssertFalse(recovery.canRetry)
        XCTAssertNil(recovery.retryActionTitle)
        XCTAssertEqual(recovery.lastError, "model unavailable")
    }

    func testSuccessClearsRetryAndError() {
        var recovery = BraidRecoveryState()
        recovery.recordFailure("model unavailable", day: dayWithCapturedFragments())

        recovery.recordSuccess()

        XCTAssertFalse(recovery.canRetry)
        XCTAssertNil(recovery.retryActionTitle)
        XCTAssertNil(recovery.lastError)
    }

    func testDayByMarkingCapturedPagesUsedMarksOnlyCapturedPagesAndAppendsBraid() throws {
        let dayDate = date("2026-06-06T12:00:00Z")
        let originalDay = BookDay(
            id: "2026-06-06",
            date: dayDate,
            pages: [
                page(id: "souvenir", type: .souvenir, createdAt: dayDate, usedInBookOfYou: false),
                page(id: "already-braided", type: .mood, createdAt: dayDate, usedInBookOfYou: true),
                bookOfYouPage()
            ]
        )
        let braid = bookOfYouPage(id: "fresh-braid")

        let updatedDay = BraidRecoveryState.dayByMarkingCapturedPagesUsed(originalDay, braid: braid)

        XCTAssertEqual(updatedDay.pages.count, 4)
        XCTAssertTrue(try XCTUnwrap(updatedDay.pages.first { $0.id == "souvenir" }).usedInBookOfYou)
        XCTAssertTrue(try XCTUnwrap(updatedDay.pages.first { $0.id == "already-braided" }).usedInBookOfYou)
        XCTAssertFalse(try XCTUnwrap(updatedDay.pages.first { $0.id == "book-of-you" }).usedInBookOfYou)
        XCTAssertEqual(updatedDay.pages.last?.id, "fresh-braid")
    }

    func testCapturedPagesIgnorePagesFromOtherCalendarDays() throws {
        let dayDate = date("2026-06-06T12:00:00Z")
        let previousDate = date("2026-06-05T23:00:00Z")
        let originalDay = BookDay(
            id: "2026-06-06",
            date: dayDate,
            pages: [
                page(id: "yesterday", type: .souvenir, createdAt: previousDate, usedInBookOfYou: false),
                page(id: "today", type: .mood, createdAt: dayDate, usedInBookOfYou: false)
            ]
        )

        XCTAssertEqual(originalDay.capturedPages.map(\.id), ["today"])

        let updatedDay = BraidRecoveryState.dayByMarkingCapturedPagesUsed(originalDay, braid: bookOfYouPage(id: "fresh-braid"))

        XCTAssertFalse(try XCTUnwrap(updatedDay.pages.first { $0.id == "yesterday" }).usedInBookOfYou)
        XCTAssertTrue(try XCTUnwrap(updatedDay.pages.first { $0.id == "today" }).usedInBookOfYou)
    }

    func testNightlyWindowStartsAfterTheLastBraidInsteadOfAtMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previousDay = BookDay(
            id: "2026-06-05",
            date: date("2026-06-05T00:00:00Z"),
            pages: [
                page(id: "before-braid", type: .diary, createdAt: date("2026-06-05T20:00:00Z"), usedInBookOfYou: true),
                page(id: "last-braid", type: .bookOfYou, createdAt: date("2026-06-05T21:30:00Z"), usedInBookOfYou: false),
                page(id: "after-braid", type: .souvenir, createdAt: date("2026-06-05T22:15:00Z"), usedInBookOfYou: false)
            ]
        )
        let today = BookDay(
            id: "2026-06-06",
            date: date("2026-06-06T00:00:00Z"),
            pages: [
                page(id: "this-morning", type: .mood, createdAt: date("2026-06-06T08:00:00Z"), usedInBookOfYou: false)
            ]
        )

        let pending = NightlyBraidWindow.pendingPages(
            for: today,
            previousDays: [previousDay],
            now: date("2026-06-06T21:30:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(pending.map(\.id), ["after-braid", "this-morning"])
    }

    func testNightlyReadingDayPreservesRealDatesAcrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let latePage = page(
            id: "late-page",
            type: .souvenir,
            createdAt: date("2026-06-05T23:10:00Z"),
            usedInBookOfYou: false
        )
        let previousDay = BookDay(
            id: "2026-06-05",
            date: date("2026-06-05T00:00:00Z"),
            pages: [
                page(id: "last-braid", type: .bookOfYou, createdAt: date("2026-06-05T21:30:00Z"), usedInBookOfYou: false),
                latePage
            ]
        )
        let today = BookDay(id: "2026-06-06", date: date("2026-06-06T00:00:00Z"), pages: [])

        let readingDay = NightlyBraidWindow.readingDay(
            for: today,
            previousDays: [previousDay],
            now: date("2026-06-06T21:30:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(readingDay.capturedPages.map(\.id), [latePage.id])
        XCTAssertEqual(readingDay.capturedPages.first?.createdAt, latePage.createdAt)
    }

    func testFirstBraidStillBeginsAtTheCurrentDaysStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previousDay = BookDay(
            id: "2026-06-05",
            date: date("2026-06-05T00:00:00Z"),
            pages: [page(id: "old-unbraided", type: .diary, createdAt: date("2026-06-05T22:00:00Z"), usedInBookOfYou: false)]
        )
        let today = BookDay(
            id: "2026-06-06",
            date: date("2026-06-06T00:00:00Z"),
            pages: [page(id: "first-day-page", type: .mood, createdAt: date("2026-06-06T08:00:00Z"), usedInBookOfYou: false)]
        )

        let pending = NightlyBraidWindow.pendingPages(
            for: today,
            previousDays: [previousDay],
            now: date("2026-06-06T21:30:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(pending.map(\.id), ["first-day-page"])
    }

    func testCrossMidnightBraidMarksPagesUsedInTheirActualDays() throws {
        let previousDay = BookDay(
            id: "2026-06-05",
            date: date("2026-06-05T00:00:00Z"),
            pages: [page(id: "late-page", type: .souvenir, createdAt: date("2026-06-05T23:10:00Z"), usedInBookOfYou: false)]
        )
        let today = BookDay(
            id: "2026-06-06",
            date: date("2026-06-06T00:00:00Z"),
            pages: [page(id: "morning-page", type: .mood, createdAt: date("2026-06-06T08:00:00Z"), usedInBookOfYou: false)]
        )

        let updated = BraidRecoveryState.daysByMarkingPagesUsed(
            [previousDay, today],
            pageIDs: ["late-page", "morning-page"]
        )

        XCTAssertTrue(try XCTUnwrap(updated[0].pages.first).usedInBookOfYou)
        XCTAssertTrue(try XCTUnwrap(updated[1].pages.first).usedInBookOfYou)
    }

    func testBraidSourceReceiptsRestoreTheSameCrossMidnightWindowForRebraiding() {
        let latePage = page(id: "late-page", type: .souvenir, createdAt: date("2026-06-05T23:10:00Z"), usedInBookOfYou: true)
        let morningPage = page(id: "morning-page", type: .mood, createdAt: date("2026-06-06T08:00:00Z"), usedInBookOfYou: true)
        let previousDay = BookDay(id: "2026-06-05", date: date("2026-06-05T00:00:00Z"), pages: [latePage])
        let today = BookDay(id: "2026-06-06", date: date("2026-06-06T00:00:00Z"), pages: [morningPage])
        let stampedBraid = BraidPageDetails.withSourcePages(
            bookOfYouPage(id: "cross-midnight-braid"),
            pageIDs: [latePage.id, morningPage.id]
        )

        let restored = NightlyBraidWindow.readingDay(
            for: today,
            pageIDs: BraidPageDetails.sourcePageIDs(in: stampedBraid),
            previousDays: [previousDay]
        )

        XCTAssertEqual(restored.capturedPages.map(\.id), [latePage.id, morningPage.id])
        XCTAssertEqual(BraidPageDetails.sourcePageIDs(in: stampedBraid), [latePage.id, morningPage.id])
    }

    private func dayWithCapturedFragments() -> BookDay {
        let dayDate = date("2026-06-06T12:00:00Z")
        return BookDay(
            id: "2026-06-06",
            date: dayDate,
            pages: [
                page(id: "souvenir", type: .souvenir, createdAt: dayDate, usedInBookOfYou: false)
            ]
        )
    }

    private func page(id: String, type: BookPageType, createdAt: Date = Date(), usedInBookOfYou: Bool) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: createdAt,
            promptText: "Prompt",
            userInput: "A true fragment.",
            tags: [],
            usedInBookOfYou: usedInBookOfYou
        )
    }

    // MARK: - Which braid is official

    /// A day whose receipts a braid can be audited against.
    private func adoptionDay() -> BookDay {
        let dayDate = date("2026-06-06T20:00:00Z")
        return BookDay(
            id: "2026-06-06",
            date: dayDate,
            pages: [
                BookPage(
                    id: "lived-chair", type: .diary, createdAt: dayDate,
                    promptText: "What remained?",
                    userInput: "I tightened the loose screw on the blue kitchen chair.",
                    origin: .userAuthored
                ),
                BookPage(
                    id: "lived-soup", type: .souvenir, createdAt: dayDate,
                    promptText: "What remained?",
                    userInput: "I carried tomato soup to Sam and forgot the silver spoon.",
                    origin: .userAuthored
                )
            ]
        )
    }

    private func braidPage(id: String, body: String) -> BookPage {
        BookPage(
            id: id, type: .bookOfYou, createdAt: date("2026-06-06T21:00:00Z"),
            promptText: "The Book braided today.", userInput: body,
            tags: ["braid"], usedInBookOfYou: true
        )
    }

    private var fullBraidBody: String {
        [
            "The Blue Kitchen Chair",
            "You tightened the loose screw on the blue kitchen chair, and the chair stopped complaining about a thing it had complained about for weeks. I kept the screw. Small repairs are still repairs.",
            "Later you carried tomato soup to Sam and forgot the silver spoon. You went back for it, which is the part I am keeping. The soup and the screw belong in one paragraph: both were you tending something that could not tend itself.",
            "The Book kept the page: the screw and the soup were the same errand."
        ].joined(separator: "\n\n")
    }

    private var thinBraidBody: String {
        "A Chair\n\nYou fixed a chair and carried soup.\n\nThe Book kept the page: you fixed a chair."
    }

    private func adoptionContext(for day: BookDay) -> BraidPromptBuilder.Context {
        BraidPromptBuilder.Context(taleReading: BraidPromptBuilder.taleReading(for: day))
    }

    /// The bug this guards: `BookDay.bookOfYou` reads the last braid on the day,
    /// so before adoption was quality-aware a thinner rewrite silently became
    /// the official page purely by finishing second.
    func testAThinnerRewriteDoesNotTakeTheDay() throws {
        var day = adoptionDay()
        let good = braidPage(id: "good-braid", body: fullBraidBody)
        day.pages.append(good)

        let result = BraidRecoveryState.dayByAdoptingBraid(
            day,
            braid: braidPage(id: "thin-braid", body: thinBraidBody),
            context: adoptionContext(for: day),
            replacingPrior: true
        )

        XCTAssertEqual(result.adoption, .keptExisting)
        XCTAssertEqual(result.day.bookOfYou?.id, "good-braid")
        XCTAssertFalse(result.day.pages.contains { $0.id == "thin-braid" })
    }

    func testABetterRewriteReplacesThePriorBraid() throws {
        var day = adoptionDay()
        day.pages.append(braidPage(id: "thin-braid", body: thinBraidBody))

        let result = BraidRecoveryState.dayByAdoptingBraid(
            day,
            braid: braidPage(id: "good-braid", body: fullBraidBody),
            context: adoptionContext(for: day),
            replacingPrior: true
        )

        XCTAssertEqual(result.adoption, .adopted)
        XCTAssertEqual(result.day.bookOfYou?.id, "good-braid")
        XCTAssertFalse(result.day.pages.contains { $0.id == "thin-braid" })
    }

    /// "Braid a new one too" keeps both pages, but the better one stays the
    /// Book's answer rather than whichever was written most recently.
    func testASecondBraidKeepsBothAndTheBetterStaysOfficial() throws {
        var day = adoptionDay()
        day.pages.append(braidPage(id: "good-braid", body: fullBraidBody))

        let result = BraidRecoveryState.dayByAdoptingBraid(
            day,
            braid: braidPage(id: "thin-braid", body: thinBraidBody),
            context: adoptionContext(for: day),
            replacingPrior: false
        )

        XCTAssertEqual(result.adoption, .keptExisting)
        XCTAssertTrue(result.day.pages.contains { $0.id == "thin-braid" })
        XCTAssertEqual(result.day.bookOfYou?.id, "good-braid")
    }

    func testTheFirstBraidOfTheDayIsAlwaysAdopted() throws {
        let day = adoptionDay()
        let result = BraidRecoveryState.dayByAdoptingBraid(
            day,
            braid: braidPage(id: "thin-braid", body: thinBraidBody),
            context: adoptionContext(for: day)
        )
        XCTAssertEqual(result.adoption, .adopted)
        XCTAssertEqual(result.day.bookOfYou?.id, "thin-braid")
    }

    private func bookOfYouPage(id: String = "book-of-you") -> BookPage {
        page(id: id, type: .bookOfYou, usedInBookOfYou: false)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
