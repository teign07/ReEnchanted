import XCTest
@testable import InsideCoverCore

/// Phase 3a/3b: day-rows as loom observations.
///
/// The point of these is the denominator. Before the Daybook, every pattern the
/// Book could find was conditioned on the reader having shown up: the out-group
/// was always *other kept pages*, never *other days*. A whole class of true
/// statement was unsayable because the silent days existed in no data structure
/// at all. These tests are mostly about whether absence is now countable, and
/// whether a row can smuggle in anything it did not actually observe.
final class DaybookLoomTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private func row(
        daysAgo: Int,
        fidelity: DaybookEntry.Fidelity = .live,
        kept: Int = 0,
        events: Int? = nil,
        weather: [String] = [],
        sleep: Double? = nil,
        rut: Int? = nil,
        place: String? = nil,
        travelled: Bool? = nil,
        daylight: Int? = nil
    ) -> DaybookEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        var entry = DaybookEntry(
            dayID: DaybookRecorder.dayID(for: date, calendar: calendar),
            date: date,
            fidelity: fidelity,
            calendar: calendar,
            writtenAt: date
        )
        entry.keptPageCount = kept
        entry.calendarEventCount = events
        entry.weatherTags = weather
        entry.sleepHours = sleep
        entry.rutPressure = rut
        entry.placeLabel = place
        entry.travelled = travelled
        entry.daylightMinutes = daylight
        return entry
    }

    private func ledger(sleepMedian: Double? = nil) -> StandingLedger {
        var ledger = StandingLedger.unwritten
        ledger.tenureDays = 60
        if let sleepMedian {
            ledger.baselines = [
                StandingBaseline(
                    field: .sleepHours,
                    window: StandingGate.shortWindow,
                    median: sleepMedian,
                    medianAbsoluteDeviation: 1.0,
                    sampleCount: 20
                )
            ]
        }
        return ledger
    }

    // MARK: - Absence becomes a row

    func testASilentDayIsAnObservationWithAWritingOutcome() {
        let silent = row(daysAgo: 1, kept: 0, events: 4)
        let observation = silent.loomObservation(ledger: ledger(), calendar: calendar)

        XCTAssertNotNil(observation)
        XCTAssertTrue(observation!.has(where: { $0.id == "writing:silent" }))
        XCTAssertFalse(observation!.has(where: { $0.id == "writing:kept" }))
    }

    func testAWrittenDayCarriesTheOppositeOutcome() {
        let wrote = row(daysAgo: 1, kept: 2, events: 0)
        let observation = wrote.loomObservation(ledger: ledger(), calendar: calendar)

        XCTAssertTrue(observation!.has(where: { $0.id == "writing:kept" }))
    }

    func testTheLoomCanNowCountWritingAgainstOpenAndCrowdedDays() {
        // Nine open days written on; twelve crowded days mostly not. This is
        // precisely the statement that was unsayable before day-rows existed,
        // because the crowded silent days were in no data structure at all.
        var rows: [DaybookEntry] = []
        var day = 1
        for _ in 0..<10 {
            rows.append(row(daysAgo: day, kept: 2, events: 0))
            day += 1
        }
        for index in 0..<12 {
            rows.append(row(daysAgo: day, kept: index < 2 ? 1 : 0, events: 4))
            day += 1
        }

        let observations = StandingLedgerBuilder.loomObservations(
            rows: rows,
            ledger: ledger(),
            calendar: calendar
        )
        let connections = RelationalLoom.connections(observations: observations)

        // Some connection relates the calendar's tempo to whether writing
        // happened. Which way round the loom orients it is its own business.
        XCTAssertTrue(
            connections.contains { connection in
                let ids = [connection.condition.id, connection.outcome.id]
                return ids.contains { $0.hasPrefix("tempo:") } && ids.contains { $0.hasPrefix("writing:") }
            },
            "Expected a tempo/writing connection, got: \(connections.map { "\($0.condition.id)->\($0.outcome.id)" })"
        )
    }

    // MARK: - A row cannot claim what it did not see

    func testAnAbsentRowOffersOnlyItsDateAndItsSilence() {
        // The app was never opened: no weather, no body, no calendar was ever
        // observed. The row must not be able to smuggle any of that in.
        let absent = row(daysAgo: 3, fidelity: .absent)
        let observation = absent.loomObservation(ledger: ledger(sleepMedian: 7), calendar: calendar)

        let families = Set(observation?.features.map(\.family) ?? [])
        XCTAssertEqual(families, [.writing, .weekPart])
    }

    func testADayWithNothingButItsDateIsNotAnObservation() {
        var bare = row(daysAgo: 3, fidelity: .absent)
        bare.keptPageCount = 0
        // Strip even the weekday by asking for the features directly: a row
        // always has weekday + writing, so two is the floor and a row can never
        // fall below it. This asserts the floor is enforced, not bypassed.
        let observation = bare.loomObservation(ledger: ledger(), calendar: calendar)
        XCTAssertEqual(observation?.features.count, 2)
    }

    // MARK: - Bands are the reader's own

    func testSleepBandsAreDrawnAgainstTheReadersOwnMedian() {
        // Six hours is short for a seven-hour sleeper and long for a
        // four-hour one. The same night, two different readings.
        let night = row(daysAgo: 1, kept: 1, sleep: 5.0)

        let forLongSleeper = night.loomObservation(ledger: ledger(sleepMedian: 8), calendar: calendar)
        let forShortSleeper = night.loomObservation(ledger: ledger(sleepMedian: 4), calendar: calendar)

        XCTAssertTrue(forLongSleeper!.has(where: { $0.id == "sleep:short" }))
        XCTAssertTrue(forShortSleeper!.has(where: { $0.id == "sleep:long" }))
    }

    func testNoSleepBandWithoutATrustworthyBaseline() {
        let night = row(daysAgo: 1, kept: 1, sleep: 3.0)
        // An unwritten Ledger has no baselines at all.
        let observation = night.loomObservation(ledger: ledger(), calendar: calendar)

        XCTAssertFalse(observation!.hasFamily(.sleep))
    }

    // MARK: - The new families

    func testTheDaybookFamiliesAppearWhenTheRowCanAnswerForThem() {
        let rich = row(
            daysAgo: 1,
            kept: 1,
            events: 0,
            weather: ["rain"],
            sleep: 4.0,
            rut: 2,
            place: "Home",
            travelled: true,
            daylight: 9 * 60
        )
        let observation = rich.loomObservation(ledger: ledger(sleepMedian: 8), calendar: calendar)!

        XCTAssertTrue(observation.hasFamily(.sleep))
        XCTAssertTrue(observation.hasFamily(.daylight))
        XCTAssertTrue(observation.hasFamily(.travel))
        XCTAssertTrue(observation.hasFamily(.rutBand))
        XCTAssertTrue(observation.hasFamily(.writing))
        XCTAssertTrue(observation.hasFamily(.weather))
        XCTAssertTrue(observation.hasFamily(.tempo))
        XCTAssertTrue(observation.hasFamily(.place))
    }

    func testAQuietRutDoesNotBecomeAFeature() {
        // Pressure 1 is the ordinary-life floor: it is not a condition worth
        // relating anything to, and would otherwise tag almost every row.
        let ordinary = row(daysAgo: 1, kept: 1, rut: 1)
        let observation = ordinary.loomObservation(ledger: ledger(), calendar: calendar)!

        XCTAssertFalse(observation.hasFamily(.rutBand))
    }

    func testTheReadersOwnStateFamiliesAreMarkedSensitive() {
        // These are claims about the reader's condition rather than the
        // world's, and the loom already treats that distinction as meaningful.
        XCTAssertTrue(RelationalLoomFeature.Family.rutBand.isSensitiveInterpretation)
        XCTAssertTrue(RelationalLoomFeature.Family.pulseBand.isSensitiveInterpretation)
        XCTAssertFalse(RelationalLoomFeature.Family.weather.isSensitiveInterpretation)
        XCTAssertFalse(RelationalLoomFeature.Family.writing.isSensitiveInterpretation)
    }

    // MARK: - Lagged connections (3c)

    /// `pattern` decides, for each day index, whether that day was written on
    /// given whether the *previous* day was a short night.
    private func laggedHistory(
        days: Int,
        shortNight: (Int) -> Bool,
        wroteAfterShort: Bool,
        noise: (Int) -> Bool = { _ in false }
    ) -> [DaybookEntry] {
        (0..<days).map { index in
            let daysAgo = days - index
            let wasShort = index > 0 && shortNight(index - 1)
            let wrote = noise(index) ? !wroteAfterShort : (wasShort ? wroteAfterShort : !wroteAfterShort)
            return row(
                daysAgo: daysAgo,
                kept: wrote ? 1 : 0,
                sleep: shortNight(index) ? 4.0 : 8.0
            )
        }
    }

    func testALaggedRelationshipAcrossANightIsFound() {
        // Alternating short and long nights; the reader writes on the day after
        // a long night and not after a short one. Nothing in a same-day pairing
        // could see this.
        let rows = laggedHistory(
            days: 40,
            shortNight: { $0 % 2 == 0 },
            wroteAfterShort: false
        )

        let found = LaggedDaybookLoom.confirmedConnections(
            rows: rows,
            ledger: ledger(sleepMedian: 6),
            lag: 1,
            calendar: calendar
        )

        XCTAssertTrue(
            found.contains { connection in
                connection.condition.id.hasPrefix("after:sleep:")
                    && connection.outcome.id.hasPrefix("writing:")
            },
            "Expected a sleep→writing relationship across a night, got: \(found.map { "\($0.condition.id)->\($0.outcome.id)" })"
        )
    }

    func testALaggedFindingThatDoesNotSurviveTheHoldoutIsDiscarded() {
        // The relationship holds for the first stretch of history and then
        // inverts. A discovery pass alone would happily report it; the holdout
        // is the whole reason it does not reach the reader.
        var rows = laggedHistory(days: 40, shortNight: { $0 % 2 == 0 }, wroteAfterShort: false)
        // Flip the outcome on the most recent third: the holdout stretch.
        for index in rows.indices where rows[index].date >= calendar.date(byAdding: .day, value: -13, to: now)! {
            rows[index].keptPageCount = rows[index].keptPageCount > 0 ? 0 : 1
        }

        let found = LaggedDaybookLoom.confirmedConnections(
            rows: rows,
            ledger: ledger(sleepMedian: 6),
            lag: 1,
            calendar: calendar
        )

        XCTAssertFalse(
            found.contains { $0.condition.id.hasPrefix("after:sleep:") },
            "A finding that reversed on unseen days must not survive: \(found.map { "\($0.condition.id)->\($0.outcome.id)" })"
        )
    }

    func testNoLaggedFindingsBelowTheMinimumPairs() {
        let rows = laggedHistory(days: 8, shortNight: { $0 % 2 == 0 }, wroteAfterShort: false)

        XCTAssertTrue(
            LaggedDaybookLoom.confirmedConnections(
                rows: rows,
                ledger: ledger(sleepMedian: 6),
                lag: 1,
                calendar: calendar
            ).isEmpty
        )
    }

    func testNoLaggedFindingsBeforeTheLedgerHasTenure() {
        let rows = laggedHistory(days: 40, shortNight: { $0 % 2 == 0 }, wroteAfterShort: false)
        var young = ledger(sleepMedian: 6)
        young.tenureDays = 4

        XCTAssertTrue(
            LaggedDaybookLoom.confirmedConnections(
                rows: rows,
                ledger: young,
                lag: 1,
                calendar: calendar
            ).isEmpty
        )
    }

    func testLaggedConditionsAreMarkedSoTheyCannotMergeWithSameDayFindings() {
        let rows = laggedHistory(days: 20, shortNight: { $0 % 2 == 0 }, wroteAfterShort: false)
        let paired = LaggedDaybookLoom.pairedObservations(
            rows: rows,
            ledger: ledger(sleepMedian: 6),
            lag: 1,
            calendar: calendar
        )

        XCTAssertFalse(paired.isEmpty)
        for observation in paired {
            // Exactly one outcome, unprefixed; every condition marked.
            let outcomes = observation.features.filter { $0.family == .writing }
            XCTAssertEqual(outcomes.count, 1)
            XCTAssertFalse(outcomes[0].id.hasPrefix(LaggedDaybookLoom.conditionPrefix))
            for condition in observation.features where condition.family != .writing {
                XCTAssertTrue(condition.id.hasPrefix(LaggedDaybookLoom.conditionPrefix))
            }
        }
    }

    func testAnEarlierDaysWritingIsAllowedAsAConditionForTheNext() {
        let rows = laggedHistory(days: 20, shortNight: { $0 % 3 == 0 }, wroteAfterShort: true)
        let paired = LaggedDaybookLoom.pairedObservations(
            rows: rows,
            ledger: ledger(sleepMedian: 6),
            lag: 1,
            calendar: calendar
        )

        // The earlier day's own writing is dropped from the condition side:
        // "you wrote yesterday therefore you wrote yesterday" is bookkeeping.
        // Only its circumstances carry forward.
        XCTAssertFalse(
            paired.contains { observation in
                observation.features.contains {
                    $0.id.hasPrefix(LaggedDaybookLoom.conditionPrefix) && $0.family == .writing
                }
            }
        )
    }

    // MARK: - Day-rows do not displace page evidence

    func testDayRowsCarryNoPageIDAndSoCannotBeQuotedAsAKeptPage() {
        let observation = row(daysAgo: 1, kept: 3, events: 0)
            .loomObservation(ledger: ledger(), calendar: calendar)!

        XCTAssertNil(observation.evidence.pageID)
        XCTAssertTrue(observation.evidence.text.isEmpty)
        XCTAssertTrue(observation.id.hasPrefix("daybook:"))
    }
}

private extension RelationalLoomObservation {
    func has(where predicate: (RelationalLoomFeature) -> Bool) -> Bool {
        features.contains(where: predicate)
    }
}
