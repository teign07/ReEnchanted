import XCTest
@testable import InsideCoverCore

/// Phase 7, core half: Gemma's two small jobs about Neighbours, tested with a
/// fake teller. What it says is checked; the deterministic line is the
/// fallback; nothing it names is taken unless the reader wrote it.
final class NeighbourThinkingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func gerald() throws -> (Neighbour, [BookDay]) {
        let page = BookPage(id: "tree-page", type: .spell, createdAt: now.addingTimeInterval(-20 * 86_400),
                            promptText: "A spell", userInput: "The tree is called Gerald and he hums at night.",
                            tags: ["spell", "spell:name-a-tree"])
        let days = [BookDay(id: "archive", date: now, pages: [page])]
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days, calendar: calendar).first)
        let record = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days, now: now))
        let all = [BookDay(id: "archive", date: now, pages: [page, record])]
        return (try XCTUnwrap(Neighbours.register(days: all).first), all)
    }

    func testThePromptIsSmallAndHoldsOnlyFacts() throws {
        let (neighbour, days) = try gerald()
        let ask = NeighbourThinking.howAreTheyPrompt(for: neighbour, days: days, now: now, calendar: calendar)
        XCTAssertLessThan(ask.prompt.split(whereSeparator: \.isWhitespace).count, 400)
        XCTAssertTrue(ask.prompt.contains("The reader once wrote: The tree is called Gerald and he hums at night."))
        XCTAssertTrue(ask.prompt.contains("Say Gerald in it."))
    }

    func testAGoodLineIsShown() throws {
        let (neighbour, days) = try gerald()
        let line = NeighbourThinking.howAreThey(neighbour, days: days, now: now, calendar: calendar) { _, _ in
            "Gerald's been holding a crow's nest all week and won't say whose it is."
        }
        XCTAssertEqual(line, "Gerald's been holding a crow's nest all week and won't say whose it is.")
    }

    func testALineThatInventsWhatTheReaderDidOrFeltFallsBack() throws {
        let (neighbour, days) = try gerald()
        let fallback = Neighbours.line(for: neighbour, days: days, now: now, calendar: calendar)
        for bad in [
            "Gerald misses you because you went away.",
            "You felt sad when Gerald lost his leaves.",
            "Gerald is waiting.\nAnd so is the moon.",
            "Gerald hums at night and the tree is called Gerald.",        // copies the reader
            "Gerald and Maureen are best friends now.",                   // a name nobody gave
            "Gerald is fine; the wind is not.",                           // a semicolon
            "The oak is thinking about the frost.",                       // never says the name
            "The Book thinks Gerald is lonely."
        ] {
            let line = NeighbourThinking.howAreThey(neighbour, days: days, now: now, calendar: calendar) { _, _ in bad }
            XCTAssertEqual(line, fallback, bad)
        }
        XCTAssertEqual(NeighbourThinking.howAreThey(neighbour, days: days, now: now, calendar: calendar, teller: nil), fallback)
        XCTAssertEqual(NeighbourThinking.howAreThey(neighbour, days: days, now: now, calendar: calendar) { _, _ in nil }, fallback)
    }

    func testMonthsAndPossessivesAreNotNewNames() throws {
        let (neighbour, _) = try gerald()
        XCTAssertNotNil(NeighbourThinking.checked("Gerald's kept the same three leaves since October.",
                                                  neighbour: neighbour, readerTexts: []))
    }

    func testWhoIsThisOnlyTakesANameTheReaderWrote() {
        let sentence = "The blue thermos is Dribble and it leaks down my sleeve."
        XCTAssertEqual(NeighbourThinking.parsedName("NAME: Dribble", sentence: sentence, excluded: []), "Dribble")
        XCTAssertNil(NeighbourThinking.parsedName("NAME: Leaky", sentence: sentence, excluded: []), "not in the sentence")
        XCTAssertNil(NeighbourThinking.parsedName("NONE", sentence: sentence, excluded: []))
        XCTAssertNil(NeighbourThinking.parsedName("NAME: Dribble", sentence: sentence, excluded: ["Dribble"]))
        XCTAssertNil(NeighbourThinking.parsedName("NAME: dribble", sentence: sentence, excluded: []), "exactly as written")
        let ask = NeighbourThinking.whoIsThisPrompt(sentence: sentence)
        XCTAssertTrue(ask.prompt.contains(sentence))
    }

    func testSameOneIsAVerdictOrNothing() {
        XCTAssertEqual(NeighbourThinking.parsedSame("SAME"), true)
        XCTAssertEqual(NeighbourThinking.parsedSame("different."), false)
        XCTAssertNil(NeighbourThinking.parsedSame("I think maybe"))
        XCTAssertNil(NeighbourThinking.parsedSame(nil))
    }
}
