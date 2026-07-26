import XCTest
@testable import InsideCoverCore

final class CharacterCanonPacketTests: XCTestCase {
    private let character = NarrativeWorldEntity(
        id: "juniper-test",
        packID: "test",
        name: "Juniper Test",
        kind: .character,
        belief: 24,
        narrativeWeight: 18,
        chapter: "Riddlewind",
        unwrittenInterest: "misprinted maps and doors that remember nicknames",
        traits: ["wry", "restless", "tender-hearted"],
        quirks: ["answers questions with a route", "taps commas twice before trusting them"],
        faults: ["hides concern inside jokes"],
        beliefs: ["a useful map should leave one choice unmarked"],
        goals: ["return the borrowed brass key without admitting why it mattered"],
        tags: ["maps", "keys", "student"]
    )

    func testPacketCarriesTheWholePerformanceSheet() {
        let packet = CharacterCanonPacket.promptSection(
            for: [character],
            contextLines: ["Juniper is irritated with Penny but still trusts her filing instincts."]
        )

        XCTAssertTrue(packet.contains(CharacterCanonPacket.version))
        XCTAssertTrue(packet.contains("Juniper Test [juniper-test]"))
        XCTAssertTrue(packet.contains("wry; restless; tender-hearted"))
        XCTAssertTrue(packet.contains("answers questions with a route"))
        XCTAssertTrue(packet.contains("hides concern inside jokes"))
        XCTAssertTrue(packet.contains("a useful map should leave one choice unmarked"))
        XCTAssertTrue(packet.contains("return the borrowed brass key"))
        XCTAssertTrue(packet.contains("misprinted maps"))
        XCTAssertTrue(packet.contains("Juniper is irritated with Penny"))
        XCTAssertTrue(packet.contains("Could each speaking character be identified"))
        XCTAssertTrue(packet.contains(CharacterCanonPacket.endMarker))
        XCTAssertEqual(CharacterCanonPacket.characterIDs(in: packet), ["juniper-test"])
    }

    func testFallbackVoiceIsDerivedFromCanonInsteadOfGenericNPCCopy() {
        let voice = character.resolvedWritingVoice.promptDescription

        XCTAssertTrue(voice.contains("wry"))
        XCTAssertTrue(voice.contains("answers questions with a route"))
        XCTAssertTrue(voice.contains("a useful map should leave one choice unmarked"))
        XCTAssertTrue(voice.contains("hides concern inside jokes"))
        XCTAssertTrue(voice.contains("use contractions"))
    }

    func testPacketExcludesNonSpeakingWorldEntities() {
        let location = NarrativeWorldEntity(
            id: "room-test",
            packID: "test",
            name: "The Test Room",
            kind: .location,
            belief: 10,
            narrativeWeight: 10,
            traits: ["drafty"],
            tags: ["room"]
        )

        let packet = CharacterCanonPacket.promptSection(for: [location, character])

        XCTAssertTrue(packet.contains("Juniper Test"))
        XCTAssertFalse(packet.contains("The Test Room [room-test]"))
    }

    func testEveryBundledCharacterShipsABespokeVoiceCardWithCadenceExamples() {
        XCTAssertEqual(CharacterVoiceCatalog.bundledCharacterIDs.count, 25)
        XCTAssertEqual(
            CharacterVoiceCatalog.bundledCharacterIDs.count,
            Set(CharacterVoiceCatalog.bundledCharacterIDs).count
        )

        for id in CharacterVoiceCatalog.bundledCharacterIDs {
            let profile = CharacterVoiceCatalog.profile(for: id)
            XCTAssertNotNil(profile, id)
            XCTAssertFalse(profile?.rhythm.isEmpty ?? true, id)
            XCTAssertFalse(profile?.diction.isEmpty ?? true, id)
            XCTAssertFalse(profile?.avoid.isEmpty ?? true, id)
            XCTAssertGreaterThanOrEqual(profile?.exemplars.count ?? 0, 2, id)
        }

        XCTAssertNotEqual(
            CharacterVoiceCatalog.profile(for: "penny-blackletter")?.rhythm,
            CharacterVoiceCatalog.profile(for: "wicker-eddies")?.rhythm
        )
        XCTAssertNotEqual(
            CharacterVoiceCatalog.profile(for: "dr-inkrest")?.diction,
            CharacterVoiceCatalog.profile(for: "dr-vellum")?.diction
        )
        XCTAssertNotEqual(
            CharacterVoiceCatalog.profile(for: "professor-thaddeus-mook")?.register,
            CharacterVoiceCatalog.profile(for: "pippa-pilcrow")?.register
        )
        XCTAssertNotEqual(
            CharacterVoiceCatalog.profile(for: "orion-blackthorn")?.diction,
            CharacterVoiceCatalog.profile(for: "soren-ng")?.diction
        )
        XCTAssertNotEqual(
            CharacterVoiceCatalog.profile(for: "finn-bridges")?.rhythm,
            CharacterVoiceCatalog.profile(for: "professor-kyle-momort")?.rhythm
        )
        XCTAssertNotEqual(
            CharacterVoiceCatalog.profile(for: "lysander-mosswood")?.register,
            CharacterVoiceCatalog.profile(for: "professor-cedric-stonebrook")?.register
        )
    }

    func testVoiceProfileDecodesLegacyPayloadWithoutExamples() throws {
        let data = Data(
            """
            {
              "register": "dry",
              "rhythm": "short",
              "diction": ["file"],
              "habits": ["notices proof"],
              "avoid": ["grand speeches"]
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(WritingVoiceProfile.self, from: data)

        XCTAssertEqual(decoded.register, "dry")
        XCTAssertEqual(decoded.exemplars, [])
    }

    func testPromptBudgetPreservesCanonAndTheTailContract() {
        let canon = CharacterCanonPacket.promptSection(for: [character])
        let oversizedMiddle = String(repeating: "supporting observation ", count: 1_200)
        let prompt = """
        OPENING CONTRACT
        \(oversizedMiddle)
        \(canon)
        OUTPUT FORMAT, EXACTLY:
        SCENE:
        """

        let fit = LocalBrainPromptBudget.fit(
            prompt: prompt,
            instructions: "Write the scene.",
            maxOutputTokens: 920
        )

        XCTAssertTrue(fit.wasCompacted)
        XCTAssertTrue(fit.preservedCharacterCanon)
        XCTAssertTrue(fit.prompt.contains("Juniper Test"))
        XCTAssertTrue(fit.prompt.contains(CharacterCanonPacket.endMarker))
        XCTAssertTrue(fit.prompt.contains("OUTPUT FORMAT, EXACTLY"))
        XCTAssertLessThanOrEqual(
            LocalBrainPromptBudget.estimatedTokens(for: "Write the scene.\n" + fit.prompt),
            fit.inputBudgetTokens + 2
        )
    }

    func testCharacterGenerationRoutesHaveExplicitEnforcement() {
        let ids = CharacterGenerationRouteRegistry.routes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertTrue(ids.contains("story-page"))
        XCTAssertTrue(ids.contains("letter-page"))
        XCTAssertTrue(ids.contains("student-notes"))
        XCTAssertTrue(ids.contains("two-readings"))
        XCTAssertTrue(ids.contains("cast-bond"))
        XCTAssertTrue(ids.contains("support-guild"))
        XCTAssertTrue(ids.contains("goblin-clerk"))
        XCTAssertEqual(
            CharacterGenerationRouteRegistry.contract(for: "fae-parley-literaryElf-result")?.enforcement,
            .sharedCanonAndAudit
        )
    }

    func testEvaluationDeckCoversEveryBundledVoiceAndHardPairs() {
        let covered = Set(CharacterVoiceEvaluationDeck.scenarios.flatMap(\.characterIDs))
        XCTAssertEqual(covered, Set(CharacterVoiceCatalog.bundledCharacterIDs))
        XCTAssertTrue(
            CharacterVoiceEvaluationDeck.scenarios.contains {
                Set($0.characterIDs) == Set(["penny-blackletter", "wicker-eddies"])
            }
        )
        XCTAssertTrue(
            CharacterVoiceEvaluationDeck.scenarios.contains {
                Set($0.characterIDs) == Set(["dr-inkrest", "dr-vellum"])
            }
        )
        XCTAssertTrue(
            CharacterVoiceEvaluationDeck.scenarios.contains {
                Set($0.characterIDs) == Set(["orion-blackthorn", "soren-ng"])
            }
        )
        XCTAssertTrue(
            CharacterVoiceEvaluationDeck.scenarios.contains {
                Set($0.characterIDs) == Set(["professor-vivian-villanelle", "professor-luna-wispwood"])
            }
        )
        for scenario in CharacterVoiceEvaluationDeck.scenarios {
            XCTAssertFalse(scenario.identificationClues.isEmpty, scenario.id)
            XCTAssertFalse(scenario.forbiddenTransfers.isEmpty, scenario.id)
        }
    }
}
