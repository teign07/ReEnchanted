import XCTest
@testable import InsideCoverCore

/// Taught Reading: the Book remembering, out loud, every correction the
/// reader has made: braid notes, notice feedback, and the quiet dismissals.
final class TaughtReadingTests: XCTestCase {

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!

    private func noticeEvent(_ action: ReaderLearningAction, id: String) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: id,
            dayID: "2026-07-18",
            occurredAt: now.addingTimeInterval(-2 * 86_400),
            action: action,
            surfaceID: "surface-\(id)",
            sourceID: "book-notices",
            type: .bookNotices,
            varietyKey: "book-notices",
            hour: 12
        )
    }

    private func braid(id: String, tags: [String]) -> BookPage {
        BookPage(id: id, type: .bookOfYou, createdAt: now.addingTimeInterval(-3 * 86_400),
                 promptText: "Braid", userInput: "A braided page.", tags: tags)
    }

    private func day(_ pages: [BookPage]) -> BookDay {
        BookDay(id: "2026-07-17", date: now.addingTimeInterval(-3 * 86_400), pages: pages)
    }

    func testNoRulesWithoutTeaching() {
        XCTAssertTrue(
            TaughtReading.rules(learnedBraidNotes: [], days: [], learning: ReaderLearningModel(), now: now).isEmpty
        )
        XCTAssertNil(TaughtReading.noticeLine(from: []))
    }

    func testBraidNotesComeFirstAndAreQuoted() throws {
        let rules = TaughtReading.rules(
            learnedBraidNotes: ["Less weather, more people.", "Stop calling the cat a metaphor."],
            days: [],
            learning: ReaderLearningModel(),
            now: now
        )
        let first = try XCTUnwrap(rules.first)
        XCTAssertTrue(first.line.contains("Stop calling the cat a metaphor."), "Newest teaching speaks first: \(first.line)")
        XCTAssertTrue(first.line.contains("You told me"))
        XCTAssertTrue(rules.contains { $0.line.contains("Less weather, more people.") })
    }

    func testNoticeFeedbackBecomesRules() {
        var learning = ReaderLearningModel()
        learning.record(noticeEvent(.dismissed, id: "e1"))
        learning.record(noticeEvent(.missed, id: "e2"))
        learning.record(noticeEvent(.missed, id: "e3"))
        learning.record(noticeEvent(.loved, id: "e4"))

        let rules = TaughtReading.rules(learnedBraidNotes: [], days: [], learning: learning, now: now)
        XCTAssertTrue(rules.contains { $0.id == "taught-notice-dismissed" && $0.line.contains("once") })
        XCTAssertTrue(rules.contains { $0.id == "taught-notice-missed" && $0.line.contains("Two notices") })
        XCTAssertTrue(rules.contains { $0.id == "taught-notice-loved" && $0.line.contains("One reading") })
    }

    func testBraidVerdictTagsBecomeARule() throws {
        let days = [day([
            braid(id: "b1", tags: [BraidLearningLoop.lovedItTag]),
            braid(id: "b2", tags: [BraidLearningLoop.lovedItTag]),
            braid(id: "b3", tags: [BraidLearningLoop.missedMeTag])
        ])]
        let rules = TaughtReading.rules(learnedBraidNotes: [], days: days, learning: ReaderLearningModel(), now: now)
        let verdict = try XCTUnwrap(rules.first { $0.id == "taught-braid-verdicts" })
        XCTAssertTrue(verdict.line.contains("two true"), verdict.line)
        XCTAssertTrue(verdict.line.contains("a miss"), verdict.line)
    }

    func testMissOnlyBraidsSpeakOfRewriting() throws {
        let days = [day([braid(id: "b1", tags: [BraidLearningLoop.missedMeTag])])]
        let rules = TaughtReading.rules(learnedBraidNotes: [], days: days, learning: ReaderLearningModel(), now: now)
        let verdict = try XCTUnwrap(rules.first { $0.id == "taught-braid-verdicts" })
        XCTAssertTrue(verdict.line.contains("rewrite toward what you meant"))
    }

    func testNoticeLineWeavesTheFirstRule() throws {
        let rules = TaughtReading.rules(
            learnedBraidNotes: ["Less weather, more people."],
            days: [],
            learning: ReaderLearningModel(),
            now: now
        )
        let line = try XCTUnwrap(TaughtReading.noticeLine(from: rules))
        XCTAssertTrue(line.contains("teaching me how to read you"))
        XCTAssertTrue(line.contains("Less weather, more people."))
    }

    func testLongTeachingsAreClippedOnAWordBoundary() throws {
        let long = "Please remember that the mornings are not sad, they are just slow, and the Book keeps mistaking slowness for sorrow when it reads them back to me."
        let rules = TaughtReading.rules(learnedBraidNotes: [long], days: [], learning: ReaderLearningModel(), now: now)
        let first = try XCTUnwrap(rules.first)
        XCTAssertTrue(first.line.contains("\u{2026}"))
        XCTAssertFalse(first.line.contains("reads them back to me"), "The tail should be clipped: \(first.line)")
    }

    func testRuleCapHolds() {
        var learning = ReaderLearningModel()
        learning.record(noticeEvent(.dismissed, id: "e1"))
        learning.record(noticeEvent(.missed, id: "e2"))
        learning.record(noticeEvent(.loved, id: "e3"))
        let days = [day([braid(id: "b1", tags: [BraidLearningLoop.lovedItTag])])]
        let rules = TaughtReading.rules(
            learnedBraidNotes: ["One.", "Two."],
            days: days,
            learning: learning,
            now: now,
            limit: 3
        )
        XCTAssertEqual(rules.count, 3)
    }
}
