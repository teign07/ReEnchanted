import XCTest
@testable import InsideCoverCore

/// The Book arranging a day instead of waiting for one.
///
/// Everything else in the grimoire watches. This is the only part that acts,
/// which makes it the only part that can be unfair — so most of what is
/// asserted here is about restraint: it tests one thing at a time, it never
/// counts a day the reader skipped against them, and it says the result out
/// loud when it was wrong.
final class GrimoireExperimentTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private let recipes = ["book-stolen-opening", "trencher-open-table"]

    private func feature(_ id: String, _ domain: String, role: LoomFeatureRole) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: id,
            conditionClause: "a \(id) was set", outcomeClause: "you wrote about \(id)",
            role: role, provenance: .systemEvent
        )
    }

    /// A ledger holding one rule the Book could actually arrange a day for.
    private func ledger(
        state: GrimoireClaimState = .standing,
        hits: Int = 12,
        recipe: String = "book-stolen-opening",
        outcomeOn outcomeDays: [Int]? = nil
    ) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        let condition = feature("working:\(recipe)", "working", role: .either)
        let outcome = feature("word:steady", "word", role: .outcomeOnly)
        // Every day is in the universe, including the ones nothing happened on.
        // A rule needs days it did *not* hold on or there is nothing to
        // contrast it against, and the Book will not commit to it.
        let ambient = feature("hour:evening", "hour", role: .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<80 {
            var features: [LoomFeatureRef] = [ambient]
            let set = day % 6 == 0
            if set { features.append(condition) }
            // Background: the word turns up on a few days of its own, so the
            // rule is strong rather than suspiciously perfect. None of these
            // fall in 79...82, which is the window the "missed" test needs
            // clear.
            let wroteIt = outcomeDays.map { $0.contains(day) } ?? (set || day % 11 == 3)
            if wroteIt { features.append(outcome) }
            observations.append(LoomObservation(
                id: "day-\(day)", day: day,
                occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "page-\(day)", evidenceLine: ""
            ))
        }
        ledger.ingest(observations)
        var passes = 0
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        while !ledger.sweep(now: now, budget: 2_000, calendar: calendar).finished, passes < 200 {
            passes += 1
        }
        // Put the rule into the state under test, said out loud.
        let subjects = ledger.rows.values
            .filter { $0.conditionID == condition.id && $0.outcomeID == outcome.id }
            .map(\.id)
        for id in subjects {
            ledger.markSpoken(id, now: now, calendar: calendar)
            ledger.rows[id]?.state = state
            let peak = ledger.rows[id]?.strengthPeak ?? 0
            ledger.rows[id]?.strengthPeak = max(peak, 80)
        }
        _ = hits
        return ledger
    }

    private func candidateRow(_ ledger: GrimoireLedger) -> GrimoireCorrespondence? {
        ledger.experimentCandidate(
            arrangeableRecipeIDs: recipes,
            now: GrimoireDay.date(for: 81, calendar: calendar),
            calendar: calendar
        )?.row
    }

    // MARK: Choosing

    func testAConditionTheBookCannotCauseIsNotTestable() {
        XCTAssertNil(GrimoireLedger.arrangeableRecipe(of: "weather:rain"))
        XCTAssertEqual(GrimoireLedger.arrangeableRecipe(of: "working:book-stolen-opening"),
                       "book-stolen-opening")
    }

    func testItPicksARuleItCanActuallyArrangeADayFor() throws {
        let found = try XCTUnwrap(candidateRow(ledger()), "nothing was testable")
        XCTAssertEqual(found.conditionID, "working:book-stolen-opening")
    }

    func testARecipeTheAppCannotOfferIsNeverChosen() {
        let picked = ledger().experimentCandidate(
            arrangeableRecipeIDs: ["some-other-errand"],
            now: GrimoireDay.date(for: 81, calendar: calendar), calendar: calendar
        )
        XCTAssertNil(picked, "it asked for a Working that does not exist")
    }

    func testARuleTheBookHasNotSaidOutLoudIsNotTested() {
        var subject = ledger()
        for id in subject.rows.keys.sorted() {
            subject.rows[id]?.state = .watching
            subject.rows[id]?.lastSpokenAt = nil
        }
        XCTAssertNil(candidateRow(subject))
    }

    func testAShutReadingIsNeverTested() {
        var subject = ledger()
        for id in subject.rows.keys.sorted() { subject.rows[id]?.state = .forbidden }
        XCTAssertNil(candidateRow(subject))
    }

    func testThinEvidenceIsNotWorthAnErrand() {
        // Two hits: still counting, not yet worth spending a day of the
        // reader's life on.
        let thin = ledger(outcomeOn: [0, 6])
        if let found = candidateRow(thin) {
            let stats = thin.currentStats(for: found, calendar: calendar)
            XCTAssertGreaterThanOrEqual(stats?.inHits ?? 0, GrimoireLedger.ExperimentBars.minimumHits)
        }
    }

    // MARK: Committing

    func testThePredictionIsWrittenDownBeforeAnythingHappens() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try XCTUnwrap(subject.experimentCandidate(
            arrangeableRecipeIDs: recipes, now: now, calendar: calendar
        ))
        subject.beginExperiment(
            row: pick.row, recipeID: pick.recipeID, outcomeID: pick.outcomeID,
            workingID: "working-1", now: now, calendar: calendar
        )
        let running = try XCTUnwrap(subject.runningExperiment)
        XCTAssertEqual(running.verdict, .waiting)
        XCTAssertFalse(running.prediction.isEmpty, "it committed to nothing")
        // The prediction must name the thing that could be wrong, not gesture
        // at it — that is the whole point of writing it down first.
        let outcome = try XCTUnwrap(subject.ref(running.outcomeID))
        XCTAssertTrue(running.prediction.contains(outcome.outcomeClause), running.prediction)
        // Setting a test is the Book saying the rule, so the rest window starts.
        XCTAssertNotNil(subject.rows[pick.row.id]?.lastSpokenAt)
    }

    func testItRunsOneTestAtATime() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try XCTUnwrap(subject.experimentCandidate(
            arrangeableRecipeIDs: recipes, now: now, calendar: calendar
        ))
        subject.beginExperiment(row: pick.row, recipeID: pick.recipeID,
                                outcomeID: pick.outcomeID, workingID: "w1", now: now, calendar: calendar)
        XCTAssertFalse(subject.mayRunAnExperiment(now: now))
        subject.beginExperiment(row: pick.row, recipeID: pick.recipeID,
                                outcomeID: pick.outcomeID, workingID: "w2", now: now, calendar: calendar)
        XCTAssertEqual(subject.experiments.count, 1, "it started a second test on top of the first")
    }

    func testItRestsBetweenTests() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try XCTUnwrap(subject.experimentCandidate(
            arrangeableRecipeIDs: recipes, now: now, calendar: calendar
        ))
        subject.beginExperiment(row: pick.row, recipeID: pick.recipeID,
                                outcomeID: pick.outcomeID, workingID: "w1", now: now, calendar: calendar)
        _ = subject.settleExperiment(wentOn: 81, abandoned: false, now: now, calendar: calendar)
        XCTAssertFalse(subject.mayRunAnExperiment(now: now), "it went straight into another one")
        let later = now.addingTimeInterval(Double(GrimoireLedger.ExperimentBars.restDays) * 86_400)
        XCTAssertTrue(subject.mayRunAnExperiment(now: later))
    }

    // MARK: Reading the answer

    private func started(
        _ subject: inout GrimoireLedger, at now: Date
    ) throws -> (row: GrimoireCorrespondence, outcomeID: String) {
        let pick = try XCTUnwrap(subject.experimentCandidate(
            arrangeableRecipeIDs: recipes, now: now, calendar: calendar
        ))
        subject.beginExperiment(row: pick.row, recipeID: pick.recipeID,
                                outcomeID: pick.outcomeID, workingID: "w1", now: now, calendar: calendar)
        return (pick.row, pick.outcomeID)
    }

    func testWhenTheThingFollowsTheBookSaysItKnew() throws {
        // The outcome lands on day 78, inside the window after going on 78.
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try started(&subject, at: now)
        let settled = try XCTUnwrap(
            subject.settleExperiment(wentOn: 78, abandoned: false, now: now, calendar: calendar)
        )
        XCTAssertEqual(settled.verdict, .held)
        let line = GrimoireVoice.experimentResult(
            settled, row: try XCTUnwrap(subject.rows[pick.row.id]), ledger: subject, calendar: calendar
        )
        XCTAssertTrue(line.contains("on purpose"), line)
    }

    func testWhenItDoesNotFollowTheBookTakesItsCertaintyBack() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try started(&subject, at: now)
        XCTAssertEqual(subject.rows[pick.row.id]?.state, .standing)
        // Day 79 has no outcome anywhere in its window.
        let settled = try XCTUnwrap(
            subject.settleExperiment(wentOn: 79, abandoned: false, now: now, calendar: calendar)
        )
        XCTAssertEqual(settled.verdict, .missed)
        XCTAssertEqual(subject.rows[pick.row.id]?.state, .spoken,
                       "it stayed sure of a rule its own test just failed")
        // Kept, not thrown away: one arranged day is not proof of a negative.
        XCTAssertEqual(subject.rows[pick.row.id]?.isAlive, true)
        let line = GrimoireVoice.experimentResult(
            settled, row: try XCTUnwrap(subject.rows[pick.row.id]), ledger: subject, calendar: calendar
        )
        XCTAssertTrue(line.contains("I was wrong"), line)
    }

    /// The one that matters most: not going is not a failure.
    func testAReaderWhoNeverWentIsNeverCountedAgainstTheRule() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try started(&subject, at: now)
        let before = subject.rows[pick.row.id]?.state
        let settled = try XCTUnwrap(
            subject.settleExperiment(wentOn: nil, abandoned: true, now: now, calendar: calendar)
        )
        XCTAssertEqual(settled.verdict, .unanswered)
        XCTAssertEqual(subject.rows[pick.row.id]?.state, before,
                       "skipping an errand cost the reader one of the Book's convictions")
        let line = GrimoireVoice.experimentResult(
            settled, row: try XCTUnwrap(subject.rows[pick.row.id]), ledger: subject, calendar: calendar
        )
        XCTAssertTrue(line.contains("still don't know"), line)
        for blame in ["should", "you failed", "you didn't bother", "wasted"] {
            XCTAssertFalse(line.lowercased().contains(blame), "it told the reader off: \(line)")
        }
    }

    func testItWaitsBeforeCallingAnErrandUnanswered() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        _ = try started(&subject, at: now)
        XCTAssertNil(
            subject.settleExperiment(wentOn: nil, abandoned: false, now: now, calendar: calendar),
            "it gave up on the reader the same day it asked"
        )
        let late = now.addingTimeInterval(Double(GrimoireLedger.ExperimentBars.patienceDays) * 86_400)
        let settled = try XCTUnwrap(
            subject.settleExperiment(wentOn: nil, abandoned: false, now: late, calendar: calendar)
        )
        XCTAssertEqual(settled.verdict, .unanswered)
    }

    // MARK: Keeping it

    func testTheResultIsShownOnceAndThenRests() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        _ = try started(&subject, at: now)
        let settled = try XCTUnwrap(
            subject.settleExperiment(wentOn: 78, abandoned: false, now: now, calendar: calendar)
        )
        XCTAssertEqual(subject.unreportedExperiments().count, 1)
        subject.markExperimentReported(settled.id, now: now)
        XCTAssertTrue(subject.unreportedExperiments().isEmpty)
    }

    func testAnExperimentSurvivesBeingSavedAndLoaded() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        _ = try started(&subject, at: now)
        let data = try JSONEncoder().encode(subject)
        let restored = try JSONDecoder().decode(GrimoireLedger.self, from: data)
        XCTAssertEqual(restored.runningExperiment?.prediction, subject.runningExperiment?.prediction)
        XCTAssertEqual(restored.experiments.count, 1)
    }

    /// A ledger written before experiments existed must still open.
    func testAnOlderSaveOpensWithNoExperiments() throws {
        var subject = ledger()
        subject.experiments = []
        let data = try JSONEncoder().encode(subject)
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: "experiments")
        let trimmed = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(GrimoireLedger.self, from: trimmed)
        XCTAssertTrue(restored.experiments.isEmpty)
    }

    /// Whatever it says, it says in the Book's own mouth.
    func testEveryThingItSaysIsInVoice() throws {
        var subject = ledger()
        let now = GrimoireDay.date(for: 81, calendar: calendar)
        let pick = try started(&subject, at: now)
        let row = try XCTUnwrap(subject.rows[pick.row.id])
        var lines = [
            GrimoireVoice.prediction(row: row, ledger: subject, calendar: calendar),
            GrimoireVoice.experimentSummons(row: row, ledger: subject, calendar: calendar)
        ]
        for verdict in [GrimoireExperiment.Verdict.held, .missed, .unanswered] {
            var experiment = try XCTUnwrap(subject.runningExperiment)
            experiment.verdict = verdict
            lines.append(GrimoireVoice.experimentResult(
                experiment, row: row, ledger: subject, calendar: calendar
            ))
            lines.append(GrimoireVoice.experimentTitle(experiment))
        }
        for line in lines {
            XCTAssertFalse(line.isEmpty)
            for clerical in ["data", "correlat", "statistic", "metric", "hypothes", "variable"] {
                XCTAssertFalse(line.lowercased().contains(clerical), "clerical voice: \(line)")
            }
            for hedge in ["may ", "perhaps", "possibly", "tends to", "appears to"] {
                XCTAssertFalse(line.lowercased().contains(hedge), "hedged: \(line)")
            }
            for mark in [" ,", " .", "  "] {
                XCTAssertFalse(line.contains(mark), "“\(mark)” in: \(line)")
            }
        }
    }
}

/// The test reaching the reader.
///
/// A Book that runs experiments in private is just a Book with opinions. The
/// point is that it commits out loud and then reports, so these check that
/// both Pages arrive, that neither repeats forever, and that having shown the
/// setting-up never counts as having shown the answer.
final class GrimoireExperimentSurfaceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private var now: Date { GrimoireDay.date(for: 81, calendar: calendar) }

    private func feature(_ id: String, _ domain: String, _ role: LoomFeatureRole) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: id,
            conditionClause: "a \(id) was set", outcomeClause: "you wrote about \(id)",
            role: role, provenance: .systemEvent
        )
    }

    private func running() -> GrimoireLedger {
        var ledger = GrimoireLedger()
        let condition = feature("working:book-stolen-opening", "working", .either)
        let outcome = feature("word:steady", "word", .outcomeOnly)
        let ambient = feature("hour:evening", "hour", .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<80 {
            var features = [ambient]
            let set = day % 6 == 0
            if set { features.append(condition) }
            if set || day % 11 == 3 { features.append(outcome) }
            observations.append(LoomObservation(
                id: "d\(day)", day: day,
                occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "p\(day)", evidenceLine: ""
            ))
        }
        ledger.ingest(observations)
        var passes = 0
        while !ledger.sweep(now: now, budget: 2_000, calendar: calendar).finished, passes < 200 {
            passes += 1
        }
        for id in ledger.rows.keys.sorted() where ledger.rows[id]?.conditionID == condition.id {
            ledger.markSpoken(id, now: now, calendar: calendar)
            ledger.rows[id]?.state = .standing
        }
        if let pick = ledger.experimentCandidate(
            arrangeableRecipeIDs: ["book-stolen-opening"], now: now, calendar: calendar
        ) {
            ledger.beginExperiment(
                row: pick.row, recipeID: pick.recipeID, outcomeID: pick.outcomeID,
                workingID: "w1", now: now, calendar: calendar
            )
        }
        return ledger
    }

    private func pages(_ ledger: GrimoireLedger) -> [SurfacePage] {
        var inputs = BookSourceInputs()
        inputs.grimoire = ledger
        let day = BookDay(id: "2026-09-03", date: now, pages: [])
        return GrimoirePageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day, recentDays: []),
            inputs: inputs, now: now
        )
    }

    func testTheBookExplainsItselfBeforeTheErrand() throws {
        let ledger = running()
        let page = try XCTUnwrap(pages(ledger).first, "it set a test and said nothing")
        let running = try XCTUnwrap(ledger.runningExperiment)
        XCTAssertEqual(page.payload.headline, GrimoireVoice.experimentTitle(running))
        XCTAssertNotNil(page.payload.metadata["grimoireExperimentID"])
        // The prediction is on the Page, so the reader holds the receipt.
        XCTAssertFalse(page.detail.isEmpty)
        XCTAssertTrue(page.payload.body.contains(page.detail), "the prediction never reached the Page")
    }

    /// While a test is out, the reader must not be asked to confirm the rule —
    /// that would be the Book collecting its own result.
    func testItDoesNotAskTheReaderToGradeAnOpenTest() throws {
        let page = try XCTUnwrap(pages(running()).first)
        XCTAssertEqual(page.payload.metadata["adaptiveActions"], "")
    }

    func testTheSettingUpIsShownOnceAndThenStops() throws {
        var ledger = running()
        let page = try XCTUnwrap(pages(ledger).first)
        ledger = try XCTUnwrap(GrimoireLedger.speaking(page, in: ledger, now: now))
        let repeated = pages(ledger).first
        XCTAssertNotEqual(repeated?.payload.headline, "I Am Trying Something",
                          "it announced the same test twice")
    }

    /// The one that would have been a silent bug: showing the set-up must not
    /// consume the reader's right to hear the answer.
    func testHavingShownTheSetUpDoesNotConsumeTheResult() throws {
        var ledger = running()
        let announced = try XCTUnwrap(pages(ledger).first)
        ledger = try XCTUnwrap(GrimoireLedger.speaking(announced, in: ledger, now: now))
        XCTAssertTrue(ledger.unreportedExperiments().isEmpty, "not settled yet")

        _ = ledger.settleExperiment(wentOn: 78, abandoned: false, now: now, calendar: calendar)
        XCTAssertEqual(ledger.unreportedExperiments().count, 1,
                       "the answer was swallowed by having announced the question")
        let result = try XCTUnwrap(pages(ledger).first)
        let held = try XCTUnwrap(ledger.experiments.first)
        XCTAssertEqual(held.verdict, .held)
        XCTAssertEqual(result.payload.headline, GrimoireVoice.experimentTitle(held))
    }

    func testItReportsBeingWrongJustAsLoudly() throws {
        var ledger = running()
        _ = ledger.settleExperiment(wentOn: 79, abandoned: false, now: now, calendar: calendar)
        let page = try XCTUnwrap(pages(ledger).first)
        let missed = try XCTUnwrap(ledger.experiments.first)
        XCTAssertEqual(missed.verdict, .missed)
        XCTAssertEqual(page.payload.headline, GrimoireVoice.experimentTitle(missed))
        // Louder, in fact: a retraction outranks anything new it has to say.
        XCTAssertGreaterThanOrEqual(page.score, 80)
        XCTAssertTrue(page.payload.body.contains("I was wrong"), page.payload.body)
    }

    func testAResultIsShownOnceAndThenRests() throws {
        var ledger = running()
        _ = ledger.settleExperiment(wentOn: 79, abandoned: false, now: now, calendar: calendar)
        let page = try XCTUnwrap(pages(ledger).first)
        ledger = try XCTUnwrap(GrimoireLedger.speaking(page, in: ledger, now: now))
        XCTAssertTrue(ledger.unreportedExperiments().isEmpty)
        let again = pages(ledger).first
        XCTAssertNotEqual(again?.payload.metadata["grimoireExperimentID"], page.payload.metadata["grimoireExperimentID"])
    }

    /// A reading the reader shut stays shut, tests included.
    func testAShutReadingNeverSurfacesATest() {
        var ledger = running()
        _ = ledger.settleExperiment(wentOn: 79, abandoned: false, now: now, calendar: calendar)
        var inputs = BookSourceInputs()
        inputs.grimoire = ledger
        inputs.bookReadingBoundaries = ledger.experiments.map {
            BookReadingBoundary(id: $0.rowID, createdAt: now)
        }
        let day = BookDay(id: "2026-09-03", date: now, pages: [])
        let found = GrimoirePageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day, recentDays: []),
            inputs: inputs, now: now
        )
        XCTAssertTrue(found.allSatisfy { $0.payload.metadata["grimoireExperimentID"] == nil })
    }
}
