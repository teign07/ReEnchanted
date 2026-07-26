import Foundation

/// What the Book noticed that the reader could not.
///
/// `EditionCurator` decides which pages are *worth* binding. This decides what
/// is worth *saying* about them — the connections nobody can see from inside
/// their own month, because seeing them requires holding thirty days still at
/// once.
///
/// Every revelation obeys the same two-sided honesty law the Book uses
/// everywhere else: a claim must carry both its hits and its base rate. "You
/// wrote about rain on six days" is a boast; "six of your nineteen written days
/// mention rain" is a reading. A finding that cannot state both does not bind.
///
/// Pure and deterministic: the same period always reveals the same things, in
/// the same order. Nothing here reaches for the local brain — these are
/// countable facts about the archive, and the Book should be able to state them
/// instantly and identically every time it is asked.
enum BindingRevelations {

    // MARK: Types

    struct Evidence: Codable, Equatable {
        var date: Date
        var excerpt: String
    }

    enum Kind: String, Codable, Equatable, CaseIterable {
        /// The same thing photographed again and again.
        case recurringSubject
        /// A colour the reader's images keep returning to.
        case recurringPalette
        /// A place that kept showing up beside the keeps.
        case recurringPlace
        /// A word the reader leant on without noticing.
        case recurringWord
        /// The hour their ink runs heaviest or brightest.
        case hourOfHonesty
        /// Weather that keeps arriving with a particular mood.
        case weatherAndInk
        /// Nearly the same sentence, written weeks apart.
        case saidItTwice
        /// Silence, then a return.
        case returnAfterSilence
    }

    struct Revelation: Identifiable, Codable, Equatable {
        var id: String
        var kind: Kind
        /// The short line that goes in the margin or the section heading.
        var title: String
        /// The Book's reading, including its own base rate.
        var body: String
        /// The pages this was read from, so the claim can be checked.
        var evidence: [Evidence]
        /// Higher binds first. Roughly "how much archive stood behind this".
        var strength: Int
    }

    // MARK: Tunables

    /// A sensory value must appear on at least this many *distinct days* before
    /// it counts as recurrence rather than one enthusiastic afternoon.
    static let minimumRecurringDays = 3
    /// A word must be leant on this often before the Book mentions it. Set above
    /// the incidental range so ordinary repetition stays unremarked.
    static let minimumWordUses = 4
    /// Two passages must be at least this far apart to be worth pointing at.
    /// Saying the same thing on consecutive nights is a mood, not an echo.
    static let echoMinimumDayGap = 9
    /// Lexical overlap (Jaccard over content words) at which two passages are
    /// treated as the same thought said twice.
    static let echoSimilarityFloor = 0.42
    /// A silence must run this long before returning from it is a story.
    static let silenceMinimumDays = 5
    /// A facet needs this share of the period's written days before a
    /// tone claim is honest rather than anecdotal.
    static let toneShareFloor = 0.5
    /// Nothing is claimed from a period thinner than this.
    static let minimumWrittenDays = 4

    /// Words too common to be anyone's signature. Deliberately broader than the
    /// search stop list: this one is guarding a *claim about the reader*, so it
    /// errs toward silence.
    static let unremarkableWords: Set<String> = [
        "about", "after", "again", "against", "almost", "already", "also",
        "always", "another", "anything", "around", "because", "been", "before",
        "being", "better", "between", "both", "came", "come", "could", "didn",
        "does", "doing", "done", "down", "each", "even", "ever", "every",
        "feel", "feeling", "felt", "first", "from", "gets", "getting", "goes",
        "going", "gone", "good", "got", "had", "has", "have", "having", "here",
        "how", "into", "isn", "it's", "its", "just", "keep", "kept", "know",
        "last", "least", "left", "less", "like", "little", "long", "look",
        "looked", "looking", "made", "make", "makes", "making", "many", "may",
        "maybe", "might", "more", "most", "much", "must", "near", "need",
        "never", "next", "nothing", "now", "off", "often", "once", "one",
        "only", "onto", "other", "our", "out", "over", "own", "put", "quite",
        "rather", "really", "right", "said", "same", "saw", "say", "see",
        "seen", "she", "should", "since", "small", "some", "something",
        "sometimes", "soon", "still", "such", "take", "taken", "than", "that",
        "the", "their", "them", "then", "there", "these", "they", "thing",
        "things", "think", "this", "those", "though", "thought", "three",
        "through", "time", "today", "together", "told", "too", "took", "two",
        "under", "until", "upon", "used", "very", "want", "wanted", "was",
        "way", "well", "went", "were", "what", "when", "where", "which",
        "while", "who", "whole", "why", "will", "with", "without", "won",
        "would", "yet", "you", "your", "yours"
    ]

    // MARK: Entry point

    /// Read a period and report what stands out. `pages` may arrive in any
    /// order. Results are strongest-first, then stable by id.
    static func find(
        pages: [BookPage],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 6
    ) -> [Revelation] {
        guard limit > 0 else { return [] }
        let written = pages
            .filter { !$0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
        let writtenDays = distinctDayCount(written, calendar: calendar)
        guard writtenDays >= minimumWrittenDays else { return [] }

        var found: [Revelation] = []
        found += sensoryRecurrences(pages: pages, calendar: calendar)
        found += wordRecurrence(pages: written, writtenDays: writtenDays, calendar: calendar)
        found += toneByDayPart(pages: written, writtenDays: writtenDays, calendar: calendar)
        found += toneByWeather(pages: written, writtenDays: writtenDays, calendar: calendar)
        found += echoes(pages: written, calendar: calendar)
        found += returnAfterSilence(pages: written, calendar: calendar)

        return Array(
            found
                .sorted { left, right in
                    if left.strength == right.strength { return left.id < right.id }
                    return left.strength > right.strength
                }
                .prefix(limit)
        )
    }

    // MARK: Sensory recurrence — subjects, palettes, places

    /// The Sensory Loom already records what a photograph was *of*, what colour
    /// it ran, and where the reader stood. Nobody scrolls their own archive
    /// counting these. The Book can.
    private static func sensoryRecurrences(
        pages: [BookPage],
        calendar: Calendar
    ) -> [Revelation] {
        var out: [Revelation] = []
        let lanes: [(SensoryObservation.Dimension, Kind)] = [
            (.subject, .recurringSubject),
            (.palette, .recurringPalette),
            (.place, .recurringPlace)
        ]

        for (dimension, kind) in lanes {
            // Days, not pages: eight photographs of one afternoon's harbour is
            // an afternoon, and the Book should not dress it as a habit.
            var daysByValue: [String: Set<Date>] = [:]
            var pagesByValue: [String: [BookPage]] = [:]
            for page in pages {
                let folio = page.sensoryFolio ?? SensoryFolioProjector.structuredFolio(from: page)
                for value in Set(folio.values(for: dimension)) {
                    guard isReportableSensoryValue(value) else { continue }
                    daysByValue[value, default: []].insert(calendar.startOfDay(for: page.createdAt))
                    pagesByValue[value, default: []].append(page)
                }
            }

            guard let (value, days) = daysByValue
                .filter({ $0.value.count >= minimumRecurringDays })
                .sorted(by: { left, right in
                    if left.value.count == right.value.count { return left.key < right.key }
                    return left.value.count > right.value.count
                })
                .first
            else { continue }

            let sourcePages = (pagesByValue[value] ?? []).sorted { $0.createdAt < $1.createdAt }
            out.append(
                Revelation(
                    id: "\(kind.rawValue):\(value)",
                    kind: kind,
                    title: sensoryTitle(kind: kind, value: value),
                    body: sensoryBody(kind: kind, value: value, dayCount: days.count),
                    evidence: evidence(from: sourcePages, limit: 3),
                    strength: 40 + days.count * 6
                )
            )
        }
        return out
    }

    /// Loom values arrive from several extractors, and some of them are
    /// bookkeeping rather than observation. A value the reader would not
    /// recognise as a description of their own life never binds.
    private static func isReportableSensoryValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 40 else { return false }
        guard trimmed.contains(where: \.isLetter) else { return false }
        // Entry ids and uuid-ish handles leak in through the context snapshot.
        if trimmed.contains("-") && trimmed.contains(where: \.isNumber) { return false }
        if trimmed.allSatisfy({ $0.isNumber || $0 == "." }) { return false }
        return !unremarkableWords.contains(trimmed)
    }

    private static func sensoryTitle(kind: Kind, value: String) -> String {
        switch kind {
        case .recurringSubject: return "You kept photographing \(value)"
        case .recurringPalette: return "Your month ran \(value)"
        case .recurringPlace: return "\(value.capitalizedFirst) kept showing up"
        default: return value
        }
    }

    private static func sensoryBody(kind: Kind, value: String, dayCount: Int) -> String {
        let days = dayCount == 1 ? "one day" : "\(dayCount) separate days"
        switch kind {
        case .recurringSubject:
            return "It appears in what you kept on \(days). I doubt you were counting. Something in it keeps asking to be looked at again."
        case .recurringPalette:
            return "\(days.capitalizedFirst) of your images came back in this register. Not a decision you made — just the light you kept walking into."
        case .recurringPlace:
            return "This place stands behind \(days) of what you kept. Rooms get into writing without being written about."
        default:
            return ""
        }
    }

    // MARK: A word the reader leant on

    /// The reader's own vocabulary, counted. This is the finding that most
    /// reliably surprises: nobody hears their own refrains.
    private static func wordRecurrence(
        pages: [BookPage],
        writtenDays: Int,
        calendar: Calendar
    ) -> [Revelation] {
        var uses: [String: Int] = [:]
        var daysByWord: [String: Set<Date>] = [:]
        var pagesByWord: [String: [BookPage]] = [:]

        for page in pages {
            let day = calendar.startOfDay(for: page.createdAt)
            for token in Set(contentWords(in: page.userInput)) {
                daysByWord[token, default: []].insert(day)
                pagesByWord[token, default: []].append(page)
            }
            for token in contentWords(in: page.userInput) {
                uses[token, default: 0] += 1
            }
        }

        let candidates = uses
            .filter { word, count in
                count >= minimumWordUses && (daysByWord[word]?.count ?? 0) >= minimumRecurringDays
            }
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }

        guard let (word, count) = candidates.first else { return [] }
        let dayCount = daysByWord[word]?.count ?? 0
        let sourcePages = (pagesByWord[word] ?? []).sorted { $0.createdAt < $1.createdAt }

        return [
            Revelation(
                id: "\(Kind.recurringWord.rawValue):\(word)",
                kind: .recurringWord,
                title: "You kept saying \u{201C}\(word)\u{201D}",
                body: "\(count) times, across \(dayCount) of your \(writtenDays) written days. You never repeated it on purpose. A word that keeps coming back is usually standing in for something that hasn\u{2019}t been said straight yet.",
                evidence: evidence(from: sourcePages, limit: 3),
                strength: 55 + count * 3
            )
        ]
    }

    // MARK: Tone against the conditions it arrived in

    /// When the ink runs heavy or bright. Uses ContextWeave's lexicons, which
    /// deliberately exclude weather and hour words so a facet can never predict
    /// itself.
    private static func toneByDayPart(
        pages: [BookPage],
        writtenDays: Int,
        calendar: Calendar
    ) -> [Revelation] {
        let buckets = Dictionary(grouping: pages) { page -> String in
            // A page kept before context snapshots existed still has an hour on
            // it. Round-tripping through the snapshot keeps one definition of
            // where the day parts divide.
            page.context?.dayPart.nonEmpty
                ?? BookPageContextSnapshot(at: page.createdAt, calendar: calendar).dayPart
        }
        return toneClaim(
            buckets: buckets,
            kind: .hourOfHonesty,
            writtenDays: writtenDays,
            calendar: calendar
        ) { part, tone, hits, total in
            let register = tone == .heavy ? "heaviest" : "brightest"
            return (
                "Your ink runs \(register) \(dayPartPhrase(part))",
                "\(hits) of the \(total) pages you wrote \(dayPartPhrase(part)) lean that way. The hour you write in is doing more work than it gets credit for."
            )
        }
    }

    private static func toneByWeather(
        pages: [BookPage],
        writtenDays: Int,
        calendar: Calendar
    ) -> [Revelation] {
        var buckets: [String: [BookPage]] = [:]
        for page in pages {
            for tag in Set(page.context?.weatherTags ?? []) where !tag.isEmpty {
                buckets[tag, default: []].append(page)
            }
        }
        return toneClaim(
            buckets: buckets,
            kind: .weatherAndInk,
            writtenDays: writtenDays,
            calendar: calendar
        ) { weather, tone, hits, total in
            let register = tone == .heavy ? "heavier" : "brighter"
            return (
                "\(weather.capitalizedFirst) makes your writing \(register)",
                "You wrote \(total) times when it was \(weather). \(hits) of those ran \(register) than your usual. The weather gets into the ink whether or not it gets into the sentence."
            )
        }
    }

    /// Shared shape for "in condition X, your ink does Y". Requires a real
    /// sample in the facet *and* a strict majority, so a two-page bucket can
    /// never produce a finding.
    private static func toneClaim(
        buckets: [String: [BookPage]],
        kind: Kind,
        writtenDays: Int,
        calendar: Calendar,
        phrasing: (String, ContextWeave.InkTone, Int, Int) -> (String, String)
    ) -> [Revelation] {
        var best: (key: String, tone: ContextWeave.InkTone, hits: Int, total: Int, pages: [BookPage])?

        for (key, group) in buckets.sorted(by: { $0.key < $1.key }) {
            guard group.count >= minimumRecurringDays else { continue }
            let toned = group.compactMap { page -> (BookPage, ContextWeave.InkTone)? in
                guard let tone = ContextWeave.tone(of: page.userInput) else { return nil }
                return (page, tone)
            }
            guard !toned.isEmpty else { continue }
            for tone in [ContextWeave.InkTone.heavy, .bright] {
                let hits = toned.filter { $0.1 == tone }
                let share = Double(hits.count) / Double(group.count)
                guard share >= toneShareFloor, hits.count >= minimumRecurringDays else { continue }
                if best == nil || hits.count > best!.hits {
                    best = (key, tone, hits.count, group.count, hits.map(\.0))
                }
            }
        }

        guard let best else { return [] }
        let (title, body) = phrasing(best.key, best.tone, best.hits, best.total)
        return [
            Revelation(
                id: "\(kind.rawValue):\(best.key):\(best.tone.rawValue)",
                kind: kind,
                title: title,
                body: body,
                evidence: evidence(from: best.pages.sorted { $0.createdAt < $1.createdAt }, limit: 2),
                strength: 45 + best.hits * 4
            )
        ]
    }

    private static func dayPartPhrase(_ part: String) -> String {
        switch part.lowercased() {
        case "morning": return "in the morning"
        case "afternoon": return "in the afternoon"
        case "evening": return "in the evening"
        case "night", "late night": return "after dark"
        default: return "at that hour"
        }
    }

    // MARK: The same thought, twice

    /// Two passages far apart that say nearly the same thing. The reader has
    /// forgotten the first one by the time they write the second — which is
    /// precisely why it is worth showing them side by side.
    ///
    /// Lexical for now, and deliberately so: this must be instant, offline, and
    /// identical on every device. The folio's semantic lanes can sharpen it
    /// later without changing the shape of the finding.
    private static func echoes(pages: [BookPage], calendar: Calendar) -> [Revelation] {
        let candidates = pages.filter { contentWords(in: $0.userInput).count >= 5 }
        guard candidates.count >= 2 else { return [] }

        var best: (left: BookPage, right: BookPage, score: Double)?
        for (index, left) in candidates.enumerated() {
            let leftWords = Set(contentWords(in: left.userInput))
            for right in candidates.dropFirst(index + 1) {
                let gap = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: left.createdAt),
                    to: calendar.startOfDay(for: right.createdAt)
                ).day ?? 0
                guard gap >= echoMinimumDayGap else { continue }
                let rightWords = Set(contentWords(in: right.userInput))
                let union = leftWords.union(rightWords).count
                guard union > 0 else { continue }
                let score = Double(leftWords.intersection(rightWords).count) / Double(union)
                guard score >= echoSimilarityFloor else { continue }
                if best == nil || score > best!.score {
                    best = (left, right, score)
                }
            }
        }

        guard let best else { return [] }
        let gap = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: best.left.createdAt),
            to: calendar.startOfDay(for: best.right.createdAt)
        ).day ?? 0
        return [
            Revelation(
                id: "\(Kind.saidItTwice.rawValue):\(best.left.id):\(best.right.id)",
                kind: .saidItTwice,
                title: "You wrote this twice, \(gap) days apart",
                body: "Not a quotation \u{2014} you had forgotten the first one. Whatever this is, it came back on its own, which is the only kind of evidence I fully trust.",
                evidence: evidence(from: [best.left, best.right], limit: 2),
                strength: 70 + Int(best.score * 30)
            )
        ]
    }

    // MARK: Coming back

    /// The longest silence in the period, and what ended it. A gap is usually
    /// read as failure. It is more honestly read as a life that got loud.
    private static func returnAfterSilence(pages: [BookPage], calendar: Calendar) -> [Revelation] {
        let days = Set(pages.map { calendar.startOfDay(for: $0.createdAt) }).sorted()
        guard days.count >= 2 else { return [] }

        var widest: (gap: Int, resumed: Date)?
        for (previous, next) in zip(days, days.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous, to: next).day ?? 0
            guard gap >= silenceMinimumDays else { continue }
            if widest == nil || gap > widest!.gap {
                widest = (gap, next)
            }
        }

        guard let widest else { return [] }
        let returning = pages
            .filter { calendar.startOfDay(for: $0.createdAt) == widest.resumed }
            .sorted { $0.createdAt < $1.createdAt }
        guard !returning.isEmpty else { return [] }

        return [
            Revelation(
                id: "\(Kind.returnAfterSilence.rawValue):\(Int(widest.resumed.timeIntervalSince1970))",
                kind: .returnAfterSilence,
                title: "\(widest.gap) days of nothing, and then you came back",
                body: "I am not scoring the gap. Something was happening in it, and none of it was written down. What matters is the page you opened afterwards \u{2014} nobody does that by accident.",
                evidence: evidence(from: returning, limit: 2),
                strength: 50 + widest.gap * 2
            )
        ]
    }

    // MARK: Helpers

    static func contentWords(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && $0 != "\u{2019}" && $0 != "'" }
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\u{2019}'")) }
            .filter { $0.count >= 4 && !unremarkableWords.contains($0) }
    }

    private static func distinctDayCount(_ pages: [BookPage], calendar: Calendar) -> Int {
        Set(pages.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    private static func evidence(from pages: [BookPage], limit: Int) -> [Evidence] {
        pages.prefix(limit).map { page in
            Evidence(date: page.createdAt, excerpt: excerpt(from: page))
        }
    }

    private static func excerpt(from page: BookPage) -> String {
        let raw = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count > 160 else { return raw }
        let clipped = raw.prefix(160)
        guard let lastSpace = clipped.lastIndex(of: " ") else { return String(clipped) + "\u{2026}" }
        return String(clipped[clipped.startIndex..<lastSpace]) + "\u{2026}"
    }
}

private extension String {
    /// Upper-cases only the first character, leaving the rest of a sensory
    /// value or weather tag exactly as the extractor recorded it.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
