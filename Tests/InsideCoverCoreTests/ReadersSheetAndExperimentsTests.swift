import XCTest
@testable import InsideCoverCore

/// Phases 4 and 5: who the reader is in the story, and the Book acting on a
/// belief about them.
///
/// The Sheet's tests are mostly about what does *not* reach a prompt. The
/// experiment tests are mostly about consent and about the Book not being
/// allowed to mark its own homework.
final class ReadersSheetAndExperimentsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    // MARK: - The Reader's Sheet

    private func inputsWithAStory() -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        var story = ReaderStory.empty
        story.shadowPermission = .knowButNeverWrite
        story.openThreads = [
            OpenThread(
                id: "t1",
                line: "The harbour keeps coming back.",
                shelf: .light,
                openedAt: now,
                lastTouchedAt: now,
                movement: .began,
                sourcePageID: nil,
                touchCount: 2,
                closedAt: nil
            )
        ]
        inputs.readerStory = story
        inputs.relationshipField = [
            "pippa": RelationshipTie(warmth: 30, tension: 0, familiarity: 20),
            "mook": RelationshipTie(warmth: 8, tension: 2, familiarity: 5)
        ]
        var ledger = StandingLedger.unwritten
        ledger.tenureDays = 90
        ledger.rut = RutTrajectory(
            direction: .standing,
            currentPressure: 2,
            pressureThirtyDaysAgo: 2,
            daysAtCurrentLevel: 12,
            mayName: true
        )
        inputs.standingLedger = ledger
        inputs.readerBeliefScore = 61
        return inputs
    }

    func testTheSheetGathersWhatWasScatteredAcrossTheInputs() {
        let sheet = ReadersSheetBuilder.build(inputs: inputsWithAStory(), now: now)

        XCTAssertEqual(sheet.tenureDays, 90)
        XCTAssertEqual(sheet.beliefScore, 61)
        XCTAssertEqual(sheet.openThreads.count, 1)
        XCTAssertEqual(sheet.shadowPermission, .knowButNeverWrite)
        // Warmest bond first.
        XCTAssertEqual(sheet.closestBonds.first?.entityID, "pippa")
    }

    func testTheShadowRuleLeadsThePromptBecauseItIsACeilingOnEverythingElse() {
        let sheet = ReadersSheetBuilder.build(inputs: inputsWithAStory(), now: now)
        let prompt = sheet.promptSection

        XCTAssertTrue(prompt.hasPrefix(ReaderStory.ShadowPermission.knowButNeverWrite.promptLine))
    }

    func testNoTwinNumberEverReachesThePrompt() {
        // The Sheet holds belief, tenure, and the Rut band because callers in
        // the curation layer want them. None of it is material for a page, and
        // a number in a prompt is a number one sentence away from the reader.
        let sheet = ReadersSheetBuilder.build(inputs: inputsWithAStory(), now: now)
        let prompt = sheet.promptSection

        XCTAssertFalse(prompt.contains("61"))
        XCTAssertFalse(prompt.contains("90"))
        XCTAssertFalse(prompt.lowercased().contains("rut"))
        XCTAssertFalse(prompt.lowercased().contains("pressure"))
        XCTAssertFalse(prompt.lowercased().contains("score"))
    }

    func testPeopleCarryTheWitnessLawIntoThePrompt() {
        var inputs = inputsWithAStory()
        var people = PeopleLedger()
        people.threads = [
            PersonThread(
                id: "person:marcus",
                name: "Marcus",
                introducedDay: "2026-07-01",
                readerWords: "My brother.",
                firstMentionDay: "2026-07-01",
                lastMentionDay: "2026-08-01",
                mentionPageCount: 4,
                castMemberID: "cast-marcus"
            ),
            // Never written in, so never named to the brain.
            PersonThread(
                id: "person:ana",
                name: "Ana",
                introducedDay: "2026-07-02",
                readerWords: "A colleague.",
                firstMentionDay: "2026-07-02",
                lastMentionDay: "2026-07-02",
                mentionPageCount: 1
            )
        ]
        inputs.people = people

        let prompt = ReadersSheetBuilder.build(inputs: inputs, now: now).promptSection

        XCTAssertTrue(prompt.contains("Marcus"))
        XCTAssertFalse(prompt.contains("Ana"))
        XCTAssertTrue(prompt.contains("Never voice them"))
    }

    func testARestedPersonThreadIsNotNamed() {
        var inputs = inputsWithAStory()
        var people = PeopleLedger()
        var thread = PersonThread(
            id: "person:marcus",
            name: "Marcus",
            introducedDay: "2026-07-01",
            readerWords: "My brother.",
            firstMentionDay: "2026-07-01",
            lastMentionDay: "2026-08-01",
            mentionPageCount: 4,
            castMemberID: "cast-marcus"
        )
        thread.resting = true
        people.threads = [thread]
        inputs.people = people

        XCTAssertFalse(
            ReadersSheetBuilder.build(inputs: inputs, now: now).promptSection.contains("Marcus")
        )
    }

    func testAnEmptySheetIsNotWorthHandingToTheBrain() {
        let empty = ReadersSheetBuilder.build(inputs: .empty, now: now)

        XCTAssertFalse(empty.isWorthSpeakingTo)
    }

    // MARK: - Experiments: consent

    private func liveExperiment(
        condition: String = "after:sleep:long",
        attempts: Int = 0,
        lastArranged: Date? = nil,
        borneOut: Int = 0,
        contradicted: Int = 0
    ) -> TwinExperiment {
        TwinExperiment(
            id: "twin-experiment:\(condition)",
            conditionFeatureID: condition,
            beliefKey: "\(condition)->writing:kept",
            standing: .proposed,
            proposedAt: now,
            lastArrangedAt: lastArranged,
            attempts: attempts,
            borneOutCount: borneOut,
            contradictedCount: contradicted
        )
    }

    private func yesterdayWithLongSleep() -> DaybookEntry {
        let date = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        var entry = DaybookEntry(
            dayID: DaybookRecorder.dayID(for: date, calendar: calendar),
            date: date,
            fidelity: .live,
            calendar: calendar,
            writtenAt: date
        )
        entry.sleepHours = 10
        entry.keptPageCount = 1
        return entry
    }

    private func readyStanding() -> StandingLedger {
        var ledger = StandingLedger.unwritten
        ledger.tenureDays = 90
        ledger.baselines = [
            StandingBaseline(
                field: .sleepHours,
                window: StandingGate.shortWindow,
                median: 7,
                medianAbsoluteDeviation: 1,
                sampleCount: 20
            )
        ]
        return ledger
    }

    private var grantedAuthority: BookWorkingAuthority {
        var authority = BookWorkingAuthority.sealed
        authority.isEnabled = true
        authority.grantedAt = now
        return authority
    }

    func testNothingIsArrangedWithoutTheReadersWorkingsGrant() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment())

        // The authority is sealed by default, and arranging conditions for
        // someone is exactly the kind of real-world act it exists to gate.
        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: .sealed,
                distressActive: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testAPausedGrantStopsArrangingImmediately() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment())
        var paused = grantedAuthority
        paused.pausedUntil = now.addingTimeInterval(86_400)

        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: paused,
                distressActive: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testDistressStopsArranging() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment())

        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: grantedAuthority,
                distressActive: true,
                now: now,
                calendar: calendar
            )
        )
    }

    // MARK: - Experiments: the loop

    func testAnExperimentIsArrangedWhenYesterdaysConditionsArrived() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment(condition: "after:sleep:long"))

        let chosen = TwinExperimenter.arrangeable(
            ledger: ledger,
            yesterday: yesterdayWithLongSleep(),
            standing: readyStanding(),
            authority: grantedAuthority,
            distressActive: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(chosen?.conditionFeatureID, "after:sleep:long")
    }

    func testNothingIsArrangedWhenTheConditionsDidNotArrive() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment(condition: "after:sleep:short"))

        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: grantedAuthority,
                distressActive: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testAnExperimentRestsBetweenAttempts() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(
            liveExperiment(attempts: 1, lastArranged: calendar.date(byAdding: .day, value: -2, to: now))
        )

        // An experiment that runs every day is not an experiment; it is a
        // schedule the reader never agreed to.
        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: grantedAuthority,
                distressActive: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testOnlyTwoBeliefsAreHeldAtOnce() {
        var existing = TwinExperimentLedger.empty
        existing.upsert(liveExperiment(condition: "after:sleep:long"))
        existing.upsert(liveExperiment(condition: "after:tempo:open"))

        let proposals = TwinExperimenter.propose(
            from: [],
            existing: existing,
            now: now
        )

        XCTAssertTrue(proposals.isEmpty)
    }

    // MARK: - Experiments: the Book does not mark its own homework

    func testAVerdictIsJudgedAgainstTheReadersOwnBaseline() {
        var ledger = TwinExperimentLedger.empty
        let experiment = liveExperiment()
        ledger.upsert(experiment)

        // A reader whose usual delayed-outcome answer is 8, answering 6. That
        // is a decline, and an absolute threshold of 6 would call it a win.
        TwinExperimenter.recordOutcome(
            experimentID: experiment.id,
            score: 6,
            baseline: 8,
            in: &ledger
        )

        XCTAssertEqual(ledger.experiment(id: experiment.id)?.standing, .contradicted)
    }

    func testALowScoringReaderImprovingCountsAsBorneOut() {
        var ledger = TwinExperimentLedger.empty
        let experiment = liveExperiment()
        ledger.upsert(experiment)

        // Usual is 3, answered 5. That is an improvement, and an absolute bar
        // of 6 would call it a failure.
        TwinExperimenter.recordOutcome(
            experimentID: experiment.id,
            score: 5,
            baseline: 3,
            in: &ledger
        )

        XCTAssertEqual(ledger.experiment(id: experiment.id)?.standing, .borneOut)
    }

    func testABeliefIsAbandonedAfterEnoughContradiction() {
        var ledger = TwinExperimentLedger.empty
        let experiment = liveExperiment(contradicted: 2)
        ledger.upsert(experiment)

        TwinExperimenter.recordOutcome(
            experimentID: experiment.id,
            score: 1,
            baseline: 6,
            in: &ledger
        )

        XCTAssertEqual(ledger.experiment(id: experiment.id)?.standing, .abandoned)
        XCTAssertTrue(ledger.experiment(id: experiment.id)!.isSpent)
    }

    func testASpentBeliefIsNeverArrangedForAgain() {
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment(contradicted: 3))

        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: grantedAuthority,
                distressActive: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testAnEstablishedBeliefStopsBeingTested() {
        // Once it is reliable there is nothing left to learn, and continuing to
        // test it would just be the Book arranging the reader's days for them.
        var ledger = TwinExperimentLedger.empty
        ledger.upsert(liveExperiment(borneOut: 3))

        XCTAssertNil(
            TwinExperimenter.arrangeable(
                ledger: ledger,
                yesterday: yesterdayWithLongSleep(),
                standing: readyStanding(),
                authority: grantedAuthority,
                distressActive: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testOnlyLaggedFindingsBecomeBeliefs() {
        // A same-day connection says what goes together, not what follows what,
        // and only the second is something the Book can arrange for.
        let sameDay = RelationalLoomConnection(
            id: "c1",
            observationKey: "weather:rain->writing:kept",
            headline: "You write in the rain",
            line: "You write in the rain.",
            condition: RelationalLoomFeature(
                id: "weather:rain", family: .weather, label: "Rain",
                conditionClause: "it rained", outcomeClause: "it rained",
                symbolName: "cloud.rain", carriesReaderSuppliedMeaning: false
            ),
            outcome: RelationalLoomFeature(
                id: "writing:kept", family: .writing, label: "Wrote",
                conditionClause: "you wrote", outcomeClause: "you wrote",
                symbolName: "pencil", carriesReaderSuppliedMeaning: false
            ),
            evidence: [],
            evidencePageIDs: [],
            inHits: 8, inCount: 10, outHits: 2, outCount: 10,
            evidenceTier: .established,
            strength: 90
        )

        XCTAssertTrue(
            TwinExperimenter.propose(from: [sameDay], existing: .empty, now: now).isEmpty
        )
    }
}
