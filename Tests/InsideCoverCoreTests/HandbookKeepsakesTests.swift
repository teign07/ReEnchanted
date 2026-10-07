import XCTest
@testable import InsideCoverCore

final class HandbookKeepsakesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }

    private func day(_ n: Int, words: [String] = [], braid: Bool = false, photos: Int = 0) -> BoundDay {
        let when = date(n)
        let braids = braid
            ? [MonthlyEditionItem(id: "b\(n)", kind: .page, title: "Night \(n)", body: "Body", date: when, pageType: .bookOfYou, sourceID: nil, mediaAssets: [], tags: [])]
            : []
        let shots = (0..<photos).map {
            MonthlyEditionItem(id: "p\(n)-\($0)", kind: .image, title: "Photo", body: "", date: when, pageType: .plainPage, sourceID: nil, mediaAssets: [], tags: [])
        }
        return BoundDay(
            id: "d\(n)", date: when,
            almanac: BoundDayAlmanac(moonName: "Waxing Gibbous", moonIlluminated: 0.7, moonAgeDays: 10, skyWords: [], feast: nil),
            scenes: [], clippings: [], castLines: [], braids: braids, photos: shots, words: words, keeps: [], specimens: []
        )
    }

    private let sentences = [
        "The plastic lemon seltzer bottle was cool in the hand.",
        "Amanda made the coffee and we talked about nothing at all.",
        "The porch light flickered twice and then decided to stay on.",
        "I walked the long way home just to see the leaves.",
        "There was a heron standing in the car park like it owned it.",
        "The first real cold morning of the year, and I was glad.",
        "Somebody left a pumpkin on the wall with a very kind face.",
        "We ate soup standing up because the table was full of mail.",
        "The moon came up behind the church like a coin in a fountain.",
        "I finally answered the letter I had been carrying around."
    ]

    private func month(_ count: Int = 10) -> [BoundDay] {
        (0..<count).map { day(2 + $0 * 3, words: [sentences[$0 % sentences.count]], braid: $0 % 2 == 0, photos: $0 % 3 == 0 ? 1 : 0) }
    }

    private func page(_ text: String, id: String) -> BookPage {
        BookPage(id: id, type: .diary, createdAt: date(5), promptText: "p", userInput: text)
    }

    // MARK: Pixels

    func testEveryDayOfTheMonthIsAPixelAndAKeptDayIsLit() throws {
        let pixels = try XCTUnwrap(HandbookKeepsakesBuilder.pixels(days: month(), monthStart: date(1), monthName: "October", year: 2026, calendar: calendar))
        XCTAssertEqual(pixels.levels.count, 31)
        XCTAssertEqual(pixels.moon.count, 31)
        XCTAssertEqual(pixels.leadingBlanks, 4, "October 2026 starts on a Thursday; a Sunday-first grid leaves four blanks")
        XCTAssertGreaterThan(pixels.levels[1], 0, "the 2nd was kept")
        XCTAssertEqual(pixels.levels[0], 0, "the 1st was not")
        XCTAssertEqual(pixels.keptDays, pixels.levels.filter { $0 > 0 }.count)
        XCTAssertTrue(pixels.levels.allSatisfy { (0...4).contains($0) })
        XCTAssertNotNil(pixels.busiestDay)
        XCTAssertEqual(pixels.weekdayLetters.count, 7)
    }

    func testLongestRunCountsConsecutiveKeptDays() throws {
        let days = [day(3, words: [sentences[0]]), day(4, words: [sentences[1]]), day(5, words: [sentences[2]]), day(9, words: [sentences[3]])]
        let pixels = try XCTUnwrap(HandbookKeepsakesBuilder.pixels(days: days, monthStart: date(1), monthName: "October", year: 2026, calendar: calendar))
        XCTAssertEqual(pixels.longestRun, 3)
    }

    func testAMonthOfNothingHasNoPixelsToInvent() {
        XCTAssertNil(HandbookKeepsakesBuilder.pixels(days: [day(3)], monthStart: date(1), monthName: "October", year: 2026, calendar: calendar))
    }

    func testPassportStampsOnlyTheDaysKept() throws {
        let passport = try XCTUnwrap(HandbookKeepsakesBuilder.passport(days: month(), monthStart: date(1), monthName: "October", year: 2026, calendar: calendar))
        XCTAssertEqual(passport.daysInMonth, 31)
        XCTAssertEqual(passport.keptDays, month().map { calendar.component(.day, from: $0.date) }.sorted())
        XCTAssertNil(HandbookKeepsakesBuilder.passport(days: [day(3, words: [sentences[0]])], monthStart: date(1), monthName: "October", year: 2026, calendar: calendar), "one stamp is not a passport")
    }

    // MARK: Found poem

    func testThePoemIsTheReadersOwnSentencesInTheOrderTheyWereWritten() throws {
        let days = month()
        let lines = HandbookKeepsakesBuilder.poemCandidates(days: days, calendar: calendar)
        let poem = try XCTUnwrap(HandbookKeepsakesBuilder.poem(lines: lines, pages: [], monthName: "October", seed: "2026-10"))
        let printed = poem.stanzas.flatMap { $0 }.map(\.text)
        XCTAssertEqual(printed.count, 10)
        XCTAssertTrue(printed.allSatisfy { line in days.flatMap(\.words).contains(line) }, "not one word of it is the Book's")
        XCTAssertEqual(printed, lines.map(\.text), "in the order the month happened")
        XCTAssertEqual(poem.stanzas.flatMap { $0 }.first?.dateLabel, "Oct 2")
        XCTAssertTrue(poem.stanzas.allSatisfy { (2...5).contains($0.count) }, "no stanza of one")
        XCTAssertEqual(poem.title, "October, Said Plainly")
    }

    func testAThinMonthMakesNoPoemRatherThanAPoorOne() {
        let lines = HandbookKeepsakesBuilder.poemCandidates(days: Array(month().prefix(4)), calendar: calendar)
        XCTAssertNil(HandbookKeepsakesBuilder.poem(lines: lines, pages: [], monthName: "October", seed: "s"))
    }

    func testTheTitleComesFromWhatTheMonthKeptReturningTo() throws {
        let pages = [
            page("Coffee on the porch before work.", id: "1"), page("Another coffee, another porch, the same dog.", id: "2"),
            page("The porch light again, and a cold coffee.", id: "3")
        ]
        let lines = HandbookKeepsakesBuilder.poemCandidates(days: month(), calendar: calendar)
        let poem = try XCTUnwrap(HandbookKeepsakesBuilder.poem(lines: lines, pages: pages, monthName: "October", seed: "s"))
        XCTAssertTrue(poem.title.hasPrefix("On "), poem.title)
        XCTAssertTrue(poem.title.lowercased().contains("coffee") || poem.title.lowercased().contains("porch"), poem.title)
    }

    func testLinesThatAreNotReadableAsLinesAreNotUsed() {
        let days = [day(2, words: ["https://example.com/something/long/enough/to/qualify"]),
                    day(3, words: ["Too short."]),
                    day(4, words: ["12345 67890 12345 67890 12345 67890 12345 67890 abc def"]),
                    day(5, words: [String(repeating: "word ", count: 30)])]
        XCTAssertTrue(HandbookKeepsakesBuilder.poemCandidates(days: days, calendar: calendar).isEmpty)
    }

    // MARK: Cut-outs

    func testTheBookmarksAreThreeOfTheReadersLinesAndNothingElseIsCutOut() throws {
        let lines = HandbookKeepsakesBuilder.poemCandidates(days: month(), calendar: calendar)
        let cut = try XCTUnwrap(HandbookKeepsakesBuilder.cutouts(lines: lines, days: month(), monthName: "October", seed: "2026-10"))
        XCTAssertEqual(cut.bookmarks.count, 3)
        XCTAssertEqual(Set(cut.bookmarks.map(\.line)).count, 3, "no line twice")
        XCTAssertTrue(cut.bookmarks.allSatisfy { b in lines.contains { $0.text == b.line } })
        XCTAssertTrue(cut.bookmarks.allSatisfy { $0.line.count <= 78 })
        XCTAssertNil(HandbookKeepsakesBuilder.cutouts(lines: Array(lines.prefix(2)), days: month(), monthName: "October", seed: "s"))
    }

    // MARK: Questions, eight words, capsule

    func testQuestionsAreSeededByTheMonthAndTwoAreTheReadersOwn() throws {
        let pages = [
            page("Walked past the lighthouse and thought about lighthouse keepers.", id: "1"),
            page("The lighthouse again, with a flask of tea and a sandwich.", id: "2"),
            page("A sandwich at the lighthouse, and the tea went cold.", id: "3")
        ]
        let q = try XCTUnwrap(HandbookKeepsakesBuilder.questions(pages: pages, seed: "2026-10"))
        XCTAssertTrue(q.items.contains { $0.contains("lighthouse") }, "\(q.items)")
        XCTAssertLessThanOrEqual(q.items.count, 8)
        XCTAssertEqual(q.items, HandbookKeepsakesBuilder.questions(pages: pages, seed: "2026-10")?.items, "a reprint is the same book")
        XCTAssertNotEqual(q.items, HandbookKeepsakesBuilder.questions(pages: pages, seed: "2026-11")?.items, "another month asks other things")
    }

    func testAQuestionNeverPutsAPersonsNameInAMouth() throws {
        let pages = [page("Went to see Amanda today and Amanda made tea.", id: "1"), page("Amanda was off, so Amanda and I walked.", id: "2")]
        let q = try XCTUnwrap(HandbookKeepsakesBuilder.questions(pages: pages, seed: "s"))
        XCTAssertFalse(q.items.contains { $0.contains("Amanda") }, "\(q.items)")
    }

    func testEightWordsAreTheReadersAndNeedAtLeastSix() {
        XCTAssertNil(HandbookKeepsakesBuilder.eightWords(pages: [page("Just a few words here.", id: "1")], seed: "s"))
        let texts = [
            "The lantern swung over the harbour while the kettle sang.", "A lantern in the window, and the harbour was quiet.",
            "The kettle again, and thunder over the mountains.", "Mountains behind the harbour, and a heron in the shallows.",
            "The heron stood by the kettle of the harbour, thunder rolling.", "Thunder, lantern, mountains, shallows.",
            "Biscuits, orchard, bicycle, and a borrowed umbrella.", "An umbrella and a bicycle by the orchard gate."
        ]
        let pages = texts.enumerated().map { page($0.element, id: "\($0.offset)") }
        let eight = HandbookKeepsakesBuilder.eightWords(pages: pages, seed: "s")
        XCTAssertNotNil(eight)
        XCTAssertGreaterThanOrEqual(eight?.words.count ?? 0, 6)
        XCTAssertLessThanOrEqual(eight?.words.count ?? 9, 8)
    }

    func testTheCapsuleOpensNextYear() throws {
        let capsule = try XCTUnwrap(HandbookKeepsakesBuilder.capsule(monthName: "October", year: 2026, seed: "2026-10"))
        XCTAssertEqual(capsule.openYear, 2027)
        XCTAssertEqual(capsule.prompts.count, 3)
    }

    // MARK: The whole

    func testAMonthBuildsEveryKeepsakeItHasMaterialFor() throws {
        let pages = month().flatMap { d in d.words.enumerated().map { page($0.element, id: "\(d.id)-\($0.offset)") } }
        let keepsakes = try XCTUnwrap(HandbookKeepsakesBuilder.make(days: month(), pages: pages, seed: "2026-10", calendar: calendar))
        XCTAssertNotNil(keepsakes.pixels)
        XCTAssertNotNil(keepsakes.poem)
        XCTAssertNotNil(keepsakes.passport)
        XCTAssertNotNil(keepsakes.cutouts)
        XCTAssertNotNil(keepsakes.capsule)
        XCTAssertEqual(keepsakes, HandbookKeepsakesBuilder.make(days: month(), pages: pages, seed: "2026-10", calendar: calendar))
    }

    func testNothingKeptMeansNoKeepsakesAtAll() {
        XCTAssertNil(HandbookKeepsakesBuilder.make(days: [day(3)], pages: [], seed: "s", calendar: calendar)?.pixels)
        XCTAssertNil(HandbookKeepsakesBuilder.make(days: [], pages: [], seed: "s", calendar: calendar))
    }

    func testKeepsakesAreGivenUpLastAndOneAtATime() {
        var keepsakes = HandbookKeepsakes(
            pixels: HandbookKeepsakes.Pixels(monthName: "October", year: 2026, leadingBlanks: 0, levels: [1], moon: [0.5], keptDays: 1,
                                             longestRun: 1, busiestDay: 1, busiestCount: 1, weekdayLetters: []),
            capsule: HandbookKeepsakes.Capsule(monthName: "October", openYear: 2027, prompts: [])
        )
        XCTAssertTrue(keepsakes.removeOne())
        XCTAssertNil(keepsakes.capsule, "the capsule goes first")
        XCTAssertNotNil(keepsakes.pixels)
        XCTAssertTrue(keepsakes.removeOne())
        XCTAssertTrue(keepsakes.isEmpty)
        XCTAssertFalse(keepsakes.removeOne())
    }

    func testASentenceSaidOnTwoDaysIsOneLine() {
        let same = "Clear and sharp. My breath showed at the bus stop."
        let lines = HandbookKeepsakesBuilder.poemCandidates(days: [day(2, words: [same]), day(5, words: [same]), day(9, words: [sentences[1]])], calendar: calendar)
        XCTAssertEqual(lines.map(\.text), [same, sentences[1]])
    }

    // MARK: Photographs

    private func photoDay(_ n: Int, shots: Int, braid: String = "A Night") -> BoundDay {
        var d = day(n, words: [sentences[n % sentences.count]], braid: true)
        d.braids[0].title = braid
        d.photos = (0..<shots).map { index in
            MonthlyEditionItem(id: "ph\(n)-\(index)", kind: .image, title: "Photo", body: "", date: date(n), pageType: .plainPage, sourceID: nil,
                               mediaAssets: [BookPageMediaAsset(kind: .photoLibraryAsset, reference: "lib-\(n)-\(index)", caption: "", sourceID: "s", metadata: [:])], tags: [])
        }
        return d
    }

    func testThePhotographsSpreadNeedsThreeAndFramesTheBusiestDay() throws {
        XCTAssertNil(HandbookKeepsakesBuilder.photos(days: [photoDay(3, shots: 1), photoDay(9, shots: 1)], monthName: "October", calendar: calendar))
        let days = [photoDay(3, shots: 1), photoDay(9, shots: 2, braid: "The Blue Door"), photoDay(14, shots: 1)]
        let photos = try XCTUnwrap(HandbookKeepsakesBuilder.photos(days: days, monthName: "October", calendar: calendar))
        XCTAssertEqual(photos.shots.count, 4)
        XCTAssertEqual(photos.shots.map(\.dateLabel), ["Oct 3", "Oct 9", "Oct 9", "Oct 14"], "in the order they were taken")
        XCTAssertEqual(photos.shots[photos.featuredIndex].title, "The Blue Door", "the busiest day's photograph is the one framed")
    }

    func testAPhotographWhoseFileIsGoneIsLeftOutAndNoneIsShownTwice() {
        var missing = photoDay(3, shots: 1)
        missing.photos[0].mediaAssets = [BookPageMediaAsset(kind: .renderedImageFile, reference: "/gone/old.png", caption: "", sourceID: "s", metadata: [:])]
        var twice = photoDay(5, shots: 2)
        twice.photos[1].mediaAssets = twice.photos[0].mediaAssets
        let photos = HandbookKeepsakesBuilder.photos(days: [missing, twice, photoDay(7, shots: 1), photoDay(9, shots: 1)], monthName: "October", calendar: calendar)
        XCTAssertEqual(photos?.shots.count, 3, "the missing file and the duplicate are dropped")
    }

    // MARK: Superlatives

    func testSuperlativesAreEarnedNotInvented() throws {
        XCTAssertNil(HandbookKeepsakesBuilder.superlatives(days: [day(3, words: [sentences[0]])], pages: [], monthName: "October", calendar: calendar))
        let days = month(10)
        var pages: [BookPage] = []
        for (index, d) in days.enumerated() {
            var p = page(sentences[index % sentences.count] + " coffee", id: "p\(index)")
            p.createdAt = calendar.date(bySettingHour: index < 6 ? 21 : 8, minute: 10, second: 0, of: d.date)!
            pages.append(p)
        }
        let supers = try XCTUnwrap(HandbookKeepsakesBuilder.superlatives(days: days, pages: pages, monthName: "October", calendar: calendar))
        XCTAssertGreaterThanOrEqual(supers.awards.count, 4)
        XCTAssertLessThanOrEqual(supers.awards.count, 8)
        let hour = try XCTUnwrap(supers.awards.first { $0.title.contains("Writing at") })
        XCTAssertEqual(hour.headline, "9 p.m.")
        XCTAssertTrue(supers.awards.allSatisfy { !$0.headline.isEmpty && !$0.detail.isEmpty })
        XCTAssertFalse(supers.awards.contains { ["hinge", "ritual"].contains(where: $0.detail.lowercased().contains) })
    }

    func testTheLongestQuietIsTheLongestRunOfDaysWithNothingKept() throws {
        let days = [day(2, words: [sentences[0]]), day(3, words: [sentences[1]]), day(4, words: [sentences[2]]), day(10, words: [sentences[3]]),
                    day(11, words: [sentences[4]]), day(12, words: [sentences[5]])]
        let quiet = try XCTUnwrap(HandbookKeepsakesBuilder.longestQuiet(days: days, calendar: calendar))
        XCTAssertEqual(quiet.length, 5)
        XCTAssertEqual(calendar.component(.day, from: quiet.start), 5)
        XCTAssertEqual(calendar.component(.day, from: quiet.end), 9)
        XCTAssertNil(HandbookKeepsakesBuilder.longestQuiet(days: [day(3, words: [sentences[0]]), day(4, words: [sentences[1]])], calendar: calendar))
    }

    func testTheMonthAtAGlanceOutlastsTheExtras() {
        var k = HandbookKeepsakes(
            pixels: HandbookKeepsakes.Pixels(monthName: "October", year: 2026, leadingBlanks: 0, levels: [1], moon: [0.5], keptDays: 1,
                                             longestRun: 1, busiestDay: 1, busiestCount: 1, weekdayLetters: []),
            passport: HandbookKeepsakes.Passport(monthName: "October", year: 2026, daysInMonth: 31, keptDays: [1, 2]),
            questions: HandbookKeepsakes.Questions(items: ["q"]),
            capsule: HandbookKeepsakes.Capsule(monthName: "October", openYear: 2027, prompts: [])
        )
        XCTAssertTrue(k.removeExtra())
        XCTAssertTrue(k.removeExtra())
        XCTAssertFalse(k.removeExtra(), "no extras left")
        XCTAssertNotNil(k.pixels)
        XCTAssertNotNil(k.passport)
        XCTAssertTrue(k.removeCore())
        XCTAssertNil(k.passport)
        XCTAssertNotNil(k.pixels, "pixels are the very last to go")
    }

    func testTheWordOfTheMonthIsNeverAPersonsName() {
        let days = month(10)
        var pages: [BookPage] = []
        for (i, d) in days.enumerated() {
            var p = page("Amanda and I had coffee again, Amanda talked about the garden.", id: "n\(i)")
            p.createdAt = d.date
            pages.append(p)
        }
        let supers = HandbookKeepsakesBuilder.superlatives(days: days, pages: pages, monthName: "October", calendar: calendar)
        let word = supers?.awards.first { $0.title == "Word of the Month" }
        XCTAssertNotEqual(word?.headline, "Amanda")
    }

    // MARK: Index

    func testTheIndexListsOrdinaryWordsWithTheDaysTheyCameUpAndNeverAName() throws {
        var pages: [BookPage] = []
        let words = ["coffee", "porch", "lantern", "harbour", "kettle", "thunder", "orchard", "bicycle", "umbrella", "garden"]
        for (i, d) in month(10).enumerated() {
            for w in words.prefix(8 + (i % 2)) where (i + w.count) % 2 == 0 || i < 4 {
                pages.append(page("Amanda and I talked about the \(w) again, \(w) and Amanda.", id: "\(i)-\(w)").withDate(d.date))
            }
        }
        let index = try XCTUnwrap(HandbookKeepsakesBuilder.index(days: month(10), pages: pages, monthName: "October", calendar: calendar))
        XCTAssertGreaterThanOrEqual(index.words.count, 8)
        XCTAssertFalse(index.words.contains { $0.term.lowercased() == "amanda" }, "a person's name is never an entry")
        XCTAssertEqual(index.words.map(\.term), index.words.map(\.term).sorted(), "alphabetical, like an index")
        XCTAssertTrue(index.words.allSatisfy { $0.locator.contains(",") || Int($0.locator.replacingOccurrences(of: "…", with: "")) != nil })
    }

    func testAMonthThatReturnedToNothingHasNoIndex() {
        XCTAssertNil(HandbookKeepsakesBuilder.index(days: month(10), pages: [page("A single page about one thing.", id: "x")], monthName: "October", calendar: calendar))
    }
}

private extension BookPage {
    func withDate(_ date: Date) -> BookPage { var copy = self; copy.createdAt = date; return copy }
}

final class BackCoverCopyTests: XCTestCase {
    func testTheBackCoverIsAboutThisReadersMonthAndSaysOnlyWhatItCounted() {
        let copy = BackCoverCopy.make(readerName: "Wren", monthName: "October", keptPages: 39, nights: 9, scenes: 22, photos: 3, hasIndex: true, seed: "x")
        XCTAssertEqual(copy.contains, ["39 kept pages", "9 braided nights", "22 scenes from the Labyrinth", "3 photographs", "an index of the month"])
        XCTAssertTrue(copy.onlyCopy.contains("Wren"))
        XCTAssertFalse(copy.blurb.isEmpty)
    }

    func testNothingIsClaimedThatTheMonthDidNotHave() {
        let copy = BackCoverCopy.make(readerName: "", monthName: "October", keptPages: 1, nights: 0, scenes: 0, photos: 0, hasIndex: false, seed: "x")
        XCTAssertEqual(copy.contains, ["1 kept page"])
        XCTAssertFalse(copy.blurb.contains("0 nights"))
        XCTAssertTrue(copy.onlyCopy.contains("you"), "no name means no invented one")
    }

    func testTheBlurbIsTheBooksVoiceAndNeverTheBannedWords() {
        for seed in ["a", "b", "c", "d", "e", "f"] {
            let copy = BackCoverCopy.make(readerName: "Wren", monthName: "October", keptPages: 39, nights: 9, scenes: 22, photos: 3, hasIndex: true, seed: seed)
            for text in [copy.blurb, copy.onlyCopy] {
                XCTAssertFalse(["hinge", "ritual"].contains(where: text.lowercased().contains), text)
            }
        }
    }

    func testTheSameBookAlwaysSaysTheSameThing() {
        let a = BackCoverCopy.make(readerName: "Wren", monthName: "October", keptPages: 39, nights: 9, scenes: 22, photos: 3, hasIndex: true, seed: "k")
        XCTAssertEqual(a, BackCoverCopy.make(readerName: "Wren", monthName: "October", keptPages: 39, nights: 9, scenes: 22, photos: 3, hasIndex: true, seed: "k"))
    }
}
