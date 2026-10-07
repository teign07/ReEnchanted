import Foundation

/// How a week is curated before it is set in type.
///
/// Issue 6 (Sep 23-29) showed what a weekly is without this: nine pages kept and
/// ten printed, built around one sentence that came back seven times; the
/// braid's `Tags:` header printed as if it were story; the whole Bleed dumped and
/// cut at "— TODAY AT THE ACADEMY —…"; a page called "Amanda" that was only the
/// word; excerpts that stopped mid-sentence; a refrain made of page-type names
/// ("photograph, reader"); and a week's page that was a weather report.
///
/// Everything here is pure and deterministic, so the same week always sets the
/// same way and every rule is tested without drawing a pixel.
enum WeeklyCuration {
    // MARK: - Excerpts

    /// Clamps to whole sentences. The cut falls between sentences whenever one
    /// fits; only a single sentence longer than the limit is cut inside itself,
    /// at a clause mark if there is one, with an ellipsis. Line breaks the reader
    /// (or the Tale) chose are kept.
    static func sentenceClamp(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }

        var units: [(text: String, joiner: String)] = []
        for paragraph in trimmed.components(separatedBy: "\n") {
            let line = paragraph.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            for (index, sentence) in WonderBraid.sentences(line).enumerated() {
                units.append((sentence, units.isEmpty ? "" : (index == 0 ? "\n" : " ")))
            }
        }
        var kept = ""
        for unit in units {
            let next = kept + unit.joiner + unit.text
            if next.count > limit { break }
            kept = next
        }
        if !kept.isEmpty { return kept }

        // One sentence is longer than the limit. Say as much of it as reads whole.
        guard let first = units.first?.text else { return String(trimmed.prefix(limit)) }
        let window = String(first.prefix(limit))
        for mark in ["; ", ", ", " \u{2014} ", ": "] {
            if let range = window.range(of: mark, options: .backwards),
               window.distance(from: window.startIndex, to: range.lowerBound) >= limit / 2 {
                return String(window[..<range.lowerBound]) + "\u{2026}"
            }
        }
        let atWord = window.lastIndex(of: " ").map { String(window[..<$0]) } ?? window
        return atWord.trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }

    /// The Page's text with the system's own furniture taken out: the braid's
    /// `Tags:` header is real metadata, not something the reader or the Book said.
    static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix(BraidPageDetails.headerPrefix) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - The refrain

    /// Words that name what a page IS, not what it is about. "Photograph again.
    /// The week insists." was a refrain made of the app's own labels.
    private static let metaWords: Set<String> = [
        "photograph", "photographs", "photo", "photos", "picture", "pictures", "image", "images", "reader", "readers",
        "page", "pages", "kept", "note", "notes", "voice", "audio", "recording", "caption", "entry", "entries",
        "journal", "sentence", "sentences", "souvenir", "today", "tonight", "weather", "moon", "tags", "time",
        "location", "fuel", "inner", "book", "week", "issue", "diary", "scrapbook", "quote", "quotes", "line", "lines",
        "word", "words", "thing", "things", "something", "morning", "evening", "night", "right", "still", "even"
    ]

    /// Whether a word names what a page IS (photograph, reader, page...), not what it is about.
    static func isMetaWord(_ word: String) -> Bool { metaWords.contains(word.lowercased()) }

    /// Words that came back on at least two different pages the reader wrote.
    /// A refrain is a word that returned; once, or twice on one page, is not.
    static func refrain(from pages: [BookPage], limit: Int = 3, minPages: Int = 2, seed: String = "") -> [String] {
        var pagesHolding: [String: Set<String>] = [:]
        var names = Set<String>()
        for page in pages where page.carriesReaderAttention && page.type != .bookOfYou && page.type != .theBleed {
            guard let written = page.readerAuthoredTextForAnalysis, !written.isEmpty else { continue }
            let words = LiteraryContinuityProjector.meaningfulWords(in: written)
                .map { $0.lowercased() }
                .filter { $0.count >= 4 && !metaWords.contains($0) }
            for word in Set(words) { pagesHolding[word, default: []].insert(page.id) }
            names.formUnion(properNames(in: written))
        }
        return pagesHolding
            .filter { $0.value.count >= minPages }
            .sorted { left, right in
                guard left.value.count == right.value.count else { return left.value.count > right.value.count }
                // Alphabetical keeps a refrain stable; a seed spreads the ties for a longer list.
                if seed.isEmpty { return left.key < right.key }
                let l = HandbookBuilder.stableHash(seed + left.key), r = HandbookBuilder.stableHash(seed + right.key)
                return l == r ? left.key < right.key : l < r
            }
            .prefix(limit)
            .map { names.contains($0.key) ? $0.key.prefix(1).uppercased() + $0.key.dropFirst() : $0.key }
    }

    /// Words written with a capital in the middle of a sentence: a name, kept as one.
    private static func properNames(in text: String) -> Set<String> {
        var found = Set<String>()
        let characters = Array(text)
        var index = 0
        var previousWordEndedSentence = true
        while index < characters.count {
            guard characters[index].isLetter else {
                if ".!?\n".contains(characters[index]) { previousWordEndedSentence = true }
                index += 1
                continue
            }
            var end = index
            while end < characters.count, characters[end].isLetter || characters[end] == "'" { end += 1 }
            let word = String(characters[index..<end])
            if !previousWordEndedSentence, word.first?.isUppercase == true, word.count >= 3 { found.insert(word.lowercased()) }
            previousWordEndedSentence = false
            index = end
        }
        return found
    }

    // MARK: - The Labyrinth, this week

    struct LabyrinthNote: Equatable {
        var date: Date
        var title: String
        var text: String
    }

    /// What the world was doing on the nights the Book braided: the authored beat
    /// each braid actually carried (a pulse of the month's Tale, a Cast errand,
    /// the Academy's own business), read back from the braid's receipts rather
    /// than guessed, so it is exactly what the reader's nights were told.
    static func labyrinthNotes(from pages: [BookPage], limit: Int = 7) -> [LabyrinthNote] {
        var seen = Set<String>()
        var notes: [LabyrinthNote] = []
        for page in pages.filter({ $0.type == .bookOfYou }).sorted(by: { $0.createdAt < $1.createdAt }) {
            for receipt in BraidContributionReceipt.receipts(in: page.tags) {
                let text = sentenceClamp(receipt.detail, limit: 240)
                guard !text.isEmpty, seen.insert(receipt.id).inserted else { continue }
                notes.append(LabyrinthNote(date: page.createdAt, title: receipt.title, text: text))
                break
            }
            if notes.count == limit { break }
        }
        return notes
    }

    // MARK: - No sentence twice

    /// Drops any sentence that repeats one the issue has already said: the same
    /// words, or nearly. Returns the text unchanged when there is nothing to drop
    /// or when dropping would leave nothing, so a note is never emptied.
    static func removingRepeats(from text: String, of used: [String]) -> String {
        let usedSets = used.map(contentSet).filter { $0.count >= 4 }
        guard !usedSets.isEmpty else { return text }
        let kept = WonderBraid.sentences(text).filter { sentence in
            let mine = contentSet(sentence)
            guard mine.count >= 4 else { return true }
            return !usedSets.contains { other in
                Double(mine.intersection(other).count) / Double(min(mine.count, other.count)) >= 0.75
            }
        }
        let rebuilt = kept.joined(separator: " ")
        return rebuilt.isEmpty || kept.count == WonderBraid.sentences(text).count ? text : rebuilt
    }

    /// Whether this sentence says what one already said: the same content words, or
    /// nearly. A sentence too short to judge is never a repeat.
    static func repeats(_ sentence: String, of used: [String]) -> Bool {
        let mine = contentSet(sentence)
        guard mine.count >= 3 else { return false }
        return used.contains { other in
            let theirs = contentSet(other)
            guard theirs.count >= 3 else { return false }
            return Double(mine.intersection(theirs).count) / Double(min(mine.count, theirs.count)) >= 0.75
        }
    }

    private static func contentSet(_ text: String) -> Set<String> {
        Set(WonderBraid.contentWords(text).map(WonderBraid.stem))
    }
}

// MARK: - A quiet week

/// Whether a week is too thin to be worth printing without a word first. The reader is told, not
/// stopped: the choice to order is theirs, and the same issue can be read, saved and printed at home
/// for free beforehand.
enum WeeklyThinness {
    struct Assessment: Equatable {
        var keptPages: Int
        var keptDays: Int?
        var title: String { "A quiet week" }
        var message: String {
            let pages = "\(keptPages) \(keptPages == 1 ? "page" : "pages")"
            let span = keptDays.map { " on \($0) \($0 == 1 ? "day" : "days")" } ?? ""
            return "You kept \(pages)\(span) this week, so the printed issue will be on the thin side, with more of the Book's own pages around your few. "
                + "Nothing is lost by looking first: you can read the whole issue here for free, save it as a PDF, or print it yourself from the app. "
                + "Order it anyway if you'd like to hold it."
        }
    }

    static let minimumKeptPages = 6
    static let minimumKeptDays = 4

    /// nil when the week has enough in it. `keptDays` is nil when the days aren't known, in which
    /// case only the page count is judged.
    static func assess(keptPages: Int, keptDays: Int?) -> Assessment? {
        let thin = keptPages < minimumKeptPages || (keptDays.map { $0 < minimumKeptDays } ?? false)
        return thin ? Assessment(keptPages: keptPages, keptDays: keptDays) : nil
    }
}
