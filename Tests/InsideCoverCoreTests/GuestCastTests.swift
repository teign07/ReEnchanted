import XCTest
@testable import InsideCoverCore

final class GuestCastTests: XCTestCase {
    private var previous = GuestCastState()
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    override func setUp() {
        super.setUp()
        previous = GuestCast.current
        GuestCast.current = GuestCastState()
    }
    override func tearDown() {
        GuestCast.current = previous
        super.tearDown()
    }
    private func receipt(_ scene: String = "the-knock", state: AuthoredContentReceiptState = .opened,
                         choice: String? = nil, at time: Date? = nil, year: Int = 2026) -> AuthoredContentReceipt {
        AuthoredContentReceipt(contentID: "the-guest.scene.\(scene)", occurrenceID: "guest-test-\(scene)",
            channel: .storyScene, scope: AuthoredContentScope(scopeID: "the-guest-november-2026", runID: "the-guest:\(year)"),
            state: state, recordedAt: time ?? date(11, 1, year: year), choiceID: choice)
    }
    private func memory(_ key: String, witness: CastStoryMemory.Witness = .withReader,
                        entity: String = GuestCast.entityID, at time: Date? = nil) -> CastStoryMemory {
        let moment = time ?? date(11, 30)
        return CastStoryMemory(id: CastStoryMemory.id(runID: "the-guest:2026", key: key, entityID: entity),
            entityID: entity, key: key, memory: "An authored November moment.", witness: witness,
            storyTitle: "The Guest Who Came on All Souls", momentTitle: "The Bowl", runID: "the-guest:2026",
            sourceID: "the-guest.scene.the-bowl", happenedAt: moment, frozenAt: moment)
    }
    private func resolve(_ receipts: [AuthoredContentReceipt] = [], memories: [CastStoryMemory] = [],
                         now: Date? = nil) -> GuestCastState {
        .resolve(receipts: AuthoredContentReceiptLedger(receipts: receipts),
                 memories: CastStoryMemoryLedger(memories: memories), now: now ?? date(12, 2), calendar: calendar)
    }
    private func pack() throws -> WorldEventPack {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/the-guest/november.reenchantedevents.json")))
    }

    func testDeliveryAndFutureReceiptsCannotIntroduceHim() {
        XCTAssertFalse(resolve([receipt(state: .delivered)]).introduced)
        XCTAssertFalse(resolve([receipt(at: date(11, 1))], now: date(10, 31)).introduced)
        XCTAssertFalse(resolve(memories: [memory("the-guest.knock.arrived", at: date(11, 1))], now: date(10, 31)).introduced)
        XCTAssertFalse(resolve(memories: [memory("the-guest.soul-cakes.forty", entity: "ambrose-trencher", at: date(11, 1))]).introduced)
    }

    func testOpeningOrThePublicArrivalIntroducesTheGuestWithoutANameReveal() {
        for state in [resolve([receipt()], now: date(11, 2)),
                      resolve(memories: [memory("the-guest.knock.fed", witness: .lived,
                                               entity: "ambrose-trencher", at: date(11, 1))], now: date(11, 2))] {
            XCTAssertTrue(state.introduced)
            XCTAssertEqual(state.name, "The Guest")
            XCTAssertTrue(state.isPresent(at: date(11, 2)))
            XCTAssertFalse(state.isPresent(at: date(12, 1)))
        }
    }

    func testAllThreeEndingsAreChoicesAndOnlyStayRevealsTheName() {
        for (choice, ending) in [("send-home", GuestCastState.Ending.home), ("ask-to-stay", .stay), ("let-it-go-back", .court)] {
            let state = resolve([receipt("the-bowl", state: .nodeCompleted, choice: choice, at: date(11, 30))])
            XCTAssertEqual(state.ending, ending)
            XCTAssertEqual(state.name, ending == .stay ? "Aiken Drum" : "The Guest")
            XCTAssertEqual(state.isPresent(at: date(12, 2)), ending == .stay)
            XCTAssertEqual(state.resolving(GuestCast.entity).id, "visitor-the-guest")
        }
    }

    func testAReportedChoiceAndHearsayCannotChooseAnEnding() {
        let reported = receipt("the-bowl", state: .reported, choice: "ask-to-stay", at: date(11, 30))
        let state = resolve([reported], memories: [memory("the-guest.bowl.stayed", witness: .heard)])
        XCTAssertTrue(state.introduced)
        XCTAssertNil(state.ending)
        XCTAssertEqual(state.name, "The Guest")
        XCTAssertFalse(state.isPresent(at: date(12, 2)))
    }

    func testFrozenMemoriesKeepTheIdentityAfterPackRetirementAndVaultRoundTrip() throws {
        var vault = PlayerVaultData()
        vault.castStoryMemories = CastStoryMemoryLedger(memories: [memory("the-guest.bowl.stayed", entity: "ambrose-trencher")])
        let restored = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(vault))
        GuestCast.synchronize(with: restored, now: date(12, 2))
        let guest = try XCTUnwrap(NarrativePackRegistry.entities.first { $0.id == GuestCast.entityID })
        XCTAssertEqual(guest.name, "Aiken Drum")
        XCTAssertTrue(guest.tags.contains("resident"))
        XCTAssertEqual(CastStoryAside.plateAssetName(for: guest.id), GuestCast.assetName)
    }

    func testAnEarlierYearsStayDoesNotChooseTheNextRunsEnding() {
        let old = receipt("the-bowl", state: .nodeCompleted, choice: "ask-to-stay", at: date(11, 30))
        let next = receipt(at: date(11, 1, year: 2027), year: 2027)
        let state = resolve([old, next], now: date(11, 2, year: 2027))
        XCTAssertTrue(state.introduced)
        XCTAssertNil(state.ending)
        XCTAssertEqual(state.name, "The Guest")
    }

    func testBeforeArrivalNoCastRelationshipPlateOrInterleafLeaksOut() {
        XCTAssertFalse(NarrativePackRegistry.knownEntities.contains { $0.id == GuestCast.entityID })
        XCTAssertFalse(NarrativePackRegistry.relationships.contains { $0.sourceEntityID == GuestCast.entityID })
        XCTAssertFalse(BookReferenceCatalog.labyrinthIllustrations.contains { $0.assetName == GuestCast.assetName })
        XCTAssertFalse(InterleafIllustrationLibrary.available.contains { $0.resolvedAssetName == GuestCast.assetName })
    }

    func testADepartedGuestRemainsInTheCastShelfButCannotBeCastIntoNewBusiness() throws {
        GuestCast.current = resolve([receipt("the-bowl", state: .nodeCompleted, choice: "send-home", at: date(11, 30))])
        XCTAssertTrue(NarrativePackRegistry.knownEntities.contains { $0.id == GuestCast.entityID })
        XCTAssertFalse(NarrativePackRegistry.entities.contains { $0.id == GuestCast.entityID })
        XCTAssertTrue(NarrativePackRegistry.knownRelationships.contains { $0.sourceEntityID == GuestCast.entityID })
        XCTAssertFalse(NarrativePackRegistry.relationships.contains { $0.sourceEntityID == GuestCast.entityID })
        XCTAssertTrue(try XCTUnwrap(CastDossier.bio(forSlug: GuestCast.entityID)).contains("You told it to go home"))
        XCTAssertFalse(try XCTUnwrap(CastDossier.bio(forSlug: GuestCast.entityID)).contains("Aiken Drum"))
        XCTAssertNotNil(CharacterPortrait.bundledAssetName(forName: "The Guest"), "The kept Page keeps its portrait")
    }

    func testStayKeepsTheKitchenInsteadOfGivingHimStudentQuarters() throws {
        GuestCast.current = resolve([receipt("the-bowl", state: .nodeCompleted, choice: "ask-to-stay", at: date(11, 30))])
        let guest = try XCTUnwrap(NarrativePackRegistry.entities.first { $0.id == GuestCast.entityID })
        XCTAssertEqual(AcademyWhereabouts.residence(for: guest), "location-kitchens")
        for hour in [3, 8, 13, 20, 23] {
            let people = AcademyWhereabouts.everyone(at: date(12, 2, hour: hour), calendar: calendar, cast: [guest])
            XCTAssertEqual(people.count, 1)
            XCTAssertEqual(people.first?.name, "Aiken Drum")
            XCTAssertEqual(people.first?.mapName, "Aiken Drum")
            XCTAssertEqual(people.first?.roomID, "location-kitchens")
            XCTAssertFalse(people.first?.isVisitor ?? true)
        }
    }

    func testMonthlyStagingCannotBringBackAGuestTheReaderSentAway() {
        for choice in ["send-home", "let-it-go-back"] {
            GuestCast.current = resolve([receipt("the-bowl", state: .nodeCompleted, choice: choice, at: date(11, 30))])
            var staging = AcademyEventStaging()
            staging.staging = [AcademyStaging(castID: GuestCast.entityID, roomID: "location-kitchens", name: "The Guest")]
            let people = AcademyWhereabouts.everyone(at: date(12, 2), calendar: calendar,
                staging: staging, cast: NarrativePackRegistry.entities)
            XCTAssertFalse(people.contains { $0.characterID == GuestCast.entityID }, choice)
        }
    }

    func testDossierArtAndRelationshipsKeepTheUnrevealedIdentity() throws {
        let dossier = try XCTUnwrap(CastDossier.bio(forSlug: GuestCast.entityID))
        for spoiler in ["Aiken", "Unseelie", "Serenity", "Court"] { XCTAssertFalse(dossier.contains(spoiler), spoiler) }
        let profile = try XCTUnwrap(CharacterPortrait.profile(forName: "The Guest"))
        XCTAssertEqual(profile.slug, GuestCast.entityID)
        XCTAssertEqual(profile.assetName, GuestCast.assetName)
        XCTAssertEqual(CastMarginalia.plateAssetName(forSlug: GuestCast.entityID), GuestCast.assetName)
        XCTAssertEqual(CastStoryNames.short("The Guest"), "The Guest")
        XCTAssertFalse(profile.prompt.contains("Aiken"))
        let canonical = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id))
        XCTAssertGreaterThanOrEqual(GuestCast.relationships.count, 7)
        for edge in GuestCast.relationships {
            XCTAssertTrue(canonical.contains(edge.sourceEntityID), edge.id)
            XCTAssertTrue(canonical.contains(edge.targetEntityID), edge.id)
            XCTAssertFalse(edge.note.contains("Aiken"), edge.id)
        }
        XCTAssertTrue(CharacterVoiceEvaluationDeck.scenarios.contains { $0.characterIDs.contains(GuestCast.entityID) })
    }

    func testChatCanRecallAnAbsentGuestAndTheOldTitleStillWorksAfterStay() {
        let own = memory("the-guest.bowl.stayed")
        let ledger = CastStoryMemoryLedger(memories: [own])
        let recalls = LetsChatCastMemory.recalls(for: "What does the Guest remember?", ledger: ledger,
            cast: [(id: GuestCast.entityID, name: "Aiken Drum")], now: date(12, 2))
        XCTAssertEqual(recalls.first?.entityID, GuestCast.entityID)
        XCTAssertEqual(recalls.first?.name, "Aiken Drum")
        XCTAssertEqual(recalls.first?.memories.count, 1)
        GuestCast.current = resolve(memories: [memory("the-guest.bowl.sent-home")])
        let known = NarrativePackRegistry.knownEntities.filter { $0.kind == .character }.map { (id: $0.id, name: $0.name) }
        let absent = LetsChatCastMemory.recalls(for: "What does the Guest remember?",
            ledger: CastStoryMemoryLedger(memories: [memory("the-guest.bowl.sent-home")]), cast: known, now: date(12, 2))
        XCTAssertEqual(absent.first?.entityID, GuestCast.entityID)
        XCTAssertEqual(absent.first?.name, "The Guest")
    }

    func testThePackGivesHimOnlyTheEndingHeLivedAndKeepsItAfterRetirement() throws {
        let pack = try pack()
        XCTAssertGreaterThanOrEqual(pack.minimumRuntimeVersion ?? 1, 12)
        let bowl = try XCTUnwrap(pack.storyScenes?.first { $0.id == "the-guest.scene.the-bowl" })
        let node = try XCTUnwrap(bowl.nodes?.first { $0.id.hasSuffix(".home-or-not") })
        for (choice, key) in [("send-home", "the-guest.bowl.sent-home"), ("ask-to-stay", "the-guest.bowl.stayed"), ("let-it-go-back", "the-guest.bowl.went-back")] {
            var r = receipt("the-bowl", state: .nodeCompleted, choice: choice, at: date(11, 30))
            r.nodeID = node.id
            let earned = CastStoryMemoryHarvest.memories(source: CastStoryMemorySource(packs: [pack]),
                receipts: AuthoredContentReceiptLedger(receipts: [r]), lifecycle: .empty,
                now: date(11, 30, hour: 13), calendar: calendar)
            let own = earned.filter { $0.entityID == GuestCast.entityID && $0.witness == .withReader }
            XCTAssertEqual(own.filter { $0.key.hasPrefix("the-guest.bowl.") }.map(\.key), [key])
            let frozen = CastStoryMemoryLedger(memories: own)
            let retired = CastStoryMemoryHarvest.memories(source: CastStoryMemorySource(packs: []),
                receipts: .empty, lifecycle: .empty, now: date(12, 10), calendar: calendar)
            XCTAssertEqual(frozen.absorbing(retired), frozen)
        }
    }

    func testTheRecordAuditRequiresTheGuestsNameRatherThanHisVisitorPrefix() throws {
        var pack = try pack()
        let cast = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).map(\.id))
        XCTAssertEqual(CastStoryMemoryAudit.problems(in: pack, knownEntityIDs: cast), [])
        let index = try XCTUnwrap(pack.events[0].record?.entries.firstIndex { $0.id == "the-guest.record.the-knock" })
        pack.events[0].record?.entries[index].account = "Ambrose fed a visitor by the fire."
        XCTAssertTrue(CastStoryMemoryAudit.problems(in: pack, knownEntityIDs: cast).contains {
            $0 == "record memory for someone the account doesn't name: the-guest.record.the-knock/visitor-the-guest"
        })
    }
}
