import XCTest
@testable import InsideCoverCore

/// Phase 2 of the permanent twin: the Daybook posted to baselines, deltas,
/// streaks, marks, and the two private trends.
///
/// The properties these guard are the ones the whole thing rests on: that the
/// reader is measured against their own usual and never a population's, that
/// nothing is read below its evidence gate, and that none of it can be spoken.
final class StandingLedgerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    /// A row `daysAgo` before `now`, with an optional sleep reading.
    private func row(
        daysAgo: Int,
        fidelity: DaybookEntry.Fidelity = .live,
        sleep: Double? = nil,
        kept: Int = 0,
        aliveness: Int? = nil,
        rut: Int? = nil,
        mayNameRut: Bool? = nil,
        place: String? = nil,
        pageTypes: [String] = []
    ) -> DaybookEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        var entry = DaybookEntry(
            dayID: DaybookRecorder.dayID(for: date, calendar: calendar),
            date: date,
            fidelity: fidelity,
            calendar: calendar,
            writtenAt: date
        )
        entry.sleepHours = sleep
        entry.keptPageCount = kept
        entry.keptPageTypes = pageTypes
        entry.alivenessScore = aliveness
        entry.rutPressure = rut
        entry.rutMayName = mayNameRut
        entry.placeLabel = place
        return entry
    }

    /// `count` days of history, oldest first, all with the same sleep reading.
    private func steadyHistory(count: Int, sleep: Double) -> [DaybookEntry] {
        (1...count).reversed().map { row(daysAgo: $0, sleep: sleep) }
    }

    // MARK: - Tenure gate

    func testLedgerStaysQuietBeforeItHasTenure() {
        let ledger = StandingLedgerBuilder.build(
            entries: steadyHistory(count: 10, sleep: 7),
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(ledger.isReady)
        // Bands are refused entirely until the Ledger has standing.
        XCTAssertNil(ledger.band(.sleepHours))
        XCTAssertNil(ledger.streak(.sleepHours))
    }

    func testLedgerBecomesReadyAtTheTenureFloor() {
        let ledger = StandingLedgerBuilder.build(
            entries: steadyHistory(count: 24, sleep: 7),
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(ledger.isReady)
        XCTAssertEqual(ledger.tenureDays, 24)
    }

    // MARK: - Baselines are the reader's own

    func testBaselineIsTheReadersOwnMedianNotAPopulationNorm() {
        // Someone who reliably sleeps five hours. Five is *their* usual, and a
        // five-hour night must not read as a deficit.
        var entries = steadyHistory(count: 24, sleep: 5)
        entries.append(row(daysAgo: 0, sleep: 5))

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.baseline(.sleepHours)?.median, 5)
        XCTAssertEqual(ledger.band(.sleepHours), .usual)
    }

    func testADeviationFromTheReadersOwnUsualIsBanded() {
        // A varied but centred history, then a night far below it.
        var entries: [DaybookEntry] = []
        for day in (1...24).reversed() {
            entries.append(row(daysAgo: day, sleep: day % 2 == 0 ? 7.5 : 6.5))
        }
        entries.append(row(daysAgo: 0, sleep: 3.0))

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.band(.sleepHours), .wellBelow)
    }

    func testAFlatFieldStillRegistersItsFirstMove() {
        // Zero spread: the first departure from a flat line must not be
        // swallowed as "usual" by a division that never happens.
        var entries = steadyHistory(count: 24, sleep: 7)
        entries.append(row(daysAgo: 0, sleep: 9))

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.baseline(.sleepHours)?.medianAbsoluteDeviation, 0)
        XCTAssertEqual(ledger.band(.sleepHours), .above)
    }

    // MARK: - Evidence gates

    func testADeltaIsRefusedBelowItsSampleGate() {
        // Long tenure, but only a handful of nights actually recorded.
        var entries = (1...30).reversed().map { row(daysAgo: $0) }
        entries.append(row(daysAgo: 2, sleep: 7))
        entries.append(row(daysAgo: 1, sleep: 7))
        entries.append(row(daysAgo: 0, sleep: 3))

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertTrue(ledger.isReady)
        // The baseline exists but is not trustworthy, so no band is handed out.
        XCTAssertNotNil(ledger.baseline(.sleepHours))
        XCTAssertEqual(ledger.baseline(.sleepHours)?.isTrustworthy, false)
        XCTAssertNil(ledger.band(.sleepHours))
    }

    func testAbsentDaysContributeNothingToBodyFieldsButDoCountPages() {
        let entries = [
            row(daysAgo: 3, sleep: 8, kept: 2),
            row(daysAgo: 2, fidelity: .absent),
            row(daysAgo: 1, fidelity: .absent),
            row(daysAgo: 0, sleep: 8, kept: 1)
        ]

        // A week away must not teach the Book that the reader sleeps zero hours.
        XCTAssertEqual(StandingLedgerBuilder.values(.sleepHours, in: entries), [8, 8])
        // But it is real evidence about how many pages were kept.
        XCTAssertEqual(StandingLedgerBuilder.values(.keptPageCount, in: entries), [2, 0, 0, 1])
    }

    // MARK: - Streaks

    func testStreakCountsConsecutiveDaysOnOneSideOfTheMedian() {
        var entries: [DaybookEntry] = []
        for day in (5...28).reversed() {
            entries.append(row(daysAgo: day, sleep: day % 2 == 0 ? 8 : 6))
        }
        // Then four short nights running.
        for day in (0...4).reversed() {
            entries.append(row(daysAgo: day, sleep: 4))
        }

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)
        let streak = ledger.streak(.sleepHours)

        XCTAssertEqual(streak?.length, 5)
        XCTAssertEqual(streak?.isAbove, false)
    }

    func testASingleDayIsNotAStreak() {
        var entries = steadyHistory(count: 24, sleep: 7)
        entries.append(row(daysAgo: 0, sleep: 3))

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertNil(ledger.streak(.sleepHours))
    }

    // MARK: - Marks

    func testMarksCountDaysSinceThingsLastHappened() {
        let entries = [
            row(daysAgo: 40, kept: 1, place: "the kitchen table", pageTypes: ["diary"]),
            row(daysAgo: 12, kept: 1, place: "Home", pageTypes: ["mood"]),
            row(daysAgo: 0)
        ]

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.mark(.daysSincePlace, subject: "the kitchen table")?.days, 40)
        XCTAssertEqual(ledger.mark(.daysSincePageType, subject: "diary")?.days, 40)
        XCTAssertEqual(ledger.mark(.daysSinceKeptPage)?.days, 12)
    }

    // MARK: - The Rut trajectory

    func testRutTrajectoryReadsTheStepsWithoutWideningPermission() {
        var entries: [DaybookEntry] = []
        for day in (20...40).reversed() {
            entries.append(row(daysAgo: day, rut: 3, mayNameRut: true))
        }
        for day in (0...19).reversed() {
            entries.append(row(daysAgo: day, rut: 1, mayNameRut: true))
        }

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.rut.direction, .easing)
        XCTAssertEqual(ledger.rut.currentPressure, 1)
        XCTAssertEqual(ledger.rut.pressureThirtyDaysAgo, 3)
        XCTAssertEqual(ledger.rut.daysAtCurrentLevel, 20)
    }

    func testRutTrajectoryNeverGrantsTheStandingToNameIt() {
        // A deepening rut with no reader report behind it. The trajectory may
        // read the change; it may not hand out permission to speak.
        var entries: [DaybookEntry] = []
        for day in (20...40).reversed() {
            entries.append(row(daysAgo: day, rut: 1, mayNameRut: false))
        }
        for day in (0...19).reversed() {
            entries.append(row(daysAgo: day, rut: 3, mayNameRut: false))
        }

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.rut.direction, .deepening)
        XCTAssertFalse(ledger.rut.mayName)
    }

    func testRutTrajectoryIsUnwrittenWithoutEnoughSteps() {
        let entries = [row(daysAgo: 1, rut: 2), row(daysAgo: 0, rut: 2)]

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.rut.direction, .notEnoughEvidence)
        XCTAssertEqual(ledger.rut.currentPressure, 2)
    }

    // MARK: - The aliveness trend

    func testAlivenessTrendReadsBrighteningAcrossTheWindow() {
        var entries: [DaybookEntry] = []
        for day in (15...27).reversed() {
            entries.append(row(daysAgo: day, aliveness: 3))
        }
        for day in (0...13).reversed() {
            entries.append(row(daysAgo: day, aliveness: 7))
        }

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.aliveness.direction, .brightening)
        XCTAssertFalse(ledger.aliveness.isThin)
    }

    func testAlivenessTrendReportsItsOwnThinnessRatherThanGuessing() {
        // Twenty-eight days of rows, three of them answered. The denominator is
        // the whole window, which is the point of reading it off the Daybook.
        var entries = (0...27).reversed().map { row(daysAgo: $0) }
        entries[0].alivenessScore = 8
        entries[1].alivenessScore = 8

        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(ledger.aliveness.direction, .notEnoughEvidence)
        XCTAssertTrue(ledger.aliveness.isThin)
        XCTAssertEqual(ledger.aliveness.windowDays, 28)
        XCTAssertEqual(ledger.aliveness.answeredDays, 2)
    }

    func testAlivenessCoverageCountsUnansweredDaysAgainstConfidence() {
        // The *same eight answers* against two different denominators. Eight
        // answers on eight days the Book saw is a firmer claim than the same
        // eight scattered through four weeks of unanswered ones, which is the
        // whole reason for reading the trend off the Daybook rather than off
        // the pulse ledger.
        let dense = (0...7).reversed().map { row(daysAgo: $0, aliveness: 6) }

        var sparse = dense
        sparse.append(contentsOf: (8...27).reversed().map { row(daysAgo: $0) })

        let denseLedger = StandingLedgerBuilder.build(entries: dense, now: now, calendar: calendar)
        let sparseLedger = StandingLedgerBuilder.build(entries: sparse, now: now, calendar: calendar)

        XCTAssertEqual(denseLedger.aliveness.answeredDays, sparseLedger.aliveness.answeredDays)
        XCTAssertEqual(denseLedger.aliveness.windowDays, 8)
        XCTAssertEqual(sparseLedger.aliveness.windowDays, 28)
        XCTAssertGreaterThan(
            denseLedger.aliveness.confidence,
            sparseLedger.aliveness.confidence
        )
    }

    // MARK: - It cannot speak

    func testNoLedgerTypeCanRenderItselfIntoProse() {
        // The enforcement is structural: these types carry no prose, so a page
        // that wanted to show a number would have to add the means to do it.
        // `String(describing:)` on a struct with no CustomStringConvertible
        // yields the synthesized dump, which is not a sentence and would be
        // obvious in any surface it reached.
        XCTAssertFalse(StandingLedger.unwritten is any CustomStringConvertible)
        XCTAssertFalse(RutTrajectory.unwritten is any CustomStringConvertible)
        XCTAssertFalse(AlivenessTrend.unwritten is any CustomStringConvertible)
        XCTAssertFalse(StandingBand.usual is any CustomStringConvertible)
    }

    // MARK: - The gates

    private func gates(
        aliveness: AlivenessTrend.Direction = .holding,
        thin: Bool = false,
        rut: RutTrajectory.Direction = .standing,
        lean: InferredLean = .neutral,
        ready: Bool = true
    ) -> TwinCurationGates {
        var ledger = StandingLedger.unwritten
        ledger.tenureDays = ready ? 40 : 3
        ledger.aliveness = AlivenessTrend(
            direction: aliveness,
            answeredDays: thin ? 1 : 12,
            windowDays: 28,
            confidence: thin ? 8 : 70
        )
        ledger.rut = RutTrajectory(
            direction: rut,
            currentPressure: 1,
            pressureThirtyDaysAgo: 1,
            daysAtCurrentLevel: 5,
            mayName: false
        )
        let signals = InferredReaderSignals(
            signals: lean == .neutral ? [] : [
                InferredSignal(
                    measure: .specificity,
                    lean: lean,
                    strength: 2,
                    recentSampleCount: 12,
                    priorSampleCount: 12
                ),
                InferredSignal(
                    measure: .variety,
                    lean: lean,
                    strength: 2,
                    recentSampleCount: 12,
                    priorSampleCount: 12
                )
            ],
            computedAt: now,
            isReady: true
        )
        return TwinCurationGates.resolve(ledger: ledger, signals: signals)
    }

    func testGatesStayNeutralUntilTheLedgerIsReady() {
        let early = gates(aliveness: .dimming, lean: .rutward, ready: false)

        XCTAssertEqual(early, .neutral)
        XCTAssertEqual(early.claimCeiling, .established)
        XCTAssertEqual(early.interruptionLean, .neutral)
    }

    func testAClaimCeilingComesDownOnADarkWeek() {
        XCTAssertEqual(gates().claimCeiling, .established)
        // One lane dark lowers it a step.
        XCTAssertEqual(gates(aliveness: .dimming).claimCeiling, .gathering)
        XCTAssertEqual(gates(lean: .rutward).claimCeiling, .gathering)
        XCTAssertEqual(gates(rut: .deepening).claimCeiling, .gathering)
        // Both lanes agreeing takes the Book back to pointing, not concluding.
        XCTAssertEqual(gates(aliveness: .dimming, lean: .rutward).claimCeiling, .glimmer)
    }

    func testACeilingOnlyEverLowersAClaim() {
        // Evidence proposes; the ceiling disposes: downward only.
        XCTAssertEqual(BookClaimTier.established.capped(by: .gathering), .gathering)
        XCTAssertEqual(BookClaimTier.glimmer.capped(by: .established), .glimmer)
        XCTAssertEqual(BookClaimTier.gathering.capped(by: .gathering), .gathering)
    }

    func testAThinAlivenessTrendIsNotTreatedAsDimming() {
        // One answer in four weeks is not evidence of a dark month; it is a
        // reason to ask. The ceiling must not come down on almost no data.
        let sparse = gates(aliveness: .dimming, thin: true)

        XCTAssertEqual(sparse.claimCeiling, .established)
        XCTAssertTrue(sparse.wantsPulseAnswer)
        XCTAssertGreaterThan(sparse.pulseScoreBoost, 0)
    }

    func testInterruptionsNarrowToTheEveningWhenLeaningRutward() {
        XCTAssertEqual(gates(aliveness: .dimming).interruptionLean, .rutward)
        XCTAssertEqual(gates().interruptionLean, .neutral)

        // The morning knock is the one given up; the evening ember stays.
        XCTAssertEqual(BookInterruptionBudget.narrowed(.both, lean: .rutward), .evening)
        XCTAssertEqual(BookInterruptionBudget.narrowed(.both, lean: .neutral), .both)
        // A reader who only asked for mornings keeps their morning.
        XCTAssertEqual(BookInterruptionBudget.narrowed(.morning, lean: .rutward), .morning)
        // And the Book never goes fully silent from this gate.
        XCTAssertEqual(BookInterruptionBudget.narrowed(.evening, lean: .rutward), .evening)
        XCTAssertEqual(BookInterruptionBudget.narrowed(.inside, lean: .rutward), .inside)
    }

    func testNarrowingDropsTheMorningWindowFromAPlan() {
        let morning = BookInterruptionCandidate(
            id: "m", dayID: "2026-08-05", window: .morning, kind: .ordinary
        )
        let evening = BookInterruptionCandidate(
            id: "e", dayID: "2026-08-05", window: .evening, kind: .ordinary
        )

        let open = BookInterruptionBudget.plan(
            candidates: [morning, evening], cadence: .both, lean: .neutral
        )
        let narrowed = BookInterruptionBudget.plan(
            candidates: [morning, evening], cadence: .both, lean: .rutward
        )

        XCTAssertEqual(open.winners.map(\.id), ["e", "m"])
        XCTAssertEqual(narrowed.winners.map(\.id), ["e"])
    }

    // MARK: - Round trip

    func testLedgerSurvivesAVaultRoundTrip() throws {
        var entries = steadyHistory(count: 24, sleep: 7)
        entries.append(row(daysAgo: 0, sleep: 3, kept: 2, aliveness: 5, rut: 2))
        let ledger = StandingLedgerBuilder.build(entries: entries, now: now, calendar: calendar)

        let data = try JSONEncoder().encode(ledger)
        let decoded = try JSONDecoder().decode(StandingLedger.self, from: data)

        XCTAssertEqual(decoded, ledger)
        XCTAssertEqual(decoded.version, StandingLedger.currentVersion)
    }

    func testAnEmptyDaybookPostsAnUnwrittenLedger() {
        let ledger = StandingLedgerBuilder.build(entries: [], now: now, calendar: calendar)

        XCTAssertEqual(ledger, .unwritten)
        XCTAssertFalse(ledger.isReady)
    }
}
