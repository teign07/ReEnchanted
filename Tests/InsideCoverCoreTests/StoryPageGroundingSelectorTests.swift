import XCTest
@testable import InsideCoverCore

private struct StoryGroundingTestScorer: StacksSemanticScoring {
    var modelID: String { "story-grounding-test" }
    var matches: [String: Double]
    var fallback: Double = 0.05

    func similarity(between query: String, and document: String) -> Double? {
        let lowered = document.lowercased()
        return matches.first { lowered.contains($0.key.lowercased()) }?.value ?? fallback
    }
}

final class StoryPageGroundingSelectorTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func page(
        _ id: String,
        text: String,
        daysAgo: Double,
        type: BookPageType = .diary,
        origin: BookPageOrigin = .userAuthored,
        tags: [String] = []
    ) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: now.addingTimeInterval(-daysAgo * 86_400),
            promptText: "Keep what mattered.",
            userInput: text,
            tags: tags,
            origin: origin
        )
    }

    func testSemanticRelevanceCanChooseAnOlderMeaningfulPageOverTheNewestKeep() throws {
        let newest = page(
            "newest",
            text: "The brass kettle clicked twice while rain pressed against the kitchen window.",
            daysAgo: 1
        )
        let relevant = page(
            "repair",
            text: "I finally apologized to Mara, and the silence between us became somewhere we could stand together.",
            daysAgo: 24
        )
        let scorer = StoryGroundingTestScorer(matches: ["apologized to mara": 0.86])

        let selection = try XCTUnwrap(MeaningfulPassageSelector.select(
            pages: [newest, relevant],
            query: "friendship repair apology trust after an argument",
            inputs: .empty,
            scorer: scorer,
            now: now
        ))

        XCTAssertEqual(selection.pageID, "repair")
        XCTAssertTrue(selection.excerpt.contains("apologized"))
        XCTAssertGreaterThan(selection.semanticSimilarity ?? 0, 0.8)
    }

    func testSelectorFindsTheResonantMiddlePassageInsteadOfTakingTheFirstLine() throws {
        let kept = page(
            "middle",
            text: "I washed the cups before bed. I left the porch light on because coming home should not require bravery. The cat stole my chair afterward.",
            daysAgo: 7
        )
        let scorer = StoryGroundingTestScorer(matches: ["porch light": 0.91])

        let selection = try XCTUnwrap(MeaningfulPassageSelector.select(
            pages: [kept],
            query: "homecoming safety welcome and small acts of care",
            inputs: .empty,
            scorer: scorer,
            now: now
        ))

        XCTAssertTrue(selection.excerpt.contains("porch light"))
        XCTAssertNotEqual(selection.excerpt, "I washed the cups before bed.")
    }

    func testSalienceFallbackRejectsAThinNewestPageForSpecificProse() throws {
        let thin = page("thin", text: "It was fine.", daysAgo: 0.1)
        let vivid = page(
            "vivid",
            text: "Nothing much happened. The wet red mitten on the bus seat kept pointing toward the empty door. I carried that small accusation home.",
            daysAgo: 18
        )

        let selection = try XCTUnwrap(MeaningfulPassageSelector.select(
            pages: [thin, vivid],
            query: "an ordinary object becomes evidence",
            inputs: .empty,
            scorer: nil,
            now: now
        ))

        XCTAssertEqual(selection.pageID, "vivid")
        XCTAssertTrue(selection.excerpt.contains("mitten") || selection.excerpt.contains("accusation"))
    }

    func testSelectorLeavesOnlyThinGenericKeepsAlone() {
        let thin = page("thin", text: "It was fine.", daysAgo: 0.1)

        let selection = MeaningfulPassageSelector.select(
            pages: [thin],
            query: "friendship repair and trust",
            inputs: .empty,
            scorer: nil,
            now: now
        )

        XCTAssertNil(selection)
    }

    func testSelectorSkipsPrivateGeneratedAndAlreadyUsedSources() throws {
        let body = page(
            "body-private",
            text: "The silver pulse in my wrist sounded like a locked gate opening.",
            daysAgo: 2,
            type: .body
        )
        let generated = page(
            "generated",
            text: "The perfect lantern waited at the threshold.",
            daysAgo: 3,
            origin: .generated
        )
        let alreadyUsed = page(
            "used-source",
            text: "The blue envelope held the exact answer everyone needed.",
            daysAgo: 4
        )
        let storyUsingIt = page(
            "prior-story",
            text: "A prior story page.",
            daysAgo: 1,
            type: .narrativeOS,
            origin: .simulated,
            tags: ["\(MeaningfulPassageSelector.sourceTagPrefix)used-source"]
        )
        let eligible = page(
            "eligible",
            text: "I found a bent library card under the radiator and kept it for no sensible reason.",
            daysAgo: 12
        )
        let scorer = StoryGroundingTestScorer(matches: [
            "silver pulse": 0.99,
            "perfect lantern": 0.98,
            "blue envelope": 0.97,
            "library card": 0.70
        ])

        let selection = try XCTUnwrap(MeaningfulPassageSelector.select(
            pages: [body, generated, alreadyUsed, storyUsingIt, eligible],
            query: "an object becomes evidence",
            inputs: .empty,
            scorer: scorer,
            now: now
        ))

        XCTAssertEqual(selection.pageID, "eligible")
    }

    func testStoryPacketCarriesSemanticSelectionReasonAndChosenPassage() throws {
        let newest = page(
            "ordinary-new",
            text: "The coffee cooled beside the open book while the clock ticked.",
            daysAgo: 1
        )
        let resonant = page(
            "resonant-old",
            text: "I folded the apology into the green scarf. It was easier to carry once it had a shape.",
            daysAgo: 20
        )
        let calendar = Calendar.current
        let day = BookDay(
            id: BookDay.id(for: now, calendar: calendar),
            date: calendar.startOfDay(for: now),
            pages: []
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [newest, resonant].map { page in
            BookDay(
                id: BookDay.id(for: page.createdAt, calendar: calendar),
                date: calendar.startOfDay(for: page.createdAt),
                pages: [page]
            )
        }
        inputs.storyRecipeBoosts = ["grey-edit": 12]
        inputs.storySceneBiases = [StoryRecipe.worldLedTag: -12]
        let scorer = StoryGroundingTestScorer(matches: ["folded the apology": 0.89])

        let packet = StoryScenePacketBuilder.packet(
            for: day,
            inputs: inputs,
            now: now,
            semanticScorer: scorer
        )
        let grounding = try XCTUnwrap(packet.blueprint?.grounding)

        XCTAssertEqual(grounding.kind, .keptPage)
        XCTAssertEqual(grounding.sourceID, "resonant-old")
        XCTAssertTrue(grounding.text.contains("apology"))
        XCTAssertTrue(grounding.selectionReason?.contains("semantic relevance") == true)
        XCTAssertTrue(grounding.selectionReason?.contains("89%") == true)
    }
}
