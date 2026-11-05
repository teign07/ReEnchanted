import Foundation
import NaturalLanguage

// MARK: - The reader's words, counted

/// Every word the reader has written: how often, when, beside which other
/// words, and the line it sat in. This is what a tapped word on a leaf is
/// looked up in.
///
/// Built off the main thread from the kept archive. The build never holds a
/// `BookPage` in a loop local, a tuple or a sort (see `passages(in:)`): Pages
/// are big, and on a 512 KB background stack that's how the 10-31 launch crash
/// happened.
struct WordsOfYours: Sendable {
    struct Sighting: Sendable, Equatable {
        let pageID: String
        let date: Date
        /// The sentence the word sat in, as the reader wrote it.
        let line: String
    }

    struct Entry: Sendable {
        let word: String
        var count = 0
        var first: Sighting
        /// The latest sightings, oldest first. Capped, so a word written every
        /// day for years costs the same as one written for a month.
        var recent: [Sighting] = []
        var hourCounts = [Int](repeating: 0, count: 24)
        var weekdayCounts = [Int](repeating: 0, count: 7)
        /// Distinct calendar days it turned up on, in order.
        var days: [Int] = []
        var companions: [String: Int] = [:]
        /// Every line it was written in, past the cap on `recent`.
        var lines = 0
    }

    static let recentLimit = 12

    private(set) var entries: [String: Entry] = [:]
    /// How many kept Pages this was built from, so a caller can tell when the
    /// archive has moved on.
    private(set) var pageCount = 0

    func entry(for word: String) -> Entry? {
        guard let key = Self.key(word) else { return nil }
        if let found = entries[key] { return found }
        // A plural the reader only ever wrote in the singular, or the reverse.
        for variant in Self.variants(of: key) {
            if let found = entries[variant] { return found }
        }
        return nil
    }

    // MARK: Building

    /// One kept Page's worth of the reader's own writing, without the Page.
    struct Passage: Sendable {
        let pageID: String
        let date: Date
        let texts: [String]
    }

    static func build(from days: [BookDay], calendar: Calendar = .current) -> WordsOfYours {
        build(passages: passages(in: days), calendar: calendar)
    }

    static func build(passages unsorted: [Passage], calendar: Calendar = .current) -> WordsOfYours {
        var lexicon = WordsOfYours()
        let passages = unsorted.sorted { $0.date < $1.date }
        lexicon.pageCount = passages.count
        for passage in passages {
            let parts = calendar.dateComponents([.hour, .weekday], from: passage.date)
            let hour = min(23, max(0, parts.hour ?? 12))
            let weekday = min(6, max(0, (parts.weekday ?? 1) - 1))
            let day = Int(floor(calendar.startOfDay(for: passage.date).timeIntervalSinceReferenceDate / 86_400))
            for text in passage.texts {
                for sentence in sentences(in: text) {
                    let keys = contentKeys(in: sentence)
                    guard !keys.isEmpty else { continue }
                    let sighting = Sighting(pageID: passage.pageID, date: passage.date, line: trimmedLine(sentence))
                    let companions = Set(keys)
                    for key in Set(keys) {
                        var entry = lexicon.entries[key] ?? Entry(word: key, first: sighting)
                        entry.count += keys.lazy.filter { $0 == key }.count
                        if entry.recent.last?.pageID != sighting.pageID || entry.recent.last?.line != sighting.line {
                            entry.recent.append(sighting)
                            entry.lines += 1
                            if entry.recent.count > recentLimit { entry.recent.removeFirst() }
                        }
                        entry.hourCounts[hour] += 1
                        entry.weekdayCounts[weekday] += 1
                        if entry.days.last != day { entry.days.append(day) }
                        for other in companions where other != key {
                            entry.companions[other, default: 0] += 1
                        }
                        lexicon.entries[key] = entry
                    }
                }
            }
        }
        // Only the closest company is ever read back.
        for key in lexicon.entries.keys {
            guard let companions = lexicon.entries[key]?.companions, companions.count > 8 else { continue }
            let kept = companions.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(8)
            lexicon.entries[key]?.companions = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
        return lexicon
    }

    /// The reader's writing on every kept Page, as small values. Pages are
    /// reached by index inside a helper that isn't inlined, so no Page ever
    /// sits in this loop's frame.
    static func passages(in days: [BookDay]) -> [Passage] {
        var passages: [Passage] = []
        for dayIndex in days.indices {
            for pageIndex in days[dayIndex].pages.indices {
                if let passage = passage(in: days, day: dayIndex, page: pageIndex) {
                    passages.append(passage)
                }
            }
        }
        return passages
    }

    @inline(never)
    private static func passage(in days: [BookDay], day: Int, page: Int) -> Passage? {
        let origin = days[day].pages[page].origin
        guard origin != .simulated else { return nil }
        let texts = days[day].pages[page].readerAuthoredTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !texts.isEmpty else { return nil }
        return Passage(pageID: days[day].pages[page].id, date: days[day].pages[page].createdAt, texts: texts)
    }

    // MARK: Words

    /// The dictionary form of a word as written: lower case, letters only.
    /// Nil for the little words that only hold a sentence together.
    static func key(_ raw: String) -> String? {
        var word = raw.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: CharacterSet.letters.inverted)
        if word.hasSuffix("'s") { word = String(word.dropLast(2)) }
        guard word.count >= 3, word.allSatisfy(\.isLetter), !stopWords.contains(word) else { return nil }
        return word
    }

    static func contentKeys(in sentence: String) -> [String] {
        sentence.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "\u{2019}" })
            .prefix(60)
            .compactMap { key(String($0)) }
    }

    static func variants(of key: String) -> [String] {
        var result: [String] = []
        if key.hasSuffix("ies"), key.count > 4 { result.append(String(key.dropLast(3)) + "y") }
        if key.hasSuffix("es"), key.count > 4 { result.append(String(key.dropLast(2))) }
        if key.hasSuffix("s"), !key.hasSuffix("ss"), key.count > 3 { result.append(String(key.dropLast())) }
        result.append(key + "s")
        if key.hasSuffix("y"), key.count > 3 { result.append(String(key.dropLast()) + "ies") }
        return result
    }

    static func sentences(in text: String) -> [String] {
        var found: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.bySentences, .localized]) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                found.append(sentence)
            }
        }
        return found.isEmpty ? [text] : found
    }

    private static func trimmedLine(_ sentence: String) -> String {
        let line = sentence.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard line.count > 160 else { return line }
        return String(line.prefix(157)).trimmingCharacters(in: .whitespaces) + "…"
    }

    static let stopWords: Set<String> = [
        "the", "and", "but", "for", "nor", "yet", "not", "you", "your", "yours", "she", "her", "hers",
        "him", "his", "its", "our", "ours", "they", "them", "their", "theirs", "who", "whom", "whose",
        "what", "which", "that", "this", "these", "those", "there", "here", "then", "than", "when",
        "where", "why", "how", "all", "any", "both", "each", "few", "more", "most", "other", "some",
        "such", "only", "own", "same", "too", "very", "can", "will", "just", "don't", "dont", "should",
        "now", "was", "were", "are", "been", "being", "have", "has", "had", "having", "does", "did",
        "doing", "would", "could", "might", "must", "shall", "may", "into", "onto", "from", "with",
        "about", "above", "below", "over", "under", "again", "once", "off", "out", "upon",
        "because", "until", "while", "after", "before", "during", "through", "between", "against",
        "also", "really", "still", "even", "much", "many", "lot", "lots", "got", "get", "gets", "getting",
        "i'm", "i've", "i'd", "i'll", "it's", "that's", "didn't", "wasn't", "isn't", "can't", "couldn't",
        "won't", "wouldn't", "doesn't", "haven't", "hadn't", "aren't", "weren't", "let", "lets", "let's",
        "like", "one", "two", "back", "way", "well", "went", "go", "goes", "going", "come",
        "came", "said", "say", "says", "make", "made", "thing", "things", "something", "anything",
        "nothing", "everything", "someone", "anyone", "everyone", "today", "yesterday", "tomorrow",
        "day", "days", "time", "times", "maybe", "kind", "sort", "bit", "ever", "never", "always",
        "who's", "what's", "there's", "he's", "she's", "we're", "they're", "you're", "we've", "they've",
        "myself", "yourself", "itself", "himself", "herself", "ourselves", "themselves", "whatever"
    ]
}

// MARK: - The Book's dictionary of you

/// A word looked up in the Book's own dictionary: not what the word means,
/// what it means *for this reader*, worked out from how they use it.
///
/// Said the Book's way: flat, plain, a child's notes about a word as if it were
/// a creature with habits. Nothing hedged. Every line is a count the Book can
/// stand behind.
struct BookDictionaryEntry: Equatable, Sendable {
    let headword: String
    /// "a thing", "a doing word", … Nil when the Book can't tell.
    let kind: String?
    /// The Book's notes on the word. Companion words come marked `*like this*`.
    let senses: [String]
    /// The first time the reader wrote it.
    let first: WordsOfYours.Sighting?
    /// Other times, newest first.
    let echoes: [WordsOfYours.Sighting]
    /// How many more times there were than `echoes` shows.
    let moreCount: Int
    let isAlive: Bool
}

enum BookDictionary {
    static let echoLimit = 6

    static func entry(
        for tapped: String,
        in lexicon: WordsOfYours,
        caughtAt: Date? = nil,
        excludingPage pageID: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BookDictionaryEntry {
        let headword = tapped.trimmingCharacters(in: CharacterSet.letters.inverted)
        let key = WordsOfYours.key(headword) ?? headword.lowercased()
        let alive = Bestiary.creature(for: key) != nil
        guard let found = lexicon.entry(for: headword) else {
            var senses = [pick(key, [
                "This one's new. You haven't written it on any Page I've kept yet.",
                "I haven't seen you write this anywhere else. Not yet.",
                "First sighting. I've nothing on it yet but this."
            ])]
            if alive { senses.append("It's alive. I can tell.") }
            if let caughtAt { senses.append(caughtLine(caughtAt, calendar: calendar)) }
            return BookDictionaryEntry(headword: headword, kind: nil, senses: senses,
                                       first: nil, echoes: [], moreCount: 0, isAlive: alive)
        }

        var senses: [String] = [countLine(found)]
        if let when = whenLine(found) { senses.append(when) }
        if let company = companyLine(found) { senses.append(company) }
        if let absence = absenceLine(found, now: now, calendar: calendar) { senses.append(absence) }
        if alive { senses.append("It's alive. I can tell.") }
        if let caughtAt { senses.append(caughtLine(caughtAt, calendar: calendar)) }

        // A line written word for word more than once is one echo, the
        // newest; it isn't five.
        var seenLines: Set<String> = [found.first.line.lowercased()]
        let others = found.recent.reversed().filter {
            $0.pageID != pageID && $0 != found.first && seenLines.insert($0.line.lowercased()).inserted
        }
        let echoes = Array(others.prefix(echoLimit))
        let shownFirst = found.first.pageID == pageID ? nil : found.first
        let here = found.recent.filter { $0.pageID == pageID }.count
        let accounted = echoes.count + (shownFirst == nil ? 0 : 1) + max(here, shownFirst == nil ? 1 : 0)
        return BookDictionaryEntry(
            headword: headword,
            kind: kind(of: found.word, in: found.first.line),
            senses: senses,
            first: shownFirst,
            echoes: echoes,
            moreCount: max(0, found.lines - accounted),
            isAlive: alive
        )
    }

    private static func countLine(_ entry: WordsOfYours.Entry) -> String {
        let n = entry.count
        switch n {
        case ...1:
            return pick(entry.word, [
                "You've only written it once. I'm keeping an eye on it.",
                "Just the once so far. It might be shy.",
                "Once. It hasn't decided if it lives here yet."
            ])
        case 2...4:
            return pick(entry.word, [
                "You've written it \(spelled(n)) times. It's starting to find its own way back.",
                "\(spelled(n).sentenceStart) times so far. I've started saving it a seat.",
                "You've written it \(spelled(n)) times. It isn't a stranger any more."
            ])
        default:
            return pick(entry.word, [
                "One of yours. You've written it \(spelled(n)) times.",
                "You've written it \(spelled(n)) times. It knows the way in by now.",
                "\(spelled(n).sentenceStart) times. It practically lives here."
            ])
        }
    }

    private static func whenLine(_ entry: WordsOfYours.Entry) -> String? {
        let total = entry.hourCounts.reduce(0, +)
        guard total >= 3 else { return nil }
        func share(_ hours: [Int]) -> Double {
            Double(hours.reduce(0) { $0 + entry.hourCounts[$1] }) / Double(total)
        }
        if share(Array(4..<8)) >= 0.6 { return "Nearly always before eight in the morning." }
        if share(Array(5..<12)) >= 0.6 { return "It comes out in the mornings." }
        if share(Array(12..<17)) >= 0.6 { return "Mostly an afternoon word." }
        if share(Array(17..<22)) >= 0.6 { return "It comes out in the evenings." }
        if share([22, 23, 0, 1, 2, 3]) >= 0.6 { return "It only comes out at night." }
        let days = entry.weekdayCounts.reduce(0, +)
        if days >= 4, let top = entry.weekdayCounts.indices.max(by: { entry.weekdayCounts[$0] < entry.weekdayCounts[$1] }),
           Double(entry.weekdayCounts[top]) / Double(days) >= 0.5 {
            let names = ["Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"]
            return "It likes \(names[top])."
        }
        return nil
    }

    private static func companyLine(_ entry: WordsOfYours.Entry) -> String? {
        let close = entry.companions
            .filter { $0.value >= 2 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(2)
            .map(\.key)
        switch close.count {
        case 2: return "It goes about with *\(close[0])* and *\(close[1])*."
        case 1: return "It's usually somewhere near *\(close[0])*."
        default: return nil
        }
    }

    private static func absenceLine(_ entry: WordsOfYours.Entry, now: Date, calendar: Calendar) -> String? {
        let today = Int(floor(calendar.startOfDay(for: now).timeIntervalSinceReferenceDate / 86_400))
        if let last = entry.days.last, today - last >= 45 {
            let month = DateFormatter()
            month.dateFormat = "MMMM"
            let lastDate = entry.recent.last?.date ?? entry.first.date
            return "You haven't written it since \(month.string(from: lastDate)). I miss it a bit."
        }
        var longest = 0
        for (earlier, later) in zip(entry.days, entry.days.dropFirst()) { longest = max(longest, later - earlier) }
        guard longest >= 21 else { return nil }
        return "It went missing for \(spelled(longest / 7)) weeks once, then came back."
    }

    private static func caughtLine(_ caughtAt: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(caughtAt) { return "You caught it today. It's pressed in here now." }
        let date = DateFormatter()
        date.setLocalizedDateFormatFromTemplate("d MMMM")
        return "You caught it on \(date.string(from: caughtAt)). It's pressed in here now."
    }

    /// What sort of word it is, said the way a child sorts things.
    static func kind(of word: String, in line: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = line
        var found: NLTag?
        tagger.enumerateTags(in: line.startIndex..<line.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            guard WordsOfYours.key(String(line[range])) == word else { return true }
            found = tag
            return false
        }
        switch found {
        case .noun?: return "a thing"
        case .verb?: return "a doing word"
        case .adjective?: return "a what-it's-like word"
        case .adverb?: return "a how-you-did-it word"
        default: return nil
        }
    }

    static func spelled(_ n: Int) -> String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                     "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
                     "eighteen", "nineteen", "twenty"]
        return words.indices.contains(n) ? words[n] : "\(n)"
    }

    private static func pick(_ seed: String, _ lines: [String]) -> String {
        lines[abs(seed.stableHash) % lines.count]
    }
}

private extension String {
    var sentenceStart: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Loose words

/// Now and then one of the reader's words gets loose on a leaf for the day.
/// The Pixie keeps landing on it; tap it and it bolts, and the reader has a
/// moment to catch it.
///
/// Deterministic for the day, so the same word is loose every time the leaf
/// comes round, and a different one tomorrow. Words that are alive (anything
/// the Bestiary would file) get loose more easily. Of course they do.
enum LooseWords {
    struct Pick: Equatable {
        let key: String
        let range: NSRange
    }

    static func pick(in text: String, leafKey: String, dayID: String) -> Pick? {
        let seed = abs("loose|\(dayID)|\(leafKey)|\(text.prefix(48))".stableHash)
        var living: [Pick] = []
        var ordinary: [Pick] = []
        var seen: Set<String> = []
        let ns = text as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { word, range, _, _ in
            guard let word, let key = WordsOfYours.key(word), key.count >= 4, seen.insert(key).inserted else { return }
            let pick = Pick(key: key, range: range)
            if Bestiary.creature(for: key) != nil { living.append(pick) } else if key.count >= 5 { ordinary.append(pick) }
        }
        if !living.isEmpty, seed % 3 == 0 { return living[(seed / 3) % living.count] }
        if !ordinary.isEmpty, seed % 5 == 1 { return ordinary[(seed / 5) % ordinary.count] }
        return nil
    }
}
