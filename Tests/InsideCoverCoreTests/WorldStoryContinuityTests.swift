import XCTest
@testable import InsideCoverCore

final class WorldStoryContinuityTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int = 10, _ hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func day(_ number: Int = 10, lived: Bool = false) -> BookDay {
        BookDay(id: "2026-10-\(number)", date: date(number, 0), pages: lived ? [
            BookPage(id: "reader-diary", type: .diary, createdAt: date(number, 12), promptText: "Diary",
                userInput: "I repaired the blue gate after lunch. The new latch held when I closed it.", origin: .userAuthored)
        ] : [])
    }

    private func pack() throws -> WorldEventPack {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
    }

    private func event(pulses: [WorldEventPulse]? = nil) throws -> ResolvedWorldEvent {
        let pack = try pack()
        let authored = try XCTUnwrap(pack.events.first)
        var phase = try XCTUnwrap(authored.phases.first)
        if let pulses { phase.pulses = pulses }
        return ResolvedWorldEvent(id: authored.id, packID: pack.id, title: authored.title,
            subtitle: authored.subtitle, phase: phase, startedAt: date(1, 0), endsAt: date(31, 23),
            progress: 0.1, playerTouchCount: 0, effects: [], packet: authored.packet)
    }

    private func record(_ brief: BleedColumnBrief, at date: Date? = nil) -> BleedPrintRecord {
        BleedPrintRecord(slotID: "paper-\((date ?? self.date()).timeIntervalSince1970)", printedAt: date ?? self.date(), items: [
            .init(storyID: brief.storyID ?? brief.id, revision: brief.revision ?? "one", title: brief.title,
                  body: brief.composedBody, sourcePageIDs: [], worldFactID: brief.worldFactID,
                  worldEventRunID: brief.worldEventRunID, undertakingID: brief.undertakingID)
        ])
    }

    private func business(_ id: String = "penny-case", privateScene: Bool = false) -> CastUndertaking {
        CastUndertaking(id: id, actorID: "penny-blackletter", title: "The altered record",
            pursuit: "Find the original", why: "Someone changed it", stages: [
                CastUndertakingStage(id: "test-comma", line: "Penny found a changed comma.",
                    trace: "A red circle on page four.", tags: ["archive"],
                    scene: "Penny holds the paper up. ‘This comma was not here,’ she says.",
                    surface: privateScene ? .letter : .witnessedScene),
                CastUndertakingStage(id: "test-interview", line: "Penny interviewed the witness.",
                    trace: "A name crossed out twice.", tags: ["archive"],
                    scene: "Penny closes the notebook. ‘That is the same answer,’ she says.")
            ], stageIndex: 0, status: .active, startedAt: date(1), lastAdvancedAt: date(9), nextEligibleAt: date(12))
    }

    func testMorningPaperAndBraidChooseTheSameMonthlyFact() throws {
        let event = try event()
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [event]
        let morning = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        let forNight = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(10, 0), worldEvents: [event],
            recentDays: [], printed: [record(morning)], through: date(10, 22), calendar: calendar))
        XCTAssertEqual(forNight.fact.id, morning.worldFactID)
        XCTAssertEqual(forNight.fact.text, morning.composedBody)
        XCTAssertEqual(forNight.runID, morning.worldEventRunID)
    }

    func testActualLivedAndQuietBraidPlansCarryThePrintedPulse() throws {
        let event = try event()
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [event]
        let morning = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        var context = BraidPromptBuilder.Context()
        context.activeWorldEvents = [event]
        context.bleedPrintHistory = [record(morning)]
        context.worldStoryCutoff = date(10, 22)
        let quiet = BraidScenePlanBuilder.plan(for: day(), context: context, calendar: calendar)
        XCTAssertEqual(quiet.quietDayBeats.first?.id, morning.worldFactID)
        XCTAssertLessThanOrEqual(quiet.quietDayBeats.count, BraidScenePlanBuilder.worldItemLimit)
        let lived = BraidScenePlanBuilder.plan(for: day(lived: true), context: context, calendar: calendar)
        XCTAssertEqual(lived.worldBeat?.id, morning.worldFactID, lived.summary)
        XCTAssertEqual(lived.reportedWorldFactIDs, [morning.worldFactID!])
        XCTAssertTrue(lived.brief().contains("This is the same event; no later outcome is supplied."))
        XCTAssertFalse(lived.worldBeat?.fact.contains("Today's paper") == true)
    }

    func testContextFactoryCarriesPressMemoryWithoutTreatingItAsReaderEvidence() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let morning = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        let memory = [record(morning)]
        let context = BraidPromptBuilder.context(for: day(), days: [], activeWorldEvents: inputs.activeWorldEvents,
            bleedPrintHistory: memory, now: date(10, 22), calendar: calendar)
        XCTAssertEqual(context.bleedPrintHistory, memory)
        XCTAssertEqual(context.worldStoryCutoff, date(10, 22))
        XCTAssertTrue(BraidScenePlanBuilder.plan(for: day(), context: context, calendar: calendar).evidence.isEmpty)
    }

    func testOpeningEveningDoesNotPrintOrRerollTheMorningPulse() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let morning = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        let memory = [record(morning)]
        XCTAssertNil(BleedNewsroom.monthlyBrief(kind: .evening, day: day(), inputs: inputs,
            history: memory, now: date(10, 18), calendar: calendar))
        let evening = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(10, 18), worldEvents: inputs.activeWorldEvents,
            recentDays: [], printed: memory, calendar: calendar))
        XCTAssertEqual(evening.fact.id, morning.worldFactID)
    }

    func testMissedMorningStillHasAnEveningAndNightlyStory() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let evening = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .evening, day: day(), inputs: inputs,
            history: [], now: date(10, 18), calendar: calendar))
        let night = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(10, 0), worldEvents: inputs.activeWorldEvents,
            recentDays: [], printed: [], calendar: calendar))
        XCTAssertEqual(evening.worldFactID, night.fact.id)
    }

    func testCurrentPhaseBoundaryRejectsAnEarlierPhaseChoice() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let old = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        var next = try event(pulses: [WorldEventPulse(id: "later", text: "The bridge has come down.", tender: "The bridge is down.")])
        next.phase.id = "later-phase"
        let chosen = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(10, 18), worldEvents: [next],
            recentDays: [], printed: [record(old)], calendar: calendar))
        XCTAssertEqual(chosen.fact.id, "world-event:\(next.id):pulse:later")
    }

    func testDailyChoiceIsStableUnderPulseAndArchiveOrdering() throws {
        let original = try event()
        var reordered = original
        reordered.phase.pulses?.reverse()
        let first = SceneWorldCanon.dailyPulse(on: date(), worldEvents: [original], recentDays: [], calendar: calendar)
        let second = SceneWorldCanon.dailyPulse(on: date(10, 18), worldEvents: [reordered], recentDays: [day(9)], calendar: calendar)
        XCTAssertEqual(first, second)
    }

    func testPrintedPulseRemainsFixedWhenEarlierNightHistoryArrives() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let morning = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        var yesterday = day(9)
        yesterday.pages = [BookPage(type: .bookOfYou, createdAt: date(9, 22), promptText: "Night",
            tags: ["braid-claim:world:\(morning.worldFactID!)"], origin: .generated)]
        let chosen = SceneWorldCanon.dailyPulse(on: date(10, 22), worldEvents: inputs.activeWorldEvents,
            recentDays: [yesterday], printed: [record(morning)], calendar: calendar)
        XCTAssertEqual(chosen?.fact.id, morning.worldFactID)
    }

    func testBraidFirstCanFreezeTheChoiceForALaterPaper() throws {
        let event = try event()
        let chosen = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [], calendar: calendar))
        var today = day()
        today.pages = [BookPage(type: .bookOfYou, createdAt: date(10, 16), promptText: "A night",
            tags: ["braid-claim:world:\(chosen.fact.id)"], origin: .generated)]
        let later = SceneWorldCanon.dailyPulse(on: date(10, 18), worldEvents: [event], recentDays: [today], calendar: calendar)
        XCTAssertEqual(later?.fact.id, chosen.fact.id)
    }

    func testExpiredFutureAndAnotherRunCannotFreezeTodaysStory() throws {
        var event = try event()
        event.startedAt = date(11, 0)
        XCTAssertNil(SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [], calendar: calendar))
        event.startedAt = date(1, 0)
        event.endsAt = date(9, 0)
        XCTAssertNil(SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [], calendar: calendar))
        event = try self.event()
        let baseline = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [], calendar: calendar))
        let other = try XCTUnwrap(event.phase.pulses?.first { "world-event:\(event.id):pulse:\($0.id)" != baseline.fact.id })
        let brief = BleedColumnBrief(id: "monthly-pulse", title: "Wrong run", byline: "Academy", composedBody: other.text,
            packet: "", maxTokens: 0, worldFactID: "world-event:\(event.id):pulse:\(other.id)", worldEventRunID: "old-run")
        let wrongRun = record(brief)
        var future = wrongRun
        future.printedAt = date(10, 23)
        future.items[0].worldEventRunID = baseline.runID
        let chosen = SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [],
            printed: [wrongRun, future], through: date(10, 22), calendar: calendar)
        XCTAssertEqual(chosen, baseline)
    }

    func testKeptPaperCanRecoverTheSharedChoiceWithoutVaultMemory() throws {
        let event = try event()
        let pulse = try XCTUnwrap(event.phase.pulses?.first)
        let brief = BleedColumnBrief(id: "monthly-pulse", title: event.title, byline: "Academy", composedBody: pulse.text,
            packet: "", maxTokens: 0, worldFactID: "world-event:\(event.id):pulse:\(pulse.id)",
            worldEventRunID: SceneWorldCanon.runID(for: event, calendar: calendar))
        var today = day()
        today.pages = [BookPage(type: .theBleed, createdAt: date(), promptText: "Morning",
            userInput: pulse.text, origin: .generated,
            metadata: [BleedPrintRecord.metadataKey: record(brief).encoded])]
        var context = BraidPromptBuilder.Context()
        context.activeWorldEvents = [event]
        context.worldStoryCutoff = date(10, 22)
        let plan = BraidScenePlanBuilder.plan(for: today, context: context, calendar: calendar)
        XCTAssertTrue(plan.evidence.isEmpty)
        XCTAssertEqual(plan.quietDayBeats.first?.id, brief.worldFactID)
        XCTAssertEqual(plan.reportedWorldFactIDs, [brief.worldFactID!])
    }

    func testWithoutAMonthlyEventTheBraidCanCarryTheReportedCastFact() throws {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [business("another-case"), business()]
        let report = try XCTUnwrap(BleedNewsroom.academyBriefs(inputs: inputs, history: [], now: date(), limit: 2)
            .first { $0.undertakingID == "penny-case" })
        var context = BraidPromptBuilder.Context()
        context.castUndertakings = inputs.castUndertakings
        context.bleedPrintHistory = [record(report)]
        context.worldStoryCutoff = date(10, 22)
        let plan = BraidScenePlanBuilder.plan(for: day(lived: true), context: context, calendar: calendar)
        XCTAssertEqual(plan.worldBeat?.id, report.worldFactID)
        XCTAssertEqual(plan.reportedWorldFactIDs, [report.worldFactID!])
        XCTAssertFalse(plan.brief().contains("‘This comma was not here,’"))
    }

    func testEncounteredMonthlyOutcomeOwnsTheNightOverThePrintedPulse() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let pulse = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "end", channel: .storyScene,
            state: .nodeCompleted, recordedAt: date(10, 18), storyText: "Wicker took the pin.")
        var context = BraidPromptBuilder.Context()
        context.activeWorldEvents = inputs.activeWorldEvents
        context.bleedPrintHistory = [record(pulse)]
        context.authoredStoryReceipts = [receipt]
        context.worldStoryCutoff = date(10, 22)
        let plan = BraidScenePlanBuilder.plan(for: day(lived: true), context: context, calendar: calendar)
        XCTAssertEqual(plan.authoredStoryReceipts, [receipt])
        XCTAssertNil(plan.worldBeat)
        XCTAssertTrue(plan.quietDayBeats.isEmpty)
        XCTAssertNil(plan.reportedWorldFactIDs)
        XCTAssertTrue(plan.brief().contains("Wicker took the pin."))
    }

    func testPressContextInSavedPlanIsOptionalForOlderPlans() throws {
        let plan = BraidScenePlanBuilder.plan(for: day(), calendar: calendar)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json.removeValue(forKey: "reportedWorldFactIDs")
        let legacy = try JSONDecoder().decode(BraidScenePlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.reportedWorldFactIDs)
    }

    func testHardDayUsesTheQuietVersionOfTheSameFact() throws {
        let event = try event(pulses: [WorldEventPulse(id: "one", text: "The stair refuses the soup.", tender: "The stair is quiet.")])
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [event]
        var hard = day()
        hard.pages = [BookPage(type: .diary, createdAt: date(), promptText: "Diary", userInput: "An honest line.", tags: ["distress"])]
        let copy = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: hard, inputs: inputs,
            history: [], now: date(), calendar: calendar))
        XCTAssertEqual(copy.composedBody, "The stair is quiet.")
        let pulse = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [], calendar: calendar))
        let live = SceneWorldCanon.dailyLiveFacts(undertakings: [], worldEvents: [event], selectedPulse: pulse, hardNight: true)
        let bench = try XCTUnwrap(BraidBench.corpus().first { $0.name == "tender-shadow" })
        let plan = BraidScenePlanBuilder.plan(for: bench.day, context: bench.context)
        let beat = try XCTUnwrap(SceneWorldCanon.beat(for: plan, recentDays: [], on: date(), live: live, preferredFactID: pulse.fact.id))
        XCTAssertEqual(beat.fact, "The stair is quiet.")
    }

    func testPulseWithoutQuietVariantDoesNotEnterAHardPaperOrNight() throws {
        let event = try event(pulses: [WorldEventPulse(id: "one", text: "The stair throws the soup.")])
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [event]
        var hard = day()
        hard.pages = [BookPage(type: .diary, createdAt: date(), promptText: "Diary", userInput: "An honest line.", tags: ["distress"])]
        XCTAssertNil(BleedNewsroom.monthlyBrief(kind: .evening, day: hard, inputs: inputs,
            history: [], now: date(10, 18), calendar: calendar))
        let pulse = try XCTUnwrap(SceneWorldCanon.dailyPulse(on: date(), worldEvents: [event], recentDays: [], calendar: calendar))
        XCTAssertFalse(SceneWorldCanon.dailyLiveFacts(undertakings: [], worldEvents: [event], selectedPulse: pulse,
            hardNight: true).contains { $0.id == pulse.fact.id })
    }

    func testPublicCastReportGetsTheAuthoredSceneWithoutFutureOrPrivateScenes() throws {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [business()]
        let report = try XCTUnwrap(BleedNewsroom.academyBriefs(inputs: inputs, history: [], now: date(), limit: 1).first)
        XCTAssertTrue(report.packet.contains("‘This comma was not here,’"))
        XCTAssertFalse(report.packet.contains("Penny closes the notebook"))
        XCTAssertEqual(report.undertakingID, "penny-case")
        inputs.castUndertakings = [business(privateScene: true)]
        XCTAssertTrue(BleedNewsroom.academyBriefs(inputs: inputs, history: [], now: date(), limit: 1).isEmpty)
    }

    func testPrintedReportPrefersTheRelatedSceneWithoutWitnessingOrSkippingIt() throws {
        var inputs = BookSourceInputs.empty
        var wanted = business()
        wanted.stageIndex = 1
        var other = business("another-case")
        other.actorID = "thorne"
        inputs.castUndertakings = [other, wanted]
        let report = try XCTUnwrap(BleedNewsroom.academyBriefs(inputs: inputs, history: [], now: date(), limit: 2)
            .first { $0.undertakingID == wanted.id })
        inputs.bleedPrintHistory = [record(report)]
        let before = inputs.undertakingSerial
        let scene = try XCTUnwrap(GossipSimulationBuilder.undertakingCandidate(inputs: inputs, now: date(10, 12)))
        XCTAssertEqual(scene.payload.metadata[GossipSimulationBuilder.undertakingKey], wanted.id)
        XCTAssertEqual(scene.payload.metadata[GossipSimulationBuilder.undertakingStageIndexKey], "0")
        XCTAssertTrue(scene.payload.body.contains("‘This comma was not here,’"))
        XCTAssertEqual(inputs.undertakingSerial, before)
        XCTAssertEqual(inputs.castUndertakings.last?.stageIndex, 1)
        inputs.undertakingSerial.met(undertakingID: wanted.id, stageIndex: 0, at: date(10, 12))
        XCTAssertNil(GossipSimulationBuilder.undertakingCandidate(inputs: inputs, now: date(10, 18)))
    }

    func testExistingEncounteredThreadStillOwnsItsContinuation() {
        let wanted = business("paper-case")
        let followed = business("followed-case")
        var serial = UndertakingSerial()
        serial.met(undertakingID: followed.id, stageIndex: 0, at: date(9))
        var current = followed
        current.stageIndex = 1
        let next = UndertakingSerialEngine.nextBeat(among: [wanted, current], serial: serial,
            slotID: "today", now: date(), preferredUndertakingIDs: [wanted.id])
        XCTAssertEqual(next?.id, followed.id)
        XCTAssertEqual(next?.stageIndex, 1)
    }

    func testKeptNewspaperDoesNotBecomeItsOwnDuplicateFictionButPreservesReaderInk() throws {
        let report = BleedColumnBrief(id: "monthly-pulse", title: "Academy", byline: "Penny", composedBody: "The stair moved.",
            packet: "", maxTokens: 0, storyID: "pulse:one", worldFactID: "world-event:test:pulse:one")
        let paper = BookPage(id: "kept-paper", type: .theBleed, createdAt: date(), promptText: "Morning paper",
            userInput: "The stair moved.\n\nMargin note: I fixed the blue gate today.", origin: .generated,
            metadata: [BleedPrintRecord.metadataKey: record(report).encoded])
        var today = day()
        today.pages = [paper]
        let plan = BraidScenePlanBuilder.plan(for: today, calendar: calendar)
        XCTAssertFalse(plan.evidence.contains { $0.pageID == paper.id && $0.kind == .keptFiction })
        XCTAssertTrue(plan.evidence.contains { $0.pageID == paper.id && $0.text.contains("blue gate") && $0.kind == .writtenLine })
    }

    func testWorldCoordinationFieldsSurvivePrintRecordEncodingAndOldRecords() throws {
        var inputs = BookSourceInputs.empty
        inputs.activeWorldEvents = [try event()]
        let pulse = try XCTUnwrap(BleedNewsroom.monthlyBrief(kind: .morning, day: day(), inputs: inputs,
            history: [], now: date(), calendar: calendar))
        let decoded = try XCTUnwrap(BleedPrintRecord.decode(record(pulse).encoded))
        XCTAssertEqual(decoded.items.first?.worldFactID, pulse.worldFactID)
        XCTAssertEqual(decoded.items.first?.worldEventRunID, pulse.worldEventRunID)
        let legacy = BleedPrintRecord.decode(#"{"slotID":"old","printedAt":0,"items":[{"storyID":"old","revision":"old","title":"Old","body":"Old","sourcePageIDs":[]}]}"#)
        XCTAssertNil(legacy?.items.first?.worldFactID)
    }
}
