import XCTest
@testable import InsideCoverCore

/// Phase 0 of the permanent twin: one raw row per calendar day, kept or not.
/// These tests guard the two properties everything later leans on: that a row
/// is an observation rather than an interpolation, and that a row's fidelity
/// cannot be quietly upgraded by a backfill walk.
final class DaybookTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }()

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour)) ?? Date()
    }

    private func page(
        id: String,
        day: Int,
        hour: Int = 9,
        text: String,
        context: BookPageContextSnapshot? = nil
    ) -> BookPage {
        BookPage(
            id: id,
            type: .diary,
            createdAt: date(day, hour: hour),
            promptText: "Prompt",
            userInput: text,
            context: context
        )
    }

    private func bookDay(_ day: Int, pages: [BookPage]) -> BookDay {
        BookDay(
            id: DaybookRecorder.dayID(for: date(day), calendar: calendar),
            date: calendar.startOfDay(for: date(day)),
            pages: pages
        )
    }

    // MARK: - Live rows

    func testLiveRowRecordsWorldStateAndKeptCounts() {
        var inputs = BookSourceInputs.empty
        inputs.currentWeatherTags = ["rain", "cold"]
        inputs.weather = WeatherSourceSignal(phrase: "Current: Rain, 38F", source: "test")
        inputs.readerBeliefScore = 44
        inputs.body = BodySourceSignal(status: "tired", score: 31, phrase: "A short night.")

        let today = bookDay(3, pages: [
            page(id: "a", day: 3, text: "The harbour was grey and I was glad of it."),
            page(id: "b", day: 3, text: "Short one.")
        ])

        let entry = DaybookRecorder.live(
            inputs: inputs,
            day: today,
            now: date(3, hour: 21),
            calendar: calendar
        )

        XCTAssertEqual(entry.dayID, "2026-08-03")
        XCTAssertEqual(entry.fidelity, .live)
        XCTAssertEqual(entry.weatherTags, ["cold", "rain"])
        XCTAssertEqual(entry.temperatureBand, "cold")
        XCTAssertEqual(entry.bodyScore, 31)
        XCTAssertEqual(entry.beliefScoreAtClose, 44)
        XCTAssertEqual(entry.keptPageCount, 2)
        XCTAssertTrue(entry.deskWasSeen)
        XCTAssertTrue(entry.carriesEvidence)
    }

    func testUnobservedFieldsStayNilRatherThanGuessing() {
        // An empty twin: no weather, no body, no calendar, no pulses answered.
        let entry = DaybookRecorder.live(
            inputs: .empty,
            day: nil,
            now: date(3),
            calendar: calendar
        )

        XCTAssertNil(entry.temperatureBand)
        XCTAssertNil(entry.bodyScore)
        XCTAssertNil(entry.sleepHours)
        XCTAssertNil(entry.alivenessScore)
        XCTAssertNil(entry.wonderScore)
        XCTAssertNil(entry.capacityScore)
        XCTAssertNil(entry.medianWordsWritten)
        XCTAssertEqual(entry.keptPageCount, 0)
    }

    func testPulseScoresAreReadOnlyForTheirOwnDay() {
        func pulse(id: String, day: Int, score: Int) -> ReaderStatePulseRecord {
            ReaderStatePulseRecord(
                id: id,
                dimension: .aliveness,
                score: score,
                answerCode: "test",
                answerLine: "Test answer.",
                askedAt: date(day, hour: 19),
                answeredAt: date(day, hour: 20),
                dayID: DaybookRecorder.dayID(for: date(day), calendar: calendar),
                facets: []
            )
        }

        var inputs = BookSourceInputs.empty
        var ledger = ReaderStatePulseLedger.empty
        ledger.record(pulse(id: "yesterday", day: 2, score: 80))
        ledger.record(pulse(id: "today", day: 3, score: 25))
        inputs.readerStatePulses = ledger

        let entry = DaybookRecorder.live(
            inputs: inputs,
            day: nil,
            now: date(3, hour: 22),
            calendar: calendar
        )

        // Yesterday's 80 must not leak forward. Carrying values across days is
        // the Ledger's business, and it is not an observation.
        XCTAssertEqual(entry.alivenessScore, 25)
        XCTAssertNil(entry.wonderScore)
    }

    // MARK: - Rut doctrine

    func testDaybookRowsNeverRaiseRutPressureOnTheirOwn() {
        // A twin with no reader-reported Rut evidence at all. Absence, silence,
        // and grim weather must leave the assessment at its ordinary-life floor
        // and must never license the Book to name the Rut.
        var inputs = BookSourceInputs.empty
        inputs.currentWeatherTags = ["storm", "cold"]
        inputs.quietDays = 40

        let entry = DaybookRecorder.live(
            inputs: inputs,
            day: nil,
            now: date(3),
            calendar: calendar
        )

        XCTAssertEqual(entry.rutPressure, 1)
        XCTAssertEqual(entry.rutMayName, false)
    }

    // MARK: - Reconstruction

    func testReconstructedRowRecoversRealContextFromKeptPages() {
        let context = BookPageContextSnapshot(
            at: date(1, hour: 8),
            calendar: calendar,
            weatherTags: ["fog"],
            bodyScore: 62,
            calendarEventCount: 3,
            nearbyAnchorID: "anchor-kitchen",
            locationLabel: "Home"
        )
        let day = bookDay(1, pages: [
            page(id: "c", day: 1, text: "Fog on the water, and I stayed with it a while.", context: context)
        ])

        let entry = DaybookRecorder.reconstructed(day: day, calendar: calendar)

        XCTAssertEqual(entry.fidelity, .reconstructed)
        XCTAssertEqual(entry.weatherTags, ["fog"])
        XCTAssertEqual(entry.bodyScore, 62)
        XCTAssertEqual(entry.calendarEventCount, 3)
        XCTAssertEqual(entry.placeLabel, "Home")
        XCTAssertEqual(entry.keptPageCount, 1)
        XCTAssertTrue(entry.carriesEvidence)
    }

    func testAbsentRowCarriesNoEvidence() {
        let entry = DaybookRecorder.absent(
            dayID: "2026-08-02",
            date: date(2),
            calendar: calendar
        )

        XCTAssertEqual(entry.fidelity, .absent)
        XCTAssertFalse(entry.carriesEvidence)
        XCTAssertFalse(entry.deskWasSeen)
        XCTAssertEqual(entry.keptPageCount, 0)
        XCTAssertTrue(entry.weatherTags.isEmpty)
        XCTAssertNil(entry.bodyScore)
    }

    // MARK: - The gap walk

    func testBackfillReconstructsWrittenDaysAndMarksTheRestAbsent() {
        let days = [
            bookDay(1, pages: [page(id: "d", day: 1, text: "Something worth keeping.")]),
            bookDay(3, pages: [page(id: "e", day: 3, text: "Another.")])
        ]

        let entries = DaybookRecorder.backfill(
            recordedDayIDs: [],
            days: days,
            now: date(5, hour: 10),
            calendar: calendar
        )

        // Days 1–4 are walked; day 5 is today and belongs to the live tick.
        XCTAssertEqual(entries.map(\.dayID), ["2026-08-01", "2026-08-02", "2026-08-03", "2026-08-04"])
        XCTAssertEqual(entries[0].fidelity, .reconstructed)
        XCTAssertEqual(entries[1].fidelity, .absent)
        XCTAssertEqual(entries[2].fidelity, .reconstructed)
        XCTAssertEqual(entries[3].fidelity, .absent)
    }

    func testBackfillSkipsDaysThatAlreadyHaveRows() {
        let entries = DaybookRecorder.backfill(
            recordedDayIDs: ["2026-08-02", "2026-08-03"],
            days: [bookDay(1, pages: [page(id: "f", day: 1, text: "Kept.")])],
            now: date(4, hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(entries.map(\.dayID), ["2026-08-01"])
    }

    func testBackfillIsCappedSoALongAbsenceLeavesATruthfulHole() {
        let entries = DaybookRecorder.backfill(
            recordedDayIDs: [],
            days: [],
            now: date(5, hour: 10),
            calendar: calendar,
            cap: 2
        )

        // Two days of gap, not a year of manufactured skeletons.
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map(\.dayID), ["2026-08-03", "2026-08-04"])
    }

    func testBackfillExcludesToday() {
        let entries = DaybookRecorder.backfill(
            recordedDayIDs: [],
            days: [bookDay(5, pages: [page(id: "g", day: 5, text: "Today's page.")])],
            now: date(5, hour: 23),
            calendar: calendar
        )

        XCTAssertFalse(entries.contains { $0.dayID == "2026-08-05" })
    }

    // MARK: - Split body metrics (Phase 1)

    private func bodySignal(
        score: Int = 58,
        steps: String? = "7,204",
        sleep: String? = "6.2",
        restingHeartRate: String? = "54",
        hrv: String? = "41"
    ) -> BodySourceSignal {
        var metrics: [BodySourceSignal.Metric] = []
        if let steps {
            metrics.append(.init(id: "stepCount", label: "Steps", value: steps, kind: "sum"))
        }
        if let sleep {
            metrics.append(.init(id: "sleepAnalysis", label: "Sleep", value: sleep, unit: "h", kind: "category"))
        }
        // The richer metrics arrive under HealthKit's own raw identifiers.
        if let restingHeartRate {
            metrics.append(.init(
                id: "HKQuantityTypeIdentifierRestingHeartRate",
                label: "Resting heart rate",
                value: restingHeartRate,
                unit: "bpm"
            ))
        }
        if let hrv {
            metrics.append(.init(
                id: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
                label: "HRV",
                value: hrv,
                unit: "ms"
            ))
        }
        return BodySourceSignal(status: "STEADY", score: score, phrase: "Steady.", metrics: metrics)
    }

    func testBodyMetricsAreReadUnderBothNamingConventions() {
        let body = bodySignal()

        XCTAssertEqual(body.metricValue(.steps), 7204)
        XCTAssertEqual(body.metricValue(.sleep), 6.2)
        XCTAssertEqual(body.metricValue(.restingHeartRate), 54)
        XCTAssertEqual(body.metricValue(.heartRateVariability), 41)
    }

    func testMetricIDNormalizationStripsHealthKitPrefixes() {
        XCTAssertEqual(
            BodySourceSignal.normalizedMetricID("HKQuantityTypeIdentifierRestingHeartRate"),
            "restingHeartRate"
        )
        XCTAssertEqual(
            BodySourceSignal.normalizedMetricID("HKCategoryTypeIdentifierSleepAnalysis"),
            "sleepAnalysis"
        )
        XCTAssertEqual(BodySourceSignal.normalizedMetricID("stepCount"), "stepCount")
    }

    func testMissingMetricsStayNilRatherThanZero() {
        let body = bodySignal(steps: nil, sleep: "0", restingHeartRate: nil, hrv: nil)

        XCTAssertNil(body.metricValue(.steps))
        // A zero is "nothing recorded", not "measured as zero".
        XCTAssertNil(body.metricValue(.sleep))
        XCTAssertNil(body.metricValue(.restingHeartRate))
    }

    func testLiveRowSplitsTheCompositeBodyScoreIntoNamedMetrics() {
        var inputs = BookSourceInputs.empty
        inputs.body = bodySignal(score: 31)

        let entry = DaybookRecorder.live(
            inputs: inputs,
            day: nil,
            now: date(3, hour: 21),
            calendar: calendar
        )

        // The composite survives; the parts are now separately answerable.
        XCTAssertEqual(entry.bodyScore, 31)
        XCTAssertEqual(entry.sleepHours, 6.2)
        XCTAssertEqual(entry.steps, 7204)
        XCTAssertEqual(entry.restingHeartRate, 54)
        XCTAssertEqual(entry.heartRateVariability, 41)
    }

    func testPageContextSnapshotRejectsImpossibleBodyReadings() {
        let snapshot = BookPageContextSnapshot(
            at: date(3),
            calendar: calendar,
            sleepHours: 40,
            steps: -5,
            restingHeartRate: 0,
            heartRateVariability: 41
        )

        XCTAssertNil(snapshot.sleepHours)
        XCTAssertNil(snapshot.steps)
        XCTAssertNil(snapshot.restingHeartRate)
        XCTAssertEqual(snapshot.heartRateVariability, 41)
    }

    func testSnapshotsWrittenBeforePhaseOneDecodeWithNilBodyMetrics() throws {
        // A snapshot as it was encoded before the split fields existed.
        let legacy = """
        {"timeZoneIdentifier":"America/Los_Angeles","utcOffsetSeconds":-25200,
         "dayPart":"morning","weatherTags":["rain"],"bodyScore":44}
        """
        let decoded = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: Data(legacy.utf8)
        )

        XCTAssertEqual(decoded.bodyScore, 44)
        XCTAssertNil(decoded.sleepHours)
        XCTAssertNil(decoded.steps)
    }

    func testReconstructionRecoversSplitMetricsFromKeptPages() {
        let context = BookPageContextSnapshot(
            at: date(1, hour: 8),
            calendar: calendar,
            bodyScore: 40,
            sleepHours: 5.1,
            steps: 3000,
            restingHeartRate: 61
        )
        let day = bookDay(1, pages: [
            page(id: "m", day: 1, text: "A short night, and it showed.", context: context)
        ])

        let entry = DaybookRecorder.reconstructed(day: day, calendar: calendar)

        XCTAssertEqual(entry.sleepHours, 5.1)
        XCTAssertEqual(entry.steps, 3000)
        XCTAssertEqual(entry.restingHeartRate, 61)
    }

    // MARK: - Reconciliation

    func testReconciliationCatchesUpARowTheArchiveOutgrew() {
        // A row written at breakfast, before the day's keeps existed.
        var morning = DaybookRecorder.live(
            inputs: .empty,
            day: nil,
            now: date(3, hour: 7),
            calendar: calendar
        )
        XCTAssertEqual(morning.keptPageCount, 0)
        morning.dayID = "2026-08-03"

        let day = bookDay(3, pages: [
            page(id: "h", day: 3, hour: 14, text: "Kept after the tick had already run."),
            page(id: "i", day: 3, hour: 19, text: "And another.")
        ])

        let updated = DaybookRecorder.reconciled(entry: morning, with: day, calendar: calendar)

        XCTAssertEqual(updated?.keptPageCount, 2)
        // Correcting the arithmetic must not demote what the Book watched happen.
        XCTAssertEqual(updated?.fidelity, .live)
    }

    func testReconciliationReturnsNilWhenTheRowIsAlreadyTrue() {
        let day = bookDay(3, pages: [page(id: "j", day: 3, text: "One kept page.")])
        let entry = DaybookRecorder.reconstructed(day: day, calendar: calendar)

        XCTAssertNil(DaybookRecorder.reconciled(entry: entry, with: day, calendar: calendar))
    }

    func testAnAbsentDayThatTurnsOutToHavePagesBecomesReconstructed() {
        let absent = DaybookRecorder.absent(dayID: "2026-08-03", date: date(3), calendar: calendar)
        let day = bookDay(3, pages: [page(id: "k", day: 3, text: "It was not an empty day.")])

        let updated = DaybookRecorder.reconciled(entry: absent, with: day, calendar: calendar)

        XCTAssertEqual(updated?.fidelity, .reconstructed)
        XCTAssertEqual(updated?.keptPageCount, 1)
        XCTAssertEqual(updated?.deskWasSeen, true)
    }

    func testReconciliationsOnlyReachIntoTheTrailingWindow() {
        let stale = DaybookRecorder.absent(dayID: "2026-08-01", date: date(1), calendar: calendar)
        let old = DaybookRecorder.absent(dayID: "2026-07-01", date: date(1).addingTimeInterval(-31 * 86_400), calendar: calendar)
        let days = [bookDay(1, pages: [page(id: "l", day: 1, text: "Kept.")])]

        let corrections = DaybookRecorder.reconciliations(
            entries: [stale, old],
            days: days,
            within: 7,
            now: date(4, hour: 9),
            calendar: calendar
        )

        XCTAssertEqual(corrections.map(\.dayID), ["2026-08-01"])
    }

    // MARK: - Fidelity may never be demoted

    func testALiveRowIsNeverOverwrittenByABackfilledOne() {
        XCTAssertTrue(BookArchiveDatabase.mayReplace(nil, with: .absent))
        XCTAssertTrue(BookArchiveDatabase.mayReplace(.live, with: .live))
        XCTAssertTrue(BookArchiveDatabase.mayReplace(.absent, with: .reconstructed))
        XCTAssertTrue(BookArchiveDatabase.mayReplace(.reconstructed, with: .live))

        XCTAssertFalse(BookArchiveDatabase.mayReplace(.live, with: .reconstructed))
        XCTAssertFalse(BookArchiveDatabase.mayReplace(.live, with: .absent))
        XCTAssertFalse(BookArchiveDatabase.mayReplace(.reconstructed, with: .absent))
    }

    // MARK: - Measures

    func testLongestOpenBlockFindsTheGapBetweenBookings() {
        let events = [
            CalendarEventSignal(
                id: "1",
                title: "Morning",
                startsAt: date(3, hour: 9),
                endsAt: date(3, hour: 10),
                isAllDay: false
            ),
            CalendarEventSignal(
                id: "2",
                title: "Late",
                startsAt: date(3, hour: 20),
                endsAt: date(3, hour: 21),
                isAllDay: false
            )
        ]

        let minutes = DaybookRecorder.longestOpenBlockMinutes(
            events: events,
            on: date(3),
            calendar: calendar
        )

        // 10:00 to 20:00 is the widest stretch inside the 07:00–23:00 window.
        XCTAssertEqual(minutes, 600)
    }

    func testLongestOpenBlockOnAnEmptyCalendarIsTheWholeWakingWindow() {
        let minutes = DaybookRecorder.longestOpenBlockMinutes(
            events: [],
            on: date(3),
            calendar: calendar
        )

        XCTAssertEqual(minutes, 16 * 60)
    }

    func testSessionCountSplitsOnHalfHourGaps() {
        let moments = [
            date(3, hour: 8),
            date(3, hour: 8).addingTimeInterval(60),
            date(3, hour: 8).addingTimeInterval(10 * 60),
            date(3, hour: 14),
            date(3, hour: 21)
        ]

        XCTAssertEqual(DaybookRecorder.sessionCount(from: moments), 3)
        XCTAssertEqual(DaybookRecorder.sessionCount(from: []), 0)
    }

    func testTemperatureBands() {
        func band(_ phrase: String) -> String? {
            DaybookRecorder.temperatureBand(
                from: WeatherSourceSignal(phrase: phrase, source: "test")
            )
        }

        XCTAssertEqual(band("Current: Snow, 21F"), "cold")
        XCTAssertEqual(band("Current: Clear, 64F"), "mild")
        XCTAssertEqual(band("Current: Bright, 91F"), "hot")
        XCTAssertNil(band(""))
    }

    // MARK: - Round trip

    func testEntryEncodesAndDecodesWhole() throws {
        var entry = DaybookRecorder.absent(dayID: "2026-08-02", date: date(2), calendar: calendar)
        entry.weatherTags = ["rain"]
        entry.sleepHours = 6.25
        entry.rutEvidence = ["ordinary-life-prior"]
        entry.keptPageTypes = ["diary", "mood"]

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(DaybookEntry.self, from: data)

        XCTAssertEqual(decoded, entry)
        XCTAssertEqual(decoded.id, "2026-08-02")
    }
}
