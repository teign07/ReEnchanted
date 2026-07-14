import Foundation

struct InsideCoverState: Codable, Equatable {
    var generatedAt: String
    var player: String
    var title: String
    var day: String
    var block: String
    var now: String
    var next: String
    var club: String
    var practice: String
    var practicePrompt: String
    var classroom: ClassroomState?
    var health: HealthState?
    var note: String
    var image: String
    var imageData: String?
    var openURL: String
    var readerLexicon: ReaderLexicon = ReaderLexicon()

    static let fallback = InsideCoverState(
        generatedAt: "",
        player: "Reader",
        title: "ReEnchanted",
        day: "The Academy is listening",
        block: "Between Pages",
        now: "No fresh state imported",
        next: "Import widget-state.json",
        club: "",
        practice: "Open the Book",
        practicePrompt: "Run scripts/widget-state.py, then import the JSON into this app.",
        classroom: nil,
        health: HealthState(status: "WATCH", score: 0, phrase: "The shelves are waiting for ink."),
        note: "The Book is awake behind the glass.",
        image: "",
        imageData: nil,
        openURL: "telegram://"
    )
}

extension InsideCoverState {
    private enum CodingKeys: String, CodingKey {
        case generatedAt, player, title, day, block, now, next, club, practice, practicePrompt
        case classroom, health, note, image, imageData, openURL, readerLexicon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(String.self, forKey: .generatedAt)
        player = try c.decode(String.self, forKey: .player)
        title = try c.decode(String.self, forKey: .title)
        day = try c.decode(String.self, forKey: .day)
        block = try c.decode(String.self, forKey: .block)
        now = try c.decode(String.self, forKey: .now)
        next = try c.decode(String.self, forKey: .next)
        club = try c.decode(String.self, forKey: .club)
        practice = try c.decode(String.self, forKey: .practice)
        practicePrompt = try c.decode(String.self, forKey: .practicePrompt)
        classroom = try c.decodeIfPresent(ClassroomState.self, forKey: .classroom)
        health = try c.decodeIfPresent(HealthState.self, forKey: .health)
        note = try c.decode(String.self, forKey: .note)
        image = try c.decode(String.self, forKey: .image)
        imageData = try c.decodeIfPresent(String.self, forKey: .imageData)
        openURL = try c.decode(String.self, forKey: .openURL)
        readerLexicon = try c.decodeIfPresent(ReaderLexicon.self, forKey: .readerLexicon) ?? ReaderLexicon()
    }
}

struct ClassroomState: Codable, Equatable {
    var className: String
    var professor: String
    var lesson: String
    var segment: String
    var active: Bool
}

struct HealthState: Codable, Equatable {
    var status: String
    var score: Int
    var phrase: String
}

struct PageBeliefProfile: Identifiable, Codable, Equatable {
    var sourceID: String
    var type: BookPageType
    var title: String
    var belief: Int
    var narrativeWeight: Int
    var cadence: String
    var note: String

    var id: String { sourceID }

    var curationWeight: Int {
        narrativeWeight + belief
    }
}

struct LorePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: ContentPackAvailability
    var themes: [String]
    var snippets: [ReferenceSnippet]
}

struct WritingVoiceProfile: Codable, Equatable {
    var register: String
    var rhythm: String
    var diction: [String]
    var habits: [String]
    var avoid: [String]

    var promptDescription: String {
        let dictionLine = diction.isEmpty ? "Use vocabulary implied by the character." : diction.joined(separator: ", ")
        let habitLine = habits.isEmpty ? "Let the character's habits appear subtly." : habits.joined(separator: "; ")
        let avoidLine = avoid.isEmpty ? "Do not overperform the voice." : avoid.joined(separator: "; ")
        return """
        Register: \(register)
        Rhythm: \(rhythm)
        Diction: \(dictionLine)
        Habits: \(habitLine)
        Avoid: \(avoidLine)
        """
    }
}

enum StoryThreadPhase: String, Codable, Equatable, CaseIterable {
    case seed
    case returning
    case rising
    case climax
    case resolution
    case fading
}

enum NarrativeRelationshipKind: String, Codable, Equatable, CaseIterable {
    case authorship
    case attention
    case stewardship
    case care
    case correspondence
    case realityBleed
    case companionship
    case tension
}

enum SupportFacultyChartKind: String, Codable, Equatable, CaseIterable {
    case difficultPage
    case bodyMarginalia
}

struct SupportFacultyChart: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var kind: SupportFacultyChartKind
    var facultyEntityID: String
    var facultyName: String
    var pageTitle: String
    var roleTitle: String
    var purpose: String
    var reads: [String]
    var allowedUses: [String]
    var forbiddenUses: [String]
    var invitations: [String]
    var closureConditions: [String]
    var artifactTypes: [String]
    var safetyLine: String
    var tags: [String]
}

struct SupportFacultyPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: ContentPackAvailability
    var charts: [SupportFacultyChart]
}

enum SupportFacultyPackRegistry {
    static let corePackID = "core-support-faculty"

    static let bundledPacks: [SupportFacultyPack] = [
        SupportFacultyPack(
            id: corePackID,
            displayName: "Core Support Faculty Pack",
            version: "0.1",
            author: "The Book",
            availability: .bundledFree,
            charts: coreCharts
        )
    ]

    static var enabledPacks: [SupportFacultyPack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var charts: [SupportFacultyChart] {
        enabledPacks.flatMap(\.charts)
    }

    static func chart(id: String) -> SupportFacultyChart? {
        charts.first { $0.id == id }
    }

    static func charts(for entityIDs: [String]) -> [SupportFacultyChart] {
        let ids = Set(entityIDs)
        return charts.filter { ids.contains($0.facultyEntityID) }
    }

    static func charts(matching tags: Set<String>) -> [SupportFacultyChart] {
        charts
            .map { chart in
                let overlap = tags.intersection(Set(chart.tags)).count
                return (chart, overlap)
            }
            .filter { $0.1 > 0 }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
            .map(\.0)
    }

    private static let coreCharts: [SupportFacultyChart] = [
        SupportFacultyChart(
            id: "inkrest-difficult-page-chart",
            packID: corePackID,
            kind: .difficultPage,
            facultyEntityID: "dr-inkrest",
            facultyName: "Dr. Selene Inkrest",
            pageTitle: "Difficult Page",
            roleTitle: "Academy Narrative Therapist",
            purpose: "Hold emotional difficulty through narrative therapy, grounding, and reauthoring without turning pain into plot fuel.",
            reads: [
                "therapy chart",
                "Vellum chart",
                "fuel and body context",
                "heartbeat and recent pages",
                "diary or daydream material when offered"
            ],
            allowedUses: [
                "externalize a problem without making it the person",
                "name one feeling or pressure gently",
                "offer grounding, parts language, ACT, or CBT as practical tools",
                "write a preferred-story sentence",
                "keep quiet company when words are too expensive"
            ],
            forbiddenUses: [
                "diagnosis",
                "forced catharsis",
                "trauma excavation without consent",
                "major plot escalation",
                "spooky ambience",
                "certainty about symbols"
            ],
            invitations: [
                "name the page",
                "sit with the feeling",
                "rewrite one sentence",
                "choose grounding",
                "let Inkrest wait with it"
            ],
            closureConditions: [
                "one feeling or problem is externalized",
                "one preferred-story sentence is written",
                "one grounding step is chosen",
                "nothing is saved unless it is useful"
            ],
            artifactTypes: [
                "Therapy Chart check-in",
                "Difficult Page note",
                "reauthoring note",
                "grounding card",
                "question for real therapy"
            ],
            safetyLine: "A feeling is not a verdict. A problem is not a person. The next hour is where the story can be revised.",
            tags: ["support-faculty", "inkrest", "difficult-pages", "therapy-chart", "grounding", "care", "reauthoring"]
        ),
        SupportFacultyChart(
            id: "vellum-body-marginalia-chart",
            packID: corePackID,
            kind: .bodyMarginalia,
            facultyEntityID: "dr-vellum",
            facultyName: "Dr. Elowen Vellum",
            pageTitle: "Body Marginalia Page",
            roleTitle: "Academy Longevity Physician",
            purpose: "Translate body, fuel, movement, recovery, and repeated ledger clues into one useful daily experiment with no shame attached.",
            reads: [
                "fuel log",
                "Vellum ledger pattern clues",
                "HealthKit body signals",
                "sleep and recovery context",
                "blood pressure or labs when explicitly provided",
                "supplements and medication cautions when explicitly provided",
                "current longevity research only when requested"
            ],
            allowedUses: [
                "choose one body-support action",
                "review a small experiment",
                "log one data point",
                "turn missing data into uncertainty, not blame",
                "prepare a question for a doctor or pharmacist"
            ],
            forbiddenUses: [
                "food shame",
                "diagnosis",
                "prescription changes",
                "heroic protocols",
                "generic wellness copy",
                "treating missing data as certainty"
            ],
            invitations: [
                "choose one warm fuel action",
                "try a small movement experiment",
                "review rest without moralizing it",
                "ask a longevity question",
                "log one body clue"
            ],
            closureConditions: [
                "one reader-sized action is named",
                "one experiment or metric is clarified",
                "one safety flag is preserved",
                "one doctor or pharmacist question is prepared when needed"
            ],
            artifactTypes: [
                "Vellum chart update",
                "Body Marginalia note",
                "fuel observation",
                "body experiment record",
                "doctor or pharmacist question"
            ],
            safetyLine: "The body is evidence, not an accusation. Useful beats heroic.",
            tags: ["support-faculty", "vellum", "body", "fuel", "health", "vellum-chart", "longevity", "care", "experiment"]
        )
    ]
}

enum GossipSimulationActionKind: String, Codable, Equatable, CaseIterable {
    case takeAction
    case investBelief
    case attackBelief

    var title: String {
        switch self {
        case .takeAction:
            return "acted"
        case .investBelief:
            return "invested Belief"
        case .attackBelief:
            return "tested Belief"
        }
    }
}

enum GossipRelationshipMoveKind: String, Codable, Equatable {
    case invest   // the actor talks the target up — warms the thread between them
    case attack   // the actor undermines the target — tenses the thread between them
}

/// A character-to-character Belief move during gossip: one actor invests in or
/// attacks another, shifting that target's Belief and the relationship field.
struct GossipRelationshipMove: Codable, Equatable {
    var actorID: String
    var actorName: String
    var targetID: String
    var targetName: String
    var kind: GossipRelationshipMoveKind
    var amount: Int

    var token: String { "\(actorID)>\(targetID):\(kind.rawValue):\(amount)" }

    var promptLine: String {
        switch kind {
        case .invest: return "\(actorName) quietly talks up \(targetName) — investing Belief in them."
        case .attack: return "\(actorName) undercuts \(targetName) — chipping at their Belief."
        }
    }
}

enum GossipPageBeliefMoveKind: String, Codable, Equatable {
    case invest
    case attack
}

/// A character-to-page Belief move during gossip: Cast members can warm the
/// kinds of Pages they want the Book to notice, or try to steal Glow from Pages
/// they distrust. These tokens drive the real Page Belief ledger.
struct GossipPageBeliefMove: Codable, Equatable {
    var actorID: String
    var actorName: String
    var sourceID: String
    var sourceTitle: String
    var kind: GossipPageBeliefMoveKind
    var amount: Int

    var token: String { "\(actorID)>\(sourceID):\(kind.rawValue):\(amount)" }

    var promptLine: String {
        switch kind {
        case .invest:
            return "\(actorName) gives Belief to \(sourceTitle) Pages, trying to make that kind of page more real."
        case .attack:
            return "\(actorName) tries to take Belief from \(sourceTitle) Pages, cooling what the Book will notice."
        }
    }
}

struct GossipSimulationTurn: Codable, Equatable {
    var id: String
    var actorID: String
    var actorName: String
    var threadID: String
    var threadTitle: String
    var actionKind: GossipSimulationActionKind
    var overheardLine: String
    var visibleTrace: String
    var hiddenEffect: String
    var consequenceLines: [String]
    var tags: [String]
    var beliefCombat: BeliefCombatResult?
    var chapterTalismanMove: ChapterTalismanBeliefMove?
    var relationshipMove: GossipRelationshipMove?
    var pageBeliefMove: GossipPageBeliefMove?
}

enum ContentPackAvailability: String, Codable, Equatable {
    case bundledFree
    case patron
    case paid
    case userImported
    case locked
}

enum LorePackRegistry {
    static let corePackID = "core-labyrinth-lore"

    static func bundledPacks(coreSnippets: [ReferenceSnippet]) -> [LorePack] {
        [
            LorePack(
                id: corePackID,
                displayName: "Core Labyrinth Lore Pack",
                version: "1.0",
                author: "The Book",
                availability: .bundledFree,
                themes: ["academy", "characters", "classes", "history", "letters", "rooms"],
                snippets: coreSnippets
            )
        ]
    }

    static func enabledPacks(coreSnippets: [ReferenceSnippet]) -> [LorePack] {
        bundledPacks(coreSnippets: coreSnippets).filter { $0.availability != .locked }
    }

    static func snippets(coreSnippets: [ReferenceSnippet]) -> [ReferenceSnippet] {
        enabledPacks(coreSnippets: coreSnippets).flatMap(\.snippets)
    }
}

enum BraidTextPolisher {
    static func polishedBookOfYou(_ text: String, maxParagraphs: Int = 7, maxWords: Int = 480) -> String {
        let paragraphs = normalizedParagraphs(from: text)
        guard !paragraphs.isEmpty else { return "" }

        var seenSentenceKeys = Set<String>()
        var seenMotifKeys = Set<String>()
        var seenIdeaWordSets: [Set<String>] = []
        var polishedParagraphs: [String] = []

        for paragraph in paragraphs {
            let polishedSentences = sentences(in: paragraph).filter { sentence in
                let significantWords = significantWords(in: sentence)
                let normalized = significantWords.joined(separator: " ")
                guard !normalized.isEmpty else { return false }

                if seenSentenceKeys.contains(normalized) {
                    return false
                }

                let ideaWords = ideaWordSet(from: significantWords)
                if isRepeatedIdea(ideaWords, comparedTo: seenIdeaWordSets) {
                    return false
                }

                let motifKeys = motifKeys(in: sentence)
                if !motifKeys.isEmpty && motifKeys.contains(where: { seenMotifKeys.contains($0) }) {
                    return false
                }

                seenSentenceKeys.insert(normalized)
                if ideaWords.count >= 3 {
                    seenIdeaWordSets.append(ideaWords)
                }
                motifKeys.forEach { seenMotifKeys.insert($0) }
                return true
            }

            let polished = polishedSentences.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !polished.isEmpty {
                polishedParagraphs.append(polished)
            }
        }

        return limitedText(polishedParagraphs, maxParagraphs: maxParagraphs, maxWords: maxWords)
    }

    private static func normalizedParagraphs(from text: String) -> [String] {
        var paragraphs: [String] = []
        var currentLines: [String] = []

        for line in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                let paragraph = currentLines.joined(separator: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !paragraph.isEmpty {
                    paragraphs.append(paragraph)
                }
                currentLines = []
            } else {
                currentLines.append(trimmed)
            }
        }

        let finalParagraph = currentLines.joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalParagraph.isEmpty {
            paragraphs.append(finalParagraph)
        }

        return paragraphs
    }

    private static func sentences(in paragraph: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for character in paragraph {
            current.append(character)
            if ".!?".contains(character), !currentLooksLikeAbbreviation(current) {
                let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                current = ""
            }
        }

        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty {
            sentences.append(remainder)
        }

        return sentences
    }

    private static func currentLooksLikeAbbreviation(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "St.", "Jr.", "Sr."].contains { trimmed.hasSuffix($0) }
    }

    private static func ideaWordSet(from words: [String]) -> Set<String> {
        Set(words.filter { $0.count > 2 })
    }

    private static func isRepeatedIdea(_ words: Set<String>, comparedTo previous: [Set<String>]) -> Bool {
        guard words.count >= 3 else { return false }

        return previous.contains { prior in
            guard prior.count >= 3 else { return false }
            let shared = words.intersection(prior).count
            guard shared >= 3 else { return false }

            let smallerCount = min(words.count, prior.count)
            let containment = Double(shared) / Double(smallerCount)
            let unionCount = words.union(prior).count
            let jaccard = Double(shared) / Double(unionCount)

            return containment >= 0.72 || jaccard >= 0.5
        }
    }

    private static func motifKeys(in sentence: String) -> Set<String> {
        let words = Set(significantWords(in: sentence))
        var keys = Set<String>()
        let names = properNames(in: sentence)

        let absenceWords: Set<String> = [
            "lonely", "alone", "missing", "missed", "absence", "absent",
            "without", "lacked", "lacking", "near", "presence"
        ]
        if !words.isDisjoint(with: absenceWords) {
            if names.isEmpty {
                keys.insert("absence")
            } else {
                names.forEach { keys.insert("absence:\($0)") }
            }
        }

        if words.contains("silence") && !words.isDisjoint(with: absenceWords) {
            keys.insert("lonely-silence")
        }

        return keys
    }

    private static func significantWords(in sentence: String) -> [String] {
        let stopWords: Set<String> = [
            "a", "an", "and", "as", "at", "but", "by", "for", "from", "in",
            "into", "it", "its", "of", "on", "or", "the", "this", "to", "was",
            "were", "with", "you", "your", "that", "there", "held", "felt"
        ]
        return sentence.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    private static func properNames(in sentence: String) -> Set<String> {
        let ignored: Set<String> = ["The", "Book", "You", "It"]
        return sentence.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .compactMap { word -> String? in
                guard let first = word.unicodeScalars.first,
                      CharacterSet.uppercaseLetters.contains(first),
                      !ignored.contains(word) else {
                    return nil
                }
                return word.lowercased()
            }
            .reduce(into: Set<String>()) { $0.insert($1) }
    }

    private static func limitedText(_ paragraphs: [String], maxParagraphs: Int, maxWords: Int) -> String {
        guard !paragraphs.isEmpty else { return "" }

        let closingIndex = paragraphs.lastIndex { $0.hasPrefix("The Book kept the page:") }
        var limited = paragraphs
        if limited.count > maxParagraphs {
            if let closingIndex, closingIndex == limited.indices.last {
                limited = Array(limited.prefix(maxParagraphs - 1)) + [limited[closingIndex]]
            } else {
                limited = Array(limited.prefix(maxParagraphs))
            }
        }

        while wordCount(in: limited.joined(separator: "\n\n")) > maxWords, limited.count > 2 {
            let removeIndex: Int
            if let closingIndex = limited.lastIndex(where: { $0.hasPrefix("The Book kept the page:") }) {
                removeIndex = max(0, closingIndex - 1)
            } else {
                removeIndex = limited.count - 2
            }
            limited.remove(at: removeIndex)
        }

        return limited.joined(separator: "\n\n")
    }

    private static func wordCount(in text: String) -> Int {
        text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

struct LocalBrainTelemetryState: Codable, Equatable {
    private(set) var isReading = false
    private(set) var isWorking = false
    private(set) var currentLabel = "the Book"
    private(set) var currentPromptCharacters = 0
    private(set) var currentQueuedCount = 0
    private(set) var currentGeneratedText = ""
    private(set) var currentGeneratedCharacters = 0
    private(set) var currentPromptTokens: Int?
    private(set) var currentGeneratedTokens: Int?
    private(set) var currentTokensPerSecond: Double?
    private(set) var startedAt: Date?
    private(set) var lastLabel = "none"
    private(set) var lastPromptCharacters = 0
    private(set) var lastFinishedAt: Date?
    private(set) var lastError: String?

    var currentWorkStatus: String? {
        guard isWorking else { return nil }
        return "\(currentLabel) · \(currentPromptCharacters) chars · \(currentQueuedCount) queued"
    }

    var currentGenerationPreview: String? {
        let preview = currentGeneratedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? nil : preview
    }

    var currentGenerationProgressLine: String? {
        var parts: [String] = []
        if let currentGeneratedTokens {
            parts.append("\(currentGeneratedTokens) tokens")
        } else if currentGeneratedCharacters > 0 {
            parts.append("\(currentGeneratedCharacters) chars")
        }
        if let currentTokensPerSecond {
            parts.append("\(String(format: "%.1f", currentTokensPerSecond)) tok/s")
        }
        if let currentPromptTokens {
            parts.append("\(currentPromptTokens) prompt tokens")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func lastWorkStatus(formatDate: (Date) -> String) -> String {
        let finishedText = lastFinishedAt.map(formatDate) ?? "not finished"
        return "\(lastLabel) · \(lastPromptCharacters) chars · \(finishedText)"
    }

    mutating func wake() {
        isReading = true
    }

    mutating func rest() {
        isReading = false
    }

    mutating func beginOrUpdateWork(
        label: String?,
        promptCharacters: Int,
        queuedCount: Int,
        now: Date = Date()
    ) -> Bool {
        let didBegin = !isWorking
        if didBegin {
            startedAt = now
        }
        let displayLabel = label ?? "the Book"
        let didChangeLabel = currentLabel != displayLabel
        isWorking = true
        currentLabel = displayLabel
        currentPromptCharacters = promptCharacters
        currentQueuedCount = queuedCount
        if didBegin || didChangeLabel {
            clearGenerationProgress()
        }
        lastLabel = displayLabel
        lastPromptCharacters = promptCharacters
        return didBegin
    }

    mutating func updateGenerationProgress(
        label: String?,
        text: String,
        generatedCharacters: Int,
        promptTokens: Int?,
        generatedTokens: Int?,
        tokensPerSecond: Double?
    ) {
        if let label, !label.isEmpty {
            currentLabel = label
            lastLabel = label
        }
        currentGeneratedText = text
        currentGeneratedCharacters = generatedCharacters
        currentPromptTokens = promptTokens
        currentGeneratedTokens = generatedTokens
        currentTokensPerSecond = tokensPerSecond
    }

    mutating func finishWork(now: Date = Date()) {
        isWorking = false
        startedAt = nil
        currentQueuedCount = 0
        currentPromptCharacters = 0
        clearGenerationProgress()
        lastFinishedAt = now
    }

    mutating func resetTransientWork() {
        isReading = false
        isWorking = false
        startedAt = nil
        currentQueuedCount = 0
        currentPromptCharacters = 0
        clearGenerationProgress()
    }

    mutating func recordError(_ error: String) {
        lastError = error
    }

    mutating func clearError() {
        lastError = nil
    }

    private mutating func clearGenerationProgress() {
        currentGeneratedText = ""
        currentGeneratedCharacters = 0
        currentPromptTokens = nil
        currentGeneratedTokens = nil
        currentTokensPerSecond = nil
    }
}

struct BookArchiveExport: Codable, Equatable {
    static let schemaVersion = 2

    var schemaVersion: Int
    var generatedAt: Date
    var dayCount: Int
    var pageCount: Int
    var days: [BookDay]
    /// What the Book has noticed, named, and wagered - exported so the wider
    /// Labyrinth (scene engine, NPC dialogue) can reference the same threads.
    var continuity: LiteraryContinuityDigest?
    var constellations: [Constellation]?
    var wagers: [BookWager]?
    var themes: [BookTheme]?
    var clusters: [BookMotifCluster]?

    init(
        generatedAt: Date = Date(),
        days: [BookDay],
        continuity: LiteraryContinuityDigest? = nil,
        constellations: [Constellation]? = nil,
        wagers: [BookWager]? = nil,
        themes: [BookTheme]? = nil,
        clusters: [BookMotifCluster]? = nil,
        calendar: Calendar = .current
    ) {
        let normalizedDays = Self.normalizedDays(days, calendar: calendar)
        self.schemaVersion = Self.schemaVersion
        self.generatedAt = generatedAt
        self.dayCount = normalizedDays.count
        self.pageCount = normalizedDays.reduce(0) { $0 + $1.pages.count }
        self.days = normalizedDays
        self.continuity = continuity
        self.constellations = constellations
        self.wagers = wagers
        self.themes = themes
        self.clusters = clusters
    }

    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> BookArchiveExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BookArchiveExport.self, from: data)
    }

    private static func normalizedDays(_ days: [BookDay], calendar: Calendar) -> [BookDay] {
        var merged: [String: BookDay] = [:]
        for day in days {
            var normalized = day
            normalized.id = BookDay.id(for: day.date, calendar: calendar)
            normalized.date = calendar.startOfDay(for: day.date)
            normalized.pages = day.pages.sorted { $0.createdAt < $1.createdAt }
            if var existing = merged[normalized.id] {
                existing.pages.append(contentsOf: normalized.pages)
                existing.pages = uniquePages(existing.pages).sorted { $0.createdAt < $1.createdAt }
                merged[normalized.id] = existing
            } else {
                normalized.pages = uniquePages(normalized.pages)
                merged[normalized.id] = normalized
            }
        }
        return merged.values
            .sorted { $0.date < $1.date }
    }

    private static func uniquePages(_ pages: [BookPage]) -> [BookPage] {
        var seen = Set<String>()
        return pages.filter { page in
            seen.insert(page.id).inserted
        }
    }
}

struct BookPageQuery: Equatable {
    var type: BookPageType?
    var sourceID: String?
    var tag: String?
    var privacy: BookPagePrivacy?
    var usedInBookOfYou: Bool?
    var startDate: Date?
    var endDate: Date?
    var limit: Int

    init(
        type: BookPageType? = nil,
        sourceID: String? = nil,
        tag: String? = nil,
        privacy: BookPagePrivacy? = nil,
        usedInBookOfYou: Bool? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 20
    ) {
        self.type = type
        self.sourceID = sourceID
        self.tag = tag
        self.privacy = privacy
        self.usedInBookOfYou = usedInBookOfYou
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
    }
}

enum BookArchiveIndex {
    static func pages(in days: [BookDay], matching query: BookPageQuery) -> [BookPage] {
        days
            .flatMap(\.pages)
            .sorted { $0.createdAt > $1.createdAt }
            .lazy
            .filter { matches($0, query: query) }
            .prefix(max(query.limit, 0))
            .map { $0 }
    }

    static func resurfacingCandidates(
        in days: [BookDay],
        before date: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 12
    ) -> [BookPage] {
        let startOfDay = calendar.startOfDay(for: date)
        return pages(
            in: days,
            matching: BookPageQuery(
                type: .souvenir,
                usedInBookOfYou: true,
                endDate: startOfDay,
                limit: limit
            )
        )
    }

    static func matches(_ page: BookPage, query: BookPageQuery) -> Bool {
        if let type = query.type, page.type != type {
            return false
        }
        if let sourceID = query.sourceID, page.sourceID != sourceID {
            return false
        }
        if let tag = query.tag,
           !page.tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
            return false
        }
        if let privacy = query.privacy, page.privacy != privacy {
            return false
        }
        if let usedInBookOfYou = query.usedInBookOfYou,
           page.usedInBookOfYou != usedInBookOfYou {
            return false
        }
        if let startDate = query.startDate, page.createdAt < startDate {
            return false
        }
        if let endDate = query.endDate, page.createdAt >= endDate {
            return false
        }
        return true
    }
}

struct CodablePoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct CodableSize: Codable, Equatable {
    var width: Double
    var height: Double
}

struct ClosedDoubleRange: Codable, Equatable {
    var lowerBound: Double
    var upperBound: Double

    func value(seed: Int, salt: Int) -> Double {
        guard upperBound > lowerBound else { return lowerBound }
        let mixed = abs((seed &* 31) ^ (salt &* 997))
        let unit = Double(mixed % 10_000) / 10_000
        return lowerBound + (upperBound - lowerBound) * unit
    }
}

enum PhotoSuggestionMode: String, Codable, CaseIterable {
    case automatic
    case askFirst
    case manualOnly
    case off
}

struct PhotoSuggestionSettings: Codable, Equatable {
    var isEnabled: Bool
    var mode: PhotoSuggestionMode
    var lookbackHours: Int
    var includePeople: Bool
    var includePets: Bool
    var includeScreenshots: Bool
    var favoritesOnly: Bool
    var maxAutomaticSuggestionsPerDay: Int

    static let `default` = PhotoSuggestionSettings(
        isEnabled: true,
        mode: .askFirst,
        lookbackHours: 72,
        includePeople: true,
        includePets: true,
        includeScreenshots: false,
        favoritesOnly: false,
        maxAutomaticSuggestionsPerDay: 3
    )
}

struct PhotoCandidate: Identifiable, Codable, Equatable {
    var id: UUID
    var assetLocalIdentifier: String
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var isFavorite: Bool
    var score: Double
    var reasons: [String]
    var discoveredAt: Date
}

struct PhotoMarginalia: Codable, Equatable {
    var fieldNote: String
    var stampLabel: String
    var observationList: [String]
    var closingLine: String
}

enum PackAvailability: String, Codable, Equatable {
    case bundledFree
    case patron
    case paid
    case userImported
    case locked
}

struct TemplateFallbackPhrases: Codable, Equatable {
    var fieldNotes: [String]
    var stampLabels: [String]
    var observations: [String]
    var closingLines: [String]
}

enum CanvasPreference: String, Codable, Equatable {
    case portrait
    case landscape
    case square
    case matchPhoto
}

enum PhotoOrientation: String, Codable, Equatable {
    case portrait
    case landscape
    case square
}

enum PhotoTreatment: String, Codable, Equatable {
    case naturalKept
    case softArchive
    case sepiaFieldNote
    case hearthGlow
    case quietMatte
}

struct TemplateTextSlotSpec: Identifiable, Codable, Equatable {
    var id: String
    var contentKey: MarginaliaContentKey
    var title: String?
    var position: CodablePoint
    var size: CodableSize
    var rotationRange: ClosedDoubleRange
    var paperTags: [String]
    var fontStyle: IlluminatedFontStyle
    var maxLines: Int
}

struct TemplateDecorationSlotSpec: Identifiable, Codable, Equatable {
    var id: String
    var kind: IlluminationAssetKind
    var tags: [String]
    var position: CodablePoint
    var size: CodableSize
    var rotationRange: ClosedDoubleRange
    var opacityRange: ClosedDoubleRange
    var required: Bool
}

struct PhotoFrameSpec: Codable, Equatable {
    var position: CodablePoint
    var size: CodableSize
    var rotationDegrees: Double
    var cornerRadius: Double
}

struct DecorationPlacement: Identifiable, Codable, Equatable {
    var id: UUID
    var assetName: String
    var kind: IlluminationAssetKind
    var position: CodablePoint
    var size: CodableSize
    var rotationDegrees: Double
    var opacity: Double
}

enum PhotoAnalysisValidator {
    static func decodeAndValidate(_ raw: String, fallback: PhotoAnalysis = .academyFallback) -> PhotoAnalysis {
        guard let json = extractJSONObject(from: raw),
              let data = json.data(using: .utf8) else {
            return fallback
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(PhotoAnalysis.self, from: data) else {
            return fallback
        }

        return validate(decoded, fallback: fallback)
    }

    static func validate(_ analysis: PhotoAnalysis, fallback: PhotoAnalysis = .academyFallback) -> PhotoAnalysis {
        let scene = sanitizedSentence(analysis.scene, maxCharacters: 160, fallback: fallback.scene)
        let motifs = sanitizedMotifs(analysis.motifs, fallback: fallback.motifs)
        let mood = cappedWords(analysis.mood, maxWords: 3, maxCharacters: 32, fallback: fallback.mood)

        let fieldNote = cappedWords(analysis.marginalia.fieldNote, maxWords: 8, maxCharacters: 72, fallback: fallback.marginalia.fieldNote)
        let stampLabel = cappedWords(analysis.marginalia.stampLabel, maxWords: 3, maxCharacters: 24, fallback: fallback.marginalia.stampLabel)
        let observations = exactly(
            analysis.marginalia.observationList.map { cappedWords($0, maxWords: 6, maxCharacters: 54, fallback: "") },
            count: 5,
            fallback: fallback.marginalia.observationList
        )
        let closing = closingLine(analysis.marginalia.closingLine, fallback: fallback.marginalia.closingLine)
        let souvenirs = exactly(
            analysis.souvenirCandidates.map { cappedWords($0, maxWords: 16, maxCharacters: 120, fallback: "") },
            count: 2,
            fallback: fallback.souvenirCandidates
        )

        return PhotoAnalysis(
            scene: scrubNames(scene),
            motifs: motifs,
            mood: scrubNames(mood),
            suggestedTemplate: analysis.suggestedTemplate,
            marginalia: PhotoMarginalia(
                fieldNote: scrubNames(fieldNote),
                stampLabel: scrubNames(stampLabel),
                observationList: observations.map(scrubNames),
                closingLine: scrubNames(closing)
            ),
            souvenirCandidates: souvenirs.map(scrubNames)
        )
    }

    private static func extractJSONObject(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private static func sanitizedSentence(_ value: String, maxCharacters: Int, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(maxCharacters))
    }

    private static func sanitizedMotifs(_ values: [String], fallback: [String]) -> [String] {
        var motifs = values
            .map { $0.lowercased().filter { $0.isLetter || $0.isNumber } }
            .filter { !$0.isEmpty }
        for item in fallback where motifs.count < 3 {
            if !motifs.contains(item) { motifs.append(item) }
        }
        return Array(motifs.prefix(5))
    }

    private static func cappedWords(_ value: String, maxWords: Int, maxCharacters: Int, fallback: String) -> String {
        let words = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(maxWords)
            .joined(separator: " ")
        let capped = String(words.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        return capped.isEmpty ? fallback : capped
    }

    private static func closingLine(_ value: String, fallback: String) -> String {
        let capped = cappedWords(value, maxWords: 10, maxCharacters: 96, fallback: fallback)
        if capped.localizedCaseInsensitiveContains("The Book kept") {
            return capped
        }
        return fallback
    }

    private static func exactly(_ values: [String], count: Int, fallback: [String]) -> [String] {
        var output = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for item in fallback where output.count < count {
            output.append(item)
        }
        return Array(output.prefix(count))
    }

    private static func scrubNames(_ value: String) -> String {
        let blocked = ["Penny Blackletter"] + PersonalNameGuard.blockedNames
        return blocked.reduce(value) { partial, name in
            guard name.count > 1 else { return partial }
            return partial.replacingOccurrences(of: name, with: "the subject", options: [.caseInsensitive])
        }
    }
}

struct DistressSignals: Equatable {
    var isActive: Bool
    var reasons: [String]

    static func evaluate(day: BookDay) -> DistressSignals {
        let distressTags: Set<String> = [
            "distress", "hard", "heavy", "low", "numb", "stormy", "depleted", "grief", "panic"
        ]
        var reasons: [String] = []

        for page in day.capturedPages {
            let loweredTags = Set(page.tags.map { $0.lowercased() })
            if !loweredTags.isDisjoint(with: distressTags) {
                reasons.append("\(page.type.shortTitle) carried a hard tag")
                continue
            }

            let loweredInput = page.userInput.lowercased()
            if loweredInput.contains("panic")
                || loweredInput.contains("depressed")
                || loweredInput.contains("hopeless")
                || loweredInput.contains("can't do this")
                || loweredInput.contains("cannot do this") {
                reasons.append("\(page.type.shortTitle) carried a hard phrase")
            }
        }

        return DistressSignals(isActive: !reasons.isEmpty, reasons: reasons)
    }
}

struct BleedTranslation: Equatable {
    var dayShape: String
    var pageBias: [BookPageType]
    var atmosphereLine: String
    var forbiddenOffers: [String]

    static let neutral = BleedTranslation(
        dayShape: "ordinary",
        pageBias: [.mood, .souvenir, .rest],
        atmosphereLine: "The margins are awake and listening.",
        forbiddenOffers: []
    )

    static let shelter = BleedTranslation(
        dayShape: "shelter",
        pageBias: [.rest, .mood, .souvenir],
        atmosphereLine: "The Book has lowered the lamps; the day asked for gentleness.",
        forbiddenOffers: ["long_embark", "high_energy_challenge", "step_back_offer"]
    )
}

enum BleedTranslator {
    static func translate(distress: DistressSignals) -> BleedTranslation {
        distress.isActive ? .shelter : .neutral
    }
}

struct StepBackEligibility: Equatable {
    var canOfferHalfOpenBook: Bool
    var reasons: [String]

    static func evaluate(recentDays: [BookDay], distress: DistressSignals) -> StepBackEligibility {
        guard !distress.isActive else {
            return StepBackEligibility(
                canOfferHalfOpenBook: false,
                reasons: ["The Book never offers stepping back from a hard or ambiguous place."]
            )
        }

        let recentCapturedPages = recentDays.flatMap(\.capturedPages)
        let unpromptedWonderCount = recentCapturedPages.filter { page in
            page.type == .souvenir && page.tags.contains { $0.lowercased() == "unprompted" }
        }.count

        guard unpromptedWonderCount >= 3 else {
            return StepBackEligibility(
                canOfferHalfOpenBook: false,
                reasons: ["The half-open-book ritual waits for sustained unprompted wonder."]
            )
        }

        return StepBackEligibility(
            canOfferHalfOpenBook: true,
            reasons: ["Sustained unprompted wonder is present and no distress signal is active."]
        )
    }
}

struct EnchantmentSpell: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String

    /// How this spell wants to sound — specific and quirky, never generic.
    var styleDirective: String {
        switch id {
        case "everything-speaks":
            return "The subject speaks in first person with a concrete, approachable voice — like a neighbor who happens to be a teapot. It knows its own materials, its wear marks, its job, and its small opinions about how it is treated. It mentions one specific thing it has witnessed from where it sits. It is candid but kind, never mystical, and it ends by asking the reader one small practical question."
        case "everything-is-poetry":
            return "Write in the manner of Mary Oliver: plain spoken attention, short unforced lines, the natural world close at hand even indoors, amazement carried lightly. Begin in exact observation of the subject, let the poem turn once toward the reader's one wild life, and end on a question or a quiet instruction. No rhyme, no ornament, no abstractions where a grasshopper would do."
        case "everything-is-a-haiku":
            return "Write exactly three haiku, each 5-7-5-ish, each catching a different aspect of the subject: its surface, its purpose, its secret. Season words welcome. Number them 1, 2, 3."
        case "everything-is-magic":
            return "Reveal the subject as a genuine spellbook entry. Format: the spell's hidden Name (in small capitals feel), what school of ordinary magic it belongs to, its Components (the real visible materials), its Effect (what it actually does to a household, stated as enchantment), and one quirky Side Effect nobody warns you about."
        case "everything-is-wonderful":
            return "Write a guided tour of the subject's overlooked marvels — three specific wonders, each anchored to a visible detail, each genuinely surprising rather than flattering. End with the single most wonderful fact, saved for last."
        case "everything-is-stories":
            return "Write one complete miniature story — beginning, turn, ending — in which the subject is the quiet protagonist. Ground it in the visible details, give it one named stranger passing through, and let something small actually change by the end."
        case "everything-is-nice":
            return "The subject receives compliments it has waited years to hear. Write four of them, each precise to its visible details, escalating from practical to almost embarrassingly tender. The subject's reaction leaks through in one final line."
        case "mirror-mirror":
            return "Speak as the mirror-self: gentle, wry, on the reader's side. One true reflection about what the photo actually shows, one insight the reader might be too close to see, and one playful prophecy for the next three days, specific enough to check."
        case "everything-is-puzzling":
            return "Pose the subject as a riddle with teeth — sensory clues, misdirection, real solvability. Then one hint for the stuck. Then whisper the answer on the last line, marked 'whispered:'."
        case "everything-is-connected":
            return "Trace three genuinely surprising threads from the subject outward: one to history, one to somewhere far away on Earth, one to something in the reader's own probable week. Each thread concrete, named, and true-shaped. End by noting where two threads secretly cross."
        case "everything-is-astral":
            return "The subject has an astral double that travels while the body stays. Write the double's travelogue from last night: two or three vivid stops, transit described synesthetically, one souvenir it brought back that explains something visible in the photo."
        case "everything-is-roasted":
            return "An affectionate comedy roast. Three escalating burns aimed at the subject's visible weak spots, each funny because it is precise, then one closing line that accidentally reveals the roaster loves it."
        case "everything-is-punny":
            return "A cascade of puns about the subject, escalating from groanworthy to genuinely criminal, each one building on the last. End when the subject itself appears to file a complaint."
        case "everything-is-a-joke":
            return "One proper joke with a setup rooted in the subject's visible reality and a punchline that lands sideways, then one tag line that makes it worse in the best way."
        default:
            return "Concrete, strange, warm. Anchor every line to a visible detail."
        }
    }

    /// How much room the spell deserves: stories and poems breathe;
    /// jokes stay sharp.
    var responseShape: String {
        switch id {
        case "everything-is-stories":
            return "150 to 260 words."
        case "everything-is-poetry", "everything-is-astral":
            return "12 to 24 lines."
        case "everything-speaks", "mirror-mirror", "everything-is-magic", "everything-is-wonderful", "everything-is-connected", "everything-is-nice":
            return "3 to 5 short paragraphs or sections — give it real room."
        case "everything-is-a-haiku":
            return "Exactly three numbered haiku."
        default:
            return "Short and sharp — brevity is the joke's knife."
        }
    }

    var preferredMaxTokens: Int {
        switch id {
        case "everything-is-stories", "everything-is-astral":
            return 700
        case "everything-speaks", "everything-is-poetry", "mirror-mirror", "everything-is-magic", "everything-is-wonderful", "everything-is-connected", "everything-is-nice":
            return 620
        default:
            return 360
        }
    }

    var symbolName: String {
        switch id {
        case "everything-speaks":
            return "bubble.left.and.text.bubble.right"
        case "everything-is-poetry", "everything-is-a-haiku":
            return "text.quote"
        case "everything-is-magic":
            return "wand.and.sparkles"
        case "everything-is-wonderful", "everything-is-nice":
            return "sparkles"
        case "everything-is-stories":
            return "book.pages"
        case "mirror-mirror":
            return "person.crop.square"
        case "everything-is-puzzling":
            return "questionmark.diamond"
        case "everything-is-connected":
            return "point.3.connected.trianglepath.dotted"
        case "everything-is-astral":
            return "moon.stars"
        case "everything-is-roasted":
            return "flame"
        case "everything-is-punny", "everything-is-a-joke":
            return "theatermasks"
        default:
            return "wand.and.sparkles"
        }
    }
}

enum StoryEnchantmentCatalog {
    static let spells: [EnchantmentSpell] = [
        EnchantmentSpell(id: "everything-speaks", title: "Everything Speaks", detail: "Look really closely and let a real object talk back."),
        EnchantmentSpell(id: "everything-is-poetry", title: "Everything's Poetry", detail: "Turn one real little detail into a line with music in it."),
        EnchantmentSpell(id: "everything-is-magic", title: "Everything's Magic", detail: "Show the secret spellbook hiding inside an ordinary thing."),
        EnchantmentSpell(id: "everything-is-wonderful", title: "Everything's Wonderful", detail: "Find the wonder tucked inside a plain little thing."),
        EnchantmentSpell(id: "everything-is-stories", title: "Everything's Stories", detail: "Let a tiny hidden story sneak out of whatever you point at."),
        EnchantmentSpell(id: "everything-is-a-haiku", title: "Everything's a Haiku", detail: "Squish it all down into three quiet little lines."),
        EnchantmentSpell(id: "everything-is-nice", title: "Everything's Nice", detail: "Coax sweet compliments and happy surprises out of it."),
        EnchantmentSpell(id: "mirror-mirror", title: "Mirror, Mirror", detail: "Ask a selfie for a good look, a nice truth, and a peek ahead."),
        EnchantmentSpell(id: "everything-is-puzzling", title: "Everything's Puzzling", detail: "Turn it into a riddle with a little bite to it."),
        EnchantmentSpell(id: "everything-is-connected", title: "Everything's Connected", detail: "Show all the bigger threads quietly tied to it."),
        EnchantmentSpell(id: "everything-is-astral", title: "Everything's Astral", detail: "Let it open a little road for your dreamy astral twin."),
        EnchantmentSpell(id: "everything-is-roasted", title: "Everything's Roasted", detail: "Point a silly, friendly little burn right at its weak spot."),
        EnchantmentSpell(id: "everything-is-punny", title: "Everything's Punny", detail: "Let some goofy wordplay crack it open sideways."),
        EnchantmentSpell(id: "everything-is-a-joke", title: "Everything's a Joke", detail: "Use a silly little joke to shake the tension loose.")
    ]

    static var promptCatalog: String {
        spells.map { "- \($0.id): \($0.title) - \($0.detail)" }.joined(separator: "\n")
    }

    static func spell(id: String?) -> EnchantmentSpell? {
        guard let id else { return nil }
        return spells.first { $0.id == id }
    }
}

struct FacultyLogWindow: Equatable {
    var id: String
    var name: String
    var startMinute: Int
    var endMinute: Int
}

enum FacultyLogCadence {
    static let windows: [FacultyLogWindow] = [
        FacultyLogWindow(id: "morning", name: "Morning Bell", startMinute: 5 * 60, endMinute: 11 * 60),
        FacultyLogWindow(id: "midday", name: "Midday Bell", startMinute: 11 * 60, endMinute: 16 * 60),
        FacultyLogWindow(id: "evening", name: "Evening Bell", startMinute: 16 * 60, endMinute: 21 * 60),
        FacultyLogWindow(id: "night", name: "Night Bell", startMinute: 21 * 60, endMinute: 29 * 60)
    ]

    static func currentWindow(for date: Date = Date(), calendar: Calendar = .current) -> FacultyLogWindow {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let comparableMinute = minute < windows[0].startMinute ? minute + 24 * 60 : minute
        return windows.first { window in
            comparableMinute >= window.startMinute && comparableMinute < window.endMinute
        } ?? windows[0]
    }

    static func didLog(kind: FacultyEntryKind, day: BookDay, entries: [FacultyEntry], now: Date = Date()) -> Bool {
        let window = currentWindow(for: now)
        if entries.contains(where: { $0.kind == kind && $0.dayID == day.id && $0.windowID == window.id }) {
            return true
        }
        let kindTag = "faculty-kind:\(kind.rawValue)"
        let windowTag = "faculty-window:\(window.id)"
        return day.pages.contains { page in
            page.tags.contains(kindTag) && page.tags.contains(windowTag)
        }
    }
}

enum FacultyResearchNoteGenerator {
    static func draftCandidate(for day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> SurfacePage? {
        let source = BookPageSourceRegistry.source(for: .facultyResearch)
        guard !SupportGuildSynthesisGenerator.isGuildTime(now) else { return nil }
        let dueFaculty = nextDueFaculty(for: day)
        guard let facultyID = dueFaculty else { return nil }
        return draftCandidate(for: facultyID, source: source, day: day, inputs: inputs, now: now)
    }

    static func nextDueFaculty(for day: BookDay) -> String? {
        let researched = Set(day.pages.filter { $0.type == .facultyResearch }.flatMap(\.tags).compactMap { tag -> String? in
            guard tag.hasPrefix("faculty:") else { return nil }
            return String(tag.dropFirst("faculty:".count))
        })
        if !researched.contains("dr-vellum") {
            return "dr-vellum"
        }
        if !researched.contains("dr-inkrest") {
            return "dr-inkrest"
        }
        return nil
    }

    static func draftCandidate(for facultyID: String, source: BookPageSource, day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let entity = NarrativePackRegistry.entities.first { $0.id == facultyID }
        let facultyName = entity?.name ?? facultyID
        let chart = SupportFacultyPackRegistry.charts(for: [facultyID]).first
        let topic = entity?.unwrittenInterest ?? chart?.purpose ?? "care research"
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        let body = promptBody(for: facultyID, topic: topic, day: day, inputs: inputs)
        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)-\(facultyID)",
            type: .facultyResearch,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .gentleTranslation,
            score: facultyID == "dr-vellum" ? 59 : 57,
            reason: "\(facultyName) is quietly getting a little research note ready for tonight's Guild page.",
            prompt: "\(facultyName) opens a research folio.",
            detail: "A private little study, thought up right here on your device, for tonight's Support Guild meeting.",
            payload: BookPagePayload(
                headline: "\(facultyName)'s Research Folio",
                body: body,
                metadata: [
                    "source": source.id,
                    "facultyID": facultyID,
                    "facultyName": facultyName,
                    "researchTopic": topic,
                    "slotID": slot,
                    "placeholder": "Keep this research note for tonight's Guild page.",
                    "tags": "faculty-research,faculty:\(facultyID),support-guild,research"
                ]
            )
        )
    }

    private static func promptBody(for facultyID: String, topic: String, day: BookDay, inputs: BookSourceInputs) -> String {
        let metrics = inputs.body?.metrics.prefix(8).map(\.displayText).joined(separator: " | ") ?? "no HealthKit metrics"
        let entries = inputs.facultyEntries.prefix(8).map { "\($0.windowName): \($0.rawText)" }.joined(separator: "\n")
        let fuelDigest = VellumFuelPatternDigest.make(from: inputs.facultyEntries.filter { $0.kind == .fuel })
        if facultyID == "dr-vellum" {
            return """
            Research focus: \(topic)

            Vellum should connect current body evidence to longevity, fuel, recovery, sleep, heart signals, medication cautions, and one humane experiment. Make the pattern recognition the star: repeated fuel-ledger clues are evidence for what to observe next, not a score. Use uncertainty. No diagnosis. No protocol heroics.

            Body signals: \(metrics)
            Vellum ledger pattern star: \(fuelDigest.summary)
            Ledger clue counts: \(fuelDigest.researchLine)
            Recent chart entries:
            \(entries.isEmpty ? "No chart entries yet." : entries)
            """
        }
        return """
        Research focus: \(topic)

        Inkrest should connect current inner weather to narrative psychology, consciousness, self-distancing, reauthoring, attention, and one gentle question. Use uncertainty. No diagnosis. No forced catharsis.

        Body signals: \(metrics)
        Recent chart entries:
        \(entries.isEmpty ? "No chart entries yet." : entries)
        """
    }
}

enum WonderConciergeMode: String, CaseIterable {
    case closeToHome
    case budget
    case obscure
    case vibe
    case scavenger
    case recovery

    var title: String {
        switch self {
        case .closeToHome:
            return "Close to Home"
        case .budget:
            return "Budget Agent"
        case .obscure:
            return "Curator of the Obscure"
        case .vibe:
            return "Vibe Check"
        case .scavenger:
            return "Gamifier"
        case .recovery:
            return "Recovery Compass"
        }
    }

    var promptSeed: String {
        switch self {
        case .closeToHome:
            return "Make a tiny adventure from the room, porch, driveway, kitchen, or nearest walkable threshold."
        case .budget:
            return "Keep cost anxiety low. Use free or cheap options and name one simple treat."
        case .obscure:
            return "Look for overlooked oddities, strange local history, old signs, hidden corners, or story-rich places."
        case .vibe:
            return "Match the user's mood to a place, texture, sound, or tiny ritual."
        case .scavenger:
            return "Turn the situation into a sensory scavenger hunt with specific things to find or photograph."
        case .recovery:
            return "Shrink the Compass to the user's energy envelope. Movement can be one inch; rest can be the run."
        }
    }
}

enum BookSchedule {
    /// The braid may be *offered* on the shelf from 6pm — an early-bird option,
    /// not an obligation. The automatic braid (`shouldAutoBraid`) still waits
    /// for the evening, so the ritual keeps its anticipation.
    static func isBraidSurfaceTime(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        minutesSinceStartOfDay(for: date, calendar: calendar) >= 18 * 60
    }

    static func shouldAutoBraid(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        minutesSinceStartOfDay(for: date, calendar: calendar) >= 21 * 60 + 30
    }

    private static func minutesSinceStartOfDay(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

struct RankedSurfacePage: Equatable {
    var page: SurfacePage
    var rank: Int
}

struct CuratorSurfacePreferences: Equatable {
    var dismissedSurfaceIDs: Set<String>
    var disabledSourceIDs: Set<String>
    var pageBeliefProfiles: [String: PageBeliefProfile]
    var readerLearning: ReaderLearningModel

    static let none = CuratorSurfacePreferences()

    init(
        dismissedSurfaceIDs: Set<String> = [],
        disabledSourceIDs: Set<String> = [],
        pageBeliefProfiles: [String: PageBeliefProfile] = [:],
        readerLearning: ReaderLearningModel = ReaderLearningModel()
    ) {
        self.dismissedSurfaceIDs = dismissedSurfaceIDs
        self.disabledSourceIDs = disabledSourceIDs
        self.pageBeliefProfiles = pageBeliefProfiles
        self.readerLearning = readerLearning
    }

    func allows(_ page: SurfacePage) -> Bool {
        dismissedSurfaceIDs.isDisjoint(with: page.curatorDeskExclusionKeys)
            && !disabledSourceIDs.contains(page.sourceID)
    }

    func adjustedScore(for page: SurfacePage) -> Int {
        let profile = pageBeliefProfiles[page.sourceID]
            ?? BookPageSourceRegistry.beliefProfile(for: page.source)
        let baseline = BookPageSourceRegistry.defaultBelief(for: page.source)
        let effectiveBelief = max(profile.belief, startingPageBelief(for: page) ?? profile.belief)
        let beliefDelta = effectiveBelief - baseline
        let narrativeBias = (profile.narrativeWeight - 20) / 4
        let beliefBias = beliefDelta / 2
        let automagicFloor = BookPageSourceRegistry.automagicSourceIDs.contains(page.sourceID) ? 68 : 0
        let lowBeliefChance = lowBeliefChanceBoost(for: page, profile: profile)
        let learnedBias = readerLearning.scoreAdjustment(for: page)
        return max(automagicFloor, page.score + narrativeBias + beliefBias + lowBeliefChance + learnedBias)
    }

    private func startingPageBelief(for page: SurfacePage) -> Int? {
        guard let raw = page.payload.metadata["startingPageBelief"],
              let value = Int(raw) else {
            return nil
        }
        return max(0, min(100, value))
    }

    private func lowBeliefChanceBoost(for page: SurfacePage, profile: PageBeliefProfile) -> Int {
        guard profile.belief <= 10 else { return 0 }
        let slot = abs("\(page.sourceID)-\(page.id)".stableHash) % 11
        return slot == 0 ? 18 : 0
    }
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var readerLearningNormalizedTag: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    func bookPreviewSentenceLimit(_ limit: Int) -> String {
        let normalized = components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard limit > 0, !normalized.isEmpty else {
            return ""
        }

        var sentences: [String] = []
        var current = ""
        for character in normalized {
            current.append(character)
            if ".!?".contains(character), current.hasBookPreviewSentenceBoundary {
                let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                current = ""
                if sentences.count == limit {
                    break
                }
            }
        }

        if sentences.isEmpty {
            return normalized
        }
        return sentences.prefix(limit).joined(separator: " ")
    }

    private var hasBookPreviewSentenceBoundary: Bool {
        guard let last = last, ".!?".contains(last) else {
            return false
        }
        guard last == "." else {
            return true
        }

        let lastToken = split(separator: " ").last.map(String.init) ?? self
        let abbreviation = lastToken
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        let nonTerminalAbbreviations: Set<String> = [
            "dr", "prof", "mr", "mrs", "ms", "mx", "st", "sr", "jr", "vs", "etc"
        ]
        if nonTerminalAbbreviations.contains(abbreviation) {
            return false
        }

        return true
    }
}

extension String {
    /// FNV-1a 64-bit. Swift's `hashValue` is randomized per process launch,
    /// which silently reshuffles anything seeded from it; use this for any
    /// rotation, jitter, or placement that should be stable across launches.
    var stableHash: Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(bitPattern: UInt(truncatingIfNeeded: hash))
    }
}

extension Int {
    /// SplitMix64 finalizer: deterministic scrambling for seed arithmetic
    /// (`Int.hashValue` is also process-randomized).
    var stableScramble: Int {
        var z = UInt64(bitPattern: Int64(self)) &+ 0x9e3779b97f4a7c15
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        z = z ^ (z >> 31)
        return Int(bitPattern: UInt(truncatingIfNeeded: z))
    }
}
