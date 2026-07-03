import XCTest
@testable import InsideCoverCore

final class InstantGratificationTests: XCTestCase {

    // MARK: KeepMarginalia

    func testMarginNoteIsDeterministicForSamePageID() {
        let first = KeepMarginalia.note(for: "The kettle sang twice before I noticed.", pageType: .diary, pageID: "page-abc")
        let second = KeepMarginalia.note(for: "The kettle sang twice before I noticed.", pageType: .diary, pageID: "page-abc")
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    func testMarginNoteVoicesSpreadAcrossPageIDs() {
        // Across many page IDs the seed should reach more than one voice.
        let slugs = Set((0..<24).compactMap { index in
            KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "spark-page-\(index)"
            )?.castSlug
        })
        XCTAssertGreaterThanOrEqual(slugs.count, 2)
    }

    func testMarginNoteSkipsThinAndPrivateKeeps() {
        XCTAssertNil(KeepMarginalia.note(for: "ok", pageType: .diary, pageID: "thin"))
        XCTAssertNil(
            KeepMarginalia.note(
                for: "Slept badly, achy all over, long strange dreams about rain.",
                pageType: .body,
                pageID: "private-body"
            ),
            "The cast never comments on body logs."
        )
        XCTAssertNil(
            KeepMarginalia.note(
                for: "Two eggs, black coffee, a fistful of blueberries at noon.",
                pageType: .fuel,
                pageID: "private-fuel"
            ),
            "The cast never comments on fuel logs."
        )
    }

    func testFeaturedWordAndSubstitutionLeaveNoPlaceholder() {
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "the parking lot looked like a cathedral"),
            "cathedral"
        )
        // Whichever line the seed picks, no unfilled placeholder may remain.
        for index in 0..<24 {
            let note = KeepMarginalia.note(
                for: "the parking lot looked like a cathedral",
                pageType: .souvenir,
                pageID: "cathedral-\(index)"
            )
            XCTAssertNotNil(note)
            XCTAssertFalse(note?.line.contains("{word}") ?? true)
        }
    }

    func testFirstEligibleKeepIsPippasPinnedNote() {
        let note = KeepMarginalia.note(
            for: "A stranger held the door and said something kind.",
            pageType: .diary,
            pageID: "first-keep",
            priorKeepCount: 0
        )
        XCTAssertEqual(note?.castSlug, "pippa-pilcrow")
        XCTAssertEqual(note?.line, KeepMarginalia.firstKeepNote.line)
        // Thin and private keeps are still skipped even on the very first keep.
        XCTAssertNil(KeepMarginalia.note(for: "ok", pageType: .diary, pageID: "first-keep", priorKeepCount: 0))
        XCTAssertNil(
            KeepMarginalia.note(
                for: "Slept badly, achy all over, long strange dreams about rain.",
                pageType: .body,
                pageID: "first-keep",
                priorKeepCount: 0
            )
        )
    }

    func testSecondEligibleKeepIsTheDuet() {
        let note = KeepMarginalia.note(
            for: "The bus was late and the light was the wrong colour.",
            pageType: .diary,
            pageID: "second-keep",
            priorKeepCount: 1
        )
        XCTAssertEqual(note?.castSlug, "professor-thaddeus-mook")
        XCTAssertEqual(note?.rejoinderName, "Pippa Pilcrow")
        XCTAssertNotNil(note?.rejoinderAsset)
        XCTAssertNotNil(note?.rejoinderLine)
    }

    func testGreeterClampBeforeThreshold() {
        for index in 0..<40 {
            let slug = KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "greeter-\(index)",
                priorKeepCount: 5
            )?.castSlug
            XCTAssertNotNil(slug)
            XCTAssertTrue(KeepMarginalia.greeterSlugs.contains(slug ?? ""), "\(slug ?? "nil") is not a greeter")
        }
    }

    func testFullCastAfterThreshold() {
        let slugs = Set((0..<200).compactMap { index in
            KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "mature-\(index)",
                priorKeepCount: 40
            )?.castSlug
        })
        XCTAssertTrue(slugs.contains { !KeepMarginalia.greeterSlugs.contains($0) })
    }

    func testEligibleKeepCountMatchesPagesThatCanShowMarginNotes() {
        let souvenir = BookPage(
            id: "counts", type: .souvenir, promptText: "Catch one bright particular.",
            userInput: "The kettle sang twice before I noticed.", origin: .userAuthored
        )
        let bodyLog = BookPage(
            id: "body", type: .body, promptText: "How is the body?",
            userInput: "Slept badly, achy all over, strange dreams.", origin: .userAuthored
        )
        let thin = BookPage(
            id: "thin", type: .diary, promptText: "A line?",
            userInput: "It rained.", origin: .userAuthored
        )
        let generated = BookPage(
            id: "gen", type: .diary, promptText: "A line?",
            userInput: "The Book wrote this one on its own, at length.", origin: .generated
        )
        let day = BookDay(id: "2026-07-02", date: Date(), pages: [souvenir, bodyLog, thin, generated])
        XCTAssertEqual(KeepMarginalia.eligibleKeepCount(in: [day]), 2)
    }

    func testGeneratedPageKeepAdvancesFirstFriendGate() {
        let generated = BookPage(
            id: "generated-first",
            type: .diary,
            promptText: "The Book offered a page.",
            userInput: "The page had enough honest detail to answer.",
            origin: .generated
        )
        let day = BookDay(id: "2026-07-02", date: Date(), pages: [generated])
        let priorCount = KeepMarginalia.eligibleKeepCount(in: [day])

        let note = KeepMarginalia.note(
            for: "The next kept page should not pretend it is first.",
            pageType: .diary,
            pageID: "after-generated",
            priorKeepCount: priorCount
        )

        XCTAssertEqual(priorCount, 1)
        XCTAssertEqual(note?.castSlug, "professor-thaddeus-mook")
    }

    func testAvoidingRecentCastSlugChoosesDifferentVoiceWhenPossible() throws {
        let base = try XCTUnwrap(KeepMarginalia.note(
            for: "A small true thing happened by the window today.",
            pageType: .diary,
            pageID: "avoid-repeat",
            priorKeepCount: 20
        ))

        let avoided = try XCTUnwrap(KeepMarginalia.note(
            for: "A small true thing happened by the window today.",
            pageType: .diary,
            pageID: "avoid-repeat",
            priorKeepCount: 20,
            avoidingCastSlugs: [base.castSlug]
        ))

        XCTAssertNotEqual(avoided.castSlug, base.castSlug)
    }

    func testRecentCastSlugsReconstructsPriorMarginSpeakers() {
        let first = BookPage(
            id: "first",
            type: .diary,
            createdAt: Date(timeIntervalSince1970: 1),
            promptText: "First",
            userInput: "The first eligible generated page has enough words.",
            origin: .generated
        )
        let second = BookPage(
            id: "second",
            type: .diary,
            createdAt: Date(timeIntervalSince1970: 2),
            promptText: "Second",
            userInput: "The second eligible page has enough words too.",
            origin: .generated
        )
        let day = BookDay(id: "2026-07-02", date: Date(timeIntervalSince1970: 0), pages: [second, first])

        XCTAssertEqual(
            KeepMarginalia.recentCastSlugs(in: [day], limit: 2),
            ["pippa-pilcrow", "professor-thaddeus-mook"]
        )
    }

    func testEveryVoiceHasAccentAndGlyph() {
        for voice in KeepMarginalia.voices {
            XCTAssertEqual(voice.accentHex.count, 6, "\(voice.slug) accent must be RRGGBB")
            var scanned: UInt64 = 0
            XCTAssertTrue(Scanner(string: voice.accentHex).scanHexInt64(&scanned), "\(voice.slug) accent is not hex")
            XCTAssertFalse(voice.glyph.isEmpty, "\(voice.slug) is missing a glyph")
        }
    }

    // MARK: BraidEmber

    func testEmberIsSilentBeforeEvening() {
        let day = dayWithTwoProsePages()
        let morning = Self.date(year: 2026, month: 6, day: 12, hour: 10)
        XCTAssertNil(BraidEmber.teaser(for: day, now: morning, calendar: Self.nyCalendar))
    }

    func testEmberNeedsAtLeastTwoThreads() {
        let single = BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [prosePage(id: "one", createdAtHour: 9, input: "The fog sat low over the harbor all afternoon.")]
        )
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 18)
        XCTAssertNil(BraidEmber.teaser(for: single, now: evening, calendar: Self.nyCalendar))
    }

    func testEmberNamesThreadsInTheEvening() throws {
        let day = dayWithTwoProsePages()
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 18)
        let teaser = try XCTUnwrap(BraidEmber.teaser(for: day, now: evening, calendar: Self.nyCalendar))
        XCTAssertTrue(teaser.contains("two threads"))
        XCTAssertTrue(teaser.contains("harbor"))
        XCTAssertTrue(teaser.contains("cathedral"))
    }

    func testThreadLabelsPreferVividWordsAndDedupe() {
        let day = BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [
                prosePage(id: "a", createdAtHour: 9, input: "Rain over the harbor."),
                moodPage(id: "b", createdAtHour: 10),
                prosePage(id: "c", createdAtHour: 11, input: "The harbor once more.")
            ]
        )
        let labels = BraidEmber.threadLabels(for: day)
        // A prose page is named by its vivid word; a wordless log falls back to
        // its type title (a mood page reads as the app's inner "weather").
        XCTAssertTrue(labels.contains("the harbor"))
        XCTAssertTrue(labels.contains("a weather"))
        XCTAssertEqual(labels.count, 2, "The two harbor pages dedupe to one label.")
        XCTAssertEqual(labels.count, Set(labels).count, "Labels must dedupe.")
    }

    // MARK: Weekly signature

    func testWeeklySignatureCountsRecentBoundPages() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let pages = [
            boundSouvenir(id: "s1", daysAgo: 2, from: now, input: "The rain made the parking lot look like a page under glass."),
            boundSouvenir(id: "s2", daysAgo: 1, from: now, input: "The bus window held the whole grey street for a moment.")
        ]
        let line = try XCTUnwrap(EditionCurator.weeklySignatureLine(monthPages: pages, now: now))
        XCTAssertTrue(line.contains("2 pages"))
        XCTAssertTrue(line.contains("June"))
    }

    func testWeeklySignatureExcludesOlderThanAWeek() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let pages = [
            boundSouvenir(id: "s1", daysAgo: 2, from: now, input: "One recent kept sentence with real weather in it."),
            boundSouvenir(id: "old", daysAgo: 20, from: now, input: "A sentence from three weeks ago, long since bound.")
        ]
        // Only one page falls inside the trailing week, so no signature yet.
        XCTAssertNil(EditionCurator.weeklySignatureLine(monthPages: pages, now: now))
    }

    // MARK: Fixtures

    private func dayWithTwoProsePages() -> BookDay {
        BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [
                prosePage(id: "harbor", createdAtHour: 9, input: "Rain over the harbor."),
                prosePage(id: "cathedral", createdAtHour: 11, input: "The parking lot looked like a cathedral under rain.")
            ]
        )
    }

    private func prosePage(id: String, createdAtHour: Int, input: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: Self.date(year: 2026, month: 6, day: 12, hour: createdAtHour),
            promptText: "Catch one bright particular.",
            userInput: input,
            tags: ["souvenir"]
        )
    }

    private func moodPage(id: String, createdAtHour: Int) -> BookPage {
        BookPage(
            id: id,
            type: .mood,
            createdAt: Self.date(year: 2026, month: 6, day: 12, hour: createdAtHour),
            promptText: "How is the weather inside?",
            userInput: "",
            tags: ["mood"]
        )
    }

    private func boundSouvenir(id: String, daysAgo: Int, from now: Date, input: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: now.addingTimeInterval(TimeInterval(-daysAgo) * 86_400),
            promptText: "Catch one bright particular.",
            userInput: input,
            tags: ["souvenir"],
            origin: .userAuthored
        )
    }

    // Use the current calendar throughout: `BookDay.capturedPages` derives its
    // day window with `Calendar.current`, so fixtures must live in the same
    // timezone or they fall outside the window on non-UTC hosts.
    private static let nyCalendar = Calendar.current

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
}
