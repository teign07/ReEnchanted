import XCTest
@testable import InsideCoverCore

/// A scorer that answers from a fixed table, keyed by document text —
/// deterministic stand-in for the sentence embedding.
private struct FixedSimilarityScorer: StacksSemanticScoring {
    let modelID = "test.fixed"
    var scores: [String: Double]

    func similarity(between query: String, and document: String) -> Double? {
        scores[document]
    }
}

final class SemanticEchoTests: XCTestCase {

    private let oldFeeling = "The kettle sang twice and nobody came."
    private let newFeeling = "Something small waited all evening for my attention."

    func testSemanticEchoFiresOnWordDisjointFeeling() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.8])

        let echo = try XCTUnwrap(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            )
        )
        XCTAssertEqual(echo.sourcePageID, "old")
        XCTAssertEqual(echo.similarity, 0.8)
        XCTAssertEqual(echo.excerpt, "The kettle sang twice and nobody came")
        XCTAssertTrue(echo.line.contains(echo.excerpt))
        XCTAssertTrue(echo.monthLine.contains("back in") || echo.monthLine.contains("in "))
    }

    func testSemanticEchoRefusesSharedContentWord() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.9])

        XCTAssertNil(
            SemanticKeepEcho.find(
                for: "The kettle waited all evening for my attention.", pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            ),
            "A shared content word means string matching could take credit — the word echo's territory."
        )
    }

    func testSemanticEchoRespectsAgeAndPrivacy() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.9])

        let recent = prosePage(id: "recent", createdAt: now.addingTimeInterval(-3 * 86_400), input: oldFeeling)
        XCTAssertNil(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([recent])], scorer: scorer, now: now
            ),
            "A 3-day-old page is too recent to echo."
        )

        let oldBody = BookPage(
            id: "body",
            type: .body,
            createdAt: now.addingTimeInterval(-40 * 86_400),
            promptText: "How does the body read today?",
            userInput: oldFeeling,
            tags: ["body"]
        )
        XCTAssertNil(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([oldBody])], scorer: scorer, now: now
            ),
            "Body logs never echo."
        )

        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        XCTAssertNil(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .fuel, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            ),
            "The Book stays out of fuel logs on the kept side too."
        )
    }

    func testSemanticEchoNeedsSimilarityFloor() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: SemanticKeepEcho.similarityFloor - 0.01])

        XCTAssertNil(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            )
        )
    }

    func testSemanticEchoNeedsScorerAndBody() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.9])

        XCTAssertNil(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: nil, now: now
            ),
            "No embedding, no claim."
        )
        XCTAssertNil(
            SemanticKeepEcho.find(
                for: "Quiet day, mostly.", pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            ),
            "A thin input cannot carry a felt connection."
        )
    }

    func testSemanticEchoPicksStrongestSimilarity() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let softer = "The lamp stayed on longer than it needed to."
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let other = prosePage(id: "other", createdAt: now.addingTimeInterval(-60 * 86_400), input: softer)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.62, softer: 0.9])

        let echo = try XCTUnwrap(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([old]), dayHolding([other])], scorer: scorer, now: now
            )
        )
        XCTAssertEqual(echo.sourcePageID, "other")
        XCTAssertEqual(echo.similarity, 0.9)
    }

    func testSemanticEchoIsDeterministic() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.8])
        let days = [dayHolding([old])]

        let first = SemanticKeepEcho.find(for: newFeeling, pageType: .diary, pageID: "new", in: days, scorer: scorer, now: now)
        let second = SemanticKeepEcho.find(for: newFeeling, pageType: .diary, pageID: "new", in: days, scorer: scorer, now: now)
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    func testExcerptClipsOnWordBoundary() {
        let long = "The harbor lights were doing that thing where they promise considerably more than any morning could keep"
        let clipped = SemanticKeepEcho.excerpt(of: long)
        XCTAssertTrue(clipped.hasSuffix("\u{2026}"))
        XCTAssertLessThanOrEqual(clipped.count, 65)
        XCTAssertFalse(clipped.dropLast().hasSuffix(" "))

        XCTAssertEqual(
            SemanticKeepEcho.excerpt(of: "Short and sweet. And this part is dropped."),
            "Short and sweet"
        )
    }

    func testNoteWearsTheBooksOwnVoice() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.8])
        let echo = try XCTUnwrap(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            )
        )
        let note = SemanticKeepEcho.note(from: echo)
        XCTAssertEqual(note.castSlug, "the-book")
        XCTAssertEqual(note.castName, "The Book")
        XCTAssertEqual(note.line, echo.line)
    }

    func testSemanticEchoExposesDurableMemoryTags() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(id: "old", createdAt: now.addingTimeInterval(-40 * 86_400), input: oldFeeling)
        let scorer = FixedSimilarityScorer(scores: [oldFeeling: 0.8])
        let echo = try XCTUnwrap(
            SemanticKeepEcho.find(
                for: newFeeling, pageType: .diary, pageID: "new",
                in: [dayHolding([old])], scorer: scorer, now: now
            )
        )

        let tags = SemanticKeepEcho.tags(for: echo)

        XCTAssertTrue(tags.contains(SemanticKeepEcho.markerTag))
        XCTAssertTrue(tags.contains("\(SemanticKeepEcho.sourceTagPrefix)old"))
        XCTAssertTrue(tags.contains("\(SemanticKeepEcho.lineTagPrefix)\(echo.line)"))
    }

    // MARK: Fixtures

    private func dayHolding(_ pages: [BookPage]) -> BookDay {
        let anchor = pages.first?.createdAt ?? Date()
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: anchor)
        let id = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
        return BookDay(id: id, date: Calendar.current.startOfDay(for: anchor), pages: pages)
    }

    private func prosePage(id: String, createdAt: Date, input: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: createdAt,
            promptText: "Catch one bright particular.",
            userInput: input,
            tags: ["souvenir"],
            origin: .userAuthored
        )
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
}
