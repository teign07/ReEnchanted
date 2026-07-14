import XCTest
@testable import InsideCoverCore

final class SentenceBuilderTests: XCTestCase {
    func testConcreteTextCanStandAsComplete() {
        let engine = SentenceBuilderEngine()

        let analysis = engine.analyze("The mug left a warm ring on the table.")

        XCTAssertTrue(analysis.canStandAsComplete)
    }

    func testAnalysisFindsCoreCraftMarks() {
        let engine = SentenceBuilderEngine()

        let analysis = engine.analyze("The mug waited in a cold blue sound.")

        XCTAssertTrue(analysis.hasConcreteAnchor)
        XCTAssertTrue(analysis.hasSensoryDetail)
        XCTAssertTrue(analysis.hasLivingMotion)
        XCTAssertTrue(analysis.hasWorldActor)
        XCTAssertTrue(analysis.hasCrossedSense)
        XCTAssertEqual(analysis.memoryStrength, 4)
        XCTAssertTrue(analysis.isVivid)
    }

    func testAnalysisDetectsWorldActor() {
        let engine = SentenceBuilderEngine()

        XCTAssertTrue(engine.analyze("The bench caught my weight.").hasWorldActor)
        XCTAssertTrue(engine.analyze("The door waited in the rain.").hasWorldActor)
        XCTAssertTrue(engine.analyze("The mug kept the light.").hasWorldActor)
    }

    func testAnalysisDoesNotTreatReaderAsWorldActor() {
        let engine = SentenceBuilderEngine()

        XCTAssertFalse(engine.analyze("I saw the bench and waited.").hasWorldActor)
        XCTAssertFalse(engine.analyze("I carried the mug.").hasWorldActor)
        XCTAssertFalse(engine.analyze("The mug was warm.").hasWorldActor)
    }

    func testAvoidWordsPromptGroundedMagicBeforeOrdinarySteps() {
        let engine = SentenceBuilderEngine()

        XCTAssertTrue(engine.analyze("The room felt cosmic.").diagnostics.contains { $0.word == "cosmic" })
        XCTAssertEqual(engine.scaffold(for: "The room felt cosmic.").tokens.first { $0.word == "cosmic" }?.role, .smoke)
    }

    func testContentPacksMergeOverlayStepsAndVocabulary() {
        let pack = SentenceBuilderPack.core.merged(with: .souvenir)
        let engine = SentenceBuilderEngine(pack: pack)

        XCTAssertEqual(pack.displayName, "Souvenir Sentence")
        XCTAssertEqual(pack.ritualTitle, "Steal the diamond")
        XCTAssertTrue(pack.replayPrompt.contains("single best feeling"))
        XCTAssertTrue(pack.concreteWords.contains("ticket"))
        XCTAssertTrue(engine.analyze("The ticket stayed damp in my pocket.").hasConcreteAnchor)
        XCTAssertTrue(engine.analyze("The ticket stayed damp in my pocket.").hasLivingMotion)
    }

    func testSouvenirShareTextUsesNativeSharePayload() {
        let engine = SentenceBuilderEngine()

        XCTAssertEqual(engine.souvenirShareText(for: "  The rain smelled green.  "), "The rain smelled green.\n\n— One-Sentence Souvenir")
        XCTAssertEqual(engine.souvenirShareText(for: "   "), "")
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

    func testMoreMovesKeepsContextLeadersAndRotatesTheOtherSlots() throws {
        let engine = SentenceBuilderEngine(
            context: SentenceBuilderContext(prompt: "Remember the train ticket on the platform.")
        )
        let scaffold = engine.scaffold(for: "The mug waited.")
        let mug = try XCTUnwrap(scaffold.tokens.first { $0.word == "mug" })
        let firstPage = engine.moves(for: mug, in: scaffold)
        let shown = Set(firstPage.map { $0.word.lowercased() })
        let secondPage = engine.moves(for: mug, in: scaffold, avoiding: shown)

        XCTAssertEqual(firstPage.prefix(2).map(\.word), secondPage.prefix(2).map(\.word))
        XCTAssertTrue(Set(firstPage.dropFirst(2).map(\.word)).isDisjoint(with: secondPage.dropFirst(2).map(\.word)))
    }

    func testMoreMovesCyclesEntirePoolWhenThereIsNoContextToPin() throws {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "The phone waited.")
        let phone = try XCTUnwrap(scaffold.tokens.first { $0.word == "phone" })
        let firstPage = engine.moves(for: phone, in: scaffold)
        let secondPage = engine.moves(
            for: phone,
            in: scaffold,
            avoiding: Set(firstPage.map { $0.word.lowercased() })
        )

        XCTAssertEqual(firstPage.count, 8)
        XCTAssertEqual(secondPage.count, 8)
        XCTAssertTrue(Set(firstPage.map(\.word)).isDisjoint(with: secondPage.map(\.word)))
    }

    func testCrossedSenseChipsRotateWithTheRestOfThePage() throws {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "It felt warm.")
        let warm = try XCTUnwrap(scaffold.tokens.first { $0.word == "warm" })
        let firstPage = engine.moves(for: warm, in: scaffold)
        let secondPage = engine.moves(
            for: warm,
            in: scaffold,
            avoiding: Set(firstPage.map { $0.word.lowercased() })
        )
        let firstCrossings = firstPage.filter { $0.group == "cross" }.map(\.word)
        let secondCrossings = secondPage.filter { $0.group == "cross" }.map(\.word)

        XCTAssertEqual(firstCrossings.count, 2)
        XCTAssertEqual(secondCrossings.count, 2)
        XCTAssertTrue(Set(firstCrossings).isDisjoint(with: secondCrossings))
    }

    func testStarterOptionsKeepSelectionAndContextWhileRotating() throws {
        let engine = SentenceBuilderEngine(
            context: SentenceBuilderContext(prompt: "Remember the train ticket on the platform.")
        )
        let template = try XCTUnwrap(SentenceBuilderPack.core.starterTemplates.first)
        let anchor = try XCTUnwrap(template.slots.first { $0.kind == .anchor })
        let draft = SentenceStarterDraft(template: template, selections: [anchor.id: "ticket"])
        let firstPage = engine.options(for: anchor, in: draft)
        let secondPage = engine.options(
            for: anchor,
            in: draft,
            avoiding: Set(firstPage.map { $0.lowercased() })
        )

        XCTAssertEqual(firstPage.first, "ticket")
        XCTAssertEqual(secondPage.first, "ticket")
        XCTAssertGreaterThan(Set(secondPage).subtracting(firstPage).count, 0)
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

    func testComposedCoreMergesOwnedExpansionPack() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer {
            PackEntitlements.ownedPackIDs = savedOwned
            SentenceBuilderPackRegistry.reload()
        }
        PackEntitlements.ownedPackIDs = []
        SentenceBuilderPackRegistry.reload()

        // The word hoard moved off the paid shelf and onto the free-gift shelf;
        // it still binds as an entitlement so the reader chooses when it wakes.
        XCTAssertNil(BookShopCatalog.listing(forPackID: "pack.night-and-garden"))
        XCTAssertTrue(BookShopCatalog.freeGifts.contains { $0.packID == "pack.night-and-garden" })
        XCTAssertFalse(SentenceBuilderPackRegistry.enabledExpansionPacks().contains { $0.id == "pack.night-and-garden" })

        PackEntitlements.ownedPackIDs = ["pack.night-and-garden"]
        SentenceBuilderPackRegistry.reload()
        XCTAssertTrue(SentenceBuilderPackRegistry.enabledExpansionPacks().contains { $0.id == "pack.night-and-garden" })
        XCTAssertTrue(SentenceBuilderPackRegistry.composedCore().concreteWords.contains("moth"))
        XCTAssertTrue(SentenceBuilderPackRegistry.composedCore().themes.contains { $0.id == "garden" })
    }

    func testShadowWonderPackComposesOnlyWhenActive() {
        let inactive = SentenceBuilderPackRegistry.composedCore(readerLexicon: ReaderLexicon(), shadowWonderActive: false)
        let active = SentenceBuilderPackRegistry.composedCore(readerLexicon: ReaderLexicon(), shadowWonderActive: true)

        XCTAssertEqual(inactive.ritualTitle, "Wake the sentence")
        XCTAssertFalse(inactive.themes.contains { $0.id == "thornlight" })
        XCTAssertEqual(active.ritualTitle, "Wake the worn edge")
        XCTAssertTrue(active.themes.contains { $0.id == "thornlight" })
        XCTAssertTrue(active.themes.contains { $0.id == "decay" })
    }

    func testChapterNineMasteryPackAddsPennySentenceDesk() throws {
        SentenceBuilderPackRegistry.reload()
        let pack = SentenceBuilderPackRegistry.composedChapterNineMastery(readerLexicon: ReaderLexicon())

        XCTAssertEqual(pack.displayName, "Penny's Sentence Desk")
        XCTAssertEqual(pack.ritualTitle, "File the evidence")
        XCTAssertTrue(pack.starterTemplates.contains { $0.id == "chapter-nine-specific-detail" })
        XCTAssertTrue(pack.starterTemplates.contains { $0.id == "chapter-nine-crossed-wire" })
        XCTAssertTrue(pack.themes.contains { $0.id == "souvenir-evidence" })

        let engine = SentenceBuilderEngine(pack: pack)
        let analysis = engine.analyze("The bench caught my weight with warm quiet.")

        XCTAssertTrue(analysis.hasConcreteAnchor)
        XCTAssertTrue(analysis.hasSensoryDetail)
        XCTAssertTrue(analysis.hasLivingMotion)
        XCTAssertTrue(analysis.hasCrossedSense)
        XCTAssertTrue(analysis.isVivid)
    }

    func testPennySentenceMasteryLessonsAreMultiplePagesWorth() {
        XCTAssertEqual(PennySentenceMasteryLesson.allCases.count, 4)
        XCTAssertEqual(PennySentenceMasteryLesson.crossedWires.masteryHint, "Penny wants a crossed sense: taste, sound, smell, color, texture in the wrong lane.")
        XCTAssertTrue(PennySentenceMasteryLesson.twentyFourHourVault.tags.contains("sentence-lesson:twenty-four-hour-vault"))
    }

    func testSentencePackImportValidationRejectsEmptyAndMalformedFiles() throws {
        let valid = """
        { "id": "pack.imported", "concreteWords": ["thimble"], "availability": "userImported" }
        """.data(using: .utf8)!

        let pack = try XCTUnwrap(SentenceBuilderPackRegistry.validateImport(data: valid))

        XCTAssertEqual(pack.id, "pack.imported")
        XCTAssertEqual(pack.availability, "userImported")
        XCTAssertNil(SentenceBuilderPackRegistry.validateImport(data: "{}".data(using: .utf8)!))
        XCTAssertNil(SentenceBuilderPackRegistry.validateImport(data: "nope".data(using: .utf8)!))
    }

    func testComposedCoreWithReaderLexiconUsesCachedBase() {
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "thimble",
            originalSense: "a small metal sewing guard",
            newSense: "a tiny room for courage",
            ruling: .pardoned,
            category: .concrete,
            origin: .seeded,
            ledAt: Date(timeIntervalSinceReferenceDate: 16)
        ))

        SentenceBuilderPackRegistry.reload()
        let expected = SentenceBuilderPackRegistry.composedCore().merged(with: lexicon.asSentenceBuilderPack())
        let actual = SentenceBuilderPackRegistry.composedCore(readerLexicon: lexicon)

        XCTAssertEqual(actual.concreteWords, expected.concreteWords)
        XCTAssertEqual(actual.themes, expected.themes)
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

    // MARK: - Runtime page context

    func testRuntimeContextChangesTopSuggestionsForTheSameDraft() throws {
        let railEngine = SentenceBuilderEngine(
            context: SentenceBuilderContext(prompt: "Remember the train ticket on the platform.")
        )
        let weatherEngine = SentenceBuilderEngine(
            context: SentenceBuilderContext(prompt: "Notice the rain against the window.")
        )
        let railScaffold = railEngine.scaffold(for: "The mug waited.")
        let weatherScaffold = weatherEngine.scaffold(for: "The mug waited.")
        let railMug = try XCTUnwrap(railScaffold.tokens.first { $0.word == "mug" })
        let weatherMug = try XCTUnwrap(weatherScaffold.tokens.first { $0.word == "mug" })

        let railFirst = try XCTUnwrap(railEngine.moves(for: railMug, in: railScaffold).first?.word)
        let weatherFirst = try XCTUnwrap(weatherEngine.moves(for: weatherMug, in: weatherScaffold).first?.word)

        XCTAssertTrue(["ticket", "train"].contains(railFirst))
        XCTAssertTrue(["rain", "window"].contains(weatherFirst))
        XCTAssertNotEqual(railFirst, weatherFirst)
    }

    func testRuntimeNounBecomesARecognizedAnchor() {
        let engine = SentenceBuilderEngine(
            context: SentenceBuilderContext(prompt: "The telescope stood beside the railing.")
        )

        XCTAssertTrue(engine.analyze("The telescope waited beside me.").hasConcreteAnchor)
        XCTAssertEqual(engine.scaffold(for: "The telescope waited.").tokens.first { $0.word == "telescope" }?.role, .thing)
    }

    func testPersonalLexiconWordsArePromotedWhenThePageHasNoStrongerClue() throws {
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "thimble",
            originalSense: "a small metal sewing guard",
            newSense: "a tiny room for courage",
            ruling: .adopted,
            category: .concrete,
            origin: .seeded,
            ledAt: Date(timeIntervalSinceReferenceDate: 17)
        ))
        let pack = SentenceBuilderPackRegistry.composed(onto: .core, readerLexicon: lexicon)
        let engine = SentenceBuilderEngine(
            pack: pack,
            context: SentenceBuilderContext(personalWords: ["thimble"])
        )
        let scaffold = engine.scaffold(for: "The mug waited.")
        let mug = try XCTUnwrap(scaffold.tokens.first { $0.word == "mug" })

        XCTAssertEqual(engine.moves(for: mug, in: scaffold).first?.word, "thimble")
    }

    func testReplyUsesReplySpecificCraftMarksAndEchoesIncomingNote() {
        let engine = SentenceBuilderEngine(context: SentenceBuilderContext(
            intent: .letterReply,
            sourceText: "The broken umbrella made me laugh.",
            recipientName: "Pippa"
        ))

        let analysis = engine.analyze("I keep thinking about your umbrella.")

        XCTAssertEqual(analysis.craftMarks.map(\.title), ["Answer", "Echo", "Voice", "Close"])
        XCTAssertTrue(analysis.craftMarks.first { $0.title == "Echo" }?.isPresent == true)
        XCTAssertTrue(analysis.craftMarks.first { $0.title == "Voice" }?.isPresent == true)
        XCTAssertTrue(analysis.canStandAsComplete)
    }

    func testMissionProofUsesActionAndEvidenceInsteadOfCrossedSense() {
        let engine = SentenceBuilderEngine(context: SentenceBuilderContext(
            intent: .missionProof,
            prompt: "Find one overlooked umbrella.",
            sourceText: "The umbrella is field evidence."
        ))

        let analysis = engine.analyze("The umbrella rolled across the pavement.")

        XCTAssertEqual(analysis.craftMarks.map(\.title), ["Proof", "Detail", "Action", "Return"])
        XCTAssertTrue(analysis.craftMarks.first { $0.title == "Action" }?.isPresent == true)
        XCTAssertTrue(analysis.canStandAsComplete)
    }

    func testContextualReplyStarterUsesIncomingPageVocabulary() throws {
        let engine = SentenceBuilderEngine(context: SentenceBuilderContext(
            intent: .letterReply,
            sourceText: "I found your umbrella beside the station clock."
        ))

        let draft = try XCTUnwrap(engine.starterDraft(seed: "reply"))

        XCTAssertEqual(draft.template.id, "context-reply")
        XCTAssertTrue(["umbrella", "station", "clock"].contains(draft.selections["anchor"] ?? ""))
        XCTAssertTrue(engine.render(draft).hasPrefix("Your note about "))
    }

    func testReplacementPreservesCapitalizationAndRepairsArticle() throws {
        let engine = SentenceBuilderEngine()
        let scaffold = engine.scaffold(for: "A Mug waited.")
        let mug = try XCTUnwrap(scaffold.tokens.first { $0.word == "Mug" })

        let replaced = scaffold.replacing(tokenID: mug.id, with: "envelope", using: .core)

        XCTAssertEqual(replaced.rendered, "An Envelope waited.")
    }

    func testPastTenseMotionSuggestionsKeepPastTenseShape() throws {
        let engine = SentenceBuilderEngine(context: SentenceBuilderContext(
            prompt: "The rain is drumming on the roof."
        ))
        let scaffold = engine.scaffold(for: "The rain waited.")
        let waited = try XCTUnwrap(scaffold.tokens.first { $0.word == "waited" })

        let moves = engine.moves(for: waited, in: scaffold)

        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy {
            $0.word.hasSuffix("ed") || ["caught", "held", "kept", "left", "made", "sat", "stood", "took", "went", "wore"].contains($0.word)
        })
    }
}
