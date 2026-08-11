import Foundation

// MARK: - The Standing Ledger
//
// The Daybook is the raw record; this is what gets posted from it. Baselines the
// reader is measured against (their own, never a population's) plus the deltas,
// streaks and marks that fall out of comparing today to them.
//
// Everything here is INTERNAL. No type in this file may render itself into
// prose, and none of them carries a `description` or any speakable string. The
// two reasons are not symmetric and both matter:
//
// - The aliveness pulse is reader-answered. Shown as a score, it becomes a score
//   the reader answers to protect, which corrupts the one input the whole twin
//   rests on. It is the single measurement here that cannot be displayed without
//   changing it.
// - The Rut doctrine's second rule is that it makes story, not shame. A visible
//   rising rut number is a shame gauge with a lamp on it.
//
// What the Ledger is *for* is gating: how bold a claim may be, how many
// interruptions the Book may spend, what shape the desk takes, when to ask for a
// pulse at all. The reader meets its effects and never its arithmetic.

// MARK: Fields

/// The numeric series the Ledger tracks out of the Daybook. Adding a case here
/// is all it takes to give a field a baseline, a delta, and a streak.
enum StandingField: String, Codable, CaseIterable {
    case sleepHours
    case steps
    case restingHeartRate
    case heartRateVariability
    case bodyScore
    case calendarEventCount
    case longestOpenBlockMinutes
    case daylightMinutes
    case keptPageCount
    case medianWordsWritten
    case openedCount
    case sessionCount
    case alivenessScore
    case wonderScore
    case hiddenMagicScore
    case capacityScore
    case beliefScoreAtClose
    case rutPressure

    /// Whether a rise in this field is a rise in something good. Used only to
    /// orient a direction internally; the Ledger never says so out loud.
    var higherIsBrighter: Bool? {
        switch self {
        case .sleepHours, .heartRateVariability, .bodyScore, .longestOpenBlockMinutes,
             .keptPageCount, .alivenessScore, .wonderScore, .hiddenMagicScore,
             .capacityScore, .beliefScoreAtClose:
            return true
        case .restingHeartRate, .rutPressure:
            return false
        case .steps, .calendarEventCount, .daylightMinutes, .medianWordsWritten,
             .openedCount, .sessionCount:
            // Genuinely ambiguous. More steps is not better; more words is not
            // better. These are read as change, never as improvement.
            return nil
        }
    }

    func value(in entry: DaybookEntry) -> Double? {
        switch self {
        case .sleepHours: return entry.sleepHours
        case .steps: return entry.steps.map(Double.init)
        case .restingHeartRate: return entry.restingHeartRate.map(Double.init)
        case .heartRateVariability: return entry.heartRateVariability
        case .bodyScore: return entry.bodyScore.map(Double.init)
        case .calendarEventCount: return entry.calendarEventCount.map(Double.init)
        case .longestOpenBlockMinutes: return entry.longestOpenBlockMinutes.map(Double.init)
        case .daylightMinutes: return entry.daylightMinutes.map(Double.init)
        case .keptPageCount: return Double(entry.keptPageCount)
        case .medianWordsWritten: return entry.medianWordsWritten.map(Double.init)
        case .openedCount: return Double(entry.openedCount)
        case .sessionCount: return Double(entry.sessionCount)
        case .alivenessScore: return entry.alivenessScore.map(Double.init)
        case .wonderScore: return entry.wonderScore.map(Double.init)
        case .hiddenMagicScore: return entry.hiddenMagicScore.map(Double.init)
        case .capacityScore: return entry.capacityScore.map(Double.init)
        case .beliefScoreAtClose: return entry.beliefScoreAtClose.map(Double.init)
        case .rutPressure: return entry.rutPressure.map(Double.init)
        }
    }

    /// Fields whose zero is a real reading rather than a missing one. For the
    /// rest, an `.absent` day contributes nothing rather than a zero: otherwise
    /// a week away would teach the Book that the reader sleeps zero hours.
    var countsOnAbsentDays: Bool {
        switch self {
        case .keptPageCount, .openedCount, .sessionCount: return true
        default: return false
        }
    }
}

// MARK: Gates

/// Minimum evidence before anything may be acted on. Deliberately conservative:
/// a wrong lean here costs trust in everything else the Book does.
enum StandingGate {
    /// Real values needed in a 28-day window before a delta may be read.
    static let shortWindowMinimum = 14
    /// Real values needed in a 90-day window before a trend may be read.
    static let longWindowMinimum = 45
    /// Days of Daybook history before the Ledger says anything at all.
    static let minimumTenureDays = 21

    static let shortWindow = 28
    static let longWindow = 90
}

// MARK: Baselines

/// Median and median-absolute-deviation rather than mean and standard
/// deviation: robust to the one eighteen-hour sleep, and honest at the small
/// sample sizes this will live at for months.
struct StandingBaseline: Codable, Equatable {
    var field: StandingField
    var window: Int
    var median: Double
    var medianAbsoluteDeviation: Double
    var sampleCount: Int

    /// Whether this baseline has enough behind it to be leaned on.
    var isTrustworthy: Bool {
        window <= StandingGate.shortWindow
            ? sampleCount >= StandingGate.shortWindowMinimum
            : sampleCount >= StandingGate.longWindowMinimum
    }
}

// MARK: Deltas

/// Where today sits against the reader's own usual, in bands. The Ledger deals
/// in bands rather than numbers so that no caller is tempted to render one.
enum StandingBand: String, Codable, Equatable {
    case wellBelow
    case below
    case usual
    case above
    case wellAbove

    /// Bands as a signed step, for arithmetic in gating decisions.
    var step: Int {
        switch self {
        case .wellBelow: return -2
        case .below: return -1
        case .usual: return 0
        case .above: return 1
        case .wellAbove: return 2
        }
    }
}

struct StandingDelta: Codable, Equatable {
    var field: StandingField
    var band: StandingBand
    var sampleCount: Int

    /// True only when the band rests on enough days to be worth acting on.
    var isTrustworthy: Bool {
        sampleCount >= StandingGate.shortWindowMinimum
    }
}

// MARK: Streaks

struct StandingStreak: Codable, Equatable {
    var field: StandingField
    /// Positive for consecutive days above the median, negative for below.
    var length: Int
    var isAbove: Bool
}

// MARK: Marks: firsts and lasts

/// Days since something last happened. Cheap to compute and unusually
/// evocative: "forty days since the kitchen table" is a whole story.
struct StandingMark: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case daysSinceKeptPage
        case daysSincePlace
        case daysSincePageType
        case daysSinceAnsweredPulse
        case daysSinceFieldObserved
    }

    var kind: Kind
    /// Place label, page type, or field name: empty for the kinds that need no
    /// subject.
    var subject: String
    var days: Int
}

// MARK: The Rut trajectory

/// The Rut has never had a trend, only a standing value recomputed on demand.
/// The series is stepped rather than smooth: pressure moves only when the
/// reader answers `rut-depth` again, so this reports levels and how long they
/// have held, not a slope.
struct RutTrajectory: Codable, Equatable {
    enum Direction: String, Codable, Equatable {
        case notEnoughEvidence
        case easing
        case standing
        case deepening
    }

    var direction: Direction
    var currentPressure: Int?
    var pressureThirtyDaysAgo: Int?
    /// How long the current level has held, in days.
    var daysAtCurrentLevel: Int
    /// Whether the reader has ever given the Book the standing to name it. This
    /// mirrors `NothingTide.mayNameRut` and is carried here only so a caller
    /// need not recompute it; the Ledger never widens the permission.
    var mayName: Bool

    static let unwritten = RutTrajectory(
        direction: .notEnoughEvidence,
        currentPressure: nil,
        pressureThirtyDaysAgo: nil,
        daysAtCurrentLevel: 0,
        mayName: false
    )
}

// MARK: The aliveness trend

/// `ReaderReenchantmentMetrics` already computes a direction, but only across
/// days the reader answered a pulse, which is not a random sample of a life.
/// This reads the same question against the Daybook, where every day has a row,
/// and reports its own coverage so a caller can discount it honestly.
struct AlivenessTrend: Codable, Equatable {
    enum Direction: String, Codable, Equatable {
        case notEnoughEvidence
        case dimming
        case holding
        case brightening
    }

    var direction: Direction
    /// Days in the recent window that carried an answer, over days in the
    /// window. Low coverage is not a reason to guess; it is a reason to ask.
    var answeredDays: Int
    var windowDays: Int
    /// 0–100. Rises with coverage and with the number of distinct answered days.
    var confidence: Int

    var coverage: Double {
        windowDays > 0 ? Double(answeredDays) / Double(windowDays) : 0
    }

    /// Below this, the Book should be asking for a pulse rather than leaning on
    /// the trend it already has.
    var isThin: Bool {
        coverage < 0.25 || answeredDays < 4
    }

    static let unwritten = AlivenessTrend(
        direction: .notEnoughEvidence,
        answeredDays: 0,
        windowDays: 0,
        confidence: 0
    )
}

// MARK: The Ledger

struct StandingLedger: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = StandingLedger.currentVersion
    var computedAt: Date
    var dayCount: Int
    var evidenceDayCount: Int
    var tenureDays: Int
    var baselines: [StandingBaseline]
    var deltas: [StandingDelta]
    var streaks: [StandingStreak]
    var marks: [StandingMark]
    var rut: RutTrajectory
    var aliveness: AlivenessTrend

    static let unwritten = StandingLedger(
        computedAt: .distantPast,
        dayCount: 0,
        evidenceDayCount: 0,
        tenureDays: 0,
        baselines: [],
        deltas: [],
        streaks: [],
        marks: [],
        rut: .unwritten,
        aliveness: .unwritten
    )

    /// The Ledger stays quiet until it has enough history to be worth consulting.
    var isReady: Bool {
        tenureDays >= StandingGate.minimumTenureDays
    }

    // MARK: Reading it

    func baseline(_ field: StandingField, window: Int = StandingGate.shortWindow) -> StandingBaseline? {
        baselines.first { $0.field == field && $0.window == window }
    }

    /// The band for a field, or nil when the evidence does not support one.
    /// Callers get a band and never a number, by design.
    func band(_ field: StandingField) -> StandingBand? {
        guard isReady else { return nil }
        guard let delta = deltas.first(where: { $0.field == field }), delta.isTrustworthy else {
            return nil
        }
        return delta.band
    }

    func streak(_ field: StandingField) -> StandingStreak? {
        guard isReady else { return nil }
        return streaks.first { $0.field == field }
    }

    func mark(_ kind: StandingMark.Kind, subject: String = "") -> StandingMark? {
        marks.first { $0.kind == kind && $0.subject == subject }
    }
}

// MARK: - What the Ledger is for

/// The small set of coarse decisions the twin is allowed to make. This is the
/// only door between the Ledger's arithmetic and the rest of the Book: callers
/// take a ceiling, a lean, or a boolean, and never a number. Keeping the door
/// this narrow is what makes "internal only" a property of the design rather
/// than a habit anyone has to remember.
struct TwinCurationGates: Equatable {
    /// The boldest a claim about the reader may be right now. Evidence still has
    /// to earn the tier; this only lowers the ceiling.
    var claimCeiling: BookClaimTier
    /// How the Book's knocking should be narrowed, if at all.
    var interruptionLean: InferredLean
    /// True when the aliveness trend is too thin to lean on, which is a reason
    /// to ask for a pulse rather than to guess at one.
    var wantsPulseAnswer: Bool
    /// Added to the reader-state pulse page's score when an answer is wanted.
    var pulseScoreBoost: Int

    static let neutral = TwinCurationGates(
        claimCeiling: .established,
        interruptionLean: .neutral,
        wantsPulseAnswer: false,
        pulseScoreBoost: 0
    )

    /// `signals` is the behavioural lane; `ledger` is the answered one. They are
    /// read together so a dark reading needs either two thin agreements or one
    /// firm one before it narrows anything.
    static func resolve(
        ledger: StandingLedger,
        signals: InferredReaderSignals
    ) -> TwinCurationGates {
        guard ledger.isReady else { return .neutral }

        let dimming = ledger.aliveness.direction == .dimming && !ledger.aliveness.isThin
        let flattening = signals.alivenessLean == .rutward
        let deepening = ledger.rut.direction == .deepening

        // A claim that lands wrong costs more on a dark week than it gains on a
        // bright one. The same sentence is a delight in one month and a
        // presumption in another, so the ceiling comes down before the Book
        // starts naming things about someone who is struggling.
        let claimCeiling: BookClaimTier
        switch (dimming || deepening, flattening) {
        case (true, true): claimCeiling = .glimmer
        case (true, false), (false, true): claimCeiling = .gathering
        case (false, false): claimCeiling = .established
        }

        // Leaning in hardest exactly when someone is depleted is the classic
        // failure of this whole genre of software.
        let interruptionLean: InferredLean = (dimming || flattening) ? .rutward : .neutral

        let wantsPulse = ledger.aliveness.isThin
        return TwinCurationGates(
            claimCeiling: claimCeiling,
            interruptionLean: interruptionLean,
            wantsPulseAnswer: wantsPulse,
            // Enough to lift the fresh-weather pulse (72) above the ordinary
            // desk without letting it outrank a delayed-outcome ask (88).
            pulseScoreBoost: wantsPulse ? 12 : 0
        )
    }
}

// MARK: - Posting the Daybook to the Ledger

enum StandingLedgerBuilder {
    /// Rows may arrive in any order; they are sorted here. Newest-first from the
    /// archive is the usual case.
    static func build(
        entries: [DaybookEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StandingLedger {
        let rows = entries.sorted { $0.date < $1.date }
        guard let earliest = rows.first?.date else { return .unwritten }

        let tenure = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earliest),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        let shortRows = window(rows, days: StandingGate.shortWindow, now: now, calendar: calendar)
        let longRows = window(rows, days: StandingGate.longWindow, now: now, calendar: calendar)

        var baselines: [StandingBaseline] = []
        var deltas: [StandingDelta] = []
        var streaks: [StandingStreak] = []

        for field in StandingField.allCases {
            if let short = baseline(field: field, rows: shortRows, window: StandingGate.shortWindow) {
                baselines.append(short)
                if let latest = latestValue(field, in: rows) {
                    deltas.append(
                        StandingDelta(
                            field: field,
                            band: band(value: latest, baseline: short),
                            sampleCount: short.sampleCount
                        )
                    )
                }
                if let streak = streak(field: field, rows: rows, median: short.median) {
                    streaks.append(streak)
                }
            }
            if let long = baseline(field: field, rows: longRows, window: StandingGate.longWindow) {
                baselines.append(long)
            }
        }

        return StandingLedger(
            computedAt: now,
            dayCount: rows.count,
            evidenceDayCount: rows.filter(\.carriesEvidence).count,
            tenureDays: max(0, tenure),
            baselines: baselines,
            deltas: deltas,
            streaks: streaks,
            marks: marks(rows: rows, now: now, calendar: calendar),
            rut: rutTrajectory(rows: rows, now: now, calendar: calendar),
            aliveness: alivenessTrend(rows: rows, now: now, calendar: calendar)
        )
    }

    // MARK: Windows and values

    static func window(
        _ rows: [DaybookEntry],
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> [DaybookEntry] {
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -days,
            to: calendar.startOfDay(for: now)
        ) else { return rows }
        return rows.filter { $0.date >= cutoff }
    }

    /// Values for a field, skipping days that cannot honestly answer for it. An
    /// `.absent` day contributes a zero for "how many pages were kept" and
    /// nothing at all for "how long did you sleep".
    static func values(_ field: StandingField, in rows: [DaybookEntry]) -> [Double] {
        rows.compactMap { row in
            guard row.carriesEvidence || field.countsOnAbsentDays else { return nil }
            return field.value(in: row)
        }
    }

    static func latestValue(_ field: StandingField, in rows: [DaybookEntry]) -> Double? {
        rows.reversed().first { row in
            (row.carriesEvidence || field.countsOnAbsentDays) && field.value(in: row) != nil
        }.flatMap { field.value(in: $0) }
    }

    // MARK: Baselines

    static func baseline(
        field: StandingField,
        rows: [DaybookEntry],
        window: Int
    ) -> StandingBaseline? {
        let observed = values(field, in: rows)
        guard let centre = median(observed) else { return nil }
        let deviations = observed.map { abs($0 - centre) }
        return StandingBaseline(
            field: field,
            window: window,
            median: centre,
            medianAbsoluteDeviation: median(deviations) ?? 0,
            sampleCount: observed.count
        )
    }

    /// Bands at one and two MADs. When the deviation is zero: a field that has
    /// not varied at all, only an exact match counts as usual, so a first move
    /// away from a flat line registers.
    static func band(value: Double, baseline: StandingBaseline) -> StandingBand {
        let spread = baseline.medianAbsoluteDeviation
        let difference = value - baseline.median
        guard spread > 0 else {
            if difference == 0 { return .usual }
            return difference > 0 ? .above : .below
        }
        let units = difference / spread
        if units <= -2 { return .wellBelow }
        if units <= -1 { return .below }
        if units >= 2 { return .wellAbove }
        if units >= 1 { return .above }
        return .usual
    }

    // MARK: Streaks

    static func streak(field: StandingField, rows: [DaybookEntry], median: Double) -> StandingStreak? {
        var length = 0
        var isAbove: Bool?

        for row in rows.reversed() {
            guard row.carriesEvidence || field.countsOnAbsentDays,
                  let value = field.value(in: row) else { continue }
            guard value != median else { break }
            let above = value > median
            if isAbove == nil { isAbove = above }
            guard above == isAbove else { break }
            length += 1
        }

        guard let isAbove, length >= 2 else { return nil }
        return StandingStreak(field: field, length: length, isAbove: isAbove)
    }

    // MARK: Marks

    static func marks(rows: [DaybookEntry], now: Date, calendar: Calendar) -> [StandingMark] {
        var out: [StandingMark] = []
        let today = calendar.startOfDay(for: now)

        func days(since date: Date) -> Int {
            max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0)
        }

        if let last = rows.last(where: { $0.keptPageCount > 0 }) {
            out.append(.init(kind: .daysSinceKeptPage, subject: "", days: days(since: last.date)))
        }
        if let last = rows.last(where: { $0.alivenessScore != nil }) {
            out.append(.init(kind: .daysSinceAnsweredPulse, subject: "", days: days(since: last.date)))
        }

        // Places the reader has actually been, most recent visit each.
        var lastSeenPlace: [String: Date] = [:]
        var lastSeenType: [String: Date] = [:]
        for row in rows {
            if let place = row.placeLabel, !place.isEmpty {
                lastSeenPlace[place] = row.date
            }
            for type in row.keptPageTypes {
                lastSeenType[type] = row.date
            }
        }
        for (place, date) in lastSeenPlace.sorted(by: { $0.key < $1.key }) {
            out.append(.init(kind: .daysSincePlace, subject: place, days: days(since: date)))
        }
        for (type, date) in lastSeenType.sorted(by: { $0.key < $1.key }) {
            out.append(.init(kind: .daysSincePageType, subject: type, days: days(since: date)))
        }

        for field in StandingField.allCases {
            guard let last = rows.last(where: { field.value(in: $0) != nil }) else { continue }
            out.append(.init(
                kind: .daysSinceFieldObserved,
                subject: field.rawValue,
                days: days(since: last.date)
            ))
        }

        return out
    }

    // MARK: The Rut

    static func rutTrajectory(rows: [DaybookEntry], now: Date, calendar: Calendar) -> RutTrajectory {
        let pressures = rows.compactMap { row -> (Date, Int)? in
            guard let pressure = row.rutPressure else { return nil }
            return (row.date, pressure)
        }
        guard let current = pressures.last else { return .unwritten }

        let mayName = rows.last(where: { $0.rutMayName != nil })?.rutMayName ?? false

        // How long the present level has held.
        var held = 0
        for (_, pressure) in pressures.reversed() {
            guard pressure == current.1 else { break }
            held += 1
        }

        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)),
              let earlier = pressures.last(where: { $0.0 <= thirtyDaysAgo })?.1,
              pressures.count >= 8 else {
            return RutTrajectory(
                direction: .notEnoughEvidence,
                currentPressure: current.1,
                pressureThirtyDaysAgo: nil,
                daysAtCurrentLevel: held,
                mayName: mayName
            )
        }

        let direction: RutTrajectory.Direction
        if current.1 > earlier {
            direction = .deepening
        } else if current.1 < earlier {
            direction = .easing
        } else {
            direction = .standing
        }

        return RutTrajectory(
            direction: direction,
            currentPressure: current.1,
            pressureThirtyDaysAgo: earlier,
            daysAtCurrentLevel: held,
            mayName: mayName
        )
    }

    // MARK: Aliveness

    static func alivenessTrend(rows: [DaybookEntry], now: Date, calendar: Calendar) -> AlivenessTrend {
        let recent = window(rows, days: StandingGate.shortWindow, now: now, calendar: calendar)
        let answered = recent.filter { $0.alivenessScore != nil }
        let windowDays = max(recent.count, 1)

        // Coverage matters as much as count, and it matters whether or not a
        // direction can be read: eight answers across four weeks of silence is
        // a thinner thing to hold than eight across eight days. This is why the
        // trend is read off the Daybook and not off the pulse ledger, where the
        // unanswered days simply do not exist.
        let coverage = Double(answered.count) / Double(windowDays)
        let confidence = min(96, Int(coverage * 60) + answered.count * 4)

        func unread() -> AlivenessTrend {
            AlivenessTrend(
                direction: .notEnoughEvidence,
                answeredDays: answered.count,
                windowDays: windowDays,
                confidence: confidence
            )
        }

        guard answered.count >= 4,
              let midpoint = calendar.date(
                  byAdding: .day,
                  value: -StandingGate.shortWindow / 2,
                  to: calendar.startOfDay(for: now)
              ) else {
            return unread()
        }

        // A change needs a before and an after. Answers clustered entirely in
        // one half of the window describe a mood, not a direction.
        let early = answered.filter { $0.date < midpoint }.compactMap(\.alivenessScore).map(Double.init)
        let late = answered.filter { $0.date >= midpoint }.compactMap(\.alivenessScore).map(Double.init)

        guard let earlyMean = mean(early), let lateMean = mean(late) else {
            return unread()
        }

        let change = lateMean - earlyMean
        let direction: AlivenessTrend.Direction
        if change >= 0.75 {
            direction = .brightening
        } else if change <= -0.75 {
            direction = .dimming
        } else {
            direction = .holding
        }

        return AlivenessTrend(
            direction: direction,
            answeredDays: answered.count,
            windowDays: windowDays,
            confidence: confidence
        )
    }

    // MARK: Small measures

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
