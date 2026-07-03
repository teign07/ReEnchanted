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
        // Default keeps the Book open-ended.
        XCTAssertEqual(BookGreetingComposer.compose(.init(name: "bj", seed: 0)).line, "The Book is ready to play.")
        XCTAssertFalse(BookGreetingComposer.compose(.init(name: "bj", seed: 0)).line.contains("Ready to make some magic?"))
    }

    func testWorldChargePrioritizesLiveWorldSignals() {
        let celebration = WorldChargeComposer.compose(.init(
            moonName: "Waxing Crescent",
            celebrationTitle: "The Luminous Gathering",
            greyLevel: 3,
            hour: 20,
            seed: 0
        ))
        XCTAssertTrue(celebration.contains("Luminous Gathering"))

        let weather = WorldChargeComposer.compose(.init(
            weatherPhrase: "steady rain against the glass",
            moonName: "New Moon",
            hour: 14,
            seed: 0
        ))
        XCTAssertTrue(weather.lowercased().contains("rain"))

        let kept = WorldChargeComposer.compose(.init(
            keptToday: 2,
            moonName: "New Moon",
            hour: 12,
            seed: 0
        ))
        XCTAssertTrue(kept.contains("2 fragments"))
        XCTAssertTrue(kept.contains("next Page"))
    }

    func testAfterglowCarriesTheKeepOutward() {
        let line = BookAfterglow.line(
            for: "The hallway light made the umbrella look like a tiny lighthouse.",
            pageType: .souvenir,
            pageID: "afterglow-test"
        )
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(
            line.contains("next room")
                || line.contains("next Page")
                || line.contains("outside the covers")
        )
    }
}
