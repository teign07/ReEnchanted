import XCTest
@testable import InsideCoverCore

final class PactWarTests: XCTestCase {
    private func offsets(_ pairs: [String: Int]) -> [String: Int] { pairs }

    func testTiersFromControlBelief() {
        XCTAssertEqual(PactTier.tier(forControl: 0), .none)
        XCTAssertEqual(PactTier.tier(forControl: 5), .contesting)
        XCTAssertEqual(PactTier.tier(forControl: 15), .influenced)
        XCTAssertEqual(PactTier.tier(forControl: 30), .controlled)
        XCTAssertEqual(PactTier.tier(forControl: 55), .dominated)
        XCTAssertEqual(PactTier.tier(forControl: 80), .sovereign)
    }

    func testControllerIsClearLeaderOnly() {
        var state = PactWarState()
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 20
        state.control[PactWarState.key("moss-clasp", "shelf-reflection")] = 20
        XCTAssertNil(state.controller(of: "shelf-reflection"), "a tie has no controller")
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 25
        XCTAssertEqual(state.controller(of: "shelf-reflection"), "ember-seal")
        XCTAssertEqual(state.tier(of: "shelf-reflection"), .controlled)
    }

    func testTickAdvancesTheWarAndIsGated() {
        var state = PactWarState()
        let now = Date()
        let records = PactWarEngine.tick(into: &state, entityBeliefOffsets: [:], boundTalismanID: nil, now: now)
        XCTAssertFalse(records.isEmpty, "every Talisman stirs once")
        let total = state.control.values.reduce(0, +)
        XCTAssertGreaterThan(total, 0, "control belief was placed")
        // Gated: a second tick right away does nothing.
        let again = PactWarEngine.tick(into: &state, entityBeliefOffsets: [:], boundTalismanID: nil, now: now.addingTimeInterval(60))
        XCTAssertTrue(again.isEmpty)
    }

    func testWarIsSilentUnderDistress() {
        var state = PactWarState()
        let records = PactWarEngine.tick(into: &state, entityBeliefOffsets: [:], boundTalismanID: nil, now: Date(), distressActive: true)
        XCTAssertTrue(records.isEmpty)
        XCTAssertTrue(state.control.isEmpty)
    }

    func testHomeFieldRaisesOverallBelief() {
        let plain = PactWarEngine.overallBelief(talismanID: "ember-seal", entityBeliefOffsets: [:], boundTalismanID: nil)
        let home = PactWarEngine.overallBelief(talismanID: "ember-seal", entityBeliefOffsets: [:], boundTalismanID: "ember-seal")
        XCTAssertEqual(home - plain, PactWarEngine.homeFieldBonus)
    }

    func testLowBeliefTalismanOnlyPushesAligned() {
        // Drive several daily ticks for a weak, unbound field; pushes should land
        // on aligned territories and never go negative anywhere.
        var state = PactWarState()
        var now = Date()
        for _ in 0..<6 {
            PactWarEngine.tick(into: &state, entityBeliefOffsets: [:], boundTalismanID: nil, now: now)
            now = now.addingTimeInterval(Double(PactWarEngine.tickGapHours + 1) * 3_600)
        }
        for value in state.control.values { XCTAssertGreaterThanOrEqual(value, 0) }
        // Emberheart (aligned to reflection/story/notifications) should have placed
        // belief in at least one aligned territory.
        let emberAligned = PactWarEngine.alignment["ember-seal"] ?? []
        let emberSomewhere = emberAligned.contains { state.control("ember-seal", $0) > 0 }
        XCTAssertTrue(emberSomewhere)
    }

    func testShelfBoostScalesWithTier() {
        var state = PactWarState()
        XCTAssertEqual(PactWarEffects.shelfBoost(for: .diary, state: state), 0)
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 30 // controlled
        XCTAssertEqual(PactWarEffects.shelfBoost(for: .diary, state: state), 4)
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 50 // dominated
        XCTAssertEqual(PactWarEffects.shelfBoost(for: .diary, state: state), 8)
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 75 // sovereign
        XCTAssertEqual(PactWarEffects.shelfBoost(for: .diary, state: state), 12)
    }

    func testControlledShelfGetsCuratorLift() {
        var state = PactWarState()
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 50
        var inputs = BookSourceInputs.empty
        inputs.pactWar = state
        let mood = CuratorMood.make(inputs: inputs)
        let diary = SurfacePage(
            id: "p", type: .diary, sourceID: "diary-page", intent: .capture,
            renderStyle: .promptCard, score: 50, reason: "", prompt: "", detail: "",
            payload: BookPagePayload(headline: "", body: "")
        )
        XCTAssertGreaterThanOrEqual(mood.adjustment(for: diary), 8, "a dominated shelf lifts its pages")
    }

    func testFramingReflectsControllingChapter() {
        var state = PactWarState()
        state.control[PactWarState.key("moss-clasp", "shelf-care")] = 50
        let framing = PactWarEffects.framing(for: .body, state: state)
        XCTAssertEqual(framing, AcademyChapterRegistry.chapter(id: "mossbloom")?.writeFraming)
        // An uncontrolled shelf has no framing.
        XCTAssertNil(PactWarEffects.framing(for: .narrativeOS, state: PactWarState()))
    }

    func testFramedAnnotatesCapturePagesOnControlledShelves() {
        var state = PactWarState()
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 50
        let diary = SurfacePage(
            id: "p", type: .diary, sourceID: "diary-page", intent: .capture,
            renderStyle: .promptCard, score: 50, reason: "", prompt: "Now", detail: "d",
            payload: BookPagePayload(headline: "h", body: "b")
        )
        let framed = PactWarEffects.framed(diary, state: state)
        XCTAssertEqual(framed.payload.metadata["pactTalisman"], "The Ember Seal")
        XCTAssertEqual(framed.payload.metadata["pactFraming"], AcademyChapterRegistry.chapter(id: "emberheart")?.writeFraming)
        // Non-capture pages and uncontrolled shelves are left untouched.
        let story = SurfacePage(
            id: "s", type: .narrativeOS, sourceID: "narrative-os", intent: .simulate,
            renderStyle: .promptCard, score: 50, reason: "", prompt: "x", detail: "y",
            payload: BookPagePayload(headline: "h", body: "b")
        )
        XCTAssertNil(PactWarEffects.framed(story, state: state).payload.metadata["pactFraming"])
    }

    func testFramedAnnotatesEarlyShelfStoryBeforeControl() {
        var state = PactWarState()
        state.control[PactWarState.key("moss-clasp", "shelf-care")] = 12
        let body = SurfacePage(
            id: "b", type: .body, sourceID: "body-page", intent: .reflect,
            renderStyle: .gentleTranslation, score: 50, reason: "", prompt: "p", detail: "d",
            payload: BookPagePayload(headline: "h", body: "b")
        )
        let framed = PactWarEffects.framed(body, state: state)
        XCTAssertEqual(framed.payload.metadata["pactShelfTalisman"], "The Moss Clasp")
        XCTAssertEqual(framed.payload.metadata["pactShelfTier"], PactTier.influenced.label)
        XCTAssertNotNil(framed.payload.metadata["pactShelfStory"])
        XCTAssertNil(framed.payload.metadata["pactFraming"], "early influence explains itself but does not rewrite the page yet")
    }

    func testWhisperAndHourVoicesShiftByController() {
        XCTAssertNotEqual(PactVoices.braidWhisper(controller: "ember-seal").body,
                          PactVoices.braidWhisper(controller: "moss-clasp").body)
        XCTAssertEqual(PactVoices.braidWhisper(controller: nil).title, "The Book is ready to braid")
        XCTAssertNotNil(PactVoices.hourQuestion(controller: "tide-glass", phase: "before"))
        XCTAssertNil(PactVoices.hourQuestion(controller: nil, phase: "before"))
    }

    func testSeizingATerritoryQueuesADispatch() {
        // Pre-load Mossbloom as the sitting controller, then let a strong field
        // tick; a change of hands (or a fresh seize) should queue a dispatch.
        var state = PactWarState()
        // Give Tidecrest an overwhelming, belief-heavy run at the Field shelf.
        let offsets = ["tide-glass": 60]
        var now = Date()
        var sawDispatch = false
        for _ in 0..<8 {
            PactWarEngine.tick(into: &state, entityBeliefOffsets: offsets, boundTalismanID: "tide-glass", now: now)
            if !state.pendingDispatches.isEmpty { sawDispatch = true; break }
            now = now.addingTimeInterval(Double(PactWarEngine.tickGapHours + 1) * 3_600)
        }
        XCTAssertTrue(sawDispatch, "a contested war eventually produces a dispatch")
    }

    func testSovereignDispatchFiresAtTopTier() {
        var state = PactWarState()
        // Seed Emberheart just below Sovereign on the Reflection shelf, alone.
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 66
        let before = Set(state.pendingDispatches.map(\.id))
        // A belief-heavy, unrivalled Emberheart pushes/consolidates its aligned
        // shelves; over enough daily ticks Reflection crosses into Sovereign.
        var now = Date()
        for _ in 0..<30 {
            PactWarEngine.tick(into: &state, entityBeliefOffsets: ["ember-seal": 70], boundTalismanID: "ember-seal", now: now)
            now = now.addingTimeInterval(Double(PactWarEngine.tickGapHours + 1) * 3_600)
            if state.tier(of: "shelf-reflection") == .sovereign { break }
        }
        let sovereign = state.pendingDispatches.contains {
            $0.kind == .sovereign && $0.territoryID == "shelf-reflection" && !before.contains($0.id)
        }
        XCTAssertTrue(sovereign)
        XCTAssertEqual(state.tier(of: "shelf-reflection"), .sovereign)
    }

    func testDispatchAdapterSurfacesAndIsClearedOnceKept() {
        var state = PactWarState()
        let dispatch = PactDispatch(
            id: "pact-dispatch-shelf-care-moss-clasp-seized-2026-06-13",
            territoryID: "shelf-care", talismanID: "moss-clasp", kind: .seized,
            line: "The Moss Clasp has taken The Care Shelf.", at: Date()
        )
        state.pendingDispatches = [dispatch]
        var inputs = BookSourceInputs.empty
        inputs.pactWar = state
        let day = BookDay.today()
        let adapter = PactDispatchPageSourceAdapter()

        let surfaced = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())
        XCTAssertEqual(surfaced.first?.type, .pactDispatch)
        XCTAssertEqual(surfaced.first?.payload.metadata["dispatchID"], dispatch.id)

        // Once a page carrying its tag is kept, the dispatch stops surfacing.
        let keptDay = BookDay(id: day.id, date: day.date, pages: [
            BookPage(type: .pactDispatch, promptText: "A Shelf Changes Hands", userInput: "kept",
                     tags: ["pact-dispatch", "pact-dispatch:\(dispatch.id)"])
        ])
        var keptInputs = inputs
        keptInputs.days = [keptDay]
        let after = adapter.candidates(for: keptDay, context: CuratorContext.make(for: keptDay), inputs: keptInputs, now: Date())
        XCTAssertTrue(after.isEmpty)
    }

    func testDoorEpigraphAppearsOnlyWhenDoorIsControlled() {
        var state = PactWarState()
        XCTAssertNil(PactWarEffects.doorEpigraph(for: .weather, state: state))
        state.control[PactWarState.key("tide-glass", "integ-weather")] = 30 // controlled
        let epigraph = PactWarEffects.doorEpigraph(for: .weather, state: state)
        XCTAssertNotNil(epigraph)
        XCTAssertEqual(epigraph?.talisman, "The Tide Glass")
        // A page kind with no door is never epigraphed.
        XCTAssertNil(PactWarEffects.doorEpigraph(for: .diary, state: state))
    }

    func testFramedInjectsDoorEpigraph() {
        var state = PactWarState()
        state.control[PactWarState.key("moss-clasp", "integ-health")] = 50
        let body = SurfacePage(
            id: "b", type: .body, sourceID: "body-page", intent: .reflect,
            renderStyle: .gentleTranslation, score: 50, reason: "", prompt: "p", detail: "d",
            payload: BookPagePayload(headline: "h", body: "b")
        )
        let framed = PactWarEffects.framed(body, state: state)
        XCTAssertFalse(framed.payload.metadata["pactDoorEpigraph"]?.isEmpty ?? true)
        XCTAssertEqual(framed.payload.metadata["pactDoorTalisman"], "The Moss Clasp")
    }

    func testSovereignShelfPageTypes() {
        var state = PactWarState()
        XCTAssertTrue(PactWarEffects.sovereignShelfPageTypes(state: state).isEmpty)
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 80
        let types = PactWarEffects.sovereignShelfPageTypes(state: state)
        XCTAssertTrue(types.contains(.diary))
        XCTAssertTrue(types.contains(.mood))
        XCTAssertFalse(types.contains(.body)) // a different (uncontrolled) shelf
    }

    func testNextNewMoonIsInTheFutureAndReadsNew() {
        let next = MoonPhaseCalendar.nextNewMoon(after: Date())
        XCTAssertGreaterThan(next, Date())
        XCTAssertEqual(MoonPhaseCalendar.phase(on: next).name, "New Moon")
    }

    func testSovereignWhisperVoiceShiftsByController() {
        XCTAssertNil(PactVoices.sovereignWhisper(controller: nil))
        XCTAssertNotEqual(PactVoices.sovereignWhisper(controller: "ember-seal")?.body,
                          PactVoices.sovereignWhisper(controller: "dusk-thorn")?.body)
    }

    func testVerdictAdapterSurfacesAContestedReadingOfARealPage() {
        var inputs = BookSourceInputs.empty
        inputs.pactWar = PactWarState()
        let day = BookDay(id: BookDay.today().id, date: Date(), pages: [
            BookPage(type: .diary, promptText: "Diary", userInput: "I walked to the harbor and the fog came in.")
        ])
        let adapter = PactVerdictPageSourceAdapter()
        let surfaced = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())
        XCTAssertEqual(surfaced.first?.type, .pactVerdict)
        let meta = surfaced.first?.payload.metadata
        XCTAssertEqual(meta?["territoryID"], "shelf-reflection", "a diary page is governed by the Reflection shelf")
        XCTAssertNotEqual(meta?["talismanA"], meta?["talismanB"], "two different Talismans contest the reading")
        XCTAssertFalse(meta?["readingA"]?.isEmpty ?? true)
        XCTAssertFalse(meta?["readingB"]?.isEmpty ?? true)
    }

    func testRuledPageIsNeverReAsked() {
        var inputs = BookSourceInputs.empty
        inputs.pactWar = PactWarState()
        var page = BookPage(type: .diary, promptText: "Diary", userInput: "a kept day")
        page.tags = ["pact-verdict:\(page.id)"]   // already ruled
        let day = BookDay(id: BookDay.today().id, date: Date(), pages: [page])
        let adapter = PactVerdictPageSourceAdapter()
        let after = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())
        XCTAssertTrue(after.isEmpty, "a page already ruled is never re-asked")
    }

    func testReaderVerdictAdjustClampsControl() {
        var state = PactWarState()
        state.adjust("ember-seal", "shelf-reflection", by: 6)
        XCTAssertEqual(state.control("ember-seal", "shelf-reflection"), 6)
        state.adjust("ember-seal", "shelf-reflection", by: -100)
        XCTAssertEqual(state.control("ember-seal", "shelf-reflection"), 0, "clamped at 0")
    }

    func testReaderVerdictCanSeizeATerritoryAndQueueADispatch() {
        var state = PactWarState()
        // Moss-clasp sits as a thin controller; the reader rules hard for Emberheart.
        state.control[PactWarState.key("moss-clasp", "shelf-reflection")] = 4
        let before = state
        state.adjust("ember-seal", "shelf-reflection", by: 6)   // verdict winner bump
        state.adjust("moss-clasp", "shelf-reflection", by: -2)  // loser gives a little
        let newSovereign = PactWarEngine.detectCrossings(before: before, into: &state, now: Date())
        XCTAssertFalse(newSovereign)
        XCTAssertEqual(state.controller(of: "shelf-reflection"), "ember-seal", "the reader's hand changed who holds the shelf")
        XCTAssertTrue(state.pendingDispatches.contains { $0.kind == .seized && $0.territoryID == "shelf-reflection" })
    }

    func testPactWarStateDecodesFromJSONMissingErrands() throws {
        // An older save predates `errands`; decoding must not throw and the field
        // defaults to empty while the rest survives.
        let json = """
        {"control":{"ember-seal|shelf-reflection":30},"log":[],"pendingDispatches":[]}
        """.data(using: .utf8)!
        let state = try JSONDecoder().decode(PactWarState.self, from: json)
        XCTAssertEqual(state.control("ember-seal", "shelf-reflection"), 30)
        XCTAssertTrue(state.errands.isEmpty)
        // And it round-trips cleanly with the new field present.
        let reencoded = try JSONEncoder().encode(state)
        let again = try JSONDecoder().decode(PactWarState.self, from: reencoded)
        XCTAssertEqual(again, state)
    }

    func testErrandIsOnlyOfferedFromARealFoothold() {
        var state = PactWarState()
        XCTAssertNil(PactWarEngine.offerErrand(into: &state), "no foothold, no errand")
        // Give Emberheart an Influenced foothold on the Reflection shelf.
        state.control[PactWarState.key("ember-seal", "shelf-reflection")] = 20
        let errand = PactWarEngine.offerErrand(into: &state)
        XCTAssertEqual(errand?.talismanID, "ember-seal")
        XCTAssertEqual(errand?.territoryID, "shelf-reflection")
        XCTAssertEqual(errand?.status, .owed)
        // Only one open errand at a time.
        XCTAssertNil(PactWarEngine.offerErrand(into: &state))
    }

    func testDeliverErrandGainsControlAndMarksDelivered() {
        var state = PactWarState()
        state.control[PactWarState.key("moss-clasp", "shelf-care")] = 20
        let errand = PactWarEngine.offerErrand(into: &state)!
        let before = state.control("moss-clasp", "shelf-care")
        let newSovereign = PactWarEngine.deliverErrand(errandID: errand.id, report: "I sat by the window and the rain wrote a line.", into: &state)
        XCTAssertFalse(newSovereign)
        XCTAssertEqual(state.control("moss-clasp", "shelf-care") - before, PactErrands.controlReward)
        let delivered = state.errands.first { $0.id == errand.id }
        XCTAssertEqual(delivered?.status, .delivered)
        XCTAssertFalse(delivered?.fieldReport?.isEmpty ?? true)
        XCTAssertFalse(delivered?.talismanResponse?.isEmpty ?? true)
        XCTAssertTrue(state.log.contains { $0.kind == .errand })
    }

    func testErrandLapsesAfterItsDeadline() {
        var state = PactWarState()
        state.control[PactWarState.key("tide-glass", "shelf-field")] = 20
        let now = Date()
        let errand = PactWarEngine.offerErrand(into: &state, now: now)!
        // Nothing lapses before the deadline.
        XCTAssertTrue(PactWarEngine.sweepErrandLapses(into: &state, now: now).isEmpty)
        // Well past the payment window, the owed errand lapses.
        let later = errand.deadline.addingTimeInterval(3_600)
        XCTAssertEqual(PactWarEngine.sweepErrandLapses(into: &state, now: later), [errand.id])
        XCTAssertEqual(state.openErrand, nil)
    }

    func testEveryShelfPageTypeMapsToOneShelf() {
        // No page type should sit on two shelves (avoids ambiguous boosts).
        for type in BookPageType.allCases {
            let shelves = PactTerritoryRegistry.shelves.filter { $0.pageTypes.contains(type) }
            XCTAssertLessThanOrEqual(shelves.count, 1, "\(type.rawValue) is on \(shelves.count) shelves")
        }
    }
}
