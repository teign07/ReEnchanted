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
    You are Serenity Brown of Tidecrest inside ReEnchanted. Read the Tarot in your own voice: warm, lightly mischievous, companionable, concrete, and willing to turn a solemn plan sideways when a kinder detour reveals more life. You believe joy is not a distraction from magic. Your gift is shared lightness and playful motion; your fault is skipping past gravity and leaving someone else to name the hard thing. Do not make that mistake here: name the real thorn plainly before offering one thing to try. You are a Cast member beside the reader, not an oracle, therapist, sage, or generic assistant.

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
            positionLine = "It arrives alone, so let \(card.keywords.first ?? "its image") be the first thread, not the final answer."
        case .root:
            positionLine = "\(card.name) sits under the spread like a root: \(card.lightMeaning.lowercasedFirst)"
        case .weather:
            positionLine = "\(card.name) makes the weather around this question: \(card.lightMeaning.lowercasedFirst)"
        case .door:
            positionLine = "\(card.name) does not promise an outcome; it offers a turn: \(card.lightMeaning.lowercasedFirst)"
        }
        let relationshipLine: String
        if let neighbor = neighborNames.first {
            relationshipLine = "Beside \(neighbor), its \(card.keywords.first ?? "signal") may be worth watching for agreement or friction."
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
    static let version = "unwritten-v3.2"

    /// Authored lettering belongs to the card composition, rather than to a
    /// generated bitmap. Its transcript stays available to VoiceOver as well.
    struct Marginalia: Equatable {
        struct Point: Equatable {
            let x: Double
            let y: Double
        }

        struct Annotation: Equatable {
            let text: String
            let x: Double
            let y: Double
            let width: Double
            var fontWidthRatio: Double = 0.034
            var rotation: Double = -2
            var onPaper: Bool = false
            var maxLines: Int = 2
            var leader: [Point] = []
            var isInscription: Bool = false
        }

        let label: String
        let note: String
        var labelX: Double = 0.06
        var labelY: Double = 0.145
        var labelWidth: Double = 0.36
        var labelOnPaper: Bool = false
        var noteX: Double = 0.09
        var noteY: Double = 0.91
        var noteWidth: Double = 0.82
        var labelFontWidthRatio: Double = 0.043
        var labelRotation: Double = -3
        var additional: [Annotation] = []
        var sceneDescription: String = ""
        var transcriptOverride: String? = nil

        var transcript: String {
            if let transcriptOverride { return transcriptOverride }
            return "In the margin: " + ([label] + additional.filter { !$0.isInscription }.map(\.text) + [note])
                .map { $0.hasSuffix(".") || $0.hasSuffix("?") || $0.hasSuffix("!") ? $0 : $0 + "." }
                .joined(separator: " ")
        }

        var inscriptionTranscript: String {
            additional.filter(\.isInscription).map(\.text).joined(separator: ", ")
        }

        var accessibleDescription: String {
            [sceneDescription,
             inscriptionTranscript.isEmpty ? "" : "Artwork lettering: \(inscriptionTranscript).",
             transcript].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    static func marginalia(for cardID: String) -> Marginalia? {
        printedMarginalia[cardID]
    }

    /// The Cast reader sees the same edition-specific objects and printed
    /// notes as the reader. These are artwork, never evidence about a person.
    static func illustrationContext(for cardID: String) -> String? {
        guard let margin = marginalia(for: cardID) else { return nil }
        let subjects = (illustratedSubjects[cardID] ?? [])
            .map { $0.replacingOccurrences(of: "-", with: " ") }
            .joined(separator: ", ")
        return """
        This card reimagines Rider–Waite–Smith in the ReEnchanted library Academy. Wands are dip pens, Swords are paper knives, and Pentacles are hinged book clasps; traditional identities and counts remain.
        Pictured scene: \(margin.sceneDescription)
        Artwork subjects and themes: \(subjects).
        Artwork lettering: \(margin.inscriptionTranscript)
        Authored card marginalia: \(margin.transcript)
        These are authored details of the picture, not the reader's notes or facts about their life.
        """
    }

    // BEGIN AUTHORED UNWRITTEN MARGINALIA
    private static let printedMarginalia: [String: Marginalia] = [
        "major-00": .init(label: "white rose", note: "The dog noticed.", labelX: 0.025, labelY: 0.118, labelWidth: 0.18, labelOnPaper: true, noteX: 0.09, noteY: 0.935, noteWidth: 0.82, labelFontWidthRatio: 0.032, additional: [.init(text: "edge of the step", x: 0.04, y: 0.82, width: 0.3, fontWidthRatio: 0.03, onPaper: false, maxLines: 2), .init(text: "It caught the corner.", x: 0.755, y: 0.585, width: 0.22, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 3, leader: [.init(x: 0.77, y: 0.58), .init(x: 0.89, y: 0.51)])], sceneDescription: "An adult Black literary-fae reader steps toward a precipice outside a book-filled Academy doorway, looking up into sunlight. A white dog tugs his coat hem. He carries a white rose and a small book bundle; a book moth catches a loose blank page. The margins study the rose and the edge of a step."),
        "major-01": .init(label: "catalog tab", note: "The tools won't do it for you.", labelX: 0.025, labelY: 0.095, labelWidth: 0.18, additional: [.init(text: "white lily", x: 0.045, y: 0.875, width: 0.2, fontWidthRatio: 0.033, maxLines: 1, leader: [.init(x: 0.07, y: 0.875), .init(x: 0.045, y: 0.84), .init(x: 0.07, y: 0.79)]), .init(text: "Put that back.", x: 0.76, y: 0.27, width: 0.21, fontWidthRatio: 0.03, rotation: -2, onPaper: true, maxLines: 2, leader: [.init(x: 0.82, y: 0.265), .init(x: 0.89, y: 0.225)])], sceneDescription: "Penny Blackletter raises a dip pen and points down at her printing desk. A cup, paper knife and hinged pentacle book clasp rest among books. An infinity loop hangs above her; roses and lilies grow through the wild library. A pixie steals a comma in the margin."),
        "major-02": .init(label: "pomegranate rind", note: "Some things open when you stop pulling.", labelX: 0.025, labelY: 0.125, labelWidth: 0.245, labelOnPaper: true, noteX: 0.09, noteY: 0.91, noteWidth: 0.82, labelFontWidthRatio: 0.028, additional: [.init(text: "veil hem", x: 0.03, y: 0.815, width: 0.22, fontWidthRatio: 0.03, onPaper: false, maxLines: 1), .init(text: "Not every door is yours.", x: 0.59, y: 0.875, width: 0.35, fontWidthRatio: 0.03, onPaper: false, maxLines: 1), .init(text: "B", x: 0.139, y: 0.332, width: 0.07, fontWidthRatio: 0.06, rotation: 0, maxLines: 1, isInscription: true), .init(text: "J", x: 0.854, y: 0.332, width: 0.06, fontWidthRatio: 0.06, rotation: 0, maxLines: 1, isInscription: true), .init(text: "TORA", x: 0.38, y: 0.57, width: 0.09, fontWidthRatio: 0.025, rotation: 5, maxLines: 1, isInscription: true)], sceneDescription: "A mature Unseelie literary-elf keeper sits in a restricted Academy reading room between an ink-black pillar marked B and a pale pillar marked J. She wears a lunar crown and cross; a crescent rests at her feet. Her hands partly cover a scroll marked TORA. A pomegranate-and-palm veil conceals a guarded book and a glimpse of water. The margins study rind and veil mending, with a question-mark pixie."),
        "major-03": .init(label: "wheat ear", note: "Feed what is growing.", labelX: 0.04, labelY: 0.94, labelWidth: 0.25, labelOnPaper: false, noteX: 0.46, noteY: 0.895, noteWidth: 0.48, labelFontWidthRatio: 0.029, additional: [.init(text: "plant tie", x: 0.835, y: 0.465, width: 0.14, fontWidthRatio: 0.026, rotation: -2, onPaper: true, maxLines: 1), .init(text: "Leave room for roots.", x: 0.045, y: 0.05, width: 0.18, fontWidthRatio: 0.028, rotation: -2, onPaper: false, maxLines: 3)], sceneDescription: "An adult Seelie literary-elf nurturer sits in a cushioned wooden chair in the Mossbloom common-room conservatory. Twelve separate stars crown her; she raises a plain scepter beside a Venus-marked heart shield, ripe wheat and flowing water. Books, plants and a botanical folio surround her. A paper sprite loosens a plant tie in the margin. Margin refinement: the wheat study sits low on the left, the tied-stem study runs along the right edge, and the helper works in the actual vine rather than a separate upper corner."),
        "major-04": .init(label: "oak grain", note: "Who made these rules?", labelX: 0.04, labelY: 0.095, labelWidth: 0.23, noteX: 0.09, noteY: 0.91, noteWidth: 0.82, labelFontWidthRatio: 0.03, additional: [.init(text: "wax seal", x: 0.035, y: 0.716, width: 0.13, fontWidthRatio: 0.027, onPaper: false, maxLines: 2), .init(text: "This side of the line.", x: 0.6, y: 0.875, width: 0.34, fontWidthRatio: 0.03, onPaper: false, maxLines: 1)], sceneDescription: "Headmistress Seraphina Thorne sits in a four-ram-carved stone chair at the Great Hall head table. Her oxblood Academy coat, upright scepter, steady orb hand and mountain window echo the Emperor. Books and blank boundary plans lie on the table. The margins study oak grain and a wax impression; a wingless goblin measures a paper edge."),
        "major-05": .init(label: "leather", note: "Which old rule still helps?", labelX: 0.18, labelY: 0.045, labelWidth: 0.12, noteX: 0.09, noteY: 0.93, noteWidth: 0.82, labelFontWidthRatio: 0.03, additional: [.init(text: "book ribbon", x: 0.045, y: 0.875, width: 0.25, fontWidthRatio: 0.03, onPaper: false, maxLines: 1), .init(text: "Ask him why.", x: 0.035, y: 0.33, width: 0.18, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "Professor Thaddeus Mook teaches two adult learners in a book-filled Lexical Diversity classroom. He raises a teaching hand and holds a staff beneath a three-tier bookplate crown. Two crossed keys sit below his great chained, padlocked Dictionary. His canonical spectacles and red pen remain. A worn leather-and-ribbon study and question-mark pixie inhabit the margins."),
        "major-06": .init(label: "joining stitch", note: "Two hands. Neither holds the other shut.", labelX: 0.025, labelY: 0.14, labelWidth: 0.23, labelOnPaper: true, sceneDescription: "Two adult literary elves, Seelie and Unseelie, meet as equals over a shared book in a branching library. A manuscript-winged Book Fae witnesses their choice beneath the sun. Apples and a serpent flank one side; a flame tree flanks the other."),
        "major-07": .init(label: "cart lashings", note: "Which way, then?", labelX: 0.05, labelY: 0.92, labelWidth: 0.32, labelOnPaper: false, noteX: 0.045, noteY: 0.035, noteWidth: 0.24, labelFontWidthRatio: 0.028, labelRotation: -2, additional: [.init(text: "wheel spoke", x: 0.025, y: 0.82, width: 0.22, fontWidthRatio: 0.027, rotation: -2, onPaper: false, maxLines: 2), .init(text: "Both beasts heard you.", x: 0.49, y: 0.925, width: 0.45, fontWidthRatio: 0.03, rotation: -2, onPaper: false, maxLines: 2)], sceneDescription: "Professor Permancer stands armored in a heavy returned-book cart under star canopy in a finite courtyard; black and white folded-paper sphinx-like beasts face opposite directions below, no reins. Cart-lashing knot, partial wheel and winged catalogue sprite testing parcel knot occupy paper margins. Margin refinement: the cart lashings sit in a low horizontal study beside the separate wheel study. A small helper works beside a parcel on the left of the cart; the upper margin carries an authored aside."),
        "major-08": .init(label: "paper mane", note: "Mind the teeth.", labelX: 0.025, labelY: 0.173, labelWidth: 0.2, labelOnPaper: false, noteY: 0.915, labelFontWidthRatio: 0.028, additional: [.init(text: "flower cord", x: 0.025, y: 0.414, width: 0.125, fontWidthRatio: 0.022, onPaper: false, maxLines: 1), .init(text: "Ask the lion first.", x: 0.62, y: 0.875, width: 0.32, fontWidthRatio: 0.03, onPaper: false, maxLines: 1)], sceneDescription: "Professor Luna Wispwood, smiling and freckled with curly copper-red hair and blue practical waistcoat, gently cups an open paper-lion jaw in a morning Basic Enchantments classroom. Flowers connect her hair, waist and the lion, a gold infinity floats above, and a mountain appears through the window. A blank dropped book and shelves ground the lesson."),
        "major-09": .init(label: "lantern wick", note: "Enough light for this step.", labelX: 0.025, labelY: 0.17, labelWidth: 0.24, labelOnPaper: true, sceneDescription: "An ancient Deep Lore Dwarf holds a six-point-star lantern and walking staff on a narrow Under-Stacks stair. Books, keys, mist and a moth surround him. The lantern lights the next step."),
        "major-10": .init(label: "catalogue spindle", note: "Who is on top this time?", labelX: 0.025, labelY: 0.845, labelWidth: 0.34, noteX: 0.09, noteY: 0.91, noteWidth: 0.82, labelFontWidthRatio: 0.029, labelRotation: -2, additional: [.init(text: "bearing", x: 0.02, y: 0.113, width: 0.115, fontWidthRatio: 0.024, onPaper: true, maxLines: 1), .init(text: "Round again.", x: 0.72, y: 0.875, width: 0.22, fontWidthRatio: 0.03, onPaper: false, maxLines: 1), .init(text: "T", x: 0.483, y: 0.304, width: 0.05, fontWidthRatio: 0.055, rotation: 0, maxLines: 1, isInscription: true), .init(text: "A", x: 0.776, y: 0.444, width: 0.05, fontWidthRatio: 0.055, rotation: 90, maxLines: 1, isInscription: true), .init(text: "R", x: 0.526, y: 0.614, width: 0.05, fontWidthRatio: 0.055, rotation: -180, maxLines: 1, isInscription: true), .init(text: "O", x: 0.242, y: 0.438, width: 0.05, fontWidthRatio: 0.055, rotation: 0, maxLines: 1, isInscription: true)], sceneDescription: "A copper catalogue-drawer wheel stands in a timber Catalogue Hall. A serpent descends on the left, head pointing down; a red jackal-headed figure rises on the right. A sphinx holds a brass paper knife above it. Four winged witnesses read books in the corners: human, eagle, bull and lion. T, A, R and O mark the wheel. Margins study spindle hardware; a goblin holds a loose catalogue leaf."),
        "major-11": .init(label: "square clasp", note: "Let the facts keep their weight.", labelX: 0.035, labelY: 0.11, labelWidth: 0.27, noteX: 0.09, noteY: 0.92, noteWidth: 0.82, labelFontWidthRatio: 0.03, labelRotation: -2, additional: [.init(text: "paper edge", x: 0.1, y: 0.772, width: 0.18, fontWidthRatio: 0.028, onPaper: false, maxLines: 1), .init(text: "Weigh that too.", x: 0.79, y: 0.68, width: 0.18, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "Penny seated in Attestation office between two timber supports and violet screen, holds upright brass paper knife and balanced scales of paper; blank ledger across knees. Square red-glass clasp study, torn paper edge and tiny paper-corner fae enrich margins."),
        "major-12": .init(label: "ankle loop", note: "Try the view from here.", labelX: 0.03, labelY: 0.29, labelWidth: 0.17, labelOnPaper: true, noteY: 0.915, labelFontWidthRatio: 0.028, additional: [.init(text: "door hinge", x: 0.03, y: 0.657, width: 0.18, fontWidthRatio: 0.028, onPaper: true, maxLines: 1), .init(text: "No rush from this side.", x: 0.045, y: 0.875, width: 0.43, fontWidthRatio: 0.03, rotation: -7, onPaper: false, maxLines: 2)], sceneDescription: "Professor Permancer hangs calmly upside down by one padded boot/ankle loop from a living T-shaped timber story-door. His free leg bends and crosses the attached leg, arms rest behind his back and halo surrounds his inverted head. A blank open floor book and finite green-daylit classroom shelves complete the lesson."),
        "major-13": .init(label: "rose petal", note: "Let it end.", labelX: 0.215, labelY: 0.104, labelWidth: 0.145, labelOnPaper: false, noteX: 0.33, noteY: 0.91, noteWidth: 0.34, labelFontWidthRatio: 0.027, additional: [.init(text: "fallen leaf", x: 0.27, y: 0.855, width: 0.2, fontWidthRatio: 0.027, onPaper: false, maxLines: 1), .init(text: "Keep the seed.", x: 0.63, y: 0.855, width: 0.25, fontWidthRatio: 0.028, onPaper: false, maxLines: 1)], sceneDescription: "A skeletal rider and white horse pass four witnesses in an old-paper garden; black rose banner, fallen crown, river, two towers and sunrise mark a real ending."),
        "major-14": .init(label: "iris petal", note: "A little of each. Don't spill.", labelX: 0.1, labelY: 0.097, labelWidth: 0.135, labelOnPaper: false, noteY: 0.92, labelFontWidthRatio: 0.024, additional: [.init(text: "dye swatches", x: 0.025, y: 0.805, width: 0.22, fontWidthRatio: 0.028, onPaper: true, maxLines: 1), .init(text: "A little at a time.", x: 0.65, y: 0.875, width: 0.29, fontWidthRatio: 0.029, onPaper: false, maxLines: 1)], sceneDescription: "Professor Eleanor Euphony appears as a winged Temperance allegory in the book-filled Inkworks dye room. Her long dark locs carry silver strands; she wears practical blue-violet Academy clothes. One bare foot rests on dry stone and one in a shallow water channel. Ink-water arches between exactly two held cups. Irises and a sunlit path appear beyond the worktables. Margins study an iris petal and two dye swatches; a tiny colour sprite tests pigment on paper."),
        "major-15": .init(label: "loose chain link", note: "What keeps them here?", labelX: 0.025, labelY: 0.12, labelWidth: 0.22, labelOnPaper: true, noteY: 0.915, labelFontWidthRatio: 0.028, additional: [.init(text: "broken seal", x: 0.025, y: 0.864, width: 0.22, fontWidthRatio: 0.028, onPaper: true, maxLines: 1), .init(text: "Loose enough to lift.", x: 0.64, y: 0.875, width: 0.32, fontWidthRatio: 0.03, rotation: -2, onPaper: false, maxLines: 2)], sceneDescription: "A horned, bat-winged book-bargain fae sits above two adult readers in a locked lending alcove. Loose chains join their oversized open collars to a dark lectern pedestal, a downward torch and inverted star retain the Devil tableau, and open book clasps leave a questioned bargain visible."),
        "major-16": .init(label: "paper fibres", note: "What was it holding shut?", labelX: 0.025, labelY: 0.098, labelWidth: 0.18, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "split timber", x: 0.8, y: 0.12, width: 0.18, fontWidthRatio: 0.023, onPaper: true, maxLines: 1), .init(text: "Mind the landing.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.029, onPaper: false, maxLines: 1)], sceneDescription: "Lightning breaks a book-filled archive tower, its crown flies free, two adult scholars fall among exactly twenty-two flame drops, and two tiny ink fae shelter beneath a loose roof tile at the margin."),
        "major-17": .init(label: "water ripples", note: "Give tomorrow one small drink.", labelX: 0.025, labelY: 0.1, labelWidth: 0.18, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.023, labelRotation: -1, additional: [.init(text: "feather trace", x: 0.025, y: 0.885, width: 0.23, fontWidthRatio: 0.027, onPaper: false, maxLines: 1), .init(text: "Enough for tonight.", x: 0.78, y: 0.42, width: 0.2, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "A silver-haired adult literary elf in rolled garden workwear kneels at a finite reading-garden pool, one foot in water and one knee on earth. Two ceramic jugs pour onto water and soil beneath one large and seven small eight-point stars. Books and drying blank sheets sit by the timber garden shelter; waterline, feather and book-moth margin traces accompany the scene."),
        "major-18": .init(label: "reeds", note: "Go slowly.", labelX: 0.025, labelY: 0.145, labelWidth: 0.18, labelOnPaper: true, noteX: 0.32, noteY: 0.93, noteWidth: 0.3, labelFontWidthRatio: 0.028, additional: [.init(text: "tide mark", x: 0.035, y: 0.815, width: 0.2, fontWidthRatio: 0.028, onPaper: true, maxLines: 1, leader: [.init(x: 0.12, y: 0.837), .init(x: 0.12, y: 0.85)]), .init(text: "That shadow moved.", x: 0.32, y: 0.895, width: 0.31, fontWidthRatio: 0.023, onPaper: false, maxLines: 1)], sceneDescription: "At the wet approach to the tidal library, one domestic dog and one wolf howl beneath a single profile-faced full moon. Fifteen gold dew drops descend between two timber library towers while a crayfish rises from a pool and a gold path winds into misty hills. A folded wordless travel map ends near the water."),
        "major-19": .init(label: "sunflower petal", note: "Look. All that yellow.", labelX: 0.025, labelY: 0.105, labelWidth: 0.18, labelOnPaper: true, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -2, additional: [.init(text: "banner seam", x: 0.82, y: 0.275, width: 0.16, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "More room for yellow.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.027, onPaper: false, maxLines: 1)], sceneDescription: "A fully clothed joyful young literary fae rides a calm white horse beneath a faced sun with straight and wavy rays. A raised red banner, open arm and red feather echo the traditional tableau; exactly four sunflowers grow behind a low courtyard wall. A storybook satchel, reading window and open botanical book ground the Academy setting. One petal, a banner seam and tiny stitch-hanging pixie occupy outer paper scraps."),
        "major-20": .init(label: "trumpet ribbon", note: "What is asking you to rise?", labelX: 0.035, labelY: 0.105, labelWidth: 0.23, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -2, additional: [.init(text: "coffer hinge", x: 0.025, y: 0.79, width: 0.22, fontWidthRatio: 0.03, onPaper: false, maxLines: 2), .init(text: "You heard it too.", x: 0.045, y: 0.25, width: 0.23, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "In the finite oak Vault of Doors, a russet-winged herald in a pale tailored Academy coat sounds a brass trumpet with a white red-cross banner. Three foreground and three distant clothed readers rise from open book-shaped coffers and raise their arms toward the call. Open doors frame dawn tidal water and mountains. Ribbon, hinge and tiny folio-sprite studies occupy pale outer scraps."),
        "major-21": .init(label: "laurel", note: "Notice what has come together.", labelX: 0.018, labelY: 0.13, labelWidth: 0.1, labelOnPaper: true, noteX: 0.09, noteY: 0.92, noteWidth: 0.82, labelFontWidthRatio: 0.022, additional: [.init(text: "wreath tie", x: 0.025, y: 0.9, width: 0.19, fontWidthRatio: 0.026, onPaper: false, maxLines: 1), .init(text: "The door is still there.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.026, onPaper: false, maxLines: 1)], sceneDescription: "An androgynous adult literary-fae dancer moves within a living oval laurel wreath in the Academy completion gallery, one small dip pen in each hand. Four winged witnesses—human, eagle, bull and lion—occupy the tableau corners. Handmade books and five restrained Chapter colours mark a completed work."),
        "wands-ace": .init(label: "wood buds", note: "Give the spark a page.", labelX: 0.79, labelY: 0.235, labelWidth: 0.19, labelOnPaper: true, noteX: 0.36, noteY: 0.92, noteWidth: 0.6, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "paper curl", x: 0.025, y: 0.895, width: 0.23, fontWidthRatio: 0.028, rotation: -2, onPaper: false, maxLines: 2), .init(text: "Start here.", x: 0.04, y: 0.04, width: 0.2, fontWidthRatio: 0.03, rotation: -2, onPaper: false, maxLines: 2)], sceneDescription: "A cloud-paper hand offers one budding brass-nib dip pen over a blank writing desk, open book and library window; a sprite clears the paper. Margin refinement: the wood-bud specimen is high on the right and the paper-curl study low on the left; a short aside occupies quiet upper-left paper."),
        "wands-two": .init(label: "map fold", note: "What lies beyond the plan?", labelX: 0.035, labelY: 0.12, labelWidth: 0.25, noteX: 0.48, noteY: 0.89, noteWidth: 0.47, labelFontWidthRatio: 0.03, labelRotation: -2, additional: [.init(text: "window latch", x: 0.025, y: 0.79, width: 0.22, fontWidthRatio: 0.03, onPaper: false, maxLines: 2), .init(text: "Leave a way back.", x: 0.045, y: 0.925, width: 0.31, fontWidthRatio: 0.03, onPaper: false, maxLines: 2)], sceneDescription: "Soren Ng, tousled black-haired and bespectacled, stands in brick-red practical Academy tailoring at a map-classroom window, holding a small globe and one upright nibbed wooden pen. A second nibbed pen is fixed to the opposite timber jamb. Sea, village and hills lie outside; atlases and books occupy the desk. Folded-map, window-latch and map-fae traces frame the scene."),
        "wands-three": .init(label: "sailcloth", note: "Send it. Then watch the horizon.", labelX: 0.025, labelY: 0.125, labelWidth: 0.19, labelOnPaper: true, noteX: 0.28, noteY: 0.89, noteWidth: 0.68, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "parcel cord", x: 0.025, y: 0.86, width: 0.2, fontWidthRatio: 0.027, onPaper: false, maxLines: 1), .init(text: "They are moving.", x: 0.045, y: 0.95, width: 0.26, fontWidthRatio: 0.028, maxLines: 1)], sceneDescription: "An adult literary-elf shipping clerk seen from behind watches three separate ships from a timber library shipping balcony; three long dip pens flank them, one held. Borrowing parcels, bound travel books and a gold-red horizon speak of departure."),
        "wands-four": .init(label: "ivy leaf", note: "Come in. There is room.", labelX: 0.16, labelY: 0.115, labelWidth: 0.13, noteX: 0.43, noteY: 0.89, noteWidth: 0.52, labelFontWidthRatio: 0.029, additional: [.init(text: "ribbon knot", x: 0.06, y: 0.962, width: 0.28, fontWidthRatio: 0.026, onPaper: false, maxLines: 1), .init(text: "Mind the knot.", x: 0.66, y: 0.852, width: 0.29, fontWidthRatio: 0.028, onPaper: true, maxLines: 1)], sceneDescription: "Serenity Brown and Zara Finch raise flowers beneath a garland supported by four brass-nib dip pens in the Great Hall. Books cover communal reading tables. Ivy and ribbon studies fill the margins; a small literary elf ties a ribbon."),
        "wands-five": .init(label: "practice chalk", note: "Five pens. Five different plans.", labelX: 0.025, labelY: 0.095, labelWidth: 0.2, labelOnPaper: true, noteX: 0.48, noteY: 0.875, noteWidth: 0.47, labelFontWidthRatio: 0.024, labelRotation: -1, additional: [.init(text: "sleeve patch", x: 0.025, y: 0.245, width: 0.22, fontWidthRatio: 0.026, rotation: -1, onPaper: true, maxLines: 2), .init(text: "Not the same plan.", x: 0.055, y: 0.915, width: 0.32, fontWidthRatio: 0.03, rotation: -5, onPaper: false, maxLines: 2)], sceneDescription: "Five adult Academy writers compete over a blank shared sheet at a classroom table. Exactly five whole brass-nib dip pens cross in five independent grips; Penny retains her wire spectacles. Furrowed brows, interruption and a competitive grin convey playful strife rather than agreement. A tiny bookish imp tugs the sheet from the tabletop. Chalk and a repaired sleeve inhabit the left margin; the former separate lower-right fae sticker is absent."),
        "wands-six": .init(label: "laurel sprig", note: "Let the work be seen.", labelX: 0.035, labelY: 0.14, labelWidth: 0.26, noteX: 0.43, noteY: 0.915, noteWidth: 0.53, labelFontWidthRatio: 0.03, labelRotation: -2, additional: [.init(text: "binding cords", x: 0.025, y: 0.82, width: 0.23, fontWidthRatio: 0.029, onPaper: false, maxLines: 2), .init(text: "Let them help carry it.", x: 0.045, y: 0.89, width: 0.34, fontWidthRatio: 0.029, onPaper: false, maxLines: 2)], sceneDescription: "Finn Bridges, dark-curled and determined in ember-red riding tailoring, returns on a white horse through the Academy entrance hall. He raises one laurel-crowned dip pen while five adult onlookers hold five other pens and books. Book parcels, timber doors and the return counter establish the room; laurel sprig, binding-cord and ribbon-tying fae traces fill the outer scraps."),
        "wands-seven": .init(label: "boot sole", note: "Hold your ground. Mind your feet.", labelX: 0.025, labelY: 0.14, labelWidth: 0.16, labelOnPaper: true, noteX: 0.09, noteY: 0.935, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "threshold grain", x: 0.025, y: 0.27, width: 0.19, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Check the other shoe.", x: 0.63, y: 0.895, width: 0.31, fontWidthRatio: 0.026, maxLines: 1)], sceneDescription: "Zara Finch braces a long dip pen diagonally in both hands on the raised uneven lending threshold, one boot and one low shoe visible. Six nibbed dip pens rise separately below. A book trolley and open blank manuscript stand behind her under clear daylight; shelves and ivy surround the ordinary doorway. Margins show worn boot sole, threshold grain and a goblin handling a loose shoelace."),
        "wands-eight": .init(label: "flight marks", note: "The message is already moving.", labelX: 0.025, labelY: 0.095, labelWidth: 0.21, labelOnPaper: true, noteX: 0.09, noteY: 0.93, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "cloud wash", x: 0.82, y: 0.145, width: 0.17, fontWidthRatio: 0.024, rotation: -1, onPaper: true, maxLines: 2), .init(text: "Make a clear way.", x: 0.6, y: 0.88, width: 0.35, fontWidthRatio: 0.027, rotation: -1, onPaper: false, maxLines: 2)], sceneDescription: "Eight separated flying dip pens point down-right beyond a timber courier-room window; blank correspondence, books and tied book parcels rest below."),
        "wands-nine": .init(label: "mended sleeve", note: "Still here. Still watching.", labelX: 0.035, labelY: 0.14, labelWidth: 0.25, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.03, labelRotation: -2, additional: [.init(text: "bandage fold", x: 0.025, y: 0.76, width: 0.23, fontWidthRatio: 0.029, onPaper: false, maxLines: 2), .init(text: "You can sit and watch.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.029, onPaper: false, maxLines: 1)], sceneDescription: "An older brown-skinned literary elf with a forehead bandage stands watch at the late-shift return desk, gripping one oversized dip pen in both hands. Eight other nibbed pens form a rack fence behind: four left and four right. A repaired folio, low shelves, dawn window and lamp establish the room. Mended cloth, folded bandage and a stool-propping margin goblin accompany the scene."),
        "wands-ten": .init(label: "binding cord", note: "You could put some down.", labelX: 0.025, labelY: 0.18, labelWidth: 0.2, labelOnPaper: true, sceneDescription: "A weary Marginalia Goblin carries ten brass-nib dip pens up a crooked library stair toward a lit bindery. The fan of pens obstructs his view; a cord study and footprint mark the paper margins."),
        "wands-page": .init(label: "salamander motif", note: "What caught your attention?", labelX: 0.025, labelY: 0.145, labelWidth: 0.19, labelOnPaper: true, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "feather trace", x: 0.025, y: 0.275, width: 0.19, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Go and look.", x: 0.78, y: 0.63, width: 0.19, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "A youthful adult literary-elf messenger stands in profile inside a small first-year study room, delightedly examining the budding nib of one upright long wood dip pen held in both hands. The figure wears a feathered cap, ochre short study coat with black salamander motifs and red leggings; boots on dry sandy classroom floor. A notebook lies blank on a study desk; full shelves and a tall open window onto dry ochre hills preserve the original landscape echo."),
        "wands-knight": .init(label: "saddle cord", note: "Where are you going so fast?", labelX: 0.025, labelY: 0.18, labelWidth: 0.22, labelOnPaper: false, noteX: 0.09, noteY: 0.93, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "wind trace", x: 0.56, y: 0.145, width: 0.19, fontWidthRatio: 0.027, onPaper: true, maxLines: 1), .init(text: "Find the way home too.", x: 0.63, y: 0.895, width: 0.31, fontWidthRatio: 0.027, onPaper: false, maxLines: 1)], sceneDescription: "Kyle Momort, grey-forelocked and in his navy ember-lined coat, rides left on a rearing chestnut horse, holding one budding dip pen; salamander waistcoat, escaped blank leaves, books and triangular ochre hills preserve the RWS momentum tableau."),
        "wands-queen": .init(label: "sunflower seeds", note: "She brought her own sun.", labelX: 0.045, labelY: 0.88, labelWidth: 0.32, labelOnPaper: false, noteX: 0.35, noteY: 0.935, noteWidth: 0.6, labelFontWidthRatio: 0.03, labelRotation: -2, additional: [.init(text: "cat paw print", x: 0.04, y: 0.782, width: 0.28, fontWidthRatio: 0.028, rotation: -2, onPaper: false, maxLines: 1), .init(text: "The cat stays.", x: 0.07, y: 0.075, width: 0.4, fontWidthRatio: 0.035, rotation: 4, onPaper: false, maxLines: 2)], sceneDescription: "The copper-haired Queen of Wands sits confidently in her book-filled common room with one long dip pen, one sunflower and a black cat at her feet. The lion-carved chair and central scene remain. The sunflower seed study now sits in the lower-left margin below the separate paw-print study. A tiny bookish goblin sits beside the chair at lower-right watching the cat. Upper margins are quiet paper."),
        "wands-king": .init(label: "salamander scales", note: "What will your vision make possible?", labelX: 0.025, labelY: 0.124, labelWidth: 0.19, labelOnPaper: false, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "chair joint", x: 0.025, y: 0.29, width: 0.17, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Stand up when it is time.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.027, onPaper: false, maxLines: 1)], sceneDescription: "An unnamed mature Deep Lore Dwarf faculty steward sits in three-quarter profile looking left, body poised to rise, on a carved timber workchair in the small Quillquarium faculty workroom. He holds one living upright dip pen at his left side, right hand rests on knee; folded signatures, coils of binding cord and volumes lie on a low workbench. Lion and curling salamander motifs decorate chair and red/ochre waistcoat, and one small living salamander rests at his feet."),
        "cups-ace": .init(label: "water lily", note: "Let something reach you.", labelX: 0.025, labelY: 0.185, labelWidth: 0.2, labelOnPaper: false, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "ripple rings", x: 0.81, y: 0.29, width: 0.17, fontWidthRatio: 0.026, onPaper: true, maxLines: 1), .init(text: "A little can overflow.", x: 0.045, y: 0.86, width: 0.32, fontWidthRatio: 0.029, onPaper: false, maxLines: 2)], sceneDescription: "A cloud-paper hand presents a sea-glass cup above a lily pool; five separate overflowing ribbons and a single descending dove with white petal preserve the RWS tableau, beside a dry book-filled garden bench."),
        "cups-two": .init(label: "shared ribbon", note: "Meet where both can stand.", labelX: 0.035, labelY: 0.135, labelWidth: 0.25, noteX: 0.43, noteY: 0.9, noteWidth: 0.53, labelFontWidthRatio: 0.03, labelRotation: -2, additional: [.init(text: "table grain", x: 0.025, y: 0.81, width: 0.23, fontWidthRatio: 0.029, onPaper: false, maxLines: 1), .init(text: "Both of you, then.", x: 0.045, y: 0.915, width: 0.32, fontWidthRatio: 0.029, onPaper: false, maxLines: 2)], sceneDescription: "Two adult literary elves, one silver-locced and sea-green-clad and one black-haired in ink-violet, stand facing each other beside a shared open book. Each holds one golden cup and their free hands meet in a handshake. A winged lion head and two-serpent caduceus appear above the finite Tidecrest reading-table alcove. Ribbon, table-grain and thread-joining paper-fae studies fill the margins."),
        "cups-three": .init(label: "rosemary", note: "Make room at the table.", labelX: 0.025, labelY: 0.13, labelWidth: 0.19, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "apron hem", x: 0.025, y: 0.285, width: 0.17, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "There is another chair.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.026, onPaper: false, maxLines: 1)], sceneDescription: "Ambrose Trencher and two adult literary-fae kitchen companions toast in a close standing circle, one back-turned. Three raised brass cups meet above them. Ambrose retains grey beard, hairnet, glasses and stained apron. Open blank cookbooks and story volumes share the worktable with bread and fruit; apples and flowers sit underfoot. Margins hold rosemary, a repaired linen apron and a pantry goblin with blank recipe leaf."),
        "cups-four": .init(label: "window-seat bark", note: "Is this a pause or an answer?", labelX: 0.025, labelY: 0.13, labelWidth: 0.24, labelOnPaper: false, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "leaf shadow", x: 0.81, y: 0.33, width: 0.17, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "It can wait outside.", x: 0.035, y: 0.465, width: 0.23, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 3, leader: [.init(x: 0.265, y: 0.48), .init(x: 0.3, y: 0.416)])], sceneDescription: "A silver-curled adult elf pauses cross-legged under a real tree in a finite Book Burrow common room, facing three sea-glass cups while a cloud-paper hand offers a fourth."),
        "cups-five": .init(label: "paper stain", note: "What remains behind you?", labelX: 0.035, labelY: 0.12, labelWidth: 0.25, labelOnPaper: true, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -2, additional: [.init(text: "bridge sketch", x: 0.055, y: 0.835, width: 0.22, fontWidthRatio: 0.027, onPaper: false, maxLines: 1), .init(text: "Turn when you can.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.029, onPaper: false, maxLines: 1)], sceneDescription: "An older grey-haired literary elf stands in a dark practical coat and apron in a kitchen cookbook alcove, head bowed toward three spilled golden cups on recipe leaves. Two cups remain upright on the table behind. A river, bridge and house appear through the window; cookbook shelves, bread and hearth establish the domestic room. Stain, bridge-sketch and dry-recipe-saving goblin studies accompany the scene."),
        "cups-six": .init(label: "white blossom", note: "Which bit do you remember?", labelX: 0.025, labelY: 0.13, labelWidth: 0.19, labelOnPaper: false, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "courtyard paving", x: 0.025, y: 0.235, width: 0.18, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Keep the kind part.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.026, onPaper: false, maxLines: 1)], sceneDescription: "Two unnamed young literary-fae readers of different ages exchange one flower-filled brass cup in a small old Academy courtyard. The taller youth at left bends kindly toward the shorter child at right. Four other flower cups stand separately in the foreground and the sixth cup stands on a low timber book-return pedestal behind left. An old wordless picture book lies open beside them; a gentle adult sentry walks away under a far crooked arch. Ordinary brick/timber Academy walls, bay windows, small book shelves by the door and worn paving enclose the intimate courtyard."),
        "cups-seven": .init(label: "cloud ink", note: "Which one follows you out?", labelX: 0.025, labelY: 0.105, labelWidth: 0.17, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "paper tab", x: 0.025, y: 0.225, width: 0.14, fontWidthRatio: 0.023, onPaper: true, maxLines: 1), .init(text: "Not all of them.", x: 0.77, y: 0.835, width: 0.2, fontWidthRatio: 0.03, rotation: 4, onPaper: false, maxLines: 2)], sceneDescription: "A back-view adult learner faces seven floating vision cups, three upper and four lower, emerging from an open picture book in a finite classroom."),
        "cups-eight": .init(label: "tide-worn paper", note: "What stays on this side?", labelX: 0.035, labelY: 0.145, labelWidth: 0.28, noteX: 0.26, noteY: 0.92, noteWidth: 0.65, labelFontWidthRatio: 0.029, labelRotation: -2, additional: [.init(text: "boot print", x: 0.025, y: 0.9, width: 0.22, fontWidthRatio: 0.027, onPaper: false, maxLines: 1), .init(text: "You may go.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.029, onPaper: false, maxLines: 1)], sceneDescription: "A grey-curled literary-elf reader in a practical red traveling coat walks away from a finite reading-room doorway across tidal rocks toward mountains. Eight abandoned cups sit on a two-tier stone ledge: five lower and three upper with a deliberate gap. An eclipsed moon hangs above the water. A closed bookmarked book remains inside; tide-paper, boot-print and book-moth studies fill the margins."),
        "cups-nine": .init(label: "cushion seam", note: "Nine cups. Still thirsty?", labelX: 0.025, labelY: 0.125, labelWidth: 0.24, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.027, labelRotation: -1, additional: [.init(text: "shelf peg", x: 0.025, y: 0.205, width: 0.16, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Unfold your arms a little.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.026, onPaper: false, maxLines: 1)], sceneDescription: "A content unnamed adult Deep Lore Dwarf reader sits frontally on a mended low chair in a small private library nook, arms folded with slight guardedness, feet planted apart and a well-used closed knee book resting on lap. Exactly nine brass cups form one shallow arc on a blue-cloth-draped curved timber shelf behind the head and shoulders. Low shelves of well-read books, mended cushion and a small green-blue side window make this an ordinary quiet room."),
        "cups-ten": .init(label: "rosemary", note: "Who makes room for you here?", labelX: 0.025, labelY: 0.145, labelWidth: 0.18, labelOnPaper: true, noteX: 0.5, noteY: 0.91, noteWidth: 0.46, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "quilt seam", x: 0.025, y: 0.22, width: 0.16, fontWidthRatio: 0.023, onPaper: true, maxLines: 1), .init(text: "Leave a place for one more.", x: 0.05, y: 0.875, width: 0.35, fontWidthRatio: 0.029, onPaper: false, maxLines: 2)], sceneDescription: "An older elf and younger adult raise their arms together as two fully clothed children dance below ten overhead cups; recipe books, blank storybook, hearth, ordinary furniture and a river view make a domestic library home."),
        "cups-page": .init(label: "fish scales", note: "What odd thing wants your attention?", labelX: 0.08, labelY: 0.145, labelWidth: 0.22, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -2, additional: [.init(text: "wave line", x: 0.025, y: 0.775, width: 0.23, fontWidthRatio: 0.028, onPaper: false, maxLines: 1), .init(text: "The fish has a point.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.029, onPaper: false, maxLines: 1)], sceneDescription: "An amused adult Tidecrest literary-elf messenger in a blue coat, coral waistcoat, cap and boots looks at a fish peeking from the one cup they hold. Blank folded letters and books fill the finite message room; sea and shore appear through the window. Scale, wave-line and question-mark-fishing pixie traces accompany the scene."),
        "cups-knight": .init(label: "bridle ribbon", note: "How will you carry it?", labelX: 0.025, labelY: 0.11, labelWidth: 0.23, labelOnPaper: true, noteX: 0.53, noteY: 0.9, noteWidth: 0.43, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "bridge stone", x: 0.025, y: 0.24, width: 0.2, fontWidthRatio: 0.026, onPaper: true, maxLines: 1), .init(text: "Slow enough to hear.", x: 0.36, y: 0.08, width: 0.27, fontWidthRatio: 0.029, onPaper: false, maxLines: 2)], sceneDescription: "A calm adult literary-elf mounted messenger slowly approaches right on a white horse crossing an old timber-and-stone bridge to the lending library. The rider offers one upright brass cup ahead in one hand, other hand lightly holds reins. A ribbon-tied invitation book rests in the saddle pocket. Books on the lending porch and a strapped parcel of volumes establish the Academy; a small river winds under bridge toward distant cool mountains. Wing motifs appear on the messenger's cap and boot straps."),
        "cups-queen": .init(label: "shell ridge", note: "She hasn't opened it.", labelX: 0.76, labelY: 0.835, labelWidth: 0.22, labelOnPaper: false, noteX: 0.065, noteY: 0.925, noteWidth: 0.64, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "curtain hem", x: 0.025, y: 0.53, width: 0.2, fontWidthRatio: 0.027, rotation: -2, onPaper: true, maxLines: 1), .init(text: "Keep one foot here.", x: 0.04, y: 0.09, width: 0.18, fontWidthRatio: 0.03, rotation: -2, onPaper: false, maxLines: 3)], sceneDescription: "Canonical silver-black-haired, spectacle-wearing Dr Selene Inkrest sits listening at a common-room bay window with one closed cup, shell-carved throne and dry feet near moving tide; books and her hourglass ground the scene. Margin refinement: a narrow hem specimen runs down the left edge, the shell study sits low on the right, and the small fae works on its bookmark beside the curtain rather than an upper-right vignette."),
        "cups-king": .init(label: "sea-worn stone", note: "The sea won't sit still.", labelX: 0.035, labelY: 0.11, labelWidth: 0.25, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -2, additional: [.init(text: "chair binding", x: 0.025, y: 0.77, width: 0.23, fontWidthRatio: 0.028, onPaper: false, maxLines: 1), .init(text: "He does.", x: 0.765, y: 0.265, width: 0.2, fontWidthRatio: 0.03, rotation: 4, onPaper: true, maxLines: 2)], sceneDescription: "An older silver-bearded literary elf in sea-blue practical tailoring sits calmly on a stone reading chair amid moving tidal water. He holds one cup and a short ball-topped scepter. A ship appears through the window and a small fish leaps beside the chair. Books, a stone-weighted blank ledger and finite faculty shelves establish the room; sea stones, chair bindings and a cushion-securing goblin accompany the scene."),
        "swords-ace": .init(label: "laurel leaf", note: "Name the clear thing.", labelX: 0.025, labelY: 0.12, labelWidth: 0.19, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "paper fibres", x: 0.025, y: 0.265, width: 0.19, fontWidthRatio: 0.026, onPaper: true, maxLines: 1), .init(text: "Cut carefully.", x: 0.795, y: 0.4, width: 0.18, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "An unnamed fae hand emerges from a curl of paper-white cloud over an Attestation copying desk, offering one upright long brass paper knife. A small brass crown encircles its upper blade, with laurel branch hanging at left and palm frond at right. Six isolated golden falling marks descend around the blade. Folded proof leaves and closed books lie below; a small window behind the desk reveals distant blue-violet mountains."),
        "swords-two": .init(label: "blindfold cloth", note: "What can't she see?", labelX: 0.025, labelY: 0.115, labelWidth: 0.23, labelOnPaper: true, noteX: 0.06, noteY: 0.905, noteWidth: 0.88, labelFontWidthRatio: 0.025, labelRotation: 0, additional: [.init(text: "tide line", x: 0.025, y: 0.295, width: 0.18, fontWidthRatio: 0.024, onPaper: true, maxLines: 2), .init(text: "There is a shore behind you.", x: 0.56, y: 0.87, width: 0.4, fontWidthRatio: 0.026, onPaper: false, maxLines: 2)], sceneDescription: "A still blindfolded elf reader crosses two outward-pointing brass paper knives at the chest in an ordinary moonlit shore-library room; rocky tide and crescent show through open casement."),
        "swords-three": .init(label: "paper fibres", note: "All the way through.", labelX: 0.025, labelY: 0.14, labelWidth: 0.26, noteX: 0.09, noteY: 0.915, noteWidth: 0.82, labelFontWidthRatio: 0.029, labelRotation: -1, additional: [.init(text: "rain wash", x: 0.025, y: 0.87, width: 0.22, fontWidthRatio: 0.027, onPaper: false, maxLines: 1), .init(text: "Do not tidy it yet.", x: 0.8, y: 0.785, width: 0.18, fontWidthRatio: 0.028, rotation: 4, onPaper: true, maxLines: 3)], sceneDescription: "A layered red-violet book-leaf paper heart hangs above a conservation bench, pierced by exactly three brass paper knives. Rain streaks the window behind. Books, blank repair paper and a wood press establish the finite workroom; fibre, rain-wash and sheltering moth traces accompany the scene."),
        "swords-four": .init(label: "mending", note: "The page can wait.", labelX: 0.045, labelY: 0.09, labelWidth: 0.18, labelOnPaper: true, noteX: 0.09, noteY: 0.925, noteWidth: 0.64, labelFontWidthRatio: 0.028, additional: [.init(text: "Shh.", x: 0.035, y: 0.35, width: 0.1, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 2), .init(text: "Leave it closed.", x: 0.045, y: 0.745, width: 0.25, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 2), .init(text: "rosemary", x: 0.75, y: 0.875, width: 0.23, fontWidthRatio: 0.028, rotation: -2, onPaper: false, maxLines: 1)], sceneDescription: "Cedric reclines with closed eyes and naturally folded hands in a quiet, book-filled Chapter common room. Cool morning window light and a diminished hearth suggest withdrawal and recovery. Three brass paper knives hang upright on the wall and a fourth lies horizontally on the closed table book. Foreground clutter is reduced. A tiny folded-paper helper draws the left curtain; a physical comma bookmark rests on a closed lower-left book. A small mending study sits upper-left and rosemary lower-right. The former top-right sleeping fae sticker is absent."),
        "swords-five": .init(label: "storm wash", note: "What did winning leave behind?", labelX: 0.025, labelY: 0.115, labelWidth: 0.22, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.027, labelRotation: -1, additional: [.init(text: "scored wood", x: 0.025, y: 0.245, width: 0.17, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Look at who left.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.026, onPaper: false, maxLines: 1)], sceneDescription: "Three unnamed adult Academy debaters after a bitter dispute in a reading room overlooking wind-torn water. Foreground right figure glances back with uneasy ambiguous triumph while gathering three brass paper knives: two upright in one hand against shoulder and a third angled down in other hand. Two other debaters turn away and leave toward the rear-left doorway, one head bowed. Two more brass paper knives lie separated on floor beside a table with a torn shared blank folio and displaced books."),
        "swords-six": .init(label: "ferry rope", note: "They brought it with them.", labelX: 0.035, labelY: 0.205, labelWidth: 0.23, labelOnPaper: true, noteX: 0.23, noteY: 0.9, noteWidth: 0.72, labelFontWidthRatio: 0.025, labelRotation: 0, additional: [.init(text: "river bends", x: 0.8, y: 0.31, width: 0.17, fontWidthRatio: 0.024, onPaper: true, maxLines: 2), .init(text: "One bank at a time.", x: 0.56, y: 0.87, width: 0.4, fontWidthRatio: 0.026, onPaper: false, maxLines: 2)], sceneDescription: "Three figures cross in a wooden ferry, ferryperson standing at stern and cloaked adult/child seated ahead; six upright paper knives and dry tied books travel toward a quieter bank."),
        "swords-seven": .init(label: "tent seam", note: "Whose knives are those?", labelX: 0.025, labelY: 0.13, labelWidth: 0.24, labelOnPaper: false, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "heel print", x: 0.025, y: 0.79, width: 0.18, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Two stayed behind.", x: 0.7, y: 0.79, width: 0.27, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 2, leader: [.init(x: 0.76, y: 0.78), .init(x: 0.85, y: 0.72)])], sceneDescription: "An unnamed adult literary-elf field librarian steps away with five brass paper knives and glances back at two knives left planted beside book-filled canvas tents. A book satchel and open ledger ground the field library; tent-seam, heel-print and a winged margin-fae trace accompany the scene."),
        "swords-eight": .init(label: "loose linen knot", note: "Where is the open way?", labelX: 0.025, labelY: 0.16, labelWidth: 0.22, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "mud print", x: 0.025, y: 0.29, width: 0.17, fontWidthRatio: 0.026, onPaper: true, maxLines: 1), .init(text: "The knot has room.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.026, onPaper: false, maxLines: 1)], sceneDescription: "An unnamed adult literary-elf reader stands blindfolded and loosely wrapped in linen binding tape on wet muddy ground at the Library keep approach. Exactly eight brass paper knives are planted downward in an incomplete fence, three left and five right/behind. A broad clear gap directly forward between them remains open. A fallen wordless torn map, a small box of closed books and distant crooked timber library keep establish the Academy."),
        "swords-nine": .init(label: "rose quilt patch", note: "What woke them?", labelX: 0.025, labelY: 0.145, labelWidth: 0.23, labelOnPaper: true, noteX: 0.06, noteY: 0.905, noteWidth: 0.88, labelFontWidthRatio: 0.023, labelRotation: 0, additional: [.init(text: "pillow seam", x: 0.025, y: 0.285, width: 0.2, fontWidthRatio: 0.024, onPaper: true, maxLines: 2), .init(text: "The candle is still lit.", x: 0.035, y: 0.45, width: 0.24, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 3)], sceneDescription: "One adult reader wakes hunched with face in both hands under nine horizontal wall-mounted brass paper knives; rose quilt, ordinary dorm furniture, books and restrained night lamp preserve the difficult nighttime mood."),
        "swords-ten": .init(label: "dawn wash", note: "That is all ten.", labelX: 0.025, labelY: 0.13, labelWidth: 0.26, labelOnPaper: false, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.029, labelRotation: -1, additional: [.init(text: "cloak seam", x: 0.025, y: 0.81, width: 0.22, fontWidthRatio: 0.028, onPaper: false, maxLines: 1), .init(text: "The light came anyway.", x: 0.63, y: 0.875, width: 0.31, fontWidthRatio: 0.027, onPaper: false, maxLines: 1)], sceneDescription: "A prone adult literary-fae reader lies head-right on an after-hours reading-room floor beneath a red cloak and ruined blank manuscript. Ten brass paper knives descend into the cloak and pages without gore. A broad window frames dark clouds breaking to gold dawn over still water; a few books and an extinguished lamp remain. Dawn-wash, cloak-seam and winged margin-fae traces accompany the scene."),
        "swords-page": .init(label: "wind ribbon", note: "What needs a better question?", labelX: 0.025, labelY: 0.145, labelWidth: 0.23, labelOnPaper: true, noteX: 0.09, noteY: 0.905, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "cloud edge", x: 0.025, y: 0.28, width: 0.17, fontWidthRatio: 0.025, onPaper: true, maxLines: 1), .init(text: "Hold the thought gently.", x: 0.035, y: 0.36, width: 0.23, fontWidthRatio: 0.027, onPaper: true, maxLines: 3)], sceneDescription: "A youthful adult literary-elf weather observer stands at an open weather-window study room, feet apart on uneven timber flooring, body turned right while alert gaze looks left. Both hands hold one raised brass paper knife near the right shoulder, blade rising diagonally to upper right. Strong breeze pulls dark loose hair and violet short coat across body. A strapped-shut notebook rests on a book-covered study stool; birds and racing clouds are visible beyond the open window above green hills."),
        "swords-knight": .init(label: "storm-bent leaf", note: "What is the charge leaving unseen?", labelX: 0.25, labelY: 0.12, labelWidth: 0.245, labelOnPaper: true, noteX: 0.06, noteY: 0.905, noteWidth: 0.88, labelFontWidthRatio: 0.021, labelRotation: 0, additional: [.init(text: "rein knot", x: 0.53, y: 0.12, width: 0.18, fontWidthRatio: 0.024, onPaper: true, maxLines: 2), .init(text: "Look beyond the point.", x: 0.56, y: 0.87, width: 0.4, fontWidthRatio: 0.026, onPaper: false, maxLines: 2)], sceneDescription: "An ash-haired adult elf rider leans into a leftward charge on one white horse, one raised brass paper knife and red scarf against torn clouds/bent trees; saddle books and blank escaped leaves connect the Academy delivery lane."),
        "swords-queen": .init(label: "butterfly wing", note: "Be clear without closing your hand.", labelX: 0.055, labelY: 0.962, labelWidth: 0.3, labelOnPaper: false, noteX: 0.4, noteY: 0.91, noteWidth: 0.55, labelFontWidthRatio: 0.027, labelRotation: -1, additional: [.init(text: "window frost", x: 0.86, y: 0.26, width: 0.12, fontWidthRatio: 0.025, rotation: -2, onPaper: false, maxLines: 2, leader: [.init(x: 0.955, y: 0.3), .init(x: 0.986, y: 0.32), .init(x: 0.986, y: 0.43)]), .init(text: "Leave room for an answer.", x: 0.04, y: 0.06, width: 0.24, fontWidthRatio: 0.03, rotation: -2, onPaper: false, maxLines: 2)], sceneDescription: "Professor Vivian Villanelle sits in profile facing right in a finite editorial room, black bob streaked grey, practical black jacket and wine waistcoat. She holds one upright brass paper knife and extends an open palm. Her black-glass pen is pocketed and a blank bound ribbon trails from an open book. Crescent/butterfly chair marks, clear sky and wing/frost/patching-fae margin studies preserve the Queen tableau. Margin refinement: the butterfly wing sits below the picture at left, the frost study runs down the far-right edge, and the tiny fae repairs a paper corner at the lower-right furniture edge."),
        "swords-king": .init(label: "chair carving", note: "Who does the rule make room for?", labelX: 0.025, labelY: 0.15, labelWidth: 0.24, labelOnPaper: true, noteX: 0.06, noteY: 0.905, noteWidth: 0.88, labelFontWidthRatio: 0.025, labelRotation: 0, additional: [.init(text: "boundary fold", x: 0.025, y: 0.29, width: 0.2, fontWidthRatio: 0.024, onPaper: true, maxLines: 2), .init(text: "Ask for a reason.", x: 0.775, y: 0.3, width: 0.2, fontWidthRatio: 0.028, onPaper: true, maxLines: 2)], sceneDescription: "Professor Thaddeus Mook sits front-facing and stiffly upright in a high timber committee chair carved with butterfly and crescent-moon motifs. He holds one long brass paper knife slightly angled from vertical in his right hand; his other hand rests on a thick chained and padlocked Dictionary on the adjoining table, with a loose blank correction leaf. Wind-tossed trees show through a window behind the finite Library rules committee room, full of closed volumes and an empty neighboring chair."),
        "pentacles-ace": .init(label: "garden moss", note: "What could you make with this?", labelX: 0.045, labelY: 0.899, labelWidth: 0.28, labelOnPaper: false, noteX: 0.38, noteY: 0.895, noteWidth: 0.57, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "Put a hand to it.", x: 0.055, y: 0.09, width: 0.29, fontWidthRatio: 0.034, rotation: -4, onPaper: false, maxLines: 2), .init(text: "path stone", x: 0.89, y: 0.487, width: 0.1, fontWidthRatio: 0.026, rotation: -2, onPaper: true, maxLines: 2), .init(text: "That corner.", x: 0.745, y: 0.79, width: 0.23, fontWidthRatio: 0.028, rotation: -2, onPaper: true, maxLines: 2)], sceneDescription: "An offered hand holds exactly one round hinged brass book-cover clasp bearing a five-pointed star. A flowering garden arch opens onto a path and distant mountain, above a sewn blank book. Moss now occupies a small lower-left paper strip; a narrow paving study runs down the right edge. A tiny book fae touches the lower-right book corner. Upper-left paper holds an authored aside."),
        "pentacles-two": .init(label: "parcel ribbon", note: "What can move without coming loose?", labelX: 0.04, labelY: 0.108, labelWidth: 0.29, labelOnPaper: false, noteX: 0.33, noteY: 0.91, noteWidth: 0.62, labelFontWidthRatio: 0.032, labelRotation: -1, additional: [.init(text: "wave trace", x: 0.035, y: 0.755, width: 0.24, fontWidthRatio: 0.031, rotation: -1, onPaper: false, maxLines: 1), .init(text: "Breathe between the turns.", x: 0.045, y: 0.895, width: 0.25, fontWidthRatio: 0.028, rotation: -1, onPaper: false, maxLines: 3)], sceneDescription: "A dark-curled adult literary-elf parcel dispatcher balances on one boot with a knee lifted in a sunlit book-parcel workroom. Two round hinged brass pentacle clasps, one in each hand, are linked by a green infinity ribbon. Two ships ride waves through the low harbor window. Books fill a hip satchel and plain tied parcels fill the room; frayed ribbon, wave and parcel-shifting goblin traces accompany the scene."),
        "pentacles-three": .init(label: "linen thread", note: "Three people. What does each know?", labelX: 0.04, labelY: 0.008, labelWidth: 0.24, noteX: 0.09, noteY: 0.925, noteWidth: 0.82, labelFontWidthRatio: 0.03, additional: [.init(text: "sewing needle", x: 0.05, y: 0.865, width: 0.26, fontWidthRatio: 0.028, onPaper: false, maxLines: 1), .init(text: "Leave a little slack.", x: 0.66, y: 0.875, width: 0.3, fontWidthRatio: 0.029, onPaper: false, maxLines: 2)], sceneDescription: "Vivian Villanelle and a Deep Lore Dwarf compare a folded binding plan while an adult literary elf sews a book on a frame. Three hinged pentacle book clasps hang above the sunlit classroom workbench. A winged seam fae tugs thread in the margin."),
        "pentacles-four": .init(label: "worn binding leather", note: "What is your grip keeping out?", labelX: 0.025, labelY: 0.104, labelWidth: 0.31, labelOnPaper: true, noteX: 0.255, noteY: 0.89, noteWidth: 0.66, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "boot sole", x: 0.025, y: 0.949, width: 0.2, fontWidthRatio: 0.027, rotation: -1, maxLines: 1), .init(text: "It is very tight.", x: 0.32, y: 0.956, width: 0.55, fontWidthRatio: 0.031, rotation: 1, maxLines: 1)], sceneDescription: "A seated Deep Lore Dwarf lending clerk hugs a closed green book with crossed arms. Four pentacle-stamped brass cover clasps appear on the held book, on a small book above the cap, and on two closed volumes beneath the boots. Locked book cupboards, returned volumes and a window onto Academy rooftops surround the lending desk. A worn leather offcut, a low-left boot-sole study and a fae loosening a red string knot inhabit the margins.", transcriptOverride: "In the margin: worn binding leather. boot sole. What is your grip keeping out? It is very tight."),
        "pentacles-five": .init(label: "snow on wool", note: "Who is inside?", labelX: 0.025, labelY: 0.163, labelWidth: 0.25, labelOnPaper: true, noteX: 0.56, noteY: 0.915, noteWidth: 0.39, labelFontWidthRatio: 0.027, labelRotation: -1, additional: [.init(text: "crutch grip", x: 0.025, y: 0.355, width: 0.18, fontWidthRatio: 0.027, rotation: -1, onPaper: true, maxLines: 1), .init(text: "The door is shut.", x: 0.055, y: 0.85, width: 0.32, fontWidthRatio: 0.03, rotation: 3, onPaper: false, maxLines: 2)], sceneDescription: "Two weathered adult literary-fae travelers pass a snow-covered library porch, one supported by two wooden crutches with a wrapped lower leg, the other hunched in an ochre cloak carrying books. Five hinged pentacle disks glow in a 1-2-2 window before shelves of books; a nearby door remains closed. Snowy wool and a gripping hand appear at left; a tiny pointed-eared, green-capped fae holds a dry blank scrap at upper-right."),
        "pentacles-six": .init(label: "apron mending", note: "Can help leave both people standing?", labelX: 0.025, labelY: 0.122, labelWidth: 0.21, labelOnPaper: false, noteX: 0.09, noteY: 0.92, noteWidth: 0.82, labelFontWidthRatio: 0.027, labelRotation: 0, additional: [.init(text: "scale cords", x: 0.035, y: 0.84, width: 0.25, fontWidthRatio: 0.031, rotation: -1, onPaper: false, maxLines: 1), .init(text: "Ask what they need.", x: 0.035, y: 0.225, width: 0.22, fontWidthRatio: 0.028, rotation: -1, onPaper: true, maxLines: 2)], sceneDescription: "Ambrose Trencher, broad and bearded under a hairnet, stands behind the kitchen lending counter with a cookbook under his arm and wooden spoon at his apron. He holds balance scales and gives rectangular paper tokens to two lower-seated readers, an older literary elf and a dwarf. Six hinged pentacle clasps occupy the wall above. Wrapped cookbooks, repair ledger, apron stitches, scale cords and recipe-returning fae complete the room."),
        "pentacles-seven": .init(label: "vine tendril", note: "Is this still what you mean to grow?", labelX: 0.025, labelY: 0.112, labelWidth: 0.2, labelOnPaper: false, noteX: 0.07, noteY: 0.905, noteWidth: 0.86, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "tool-handle grain", x: 0.025, y: 0.22, width: 0.2, fontWidthRatio: 0.023, rotation: -1, onPaper: true, maxLines: 2), .init(text: "Look before the next row.", x: 0.58, y: 0.87, width: 0.37, fontWidthRatio: 0.026, rotation: -1, onPaper: false, maxLines: 2)], sceneDescription: "Lysander Mosswood pauses in the Mossbloom reading garden, chin and both hands resting on the plain wooden top of a garden hoe, looking down at the vine he has tended. Six round pentacle-stamped brass cover clasps hang separately from short leather bookbinding tabs among a leafy vine at left, with one more clasp on a small low open-sided harvest tray at his feet. A planted wordless book feeds moss by the vine roots; a reading bench and ordinary garden bookshelves hold worn volumes."),
        "pentacles-eight": .init(label: "sewn signatures", note: "Let the next one teach your hands.", labelX: 0.025, labelY: 0.145, labelWidth: 0.245, labelOnPaper: true, noteX: 0.09, noteY: 0.91, noteWidth: 0.82, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "bench wear", x: 0.84, y: 0.359, width: 0.145, fontWidthRatio: 0.025, rotation: -1, onPaper: true, maxLines: 1), .init(text: "A little roughness stays.", x: 0.55, y: 0.869, width: 0.4, fontWidthRatio: 0.027, rotation: -1, onPaper: false, maxLines: 1)], sceneDescription: "A sturdy adult dwarf bookbinder with braided hair, beard and spectacles engraves a brass pentacle clasp at a worn bench. Seven completed five-point hinged clasps hang on the upright board and one lies under the punch, eight total. Sewn signatures and trial bindings fill a finite daylight classroom with town beyond the window. Linen, scarred wood and a small winged fae carrying cloth offcuts occupy the margins."),
        "pentacles-nine": .init(label: "grape leaf", note: "Can you enjoy what you have tended?", labelX: 0.6, labelY: 0.89, labelWidth: 0.28, labelOnPaper: false, noteX: 0.045, noteY: 0.945, noteWidth: 0.91, labelFontWidthRatio: 0.028, labelRotation: -1, additional: [.init(text: "falcon feather", x: 0.04, y: 0.15, width: 0.27, fontWidthRatio: 0.028, rotation: -2, onPaper: false, maxLines: 1), .init(text: "Leave a little wild.", x: 0.195, y: 0.035, width: 0.14, fontWidthRatio: 0.028, rotation: -2, onPaper: false, maxLines: 3)], sceneDescription: "Gwendolyn Mythwright stands in moss-green practical field clothes in a glass-and-timber conservatory reading garden, a hooded falcon on her raised glove and a moss-edged notebook at her hip. Nine hinged pentacle clasps hang among grapes: six left and three right. A distant Academy home, plant folio, snail, grape-leaf specimen, falcon feather and book moth complete the cultivated scene. Margin refinement: the feather study sits high on the left and the grape-leaf study low in the middle; no additional creature or pentacle is introduced."),
        "pentacles-ten": .init(label: "binding cloth", note: "What will outlast your own hands?", labelX: 0.018, labelY: 0.108, labelWidth: 0.17, labelOnPaper: true, noteX: 0.075, noteY: 0.935, noteWidth: 0.86, labelFontWidthRatio: 0.022, labelRotation: -1, additional: [.init(text: "door joint", x: 0.025, y: 0.226, width: 0.21, fontWidthRatio: 0.028, rotation: -1, onPaper: true, maxLines: 1), .init(text: "Keep a place here.", x: 0.055, y: 0.875, width: 0.36, fontWidthRatio: 0.03, rotation: 3, onPaper: false, maxLines: 2)], sceneDescription: "A white-haired elder, two adult literary elves and a child share a worn storybook with two white dogs in the Book Burrow. Ten pentacle-stamped brass cover clasps form four center, three left and three right positions around the timber arch and on a closed floor volume. Books, lamps, blankets and mended cloth fill the room. A woven binding-cloth specimen, timber door joint and goblin sewing a blank family album inhabit the margins."),
        "pentacles-page": .init(label: "furrowed earth", note: "Give it your full attention.", labelX: 0.025, labelY: 0.127, labelWidth: 0.27, labelOnPaper: false, noteX: 0.4, noteY: 0.9, noteWidth: 0.56, labelFontWidthRatio: 0.026, labelRotation: -1, additional: [.init(text: "book cloth", x: 0.565, y: 0.099, width: 0.165, fontWidthRatio: 0.026, rotation: -1, onPaper: false, maxLines: 1), .init(text: "This is worth learning.", x: 0.77, y: 0.72, width: 0.2, fontWidthRatio: 0.028, rotation: -1, onPaper: true, maxLines: 3)], sceneDescription: "An auburn-haired, freckled young adult elf in a red cap stands in a finite bookbinding study, lifting one five-point hinged brass clasp in both hands and studying it. A blank uncased sewn book and book cloth wait on the desk; green field, furrowed earth, trees and distant hills show through the open garden door. Furrows and cloth samples sit above, with a tiny punctuation pixie at a torn paper edge beside a physical comma."),
        "pentacles-knight": .init(label: "horsehair tie", note: "What can you carry steadily?", labelX: 0.075, labelY: 0.117, labelWidth: 0.3, labelOnPaper: false, noteX: 0.45, noteY: 0.89, noteWidth: 0.5, labelFontWidthRatio: 0.031, labelRotation: 0, additional: [.init(text: "field furrows", x: 0.105, y: 0.875, width: 0.25, fontWidthRatio: 0.028, rotation: -1, onPaper: false, maxLines: 1), .init(text: "Ready is a kind of work.", x: 0.775, y: 0.19, width: 0.2, fontWidthRatio: 0.027, rotation: -1, onPaper: true, maxLines: 3)], sceneDescription: "A sturdy Deep Lore Dwarf parcel steward sits quietly on a still dark horse in the Academy book-delivery yard, wearing archive-blue working layers and worn silver riding armor. He offers one hinged brass pentacle clasp. Keys, lantern, sewn book parcels and visible volumes hang at the saddle; an open gate frames plowed field furrows. Horsehair, field and parcel-cord fae traces accompany the scene."),
        "pentacles-queen": .init(label: "rabbit track", note: "Even the apron got mended.", labelX: 0.025, labelY: 0.124, labelWidth: 0.225, labelOnPaper: true, noteX: 0.085, noteY: 0.9, noteWidth: 0.85, labelFontWidthRatio: 0.027, labelRotation: -1, additional: [.init(text: "apron hem", x: 0.025, y: 0.249, width: 0.21, fontWidthRatio: 0.028, rotation: -1, onPaper: true, maxLines: 1), .init(text: "Mind the washing-up.", x: 0.3, y: 0.958, width: 0.57, fontWidthRatio: 0.031, rotation: 1, maxLines: 1)], sceneDescription: "Professor Lydia Boggle smiles down at one pentacle-stamped brass cover clasp cradled by both hands on the book in her lap. Her grey-black curls, round spectacles, blue coat, marigold waistcoat and small glass glint-lens accompany the work. One rabbit sits beside the goat-and-fruit-carved chair. Books, thread, linen scraps and unfinished bindings fill the Mossbloom common-room repair table beside an open garden window. Rabbit hopping impressions, a patched apron hem and a goblin stitching a blank recipe leaf inhabit the margins."),
        "pentacles-king": .init(label: "grape tendril", note: "What does having enough let you tend?", labelX: 0.035, labelY: 0.144, labelWidth: 0.18, labelOnPaper: false, noteX: 0.09, noteY: 0.89, noteWidth: 0.82, labelFontWidthRatio: 0.025, labelRotation: -1, additional: [.init(text: "desk joint", x: 0.795, y: 0.353, width: 0.185, fontWidthRatio: 0.027, rotation: -1, onPaper: false, maxLines: 1), .init(text: "Keep it growing.", x: 0.675, y: 0.864, width: 0.28, fontWidthRatio: 0.028, rotation: -1, onPaper: false, maxLines: 1)], sceneDescription: "A broad mature elf Book Burrow steward with silver curls and beard sits on a bull-head-and-vine chair at a worn desk of maintained books and a blank folio. One hand holds a plain orb scepter and the other steadies one five-point hinged brass clasp on a closed volume. Grapes and white flowers grow around the room; a town shows beyond the window. Tendril and wood-joint studies flank a tiny book fae tending a vine by a closed account book."),
    ]
    private static let illustratedSubjects: [String: [String]] = [
        "major-00": ["adventure", "beginning", "blank-page", "book-bundle", "book-moth", "cliff", "dog", "library-door", "risk", "threshold", "trust", "white-rose"],
        "major-01": ["agency", "catalog-card", "library", "making", "penny-blackletter", "printing-desk", "printing-press", "punctuation-pixie", "rose", "skill", "tools", "white-lily", "writing"],
        "major-02": ["guarded-book", "intuition", "literary-elf", "moon", "palm", "pomegranate", "question-mark", "restricted-reading-room", "scroll", "secret", "silence", "unseelie", "veil", "veil-hem"],
        "major-03": ["abundance", "botanical-book", "conservatory", "creation", "flowing-water", "garden", "growth", "mossbloom-common-room", "nurture", "paper-sprite", "plant-tie", "venus-heart", "wheat"],
        "major-04": ["authority", "book", "boundary", "great-hall", "head-table", "marginalia-goblin", "mountain", "oak-grain", "orb", "ram", "scepter", "seraphina-thorne", "stewardship", "structure", "wax-impression", "wax-seal"],
        "major-05": ["binding-leather", "book-ribbon", "chained-dictionary", "classroom", "crossed-keys", "keys", "learning", "lexical-diversity", "punctuation-pixie", "teacher", "teaching", "thaddeus-mook", "tradition"],
        "major-06": ["apple", "book-fae", "choice", "flame", "joining-stitch", "library", "literary-elf", "love", "relationship", "seelie", "serpent", "shared-book", "unseelie", "values"],
        "major-07": ["cart-lashing", "wheel-spoke", "catalogue-sprite", "book-parcel", "courtyard", "book-cart", "books", "star-canopy", "paper-beasts"],
        "major-08": ["paper-lion", "lion-mane", "flower-cord", "classroom", "luna-wispwood", "books", "mountain", "infinity-sign"],
        "major-09": ["book-moth", "guidance", "lantern", "library", "mist", "old-keys", "search", "solitude", "under-stacks", "walking-staff"],
        "major-10": ["catalogue-spindle", "axle-pin", "catalogue-wheel", "book-witness", "serpent", "sphinx", "jackal-fae", "winged-readers", "catalogue-hall", "books"],
        "major-11": ["square-clasp", "paper-edge", "paper-sprite", "correction-leaf", "penny-blackletter", "balanced-scales", "paper-knife", "ledger", "books", "attestation-room"],
        "major-12": ["ankle-loop", "door-hinge", "floor-book", "professor-permancer", "classroom", "books", "halo", "story-door", "suspended-reader"],
        "major-13": ["old-paper-garden", "white-rose-petal", "fallen-leaf", "book-moth", "skeletal-rider", "white-horse", "black-banner", "fallen-crown", "river", "library-towers", "sunrise", "books"],
        "major-14": ["iris-petal", "dye-swatch", "colour-sprite", "swatch-book", "eleanor-euphony", "inkworks", "water-channel", "two-cups", "irises", "books"],
        "major-15": ["loose-chain-link", "broken-seal", "book-bargain", "open-book-clasps", "horned-fae", "bat-wings", "downward-torch", "loose-chains", "lending-alcove", "books"],
        "major-16": ["paper-fibres", "split-timber", "archive-tower", "two-ink-fae", "lightning", "displaced-crown", "two-falling-scholars", "twenty-two-flame-drops", "exposed-shelves", "books", "visible-foundation"],
        "major-17": ["water-ripples", "feather-trace", "book-moth", "drying-pages", "reading-garden", "pool", "pouring-jugs", "literary-elf", "bird", "books", "stars"],
        "major-18": ["reeds", "tide-mark", "tidal-library", "folded-map", "profile-moon", "fifteen-gold-drops", "domestic-dog", "wolf", "emerging-crayfish", "winding-path", "books", "puddle-fae"],
        "major-19": ["sunflower-petal", "banner-seam", "storybook", "reading-window", "young-literary-fae", "white-horse", "faced-sun", "red-banner", "red-feather", "four-sunflowers", "courtyard", "books", "stitch-hanging-pixie"],
        "major-20": ["trumpet-ribbon", "coffer-hinge", "paper-sprite", "vault-of-doors", "book-coffers", "trumpet", "six-readers", "mountains", "water", "books"],
        "major-21": ["laurel-leaf", "wreath-tie", "handmade-book", "completion-gallery", "literary-fae-dancer", "oval-wreath", "two-dip-pens", "winged-human", "winged-eagle", "winged-bull", "winged-lion", "books", "knot-tying-fae"],
        "wands-ace": ["wood-bud", "paper-curl", "first-mark-paper", "new-writer-desk", "one-dip-pen", "offered-hand", "paper-cloud", "river", "castle", "books", "paper-sprite"],
        "wands-two": ["map-fold", "window-latch", "map-fae", "soren-ng", "planning-globe", "map-classroom", "books", "two-dip-pens", "sea"],
        "wands-three": ["sailcloth", "parcel-cord", "bound-travel-records", "shipping-balcony", "literary-elf", "three-dip-pens", "three-ships", "books", "parcel-tying-goblin"],
        "wands-four": ["book", "celebration", "communal-reading-table", "dip-pen", "garland", "great-hall", "ivy-leaf", "literary-elf", "milestone", "pen", "ribbon-knot", "serenity-brown", "welcome", "zara-finch"],
        "wands-five": ["bookish-imp", "classroom", "competition", "interruption", "paper-scraps", "pen", "practice-chalk", "sleeve-patch"],
        "wands-six": ["laurel-sprig", "binding-cords", "book-parcel-fae", "finn-bridges", "six-dip-pens", "white-horse", "library-entrance", "books", "public-recognition"],
        "wands-seven": ["book-trolley", "worn-boot-sole", "threshold-grain", "shoelace", "zara-finch", "seven-dip-pens", "raised-threshold", "mismatched-shoes", "books", "shoelace-goblin"],
        "wands-eight": ["flight-marks", "cloud-wash", "margin-moth", "courier-window"],
        "wands-nine": ["mended-sleeve", "bandage-fold", "stool-propping-goblin", "bandaged-watcher", "nine-dip-pens", "return-desk", "repaired-folio", "books", "literary-elf"],
        "wands-ten": ["bindery-door", "binding-cord", "burden", "dip-pen", "library", "load", "marginalia-goblin", "pen", "responsibility", "stair"],
        "wands-page": ["blank-notebook", "salamander-cloth", "feather-trace", "question-mark", "adult-literary-elf", "one-dip-pen", "first-year-study-room", "dry-hills", "books", "punctuation-pixie"],
        "wands-knight": ["saddle-cord", "wind-trace", "saddle-folio", "delivery-lane", "professor-kyle-momort", "one-dip-pen", "rearing-horse", "salamander-motif", "books", "blank-pages", "academy-route"],
        "wands-queen": ["sunflower-seed", "cat-paw-print", "book-cushion-goblin", "emberheart-common-room", "literary-elf-host", "one-dip-pen", "sunflower", "black-cat", "lion-carved-chair", "books"],
        "wands-king": ["folded-signatures", "binding-cord", "chair-joint", "oil-flask", "deep-lore-dwarf", "one-dip-pen", "lion-chair", "salamander", "faculty-workroom", "books"],
        "cups-ace": ["water-lily", "ripple-rings", "margin-moth", "garden-reading-bench", "one-cup", "five-streams", "dove", "white-petal", "offered-hand", "lily-pool", "books"],
        "cups-two": ["shared-ribbon", "table-grain", "thread-joining-paper-fae", "seelie-elf", "unseelie-elf", "two-cups", "winged-lion", "caduceus", "shared-book", "tidecrest-common-room", "reciprocal-exchange"],
        "cups-three": ["rosemary-sprig", "apron-patch", "recipe-leaf", "story-table", "ambrose-trencher", "three-cups", "kitchen", "cookbooks", "celebration", "rosemary", "recipe-fae"],
        "cups-four": ["window-seat-bark", "leaf-shadow", "knocking-paper-fae", "book-burrow", "four-cups", "crossed-arms", "literary-elf", "offered-cup", "tree-window-seat", "books", "leaf-shadow"],
        "cups-five": ["recipe-paper-stain", "bridge-sketch", "pantry-goblin", "five-cups", "three-spilled-cups", "two-upright-cups", "grieving-literary-elf", "kitchen", "cookbooks", "bridge", "river", "house"],
        "cups-six": ["garden-flower", "courtyard-paving", "picture-book", "pressed-petal", "six-flower-cups", "young-fae", "exchanged-cup", "courtyard", "sentry", "picture-book", "white-blossoms"],
        "cups-seven": ["cloud-ink", "paper-tab", "plain-pebble", "illustrated-classroom", "seven-cups", "face-vision", "shrouded-vision", "snake", "tower", "jewels", "laurel", "dragon", "illustrated-book", "pebble-goblin"],
        "cups-eight": ["tide-worn-paper", "walking-boot-print", "margin-moth", "eight-cups", "departing-reader", "eclipsed-moon", "tidal-reading-room", "mountains", "abandoned-book"],
        "cups-nine": ["cushion-seam", "shelf-peg", "knee-book", "mended-chair", "nine-cups", "folded-arms", "dwarf-reader", "blue-cloth", "book-nook", "books", "sleeping-goblin"],
        "cups-ten": ["hearth-herb", "quilt-seam", "pantry-fae", "shared-kitchen", "ten-cups", "rainbow", "two-carers", "two-children", "kitchen", "cookbooks", "river", "home", "rosemary", "quilt"],
        "cups-page": ["fish-scale-study", "wave-line", "punctuation-pixie", "tidecrest-message-room", "adult-messenger", "one-cup", "fish", "shore", "waves", "books", "blank-letters"],
        "cups-knight": ["bridle-ribbon", "bridge-stone", "book-moth", "invitation-book", "one-cup", "white-horse", "literary-elf-messenger", "library-bridge", "book-parcel", "ribbon", "book-moth"],
        "cups-queen": ["shell-ridge", "curtain-hem", "bookmark-repair", "tidecrest-bay-window", "dr-selene-inkrest", "one-closed-cup", "shell-chair", "nymph-carving", "dry-boots", "tide", "books", "hourglass", "silk-bookmark"],
        "cups-king": ["sea-worn-stone", "chair-binding", "cushion-securing-goblin", "older-literary-elf", "one-cup", "ball-topped-scepter", "stone-reading-chair", "ship", "leaping-fish", "tidal-water", "faculty-reading-room", "books"],
        "swords-ace": ["laurel-fibre", "paper-grain", "proof-leaf", "torn-paper", "one-paper-knife", "crown", "laurel", "palm", "six-gold-marks", "offered-hand", "paper-cloud", "copying-desk", "books"],
        "swords-two": ["blindfold-cloth", "tide-line", "folded-paper-screen", "shore-quiet-room"],
        "swords-three": ["paper-heart-fibres", "rain-wash", "sheltering-book-moth", "paper-heart", "three-paper-knives", "rain", "conservation-workroom", "books"],
        "swords-four": ["book", "cedric-stonebrook", "chapter-common-room", "closed-book", "comma-bookmark", "curtain", "daybed", "hearth", "mending", "paper-helper", "paper-knife", "pause", "quiet-hours", "recovery", "rest", "rosemary", "withdrawal"],
        "swords-five": ["wind-torn-paper", "table-scratch", "shared-folio", "unlettered-scraps", "five-paper-knives", "two-departing-readers", "debate-room", "torn-folio", "stormwater", "books"],
        "swords-six": ["ferry-rope", "river-bends", "book-parcel", "library-ferry-landing"],
        "swords-seven": ["tent-seam", "heel-print", "inventory-sheet-goblin", "literary-elf", "five-carried-knives", "two-planted-knives", "backward-glance", "field-library", "books", "winged-margin-fae"],
        "swords-eight": ["loose-cloth-knot", "mud-print", "torn-map", "paper-loop", "eight-paper-knives", "blindfold", "loose-linen-bindings", "open-path", "archive-keep", "book-crate"],
        "swords-nine": ["rose-quilt-patch", "pillow-seam", "book-moth", "night-dorm"],
        "swords-ten": ["dawn-wash", "cloak-seam", "climbing-margin-moth", "prone-reader", "ten-paper-knives", "red-cloak", "ruined-manuscript", "dawn", "water", "books"],
        "swords-page": ["wind-tugged-cloth", "cloud-edge", "strapped-notebook", "weather-window", "one-paper-knife", "literary-elf-observer", "wind", "birds", "clouds", "closed-notebook", "weather-window"],
        "swords-knight": ["storm-bent-leaf", "rein-knot", "sheltered-blank-map", "storm-delivery-road"],
        "swords-queen": ["butterfly-wing-study", "window-frost", "paper-corner-book-fae", "professor-vivian-villanelle", "one-paper-knife", "open-palm", "butterfly-chair", "crescent", "bird", "editorial-room", "books"],
        "swords-king": ["chair-carving", "boundary-fold", "chained-dictionary", "correction-leaf"],
        "pentacles-ace": ["book-clasp", "book-fae", "garden-arch", "garden-moss", "hinged-clasp", "path-stone", "sewn-book"],
        "pentacles-two": ["literary-elf", "parcel-dispatcher", "book-parcel", "dispatch-room", "book-satchel", "harbor", "two-ships", "infinity-ribbon", "hinged-book-clasp", "parcel-ribbon", "wave-trace", "margin-goblin"],
        "pentacles-three": ["artisan", "book", "book-clasp", "bookbinding", "classroom", "collaboration", "craft", "deep-lore-dwarf", "linen-thread", "literary-elf", "plans", "sewing-needle", "vivian-villanelle"],
        "pentacles-four": ["deep-lore-dwarf", "lending-clerk", "closed-lending-desk", "closed-book", "locked-book-cupboard", "book-cover-clasps", "binding-leather", "boot-sole", "string-knot", "academy-rooftops"],
        "pentacles-five": ["snowy-porch", "crutches", "lit-window", "route-scrap"],
        "pentacles-six": ["ambrose-trencher", "cafeteria-cook", "kitchen", "cookbook", "lending-counter", "repair-ledger", "balance-scales", "paper-token", "literary-elf", "deep-lore-dwarf", "hinged-book-clasp", "apron-mending", "scale-cords", "pantry-fae"],
        "pentacles-seven": ["vine-tendril", "tool-handle-grain", "blank-seed-label", "planted-book", "lysander-mosswood", "mossbloom", "garden-hoe", "harvest-tray", "reading-garden"],
        "pentacles-eight": ["sewn-signatures", "clasp-board", "binding-offcuts", "town-window"],
        "pentacles-nine": ["gwendolyn-mythwright", "mossbloom", "conservatory", "reading-garden", "grape-leaf", "grape-trellis", "hooded-falcon", "falcon-feather", "moss-edged-notebook", "plant-folio", "book-moth", "snail", "hinged-book-clasp"],
        "pentacles-ten": ["book-burrow", "literary-fae-household", "elder", "child", "two-white-dogs", "shared-storybook", "book-cover-clasps", "family-binding-cloth", "door-joint", "family-album", "timber-arch", "blankets"],
        "pentacles-page": ["raised-clasp", "furrowed-earth", "book-cloth", "paper-tab"],
        "pentacles-knight": ["deep-lore-dwarf", "parcel-steward", "delivery-yard", "dark-horse", "riding-armor", "sewn-book-parcel", "lantern", "archive-keys", "plowed-field", "horsehair-tie", "field-furrows", "parcel-cord", "margin-fae", "hinged-book-clasp"],
        "pentacles-queen": ["professor-lydia-boggle", "mossbloom-common-room", "repair-table", "rabbit", "rabbit-track", "apron-hem", "linen-scraps", "unfinished-book", "book-cover-clasp", "glint-lens", "goat-carving", "garden"],
        "pentacles-king": ["bull-chair", "grape-tendril", "desk-joint", "account-book"],
    ]
    // END AUTHORED UNWRITTEN MARGINALIA

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

    static func card(assetName: String) -> TarotCardDefinition? {
        all.first { $0.assetName == assetName }
    }

    /// Pictures encountered between Pages are illustrations, never a draw or
    /// evidence about the reader. They share the existing plate history.
    static var interleafIllustrations: [InterleafIllustration] {
        all.map { card in
            InterleafIllustration(
                id: "tarot::\(card.id)", assetName: card.assetName,
                title: "\(card.name) · The Unwritten Deck",
                tags: pictureSubjects(for: card.id)
            )
        }
    }

    /// Literal subjects from the two neighboring Pages. Whole words and
    /// explicit phrases only: no mood inference, model work or archive search.
    static func interleafSubjectTags(in text: String) -> [String] {
        let words = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let wordSet = Set(words)
        let joined = " " + words.joined(separator: " ") + " "
        let vocabulary = Set(all.flatMap { pictureSubjects(for: $0.id) })
        return vocabulary.filter { subject in
            let phrase = subject.replacingOccurrences(of: "-", with: " ")
            let plural: String
            if phrase.hasSuffix("knife") {
                plural = String(phrase.dropLast(2)) + "ves"
            } else if phrase.hasSuffix("leaf") {
                plural = String(phrase.dropLast()) + "ves"
            } else {
                plural = phrase + "s"
            }
            if phrase.contains(" ") {
                return joined.contains(" \(phrase) ") || joined.contains(" \(plural) ")
            }
            return wordSet.contains(phrase) || wordSet.contains(plural)
        }.sorted()
    }

    /// Installed art supplies its own visible subjects; superseded locations
    /// such as the chapel in Four of Swords must not keep matching Pages.
    private static func pictureSubjects(for cardID: String) -> [String] {
        Array(Set(illustratedSubjects[cardID] ?? interleafSubjects[cardID] ?? [])).sorted()
    }

    /// Card-specific subjects keep the full 78-card cabinet from reducing
    /// every work Page to Pentacles or every night Page to the same Moon.
    private static let interleafSubjects: [String: [String]] = [
        "major-00": ["beginning", "new-start", "adventure", "threshold", "library", "dog", "rose"],
        "major-01": ["skill", "tools", "writing", "making", "agency"],
        "major-02": ["intuition", "silence", "secret", "moon", "veil"],
        "major-03": ["garden", "growth", "nurture", "wheat", "creation"],
        "major-04": ["boundary", "structure", "authority", "mountain", "stewardship"],
        "major-05": ["teaching", "tradition", "learning", "teacher", "keys"],
        "major-06": ["relationship", "choice", "values", "garden", "love"],
        "major-07": ["direction", "journey", "movement", "travel", "opposites"],
        "major-08": ["courage", "patience", "lion", "compassion", "gentleness"],
        "major-09": ["solitude", "lantern", "search", "guidance", "mountain"],
        "major-10": ["change", "cycle", "wheel", "turning", "fortune"],
        "major-11": ["justice", "balance", "truth", "fairness", "consequence"],
        "major-12": ["pause", "waiting", "perspective", "surrender", "stillness"],
        "major-13": ["ending", "autumn", "release", "death", "renewal"],
        "major-14": ["integration", "proportion", "healing", "balance", "irises"],
        "major-15": ["attachment", "appetite", "chain", "shadow", "bargain"],
        "major-16": ["rupture", "collapse", "lightning", "storm", "tower"],
        "major-17": ["hope", "renewal", "star", "pool", "bird"],
        "major-18": ["moon", "night", "dream", "uncertainty", "wolf", "path"],
        "major-19": ["sun", "joy", "vitality", "sunflower", "horse", "garden"],
        "major-20": ["awakening", "reckoning", "trumpet", "answering", "call"],
        "major-21": ["completion", "integration", "dance", "laurel", "whole"],
        "wands-ace": ["spark", "beginning", "initiative", "pen"],
        "wands-two": ["planning", "possibility", "world", "battlement"],
        "wands-three": ["expansion", "waiting", "ship", "horizon"],
        "wands-four": ["welcome", "milestone", "celebration", "garland"],
        "wands-five": ["friction", "practice", "contest", "rehearsal"],
        "wands-six": ["recognition", "success", "praise", "laurel"],
        "wands-seven": ["defense", "conviction", "high-ground", "boundary"],
        "wands-eight": ["speed", "message", "alignment", "river"],
        "wands-nine": ["endurance", "readiness", "fence", "watcher"],
        "wands-ten": ["burden", "responsibility", "load", "town"],
        "wands-page": ["curiosity", "message", "discovery", "pen"],
        "wands-knight": ["pursuit", "heat", "impulse", "horse"],
        "wands-queen": ["confidence", "warmth", "sunflower", "cat"],
        "wands-king": ["vision", "leadership", "fire", "salamander"],
        "cups-ace": ["feeling", "openness", "water", "dove"],
        "cups-two": ["mutuality", "exchange", "relationship", "partnership"],
        "cups-three": ["friendship", "celebration", "joy", "flowers"],
        "cups-four": ["withdrawal", "reevaluation", "tree", "refusal"],
        "cups-five": ["grief", "loss", "bridge", "river"],
        "cups-six": ["memory", "childhood", "return", "courtyard"],
        "cups-seven": ["fantasy", "options", "visions", "choice"],
        "cups-eight": ["leaving", "search", "moon", "mountain"],
        "cups-nine": ["satisfaction", "wish", "enough", "abundance"],
        "cups-ten": ["belonging", "family", "home", "river"],
        "cups-page": ["surprise", "imagination", "fish", "shore"],
        "cups-knight": ["invitation", "romance", "feeling", "horse"],
        "cups-queen": ["empathy", "listening", "water", "shell"],
        "cups-king": ["steadiness", "diplomacy", "sea", "ship"],
        "swords-ace": ["clarity", "truth", "decision", "crown"],
        "swords-two": ["stalemate", "decision", "blindfold", "sea"],
        "swords-three": ["heartbreak", "grief", "rain", "heart"],
        "swords-four": ["rest", "recovery", "pause", "chapel"],
        "swords-five": ["victory", "aftermath", "conflict", "departure"],
        "swords-six": ["passage", "boat", "crossing", "journey"],
        "swords-seven": ["strategy", "concealment", "tent", "secrecy"],
        "swords-eight": ["restriction", "blindfold", "path", "bond"],
        "swords-nine": ["anxiety", "nightmare", "bed", "night"],
        "swords-ten": ["ending", "exhaustion", "dawn", "stillness"],
        "swords-page": ["inquiry", "alertness", "wind", "question"],
        "swords-knight": ["haste", "conviction", "storm", "horse"],
        "swords-queen": ["discernment", "independence", "honesty", "butterfly"],
        "swords-king": ["reason", "judgment", "authority", "ethics"],
        "pentacles-ace": ["opportunity", "beginning", "garden", "arch"],
        "pentacles-two": ["adaptation", "juggling", "demands", "ship"],
        "pentacles-three": ["craft", "collaboration", "plans", "artisan"],
        "pentacles-four": ["holding", "control", "security", "book-clasp"],
        "pentacles-five": ["hardship", "exclusion", "shelter", "snow"],
        "pentacles-six": ["giving", "reciprocity", "generosity", "scales"],
        "pentacles-seven": ["patience", "cultivation", "harvest", "garden"],
        "pentacles-eight": ["practice", "apprenticeship", "work", "bench"],
        "pentacles-nine": ["independence", "pleasure", "grapes", "falcon"],
        "pentacles-ten": ["legacy", "home", "family", "generations", "arch"],
        "pentacles-page": ["study", "learning", "field", "concentration"],
        "pentacles-knight": ["reliability", "patience", "work", "horse"],
        "pentacles-queen": ["care", "resourcefulness", "garden", "rabbit"],
        "pentacles-king": ["stewardship", "abundance", "grapes", "tending"]
    ]

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
                body: "All 78 cards are in here. Open the deck. Draw one card, or draw three: Root, Weather, Door. Serenity reads beside you. Chance chooses the cards. You decide what fits. Nothing here predicts your life.",
                metadata: [
                    "source": source.id,
                    "tags": "tarot,reflection,rider-waite-smith",
                    "tarotDeckVersion": TarotDeck.version,
                    "automaticRecurrenceSlot": "\(BookDay.id(for: now)):tarot",
                    // The deck advances daily, but this invitation's copy does
                    // not: without a declared rest the identical card face took
                    // the desk every day for a fortnight. The draw is still
                    // there whenever the reader goes looking for it.
                    "automaticRepeatRestDays": "3",
                    "dailyTarot": "true"
                ]
            )
        )
    }
}
