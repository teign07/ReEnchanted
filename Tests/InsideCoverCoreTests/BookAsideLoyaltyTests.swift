import XCTest
@testable import InsideCoverCore

/// An Aside is not a report: it is the Book admitting it had a reaction. That
/// only lands if the reaction is about a *person*. These cover the
/// deterministic path, which is what runs when there is no local brain, and
/// which previously said one of three fixed sentences no matter who acted.
final class BookAsideLoyaltyTests: XCTestCase {

    private func loyalty(
        id: String,
        name: String,
        stance: BookLoyaltyStance,
        strength: BookLoyaltyStrength = .devoted,
        counterweight: String = "They can be insufferable about it afterwards."
    ) -> BookLoyalty {
        BookLoyalty(
            id: "book-loyalty-cast-\(id)",
            targetID: id,
            targetName: name,
            targetKind: .castMember,
            strength: strength,
            stance: stance,
            reason: "reason",
            counterweight: counterweight,
            evidencePageIDs: [],
            formedAt: Date(),
            lastEvolvedAt: Date(),
            revisions: [],
            isCanonical: true
        )
    }

    private var cast: [BookLoyalty] {
        [
            loyalty(id: "wicker-eddies", name: "Wicker Eddies", stance: .delighted),
            loyalty(id: "serenity-brown", name: "Serenity Brown", stance: .delighted),
            loyalty(id: "penny-blackletter", name: "Penny Blackletter", stance: .protective)
        ]
    }

    private func gossip(
        turnID: String,
        actorID: String,
        actorName: String,
        actionKind: String = GossipSimulationActionKind.attackBelief.rawValue,
        relationshipMoves: String = "wicker-eddies:+2"
    ) -> SurfacePage {
        SurfacePage(
            id: "gossip-\(turnID)",
            type: .gossip,
            sourceID: "gossip",
            intent: .simulate,
            renderStyle: .loreLetter,
            score: 70,
            reason: "reason",
            prompt: "prompt",
            detail: "detail",
            payload: BookPagePayload(
                headline: "headline",
                body: "body",
                metadata: [
                    "turnID": turnID,
                    "actorID": actorID,
                    "actorName": actorName,
                    "actionKind": actionKind,
                    "relationshipMoves": relationshipMoves,
                    "simulationPacket": "packet",
                    "gossipDraft": "Something happened in the corridor."
                ]
            )
        )
    }

    // MARK: The reaction is about a person

    func testTheAsideNamesTheOneItIsFondOf() {
        let aside = BookAsideForm.draft(
            from: gossip(turnID: "t1", actorID: "wicker-eddies", actorName: "Wicker Eddies"),
            loyalties: cast
        )
        XCTAssertTrue(
            aside.payload.body.contains("Wicker"),
            "The Book should say who it was: \(aside.payload.body)"
        )
        XCTAssertEqual(aside.payload.metadata["asideLoyaltyTargetID"], "wicker-eddies")
    }

    func testDifferentPeopleGetDifferentReactions() {
        let wicker = BookAsideForm.draft(
            from: gossip(turnID: "same-turn", actorID: "wicker-eddies", actorName: "Wicker Eddies"),
            loyalties: cast
        )
        let penny = BookAsideForm.draft(
            from: gossip(turnID: "same-turn", actorID: "penny-blackletter", actorName: "Penny Blackletter"),
            loyalties: cast
        )
        XCTAssertNotEqual(wicker.payload.body, penny.payload.body,
                          "The same turn by two different people read identically")
        XCTAssertNotEqual(wicker.payload.headline, penny.payload.headline)
    }

    /// Delight and protectiveness are different feelings and should not sound
    /// the same.
    func testStanceChangesTheKeyOfTheReaction() {
        let delighted = BookAsideForm.reaction(
            actorIDs: ["wicker-eddies"], actorNames: ["Wicker Eddies"],
            actionKinds: "", loyalties: cast, seed: "s"
        )
        let protective = BookAsideForm.reaction(
            actorIDs: ["penny-blackletter"], actorNames: ["Penny Blackletter"],
            actionKinds: "", loyalties: cast, seed: "s"
        )
        XCTAssertNotEqual(delighted.line, protective.line)
        XCTAssertTrue(delighted.line.contains("Wicker"))
        XCTAssertTrue(protective.line.contains("Penny"))
    }

    func testAnAttackOnSomebodyItProtectsReadsAsAnnoyance() {
        let reaction = BookAsideForm.reaction(
            actorIDs: ["penny-blackletter"], actorNames: ["Penny Blackletter"],
            actionKinds: GossipSimulationActionKind.attackBelief.rawValue,
            loyalties: cast, seed: "s"
        )
        XCTAssertTrue(reaction.line.contains("Penny"))
        XCTAssertTrue(
            reaction.line.contains("record") || reaction.line.contains("receipt"),
            "Expected the Book to take Penny's side: \(reaction.line)"
        )
    }

    // MARK: Matching

    func testTheBookRecognisesAFirstNameOnItsOwn() {
        let byFirstName = BookAsideForm.loyalty(
            forActorIDs: [], actorNames: ["Wicker"], loyalties: cast
        )
        XCTAssertEqual(byFirstName?.targetID, "wicker-eddies")
    }

    func testTheStrongestLoyaltyWinsWhenSeveralActed() {
        var loyalties = cast
        loyalties.append(loyalty(id: "minor-figure", name: "Minor Figure",
                                 stance: .complicated, strength: .interested))
        let picked = BookAsideForm.loyalty(
            forActorIDs: ["minor-figure", "penny-blackletter"],
            actorNames: [], loyalties: loyalties
        )
        XCTAssertEqual(picked?.targetID, "penny-blackletter")
    }

    // MARK: Nobody it knows

    func testAStrangerStillGetsAReactionJustNotAPersonalOne() {
        let aside = BookAsideForm.draft(
            from: gossip(turnID: "t2", actorID: "somebody-new", actorName: "Somebody New"),
            loyalties: cast
        )
        XCTAssertNil(aside.payload.metadata["asideLoyaltyTargetID"])
        XCTAssertFalse(aside.payload.body.isEmpty)
        XCTAssertTrue(aside.payload.body.contains("I "), "The Book still has a view")
    }

    func testItWorksWithNoLoyaltiesAtAll() {
        let aside = BookAsideForm.draft(
            from: gossip(turnID: "t3", actorID: "wicker-eddies", actorName: "Wicker Eddies"),
            loyalties: []
        )
        XCTAssertFalse(aside.payload.body.isEmpty)
        XCTAssertEqual(aside.type, .bookAside)
    }

    // MARK: Devotion without flattery

    func testDevotionSometimesAdmitsTheOtherHalf() {
        var sawCounterweight = false
        for index in 0..<60 {
            let reaction = BookAsideForm.reaction(
                actorIDs: ["wicker-eddies"], actorNames: [],
                actionKinds: "", loyalties: cast, seed: "seed-\(index)"
            )
            if reaction.line.contains("gone soft") { sawCounterweight = true }
        }
        XCTAssertTrue(sawCounterweight, "The Book never once admitted the counterweight")
    }

    func testAPassingFondnessNeverReachesForTheCounterweight() {
        let mild = [loyalty(id: "x", name: "Ex Ample", stance: .delighted, strength: .interested)]
        for index in 0..<60 {
            let reaction = BookAsideForm.reaction(
                actorIDs: ["x"], actorNames: [], actionKinds: "",
                loyalties: mild, seed: "seed-\(index)"
            )
            XCTAssertFalse(reaction.line.contains("gone soft"))
        }
    }

    // MARK: De-repetition

    func testTheSameTurnAlwaysReadsTheSameWay() {
        let first = BookAsideForm.draft(
            from: gossip(turnID: "stable", actorID: "wicker-eddies", actorName: "Wicker Eddies"),
            loyalties: cast
        )
        let second = BookAsideForm.draft(
            from: gossip(turnID: "stable", actorID: "wicker-eddies", actorName: "Wicker Eddies"),
            loyalties: cast
        )
        XCTAssertEqual(first.payload.body, second.payload.body)
    }

    func testTheAsideDoesNotArriveWearingTheSameSentenceEveryTime() {
        var openings: Set<String> = []
        var lines: Set<String> = []
        for index in 0..<40 {
            let aside = BookAsideForm.draft(
                from: gossip(turnID: "turn-\(index)", actorID: "wicker-eddies", actorName: "Wicker Eddies"),
                loyalties: cast
            )
            let paragraphs = aside.payload.body.components(separatedBy: "\n\n")
            openings.insert(paragraphs.first ?? "")
            lines.insert(paragraphs.last ?? "")
        }
        XCTAssertGreaterThan(openings.count, 1, "Every Aside opened with the same sentence")
        XCTAssertGreaterThan(lines.count, 1, "Every Aside closed with the same sentence")
    }

    // MARK: The form's own promises

    /// The whole pleasure of the Page is that nothing is being asked of the
    /// reader. A question mark at the end would undo it.
    func testAnAsideNeverEndsWithAnAssignment() {
        for index in 0..<40 {
            for (id, name) in [("wicker-eddies", "Wicker Eddies"),
                               ("penny-blackletter", "Penny Blackletter"),
                               ("stranger", "A Stranger")] {
                let aside = BookAsideForm.draft(
                    from: gossip(turnID: "q-\(index)", actorID: id, actorName: name),
                    loyalties: cast
                )
                let body = aside.payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(body.hasSuffix("?"), "Ended with a question: \(body)")
                let lowered = body.lowercased()
                XCTAssertFalse(lowered.contains("what do you think"), "Asked for a response")
                XCTAssertFalse(lowered.contains("your turn"), "Handed out an assignment")
            }
        }
    }

    /// It must stay first-person. An Aside in a narrator's voice is Gossip.
    func testTheAsideAlwaysSpeaksAsItself() {
        for index in 0..<30 {
            let aside = BookAsideForm.draft(
                from: gossip(turnID: "voice-\(index)", actorID: "serenity-brown", actorName: "Serenity Brown"),
                loyalties: cast
            )
            let body = aside.payload.body
            XCTAssertTrue(body.contains("I ") || body.contains("I'"),
                          "The Book vanished from its own Aside: \(body)")
        }
    }
}
