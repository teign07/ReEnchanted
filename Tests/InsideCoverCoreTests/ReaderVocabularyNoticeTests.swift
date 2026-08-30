import XCTest
@testable import InsideCoverCore

/// Notices gated on nothing but the reader having written something twice.
///
/// Fifteen kinds of Notice existed and four ever fired in a simulated
/// fortnight, because the rest wait on a person thread, a connection, a wager
/// or an aliveness trace. These three read the archive's own vocabulary, which
/// is the one thing that is always there.
final class ReaderVocabularyNoticeTests: XCTestCase {
    private var calendar: Calendar {
        var v = Calendar(identifier: .gregorian); v.timeZone = TimeZone(secondsFromGMT: 0)!; return v
    }
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func page(_ id: String, _ text: String, daysAgo: Double) -> BookPage {
        BookPage(
            id: id, type: .souvenir,
            createdAt: now.addingTimeInterval(-daysAgo * 86_400),
            promptText: "Souvenir", userInput: text, origin: .userAuthored
        )
    }

    private func archive(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages, by: { BookDay.id(for: $0.createdAt, calendar: calendar) })
            .map { id, pages in
                BookDay(id: id, date: calendar.startOfDay(for: pages[0].createdAt), pages: pages)
            }
            .sorted { $0.date < $1.date }
    }

    func testAWordThatComesBackAfterALongSilenceIsNoticed() {
        let days = archive([
            page("old", "The harbour had a lantern on every post.", daysAgo: 120),
            page("filler1", "Bread going stale beside the kettle.", daysAgo: 60),
            page("filler2", "Frost on the window before dawn.", daysAgo: 30),
            page("new", "Down at the harbour again, years later it felt like.", daysAgo: 0.5)
        ])
        let vocabulary = ReaderVocabulary.of(days: days)

        let returned = ReaderVocabularyNotice.returned(in: vocabulary, now: now)

        XCTAssertEqual(returned?.word, "harbour")
        XCTAssertGreaterThan(returned?.gapDays ?? 0, 100)
        XCTAssertEqual(returned?.earlier.pageID, "old")
        XCTAssertEqual(returned?.recent.pageID, "new")
    }

    /// A word used last week and again today is a habit, not a return.
    func testAWordInSteadyUseIsNotAReturn() {
        let days = archive([
            page("a", "The kettle clicked off before dawn.", daysAgo: 6),
            page("b", "The kettle again, and frost.", daysAgo: 0.5)
        ])

        XCTAssertNil(ReaderVocabularyNotice.returned(in: ReaderVocabulary.of(days: days), now: now))
    }

    func testAGenuinelyNewWordIsNoticedOnlyInAnArchiveOldEnoughToMeanIt() {
        let mature = archive([
            page("old1", "The kettle clicked off before dawn.", daysAgo: 90),
            page("old2", "Frost on the window again.", daysAgo: 60),
            page("new", "A brackish smell coming off the reservoir.", daysAgo: 0.5)
        ])
        let first = ReaderVocabularyNotice.firstUse(
            in: ReaderVocabulary.of(days: mature), days: mature, now: now
        )
        // Either new word is a true first use; the Book prefers the more
        // particular one, and both qualify. What must never happen is it
        // claiming a word the reader has written before.
        XCTAssertTrue(
            ["brackish", "reservoir"].contains(first?.word ?? ""),
            "picked \(first?.word ?? "nothing")"
        )
        XCTAssertEqual(first?.use.pageID, "new")

        // The same page in a young archive is the Book meeting the reader, not
        // the reader reaching for something new.
        let young = archive([page("new", "A brackish smell off the reservoir.", daysAgo: 0.5)])
        XCTAssertNil(ReaderVocabularyNotice.firstUse(
            in: ReaderVocabulary.of(days: young), days: young, now: now
        ))
    }

    func testTwoWordsThatKeepArrivingTogetherAreNoticed() {
        let days = archive([
            page("a", "The harbour and the lantern, both still.", daysAgo: 20),
            page("b", "A lantern over the harbour again.", daysAgo: 12),
            page("c", "The lantern, the harbour, nothing else awake.", daysAgo: 3),
            page("d", "Frost on the window before dawn.", daysAgo: 1)
        ])

        let pair = ReaderVocabularyNotice.pair(in: ReaderVocabulary.of(days: days))

        XCTAssertEqual([pair?.first, pair?.second].compactMap { $0 }.sorted(), ["harbour", "lantern"])
        XCTAssertEqual(pair?.together, 3)
        XCTAssertFalse(pair?.latestQuote.isEmpty ?? true, "the Book has to be able to show its evidence")
    }

    /// The Book's own braid is not the reader writing, and nothing may be
    /// claimed from an archive that has not said anything twice.
    func testNothingIsClaimedWithoutTheReadersOwnInk() {
        let braid = BookPage(
            id: "braid", type: .bookOfYou, createdAt: now.addingTimeInterval(-3600),
            promptText: "The Book of You",
            userInput: "The harbour and the lantern and the harbour and the lantern.",
            usedInBookOfYou: true, origin: .generated
        )
        let vocabulary = ReaderVocabulary.of(days: archive([braid]))

        XCTAssertTrue(vocabulary.isEmpty)
        XCTAssertNil(ReaderVocabularyNotice.pair(in: vocabulary))
        XCTAssertNil(ReaderVocabularyNotice.returned(in: vocabulary, now: now))
    }
}

/// The findings about *how* the reader writes rather than what they write.
extension ReaderVocabularyNoticeTests {
    /// The most delicate finding in the Book. It must never fire on a word the
    /// reader used twice and moved on from — that is a gap, not a habit ending.
    func testAWordOnlyGoesQuietAfterItWasAHabit() {
        let habit = archive([
            page("a", "The harbour again, and the lantern.", daysAgo: 200),
            page("b", "A lantern over the harbour.", daysAgo: 190),
            page("c", "The harbour, quiet this time.", daysAgo: 180),
            page("d", "Lantern light on the harbour wall.", daysAgo: 170),
            page("e", "Frost on the window before dawn.", daysAgo: 1)
        ])
        let vanished = ReaderVocabularyNotice.vanished(in: ReaderVocabulary.of(days: habit), now: now)
        XCTAssertEqual(vanished?.word, "harbour")
        XCTAssertGreaterThan(vanished?.uses ?? 0, 3)

        let passing = archive([
            page("a", "A kestrel over the reservoir.", daysAgo: 200),
            page("b", "The kestrel again, maybe.", daysAgo: 195),
            page("c", "Frost on the window before dawn.", daysAgo: 1)
        ])
        XCTAssertNil(
            ReaderVocabularyNotice.vanished(in: ReaderVocabulary.of(days: passing), now: now),
            "two uses and a silence is a gap, not a habit that ended"
        )
    }

    func testTheHourShiftsOnlyWhenBothHalvesActuallyLean() {
        var pages: [BookPage] = []
        for index in 0..<12 {
            pages.append(page("m\(index)", "The kettle clicked off before dawn.", daysAgo: Double(120 - index * 4)))
        }
        for index in 0..<12 {
            // Night ink, later in the archive.
            let at = now.addingTimeInterval(-Double(40 - index * 3) * 86_400)
            let night = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: at)!
            pages.append(BookPage(
                id: "n\(index)", type: .souvenir, createdAt: night,
                promptText: "Souvenir", userInput: "Down at the harbour, a lantern.",
                origin: .userAuthored,
                context: BookPageContextSnapshot(at: night, calendar: calendar)
            ))
        }
        let shift = ReaderVocabularyNotice.hourShift(days: archive(pages), now: now, calendar: calendar)
        XCTAssertEqual(shift?.recentPart, "night")
        XCTAssertNotEqual(shift?.earlierPart, shift?.recentPart)

        // A reader who has always written at the same hour has no shift.
        var steady: [BookPage] = []
        for index in 0..<24 {
            steady.append(page("s\(index)", "The kettle clicked off before dawn.", daysAgo: Double(120 - index * 4)))
        }
        XCTAssertNil(ReaderVocabularyNotice.hourShift(days: archive(steady), now: now, calendar: calendar))
    }

    func testLengthShiftNeedsARealChangeAndCarriesNoVerdict() {
        var pages: [BookPage] = []
        for index in 0..<12 {
            pages.append(page("long\(index)",
                "The kettle clicked off before the frost had finished leaving the window and the whole kitchen smelled of yesterday's bread and rain.",
                daysAgo: Double(120 - index * 4)))
        }
        for index in 0..<12 {
            pages.append(page("short\(index)", "Frost. Kettle. Quiet.", daysAgo: Double(40 - index * 3)))
        }
        let shift = ReaderVocabularyNotice.lengthShift(days: archive(pages))
        XCTAssertNotNil(shift)
        XCTAssertFalse(shift?.grew ?? true)
        XCTAssertLessThan(shift?.recentWords ?? 99, shift?.earlierWords ?? 0)

        var steady: [BookPage] = []
        for index in 0..<24 {
            steady.append(page("e\(index)", "The kettle clicked off before dawn today.", daysAgo: Double(120 - index * 4)))
        }
        XCTAssertNil(
            ReaderVocabularyNotice.lengthShift(days: archive(steady)),
            "a steady hand is not a finding"
        )
    }

    func testTheSameDayInAnEarlierYearIsFound() {
        let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        let anniversary = BookPage(
            id: "then", type: .souvenir, createdAt: lastYear,
            promptText: "Souvenir", userInput: "A kestrel over the reservoir, holding still.",
            origin: .userAuthored
        )
        let found = ReaderVocabularyNotice.sameDayLastYear(
            days: archive([anniversary, page("now", "Frost again.", daysAgo: 0.2)]),
            now: now, calendar: calendar
        )
        XCTAssertEqual(found?.yearsAgo, 1)
        XCTAssertTrue(found?.quote.contains("kestrel") ?? false)

        XCTAssertNil(ReaderVocabularyNotice.sameDayLastYear(
            days: archive([page("recent", "Frost again.", daysAgo: 3)]),
            now: now, calendar: calendar
        ))
    }
}
