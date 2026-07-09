import XCTest
@testable import InsideCoverCore

final class AskTheBookKnowledgePromptTests: XCTestCase {
    func testCompassQuestionReceivesCompassAndAppSystemKnowledge() {
        let packet = BookKnowledgePromptBuilder.trainingPacket(for: "How do Compass Runs work?")

        XCTAssertTrue(packet.contains("The Wonder Compass is the real-world method"))
        XCTAssertTrue(packet.contains("Notice/North"))
        XCTAssertTrue(packet.contains("Compass Runs"))
        XCTAssertTrue(packet.contains("One-Sentence Souvenir"))
    }

    func testCastQuestionReceivesMatchedCastKnowledge() {
        let packet = BookKnowledgePromptBuilder.trainingPacket(for: "Who is Zara Finch?")

        XCTAssertTrue(packet.contains("Zara Finch"))
        XCTAssertTrue(packet.contains("safe path") || packet.contains("loyal") || packet.contains("Compass Runs"))
    }

    func testSystemQuestionReceivesStoryPagesAndBeliefKnowledge() {
        let packet = BookKnowledgePromptBuilder.trainingPacket(for: "What are Story Pages and Belief?")

        XCTAssertTrue(packet.contains("Story Pages"))
        XCTAssertTrue(packet.contains("Belief is attention made usable"))
        XCTAssertTrue(packet.contains("Glow"))
    }
}
