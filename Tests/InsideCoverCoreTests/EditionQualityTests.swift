import XCTest
@testable import InsideCoverCore

/// Regressions from reading real proofs of every publication (weekly issue,
/// monthly edition, seasonal volume, annual hardcover) built from a synthetic
/// year. Each test names what a reader actually saw printed.
final class EditionQualityTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func braid(_ id: String, title: String, body: String, on day: Date) -> BookPage {
        BookPage(id: id, type: .bookOfYou, createdAt: day,
                 promptText: "The local Book brain braided today.",
                 userInput: "\(title)\n\n\(body)\n\nThe Book kept the page: \(title.lowercased()).",
                 tags: ["braid", "book-of-you", "local-model", "mlx", "gemma"], origin: .generated)
    }

    // MARK: Bookkeeping never becomes the reader's language

    /// "Diary, Then Braid" was a month's theme: page tags counted as words.
    func testTagsAndBraidPlumbingAreNotPatternWords() {
        let souvenir = BookPage(type: .souvenir, createdAt: date(10, 1), promptText: "Keep one thing",
                                userInput: "The fox sat on the wall.",
                                tags: ["souvenir", "check-in-window:evening", "diary"])
        let words = LiteraryContinuityProjector.meaningfulWords(in: souvenir.resolvedAttentionFingerprint.patternText)
        XCTAssertTrue(words.contains("wall"))
        for leaked in ["souvenir", "check", "window", "evening", "diary"] {
            XCTAssertFalse(words.contains(leaked), leaked)
        }

        let night = braid("b", title: "The Card in the Atlas", body: "You found the card in the atlas.", on: date(10, 1))
        let braidWords = LiteraryContinuityProjector.meaningfulWords(in: night.resolvedAttentionFingerprint.patternText)
        for leaked in ["local", "brain", "braided", "braid", "gemma", "book", "page"] {
            XCTAssertFalse(braidWords.contains(leaked), leaked)
        }
    }

    /// The Book's own prose (every braid says "Curse") is not the reader's
    /// returning language; a season was titled "The Season of Curse".
    func testThemesComeFromTheReadersPagesNotTheBooks() {
        var pages: [BookPage] = []
        for day in 1...14 {
            pages.append(BookPage(type: .diary, createdAt: date(10, day), promptText: "One true thing",
                                  userInput: day.isMultiple(of: 2) ? "Walked the dog past the harbour." : "Rain on the harbour wall again."))
            pages.append(braid("b\(day)", title: "Night \(day)", body: "The Curse hates the Labyrinth. The Curse lost tonight.", on: date(10, day, hour: 22)))
        }
        let digest = LiteraryContinuityProjector.digest(days: [BookDay(id: "d", date: date(10, 1), pages: pages)],
                                                        events: [], entityMemories: [], now: date(10, 31), calendar: calendar)
        let subjects = Set(digest.signals.map(\.subjectID))
        XCTAssertFalse(subjects.contains("curse"))
        XCTAssertFalse(subjects.contains("labyrinth"))
    }

    /// "Journal Page has turned into a thread rather than a moment" is a Page
    /// type being used, not something the reader's month did.
    func testPageTypeBeliefIsNeverPrintedAsAThread() {
        let pages = (1...20).map { BookPage(type: .diary, createdAt: date(10, $0), promptText: "p", userInput: "Line \($0) about a kettle.") }
        let digest = LiteraryContinuityProjector.digest(
            days: [BookDay(id: "d", date: date(10, 1), pages: pages)], events: [], entityMemories: [],
            pageBelief: [BookPageSourceRegistry.source(for: .diary).id: 90], now: date(10, 31), calendar: calendar)
        let printed = digest.signals.map(\.line).joined(separator: " ")
        XCTAssertFalse(printed.contains(BookPageType.diary.title), printed)
        XCTAssertTrue(digest.beliefLifecycles.contains { $0.isPageSource == true }, "the ledger keeps it")
    }

    /// Adverbs and past-tense verbs crowned themes: "Rain and Boiled",
    /// "Door, Then Watched", and a thread for "Nearly".
    func testAdverbsAndPastTenseVerbsAreNotLiterarySubjects() {
        for word in ["nearly", "anyway", "boiled", "watched", "stayed", "because"] {
            XCTAssertFalse(LiteraryContinuityProjector.isLiteraryCandidate(word), word)
        }
        for word in ["harbour", "bread", "seed", "speed", "kettle"] {
            XCTAssertTrue(LiteraryContinuityProjector.isLiteraryCandidate(word), word)
        }
    }

    // MARK: Refrains are words that came back

    func testBraidMotifsAreWholeWordsAndNeverTheColophon() {
        let days = [BookDay(id: "d", date: date(10, 5), pages: [
            braid("a", title: "Sunday Tea", body: "Instead of cupboards, the handle of the door.", on: date(10, 5))
        ])]
        let motifs = BindingMemorySpine.digest(days: days, now: date(10, 31)).motifCounts.map(\.motif)
        for wrong in ["sun", "tea", "cup", "hand", "book", "page"] where wrong != "tea" {
            XCTAssertFalse(motifs.contains(wrong), wrong)
        }
        XCTAssertTrue(motifs.contains("door"))
    }

    func testTheWeeksRefrainNeedsARepeatedWord() {
        func card(_ lines: [String]) -> WeeklyIssueShareCard {
            var issue = WeeklyIssue(number: 5, startDate: date(10, 1), endDate: date(10, 8), dateRange: "Oct 1–7",
                                    keptCount: lines.count, highlights: lines, pages: [])
            issue.highlights = lines
            return WeeklyIssueShareCard.make(issue: issue)
        }
        XCTAssertEqual(card(["Because the bus was late.", "Anyway, the kettle boiled."]).motifLine,
                       "The week kept its own weather.")
        XCTAssertEqual(card(["Rain on the harbour.", "The harbour fog lifted.", "Toast."]).motifLine, "Refrain: harbour")
    }

    // MARK: Counting pages in words, not titles

    /// "2 quote to keeps and 2 what the sky is doings", and "month" in a week.
    func testSetAsideLineUsesNounsAndItsOwnSpan() {
        XCTAssertEqual(EditionCurator.countPhrase(type: .quotes, count: 2), "2 quotes")
        XCTAssertEqual(EditionCurator.countPhrase(type: .weather, count: 1), "one sky note")
        XCTAssertEqual(EditionCurator.countPhrase(type: .bookOfYou, count: 3), "3 braids")
        XCTAssertEqual(EditionCurator.countPhrase(type: .twoReadings, count: 2), "2 Two Readings pages")
        var curated = EditionCurator.CuratedMonth(pages: [], setAside: [.quotes: 2])
        curated.span = "week"
        XCTAssertEqual(curated.setAsideLine, "The week also held 2 quotes - kept in the archive, but not bound here.")
    }

    // MARK: Braids bind under their own names

    func testABraidBindsUnderItsTitleWithoutItsTitleLine() {
        let page = braid("b", title: "The Lamp Works", body: "You rewired the brass lamp.", on: date(10, 3))
        XCTAssertEqual(page.bindingDisplayTitle, "The Lamp Works")
        XCTAssertFalse(page.bindingBodyText.hasPrefix("The Lamp Works"))
        XCTAssertTrue(page.bindingBodyText.contains("You rewired the brass lamp."))
    }

    // MARK: A chapter reads its own month

    /// Bound into a December annual, January's words were "quiet for 238 days".
    func testAChapterIsReadAsOfItsOwnLastDay() {
        let january = (1...25).map { BookPage(type: .diary, createdAt: date(1, $0), promptText: "p",
                                              userInput: $0 < 5 ? "The harbour bell rang." : "Toast and the radio.") }
        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "jan", date: date(1, 1), pages: january)], readerName: "Wren",
            startDate: date(1, 1, hour: 0), endDate: date(1, 31, hour: 23), generatedAt: date(12, 31), calendar: calendar)
        let quiet = edition.continuity.signals.filter { $0.kind == .absence }
        // Nothing in January can have been quiet for longer than January.
        let longest = quiet.compactMap { signal -> Int? in
            signal.line.components(separatedBy: "quiet for ").last?.split(separator: " ").first.flatMap { Int($0) }
        }.max() ?? 0
        XCTAssertLessThanOrEqual(longest, 31, "\(quiet.map(\.line))")
    }

    /// Twelve identical "nothing arranged itself into a story" leaves in one
    /// hardcover.
    func testAVolumeChapterDropsOnlyTheQuietRegister() {
        let quiet = MonthlyEditionSection(id: "what-this-was", title: "What This Month Was", note: "", items: [
            MonthlyEditionItem(id: "w", kind: .continuity, title: "", body: "Nothing in this month arranged itself into a story.",
                               date: nil, pageType: nil, sourceID: nil, mediaAssets: [], tags: ["span-shape"])
        ])
        let running = MonthlyEditionSection(id: "what-this-was", title: "What This Month Was", note: "", items: [
            MonthlyEditionItem(id: "w", kind: .continuity, title: "", body: "Something has been running under this month.",
                               date: nil, pageType: nil, sourceID: nil, mediaAssets: [], tags: ["span-shape", "beat:crossing"])
        ])
        var chapter = MonthlyEditionBuilder.edition(from: [], readerName: "Wren", startDate: date(3, 1), endDate: date(3, 31), calendar: calendar)
        chapter.sections = [quiet]
        XCTAssertTrue(MonthlyEditionBuilder.asVolumeChapter(chapter).sections.isEmpty)
        chapter.sections = [running]
        XCTAssertEqual(MonthlyEditionBuilder.asVolumeChapter(chapter).sections.count, 1)
    }
}
