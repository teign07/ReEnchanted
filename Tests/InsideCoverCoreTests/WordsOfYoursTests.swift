import XCTest
@testable import InsideCoverCore

final class WordsOfYoursTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func at(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    private func passage(_ id: String, _ day: Int, _ hour: Int, _ text: String) -> WordsOfYours.Passage {
        WordsOfYours.Passage(pageID: id, date: at(day, hour), texts: [text])
    }

    func testCountsWordsAcrossPagesWithTheirLines() {
        let lexicon = WordsOfYours.build(passages: [
            passage("b", 2, 7, "The kettle clicked off. Tea by the window."),
            passage("a", 1, 7, "The kettle sang before the frost left the window."),
            passage("c", 3, 7, "Kettle again, and tea, and the window fogged.")
        ], calendar: calendar)
        let kettle = lexicon.entry(for: "Kettle,")
        XCTAssertEqual(kettle?.count, 3)
        XCTAssertEqual(kettle?.first.pageID, "a", "the first sighting is the earliest, whatever order the archive gave")
        XCTAssertEqual(kettle?.days.count, 3)
        XCTAssertNil(lexicon.entry(for: "the"), "little words aren't kept")
        XCTAssertEqual(lexicon.entry(for: "kettles")?.word, "kettle", "a plural finds the singular")
    }

    func testTheBooksEntryIsCountedAndPlainSpoken() {
        let lexicon = WordsOfYours.build(passages: [
            passage("a", 1, 6, "The kettle and the tea before work."),
            passage("b", 2, 7, "Kettle on, tea in the blue cup."),
            passage("c", 3, 6, "Forgot the kettle. Tea went cold."),
            passage("d", 4, 7, "Kettle, tea, the radio quietly.")
        ], calendar: calendar)
        let entry = BookDictionary.entry(for: "kettle", in: lexicon, excludingPage: "d", now: at(5, 9), calendar: calendar)
        XCTAssertEqual(entry.headword, "kettle")
        XCTAssertTrue(entry.senses.contains("Nearly always before eight in the morning."), "\(entry.senses)")
        XCTAssertTrue(entry.senses.contains { $0.contains("*tea*") }, "\(entry.senses)")
        XCTAssertEqual(entry.first?.pageID, "a")
        XCTAssertFalse(entry.echoes.contains { $0.pageID == "d" }, "the leaf the reader is on isn't its own echo")
        XCTAssertFalse(entry.echoes.contains { $0.pageID == "a" }, "the first time is shown once, as the first time")
        for sense in entry.senses {
            XCTAssertFalse(sense.contains("the Book"), "the Book is the narrator: \(sense)")
            XCTAssertFalse(sense.lowercased().contains("perhaps") || sense.lowercased().contains("might suggest"), sense)
        }
    }

    func testAWordNeverKeptSaysSo() {
        let entry = BookDictionary.entry(for: "heron", in: WordsOfYours.build(passages: [], calendar: calendar),
                                         now: at(1, 9), calendar: calendar)
        XCTAssertTrue(entry.echoes.isEmpty)
        XCTAssertTrue(entry.isAlive, "a heron is alive")
        XCTAssertTrue(entry.senses.contains("It's alive. I can tell."))
    }

    func testLooseWordsAreTheSameAllDayAndRare() {
        let text = "A heron on the canal wall, and the lantern swinging over the jetty."
        let first = LooseWords.pick(in: text, leafKey: "page-1", dayID: "2026-10-31")
        XCTAssertEqual(first, LooseWords.pick(in: text, leafKey: "page-1", dayID: "2026-10-31"))
        var loose = 0
        for day in 1...200 {
            if LooseWords.pick(in: text, leafKey: "page-1", dayID: "day-\(day)") != nil { loose += 1 }
        }
        XCTAssertGreaterThan(loose, 10, "it does happen")
        XCTAssertLessThan(loose, 120, "it isn't every day")
        if let pick = LooseWords.pick(in: text, leafKey: "page-1", dayID: "2026-10-31") {
            XCTAssertEqual((text as NSString).substring(with: pick.range).lowercased(), pick.key)
        }
    }

    func testPassagesSkipSimulatedPages() {
        var day = BookDay(id: "2026-03-01", date: at(1, 0), pages: [])
        day.pages.append(BookPage(id: "real", type: .diary, promptText: "", userInput: "The kettle sang.", tags: [],
                                  sourceID: "", origin: .userAuthored))
        day.pages.append(BookPage(id: "fake", type: .diary, promptText: "", userInput: "The kettle sang.", tags: [],
                                  sourceID: "", origin: .simulated))
        let passages = WordsOfYours.passages(in: [day])
        XCTAssertEqual(passages.map(\.pageID), ["real"])
    }
}
