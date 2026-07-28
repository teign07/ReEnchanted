import XCTest
@testable import InsideCoverCore

final class StoryPageConsequenceTests: XCTestCase {
    func testStoryConsequencePackDecodesUnknownAtoms() throws {
        let data = Data("""
        {
          "id": "reader-consequence-pack",
          "displayName": "Reader Consequences",
          "version": 1,
          "author": "Reader",
          "availability": "userImported",
          "bundles": [
            {
              "id": "new-physics",
              "label": "New Physics",
              "when": { "choiceRoles": ["sliceoflife"] },
              "atoms": [
                { "type": "futureThingTheOldAppDoesNotKnow", "amount": 7 },
                { "type": "ritualLedgerDelta", "target": "smallCeremonyRegister", "amount": 1 },
                { "type": "sceneBiasDelta", "target": "quiet", "amount": 2 },
                { "type": "pageTag", "value": "still-decodes" }
              ]
            }
          ]
        }
        """.utf8)

        let pack = try JSONDecoder().decode(StoryConsequencePack.self, from: data)

        XCTAssertEqual(pack.bundles.first?.atoms.first?.type, "futureThingTheOldAppDoesNotKnow")
        XCTAssertEqual(pack.bundles.first?.atoms.dropFirst().first?.target, "smallCeremonyRegister")
        XCTAssertEqual(pack.bundles.first?.atoms.last?.value, "still-decodes")
    }

    func testEveryEnabledStoryRecipeHasUniversalCompilerContinuity() {
        XCTAssertFalse(StoryFormRegistry.recipes.isEmpty)
        for recipe in StoryFormRegistry.recipes {
            let page = storyPage(
                input: "Chosen path: Slice of Life",
                tags: [
                    "narrative-os",
                    "story-recipe:\(recipe.id)",
                    "choice:sliceoflife",
                    "entity:zara-finch",
                    "entity:damien-nights",
                    "entity:location-great-hall"
                ]
            )

            let consequence = StoryConsequenceResolver.resolvedConsequence(
                forChoiceID: "sliceoflife",
                page: page,
                bundles: []
            )

            XCTAssertTrue(
                consequence.bundleIDs.contains("recipe-continuity:\(recipe.id)"),
                "\(recipe.id) did not enter the consequence compiler"
            )
            XCTAssertEqual(consequence.ritualLedgerDeltas["story-recipe-turn:\(recipe.id)"], 1)
            XCTAssertEqual(
                consequence.ritualLedgerDeltas["story-pair:damien-nights--zara-finch:encounters"],
                1
            )
            XCTAssertEqual(consequence.settingAffinityDeltas["location-great-hall"], 1)
        }
    }

    func testConsequenceConditionCanTargetExactRecipeWithoutProseGuessing() {
        let page = storyPage(
            input: "No recipe keywords are required here. Chosen path: Progress Arc",
            tags: ["story-recipe:rivals-tether", "choice:progressarc"]
        )
        let matching = StoryConsequenceCondition(recipeIDs: ["rivals-tether"])
        let other = StoryConsequenceCondition(recipeIDs: ["shared-quiet"])

        XCTAssertTrue(matching.matches(page: page, choiceID: "progressarc"))
        XCTAssertFalse(other.matches(page: page, choiceID: "progressarc"))
    }

    func testConsequencePackValidationRejectsBrokenKnownAtomsButKeepsUnknownAtomsForwardCompatible() throws {
        let data = Data("""
        {
          "id": "broken-pack",
          "displayName": "Broken Pack",
          "version": 1,
          "author": "Reader",
          "availability": "userImported",
          "bundles": [
            {
              "id": "broken",
              "label": "Broken",
              "when": { "recipeIDs": ["known-recipe"] },
              "atoms": [
                { "type": "futureRecipeBoost", "recipeID": "missing-recipe", "amount": 2 },
                { "type": "relationshipTieDelta" },
                { "type": "futureAtomFromANewerBook", "amount": 1 }
              ]
            }
          ]
        }
        """.utf8)
        let pack = try JSONDecoder().decode(StoryConsequencePack.self, from: data)

        let report = StoryConsequencePackValidator.validate(
            pack,
            knownRecipeIDs: ["known-recipe"]
        )

        XCTAssertFalse(report.isUsable)
        XCTAssertTrue(report.errors.contains { $0.message.contains("unknown Story Recipe missing-recipe") })
        XCTAssertTrue(report.errors.contains { $0.message.contains("must change warmth") })
        XCTAssertTrue(report.warnings.contains { $0.message.contains("futureAtomFromANewerBook") })
    }

    func testBundledConsequencePackPassesStrictValidation() throws {
        let pack = try XCTUnwrap(StoryConsequenceRegistry.bundledPacks.first)
        let report = StoryConsequencePackValidator.validate(pack)

        XCTAssertTrue(
            report.isUsable,
            report.errors.map { "\($0.path): \($0.message)" }.joined(separator: " | ")
        )
    }

    func testDramaticDisagreementCompilesPairHistoryAndFuturePressure() throws {
        let effect = StoryDramaticChoiceEffect(
            choiceID: "surprise",
            role: .surprise,
            requiredReactorID: "damien-nights",
            requiredReactorName: "Damien Nights",
            requiredReaction: "admits the disagreement protects an old fear",
            readerChoiceEffect: "The hidden loyalty becomes discussable.",
            changedFact: "Damien admits that the argument was protecting Zara.",
            memorySummary: "Damien remembers admitting why he argued with Zara.",
            warmthDelta: 0,
            tensionDelta: 2,
            familiarityDelta: 1
        )
        let contract = StoryDramaticContract(
            recipeID: "rivals-tether",
            leadCharacterID: "zara-finch",
            leadCharacterName: "Zara Finch",
            leadCharacterWant: "an honest answer",
            leadCharacterWorry: "the answer will harden the quarrel",
            leadCharacterBlindSpot: "she mistakes caution for contempt",
            otherCharacterID: "damien-nights",
            otherCharacterName: "Damien Nights",
            otherCharacterPressure: "he is protecting an old promise",
            relationshipID: "zara-damien",
            relationshipQuestion: "Can they disagree without becoming strangers?",
            stakes: "Silence lets suspicion become their working truth.",
            choiceEffects: [effect]
        )
        let receipt = StoryDramaticOutcomeReceipt(
            contract: contract,
            effect: effect,
            turnKind: .relationshipShift
        )
        let receiptTag = try XCTUnwrap(receipt.encodedTag)
        let page = storyPage(
            input: "Chosen path: Something Surprising",
            tags: [
                "story-recipe:rivals-tether",
                "choice:surprise",
                "entity:zara-finch",
                "entity:damien-nights",
                receiptTag
            ] + StoryChoiceClosure.tags(
                chosenChoiceID: "surprise",
                availableChoiceIDs: ["slice-of-life", "progress-arc", "surprise"],
                chosenText: "Betray the promise."
            )
        )

        let consequence = StoryConsequenceResolver.resolvedConsequence(
            forChoiceID: "surprise",
            page: page,
            bundles: []
        )

        XCTAssertEqual(consequence.ritualLedgerDeltas["story-pair:damien-nights--zara-finch:encounters"], 1)
        XCTAssertEqual(consequence.ritualLedgerDeltas["story-pair:damien-nights--zara-finch:tension"], 2)
        XCTAssertEqual(consequence.ritualLedgerDeltas["story-pair:damien-nights--zara-finch:ruptures"], 2)
        XCTAssertGreaterThanOrEqual(consequence.futureRecipeBoosts["concrete-disagreement"] ?? 0, 1)
        XCTAssertGreaterThanOrEqual(consequence.futureRecipeBoosts["rivals-tether"] ?? 0, 3)
        XCTAssertTrue(consequence.entityMemoryWrites.contains { $0.entityID == "damien-nights" })
        XCTAssertTrue(consequence.entityMemoryWrites.contains { $0.entityID == "zara-finch" })
    }

    func testDynamicRelationshipTensionCanUnlockRivalryRecipes() throws {
        let characters = NarrativePackRegistry.entities.filter { $0.kind == .character }
        let first = try XCTUnwrap(characters.first)
        let second = try XCTUnwrap(characters.dropFirst().first)
        let pair = NarrativeGraphData.relationshipPairKey(first.id, second.id)

        XCTAssertTrue(StoryFormRegistry.hasRivalryEdge(
            among: [first, second],
            relationshipField: [pair: RelationshipTie(warmth: 0, tension: 2, familiarity: 2)]
        ))
    }

    func testRepairRestStoryChoiceCreatesChangedTextureConsequences() {
        let page = storyPage(
            input: """
            Turn 1

            Zara mended the rain lamp and let the room rest.

            Chosen path: Slice of Life

            The ordinary detail gained weight.
            """,
            tags: [
                "narrative-os", "rest", "quiet",
                "entity:zara-finch", "entity:damien-nights",
                "thread:weather-in-the-stacks", "choice:sliceoflife"
            ]
        )

        let consequence = StoryConsequenceResolver.resolvedConsequence(forChoiceID: "sliceoflife", page: page)

        XCTAssertEqual(consequence.beliefDelta, 1)
        XCTAssertEqual(consequence.entityBeliefDeltas["zara-finch"], 1)
        XCTAssertLessThan(consequence.nothingGreyDelta, 0)
        XCTAssertGreaterThanOrEqual(consequence.futureRecipeBoosts["shared-quiet"] ?? 0, 2)
        XCTAssertTrue(consequence.eventTags.contains("mended-object"))
        XCTAssertTrue(consequence.eventTags.contains("grey-repaired"))
        XCTAssertTrue(consequence.eventTags.contains("motif:lamp"))
        XCTAssertTrue(consequence.relationshipTieDeltas.contains { delta in
            delta.entityIDs.contains("zara-finch") &&
            delta.entityIDs.contains("damien-nights") &&
            delta.warmth == 1 &&
            delta.familiarity == 1
        })
        XCTAssertTrue(consequence.entityMemoryWrites.contains { $0.entityID == "zara-finch" && $0.summary.contains("repair and rest") })
    }

    func testKeptStoryPageChoiceEventCarriesConsequenceEvidenceAndMemory() {
        let page = storyPage(
            input: """
            Turn 1

            Penny found an extra note under the page.

            Chosen path: Something Surprising

            A related side door opened.
            """,
            tags: [
                "narrative-os", "entity:penny-blackletter",
                "thread:margin-glass-letters", "choice:surprise"
            ]
        )

        let events = NarrativeEventResolver.events(forKept: page)
        let choiceEvent = events.first { $0.kind == .choiceSelected && $0.id.contains("surprise") }

        XCTAssertEqual(choiceEvent?.effect.beliefDelta, 2)
        XCTAssertTrue(choiceEvent?.tags.contains("motif:threshold") == true)
        XCTAssertTrue(choiceEvent?.tags.contains("recipe-boost:small-discovery") == true)
        XCTAssertTrue((choiceEvent?.effect.entityMemoryWrites ?? []).contains { write in
            write.entityID == "penny-blackletter" &&
            write.summary.contains("sideways detail")
        })
        let memories = choiceEvent.map { NarrativeEntityMemoryResolver.memories(for: $0) } ?? []
        XCTAssertTrue(memories.contains { $0.summary.contains("sideways detail") })
    }

    func testIgnoredErasureIsTheGreyIncreasePath() {
        let page = storyPage(
            input: """
            Turn 1

            The threshold label faded. The reader ignored the erasure and left it unnamed.

            Chosen path: Something Surprising

            The missing label stayed cold.
            """,
            tags: [
                "narrative-os", "grey", "nothing", "nocturne",
                "entity:the-book", "choice:surprise"
            ]
        )

        let consequence = StoryConsequenceResolver.resolvedConsequence(forChoiceID: "surprise", page: page)

        XCTAssertEqual(consequence.nothingGreyDelta, 1)
        XCTAssertTrue(consequence.eventTags.contains("ignored-erasure"))
        XCTAssertTrue(consequence.eventTags.contains("grey-thickened"))
        XCTAssertEqual(consequence.futureRecipeBoosts["nothing-library-corner"], 2)
    }

    func testApplicatorMutatesDurableWorldTexture() {
        let page = storyPage(
            input: """
            Turn 1

            Zara mended the lamp and let the kitchen rest around a bowl of soup.

            Chosen path: Slice of Life

            The ordinary detail gained weight.
            """,
            tags: [
                "narrative-os", "rest", "care", "body",
                "entity:zara-finch", "entity:damien-nights",
                "thread:body-learns-trust", "choice:sliceoflife"
            ]
        )
        let consequences = StoryConsequenceResolver.resolvedConsequences(forKept: page)
        var state = StoryConsequenceApplicationState()

        StoryConsequenceApplicator.apply(consequences, to: &state)

        XCTAssertEqual(state.entityBeliefDeltas["zara-finch"], 1)
        XCTAssertLessThan(state.nothingGreyOffset, 0)
        XCTAssertGreaterThanOrEqual(state.storyRecipeBoosts["shared-quiet"] ?? 0, 2)
        XCTAssertGreaterThan(state.storyMotifs["lamp"] ?? 0, 0)
        XCTAssertGreaterThan(state.storyMotifs["soup"] ?? 0, 0)
        XCTAssertGreaterThan(state.bookNoticeEvidence, 0)
        let pair = NarrativeGraphData.relationshipPairKey("damien-nights", "zara-finch")
        XCTAssertEqual(state.relationshipField[pair]?.warmth, 1)
        XCTAssertEqual(state.relationshipField[pair]?.familiarity, 1)
    }

    func testApplicatorMutatesRitualSettingAndSceneBiasLedgers() {
        let consequence = StoryResolvedConsequence(
            choiceID: "sliceoflife",
            ritualLedgerDeltas: ["small-ceremony-register": 1, "quiet-company:zara-finch": 2],
            settingAffinityDeltas: ["location-great-hall": 3],
            sceneBiasDeltas: ["quiet": 2, "tension": -1]
        )
        var state = StoryConsequenceApplicationState(
            storyRituals: ["small-ceremony-register": 9],
            storySettingAffinities: ["location-great-hall": 23],
            storySceneBiases: ["quiet": 23, "tension": -23]
        )

        StoryConsequenceApplicator.apply([consequence], to: &state)

        XCTAssertEqual(state.storyRituals["small-ceremony-register"], 10)
        XCTAssertEqual(state.storyRituals["quiet-company:zara-finch"], 2)
        XCTAssertEqual(state.storySettingAffinities["location-great-hall"], 24)
        XCTAssertEqual(state.storySceneBiases["quiet"], 24)
        XCTAssertEqual(state.storySceneBiases["tension"], -24)
    }

    func testRitualThresholdConditionFiresOnExactTenthRepeat() {
        let page = storyPage(
            input: """
            Turn 1

            The Great Hall solemnly honors washing one cup.

            Chosen path: Slice of Life

            The cup receives a frankly excessive ovation.
            """,
            tags: ["narrative-os", "great-hall", "choice:sliceoflife", "entity:the-book"]
        )
        var condition = StoryConsequenceCondition()
        condition.choiceRoles = ["sliceoflife"]
        condition.ritualCountsAtLeast = ["smallCeremonyRegister": 9]
        condition.ritualCountsBelow = ["smallCeremonyRegister": 10]
        let bundle = StoryConsequenceBundle(
            id: "small-ceremony-tenth",
            label: "Small Ceremony: Tenth",
            when: condition,
            atoms: [
                StoryConsequenceAtom(type: "ritualLedgerDelta", target: "smallCeremonyRegister", targets: nil, amount: 1, warmth: nil, tension: nil, familiarity: nil, value: nil, recipeID: nil, entityID: nil, faeKind: nil, template: nil),
                StoryConsequenceAtom(type: "pageTag", target: nil, targets: nil, amount: nil, warmth: nil, tension: nil, familiarity: nil, value: "tenth-small-ceremony", recipeID: nil, entityID: nil, faeKind: nil, template: nil),
                StoryConsequenceAtom(type: "settingAffinityDelta", target: "locationGreatHall", targets: nil, amount: 2, warmth: nil, tension: nil, familiarity: nil, value: nil, recipeID: nil, entityID: nil, faeKind: nil, template: nil)
            ]
        )

        let notYet = StoryConsequenceResolver.resolvedConsequence(
            forChoiceID: "sliceoflife",
            page: page,
            world: StoryConsequenceWorldSnapshot(storyRituals: ["small-ceremony-register": 8]),
            bundles: [bundle]
        )
        let exactTenth = StoryConsequenceResolver.resolvedConsequence(
            forChoiceID: "sliceoflife",
            page: page,
            world: StoryConsequenceWorldSnapshot(storyRituals: ["small-ceremony-register": 9]),
            bundles: [bundle]
        )
        let alreadyPassed = StoryConsequenceResolver.resolvedConsequence(
            forChoiceID: "sliceoflife",
            page: page,
            world: StoryConsequenceWorldSnapshot(storyRituals: ["small-ceremony-register": 10]),
            bundles: [bundle]
        )
        var state = StoryConsequenceApplicationState(storyRituals: ["small-ceremony-register": 9])

        StoryConsequenceApplicator.apply([exactTenth], to: &state)

        XCTAssertTrue(notYet.isEmpty)
        XCTAssertTrue(alreadyPassed.isEmpty)
        XCTAssertEqual(exactTenth.ritualLedgerDeltas["small-ceremony-register"], 1)
        XCTAssertEqual(exactTenth.settingAffinityDeltas["location-great-hall"], 2)
        XCTAssertTrue(exactTenth.eventTags.contains("tenth-small-ceremony"))
        XCTAssertEqual(state.storyRituals["small-ceremony-register"], 10)
    }

    func testStorySparkChoiceCreatesSentenceOpenedConsequences() {
        let page = storyPage(
            input: """
            Turn 1

            The rain sentence opened a small door in the shelf.

            Chosen path: Slice of Life

            The sentence stayed small, but it did not stay inert.
            """,
            tags: [
                "narrative-os", "story-spark", "story-spark-source:rain-page",
                "choice:sliceoflife", "entity:the-book"
            ]
        )

        let consequence = StoryConsequenceResolver.resolvedConsequence(forChoiceID: "sliceoflife", page: page)

        XCTAssertTrue(consequence.bundleIDs.contains("story-spark-sentence-opened"))
        XCTAssertGreaterThanOrEqual(consequence.beliefDelta, 1)
        XCTAssertGreaterThanOrEqual(consequence.bookNoticeEvidenceDelta, 1)
        XCTAssertEqual(consequence.ritualLedgerDeltas["story-spark"], 1)
        XCTAssertEqual(consequence.futureRecipeBoosts["souvenir-door"], 2)
        XCTAssertEqual(consequence.sceneBiasDeltas["threshold"], 1)
        XCTAssertTrue(consequence.eventTags.contains("sentence-opened"))
        XCTAssertTrue(consequence.eventTags.contains("motif:threshold"))
        XCTAssertTrue(consequence.monthlyEditionLines.contains("A kept sentence opened a small door in the Story Pages."))
        XCTAssertTrue(consequence.entityMemoryWrites.contains { $0.entityID == "the-book" && $0.summary.contains("sentence became a door") })
    }

    func testLegacyRawStoryMechanicTagsStillCountAsCompassRun() throws {
        let rawTagged = storyPage(
            input: "Chosen path: Progress Arc",
            tags: ["narrative-os", "story-mechanic", "compass-run", "choice:progressarc"]
        )
        let canonicalTagged = storyPage(
            input: "Chosen path: Progress Arc",
            tags: ["narrative-os", "story-mechanic", "story-mechanic:compass-run", "choice:progressarc"]
        )

        let rawEffect = try XCTUnwrap(NarrativeEventResolver.events(forKept: rawTagged).first { $0.kind == .choiceSelected }?.effect)
        let canonicalEffect = try XCTUnwrap(NarrativeEventResolver.events(forKept: canonicalTagged).first { $0.kind == .choiceSelected }?.effect)

        XCTAssertEqual(rawEffect.threadWeightDeltas["ordinary-magic"], canonicalEffect.threadWeightDeltas["ordinary-magic"])
    }

    func testFaeCourtesyApplicatorWarmsFaeState() {
        let page = BookPage(
            id: "fae-story",
            type: .bookFae,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            promptText: "A Book Fae arrives.",
            userInput: """
            Turn 1

            The goblin tests the courtesy of the room.

            Chosen path: Slice of Life

            Courtesy softens the claim.
            """,
            tags: ["book-fae", "fae", "fae:goblin", "entity:the-book", "choice:sliceoflife"]
        )
        let consequences = StoryConsequenceResolver.resolvedConsequences(forKept: page)
        var state = StoryConsequenceApplicationState()

        StoryConsequenceApplicator.apply(consequences, to: &state)

        XCTAssertEqual(state.fae.warmth(for: .goblin), 1)
        XCTAssertEqual(state.fae.attention, 1)
    }

    func testStoryRecipeBoostsInfluenceFormAndGenreSelection() {
        let pick = StoryFormRegistry.select(
            tags: [],
            surfaceHistory: [:],
            ascendantChapterID: nil,
            dayID: "boost-day",
            slot: "slot-a",
            recipeBoosts: ["shared-quiet": 12],
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertTrue(["quiet-epic", "correspondence"].contains(pick.form.id))
        XCTAssertTrue(["pastoral", "field-naturalist"].contains(pick.genre.id))
    }

    func testSceneBiasInfluencesFormAndGenreSelection() {
        let pick = StoryFormRegistry.select(
            tags: [],
            surfaceHistory: [:],
            ascendantChapterID: nil,
            dayID: "bias-day",
            slot: "slot-a",
            sceneBiases: ["nocturne": 24, "gentle-horror": 24],
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(pick.form.id, "nocturne")
        XCTAssertEqual(pick.genre.id, "gentle-horror")
    }

    func testConsequenceLedgerRecordsEachCompiledChoiceOnceAndRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let page = BookPage(
            id: "story-causal-receipt",
            type: .narrativeOS,
            createdAt: now,
            promptText: "The Story Page is stirring.",
            userInput: "Chosen path: Something Surprising",
            tags: [
                "story-recipe:rivals-tether",
                "entity:zara-finch",
                "entity:damien-nights",
                "entity:location-great-hall"
            ]
        )
        let consequence = StoryResolvedConsequence(
            choiceID: "surprise",
            bundleIDs: ["universal-story-continuity"],
            relationshipTieDeltas: [
                StoryRelationshipTieDelta(
                    entityIDs: ["zara-finch", "damien-nights"],
                    warmth: 0,
                    tension: 2,
                    familiarity: 1
                )
            ],
            eventTags: ["story-refusal-remembered"],
            chapterTalismanDeltas: ["chapter-candle": 1],
            worldEventTouches: ["dictionary-rebellion"],
            radioBanterHooks: ["old-promise"],
            monthlyEditionLines: ["The old promise acquired a witness."]
        )
        var ledger = StoryConsequenceLedger.empty

        let inserted = ledger.record(page: page, consequences: [consequence])
        let duplicate = ledger.record(page: page, consequences: [consequence])

        let receipt = try XCTUnwrap(inserted.first)
        XCTAssertTrue(duplicate.isEmpty)
        XCTAssertEqual(ledger.receipts.count, 1)
        XCTAssertEqual(receipt.recipeID, "rivals-tether")
        XCTAssertEqual(receipt.characterIDs, ["zara-finch", "damien-nights"])
        XCTAssertEqual(receipt.settingIDs, ["location-great-hall"])
        XCTAssertEqual(receipt.tensionDelta, 2)
        XCTAssertEqual(receipt.significance, .rupture)
        XCTAssertEqual(receipt.chapterTalismanDeltas["chapter-candle"], 1)
        XCTAssertEqual(receipt.worldEventTouches, ["dictionary-rebellion"])

        let decoded = try JSONDecoder().decode(
            StoryConsequenceLedger.self,
            from: JSONEncoder().encode(ledger)
        )
        XCTAssertEqual(decoded, ledger)
    }

    func testAccumulatedFictionalPressureShapesLongGameAndOpensQuestionAtThreshold() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let first = moonshotReceipt(
            id: "first-friction",
            createdAt: now.addingTimeInterval(-86_400),
            tension: 2,
            significance: .turn
        )
        let second = moonshotReceipt(
            id: "second-friction",
            createdAt: now,
            tension: 2,
            significance: .turn
        )
        let ledger = StoryConsequenceLedger(receipts: [first, second])

        XCTAssertGreaterThan(
            ledger.longGameBoost(
                recipeID: "rivals-tether",
                preferredTags: ["rivalry"],
                now: now
            ),
            0
        )
        XCTAssertGreaterThan(
            ledger.longGameBoost(
                recipeID: "shared-quiet",
                preferredTags: ["care"],
                now: now
            ),
            0
        )
        XCTAssertEqual(ledger.contestedQuestionSeed(from: [second])?.id, second.id)
    }

    func testCompiledFactCanBecomeMultiCharacterDisagreementWithoutBeingRewritten() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let receipt = moonshotReceipt(
            id: "academy-argument",
            createdAt: now,
            tension: 3,
            significance: .rupture
        )

        let question = try XCTUnwrap(ContestedQuestionEngine.opening(
            consequence: receipt,
            entities: NarrativePackRegistry.entities,
            existing: [],
            now: now
        ))

        XCTAssertGreaterThanOrEqual(question.positions.count, ContestedQuestion.minimumPositions)
        XCTAssertTrue(question.positions.allSatisfy { $0.groundedInIDs == [receipt.id] })
        XCTAssertEqual(question.aboutMovementIDs, [receipt.id])
        XCTAssertTrue(question.question.contains(receipt.changedFact!))
        XCTAssertTrue(question.bookPosition.lowercased().contains("guess"))
    }

    func testRadioCanVoiceARecentConsequenceInItsOwnStationGrammar() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let receipt = moonshotReceipt(
            id: "radio-echo",
            createdAt: now,
            tension: 3,
            significance: .rupture
        )
        let station = RadioStation(
            id: "thornwave",
            title: "Thornwave",
            frequency: 91.3,
            subtitle: "test",
            hostEntityID: nil,
            packID: nil,
            unlockRule: "test",
            moodTags: [],
            signalLine: "test",
            tracks: [],
            interludeTitles: [],
            effects: [],
            banters: []
        )
        let state = RadioPlaybackState(
            activeStationID: station.id,
            startedAt: now,
            lastTunedAt: now
        )
        let context = RadioWorldContext(
            pageContext: RadioPageContext(storyConsequenceEchoes: [receipt])
        )

        let banter = try XCTUnwrap(RadioStationRegistry.nextBanter(
            station: station,
            state: state,
            context: context,
            now: now
        ))

        XCTAssertEqual(banter.id, "consequence-banter:\(receipt.id):thornwave")
        XCTAssertEqual(banter.category, .gossip)
        XCTAssertTrue(banter.caption.contains("Wicker"))
        XCTAssertTrue(banter.caption.contains(receipt.changedFact!))
    }

    func testMonthlyAndAnnualBindingsRememberCompiledStoryTurns() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let consequenceDate = calendar.date(
            from: DateComponents(year: 2026, month: 6, day: 12, hour: 18)
        )!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 12, hour: 12)
        )!
        let receipt = moonshotReceipt(
            id: "edition-turn",
            createdAt: consequenceDate,
            tension: 3,
            significance: .rupture
        )

        let monthly = MonthlyEditionBuilder.previousMonth(
            from: [],
            storyConsequences: [receipt],
            now: now,
            calendar: calendar
        )
        let annual = MonthlyEditionBuilder.annual(
            2026,
            from: [],
            storyConsequences: [receipt],
            now: now,
            calendar: calendar
        )

        let monthlySection = try XCTUnwrap(
            monthly.sections.first { $0.id == "fictional-consequences" }
        )
        XCTAssertEqual(monthlySection.items.first?.body, receipt.changedFact)
        XCTAssertEqual(monthlySection.items.first?.sourceID, "fictional-consequence-compiler")
        XCTAssertTrue(
            annual.chapters.contains {
                $0.sections.first(where: { $0.id == "fictional-consequences" })?.items.isEmpty == false
            }
        )
    }

    func testExplicitCompilerRelayCountsAsExactWorldEventTouch() throws {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs.insert("dictionary-rebellion")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 10, hour: 12)
        )!
        let receipt = moonshotReceipt(
            id: "rebellion-touch",
            createdAt: now,
            tension: 2,
            significance: .turn
        )
        var inputs = BookSourceInputs.empty
        inputs.storyConsequenceLedger = StoryConsequenceLedger(receipts: [receipt])

        let event = try XCTUnwrap(
            WorldEventResolver.activeEvents(
                now: now,
                inputs: inputs,
                calendar: calendar
            ).first { $0.id == "dictionary-rebellion" }
        )

        XCTAssertEqual(event.playerTouchCount, 1)
        XCTAssertEqual(event.playerTouchCounts?[WorldEventTouchKind.storyChoiceMade.rawValue], 1)
    }

    private func moonshotReceipt(
        id: String,
        createdAt: Date,
        tension: Int,
        significance: StoryConsequenceSignificance
    ) -> StoryConsequenceReceipt {
        StoryConsequenceReceipt(
            id: id,
            sourcePageID: "page-\(id)",
            sourcePageType: .narrativeOS,
            createdAt: createdAt,
            recipeID: "rivals-tether",
            choiceID: "surprise",
            bundleIDs: ["dramatic-outcome-v1"],
            characterIDs: ["zara-finch", "damien-nights"],
            settingIDs: ["location-great-hall"],
            relationshipID: "zara-damien",
            changedFact: "Damien admitted the quarrel was protecting Zara.",
            memorySummary: "The Academy remembers what Damien admitted.",
            eventTags: ["story-betrayal-remembered"],
            radioHooks: ["old-promise"],
            monthlyEditionLines: [],
            worldEventTouches: ["dictionary-rebellion"],
            chapterTalismanDeltas: ["chapter-candle": 1],
            warmthDelta: 0,
            tensionDelta: tension,
            familiarityDelta: 1,
            significance: significance
        )
    }

    private func storyPage(input: String, tags: [String]) -> BookPage {
        BookPage(
            id: "story-\(UUID().uuidString)",
            type: .narrativeOS,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            promptText: "The Story Page is stirring.",
            userInput: input,
            tags: tags
        )
    }
}
