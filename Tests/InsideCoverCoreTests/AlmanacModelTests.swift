import XCTest
@testable import InsideCoverCore

final class AlmanacModelTests: XCTestCase {

    // A Gregorian calendar with a fixed firstWeekday (Sunday) and UTC so the
    // grid math is deterministic regardless of the test machine's locale.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1 // Sunday
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = 12
        return calendar.date(from: comps)!
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, pages: Int) -> BookDay {
        let dayStart = date(y, m, d)
        // Space the captured pages within the day so createdAt lands in range.
        let pages = (0..<pages).map { i in
            BookPage(
                id: "\(y)-\(m)-\(d)-\(i)",
                type: .diary,
                createdAt: dayStart.addingTimeInterval(Double(i) * 60),
                promptText: "p\(i)"
            )
        }
        return BookDay(id: AlmanacModel.dayID(for: dayStart, calendar: calendar), date: dayStart, pages: pages)
    }

    // MARK: grid shape

    func testGridHasLeadingBlanksAndAllDays() {
        // March 2027: the 1st is a Monday, so with Sunday-first there is exactly
        // one leading blank. March has 31 days.
        let grid = AlmanacModel.grid(forMonthContaining: date(2027, 3, 15), days: [], calendar: calendar)
        let cells = grid.weeks.flatMap { $0 }
        XCTAssertEqual(cells.count % 7, 0)
        let leadingBlanks = cells.prefix { $0.date == nil }.count
        XCTAssertEqual(leadingBlanks, 1)
        let dayCells = cells.filter { $0.date != nil }
        XCTAssertEqual(dayCells.count, 31)
    }

    // MARK: counts land on the right cells

    func testKeptCountsLandOnCorrectCell() {
        let days = [day(2027, 3, 3, pages: 2), day(2027, 3, 10, pages: 1)]
        let grid = AlmanacModel.grid(forMonthContaining: date(2027, 3, 1), days: days, calendar: calendar)
        let cells = grid.weeks.flatMap { $0 }
        func count(day d: Int) -> Int {
            cells.first { $0.date.map { calendar.component(.day, from: $0) == d } ?? false }?.keptCount ?? -1
        }
        XCTAssertEqual(count(day: 3), 2)
        XCTAssertEqual(count(day: 10), 1)
        XCTAssertEqual(count(day: 4), 0)
    }

    // MARK: bounds clamp to the archive

    func testBoundsSpanFirstOfEarliestToFirstOfLatestMonth() {
        let days = [day(2027, 2, 20, pages: 1), day(2027, 5, 4, pages: 1)]
        let bounds = AlmanacModel.bounds(days: days, calendar: calendar)
        XCTAssertEqual(bounds?.earliest, calendar.startOfDay(for: date(2027, 2, 1)))
        XCTAssertEqual(bounds?.latest, calendar.startOfDay(for: date(2027, 5, 1)))
    }

    func testBoundsNilWhenNothingKept() {
        XCTAssertNil(AlmanacModel.bounds(days: [], calendar: calendar))
    }

    // MARK: day drill-down

    func testKeptPagesForDayReturnsNewestFirst() {
        let days = [day(2027, 3, 3, pages: 3)]
        let pages = AlmanacModel.keptPages(on: date(2027, 3, 3), days: days, calendar: calendar)
        XCTAssertEqual(pages.count, 3)
        XCTAssertTrue(pages[0].createdAt >= pages[1].createdAt)
        XCTAssertTrue(pages[1].createdAt >= pages[2].createdAt)
    }

    // MARK: Thread of the Month

    func testLitDayCountsDistinctDaysNotPageVolume() {
        // Three lit days in March; page volume on any one day is irrelevant.
        let days = [
            day(2027, 3, 2, pages: 5),
            day(2027, 3, 9, pages: 1),
            day(2027, 3, 20, pages: 3)
        ]
        XCTAssertEqual(
            ThreadOfTheMonth.litDayCount(inMonthContaining: date(2027, 3, 15), days: days, calendar: calendar),
            3
        )
    }

    func testLitDayCountIgnoresOtherMonthsAndEmptyDays() {
        let days = [
            day(2027, 3, 4, pages: 1),
            day(2027, 3, 5, pages: 0), // no captured pages — not lit
            day(2027, 2, 28, pages: 4), // previous month
            day(2027, 4, 1, pages: 2)   // next month
        ]
        XCTAssertEqual(
            ThreadOfTheMonth.litDayCount(inMonthContaining: date(2027, 3, 15), days: days, calendar: calendar),
            1
        )
    }

    func testProgressReportsOnlyWhatTheMonthAlreadyHolds() {
        let days = [
            day(2027, 3, 1, pages: 2),
            day(2027, 3, 2, pages: 1),
            day(2027, 3, 3, pages: 3),
            day(2027, 3, 4, pages: 1),
            day(2027, 3, 5, pages: 2),
            day(2027, 2, 28, pages: 8)
        ]
        let progress = ThreadOfTheMonth.progress(forMonthContaining: date(2027, 3, 15), days: days, calendar: calendar)
        XCTAssertEqual(progress.litDays, 5)
        XCTAssertEqual(progress.keptPages, 9)
        XCTAssertTrue(calendar.isDate(progress.monthStart, inSameDayAs: date(2027, 3, 1)))
    }

    func testProgressHasNoTierOrDistanceToAQuota() {
        let days = (1...22).map { day(2027, 3, $0, pages: 1) }
        let progress = ThreadOfTheMonth.progress(forMonthContaining: date(2027, 3, 15), days: days, calendar: calendar)
        XCTAssertEqual(progress.litDays, 22)
        XCTAssertEqual(progress.keptPages, 22)
    }
}
