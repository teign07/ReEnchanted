import XCTest
@testable import InsideCoverCore

final class BookGreetingTests: XCTestCase {
    func testGreetingUsesNameAndFallsBack() {
        XCTAssertTrue(BookGreetingComposer.compose(.init(name: "bj", seed: 0)).greeting.contains("bj"))
        XCTAssertTrue(BookGreetingComposer.compose(.init(name: "  ", seed: 0)).greeting.contains("friend"))
    }

    func testOpenerRotatesWithSeed() {
        let a = BookGreetingComposer.compose(.init(name: "bj", seed: 0)).greeting
        let b = BookGreetingComposer.compose(.init(name: "bj", seed: 1)).greeting
        XCTAssertNotEqual(a, b)
    }

    func testDynamicLineFollowsPriority() {
        // Celebration outranks everything.
        XCTAssertTrue(BookGreetingComposer.compose(.init(
            name: "bj", celebrationTitle: "The Luminous Gathering",
            openBargainFae: "Marginalia Goblin", keptYesterday: 3, seed: 0
        )).line.contains("Luminous Gathering"))
        // Then an open bargain.
        XCTAssertTrue(BookGreetingComposer.compose(.init(
            name: "bj", openBargainFae: "Sentence Salamander", keptYesterday: 3, seed: 0
        )).line.contains("Sentence Salamander"))
        // Then yesterday's pages.
        XCTAssertTrue(BookGreetingComposer.compose(.init(name: "bj", keptYesterday: 2, seed: 0)).line.contains("2 pages"))
        // Grey day.
        XCTAssertTrue(BookGreetingComposer.compose(.init(name: "bj", greyLevel: 3, seed: 0)).line.contains("grey"))
        // Default call to magic.
        XCTAssertEqual(BookGreetingComposer.compose(.init(name: "bj", seed: 0)).line, "Ready to make some magic?")
    }
}
