import XCTest
@testable import InsideCoverCore

/// November 2026, The Guest Who Came on All Souls. The pack is authored in
/// `ContentPacks/the-guest/build_pack.py`; these hold it to the same contracts as
/// October before it can ship.
final class TheGuestPackTests: XCTestCase {
    private func pack() throws -> WorldEventPack {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/the-guest/november.reenchantedevents.json")))
    }

    private func event() throws -> WorldEvent { try XCTUnwrap(try pack().events.first) }

    // MARK: Release

    func testTheIssueValidatesForRelease() throws {
        let p = try pack()
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        let working = MonthlyIssueAuthoringValidator.validate(manifest, against: p, mode: .working)
        XCTAssertTrue(working.errors.isEmpty, "\(working)")
        let release = MonthlyIssueAuthoringValidator.validate(manifest, against: p, mode: .release)
        XCTAssertTrue(release.isValid, "\(release)")
        XCTAssertEqual(manifest.phasePlans.map(\.role), WorldEventPhaseRole.allCases)
        let event = try event()
        XCTAssertEqual(event.calendar.startMonth, 11)
        XCTAssertEqual(event.calendar.durationDays, 30)
        XCTAssertEqual(event.phases.map(\.startsAtProgress), event.phases.map(\.startsAtProgress).sorted())
    }

    func testEveryScenesRoutesAreWhole() throws {
        for scene in try pack().storyScenes ?? [] {
            XCTAssertEqual(AuthoredStoryProgress.diagnostics(for: scene), [], scene.id)
        }
    }

    // MARK: The Cast remember it

    func testTheMemoriesKeepTheContract() throws {
        let cast = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id))
        let problems = CastStoryMemoryAudit.problems(in: try pack(), knownEntityIDs: cast)
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }

    func testEveryoneInAScenesCastRemembersSomethingFromIt() throws {
        for scene in try pack().storyScenes ?? [] {
            var remembered = Set((scene.castMemories ?? []).map(\.entityID))
            for node in scene.nodes ?? [] {
                remembered.formUnion((node.castMemories ?? []).map(\.entityID))
                for choice in node.choices { remembered.formUnion((choice.castMemories ?? []).map(\.entityID)) }
            }
            for member in scene.castIDs ?? [] {
                XCTAssertTrue(remembered.contains(member), "\(member) was in \(scene.id) and remembers nothing")
            }
        }
    }

    /// The Offer names the November evening the Reader chose for Serenity in October, from
    /// her own memory, and has a version for a reader who wasn't there.
    func testTheOfferRemembersOctobersEvening() throws {
        let offer = try XCTUnwrap(try pack().storyScenes?.first { $0.id == "the-guest.scene.the-offer" })
        let entry = try XCTUnwrap(offer.nodes?.first)
        func memory(_ key: String) -> CastStoryMemory {
            CastStoryMemory(id: "count-unbound|\(key)|serenity-brown", entityID: "serenity-brown", key: key,
                            memory: "An evening in November.", witness: .withReader, storyTitle: "The Count Unbound",
                            momentTitle: "An evening in November", runID: "count-unbound:2026", sourceID: "test",
                            happenedAt: Date(), frozenAt: Date())
        }
        let roof = CastStoryRecall.render(entry.body, recalls: entry.recalls,
                                          ledger: CastStoryMemoryLedger(memories: [memory("count-unbound.november.knocking")]))
        XCTAssertTrue(roof.contains("The glass roof"))
        let table = CastStoryRecall.render(entry.body, recalls: entry.recalls,
                                           ledger: CastStoryMemoryLedger(memories: [memory("count-unbound.november.answer")]))
        XCTAssertTrue(table.contains("A pear tart"))
        let alone = CastStoryRecall.render(entry.body, recalls: entry.recalls, ledger: .empty)
        XCTAssertTrue(alone.contains("The evening you kept for yourself"))
        XCTAssertFalse(alone.contains("{october-evening}"))
    }

    /// December's first morning reads how November ended, and what Serenity chose, from what
    /// Ambrose and Serenity remember; a reader who missed both gets a version that gives
    /// nothing away.
    func testTheFirstOfDecemberRemembersTheEnding() throws {
        let scene = try XCTUnwrap(try pack().storyScenes?.first { $0.id == "the-guest.scene.the-first-of-december" })
        let nodes = try XCTUnwrap(scene.nodes)
        func ledger(_ entity: String, _ key: String) -> CastStoryMemoryLedger {
            CastStoryMemoryLedger(memories: [CastStoryMemory(
                id: "the-guest|\(key)|\(entity)", entityID: entity, key: key, memory: "November.",
                witness: .withReader, storyTitle: "The Guest Who Came on All Souls", momentTitle: "The Bowl",
                runID: "the-guest:2026", sourceID: "test", happenedAt: Date(), frozenAt: Date())])
        }
        func morning(_ key: String?) -> String {
            CastStoryRecall.render(nodes[0].body, recalls: nodes[0].recalls,
                                   ledger: key.map { ledger("ambrose-trencher", $0) } ?? .empty)
        }
        XCTAssertTrue(morning("the-guest.bowl.stayed").contains("The pots are done."))
        XCTAssertTrue(morning("the-guest.bowl.sent-home").contains("a brass button"))
        XCTAssertTrue(morning("the-guest.bowl.went-back").contains("a second sack"))
        let missed = morning(nil)
        XCTAssertTrue(missed.contains("the Kitchens' business"))
        for giveaway in ["home", "Court", "stayed", "pots are done"] {
            XCTAssertFalse(missed.contains(giveaway), giveaway)
        }
        XCTAssertFalse(missed.contains("{"))

        func breakfast(_ key: String?) -> String {
            CastStoryRecall.render(nodes[1].body, recalls: nodes[1].recalls,
                                   ledger: key.map { ledger("serenity-brown", $0) } ?? .empty)
        }
        XCTAssertTrue(breakfast("the-guest.offer.taken").contains("Tell me again"))
        XCTAssertTrue(breakfast("the-guest.offer.kept").contains("tastes of paper"))
        XCTAssertTrue(breakfast(nil).contains("she isn't saying"))
        XCTAssertEqual(nodes[1].choices.count, 3, "the Long Watch inherits one of three answers")
    }

    // MARK: The Story So Far

    func testTheLadderNeverLeadsTheRecord() throws {
        XCTAssertEqual(WorldEventCatchUpAudit.problems(in: try event()), [])
        let entries = try XCTUnwrap(try event().record?.entries)
        XCTAssertGreaterThanOrEqual(entries.count, 13)
    }

    func testTheLadderIsShortAndKeepsTheBooksVoice() throws {
        for rung in try XCTUnwrap(try event().catchUp) {
            XCTAssertLessThanOrEqual(rung.body.split(whereSeparator: \.isWhitespace).count, 165, rung.id)
            XCTAssertNotNil(rung.openQuestion?.nonEmpty, rung.id)
            let lower = (rung.title + " " + rung.body + " " + (rung.openQuestion ?? "")).lowercased()
            for word in ["triangle", "romance", "romantic", "love interest", "rival", "suitor", "crush", "in love",
                         "hinge", "ritual", "forgive"] {
                XCTAssertFalse(lower.contains(word), "\(rung.id) says \(word)")
            }
            XCTAssertNil(rung.body.range(of: #", which\b"#, options: .regularExpression), rung.id)
            XCTAssertNil(lower.range(of: #"\bnot\b[^.]{0,40}\bbut\b"#, options: .regularExpression), rung.id)
            for stiff in [" do not ", " cannot ", " it is ", " she is ", " he is ", " that is "] {
                XCTAssertFalse(lower.contains(stiff), "\(stiff) in \(rung.id)")
            }
            for hands in ["my hand", "i hold", "i pick", "i reach"] {
                XCTAssertFalse(lower.contains(hands), "the Book has no hands: \(rung.id)")
            }
        }
    }

    func testNoRungGivesAwayWhatHappensAfterIt() throws {
        let facts: [String: Int] = [
            "souling": 1, "green coat": 1, "the guest": 1, "scrubbed": 1,
            "treacle": 5, "momort": 5,
            "martinmas": 11, "paper": 11,
            "omelette": 14, "teaspoons": 14, "two hundred": 14,
            "three in the morning": 21, "an offer": 21,
            "stir-up": 22, "endpaper": 22, "a bowl for the one": 22,
            "whoever's missing": 26,
            "oats": 29, "thorn": 29, "white bowl": 29
        ]
        for rung in try XCTUnwrap(try event().catchUp) {
            for (fact, day) in facts where rung.fromDay < day {
                XCTAssertFalse(rung.body.lowercased().contains(fact),
                               "\(rung.id) (day \(rung.fromDay)) tells '\(fact)' before day \(day)")
            }
        }
    }

    // MARK: The map and the daily pulse

    func testTheMapOnlyPutsRealPeopleInRealRooms() throws {
        let cast = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id))
        let event = try event()
        let sets = event.phases.map { ($0.id, AcademyStagingSet(staging: $0.staging, closedRoomIDs: $0.closedRoomIDs,
                                                                   roomNotes: $0.roomNotes, borrowedRooms: $0.borrowedRooms)) }
            + [("foreshadow", event.foreshadowAcademy ?? AcademyStagingSet()), ("residue", event.residueAcademy ?? AcademyStagingSet())]
        for (label, set) in sets {
            let borrowed = Set((set.borrowedRooms ?? []).map(\.id))
            for staging in set.staging ?? [] {
                XCTAssertTrue(AcademyGeography.room(id: staging.roomID) != nil || borrowed.contains(staging.roomID),
                              "\(label): \(staging.roomID)")
                XCTAssertTrue(cast.contains(staging.castID) || staging.name?.nonEmpty != nil, "\(label): \(staging.castID)")
            }
            for note in set.roomNotes ?? [] {
                XCTAssertTrue(AcademyGeography.room(id: note.roomID) != nil, "\(label): \(note.roomID)")
            }
            for room in set.borrowedRooms ?? [] {
                XCTAssertTrue(room.joins.allSatisfy { AcademyGeography.room(id: $0.roomID) != nil }, room.id)
            }
        }
    }

    func testEveryPulseHasAQuietVersion() throws {
        let pulses = try event().phases.flatMap { $0.pulses ?? [] }
        XCTAssertGreaterThanOrEqual(pulses.count, 30)
        XCTAssertEqual(Set(pulses.map(\.id)).count, pulses.count)
        for pulse in pulses {
            XCTAssertNotNil(pulse.tender?.nonEmpty, pulse.id)
            XCTAssertFalse(pulse.text.lowercased().contains("hinge"), pulse.id)
        }
    }

    // MARK: The Bleed

    func testRecapsAreShortAndThirdPerson() throws {
        let recaps = try XCTUnwrap(try pack().bleedArticles).filter { $0.tags.contains("weekly-recap") }
        XCTAssertEqual(recaps.count, 4)
        for recap in recaps {
            XCTAssertLessThanOrEqual(recap.body.split(whereSeparator: \.isWhitespace).count, 150, recap.id)
            XCTAssertFalse(recap.body.lowercased().contains("you "), recap.id)
            XCTAssertEqual(recap.byline, "Penny Blackletter")
        }
    }

    func testDeskPiecesAreWellFormedAndNeverStandAlone() throws {
        let articles = try XCTUnwrap(try pack().bleedArticles)
        let manifestIDs = Set(try XCTUnwrap(try pack().authoringManifests?.first).content.map(\.id))
        let cues = Set(BleedDayDesk.LetterCue.allCases.map(\.rawValue))
        let pieces = articles.filter(\.isDeskPiece)
        XCTAssertGreaterThanOrEqual(pieces.filter { $0.tags.contains("classified") }.count, 10)
        XCTAssertGreaterThanOrEqual(pieces.filter { $0.tags.contains("cast-letter") }.count, 15)
        for piece in pieces {
            XCTAssertFalse(manifestIDs.contains(piece.id), "\(piece.id) would also print as its own article")
            XCTAssertNotNil(piece.tags.first { $0.hasPrefix("from-day:") }, piece.id)
            if piece.tags.contains("classified") {
                XCTAssertNotNil(piece.reply?.nonEmpty, piece.id)
            } else {
                let cue = piece.tags.first { $0.hasPrefix("cue:") }.map { String($0.dropFirst(4)) }
                XCTAssertTrue(cue.map(cues.contains) == true, piece.id)
                XCTAssertNotNil(piece.tags.first { $0.hasPrefix("cast:") }, piece.id)
                XCTAssertFalse(piece.byline.isEmpty, piece.id)
            }
        }
    }

    // MARK: The margins pack

    private func margins() throws -> PageArchetypePack {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(
            PageArchetypePack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/the-guest/margins.reenchantedpack.json")))
    }

    /// The Cast's own business while the Guest is in the house: five dramatised beats each,
    /// every beat in a real phase of the event, and the same laws as the core ladders.
    func testTheCastsBusinessIsWellFormed() throws {
        let ladders = try XCTUnwrap(try margins().undertakings)
        XCTAssertEqual(ladders.count, 3)
        let phases = Set(try event().phases.map(\.id))
        let cast = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id))
        let forbidden = ["you should", "your task", "try to", "can you", "help him", "help her", "we need you",
                         "bring me", "go and", "your turn", "find one", "fetch me", "for you to"]
        for ladder in ladders {
            XCTAssertEqual(ladder.eventID, "the-guest")
            XCTAssertEqual(ladder.stages.count, 5, ladder.id)
            XCTAssertTrue(cast.contains(ladder.actorID), ladder.actorID)
            XCTAssertTrue(ladder.stages.contains { $0.arrivesAs == .letter && $0.door != nil }, ladder.id)
            XCTAssertTrue(ladder.stages.contains { $0.arrivesAs == .witnessedScene }, ladder.id)
            for stage in ladder.stages {
                XCTAssertTrue(phases.contains(stage.phaseID ?? ""), "\(ladder.id)/\(stage.id)")
                XCTAssertNotNil(stage.scene, "\(ladder.id)/\(stage.id) is still a report")
                XCTAssertFalse(stage.trace.isEmpty)
                for member in stage.castIDs ?? [] { XCTAssertTrue(cast.contains(member), member) }
                let text = [stage.scene, stage.deniability, stage.line].compactMap { $0 }.joined(separator: " ").lowercased()
                for phrase in forbidden + CastStoryMemoryAudit.bannedWords {
                    XCTAssertFalse(text.contains(phrase), "\(ladder.id)/\(stage.id): '\(phrase)'")
                }
            }
        }
    }

    func testKitchenSpellsOnlyWakeWhileTheGuestIsHere() throws {
        let spells = try margins().archetypes
        XCTAssertEqual(spells.count, 4)
        for spell in spells {
            XCTAssertEqual(spell.trigger?.activeWorldEventIDs, ["the-guest"], spell.id)
            for band in spell.trigger?.timeBands ?? [] {
                XCTAssertTrue(["dawn", "day", "dusk", "night"].contains(band), "\(spell.id): \(band) never matches")
            }
            XCTAssertTrue(spell.bodyTemplate.contains("The rule:"), "\(spell.id) plays its rule straight")
            XCTAssertTrue(spell.bodyTemplate.contains("Write in the margin"), spell.id)
            for word in CastStoryMemoryAudit.bannedWords { XCTAssertFalse(spell.bodyTemplate.lowercased().contains(word)) }
        }
        let pencilings = try XCTUnwrap(try margins().marginaliaSnippets)
        XCTAssertGreaterThanOrEqual(pencilings.count, 12)
        XCTAssertTrue(pencilings.allSatisfy { $0.placementTrigger?.activeWorldEventIDs == ["the-guest"] })
    }
}
