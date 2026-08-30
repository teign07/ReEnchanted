import Foundation

/// The maps the Book draws of the reader, rather than of the Academy.
///
/// The Margins Atlas was a three-card deck — the Loom, the Constellation and
/// the Company — and all three drew the *world*: the cast, where Belief went,
/// the people the reader names. Measured over a fortnight the Atlas reached the
/// desk ten to twelve times out of three distinct Pages, because three is how
/// many maps existed. No rest rule can fix a deck that small. The Book needed
/// more to draw.
///
/// These are drawn from nothing but the reader's own kept Pages: the words they
/// used, and the hour, sky and place the context snapshot recorded when they
/// wrote them. Nothing here infers a mood, a meaning, or a cause. Every edge is
/// something the reader actually did — this word, under that sky, at that hour
/// — which is the only sort of claim the Book is entitled to make about
/// somebody's life.
enum ReaderAtlas {
    /// A map wants enough lines to be a map. Below these the Book has a
    /// coincidence, not a cartography, and it should say nothing.
    static let minimumEdges = 3
    /// Two conditions at minimum, or the "map" is one column: every word the
    /// reader has ever written, filed under `morning`.
    static let minimumConditions = 2
    /// A word has to come back. One page can put any word on a map; recurrence
    /// is the whole claim these maps make.
    static let minimumPagesPerWord = 2

    // MARK: - The maps

    /// When the reader writes, and what they write then.
    static func hours(days: [BookDay], calendar: Calendar = .current) -> NarrativeGraphData {
        conditionMap(
            ink: ink(in: days, calendar: calendar),
            conditionKind: "hour",
            conditions: { $0.dayPart.map { [$0] } ?? [] },
            edgeLabel: { "written in the \($0)" }
        )
    }

    /// The weather the reader's words keep arriving in.
    static func skies(days: [BookDay], calendar: Calendar = .current) -> NarrativeGraphData {
        conditionMap(
            ink: ink(in: days, calendar: calendar),
            conditionKind: "sky",
            conditions: { $0.skies },
            edgeLabel: { "written under \($0)" }
        )
    }

    /// Where the reader was standing when they wrote.
    static func places(days: [BookDay], calendar: Calendar = .current) -> NarrativeGraphData {
        conditionMap(
            ink: ink(in: days, calendar: calendar),
            conditionKind: "place",
            conditions: { $0.place.map { [$0] } ?? [] },
            edgeLabel: { "written at \($0)" }
        )
    }

    /// The reader's own vocabulary, and which of their words keep arriving
    /// together. This is the one map with no conditions in it at all: it is
    /// made entirely of things the reader chose to write down.
    static func lexicon(days: [BookDay], calendar: Calendar = .current) -> NarrativeGraphData {
        let ink = ink(in: days, calendar: calendar)
        let recurring = recurringWords(in: ink)
        guard recurring.count >= 3 else { return .empty }

        var pairCounts: [String: Int] = [:]
        for page in ink {
            let words = page.words.filter { recurring[$0] != nil }.sorted()
            guard words.count > 1 else { continue }
            for (index, left) in words.enumerated() {
                for right in words.dropFirst(index + 1) {
                    pairCounts[NarrativeGraphData.relationshipPairKey(left, right), default: 0] += 1
                }
            }
        }
        guard pairCounts.count >= minimumEdges else { return .empty }

        let ranked: [(key: String, value: Int)] = pairCounts.sorted { left, right in
            left.value == right.value ? left.key < right.key : left.value > right.value
        }
        var edges: [GraphEdge] = []
        for (pair, count) in ranked.prefix(24) {
            let ends: [String] = pair.split(separator: "|").map(String.init)
            guard ends.count == 2 else { continue }
            edges.append(GraphEdge(
                id: "lexicon-\(pair)",
                sourceID: "word-\(ends[0])",
                targetID: "word-\(ends[1])",
                strength: strength(count),
                // Warmth here is recurrence, not sentiment: a pair the reader
                // keeps bringing back together is drawn warmer. The Book is not
                // claiming to know how they feel about it.
                warmth: min(0.6, Double(count) / 5.0),
                label: count > 2 ? "keeps arriving together" : "arrived together"
            ))
        }
        let usedWords: Set<String> = Set(edges.flatMap { [$0.sourceID, $0.targetID] })
        let nodes: [GraphNode] = wordNodes(recurring, keeping: usedWords)
        guard nodes.count >= 3 else { return .empty }
        return NarrativeGraphData(nodes: nodes, edges: edges)
    }

    // MARK: - The reader's ink

    private struct Ink {
        var words: [String]
        var dayPart: String?
        var skies: [String]
        var place: String?
    }

    private static func ink(in days: [BookDay], calendar: Calendar) -> [Ink] {
        days.flatMap(\.pages).compactMap { page -> Ink? in
            // The Book's own braid is not the reader writing.
            guard page.type != .bookOfYou,
                  let text = page.readerAuthoredTextForAnalysis?.nonEmpty
            else { return nil }
            let words = KeepMarginalia.loadBearingWords(in: text)
            guard !words.isEmpty else { return nil }
            let recorded = page.context?.dayPart.nonEmpty
            return Ink(
                words: words,
                // Pages kept before the context snapshot existed still know
                // their own hour, so the oldest ink is not left off the map.
                dayPart: (recorded == "unknown" ? nil : recorded) ?? dayPart(of: page.createdAt, calendar: calendar),
                skies: page.context?.weatherTags.compactMap(\.nonEmpty) ?? [],
                place: page.context?.locationLabel?.nonEmpty
            )
        }
    }

    private static func dayPart(of date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...20: return "evening"
        default: return "night"
        }
    }

    /// Words the reader has used on more than one Page, and how many.
    private static func recurringWords(in ink: [Ink]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for page in ink {
            for word in Set(page.words) { counts[word, default: 0] += 1 }
        }
        return counts.filter { $0.value >= minimumPagesPerWord }
    }

    // MARK: - Drawing

    /// Every conditional map has the same shape: the circumstances the Book
    /// recorded down one side, the reader's recurring words down the other, and
    /// a line wherever the two actually met on a Page.
    private static func conditionMap(
        ink: [Ink],
        conditionKind: String,
        conditions: (Ink) -> [String],
        edgeLabel: (String) -> String
    ) -> NarrativeGraphData {
        let recurring = recurringWords(in: ink)
        guard !recurring.isEmpty else { return .empty }

        var pairCounts: [String: [String: Int]] = [:]
        var conditionCounts: [String: Int] = [:]
        for page in ink {
            let found = Set(conditions(page))
            guard !found.isEmpty else { continue }
            let words = page.words.filter { recurring[$0] != nil }
            guard !words.isEmpty else { continue }
            for condition in found {
                conditionCounts[condition, default: 0] += 1
                for word in Set(words) {
                    pairCounts[condition, default: [:]][word, default: 0] += 1
                }
            }
        }
        guard conditionCounts.count >= minimumConditions else { return .empty }

        var edges: [GraphEdge] = []
        for (condition, words) in pairCounts {
            for (word, count) in words {
                edges.append(GraphEdge(
                    id: "\(conditionKind)-\(condition)-\(word)",
                    sourceID: "\(conditionKind)-\(condition)",
                    targetID: "word-\(word)",
                    strength: strength(count),
                    warmth: min(0.6, Double(count) / 5.0),
                    label: edgeLabel(condition)
                ))
            }
        }
        // The strongest lines first, so a busy archive draws a legible map
        // rather than every word it has ever met.
        let strongestFirst: [GraphEdge] = edges.sorted { left, right in
            left.strength == right.strength ? left.id < right.id : left.strength > right.strength
        }
        edges = Array(strongestFirst.prefix(24))
        guard edges.count >= minimumEdges else { return .empty }

        let usedIDs: Set<String> = Set(edges.flatMap { [$0.sourceID, $0.targetID] })
        var conditionNodes: [GraphNode] = []
        for (condition, count) in conditionCounts {
            let id: String = "\(conditionKind)-\(condition)"
            guard usedIDs.contains(id) else { continue }
            let weight: Int = max(8, min(30, count * 3))
            conditionNodes.append(GraphNode(
                id: id,
                label: condition.replacingOccurrences(of: "-", with: " "),
                weight: Double(weight),
                chapterID: nil,
                kindLabel: conditionKind
            ))
        }
        conditionNodes = sortedByWeight(conditionNodes)
        let words: [GraphNode] = wordNodes(recurring, keeping: usedIDs)
        guard conditionNodes.count >= minimumConditions, words.count >= 2 else { return .empty }
        return NarrativeGraphData(nodes: conditionNodes + words, edges: edges)
    }

    private static func wordNodes(_ recurring: [String: Int], keeping usedIDs: Set<String>) -> [GraphNode] {
        var nodes: [GraphNode] = []
        for (word, pages) in recurring where usedIDs.contains("word-\(word)") {
            nodes.append(wordNode(word, pages: pages))
        }
        return sortedByWeight(nodes)
    }

    private static func sortedByWeight(_ nodes: [GraphNode]) -> [GraphNode] {
        nodes.sorted { left, right in
            left.weight == right.weight ? left.id < right.id : left.weight > right.weight
        }
    }

    private static func wordNode(_ word: String, pages: Int) -> GraphNode {
        GraphNode(
            id: "word-\(word)",
            label: word,
            weight: Double(max(6, min(26, pages * 4))),
            chapterID: nil,
            kindLabel: "word"
        )
    }

    private static func strength(_ count: Int) -> Double {
        min(1.0, 0.25 + Double(count) * 0.15)
    }
}

/// The reader's vocabulary over time: which of their own words they have used,
/// when, and in what sentence.
///
/// Most of the Book's noticing is gated on an optional subsystem — a person
/// thread opened, a connection found, a wager sealed — so in a fortnight of
/// simulated reading only four distinct Notices ever fired out of fifteen
/// kinds. These findings are gated on nothing but the reader having written
/// something twice, which is the one thing an archive always has.
struct ReaderVocabulary {
    struct Use: Equatable {
        var pageID: String
        var at: Date
        /// The sentence the word arrived in, kept whole so the Book can show
        /// its evidence rather than assert a pattern.
        var quote: String
    }

    /// word → every use, oldest first.
    var uses: [String: [Use]] = [:]

    var isEmpty: Bool { uses.isEmpty }

    static func of(days: [BookDay]) -> ReaderVocabulary {
        ArchiveMemo.value("reader.vocabulary", days: days) { build(days: days) }
    }

    private static func build(days: [BookDay]) -> ReaderVocabulary {
        var vocabulary = ReaderVocabulary()
        let pages = days
            .flatMap(\.pages)
            .filter { $0.type != .bookOfYou }
            .sorted { $0.createdAt < $1.createdAt }
        for page in pages {
            guard let text = page.readerAuthoredTextForAnalysis?.nonEmpty else { continue }
            let quote = clipped(text)
            for word in KeepMarginalia.loadBearingWords(in: text) {
                vocabulary.uses[word, default: []].append(
                    Use(pageID: page.id, at: page.createdAt, quote: quote)
                )
            }
        }
        return vocabulary
    }

    private static func clipped(_ text: String, limit: Int = 140) -> String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > limit else { return flat }
        return String(flat.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}

/// Findings the Book can make out of the reader's own vocabulary alone.
///
/// Each is a fact with its evidence attached and no interpretation: the word,
/// the two sentences, the gap. The Book says what it noticed and hands the
/// meaning back, which is the only claim it is entitled to make about a life it
/// only sees through kept pages.
enum ReaderVocabularyNotice {
    /// A word has to have been gone this long for its return to be a return
    /// rather than a habit.
    static let returnGapDays = 45.0
    /// And the archive has to be old enough that a first use is genuinely a
    /// first, rather than the Book meeting the reader.
    static let firstUseArchiveDays = 30.0

    struct Returned: Equatable {
        var word: String
        var earlier: ReaderVocabulary.Use
        var recent: ReaderVocabulary.Use
        var gapDays: Int
    }

    struct FirstUse: Equatable {
        var word: String
        var use: ReaderVocabulary.Use
        var archivedWords: Int
    }

    struct Pair: Equatable {
        var first: String
        var second: String
        var together: Int
        var latestQuote: String
    }

    /// A word the reader used long ago and has just used again.
    static func returned(in vocabulary: ReaderVocabulary, now: Date) -> Returned? {
        var best: Returned?
        for (word, uses) in vocabulary.uses where uses.count > 1 {
            guard let recent = uses.last,
                  now.timeIntervalSince(recent.at) <= 3 * 86_400 else { continue }
            let previous = uses[uses.count - 2]
            let gap = recent.at.timeIntervalSince(previous.at)
            guard gap >= returnGapDays * 86_400 else { continue }
            let candidate = Returned(
                word: word,
                earlier: previous,
                recent: recent,
                gapDays: Int(gap / 86_400)
            )
            // The longest silence is the most worth remarking on, and ties
            // break on the word so the finding is stable across rebuilds.
            if let current = best {
                if candidate.gapDays > current.gapDays
                    || (candidate.gapDays == current.gapDays && candidate.word < current.word) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        return best
    }

    /// A word the reader has never written before, in an archive old enough for
    /// that to mean something.
    static func firstUse(in vocabulary: ReaderVocabulary, days: [BookDay], now: Date) -> FirstUse? {
        let oldest = days.flatMap(\.pages).map(\.createdAt).min()
        guard let oldest, now.timeIntervalSince(oldest) >= firstUseArchiveDays * 86_400 else { return nil }
        var best: FirstUse?
        for (word, uses) in vocabulary.uses where uses.count == 1 {
            guard let only = uses.first,
                  now.timeIntervalSince(only.at) <= 2 * 86_400 else { continue }
            let candidate = FirstUse(word: word, use: only, archivedWords: vocabulary.uses.count)
            // The longest word is the most particular, and particularity is
            // what makes a first use worth mentioning at all.
            if let current = best {
                if candidate.word.count > current.word.count
                    || (candidate.word.count == current.word.count && candidate.word < current.word) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        return best
    }

    /// Two words that keep arriving on the same page.
    static func pair(in vocabulary: ReaderVocabulary, minimumTogether: Int = 3) -> Pair? {
        var pageWords: [String: Set<String>] = [:]
        var latestByPage: [String: (Date, String)] = [:]
        for (word, uses) in vocabulary.uses where uses.count > 1 {
            for use in uses {
                pageWords[use.pageID, default: []].insert(word)
                latestByPage[use.pageID] = (use.at, use.quote)
            }
        }
        var counts: [String: Int] = [:]
        var latest: [String: (Date, String)] = [:]
        for (pageID, words) in pageWords {
            let sorted = words.sorted()
            guard sorted.count > 1 else { continue }
            for (index, left) in sorted.enumerated() {
                for right in sorted.dropFirst(index + 1) {
                    let key = "\(left)|\(right)"
                    counts[key, default: 0] += 1
                    if let seen = latestByPage[pageID],
                       latest[key] == nil || seen.0 > latest[key]!.0 {
                        latest[key] = seen
                    }
                }
            }
        }
        let winner = counts
            .filter { $0.value >= minimumTogether }
            .max { left, right in
                left.value == right.value ? left.key > right.key : left.value < right.value
            }
        guard let winner else { return nil }
        let ends = winner.key.split(separator: "|").map(String.init)
        guard ends.count == 2 else { return nil }
        return Pair(
            first: ends[0],
            second: ends[1],
            together: winner.value,
            latestQuote: latest[winner.key]?.1 ?? ""
        )
    }
}

/// How often this reader actually opens the Book.
///
/// Every time constant in the Curator was written for an imagined reader who
/// opens the Book about three times a day: instruments rest three and a half
/// hours, a kept sentence stays owed an answer for seventy-two, a Page waits
/// six to ten hours per sibling in its deck. None of that is wrong so much as
/// it is *somebody else's*. A reader who opens the Book twice a week meets a
/// desk tuned for someone who opens it twenty times, and the bursty reader in
/// the simulation is exactly who those constants fail.
///
/// So the Curator measures the reader's own rhythm and scales its clocks by it.
/// A sitting is however long this reader's sittings are.
struct ReaderTempo: Equatable {
    /// Distinct sittings per day, measured over recent history.
    var sittingsPerDay: Double
    /// Typical hours between one sitting and the next.
    var hoursBetweenSittings: Double

    /// What the Curator assumed before it could measure: about three sittings a
    /// day. New readers get this until they have a rhythm of their own, so
    /// nothing about a first week changes.
    static let assumed = ReaderTempo(sittingsPerDay: 3, hoursBetweenSittings: 6)

    /// Two Pages served eleven minutes apart are one sitting, not two.
    private static let sittingBucketMinutes = 45.0
    /// Long enough to average out a quiet week, short enough to follow a reader
    /// whose life has changed.
    private static let observationDays = 21.0

    /// Instruments are tools: one should be within reach each sitting, and not
    /// twice in the same one. Slightly under the reader's own gap does both.
    var instrumentSpacingHours: Double {
        min(18, max(1.5, hoursBetweenSittings * 0.6))
    }

    /// A kept sentence stays owed an answer for about four of this reader's own
    /// sittings — long enough to survive a gap, short enough that the answer
    /// still belongs to the thing that happened.
    var answerWindowHours: Double {
        min(240, max(18, hoursBetweenSittings * 4))
    }

    /// A Page waits roughly one sitting per sibling in its deck.
    var appetitePerSiblingHours: Double {
        min(24, max(3, hoursBetweenSittings))
    }

    /// Measured from when Pages were actually served: the Book's own record of
    /// being opened. Falls back to `assumed` until there is enough to see.
    static func measured(history: [String: SurfaceHistoryRecord], now: Date) -> ReaderTempo {
        let cutoff = now.addingTimeInterval(-observationDays * 86_400)
        let bucket = sittingBucketMinutes * 60
        var sittings = Set<Int>()
        var earliest = now
        for record in history.values where record.lastShownAt >= cutoff && record.lastShownAt <= now {
            sittings.insert(Int(record.lastShownAt.timeIntervalSince1970 / bucket))
            earliest = min(earliest, record.lastShownAt)
        }
        // Three sittings is not a rhythm. Below that the Book keeps its
        // assumption rather than tuning itself to noise.
        guard sittings.count >= 3 else { return assumed }
        let observed = max(1.0, now.timeIntervalSince(earliest) / 86_400)
        let perDay = max(0.05, Double(sittings.count) / observed)
        return ReaderTempo(
            sittingsPerDay: perDay,
            hoursBetweenSittings: min(96, max(1, 24 / perDay))
        )
    }

    /// Memoised: the tempo changes slowly, and it is read on every eligibility
    /// check for every candidate.
    static func current(history: [String: SurfaceHistoryRecord], now: Date) -> ReaderTempo {
        let stamp = history.values.map(\.lastShownAt).max() ?? .distantPast
        let key = "\(history.count)|\(Int(stamp.timeIntervalSince1970 / 900))"
        cacheLock.lock()
        if let hit = cache[key] { cacheLock.unlock(); return hit }
        cacheLock.unlock()
        let made = measured(history: history, now: now)
        cacheLock.lock()
        if cache.count > 16 { cache.removeAll(keepingCapacity: true) }
        cache[key] = made
        cacheLock.unlock()
        return made
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: ReaderTempo] = [:]
}

// MARK: - Findings about how the reader writes, not only what

extension ReaderVocabularyNotice {
    /// A subject has to be this quiet before its absence is a fact rather than
    /// a gap between two ordinary weeks.
    static let vanishGapDays = 60.0
    /// And it has to have been a habit first, or every word the reader used
    /// once and dropped becomes a finding.
    static let vanishMinimumUses = 4

    struct Vanished: Equatable {
        var word: String
        var uses: Int
        var lastSeenDays: Int
        var lastQuote: String
    }

    /// A word that used to keep coming and has stopped.
    ///
    /// The most delicate finding here. Said plainly it is an accusation — *you
    /// have stopped caring about this* — which the Book has no way of knowing
    /// and no business implying. It is safe only as an inventory fact: the word
    /// was here often, and it has not been here lately, and that is all.
    static func vanished(in vocabulary: ReaderVocabulary, now: Date) -> Vanished? {
        var best: Vanished?
        for (word, uses) in vocabulary.uses where uses.count >= vanishMinimumUses {
            guard let last = uses.last else { continue }
            let quiet = now.timeIntervalSince(last.at)
            guard quiet >= vanishGapDays * 86_400 else { continue }
            // It has to have been a real habit: several uses inside a stretch
            // shorter than the silence that followed.
            guard let first = uses.first,
                  last.at.timeIntervalSince(first.at) < quiet else { continue }
            let candidate = Vanished(
                word: word,
                uses: uses.count,
                lastSeenDays: Int(quiet / 86_400),
                lastQuote: last.quote
            )
            if let current = best {
                if candidate.uses > current.uses
                    || (candidate.uses == current.uses && candidate.word < current.word) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        return best
    }

    struct HourShift: Equatable {
        var earlierPart: String
        var recentPart: String
        var earlierShare: Int
        var recentShare: Int
    }

    /// The reader used to write at one part of the day and now writes at
    /// another.
    static func hourShift(days: [BookDay], now: Date, calendar: Calendar = .current) -> HourShift? {
        let pages = days
            .flatMap(\.pages)
            .filter { $0.type != .bookOfYou && $0.readerAuthoredTextForAnalysis?.nonEmpty != nil }
            .sorted { $0.createdAt < $1.createdAt }
        guard pages.count >= 20 else { return nil }
        let split = pages.count / 2
        func share(_ slice: ArraySlice<BookPage>) -> [String: Int] {
            var counts: [String: Int] = [:]
            for page in slice {
                let recorded = page.context?.dayPart.nonEmpty
                let part = (recorded == "unknown" ? nil : recorded) ?? dayPartName(page.createdAt, calendar)
                counts[part, default: 0] += 1
            }
            return counts
        }
        let earlier = share(pages[..<split])
        let recent = share(pages[split...])
        guard let earlierTop = earlier.max(by: { $0.value < $1.value }),
              let recentTop = recent.max(by: { $0.value < $1.value }),
              earlierTop.key != recentTop.key else { return nil }
        let earlierPercent = Int(Double(earlierTop.value) / Double(max(1, split)) * 100)
        let recentPercent = Int(Double(recentTop.value) / Double(max(1, pages.count - split)) * 100)
        // Both halves have to actually lean somewhere, or this is noise with a
        // winner in it.
        guard earlierPercent >= 40, recentPercent >= 40 else { return nil }
        return HourShift(
            earlierPart: earlierTop.key,
            recentPart: recentTop.key,
            earlierShare: earlierPercent,
            recentShare: recentPercent
        )
    }

    struct LengthShift: Equatable {
        var earlierWords: Int
        var recentWords: Int
        var grew: Bool
        var recentQuote: String
    }

    /// The reader's sentences have got markedly longer or shorter.
    ///
    /// Deliberately reported without a verdict. Shorter is not worse and longer
    /// is not better; the Book has met people who said everything in nine words
    /// and people who needed ninety.
    static func lengthShift(days: [BookDay]) -> LengthShift? {
        let inked = days
            .flatMap(\.pages)
            .filter { $0.type != .bookOfYou }
            .compactMap { page -> (Date, String)? in
                guard let text = page.readerAuthoredTextForAnalysis?.nonEmpty else { return nil }
                return (page.createdAt, text)
            }
            .sorted { $0.0 < $1.0 }
        guard inked.count >= 20 else { return nil }
        let split = inked.count / 2
        func averageWords(_ slice: ArraySlice<(Date, String)>) -> Int {
            let total = slice.reduce(0) { $0 + $1.1.split(whereSeparator: { $0.isWhitespace }).count }
            return total / max(1, slice.count)
        }
        let earlier = averageWords(inked[..<split])
        let recent = averageWords(inked[split...])
        guard earlier > 0, recent > 0 else { return nil }
        let ratio = Double(recent) / Double(earlier)
        // A third longer or a quarter shorter. Below that it is a mood, not a
        // change.
        guard ratio >= 1.35 || ratio <= 0.75 else { return nil }
        return LengthShift(
            earlierWords: earlier,
            recentWords: recent,
            grew: ratio > 1,
            recentQuote: ReaderVocabulary.clippedQuote(inked.last?.1 ?? "")
        )
    }

    struct Anniversary: Equatable {
        var yearsAgo: Int
        var quote: String
        var monthName: String
    }

    /// Something the reader kept on this day in an earlier year.
    static func sameDayLastYear(days: [BookDay], now: Date, calendar: Calendar = .current) -> Anniversary? {
        let today = calendar.dateComponents([.month, .day], from: now)
        let thisYear = calendar.component(.year, from: now)
        var best: Anniversary?
        for page in days.flatMap(\.pages) where page.type != .bookOfYou {
            guard let text = page.readerAuthoredTextForAnalysis?.nonEmpty else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: page.createdAt)
            guard parts.month == today.month, parts.day == today.day,
                  let year = parts.year, year < thisYear else { continue }
            let candidate = Anniversary(
                yearsAgo: thisYear - year,
                quote: ReaderVocabulary.clippedQuote(text),
                monthName: monthName(page.createdAt, calendar)
            )
            if best == nil || candidate.yearsAgo < (best?.yearsAgo ?? .max) { best = candidate }
        }
        return best
    }

    private static func dayPartName(_ date: Date, _ calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...20: return "evening"
        default: return "night"
        }
    }

    private static func monthName(_ date: Date, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
}

extension ReaderVocabulary {
    static func clippedQuote(_ text: String, limit: Int = 140) -> String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > limit else { return flat }
        return String(flat.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
