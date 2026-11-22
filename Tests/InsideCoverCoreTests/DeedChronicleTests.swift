import XCTest
@testable import InsideCoverCore

/// Phase 4: the deed chronicle. What the reader did, read from the archive;
/// the month told as deeds; titles each tied to a deed and a day.
final class DeedChronicleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func days(_ pages: [BookPage]) -> [BookDay] { [BookDay(id: "archive", date: date(10, 1), pages: pages)] }

    private func tree(at: Date) -> BookPage {
        BookPage(id: "tree-page", type: .spell, createdAt: at, promptText: "A spell",
                 userInput: "The tree is called Gerald.", tags: ["spell", "spell:name-a-tree"])
    }

    private func errand(_ id: String, title: String, words: String, at: Date) -> BookPage {
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: id, title: title, invitation: "Go on.", proofPrompt: "One sentence.",
            facets: [.exactAttention], sourceTags: [], hasWrittenProof: true, hasVisualProof: false,
            completedAt: at, wasPromptedByBook: true)
        return BookPage(id: id, type: .wonderCompass, createdAt: at, promptText: title, userInput: words,
                        livedQuestReceipt: receipt)
    }

    private func diary(_ words: String, at: Date, id: String) -> BookPage {
        BookPage(id: id, type: .diary, createdAt: at, promptText: "Diary", userInput: words)
    }

    private func withGerald(_ pages: [BookPage]) throws -> [BookPage] {
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar)
            .first { $0.key == "page:tree-page" })
        return pages + [try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days(pages), now: date(10, 2)))]
    }

    func testDeedsComeOnlyFromPagesTheReaderPutSomethingInto() throws {
        let generated = BookPage(id: "book", type: .spell, createdAt: date(10, 3), promptText: "A spell",
                                 userInput: "The tree is called Gerald.", tags: ["spell:name-a-tree"], origin: .generated)
        var pages = try withGerald([tree(at: date(10, 1))])
        pages += [generated, errand("chair-held", title: "The Chair's Opinion", words: "It thinks I'm late.", at: date(10, 9))]
        let deeds = DeedChronicle.deeds(days: days(pages))
        XCTAssertFalse(deeds.contains { $0.pageID == "book" })
        XCTAssertEqual(deeds.map(\.kind), [.neighbourNamed, .workingReturned], "a spell that named a Neighbour is told once")
        let named = try XCTUnwrap(deeds.first { $0.kind == .neighbourNamed })
        XCTAssertEqual(named.phrase, "told a tree it was called Gerald")
        XCTAssertEqual(named.date, date(10, 1), "a Neighbour is dated by the Page it was named on")
        XCTAssertEqual(named.sentence, "The tree is called Gerald.")
    }

    func testTheMonthIsToldAsDeedsWithTheReaderAsTheOneWhoDidThem() throws {
        var pages = try withGerald([tree(at: date(10, 1))])
        pages += [
            diary("Gerald dropped conkers on me.", at: date(10, 5), id: "d1"),
            diary("Waved at Gerald.", at: date(10, 12), id: "d2"),
            errand("chair-held", title: "The Chair's Opinion", words: "It thinks I'm late.", at: date(10, 9)),
            errand("tiny-kindness", title: "The Lost Property Office", words: "A glove on a railing.", at: date(10, 20)),
            diary("Nothing about anybody.", at: date(11, 2), id: "november")
        ]
        let paragraphs = DeedChronicle.told(
            deeds: DeedChronicle.deeds(days: days(pages)), days: days(pages),
            from: date(10, 1).addingTimeInterval(-43_200), to: date(10, 31).addingTimeInterval(43_200),
            periodName: "October")
        XCTAssertEqual(paragraphs.first, "In October you told a tree it was called Gerald. Gerald was in your Pages three times.")
        XCTAssertTrue(paragraphs.contains { $0.contains("You went out on two errands and came back from every one with something.") }, "\(paragraphs)")
        XCTAssertTrue(paragraphs.last?.contains("\u{201C}The tree is called Gerald.\u{201D}") == true)
        XCTAssertFalse(paragraphs.joined().contains("the Book"))
    }

    func testAnEmptyMonthTellsNothing() {
        let pages = [diary("Just a day.", at: date(10, 4), id: "d")]
        XCTAssertTrue(DeedChronicle.told(deeds: DeedChronicle.deeds(days: days(pages)), days: days(pages),
                                         from: date(10, 1), to: date(10, 31), periodName: "October").isEmpty)
    }

    func testTitlesNameTheDeedAndTheDay() throws {
        let pages = try withGerald([tree(at: date(5, 14))])
        let titles = DeedChronicle.titles(deeds: DeedChronicle.deeds(days: days(pages)), calendar: calendar)
        let namer = try XCTUnwrap(titles.first { $0.id == "namer-of-trees" })
        XCTAssertEqual(namer.title, "Namer of Trees")
        XCTAssertEqual(namer.earnedAt, date(5, 14))
        XCTAssertEqual(namer.because, "You told a tree it was called Gerald, in May 2026.")
        XCTAssertFalse(titles.contains { $0.id == "who-went-out" })
    }

    func testATitleForACountIsEarnedOnTheDayTheCountWasReached() throws {
        let pages = (1...10).map { errand("errand-\($0)", title: "Errand", words: "Did it.", at: date(9, $0)) }
        let titles = DeedChronicle.titles(deeds: DeedChronicle.deeds(days: days(pages)), calendar: calendar)
        let out = try XCTUnwrap(titles.first { $0.id == "who-went-out" })
        XCTAssertEqual(out.earnedAt, date(9, 10))
        XCTAssertNil(DeedChronicle.titles(deeds: DeedChronicle.deeds(days: days(Array(pages.prefix(9)))), calendar: calendar)
            .first { $0.id == "who-went-out" })
    }

    func testTheMonthlyEditionCarriesTheDeedsLeaf() throws {
        let pages = try withGerald([tree(at: date(10, 1))])
        let section = MonthlyEditionBuilder.deedsSection(
            days: days(pages), start: date(10, 1).addingTimeInterval(-43_200),
            end: date(10, 31).addingTimeInterval(39_600), calendar: calendar)
        XCTAssertEqual(section.items.first?.title, "October, Told as Deeds")
        XCTAssertEqual(section.items.last?.title, "A Title")
        XCTAssertTrue(section.items.last?.body.hasPrefix("Namer of Trees. You told a tree it was called Gerald") == true)
        let empty = MonthlyEditionBuilder.deedsSection(days: days([]), start: date(10, 1), end: date(10, 31), calendar: calendar)
        XCTAssertTrue(empty.items.isEmpty)
    }

    func testTheReadersSheetShowsTitles() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = days(try withGerald([tree(at: date(5, 14))]))
        let sheet = ReadersSheetBuilder.build(inputs: inputs, now: date(10, 1))
        XCTAssertEqual(sheet.titles.map(\.id), ["namer-of-trees"])
        let you = sheet.readerFacingSections.first { $0.id == "you" }?.text ?? ""
        XCTAssertTrue(you.contains("Namer of Trees."), you)
    }
}
