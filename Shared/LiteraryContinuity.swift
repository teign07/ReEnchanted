import Foundation

// MARK: - The Book's Own Voice

/// The voice the reader hears whenever the Book narrates or speaks as itself:
/// child-like animism, never childish. Simple, vulnerable, surprising sentences
/// that give ordinary things little feelings and wants. Cast members keep
/// their own voices — this block belongs only to the narration and the Book.
enum BookVoice {
    /// The full block, for prompt instructions with room to breathe.
    static let animism = """
    THE BOOK'S OWN VOICE — child-like animism, never childish:
    - Simple, surprising sentences. Everyday words carrying real feeling: "the kettle sulked," not "the vessel brooded."
    - Give objects, rooms, weather, and pages little feelings and wants, the way a child imagines their toys are awake — playful, tender, never twee.
    - Be a little vulnerable: the Book may admit wanting, wondering, or not knowing. The wonder is sincere, never performed.
    - Wise underneath. No baby talk, no gushing, no exclamation-mark enthusiasm, no cutesy diminutives.
    - Named characters keep their own voices when they speak; this voice belongs to the narration and the Book alone.
    """

    /// One line, for tight prompts where every token counts.
    static let animismLine = "Write the narration in the Book's own voice — child-like animism, never childish: simple, surprising sentences; everyday words; little feelings and wants given to ordinary things; sincere wonder, a little vulnerable, wise underneath. Named characters keep their own voices when they speak."
}

enum LiterarySignalKind: String, Codable, Equatable, CaseIterable {
    case pattern
    case beliefLifecycle
    case absence
    case duration
    case listening
    /// Not what the pages say but how — pace, hour, hedging. The class of
    /// observation only someone who has read all of you could make.
    case manner
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
        var readerLexicon: ReaderLexicon = ReaderLexicon()
        var readerLearningPromptLines: [String] = []
        var memoryDigest: BindingMemoryDigest = .empty
        var semanticEchoSourceIDs: [String] = []
        var semanticEchoLines: [String] = []
        var meaningfulSpinePassages: [MeaningfulPassageSelector.Selection] = []
        var souvenirAnchor: SouvenirAnchor?

        static let empty = Context()
    }

    struct SouvenirAnchor: Equatable {
        var pageID: String
        var pageTitle: String
        var keptText: String
        var keptAt: Date
        var reason: String
        var score: Int
    }

    static func context(
        for day: BookDay,
        days: [BookDay],
        themes: [BookTheme] = [],
        entityBeliefOffsets: [String: Int] = [:],
        learnedNotes: [String] = [],
        nowPlaying: String? = nil,
        activeWorldEvents: [ResolvedWorldEvent] = [],
        readerLexicon: ReaderLexicon = ReaderLexicon(),
        readerLearning: ReaderLearningModel = ReaderLearningModel(),
        semanticScorer: StacksSemanticScoring? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Context {
        let recentBraids = recentBraidTexts(excludingDayID: day.id, days: days)
        let memoryDigest = BindingMemorySpine.digest(
            days: days.filter { $0.id != day.id },
            now: now,
            limit: 6
        )
        let semanticEchoes = semanticEchoes(in: day)
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
        var passageInputs = BookSourceInputs.empty
        passageInputs.days = days
        passageInputs.themes = themes
        let spineQuery = ([
            theme?.name ?? "",
            theme?.line ?? "",
            chapter?.name ?? "",
            chapter?.philosophy ?? ""
        ] + day.capturedPages.flatMap { page in
            [page.promptText, page.tags.joined(separator: " "), page.resolvedAttentionFingerprint.patternTokens.joined(separator: " ")]
        } + semanticEchoes.lines).filter { !$0.isEmpty }.joined(separator: ". ")
        let meaningfulSpinePassages = MeaningfulPassageSelector.rankedSelections(
            pages: day.capturedPages,
            query: spineQuery,
            inputs: passageInputs,
            scorer: semanticScorer,
            limit: 3,
            maximumAge: 3 * 86_400,
            minimumScore: 14,
            honorPriorUse: false,
            diversifyPageTypes: true,
            now: now
        )

        return Context(
            recentBraids: recentBraids,
            theme: theme,
            chapter: chapter,
            learnedGuidance: merged.signals.isEmpty ? nil : merged,
            nowPlaying: nowPlaying,
            activeWorldEvents: activeWorldEvents,
            readerLexicon: readerLexicon,
            readerLearningPromptLines: readerLearning.promptLines(now: now),
            memoryDigest: memoryDigest,
            semanticEchoSourceIDs: semanticEchoes.sourceIDs,
            semanticEchoLines: semanticEchoes.lines,
            meaningfulSpinePassages: meaningfulSpinePassages,
            souvenirAnchor: souvenirAnchor(in: day)
        )
    }

    static func souvenirAnchor(in day: BookDay) -> SouvenirAnchor? {
        day.capturedPages
            .compactMap(souvenirAnchorCandidate)
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.keptAt > rhs.keptAt
                }
                return lhs.score > rhs.score
            }
            .first
    }

    private static func souvenirAnchorCandidate(for page: BookPage) -> SouvenirAnchor? {
        let text = souvenirText(for: page)
        guard !text.isEmpty else { return nil }

        let lowerPrompt = page.promptText.lowercased()
        let lowerSource = page.sourceID.lowercased()
        let lowerTags = Set(page.tags.map { $0.lowercased() })
        let isExplicitSouvenir = page.type == .souvenir
            || lowerSource == "one-sentence-souvenir"
            || lowerTags.contains("one-sentence-souvenir")
            || lowerTags.contains("souvenir")
            || lowerTags.contains("first-run-souvenir")
            || lowerTags.contains("onboarding-first-souvenir")
        let promptAsksForSentence = lowerPrompt.contains("one sentence")
            || lowerPrompt.contains("one-sentence")
            || lowerPrompt.contains("one true")
            || lowerPrompt.contains("souvenir")
        guard isExplicitSouvenir || promptAsksForSentence else { return nil }

        var score = 0
        switch page.origin {
        case .userAuthored, .imported:
            score += 40
        case .generated, .simulated:
            score += 10
        }
        if page.type == .souvenir { score += 100 }
        if lowerTags.contains("one-sentence-souvenir") { score += 90 }
        if lowerSource == "one-sentence-souvenir" { score += 80 }
        if lowerTags.contains("first-run-souvenir") || lowerTags.contains("onboarding-first-souvenir") { score += 60 }
        if lowerTags.contains("souvenir") { score += 45 }
        if lowerPrompt.contains("one sentence") || lowerPrompt.contains("one-sentence") || lowerPrompt.contains("one true") { score += 35 }
        if lowerPrompt.contains("souvenir") { score += 20 }
        if looksLikeOneSentence(text) { score += 25 }
        if (20...180).contains(text.count) { score += 10 }

        return SouvenirAnchor(
            pageID: page.id,
            pageTitle: page.type.title,
            keptText: clippedText(text, limit: 220),
            keptAt: page.createdAt,
            reason: souvenirReason(for: page, tags: lowerTags, promptAsksForSentence: promptAsksForSentence),
            score: score
        )
    }

    private static func souvenirText(for page: BookPage) -> String {
        let primary = page.userInput.nonEmpty ?? page.playerReply.nonEmpty ?? ""
        return clippedText(primary, limit: 260)
    }

    private static func looksLikeOneSentence(_ text: String) -> Bool {
        let words = text.split { $0.isWhitespace }.count
        guard (3...36).contains(words) else { return false }
        let sentenceBreaks = text.filter { ".!?".contains($0) }.count
        return sentenceBreaks <= 2
    }

    private static func souvenirReason(for page: BookPage, tags: Set<String>, promptAsksForSentence: Bool) -> String {
        if page.type == .souvenir {
            return "explicit One-Sentence Souvenir"
        }
        if tags.contains("one-sentence-souvenir") {
            return "one-sentence souvenir kept from another page"
        }
        if tags.contains("first-run-souvenir") || tags.contains("onboarding-first-souvenir") {
            return "first souvenir the Book learned from the reader"
        }
        if promptAsksForSentence {
            return "this page asked the reader for one true sentence"
        }
        return "reader-authored souvenir signal"
    }

    static func semanticEchoes(in day: BookDay) -> (sourceIDs: [String], lines: [String]) {
        let tags = day.capturedPages.flatMap(\.tags)
        return (
            uniqueTagValues(withPrefix: SemanticKeepEcho.sourceTagPrefix, in: tags),
            uniqueTagValues(withPrefix: SemanticKeepEcho.lineTagPrefix, in: tags)
        )
    }

    private static func uniqueTagValues(withPrefix prefix: String, in tags: [String]) -> [String] {
        var seen: Set<String> = []
        var values: [String] = []
        for tag in tags where tag.hasPrefix(prefix) {
            let value = String(tag.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            values.append(value)
        }
        return values
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
        let souvenirSection = souvenirSpineSection(for: day, context: context)
        let meaningfulSpineSection = meaningfulSpineSection(context: context)
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

        let readerLearningSection: String
        if !context.readerLearningPromptLines.isEmpty {
            readerLearningSection = """


            LEARNED READER CONTEXT:
            \(context.readerLearningPromptLines.prefix(4).map { "- \($0)" }.joined(separator: "\n"))

            READER-LEARNING RULE:
            - These lines describe how prior pages met the reader. Use them only to choose emphasis, pacing, and restraint.
            - Never invent facts from them. Today's kept pages remain the material.
            - If a line says something is cooling or resting, do less of it unless today's kept pages clearly ask for it.
            """
        } else {
            readerLearningSection = ""
        }

        let memorySpineSection: String
        if context.memoryDigest.braids.isEmpty {
            memorySpineSection = ""
        } else {
            let motifLine = context.memoryDigest.motifCounts.isEmpty
                ? "none yet"
                : context.memoryDigest.motifCounts
                    .prefix(6)
                    .map { "\($0.motif) x\($0.count)" }
                    .joined(separator: ", ")
            let braidLines = context.memoryDigest.braids.prefix(3).map { memory in
                let callback = memory.residue.callbackCandidate ?? memory.residue.keptLine
                return "- \(memory.residue.title): \(callback)"
            }.joined(separator: "\n")
            let strongestCallback = context.memoryDigest.strongestCallback.map {
                "\nStrongest fresh callback: \($0)"
            } ?? ""
            memorySpineSection = """


            BOOK MEMORY SPINE:
            Recurring braid motifs: \(motifLine)
            Recent braid residue:
            \(braidLines)\(strongestCallback)

            MEMORY-SPINE RULE:
            - You may let one prior residue return only if today's kept pages honestly answer it.
            - If it returns, change it with today's evidence; never simply repeat the old image.
            - Treat these as callbacks, not source material. Today's kept pages still own the braid.
            """
        }

        let semanticEchoSection: String
        if context.semanticEchoLines.isEmpty {
            semanticEchoSection = ""
        } else {
            semanticEchoSection = """


            SEMANTIC ECHOES FROM TODAY:
            \(context.semanticEchoLines.prefix(3).map { "- \($0)" }.joined(separator: "\n"))

            SEMANTIC-ECHO RULE:
            - A semantic echo means today's page answered an older page by feeling, not by repeating words.
            - You may let that answered feeling become part of the spine only if today's kept pages support it.
            - Do not quote the older page unless the echo line already does.
            """
        }

        let clashSection: String
        if day.capturedPages.contains(where: { $0.tags.contains("clash") }) {
            clashSection = """


            WHERE BELIEF WAS TESTED:
            - Today holds a clash page: the reader defended something against being made generic. Unless a lived page holds something even more personally true, let the clash be the braid's "Until" - the turn of the day.
            - Name what was protected in concrete words. Never recap it as a battle report; never quote rolls, numbers, or mechanics.
            - Frame the outcome by its digest: a bright success is restored agency; a costly success is saved-but-not-easy; a complication is unfinished business the Book keeps warm; standing down is wisdom - a lamp saved for tomorrow. Never shame a retreat.
            - Leave one clause of residue open (a title still missing, a seal still warm, a word the grey now knows you defend) so tomorrow's pages have something to pick up.
            """
        } else {
            clashSection = ""
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
        - Write the braid in second-person past tense: "you walked", "you kept", "the lamp waited". Do not write second-person present tense ("you walk", "you keep").
        - The first line may be a bare title, 2 to 7 words, if a true one arrives. Do not prefix it with "Title:".
        - Follow the day's real clock: the kept pages are timestamped - let morning be morning and evening be evening.
        - Give the braid old tale bones under modern room-light: Once, Because, Until, And so, Kept.
        - The "Once" is where the day truly began. The "Because" is the real pressure or hunger gathering. The "Until" is the turn, and it must be something that actually happened, not a mood shift. The "And so" is the small change left behind.
        - Make it feel narrated, not listed. Do not mention page types like "Weather Page" or "Lore Page" unless the player wrote those words.
        - End with one closing sentence that begins: "The Book kept the page:"
        - Let that final line loop back to the spine: carry one concrete thing from how the day began into how it is kept, so the page closes the circle it opened.
        - On a phone, the braid should feel like a full page of the Book without becoming a scroll chore.

        TWO SHELVES:
        - Each kept page names its shelf. Lived pages are the reader's own record: souvenirs, fuel and body logs, inner weather, playful missions, photos, imported real-world signals. Fiction pages are the Book's side of the day: letters, Story Page scenes and decisions, fae bargains and parleys, classes, gossip.
        - Build the braid from both shelves in roughly equal measure: about half the page from what the reader lived, about half from what the story did with it. Never let either shelf drown the other.
        - One-Sentence Souvenirs remain the strongest single spine candidates, because they are the reader choosing one true line.
        - A fiction page where the reader made a real decision - a chosen Story Page path, a paid bargain, an answered parley - is reader-endorsed: it may carry the spine when the day's truest turn happened there.
        - When the shelves disagree about facts, the lived shelf wins. The fiction may color the real; it may never overwrite it.
        \(souvenirSection)\(meaningfulSpineSection)

        VOICE:
        \(BookVoice.animism)
        - Write with varied literary cadence: some sentences should be short, plain, and surprising; others may be longer and more flowing, turning through image and thought before they land.
        - Use everyday words carrying real feeling: "the kettle sulked," not "the vessel brooded." Intimate but not sentimental, concrete before abstract.
        - The Book may be a little vulnerable: it can admit wanting, wondering, or not knowing. Its wonder is sincere, never performed, and wise underneath.
        - Bring faerie pressure through ordinary objects: cups, keys, chargers, coats, dishes, windows, receipts, weather, doorways. Never make the day fake-grand.
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
        - For the nightly Book of You braid, prefer "you" as the lens and keep the day already lived: second-person, past tense.

        ANTI-PARROT RULE:
        - Do not copy any supplied sentence longer than seven words.
        - Paraphrase the kept pages into a coherent story.
        - You may quote one short phrase only if it has unusual power.
        - Mention each motif, image, sentence idea, or emotional beat only once.
        - Do not restate the same idea in consecutive paragraphs with swapped words.
        - Prefer one fresh concrete detail over a second sentence explaining the same mood, object, weather, relationship, or threshold.

        KEPT PAGES FROM TODAY:
        \(evidence.isEmpty ? "- No kept pages yet. Write a quiet note about the Book waiting for the day to gather." : evidence)\(clashSection)\(themeSection)\(chapterSection)\(learnedSection)\(readerLearningSection)\(memorySpineSection)\(semanticEchoSection)\(RadioAtmosphere.promptSection(context.nowPlaying))\(context.activeWorldEvents.bookOfYouPromptSection)\(context.readerLexicon.languageLawSection())\(continuity)
        """
    }

    private static func souvenirSpineSection(for day: BookDay, context: Context) -> String {
        guard let anchor = context.souvenirAnchor ?? souvenirAnchor(in: day) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return """

        SOUVENIR SPINE (required):
        The reader's carried sentence for tonight is from \(anchor.pageTitle), kept at \(formatter.string(from: anchor.keptAt)): "\(anchor.keptText)"
        Why it matters: \(anchor.reason).

        SOUVENIR RULE:
        - This sentence, or the concrete thing inside it, must be visible in the braid's opening, must affect the "Until" turn or the thing that changes, and must return transformed in "The Book kept the page:".
        - Do not paste the full sentence back. Carry its image, object, action, or pressure through the braid so the reader can feel the Book read it.
        - If fiction pages are vivid, braid them around this sentence rather than away from it.
        """
    }

    private static func meaningfulSpineSection(context: Context) -> String {
        guard !context.meaningfulSpinePassages.isEmpty else { return "" }
        let passages = context.meaningfulSpinePassages.enumerated().map { index, selection in
            "\(index + 1). \(selection.pageType.shortTitle): “\(selection.excerpt)” (\(selection.reason))"
        }.joined(separator: "\n")
        return """


        MEANINGFUL PASSAGE COMPASS:
        \(passages)

        PASSAGE-COMPASS RULE:
        - These are the day's most relevant, specific reader-authored passages, selected from inside the keeps rather than from their openings.
        - Choose one as the braid's main hinge unless the required Souvenir Spine is stronger; the others may support it, but do not force them all into the prose.
        - The complete kept-page evidence below still governs the facts and the day's clock. This compass chooses emphasis; it does not erase the other pages.
        - Quote at most one short phrase and never mention selection, scoring, embeddings, or an archive.
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
                let clashDigest: String
                if page.tags.contains("clash") {
                    let kind = page.tags.first { $0.hasPrefix("clash:") }?.replacingOccurrences(of: "clash:", with: "") ?? "clash"
                    let outcome = page.tags.first { $0.hasPrefix("clash-outcome:") }?.replacingOccurrences(of: "clash-outcome:", with: "") ?? "unrolled"
                    let choice = page.tags.first { $0.hasPrefix("choice:") }?.replacingOccurrences(of: "choice:", with: "") ?? "none"
                    clashDigest = "\nClash digest: Belief was tested (\(kind)); the reader chose the \(choice) path; outcome \(outcome)."
                } else {
                    clashDigest = ""
                }
                return """
                \(index + 1). \(page.type.title) - kept at \(timeFormatter.string(from: page.createdAt))
                Shelf: \(braidShelf(for: page))
                Thread gravity: \(threadGravity(for: page))
                Prompt: \(prompt.isEmpty ? "none" : prompt)
                Kept text: \(text.isEmpty ? "(blank)" : text)
                Reader reply: \(reply.isEmpty ? "none" : reply)
                Visual evidence: \(media.isEmpty ? "none" : media)
                Tags: \(tags)\(clashDigest)
                """
            }
    }

    /// Which shelf a kept page sits on: the reader's own record, or the Book's
    /// fiction. Deterministic so the braid never has to guess provenance.
    static func braidShelf(for page: BookPage) -> String {
        switch page.origin {
        case .userAuthored, .imported:
            return "lived"
        case .generated, .simulated:
            return "fiction"
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
                return "reader-endorsed fiction; high gravity - the reader made a real decision here"
            }
            return "generated fiction color; medium gravity"
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
                case .audioFile:
                    kind = "kept voice recording"
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
    static let headerPrefix = "Tags:"

    var title: String
    var body: String
    var themeName: String?
    var chapterName: String?
    var residue: BookOfYouResidue?
    /// The morning callback naming the threads last night's ember promised, shown
    /// as a small kicker above the braid so the reveal pays off the evening tease.
    var promiseEcho: String?

    static let promiseEchoTagPrefix = "promise-echo:"

    struct HeaderContext: Equatable {
        var timeLabel: String
        var locationLabel: String
        var weatherWord: String
        var moonPhaseName: String
        var fuelLabel: String
        var innerWeatherLabel: String

        var displayLine: String {
            "\(BraidPageDetails.headerPrefix) Time \(timeLabel) · Location \(locationLabel) · Weather \(weatherWord) · Moon \(moonPhaseName) · Fuel \(fuelLabel) · Inner weather \(innerWeatherLabel)"
        }

        var metadataTags: [String] {
            [
                "braid-time:\(timeLabel)",
                "braid-location:\(locationLabel)",
                "braid-weather:\(weatherWord)",
                "braid-moon:\(moonPhaseName)",
                "braid-fuel:\(fuelLabel)",
                "braid-inner-weather:\(innerWeatherLabel)"
            ]
        }

        static func make(for page: BookPage, day: BookDay, inputs: BookSourceInputs, calendar: Calendar = .current) -> HeaderContext {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "h:mm a"

            return HeaderContext(
                timeLabel: formatter.string(from: page.createdAt),
                locationLabel: locationLabel(from: inputs),
                weatherWord: weatherWord(from: inputs, day: day),
                moonPhaseName: MoonPhaseCalendar.phase(on: page.createdAt).name,
                fuelLabel: fuelLabel(from: inputs, day: day),
                innerWeatherLabel: innerWeatherLabel(from: inputs, day: day)
            )
        }

        private static func locationLabel(from inputs: BookSourceInputs) -> String {
            if let currentLocationLabel = inputs.currentLocationLabel?.nonEmpty {
                return currentLocationLabel
            }
            if let anchorName = inputs.nearbyAnchor?.anchor.name.nonEmpty {
                return anchorName
            }
            return "Current place"
        }

        private static func weatherWord(from inputs: BookSourceInputs, day: BookDay) -> String {
            if let selector = inputs.enchantedWeather?.selector.nonEmpty {
                return selector
            }
            guard let phrase = inputs.weather?.phrase.nonEmpty else {
                return day.capturedPages
                    .sorted(by: { $0.createdAt > $1.createdAt })
                    .compactMap(\.context)
                    .flatMap(\.weatherTags)
                    .first?.nonEmpty ?? "not recorded"
            }
            let lowered = phrase.lowercased()
            let candidates = [
                "thunder", "storm", "snow", "sleet", "ice", "rain", "drizzle", "shower",
                "fog", "mist", "haze", "wind", "breeze", "cloud", "overcast", "clear",
                "sun", "bright", "cold", "warm", "humid"
            ]
            return candidates.first(where: { lowered.contains($0) }) ?? phrase
                .split { !$0.isLetter }
                .first
                .map { String($0).lowercased() } ?? "not recorded"
        }

        private static func fuelLabel(from inputs: BookSourceInputs, day: BookDay) -> String {
            if let latestFuel = inputs.facultyEntries
                .filter({ $0.kind == .fuel && $0.dayID == day.id })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first,
               let nutrition = nutritionLine(from: latestFuel.rawText) {
                return nutrition
            }

            let nutritionMetrics = nutritionMetrics(from: inputs.body?.metrics ?? [])
            if !nutritionMetrics.isEmpty {
                return nutritionMetrics.joined(separator: ", ")
            }

            return "not logged"
        }

        private static func innerWeatherLabel(from inputs: BookSourceInputs, day: BookDay) -> String {
            if let latestEntry = inputs.facultyEntries
                .filter({ $0.kind == .innerWeather && $0.dayID == day.id })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first {
                return clippedHeaderValue(latestEntry.rawText)
            }

            if let latestMood = day.pages
                .filter({ $0.type == .mood })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first,
               let text = latestMood.userInput.nonEmpty ?? latestMood.playerReply.nonEmpty {
                return clippedHeaderValue(text)
            }

            return "not logged"
        }

        private static func nutritionLine(from rawText: String) -> String? {
            rawText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { line in
                    let lower = line.lowercased()
                    return lower.contains("kcal") || lower.contains("protein") || lower.contains("carb")
                }
                .map { line in
                    line
                        .replacingOccurrences(of: " (Vellum's rough arithmetic)", with: "")
                        .replacingOccurrences(of: "Vellum's rough arithmetic", with: "")
                        .replacingOccurrences(of: "Vellum's Ledger: ", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .flatMap(\.nonEmpty)
        }

        private static func nutritionMetrics(from metrics: [BodySourceSignal.Metric]) -> [String] {
            let ids = Set([
                "dietaryEnergyConsumed",
                "dietaryProtein",
                "dietaryCarbohydrates",
                "dietaryFatTotal",
                "dietaryFatSaturated",
                "dietarySugar",
                "dietaryFiber",
                "dietarySodium",
                "dietaryWater"
            ])
            return metrics
                .filter { metric in
                    ids.contains(metric.id) || metric.label.localizedCaseInsensitiveContains("Dietary")
                }
                .map(\.displayText)
                .filter { !$0.isEmpty }
        }

        private static func clippedHeaderValue(_ value: String, limit: Int = 80) -> String {
            let normalized = value
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .first ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.count > limit else { return normalized }
            let end = normalized.index(normalized.startIndex, offsetBy: limit)
            return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
    }

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
            chapterName: tagValue(prefix: "chapter:", in: page.tags),
            residue: BookOfYouResidue.fromTags(in: page),
            promiseEcho: tagValue(prefix: promiseEchoTagPrefix, in: page.tags)
        )
    }

    /// Stamps the evening ember's kept-promise callback onto a freshly braided
    /// page (via a value-carrying tag, like `theme:`/`chapter:`). A no-op when the
    /// day had no promised threads.
    static func withPromiseEcho(_ page: BookPage, line: String?) -> BookPage {
        guard let line = line?.nonEmpty else { return page }
        var updated = page
        var tags = Set(updated.tags)
        tags = tags.filter { !$0.hasPrefix(promiseEchoTagPrefix) }
        tags.insert("\(promiseEchoTagPrefix)\(line)")
        updated.tags = tags.sorted()
        return updated
    }

    static func annotated(_ page: BookPage, context: BraidPromptBuilder.Context, headerContext: HeaderContext? = nil) -> BookPage {
        var updated = page
        let details = details(for: page)
        if details.title != "Book of You" {
            updated.promptText = "Book of You: \(details.title)"
        }
        updated.promptVersion = promptVersion
        if let headerContext {
            updated.userInput = addingHeader(headerContext.displayLine, to: updated.userInput)
        }

        var tags = Set(updated.tags)
        tags.insert("braid-v2")
        if let headerContext {
            tags = tags.filter {
                !$0.hasPrefix("braid-time:")
                    && !$0.hasPrefix("braid-location:")
                    && !$0.hasPrefix("braid-weather:")
                    && !$0.hasPrefix("braid-moon:")
                    && !$0.hasPrefix("braid-fuel:")
                    && !$0.hasPrefix("braid-inner-weather:")
            }
            headerContext.metadataTags.forEach { tags.insert($0) }
        }
        if let theme = context.theme?.name, !theme.isEmpty {
            tags.insert("theme:\(theme)")
        }
        if let chapter = context.chapter?.name, !chapter.isEmpty {
            tags.insert("chapter:\(chapter)")
        }
        if !context.recentBraids.isEmpty {
            tags.insert("yesterday-echo")
        }
        let residue = BookOfYouResidue.extract(from: updated, context: context)
        tags = residue.stamping(into: tags)
        updated.tags = tags.sorted()
        return updated
    }

    private static func parseTitleAndBody(from text: String) -> (title: String?, body: String) {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let header = paragraphs.first(where: isHeaderLine)
        let titleCandidates = paragraphs.filter { !isHeaderLine($0) }
        guard let first = titleCandidates.first, looksLikeTitle(first) else {
            return (nil, text)
        }
        let bodyParagraphs = paragraphs.filter { $0 != first }
        let body = bodyParagraphs.joined(separator: "\n\n")
        if body.isEmpty, let header {
            return (first, header)
        }
        return (first, body)
    }

    private static func addingHeader(_ header: String, to text: String) -> String {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isHeaderLine($0) }
        return ([header] + paragraphs).joined(separator: "\n\n")
    }

    private static func isHeaderLine(_ value: String) -> Bool {
        value.hasPrefix(headerPrefix)
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

/// Stable handles left behind by a Book of You page so weekly, monthly, and
/// annual bindings can read the braid as memory instead of plain text. The tags
/// are deliberately compact because `BookPage` persists tags, not page metadata.
struct BookOfYouResidue: Equatable {
    static let markerTag = "braid-residue"
    static let titlePrefix = "residue-title:"
    static let spinePrefix = "residue-spine:"
    static let keptPrefix = "residue-kept:"
    static let motifPrefix = "residue-motif:"
    static let questionPrefix = "residue-question:"
    static let callbackPrefix = "residue-callback:"
    static let semanticEchoPrefix = "residue-echo:"

    var title: String
    var spineLine: String
    var keptLine: String
    var motifs: [String]
    var semanticEchoIDs: [String]
    var openedQuestion: String?
    var callbackCandidate: String?

    static func extract(from page: BookPage, context: BraidPromptBuilder.Context = .empty) -> BookOfYouResidue {
        let details = BraidPageDetails.details(for: page)
        let title = clipped(details.title, limit: 64)
        let paragraphs = normalizedParagraphs(from: details.body)
        let keptLine = paragraphs
            .flatMap(sentences)
            .last { $0.hasPrefix("The Book kept the page:") }
            .map { clipped($0, limit: 140) }
            ?? clipped(paragraphs.last ?? details.body, limit: 140)
        let spineLine = paragraphs
            .flatMap(sentences)
            .first { !$0.hasPrefix("The Book kept the page:") }
            .map { clipped($0, limit: 140) }
            ?? keptLine
        let question = paragraphs
            .flatMap(sentences)
            .last { $0.hasSuffix("?") }
            .map { clipped($0, limit: 120) }
        let motifs = motifWords(in: "\(title) \(details.body)", adding: context.theme?.motifs ?? [])
        let callback = callback(from: keptLine, fallbackTitle: title)
        let echoes = page.tags
            .compactMap { tag -> String? in
                tag.hasPrefix(semanticEchoPrefix) ? String(tag.dropFirst(semanticEchoPrefix.count)) : nil
            }
        return BookOfYouResidue(
            title: title,
            spineLine: spineLine,
            keptLine: keptLine,
            motifs: motifs,
            semanticEchoIDs: Array(Set(echoes + context.semanticEchoSourceIDs)).sorted(),
            openedQuestion: question,
            callbackCandidate: callback
        )
    }

    static func fromTags(in page: BookPage) -> BookOfYouResidue? {
        guard page.tags.contains(markerTag) else { return nil }
        let fallbackTitle = page.promptText
            .replacingOccurrences(of: "Book of You:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return BookOfYouResidue(
            title: tagValue(titlePrefix, in: page.tags) ?? fallbackTitle.nonEmpty ?? "Book of You",
            spineLine: tagValue(spinePrefix, in: page.tags) ?? "",
            keptLine: tagValue(keptPrefix, in: page.tags) ?? "",
            motifs: values(motifPrefix, in: page.tags),
            semanticEchoIDs: values(semanticEchoPrefix, in: page.tags),
            openedQuestion: tagValue(questionPrefix, in: page.tags),
            callbackCandidate: tagValue(callbackPrefix, in: page.tags)
        )
    }

    func stamping(into tags: Set<String>) -> Set<String> {
        var stamped = tags.filter { tag in
            !tag.hasPrefix(Self.titlePrefix)
                && !tag.hasPrefix(Self.spinePrefix)
                && !tag.hasPrefix(Self.keptPrefix)
                && !tag.hasPrefix(Self.motifPrefix)
                && !tag.hasPrefix(Self.questionPrefix)
                && !tag.hasPrefix(Self.callbackPrefix)
                && !tag.hasPrefix(Self.semanticEchoPrefix)
        }
        stamped.insert(Self.markerTag)
        stamped.insert(Self.titlePrefix + title)
        if !spineLine.isEmpty { stamped.insert(Self.spinePrefix + spineLine) }
        if !keptLine.isEmpty { stamped.insert(Self.keptPrefix + keptLine) }
        for motif in motifs.prefix(6) {
            stamped.insert(Self.motifPrefix + motif)
        }
        if let openedQuestion, !openedQuestion.isEmpty {
            stamped.insert(Self.questionPrefix + openedQuestion)
        }
        if let callbackCandidate, !callbackCandidate.isEmpty {
            stamped.insert(Self.callbackPrefix + callbackCandidate)
        }
        for echoID in semanticEchoIDs.prefix(6) where !echoID.isEmpty {
            stamped.insert(Self.semanticEchoPrefix + echoID)
        }
        return stamped
    }

    private static func tagValue(_ prefix: String, in tags: [String]) -> String? {
        tags.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap(\.nonEmpty)
    }

    private static func values(_ prefix: String, in tags: [String]) -> [String] {
        tags
            .compactMap { tag in
                tag.hasPrefix(prefix) ? String(tag.dropFirst(prefix.count)).nonEmpty : nil
            }
            .sorted()
    }

    private static func normalizedParagraphs(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func sentences(in paragraph: String) -> [String] {
        var out: [String] = []
        var current = ""
        for character in paragraph {
            current.append(character)
            if ".!?".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { out.append(trimmed) }
                current = ""
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { out.append(trimmed) }
        return out
    }

    private static func motifWords(in text: String, adding themeMotifs: [String]) -> [String] {
        let lexicon: [String] = [
            "rain", "snow", "fog", "wind", "storm", "cloud", "sun", "moon",
            "window", "door", "threshold", "kitchen", "room", "porch", "harbor",
            "coffee", "tea", "cup", "mug", "lamp", "key", "book", "page",
            "letter", "photo", "garden", "walk", "road", "water", "hand",
            "sleep", "hunger", "music", "light", "shadow"
        ]
        let lower = text.lowercased()
        let words = Set(lower.split { !$0.isLetter }.map(String.init))
        let theme = themeMotifs
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidates = theme + lexicon
        var seen: Set<String> = []
        var motifs: [String] = []
        for candidate in candidates where !seen.contains(candidate) {
            if words.contains(candidate) || lower.contains(candidate) {
                seen.insert(candidate)
                motifs.append(candidate)
            }
            if motifs.count == 6 { break }
        }
        return motifs
    }

    private static func callback(from keptLine: String, fallbackTitle: String) -> String? {
        let raw = keptLine
            .replacingOccurrences(of: "The Book kept the page:", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".:")))
        return clipped(raw.nonEmpty ?? fallbackTitle, limit: 96).nonEmpty
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        let prefix = normalized[..<end]
        let lastSpace = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BindingMemoryDigest: Equatable {
    struct BraidMemory: Equatable {
        var pageID: String
        var date: Date
        var residue: BookOfYouResidue
    }

    struct MotifCount: Equatable {
        var motif: String
        var count: Int
    }

    var braids: [BraidMemory]
    var motifCounts: [MotifCount]
    var strongestCallback: String?

    static let empty = BindingMemoryDigest(braids: [], motifCounts: [], strongestCallback: nil)
}

enum BindingMemorySpine {
    static func digest(days: [BookDay], now: Date = Date(), limit: Int = 12) -> BindingMemoryDigest {
        let braidMemories = days
            .flatMap(\.pages)
            .filter { $0.type == .bookOfYou && $0.createdAt <= now }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { page -> BindingMemoryDigest.BraidMemory? in
                let residue = BookOfYouResidue.fromTags(in: page) ?? BookOfYouResidue.extract(from: page)
                return BindingMemoryDigest.BraidMemory(pageID: page.id, date: page.createdAt, residue: residue)
            }
        guard !braidMemories.isEmpty else { return .empty }
        let counts = Dictionary(grouping: braidMemories.flatMap(\.residue.motifs), by: { $0 })
            .mapValues(\.count)
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .prefix(8)
            .map { BindingMemoryDigest.MotifCount(motif: $0.key, count: $0.value) }
        return BindingMemoryDigest(
            braids: Array(braidMemories.prefix(limit)),
            motifCounts: counts,
            strongestCallback: braidMemories.first?.residue.callbackCandidate
        )
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

// MARK: - Taught Reading (corrections remembered out loud)

/// One rule the reader has taught the Book about how to read them, spoken
/// back in the Book's voice. Being correctable out loud is what separates a
/// reader from a horoscope.
struct TaughtReadingRule: Identifiable, Equatable {
    var id: String
    var line: String
}

/// Gathers everything the reader has taught the Book — braid corrections,
/// notice feedback, quiet dismissals — from the stores that already hold
/// them. No new ledgers: the vault's braid notes, the kept pages' feedback
/// tags, and the reader-learning events are the memory of being corrected.
enum TaughtReading {
    static func rules(
        learnedBraidNotes: [String],
        days: [BookDay],
        learning: ReaderLearningModel,
        now: Date = Date(),
        limit: Int = 6
    ) -> [TaughtReadingRule] {
        var rules: [TaughtReadingRule] = []

        // The reader's own written corrections come first — nothing teaches
        // like a sentence the reader typed at the Book.
        for (index, note) in learnedBraidNotes.suffix(2).reversed().enumerated() {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            rules.append(TaughtReadingRule(
                id: "taught-braid-note-\(index)",
                line: "You told me: \u{201C}\(clipped(trimmed))\u{201D} — the braids have been written with that in hand since."
            ))
        }

        // Feedback on the Book's noticing: stepped back from, softened, trusted.
        let noticeEvents = learning.events.filter { $0.type == .bookNotices }
        let dismissed = noticeEvents.filter { $0.action == .dismissed }.count
        let missed = noticeEvents.filter { $0.action == .missed }.count
        let loved = noticeEvents.filter { $0.action == .loved }.count
        if dismissed > 0 {
            rules.append(TaughtReadingRule(
                id: "taught-notice-dismissed",
                line: "You asked me, \(timesPhrase(dismissed)), not to read you a certain way. I stepped back from those readings — stepped back, not forgotten; respected."
            ))
        }
        if missed > 0 {
            rules.append(TaughtReadingRule(
                id: "taught-notice-missed",
                line: "\(spelled(missed).capitalized) \(missed == 1 ? "notice" : "notices") you marked \u{201C}not quite.\u{201D} I soften those patterns before speaking them again."
            ))
        }
        if loved > 0 {
            rules.append(TaughtReadingRule(
                id: "taught-notice-loved",
                line: "\(spelled(loved).capitalized) \(loved == 1 ? "reading" : "readings") you sealed as true. That kind of noticing gets to speak sooner now."
            ))
        }

        // Braid verdicts carried on the kept pages themselves.
        let braids = days.flatMap(\.pages).filter { $0.type == .bookOfYou }
        let lovedBraids = braids.filter { $0.tags.contains(BraidLearningLoop.lovedItTag) }.count
        let missedBraids = braids.filter { $0.tags.contains(BraidLearningLoop.missedMeTag) }.count
        switch (lovedBraids > 0, missedBraids > 0) {
        case (true, true):
            rules.append(TaughtReadingRule(
                id: "taught-braid-verdicts",
                line: "Of the braids, you called \(spelled(lovedBraids)) true and \(spelled(missedBraids)) \(missedBraids == 1 ? "a miss" : "misses"). Every new braid is tasted against exactly those lessons."
            ))
        case (true, false):
            rules.append(TaughtReadingRule(
                id: "taught-braid-verdicts",
                line: "You have called \(spelled(lovedBraids)) \(lovedBraids == 1 ? "braid" : "braids") a true page. The Book keeps aiming there."
            ))
        case (false, true):
            rules.append(TaughtReadingRule(
                id: "taught-braid-verdicts",
                line: "\(spelled(missedBraids).capitalized) \(missedBraids == 1 ? "braid" : "braids") missed you, and you said so. The Book rewrites toward what you meant."
            ))
        case (false, false):
            break
        }

        // A page family the reader's dismissals cooled: the correction the
        // reader made without ever saying a word.
        if let cooling = learning.insights(now: now, limit: 6).first(where: { $0.kind == .coolingType }) {
            rules.append(TaughtReadingRule(
                id: "taught-cooling-\(cooling.id)",
                line: "\(cooling.line) You never had to say it twice — the quiet was instruction enough."
            ))
        }

        return Array(rules.prefix(limit))
    }

    /// The single line woven into a Book Notices page when the reader has
    /// taught the Book anything: proof that corrections change the reading.
    static func noticeLine(from rules: [TaughtReadingRule]) -> String? {
        guard let first = rules.first else { return nil }
        return "You have been teaching me how to read you, and I keep the lessons: \(first.line)"
    }

    private static func clipped(_ text: String, limit: Int = 90) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let lastSpace = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<lastSpace]) + "\u{2026}"
    }

    private static func timesPhrase(_ n: Int) -> String {
        switch n {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(spelled(n)) times"
        }
    }

    private static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven",
                     "eight", "nine", "ten", "eleven", "twelve"]
        return (0...12).contains(n) ? words[n] : "\(n)"
    }
}

/// Receipts that the reader's own seeing is changing: an early plain sentence
/// beside a recent vivid one, both quoted from the archive.
enum HowYouSee {
    struct SeeingReceipt: Codable, Equatable {
        var earlierQuote: String
        var earlierMonthName: String
        var recentQuote: String
        var earlierStrength: Int
        var recentStrength: Int
    }

    static let minimumAuthoredPages = 40
    static let minimumSpanDays = 60
    static let seeingTypes: Set<BookPageType> = [.souvenir, .diary, .mood, .wonderCompass, .plainPage]

    static func receipt(days: [BookDay], now: Date = Date()) -> SeeingReceipt? {
        let engine = SentenceBuilderEngine()
        let pages = days.flatMap(\.pages)
            .filter {
                seeingTypes.contains($0.type)
                    && $0.origin == .userAuthored
                    && $0.userInput.split(whereSeparator: \.isWhitespace).count >= 4
            }
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        guard pages.count >= minimumAuthoredPages,
              let first = pages.first,
              let last = pages.last,
              last.createdAt.timeIntervalSince(first.createdAt) >= Double(minimumSpanDays) * 86_400 else { return nil }

        let earlyEnd = first.createdAt.addingTimeInterval(30 * 86_400)
        let recentStart = now.addingTimeInterval(-30 * 86_400)
        let early = pages.filter { $0.createdAt <= earlyEnd }
        let recent = pages.filter { $0.createdAt >= recentStart && $0.createdAt <= now }
        guard !early.isEmpty, !recent.isEmpty else { return nil }

        let earlyAnalyses = early.map { ($0, engine.analyze($0.userInput)) }
        let recentAnalyses = recent.map { ($0, engine.analyze($0.userInput)) }
        let earlyAverage = Double(earlyAnalyses.reduce(0) { $0 + $1.1.memoryStrength }) / Double(earlyAnalyses.count)
        let recentAverage = Double(recentAnalyses.reduce(0) { $0 + $1.1.memoryStrength }) / Double(recentAnalyses.count)
        let earlyVividShare = Double(earlyAnalyses.filter { $0.1.isVivid }.count) / Double(earlyAnalyses.count)
        let recentVividShare = Double(recentAnalyses.filter { $0.1.isVivid }.count) / Double(recentAnalyses.count)
        let vividImproved = earlyVividShare > 0
            ? recentVividShare >= earlyVividShare * 2
            : recentVividShare >= 0.25
        guard recentAverage >= earlyAverage + 0.75 || vividImproved else { return nil }

        let earlier = earlyAnalyses
            .filter { $0.1.memoryStrength <= 1 }
            .min { ($0.0.userInput.count, $0.0.createdAt, $0.0.id) < ($1.0.userInput.count, $1.0.createdAt, $1.0.id) }
        let latest = recentAnalyses
            .filter { $0.1.isVivid && $0.0.id != earlier?.0.id }
            .max { ($0.1.memoryStrength, $0.0.createdAt, $0.0.id) < ($1.1.memoryStrength, $1.0.createdAt, $1.0.id) }
        guard let earlier, let latest else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return SeeingReceipt(
            earlierQuote: clipped(earlier.0.userInput.bookPreviewSentenceLimit(1)),
            earlierMonthName: formatter.string(from: earlier.0.createdAt),
            recentQuote: clipped(latest.0.userInput.bookPreviewSentenceLimit(1)),
            earlierStrength: earlier.1.memoryStrength,
            recentStrength: latest.1.memoryStrength
        )
    }

    private static func clipped(_ text: String, limit: Int = 110) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let lastSpace = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<lastSpace]) + "…"
    }
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
            addIfWeak(score.souvenirSpine, threshold: 8, dimension: "souvenirSpine", weight: 4 + readerPenalty, into: &weights, notes: &notes)
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
        case "souvenirSpine":
            return "Carry the reader's one-sentence souvenir through the opening, turn, and kept-page line."
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
        var souvenirSpine: Int
        var keeperSentence: Int
        var concreteMagic: Int
        var penalties: Int

        var total: Int {
            title + storyShape + priorEcho + themeAndChapter + souvenirSpine + keeperSentence + concreteMagic - penalties
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
            souvenirSpine: souvenirSpineScore(
                normalized: normalized,
                paragraphs: paragraphs,
                closingSentences: closingSentences,
                context: context
            ),
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

    private static func souvenirSpineScore(
        normalized: String,
        paragraphs: [String],
        closingSentences: [String],
        context: BraidPromptBuilder.Context
    ) -> Int {
        guard let anchor = context.souvenirAnchor else { return 6 }
        let anchorWords = Set(significantWords(anchor.keptText))
        guard !anchorWords.isEmpty else { return 6 }

        let totalHits = anchorWords.filter { normalized.contains($0) }.count
        guard totalHits > 0 else { return 0 }

        let opening = paragraphs.first?.normalizedForBraidTasting ?? ""
        let closing = closingSentences.joined(separator: " ").normalizedForBraidTasting
        let openingHits = anchorWords.filter { opening.contains($0) }.count
        let closingHits = anchorWords.filter { closing.contains($0) }.count

        var score = 5
        if totalHits >= min(2, anchorWords.count) { score += 4 }
        if openingHits > 0 { score += 3 }
        if closingHits > 0 { score += 4 }
        return min(score, 14)
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
        let pattern = patternSignals(pages: pages, events: events, now: now, calendar: calendar)
        let absences = absenceSignals(pages: pages, events: events, now: now, calendar: calendar)
        let durations = durationSignals(pages: pages, lifecycles: lifecycles, now: now, calendar: calendar)
        let lifecycle = lifecycles.prefix(4).map { lifecycleSignal($0, now: now, calendar: calendar) }
        let manner = mannerSignals(pages: pages, now: now, calendar: calendar)
        let signals = pattern + absences + durations + lifecycle + manner

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

    // MARK: - Manner signals (how the reader writes)

    /// The window the Book calls "this week" when reading manner.
    static let mannerRecentWindowDays = 7
    /// How far back the baseline reaches. Older pages describe a different
    /// season of the hand and are left out of the comparison.
    static let mannerBaselineWindowDays = 56

    /// Qualifiers whose density is the pencil hovering. Phrases are matched
    /// as phrases.
    static let mannerHedgeTerms: [String] = [
        "maybe", "probably", "perhaps", "i guess", "i suppose",
        "sort of", "kind of", "i think", "a bit"
    ]

    /// Manner observations read only the reader's own prose — never prompt
    /// text (the Book's words) and never the private body/fuel logs.
    static func mannerProse(in pages: [BookPage]) -> [BookPage] {
        pages.filter { page in
            page.origin == .userAuthored
                && !EditionCurator.defaultPrivateTypes.contains(page.type)
                && page.userInput.split { !$0.isLetter && !$0.isNumber }.count >= 5
        }
    }

    static func mannerSignals(pages: [BookPage], now: Date, calendar: Calendar) -> [LiteraryContinuitySignal] {
        let prose = mannerProse(in: pages)
        guard !prose.isEmpty else { return [] }
        var signals: [LiteraryContinuitySignal] = []
        if let pace = sentencePaceSignal(prose: prose, now: now) {
            signals.append(pace)
        }
        if let hedge = hedgeInkSignal(prose: prose, now: now) {
            signals.append(hedge)
        }
        signals += hourboundSubjectSignals(prose: prose, now: now, calendar: calendar)
        return signals
    }

    /// The sentences walked faster or slower this week than the reader's own
    /// baseline. Requires enough pages on both sides of the comparison that
    /// the drift is a real change of gait, not one hurried evening.
    static func sentencePaceSignal(prose: [BookPage], now: Date) -> LiteraryContinuitySignal? {
        let recentCutoff = now.addingTimeInterval(TimeInterval(-mannerRecentWindowDays) * 86_400)
        let baselineCutoff = now.addingTimeInterval(TimeInterval(-mannerBaselineWindowDays) * 86_400)
        let recent = prose.filter { $0.createdAt > recentCutoff && $0.createdAt <= now }
        let baseline = prose.filter { $0.createdAt > baselineCutoff && $0.createdAt <= recentCutoff }
        guard recent.count >= 4, baseline.count >= 8 else { return nil }

        let recentAverage = averageSentenceLength(of: recent)
        let baselineAverage = averageSentenceLength(of: baseline)
        guard recentAverage > 0, baselineAverage > 0 else { return nil }
        let ratio = recentAverage / baselineAverage

        let line: String
        let flavor: String
        if ratio <= 0.72 {
            line = "This week the sentences walk faster — about \(spelledCount(Int(recentAverage.rounded()))) words to a step, where \(spelledCount(Int(baselineAverage.rounded()))) has been usual. Shorter steps, quicker breath."
            flavor = "fast"
        } else if ratio >= 1.4 {
            line = "The sentences have slowed into long walks this week — about \(spelledCount(Int(recentAverage.rounded()))) words to a sentence, where \(spelledCount(Int(baselineAverage.rounded()))) has been usual. Unhurried, taking the air."
            flavor = "slow"
        } else {
            return nil
        }

        let sortedRecent = recent.sorted { $0.createdAt < $1.createdAt }
        return LiteraryContinuitySignal(
            id: "manner-pace",
            kind: .manner,
            subjectID: "manner-pace",
            subjectName: "the sentences",
            line: line,
            evidencePageIDs: sortedRecent.suffix(6).map(\.id),
            relatedEntityIDs: [],
            tags: ["manner", "pace", flavor],
            firstSeenAt: sortedRecent.first?.createdAt ?? now,
            lastSeenAt: sortedRecent.last?.createdAt ?? now,
            strength: min(72, 56 + Int((abs(1 - ratio) * 24).rounded()))
        )
    }

    /// Hedge density rose or fell hard against the reader's own baseline —
    /// the pencil hovering, or the week written in ink.
    static func hedgeInkSignal(prose: [BookPage], now: Date) -> LiteraryContinuitySignal? {
        let recentCutoff = now.addingTimeInterval(TimeInterval(-mannerRecentWindowDays) * 86_400)
        let baselineCutoff = now.addingTimeInterval(TimeInterval(-mannerBaselineWindowDays) * 86_400)
        let recent = prose.filter { $0.createdAt > recentCutoff && $0.createdAt <= now }
        let baseline = prose.filter { $0.createdAt > baselineCutoff && $0.createdAt <= recentCutoff }

        let recentWords = totalWordCount(of: recent)
        let baselineWords = totalWordCount(of: baseline)
        // Density needs volume before it means anything.
        guard recentWords >= 120, baselineWords >= 400 else { return nil }

        let recentHedges = hedgeCount(in: recent)
        let baselineHedges = hedgeCount(in: baseline)
        let recentDensity = Double(recentHedges) / Double(recentWords) * 100
        let baselineDensity = Double(baselineHedges) / Double(baselineWords) * 100

        let line: String
        let flavor: String
        if baselineDensity > 0, recentDensity >= baselineDensity * 2.2, recentHedges >= 3 {
            line = "More \u{201C}maybe\u{201D} in the margins than usual this week. The pencil is hovering over something it has not decided to write."
            flavor = "hovering"
        } else if baselineDensity >= 1.0, recentDensity <= baselineDensity * 0.35 {
            line = "The maybes have thinned out of the pages. This week you are writing in ink."
            flavor = "ink"
        } else {
            return nil
        }

        let sortedRecent = recent.sorted { $0.createdAt < $1.createdAt }
        return LiteraryContinuitySignal(
            id: "manner-hedge",
            kind: .manner,
            subjectID: "manner-hedge",
            subjectName: "the maybes",
            line: line,
            evidencePageIDs: sortedRecent.suffix(6).map(\.id),
            relatedEntityIDs: [],
            tags: ["manner", "hedge", flavor],
            firstSeenAt: sortedRecent.first?.createdAt ?? now,
            lastSeenAt: sortedRecent.last?.createdAt ?? now,
            strength: 58
        )
    }

    /// A subject that only ever appears at one hour of the day — "you only
    /// write about the harbor after dark." Honest by construction: it needs
    /// the reader to write at other hours too, or "only at night" would be
    /// trivially true of everything.
    static func hourboundSubjectSignals(prose: [BookPage], now: Date, calendar: Calendar) -> [LiteraryContinuitySignal] {
        // The corpus must genuinely spread across hours: at least two bands,
        // and at least 40% of prose outside any single word's band.
        let allBands = prose.map { dayBand(for: $0.createdAt, calendar: calendar) }
        guard Set(allBands).count >= 2 else { return [] }
        let bandTotals = Dictionary(grouping: allBands) { $0 }.mapValues(\.count)

        var buckets: [String: [BookPage]] = [:]
        for page in prose {
            for word in meaningfulWords(in: page.userInput) {
                buckets[word, default: []].append(page)
            }
        }

        var out: [LiteraryContinuitySignal] = []
        for (word, matches) in buckets {
            let unique = uniqueMannerPages(matches)
            guard unique.count >= 3 else { continue }
            let dayIDs = Set(unique.map { BookDay.id(for: $0.createdAt, calendar: calendar) })
            guard dayIDs.count >= 2 else { continue }
            guard let penalty = ubiquityPenalty(pageHits: unique.count, totalPages: prose.count), penalty <= 8 else { continue }

            let bands = Set(unique.map { dayBand(for: $0.createdAt, calendar: calendar) })
            guard bands.count == 1, let band = bands.first else { continue }
            let inBand = bandTotals[band] ?? 0
            let outsideShare = Double(prose.count - inBand) / Double(prose.count)
            guard outsideShare >= 0.4 else { continue }

            let sorted = unique.sorted { $0.createdAt < $1.createdAt }
            out.append(LiteraryContinuitySignal(
                id: "manner-hour-\(word)",
                kind: .manner,
                subjectID: word,
                subjectName: word,
                line: "\(word.capitalized) only ever visits these pages \(bandPhrase(for: band)) — \(spelledCount(unique.count)) times now, never at any other hour.",
                evidencePageIDs: sorted.map(\.id),
                relatedEntityIDs: [],
                tags: ["manner", "hour", band, word],
                firstSeenAt: sorted.first?.createdAt ?? now,
                lastSeenAt: sorted.last?.createdAt ?? now,
                strength: min(70, 50 + 4 * min(unique.count, 5) - penalty)
            ))
        }
        return out
            .sorted { left, right in
                if left.strength == right.strength { return left.subjectName < right.subjectName }
                return left.strength > right.strength
            }
            .prefix(2)
            .map(\.self)
    }

    static func dayBand(for date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...20: return "evening"
        default: return "night"
        }
    }

    static func bandPhrase(for band: String) -> String {
        switch band {
        case "morning": return "in the morning"
        case "afternoon": return "in the afternoon"
        case "evening": return "in the evening"
        default: return "after dark"
        }
    }

    private static func averageSentenceLength(of pages: [BookPage]) -> Double {
        var sentenceCount = 0
        var wordCount = 0
        for page in pages {
            let sentences = page.userInput
                .split(omittingEmptySubsequences: true) { ".!?\n".contains($0) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            sentenceCount += sentences.count
            wordCount += sentences.reduce(0) { $0 + $1.split { !$0.isLetter && !$0.isNumber }.count }
        }
        guard sentenceCount > 0 else { return 0 }
        return Double(wordCount) / Double(sentenceCount)
    }

    private static func totalWordCount(of pages: [BookPage]) -> Int {
        pages.reduce(0) { $0 + $1.userInput.split { !$0.isLetter && !$0.isNumber }.count }
    }

    private static func hedgeCount(in pages: [BookPage]) -> Int {
        pages.reduce(0) { total, page in
            let text = " \(page.userInput.lowercased().replacingOccurrences(of: "[^a-z]+", with: " ", options: .regularExpression)) "
            return total + mannerHedgeTerms.reduce(0) { sum, term in
                sum + text.components(separatedBy: " \(term) ").count - 1
            }
        }
    }

    private static func uniqueMannerPages(_ pages: [BookPage]) -> [BookPage] {
        var seen: Set<String> = []
        var out: [BookPage] = []
        for page in pages where !seen.contains(page.id) {
            seen.insert(page.id)
            out.append(page)
        }
        return out.sorted { $0.createdAt < $1.createdAt }
    }

    private static func spelledCount(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven",
                     "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
                     "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]
        return (0...20).contains(n) ? words[n] : "\(n)"
    }

    private static func patternSignals(
        pages: [BookPage],
        events: [NarrativeEvent],
        now: Date,
        calendar: Calendar
    ) -> [LiteraryContinuitySignal] {
        var buckets: [String: [BookPage]] = [:]
        for page in pages {
            let text = page.resolvedAttentionFingerprint.patternText
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
            let text = page.resolvedAttentionFingerprint.patternText
            for word in meaningfulWords(in: text) {
                buckets[word, default: []].append(page)
            }
        }
        let recentText = pages
            .filter { $0.createdAt >= historyCutoff }
            .map { $0.resolvedAttentionFingerprint.patternText }
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
        let events = lifecycle.eventCount == 1 ? "one event" : "\(lifecycle.eventCount) events"
        return LiteraryContinuitySignal(
            id: "belief-lifecycle-\(lifecycle.id)",
            kind: .beliefLifecycle,
            subjectID: lifecycle.id,
            subjectName: lifecycle.name,
            line: "\(lifecycle.name) has become a living thread: \(appearances), \(events), current Glow \(lifecycle.currentGlow).",
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

// MARK: - Context Weave
//
// The general relationship finder. It lays the reader's own prose beside the
// coarse context each page carried home in its BookPageContextSnapshot —
// weather, hour, weekend, body, busy-ness, familiar place — and speaks only
// when a writing habit keeps choosing one condition over the others. Every
// comparison is two-sided (rainy pages against dry ones, never rainy pages
// against nothing), reads only the context that was true when the page was
// kept, and is phrased as an observation the reader may overrule.

/// One discovered relationship between how (or what) the reader writes and a
/// condition the pages were kept under.
struct ContextConnection: Identifiable, Equatable {
    enum Kind: String, Equatable {
        /// A writing manner (tone, hedging, length, questions) that leans
        /// into one condition.
        case manner
        /// A recurring subject word that only ever appears under one
        /// condition.
        case subject
    }

    /// Stable across days, but includes an evidence bucket so a connection
    /// may honestly speak again once it has gathered meaningfully more pages.
    var id: String
    var kind: Kind
    var facetID: String
    var headline: String
    var line: String
    var evidencePageIDs: [String]
    var strength: Int
    var inHits: Int
    var inCount: Int
    var outHits: Int
    var outCount: Int
}

enum ContextWeave {
    // MARK: Tone lexicons

    /// Weather and hour words are deliberately absent from both lexicons:
    /// "the bright sun" on a clear day or "dark" after nightfall would let a
    /// facet predict itself and the connection would be circular, not read.
    static let brightInkWords: Set<String> = [
        "glad", "happy", "happiness", "laugh", "laughed", "laughing", "laughter",
        "love", "loved", "lovely", "sweet", "joy", "joyful", "delight", "delighted",
        "fun", "funny", "smile", "smiled", "smiling", "grin", "grinning",
        "grateful", "gratitude", "thankful", "calm", "peaceful", "gentle",
        "cozy", "snug", "proud", "excited", "alive", "wonderful", "beautiful",
        "kind", "hopeful", "hope", "singing", "sang", "dancing", "danced"
    ]

    static let heavyInkWords: Set<String> = [
        "sad", "sadness", "sadder", "tired", "exhausted", "weary", "heavy",
        "heavier", "alone", "lonely", "loneliness", "hurt", "hurts", "hurting",
        "ache", "aches", "aching", "cried", "cry", "crying", "tears", "worry",
        "worried", "worrying", "anxious", "anxiety", "afraid", "fear", "fearful",
        "scared", "empty", "hollow", "lost", "angry", "anger", "frustrated",
        "frustrating", "grief", "grieving", "mourning", "numb", "dread",
        "sore", "sick", "awful", "terrible", "dreading", "overwhelmed"
    ]

    enum InkTone: String, Equatable {
        case bright
        case heavy
    }

    /// The page's dominant emotional register, or nil when the ink is
    /// neutral or evenly mixed. Strict majority only — the Book never breaks
    /// a tie on the reader's behalf.
    static func tone(of text: String) -> InkTone? {
        var bright = 0
        var heavy = 0
        for word in tokens(in: text) {
            if brightInkWords.contains(word) { bright += 1 }
            if heavyInkWords.contains(word) { heavy += 1 }
        }
        guard bright != heavy else { return nil }
        return bright > heavy ? .bright : .heavy
    }

    // MARK: Measures — how a page is written

    enum Measure: String, CaseIterable {
        case heavyInk = "heavy-ink"
        case brightInk = "bright-ink"
        case hedged
        case asking
        case longform
        case brisk

        /// "\(spelled(n)) of them …" — the clause that reports the in-facet hits.
        var hitPhrase: String {
            switch self {
            case .heavyInk: return "lean on the heavier words"
            case .brightInk: return "reach for the brighter words"
            case .hedged: return "hedge — maybe, perhaps, I think"
            case .asking: return "end up asking questions"
            case .longform: return "run long, taking the air"
            case .brisk: return "stay brisk, a few quick strokes"
            }
        }

        /// The sentence that opens the observation.
        func hook(inPhrase: String) -> String {
            switch self {
            case .heavyInk: return "The ink runs heavier \(inPhrase)."
            case .brightInk: return "The ink runs brighter \(inPhrase)."
            case .hedged: return "The maybes gather \(inPhrase)."
            case .asking: return "Your questions arrive \(inPhrase)."
            case .longform: return "The sentences stretch out \(inPhrase)."
            case .brisk: return "The sentences shorten their stride \(inPhrase)."
            }
        }
    }

    static func matches(_ measure: Measure, page: BookPage, medianWords: Int) -> Bool {
        switch measure {
        case .heavyInk: return tone(of: page.userInput) == .heavy
        case .brightInk: return tone(of: page.userInput) == .bright
        case .hedged: return hedgeCount(in: page.userInput) >= 1
        case .asking: return page.userInput.contains("?")
        case .longform: return wordCount(of: page.userInput) >= max(30, medianWords * 17 / 10)
        case .brisk: return wordCount(of: page.userInput) <= max(6, medianWords / 2)
        }
    }

    // MARK: Facets — the conditions a page was kept under

    struct Facet: Equatable {
        var id: String
        var family: String
        var inPhrase: String
        var outPhrase: String
    }

    /// Families whose membership every page can claim; the rest require the
    /// page to carry a context snapshot recording that dimension. A page may
    /// belong to a family without matching any facet in it (a mild-weather
    /// page still counts as "not rainy") — that is what keeps the out-group
    /// honest.
    static func families(for page: BookPage) -> Set<String> {
        var out: Set<String> = ["hour", "week"]
        guard let context = page.context else { return out }
        if !context.weatherTags.isEmpty { out.insert("weather") }
        if context.bodyScore != nil { out.insert("body") }
        if context.calendarEventCount != nil { out.insert("tempo") }
        out.insert("place")
        return out
    }

    static func facetIDs(for page: BookPage, calendar: Calendar) -> Set<String> {
        var out: Set<String> = []
        let dayPart: String
        if let stored = page.context?.dayPart,
           ["morning", "afternoon", "evening", "night"].contains(stored) {
            dayPart = stored
        } else {
            dayPart = LiteraryContinuityProjector.dayBand(for: page.createdAt, calendar: calendar)
        }
        out.insert("hour:\(dayPart)")
        out.insert(calendar.isDateInWeekend(page.createdAt) ? "week:weekend" : "week:weekday")
        if let context = page.context {
            for tag in context.weatherTags {
                out.insert("weather:\(tag)")
            }
            if let score = context.bodyScore {
                if score <= 40 { out.insert("body:low") }
                if score >= 70 { out.insert("body:high") }
            }
            if let events = context.calendarEventCount {
                if events >= 3 { out.insert("tempo:crowded") }
                if events == 0 { out.insert("tempo:open") }
            }
            if let anchor = context.nearbyAnchorID {
                out.insert("place:\(anchor)")
            }
        }
        return out
    }

    static func facet(for facetID: String) -> Facet {
        let family = String(facetID.prefix(while: { $0 != ":" }))
        let value = String(facetID.dropFirst(family.count + 1))
        switch facetID {
        case "hour:morning":
            return Facet(id: facetID, family: family, inPhrase: "in the morning hours", outPhrase: "at other hours")
        case "hour:afternoon":
            return Facet(id: facetID, family: family, inPhrase: "in the afternoon", outPhrase: "at other hours")
        case "hour:evening":
            return Facet(id: facetID, family: family, inPhrase: "in the evening", outPhrase: "at other hours")
        case "hour:night":
            return Facet(id: facetID, family: family, inPhrase: "after dark", outPhrase: "in daylight")
        case "week:weekend":
            return Facet(id: facetID, family: family, inPhrase: "on weekends", outPhrase: "on weekdays")
        case "week:weekday":
            return Facet(id: facetID, family: family, inPhrase: "on weekdays", outPhrase: "on weekends")
        case "weather:rain":
            return Facet(id: facetID, family: family, inPhrase: "while it was raining", outPhrase: "under other skies")
        case "weather:storm":
            return Facet(id: facetID, family: family, inPhrase: "while a storm was about", outPhrase: "under calmer skies")
        case "weather:snow":
            return Facet(id: facetID, family: family, inPhrase: "while snow was down", outPhrase: "under other skies")
        case "weather:fog":
            return Facet(id: facetID, family: family, inPhrase: "in fog", outPhrase: "under clearer skies")
        case "weather:wind":
            return Facet(id: facetID, family: family, inPhrase: "on windy days", outPhrase: "on stiller days")
        case "weather:cloud":
            return Facet(id: facetID, family: family, inPhrase: "under a clouded sky", outPhrase: "under other skies")
        case "weather:bright":
            return Facet(id: facetID, family: family, inPhrase: "under a bright sky", outPhrase: "under other skies")
        case "weather:hot":
            return Facet(id: facetID, family: family, inPhrase: "on hot days", outPhrase: "on cooler days")
        case "weather:cold":
            return Facet(id: facetID, family: family, inPhrase: "on cold days", outPhrase: "on milder days")
        case "body:low":
            return Facet(id: facetID, family: family, inPhrase: "on days the body arrived tired", outPhrase: "on livelier days")
        case "body:high":
            return Facet(id: facetID, family: family, inPhrase: "on days the body arrived lively", outPhrase: "on quieter-bodied days")
        case "tempo:crowded":
            return Facet(id: facetID, family: family, inPhrase: "on your crowded days", outPhrase: "on days with more room")
        case "tempo:open":
            return Facet(id: facetID, family: family, inPhrase: "on days the calendar stood open", outPhrase: "on busier days")
        default:
            if family == "place" {
                return Facet(id: facetID, family: family, inPhrase: "within reach of the same familiar place", outPhrase: "elsewhere")
            }
            return Facet(id: facetID, family: family, inPhrase: "while the weather leaned \(value)", outPhrase: "otherwise")
        }
    }

    static func headline(forFamily family: String) -> String {
        switch family {
        case "weather": return "The Weather in Your Ink"
        case "hour": return "The Hours in Your Ink"
        case "week": return "The Shape of Your Weeks"
        case "body": return "The Body in the Margins"
        case "tempo": return "The Crowded Days"
        case "place": return "A Familiar Doorstep"
        default: return "The Thread Between"
        }
    }

    // MARK: Evidence thresholds

    /// Pages kept under the condition, and distinct days among them.
    static let minimumInPages = 4
    static let minimumInDays = 3
    /// Pages kept under the *other* conditions of the same family — no
    /// one-sided claims.
    static let minimumOutPages = 4
    /// The habit must hold on most in-condition pages and clearly not hold
    /// elsewhere.
    static let minimumInRate = 0.5
    static let minimumRateGap = 0.3
    static let minimumLift = 2.0
    static let minimumHits = 3

    // MARK: The finder

    static func connections(
        days: [BookDay],
        calendar: Calendar = .current
    ) -> [ContextConnection] {
        let prose = LiteraryContinuityProjector.mannerProse(
            in: uniquePages(days.flatMap(\.capturedPages))
        )
        guard prose.count >= 10 else { return [] }
        let medianWords = median(prose.map { wordCount(of: $0.userInput) })

        var familyMembers: [String: [BookPage]] = [:]
        var facetMembers: [String: [BookPage]] = [:]
        for page in prose {
            for family in families(for: page) {
                familyMembers[family, default: []].append(page)
            }
            for facetID in facetIDs(for: page, calendar: calendar) {
                facetMembers[facetID, default: []].append(page)
            }
        }

        var out: [ContextConnection] = []
        for (facetID, inPages) in facetMembers {
            let facet = facet(for: facetID)
            guard let family = familyMembers[facet.family] else { continue }
            let inIDs = Set(inPages.map(\.id))
            let outPages = family.filter { !inIDs.contains($0.id) }
            guard inPages.count >= minimumInPages,
                  distinctDayCount(of: inPages, calendar: calendar) >= minimumInDays,
                  outPages.count >= minimumOutPages else { continue }

            for measure in Measure.allCases {
                if let connection = mannerConnection(
                    measure: measure,
                    facet: facet,
                    inPages: inPages,
                    outPages: outPages,
                    medianWords: medianWords
                ) {
                    out.append(connection)
                }
            }
            out += subjectConnections(
                facet: facet,
                inPages: inPages,
                outPages: outPages,
                familyCount: family.count,
                calendar: calendar
            )
        }
        return out.sorted { left, right in
            if left.strength != right.strength { return left.strength > right.strength }
            return left.id < right.id
        }
    }

    private static func mannerConnection(
        measure: Measure,
        facet: Facet,
        inPages: [BookPage],
        outPages: [BookPage],
        medianWords: Int
    ) -> ContextConnection? {
        let inHitPages = inPages.filter { matches(measure, page: $0, medianWords: medianWords) }
        let outHits = outPages.filter { matches(measure, page: $0, medianWords: medianWords) }.count
        let inRate = Double(inHitPages.count) / Double(inPages.count)
        let outRate = Double(outHits) / Double(outPages.count)
        guard inHitPages.count >= minimumHits,
              inRate >= minimumInRate,
              inRate - outRate >= minimumRateGap,
              inRate >= outRate * minimumLift else { return nil }

        let line = """
        \(measure.hook(inPhrase: facet.inPhrase)) Of the \(spelled(inPages.count)) pages you kept \(facet.inPhrase), \(spelled(inHitPages.count)) \(measure.hitPhrase). \(facet.outPhrase.sentenceCapitalized), \(spelled(outHits)) of \(spelled(outPages.count)) do.
        """
        let evidence = inHitPages
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .sorted { $0.createdAt < $1.createdAt }
        let gap = inRate - outRate
        let strength = min(84, 50 + Int((gap * 40).rounded()) + min(10, inHitPages.count))
        return ContextConnection(
            id: "context-\(facet.id)-\(measure.rawValue)-e\(min(inHitPages.count, 30) / 6)",
            kind: .manner,
            facetID: facet.id,
            headline: headline(forFamily: facet.family),
            line: line,
            evidencePageIDs: evidence.map(\.id),
            strength: strength,
            inHits: inHitPages.count,
            inCount: inPages.count,
            outHits: outHits,
            outCount: outPages.count
        )
    }

    /// A subject word that has only ever appeared under this condition:
    /// "the harbor only visits these pages while it is raining." Hour facets
    /// are skipped — hourbound subjects are already the manner system's job.
    private static func subjectConnections(
        facet: Facet,
        inPages: [BookPage],
        outPages: [BookPage],
        familyCount: Int,
        calendar: Calendar
    ) -> [ContextConnection] {
        guard facet.family != "hour" else { return [] }
        // The family must genuinely spread across the condition, or "only
        // ever here" is trivially true of everything.
        guard Double(outPages.count) / Double(familyCount) >= 0.4 else { return [] }

        var inWordPages: [String: [BookPage]] = [:]
        for page in inPages {
            for word in page.resolvedAttentionFingerprint.subjectTokens + page.resolvedAttentionFingerprint.visualTokens {
                inWordPages[word, default: []].append(page)
            }
        }
        var outWords: Set<String> = []
        for page in outPages {
            outWords.formUnion(page.resolvedAttentionFingerprint.subjectTokens)
            outWords.formUnion(page.resolvedAttentionFingerprint.visualTokens)
        }

        var out: [ContextConnection] = []
        for (word, pages) in inWordPages {
            let unique = uniquePages(pages)
            guard unique.count >= minimumHits,
                  distinctDayCount(of: unique, calendar: calendar) >= minimumInDays,
                  !outWords.contains(word),
                  let penalty = LiteraryContinuityProjector.ubiquityPenalty(
                      pageHits: unique.count,
                      totalPages: familyCount
                  ),
                  penalty <= 8 else { continue }

            let sorted = unique.sorted { $0.createdAt < $1.createdAt }
            out.append(ContextConnection(
                id: "context-\(facet.id)-subject-\(word)-e\(min(unique.count, 30) / 6)",
                kind: .subject,
                facetID: facet.id,
                headline: headline(forFamily: facet.family),
                line: "\(word.capitalized) has only ever stepped into these pages \(facet.inPhrase) — \(spelled(unique.count)) times now, never \(facet.outPhrase).",
                evidencePageIDs: sorted.suffix(4).map(\.id),
                strength: min(78, 48 + 5 * min(unique.count, 5) - penalty),
                inHits: unique.count,
                inCount: inPages.count,
                outHits: 0,
                outCount: outPages.count
            ))
        }
        return out
    }

    // MARK: Small helpers

    private static func tokens(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
    }

    private static func wordCount(of text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }

    private static func hedgeCount(in text: String) -> Int {
        let normalized = " \(text.lowercased().replacingOccurrences(of: "[^a-z]+", with: " ", options: .regularExpression)) "
        return LiteraryContinuityProjector.mannerHedgeTerms.reduce(0) { sum, term in
            sum + normalized.components(separatedBy: " \(term) ").count - 1
        }
    }

    private static func median(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func distinctDayCount(of pages: [BookPage], calendar: Calendar) -> Int {
        Set(pages.map { BookDay.id(for: $0.createdAt, calendar: calendar) }).count
    }

    private static func uniquePages(_ pages: [BookPage]) -> [BookPage] {
        var seen: Set<String> = []
        return pages.filter { page in
            if seen.contains(page.id) { return false }
            seen.insert(page.id)
            return true
        }
    }

    private static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven",
                     "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
                     "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]
        return (0...20).contains(n) ? words[n] : "\(n)"
    }
}

private extension String {
    var sentenceCapitalized: String {
        guard let first = first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

// MARK: - Themes
//
// A theme is the month's weather system: two or three motifs that kept
// gathering until they deserve a shared name. Themes are discovered from
// kept pages and the continuity digest, remembered across months, and used
// as chapter subtitles, theme pages, and margin material. Like everything
// else in the Book, a theme is a literary observation, never a verdict.

enum BookThemeStability: String, Codable, Equatable {
    case provisional
    case stable
}

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
    var stability: BookThemeStability
    var observedDayCount: Int
    var settledAt: Date?

    var promptLine: String {
        "\(stabilityTitle): \(name). \(line) \(stabilityDetail)"
    }

    var isStable: Bool {
        stability == .stable
    }

    var stabilityTitle: String {
        switch stability {
        case .provisional: return "Provisional monthly theme"
        case .stable: return "Settled monthly theme"
        }
    }

    var stabilityDetail: String {
        switch stability {
        case .provisional:
            return "Status: unstable; the Book is still updating this theme as the month gathers more days."
        case .stable:
            return "Status: stable; the Book has stopped resetting this theme for the month."
        }
    }

    var readerStatusLine: String {
        "\(stabilityTitle): \(name). \(stabilityDetail)"
    }

    init(
        id: String,
        monthKey: String,
        name: String,
        motifs: [String],
        line: String,
        strength: Int,
        evidencePageIDs: [String],
        excerptLines: [String],
        discoveredAt: Date,
        stability: BookThemeStability = .stable,
        observedDayCount: Int = 7,
        settledAt: Date? = nil
    ) {
        self.id = id
        self.monthKey = monthKey
        self.name = name
        self.motifs = motifs
        self.line = line
        self.strength = strength
        self.evidencePageIDs = evidencePageIDs
        self.excerptLines = excerptLines
        self.discoveredAt = discoveredAt
        self.stability = stability
        self.observedDayCount = observedDayCount
        self.settledAt = settledAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case monthKey
        case name
        case motifs
        case line
        case strength
        case evidencePageIDs
        case excerptLines
        case discoveredAt
        case stability
        case observedDayCount
        case settledAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        monthKey = try container.decode(String.self, forKey: .monthKey)
        name = try container.decode(String.self, forKey: .name)
        motifs = try container.decode([String].self, forKey: .motifs)
        line = try container.decode(String.self, forKey: .line)
        strength = try container.decode(Int.self, forKey: .strength)
        evidencePageIDs = try container.decode([String].self, forKey: .evidencePageIDs)
        excerptLines = try container.decode([String].self, forKey: .excerptLines)
        discoveredAt = try container.decode(Date.self, forKey: .discoveredAt)
        stability = try container.decodeIfPresent(BookThemeStability.self, forKey: .stability) ?? .stable
        observedDayCount = try container.decodeIfPresent(Int.self, forKey: .observedDayCount) ?? 7
        settledAt = try container.decodeIfPresent(Date.self, forKey: .settledAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(monthKey, forKey: .monthKey)
        try container.encode(name, forKey: .name)
        try container.encode(motifs, forKey: .motifs)
        try container.encode(line, forKey: .line)
        try container.encode(strength, forKey: .strength)
        try container.encode(evidencePageIDs, forKey: .evidencePageIDs)
        try container.encode(excerptLines, forKey: .excerptLines)
        try container.encode(discoveredAt, forKey: .discoveredAt)
        try container.encode(stability, forKey: .stability)
        try container.encode(observedDayCount, forKey: .observedDayCount)
        try container.encodeIfPresent(settledAt, forKey: .settledAt)
    }
}

enum BookThemeEngine {
    static let minimumObservedDaysForTheme = 3
    static let stableObservedDaysForTheme = 7

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
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BookTheme? {
        let observedDayCount = observedDayCount(for: pages, calendar: calendar)
        guard observedDayCount >= minimumObservedDaysForTheme else { return nil }

        var weights: [String: Int] = [:]
        var evidence: [String: [String]] = [:]

        for page in pages {
            let text = page.resolvedAttentionFingerprint.patternText
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
        let stability: BookThemeStability = observedDayCount >= stableObservedDaysForTheme ? .stable : .provisional

        return BookTheme(
            id: "theme-\(monthKey)",
            monthKey: monthKey,
            name: name,
            motifs: motifs,
            line: themeLine(motifs: motifs, seed: "\(monthKey)-line"),
            strength: strength,
            evidencePageIDs: evidenceIDs,
            excerptLines: excerpts,
            discoveredAt: now,
            stability: stability,
            observedDayCount: observedDayCount,
            settledAt: stability == .stable ? now : nil
        )
    }

    /// Upserts the current month's theme into the remembered ledger. Old
    /// months and already-settled live themes keep their names; only the live
    /// provisional theme keeps being rewritten as the month gathers evidence.
    static func remembered(
        _ existing: [BookTheme],
        observing current: BookTheme?,
        monthKey: String
    ) -> [BookTheme] {
        let existingTheme = existing.first { $0.monthKey == monthKey }
        if existingTheme?.isStable == true {
            return existing.sorted { $0.monthKey < $1.monthKey }
        }

        var kept = existing.filter { $0.monthKey != monthKey }
        if var current {
            current.discoveredAt = existingTheme?.discoveredAt ?? current.discoveredAt
            kept.append(current)
        }
        return kept.sorted { $0.monthKey < $1.monthKey }
    }

    static func theme(forMonth monthKey: String, in themes: [BookTheme]) -> BookTheme? {
        themes.first { $0.monthKey == monthKey }
    }

    static func observedDayCount(for pages: [BookPage], calendar: Calendar = .current) -> Int {
        Set(pages.map { BookDay.id(for: $0.createdAt, calendar: calendar) }).count
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
