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
}
