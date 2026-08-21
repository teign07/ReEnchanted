import XCTest
@testable import InsideCoverCore

/// A souvenir is a scrap of a day the reader decided to keep, and the moon
/// lights keepsakes. This is the leaf's material answering the world — the same
/// family as the deckle edge and the foxing — not an action and not chrome.
final class MoonlitLeafTests: XCTestCase {
    func testKeepsakesCatchTheMoon() {
        XCTAssertTrue(BookPageType.souvenir.isLitByTheMoon)
        XCTAssertTrue(BookPageType.bookPocket.isLitByTheMoon)
    }

    /// Reading matter is not lit. If everything glowed, nothing would.
    func testOrdinaryReadingIsNotLit() {
        for type in [BookPageType.diary, .quotes, .letter, .bookNotices, .weather] {
            XCTAssertFalse(type.isLitByTheMoon, "\(type) should not catch moonlight")
        }
    }

    /// The whole point of reading `illuminatedFraction` rather than a full-moon
    /// flag: the Book gets brighter as the month turns, instead of a light
    /// switching on for one night. A threshold would hide the change entirely.
    func testTheMoonIsReadAsAFractionNotASwitch() {
        var seen = Set<String>()
        // Sample a full lunar month.
        for day in 0..<30 {
            let date = Date().addingTimeInterval(Double(day) * 86_400)
            let fraction = MoonPhaseCalendar.phase(on: date).illuminatedFraction
            XCTAssertTrue((0...1).contains(fraction), "day \(day): \(fraction)")
            seen.insert(String(format: "%.2f", fraction))
        }
        XCTAssertGreaterThan(seen.count, 12, "a month should show many different fullnesses")
    }

    func testTonightsMoonIsReportedForContext() {
        let tonight = MoonPhaseCalendar.phase(on: Date())
        print("Tonight: \(tonight.name), illuminated \(String(format: "%.0f%%", tonight.illuminatedFraction * 100))")
        XCTAssertFalse(tonight.name.isEmpty)
    }
}
