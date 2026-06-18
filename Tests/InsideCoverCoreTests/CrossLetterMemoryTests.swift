import XCTest
@testable import InsideCoverCore

final class CrossLetterMemoryTests: XCTestCase {
    private let sender = NarrativeWorldEntity(
        id: "penny-blackletter", packID: "core", name: "Penny Blackletter",
        kind: .character, belief: 30, narrativeWeight: 24,
        beliefs: ["honest details matter"], tags: ["records"]
    )

    func testNoHistoryReturnsNil() {
        let inputs = BookSourceInputs.empty
        XCTAssertNil(CharacterLetterPageGenerator.crossLetterMemory(for: sender, day: BookDay.today(), inputs: inputs))
    }

    func testRecallsAPriorLetter() {
        var inputs = BookSourceInputs.empty
        let priorLetter = BookPage(
            type: .letter, createdAt: Date().addingTimeInterval(-3 * 86_400), promptText: "Letter from Penny",
            userInput: "Dear friend, I found a receipt with a cat drawn on it.",
            tags: ["letter", "sender:penny-blackletter"]
        )
        inputs.days = [BookDay(id: "2026-06-10", date: Date().addingTimeInterval(-3 * 86_400), pages: [priorLetter])]
        let memory = CharacterLetterPageGenerator.crossLetterMemory(for: sender, day: BookDay.today(), inputs: inputs)
        XCTAssertNotNil(memory)
        XCTAssertTrue(memory?.contains("last wrote") ?? false)
        XCTAssertTrue(memory?.contains("cat") ?? false)
    }

    func testRemembersSidingWithAndAgainst() {
        var inputs = BookSourceInputs.empty
        // Reader sided WITH Penny over someone else.
        let sidedWith = BookPage(
            type: .twoReadings, createdAt: Date().addingTimeInterval(-2 * 86_400), promptText: "The Two Readings", userInput: "...",
            tags: ["two-readings", "entity:penny-blackletter", "entity:dr-inkrest", "sided:penny-blackletter"]
        )
        inputs.days = [BookDay(id: "2026-06-11", date: Date().addingTimeInterval(-2 * 86_400), pages: [sidedWith])]
        XCTAssertTrue(CharacterLetterPageGenerator.crossLetterMemory(for: sender, day: BookDay.today(), inputs: inputs)?.contains("WITH you") ?? false)

        // Reader sided AGAINST Penny (chose the rival).
        let sidedAgainst = BookPage(
            type: .twoReadings, createdAt: Date().addingTimeInterval(-1 * 86_400), promptText: "The Two Readings", userInput: "...",
            tags: ["two-readings", "entity:penny-blackletter", "entity:dr-inkrest", "sided:dr-inkrest"]
        )
        inputs.days = [BookDay(id: "2026-06-12", date: Date().addingTimeInterval(-1 * 86_400), pages: [sidedAgainst])]
        XCTAssertTrue(CharacterLetterPageGenerator.crossLetterMemory(for: sender, day: BookDay.today(), inputs: inputs)?.contains("AGAINST you") ?? false)
    }

    func testBeliefStandingShowsUp() {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets = ["penny-blackletter": 8]
        XCTAssertTrue(CharacterLetterPageGenerator.crossLetterMemory(for: sender, day: BookDay.today(), inputs: inputs)?.contains("Belief") ?? false)
    }
}
