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
        XCTAssertTrue(choiceEvent?.tags.contains("recipe-boost:small-mystery") == true)
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
