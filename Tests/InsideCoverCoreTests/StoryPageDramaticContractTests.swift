import XCTest
@testable import InsideCoverCore

final class StoryPageDramaticContractTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 806_000_000)

    func testEveryBundledRecipeAuthorsCharacterPressure() {
        XCTAssertFalse(StoryFormRegistry.coreRecipes.isEmpty)
        for recipe in StoryFormRegistry.coreRecipes {
            let pressure = recipe.characterPressure
            XCTAssertNotNil(pressure, "\(recipe.id) has no character-pressure declaration")
            XCTAssertFalse(pressure?.leadCharacterWorryTemplate.isEmpty ?? true, recipe.id)
            XCTAssertFalse(pressure?.leadCharacterBlindSpotTemplate.isEmpty ?? true, recipe.id)
            XCTAssertFalse(pressure?.otherCharacterPressureTemplate.isEmpty ?? true, recipe.id)
            XCTAssertFalse(pressure?.relationshipQuestionTemplate.isEmpty ?? true, recipe.id)
            XCTAssertFalse(pressure?.requiredCharacterReactionTemplate.isEmpty ?? true, recipe.id)
            XCTAssertTrue(StoryFormRegistry.recipeIsValid(recipe), "\(recipe.id) failed recipe validation")
        }
    }

    func testPacketAnswersFiveDramaticQuestionsBeforeProse() throws {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now)
        let blueprint = try XCTUnwrap(packet.blueprint)
        let contract = try XCTUnwrap(blueprint.dramaticContract)

        XCTAssertFalse(contract.leadCharacterName.isEmpty) // Who is here?
        XCTAssertFalse(contract.leadCharacterWant.isEmpty) // What do they want?
        XCTAssertFalse(contract.leadCharacterBlindSpot.isEmpty) // What are they wrong about?
        XCTAssertFalse(contract.relationshipQuestion.isEmpty) // What does the choice test?
        XCTAssertFalse(contract.stakes.isEmpty) // What differs if nobody answers?
        XCTAssertEqual(contract.choiceEffects.map(\.role), StoryChoiceRole.allCases)
        XCTAssertEqual(Set(contract.choiceEffects.map(\.changedFact)).count, 3)
        XCTAssertTrue(contract.choiceEffects.allSatisfy { !$0.requiredReactorID.isEmpty && !$0.requiredReaction.isEmpty })
    }

    func testDramaticContractIsStableForTheSameStorySlot() throws {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let first = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now)
        let second = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now)

        XCTAssertEqual(first.blueprint?.dramaticContract, second.blueprint?.dramaticContract)
    }

    func testLegacyRecipeWithoutPressureStillDecodesAndResolvesFallbackContract() throws {
        let original = try XCTUnwrap(StoryFormRegistry.coreRecipes.first)
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "characterPressure")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacy = try JSONDecoder().decode(StoryRecipe.self, from: legacyData)
        XCTAssertNil(legacy.characterPressure)

        let characters = NarrativePackRegistry.entities.filter { $0.kind == .character }
        let lead = try XCTUnwrap(characters.first)
        let companion = characters.dropFirst().first
        let contract = StoryScenePacketBuilder.makeDramaticContract(
            recipe: legacy,
            lead: lead,
            companion: companion,
            relationship: nil,
            turn: StoryTurn(
                kind: .relationshipShift,
                character: lead.name,
                want: "an honest answer",
                obstacle: "the answer has been avoided",
                statement: "Someone answers plainly.",
                register: .active,
                landings: [
                    "slice-of-life": "They accept the small answer.",
                    "progress-arc": "They make a promise that moves the thread.",
                    "surprise": "They admit the question was protecting a secret."
                ]
            )
        )

        XCTAssertEqual(contract.choiceEffects.count, 3)
        XCTAssertFalse(contract.leadCharacterWorry.isEmpty)
        XCTAssertFalse(contract.relationshipQuestion.isEmpty)
    }

    func testOutcomeReceiptRoundTripsAndMutatesExactRelationshipAndMemory() throws {
        let contract = sampleContract()
        let effect = try XCTUnwrap(contract.effect(for: "progressarc"))
        let receipt = StoryDramaticOutcomeReceipt(contract: contract, effect: effect, turnKind: .relationshipShift)
        let tag = try XCTUnwrap(receipt.encodedTag)
        XCTAssertEqual(StoryDramaticOutcomeReceipt.decode(tag: tag), receipt)

        let page = BookPage(
            type: .narrativeOS,
            promptText: "A Story Page",
            userInput: "Chosen path: Progress Arc",
            tags: ["choice:progressarc", "entity:zara", "entity:stonebrook", "thread:ordinary-magic", tag]
        )
        let consequence = StoryConsequenceResolver.resolvedConsequence(forChoiceID: "progressarc", page: page)

        XCTAssertTrue(consequence.bundleIDs.contains("dramatic-outcome-v1"))
        XCTAssertEqual(consequence.relationshipWeightDeltas["zara-stonebrook"], 1)
        XCTAssertTrue(consequence.relationshipTieDeltas.contains {
            Set($0.entityIDs) == Set(["zara", "stonebrook"])
                && $0.familiarity == effect.familiarityDelta
                && $0.tension == effect.tensionDelta
        })
        XCTAssertTrue(consequence.entityMemoryWrites.contains {
            $0.entityID == "stonebrook" && $0.summary == effect.memorySummary
        })
        XCTAssertTrue(consequence.eventTags.contains("story-character-reacted"))
        XCTAssertTrue(consequence.eventTags.contains("story-relationship-changed"))
    }

    func testResultValidatorRequiresNamedReactionAndChangedFact() throws {
        let effect = try XCTUnwrap(sampleContract().effect(for: "progress-arc"))
        let empty = StoryDramaticResultValidator.validate(
            "The room glowed. Everything felt different somehow.",
            effect: effect
        )
        XCTAssertFalse(empty.isAcceptable)

        let enacted = "Stonebrook answers Zara's disagreement by changing trust between them. Stonebrook agrees to carry the map, and the promise moves the thread."
        let valid = StoryDramaticResultValidator.validate(enacted, effect: effect)
        XCTAssertTrue(valid.isAcceptable, valid.failures.joined(separator: " | "))
    }

    private func sampleContract() -> StoryDramaticContract {
        let effects = [
            StoryDramaticChoiceEffect(
                choiceID: "slice-of-life", role: .sliceOfLife,
                requiredReactorID: "stonebrook", requiredReactorName: "Stonebrook",
                requiredReaction: "accepts Zara's ordinary kindness",
                readerChoiceEffect: "The choice lets care alter their distance.",
                changedFact: "Stonebrook accepts the cup and stays.",
                memorySummary: "Stonebrook remembers that Zara's ordinary kindness made staying possible.",
                warmthDelta: 1, tensionDelta: 0, familiarityDelta: 1
            ),
            StoryDramaticChoiceEffect(
                choiceID: "progress-arc", role: .progressArc,
                requiredReactorID: "stonebrook", requiredReactorName: "Stonebrook",
                requiredReaction: "answers Zara's disagreement by changing trust between them",
                readerChoiceEffect: "The choice requires an answer that cannot reset.",
                changedFact: "Stonebrook agrees to carry the map, and the promise moves the thread.",
                memorySummary: "Stonebrook remembers agreeing to carry Zara's map.",
                warmthDelta: 0, tensionDelta: -1, familiarityDelta: 1
            ),
            StoryDramaticChoiceEffect(
                choiceID: "surprise", role: .surprise,
                requiredReactorID: "stonebrook", requiredReactorName: "Stonebrook",
                requiredReaction: "admits the hidden fear beneath the disagreement",
                readerChoiceEffect: "The choice exposes the sideways truth.",
                changedFact: "Stonebrook admits the map resembles one that failed before.",
                memorySummary: "Stonebrook remembers admitting why the map frightened him.",
                warmthDelta: 0, tensionDelta: 1, familiarityDelta: 1
            )
        ]
        return StoryDramaticContract(
            recipeID: "test-recipe",
            leadCharacterID: "zara",
            leadCharacterName: "Zara",
            leadCharacterWant: "Stonebrook to trust her map",
            leadCharacterWorry: "Zara worries Stonebrook thinks she is guessing.",
            leadCharacterBlindSpot: "Zara mistakes Stonebrook's fear for contempt.",
            otherCharacterID: "stonebrook",
            otherCharacterName: "Stonebrook",
            otherCharacterPressure: "Stonebrook wants proof because an earlier map failed him.",
            relationshipID: "zara-stonebrook",
            relationshipQuestion: "Will Stonebrook trust Zara enough to carry the map?",
            stakes: "Without an answer, contempt remains their working truth.",
            choiceEffects: effects
        )
    }
}
