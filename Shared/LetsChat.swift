import Foundation

// MARK: - Let's Chat
//
// The reader-facing name for what the code still calls AskTheBook. See
// docs/lets-chat-redesign.md for why it was rebuilt.
//
// Three small, deterministic pieces live here, none of which needs the model:
//
// - `LetsChatRouter` reads a message and decides what it is *for*, so a
//   greeting never pays for an archive search and a long history question
//   gets the room it needs.
// - `LetsChatEchoGuard` stops the Book reading the reader's own sentence (or
//   its own last answer) back to them.
// - `LetsChatAction` recognises the few things a reader can ask the Book to
//   *do*. The model never decides to act; the reader confirms every one.

/// What a message to the Book is for.
enum LetsChatIntent: String, Equatable {
    /// "hi", "good evening", "how are you". A greeting can simply be a greeting.
    case greeting
    /// Anything the reader just wants to talk about.
    case smallTalk
    /// A question about the Book itself: its wants, quirks, projects.
    case aboutBook
    /// A question that needs the reader's own history.
    case aboutReader
    /// A question about the Academy, the cast, the Compass, the app.
    case aboutWorld
    /// "remember that…", "keep this".
    case action
}

/// Something the reader asked the Book to do. Always offered back as a chip;
/// nothing here runs on its own.
enum LetsChatAction: Equatable {
    case remember(String)
    case keepChat
}

struct LetsChatRoute: Equatable {
    var intent: LetsChatIntent
    /// Only history questions pay for a search of the whole archive.
    var needsArchive: Bool
    /// How many lore notes the prompt may carry. Zero drops the whole
    /// knowledge packet, which is over a thousand characters of scaffolding.
    var knowledgeLimit: Int
    /// How many earlier exchanges ride along.
    var historyTurns: Int
    /// Replies are conversation, not essays.
    var maxReplyTokens: Int
    var action: LetsChatAction?
    /// "What do you think about me?" The question has no search words in it,
    /// so it gets a spread of the reader's own recent Pages and facts instead.
    var isPortrait: Bool = false

    /// Whether the Book's own state may answer exactly, without the model.
    var mayAnswerFromInterior: Bool { intent == .aboutBook }
}

enum LetsChatRouter {
    static func route(
        _ message: String,
        previousTurns: [AskTheBookTurn] = []
    ) -> LetsChatRoute {
        let text = normalized(message)
        let wordCount = text.split(separator: " ").count

        if let action = action(in: message, normalizedText: text) {
            return LetsChatRoute(
                intent: .action,
                needsArchive: false,
                knowledgeLimit: 0,
                historyTurns: 1,
                maxReplyTokens: 120,
                action: action
            )
        }

        // A short follow-up ("why?", "tell me more", "and then?") belongs to
        // whatever the last exchange was about, including whether that needed
        // the archive. Judged alone it would route as small talk and lose the
        // thread.
        if wordCount <= 4,
           let last = previousTurns.last,
           isFollowUp(text),
           !isGreeting(text, wordCount: wordCount) {
            var inherited = route(last.prompt, previousTurns: [])
            if inherited.intent == .action || inherited.intent == .greeting {
                inherited = route("", previousTurns: [])
            }
            inherited.historyTurns = max(inherited.historyTurns, 3)
            return inherited
        }

        if isGreeting(text, wordCount: wordCount) {
            return LetsChatRoute(
                intent: .greeting,
                needsArchive: false,
                knowledgeLimit: 0,
                historyTurns: 1,
                maxReplyTokens: 90,
                action: nil
            )
        }

        // Order matters. An explicit history cue wins outright; then questions
        // about the Book itself, which are full of "me" and "you" and must not
        // be mistaken for the reader's own life; only then the looser guess
        // that a real first-person question deserves a search.
        // "have i changed" is about the Book's long game, though it opens with
        // a history cue. These few go first.
        let asksAboutTheLongGame = contains(
            any: ["am i changing", "have i changed", "is this changing me", "is this working"],
            in: text
        )
        if asksAboutTheLongGame {
            return LetsChatRoute(
                intent: .aboutBook,
                needsArchive: false,
                knowledgeLimit: 2,
                historyTurns: 3,
                maxReplyTokens: 240,
                action: nil
            )
        }
        if isPortraitRequest(message) {
            var route = aboutReaderRoute
            route.isPortrait = true
            route.maxReplyTokens = 300
            return route
        }
        let hasHistoryCue = contains(any: historyCues, in: text)
        if hasHistoryCue {
            return aboutReaderRoute
        }

        if asksAboutTheBook(text) {
            return LetsChatRoute(
                intent: .aboutBook,
                needsArchive: false,
                knowledgeLimit: 2,
                historyTurns: 3,
                maxReplyTokens: 240,
                action: nil
            )
        }

        if asksAboutReaderHistory(text, wordCount: wordCount, hasQuestionMark: message.contains("?")) {
            return aboutReaderRoute
        }

        if mentionsTheWorld(text) {
            return LetsChatRoute(
                intent: .aboutWorld,
                needsArchive: false,
                knowledgeLimit: 8,
                historyTurns: 3,
                maxReplyTokens: 260,
                action: nil
            )
        }

        return LetsChatRoute(
            intent: .smallTalk,
            needsArchive: false,
            knowledgeLimit: 0,
            historyTurns: 3,
            maxReplyTokens: 200,
            action: nil
        )
    }

    private static let portraitCues: [String] = [
        "think about me", "think of me", "think i am", "think i'm",
        "notice about me", "noticed about me", "learned about me",
        "learn about me", "know about me", "tell me about me",
        "see in me", "who am i", "what am i like", "describe me",
        "do you know me", "how do you see me", "what do you make of me",
        "what's your read on me", "what is your read on me"
    ]

    static func isPortraitRequest(_ message: String) -> Bool {
        contains(any: portraitCues, in: normalized(message))
    }

    private static let aboutReaderRoute = LetsChatRoute(
        intent: .aboutReader,
        needsArchive: true,
        knowledgeLimit: 3,
        historyTurns: 3,
        maxReplyTokens: 280,
        action: nil
    )

    // MARK: Cues

    private static let greetings: [String] = [
        "hi", "hello", "hey", "hiya", "yo", "howdy", "sup", "morning",
        "good morning", "good afternoon", "good evening", "good night",
        "whats up", "what's up", "how are you", "how are you today",
        "hows it going", "how's it going", "how do you do", "hi book",
        "hello book", "hey book"
    ]

    private static let greetingTails: [String] = [
        "how are you", "how are you today", "how are you doing", "hows it going",
        "how's it going", "how are things", "how have you been",
        "how've you been", "whats up", "what's up", "how do you do",
        "how is your day", "how's your day", "book", "there", "again"
    ]

    /// A greeting is only greetings: "hey, good morning. how are you?" is one,
    /// "hey, can you tell me about my week" is not. Strip greetings off the
    /// front, then allow one "how are you" and a name; anything left over is
    /// a real message.
    private static func isGreeting(_ text: String, wordCount: Int) -> Bool {
        guard wordCount <= 10 else { return false }
        var rest = text.replacingOccurrences(of: "'", with: "")
        let leads = greetings
            .map { $0.replacingOccurrences(of: "'", with: "") }
            .sorted { $0.count > $1.count }
        var stripped = false
        var progressed = true
        while progressed, !rest.isEmpty {
            progressed = false
            for lead in leads where rest == lead || rest.hasPrefix(lead + " ") {
                rest = String(rest.dropFirst(lead.count)).trimmingCharacters(in: .whitespaces)
                stripped = true
                progressed = true
                break
            }
        }
        guard stripped else { return false }
        if rest.isEmpty { return true }
        let tails = greetingTails.map { $0.replacingOccurrences(of: "'", with: "") }
        while !rest.isEmpty {
            guard let tail = tails.sorted(by: { $0.count > $1.count })
                .first(where: { rest == $0 || rest.hasPrefix($0 + " ") }) else { return false }
            rest = String(rest.dropFirst(tail.count)).trimmingCharacters(in: .whitespaces)
        }
        return true
    }

    private static let followUpOpeners: [String] = [
        "why", "how", "and", "so", "really", "what about", "tell me more",
        "go on", "more", "which", "where", "when", "who", "then", "ok",
        "okay", "and then", "meaning", "like what", "such as"
    ]

    private static func isFollowUp(_ text: String) -> Bool {
        followUpOpeners.contains { text == $0 || text.hasPrefix($0 + " ") }
    }

    /// Cues that the reader is asking about their own past. Matched as whole
    /// phrases: "did i" must not fire inside "did it".
    private static let historyCues: [String] = [
        "do you remember", "remember when", "did i", "have i", "when did i",
        "where did i", "what did i", "what have i", "what was i", "who did i",
        "how many", "how often", "how long have", "what do you know about me",
        "last time", "first time", "ever told you", "did i tell you",
        "my pages", "my page", "my book", "my logs", "my week", "my month",
        "what happened", "when was the last", "since we", "pattern",
        "over time", "keep happening", "keeps happening", "tend to",
        "how have i", "when am i", "what makes me", "how do i feel",
        "how did i feel", "on rainy days", "on sunny days", "again and again",
        "recurring", "connection between", "remind me what", "remind me when",
        "remind me about", "what do i usually", "do i usually", "do i always",
        "am i always", "i wrote", "i told you", "i said"
    ]

    private static func asksAboutReaderHistory(
        _ text: String,
        wordCount: Int,
        hasQuestionMark: Bool
    ) -> Bool {
        // A real question about the reader's own life is worth a search even
        // without a cue phrase. A short exclamation or remark is not.
        let first = Set(["i", "my", "me", "mine", "myself"])
        let words = Set(text.split(separator: " ").map(String.init))
        return hasQuestionMark && wordCount >= 6 && !words.isDisjoint(with: first)
    }

    /// Questions about the Book's own state. Deliberately about *you*, the
    /// Book: "what do you think about my sister's wedding" is the reader's
    /// subject, not the Book's.
    private static let bookCues: [String] = [
        "your favorite", "your favourite", "your secret", "your secrets",
        "your quirks", "your quirk", "what do you want", "want from me",
        "who are you", "what are you", "are you alive", "how do you feel",
        "what are you thinking", "your long term goal", "your long-term goal",
        "your goal", "your plan", "your agenda", "what do you like",
        "your taste", "your opinion", "what do you believe",
        "your project", "what are you doing", "what are you working on",
        "tell me about yourself", "about yourself", "your pet peeve",
        "your pet peeves", "mad at me", "angry at me", "grudge",
        "our argument", "we disagree", "changed your mind", "have you been wrong",
        "who were you", "how have you changed", "your traditions",
        "changing me", "change me", "is this working", "re-enchanted",
        "why did you speak", "you started this", "are you conflicted"
    ]

    private static func asksAboutTheBook(_ text: String) -> Bool {
        contains(any: bookCues, in: text)
    }

    private static let worldCues: [String] = [
        "academy", "labyrinth", "wonder compass", "compass", "belief",
        "glow", "chapter", "the rut", "the curse", "fae", "wicker",
        "serenity", "thorne", "inkrest", "story page", "enchantment",
        "emberheart", "mossbloom", "tidecrest", "riddlewind", "duskthorn",
        "the cast", "the stacks"
    ]

    private static func mentionsTheWorld(_ text: String) -> Bool {
        if contains(any: worldCues, in: text) { return true }
        let first = Set(text.split(separator: " ").map(String.init))
        for entity in NarrativePackRegistry.entities {
            let name = normalized(entity.name)
            guard name.count >= 4 else { continue }
            if contains(any: [name], in: text) { return true }
            if let given = name.split(separator: " ").first.map(String.init),
               given.count >= 4,
               first.contains(given) {
                return true
            }
        }
        return false
    }

    // MARK: Actions

    private static let rememberLeads: [String] = [
        "remember that", "remember this", "remember:", "please remember",
        "i want you to remember", "i'd like you to remember",
        "i would like you to remember", "dont forget that", "don't forget that",
        "note that", "make a note that"
    ]

    private static let keepPhrases: [String] = [
        "keep this chat", "save this chat", "keep our chat", "save our chat",
        "keep this conversation", "save this conversation",
        "make this a page", "put this on a page", "keep this as a page",
        "keep this"
    ]

    private static func action(in message: String, normalizedText text: String) -> LetsChatAction? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
        for lead in rememberLeads where lower.hasPrefix(lead) {
            let payload = String(trimmed.dropFirst(lead.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " :,-—").union(.whitespacesAndNewlines))
            // "remember that" with nothing after it is not a thing to remember.
            guard payload.split(separator: " ").count >= 2 else { return nil }
            return .remember(payload)
        }
        // Whole-message match only: "keep this in mind while we talk" is not a
        // request to keep a Page.
        let squeezed = text
        if keepPhrases.contains(where: { squeezed == $0 || squeezed == "please " + $0 }) {
            return .keepChat
        }
        return nil
    }

    // MARK: Text helpers

    static func normalized(_ message: String) -> String {
        let lowered = message
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
        var out = ""
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "'" || scalar == "-" {
                out.unicodeScalars.append(scalar)
            } else {
                out.append(" ")
            }
        }
        return out
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    private static func contains(any phrases: [String], in text: String) -> Bool {
        let padded = " \(text) "
        return phrases.contains { phrase in
            let p = normalized(phrase)
            return !p.isEmpty && padded.contains(" \(p) ")
        }
    }
}

// MARK: - Echo guard

/// Keeps the Book from reading a sentence back to whoever just said it.
///
/// A 2B model copies any quotable phrase in its prompt, and the old chat handed
/// it the reader's own words as the "strongest record" and told it to build its
/// first paragraph from them. This is the check on both ends: retrieval drops
/// evidence that is only the reader's current chat, and a finished reply that
/// repeats the reader (or the Book's last answer) is cut back.
enum LetsChatEchoGuard {
    static func words(_ text: String) -> [String] {
        LetsChatRouter.normalized(text).split(separator: " ").map(String.init)
    }

    private static func grams(_ words: [String], size: Int) -> [String] {
        guard size > 0, words.count >= size else { return [] }
        return (0...(words.count - size)).map { words[$0..<($0 + size)].joined(separator: " ") }
    }

    /// Fraction of `text`'s word n-grams that also occur in `source`.
    static func overlap(of text: String, in source: String, size: Int = 4) -> Double {
        let textWords = words(text)
        let sourceWords = words(source)
        let size = min(size, max(1, min(textWords.count, sourceWords.count)))
        let textGrams = grams(textWords, size: size)
        guard !textGrams.isEmpty else { return 0 }
        let sourceGrams = Set(grams(sourceWords, size: size))
        let hits = textGrams.filter(sourceGrams.contains).count
        return Double(hits) / Double(textGrams.count)
    }

    /// True when `reply` is mostly the reader's own message said back.
    static func repeats(reader message: String, in reply: String) -> Bool {
        let readerWords = words(message)
        let replyWords = words(reply)
        guard readerWords.count >= 5, replyWords.count >= 6 else { return false }
        if LetsChatRouter.normalized(reply).contains(LetsChatRouter.normalized(message)) {
            // Quoting the reader inside a longer reply is allowed; a reply that
            // is *only* the quote is not.
            return Double(readerWords.count) / Double(replyWords.count) >= 0.5
        }
        return overlap(of: reply, in: message) >= 0.4
    }

    /// True when `reply` is mostly something the Book already said.
    static func repeats(earlier answers: [String], in reply: String) -> Bool {
        guard words(reply).count >= 8 else { return false }
        return answers.contains { overlap(of: reply, in: $0) >= 0.6 }
    }

    /// Evidence that is nothing but what the reader has said in this chat.
    /// Their own sentence is never news to them.
    static func isEcho(evidenceText: String, ofSession messages: [String]) -> Bool {
        let evidenceWords = words(evidenceText)
        guard !evidenceWords.isEmpty else { return false }
        let sessionWords = messages.flatMap(words)
        guard !sessionWords.isEmpty else { return false }
        if evidenceWords.count < 4 {
            let joined = evidenceWords.joined(separator: " ")
            return messages.contains { LetsChatRouter.normalized($0).contains(joined) }
        }
        let size = 3
        let sessionGrams = Set(messages.flatMap { grams(words($0), size: size) })
        let evidenceGrams = grams(evidenceWords, size: size)
        guard !evidenceGrams.isEmpty else { return false }
        let hits = evidenceGrams.filter(sessionGrams.contains).count
        return Double(hits) / Double(evidenceGrams.count) >= 0.6
    }

    /// Drops sentences that only repeat the reader. If that would leave
    /// nothing, the reply is returned untouched; the caller decides whether
    /// to retry.
    static func removingEcho(from reply: String, reader message: String) -> String {
        let sentences = splitSentences(reply)
        guard sentences.count > 1 else { return reply }
        let kept = sentences.filter { sentence in
            let sentenceWords = words(sentence)
            guard sentenceWords.count >= 5 else { return true }
            return overlap(of: sentence, in: message) < 0.6
        }
        guard !kept.isEmpty, kept.count < sentences.count else { return reply }
        return kept.joined(separator: " ")
    }

    private static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?\n".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }
}

// MARK: - Starters and follow-ups

/// Things the reader can tap instead of typing. The Book offers them; none is
/// generated by the model, so they cost nothing and cannot misfire.
enum LetsChatSuggestions {
    /// What a first-time-in-this-chat reader sees under an empty composer.
    /// Talk first, questions about the Book after; the Book's own opening
    /// prompts (when it spoke first) lead.
    static func starters(initiativePrompts: [String] = [], seed: Int = 0) -> [String] {
        let talk = [
            "I want to tell you about my day",
            "What are you thinking about?",
            "What did I write about most lately?",
            "What do you want from me?",
            "Tell me one of your secrets.",
            "Which Page is your favorite?",
            "What have you changed your mind about?"
        ]
        let rotated = talk.isEmpty ? talk : (0..<talk.count).map { talk[($0 + abs(seed)) % talk.count] }
        var seen = Set<String>()
        return (initiativePrompts + rotated).filter { seen.insert($0).inserted }.prefix(5).map { $0 }
    }

    /// Two taps after a reply. Phrased so the router sends them where they
    /// should go: "Do you remember more" is a history question, "Ask me
    /// something" is the Book's turn to be curious.
    static func followUps(after route: LetsChatRoute, evidence: [AskTheBookEvidence]) -> [String] {
        var chips: [String] = []
        if route.needsArchive, evidence.contains(where: {
            $0.authority == .readerWords || $0.authority == .priorConversation
                || $0.authority == .importedEvidence
        }) {
            chips.append("Do you remember more about that?")
        }
        if route.intent != .greeting {
            chips.append("Ask me something instead.")
        } else {
            chips.append("I want to tell you about my day")
        }
        return chips
    }
}

// MARK: - What the Book says it is doing

/// Real stages of a reply, reported by the code that is actually doing them.
/// The chat shows each as it happens, so a long wait says what it is waiting
/// for instead of showing a spinner.
enum LetsChatStage: Equatable {
    /// The weights are being loaded from storage. The slow one, and only when
    /// the phone had put them away.
    case waking
    /// The model is taking in the prompt before it writes its first word.
    case reading
    /// The first try repeated someone, so it is being written again.
    case retrying
}

enum LetsChatStatusCopy {
    static let starting = "Hm. Let me think."
    static let looking = "I'm going through your Pages."

    /// What it is looking for, in the words it is actually searching with.
    static func lookingLine(for message: String) -> String {
        let terms = StacksQuery.parse(message).terms
            .filter { $0.count >= 3 }
            .prefix(4)
        guard !terms.isEmpty else { return looking }
        return "I'm looking for \(terms.map { "“\($0)”" }.joined(separator: ", "))."
    }

    /// One line per page it opened: what it is, whose it is, when.
    static func leafLine(for evidence: AskTheBookEvidence) -> (title: String, detail: String) {
        (
            shortTitle(evidence.result.title),
            [evidence.authority.readerLabel, evidence.result.dateLabel]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        )
    }

    static let openingThem = "I'm opening them up."

    static func line(for stage: LetsChatStage) -> String {
        switch stage {
        case .waking: return "I'm waking my pencil up. This is the slow part."
        case .reading: return "I'm reading what we said."
        case .retrying: return "That came out like an echo. I'm writing it again."
        }
    }

    /// The receipt left behind once a search finishes. The pages it opened are
    /// listed one by one beneath it (`leafLine`), so this says only how much it
    /// searched and whether anything fit.
    static func searchedLine(records: Int, evidence: [AskTheBookEvidence]) -> String {
        let count = records.formatted()
        switch evidence.count {
        case 0: return "I went through \(count) records. Nothing fit."
        case 1: return "I went through \(count) records. One fit:"
        default: return "I went through \(count) records. \(evidence.count) fit:"
        }
    }

    private static func shortTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 32 else { return trimmed }
        return trimmed.prefix(30).trimmingCharacters(in: .whitespaces) + "…"
    }
}

// MARK: - Personality

/// One real thing on the Book's mind, offered to a reply that may or may not
/// use it. The whole inner life is never handed to a chat about the reader:
/// it made the Book talk only about itself ("tracking this quietness"). This
/// is the other half of the bargain: now and then, one specific thing from it
/// gets in, and the Book is a character rather than a polite surface.
struct LetsChatOnMyMind: Equatable {
    var id: String
    var line: String
}

enum LetsChatPersonality {
    /// Percent chance a reply of this kind carries something from the Book's
    /// own life. A hello is a fair place for it; a request to remember
    /// something, or "what do you think of me", is the reader's moment.
    static func chance(for route: LetsChatRoute) -> Int {
        if route.isPortrait { return 0 }
        switch route.intent {
        case .greeting: return 70
        case .smallTalk: return 35
        case .aboutWorld: return 25
        case .aboutReader: return 12
        case .aboutBook, .action: return 0
        }
    }

    /// Replies that must pass between two appearances. Once is a character;
    /// every time is a tic.
    static let restTurns = 3

    /// What the Book could say, in plain words, from what it actually holds.
    static func candidates(from interior: BookInteriorState) -> [LetsChatOnMyMind] {
        guard interior.isAwake else { return [] }
        var items: [LetsChatOnMyMind] = []
        if let fascination = interior.fascination {
            items.append(.init(
                id: "fascination-\(fascination.id)",
                line: "You keep thinking about \(fascination.subject). \(fascination.line)"
            ))
        }
        if let want = interior.currentWant {
            items.append(.init(id: "want-\(want.id)", line: "There's something you want from them: \(want.line) \(want.why)"))
        }
        if let project = interior.currentProject {
            items.append(.init(
                id: "project-\(project.id)",
                line: "You're looking into ‘\(project.title)’. You want to know: \(project.question)"
            ))
        }
        if let business = interior.runningBusiness {
            items.append(.init(id: "business-\(business.id)", line: business.latestLine))
        }
        if let surprise = interior.recentSurprise {
            items.append(.init(id: "surprise-\(surprise.id)", line: surprise.line))
        }
        if let promise = interior.promise {
            items.append(.init(id: "promise-\(promise.id)", line: promise.line))
        }
        if let tension = interior.currentTension {
            items.append(.init(
                id: "tension-\(tension.id)",
                line: "You're torn: \(tension.firstPole) And: \(tension.secondPole)"
            ))
        }
        if let fault = interior.currentFault {
            items.append(.init(id: "fault-\(fault.id)", line: "You got something wrong and want to say so: \(fault.admission)"))
        }
        return items.filter { !$0.line.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Deterministic for a given message and point in the conversation, so a
    /// retried reply does not change its mind about being chatty.
    static func pick(
        interior: BookInteriorState,
        route: LetsChatRoute,
        message: String,
        turnCount: Int,
        turnsSinceLast: Int?
    ) -> LetsChatOnMyMind? {
        let chance = chance(for: route)
        guard chance > 0 else { return nil }
        if let turnsSinceLast, turnsSinceLast < restTurns { return nil }
        let items = candidates(from: interior)
        guard !items.isEmpty else { return nil }
        let seed = abs(message.stableHash &+ turnCount &* 7_919)
        guard seed % 100 < chance else { return nil }
        return items[(seed / 100) % items.count]
    }
}
