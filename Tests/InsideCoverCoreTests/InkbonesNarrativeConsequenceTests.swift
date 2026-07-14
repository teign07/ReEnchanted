import XCTest
@testable import InsideCoverCore

final class InkbonesNarrativeConsequenceTests: XCTestCase {
    func testStandardStoryThrowUsesFiveNarrativeBandsAtTheExpectedBoundaries() {
        let threshold = BeliefCombatResolver.finalThreshold(for: 50, difficulty: .standard)

        XCTAssertEqual(threshold, 62)
        XCTAssertEqual(StoryInkbonesResolution(roll: 5, threshold: threshold).band, .triumph)
        XCTAssertEqual(StoryInkbonesResolution(roll: 6, threshold: threshold).band, .favor)
        XCTAssertEqual(StoryInkbonesResolution(roll: 62, threshold: threshold).band, .favor)
        XCTAssertEqual(StoryInkbonesResolution(roll: 63, threshold: threshold).band, .hesitate)
        XCTAssertEqual(StoryInkbonesResolution(roll: 72, threshold: threshold).band, .hesitate)
        XCTAssertEqual(StoryInkbonesResolution(roll: 73, threshold: threshold).band, .sideways)
        XCTAssertEqual(StoryInkbonesResolution(roll: 95, threshold: threshold).band, .sideways)
        XCTAssertEqual(StoryInkbonesResolution(roll: 96, threshold: threshold).band, .cost)
    }

    func testCostResolutionPromptCarriesMechanicEvidenceAndBindingNarrativeDirection() {
        let resolution = StoryInkbonesResolution(roll: 97, threshold: 62)
        let section = resolution.narrativePromptSection(
            committedLanding: "Mara receives the key and agrees to open the west cabinet.",
            effectLine: "Ask Mara to take the key."
        )

        XCTAssertEqual(resolution.band, .cost)
        XCTAssertTrue(section.contains("Belief roll: 97 against 62"))
        XCTAssertTrue(section.contains("Mara receives the key"))
        XCTAssertTrue(section.contains("spent, broken, owed, or overheard"))
        XCTAssertTrue(section.contains("Do not mention dice, rolls, thresholds"))
    }

    func testFallbackPreservesPreparedResultLandingAndBandConsequenceWithoutBecomingARollLabel() {
        let resolution = StoryInkbonesResolution(roll: 68, threshold: 62)
        let fallback = resolution.fallbackConsequence(
            preparedResult: "Mara reaches for the cabinet, then stops with her hand above the latch.",
            committedLanding: "Mara agrees to open the cabinet after one promise is made.",
            effectLine: "Ask Mara to open it."
        )

        XCTAssertEqual(resolution.band, .hesitate)
        XCTAssertTrue(fallback.contains("Mara reaches for the cabinet"))
        XCTAssertTrue(fallback.contains("Mara agrees to open the cabinet"))
        XCTAssertTrue(fallback.contains(resolution.band.fallbackClosingLine))
        XCTAssertFalse(fallback.contains("Belief roll:"))
    }

    func testGeneratedCostConsequenceGetsSafetyBeatOnlyWhenWriterMissesTheBand() {
        let resolution = StoryInkbonesResolution(roll: 99, threshold: 62)
        let unshaped = "Mara opens the cabinet and hands over the letter. The scene moves on."
        let alreadyShaped = "Mara opens the cabinet, but now she is owed the answer she asked for."

        XCTAssertEqual(
            resolution.ensuringNarrativeBand(in: unshaped),
            unshaped + "\n\n" + resolution.band.fallbackClosingLine
        )
        XCTAssertEqual(resolution.ensuringNarrativeBand(in: alreadyShaped), alreadyShaped)
    }

    func testCriticalCostWinsOverNearThresholdBandAtHighThresholds() {
        XCTAssertEqual(StoryInkbonesResolution(roll: 96, threshold: 90).band, .cost)
        XCTAssertEqual(StoryInkbonesResolution(roll: 95, threshold: 90).band, .hesitate)
    }
}
