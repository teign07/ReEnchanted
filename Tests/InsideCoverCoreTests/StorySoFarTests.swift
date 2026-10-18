import XCTest
@testable import InsideCoverCore

/// The month's story keeps going without the reader, so the Book can tell it
/// as it stands: once to someone who arrives partway, again to someone who's
/// been away, and on request. The ladder is authored; none of it is generated.
final class StorySoFarTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func event() throws -> (packID: String, event: WorldEvent) {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let pack = try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json"))
        )
        return (pack.id, try XCTUnwrap(pack.events.first))
    }

    private func rungs() throws -> [WorldEventCatchUpRung] {
        try XCTUnwrap(try event().event.catchUp).sorted { $0.fromDay < $1.fromDay }
    }

    // MARK: The ladder

    func testTheLadderStartsOnDayOneAndIsShortAndAnswersNothing() throws {
        let ladder = try rungs()
        XCTAssertEqual(ladder.first?.fromDay, 0)
        XCTAssertEqual(Set(ladder.map(\.id)).count, ladder.count)
        for rung in ladder {
            XCTAssertLessThanOrEqual(rung.body.split(whereSeparator: \.isWhitespace).count, 165, rung.id)
            XCTAssertNotNil(rung.openQuestion?.nonEmpty, rung.id)
            XCTAssertNotNil(rung.title.nonEmpty, rung.id)
        }
    }

    func testNoRungGivesAwayWhatOpensAfterIt() throws {
        // The earliest live day each fact may be told.
        let facts: [String: Int] = [
            "crossed out": 8, "Thursday": 8, "East Stacks are closed": 8, "East Stacks are shut": 8,
            "harbours": 14, "toast crusts": 14,
            "Old Reading Room": 17, "finished man": 17,
            "castle": 22, "drawbridge": 22, "nursery": 22, "stair": 22,
            "Nightbound": 28, "Not today": 29,
            "crooked": 31, "Burrow": 31
        ]
        for rung in try rungs() {
            for (fact, day) in facts where rung.fromDay < day {
                XCTAssertFalse(
                    rung.body.localizedCaseInsensitiveContains(fact),
                    "\(rung.id) (day \(rung.fromDay)) tells '\(fact)', which isn't true to tell before day \(day)"
                )
            }
        }
    }

    func testTheLadderTellsWhatHappenedAndNeverNamesWhatItIs() throws {
        for rung in try rungs() {
            let text = (rung.title + " " + rung.body + " " + (rung.openQuestion ?? "")).lowercased()
            for word in ["triangle", "romance", "romantic", "love interest", "rival", "suitor", "crush", "in love"] {
                XCTAssertFalse(text.contains(word), "\(rung.id) names it: \(word)")
            }
        }
    }

    func testTheLadderKeepsTheBooksVoice() throws {
        for rung in try rungs() {
            let text = rung.body
            let lower = text.lowercased()
            for banned in ["hinge", "ritual", "as an ai"] {
                XCTAssertFalse(lower.contains(banned), "\(banned) in \(rung.id)")
            }
            XCTAssertNil(text.range(of: #", which\b"#, options: .regularExpression), rung.id)
            XCTAssertNil(lower.range(of: #"\bnot\b[^.]{0,40}\bbut\b"#, options: .regularExpression), rung.id)
            for stiff in [" do not ", " cannot ", " it is ", " she is ", " he is ", " that is "] {
                XCTAssertFalse(lower.contains(stiff), "\(stiff) in \(rung.id)")
            }
            for hands in ["my hand", "i hold", "i pick", "i reach"] {
                XCTAssertFalse(lower.contains(hands), "the Book has no hands: \(rung.id)")
            }
        }
    }

    func testTheRightRungForTheDay() throws {
        let e = try event().event
        func id(_ day: Int?, _ stage: WorldEventLifecycleStage) -> String? {
            e.catchUpRung(liveDay: day, stage: stage)?.id.replacingOccurrences(of: "count-unbound.catchup.", with: "")
        }
        XCTAssertEqual(id(0, .live), "0")
        XCTAssertEqual(id(3, .live), "0")
        XCTAssertEqual(id(4, .live), "1")
        XCTAssertEqual(id(7, .live), "1")
        XCTAssertEqual(id(8, .live), "2")
        XCTAssertEqual(id(16, .live), "3")
        XCTAssertEqual(id(17, .live), "4")
        XCTAssertEqual(id(25, .live), "5")
        XCTAssertEqual(id(28, .live), "6")
        XCTAssertEqual(id(29, .live), "7")
        XCTAssertEqual(id(30, .live), "7")
        XCTAssertEqual(id(nil, .residue), "8")
        XCTAssertNil(id(nil, .foreshadow))
        XCTAssertNil(id(nil, .sealed))
    }

    // MARK: The dated record

    func testTheLadderNeverLeadsTheDatedRecord() throws {
        let e = try event().event
        XCTAssertEqual(WorldEventCatchUpAudit.problems(in: e), [])
    }

    func testEveryRecordEntryIsDatedAndNothingIsPublicBeforeItHappens() throws {
        let entries = try XCTUnwrap(try event().event.record?.entries)
        XCTAssertGreaterThanOrEqual(entries.count, 13)
        for entry in entries {
            XCTAssertNotNil(entry.onDay, entry.id)
            XCTAssertGreaterThanOrEqual(entry.publicFromDay ?? -1, entry.onDay ?? 99, entry.id)
        }
    }

    func testTheAuditCatchesALadderThatSpoils() throws {
        var e = try event().event
        var ladder = try XCTUnwrap(e.catchUp)
        // Day 4 telling the day-8 attack.
        ladder[1].tells = (ladder[1].tells ?? []) + ["count-unbound.record.living-claim"]
        e.catchUp = ladder
        XCTAssertTrue(WorldEventCatchUpAudit.problems(in: e).contains { $0.contains("living-claim") })
        ladder[1].tells = ["count-unbound.record.nope"]
        e.catchUp = ladder
        XCTAssertTrue(WorldEventCatchUpAudit.problems(in: e).contains { $0.contains("unknown entry") })
        ladder[1].tells = []
        e.catchUp = ladder
        XCTAssertTrue(WorldEventCatchUpAudit.problems(in: e).contains { $0.contains("no record entry") })
    }

    func testTheEditionDatesTheRecordByWhenItHappened() throws {
        let (packID, e) = try event()
        let november = date(11, 1)
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: packID, event: e, now: november, calendar: calendar))
        let record = WorldEventRecordBuilder.build(
            packID: packID, event: e, snapshot: snapshot, ledger: .empty, outcome: nil)
        let section = MonthlyEditionBuilder.worldRecordSection(
            from: [record], start: date(10, 1), end: date(10, 31), calendar: calendar)
        let bird = try XCTUnwrap(section.items.first { $0.id.hasSuffix("count-unbound.record.paper-bird") })
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(bird.date)), 3, "day 2 of the run is October 3")
    }

    // MARK: The Pages

    func testAReaderWhoArrivesPartwayGetsTheStoryAsItStands() throws {
        let events = [try event()]
        let day = BookDay(id: "d", date: date(10, 10), pages: [])
        let page = try XCTUnwrap(StorySoFarPageSourceAdapter.onboardingSurface(
            for: day, inputs: .empty, now: date(10, 10), events: events
        ))
        XCTAssertEqual(page.sourceID, StorySoFarPageSourceAdapter.onboardingSourceID)
        XCTAssertEqual(page.payload.metadata["firstRunStep"], "story-so-far")
        XCTAssertEqual(page.payload.headline, "The East Stacks Are Shut")
        XCTAssertTrue(page.payload.body.contains("partway"))
        XCTAssertTrue(page.payload.body.contains("What I'd like to know:"))
    }

    func testOnDayOneTheBookSetsTheTableInsteadOfApologisingForBeingLate() throws {
        let events = [try event()]
        let day = BookDay(id: "d", date: date(10, 1), pages: [])
        let page = try XCTUnwrap(StorySoFarPageSourceAdapter.onboardingSurface(
            for: day, inputs: .empty, now: date(10, 1), events: events
        ))
        XCTAssertTrue(page.payload.body.hasPrefix("A new story starts this month"))
    }

    func testNothingIsToldBeforeOrAfterTheRun() throws {
        let events = [try event()]
        let early = BookDay(id: "d", date: date(9, 1), pages: [])
        XCTAssertNil(StorySoFarPageSourceAdapter.onboardingSurface(for: early, inputs: .empty, now: date(9, 1), events: events))
        let late = BookDay(id: "d", date: date(12, 15), pages: [])
        XCTAssertNil(StorySoFarPageSourceAdapter.onboardingSurface(for: late, inputs: .empty, now: date(12, 15), events: events))
    }

    func testAReaderWhoAlreadyMetTheStoryIsNotToldItAgain() throws {
        let e = try event()
        var inputs = BookSourceInputs.empty
        var ledger = AuthoredContentReceiptLedger.empty
        ledger.receipts.append(AuthoredContentReceipt(
            contentID: "count-unbound.scene.chair-first",
            occurrenceID: "x",
            channel: .storyScene,
            scope: AuthoredContentScope(scopeID: "count-unbound-2026-10", runID: "count-unbound:2026", phaseID: nil),
            state: .delivered,
            recordedAt: date(10, 2)
        ))
        inputs.authoredContentReceipts = ledger
        let day = BookDay(id: "d", date: date(10, 10), pages: [])
        XCTAssertNil(StorySoFarPageSourceAdapter.onboardingSurface(for: day, inputs: inputs, now: date(10, 10), events: [e]))
    }

    func testRadioAloneDoesNotCountAsHavingMetTheStory() throws {
        let e = try event()
        var inputs = BookSourceInputs.empty
        var ledger = AuthoredContentReceiptLedger.empty
        ledger.receipts.append(AuthoredContentReceipt(
            contentID: "count-unbound.radio.x",
            occurrenceID: "x",
            channel: .radioBanter,
            scope: AuthoredContentScope(scopeID: "count-unbound-2026-10", runID: "count-unbound:2026", phaseID: nil),
            state: .played,
            recordedAt: date(10, 2)
        ))
        inputs.authoredContentReceipts = ledger
        let day = BookDay(id: "d", date: date(10, 10), pages: [])
        XCTAssertNotNil(StorySoFarPageSourceAdapter.onboardingSurface(for: day, inputs: inputs, now: date(10, 10), events: [e]))
    }

    func testTheOnboardingStepIsPartOfTheSequence() {
        XCTAssertTrue(FirstRunPageSequence.stepEngagementKeys.contains(
            "source:\(StorySoFarPageSourceAdapter.onboardingSourceID)"
        ))
    }

    // MARK: Coming back

    private func keptDay(daysAgo: Int, now: Date) -> BookDay {
        let when = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        return BookDay(id: "k\(daysAgo)", date: when, pages: [
            BookPage(type: .souvenir, createdAt: when, promptText: "x", userInput: "kept")
        ])
    }

    func testTheBookOffersTheCatchUpAfterAFewDaysAway() {
        let now = date(10, 20)
        var inputs = BookSourceInputs.empty
        inputs.days = [keptDay(daysAgo: 5, now: now)]
        XCTAssertTrue(StorySoFarPageSourceAdapter.isDueForReturn(inputs: inputs, now: now, calendar: calendar))
        inputs.days = [keptDay(daysAgo: 2, now: now)]
        XCTAssertFalse(StorySoFarPageSourceAdapter.isDueForReturn(inputs: inputs, now: now, calendar: calendar))
        inputs.days = []
        XCTAssertFalse(StorySoFarPageSourceAdapter.isDueForReturn(inputs: inputs, now: now, calendar: calendar))
    }

    func testTheCatchUpRestsForAWeek() {
        let now = date(10, 20)
        var inputs = BookSourceInputs.empty
        inputs.days = [keptDay(daysAgo: 6, now: now)]
        inputs.surfaceHistory["source:\(StorySoFarPageSourceAdapter.returnSourceID)"] = SurfaceHistoryRecord(
            lastShownAt: calendar.date(byAdding: .day, value: -3, to: now)!, recentShowCount: 1
        )
        XCTAssertFalse(StorySoFarPageSourceAdapter.isDueForReturn(inputs: inputs, now: now, calendar: calendar))
        inputs.surfaceHistory["source:\(StorySoFarPageSourceAdapter.returnSourceID)"] = SurfaceHistoryRecord(
            lastShownAt: calendar.date(byAdding: .day, value: -9, to: now)!, recentShowCount: 1
        )
        XCTAssertTrue(StorySoFarPageSourceAdapter.isDueForReturn(inputs: inputs, now: now, calendar: calendar))
    }

    func testTheReturnPageIsNotAFirstRunStep() throws {
        let e = try event()
        let standing = try XCTUnwrap(StorySoFarPageSourceAdapter.standing(
            now: date(10, 20), events: [e], calendar: calendar
        ))
        let page = StorySoFarPageSourceAdapter.surface(for: standing, variant: .returning, score: 68)
        XCTAssertNil(page.payload.metadata["firstRunStep"])
        XCTAssertTrue(page.payload.body.hasPrefix("You've been away a few days."))
        XCTAssertEqual(page.sourceID, StorySoFarPageSourceAdapter.returnSourceID)
    }
}
