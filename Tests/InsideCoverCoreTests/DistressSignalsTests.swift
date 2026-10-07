import XCTest
@testable import InsideCoverCore

/// What counts as a hard day. One honest mood word used to be enough, so naming
/// a heavy sky in Inner Weather shrank the whole Book for the day.
final class DistressSignalsTests: XCTestCase {
    private func day(_ pages: [(input: String, tags: [String])]) -> BookDay {
        let date = Calendar.current.date(
            from: DateComponents(year: 2026, month: 6, day: 1, hour: 10)
        )!
        return BookDay(
            id: "2026-06-01",
            date: date,
            pages: pages.enumerated().map { offset, page in
                BookPage(
                    id: "page-\(offset)",
                    type: .souvenir,
                    createdAt: date.addingTimeInterval(Double(offset) * 60),
                    promptText: "One sentence.",
                    userInput: page.input,
                    tags: page.tags
                )
            }
        )
    }

    func testOneMoodWordIsNotAHardDay() {
        XCTAssertFalse(DistressSignals.evaluate(day: day([("Quiet and heavy.", ["heavy"])])).isActive)
        XCTAssertFalse(DistressSignals.evaluate(day: day([("I can't do this crossword.", [])])).isActive)
        XCTAssertFalse(DistressSignals.evaluate(day: day([("Low sun on the water.", ["low"])])).isActive)
    }

    func testTwoDifferentPagesOfMoodWordsAreAHardDay() {
        let signals = DistressSignals.evaluate(day: day([
            ("Everything feels heavy.", ["heavy"]),
            ("Gone numb by lunch.", ["numb"])
        ]))
        XCTAssertTrue(signals.isActive)
        XCTAssertEqual(signals.reasons.count, 2)
    }

    func testOnePageCarryingTwoWeakSignalsStillCountsOnce() {
        XCTAssertFalse(DistressSignals.evaluate(
            day: day([("Heavy and numb and low.", ["heavy", "numb", "low"])])
        ).isActive)
    }

    func testAnExplicitSignalIsEnoughByItself() {
        XCTAssertTrue(DistressSignals.evaluate(day: day([("Nothing helps.", ["distress"])])).isActive)
        XCTAssertTrue(DistressSignals.evaluate(day: day([("I feel hopeless.", [])])).isActive)
        XCTAssertTrue(DistressSignals.evaluate(day: day([("Felt depressed all day.", [])])).isActive)
    }
}
