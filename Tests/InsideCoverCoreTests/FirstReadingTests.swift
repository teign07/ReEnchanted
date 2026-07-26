import XCTest
@testable import InsideCoverCore

/// The First Reading — the Book's earliest honest proof it read *you*. It fires
/// before the pattern-noticing maturity gate, grounded entirely in the reader's
/// own kept pages, exactly once, and never invents a pattern.
final class FirstReadingTests: XCTestCase {
    private let adapter = FirstReadingPageSourceAdapter()

    private func date(_ day: Int, hour: Int = 10) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func souvenir(_ text: String, on day: Int, hour: Int = 10) -> BookPage {
        BookPage(type: .souvenir, createdAt: date(day, hour: hour), promptText: "Souvenir", userInput: text)
    }

    private func inputs(with pages: [BookPage]) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { id, pages in BookDay(id: id, date: pages[0].createdAt, pages: pages) }
        return inputs
    }

    private func accumulatedPages() -> [BookPage] {
        [
            souvenir("The kitchen window held the last of the gold light.", on: 1),
            souvenir("Rain all afternoon, and I did not mind it once.", on: 1, hour: 18),
            souvenir("A quiet mug of coffee before anyone else woke.", on: 2),
            souvenir("The porch boards were warm under my feet.", on: 2, hour: 19),
            souvenir("A small bird argued with the garden gate.", on: 3),
            souvenir("The moon found the water glass after dark.", on: 3, hour: 20)
        ]
    }

    private func candidates(_ inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let today = BookDay(id: "today", date: now, pages: [])
        return adapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
    }

    // MARK: - Surfacing

    func testSurfacesAfterEvidenceAccumulatesAcrossThreeDays() {
        let surfaced = candidates(inputs(with: accumulatedPages()), now: date(3, hour: 21))
        XCTAssertEqual(surfaced.first?.type, .bookNotices)
        XCTAssertEqual(surfaced.first?.payload.metadata["firstReading"], "true")
        XCTAssertEqual(surfaced.first?.payload.metadata["reflectedPageCount"], "6")
        // The proof: the reader's own words are quoted back.
        XCTAssertTrue(surfaced.first?.payload.body.contains("gold light") == true)
        XCTAssertEqual(surfaced.first?.payload.metadata["automaticRepeatRestDays"], "45")
        XCTAssertEqual(surfaced.first?.payload.metadata["noveltyKey"], "first-reading")
    }

    func testDoesNotSurfaceWithTwoPages() {
        let inputs = inputs(with: [
            souvenir("The kitchen window held the last of the gold light.", on: 1),
            souvenir("Rain all afternoon, and I did not mind it once.", on: 1)
        ])
        XCTAssertTrue(candidates(inputs, now: date(1, hour: 20)).isEmpty)
    }

    func testDoesNotSurfaceFromOneLargeSitting() {
        let pages = (0..<8).map {
            souvenir("A substantial kept sentence number \($0) from the same evening.", on: 1, hour: 8 + $0)
        }
        XCTAssertTrue(candidates(inputs(with: pages), now: date(3, hour: 20)).isEmpty)
    }

    func testReflectableBookOverloadDoesNotDuplicateToday() {
        let today = BookDay(id: "2026-07-01", date: date(1), pages: [
            souvenir("The kitchen window held the last of the gold light.", on: 1),
            souvenir("Rain all afternoon, and I did not mind it once.", on: 1),
            souvenir("A quiet mug of coffee before anyone else woke.", on: 1)
        ])
        var inputs = BookSourceInputs.empty
        inputs.days = [today]

        XCTAssertEqual(FirstReading.reflectablePages(in: inputs, today: today).count, 3)
        XCTAssertEqual(FirstReading.reflectablePages(in: [today]).count, 3)
    }

    func testDoesNotSurfaceOnceLibraryIsDeep() {
        let pages = (1...12).map { souvenir("A real kept line number \($0), with substance.", on: (($0 - 1) / 4) + 1, hour: ($0 % 4) + 8) }
        XCTAssertTrue(candidates(inputs(with: pages), now: date(3, hour: 20)).isEmpty)
    }

    // MARK: - Once-only

    func testDoesNotRepeatAfterKept() {
        var pages = accumulatedPages()
        // The kept reading carries the milestone tag.
        pages.append(BookPage(type: .bookNotices, createdAt: date(1, hour: 21),
                              promptText: "The Book Reads Back", userInput: "",
                              tags: ["first-reading", "book-notices"]))
        XCTAssertTrue(candidates(inputs(with: pages), now: date(4, hour: 20)).isEmpty)
    }

    // MARK: - Privacy

    func testBodyAndFuelStayPrivate() {
        // Two private logs plus six souvenirs: only the souvenirs are counted
        // and reflected. The private input must never appear in the body.
        var pages = [
            BookPage(type: .body, createdAt: date(1, hour: 8), promptText: "Body", userInput: "secret ache in my left knee"),
            BookPage(type: .fuel, createdAt: date(1, hour: 9), promptText: "Fuel", userInput: "skipped lunch again today"),
        ] + accumulatedPages()
        pages.shuffle()
        let surfaced = candidates(inputs(with: pages), now: date(3, hour: 21))
        XCTAssertEqual(surfaced.first?.payload.metadata["reflectedPageCount"], "6")
        let body = surfaced.first?.payload.body ?? ""
        XCTAssertFalse(body.contains("knee"))
        XCTAssertFalse(body.contains("lunch"))
    }

    // MARK: - Honest thread detection

    func testNamesAThreadThatGenuinelyRecurs() {
        let reflection = FirstReading.reflection(for: [
            souvenir("Rain on the window all morning.", on: 1),
            souvenir("More rain by the afternoon, steady and grey.", on: 1),
            souvenir("A warm mug and a good book.", on: 1)
        ], now: date(1, hour: 20))
        XCTAssertEqual(reflection?.threadWord, "rain")
        XCTAssertEqual(reflection?.threadCount, 2)
        let body = FirstReading.body(for: reflection!)
        XCTAssertTrue(body.contains("I've circled it in pencil"))
        XCTAssertTrue(body.contains("It seems pleased"))
        XCTAssertFalse(body.contains("Books should be careful with certainty"))
    }

    func testInventsNoThreadWhenNoneRecurs() {
        let reflection = FirstReading.reflection(for: [
            souvenir("The kitchen was warm and bright.", on: 1),
            souvenir("A dog barked somewhere down the road.", on: 1),
            souvenir("The candle guttered near midnight.", on: 1)
        ], now: date(1, hour: 20))
        XCTAssertNil(reflection?.threadWord)
        XCTAssertFalse(FirstReading.body(for: reflection!).contains("pencil"))
    }

    func testFirstReadingSoundsSpokenWithoutApologizingForReading() throws {
        let reflection = try XCTUnwrap(FirstReading.reflection(for: [
            souvenir("The kitchen window held the last of the gold light.", on: 1),
            souvenir("Rain all afternoon, and I didn't mind it once.", on: 1),
            souvenir("A quiet mug of coffee before anyone else woke.", on: 1)
        ], now: date(1, hour: 20)))

        let body = FirstReading.body(for: reflection)
        XCTAssertTrue(body.hasPrefix("I've read what you kept"))
        XCTAssertTrue(body.contains("That'd be rude"))
        XCTAssertFalse(body.contains("I will not pretend"))
        XCTAssertFalse(body.contains("Not a life yet"))
    }

    // MARK: - Returning sessions

    private func returningReaderInputs() -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs = self.inputs(with: accumulatedPages())
        inputs.surfaceHistory["source:labyrinth-welcome"] = SurfaceHistoryRecord(lastShownAt: date(1, hour: 8), recentShowCount: 1)
        inputs.surfaceHistory["source:help-and-tips"] = SurfaceHistoryRecord(lastShownAt: date(1, hour: 8), recentShowCount: 1)
        return inputs
    }

    /// The milestone yields to a hard day: gentleness leads, the reading waits.
    func testDefersDuringDistress() {
        let hardDay = BookDay(id: "2026-07-02", date: date(2), pages: [
            BookPage(type: .mood, createdAt: date(2, hour: 20), promptText: "Mood",
                     userInput: "a hard one", tags: ["distress"])
        ])
        let distressed = CuratorContext.make(for: hardDay)
        XCTAssertTrue(distressed.distress.isActive, "precondition: the day reads as distress")
        let surfaced = adapter.candidates(for: hardDay, context: distressed, inputs: returningReaderInputs(), now: date(2, hour: 21))
        XCTAssertTrue(surfaced.isEmpty)
    }

    // MARK: - Determinism

    func testBodyIsDeterministic() {
        let pages = [
            souvenir("The kitchen window held the last of the gold light.", on: 1),
            souvenir("Rain all afternoon, and I did not mind it once.", on: 1),
            souvenir("A quiet mug of coffee before anyone else woke.", on: 1)
        ]
        let a = FirstReading.reflection(for: pages, now: date(1, hour: 20)).map(FirstReading.body(for:))
        let b = FirstReading.reflection(for: pages, now: date(1, hour: 20)).map(FirstReading.body(for:))
        XCTAssertEqual(a, b)
    }
}
