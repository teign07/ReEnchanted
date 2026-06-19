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

    // MARK: - Scaffold (grammar-safe transform model)

    func testScaffoldRoundTripsTheUsersOwnText() {
        let engine = SentenceBuilderEngine()
        let original = "The mug waited on the cold table."

        XCTAssertEqual(engine.scaffold(for: original).rendered, original)
    }

    func testScaffoldRoundTripsLeadingAndIrregularSpacing() {
        let engine = SentenceBuilderEngine()
        let original = "  The rain  clicked, twice.  "

        XCTAssertEqual(engine.scaffold(for: original).rendered, original)
    }

    func testScaffoldTagsCraftRolesFromPackVocabulary() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The cold mug waited.")

        func role(_ word: String) -> SentenceRole? {
            scaffold.tokens.first { $0.word == word }?.role
        }
        XCTAssertEqual(role("cold"), .sense)
        XCTAssertEqual(role("mug"), .thing)
        XCTAssertEqual(role("waited"), .motion)
        XCTAssertEqual(role("The"), .plain)
    }

    func testScaffoldTagsMistyAndSmokeWords() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "Dinner was nice and cosmic.")

        XCTAssertEqual(scaffold.tokens.first { $0.word == "nice" }?.role, .misty)
        XCTAssertEqual(scaffold.tokens.first { $0.word == "cosmic" }?.role, .smoke)
    }

    func testReplacingTokenIsGrammarSafeAndPreservesPunctuation() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "Dinner was nice.")
        guard let misty = scaffold.tokens.first(where: { $0.role == .misty }) else {
            return XCTFail("expected a misty token")
        }

        let healed = scaffold.replacing(tokenID: misty.id, with: "warm", using: .core)

        XCTAssertEqual(healed.rendered, "Dinner was warm.")
        XCTAssertEqual(healed.tokens.first { $0.word == "warm" }?.role, .sense)
    }

    func testMovesGroundMistyWordsIntoSenses() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "Dinner was tired.")
        let misty = scaffold.tokens.first { $0.role == .misty }!

        let moves = engine.moves(for: misty)

        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy { $0.group == "ground" })
        // Applying any move heals the sentence in place.
        let healed = scaffold.replacing(tokenID: misty.id, with: moves[0].word, using: .core)
        XCTAssertEqual(healed.rendered, "Dinner was \(moves[0].word).")
    }

    func testMovesOnSenseOfferCrossedSenseLeap() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The cold mug waited.")
        let sense = scaffold.tokens.first { $0.word == "cold" }!

        let moves = engine.moves(for: sense)

        XCTAssertTrue(moves.contains { $0.group == "cross" })
        XCTAssertFalse(moves.contains { $0.word == "cold" })
    }

    func testPlainWordsOfferNoMoves() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The mug waited.")
        let plain = scaffold.tokens.first { $0.word == "The" }!

        XCTAssertTrue(engine.moves(for: plain).isEmpty)
    }

    func testReplacingTokenRetagsSoHighlightingStaysHonest() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The cup sat there.")
        guard let cup = scaffold.tokens.first(where: { $0.word == "cup" }) else {
            return XCTFail("expected an anchor token")
        }

        // Swapping one craft word for another keeps the sentence intact — no jumble possible.
        let swapped = scaffold.replacing(tokenID: cup.id, with: "kettle", using: .core)

        XCTAssertEqual(swapped.rendered, "The kettle sat there.")
        XCTAssertTrue(swapped.presentRoles.contains(.thing))
    }
}
