import XCTest
@testable import InsideCoverCore

/// "Reality mints, fiction spends" is the mechanism that keeps the Book from
/// becoming a place to sit. These pin the two properties that make it true:
/// fiction can never mint, and a reader who lives hard never mints into nothing.
final class BeliefEconomyOneWayTests: XCTestCase {

    private func surface(_ type: BookPageType, metadata: [String: String] = [:]) -> SurfacePage {
        SurfacePage(
            id: "s-\(type.rawValue)",
            type: type,
            sourceID: "source-\(type.rawValue)",
            intent: .capture,
            renderStyle: .loreLetter,
            score: 50,
            reason: "r",
            prompt: "p",
            detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: metadata)
        )
    }

    // MARK: - Fiction is wallet-neutral

    func testFictionNeverMintsBelief() {
        for type in [BookPageType.narrativeOS, .letter, .note, .bookFae, .gossip, .enchantment] {
            XCTAssertEqual(
                BeliefEconomyPolicy.keepReward(for: surface(type)),
                0,
                "\(type) must not mint — fiction spends, it does not pay"
            )
        }
    }

    func testAttendingToActualityMints() {
        for type in [BookPageType.souvenir, .diary, .mood, .weather, .wonderCompass, .pactErrand] {
            XCTAssertEqual(
                BeliefEconomyPolicy.keepReward(for: surface(type)),
                1,
                "\(type) is the reader attending to something real"
            )
        }
    }

    func testEveryFictionGenerationCostsSomething() {
        for kind in BeliefGenerationKind.allCases {
            XCTAssertGreaterThan(kind.cost, 0, "\(kind) must cost lived Belief")
        }
    }

    func testAPageMayOptOutOfMintingEntirely() {
        XCTAssertEqual(
            BeliefEconomyPolicy.keepReward(for: surface(.souvenir, metadata: ["noBeliefReward": "true"])),
            0
        )
    }

    // MARK: - Living never mints into nothing

    func testAnOrdinaryReaderKeepsTheWholeMint() {
        let mint = BeliefEconomyPolicy.mint(1, readerBelief: 30)
        XCTAssertEqual(mint.toReader, 1)
        XCTAssertEqual(mint.overflow, 0)
        XCTAssertFalse(mint.isOverflowing)
    }

    func testAFullGaugeSendsTheWholeMintOutwardRatherThanDiscardingIt() {
        let mint = BeliefEconomyPolicy.mint(6, readerBelief: BeliefEconomyPolicy.readerCeiling)
        XCTAssertEqual(mint.toReader, 0)
        XCTAssertEqual(mint.overflow, 6, "a capped gauge must not swallow the reader's noticing")
    }

    func testAWellLitReaderSplitsTheMintWithTheWorld() {
        let floor = BeliefEconomyPolicy.readerOverflowFloor
        let mint = BeliefEconomyPolicy.mint(6, readerBelief: floor)
        XCTAssertEqual(mint.toReader, 3)
        XCTAssertEqual(mint.overflow, 3)
    }

    func testPastTheSoftCeilingASinglePointWarmsTheWorld() {
        let mint = BeliefEconomyPolicy.mint(1, readerBelief: BeliefEconomyPolicy.readerOverflowFloor + 5)
        XCTAssertEqual(mint.toReader, 0)
        XCTAssertEqual(mint.overflow, 1)
    }

    func testNoPointOfNoticingIsEverLost() {
        for belief in 0...BeliefEconomyPolicy.readerCeiling {
            for requested in 1...6 {
                let mint = BeliefEconomyPolicy.mint(requested, readerBelief: belief)
                XCTAssertEqual(
                    mint.toReader + mint.overflow,
                    requested,
                    "mint of \(requested) at \(belief) leaked"
                )
                XCTAssertGreaterThanOrEqual(mint.toReader, 0)
                XCTAssertGreaterThanOrEqual(mint.overflow, 0)
                XCTAssertLessThanOrEqual(
                    belief + mint.toReader,
                    BeliefEconomyPolicy.readerCeiling,
                    "the gauge must never exceed its ceiling"
                )
            }
        }
    }

    func testSpendsApplyWholeAndNeverOverflow() {
        for belief in [0, 30, BeliefEconomyPolicy.readerCeiling] {
            let mint = BeliefEconomyPolicy.mint(-5, readerBelief: belief)
            XCTAssertEqual(mint.toReader, -5)
            XCTAssertEqual(mint.overflow, 0)
        }
    }

    func testTheSoftCeilingConstantIsActuallyWired() {
        // It sat declared and unreferenced for a long time; this is the guard
        // against it drifting back out of use.
        XCTAssertEqual(BeliefEconomyPolicy.readerOverflowFloor, BeliefEconomyEngine.readerSoftCeiling)
        XCTAssertLessThan(BeliefEconomyPolicy.readerOverflowFloor, BeliefEconomyPolicy.readerCeiling)
        XCTAssertNotEqual(
            BeliefEconomyPolicy.mint(2, readerBelief: BeliefEconomyPolicy.readerOverflowFloor),
            BeliefEconomyPolicy.mint(2, readerBelief: BeliefEconomyPolicy.readerOverflowFloor - 1)
        )
    }

    // MARK: - The law is said out loud once

    func testTheFirstFictionSpendNamesWhereBeliefComesFrom() {
        let first = BeliefEconomyPolicy.generationSpendLine(for: .storyPage, isFirstSpend: true)
        XCTAssertTrue(first.contains("your own noticing"))
        XCTAssertTrue(first.contains("Story Page"))
    }

    func testLaterSpendsDoNotRepeatTheLesson() {
        let later = BeliefEconomyPolicy.generationSpendLine(for: .storyPage, isFirstSpend: false)
        XCTAssertFalse(later.contains("your own noticing"))
        XCTAssertTrue(later.contains("Story Page"))
    }
}
