import XCTest
@testable import InsideCoverCore

/// The Bindery nudge: at the turn of a month, when the month just past holds
/// enough bound-worthy pages, a page surfaces that opens the BookShop's Bindery
/// shelf. It is gated to early in the month, to a worthwhile page count, and to
/// once per month.
final class BinderyAdapterTests: XCTestCase {
    private let adapter = BinderyPageSourceAdapter()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
    }

    /// Four substantial May diary pages: comfortably above the binding floor.
    private func mayDays() -> [BookDay] {
        (1...4).map { d in
            let when = date(2026, 5, d * 5)
            return BookDay(id: "2026-05-\(d * 5)", date: when, pages: [
                BookPage(type: .diary, promptText: "Diary",
                         userInput: "A real kept sentence number \(d), with enough substance to bind.")
            ])
        }
    }

    private func candidates(now: Date, inputs: BookSourceInputs) -> [SurfacePage] {
        let day = BookDay(id: "today", date: now, pages: [])
        return adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
    }

    func testSurfacesEarlyInMonthWhenLastMonthHasPages() {
        var inputs = BookSourceInputs.empty
        inputs.days = mayDays()
        let surfaced = candidates(now: date(2026, 6, 3), inputs: inputs)
        XCTAssertEqual(surfaced.first?.type, .bindery)
        XCTAssertEqual(surfaced.first?.payload.metadata["opensBookShop"], "true")
        XCTAssertEqual(surfaced.first?.payload.metadata["binderyShelf"], "true")
        XCTAssertEqual(surfaced.first?.payload.metadata["binderyMonthName"], "May")
    }

    func testDoesNotSurfaceLateInTheMonth() {
        var inputs = BookSourceInputs.empty
        inputs.days = mayDays()
        XCTAssertTrue(candidates(now: date(2026, 6, 20), inputs: inputs).isEmpty)
    }

    func testDoesNotSurfaceWhenLastMonthIsTooThin() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-05-10", date: date(2026, 5, 10), pages: [
            BookPage(type: .diary, promptText: "Diary", userInput: "a single thin page")
        ])]
        XCTAssertTrue(candidates(now: date(2026, 6, 3), inputs: inputs).isEmpty)
    }

    func testDoesNotRepeatOncesShownThisMonth() {
        var inputs = BookSourceInputs.empty
        inputs.days = mayDays()
        inputs.surfaceHistory["source:bindery-call"] = SurfaceHistoryRecord(lastShownAt: date(2026, 6, 1), recentShowCount: 1)
        XCTAssertTrue(candidates(now: date(2026, 6, 3), inputs: inputs).isEmpty)
    }
}
