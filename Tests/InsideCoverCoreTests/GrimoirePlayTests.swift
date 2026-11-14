import XCTest
@testable import InsideCoverCore

/// Spells, playful missions and Wicker's dares in the grimoire: as things a
/// rule can be about, and as the thing the Book arranges to test a rule.
/// Everything starts from kept Pages and goes through the real projection.
final class GrimoirePlayTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func at(_ index: Int, hour: Int = 10) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: GrimoireDay.date(for: index, calendar: calendar))!
    }

    private func bookDay(_ index: Int, _ pages: [BookPage]) -> BookDay {
        let date = at(index)
        return BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: pages)
    }

    private func diary(_ index: Int, place: String = "Work") -> BookPage {
        let date = at(index)
        return BookPage(
            id: "diary-\(index)", type: .diary, createdAt: date,
            promptText: "Prompt", userInput: "Walked the long way past the allotments.",
            tags: [], origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar, locationLabel: place)
        )
    }

    private func mission(_ index: Int, mode: PlayfulMissionMode = .perform, place: String = "Harbour") -> BookPage {
        let date = at(index, hour: 16)
        var page = BookPage(
            id: "mission-\(index)", type: .wonderCompass, createdAt: date,
            promptText: "Interview the floor.", userInput: "It said nothing, which is an answer.",
            tags: ["playful-mission", "play-mode:\(mode.rawValue)", "entity:pippa-pilcrow"],
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar, locationLabel: place)
        )
        page.livedQuestReceipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "interview-the-floor", title: "Interview The Floor",
            invitation: "Interview the floor.", proofPrompt: "What did it say?", facets: [],
            sourceTags: ["play-mode:\(mode.rawValue)"], hasWrittenProof: true, hasVisualProof: false,
            completedAt: date, wasPromptedByBook: true
        )
        return page
    }

    private func dare(_ index: Int) -> BookPage {
        let date = at(index, hour: 12)
        var page = BookPage(
            id: "dare-\(index)", type: .wickerDare, createdAt: date,
            promptText: "Lose a staring contest to a pigeon.", userInput: "The pigeon won.",
            tags: ["entity:wicker-eddies"], origin: .userAuthored
        )
        page.livedQuestReceipt = LivedQuestReceipt(
            kind: .wickerDare, questID: "pigeon", title: "The Staring Contest",
            invitation: "Lose a staring contest.", proofPrompt: "Who blinked?", facets: [],
            sourceTags: [], hasWrittenProof: true, hasVisualProof: false,
            completedAt: date, wasPromptedByBook: true
        )
        return page
    }

    private func observe(_ days: [BookDay]) -> [LoomObservation] {
        GrimoireProjection.observations(from: GrimoireSlice(days: days, calendar: calendar))
    }

    private func swept(_ days: [BookDay], at day: Int = 61) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.reconcile(observe(days), now: at(day))
        var passes = 0
        while true {
            let report = ledger.sweep(now: at(day), budget: 900, calendar: calendar)
            passes += 1
            if report.finished || passes > 80 { break }
        }
        return ledger
    }

    /// Every third day the reader does a show-off mission at the harbour.
    private func harbourMissionDays(through last: Int = 60) -> [BookDay] {
        (0..<last).map { index in
            index % 3 == 0 ? bookDay(index, [mission(index)]) : bookDay(index, [diary(index)])
        }
    }

    // MARK: Things a rule can be about

    func testWhatTheReaderCastAndDidBecomesFeatures() throws {
        let spell = try XCTUnwrap(SpellRegistry.all.first { $0.trigger == nil })
        let cast = BookPage(
            id: "cast", type: .spell, createdAt: at(2), promptText: "p", userInput: "Done, and the kettle agreed.",
            tags: ["spell:\(spell.id)"], origin: .userAuthored
        )
        let ids = Set(observe([bookDay(2, [cast, mission(2), dare(2)])]).flatMap(\.features).map(\.id))
        XCTAssertTrue(ids.contains("spell:\(spell.id)"))
        XCTAssertTrue(ids.contains("spell-kind:\(spell.mechanic.rawValue)"))
        XCTAssertTrue(ids.contains("mission:interview-the-floor"))
        XCTAssertTrue(ids.contains("mission-mode:perform"))
        XCTAssertTrue(ids.contains("dare:any"))
        XCTAssertTrue(ids.contains("dare:pigeon"))
    }

    func testASpellNobodyAnsweredWasNotCast() throws {
        let spell = try XCTUnwrap(SpellRegistry.all.first { $0.trigger == nil })
        let offered = BookPage(
            id: "offered", type: .spell, createdAt: at(2), promptText: "p", userInput: "",
            tags: ["spell:\(spell.id)"]
        )
        let ids = Set(observe([bookDay(2, [offered])]).flatMap(\.features).map(\.id))
        XCTAssertFalse(ids.contains("spell:\(spell.id)"))
    }

    func testAMissionKindCanBeARuleAboutWhereTheReaderGoes() {
        let ledger = swept(harbourMissionDays())
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "mission-mode:perform", outcome: "place:harbour")
        XCTAssertNotNil(ledger.row(id), "show-off missions at the harbour never became a rule")
    }

    func testAMissionNeverExplainsItsOwnPageOrHost() {
        let ledger = swept(harbourMissionDays())
        let explained = ledger.rows.values.filter { row in
            let pair = [row.conditionID, row.outcomeID ?? ""]
            let isPlay = pair.contains { $0.hasPrefix("mission") }
            let isLeaf = pair.contains { $0.hasPrefix("cast:") || $0.hasPrefix("kept:") || $0.hasPrefix("word:") }
            return (row.shape == .conditional || row.shape == .sibling) && isPlay && isLeaf
        }
        XCTAssertTrue(explained.isEmpty, "a mission explained its own Page: \(explained.map(\.id))")
    }

    // MARK: The Book arranging one to test a rule

    private func ledgerRunningAMissionTest() throws -> GrimoireLedger {
        var ledger = swept(harbourMissionDays())
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "mission-mode:perform", outcome: "place:harbour")
        ledger.markSpoken(id, now: at(40), calendar: calendar)
        let play = try XCTUnwrap(ledger.experimentCandidate(
            arrangeableCauses: GrimoireArrangement.playCauses(), now: at(61), calendar: calendar
        ))
        XCTAssertEqual(play.causeID, "mission-mode:perform")
        ledger.beginExperiment(row: play.row, causeID: play.causeID, outcomeID: play.outcomeID, now: at(61), calendar: calendar)
        XCTAssertEqual(ledger.runningExperiment?.cause, "mission-mode:perform")
        return ledger
    }

    func testTheDeskHandsOutTheArrangedKindOfMission() throws {
        var inputs = BookSourceInputs.empty
        inputs.grimoire = try ledgerRunningAMissionTest()
        let handed = PlayfulMissionRegistry.mission(for: bookDay(61, []), inputs: inputs, now: at(61))
        XCTAssertEqual(handed.playMode, .perform)
        XCTAssertEqual(GrimoireArrangement.arrangedCause(inputs.grimoire), "mission-mode:perform")
    }

    func testATestSurvivesTheRebuildAndSettlesFromTheArchive() throws {
        var ledger = try ledgerRunningAMissionTest()
        // The reader does a show-off mission the next day, at the harbour.
        let days = harbourMissionDays() + [bookDay(62, [mission(62)])]
        ledger.reconcile(observe(days), now: at(63))
        XCTAssertNotNil(ledger.runningExperiment, "the six-hourly rebuild threw the test away")
        let settled = try XCTUnwrap(ledger.settleArrangedExperiment(now: at(63), calendar: calendar))
        XCTAssertEqual(settled.verdict, .held)
        XCTAssertEqual(settled.openedOn, 62)
        XCTAssertTrue(ledger.bookAskedDays.contains(62), "the arranged day must not judge a promise")
        XCTAssertEqual(ledger.unreportedExperiments().first?.id, settled.id)
        // And it stays put through the next rebuild too.
        ledger.reconcile(observe(days), now: at(64))
        XCTAssertEqual(ledger.unreportedExperiments().first?.id, settled.id)
        XCTAssertTrue(ledger.bookAskedDays.contains(62))
    }

    /// No 21-day rest for play tests: the next may start as soon as the last
    /// result has been shown. Only the same rule rests, for a fortnight.
    func testPlayTestsArePacedByTheResultNotTheCalendar() throws {
        var ledger = try ledgerRunningAMissionTest()
        let days = harbourMissionDays() + [bookDay(62, [mission(62)])]
        ledger.reconcile(observe(days), now: at(63))
        let settled = try XCTUnwrap(ledger.settleArrangedExperiment(now: at(63), calendar: calendar))
        XCTAssertFalse(ledger.mayRunAPlayExperiment(now: at(63)), "started a new test before showing the last result")
        ledger.markExperimentReported(settled.id, now: at(63))
        XCTAssertTrue(ledger.mayRunAPlayExperiment(now: at(64)), "a play test waited on a calendar rest")
        let causes = GrimoireArrangement.playCauses()
        XCTAssertNil(ledger.experimentCandidate(arrangeableCauses: causes, now: at(64), calendar: calendar),
                     "the same rule was tested again straight away")
        XCTAssertNotNil(ledger.experimentCandidate(arrangeableCauses: causes, now: at(76), calendar: calendar))
        // A result the desk never found room for stops holding things up.
        var unshown = try ledgerRunningAMissionTest()
        unshown.reconcile(observe(days), now: at(63))
        _ = unshown.settleArrangedExperiment(now: at(63), calendar: calendar)
        XCTAssertTrue(unshown.mayRunAPlayExperiment(now: at(71)))
        // A Working test still rests, and only after another Working test.
        XCTAssertTrue(unshown.mayRunAnExperiment(now: at(64)))
    }

    func testAMissIsOnlyCalledOnceTheWindowHasPassed() throws {
        var ledger = try ledgerRunningAMissionTest()
        // Done, but at work this time: the rule said the harbour.
        let days = harbourMissionDays() + [bookDay(62, [mission(62, place: "Work")])]
        ledger.reconcile(observe(days), now: at(62))
        XCTAssertNil(ledger.settleArrangedExperiment(now: at(63), calendar: calendar), "called a miss mid-window")
        let settled = try XCTUnwrap(ledger.settleArrangedExperiment(now: at(66), calendar: calendar))
        XCTAssertEqual(settled.verdict, .missed)
    }
}
