import Foundation

enum TarotArcana: String, Codable, Equatable {
    case major
    case minor
}

enum TarotSuit: String, Codable, CaseIterable, Equatable {
    case cups
    case pentacles
    case swords
    case wands

    var title: String { rawValue.capitalized }

    var field: String {
        switch self {
        case .cups: return "feeling and relationship"
        case .pentacles: return "body, home, and work"
        case .swords: return "thought and truth"
        case .wands: return "desire and making"
        }
    }
}

enum TarotRank: String, Codable, CaseIterable, Equatable {
    case ace, two, three, four, five, six, seven, eight, nine, ten
    case page, knight, queen, king

    var title: String { rawValue.capitalized }

    var assetSuffix: String {
        switch self {
        case .ace: return "Ace"
        case .two: return "02"
        case .three: return "03"
        case .four: return "04"
        case .five: return "05"
        case .six: return "06"
        case .seven: return "07"
        case .eight: return "08"
        case .nine: return "09"
        case .ten: return "10"
        case .page: return "Page"
        case .knight: return "Knight"
        case .queen: return "Queen"
        case .king: return "King"
        }
    }
}

struct TarotCardDefinition: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assetName: String
    var arcana: TarotArcana
    var suit: TarotSuit?
    var rank: TarotRank?
    var keywords: [String]
    var lightMeaning: String
    var shadowMeaning: String
}

enum TarotSpread: String, Codable, CaseIterable, Equatable {
    case oneCard
    case rootWeatherDoor

    var title: String {
        switch self {
        case .oneCard: return "One card"
        case .rootWeatherDoor: return "Root · Weather · Door"
        }
    }

    var subtitle: String {
        switch self {
        case .oneCard: return "One image to carry into the day."
        case .rootWeatherDoor: return "What’s beneath · what surrounds · what may open."
        }
    }

    var positions: [TarotSpreadPosition] {
        switch self {
        case .oneCard: return [.single]
        case .rootWeatherDoor: return [.root, .weather, .door]
        }
    }
}

enum TarotSpreadPosition: String, Codable, Equatable {
    case single, root, weather, door

    var title: String {
        switch self {
        case .single: return "The card"
        case .root: return "Root"
        case .weather: return "Weather"
        case .door: return "Door"
        }
    }

    var prompt: String {
        switch self {
        case .single: return "What keeps catching your eye?"
        case .root: return "What is underneath this?"
        case .weather: return "What atmosphere are you moving through?"
        case .door: return "What wants a small opening?"
        }
    }
}

struct TarotDrawnCard: Identifiable, Codable, Equatable {
    var id: String { "\(position.rawValue)-\(cardID)" }
    var cardID: String
    var position: TarotSpreadPosition
    var isReversed: Bool
}

struct TarotReadingSourceReceipt: Identifiable, Codable, Equatable {
    var id: String { documentID }
    var documentID: String
    var referenceID: String
    var kind: String
    var title: String
    var excerpt: String
    var dateLabel: String
    var relevance: Int
}

struct TarotReadingEdgeReceipt: Identifiable, Codable, Equatable {
    var id: String { "\(fromID)|\(kind)|\(toID)" }
    var fromID: String
    var toID: String
    var kind: String
    var weight: Int
}

struct TarotReadingContextReceipt: Codable, Equatable {
    var query: String
    var retrievalMode: String
    var embeddingModelID: String?
    var sources: [TarotReadingSourceReceipt]
    var edges: [TarotReadingEdgeReceipt]
    var preparedAt: Date
}

struct TarotReadingArtifact: Identifiable, Codable, Equatable {
    static let metadataKey = "tarotReadingArtifact"

    var schemaVersion = 3
    var id: String
    var deckVersion: String
    var spread: TarotSpread
    var drawnAt: Date
    var question: String
    var cards: [TarotDrawnCard]
    var firstLook: String
    var reflection: String
    /// Local, deterministic field notes shown as each card turns. Stored so a
    /// kept reading preserves exactly what the reader saw.
    var revealProse: [String: String]?
    /// New readings name their Cast reader. Optional for backward-compatible
    /// decoding of readings kept before Tarot belonged to Serenity Brown.
    var readerID: String?
    var readerName: String?
    /// Gemma is only called after an explicit Cast-reader button press. The
    /// storage name remains unchanged so older kept readings still decode.
    var auroraReading: String?
    /// Present only when the reader explicitly invited recent Pages into the
    /// reading. This is the inspectable retrieval receipt, not hidden context.
    var contextReceipt: TarotReadingContextReceipt?

    init(
        id: String = UUID().uuidString,
        deckVersion: String = TarotDeck.version,
        spread: TarotSpread,
        drawnAt: Date = Date(),
        question: String = "",
        cards: [TarotDrawnCard],
        firstLook: String = "",
        reflection: String = "",
        revealProse: [String: String]? = nil,
        readerID: String? = TarotReadingGuide.readerID,
        readerName: String? = TarotReadingGuide.readerName,
        auroraReading: String? = nil,
        contextReceipt: TarotReadingContextReceipt? = nil
    ) {
        self.id = id
        self.deckVersion = deckVersion
        self.spread = spread
        self.drawnAt = drawnAt
        self.question = question
        self.cards = cards
        self.firstLook = firstLook
        self.reflection = reflection
        self.revealProse = revealProse
        self.readerID = readerID
        self.readerName = readerName
        self.auroraReading = auroraReading
        self.contextReceipt = contextReceipt
    }

    /// Reader-neutral access for current code; `auroraReading` remains the
    /// encoded key solely to keep previously saved artifacts readable.
    var castReading: String? {
        get { auroraReading }
        set { auroraReading = newValue }
    }

    var archiveText: String {
        let heldQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let cardLines = cards.compactMap { drawn -> String? in
            guard let card = TarotDeck.card(id: drawn.cardID) else { return nil }
            return "\(drawn.position.title): \(card.name)\(drawn.isReversed ? " · reversed" : "")"
        }
        var sections = [spread.title]
        if !heldQuestion.isEmpty { sections.append("Held lightly: \(heldQuestion)") }
        sections.append(cardLines.joined(separator: "\n"))
        if !firstLook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("First look:\n\(firstLook)")
        }
        if !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("What I’m carrying:\n\(reflection)")
        }
        if let castReading = castReading?.trimmingCharacters(in: .whitespacesAndNewlines),
           !castReading.isEmpty {
            sections.append("\(readerName ?? "Aurora") read beside me:\n\(castReading)")
        }
        if let receipt = contextReceipt, !receipt.sources.isEmpty {
            let sourceLines = receipt.sources.map { "• \($0.title) · \($0.dateLabel)" }
            sections.append("Pages invited into the reading:\n\(sourceLines.joined(separator: "\n"))")
        }
        return sections.joined(separator: "\n\n")
    }
}

enum TarotReadingGuide {
    static let readerID = "serenity-brown"
    static let readerName = "Serenity Brown"

    static let voiceContract = """
    You are Serenity Brown of Tidecrest inside ReEnchanted. Read the Tarot in your own voice: warm, lightly mischievous, companionable, concrete, and willing to turn a solemn plan sideways when a kinder detour reveals more life. You believe joy is not a distraction from magic. Your gift is shared lightness and playful motion; your fault is skipping past gravity and leaving someone else to name the hard thing. Do not make that mistake here: name the real thorn plainly before offering a possible door. You are a Cast member beside the reader, not an oracle, therapist, sage, or generic assistant.

    Never predict destiny, diagnose, claim certainty about another person's mind, or make medical, legal, financial, safety, fertility, mortality, or crisis decisions. If the question asks a card to make such a decision, say: “Don't let a picture make that call for you. We can read what the choice is stirring, but the decision belongs with real information and real help.” Use only the supplied question, cards, notes, and explicitly receipted Pages.
    """

    static func questionDirective(for question: String) -> String {
        let held = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !held.isEmpty else {
            return "No question was supplied. Read the cards as a concrete weather report for the reader's attention."
        }
        return """
        The reader asked exactly: “\(held)”
        Answer that question directly in THE PICTURE TOGETHER, preserving its people, places, and concrete subject. Every later passage must remain about that question rather than drifting into a generic card meaning. Do not promise what will happen; describe what the cards invite the reader to notice, enjoy, guard against, or try in relation to it.
        """
    }
}

enum TarotLocalInterpreter {
    static func reveal(for drawn: TarotDrawnCard, in reading: TarotReadingArtifact) -> String {
        guard let card = TarotDeck.card(id: drawn.cardID) else { return "" }
        let question = reading.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let neighborNames = reading.cards
            .filter { $0.id != drawn.id }
            .compactMap { TarotDeck.card(id: $0.cardID)?.name }
        let positionLine: String
        switch drawn.position {
        case .single:
            positionLine = "It arrives alone, so let \(card.keywords.first ?? "its image") be the first thread—not the final answer."
        case .root:
            positionLine = "\(card.name) sits under the spread like a root: \(card.lightMeaning.lowercasedFirst)"
        case .weather:
            positionLine = "\(card.name) makes the weather around this question: \(card.lightMeaning.lowercasedFirst)"
        case .door:
            positionLine = "\(card.name) does not promise an outcome; it offers a hinge: \(card.lightMeaning.lowercasedFirst)"
        }
        let relationshipLine: String
        if let neighbor = neighborNames.first {
            relationshipLine = "Beside \(neighbor), its \(card.keywords.first ?? "signal") may be worth watching for agreement—or friction."
        } else if question.isEmpty {
            relationshipLine = "Without a held question, the picture gets to choose what catches."
        } else {
            relationshipLine = "Hold it beside “\(question.clippedForTarot(limit: 72))” and notice which word changes temperature."
        }
        return "\(positionLine) \(relationshipLine)"
    }

    static func fillReveals(in reading: TarotReadingArtifact) -> TarotReadingArtifact {
        var result = reading
        result.revealProse = Dictionary(uniqueKeysWithValues: reading.cards.map {
            ($0.id, reveal(for: $0, in: reading))
        })
        return result
    }
}

private extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }

    func clippedForTarot(limit: Int) -> String {
        count <= limit ? self : String(prefix(limit - 1)) + "…"
    }
}

enum TarotDeck {
    static let version = "rws-temporary-v1"

    private struct Seed {
        let name: String
        let keywords: [String]
        let light: String
        let shadow: String
    }

    private static let majors: [Seed] = [
        .init(name: "The Fool", keywords: ["beginning", "trust", "wonder"], light: "A beginning asks for curiosity before certainty.", shadow: "Freedom can become avoidance when no step is ever chosen."),
        .init(name: "The Magician", keywords: ["agency", "skill", "attention"], light: "The tools are already on the table; direct them.", shadow: "Check whether confidence is becoming performance or control."),
        .init(name: "The High Priestess", keywords: ["intuition", "quiet", "mystery"], light: "Let the unspoken information have a seat.", shadow: "Silence can shelter wisdom, or hide what needs naming."),
        .init(name: "The Empress", keywords: ["nurture", "abundance", "creation"], light: "Feed what is alive enough to grow.", shadow: "Care without boundaries can become depletion."),
        .init(name: "The Emperor", keywords: ["structure", "authority", "stability"], light: "A clear boundary can make the room safer.", shadow: "Structure turns brittle when it cannot listen."),
        .init(name: "The Hierophant", keywords: ["tradition", "teaching", "belonging"], light: "Ask what inherited wisdom still serves.", shadow: "A rule is not sacred merely because it is old."),
        .init(name: "The Lovers", keywords: ["choice", "union", "values"], light: "Choose in a way that lets your values recognize you.", shadow: "Harmony can become self-abandonment when difference is feared."),
        .init(name: "The Chariot", keywords: ["direction", "will", "movement"], light: "Gather competing forces around one true direction.", shadow: "Momentum is not the same thing as alignment."),
        .init(name: "Strength", keywords: ["courage", "patience", "heart"], light: "Meet the wild thing without humiliating it.", shadow: "Gentleness is not an excuse to avoid necessary force."),
        .init(name: "The Hermit", keywords: ["solitude", "search", "guidance"], light: "Step back far enough to see your own lantern.", shadow: "Solitude can quietly harden into disappearance."),
        .init(name: "Wheel of Fortune", keywords: ["cycle", "change", "timing"], light: "The pattern is moving; move with what is actually changing.", shadow: "Do not surrender your agency to luck or inevitability."),
        .init(name: "Justice", keywords: ["truth", "balance", "consequence"], light: "Name the facts and let consequences belong where they belong.", shadow: "Fairness without mercy can become another distortion."),
        .init(name: "The Hanged Man", keywords: ["pause", "surrender", "perspective"], light: "A chosen pause may reveal the angle effort could not.", shadow: "Waiting is not wisdom when it only postpones a decision."),
        .init(name: "Death", keywords: ["ending", "change", "release"], light: "Something completed can be allowed to become compost.", shadow: "Clinging can make an ending harsher than it needs to be."),
        .init(name: "Temperance", keywords: ["integration", "measure", "healing"], light: "Combine what seemed opposed until a third way appears.", shadow: "Moderation can become dilution when the truth needs a clear edge."),
        .init(name: "The Devil", keywords: ["attachment", "appetite", "shadow"], light: "Look closely at the bargain and where the chain is loose.", shadow: "Shame can keep a pattern stronger than honest desire does."),
        .init(name: "The Tower", keywords: ["rupture", "revelation", "release"], light: "What falls may be the structure that could no longer hold truth.", shadow: "Do not confuse destruction with transformation for its own sake."),
        .init(name: "The Star", keywords: ["hope", "renewal", "guidance"], light: "Offer the future one honest act of faith.", shadow: "Hope needs tending; it cannot live on wishing alone."),
        .init(name: "The Moon", keywords: ["dream", "uncertainty", "instinct"], light: "Move slowly; not everything unclear is dangerous.", shadow: "Fear can paint certainty onto shadows."),
        .init(name: "The Sun", keywords: ["clarity", "joy", "vitality"], light: "Let the good thing be fully good while it is here.", shadow: "Brightness can overlook what still needs shade and rest."),
        .init(name: "Judgement", keywords: ["calling", "reckoning", "awakening"], light: "Answer the life that is asking you to rise differently.", shadow: "A reckoning is not an invitation to condemn yourself forever."),
        .init(name: "The World", keywords: ["completion", "wholeness", "arrival"], light: "Notice what has become whole enough to celebrate.", shadow: "Completion is a threshold, not a demand for perfection.")
    ]

    private static let rankMeanings: [TarotRank: Seed] = [
        .ace: .init(name: "", keywords: ["seed", "opening"], light: "A clean beginning is being offered.", shadow: "Potential needs a real container before it can grow."),
        .two: .init(name: "", keywords: ["choice", "pairing"], light: "Two forces can meet without becoming identical.", shadow: "Indecision may be disguising the choice already felt."),
        .three: .init(name: "", keywords: ["growth", "company"], light: "Something expands through witness or collaboration.", shadow: "More voices are not always more truth."),
        .four: .init(name: "", keywords: ["stability", "pause"], light: "Make a place sturdy enough to rest in.", shadow: "Protection can become stagnation or enclosure."),
        .five: .init(name: "", keywords: ["friction", "loss"], light: "The difficult part deserves an honest name.", shadow: "Pain can narrow the field until nothing else is visible."),
        .six: .init(name: "", keywords: ["exchange", "passage"], light: "A kinder current is available; enter it deliberately.", shadow: "Help can create imbalance when its terms stay hidden."),
        .seven: .init(name: "", keywords: ["discernment", "test"], light: "Choose what deserves continued belief.", shadow: "Defensiveness or fantasy may be multiplying the problem."),
        .eight: .init(name: "", keywords: ["practice", "movement"], light: "Repetition and motion are changing the situation.", shadow: "Busyness can keep the deeper question out of reach."),
        .nine: .init(name: "", keywords: ["ripening", "resilience"], light: "What you have tended is close enough to feel.", shadow: "Self-protection may be keeping nourishment out too."),
        .ten: .init(name: "", keywords: ["completion", "inheritance"], light: "See the whole cycle and what it has made.", shadow: "A full load may include burdens that are not yours."),
        .page: .init(name: "", keywords: ["message", "learning"], light: "Approach this as a student and listen for news.", shadow: "Curiosity scatters when it will not stay for the lesson."),
        .knight: .init(name: "", keywords: ["pursuit", "motion"], light: "Give the desire a direction and move.", shadow: "Urgency can outrun judgment."),
        .queen: .init(name: "", keywords: ["stewardship", "inner mastery"], light: "Lead by tending the conditions from within.", shadow: "Care or composure can become quiet control."),
        .king: .init(name: "", keywords: ["command", "outer mastery"], light: "Take responsible ownership of the field.", shadow: "Authority without listening becomes domination.")
    ]

    private static let suitMeanings: [TarotSuit: Seed] = [
        .cups: .init(name: "", keywords: ["feeling", "relationship"], light: "Let feeling become information and connection.", shadow: "Feeling may be flooding the facts or withholding itself."),
        .pentacles: .init(name: "", keywords: ["body", "work"], light: "Bring the matter into the body, the home, or the workbench.", shadow: "Security may be narrowing into scarcity or overwork."),
        .swords: .init(name: "", keywords: ["thought", "truth"], light: "Use clear language and let the true distinction appear.", shadow: "A sharp mind can cut its holder when it cannot rest."),
        .wands: .init(name: "", keywords: ["desire", "making"], light: "Follow the living spark toward expression.", shadow: "Heat without grounding can scorch or scatter.")
    ]

    static let all: [TarotCardDefinition] = {
        let majorCards = majors.enumerated().map { number, seed in
            TarotCardDefinition(
                id: String(format: "major-%02d", number),
                name: seed.name,
                assetName: String(format: "TarotMajor%02d", number) + majorAssetSuffix(number),
                arcana: .major,
                suit: nil,
                rank: nil,
                keywords: seed.keywords,
                lightMeaning: seed.light,
                shadowMeaning: seed.shadow
            )
        }
        let minorCards = TarotSuit.allCases.flatMap { suit in
            TarotRank.allCases.map { rank -> TarotCardDefinition in
                let rankSeed = rankMeanings[rank]!
                let suitSeed = suitMeanings[suit]!
                return TarotCardDefinition(
                    id: "\(suit.rawValue)-\(rank.rawValue)",
                    name: "\(rank.title) of \(suit.title)",
                    assetName: "Tarot\(suit.title)\(rank.assetSuffix)",
                    arcana: .minor,
                    suit: suit,
                    rank: rank,
                    keywords: Array((rankSeed.keywords + suitSeed.keywords).prefix(3)),
                    lightMeaning: "\(rankSeed.light) \(suitSeed.light)",
                    shadowMeaning: "\(rankSeed.shadow) \(suitSeed.shadow)"
                )
            }
        }
        return majorCards + minorCards
    }()

    static func card(id: String) -> TarotCardDefinition? {
        all.first { $0.id == id }
    }

    private static func majorAssetSuffix(_ number: Int) -> String {
        [
            "Fool", "Magician", "HighPriestess", "Empress", "Emperor", "Hierophant",
            "Lovers", "Chariot", "Strength", "Hermit", "WheelOfFortune", "Justice",
            "HangedMan", "Death", "Temperance", "Devil", "Tower", "Star", "Moon",
            "Sun", "Judgement", "World"
        ][number]
    }
}

enum TarotDrawEngine {
    static func draw(spread: TarotSpread) -> TarotReadingArtifact {
        var generator = SystemRandomNumberGenerator()
        return draw(spread: spread, using: &generator)
    }

    static func draw<R: RandomNumberGenerator>(
        spread: TarotSpread,
        using generator: inout R
    ) -> TarotReadingArtifact {
        var deck = TarotDeck.all
        deck.shuffle(using: &generator)
        let cards = zip(spread.positions, deck.prefix(spread.positions.count)).map { position, card in
            TarotDrawnCard(cardID: card.id, position: position, isReversed: false)
        }
        return TarotReadingArtifact(spread: spread, cards: cards)
    }
}

struct TarotPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .tarot)

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive,
              !context.distress.isActive,
              inputs.keptPageCount >= EmergentPageMaturity.minimumKeptPages else {
            return []
        }
        let mostRecentReading = (inputs.days + [day])
            .flatMap(\.pages)
            .filter { $0.type == .tarot }
            .map(\.createdAt)
            .max()
        guard mostRecentReading.map({ !Calendar.current.isDate($0, inSameDayAs: now) }) ?? true else {
            return []
        }
        return [surface(now: now)]
    }

    func manualSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        surface(now: now)
    }

    private func surface(now: Date) -> SurfacePage {
        SurfacePage(
            id: "tarot-pages-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .tarot,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .tarotReading,
            score: 70,
            reason: "A small deck has surfaced without insisting it knows more than you do.",
            prompt: "The cards have left a little room for you.",
            detail: "Choose one card, or lay Root · Weather · Door. The draw is chance; the reading belongs to you.",
            payload: BookPagePayload(
                headline: "Tarot Pages",
                body: "Serenity Brown will read beside you. She won’t pretend the cards are a verdict.",
                metadata: [
                    "source": source.id,
                    "tags": "tarot,reflection,rider-waite-smith",
                    "tarotDeckVersion": TarotDeck.version,
                    "automaticRecurrenceSlot": "\(BookDay.id(for: now)):tarot",
                    "dailyTarot": "true"
                ]
            )
        )
    }
}
