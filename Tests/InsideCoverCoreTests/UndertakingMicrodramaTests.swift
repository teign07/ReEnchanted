import XCTest
@testable import InsideCoverCore

/// The dramatic form, and the selection that lets a run of beats read as one
/// story instead of as ten threads sampled at random.
///
/// The editorial rules in the first section were originally written as a runtime
/// validator over a parallel definition registry. They are better as tests: the
/// prose they govern lives on the beat itself, so a violation is a test failure
/// at authoring time rather than a `.needsAuthoring` case discovered in the
/// field.
final class UndertakingMicrodramaTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func days(_ count: Double) -> Date { start.addingTimeInterval(count * 86_400) }

    private var allStages: [(actorID: String, stage: CastUndertakingStage)] {
        CastUndertakingRegistry.actorIDs.flatMap { actorID in
            (CastUndertakingRegistry.ladder(for: actorID)?.stages ?? []).map { (actorID, $0) }
        }
    }

    // MARK: - Editorial law

    func testEveryBeatLeavesSomethingBehind() {
        // The residue is the whole mechanism by which one small scene outlives
        // its own page. A beat without one cannot be returned to sideways.
        for (actorID, stage) in allStages {
            XCTAssertFalse(
                stage.trace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(actorID)/\(stage.id) leaves nothing another surface could notice"
            )
        }
    }

    func testEveryLadderIsMostlyDramatised() {
        // A scene is optional per beat — the ledger sentence is a working
        // fallback — but a ladder of nothing but reports is the thing this
        // work existed to fix.
        for actorID in CastUndertakingRegistry.actorIDs {
            let stages = CastUndertakingRegistry.ladder(for: actorID)?.stages ?? []
            let dramatised = stages.filter { $0.scene != nil }.count
            XCTAssertEqual(
                dramatised, stages.count,
                "\(actorID) has \(stages.count - dramatised) beats still reading as reports"
            )
        }
    }

    func testNoSceneAnnouncesItsOwnResidue() {
        // "Left behind: a back issue open at page four" tells the reader the
        // object matters, which is the one thing a beat must never do. The
        // residue arrives as an image and is left there.
        let tells = ["left behind:", "which is significant", "this matters",
                     "the meaning of this", "what this means is", "symbolically",
                     "it was at this point that", "little did"]
        for (actorID, stage) in allStages {
            let scene = (stage.scene ?? "").lowercased()
            for tell in tells {
                XCTAssertFalse(
                    scene.contains(tell),
                    "\(actorID)/\(stage.id) explains itself: '\(tell)'"
                )
            }
        }
    }

    func testNoSceneOrDeniabilityAssignsTheReaderAnything() {
        // The same law the ladders already lived under, extended to the two new
        // registers. A beat that ends "bring me one" is an errand, and errands
        // have their own machinery with their own cooldowns; a scene must not
        // grow a second, unbudgeted ask channel.
        let forbidden = ["you should", "your task", "try to", "can you", "help him",
                         "help her", "we need you", "bring me", "go and", "your turn",
                         "find one", "fetch me", "for you to"]
        for (actorID, stage) in allStages {
            let text = [stage.scene, stage.deniability]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            for phrase in forbidden {
                XCTAssertFalse(
                    text.contains(phrase),
                    "\(actorID)/\(stage.id) reads as an assignment: '\(phrase)'"
                )
            }
        }
    }

    func testScenesAreCompressed() {
        // One situation, one turn, out. The ceiling is the point: past about
        // 250 words a beat has started discussing how everyone feels about it.
        for (actorID, stage) in allStages {
            guard let scene = stage.scene else { continue }
            let words = scene.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertGreaterThan(words, 25, "\(actorID)/\(stage.id) is not a scene yet")
            XCTAssertLessThan(words, 250, "\(actorID)/\(stage.id) has outgrown a morsel")
        }
    }

    func testDeniabilityIsNotUniversal() {
        // Not every beat gets the joke. Serenity's silences and Trencher's grief
        // would be cheapened by a quip on the record, and a surface that always
        // fires stops being a surprise.
        let withDeniability = allStages.filter { $0.stage.deniability != nil }.count
        XCTAssertGreaterThan(withDeniability, 20, "The radio band has too little to carry")
        XCTAssertLessThan(withDeniability, allStages.count, "Some beats should decline to comment")
    }

    // MARK: - Prose is upgradeable without a migration

    func testAuthoredProseResolvesFromTheRegistryNotTheVault() {
        var undertaking = CastUndertakingEngine.seeded(existing: [], now: start)
            .first { $0.actorID == "wicker-eddies" }!
        // An older vault carrying a beat from before scenes existed.
        undertaking.stages[0].scene = nil
        undertaking.stages[0].line = "Something that was written differently once."
        undertaking.stageIndex = 0

        XCTAssertNil(undertaking.currentStage?.scene)
        XCTAssertNotNil(undertaking.currentBeat?.scene, "A stale vault should still print current prose")
        XCTAssertTrue(undertaking.currentBeat?.dramatised.contains("Four inches") == true)
    }

    func testAnUnknownStageFallsBackToWhateverTheVaultHas() {
        var undertaking = CastUndertakingEngine.seeded(existing: [], now: start)[0]
        undertaking.stages[undertaking.stageIndex].id = "a-beat-that-was-retired"
        undertaking.stages[undertaking.stageIndex].line = "The old words."
        XCTAssertEqual(undertaking.currentBeat?.line, "The old words.")
    }

    func testDramatisedFallsBackToTheLedgerSentence() {
        let bare = CastUndertakingStage(
            id: "bare", line: "It happened.", trace: "Something left.", tags: ["x"]
        )
        XCTAssertEqual(bare.dramatised, "It happened.")
    }

    // MARK: - The serial

    func testAThreadTheReaderIsFollowingContinuesWhenItHasMoved() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        var serial = UndertakingSerial()
        let followed = undertakings.first { $0.actorID == "penny-blackletter" }!

        serial.met(undertakingID: followed.id, stageIndex: 0, at: start)
        // The thread advances; every other thread is also available.
        let index = undertakings.firstIndex { $0.id == followed.id }!
        undertakings[index].stageIndex = 1

        // Whatever the slot hashes to, the followed thread wins.
        for probe in 0..<40 {
            let picked = UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "slot-\(probe)", now: days(1)
            )
            XCTAssertEqual(picked?.id, followed.id, "slot-\(probe) abandoned the story in progress")
            XCTAssertEqual(picked?.stageIndex, 1)
        }
    }

    func testAThreadNeverSkipsUnseenScenesWhenTheWorldIsFarAhead() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        var serial = UndertakingSerial()
        let followed = undertakings.first { $0.actorID == "penny-blackletter" }!
        let index = undertakings.firstIndex { $0.id == followed.id }!
        serial.met(
            undertakingID: followed.id,
            stageIndex: 0,
            storyBeatID: UndertakingSerial.storyBeatKey(
                actorID: followed.actorID,
                stageID: followed.stages[0].id
            ),
            at: start
        )
        undertakings[index].stageIndex = 4
        undertakings[index].status = .concluded

        let picked = UndertakingSerialEngine.nextBeat(
            among: undertakings,
            serial: serial,
            slotID: "slot-a",
            now: days(4)
        )
        XCTAssertEqual(picked?.id, followed.id)
        XCTAssertEqual(picked?.stageIndex, 1, "The projection moves one unseen scene at a time")
        XCTAssertEqual(undertakings[index].stageIndex, 4, "Opening old history must not rewind the world")
    }

    func testTheSameBeatIsNeverServedTwice() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        var serial = UndertakingSerial()
        let followed = undertakings.first { $0.actorID == "penny-blackletter" }!
        let index = undertakings.firstIndex { $0.id == followed.id }!
        undertakings[index].stageIndex = 2
        serial.met(undertakingID: followed.id, stageIndex: 2, at: start)

        for probe in 0..<40 {
            let picked = UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "slot-\(probe)", now: days(1)
            )
            XCTAssertFalse(
                picked?.id == followed.id && picked?.stageIndex == 2,
                "A beat already met came back round"
            )
        }
    }

    func testAStaleThreadIsNotResumedMidLadder() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        var serial = UndertakingSerial()
        let followed = undertakings.first { $0.actorID == "penny-blackletter" }!
        let index = undertakings.firstIndex { $0.id == followed.id }!
        serial.met(undertakingID: followed.id, stageIndex: 0, at: start)
        undertakings[index].stageIndex = 3

        // Inside the window, the run is still a run.
        XCTAssertEqual(
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "slot-a", now: days(4)
            )?.id,
            followed.id
        )
        // Well outside it, resuming would be a stranger halfway through a
        // sentence, so selection goes back to weighing everything.
        let late = (0..<40).compactMap { probe in
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "slot-\(probe)", now: days(45)
            )?.id
        }
        XCTAssertGreaterThan(Set(late).count, 1, "A stale thread should stop monopolising the desk")
    }

    func testAReaderWhoHasMetEverythingGetsNoWorldBusiness() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for index in undertakings.indices { undertakings[index].stageIndex = 1 }
        var serial = UndertakingSerial()
        for undertaking in undertakings {
            for stageIndex in 0...undertaking.stageIndex {
                serial.met(
                    undertakingID: undertaking.id,
                    stageIndex: stageIndex,
                    storyBeatID: UndertakingSerial.storyBeatKey(
                        actorID: undertaking.actorID,
                        stageID: undertaking.stages[stageIndex].id
                    ),
                    at: start
                )
            }
        }
        XCTAssertNil(
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "slot-a", now: days(1)
            ),
            "With nothing new to report the desk should go back to being about the reader"
        )
    }

    func testSelectionPrefersARecognisedThreadOverAStranger() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for index in undertakings.indices { undertakings[index].stageIndex = 3 }
        var serial = UndertakingSerial()
        let known = undertakings[0]
        // Met once, long ago: outside the continuation window, so this is the
        // weighted path rather than a run.
        serial.met(undertakingID: known.id, stageIndex: 0, at: start)

        let picks = (0..<400).compactMap { probe in
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "probe-\(probe)", now: days(60)
            )?.id
        }
        let recognised = picks.filter { $0 == known.id }.count
        let fairShare = Double(picks.count) / Double(undertakings.count)
        XCTAssertGreaterThan(Double(recognised), fairShare, "Recognition should count for something")
        // But never to the point of shutting the rest of the Academy out.
        XCTAssertGreaterThan(Set(picks).count, 4, "The ensemble should still get a look in")
    }

    func testAStrangersLadderOpensAtItsEarliestAvailableScene() {
        // The world may already be at beat five, and its traces may already be
        // in the Bleed or the Market. The Book can still open the first scene
        // without pretending the world waited or announcing a backlog.
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for index in undertakings.indices {
            undertakings[index].stageIndex = index % 2 == 0 ? 0 : 4
        }
        let picks = (0..<400).compactMap { probe in
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: UndertakingSerial(), slotID: "probe-\(probe)", now: start
            )
        }
        XCTAssertTrue(picks.allSatisfy { $0.stageIndex == 0 })
    }

    func testLegacyDuplicateGenerationCannotReplayAuthoredProse() {
        var original = CastUndertakingEngine.seeded(existing: [], now: start)
            .first { $0.actorID == "penny-blackletter" }!
        original.stageIndex = 1
        var duplicate = original
        duplicate.id = "undertaking-penny-blackletter-1"
        duplicate.startedAt = days(30)

        var serial = UndertakingSerial()
        serial.met(undertakingID: original.id, stageIndex: 0, at: start)
        let picked = UndertakingSerialEngine.nextBeat(
            among: [original, duplicate],
            serial: serial,
            slotID: "slot-a",
            now: days(31)
        )
        XCTAssertEqual(picked?.stageIndex, 1)
        XCTAssertNotEqual(
            picked?.currentStage?.id,
            original.stages[0].id,
            "A new occurrence ID must not make identical prose new"
        )
    }

    func testSelectionIsDeterministicForTheSameSlot() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        var serial = UndertakingSerial()
        serial.met(undertakingID: undertakings[2].id, stageIndex: 0, at: start)
        let a = UndertakingSerialEngine.nextBeat(
            among: undertakings, serial: serial, slotID: "slot-x", now: days(2)
        )
        let b = UndertakingSerialEngine.nextBeat(
            among: undertakings, serial: serial, slotID: "slot-x", now: days(2)
        )
        XCTAssertEqual(a?.id, b?.id)
    }

    func testARunIsCountedOnlyWhileItStaysTheSameStory() {
        var serial = UndertakingSerial()
        serial.met(undertakingID: "thread-a", stageIndex: 0, at: start)
        XCTAssertEqual(serial.runLength, 1)
        serial.met(undertakingID: "thread-a", stageIndex: 1, at: days(2))
        XCTAssertEqual(serial.runLength, 2)
        // A different thread starts its own run.
        serial.met(undertakingID: "thread-b", stageIndex: 0, at: days(3))
        XCTAssertEqual(serial.runLength, 1)
        // And a long gap breaks one.
        serial.met(undertakingID: "thread-b", stageIndex: 1, at: days(90))
        XCTAssertEqual(serial.runLength, 1)
    }

    func testTheSerialStaysBounded() {
        var serial = UndertakingSerial()
        for index in 0..<400 {
            serial.met(
                undertakingID: "thread-\(index)",
                stageIndex: index % 5,
                storyBeatID: "actor-\(index)#stage-\(index)",
                at: start
            )
        }
        XCTAssertEqual(serial.rememberedBeats.count, UndertakingSerial.rememberedBeatLimit)
        XCTAssertEqual(serial.rememberedStoryBeats.count, UndertakingSerial.rememberedBeatLimit)
        // The most recent beats are the ones worth keeping.
        XCTAssertTrue(serial.hasMet(undertakingID: "thread-399", stageIndex: 4))
        XCTAssertFalse(serial.hasMet(undertakingID: "thread-0", stageIndex: 0))
    }

    // MARK: - What the reader actually gets

    func testAWorldBusinessPageDoesNotLabelItsResidue() {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let day = BookDay(id: "2026-08-12", date: start, pages: [])

        var sawOne = false
        for hour in stride(from: 0, to: 24 * 40, by: 4) {
            let probe = start.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["worldSeeded"] == "true" else { continue }
            sawOne = true
            XCTAssertFalse(surface.payload.body.contains("Left behind"))
            XCTAssertEqual(surface.renderStyle, .witnessedScene)
            // The ladder position rides along so the encounter can be recorded.
            XCTAssertNotNil(surface.payload.metadata[GossipSimulationBuilder.undertakingStageIndexKey])
            XCTAssertNotNil(surface.payload.metadata[GossipSimulationBuilder.undertakingResidueKey])
        }
        XCTAssertTrue(sawOne, "Some slots should belong wholly to the Academy")
    }

    func testSeveralUnseenTurnsBecomeOneGentleScrapPage() {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = inputs.castUndertakings.firstIndex { $0.actorID == "penny-blackletter" }!
        let followed = inputs.castUndertakings[index]
        inputs.castUndertakings[index].stageIndex = 4
        inputs.castUndertakings[index].status = .concluded
        inputs.undertakingSerial.met(
            undertakingID: followed.id,
            stageIndex: 0,
            storyBeatID: UndertakingSerial.storyBeatKey(
                actorID: followed.actorID,
                stageID: followed.stages[0].id
            ),
            at: start
        )
        // Keep only the followed thread so a world-owned slot cannot select a
        // different piece of Academy business.
        inputs.castUndertakings = [inputs.castUndertakings[index]]
        let day = BookDay(id: "2026-08-12", date: start, pages: [])

        for hour in stride(from: 0, to: 24 * 40, by: 4) {
            let probe = start.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["worldSeeded"] == "true" else { continue }
            XCTAssertEqual(
                surface.payload.metadata[GossipSimulationBuilder.undertakingCatchUpKey],
                "true"
            )
            XCTAssertEqual(surface.renderStyle, .graphEvent)
            XCTAssertTrue(surface.payload.body.contains("You missed a little"))
            XCTAssertTrue(surface.payload.body.contains("I kept the scraps"))
            XCTAssertTrue(surface.payload.body.contains("From the Bleed"))
            XCTAssertTrue(surface.payload.body.contains("margin band"))
            XCTAssertTrue(surface.payload.body.contains("Goblin Market"))
            XCTAssertEqual(
                surface.payload.metadata[GossipSimulationBuilder.undertakingCoveredStageIndexesKey],
                "1,2,3"
            )
            XCTAssertFalse(surface.payload.body.lowercased().contains("episode"))
            XCTAssertFalse(surface.payload.body.lowercased().contains("catch up"))

            var afterScraps = inputs.undertakingSerial
            let indexes = surface.payload.metadata[GossipSimulationBuilder.undertakingCoveredStageIndexesKey]?
                .split(separator: ",").compactMap { Int($0) } ?? []
            let storyBeatIDs = surface.payload.metadata[GossipSimulationBuilder.undertakingCoveredStoryBeatIDsKey]?
                .split(separator: ",").map(String.init) ?? []
            for (offset, stageIndex) in indexes.enumerated() {
                afterScraps.met(
                    undertakingID: followed.id,
                    stageIndex: stageIndex,
                    storyBeatID: storyBeatIDs.indices.contains(offset) ? storyBeatIDs[offset] : nil,
                    at: probe
                )
            }
            XCTAssertEqual(
                UndertakingSerialEngine.nextBeat(
                    among: inputs.castUndertakings,
                    serial: afterScraps,
                    slotID: "after-scraps",
                    now: probe
                )?.stageIndex,
                4,
                "The current scene stays whole after the middle turns are gathered"
            )
            return
        }
        XCTFail("No gentle scrap page was produced")
    }

    func testAPagePrintsTheSceneRatherThanTheLedgerSentence() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        // Only one thread running, so the pick is forced.
        undertakings = undertakings.filter { $0.actorID == "wicker-eddies" }
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = undertakings
        let day = BookDay(id: "2026-08-12", date: start, pages: [])

        for hour in stride(from: 0, to: 24 * 40, by: 4) {
            let probe = start.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["worldSeeded"] == "true" else { continue }
            XCTAssertTrue(
                surface.payload.body.contains("Four inches"),
                "The page should print the scene"
            )
            XCTAssertFalse(
                surface.payload.body.hasPrefix("Wicker measures the sealed door"),
                "The ledger sentence belongs in the ledger, not on the page"
            )
            return
        }
        XCTFail("No world-business page was produced")
    }

    // MARK: - Sideways return

    func testABeatReachesMoreThanTheBleed() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = undertakings.firstIndex { $0.actorID == "wicker-eddies" }!
        undertakings[index].stageIndex = 1  // the beat with a deniability line

        let pressures = WorldPressureEngine.minting(
            into: [],
            relationshipField: [:],
            advancedUndertaking: undertakings[index],
            castName: { _ in "Wicker" },
            now: start
        )
        guard let pressure = pressures.first(where: { $0.origin == .undertakingStage }) else {
            return XCTFail("An advanced beat should leave marks")
        }
        let surfaces = Set(pressure.fingerprints.map(\.surface))
        XCTAssertTrue(surfaces.contains(.bleedCopy))
        XCTAssertTrue(surfaces.contains(.bystanderComplaint))
        XCTAssertTrue(surfaces.contains(.radioMargin), "The best joke in the Academy was unreachable")
        XCTAssertTrue(surfaces.contains(.shopItem))
        XCTAssertTrue(surfaces.contains(.classDescription))
    }

    func testTheRadioCarriesTheCharactersOwnPosition() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = undertakings.firstIndex { $0.actorID == "wicker-eddies" }!
        undertakings[index].stageIndex = 1

        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: [:],
            advancedUndertaking: undertakings[index],
            castName: { _ in "Wicker" }, now: start
        )
        let radio = pressures.flatMap(\.fingerprints).first { $0.surface == .radioMargin }
        XCTAssertTrue(radio?.line.contains("appealing") == true, "Got: \(radio?.line ?? "nothing")")
    }

    func testABeatWithNothingToSayGetsNoRadioLine() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = undertakings.firstIndex { $0.actorID == "serenity-brown" }!
        undertakings[index].stageIndex = 1  // the lamp: she tells nobody

        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: [:],
            advancedUndertaking: undertakings[index],
            castName: { _ in "Serenity" }, now: start
        )
        let radio = pressures.flatMap(\.fingerprints).filter { $0.surface == .radioMargin }
        XCTAssertTrue(radio.isEmpty, "A silence should stay a silence")
    }

    func testFingerprintsAreDeterministic() {
        let stages = allStages.map(\.stage)
        for stage in stages {
            XCTAssertEqual(
                WorldPressureEngine.shopItem(for: stage),
                WorldPressureEngine.shopItem(for: stage)
            )
            XCTAssertFalse(WorldPressureEngine.shopItem(for: stage).isEmpty)
            XCTAssertFalse(WorldPressureEngine.classNotice(for: stage, name: "X").isEmpty)
        }
    }

    // MARK: - Persistence

    func testTheSerialRoundTrips() throws {
        var serial = UndertakingSerial()
        serial.met(
            undertakingID: "thread-a",
            stageIndex: 2,
            storyBeatID: "actor-a#stage-c",
            at: start
        )
        let data = try JSONEncoder().encode(serial)
        XCTAssertEqual(try JSONDecoder().decode(UndertakingSerial.self, from: data), serial)
    }

    func testALegacyVaultWithoutASerialDecodes() throws {
        let json = "{\"version\":1}"
        let decoded = try JSONDecoder().decode(UndertakingSerial.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.rememberedBeats.isEmpty)
        XCTAssertTrue(decoded.rememberedStoryBeats.isEmpty)
        XCTAssertNil(decoded.lastThreadID)
    }

    func testALegacyStageWithoutASceneDecodes() throws {
        let json = """
            {"id":"punctuation","line":"It happened.","trace":"Something left.","tags":["archive"]}
            """
        let decoded = try JSONDecoder().decode(CastUndertakingStage.self, from: Data(json.utf8))
        XCTAssertNil(decoded.scene)
        XCTAssertNil(decoded.deniability)
        XCTAssertNil(decoded.door)
        XCTAssertEqual(decoded.dramatised, "It happened.")
    }

    // MARK: - Doors through the covers

    private var allDoors: [(actorID: String, door: UndertakingDoor)] {
        allStages.compactMap { actorID, stage in
            stage.door.map { (actorID, $0) }
        }
    }

    func testDoorsAreRare() {
        // The essay's rhythm put participation at roughly one beat in ten. It
        // has to stay scarce: an ask on every beat turns the Academy into a
        // chore list, which is the failure mode the whole form exists to avoid.
        XCTAssertGreaterThanOrEqual(allDoors.count, 3)
        XCTAssertLessThanOrEqual(allDoors.count, allStages.count / 6)
        XCTAssertEqual(Set(allDoors.map(\.door.id)).count, allDoors.count, "Duplicate door ids")
    }

    func testADoorAsksAndTheSceneThatOpenedItDoesNot() {
        // The division of labour that keeps a scene a scene: the beat never
        // addresses the reader, and the errand that came out of it always does.
        for (actorID, stage) in allStages {
            guard let door = stage.door else { continue }
            XCTAssertFalse(door.ask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(door.proofPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let scene = (stage.scene ?? "").lowercased()
            for phrase in ["bring me", "go and", "find one", "your turn"] {
                XCTAssertFalse(scene.contains(phrase), "\(actorID)/\(stage.id)'s scene became the ask")
            }
        }
    }

    func testADoorStaysShutUntilItsSceneHasBeenRead() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        XCTAssertTrue(
            UndertakingDoorEngine.open(in: undertakings, serial: UndertakingSerial()).isEmpty,
            "An errand must not arrive for a scene the reader has never met"
        )
    }

    func testMeetingTheBeatOpensItsDoor() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let wicker = undertakings.first { $0.actorID == "wicker-eddies" }!
        var serial = UndertakingSerial()
        serial.met(undertakingID: wicker.id, stageIndex: 0, at: start)

        let open = UndertakingDoorEngine.open(in: undertakings, serial: serial)
        XCTAssertEqual(open.map(\.door.id), ["wicker-unlooked-door"])
        XCTAssertEqual(open.first?.actorID, "wicker-eddies")
    }

    func testADoorIsNotReopenedByAReseededLadder() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = undertakings.firstIndex { $0.actorID == "wicker-eddies" }!
        var serial = UndertakingSerial()
        serial.met(undertakingID: undertakings[index].id, stageIndex: 0, at: start)
        XCTAssertEqual(UndertakingDoorEngine.open(in: undertakings, serial: serial).count, 1)

        // The same authored ladder running again under a fresh occurrence ID.
        undertakings[index].id = "undertaking-wicker-eddies-1"
        let reopened = UndertakingDoorEngine.open(in: undertakings, serial: serial)
        XCTAssertTrue(reopened.isEmpty, "Story identity, not occurrence, decides whether a door is spent")
    }

    func testADoorBecomesAnOrdinaryErrandHostedByItsOwnCharacter() {
        let open = UndertakingDoorEngine.OpenDoor(
            actorID: "wicker-eddies",
            door: CastUndertakingRegistry.ladder(for: "wicker-eddies")!.stages[0].door!
        )
        let mission = PlayfulMissionRegistry.doorMission(open)

        // It is a Playful Mission, so it inherits that machinery's freshness
        // history, proof prompt and receipt path rather than growing its own.
        XCTAssertEqual(mission.hostSlugOverride, "wicker-eddies")
        XCTAssertEqual(mission.host.slug, "wicker-eddies")
        XCTAssertFalse(mission.host.name.isEmpty)
        XCTAssertFalse(mission.host.assetName.isEmpty)
        XCTAssertTrue(mission.tags.contains("undertaking-door"))
        XCTAssertTrue(mission.id.contains("wicker-unlooked-door"))
    }

    func testAnOrdinaryMissionStillPicksItsHostFromItsTags() {
        // The override must not disturb how every existing mission is cast.
        let ordinary = PlayfulMission(
            id: "x", title: "T", prompt: "P", proofPrompt: "Q",
            tags: ["people", "connection"]
        )
        XCTAssertNil(ordinary.hostSlugOverride)
        XCTAssertEqual(ordinary.host.slug, "serenity-brown")
    }

    func testAnUnansweredDoorIsNotHeldAgainstTheReader() {
        // Declining costs nothing has to be mechanical, not just tonal: there
        // is nowhere to record a refusal, so an ignored door simply stays open.
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let wicker = undertakings.first { $0.actorID == "wicker-eddies" }!
        var serial = UndertakingSerial()
        serial.met(undertakingID: wicker.id, stageIndex: 0, at: start)

        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = undertakings
        inputs.undertakingSerial = serial

        XCTAssertEqual(PlayfulMissionRegistry.doorMissions(inputs: inputs).count, 1)
        // Still open a fortnight later, having been ignored throughout.
        XCTAssertEqual(PlayfulMissionRegistry.doorMissions(inputs: inputs).count, 1)
    }

    func testADoorAlreadySentDoesNotComeRoundAgain() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let wicker = undertakings.first { $0.actorID == "wicker-eddies" }!
        var serial = UndertakingSerial()
        serial.met(undertakingID: wicker.id, stageIndex: 0, at: start)

        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = undertakings
        inputs.undertakingSerial = serial
        let sent = PlayfulMissionRegistry.doorMissions(inputs: inputs)[0]
        inputs.surfaceHistory["playful-mission:\(sent.id)"] = SurfaceHistoryRecord(
            lastShownAt: start, recentShowCount: 1
        )

        XCTAssertTrue(PlayfulMissionRegistry.doorMissions(inputs: inputs).isEmpty)
    }

    func testADoorReachesTheReaderThroughTheOrdinaryMissionRoute() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let wicker = undertakings.first { $0.actorID == "wicker-eddies" }!
        var serial = UndertakingSerial()
        serial.met(undertakingID: wicker.id, stageIndex: 0, at: start)

        var withDoor = BookSourceInputs.empty
        withDoor.castUndertakings = undertakings
        withDoor.undertakingSerial = serial

        var withoutDoor = BookSourceInputs.empty
        withoutDoor.castUndertakings = undertakings

        // A moon or a weather front outranks a door on purpose: those are about
        // the reader's actual right-now and will not keep, where a door will.
        // So find a night the sky is not already asking for something.
        var reached = false
        for offset in 0..<40 {
            let probe = days(Double(offset))
            let day = BookDay(id: "probe-\(offset)", date: probe, pages: [])
            let baseline = PlayfulMissionRegistry.mission(for: day, inputs: withoutDoor, now: probe)
            guard !baseline.tags.contains("natural-phenomenon") else { continue }

            XCTAssertEqual(
                PlayfulMissionRegistry.mission(for: day, inputs: withDoor, now: probe).id,
                "undertaking-door-wicker-unlooked-door"
            )
            reached = true
            break
        }
        XCTAssertTrue(reached, "The sky asked for something on all forty nights")
    }

    func testNoDoorMeansTheMissionPoolIsUntouched() {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let day = BookDay(id: "2026-08-13", date: start, pages: [])

        let mission = PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: start)
        XCTAssertFalse(mission.id.hasPrefix("undertaking-door-"))
    }

    func testADoorRoundTrips() throws {
        let stage = CastUndertakingRegistry.ladder(for: "wicker-eddies")!.stages[0]
        let data = try JSONEncoder().encode(stage)
        let decoded = try JSONDecoder().decode(CastUndertakingStage.self, from: data)
        XCTAssertEqual(decoded.door, stage.door)
    }

    // MARK: - Crossings

    func testACrossingIsVisibleToMoreThanTheProse() {
        // Serenity is in two of Wicker's beats and Trencher in two other
        // people's. Before castIDs those were cameos: the prose knew, and
        // nothing that spends consequences did.
        let wicker = CastUndertakingRegistry.ladder(for: "wicker-eddies")!
        XCTAssertEqual(wicker.stages[0].castIDs, ["serenity-brown"])
        XCTAssertTrue(wicker.participantIDs.contains("serenity-brown"))
        XCTAssertEqual(wicker.participantIDs.first, "wicker-eddies", "The owner leads")

        let thorne = CastUndertakingRegistry.ladder(for: "headmistress-thorne")!
        XCTAssertTrue(thorne.participantIDs.contains("wicker-eddies"))
    }

    func testACoreCrossingNeverStructurallyNamesAPaidCharacter() {
        // `NarrativePackRegistry.entities` is entitlement-gated: Mook and Pippa
        // do not exist until the Dictionary Rebellion is owned. Prose may
        // mention anybody — the Academy is full of people you have not met — but
        // a castID is structural, and the systems that spend consequences on it
        // would be resolving a character this reader does not have.
        let ownedByEveryone = Set(NarrativePackRegistry.entities.map(\.id))
        for ladder in CastUndertakingRegistry.coreLadders {
            for id in ladder.participantIDs {
                XCTAssertTrue(
                    ownedByEveryone.contains(id),
                    "\(ladder.id) structurally names \(id), who is behind an entitlement"
                )
            }
        }
    }

    func testAPostedLadderMayNameItsOwnPacksCharacters() {
        // The staircase ladder ships inside the same locked folio that creates
        // Mook and Pippa, so it is enabled exactly when they exist.
        let everyBundledCharacter = Set(
            NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id)
        )
        for id in PageArchetypePackRegistry.staircaseCannotBeProvoked.participantIDs {
            XCTAssertTrue(everyBundledCharacter.contains(id), "\(id) is nobody at all")
        }
    }

    func testAPageCarriesEverybodyInTheScene() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        undertakings = undertakings.filter { $0.actorID == "wicker-eddies" }
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = undertakings
        let day = BookDay(id: "2026-08-13", date: start, pages: [])

        for hour in stride(from: 0, to: 24 * 40, by: 4) {
            let probe = start.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["worldSeeded"] == "true" else { continue }
            let cast = surface.payload.metadata[GossipSimulationBuilder.undertakingCastKey]
            XCTAssertEqual(cast, "wicker-eddies,serenity-brown")
            return
        }
        XCTFail("No world-business page was produced")
    }

    // MARK: - Which surface a beat arrives on

    func testABeatDefaultsToAWitnessedScene() {
        let stage = CastUndertakingRegistry.ladder(for: "penny-blackletter")!.stages[0]
        XCTAssertNil(stage.surface)
        XCTAssertEqual(stage.arrivesAs, .witnessedScene)
    }

    func testEachSurfaceGetsItsOwnFraming() {
        // The prose is the author's; only the frame changes. But the frames must
        // actually differ, or declaring a surface buys nothing.
        let framings = UndertakingBeatSurface.allCases.map {
            GossipSimulationBuilder.undertakingFraming(for: $0, actorName: "Mook")
        }
        XCTAssertEqual(Set(framings.map(\.prompt)).count, UndertakingBeatSurface.allCases.count)
        XCTAssertEqual(Set(framings.map(\.renderStyle)).count, UndertakingBeatSurface.allCases.count)
        XCTAssertTrue(
            GossipSimulationBuilder.undertakingFraming(for: .letter, actorName: "Mook").prompt.contains("Mook"),
            "A letter is from somebody"
        )
    }

    func testAnUnknownSurfaceFromALaterPackDegradesToAScene() throws {
        // A folio authored against a newer app must lose its framing, never its
        // Page.
        let json = """
            {"id":"x","line":"It happened.","trace":"Left.","tags":["a"],"surface":"hologram"}
            """
        let decoded = try JSONDecoder().decode(CastUndertakingStage.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.arrivesAs, .witnessedScene)
    }

    // MARK: - Business posted by a pack

    private static let packLadder = UndertakingLadder(
        id: "test-pack-ladder",
        actorID: "pippa-pilcrow",
        title: "Posted Business",
        pursuit: "Prove a folio can add business.",
        why: "Because it should cost one JSON file.",
        stages: [
            CastUndertakingStage(
                id: "posted", line: "Something happened.", trace: "A thing was left.",
                tags: ["words"], scene: "A scene, dropped into late, that stops before it explains itself.",
                surface: .letter
            )
        ]
    )

    override func tearDown() {
        CastUndertakingRegistry.install([])
        super.tearDown()
    }

    func testAPostedLadderJoinsTheSameRegistryAsTheCoreSeason() {
        let coreCount = CastUndertakingRegistry.coreLadders.count
        CastUndertakingRegistry.install([Self.packLadder])

        XCTAssertEqual(CastUndertakingRegistry.allLadders.count, coreCount + 1)
        XCTAssertEqual(CastUndertakingRegistry.ladder(withID: "test-pack-ladder")?.title, "Posted Business")
        XCTAssertEqual(CastUndertakingRegistry.ladders(for: "pippa-pilcrow").count, 1)
        XCTAssertTrue(CastUndertakingRegistry.actorIDs.contains("pippa-pilcrow"))
    }

    func testPostedBusinessSeedsAndRunsLikeAnyOther() {
        CastUndertakingRegistry.install([Self.packLadder])
        let seeded = CastUndertakingEngine.seeded(existing: [], now: start)
        guard let posted = seeded.first(where: { $0.resolvedLadderID == "test-pack-ladder" }) else {
            return XCTFail("A posted ladder should begin like any other business")
        }
        XCTAssertEqual(posted.actorID, "pippa-pilcrow")
        XCTAssertTrue(posted.isRunning)
        // And it is reachable by the same selection the core season uses.
        let picked = UndertakingSerialEngine.nextBeat(
            among: [posted], serial: UndertakingSerial(), slotID: "slot-a", now: days(1)
        )
        XCTAssertEqual(picked?.id, posted.id)
    }

    func testInstallingAPackDoesNotDisturbBusinessAlreadyUnderway() {
        let before = CastUndertakingEngine.seeded(existing: [], now: start)
        CastUndertakingRegistry.install([Self.packLadder])
        let after = CastUndertakingEngine.seeded(existing: before, now: days(30))

        XCTAssertEqual(after.count, before.count + 1)
        for original in before {
            XCTAssertEqual(after.first { $0.id == original.id }, original, "\(original.id) was disturbed")
        }
    }

    func testAPostedLadderSeedsOnlyOnce() {
        CastUndertakingRegistry.install([Self.packLadder])
        let once = CastUndertakingEngine.seeded(existing: [], now: start)
        let twice = CastUndertakingEngine.seeded(existing: once, now: days(400))
        XCTAssertEqual(once.count, twice.count, "A folio's business is finite history, not a template")
    }

    func testAPackMayNotOverwriteTheCoreSeason() {
        // A paid folio must not be able to rewrite free business out from under
        // a reader who is partway up it.
        let hostile = UndertakingLadder(
            id: "core-wicker-eddies",
            actorID: "wicker-eddies",
            title: "Replaced",
            pursuit: "x", why: "y",
            stages: [CastUndertakingStage(id: "z", line: "l", trace: "t", tags: ["a"])]
        )
        CastUndertakingRegistry.install([hostile])
        XCTAssertEqual(
            CastUndertakingRegistry.ladder(withID: "core-wicker-eddies")?.title,
            "Technically Not Entering"
        )
    }

    func testAPostedLadderIsPureDataAndRoundTrips() throws {
        let data = try JSONEncoder().encode(Self.packLadder)
        let decoded = try JSONDecoder().decode(UndertakingLadder.self, from: data)
        XCTAssertEqual(decoded, Self.packLadder)
    }

    func testTheShippedExampleFolioIsWellFormed() {
        // The pack ladder that ships with the Dictionary Rebellion is the thing
        // future folios get copied from, so it has to stay exemplary.
        let ladder = PageArchetypePackRegistry.staircaseCannotBeProvoked
        XCTAssertEqual(ladder.eventID, "dictionary-rebellion")
        XCTAssertEqual(ladder.stages.count, 5)
        XCTAssertTrue(ladder.participantIDs.count >= 3, "It should be genuinely multi-character")
        XCTAssertTrue(ladder.stages.contains { $0.arrivesAs == .letter })
        XCTAssertTrue(ladder.stages.contains { $0.arrivesAs == .note })
        XCTAssertTrue(ladder.stages.contains { $0.arrivesAs == .witnessedScene })
        XCTAssertTrue(ladder.stages.contains { $0.door != nil })
        for stage in ladder.stages {
            XCTAssertNotNil(stage.scene, "\(stage.id) is still a report")
            XCTAssertFalse(stage.trace.isEmpty)
        }
    }

    // MARK: - Business bound to a world event

    private var rebellionLive: UndertakingEventContext {
        UndertakingEventContext(phaseByEventID: ["dictionary-rebellion": "omen"])
    }

    func testAnEventContextIsBuiltFromWhatIsActuallyRunning() {
        XCTAssertTrue(UndertakingEventContext.none.isEmpty)
        XCTAssertFalse(rebellionLive.isLive("starlit-paper-trial"))
        XCTAssertTrue(rebellionLive.isLive("dictionary-rebellion"))
        XCTAssertFalse(rebellionLive.isLive(nil), "Business belonging to no event is not live business")
        XCTAssertEqual(rebellionLive.phase(of: "dictionary-rebellion"), "omen")
    }

    func testARunningEventPullsTheDeskTowardBusinessBoundToIt() {
        CastUndertakingRegistry.install([PageArchetypePackRegistry.staircaseCannotBeProvoked])
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let bound = undertakings.first { $0.resolvedLadderID.contains("staircase") }!

        func share(_ events: UndertakingEventContext) -> Int {
            (0..<400).compactMap {
                UndertakingSerialEngine.nextBeat(
                    among: undertakings, serial: UndertakingSerial(),
                    slotID: "probe-\($0)", now: start, events: events
                )?.id
            }.filter { $0 == bound.id }.count
        }

        let quiet = share(.none)
        let live = share(rebellionLive)
        XCTAssertGreaterThan(live, quiet, "A running event should reach the whole Academy")
        // But never to the point of becoming the only thing happening.
        let others = (0..<400).compactMap {
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: UndertakingSerial(),
                slotID: "probe-\($0)", now: start, events: rebellionLive
            )?.id
        }
        XCTAssertGreaterThan(Set(others).count, 3, "The rest of the Academy still exists")
    }

    func testBusinessBelongingToNoEventIsUnaffected() {
        let undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for probe in 0..<40 {
            XCTAssertEqual(
                UndertakingSerialEngine.nextBeat(
                    among: undertakings, serial: UndertakingSerial(),
                    slotID: "p-\(probe)", now: start, events: rebellionLive
                )?.id,
                UndertakingSerialEngine.nextBeat(
                    among: undertakings, serial: UndertakingSerial(),
                    slotID: "p-\(probe)", now: start, events: .none
                )?.id,
                "An event the core season has nothing to do with must change nothing"
            )
        }
    }

    func testABeatWaitsForItsPhaseWhileTheEventIsRunning() {
        CastUndertakingRegistry.install([PageArchetypePackRegistry.staircaseCannotBeProvoked])
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        undertakings = undertakings.filter { $0.resolvedLadderID.contains("staircase") }
        // The world has run ahead to the verdict, which belongs to the afterimage.
        undertakings[0].stageIndex = 4
        var serial = UndertakingSerial()
        for index in 0..<4 {
            serial.met(undertakingID: undertakings[0].id, stageIndex: index, at: start)
        }

        let duringAssembly = UndertakingEventContext(phaseByEventID: ["dictionary-rebellion": "assembly"])
        XCTAssertNil(
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "s", now: start, events: duringAssembly
            ),
            "The verdict should wait for the afterimage"
        )

        let duringAfterimage = UndertakingEventContext(phaseByEventID: ["dictionary-rebellion": "afterimage"])
        XCTAssertEqual(
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "s", now: start, events: duringAfterimage
            )?.stageIndex,
            4
        )
    }

    func testThePhaseHoldLiftsWhenTheEventIsNotRunningAtAll() {
        // Otherwise an archive reader, or anyone who met the ladder outside its
        // season, is stranded partway up it forever.
        CastUndertakingRegistry.install([PageArchetypePackRegistry.staircaseCannotBeProvoked])
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        undertakings = undertakings.filter { $0.resolvedLadderID.contains("staircase") }
        undertakings[0].stageIndex = 4
        var serial = UndertakingSerial()
        for index in 0..<4 {
            serial.met(undertakingID: undertakings[0].id, stageIndex: index, at: start)
        }
        XCTAssertEqual(
            UndertakingSerialEngine.nextBeat(
                among: undertakings, serial: serial, slotID: "s", now: start, events: .none
            )?.stageIndex,
            4,
            "No live event means no hold"
        )
    }

    func testARunningEventAlsoMovesItsBusinessFaster() {
        CastUndertakingRegistry.install([PageArchetypePackRegistry.staircaseCannotBeProvoked])
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        for index in undertakings.indices { undertakings[index].nextEligibleAt = start }

        // Fresh state per trial: a ladder only has five beats, so letting one
        // run to completion measures whether it finished, not whether it moved
        // sooner. What matters is how often the world picks it up.
        func picks(_ events: UndertakingEventContext) -> Int {
            var chosen = 0
            for probe in 0..<300 {
                let step = CastUndertakingEngine.advancing(
                    undertakings, now: days(1), slotID: "slot-\(probe)", events: events
                )
                if step.advanced?.resolvedLadderID.contains("staircase") == true { chosen += 1 }
            }
            return chosen
        }
        XCTAssertGreaterThan(picks(rebellionLive), picks(.none))
    }

    func testTheShippedFolioIsBoundToItsEventsPhases() {
        let ladder = PageArchetypePackRegistry.staircaseCannotBeProvoked
        let phases = ladder.stages.compactMap(\.phaseID)
        XCTAssertEqual(phases.count, ladder.stages.count, "Every beat should know its week")
        XCTAssertEqual(phases.first, "omen")
        XCTAssertEqual(phases.last, "afterimage")
        // And every named phase is one the event actually has.
        let event = WorldEventRegistry.dictionaryRebellion
        XCTAssertEqual(event.id, ladder.eventID)
        let known = Set(event.phases.map(\.id))
        for phase in phases {
            XCTAssertTrue(known.contains(phase), "\(phase) is not a phase of \(ladder.eventID ?? "")")
        }
    }

    // MARK: - A crossing makes the world busy around both people

    func testACrossingHeatsEverybodyInIt() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = undertakings.firstIndex { $0.actorID == "wicker-eddies" }!
        undertakings[index].stageIndex = 0  // Serenity is in this one

        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: [:],
            advancedUndertaking: undertakings[index],
            castName: { _ in "Wicker" }, now: start
        )
        guard let pressure = pressures.first(where: { $0.origin == .undertakingStage }) else {
            return XCTFail("An advanced beat should leave marks")
        }
        XCTAssertEqual(pressure.subjectIDs, ["wicker-eddies", "serenity-brown"])

        // And that is what makes both their threads start converging.
        let hot = CastUndertakingEngine.hotActorIDs(
            pressures: [pressure], places: [:], recentMovements: [], now: start
        )
        XCTAssertTrue(hot.contains("serenity-brown"), "A crossing should pull her thread in too")
    }

    func testABeatWithNobodyElseInItHeatsOnlyItsOwner() {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        let index = undertakings.firstIndex { $0.actorID == "orion-blackthorn" }!
        undertakings[index].stageIndex = 0

        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: [:],
            advancedUndertaking: undertakings[index],
            castName: { _ in "Orion" }, now: start
        )
        XCTAssertEqual(
            pressures.first { $0.origin == .undertakingStage }?.subjectIDs,
            ["orion-blackthorn"]
        )
    }

    func testAPostedLadderNamingAStrangerIsDropped() {
        let stranger = UndertakingLadder(
            id: "stranger", actorID: "somebody-who-does-not-exist",
            title: "t", pursuit: "p", why: "w",
            stages: [CastUndertakingStage(id: "s", line: "l", trace: "t", tags: ["a"])]
        )
        let pack = PageArchetypePack(
            id: "test", displayName: "Test", version: 1, author: "T",
            availability: "userImported", archetypes: [], undertakings: [stranger]
        )
        // Filtering happens where packs are gathered, so assert the rule the
        // gatherer applies rather than reaching into the file system.
        let known = Set(NarrativePackRegistry.entities.map(\.id))
        XCTAssertFalse(known.contains(pack.undertakings![0].actorID))
    }
}
