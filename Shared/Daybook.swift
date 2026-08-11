import Foundation

// MARK: - The Daybook
//
// One raw row per calendar day, whether or not the reader kept anything.
//
// A daybook is the accounting record written as things happen, before anything
// is posted to a ledger: chronological, uninterpreted, and complete. That is the
// contract here. Every other reader-facing structure in the Book is conditioned
// on the reader having shown up: page context snapshots exist only where a page
// was kept, and so every pattern the Book can currently find is drawn from the
// days it was already invited into. The Daybook is the denominator that was
// missing. It records absence; it never concludes anything from it.
//
// Doctrine, in order:
// 1. Rows are observations, never interpolations. A field the Book did not
//    observe stays nil. Carrying a value forward is the Ledger's business.
// 2. A row's `fidelity` says how it was come by. A reconstructed row can never
//    counterweight a live one, and a pattern that flips when reconstructed rows
//    are excluded is not a pattern.
// 3. Absence is not Rut evidence. `NothingTide` rule 3 stands: silence, weather,
//    seasons, and story activity never corroborate the Curse. `rutPressure` here
//    is a snapshot of the reader's own reported assessment and nothing more.

struct DaybookEntry: Codable, Equatable, Identifiable {
    /// How the row was come by. The difference is load-bearing: HealthKit and
    /// EventKit answer retroactively, but weather and location do not, so a
    /// backfilled row has real counts and honestly-absent skies.
    enum Fidelity: String, Codable, Equatable {
        /// Written while the day was current, with live sensors.
        case live
        /// Backfilled from the archive. Only the fields the archive genuinely
        /// preserved are populated; the rest stay nil rather than guess.
        case reconstructed
        /// The day passed with nothing recorded at all. The row exists so the
        /// day can be counted, and contributes to nothing else.
        case absent
    }

    var id: String { dayID }

    var dayID: String
    var date: Date
    var timeZoneIdentifier: String
    var utcOffsetSeconds: Int
    var fidelity: Fidelity
    var writtenAt: Date

    // MARK: World

    var weatherTags: [String] = []
    var temperatureBand: String?
    var daylightMinutes: Int?
    var placeLabel: String?
    var nearbyAnchorID: String?
    var distinctPlaceCount: Int?
    var travelled: Bool?

    // MARK: Calendar

    var calendarEventCount: Int?
    var firstEventHour: Int?
    var lastEventHour: Int?
    var longestOpenBlockMinutes: Int?

    // MARK: Body
    //
    // `bodyScore` is a composite: it collapses sleep, movement and energy into
    // one 0–100 number banded at ≤40 and ≥70. That is enough to say "the body
    // arrived tired" and not enough to say anything about *why*. The split
    // fields are what let a later phase find "after short nights" rather than
    // "on low-body days": a different and much more useful claim. Each stays
    // nil when the reader has not shared that metric.

    var bodyScore: Int?
    var sleepHours: Double?
    var steps: Int?
    var restingHeartRate: Int?
    var heartRateVariability: Double?
    var activeKilocalories: Double?
    var distanceMiles: Double?
    var bodyObservedAt: Date?

    // MARK: Reader-reported
    //
    // nil when unanswered. Never filled in from a neighbouring day.

    var alivenessScore: Int?
    var wonderScore: Int?
    var hiddenMagicScore: Int?
    var capacityScore: Int?
    var innerWeatherEntryID: String?
    var innerWeatherTone: String?
    var fuelEntryID: String?

    // MARK: Rut: reader-evidence-derived only

    var rutPressure: Int?
    var rutMayName: Bool?
    var rutEvidence: [String] = []

    // MARK: What happened. Counts, not judgements.

    var deskWasSeen: Bool = false
    var sessionCount: Int = 0
    var keptPageCount: Int = 0
    var keptPageTypes: [String] = []
    var openedCount: Int = 0
    var dismissedCount: Int = 0
    var medianWordsWritten: Int?
    var dayInkTone: String?
    var beliefScoreAtClose: Int?

    init(
        dayID: String,
        date: Date,
        fidelity: Fidelity,
        calendar: Calendar = .current,
        writtenAt: Date = Date()
    ) {
        self.dayID = dayID
        self.date = date
        self.timeZoneIdentifier = calendar.timeZone.identifier
        self.utcOffsetSeconds = calendar.timeZone.secondsFromGMT(for: date)
        self.fidelity = fidelity
        self.writtenAt = writtenAt
    }

    /// True when the row carries something a pattern could actually stand on.
    /// `.absent` rows are deliberately excluded: they make the denominator
    /// honest and are evidence for nothing.
    var carriesEvidence: Bool {
        fidelity != .absent
    }
}

// MARK: - A day as something the loom can read
//
// Until there was a row for every day, every pattern the Book could find was
// conditioned on the reader having shown up: the out-group was always *other
// kept pages*, never *other days*. That made a whole class of true thing
// unsayable: "of your last eleven open days you wrote on nine; of your last
// fourteen crowded ones, two", because the crowded silent days existed in no
// data structure at all.
//
// These observations fix the denominator. The `writing` feature is the outcome
// that carries it: a day either had a page kept in it or it did not, and both
// are now rows.
//
// Two properties keep it honest. A row only offers the features it genuinely
// has, so an `.absent` day contributes its weekday and its silence and nothing
// else: there is no way for it to smuggle in a weather it never saw. And the
// bands are drawn against the reader's own baselines from the Ledger, so
// "a short night" means short *for them*.

extension DaybookEntry {
    /// The loom observation for this day, or nil when the row cannot answer for
    /// anything beyond its own date.
    func loomObservation(
        ledger: StandingLedger,
        calendar: Calendar = .current
    ) -> RelationalLoomObservation? {
        var features: [RelationalLoomFeature] = []

        func add(
            _ family: RelationalLoomFeature.Family,
            _ value: String,
            label: String,
            condition: String,
            outcome: String,
            symbol: String,
            readerMeaning: Bool = false
        ) {
            features.append(
                RelationalLoomFeature(
                    id: "\(family.rawValue):\(value)",
                    family: family,
                    label: label,
                    conditionClause: condition,
                    outcomeClause: outcome,
                    symbolName: symbol,
                    carriesReaderSuppliedMeaning: readerMeaning
                )
            )
        }

        // The outcome that makes absence a thing at all.
        if keptPageCount > 0 {
            add(.writing, "kept", label: "Wrote",
                condition: "you had written", outcome: "you wrote something down",
                symbol: "pencil")
        } else {
            add(.writing, "silent", label: "Didn't write",
                condition: "you had not written", outcome: "the day went unwritten",
                symbol: "pencil.slash")
        }

        add(.weekPart, calendar.isDateInWeekend(date) ? "weekend" : "weekday",
            label: calendar.isDateInWeekend(date) ? "Weekend" : "Weekday",
            condition: calendar.isDateInWeekend(date) ? "it was the weekend" : "it was a weekday",
            outcome: calendar.isDateInWeekend(date) ? "it fell on a weekend" : "it fell on a weekday",
            symbol: "calendar")

        for tag in weatherTags {
            add(.weather, tag, label: tag.capitalized,
                condition: "the weather leaned \(tag)", outcome: "the weather leaned \(tag)",
                symbol: "cloud")
        }

        if let events = calendarEventCount {
            if events == 0 {
                add(.tempo, "open", label: "Open day",
                    condition: "the calendar stood open", outcome: "the calendar stood open",
                    symbol: "calendar.badge.minus")
            } else if events >= 3 {
                add(.tempo, "crowded", label: "Crowded day",
                    condition: "the day was crowded", outcome: "the day was crowded",
                    symbol: "calendar.badge.exclamationmark")
            }
        }

        if let place = nearbyAnchorID ?? placeLabel, !place.isEmpty {
            add(.place, place, label: place,
                condition: "you were near \(place)", outcome: "you were near \(place)",
                symbol: "mappin")
        }

        // Bands against the reader's own median, never a population's.
        if let band = relativeBand(.sleepHours, ledger: ledger) {
            add(.sleep, band.id, label: "Sleep \(band.id)",
                condition: band.id == "short" ? "the night before had been short" : "the night before had been long",
                outcome: band.id == "short" ? "the night had been short" : "the night had been long",
                symbol: "moon.zzz")
        }

        if let band = relativeBand(.alivenessScore, ledger: ledger) {
            add(.pulseBand, band.id, label: "Pulse \(band.id)",
                condition: band.id == "short" ? "you had been running low" : "you had been running high",
                outcome: band.id == "short" ? "you were running low" : "you were running high",
                symbol: "waveform.path.ecg", readerMeaning: true)
        }

        if let pressure = rutPressure, pressure >= 2 {
            add(.rutBand, pressure >= 3 ? "desk" : "margins",
                label: pressure >= 3 ? "Rut at the desk" : "Rut in the margins",
                condition: "the grey had been close", outcome: "the grey had been close",
                symbol: "square.grid.3x3.fill", readerMeaning: true)
        }

        if let minutes = daylightMinutes {
            let value = minutes >= 13 * 60 ? "long" : (minutes <= 10 * 60 ? "short" : nil)
            if let value {
                add(.daylight, value, label: value == "long" ? "Long light" : "Short light",
                    condition: value == "long" ? "the light was long" : "the light was short",
                    outcome: value == "long" ? "the light was long" : "the light was short",
                    symbol: "sun.horizon")
            }
        }

        if let travelled {
            add(.travel, travelled ? "elsewhere" : "home-set",
                label: travelled ? "Away" : "Usual ground",
                condition: travelled ? "you were away from your usual ground" : "you were on your usual ground",
                outcome: travelled ? "you were away" : "you stayed on usual ground",
                symbol: travelled ? "airplane" : "house")
        }

        // A day whose only feature is that it happened teaches nothing.
        guard features.count >= 2 else { return nil }

        return RelationalLoomObservation(
            id: "daybook:\(dayID)",
            dayID: dayID,
            occurredAt: date,
            features: features,
            evidence: RelationalLoomEvidence(
                id: "daybook-evidence:\(dayID)",
                dayID: dayID,
                occurredAt: date,
                title: keptPageCount > 0 ? "A day you wrote" : "A day that went unwritten",
                text: "",
                pageID: nil
            )
        )
    }

    /// Where a field sat against the reader's own 28-day median, as `short` or
    /// `long`, or nil when it sat in the usual range or has no trustworthy
    /// baseline behind it.
    private func relativeBand(
        _ field: StandingField,
        ledger: StandingLedger
    ) -> (id: String, value: Double)? {
        guard let baseline = ledger.baseline(field), baseline.isTrustworthy,
              let value = field.value(in: self) else { return nil }
        let spread = max(baseline.medianAbsoluteDeviation, 0.0001)
        let units = (value - baseline.median) / spread
        if units <= -1 { return ("short", value) }
        if units >= 1 { return ("long", value) }
        return nil
    }
}

extension StandingLedgerBuilder {
    /// Every day the Book has a row for, as loom observations. These are meant
    /// to be handed to `ContextWeave.connections(observations:)` alongside the
    /// page-derived ones, not instead of them.
    static func loomObservations(
        rows: [DaybookEntry],
        ledger: StandingLedger,
        calendar: Calendar = .current
    ) -> [RelationalLoomObservation] {
        rows.compactMap { $0.loomObservation(ledger: ledger, calendar: calendar) }
    }
}

// MARK: - Lagged connections
//
// Every connection the loom can currently find is same-receipt: features that
// co-occurred in one observation. A daily series permits something the
// architecture has never been able to reach: a relationship across a night.
//
//   "The day after a long walk, your sentences run longer."
//   "You ask questions the day after a short night."
//
// These are causal-*shaped*, which is exactly why they get the strictest gate
// in the system. A same-day coincidence is a curiosity; a claim that one day
// shapes the next is close to a claim about cause, and with twenty-nine
// families and two lags, spurious findings are not a possibility but a
// certainty. So a lagged finding must survive a holdout: discovered on the
// earlier stretch of history, then independently confirmed on the later one.

enum LaggedDaybookLoom {
    /// Fraction of history used for discovery. The remainder is never looked at
    /// until there is a candidate to test against it.
    static let discoveryFraction = 0.7
    /// Paired days needed before a lag is examined at all.
    static let minimumPairs = 12
    /// The condition side of a lagged pair is marked so a finding across a
    /// night can never be confused with, or merged into, a same-day one.
    static let conditionPrefix = "after:"

    /// Observations pairing each day's conditions with a later day's outcome.
    ///
    /// Only the *writing* outcome crosses the gap. Relating one day's weather
    /// to the next day's weather would be meteorology, and relating a day's
    /// sleep to the next day's sleep is a habit, not a discovery.
    static func pairedObservations(
        rows: [DaybookEntry],
        ledger: StandingLedger,
        lag: Int,
        calendar: Calendar = .current
    ) -> [RelationalLoomObservation] {
        let ordered = rows.sorted { $0.date < $1.date }
        let byDayID = Dictionary(uniqueKeysWithValues: ordered.map { ($0.dayID, $0) })

        return ordered.compactMap { row -> RelationalLoomObservation? in
            guard let laterDate = calendar.date(byAdding: .day, value: lag, to: row.date),
                  let later = byDayID[DaybookRecorder.dayID(for: laterDate, calendar: calendar)],
                  let conditions = row.loomObservation(ledger: ledger, calendar: calendar),
                  let outcomes = later.loomObservation(ledger: ledger, calendar: calendar) else {
                return nil
            }

            // The earlier day contributes conditions only: including whether
            // it was written on, which is a legitimate condition for the day
            // that follows it.
            let conditionFeatures = conditions.features
                .filter { $0.family != .writing }
                .map { feature -> RelationalLoomFeature in
                    var marked = feature
                    marked.id = conditionPrefix + feature.id
                    return marked
                }
            guard let outcome = outcomes.features.first(where: { $0.family == .writing }),
                  !conditionFeatures.isEmpty else { return nil }

            return RelationalLoomObservation(
                id: "daybook-lag\(lag):\(row.dayID)",
                dayID: later.dayID,
                occurredAt: later.date,
                features: conditionFeatures + [outcome],
                evidence: RelationalLoomEvidence(
                    id: "daybook-lag\(lag)-evidence:\(row.dayID)",
                    dayID: later.dayID,
                    occurredAt: later.date,
                    title: "The day after",
                    text: "",
                    pageID: nil
                )
            )
        }
    }

    /// Lagged findings that survived a holdout.
    ///
    /// Discovery runs on the earlier `discoveryFraction` of the paired history.
    /// Every candidate is then re-counted on the later stretch, which the
    /// discovery pass never saw, and kept only if the relationship still leans
    /// the same way there. This is the difference between a pattern and a
    /// coincidence that happened to clear a threshold once.
    static func confirmedConnections(
        rows: [DaybookEntry],
        ledger: StandingLedger,
        lag: Int = 1,
        calendar: Calendar = .current
    ) -> [RelationalLoomConnection] {
        guard ledger.isReady else { return [] }
        let paired = pairedObservations(rows: rows, ledger: ledger, lag: lag, calendar: calendar)
            .sorted { $0.occurredAt < $1.occurredAt }
        guard paired.count >= minimumPairs else { return [] }

        let splitIndex = Int(Double(paired.count) * discoveryFraction)
        let discovery = Array(paired.prefix(splitIndex))
        let holdout = Array(paired.suffix(paired.count - splitIndex))
        guard discovery.count >= 5, holdout.count >= 3 else { return [] }

        return RelationalLoom.connections(observations: discovery).filter { candidate in
            holds(candidate, in: holdout)
        }
    }

    /// Whether a candidate still leans the same way on days it was not found on.
    /// The bar is deliberately only directional: a holdout stretch is small,
    /// and asking it to clear the full discovery gate again would reject
    /// everything real along with everything spurious.
    static func holds(
        _ connection: RelationalLoomConnection,
        in holdout: [RelationalLoomObservation]
    ) -> Bool {
        let universe = holdout.filter { $0.hasFamily(connection.outcome.family) }
        let inside = universe.filter { $0.has(connection.condition) }
        let outside = universe.filter { !$0.has(connection.condition) }
        guard !inside.isEmpty, !outside.isEmpty else { return false }

        let inRate = Double(inside.filter { $0.has(connection.outcome) }.count) / Double(inside.count)
        let outRate = Double(outside.filter { $0.has(connection.outcome) }.count) / Double(outside.count)
        return inRate > outRate
    }
}

// MARK: - Reading the body signal as numbers

/// `BodySourceSignal` carries its metrics as display strings, and by two naming
/// conventions at once: the four base metrics use short ids (`stepCount`,
/// `sleepAnalysis`), while the richer ones use `HKQuantityTypeIdentifier` raw
/// values (`HKQuantityTypeIdentifierRestingHeartRate`). Both are normalised here
/// so the twin can read a number without caring which lane it arrived by.
extension BodySourceSignal {
    /// The metric ids the twin reads, in their normalised short form.
    enum MetricKey: String {
        case steps = "stepCount"
        case sleep = "sleepAnalysis"
        case restingHeartRate
        case heartRateVariability = "heartRateVariabilitySDNN"
        case activeEnergy = "activeEnergyBurned"
        case distance = "distanceWalkingRunning"
    }

    /// `HKQuantityTypeIdentifierRestingHeartRate` → `restingHeartRate`.
    /// A short id passes through untouched.
    static func normalizedMetricID(_ id: String) -> String {
        for prefix in ["HKQuantityTypeIdentifier", "HKCategoryTypeIdentifier"] where id.hasPrefix(prefix) {
            let stripped = id.dropFirst(prefix.count)
            guard let first = stripped.first else { return id }
            return first.lowercased() + stripped.dropFirst()
        }
        return id
    }

    func metricValue(_ key: MetricKey) -> Double? {
        // Values are formatted for display, so they can carry grouping
        // separators ("7,204"). Strip anything that isn't part of a number.
        guard let metric = metrics.first(where: {
            Self.normalizedMetricID($0.id) == key.rawValue
        }) else { return nil }
        let cleaned = metric.value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard let value = Double(cleaned) else { return nil }
        // A zero here means "nothing recorded", not "measured as zero": the
        // base metrics are already filtered on `> 0` before they are attached.
        return value > 0 ? value : nil
    }

    /// When the freshest metric was actually observed, if any of them say.
    var freshestObservation: Date? {
        metrics.compactMap(\.observedAt).max()
    }
}

// MARK: - Building rows

enum DaybookRecorder {
    /// How far back a returning reader's gap is walked before the Book simply
    /// accepts that it does not know. A year away should leave a truthful hole,
    /// not a year of manufactured skeletons.
    static let backfillCapDays = 90

    static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        AlmanacModel.dayID(for: date, calendar: calendar)
    }

    // MARK: Live

    /// The row for a day the Book is standing inside. `day` is today's archive
    /// day; `inputs` is the twin as currently assembled.
    static func live(
        inputs: BookSourceInputs,
        day: BookDay?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DaybookEntry {
        let startOfDay = calendar.startOfDay(for: now)
        let id = dayID(for: now, calendar: calendar)
        var entry = DaybookEntry(
            dayID: id,
            date: startOfDay,
            fidelity: .live,
            calendar: calendar,
            writtenAt: now
        )

        // World
        entry.weatherTags = inputs.currentWeatherTags.sorted()
        entry.temperatureBand = temperatureBand(from: inputs.weather)
        entry.daylightMinutes = inputs.coordinate.flatMap {
            daylightMinutes(on: now, at: $0, calendar: calendar)
        }
        entry.placeLabel = inputs.currentPlaceContext.map(\.rawValue) ?? inputs.currentLocationLabel
        entry.nearbyAnchorID = inputs.nearbyAnchor?.anchor.id

        // Calendar
        if inputs.calendarIntegrationEnabled {
            let todaysEvents = inputs.calendarEvents
                .filter { calendar.isDate($0.startsAt, inSameDayAs: now) }
                .sorted { $0.startsAt < $1.startsAt }
            entry.calendarEventCount = todaysEvents.count
            entry.firstEventHour = todaysEvents.first.map {
                calendar.component(.hour, from: $0.startsAt)
            }
            entry.lastEventHour = todaysEvents.last.map {
                calendar.component(.hour, from: $0.startsAt)
            }
            entry.longestOpenBlockMinutes = longestOpenBlockMinutes(
                events: todaysEvents,
                on: now,
                calendar: calendar
            )
        }

        // Body
        if let body = inputs.body, body.isAvailable {
            entry.bodyScore = body.score
            entry.bodyObservedAt = body.freshestObservation ?? now
            applyBodyMetrics(to: &entry, from: body)
        }

        // Reader-reported pulses, today only
        let todaysPulses = inputs.readerStatePulses.records.filter { $0.dayID == id }
        func pulse(_ dimension: ReaderStatePulseDimension) -> Int? {
            todaysPulses
                .filter { $0.dimension == dimension }
                .max { $0.answeredAt < $1.answeredAt }?
                .score
        }
        entry.alivenessScore = pulse(.aliveness)
        entry.wonderScore = pulse(.wonder)
        entry.hiddenMagicScore = pulse(.hiddenMagic)
        entry.capacityScore = pulse(.capacity)

        let todaysFaculty = inputs.facultyEntries
            .filter { $0.dayID == id }
            .sorted { $0.createdAt > $1.createdAt }
        let innerWeather = todaysFaculty.first { $0.kind == .innerWeather }
        entry.innerWeatherEntryID = innerWeather?.id
        entry.innerWeatherTone = innerWeather.flatMap { ContextWeave.tone(of: $0.rawText)?.rawValue }
        entry.fuelEntryID = todaysFaculty.first { $0.kind == .fuel }?.id

        // Rut: a snapshot of the reader's own reported assessment
        let distressActive = day.map { DistressSignals.evaluate(day: $0).isActive } ?? false
        let rut = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: distressActive,
            now: now,
            calendar: calendar
        )
        // The reader's own report, not the working pressure. The Rut's long
        // trajectory should be a record of what they said, so a behavioural
        // lean can never accumulate into apparent testimony.
        entry.rutPressure = rut.reportedPressure
        entry.rutMayName = rut.mayNameRut
        entry.rutEvidence = rut.evidence

        // What happened
        entry.deskWasSeen = true
        entry.beliefScoreAtClose = inputs.readerBeliefScore
        applyPageCounts(to: &entry, day: day, calendar: calendar)
        applyInteractionCounts(to: &entry, learning: inputs.readerLearning, dayID: id)

        return entry
    }

    // MARK: Reconstructed

    /// The row for a past day the Daybook never saw, rebuilt from what the
    /// archive genuinely preserved. Kept pages carry a `BookPageContextSnapshot`,
    /// so weather, body, calendar density and place are real here: recovered,
    /// not invented. Everything the archive cannot answer stays nil.
    static func reconstructed(
        day: BookDay,
        calendar: Calendar = .current,
        writtenAt: Date = Date()
    ) -> DaybookEntry {
        let startOfDay = BookDay.startDate(for: day.id, fallback: day.date, calendar: calendar)
        var entry = DaybookEntry(
            dayID: dayID(for: startOfDay, calendar: calendar),
            date: startOfDay,
            fidelity: .reconstructed,
            calendar: calendar,
            writtenAt: writtenAt
        )

        let captured = day.capturedPages
        let contexts = captured.compactMap(\.context)

        // The snapshots agree far more often than not; where they disagree the
        // union is the honest reading of "what the sky did that day".
        entry.weatherTags = Array(Set(contexts.flatMap(\.weatherTags))).sorted()
        entry.bodyScore = medianInt(contexts.compactMap(\.bodyScore))
        entry.calendarEventCount = medianInt(contexts.compactMap(\.calendarEventCount))

        // Split body metrics, for days whose pages were kept after Phase 1.
        // Sleep is the night behind the whole day, so the first reading stands
        // for it; the rest take the median of what the day's pages saw.
        entry.sleepHours = contexts.compactMap(\.sleepHours).first
        entry.steps = medianInt(contexts.compactMap(\.steps))
        entry.restingHeartRate = medianInt(contexts.compactMap(\.restingHeartRate))
        entry.heartRateVariability = median(contexts.compactMap(\.heartRateVariability))
        entry.placeLabel = contexts.compactMap(\.locationLabel).first
        entry.nearbyAnchorID = contexts.compactMap(\.nearbyAnchorID).first
        entry.distinctPlaceCount = {
            let labels = Set(contexts.compactMap(\.locationLabel))
            return labels.isEmpty ? nil : labels.count
        }()
        entry.innerWeatherEntryID = contexts.compactMap(\.innerWeatherEntryID).first
        entry.fuelEntryID = contexts.compactMap(\.fuelEntryID).first

        entry.deskWasSeen = !captured.isEmpty
        applyPageCounts(to: &entry, day: day, calendar: calendar)

        return entry
    }

    /// A day that passed with nothing recorded. It exists to be counted.
    static func absent(
        dayID id: String,
        date: Date,
        calendar: Calendar = .current,
        writtenAt: Date = Date()
    ) -> DaybookEntry {
        DaybookEntry(
            dayID: id,
            date: calendar.startOfDay(for: date),
            fidelity: .absent,
            calendar: calendar,
            writtenAt: writtenAt
        )
    }

    // MARK: Backfill

    /// The days between the last recorded row and today that have no row yet,
    /// oldest first, capped so a long absence cannot stall a launch.
    ///
    /// Today is excluded: the live tick owns it, and a `.absent` row written at
    /// 00:01 would otherwise have to be corrected an hour later.
    static func missingDays(
        recordedDayIDs: Set<String>,
        through now: Date,
        earliest: Date?,
        calendar: Calendar = .current,
        cap: Int = backfillCapDays
    ) -> [(dayID: String, date: Date)] {
        let today = calendar.startOfDay(for: now)
        guard let capStart = calendar.date(byAdding: .day, value: -cap, to: today) else { return [] }
        var cursor = max(capStart, earliest.map { calendar.startOfDay(for: $0) } ?? capStart)
        var out: [(dayID: String, date: Date)] = []
        while cursor < today {
            let id = dayID(for: cursor, calendar: calendar)
            if !recordedDayIDs.contains(id) {
                out.append((id, cursor))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }

    /// The rows to write for a gap: reconstructed where the archive has a day
    /// with kept pages, absent where it does not.
    static func backfill(
        recordedDayIDs: Set<String>,
        days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current,
        cap: Int = backfillCapDays
    ) -> [DaybookEntry] {
        var archived: [String: BookDay] = [:]
        for day in days {
            let start = BookDay.startDate(for: day.id, fallback: day.date, calendar: calendar)
            archived[dayID(for: start, calendar: calendar)] = day
        }
        let earliest = days
            .map { BookDay.startDate(for: $0.id, fallback: $0.date, calendar: calendar) }
            .min()

        return missingDays(
            recordedDayIDs: recordedDayIDs,
            through: now,
            earliest: earliest,
            calendar: calendar,
            cap: cap
        ).map { missing in
            if let day = archived[missing.dayID], !day.capturedPages.isEmpty {
                return reconstructed(day: day, calendar: calendar, writtenAt: now)
            }
            return absent(dayID: missing.dayID, date: missing.date, calendar: calendar, writtenAt: now)
        }
    }

    // MARK: Reconciliation

    /// A day's row is written while the day is still moving. If the reader keeps
    /// pages after the last tick and the app is killed rather than backgrounded,
    /// the row keeps counts that the archive has since outgrown, and the gap
    /// walk will not revisit it, because the day already has a row.
    ///
    /// Returns an updated row when the archive disagrees with what was recorded,
    /// and nil when the row is already true. Fidelity is preserved: this corrects
    /// a live row's arithmetic, it does not demote it to a reconstruction.
    static func reconciled(
        entry: DaybookEntry,
        with day: BookDay,
        calendar: Calendar = .current,
        writtenAt: Date = Date()
    ) -> DaybookEntry? {
        guard entry.fidelity != .absent || !day.capturedPages.isEmpty else { return nil }

        var updated = entry
        applyPageCounts(to: &updated, day: day, calendar: calendar)
        if entry.fidelity == .absent, !day.capturedPages.isEmpty {
            // The day turned out not to be empty after all.
            updated.fidelity = .reconstructed
            updated.deskWasSeen = true
        }
        guard updated != entry else { return nil }
        updated.writtenAt = writtenAt
        return updated
    }

    /// Rows in the trailing window whose counts the archive has moved past.
    static func reconciliations(
        entries: [DaybookEntry],
        days: [BookDay],
        within window: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DaybookEntry] {
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -window,
            to: calendar.startOfDay(for: now)
        ) else { return [] }

        var archived: [String: BookDay] = [:]
        for day in days {
            let start = BookDay.startDate(for: day.id, fallback: day.date, calendar: calendar)
            archived[dayID(for: start, calendar: calendar)] = day
        }

        return entries.compactMap { entry in
            guard entry.date >= cutoff, let day = archived[entry.dayID] else { return nil }
            return reconciled(entry: entry, with: day, calendar: calendar, writtenAt: now)
        }
    }

    // MARK: Shared shaping

    static func applyBodyMetrics(to entry: inout DaybookEntry, from body: BodySourceSignal) {
        entry.sleepHours = body.metricValue(.sleep)
        entry.steps = body.metricValue(.steps).map { Int($0) }
        entry.restingHeartRate = body.metricValue(.restingHeartRate).map { Int($0) }
        entry.heartRateVariability = body.metricValue(.heartRateVariability)
        entry.activeKilocalories = body.metricValue(.activeEnergy)
        entry.distanceMiles = body.metricValue(.distance)
    }

    private static func applyPageCounts(
        to entry: inout DaybookEntry,
        day: BookDay?,
        calendar: Calendar
    ) {
        guard let day else { return }
        let captured = day.capturedPages
        entry.keptPageCount = captured.count
        entry.keptPageTypes = Array(Set(captured.map(\.type.rawValue))).sorted()

        let written = captured.map(\.userInput).filter { !$0.isEmpty }
        entry.medianWordsWritten = medianInt(written.map(wordCount))
        entry.dayInkTone = ContextWeave.tone(of: written.joined(separator: " "))?.rawValue
    }

    private static func applyInteractionCounts(
        to entry: inout DaybookEntry,
        learning: ReaderLearningModel,
        dayID id: String
    ) {
        let todays = learning.events.filter { $0.dayID == id }
        entry.openedCount = todays.filter { $0.action == .opened }.count
        entry.dismissedCount = todays.filter { $0.action == .dismissed }.count
        entry.sessionCount = sessionCount(from: todays.map(\.occurredAt))
    }

    /// A session is a run of interactions with no half-hour gap in it. Coarse on
    /// purpose: this is a rhythm signal, not attendance.
    static func sessionCount(from moments: [Date], gap: TimeInterval = 30 * 60) -> Int {
        let sorted = moments.sorted()
        guard let first = sorted.first else { return 0 }
        var count = 1
        var previous = first
        for moment in sorted.dropFirst() {
            if moment.timeIntervalSince(previous) > gap { count += 1 }
            previous = moment
        }
        return count
    }

    // MARK: Small measures

    static func temperatureBand(from weather: WeatherSourceSignal?) -> String? {
        guard let weather, weather.isAvailable else { return nil }
        let haystack = "\(weather.phrase) \(weather.currentTemperature ?? "")".lowercased()
        guard let value = firstTemperature(in: haystack) else { return nil }
        // The phrase carries its own unit; Fahrenheit is the app's display
        // default, so a bare number is read as Fahrenheit.
        let fahrenheit = haystack.contains("c") && !haystack.contains("f")
            ? value * 9 / 5 + 32
            : value
        if fahrenheit <= 45 { return "cold" }
        if fahrenheit >= 80 { return "hot" }
        return "mild"
    }

    private static func firstTemperature(in text: String) -> Double? {
        var digits = ""
        var sawMinus = false
        for character in text {
            if character.isNumber {
                digits.append(character)
            } else if character == "-" && digits.isEmpty {
                sawMinus = true
            } else if !digits.isEmpty {
                break
            }
        }
        guard let value = Double(digits) else { return nil }
        return sawMinus ? -value : value
    }

    static func daylightMinutes(
        on date: Date,
        at coordinate: ReaderCoordinate,
        calendar: Calendar = .current
    ) -> Int? {
        guard let sunrise = SolarClock.sunrise(on: date, at: coordinate, calendar: calendar),
              let sunset = SolarClock.sunset(on: date, at: coordinate, calendar: calendar),
              sunset > sunrise else { return nil }
        return Int(sunset.timeIntervalSince(sunrise) / 60)
    }

    /// The longest stretch of the waking day (07:00–23:00) with nothing booked
    /// in it. Days with no events return the whole window.
    static func longestOpenBlockMinutes(
        events: [CalendarEventSignal],
        on date: Date,
        calendar: Calendar = .current,
        wakingStartHour: Int = 7,
        wakingEndHour: Int = 23
    ) -> Int? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .hour, value: wakingStartHour, to: startOfDay),
              let windowEnd = calendar.date(byAdding: .hour, value: wakingEndHour, to: startOfDay),
              windowEnd > windowStart else { return nil }

        let busy = events
            .map { event -> (Date, Date) in
                // An event with no end is treated as an hour: long enough to
                // break a free block, short enough not to swallow the day.
                let rawEnd = event.endsAt.map { max($0, event.startsAt) }
                    ?? event.startsAt.addingTimeInterval(3600)
                return (max(event.startsAt, windowStart), min(rawEnd, windowEnd))
            }
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }

        var longest: TimeInterval = 0
        var cursor = windowStart
        for (start, end) in busy {
            if start > cursor {
                longest = max(longest, start.timeIntervalSince(cursor))
            }
            cursor = max(cursor, end)
        }
        longest = max(longest, windowEnd.timeIntervalSince(cursor))
        return Int(longest / 60)
    }

    static func wordCount(_ text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }

    static func medianInt(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
}
