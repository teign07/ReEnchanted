import XCTest
@testable import InsideCoverCore

/// The long-horizon simulations in `BookReenchantmentSimulationTests` assert
/// restraint — bounded, rare, varied, never a feed. They never assert that the
/// learning loops *pay off*. These do.
///
/// Each test closes the real loop: `BookCurator.rankedPages` selects through the
/// live propensity-weighted race, the Book stamps its own
/// `CausalCurationReceipt`, a simulated reader with a hidden truth answers, and
/// the answer is fed back through `ReaderAlivenessModel.ingest`. The Book is
/// never told which families actually work.
///
/// The headline measure is the reader's own rate of lived receipts per surfaced
/// Page. If the loops compound, that rate rises on its own as the desk fills
/// with what works.
///
/// Every rising measure is paired with a null reader whose answers are
/// independent of what was shown, at the same overall rate. Without that pairing
/// a rising curve proves nothing — a Book that merely repeats its own
/// preferences produces one too. Telling those apart is the entire reason
/// `CausalCurationReceipt` logs propensities and eligible alternatives, so these
/// tests hold themselves to the same standard.
final class CompoundingCurationTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 2_050_000_000)
    private let facets: Set<String> = ["time:evening", "weather:rain"]

    /// One family per desk role genuinely works for this reader, so the Book has
    /// a reachable better desk rather than a single slot to fight over.
    private let livingSourceIDs = ["rain-door", "margin-echo", "quote-horizon"]

    private var contextKey: String {
        ReaderAlivenessCurationContext.contextKey(facets)
    }

    // MARK: - The compounding contract

    func testTheReadersRateOfLivedReceiptsRisesAsTheBookLearns() {
        let truthful = truthfulRun()
        let null = nullRun()

        let truthfulRise = truthful.outcomeRate(quarter: 3) - truthful.outcomeRate(quarter: 0)
        let nullRise = null.outcomeRate(quarter: 3) - null.outcomeRate(quarter: 0)

        XCTAssertGreaterThan(
            truthfulRise,
            0.05,
            "The reader's rate of lived receipts did not improve: first quarter "
                + "\(truthful.outcomeRate(quarter: 0)), last quarter "
                + "\(truthful.outcomeRate(quarter: 3))."
        )
        XCTAssertGreaterThan(
            truthfulRise,
            nullRise,
            "A reader whose answers ignore the Page improved just as much "
                + "(\(nullRise)), so this measures the Book repeating itself "
                + "rather than learning."
        )
        XCTAssertGreaterThan(
            truthful.livingShare(quarter: 3),
            truthful.livingShare(quarter: 0),
            "The desk did not actually shift toward the families that worked."
        )
        XCTAssertGreaterThan(
            truthful.outcomeRate(half: 1),
            truthful.outcomeRate(half: 0),
            "Pooled over halves, where the sampling noise is far smaller, the "
                + "reader's harvest still has to be better later than earlier."
        )
    }

    /// Averaged over independent runs, the reader's harvest must never turn back
    /// down.
    ///
    /// This is asserted on the running average rather than quarter against
    /// quarter, and the difference is a measurement limit rather than a
    /// concession. The harvest is a sampled quantity: five runs give roughly two
    /// points of spread per quarter against a trend of about four points per
    /// quarter, so a single quarter-to-quarter step sits near one sigma and will
    /// sometimes fall however well the Book is learning. Asking for strict
    /// quarter-on-quarter growth would pin noise, not behaviour — and it can
    /// never be honestly guaranteed anyway, because the exploration floor spends
    /// some of every desk on families that have not earned it. What the Book
    /// knows may be held to a stricter standard; see
    /// `testWhatTheBookKnowsNeverStopsImproving`.
    func testAveragedAcrossSeedsTheHarvestNeverTurnsBackDown() {
        let runs = truthfulRuns()
        func rate(quarter: Int) -> Double {
            runs.map { $0.outcomeRate(quarter: quarter) }.reduce(0, +) / Double(runs.count)
        }
        let curve = (0..<4).map(rate(quarter:))
        let running = (0..<4).map { quarter in
            (0...quarter).map(rate(quarter:)).reduce(0, +) / Double(quarter + 1)
        }

        for (quarter, (earlier, later)) in zip(running, running.dropFirst()).enumerated() {
            XCTAssertGreaterThanOrEqual(
                later,
                earlier,
                "The running harvest fell at quarter \(quarter + 1): \(running) from \(curve)."
            )
        }
        XCTAssertGreaterThan(
            running[3] - running[0],
            0.04,
            "Four months of consistent evidence barely moved the harvest: \(running)."
        )
    }

    /// The reader's sampled harvest is a noisy thing — 72 draws a quarter, so a
    /// share near 0.4 carries about six points of sampling spread, and a quarter
    /// can come in low with nothing behind it. What the Book *knows* has no such
    /// excuse: evidence only accumulates, so the distance it holds between the
    /// families that work and the ones that do not must never shrink.
    func testWhatTheBookKnowsNeverStopsImproving() {
        let truthful = truthfulRun()
        let gaps = (0..<4).map { liftGap(in: truthful, quarter: $0) }

        for (earlier, later) in zip(gaps, gaps.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                later,
                earlier,
                "The Book un-learned something it had already been shown: \(gaps)."
            )
        }
        XCTAssertGreaterThan(
            gaps[3],
            gaps[0],
            "Four months of consistent evidence taught the Book nothing: \(gaps)."
        )
    }

    func testEachWorkingFamilyEarnsUpliftAndEachHollowOneCools() throws {
        let truthful = truthfulRun()
        let null = nullRun()

        for sourceID in livingSourceIDs {
            let lift = try bestLift(in: truthful, sourceID: sourceID)
            let nullLift = try bestLift(in: null, sourceID: sourceID)
            XCTAssertGreaterThan(lift, 1, "\(sourceID) never earned uplift.")
            XCTAssertGreaterThan(
                lift,
                nullLift,
                "\(sourceID) gained uplift without the outcomes tracking the Page."
            )
        }

        let cooled = try truthful.surfacedSourceIDs
            .filter { !livingSourceIDs.contains($0) }
            .map { try bestLift(in: truthful, sourceID: $0) }
        XCTAssertFalse(cooled.isEmpty)
        XCTAssertLessThan(
            cooled.reduce(0, +) / Double(cooled.count),
            1,
            "Families that produced nothing for months were not cooled at all."
        )
    }

    /// Compounding must never become a filter. Families that failed this reader
    /// keep their ticket, or one wrong early read becomes permanent.
    func testCompoundingNeverClosesExploration() {
        let truthful = truthfulRun()
        let hollowInFinalQuarter = truthful.quarters[3]
            .filter { !livingSourceIDs.contains($0.key) }
            .values
            .reduce(0, +)

        XCTAssertGreaterThan(
            hollowInFinalQuarter,
            0,
            "The cooled families were starved out of the final quarter."
        )
        XCTAssertLessThan(
            truthful.livingShare(quarter: 3),
            1,
            "The warm families became a certainty."
        )
    }

    // MARK: - What compounding is allowed to be made of

    /// The north star may only move on evidence from outside the Book. Months of
    /// diligent in-app participation — opening every Page, acting on every Page
    /// — must leave it exactly where it started.
    func testTheGoalMeasureOnlyBrightensOnEvidenceFromOutsideTheBook() {
        let crossing = truthfulRun()
        let appUseOnly = appUseOnlyRun()

        let crossingReading = reading(for: crossing)
        let appUseReading = reading(for: appUseOnly)

        XCTAssertGreaterThanOrEqual(crossingReading.livedProofCount, 2)
        XCTAssertNotEqual(
            crossingReading.direction,
            .notEnoughEvidence,
            "Months of lived receipts never became a reading."
        )
        XCTAssertGreaterThan(crossingReading.confidence, 0)

        XCTAssertEqual(
            appUseReading.direction,
            .notEnoughEvidence,
            "Months of in-Book participation moved the north star."
        )
        XCTAssertEqual(appUseReading.livedProofCount, 0)
        XCTAssertGreaterThan(
            appUseReading.supportingSignalCount,
            0,
            "In-Book acts should still count as support, just never as proof."
        )
    }

    /// Two families the reader answers just as often, differing only in what the
    /// answer was: one sent them out of the Book, the other was admired inside
    /// it. Compounding has to prefer the crossing.
    func testCompoundingPrefersCrossingsOverApproval() throws {
        let crossed = Self.crossedSourceID
        let admired = Self.admiredSourceID
        let result = crossingVersusApprovalRun()

        XCTAssertGreaterThan(
            try bestLift(in: result, sourceID: crossed),
            try bestLift(in: result, sourceID: admired),
            "Being admired inside the Book compounded as fast as leaving it did."
        )
        XCTAssertGreaterThan(
            result.learning.scoreAdjustment(for: result.candidate(crossed)),
            result.learning.scoreAdjustment(for: result.candidate(admired)),
            "The taste model disagreed with the causal layer about crossings."
        )
    }

    // MARK: - The simulated reader

    /// A reader governed by a hidden truth. The Book sees only the answers.
    ///
    /// Answers are spaced exactly rather than sampled: the nth exposure of a
    /// family is a hit when its running quota crosses an integer. A coin-flipping
    /// reader adds a second source of variance on top of the Curator's own
    /// deliberate randomness, and over a 96-day desk that binomial noise swamps
    /// the effect being measured — quarter-to-quarter swings of ±10 points with
    /// nothing behind them. This keeps each family's true rate intact while
    /// leaving the Book's exploration as the only thing still rolling dice.
    private struct SimulatedReader {
        var rates: [String: Double]
        var defaultRate: Double
        var positive: ReaderLearningAction = .keepsakeEarned
        var negative: ReaderLearningAction = .dismissed
        var positiveBySource: [String: ReaderLearningAction] = [:]

        func answer(to sourceID: String, exposure: Int) -> ReaderLearningAction {
            let rate = rates[sourceID] ?? defaultRate
            let quota = { (count: Int) in Int(Double(count) * rate) }
            guard quota(exposure + 1) > quota(exposure) else { return negative }
            return positiveBySource[sourceID] ?? positive
        }
    }

    // MARK: - The scenarios

    /// A run is a pure function of its label, its reader, and its length, and
    /// each one costs about a minute — `CausalCurationLedger.estimate` walks the
    /// whole ledger for every candidate of every desk. Tests share histories
    /// rather than re-simulating them, which also means the compounding claim
    /// and the uplift claim are made about the very same simulated months.
    private static var runCache: [String: RunResult] = [:]

    private static let crossedSourceID = "rain-door"
    private static let admiredSourceID = "sky-door"

    /// The living families genuinely work for this reader; the rest rarely do.
    private func truthfulRun(seed: String = "truthful") -> RunResult {
        cachedRun(
            label: seed,
            reader: SimulatedReader(
                rates: Dictionary(uniqueKeysWithValues: livingSourceIDs.map { ($0, 0.82) }),
                defaultRate: 0.06
            )
        )
    }

    /// The same reader and the same hidden truth, met by a Book rolling different
    /// dice. One run's quarter can come in low on sampling alone; averaging
    /// independent runs shrinks that spread without touching the effect.
    private func truthfulRuns() -> [RunResult] {
        ["truthful", "truthful-b", "truthful-c", "truthful-d", "truthful-e"]
            .map { truthfulRun(seed: $0) }
    }

    /// The same quantity of good news, unrelated to what was offered. Any rise
    /// here is the Book agreeing with itself, not learning.
    private func nullRun() -> RunResult {
        cachedRun(
            label: "null",
            reader: SimulatedReader(rates: [:], defaultRate: 0.25)
        )
    }

    /// Diligent in-Book participation and nothing else: every Page opened, most
    /// Pages acted on, never a trace left outside the covers.
    private func appUseOnlyRun() -> RunResult {
        cachedRun(
            label: "app-use-only",
            reader: SimulatedReader(
                rates: [:],
                defaultRate: 0.7,
                positive: .acted,
                negative: .opened
            )
        )
    }

    /// Two families answered equally often, differing only in what the answer
    /// was: one crossing, one admiring.
    private func crossingVersusApprovalRun() -> RunResult {
        cachedRun(
            label: "crossing-vs-approval",
            reader: SimulatedReader(
                rates: [Self.crossedSourceID: 0.72, Self.admiredSourceID: 0.72],
                defaultRate: 0.08,
                positiveBySource: [
                    Self.crossedSourceID: .keepsakeEarned,
                    Self.admiredSourceID: .loved
                ]
            )
        )
    }

    private func cachedRun(label: String, reader: SimulatedReader) -> RunResult {
        if let cached = Self.runCache[label] { return cached }
        let result = run(label: label, reader: reader)
        Self.runCache[label] = result
        return result
    }

    // MARK: - The run

    private struct RunResult {
        var quarters: [[String: Int]]
        var positives: [Int]
        var roleCounts: [String: [BookSessionRole: Int]]
        var model: ReaderAlivenessModel
        var learning: ReaderLearningModel
        var candidates: [SurfacePage]
        var livingSourceIDs: [String]
        var endedAt: Date
        /// The Book as it stood at the close of each quarter, so what it knew can
        /// be read separately from what the dice happened to serve.
        var quarterModels: [ReaderAlivenessModel]
        var quarterEnds: [Date]

        var surfacedSourceIDs: [String] {
            Array(Set(quarters.flatMap(\.keys))).sorted()
        }

        /// The reader's own harvest: lived receipts per Page the Book offered.
        func outcomeRate(quarter: Int) -> Double {
            let surfaced = quarters[quarter].values.reduce(0, +)
            guard surfaced > 0 else { return 0 }
            return Double(positives[quarter]) / Double(surfaced)
        }

        /// Pooled across both halves, where there are twice the draws and so
        /// appreciably less sampling noise than a single quarter carries.
        func outcomeRate(half: Int) -> Double {
            let quarters = half == 0 ? [0, 1] : [2, 3]
            let surfaced = quarters.reduce(0) { $0 + self.quarters[$1].values.reduce(0, +) }
            guard surfaced > 0 else { return 0 }
            let positive = quarters.reduce(0) { $0 + positives[$1] }
            return Double(positive) / Double(surfaced)
        }

        func livingShare(quarter: Int) -> Double {
            let surfaced = quarters[quarter].values.reduce(0, +)
            guard surfaced > 0 else { return 0 }
            let living = quarters[quarter]
                .filter { livingSourceIDs.contains($0.key) }
                .values
                .reduce(0, +)
            return Double(living) / Double(surfaced)
        }

        /// A family rotates across desk roles, and the causal layer keys on
        /// role, so its evidence is spread over several cells. Report the role
        /// it occupied most often.
        func dominantRole(for sourceID: String) -> BookSessionRole? {
            roleCounts[sourceID]?.max { $0.value < $1.value }?.key
        }

        func candidate(_ sourceID: String) -> SurfacePage {
            candidates.first { $0.sourceID == sourceID }!
        }
    }

    private func run(
        label: String,
        reader: SimulatedReader,
        dayCount: Int = 96
    ) -> RunResult {
        let candidates = self.candidates()
        let preferences = CuratorSurfacePreferences(
            pageBeliefProfiles: Dictionary(uniqueKeysWithValues: candidates.map { candidate in
                (candidate.sourceID, PageBeliefProfile(
                    sourceID: candidate.sourceID,
                    type: candidate.type,
                    title: candidate.type.title,
                    belief: 50,
                    narrativeWeight: 20,
                    cadence: "compounding",
                    note: "Every candidate starts identically believed."
                ))
            })
        )
        var mood = CuratorMood.neutral
        mood.keptPageCount = 100

        var model = ReaderAlivenessModel.unwritten
        var learning = ReaderLearningModel()
        var quarters = Array(repeating: [String: Int](), count: 4)
        var positives = Array(repeating: 0, count: 4)
        var roleCounts: [String: [BookSessionRole: Int]] = [:]
        var exposures: [String: Int] = [:]
        var quarterModels = Array(repeating: ReaderAlivenessModel.unwritten, count: 4)
        var quarterEnds = Array(repeating: start, count: 4)
        var endedAt = start

        for day in 0..<dayCount {
            let at = start.addingTimeInterval(Double(day) * 86_400)
            endedAt = at
            let quarter = min(3, day * 4 / dayCount)
            let seed = "\(label)-day-\(day)"
            let ranked = BookCurator.rankedPages(
                from: candidates,
                limit: 3,
                preferences: preferences,
                mood: mood,
                now: at,
                intention: intention(seed: seed, at: at),
                selectionSeed: seed,
                readerAliveness: model,
                alivenessFacets: facets
            ).map(\.page)

            for surface in ranked {
                // Deterministic editorial insertions carry no receipt and are
                // not part of the experiment.
                guard let receipt = CausalCurationReceipt.read(from: surface) else { continue }
                quarters[quarter][surface.sourceID, default: 0] += 1
                roleCounts[surface.sourceID, default: [:]][receipt.role, default: 0] += 1

                let exposure = exposures[surface.sourceID, default: 0]
                exposures[surface.sourceID] = exposure + 1
                let answer = reader.answer(to: surface.sourceID, exposure: exposure)
                if answer != reader.negative { positives[quarter] += 1 }
                for (offset, action) in [(60.0, ReaderLearningAction.surfaced), (180.0, answer)] {
                    let event = learningEvent(
                        id: "\(label)-\(day)-\(surface.sourceID)-\(action.rawValue)",
                        action: action,
                        surface: surface,
                        receipt: receipt,
                        at: at.addingTimeInterval(offset)
                    )
                    model.ingest(event)
                    learning.record(event)
                }
            }
            quarterModels[quarter] = model
            quarterEnds[quarter] = at
        }

        return RunResult(
            quarters: quarters,
            positives: positives,
            roleCounts: roleCounts,
            model: model,
            learning: learning,
            candidates: candidates,
            livingSourceIDs: livingSourceIDs,
            endedAt: endedAt,
            quarterModels: quarterModels,
            quarterEnds: quarterEnds
        )
    }

    /// How far apart the Book has learned to hold the families that work from the
    /// ones that do not, as of the close of a given quarter. Unlike the reader's
    /// sampled harvest, this reflects only accumulated evidence, so it is the
    /// quantity that can honestly be asked to keep climbing.
    private func liftGap(in result: RunResult, quarter: Int) -> Double {
        let model = result.quarterModels[quarter]
        let at = result.quarterEnds[quarter]
        func meanLift(of sourceIDs: [String]) -> Double {
            let lifts = sourceIDs.compactMap { sourceID -> Double? in
                guard let role = result.dominantRole(for: sourceID) else { return nil }
                return model.causalUpliftMultiplier(
                    movement: .freshSight,
                    role: role,
                    sourceID: sourceID,
                    contextKey: contextKey,
                    now: at
                )
            }
            guard !lifts.isEmpty else { return 1 }
            return lifts.reduce(0, +) / Double(lifts.count)
        }
        let hollow = result.surfacedSourceIDs.filter { !livingSourceIDs.contains($0) }
        return meanLift(of: livingSourceIDs) - meanLift(of: hollow)
    }

    /// The strongest multiplier the family earned in the role it mostly held.
    private func bestLift(in result: RunResult, sourceID: String) throws -> Double {
        let role = try XCTUnwrap(
            result.dominantRole(for: sourceID),
            "\(sourceID) never reached the desk."
        )
        return result.model.causalUpliftMultiplier(
            movement: .freshSight,
            role: role,
            sourceID: sourceID,
            contextKey: contextKey,
            now: result.endedAt
        )
    }

    private func reading(for result: RunResult) -> ReaderReenchantmentMetrics {
        ReaderReenchantmentMeasure.reading(
            pulses: .empty,
            aliveness: result.model,
            longGame: nil,
            learning: result.learning,
            days: [],
            now: result.endedAt
        )
    }

    // MARK: - Fixtures

    /// Twelve families for three slots, so a family's share of the desk has room
    /// to rise or fall instead of being pinned by the desk's own composition
    /// rules. One working family sits in each role group, so a better desk is
    /// actually reachable. Composition prompts are left out: the desk allows
    /// only one at a time, which would cap a family for reasons unrelated to
    /// learning.
    private func candidates() -> [SurfacePage] {
        [
            page(.weather, intent: .capture, sourceID: "rain-door"),
            page(.todaysSky, intent: .capture, sourceID: "sky-door"),
            page(.body, intent: .capture, sourceID: "body-door"),
            page(.location, intent: .capture, sourceID: "place-door"),
            page(.wonderCompass, intent: .capture, sourceID: "compass-door"),
            page(.note, intent: .reflect, sourceID: "margin-echo"),
            page(.castBond, intent: .reflect, sourceID: "bond-echo"),
            page(.wordNegotiation, intent: .reflect, sourceID: "word-echo"),
            page(.letter, intent: .reflect, sourceID: "letter-echo"),
            page(.quotes, intent: .importReference, sourceID: "quote-horizon"),
            page(.lore, intent: .importReference, sourceID: "lore-horizon"),
            page(.quip, intent: .importReference, sourceID: "quip-horizon")
        ]
    }

    private func page(
        _ type: BookPageType,
        intent: BookPageIntent,
        sourceID: String
    ) -> SurfacePage {
        SurfacePage(
            id: "compounding-\(sourceID)",
            type: type,
            sourceID: sourceID,
            intent: intent,
            score: 60,
            prompt: type.title,
            detail: "An equally suitable candidate.",
            payload: BookPagePayload(
                headline: type.title,
                body: "An equally suitable candidate.",
                metadata: [:]
            )
        )
    }

    private func intention(seed: String, at: Date) -> BookSessionIntention {
        BookSessionIntention(
            id: "compounding-\(seed)",
            dayID: BookDay.id(for: at),
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: [],
            evidenceReason: "A deterministic simulation supplied an honest opening.",
            createdAt: at,
            expiresAt: at.addingTimeInterval(6 * 3600),
            seed: seed
        )
    }

    private func learningEvent(
        id: String,
        action: ReaderLearningAction,
        surface: SurfacePage,
        receipt: CausalCurationReceipt,
        at: Date
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: id,
            dayID: BookDay.id(for: at),
            occurredAt: at,
            action: action,
            surfaceID: surface.id,
            sourceID: surface.sourceID,
            type: surface.type,
            varietyKey: "compounding-\(surface.sourceID)",
            hour: 19,
            tags: [
                "book-session:freshSight",
                "book-session-id:\(receipt.sessionID)",
                "book-session-role:\(receipt.role.rawValue)"
            ],
            evidence: action == .keepsakeEarned
                ? "The rain made the long evening street look silver."
                : nil,
            context: context(at: at),
            causalReceipt: receipt
        )
    }

    private func context(at: Date) -> BookPageContextSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return BookPageContextSnapshot(
            at: at,
            calendar: calendar,
            weatherTags: ["rain"],
            calendarEventCount: 0,
            locationLabel: "Old streets"
        )
    }
}
