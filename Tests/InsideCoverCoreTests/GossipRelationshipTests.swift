import XCTest
@testable import InsideCoverCore

final class GossipRelationshipTests: XCTestCase {
    func testStableWeightedRollCanSelectLowerWeightedCandidate() {
        struct Candidate: Equatable {
            var id: String
            var weight: Int
        }
        let high = Candidate(id: "highest", weight: 90)
        let low = Candidate(id: "lower", weight: 10)
        let candidates = [high, low]

        let lowerHit = (0..<1_000).contains { index in
            StableWeightedRoll.pick(
                from: candidates,
                seed: "weighted-roll-proof-\(index)",
                weight: \.weight
            ) == low
        }

        XCTAssertTrue(lowerHit, "Weighted rolls should bias toward high weights without making them deterministic winners.")
    }

    func testStableWeightedRollOrderingDoesNotAlwaysPutHighestFirst() {
        struct Candidate: Equatable {
            var id: String
            var weight: Int
        }
        let candidates = [
            Candidate(id: "highest", weight: 80),
            Candidate(id: "middle", weight: 15),
            Candidate(id: "lower", weight: 5)
        ]

        let nonHighestLead = (0..<1_000).contains { index in
            StableWeightedRoll.ordered(
                from: candidates,
                seed: "weighted-order-proof-\(index)",
                weight: \.weight
            ).first?.id != "highest"
        }

        XCTAssertTrue(nonHighestLead, "Weighted ordering should not collapse into sorting by the maximum score.")
    }

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

    func testPageBeliefMoveTokenFormat() {
        let move = GossipPageBeliefMove(
            actorID: "penny-blackletter",
            actorName: "Penny",
            sourceID: "wonder-compass",
            sourceTitle: "Wonder Compass",
            kind: .invest,
            amount: 2
        )

        XCTAssertEqual(move.token, "penny-blackletter>wonder-compass:invest:2")
        XCTAssertTrue(move.promptLine.contains("Penny"))
        XCTAssertTrue(move.promptLine.contains("Wonder Compass"))
        XCTAssertTrue(move.promptLine.contains("Pages"))
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

    func testGossipSurfaceCarriesPageBeliefMoves() {
        let inputs = BookSourceInputs.empty
        let now = Date()
        let pages = (0..<5).map { i in
            BookPage(type: .diary, createdAt: now, promptText: "now",
                     userInput: "A small kept thing number \(i)", tags: ["kept"])
        }
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: pages)

        let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: now)

        XCTAssertEqual(surface.type, .gossip)
        XCTAssertFalse(surface.payload.metadata["pageBeliefMoves"]?.isEmpty ?? true)
        XCTAssertTrue(surface.payload.metadata["pageBeliefMoveLines"]?.contains("Pages") ?? false)
        XCTAssertTrue(surface.payload.metadata["simulationPacket"]?.contains("Page Belief:") ?? false)
    }

    func testBookAsideReframesExactGossipReceiptsInTheBooksVoice() {
        let gossip = notableGossipSurface(turnID: automaticAsideTurnID())

        let aside = BookAsideForm.draft(from: gossip)

        XCTAssertEqual(aside.type, .bookAside)
        XCTAssertEqual(aside.sourceID, "book-aside")
        XCTAssertEqual(aside.intent, .simulate)
        XCTAssertEqual(aside.payload.metadata[BookAsideForm.editorialFormKey], BookAsideForm.editorialFormValue)
        XCTAssertEqual(aside.payload.metadata["relationshipMoves"], gossip.payload.metadata["relationshipMoves"])
        XCTAssertEqual(aside.payload.metadata["simulationPacket"], gossip.payload.metadata["simulationPacket"])
        XCTAssertTrue(aside.payload.body.hasPrefix("Listen. I have been waiting to tell you"))
        XCTAssertTrue(aside.payload.body.contains("I may have misjudged"))
        XCTAssertFalse(aside.payload.body.contains("What changed:"))
        XCTAssertFalse(aside.payload.body.contains("•"))
        XCTAssertTrue(aside.payload.metadata["tags"]?.contains("book-aside") ?? false)
    }

    func testBookAsideAutomaticGateIsRareAndRequiresATellableTurn() {
        let eligible = notableGossipSurface(turnID: automaticAsideTurnID())
        XCTAssertTrue(BookAsideForm.shouldSurfaceAutomatically(from: eligible))

        var quietMetadata = eligible.payload.metadata
        quietMetadata["relationshipMoves"] = ""
        quietMetadata["chapterTalismanMoves"] = ""
        quietMetadata["pageBeliefMoves"] = ""
        quietMetadata["actionKinds"] = GossipSimulationActionKind.takeAction.rawValue
        let quiet = SurfacePage(
            id: eligible.id,
            type: eligible.type,
            sourceID: eligible.sourceID,
            intent: eligible.intent,
            renderStyle: eligible.renderStyle,
            score: eligible.score,
            reason: eligible.reason,
            prompt: eligible.prompt,
            detail: eligible.detail,
            payload: BookPagePayload(
                headline: eligible.payload.headline,
                body: eligible.payload.body,
                metadata: quietMetadata
            )
        )
        XCTAssertFalse(BookAsideForm.shouldSurfaceAutomatically(from: quiet))

        let hits = (0..<1_000).filter { index in
            BookAsideForm.shouldSurfaceAutomatically(from: notableGossipSurface(turnID: "aside-cadence-\(index)"))
        }.count
        XCTAssertGreaterThan(hits, 150)
        XCTAssertLessThan(hits, 330)
    }

    func testPreparedAsideRoutesThroughAsideAdapterInsteadOfGossipAdapter() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.preparedGossipPageSurface = BookAsideForm.draft(from: notableGossipSurface(turnID: automaticAsideTurnID()))
        let context = CuratorContext.make(for: day)

        XCTAssertTrue(GossipPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now).isEmpty)
        XCTAssertEqual(BookAsidePageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now).first?.type, .bookAside)
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

    private func automaticAsideTurnID() -> String {
        (0..<10_000)
            .map { "automatic-aside-\($0)" }
            .first { Int($0.stableHash.magnitude % 100) < BookAsideForm.automaticPercent }!
    }

    private func notableGossipSurface(turnID: String) -> SurfacePage {
        SurfacePage(
            id: "gossip-page-\(turnID)",
            type: .gossip,
            sourceID: "gossip-page",
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 70,
            reason: "A relationship changed offscreen.",
            prompt: "Gossip from the Margins",
            detail: "Penny folded the apology into the atlas.",
            payload: BookPagePayload(
                headline: "The margins carried a rumor.",
                body: """
                Penny folded the apology into the atlas.
                The brass clasp would not close.
                • Finch kept the letter.

                What changed:
                • Finch kept the letter.
                """,
                metadata: [
                    "source": "gossip-page",
                    "turnID": turnID,
                    "actorName": "Penny Blackletter",
                    "actorNames": "Penny Blackletter, Zara Finch",
                    "actionKind": GossipSimulationActionKind.investBelief.rawValue,
                    "actionKinds": GossipSimulationActionKind.investBelief.rawValue,
                    "relationshipMoves": "penny-blackletter>zara-finch:invest:2",
                    "chapterTalismanMoves": "",
                    "pageBeliefMoves": "",
                    "simulationPacket": """
                    TURN 1
                    Actor: Penny Blackletter [penny-blackletter]
                    Overheard line: Penny folded the apology into the atlas.
                    Visible trace: The brass clasp would not close.
                    Consequences:
                    - Finch kept the letter.
                    """,
                    "gossipDraft": """
                    Penny folded the apology into the atlas.
                    The brass clasp would not close.
                    • Finch kept the letter.

                    What changed:
                    • Finch kept the letter.
                    """,
                    "tags": "gossip,relationship"
                ]
            )
        )
    }
}
