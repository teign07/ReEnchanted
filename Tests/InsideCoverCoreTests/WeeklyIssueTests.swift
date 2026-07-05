import XCTest
@testable import InsideCoverCore

/// The Weekly Issue — the reader's past seven days packaged as a felt "issue,"
/// anchored to their own start so Issue No. 1 is always their first week.
final class WeeklyIssueTests: XCTestCase {
    private let calendar = Calendar.current
    private let base = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9))!

    private func at(_ dayOffset: Int, hour: Int = 12) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: base)!
            .addingTimeInterval(Double(hour - 9) * 3600)
    }

    private func souvenir(_ text: String, dayOffset: Int, hour: Int = 12) -> BookPage {
        BookPage(type: .souvenir, createdAt: at(dayOffset, hour: hour), promptText: "Souvenir", userInput: text)
    }

    /// A full first week of kept souvenirs, the first at `base`.
    private func firstWeekPages() -> [BookPage] {
        [
            souvenir("The kitchen window held the last of the gold light.", dayOffset: 0),
            souvenir("Rain all afternoon, and I did not mind it once.", dayOffset: 2),
            souvenir("A quiet mug of coffee before anyone else woke.", dayOffset: 4),
            souvenir("The harbor fog came in without a sound.", dayOffset: 6)
        ]
    }

    /// Group pages into one BookDay per calendar day, as a real archive does —
    /// `BookDay.capturedPages` only returns pages that belong to that day.
    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { id, ps in BookDay(id: id, date: calendar.startOfDay(for: ps[0].createdAt), pages: ps) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Engine

    func testNoIssueBeforeTheFirstWeekCloses() {
        let issue = WeeklyIssue.current(days: days(firstWeekPages()), now: at(6, hour: 20))
        XCTAssertNil(issue, "still inside week one")
    }

    func testFirstIssueClosesAtSevenDays() {
        let issue = WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10))
        XCTAssertEqual(issue?.number, 1)
        XCTAssertTrue(issue?.isFirstIssue == true)
        XCTAssertEqual(issue?.keptCount, 4)
        XCTAssertFalse(issue?.highlights.isEmpty == true)
        XCTAssertEqual(issue?.dateRange, "Jul 1\u{2013}7")
    }

    func testIssueNumberIncrementsBySecondWeek() {
        var pages = firstWeekPages()
        pages += [
            souvenir("A new week: the streetlights buzzed awake at dusk.", dayOffset: 8),
            souvenir("Snow that could not decide whether to fall.", dayOffset: 11)
        ]
        let issue = WeeklyIssue.current(days: days(pages), now: at(14, hour: 10))
        XCTAssertEqual(issue?.number, 2)
        XCTAssertFalse(issue?.isFirstIssue == true)
        // Issue 2 covers only its own week's pages.
        XCTAssertEqual(issue?.keptCount, 2)
    }

    func testIssueGoesStaleAfterItsFreshnessWindow() {
        // Five days into the second week: issue one has closed but gone stale,
        // and issue two has not closed yet.
        let issue = WeeklyIssue.current(days: days(firstWeekPages()), now: at(12, hour: 10))
        XCTAssertNil(issue)
    }

    func testThinWeekEarnsNoCover() {
        let onePage = [souvenir("A single line, kept alone.", dayOffset: 1)]
        let issue = WeeklyIssue.current(days: days(onePage), now: at(7, hour: 10))
        XCTAssertNil(issue)
    }

    func testIsDeterministic() {
        let a = WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10))
        let b = WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10))
        XCTAssertEqual(a, b)
    }

    // MARK: - Adapter

    private let adapter = WeeklyIssuePageSourceAdapter()

    private func candidates(days: [BookDay], now: Date, context: CuratorContext? = nil) -> [SurfacePage] {
        var inputs = BookSourceInputs.empty
        inputs.days = days
        let today = BookDay(id: "today", date: now, pages: [])
        return adapter.candidates(for: today, context: context ?? CuratorContext.make(for: today), inputs: inputs, now: now)
    }

    func testAdapterSurfacesFirstIssueAsAMilestone() {
        let surfaced = candidates(days: days(firstWeekPages()), now: at(7, hour: 10))
        XCTAssertEqual(surfaced.first?.type, .bindery)
        XCTAssertEqual(surfaced.first?.payload.metadata["weeklyIssue"], "true")
        XCTAssertEqual(surfaced.first?.payload.metadata["weeklyIssueNumber"], "1")
        XCTAssertEqual(surfaced.first?.payload.metadata["weeklyIssueFirst"], "true")
        XCTAssertEqual(surfaced.first?.score, 82)
        XCTAssertTrue(surfaced.first?.payload.body.contains("Issue No. 1") == true)
    }

    /// The weekly issue must never write to the monthly Bindery's history, or it
    /// would suppress the monthly binding nudge.
    func testUsesItsOwnSourceIDSeparateFromMonthlyBindery() {
        let surfaced = candidates(days: days(firstWeekPages()), now: at(7, hour: 10))
        let monthlyBinderySourceID = BinderyPageSourceAdapter().source.id
        XCTAssertEqual(surfaced.first?.sourceID, "\(monthlyBinderySourceID)-weekly")
        XCTAssertNotEqual(surfaced.first?.sourceID, monthlyBinderySourceID)
    }

    func testDoesNotRepeatAfterKept() {
        var pages = firstWeekPages()
        pages.append(BookPage(type: .bindery, createdAt: at(7, hour: 11), promptText: "Your First Issue",
                              userInput: "", tags: ["weekly-issue:1", "edition"]))
        XCTAssertTrue(candidates(days: days(pages), now: at(7, hour: 20)).isEmpty)
    }

    func testDefersDuringDistress() {
        let hardDay = BookDay(id: "today", date: at(7, hour: 10), pages: [
            BookPage(type: .mood, createdAt: at(7, hour: 9), promptText: "Mood",
                     userInput: "a hard one", tags: ["distress"])
        ])
        var inputs = BookSourceInputs.empty
        inputs.days = days(firstWeekPages())
        let distressed = CuratorContext.make(for: hardDay)
        XCTAssertTrue(distressed.distress.isActive)
        XCTAssertTrue(adapter.candidates(for: hardDay, context: distressed, inputs: inputs, now: at(7, hour: 10)).isEmpty)
    }
}
