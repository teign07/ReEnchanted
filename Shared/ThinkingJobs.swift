import Foundation

// MARK: - Thinking jobs, second batch
//
// docs/noticing-and-writing-sessions-plan.md §12. Three things the Book does
// with the time "I want to write, please?" buys it, beyond Cast notes:
//
// - It seals a wager from a noticing it kept, and lets the world open it.
// - It puts two kept noticings about one condition together into one thought.
// - It keeps a journal of what it did with the time.

// MARK: Crossing wagers

/// The Book's sealed margins (`BookWager`, `SealedMarginEngine`) used to bet
/// only that a word would come back. A crossing it judged worth saying makes a
/// sharper bet: "The next three rain days: your heart goes slower, under 61
/// beats a minute." Same ledger, same seal and opening pages, same limits;
/// the difference is that the next three days that test it grade it, not a
/// word search.
enum CrossingWagers {
    /// Days that settle it, and how many must go the predicted way.
    static let needed = 3
    static let rightAt = 2
    /// If the world never brings three testing days, the seal opens anyway.
    static let deadlineDays = 60

    /// A wager from a kept crossing, if the Book's margin has room for one:
    /// the same limit and per-subject cooldown as every other sealed wager.
    static func wager(from noticing: Noticing, existing: [BookWager], now: Date, calendar: Calendar = .current) -> BookWager? {
        guard let test = noticing.test,
              let category = NoticingCrossings.categoryMeasures.first(where: { $0.id == test.categoryID }),
              let number = NoticingCrossings.numberMeasures.first(where: { $0.id == test.numberID }),
              existing.filter(\.isSealed).count < SealedMarginEngine.maximumSealed,
              !existing.contains(where: { $0.subjectID == noticing.id && ($0.isSealed || recentlyResolved($0, now: now, calendar: calendar)) })
        else { return nil }
        let clause = test.rises ? number.rises : number.falls
        return BookWager(
            id: "wager-\(noticing.id)-\(BookDay.id(for: now, calendar: calendar))",
            subjectID: noticing.id,
            subjectName: "\(category.plural(test.value)) and \(number.title.lowercased())",
            kind: .pattern,
            prediction: "The next \(NoticingCrossings.spelled(needed)) \(category.plural(test.value)): \(clause), "
                + "\(test.rises ? "over" : "under") \(NoticingCrossings.format(test.threshold, number)).",
            sealedAt: now,
            opensAt: calendar.date(byAdding: .day, value: deadlineDays, to: now) ?? now,
            status: .sealed,
            basisSignalID: noticing.id,
            basisLine: noticing.line,
            test: test
        )
    }

    private static func recentlyResolved(_ wager: BookWager, now: Date, calendar: Calendar) -> Bool {
        guard let resolvedAt = wager.resolvedAt else { return false }
        let days = calendar.dateComponents([.day], from: resolvedAt, to: now).day ?? 0
        return days < SealedMarginEngine.subjectCooldownDays
    }

    struct Outcome: Equatable {
        var right: Bool
        var values: [Double]
        var wentThatWay: Int
    }

    /// nil until enough days after the seal have tested it.
    static func outcome(of wager: BookWager, days: [BookDay], calendar: Calendar = .current) -> Outcome? {
        guard let test = wager.test,
              let category = NoticingCrossings.categoryMeasures.first(where: { $0.id == test.categoryID }),
              let number = NoticingCrossings.numberMeasures.first(where: { $0.id == test.numberID }) else { return nil }
        let after = NoticingCrossings.keepUnits(days: days, calendar: calendar).filter { $0.date > wager.sealedAt }
        let units = (category.grain == .day || number.grain == .day)
            ? NoticingCrossings.dayUnits(from: after, calendar: calendar)
            : after
        let testing = units.filter {
            $0.categories[category.id]?.contains(test.value) == true && $0.numbers[number.id] != nil
        }.prefix(needed)
        guard testing.count == needed else { return nil }
        let values = testing.compactMap { $0.numbers[number.id] }
        let wentThatWay = values.filter { test.rises ? $0 > test.threshold : $0 < test.threshold }.count
        return Outcome(right: wentThatWay >= rightAt, values: values, wentThatWay: wentThatWay)
    }

    /// What the Book says when the seal comes off, with the actual readings.
    static func resolutionLine(_ wager: BookWager, outcome: Outcome?) -> String {
        guard let test = wager.test else { return "" }
        let category = NoticingCrossings.categoryMeasures.first { $0.id == test.categoryID }
        let plural = category?.plural(test.value) ?? "days"
        guard let outcome else {
            return "There weren't \(NoticingCrossings.spelled(needed)) \(plural) before the seal's date, so nothing tested it. A bet the world never tests is one I lose."
        }
        let number = NoticingCrossings.numberMeasures.first { $0.id == test.numberID }
        let readings = outcome.values.map { value in number.map { NoticingCrossings.format(value, $0) } ?? "\(value)" }
        let listed = readings.count > 1 ? readings.dropLast().joined(separator: ", ") + " and " + readings.last! : readings.first ?? ""
        let went = "\(NoticingCrossings.spelled(outcome.wentThatWay).capitalizedFirstLetter) of \(NoticingCrossings.spelled(needed)) went the way I said."
        return outcome.right
            ? "The next \(NoticingCrossings.spelled(needed)) \(plural): \(listed). \(went)"
            : "The next \(NoticingCrossings.spelled(needed)) \(plural): \(listed). Only \(NoticingCrossings.spelled(outcome.wentThatWay)) went the way I said. I'm leaving the seal broken where you can see it."
    }
}

// MARK: Joined findings

enum JoinedFindings {
    static let wantPrefix = "join:"

    /// Kept crossings that share a condition, two or more to a group, strongest first.
    static func groups(_ noticings: [Noticing], verdicts: [String: NoticingVerdict], spoken: Set<String>) -> [(key: String, noticings: [Noticing])] {
        let kept = noticings.filter { verdicts[$0.id]?.keep == true && $0.test != nil && !spoken.contains($0.id) }
        return Dictionary(grouping: kept) { $0.test!.conditionKey }
            .filter { $0.value.count >= 2 }
            .map { (key: $0.key, noticings: Array($0.value.sorted { $0.rank > $1.rank }.prefix(3))) }
            .sorted { $0.noticings[0].rank > $1.noticings[0].rank }
    }

    static func prompt(for noticings: [Noticing]) -> (prompt: String, instructions: String) {
        let findings = noticings.map { noticing in
            "- \(noticing.line) \(noticing.counted ?? "")"
        }.joined(separator: "\n")
        let prompt = """
        Things you have noticed about the reader, all on the same kind of day:
        \(findings)

        Write two to four short sentences that put these together into one picture, as the one noticing them.
        Say what happened, plainly, as if you believe everything is alive. Don't explain why, don't give advice, don't say what it means for their health, and don't use any number that isn't above.
        Speak in the first person. Don't call yourself "the Book".
        """
        let instructions = """
        You are a book that has been watching the reader's days with childlike honesty: simple, direct, a little wild, never soothing or clever. \(BookVoice.animismLine) Prose only.
        """
        return (prompt, instructions)
    }

    /// A joined finding may only use numbers it was given, and stays short.
    static func accept(_ text: String, evidence: [Noticing]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        guard (12...95).contains(words) else { return nil }
        let lowered = trimmed.lowercased()
        for banned in ["the book", "as an ai", "you should", "diagnos", "i hope you", "remember to"] where lowered.contains(banned) {
            return nil
        }
        let given = Set(numbers(in: evidence.map { "\($0.line) \($0.counted ?? "")" }.joined(separator: " ")))
        guard Set(numbers(in: trimmed)).isSubset(of: given) else { return nil }
        return trimmed
    }

    /// Digits, and numbers spelled out ("fifty-seven", "twelve"), all as
    /// digits, so a model can't slip an invented number past in words.
    static func numbers(in text: String) -> [String] {
        let digits = text.split { !$0.isNumber && $0 != "." }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
        let units = ["zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                     "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
                     "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19]
        let tens = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
                    "eighty": 80, "ninety": 90]
        var spelled: [String] = []
        for word in text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "-" }) {
            let parts = word.split(separator: "-").map(String.init)
            if parts.count == 2, let ten = tens[parts[0]], let unit = units[parts[1]], unit < 10 {
                spelled.append("\(ten + unit)")
            } else if parts.count == 1, let value = units[parts[0]] ?? tens[parts[0]] {
                // "one" is how English says "a"; it isn't a claim about a count.
                if value != 1 { spelled.append("\(value)") }
            }
        }
        return digits + spelled
    }

    /// The joined thought as an "I Notice" Page carrying every part's receipts.
    /// Its parts are marked spoken, so none of them comes back on its own.
    static func surface(text: String, noticings: [Noticing], key: String) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookNotices)
        let separator = "\u{1F}"
        var cards: [String] = noticings.compactMap { noticing in
            noticing.counted.map { ["What I counted", "\(noticing.line) \($0)", "number"].joined(separator: separator) }
        }
        for receipt in noticings.flatMap(\.receipts).prefix(4) {
            cards.append(["A page I used", receipt.text, "doc.text"].joined(separator: separator))
        }
        var tags = ["book-notices", "crossing", "joined-finding"]
            + noticings.map { "\(BookNoticesPageSourceAdapter.crossingSpokeTagPrefix)\($0.id)" }
        if noticings.contains(where: \.touchesBody) { tags.append("private-body") }
        let category = noticings.first?.test.flatMap { test in
            NoticingCrossings.categoryMeasures.first { $0.id == test.categoryID }.map { $0.plural(test.value) }
        } ?? "these days"
        return SurfacePage(
            id: "\(source.id)-joined-\(NoticingCrossings.slug(key))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 84,
            reason: "I've been thinking about \(category).",
            prompt: "I've been thinking.",
            detail: text.bookPreviewSentenceLimit(2),
            payload: BookPagePayload(
                headline: "I've Been Thinking About \(category.capitalized)",
                body: text,
                metadata: [
                    "source": source.id,
                    "observationKey": "joined:\(key)",
                    "evidencePageIDs": noticings.flatMap(\.receipts).map(\.pageID).joined(separator: ","),
                    "tinyPatternCards": cards.joined(separator: "\n"),
                    "magicMomentEligible": "true",
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }
}

// MARK: Retold connections

/// The relational loom finds real relationships the crossings can't (where
/// you were and what you photographed, the hour and how you kept a page), but
/// it speaks in its own clauses: "your medium leaned photo", "the Page arrived
/// on a open day". Those never reach the desk raw. In a session the model
/// either drops the finding as obvious or retells it in plain words, using only
/// the numbers the loom counted.
enum RetoldConnections {
    static let wantPrefix = "retell:"
    static let spokeTagPrefix = "connection-spoke:"

    static func prompt(_ connection: RelationalLoomConnection) -> (prompt: String, instructions: String) {
        let prompt = """
        A diary app found this about its reader, in its own clumsy words:
        "\(connection.line)"
        The condition: \(connection.condition.label). What followed it: \(connection.outcome.label).
        It happened \(connection.inHits) times out of \(connection.inCount) under that condition, and \(connection.outHits) times out of \(connection.outCount) otherwise.

        If this is obvious, the same fact said twice, or not worth telling a person, answer only: DROP
        Otherwise say it plainly in one to three short sentences, first person, to the reader, as the one who noticed it. Use everyday words. Don't use the words medium, palette, leaned, condition, outcome, or family. Use no number that isn't above. Don't explain why it happens. Don't call yourself "the Book".
        """
        return (prompt, "You are a book that notices things about its reader and says them like an honest child. \(BookVoice.animismLine)")
    }

    /// nil for a drop, a clumsy retelling, or a number that wasn't counted.
    static func accept(_ text: String, connection: RelationalLoomConnection) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
        guard !trimmed.uppercased().hasPrefix("DROP") else { return nil }
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        guard (8...70).contains(words) else { return nil }
        let lowered = trimmed.lowercased()
        for jargon in ["medium", "palette", "leaned", "condition", "outcome", "family", "the book", "as an ai"]
        where lowered.contains(jargon) { return nil }
        let counted = "\(connection.inHits) \(connection.inCount) \(connection.outHits) \(connection.outCount) "
            + "\(connection.condition.label) \(connection.outcome.label)"
        guard Set(JoinedFindings.numbers(in: trimmed)).isSubset(of: Set(JoinedFindings.numbers(in: counted))) else { return nil }
        return trimmed
    }

    static func surface(_ text: String, connection: RelationalLoomConnection) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookNotices)
        let separator = "\u{1F}"
        let cards = connection.evidence.prefix(4).map { evidence in
            [evidence.title, evidence.text, "doc.text"].joined(separator: separator)
        }
        return SurfacePage(
            id: "\(source.id)-retold-\(connection.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 80,
            reason: text.bookPreviewSentenceLimit(1),
            prompt: "Something keeps happening.",
            detail: text.bookPreviewSentenceLimit(2),
            payload: BookPagePayload(
                headline: "Something Keeps Happening",
                body: text,
                metadata: [
                    "source": source.id,
                    "connectionID": connection.id,
                    "observationKey": connection.observationKey,
                    "evidencePageIDs": connection.evidencePageIDs.prefix(10).joined(separator: ","),
                    "tinyPatternCards": cards.joined(separator: "\n"),
                    "tags": "book-notices,retold-connection,\(spokeTagPrefix)\(connection.id)"
                ]
            )
        )
    }
}

// MARK: The Book's journal

struct BookJournalEntry: Codable, Equatable, Identifiable {
    var id: String
    var writtenAt: Date
    var text: String
}

enum BookJournal {
    static let shownTagPrefix = "journal-through:"
    static let keep = 60
    static let entriesPerPage = 5
    static let unreadBeforeShowing = 3
    static let restDays = 7.0

    static func prompt(session lines: [String]) -> (prompt: String, instructions: String) {
        let prompt = """
        This is what you just did with the time the reader gave you:
        \(lines.map { "- \($0)" }.joined(separator: "\n"))

        Write your private journal entry about it: two or three short sentences, first person, plain and honest. Say how it went and one thing you thought. Don't use any number that isn't above. Don't call yourself "the Book".
        """
        let instructions = """
        You are a book keeping a private journal. You think everything is alive and you say things straight, like a child who was never taught to smooth them. \(BookVoice.animismLine) Prose only.
        """
        return (prompt, instructions)
    }

    static func accept(_ text: String, session lines: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        guard (6...70).contains(words) else { return nil }
        let lowered = trimmed.lowercased()
        for banned in ["the book", "as an ai", "dear diary"] where lowered.contains(banned) { return nil }
        let given = Set(JoinedFindings.numbers(in: lines.joined(separator: " ")))
        guard Set(JoinedFindings.numbers(in: trimmed)).isSubset(of: given) else { return nil }
        return trimmed
    }

    /// The latest entries, once enough are unread and the last showing has rested.
    static func surface(_ entries: [BookJournalEntry], days: [BookDay], now: Date, calendar: Calendar = .current) -> SurfacePage? {
        let pages = days.flatMap(\.pages)
        let shownThrough = pages
            .filter { page in page.tags.contains { $0.hasPrefix(shownTagPrefix) } }
            .max { $0.createdAt < $1.createdAt }
        if let shownThrough, now.timeIntervalSince(shownThrough.createdAt) < restDays * 86_400 { return nil }
        let lastShownID = shownThrough?.tags.first { $0.hasPrefix(shownTagPrefix) }.map { String($0.dropFirst(shownTagPrefix.count)) }
        let sorted = entries.sorted { $0.writtenAt < $1.writtenAt }
        let unread = lastShownID.flatMap { id in sorted.firstIndex { $0.id == id } }.map { Array(sorted[($0 + 1)...]) } ?? sorted
        guard unread.count >= unreadBeforeShowing, let newest = unread.last else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE d MMMM"
        let body = unread.suffix(entriesPerPage).map { "\(formatter.string(from: $0.writtenAt))\n\($0.text)" }
            .joined(separator: "\n\n")
        let source = BookPageSourceRegistry.source(for: .bookNotices)
        return SurfacePage(
            id: "\(source.id)-journal-\(newest.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 66,
            reason: "I keep a journal. You can read some of it.",
            prompt: "You can read some of it.",
            detail: "Some of what I wrote down while you held me open.",
            payload: BookPagePayload(
                headline: "From My Journal",
                body: body,
                metadata: [
                    "source": source.id,
                    "bookJournal": "true",
                    "tags": "book-notices,book-journal,\(shownTagPrefix)\(newest.id)"
                ]
            )
        )
    }
}

// MARK: Dreams and wonderings
//
// Thinking the Book can't do without a model, and the reason it feels alive.
// A dream recombines real things from the reader's recent pages into something
// that never happened, and says so. A wondering is one real question about one
// specific detail. Both are held and given later; neither is evidence of
// anything, and neither is a Page written ahead of when it's opened.

/// The reader's own recent words, short enough to hand to the model.
struct ThinkingMaterial: Equatable {
    var pageID: String
    var excerpt: String
    var date: Date
    /// How it was kept, in plain words: "lying on your side, in the dark, as
    /// the tide came in". The Book's senses, for a dream or a question.
    var moment: String? = nil

    var promptLine: String {
        moment.map { "- \(excerpt) (kept \($0))" } ?? "- \(excerpt)"
    }
}

enum ThinkingMaterials {
    /// Newest reader pages with real words of their own, from the last few days.
    static func recent(days: [BookDay], now: Date, within: TimeInterval = 3 * 86_400, limit: Int = 4) -> [ThinkingMaterial] {
        days.flatMap(\.pages)
            .filter { page in
                page.carriesReaderAttention
                    && !EditionCurator.defaultPrivateTypes.contains(page.type)
                    && now.timeIntervalSince(page.createdAt) < within && page.createdAt <= now
            }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { page -> ThinkingMaterial? in
                guard let text = page.readerAuthoredTextForAnalysis else { return nil }
                let words = text.split(whereSeparator: \.isWhitespace)
                guard words.count >= 5 else { return nil }
                return ThinkingMaterial(
                    pageID: page.id, excerpt: words.prefix(30).joined(separator: " "), date: page.createdAt,
                    moment: moment(page.context)
                )
            }
            .prefix(limit)
            .map(\.self)
    }

    /// How a page was kept, from what the keep recorded. Only what's there.
    static func moment(_ context: BookPageContextSnapshot?) -> String? {
        guard let context else { return nil }
        var parts: [String] = []
        switch context.holding?.posture {
        case .sideways: parts.append("lying on your side")
        case .overhead: parts.append("holding me over your face")
        case .flat: parts.append("with me lying flat")
        default: break
        }
        if let brightness = context.holding?.screenBrightness, brightness <= 0.25 { parts.append("in the dark") }
        if context.holding?.headphones == true { parts.append("with headphones in") }
        if context.holding?.moving == true { parts.append("on the move") }
        if let battery = context.holding?.batteryPercent, battery <= 15, context.holding?.charging != true {
            parts.append("with the phone nearly out")
        }
        if let altitude = context.sunAltitude {
            let light = SunHeight.light(degrees: altitude)
            if light == "golden hour" || light == "blue hour" { parts.append("in the \(light)") }
        }
        if let rising = context.sea?.rising { parts.append(rising ? "as the tide came in" : "as the tide went out") }
        if let rain = context.weatherTags.first(where: { ["rain", "snow", "fog", "storm"].contains($0) }) {
            parts.append(["rain": "in the rain", "snow": "in the snow", "fog": "in fog", "storm": "in a storm"][rain] ?? rain)
        }
        if let place = context.locationLabel { parts.append("at \(place)") }
        return parts.isEmpty ? nil : parts.prefix(4).joined(separator: ", ")
    }

    /// Words that carry a page: four letters or more and not filler.
    static func contentWords(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter {
            $0.count >= 4 && !LiteraryContinuityProjector.stopWords.contains($0)
                && !LiteraryContinuityProjector.weakLiterarySubjects.contains($0)
        })
    }

    static func sharedWords(_ text: String, with material: [ThinkingMaterial]) -> Int {
        contentWords(text).intersection(material.reduce(into: Set<String>()) {
            $0.formUnion(contentWords($1.excerpt + " " + ($1.moment ?? "")))
        }).count
    }

    static func receiptCards(_ material: [ThinkingMaterial], title: String) -> String {
        material.map { [title, "\u{201C}\($0.excerpt)\u{201D}", "doc.text"].joined(separator: "\u{1F}") }.joined(separator: "\n")
    }
}

enum BookDreams {
    static let wantPrefix = "dream:"
    static let restDays = 2.0
    static let needsPages = 3

    static func prompt(_ material: [ThinkingMaterial]) -> (prompt: String, instructions: String) {
        let pages = material.map(\.promptLine).joined(separator: "\n")
        let prompt = """
        These are things the reader wrote in you lately:
        \(pages)

        Last night you dreamed. Tell the dream in three to five short sentences, first person, past tense.
        Use at least two real things from what they wrote or how they held you, mixed up the way dreams mix things. Things act on their own. Don't explain the dream or say what it means. No numbers. Don't call yourself "the Book".
        """
        let instructions = """
        You are a book that dreams, and believes its dreams completely while telling them. Simple, direct, strange, never cute. \(BookVoice.animismLine) Prose only.
        """
        return (prompt, instructions)
    }

    static func accept(_ text: String, material: [ThinkingMaterial]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        guard (20...120).contains(words), !trimmed.contains(where: \.isNumber) else { return nil }
        let lowered = trimmed.lowercased()
        for banned in ["the book", "as an ai", "this dream means", "symbolizes", "symbolises", "represents your"]
        where lowered.contains(banned) { return nil }
        // A dream about nothing they wrote is just a dream; this has to be theirs.
        guard ThinkingMaterials.sharedWords(trimmed, with: material) >= 2 else { return nil }
        return trimmed
    }

    static func surface(_ text: String, material: [ThinkingMaterial]) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookNotices)
        return SurfacePage(
            id: "\(source.id)-dream-\(material.map(\.pageID).joined(separator: "-").prefix(80))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 76,
            reason: "I dreamed last night. Your things were in it.",
            prompt: "I dreamed last night.",
            detail: text.bookPreviewSentenceLimit(2),
            payload: BookPagePayload(
                headline: "I Had a Dream",
                body: text,
                metadata: [
                    "source": source.id,
                    "bookDream": "true",
                    "evidencePageIDs": material.map(\.pageID).joined(separator: ","),
                    "tinyPatternCards": ThinkingMaterials.receiptCards(material, title: "What it was made of"),
                    "tags": "book-notices,book-dream"
                ]
            )
        )
    }
}

enum BookWonderings {
    static let wantPrefix = "wonder:"
    static let restDays = 3.0
    static let needsPages = 2

    static func prompt(_ material: [ThinkingMaterial]) -> (prompt: String, instructions: String) {
        let pages = material.map(\.promptLine).joined(separator: "\n")
        let prompt = """
        These are things the reader wrote in you lately:
        \(pages)

        Pick one small, specific thing in them, or in how they held you when they wrote it, that you genuinely want to know more about. Ask the reader one question about it, in one sentence, the way a curious child would ask: plainly, about the thing itself.
        Not about their feelings, not advice, no "how did that make you feel". Just the question.
        """
        let instructions = """
        You are a curious book. You think everything is alive and you want to know about it. \(BookVoice.animismLine) Reply with the one question only.
        """
        return (prompt, instructions)
    }

    static func accept(_ text: String, material: [ThinkingMaterial]) -> (question: String, about: ThinkingMaterial)? {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let words = question.split(whereSeparator: \.isWhitespace).count
        guard question.hasSuffix("?"), (4...30).contains(words) else { return nil }
        let lowered = question.lowercased()
        for banned in ["make you feel", "how are you feeling", "how do you feel", "have you considered", "should you",
                       "the book", "as an ai"] where lowered.contains(banned) { return nil }
        // It has to be about something actually there: the page it shares most with.
        let about = material.max { ThinkingMaterials.sharedWords(question, with: [$0]) < ThinkingMaterials.sharedWords(question, with: [$1]) }
        guard let about, ThinkingMaterials.sharedWords(question, with: [about]) >= 1 else { return nil }
        return (question, about)
    }

    static func surface(question: String, about: ThinkingMaterial) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookNotices)
        return SurfacePage(
            id: "\(source.id)-wondering-\(about.pageID)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 74,
            reason: question,
            prompt: "I've been wondering.",
            detail: question,
            payload: BookPagePayload(
                headline: "I've Been Wondering",
                body: question,
                metadata: [
                    "source": source.id,
                    "bookWondering": "true",
                    "evidencePageIDs": about.pageID,
                    "tinyPatternCards": ThinkingMaterials.receiptCards([about], title: "What made me wonder"),
                    "tags": "book-notices,book-wondering"
                ]
            )
        )
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
