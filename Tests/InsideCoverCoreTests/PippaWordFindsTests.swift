import XCTest
@testable import InsideCoverCore

final class PippaWordFindsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testOnlyReaderWordsContributeToCountsAndConnections() {
        let generated = BookPage(id: "generated", type: .letter, createdAt: now,
            promptText: "", userInput: "Moon! Kettle! Door! Key?", tags: [], origin: .generated)
        let reader = BookPage(id: "reader", type: .souvenir, createdAt: now,
            promptText: "Ignore this!", userInput: "Moss! Home?", tags: [], origin: .userAuthored)
        let reading = PippaWordFinds.prepare(days: [BookDay(id: "day", date: now, pages: [generated, reader])])
        XCTAssertEqual(reading.exclamationCount, 1)
        XCTAssertEqual(reading.questionCount, 1)
        XCTAssertFalse(reading.words.contains("kettle"))
        XCTAssertFalse(reading.scraps.contains { $0.id.hasPrefix("connection:") })
        XCTAssertTrue(reading.scraps.filter { !$0.sourcePageIDs.isEmpty }.allSatisfy { $0.sourcePageIDs == ["reader"] })
    }

    func testNewWritingDisplacesTheOldFirstWordAndDuplicateRowsCountOnce() {
        let old = PippaWordFinds.Writing(id: "old", date: now.addingTimeInterval(-86_400), texts: ["beer!"])
        let fresh = PippaWordFinds.Writing(id: "fresh", date: now, texts: ["moss? velvet!"])
        let reading = PippaWordFinds.prepare(writings: [old, fresh, old])
        XCTAssertEqual(Array(reading.words.prefix(2)), ["moss", "velvet"])
        XCTAssertEqual(reading.exclamationCount, 2)
        XCTAssertEqual(reading.questionCount, 1)
    }

    func testReaderReplyIsIncludedButSensitiveAndImportedBodiesAreNot() {
        let reply = BookPage(id: "reply", type: .letter, createdAt: now,
            promptText: "", userInput: "Book-owned moon!!!", playerReply: "moss!", tags: [], origin: .generated)
        let sensitive = BookPage(id: "sensitive", type: .souvenir, createdAt: now,
            promptText: "", userInput: "secret!!!", tags: [], origin: .userAuthored, privacy: .localSensitive)
        let imported = BookPage(id: "import", type: .souvenir, createdAt: now,
            promptText: "", userInput: "someone else’s kettle!!!", tags: [], origin: .imported)
        let reading = PippaWordFinds.prepare(days: [BookDay(id: "day", date: now, pages: [reply, sensitive, imported])])
        XCTAssertEqual(reading.words, ["moss"])
        XCTAssertEqual(reading.exclamationCount, 1)
    }

    func testConnectionNeedsActualWordsOnAtLeastTwoPages() {
        let door = PippaWordFinds.Writing(id: "door", date: now, texts: ["door"])
        let key = PippaWordFinds.Writing(id: "key", date: now, texts: ["key"])
        XCTAssertFalse(PippaWordFinds.prepare(writings: [door]).scraps.contains { $0.id == "connection:door:key" })
        let together = PippaWordFinds.Writing(id: "both", date: now, texts: ["door key"])
        XCTAssertFalse(PippaWordFinds.prepare(writings: [together]).scraps.contains { $0.id == "connection:door:key" })
        let scrap = PippaWordFinds.prepare(writings: [door, key]).scraps.first { $0.id == "connection:door:key" }
        XCTAssertEqual(scrap?.sourcePageIDs, ["door", "key"])
    }

    func testReturningWordNeedsAtLeastAWeekAndRealOccurrences() {
        let old = PippaWordFinds.Writing(id: "old", date: now.addingTimeInterval(-8 * 86_400), texts: ["moss moss"])
        let fresh = PippaWordFinds.Writing(id: "fresh", date: now, texts: ["moss"])
        let reading = PippaWordFinds.prepare(writings: [old, fresh])
        XCTAssertTrue(reading.scraps.contains { $0.id == "return:moss" })
        XCTAssertTrue(reading.scraps.first { $0.id == "repeat:moss" }?.line.contains("3 times") == true)
        XCTAssertNil(PippaWordFinds.prepare(writings: [fresh]).scraps.first { $0.id == "return:moss" })
        XCTAssertNotNil(reading.favouriteScrap(for: "moss"))
        XCTAssertNil(reading.favouriteScrap(for: "velvet"))
    }

    func testRemovingWritingRemovesItsFindsAndFavourite() {
        let writing = PippaWordFinds.Writing(id: "one", date: now, texts: ["velvet!!!!!!"])
        XCTAssertTrue(PippaWordFinds.prepare(writings: [writing]).scraps.contains { $0.id == "craft:ladder" })
        let empty = PippaWordFinds.prepare(writings: [])
        XCTAssertTrue(empty.scraps.isEmpty)
        XCTAssertEqual(empty.exclamationCount, 0)
        XCTAssertNil(empty.favouriteScrap(for: "velvet"))
    }

    func testEditingExclamationDetectionIncludesInsertionPasteAndDeletion() {
        XCTAssertTrue(PippaWordFinds.addedExclamation(before: "hello", after: "hello!"))
        XCTAssertTrue(PippaWordFinds.addedExclamation(before: "hello there", after: "hello! there"))
        XCTAssertTrue(PippaWordFinds.addedExclamation(before: "", after: "a shout! and another!"))
        XCTAssertFalse(PippaWordFinds.addedExclamation(before: "hello!", after: "hello"))
        XCTAssertFalse(PippaWordFinds.addedExclamation(before: "hello!", after: "hello! again"))
        XCTAssertFalse(PippaWordFinds.addedExclamation(before: "hello!", after: "hello!"))
    }
}
