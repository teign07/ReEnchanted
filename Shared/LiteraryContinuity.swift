import Foundation

enum LiterarySignalKind: String, Codable, Equatable, CaseIterable {
    case pattern
    case beliefLifecycle
    case absence
    case duration
    case listening
}

// MARK: - Book of You Braid Prompting

enum BraidPromptBuilder {
    struct Context: Equatable {
        var recentBraids: [String] = []
        var theme: BookTheme?
        var chapter: AcademyChapter?
        var learnedGuidance: BraidLearningGuidance?
        var nowPlaying: String?
        var activeWorldEvents: [ResolvedWorldEvent] = []

        static let empty = Context()
    }

    static func context(
        for day: BookDay,
        days: [BookDay],
        themes: [BookTheme] = [],
        entityBeliefOffsets: [String: Int] = [:],
        learnedNotes: [String] = [],
        nowPlaying: String? = nil,
        activeWorldEvents: [ResolvedWorldEvent] = [],
        calendar: Calendar = .current
    ) -> Context {
        let recentBraids = recentBraidTexts(excludingDayID: day.id, days: days)
        let monthKey = BookThemeEngine.monthKey(for: day.date, calendar: calendar)
        let theme = BookThemeEngine.theme(forMonth: monthKey, in: themes)
        let chapter = TalismanAscendancy.ascendant(
            entities: NarrativePackRegistry.entities,
            beliefOffsets: entityBeliefOffsets
        ).flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0.id) }
        let improvementContext = Context(recentBraids: recentBraids, theme: theme, chapter: chapter)
        let learned = BraidLearningLoop.guidance(
            fromPages: days.flatMap(\.pages),
            context: improvementContext
        )
        // Reader-taught Gemma notes sort ahead of the deterministic heuristics:
        // the reader said this braid missed, and the Book listened.
        let merged = BraidLearningGuidance(signals: BraidLearningLoop.readerTaughtSignals(from: learnedNotes) + learned.signals)

        return Context(
            recentBraids: recentBraids,
            theme: theme,
            chapter: chapter,
            learnedGuidance: merged.signals.isEmpty ? nil : merged,
            nowPlaying: nowPlaying,
            activeWorldEvents: activeWorldEvents
        )
    }

    static func recentBraidTexts(excludingDayID dayID: String, days: [BookDay], limit: Int = 2) -> [String] {
        let braids = days
            .filter { $0.id != dayID }
            .sorted { $0.date < $1.date }
            .flatMap { day in day.pages.filter { $0.type == .bookOfYou } }
        guard !braids.isEmpty else { return [] }

        var selected: [BookPage] = []
        if let newest = braids.last {
            selected.append(newest)
        }
        if braids.count >= 5 {
            selected.append(braids[braids.count - 5])
        }

        return selected
            .prefix(limit)
            .map { clippedText($0.userInput, limit: 700) }
    }

    static func prompt(for day: BookDay, recentBraids: [String] = []) -> String {
        prompt(for: day, context: Context(recentBraids: recentBraids))
    }

    static func prompt(for day: BookDay, context: Context) -> String {
        let evidence = evidenceLines(for: day).joined(separator: "\n\n")
        let continuity: String
        if context.recentBraids.isEmpty {
            continuity = ""
        } else {
            let earlier = context.recentBraids.enumerated()
                .map { index, braid in "EARLIER BRAID \(index + 1):\n\(braid)" }
                .joined(separator: "\n\n")
            continuity = """


            EARLIER PAGES OF THE BOOK OF YOU (continuity, not material):
            \(earlier)

            CONTINUITY RULE:
            - At most one image or motif from an earlier braid may return today, changed by what today actually held.
            - Never repeat an earlier braid's sentences and never re-describe its events. Today's kept pages are the only material.
            - If nothing from earlier honestly connects, let nothing return.
            """
        }
        let themeSection: String
        if let theme = context.theme {
            themeSection = """


            MONTHLY THEME THREAD:
            \(theme.promptLine)

            THEME RULE:
            - Let this theme behave like a faint running head or watermark, not a thesis statement.
            - Use at most one of its motifs unless today's kept pages clearly invite more.
            """
        } else {
            themeSection = ""
        }

        let chapterSection: String
        if let chapter = context.chapter {
            chapterSection = """


            CHAPTER WEATHER:
            Chapter \(chapter.name)
            Philosophy: \(chapter.philosophy)
            Talisman: \(chapter.talismanName)
            Writing frame: \(chapter.writeFraming)
            Story bias: \(chapter.storyBias)

            CHAPTER RULE:
            - Let the chapter color the braid's angle of attention, not announce itself as a label.
            - Do not say "Chapter \(chapter.name)" unless a kept page already named it.
            """
        } else {
            chapterSection = ""
        }

        let learnedSection: String
        if let guidance = context.learnedGuidance, !guidance.promptLines.isEmpty {
            learnedSection = """


            LEARNED BRAID TASTE:
            \(guidance.promptLines.map { "- \($0)" }.joined(separator: "\n"))

            LEARNING RULE:
            - Treat these as local taste notes from prior Book of You pages, not hard lore.
            - Follow the strongest note first, but never violate the kept pages.
            """
        } else {
            learnedSection = ""
        }

        return """
        You are the Book inside ReEnchanted.
        Braid the player's kept pages into one grounded Book of You entry: a small story about this day. The Book of You is one continuing book, not a stack of unrelated entries.

        SPINE FIRST:
        - Before writing, silently choose the day's spine: the one detail, tension, or small change that the kept pages keep circling. Build the braid around it.
        - The other pages are tributaries. Let them feed the spine instead of standing in a row.
        - Silently choose a short title for the day. Use it only if it can appear as the first line without feeling like a heading label.

        SHAPE:
        - Write 4 to 7 paragraphs, about 280 to 450 words.
        - The first line may be a bare title, 2 to 7 words, if a true one arrives. Do not prefix it with "Title:".
        - Follow the day's real clock: the kept pages are timestamped - let morning be morning and evening be evening.
        - Give the braid old tale bones under modern room-light: Once, Because, Until, And so, Kept.
        - The "Once" is where the day truly began. The "Because" is the real pressure or hunger gathering. The "Until" is the turn, and it must be something that actually happened, not a mood shift. The "And so" is the small change left behind.
        - Make it feel narrated, not listed. Do not mention page types like "Weather Page" or "Lore Page" unless the player wrote those words.
        - End with one closing sentence that begins: "The Book kept the page:"
        - Let that final line loop back to the spine: carry one concrete thing from how the day began into how it is kept, so the page closes the circle it opened.
        - On a phone, the braid should feel like a full page of the Book without becoming a scroll chore.

        PROVENANCE GRAVITY:
        - Treat reader-authored and imported real-world pages as anchor threads. One-Sentence Souvenirs are especially strong spine candidates because they are the reader choosing one true line.
        - Treat generated or simulated story pages as color threads: let them tint metaphors, motifs, cast pressure, and fairy-tale logic, but do not let them overrule what the reader actually wrote or what an imported real-world source says.
        - If a generated page carries a reader reply, upgraded choice, or user-edited line, treat that response as reader-endorsed fiction: stronger than ordinary generated color, still lighter than a real souvenir or direct user-authored page.
        - When anchor and color threads conflict, the anchor wins. Let the fiction bleed into the real without drowning it.
        - Build the spine from anchor threads first, then weave color threads around it so the day feels half true record, half spell.

        VOICE:
        - Write with varied literary cadence: some sentences should be short, plain, and surprising; others may be longer and more flowing, turning through image and thought before they land.
        - Let the voice feel like a clear old tale told beside a modern lamp: mythic but not ornate, intimate but not sentimental, concrete before abstract.
        - Bring faerie pressure through ordinary objects: cups, keys, chargers, coats, dishes, windows, receipts, weather, doorways. Never make the day fake-grand.
        - The Book notices small true details and gives them a little magic.
        - Prefer what someone said, touched, carried, avoided, dropped, or noticed over explaining what it means.
        - Let at least two sentences per braid run longer than the others, like a breath let out, but keep them anchored in supplied facts.
        - Avoid a drumbeat of same-length declarative sentences. Vary openings, sentence lengths, and paragraph shapes.
        - No diagnosis, no flattery, no moralizing, no corporate/app language.
        - Do not invent completed actions, locations, people, feelings, or tasks.
        - Avoid vague wonder, generic inspiration, journey, profound, tapestry, echoes, hidden meaning, and abstract emotional summary.

        REGISTER LOCK (the most common way this braid fails):
        - Never use clinical, scientific, or report diction. Banish words like: nascent, precipitation, observation, observed, reckoning, currents, structure, inner landscape, transfer, exchange, documented, noted, the report. These break the spell harder than purple words do.
        - Do not narrate the braid about itself. Forbidden moves: "the observation of this shift followed", "a quiet transfer of something fragile", "this weather pressed against the inner landscape". Name the thing, do not name the noticing of the thing.
        - Lean on concrete nouns and plain strong verbs, not abstract nouns. If a sentence's subject is an idea (a shift, a moment, a reckoning, a structure, a brightness), rewrite it so the subject is something you could touch, hold, or hear.
        - Transmute numbers and data. Never quote a raw forecast ("sixty degrees, a high of sixty-one and a low of fifty-five"). Turn measurements into weather felt on the skin: a gray sky, a cold that gets in at the collar, rain the air keeps promising.

        ONE LENS:
        - Choose a single point of view for the whole braid and hold it. If the reader is "you", stay "you"; if the day belongs to a named person, stay with them. Do not drift between "you", "a mortal", a name, and an unnamed "figure" in the same page.
        - Do not turn the reader into a distant "a mortal" or "a figure" partway through. The Book is writing one person's day to that person.

        ANTI-PARROT RULE:
        - Do not copy any supplied sentence longer than seven words.
        - Paraphrase the kept pages into a coherent story.
        - You may quote one short phrase only if it has unusual power.
        - Mention each motif, image, sentence idea, or emotional beat only once.
        - Do not restate the same idea in consecutive paragraphs with swapped words.
        - Prefer one fresh concrete detail over a second sentence explaining the same mood, object, weather, relationship, or threshold.

        KEPT PAGES FROM TODAY:
        \(evidence.isEmpty ? "- No kept pages yet. Write a quiet note about the Book waiting for the day to gather." : evidence)\(themeSection)\(chapterSection)\(learnedSection)\(RadioAtmosphere.promptSection(context.nowPlaying))\(context.activeWorldEvents.bookOfYouPromptSection)\(continuity)
        """
    }

    /// Gemma re-reads a braid the reader said missed them and rewrites it
    /// truer. The full braid craft spec is reused so the revision plays by the
    /// same rules; the prior draft and the weak-dimension notes tell it what to
    /// fix. `weakNotes` come from `BraidLearningLoop.weakDimensionNotes`.
    static func rewritePrompt(for day: BookDay, priorBraid: String, weakNotes: [String], context: Context) -> String {
        let base = prompt(for: day, context: context)
        let weakSection = weakNotes.isEmpty
            ? ""
            : "\n\nWHAT MISSED LAST TIME (address these first, without violating the kept pages):\n"
                + weakNotes.map { "- \($0)" }.joined(separator: "\n")
        return """
        You already braided this day once, and the reader felt the page missed them. Rewrite it truer to their day.

        YOUR PRIOR DRAFT (keep what was honest, fix what missed, and do not reuse its sentences):
        \(priorBraid)\(weakSection)

        Now write the improved Book of You page, following every rule below.

        \(base)
        """
    }

    /// Gemma turns a missed braid into one short reader-taught taste note that
    /// will steer future braids. Returns a prompt for a single sentence.
    static func tasteNotePrompt(for day: BookDay, priorBraid: String, weakNotes: [String], context: Context) -> String {
        let evidence = evidenceLines(for: day).joined(separator: "\n\n")
        let weakSection = weakNotes.isEmpty
            ? ""
            : "\n\nHEURISTIC HUNCHES (you may agree or disagree):\n"
                + weakNotes.map { "- \($0)" }.joined(separator: "\n")
        return """
        You are the Book inside ReEnchanted. The reader marked this Book of You page as one that missed them.
        Read it against the kept pages it was braided from, and name in one short sentence what the Book should do differently next time it braids this reader's days.

        THE PAGE THAT MISSED:
        \(priorBraid)\(weakSection)

        KEPT PAGES FROM THAT DAY:
        \(evidence.isEmpty ? "- None recorded." : evidence)

        Reply with exactly one second-person instruction to yourself for next time, at most 24 words.
        Begin with a verb. No preamble, no quotation marks, no "Note:" label.
        Speak as the reader's own taste, for example: "Stay closer to what my hands actually did." or "Let the evening hold the final line."
        """
    }

    private static func evidenceLines(for day: BookDay, characterLimit: Int = 760) -> [String] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return day.capturedPages
            .sorted { $0.createdAt < $1.createdAt }
            .enumerated()
            .map { index, page in
                let prompt = clippedText(page.promptText, limit: 220)
                let text = clippedText(page.userInput, limit: characterLimit)
                let tags = page.tags.isEmpty ? "none" : page.tags.joined(separator: ", ")
                let media = mediaEvidence(for: page)
                let reply = clippedText(page.playerReply, limit: 260)
                return """
                \(index + 1). \(page.type.title) - kept at \(timeFormatter.string(from: page.createdAt))
                Thread gravity: \(threadGravity(for: page))
                Prompt: \(prompt.isEmpty ? "none" : prompt)
                Kept text: \(text.isEmpty ? "(blank)" : text)
                Reader reply: \(reply.isEmpty ? "none" : reply)
                Visual evidence: \(media.isEmpty ? "none" : media)
                Tags: \(tags)
                """
            }
    }

    private static func threadGravity(for page: BookPage) -> String {
        let hasReaderReply = !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch page.origin {
        case .userAuthored:
            if page.type == .souvenir {
                return "reader-authored anchor; one-sentence souvenir; highest gravity"
            }
            return "reader-authored anchor; high gravity"
        case .imported:
            return "imported real-world anchor; high gravity"
        case .generated, .simulated:
            if hasReaderReply {
                return "reader-endorsed fiction; medium gravity"
            }
            return "generated fiction color; lower gravity"
        }
    }

    private static func mediaEvidence(for page: BookPage) -> String {
        page.mediaAssets
            .prefix(3)
            .map { asset in
                let kind: String
                switch asset.kind {
                case .bundledImage:
                    kind = "bundled Labyrinth illustration"
                case .renderedImageFile:
                    kind = "kept illuminated page image"
                case .photoLibraryAsset:
                    kind = "private source photo reference"
                }
                let caption = clippedText(asset.caption, limit: 140)
                return caption.isEmpty ? kind : "\(kind): \(caption)"
            }
            .joined(separator: "; ")
    }

    private static func clippedText(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

struct BraidPageDetails: Equatable {
    static let promptVersion = "book-of-you-braid-v2"

    var title: String
    var body: String
    var themeName: String?
    var chapterName: String?

    static func details(for page: BookPage) -> BraidPageDetails {
        let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = parseTitleAndBody(from: text)
        let fallbackTitle = page.promptText
            .replacingOccurrences(of: "Book of You:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return BraidPageDetails(
            title: parsed.title ?? fallbackTitle.nonEmpty ?? "Book of You",
            body: parsed.body.nonEmpty ?? text,
            themeName: tagValue(prefix: "theme:", in: page.tags),
            chapterName: tagValue(prefix: "chapter:", in: page.tags)
        )
    }

    static func annotated(_ page: BookPage, context: BraidPromptBuilder.Context) -> BookPage {
        var updated = page
        let details = details(for: page)
        if details.title != "Book of You" {
            updated.promptText = "Book of You: \(details.title)"
        }
        updated.promptVersion = promptVersion

        var tags = Set(updated.tags)
        tags.insert("braid-v2")
        if let theme = context.theme?.name, !theme.isEmpty {
            tags.insert("theme:\(theme)")
        }
        if let chapter = context.chapter?.name, !chapter.isEmpty {
            tags.insert("chapter:\(chapter)")
        }
        if !context.recentBraids.isEmpty {
            tags.insert("yesterday-echo")
        }
        updated.tags = tags.sorted()
        return updated
    }

    private static func parseTitleAndBody(from text: String) -> (title: String?, body: String) {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = paragraphs.first, looksLikeTitle(first) else {
            return (nil, text)
        }
        return (first, paragraphs.dropFirst().joined(separator: "\n\n"))
    }

    private static func looksLikeTitle(_ value: String) -> Bool {
        guard !value.hasPrefix("The Book kept the page:"),
              !value.localizedCaseInsensitiveContains("Title:"),
              value.count <= 64 else {
            return false
        }
        if value.contains(".") || value.contains("?") || value.contains("!") || value.contains(":") {
            return false
        }
        let words = value.split { $0.isWhitespace || $0 == "," || $0 == ";" }
        return (2...7).contains(words.count)
    }

    private static func tagValue(prefix: String, in tags: [String]) -> String? {
        tags.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap(\.nonEmpty)
    }
}

// MARK: - Braid Learning

struct BraidLearningGuidance: Equatable, Codable {
    struct Signal: Equatable, Codable {
        var dimension: String
        var weight: Int
        var note: String
    }

    var signals: [Signal]

    var promptLines: [String] {
        signals
            .sorted { lhs, rhs in
                if lhs.weight == rhs.weight {
                    return lhs.dimension < rhs.dimension
                }
                return lhs.weight > rhs.weight
            }
            .prefix(4)
            .map(\.note)
    }

    static let empty = BraidLearningGuidance(signals: [])
}

enum BraidLearningLoop {
    static let missedMeTag = "braid-missed-me"
    static let lovedItTag = "braid-loved-it"
    static let improveNextTag = missedMeTag
    static let improvedTag = "braid-improved-next"

    struct Observation: Equatable {
        var selected: BraidTastingRoom.Sample
        var alternatives: [BraidTastingRoom.Sample]
        var acceptedByReader: Bool
        var editedText: String?

        init(
            selected: BraidTastingRoom.Sample,
            alternatives: [BraidTastingRoom.Sample] = [],
            acceptedByReader: Bool = true,
            editedText: String? = nil
        ) {
            self.selected = selected
            self.alternatives = alternatives
            self.acceptedByReader = acceptedByReader
            self.editedText = editedText
        }
    }

    static func guidance(from observations: [Observation], limit: Int = 8) -> BraidLearningGuidance {
        let recent = observations.suffix(limit)
        var weights: [String: Int] = [:]
        var notes: [String: String] = [:]

        for observation in recent {
            let selected = observation.selected
            let score = selected.score
            let readerPenalty = observation.acceptedByReader ? 0 : 4

            addIfWeak(score.title, threshold: 8, dimension: "title", weight: 2 + readerPenalty, into: &weights, notes: &notes)
            addIfWeak(score.storyShape, threshold: 15, dimension: "storyShape", weight: 3 + readerPenalty, into: &weights, notes: &notes)
            addIfWeak(score.priorEcho, threshold: 7, dimension: "priorEcho", weight: 2 + readerPenalty, into: &weights, notes: &notes)
            addIfWeak(score.themeAndChapter, threshold: 8, dimension: "themeAndChapter", weight: 2 + readerPenalty, into: &weights, notes: &notes)
            addIfWeak(score.keeperSentence, threshold: 10, dimension: "keeperSentence", weight: 3 + readerPenalty, into: &weights, notes: &notes)
            addIfWeak(score.concreteMagic, threshold: 9, dimension: "concreteMagic", weight: 2 + readerPenalty, into: &weights, notes: &notes)

            if score.penalties > 0 {
                weights["penalties", default: 0] += score.penalties + readerPenalty
                notes["penalties"] = note(for: "penalties")
            }

            if let editedText = observation.editedText,
               editedText.normalizedForBraidTasting != selected.page.userInput.normalizedForBraidTasting {
                learnFromEdit(original: selected.page.userInput, edited: editedText, weights: &weights, notes: &notes)
            }
        }

        let signals = weights.map { dimension, weight in
            BraidLearningGuidance.Signal(
                dimension: dimension,
                weight: weight,
                note: notes[dimension] ?? note(for: dimension)
            )
        }
        .filter { $0.weight > 0 }

        return BraidLearningGuidance(signals: signals)
    }

    static func guidance(
        fromPages pages: [BookPage],
        context: BraidPromptBuilder.Context = .empty,
        limit: Int = 8
    ) -> BraidLearningGuidance {
        let observations = pages
            .filter { $0.type == .bookOfYou && $0.tags.contains(improveNextTag) }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(limit)
            .map { page in
                let sample = BraidTastingRoom.Sample(
                    page: page,
                    details: BraidPageDetails.details(for: page),
                    score: BraidTastingRoom.score(page: page, context: context)
                )
                return Observation(selected: sample, acceptedByReader: false)
            }
        var guidance = guidance(from: observations, limit: limit)
        if !observations.isEmpty, guidance.signals.isEmpty {
            guidance = BraidLearningGuidance(signals: [
                .init(
                    dimension: "concreteMagic",
                    weight: 1,
                    note: note(for: "concreteMagic")
                )
            ])
        }
        return guidance
    }

    static func improvedContext(
        _ context: BraidPromptBuilder.Context,
        observations: [Observation],
        limit: Int = 8
    ) -> BraidPromptBuilder.Context {
        var updated = context
        let guidance = guidance(from: observations, limit: limit)
        updated.learnedGuidance = guidance.signals.isEmpty ? nil : guidance
        return updated
    }

    /// Reader-taught Gemma notes (earned on "this missed me") become guidance
    /// signals weighted above the deterministic heuristics, newest first.
    static func readerTaughtSignals(from notes: [String]) -> [BraidLearningGuidance.Signal] {
        let cleaned = notes.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
        guard !cleaned.isEmpty else { return [] }
        return cleaned.enumerated().map { index, note in
            BraidLearningGuidance.Signal(dimension: "reader-taught", weight: 40 + index, note: note)
        }
    }

    /// The weak-dimension prompt lines for a single braid page — used to tell
    /// Gemma exactly what to address when re-reading or rewriting it.
    static func weakDimensionNotes(for page: BookPage, context: BraidPromptBuilder.Context = .empty) -> [String] {
        let sample = BraidTastingRoom.Sample(
            page: page,
            details: BraidPageDetails.details(for: page),
            score: BraidTastingRoom.score(page: page, context: context)
        )
        return guidance(from: [Observation(selected: sample, acceptedByReader: false)]).promptLines
    }

    static func publicLesson(for page: BookPage, context: BraidPromptBuilder.Context = .empty) -> String {
        let guidance = guidance(fromPages: [page], context: context, limit: 1)
        let note = guidance.promptLines.first ?? note(for: "concreteMagic")
        if note.localizedCaseInsensitiveContains("title") {
            return "The Book learned to name the day more sharply next time."
        }
        if note.localizedCaseInsensitiveContains("old-tale") {
            return "The Book learned to give the next Braid a clearer turn."
        }
        if note.localizedCaseInsensitiveContains("earlier image") {
            return "The Book learned to echo yesterday only when the echo changes."
        }
        if note.localizedCaseInsensitiveContains("theme and chapter") {
            return "The Book learned to let theme and chapter move like weather."
        }
        if note.localizedCaseInsensitiveContains("The Book kept the page") {
            return "The Book learned to leave the next page with a stronger final line."
        }
        if note.localizedCaseInsensitiveContains("ordinary enchanted objects") {
            return "The Book learned to put more magic into ordinary things."
        }
        if note.localizedCaseInsensitiveContains("generic") {
            return "The Book learned to trade grand words for truer details."
        }
        return "The Book learned a little more about how your days want to be told."
    }

    private static func addIfWeak(
        _ value: Int,
        threshold: Int,
        dimension: String,
        weight: Int,
        into weights: inout [String: Int],
        notes: inout [String: String]
    ) {
        guard value < threshold else { return }
        weights[dimension, default: 0] += max(1, threshold - value + weight)
        notes[dimension] = note(for: dimension)
    }

    private static func learnFromEdit(
        original: String,
        edited: String,
        weights: inout [String: Int],
        notes: inout [String: String]
    ) {
        let originalSentences = original.braidSentences.count
        let editedSentences = edited.braidSentences.count
        if editedSentences > originalSentences {
            weights["storyShape", default: 0] += 2
            notes["storyShape"] = note(for: "storyShape")
        }

        let originalConcrete = concreteWordCount(in: original)
        let editedConcrete = concreteWordCount(in: edited)
        if editedConcrete > originalConcrete {
            weights["concreteMagic", default: 0] += 3
            notes["concreteMagic"] = note(for: "concreteMagic")
        }

        if edited.contains("The Book kept the page:") && !original.contains("The Book kept the page:") {
            weights["keeperSentence", default: 0] += 4
            notes["keeperSentence"] = note(for: "keeperSentence")
        }
    }

    private static func concreteWordCount(in text: String) -> Int {
        let normalized = text.normalizedForBraidTasting
        let words = ["cup", "key", "charger", "coat", "dish", "window", "receipt", "door", "lamp", "phone", "rain", "coffee", "table", "shoe", "bag"]
        return words.filter { normalized.contains($0) }.count
    }

    private static func note(for dimension: String) -> String {
        switch dimension {
        case "title":
            return "Choose a sharper, less generic title: 2 to 7 concrete words, no label, no summary."
        case "storyShape":
            return "Strengthen the old-tale turn: make the Once, Because, Until, and And so movements legible without listing them."
        case "priorEcho":
            return "Let one earlier image return changed by today, or let the prior braid stay silent."
        case "themeAndChapter":
            return "Use theme and chapter as weather: one quiet motif or angle, never an announcement."
        case "keeperSentence":
            return "End with exactly one memorable sentence beginning 'The Book kept the page:'."
        case "concreteMagic":
            return "Trade abstract wonder for ordinary enchanted objects: cups, keys, windows, chargers, coats, receipts, doors."
        case "penalties":
            return "Drop report and clinical diction (nascent, precipitation, observation, reckoning, currents), quote no raw forecast numbers, hold one point of view, and avoid generic reflection words or doubled explanation."
        default:
            return "Prefer concrete, specific Book of You prose over generic summary."
        }
    }
}

// MARK: - Braid Tasting Room

enum BraidTastingRoom {
    struct Sample: Equatable {
        var page: BookPage
        var details: BraidPageDetails
        var score: Score
    }

    struct Score: Equatable, Comparable {
        var title: Int
        var storyShape: Int
        var priorEcho: Int
        var themeAndChapter: Int
        var keeperSentence: Int
        var concreteMagic: Int
        var penalties: Int

        var total: Int {
            title + storyShape + priorEcho + themeAndChapter + keeperSentence + concreteMagic - penalties
        }

        static func < (lhs: Score, rhs: Score) -> Bool {
            lhs.total < rhs.total
        }
    }

    struct Result: Equatable {
        var samples: [Sample]
        var winner: Sample?
    }

    static func taste(_ pages: [BookPage], context: BraidPromptBuilder.Context = .empty) -> Result {
        let samples = pages.map { page -> Sample in
            let details = BraidPageDetails.details(for: page)
            return Sample(
                page: page,
                details: details,
                score: score(details: details, context: context)
            )
        }
        .sorted { lhs, rhs in
            if lhs.score.total == rhs.score.total {
                return lhs.details.title.localizedCaseInsensitiveCompare(rhs.details.title) == .orderedAscending
            }
            return lhs.score.total > rhs.score.total
        }
        return Result(samples: samples, winner: samples.first)
    }

    static func score(page: BookPage, context: BraidPromptBuilder.Context = .empty) -> Score {
        score(details: BraidPageDetails.details(for: page), context: context)
    }

    private static func score(details: BraidPageDetails, context: BraidPromptBuilder.Context) -> Score {
        let body = details.body
        let normalized = body.normalizedForBraidTasting
        let paragraphs = body.braidParagraphs
        let sentences = body.braidSentences
        let closingSentences = sentences.filter { $0.hasPrefix("The Book kept the page:") }

        return Score(
            title: titleScore(details.title),
            storyShape: storyShapeScore(paragraphs: paragraphs, normalized: normalized),
            priorEcho: priorEchoScore(normalized: normalized, context: context),
            themeAndChapter: themeAndChapterScore(normalized: normalized, context: context),
            keeperSentence: keeperSentenceScore(closingSentences, opening: paragraphs.first),
            concreteMagic: concreteMagicScore(normalized: normalized),
            penalties: penaltyScore(normalized: normalized, sentences: sentences)
        )
    }

    private static func titleScore(_ title: String) -> Int {
        let words = title.split { $0.isWhitespace || $0 == "," || $0 == ";" }
        guard title != "Book of You", (2...7).contains(words.count), title.count <= 64 else {
            return 0
        }
        let generic = ["today", "journey", "reflection", "meaning", "magic", "braid"]
        let genericHits = generic.filter { title.localizedCaseInsensitiveContains($0) }.count
        return max(0, 12 - genericHits * 3)
    }

    private static func storyShapeScore(paragraphs: [String], normalized: String) -> Int {
        var score = 0
        if (4...7).contains(paragraphs.count) { score += 8 }
        if containsAny(["once", "began", "morning", "first"], in: normalized) { score += 3 }
        if containsAny(["because", "wanted", "needed", "pressure", "hunger"], in: normalized) { score += 3 }
        if containsAny(["until", "then", "when"], in: normalized) { score += 3 }
        if containsAny(["and so", "left behind", "afterward", "kept"], in: normalized) { score += 3 }
        return min(score, 20)
    }

    private static func priorEchoScore(normalized: String, context: BraidPromptBuilder.Context) -> Int {
        guard !context.recentBraids.isEmpty else { return 6 }
        let motifHits = context.recentBraids
            .flatMap(significantWords)
            .filter { normalized.contains($0) }
        let uniqueHits = Set(motifHits).count
        if uniqueHits == 0 { return 0 }
        if uniqueHits <= 3 { return 10 }
        return 5
    }

    private static func themeAndChapterScore(normalized: String, context: BraidPromptBuilder.Context) -> Int {
        var score = 0
        if let theme = context.theme {
            let motifHits = theme.motifs
                .map { $0.normalizedForBraidTasting }
                .filter { !$0.isEmpty && normalized.contains($0) }
                .count
            if motifHits == 1 {
                score += 6
            } else if motifHits > 1 {
                score += 3
            }
            if normalized.contains(theme.name.normalizedForBraidTasting) {
                score -= 2
            }
        } else {
            score += 3
        }

        if let chapter = context.chapter {
            if normalized.contains("chapter \(chapter.name.normalizedForBraidTasting)") {
                score -= 3
            }
            let frameHits = significantWords(chapter.writeFraming + " " + chapter.storyBias)
                .filter { normalized.contains($0) }
                .count
            if frameHits > 0 {
                score += 5
            }
        } else {
            score += 3
        }

        return max(0, min(score, 12))
    }

    private static func keeperSentenceScore(_ closingSentences: [String], opening: String?) -> Int {
        guard closingSentences.count == 1, let closing = closingSentences.first else { return 0 }
        let words = closing.split { $0.isWhitespace }.count
        guard (8...28).contains(words) else { return 5 }
        return 14 + callbackBonus(closing: closing, opening: opening)
    }

    /// Reward the opening->closing loop: when the kept line carries a concrete
    /// word back from where the day began, the braid feels deliberately kept
    /// rather than merely ended. Bonus is capped so it can lift a strong braid
    /// without letting the keeper sentence dominate the whole score.
    private static func callbackBonus(closing: String, opening: String?) -> Int {
        guard let opening, !opening.isEmpty else { return 0 }
        let openingWords = Set(significantWords(opening))
        guard !openingWords.isEmpty else { return 0 }
        // Drop the fixed "the book kept the page" stem so it can't self-match.
        let keeperStem = significantWords("the book kept the page")
        let echoes = significantWords(closing)
            .filter { !keeperStem.contains($0) && openingWords.contains($0) }
        return min(Set(echoes).count * 3, 6)
    }

    private static func concreteMagicScore(normalized: String) -> Int {
        let ordinary = ["cup", "key", "charger", "coat", "dish", "window", "receipt", "door", "lamp", "phone", "rain", "coffee", "table", "shoe", "bag"]
        let magical = ["book", "faerie", "spell", "charm", "threshold", "omen", "glimmer", "lantern", "kept", "bright", "moon", "moth"]
        let ordinaryHits = ordinary.filter { normalized.contains($0) }.count
        let magicalHits = magical.filter { normalized.contains($0) }.count
        return min(14, min(ordinaryHits, 4) * 2 + min(magicalHits, 3) * 2)
    }

    private static func penaltyScore(normalized: String, sentences: [String]) -> Int {
        let banned = ["journey", "profound", "tapestry", "hidden meaning", "generic inspiration"]
        var penalties = banned.filter { normalized.contains($0) }.count * 4

        // Clinical / report diction breaks the spell as badly as purple words do.
        let clinical = [
            "nascent", "precipitation", "observation", "observed", "reckoning",
            "currents", "inner landscape", "the report", "transfer of", "documented"
        ]
        penalties += clinical.filter { normalized.contains($0) }.count * 4

        // Raw forecast figures should be transmuted into felt weather, not quoted.
        let temperatureWords = ["degrees", "high of", "low of", "overcast at", "forecast"]
        penalties += temperatureWords.filter { normalized.contains($0) }.count * 3

        // Point-of-view drift: distancing the reader into a specimen mid-braid.
        let distancing = ["a mortal", "the mortal", "a figure", "the figure"]
        penalties += distancing.filter { normalized.contains($0) }.count * 2

        if sentences.count < 4 { penalties += 6 }
        let repeatedStarts = Dictionary(grouping: sentences.compactMap { $0.split(separator: " ").first?.lowercased() }, by: { $0 })
            .values
            .filter { $0.count >= 3 }
            .count
        penalties += repeatedStarts * 3
        return penalties
    }

    private static func significantWords(_ text: String) -> [String] {
        let stopwords: Set<String> = [
            "about", "after", "again", "because", "before", "chapter", "could", "every", "from", "into", "like",
            "little", "more", "only", "over", "that", "their", "there", "this", "through", "under", "when",
            "where", "with", "without", "would", "write", "writing"
        ]
        return text
            .normalizedForBraidTasting
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !stopwords.contains($0) }
    }

    private static func containsAny(_ needles: [String], in haystack: String) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}

private extension String {
    var normalizedForBraidTasting: String {
        lowercased()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var braidParagraphs: [String] {
        replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var braidSentences: [String] {
        replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct LiteraryContinuitySignal: Identifiable, Codable, Equatable {
    var id: String
    var kind: LiterarySignalKind
    var subjectID: String
    var subjectName: String
    var line: String
    var evidencePageIDs: [String]
    var relatedEntityIDs: [String]
    var tags: [String]
    var firstSeenAt: Date
    var lastSeenAt: Date
    var strength: Int

    var promptLine: String {
        "\(subjectName): \(line)"
    }
}

struct BeliefLifecycleProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var currentGlow: Int
    var firstSeenAt: Date
    var lastSeenAt: Date
    var pageCount: Int
    var eventCount: Int
    var characterCount: Int
    var evidencePageIDs: [String]
    var relatedEntityIDs: [String]

    var ageInDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: firstSeenAt), to: Calendar.current.startOfDay(for: Date())).day ?? 1)
    }
}

struct LiteraryContinuityDigest: Codable, Equatable {
    var signals: [LiteraryContinuitySignal]
    var beliefLifecycles: [BeliefLifecycleProfile]

    static let empty = LiteraryContinuityDigest(signals: [], beliefLifecycles: [])

    var strongestSignals: [LiteraryContinuitySignal] {
        signals.sorted { left, right in
            if left.strength == right.strength {
                return left.subjectName < right.subjectName
            }
            return left.strength > right.strength
        }
    }

    func signals(relatedTo page: BookPage, limit: Int = 3) -> [LiteraryContinuitySignal] {
        let pageWords = Self.meaningfulWords(in: "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))")
        return strongestSignals
            .filter { signal in
                !Set(signal.evidencePageIDs).isDisjoint(with: [page.id])
                    || !Set(signal.tags.map { $0.lowercased() }).isDisjoint(with: pageWords)
                    || pageWords.contains(signal.subjectName.lowercased())
            }
            .prefix(limit)
            .map(\.self)
    }

    private static func meaningfulWords(in text: String) -> Set<String> {
        LiteraryContinuityProjector.meaningfulWords(in: text)
    }
}

enum LiteraryContinuityProjector {
    static func digest(
        days: [BookDay],
        events: [NarrativeEvent],
        entityMemories: [NarrativeEntityMemory],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LiteraryContinuityDigest {
        let pages = days.flatMap(\.pages).sorted { $0.createdAt < $1.createdAt }
        guard !pages.isEmpty || !events.isEmpty || !entityMemories.isEmpty else {
            return .empty
        }
        let lifecycles = beliefLifecycles(
            pages: pages,
            events: events,
            entityMemories: entityMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief
        )
        let signals = patternSignals(pages: pages, events: events, now: now, calendar: calendar)
            + absenceSignals(pages: pages, events: events, now: now, calendar: calendar)
            + durationSignals(pages: pages, lifecycles: lifecycles, now: now, calendar: calendar)
            + lifecycles.prefix(4).map { lifecycleSignal($0, now: now, calendar: calendar) }

        return LiteraryContinuityDigest(
            signals: Array(signals.sorted { left, right in
                if left.strength == right.strength {
                    return left.subjectName < right.subjectName
                }
                return left.strength > right.strength
            }.prefix(16)),
            beliefLifecycles: lifecycles
        )
    }

    static func meaningfulWords(in text: String) -> Set<String> {
        return Set(text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter(isLiteraryCandidate)
        )
    }

    static let stopWords: Set<String> = [
        "about", "after", "again", "almost", "already", "also", "always", "another",
        "around", "because", "been", "before", "being", "between", "book", "both", "came",
        "come", "could", "does", "doing", "done", "down", "during", "each", "even", "every",
        "feel", "feeling", "felt", "first", "from", "going", "gone", "good", "have", "here",
        "into", "just", "kept", "last", "like", "little", "made", "make", "many", "might",
        "more", "most", "much", "never", "next", "only", "other", "over", "page", "pages",
        "really", "same", "should", "small", "some", "something", "still",
        "than", "that", "their", "them", "then", "there", "these", "they", "thing", "things",
        "this", "those", "through", "time", "today", "tomorrow", "tonight", "under", "until",
        "very", "want", "wanted", "week", "well", "went", "were", "what", "when", "where",
        "which", "while", "will", "with", "without", "would", "year", "yesterday", "your", "you",
        "january", "february", "march", "april", "june", "july", "august", "september",
        "october", "november", "december", "monday", "tuesday", "wednesday", "thursday",
        "friday", "saturday", "sunday", "morning", "evening", "night", "afternoon"
    ]

    /// Words can be meaningful to a parser while still being poor literary
    /// subjects. This list keeps the Book from naming scaffolding, generic
    /// motion, and emotional weather so vague it becomes accidental.
    static let weakLiterarySubjects: Set<String> = [
        "able", "above", "actually", "along", "anything", "away", "became", "begin",
        "began", "behind", "better", "blank", "called", "cannot", "change", "changed",
        "chapter", "class", "close", "closed", "climax", "coming", "current", "different",
        "early", "empty", "enough", "face", "fall", "fallen", "falling", "fell", "flat",
        "found", "front", "gave", "given", "gets", "getting", "half", "hard", "having",
        "held", "inside", "kind", "knew", "know", "later", "left", "less", "line",
        "lines", "long", "look", "looked", "looking", "lost", "maybe", "moment",
        "near", "needed", "open", "opened", "outside", "part", "past", "place",
        "point", "quietly", "read", "ready", "right", "room", "said", "saw", "scene",
        "second", "seen", "seems", "self", "side", "started", "story", "sure", "take",
        "taken", "takes", "tell", "thread", "told", "took", "toward", "trying", "turn",
        "turned", "used", "using", "voice", "whole", "work", "world"
    ]

    static func isLiteraryCandidate(_ word: String) -> Bool {
        word.count >= 4
            && !stopWords.contains(word)
            && !weakLiterarySubjects.contains(word)
            && !word.contains(where: \.isNumber)
    }

    /// Words that appear in a large share of all pages are the reader's
    /// ambient vocabulary, not a pattern - "academy" in a play archive,
    /// "meeting" in a work one. The damping is per-reader and automatic.
    /// Small archives skip it, so a young Book can still get excited about
    /// three mentions of the harbor in its first week.
    static let ubiquityMinimumPages = 12
    static let ubiquityCeiling = 0.34

    /// nil means the word is ambient vocabulary and should be no signal at
    /// all; otherwise the penalty scales with how common the word is.
    static func ubiquityPenalty(pageHits: Int, totalPages: Int) -> Int? {
        guard totalPages >= ubiquityMinimumPages else { return 0 }
        let ratio = Double(pageHits) / Double(totalPages)
        guard ratio <= ubiquityCeiling else { return nil }
        return Int(ratio * 60)
    }

    /// Diminishing returns past the first handful of pages, so strength
    /// discriminates between "appears sometimes" and "appears constantly"
    /// instead of every common word pinning the cap.
    static func patternStrength(pageCount: Int, eventBoost: Int, penalty: Int) -> Int {
        let early = 7 * min(pageCount, 5)
        let late = 2 * min(max(pageCount - 5, 0), 12)
        return min(94, max(1, 38 + early + late + eventBoost - penalty))
    }

    private static func patternSignals(
        pages: [BookPage],
        events: [NarrativeEvent],
        now: Date,
        calendar: Calendar
    ) -> [LiteraryContinuitySignal] {
        var buckets: [String: [BookPage]] = [:]
        for page in pages {
            let text = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))"
            for word in meaningfulWords(in: text) {
                buckets[word, default: []].append(page)
            }
        }
        let eventText = events.prefix(80).map { "\($0.summary) \($0.tags.joined(separator: " "))" }.joined(separator: " ")
        let eventWords = meaningfulWords(in: eventText)
        let totalPages = pages.count
        return buckets.compactMap { word, matches in
            let uniquePages = unique(matches)
            guard uniquePages.count >= 3 else { return nil }
            guard let penalty = ubiquityPenalty(pageHits: uniquePages.count, totalPages: totalPages) else { return nil }
            let first = uniquePages.first?.createdAt ?? now
            let last = uniquePages.last?.createdAt ?? now
            let isMovingInEvents = eventWords.contains(word)
            let line = isMovingInEvents
                ? "\(word.capitalized) kept returning in the pages, then recent events picked up the thread."
                : "\(word.capitalized) kept returning through the kept pages."
            return LiteraryContinuitySignal(
                id: "pattern-\(word)",
                kind: .pattern,
                subjectID: word,
                subjectName: word.capitalized,
                line: line,
                evidencePageIDs: uniquePages.prefix(8).map(\.id),
                relatedEntityIDs: [],
                tags: [word, "pattern", "literary-continuity"] + (isMovingInEvents ? ["recent-events"] : []),
                firstSeenAt: first,
                lastSeenAt: last,
                strength: patternStrength(pageCount: uniquePages.count, eventBoost: eventWords.contains(word) ? 10 : 0, penalty: penalty)
            )
        }
    }

    private static func absenceSignals(
        pages: [BookPage],
        events: [NarrativeEvent],
        now: Date,
        calendar: Calendar
    ) -> [LiteraryContinuitySignal] {
        let historyCutoff = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        let olderPages = pages.filter { $0.createdAt < historyCutoff }
        guard olderPages.count >= 3 else { return [] }
        var buckets: [String: [BookPage]] = [:]
        for page in olderPages {
            let text = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))"
            for word in meaningfulWords(in: text) {
                buckets[word, default: []].append(page)
            }
        }
        let recentText = pages
            .filter { $0.createdAt >= historyCutoff }
            .map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }
            .joined(separator: " ")
        let recentWords = meaningfulWords(in: recentText)
        return buckets.compactMap { word, matches in
            let uniquePages = unique(matches)
            guard uniquePages.count >= 3, !recentWords.contains(word), let last = uniquePages.last?.createdAt else {
                return nil
            }
            guard let penalty = ubiquityPenalty(pageHits: uniquePages.count, totalPages: olderPages.count) else { return nil }
            let quietDays = max(21, calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 21)
            return LiteraryContinuitySignal(
                id: "absence-\(word)",
                kind: .absence,
                subjectID: word,
                subjectName: word.capitalized,
                line: "\(word.capitalized) used to appear often; it has been quiet for \(quietDays) days.",
                evidencePageIDs: uniquePages.suffix(6).map(\.id),
                relatedEntityIDs: [],
                tags: [word, "absence", "literary-continuity"],
                firstSeenAt: uniquePages.first?.createdAt ?? last,
                lastSeenAt: last,
                strength: min(94, 34 + uniquePages.count * 7 + min(20, quietDays / 3) - penalty)
            )
        }
    }

    private static func durationSignals(
        pages: [BookPage],
        lifecycles: [BeliefLifecycleProfile],
        now: Date,
        calendar: Calendar
    ) -> [LiteraryContinuitySignal] {
        var signals: [LiteraryContinuitySignal] = []
        if let oldest = pages.first {
            let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: oldest.createdAt), to: calendar.startOfDay(for: now)).day ?? 1)
            if days >= 30 {
                signals.append(LiteraryContinuitySignal(
                    id: "duration-book-\(oldest.id)",
                    kind: .duration,
                    subjectID: "book",
                    subjectName: "The Book",
                    line: "The oldest kept page has been in the Book for \(days) days.",
                    evidencePageIDs: [oldest.id],
                    relatedEntityIDs: [],
                    tags: ["duration", "archive", "literary-continuity"],
                    firstSeenAt: oldest.createdAt,
                    lastSeenAt: now,
                    strength: min(88, 40 + days / 14)
                ))
            }
        }
        for lifecycle in lifecycles.prefix(3) {
            let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: lifecycle.firstSeenAt), to: calendar.startOfDay(for: now)).day ?? 1)
            guard days >= 14 else { continue }
            signals.append(LiteraryContinuitySignal(
                id: "duration-belief-\(lifecycle.id)",
                kind: .duration,
                subjectID: lifecycle.id,
                subjectName: lifecycle.name,
                line: "\(lifecycle.name) has been in the margins for \(days) days.",
                evidencePageIDs: lifecycle.evidencePageIDs,
                relatedEntityIDs: lifecycle.relatedEntityIDs,
                tags: ["duration", "belief", "literary-continuity", lifecycle.id],
                firstSeenAt: lifecycle.firstSeenAt,
                lastSeenAt: lifecycle.lastSeenAt,
                strength: min(90, 36 + days / 10 + lifecycle.pageCount * 3)
            ))
        }
        return signals
    }

    private static func beliefLifecycles(
        pages: [BookPage],
        events: [NarrativeEvent],
        entityMemories: [NarrativeEntityMemory],
        entityBelief: [String: Int],
        pageBelief: [String: Int]
    ) -> [BeliefLifecycleProfile] {
        let entities = NarrativePackRegistry.entities
        var profiles: [BeliefLifecycleProfile] = []

        for entity in entities where entity.kind == .character || entity.kind == .motif || entity.kind == .talisman {
            let pageHits = pages.filter { page in
                let text = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
                return text.contains(entity.id.lowercased()) || text.contains(entity.name.lowercased())
            }
            let eventHits = events.filter { event in
                event.effect.entityWeightDeltas.keys.contains(entity.id)
                    || event.summary.lowercased().contains(entity.name.lowercased())
                    || event.tags.contains(entity.id)
            }
            let memoryHits = entityMemories.filter { $0.entityID == entity.id }
            guard pageHits.count + eventHits.count + memoryHits.count > 0 else { continue }
            let dates = pageHits.map(\.createdAt) + eventHits.map(\.createdAt) + memoryHits.map(\.createdAt)
            profiles.append(BeliefLifecycleProfile(
                id: entity.id,
                name: entity.name,
                currentGlow: max(0, min(100, entity.belief + (entityBelief[entity.id] ?? 0))),
                firstSeenAt: dates.min() ?? Date(),
                lastSeenAt: dates.max() ?? Date(),
                pageCount: pageHits.count,
                eventCount: eventHits.count,
                characterCount: entity.kind == .character ? 1 : 0,
                evidencePageIDs: Array(pageHits.prefix(8).map(\.id)),
                relatedEntityIDs: [entity.id]
            ))
        }

        for profile in BookPageSourceRegistry.beliefProfiles(ledger: pageBelief) {
            let pageHits = pages.filter { $0.sourceID == profile.sourceID || $0.type == profile.type }
            let eventHits = events.filter { $0.sourcePageType == profile.type || $0.tags.contains(profile.sourceID) }
            guard pageHits.count + eventHits.count > 0 else { continue }
            let dates = pageHits.map(\.createdAt) + eventHits.map(\.createdAt)
            profiles.append(BeliefLifecycleProfile(
                id: profile.sourceID,
                name: profile.title,
                currentGlow: profile.belief,
                firstSeenAt: dates.min() ?? Date(),
                lastSeenAt: dates.max() ?? Date(),
                pageCount: pageHits.count,
                eventCount: eventHits.count,
                characterCount: 0,
                evidencePageIDs: Array(pageHits.prefix(8).map(\.id)),
                relatedEntityIDs: []
            ))
        }

        return profiles.sorted { left, right in
            let leftScore = left.pageCount * 8 + left.eventCount * 5 + left.currentGlow
            let rightScore = right.pageCount * 8 + right.eventCount * 5 + right.currentGlow
            if leftScore == rightScore {
                return left.name < right.name
            }
            return leftScore > rightScore
        }
    }

    private static func lifecycleSignal(
        _ lifecycle: BeliefLifecycleProfile,
        now: Date,
        calendar: Calendar
    ) -> LiteraryContinuitySignal {
        let appearances = lifecycle.pageCount == 1 ? "one kept page" : "\(lifecycle.pageCount) kept pages"
        return LiteraryContinuitySignal(
            id: "belief-lifecycle-\(lifecycle.id)",
            kind: .beliefLifecycle,
            subjectID: lifecycle.id,
            subjectName: lifecycle.name,
            line: "\(lifecycle.name) has become a living thread: \(appearances), \(lifecycle.eventCount) events, current Glow \(lifecycle.currentGlow).",
            evidencePageIDs: lifecycle.evidencePageIDs,
            relatedEntityIDs: lifecycle.relatedEntityIDs,
            tags: ["belief", "lifecycle", "literary-continuity", lifecycle.id],
            firstSeenAt: lifecycle.firstSeenAt,
            lastSeenAt: lifecycle.lastSeenAt,
            strength: min(96, 32 + lifecycle.currentGlow / 2 + lifecycle.pageCount * 4 + lifecycle.eventCount * 2)
        )
    }

    private static func unique(_ pages: [BookPage]) -> [BookPage] {
        var seen: Set<String> = []
        return pages.filter { page in
            if seen.contains(page.id) { return false }
            seen.insert(page.id)
            return true
        }
    }
}

// MARK: - Themes
//
// A theme is the month's weather system: two or three motifs that kept
// gathering until they deserve a shared name. Themes are discovered from
// kept pages and the continuity digest, remembered across months, and used
// as chapter subtitles, theme pages, and margin material. Like everything
// else in the Book, a theme is a literary observation, never a verdict.

struct BookTheme: Identifiable, Codable, Equatable {
    var id: String
    var monthKey: String
    var name: String
    var motifs: [String]
    var line: String
    var strength: Int
    var evidencePageIDs: [String]
    var excerptLines: [String]
    var discoveredAt: Date

    var promptLine: String {
        "This month's theme: \(name). \(line)"
    }
}

enum BookThemeEngine {
    /// Words too structural to be a theme, on top of the continuity stop list.
    private static let themeStop: Set<String> = [
        "today", "yesterday", "tomorrow", "morning", "evening", "night",
        "really", "very", "little", "small", "around", "still", "going",
        "started", "finished", "thing", "things", "while", "after", "before",
        "first", "last", "back", "down", "over", "made", "make", "want",
        "wanted", "good", "nice", "time", "felt", "feel", "feeling", "went"
    ]

    /// Discovers the theme of a span of days. Deterministic for the same
    /// pages, digest, and month key.
    static func theme(
        for pages: [BookPage],
        digest: LiteraryContinuityDigest,
        constellations: [Constellation] = [],
        monthKey: String,
        now: Date = Date()
    ) -> BookTheme? {
        var weights: [String: Int] = [:]
        var evidence: [String: [String]] = [:]

        for page in pages {
            let text = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))"
            for word in LiteraryContinuityProjector.meaningfulWords(in: text) where !themeStop.contains(word) {
                weights[word, default: 0] += 2
                if evidence[word, default: []].count < 8, !evidence[word, default: []].contains(page.id) {
                    evidence[word, default: []].append(page.id)
                }
            }
        }
        // Ambient vocabulary makes a dull theme; drop words on most pages.
        for (word, hits) in evidence where LiteraryContinuityProjector.ubiquityPenalty(pageHits: hits.count, totalPages: pages.count) == nil {
            weights.removeValue(forKey: word)
        }
        for signal in digest.signals {
            let subject = signal.subjectID.lowercased()
            guard !themeStop.contains(subject), subject.count >= 4 else { continue }
            weights[subject, default: 0] += signal.strength / 10
        }
        for constellation in constellations where constellation.isAlive {
            let subject = constellation.subjectID.lowercased()
            guard !themeStop.contains(subject), subject.count >= 4 else { continue }
            weights[subject, default: 0] += 6
        }

        let ranked = weights
            .filter { $0.value >= 4 && evidence[$0.key, default: []].count >= 2 }
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
        guard ranked.count >= 2 else { return nil }

        let motifs = Array(ranked.prefix(3).map(\.key))
        let primary = motifs[0]
        let secondary = motifs[1]
        let name = themeName(primary: primary, secondary: secondary, seed: "\(monthKey)-\(primary)-\(secondary)")
        let strength = min(100, ranked[0].1 * 3 + ranked[1].1 * 2)
        let evidenceIDs = Array(Set(motifs.flatMap { evidence[$0] ?? [] })).sorted()
        let excerpts = excerptLines(for: motifs, in: pages)

        return BookTheme(
            id: "theme-\(monthKey)",
            monthKey: monthKey,
            name: name,
            motifs: motifs,
            line: themeLine(motifs: motifs, seed: "\(monthKey)-line"),
            strength: strength,
            evidencePageIDs: evidenceIDs,
            excerptLines: excerpts,
            discoveredAt: now
        )
    }

    /// Upserts the current month's theme into the remembered ledger. Old
    /// months keep their themes forever; only the live month is rewritten.
    static func remembered(
        _ existing: [BookTheme],
        observing current: BookTheme?,
        monthKey: String
    ) -> [BookTheme] {
        var kept = existing.filter { $0.monthKey != monthKey }
        if let current {
            kept.append(current)
        }
        return kept.sorted { $0.monthKey < $1.monthKey }
    }

    static func theme(forMonth monthKey: String, in themes: [BookTheme]) -> BookTheme? {
        themes.first { $0.monthKey == monthKey }
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    /// "Secrets and Harbors" - two motifs joined by a deterministic pattern.
    static func themeName(primary: String, secondary: String, seed: String) -> String {
        let first = poeticized(primary)
        let second = poeticized(secondary)
        let patterns = [
            "%@ and %@",
            "%@ and %@",
            "Of %@ and %@",
            "%@, Then %@",
            "What %@ Said to %@"
        ]
        let pattern = patterns[ConstellationKeeper.stableIndex(for: "\(seed)-pattern", count: patterns.count)]
        return String(format: pattern, first, second)
    }

    private static func themeLine(motifs: [String], seed: String) -> String {
        let listed: String
        switch motifs.count {
        case 0, 1:
            listed = motifs.first.map(poeticized) ?? "the ordinary"
        case 2:
            listed = "\(poeticized(motifs[0])) and \(poeticized(motifs[1]))"
        default:
            listed = "\(poeticized(motifs[0])), \(poeticized(motifs[1])), and \(poeticized(motifs[2]))"
        }
        let templates = [
            "The pages kept returning to %@, the way a reader rereads a favorite paragraph without deciding to.",
            "%@ ran under the month like a watermark - visible whenever a page was held up to the light.",
            "If this month were a chapter, its running heads would say %@.",
            "The margins filled with %@ before anyone thought to call it a theme."
        ]
        let template = templates[ConstellationKeeper.stableIndex(for: seed, count: templates.count)]
        return String(format: template, listed)
    }

    private static func poeticized(_ word: String) -> String {
        word.prefix(1).uppercased() + word.dropFirst()
    }

    private static func excerptLines(for motifs: [String], in pages: [BookPage]) -> [String] {
        var excerpts: [String] = []
        for motif in motifs {
            guard let page = pages.first(where: { page in
                page.userInput.lowercased().contains(motif) && page.userInput.count >= 16
            }) else { continue }
            var line = page.userInput.bookPreviewSentenceLimit(1).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.count > 110 {
                line = String(line.prefix(107)) + "..."
            }
            if !excerpts.contains(line) {
                excerpts.append(line)
            }
            if excerpts.count >= 3 { break }
        }
        return excerpts
    }
}
