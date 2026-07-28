import XCTest
@testable import InsideCoverCore

/// Closing the loop between the two taste models. The Curator picks one of four
/// recipe variants, but the engine that *builds* those four used to narrow ~35
/// recipes on consequence-derived boosts alone — it never heard what the reader
/// actually did. A recipe someone reliably kept and walked outside after could
/// not improve its odds of being offered at all.
final class StoryRecipeLearningLoopTests: XCTestCase {

    private func event(
        _ action: ReaderLearningAction,
        recipeID: String,
        lane: String,
        at date: Date,
        index: Int
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: "\(action.rawValue)-\(recipeID)-\(index)",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: action,
            surfaceID: "\(recipeID)-\(index)",
            sourceID: "narrative-os",
            type: .narrativeOS,
            varietyKey: "narrative-os",
            hour: 10,
            tags: ["recipe:\(recipeID)", "lane:\(lane)"]
        )
    }

    private func model(
        _ entries: [(ReaderLearningAction, String, String)],
        repeated: Int = 4
    ) -> ReaderLearningModel {
        var model = ReaderLearningModel()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<repeated {
            let at = start.addingTimeInterval(Double(index) * 86_400)
            for (action, recipeID, lane) in entries {
                model.record(event(action, recipeID: recipeID, lane: lane, at: at, index: index))
            }
        }
        return model
    }

    // MARK: - The reader's history now reaches recipe selection

    func testARecipeTheReaderCrossedForOutranksOneTheyOnlyAdmired() {
        let learned = model([
            (.followedThread, "night-errand", "world-led"),
            (.loved, "dorm-room-visit", "grounded")
        ])
        XCTAssertGreaterThan(
            learned.storyRecipeAffinity(recipeID: "night-errand", lane: "world-led"),
            learned.storyRecipeAffinity(recipeID: "dorm-room-visit", lane: "grounded")
        )
    }

    func testARecipeTheReaderKeepsSendingAwayIsArguedAgainst() {
        let learned = model([(.dismissed, "tiny-heist", "world-led")])
        XCTAssertLessThan(learned.storyRecipeAffinity(recipeID: "tiny-heist", lane: "world-led"), 0)
    }

    func testAnUnknownRecipeIsNeitherHelpedNorPunished() {
        XCTAssertEqual(
            ReaderLearningModel().storyRecipeAffinity(recipeID: "never-seen", lane: "grounded"),
            0
        )
    }

    /// Lane evidence should carry a recipe the reader has never met — that is
    /// the whole point of making the lane learnable.
    func testLanePreferenceLiftsAnUnseenRecipeInThatLane() {
        let learned = model([(.keepsakeEarned, "night-errand", "world-led")])
        let unseenInLovedLane = learned.storyRecipeAffinity(recipeID: "brand-new", lane: "world-led")
        let unseenElsewhere = learned.storyRecipeAffinity(recipeID: "brand-new", lane: "grounded")
        XCTAssertGreaterThan(unseenInLovedLane, 0)
        XCTAssertEqual(unseenElsewhere, 0)
        XCTAssertGreaterThan(unseenInLovedLane, unseenElsewhere)
    }

    func testTheRecipeOutweighsItsLane() {
        // A disliked recipe inside a loved lane must still be argued against.
        var learned = model([(.keepsakeEarned, "night-errand", "world-led")])
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        for index in 0..<6 {
            learned.record(event(.dismissed, recipeID: "tiny-heist", lane: "world-led",
                                 at: start.addingTimeInterval(Double(index) * 86_400), index: 100 + index))
        }
        XCTAssertLessThan(
            learned.storyRecipeAffinity(recipeID: "tiny-heist", lane: "world-led"),
            learned.storyRecipeAffinity(recipeID: "night-errand", lane: "world-led")
        )
    }

    func testTheReturnPathCannotOverpowerDiscovery() {
        let adored = model([(.keepsakeEarned, "night-errand", "world-led")], repeated: 40)
        XCTAssertLessThanOrEqual(
            adored.storyRecipeAffinity(recipeID: "night-errand", lane: "world-led"),
            ReaderLearningModel.storyAffinityCeiling
        )
        let loathed = model([(.missed, "tiny-heist", "grounded")], repeated: 40)
        XCTAssertGreaterThanOrEqual(loathed.storyRecipeAffinity(recipeID: "tiny-heist", lane: "grounded"), -12)
    }

    /// The points above the taste ceiling are crossing-only, so a recipe the
    /// reader merely adores cannot become as likely to be offered as one they
    /// acted on.
    func testAdmirationAloneCannotReachTheCrossingCeiling() {
        let adored = model([(.loved, "dorm-room-visit", "grounded")], repeated: 40)
        XCTAssertLessThanOrEqual(
            adored.storyRecipeAffinity(recipeID: "dorm-room-visit", lane: "grounded"),
            ReaderLearningModel.storyTasteCeiling
        )
        let crossed = model([(.keepsakeEarned, "night-errand", "world-led")], repeated: 40)
        XCTAssertGreaterThan(
            crossed.storyRecipeAffinity(recipeID: "night-errand", lane: "world-led"),
            ReaderLearningModel.storyTasteCeiling
        )
    }

    // MARK: - Exploration narrows as the Book learns

    func testAnUnknownRecipeKeepsTheFullExplorationWidth() {
        XCTAssertEqual(ReaderLearningModel().storyExplorationWidth(recipeID: "never-seen"), 5)
    }

    func testExplorationClosesAsTheReaderAnswers() {
        let widths = (0...6).map { count -> Int in
            model([(.kept, "night-errand", "world-led")], repeated: count)
                .storyExplorationWidth(recipeID: "night-errand")
        }
        XCTAssertEqual(widths.first, 5)
        // Monotonically narrowing, never inverting.
        for (earlier, later) in zip(widths, widths.dropFirst()) {
            XCTAssertGreaterThanOrEqual(earlier, later)
        }
        XCTAssertLessThan(widths.last!, widths.first!)
    }

    /// The width must never reach zero: `% width` would trap, and the Book
    /// should keep a sliver of surprise even about a settled preference.
    func testExplorationNeverClosesCompletely() {
        for count in [0, 1, 5, 20, 200] {
            let width = model([(.kept, "night-errand", "world-led")], repeated: count)
                .storyExplorationWidth(recipeID: "night-errand")
            XCTAssertGreaterThanOrEqual(width, 1, "width collapsed at \(count) signals")
        }
    }

    func testExplorationIsDeterministicForTheSameDayAndSlot() {
        // The shelf is seeded by day and slot, so the same afternoon always
        // offers the same four. This is the property that keeps the Book from
        // reading as a slot machine.
        let seedA = abs("2026-07-26-slot3-night-errand-recipe".stableHash % 5)
        let seedB = abs("2026-07-26-slot3-night-errand-recipe".stableHash % 5)
        XCTAssertEqual(seedA, seedB)
    }
}
