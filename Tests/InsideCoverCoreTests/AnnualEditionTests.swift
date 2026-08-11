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

    private func scrapbook(_ id: String, title: String, on when: Date) -> BookPage {
        BookPage(
            id: id,
            type: .plainPage,
            createdAt: when,
            promptText: title,
            userInput: """
            A composed scrapbook page.

            Scraps bound here:
            Souvenir: The harbor fog came in.
            """,
            tags: ["annual-test", "pagewright", "scrapbook", "format:scrapPage"],
            sourceID: "pagewright",
            origin: .userAuthored,
            privacy: .privateLocal,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: "/tmp/\(id).png",
                    caption: title,
                    sourceID: "pagewright"
                )
            ]
        )
    }

    private func braid(_ id: String, title: String, keptLine: String, on when: Date) -> BookPage {
        BraidPageDetails.annotated(
            BookPage(
                id: id,
                type: .bookOfYou,
                createdAt: when,
                promptText: "Book of You",
                userInput: """
                \(title)

                The rain tapped the window while the lamp kept watch.

                The Book kept the page: \(keptLine).
                """,
                tags: ["annual-test", "braid"],
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id
            ),
            context: .empty
        )
    }

    /// A few months of kept pages, plus one empty month between them.
    private func sampleDays() -> [BookDay] {
        var days: [BookDay] = []
        // January: souvenirs + braids.
        days.append(BookDay(id: "2026-01-05", date: date(1, 5, hour: 0), pages: [
            page("jan-s1", type: .souvenir, on: date(1, 5)),
            braid("jan-b1", title: "Rain At The Window", keptLine: "rain made the lamp brave", on: date(1, 5, hour: 22))
        ]))
        days.append(BookDay(id: "2026-01-18", date: date(1, 18, hour: 0), pages: [
            page("jan-s2", type: .souvenir, on: date(1, 18))
        ]))
        // February: empty (no pages); should not become a chapter.
        days.append(BookDay(id: "2026-02-10", date: date(2, 10, hour: 0), pages: []))
        // March: letters + souvenirs.
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
        XCTAssertTrue(first.foreword.hasSuffix("\n\nThe Book"))
        XCTAssertFalse(first.closing.isEmpty)
        XCTAssertEqual(first, again, "the same year binds identically")
    }

    func testAnnualForewordAndClosingUseTheBooksOwnVoice() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)

        XCTAssertTrue(annual.foreword.contains("patted the corners flat"))
        XCTAssertTrue(annual.foreword.contains("the month is still there, waiting where you left it"))
        XCTAssertTrue(annual.foreword.contains("I kept turning the pages anyway"))
        XCTAssertTrue(annual.closing.contains("tucked in the corners"))
        XCTAssertTrue(annual.closing.contains("The next page is blank and already eavesdropping"))
    }

    func testEachChapterKeepsItsOwnSections() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        for chapter in annual.chapters {
            XCTAssertFalse(chapter.sections.isEmpty, "\(chapter.monthName) should carry curated sections")
            XCTAssertFalse(chapter.foreword.isEmpty, "\(chapter.monthName) keeps its own foreword")
        }
    }

    func testAnnualCarriesScrapbookPagesThroughMonthlyChapters() {
        let days = [
            BookDay(id: "2026-01-05", date: date(1, 5, hour: 0), pages: [
                page("jan-s1", type: .souvenir, on: date(1, 5)),
                scrapbook("jan-scrap", title: "January Scrap", on: date(1, 5, hour: 16))
            ])
        ]

        let annual = MonthlyEditionBuilder.annual(2026, from: days, readerName: "bj", now: date(12, 31), calendar: calendar)
        let section = annual.chapters.first?.sections.first { $0.id == "scrapbook-pages" }

        XCTAssertEqual(section?.title, "Scrapbook Pages")
        XCTAssertEqual(section?.items.map(\.id), ["jan-scrap"])
        XCTAssertEqual(section?.items.first?.title, "January Scrap")
    }

    func testAnnualCarriesYearLevelMemorySpine() {
        let annual = MonthlyEditionBuilder.annual(2026, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)

        XCTAssertTrue(annual.memorySpine?.motifs.contains { $0.contains("rain") } == true)
        XCTAssertTrue(annual.memorySpine?.callbacks.contains { $0.contains("rain made the lamp brave") } == true)
        XCTAssertTrue(annual.memorySpine?.coverStories.contains { $0.contains("Rain At The Window") } == true)
    }

    func testEmptyYearBindsToNothing() {
        let annual = MonthlyEditionBuilder.annual(2025, from: sampleDays(), readerName: "bj", now: date(12, 31), calendar: calendar)
        XCTAssertTrue(annual.isEmpty, "a year with no kept pages has no chapters")
        XCTAssertEqual(annual.chapters.count, 0)
    }
}
