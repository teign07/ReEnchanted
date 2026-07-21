import XCTest
@testable import InsideCoverCore

/// The Book Asks — one pointed question grounded in the reader's own hedge
/// words. An "again" implies a first time; the Book asks about the part that
/// was never written down.
final class BookAsksTests: XCTestCase {
    private let adapter = BookAsksPageSourceAdapter()

    private func date(_ day: Int, hour: Int = 10) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func souvenir(_ text: String, on day: Int, hour: Int = 10, tags: [String] = []) -> BookPage {
        BookPage(type: .souvenir, createdAt: date(day, hour: hour), promptText: "Souvenir", userInput: text, tags: tags)
    }

    private func day(_ day: Int, pages: [BookPage]) -> BookDay {
        BookDay(id: String(format: "2026-07-%02d", day), date: date(day, hour: 0), pages: pages)
    }

    // MARK: - Engine

    func testFindsHedgeInRecentPage() throws {
        let days = [day(10, pages: [
            souvenir("We did not fight about the dishes this time.", on: 10)
        ])]
        let question = try XCTUnwrap(BookAsks.question(in: days, askedSourcePageIDs: [], now: date(11)))
        XCTAssertEqual(question.hedgeWord, "this time")
        XCTAssertEqual(question.sentence, "We did not fight about the dishes this time")
    }

    func testHedgePriorityFollowsArrayOrder() throws {
        let days = [day(10, pages: [
            souvenir("It almost worked again, like it almost worked before.", on: 10)
        ])]
        let question = try XCTUnwrap(BookAsks.question(in: days, askedSourcePageIDs: [], now: date(11)))
        XCTAssertEqual(question.hedgeWord, "again", "\u{201C}again\u{201D} outranks \u{201C}almost\u{201D} in the hedge order.")
    }

    func testWholeWordMatchingOnly() {
        let days = [day(10, pages: [
            souvenir("The stillness held all morning across the grey water.", on: 10)
        ])]
        XCTAssertNil(
            BookAsks.question(in: days, askedSourcePageIDs: [], now: date(11)),
            "\u{201C}stillness\u{201D} must not match the hedge \u{201C}still\u{201D}."
        )
    }

    func testIgnoresOldPagesPrivateLogsAndOwnAnswers() {
        let stale = [day(1, pages: [souvenir("The kettle sang again this morning.", on: 1)])]
        XCTAssertNil(
            BookAsks.question(in: stale, askedSourcePageIDs: [], now: date(11)),
            "A ten-day-old page is outside the asking window."
        )

        let fuel = [day(10, pages: [
            BookPage(type: .fuel, createdAt: date(10), promptText: "Fuel", userInput: "Skipped breakfast again before the long drive.")
        ])]
        XCTAssertNil(BookAsks.question(in: fuel, askedSourcePageIDs: [], now: date(11)))

        let answer = [day(10, pages: [
            souvenir("It happened again, the way it always does.", on: 10, tags: ["book-asks"])
        ])]
        XCTAssertNil(
            BookAsks.question(in: answer, askedSourcePageIDs: [], now: date(11)),
            "The Book never mines its own question-answers for new questions."
        )
    }

    func testNeverAsksAboutTheSamePageTwice() throws {
        let page = souvenir("The kettle sang again this morning.", on: 10)
        let days = [day(10, pages: [page])]
        XCTAssertNotNil(BookAsks.question(in: days, askedSourcePageIDs: [], now: date(11)))
        XCTAssertNil(BookAsks.question(in: days, askedSourcePageIDs: [page.id], now: date(11)))
    }

    func testMostRecentPageWins() throws {
        let older = souvenir("Rain again on the long road home.", on: 9)
        let newer = souvenir("The porch light was still on when I got back.", on: 10, hour: 20)
        let days = [day(9, pages: [older]), day(10, pages: [newer])]
        let question = try XCTUnwrap(BookAsks.question(in: days, askedSourcePageIDs: [], now: date(11)))
        XCTAssertEqual(question.sourcePageID, newer.id)
        XCTAssertEqual(question.hedgeWord, "still")
    }

    func testAskedSourcePageIDsRecoverFromTags() {
        let kept = BookPage(
            type: .bookNotices, createdAt: date(10), promptText: "The Book Asks",
            userInput: "", tags: ["book-asks", "book-asks-src-abc123", "book-notices"]
        )
        XCTAssertEqual(BookAsks.askedSourcePageIDs(in: [day(10, pages: [kept])]), ["abc123"])
    }

    func testWeeklyGovernor() {
        let kept = BookPage(
            type: .bookNotices, createdAt: date(8), promptText: "The Book Asks",
            userInput: "", tags: ["book-asks"]
        )
        let days = [day(8, pages: [kept])]
        XCTAssertTrue(BookAsks.askedRecently(in: days, now: date(11)))
        XCTAssertFalse(BookAsks.askedRecently(in: days, now: date(20)))
    }

    func testBodyQuotesSentenceAndProbesTheHedge() {
        let question = BookAsks.Question(
            sourcePageID: "p1",
            hedgeWord: "finally",
            sentence: "The boxes are finally out of the hallway"
        )
        let body = BookAsks.body(for: question)
        XCTAssertTrue(body.contains("The boxes are finally out of the hallway"))
        XCTAssertTrue(body.contains("the waiting"))
        XCTAssertTrue(body.contains("Pencil questions don't rust."))
    }

    func testClippingKeepsWordBoundary() {
        let long = String(repeating: "a long sentence that keeps going ", count: 6)
        let clipped = BookAsks.clipped(long)
        XCTAssertTrue(clipped.hasSuffix("\u{2026}"))
        XCTAssertLessThanOrEqual(clipped.count, 111)
        XCTAssertEqual(BookAsks.clipped("Short one"), "Short one")
    }

    // MARK: - Adapter

    private func inputs(archive: [BookDay]) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = archive
        return inputs
    }

    private func matureArchive(hedgePage: BookPage) -> [BookDay] {
        // Nine substantial pages so the adapter is past the First Reading window.
        let filler = (1...8).map { souvenir("A steady kept line number \($0), with real substance to it.", on: 3, hour: $0) }
        return [day(3, pages: filler), day(10, pages: [hedgePage])]
    }

    func testAdapterSurfacesOneQuestion() {
        let hedge = souvenir("The kettle sang again this morning.", on: 10)
        let today = BookDay(id: "today", date: date(11), pages: [])
        let surfaced = adapter.candidates(
            for: today, context: CuratorContext.make(for: today),
            inputs: inputs(archive: matureArchive(hedgePage: hedge)), now: date(11)
        )
        XCTAssertEqual(surfaced.count, 1)
        XCTAssertEqual(surfaced.first?.type, .bookNotices)
        XCTAssertEqual(surfaced.first?.payload.metadata["bookAsks"], "true")
        XCTAssertEqual(surfaced.first?.payload.metadata["bookAsksWord"], "again")
        XCTAssertEqual(surfaced.first?.payload.metadata["bookAsksSourcePageID"], hedge.id)
        XCTAssertTrue(surfaced.first?.payload.metadata["tags"]?.contains("book-asks-src-\(hedge.id)") == true)
        XCTAssertTrue(surfaced.first?.payload.body.contains("kettle") == true)
    }

    func testAdapterWaitsForLibraryDepth() {
        // Only the hedge page and two others: inside First Reading's window, too
        // early for questions.
        let hedge = souvenir("The kettle sang again this morning.", on: 10)
        let thin = [day(10, pages: [
            hedge,
            souvenir("A quiet mug before anyone woke.", on: 10, hour: 8),
            souvenir("Rain that nobody minded.", on: 10, hour: 9)
        ])]
        let today = BookDay(id: "today", date: date(11), pages: [])
        XCTAssertTrue(adapter.candidates(
            for: today, context: CuratorContext.make(for: today),
            inputs: inputs(archive: thin), now: date(11)
        ).isEmpty)
    }

    func testAdapterHonorsWeeklyGovernor() {
        let hedge = souvenir("The kettle sang again this morning.", on: 10)
        var archive = matureArchive(hedgePage: hedge)
        archive.append(day(9, pages: [
            BookPage(type: .bookNotices, createdAt: date(9), promptText: "The Book Asks",
                     userInput: "", tags: ["book-asks", "book-asks-src-old"])
        ]))
        let today = BookDay(id: "today", date: date(11), pages: [])
        XCTAssertTrue(adapter.candidates(
            for: today, context: CuratorContext.make(for: today),
            inputs: inputs(archive: archive), now: date(11)
        ).isEmpty)
    }
}
