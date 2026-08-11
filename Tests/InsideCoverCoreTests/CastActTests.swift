import XCTest
@testable import InsideCoverCore

/// The Academy's action vocabulary used to be three verbs and two relationship
/// moves, which produced "Wicker lent some warmth to Penny; they grew closer":
/// a description of a ledger entry rather than of a thing a person did.
///
/// These tests hold the replacement to its two promises: the same act means
/// different things in different hands, and warmth is evidenced rather than
/// asserted.
final class CastActTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Manner

    func testTheSameActReadsDifferentlyInDifferentHands() {
        let penny = CastMannerCatalog.render(
            act: .correctInPublic, actorID: "penny-blackletter",
            actorName: "Penny", targetName: "Wicker"
        )
        let wicker = CastMannerCatalog.render(
            act: .correctInPublic, actorID: "wicker-eddies",
            actorName: "Wicker", targetName: "Penny"
        )
        XCTAssertNotEqual(penny, wicker)
        XCTAssertTrue(penny.contains("date"), "Penny corrects with the record: \(penny)")
        XCTAssertTrue(wicker.contains("interrupt"), "Wicker corrects performatively: \(wicker)")
    }

    func testNobodySaysLentSomeWarmth() {
        // The exact phrasing this whole system exists to delete.
        for act in CastAct.allCases {
            for manner in CastMannerCatalog.manners {
                let line = CastMannerCatalog.render(
                    act: act, actorID: manner.castID,
                    actorName: "Someone", targetName: "Another"
                )
                let lowered = line.lowercased()
                XCTAssertFalse(lowered.contains("lent some warmth"), line)
                XCTAssertFalse(lowered.contains("they grew closer"), line)
                XCTAssertFalse(lowered.contains("the air between them tightened"), line)
            }
        }
    }

    func testTheTargetPlaceholderIsAlwaysFilled() {
        for manner in CastMannerCatalog.manners {
            for (act, _) in manner.renderings {
                let line = CastMannerCatalog.render(
                    act: act, actorID: manner.castID,
                    actorName: "Someone", targetName: "Another"
                )
                XCTAssertFalse(line.contains("{target}"), "\(manner.castID)/\(act) leaked a placeholder")
            }
        }
    }

    func testCharacterHoldsAgainstConvenience() {
        // Serenity does not exclude people, whatever the simulation wants.
        XCTAssertFalse(CastMannerCatalog.wouldPerform(.exclude, castID: "serenity-brown"))
        XCTAssertFalse(CastMannerCatalog.wouldPerform(.takeCredit, castID: "serenity-brown"))
        // And Wicker will not apologise properly.
        XCTAssertFalse(CastMannerCatalog.wouldPerform(.apologiseBadly, castID: "wicker-eddies"))
        // Somebody with no card will do anything.
        XCTAssertTrue(CastMannerCatalog.wouldPerform(.exclude, castID: "nobody-in-particular"))
    }

    func testARefusedActIsNeverChosen() {
        for seed in 0..<200 {
            let act = CastMannerCatalog.chooseAct(castID: "serenity-brown", seed: "s\(seed)")
            XCTAssertNotEqual(act, .exclude)
            XCTAssertNotEqual(act, .takeCredit)
            XCTAssertNotEqual(act, .correctInPublic)
        }
    }

    func testActChoiceIsStableAndVaried() {
        let first = CastMannerCatalog.chooseAct(castID: "wicker-eddies", seed: "same")
        let second = CastMannerCatalog.chooseAct(castID: "wicker-eddies", seed: "same")
        XCTAssertEqual(first, second, "The same turn chose two different acts")

        var seen: Set<CastAct> = []
        for seed in 0..<120 {
            seen.insert(CastMannerCatalog.chooseAct(castID: "wicker-eddies", seed: "s\(seed)"))
        }
        XCTAssertGreaterThan(seen.count, 3, "Wicker only ever does \(seen.count) thing(s)")
    }

    // MARK: Two people, two memories

    func testBothPartiesRememberAndNotTheSameWay() {
        let memories = CastActMemory.memories(
            act: .coverFor,
            actorID: "wicker-eddies", actorName: "Wicker",
            targetID: "penny-blackletter", targetName: "Penny"
        )
        XCTAssertEqual(memories.count, 2)

        let wicker = memories.first { $0.entityID == "wicker-eddies" }
        let penny = memories.first { $0.entityID == "penny-blackletter" }
        XCTAssertNotNil(wicker)
        XCTAssertNotNil(penny)
        XCTAssertNotEqual(wicker?.summary, penny?.summary,
                          "Both people remembered the same act identically")

        // The specific asymmetry that makes this worth having.
        XCTAssertTrue(wicker?.summary.contains("took the blame") == true)
        XCTAssertTrue(penny?.summary.contains("thanked") == true,
                      "Penny should remember not having thanked him: \(penny?.summary ?? "")")
    }

    func testEveryActHasBothInsides() {
        for act in CastAct.allCases {
            let memories = CastActMemory.memories(
                act: act, actorID: "a", actorName: "A", targetID: "b", targetName: "B"
            )
            XCTAssertEqual(memories.count, 2, "\(act) produced \(memories.count) memories")
            XCTAssertNotEqual(memories[0].summary, memories[1].summary, "\(act) is symmetrical")
            for memory in memories {
                XCTAssertFalse(memory.summary.isEmpty)
                XCTAssertTrue(memory.tags.contains("cast-act"), "\(act) memory is not findable")
            }
        }
    }

    func testMemoriesAreTaggedWithWhoTheyAreAbout() {
        let memories = CastActMemory.memories(
            act: .defend, actorID: "a", actorName: "A", targetID: "b", targetName: "B"
        )
        XCTAssertTrue(memories.first { $0.entityID == "a" }?.tags.contains("toward:b") == true)
        XCTAssertTrue(memories.first { $0.entityID == "b" }?.tags.contains("from:a") == true)
    }

    // MARK: The ledger remembers

    private func record(_ act: CastAct, day offset: Int, actor: String = "wicker-eddies", target: String = "penny-blackletter") -> CastActRecord {
        CastActRecord(
            id: "r-\(act.rawValue)-\(offset)",
            actorID: actor, actorName: "Wicker",
            targetID: target, targetName: "Penny",
            act: act,
            line: "line",
            occurredAt: now.addingTimeInterval(Double(offset) * 86_400),
            tags: []
        )
    }

    func testTheSecondTimeKnowsAboutTheFirst() {
        var ledger = CastActLedger.empty
        XCTAssertNil(
            CastActMemory.callback(for: .correctInPublic, actorName: "Wicker",
                                   targetName: "Penny", priorCount: 0, lastLine: nil),
            "A first time is not a pattern and should say nothing"
        )

        ledger.record(record(.correctInPublic, day: 0))
        let prior = ledger.count(act: .correctInPublic, by: "wicker-eddies", to: "penny-blackletter")
        XCTAssertEqual(prior, 1)
        let second = CastActMemory.callback(for: .correctInPublic, actorName: "Wicker",
                                            targetName: "Penny", priorCount: prior, lastLine: "line")
        XCTAssertNotNil(second)
        XCTAssertTrue(second?.contains("second time") == true)
    }

    func testThreeTimesBecomesAHabit() {
        var ledger = CastActLedger.empty
        ledger.record(record(.correctInPublic, day: 0))
        ledger.record(record(.correctInPublic, day: 4))
        let prior = ledger.count(act: .correctInPublic, by: "wicker-eddies", to: "penny-blackletter")
        let line = CastActMemory.callback(for: .correctInPublic, actorName: "Wicker",
                                          targetName: "Penny", priorCount: prior, lastLine: "line")
        XCTAssertTrue(line?.contains("habit") == true, "Got: \(line ?? "nil")")
    }

    func testTheLedgerFindsAPairWhicheverWayRound() {
        var ledger = CastActLedger.empty
        ledger.record(record(.defend, day: 0))
        ledger.record(record(.concede, day: 1, actor: "penny-blackletter", target: "wicker-eddies"))
        XCTAssertEqual(ledger.between("wicker-eddies", "penny-blackletter").count, 2)
        XCTAssertEqual(ledger.between("penny-blackletter", "wicker-eddies").count, 2)
    }

    /// Standing is read off what happened, not off a stored score.
    func testStandingIsEvidencedNotAsserted() {
        var ledger = CastActLedger.empty
        ledger.record(record(.defend, day: 0))
        ledger.record(record(.coverFor, day: 1))
        XCTAssertEqual(ledger.standing("wicker-eddies", "penny-blackletter"), 4)

        ledger.record(record(.takeCredit, day: 2))
        XCTAssertEqual(ledger.standing("wicker-eddies", "penny-blackletter"), 2)
    }

    func testTheLedgerStaysAPlaceNotADatabase() {
        var ledger = CastActLedger.empty
        for index in 0..<(CastActLedger.capacity + 60) {
            ledger.record(CastActRecord(
                id: "r\(index)", actorID: "a", actorName: "A", targetID: "b", targetName: "B",
                act: .concede, line: "l", occurredAt: now.addingTimeInterval(Double(index)), tags: []
            ))
        }
        XCTAssertEqual(ledger.records.count, CastActLedger.capacity)
    }

    // MARK: Obligations outlive the reader's attention

    func testAnUnansweredDebtStaysOpen() {
        var ledger = CastActLedger.empty
        ledger.record(record(.coverFor, day: 0))
        let open = ledger.openObligations(from: "wicker-eddies")
        XCTAssertEqual(open.count, 1)

        let line = CastActMemory.obligationLine(open[0], now: now.addingTimeInterval(40 * 86_400))
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("not mentioned") == true, "Got: \(line ?? "nil")")
    }

    func testARepaidDebtCloses() {
        var ledger = CastActLedger.empty
        ledger.record(record(.coverFor, day: 0))
        ledger.record(record(.repayEarly, day: 3, actor: "penny-blackletter", target: "wicker-eddies"))
        XCTAssertTrue(ledger.openObligations(from: "wicker-eddies").isEmpty)
    }

    func testAFreshDebtIsNotYetFurniture() {
        var ledger = CastActLedger.empty
        ledger.record(record(.owe, day: 0))
        let open = ledger.openObligations(from: "wicker-eddies")
        XCTAssertNil(
            CastActMemory.obligationLine(open[0], now: now.addingTimeInterval(3 * 86_400)),
            "Three days is not long enough for a debt to have become a thing"
        )
    }

    // MARK: Mechanics survive underneath

    func testTheArithmeticStillWorks() {
        XCTAssertGreaterThan(CastAct.defend.relationshipDelta, 0)
        XCTAssertLessThan(CastAct.takeCredit.relationshipDelta, 0)
        XCTAssertEqual(CastAct.owe.relationshipDelta, 0, "Owing is not a feeling")

        // Most acts do not touch Belief. Pretending otherwise is what made the
        // old system read as a game.
        let beliefMoving = CastAct.allCases.filter { $0.beliefDelta != 0 }
        XCTAssertLessThanOrEqual(beliefMoving.count, 6, "Too much of ordinary life is being scored as Belief")
    }

    func testTheComplicatedActsAreNotAdjudicated() {
        // These are kind and unkind at once and the Book must not pick.
        for act in [CastAct.coverFor, .forgetDeliberately, .withhold, .concede, .forgiveADebt] {
            XCTAssertTrue(act.isComplicated, "\(act) should be ambiguous")
        }
        XCTAssertFalse(CastAct.defend.isComplicated)
    }

    // MARK: Assembly

    func testPerformProducesEverythingAtOnce() {
        var ledger = CastActLedger.empty
        ledger.record(record(.coverFor, day: 0))

        let performance = CastActMemory.perform(
            act: .coverFor,
            actorID: "wicker-eddies", actorName: "Wicker",
            targetID: "penny-blackletter", targetName: "Penny",
            ledger: ledger, at: now, seed: "seed"
        )
        XCTAssertFalse(performance.record.line.isEmpty)
        XCTAssertEqual(performance.memories.count, 2)
        XCTAssertNotNil(performance.callback, "The second occurrence should refer back")
        XCTAssertTrue(performance.record.tags.contains(CastAct.coverFor.tag))
    }

    func testActsSurviveTheRoundTripThroughMetadata() {
        let records = [record(.defend, day: 0), record(.confide, day: 1)]
        let encoded = CastActArchive.encode(records)
        XCTAssertFalse(encoded.isEmpty)
        let decoded = CastActArchive.decode(encoded)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.first?.line, records.first?.line, "The rendered line must survive verbatim")
        XCTAssertEqual(CastActArchive.decode("not base 64").count, 0)
    }

    // MARK: Voice

    func testEveryAuthoredLineIsConcrete() {
        // The bar the undertaking ladders set: physical, specific, no abstraction.
        // The ban is on *ledger* language: sentences that describe the score
        // rather than the act. A character being described as behaving warmly
        // is fine; "warmth" as a quantity that moved between two people is not.
        let vague = ["lent some warmth", "grew closer", "grew apart", "the bond",
                     "their connection", "relationship improved", "relationship worsened",
                     "affinity", "rapport increased"]
        for manner in CastMannerCatalog.manners {
            for (act, rendering) in manner.renderings {
                let lowered = rendering.lowercased()
                for word in vague {
                    XCTAssertFalse(lowered.contains(word),
                                   "\(manner.castID)/\(act) is abstract: \(rendering)")
                }
                XCTAssertGreaterThan(rendering.count, 40, "\(manner.castID)/\(act) is too thin")
            }
        }
    }

    func testEveryCardedCastMemberHasOpinionsAboutWhatTheyWillDo() {
        for manner in CastMannerCatalog.manners {
            XCTAssertFalse(manner.signature.isEmpty, "\(manner.castID) has no signature")
            XCTAssertFalse(manner.favours.isEmpty, "\(manner.castID) reaches for nothing")
            XCTAssertFalse(manner.renderings.isEmpty, "\(manner.castID) has no authored acts")
            XCTAssertTrue(manner.favours.isDisjoint(with: manner.refuses),
                          "\(manner.castID) both favours and refuses the same act")
        }
        XCTAssertGreaterThanOrEqual(CastMannerCatalog.manners.count, 8)
    }
}

/// The Cast Ledger on the home screen renders `CastAgencyMovement.line`, which
/// is written on a different path from the Gossip Page prose. Replacing the
/// verbs in one place left "Wicker warmed toward Penny" sitting on the home
/// screen, which is where the reader actually looks.
final class CastLedgerLineTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTheLedgerNoLongerSaysWarmedToward() {
        for warming in [true, false] {
            for castID in CastMannerCatalog.manners.map(\.castID) {
                let line = CastMannerCatalog.ledgerLine(
                    actorID: castID, actorName: "Someone",
                    targetID: "other", targetName: "Another",
                    warming: warming, alreadyPerformed: [], seed: "s"
                )
                let lowered = line.lowercased()
                XCTAssertFalse(lowered.contains("warmed toward"), line)
                XCTAssertFalse(lowered.contains("cooled toward"), line)
                XCTAssertFalse(lowered.contains("tried to talk up"), line)
                XCTAssertFalse(line.isEmpty)
            }
        }
    }

    /// The ledger and the page must describe the same event in the same words.
    func testTheLedgerReusesThePagesOwnSentence() {
        let performed = CastActRecord(
            id: "r", actorID: "wicker-eddies", actorName: "Wicker",
            targetID: "penny-blackletter", targetName: "Penny",
            act: .coverFor, line: "Wicker took the blame instantly and loudly.",
            occurredAt: now, tags: []
        )
        let line = CastMannerCatalog.ledgerLine(
            actorID: "wicker-eddies", actorName: "Wicker",
            targetID: "penny-blackletter", targetName: "Penny",
            warming: true, alreadyPerformed: [performed], seed: "s"
        )
        XCTAssertEqual(line, performed.line, "The ledger wrote its own second version of the event")
    }

    func testAnActFromADifferentPairIsNotBorrowed() {
        let unrelated = CastActRecord(
            id: "r", actorID: "serenity-brown", actorName: "Serenity",
            targetID: "someone-else", targetName: "Else",
            act: .concede, line: "A completely different event.",
            occurredAt: now, tags: []
        )
        let line = CastMannerCatalog.ledgerLine(
            actorID: "wicker-eddies", actorName: "Wicker",
            targetID: "penny-blackletter", targetName: "Penny",
            warming: true, alreadyPerformed: [unrelated], seed: "s"
        )
        XCTAssertNotEqual(line, unrelated.line)
        XCTAssertTrue(line.contains("Penny"), "Got: \(line)")
    }

    /// A movement recorded as warmth must not be illustrated by somebody
    /// taking credit for another person's work.
    func testTheActPointsTheSameWayAsTheMovement() {
        for seed in 0..<80 {
            let warm = CastMannerCatalog.chooseAct(
                castID: "penny-blackletter", seed: "s\(seed)", warming: true
            )
            XCTAssertGreaterThan(warm.relationshipDelta, 0, "\(warm) is not a warming act")

            let cool = CastMannerCatalog.chooseAct(
                castID: "wicker-eddies", seed: "s\(seed)", warming: false
            )
            XCTAssertLessThan(cool.relationshipDelta, 0, "\(cool) is not a cooling act")
        }
    }

    func testADirectionlessChoiceStillWorks() {
        let act = CastMannerCatalog.chooseAct(castID: "wicker-eddies", seed: "s")
        XCTAssertTrue(CastAct.allCases.contains(act))
    }

    func testSomebodyWithNoCardStillGetsAConcreteLine() {
        let line = CastMannerCatalog.ledgerLine(
            actorID: "nobody-in-particular", actorName: "A Stranger",
            targetID: "other", targetName: "Another",
            warming: true, alreadyPerformed: [], seed: "s"
        )
        XCTAssertTrue(line.contains("A Stranger"))
        XCTAssertTrue(line.contains("Another"))
        XCTAssertFalse(line.contains("{target}"))
    }

    func testTheLedgerLineIsStableForTheSameMovement() {
        let first = CastMannerCatalog.ledgerLine(
            actorID: "wicker-eddies", actorName: "Wicker", targetID: "p", targetName: "Penny",
            warming: false, alreadyPerformed: [], seed: "slot-1"
        )
        let second = CastMannerCatalog.ledgerLine(
            actorID: "wicker-eddies", actorName: "Wicker", targetID: "p", targetName: "Penny",
            warming: false, alreadyPerformed: [], seed: "slot-1"
        )
        XCTAssertEqual(first, second)
    }
}
