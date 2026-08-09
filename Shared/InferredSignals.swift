import Foundation

// MARK: - Inferring the two private scores from more than self-report
//
// The Rut and the reader's aliveness both move on evidence the reader never had
// to type. The seam this works through already exists: `NothingTide.rutAssessment`
// returns `pressure` — private curation weight — and `mayNameRut` — permission to
// speak — as separate fields.
//
//   Inferred signals may move `pressure`. They may never touch `mayNameRut`.
//
// That is what doctrine rule 3 is actually protecting. The harm in reading the
// Rut off behaviour was never the reading; it was the Book turning around and
// telling someone they are in a rut because they went quiet. The Book here gets
// to respond and never to accuse.
//
// Two further rules hold this honest:
//
// 1. The Rut is measured as FLATTENING, never as heaviness. Someone writing
//    heavily about a dying parent is intensely alive. Heavy ink plus specificity
//    is aliveness; heavy ink plus flatness is the Rut. Every measure below keys
//    on flatness and none on tone, deliberately.
//
// 2. The Book must not score itself with the signal it optimises. Reader-answered
//    pulses and lived receipts remain the SCORING and are deliberately absent
//    from this file — if inferred aliveness both drove curation and measured
//    whether curation worked, the loop would close and the Book would reliably
//    discover it was doing well. What is here informs; what is not here judges.

// MARK: Leans

enum InferredLean: String, Codable, Equatable {
    case rutward
    case neutral
    case aliveward
}

/// What the Book watches, and what a move in each direction means. Several are
/// deliberately asymmetric: a collapse in sentence length is a flattening, but a
/// burst of long sentences is not therefore an aliveness. Where a direction
/// means nothing reliable, it means nothing.
enum InferredMeasure: String, Codable, CaseIterable {
    /// Particularity: names, places, numbers — the grain of an actual day.
    /// The Rut's own definition is "the grey loss of particular life", so this
    /// is not a proxy for the Rut. It is the thing itself.
    case specificity
    /// How much each page resembles the one before it. Days becoming
    /// interchangeable is the definition of the flattening.
    case selfSimilarity
    /// Vocabulary range, measured over an equal number of words from each
    /// window so a quiet fortnight cannot masquerade as a narrowing one.
    case lexicalRange
    case sentenceLength
    /// Distinct page types and places in the window.
    case variety
    case questionAsking
    /// Places and page kinds appearing that were not there before.
    case novelty

    var risingLean: InferredLean {
        switch self {
        case .specificity, .variety, .questionAsking, .novelty: return .aliveward
        case .selfSimilarity: return .rutward
        case .lexicalRange, .sentenceLength: return .neutral
        }
    }

    var fallingLean: InferredLean {
        switch self {
        case .specificity, .lexicalRange, .sentenceLength, .variety: return .rutward
        case .selfSimilarity, .questionAsking, .novelty: return .neutral
        }
    }

    var evidenceTag: String {
        "inferred:\(rawValue)"
    }
}

struct InferredSignal: Codable, Equatable {
    var measure: InferredMeasure
    var lean: InferredLean
    /// 1 for a clear move, 2 for a large one. Never more.
    var strength: Int
    var recentSampleCount: Int
    var priorSampleCount: Int

    var evidenceTag: String { measure.evidenceTag }
}

// MARK: The reading

struct InferredReaderSignals: Codable, Equatable {
    var signals: [InferredSignal]
    var computedAt: Date
    var isReady: Bool

    static let unwritten = InferredReaderSignals(
        signals: [],
        computedAt: .distantPast,
        isReady: false
    )

    var rutwardWeight: Int {
        signals.filter { $0.lean == .rutward }.reduce(0) { $0 + $1.strength }
    }

    var alivewardWeight: Int {
        signals.filter { $0.lean == .aliveward }.reduce(0) { $0 + $1.strength }
    }

    /// Rutward minus aliveward. Positive means the writing has been flattening.
    var net: Int {
        rutwardWeight - alivewardWeight
    }

    /// The only number this file is allowed to hand to the Rut, and it is
    /// capped at a single step in either direction. Behaviour may lean the
    /// Book's private weighting; it may never carry it.
    var rutPressureAdjustment: Int {
        guard isReady else { return 0 }
        if net >= InferredSignalGate.leanThreshold { return 1 }
        if net <= -InferredSignalGate.leanThreshold { return -1 }
        return 0
    }

    var alivenessLean: InferredLean {
        guard isReady else { return .neutral }
        if net >= InferredSignalGate.leanThreshold { return .rutward }
        if net <= -InferredSignalGate.leanThreshold { return .aliveward }
        return .neutral
    }

    /// Every tag behind the current reading, for audit. The `inferred:` prefix
    /// keeps the two lanes separable wherever evidence is inspected.
    var evidenceTags: [String] {
        signals.filter { $0.lean != .neutral }.map(\.evidenceTag).sorted()
    }
}

enum InferredSignalGate {
    /// Pages needed in each of the two windows before anything is read.
    static let minimumPagesPerWindow = 8
    /// Days in each window.
    static let windowDays = 14
    /// Net weight before a lean is called at all.
    static let leanThreshold = 3
    /// A change this large, as a fraction of the larger of the two windows,
    /// counts as a move; twice this is a large one.
    static let moveFraction = 0.20
    /// Inferred weight may never push the Rut to its top band. Naming the deep
    /// water requires the reader to say so.
    static let inferredPressureCeiling = 2
}

// MARK: - Applying it

enum InferredRutApplication {
    /// The Rut's private pressure, leaned by behaviour and capped.
    ///
    /// `mayNameRut` is deliberately not a parameter: nothing in this file can
    /// change it, and passing it through would invite a future caller to try.
    static func adjustedPressure(
        base: Int,
        signals: InferredReaderSignals
    ) -> Int {
        let adjusted = base + signals.rutPressureAdjustment
        // Never below the ordinary-life floor, and never into the top band on
        // inferred evidence alone — though a reader who has reported their way
        // there keeps their own level.
        let ceiling = max(base, InferredSignalGate.inferredPressureCeiling)
        return min(ceiling, max(1, adjusted))
    }
}

// MARK: - Reading the signals

enum InferredSignalReader {
    /// `pages` should be the reader's authored pages, newest or oldest first —
    /// they are sorted here. `rows` supplies variety and novelty, which are
    /// properties of days rather than of prose.
    static func read(
        pages: [BookPage],
        rows: [DaybookEntry],
        ledger: StandingLedger,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InferredReaderSignals {
        guard let recentCutoff = calendar.date(
                byAdding: .day,
                value: -InferredSignalGate.windowDays,
                to: calendar.startOfDay(for: now)
              ),
              let priorCutoff = calendar.date(
                byAdding: .day,
                value: -2 * InferredSignalGate.windowDays,
                to: calendar.startOfDay(for: now)
              ) else {
            return .unwritten
        }

        let authored = pages
            .filter { $0.origin == .userAuthored && !$0.userInput.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
        let recent = authored.filter { $0.createdAt >= recentCutoff }
        let prior = authored.filter { $0.createdAt >= priorCutoff && $0.createdAt < recentCutoff }

        guard recent.count >= InferredSignalGate.minimumPagesPerWindow,
              prior.count >= InferredSignalGate.minimumPagesPerWindow else {
            return InferredReaderSignals(signals: [], computedAt: now, isReady: false)
        }

        let recentRows = rows.filter { $0.date >= recentCutoff }
        let priorRows = rows.filter { $0.date >= priorCutoff && $0.date < recentCutoff }

        var signals: [InferredSignal] = []

        func add(_ measure: InferredMeasure, recentValue: Double?, priorValue: Double?) {
            guard let recentValue, let priorValue else { return }
            signals.append(
                signal(
                    measure: measure,
                    recent: recentValue,
                    prior: priorValue,
                    recentCount: recent.count,
                    priorCount: prior.count
                )
            )
        }

        add(.specificity,
            recentValue: specificity(of: recent),
            priorValue: specificity(of: prior))
        add(.selfSimilarity,
            recentValue: selfSimilarity(of: recent),
            priorValue: selfSimilarity(of: prior))
        add(.lexicalRange,
            recentValue: lexicalRange(of: recent, matching: prior),
            priorValue: lexicalRange(of: prior, matching: recent))
        add(.sentenceLength,
            recentValue: medianWords(of: recent),
            priorValue: medianWords(of: prior))
        add(.questionAsking,
            recentValue: questionRate(of: recent),
            priorValue: questionRate(of: prior))
        add(.variety,
            recentValue: variety(of: recentRows),
            priorValue: variety(of: priorRows))

        if let novelty = novelty(recent: recentRows, prior: priorRows) {
            signals.append(
                signal(
                    measure: .novelty,
                    recent: novelty.recent,
                    prior: novelty.prior,
                    recentCount: recentRows.count,
                    priorCount: priorRows.count
                )
            )
        }

        // The Ledger's own tenure gate governs here too: measures compared
        // against two thin fortnights are a Tuesday, not a trend.
        return InferredReaderSignals(
            signals: signals,
            computedAt: now,
            isReady: ledger.isReady
        )
    }

    static func signal(
        measure: InferredMeasure,
        recent: Double,
        prior: Double,
        recentCount: Int,
        priorCount: Int
    ) -> InferredSignal {
        // Relative to the larger of the two rather than to the prior window.
        // Dividing by `prior` silently swallows the most meaningful move a
        // measure can make — the one away from zero. A fortnight with no
        // particulars in it at all, followed by one full of names and places,
        // is not "no change"; it is the largest change available.
        let denominator = max(abs(recent), abs(prior))
        let change = denominator > 0 ? (recent - prior) / denominator : 0
        let magnitude = abs(change)
        let strength: Int
        if magnitude >= InferredSignalGate.moveFraction * 2 {
            strength = 2
        } else if magnitude >= InferredSignalGate.moveFraction {
            strength = 1
        } else {
            strength = 0
        }

        let lean: InferredLean = strength == 0
            ? .neutral
            : (change > 0 ? measure.risingLean : measure.fallingLean)

        return InferredSignal(
            measure: measure,
            // A move in a direction that means nothing carries no weight.
            lean: lean,
            strength: lean == .neutral ? 0 : strength,
            recentSampleCount: recentCount,
            priorSampleCount: priorCount
        )
    }

    // MARK: Prose measures

    /// Particularity per hundred words: mid-sentence capitalised tokens (names,
    /// places) and numerals. Sentence-initial capitals are excluded — they are
    /// grammar, not grain.
    static func specificity(of pages: [BookPage]) -> Double? {
        var particulars = 0
        var words = 0
        for page in pages {
            for sentence in sentences(in: page.userInput) {
                let tokens = sentence.split { !$0.isLetter && !$0.isNumber }.map(String.init)
                guard !tokens.isEmpty else { continue }
                words += tokens.count
                for (index, token) in tokens.enumerated() {
                    if token.contains(where: \.isNumber) {
                        particulars += 1
                    } else if index > 0, token.first?.isUppercase == true {
                        particulars += 1
                    }
                }
            }
        }
        guard words > 0 else { return nil }
        return Double(particulars) / Double(words) * 100
    }

    /// Mean overlap between each page and the one before it. Rising overlap is
    /// days becoming interchangeable.
    static func selfSimilarity(of pages: [BookPage]) -> Double? {
        let sets = pages.map { contentWords(in: $0.userInput) }.filter { !$0.isEmpty }
        guard sets.count >= 2 else { return nil }
        var total = 0.0
        for index in 1..<sets.count {
            let a = sets[index - 1]
            let b = sets[index]
            let union = a.union(b).count
            total += union > 0 ? Double(a.intersection(b).count) / Double(union) : 0
        }
        return total / Double(sets.count - 1)
    }

    /// Type-token ratio over an equal number of words from each window, so a
    /// fortnight that simply had less writing in it cannot read as a narrowing
    /// vocabulary. That confound is the whole difficulty with this measure.
    static func lexicalRange(of pages: [BookPage], matching other: [BookPage]) -> Double? {
        let mine = allContentWords(in: pages)
        let theirs = allContentWords(in: other)
        let sampleSize = min(mine.count, theirs.count)
        guard sampleSize >= 40 else { return nil }
        let sample = Array(mine.prefix(sampleSize))
        return Double(Set(sample).count) / Double(sample.count)
    }

    static func medianWords(of pages: [BookPage]) -> Double? {
        let counts = pages.map { Double(DaybookRecorder.wordCount($0.userInput)) }
        return StandingLedgerBuilder.median(counts)
    }

    static func questionRate(of pages: [BookPage]) -> Double? {
        guard !pages.isEmpty else { return nil }
        let asking = pages.filter { $0.userInput.contains("?") }.count
        return Double(asking) / Double(pages.count)
    }

    // MARK: Day measures

    /// Distinct page kinds and places in the window, per day.
    static func variety(of rows: [DaybookEntry]) -> Double? {
        guard !rows.isEmpty else { return nil }
        let types = Set(rows.flatMap(\.keptPageTypes))
        let places = Set(rows.compactMap(\.placeLabel).filter { !$0.isEmpty })
        return Double(types.count + places.count)
    }

    /// Kinds and places in the recent window that were not in the prior one.
    /// Reported against a baseline of one so the ratio stays defined when the
    /// prior fortnight brought nothing new.
    static func novelty(
        recent: [DaybookEntry],
        prior: [DaybookEntry]
    ) -> (recent: Double, prior: Double)? {
        guard !recent.isEmpty, !prior.isEmpty else { return nil }
        let priorKeys = Set(prior.flatMap(\.keptPageTypes))
            .union(prior.compactMap(\.placeLabel))
        let recentKeys = Set(recent.flatMap(\.keptPageTypes))
            .union(recent.compactMap(\.placeLabel))
        let fresh = recentKeys.subtracting(priorKeys).count
        return (Double(fresh) + 1, 1)
    }

    // MARK: Words

    /// Deliberately small. A longer stop list would start removing the ordinary
    /// words whose disappearance is exactly what a narrowing looks like.
    static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "than", "that",
        "this", "these", "those", "of", "to", "in", "on", "at", "for", "with",
        "from", "by", "as", "is", "are", "was", "were", "be", "been", "being",
        "it", "its", "i", "me", "my", "you", "your", "he", "she", "they", "we",
        "them", "his", "her", "their", "our", "so", "just", "not", "no", "do",
        "did", "does", "have", "has", "had", "will", "would", "can", "could"
    ]

    static func allContentWords(in pages: [BookPage]) -> [String] {
        pages.flatMap { page in
            page.userInput
                .lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count > 2 && !stopWords.contains($0) }
        }
    }

    static func contentWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count > 2 && !stopWords.contains($0) }
        )
    }

    static func sentences(in text: String) -> [String] {
        text.split { $0 == "." || $0 == "!" || $0 == "?" || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
