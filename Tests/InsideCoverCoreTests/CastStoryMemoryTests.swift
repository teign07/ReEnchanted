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

    // MARK: Second-hand

    private var listeners: [CastStoryGossip.Listener] {
        CastStoryGossip.listeners(from: NarrativePackRegistry.bundledPacks.flatMap(\.entities))
    }

    private func told(_ ledger: CastStoryMemoryLedger, now: Date,
                      closeness: @escaping (String, String) -> Int = { _, _ in 0 }) -> [CastStoryMemory] {
        CastStoryGossip.spread(ledger: ledger, listeners: listeners, closeness: closeness, now: now, calendar: calendar)
    }

    func testTheNewsReachesTwoPeopleWhoWerentThere() throws {
        // Lunch on day 0 is public at once; the bread gets round.
        let ledger = CastStoryMemoryLedger.empty.absorbing(try harvest([], now: date(10, 6)))
        let heard = told(ledger, now: date(10, 6))
        let bread = heard.filter { $0.key == "count-unbound.lunch.bread" }
        XCTAssertEqual(bread.count, 2)
        for memory in bread {
            XCTAssertEqual(memory.witness, .heard)
            XCTAssertEqual(memory.heardFromID, "ambrose-trencher", "told by the bystander, not by Wicker")
            XCTAssertFalse(["wicker-eddies", "serenity-brown", "ambrose-trencher"].contains(memory.entityID),
                           "nobody's told about their own lunch")
            XCTAssertTrue(memory.aside?.hasPrefix("Ambrose says Wicker") == true, memory.aside ?? "")
            XCTAssertGreaterThanOrEqual(memory.happenedAt.timeIntervalSince(date(10, 1, hour: 0)), 86_400, "a day at least")
        }
        XCTAssertFalse(heard.contains { $0.key == "count-unbound.lunch.chair" }, "only gossip-worthy moments spread")
        // Told once, to the same ears, however often it's worked out.
        let after = ledger.absorbing(heard)
        XCTAssertEqual(after.absorbing(told(after, now: date(10, 7))).memories.filter {
            $0.key == "count-unbound.lunch.bread" && $0.witness == .heard
        }.count, 2)
        XCTAssertEqual(Set(told(ledger, now: date(10, 6)).map(\.id)), Set(heard.map(\.id)), "deterministic")
    }

    func testNewsWaitsADayAndCloseFriendsHearFirst() {
        var news = memory("bread", entity: "wicker-eddies", at: date(10, 10))
        news.gossip = "{teller} says there was bread."
        news.presentIDs = ["wicker-eddies"]
        let ledger = CastStoryMemoryLedger(memories: [news])
        XCTAssertTrue(told(ledger, now: date(10, 10, hour: 20)).isEmpty, "not the same day")
        let friend = listeners.first { $0.id != "wicker-eddies" && $0.id != "serenity-brown" }!.id
        let heard = told(ledger, now: date(10, 20)) { a, b in
            Set([a, b]) == Set(["wicker-eddies", friend]) ? 50 : 0
        }
        XCTAssertTrue(heard.contains { $0.entityID == friend })
        XCTAssertEqual(heard.first { $0.entityID == friend }?.aside, "Everyone says there was bread.",
                       "nobody tells on themselves; with no bystander it's going round")
        XCTAssertNil(heard.first?.heardFromID)
    }

    func testWhoeverOnlyHeardItNeverTellsIt() {
        var news = memory("bread", entity: "wicker-eddies", at: date(10, 1))
        news.gossip = "{teller} says there was bread."
        news.presentIDs = ["wicker-eddies"]
        var heard = memory("bread", entity: "penny-blackletter", at: date(10, 2), witness: .heard)
        heard.id = CastStoryMemory.id(runID: runID, key: "bread", entityID: "penny-blackletter")
        heard.heardFromName = nil
        let second = told(CastStoryMemoryLedger(memories: [news, heard]), now: date(10, 30))
        XCTAssertEqual(second.count, 1)
        XCTAssertNil(second.first?.heardFromID, "Penny only heard it")
        XCTAssertNotEqual(second.first?.entityID, "penny-blackletter")
    }

    func testHearsayIsntPassedOnAndGivesWayToBeingThere() {
        var rumour = memory("bread", entity: "penny-blackletter", at: date(10, 10), witness: .heard)
        rumour.gossip = nil
        XCTAssertTrue(told(CastStoryMemoryLedger(memories: [rumour]), now: date(10, 30)).isEmpty, "one hop")
        var lived = rumour
        lived.witness = .lived
        let ledger = CastStoryMemoryLedger(memories: [rumour]).absorbing([lived])
        XCTAssertEqual(ledger.memories.first?.witness, .lived)
        XCTAssertEqual(CastStoryMemoryLedger(memories: [lived]).absorbing([rumour]).memories.first?.witness, .lived)
    }

    func testTheCastPageSaysWhoTold() throws {
        let zara = try XCTUnwrap(NarrativePackRegistry.bundledPacks.flatMap(\.entities).first { $0.kind == .character })
        var heard = memory("bread", entity: zara.id, at: date(10, 4), witness: .heard)
        heard.heardFromName = "Wicker"
        let record = CastMemberLivingRecord(
            entity: zara, cast: [zara], memories: [], days: [], movements: [], authoredRelationships: [],
            relationshipField: [:], storyMemories: [heard], now: date(10, 6))
        XCTAssertEqual(record.storyMemories?.first?.heardFrom, "Wicker")
        XCTAssertTrue(CastStoryMemoryProjection.entityMemories(CastStoryMemoryLedger(memories: [heard]))
            .first?.summary.contains("heard from Wicker") == true)
    }

    // MARK: Let's Chat

    private var castNames: [(id: String, name: String)] {
        NarrativePackRegistry.bundledPacks.flatMap(\.entities).filter { $0.kind == .character }.map { (id: $0.id, name: $0.name) }
    }

    func testAskingWhatSomeoneRemembersIsAnsweredFromTheLedger() throws {
        let receipts = [node("academy.school.chair-first", "academy.school.chair-first.after", at: date(10, 1))]
        let ledger = CastStoryMemoryLedger.empty.absorbing(try harvest(receipts, now: date(10, 3)))
        let recalls = LetsChatCastMemory.recalls(for: "What does Wicker remember?", ledger: ledger, cast: castNames, now: date(10, 3))
        XCTAssertEqual(recalls.map(\.entityID), ["wicker-eddies"])
        let answer = try XCTUnwrap(LetsChatCastMemory.answer(to: "What does Wicker remember?", recalls: recalls))
        XCTAssertTrue(answer.hasPrefix("Wicker's carrying"))
        XCTAssertTrue(answer.contains("stepping stone"))
        XCTAssertTrue(answer.contains("You were there for that one."))
        XCTAssertNil(LetsChatCastMemory.answer(to: "Wicker is funny", recalls: recalls), "only the direct question")
        XCTAssertTrue(LetsChatCastMemory.recalls(for: "what about the weather", ledger: ledger, cast: castNames).isEmpty)
    }

    func testSomeoneWithNothingToTellSaysSo() {
        let recalls = LetsChatCastMemory.recalls(for: "Has Permancer heard about it?", ledger: .empty, cast: castNames)
        XCTAssertEqual(recalls.first?.entityID, "professor-permancer", "a professor answers to his surname")
        XCTAssertEqual(LetsChatCastMemory.answer(to: "Has Permancer heard about it?", recalls: recalls)?
            .hasPrefix("Professor Permancer hasn't told me anything"), true)
    }

    func testTheChatPromptCarriesWhatTheyRemember() throws {
        var heard = memory("bread", entity: "serenity-brown", at: date(10, 2), witness: .heard)
        heard.heardFromName = "Wicker"
        let recalls = LetsChatCastMemory.recalls(
            for: "Is Serenity okay?", ledger: CastStoryMemoryLedger(memories: [heard]), cast: castNames, now: date(10, 3))
        let prompt = LetsChatPrompt.render(
            LetsChatPrompt.Inputs(message: "Is Serenity okay?", route: LetsChatRouter.route("Is Serenity okay?"),
                                  castRecalls: recalls),
            budget: LetsChatPrompt.Budget(evidenceCount: 0, historyTurns: 0, knowledgeNotes: 0,
                                          interiorCharacters: 0, recentPages: 0))
        XCTAssertTrue(prompt.contains("WHAT SERENITY BROWN REMEMBERS FROM THE STORY"))
        XCTAssertTrue(prompt.contains("(heard it from Wicker)"))
        XCTAssertTrue(prompt.contains("don't add to them"))
    }

    func testNobodyIsToldAboutThemselvesOrHearsTheWholeMonth() throws {
        let ledger = CastStoryMemoryLedger.empty.absorbing(try harvest([], now: date(11, 5)))
        let heard = told(ledger, now: date(11, 5)) { _, _ in 12 }
        XCTAssertFalse(heard.isEmpty)
        let names = Dictionary(listeners.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var load: [String: Int] = [:]
        for memory in heard {
            let aside = try XCTUnwrap(memory.aside)
            XCTAssertFalse(aside.contains("{teller}"))
            if let teller = memory.heardFromName {
                let short = teller.split(separator: " ").last.map(String.init) ?? teller
                XCTAssertFalse(aside.dropFirst(teller.count).contains(short), "\(teller) tells on themselves: \(aside)")
            }
            XCTAssertFalse(CastStoryNames.mentions(memory.memory + " " + aside, name: names[memory.entityID] ?? ""),
                           "\(memory.entityID) hears about themselves")
            load[memory.entityID, default: 0] += 1
        }
        XCTAssertLessThanOrEqual(load.values.max() ?? 0, 4, "the month's news is spread about: \(load)")
    }
}
