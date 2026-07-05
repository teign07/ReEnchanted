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

    func testReturningGreetingUsesRemembranceInsteadOfLiveMechanics() {
        let recent = BookGreetingComposer.compose(.init(
            name: "bj",
            rememberedFactLines: ["You care about small rituals."],
            recentKeptLines: ["The kettle clicked like a tiny door latch."],
            keptPageCount: 4,
            seed: 0
        ))
        XCTAssertTrue(recent.line.contains("I remember this from your margins"))
        XCTAssertTrue(recent.line.contains("kettle"))

        let fact = BookGreetingComposer.compose(.init(
            name: "bj",
            rememberedFactLines: ["You care about small rituals."],
            keptPageCount: 4,
            seed: 0
        ))
        XCTAssertTrue(fact.line.contains("Book remembers"))
        XCTAssertTrue(fact.line.contains("small rituals"))

        let count = BookGreetingComposer.compose(.init(name: "bj", keptPageCount: 2, seed: 0))
        XCTAssertTrue(count.line.contains("2 kept fragments"))

        let wonder = BookGreetingComposer.compose(.init(name: "bj", seed: 3))
        XCTAssertTrue(wonder.line.lowercased().contains("i wonder"))
        XCTAssertFalse(wonder.line.contains("bargain"))
        XCTAssertFalse(wonder.line.contains("Wheel"))
        XCTAssertFalse(wonder.line.contains("talisman"))
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

    func testWorldChargeCarriesCelebrationFaeAndPactSignals() {
        let celebration = WorldChargeComposer.compose(.init(
            moonName: "New Moon",
            celebrationTitle: "The Luminous Gathering",
            hour: 12,
            seed: 0
        ))
        XCTAssertTrue(celebration.contains("Luminous Gathering"))

        let fae = WorldChargeComposer.compose(.init(
            moonName: "New Moon",
            hour: 12,
            seed: 0,
            openBargainFae: "Sentence Salamander"
        ))
        XCTAssertTrue(fae.contains("Sentence Salamander"))
        XCTAssertTrue(fae.contains("Terms"))

        let pact = WorldChargeComposer.compose(.init(
            moonName: "New Moon",
            hour: 12,
            seed: 0,
            pactLine: "The Wind Cipher asks for a small errand."
        ))
        XCTAssertTrue(pact.contains("Wind Cipher"))
        XCTAssertTrue(pact.contains("Another Page"))
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

    func testOpeningVoiceSummarizesAgencySignals() {
        let voice = BookOpenVoiceComposer.compose(.init(
            moonName: "Waxing Crescent",
            hour: 15,
            seed: 0,
            ascendantTalismanName: "The Dusk Thorn",
            castActionLine: "Zara Finch invested 2 Belief in Wicker Eddies.",
            relationshipLine: "Zara Finch and Wicker Eddies warmed by the Loom.",
            beliefMovementLine: "Mothlight Beats brightened by 1.",
            readerBelief: 34
        ))

        XCTAssertFalse(voice.heroLine.isEmpty)
        XCTAssertFalse(voice.edgeLine.isEmpty)
        XCTAssertTrue(
            voice.edgeLine.contains("Relationship")
                || voice.edgeLine.contains("Cast")
                || voice.edgeLine.contains("Belief")
                || voice.edgeLine.contains("Talisman")
        )
    }

    func testOpeningVoiceKeepsReadableLineCount() {
        let voice = BookOpenVoiceComposer.compose(.init(
            moonName: "Full Moon",
            hour: 22,
            seed: 3,
            castActionLine: "Penny Blackletter gave 3 Belief to Wonder Compass Pages.",
            beliefMovementLine: "You brightened by 1. Yesterday's kept pages left a small ember behind."
        ))

        XCTAssertLessThanOrEqual(voice.heroLine.components(separatedBy: ". ").count, 2)
        XCTAssertLessThanOrEqual(voice.edgeLine.components(separatedBy: ". ").count, 2)
    }
}
