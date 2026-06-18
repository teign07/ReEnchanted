import XCTest
@testable import InsideCoverCore

final class AnnualEditionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? Date()
    }

    private func page(_ id: String, type: BookPageType, on when: Date) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: when,
            promptText: "Prompt \(id)",
            userInput: "Kept page \(id)",
            tags: ["annual-test"],
            sourceID: BookPageSourceRegistry.source(for: type).id
        )
    }

    /// A few months of kept pages, plus one empty month between them.
    private func sampleDays() -> [BookDay] {
        var days: [BookDay] = []
        // January — souvenirs + braids.
        days.append(BookDay(id: "2026-01-05", date: date(1, 5, hour: 0), pages: [
            page("jan-s1", type: .souvenir, on: date(1, 5)),
            page("jan-b1", type: .bookOfYou, on: date(1, 5, hour: 22))
        ]))
        days.append(BookDay(id: "2026-01-18", date: date(1, 18, hour: 0), pages: [
            page("jan-s2", type: .souvenir, on: date(1, 18))
        ]))
        // February — empty (no pages); should not become a chapter.
        days.append(BookDay(id: "2026-02-10", date: date(2, 10, hour: 0), pages: []))
        // March — letters + souvenirs.
        days.append(BookDay(id: "2026-03-09", date: date(3, 9, hour: 0), pages: [
            page("mar-l1", type: .letter, on: date(3, 9)),
            page("mar-s1", type: .souvenir, on: date(3, 9, hour: 20))
        ]))
        return days
    }

    func testAnnualBindsOneChapterPerMonthWithPages() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        XCTAssertFalse(annual.isEmpty)
        XCTAssertEqual(annual.year, 2026)
        // January and March kept pages; February did not.
        XCTAssertEqual(annual.chapters.count, 2)
        XCTAssertEqual(annual.chapters.map(\.monthName), ["January 2026", "March 2026"])
    }

    func testAnnualChaptersAreInCalendarOrderAndNumbered() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        let starts = annual.chapters.map(\.startDate)
        XCTAssertEqual(starts, starts.sorted(), "chapters bind in calendar order")
        // Chapter numbers are the months' positions among months with pages.
        XCTAssertEqual(annual.chapters.first?.chapterNumber, 1)
        XCTAssertEqual(annual.chapters.last?.chapterNumber, 2)
    }

    func testAnnualTotalsSumTheChapters() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        XCTAssertEqual(annual.pageCount, annual.chapters.reduce(0) { $0 + $1.pageCount })
        XCTAssertEqual(annual.dayCount, annual.chapters.reduce(0) { $0 + $1.dayCount })
        XCTAssertEqual(annual.pageCount, 5, "four authored pages in Jan/Mar plus the braid")
    }

    func testAnnualForewordIsWrittenAndDeterministic() {
        let days = sampleDays()
        let first = MonthlyEditionBuilder.annual(2026, from: days, readerName: "bj", now: date(12, 31), calendar: calendar)
        let again = MonthlyEditionBuilder.annual(2026, from: days, readerName: "bj", now: date(12, 31), calendar: calendar)
        XCTAssertFalse(first.foreword.isEmpty)
        XCTAssertTrue(first.foreword.contains("2026"))
        XCTAssertTrue(first.foreword.hasSuffix("- The Book"))
        XCTAssertFalse(first.closing.isEmpty)
        XCTAssertEqual(first, again, "the same year binds identically")
    }

    func testEachChapterKeepsItsOwnSections() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        for chapter in annual.chapters {
            XCTAssertFalse(chapter.sections.isEmpty, "\(chapter.monthName) should carry curated sections")
            XCTAssertFalse(chapter.foreword.isEmpty, "\(chapter.monthName) keeps its own foreword")
        }
    }

    func testEmptyYearBindsToNothing() {
        let annual = MonthlyEditionBuilder.annual(2025, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        XCTAssertTrue(annual.isEmpty, "a year with no kept pages has no chapters")
        XCTAssertEqual(annual.chapters.count, 0)
    }
}
