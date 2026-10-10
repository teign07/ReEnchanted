import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// The opening and last page read the Reader's ink, not the night's invented
/// furniture or the archive's word-count findings. Gemma may write the joins;
/// the quoted moment and its date are supplied by the press, unchanged.
struct WeeklyTaleReading {
    static let instructions = """
    You are the Labyrinth of Stories, a Book with a voice like a feral child:
    child-like anthropomorphism, not childish. Use simple, concrete words.
    Follow the small writing job and its output format exactly. The Reader's
    words and dates are facts. You may not add events or feelings to their life.
    Speak as the Book doing its work on the pages, without praise or a moral.
    """
    enum Position: String { case opening, closing }

    struct Moment: Equatable {
        var pageID: String
        var date: Date
        var text: String
    }

    struct Return: Equatable {
        var word: String
        var moments: [Moment]
    }

    var moments: [Moment]
    var returns: [Return]
    var calendar: Calendar

    init(issue: WeeklyIssue, calendar: Calendar = .current) {
        self.calendar = calendar
        moments = issue.pages.sorted { $0.createdAt < $1.createdAt }.compactMap { page in
            guard page.createdAt >= issue.startDate, page.createdAt < issue.endDate,
                  !EditionCurator.defaultPrivateTypes.contains(page.type), page.type != .bookOfYou,
                  page.weeklyIssueArtifact == nil, page.monthlyEditionArtifact == nil, page.annualEditionArtifact == nil,
                  let text = page.readerAuthoredTextForAnalysis?.nonEmpty else { return nil }
            return Moment(pageID: page.id, date: page.createdAt, text: text)
        }
        returns = Self.returns(in: moments, calendar: calendar)
    }

    static func returns(in moments: [Moment], calendar: Calendar) -> [Return] {
        var occurrences: [String: [Moment]] = [:]
        for moment in moments {
            for word in things(in: moment.text) {
                if !(occurrences[word] ?? []).contains(where: { calendar.isDate($0.date, inSameDayAs: moment.date) }) {
                    occurrences[word, default: []].append(moment)
                }
            }
        }
        return occurrences.filter {
            $0.value.count > 1 && Set($0.value.map { WonderBraid.normalized($0.text) }).count > 1
        }.sorted {
            if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
            let leftSpan = $0.value.last!.date.timeIntervalSince($0.value.first!.date)
            let rightSpan = $1.value.last!.date.timeIntervalSince($1.value.first!.date)
            if leftSpan != rightSpan { return leftSpan > rightSpan }
            return $0.key < $1.key
        }.prefix(2).map { Return(word: $0.key, moments: $0.value) }
    }

    /// Only nouns can return. Shared verbs, times and the app's own labels are
    /// not evidence that the days belong to one story.
    static func things(in text: String) -> Set<String> {
        // "Next door" names a neighbour, not a door returning on another day.
        let literal = text.replacingOccurrences(of: "\\bnext[- ]door\\b", with: "", options: [.regularExpression, .caseInsensitive])
        return nouns(in: literal).filter { $0.count >= 4 && !WeeklyCuration.isMetaWord($0) && !ordinaryWords.contains($0) }
    }

    private static func nouns(in text: String) -> Set<String> {
        var found = Set<String>()
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            guard tag == .noun else { return true }
            let word = String(text[range]).lowercased()
            found.insert(word)
            return true
        }
        #endif
        return found
    }

    private static let ordinaryWords: Set<String> = [
        "anything", "everything", "nothing", "today", "tomorrow", "yesterday", "time", "times",
        "life", "days", "months", "years", "year", "month", "hours", "hour", "minutes", "minute",
        "work", "home", "people", "someone", "everyone", "something", "sort", "kind", "part", "parts"
    ]

    func focus(for position: Position) -> Moment? {
        if position == .opening { return returns.first?.moments.first ?? moments.first }
        // An explicit last-page reflection is the Reader's account, not an
        // invitation for the Book to substitute its own diagnosis.
        return moments.last
    }

    static func excerpt(_ text: String) -> String {
        let sentences = WonderBraid.sentences(text)
        guard !sentences.isEmpty else { return text }
        // Whole sentences only. A long first sentence keeps its ending too.
        var chosen = sentences[0]
        if chosen.split(whereSeparator: \.isWhitespace).count < 8, sentences.count > 1 {
            chosen += " " + sentences[1]
        }
        return chosen
    }

    func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    var title: String? {
        guard let focus = focus(for: .opening) else { return nil }
        let heading = Self.heading(for: focus.text)
        return heading.flatMap { $0.count <= 72 ? $0 : nil } ?? "\(day(focus.date)), Kept"
    }

    /// NLTagger's lexical assets aren't always present in a simulator. The
    /// older fragment fallback removes function words, producing headings like
    /// "Carried heavy shopping all". A title may be a phrase or a whole sentence;
    /// it may never be a scrambled collection of the Reader's words.
    static func heading(for text: String) -> String? {
        let sentence = BraidSceneWriter.secondPerson(excerpt(text))
        let fragment = BraidScenePlan.fragment(of: sentence, fromEnd: false)
        if sentence.lowercased().contains(fragment.lowercased()), fragment != "A Quiet Night",
           isCompleteNounPhrase(fragment) { return fragment }
        guard sentence.count <= 130 else { return nil }
        return sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }

    private static func isCompleteNounPhrase(_ text: String) -> Bool {
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var tags: [NLTag] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if let tag { tags.append(tag) }
            return true
        }
        // A truncated verb phrase is still a substring of the source. Requiring
        // an actual noun phrase also fails safely when lexical data is absent.
        return tags.last == .noun && !tags.contains(.verb)
        #else
        return false
        #endif
    }

    var titlePrompt: String? {
        guard let focus = focus(for: .opening) else { return nil }
        return """
        Name this exact Tale of Your Week.
        Its opening moment, in the Reader's own words:
        \(Self.excerpt(focus.text))
        Pick a concrete title of 2 to 8 CONSECUTIVE words from this passage. Keep the words in their original order.
        Choose a particular thing. Capitalize the phrase as a title; add no new words.
        No invented actions, meaning, praise, secrets, lessons, dates or Reader name.
        Don't use “week,” “issue,” “journey” or “chapter.” Output the title only.
        """
    }

    func note(at position: Position, bookLines: [String]? = nil) -> String {
        guard let focus = focus(for: position) else {
            return position == .opening
                ? "These are the pages I have from this week. I'll show you what they hold."
                : "This is where these pages stop. I won't make up what happened outside them."
        }
        let choices = bookLineChoices(at: position)
        let seed = ConstellationKeeper.stableIndex(for: focus.text + position.rawValue, count: choices.first.count)
        let lines = bookLines ?? [choices.first[seed], choices.last[seed % choices.last.count]]
        let witness = position == .closing && focus.pageID == self.focus(for: .opening)?.pageID
            ? "That \(day(focus.date)) page is the last of your words I have from this week."
            : "On \(day(focus.date)), you wrote:\n\n“\(Self.excerpt(focus.text))”"
        var blocks = [lines.first, witness].compactMap { $0 }
        if let recurring = returns.first {
            if position == .opening, let later = recurring.moments.last,
               WonderBraid.normalized(later.text) != WonderBraid.normalized(focus.text) {
                blocks.append("Then on \(day(later.date)), you wrote:\n\n“\(Self.excerpt(later.text))”")
            }
        }
        blocks.append(contentsOf: lines.dropFirst())
        return blocks.joined(separator: "\n\n")
    }

    /// A small local model is better at choosing a voice than at inventing an
    /// editorial mind from scratch. These are authored Book joins, with the
    /// actual Reader passage between them. None makes a claim about their life.
    func bookLineChoices(at position: Position) -> (first: [String], last: [String]) {
        let source = focus(for: position).map { Self.excerpt($0.text) } ?? ""
        let fragment = BraidScenePlan.fragment(of: source, fromEnd: false)
        let faced = BraidSceneWriter.secondPerson(source)
        let subject = faced.lowercased().contains(fragment.lowercased()) && !Self.nouns(in: fragment).isEmpty
            ? WeeklyTaleBuilder.lowercasedArticle(fragment) : nil
        let part = subject.map { "the part about \($0)" } ?? "this part"
        func rotated(_ values: [String], slot: String) -> [String] {
            let offset = ConstellationKeeper.stableIndex(for: slot + position.rawValue + source, count: values.count)
            return Array(values[offset...] + values[..<offset])
        }
        func choices(_ first: [String], _ last: [String]) -> (first: [String], last: [String]) {
            (rotated(first, slot: "first"), rotated(last, slot: "last"))
        }
        if position == .opening {
            let last = moments.count <= 1 ? [
                "Come in. This page is yours.",
                "Turn the page. You can read it whole.",
                "I've put this page where I can find it again.",
                "I'm showing you what I have.",
                "I kept this. There is room around it."
            ] : [
                "Come in. I've kept the rest, too.",
                "Turn the page. There's more in here.",
                "I've put the days in their places. You can walk through them now.",
                "I want to show you what came after.",
                "I'm opening here. The rest is waiting inside."
            ]
            return choices([
                "I don't want \(part) lost between my pages.",
                "I want this one right at the front.",
                "No. This bit stays.",
                "I read this bit again before I started binding.",
                "I could have started elsewhere. I chose here."
            ], last)
        }
        return choices([
            "I don't want \(part) falling out when I shut.",
            "This is where these pages stop.",
            "I've reached the last of your words from this week.",
            "I'm putting this bit where I can find it again.",
            "I'm stopping here. The words stay."
        ], [
            "I can close my covers now. This part is kept.",
            "I'm closing this part. I'm leaving room.",
            "I don't have to know what happens next to keep this.",
            "I'm not writing The End on your life.",
            "I won't put words in the empty bits."
        ])
    }

    /// A small job for Gemma: the Book's two sentences around one locked moment.
    /// It does not paraphrase a person's life or make an arc out of vocabulary.
    func prompt(at position: Position) -> String {
        let source = focus(for: position).map { Self.excerpt($0.text) } ?? ""
        let choices = bookLineChoices(at: position)
        let first = choices.first.enumerated().map { "START\($0.offset + 1) \($0.element)" }.joined(separator: "\n")
        let last = choices.last.enumerated().map { "END\($0.offset + 1) \($0.element)" }.joined(separator: "\n")
        return """
        Choose the Book's \(position.rawValue) for this Reader passage:
        \(source)

        Choose one START and one END that suit these exact words. A painful or quiet
        passage deserves care, not excitement. Do not rewrite the passage or the choices.
        \(first)
        \(last)

        Output ONLY the two chosen IDs on separate lines, e.g. START2 then END4.
        """
    }

    func acceptedBookLines(_ raw: String, at position: Position) -> [String]? {
        let ids = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        let choices = bookLineChoices(at: position)
        if ids.count == 2, ids[0].hasPrefix("START"), ids[1].hasPrefix("END"),
           let first = Int(ids[0].dropFirst(5)), let last = Int(ids[1].dropFirst(3)),
           choices.first.indices.contains(first - 1), choices.last.indices.contains(last - 1) {
            return [choices.first[first - 1], choices.last[last - 1]]
        }
        let rawLines = raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let witness = focus(for: position).map { "\(day($0.date)): “\(Self.excerpt($0.text))”" }
        // Some drafts echo the exact supplied witness after the requested two
        // lines. It is harmless furniture: the press inserts its own copy.
        let lines = rawLines.filter { $0 != witness }
        guard lines.count == 2 else { return nil }
        var accepted: [String] = []
        let source = focus(for: position).map { Self.excerpt($0.text) } ?? ""
        let sourceNouns = Self.nouns(in: source)
        let allowedNouns = sourceNouns.union(["book", "page", "pages", "word", "words", "week", "covers", "cover", "part", "end", "beginning", "sentence", "sentences", "story", "ink", "bit", "bits", "attention", "paper", "margin", "margins"])
        for line in lines {
            guard line.hasPrefix("BOOK ") || line.hasPrefix("BOOK: ") else { return nil }
            let text = String(line.dropFirst(line.hasPrefix("BOOK: ") ? 6 : 5))
            guard text.hasPrefix("I ") || ["I'm ", "I've ", "I'll ", "I’m ", "I’ve ", "I’ll "].contains(where: text.hasPrefix),
                  WonderBraid.sentences(text).count == 1,
                  text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?"),
                  !BraidDraftVerifier.assertsSomethingHappenedToTheReader(text),
                  !BraidDraftVerifier.declaresMeaning(text),
                  text.range(of: "^I (?:I|the|a|an|this|that|these|those)\\b", options: [.regularExpression, .caseInsensitive]) == nil,
                  BraidPointOfView.returningTheReadersActions(in: text, readerDay: [BraidSceneWriter.secondPerson(source).lowercased(), "you " + source.lowercased()]).repaired == 0,
                  !text.contains("“"), !text.contains("\""),
                  !Self.hasUnsupportedClaim(text, allowedNouns: allowedNouns) else { return nil }
            accepted.append(text)
        }
        guard accepted.joined(separator: " ").split(whereSeparator: \.isWhitespace).count <= 35 else { return nil }
        if !sourceNouns.isEmpty, Self.nouns(in: accepted[0]).intersection(sourceNouns).isEmpty { return nil }
        return accepted
    }

    private static func hasUnsupportedClaim(_ text: String, allowedNouns: Set<String>) -> Bool {
        let forbidden = "\\b(feel\\w*|heal\\w*|brav\\w*|stronger|grow\\w*|transform\\w*|realiz\\w*|realis\\w*|learn\\w*|deserv\\w*|destin\\w*|secret\\w*|symbol\\w*|mean\\w*|seem\\w*|whisper\\w*|magic\\w*|proud|finally|always|never|every\\w*)\\b"
        if text.range(of: forbidden, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var unsafe = false
        var taggedWords = 0
        var taggedVerbs = 0
        let verbs: Set<String> = ["be", "have", "do", "will", "can", "would", "read", "write", "keep", "bind", "look", "open", "close", "want", "start", "end", "leave", "hold", "put", "lose", "turn", "remember", "think", "like", "refuse", "let", "gather", "finish", "show"]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag != nil { taggedWords += 1 }
            if tag == .verb { taggedVerbs += 1 }
            let word = String(text[range]).lowercased()
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased() ?? word
            if tag == .noun, !allowedNouns.contains(word), !allowedNouns.contains(lemma) { unsafe = true }
            if tag == .verb, !verbs.contains(lemma) { unsafe = true }
            return !unsafe
        }
        return unsafe || taggedWords == 0 || taggedVerbs == 0
        #else
        return true // The safe floor is preferable to an unchecked model note.
        #endif
    }

    func acceptedTitle(_ raw: String) -> String? {
        guard let source = focus(for: .opening) else { return nil }
        var title = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\"“”'*_#.!?"))
        if title == title.uppercased() { title = title.localizedCapitalized }
        guard (2...8).contains(title.split(whereSeparator: \.isWhitespace).count), title.count <= 72,
              !title.contains("\n"), !BraidDraftVerifier.declaresMeaning(title) else { return nil }
        let supplied = Set(WonderBraid.contentWords(source.text).map(WonderBraid.stem))
        let offered = Set(WonderBraid.contentWords(title).map(WonderBraid.stem))
        guard !offered.isEmpty, offered.isSubset(of: supplied) else { return nil }
        // Word bags admitted "Dog walk Amanda's". A title must be an actual
        // phrase, not a scrambled version of the Reader's sentence.
        func normalized(_ value: String) -> String {
            value.lowercased().replacingOccurrences(of: "’", with: "'")
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        guard normalized(source.text).contains(normalized(title)) else { return nil }
        return title
    }
}

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
