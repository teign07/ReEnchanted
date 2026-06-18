import XCTest
@testable import InsideCoverCore

final class SentenceBuilderTests: XCTestCase {
    func testVagueWordsBecomeCutMistNudges() {
        let engine = SentenceBuilderEngine()

        let nudge = engine.nudge(for: "Dinner was nice.")

        XCTAssertEqual(nudge.step.kind, .cutMist)
        XCTAssertEqual(nudge.highlightedWord, "nice")
        XCTAssertTrue(nudge.step.question.contains("texture"))
    }

    func testBuilderAdvancesThroughCraftMoves() {
        let engine = SentenceBuilderEngine()

        XCTAssertEqual(engine.nudge(for: "I walked home.").step.kind, .anchor)
        XCTAssertEqual(engine.nudge(for: "I walked home.", completedKinds: [.anchor]).step.kind, .sense)
        XCTAssertEqual(engine.nudge(for: "I walked home.", completedKinds: [.anchor, .sense]).step.kind, .motion)
        XCTAssertEqual(engine.nudge(for: "I walked home.", completedKinds: [.anchor, .sense, .motion]).step.kind, .crossing)
    }

    func testConcreteTextCanStandAsComplete() {
        let engine = SentenceBuilderEngine()

        let nudge = engine.nudge(for: "The mug left a warm ring on the table.")

        XCTAssertTrue(nudge.canStandAsComplete)
    }

    func testAnalysisFindsCoreCraftMarks() {
        let engine = SentenceBuilderEngine()

        let analysis = engine.analyze("The mug waited in a cold blue sound.")

        XCTAssertTrue(analysis.hasConcreteAnchor)
        XCTAssertTrue(analysis.hasSensoryDetail)
        XCTAssertTrue(analysis.hasLivingMotion)
        XCTAssertTrue(analysis.hasCrossedSense)
        XCTAssertEqual(analysis.memoryStrength, 4)
        XCTAssertTrue(analysis.isVivid)
    }

    func testNudgeSkipsAlreadyPresentCraftMoves() {
        let engine = SentenceBuilderEngine()

        let nudge = engine.nudge(for: "The mug waited on the table.")

        XCTAssertEqual(nudge.step.kind, .sense)
    }

    func testAvoidWordsPromptGroundedMagicBeforeOrdinarySteps() {
        let engine = SentenceBuilderEngine()

        let nudge = engine.nudge(for: "The room felt cosmic.")

        XCTAssertEqual(nudge.step.kind, .groundGlow)
        XCTAssertEqual(nudge.highlightedWord, "cosmic")
        XCTAssertTrue(engine.analyze("The room felt cosmic.").diagnostics.contains { $0.word == "cosmic" })
    }

    func testContentPacksMergeOverlayStepsAndVocabulary() {
        let pack = SentenceBuilderPack.core.merged(with: .souvenir)
        let engine = SentenceBuilderEngine(pack: pack)

        XCTAssertEqual(pack.displayName, "Souvenir Sentence")
        XCTAssertEqual(pack.ritualTitle, "Steal the diamond")
        XCTAssertTrue(pack.replayPrompt.contains("single best feeling"))
        XCTAssertTrue(pack.concreteWords.contains("ticket"))
        XCTAssertEqual(pack.steps.first { $0.kind == .anchor }?.id, "souvenir-anchor")
        XCTAssertTrue(engine.analyze("The ticket stayed damp in my pocket.").hasConcreteAnchor)
        XCTAssertTrue(engine.analyze("The ticket stayed damp in my pocket.").hasLivingMotion)
    }

    func testChipsPreferUnusedWords() {
        let engine = SentenceBuilderEngine()
        let step = SentenceBuilderPack.core.steps[0]

        let chips = engine.chips(for: step, text: "The glass was already there.")

        XCTAssertFalse(chips.contains("glass"))
        XCTAssertTrue(chips.contains("door"))
    }

    func testAlchemyLevelsTrackSentenceStrength() {
        let engine = SentenceBuilderEngine()

        XCTAssertTrue(engine.alchemyLevels(for: "It was good.").first { $0.id == "label" }?.isCurrent == true)
        XCTAssertTrue(engine.alchemyLevels(for: "The mug was warm.").first { $0.id == "hook" }?.isCurrent == true)
        XCTAssertTrue(engine.alchemyLevels(for: "The mug waited in a warm blue sound.").first { $0.id == "spell" }?.isCurrent == true)
    }

    func testSouvenirShareTextUsesNativeSharePayload() {
        let engine = SentenceBuilderEngine()

        XCTAssertEqual(engine.souvenirShareText(for: "  The rain smelled green.  "), "The rain smelled green.\n\n— One-Sentence Souvenir")
        XCTAssertEqual(engine.souvenirShareText(for: "   "), "")
    }

    func testAppendKeepsUserTextEditableAndSimple() {
        let engine = SentenceBuilderEngine()

        XCTAssertEqual(engine.append("rain", to: ""), "rain")
        XCTAssertEqual(engine.append("rain", to: "I walked home"), "I walked home rain")
        XCTAssertEqual(engine.append("rain", to: "I walked home,"), "I walked home, rain")
    }

    func testAvoidWordsAreDetectedForPackGuardrails() {
        let engine = SentenceBuilderEngine()

        XCTAssertEqual(engine.hasAvoidWord("A cosmic tapestry of feeling."), "cosmic")
        XCTAssertNil(engine.hasAvoidWord("The cup clicked on the table."))
    }
}
