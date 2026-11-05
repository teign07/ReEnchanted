import XCTest
@testable import InsideCoverCore

final class WritingTipTests: XCTestCase {
    func testEveryTipIsLabelledAndHasItsOwnHandwrittenAside() {
        let lessons = InterleafWritingCraft.lessons
        XCTAssertFalse(lessons.isEmpty)
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
        for lesson in lessons {
            XCTAssertTrue(lesson.label.hasPrefix("Sentence Tip: "), lesson.id)
            XCTAssertTrue(lesson.text.contains(lesson.quotedExample), lesson.id)
            XCTAssertFalse(lesson.aside.isEmpty, lesson.id)
            XCTAssertLessThanOrEqual(lesson.aside.count, 45, "\(lesson.id) aside must fit a margin")
            XCTAssertFalse(lesson.explanation.contains(lesson.aside), "\(lesson.id) aside repeats the printed tip")
            XCTAssertEqual(InterleafWritingCraft.lesson(forTextID: lesson.textID)?.id, lesson.id)
        }
        XCTAssertEqual(InterleafWritingCraft.texts.map(\.id), lessons.map(\.textID))
    }

    func testTipsSpeakAsTheBookNotAboutIt() {
        let banned = ["the book", "ritual", "hinge", "teeth", "synaesthetic"]
        for lesson in InterleafWritingCraft.lessons {
            let all = [lesson.title, lesson.explanation, lesson.why, lesson.aside].joined(separator: " ").lowercased()
            for word in banned { XCTAssertFalse(all.contains(word), "\(lesson.id): \(word)") }
        }
        let tip = InterleafWritingCraft.texts[0]
        XCTAssertEqual(tip.attribution, "ME, ON WRITING")
    }

    func testTipAsidesStayOutOfTheGeneralMarginaliaPool() {
        let pool = Set(IlluminationMarginaliaLibrary.availableSnippets.map(\.text))
        for lesson in InterleafWritingCraft.lessons {
            XCTAssertFalse(pool.contains(lesson.aside), lesson.id)
        }
    }
}
