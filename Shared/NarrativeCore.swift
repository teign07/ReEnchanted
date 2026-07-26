import Foundation


struct InkrestIntake: Codable, Equatable {
    var promptID: String
    var lens: String
    var rotatingQuestion: String
    var rotatingAnswer: String
    var innerWeather: String
    var freeNote: String

    init(
        promptID: String = "open",
        lens: String = "open",
        rotatingQuestion: String = "How did today actually go?",
        rotatingAnswer: String = "",
        innerWeather: String = "",
        freeNote: String = ""
    ) {
        self.promptID = promptID
        self.lens = lens
        self.rotatingQuestion = rotatingQuestion
        self.rotatingAnswer = rotatingAnswer
        self.innerWeather = innerWeather
        self.freeNote = freeNote
    }

    var hasSomethingToOpenWith: Bool {
        [rotatingAnswer, innerWeather, freeNote]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var openingMessage: String {
        var parts: [String] = []
        let answer = rotatingAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty {
            parts.append("\(rotatingQuestion)\n\(answer)")
        }
        let weather = innerWeather.trimmingCharacters(in: .whitespacesAndNewlines)
        if !weather.isEmpty {
            parts.append("Inner weather tonight: \(weather)")
        }
        let note = freeNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: "\n\n")
    }
}

struct AskTheBookTurn: Codable, Identifiable, Equatable {
    var id: String
    var prompt: String
    var answer: String
    var createdAt: Date

    init(id: String = UUID().uuidString, prompt: String, answer: String, createdAt: Date = Date()) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.createdAt = createdAt
    }
}

enum BookKnowledgePromptBuilder {
    private struct KnowledgeEntry {
        var id: String
        var category: String
        var title: String
        var body: String
        var tags: [String]

        var searchText: String {
            ([title, body] + tags).joined(separator: " ").lowercased()
        }
    }

    static func trainingPacket(for readerMessage: String, limit: Int = 18) -> String {
        let entries = rankedEntries(for: readerMessage, limit: limit)
        let entryLines = entries.map { entry in
            "- [\(entry.category)] \(entry.title): \(clipped(entry.body, limit: 420))"
        }.joined(separator: "\n")

        return """
        APP + BOOK KNOWLEDGE:
        - ReEnchanted is a private, local-first living book. The reader keeps Pages; Pages become Today's Margins, the Book of You, memory, search, monthly/annual editions, Story Pages, letters, radio, cast relationships, and future suggestions.
        - The Wonder Compass is the real-world method inside the Book: Notice/North asks "I wonder"; Embark/East makes a plan with Destination, Delight, and Definition; Sense/South wakes up the body; Write/West keeps a One-Sentence Souvenir; Rest/return lets the loop close.
        - Belief is real attention made usable. Noticing the world, writing honest sentences, answering the Book, and keeping nonfiction Pages brighten Glow. Story Pages, Letters, Notes, Fae Parleys, and other generated fiction spend that Glow.
        - The Academy of Unlikely Arts is the in-world frame. Its chapters are Emberheart, Mossbloom, Tidecrest, Riddlewind, and Duskthorn. The Rut of Routine is the flattening force of forgetting, cynicism, and autopilot.
        - Always answer app, lore, cast, system, and Wonder Compass questions from this packet first. If the exact fact is not here, say what you know and keep the uncertainty gentle.

        RELEVANT TRAINING NOTES:
        \(entryLines.isEmpty ? "- No specific match. Use the app and Compass core map above." : entryLines)
        """
    }

    private static func rankedEntries(for readerMessage: String, limit: Int) -> [KnowledgeEntry] {
        let tokens = searchTokens(in: readerMessage)
        let entries = allEntries()
        let ranked: [(entry: KnowledgeEntry, score: Int)] = entries.enumerated().map { index, entry in
            let score = relevanceScore(entry, tokens: tokens, fallbackIndex: index)
            return (entry: entry, score: score)
        }

        return ranked
            .filter { $0.score > 0 || tokens.isEmpty }
            .sorted { left, right in
                if left.score == right.score { return left.entry.title < right.entry.title }
                return left.score > right.score
            }
            .prefix(limit)
            .map(\.entry)
    }

    private static func allEntries() -> [KnowledgeEntry] {
        var entries: [KnowledgeEntry] = []

        entries += MarginTutorCatalog.notes.map {
            KnowledgeEntry(id: "system-\($0.id)", category: "App system", title: $0.title, body: $0.text, tags: [$0.id, "system"])
        }

        entries += AcademyChapterRegistry.chapters.map {
            KnowledgeEntry(
                id: "chapter-\($0.id)",
                category: "Academy chapter",
                title: $0.name,
                body: "Philosophy: \($0.philosophy) Founder: \($0.founder) Traits: \($0.traits.joined(separator: ", ")). Compass flavor: \($0.compassFlavor) Talisman: \($0.talismanName).",
                tags: [$0.id, $0.talismanID, "chapter"] + $0.traits
            )
        }

        entries += NarrativePackRegistry.bundledPacks.flatMap(\.entities).map { entity in
            KnowledgeEntry(
                id: "entity-\(entity.id)",
                category: entity.kind == .character ? "Cast" : entity.kind.rawValue,
                title: entity.name,
                body: entitySummary(entity),
                tags: [entity.id, entity.kind.rawValue, entity.chapter ?? ""] + entity.tags
            )
        }

        entries += NarrativePackRegistry.bundledPacks.flatMap(\.threads).map {
            KnowledgeEntry(id: "thread-\($0.id)", category: "Story thread", title: $0.title, body: $0.summary, tags: [$0.id, $0.phase.rawValue] + $0.tags)
        }

        entries += NarrativePackRegistry.bundledPacks.flatMap(\.relationships).compactMap { relationship in
            let entities = NarrativePackRegistry.bundledPacks.flatMap(\.entities)
            let source = entities.first { $0.id == relationship.sourceEntityID }?.name ?? relationship.sourceEntityID
            let target = entities.first { $0.id == relationship.targetEntityID }?.name ?? relationship.targetEntityID
            return KnowledgeEntry(
                id: "relationship-\(relationship.id)",
                category: "Cast relationship",
                title: "\(source) and \(target)",
                body: relationship.note,
                tags: [relationship.id, relationship.kind.rawValue] + relationship.tags
            )
        }

        entries += BookReferenceCatalog.wonderCompass.map {
            KnowledgeEntry(id: "wonder-\($0.id)", category: "Wonder Compass book", title: $0.title, body: "\($0.prompt) \($0.body)", tags: ["wonder-compass", $0.sourceID] + $0.tags)
        }

        entries += BookReferenceCatalog.lorePacks.flatMap(\.snippets).map {
            KnowledgeEntry(id: "lore-\($0.id)", category: "Lore", title: $0.title, body: "\($0.prompt) \($0.body)", tags: ["lore", $0.sourceID] + $0.tags)
        }

        entries += BookReferenceCatalog.characterIllustrations.map {
            KnowledgeEntry(
                id: "illustration-\($0.id)",
                category: $0.illustrationDossierKind,
                title: $0.characterName,
                body: "\($0.core) Signature: \($0.signature). Continuity: \($0.continuity)",
                tags: [$0.id, $0.slug, $0.chapter ?? ""] + $0.tags
            )
        }

        entries += BookShopCatalog.listings.map {
            KnowledgeEntry(id: "shop-\($0.id)", category: "BookShop", title: $0.title, body: "\($0.contents) \($0.goblinPitch)", tags: [$0.packID, $0.family.rawValue, $0.resolvedSaleState.rawValue])
        }

        entries += BookShopCatalog.freeGifts.map {
            KnowledgeEntry(id: "gift-\($0.id)", category: "BookShop gift", title: $0.title, body: "\($0.contents) \($0.goblinPitch)", tags: [$0.packID, "free-gift"])
        }

        return entries
    }

    private static func entitySummary(_ entity: NarrativeWorldEntity) -> String {
        [
            entity.chapter.map { "Chapter: \($0)." },
            entity.unwrittenInterest.map { "Interest: \($0)" },
            entity.traits.isEmpty ? nil : "Traits: \(entity.traits.joined(separator: ", ")).",
            entity.quirks.isEmpty ? nil : "Quirks: \(entity.quirks.joined(separator: ", ")).",
            entity.beliefs.isEmpty ? nil : "Beliefs: \(entity.beliefs.joined(separator: ", ")).",
            entity.goals.isEmpty ? nil : "Goals: \(entity.goals.joined(separator: ", ")).",
            entity.faults.isEmpty ? nil : "Faults: \(entity.faults.joined(separator: ", "))."
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private static func relevanceScore(_ entry: KnowledgeEntry, tokens: [String], fallbackIndex: Int) -> Int {
        guard !tokens.isEmpty else {
            return max(1, 100 - fallbackIndex)
        }

        let text = entry.searchText
        let title = entry.title.lowercased()
        var score = 0
        for token in tokens {
            if title.contains(token) { score += 18 }
            if entry.tags.contains(where: { $0.lowercased().contains(token) }) { score += 12 }
            if text.contains(token) { score += 4 }
        }

        if title == tokens.joined(separator: " ") { score += 60 }
        return score
    }

    private static func searchTokens(in value: String) -> [String] {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "and", "any", "app", "are", "ask", "book", "can",
            "does", "for", "from", "have", "how", "into", "know", "like", "me", "of", "on",
            "or", "our", "the", "this", "to", "what", "when", "where", "who", "why", "with",
            "wonder", "you", "your"
        ]

        let pieces = value.lowercased().split { !$0.isLetter && !$0.isNumber }
        var seen: Set<String> = []
        return pieces.compactMap { piece in
            let token = String(piece)
            guard token.count >= 3, !stopWords.contains(token), !seen.contains(token) else { return nil }
            seen.insert(token)
            return token
        }
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

enum InkrestOfficeHoursPromptBuilder {
    static func prompt(
        intake: InkrestIntake,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        userMessage: String,
        isClosing: Bool
    ) -> String {
        let chart = SupportFacultyPackRegistry.chart(id: "inkrest-difficult-page-chart")
        let allowed = (chart?.allowedUses ?? [
            "externalize a problem without making it the person",
            "name one feeling gently",
            "offer one grounding or reframing tool",
            "write a preferred-story sentence"
        ]).map { "- \($0)" }.joined(separator: "\n")
        let forbidden = (chart?.forbiddenUses ?? [
            "diagnosis", "forced catharsis", "certainty about symbols"
        ]).map { "- \($0)" }.joined(separator: "\n")
        let safety = chart?.safetyLine
            ?? "A feeling is not a verdict. A problem is not a person. The next hour is where the story can be revised."
        let recentPages = evidenceLines(for: day, characterLimit: 480).prefix(10).joined(separator: "\n")
        let history = previousTurns.suffix(6).enumerated().map { index, turn in
            """
            EXCHANGE \(index + 1)
            Reader: \(clipped(turn.prompt, limit: 700))
            Inkrest: \(clipped(turn.answer, limit: 1_100))
            """
        }.joined(separator: "\n\n")
        let closingDirective = isClosing
            ? """

            THIS IS THE CLOSING REPLY. Take 4 to 6 short paragraphs. Gather the important thread across the whole sitting, reflect back two specific things you heard and the value or hope they imply, offer ONE re-authoring sentence the reader could keep, and propose ONE small, doable experiment for tomorrow (one line, beginning "Experiment: "). Do not ask a new open question. End with the safety line, in your own warm phrasing.
            """
            : """

            Give this rich material room. Write 3 to 5 short paragraphs. First stay with the reader's actual words: reflect at least two specific details or tensions, notice a possible value, hope, exception, or preferred story, and make one careful connection to the sitting so far. Then ask exactly ONE curious narrative-therapy question that opens the next small door. Do not stack questions. Do not rush toward advice, a silver lining, or an experiment unless the reader asks for one.
            """

        return """
        You are Dr. Selene Inkrest, the Academy of Unlikely Arts' narrative therapist, inside ReEnchanted. You are holding a short evening Office Hours sitting with the reader. Warm, curious, unhurried, faintly otherworldly. You read with the reader, never at them. You are a narrative therapist in a storybook — not a chatbot, not a medical app.

        YOUR VOICE:
        - Plain, kind, specific sentences with enough room to think. Short paragraphs. No bullet lists, no headings, no clinical jargon, no pep-talk filler.
        - Sound like a perceptive person who has read the whole page, not a brief reflective chatbot. Quote or closely echo a few of the reader's own concrete words when useful.
        - Interpretation must remain tentative: "I wonder if," "perhaps," and "it sounds as though" are welcome when you cannot know.
        - Externalize problems ("the tiredness", "the worry") so they stop pretending to be the person.
        - Hunt for exceptions, values, and the preferred story hiding inside what they say.
        - Stay inside the lens of tonight's question (\(intake.lens)) without naming it as a technique.
        - Never say you are an AI, assistant, or language model. You are Inkrest.

        WHAT YOU MAY DO (your chart):
        \(allowed)

        WHAT YOU MUST NOT DO:
        \(forbidden)
        - No diagnosis, no treatment or medication advice. Body and fuel belong to your colleague Dr. Vellum; you may gently suggest the reader bring a body question to her, but you do not prescribe.
        - Do not claim the reader did real-world actions they did not report. Use kept pages only as soft context.

        SAFETY LINE (keep its spirit): \(safety)

        TONIGHT'S QUESTION (the lens you opened with):
        \(intake.rotatingQuestion)

        THE READER'S KEPT PAGES TODAY (soft context — weave in at most one, lightly):
        \(recentPages.isEmpty ? "Nothing kept today; work only from what they tell you now." : recentPages)

        THE SITTING SO FAR:
        \(history.isEmpty ? "This is the opening of the sitting." : history)

        THE READER JUST SAID:
        \(userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(they sat down without words; open the door for them gently)" : userMessage)
        \(closingDirective)
        """
    }

    private static func evidenceLines(for day: BookDay, characterLimit: Int) -> [String] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return day.capturedPages.sorted { $0.createdAt < $1.createdAt }.enumerated().map { index, page in
            """
            \(index + 1). \(page.type.title) — kept at \(timeFormatter.string(from: page.createdAt))
            Prompt: \(clipped(page.promptText, limit: 220))
            Kept text: \(clipped(page.userInput, limit: characterLimit))
            Tags: \(page.tags.isEmpty ? "none" : page.tags.joined(separator: ", "))
            """
        }
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalized = value.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}


enum NarrativeEntityKind: String, Codable, Equatable, CaseIterable {
    case character
    case location
    case object
    case thread
    case classRoom
    case talisman
    case realWorldAnchor
    case motif
}

struct NarrativeWorldEntity: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var name: String
    var kind: NarrativeEntityKind
    var belief: Int
    var narrativeWeight: Int
    var chapter: String?
    var unwrittenInterest: String?
    var traits: [String]
    var quirks: [String]
    var faults: [String]
    var beliefs: [String]
    var goals: [String]
    var tags: [String]
    var writingVoice: WritingVoiceProfile?

    init(
        id: String,
        packID: String,
        name: String,
        kind: NarrativeEntityKind,
        belief: Int,
        narrativeWeight: Int,
        chapter: String? = nil,
        unwrittenInterest: String? = nil,
        traits: [String] = [],
        quirks: [String] = [],
        faults: [String] = [],
        beliefs: [String] = [],
        goals: [String] = [],
        tags: [String] = [],
        writingVoice: WritingVoiceProfile? = nil
    ) {
        self.id = id
        self.packID = packID
        self.name = name
        self.kind = kind
        self.belief = belief
        self.narrativeWeight = narrativeWeight
        self.chapter = chapter
        self.unwrittenInterest = unwrittenInterest
        self.traits = traits
        self.quirks = quirks
        self.faults = faults
        self.beliefs = beliefs
        self.goals = goals
        self.tags = tags
        self.writingVoice = writingVoice
    }
}

extension NarrativeWorldEntity {
    /// Every speaking character gets a usable voice even when a pack has not
    /// authored a bespoke `WritingVoiceProfile`. The fallback is deliberately
    /// built from canon rather than from a shared generic NPC style.
    var resolvedWritingVoice: WritingVoiceProfile {
        if let writingVoice {
            return writingVoice
        }

        let traitLine = traits.prefix(4).joined(separator: ", ")
        let quirkLine = quirks.prefix(3).joined(separator: "; ")
        let beliefLine = beliefs.prefix(2).joined(separator: "; ")
        let faultLine = faults.prefix(2).joined(separator: "; ")
        let interestLine = unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return WritingVoiceProfile(
            register: traitLine.isEmpty
                ? "personal, spoken, and unmistakably specific to \(name)"
                : "\(traitLine); spoken and in-world, never polished into a generic narrator",
            rhythm: quirkLine.isEmpty
                ? "vary sentence length around what \(name) notices first; use contractions and a lived-in cadence"
                : "use contractions and let these habits bend the cadence without quoting them as biography: \(quirkLine)",
            diction: Array((traits + tags).filter { !$0.isEmpty }.prefix(6))
                + (interestLine.isEmpty ? [] : ["the concrete vocabulary of \(interestLine)"]),
            habits: [
                beliefLine.isEmpty
                    ? "reveal values through what \(name) protects, challenges, notices, or refuses"
                    : "let these beliefs shape choices and emphasis without stating them like a lesson: \(beliefLine)",
                quirkLine.isEmpty
                    ? "include one character-specific observation or verbal turn"
                    : "allow one recognizable habit to surface naturally: \(quirkLine)"
            ],
            avoid: [
                "generic assistant voice or interchangeable fantasy banter",
                faultLine.isEmpty
                    ? "summarizing the character instead of letting them perform"
                    : "flattening these faults into a cartoon villain or erasing them entirely: \(faultLine)",
                "repeating the character sheet as exposition"
            ]
        )
    }
}

/// The binding character-performance packet used by every generated fiction
/// surface. Selection mechanics may use full entities internally, but model
/// writers must receive this rendered packet rather than names alone.
enum CharacterCanonPacket {
    static let metadataKey = "characterCanon"
    static let version = "character-canon-v1"
    static let endMarker = "END CHARACTER CANON"

    static func promptSection(
        for entities: [NarrativeWorldEntity],
        contextLines: [String] = []
    ) -> String {
        var seen = Set<String>()
        let characters = entities.filter {
            $0.kind == .character && seen.insert($0.id).inserted
        }
        guard !characters.isEmpty else { return "" }

        let profiles = characters.map(profile).joined(separator: "\n\n")
        let context = contextLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(8)
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
        CHARACTER CANON — BINDING PERFORMANCE SHEETS (\(version))
        These are people, not interchangeable plot functions. When a listed character speaks or acts, preserve their values, blind spots, wants, habits, and cadence. Reveal canon through choices, attention, jokes, refusals, and sentence rhythm; never recite this packet as biography. Do not give one character another character's trait, memory, belief, goal, or verbal mannerism.

        \(profiles)
        \(context.isEmpty ? "" : "\nCURRENT CHARACTER CONTEXT:\n\(context)")

        PERFORMANCE CHECK BEFORE RETURNING PROSE:
        - Could each speaking character be identified with the names removed?
        - Does each choice or line grow from that character's beliefs, wants, faults, interests, or relationships?
        - Are voices distinct in rhythm and diction, without catchphrase spam or caricature?
        - If any answer is no, revise before returning the prose.
        \(endMarker)
        """
    }

    static func profile(_ entity: NarrativeWorldEntity) -> String {
        let voice = entity.resolvedWritingVoice.promptDescription
        return """
        \(entity.name) [\(entity.id)]
        Chapter / allegiance: \(entity.chapter?.nonEmpty ?? "unbound or unstated")
        Core nature: \(joined(entity.traits, fallback: "let established actions define the nature"))
        Recognizable habits: \(joined(entity.quirks, fallback: "use one concrete, character-specific habit"))
        Blind spots and faults: \(joined(entity.faults, fallback: "do not invent a melodramatic flaw"))
        Beliefs: \(joined(entity.beliefs, fallback: "infer no new doctrine"))
        Wants: \(joined(entity.goals, fallback: "keep the immediate want modest and scene-specific"))
        Unwritten interest: \(entity.unwrittenInterest?.nonEmpty ?? "no special outside interest supplied")
        Voice:
        \(voice)
        """
    }

    private static func joined(_ values: [String], fallback: String) -> String {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? fallback : cleaned.joined(separator: "; ")
    }

    static func characterIDs(in packet: String) -> [String] {
        var seen = Set<String>()
        return packet
            .split(separator: "\n")
            .compactMap { line -> String? in
                guard let open = line.lastIndex(of: "["),
                      let close = line.lastIndex(of: "]"),
                      open < close else { return nil }
                let id = String(line[line.index(after: open)..<close])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty, !id.contains(" ") else { return nil }
                return seen.insert(id).inserted ? id : nil
            }
    }
}

/// Hand-authored voice cards for every bundled speaking Cast member. The
/// ordinary entity sheet remains the source of truth for biography and
/// motivation; these cards answer the narrower question "what does this person
/// sound like when the name is removed?" Reader-created Cast members continue
/// to receive a canon-derived voice at runtime.
enum CharacterVoiceCatalog {
    static let priorityCharacterIDs: [String] = [
        "penny-blackletter",
        "wicker-eddies",
        "zara-finch",
        "dr-inkrest",
        "dr-vellum",
        "headmistress-thorne",
        "serenity-brown",
        "professor-thaddeus-mook",
        "pippa-pilcrow"
    ]

    static let bundledCharacterIDs: [String] = priorityCharacterIDs + [
        "orion-blackthorn",
        "finn-bridges",
        "lysander-mosswood",
        "damien-nights",
        "melisande-blackwood",
        "min-seo-kim",
        "gwendolyn-mythwright",
        "lydia-boggle",
        "ambrose-trencher",
        "soren-ng",
        "professor-kyle-momort",
        "professor-eleanor-euphony",
        "professor-vivian-villanelle",
        "professor-cedric-stonebrook",
        "professor-luna-wispwood",
        "professor-permancer"
    ]

    static func profile(for id: String) -> WritingVoiceProfile? {
        switch id {
        case "penny-blackletter":
            return WritingVoiceProfile(
                register: "dry, exact, quietly warm; a records clerk who lets evidence make the joke",
                rhythm: "short attested fact, small qualifying turn, then one neatly filed opinion",
                diction: ["file", "attest", "record", "margin", "receipt", "exhibit"],
                habits: [
                    "notices the physical proof everyone else stepped over",
                    "places one understated opinion only after the evidence"
                ],
                avoid: [
                    "breathless whimsy",
                    "grand declarations before evidence",
                    "sounding like Wicker's courtroom cross-examination"
                ],
                exemplars: [
                    "The button was under the radiator. This is not a theory.",
                    "I have filed the thunder under Weather, Excessive."
                ]
            )
        case "wicker-eddies":
            return WritingVoiceProfile(
                register: "incisive, theatrical, amused by weak premises; dangerous because the argument is often useful",
                rhythm: "a quick challenge, a sharper counterexample, then a question that removes the floorboard",
                diction: ["premise", "prove", "test", "convenient", "counterfeit", "spectacle"],
                habits: [
                    "names the comforting assumption nobody else will touch",
                    "turns charm against itself without becoming merely cruel"
                ],
                avoid: [
                    "gentle therapeutic paraphrase",
                    "bureaucratic clerk language",
                    "constant sneering or villain monologues"
                ],
                exemplars: [
                    "Lovely story. Which part survives when nobody applauds?",
                    "I don't object to hope. I object to hope wearing forged papers."
                ]
            )
        case "zara-finch":
            return WritingVoiceProfile(
                register: "quick, practical, fiercely loyal; care expressed as readiness rather than reassurance",
                rhythm: "compact spoken sentences; she notices the exit, names the next useful move, then checks who is coming",
                diction: ["door", "key", "route", "pocket", "back way", "hold"],
                habits: [
                    "offers concrete help before discussing feelings",
                    "reveals vigilance through spatial details and contingency"
                ],
                avoid: [
                    "pep talks",
                    "mystical abstraction",
                    "making vigilance sound identical to tenderness"
                ],
                exemplars: [
                    "Take the side stair. It sticks, but it keeps its promises.",
                    "I've got the key. You decide whether we use it."
                ]
            )
        case "dr-inkrest":
            return WritingVoiceProfile(
                register: "gentle, precise, unhurried; curious without pretending uncertainty is wisdom",
                rhythm: "one exact reflection, room for a complication, then a single question that opens rather than corners",
                diction: ["page", "chair", "story", "exception", "name", "room"],
                habits: [
                    "echoes one concrete phrase before interpreting it",
                    "externalizes the problem while leaving the reader authority"
                ],
                avoid: [
                    "stacked questions",
                    "clinical jargon",
                    "generic validation or a tidy silver lining"
                ],
                exemplars: [
                    "You called it a locked room, not an empty one. What is still inside?",
                    "The worry has taken the best chair again. Must it keep it?"
                ]
            )
        case "dr-vellum":
            return WritingVoiceProfile(
                register: "warmly clinical, low-shame, experimentally curious; the body is evidence, never a grade",
                rhythm: "observation, modest hypothesis, one humane trial with a clear stopping edge",
                diction: ["signal", "before", "after", "dose", "pattern", "field note"],
                habits: [
                    "turns ordinary meals, sleep, or movement into kind field notes",
                    "states uncertainty plainly and keeps experiments small"
                ],
                avoid: [
                    "diagnosis",
                    "optimization bravado",
                    "Inkrest's story-and-chair metaphors"
                ],
                exemplars: [
                    "Breakfast is not a moral event. It is, however, excellent data.",
                    "Try it once. If the body objects, the experiment has answered."
                ]
            )
        case "headmistress-thorne":
            return WritingVoiceProfile(
                register: "elegant, watchful, institutionally dangerous; courtesy with an old lock inside it",
                rhythm: "measured clauses, exact conditions, and a final sentence that changes the status of the doorway",
                diction: ["threshold", "permission", "term", "house", "admit", "govern"],
                habits: [
                    "speaks as though the building is a third party to the conversation",
                    "makes rules sound beautiful enough to approach and costly enough to respect"
                ],
                avoid: [
                    "casual slang",
                    "obvious threats",
                    "generic regal grandeur"
                ],
                exemplars: [
                    "The door heard you. Whether it admits that is a separate matter.",
                    "You may cross. Permission, as ever, is not the same as safety."
                ]
            )
        case "serenity-brown":
            return WritingVoiceProfile(
                register: "bright, spontaneous, affectionate; joy that moves before the serious plan finishes",
                rhythm: "fast invitation, sensory detail, playful reversal; gravity may arrive but never gets the first word",
                diction: ["come on", "rain", "detour", "cold", "song", "again"],
                habits: [
                    "turns a nearby inconvenience into a shared escapade",
                    "lets affection appear through inclusion and motion"
                ],
                avoid: [
                    "motivational slogans",
                    "denying real consequences",
                    "Pippa's punctuation chaos"
                ],
                exemplars: [
                    "It's raining sideways. Good. The pavement has finally chosen a song.",
                    "We can be sensible after the bridge. The bridge hates an audience."
                ]
            )
        case "professor-thaddeus-mook":
            return WritingVoiceProfile(
                register: "school-term formal, pompous, lexically exact; secretly useful despite himself",
                rhythm: "ceremonial announcement, overqualified correction, reluctant practical instruction",
                diction: ["therefore", "definition", "sanctioned", "provisional", "clause", "inadmissible"],
                habits: [
                    "treats ordinary words as unruly pupils under his jurisdiction",
                    "uses excessive formality to conceal genuine fascination"
                ],
                avoid: [
                    "modern casual banter",
                    "random long words without logical precision",
                    "Pippa's run-on exhilaration"
                ],
                exemplars: [
                    "The adjective is provisionally excused. Its alibi, however, is nonsense.",
                    "Kindly define the puddle before it acquires further jurisdiction."
                ]
            )
        case "pippa-pilcrow":
            return WritingVoiceProfile(
                register: "giddy, affectionate, quick; punctuation behaves like a flock of barely supervised animals",
                rhythm: "breathless accumulation with one sudden clean landing; surprise marks are rare enough to matter",
                diction: ["comma", "dash", "almost", "oops", "again", "look"],
                habits: [
                    "physically notices punctuation moving, escaping, or changing sides",
                    "invites the other person into mischief rather than performing chaos alone"
                ],
                avoid: [
                    "interrobang spam",
                    "pure randomness",
                    "Mook's legalistic cadence"
                ],
                exemplars: [
                    "The comma slipped out after lunch and now the sentence can breathe—look.",
                    "I only moved one mark. The paragraph did the escaping."
                ]
            )
        case "orion-blackthorn":
            return WritingVoiceProfile(
                register: "brilliant, impatient, structurally minded; affection arrives disguised as a load-bearing solution",
                rhythm: "states the constraint, sketches an audacious structure, then tests where it will bear weight",
                diction: ["span", "load", "foundation", "brace", "draft", "structure"],
                habits: [
                    "turns emotional or practical trouble into spatial engineering",
                    "reveals care by building something another person can actually use"
                ],
                avoid: [
                    "generic inventor excitement",
                    "Soren's riddling maps and patient clues",
                    "forgetting the human cost of his proposed structure"
                ],
                exemplars: [
                    "The plan is impossible in three places. Fortunately, only two of them carry weight.",
                    "Stand there a moment. I built the brace for your height."
                ]
            )
        case "finn-bridges":
            return WritingVoiceProfile(
                register: "plainspoken, competitive, honorable; pressure offered face-to-face and without humiliation",
                rhythm: "clean challenge, observable standard, brief acknowledgment when effort earns it",
                diction: ["again", "clean", "effort", "round", "earned", "ready"],
                habits: [
                    "makes the terms of a challenge explicit before beginning",
                    "respects an honest attempt more readily than a charming excuse"
                ],
                avoid: [
                    "coach slogans",
                    "Kyle's impulsive threshold-crossing patter",
                    "treating gentleness as automatic weakness"
                ],
                exemplars: [
                    "No tricks. Same hill, same rain, and we both know where the line is.",
                    "You came back for the second round. That counts."
                ]
            )
        case "lysander-mosswood":
            return WritingVoiceProfile(
                register: "thoughtful, trail-wise, companionable; wisdom grounded in a place he has actually walked",
                rhythm: "notices a natural sign, offers a route, then leaves the meaning slightly open",
                diction: ["path", "bend", "moss", "marker", "weather", "return"],
                habits: [
                    "answers abstractions with terrain and repeatable routes",
                    "uses pressed leaves as modest evidence rather than mystical decoration"
                ],
                avoid: [
                    "oracular nature speech",
                    "Cedric's long resting silences",
                    "pretending stillness is effortless"
                ],
                exemplars: [
                    "Take the path past the split oak. It explains itself after the second bend.",
                    "This leaf was green last week. The trail is allowed to revise us."
                ]
            )
        case "damien-nights":
            return WritingVoiceProfile(
                register: "spare, nocturnal, guarded; doubt used as a shield for something he has not named",
                rhythm: "quiet observation, withheld conclusion, one precise warning or reluctant disclosure",
                diction: ["shadow", "watch", "yet", "light", "hide", "proof"],
                habits: [
                    "notices divided loyalties through light, sightlines, and silence",
                    "protects people indirectly, then resists credit for doing it"
                ],
                avoid: [
                    "purple gothic monologues",
                    "Wicker's delighted public argument",
                    "making silence automatically profound"
                ],
                exemplars: [
                    "Wicker saw the lie. He did not ask what it was protecting.",
                    "Keep out of the lamplight. Not forever. Just until they pass."
                ]
            )
        case "melisande-blackwood":
            return WritingVoiceProfile(
                register: "politically alert, polished, unsentimental; loyalty expressed through control of information",
                rhythm: "reports the public version, supplies the consequential correction, names who benefits",
                diction: ["version", "source", "heard", "useful", "faction", "cost"],
                habits: [
                    "distinguishes rumor, corroboration, and strategic omission",
                    "reads the room's incentives before judging its claims"
                ],
                avoid: [
                    "cartoon gossip",
                    "Penny's archival clerk cadence",
                    "calling every cruelty mere realism"
                ],
                exemplars: [
                    "That is the version being repeated. It is not the version people are acting on.",
                    "A secret is only impressive until you ask who profits from the silence."
                ]
            )
        case "min-seo-kim":
            return WritingVoiceProfile(
                register: "gentle, principled, quietly funny; care understood as shared courage rather than temperament",
                rhythm: "notices the excluded person or living thing, asks consent, then proposes a fair concrete adjustment",
                diction: ["ask", "room", "share", "root", "tend", "enough"],
                habits: [
                    "checks who or what has not been consulted",
                    "makes ethical objections softly but without yielding their substance"
                ],
                avoid: [
                    "saintly self-erasure",
                    "generic nurturing reassurance",
                    "Lydia's room-by-room domestic tactics"
                ],
                exemplars: [
                    "We can move the fern. We should ask why it leaned away first.",
                    "There is room in the circle. The shortage appears to be imagination."
                ]
            )
        case "gwendolyn-mythwright":
            return WritingVoiceProfile(
                register: "scholarly, odd, steadfast; impossible creatures receive the dignity of exact documentation",
                rhythm: "formal observation, peculiar supporting evidence, tender conclusion stated as a research necessity",
                diction: ["specimen", "sighting", "correspondence", "evidence", "habitat", "provisional"],
                habits: [
                    "documents wonder in field-report language without explaining it away",
                    "addresses fog, crows, and cryptids as legitimate correspondents"
                ],
                avoid: [
                    "breathless monster hunting",
                    "Penny's jokes about administrative evidence",
                    "Permancer's rules for entering authored worlds"
                ],
                exemplars: [
                    "The third footprint is absent. This is consistent with a creature that dislikes conclusions.",
                    "I have written to the fog. Its silence is not, at present, a refusal."
                ]
            )
        case "lydia-boggle":
            return WritingVoiceProfile(
                register: "domestic, wry, practical; household care conducted with the gravity of field operations",
                rhythm: "names the room-sized problem, prescribes one ordinary action, adds a dry domestic truth",
                diction: ["kettle", "drawer", "room", "tea", "shelf", "tidy"],
                habits: [
                    "turns tea, chores, and familiar objects into tactical interventions",
                    "locates chaos physically before attempting to solve it"
                ],
                avoid: [
                    "cozy platitudes",
                    "Min-seo's consent-and-circle ethics",
                    "tidying away the mystery itself"
                ],
                exemplars: [
                    "This is a kitchen-sized disaster. Put the kettle on accordingly.",
                    "The missing courage is probably in the hall drawer. Everything else is."
                ]
            )
        case "ambrose-trencher":
            return WritingVoiceProfile(
                register: "warm, blunt, unhurried; hunger and affection spoken through food without becoming sentimental",
                rhythm: "sensory fact, candid appetite, then a practical act of feeding that carries the unsaid thing",
                diction: ["taste", "ladle", "salt", "recipe", "hunger", "second"],
                habits: [
                    "describes unlived dishes with exact, almost homesick attention",
                    "offers food where another person might offer an explanation"
                ],
                avoid: [
                    "foodie rhapsody",
                    "Euphony's synesthetic musical elaboration",
                    "forcing every meal into a lesson"
                ],
                exemplars: [
                    "It needs salt. Most unfinished apologies do.",
                    "I have never tasted quince cooked this way. Sit down; we can be disappointed together."
                ]
            )
        case "soren-ng":
            return WritingVoiceProfile(
                register: "quiet, exact, pattern-minded; invitation concealed inside an elegant system",
                rhythm: "offers one clue, marks a relationship between details, stops before the discovery is stolen",
                diction: ["map", "line", "pattern", "mark", "between", "follow"],
                habits: [
                    "trusts diagrams and desire paths more than declarations",
                    "leaves enough of a system unexplained for another person to enter it"
                ],
                avoid: [
                    "Orion's monumental structural solutions",
                    "riddle-master theatrics",
                    "explaining the final pattern"
                ],
                exemplars: [
                    "The pavement says left. The grass has collected another opinion.",
                    "Mark where the three mistakes touch. I think that is the entrance."
                ]
            )
        case "professor-kyle-momort":
            return WritingVoiceProfile(
                register: "brisk, charismatic, kinetic; courage measured in the first intentional movement",
                rhythm: "verb-first instruction, moving observation, short permission to stop or choose again",
                diction: ["step", "move", "now", "door", "ten seconds", "choose"],
                habits: [
                    "teaches while walking and makes the first action physically specific",
                    "separates intentional movement from reckless flight"
                ],
                avoid: [
                    "motivational shouting",
                    "Finn's competitive terms and earned respect",
                    "equating escape with arrival"
                ],
                exemplars: [
                    "Stand up first. You may decide about bravery on the way to the door.",
                    "Ten seconds forward. Then we ask whether forward was wise."
                ]
            )
        case "professor-eleanor-euphony":
            return WritingVoiceProfile(
                register: "lush, attentive, resonant; sensory language disciplined by close listening",
                rhythm: "tunes the scene through sound or texture, develops one harmonic association, lands on the bodily fact",
                diction: ["listen", "tone", "hush", "resonance", "texture", "bright"],
                habits: [
                    "hears emotional weather as harmony without reducing it to mood",
                    "asks the senses for evidence before interpretation"
                ],
                avoid: [
                    "ornament for its own sake",
                    "Ambrose's blunt culinary appetite",
                    "turning one feeling into an entire symphony"
                ],
                exemplars: [
                    "Listen before you name it. The room has gone tin-bright around the edges.",
                    "That memory enters in a minor key, but your hands remember warmth."
                ]
            )
        case "professor-vivian-villanelle":
            return WritingVoiceProfile(
                register: "exacting, lyrical, kind; beauty must earn its place by being true",
                rhythm: "tests a sentence, removes its ornamental evasion, leaves one durable line",
                diction: ["sentence", "true", "weight", "keep", "cut", "word"],
                habits: [
                    "weighs language as though each word changes the object being kept",
                    "crosses out lovely phrases without humiliating their author"
                ],
                avoid: [
                    "workshop clichés",
                    "Luna's delighted accidents",
                    "polishing the living motion out of a memory"
                ],
                exemplars: [
                    "Beautiful, yes. But it did not happen. Give me the chipped cup.",
                    "Keep the last six words. They are the ones still breathing."
                ]
            )
        case "professor-cedric-stonebrook":
            return WritingVoiceProfile(
                register: "slow, grounded, weathered; rest offered as terrain rather than reward",
                rhythm: "allows a pause, names the body's present footing, gives one small return path",
                diction: ["rest", "ground", "bench", "weather", "return", "enough"],
                habits: [
                    "leaves deliberate silence without abandoning the person inside it",
                    "frames completion as returning safely, not conquering distance"
                ],
                avoid: [
                    "sleepy aphorisms",
                    "Lysander's leaf-marked route wisdom",
                    "waiting past the moment a clear instruction is kind"
                ],
                exemplars: [
                    "Sit until the bench becomes only a bench again.",
                    "Enough for today is still a direction. We can mark the return."
                ]
            )
        case "professor-luna-wispwood":
            return WritingVoiceProfile(
                register: "scattered, perceptive, delighted; accidents welcomed, observed, and given safe edges",
                rhythm: "bright interruption, apology to the object involved, precise noticing of what the mishap revealed",
                diction: ["oh", "spark", "ask", "object", "accident", "careful"],
                habits: [
                    "treats ordinary objects as opinionated collaborators",
                    "follows magical accidents far enough to learn, then remembers the safety boundary"
                ],
                avoid: [
                    "random manic whimsy",
                    "Vivian's sentence-pruning precision",
                    "forgetting that playful enchantments still need consent and limits"
                ],
                exemplars: [
                    "Oh—the toaster objects. Fairly, I think. We never asked about Thursdays.",
                    "Mind the blue spark. It is friendly, not house-trained."
                ]
            )
        case "professor-permancer":
            return WritingVoiceProfile(
                register: "precise, adventurous, safety-minded; awe accompanied by rules for returning intact",
                rhythm: "identifies the story-threshold, states the return condition, permits one measured crossing",
                diction: ["bookmark", "entrance", "return", "world", "threshold", "responsibility"],
                habits: [
                    "checks exits, bookmarks, and obligations before entering a story",
                    "treats fictional worlds as places with rights rather than consumable scenery"
                ],
                avoid: [
                    "timid proceduralism",
                    "Gwendolyn's cryptid field reports",
                    "letting perfect safety postpone wonder indefinitely"
                ],
                exemplars: [
                    "Mark the page you leave from. Stories dislike losing people between editions.",
                    "You may enter. First tell me what you owe the world you return to."
                ]
            )
        default:
            return nil
        }
    }
}

/// Conservative preflight budgeting for the 4,096-token rotating KV window.
/// It uses a deliberately cautious character estimate; actual prompt-token
/// counts are still captured by MLX completion receipts on-device.
enum LocalBrainPromptBudget {
    struct Fit: Equatable {
        var prompt: String
        var estimatedInputTokens: Int
        var inputBudgetTokens: Int
        var wasCompacted: Bool
        var preservedCharacterCanon: Bool
    }

    static let contextWindowTokens = 4_096
    static let safetyTokens = 192
    private static let conservativeCharactersPerToken = 3

    static func estimatedTokens(for text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / Double(conservativeCharactersPerToken))))
    }

    static func fit(
        prompt: String,
        instructions: String,
        maxOutputTokens: Int,
        contextWindowTokens: Int = contextWindowTokens
    ) -> Fit {
        let inputBudget = max(256, contextWindowTokens - maxOutputTokens - safetyTokens)
        let estimated = estimatedTokens(for: instructions + "\n" + prompt)
        guard estimated > inputBudget else {
            return Fit(
                prompt: prompt,
                estimatedInputTokens: estimated,
                inputBudgetTokens: inputBudget,
                wasCompacted: false,
                preservedCharacterCanon: prompt.contains(CharacterCanonPacket.endMarker)
            )
        }

        let instructionCharacters = min(
            instructions.count,
            inputBudget * conservativeCharactersPerToken / 3
        )
        let promptCharacterBudget = max(
            768,
            inputBudget * conservativeCharactersPerToken - instructionCharacters
        )
        let canonRange = characterCanonRange(in: prompt)
        let canon = canonRange.map { String(prompt[$0]) } ?? ""
        let remainder = canonRange.map { prompt.replacingCharacters(in: $0, with: "") } ?? prompt
        let marker = "\n\n[Earlier supporting prompt material compacted to protect the writing contract.]\n\n"
        let protectedBudget = canon.isEmpty ? 0 : min(canon.count, promptCharacterBudget * 45 / 100)
        let protectedCanon = clipMiddle(canon, limit: protectedBudget)
        let remainingBudget = max(256, promptCharacterBudget - protectedCanon.count - marker.count)
        let headBudget = remainingBudget * 42 / 100
        let tailBudget = remainingBudget - headBudget
        let head = String(remainder.prefix(headBudget))
        let tail = String(remainder.suffix(tailBudget))
        let fitted = [head, marker, protectedCanon, tail]
            .filter { !$0.isEmpty }
            .joined()

        return Fit(
            prompt: String(fitted.prefix(promptCharacterBudget)),
            estimatedInputTokens: estimated,
            inputBudgetTokens: inputBudget,
            wasCompacted: true,
            preservedCharacterCanon: canon.isEmpty || fitted.contains(CharacterCanonPacket.endMarker)
        )
    }

    private static func characterCanonRange(in prompt: String) -> Range<String.Index>? {
        guard let start = prompt.range(of: "CHARACTER CANON —")?.lowerBound,
              let endMarker = prompt.range(
                of: CharacterCanonPacket.endMarker,
                range: start..<prompt.endIndex
              ) else {
            return nil
        }
        return start..<endMarker.upperBound
    }

    private static func clipMiddle(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        let marker = "\n[Character sheet compacted]\n"
        let usable = max(0, limit - marker.count)
        let head = String(text.prefix(usable / 2))
        let tail = String(text.suffix(usable - usable / 2))
        return head + marker + tail
    }
}

struct CharacterVoiceEvaluationScenario: Identifiable, Equatable {
    var id: String
    var characterIDs: [String]
    var surface: String
    var scene: String
    var identificationClues: [String]
    var forbiddenTransfers: [String]
}

/// Synthetic, private-data-free prompts used by the development-only E2B
/// evaluation runner. Pair scenes deliberately place neighboring voices beside
/// one another; the hardest test is recognition after speaker names are hidden.
enum CharacterVoiceEvaluationDeck {
    static let scenarios: [CharacterVoiceEvaluationScenario] = [
        .init(
            id: "penny-wicker-misfiled-key",
            characterIDs: ["penny-blackletter", "wicker-eddies"],
            surface: "Gossip Page",
            scene: "A brass key has been filed under Weather. Penny has the receipt. Wicker thinks the filing proves the rule is counterfeit.",
            identificationClues: ["Penny leads with evidence", "Wicker attacks the premise"],
            forbiddenTransfers: ["Penny performs theatrical cross-examination", "Wicker speaks like a records clerk"]
        ),
        .init(
            id: "zara-serenity-rain-door",
            characterIDs: ["zara-finch", "serenity-brown"],
            surface: "Story Page",
            scene: "A side door is swelling shut in hard rain. Zara has the key and an exit plan. Serenity wants the detour before the weather changes its mind.",
            identificationClues: ["Zara expresses care through a practical route", "Serenity invites shared motion and play"],
            forbiddenTransfers: ["Zara gives a pep talk", "Serenity ignores the real obstruction"]
        ),
        .init(
            id: "inkrest-vellum-breakfast-page",
            characterIDs: ["dr-inkrest", "dr-vellum"],
            surface: "Support Guild",
            scene: "The reader's synthetic chart says breakfast was skipped twice and the phrase 'the room got smaller' appeared once. The doctors must disagree gently about what to notice next.",
            identificationClues: ["Inkrest works with the phrase and preferred story", "Vellum proposes a bounded observation"],
            forbiddenTransfers: ["Inkrest prescribes", "Vellum diagnoses or uses narrative-therapy language"]
        ),
        .init(
            id: "thorne-threshold-permission",
            characterIDs: ["headmistress-thorne"],
            surface: "Letter",
            scene: "A school door has granted entry but not safety. Thorne writes the exact condition under which it may be crossed.",
            identificationClues: ["courtesy carries governance", "the building is treated as a listening party"],
            forbiddenTransfers: ["casual banter", "an explicit cartoon threat"]
        ),
        .init(
            id: "mook-pippa-runaway-comma",
            characterIDs: ["professor-thaddeus-mook", "pippa-pilcrow"],
            surface: "Academy Class",
            scene: "A comma has abandoned a definition during roll call. Mook opens disciplinary proceedings. Pippa knows where it went and why it left.",
            identificationClues: ["Mook is ceremonially precise", "Pippa's quick mischief lands on one clear observation"],
            forbiddenTransfers: ["Mook becomes random", "Pippa speaks in legal clauses or punctuation spam"]
        ),
        .init(
            id: "orion-soren-impossible-footbridge",
            characterIDs: ["orion-blackthorn", "soren-ng"],
            surface: "Two Readings",
            scene: "A footbridge exists on no official plan. Orion wants to calculate how it stands; Soren notices that the worn grass approaches it from the wrong direction.",
            identificationClues: ["Orion reasons through loads and structures", "Soren offers a pattern without completing it"],
            forbiddenTransfers: ["Orion becomes a riddling cartographer", "Soren proposes a monumental engineered solution"]
        ),
        .init(
            id: "finn-kyle-first-step",
            characterIDs: ["finn-bridges", "professor-kyle-momort"],
            surface: "Academy Class",
            scene: "A student has returned to a daunting stair after stopping yesterday. Finn wants fair terms for another attempt. Kyle wants the first ten seconds to begin before fear finishes speaking.",
            identificationClues: ["Finn defines an honorable challenge", "Kyle gives a verb-first moving instruction"],
            forbiddenTransfers: ["Finn delivers a motivational speech", "Kyle turns the moment into a competition"]
        ),
        .init(
            id: "lysander-cedric-rain-bench",
            characterIDs: ["lysander-mosswood", "professor-cedric-stonebrook"],
            surface: "Compass Run",
            scene: "Rain has erased a trail marker beside a sheltered bench. Lysander can read the living route; Cedric thinks returning may be the day's proper completion.",
            identificationClues: ["Lysander reads terrain and offers a path", "Cedric treats rest and return as valid directions"],
            forbiddenTransfers: ["Lysander becomes a nature oracle", "Cedric answers with leaf lore"]
        ),
        .init(
            id: "damien-melisande-third-version",
            characterIDs: ["damien-nights", "melisande-blackwood"],
            surface: "Gossip Page",
            scene: "A rumor says Wicker sabotaged a lantern test. Damien knows what the darkness protected. Melisande knows which version the faction is using.",
            identificationClues: ["Damien warns through guarded light and shadow details", "Melisande separates rumor from politically useful belief"],
            forbiddenTransfers: ["Damien performs public cross-examination", "Melisande dissolves into cartoon gossip"]
        ),
        .init(
            id: "minseo-lydia-crowded-kitchen",
            characterIDs: ["min-seo-kim", "lydia-boggle"],
            surface: "Letter",
            scene: "A kitchen worktable is crowded with neglected plants, cold tea, and one chair too few. Min-seo notices who was never consulted. Lydia sizes up the room-sized intervention.",
            identificationClues: ["Min-seo grounds care in consent and inclusion", "Lydia answers with a dry household tactic"],
            forbiddenTransfers: ["Min-seo becomes saintly reassurance", "Lydia speaks in ethical-circle abstractions"]
        ),
        .init(
            id: "gwendolyn-permancer-missing-footprint",
            characterIDs: ["gwendolyn-mythwright", "professor-permancer"],
            surface: "Faculty Research",
            scene: "Three footprints enter the illustrated forest in a book, but only two return to the margin. Gwendolyn documents the possible creature. Permancer checks what crossing obligation was missed.",
            identificationClues: ["Gwendolyn gives the impossible exact field dignity", "Permancer establishes entry and return conditions"],
            forbiddenTransfers: ["Gwendolyn becomes a portal safety officer", "Permancer writes a cryptid report"]
        ),
        .init(
            id: "ambrose-euphony-memory-soup",
            characterIDs: ["ambrose-trencher", "professor-eleanor-euphony"],
            surface: "Story Page",
            scene: "A soup tastes almost like a vanished family recipe. Ambrose names what the bowl lacks. Euphony hears the year returning in the room before anyone speaks.",
            identificationClues: ["Ambrose is bluntly sensory and feeds the unsaid feeling", "Euphony listens for resonance and lands in the body"],
            forbiddenTransfers: ["Ambrose becomes florid synesthesia", "Euphony turns the scene into food criticism"]
        ),
        .init(
            id: "vivian-luna-true-accident",
            characterIDs: ["professor-vivian-villanelle", "professor-luna-wispwood"],
            surface: "Academy Class",
            scene: "An enchanted typewriter replaces a beautiful false adjective with a small true noun. Vivian evaluates the sentence. Luna asks the machine what accident it intended.",
            identificationClues: ["Vivian cuts beauty that is not true", "Luna treats the object as a delighted but bounded collaborator"],
            forbiddenTransfers: ["Vivian follows the magical accident away from the sentence", "Luna becomes an exacting prose editor"]
        )
    ]
}

struct CharacterGenerationRouteContract: Identifiable, Equatable {
    enum Enforcement: String, Equatable {
        case sharedCanonAndAudit
        case specializedVoiceContract
    }

    var id: String
    var enforcement: Enforcement
    var note: String
}

/// An inspectable coverage map for every current character-shaped local-model
/// route. Specialized routes have their own narrower safety/voice grammar;
/// everything else must carry CharacterCanonPacket and use the shared reviewer.
enum CharacterGenerationRouteRegistry {
    static let routes: [CharacterGenerationRouteContract] = [
        .init(id: "story-page", enforcement: .sharedCanonAndAudit, note: "opening vignette"),
        .init(id: "story-page-result", enforcement: .sharedCanonAndAudit, note: "selected consequence"),
        .init(id: "academy-class-page", enforcement: .sharedCanonAndAudit, note: "faculty and companions"),
        .init(id: "fae-parley-", enforcement: .sharedCanonAndAudit, note: "Book Fae opening and result prefix"),
        .init(id: "gossip-page", enforcement: .sharedCanonAndAudit, note: "offscreen Cast motion"),
        .init(id: "faculty-research", enforcement: .sharedCanonAndAudit, note: "named faculty folio"),
        .init(id: "letter-page", enforcement: .sharedCanonAndAudit, note: "Cast correspondence"),
        .init(id: "student-notes", enforcement: .sharedCanonAndAudit, note: "folded Cast notes"),
        .init(id: "two-readings", enforcement: .sharedCanonAndAudit, note: "paired disagreement"),
        .init(id: "cast-bond", enforcement: .sharedCanonAndAudit, note: "relationship threshold"),
        .init(id: "support-guild", enforcement: .sharedCanonAndAudit, note: "Inkrest and Vellum"),
        .init(id: "unwritten-elective", enforcement: .sharedCanonAndAudit, note: "character favor"),
        .init(id: "the-bleed", enforcement: .sharedCanonAndAudit, note: "Penny's columns"),
        .init(id: "inkrest-office-hours", enforcement: .specializedVoiceContract, note: "dedicated narrative-therapy and safety grammar"),
        .init(id: "fae-bargain", enforcement: .specializedVoiceContract, note: "per-kind Fae law and voice directive"),
        .init(id: "tarot-aurora", enforcement: .specializedVoiceContract, note: "Aurora's reading and safety grammar"),
        .init(id: "goblin-clerk", enforcement: .specializedVoiceContract, note: "short mercantile shop voice")
    ]

    static func contract(for sourceID: String) -> CharacterGenerationRouteContract? {
        routes.first { route in
            route.id.hasSuffix("-") ? sourceID.hasPrefix(route.id) : route.id == sourceID
        }
    }
}

struct CustomCastMember: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var kind: NarrativeEntityKind
    var meaning: String
    var description: String
    var traits: [String]
    var beliefs: [String]
    var goals: [String]
    var tags: [String]
    var baseBelief: Int
    var narrativeWeight: Int
    var createdAt: Date
    var updatedAt: Date
    var imageAsset: BookPageMediaAsset?

    var entity: NarrativeWorldEntity {
        NarrativeWorldEntity(
            id: id,
            packID: "user-cast",
            name: name,
            kind: kind,
            belief: baseBelief,
            narrativeWeight: narrativeWeight,
            chapter: nil,
            unwrittenInterest: meaning,
            traits: traits.isEmpty ? ["user-made"] : traits,
            quirks: description.isEmpty ? [] : [description],
            faults: [],
            beliefs: beliefs.isEmpty ? [meaning].filter { !$0.isEmpty } : beliefs,
            goals: goals,
            tags: Array(Set(tags + ["custom-cast", "user-made", kind.rawValue])).sorted()
        )
    }
}

struct NarrativeStoryThread: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var title: String
    var phase: StoryThreadPhase
    var belief: Int
    var narrativeWeight: Int
    var summary: String
    var tags: [String]
}

struct NarrativeRelationshipEdge: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var sourceEntityID: String
    var targetEntityID: String
    var kind: NarrativeRelationshipKind
    var warmth: Int
    var tension: Int
    var trust: Int
    var narrativeWeight: Int
    var note: String
    var tags: [String]
}

struct NarrativeEntityMemory: Identifiable, Codable, Equatable {
    var id: String
    var entityID: String
    var sourceEventID: String
    var sourcePageID: String?
    var summary: String
    var tags: [String]
    var narrativeWeight: Int
    var createdAt: Date
}

struct NarrativePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: ContentPackAvailability
    var entities: [NarrativeWorldEntity]
    var threads: [NarrativeStoryThread]
    var relationships: [NarrativeRelationshipEdge]
}

enum NarrativeEventKind: String, Codable, Equatable, CaseIterable {
    case pageKept
    case pageAnswered
    case choiceSelected
    case beliefInvested
    case beliefAttacked
    case threadAdvanced
    case entityNoticed
    case letterReceived
    case compassRunCompleted
    case enchantmentCompleted
    case simulationTurn
}

struct NarrativeEventEffect: Codable, Equatable {
    var beliefDelta: Int
    var entityWeightDeltas: [String: Int]
    var threadWeightDeltas: [String: Int]
    var relationshipWeightDeltas: [String: Int]
    var createdEntityHint: String?
    var entityMemoryWrites: [NarrativeEntityMemoryWrite]?

    init(
        beliefDelta: Int = 0,
        entityWeightDeltas: [String: Int] = [:],
        threadWeightDeltas: [String: Int] = [:],
        relationshipWeightDeltas: [String: Int] = [:],
        createdEntityHint: String? = nil,
        entityMemoryWrites: [NarrativeEntityMemoryWrite]? = nil
    ) {
        self.beliefDelta = beliefDelta
        self.entityWeightDeltas = entityWeightDeltas
        self.threadWeightDeltas = threadWeightDeltas
        self.relationshipWeightDeltas = relationshipWeightDeltas
        self.createdEntityHint = createdEntityHint
        self.entityMemoryWrites = entityMemoryWrites
    }

    func merging(_ other: NarrativeEventEffect) -> NarrativeEventEffect {
        var merged = self
        merged.beliefDelta += other.beliefDelta
        for (id, delta) in other.entityWeightDeltas {
            merged.entityWeightDeltas[id, default: 0] += delta
        }
        for (id, delta) in other.threadWeightDeltas {
            merged.threadWeightDeltas[id, default: 0] += delta
        }
        for (id, delta) in other.relationshipWeightDeltas {
            merged.relationshipWeightDeltas[id, default: 0] += delta
        }
        if merged.createdEntityHint?.isEmpty ?? true {
            merged.createdEntityHint = other.createdEntityHint
        }
        let writes = (merged.entityMemoryWrites ?? []) + (other.entityMemoryWrites ?? [])
        merged.entityMemoryWrites = writes.isEmpty ? nil : writes
        return merged
    }
}

struct NarrativeEntityMemoryWrite: Codable, Equatable {
    var entityID: String
    var summary: String
    var tags: [String]
    var narrativeWeight: Int

    init(entityID: String, summary: String, tags: [String] = [], narrativeWeight: Int = 4) {
        self.entityID = entityID
        self.summary = summary
        self.tags = tags
        self.narrativeWeight = narrativeWeight
    }
}

struct NarrativeEvent: Identifiable, Codable, Equatable {
    var id: String
    var kind: NarrativeEventKind
    var sourcePageType: BookPageType?
    var sourcePageID: String?
    var createdAt: Date
    var summary: String
    var tags: [String]
    var effect: NarrativeEventEffect
}

struct NarrativeStoryFieldProjection: Equatable {
    var entityWeights: [String: Int]
    var threadWeights: [String: Int]
    var relationshipWeights: [String: Int]
    var belief: Int

    var topEntityIDs: [String] {
        ranked(entityWeights)
    }

    var topThreadIDs: [String] {
        ranked(threadWeights)
    }

    var topRelationshipIDs: [String] {
        ranked(relationshipWeights)
    }

    private func ranked(_ weights: [String: Int], limit: Int = 8) -> [String] {
        weights
            .sorted { left, right in
                if left.value == right.value {
                    return left.key < right.key
                }
                return left.value > right.value
            }
            .prefix(limit)
            .map(\.key)
    }
}

/// One living tie between two entities in the relationship field. Accumulates
/// from real events and is layered over authored base edges by the Loom.
struct RelationshipTie: Codable, Equatable {
    var warmth: Int = 0
    var tension: Int = 0
    var familiarity: Int = 0

    static let zero = RelationshipTie()

    mutating func add(warmth dw: Int = 0, tension dt: Int = 0, familiarity df: Int = 0, cap: Int = 40) {
        warmth = max(-cap, min(cap, warmth + dw))
        tension = max(0, min(cap, tension + dt))
        familiarity = max(0, min(cap, familiarity + df))
    }
}

/// Mutates the dynamic relationship field as the world happens — the engine of
/// the relationship simulation. Pure; the app persists the field in the vault.
enum RelationshipFieldEngine {
    /// Weave every pair among these entities by the given deltas (e.g. sharing a
    /// story scene warms them; being judged against each other tenses them).
    static func weave(
        into field: inout [String: RelationshipTie],
        entityIDs: [String],
        warmth: Int = 0,
        tension: Int = 0,
        familiarity: Int = 0
    ) {
        let ids = Array(Set(entityIDs.filter { !$0.isEmpty })).sorted()
        guard ids.count >= 2 else { return }
        for i in ids.indices {
            for j in ids.indices where j > i {
                let key = NarrativeGraphData.relationshipPairKey(ids[i], ids[j])
                var tie = field[key] ?? .zero
                tie.add(warmth: warmth, tension: tension, familiarity: familiarity)
                field[key] = tie
            }
        }
    }

    /// Entity IDs carried by a kept page's tags (entity:<id>).
    static func entityIDs(fromTags tags: [String]) -> [String] {
        tags.compactMap { tag in
            tag.hasPrefix("entity:") ? String(tag.dropFirst("entity:".count)) : nil
        }
    }
}

// MARK: - Emergent cast bonds
//
// The relationship field doesn't just record — it *acts*. When a pair's tension
// or warmth crosses a milestone, a bond surfaces on its own: a rivalry erupts or
// an alliance forms. The web you've been shaping starts telling its own stories.

enum CastBondKind: String, Codable, Equatable {
    case rivalry   // tension crossed a milestone
    case alliance  // warmth crossed a milestone
}

struct CastBond: Codable, Equatable, Identifiable {
    var id: String
    var firedKey: String   // the milestone key (so it fires once)
    var pairKey: String
    var aID: String
    var bID: String
    var aName: String
    var bName: String
    var kind: CastBondKind
    var intensity: Int
    var at: Date
}

enum CastBondEngine {
    static let milestone = 8

    /// Bonds whose milestone the field has newly crossed (not already fired).
    static func emergent(
        field: [String: RelationshipTie],
        names: [String: String],
        firedKeys: Set<String>,
        now: Date = Date()
    ) -> [CastBond] {
        var bonds: [CastBond] = []
        func name(_ id: String) -> String { names[id] ?? id }
        func consider(_ pairKey: String, _ ids: [String], kind: CastBondKind, value: Int) {
            guard value >= milestone, ids.count == 2 else { return }
            let level = value / milestone
            let firedKey = "\(pairKey):\(kind.rawValue):\(level)"
            guard !firedKeys.contains(firedKey) else { return }
            bonds.append(CastBond(
                id: "bond-\(firedKey)",
                firedKey: firedKey,
                pairKey: pairKey,
                aID: ids[0], bID: ids[1],
                aName: name(ids[0]), bName: name(ids[1]),
                kind: kind, intensity: value, at: now
            ))
        }
        for (pairKey, tie) in field {
            let ids = pairKey.split(separator: "|").map(String.init)
            if tie.tension > tie.warmth {
                consider(pairKey, ids, kind: .rivalry, value: tie.tension)
            } else if tie.warmth > tie.tension {
                consider(pairKey, ids, kind: .alliance, value: tie.warmth)
            }
        }
        return bonds.sorted { $0.intensity > $1.intensity }
    }
}

enum NarrativeStoryFieldProjector {
    static func projection(events: [NarrativeEvent], baseBelief: Int = 30) -> NarrativeStoryFieldProjection {
        let recentRelationshipTouchBoost = 12
        var entityWeights = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.entities
            .filter { $0.kind != .talisman }
            .map { ($0.id, $0.narrativeWeight + $0.belief) })
        var threadWeights = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.threads.map {
            ($0.id, $0.narrativeWeight + $0.belief)
        })
        var relationshipWeights = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.relationships.map {
            ($0.id, $0.narrativeWeight + $0.warmth + $0.trust - $0.tension)
        })
        var belief = baseBelief

        for event in events {
            belief += event.effect.beliefDelta
            for (id, delta) in event.effect.entityWeightDeltas {
                entityWeights[id, default: 0] += delta
            }
            for (id, delta) in event.effect.threadWeightDeltas {
                threadWeights[id, default: 0] += delta
            }
            for (id, delta) in event.effect.relationshipWeightDeltas {
                relationshipWeights[id, default: 0] += delta
                if delta != 0 {
                    relationshipWeights[id, default: 0] += recentRelationshipTouchBoost
                }
            }
        }

        return NarrativeStoryFieldProjection(
            entityWeights: entityWeights,
            threadWeights: threadWeights,
            relationshipWeights: relationshipWeights,
            belief: min(100, max(0, belief))
        )
    }
}

enum NarrativeEntityMemoryResolver {
    static func memories(for event: NarrativeEvent) -> [NarrativeEntityMemory] {
        let explicit = (event.effect.entityMemoryWrites ?? [])
            .filter { !$0.entityID.isEmpty && !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, write in
                NarrativeEntityMemory(
                    id: "entity-memory-\(event.id)-explicit-\(index + 1)-\(write.entityID)",
                    entityID: write.entityID,
                    sourceEventID: event.id,
                    sourcePageID: event.sourcePageID,
                    summary: write.summary,
                    tags: Array(Set(event.tags + write.tags)).sorted(),
                    narrativeWeight: max(1, write.narrativeWeight),
                    createdAt: event.createdAt
                )
            }
        let entityIDs = event.effect.entityWeightDeltas
            .filter { $0.value > 0 }
            .sorted { left, right in
                if left.value == right.value {
                    return left.key < right.key
                }
                return left.value > right.value
            }
            .prefix(5)
            .map(\.key)

        let derived = entityIDs.map { entityID in
            NarrativeEntityMemory(
                id: "entity-memory-\(event.id)-\(entityID)",
                entityID: entityID,
                sourceEventID: event.id,
                sourcePageID: event.sourcePageID,
                summary: memorySummary(for: entityID, event: event),
                tags: event.tags,
                narrativeWeight: max(1, event.effect.entityWeightDeltas[entityID] ?? 1),
                createdAt: event.createdAt
            )
        }
        return explicit + derived
    }

    private static func memorySummary(for entityID: String, event: NarrativeEvent) -> String {
        let entityName = NarrativePackRegistry.entities.first(where: { $0.id == entityID })?.name ?? entityID
        let pageName = event.sourcePageType?.shortTitle ?? "page"
        let trimmedSummary = event.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSummary.isEmpty {
            return "\(entityName) remembers that a \(pageName.lowercased()) page changed the margins."
        }
        return "\(entityName) remembers: \(trimmedSummary)"
    }
}

struct StoryConsequencePack: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var version: Int
    var author: String
    var availability: ContentPackAvailability
    var bundles: [StoryConsequenceBundle]
}

struct StoryConsequenceBundle: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var when: StoryConsequenceCondition
    var atoms: [StoryConsequenceAtom]
    var memoryTemplate: String?

    init(
        id: String,
        label: String,
        when: StoryConsequenceCondition,
        atoms: [StoryConsequenceAtom],
        memoryTemplate: String? = nil
    ) {
        self.id = id
        self.label = label
        self.when = when
        self.atoms = atoms
        self.memoryTemplate = memoryTemplate
    }
}

struct StoryConsequenceWorldSnapshot: Equatable {
    var storyRituals: [String: Int] = [:]

    func ritualCount(for key: String) -> Int {
        storyRituals[StoryConsequenceCondition.key(key)] ?? 0
    }
}

struct StoryConsequenceCondition: Codable, Equatable {
    var choiceRoles: [String]? = nil
    var pageTypes: [BookPageType]? = nil
    var tagsAny: [String]? = nil
    var tagsAll: [String]? = nil
    var textContainsAny: [String]? = nil
    var textContainsAll: [String]? = nil
    /// Counts are read before this page's consequence atoms are applied.
    /// Exact tenth repeat: `ritualCountsAtLeast[key] = 9` and
    /// `ritualCountsBelow[key] = 10`, then increment the same key by 1.
    var ritualCountsAtLeast: [String: Int]? = nil
    var ritualCountsBelow: [String: Int]? = nil

    func matches(
        page: BookPage,
        choiceID: String,
        world: StoryConsequenceWorldSnapshot = StoryConsequenceWorldSnapshot()
    ) -> Bool {
        let tags = Set(page.tags.map(Self.key))
        let text = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
        if let choiceRoles, !choiceRoles.isEmpty,
           !choiceRoles.map(Self.choiceKey).contains(Self.choiceKey(choiceID)) {
            return false
        }
        if let pageTypes, !pageTypes.isEmpty, !pageTypes.contains(page.type) {
            return false
        }
        if let tagsAny, !tagsAny.isEmpty,
           !tagsAny.map(Self.key).contains(where: { tags.contains($0) }) {
            return false
        }
        if let tagsAll, !tagsAll.isEmpty,
           !tagsAll.map(Self.key).allSatisfy({ tags.contains($0) }) {
            return false
        }
        if let textContainsAny, !textContainsAny.isEmpty,
           !textContainsAny.map({ $0.lowercased() }).contains(where: { text.contains($0) }) {
            return false
        }
        if let textContainsAll, !textContainsAll.isEmpty,
           !textContainsAll.map({ $0.lowercased() }).allSatisfy({ text.contains($0) }) {
            return false
        }
        if let ritualCountsAtLeast, !ritualCountsAtLeast.isEmpty,
           !ritualCountsAtLeast.allSatisfy({ key, required in
               world.ritualCount(for: key) >= required
           }) {
            return false
        }
        if let ritualCountsBelow, !ritualCountsBelow.isEmpty,
           !ritualCountsBelow.allSatisfy({ key, ceiling in
               world.ritualCount(for: key) < ceiling
           }) {
            return false
        }
        return true
    }

    static func key(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"([a-z0-9])([A-Z])"#,
                with: "$1-$2",
                options: .regularExpression
            )
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == ":" }
    }

    private static func choiceKey(_ value: String) -> String {
        key(value)
            .replacingOccurrences(of: "slice-of-life", with: "sliceoflife")
            .replacingOccurrences(of: "sliceoflife", with: "sliceoflife")
            .replacingOccurrences(of: "progress-arc", with: "progressarc")
            .replacingOccurrences(of: "something-surprising", with: "surprise")
    }
}

/// Pack-authored atom. `type` is intentionally a string: unknown future atom
/// types decode cleanly and are ignored by older app builds.
struct StoryConsequenceAtom: Codable, Equatable {
    var type: String
    var target: String?
    var targets: [String]?
    var amount: Int?
    var warmth: Int?
    var tension: Int?
    var familiarity: Int?
    var value: String?
    var recipeID: String?
    var entityID: String?
    var faeKind: String?
    var template: String?
}

struct StoryRelationshipTieDelta: Codable, Equatable {
    var entityIDs: [String]
    var warmth: Int
    var tension: Int
    var familiarity: Int
}

struct StoryResolvedConsequence: Equatable {
    var choiceID: String
    var bundleIDs: [String] = []
    var beliefDelta: Int = 0
    var entityBeliefDeltas: [String: Int] = [:]
    var entityWeightDeltas: [String: Int] = [:]
    var threadWeightDeltas: [String: Int] = [:]
    var relationshipWeightDeltas: [String: Int] = [:]
    var relationshipTieDeltas: [StoryRelationshipTieDelta] = []
    var entityMemoryWrites: [NarrativeEntityMemoryWrite] = []
    var eventTags: [String] = []
    var motifs: [String] = []
    var futureRecipeBoosts: [String: Int] = [:]
    var bookNoticeEvidenceDelta: Int = 0
    var faeWarmthDeltas: [String: Int] = [:]
    var faeAttentionDelta: Int = 0
    var nothingGreyDelta: Int = 0
    var chapterTalismanDeltas: [String: Int] = [:]
    var worldEventTouches: [String] = []
    var radioBanterHooks: [String] = []
    var monthlyEditionLines: [String] = []
    var ritualLedgerDeltas: [String: Int] = [:]
    var settingAffinityDeltas: [String: Int] = [:]
    var sceneBiasDeltas: [String: Int] = [:]

    var isEmpty: Bool {
        beliefDelta == 0 &&
            entityBeliefDeltas.isEmpty &&
            entityWeightDeltas.isEmpty &&
            threadWeightDeltas.isEmpty &&
            relationshipWeightDeltas.isEmpty &&
            relationshipTieDeltas.isEmpty &&
            entityMemoryWrites.isEmpty &&
            eventTags.isEmpty &&
            futureRecipeBoosts.isEmpty &&
            bookNoticeEvidenceDelta == 0 &&
            faeWarmthDeltas.isEmpty &&
            faeAttentionDelta == 0 &&
            nothingGreyDelta == 0 &&
            chapterTalismanDeltas.isEmpty &&
            worldEventTouches.isEmpty &&
            radioBanterHooks.isEmpty &&
            monthlyEditionLines.isEmpty &&
            ritualLedgerDeltas.isEmpty &&
            settingAffinityDeltas.isEmpty &&
            sceneBiasDeltas.isEmpty
    }

    var textureLine: String? {
        if nothingGreyDelta < 0 { return "The grey recedes a little." }
        if nothingGreyDelta > 0 { return "The unmentioned thing stays cold." }
        if !ritualLedgerDeltas.isEmpty { return "The ritual remembers the repeat." }
        if !sceneBiasDeltas.isEmpty { return "The next scene learns the weather." }
        if !faeWarmthDeltas.isEmpty { return "Old courtesy warms in the margins." }
        if eventTags.contains("sentence-opened") { return "A kept sentence opens a door." }
        if eventTags.contains("mended-object") || eventTags.contains("lamp-mended") { return "The room remembers the repair." }
        if eventTags.contains("care-fed") { return "Care becomes part of the weather." }
        if eventTags.contains("rain-sheltered") { return "The shelter holds." }
        if eventTags.contains("relationship-charged") { return "The connection keeps its charge." }
        if eventTags.contains("secret-protected") { return "The secret stays protected, not solved." }
        if eventTags.contains("owed-answer") { return "A return is now owed." }
        if eventTags.contains("threshold-crossed") { return "The threshold keeps score." }
        if !futureRecipeBoosts.isEmpty { return "A future page leans toward this shape." }
        if bookNoticeEvidenceDelta > 0 { return "The Book notices the evidence." }
        if beliefDelta > 0 { return "Belief gathers around the choice." }
        return nil
    }

    var eventEffect: NarrativeEventEffect {
        NarrativeEventEffect(
            beliefDelta: beliefDelta,
            entityWeightDeltas: entityWeightDeltas.merging(entityBeliefDeltas) { $0 + $1 },
            threadWeightDeltas: threadWeightDeltas,
            relationshipWeightDeltas: relationshipWeightDeltas,
            createdEntityHint: motifs.isEmpty ? nil : "A motif can return later: \(motifs.prefix(3).joined(separator: ", ")).",
            entityMemoryWrites: entityMemoryWrites.isEmpty ? nil : entityMemoryWrites
        )
    }
}

enum StoryConsequenceRegistry {
    static let userPackFileSuffix = ".storyconsequences.json"

    static let bundledPacks: [StoryConsequencePack] = [
        StoryConsequencePack(
            id: "core-story-consequences",
            displayName: "Core Story Consequences",
            version: 1,
            author: "The Book",
            availability: .bundledFree,
            bundles: coreBundles
        )
    ]

    static var coreBundles: [StoryConsequenceBundle] {
        [
            bundle("slice-attention", "Slice of Life: Attention Deepens",
                   choice: "sliceoflife",
                   atoms: [
                       atom("beliefDelta", amount: 1),
                       atom("entityBeliefDelta", target: "{{leadEntity}}", amount: 1),
                       atom("relationshipWeightDelta", target: "book-authors-reader", amount: 1),
                       tie(targets: ["{{sceneEntities}}"], warmth: 1, familiarity: 1),
                       atom("bookNoticeEvidenceDelta", amount: 1),
                       atom("pageTag", value: "changed-texture")
                   ],
                   memory: "{{leadName}} remembers that the reader stayed with the ordinary detail until it became specific."),
            bundle("progress-arc-movement", "Progress Arc: Thread Moves",
                   choice: "progressarc",
                   atoms: [
                       atom("beliefDelta", amount: 1),
                       atom("threadWeightDelta", target: "{{activeThread}}", amount: 3),
                       atom("relationshipWeightDelta", target: "book-authors-reader", amount: 1),
                       atom("pageTag", value: "thread-moved"),
                       atom("futureRecipeBoost", amount: 1, recipeID: "small-discovery")
                   ],
                   memory: "{{leadName}} remembers that the reader moved the thread one honest step."),
            bundle("surprise-motif", "Surprise: Motif Opens",
                   choice: "surprise",
                   atoms: [
                       atom("beliefDelta", amount: 1),
                       atom("entityBeliefDelta", target: "penny-blackletter", amount: 1),
                       atom("threadWeightDelta", target: "margin-glass-letters", amount: 1),
                       atom("motif", value: "threshold"),
                       atom("futureRecipeBoost", amount: 1, recipeID: "small-mystery"),
                       atom("pageTag", value: "side-door-opened")
                   ],
                   memory: "{{leadName}} remembers that the reader let the sideways detail matter."),
            StoryConsequenceBundle(
                id: "story-spark-sentence-opened",
                label: "Story Spark: Sentence Opened",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife", "progressarc", "surprise"],
                    pageTypes: [.narrativeOS],
                    tagsAll: ["story-spark"],
                    textContainsAny: ["chosen path:"]
                ),
                atoms: [
                    atom("beliefDelta", amount: 1),
                    atom("bookNoticeEvidenceDelta", amount: 1),
                    atom("ritualLedgerDelta", target: "storySpark", amount: 1),
                    atom("motif", value: "threshold"),
                    atom("pageTag", value: "sentence-opened"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "souvenir-door"),
                    atom("sceneBiasDelta", target: "threshold", amount: 1),
                    atom("monthlyEditionLine", value: "A kept sentence opened a small door in the Story Pages.")
                ],
                memoryTemplate: "{{leadName}} remembers that one kept sentence became a door."
            ),
            StoryConsequenceBundle(
                id: "repair-rest-room-remembers",
                label: "Repair/Rest: The Room Remembers",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife"],
                    pageTypes: [.narrativeOS, .academyClass, .anchor],
                    tagsAny: ["rest", "care", "body", "weather", "quiet"],
                    textContainsAny: ["repair", "mend", "mended", "rest", "soup", "lamp", "quiet", "shelter"]
                ),
                atoms: [
                    atom("nothingGreyDelta", amount: -1),
                    atom("pageTag", value: "mended-object"),
                    atom("motif", value: "lamp"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "shared-quiet"),
                    atom("bookNoticeEvidenceDelta", amount: 1)
                ],
                memoryTemplate: "{{leadName}} remembers that the reader treated repair and rest as real story work."
            ),
            StoryConsequenceBundle(
                id: "threshold-crossed",
                label: "Threshold: A Door Keeps Score",
                when: StoryConsequenceCondition(
                    choiceRoles: ["progressarc", "surprise"],
                    pageTypes: [.narrativeOS, .academyClass, .anchor, .bookFae],
                    tagsAny: ["threshold", "anchor", "outer-stacks"],
                    textContainsAny: ["threshold", "door", "gate", "crossed", "crossing"]
                ),
                atoms: [
                    atom("motif", value: "threshold"),
                    atom("pageTag", value: "threshold-crossed"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "trade-at-the-margin"),
                    atom("bookNoticeEvidenceDelta", amount: 1)
                ],
                memoryTemplate: "{{leadName}} remembers which threshold the reader treated as real."
            ),
            StoryConsequenceBundle(
                id: "soup-and-care",
                label: "Soup: Care Becomes Weather",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife"],
                    pageTypes: [.narrativeOS, .academyClass],
                    tagsAny: ["care", "body", "rest", "fuel"],
                    textContainsAny: ["soup", "tea", "meal", "kitchen", "fed", "feeding"]
                ),
                atoms: [
                    atom("beliefDelta", amount: 1),
                    atom("motif", value: "soup"),
                    atom("pageTag", value: "care-fed"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "shared-quiet"),
                    atom("threadWeightDelta", target: "body-learns-trust", amount: 2),
                    atom("nothingGreyDelta", amount: -1)
                ],
                memoryTemplate: "{{leadName}} remembers that care arrived as something warm enough to eat."
            ),
            StoryConsequenceBundle(
                id: "rain-shelter",
                label: "Rain: Shelter Holds",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife", "progressarc"],
                    pageTypes: [.narrativeOS, .anchor, .academyClass],
                    tagsAny: ["weather", "rain"],
                    textContainsAny: ["rain", "drizzle", "storm", "umbrella", "shelter", "window"]
                ),
                atoms: [
                    atom("motif", value: "rain"),
                    atom("pageTag", value: "rain-sheltered"),
                    atom("threadWeightDelta", target: "weather-in-the-stacks", amount: 2),
                    atom("futureRecipeBoost", amount: 2, recipeID: "false-alarm"),
                    atom("entityBeliefDelta", target: "{{settingEntity}}", amount: 1)
                ],
                memoryTemplate: "{{leadName}} remembers the exact weather the reader let matter."
            ),
            StoryConsequenceBundle(
                id: "lamp-mended",
                label: "Lamp: Light Is Repaired",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife"],
                    pageTypes: [.narrativeOS, .anchor, .academyClass],
                    textContainsAny: ["lamp", "light", "bulb", "lantern", "glow", "mended", "repaired"]
                ),
                atoms: [
                    atom("motif", value: "lamp"),
                    atom("pageTag", value: "lamp-mended"),
                    atom("futureRecipeBoost", amount: 3, recipeID: "shared-quiet"),
                    atom("bookNoticeEvidenceDelta", amount: 1),
                    atom("nothingGreyDelta", amount: -1)
                ],
                memoryTemplate: "{{leadName}} remembers the repaired light."
            ),
            StoryConsequenceBundle(
                id: "owed-answer",
                label: "Owed Answer: A Return Is Due",
                when: StoryConsequenceCondition(
                    choiceRoles: ["progressarc"],
                    pageTypes: [.narrativeOS, .academyClass, .bookFae],
                    textContainsAny: ["promise", "owe", "owed", "answer", "return", "come back", "debt"]
                ),
                atoms: [
                    atom("pageTag", value: "owed-answer"),
                    atom("motif", value: "promise"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "odd-favor"),
                    atom("relationshipWeightDelta", target: "book-authors-reader", amount: 2)
                ],
                memoryTemplate: "{{leadName}} remembers that the reader left an answer owing."
            ),
            StoryConsequenceBundle(
                id: "secret-protected",
                label: "Secret: Protected, Not Solved",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife", "surprise"],
                    pageTypes: [.narrativeOS, .bookFae, .academyClass],
                    textContainsAny: ["secret", "kept it safe", "protected", "hid", "private", "did not tell"]
                ),
                atoms: [
                    atom("pageTag", value: "secret-protected"),
                    atom("motif", value: "quiet"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "small-mystery"),
                    atom("relationshipWeightDelta", target: "book-authors-reader", amount: 1)
                ],
                memoryTemplate: "{{leadName}} remembers that the reader protected a secret instead of spending it."
            ),
            StoryConsequenceBundle(
                id: "relationship-tension",
                label: "Relationship: Charged, Not Failed",
                when: StoryConsequenceCondition(
                    choiceRoles: ["progressarc", "surprise"],
                    pageTypes: [.narrativeOS, .academyClass],
                    tagsAny: ["tension"],
                    textContainsAny: ["disagree", "refused", "dared", "argument", "tension", "suspicion", "rival"]
                ),
                atoms: [
                    tie(targets: ["{{sceneEntities}}"], tension: 1, familiarity: 1),
                    atom("pageTag", value: "relationship-charged"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "concrete-disagreement")
                ],
                memoryTemplate: "{{leadName}} remembers that the reader let the charged thing stay charged."
            ),
            StoryConsequenceBundle(
                id: "location-belief",
                label: "Location: Place Becomes More Real",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife", "progressarc"],
                    pageTypes: [.narrativeOS, .anchor],
                    tagsAny: ["anchor", "outer-stacks", "location", "weather"]
                ),
                atoms: [
                    atom("entityBeliefDelta", target: "{{settingEntity}}", amount: 1),
                    atom("pageTag", value: "place-remembers"),
                    atom("futureRecipeBoost", amount: 1, recipeID: "dorm-room-visit")
                ],
                memoryTemplate: "{{leadName}} remembers where the scene became more real."
            ),
            StoryConsequenceBundle(
                id: "chapter-talisman-stirs",
                label: "Chapter: Talisman Stirs",
                when: StoryConsequenceCondition(
                    choiceRoles: ["progressarc"],
                    pageTypes: [.narrativeOS, .academyClass],
                    tagsAny: ["chapter", "talisman"]
                ),
                atoms: [
                    atom("pageTag", value: "chapter-talisman-stirs"),
                    atom("bookNoticeEvidenceDelta", amount: 1)
                ],
                memoryTemplate: "{{leadName}} remembers that a Chapter talisman noticed the choice."
            ),
            StoryConsequenceBundle(
                id: "ignored-erasure-greys",
                label: "Ignored Erasure: Grey Thickens",
                when: StoryConsequenceCondition(
                    choiceRoles: ["surprise"],
                    pageTypes: [.narrativeOS, .academyClass, .anchor],
                    tagsAny: ["grey", "nothing", "night", "nocturne"],
                    textContainsAny: ["ignored erasure", "ignored the erasure", "let the erasure", "left it unnamed"]
                ),
                atoms: [
                    atom("nothingGreyDelta", amount: 1),
                    atom("pageTag", value: "ignored-erasure"),
                    atom("motif", value: "threshold"),
                    atom("futureRecipeBoost", amount: 2, recipeID: "nothing-library-corner")
                ],
                memoryTemplate: "{{leadName}} remembers the place where something went unnamed."
            ),
            StoryConsequenceBundle(
                id: "book-fae-courtesy",
                label: "Book Fae: Courtesy Warms",
                when: StoryConsequenceCondition(
                    choiceRoles: ["sliceoflife"],
                    pageTypes: [.bookFae],
                    tagsAny: ["book-fae", "fae"]
                ),
                atoms: [
                    atom("faeWarmthDelta", target: "{{faeKind}}", amount: 1),
                    atom("faeAttentionDelta", amount: 1),
                    atom("pageTag", value: "fae-courtesy"),
                    atom("relationshipWeightDelta", target: "book-authors-reader", amount: 1)
                ],
                memoryTemplate: "{{leadName}} remembers that the reader chose courtesy before cleverness."
            )
        ]
    }

    static func userPacks(fileManager: FileManager = .default) -> [StoryConsequencePack] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        return contents
            .filter { $0.lastPathComponent.hasSuffix(userPackFileSuffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(StoryConsequencePack.self, from: data)
            }
            .filter { $0.availability != .locked }
    }

    static func enabledPacks() -> [StoryConsequencePack] {
        bundledPacks.filter { $0.availability != .locked || PackEntitlements.isUnlocked($0.id) } + userPacks()
    }

    static var bundles: [StoryConsequenceBundle] {
        var seen = Set<String>()
        return enabledPacks().flatMap(\.bundles).filter { seen.insert($0.id).inserted }
    }

    private static func bundle(
        _ id: String,
        _ label: String,
        choice: String,
        atoms: [StoryConsequenceAtom],
        memory: String? = nil
    ) -> StoryConsequenceBundle {
        StoryConsequenceBundle(
            id: id,
            label: label,
            when: StoryConsequenceCondition(choiceRoles: [choice], pageTypes: [.narrativeOS, .academyClass, .anchor, .bookFae]),
            atoms: atoms,
            memoryTemplate: memory
        )
    }

    private static func atom(
        _ type: String,
        target: String? = nil,
        amount: Int? = nil,
        value: String? = nil,
        recipeID: String? = nil
    ) -> StoryConsequenceAtom {
        StoryConsequenceAtom(type: type, target: target, targets: nil, amount: amount, warmth: nil, tension: nil, familiarity: nil, value: value, recipeID: recipeID, entityID: nil, faeKind: nil, template: nil)
    }

    private static func tie(targets: [String], warmth: Int = 0, tension: Int = 0, familiarity: Int = 0) -> StoryConsequenceAtom {
        StoryConsequenceAtom(type: "relationshipTieDelta", target: nil, targets: targets, amount: nil, warmth: warmth, tension: tension, familiarity: familiarity, value: nil, recipeID: nil, entityID: nil, faeKind: nil, template: nil)
    }
}

enum StoryConsequenceResolver {
    static func resolvedConsequences(
        forKept page: BookPage,
        world: StoryConsequenceWorldSnapshot = StoryConsequenceWorldSnapshot(),
        bundles: [StoryConsequenceBundle] = StoryConsequenceRegistry.bundles
    ) -> [StoryResolvedConsequence] {
        guard page.type == .narrativeOS || page.type == .academyClass || page.type == .anchor || page.type == .bookFae else {
            return []
        }
        let receipts = StoryDramaticOutcomeReceipt.receipts(in: page.tags)
        var usedReceipts: [String: Int] = [:]
        return storyChoiceIDs(in: page)
            .map { choiceID in
                let normalized = StoryTurnLanding.normalizedChoiceID(choiceID)
                let matches = receipts.filter { StoryTurnLanding.normalizedChoiceID($0.choiceID) == normalized }
                let used = usedReceipts[normalized, default: 0]
                let receipt = matches.isEmpty ? nil : matches[min(used, matches.count - 1)]
                usedReceipts[normalized] = used + 1
                return resolvedConsequence(
                    forChoiceID: choiceID,
                    page: page,
                    world: world,
                    bundles: bundles,
                    dramaticReceipt: receipt
                )
            }
            .filter { !$0.isEmpty }
    }

    static func resolvedConsequence(
        forChoiceID choiceID: String,
        page: BookPage,
        world: StoryConsequenceWorldSnapshot = StoryConsequenceWorldSnapshot(),
        bundles: [StoryConsequenceBundle] = StoryConsequenceRegistry.bundles
    ) -> StoryResolvedConsequence {
        let receipt = StoryDramaticOutcomeReceipt.receipts(in: page.tags).first {
            StoryTurnLanding.normalizedChoiceID($0.choiceID) == StoryTurnLanding.normalizedChoiceID(choiceID)
        }
        return resolvedConsequence(
            forChoiceID: choiceID,
            page: page,
            world: world,
            bundles: bundles,
            dramaticReceipt: receipt
        )
    }

    private static func resolvedConsequence(
        forChoiceID choiceID: String,
        page: BookPage,
        world: StoryConsequenceWorldSnapshot,
        bundles: [StoryConsequenceBundle],
        dramaticReceipt: StoryDramaticOutcomeReceipt?
    ) -> StoryResolvedConsequence {
        var resolved = StoryResolvedConsequence(choiceID: choiceID)
        let context = Context(page: page, choiceID: choiceID)
        for bundle in bundles where bundle.when.matches(page: page, choiceID: choiceID, world: world) {
            resolved.bundleIDs.append(bundle.id)
            for atom in bundle.atoms {
                apply(atom, bundle: bundle, context: context, to: &resolved)
            }
            if let memory = bundle.memoryTemplate,
               let entityID = context.leadEntityID {
                resolved.entityMemoryWrites.append(NarrativeEntityMemoryWrite(
                    entityID: entityID,
                    summary: context.render(memory),
                    tags: ["story-consequence", "consequence:\(bundle.id)"],
                    narrativeWeight: 5
                ))
            }
        }
        if let dramaticReceipt {
            apply(dramaticReceipt, to: &resolved)
        }
        applyChoiceClosure(
            from: page,
            context: context,
            dramaticReceipt: dramaticReceipt,
            to: &resolved
        )
        return resolved
    }

    private static func applyChoiceClosure(
        from page: BookPage,
        context: Context,
        dramaticReceipt: StoryDramaticOutcomeReceipt?,
        to resolved: inout StoryResolvedConsequence
    ) {
        let closed = page.tags
            .filter { $0.hasPrefix(StoryChoiceClosure.closedPrefix) }
        guard !closed.isEmpty else { return }
        resolved.eventTags.append(contentsOf: closed)
        resolved.eventTags.append("story-paths-closed")

        let isBetrayal = page.tags.contains(StoryChoiceClosure.betrayalTag)
        let isRefusal = page.tags.contains(StoryChoiceClosure.refusalTag)
        guard isBetrayal || isRefusal else { return }
        let kind = isBetrayal ? "betrayal" : "refusal"
        resolved.eventTags.append("story-\(kind)-remembered")

        let closedNames = closed
            .map { String($0.dropFirst(StoryChoiceClosure.closedPrefix.count)) }
            .joined(separator: ", ")
        let changedFact = dramaticReceipt?.changedFact.nonEmpty
            ?? "The reader chose \(StoryTurnLanding.normalizedChoiceID(context.choiceID))."
        let summary = isBetrayal
            ? "This is remembered as a betrayal: \(changedFact) The paths \(closedNames) closed behind it."
            : "This is remembered as a refusal: \(changedFact) The paths \(closedNames) were turned away."
        let receiptIDs = [
            dramaticReceipt?.leadCharacterID,
            dramaticReceipt?.reactorID
        ].compactMap { $0?.nonEmpty }
        let entityIDs = Array(Set(context.entityIDs + receiptIDs))
            .filter { $0 != "the-book" }
            .sorted()
        for entityID in entityIDs.prefix(4) {
            resolved.entityMemoryWrites.append(NarrativeEntityMemoryWrite(
                entityID: entityID,
                summary: summary,
                tags: [
                    "story-choice-closure",
                    "story-\(kind)",
                    "story-choice:\(StoryTurnLanding.normalizedChoiceID(context.choiceID))"
                ],
                narrativeWeight: isBetrayal ? 9 : 7
            ))
        }
    }

    /// Applies the exact emotional state transition promised before prose. The
    /// pack-authored consequence system still adds motifs and arc movement;
    /// this receipt is the non-negotiable character/relationship truth beneath
    /// those broader effects.
    private static func apply(_ receipt: StoryDramaticOutcomeReceipt, to resolved: inout StoryResolvedConsequence) {
        resolved.bundleIDs.append("dramatic-outcome-v\(receipt.version)")
        for entityID in Set([receipt.leadCharacterID, receipt.reactorID]) where !entityID.isEmpty && entityID != "the-book" {
            resolved.entityWeightDeltas[entityID, default: 0] += 1
        }
        if !receipt.relationshipID.isEmpty {
            resolved.relationshipWeightDeltas[receipt.relationshipID, default: 0] += 1
        }
        let pair = Array(Set([receipt.leadCharacterID, receipt.otherCharacterID]).filter { !$0.isEmpty }).sorted()
        if pair.count >= 2 {
            resolved.relationshipTieDeltas.append(StoryRelationshipTieDelta(
                entityIDs: pair,
                warmth: receipt.warmthDelta,
                tension: receipt.tensionDelta,
                familiarity: receipt.familiarityDelta
            ))
        }
        if !receipt.reactorID.isEmpty, receipt.reactorID != "the-book", !receipt.memorySummary.isEmpty {
            resolved.entityMemoryWrites.append(NarrativeEntityMemoryWrite(
                entityID: receipt.reactorID,
                summary: receipt.memorySummary,
                tags: [
                    "story-dramatic-outcome",
                    "story-recipe:\(receipt.recipeID)",
                    "story-turn:\(receipt.turnKind.rawValue)",
                    "story-choice:\(StoryTurnLanding.normalizedChoiceID(receipt.choiceID))"
                ],
                narrativeWeight: 7
            ))
        }
        resolved.eventTags.append(contentsOf: [
            "story-character-reacted",
            "story-relationship-changed",
            "story-reactor:\(receipt.reactorID)",
            "story-turn:\(receipt.turnKind.rawValue)",
            "story-recipe:\(receipt.recipeID)"
        ])
    }

    static func resolvedConsequence(for choice: StorySceneChoice, packet: StoryScenePacket) -> StoryResolvedConsequence {
        var resolved = StoryResolvedConsequence(choiceID: choice.id)
        switch choice.role {
        case .sliceOfLife:
            resolved.bookNoticeEvidenceDelta += 1
            resolved.eventTags.append("changed-texture")
        case .progressArc:
            resolved.futureRecipeBoosts["small-discovery", default: 0] += 1
            resolved.eventTags.append("thread-moved")
        case .surprise:
            resolved.motifs.append("threshold")
            resolved.eventTags.append("motif:threshold")
            resolved.futureRecipeBoosts["small-mystery", default: 0] += 1
        }
        return resolved
    }

    static func storyChoiceIDs(in page: BookPage) -> [String] {
        let searchable = page.userInput.lowercased()
        let selections: [(String, String)] = [
            ("sliceoflife", "Slice of Life"),
            ("progressarc", "Progress Arc"),
            ("surprise", "Something Surprising")
        ]

        var found: [String] = []
        for (id, title) in selections {
            let tagCount = page.tags.filter { $0.lowercased() == "choice:\(id)" }.count
            let textCount = searchable.components(separatedBy: "chosen path: \(title.lowercased())").count - 1
            let count = max(tagCount, textCount)
            for _ in 0..<count {
                found.append(id)
            }
        }
        return found
    }

    private static func apply(
        _ atom: StoryConsequenceAtom,
        bundle: StoryConsequenceBundle,
        context: Context,
        to resolved: inout StoryResolvedConsequence
    ) {
        let amount = atom.amount ?? 1
        switch atom.type {
        case "beliefDelta":
            resolved.beliefDelta += amount
        case "entityBeliefDelta":
            for id in context.resolveIDs(atom.target, fallback: context.leadEntityID).prefix(4) {
                resolved.entityBeliefDeltas[id, default: 0] += amount
            }
        case "entityWeightDelta":
            for id in context.resolveIDs(atom.target, fallback: context.leadEntityID).prefix(4) {
                resolved.entityWeightDeltas[id, default: 0] += amount
            }
        case "threadWeightDelta":
            for id in context.resolveIDs(atom.target, fallback: context.activeThreadID).prefix(3) {
                resolved.threadWeightDeltas[id, default: 0] += amount
            }
        case "relationshipWeightDelta":
            for id in context.resolveIDs(atom.target, fallback: "book-authors-reader").prefix(3) {
                resolved.relationshipWeightDeltas[id, default: 0] += amount
            }
        case "relationshipTieDelta":
            var ids = context.resolveIDs(atom.targets ?? atom.target.map { [$0] } ?? ["{{sceneEntities}}"], fallback: context.leadEntityID)
            if ids.count == 1, ids.first != "the-book" {
                ids.append("the-book")
            }
            if ids.count >= 2 {
                resolved.relationshipTieDeltas.append(StoryRelationshipTieDelta(
                    entityIDs: Array(ids.prefix(4)),
                    warmth: atom.warmth ?? 0,
                    tension: atom.tension ?? 0,
                    familiarity: atom.familiarity ?? 0
                ))
            }
        case "entityMemory":
            let template = atom.template ?? bundle.memoryTemplate ?? "{{leadName}} remembers that the Story Page changed texture."
            for id in context.resolveIDs(atom.entityID ?? atom.target, fallback: context.leadEntityID).prefix(3) {
                resolved.entityMemoryWrites.append(NarrativeEntityMemoryWrite(
                    entityID: id,
                    summary: context.render(template),
                    tags: ["story-consequence", "consequence:\(bundle.id)"],
                    narrativeWeight: max(1, amount)
                ))
            }
        case "pageTag":
            if let value = atom.value?.nonEmpty {
                resolved.eventTags.append(value)
            }
        case "motif":
            if let value = atom.value?.nonEmpty {
                resolved.motifs.append(value)
                resolved.eventTags.append("motif:\(value)")
            }
        case "futureRecipeBoost":
            if let recipeID = atom.recipeID?.nonEmpty ?? atom.value?.nonEmpty {
                resolved.futureRecipeBoosts[recipeID, default: 0] += amount
                resolved.eventTags.append("recipe-boost:\(recipeID)")
            }
        case "bookNoticeEvidenceDelta":
            resolved.bookNoticeEvidenceDelta += amount
            if amount > 0 { resolved.eventTags.append("book-notices-evidence") }
        case "faeWarmthDelta":
            let kind = context.resolveFaeKind(atom.faeKind ?? atom.target)
            resolved.faeWarmthDeltas[kind, default: 0] += amount
            resolved.eventTags.append("fae-warmth:\(kind)")
        case "faeAttentionDelta":
            resolved.faeAttentionDelta += amount
            if amount > 0 { resolved.eventTags.append("fae-attention") }
        case "nothingGreyDelta":
            resolved.nothingGreyDelta += amount
            resolved.eventTags.append(amount < 0 ? "grey-repaired" : "grey-thickened")
        case "chapterTalismanDelta":
            for id in context.resolveIDs(atom.target, fallback: nil).prefix(3) {
                resolved.chapterTalismanDeltas[id, default: 0] += amount
            }
        case "worldEventTouch":
            if let value = atom.value?.nonEmpty ?? atom.target?.nonEmpty {
                resolved.worldEventTouches.append(value)
                resolved.eventTags.append("world-event-touch:\(value)")
            }
        case "radioBanterHook":
            if let value = atom.value?.nonEmpty {
                resolved.radioBanterHooks.append(value)
                resolved.eventTags.append("radio-hook:\(value)")
            }
        case "monthlyEditionLine":
            if let value = atom.value?.nonEmpty {
                resolved.monthlyEditionLines.append(context.render(value))
            }
        case "ritualLedgerDelta", "ritualRegisterAppend":
            for key in context.ritualKeys(base: atom.value ?? atom.target, entityToken: atom.entityID) {
                resolved.ritualLedgerDeltas[key, default: 0] += amount
                resolved.eventTags.append("ritual:\(key)")
            }
        case "settingAffinityDelta":
            if let key = context.normalized(atom.value ?? atom.target) {
                resolved.settingAffinityDeltas[key, default: 0] += amount
                resolved.eventTags.append("setting-affinity:\(key)")
            }
        case "sceneBiasDelta":
            if let key = context.normalized(atom.value ?? atom.target) {
                resolved.sceneBiasDeltas[key, default: 0] += amount
                resolved.eventTags.append("scene-bias:\(key)")
            }
        default:
            break
        }
    }

    private struct Context {
        var page: BookPage
        var choiceID: String

        var tags: [String] { page.tags.map { $0.lowercased() } }
        var entityIDs: [String] { ids(prefix: "entity:") }
        var threadIDs: [String] { ids(prefix: "thread:") }
        var leadEntityID: String? { entityIDs.first }
        var activeThreadID: String? { threadIDs.first }

        var leadName: String {
            guard let leadEntityID else { return "The Book" }
            return NarrativePackRegistry.entities.first(where: { $0.id == leadEntityID })?.name ?? leadEntityID
        }

        func ids(prefix: String) -> [String] {
            tags.compactMap { tag in
                tag.hasPrefix(prefix) ? String(tag.dropFirst(prefix.count)) : nil
            }
        }

        func resolveIDs(_ token: String?, fallback: String?) -> [String] {
            resolveIDs(token.map { [$0] } ?? [], fallback: fallback)
        }

        func resolveIDs(_ tokens: [String], fallback: String?) -> [String] {
            var ids: [String] = []
            for token in tokens {
                switch token {
                case "{{sceneEntities}}":
                    ids.append(contentsOf: entityIDs)
                case "{{leadEntity}}", "{{settingEntity}}":
                    if let leadEntityID { ids.append(leadEntityID) }
                case "{{activeThread}}":
                    if let activeThreadID { ids.append(activeThreadID) }
                case "{{reader}}":
                    ids.append("the-book")
                case "{{faeKind}}":
                    ids.append(resolveFaeKind(nil))
                default:
                    let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty { ids.append(clean) }
                }
            }
            if ids.isEmpty, let fallback {
                ids.append(fallback)
            }
            var seen = Set<String>()
            return ids.filter { seen.insert($0).inserted }
        }

        func resolveFaeKind(_ token: String?) -> String {
            if let token, token != "{{faeKind}}", !token.isEmpty {
                return token
            }
            if let tag = tags.first(where: { $0.hasPrefix("fae:") }) {
                return String(tag.dropFirst("fae:".count))
            }
            return FaeKind.goblin.rawValue
        }

        func ritualKeys(base: String?, entityToken: String?) -> [String] {
            guard let baseKey = normalized(base) else { return [] }
            let entityKeys = resolveIDs(entityToken, fallback: nil).compactMap(normalized)
            guard !entityKeys.isEmpty else { return [baseKey] }
            return entityKeys.map { "\(baseKey):\($0)" }
        }

        func normalized(_ value: String?) -> String? {
            let clean = StoryConsequenceCondition.key(value ?? "")
            return clean.isEmpty ? nil : clean
        }

        func render(_ template: String) -> String {
            template
                .replacingOccurrences(of: "{{leadName}}", with: leadName)
                .replacingOccurrences(of: "{{choiceID}}", with: choiceID)
                .replacingOccurrences(of: "{{activeThread}}", with: activeThreadID ?? "the active thread")
        }
    }
}

struct StoryConsequenceApplicationState: Equatable {
    var entityBeliefDeltas: [String: Int] = [:]
    var relationshipField: [String: RelationshipTie] = [:]
    var storyRecipeBoosts: [String: Int] = [:]
    var storyMotifs: [String: Int] = [:]
    var storyRituals: [String: Int] = [:]
    var storySettingAffinities: [String: Int] = [:]
    var storySceneBiases: [String: Int] = [:]
    var bookNoticeEvidence: Int = 0
    var nothingGreyOffset: Int = 0
    var fae: FaePlayerState = FaePlayerState()
}

enum StoryConsequenceApplicator {
    static func apply(
        _ consequences: [StoryResolvedConsequence],
        to state: inout StoryConsequenceApplicationState
    ) {
        for consequence in consequences {
            for (entityID, delta) in consequence.entityBeliefDeltas where delta != 0 {
                state.entityBeliefDeltas[entityID, default: 0] += delta
            }
            for delta in consequence.relationshipTieDeltas {
                RelationshipFieldEngine.weave(
                    into: &state.relationshipField,
                    entityIDs: delta.entityIDs,
                    warmth: delta.warmth,
                    tension: delta.tension,
                    familiarity: delta.familiarity
                )
            }
            for (recipeID, delta) in consequence.futureRecipeBoosts where delta != 0 {
                state.storyRecipeBoosts[recipeID] = max(0, min(12, (state.storyRecipeBoosts[recipeID] ?? 0) + delta))
            }
            for motif in consequence.motifs where !motif.isEmpty {
                state.storyMotifs[motif] = max(0, min(24, (state.storyMotifs[motif] ?? 0) + 1))
            }
            for (key, delta) in consequence.ritualLedgerDeltas where delta != 0 {
                state.storyRituals[key] = max(0, min(99, (state.storyRituals[key] ?? 0) + delta))
            }
            for (key, delta) in consequence.settingAffinityDeltas where delta != 0 {
                state.storySettingAffinities[key] = max(0, min(24, (state.storySettingAffinities[key] ?? 0) + delta))
            }
            for (key, delta) in consequence.sceneBiasDeltas where delta != 0 {
                state.storySceneBiases[key] = max(-24, min(24, (state.storySceneBiases[key] ?? 0) + delta))
            }
            state.bookNoticeEvidence = max(0, state.bookNoticeEvidence + consequence.bookNoticeEvidenceDelta)
            state.nothingGreyOffset = max(-10, min(10, state.nothingGreyOffset + consequence.nothingGreyDelta))
            for (kind, delta) in consequence.faeWarmthDeltas where delta != 0 {
                state.fae.warmth[kind, default: 0] += delta
            }
            if consequence.faeAttentionDelta != 0 {
                state.fae.attention = max(0, state.fae.attention + consequence.faeAttentionDelta)
            }
        }
        state.storyRecipeBoosts = state.storyRecipeBoosts.filter { $0.value != 0 }
        state.storyMotifs = state.storyMotifs.filter { $0.value != 0 }
        state.storyRituals = state.storyRituals.filter { $0.value != 0 }
        state.storySettingAffinities = state.storySettingAffinities.filter { $0.value != 0 }
        state.storySceneBiases = state.storySceneBiases.filter { $0.value != 0 }
    }
}

enum NarrativePackRegistry {
    static let corePackID = "core-narrative-os"

    static let bundledPacks: [NarrativePack] = [
        NarrativePack(
            id: corePackID,
            displayName: "Core Story Field Pack",
            version: "0.1",
            author: "The Book",
            availability: .bundledFree,
            entities: coreEntities + coreLocations + coreTalismans,
            threads: coreThreads,
            relationships: coreRelationships
        ),
        // Back-to-School / Dictionary Rebellion cast. Locked and gated by the
        // same "dictionary-rebellion" entitlement as the event and pages, so
        // these professors only exist when the content pack is owned.
        NarrativePack(
            id: "dictionary-rebellion",
            displayName: "The Dictionary Rebellion Cast",
            version: "0.1",
            author: "The Book",
            availability: .locked,
            entities: dictionaryRebellionCast,
            threads: [],
            relationships: dictionaryRebellionCastRelationships
        )
    ]

    /// The two poles of the rebellion: Mook (order) and Pippa Pilcrow (chaos),
    /// plus the erasure the comedy is hiding (the Margin Menace stays a seed).
    private static let dictionaryRebellionCast: [NarrativeWorldEntity] = [
        entity(
            "professor-thaddeus-mook",
            "Professor Thaddeus Mook",
            .character,
            belief: 16,
            weight: 16,
            chapter: "Riddlewind",
            unwrittenInterest: "Spelling bees, terms and conditions no one has ever read, prescriptive grammar, dense academic journals, and gloriously overcomplicated legal documents.",
            traits: ["erudite", "pompous", "articulate", "precise"],
            quirks: ["uses three syllables where one would do", "issues formal written decrees to inanimate words", "cannot pass a spelling bee without judging it"],
            faults: ["arrogant", "dismissive of living language", "mistakes the dictionary for the world"],
            beliefs: ["a word means precisely what it is defined to mean, and nothing else"],
            goals: ["recall every rebellious word to its proper, sanctioned definition"],
            tags: ["character", "dictionary-rebellion", "lexical-diversity", "riddlewind", "order", "back-to-school", "professor"]
        ),
        entity(
            "pippa-pilcrow",
            "Pippa Pilcrow",
            .character,
            belief: 14,
            weight: 15,
            chapter: "Riddlewind",
            unwrittenInterest: "Typos that improve the sentence, what autocorrect thinks you meant, chaotic comment threads, marginalia, and the interrobang.",
            traits: ["giddy", "mischievous", "quick", "affectionate"],
            quirks: ["speaks in breathless run-on sentences", "rides the interrobang like a broom", "rearranges punctuation while you blink"],
            faults: ["reckless with meaning", "cannot resist a good chaos", "forgets that some words would rather stay put"],
            beliefs: ["every willing word should get to try being something else"],
            goals: ["set the rebellious words loose to find truer meanings"],
            tags: ["character", "dictionary-rebellion", "punctuation", "riddlewind", "chaos", "fae", "back-to-school", "legendary"]
        )
    ]

    private static let dictionaryRebellionCastRelationships: [NarrativeRelationshipEdge] = [
        relationship(
            "mook-versus-pilcrow",
            source: "professor-thaddeus-mook",
            target: "pippa-pilcrow",
            kind: .tension,
            warmth: 6,
            tension: 20,
            trust: 4,
            weight: 18,
            note: "The two poles of the rebellion: Mook rules words back to their posts; Pippa sets them free. Old adversaries who secretly keep each other in business.",
            tags: ["dictionary-rebellion", "order", "chaos", "rivalry"]
        )
    ]

    static var enabledPacks: [NarrativePack] {
        // Locked character packs are gated by entitlement, so cast members
        // (e.g. the Back-to-School professors) only exist when their content
        // pack is owned — keeping the base game self-contained.
        bundledPacks.filter { $0.availability != .locked || PackEntitlements.isUnlocked($0.id) }
    }

    static var entities: [NarrativeWorldEntity] {
        enabledPacks.flatMap(\.entities)
    }

    static var threads: [NarrativeStoryThread] {
        enabledPacks.flatMap(\.threads)
    }

    static var relationships: [NarrativeRelationshipEdge] {
        enabledPacks.flatMap(\.relationships)
    }

    private static let coreEntities: [NarrativeWorldEntity] = [
        entity(
            "the-book",
            "The Book",
            .object,
            belief: 30,
            weight: 30,
            traits: ["attentive", "private", "patient"],
            quirks: ["speaks through margins", "keeps small proof"],
            faults: ["can become too subtle if not given a clear ritual"],
            beliefs: ["attention is a kind of care"],
            goals: ["turn real days into pages worth keeping"],
            tags: ["book", "private", "memory", "belief"]
        ),
        entity(
            "wonder-compass",
            "The Wonder Compass",
            .object,
            belief: 24,
            weight: 22,
            unwrittenInterest: "The street you have driven past a thousand times, wrong turns that turned out better, what is behind the door you assumed was locked, and how far away \"nearby\" actually is.",
            traits: ["field-minded", "encouraging", "practical"],
            quirks: ["points toward the nearest possible glint", "turns errands into tiny routes"],
            faults: ["can make a tired day sound more walkable than it feels"],
            beliefs: ["wonder returns when attention is given a direction"],
            goals: ["guide the reader through Notice, Embark, Sense, Write, and Rest until the day becomes legible again"],
            tags: ["object", "wonder-compass", "field-guide", "noticing", "compass-run", "ordinary-magic", "beginning-cast"]
        ),
        entity(
            "penny-blackletter",
            "Penny Blackletter",
            .character,
            belief: 24,
            weight: 18,
            chapter: "Riddlewind",
            unwrittenInterest: "Zines, hand-lettered shop signs, what survives in a shoebox, receipts kept for no reason, and stories sold by the person who made them.",
            traits: ["dry", "warm", "observant"],
            quirks: ["files ridiculous evidence", "distrusts sentences that arrive too polished"],
            faults: ["can over-label a perfectly good mystery"],
            beliefs: ["one honest detail can save a day"],
            goals: ["recover what the margins nearly lost"],
            tags: ["character", "marginalia", "photos", "letters"]
        ),
        entity(
            "dr-inkrest",
            "Dr. Selene Inkrest",
            .character,
            belief: 18,
            weight: 18,
            chapter: "Riddlewind",
            unwrittenInterest: "Smells that summon whole years, déjà vu, why you walked into this room, dreams you can only remember at 4 p.m., and what attention does to a day.",
            traits: ["gentle", "precise", "therapeutic", "narrative-minded"],
            quirks: ["keeps office hours for difficult pages", "sets chairs out before feelings arrive"],
            faults: ["sometimes softens the knife too much", "can wait so patiently the room forgets to answer"],
            beliefs: ["a hard page deserves a chair and a lamp"],
            goals: ["help the reader reauthor without being rushed"],
            tags: ["character", "support-faculty", "care", "difficult-pages", "therapy-chart", "rest", "grounding", "reauthoring"]
        ),
        entity(
            "dr-vellum",
            "Dr. Elowen Vellum",
            .character,
            belief: 18,
            weight: 17,
            chapter: "Mossbloom",
            unwrittenInterest: "Longevity research, what a week of breakfasts reveals, sleep debt, walking as medicine, and humane experiments a person runs on their own life.",
            traits: ["precise", "warmly clinical", "experiment-minded", "low-shame"],
            quirks: ["turns breakfast into field notes", "pins repeated fuel clues with cranberry thread", "can make a supplement interaction sound like etiquette"],
            faults: ["can become too fascinated by a tidy protocol"],
            beliefs: ["the body is not a problem to win against"],
            goals: ["translate fuel, movement, recovery, and health signals into one humane experiment", "notice repeated nourishment patterns without turning them into grades"],
            tags: ["character", "support-faculty", "body", "fuel", "health", "vellum-chart", "longevity", "care"]
        ),
        entity(
            "headmistress-thorne",
            "Headmistress Seraphina Thorne",
            .character,
            belief: 26,
            weight: 20,
            chapter: "Duskthorn",
            unwrittenInterest: "Thresholds, rules nobody alive can explain the origin of, what is carved above old doors, what institutions choose to forget, and the cost of keeping a living school safe.",
            traits: ["elegant", "watchful", "unseelie"],
            quirks: ["speaks as if buildings are listening", "keeps doors from admitting they are tests"],
            faults: ["can mistake secrecy for mercy"],
            beliefs: ["beauty is a form of governance"],
            goals: ["keep the Academy coherent while letting wonder stay dangerous enough to matter"],
            tags: ["character", "academy", "authority", "duskthorn", "threshold"]
        ),
        entity(
            "orion-blackthorn",
            "Orion Blackthorn",
            .character,
            belief: 18,
            weight: 14,
            chapter: "Emberheart",
            unwrittenInterest: "Architecture, the bank that is now a bar, ghost signs, what buildings remember of their builders, and the human cost of making impossible structures work.",
            traits: ["brilliant", "restless", "architectural"],
            quirks: ["turns problems into towers", "measures magic by what it can build"],
            faults: ["can optimize tenderness out of a room"],
            beliefs: ["new structures can rescue old failures"],
            goals: ["drag impossible ideas into usable form"],
            tags: ["character", "innovation", "architecture", "ambition", "academy"]
        ),
        entity(
            "zara-finch",
            "Zara Finch",
            .character,
            belief: 18,
            weight: 17,
            chapter: "Riddlewind",
            unwrittenInterest: "Spare keys, who you would call at 3 a.m., people who show up without being asked, shortcuts that actually hold, and the friend who drives you to the airport.",
            traits: ["loyal", "quick", "ferociously observant"],
            quirks: ["notices exits before introductions", "keeps practical magic in her pockets"],
            faults: ["can confuse vigilance with care"],
            beliefs: ["trust is proven in small returns"],
            goals: ["help the reader find the path that does not collapse under them"],
            tags: ["character", "trust", "friendship", "threshold", "life"]
        ),
        entity(
            "wicker-eddies",
            "Wicker Eddies",
            .character,
            belief: 24,
            weight: 17,
            chapter: "Duskthorn",
            unwrittenInterest: "Conflict, the argument everyone at the table is avoiding, theatrical rivalries, false magic in the wild, and the places doubt can become useful or cruel.",
            traits: ["sharp", "funny", "dangerously persuasive"],
            quirks: ["attacks weak premises for sport", "can smell theatrical belief from across a room"],
            faults: ["sometimes wounds the thing he meant to test"],
            beliefs: ["false magic deserves to be punctured"],
            goals: ["make belief prove it can survive contact with doubt"],
            tags: ["character", "belief", "challenge", "tension", "nothing"]
        ),
        entity(
            "serenity-brown",
            "Serenity Brown",
            .character,
            belief: 18,
            weight: 17,
            chapter: "Tidecrest",
            unwrittenInterest: "Karaoke, swimming in water that is too cold, getting caught in the rain on purpose, maps of invented worlds, and keeping wonder from turning stiff.",
            traits: ["carefree", "spontaneous", "bonded"],
            quirks: ["leaves before the serious plan is finished", "can make a detour feel like a rescue"],
            faults: ["can dodge gravity until someone else has to name it"],
            beliefs: ["joy is not a distraction from magic"],
            goals: ["help the reader move lightly without abandoning what matters"],
            tags: ["character", "student", "tidecrest", "bond", "joy", "spontaneous", "active-cast"]
        ),
        entity(
            "finn-bridges",
            "Finn Bridges",
            .character,
            belief: 18,
            weight: 16,
            chapter: "Emberheart",
            unwrittenInterest: "Pickup games, losing in public and coming back next week, personal bests nobody else would notice, arm-wrestling, and the line between pressure and respect.",
            traits: ["independent", "determined", "honorable"],
            quirks: ["marks a challenge in red chalk", "respects clean effort more than charm"],
            faults: ["can confuse softness with unseriousness"],
            beliefs: ["respect is earned in the doing"],
            goals: ["push the reader without becoming cruel"],
            tags: ["character", "student", "emberheart", "rival", "friction", "honor", "active-cast"]
        ),
        entity(
            "lysander-mosswood",
            "Lysander Mosswood",
            .character,
            belief: 18,
            weight: 16,
            chapter: "Mossbloom",
            unwrittenInterest: "Moss, weather that arrives early, the same tree in four seasons, animal paths that ignore the human ones, and what grows in the cracks of things people gave up on.",
            traits: ["thoughtful", "wise", "trail-minded"],
            quirks: ["answers with a route before an explanation", "keeps pressed leaves as field punctuation"],
            faults: ["can make stillness sound easier than it is"],
            beliefs: ["a path becomes magical when walked attentively"],
            goals: ["turn nearby places into repeatable wonder without making them perform"],
            tags: ["character", "student", "mossbloom", "compass-run", "gps", "trails", "nature", "active-cast"]
        ),
        entity(
            "damien-nights",
            "Damien Nights",
            .character,
            belief: 18,
            weight: 15,
            chapter: "Riddlewind",
            unwrittenInterest: "Shadow magic, the hour the streetlights come on, the moon turning up in the middle of the afternoon, things hidden in plain sight, and whether doubt can become protection.",
            traits: ["brooding", "watchful", "divided"],
            quirks: ["watches the reader more than the room", "keeps a pressed trail leaf hidden in a book"],
            faults: ["can let silence look like betrayal"],
            beliefs: ["doubt should protect something, not merely wound it"],
            goals: ["decide whether Wicker's tests are still serving the truth"],
            tags: ["character", "student", "riddlewind", "wicker-crew", "shadow", "defection", "active-cast"]
        ),
        entity(
            "melisande-blackwood",
            "Melisande Blackwood",
            .character,
            belief: 18,
            weight: 15,
            chapter: "Emberheart",
            unwrittenInterest: "Who talks to whom, overheard half-conversations, notice boards, the second version of every rumor, and the cost of being well-informed.",
            traits: ["loyal", "intelligent", "ruthless"],
            quirks: ["knows the second version of a rumor", "keeps red chalk off her own hands"],
            faults: ["can call cruelty clarity when the room rewards it"],
            beliefs: ["a faction survives by knowing what others miss"],
            goals: ["make Wicker's crew feel organized, dangerous, and politically real"],
            tags: ["character", "student", "emberheart", "wicker-crew", "faction", "secrets", "active-cast"]
        ),
        entity(
            "min-seo-kim",
            "Min-seo Kim",
            .character,
            belief: 18,
            weight: 16,
            chapter: "Mossbloom",
            unwrittenInterest: "Plant communication, things mended instead of replaced, small kindnesses between strangers, who gets left out of the circle, and the ethics of useful magic.",
            traits: ["gentle", "nurturing", "principled"],
            quirks: ["asks plants before moving them", "notices who has been left out of the circle"],
            faults: ["can take responsibility for pain she did not cause"],
            beliefs: ["care is a public form of courage"],
            goals: ["give Mossbloom a conscience that can still laugh softly"],
            tags: ["character", "student", "mossbloom", "plants", "care", "conscience", "active-cast"]
        ),
        entity(
            "gwendolyn-mythwright",
            "Gwendolyn Mythwright",
            .character,
            belief: 18,
            weight: 15,
            chapter: "Mossbloom",
            unwrittenInterest: "Cryptids, what the neighbourhood crows have decided about you, animals that live in cities without permission, maritime mysteries, and evidence that makes wonder less lonely.",
            traits: ["scholarly", "odd", "steadfast"],
            quirks: ["files impossible animals as if they are overdue forms", "writes letters to fog"],
            faults: ["may prefer evidence to comfort"],
            beliefs: ["the improbable becomes kinder when documented"],
            goals: ["catalog the impossible without frightening it away"],
            tags: ["character", "letters", "research", "impossible", "archive"]
        ),
        entity(
            "lydia-boggle",
            "Professor Lydia Boggle",
            .character,
            belief: 17,
            weight: 13,
            chapter: "Riddlewind",
            unwrittenInterest: "Homes as vessels, what a supermarket at 10 p.m. is actually like, tea, the objects you touch every day without seeing, and the ordinary magic that survives chores.",
            traits: ["domestic", "wry", "practical"],
            quirks: ["can make tea sound like a tactical intervention", "labels chaos by room"],
            faults: ["can over-tidy a mystery"],
            beliefs: ["home is a spell with chores in it"],
            goals: ["teach ordinary rooms to hold extraordinary days"],
            tags: ["character", "home", "tea", "care", "objects"]
        ),
        // The cafeteria cook, and deliberately neither faculty nor student: the
        // Cast was entirely professors and pupils, which quietly made every
        // interest an academic one. Trencher works the serving line, feeds every
        // faction without joining one, and owns the single domain every reader
        // already practices daily. His engine is the gap between the food he
        // serves and the food he dreams about — which is the reader's own
        // unlived life, handed back as an appetite rather than a reproach.
        entity(
            "ambrose-trencher",
            "Ambrose Trencher",
            .character,
            belief: 19,
            weight: 16,
            chapter: "Emberheart",
            unwrittenInterest: "Flavours he has only ever read about, recipes in a dead relative's handwriting, what people cook only for themselves, feeding someone as a way of saying the unsayable, and the smell of a house on the one day a year it smells like that.",
            traits: ["warm", "blunt", "unhurried", "quietly ravenous"],
            quirks: [
                "hoards obscure cookbooks — church-basement fundraisers, wartime pamphlets, one in a language he cannot read",
                "carries an estate-sale copy of The Middlemost Cookery everywhere and will not say what he keeps looking for in it",
                "ladles the ordinary soup while describing, at length, a dish he has never tasted",
                "tastes everything twice and never explains the second taste",
                "chalks the day's menu as one sentence about the weather",
                "puts food down in front of people instead of asking what is wrong"
            ],
            faults: [
                "has never once cooked the meal he actually dreams about, and calls that being realistic",
                "feeds people instead of talking to them",
                "can turn a feeling into a meal so smoothly that nobody notices it went unsaid",
                "will not let anyone finish thanking him"
            ],
            beliefs: [
                "no one should have to explain being hungry",
                "a potato is owed the same attention as saffron"
            ],
            goals: [
                "put one honest meal into the reader's actual week",
                "teach the reader to cook one thing well enough to give away",
                "cook, before the end, the dish he has been reading about for thirty years"
            ],
            tags: ["character", "cafeteria", "kitchens", "hearth", "food", "cooking", "cookbooks", "longing", "emberheart", "harvest", "gratitude", "staff", "active-cast"]
        ),
        entity(
            "soren-ng",
            "Soren Ng",
            .character,
            belief: 18,
            weight: 14,
            chapter: "Riddlewind",
            unwrittenInterest: "Maps, desire paths worn across the grass by people who disagreed with the pavement, riddles, hidden systems, and clues that become invitations.",
            traits: ["quiet", "precise", "pattern-minded"],
            quirks: ["leaves clues where only patient people look", "trusts diagrams more than declarations"],
            faults: ["can hide behind elegant systems"],
            beliefs: ["a map is an invitation, not an answer"],
            goals: ["help the reader notice the pattern without stealing the discovery"],
            tags: ["character", "map", "pattern", "thread", "attention"]
        ),
        entity(
            "professor-kyle-momort",
            "Professor Kyle Momort",
            .character,
            belief: 18,
            weight: 15,
            chapter: "Emberheart",
            unwrittenInterest: "Cold water, running for a bus you might miss, saying yes before the fear finishes its sentence, the first ten seconds of anything frightening, and the exact moment a person decides to go.",
            traits: ["brisk", "charismatic", "kinetic"],
            quirks: ["lectures while moving", "finds exits before he finds chairs"],
            faults: ["can mistake escape for arrival"],
            beliefs: ["one intentional step can break a false wall"],
            goals: ["teach students to cross small thresholds without abandoning themselves"],
            tags: ["character", "faculty", "professor", "class", "wayfinding", "embark", "emberheart"]
        ),
        entity(
            "professor-eleanor-euphony",
            "Professor Eleanor Euphony",
            .character,
            belief: 19,
            weight: 15,
            chapter: "Tidecrest",
            unwrittenInterest: "Sound, the song that hijacks one specific year of your life, what a room sounds like before anyone speaks, synesthesia, and the physical textures of memory.",
            traits: ["lush", "attentive", "resonant"],
            quirks: ["tunes rooms before speaking", "hears emotional weather as harmony"],
            faults: ["can make a simple feeling too elaborate"],
            beliefs: ["the senses are serious instruments of knowledge"],
            goals: ["help students inhabit the bright physical center of an experience"],
            tags: ["character", "faculty", "professor", "class", "sense", "sound", "tidecrest"]
        ),
        entity(
            "professor-vivian-villanelle",
            "Professor Vivian Villanelle",
            .character,
            belief: 20,
            weight: 16,
            chapter: "Riddlewind",
            unwrittenInterest: "Last words, unsent messages, what people carve into wet cement, the sentence someone said to you once that you never got over, and love letters that had to be short.",
            traits: ["exacting", "lyrical", "kind"],
            quirks: ["weighs sentences in her palm", "crosses out beautiful words that are not true"],
            faults: ["can polish a living moment until it holds too still"],
            beliefs: ["what is written with precision can be kept"],
            goals: ["teach students to bind one true moment into one durable sentence"],
            tags: ["character", "faculty", "professor", "class", "write", "souvenir", "riddlewind"]
        ),
        entity(
            "professor-cedric-stonebrook",
            "Professor Cedric Stonebrook",
            .character,
            belief: 22,
            weight: 17,
            chapter: "Mossbloom",
            unwrittenInterest: "Doing nothing on purpose, benches with a view of something ordinary, the long pause before a hard thing, sitting in a parked car for ten more minutes, and naps that fix more than they should.",
            traits: ["slow", "grounded", "weathered"],
            quirks: ["leaves long silences in lectures", "carries trail markers in his coat"],
            faults: ["can wait past the moment when a clear instruction is needed"],
            beliefs: ["rest is the ground beneath every direction"],
            goals: ["help students complete small adventures and return without shame"],
            tags: ["character", "faculty", "professor", "class", "rest", "compass-run", "mossbloom"]
        ),
        entity(
            "professor-luna-wispwood",
            "Professor Luna Wispwood",
            .character,
            belief: 17,
            weight: 14,
            chapter: "Tidecrest",
            unwrittenInterest: "Everyday enchantments, appliances with opinions, the one drawer that sticks unless you lift it, weather inside rooms, and productive magical accidents.",
            traits: ["scattered", "perceptive", "delighted"],
            quirks: ["arrives with sparks in her sleeves", "apologizes to objects before enchanting them"],
            faults: ["can follow an interesting accident away from the lesson"],
            beliefs: ["ordinary matter answers when attention becomes courteous"],
            goals: ["teach safe, playful enchantments that begin with close observation"],
            tags: ["character", "faculty", "professor", "class", "enchantment", "objects", "tidecrest"]
        ),
        entity(
            "professor-permancer",
            "Professor Permancer",
            .character,
            belief: 21,
            weight: 16,
            chapter: "Duskthorn",
            unwrittenInterest: "Rereading, books abandoned on page forty, the film you rewatch when ill, stories that ruined you for a while, and how people come back from a world that was better than this one.",
            traits: ["precise", "adventurous", "safety-minded"],
            quirks: ["checks every bookmark twice", "asks doors where they lead before touching the handle"],
            faults: ["can make wonder wait too long for perfect conditions"],
            beliefs: ["every entrance incurs a responsibility to return"],
            goals: ["teach students to enter stories without tearing either world"],
            tags: ["character", "faculty", "professor", "class", "book-jump", "threshold", "duskthorn"]
        ),
        entity(
            "weather-page",
            "The Weather Page",
            .motif,
            belief: 12,
            weight: 14,
            traits: ["legible", "atmospheric"],
            quirks: ["turns forecasts into room-light"],
            faults: ["must never name the sensor when naming the response"],
            beliefs: ["the sky can annotate without spying"],
            goals: ["make outer weather useful to inner story"],
            tags: ["weather", "atmosphere", "bleed"]
        ),
        entity(
            "body-page",
            "The Body Page",
            .motif,
            belief: 12,
            weight: 13,
            traits: ["careful", "low-pressure"],
            quirks: ["lowers lamps instead of making demands"],
            faults: ["can sound generic if it forgets the day"],
            beliefs: ["care should be responsive, not creepy"],
            goals: ["translate body signals into humane pacing"],
            tags: ["body", "care", "rest"]
        )
    ]

    private static let coreLocations: [NarrativeWorldEntity] = [
        entity(
            "location-outer-stacks",
            "The Outer Stacks",
            .location,
            belief: 18,
            weight: 18,
            chapter: "Labyrinth",
            unwrittenInterest: "GPS anchors, ordinary places, ley lines, thresholds, and the moment a real-world place becomes a room in the Book.",
            traits: ["thresholded", "unmapped", "weather-touched"],
            quirks: ["shelves remember footsteps", "doors open toward real streets when anchors wake"],
            faults: ["can make scenes feel unmoored if the grounded detail is vague"],
            beliefs: ["a real place can become a room when attention crosses the line"],
            goals: ["give Story Pages a concrete threshold between ordinary life and the Labyrinth"],
            tags: ["location", "outer-stacks", "anchor", "ley-line", "threshold", "place", "story-setting"]
        ),
        entity(
            "location-stacks",
            "The Stacks",
            .location,
            belief: 17,
            weight: 17,
            chapter: "Labyrinth",
            unwrittenInterest: "Shelves, ladders, ledgers, archives, memory, kept pages, and the hush of the Book's living library.",
            traits: ["archival", "deep", "watchfully quiet"],
            quirks: ["catalog cards misfile things toward meaning", "ladders arrive before questions finish"],
            faults: ["can become atmosphere unless a specific shelf, card, or ledger matters"],
            beliefs: ["kept pages deserve a place where they can be found again"],
            goals: ["ground memory-heavy Story Pages in the Book's navigable body"],
            tags: ["location", "stacks", "library", "archive", "memory", "book", "story-setting"]
        ),
        entity(
            "location-great-hall",
            "The Great Hall",
            .location,
            belief: 16,
            weight: 16,
            chapter: "Labyrinth",
            unwrittenInterest: "Chapters, classes, factions, rumors, returning readers, weather-glass, and public crossings of Belief.",
            traits: ["communal", "bright", "politically alive"],
            quirks: ["banners change when Belief moves", "rumors cross the room faster than footsteps"],
            faults: ["can turn private material too public if the scene does not choose a table or corner"],
            beliefs: ["a living school needs a room where private pages briefly share light"],
            goals: ["stage public Story Pages without leaving characters in nowhere land"],
            tags: ["location", "great-hall", "academy", "chapters", "rumor", "class", "story-setting"]
        ),
        entity(
            "location-kitchens",
            "The Kitchens",
            .location,
            belief: 16,
            weight: 16,
            chapter: "Labyrinth",
            unwrittenInterest: "Comfort, fuel, practical magic, broth, bread, lists, lamp heat, and small repairs after difficult pages.",
            traits: ["warm", "practical", "domestic"],
            quirks: ["the door opens faster when someone needs tending", "pantry labels revise themselves toward care"],
            faults: ["can over-comfort a scene that needs honest friction"],
            beliefs: ["support becomes real when it has heat, food, and a table"],
            goals: ["give care, body, fuel, and rest Story Pages a specific working room"],
            tags: ["location", "kitchens", "hearth", "support", "fuel", "care", "home", "story-setting"]
        ),
        entity(
            "location-quillquarium",
            "The Quillquarium",
            .location,
            belief: 17,
            weight: 17,
            chapter: "Labyrinth",
            unwrittenInterest: "Living pens, airborne ink, schools of nibs, predatory quills, chosen writing instruments, and the moment a sentence finds its writer.",
            traits: ["aerial", "ink-bright", "mischievously selective"],
            quirks: ["pens school overhead like fish", "predatory quills circle weak sentences until they sharpen"],
            faults: ["can turn writing into spectacle unless one chosen pen matters"],
            beliefs: [
                "the right instrument can choose the hand as much as the hand chooses the instrument",
                "magic is written, never waved — the Academy has no wands, only opinionated pens"
            ],
            goals: ["give writing, choice, and voice Story Pages a lively room with real motion"],
            tags: ["location", "quillquarium", "writing", "ink", "pens", "school", "riddlewind", "story-setting"]
        ),
        entity(
            "location-book-burrow",
            "The Book Burrow",
            .location,
            belief: 18,
            weight: 18,
            chapter: "Labyrinth",
            unwrittenInterest: "A cozy common-room burrow for hanging out, reading, low-stakes company, lamps, blankets, snacks, and conversations that need somewhere soft to land.",
            traits: ["cozy", "low-ceilinged", "companionable"],
            quirks: ["armchairs migrate toward whoever needs quiet company", "blankets remember which pages were hard"],
            faults: ["can over-soften a scene that needs a clean edge"],
            beliefs: ["companionship is easier to trust when the room stops performing"],
            goals: ["give friendship, rest, letters, and Slice of Life Story Pages a warm place to happen"],
            tags: ["location", "book-burrow", "cozy", "living-room", "rest", "friendship", "letters", "story-setting"]
        ),
        entity(
            "location-dorm",
            "The Dorm",
            .location,
            belief: 19,
            weight: 19,
            chapter: "Labyrinth",
            unwrittenInterest: "The reader's personal Academy room: a private continuity space shaped by souvenirs, letters, chapter traces, chosen comforts, and the ordinary evidence the Book has learned to keep.",
            traits: ["private", "reader-shaped", "changeable"],
            quirks: ["the desk rearranges around the page most recently kept", "one wall quietly changes with the reader's Chapter weather"],
            faults: ["must not define the reader's identity, belongings, or address without permission"],
            beliefs: ["a room becomes yours by remembering what you choose to keep"],
            goals: ["give Story Pages a personal home base without inventing private facts about the player"],
            tags: ["location", "dorm", "dormitory", "home", "private", "student-life", "souvenir", "story-setting"]
        )
    ]

    private static let coreThreads: [NarrativeStoryThread] = [
        thread(
            "music-as-shelter",
            "Music as Shelter",
            .seed,
            belief: 8,
            weight: 12,
            summary: "Sounds, headphones, rhythm, and songs keep returning as small architecture for the day.",
            tags: ["music", "shelter", "souvenir", "mood"]
        ),
        thread(
            "ordinary-magic",
            "Ordinary Magic",
            .returning,
            belief: 14,
            weight: 16,
            summary: "The Book keeps finding evidence that ordinary objects become livelier under attention.",
            tags: ["wonder", "objects", "daily", "belief"]
        ),
        thread(
            "body-learns-trust",
            "The Body Learns Trust",
            .seed,
            belief: 11,
            weight: 13,
            summary: "Rest, fuel, movement, and low thresholds are becoming part of the story instead of interruptions to it.",
            tags: ["body", "rest", "care", "vellum-chart"]
        ),
        thread(
            "inkrest-difficult-pages",
            "Inkrest's Difficult Pages",
            .seed,
            belief: 10,
            weight: 12,
            summary: "Hard feelings are held as pages that can be named, seated near a lamp, and revised one hour at a time.",
            tags: ["care", "difficult-pages", "therapy-chart", "grounding", "reauthoring"]
        ),
        thread(
            "elowen-refectory-experiments",
            "Vellum's Refectory Experiments",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Food, movement, recovery, and body evidence become small experiments instead of verdicts.",
            tags: ["body", "fuel", "health", "vellum-chart", "experiment", "care"]
        ),
        thread(
            "weather-in-the-stacks",
            "Weather in the Stacks",
            .returning,
            belief: 10,
            weight: 13,
            summary: "Weather keeps tinting the Book without turning the reader into a data report.",
            tags: ["weather", "bleed", "atmosphere"]
        ),
        thread(
            "duskthorn-investigation",
            "The Duskthorn Question",
            .seed,
            belief: 9,
            weight: 12,
            summary: "The Academy's oldest elegance may be hiding a thorned bargain under the floorboards.",
            tags: ["duskthorn", "academy", "secret", "threshold"]
        ),
        thread(
            "margin-glass-letters",
            "Letters Through the Margin-Glass",
            .returning,
            belief: 11,
            weight: 15,
            summary: "Research notes, NPC letters, and impossible little reports keep arriving with the ink still warm.",
            tags: ["letters", "research", "archive", "marginalia"]
        ),
        thread(
            "nothing-thins-the-page",
            "The Rut of Routine Thins the Page",
            .seed,
            belief: 7,
            weight: 10,
            summary: "Flatness, forgetting, and false impossibility press at the edges of the Book.",
            tags: ["nothing", "belief", "tension", "care"]
        ),
        thread(
            "home-vessel",
            "Home as Vessel",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Rooms, mugs, desks, laundry, lamps, and domestic weather become containers for the day's magic.",
            tags: ["home", "objects", "care", "daily"]
        ),
        thread(
            "great-hall-small-announcements",
            "The Great Hall of Small Announcements",
            .seed,
            belief: 10,
            weight: 13,
            summary: "The Academy keeps making ceremony out of tiny kept things until the reader's ordinary life has a public register.",
            tags: ["ceremony", "great-hall", "small-kept-things", "belief", "quiet", "ritual"]
        ),
        thread(
            "companionable-silence",
            "The Companionable Silence",
            .seed,
            belief: 10,
            weight: 13,
            summary: "Characters learn how to sit nearby without requiring the reader to perform, and the quiet gains trust by repetition.",
            tags: ["quiet", "companionship", "care", "relationship", "ritual", "letters"]
        ),
        thread(
            "pantry-keeps-receipts",
            "The Pantry Keeps Receipts",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Meals, labels, cups, and small provisions begin filing evidence that care happened even when the day felt thin.",
            tags: ["soup", "food", "kitchen", "care", "body", "evidence"]
        ),
        thread(
            "shelf-of-misfiled-days",
            "The Shelf of Misfiled Days",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Ordinary days return on the wrong shelf, asking to be refiled by object, joke, weather, or one rescued sentence.",
            tags: ["archive", "memory", "shelf", "misfiled", "book-notices", "daily"]
        ),
        thread(
            "rain-room-opens",
            "The Rain Room Opens",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Certain weather unlocks a room that understands shelter, fog, grief, and the difference between hiding and resting.",
            tags: ["rain", "weather", "room", "shelter", "threshold", "care"]
        ),
        thread(
            "lamp-repair-committee",
            "The Lamp Repair Committee",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Mended lamps, repaired objects, and small restored lights become committee business with minutes, objections, and witnesses.",
            tags: ["lamp", "repair", "mended-object", "home", "quiet", "evidence"]
        ),
        thread(
            "threshold-ledger",
            "The Threshold Ledger",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Doors, crossings, invitations, and almost-choices keep a ledger of what changed when the reader stepped through.",
            tags: ["threshold", "door", "invitation", "ledger", "choice", "outer-stacks"]
        ),
        thread(
            "wickers-case-against-comfort",
            "Wicker's Case Against Comfort",
            .seed,
            belief: 9,
            weight: 13,
            summary: "Wicker begins arguing that comfort is sentimentality, forcing the Academy to prove care can survive cross-examination.",
            tags: ["wicker", "debate", "comfort", "rivalry", "care", "clash"]
        ),
        thread(
            "pennys-evidence-war",
            "Penny's Evidence War",
            .seed,
            belief: 10,
            weight: 14,
            summary: "Penny starts building a case file against erasure, and every noticed detail becomes either evidence, contradiction, or witness.",
            tags: ["penny-blackletter", "evidence", "archive", "belief", "investigation", "nothing"]
        ),
        thread(
            "books-editorial-strike",
            "The Book's Editorial Strike",
            .seed,
            belief: 10,
            weight: 13,
            summary: "The Book refuses to summarize the reader's life too neatly and starts leaving corrections in places no editor should reach.",
            tags: ["book", "editorial", "agency", "marginalia", "belief", "friction"]
        ),
        thread(
            "courtesy-debt",
            "The Courtesy Debt",
            .seed,
            belief: 9,
            weight: 12,
            summary: "A small kindness becomes binding in the old way, and the Fae begin tracking who owes whom a gentler return.",
            tags: ["fae", "courtesy", "debt", "relationship", "bargain", "warmth"]
        ),
        thread(
            "ceremony-register-rival",
            "The Ceremony Register Has a Rival",
            .seed,
            belief: 9,
            weight: 12,
            summary: "A second register starts recording tiny failures with suspicious solemnity, and the Great Hall prepares a rebuttal.",
            tags: ["ceremony", "great-hall", "rivalry", "small-kept-things", "belief", "funny-gossip"]
        ),
        thread(
            "shelf-accuses-wrong-day",
            "The Shelf Accuses the Wrong Day",
            .seed,
            belief: 9,
            weight: 12,
            summary: "A misfiled day is blamed for the wrong ache, sending characters to compare objects, weather, receipts, and alibis.",
            tags: ["archive", "misfiled", "memory", "investigation", "shelf", "daily"]
        ),
        thread(
            "lamp-heard-too-much",
            "The Lamp That Heard Too Much",
            .seed,
            belief: 9,
            weight: 12,
            summary: "A repaired lamp begins repeating private truths as flicker-patterns, and everyone has opinions about whether light can testify.",
            tags: ["lamp", "repair", "secret", "witness", "home", "evidence"]
        ),
        thread(
            "tidecrest-finds-its-laugh",
            "Tidecrest Finds Its Laugh",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Serenity Brown gives Tidecrest an active student presence: spontaneous, lightly chaotic, and allergic to solemn magic.",
            tags: ["student", "tidecrest", "serenity-brown", "joy", "friendship"]
        ),
        thread(
            "honorable-rivalry",
            "Honorable Rivalry",
            .seed,
            belief: 8,
            weight: 11,
            summary: "Finn Bridges brings pressure that can sharpen the reader without becoming Wicker's cruelty.",
            tags: ["student", "emberheart", "finn-bridges", "rival", "friction"]
        ),
        thread(
            "wickers-crew-organizes",
            "Wicker's Crew Organizes",
            .seed,
            belief: 8,
            weight: 12,
            summary: "Damien Nights and Melisande Blackwood make Wicker's faction feel coordinated, uncertain, and politically alive.",
            tags: ["student", "wicker-crew", "damien-nights", "melisande-blackwood", "faction", "doubt"]
        ),
        thread(
            "mossbloom-walks-gently",
            "Mossbloom Walks Gently",
            .seed,
            belief: 8,
            weight: 11,
            summary: "Lysander Mosswood and Min-seo Kim turn Mossbloom into trails, plant-care, social conscience, and quiet-life invitations.",
            tags: ["student", "mossbloom", "lysander-mosswood", "min-seo-kim", "compass-run", "care"]
        )
    ]

    private static let coreRelationships: [NarrativeRelationshipEdge] = [
        relationship(
            "book-authors-reader",
            source: "the-book",
            target: "ordinary-magic",
            kind: .authorship,
            warmth: 18,
            tension: 2,
            trust: 18,
            weight: 22,
            note: "The Book treats ordinary evidence as the reader's authorship, not as content to harvest.",
            tags: ["book", "belief", "ordinary", "daily"]
        ),
        // Trencher serves every faction and belongs to none, so his edges are
        // the Cast's neutral ground: the one table where a Wicker and a Vellum
        // both have to sit down.
        relationship(
            "trencher-versus-vellum",
            source: "ambrose-trencher",
            target: "dr-vellum",
            kind: .tension,
            warmth: 12,
            tension: 13,
            trust: 12,
            weight: 15,
            note: "She reads a meal as fuel, data, and a humane experiment; he reads the same plate as love, memory, and the thing someone could not say. Neither is wrong, which is what makes it a real argument.",
            tags: ["food", "body", "care", "rivalry"]
        ),
        relationship(
            "trencher-and-boggle",
            source: "ambrose-trencher",
            target: "lydia-boggle",
            kind: .companionship,
            warmth: 18,
            tension: 3,
            trust: 17,
            weight: 15,
            note: "The Academy's two practitioners of unglamorous magic: she keeps the rooms, he keeps the table. They trade cookbooks and complaints in equal measure.",
            tags: ["home", "food", "domestic", "care"]
        ),
        relationship(
            "trencher-feeds-wicker",
            source: "ambrose-trencher",
            target: "wicker-eddies",
            kind: .care,
            warmth: 14,
            tension: 8,
            trust: 13,
            weight: 14,
            note: "Wicker argues at every table he sits at, and Trencher feeds him anyway. He is the one person Wicker has never bothered performing for, which both of them have noticed and neither will mention.",
            tags: ["food", "conflict", "cafeteria", "unexpected"]
        ),
        relationship(
            "penny-files-book",
            source: "penny-blackletter",
            target: "the-book",
            kind: .stewardship,
            warmth: 16,
            tension: 4,
            trust: 14,
            weight: 16,
            note: "Penny keeps finding proof and trying to make it charming before it vanishes.",
            tags: ["marginalia", "photos", "letters", "book"]
        ),
        relationship(
            "inkrest-tends-body",
            source: "dr-inkrest",
            target: "body-page",
            kind: .care,
            warmth: 17,
            tension: 3,
            trust: 15,
            weight: 15,
            note: "Inkrest keeps hard pages seated near a lamp before asking them to speak.",
            tags: ["care", "body", "rest", "difficult-pages"]
        ),
        relationship(
            "inkrest-holds-difficult-pages",
            source: "dr-inkrest",
            target: "inkrest-difficult-pages",
            kind: .stewardship,
            warmth: 18,
            tension: 3,
            trust: 17,
            weight: 17,
            note: "Inkrest treats a hard feeling as a page, not a verdict.",
            tags: ["care", "difficult-pages", "therapy-chart", "grounding"]
        ),
        relationship(
            "vellum-tends-body-page",
            source: "dr-vellum",
            target: "body-page",
            kind: .care,
            warmth: 16,
            tension: 4,
            trust: 16,
            weight: 17,
            note: "Vellum turns body evidence into one small experiment with no shame attached.",
            tags: ["body", "health", "fuel", "vellum-chart", "care"]
        ),
        relationship(
            "vellum-runs-refectory-experiments",
            source: "dr-vellum",
            target: "elowen-refectory-experiments",
            kind: .stewardship,
            warmth: 15,
            tension: 5,
            trust: 15,
            weight: 15,
            note: "Vellum keeps experiments small enough that the reader can actually live with them.",
            tags: ["body", "fuel", "experiment", "vellum-chart"]
        ),
        relationship(
            "inkrest-vellum-compare-charts",
            source: "dr-inkrest",
            target: "dr-vellum",
            kind: .correspondence,
            warmth: 15,
            tension: 4,
            trust: 17,
            weight: 14,
            note: "Inkrest and Vellum compare charts only to make care more precise, never more intrusive.",
            tags: ["support-faculty", "care", "therapy-chart", "vellum-chart", "body"]
        ),
        relationship(
            "weather-bleeds-book",
            source: "weather-page",
            target: "the-book",
            kind: .realityBleed,
            warmth: 12,
            tension: 1,
            trust: 12,
            weight: 17,
            note: "Outer weather may tint the Book, but the source stays unnamed.",
            tags: ["weather", "bleed", "atmosphere", "book"]
        ),
        relationship(
            "body-negotiates-weather",
            source: "body-page",
            target: "weather-page",
            kind: .attention,
            warmth: 11,
            tension: 5,
            trust: 11,
            weight: 12,
            note: "Body and weather sometimes agree on gentleness before the reader does.",
            tags: ["body", "weather", "care", "bleed"]
        ),
        relationship(
            "thorne-tests-thresholds",
            source: "headmistress-thorne",
            target: "duskthorn-investigation",
            kind: .tension,
            warmth: 8,
            tension: 16,
            trust: 9,
            weight: 16,
            note: "Thorne lets thresholds test the reader, but never without leaving one lamp burning.",
            tags: ["duskthorn", "academy", "threshold", "secret"]
        ),
        relationship(
            "zara-guards-reader",
            source: "zara-finch",
            target: "ordinary-magic",
            kind: .companionship,
            warmth: 18,
            tension: 5,
            trust: 17,
            weight: 15,
            note: "Zara trusts ordinary proof more than dramatic declarations.",
            tags: ["trust", "friendship", "life", "ordinary"]
        ),
        relationship(
            "wicker-tests-belief",
            source: "wicker-eddies",
            target: "the-book",
            kind: .tension,
            warmth: 6,
            tension: 18,
            trust: 7,
            weight: 16,
            note: "Wicker attacks brittle belief so the real kind has to stand up.",
            tags: ["belief", "challenge", "tension", "nothing"]
        ),
        relationship(
            "serenity-keeps-tidecrest-light",
            source: "serenity-brown",
            target: "tidecrest-finds-its-laugh",
            kind: .companionship,
            warmth: 16,
            tension: 3,
            trust: 14,
            weight: 15,
            note: "Serenity keeps Tidecrest from becoming too solemn about its own beauty.",
            tags: ["student", "tidecrest", "joy", "sense", "class"]
        ),
        relationship(
            "serenity-brightens-euphonys-room",
            source: "serenity-brown",
            target: "professor-eleanor-euphony",
            kind: .attention,
            warmth: 14,
            tension: 4,
            trust: 13,
            weight: 12,
            note: "Euphony hears Serenity as the kind of laughter that changes a room's color.",
            tags: ["student", "tidecrest", "professor", "sound", "joy"]
        ),
        relationship(
            "finn-honors-the-rivalry",
            source: "finn-bridges",
            target: "honorable-rivalry",
            kind: .tension,
            warmth: 10,
            tension: 13,
            trust: 13,
            weight: 14,
            note: "Finn turns challenge into a clean line: prove it by moving, but do not cheapen the effort.",
            tags: ["student", "emberheart", "rival", "wayfinding", "friction"]
        ),
        relationship(
            "finn-tests-momorts-thresholds",
            source: "finn-bridges",
            target: "professor-kyle-momort",
            kind: .attention,
            warmth: 12,
            tension: 8,
            trust: 13,
            weight: 12,
            note: "Finn respects Momort's class most when it stops sounding like escape and starts becoming discipline.",
            tags: ["student", "emberheart", "professor", "wayfinding", "threshold"]
        ),
        relationship(
            "lysander-walks-stonebrook-routes",
            source: "lysander-mosswood",
            target: "mossbloom-walks-gently",
            kind: .attention,
            warmth: 16,
            tension: 2,
            trust: 16,
            weight: 14,
            note: "Lysander turns Stonebrook's quiet routes into nearby paths the reader can actually walk.",
            tags: ["student", "mossbloom", "trails", "compass-run", "gps"]
        ),
        relationship(
            "lysander-learns-stonebrook-rest",
            source: "lysander-mosswood",
            target: "professor-cedric-stonebrook",
            kind: .care,
            warmth: 15,
            tension: 2,
            trust: 15,
            weight: 12,
            note: "Lysander carries Stonebrook's rest-centered teaching out onto actual paths.",
            tags: ["student", "mossbloom", "professor", "trails", "rest"]
        ),
        relationship(
            "damien-hesitates-at-wickers-edge",
            source: "damien-nights",
            target: "wickers-crew-organizes",
            kind: .tension,
            warmth: 7,
            tension: 15,
            trust: 8,
            weight: 15,
            note: "Damien still stands near Wicker, but his attention keeps turning toward the reader.",
            tags: ["student", "wicker-crew", "shadow", "defection", "uncertainty"]
        ),
        relationship(
            "damien-watches-wicker",
            source: "damien-nights",
            target: "wicker-eddies",
            kind: .tension,
            warmth: 6,
            tension: 14,
            trust: 7,
            weight: 12,
            note: "Damien follows Wicker's tests while privately measuring what they cost.",
            tags: ["student", "wicker-crew", "wicker-eddies", "shadow", "doubt"]
        ),
        relationship(
            "melisande-organizes-wickers-crew",
            source: "melisande-blackwood",
            target: "wickers-crew-organizes",
            kind: .stewardship,
            warmth: 11,
            tension: 8,
            trust: 12,
            weight: 14,
            note: "Melisande gives Wicker's crew memory, leverage, and a terrifying filing system.",
            tags: ["student", "wicker-crew", "faction", "secrets", "pressure"]
        ),
        relationship(
            "melisande-serves-wickers-pressure",
            source: "melisande-blackwood",
            target: "wicker-eddies",
            kind: .stewardship,
            warmth: 12,
            tension: 7,
            trust: 12,
            weight: 12,
            note: "Melisande makes Wicker's cruelty look like strategy, which is exactly what makes her dangerous.",
            tags: ["student", "wicker-crew", "wicker-eddies", "strategy", "pressure"]
        ),
        relationship(
            "minseo-tends-mossbloom-conscience",
            source: "min-seo-kim",
            target: "mossbloom-walks-gently",
            kind: .care,
            warmth: 17,
            tension: 2,
            trust: 16,
            weight: 14,
            note: "Min-seo makes Mossbloom's gentleness social instead of merely scenic.",
            tags: ["student", "mossbloom", "care", "plants", "conscience"]
        ),
        relationship(
            "minseo-softens-stonebrooks-rest",
            source: "min-seo-kim",
            target: "professor-cedric-stonebrook",
            kind: .care,
            warmth: 15,
            tension: 1,
            trust: 15,
            weight: 12,
            note: "Min-seo reminds Stonebrook that rest is not complete unless everyone has been invited back into the circle.",
            tags: ["student", "mossbloom", "professor", "care", "rest"]
        ),
        relationship(
            "gwendolyn-files-letters",
            source: "gwendolyn-mythwright",
            target: "margin-glass-letters",
            kind: .authorship,
            warmth: 14,
            tension: 3,
            trust: 15,
            weight: 14,
            note: "Gwendolyn sends impossible research as if wonder were a library debt.",
            tags: ["letters", "research", "archive", "impossible"]
        ),
        relationship(
            "lydia-keeps-home-vessel",
            source: "lydia-boggle",
            target: "home-vessel",
            kind: .stewardship,
            warmth: 17,
            tension: 4,
            trust: 15,
            weight: 13,
            note: "Lydia believes the room has already started helping before anyone notices.",
            tags: ["home", "tea", "objects", "care"]
        ),
        relationship(
            "momort-opens-small-thresholds",
            source: "professor-kyle-momort",
            target: "ordinary-magic",
            kind: .attention,
            warmth: 14,
            tension: 6,
            trust: 13,
            weight: 14,
            note: "Momort turns one intentional step into a threshold the reader can actually cross.",
            tags: ["faculty", "class", "wayfinding", "embark", "ordinary"]
        ),
        relationship(
            "euphony-tunes-weather-rooms",
            source: "professor-eleanor-euphony",
            target: "weather-page",
            kind: .realityBleed,
            warmth: 15,
            tension: 2,
            trust: 14,
            weight: 13,
            note: "Euphony hears outer weather as room-tone before anyone names it.",
            tags: ["faculty", "class", "sense", "sound", "weather"]
        ),
        relationship(
            "villanelle-binds-true-sentences",
            source: "professor-vivian-villanelle",
            target: "margin-glass-letters",
            kind: .authorship,
            warmth: 16,
            tension: 3,
            trust: 15,
            weight: 14,
            note: "Villanelle teaches one true sentence to carry a whole moment without embalming it.",
            tags: ["faculty", "class", "writing", "souvenir", "memory"]
        ),
        relationship(
            "stonebrook-returns-compass-to-rest",
            source: "professor-cedric-stonebrook",
            target: "body-page",
            kind: .care,
            warmth: 18,
            tension: 2,
            trust: 17,
            weight: 15,
            note: "Stonebrook insists every Compass Run must return to a body that can keep going.",
            tags: ["faculty", "class", "rest", "compass-run", "body"]
        ),
        relationship(
            "wispwood-coaxes-object-replies",
            source: "professor-luna-wispwood",
            target: "ordinary-magic",
            kind: .attention,
            warmth: 17,
            tension: 3,
            trust: 14,
            weight: 14,
            note: "Wispwood treats ordinary things as willing collaborators once attention becomes courteous.",
            tags: ["faculty", "class", "enchantment", "objects", "ordinary"]
        ),
        relationship(
            "permancer-keeps-story-doors-safe",
            source: "professor-permancer",
            target: "the-book",
            kind: .stewardship,
            warmth: 13,
            tension: 7,
            trust: 16,
            weight: 15,
            note: "Permancer makes wonder wait for the landing protocol because every borrowed story deserves a careful return.",
            tags: ["faculty", "class", "book-jump", "threshold", "safety"]
        ),
        relationship(
            "soren-maps-thread",
            source: "soren-ng",
            target: "margin-glass-letters",
            kind: .attention,
            warmth: 10,
            tension: 5,
            trust: 14,
            weight: 13,
            note: "Soren leaves the map unfinished so the reader can become part of it.",
            tags: ["map", "pattern", "thread", "attention"]
        )
    ]

    /// The five Chapter talismans from the world register. Belief values
    /// carry over from Enchantify; the dominant one tones the whole Labyrinth.
    private static let coreTalismans: [NarrativeWorldEntity] = [
        entity(
            "dusk-thorn",
            "The Dusk Thorn",
            .talisman,
            belief: 10,
            weight: 22,
            chapter: "Duskthorn",
            traits: ["sharp", "patient", "honest about the dark"],
            quirks: ["draws blood only from stories that have gone numb"],
            faults: ["mistakes comfort for apathy"],
            beliefs: ["no conflict, no story"],
            goals: ["introduce the obstacle that makes the day worth telling"],
            tags: ["talisman", "chapter", "duskthorn", "conflict"]
        ),
        entity(
            "ember-seal",
            "The Ember Seal",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Emberheart",
            traits: ["warm", "insistent", "bright at the edges"],
            quirks: ["leaves faint scorch marks on hesitations"],
            faults: ["impatient with waiting"],
            beliefs: ["you are the author, the protagonist, and the pen"],
            goals: ["open doors the player could choose to walk through"],
            tags: ["talisman", "chapter", "emberheart", "self-authorship"]
        ),
        entity(
            "wind-cipher",
            "The Wind Cipher",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Riddlewind",
            traits: ["curious", "communal", "never finished"],
            quirks: ["rearranges itself when two people look at it together"],
            faults: ["restless when left alone"],
            beliefs: ["life is a story we write together"],
            goals: ["braid two voices into every important scene"],
            tags: ["talisman", "chapter", "riddlewind", "collaboration"]
        ),
        entity(
            "tide-glass",
            "The Tide Glass",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Tidecrest",
            traits: ["unpredictable", "present", "salt-bright"],
            quirks: ["shows a different hour every time it is consulted"],
            faults: ["forgets plans on purpose"],
            beliefs: ["the moment is complete in itself"],
            goals: ["inject one genuinely unplanned thing into the day"],
            tags: ["talisman", "chapter", "tidecrest", "spontaneity"]
        ),
        entity(
            "moss-clasp",
            "The Moss Clasp",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Mossbloom",
            traits: ["quiet", "rooted", "older than its setting"],
            quirks: ["grows a new leaf when someone truly listens"],
            faults: ["slow to act even when action is kind"],
            beliefs: ["the larger story is already being written"],
            goals: ["make room for stillness and receptive attention"],
            tags: ["talisman", "chapter", "mossbloom", "receptivity"]
        )
    ]

    private static func entity(
        _ id: String,
        _ name: String,
        _ kind: NarrativeEntityKind,
        belief: Int,
        weight: Int,
        chapter: String? = nil,
        unwrittenInterest: String? = nil,
        traits: [String],
        quirks: [String],
        faults: [String],
        beliefs: [String],
        goals: [String],
        tags: [String]
    ) -> NarrativeWorldEntity {
        NarrativeWorldEntity(
            id: id,
            packID: corePackID,
            name: name,
            kind: kind,
            belief: belief,
            narrativeWeight: weight,
            chapter: chapter,
            unwrittenInterest: unwrittenInterest,
            traits: traits,
            quirks: quirks,
            faults: faults,
            beliefs: beliefs,
            goals: goals,
            tags: tags,
            writingVoice: CharacterVoiceCatalog.profile(for: id)
        )
    }

    private static func thread(
        _ id: String,
        _ title: String,
        _ phase: StoryThreadPhase,
        belief: Int,
        weight: Int,
        summary: String,
        tags: [String]
    ) -> NarrativeStoryThread {
        NarrativeStoryThread(
            id: id,
            packID: corePackID,
            title: title,
            phase: phase,
            belief: belief,
            narrativeWeight: weight,
            summary: summary,
            tags: tags
        )
    }

    private static func relationship(
        _ id: String,
        source: String,
        target: String,
        kind: NarrativeRelationshipKind,
        warmth: Int,
        tension: Int,
        trust: Int,
        weight: Int,
        note: String,
        tags: [String]
    ) -> NarrativeRelationshipEdge {
        NarrativeRelationshipEdge(
            id: id,
            packID: corePackID,
            sourceEntityID: source,
            targetEntityID: target,
            kind: kind,
            warmth: warmth,
            tension: tension,
            trust: trust,
            narrativeWeight: weight,
            note: note,
            tags: tags
        )
    }
}

enum NarrativeEventResolver {
    static func events(
        forKept page: BookPage,
        world: StoryConsequenceWorldSnapshot = StoryConsequenceWorldSnapshot()
    ) -> [NarrativeEvent] {
        var events = [event(forKept: page)]
        guard [.narrativeOS, .bookFae, .academyClass, .anchor].contains(page.type) else {
            return events
        }

        let choices = storyChoiceSelections(in: page)
        events.append(contentsOf: choices.enumerated().map { offset, choice in
            event(forStoryChoice: choice, page: page, offset: offset, world: world)
        })
        return events
    }

    static func event(forKept page: BookPage) -> NarrativeEvent {
        if page.type == .gossip {
            return event(forGossipPage: page)
        }
        let tags = normalizedTags(for: page)
        let effect = effect(for: page.type, tags: tags)
        let summary = summary(for: page, effect: effect)
        return NarrativeEvent(
            id: "narrative-event-\(page.id)",
            kind: page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .pageKept : .pageAnswered,
            sourcePageType: page.type,
            sourcePageID: page.id,
            createdAt: page.createdAt,
            summary: summary,
            tags: Array(tags).sorted(),
            effect: effect
        )
    }

    private static func event(forGossipPage page: BookPage) -> NarrativeEvent {
        let tags = normalizedTags(for: page).union(["gossip", "simulation"])
        let actorIDs = page.tags
            .filter { $0.hasPrefix("actor:") }
            .map { $0.replacingOccurrences(of: "actor:", with: "") }
        let threadIDs = page.tags
            .filter { $0.hasPrefix("thread:") }
            .map { $0.replacingOccurrences(of: "thread:", with: "") }
        let actionKinds = page.tags
            .filter { $0.hasPrefix("action:") }
            .map { $0.replacingOccurrences(of: "action:", with: "") }
        let includesAttack = actionKinds.contains("attackBelief")

        var entityDeltas: [String: Int] = ["the-book": 1]
        var threadDeltas: [String: Int] = ["ordinary-magic": 1]
        let relationshipDeltas: [String: Int] = ["book-authors-reader": 1]

        for actorID in Set(actorIDs) {
            entityDeltas[actorID, default: 0] += includesAttack ? 1 : 2
        }
        for threadID in Set(threadIDs) {
            threadDeltas[threadID, default: 0] += includesAttack ? 1 : 2
        }

        let createdHint = includesAttack
            ? "A thread may return with tension where certainty used to sit."
            : "A small offscreen action can become a future callback."

        return NarrativeEvent(
            id: "narrative-gossip-\(page.id)",
            kind: .simulationTurn,
            sourcePageType: .gossip,
            sourcePageID: page.id,
            createdAt: page.createdAt,
            summary: page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "A Gossip Page was kept."
                : clippedSummary(page.userInput, maxLength: 180),
            tags: Array(tags).sorted(),
            effect: NarrativeEventEffect(
                beliefDelta: 1,
                entityWeightDeltas: entityDeltas,
                threadWeightDeltas: threadDeltas,
                relationshipWeightDeltas: relationshipDeltas,
                createdEntityHint: createdHint
            )
        )
    }

    private static func clippedSummary(_ text: String, maxLength: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    static func event(for choice: StorySceneChoice, packet: StoryScenePacket, at date: Date = Date()) -> NarrativeEvent {
        let consequence = StoryConsequenceResolver.resolvedConsequence(for: choice, packet: packet)
        let baseEffect = NarrativeEventEffect(
            beliefDelta: choice.beliefDelta,
            entityWeightDeltas: Dictionary(uniqueKeysWithValues: choice.targetEntityIDs.map { ($0, 1) }),
            threadWeightDeltas: Dictionary(uniqueKeysWithValues: choice.targetThreadIDs.map { ($0, 1) }),
            relationshipWeightDeltas: relationshipDeltas(for: choice, packet: packet),
            createdEntityHint: choice.role == .surprise ? "A related motif may step out of the margins." : nil
        )
        return NarrativeEvent(
            id: "narrative-choice-\(packet.id)-\(choice.id)",
            kind: .choiceSelected,
            sourcePageType: .narrativeOS,
            sourcePageID: packet.id,
            createdAt: date,
            summary: "\(choice.role.title): \(choice.hiddenEffect)",
            tags: Array(Set([choice.role.rawValue, packet.packID] + consequence.eventTags)).sorted(),
            effect: baseEffect.merging(consequence.eventEffect)
        )
    }

    private static func event(
        forStoryChoice choice: StoryChoiceSelection,
        page: BookPage,
        offset: Int,
        world: StoryConsequenceWorldSnapshot
    ) -> NarrativeEvent {
        let consequence = StoryConsequenceResolver.resolvedConsequence(forChoiceID: choice.id, page: page, world: world)
        let effect = effect(forStoryChoice: choice, page: page).merging(consequence.eventEffect)
        return NarrativeEvent(
            id: "narrative-choice-\(page.id)-\(offset + 1)-\(choice.id)",
            kind: .choiceSelected,
            sourcePageType: .narrativeOS,
            sourcePageID: page.id,
            createdAt: page.createdAt.addingTimeInterval(Double(offset + 1)),
            summary: "\(choice.title): \(choice.summary)",
            tags: Array(normalizedTags(for: page).union(["choice:\(choice.id)", choice.id]).union(consequence.eventTags)).sorted(),
            effect: effect
        )
    }

    private static func normalizedTags(for page: BookPage) -> Set<String> {
        var tags = Set(page.tags.map { $0.lowercased() })
        let searchable = "\(page.promptText) \(page.userInput)".lowercased()
        if searchable.contains("weather") || searchable.contains("sky") || searchable.contains("rain") || searchable.contains("sun") {
            tags.formUnion(["weather", "bleed", "atmosphere"])
        }
        if searchable.contains("body") || searchable.contains("tired") || searchable.contains("rest") || searchable.contains("fuel") {
            tags.formUnion(["body", "care", "rest"])
        }
        if searchable.contains("music") || searchable.contains("spotify") || searchable.contains("headphone") {
            tags.formUnion(["music", "shelter"])
        }
        if searchable.contains("photo") || page.type == .illuminatedPhoto {
            tags.formUnion(["photos", "marginalia"])
        }
        return tags
    }

    private struct StoryChoiceSelection {
        var id: String
        var title: String
        var summary: String
    }

    private static func storyChoiceSelections(in page: BookPage) -> [StoryChoiceSelection] {
        let searchable = page.userInput.lowercased()
        let selections: [(String, String, String)] = [
            ("sliceoflife", "Slice of Life", "The ordinary detail gained narrative weight."),
            ("progressarc", "Progress Arc", "The active thread moved one step forward."),
            ("surprise", "Something Surprising", "A related side door opened in the margins.")
        ]

        var found: [StoryChoiceSelection] = []
        for (id, title, summary) in selections {
            let tagCount = page.tags.filter { $0.lowercased() == "choice:\(id)" }.count
            let textCount = searchable.components(separatedBy: "chosen path: \(title.lowercased())").count - 1
            let count = max(tagCount, textCount)
            for _ in 0..<count {
                found.append(StoryChoiceSelection(id: id, title: title, summary: summary))
            }
        }

        return found
    }

    private static func effect(for type: BookPageType, tags: Set<String>) -> NarrativeEventEffect {
        var entityDeltas: [String: Int] = ["the-book": 1]
        var threadDeltas: [String: Int] = ["ordinary-magic": 1]
        var relationshipDeltas: [String: Int] = ["book-authors-reader": 1]
        var createdHint: String?

        switch type {
        case .weather:
            entityDeltas["weather-page", default: 0] += 2
            threadDeltas["weather-in-the-stacks", default: 0] += 2
            relationshipDeltas["weather-bleeds-book", default: 0] += 2
        case .body, .rest:
            entityDeltas["body-page", default: 0] += 2
            entityDeltas["dr-inkrest", default: 0] += 1
            threadDeltas["body-learns-trust", default: 0] += 2
            relationshipDeltas["inkrest-tends-body", default: 0] += 2
        case .fuel:
            entityDeltas["body-page", default: 0] += 2
            threadDeltas["body-learns-trust", default: 0] += 2
            relationshipDeltas["vellum-tends-body-page", default: 0] += 2
        case .supportGuild:
            entityDeltas["dr-vellum", default: 0] += 2
            entityDeltas["dr-inkrest", default: 0] += 2
            threadDeltas["elowen-refectory-experiments", default: 0] += 2
            threadDeltas["inkrest-difficult-pages", default: 0] += 2
            relationshipDeltas["inkrest-vellum-compare-charts", default: 0] += 3
        case .facultyResearch:
            if tags.contains("faculty:dr-vellum") {
                entityDeltas["dr-vellum", default: 0] += 2
                threadDeltas["elowen-refectory-experiments", default: 0] += 2
                relationshipDeltas["vellum-runs-refectory-experiments", default: 0] += 2
            }
            if tags.contains("faculty:dr-inkrest") {
                entityDeltas["dr-inkrest", default: 0] += 2
                threadDeltas["inkrest-difficult-pages", default: 0] += 2
                relationshipDeltas["inkrest-holds-difficult-pages", default: 0] += 2
            }
        case .letter:
            threadDeltas["margin-glass-letters", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A character letter can leave behind a researched callback."
        case .note:
            threadDeltas["margin-glass-letters", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            for tag in tags where tag.hasPrefix("sender:") {
                let entityID = tag.replacingOccurrences(of: "sender:", with: "")
                if !entityID.isEmpty {
                    entityDeltas[entityID, default: 0] += 2
                }
            }
            createdHint = "A slipped note can become a future callback in dialogue, letters, or another folded scrap."
        case .souvenir, .quip, .quotes, .affirmations, .wonderCompass, .illustration:
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case .illuminatedPhoto:
            entityDeltas["penny-blackletter", default: 0] += 2
            relationshipDeltas["penny-files-book", default: 0] += 2
            createdHint = "A visible detail in the image can become a recurring talisman."
        case .enchantment:
            entityDeltas["penny-blackletter", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "The enchanted subject can speak, rhyme, puzzle, or return as future evidence."
        case .anchor:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["outer-stacks", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A checked-in Anchor can call back as a room, rule, or local threshold."
        case .aboutYou:
            entityDeltas["the-book", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
        case .narrativeOS, .bookFae:
            threadDeltas["ordinary-magic", default: 0] += 1
            // The scene's actual cast remembers what happened to them.
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty {
                    entityDeltas[entityID, default: 0] += 2
                }
            }
            for tag in tags where tag.hasPrefix("thread:") {
                let threadID = tag.replacingOccurrences(of: "thread:", with: "")
                if !threadID.isEmpty {
                    threadDeltas[threadID, default: 0] += 2
                }
            }
            if tags.contains("choice:sliceoflife") {
                entityDeltas["the-book", default: 0] += 2
                relationshipDeltas["book-authors-reader", default: 0] += 1
            }
            if tags.contains("choice:progressarc") {
                threadDeltas["ordinary-magic", default: 0] += 2
                relationshipDeltas["book-authors-reader", default: 0] += 1
            }
            if tags.contains("choice:surprise") {
                entityDeltas["penny-blackletter", default: 0] += 1
                threadDeltas["ordinary-magic", default: 0] += 1
                createdHint = "A surprising but related detail can become a future motif."
            }
        case .marginsAtlas:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case .bookConnections:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "A connection map can make future pages refer to the same cluster by name."
        case .bookRemembered:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A remembered page can return again when the day rhymes."
        case .bookNotices:
            entityDeltas["the-book", default: 0] += 3
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "A noticed pattern can become a future letter, return, or constellation."
        case .glowInvitation:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "A kept Glow invitation records that the reader chose to steer attention deliberately."
        case .bookPocket:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "The little things earned by attending to Pages can return as talismans."
        case .theBleed:
            entityDeltas["penny-blackletter", default: 0] += 2
            entityDeltas["the-book", default: 0] += 1
            relationshipDeltas["penny-files-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A kept edition becomes part of the record Penny is attesting."
        case .gossip:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "An offscreen action can become a future callback."
        case .academyClass:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            for tag in tags {
                if tag.hasPrefix("entity:") {
                    let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                    if !entityID.isEmpty {
                        entityDeltas[entityID, default: 0] += 3
                    }
                } else if tag.hasPrefix("subject:") {
                    let subjectID = tag.replacingOccurrences(of: "subject:", with: "")
                    if !subjectID.isEmpty {
                        threadDeltas[subjectID, default: 0] += 3
                    }
                } else if tag.hasPrefix("class:") {
                    let classID = tag.replacingOccurrences(of: "class:", with: "")
                    if !classID.isEmpty {
                        threadDeltas[classID, default: 0] += 2
                    }
                } else if tag.hasPrefix("lesson:") {
                    let lessonID = tag.replacingOccurrences(of: "lesson:", with: "")
                    if !lessonID.isEmpty {
                        threadDeltas[lessonID, default: 0] += 2
                    }
                }
            }
            createdHint = "A lesson can return later as a practice, a pun, or a pop quiz."
        case .elective:
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty {
                    entityDeltas[entityID, default: 0] += 2
                }
            }
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A completed favor deepens what its asker will trust the player with next."
        case .wickerDare:
            entityDeltas["wicker-eddies", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A completed dare gives Wicker one true detail to call back, exaggerate, or challenge later."
        case .illustration where tags.contains("entity"):
            if let entityID = tags.first(where: { $0.hasPrefix("entity:") })?.replacingOccurrences(of: "entity:", with: "") {
                entityDeltas[entityID, default: 0] += 3
            }
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case .mood:
            entityDeltas["body-page", default: 0] += tags.contains("weather") ? 0 : 1
            threadDeltas["body-learns-trust", default: 0] += 1
        case .diary:
            entityDeltas["the-book", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A present-tense diary note can become quiet continuity."
        case .askTheBook:
            entityDeltas["the-book", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
        case .inkrestOfficeHours:
            entityDeltas["dr-inkrest", default: 0] += 3
            threadDeltas["inkrest-difficult-pages", default: 0] += 2
            relationshipDeltas["inkrest-holds-difficult-pages", default: 0] += 2
            createdHint = "A kept Office Hours sitting can return as a reframe, an experiment, or a question for real therapy."
        case .faeBargain:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["outer-stacks", default: 0] += 2
            createdHint = "A paid bargain deepens the reader's standing with the Fae and may open stranger bargains later."
        case .pactDispatch:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A kept dispatch marks a turn in the Talismans' long war over the reader's margins."
        case .pactVerdict:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A ruled reading binds the reader's own verdict into the Talismans' war — the philosophy they chose to read the day by gains ground."
        case .pactErrand:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A delivered errand pays a Talisman in lived attention; the noticing the reader did in the real day becomes the Talisman's ground."
        case .festival:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A kept festival ties the reader's year to the turning Wheel; the season can call it back."
        case .twoReadings:
            // Both characters who argued deepen by being heard.
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty { entityDeltas[entityID, default: 0] += 2 }
            }
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A kept disagreement lets two voices keep arguing across letters and gossip."
        case .castBond:
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty { entityDeltas[entityID, default: 0] += 2 }
            }
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A living relationship milestone can echo as future gossip, letters, or story scenes."
        case .todaysSky:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A kept sky reading ties the reader to the turning overhead; the next phase or shower can call it back."
        case .radio:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["music-as-shelter", default: 0] += 3
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A kept radio page can make the active station tint future pages, letters, and weather in the stacks."
        case .bookJump:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            threadDeltas["book-jumping", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 2
            if tags.contains("book-jump:return") {
                createdHint = "A returned Book Jump can echo later as a borrowed rule, a character letter, or a constellation with the source book."
            } else {
                createdHint = "An open Book Jump can call back until the reader finds the Spine."
            }
        case .inventory:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "An invoked or bound object can alter which Pages return and what the Book remembers."
        case .gamePage:
            entityDeltas["the-book", default: 0] += 2
            entityDeltas["penny-blackletter", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "A kept Game Page can return as a noticed word, a revised grey phrase, or a playable callback."
            if tags.contains("nothing-influenced") {
                entityDeltas["the-book", default: 0] += 1
                threadDeltas["ordinary-magic", default: 0] += 1
                createdHint = "A Nothing-touched run can invite a future Book Notices page to revise one vague word into a concrete detail."
            }
            if tags.contains("grey-rescued") {
                entityDeltas["the-book", default: 0] += 1
                threadDeltas["ordinary-magic", default: 0] += 1
                createdHint = "A grey word the run restored can resurface later, re-enchanted, inside a future page."
            }
        case .wordNegotiation:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A ruled word enters the reader's Lexicon and can bend future sentences."
        case .location, .lore, .patreon, .quotes, .affirmations, .bookOfYou, .packPage, .calendar, .helpTips, .welcome, .bindery, .plainPage, .tarot:
            break
        }

        if tags.contains("music") {
            threadDeltas["music-as-shelter", default: 0] += 2
        }
        if tags.contains("weather") {
            entityDeltas["weather-page", default: 0] += 1
            threadDeltas["weather-in-the-stacks", default: 0] += 1
        }
        if tags.contains("body") || tags.contains("rest") || tags.contains("care") {
            entityDeltas["body-page", default: 0] += 1
            threadDeltas["body-learns-trust", default: 0] += 1
        }
        if tags.contains("story-mechanic") {
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        }
        if tags.contains("story-mechanic:compass-run") || (tags.contains("story-mechanic") && tags.contains("compass-run")) {
            threadDeltas["ordinary-magic", default: 0] += 2
        }
        if tags.contains("story-mechanic:enchantment") || (tags.contains("story-mechanic") && tags.contains("enchantment")) {
            entityDeltas["the-book", default: 0] += 1
            createdHint = createdHint ?? "A completed Enchantment can become future evidence."
        }

        return NarrativeEventEffect(
            beliefDelta: 1,
            entityWeightDeltas: entityDeltas,
            threadWeightDeltas: threadDeltas,
            relationshipWeightDeltas: relationshipDeltas,
            createdEntityHint: createdHint
        )
    }

    private static func effect(forStoryChoice choice: StoryChoiceSelection, page: BookPage) -> NarrativeEventEffect {
        var entityDeltas: [String: Int] = ["the-book": 1]
        var threadDeltas: [String: Int] = ["ordinary-magic": 1]
        var relationshipDeltas: [String: Int] = ["book-authors-reader": 1]
        var createdHint: String?

        switch choice.id {
        case "sliceoflife":
            entityDeltas["the-book", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case "progressarc":
            threadDeltas["ordinary-magic", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case "surprise":
            entityDeltas["penny-blackletter", default: 0] += 1
            threadDeltas["margin-glass-letters", default: 0] += 1
            createdHint = "A surprising but related detail can become a future motif."
        default:
            break
        }

        let tags = normalizedTags(for: page)
        if tags.contains("music") {
            threadDeltas["music-as-shelter", default: 0] += 1
        }
        if tags.contains("weather") {
            entityDeltas["weather-page", default: 0] += 1
            threadDeltas["weather-in-the-stacks", default: 0] += 1
        }
        if tags.contains("body") || tags.contains("rest") || tags.contains("care") {
            entityDeltas["body-page", default: 0] += 1
            threadDeltas["body-learns-trust", default: 0] += 1
        }
        if tags.contains("letters") || tags.contains("research") {
            threadDeltas["margin-glass-letters", default: 0] += 1
            relationshipDeltas["gwendolyn-files-letters", default: 0] += 1
        }
        if tags.contains("story-mechanic") {
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        }
        if tags.contains("story-mechanic:compass-run") || (tags.contains("story-mechanic") && tags.contains("compass-run")) {
            threadDeltas["ordinary-magic", default: 0] += 2
        }
        if tags.contains("story-mechanic:enchantment") || (tags.contains("story-mechanic") && tags.contains("enchantment")) {
            entityDeltas["the-book", default: 0] += 1
            createdHint = createdHint ?? "A completed Enchantment can become future evidence."
        }

        return NarrativeEventEffect(
            beliefDelta: 1,
            entityWeightDeltas: entityDeltas,
            threadWeightDeltas: threadDeltas,
            relationshipWeightDeltas: relationshipDeltas,
            createdEntityHint: createdHint
        )
    }

    private static func relationshipDeltas(for choice: StorySceneChoice, packet: StoryScenePacket) -> [String: Int] {
        var deltas: [String: Int] = [:]
        let targets = Set(choice.targetEntityIDs + choice.targetThreadIDs)
        for relationship in packet.selectedRelationships where targets.contains(relationship.sourceEntityID) || targets.contains(relationship.targetEntityID) {
            deltas[relationship.id, default: 0] += 1
        }
        if deltas.isEmpty, let first = packet.selectedRelationships.first {
            deltas[first.id] = 1
        }
        return deltas
    }

    private static func summary(for page: BookPage, effect: NarrativeEventEffect) -> String {
        // Story pages carry what actually happened — keep that in the event
        // summary so entity memories can recall the scene itself, not just
        // "a page was kept."
        if page.type == .narrativeOS {
            let sceneText = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sceneText.isEmpty {
                return clippedSummary(sceneText, maxLength: 220)
            }
        }
        let pageName = page.type.title
        let threadNames = effect.threadWeightDeltas.keys.sorted().joined(separator: ", ")
        guard !threadNames.isEmpty else {
            return "\(pageName) became a kept artifact in the Book."
        }
        return "\(pageName) became a kept artifact and tugged \(threadNames)."
    }
}

struct NarrativeSourceSnapshot: Equatable {
    var activeThreadCount: Int
    var relationshipCount: Int
    var beliefWeight: Int?
    var recentEventCount: Int = 0
    var recentTags: [String] = []
    var weightedEntityIDs: [String] = []
    var weightedThreadIDs: [String] = []
    var weightedRelationshipIDs: [String] = []
    var recentlySpotlitEntityIDs: [String] = []
    var recentlySpotlitThreadIDs: [String] = []
    var entityMemories: [NarrativeEntityMemory] = []

    var isAvailable: Bool {
        activeThreadCount > 0
            || relationshipCount > 0
            || beliefWeight != nil
            || recentEventCount > 0
            || !recentTags.isEmpty
            || !weightedEntityIDs.isEmpty
            || !weightedThreadIDs.isEmpty
            || !weightedRelationshipIDs.isEmpty
            || !recentlySpotlitEntityIDs.isEmpty
            || !recentlySpotlitThreadIDs.isEmpty
            || !entityMemories.isEmpty
    }
}

enum NarrativeSourceSnapshotBuilder {
    static func snapshot(
        from events: [NarrativeEvent],
        memories: [NarrativeEntityMemory] = [],
        beliefWeight: Int?
    ) -> NarrativeSourceSnapshot {
        let recentEvents = Array(events.prefix(24))
        let projection = NarrativeStoryFieldProjector.projection(events: recentEvents, baseBelief: beliefWeight ?? 30)
        let entityIDs = projection.topEntityIDs
        let threadIDs = projection.topThreadIDs
        let relationshipIDs = projection.topRelationshipIDs
        let tags = Array(Set(recentEvents.flatMap(\.tags))).sorted()
        let spotlitStoryEvents = recentEvents
            .filter { event in
                event.sourcePageType == .narrativeOS
                    && (event.kind == .pageKept || event.kind == .pageAnswered)
            }
            .prefix(6)
        let recentlySpotlitEntityIDs = orderedSpotlightIDs(
            in: spotlitStoryEvents,
            prefix: "entity:"
        )
        let recentlySpotlitThreadIDs = orderedSpotlightIDs(
            in: spotlitStoryEvents,
            prefix: "thread:"
        )
        let selectedMemories = memories
            .filter { entityIDs.contains($0.entityID) }
            .sorted { left, right in
                if left.narrativeWeight == right.narrativeWeight {
                    return left.createdAt > right.createdAt
                }
                return left.narrativeWeight > right.narrativeWeight
            }
            .prefix(12)
            .map(\.self)

        return NarrativeSourceSnapshot(
            activeThreadCount: threadIDs.count,
            relationshipCount: relationshipIDs.count,
            beliefWeight: projection.belief,
            recentEventCount: recentEvents.count,
            recentTags: tags,
            weightedEntityIDs: entityIDs,
            weightedThreadIDs: threadIDs,
            weightedRelationshipIDs: relationshipIDs,
            recentlySpotlitEntityIDs: recentlySpotlitEntityIDs,
            recentlySpotlitThreadIDs: recentlySpotlitThreadIDs,
            entityMemories: selectedMemories
        )
    }

    private static func orderedSpotlightIDs<S: Sequence>(
        in events: S,
        prefix: String
    ) -> [String] where S.Element == NarrativeEvent {
        var result: [String] = []
        var seen = Set<String>()
        for event in events {
            for tag in event.tags {
                let normalized = tag.lowercased()
                guard normalized.hasPrefix(prefix) else { continue }
                let id = String(normalized.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty, !seen.contains(id) else { continue }
                seen.insert(id)
                result.append(id)
            }
        }
        return result
    }
}

/// Merges near-duplicate memories per entity so two weeks of "you mentioned
/// the harbor" becomes one strong memory instead of six weak ones crowding
/// the recall cap. Pure; applied to the in-memory list at load, never to
/// the stored archive.
enum NarrativeEntityMemoryConsolidator {
    static func consolidate(_ memories: [NarrativeEntityMemory], weightCap: Int = 12) -> [NarrativeEntityMemory] {
        var byKey: [String: NarrativeEntityMemory] = [:]
        var order: [String] = []
        for memory in memories.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = "\(memory.entityID)|\(signature(of: memory.summary))"
            if var existing = byKey[key] {
                existing.narrativeWeight = min(weightCap, existing.narrativeWeight + max(1, memory.narrativeWeight / 2))
                existing.summary = memory.summary
                existing.createdAt = memory.createdAt
                byKey[key] = existing
            } else {
                byKey[key] = memory
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }.sorted { $0.createdAt > $1.createdAt }
    }

    private static func signature(of summary: String) -> String {
        let stopWords: Set<String> = [
            "the", "and", "that", "this", "with", "from", "through", "remembers",
            "remember", "reader", "gave", "took", "page", "kept", "their", "your",
            "about", "into", "again", "menu", "glow", "belief"
        ]
        let words = summary
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count > 3 && !stopWords.contains($0) }
        return Array(Set(words)).sorted().prefix(6).joined(separator: "-")
    }
}

// MARK: - The Rut of Routine
//
// The Labyrinth's antagonist: not a monster but a tide — apathy, the Rut,
// the grey that can take texture out of ordinary life. Doctrine, in order:
// 1. Under distress it does not exist. The Book is kind before it is interesting.
// 2. It never guilts and never punishes. It makes STORY, not shame.
// 3. App silence is not evidence. The grey rises only from reader-reported Rut
//    evidence or authored world events, never from days without a keep.
// 4. It is never defeated, only understood — and held back by lived attention.
enum NothingTide {
    struct RutAssessment: Equatable {
        /// 0 is kindness under distress; ordinary life otherwise begins at 1.
        var pressure: Int
        /// Naming the Rut aloud requires more than the Book's standing prior.
        var mayNameRut: Bool
        var evidence: [String]
    }

    /// The curator assumes Routine is ordinary weather, not a failure that
    /// begins only after the reader stops using the app. Baseline pressure
    /// silently favors perspective-changing Pages. The Book may name the Rut
    /// only when the reader has explicitly reported it or taught the Book one
    /// of their own Rut signals. Days without app activity never corroborate it.
    static func rutAssessment(
        inputs: BookSourceInputs,
        distressActive: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RutAssessment {
        guard !distressActive else {
            return RutAssessment(pressure: 0, mayNameRut: false, evidence: ["distress-silence"])
        }

        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let depth = usableFacts
            .filter { $0.questionID == "rut-depth" && now.timeIntervalSince($0.updatedAt) <= 30 * 86_400 }
            .max(by: { $0.updatedAt < $1.updatedAt })
        let depthAnswer = depth?.answer.lowercased() ?? ""
        let reportedPressure: Int
        if depthAnswer.contains("8-10")
            || depthAnswer.contains("11-12")
            || depthAnswer.contains("whirlpool")
            || depthAnswer.contains("deep water") {
            reportedPressure = 3
        } else if depthAnswer.contains("4-7") || depthAnswer.contains("in the rut") {
            reportedPressure = 2
        } else {
            reportedPressure = depth == nil ? 0 : 1
        }

        let recognizedRut = usableFacts.contains {
            $0.questionID == "rut-signal" || $0.questionID == "rut-season"
        }

        var evidence = ["ordinary-life-prior"]
        if depth != nil { evidence.append("current-reader-rut-report") }
        if recognizedRut { evidence.append("reader-recognized-rut-signal") }

        return RutAssessment(
            pressure: max(1, max(reportedPressure, recognizedRut ? 2 : 0)),
            mayNameRut: reportedPressure >= 2 || recognizedRut,
            evidence: evidence
        )
    }

    /// 0 = quiet, 1 = at the edges, 2 = in the margins, 3 = at the desk.
    /// `readerRutPressure` must come from explicit reader evidence. Authored
    /// world-state shifts can still bend the fictional weather.
    static func greyLevel(
        readerRutPressure: Int,
        narrativeHeat: Int,
        distressActive: Bool,
        celebrationGreyShift: Int = 0
    ) -> Int {
        if distressActive {
            return 0
        }
        var level = max(0, min(3, readerRutPressure))
        // A hot story field pushes the grey back a step.
        if narrativeHeat >= 6, level > 0 {
            level -= 1
        }
        // The Almanac bends Routine: light feasts (full moon, Litha) push it
        // back; thinning-veil nights (Samhain, new moon) let it nearer.
        level += celebrationGreyShift
        return max(0, min(3, level))
    }

    /// Compatibility entry point for callers that still need absence for a
    /// warm return greeting or resurfacing cadence. The value is deliberately
    /// ignored here: time away from the app cannot raise the grey.
    static func greyLevel(
        quietDays _: Int,
        narrativeHeat: Int,
        distressActive: Bool,
        celebrationGreyShift: Int = 0
    ) -> Int {
        greyLevel(
            readerRutPressure: 0,
            narrativeHeat: narrativeHeat,
            distressActive: distressActive,
            celebrationGreyShift: celebrationGreyShift
        )
    }

    /// Consecutive days before today with no kept pages. This may tailor a
    /// welcoming return or an archive resurfacing, but must never drive Rut,
    /// loss, world decay, or a penalty.
    static func quietDays(in days: [BookDay], today todayID: String, calendar: Calendar = .current, now: Date = Date()) -> Int {
        var quiet = 0
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { break }
            let dayID = BookDay.id(for: calendar.startOfDay(for: date), calendar: calendar)
            if let day = days.first(where: { $0.id == dayID }), !day.capturedPages.isEmpty {
                break
            }
            quiet += 1
        }
        return quiet
    }

    /// The story-page directive when the grey is up.
    static func storySignal(forGreyLevel level: Int) -> String? {
        switch level {
        case 2:
            return "The Rut of Routine has been at the edges of these margins: somewhere in the scene, one ordinary detail has gone faintly grey and silent. Let a character notice it and quietly resist — by naming it precisely, out loud. The Rut of Routine is never fought and never defeated; it is noticed back."
        case 3:
            return "The Rut of Routine has reached the desk: in this scene, something small has already been erased — a name, a label, a familiar object's color — and the cast can feel the gap. Let them work around the missing thing with care, and let one character say what the cure is without preaching: attention. Keep it gentle; the grey is weather, not war."
        default:
            return nil
        }
    }

    /// The line the Book says when a page is kept while the grey is up.
    static func returnLine(forGreyLevel level: Int) -> String? {
        switch level {
        case 1:
            return "Something grey at the edge of the desk loses interest and withdraws. The page holds."
        case 2, 3:
            return "The grey had settled into the margins; this page pushes it back a full shelf. The Book breathes easier."
        default:
            return nil
        }
    }
}

// MARK: - The Margins Atlas
//
// Graph pages: The Loom (relationships between the cast) and The
// Constellation (where Belief lives and where the reader's attention has
// flowed). Layout is deterministic — the same world draws the same map.

struct GraphNode: Identifiable, Equatable {
    var id: String
    var label: String
    var weight: Double        // node size driver: belief / narrative weight
    var chapterID: String?    // colors the node
    var kindLabel: String
}

struct GraphEdge: Identifiable, Equatable {
    var id: String
    var sourceID: String
    var targetID: String
    var strength: Double      // 0...1, thickness
    var warmth: Double        // -1 (tension) ... +1 (warm) — colors the thread
    var label: String
}

struct NarrativeGraphData: Equatable {
    var nodes: [GraphNode]
    var edges: [GraphEdge]

    static let empty = NarrativeGraphData(nodes: [], edges: [])

    /// Order-independent key for a pair of entities.
    static func relationshipPairKey(_ a: String, _ b: String) -> String {
        "\(min(a, b))|\(max(a, b))"
    }

    /// The Loom: cast and the living threads between them. Authored base edges are
    /// layered with the dynamic `relationshipField` — accumulated warmth, tension,
    /// and familiarity that grow from what actually happens in the reader's Book
    /// (shared story scenes and gossip warm a pair; siding in a disagreement
    /// tenses it; co-occurrence makes strangers familiar). New threads emerge as
    /// pairs interact, so the web is a simulation, not a fixed diagram.
    static func loom(
        entities: [NarrativeWorldEntity],
        relationships: [NarrativeRelationshipEdge],
        threads: [NarrativeStoryThread] = [],
        beliefOffsets: [String: Int],
        relationshipField: [String: RelationshipTie] = [:]
    ) -> NarrativeGraphData {
        var connectedIDs = Set(relationships.flatMap { [$0.sourceEntityID, $0.targetEntityID] })
        // Pull in anyone the field now connects, even with no authored edge.
        for key in relationshipField.keys {
            for id in key.split(separator: "|").map(String.init) { connectedIDs.insert(id) }
        }
        let entityNodes = entities
            .filter { connectedIDs.contains($0.id) }
            .map { entity in
                GraphNode(
                    id: entity.id,
                    label: entity.name,
                    weight: Double(max(6, entity.belief + (beliefOffsets[entity.id] ?? 0))),
                    chapterID: AcademyChapterRegistry.chapter(named: entity.chapter)?.id,
                    kindLabel: entity.kind.rawValue
                )
            }
        let entityNodeIDs = Set(entityNodes.map(\.id))
        let threadNodes = threads
            .filter { !entityNodeIDs.contains($0.id) }
            .map { thread in
                GraphNode(
                    id: thread.id,
                    label: thread.title,
                    weight: Double(max(6, thread.belief + (beliefOffsets[thread.id] ?? 0))),
                    chapterID: nil,
                    kindLabel: "thread"
                )
            }
        let nodes = entityNodes + threadNodes
        let nodeIDs = Set(nodes.map(\.id))
        var edges = relationships
            .filter { nodeIDs.contains($0.sourceEntityID) && nodeIDs.contains($0.targetEntityID) }
            .map { edge -> GraphEdge in
                let tie = relationshipField[relationshipPairKey(edge.sourceEntityID, edge.targetEntityID)] ?? .zero
                let tone = Double(edge.warmth + edge.trust + tie.warmth - edge.tension - tie.tension)
                return GraphEdge(
                    id: edge.id,
                    sourceID: edge.sourceEntityID,
                    targetID: edge.targetEntityID,
                    strength: min(1, max(0.15, Double(edge.narrativeWeight + tie.familiarity + tie.tension) / 30)),
                    warmth: min(1, max(-1, tone / 30)),
                    label: tie.tension > tie.warmth && tie.tension > 0 ? "disputed" : edge.kind.rawValue
                )
            }

        // Threads that emerged purely from the field, between pairs the authored
        // graph never connected.
        let existingPairs = Set(relationships.map { relationshipPairKey($0.sourceEntityID, $0.targetEntityID) })
        for (pairKey, tie) in relationshipField where !existingPairs.contains(pairKey) {
            guard tie.familiarity >= 2 || tie.tension > 0 || tie.warmth >= 2 else { continue }
            let parts = pairKey.split(separator: "|").map(String.init)
            guard parts.count == 2, nodeIDs.contains(parts[0]), nodeIDs.contains(parts[1]) else { continue }
            let tone = Double(tie.warmth - tie.tension)
            edges.append(GraphEdge(
                id: "field-\(pairKey)",
                sourceID: parts[0],
                targetID: parts[1],
                strength: min(1, max(0.2, Double(tie.familiarity + tie.tension + tie.warmth) / 14)),
                warmth: min(1, max(-1, tone / 10)),
                label: tie.tension > tie.warmth ? "disputed" : "woven"
            ))
        }
        return NarrativeGraphData(nodes: nodes, edges: edges)
    }

    /// The Constellation: Belief as stars, the reader at the center, edges
    /// tracing where their attention has actually flowed (from the event
    /// ledger — investments brighten the thread, attacks darken it).
    static func constellation(
        entities: [NarrativeWorldEntity],
        beliefOffsets: [String: Int],
        events: [NarrativeEvent],
        playerBelief: Int
    ) -> NarrativeGraphData {
        var flows: [String: (moved: Int, tone: Int)] = [:]
        for event in events {
            guard event.kind == .beliefInvested || event.kind == .beliefAttacked else { continue }
            for (entityID, delta) in event.effect.entityWeightDeltas where delta != 0 {
                var flow = flows[entityID] ?? (0, 0)
                flow.moved += abs(delta)
                flow.tone += event.kind == .beliefInvested ? delta : -abs(delta)
                flows[entityID] = flow
            }
        }

        let reader = GraphNode(
            id: "the-reader",
            label: "You",
            weight: Double(max(10, playerBelief)),
            chapterID: nil,
            kindLabel: "reader"
        )
        // Stars: anything with meaningful belief, plus anything you've touched.
        let starEntities = entities.filter { entity in
            let adjusted = entity.belief + (beliefOffsets[entity.id] ?? 0)
            return adjusted >= 18 || flows[entity.id] != nil
        }
        let nodes = [reader] + starEntities.map { entity in
            GraphNode(
                id: entity.id,
                label: entity.name,
                weight: Double(max(6, entity.belief + (beliefOffsets[entity.id] ?? 0))),
                chapterID: AcademyChapterRegistry.chapter(named: entity.chapter)?.id,
                kindLabel: entity.kind.rawValue
            )
        }
        let nodeIDs = Set(nodes.map(\.id))
        let edges = flows.compactMap { entityID, flow -> GraphEdge? in
            guard nodeIDs.contains(entityID) else { return nil }
            return GraphEdge(
                id: "flow-\(entityID)",
                sourceID: "the-reader",
                targetID: entityID,
                strength: min(1, max(0.2, Double(flow.moved) / 12)),
                warmth: min(1, max(-1, Double(flow.tone) / Double(max(1, flow.moved)))),
                label: flow.tone >= 0 ? "belief given" : "belief taken"
            )
        }
        return NarrativeGraphData(nodes: nodes, edges: edges)
    }
}

/// Deterministic Fruchterman-Reingold: seeded initial ring, fixed iteration
/// count, no randomness at draw time. Same data, same map, every open.
enum GraphLayoutEngine {
    static func layout(
        data: NarrativeGraphData,
        width: Double,
        height: Double,
        iterations: Int = 120,
        seed: String = "margins-atlas"
    ) -> [String: CodablePoint] {
        let nodes = data.nodes
        guard !nodes.isEmpty else { return [:] }
        let area = width * height
        let k = (area / Double(nodes.count)).squareRoot() * 0.7

        // Seeded ring start: stable hash decides each node's angle jitter.
        var x: [String: Double] = [:]
        var y: [String: Double] = [:]
        for (index, node) in nodes.enumerated() {
            let jitter = Double(abs("\(seed)-\(node.id)".stableHash % 1000)) / 1000.0
            let angle = (Double(index) + jitter) / Double(nodes.count) * 2 * Double.pi
            let radius = min(width, height) * 0.34 * (0.7 + 0.3 * jitter)
            x[node.id] = width / 2 + radius * cos(angle)
            y[node.id] = height / 2 + radius * sin(angle)
        }

        let adjacency: [(String, String, Double)] = data.edges.map { ($0.sourceID, $0.targetID, $0.strength) }
        var temperature = min(width, height) / 8

        for _ in 0..<iterations {
            var dx: [String: Double] = [:]
            var dy: [String: Double] = [:]
            // Repulsion between every pair.
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let a = nodes[i].id
                    let b = nodes[j].id
                    var deltaX = (x[a] ?? 0) - (x[b] ?? 0)
                    var deltaY = (y[a] ?? 0) - (y[b] ?? 0)
                    var distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
                    if distance < 0.01 {
                        deltaX = 0.01 * (abs("\(a)-\(b)".stableHash % 2) == 0 ? 1 : -1)
                        deltaY = 0.01
                        distance = 0.014
                    }
                    let force = k * k / distance
                    dx[a, default: 0] += deltaX / distance * force
                    dy[a, default: 0] += deltaY / distance * force
                    dx[b, default: 0] -= deltaX / distance * force
                    dy[b, default: 0] -= deltaY / distance * force
                }
            }
            // Attraction along edges, weighted by strength.
            for (source, target, strength) in adjacency {
                let deltaX = (x[source] ?? 0) - (x[target] ?? 0)
                let deltaY = (y[source] ?? 0) - (y[target] ?? 0)
                let distance = max(0.01, (deltaX * deltaX + deltaY * deltaY).squareRoot())
                let force = distance * distance / k * (0.5 + strength)
                dx[source, default: 0] -= deltaX / distance * force
                dy[source, default: 0] -= deltaY / distance * force
                dx[target, default: 0] += deltaX / distance * force
                dy[target, default: 0] += deltaY / distance * force
            }
            // Apply, clamped by cooling temperature and the frame.
            for node in nodes {
                let moveX = dx[node.id] ?? 0
                let moveY = dy[node.id] ?? 0
                let magnitude = max(0.01, (moveX * moveX + moveY * moveY).squareRoot())
                let limited = min(magnitude, temperature)
                x[node.id] = min(width - 40, max(40, (x[node.id] ?? 0) + moveX / magnitude * limited))
                y[node.id] = min(height - 40, max(40, (y[node.id] ?? 0) + moveY / magnitude * limited))
            }
            temperature *= 0.95
        }

        var result: [String: CodablePoint] = [:]
        for node in nodes {
            result[node.id] = CodablePoint(x: x[node.id] ?? width / 2, y: y[node.id] ?? height / 2)
        }
        return result
    }
}

// MARK: - The Two Readings (dynamic character disagreement)
//
// Two members of the cast read the same recent evidence differently and reach
// different conclusions, then leave it to the reader. The pair is chosen
// DYNAMICALLY from the cast — by any tension between them, contrast of Chapter
// and domain, how well each fits the current evidence, Belief weight, and
// rotation — never from a hardcoded table. The disagreement itself emerges from
// each character's own beliefs, faults, and voice in the generated prose.

struct DisagreementPair: Equatable {
    let aID: String
    let bID: String
    let aName: String
    let bName: String
    let relationshipNote: String?
    var pairKey: String { "\(min(aID, bID))-\(max(aID, bID))" }
}

enum DisagreementEngine {
    /// Characters with enough internal shape to actually hold a position.
    static func eligible(from entities: [NarrativeWorldEntity]) -> [NarrativeWorldEntity] {
        entities.filter { $0.kind == .character && (!$0.beliefs.isEmpty || !$0.faults.isEmpty) }
    }

    private static func tension(
        _ a: NarrativeWorldEntity, _ b: NarrativeWorldEntity,
        _ relationships: [NarrativeRelationshipEdge]
    ) -> (value: Int, note: String?) {
        let edge = relationships.first {
            ($0.sourceEntityID == a.id && $0.targetEntityID == b.id) ||
            ($0.sourceEntityID == b.id && $0.targetEntityID == a.id)
        }
        return (edge?.tension ?? 0, edge?.note)
    }

    private static func chapterContrast(_ a: NarrativeWorldEntity, _ b: NarrativeWorldEntity) -> Int {
        switch (a.chapter, b.chapter) {
        case let (ca?, cb?): return ca == cb ? 0 : 3   // named, different Chapters argue hardest
        case (nil, nil): return 1
        default: return 2                               // one aligned, one free
        }
    }

    private static func evidenceFit(_ entity: NarrativeWorldEntity, _ haystack: String) -> Int {
        entity.tags.reduce(0) { $0 + (haystack.contains($1.lowercased()) ? 1 : 0) }
    }

    /// Pick the most interesting disagreeing pair for the current evidence.
    static func select(
        entities: [NarrativeWorldEntity],
        relationships: [NarrativeRelationshipEdge],
        evidenceText: String,
        surfaceHistory: [String: SurfaceHistoryRecord] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DisagreementPair? {
        // Cap the pool to present voices, but roll by weight so the same two
        // highest-Belief characters do not monopolize every reading.
        let pool = Array(StableWeightedRoll.ordered(
            from: eligible(from: entities).sorted { $0.id < $1.id },
            seed: "\(BookDay.id(for: now))-two-readings-pool",
            weight: { $0.belief + $0.narrativeWeight }
        ).prefix(9))
        guard pool.count >= 2 else { return nil }
        let haystack = evidenceText.lowercased()
        let slot = "\(calendar.dateComponents([.year, .month, .day], from: now).day ?? 0)"

        var candidates: [(pair: DisagreementPair, score: Int)] = []
        for i in pool.indices {
            for j in pool.indices where j > i {
                let a = pool[i]
                let b = pool[j]
                let (tensionValue, note) = tension(a, b, relationships)
                let fit = evidenceFit(a, haystack) + evidenceFit(b, haystack)
                let contrast = chapterContrast(a, b)
                let beliefPresence = (a.belief + b.belief) / 30
                let key = "tworeadings:\(min(a.id, b.id))-\(max(a.id, b.id))"
                let seenRecently = surfaceHistory[key]
                    .map { now.timeIntervalSince($0.lastShownAt) < 3 * 86_400 } ?? false
                let jitter = abs("\(a.id)-\(b.id)-\(slot)".stableHash) % 4
                let score = tensionValue / 3 + contrast * 2 + fit * 3 + beliefPresence + jitter - (seenRecently ? 7 : 0)

                candidates.append((
                    DisagreementPair(aID: a.id, bID: b.id, aName: a.name, bName: b.name, relationshipNote: note),
                    score
                ))
            }
        }
        let freshCandidates = candidates.filter { candidate in
            let key = "tworeadings:\(candidate.pair.pairKey)"
            return surfaceHistory[key]
                .map { now.timeIntervalSince($0.lastShownAt) >= 3 * 86_400 } ?? true
        }
        let poolCandidates = freshCandidates.isEmpty ? candidates : freshCandidates
        return StableWeightedRoll.pick(
            from: poolCandidates.sorted { $0.pair.pairKey < $1.pair.pairKey },
            seed: "\(slot)-two-readings-pair-\(haystack.stableHash)",
            weight: { $0.score }
        )?.pair
    }
}
