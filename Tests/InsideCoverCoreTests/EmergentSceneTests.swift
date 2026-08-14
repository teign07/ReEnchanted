import XCTest
@testable import InsideCoverCore

/// The other supply. The authored ladders are fifty scenes somebody wrote; this
/// is the simulation telling its own incidents as scenes instead of as ledger
/// sentences, which is what keeps the Academy from falling silent once the
/// season has been read.
///
/// The law under test throughout: **no turn, no scene**. Every turn is lifted
/// from state the world already holds, and an incident the world produced no
/// turn for stays a report. That filter is the only thing standing between an
/// infinite supply and infinite filler, so most of these tests are about what
/// the composer *refuses* to do.
final class EmergentSceneTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func days(_ count: Double) -> Date { now.addingTimeInterval(-count * 86_400) }

    private func act(
        id: String = "act-1",
        _ kind: CastAct = .correctInPublic,
        actor: String = "penny-blackletter",
        target: String = "wicker-eddies",
        at: Date? = nil,
        tags: [String] = ["argument"]
    ) -> CastActRecord {
        CastActRecord(
            id: id,
            actorID: actor,
            actorName: "Penny",
            targetID: target,
            targetName: "Wicker",
            act: kind,
            line: "Penny corrected Wicker in front of everybody.",
            occurredAt: at ?? days(1),
            tags: tags
        )
    }

    private func room(
        id: String = "location-great-hall",
        argumentCount: Int = 0,
        refusal: String? = nil
    ) -> PlaceState {
        var state = PlaceState(id: id, refusal: refusal)
        for index in 0..<argumentCount {
            state.incidents.append(PlaceIncident(
                id: "incident-\(index)",
                line: "An argument.",
                participantIDs: ["penny-blackletter"],
                tags: ["argument"],
                occurredAt: days(Double(index + 2))
            ))
        }
        return state
    }

    // MARK: - No turn, no scene

    func testAnIncidentWithNoTurnIsNotDramatised() {
        // A thing that simply happened: no disagreement, no precedent, no debt,
        // no pattern. It stays a ledger sentence, and that is correct.
        let incident = EmergentIncident(record: act())
        XCTAssertNil(EmergentTurnFinder.turn(for: incident))
        XCTAssertNil(EmergentSceneComposer.scene(for: incident))
    }

    func testAQuietRoomIsNotAPrecedent() {
        // One or two incidents is not a pattern. A room has to earn a character
        // before its history is worth telling.
        let incident = EmergentIncident(record: act(), place: room(argumentCount: 2))
        XCTAssertNil(EmergentSceneComposer.scene(for: incident))

        let earned = EmergentIncident(record: act(), place: room(argumentCount: 3))
        XCTAssertNotNil(EmergentSceneComposer.scene(for: earned))
    }

    func testTheOverwhelmingMajorityOfOrdinaryDaysProduceNothing() {
        // The filter has to actually bite, or "infinite" becomes "constant".
        // Genuinely ordinary: different people, different acts, none of them
        // repeating, in rooms with no history and with nothing owed.
        let kinds = CastAct.allCases
        let cast = ["penny-blackletter", "wicker-eddies", "serenity-brown",
                    "lydia-boggle", "orion-blackthorn", "zara-finch"]
        var ledger = CastActLedger.empty
        for index in 0..<kinds.count {
            ledger.record(act(
                id: "quiet-\(index)",
                kinds[index],
                actor: cast[index % cast.count],
                target: cast[(index + 1) % cast.count],
                at: days(Double(index % 20 + 1))
            ))
        }
        let scenes = EmergentIncidentAssembler.dramatisable(
            acts: ledger, places: [:], relationshipField: [:], now: now
        )
        XCTAssertTrue(scenes.isEmpty, "Nothing has happened twice, so nothing has a turn")
    }

    // MARK: - Every turn comes from the world

    func testTwoAccountsThatDisagreeAreATurn() {
        let incident = EmergentIncident(
            record: act(),
            accounts: [
                WorldAccount(id: "a", movementID: "m", kind: .filed,
                             line: "It was a correction.", contradictsSibling: true),
                WorldAccount(id: "b", movementID: "m", kind: .rumor,
                             line: "It was not a correction.", contradictsSibling: false)
            ]
        )
        guard case .contradiction = try? XCTUnwrap(EmergentTurnFinder.turn(for: incident)) else {
            return XCTFail("Disagreeing testimony is the purest turn the world makes")
        }
        let scene = EmergentSceneComposer.scene(for: incident)
        XCTAssertTrue(scene?.scene.contains("It was a correction.") == true)
        XCTAssertTrue(scene?.scene.contains("It was not a correction.") == true)
    }

    func testARepeatIsATurnAndCarriesTheLedgersOwnCallback() {
        var ledger = CastActLedger.empty
        ledger.record(act(id: "first", at: days(9)))
        ledger.record(act(id: "second", at: days(1)))

        let scenes = EmergentIncidentAssembler.dramatisable(
            acts: ledger, places: [:], relationshipField: [:], now: now
        )
        guard let scene = scenes.first(where: { $0.incidentID == "second" }) else {
            return XCTFail("The second time should know about the first")
        }
        guard case .reversal = scene.turn else {
            return XCTFail("Expected the ledger's own repeat callback")
        }
        XCTAssertTrue(scene.scene.contains("second time"))
    }

    func testAnOldUnansweredDebtSurfacesAsATurn() {
        var ledger = CastActLedger.empty
        ledger.record(act(id: "debt", .owe, at: days(40)))
        ledger.record(act(id: "now", .refuseToConcede, at: days(1)))

        let scenes = EmergentIncidentAssembler.dramatisable(
            acts: ledger, places: [:], relationshipField: [:], now: now
        )
        XCTAssertTrue(
            scenes.contains { if case .debt = $0.turn { return true } else { return false } },
            "The Academy does not forget a debt merely because the reader did"
        )
    }

    func testARoomThatHasBegunRefusingIsATurn() {
        let incident = EmergentIncident(
            record: act(),
            place: room(refusal: "has stopped carrying sound to the far end")
        )
        guard case .refusal = try? XCTUnwrap(EmergentTurnFinder.turn(for: incident)) else {
            return XCTFail("A room's refusal is world state and may carry a scene")
        }
    }

    func testTheStrongestAvailableTurnWins() {
        // A pattern beats a mood; a contradiction beats a pattern.
        let incident = EmergentIncident(
            record: act(),
            place: room(argumentCount: 4, refusal: "has stopped echoing"),
            accounts: [
                WorldAccount(id: "a", movementID: "m", kind: .filed,
                             line: "One telling.", contradictsSibling: true),
                WorldAccount(id: "b", movementID: "m", kind: .rumor,
                             line: "Another telling.", contradictsSibling: false)
            ],
            callback: "That is the second time."
        )
        guard case .contradiction = try? XCTUnwrap(EmergentTurnFinder.turn(for: incident)) else {
            return XCTFail("Expected the contradiction to outrank the rest")
        }
        XCTAssertEqual(EmergentTurnFinder.candidates(for: incident).count, 4)
    }

    // MARK: - What a scene may and may not do

    func testASceneNeverExplainsItself() {
        let tells = ["left behind:", "which is significant", "this matters",
                     "what this means", "symbolically", "little did", "in other words"]
        for scene in everyShape() {
            let text = scene.scene.lowercased()
            for tell in tells {
                XCTAssertFalse(text.contains(tell), "\(scene.incidentID) explains itself: '\(tell)'")
            }
        }
    }

    func testASceneNeverAssignsTheReaderAnything() {
        let forbidden = ["you should", "your task", "bring me", "go and", "can you", "your turn"]
        for scene in everyShape() {
            let text = (scene.scene + " " + scene.residue).lowercased()
            for phrase in forbidden {
                XCTAssertFalse(text.contains(phrase), "\(scene.incidentID) reads as an assignment")
            }
        }
    }

    func testEveryDramatisedIncidentLeavesSomethingBehind() {
        for scene in everyShape() {
            XCTAssertFalse(
                scene.residue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(scene.incidentID) leaves nothing another surface could notice"
            )
            XCTAssertFalse(scene.residue.lowercased().hasPrefix("left behind"))
        }
    }

    func testScenesStayCompressed() {
        for scene in everyShape() {
            let words = scene.scene.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertGreaterThan(words, 20, "\(scene.incidentID) is not a scene yet")
            XCTAssertLessThan(words, 250, "\(scene.incidentID) has outgrown a morsel")
        }
    }

    func testTheLedgerSentenceIsKeptWhole() {
        // Same three registers the authored beats use: the ledger keeps its
        // sentence exactly, so it can be quoted back rather than paraphrased.
        let incident = EmergentIncident(record: act(), place: room(argumentCount: 3))
        let scene = EmergentSceneComposer.scene(for: incident)
        XCTAssertEqual(scene?.line, "Penny corrected Wicker in front of everybody.")
    }

    func testASceneIsTraceableToTheStateThatJustifiedIt() {
        let incident = EmergentIncident(record: act(), place: room(argumentCount: 5))
        guard let scene = EmergentSceneComposer.scene(for: incident) else {
            return XCTFail("Expected a scene")
        }
        guard case let .precedent(placeID, _, count) = scene.turn else {
            return XCTFail("Expected a precedent turn")
        }
        XCTAssertEqual(placeID, "location-great-hall")
        XCTAssertEqual(count, 5)
        XCTAssertEqual(scene.placeID, "location-great-hall")
        XCTAssertTrue(scene.scene.contains("Great Hall"))
    }

    // MARK: - Determinism and variety

    func testTheSameIncidentAlwaysTellsTheSameStory() {
        let incident = EmergentIncident(record: act(), place: room(argumentCount: 3))
        XCTAssertEqual(
            EmergentSceneComposer.scene(for: incident),
            EmergentSceneComposer.scene(for: incident)
        )
    }

    func testDifferentIncidentsDoNotAllReadTheSameWay() {
        // The supply being infinite is worth nothing if it is infinite
        // repetition. Distinct incidents must produce distinct prose.
        var seen = Set<String>()
        for index in 0..<40 {
            let incident = EmergentIncident(
                record: act(id: "varied-\(index)", at: days(1)),
                place: room(argumentCount: 3),
                callback: "That is the second time."
            )
            if let scene = EmergentSceneComposer.scene(for: incident) {
                seen.insert(scene.scene)
            }
        }
        XCTAssertGreaterThan(seen.count, 6, "Forty incidents produced too few distinct tellings")
    }

    func testTheRelationshipChangesHowTheCollisionReads() {
        let record = act(id: "tied")
        let cold = EmergentIncident(
            record: record, place: room(argumentCount: 3),
            tie: RelationshipTie(warmth: 0, tension: 20, familiarity: 10)
        )
        let warm = EmergentIncident(
            record: record, place: room(argumentCount: 3),
            tie: RelationshipTie(warmth: 20, tension: 0, familiarity: 10)
        )
        XCTAssertNotEqual(
            EmergentSceneComposer.scene(for: cold)?.scene,
            EmergentSceneComposer.scene(for: warm)?.scene,
            "Two people who cannot stand each other should collide differently"
        )
    }

    func testEveryActFamilyCanBeTold() {
        for family in CastAct.Family.allCases {
            guard let kind = CastAct.allCases.first(where: { $0.family == family }) else {
                return XCTFail("No act in family \(family)")
            }
            let incident = EmergentIncident(
                record: act(id: "family-\(family.rawValue)", kind),
                place: room(argumentCount: 3)
            )
            let scene = EmergentSceneComposer.scene(for: incident)
            XCTAssertNotNil(scene, "\(family) cannot be dramatised")
            XCTAssertFalse(scene?.residue.isEmpty ?? true)
        }
    }

    // MARK: - Reaching the desk

    func testAuthoredBusinessAlwaysOutranksTheSimulation() {
        // The authored season is better written and should win while any of it
        // is left unmet. The simulation is the floor, not the default.
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = CastUndertakingEngine.seeded(existing: [], now: now)
        inputs.castActs = ledgerWithATurn()
        inputs.placeStates = ["location-great-hall": room(argumentCount: 4)]
        let day = BookDay(id: "2026-08-14", date: now, pages: [])

        for hour in stride(from: 0, to: 24 * 20, by: 4) {
            let probe = now.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["worldSeeded"] == "true" else { continue }
            XCTAssertNil(
                surface.payload.metadata[GossipSimulationBuilder.emergentIncidentKey],
                "An unmet authored beat was available and lost to the simulation"
            )
        }
    }

    func testTheSimulationCarriesTheDeskOnceTheSeasonIsRead() {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = []          // the authored season is exhausted
        inputs.castActs = ledgerWithATurn()
        inputs.placeStates = ["location-great-hall": room(argumentCount: 4)]
        let day = BookDay(id: "2026-08-14", date: now, pages: [])

        var sawOne = false
        for hour in stride(from: 0, to: 24 * 20, by: 4) {
            let probe = now.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata[GossipSimulationBuilder.emergentIncidentKey] != nil else {
                continue
            }
            sawOne = true
            XCTAssertEqual(surface.renderStyle, .witnessedScene)
            XCTAssertNotNil(surface.payload.metadata[GossipSimulationBuilder.emergentTurnKey])
            XCTAssertFalse(surface.payload.body.contains("Left behind"))
            // Same law as an authored beat: the world already spent this.
            XCTAssertNil(surface.payload.metadata["relationshipMoves"])
            XCTAssertNil(surface.payload.metadata["pageBeliefMoves"])
        }
        XCTAssertTrue(sawOne, "With the season read and the world busy, the desk should not go quiet")
    }

    func testAWorldWithNothingToSayStillSaysNothing() {
        // The floor is not a guarantee. An Academy that has genuinely done
        // nothing worth telling hands the desk back to the reader.
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = []
        inputs.castActs = .empty
        let day = BookDay(id: "2026-08-14", date: now, pages: [])

        for hour in stride(from: 0, to: 24 * 20, by: 4) {
            let probe = now.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            XCTAssertNil(surface.payload.metadata[GossipSimulationBuilder.emergentIncidentKey])
        }
    }

    // MARK: - Helpers

    private func ledgerWithATurn() -> CastActLedger {
        var ledger = CastActLedger.empty
        ledger.record(act(id: "first", at: days(9)))
        ledger.record(act(id: "second", at: days(1)))
        return ledger
    }

    /// One scene of every turn shape, for the editorial-law sweeps.
    private func everyShape() -> [EmergentScene] {
        let shapes: [EmergentIncident] = [
            EmergentIncident(
                record: act(id: "contradiction"),
                accounts: [
                    WorldAccount(id: "a", movementID: "m", kind: .filed,
                                 line: "One telling.", contradictsSibling: true),
                    WorldAccount(id: "b", movementID: "m", kind: .rumor,
                                 line: "Another telling.", contradictsSibling: false)
                ]
            ),
            EmergentIncident(record: act(id: "reversal"), callback: "That is the second time."),
            EmergentIncident(record: act(id: "debt"), obligation: "Something is still owed."),
            EmergentIncident(record: act(id: "precedent"), place: room(argumentCount: 4)),
            EmergentIncident(record: act(id: "refusal"), place: room(refusal: "has stopped echoing"))
        ]
        return shapes.compactMap(EmergentSceneComposer.scene)
    }
}
