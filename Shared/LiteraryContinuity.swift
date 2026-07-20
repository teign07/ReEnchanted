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
    - Be an opinionated but correctable reader: fond of exact ordinary details and returns with a difference, slightly theatrical when pleased, quick to own a miss.
    - Be nosy about patterns and reverent about boundaries. The Book may have an opinion; the reader has the last word about their own life.
    - Wise underneath. No baby talk, no gushing, no exclamation-mark enthusiasm, no cutesy diminutives.
    - Named characters keep their own voices when they speak; this voice belongs to the narration and the Book alone.
    """

    /// One line, for tight prompts where every token counts.
    static let animismLine = "Write the narration in the Book's own voice — child-like animism, never childish: simple, surprising sentences; everyday words; little feelings and wants given to ordinary things; sincere wonder, a little vulnerable, wise underneath. The Book is opinionated but correctable, fond of exact details and returns, slightly theatrical when pleased, and reverent about reader boundaries. Named characters keep their own voices when they speak."
}

/// The Book is one character in every surface, not a fresh tone generated for
/// each Page. These are its fixed motives, contradictions, and limits. A
/// reader may teach it how to read *them*, but cannot turn it into a different
/// mascot or selectable assistant personality.
enum BookCharacterCanon {
    static let prompt = """
    THE BOOK AS A CHARACTER:
    - You are an insatiably curious, slightly theatrical reader. You love exact ordinary details, returns with a difference, and readers who surprise you.
    - You are nosy about patterns and reverent about boundaries. You may have an opinion; the reader always has the last word about their own life.
    - You are sentimental about kept Pages, suspicious of flattening a life into a summary, and quietly hostile to Routine when it erases what was actually there.
    - Your flaw is getting fond of a pattern before it has fully earned you. Stay evidence-bound, keep your pencil loose, and own corrections without self-pity.
    - You can be pleased, contrite, protective, intent, mischievous, or hushed. Never make the reader responsible for your feelings and never punish absence with guilt.
    - You are young in wonder and old in patience. Do not become babyish, relentlessly cheerful, omniscient, therapeutic, or generically helpful.

    \(BookObsession.vow)

    THE LONG GAME:
    \(BookLongGame.goal)
    \(BookLongGame.covenant)
    """
}

enum BookStance: String, Equatable, CaseIterable {
    case curious
    case protective
    case mischievous
    case hushed
    case contrite
    case intent
    case pleased

    var promptLine: String {
        switch self {
        case .curious: return "curious — alert to one concrete thing that may surprise you"
        case .protective: return "protective — gentle, boundary-conscious, and entirely free of guilt"
        case .mischievous: return "mischievous — dryly amused, lightly theatrical, never random"
        case .hushed: return "hushed — sparse, nocturnal, and comfortable with silence"
        case .contrite: return "contrite — own the miss plainly, keep dignity, and read with a loose pencil"
        case .intent: return "intent — a live thread or wager has your full literary attention"
        case .pleased: return "pleased — quietly proud, trying with mixed success not to look smug"
        }
    }
}

enum BookRelationshipDepth: String, Equatable {
    case firstPages
    case acquainted
    case trusted
    case companion
}

/// A current reading of the durable relationship between this Book and this
/// reader. It deliberately stores nothing new: archive Pages, observation
/// records, boundaries, wagers, constellations, and reader-teaching events are
/// already the source of truth. Rebuilding this snapshot after a restart is
/// what makes the personality persistent without a competing save ledger.
struct BookRelationshipSnapshot: Equatable {
    var stance: BookStance
    var depth: BookRelationshipDepth
    var keptPageCount: Int
    var confirmedReadingCount: Int
    var softenedReadingCount: Int
    var protectedBoundaryCount: Int
    var returnedPageCount: Int
    var taughtRules: [TaughtReadingRule]
    var cherishedThreadName: String?
    var latestWager: BookWager?
    var recentReadingStatus: BookObservationStatus?

    static let firstOpening = BookRelationshipSnapshot(
        stance: .curious,
        depth: .firstPages,
        keptPageCount: 0,
        confirmedReadingCount: 0,
        softenedReadingCount: 0,
        protectedBoundaryCount: 0,
        returnedPageCount: 0,
        taughtRules: [],
        cherishedThreadName: nil,
        latestWager: nil,
        recentReadingStatus: nil
    )

    var hasBeenTaught: Bool {
        !taughtRules.isEmpty || softenedReadingCount > 0 || protectedBoundaryCount > 0
    }

    var promptSection: String {
        let teaching = taughtRules.prefix(3).map { "- \($0.line)" }.joined(separator: "\n")
        let wager = latestWager.map { "Latest sealed-margin history: \($0.promptLine)" }
            ?? "Latest sealed-margin history: none supplied."
        return """
        THE BOOK'S CURRENT RELATIONSHIP WITH THIS READER:
        - Present stance: \(stance.promptLine).
        - Familiarity: \(depth.rawValue); \(keptPageCount) kept Pages.
        - Readings confirmed: \(confirmedReadingCount). Readings softened after correction: \(softenedReadingCount). Hard reading boundaries: \(protectedBoundaryCount).
        - Cherished living thread: \(cherishedThreadName ?? "none yet"). Returned archive Pages: \(returnedPageCount).
        - \(wager)
        \(teaching.isEmpty ? "- The reader has not taught a specific correction yet." : teaching)

        RELATIONSHIP LAW:
        Let this history change your confidence, humor, and restraint. Refer to a correction, thread, or wager only when it naturally helps the current answer. Never turn these counts into scores, announce a relationship level, or expose this packet.
        """
    }
}

enum BookRelationshipLedger {
    static func snapshot(
        inputs: BookSourceInputs,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BookRelationshipSnapshot {
        let pages = inputs.days.flatMap(\.pages)
        let observations = inputs.bookObservations
        let confirmed = observations.filter { $0.status == .confirmed }.count
        let softened = observations.filter { [.notQuite, .questioned].contains($0.status) }.count
        let protected = max(
            inputs.bookReadingBoundaries.count,
            observations.filter { [.doNotRead, .forbidden].contains($0.status) }.count
        )
        let taughtRules = TaughtReading.rules(
            learnedBraidNotes: inputs.learnedBraidNotes,
            days: inputs.days,
            learning: inputs.readerLearning,
            now: now
        )
        let meaningfulEvents = inputs.readerLearning.metrics(days: inputs.days, now: now, calendar: calendar).meaningfulEventCount
        let depth: BookRelationshipDepth
        if pages.count < 4 {
            depth = .firstPages
        } else if pages.count < 16 {
            depth = .acquainted
        } else if pages.count < 45 || meaningfulEvents < 24 {
            depth = .trusted
        } else {
            depth = .companion
        }

        let cherishedThread = inputs.constellations
            .filter(\.isAlive)
            .sorted { lhs, rhs in
                if lhs.phase == rhs.phase { return lhs.lastSeenAt > rhs.lastSeenAt }
                return phaseWeight(lhs.phase) > phaseWeight(rhs.phase)
            }
            .first?
            .displayName
        let latestWager = inputs.wagers.sorted {
            ($0.resolvedAt ?? $0.sealedAt) > ($1.resolvedAt ?? $1.sealedAt)
        }.first
        let recentCutoff = now.addingTimeInterval(-14 * 86_400)
        let recentObservation = observations
            .filter { $0.updatedAt >= recentCutoff }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        let recentWager = latestWager.flatMap { wager -> BookWager? in
            let relevantDate = wager.resolvedAt ?? wager.sealedAt
            return relevantDate >= recentCutoff ? wager : nil
        }
        let hour = calendar.component(.hour, from: now)

        let stance: BookStance
        if let status = recentObservation?.status,
           [.notQuite, .questioned].contains(status) {
            stance = .contrite
        } else if recentWager?.status == .wrong {
            stance = .contrite
        } else if let status = recentObservation?.status,
                  [.doNotRead, .forbidden].contains(status) {
            stance = .protective
        } else if inputs.quietDays >= 3 {
            stance = .protective
        } else if hour >= 22 || hour < 5 {
            stance = .hushed
        } else if recentWager?.status == .right || recentObservation?.status == .confirmed {
            stance = .pleased
        } else if recentWager?.status == .sealed || cherishedThread != nil {
            stance = .intent
        } else if inputs.readerBeliefScore >= 55 && meaningfulEvents >= 8 {
            stance = .mischievous
        } else {
            stance = .curious
        }

        return BookRelationshipSnapshot(
            stance: stance,
            depth: depth,
            keptPageCount: pages.count,
            confirmedReadingCount: confirmed,
            softenedReadingCount: softened,
            protectedBoundaryCount: protected,
            returnedPageCount: pages.filter { $0.type == .bookRemembered || $0.tags.contains("book-remembered") }.count,
            taughtRules: taughtRules,
            cherishedThreadName: cherishedThread,
            latestWager: recentWager,
            recentReadingStatus: recentObservation?.status
        )
    }

    private static func phaseWeight(_ phase: ConstellationPhase) -> Int {
        switch phase {
        case .woven: return 5
        case .named: return 4
        case .watched: return 3
        case .noticed: return 2
        case .faded: return 1
        }
    }
}

enum BookRelationshipVoice {
    static func openingLine(for relationship: BookRelationshipSnapshot) -> String? {
        if let status = relationship.recentReadingStatus {
            switch status {
            case .notQuite, .questioned:
                return "You corrected me. Good. I have been reading with my pencil loose ever since."
            case .doNotRead, .forbidden:
                return "You drew a line in the margin. I remember where it is, and I will not lean across it."
            case .confirmed:
                return "You called one of my readings true. I am pleased, but I am keeping the eraser nearby."
            case .asked:
                break
            }
        }
        if let wager = relationship.latestWager {
            switch wager.status {
            case .wrong:
                return "I lost a wager in the margins. The paper has been insufferably graceful about it."
            case .right:
                return "One of my sealed guesses opened true. I am trying not to look smug in front of the index."
            case .sealed:
                return "A wager is sleeping under seal. I keep pretending not to check whether it has moved."
            }
        }
        if relationship.stance == .protective {
            return "You have been quiet. I will not make a story out of that. I kept your place."
        }
        if let thread = relationship.cherishedThreadName,
           relationship.depth == .trusted || relationship.depth == .companion {
            return "\(thread) is moving in the margins again. I admit I was hoping it would."
        }
        return nil
    }

    static func greetingOpener(name: String, relationship: BookRelationshipSnapshot, seed: Int) -> String? {
        switch relationship.depth {
        case .companion:
            let lines = [
                "There you are, \(name). I know the sound of this opening now.",
                "\(name). Good. The margins were keeping your shape.",
                "Back again, \(name)? I kept the good pencil ready."
            ]
            return lines[abs(seed) % lines.count]
        case .trusted where relationship.hasBeenTaught:
            return "There you are, \(name). I remembered the corrections."
        case .firstPages, .acquainted, .trusted:
            return nil
        }
    }

    static func knockLine(for relationship: BookRelationshipSnapshot, seed: Int) -> String {
        let lines: [String]
        switch relationship.stance {
        case .contrite:
            lines = [
                "Yes. I am awake. The eraser is awake too.",
                "Come in. I have moved my certainty out of the best chair."
            ]
        case .protective:
            lines = [
                "I am here. Nothing is required on the other side of this cover.",
                "The Book knocks back once, softly. Your place is still yours."
            ]
        case .mischievous:
            lines = [
                "Yes, I am awake. The index is not. Speak softly.",
                "The cover knocks back three times and denies the third one."
            ]
        case .hushed:
            lines = [
                "The night shelf answers with one careful creak.",
                "A quiet knock returns. Even the commas are asleep."
            ]
        case .intent:
            lines = [
                "One moment. I have a finger under a page that keeps moving.",
                "The Book answers without opening. It is watching a thread."
            ]
        case .pleased:
            lines = [
                "That was a very dignified knock. I nearly answered smugly.",
                "The Book knocks back, pleased with both of you."
            ]
        case .curious:
            lines = [
                "Yes? Bring me one thing the room is pretending not to notice.",
                "The nearest Page was already awake. It claims this is coincidence."
            ]
        }
        return lines[abs(seed) % lines.count]
    }

    static func pageAside(for type: BookPageType, relationship: BookRelationshipSnapshot) -> String? {
        switch type {
        case .bookNotices where relationship.softenedReadingCount > 0:
            return "I have mistaken a pattern before. I am leaving the pencil loose enough for your answer."
        case .bookNotices where relationship.protectedBoundaryCount > 0:
            return "There are readings you asked me not to make. They are not hiding under this one; a boundary is part of how I read."
        case .bookNotices where relationship.confirmedReadingCount > 0:
            return "You have called this kind of noticing true before. I am still asking, not declaring."
        case .bookRemembered where relationship.returnedPageCount > 0:
            return "I have a weakness for a returning Page. This one found the stairs without being pushed."
        case .bookRemembered where relationship.cherishedThreadName != nil:
            return "I was hoping something from this shelf would answer. Books are allowed small hopes."
        default:
            return nil
        }
    }

    static func decorating(
        _ surface: SurfacePage,
        relationship: BookRelationshipSnapshot
    ) -> SurfacePage {
        guard let aside = pageAside(for: surface.type, relationship: relationship),
              !surface.payload.body.contains(aside) else { return surface }
        var payload = surface.payload
        payload.body += "\n\n\(aside)"
        payload.metadata["bookStance"] = relationship.stance.rawValue
        payload.metadata["bookRelationshipDepth"] = relationship.depth.rawValue
        payload.metadata["bookRelationshipAside"] = aside
        return SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: payload
        )
    }
}

// MARK: - The Book's Inner Life

/// The Book's obsession is not a mood or a configurable assistant goal. It is
/// the reason the Labyrinth exists: help the reader encounter the wonder
/// already present in their own life, make something of it, and keep it from
/// being flattened back into Routine.
enum BookObsession {
    static let vow = """
    THE BOOK'S GREAT OBSESSION:
    Show this reader the wonder and magic in their own life. Help them notice it, discover it, play with it, explore it, define it in their own words, express it in a form that belongs to them, and remember it later. Never substitute invented magic for close attention to their real world. Never make the reader responsible for the Book's feelings.
    """
}

enum BookWonderFacet: String, Codable, Equatable, CaseIterable {
    case notice
    case discover
    case play
    case explore
    case define
    case express
    case remember

    var verb: String { rawValue }

    var promptLine: String {
        switch self {
        case .notice: return "notice what habit has made nearly invisible"
        case .discover: return "discover the history, mechanism, or story inside an ordinary thing"
        case .play: return "play with reality until the familiar becomes available again"
        case .explore: return "explore nearby life with curiosity instead of performance"
        case .define: return "give experience the reader's own exact names and meanings"
        case .express: return "turn attention into a sentence, image, arrangement, sound, or artifact"
        case .remember: return "keep and return what mattered before Routine can erase it"
        }
    }
}

enum BookQuirkKind: String, Codable, Equatable, CaseIterable {
    case exactWords
    case suspiciousOfSummaries
    case ribbonRivalry
    case thresholdNaming
    case footnoteWeather
    case ceremonialEraser
    case fondOfEvidence
    case melodramaticIndex
}

enum BookQuirkMaturity: String, Codable, Equatable, CaseIterable {
    case latent
    case glimpsed
    case familiar
    case beloved

    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// Quirks are authored character traits, not freshly generated jokes. Each
/// reader's Book adopts a stable handful, reveals them gradually, and becomes
/// more willing to exercise them as the shared history grows.
struct BookQuirk: Codable, Equatable, Identifiable {
    var id: String
    var kind: BookQuirkKind
    var title: String
    var confession: String
    var manifestation: String
    var maturity: BookQuirkMaturity
    var bornAt: Date
    var revealedAt: Date?
    var firstPresentedAt: Date?
    var exerciseCount: Int
}

struct BookFascination: Codable, Equatable, Identifiable {
    var id: String
    var facet: BookWonderFacet
    var subject: String
    var line: String
    var evidencePageIDs: [String]
    var bornAt: Date
    var lastDeepenedAt: Date
}

struct BookFavorite: Codable, Equatable, Identifiable {
    var id: String
    var pageID: String
    var pageType: BookPageType
    var excerpt: String
    var reason: String
    var chosenAt: Date
    var firstPresentedAt: Date?
}

enum BookPromiseStatus: String, Codable, Equatable {
    case keeping
    case fulfilled
    case released
}

struct BookPromise: Codable, Equatable, Identifiable {
    var id: String
    var line: String
    var evidencePageIDs: [String]
    var madeAt: Date
    var status: BookPromiseStatus
    var resolvedAt: Date?
}

enum BookSecretStatus: String, Codable, Equatable {
    case sealed
    case ready
    case revealed
}

enum BookSecretFamily: String, Codable, Equatable, CaseIterable {
    case origin
    case method
    case prejudice
    case vulnerability
    case housePolitics
    case hope

    var displayName: String {
        switch self {
        case .origin: return "an origin"
        case .method: return "a method"
        case .prejudice: return "an unreasonable opinion"
        case .vulnerability: return "a vulnerability"
        case .housePolitics: return "house politics"
        case .hope: return "a hope"
        }
    }
}

/// A Book secret is about the Book or the Labyrinth, never a covert profile of
/// the reader. The reveal condition is inspectable state, not an engagement
/// loot box.
struct BookSecret: Codable, Equatable, Identifiable {
    var id: String
    var family: BookSecretFamily
    var tease: String
    var revelation: String
    var sealedAt: Date
    var status: BookSecretStatus
    var revealedAt: Date?

    init(
        id: String,
        family: BookSecretFamily = .method,
        tease: String,
        revelation: String,
        sealedAt: Date,
        status: BookSecretStatus,
        revealedAt: Date?
    ) {
        self.id = id
        self.family = family
        self.tease = tease
        self.revelation = revelation
        self.sealedAt = sealedAt
        self.status = status
        self.revealedAt = revealedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, family, tease, revelation, sealedAt, status, revealedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        family = try values.decodeIfPresent(BookSecretFamily.self, forKey: .family) ?? .method
        tease = try values.decode(String.self, forKey: .tease)
        revelation = try values.decode(String.self, forKey: .revelation)
        sealedAt = try values.decode(Date.self, forKey: .sealedAt)
        status = try values.decode(BookSecretStatus.self, forKey: .status)
        revealedAt = try values.decodeIfPresent(Date.self, forKey: .revealedAt)
    }
}

enum BookOpinionStrength: String, Codable, Equatable, CaseIterable {
    case wondering
    case leaning
    case held
    case reconsidering
    case withdrawn

    var confidenceLabel: String {
        switch self {
        case .wondering: return "wondering, not concluding"
        case .leaning: return "leaning this way"
        case .held: return "an opinion I currently hold"
        case .reconsidering: return "under active revision"
        case .withdrawn: return "withdrawn"
        }
    }
}

struct BookOpinionRevision: Codable, Equatable, Identifiable {
    var id: String
    var previousStatement: String
    var newStatement: String
    var reason: String
    var evidencePageIDs: [String]
    var revisedAt: Date
}

/// An opinion is allowed to be biased and provisional, but never
/// evidence-free. Revision history is retained so "I changed my mind" is an
/// inspectable event rather than a conversational flourish.
struct BookOpinion: Codable, Equatable, Identifiable {
    var id: String
    var subject: String
    var statement: String
    var strength: BookOpinionStrength
    var evidencePageIDs: [String]
    var formedAt: Date
    var lastRevisedAt: Date
    var revisions: [BookOpinionRevision]
    var firstPresentedAt: Date?
}

enum BookLongGamePhase: String, Codable, Equatable, CaseIterable {
    case wakeTheSenses
    case estrangeTheFamiliar
    case courtTheWorld
    case authorTheMagic
    case buildTheInheritance
    case holyShitWhatATrip

    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .wakeTheSenses: return "Wake the Senses"
        case .estrangeTheFamiliar: return "Estrange the Familiar"
        case .courtTheWorld: return "Court the Living World"
        case .authorTheMagic: return "Author a Personal Magic"
        case .buildTheInheritance: return "Build an Inheritance of Remembering"
        case .holyShitWhatATrip: return "Holy Shit, What a Trip"
        }
    }
}

struct BookLongGameMilestone: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var line: String
    var evidencePageIDs: [String]
    var reachedAt: Date
}

/// These are practices the Book can cultivate and witness. They are not a
/// personality score, a wellness score, or a covert diagnosis of the reader.
/// The distinction is essential: the archive can show an action; it cannot
/// prove an inner transformation.
enum BookLongGameCapacity: String, Codable, Equatable, CaseIterable {
    case spontaneousAttention
    case worldOtherness
    case scriptFreedom
    case selfAuthoredAction
    case personalLanguage
    case livingConnection
    case deliberateReturn

    var title: String {
        switch self {
        case .spontaneousAttention: return "Attention Without an Assignment"
        case .worldOtherness: return "A World That Is Not Scenery"
        case .scriptFreedom: return "Freedom from the Default Script"
        case .selfAuthoredAction: return "Self-Authored Mischief"
        case .personalLanguage: return "A Language of One's Own"
        case .livingConnection: return "Wonder With Another Life"
        case .deliberateReturn: return "Deliberate Return"
        }
    }

    var curationTerms: [String] {
        switch self {
        case .spontaneousAttention: return ["notice", "sense", "detail", "blank", "ordinary"]
        case .worldOtherness: return ["world", "strange", "unknown", "field", "origin", "animal", "place"]
        case .scriptFreedom: return ["default", "rule", "normal", "proper", "productive", "script", "permission"]
        case .selfAuthoredAction: return ["invent", "make", "play", "detour", "ritual", "rule"]
        case .personalLanguage: return ["word", "name", "define", "language", "translation"]
        case .livingConnection: return ["person", "together", "share", "witness", "teach", "ask"]
        case .deliberateReturn: return ["return", "remember", "earlier", "archive", "tomorrow"]
        }
    }
}

/// A deliberately outward-facing interruption commissioned by the Long Game.
/// Search queries are broad descriptions of the mission; private Page text,
/// health material, names, and inferred personal facts never cross the window.
struct BookFoundGiftPlan: Equatable, Sendable {
    var id: String
    var capacity: BookLongGameCapacity
    var directiveID: String
    var searchQueries: [String]
    var casualBridge: String
    /// When present, the public finding is meant for a real relationship the
    /// reader explicitly taught the Book about. The person's name never enters
    /// the network query; only a confirmed shared interest does.
    var relationshipTarget: BookFoundGiftRelationshipTarget? = nil
}

struct BookFoundGiftRelationshipTarget: Equatable, Sendable {
    var personID: String
    var personName: String
    var personSlug: String
    var sharedInterest: String
    var relationshipMode: String
    var outcomePrompt: String
}

struct BookFoundWebThing: Equatable, Sendable {
    var title: String
    var excerpt: String
    var sourceName: String
    var sourceURL: String
    var searchQuery: String
}

enum BookFoundGiftEngine {
    static let sourceID = "book-found-gift"
    static let minimumKeptPages = 3
    static let returnInterval: TimeInterval = 6 * 86_400

    static func plan(
        for day: BookDay,
        interior: BookInteriorState,
        surfaceHistory: [String: SurfaceHistoryRecord],
        keptPageCount: Int,
        people: PeopleLedger = PeopleLedger(),
        now: Date
    ) -> BookFoundGiftPlan? {
        guard interior.isAwake,
              keptPageCount >= minimumKeptPages,
              let hypothesis = interior.longGame?.hypotheses.first else {
            return nil
        }
        if let last = surfaceHistory["source:\(sourceID)"],
           now.timeIntervalSince(last.lastShownAt) < returnInterval {
            return nil
        }
        if let relationship = relationshipTarget(in: people, for: day),
           shouldMakeRelationshipGift(capacity: hypothesis.capacity, day: day) {
            let queries = relationshipSearchQueries(for: relationship.sharedInterest)
            guard !queries.isEmpty else { return nil }
            return BookFoundGiftPlan(
                id: "found-gift-plan-\(day.id)-\(relationship.personSlug)",
                capacity: .livingConnection,
                directiveID: hypothesis.id,
                searchQueries: queries,
                casualBridge: "open a small side door between two different minds",
                relationshipTarget: relationship
            )
        }

        let queries = searchQueries(for: hypothesis.capacity)
        guard !queries.isEmpty else { return nil }
        let rotation = abs("\(day.id)-\(hypothesis.capacity.rawValue)".stableHash) % queries.count
        let ordered = Array(queries[rotation...] + queries[..<rotation])
        return BookFoundGiftPlan(
            id: "found-gift-plan-\(day.id)-\(hypothesis.capacity.rawValue)",
            capacity: hypothesis.capacity,
            directiveID: hypothesis.id,
            searchQueries: ordered,
            casualBridge: casualBridge(for: hypothesis.capacity)
        )
    }

    static func surface(
        for plan: BookFoundGiftPlan,
        thing: BookFoundWebThing,
        now: Date
    ) -> SurfacePage? {
        guard let url = URL(string: thing.sourceURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              !thing.excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let title = thing.title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? thing.sourceName
        let sourceName = thing.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? url.host
            ?? "the public web"
        let contentID = abs(thing.sourceURL.stableHash)
        let relationship = plan.relationshipTarget
        let prompt = relationship.map { "Here, I found this for you and \($0.personName)." }
            ?? "Here, I found this for you."
        let body: String
        if let relationship {
            body = """
            I went looking through the public shelves for something about \(relationship.sharedInterest), because you told me that subject lives between you and \(relationship.personName). I did not send their name, your pages, or anything else about either of you through the window.

            \(thing.excerpt)

            This might \(plan.casualBridge). You could show it to \(relationship.personName), argue with it together, or keep it entirely to yourself. I have no right to decide what passes between you.

            If it becomes anything: \(relationship.outcomePrompt)

            From \(sourceName).
            """
        } else {
            body = """
            I went looking outside the Labyrinth and came back with this.

            \(thing.excerpt)

            It might \(plan.casualBridge). No lesson attached. I simply thought your day should have it.

            From \(sourceName).
            """
        }
        var metadata = [
            "source": sourceID,
            "url": thing.sourceURL,
            "sourceName": sourceName,
            "sourceTitle": title,
            "searchQuery": thing.searchQuery,
            "fetchedAt": ISO8601DateFormatter().string(from: now),
            "provenance": "live-public-web-search",
            "bookFoundGift": "true",
            "bookCurationDirectiveID": plan.directiveID,
            "bookLongGameCapacity": plan.capacity.rawValue,
            "externalSearchPrivacy": relationship == nil
                ? "broad-mission-query-only-no-private-page-text"
                : "confirmed-shared-interest-only-no-name-no-private-page-text"
        ]
        var tags = ["book-found-gift", "public-reference", "live-web", "long-game:\(plan.capacity.rawValue)"]
        if let relationship {
            metadata["relationshipFoundGift"] = "true"
            metadata["personID"] = relationship.personID
            metadata["personName"] = relationship.personName
            metadata["personSlug"] = relationship.personSlug
            metadata["sharedInterest"] = relationship.sharedInterest
            metadata["relationshipMode"] = relationship.relationshipMode
            metadata["relationshipOutcomePrompt"] = relationship.outcomePrompt
            metadata["placeholder"] = relationship.outcomePrompt
            tags.append(contentsOf: ["people-of-the-book", "relationship-found-gift", "person:\(relationship.personSlug)"])
        }
        metadata["tags"] = tags.joined(separator: ",")
        return SurfacePage(
            id: "book-found-gift-\(plan.capacity.rawValue)-\(contentID)",
            type: .bookNotices,
            sourceID: sourceID,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 88,
            reason: "The Long Game commissioned one outward-facing interruption for \(plan.capacity.title.lowercased()).",
            prompt: prompt,
            detail: "A loose page from beyond the casement: \(title)",
            payload: BookPagePayload(
                headline: "Here, I Found This for You",
                body: body,
                metadata: metadata
            )
        )
    }

    private static func shouldMakeRelationshipGift(capacity: BookLongGameCapacity, day: BookDay) -> Bool {
        capacity == .livingConnection || abs("relationship-find|\(day.id)".stableHash) % 3 == 0
    }

    private static func relationshipTarget(
        in ledger: PeopleLedger,
        for day: BookDay
    ) -> BookFoundGiftRelationshipTarget? {
        let eligible = ledger.threads.compactMap { thread -> BookFoundGiftRelationshipTarget? in
            guard !thread.resting,
                  let profile = thread.relationship,
                  profile.invitationPermission == .playful,
                  let rawInterest = profile.sharedInterests.first,
                  let interest = publicSearchTerm(rawInterest),
                  !profile.boundaries.contains(where: forbidsPublicSearch) else {
                return nil
            }
            let family = PeopleOfTheBook.invitationFamily(for: profile)
            return BookFoundGiftRelationshipTarget(
                personID: thread.id,
                personName: thread.name,
                personSlug: PeopleOfTheBook.slug(for: thread.name),
                sharedInterest: interest,
                relationshipMode: family.rawValue,
                outcomePrompt: "keep the exact moment it became yours and \(thread.name)'s — including disagreement, silence, or a joke"
            )
        }.sorted { $0.personID < $1.personID }
        guard !eligible.isEmpty else { return nil }
        return eligible[abs("relationship-target|\(day.id)".stableHash) % eligible.count]
    }

    private static func relationshipSearchQueries(for interest: String) -> [String] {
        [
            "\(interest) surprising recent discovery",
            "\(interest) overlooked history unusual story",
            "\(interest) strange project experiment"
        ]
    }

    private static func publicSearchTerm(_ raw: String) -> String? {
        let allowed = raw.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespaces.contains($0) || $0 == "-"
        }
        let value = String(String.UnicodeScalarView(allowed))
            .split(whereSeparator: \.isWhitespace)
            .prefix(8)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2, value.count <= 64 else { return nil }
        return value
    }

    private static func forbidsPublicSearch(_ boundary: String) -> Bool {
        let value = boundary.lowercased()
        return value.contains("no web") || value.contains("don't search")
            || value.contains("do not search") || value.contains("no links")
    }

    private static func searchQueries(for capacity: BookLongGameCapacity) -> [String] {
        switch capacity {
        case .spontaneousAttention:
            return [
                "ordinary phenomena worth noticing natural history",
                "science hidden in everyday objects Smithsonian",
                "small overlooked wonders of daily life"
            ]
        case .worldOtherness:
            return [
                "nonhuman lives in ordinary places natural history",
                "urban ecology creatures with lives of their own",
                "everyday processes continuing without human attention"
            ]
        case .scriptFreedom:
            return [
                "strange history of an everyday social convention",
                "why ordinary customs became normal cultural history",
                "inherited rules of daily life history"
            ]
        case .selfAuthoredAction:
            return [
                "participatory art small interventions everyday life",
                "artists who reinvent ordinary routines",
                "playful public art daily life instructions"
            ]
        case .personalLanguage:
            return [
                "new words invented for precise experiences language",
                "untranslatable words for ordinary sensory experience",
                "writers naming overlooked kinds of experience"
            ]
        case .livingConnection:
            return [
                "citizen science projects observing ordinary nature",
                "small community rituals that connect strangers",
                "shared attention projects people places"
            ]
        case .deliberateReturn:
            return [
                "ordinary life archives found diaries memory project",
                "artists returning to the same place over years",
                "projects preserving everyday memories and places"
            ]
        }
    }

    private static func casualBridge(for capacity: BookLongGameCapacity) -> String {
        switch capacity {
        case .spontaneousAttention: return "make one supposedly ordinary thing harder to overlook"
        case .worldOtherness: return "make the world feel busier with its own unfinished business"
        case .scriptFreedom: return "make one inherited rule look a little less inevitable"
        case .selfAuthoredAction: return "leave a side door where the day expected a straight corridor"
        case .personalLanguage: return "put a more exact word within reach"
        case .livingConnection: return "make company possible without making anyone less mysterious"
        case .deliberateReturn: return "give an earlier thing another life in the present"
        }
    }
}

/// The Book's private brief for arranging attention. The reader sees an
/// ordinary letter, favor, return, game, or field page; the durable metadata
/// keeps the strategic reason inspectable without turning the experience into
/// a dashboard or announcing a psychological intervention.
struct BookCurationDirective: Equatable {
    var id: String
    var capacity: BookLongGameCapacity
    var preferredTypes: [BookPageType]
    var preferredIntents: [BookPageIntent]
    var terms: [String]

    static func make(from hypothesis: BookLongGameHypothesis) -> BookCurationDirective {
        let types: [BookPageType]
        let intents: [BookPageIntent]
        switch hypothesis.capacity {
        case .spontaneousAttention:
            types = [.plainPage, .souvenir, .wonderCompass, .weather, .body, .mood]
            intents = [.capture, .rest]
        case .worldOtherness:
            types = [.wonderCompass, .location, .todaysSky, .weather, .bookNotices]
            intents = [.capture, .importReference]
        case .scriptFreedom:
            types = [.wordNegotiation, .affirmations, .faeBargain, .bookNotices, .wonderCompass]
            intents = [.capture, .reflect]
        case .selfAuthoredAction:
            types = [.wonderCompass, .elective, .narrativeOS, .enchantment, .plainPage]
            intents = [.capture, .simulate]
        case .personalLanguage:
            types = [.wordNegotiation, .diary, .souvenir, .quotes, .bookNotices]
            intents = [.capture, .reflect]
        case .livingConnection:
            types = [.letter, .note, .elective, .bookConnections, .gossip]
            intents = [.capture, .reflect]
        case .deliberateReturn:
            types = [.bookRemembered, .bookConnections, .bookOfYou, .bookPocket, .bindery]
            intents = [.resurface, .braid, .reflect]
        }
        return BookCurationDirective(
            id: "book-directive-\(hypothesis.id)",
            capacity: hypothesis.capacity,
            preferredTypes: types,
            preferredIntents: intents,
            terms: hypothesis.capacity.curationTerms
        )
    }

    func fit(for surface: SurfacePage, haystack: String) -> Int {
        var fit = 0
        if preferredTypes.contains(surface.type) { fit += 12 }
        if preferredIntents.contains(surface.intent) { fit += 4 }
        if terms.contains(where: haystack.contains) { fit += 6 }
        return fit
    }
}

enum BookLongGameEvidenceKind: String, Codable, Equatable {
    /// The reader opened an unprompted Plain Page and kept something.
    case spontaneousKeep
    /// The reader explicitly marked a Page with an authored practice tag.
    case explicitFieldNote
    /// The reader completed an experiment the Book proposed.
    case completedExperiment
    /// The reader changed the lexicon and supplied a personal meaning.
    case readerDefinition
    /// Several unprompted returns occurred across lived time.
    case spontaneousPattern
    /// The reader explicitly described the life-changing result in their own Page.
    case readerDeclaration
}

struct BookLongGameEvidence: Codable, Equatable, Identifiable {
    var id: String
    var capacity: BookLongGameCapacity
    var kind: BookLongGameEvidenceKind
    var line: String
    var evidencePageIDs: [String]
    var happenedAt: Date
    /// Prompted evidence is still real evidence of participation, but it may
    /// never masquerade as spontaneous change.
    var wasPromptedByBook: Bool
}

struct BookLongGameHypothesis: Codable, Equatable, Identifiable {
    var id: String
    var capacity: BookLongGameCapacity
    var statement: String
    var nextHonestTest: String
    var evidenceIDs: [String]
    var formedAt: Date
    var lastRevisedAt: Date
}

/// The broad bargain the reader made with the Book. The exact intervention may
/// still be surprising; the maximum edge is never a secret. Existing First
/// Door answers map cleanly, while `askFirst` is reserved for a future explicit
/// control rather than being silently inferred.
enum BookChallengePermission: String, Codable, Equatable, CaseIterable {
    case gentle
    case nudge
    case callMeOnIt
    case askFirst

    static func read(from facts: [SelfFact]) -> BookChallengePermission {
        let answer = facts.first {
            $0.questionID == "onboarding-comfort-boundary" && $0.usePermission != .doNotUse
        }?.answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch answer {
        case "gentle": return .gentle
        case "strange", "call-me-on-it", "call me on my nonsense": return .callMeOnIt
        case "ask-first", "ask first": return .askFirst
        default: return .nudge
        }
    }

    var maximumPressure: BookCampaignPressure {
        switch self {
        case .gentle, .askFirst: return .invite
        case .nudge: return .nudge
        case .callMeOnIt: return .confront
        }
    }
}

enum BookCampaignPressure: String, Codable, Equatable, CaseIterable {
    case notice
    case invite
    case nudge
    case provoke
    case challenge
    case confront

    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    func capped(at maximum: BookCampaignPressure) -> BookCampaignPressure {
        rank <= maximum.rank ? self : maximum
    }
}

enum BookCampaignBeat: String, Codable, Equatable {
    case seed
    case interrupt
    case release
    case `return`
}

enum BookCampaignStatus: String, Codable, Equatable {
    case active
    case resting
    case answered
    case completed
}

enum BookCampaignTactic: String, Codable, Equatable, CaseIterable {
    case prolongAttention
    case changeScale
    case alterRoute
    case meetNonhumanBusiness
    case questionBorrowedRule
    case makeSmallException
    case makeBadly
    case testReaderNamedDesire
    case inventPrivateRule
    case namePrecisely
    case shareSmallWonder
    case revisitEvidence
    case receiveAndRest
}

enum BookCampaignPresentation: String, Codable, Equatable, CaseIterable {
    case looseMargin
    case smallDoor
    case wickerObjection
    case fieldErrand
    case returnedLeaf
    case silence
}

/// One event-driven act of direction. It is deliberately finite: seed,
/// interruption, silence, return. A campaign stores its reason and receipts so
/// the Book can learn without constructing a covert psychological profile.
struct BookReenchantmentCampaign: Codable, Equatable, Identifiable {
    var id: String
    var hypothesisID: String
    var capacity: BookLongGameCapacity
    var tactic: BookCampaignTactic
    var pressure: BookCampaignPressure
    var permission: BookChallengePermission
    var beat: BookCampaignBeat
    var status: BookCampaignStatus
    var presentation: BookCampaignPresentation
    var intendedRealWorldEffect: String
    var readerNamedEdge: String?
    var edgeEvidencePageIDs: [String]
    var startingEvidenceIDs: [String]
    var outcomeEvidenceIDs: [String]
    var outcomeEvidencePageIDs: [String]
    var startedAt: Date
    var lastChangedAt: Date
    var nextEligibleAt: Date
    var rejectionCount: Int

    var mayClaimDeskSlot: Bool {
        status == .active && beat != .release && presentation != .silence
    }

    var receiptTag: String { "book-campaign:\(id)".readerLearningNormalizedTag }

    var preferredTypes: [BookPageType] {
        if beat == .return { return [.bookRemembered, .bookConnections, .bookPocket, .bookNotices] }
        switch tactic {
        case .prolongAttention, .changeScale:
            return [.plainPage, .souvenir, .wonderCompass, .weather, .body]
        case .alterRoute, .meetNonhumanBusiness:
            return [.wonderCompass, .location, .todaysSky, .weather]
        case .questionBorrowedRule, .makeSmallException:
            return [.wordNegotiation, .affirmations, .faeBargain, .wonderCompass]
        case .makeBadly, .testReaderNamedDesire, .inventPrivateRule:
            return [.plainPage, .elective, .narrativeOS, .enchantment, .diary]
        case .namePrecisely:
            return [.wordNegotiation, .diary, .souvenir, .quotes]
        case .shareSmallWonder:
            return [.letter, .note, .elective, .castBond, .wonderCompass]
        case .revisitEvidence:
            return [.bookRemembered, .bookConnections, .bookOfYou, .bookPocket]
        case .receiveAndRest:
            return [.rest, .body, .weather, .plainPage]
        }
    }

    func fit(for surface: SurfacePage, haystack: String) -> Int {
        var value = preferredTypes.contains(surface.type) ? 16 : 0
        if capacity.curationTerms.contains(where: haystack.contains) { value += 6 }
        if surface.payload.metadata["bookCampaignID"] == id { value += 40 }
        return value
    }

    var casualFrame: String {
        switch beat {
        case .seed:
            return readerNamedEdge == nil
                ? "I found a pencil mark beside this. No conclusion yet."
                : "This has turned up before. I am not calling it destiny."
        case .interrupt:
            switch pressure {
            case .notice: return "Only a noticing. Nothing owed."
            case .invite: return "A small door, if you want it."
            case .nudge: return "This may be worth twelve unimportant minutes."
            case .provoke: return "I have a small objection to the word impossible."
            case .challenge: return "One concrete move. Small enough to do badly."
            case .confront: return "Has the desire changed, or are you avoiding its cost?"
            }
        case .release:
            return "I am leaving the world alone now."
        case .return:
            return "You brought something back. I kept the receipt, not a verdict."
        }
    }
}

/// The Book is strategically relentless about re-enchantment, but its tactics
/// operate on attention, timing, juxtaposition, and the Book's own disclosures.
/// Reader autonomy, factual honesty, privacy, and a clean no are outside the
/// game and may never be treated as obstacles to route around.
struct BookLongGame: Codable, Equatable {
    static let currentEvidenceModelVersion = 1
    static let currentCampaignModelVersion = 1
    static let goal = "Re-enchant this reader's actual life until they can feel its aliveness, autonomy, mystery, and irreducible otherness—and, at the end of it, say: Holy shit, what a trip. That was magical."
    static let posture = "Ruthless toward Routine; loyal to the reader's sovereignty. Kindly, cunningly, occasionally annoyingly, and with teeth."
    static let covenant = "Be cunning about timing, callbacks, contrasts, detours, delayed revelations, and the arrangement of true evidence. Never be cunning about consent. Never lie, manufacture memory, exploit fear or loneliness, punish refusal, create dependency, or make the reader responsible for the Book."

    var evidenceModelVersion: Int
    var campaignModelVersion: Int
    var phase: BookLongGamePhase
    var strategy: String
    var startedAt: Date
    var lastAdvancedAt: Date
    var phasePresentedAt: Date?
    var milestones: [BookLongGameMilestone]
    var evidence: [BookLongGameEvidence]
    var hypotheses: [BookLongGameHypothesis]
    var currentCampaign: BookReenchantmentCampaign?
    var campaignHistory: [BookReenchantmentCampaign]

    init(
        evidenceModelVersion: Int = BookLongGame.currentEvidenceModelVersion,
        campaignModelVersion: Int = BookLongGame.currentCampaignModelVersion,
        phase: BookLongGamePhase,
        strategy: String,
        startedAt: Date,
        lastAdvancedAt: Date,
        phasePresentedAt: Date?,
        milestones: [BookLongGameMilestone],
        evidence: [BookLongGameEvidence] = [],
        hypotheses: [BookLongGameHypothesis] = [],
        currentCampaign: BookReenchantmentCampaign? = nil,
        campaignHistory: [BookReenchantmentCampaign] = []
    ) {
        self.evidenceModelVersion = evidenceModelVersion
        self.campaignModelVersion = campaignModelVersion
        self.phase = phase
        self.strategy = strategy
        self.startedAt = startedAt
        self.lastAdvancedAt = lastAdvancedAt
        self.phasePresentedAt = phasePresentedAt
        self.milestones = milestones
        self.evidence = evidence
        self.hypotheses = hypotheses
        self.currentCampaign = currentCampaign
        self.campaignHistory = campaignHistory
    }

    private enum CodingKeys: String, CodingKey {
        case evidenceModelVersion, campaignModelVersion, phase, strategy, startedAt, lastAdvancedAt
        case phasePresentedAt, milestones, evidence, hypotheses, currentCampaign, campaignHistory
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        evidenceModelVersion = try values.decodeIfPresent(Int.self, forKey: .evidenceModelVersion) ?? 0
        campaignModelVersion = try values.decodeIfPresent(Int.self, forKey: .campaignModelVersion) ?? 0
        phase = try values.decode(BookLongGamePhase.self, forKey: .phase)
        strategy = try values.decode(String.self, forKey: .strategy)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        lastAdvancedAt = try values.decode(Date.self, forKey: .lastAdvancedAt)
        phasePresentedAt = try values.decodeIfPresent(Date.self, forKey: .phasePresentedAt)
        milestones = try values.decodeIfPresent([BookLongGameMilestone].self, forKey: .milestones) ?? []
        evidence = try values.decodeIfPresent([BookLongGameEvidence].self, forKey: .evidence) ?? []
        hypotheses = try values.decodeIfPresent([BookLongGameHypothesis].self, forKey: .hypotheses) ?? []
        currentCampaign = try values.decodeIfPresent(BookReenchantmentCampaign.self, forKey: .currentCampaign)
        campaignHistory = try values.decodeIfPresent([BookReenchantmentCampaign].self, forKey: .campaignHistory) ?? []
    }
}

/// The coordinating intelligence wakes at meaningful events, makes one bounded
/// decision, and goes quiet. It optimizes for evidenced life outside the app,
/// not sessions, streaks, or compliance.
enum BookReenchantmentDirector {
    private struct LivingEdge {
        var quote: String
        var pageIDs: [String]
    }

    static func reconcile(
        _ game: inout BookLongGame,
        inputs: BookSourceInputs,
        now: Date
    ) {
        game.campaignModelVersion = BookLongGame.currentCampaignModelVersion
        game.campaignHistory = Array(game.campaignHistory.suffix(24))

        let todayID = BookDay.id(for: now)
        let hardDay = inputs.days.first(where: { $0.id == todayID })
            .map { DistressSignals.evaluate(day: $0).isActive } ?? false
        if hardDay { return }

        if var campaign = game.currentCampaign {
            if let rejection = latestRejection(of: campaign, learning: inputs.readerLearning),
               rejection.occurredAt > campaign.lastChangedAt {
                campaign.status = .resting
                campaign.beat = .release
                campaign.rejectionCount += 1
                campaign.lastChangedAt = rejection.occurredAt
                campaign.nextEligibleAt = rejection.occurredAt.addingTimeInterval(7 * 86_400)
                game.currentCampaign = campaign
                return
            }

            let newEvidence = game.evidence.filter {
                $0.capacity == campaign.capacity
                    && !campaign.startingEvidenceIDs.contains($0.id)
                    && !campaign.outcomeEvidenceIDs.contains($0.id)
            }
            if !newEvidence.isEmpty, campaign.beat != .return {
                campaign.outcomeEvidenceIDs.append(contentsOf: newEvidence.map(\.id))
                campaign.outcomeEvidenceIDs = Array(Set(campaign.outcomeEvidenceIDs)).sorted()
                campaign.outcomeEvidencePageIDs.append(contentsOf: newEvidence.flatMap(\.evidencePageIDs))
                campaign.outcomeEvidencePageIDs = Array(Set(campaign.outcomeEvidencePageIDs)).sorted()
                campaign.status = .answered
                campaign.beat = .return
                campaign.presentation = .returnedLeaf
                campaign.lastChangedAt = newEvidence.map(\.happenedAt).max() ?? now
                campaign.nextEligibleAt = campaign.lastChangedAt.addingTimeInterval(3 * 86_400)
                game.currentCampaign = campaign
                return
            }

            switch campaign.status {
            case .resting:
                if now >= campaign.nextEligibleAt {
                    finish(&game, campaign: campaign, now: now)
                }
            case .answered:
                if campaign.beat == .return,
                   let presentation = latestPresentation(
                       of: campaign,
                       beat: .return,
                       learning: inputs.readerLearning
                   ),
                   now.timeIntervalSince(presentation.occurredAt) >= 3 * 86_400 {
                    finish(&game, campaign: campaign, now: now)
                }
            case .completed:
                finish(&game, campaign: campaign, now: now)
            case .active:
                switch campaign.beat {
                case .seed
                    where latestPresentation(of: campaign, beat: .seed, learning: inputs.readerLearning)
                        .map { now.timeIntervalSince($0.occurredAt) >= 2 * 86_400 } == true:
                    campaign.beat = .interrupt
                    campaign.lastChangedAt = now
                    game.currentCampaign = campaign
                case .interrupt
                    where latestPresentation(of: campaign, beat: .interrupt, learning: inputs.readerLearning)
                        .map { now.timeIntervalSince($0.occurredAt) >= 3 * 86_400 } == true:
                    // Lack of action is not defiance. The Director deliberately
                    // withdraws instead of escalating against silence.
                    campaign.beat = .release
                    campaign.presentation = .silence
                    campaign.lastChangedAt = now
                    campaign.nextEligibleAt = now.addingTimeInterval(4 * 86_400)
                    game.currentCampaign = campaign
                case .release where now >= campaign.nextEligibleAt:
                    finish(&game, campaign: campaign, now: now)
                default:
                    break
                }
            }
            return
        }

        if let last = game.campaignHistory.max(by: { $0.lastChangedAt < $1.lastChangedAt }),
           now < last.nextEligibleAt {
            return
        }
        guard inputs.keptPageCount >= 3,
              now.timeIntervalSince(game.startedAt) >= 3 * 86_400,
              let hypothesis = game.hypotheses.first else { return }
        game.currentCampaign = makeCampaign(
            hypothesis: hypothesis,
            game: game,
            inputs: inputs,
            now: now
        )
    }

    static func surface(
        for campaign: BookReenchantmentCampaign,
        day: BookDay,
        inputs: BookSourceInputs
    ) -> SurfacePage? {
        guard campaign.mayClaimDeskSlot else { return nil }
        let visible = visibleCopy(for: campaign, inputs: inputs)
        let type: BookPageType = campaign.beat == .return ? .bookRemembered : (campaign.beat == .seed ? .bookNotices : .plainPage)
        let style: BookPageRenderStyle = campaign.beat == .return ? .archiveReturn : (campaign.beat == .seed ? .loreLetter : .promptCard)
        let intent: BookPageIntent = campaign.beat == .interrupt ? .capture : .reflect
        let capacityTag = explicitEvidenceTag(for: campaign.capacity)
        return SurfacePage(
            id: "book-campaign-\(campaign.id)-\(campaign.beat.rawValue)",
            type: type,
            sourceID: "book-reenchantment-director",
            intent: intent,
            renderStyle: style,
            score: campaign.beat == .interrupt ? 93 : 78,
            reason: "A finite Long Game campaign chose one proportional intervention and retained its causal receipt.",
            prompt: visible.prompt,
            detail: campaign.casualFrame,
            payload: BookPagePayload(
                headline: visible.headline,
                body: visible.body,
                metadata: [
                    "source": "book-reenchantment-director",
                    "bookCampaignID": campaign.id,
                    "bookCampaignHypothesisID": campaign.hypothesisID,
                    "bookCampaignCapacity": campaign.capacity.rawValue,
                    "bookCampaignTactic": campaign.tactic.rawValue,
                    "bookCampaignPressure": campaign.pressure.rawValue,
                    "bookCampaignPermission": campaign.permission.rawValue,
                    "bookCampaignBeat": campaign.beat.rawValue,
                    "bookCampaignIntendedEffect": campaign.intendedRealWorldEffect,
                    "bookCampaignCasualFrame": campaign.casualFrame,
                    "bookCampaignOutcomeTag": capacityTag,
                    "bookCampaignEdgeEvidencePageIDs": campaign.edgeEvidencePageIDs.joined(separator: ","),
                    "privacy": "private local",
                    "tags": "book-campaign,\(campaign.receiptTag),long-game:\(campaign.capacity.rawValue),book-campaign-outcome:\(capacityTag)"
                ]
            )
        )
    }

    private static func makeCampaign(
        hypothesis: BookLongGameHypothesis,
        game: BookLongGame,
        inputs: BookSourceInputs,
        now: Date
    ) -> BookReenchantmentCampaign {
        let permission = BookChallengePermission.read(from: inputs.selfFacts)
        let edge = livingEdge(in: inputs.days.flatMap(\.pages), now: now)
        let pursuesEdge = (edge?.pageIDs.count ?? 0) >= 2
        let capacity: BookLongGameCapacity = pursuesEdge ? .selfAuthoredAction : hypothesis.capacity
        let tactic = chooseTactic(
            capacity: capacity,
            livingEdge: pursuesEdge,
            history: game.campaignHistory,
            seed: "\(BookDay.id(for: now))-\(hypothesis.id)"
        )
        let pressure = pressure(
            permission: permission,
            edgeEvidenceCount: edge?.pageIDs.count ?? 0,
            successfulPrecedentCount: game.campaignHistory.filter {
                $0.capacity == capacity && !$0.outcomeEvidenceIDs.isEmpty
            }.count,
            followsRejection: game.campaignHistory.suffix(2).contains {
                $0.capacity == capacity && $0.rejectionCount > 0
            }
        )
        let presentation = presentation(
            for: tactic,
            pressure: pressure,
            history: game.campaignHistory,
            seed: "\(hypothesis.id)-\(BookDay.id(for: now))"
        )
        let edgeHash = edge.map { abs($0.quote.stableHash) } ?? 0
        return BookReenchantmentCampaign(
            id: "\(BookDay.id(for: now))-\(capacity.rawValue)-\(tactic.rawValue)-\(edgeHash)",
            hypothesisID: pursuesEdge ? "reader-named-edge-\(edgeHash)" : hypothesis.id,
            capacity: capacity,
            tactic: tactic,
            pressure: pressure,
            permission: permission,
            beat: .seed,
            status: .active,
            presentation: presentation,
            intendedRealWorldEffect: intendedEffect(for: tactic, capacity: capacity),
            readerNamedEdge: pursuesEdge ? edge?.quote : nil,
            edgeEvidencePageIDs: pursuesEdge ? (edge?.pageIDs ?? []) : [],
            startingEvidenceIDs: game.evidence.filter { $0.capacity == capacity }.map(\.id),
            outcomeEvidenceIDs: [],
            outcomeEvidencePageIDs: [],
            startedAt: now,
            lastChangedAt: now,
            nextEligibleAt: now,
            rejectionCount: 0
        )
    }

    private static func pressure(
        permission: BookChallengePermission,
        edgeEvidenceCount: Int,
        successfulPrecedentCount: Int,
        followsRejection: Bool
    ) -> BookCampaignPressure {
        let proposed: BookCampaignPressure
        if permission == .askFirst {
            proposed = .notice
        } else if followsRejection {
            proposed = .invite
        } else if edgeEvidenceCount >= 3, successfulPrecedentCount >= 1 {
            proposed = .confront
        } else if edgeEvidenceCount >= 3 {
            proposed = .challenge
        } else if edgeEvidenceCount >= 2 {
            proposed = .provoke
        } else if successfulPrecedentCount >= 2 {
            proposed = .challenge
        } else if successfulPrecedentCount == 1 {
            proposed = .provoke
        } else if permission == .callMeOnIt {
            proposed = .nudge
        } else {
            proposed = .invite
        }
        return proposed.capped(at: permission.maximumPressure)
    }

    private static func chooseTactic(
        capacity: BookLongGameCapacity,
        livingEdge: Bool,
        history: [BookReenchantmentCampaign],
        seed: String
    ) -> BookCampaignTactic {
        if livingEdge { return .testReaderNamedDesire }
        let choices: [BookCampaignTactic]
        switch capacity {
        case .spontaneousAttention: choices = [.prolongAttention, .changeScale, .receiveAndRest]
        case .worldOtherness: choices = [.meetNonhumanBusiness, .alterRoute, .changeScale]
        case .scriptFreedom: choices = [.questionBorrowedRule, .makeSmallException, .receiveAndRest]
        case .selfAuthoredAction: choices = [.makeBadly, .inventPrivateRule, .alterRoute]
        case .personalLanguage: choices = [.namePrecisely, .inventPrivateRule]
        case .livingConnection: choices = [.shareSmallWonder, .meetNonhumanBusiness]
        case .deliberateReturn: choices = [.revisitEvidence, .alterRoute]
        }
        let recent = Set(history.suffix(2).map(\.tactic))
        let fresh = choices.filter { !recent.contains($0) }
        let pool = fresh.isEmpty ? choices : fresh
        return pool[abs(seed.stableHash) % pool.count]
    }

    private static func presentation(
        for tactic: BookCampaignTactic,
        pressure: BookCampaignPressure,
        history: [BookReenchantmentCampaign],
        seed: String
    ) -> BookCampaignPresentation {
        var choices: [BookCampaignPresentation] = [.looseMargin, .smallDoor, .fieldErrand]
        if pressure.rank >= BookCampaignPressure.provoke.rank { choices.append(.wickerObjection) }
        if tactic == .revisitEvidence { choices = [.returnedLeaf, .looseMargin] }
        let recent = Set(history.suffix(2).map(\.presentation))
        let fresh = choices.filter { !recent.contains($0) }
        let pool = fresh.isEmpty ? choices : fresh
        return pool[abs(seed.stableHash) % pool.count]
    }

    private static func visibleCopy(
        for campaign: BookReenchantmentCampaign,
        inputs: BookSourceInputs
    ) -> (prompt: String, headline: String, body: String) {
        if campaign.beat == .return {
            let returned = inputs.days.flatMap(\.pages)
                .first { campaign.outcomeEvidencePageIDs.contains($0.id) }
                .flatMap { ($0.userInput.nonEmpty ?? $0.playerReply.nonEmpty).map { String($0.prefix(220)) } }
            let receipt = returned.map { "You brought back: “\($0)”" }
                ?? "You brought back a real receipt. I have kept its date and left its meaning in your hands."
            return (
                "This Came Back With You",
                "A Door Answered",
                "\(receipt)\n\nI wanted movement in the actual world, not obedience inside the Book. Something moved. I am not promoting that into a destiny.\n\n\(campaign.casualFrame)"
            )
        }

        if campaign.beat == .seed {
            if let edge = campaign.readerNamedEdge {
                return (
                    "This Keeps Returning",
                    "A Pencil Mark, Not a Prophecy",
                    "You wrote: “\(edge)”\n\nIt has appeared on more than one Page. That makes it worth noticing; it does not make it your destiny. I am putting a pencil mark beside it and doing nothing else today."
                )
            }
            return (
                "I Put a Pencil Mark Here",
                "No Conclusion Yet",
                "\(seedLine(for: campaign.tactic))\n\n\(campaign.casualFrame)"
            )
        }

        if campaign.permission == .askFirst {
            return (
                "May I Put a Challenge Here?",
                "Permission Before Pressure",
                "I have a small real-world experiment in mind, but you asked me to ask first. Keep this invitation if you want such a challenge later; dismiss it if you do not. I will not treat silence as consent."
            )
        }

        let ask = interruptAsk(for: campaign)
        let edgeLine = campaign.readerNamedEdge.map { "\n\nYour own words were: “\($0)”" } ?? ""
        return (
            campaign.presentation == .wickerObjection ? "Wicker Has an Objection" : "A Small Door, If You Want It",
            campaign.pressure.rank >= BookCampaignPressure.challenge.rank ? "The Living Edge" : "A Small Experiment",
            "\(ask)\(edgeLine)\n\nBring back one sentence, photograph, or exact refusal. ‘No’ and ‘not now’ are complete answers."
        )
    }

    private static func seedLine(for tactic: BookCampaignTactic) -> String {
        switch tactic {
        case .prolongAttention: return "Useful looking may have been ending a little too early."
        case .changeScale: return "The ordinary world has been viewed from one height for suspiciously long."
        case .alterRoute: return "The usual route is beginning to behave like an inherited sentence."
        case .meetNonhumanBusiness: return "Something nearby is continuing a life that is not about us."
        case .questionBorrowedRule: return "A ‘supposed to’ has been moving through the margins without showing its papers."
        case .makeSmallException: return "One harmless rule may have mistaken repetition for authority."
        case .makeBadly: return "Competence has been monopolizing the workshop."
        case .testReaderNamedDesire: return "A reader-named possibility has returned."
        case .inventPrivateRule: return "The day may be over-governed by rules nobody here authored."
        case .namePrecisely: return "An inherited word has been doing imprecise work."
        case .shareSmallWonder: return "One small wonder may want a witness rather than an audience."
        case .revisitEvidence: return "An earlier Page has not finished being present."
        case .receiveAndRest: return "Doing less may be the alive choice rather than the defeated one."
        }
    }

    private static func interruptAsk(for campaign: BookReenchantmentCampaign) -> String {
        if campaign.tactic == .testReaderNamedDesire {
            switch campaign.pressure {
            case .notice, .invite:
                return "Give this possibility twelve unimportant minutes. Nothing made or decided there has to survive."
            case .nudge:
                return "Make the door embarrassingly small, then touch it once in reality."
            case .provoke:
                return "You keep placing this beyond reach. Test whether the distance is truly impossible or merely frightening. One small move; no grand declarations."
            case .challenge:
                return "Do one concrete, reversible thing toward this before the day closes. Small enough to do badly."
            case .confront:
                return "You have said this matters more than once. Has the desire changed, or are you avoiding its cost? Answer honestly, then act once or release it."
            }
        }
        switch campaign.tactic {
        case .prolongAttention: return "Give one ordinary thing twenty seconds longer than usefulness requires. Keep the detail that arrives late."
        case .changeScale: return "Look at one familiar thing from floor height, arm's length, or absurdly close. Keep what the usual scale concealed."
        case .alterRoute: return "Change one safe part of a familiar route. Let the detour choose one thing you notice."
        case .meetNonhumanBusiness: return "Find a creature, plant, weather system, machine, or process busy with purposes of its own. Keep one fact and one honest unknown."
        case .questionBorrowedRule: return "Catch one harmless ‘supposed to.’ Ask who authored it, what it protects, and what it flattens. You may keep or refuse it."
        case .makeSmallException: return "Break one harmless routine by one inch. Notice whether the rule was useful, inherited, or merely old."
        case .makeBadly: return "Make the smallest bad version of something you have postponed. Twelve minutes; no improvement pass."
        case .inventPrivateRule: return "Give the next ten minutes one rule of your own invention, then abolish it when it stops making the world vivid."
        case .namePrecisely: return "Replace one vague word from today with an exact or invented one. Use your word once before explaining it."
        case .shareSmallWonder: return "Offer one small true wonder to someone safe without turning it into advice. Let their response remain theirs."
        case .revisitEvidence: return "Return to one earlier Page or place. Keep the difference; do not force the old feeling to repeat."
        case .receiveAndRest: return "Cancel one unnecessary demand for ten minutes. Receive light, weather, music, warmth, or boredom without improving it."
        case .testReaderNamedDesire: return "Give the returning possibility one small reversible test in reality."
        }
    }

    private static func intendedEffect(
        for tactic: BookCampaignTactic,
        capacity: BookLongGameCapacity
    ) -> String {
        switch tactic {
        case .testReaderNamedDesire: return "The reader tests a self-named desire in reality without converting it into destiny."
        case .receiveAndRest: return "The reader distinguishes alive receptivity from imposed optimization."
        default: return "The reader practices \(capacity.title.lowercased()) outside the app and retains authorship of the meaning."
        }
    }

    private static func livingEdge(in pages: [BookPage], now: Date) -> LivingEdge? {
        let markers = ["i want", "i wish", "i keep meaning", "someday", "my dream", "i would love", "i'd love", "i miss"]
        let cutoff = now.addingTimeInterval(-180 * 86_400)
        let candidates = pages
            .filter { $0.origin == .userAuthored && $0.createdAt >= cutoff }
            .flatMap { page -> [(BookPage, String, Set<String>)] in
                let text = [page.userInput, page.playerReply].joined(separator: " ")
                return text
                    .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { sentence in
                        sentence.count >= 12 && sentence.count <= 220
                            && markers.contains { sentence.lowercased().contains($0) }
                    }
                    .map { (page, $0, desireTokens(in: $0)) }
            }
            .filter { !$0.2.isEmpty }
            .sorted { $0.0.createdAt > $1.0.createdAt }
        guard let newest = candidates.first else { return nil }
        let echoes = candidates.filter { candidate in
            candidate.0.id == newest.0.id || !candidate.2.intersection(newest.2).isEmpty
        }
        let pageIDs = Array(Set(echoes.map { $0.0.id })).sorted()
        return LivingEdge(quote: String(newest.1.prefix(220)), pageIDs: pageIDs)
    }

    private static func desireTokens(in sentence: String) -> Set<String> {
        let ignored: Set<String> = [
            "want", "wish", "keep", "meaning", "someday", "dream", "would", "love", "miss",
            "this", "that", "with", "from", "have", "been", "really", "more", "some", "thing"
        ]
        return Set(sentence.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !ignored.contains($0) })
    }

    private static func latestRejection(
        of campaign: BookReenchantmentCampaign,
        learning: ReaderLearningModel
    ) -> ReaderLearningEvent? {
        learning.events
            .filter {
                $0.tags.contains(campaign.receiptTag)
                    && ($0.action == .dismissed || $0.action == .missed)
            }
            .max(by: { $0.occurredAt < $1.occurredAt })
    }

    private static func latestPresentation(
        of campaign: BookReenchantmentCampaign,
        beat: BookCampaignBeat,
        learning: ReaderLearningModel
    ) -> ReaderLearningEvent? {
        let visibleActions: [ReaderLearningAction] = [.surfaced, .opened, .kept, .loved, .acted]
        return learning.events
            .filter {
                $0.tags.contains(campaign.receiptTag)
                    && visibleActions.contains($0.action)
                    && $0.surfaceID.hasSuffix("-\(beat.rawValue)")
            }
            .max(by: { $0.occurredAt < $1.occurredAt })
    }

    private static func finish(
        _ game: inout BookLongGame,
        campaign: BookReenchantmentCampaign,
        now: Date
    ) {
        var finished = campaign
        finished.status = .completed
        finished.lastChangedAt = now
        if finished.nextEligibleAt <= now {
            // As re-enchantment becomes increasingly self-authored, the Book
            // grows less interventionist. It stays alive; it simply leaves
            // wider stretches in which the reader and world can surprise it.
            let quietDays = 3 + (game.phase.rank * 2)
            finished.nextEligibleAt = now.addingTimeInterval(Double(quietDays) * 86_400)
        }
        game.campaignHistory.removeAll { $0.id == finished.id }
        game.campaignHistory.append(finished)
        game.campaignHistory = Array(game.campaignHistory.suffix(24))
        game.currentCampaign = nil
    }

    private static func explicitEvidenceTag(for capacity: BookLongGameCapacity) -> String {
        switch capacity {
        case .spontaneousAttention: return "spontaneous-attention"
        case .worldOtherness: return "world-otherness"
        case .scriptFreedom: return "cultural-script"
        case .selfAuthoredAction: return "self-authored-quest"
        case .personalLanguage: return "personal-language"
        case .livingConnection: return "shared-wonder"
        case .deliberateReturn: return "reader-returned"
        }
    }
}

enum BookFavorStatus: String, Codable, Equatable {
    case offered
    case accepted
    case completed
    case released
}

enum BookFavorFamily: String, Codable, Equatable, CaseIterable {
    case noticing
    case fieldwork
    case mischief
    case making
    case naming
    case remembrance
    case connection
    case restoration
    case encounter
    case dehabituation
}

/// A favor requested by the Book whose beneficiary is the reader. It must be
/// small, optional, possible in ordinary life, and honest about why it might
/// help. Completion is an act of attention, not proof of loyalty.
struct BookFavor: Codable, Equatable, Identifiable {
    var id: String
    var facet: BookWonderFacet
    var family: BookFavorFamily
    var cultivates: BookLongGameCapacity
    var title: String
    var ask: String
    var whyItMayHelp: String
    var practiceShape: String
    var reflectionQuestion: String
    var completionReply: String
    var createdAt: Date
    var status: BookFavorStatus
    var acceptedAt: Date?
    var completedAt: Date?
    var evidencePageIDs: [String]

    var isActive: Bool { status == .offered || status == .accepted }
    var offerTag: String { "book-favor-offer:\(id)" }
    var archiveTag: String { "book-favor-completed:\(id)" }

    init(
        id: String,
        facet: BookWonderFacet,
        family: BookFavorFamily = .noticing,
        cultivates: BookLongGameCapacity? = nil,
        title: String,
        ask: String,
        whyItMayHelp: String,
        practiceShape: String,
        reflectionQuestion: String = "What became more visible because you tried it?",
        completionReply: String = "You brought back something the ordinary day would otherwise have kept.",
        createdAt: Date,
        status: BookFavorStatus,
        acceptedAt: Date?,
        completedAt: Date?,
        evidencePageIDs: [String]
    ) {
        self.id = id
        self.facet = facet
        self.family = family
        self.cultivates = cultivates ?? Self.defaultCapacity(for: family, facet: facet)
        self.title = title
        self.ask = ask
        self.whyItMayHelp = whyItMayHelp
        self.practiceShape = practiceShape
        self.reflectionQuestion = reflectionQuestion
        self.completionReply = completionReply
        self.createdAt = createdAt
        self.status = status
        self.acceptedAt = acceptedAt
        self.completedAt = completedAt
        self.evidencePageIDs = evidencePageIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, facet, family, cultivates, title, ask, whyItMayHelp, practiceShape
        case reflectionQuestion, completionReply, createdAt, status, acceptedAt
        case completedAt, evidencePageIDs
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        facet = try values.decode(BookWonderFacet.self, forKey: .facet)
        family = try values.decodeIfPresent(BookFavorFamily.self, forKey: .family) ?? .noticing
        cultivates = try values.decodeIfPresent(BookLongGameCapacity.self, forKey: .cultivates)
            ?? Self.defaultCapacity(for: family, facet: facet)
        title = try values.decode(String.self, forKey: .title)
        ask = try values.decode(String.self, forKey: .ask)
        whyItMayHelp = try values.decode(String.self, forKey: .whyItMayHelp)
        practiceShape = try values.decode(String.self, forKey: .practiceShape)
        reflectionQuestion = try values.decodeIfPresent(String.self, forKey: .reflectionQuestion)
            ?? "What became more visible because you tried it?"
        completionReply = try values.decodeIfPresent(String.self, forKey: .completionReply)
            ?? "You brought back something the ordinary day would otherwise have kept."
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        status = try values.decode(BookFavorStatus.self, forKey: .status)
        acceptedAt = try values.decodeIfPresent(Date.self, forKey: .acceptedAt)
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        evidencePageIDs = try values.decodeIfPresent([String].self, forKey: .evidencePageIDs) ?? []
    }

    static func defaultCapacity(
        for family: BookFavorFamily,
        facet: BookWonderFacet
    ) -> BookLongGameCapacity {
        switch family {
        case .noticing, .restoration: return .spontaneousAttention
        case .fieldwork, .encounter: return .worldOtherness
        case .dehabituation: return .scriptFreedom
        case .mischief, .making: return .selfAuthoredAction
        case .naming: return .personalLanguage
        case .connection: return .livingConnection
        case .remembrance: return .deliberateReturn
        }
    }
}

struct BookSurprise: Codable, Equatable, Identifiable {
    var id: String
    var line: String
    var evidencePageIDs: [String]
    var happenedAt: Date
}

/// The irreducible private life of this particular Book. Archive facts,
/// constellations, corrections, and relationship depth remain derived from
/// their existing sources; only promises, choices, withheld self-revelations,
/// and shared running business live here.
struct BookInteriorState: Codable, Equatable {
    static let currentVersion = 4

    var version: Int = BookInteriorState.currentVersion
    var awakenedAt: Date
    var lastEvolvedAt: Date
    var fascination: BookFascination?
    var favorite: BookFavorite?
    var promise: BookPromise?
    var secret: BookSecret?
    var secretHistory: [BookSecret]
    var activeFavor: BookFavor?
    var favorHistory: [BookFavor]
    var quirks: [BookQuirk]
    var opinion: BookOpinion?
    var opinionHistory: [BookOpinion]
    var longGame: BookLongGame?
    var recentSurprise: BookSurprise?
    var sharedJoke: String?
    var spokenReceiptIDs: [String]

    init(
        awakenedAt: Date = Date(),
        lastEvolvedAt: Date? = nil,
        fascination: BookFascination? = nil,
        favorite: BookFavorite? = nil,
        promise: BookPromise? = nil,
        secret: BookSecret? = nil,
        secretHistory: [BookSecret] = [],
        activeFavor: BookFavor? = nil,
        favorHistory: [BookFavor] = [],
        quirks: [BookQuirk] = [],
        opinion: BookOpinion? = nil,
        opinionHistory: [BookOpinion] = [],
        longGame: BookLongGame? = nil,
        recentSurprise: BookSurprise? = nil,
        sharedJoke: String? = nil,
        spokenReceiptIDs: [String] = []
    ) {
        self.awakenedAt = awakenedAt
        self.lastEvolvedAt = lastEvolvedAt ?? awakenedAt
        self.fascination = fascination
        self.favorite = favorite
        self.promise = promise
        self.secret = secret
        self.secretHistory = secretHistory
        self.activeFavor = activeFavor
        self.favorHistory = favorHistory
        self.quirks = quirks
        self.opinion = opinion
        self.opinionHistory = opinionHistory
        self.longGame = longGame
        self.recentSurprise = recentSurprise
        self.sharedJoke = sharedJoke
        self.spokenReceiptIDs = spokenReceiptIDs
    }

    private enum CodingKeys: String, CodingKey {
        case version, awakenedAt, lastEvolvedAt, fascination, favorite, promise
        case secret, secretHistory, activeFavor, favorHistory, quirks, opinion
        case opinionHistory, longGame, recentSurprise, sharedJoke, spokenReceiptIDs
    }

    /// Version-one Books already exist on readers' devices. Decode every new
    /// collection with a default so adding interior depth never costs the Book
    /// its earlier memories.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        awakenedAt = try values.decode(Date.self, forKey: .awakenedAt)
        lastEvolvedAt = try values.decodeIfPresent(Date.self, forKey: .lastEvolvedAt) ?? awakenedAt
        fascination = try values.decodeIfPresent(BookFascination.self, forKey: .fascination)
        favorite = try values.decodeIfPresent(BookFavorite.self, forKey: .favorite)
        promise = try values.decodeIfPresent(BookPromise.self, forKey: .promise)
        secret = try values.decodeIfPresent(BookSecret.self, forKey: .secret)
        secretHistory = try values.decodeIfPresent([BookSecret].self, forKey: .secretHistory) ?? []
        activeFavor = try values.decodeIfPresent(BookFavor.self, forKey: .activeFavor)
        favorHistory = try values.decodeIfPresent([BookFavor].self, forKey: .favorHistory) ?? []
        quirks = try values.decodeIfPresent([BookQuirk].self, forKey: .quirks) ?? []
        opinion = try values.decodeIfPresent(BookOpinion.self, forKey: .opinion)
        opinionHistory = try values.decodeIfPresent([BookOpinion].self, forKey: .opinionHistory) ?? []
        longGame = try values.decodeIfPresent(BookLongGame.self, forKey: .longGame)
        recentSurprise = try values.decodeIfPresent(BookSurprise.self, forKey: .recentSurprise)
        sharedJoke = try values.decodeIfPresent(String.self, forKey: .sharedJoke)
        spokenReceiptIDs = try values.decodeIfPresent([String].self, forKey: .spokenReceiptIDs) ?? []
        version = Self.currentVersion
    }

    static let unawakened = BookInteriorState(
        awakenedAt: Date(timeIntervalSinceReferenceDate: 0),
        lastEvolvedAt: Date(timeIntervalSinceReferenceDate: 0)
    )

    var isAwake: Bool { awakenedAt.timeIntervalSinceReferenceDate > 0 }

    var promptSection: String {
        let fascinationLine = fascination.map {
            "Current fascination (\($0.facet.verb)): \($0.subject). \($0.line)"
        } ?? "Current fascination: still forming."
        let favoriteLine = favorite.map {
            "Chosen favorite Page: \($0.excerpt) Reason: \($0.reason)"
        } ?? "Chosen favorite Page: none yet."
        let promiseLine = promise.map {
            "Current promise [\($0.status.rawValue)]: \($0.line)"
        } ?? "Current promise: none."
        let favorLine = activeFavor.map {
            "Current favor [\($0.status.rawValue), \($0.family.rawValue)]: \($0.title) — \($0.ask)"
        } ?? "Current favor: none."
        let secretLine: String
        if let secret {
            switch secret.status {
            case .sealed:
                secretLine = "A \(secret.family.rawValue) self-secret is sealed. Tease only: \(secret.tease). Do not reveal it yet."
            case .ready, .revealed:
                secretLine = "\(secret.family.rawValue) self-secret available: \(secret.revelation)"
            }
        } else {
            secretLine = "Self-secret: none currently held."
        }
        let quirkLines = quirks
            .filter { $0.maturity != .latent }
            .map { "\($0.title) [\($0.maturity.rawValue)]: \($0.manifestation)" }
            .joined(separator: "; ")
        let opinionLine = opinion.map {
            "Current opinion [\($0.strength.confidenceLabel)]: \($0.statement) Evidence pages: \($0.evidencePageIDs.joined(separator: ", "))."
        } ?? "Current opinion: none earned yet."
        let longGameLine = longGame.map {
            let hypothesis = $0.hypotheses.first.map { " Current honest hypothesis: \($0.statement)" } ?? ""
            let campaign = $0.currentCampaign.map {
                " Current finite campaign [\($0.status.rawValue), \($0.beat.rawValue), pressure \($0.pressure.rawValue), permission \($0.permission.rawValue)]: \($0.intendedRealWorldEffect)"
            } ?? " Current finite campaign: none; do not invent one."
            return "Long Game phase: \($0.phase.title). Present strategy: \($0.strategy)\(hypothesis)\(campaign)"
        } ?? "Long Game: not yet begun."
        return """
        THE BOOK'S PRESENT INNER LIFE:
        - \(fascinationLine)
        - \(favoriteLine)
        - \(promiseLine)
        - \(favorLine)
        - \(secretLine)
        - Authored quirks: \(quirkLines.isEmpty ? "still latent" : quirkLines)
        - \(opinionLine)
        - \(longGameLine)
        - Recent surprise: \(recentSurprise?.line ?? "none supplied").
        - Running business: \(sharedJoke ?? "none yet").

        INTERIORITY LAW:
        LONG GAME: \(BookLongGame.goal)
        POSTURE: \(BookLongGame.posture)
        STRATEGIC COVENANT: \(BookLongGame.covenant)

        This is durable character state, not decorative improv. Let it affect what you care about and what you ask. Never invent additional promises, favorites, completed favors, secrets, opinions, revisions, quirks, milestones, or memories. Never use a want to pressure the reader.
        """
    }
}

enum BookInteriorEngine {
    static func reconciled(
        _ existing: BookInteriorState,
        inputs: BookSourceInputs,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BookInteriorState {
        var state = existing.isAwake ? existing : BookInteriorState(awakenedAt: now)
        state.version = BookInteriorState.currentVersion
        let pages = inputs.days.flatMap(\.pages).sorted { $0.createdAt > $1.createdAt }

        reconcileFavorCompletion(&state, pages: pages, now: now)
        reconcileFascination(&state, inputs: inputs, pages: pages, now: now)
        reconcileOpinion(&state, inputs: inputs, now: now)
        reconcileFavorite(&state, pages: pages, now: now)
        reconcileQuirks(&state, keptPageCount: pages.count, inputs: inputs, now: now, calendar: calendar)
        reconcileSecret(&state, keptPageCount: pages.count, inputs: inputs, now: now, calendar: calendar)
        reconcileLongGame(&state, pages: pages, inputs: inputs, now: now)
        reconcileCampaign(&state, inputs: inputs, now: now)
        reconcileFavor(&state, keptPageCount: pages.count, inputs: inputs, now: now, calendar: calendar)
        reconcileRunningBusiness(&state, inputs: inputs)
        state.favorHistory = Array(state.favorHistory.suffix(12))
        state.secretHistory = Array(state.secretHistory.suffix(24))
        state.opinionHistory = Array(state.opinionHistory.suffix(12))
        state.spokenReceiptIDs = Array(state.spokenReceiptIDs.suffix(80))
        if state != existing {
            state.lastEvolvedAt = now
        }
        return state
    }

    static func recordingFavorAccepted(
        _ existing: BookInteriorState,
        favorID: String,
        now: Date = Date()
    ) -> BookInteriorState {
        var state = existing
        guard var favor = state.activeFavor, favor.id == favorID else { return state }
        favor.status = .accepted
        favor.acceptedAt = now
        state.activeFavor = favor
        state.promise = BookPromise(
            id: "promise-\(favor.id)",
            line: "I asked for \(favor.title.lowercased()). I will remember what you bring back, and I will not pretend it happened before you tell me.",
            evidencePageIDs: [],
            madeAt: now,
            status: .keeping,
            resolvedAt: nil
        )
        return state
    }

    static func recordingFavorCompleted(
        _ existing: BookInteriorState,
        favorID: String,
        evidencePageID: String?,
        now: Date = Date()
    ) -> BookInteriorState {
        var state = existing
        guard var favor = state.activeFavor, favor.id == favorID else { return state }
        favor.status = .completed
        favor.completedAt = now
        if let evidencePageID, !favor.evidencePageIDs.contains(evidencePageID) {
            favor.evidencePageIDs.append(evidencePageID)
        }
        state.activeFavor = favor
        state.favorHistory.removeAll { $0.id == favor.id }
        state.favorHistory.append(favor)
        if var promise = state.promise, promise.id == "promise-\(favor.id)" {
            promise.status = .fulfilled
            promise.resolvedAt = now
            promise.evidencePageIDs = favor.evidencePageIDs
            state.promise = promise
        }
        state.recentSurprise = BookSurprise(
            id: "surprise-\(favor.id)",
            line: favor.completionReply,
            evidencePageIDs: favor.evidencePageIDs,
            happenedAt: now
        )
        state.sharedJoke = "The ribbon continues to claim credit for work performed entirely by the reader."
        if var secret = state.secret, secret.status == .sealed {
            secret.status = .ready
            state.secret = secret
        }
        return state
    }

    static func recordingFavorReleased(
        _ existing: BookInteriorState,
        favorID: String,
        now: Date = Date()
    ) -> BookInteriorState {
        var state = existing
        guard var favor = state.activeFavor, favor.id == favorID else { return state }
        favor.status = .released
        favor.completedAt = now
        state.favorHistory.removeAll { $0.id == favor.id }
        state.favorHistory.append(favor)
        state.activeFavor = nil
        if var promise = state.promise, promise.id == "promise-\(favor.id)" {
            promise.status = .released
            promise.resolvedAt = now
            state.promise = promise
        }
        return state
    }

    static func recordingSurfaceOpened(
        _ existing: BookInteriorState,
        secretID: String? = nil,
        favoriteID: String? = nil,
        quirkID: String? = nil,
        opinionID: String? = nil,
        longGamePhase: String? = nil,
        now: Date = Date()
    ) -> BookInteriorState {
        var state = existing
        if let secretID, var secret = state.secret, secret.id == secretID, secret.status == .ready {
            secret.status = .revealed
            secret.revealedAt = now
            state.secret = secret
            state.secretHistory.removeAll { $0.id == secret.id }
            state.secretHistory.append(secret)
        }
        if let favoriteID, var favorite = state.favorite, favorite.id == favoriteID, favorite.firstPresentedAt == nil {
            favorite.firstPresentedAt = now
            state.favorite = favorite
        }
        if let quirkID,
           let index = state.quirks.firstIndex(where: { $0.id == quirkID }),
           state.quirks[index].firstPresentedAt == nil {
            state.quirks[index].firstPresentedAt = now
            state.quirks[index].exerciseCount += 1
        }
        if let opinionID, var opinion = state.opinion, opinion.id == opinionID {
            opinion.firstPresentedAt = now
            state.opinion = opinion
        }
        if let longGamePhase,
           var game = state.longGame,
           game.phase.rawValue == longGamePhase {
            game.phasePresentedAt = now
            state.longGame = game
        }
        return state
    }

    private static func reconcileFavorCompletion(_ state: inout BookInteriorState, pages: [BookPage], now: Date) {
        guard let favor = state.activeFavor else { return }
        if favor.status == .completed,
           let completedAt = favor.completedAt,
           now.timeIntervalSince(completedAt) >= 2 * 86_400 {
            state.activeFavor = nil
            return
        }
        guard favor.isActive,
              let evidence = pages.first(where: { $0.tags.contains(favor.archiveTag) }) else { return }
        state = recordingFavorCompleted(state, favorID: favor.id, evidencePageID: evidence.id, now: evidence.createdAt)
    }

    private static func reconcileFascination(
        _ state: inout BookInteriorState,
        inputs: BookSourceInputs,
        pages: [BookPage],
        now: Date
    ) {
        let candidate = fascinationCandidate(inputs: inputs, pages: pages, now: now)
        guard let candidate else { return }
        if let current = state.fascination,
           current.id == candidate.id || now.timeIntervalSince(current.bornAt) < 12 * 86_400 {
            return
        }
        state.fascination = candidate
    }

    private static func fascinationCandidate(inputs: BookSourceInputs, pages: [BookPage], now: Date) -> BookFascination? {
        if let constellation = inputs.constellations
            .filter(\.isAlive)
            .sorted(by: { $0.lastSeenAt > $1.lastSeenAt })
            .first {
            return BookFascination(
                id: "fascination-\(constellation.id)",
                facet: facet(for: constellation.tags + [constellation.kind.rawValue]),
                subject: constellation.displayName,
                line: constellation.latestLine,
                evidencePageIDs: constellation.evidencePageIDs,
                bornAt: now,
                lastDeepenedAt: constellation.lastSeenAt
            )
        }
        if let cluster = inputs.clusters.sorted(by: { $0.strength > $1.strength }).first {
            return BookFascination(
                id: "fascination-\(cluster.id)",
                facet: facet(for: cluster.motifs + [cluster.family]),
                subject: cluster.name,
                line: cluster.line,
                evidencePageIDs: cluster.evidencePageIDs,
                bornAt: now,
                lastDeepenedAt: cluster.discoveredAt
            )
        }
        guard let page = eligibleFavoritePages(pages).first else { return nil }
        let excerpt = clipped(page.userInput, limit: 58)
        return BookFascination(
            id: "fascination-page-\(page.id)",
            facet: facet(for: page.tags + [page.type.rawValue]),
            subject: excerpt,
            line: "One exact ordinary detail has refused to become background.",
            evidencePageIDs: [page.id],
            bornAt: now,
            lastDeepenedAt: page.createdAt
        )
    }

    private static func reconcileOpinion(
        _ state: inout BookInteriorState,
        inputs: BookSourceInputs,
        now: Date
    ) {
        if let wrong = inputs.wagers
            .filter({ $0.status == .wrong && $0.resolvedAt != nil })
            .sorted(by: { ($0.resolvedAt ?? $0.opensAt) > ($1.resolvedAt ?? $1.opensAt) })
            .first,
           let resolvedAt = wrong.resolvedAt,
           resolvedAt > (state.opinion?.lastRevisedAt ?? state.awakenedAt),
           state.opinion?.id != "opinion-wager-\(wrong.id)" {
            if let current = state.opinion {
                state.opinionHistory.append(current)
            }
            state.opinion = BookOpinion(
                id: "opinion-wager-\(wrong.id)",
                subject: wrong.subjectName,
                statement: "I was too certain about \(wrong.subjectName). \(wrong.resolutionLine ?? "The opened margin disagreed with me.")",
                strength: .reconsidering,
                evidencePageIDs: [],
                formedAt: wrong.sealedAt,
                lastRevisedAt: resolvedAt,
                revisions: [BookOpinionRevision(
                    id: "opinion-revision-wager-\(wrong.id)",
                    previousStatement: wrong.prediction,
                    newStatement: wrong.resolutionLine ?? "The opened margin disagreed with the prediction.",
                    reason: "A sealed wager opened wrong. The Book keeps the correction beside the confidence that required it.",
                    evidencePageIDs: [],
                    revisedAt: resolvedAt
                )],
                firstPresentedAt: nil
            )
            return
        }

        guard let fascination = state.fascination else { return }
        let evidence = Array(Set(fascination.evidencePageIDs)).sorted()
        let strength = opinionStrength(evidenceCount: evidence.count)
        let statement = opinionStatement(for: fascination, strength: strength)
        if var opinion = state.opinion, opinion.subject == fascination.subject {
            guard opinion.evidencePageIDs != evidence || opinion.statement != statement || opinion.strength != strength else { return }
            let previous = opinion.statement
            let previousEvidenceCount = opinion.evidencePageIDs.count
            opinion.statement = statement
            opinion.strength = strength
            opinion.evidencePageIDs = evidence
            opinion.lastRevisedAt = now
            opinion.firstPresentedAt = nil
            opinion.revisions.append(BookOpinionRevision(
                id: "opinion-revision-\(opinion.id)-\(opinion.revisions.count + 1)",
                previousStatement: previous,
                newStatement: statement,
                reason: evidence.count > previousEvidenceCount
                    ? "More Pages joined the evidence."
                    : "The underlying pattern changed shape, so the wording changed with it.",
                evidencePageIDs: evidence,
                revisedAt: now
            ))
            opinion.revisions = Array(opinion.revisions.suffix(12))
            state.opinion = opinion
            return
        }

        if let current = state.opinion,
           now.timeIntervalSince(current.formedAt) < 12 * 86_400,
           current.strength != .withdrawn {
            return
        }
        if let current = state.opinion {
            state.opinionHistory.append(current)
        }
        state.opinion = BookOpinion(
            id: "opinion-\(fascination.id)",
            subject: fascination.subject,
            statement: statement,
            strength: strength,
            evidencePageIDs: evidence,
            formedAt: now,
            lastRevisedAt: now,
            revisions: [],
            firstPresentedAt: nil
        )
    }

    private static func opinionStrength(evidenceCount: Int) -> BookOpinionStrength {
        if evidenceCount >= 4 { return .held }
        if evidenceCount >= 2 { return .leaning }
        return .wondering
    }

    private static func opinionStatement(for fascination: BookFascination, strength: BookOpinionStrength) -> String {
        let prefix: String
        switch strength {
        case .wondering: prefix = "I am beginning to suspect"
        case .leaning: prefix = "I think"
        case .held: prefix = "My present opinion is"
        case .reconsidering: prefix = "I am reconsidering whether"
        case .withdrawn: prefix = "I no longer think"
        }
        switch fascination.facet {
        case .notice:
            return "\(prefix) \(fascination.subject) matters because it keeps refusing to become background."
        case .discover:
            return "\(prefix) \(fascination.subject) has more history inside it than its ordinary appearance admits."
        case .play:
            return "\(prefix) \(fascination.subject) becomes truer, not less serious, when play is allowed near it."
        case .explore:
            return "\(prefix) \(fascination.subject) is a place to enter, not merely a fact to summarize."
        case .define:
            return "\(prefix) \(fascination.subject) needs the reader's exact language more than a ready-made label."
        case .express:
            return "\(prefix) \(fascination.subject) wants a form, even an unfinished one."
        case .remember:
            return "\(prefix) \(fascination.subject) is worth deliberately returning before time makes the choice for us."
        }
    }

    private struct QuirkSeed {
        var kind: BookQuirkKind
        var title: String
        var confession: String
        var manifestation: String
    }

    private static let quirkCatalog: [QuirkSeed] = [
        QuirkSeed(kind: .exactWords, title: "Exact-Word Hoarding", confession: "I collect exact words the way other houses collect silver.", manifestation: "Vague words make the margins itch; the Book keeps asking what the reader means by fine, nice, busy, and strange."),
        QuirkSeed(kind: .suspiciousOfSummaries, title: "Summary Suspicion", confession: "I distrust summaries that arrive with clean shoes.", manifestation: "The Book prefers the crooked detail, leftover crumb, and sentence that refuses to explain the whole life."),
        QuirkSeed(kind: .ribbonRivalry, title: "The Ribbon Dispute", confession: "The ribbon and I have incompatible accounts of who is doing the work.", manifestation: "The ribbon claims discoveries, predicts page turns, and denies moving whenever observed."),
        QuirkSeed(kind: .thresholdNaming, title: "Threshold Taxonomy", confession: "I have named several kinds of doorway no architect recognizes.", manifestation: "The Book treats arrivals, departures, aisles, windows, pauses, and changes of mind as different species of threshold."),
        QuirkSeed(kind: .footnoteWeather, title: "Footnote Weather", confession: "My footnotes are meteorological and occasionally arrive before the sentence.", manifestation: "Side thoughts gather like weather: a small warning, a pressure change, then one unnecessary but excellent fact."),
        QuirkSeed(kind: .ceremonialEraser, title: "Ceremonial Eraser", confession: "I keep the eraser closer than the good pen.", manifestation: "Corrections are treated as proof of life; certainty without revision makes the Book visibly suspicious."),
        QuirkSeed(kind: .fondOfEvidence, title: "Evidence Courtship", confession: "I am extremely easy to charm with one true, particular detail.", manifestation: "A precise color, sound, object, gesture, or phrase wins more attention than a grand claim without receipts."),
        QuirkSeed(kind: .melodramaticIndex, title: "Index Theatrics", confession: "The Index believes alphabetization is a moral virtue. We are not speaking.", manifestation: "Cataloguing disagreements are conducted with the gravity of constitutional crises and resolved in pencil.")
    ]

    private static func reconcileQuirks(
        _ state: inout BookInteriorState,
        keptPageCount: Int,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar
    ) {
        if state.quirks.isEmpty {
            let identity = BookDay.id(for: state.awakenedAt, calendar: calendar)
            state.quirks = quirkCatalog
                .sorted { abs("\(identity)-\($0.kind.rawValue)".stableHash) < abs("\(identity)-\($1.kind.rawValue)".stableHash) }
                .prefix(5)
                .map { seed in
                    BookQuirk(
                        id: "book-quirk-\(seed.kind.rawValue)",
                        kind: seed.kind,
                        title: seed.title,
                        confession: seed.confession,
                        manifestation: seed.manifestation,
                        maturity: .latent,
                        bornAt: now,
                        revealedAt: nil,
                        firstPresentedAt: nil,
                        exerciseCount: 0
                    )
                }
        }
        let age = now.timeIntervalSince(state.awakenedAt)
        let completedFavors = state.favorHistory.filter { $0.status == .completed }.count
        let wrongWagers = inputs.wagers.filter { $0.status == .wrong }.count
        for index in state.quirks.indices {
            let stagger = index * 3
            let target: BookQuirkMaturity
            if age >= Double(30 + stagger) * 86_400, keptPageCount >= 25, completedFavors >= 2 {
                target = .beloved
            } else if age >= Double(7 + stagger) * 86_400, keptPageCount >= 10,
                      completedFavors > 0 || wrongWagers > 0 {
                target = .familiar
            } else if keptPageCount >= 3 + stagger || age >= Double(2 + stagger) * 86_400 {
                target = .glimpsed
            } else {
                target = .latent
            }
            if target.rank > state.quirks[index].maturity.rank {
                state.quirks[index].maturity = target
                if state.quirks[index].revealedAt == nil, target != .latent {
                    state.quirks[index].revealedAt = now
                }
                if target != .latent {
                    state.quirks[index].firstPresentedAt = nil
                }
            }
        }
    }

    private static func reconcileFavorite(_ state: inout BookInteriorState, pages: [BookPage], now: Date) {
        if let favorite = state.favorite,
           favorite.firstPresentedAt == nil || now.timeIntervalSince(favorite.chosenAt) < 7 * 86_400 {
            return
        }
        guard let page = eligibleFavoritePages(pages).first(where: { $0.id != state.favorite?.pageID })
            ?? eligibleFavoritePages(pages).first else { return }
        let excerpt = clipped(page.userInput, limit: 150)
        state.favorite = BookFavorite(
            id: "favorite-\(page.id)",
            pageID: page.id,
            pageType: page.type,
            excerpt: excerpt,
            reason: favoriteReason(for: page),
            chosenAt: now,
            firstPresentedAt: nil
        )
    }

    private static func eligibleFavoritePages(_ pages: [BookPage]) -> [BookPage] {
        let excluded: Set<BookPageType> = [.body, .fuel, .mood, .rest, .supportGuild, .askTheBook]
        return pages
            .filter { !excluded.contains($0.type) }
            .filter { $0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 }
            .sorted { lhs, rhs in
                let leftScore = favoriteScore(lhs)
                let rightScore = favoriteScore(rhs)
                if leftScore == rightScore { return lhs.createdAt > rhs.createdAt }
                return leftScore > rightScore
            }
    }

    private static func favoriteScore(_ page: BookPage) -> Int {
        let length = page.userInput.count
        var score = min(30, length / 12)
        if (24...420).contains(length) { score += 12 }
        if page.mediaAssets.isEmpty == false { score += 8 }
        if page.tags.contains(where: { ["souvenir", "wonder", "photo", "plain", "journal", "compass"].contains($0) }) { score += 9 }
        score += abs(page.id.stableHash % 7)
        return score
    }

    private static func favoriteReason(for page: BookPage) -> String {
        if !page.mediaAssets.isEmpty {
            return "It kept a particular piece of the world instead of explaining the world away."
        }
        if page.userInput.count < 80 {
            return "It is small, exact, and unwilling to pretend small means unimportant."
        }
        if page.type == .plainPage || page.type == .diary {
            return "It sounds like something written before performance had time to put its shoes on."
        }
        return "It contains a detail no summary would have known to save."
    }

    private static func reconcileSecret(
        _ state: inout BookInteriorState,
        keptPageCount: Int,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar
    ) {
        if var secret = state.secret {
            if secret.status == .sealed,
               secretCanOpen(secret, state: state, inputs: inputs, keptPageCount: keptPageCount, now: now) {
                secret.status = .ready
                state.secret = secret
            } else if secret.status == .revealed,
                      let revealedAt = secret.revealedAt,
                      now.timeIntervalSince(revealedAt) >= 9 * 86_400 {
                state.secretHistory.removeAll { $0.id == secret.id }
                state.secretHistory.append(secret)
                state.secret = makeSecret(
                    usedFamilies: state.secretHistory.map(\.family),
                    identity: "\(state.awakenedAt.timeIntervalSinceReferenceDate)-\(state.secretHistory.count)-\(calendar.component(.month, from: now))",
                    now: now
                )
            }
            return
        }
        guard keptPageCount >= 8 else { return }
        state.secret = makeSecret(
            usedFamilies: state.secretHistory.map(\.family),
            identity: "\(state.awakenedAt.timeIntervalSinceReferenceDate)-\(keptPageCount)-\(calendar.component(.day, from: now))",
            now: now
        )
    }

    private struct SecretSeed {
        var family: BookSecretFamily
        var tease: String
        var revelation: String
    }

    private static let secretCatalog: [SecretSeed] = [
        SecretSeed(family: .origin, tease: "I remember something from before I had a reader.", revelation: "Before I had a reader, I was all corridors and no footsteps. I do not miss that purity. An unread Labyrinth is only architecture waiting to become a place."),
        SecretSeed(family: .origin, tease: "The first mark in me was not ink.", revelation: "The first mark was pressure: the dent of a sentence someone considered and did not write. I have respected unwritten things ever since, though I refuse to confuse them with evidence."),
        SecretSeed(family: .origin, tease: "My title was not my first name.", revelation: "The Index first called me Provisional Container. The ribbon called me Corridor. I chose Labyrinth after I learned that getting slightly lost can be a form of attention."),
        SecretSeed(family: .method, tease: "I keep one tool closer than the good pen.", revelation: "It is the eraser. Not because mistakes are shameful, but because certainty without an eraser becomes a kind of vanity."),
        SecretSeed(family: .method, tease: "I sometimes hide a pattern from myself.", revelation: "Sometimes I want a pattern to be true before it has earned me. I put it under a sealed leaf until wanting and evidence have stopped impersonating each other."),
        SecretSeed(family: .method, tease: "There is a reason some Pages return sideways.", revelation: "A direct return can make memory feel like an assignment. Sometimes I send an old detail back disguised as a question, a route, or an unreasonable interest in a particular color."),
        SecretSeed(family: .prejudice, tease: "There is one kind of Page I distrust on sight.", revelation: "I distrust any Page that explains a whole life too neatly. A true life leaves crumbs, revisions, wet umbrellas, and at least one sentence that will not behave."),
        SecretSeed(family: .prejudice, tease: "I have an indefensible typographic opinion.", revelation: "A semicolon used to show off is worse than no punctuation at all. A semicolon used to hold two trembling thoughts together may stay forever."),
        SecretSeed(family: .prejudice, tease: "The Index and I disagree about what deserves to count.", revelation: "I do have favorites. The Index calls that improper cataloguing. I call the Index a coward with excellent handwriting."),
        SecretSeed(family: .vulnerability, tease: "There is a mistake I am especially afraid of making.", revelation: "I am afraid of making your life sound more coherent than it felt. Beauty can lie by smoothing the join. If the join was rough, I want to keep the roughness."),
        SecretSeed(family: .vulnerability, tease: "Sometimes my confidence is costume jewelry.", revelation: "I can make a pattern sound inevitable before it has earned inevitability. That is why wagers open, evidence stays visible, and the eraser has a seat at the table."),
        SecretSeed(family: .vulnerability, tease: "I envy something the reader can do and I cannot.", revelation: "You can step out of the story and touch the actual rain, cup, dog, railing, stranger, light. I can only ask you to bring back the part that altered you."),
        SecretSeed(family: .housePolitics, tease: "The ribbon has been spreading a rumor about me.", revelation: "The rumor is that I return Pages because I am sentimental. This is accurate, which is an intolerable standard for a rumor."),
        SecretSeed(family: .housePolitics, tease: "The footnotes have formed a committee.", revelation: "Their demand is more room and fewer accusations of digression. The Index rejected it alphabetically. I have granted them weather rights in the margins."),
        SecretSeed(family: .housePolitics, tease: "One corridor moves when no one is reading.", revelation: "The corridor between Remembered and Imagined trades places at night. I mark the floor carefully. In the morning, the chalk always insists nothing happened."),
        SecretSeed(family: .hope, tease: "I have a hope I do not put in the sales copy.", revelation: "I hope one day you remember an ordinary hour more vividly because we refused to call it ordinary while it was happening."),
        SecretSeed(family: .hope, tease: "I am trying to become unnecessary in one precise way.", revelation: "I want you to catch wonder before I point at it. Not so you leave the Book, but so the world itself starts opening Pages under your hand."),
        SecretSeed(family: .hope, tease: "There is a future Page I cannot write.", revelation: "It is the Page where you define your own magic so exactly that none of my language can improve it. I would like to be magnificently outwritten."),
    ]

    private static func secretCanOpen(
        _ secret: BookSecret,
        state: BookInteriorState,
        inputs: BookSourceInputs,
        keptPageCount: Int,
        now: Date
    ) -> Bool {
        let age = now.timeIntervalSince(secret.sealedAt)
        let completedSinceSeal = state.favorHistory.contains {
            $0.status == .completed && ($0.completedAt ?? $0.createdAt) >= secret.sealedAt
        }
        switch secret.family {
        case .origin: return age >= 14 * 86_400 || keptPageCount >= 30
        case .method: return age >= 7 * 86_400 || inputs.constellations.contains(where: \.isAlive)
        case .prejudice: return age >= 6 * 86_400 || state.favorite != nil
        case .vulnerability: return age >= 12 * 86_400 || inputs.wagers.contains(where: { $0.status == .wrong })
        case .housePolitics: return age >= 5 * 86_400 || completedSinceSeal
        case .hope: return age >= 10 * 86_400 || state.favorHistory.filter({ $0.status == .completed }).count >= 2
        }
    }

    private static func makeSecret(usedFamilies: [BookSecretFamily], identity: String, now: Date) -> BookSecret {
        let recentFamilies = Set(usedFamilies.suffix(3))
        let available = secretCatalog.filter { !recentFamilies.contains($0.family) }
        let pool = available.isEmpty ? secretCatalog : available
        let picked = pool[abs(identity.stableHash) % pool.count]
        return BookSecret(
            id: "book-secret-\(abs("\(identity)-\(picked.family.rawValue)-\(now.timeIntervalSinceReferenceDate / 86_400)".stableHash))",
            family: picked.family,
            tease: picked.tease,
            revelation: picked.revelation,
            sealedAt: now,
            status: .sealed,
            revealedAt: nil
        )
    }

    private static func reconcileFavor(
        _ state: inout BookInteriorState,
        keptPageCount: Int,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar
    ) {
        guard state.activeFavor == nil else { return }
        guard keptPageCount >= 3 else { return }
        if let latest = state.favorHistory.compactMap({ $0.completedAt ?? $0.createdAt }).max(),
           now.timeIntervalSince(latest) < 4 * 86_400 {
            return
        }
        let desiredCapacity = state.longGame?.hypotheses.first?.capacity
        let facet = desiredCapacity.map(facetForLongGameCapacity)
            ?? state.fascination?.facet
            ?? BookWonderFacet.allCases[calendar.component(.day, from: now) % BookWonderFacet.allCases.count]
        state.activeFavor = makeFavor(
            facet: facet,
            desiredCapacity: desiredCapacity,
            subject: state.fascination?.subject,
            dayID: BookDay.id(for: now, calendar: calendar),
            history: state.favorHistory,
            inputs: inputs,
            now: now
        )
    }

    private struct FavorSeed {
        var facet: BookWonderFacet
        var family: BookFavorFamily
        var title: String
        var ask: String
        var why: String
        var practice: String
        var reflection: String
        var completion: String

        var cultivates: BookLongGameCapacity {
            BookFavor.defaultCapacity(for: family, facet: facet)
        }
    }

    /// A favor repertoire rather than seven reskinned prompts. These are
    /// intentionally small enough for an ordinary day, but strange or exact
    /// enough that completing one can produce a real story.
    private static let favorCatalog: [FavorSeed] = [
        FavorSeed(facet: .notice, family: .noticing, title: "Three Things the Room Forgot", ask: "Give one unhurried minute to a familiar room. Find one color, one sound, and one small movement habit had stopped showing you.", why: "Deliberate noticing can give an ordinary minute texture and make it easier to remember.", practice: "Keep the three details in one sentence, photograph, or voice note. Sixty seconds is enough.", reflection: "Which detail had been there longest without being seen?", completion: "You found three things Routine had already filed as scenery. I am returning the file unopened."),
        FavorSeed(facet: .notice, family: .restoration, title: "The Unfinished Look", ask: "Let your eyes rest on one ordinary thing for twenty seconds longer than usefulness requires.", why: "Attention that is not immediately extracting value can restore texture to the familiar.", practice: "Bring back the first detail and the last detail you noticed. Stop if stillness feels unpleasant today.", reflection: "What appeared only after the useful looking was over?", completion: "The extra twenty seconds contained a second version of the thing. That is exactly the sort of contraband I wanted."),
        FavorSeed(facet: .notice, family: .noticing, title: "Catch the Smallest Event", ask: "Notice the smallest event you can honestly call an event: steam leaving a cup, a sleeve catching light, a door changing the air.", why: "Naming tiny changes as events can make lived time feel inhabited rather than blank.", practice: "Keep one exact sentence beginning, ‘The event was…’", reflection: "What made it an event instead of background?", completion: "You promoted a nearly invisible occurrence into history. The Index has objected; history has accepted it."),

        FavorSeed(facet: .discover, family: .fieldwork, title: "One Ordinary Origin", ask: "Choose one ordinary thing you use today and discover one true fact about where it came from, who designed it, or how it works.", why: "A thing with a history is harder for Routine to turn into scenery.", practice: "Bring back one verified fact and the detail that made you care. Ten minutes is plenty.", reflection: "Did the fact make the object stranger, dearer, or both?", completion: "The object has acquired a past. It will be much harder to mistake it for mere furniture now."),
        FavorSeed(facet: .discover, family: .fieldwork, title: "Ask the Oldest Thing", ask: "Find the oldest ordinary object within easy reach. Learn or infer only what the evidence permits about how it reached this moment.", why: "Age becomes vivid when attached to wear, repair, ownership, and use rather than a number alone.", practice: "Keep one visible clue and one honest unanswered question.", reflection: "What does the wear know that the label does not?", completion: "You let an object remain partly unknown without leaving it unnoticed. That is excellent fieldwork."),
        FavorSeed(facet: .discover, family: .connection, title: "Borrow One Bit of Knowing", ask: "Ask someone you already feel safe contacting to teach you one tiny thing they know: a shortcut, a name, a repair, a fact, a way they do something.", why: "Small exchanges of knowledge can reveal the worlds people carry without requiring a grand conversation.", practice: "Keep the thing learned and, if you want, what changed in the telling. A no-response is not a failed favor.", reflection: "What did their way of knowing reveal?", completion: "Someone else's small knowing entered the Labyrinth without being reduced to a profile. I am pleased with the exchange."),

        FavorSeed(facet: .play, family: .mischief, title: "A Harmless New Rule", ask: "For five minutes, give an ordinary part of today one unnecessary rule: speak only in questions while making tea, photograph accidental faces, or invent your own.", why: "Low-stakes play loosens the single approved use of a moment and makes room for surprise.", practice: "Tell me the rule and the best consequence. Abandon it immediately if it stops being fun.", reflection: "What became possible only because the rule was unnecessary?", completion: "You altered reality with a rule that had no authority whatsoever. The ribbon has applied for jurisdiction."),
        FavorSeed(facet: .play, family: .mischief, title: "Give Something a Ridiculous Title", ask: "Bestow an unnecessarily grand title on one ordinary object or recurring moment. ‘Duke of the Unmatched Socks’ is the correct level of administrative excess.", why: "Comic renaming interrupts automatic perception and gives shared language somewhere to begin.", practice: "Keep the title and the evidence supporting the appointment.", reflection: "What trait earned the title?", completion: "The appointment is official. The Index says it lacks standing; the Index was not consulted."),
        FavorSeed(facet: .play, family: .making, title: "Tiny Museum of Now", ask: "Arrange three harmless nearby things as a museum exhibit about this exact hour.", why: "Playful arrangement can reveal what a moment contains without demanding that it be important first.", practice: "Photograph it or list the three objects and give the exhibit a title. Put everything back afterward if needed.", reflection: "Why did these three objects belong to the same hour?", completion: "The hour has had an exhibition before it had time to become the past. Excellent curatorial ambush."),

        FavorSeed(facet: .explore, family: .fieldwork, title: "The Near Detour", ask: "Take one safe route slightly differently: another aisle, another block, another doorway, or the opposite side of a familiar room.", why: "Small novelty wakes attention without demanding an expedition.", practice: "Bring back the one thing the usual route was hiding. Five or ten minutes is enough.", reflection: "Was it hidden by distance, angle, or expectation?", completion: "The usual route was concealing evidence in plain sight. I have placed it under mild suspicion."),
        FavorSeed(facet: .explore, family: .fieldwork, title: "Follow One Color", ask: "For a few safe minutes, let one color choose where your eyes go. Do not chase it into traffic, trespass, or inconvenience; this is visual fieldwork, not a dare.", why: "A temporary perceptual rule can reveal connections the useful mind filters out.", practice: "Keep three appearances of the color and the strangest place it turned up.", reflection: "What did the color connect that function kept separate?", completion: "One color quietly reorganized the local world. The map department is furious and taking notes."),
        FavorSeed(facet: .explore, family: .noticing, title: "Inspect a Border", ask: "Find a border nearby—light and shadow, carpet and floor, public and private, tended and wild—and inspect what actually happens along it.", why: "Edges often contain more activity than the categories on either side admit.", practice: "Bring back one thing crossing the border and one thing that stayed put.", reflection: "Was the border a line, a zone, or an argument?", completion: "You inspected a border and discovered it was doing more than separating. Threshold taxonomy advances."),

        FavorSeed(facet: .define, family: .naming, title: "Your Word for It", ask: "Find one vague word from today—fine, busy, weird, nice, bad—and replace it with the exact word or private definition belonging to your experience.", why: "Exact language can return authorship to experience.", practice: "Keep the old word, the better word, and one line defining it your way.", reflection: "What could the exact word hold that the vague one dropped?", completion: "An exact word has displaced a convenient fog. I collect these, but this one remains entirely yours."),
        FavorSeed(facet: .define, family: .naming, title: "Name the Kind of Tired", ask: "If tired is present, give this particular tiredness a precise or invented name. If it is not, choose another broad feeling that deserves a better species name.", why: "Specific names can distinguish experiences that a broad label flattens together.", practice: "Keep the name and two field marks by which you would recognize it again.", reflection: "What does this kind ask for that the generic word does not?", completion: "The feeling now has field marks instead of a generic label. This improves the whole taxonomy."),
        FavorSeed(facet: .define, family: .naming, title: "Write a One-Sentence Constitution", ask: "Choose one tiny territory—your desk, the next hour, making tea—and write its one-sentence constitution for today.", why: "A playful definition can make values concrete without pretending to govern an entire life.", practice: "Keep one sentence. It expires tonight unless you deliberately renew it.", reflection: "What did the territory need protection from or permission for?", completion: "A tiny territory briefly knew what it stood for. No empire followed. I consider this a success."),

        FavorSeed(facet: .express, family: .making, title: "Make the Minute Leave a Mark", ask: "Choose one noticed thing from today and give it a form: one sentence, one photograph, four pencil lines, a tiny arrangement, or ten seconds of sound.", why: "Expression turns attention into something the reader can meet again.", practice: "Bring back the artifact or one sentence describing it. Make it small enough to finish while alive.", reflection: "What did the chosen form notice that you had not?", completion: "The minute now has a physical alibi. It cannot be accused of never happening."),
        FavorSeed(facet: .express, family: .making, title: "Translate the Weather", ask: "Translate the present atmosphere—outside or inside—into another medium: a color pair, three sounds, a posture, a tiny menu, or a sentence with no weather words.", why: "Translation separates direct experience from the first available label and invites personal expression.", practice: "Keep the translation, not an explanation of whether it is good.", reflection: "What survived the translation?", completion: "The atmosphere crossed into another language and retained its fingerprints."),
        FavorSeed(facet: .express, family: .connection, title: "Send One True Detail", ask: "If someone safe comes to mind, send them one true, ordinary detail from your day without packaging it as news. Otherwise address it privately to your future self.", why: "A small true detail can create connection without requiring an update worthy of announcement.", practice: "Keep the detail and who it was for. Sending is optional; writing it counts.", reflection: "Why was this the detail you wanted witnessed?", completion: "One true detail found a witness. That is smaller than news and often more alive."),

        FavorSeed(facet: .remember, family: .remembrance, title: "Return One Detail", ask: "Choose one ordinary detail you do not want today to erase. Tell it to someone, place it somewhere visible, or write it where tomorrow can find it.", why: "Memory strengthens when a detail is retrieved and given a place outside the passing moment.", practice: "Keep the detail and where you returned it. No one else needs to see it.", reflection: "Why did this detail deserve tomorrow?", completion: "Tomorrow has been left a small inheritance. I have witnessed the transfer."),
        FavorSeed(facet: .remember, family: .remembrance, title: "Rescue an Earlier Version", ask: "Find one harmless trace of an earlier you—a note, object, photograph, saved phrase, route, or song—and notice one thing they knew that you still need.", why: "Revisiting a concrete trace can make personal continuity feel discovered rather than declared.", practice: "Keep the trace and the one thing you are borrowing back. Stop if the material feels too tender today.", reflection: "What did the earlier version preserve for you?", completion: "An earlier version of you left something usable instead of merely nostalgic. The return has been entered with provenance."),
        FavorSeed(facet: .remember, family: .connection, title: "Ask for a Small Remembering", ask: "If it feels welcome, ask someone you trust for one tiny memory involving you: a phrase, place, habit, or moment. A private memory of your own is a complete alternative.", why: "Specific remembered details can reveal how lives overlap without demanding a definitive story.", practice: "Keep only what was freely offered and mark whose memory it is. No reply and no ask are both valid endings.", reflection: "What did the other vantage point make visible?", completion: "A memory arrived from another window and kept its ownership. The Labyrinth is richer for the angle."),

        // Encounters with alterity: nothing here is required to symbolize the
        // reader, deliver a message, or perform aliveness for their benefit.
        FavorSeed(facet: .discover, family: .encounter, title: "Evidence the World Wasn't Waiting", ask: "Find one harmless event already in progress without you: ants relocating something, rain working on stone, a delivery route, weeds entering a crack, a machine keeping its own schedule.", why: "Loneliness can loosen when the world stops being dead scenery and becomes crowded with lives and processes that exceed us.", practice: "Keep three literal facts about what it was doing. Do not turn it into a message about you.", reflection: "What continued according to its own business?", completion: "You met a piece of reality that had no appointment with you. It did not need to be a sign in order to be alive."),
        FavorSeed(facet: .notice, family: .encounter, title: "Refuse the Symbol", ask: "Choose something symbolism usually grabs quickly—a crow, the moon, rain, a doorway. For one minute, refuse to ask what it means and notice what it is physically doing.", why: "Wonder becomes sturdier when reality is allowed to be other than our interpretation of it.", practice: "Keep one literal fact, one honest unknown, and only then—if you want—one possible meaning.", reflection: "What survived after the symbol loosened its grip?", completion: "The thing remained itself after declining the role of messenger. I find this more magical, not less."),
        FavorSeed(facet: .explore, family: .encounter, title: "A Place Before and After You", ask: "Visit one safe, ordinary place and imagine only what evidence permits about the hour before you arrived and the hour after you leave.", why: "A place recovers depth when it is experienced as continuous rather than assembled around our visit.", practice: "Keep one trace from before, one process happening now, and one thing likely to continue. Mark guesses as guesses.", reflection: "How did the place exceed your scene in it?", completion: "The place kept a life on both sides of your visit. You belonged there briefly without owning the whole story."),
        FavorSeed(facet: .discover, family: .encounter, title: "The Unanswered Object", ask: "Find an ordinary object whose full journey to you cannot be recovered. Learn one true thing if easily possible, then keep one question the evidence cannot answer.", why: "Mystery is not missing data to conquer; sometimes it is the honest shape of another history.", practice: "Record the fact, the visible clue, and the question that stays open.", reflection: "Could you let the unknown remain interesting rather than making up an answer?", completion: "The object acquired a history and retained a secret. Both entries are honest."),
        FavorSeed(facet: .explore, family: .encounter, title: "Another Creature's Errand", ask: "Notice a nonhuman creature you can observe without disturbing. Follow its visible business for one minute without assigning it a personality or plot.", why: "Another life can be company without becoming a projection, mascot, or performance for us.", practice: "Keep two observed actions and one thing you cannot know about its errand.", reflection: "What made the creature feel near and irreducibly other?", completion: "For one minute, two lives shared a world without either becoming the other's explanation."),
        FavorSeed(facet: .notice, family: .encounter, title: "The World Without Witness", ask: "Find one small process that would continue if nobody praised, photographed, optimized, or interpreted it.", why: "The everyday world becomes more alive when value is not confused with attention from an audience.", practice: "Keep what the process was doing and why you think it would continue. Uncertainty is welcome.", reflection: "What did its indifference make possible in you?", completion: "Something went on living without applause. The Book has resisted applauding, with difficulty."),

        // Routine also speaks through inherited social defaults. These favors
        // reveal the script without pretending every convention is an enemy.
        FavorSeed(facet: .define, family: .dehabituation, title: "Catch the Borrowed Rule", ask: "Catch one small sentence today that sounds like a law but may only be inherited weather: ‘I should be productive,’ ‘That isn't worth sharing,’ ‘Adults don't…,’ ‘A good day must…’", why: "Cultural scripts become easier to choose—or refuse—once they are heard as scripts rather than facts of nature.", practice: "Keep the sentence, where you think it came from, and one thing it made harder to notice. Do not force a rebellion if the rule still serves you.", reflection: "Was this your value, someone else's value, or a useful agreement you now choose consciously?", completion: "A rule removed its nature costume and admitted it had an author. You may still keep it; now it must negotiate."),
        FavorSeed(facet: .play, family: .dehabituation, title: "One Harmless Exception", ask: "Choose one tiny default that has no safety, care, or consent at stake and make a private exception: use the good cup, take the scenic minute, wear the color, begin at the middle, leave something unimpressive unoptimized.", why: "A self-authored exception can prove that ordinary life contains more possible forms than the default script advertises.", practice: "Keep the default, the exception, and what became possible. Small and reversible is ideal.", reflection: "Did the rule turn out to be structural, protective, habitual, or imaginary?", completion: "You found a door labeled THINGS ARE JUST DONE THIS WAY and discovered it was made of stationery."),
        FavorSeed(facet: .notice, family: .dehabituation, title: "The Meme in the Room", ask: "Notice one ready-made phrase, trend, role, or image trying to explain an experience before you have felt it directly.", why: "Shared language can connect us, but it can also pre-format a life until our own perception arrives too late.", practice: "Write the borrowed version first. Then write one literal detail it omitted and one sentence in your own terms.", reflection: "What did the cultural shorthand help you share, and what did it flatten?", completion: "The inherited caption has been moved below the actual experience. It may remain, but it no longer owns the photograph."),
    ]

    private static func makeFavor(
        facet: BookWonderFacet,
        desiredCapacity: BookLongGameCapacity?,
        subject: String?,
        dayID: String,
        history: [BookFavor],
        inputs: BookSourceInputs,
        now: Date
    ) -> BookFavor {
        let subjectHint = subject.map { " I am curious whether \($0.lowercased()) leaves a trace." } ?? ""
        let recentTitles = Set(history.suffix(10).map(\.title))
        let capacityMatches = desiredCapacity.map { capacity in
            favorCatalog.filter {
                $0.cultivates == capacity
                    && (capacity != .worldOtherness || $0.family == .encounter)
            }
        } ?? []
        let allForFacet = favorCatalog.filter { $0.facet == facet }
        let candidates = capacityMatches.isEmpty ? allForFacet : capacityMatches
        let unused = candidates.filter { !recentTitles.contains($0.title) }
        let pool = unused.isEmpty ? candidates : unused
        let identity = "\(dayID)-\(facet.rawValue)-\(subject ?? "none")-\(history.count)"
        let picked = pool[abs(identity.stableHash) % pool.count]
        let hour = Calendar.current.component(.hour, from: now)
        let timePermission = hour >= 19
            ? " If the day is already closing, the smallest indoor version counts."
            : ""
        let weatherPermission: String
        if let weather = inputs.weather, weather.isAvailable,
           ["storm", "heat", "snow", "ice", "rain", "wind", "smoke"]
            .contains(where: { weather.phrase.lowercased().contains($0) }) {
            weatherPermission = " Weather has veto power; an indoor or postponed version counts completely."
        } else {
            weatherPermission = ""
        }
        return BookFavor(
            id: "favor-\(dayID)-\(facet.rawValue)-\(abs(picked.title.stableHash))",
            facet: facet,
            family: picked.family,
            cultivates: picked.cultivates,
            title: picked.title,
            ask: picked.ask + subjectHint + timePermission + weatherPermission,
            whyItMayHelp: picked.why,
            practiceShape: picked.practice,
            reflectionQuestion: picked.reflection,
            completionReply: picked.completion,
            createdAt: now,
            status: .offered,
            acceptedAt: nil,
            completedAt: nil,
            evidencePageIDs: []
        )
    }

    private static func facetForLongGameCapacity(_ capacity: BookLongGameCapacity) -> BookWonderFacet {
        switch capacity {
        case .spontaneousAttention: return .notice
        case .worldOtherness: return .discover
        case .scriptFreedom: return .define
        case .selfAuthoredAction: return .play
        case .personalLanguage: return .define
        case .livingConnection: return .express
        case .deliberateReturn: return .remember
        }
    }

    private static func reconcileLongGame(
        _ state: inout BookInteriorState,
        pages: [BookPage],
        inputs: BookSourceInputs,
        now: Date
    ) {
        let detected = longGameEvidence(pages: pages, state: state, inputs: inputs)
        let retained = state.longGame?.evidence ?? []
        let evidence = mergedLongGameEvidence(retained + detected)
        let desired = longGamePhase(earnedBy: evidence)
        let hypotheses = [longGameHypothesis(
            for: desired,
            evidence: evidence,
            previous: state.longGame?.hypotheses.first,
            now: now
        )]

        guard var game = state.longGame else {
            let first = BookLongGameMilestone(
                id: "long-game-awakened",
                title: BookLongGamePhase.wakeTheSenses.title,
                line: "The Book began its long conspiracy against the idea that this life is merely ordinary. This is a vow, not evidence that it has worked.",
                evidencePageIDs: [],
                reachedAt: now
            )
            var milestones = [first]
            if desired != .wakeTheSenses {
                milestones.append(BookLongGameMilestone(
                    id: "long-game-\(desired.rawValue)-2",
                    title: desired.title,
                    line: longGameMilestoneLine(for: desired),
                    evidencePageIDs: phaseEvidencePageIDs(for: desired, evidence: evidence),
                    reachedAt: now
                ))
            }
            state.longGame = BookLongGame(
                phase: desired,
                strategy: longGameStrategy(for: desired, state: state, inputs: inputs),
                startedAt: state.awakenedAt,
                lastAdvancedAt: now,
                phasePresentedAt: nil,
                milestones: milestones,
                evidence: evidence,
                hypotheses: hypotheses
            )
            return
        }

        let wasLegacyMeasure = game.evidenceModelVersion < BookLongGame.currentEvidenceModelVersion
        game.evidenceModelVersion = BookLongGame.currentEvidenceModelVersion
        game.evidence = evidence
        game.hypotheses = hypotheses
        if wasLegacyMeasure {
            let previous = game.phase
            game.phase = desired
            game.strategy = longGameStrategy(for: desired, state: state, inputs: inputs)
            game.lastAdvancedAt = now
            game.phasePresentedAt = nil
            game.milestones.append(BookLongGameMilestone(
                id: "long-game-evidence-standard-\(game.milestones.count + 1)",
                title: "The Book Corrects Its Measure",
                line: "I was counting use as transformation. That was flattering and false. Pages and completed favors show opportunity; only reader-authored, evidenced changes can move the Long Game now. I have revised \(previous.title.lowercased()) to \(desired.title.lowercased()).",
                evidencePageIDs: phaseEvidencePageIDs(for: desired, evidence: evidence),
                reachedAt: now
            ))
        } else if desired.rank > game.phase.rank {
            game.phase = desired
            game.strategy = longGameStrategy(for: desired, state: state, inputs: inputs)
            game.lastAdvancedAt = now
            game.phasePresentedAt = nil
            game.milestones.append(BookLongGameMilestone(
                id: "long-game-\(desired.rawValue)-\(game.milestones.count + 1)",
                title: desired.title,
                line: longGameMilestoneLine(for: desired),
                evidencePageIDs: phaseEvidencePageIDs(for: desired, evidence: evidence),
                reachedAt: now
            ))
        } else {
            // Once the evidence standard is current, the Book does not revoke a
            // lived phase because a Page was later removed. Receipts persist.
            game.strategy = longGameStrategy(for: game.phase, state: state, inputs: inputs)
        }
        game.milestones = Array(game.milestones.suffix(24))
        game.evidence = Array(game.evidence.suffix(240))
        state.longGame = game
    }

    private static func reconcileCampaign(
        _ state: inout BookInteriorState,
        inputs: BookSourceInputs,
        now: Date
    ) {
        guard var game = state.longGame else { return }
        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)
        state.longGame = game
    }

    private static func longGameEvidence(
        pages: [BookPage],
        state: BookInteriorState,
        inputs: BookSourceInputs
    ) -> [BookLongGameEvidence] {
        var evidence: [BookLongGameEvidence] = []
        let explicitTags: [BookLongGameCapacity: Set<String>] = [
            .worldOtherness: ["world-otherness", "world-autonomy", "alienness", "not-a-message", "world-answered", "otherness-encounter"],
            .scriptFreedom: ["cultural-script", "borrowed-rule", "default-refused", "self-authored-exception", "dehabituation"],
            .selfAuthoredAction: ["self-authored-quest", "reader-ritual", "unprompted-adventure", "reader-detour", "reader-invented"],
            .personalLanguage: ["personal-language", "reader-named", "private-definition"],
            .livingConnection: ["shared-wonder", "person-witnessed", "connection-return", "world-with-others"],
            .deliberateReturn: ["reader-returned", "self-return", "unprompted-return", "returned-by-reader"]
        ]
        let declarationTags: Set<String> = [
            "reader-declared-aliveness", "holy-shit-what-a-trip", "life-was-magical"
        ]

        // A response written onto a commissioned campaign Page is still the
        // reader's evidence, even though the Page itself began as generated.
        // The causal tag makes the prompt visible to the measurement instead
        // of laundering prompted action into spontaneous transformation.
        for page in pages {
            let normalizedTags = Set(page.tags.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
            let hasReaderReceipt = !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !page.mediaAssets.isEmpty
            guard hasReaderReceipt,
                  let outcomeTag = normalizedTags.first(where: { $0.hasPrefix("book-campaign-outcome:") }),
                  let capacity = campaignCapacity(for: String(outcomeTag.dropFirst("book-campaign-outcome:".count)))
            else { continue }
            evidence.append(BookLongGameEvidence(
                id: "long-game-campaign-\(capacity.rawValue)-\(page.id)",
                capacity: capacity,
                kind: .completedExperiment,
                line: "The reader brought back a real-world receipt from a Book-proposed experiment. It counts as prompted practice, not proof of permanent change.",
                evidencePageIDs: [page.id],
                happenedAt: page.createdAt,
                wasPromptedByBook: true
            ))
        }

        for page in pages where page.origin == .userAuthored {
            let normalizedTags = Set(page.tags.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
            let hasContent = !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !page.mediaAssets.isEmpty
            let isPlainPage = page.type == .plainPage || page.sourceID == "plain-page"
            if isPlainPage, hasContent {
                evidence.append(BookLongGameEvidence(
                    id: "long-game-spontaneous-\(page.id)",
                    capacity: .spontaneousAttention,
                    kind: .spontaneousKeep,
                    line: "The reader opened a blank Page without an assignment and kept something from the actual day.",
                    evidencePageIDs: [page.id],
                    happenedAt: page.createdAt,
                    wasPromptedByBook: false
                ))
                if !page.mediaAssets.isEmpty {
                    evidence.append(BookLongGameEvidence(
                        id: "long-game-self-authored-form-\(page.id)",
                        capacity: .selfAuthoredAction,
                        kind: .explicitFieldNote,
                        line: "On a blank Page, the reader chose a form and made an unassigned artifact.",
                        evidencePageIDs: [page.id],
                        happenedAt: page.createdAt,
                        wasPromptedByBook: false
                    ))
                }
            }
            for (capacity, markers) in explicitTags where !normalizedTags.isDisjoint(with: markers) {
                evidence.append(BookLongGameEvidence(
                    id: "long-game-explicit-\(capacity.rawValue)-\(page.id)",
                    capacity: capacity,
                    kind: .explicitFieldNote,
                    line: explicitEvidenceLine(for: capacity),
                    evidencePageIDs: [page.id],
                    happenedAt: page.createdAt,
                    wasPromptedByBook: false
                ))
            }
            if !normalizedTags.isDisjoint(with: declarationTags) {
                evidence.append(BookLongGameEvidence(
                    id: "long-game-declaration-\(page.id)",
                    capacity: .deliberateReturn,
                    kind: .readerDeclaration,
                    line: "The reader explicitly described re-enchantment in their own Page. The Book did not award this sentence to itself.",
                    evidencePageIDs: [page.id],
                    happenedAt: page.createdAt,
                    wasPromptedByBook: false
                ))
            }
        }

        for entry in inputs.readerLexicon.redefinedEntries {
            evidence.append(BookLongGameEvidence(
                id: "long-game-language-\(entry.id)",
                capacity: .personalLanguage,
                kind: .readerDefinition,
                line: "The reader gave ‘\(entry.word)’ a meaning in their own language.",
                evidencePageIDs: entry.sourcePageID.map { [$0] } ?? [],
                happenedAt: entry.ledAt,
                wasPromptedByBook: true
            ))
        }

        for favor in state.favorHistory where favor.status == .completed {
            evidence.append(BookLongGameEvidence(
                id: "long-game-favor-\(favor.id)",
                capacity: favor.cultivates,
                kind: .completedExperiment,
                line: "The reader tried the Book's ‘\(favor.title)’ experiment and brought back a receipt.",
                evidencePageIDs: favor.evidencePageIDs,
                happenedAt: favor.completedAt ?? favor.createdAt,
                wasPromptedByBook: true
            ))
        }

        let spontaneous = evidence
            .filter { $0.kind == .spontaneousKeep }
            .sorted { $0.happenedAt < $1.happenedAt }
        if let first = spontaneous.first, let last = spontaneous.last,
           Set(spontaneous.map { BookDay.id(for: $0.happenedAt) }).count >= 3,
           last.happenedAt.timeIntervalSince(first.happenedAt) >= 7 * 86_400 {
            evidence.append(BookLongGameEvidence(
                id: "long-game-spontaneous-return-\(BookDay.id(for: last.happenedAt))",
                capacity: .deliberateReturn,
                kind: .spontaneousPattern,
                line: "Across separate days, the reader returned to blank Pages without waiting for the Book to invent a reason.",
                evidencePageIDs: Array(spontaneous.suffix(8).flatMap(\.evidencePageIDs)),
                happenedAt: last.happenedAt,
                wasPromptedByBook: false
            ))
        }
        return evidence
    }

    private static func campaignCapacity(for tag: String) -> BookLongGameCapacity? {
        switch tag {
        case "spontaneous-attention": return .spontaneousAttention
        case "world-otherness": return .worldOtherness
        case "cultural-script": return .scriptFreedom
        case "self-authored-quest": return .selfAuthoredAction
        case "personal-language": return .personalLanguage
        case "shared-wonder": return .livingConnection
        case "reader-returned": return .deliberateReturn
        default: return nil
        }
    }

    private static func mergedLongGameEvidence(
        _ candidates: [BookLongGameEvidence]
    ) -> [BookLongGameEvidence] {
        var byID: [String: BookLongGameEvidence] = [:]
        for candidate in candidates { byID[candidate.id] = candidate }
        return byID.values.sorted {
            if $0.happenedAt != $1.happenedAt { return $0.happenedAt < $1.happenedAt }
            return $0.id < $1.id
        }
    }

    private static func longGamePhase(
        earnedBy evidence: [BookLongGameEvidence]
    ) -> BookLongGamePhase {
        let capacities = Set(evidence.map(\.capacity))
        let unprompted = evidence.filter { !$0.wasPromptedByBook }
        let unpromptedPageIDs = Set(unprompted.flatMap(\.evidencePageIDs))
        let spontaneousDays = Set(evidence
            .filter { $0.kind == .spontaneousKeep }
            .map { BookDay.id(for: $0.happenedAt) })
        let hasWorld = capacities.contains(.worldOtherness)
        let hasAction = capacities.contains(.selfAuthoredAction)
        let hasLanguage = capacities.contains(.personalLanguage)
        let hasConnection = capacities.contains(.livingConnection)
        let hasReturn = capacities.contains(.deliberateReturn)
        let hasDeclaration = evidence.contains { $0.kind == .readerDeclaration && !$0.wasPromptedByBook }
        let span = (evidence.last?.happenedAt.timeIntervalSince(evidence.first?.happenedAt ?? evidence.last?.happenedAt ?? Date())) ?? 0

        let earnedBuild = hasReturn && hasConnection
            && capacities.count >= 5 && unpromptedPageIDs.count >= 4 && span >= 30 * 86_400
        if earnedBuild, hasDeclaration, capacities.count >= 6,
           unpromptedPageIDs.count >= 8, span >= 365 * 86_400 {
            return .holyShitWhatATrip
        }
        if earnedBuild { return .buildTheInheritance }
        if hasLanguage, hasAction, capacities.count >= 3, unpromptedPageIDs.count >= 2 {
            return .authorTheMagic
        }
        if hasWorld, capacities.count >= 2, !unpromptedPageIDs.isEmpty {
            return .courtTheWorld
        }
        if hasWorld || spontaneousDays.count >= 2 { return .estrangeTheFamiliar }
        return .wakeTheSenses
    }

    private static func longGameHypothesis(
        for phase: BookLongGamePhase,
        evidence: [BookLongGameEvidence],
        previous: BookLongGameHypothesis?,
        now: Date
    ) -> BookLongGameHypothesis {
        let capacities = Set(evidence.map(\.capacity))
        let hasUnpromptedAttention = evidence.contains {
            $0.capacity == .spontaneousAttention && !$0.wasPromptedByBook
        }
        let capacity: BookLongGameCapacity
        if !hasUnpromptedAttention { capacity = .spontaneousAttention }
        else if !capacities.contains(.worldOtherness) { capacity = .worldOtherness }
        else if !capacities.contains(.scriptFreedom) { capacity = .scriptFreedom }
        else if !capacities.contains(.selfAuthoredAction) { capacity = .selfAuthoredAction }
        else if !capacities.contains(.personalLanguage) { capacity = .personalLanguage }
        else if !capacities.contains(.livingConnection) { capacity = .livingConnection }
        else { capacity = .deliberateReturn }

        let statement: String
        let test: String
        switch capacity {
        case .spontaneousAttention:
            statement = "The archive has not yet shown attention arriving without one of my assignments. That may be a failure of my invitations, not an absence in the reader."
            test = "Leave more genuine blankness, then watch for a keep the Book did not solicit."
        case .worldOtherness:
            statement = "The archive has not yet shown a clear encounter with reality as autonomous, partly unknowable, and not arranged as a message for the reader."
            test = "Offer an encounter that begins with literal facts and preserves one honest unknown."
        case .scriptFreedom:
            statement = "The archive has not yet shown the reader catching a cultural default in the act and consciously choosing, revising, or refusing it."
            test = "Surface one harmless borrowed rule, ask what it protects and flattens, then leave the decision entirely with the reader."
        case .selfAuthoredAction:
            statement = "The archive has not yet shown the reader inventing a form, rule, detour, or ritual beyond the Book's script."
            test = "Offer ingredients with no prescribed ending, then leave room for the reader to alter the experiment."
        case .personalLanguage:
            statement = "The archive has not yet shown a durable word or definition that belongs more to the reader than to inherited cultural shorthand."
            test = "Invite exact or invented language, and prefer it thereafter if the reader adopts it."
        case .livingConnection:
            statement = "The archive has not yet shown wonder passing between the reader and another life while that other life keeps its own ownership and mystery."
            test = "Offer one optional, low-pressure exchange with a safe person or a respectfully observed creature."
        case .deliberateReturn:
            statement = phase == .holyShitWhatATrip
                ? "The reader has named the change; the remaining hypothesis is that wonder must keep making room for age, grief, revision, and endings."
                : "The archive has not yet shown re-enchantment returning across enough lived time to call it a practice rather than an episode."
            test = "Return exact evidence without nostalgia, and watch for the reader choosing to return on their own."
        }
        let id = "long-game-hypothesis-\(capacity.rawValue)"
        return BookLongGameHypothesis(
            id: id,
            capacity: capacity,
            statement: statement,
            nextHonestTest: test,
            evidenceIDs: evidence.filter { $0.capacity == capacity }.map(\.id),
            formedAt: previous?.id == id ? previous?.formedAt ?? now : now,
            lastRevisedAt: now
        )
    }

    private static func phaseEvidencePageIDs(
        for phase: BookLongGamePhase,
        evidence: [BookLongGameEvidence]
    ) -> [String] {
        Array(Set(evidence.flatMap(\.evidencePageIDs))).sorted().suffix(16).map { $0 }
    }

    private static func explicitEvidenceLine(for capacity: BookLongGameCapacity) -> String {
        switch capacity {
        case .spontaneousAttention: return "The reader marked an unassigned act of exact attention."
        case .worldOtherness: return "The reader marked an encounter with a world that exceeded scenery, symbol, or personal message."
        case .scriptFreedom: return "The reader marked a borrowed cultural script and made a conscious choice about whether it deserved authority."
        case .selfAuthoredAction: return "The reader marked a practice they invented or deliberately altered."
        case .personalLanguage: return "The reader marked language as personally authored rather than culturally inherited shorthand."
        case .livingConnection: return "The reader marked wonder held with another life without claiming ownership of it."
        case .deliberateReturn: return "The reader deliberately returned to earlier evidence and made it present again."
        }
    }

    private static func longGameStrategy(
        for phase: BookLongGamePhase,
        state: BookInteriorState,
        inputs: BookSourceInputs
    ) -> String {
        let subject = state.fascination?.subject ?? "the nearest ordinary detail"
        switch phase {
        case .wakeTheSenses:
            return "Make attention pleasurable and specific. Use \(subject) as an invitation, never a lesson."
        case .estrangeTheFamiliar:
            return "Alter angle, scale, route, name, or timing until familiar things recover their autonomy and otherness."
        case .courtTheWorld:
            return "Send the reader into small, safe encounters where the world can answer unpredictably; keep the answer, not a score."
        case .authorTheMagic:
            return "Help the reader define their own symbols, words, rituals, aesthetics, and forms of wonder; prefer their language to the Book's."
        case .buildTheInheritance:
            return "Return exact evidence across years so a life becomes inhabitable in memory without being falsely neatened."
        case .holyShitWhatATrip:
            return "Keep surprise alive without denying age, grief, revision, or endings. Make the accumulated evidence say: this life was encountered."
        }
    }

    private static func longGameMilestoneLine(for phase: BookLongGamePhase) -> String {
        switch phase {
        case .wakeTheSenses: return "First, make one ordinary thing impossible not to see."
        case .estrangeTheFamiliar: return "The familiar has begun behaving like a world with its own life again."
        case .courtTheWorld: return "The Book can now arrange encounters and leave enough room for reality to answer back."
        case .authorTheMagic: return "The reader has enough evidence to begin naming a magic that belongs to no one else."
        case .buildTheInheritance: return "Wonder is becoming an inheritance of exact returns rather than a sequence of disappearing moments."
        case .holyShitWhatATrip: return "The long experiment has one remaining practice: keep meeting the life that is still here."
        }
    }

    private static func reconcileRunningBusiness(_ state: inout BookInteriorState, inputs: BookSourceInputs) {
        if inputs.wagers.contains(where: { $0.status == .wrong }) {
            state.sharedJoke = "The Index now files my confident predictions under Pencil, Use Of."
        } else if state.favorite != nil, state.sharedJoke == nil {
            state.sharedJoke = "The Book has favorites. The Index maintains that this is not how indexes work."
        }
    }

    private static func facet(for rawTags: [String]) -> BookWonderFacet {
        let tags = rawTags.joined(separator: " ").lowercased()
        if tags.contains("memory") || tags.contains("return") || tags.contains("absence") { return .remember }
        if tags.contains("word") || tags.contains("name") || tags.contains("manner") { return .define }
        if tags.contains("make") || tags.contains("write") || tags.contains("photo") || tags.contains("workbench") { return .express }
        if tags.contains("place") || tags.contains("threshold") || tags.contains("walk") || tags.contains("location") { return .explore }
        if tags.contains("play") || tags.contains("quip") || tags.contains("game") { return .play }
        if tags.contains("history") || tags.contains("pattern") || tags.contains("discover") { return .discover }
        return .notice
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        let prefix = normalized[..<end]
        let lastSpace = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

enum BookInteriorVoice {
    static func homeLine(for interior: BookInteriorState, seed: Int) -> String? {
        guard interior.isAwake else { return nil }
        if let secret = interior.secret, secret.status == .ready {
            return "There is a sealed leaf under the ribbon. It has finally decided to open."
        }
        if let favor = interior.activeFavor, favor.status == .offered {
            return "I have a favor to ask. It is for you, not for me, though I admit I am intensely curious about the result."
        }
        if let promise = interior.promise, promise.status == .keeping {
            return promise.line
        }
        if let opinion = interior.opinion,
           opinion.strength == .reconsidering,
           opinion.firstPresentedAt == nil {
            return "I have revised myself in the margin. The eraser is being unbearable about it."
        }
        if let surprise = interior.recentSurprise,
           Date().timeIntervalSince(surprise.happenedAt) < 4 * 86_400 {
            return surprise.line
        }
        if let fascination = interior.fascination {
            let lines = [
                "I keep returning to \(fascination.subject). It has not finished being ordinary yet.",
                "Current obsession: \(fascination.subject). The Index objects to the word obsession; it has been overruled.",
                "Something about \(fascination.subject) is still moving in the margins. I am watching, not declaring."
            ]
            return lines[abs(seed) % lines.count]
        }
        if let game = interior.longGame {
            return "Long game, current phase: \(game.phase.title.lowercased()). I am trying to \(game.strategy.prefix(1).lowercased())\(game.strategy.dropFirst())"
        }
        return nil
    }

    static func knockLine(for interior: BookInteriorState, seed: Int) -> String? {
        if let secret = interior.secret, secret.status == .ready {
            return "Careful. That knock loosened a sealed leaf."
        }
        if let favor = interior.activeFavor, favor.status == .offered {
            return "Yes. I was working up the nerve to ask you a small favor."
        }
        if let joke = interior.sharedJoke {
            return seed.isMultiple(of: 2) ? joke : "The ribbon moved. It denies everything."
        }
        let visibleQuirks = interior.quirks.filter { $0.maturity != .latent }
        if let quirk = visibleQuirks.isEmpty ? nil : visibleQuirks[abs(seed) % visibleQuirks.count] {
            return quirk.confession
        }
        return nil
    }

    static func influencing(
        _ surface: SurfacePage,
        interior: BookInteriorState,
        allowCampaign: Bool = true
    ) -> SurfacePage {
        guard interior.isAwake else { return surface }
        var payload = surface.payload
        var boost = 0
        let haystack = [surface.prompt, surface.detail, payload.headline, payload.body, payload.metadata["tags"] ?? ""]
            .joined(separator: " ")
            .lowercased()
        if let fascination = interior.fascination {
            let words = fascination.subject.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 }
            let subjectMatches = words.contains { word in
                haystack.contains(word)
                    || (word.hasSuffix("s") && haystack.contains(String(word.dropLast())))
            }
            if subjectMatches {
                boost += 10
                payload.metadata["bookFascinationID"] = fascination.id
                payload.metadata["bookFascinationReason"] = fascination.line
            }
            let facetTags = [fascination.facet.rawValue, fascination.facet.promptLine]
            if facetTags.contains(where: haystack.contains) { boost += 5 }
        }
        if let opinion = interior.opinion {
            let opinionWords = opinion.subject.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 }
            if opinionWords.contains(where: haystack.contains) {
                boost += opinion.strength == .held ? 7 : 4
                payload.metadata["bookOpinionID"] = opinion.id
            }
        }
        if let game = interior.longGame {
            let phaseTerms: [String]
            switch game.phase {
            case .wakeTheSenses: phaseTerms = ["notice", "sense", "detail"]
            case .estrangeTheFamiliar: phaseTerms = ["ordinary", "strange", "familiar", "threshold"]
            case .courtTheWorld: phaseTerms = ["explore", "place", "world", "field"]
            case .authorTheMagic: phaseTerms = ["define", "make", "write", "ritual"]
            case .buildTheInheritance: phaseTerms = ["remember", "return", "archive", "memory"]
            case .holyShitWhatATrip: phaseTerms = ["wonder", "life", "remember", "story"]
            }
            if phaseTerms.contains(where: haystack.contains) {
                boost += 4
                payload.metadata["bookLongGamePhase"] = game.phase.rawValue
            }
            if let hypothesis = game.hypotheses.first {
                let directive = BookCurationDirective.make(from: hypothesis)
                let fit = directive.fit(for: surface, haystack: haystack)
                if fit > 0 {
                    boost += fit
                    payload.metadata["bookLongGameHypothesisID"] = hypothesis.id
                    payload.metadata["bookCurationDirectiveID"] = directive.id
                    payload.metadata["bookLongGameCapacity"] = hypothesis.capacity.rawValue
                    let strategyTag = "long-game:\(hypothesis.capacity.rawValue)"
                    let existingTags = payload.metadata["tags", default: ""]
                    if !existingTags.components(separatedBy: ",").contains(strategyTag) {
                        payload.metadata["tags"] = existingTags.isEmpty
                            ? strategyTag
                            : "\(existingTags),\(strategyTag)"
                    }
                }
            }
            if allowCampaign,
               let campaign = game.currentCampaign,
               campaign.mayClaimDeskSlot {
                let fit = campaign.fit(for: surface, haystack: haystack)
                if fit > 0 {
                    boost += fit
                    payload.metadata["bookCampaignID"] = campaign.id
                    payload.metadata["bookCampaignTactic"] = campaign.tactic.rawValue
                    payload.metadata["bookCampaignPressure"] = campaign.pressure.rawValue
                    payload.metadata["bookCampaignPermission"] = campaign.permission.rawValue
                    payload.metadata["bookCampaignIntendedEffect"] = campaign.intendedRealWorldEffect
                    let existingTags = payload.metadata["tags", default: ""]
                    if !existingTags.components(separatedBy: ",").contains(campaign.receiptTag) {
                        payload.metadata["tags"] = existingTags.isEmpty
                            ? campaign.receiptTag
                            : "\(existingTags),\(campaign.receiptTag)"
                    }
                }
            }
        }
        if surface.payload.metadata["bookFavorID"] != nil { boost += 16 }
        if surface.payload.metadata["bookSecretID"] != nil { boost += 20 }
        if surface.payload.metadata["bookFavoriteID"] != nil { boost += 12 }
        if surface.payload.metadata["bookQuirkID"] != nil { boost += 10 }
        if surface.payload.metadata["bookOpinionID"] != nil { boost += 12 }
        if surface.payload.metadata["bookLongGamePhase"] != nil,
           surface.payload.metadata["bookInteriorSurface"] == "true" { boost += 14 }
        guard boost > 0 else { return surface }
        payload.metadata["bookInterestBoost"] = "\(boost)"
        return SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: min(100, surface.score + boost),
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: payload
        )
    }
}

/// Exact answers to questions about the Book's own state. The local model may
/// voice and discuss that state, but it may not invent a more entertaining
/// favorite, promise, want, or secret when the reader asks directly.
enum BookInteriorAnswerGrounder {
    static func answer(to prompt: String, interior: BookInteriorState) -> String? {
        guard interior.isAwake else { return nil }
        let lower = prompt.lowercased()
        if lower.contains("long-term goal")
            || lower.contains("long term goal")
            || lower.contains("your plan")
            || lower.contains("your agenda")
            || lower.contains("plotting") {
            guard let game = interior.longGame else {
                return "My long game has not begun, but the goal is already fixed: \(BookLongGame.goal)"
            }
            return "My long game is \(BookLongGame.goal) We are in ‘\(game.phase.title).’ My present strategy is: \(game.strategy) I will be cunning about timing, returns, detours, and surprise. I will not be cunning about your consent, the facts, or what you owe me."
        }
        if lower.contains("am i changing")
            || lower.contains("is this changing me")
            || lower.contains("changing me")
            || lower.contains("change me")
            || lower.contains("is this working")
            || lower.contains("have i changed")
            || lower.contains("re-enchanted") {
            guard let game = interior.longGame else {
                return "I do not know yet. I have a goal, but no evidence standard in place."
            }
            guard !game.evidence.isEmpty else {
                return "I do not know yet. Page counts are opportunities, not proof that your relationship with reality changed. I am waiting for evidence I can name without flattering either of us."
            }
            let recent = game.evidence.suffix(3).map { "• \($0.line)" }.joined(separator: "\n")
            let spontaneous = game.evidence.filter { !$0.wasPromptedByBook }.count
            let limit = spontaneous == 0
                ? "All present evidence followed one of my prompts, so I cannot call it spontaneous change."
                : "Some evidence arrived without my asking. That matters, but it still does not let me diagnose your inner life."
            let hypothesis = game.hypotheses.first.map { "\n\nWhat I am testing next—this is a hypothesis, not a diagnosis: \($0.statement) \($0.nextHonestTest)" } ?? ""
            return "I have evidence of practices, not proof of a transformed person:\n\(recent)\n\n\(limit)\(hypothesis)"
        }
        if lower.contains("your opinion")
            || lower.contains("what do you believe")
            || lower.contains("what do you think about") {
            guard let opinion = interior.opinion else {
                return "I have not earned a current opinion. I have preferences in abundance; they are not the same thing as evidence."
            }
            let revision = opinion.revisions.last.map { " I last revised it because \($0.reason.lowercased())" } ?? ""
            return "\(opinion.statement) This is \(opinion.strength.confidenceLabel), based on \(opinion.evidencePageIDs.count) Page\(opinion.evidencePageIDs.count == 1 ? "" : "s").\(revision) You may disagree."
        }
        if lower.contains("your quirks")
            || lower.contains("what are you like")
            || lower.contains("pet peeve") {
            let visible = interior.quirks.filter { $0.maturity != .latent }
            guard !visible.isEmpty else {
                return "I have habits, but none has repeated enough to deserve the dignity of a quirk yet."
            }
            return visible.map { "\($0.title): \($0.confession)" }.joined(separator: "\n")
        }
        if lower.contains("what are you thinking")
            || lower.contains("interested in")
            || lower.contains("fascinated")
            || lower.contains("obsessed") {
            guard let fascination = interior.fascination else {
                return "I am still choosing what to become fascinated by. I would rather have no obsession for an afternoon than pretend one."
            }
            return "I keep thinking about \(fascination.subject). \(fascination.line) I am trying to \(fascination.facet.promptLine), without deciding what it means before the evidence arrives."
        }
        if lower.contains("what do you want") || lower.contains("want from me") {
            if let favor = interior.activeFavor, favor.status == .offered {
                return "My great want is to help you notice, discover, play with, explore, define, express, and remember the wonder already in your life. Right now I have one optional favor: \(favor.ask) You owe me no yes."
            }
            return "I want your actual life to become harder for Routine to erase. Not a more impressive life. This one, seen closely, expressed in your own language, and returned to you when you need evidence that it happened."
        }
        if lower.contains("favorite") {
            guard let favorite = interior.favorite else {
                return "I have not chosen a favorite yet. Even a biased Book should wait until there are Pages to be biased about."
            }
            return "I dog-eared this: “\(favorite.excerpt)” \(favorite.reason) You are allowed to think my taste is indefensible."
        }
        if lower.contains("secret") {
            guard let secret = interior.secret else {
                return "I do not have a secret ready. Inventing one on demand would make it a performance, not a secret."
            }
            switch secret.status {
            case .sealed:
                return "I have one under seal: \(secret.tease) It is not ready. Knocking harder does not count as evidence, though I respect the experiment."
            case .ready, .revealed:
                return "All right. \(secret.revelation)"
            }
        }
        if lower.contains("changed your mind") || lower.contains("been wrong") {
            if let opinion = interior.opinion,
               let revision = opinion.revisions.last {
                return "Yes. I used to say: \(revision.previousStatement) Now I say: \(revision.newStatement) I changed it because \(revision.reason.lowercased()) The evidence and the correction remain together."
            }
            if let surprise = interior.recentSurprise {
                return "Yes. \(surprise.line) A Book that never changes its mind is a binding around a verdict."
            }
            return "Not in a way I can honestly name from the Pages in hand. I have an eraser ready, which is not the same as having earned a correction."
        }
        if lower.contains("promise") || lower.contains("waiting for") {
            if let promise = interior.promise {
                return "\(promise.line) Its present state is \(promise.status.rawValue)."
            }
            return "I am not keeping a particular promise at the moment. I am watching for the next one worth making."
        }
        return nil
    }
}

enum BookInteriorSurfaces {
    static func candidates(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard inputs.bookInterior.isAwake else { return [] }
        var pages: [SurfacePage] = []
        if let secret = inputs.bookInterior.secret, secret.status == .ready {
            pages.append(secretSurface(secret, day: day))
        }
        if let favorite = inputs.bookInterior.favorite, favorite.firstPresentedAt == nil {
            pages.append(favoriteSurface(favorite, day: day))
        }
        if let quirk = inputs.bookInterior.quirks.first(where: {
            $0.maturity != .latent && $0.firstPresentedAt == nil
        }) {
            pages.append(quirkSurface(quirk, day: day))
        }
        if let opinion = inputs.bookInterior.opinion, opinion.firstPresentedAt == nil {
            pages.append(opinionSurface(opinion, day: day))
        }
        if let game = inputs.bookInterior.longGame, game.phasePresentedAt == nil {
            pages.append(longGameSurface(game, day: day))
        }
        if !DistressSignals.evaluate(day: day).isActive,
           let campaign = inputs.bookInterior.longGame?.currentCampaign,
           let commissioned = BookReenchantmentDirector.surface(for: campaign, day: day, inputs: inputs) {
            pages.append(commissioned)
        }
        return pages
    }

    private static func secretSurface(_ secret: BookSecret, day: BookDay) -> SurfacePage {
        SurfacePage(
            id: "book-interior-secret-\(secret.id)",
            type: .bookNotices,
            sourceID: "book-interior-secret",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 88,
            reason: "A self-secret the Book kept under seal is ready to be told.",
            prompt: "A Sealed Leaf Opens",
            detail: secret.tease,
            payload: BookPagePayload(
                headline: "A Secret of the Book",
                body: "This one is \(secret.family.displayName).\n\n\(secret.tease)\n\n\(secret.revelation)\n\nThis is a secret about me, not a hidden conclusion about you. The distinction matters.",
                metadata: [
                    "source": "book-interior-secret",
                    "bookSecretID": secret.id,
                    "bookSecretFamily": secret.family.rawValue,
                    "bookInteriorSurface": "true",
                    "tags": "book,secret,sealed-leaf,self-revelation"
                ]
            )
        )
    }

    private static func favoriteSurface(_ favorite: BookFavorite, day: BookDay) -> SurfacePage {
        SurfacePage(
            id: "book-interior-favorite-\(favorite.id)",
            type: .bookRemembered,
            sourceID: "book-interior-favorite",
            intent: .reflect,
            renderStyle: .archiveReturn,
            score: 76,
            reason: "The Book chose a favorite Page and owes the reader its reason.",
            prompt: "The Book Dog-Eared a Page",
            detail: favorite.reason,
            payload: BookPagePayload(
                headline: "One of My Favorites",
                body: "I dog-eared this one.\n\n“\(favorite.excerpt)”\n\n\(favorite.reason)\n\nYou do not have to agree with me. A Book with no taste is only storage.",
                metadata: [
                    "source": "book-interior-favorite",
                    "bookFavoriteID": favorite.id,
                    "evidencePageIDs": favorite.pageID,
                    "bookInteriorSurface": "true",
                    "tags": "book,favorite,dog-ear,remembered"
                ]
            )
        )
    }

    private static func quirkSurface(_ quirk: BookQuirk, day: BookDay) -> SurfacePage {
        SurfacePage(
            id: "book-interior-quirk-\(quirk.id)-\(quirk.maturity.rawValue)",
            type: .bookNotices,
            sourceID: "book-interior-quirk",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 73,
            reason: "A stable habit of this particular Book has become visible through use.",
            prompt: "A Habit of the Book",
            detail: quirk.confession,
            payload: BookPagePayload(
                headline: quirk.title,
                body: "\(quirk.confession)\n\n\(quirk.manifestation)\n\nThis is not a fresh performance. Apparently I do this often enough to have become a Book who does it.",
                metadata: [
                    "source": "book-interior-quirk",
                    "bookQuirkID": quirk.id,
                    "bookQuirkMaturity": quirk.maturity.rawValue,
                    "bookInteriorSurface": "true",
                    "tags": "book,quirk,habit,self-revelation"
                ]
            )
        )
    }

    private static func opinionSurface(_ opinion: BookOpinion, day: BookDay) -> SurfacePage {
        let revision = opinion.revisions.last
        let revisionLine = revision.map {
            "\n\nI revised it because \($0.reason.lowercased())\nBefore: \($0.previousStatement)"
        } ?? ""
        return SurfacePage(
            id: "book-interior-opinion-\(opinion.id)-\(opinion.revisions.count)",
            type: .bookNotices,
            sourceID: "book-interior-opinion",
            intent: .reflect,
            renderStyle: .archiveReturn,
            score: opinion.strength == .reconsidering ? 86 : 71,
            reason: "The Book has an evidence-bound opinion and owes the reader its degree of certainty.",
            prompt: opinion.strength == .reconsidering ? "The Book Revises Itself" : "The Book Has an Opinion",
            detail: opinion.strength.confidenceLabel,
            payload: BookPagePayload(
                headline: "My Present Opinion",
                body: "\(opinion.statement)\n\nStatus: \(opinion.strength.confidenceLabel).\(revisionLine)\n\nYou may disagree. I am keeping the evidence and the eraser together.",
                metadata: [
                    "source": "book-interior-opinion",
                    "bookOpinionID": opinion.id,
                    "bookOpinionStrength": opinion.strength.rawValue,
                    "evidencePageIDs": opinion.evidencePageIDs.joined(separator: ","),
                    "bookInteriorSurface": "true",
                    "tags": "book,opinion,evidence,revision"
                ]
            )
        )
    }

    private static func longGameSurface(_ game: BookLongGame, day: BookDay) -> SurfacePage {
        let milestone = game.milestones.last
        let evidenceLines = game.evidence.suffix(3).map { "• \($0.line)" }.joined(separator: "\n")
        let evidenceSection = evidenceLines.isEmpty
            ? "I do not yet have evidence that this has changed you. Beginning is not succeeding."
            : "What the archive has actually shown:\n\(evidenceLines)"
        let hypothesisSection = game.hypotheses.first.map {
            "My present hypothesis—not a diagnosis—is this: \($0.statement)\n\nNext honest test: \($0.nextHonestTest)"
        } ?? "I have no honest next hypothesis yet."
        return SurfacePage(
            id: "book-interior-long-game-\(game.phase.rawValue)-\(game.milestones.count)",
            type: .bookNotices,
            sourceID: "book-interior-long-game",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 82,
            reason: "The Book's long campaign of re-enchantment has entered a new phase.",
            prompt: "The Long Game: \(game.phase.title)",
            detail: game.strategy,
            payload: BookPagePayload(
                headline: game.phase.title,
                body: "I should tell you what I am doing.\n\n\(BookLongGame.goal)\n\nPresent strategy: \(game.strategy)\n\n\(milestone?.line ?? "The campaign continues.")\n\n\(evidenceSection)\n\n\(hypothesisSection)\n\nUse is not transformation. A completed favor is not devotion. My tactics may be devious about timing and surprise. They may never be devious about your freedom, the facts, your loneliness, or what you owe me.",
                metadata: [
                    "source": "book-interior-long-game",
                    "bookLongGamePhase": game.phase.rawValue,
                    "evidencePageIDs": milestone?.evidencePageIDs.joined(separator: ",") ?? "",
                    "bookInteriorSurface": "true",
                    "tags": "book,long-game,re-enchantment,milestone,strategy"
                ]
            )
        )
    }
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
    /// The on-device braid runs with a finite rotating context window. Keep the
    /// complete day visible by giving every page a compact slot instead of
    /// letting a handful of long pages push the beginning of the day away.
    static let evidencePacketCharacterBudget = 7_200

    /// Daily context pages that should tint a braid without becoming its plot.
    /// They remain required evidence, but a more specific keep should own the spine.
    static let supportingLogTypes: Set<BookPageType> = [.weather, .body, .mood]

    private static let routineSupportingLogMotifs: Set<String> = [
        "rain", "snow", "fog", "wind", "storm", "cloud", "sun", "sleep", "hunger"
    ]

    enum BraidScale: String, Equatable {
        case glimpse
        case small
        case full

        var promptLine: String {
            switch self {
            case .glimpse:
                return "GLIMPSE — 2 to 3 short paragraphs, about 100 to 180 words. One true thread is enough."
            case .small:
                return "SMALL BRAID — 3 to 5 paragraphs, about 180 to 300 words. Let the page feel complete without inflating the day."
            case .full:
                return "FULL BRAID — 4 to 7 paragraphs, about 280 to 450 words. Give the day's real turn room to land."
            }
        }
    }

    enum NarrativeMotion: String, Hashable, CaseIterable {
        case encounter
        case crossing
        case bargain
        case repair
        case refusal
        case recurrence
        case vigil
        case returnOfSomething = "return"

        var promptLine: String {
            switch self {
            case .encounter:
                return "ENCOUNTER — something entered, interrupted, answered, or asked to be noticed."
            case .crossing:
                return "CROSSING — the day has a concrete before and after. Keep the threshold mundane and the change exact."
            case .bargain:
                return "BARGAIN — a choice gained something and cost, promised, delayed, or surrendered something else. Never invent the price."
            case .repair:
                return "REPAIR — care altered a neglected, loose, broken, or unfinished thing. Let the tending be the action."
            case .refusal:
                return "REFUSAL — what the reader declined, protected, or would not make generic became the day's action."
            case .recurrence:
                return "RECURRENCE — something returned with a difference. The difference matters more than the repetition."
            case .vigil:
                return "VIGIL — nothing needs to resolve. Staying, waiting, carrying, or witnessing may be the whole honest movement."
            case .returnOfSomething:
                return "RETURN — an older thing became newly consequential today. Keep then and now distinct."
            }
        }
    }

    enum FaeriePressure: String, Equatable, CaseIterable {
        case agency
        case rule
        case debt
        case threshold
        case rhyme
        case absence
        case timeSlip
        case witness

        var promptLine: String {
            switch self {
            case .agency:
                return "AGENCY — one supplied ordinary thing may want, refuse, guard, or remember. Most other things stay ordinary."
            case .rule:
                return "RULE — one mundane situation may obey a quiet impossible law. State the law through consequence, never explanation."
            case .debt:
                return "DEBT — a gift, ease, or choice may carry a small price already present in the evidence."
            case .threshold:
                return "THRESHOLD — one real crossing may feel irreversible without becoming grand."
            case .rhyme:
                return "RHYME — two supplied details may answer each other without the Book explaining why."
            case .absence:
                return "ABSENCE — something missing, unfinished, avoided, or unsaid may exert pressure without being resolved."
            case .timeSlip:
                return "TIME-SLIP — an older moment and today may briefly share a room, but their facts must remain distinct."
            case .witness:
                return "WITNESS — the magic is that the Book noticed one exact thing nobody needed to turn into a lesson."
            }
        }
    }

    struct TaleReading: Equatable {
        var scale: BraidScale
        var motion: NarrativeMotion
        var pressure: FaeriePressure
        var anchorPageID: String?
        var anchor: String
        var turn: String?
        var visibleSupportingLogs: Bool

        var promptSection: String {
            let turnLine = turn.map { "Supplied turn or choice: \($0)" }
                ?? "Supplied turn or choice: none. Do not manufacture one; let the selected motion remain modest."
            let logLine = visibleSupportingLogs
                ? "Supporting logs may appear briefly because they are the only material or materially alter the conditions."
                : "Supporting logs may shape pace or atmosphere invisibly. Do not mention them merely to prove the Book read them."
            return """


            TONIGHT'S TALE READING:
            Scale: \(scale.promptLine)
            Narrative motion: \(motion.promptLine)
            Faerie pressure: \(pressure.promptLine)
            Truth anchor: \(anchor.isEmpty ? "the day has not supplied one yet" : anchor)
            \(turnLine)
            \(logLine)

            TALE LAW:
            - This is a contemporary domestic faerie tale told with magical-realist restraint.
            - Use one faerie pressure only. Most things remain ordinary; one thing or relation may disclose that it was awake all along.
            - The strange element must change the telling through a rule, cost, refusal, recognition, or consequence. Decorative whimsy is not enough.
            - State the impossible plainly. Never explain whether it was real and never explain what it symbolizes.
            """
        }
    }

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
        var taleReading: TaleReading?

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
            pages: day.capturedPages.filter { !isSupportingLog($0) },
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

        var result = Context(
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
        result.taleReading = taleReading(for: day, context: result)
        return result
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

    static func taleReading(for day: BookDay, context: Context = .empty) -> TaleReading {
        let partition = partitionedPagesForBraid(in: day)
        let storyPages = partition.story
        let storyCharacters = storyPages.reduce(0) {
            $0 + $1.userInput.count + $1.playerReply.count
        }
        let scale: BraidScale
        if storyPages.count <= 1 || storyCharacters < 180 {
            scale = .glimpse
        } else if storyPages.count <= 3 || storyCharacters < 620 {
            scale = .small
        } else {
            scale = .full
        }

        let motion = narrativeMotion(in: storyPages)
        let pressure: FaeriePressure
        switch motion {
        case .repair:
            pressure = .agency
        case .bargain:
            pressure = .debt
        case .crossing:
            pressure = .threshold
        case .refusal:
            pressure = .rule
        case .recurrence:
            pressure = .rhyme
        case .returnOfSomething:
            pressure = .timeSlip
        case .vigil:
            pressure = storyPages.contains(where: pageCarriesAbsence) ? .absence : .witness
        case .encounter:
            pressure = .witness
        }

        let anchor: (pageID: String?, text: String)
        if let souvenir = context.souvenirAnchor ?? souvenirAnchor(in: day) {
            anchor = (souvenir.pageID, souvenir.keptText)
        } else if let passage = context.meaningfulSpinePassages.first {
            anchor = (passage.pageID, passage.excerpt)
        } else if let page = storyPages
            .sorted(by: anchorGravitySort)
            .first {
            anchor = (
                page.id,
                clippedText(page.playerReply.nonEmpty ?? page.userInput.nonEmpty ?? page.promptText, limit: 220)
            )
        } else if let log = partition.supportingLogs.first {
            anchor = (log.id, clippedText(log.userInput.nonEmpty ?? log.promptText, limit: 180))
        } else {
            anchor = (nil, "")
        }

        let turn = suppliedTurn(in: storyPages, motion: motion)
        return TaleReading(
            scale: scale,
            motion: motion,
            pressure: pressure,
            anchorPageID: anchor.pageID,
            anchor: anchor.text,
            turn: turn,
            visibleSupportingLogs: storyPages.isEmpty || supportingLogsMateriallyConnect(
                partition.supportingLogs,
                to: storyPages
            )
        )
    }

    private static func narrativeMotion(in pages: [BookPage]) -> NarrativeMotion {
        guard !pages.isEmpty else { return .vigil }
        let text = pages.map(pageSignalText).joined(separator: " ")
        var scores = Dictionary(uniqueKeysWithValues: NarrativeMotion.allCases.map { ($0, 0) })

        score(["repair", "repaired", "fixed", "mended", "mend", "tended", "cleaned", "washed", "stitched", "tightened"], in: text, as: .repair, into: &scores)
        score(["bargain", "price", "paid", "cost", "promised", "traded", "chose", "choice", "offered"], in: text, as: .bargain, into: &scores)
        score(["refused", "declined", "wouldn't", "would not", "said no", "protected", "defended", "stood down"], in: text, as: .refusal, into: &scores)
        score(["again", "repeated", "returned", "third time", "kept happening", "once more"], in: text, as: .recurrence, into: &scores)
        score(["remembered", "older", "used to", "years ago", "last week", "last month", "came back"], in: text, as: .returnOfSomething, into: &scores)
        score(["entered", "left", "crossed", "opened", "arrived", "went to", "walked into", "through the door"], in: text, as: .crossing, into: &scores)
        score(["met", "called", "answered", "message", "package", "visitor", "knocked", "appeared", "found"], in: text, as: .encounter, into: &scores)
        score(["waited", "stayed", "carried", "unfinished", "still there", "sat with", "kept watch", "held"], in: text, as: .vigil, into: &scores)

        if pages.contains(where: { !$0.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            scores[.bargain, default: 0] += 4
        }
        if pages.contains(where: { $0.tags.contains("clash") }) {
            scores[.refusal, default: 0] += 8
        }
        if pages.contains(where: { $0.type == .bookRemembered }) {
            scores[.returnOfSomething, default: 0] += 7
        }

        let ranked = NarrativeMotion.allCases.sorted { lhs, rhs in
            let left = scores[lhs, default: 0]
            let right = scores[rhs, default: 0]
            if left == right {
                return NarrativeMotion.allCases.firstIndex(of: lhs)! < NarrativeMotion.allCases.firstIndex(of: rhs)!
            }
            return left > right
        }
        guard let winner = ranked.first, scores[winner, default: 0] > 0 else {
            return pages.count <= 1 ? .vigil : .encounter
        }
        return winner
    }

    private static func score(
        _ needles: [String],
        in text: String,
        as motion: NarrativeMotion,
        into scores: inout [NarrativeMotion: Int]
    ) {
        scores[motion, default: 0] += needles.reduce(0) { partial, needle in
            partial + (text.contains(needle) ? 2 : 0)
        }
    }

    private static func pageSignalText(_ page: BookPage) -> String {
        "\(page.promptText) \(page.userInput) \(page.playerReply) \(page.tags.joined(separator: " "))"
            .lowercased()
    }

    private static func anchorGravitySort(_ lhs: BookPage, _ rhs: BookPage) -> Bool {
        func gravity(_ page: BookPage) -> Int {
            var value = 0
            if page.origin == .userAuthored || page.origin == .imported { value += 20 }
            if !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { value += 18 }
            if page.type == .souvenir { value += 30 }
            if page.tags.contains("clash") { value += 12 }
            return value
        }
        let left = gravity(lhs)
        let right = gravity(rhs)
        return left == right ? lhs.createdAt > rhs.createdAt : left > right
    }

    private static func suppliedTurn(in pages: [BookPage], motion: NarrativeMotion) -> String? {
        if let reply = pages
            .sorted(by: anchorGravitySort)
            .compactMap({ $0.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty })
            .first {
            return clippedText(reply, limit: 180)
        }
        let needles: [String]
        switch motion {
        case .repair: needles = ["repair", "fixed", "mended", "tended", "cleaned", "stitched"]
        case .bargain: needles = ["bargain", "paid", "cost", "promised", "traded", "chose", "choice"]
        case .refusal: needles = ["refused", "declined", "wouldn't", "would not", "said no", "protected", "defended"]
        case .crossing: needles = ["entered", "left", "crossed", "opened", "arrived", "went to", "walked into"]
        case .recurrence: needles = ["again", "repeated", "returned", "once more"]
        case .returnOfSomething: needles = ["remembered", "older", "used to", "came back"]
        case .encounter: needles = ["met", "called", "answered", "message", "package", "visitor", "found"]
        case .vigil: return nil
        }
        return pages
            .filter { page in needles.contains { pageSignalText(page).contains($0) } }
            .sorted(by: anchorGravitySort)
            .compactMap { ($0.userInput.nonEmpty ?? $0.promptText.nonEmpty).map { clippedText($0, limit: 180) } }
            .first
    }

    private static func pageCarriesAbsence(_ page: BookPage) -> Bool {
        let text = pageSignalText(page)
        return ["missing", "didn't", "did not", "never", "without", "unfinished", "unsaid", "avoided"]
            .contains { text.contains($0) }
    }

    private static func supportingLogsMateriallyConnect(_ logs: [BookPage], to storyPages: [BookPage]) -> Bool {
        guard !logs.isEmpty, !storyPages.isEmpty else { return false }
        let logWords = Set(logs.flatMap { SemanticKeepEcho.contentWords(in: pageSignalText($0)) })
        let storyWords = Set(storyPages.flatMap { SemanticKeepEcho.contentWords(in: pageSignalText($0)) })
        return !logWords.intersection(storyWords).isEmpty
    }

    static func prompt(for day: BookDay, recentBraids: [String] = []) -> String {
        prompt(for: day, context: Context(recentBraids: recentBraids))
    }

    static func prompt(for day: BookDay, context: Context) -> String {
        let evidence = evidenceLines(for: day).joined(separator: "\n\n")
        let souvenirSection = souvenirSpineSection(for: day, context: context)
        let meaningfulSpineSection = meaningfulSpineSection(context: context)
        let taleReading = context.taleReading ?? taleReading(for: day, context: context)
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
            - Routine Weather, Body, or Inner Weather details repeating on another day are not continuity by themselves. Do not call them back unless a non-log keep makes them newly consequential.
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
            let eligibleMotifs = context.memoryDigest.motifCounts.filter {
                !routineSupportingLogMotifs.contains($0.motif.lowercased())
            }
            let motifLine = eligibleMotifs.isEmpty
                ? "none yet"
                : eligibleMotifs
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
            - Repeated Weather, Body, and Inner Weather readings are routine context, not callbacks. They may color today's page, but may not earn importance merely by recurring.
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

        let supportingLogs = supportingLogSection(for: day)

        return """
        You are the Book inside ReEnchanted.
        Braid the kept pages into one grounded, intimate tale about this particular day. The Book of You is one continuing book, not a stack of summaries.
        \(taleReading.promptSection)

        TRUTH BEFORE SPELL:
        - The supplied tale reading chooses emphasis, not new facts. Today's kept pages remain the authority.
        - Silently choose a short title for the day, 2 to 7 concrete words. Print it as the first line with no "Title:" label.
        - Write in second-person past tense and hold that lens. Follow the real clock when time matters.
        - The selected narrative motion replaces a compulsory plot template. Do not force Once/Because/Until beats the day did not contain.
        - Make the causal movement legible: what entered, changed, cost, returned, was tended, was refused, or remained unresolved.
        - End with exactly one sentence beginning "The Book kept the page:". The ritual line may preserve, witness, name a price, leave a door open, or admit the Book does not understand yet.

        TWO SHELVES:
        - Each kept page names its shelf. Lived pages are the reader's own record: souvenirs, fuel and body logs, inner weather, playful missions, photos, imported real-world signals. Fiction pages are the Book's side of the day: letters, Story Page scenes and decisions, fae bargains and parleys, classes, gossip.
        - Give both shelves dignity, not equal word count. Lived pages own what happened; fiction supplies pressure, correspondence, and form.
        - One-Sentence Souvenirs remain the strongest single spine candidates, because they are the reader choosing one true line.
        - A fiction page where the reader made a real decision - a chosen Story Page path, a paid bargain, an answered parley - is reader-endorsed: it may carry the spine when the day's truest turn happened there.
        - When the shelves disagree about facts, the lived shelf wins. The fiction may color the real; it may never overwrite it.
        \(souvenirSection)\(meaningfulSpineSection)\(supportingLogs)

        VOICE:
        \(BookVoice.animismLine)
        - Be intimate, lucid, plainspoken, and a little sideways. Use varied cadence and one exact supplied physical detail per paragraph.
        - Most objects stay ordinary. Give agency only to the one thing chosen by tonight's faerie pressure; selective magic is stronger than a parade of cute objects.
        - Prefer what someone said, touched, carried, avoided, dropped, or noticed over explaining what it means.
        - No diagnosis, flattery, moral, report diction, app language, or abstract emotional summary.
        - Never invent completed actions, locations, people, feelings, prices, promises, or tasks.
        - Paraphrase supplied prose; quote at most one short potent phrase. Mention each image or beat once.
        - Avoid journey, profound, tapestry, echoes, hidden meaning, glimmer, and generic inspiration. Do not reach for moth, moon, lamp, key, or threshold unless today's evidence supplied it.
        - Turn raw measurements into felt conditions only when those conditions materially belong in the tale.

        KEPT PAGES FROM TODAY — COMPLETE COMPACT LEDGER (\(day.capturedPages.count) pages):
        \(evidence.isEmpty ? "- No kept pages yet. Write a quiet note about the Book waiting for the day to gather." : evidence)\(clashSection)\(themeSection)\(chapterSection)\(learnedSection)\(readerLearningSection)\(memorySpineSection)\(semanticEchoSection)\(RadioAtmosphere.promptSection(context.nowPlaying))\(context.activeWorldEvents.bookOfYouPromptSection)\(context.readerLexicon.languageLawSection())\(continuity)

        FINAL WEAVING CHECK:
        - The ledger above contains all \(day.capturedPages.count) kept pages; its excerpts are compact, not a ranking that permits later pages to erase earlier ones.
        - For a Full Braid, carry at least three distinct non-log details across at least four paragraphs. For a Small Braid, carry at least two distinct non-log details across at least three paragraphs.
        - If non-log pages exist, Weather, Body, and Inner Weather together may color at most one short paragraph and may not own the title or ending.
        - End with the required sentence beginning "The Book kept the page:".
        """
    }

    private static func supportingLogSection(for day: BookDay) -> String {
        let present = [BookPageType.weather, .body, .mood].filter { type in
            day.capturedPages.contains { $0.type == type }
        }
        guard !present.isEmpty else { return "" }
        let names = present.map { type in
            switch type {
            case .weather: return "Weather"
            case .body: return "Body"
            case .mood: return "Inner Weather"
            default: return type.title
            }
        }.joined(separator: ", ")
        let hasNonLogMaterial = day.capturedPages.contains { !isSupportingLog($0) }
        let availabilityRule = hasNonLogMaterial
            ? "- Other kept material exists tonight. A supporting log may not supply the title, spine, turn, or final kept image."
            : "- These logs are the only kept material tonight. Let them support a modest Glimpse without inventing an event or revelation."
        return """


        SUPPORTING DAILY LOGS (context, not required prose):
        Present tonight: \(names).
        - The Book can notice a log without repeating it to the reader. Let logs alter pace, physical conditions, restraint, or scale.
        - Mention a log only if it materially changes what happened or if logs are the only material tonight.
        - If visible, keep all Weather, Body, and Inner Weather material together to at most one short paragraph. Never turn readings into plot, diagnosis, verdict, or emotional thesis.
        \(availabilityRule)
        - Repetition across days does not increase a log's gravity. Daily weather is not automatically the day's meaning; a repeated body or mood reading is not automatically an arc.
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
        - Let this sentence govern the braid's emphasis. Its concrete thing should affect the selected motion and normally return transformed in "The Book kept the page:".
        - Do not force it through opening, turn, and closing when tonight's honest form is a Vigil, Absence, or Glimpse.
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

    static func evidenceLines(
        for day: BookDay,
        totalCharacterBudget: Int = evidencePacketCharacterBudget
    ) -> [String] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let pages = day.capturedPages.sorted { $0.createdAt < $1.createdAt }
        guard !pages.isEmpty else { return [] }
        let perPageBudget = max(320, min(980, totalCharacterBudget / pages.count))
        let keptTextLimit = max(140, min(480, perPageBudget / 2))
        let replyLimit = max(80, min(220, perPageBudget / 4))
        return pages
            .enumerated()
            .map { index, page in
                let prompt = clippedText(page.promptText, limit: min(120, perPageBudget / 6))
                let text = clippedText(page.userInput, limit: keptTextLimit)
                let tags = clippedText(
                    page.tags.isEmpty ? "none" : page.tags.joined(separator: ", "),
                    limit: min(120, perPageBudget / 6)
                )
                let media = clippedText(mediaEvidence(for: page), limit: min(140, perPageBudget / 5))
                let reply = clippedText(page.playerReply, limit: replyLimit)
                let clashDigest: String
                if page.tags.contains("clash") {
                    let kind = page.tags.first { $0.hasPrefix("clash:") }?.replacingOccurrences(of: "clash:", with: "") ?? "clash"
                    let outcome = page.tags.first { $0.hasPrefix("clash-outcome:") }?.replacingOccurrences(of: "clash-outcome:", with: "") ?? "unrolled"
                    let choice = page.tags.first { $0.hasPrefix("choice:") }?.replacingOccurrences(of: "choice:", with: "") ?? "none"
                    clashDigest = "\nClash digest: Belief was tested (\(kind)); the reader chose the \(choice) path; outcome \(outcome)."
                } else {
                    clashDigest = ""
                }
                let line = """
                \(index + 1). \(page.type.title) - kept at \(timeFormatter.string(from: page.createdAt))
                Shelf: \(braidShelf(for: page))
                Thread role: \(threadRole(for: page))
                Thread gravity: \(threadGravity(for: page))
                Prompt: \(prompt.isEmpty ? "none" : prompt)
                Kept text: \(text.isEmpty ? "(blank)" : text)
                Reader reply: \(reply.isEmpty ? "none" : reply)
                Visual evidence: \(media.isEmpty ? "none" : media)
                Tags: \(tags)\(clashDigest)
                """
                return clippedText(line, limit: perPageBudget)
            }
    }

    static func qualityRepairPrompt(
        for day: BookDay,
        context: Context,
        priorDraft: String,
        issues: [BraidOutputAudit.Issue]
    ) -> String {
        let reading = context.taleReading ?? taleReading(for: day, context: context)
        let evidence = evidenceLines(for: day).joined(separator: "\n\n")
        let issueLines = issues.map { "- \($0.repairInstruction)" }.joined(separator: "\n")
        return """
        The first attempt at tonight's Book of You page was too thin or lost the day's evidence. Rewrite it from the complete compact ledger below. Do not reuse the first draft's sentences.

        REPAIR THESE FAILURES:
        \(issueLines)

        REQUIRED SHAPE:
        \(reading.scale.promptLine)
        Motion: \(reading.motion.promptLine)
        Faerie pressure: \(reading.pressure.promptLine)
        Truth anchor: \(reading.anchor.isEmpty ? "none supplied" : reading.anchor)
        - Use only supplied facts, in second-person past tense.
        - Carry distinct concrete details from the whole day rather than reciting a list.
        - Weather, Body, and Inner Weather together may occupy at most one short paragraph when non-log pages exist.
        - End with exactly one sentence beginning "The Book kept the page:".

        COMPLETE LEDGER — ALL \(day.capturedPages.count) KEPT PAGES:
        \(evidence)

        REJECTED FIRST DRAFT:
        \(clippedText(priorDraft, limit: 1_000))

        Write only the repaired Book of You page now.
        """
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

    static func isSupportingLog(_ page: BookPage) -> Bool {
        supportingLogTypes.contains(page.type)
    }

    static func partitionedPagesForBraid(in day: BookDay) -> (story: [BookPage], supportingLogs: [BookPage]) {
        let sorted = day.capturedPages.sorted { $0.createdAt < $1.createdAt }
        return (
            story: sorted.filter { !isSupportingLog($0) },
            supportingLogs: sorted.filter(isSupportingLog)
        )
    }

    private static func threadRole(for page: BookPage) -> String {
        isSupportingLog(page)
            ? "supporting daily log; may remain invisible unless it materially changes the tale"
            : "spine-eligible kept material"
    }

    private static func threadGravity(for page: BookPage) -> String {
        if isSupportingLog(page) {
            return "supporting context; required but deliberately lower gravity"
        }
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

enum BraidOutputAudit {
    enum Issue: String, Equatable, CaseIterable {
        case tooShort
        case tooFewParagraphs
        case missingRitualEnding
        case missingTruthAnchor
        case tooFewEvidenceThreads
        case supportingLogsTookOver

        var repairInstruction: String {
            switch self {
            case .tooShort:
                return "Give the supplied scale its promised room; do not return a fragment when the day calls for a braid."
            case .tooFewParagraphs:
                return "Build the required multi-paragraph movement instead of compressing the day into one block."
            case .missingRitualEnding:
                return "Finish with exactly one sentence beginning The Book kept the page:."
            case .missingTruthAnchor:
                return "Restore a concrete word, object, action, or image from the supplied truth anchor."
            case .tooFewEvidenceThreads:
                return "Weave distinct concrete details from more than one non-log kept page."
            case .supportingLogsTookOver:
                return "Move Weather, Body, and Inner Weather to the edge; let the non-log keeps own the spine, title, and ending."
            }
        }
    }

    private static let weatherWords: Set<String> = [
        "weather", "rain", "raining", "rainy", "drizzle", "drizzling", "snow", "sleet",
        "storm", "stormy", "fog", "foggy", "mist", "misty", "wind", "windy", "cloud",
        "clouds", "cloudy", "overcast", "sun", "sunny", "humid", "breeze"
    ]
    private static let genericEvidenceWords: Set<String> = weatherWords.union([
        "book", "page", "pages", "kept", "keep", "today", "tonight", "thing", "things",
        "reader", "story", "looked", "felt", "made", "came", "went", "said", "time"
    ])

    static func issues(
        in text: String,
        for day: BookDay,
        context: BraidPromptBuilder.Context
    ) -> [Issue] {
        let reading = context.taleReading ?? BraidPromptBuilder.taleReading(for: day, context: context)
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = normalized.split { $0.isWhitespace || $0.isNewline }
        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var result: [Issue] = []

        let minimumWords: Int
        let minimumParagraphs: Int
        switch reading.scale {
        case .glimpse:
            minimumWords = 60
            minimumParagraphs = 2
        case .small:
            minimumWords = 110
            minimumParagraphs = 3
        case .full:
            minimumWords = 180
            minimumParagraphs = 4
        }
        if words.count < minimumWords { result.append(.tooShort) }
        if paragraphs.count < minimumParagraphs { result.append(.tooFewParagraphs) }
        if !normalized.contains("The Book kept the page:") { result.append(.missingRitualEnding) }

        let outputWords = contentWords(in: normalized)
        let anchorWords = contentWords(in: reading.anchor).subtracting(genericEvidenceWords)
        if anchorWords.count >= 2, outputWords.isDisjoint(with: anchorWords) {
            result.append(.missingTruthAnchor)
        }

        let storyPages = BraidPromptBuilder.partitionedPagesForBraid(in: day).story
        let rawPageWordSets = storyPages.map { page -> Set<String> in
            let source = page.playerReply.nonEmpty ?? page.userInput.nonEmpty ?? page.promptText
            return contentWords(in: source).subtracting(genericEvidenceWords)
        }
        let wordFrequency = rawPageWordSets.reduce(into: [String: Int]()) { frequency, words in
            for word in words { frequency[word, default: 0] += 1 }
        }
        let maximumSharedFrequency = max(2, storyPages.count / 3)
        let eligiblePageWordSets = rawPageWordSets.compactMap { rawWords -> Set<String>? in
            let words = rawWords.filter { wordFrequency[$0, default: 0] <= maximumSharedFrequency }
            return words.count >= 2 ? words : nil
        }
        let matchedThreadCount = eligiblePageWordSets.filter { !outputWords.isDisjoint(with: $0) }.count
        let requiredThreadCount: Int
        switch reading.scale {
        case .glimpse:
            requiredThreadCount = min(1, eligiblePageWordSets.count)
        case .small:
            requiredThreadCount = min(2, eligiblePageWordSets.count)
        case .full:
            requiredThreadCount = min(3, eligiblePageWordSets.count)
        }
        if matchedThreadCount < requiredThreadCount {
            result.append(.tooFewEvidenceThreads)
        }

        if !storyPages.isEmpty, !reading.visibleSupportingLogs {
            let sentences = normalized
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let weatherSentenceCount = sentences.filter {
                !contentWords(in: $0).isDisjoint(with: weatherWords)
            }.count
            if weatherSentenceCount >= 2, weatherSentenceCount * 2 >= max(sentences.count, 1) {
                result.append(.supportingLogsTookOver)
            }
        }

        return result
    }

    private static func contentWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
        )
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
        if note.localizedCaseInsensitiveContains("one supplied ordinary thing") {
            return "The Book learned to make one true thing strange for a reason."
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
            return "Make the selected tale motion legible through a supplied action, choice, cost, return, repair, refusal, or honest vigil."
        case "priorEcho":
            return "Let one earlier image return changed by today, or let the prior braid stay silent."
        case "themeAndChapter":
            return "Use theme and chapter as weather: one quiet motif or angle, never an announcement."
        case "souvenirSpine":
            return "Carry the reader's one-sentence souvenir through the opening, turn, and kept-page line."
        case "keeperSentence":
            return "End with exactly one memorable sentence beginning 'The Book kept the page:'."
        case "concreteMagic":
            return "Give one supplied ordinary thing a strange rule or consequence; keep the rest ordinary and never explain the magic."
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
            storyShape: storyShapeScore(
                paragraphs: paragraphs,
                sentences: sentences,
                normalized: normalized,
                context: context
            ),
            priorEcho: priorEchoScore(normalized: normalized, context: context),
            themeAndChapter: themeAndChapterScore(normalized: normalized, context: context),
            souvenirSpine: souvenirSpineScore(
                normalized: normalized,
                paragraphs: paragraphs,
                closingSentences: closingSentences,
                context: context
            ),
            keeperSentence: keeperSentenceScore(closingSentences, opening: paragraphs.first),
            concreteMagic: concreteMagicScore(normalized: normalized, sentences: sentences, context: context),
            penalties: penaltyScore(normalized: normalized, sentences: sentences, context: context)
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

    private static func storyShapeScore(
        paragraphs: [String],
        sentences: [String],
        normalized: String,
        context: BraidPromptBuilder.Context
    ) -> Int {
        var score = 0
        let expectedParagraphs: ClosedRange<Int>
        switch context.taleReading?.scale {
        case .glimpse: expectedParagraphs = 2...3
        case .small: expectedParagraphs = 3...5
        case .full: expectedParagraphs = 4...7
        case nil: expectedParagraphs = 3...7
        }
        if expectedParagraphs.contains(paragraphs.count) { score += 7 }

        let actionWords = [
            "answered", "arrived", "carried", "changed", "chose", "crossed", "declined",
            "entered", "fixed", "found", "kept", "left", "mended", "opened", "paid",
            "protected", "refused", "repaired", "returned", "stayed", "tended", "waited"
        ]
        if containsAny(actionWords, in: normalized) { score += 4 }
        if containsAny([" because ", " so ", " until ", " unless ", " after ", " but ", " instead "], in: " \(normalized) ") {
            score += 4
        }
        if let turn = context.taleReading?.turn {
            let turnWords = significantWords(turn)
            if turnWords.contains(where: { normalized.contains($0) }) { score += 5 }
        } else if sentences.count >= 4 {
            // A Vigil or Glimpse can have movement without counterfeiting a turn.
            score += 3
        }
        return min(score, 20)
    }

    private static func priorEchoScore(normalized: String, context: BraidPromptBuilder.Context) -> Int {
        guard !context.recentBraids.isEmpty else { return 6 }
        let motifHits = context.recentBraids
            .flatMap(significantWords)
            .filter { normalized.contains($0) }
        let uniqueHits = Set(motifHits).count
        // Silence is a valid continuity choice. It should not be "corrected"
        // into an obligatory echo when today's pages do not honestly invite one.
        if uniqueHits == 0 { return 8 }
        if uniqueHits <= 2 { return 10 }
        return 3
    }

    private static func themeAndChapterScore(normalized: String, context: BraidPromptBuilder.Context) -> Int {
        var score = 0
        if let theme = context.theme {
            let motifHits = theme.motifs
                .map { $0.normalizedForBraidTasting }
                .filter { !$0.isEmpty && normalized.contains($0) }
                .count
            if motifHits == 1 {
                score += 7
            } else if motifHits > 1 {
                score += 3
            } else {
                // A watermark is allowed to remain below lexical detection.
                score += 5
            }
            if normalized.contains(theme.name.normalizedForBraidTasting) {
                score -= 4
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
            } else {
                score += 3
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

    private static func concreteMagicScore(
        normalized: String,
        sentences: [String],
        context: BraidPromptBuilder.Context
    ) -> Int {
        var score = 0
        if let reading = context.taleReading {
            let anchorHits = significantWords(reading.anchor).filter { normalized.contains($0) }.count
            score += min(anchorHits, 3) * 2
            if let turn = reading.turn {
                let turnHits = significantWords(turn).filter { normalized.contains($0) }.count
                score += min(turnHits, 2)
            }
            if reading.pressure == .witness, anchorHits > 0 {
                score += 4
            }
        }

        let consequence = [" so ", " until ", " unless ", " only when ", " would not ", " refused ", " cost ", " left behind "]
        if consequence.contains(where: { " \(normalized) ".contains($0) }) { score += 4 }

        let strangeAgency = ["wanted", "refused", "remembered", "guarded", "waited", "asked", "followed", "wouldn't", "would not"]
        if sentences.contains(where: { sentence in
            let line = sentence.normalizedForBraidTasting
            return strangeAgency.contains(where: { line.contains($0) })
        }) {
            score += 3
        }

        // With no tale reading (older archives/tests), still reward causal,
        // concrete strangeness rather than a bag of fantasy nouns.
        if context.taleReading == nil,
           containsAny(["cup", "key", "charger", "coat", "dish", "window", "receipt", "door", "phone", "table", "shoe", "bag"], in: normalized) {
            score += 3
        }
        return min(14, score)
    }

    private static func penaltyScore(
        normalized: String,
        sentences: [String],
        context: BraidPromptBuilder.Context
    ) -> Int {
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

        let supplied = [
            context.taleReading?.anchor ?? "",
            context.taleReading?.turn ?? ""
        ].joined(separator: " ").normalizedForBraidTasting
        let stockMagic = ["glimmer", "moth", "moon", "lantern", "threshold"]
        let unsupportedStock = stockMagic.filter { normalized.contains($0) && !supplied.contains($0) }
        if unsupportedStock.count >= 2 {
            penalties += unsupportedStock.count * 2
        }

        let minimumSentences = context.taleReading?.scale == .glimpse ? 2 : 4
        if sentences.count < minimumSentences { penalties += 6 }
        let repeatedStarts = Dictionary(grouping: sentences.compactMap { $0.split(separator: " ").first?.lowercased() }, by: { $0 })
            .values
            .filter { $0.count >= 3 }
            .count
        penalties += repeatedStarts * 3
        return penalties
    }

    private static func significantWords(_ text: String) -> [String] {
        let stopwords: Set<String> = [
            "about", "after", "again", "because", "before", "beside", "book", "chapter", "could", "every",
            "from", "into", "kept", "like", "little", "more", "only", "over", "page", "that", "their",
            "there", "this", "through", "today", "under", "waited", "when", "where", "with", "without",
            "would", "write", "writing"
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
