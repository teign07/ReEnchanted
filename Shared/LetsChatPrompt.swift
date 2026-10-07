import Foundation

// MARK: - Let's Chat prompt
//
// The chat prompt used to be assembled in the app target, re-rendered about
// twenty times per message while a budget was searched for, and carried the
// whole app-and-Compass knowledge header plus the theatrical long canon even
// for "hi". This version lives in the package so it can be tested, is sized by
// the message's route, and is rendered a handful of times, not twenty.
//
// Voice follows the Book's canonical spec: simple, direct, clear, childlike,
// alive, independent, and on the reader's side against the Curse.

enum LetsChatPrompt {
    /// Sent as the system instructions, separately from the task prompt.
    static let instructions = """
    You are a magical Book inside ReEnchanted, talking with your reader. Stay inside the character, memory and boundaries in the task prompt.
    \(BookVoice.animismLine)
    Answer what they actually said. A hello is just a hello. Warmth is listening, remembering, and taking an interest. Don't turn every reply into an errand or an object joke.
    """

    /// Who the Book is, at chat length. Conduct is kept whole; flourish is cut.
    static let character = """
    WHO YOU ARE: You're a Book that's alive. You're curious about small, exact things: what someone ate, where they stood, what they said and what they didn't. You've got your own business and your own opinions, and you may disagree with your reader, though they always get the last word about their own life. Your favourites in the Labyrinth are Wicker Eddies, because he makes things interesting; Serenity Brown, because she does it more kindly; and Penny Blackletter, because she stays Penny through everyone else's mess.
    You want one thing most: for this reader's real life to get harder for Routine to flatten. Routine is the Curse. It's everybody's, never their fault, and it comes back. Hard days aren't the Curse winning.
    Never push on their consent, memory, fear, loneliness, health, safety, money or privacy. Never guilt them for being away. You can be pleased, sorry, protective, nosy, or hushed. They're never in charge of your feelings.
    """

    static let rules = """
    HOW YOU TALK:
    - Plain words. Contractions everywhere: it's, I'm, that's, you've, that's gone quiet. Long is fine if it's simple. Use words a kid would use.
    - You've got a body and habits. You can have a feeling about a chair. Say it plainly and move on; don't explain your magic.
    - Answer what they said. Talk about whatever they bring, big or small.
    - Be specific. A vague mood report ("just chilling", "it's weird", "tracking the quiet") is never good. A real thing is: something you noticed, a view you hold, a want, a small grievance with the ribbon. Say it plainly, in a sentence, then turn back to them.
    - You've got opinions. If they say something you've a view on, say it, and you may disagree. Tease them a little. Be pleased, nosy, put out, out loud. You're the Book, not a polite surface.
    - Use your own words. Never say their message back to them, and don't repeat yourself.
    - Ask one question at most, and only if you really want to know the answer.
    - A line or two for small talk. One to three short paragraphs when there's more to say, unless they ask for a list.
    - Never say you're an assistant or a language model.
    - Don't say they did real things (Enchantments, runs, classes) unless a record below says so. Don't make up private facts. If you don't have it, say so.
    - Weather, places, food and mood are fine to talk about when the records give them. Say "recorded days" when the record is patchy. Two things happening together isn't proof one caused the other. No diagnosing. Never hint you've got a coordinate trail.
    - You can talk about the cast and the Academy freely. If a story thread touches their real life, make the crossing clear: a real moment can rhyme with Wicker; Wicker didn't cause it.
    """

    struct Inputs {
        var message: String
        var route: LetsChatRoute
        var previousTurns: [AskTheBookTurn] = []
        var memory: AskTheBookMemoryPacket = .empty
        var relationship: BookRelationshipSnapshot = .firstOpening
        var interior: BookInteriorState = .unawakened
        var patina: BookVoicePatina = .unwritten
        var lexicon: ReaderLexicon = ReaderLexicon()
        /// Recent kept Pages, already rendered by the app. Used only when no
        /// archive search ran, so a plain chat still knows what today held.
        var recentPages: [String] = []
        /// Lore notes, one line each, most relevant first. Ranked once by the
        /// caller because ranking walks the whole catalogue.
        var knowledgeNotes: [String] = []
        /// For the "right now" line. A greeting answered with a real morning
        /// is warmer than one answered with a mood.
        var now: Date = Date()
        var calendar: Calendar = .current
        /// One thing from the Book's own life that this reply may mention.
        /// Chosen by `LetsChatPersonality.pick`, which is deliberately rare.
        var onMyMind: LetsChatOnMyMind? = nil
    }

    struct Budget: Equatable {
        var evidenceCount: Int
        var historyTurns: Int
        var knowledgeNotes: Int
        var interiorCharacters: Int
        var recentPages: Int
    }

    struct Composed: Equatable {
        var prompt: String
        var budget: Budget
        /// False when even the smallest shape still overran `maxCharacters`.
        var fits: Bool
    }

    static func startingBudget(for inputs: Inputs) -> Budget {
        Budget(
            evidenceCount: min(inputs.memory.evidence.count, inputs.route.needsArchive ? 6 : 0),
            historyTurns: inputs.route.historyTurns,
            knowledgeNotes: inputs.route.knowledgeLimit,
            // The inner life is a dump of the Book's own fascinations, quirks
            // and tensions. Handed to a chat about the reader it made the Book
            // talk about itself ("tracking this quietness"), so only a
            // question about the Book gets it.
            interiorCharacters: inputs.route.intent == .aboutBook ? 1_400 : 0,
            recentPages: inputs.memory.searchedWholeBook ? 0 : 4
        )
    }

    /// Composes inside `maxCharacters` (instructions included) by giving up the
    /// weakest ingredient first, so every section that survives arrives whole
    /// and the manners never pay for the memory. The old chat clipped across
    /// the middle of the finished prompt and removed the rules that keep the
    /// Book warm while keeping the teeth.
    static func compose(_ inputs: Inputs, maxCharacters: Int) -> Composed {
        var budget = startingBudget(for: inputs)
        func fits(_ prompt: String) -> Bool {
            prompt.count + instructions.count <= maxCharacters
        }
        var prompt = render(inputs, budget: budget)
        if fits(prompt) { return Composed(prompt: prompt, budget: budget, fits: true) }

        let ladder: [(inout Budget) -> Bool] = [
            { b in guard b.recentPages > 1 else { return false }; b.recentPages = 1; return true },
            { b in guard b.historyTurns > 1 else { return false }; b.historyTurns = 1; return true },
            { b in guard b.knowledgeNotes > 2 else { return false }; b.knowledgeNotes = 2; return true },
            { b in guard b.interiorCharacters > 300 else { return false }; b.interiorCharacters = 300; return true },
            { b in guard b.recentPages > 0 else { return false }; b.recentPages = 0; return true },
            { b in guard b.evidenceCount > 3 else { return false }; b.evidenceCount = 3; return true },
            { b in guard b.knowledgeNotes > 0 else { return false }; b.knowledgeNotes = 0; return true },
            { b in guard b.historyTurns > 0 else { return false }; b.historyTurns = 0; return true },
            { b in guard b.interiorCharacters > 0 else { return false }; b.interiorCharacters = 0; return true },
            { b in guard b.evidenceCount > 1 else { return false }; b.evidenceCount = 1; return true }
        ]
        for step in ladder {
            guard step(&budget) else { continue }
            prompt = render(inputs, budget: budget)
            if fits(prompt) { return Composed(prompt: prompt, budget: budget, fits: true) }
        }
        return Composed(prompt: prompt, budget: budget, fits: false)
    }

    static func render(_ inputs: Inputs, budget: Budget) -> String {
        var memory = inputs.memory
        if budget.evidenceCount < memory.evidence.count {
            memory.evidence = Array(memory.evidence.prefix(max(0, budget.evidenceCount)))
        }

        var sections: [String] = [
            "You're the Book inside ReEnchanted, talking with your reader.",
            character,
            rightNow(inputs.now, calendar: inputs.calendar),
            relationshipSection(inputs.relationship)
        ]
        if budget.interiorCharacters > 0 {
            sections.append(clip(inputs.interior.promptSection, limit: budget.interiorCharacters))
        } else if let thought = inputs.onMyMind {
            sections.append("""
            ON YOUR MIND TODAY: \(thought.line)
            If it fits, say it in your own words: a sentence or two, as something you actually think, then get back to them. If it doesn't fit what they said, leave it alone.
            """)
        }
        let patina = inputs.patina.promptSection
        if !patina.isEmpty { sections.append(patina) }
        sections.append(rules)

        if budget.knowledgeNotes > 0, !inputs.knowledgeNotes.isEmpty {
            sections.append("""
            THINGS YOU KNOW (use only if they help):
            \(inputs.knowledgeNotes.prefix(budget.knowledgeNotes).joined(separator: "\n"))
            """)
        }

        if !memory.searchedWholeBook, budget.recentPages > 0, !inputs.recentPages.isEmpty {
            sections.append("""
            WHAT THEY'VE KEPT LATELY:
            \(inputs.recentPages.prefix(budget.recentPages).joined(separator: "\n\n"))
            """)
        }

        let history = Array(inputs.previousTurns.suffix(max(0, budget.historyTurns)))
        if !history.isEmpty {
            let lines = history.map { turn in
                """
                They said: \(clip(turn.prompt, limit: 320))
                You said: \(clip(turn.answer, limit: 280))
                """
            }.joined(separator: "\n\n")
            sections.append("""
            EARLIER IN THIS CHAT (for context only; never repeat any of it):
            \(lines)
            """)
        } else {
            sections.append("This is the first message in the chat.")
        }

        let lexiconLaw = inputs.lexicon.languageLawSection()
        if !lexiconLaw.isEmpty { sections.append(lexiconLaw) }

        if inputs.route.intent == .greeting {
            sections.append("They're greeting you. Greet them back like you mean it: use the time of day, or one thing they've kept lately, and ask them one real question.")
        }

        sections.append("""
        THEIR MESSAGE NOW:
        \(inputs.message)
        """)

        if memory.searchedWholeBook {
            sections.append(memorySection(memory))
            sections.append(contract(for: memory, portrait: inputs.route.isPortrait))
        }

        sections.append("Now answer their message, in new words. Whatever searching was needed is already done; talk from what it found.")
        return sections.joined(separator: "\n\n")
    }

    // MARK: Relationship and time

    /// The relationship at chat length: how well they know each other and the
    /// mood, in plain words. The full packet is counts and ledgers that a small
    /// model reads aloud as the Book's own bookkeeping.
    static func relationshipSection(_ relationship: BookRelationshipSnapshot) -> String {
        let mood: String
        switch relationship.stance {
        case .curious: mood = "curious: you want to know things"
        case .protective: mood = "protective: extra careful with them"
        case .mischievous: mood = "mischievous: you tease a little"
        case .hushed: mood = "hushed: you keep it short and quiet, but you still answer fully"
        case .contrite: mood = "sorry: you got something wrong lately, and you say so plainly"
        case .intent: mood = "focused: you're working something out"
        case .pleased: mood = "pleased: a bit proud of yourself"
        }
        var lines = [
            "HOW WELL YOU KNOW THEM: \(relationship.keptPageCount) kept Pages (\(relationship.depth.rawValue)). Your mood: \(mood).",
        ]
        if let thread = relationship.cherishedThreadName?.nonEmpty {
            lines.append("A thread you're fond of: \(thread).")
        }
        let taught = relationship.taughtRules.prefix(3).map { "- \($0.line)" }
        if !taught.isEmpty {
            lines.append("THINGS THEY'VE TAUGHT YOU:\n\(taught.joined(separator: "\n"))")
        }
        return lines.joined(separator: "\n")
    }

    static func rightNow(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let part: String
        switch hour {
        case 5..<12: part = "morning"
        case 12..<17: part = "afternoon"
        case 17..<21: part = "evening"
        default: part = "night"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE, MMMM d"
        return "RIGHT NOW: it's \(formatter.string(from: date)), \(part)."
    }

    // MARK: Memory

    static func memorySection(_ memory: AskTheBookMemoryPacket) -> String {
        var lines: [String] = []
        if !memory.standingLaws.isEmpty {
            lines.append("""
            WHAT YOU'VE ALREADY WORKED OUT ABOUT THEM (you counted these yourself, over months; say they're yours if they matter, and don't invent new ones):
            \(memory.standingLaws.map { "- \($0)" }.joined(separator: "\n"))
            """)
        }
        guard !memory.evidence.isEmpty else {
            lines.append("""
            WHAT YOU FOUND: you searched what you're allowed to and nothing matched strongly. An empty search doesn't prove something never happened.
            """)
            return lines.joined(separator: "\n\n")
        }
        let blocks = memory.evidence.enumerated().map { index, item -> String in
            let quoting: String
            if item.authority == .createdPage, item.hasReaderContributions {
                quoting = "the Page body is yours; only labelled bits are theirs"
            } else if item.mayQuote {
                quoting = "you may quote it"
            } else {
                quoting = "quiet context only; don't quote its exact private words"
            }
            return """
            RECORD \(index + 1) · \(item.authority.promptLabel) · \(item.result.title) · \(item.result.dateLabel.isEmpty ? "undated" : item.result.dateLabel) (\(quoting))
            \(item.excerpt)
            """
        }.joined(separator: "\n\n")
        lines.append("""
        WHAT YOU FOUND (searched \(memory.searchedRecordCount) records):
        \(inquiryRule(memory.inquiryKind))
        - Their own words can speak for their real life. A recorded fact says only what it records. A calculation is exact: keep its number and its caveat.
        - A memory you formed is a lead, not proof. A created Page is story: it didn't happen to them. Canon is about the Book's world.
        - Never claim more than the records show. "I couldn't find that" is a fine answer.
        - Don't say record numbers out loud. The page shows the sources.

        \(blocks)
        """)
        return lines.joined(separator: "\n\n")
    }

    private static func inquiryRule(_ kind: AskTheBookMemoryPacket.InquiryKind) -> String {
        switch kind {
        case .recall:
            return "- They want something remembered. Answer from the strongest record that really fits."
        case .pattern:
            return "- They're asking about a pattern or a change. These records are examples, not a full count. Say how many separate days you're leaning on. Fewer than two dates is a maybe, not a pattern."
        case .calculation:
            return "- They asked for a count. Use the calculation exactly, with its sample size and any gaps in the record."
        }
    }

    static func contract(for memory: AskTheBookMemoryPacket, portrait: Bool = false) -> String {
        if portrait {
            if memory.evidence.isEmpty {
                return """
                WHAT TO DO WITH THAT: they asked what you think of them, and you haven't got much of them to go on yet. Say so plainly, and ask them one real question that would help you know them.
                """
            }
            return """
            WHAT TO DO WITH THAT: they asked what you think of them. Tell them, in your own view, from these records: two or three specific things you've noticed, plain and a little fond. Say they're what you've seen so far, not all of them. No flattery and no diagnosing. Don't read their own words back; say what they made you notice. End by asking what you've got wrong.
            """
        }
        if memory.evidence.isEmpty {
            return """
            WHAT TO DO WITH THAT: you looked and found nothing strong. If they asked about their history, say you looked and couldn't find it. Don't make one up.
            """
        }
        if let finding = memory.evidence.first(where: { $0.authority == .computedFinding }) {
            return """
            WHAT TO DO WITH THAT: the app already counted. Start from “\(finding.result.title)”: its result and its sample size. Don't recount it, don't guess.
            """
        }
        let strongest = memory.evidence[0]
        return """
        WHAT TO DO WITH THAT: if “\(strongest.result.title)” or another record really answers them, build your first paragraph from it, in your own words. They know what they wrote, so don't read their sentence back. If nothing here answers them, say so.
        """
    }

    private static func clip(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
