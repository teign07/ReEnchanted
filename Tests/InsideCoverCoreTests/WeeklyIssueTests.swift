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

    private func braid(_ id: String, title: String, keptLine: String, dayOffset: Int, hour: Int = 22) -> BookPage {
        BraidPageDetails.annotated(
            BookPage(
                id: id,
                type: .bookOfYou,
                createdAt: at(dayOffset, hour: hour),
                promptText: "Book of You",
                userInput: """
                \(title)

                The window listened while rain tapped the kitchen glass.

                The Book kept the page: \(keptLine).
                """,
                tags: ["braid"]
            ),
            context: .empty
        )
    }

    private func scrapbook(_ id: String, title: String, dayOffset: Int, hour: Int = 16) -> BookPage {
        BookPage(
            id: id,
            type: .plainPage,
            createdAt: at(dayOffset, hour: hour),
            promptText: title,
            userInput: """
            A composed scrapbook page.

            Scraps bound here:
            Souvenir: The harbor fog came in.
            """,
            tags: ["pagewright", "scrapbook", "format:scrapPage", "source-page:source-1"],
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
        // The same archive always makes the same issue. (Built once — the test
        // helpers mint fresh page ids, so two builds are two different archives.)
        let archive = days(firstWeekPages())
        let a = WeeklyIssue.current(days: archive, now: at(7, hour: 10))
        let b = WeeklyIssue.current(days: archive, now: at(7, hour: 10))
        XCTAssertEqual(a, b)
    }

    /// The bound issue typesets the reader's actual ink (Seven Days spread,
    /// plates, the week's page), so the curated pages ride along.
    func testIssueCarriesItsCuratedPagesChronologically() throws {
        let issue = try XCTUnwrap(WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10)))
        XCTAssertGreaterThanOrEqual(issue.pages.count, WeeklyIssue.minimumIssuePages)
        XCTAssertEqual(issue.pages.map(\.createdAt), issue.pages.map(\.createdAt).sorted())
        XCTAssertTrue(issue.pages.allSatisfy { $0.createdAt >= issue.startDate && $0.createdAt < issue.endDate })
    }

    func testShareCardTeasesTheNextIssueDeterministically() throws {
        let issue = try XCTUnwrap(WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10)))
        let card = WeeklyIssueShareCard.make(issue: issue)
        XCTAssertFalse(card.nextIssueTease.isEmpty)
        XCTAssertEqual(card.nextIssueTease, WeeklyIssueShareCard.make(issue: issue).nextIssueTease)
    }

    func testShareCardSummarizesWithoutRawHighlightLines() throws {
        let issue = try XCTUnwrap(WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10)))
        let titleFact = SelfFact(
            id: "earned",
            questionID: "earned-wonder-label",
            question: "Your First Working Title",
            answer: "Lookout",
            bookTranslation: "",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["earned-label"],
            createdAt: at(7),
            updatedAt: at(7)
        )

        let card = WeeklyIssueShareCard.make(issue: issue, selfFacts: [titleFact])

        XCTAssertEqual(card.title, "Lookout Week")
        XCTAssertTrue(card.stats.contains("4 kept pages"))
        XCTAssertTrue(card.motifLine.hasPrefix("Refrain:"))
        XCTAssertFalse(card.motifLine.contains("The kitchen window held"))
        XCTAssertEqual(card.closingLine, "You kept the week from disappearing.")
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

    func testWeeklyIssueSpeaksInTheBooksOwnVoice() {
        let issue = candidates(days: days(firstWeekPages()), now: at(7, hour: 10)).first
        let body = issue?.payload.body ?? ""

        XCTAssertTrue(body.contains("The week looked up"))
        XCTAssertTrue(body.contains("I tried to hold it carefully"))
        XCTAssertTrue(body.contains("the year are still gathering their coats"))
        XCTAssertTrue(body.contains("I will shelve it where it can hum to itself"))
    }

    func testAdapterUsesBookOfYouResidueAsIssueMemory() {
        var pages = firstWeekPages()
        pages.append(braid("braid-1", title: "Rain At The Window", keptLine: "rain made the lamp brave", dayOffset: 6))

        let surfaced = candidates(days: days(pages), now: at(7, hour: 10))
        let issue = surfaced.first

        XCTAssertTrue(issue?.payload.body.contains("Cover story: Rain At The Window") == true)
        XCTAssertTrue(issue?.payload.body.contains("The week's refrain:") == true)
        XCTAssertEqual(issue?.payload.metadata["weeklyIssueCoverStory"], "Rain At The Window - rain made the lamp brave")
        XCTAssertTrue(issue?.payload.metadata["weeklyIssueRefrain"]?.contains("rain") == true)
        XCTAssertTrue(issue?.payload.metadata["weeklyIssueMemoryCallbacks"]?.contains("rain made the lamp brave") == true)
    }

    func testIssueNamesKeptScrapbookPages() {
        var pages = firstWeekPages()
        pages.append(scrapbook("scrap-1", title: "Harbor Scrap", dayOffset: 5))

        let issue = candidates(days: days(pages), now: at(7, hour: 10)).first

        XCTAssertEqual(issue?.payload.metadata["weeklyIssueScrapbookCount"], "1")
        XCTAssertEqual(issue?.payload.metadata["weeklyIssueScrapbookTitles"], "Harbor Scrap")
        XCTAssertTrue(issue?.payload.body.contains("scrapbook page") == true)
        XCTAssertTrue(issue?.payload.body.contains("Harbor Scrap") == true)
    }

    /// The weekly issue must never write to the monthly Bindery's history, or it
    /// would suppress the monthly binding nudge.
    func testUsesItsOwnSourceIDSeparateFromMonthlyBindery() {
        let surfaced = candidates(days: days(firstWeekPages()), now: at(7, hour: 10))
        let monthlyBinderySourceID = BinderyPageSourceAdapter().source.id
        XCTAssertEqual(surfaced.first?.sourceID, "weekly-issue")
        XCTAssertNotEqual(surfaced.first?.sourceID, monthlyBinderySourceID)
    }

    func testDoesNotRepeatAfterKept() {
        var pages = firstWeekPages()
        pages.append(BookPage(type: .bindery, createdAt: at(7, hour: 11), promptText: "Your First Issue",
                              userInput: "", tags: ["weekly-issue:1", "edition"]))
        XCTAssertTrue(candidates(days: days(pages), now: at(7, hour: 20)).isEmpty)
    }

    func testKeptIssueArtifactSurvivesPageArchiveRoundTrip() throws {
        var issue = try XCTUnwrap(WeeklyIssue.current(days: days(firstWeekPages()), now: at(7, hour: 10)))
        issue.dedication = BoundDedication(text: "For the person who made Tuesday matter.")
        let card = WeeklyIssueShareCard.make(issue: issue)
        let artifact = KeptWeeklyIssueArtifact(
            issue: issue,
            card: card,
            readerName: "Reader",
            editorialNote: "The week held together.",
            closingNote: "It is kept.",
            cardPath: "/archive/issue-1.png",
            pdfPath: "/archive/issue-1.pdf",
            keptAt: at(7, hour: 11)
        )
        let page = BookPage(
            id: "weekly-issue-1",
            type: .bindery,
            createdAt: at(7, hour: 11),
            promptText: "Weekly Issue No. 1",
            userInput: "The week held together.",
            tags: ["weekly-issue", "weekly-issue:1", "edition"],
            sourceID: "weekly-issue",
            origin: .generated,
            weeklyIssueArtifact: artifact
        )

        let decoded = try JSONDecoder().decode(BookPage.self, from: JSONEncoder().encode(page))

        XCTAssertEqual(decoded.weeklyIssueArtifact, artifact)
        XCTAssertEqual(decoded.weeklyIssueArtifact?.issue.dedication, issue.dedication)
        XCTAssertEqual(decoded.weeklyIssueArtifact?.issue.number, 1)
        XCTAssertEqual(decoded.weeklyIssueArtifact?.pdfPath, "/archive/issue-1.pdf")
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
