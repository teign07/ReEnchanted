import XCTest
@testable import InsideCoverCore

/// The month's story happens to the Cast, and they remember it: what the
/// reader was there for, what they only heard about once it was public, and
/// all of it after the month's pack has gone.
final class CastStoryMemoryTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func pack() throws -> WorldEventPack {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json"))
        )
    }

    private let issueID = "count-unbound-october-2026"
    private let runID = "count-unbound:2026"

    private func node(_ contentID: String, _ nodeID: String, choice: String? = nil, at moment: Date) -> AuthoredContentReceipt {
        AuthoredContentReceipt(
            contentID: contentID, occurrenceID: "\(contentID):\(nodeID)", channel: .storyScene,
            scope: AuthoredContentScope(scopeID: issueID, runID: runID), state: .nodeCompleted,
            recordedAt: moment, choiceID: choice, nodeID: nodeID)
    }

    private func completed(_ contentID: String, at moment: Date) -> AuthoredContentReceipt {
        AuthoredContentReceipt(
            contentID: contentID, occurrenceID: contentID, channel: .storyScene,
            scope: AuthoredContentScope(scopeID: issueID, runID: runID), state: .completed, recordedAt: moment)
    }

    private func harvest(_ receipts: [AuthoredContentReceipt], now: Date) throws -> [CastStoryMemory] {
        CastStoryMemoryHarvest.memories(
            source: CastStoryMemorySource(packs: [try pack()]),
            receipts: AuthoredContentReceiptLedger(receipts: receipts),
            lifecycle: .empty, now: now, calendar: calendar)
    }

    // MARK: The authored memories

    func testOctobersMemoriesKeepTheContract() throws {
        let cast = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id))
        let problems = CastStoryMemoryAudit.problems(in: try pack(), knownEntityIDs: cast)
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }

    func testEveryoneInAScenesCastRemembersSomethingFromIt() throws {
        for scene in try pack().storyScenes ?? [] {
            var remembered = Set((scene.castMemories ?? []).map(\.entityID))
            for choice in scene.choices { remembered.formUnion((choice.castMemories ?? []).map(\.entityID)) }
            for node in scene.nodes ?? [] {
                remembered.formUnion((node.castMemories ?? []).map(\.entityID))
                for choice in node.choices { remembered.formUnion((choice.castMemories ?? []).map(\.entityID)) }
            }
            for member in scene.castIDs ?? [] {
                XCTAssertTrue(remembered.contains(member), "\(member) was in \(scene.id) and remembers nothing")
            }
        }
    }

    func testTheRecordsMemoriesDontLeadTheRecord() throws {
        // A heard-about memory is frozen no earlier than its entry is public,
        // so its words may not carry what only later entries make public.
        let laterFacts: [String: Int] = [
            "bite": 8, "wound": 8, "living claim": 8, "Nightbound": 28, "Not today": 29, "crooked": 31
        ]
        for entry in try pack().events.first?.record?.entries ?? [] {
            let day = entry.publicFromDay ?? 31
            for memory in entry.castMemories ?? [] {
                let text = memory.memory + " " + (memory.aside ?? "")
                for (fact, from) in laterFacts where day < from {
                    XCTAssertFalse(text.localizedCaseInsensitiveContains(fact),
                                   "\(entry.id)/\(memory.entityID) tells '\(fact)' on day \(day)")
                }
            }
        }
    }

    // MARK: Earning them

    func testAChoiceIsRememberedOnlyByTheRouteTaken() throws {
        let memories = try harvest([
            node("academy.school.chair-first", "academy.school.chair-first.choice", choice: "beside-map", at: date(10, 1))
        ], now: date(10, 1, hour: 13))
        let keys = Set(memories.filter { $0.witness == .withReader }.map(\.key))
        XCTAssertTrue(keys.contains("count-unbound.lunch.reader-beside-map"))
        XCTAssertFalse(keys.contains("count-unbound.lunch.reader-near-pot"))
        XCTAssertEqual(Set(memories.filter { $0.key == "count-unbound.lunch.reader-beside-map" }.map(\.entityID)),
                       ["serenity-brown", "wicker-eddies", "ambrose-trencher"])
    }

    func testAPlainSceneIsRememberedWhenItsCompleted() throws {
        let memories = try harvest([completed("academy.school.sentence-coat", at: date(10, 2))], now: date(10, 3))
        XCTAssertTrue(memories.contains { $0.entityID == "professor-vivian-villanelle" && $0.witness == .withReader })
    }

    func testWhatTheReaderOnlyHeardAboutWaitsUntilItsPublic() throws {
        // The bite happens on day 7 and is public from day 8.
        let early = try harvest([], now: date(10, 6))
        XCTAssertFalse(early.contains { $0.key == "count-unbound.stacks.found" })
        XCTAssertTrue(early.contains { $0.key == "count-unbound.lunch.chair" && $0.witness == .lived })
        let later = try harvest([], now: date(10, 10))
        let bitten = try XCTUnwrap(later.first { $0.key == "count-unbound.stacks.found" })
        XCTAssertEqual(bitten.witness, .lived)
        XCTAssertEqual(calendar.component(.day, from: bitten.happenedAt), 8, "dated by the day it happened")
        let residue = try harvest([], now: date(11, 3))
        XCTAssertTrue(residue.contains { $0.key == "count-unbound.kitchens.case" && $0.entityID == "wicker-eddies" })
    }

    func testTheReadersVersionOfAMomentReplacesTheRumour() throws {
        let heard = CastStoryMemoryLedger.empty.absorbing(try harvest([], now: date(10, 2)))
        let rumour = try XCTUnwrap(heard.memories.first { $0.key == "count-unbound.lunch.bread" && $0.entityID == "wicker-eddies" })
        XCTAssertEqual(rumour.witness, .lived)
        let lived = heard.absorbing(try harvest([
            node("academy.school.chair-first", "academy.school.chair-first.after", at: date(10, 2, hour: 13))
        ], now: date(10, 2, hour: 14)))
        let mine = try XCTUnwrap(lived.memories.first { $0.id == rumour.id })
        XCTAssertEqual(mine.witness, .withReader)
        XCTAssertNotNil(mine.aside)
    }

    func testMemoriesAreFrozenAndOutliveThePack() throws {
        let receipts = [node("count-unbound.scene.sunday-jump", "count-unbound.scene.sunday-jump.disturbance",
                             choice: "cross-out", at: date(10, 4))]
        let ledger = CastStoryMemoryLedger.empty.absorbing(try harvest(receipts, now: date(10, 4, hour: 13)))
        XCTAssertTrue(ledger.remembers(key: "count-unbound.jump.reader-said-cross-out", entityID: "wicker-eddies"))
        XCTAssertEqual(ledger.absorbing(try harvest(receipts, now: date(10, 4, hour: 13))), ledger, "idempotent")
        // November: the pack has retired. Nothing new is harvested, nothing is lost.
        let retired = CastStoryMemoryHarvest.memories(
            source: CastStoryMemorySource(packs: []), receipts: AuthoredContentReceiptLedger(receipts: receipts),
            lifecycle: .empty, now: date(11, 20), calendar: calendar)
        XCTAssertEqual(ledger.absorbing(retired), ledger)
        // And a rewritten pack can't change what was frozen.
        var rewritten = try XCTUnwrap(ledger.memories.first)
        rewritten.memory = "Something else entirely."
        XCTAssertEqual(ledger.absorbing([rewritten]).memories.first?.memory, ledger.memories.first?.memory)
    }

    // MARK: Saying them

    private func memory(_ id: String, entity: String, at moment: Date, witness: CastStoryMemory.Witness = .withReader,
                        aside: String? = "I remember it.") -> CastStoryMemory {
        CastStoryMemory(id: id, entityID: entity, key: id, memory: "\(entity) did a thing.", aside: aside,
                        witness: witness, storyTitle: "The Count Unbound", momentTitle: "A moment", runID: runID,
                        sourceID: id, happenedAt: moment, frozenAt: moment)
    }

    func testAnAsideWaitsForANightAndIsSaidOnce() throws {
        let now = date(10, 10)
        var ledger = CastStoryMemoryLedger(memories: [
            memory("fresh", entity: "wicker-eddies", at: now.addingTimeInterval(-3_600)),
            memory("settled", entity: "serenity-brown", at: now.addingTimeInterval(-30 * 3_600)),
            memory("stale", entity: "penny-blackletter", at: now.addingTimeInterval(-40 * 86_400)),
            memory("silent", entity: "soren-ng", at: now.addingTimeInterval(-30 * 3_600), aside: nil)
        ])
        let speakers: Set = ["wicker-eddies", "serenity-brown", "penny-blackletter", "soren-ng"]
        XCTAssertEqual(CastStoryAside.pick(ledger: ledger, now: now, speakers: speakers, calendar: calendar)?.id, "settled")
        ledger = ledger.markingSpoken("settled", at: now)
        XCTAssertNil(CastStoryAside.pick(ledger: ledger, now: now.addingTimeInterval(3_600), speakers: speakers, calendar: calendar),
                     "one a day")
        XCTAssertNil(CastStoryAside.pick(ledger: ledger, now: date(10, 11, hour: 4), speakers: speakers, calendar: calendar),
                     "each aside once; the fresh one is still settling, the stale one is past")
        XCTAssertEqual(CastStoryAside.pick(ledger: ledger, now: date(10, 11, hour: 20), speakers: speakers, calendar: calendar)?.id,
                       "fresh")
    }

    func testTheCastOnTheKeptPageAndTheReadersOwnMomentsGoFirst() throws {
        let now = date(10, 20)
        let ledger = CastStoryMemoryLedger(memories: [
            memory("heard-newer", entity: "penny-blackletter", at: now.addingTimeInterval(-20 * 3_600), witness: .lived),
            memory("lived-older", entity: "serenity-brown", at: now.addingTimeInterval(-5 * 86_400)),
            memory("on-page", entity: "ambrose-trencher", at: now.addingTimeInterval(-6 * 86_400), witness: .lived)
        ])
        let speakers: Set = ["penny-blackletter", "serenity-brown", "ambrose-trencher"]
        XCTAssertEqual(CastStoryAside.pick(ledger: ledger, now: now, speakers: speakers, calendar: calendar)?.id, "lived-older")
        XCTAssertEqual(CastStoryAside.pick(ledger: ledger, now: now, speakers: speakers,
                                           preferring: ["ambrose-trencher"], calendar: calendar)?.id, "on-page")
        XCTAssertNil(CastStoryAside.pick(ledger: ledger, now: now, speakers: [], calendar: calendar),
                     "nobody speaks who isn't in the Book")
    }

    func testEveryAsideSpeakerHasAPortrait() {
        for id in ["serenity-brown", "wicker-eddies", "ambrose-trencher", "penny-blackletter",
                   "professor-permancer", "professor-vivian-villanelle", "soren-ng"] {
            XCTAssertTrue(CastStoryAside.plateAssetName(for: id).hasPrefix("LabyrinthCharacter"))
        }
        XCTAssertEqual(CastStoryAside.plateAssetName(for: "soren-ng"), "LabyrinthCharacterSorenNg")
        XCTAssertEqual(CastStoryAside.plateAssetName(for: "professor-vivian-villanelle"),
                       "LabyrinthCharacterProfessorVivianVillanelle")
    }

    // MARK: Later scenes, prompts, and the Cast page

    func testARecallIsThereOnlyForSomeoneWhoRemembers() {
        let recall = AuthoredCastRecall(
            marker: "{bread}", entityID: "wicker-eddies",
            options: [.init(key: "count-unbound.lunch.reader-beside-map", line: "Wicker still mentions the chair."),
                      .init(key: "count-unbound.lunch.bread", line: "Wicker brings the bread.")],
            fallback: "")
        let body = "Lunch again.\n\n{bread}\n\nThe soup is good."
        XCTAssertEqual(CastStoryRecall.render(body, recalls: [recall], ledger: .empty), "Lunch again.\n\nThe soup is good.")
        let heard = CastStoryMemoryLedger(memories: [
            memory("count-unbound.lunch.bread", entity: "wicker-eddies", at: date(10, 1), witness: .lived)
        ])
        XCTAssertEqual(CastStoryRecall.render(body, recalls: [recall], ledger: heard),
                       "Lunch again.\n\nWicker brings the bread.\n\nThe soup is good.")
        let elsewhere = CastStoryMemoryLedger(memories: [
            memory("count-unbound.lunch.reader-beside-map", entity: "serenity-brown", at: date(10, 1))
        ])
        XCTAssertFalse(CastStoryRecall.render(body, recalls: [recall], ledger: elsewhere).contains("chair"),
                       "Serenity remembering it isn't Wicker remembering it")
    }

    func testStoryMemoriesReachTheCastsOrdinaryMemory() {
        let ledger = CastStoryMemoryLedger(memories: [memory("m1", entity: "wicker-eddies", at: date(10, 4))])
        let base = [NarrativeEntityMemory(id: "old", entityID: "wicker-eddies", sourceEventID: "e", sourcePageID: nil,
                                          summary: "Wicker remembers a page.", tags: [], narrativeWeight: 2,
                                          createdAt: date(10, 2))]
        let merged = CastStoryMemoryProjection.merged(base, ledger: ledger)
        XCTAssertEqual(merged.map(\.id), ["cast-story-m1", "old"])
        XCTAssertTrue(merged[0].summary.hasPrefix("The Count Unbound: "))
        XCTAssertTrue(merged[0].tags.contains(CastStoryMemoryProjection.tag))
        XCTAssertEqual(CastStoryMemoryProjection.merged(merged, ledger: ledger).count, 2, "never doubled")
    }

    func testTheCastPageGivesTheStoryItsOwnShelf() throws {
        let wicker = try XCTUnwrap(NarrativePackRegistry.bundledPacks.flatMap(\.entities).first { $0.id == "wicker-eddies" })
        let ledger = CastStoryMemoryLedger(memories: [
            memory("m1", entity: "wicker-eddies", at: date(10, 4)),
            memory("m2", entity: "serenity-brown", at: date(10, 4))
        ])
        let record = CastMemberLivingRecord(
            entity: wicker, cast: [wicker],
            memories: CastStoryMemoryProjection.merged([], ledger: ledger),
            days: [], movements: [], authoredRelationships: [], relationshipField: [:],
            storyMemories: ledger.memories, now: date(10, 6))
        XCTAssertEqual(record.storyMemories?.map(\.id), ["m1"])
        XCTAssertEqual(record.storyMemories?.first?.aside, "I remember it.")
        XCTAssertTrue(record.memories.isEmpty, "the story isn't repeated under What stuck")
    }

    func testOldSavesAndPagesStillDecode() throws {
        let decoder = JSONDecoder()
        let entry = try decoder.decode(WorldEventRecordEntry.self, from: Data(#"{"id":"a","title":"t","account":"x"}"#.utf8))
        XCTAssertNil(entry.castMemories)
        let choice = try decoder.decode(AuthoredStorySceneChoice.self, from: Data(
            #"{"id":"c","title":"t","prompt":"p","result":"r","effectLine":"","consequenceTags":[]}"#.utf8))
        XCTAssertNil(choice.castMemories)
    }
}
