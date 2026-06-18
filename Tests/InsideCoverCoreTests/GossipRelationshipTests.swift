import XCTest
@testable import InsideCoverCore

final class GossipRelationshipTests: XCTestCase {
    func testRelationshipMoveTokenFormat() {
        let move = GossipRelationshipMove(
            actorID: "penny-blackletter", actorName: "Penny",
            targetID: "dr-inkrest", targetName: "Inkrest",
            kind: .attack, amount: 2
        )
        XCTAssertEqual(move.token, "penny-blackletter>dr-inkrest:attack:2")
        XCTAssertTrue(move.promptLine.contains("Penny"))
        XCTAssertTrue(move.promptLine.contains("Inkrest"))
    }

    func testGossipSurfaceCarriesRelationshipMovesKey() {
        // A populated day so the simulation has actors and threads to work with.
        var inputs = BookSourceInputs.empty
        let now = Date()
        let pages = (0..<5).map { i in
            BookPage(type: .diary, createdAt: now, promptText: "now",
                     userInput: "A small kept thing number \(i)", tags: ["kept"])
        }
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: pages)
        // Seed tension between two likely actors so moves can be attacks.
        inputs.relationshipField = [
            NarrativeGraphData.relationshipPairKey("dr-vellum", "dr-inkrest"): RelationshipTie(warmth: 0, tension: 8, familiarity: 3)
        ]
        let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: now)
        XCTAssertEqual(surface.type, .gossip)
        // The key is always present (may be empty if no move landed this slot).
        XCTAssertNotNil(surface.payload.metadata["relationshipMoves"])
    }

    func testFieldWeaveInvestVsAttack() {
        var field: [String: RelationshipTie] = [:]
        RelationshipFieldEngine.weave(into: &field, entityIDs: ["a", "b"], warmth: 2, familiarity: 1)
        let key = NarrativeGraphData.relationshipPairKey("a", "b")
        XCTAssertEqual(field[key]?.warmth, 2)
        XCTAssertEqual(field[key]?.tension, 0)
        RelationshipFieldEngine.weave(into: &field, entityIDs: ["a", "b"], tension: 3)
        XCTAssertEqual(field[key]?.tension, 3)
        XCTAssertEqual(field[key]?.warmth, 2)
    }
}
