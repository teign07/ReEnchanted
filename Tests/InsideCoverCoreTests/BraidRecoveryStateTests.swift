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

    private func bookOfYouPage(id: String = "book-of-you") -> BookPage {
        page(id: id, type: .bookOfYou, usedInBookOfYou: false)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
