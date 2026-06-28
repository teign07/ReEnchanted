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

        let moves = engine.moves(for: misty, in: scaffold)

        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy { $0.group == "ground" })
        // Every grounded swap is a recognised sense, so it lights the Body mark.
        for move in moves {
            XCTAssertTrue(engine.analyze("Dinner was \(move.word).").hasSensoryDetail, "\(move.word) should read as a sense")
        }
        // Applying any move heals the sentence in place.
        let healed = scaffold.replacing(tokenID: misty.id, with: moves[0].word, using: .core)
        XCTAssertEqual(healed.rendered, "Dinner was \(moves[0].word).")
    }

    func testMovesOnSenseOfferCrossedSenseLeap() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The cold mug waited.")
        let sense = scaffold.tokens.first { $0.word == "cold" }!

        let moves = engine.moves(for: sense, in: scaffold)

        XCTAssertTrue(moves.contains { $0.group == "cross" })
        XCTAssertFalse(moves.contains { $0.word == "cold" })
    }

    func testPlainWordsOfferNoMoves() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The mug waited.")
        let plain = scaffold.tokens.first { $0.word == "The" }!

        XCTAssertTrue(engine.moves(for: plain, in: scaffold).isEmpty)
    }

    // MARK: - Context-aware moves

    func testMovesReflectTheSentencesDominantTheme() {
        let engine = SentenceBuilderEngine()
        // "kettle" + "mug" pull the kitchen theme; the verb chips should lead with kitchen verbs.
        let scaffold = engine.scaffold(for: "The kettle and the mug sat.")
        let motionToken = scaffold.tokens.first { $0.word == "sat" } ?? scaffold.tokens.first { $0.word == "mug" }!

        XCTAssertEqual(engine.dominantTheme(in: scaffold)?.id, "kitchen")

        // For an anchor swap, kitchen anchors should surface before far-off ones.
        let mug = scaffold.tokens.first { $0.word == "mug" }!
        let anchorMoves = engine.moves(for: mug, in: scaffold)
        let kitchenWords: Set<String> = ["kettle", "cup", "spoon", "bowl", "sink", "counter", "saucer", "stove", "pan", "jar"]
        XCTAssertTrue(kitchenWords.contains(anchorMoves.first!.word), "expected a kitchen anchor first, got \(anchorMoves.first!.word)")
        _ = motionToken
    }

    func testMovesSkipWordsAlreadyInTheSentence() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The cold mug waited, cold.")
        let sense = scaffold.tokens.first { $0.word == "cold" }!

        let moves = engine.moves(for: sense, in: scaffold)

        // "mug" and "waited" are already used and must not be offered back.
        XCTAssertFalse(moves.contains { $0.word.lowercased() == "mug" })
        XCTAssertFalse(moves.contains { $0.word.lowercased() == "waited" })
    }

    func testMovesOfferMoreChipsThanBefore() {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The mug waited.")
        let mug = scaffold.tokens.first { $0.word == "mug" }!

        // The richer pools should comfortably fill the wider chip budget.
        XCTAssertGreaterThanOrEqual(engine.moves(for: mug, in: scaffold).count, 8)
    }

    // MARK: - Upgradeable packs (JSON merge)

    func testPartialJSONPackDecodesWithDefaults() throws {
        // An upgrade pack ships only the parts it wants to add.
        let json = """
        { "id": "pack.test", "concreteWords": ["telescope"], "availability": "userImported" }
        """.data(using: .utf8)!

        let pack = try JSONDecoder().decode(SentenceBuilderPack.self, from: json)

        XCTAssertEqual(pack.id, "pack.test")
        XCTAssertEqual(pack.concreteWords, ["telescope"])
        XCTAssertTrue(pack.displayName.isEmpty)   // defaulted, so merge keeps the base ritual name
        XCTAssertEqual(pack.version, 1)
        XCTAssertEqual(pack.availability, "userImported")
    }

    func testImportedPackAddsChipsAndThemeWithoutRenamingRitual() throws {
        let json = """
        {
          "id": "pack.ocean",
          "concreteWords": ["tide", "shell", "pier"],
          "sensoryWords": ["briny", "kelpy"],
          "themes": [{
            "id": "shore", "name": "Shore",
            "anchors": ["tide", "shell", "pier"],
            "senses": ["briny", "kelpy"], "verbs": ["waited"], "crossings": ["salt light"]
          }]
        }
        """.data(using: .utf8)!
        let importPack = try JSONDecoder().decode(SentenceBuilderPack.self, from: json)

        let composed = SentenceBuilderPack.core.merged(with: importPack)
        let engine = SentenceBuilderEngine(pack: composed)

        // Ritual identity is preserved (importer left it blank).
        XCTAssertEqual(composed.displayName, SentenceBuilderPack.core.displayName)
        // New anchors are live: a shore sentence finds its theme and offers shore chips.
        XCTAssertTrue(composed.concreteWords.contains("tide"))
        let scaffold = engine.scaffold(for: "The tide and the shell waited.")
        XCTAssertEqual(engine.dominantTheme(in: scaffold)?.id, "shore")
        let tide = scaffold.tokens.first { $0.word == "tide" }!
        XCTAssertTrue(engine.moves(for: tide, in: scaffold).contains { $0.word == "pier" || $0.word == "shell" })
    }

    func testStarterDraftRendersCompleteSentence() throws {
        let engine = SentenceBuilderEngine(pack: .core)

        let draft = try XCTUnwrap(engine.starterDraft(seed: "rainy-night"))
        let rendered = engine.render(draft)

        XCTAssertFalse(rendered.contains("{"))
        XCTAssertFalse(rendered.contains("}"))
        XCTAssertTrue(rendered.hasSuffix("."))
        XCTAssertTrue(engine.analyze(rendered).canStandAsComplete)
    }

    func testImportedPackCanAddStarterTemplates() throws {
        let json = """
        {
          "id": "pack.window",
          "starterTemplates": [{
            "id": "window-line",
            "title": "Window line",
            "pattern": "The {anchor} made the evening {sense}.",
            "slots": [
              { "id": "anchor", "kind": "anchor", "title": "Witness", "options": ["window"] },
              { "id": "sense", "kind": "sense", "title": "Feeling", "options": ["blue"] }
            ]
          }]
        }
        """.data(using: .utf8)!
        let importPack = try JSONDecoder().decode(SentenceBuilderPack.self, from: json)
        let composed = SentenceBuilderPack.core.merged(with: importPack)
        let engine = SentenceBuilderEngine(pack: composed)

        XCTAssertTrue(composed.starterTemplates.contains { $0.id == "window-line" })
        let draft = try XCTUnwrap(composed.starterTemplates.first { $0.id == "window-line" }.map {
            SentenceStarterDraft(template: $0, selections: ["anchor": "window", "sense": "blue"])
        })

        XCTAssertEqual(engine.render(draft), "The window made the evening blue.")
    }

    func testComposedCoreMergesEntitledExpansionPack() {
        // The locked bundled expansion is invisible until owned…
        PackEntitlements.ownedPackIDs.remove("pack.night-and-garden")
        SentenceBuilderPackRegistry.reload()
        XCTAssertFalse(SentenceBuilderPackRegistry.composedCore().concreteWords.contains("moth"))

        // …and its chips appear once unlocked.
        PackEntitlements.ownedPackIDs.insert("pack.night-and-garden")
        SentenceBuilderPackRegistry.reload()
        XCTAssertTrue(SentenceBuilderPackRegistry.composedCore().concreteWords.contains("moth"))
        XCTAssertTrue(SentenceBuilderPackRegistry.composedCore().themes.contains { $0.id == "garden" })

        // Clean up shared state for other tests.
        PackEntitlements.ownedPackIDs.remove("pack.night-and-garden")
        SentenceBuilderPackRegistry.reload()
    }

    func testReaderLexiconBuildsPersonalSentencePackFromRulings() {
        let now = Date(timeIntervalSinceReferenceDate: 10)
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "rain",
            originalSense: "water falling from clouds",
            newSense: "permission to rest",
            ruling: .adopted,
            category: .concrete,
            origin: .rebellion,
            ledAt: now,
            sourcePageID: "page-rain"
        ))
        lexicon.upsert(LexiconEntry(
            word: "hushed",
            originalSense: "made quiet",
            newSense: "held kindly under the tongue",
            ruling: .pardoned,
            category: .sensory,
            origin: .rebellion,
            ledAt: now
        ))
        lexicon.upsert(LexiconEntry(
            word: "obedient",
            originalSense: "submissive to rule",
            newSense: "unchanged",
            ruling: .recalled,
            category: .sensory,
            origin: .rebellion,
            ledAt: now
        ))
        lexicon.upsert(LexiconEntry(
            word: "elsewhere",
            originalSense: "some other place",
            newSense: "a margin door",
            ruling: .freed,
            category: .crossing,
            origin: .rebellion,
            ledAt: now
        ))

        let pack = lexicon.asSentenceBuilderPack()

        XCTAssertEqual(pack.id, "reader.lexicon")
        XCTAssertEqual(pack.availability, "personal")
        XCTAssertTrue(pack.concreteWords.contains("rain"))
        XCTAssertTrue(pack.sensoryWords.contains("hushed"))
        XCTAssertFalse(pack.sensoryWords.contains("obedient"))
        XCTAssertFalse(pack.crossingWords.contains("elsewhere"))
        XCTAssertTrue(pack.themes.contains { $0.id == "reader.lexicon.rain" && $0.senses == ["permission to rest"] })
    }

    func testReaderLexiconCanBeInjectedIntoComposedSentenceBuilderPack() {
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "thimble",
            originalSense: "a small metal sewing guard",
            newSense: "a tiny room for courage",
            ruling: .pardoned,
            category: .concrete,
            origin: .seeded,
            ledAt: Date(timeIntervalSinceReferenceDate: 11)
        ))

        let ordinary = SentenceBuilderPackRegistry.composed(onto: .core)
        let personal = SentenceBuilderPackRegistry.composed(onto: .core, readerLexicon: lexicon)
        let engine = SentenceBuilderEngine(pack: personal)

        XCTAssertFalse(ordinary.concreteWords.contains("thimble"))
        XCTAssertTrue(personal.concreteWords.contains("thimble"))
        XCTAssertTrue(engine.analyze("The thimble waited on the sill.").hasConcreteAnchor)
    }

    func testReaderLexiconUpsertKeepsOneRulingPerWord() {
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "Cold",
            originalSense: "low temperature",
            newSense: "a clean edge",
            ruling: .pardoned,
            category: .sensory,
            origin: .rebellion,
            ledAt: Date(timeIntervalSinceReferenceDate: 12)
        ))
        lexicon.upsert(LexiconEntry(
            word: "cold",
            originalSense: "low temperature",
            newSense: "the quiet after leaving",
            ruling: .adopted,
            category: .sensory,
            origin: .rebellion,
            ledAt: Date(timeIntervalSinceReferenceDate: 13)
        ))

        XCTAssertEqual(lexicon.entries.count, 1)
        XCTAssertEqual(lexicon.entries.first?.ruling, .adopted)
        XCTAssertEqual(lexicon.entries.first?.newSense, "the quiet after leaving")
    }

    func testReaderLexiconThemeEntriesRemainVisibleToSentenceAnalysis() {
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "almost",
            originalSense: "not quite",
            newSense: "a door deciding",
            ruling: .adopted,
            category: .theme,
            origin: .rebellion,
            ledAt: Date(timeIntervalSinceReferenceDate: 15)
        ))

        let pack = SentenceBuilderPackRegistry.composed(onto: .core, readerLexicon: lexicon)
        let engine = SentenceBuilderEngine(pack: pack)
        let scaffold = engine.scaffold(for: "Almost waited beside me.")

        XCTAssertTrue(pack.concreteWords.contains("almost"))
        XCTAssertTrue(engine.analyze("Almost waited beside me.").hasConcreteAnchor)
        XCTAssertEqual(engine.dominantTheme(in: scaffold)?.id, "reader.lexicon.almost")
    }

    func testLexiconEntryStableIDDoesNotCollapsePunctuationOnlyWords() {
        XCTAssertEqual(LexiconEntry.stableID(for: " cold "), "cold")
        XCTAssertEqual(LexiconEntry.stableID(for: "?!"), "word-3f-21")
        XCTAssertEqual(LexiconEntry.stableID(for: "   "), "word-empty")
    }

    func testReaderLexiconSettlesDirectionalTreatyFromRulings() {
        let ruledAt = Date(timeIntervalSinceReferenceDate: 21)
        var restoration = ReaderLexicon()
        restoration.upsert(LexiconEntry(word: "almost", originalSense: "not quite", newSense: nil, ruling: .recalled, category: .theme, origin: .rebellion, ledAt: ruledAt))
        restoration.upsert(LexiconEntry(word: "pencil", originalSense: "writing tool", newSense: nil, ruling: .recalled, category: .concrete, origin: .rebellion, ledAt: ruledAt))
        restoration.upsert(LexiconEntry(word: "bell", originalSense: "ringing object", newSense: "a warning that wants tea", ruling: .adopted, category: .concrete, origin: .rebellion, ledAt: ruledAt))

        var reformation = ReaderLexicon()
        reformation.upsert(LexiconEntry(word: "almost", originalSense: "not quite", newSense: nil, ruling: .recalled, category: .theme, origin: .rebellion, ledAt: ruledAt))
        reformation.upsert(LexiconEntry(word: "pencil", originalSense: "writing tool", newSense: "a wand with homework", ruling: .pardoned, category: .concrete, origin: .rebellion, ledAt: ruledAt))
        reformation.upsert(LexiconEntry(word: "bell", originalSense: "ringing object", newSense: "a warning that wants tea", ruling: .adopted, category: .concrete, origin: .rebellion, ledAt: ruledAt))

        var secession = ReaderLexicon()
        secession.upsert(LexiconEntry(word: "almost", originalSense: "not quite", newSense: "a door deciding", ruling: .freed, category: .theme, origin: .rebellion, ledAt: ruledAt))
        secession.upsert(LexiconEntry(word: "pencil", originalSense: "writing tool", newSense: "a wand with homework", ruling: .freed, category: .concrete, origin: .rebellion, ledAt: ruledAt))
        secession.upsert(LexiconEntry(word: "bell", originalSense: "ringing object", newSense: "a warning that wants tea", ruling: .pardoned, category: .concrete, origin: .rebellion, ledAt: ruledAt))

        XCTAssertNil(restoration.treatyOutcome(minimumRulings: 4))
        XCTAssertEqual(restoration.treatyOutcome(), .restoration)
        XCTAssertEqual(reformation.treatyOutcome(), .reformation)
        XCTAssertEqual(secession.treatyOutcome(), .secession)

        secession.settleTreatyIfReady()
        XCTAssertEqual(secession.treaty, .secession)
    }

    func testInsideCoverStateDefaultsMissingReaderLexiconForOldSaves() throws {
        let json = """
        {
          "generatedAt": "old",
          "player": "Reader",
          "title": "ReEnchanted",
          "day": "Today",
          "block": "Morning",
          "now": "Open",
          "next": "Next",
          "club": "",
          "practice": "Notice",
          "practicePrompt": "Write one line.",
          "note": "A previous save.",
          "image": "",
          "openURL": "telegram://"
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(InsideCoverState.self, from: json)

        XCTAssertTrue(state.readerLexicon.entries.isEmpty)
        XCTAssertNil(state.readerLexicon.treaty)
        XCTAssertFalse(state.readerLexicon.bargainSeedSurfaced)
    }

    func testInsideCoverStateStillRejectsStructurallyBrokenSaves() {
        let json = """
        {
          "generatedAt": "broken",
          "player": "Reader"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(InsideCoverState.self, from: json))
    }

    func testInsideCoverStateRoundTripsReaderLexicon() throws {
        var state = InsideCoverState.fallback
        state.readerLexicon.treaty = .reformation
        state.readerLexicon.bargainSeedSurfaced = true
        state.readerLexicon.upsert(LexiconEntry(
            word: "almost",
            originalSense: "not quite",
            newSense: "a door deciding",
            ruling: .adopted,
            category: .theme,
            origin: .rebellion,
            ledAt: Date(timeIntervalSinceReferenceDate: 14),
            sourcePageID: "page-almost"
        ))

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(InsideCoverState.self, from: data)

        XCTAssertEqual(decoded.readerLexicon, state.readerLexicon)
        XCTAssertEqual(decoded.readerLexicon.asSentenceBuilderPack().themes.first?.id, "reader.lexicon.almost")
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
