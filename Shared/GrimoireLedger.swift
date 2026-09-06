import Foundation

// MARK: - What a feature is

/// Whether a feature can stand on the left of a correspondence, the right, or
/// either. Weather is a condition and never an outcome; *you kept a Diary Page*
/// is an outcome and never a cause of rain. Declaring this on the feature
/// halves the pair space for free and keeps nonsense out of the ledger.
enum LoomFeatureRole: String, Codable, Equatable {
    case conditionOnly
    case outcomeOnly
    case either
}

/// How much care a claim about this feature needs. The Book is allowed to be
/// direct; it is not allowed to be a diagnosis.
enum LoomSensitivity: String, Codable, Equatable {
    case ordinary
    /// A state the reader explicitly reported. It may be repeated back as a
    /// dated observation, but never enlarged into a diagnosis or identity.
    case readerReported
    /// The reader's inner state or body. Never a diagnosis, never a cause.
    case innerState
    /// A real person. The Witness Law applies.
    case person
}

/// Where the fact came from. This is what mechanically enforces the standing
/// law that fiction may set a scene but may never become evidence about the
/// reader's actual life.
enum LoomProvenance: String, Codable, Equatable {
    case readerAuthored
    case observedContext
    case systemEvent
    case generatedFiction
}

/// One trustworthy dimension of a day.
///
/// A projector builds these; the engine never asks what kind of thing it is
/// looking at. That is the point: adding music, or tides, or how long a Page
/// was open, means writing a projector, not editing the engine.
struct LoomFeatureRef: Codable, Equatable, Hashable {
    var id: String
    /// The family this belongs to, as a plain string so new projectors need no
    /// enum case and no switch statement anywhere in the engine.
    var domain: String
    var label: String
    /// A clause that can follow "When": "it was raining".
    var conditionClause: String
    /// A complete lower-case statement: "you kept a Diary Page".
    var outcomeClause: String
    var symbolName: String
    var role: LoomFeatureRole
    var sensitivity: LoomSensitivity
    var provenance: LoomProvenance
    /// Lower sorts earlier when the Book has to choose which half of a pair
    /// reads as the cause. Circumstances outrank acts.
    var rank: Int

    init(
        id: String,
        domain: String,
        label: String,
        conditionClause: String,
        outcomeClause: String,
        symbolName: String = "sparkle",
        role: LoomFeatureRole = .either,
        sensitivity: LoomSensitivity = .ordinary,
        provenance: LoomProvenance = .observedContext,
        rank: Int = 50
    ) {
        self.id = id
        self.domain = domain
        self.label = label
        self.conditionClause = conditionClause
        self.outcomeClause = outcomeClause
        self.symbolName = symbolName
        self.role = role
        self.sensitivity = sensitivity
        self.provenance = provenance
        self.rank = rank
    }
}

/// One day, as some projector saw it.
struct LoomObservation: Equatable {
    var id: String
    var day: Int
    var occurredAt: Date
    var features: [LoomFeatureRef]
    var evidencePageID: String?
    var evidenceLine: String
    /// This receipt exists because the Book asked for it.
    ///
    /// A Working the Book set, an errand a talisman demanded — the reader did
    /// these, but they did them *because they were asked*. Counting them as
    /// free evidence lets the Book arrange the very behaviour it then treats as
    /// proof, which is how a belief quietly becomes self-fulfilling.
    var bookAsked: Bool = false
}

// MARK: - What a correspondence is

/// The shapes a correspondence can take. Every one of them is a word operation
/// over the same stored day-sets, which is why the Book can look for all of
/// them without reading the archive again.
enum GrimoireShape: String, Codable, Equatable, CaseIterable {
    /// Two things keep landing on the same day.
    case conditional
    /// One thing keeps following the other within a few days.
    case sequential
    /// One thing keeps coming back at the same time of year.
    case seasonal
    /// Two members of one family, compared against the same outcome.
    case sibling
    /// One thing that goes quiet for a long while and keeps coming back.
    case returnInterval
}

/// Where a claim stands in the Book's own head.
enum GrimoireClaimState: String, Codable, Equatable {
    /// Real enough to keep counting, not yet said out loud.
    case watching
    /// Said once. A falsifier is committed and running.
    case spoken
    /// Part of what the Book knows. It may lean on this.
    case standing
    /// It failed its own test. Kept visibly, not deleted.
    case crossedOut
    /// The reader shut this door. It never opens again.
    case forbidden
}

/// The Book's promise, made in advance, about what would prove it wrong.
///
/// This is what pays for the plain speaking. The Book does not hedge a
/// correspondence into meaninglessness; it states the thing and commits to the
/// count that would take it back, then honours the commitment without being
/// asked.
struct GrimoireFalsifier: Codable, Equatable {
    var committedAt: Date
    /// What it looked like when the Book committed. Kept as a record of the
    /// promise rather than as arithmetic: the verdict counts its own window.
    var baselineInCount: Int
    var baselineInHits: Int
    /// The claim breaks if the rate over *new* chances falls under this.
    var floorRate: Double
    /// How many new chances have to happen before the test is allowed to bite.
    var opportunitiesRequired: Int
    /// The Book's own words for the promise.
    var line: String

    enum Verdict: Equatable {
        case waiting(seen: Int, needed: Int)
        case holding(rate: Double)
        case broken(rate: Double, chances: Int)
    }

    /// Judged on chances counted directly, not on the difference between two
    /// totals.
    ///
    /// Subtracting a baseline only works while both numbers are taken over the
    /// same set of days. They are not: the baseline is the whole archive, and
    /// the verdict is measured on the days the Book kept quiet. Differencing
    /// the two can go negative, and a negative count reads as "not enough
    /// chances yet" — which would leave every promise silently unfalsifiable
    /// forever. The ledger counts the window itself and hands it over.
    func verdict(chances: Int, held: Int) -> Verdict {
        guard chances >= opportunitiesRequired else {
            return .waiting(seen: max(0, chances), needed: opportunitiesRequired)
        }
        let rate = chances > 0 ? Double(held) / Double(chances) : 0
        return rate < floorRate ? .broken(rate: rate, chances: chances) : .holding(rate: rate)
    }
}

/// One turn of the Book changing its mind, kept forever.
struct GrimoireRevision: Codable, Equatable {
    var at: Date
    var from: GrimoireClaimState
    var to: GrimoireClaimState
    var because: String
}

/// A row in the grimoire.
///
/// Deliberately light: no day-sets live here. Those are stored once per
/// feature and intersected on demand, which is both smaller and faster than
/// keeping a copy on every pair that mentions them.
struct GrimoireCorrespondence: Codable, Equatable, Identifiable {
    var id: String
    var shape: GrimoireShape
    var conditionID: String
    /// Absent for shapes about a single thing returning, like `seasonal`.
    var outcomeID: String?
    var state: GrimoireClaimState
    var firstObservedAt: Date
    var lastObservedAt: Date
    var falsifier: GrimoireFalsifier?
    var revisions: [GrimoireRevision]
    var readerStatus: BookObservationStatus?
    var lastSpokenAt: Date?
    /// Days the Book had recently put this correspondence in front of the
    /// reader by saying it.
    ///
    /// Evidence from these days is not independent of the claim, and the
    /// falsifier is measured *entirely* on days after the Book spoke, so
    /// without this the test is run on exactly the contaminated window.
    var promptedDays: DayBitset = DayBitset()
    var strengthPeak: Int
    var interestPeak: Int
    /// `sibling` only: the member of the same family that was compared against
    /// and lost. Optional so every row written before this decodes unchanged.
    var rivalID: String? = nil
    /// `seasonal` only: the exact turn of the year the Book committed to.
    ///
    /// Kept on the row so later evidence cannot silently change "spring" into
    /// "autumn" while pretending it is still the same claim.
    var season: Int? = nil


    var isAlive: Bool { state != .crossedOut && state != .forbidden }
    var hasSpoken: Bool { lastSpokenAt != nil }

    /// A stable key, safe to hand to a permanent "do not read me this way"
    /// boundary: it does not move when the evidence grows.
    static func key(
        shape: GrimoireShape,
        condition: String,
        outcome: String?,
        rival: String? = nil,
        season: Int? = nil
    ) -> String {
        if shape == .seasonal, let season { return "\(shape.rawValue):\(condition)@\(season)" }
        // The rival belongs in the key: "routes beat object hunts" and "routes
        // beat errands" are two different claims about the same pair.
        if let rival, let outcome { return "\(shape.rawValue):\(condition)|\(rival)->\(outcome)" }
        if let outcome { return "\(shape.rawValue):\(condition)->\(outcome)" }
        return "\(shape.rawValue):\(condition)"
    }
}

/// What the Book got done while nobody was watching.
///
/// The sweep runs on idle, so "while you were gone I worked something out" is
/// not a flourish here — it is a receipt. Kept so the Book can leave a small
/// mark of it on a quiet leaf, once, without ever making the absence the point.
struct GrimoireTendingMark: Codable, Equatable {
    var at: Date
    var found: Int
    var crossedOut: Int
    /// The one thing worth mentioning, already in the Book's own words.
    var line: String?
    /// Left once and then let go. A residue that repeats is wallpaper.
    var shownAt: Date?

    var isWorthMentioning: Bool { shownAt == nil && (found > 0 || crossedOut > 0) }
}

// MARK: - What the numbers say

struct GrimoireStats: Equatable {
    /// Days the condition and the outcome both happened.
    var inHits: Int = 0
    /// Days the condition happened at all.
    var inCount: Int = 0
    /// Days the outcome happened without the condition.
    var outHits: Int = 0
    /// Days the condition did not happen.
    var outCount: Int = 0
    var firstDay: Int?
    var lastDay: Int?
    var distinctYears: Int = 0
    var distinctSeasons: Int = 0
    /// Seasonal shapes only: turns of the season it showed up for, and turns
    /// it was expected and missing. "Every spring but one" lives here.
    var seasonsPresent: Int = 0
    var seasonsMissed: Int = 0
    /// The same test run over the first and second halves of the archive, so
    /// the Book can notice a correspondence loosening.
    var earlyRate: Double = 0
    var lateRate: Double = 0

    var inRate: Double { inCount > 0 ? Double(inHits) / Double(inCount) : 0 }
    var outRate: Double { outCount > 0 ? Double(outHits) / Double(outCount) : 0 }
    var lift: Double {
        guard outRate > 0 else { return inRate > 0 ? Double.infinity : 0 }
        return inRate / outRate
    }
    var rateGap: Double { inRate - outRate }
    var distinctDays: Int { inHits }

    /// 0...100. How much the counts alone support the claim.
    var strength: Int {
        guard inCount > 0, inHits > 0 else { return 0 }
        let liftScore = lift.isFinite ? min(1.0, (lift - 1.0) / 4.0) : 1.0
        let gapScore = min(1.0, max(0, rateGap) / 0.6)
        let weightScore = min(1.0, Double(inHits) / 10.0)
        return Int(((liftScore * 0.4 + gapScore * 0.35 + weightScore * 0.25) * 100).rounded())
    }
}

// MARK: - The ledger

/// The Book's accumulated private knowledge.
///
/// Two tables and nothing else: what every feature's days look like, and which
/// pairs are worth a row. The desk only ever *reads* this. Discovery happens in
/// `sweep`, off the main thread, in bounded chunks, on idle.
struct GrimoireLedger: Codable, Equatable {

    // MARK: Bars
    //
    // Deliberately the same numbers the Relational Loom already uses. The Book
    // must not keep two different standards for what counts as true.
    enum Bars {
        static let minimumUniverse = 5
        static let minimumInCount = 4
        static let minimumOutCount = 4
        static let minimumHits = 3
        static let minimumDistinctDays = 3
        static let minimumInRate = 0.55
        static let minimumRateGap = 0.30
        static let minimumLift = 1.8
        /// A claim only becomes something the Book leans on at this much
        /// evidence spread over this many days.
        static let standingHits = 8
        static let standingDays = 5
        /// How many pairs the ledger will remember at most. Past this it stops
        /// taking on new ones rather than growing without limit.
        static let maximumPairs = 250_000
        /// The reader's own hand is the strongest evidence there is, so a
        /// sequence window measured in days is enough. Longer than this and
        /// coincidence starts doing the work.
        static let sequenceWindow = 3
        /// What counts as the thing having *gone*, rather than merely not
        /// happening on a Tuesday. Three weeks is long enough that coming back
        /// is a return and not a rhythm.
        static let returnGapDays = 21
        /// Coming back twice is a coincidence with a long middle.
        static let minimumReturns = 3
        /// A feature seen on a single day can never reach the three-day bar.
        /// After this long it is not going to grow either, so it stops paying
        /// rent. Long enough that a word used once in March still has a whole
        /// season to be used again.
        static let pruneStaleDays = 120
        /// How long the Book's own telling keeps colouring a day. Tell someone
        /// rain brings out a word and they notice the word in the rain; a week
        /// is a fair guess at how long that lasts.
        static let promptedShadowDays = 7
        /// A sibling comparison needs both members to have had a real run of
        /// chances, and the winner to be clearly ahead — not ahead by noise.
        static let siblingMinimumRivalCount = 4
        static let siblingMinimumRateGap = 0.35
        static let siblingMinimumRatio = 2.0
        /// How many things the Book may be *sure* of at once.
        ///
        /// A Book holding three hundred laws is a database. One that can hold
        /// seven is a character with convictions, and having to let one go to
        /// make room is an event worth saying out loud.
        static let maximumHeld = 7
        /// How often the Book leads with its least expected reading instead of
        /// its strongest one.
        static let wagerIntervalDays = 7
        /// How long a correspondence rests after being said. The Book has
        /// better manners than to lead with its favourite fact every night.
        static let restDays = 14
    }

    // MARK: Stored

    /// Every day some projector had something to say about. The denominator.
    private(set) var universe = DayBitset()
    private(set) var featureIDs: [String] = []
    private(set) var featureRefs: [LoomFeatureRef] = []
    private(set) var featureDays: [DayBitset] = []
    /// Where a feature's Page differs from its day's default.
    ///
    /// A day can hold several Pages, and the features of the second are not
    /// evidence for a claim carried by the first — showing the wrong one means
    /// the Book displays receipts that do not contain what it is claiming.
    ///
    /// Only the exceptions are kept. Most days have one Page, and on the rest
    /// most features still come from the day's first, so this costs in
    /// proportion to genuine ambiguity rather than to the size of the archive.
    /// Storing it for every feature instead cost 229KB of a 499KB save.
    /// Days whose receipts exist because the Book asked for them.
    ///
    /// Separate from a correspondence's own shadow: that one is about the Book
    /// having *said* a thing, this one about the Book having *arranged* it. A
    /// promise is judged on neither.
    private(set) var bookAskedDays = DayBitset()
    /// Tests the Book has run on its own rules, oldest first.
    var experiments: [GrimoireExperiment] = []
    private(set) var featurePageOverrides: [String: [Int: String]] = [:]
    /// One representative kept Page per day.
    ///
    /// Evidence is *derived* from this rather than attached to rows: a
    /// correspondence's supporting Pages are exactly the Pages of the days it
    /// happened on, which is always true and never needs maintaining. It is
    /// also what lets a four-year claim show a Page from its first year.
    private(set) var dayPageIDs: [Int: String] = [:]
    /// Pairs the ledger has ever seen land together.
    private(set) var knownPairs: Set<UInt64> = []
    /// Pairs touched since the last sweep. The sweep drains this, which is what
    /// makes the work proportional to what changed rather than to the archive.
    ///
    /// This and `rows` are writable across the module because the sweep lives
    /// in its own file. The feature arrays above stay `private(set)`: they are
    /// three parallel lists plus an index, and nothing outside `intern` is
    /// allowed near them.
    var dirtyPairs: [UInt64] = []
    var rows: [String: GrimoireCorrespondence] = [:]
    var lastSweptAt: Date?
    var lastIngestedAt: Date?
    var lastPrunedAt: Date?
    /// When the Book last led with a long shot rather than its surest fact.
    var lastWagerAt: Date?
    /// What the last idle tend actually achieved, for the quiet leaf.
    var lastTending: GrimoireTendingMark?

    /// The last few days of features, kept so that *sequence* candidates can be
    /// found at all.
    ///
    /// Same-day co-occurrence is the only thing a single observation can teach,
    /// and a sequence is by definition two things on different days: without
    /// this buffer the Book could never notice that a photograph tends to
    /// follow an invitation, because the two never share a day. Capped at the
    /// sequence window, so it is a handful of integers, not a history.
    private(set) var recentDayNumbers: [Int] = []
    private(set) var recentDayFeatures: [[Int]] = []

    /// Rebuilt on decode, never stored: it is entirely derivable from
    /// `featureIDs` and would otherwise duplicate every id on disk.
    private var featureIndex: [String: Int] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case universe, featureIDs, featureRefs, featureDays
        case knownPairs, dirtyPairs, rows, lastSweptAt, lastIngestedAt, dayPageIDs, lastPrunedAt, featurePageOverrides, bookAskedDays, lastWagerAt, lastTending, experiments
        case recentDayNumbers, recentDayFeatures
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        universe = try container.decodeIfPresent(DayBitset.self, forKey: .universe) ?? DayBitset()
        featureIDs = try container.decodeIfPresent([String].self, forKey: .featureIDs) ?? []
        featureRefs = try container.decodeIfPresent([LoomFeatureRef].self, forKey: .featureRefs) ?? []
        featureDays = try container.decodeIfPresent([DayBitset].self, forKey: .featureDays) ?? []
        dayPageIDs = try container.decodeIfPresent([Int: String].self, forKey: .dayPageIDs) ?? [:]
        bookAskedDays = try container.decodeIfPresent(DayBitset.self, forKey: .bookAskedDays) ?? DayBitset()
        experiments = try container.decodeIfPresent([GrimoireExperiment].self, forKey: .experiments) ?? []
        featurePageOverrides = try container.decodeIfPresent(
            [String: [Int: String]].self, forKey: .featurePageOverrides
        ) ?? [:]
        knownPairs = try container.decodeIfPresent(Set<UInt64>.self, forKey: .knownPairs) ?? []
        dirtyPairs = try container.decodeIfPresent([UInt64].self, forKey: .dirtyPairs) ?? []
        rows = try container.decodeIfPresent([String: GrimoireCorrespondence].self, forKey: .rows) ?? [:]
        lastSweptAt = try container.decodeIfPresent(Date.self, forKey: .lastSweptAt)
        lastIngestedAt = try container.decodeIfPresent(Date.self, forKey: .lastIngestedAt)
        lastPrunedAt = try container.decodeIfPresent(Date.self, forKey: .lastPrunedAt)
        lastWagerAt = try container.decodeIfPresent(Date.self, forKey: .lastWagerAt)
        lastTending = try container.decodeIfPresent(GrimoireTendingMark.self, forKey: .lastTending)
        recentDayNumbers = try container.decodeIfPresent([Int].self, forKey: .recentDayNumbers) ?? []
        recentDayFeatures = try container.decodeIfPresent([[Int]].self, forKey: .recentDayFeatures) ?? []
        if recentDayNumbers.count != recentDayFeatures.count {
            recentDayNumbers = []
            recentDayFeatures = []
        }
        // A truncated or hand-edited save must not be able to desync the three
        // parallel arrays into a crash on the next ingest.
        let width = min(featureIDs.count, min(featureRefs.count, featureDays.count))
        if width < featureIDs.count || width < featureRefs.count || width < featureDays.count {
            featureIDs = Array(featureIDs.prefix(width))
            featureRefs = Array(featureRefs.prefix(width))
            featureDays = Array(featureDays.prefix(width))
        }
        featureIndex = [:]
        featureIndex.reserveCapacity(featureIDs.count)
        for (offset, id) in featureIDs.enumerated() { featureIndex[id] = offset }
    }

    // MARK: Reading

    var featureCount: Int { featureIDs.count }
    var pairCount: Int { knownPairs.count }
    var pendingSweepCount: Int { dirtyPairs.count }

    func index(of featureID: String) -> Int? { featureIndex[featureID] }

    func ref(_ featureID: String) -> LoomFeatureRef? {
        guard let index = featureIndex[featureID] else { return nil }
        return featureRefs[index]
    }

    func days(of featureID: String) -> DayBitset {
        guard let index = featureIndex[featureID] else { return DayBitset() }
        return featureDays[index]
    }

    func row(_ id: String) -> GrimoireCorrespondence? { rows[id] }

    /// The Pages a correspondence rests on, spread across its whole life.
    ///
    /// Always the first and the most recent, then days sampled evenly between,
    /// so the reader sees where a claim started rather than four Pages from
    /// last week.
    func evidencePageIDs(for row: GrimoireCorrespondence, limit: Int = 4) -> [String] {
        guard limit > 0 else { return [] }
        let conditionDays = days(of: row.conditionID)
        let joint: DayBitset
        if let outcomeID = row.outcomeID {
            let outcomeDays = row.shape == .sequential
                ? sequenceOutcomeDays(outcomeID)
                : days(of: outcomeID)
            joint = conditionDays.intersection(outcomeDays)
        } else {
            joint = conditionDays
        }
        let all = joint.days
        guard !all.isEmpty else { return [] }
        let picked: [Int]
        if all.count <= limit {
            picked = all
        } else {
            // First, last, and an even spread between them.
            var chosen: [Int] = []
            for slot in 0..<limit {
                let index = Int((Double(slot) / Double(limit - 1)) * Double(all.count - 1))
                if !chosen.contains(all[index]) { chosen.append(all[index]) }
            }
            picked = chosen
        }
        var seen = Set<String>()
        var pages: [String] = []
        func offer(_ pageID: String?) {
            guard pages.count < limit, let pageID, seen.insert(pageID).inserted else { return }
            pages.append(pageID)
        }
        func page(carrying featureID: String, on day: Int) -> String? {
            featurePageOverrides[featureID]?[day] ?? dayPageIDs[day]
        }
        for day in picked where pages.count < limit {
            // The outcome first: it is the half of the claim the reader is most
            // likely to want to see in their own handwriting.
            if row.shape == .sequential, let outcomeID = row.outcomeID {
                offer(page(carrying: row.conditionID, on: day))
                let outcomeDays = days(of: outcomeID)
                for outcomeDay in (day + 1)...(day + Bars.sequenceWindow)
                where outcomeDays.contains(outcomeDay) {
                    offer(page(carrying: outcomeID, on: outcomeDay))
                    break
                }
            } else {
                if let outcomeID = row.outcomeID { offer(page(carrying: outcomeID, on: day)) }
                offer(page(carrying: row.conditionID, on: day))
            }
        }
        return pages
    }

    var living: [GrimoireCorrespondence] { rows.values.filter(\.isAlive) }
    var standing: [GrimoireCorrespondence] { rows.values.filter { $0.state == .standing } }
    var crossedOut: [GrimoireCorrespondence] { rows.values.filter { $0.state == .crossedOut } }

    // MARK: Ingest

    /// Fold one day's observations in. Sets bits, notes which pairs moved, and
    /// returns. It never scans the archive and never computes a statistic:
    /// everything expensive is deferred to `sweep`.
    mutating func ingest(_ observations: [LoomObservation], now: Date = Date()) {
        guard !observations.isEmpty else { return }
        var dirty = Set(dirtyPairs)
        // Day order matters: the rolling window below is what finds sequences,
        // and a backfill handed over out of order would look like noise.
        for observation in observations.sorted(by: { $0.day < $1.day }) {
            guard observation.day >= 0 else { continue }
            universe.insert(observation.day)
            if observation.bookAsked { bookAskedDays.insert(observation.day) }
            if let pageID = observation.evidencePageID, dayPageIDs[observation.day] == nil {
                dayPageIDs[observation.day] = pageID
            }
            var indices: [Int] = []
            indices.reserveCapacity(observation.features.count)
            for feature in observation.features {
                let index = intern(feature)
                featureDays[index].insert(observation.day)
                if let pageID = observation.evidencePageID,
                   dayPageIDs[observation.day] != pageID,
                   featurePageOverrides[feature.id]?[observation.day] == nil {
                    featurePageOverrides[feature.id, default: [:]][observation.day] = pageID
                }
                indices.append(index)
            }
            note(pairs: indices, dirty: &dirty)
            noteSequences(following: indices, on: observation.day, dirty: &dirty)
            remember(indices, on: observation.day)
        }
        // Sorted, and not for tidiness. `Array(Set<UInt64>)` comes out in hash
        // order, which Swift seeds per process, so the sweep examined candidate
        // pairs in a different order every launch. The conviction cabinet holds
        // only `maximumHeld`, and a newcomer must beat the weakest thing
        // already in it — so *which* rules the Book ended up sure of depended
        // on the order they happened to be looked at. Same archive, different
        // launch, different convictions.
        dirtyPairs = Array(dirty).sorted()
        lastIngestedAt = now
    }

    /// Replace the derived evidence with a fresh projection of the archive.
    ///
    /// The archive is the source of truth. Replaying it through `ingest` is not
    /// reconciliation: bits can only be added, withdrawn Pages never leave,
    /// and the sequence window sees four-year-old days after yesterday. A
    /// rebuild is cheap enough for the six-hour background chore and, unlike a
    /// cache patch, remains correct when privacy or archive contents change.
    /// Spoken history and the reader's answers survive; only derived evidence
    /// and candidate indices are rebuilt.
    mutating func reconcile(_ observations: [LoomObservation], now: Date = Date()) {
        let rememberedRows = rows
        let rememberedSweep = lastSweptAt
        let rememberedPrune = lastPrunedAt
        let rememberedWager = lastWagerAt

        self = GrimoireLedger()
        rows = rememberedRows
        lastSweptAt = rememberedSweep
        lastPrunedAt = rememberedPrune
        lastWagerAt = rememberedWager
        ingest(observations, now: now)

        // A previous row may no longer co-occur in the rebuilt archive. Keep
        // its pair alive long enough for the sweep to withdraw or cross it out.
        var dirty = Set(dirtyPairs)
        for row in Array(rows.values) {
            let id = row.id
            guard let condition = index(of: row.conditionID) else {
                retireOrForget(id, now: now)
                continue
            }
            guard let outcomeID = row.outcomeID else { continue }
            guard let outcome = index(of: outcomeID) else {
                retireOrForget(id, now: now)
                continue
            }
            let key = GrimoireLedger.pairKey(condition, outcome)
            knownPairs.insert(key)
            dirty.insert(key)
        }
        // Re-test every candidate because reconciliation may have removed a
        // miss as well as added a hit.
        dirty.formUnion(knownPairs)
        // Sorted, and not for tidiness. `Array(Set<UInt64>)` comes out in hash
        // order, which Swift seeds per process, so the sweep examined candidate
        // pairs in a different order every launch. The conviction cabinet holds
        // only `maximumHeld`, and a newcomer must beat the weakest thing
        // already in it — so *which* rules the Book ended up sure of depended
        // on the order they happened to be looked at. Same archive, different
        // launch, different convictions.
        dirtyPairs = Array(dirty).sorted()
        lastIngestedAt = now
    }

    private mutating func retireOrForget(_ id: String, now: Date) {
        guard var row = rows[id] else { return }
        if row.state == .forbidden { return }
        guard row.hasSpoken else {
            rows.removeValue(forKey: id)
            return
        }
        guard row.state != .crossedOut else { return }
        let from = row.state
        row.state = .crossedOut
        row.revisions.append(GrimoireRevision(
            at: now,
            from: from,
            to: .crossedOut,
            because: "the Pages it rested on are no longer in the archive"
        ))
        rows[id] = row
    }

    private mutating func intern(_ feature: LoomFeatureRef) -> Int {
        if let existing = featureIndex[feature.id] {
            // A projector may sharpen its own wording between releases. Keep
            // the newest description; the days already counted stay counted.
            featureRefs[existing] = feature
            return existing
        }
        let index = featureIDs.count
        featureIDs.append(feature.id)
        featureRefs.append(feature)
        featureDays.append(DayBitset())
        featureIndex[feature.id] = index
        return index
    }

    /// Record every eligible pairing inside one observation.
    ///
    /// This is the line that keeps "everything against everything" affordable:
    /// the table is built from pairs that *actually landed together*, never
    /// from the cross product, and a feature seen on only one day is not
    /// admitted at all — it could never clear the three-day bar anyway.
    private mutating func note(pairs indices: [Int], dirty: inout Set<UInt64>) {
        guard indices.count > 1 else { return }
        let eligible = indices.filter { featureDays[$0].count >= 2 }
        guard eligible.count > 1 else { return }
        for left in eligible {
            for right in eligible where left != right {
                guard GrimoireLedger.canPair(featureRefs[left], featureRefs[right]) else { continue }
                let key = GrimoireLedger.pairKey(left, right)
                if knownPairs.contains(key) {
                    dirty.insert(key)
                } else if knownPairs.count < Bars.maximumPairs {
                    knownPairs.insert(key)
                    dirty.insert(key)
                }
            }
        }
    }

    /// Pair today's features with the last few days' features, so that "this
    /// keeps following that" is a question the sweep is ever able to ask.
    private mutating func noteSequences(following indices: [Int], on day: Int, dirty: inout Set<UInt64>) {
        guard !recentDayNumbers.isEmpty else { return }
        let today = indices.filter { featureDays[$0].count >= 2 }
        guard !today.isEmpty else { return }
        for (slot, earlier) in recentDayNumbers.enumerated() {
            let gap = day - earlier
            guard gap >= 1, gap <= Bars.sequenceWindow else { continue }
            for before in recentDayFeatures[slot] where featureDays[before].count >= 2 {
                for after in today where before != after {
                    guard GrimoireLedger.canPair(featureRefs[before], featureRefs[after]) else { continue }
                    let key = GrimoireLedger.pairKey(before, after)
                    if knownPairs.contains(key) {
                        dirty.insert(key)
                    } else if knownPairs.count < Bars.maximumPairs {
                        knownPairs.insert(key)
                        dirty.insert(key)
                    }
                }
            }
        }
    }

    /// Keep the window. Days already in it merge; anything older than the
    /// window falls off the front.
    private mutating func remember(_ indices: [Int], on day: Int) {
        if let slot = recentDayNumbers.firstIndex(of: day) {
            recentDayFeatures[slot] = Array(Set(recentDayFeatures[slot] + indices))
        } else {
            recentDayNumbers.append(day)
            recentDayFeatures.append(indices)
        }
        while let oldest = recentDayNumbers.first, day - oldest > Bars.sequenceWindow {
            recentDayNumbers.removeFirst()
            recentDayFeatures.removeFirst()
        }
    }

    static func pairKey(_ condition: Int, _ outcome: Int) -> UInt64 {
        (UInt64(UInt32(truncatingIfNeeded: condition)) << 32) | UInt64(UInt32(truncatingIfNeeded: outcome))
    }

    static func unpack(_ key: UInt64) -> (condition: Int, outcome: Int) {
        (Int(key >> 32), Int(key & 0xFFFF_FFFF))
    }

    /// Which orderings of two features are allowed to become a claim.
    static func canPair(_ condition: LoomFeatureRef, _ outcome: LoomFeatureRef) -> Bool {
        guard condition.id != outcome.id else { return false }
        guard condition.role != .outcomeOnly else { return false }
        guard outcome.role != .conditionOnly else { return false }
        // Fiction may set the scene. It may never be the thing the Book claims
        // about the reader's actual life.
        guard outcome.provenance != .generatedFiction else { return false }
        // Two things from the same family are the trivial pairing — it was
        // morning, therefore it was morning. The sibling shape covers the one
        // within-family comparison that is worth making.
        guard condition.domain != outcome.domain else { return false }
        return true
    }

    // MARK: Forgetting

    /// Drop features that can never become a claim, and compact what is left.
    ///
    /// Most of what a reader writes is words used once. They are admitted
    /// cheaply — a one-day feature never even enters the pair table — but they
    /// are *interned* forever, and over four years that is thousands of ids and
    /// clauses carried in every save.
    ///
    /// A feature goes only if it has been seen on a single day, that day is
    /// long past, and nothing standing refers to it. Everything else keeps its
    /// place. Returns how many were forgotten.
    @discardableResult
    mutating func prune(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard !featureIDs.isEmpty else { return 0 }
        let today = GrimoireDay.index(for: now, calendar: calendar)

        // Anything a row leans on is untouchable, whatever its day count.
        var referenced = Set<String>()
        for row in rows.values {
            referenced.insert(row.conditionID)
            if let outcome = row.outcomeID { referenced.insert(outcome) }
            if let rival = row.rivalID { referenced.insert(rival) }
        }

        var keep: [Int] = []
        keep.reserveCapacity(featureIDs.count)
        for index in featureIDs.indices {
            let days = featureDays[index]
            let stale = (days.lastDay.map { today - $0 > Bars.pruneStaleDays } ?? true)
            let disposable = days.count < 2 && stale && !referenced.contains(featureIDs[index])
            if !disposable { keep.append(index) }
        }
        let dropped = featureIDs.count - keep.count
        guard dropped > 0 else {
            lastPrunedAt = now
            return 0
        }

        // Indices move, and `knownPairs` is packed out of them, so everything
        // keyed by index has to be rewritten in the same breath.
        var moved = [Int: Int]()
        moved.reserveCapacity(keep.count)
        var ids: [String] = []
        var refs: [LoomFeatureRef] = []
        var dayfields: [DayBitset] = []
        ids.reserveCapacity(keep.count)
        refs.reserveCapacity(keep.count)
        dayfields.reserveCapacity(keep.count)
        for (position, old) in keep.enumerated() {
            moved[old] = position
            ids.append(featureIDs[old])
            refs.append(featureRefs[old])
            dayfields.append(featureDays[old])
        }

        func remap(_ keys: some Sequence<UInt64>) -> [UInt64] {
            keys.compactMap { key in
                let (condition, outcome) = GrimoireLedger.unpack(key)
                guard let newCondition = moved[condition], let newOutcome = moved[outcome] else { return nil }
                return GrimoireLedger.pairKey(newCondition, newOutcome)
            }
        }
        let remappedKnown = Set(remap(knownPairs))
        let remappedDirty = remap(dirtyPairs).filter { remappedKnown.contains($0) }

        featureIDs = ids
        featureRefs = refs
        featureDays = dayfields
        featureIndex = [:]
        featureIndex.reserveCapacity(ids.count)
        for (position, id) in ids.enumerated() { featureIndex[id] = position }
        featurePageOverrides = featurePageOverrides.filter { featureIndex[$0.key] != nil }
        knownPairs = remappedKnown
        dirtyPairs = Array(Set(remappedDirty))
        // These are feature indices too. Retaining the old numbers after a
        // compaction can manufacture sequences or index past the new arrays.
        recentDayNumbers = []
        recentDayFeatures = []
        lastPrunedAt = now
        return dropped
    }

    // MARK: Statistics

    /// The bar check, and nothing more: four popcounts and some division.
    ///
    /// Split out from the rest because the sweep asks this question of every
    /// candidate pair and almost all of them fail it. Years, seasons and drift
    /// cost real time, so nothing pays for them until it has earned a row.
    /// Both sets must be subsets of the universe — every feature day comes from
    /// an observation, which also stamped the universe. Derived sets (a shifted
    /// sequence window, say) must be intersected with the universe *before*
    /// they arrive here; `sequenceOutcomeDays` is the one that does that.
    ///
    /// Given that, the two contrast counts are subtraction rather than set
    /// algebra, which spares an array allocation on a path the desk walks once
    /// per row.
    func contrast(conditionDays condition: DayBitset, outcomeDays outcome: DayBitset) -> GrimoireStats {
        var out = GrimoireStats()
        out.inCount = condition.count
        out.inHits = condition.intersectionCount(outcome)
        out.outCount = universe.count - out.inCount
        out.outHits = outcome.count - out.inHits
        return out
    }

    /// The same counts, taken over a narrower set of days.
    ///
    /// Used to judge a claim on days the Book was not standing over the
    /// reader's shoulder. Everything is clipped to `within`, so the subtraction
    /// arithmetic above still holds.
    func contrast(
        conditionDays condition: DayBitset,
        outcomeDays outcome: DayBitset,
        within days: DayBitset
    ) -> GrimoireStats {
        let inside = condition.intersection(days)
        let landed = outcome.intersection(days)
        var out = GrimoireStats()
        out.inCount = inside.count
        out.inHits = inside.intersectionCount(landed)
        out.outCount = days.count - out.inCount
        out.outHits = landed.count - out.inHits
        return out
    }

    /// The days a correspondence's own telling may have coloured: the days the
    /// Book raised it, and the week after each.
    func promptedWindow(for row: GrimoireCorrespondence) -> DayBitset {
        let spoken = row.promptedDays.isEmpty
            ? DayBitset()
            : row.promptedDays.union(row.promptedDays.window(after: 1, through: Bars.promptedShadowDays))
        // Days the Book *said* it, plus days the Book *arranged* it. Neither is
        // the reader's own doing, so neither may judge the promise.
        return spoken.union(bookAskedDays).intersection(universe)
    }

    /// The days that sit just before an outcome, clipped to days the Book was
    /// actually open. The clip is what lets `contrast` do arithmetic.
    func sequenceOutcomeDays(_ outcomeID: String) -> DayBitset {
        days(of: outcomeID)
            .precedingWindow(from: 1, through: Bars.sequenceWindow)
            .intersection(universe)
    }

    /// The parts only a surviving correspondence needs: when it started, how
    /// many years and seasons it spans, and whether it has been loosening.
    func enrich(
        _ stats: inout GrimoireStats,
        conditionDays condition: DayBitset,
        outcomeDays outcome: DayBitset
    ) {
        let joint = condition.intersection(outcome)
        stats.firstDay = joint.firstDay
        stats.lastDay = joint.lastDay

        var years: Set<Int> = []
        var seasons: Set<Int> = []
        for day in joint.days {
            let civil = GrimoireDay.civil(of: day)
            years.insert(civil.year)
            seasons.insert(GrimoireDay.season(of: day))
        }
        stats.distinctYears = years.count
        stats.distinctSeasons = seasons.count

        if let low = universe.firstDay, let high = universe.lastDay, high > low {
            let midpoint = low + (high - low) / 2
            let earlyIn = condition.intersection(DayBitset.filled(from: low, through: midpoint))
            let lateIn = condition.intersection(DayBitset.filled(from: midpoint + 1, through: high))
            stats.earlyRate = earlyIn.count > 0
                ? Double(earlyIn.intersectionCount(outcome)) / Double(earlyIn.count) : 0
            stats.lateRate = lateIn.count > 0
                ? Double(lateIn.intersectionCount(outcome)) / Double(lateIn.count) : 0
        }
    }

    /// Both halves, for callers that want the whole picture of one row.
    func stats(
        conditionDays condition: DayBitset,
        outcomeDays outcome: DayBitset,
        calendar: Calendar = .current
    ) -> GrimoireStats {
        var out = contrast(conditionDays: condition, outcomeDays: outcome)
        enrich(&out, conditionDays: condition, outcomeDays: outcome)
        return out
    }

    /// Does this clear the bar to be worth a row at all?
    static func clearsBar(_ stats: GrimoireStats, universeCount: Int) -> Bool {
        guard universeCount >= Bars.minimumUniverse else { return false }
        guard stats.inCount >= Bars.minimumInCount else { return false }
        guard stats.outCount >= Bars.minimumOutCount else { return false }
        guard stats.inHits >= Bars.minimumHits else { return false }
        guard stats.distinctDays >= Bars.minimumDistinctDays else { return false }
        guard stats.inRate >= Bars.minimumInRate else { return false }
        guard stats.rateGap >= Bars.minimumRateGap else { return false }
        guard stats.lift >= Bars.minimumLift else { return false }
        return true
    }

    static func clearsStandingBar(_ stats: GrimoireStats) -> Bool {
        stats.inHits >= Bars.standingHits && stats.distinctDays >= Bars.standingDays
    }
}
