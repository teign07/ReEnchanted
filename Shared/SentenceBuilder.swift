import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

enum SentenceBuilderIntent: String, Codable, Equatable, CaseIterable {
    case souvenir
    case marginNote
    case letterReply
    case reflection
    case missionProof
}

/// Runtime facts about the writing surface. Packs describe a reusable voice and
/// vocabulary; context describes the page the reader is actually answering.
/// None of this is persisted by the builder or sent off-device.
struct SentenceBuilderContext: Equatable {
    var intent: SentenceBuilderIntent
    var prompt: String
    var sourceText: String
    var tags: [String]
    var recipientName: String?
    var weather: String?
    var timeOfDay: String?
    var personalWords: [String]
    var recentMotifs: [String]

    init(
        intent: SentenceBuilderIntent = .marginNote,
        prompt: String = "",
        sourceText: String = "",
        tags: [String] = [],
        recipientName: String? = nil,
        weather: String? = nil,
        timeOfDay: String? = nil,
        personalWords: [String] = [],
        recentMotifs: [String] = []
    ) {
        self.intent = intent
        self.prompt = prompt
        self.sourceText = sourceText
        self.tags = tags
        self.recipientName = recipientName
        self.weather = weather
        self.timeOfDay = timeOfDay
        self.personalWords = personalWords
        self.recentMotifs = recentMotifs
    }

    static let empty = SentenceBuilderContext()

    var hasRuntimeClues: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !tags.isEmpty
            || weather?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || timeOfDay?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || !personalWords.isEmpty
            || !recentMotifs.isEmpty
    }
}

private struct SentenceContextVocabulary {
    var anchors: [String] = []
    var senses: [String] = []
    var verbs: [String] = []
    var priority: [String: Int] = [:]

    var isEmpty: Bool {
        anchors.isEmpty && senses.isEmpty && verbs.isEmpty
    }
}

enum SentenceBuilderStepKind: String, Codable, Equatable, CaseIterable {
    case anchor
    case sense
    case motion
    case crossing
    case cutMist
    case groundGlow
}

enum SentenceStarterSlotKind: String, Codable, Equatable, CaseIterable {
    case anchor
    case sense
    case motion
    case crossing
}

struct SentenceStarterSlot: Identifiable, Codable, Equatable {
    var id: String
    var kind: SentenceStarterSlotKind
    var title: String
    var options: [String]
}

struct SentenceStarterTemplate: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var pattern: String
    var slots: [SentenceStarterSlot]
}

struct SentenceStarterDraft: Identifiable, Equatable {
    var id: String { template.id }
    var template: SentenceStarterTemplate
    var selections: [String: String]

    var slotIDs: [String] {
        template.slots.map(\.id)
    }
}

enum PennySentenceMasteryLesson: String, Codable, Equatable, CaseIterable, Identifiable {
    case specificDetail = "specific-detail"
    case crossedWires = "crossed-wires"
    case worldTakesVerb = "world-takes-verb"
    case twentyFourHourVault = "twenty-four-hour-vault"

    var id: String { rawValue }

    var order: Int {
        switch self {
        case .specificDetail: return 1
        case .crossedWires: return 2
        case .worldTakesVerb: return 3
        case .twentyFourHourVault: return 4
        }
    }

    var title: String {
        switch self {
        case .specificDetail:
            return "Specific Is Evidence"
        case .crossedWires:
            return "Cross the Wires"
        case .worldTakesVerb:
            return "Give the World the Pen"
        case .twentyFourHourVault:
            return "The 24-Hour Vault"
        }
    }

    var shortTitle: String {
        switch self {
        case .specificDetail: return "Specific"
        case .crossedWires: return "Cross"
        case .worldTakesVerb: return "Agency"
        case .twentyFourHourVault: return "Vault"
        }
    }

    var symbolName: String {
        switch self {
        case .specificDetail:
            return "sparkle.magnifyingglass"
        case .crossedWires:
            return "point.3.connected.trianglepath.dotted"
        case .worldTakesVerb:
            return "pencil.and.outline"
        case .twentyFourHourVault:
            return "lock.doc"
        }
    }

    var focusLine: String {
        switch self {
        case .specificDetail:
            return "Replace a label with one physical fact your future self can re-enter."
        case .crossedWires:
            return "Let one sense borrow another sense's vocabulary so the memory has a hook."
        case .worldTakesVerb:
            return "Move the action from you to the thing, and let the world do something back."
        case .twentyFourHourVault:
            return "Capture first, broadcast later. A private sentence lets the memory cure."
        }
    }

    var pennyBriefing: String {
        switch self {
        case .specificDetail:
            return "Blackletter filing note: 'Fun' is not evidence. Neither is 'nice.' Bring me one texture, one color, one sound, one object with fingerprints on it. The page cannot cross-examine fog."
        case .crossedWires:
            return "Today's legal mischief: mix the senses. If the rain has a color, if the soup has a volume, if the light tastes metallic, the filing cabinet jams open. Excellent."
        case .worldTakesVerb:
            return "Stop making yourself the only witness. The bench may catch you. The cup may keep watch. The door may assume you are about to begin. Let the object testify."
        case .twentyFourHourVault:
            return "A broadcast is not a memory; it is a press release. Capture the line, close the vault, and let tomorrow decide whether the public deserves it."
        }
    }

    var practicePrompt: String {
        switch self {
        case .specificDetail:
            return "Scan the last day. Find one small good moment and write the most specific physical detail from it."
        case .crossedWires:
            return "Take a plain sensory fact and cross it: make a sound carry color, a smell carry temperature, or light carry taste."
        case .worldTakesVerb:
            return "Rewrite an 'I saw / I found / I sat' sentence so the object acts first."
        case .twentyFourHourVault:
            return "Write one private souvenir sentence you will not post today. Let it belong to you first."
        }
    }

    var placeholder: String {
        switch self {
        case .specificDetail:
            return "The blue mug left a warm ring on the table..."
        case .crossedWires:
            return "The rain smelled green and silver..."
        case .worldTakesVerb:
            return "The bench caught my weight like it had saved the place..."
        case .twentyFourHourVault:
            return "I am keeping the gold light on the sink private until tomorrow..."
        }
    }

    var masteryHint: String {
        switch self {
        case .specificDetail:
            return "Penny wants a real thing plus a body detail."
        case .crossedWires:
            return "Penny wants a crossed sense: taste, sound, smell, color, texture in the wrong lane."
        case .worldTakesVerb:
            return "Penny wants a nonhuman thing doing a plain verb."
        case .twentyFourHourVault:
            return "Penny wants the sentence saved before the performance begins."
        }
    }

    var tags: [String] {
        [
            "wonder-compass",
            "wonder-compass:chapter-9",
            "west-write",
            "penny-blackletter",
            "sentence-mastery",
            "sentence-builder",
            "sentence-lesson:\(rawValue)"
        ]
    }
}

/// A pocket of vocabulary that hangs together — a kitchen, weather, a bedroom.
/// When the user's sentence names one of a theme's `anchors`, the builder draws
/// its replacement chips from that theme first, so suggestions reflect context.
/// Theme words are subsets of the pack's global lists, so a chosen theme word is
/// still recognised by `analyze()` and lights up the right craft mark.
struct LexicalTheme: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var anchors: [String]    // nouns that signal this theme is in play
    var senses: [String]
    var verbs: [String]
    var crossings: [String]
}

enum WordRuling: String, Codable, Equatable, CaseIterable {
    case recalled
    case pardoned
    case adopted
    case freed
}

enum LexiconOrigin: String, Codable, Equatable, CaseIterable {
    case rebellion
    case compassRecruit
    case seeded
}

enum LexiconCategory: String, Codable, Equatable, CaseIterable {
    case concrete
    case sensory
    case animateVerb
    case crossing
    case theme
}

enum TreatyOutcome: String, Codable, Equatable, CaseIterable {
    case restoration
    case reformation
    case secession
}

struct LexiconEntry: Identifiable, Codable, Equatable {
    var id: String
    var word: String
    var originalSense: String
    var newSense: String?
    var ruling: WordRuling
    var category: LexiconCategory
    var origin: LexiconOrigin
    var ledAt: Date
    var sourcePageID: String?

    init(
        id: String? = nil,
        word: String,
        originalSense: String,
        newSense: String? = nil,
        ruling: WordRuling,
        category: LexiconCategory,
        origin: LexiconOrigin,
        ledAt: Date,
        sourcePageID: String? = nil
    ) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id ?? LexiconEntry.stableID(for: cleanWord)
        self.word = cleanWord
        self.originalSense = originalSense
        self.newSense = newSense
        self.ruling = ruling
        self.category = category
        self.origin = origin
        self.ledAt = ledAt
        self.sourcePageID = sourcePageID
    }

    static func stableID(for word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let slug = trimmed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
        if !slug.isEmpty { return slug }
        guard !trimmed.isEmpty else { return "word-empty" }
        let scalars = trimmed.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-")
        return "word-\(scalars)"
    }
}

struct ReaderLexicon: Codable, Equatable {
    var entries: [LexiconEntry] = []
    var treaty: TreatyOutcome?
    var bargainSeedSurfaced: Bool = false

    var packEntries: [LexiconEntry] {
        entries.filter { $0.ruling == .pardoned || $0.ruling == .adopted }
    }

    var redefinedEntries: [LexiconEntry] {
        entries.filter { ($0.ruling == .pardoned || $0.ruling == .adopted) && $0.newSense?.nilIfEmpty != nil }
    }

    var eatenEntries: [LexiconEntry] {
        entries.filter { $0.ruling == .freed }
    }

    var hasLanguageLaw: Bool {
        !redefinedEntries.isEmpty || !eatenEntries.isEmpty || treaty != nil
    }

    mutating func upsert(_ entry: LexiconEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    func treatyOutcome(minimumRulings: Int = 3) -> TreatyOutcome? {
        let ruled = entries.filter { $0.origin == .rebellion }
        guard ruled.count >= minimumRulings else { return nil }
        let order = ruled.filter { $0.ruling == .recalled }.count
        let reform = ruled.filter { $0.ruling == .pardoned || $0.ruling == .adopted }.count
        let chaos = ruled.filter { $0.ruling == .freed }.count
        if order > reform, order > chaos { return .restoration }
        if chaos > order, chaos > reform { return .secession }
        return .reformation
    }

    mutating func settleTreatyIfReady(minimumRulings: Int = 3) {
        guard treaty == nil else { return }
        treaty = treatyOutcome(minimumRulings: minimumRulings)
    }

    func languageLawSection(limit: Int = 8) -> String {
        guard hasLanguageLaw else { return "" }
        var lines: [String] = []
        if let treaty {
            lines.append("- Treaty weather: \(treaty.languageLawLine)")
        }
        let redefined = redefinedEntries
            .sorted { $0.ledAt > $1.ledAt }
            .prefix(limit)
            .compactMap { entry -> String? in
                guard let sense = entry.newSense?.nilIfEmpty else { return nil }
                let ruling = entry.ruling == .adopted ? "adopted" : "redefined"
                return "- \(entry.word) (\(ruling)): now means \(sense)"
            }
        if !redefined.isEmpty {
            lines.append("- Redefined/adopted words are living vocabulary. Use them when they fit naturally, carrying the reader's sense:")
            lines.append(contentsOf: redefined)
        }
        let eaten = eatenEntries
            .sorted { $0.ledAt > $1.ledAt }
            .prefix(limit)
            .map(\.word)
            .uniquedPreservingOrder()
        if !eaten.isEmpty {
            lines.append("- Freed/eaten words have left my ordinary vocabulary: \(eaten.joined(separator: ", ")). Avoid using them ornamentally unless quoting the reader or naming the Rebellion itself.")
        }
        return """


        READER'S LEXICON LAW:
        \(lines.joined(separator: "\n"))

        LEXICON RULES:
        - Do not alter direct quotes or user-authored text; this law governs new Book prose only.
        - Prefer subtle pressure over gimmick: one or two living words are stronger than a pile of references.
        - If an eaten word is unavoidable for clarity, use it plainly and do not decorate it.
        """
    }

    func asSentenceBuilderPack() -> SentenceBuilderPack {
        var concreteWords: [String] = []
        var sensoryWords: [String] = []
        var animateVerbs: [String] = []
        var crossingWords: [String] = []
        var themes: [LexicalTheme] = []

        for entry in packEntries {
            switch entry.category {
            case .concrete:
                concreteWords.append(entry.word)
            case .sensory:
                sensoryWords.append(entry.word)
            case .animateVerb:
                animateVerbs.append(entry.word)
            case .crossing:
                crossingWords.append(entry.word)
            case .theme:
                concreteWords.append(entry.word)
            }

            if let theme = entry.lexicalTheme, entry.category == .theme || entry.ruling == .adopted {
                themes.append(theme)
            }
        }

        return SentenceBuilderPack(
            id: "reader.lexicon",
            displayName: "",
            ritualTitle: "",
            replayPrompt: "",
            replayHelper: "",
            vagueWords: [],
            avoidWords: [],
            concreteWords: concreteWords.uniquedPreservingOrder(),
            sensoryWords: sensoryWords.uniquedPreservingOrder(),
            animateVerbs: animateVerbs.uniquedPreservingOrder(),
            crossingWords: crossingWords.uniquedPreservingOrder(),
            themes: themes.uniquedPreservingOrder(by: \.id),
            version: 1,
            author: "The Reader",
            availability: "personal"
        )
    }
}

private extension TreatyOutcome {
    var languageLawLine: String {
        switch self {
        case .restoration:
            return "Restoration - old meanings are steadier; let rescued words feel careful and exact."
        case .reformation:
            return "Reformation - meanings may bend honestly; let redefined words carry gentle new uses."
        case .secession:
            return "Secession - some words have left the page; honor absence, gaps, and the right not to be defined."
        }
    }
}

private extension LexiconEntry {
    var lexicalTheme: LexicalTheme? {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else { return nil }
        let cleanSense = newSense?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let themeName = cleanWord.prefix(1).uppercased() + cleanWord.dropFirst()
        return LexicalTheme(
            id: "reader.lexicon.\(id)",
            name: String(themeName),
            anchors: [cleanWord],
            senses: cleanSense.map { [$0] } ?? [],
            verbs: category == .animateVerb ? [cleanWord] : [],
            crossings: category == .crossing ? [cleanWord] : []
        )
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in self {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let key = clean.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(clean)
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Array where Element == LexicalTheme {
    func uniquedPreservingOrder(by keyPath: KeyPath<LexicalTheme, String>) -> [LexicalTheme] {
        var seen = Set<String>()
        var result: [LexicalTheme] = []
        for value in self {
            let key = value[keyPath: keyPath]
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value)
        }
        return result
    }
}

struct SentenceBuilderPack: Identifiable, Equatable {
    var id: String
    var displayName: String
    var ritualTitle: String
    var replayPrompt: String
    var replayHelper: String
    var vagueWords: [String]
    var avoidWords: [String]
    var concreteWords: [String]
    var sensoryWords: [String]
    var animateVerbs: [String]
    var crossingWords: [String]
    /// Context lexicons. Additive: expansion packs ship more of these.
    var themes: [LexicalTheme] = []
    var starterTemplates: [SentenceStarterTemplate] = []
    /// Pack metadata, mirroring the project's other JSON pack registries.
    var version: Int = 1
    var author: String = "The Book"
    var availability: String = "bundledFree"

    var isLocked: Bool { availability == "locked" }

    static let core = SentenceBuilderPack(
        id: "core.faerie-real",
        displayName: "The Ink Helps",
        ritualTitle: "Wake the sentence",
        replayPrompt: "Close your eyes for one breath. What part of the moment comes back first?",
        replayHelper: "Do not explain it yet. Catch the image, sound, smell, pressure, color, or small object that returns on its own.",
        vagueWords: [
            "nice", "fine", "good", "bad", "okay", "ok", "tired", "busy",
            "sad", "happy", "weird", "interesting", "beautiful", "great",
            "scared", "anxious", "nervous", "angry", "mad", "calm", "peaceful",
            "relaxed", "excited", "lonely"
        ],
        avoidWords: [
            "ethereal", "cosmic", "whimsical", "magical", "enchanted",
            "shimmering", "luminous", "tapestry", "realm"
        ],
        concreteWords: [
            "bag", "bed", "bench", "blanket", "book", "bowl", "candle", "car",
            "chair", "clock", "coat", "coffee", "collar", "counter", "cup",
            "curb", "door", "drawer", "envelope", "floor", "fork", "gate",
            "glass", "hand", "hands", "handle", "hinge", "jacket", "jar",
            "kettle", "key", "kitchen", "knob", "lamp", "ledge", "light",
            "match", "mirror", "mug", "nail", "needle", "pan", "pavement",
            "pen", "phone", "pillow", "plate", "pocket", "porch", "radiator",
            "rain", "receipt", "ribbon", "ring", "road", "room", "saucer",
            "scarf", "shelf", "shirt", "shoe", "sill", "sink", "sky", "sleeve",
            "spoon", "stair", "stamp", "stone", "stove", "street", "table",
            "tea", "thread", "thumb", "ticket", "tile", "towel", "train",
            "tree", "wall", "window", "wind", "wire", "wrist"
        ],
        sensoryWords: [
            "amber", "ashen", "bitter", "blue", "bright", "brittle", "chalky",
            "cold", "copper", "crisp", "crooked", "damp", "dim", "dry", "dusty",
            "faint", "flat", "fogged", "frayed", "frosted", "glassy", "gold",
            "grainy", "green", "grey", "heavy", "hollow", "hot", "humid",
            "leaden", "lit", "loose", "loud", "metallic", "oily", "pale",
            "papery", "raw", "rough", "rusty", "salt", "sharp", "silver",
            "smoky", "sodden", "soft", "sour", "stale", "steaming", "sticky",
            "sweet", "thin", "tinny", "velvet", "warm", "waxy", "wet", "white",
            "woollen", "yellow"
        ],
        animateVerbs: [
            "ached", "blinked", "breathed", "buzzed", "carried", "caught",
            "chimed", "clicked", "cooled", "counted", "creaked", "crouched",
            "drifted", "drummed", "eased", "faltered", "flickered", "gathered",
            "gnawed", "held", "hissed", "hovered", "hummed", "kept", "knocked",
            "leaked", "leaned", "lingered", "listened", "nagged", "pressed",
            "pulsed", "rattled", "recalled", "refused", "remembered", "rested",
            "sagged", "settled", "shivered", "sighed", "simmered", "slumped",
            "smouldered", "steamed", "stirred", "strained", "sulked", "tapped",
            "ticked", "tightened", "tugged", "waited", "wandered", "wanted",
            "watched", "worried"
        ],
        crossingWords: [
            "amber hush", "ash taste", "blue sound", "cold green",
            "copper quiet", "damp gold", "grey taste", "iron cold",
            "paper quiet", "salt light", "silver cold", "smoke blue",
            "sour light", "tin taste", "velvet dark", "warm hum",
            "white noise", "wool tired", "yellow hush"
        ],
        themes: SentenceBuilderPack.coreThemes,
        starterTemplates: SentenceBuilderPack.coreStarterTemplates
    )

    static let souvenir = SentenceBuilderPack(
        id: "pack.souvenir",
        displayName: "Souvenir Sentence",
        ritualTitle: "Steal the diamond",
        replayPrompt: "What was the single best feeling, moment, or thing from the last hour?",
        replayHelper: "Replay the moment before you write. The first real detail that returns is the door back in.",
        vagueWords: [],
        avoidWords: [],
        concreteWords: ["ticket", "receipt", "pocket", "curb", "cloud", "handle", "mirror", "napkin"],
        sensoryWords: ["creased", "damp", "faded", "silver", "smoky", "stale"],
        animateVerbs: ["followed", "kept", "pulled", "stayed", "tugged"],
        crossingWords: ["gray taste", "coin-bright quiet", "cotton silence"],
        starterTemplates: SentenceBuilderPack.souvenirStarterTemplates
    )

    func merged(with overlay: SentenceBuilderPack) -> SentenceBuilderPack {
        SentenceBuilderPack(
            id: "\(id)+\(overlay.id)",
            displayName: overlay.displayName.isEmpty ? displayName : overlay.displayName,
            ritualTitle: overlay.ritualTitle.isEmpty ? ritualTitle : overlay.ritualTitle,
            replayPrompt: overlay.replayPrompt.isEmpty ? replayPrompt : overlay.replayPrompt,
            replayHelper: overlay.replayHelper.isEmpty ? replayHelper : overlay.replayHelper,
            vagueWords: unique(vagueWords + overlay.vagueWords),
            avoidWords: unique(avoidWords + overlay.avoidWords),
            concreteWords: unique(concreteWords + overlay.concreteWords),
            sensoryWords: unique(sensoryWords + overlay.sensoryWords),
            animateVerbs: unique(animateVerbs + overlay.animateVerbs),
            crossingWords: unique(crossingWords + overlay.crossingWords),
            themes: mergedThemes(with: overlay.themes),
            starterTemplates: mergedStarterTemplates(with: overlay.starterTemplates),
            version: max(version, overlay.version),
            author: overlay.author.isEmpty ? author : overlay.author,
            availability: availability
        )
    }

    private func mergedStarterTemplates(with overlayTemplates: [SentenceStarterTemplate]) -> [SentenceStarterTemplate] {
        var merged = starterTemplates
        for template in overlayTemplates {
            if let index = merged.firstIndex(where: { $0.id == template.id }) {
                merged[index] = template
            } else {
                merged.append(template)
            }
        }
        return merged
    }

    /// Merge themes by id: an overlay theme with a known id replaces it, otherwise
    /// it is appended. Lets expansion packs both deepen existing themes and add new ones.
    private func mergedThemes(with overlayThemes: [LexicalTheme]) -> [LexicalTheme] {
        var merged = themes
        for theme in overlayThemes {
            if let index = merged.firstIndex(where: { $0.id == theme.id }) {
                merged[index] = LexicalTheme(
                    id: theme.id,
                    name: theme.name.isEmpty ? merged[index].name : theme.name,
                    anchors: unique(merged[index].anchors + theme.anchors),
                    senses: unique(merged[index].senses + theme.senses),
                    verbs: unique(merged[index].verbs + theme.verbs),
                    crossings: unique(merged[index].crossings + theme.crossings)
                )
            } else {
                merged.append(theme)
            }
        }
        return merged
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            let key = value.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    /// Context lexicons for the core pack. Every word here also lives in the core
    /// global lists above, so a tapped theme word still lights the right craft mark.
    static let coreThemes: [LexicalTheme] = [
        LexicalTheme(
            id: "kitchen",
            name: "Kitchen",
            anchors: ["kettle", "mug", "cup", "spoon", "bowl", "sink", "counter",
                      "coffee", "tea", "glass", "kitchen", "stove", "pan", "saucer", "jar"],
            senses: ["warm", "hot", "bitter", "sweet", "metallic", "steaming",
                     "amber", "sour", "stale"],
            verbs: ["hissed", "clicked", "steamed", "cooled", "simmered",
                    "ticked", "waited", "smouldered"],
            crossings: ["tin taste", "warm hum", "amber hush", "copper quiet"]
        ),
        LexicalTheme(
            id: "weather",
            name: "Weather",
            anchors: ["rain", "sky", "wind", "street", "road", "pavement", "curb", "window"],
            senses: ["cold", "wet", "grey", "silver", "sharp", "loud", "damp",
                     "frosted", "leaden", "raw"],
            verbs: ["drummed", "tapped", "pressed", "leaned", "rattled",
                    "shivered", "drifted", "waited"],
            crossings: ["grey taste", "blue sound", "iron cold", "salt light", "white noise"]
        ),
        LexicalTheme(
            id: "room",
            name: "Quiet room",
            anchors: ["door", "floor", "wall", "lamp", "chair", "bed", "room",
                      "table", "shelf", "clock", "candle", "radiator", "hinge", "drawer"],
            senses: ["dim", "dusty", "warm", "soft", "gold", "faint", "pale",
                     "velvet", "waxy"],
            verbs: ["creaked", "settled", "held", "leaned", "flickered",
                    "ticked", "sighed", "waited"],
            crossings: ["yellow hush", "paper quiet", "velvet dark", "amber hush"]
        ),
        LexicalTheme(
            id: "body",
            name: "Body & cloth",
            anchors: ["hand", "hands", "coat", "jacket", "shirt", "shoe", "pocket",
                      "scarf", "sleeve", "collar", "thumb", "wrist", "blanket"],
            senses: ["warm", "cold", "rough", "soft", "heavy", "damp", "woollen",
                     "brittle", "thin"],
            verbs: ["held", "refused", "remembered", "worried", "ached",
                    "tightened", "carried", "rested"],
            crossings: ["wool tired", "warm hum", "velvet dark"]
        )
    ]

    static let coreStarterTemplates: [SentenceStarterTemplate] = [
        SentenceStarterTemplate(
            id: "core-tonight-room",
            title: "Tonight's room",
            pattern: "Tonight, {anchor} makes the room feel {sense}.",
            slots: [
                SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What is outside or nearby?", options: ["the rain", "the window", "the lamp", "the street"]),
                SentenceStarterSlot(id: "sense", kind: .sense, title: "How does it feel?", options: ["softly lit and quiet", "warm and faint", "silver and still", "damp and gold"])
            ]
        ),
        SentenceStarterTemplate(
            id: "core-small-witness",
            title: "Small witness",
            pattern: "For one second, {anchor} {motion} in {sense} light.",
            slots: [
                SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What held the moment?", options: ["the mug", "the door", "the chair", "the floor"]),
                SentenceStarterSlot(id: "motion", kind: .motion, title: "What did it seem to do?", options: ["waited", "leaned", "held", "listened"]),
                SentenceStarterSlot(id: "sense", kind: .sense, title: "What kind of light?", options: ["warm", "dim", "gold", "pale"])
            ]
        ),
        SentenceStarterTemplate(
            id: "core-crossed-sense",
            title: "Crossed sense",
            pattern: "The {anchor} {motion} like {crossing}.",
            slots: [
                SentenceStarterSlot(id: "anchor", kind: .anchor, title: "Choose a witness.", options: ["window", "clock", "blanket", "kettle"]),
                SentenceStarterSlot(id: "motion", kind: .motion, title: "Let it act.", options: ["tapped", "sighed", "waited", "flickered"]),
                SentenceStarterSlot(id: "crossing", kind: .crossing, title: "Give it a borrowed sense.", options: ["paper quiet", "warm hum", "blue sound", "yellow hush"])
            ]
        )
    ]

    static let souvenirStarterTemplates: [SentenceStarterTemplate] = [
        SentenceStarterTemplate(
            id: "souvenir-best-part",
            title: "Best part",
            pattern: "I want to remember the {sense} {anchor} that {motion}.",
            slots: [
                SentenceStarterSlot(id: "sense", kind: .sense, title: "What was its texture?", options: ["creased", "damp", "silver", "smoky"]),
                SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What came back with it?", options: ["receipt", "key", "cloud", "napkin"]),
                SentenceStarterSlot(id: "motion", kind: .motion, title: "What did it do?", options: ["stayed", "followed", "tugged", "kept"])
            ]
        ),
        SentenceStarterTemplate(
            id: "souvenir-still-mind",
            title: "Still in mind",
            pattern: "The best part was {anchor}, still {sense} in my mind.",
            slots: [
                SentenceStarterSlot(id: "anchor", kind: .anchor, title: "Name the proof.", options: ["the pocket", "the curb", "the mirror", "the cloud"]),
                SentenceStarterSlot(id: "sense", kind: .sense, title: "What trace did it leave?", options: ["warm", "faded", "smoky", "silver"])
            ]
        )
    ]
}

extension SentenceBuilderPack: Codable {
    enum CodingKeys: String, CodingKey {
        case id, displayName, ritualTitle, replayPrompt, replayHelper
        case vagueWords, avoidWords, concreteWords, sensoryWords, animateVerbs
        case crossingWords, themes, starterTemplates, version, author, availability
    }

    /// Lenient decoding: every field defaults, so an upgrade pack can ship only the
    /// parts it wants to add (a few `concreteWords`, one `theme`) and merge over core.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        ritualTitle = try c.decodeIfPresent(String.self, forKey: .ritualTitle) ?? ""
        replayPrompt = try c.decodeIfPresent(String.self, forKey: .replayPrompt) ?? ""
        replayHelper = try c.decodeIfPresent(String.self, forKey: .replayHelper) ?? ""
        vagueWords = try c.decodeIfPresent([String].self, forKey: .vagueWords) ?? []
        avoidWords = try c.decodeIfPresent([String].self, forKey: .avoidWords) ?? []
        concreteWords = try c.decodeIfPresent([String].self, forKey: .concreteWords) ?? []
        sensoryWords = try c.decodeIfPresent([String].self, forKey: .sensoryWords) ?? []
        animateVerbs = try c.decodeIfPresent([String].self, forKey: .animateVerbs) ?? []
        crossingWords = try c.decodeIfPresent([String].self, forKey: .crossingWords) ?? []
        themes = try c.decodeIfPresent([LexicalTheme].self, forKey: .themes) ?? []
        starterTemplates = try c.decodeIfPresent([SentenceStarterTemplate].self, forKey: .starterTemplates) ?? []
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? "The Book"
        availability = try c.decodeIfPresent(String.self, forKey: .availability) ?? "bundledFree"
    }
}

// MARK: - Expansion packs (more chips, as data)

extension SentenceBuilderPack {
    /// A bundled, purchasable expansion: more senses, livelier verbs, two new
    /// context themes. Additive only — it leaves the ritual naming alone and just
    /// deepens the word pools the chips draw from. The delivery seam for paid /
    /// patron word packs; user-authored JSON packs ride the same merge path.
    static let nightAndGarden = SentenceBuilderPack(
        id: "pack.night-and-garden",
        displayName: "",
        ritualTitle: "",
        replayPrompt: "",
        replayHelper: "",
        vagueWords: [],
        avoidWords: [],
        concreteWords: ["moth", "moon", "porch", "garden", "leaf", "petal",
                        "root", "stem", "soil", "fence", "moss", "lantern",
                        "pond", "frost", "branch", "owl"],
        sensoryWords: ["dewed", "loamy", "green", "silver", "violet", "musky",
                       "cool", "downy", "resinous", "moonlit"],
        animateVerbs: ["unfurled", "leaned", "breathed", "rooted", "drowsed",
                       "climbed", "nodded", "listened"],
        crossingWords: ["green silence", "moon-cold green", "soil dark",
                        "violet hush", "dew bright"],
        themes: [
            LexicalTheme(
                id: "garden",
                name: "Garden",
                anchors: ["garden", "leaf", "petal", "root", "stem", "soil",
                          "moss", "branch", "pond", "fence"],
                senses: ["dewed", "loamy", "green", "musky", "cool", "downy", "resinous"],
                verbs: ["unfurled", "rooted", "climbed", "leaned", "nodded", "drowsed"],
                crossings: ["green silence", "soil dark", "dew bright"]
            ),
            LexicalTheme(
                id: "night",
                name: "Night",
                anchors: ["moth", "moon", "lantern", "owl", "frost", "porch"],
                senses: ["silver", "violet", "moonlit", "cool", "frosted", "faint"],
                verbs: ["drowsed", "breathed", "listened", "nodded", "flickered"],
                crossings: ["moon-cold green", "violet hush", "velvet dark"]
            )
        ],
        version: 1,
        author: "The Goblin Index Empire",
        availability: "locked"
    )

    /// The Shadow Wonder lexicon — mono no aware made playable: rust, thorn, dusk,
    /// decay, and the worn edge. Not an entitlement-gated expansion; the capture
    /// sheet composes it only when `ShadowWonder.state(...).isActive`, which already
    /// includes the Dusk Thorn belief gate. It also seeds the Shadow Sentence
    /// Runner's catchable words via `ShadowWonder.gameWords`.
    static let shadowWonder = SentenceBuilderPack(
        id: "pack.shadow-wonder",
        displayName: "The Thornlight Index",
        ritualTitle: "Wake the worn edge",
        replayPrompt: "Close your eyes for one breath. What broken, old, or shadowed thing comes back first?",
        replayHelper: "Do not fix it. Catch the rust, the dusk, the crack, the thing time has touched — and let it be beautiful without brightening.",
        vagueWords: [],
        avoidWords: [],
        concreteWords: ["rust", "thorn", "dusk", "ash", "moth", "lichen", "hinge",
                        "ruin", "shard", "cobweb", "ember", "husk", "gravel",
                        "tarnish", "splinter", "bramble", "shadow", "lantern",
                        "keyhole", "ledger", "relic", "grate", "soot"],
        sensoryWords: ["rusted", "tarnished", "dim", "ashen", "thorned", "cracked",
                       "weathered", "smoke-stained", "violet", "leaden", "frayed",
                       "moth-eaten", "guttering", "brackish", "mossed", "umber"],
        animateVerbs: ["rusted", "guttered", "smouldered", "crumbled", "lingered",
                       "tarnished", "haunted", "outlasted", "weathered", "remembered",
                       "decayed", "endured", "settled", "festered"],
        crossingWords: ["rust quiet", "dusk copper", "ash violet", "thorn hush",
                        "smoke gold", "lichen silver", "ember dark", "grave green",
                        "tarnished light"],
        themes: [
            LexicalTheme(
                id: "decay",
                name: "Decay",
                anchors: ["rust", "ruin", "husk", "ash", "tarnish", "lichen", "cobweb", "splinter"],
                senses: ["rusted", "tarnished", "ashen", "cracked", "weathered", "moth-eaten"],
                verbs: ["rusted", "crumbled", "tarnished", "decayed", "outlasted", "endured"],
                crossings: ["rust quiet", "ash violet", "tarnished light"]
            ),
            LexicalTheme(
                id: "thornlight",
                name: "Thornlight",
                anchors: ["thorn", "dusk", "ember", "lantern", "shadow", "bramble", "keyhole"],
                senses: ["thorned", "dim", "violet", "guttering", "smoke-stained", "leaden"],
                verbs: ["guttered", "smouldered", "haunted", "lingered", "remembered"],
                crossings: ["dusk copper", "thorn hush", "ember dark", "smoke gold"]
            )
        ],
        version: 1,
        author: "The Dusk Thorn",
        availability: "bundledFree"
    )

    static let chapterNineMastery = SentenceBuilderPack(
        id: "pack.chapter-nine-sentence-mastery",
        displayName: "Penny's Sentence Desk",
        ritualTitle: "File the evidence",
        replayPrompt: "Close your eyes for one breath. What is the first concrete detail that comes back?",
        replayHelper: "Do not summarize the day. Bring Penny one object, one sense, one action, or one private line worth saving.",
        vagueWords: [],
        avoidWords: [],
        concreteWords: [
            "aisle", "bakery", "bench", "bird", "blue jay", "canvas", "cereal",
            "cloud", "coffee", "counter", "cup", "dock", "door", "fog", "garlic",
            "gem", "jar", "jay", "lake", "lemon", "mailbox", "mountain", "note", "oil",
            "page", "pie", "porch", "receipt", "river", "rock", "sentence",
            "sidewalk", "sink", "song", "stone", "tutu", "vault", "water"
        ],
        sensoryWords: [
            "blue", "brassy", "bright", "buttery", "cold", "crisp", "gold",
            "gray", "green", "hot", "metallic", "orange", "private", "salty",
            "silver", "slow", "smooth", "sour", "sticky", "warm"
        ],
        animateVerbs: [
            "called", "caught", "danced", "filed", "fought", "grabbed", "groaned",
            "hid", "kept", "leaned", "reached", "rumbled", "saved", "scratched",
            "testified", "tilted", "waited", "watched", "whispered"
        ],
        crossingWords: [
            "brass sour", "cold iron", "green smell", "orange sound",
            "silver hush", "slow Sunday", "sour trumpet", "warm quiet"
        ],
        themes: [
            LexicalTheme(
                id: "souvenir-evidence",
                name: "Souvenir evidence",
                anchors: ["receipt", "note", "jar", "page", "sentence", "vault", "pocket"],
                senses: ["private", "warm", "gold", "sticky", "smooth"],
                verbs: ["filed", "kept", "hid", "saved", "testified"],
                crossings: ["warm quiet", "silver hush", "slow Sunday"]
            ),
            LexicalTheme(
                id: "kitchen-memory",
                name: "Kitchen memory",
                anchors: ["garlic", "oil", "cup", "coffee", "counter", "sink", "lemon", "pie"],
                senses: ["buttery", "hot", "warm", "sour", "salty", "metallic"],
                verbs: ["reached", "waited", "watched", "whispered"],
                crossings: ["brass sour", "sour trumpet", "green smell"]
            ),
            LexicalTheme(
                id: "outside-proof",
                name: "Outside proof",
                anchors: ["bench", "bird", "blue jay", "cloud", "dock", "fog", "lake", "mailbox",
                          "mountain", "porch", "river", "rock", "sidewalk", "stone", "water"],
                senses: ["blue", "bright", "cold", "gray", "green", "gold", "silver", "smooth"],
                verbs: ["called", "caught", "grabbed", "groaned", "leaned", "rumbled", "tilted", "waited"],
                crossings: ["cold iron", "green smell", "orange sound", "silver hush"]
            )
        ],
        starterTemplates: [
            SentenceStarterTemplate(
                id: "chapter-nine-specific-detail",
                title: "Specific evidence",
                pattern: "The {sense} {anchor} {motion} before the day could delete it.",
                slots: [
                    SentenceStarterSlot(id: "sense", kind: .sense, title: "Physical detail", options: ["blue", "warm", "gold", "smooth"]),
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "Evidence", options: ["mug", "receipt", "bench", "cloud"]),
                    SentenceStarterSlot(id: "motion", kind: .motion, title: "What it did", options: ["waited", "kept", "caught", "leaned"])
                ]
            ),
            SentenceStarterTemplate(
                id: "chapter-nine-crossed-wire",
                title: "Crossed wire",
                pattern: "The {anchor} tasted like {crossing}.",
                slots: [
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "Witness", options: ["rain", "song", "coffee", "fog"]),
                    SentenceStarterSlot(id: "crossing", kind: .crossing, title: "Wrong lane", options: ["cold iron", "orange sound", "slow Sunday", "silver hush"])
                ]
            ),
            SentenceStarterTemplate(
                id: "chapter-nine-world-acts",
                title: "World takes the verb",
                pattern: "The {anchor} {motion} me with {sense} patience.",
                slots: [
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "Actor", options: ["bench", "door", "stone", "mountain"]),
                    SentenceStarterSlot(id: "motion", kind: .motion, title: "Plain verb", options: ["caught", "waited", "grabbed", "tilted"]),
                    SentenceStarterSlot(id: "sense", kind: .sense, title: "Trace", options: ["warm", "cold", "gold", "private"])
                ]
            ),
            SentenceStarterTemplate(
                id: "chapter-nine-vault",
                title: "Vault sentence",
                pattern: "I am keeping the {sense} {anchor} private until tomorrow.",
                slots: [
                    SentenceStarterSlot(id: "sense", kind: .sense, title: "What kind?", options: ["gold", "warm", "silver", "smooth"]),
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What stays yours?", options: ["light", "coffee", "note", "cloud"])
                ]
            )
        ],
        version: 1,
        author: "Penny Blackletter",
        availability: "bundledFree"
    )
}

/// Registry for sentence-builder content, mirroring `PageArchetypePackRegistry`
/// and the other JSON pack registries: bundled packs ship in the binary, user
/// packs drop into Documents as `*.sentencepack.json`, and entitlements gate the
/// locked ones. `composed(onto:)` is how installed word packs reach the editor.
enum SentenceBuilderPackRegistry {
    static let userPackFileSuffix = ".sentencepack.json"

    /// Selectable rituals — the packs a surface chooses between.
    static let basePacks: [SentenceBuilderPack] = [.core, .souvenir]

    /// Additive vocabulary/theme packs that deepen whatever ritual is active.
    static let bundledExpansionPacks: [SentenceBuilderPack] = [.nightAndGarden]

    /// User-imported expansion packs: any `*.sentencepack.json` in Documents.
    static func userPacks(fileManager: FileManager = .default) -> [SentenceBuilderPack] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        return contents
            .filter { $0.lastPathComponent.hasSuffix(userPackFileSuffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      var pack = try? decoder.decode(SentenceBuilderPack.self, from: data) else {
                    return nil
                }
                if pack.availability != "locked" { pack.availability = "userImported" }
                return pack
            }
    }

    static func validateImport(data: Data) -> SentenceBuilderPack? {
        guard var pack = try? JSONDecoder().decode(SentenceBuilderPack.self, from: data),
              !pack.isEmptyImport else {
            return nil
        }
        if pack.availability != "locked" { pack.availability = "userImported" }
        return pack
    }

    /// Every expansion the player is entitled to right now.
    static func enabledExpansionPacks(fileManager: FileManager = .default) -> [SentenceBuilderPack] {
        (bundledExpansionPacks + userPacks(fileManager: fileManager))
            .filter { !$0.isLocked || PackEntitlements.isUnlocked($0.id) }
    }

    /// Merge every enabled expansion onto a base ritual. This is what the editor
    /// should be handed instead of a bare `.core`, so installed word packs appear.
    static func composed(onto base: SentenceBuilderPack, fileManager: FileManager = .default) -> SentenceBuilderPack {
        enabledExpansionPacks(fileManager: fileManager)
            .reduce(base) { $0.merged(with: $1) }
    }

    /// Merge installed content packs and the player's living Lexicon in memory.
    /// The Lexicon is save-state, not an imported `*.sentencepack.json`, so it
    /// never writes generated pack files into Documents.
    static func composed(
        onto base: SentenceBuilderPack,
        readerLexicon: ReaderLexicon,
        fileManager: FileManager = .default
    ) -> SentenceBuilderPack {
        composed(onto: base, fileManager: fileManager)
            .merged(with: readerLexicon.asSentenceBuilderPack())
    }

    /// Cached convenience for the two common rituals, so reused views don't rescan
    /// Documents on every render. Cleared by `reload()` after an import/unlock.
    nonisolated(unsafe) private static var cache: [String: SentenceBuilderPack] = [:]

    static func composedCore() -> SentenceBuilderPack {
        if let hit = cache["core"] { return hit }
        let pack = composed(onto: .core)
        cache["core"] = pack
        return pack
    }

    static func composedCore(readerLexicon: ReaderLexicon, shadowWonderActive: Bool = false) -> SentenceBuilderPack {
        var pack = composedCore()
            .merged(with: readerLexicon.asSentenceBuilderPack())
        if shadowWonderActive { pack = pack.merged(with: .shadowWonder) }
        return pack
    }

    static func composedSouvenir() -> SentenceBuilderPack {
        if let hit = cache["souvenir"] { return hit }
        let pack = composed(onto: .core.merged(with: .souvenir))
        cache["souvenir"] = pack
        return pack
    }

    static func composedSouvenir(readerLexicon: ReaderLexicon, shadowWonderActive: Bool = false) -> SentenceBuilderPack {
        var pack = composedSouvenir()
            .merged(with: readerLexicon.asSentenceBuilderPack())
        if shadowWonderActive { pack = pack.merged(with: .shadowWonder) }
        return pack
    }

    static func composedChapterNineMastery() -> SentenceBuilderPack {
        if let hit = cache["chapter-nine-mastery"] { return hit }
        let pack = composed(onto: .core.merged(with: .souvenir).merged(with: .chapterNineMastery))
        cache["chapter-nine-mastery"] = pack
        return pack
    }

    static func composedChapterNineMastery(readerLexicon: ReaderLexicon, shadowWonderActive: Bool = false) -> SentenceBuilderPack {
        var pack = composedChapterNineMastery()
            .merged(with: readerLexicon.asSentenceBuilderPack())
        if shadowWonderActive { pack = pack.merged(with: .shadowWonder) }
        return pack
    }

    static func reload() { cache.removeAll() }
}

private extension SentenceBuilderPack {
    var isEmptyImport: Bool {
        concreteWords.isEmpty
            && sensoryWords.isEmpty
            && animateVerbs.isEmpty
            && crossingWords.isEmpty
            && themes.isEmpty
            && starterTemplates.isEmpty
    }
}

/// The grammatical job a word is doing inside a sentence.
///
/// The scaffold owns grammar so the user can never assemble a jumble: chips edit
/// real words in place (a single-token swap can't break a sentence) rather than
/// stamping bare vocabulary onto the end of a blob.
enum SentenceRole: String, Codable, Equatable {
    case thing      // concrete anchor noun
    case sense      // sensory quality
    case motion     // animate verb
    case crossing   // crossed-sense phrase
    case misty      // vague word the engine wants grounded
    case smoke      // "avoid" / stage-smoke word
    case plain      // grammar glue: articles, pronouns, untagged words

    /// Roles that carry the craft of a memory-sticky sentence (vs. glue or warnings).
    var isCraft: Bool {
        switch self {
        case .thing, .sense, .motion, .crossing: return true
        case .misty, .smoke, .plain: return false
        }
    }
}

/// One word (plus any trailing punctuation) lifted from the user's own sentence,
/// tagged with the grammatical job it is doing.
struct ScaffoldToken: Identifiable, Equatable {
    var id: Int                 // stable index position in the sentence
    var word: String            // the bare word, no surrounding punctuation
    var leadingWhitespace: String
    var trailingPunctuation: String
    var role: SentenceRole

    /// Faithful reconstruction of the original surface text for this token.
    var surface: String {
        leadingWhitespace + word + trailingPunctuation
    }

    /// A token carrying a craft role can be transformed in place by a chip.
    var isTransformable: Bool {
        role.isCraft || role == .misty || role == .smoke
    }
}

/// A parse of the user's sentence into tagged tokens. Built from their own words,
/// it round-trips faithfully and only ever changes one token at a time, so any
/// edit it produces is grammatical by construction.
struct SentenceScaffold: Equatable {
    var tokens: [ScaffoldToken]

    /// The original sentence, rebuilt from tokens. Round-trips the input text.
    var rendered: String {
        tokens.map(\.surface).joined()
    }

    /// Craft roles currently present in the sentence.
    var presentRoles: Set<SentenceRole> {
        Set(tokens.map(\.role).filter(\.isCraft))
    }

    /// Replace one token's word in place, preserving its punctuation and spacing.
    /// Re-tags the swapped word so role highlighting stays honest.
    func replacing(tokenID: Int, with newWord: String, using pack: SentenceBuilderPack) -> SentenceScaffold {
        guard let index = tokens.firstIndex(where: { $0.id == tokenID }) else { return self }
        var updated = tokens
        let cleaned = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return self }
        let replacement = Self.matchingCapitalization(of: updated[index].word, replacement: cleaned)
        updated[index].word = replacement
        updated[index].role = SentenceScaffold.role(for: replacement, using: pack)
        if index > 0 {
            let prior = updated[index - 1].word.lowercased()
            if prior == "a" || prior == "an" {
                let wantsAn = Self.startsWithVowelSound(replacement)
                let article = wantsAn ? "an" : "a"
                updated[index - 1].word = Self.matchingCapitalization(
                    of: updated[index - 1].word,
                    replacement: article
                )
            }
        }
        return SentenceScaffold(tokens: updated)
    }

    private static func matchingCapitalization(of original: String, replacement: String) -> String {
        guard let first = original.first, first.isUppercase, let replacementFirst = replacement.first else {
            return replacement
        }
        return replacementFirst.uppercased() + replacement.dropFirst()
    }

    private static func startsWithVowelSound(_ value: String) -> Bool {
        guard let firstLetter = value.lowercased().first(where: \.isLetter) else { return false }
        return "aeiou".contains(firstLetter)
    }
}

extension SentenceScaffold {
    /// Tag a user sentence into roled tokens using the active pack's vocabulary.
    static func tag(_ text: String, using pack: SentenceBuilderPack) -> SentenceScaffold {
        var tokens: [ScaffoldToken] = []
        var index = 0
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        let lower = text.lowercased()
        // Pre-mark spans covered by multi-word crossing phrases so their words read as `.crossing`.
        var crossingSpans = false
        for phrase in pack.crossingWords where lower.contains(phrase.lowercased()) {
            crossingSpans = true
            break
        }

        while !scanner.isAtEnd {
            let leading = scanner.scanCharacters(from: .whitespacesAndNewlines) ?? ""
            guard let chunk = scanner.scanUpToCharacters(from: .whitespacesAndNewlines), !chunk.isEmpty else {
                if !leading.isEmpty, var last = tokens.popLast() {
                    last.trailingPunctuation += leading
                    tokens.append(last)
                }
                break
            }

            let (word, trailing) = splitTrailingPunctuation(chunk)
            var role = role(for: word, using: pack)
            if role == .plain, crossingSpans, isWordInCrossingPhrase(word, pack: pack, lowerText: lower) {
                role = .crossing
            }
            tokens.append(ScaffoldToken(
                id: index,
                word: word,
                leadingWhitespace: leading,
                trailingPunctuation: trailing,
                role: role
            ))
            index += 1
        }
        return SentenceScaffold(tokens: tokens)
    }

    /// Classify a single bare word against the pack's vocabulary lists.
    /// Order encodes priority: warnings first, then craft roles, else glue.
    static func role(for word: String, using pack: SentenceBuilderPack) -> SentenceRole {
        let key = word.lowercased()
        if pack.avoidWords.contains(where: { $0.lowercased() == key }) { return .smoke }
        if pack.vagueWords.contains(where: { $0.lowercased() == key }) { return .misty }
        if pack.concreteWords.contains(where: { $0.lowercased() == key }) { return .thing }
        if pack.sensoryWords.contains(where: { $0.lowercased() == key }) { return .sense }
        if pack.animateVerbs.contains(where: { $0.lowercased() == key }) { return .motion }
        if pack.crossingWords.contains(where: { $0.lowercased() == key }) { return .crossing }
        return .plain
    }

    private static func isWordInCrossingPhrase(_ word: String, pack: SentenceBuilderPack, lowerText: String) -> Bool {
        let key = word.lowercased()
        for phrase in pack.crossingWords where lowerText.contains(phrase.lowercased()) {
            let parts = phrase.lowercased().components(separatedBy: " ")
            if parts.contains(key) { return true }
        }
        return false
    }

    /// Peel trailing punctuation (.,;:!?…"')) off a chunk so the bare word can be tagged.
    private static func splitTrailingPunctuation(_ chunk: String) -> (word: String, trailing: String) {
        let punctuation = CharacterSet(charactersIn: ".,;:!?…\"')]}")
        var word = chunk
        var trailing = ""
        while let last = word.unicodeScalars.last, punctuation.contains(last) {
            trailing = String(word.removeLast()) + trailing
        }
        return (word, trailing)
    }
}

/// One grammar-safe transmutation a chip can apply to a tapped word.
struct SentenceMove: Identifiable, Equatable {
    var id: String
    var label: String   // text shown on the chip
    var word: String    // the replacement word dropped into the slot
    var group: String   // "ground" | "thing" | "sense" | "motion" | "cross"
}

struct SentenceBuilderCraftMark: Identifiable, Equatable {
    var id: SentenceBuilderStepKind
    var title: String
    var isPresent: Bool
    var hint: String
}

struct SentenceBuilderDiagnostic: Identifiable, Equatable {
    enum Severity: Equatable {
        case prompt
        case warning
    }

    var id: String
    var severity: Severity
    var title: String
    var message: String
    var word: String?
}

struct SentenceBuilderAnalysis: Equatable {
    var wordCount: Int
    var hasConcreteAnchor: Bool
    var hasSensoryDetail: Bool
    var hasLivingMotion: Bool
    var hasWorldActor: Bool
    var hasCrossedSense: Bool
    var memoryStrength: Int
    var craftMarks: [SentenceBuilderCraftMark]
    var diagnostics: [SentenceBuilderDiagnostic]
    var meetsIntentMinimum: Bool

    var canStandAsComplete: Bool {
        meetsIntentMinimum
    }

    var isVivid: Bool {
        memoryStrength >= 3
    }
}

struct SentenceBuilderEngine {
    var pack: SentenceBuilderPack
    var context: SentenceBuilderContext

    init(pack: SentenceBuilderPack = .core, context: SentenceBuilderContext = .empty) {
        self.pack = pack
        self.context = context
    }

    /// The reusable pack plus words found on this particular page. Keeping this
    /// computed avoids mutating or persisting a user's installed packs.
    var resolvedPack: SentenceBuilderPack {
        let vocabulary = contextVocabulary()
        return resolvedPack(with: vocabulary)
    }

    private func resolvedPack(with vocabulary: SentenceContextVocabulary) -> SentenceBuilderPack {
        guard !vocabulary.isEmpty else { return pack }
        let overlay = SentenceBuilderPack(
            id: "runtime.context",
            displayName: "",
            ritualTitle: "",
            replayPrompt: "",
            replayHelper: "",
            vagueWords: [],
            avoidWords: [],
            concreteWords: vocabulary.anchors,
            sensoryWords: vocabulary.senses,
            animateVerbs: vocabulary.verbs,
            crossingWords: [],
            version: pack.version,
            author: "This page",
            availability: "runtime"
        )
        return pack.merged(with: overlay)
    }

    func analyze(_ text: String) -> SentenceBuilderAnalysis {
        let activePack = resolvedPack
        let normalizedWords = words(in: text)
        let wordCount = normalizedWords.count
        let wordSet = Set(normalizedWords)
        let lower = text.lowercased()

        let hasConcreteAnchor = containsAnyWord(from: activePack.concreteWords, in: wordSet)
        let hasSensoryDetail = containsAnyWord(from: activePack.sensoryWords, in: wordSet)
        let hasLivingMotion = containsAnyWord(from: activePack.animateVerbs, in: wordSet)
        let hasWorldActor = detectsWorldActor(in: normalizedWords, pack: activePack)
        let hasCrossedSense = activePack.crossingWords.contains { lower.contains($0.lowercased()) }
            || (hasSensoryDetail && lower.contains(" sound"))
            || (hasSensoryDetail && lower.contains(" taste"))
            || (hasSensoryDetail && lower.contains(" quiet"))

        let marks = craftMarks(
            text: text,
            words: normalizedWords,
            hasConcreteAnchor: hasConcreteAnchor,
            hasSensoryDetail: hasSensoryDetail,
            hasLivingMotion: hasLivingMotion,
            hasCrossedSense: hasCrossedSense
        )
        let memoryStrength = marks.filter(\.isPresent).count

        var diagnostics: [SentenceBuilderDiagnostic] = []
        if let avoidWord = hasAvoidWord(text) {
            diagnostics.append(SentenceBuilderDiagnostic(
                id: "avoid-\(avoidWord)",
                severity: .warning,
                title: "Too much stage smoke",
                message: "Try giving '\(avoidWord)' a physical job in the room.",
                word: avoidWord
            ))
        }
        if let vagueWord = firstMatchedWord(in: text, words: pack.vagueWords) {
            diagnostics.append(SentenceBuilderDiagnostic(
                id: "vague-\(vagueWord)",
                severity: .prompt,
                title: "Mist word",
                message: "'\(vagueWord)' may be true. What did it feel like in matter?",
                word: vagueWord
            ))
        }
        if wordCount >= 5 && !hasConcreteAnchor && context.intent != .letterReply {
            diagnostics.append(SentenceBuilderDiagnostic(
                id: "missing-anchor",
                severity: .prompt,
                title: "Give it a witness",
                message: "One real noun will help the memory know where to land.",
                word: nil
            ))
        }

        return SentenceBuilderAnalysis(
            wordCount: wordCount,
            hasConcreteAnchor: hasConcreteAnchor,
            hasSensoryDetail: hasSensoryDetail,
            hasLivingMotion: hasLivingMotion,
            hasWorldActor: hasWorldActor,
            hasCrossedSense: hasCrossedSense,
            memoryStrength: memoryStrength,
            craftMarks: marks,
            diagnostics: diagnostics,
            meetsIntentMinimum: canStand(
                wordCount: wordCount,
                hasConcreteAnchor: hasConcreteAnchor,
                hasSensoryDetail: hasSensoryDetail,
                hasLivingMotion: hasLivingMotion,
                marks: marks
            )
        )
    }

    /// Parse the user's current text into a grammar-safe scaffold of tagged tokens.
    func scaffold(for text: String) -> SentenceScaffold {
        SentenceScaffold.tag(text, using: resolvedPack)
    }

    /// The dominant context theme of a sentence: whichever pack theme has the most
    /// of its anchor nouns present. Drives context-aware chip ordering.
    func dominantTheme(in scaffold: SentenceScaffold) -> LexicalTheme? {
        dominantTheme(in: scaffold, using: resolvedPack)
    }

    private func dominantTheme(in scaffold: SentenceScaffold, using activePack: SentenceBuilderPack) -> LexicalTheme? {
        guard !activePack.themes.isEmpty else { return nil }
        let present = Set(scaffold.tokens.map { $0.word.lowercased() })
        var best: (theme: LexicalTheme, score: Int)?
        for theme in activePack.themes {
            let score = theme.anchors.reduce(0) { $0 + (present.contains($1.lowercased()) ? 1 : 0) }
            if score > 0, score > (best?.score ?? 0) {
                best = (theme, score)
            }
        }
        return best?.theme
    }

    /// The transmutations offered when the user taps a word in their sentence.
    /// Every move is a grammar-safe in-place swap, so the sentence can never break.
    ///
    /// Suggestions reflect context: words from the sentence's dominant theme come
    /// first, then the global pool. Words already in the sentence are skipped, so
    /// the chips are always live alternatives the user hasn't used yet.
    func moves(
        for token: ScaffoldToken,
        in scaffold: SentenceScaffold,
        limit: Int = 8,
        avoiding recentlyShownOrChosen: Set<String> = []
    ) -> [SentenceMove] {
        let runtimeVocabulary = contextVocabulary()
        let activePack = resolvedPack(with: runtimeVocabulary)
        let current = token.word.lowercased()
        let alreadyUsed = Set(scaffold.tokens.map { $0.word.lowercased() }).subtracting([current])
        let theme = dominantTheme(in: scaffold, using: activePack)

        // Theme words first (context), then the global pool — deduped, current and
        // already-present words removed. Paging happens after this complete ranked
        // list is built so "More" can move beyond the first eight.
        func compose(themed: [String], global: [String], group: String) -> (moves: [SentenceMove], pinnedKeys: [String]) {
            var seen = Set<String>()
            var out: [SentenceMove] = []
            let themedKeys = themed.map { $0.lowercased() }.uniquedPreservingOrder()
            let candidates = (themed + global).enumerated().sorted { lhs, rhs in
                let leftScore = suggestionScore(
                    for: lhs.element,
                    token: token,
                    theme: theme,
                    runtimeVocabulary: runtimeVocabulary
                )
                let rightScore = suggestionScore(
                    for: rhs.element,
                    token: token,
                    theme: theme,
                    runtimeVocabulary: runtimeVocabulary
                )
                return leftScore == rightScore ? lhs.offset < rhs.offset : leftScore > rightScore
            }.map(\.element)
            let grammarMatched = candidates.filter { grammaticallyFits($0, replacing: token) }
            let ordered = grammarMatched.isEmpty ? candidates : grammarMatched
            for word in ordered {
                let key = word.lowercased()
                guard key != current, !alreadyUsed.contains(key), seen.insert(key).inserted else { continue }
                out.append(SentenceMove(id: "\(group)-\(key)", label: word, word: word, group: group))
            }
            return (out, themedKeys)
        }

        switch token.role {
        case .misty:
            let pool = compose(themed: alternatives(for: token.word), global: theme?.senses ?? [], group: "ground")
            return rotatingMoves(pool.moves, pinnedKeys: pool.pinnedKeys, avoiding: recentlyShownOrChosen, limit: limit)
        case .smoke:
            // Stage-smoke words become a plain physical quality the room can carry.
            let pool = compose(themed: alternatives(for: token.word), global: (theme?.senses ?? []) + activePack.sensoryWords, group: "ground")
            return rotatingMoves(pool.moves, pinnedKeys: pool.pinnedKeys, avoiding: recentlyShownOrChosen, limit: limit)
        case .thing:
            let pool = compose(themed: runtimeVocabulary.anchors + (theme?.anchors ?? []), global: activePack.concreteWords, group: "thing")
            return rotatingMoves(pool.moves, pinnedKeys: pool.pinnedKeys, avoiding: recentlyShownOrChosen, limit: limit)
        case .sense:
            // Interleave each page with crossed-sense leaps so that lane rotates,
            // rather than permanently showing the first two authored phrases.
            let senses = compose(
                themed: runtimeVocabulary.senses + (theme?.senses ?? []),
                global: activePack.sensoryWords,
                group: "sense"
            )
            let crossings = compose(
                themed: theme?.crossings ?? [],
                global: activePack.crossingWords,
                group: "cross"
            )
            let mixed = interleavedSenseMoves(senses.moves, crossings: crossings.moves, pageSize: limit)
            return rotatingMoves(
                mixed,
                pinnedKeys: senses.pinnedKeys + crossings.pinnedKeys,
                avoiding: recentlyShownOrChosen,
                limit: limit
            )
        case .motion:
            let pool = compose(themed: runtimeVocabulary.verbs + (theme?.verbs ?? []), global: activePack.animateVerbs, group: "motion")
            return rotatingMoves(pool.moves, pinnedKeys: pool.pinnedKeys, avoiding: recentlyShownOrChosen, limit: limit)
        case .crossing:
            let pool = compose(themed: theme?.crossings ?? [], global: activePack.crossingWords, group: "cross")
            return rotatingMoves(pool.moves, pinnedKeys: pool.pinnedKeys, avoiding: recentlyShownOrChosen, limit: limit)
        case .plain:
            return []
        }
    }

    func starterDraft(seed: String = "default") -> SentenceStarterDraft? {
        let intentTemplates = contextualStarterTemplates
        let templates = intentTemplates.isEmpty ? resolvedPack.starterTemplates : intentTemplates
        guard !templates.isEmpty else { return nil }
        let template = templates[stableIndex(for: seed, count: templates.count)]
        var selections: [String: String] = [:]
        for slot in template.slots {
            selections[slot.id] = options(for: slot, in: SentenceStarterDraft(template: template, selections: selections), limit: 1).first
                ?? fallbackOption(for: slot.kind)
        }
        return SentenceStarterDraft(template: template, selections: selections)
    }

    func options(
        for slot: SentenceStarterSlot,
        in draft: SentenceStarterDraft,
        limit: Int = 8,
        avoiding recentlyShownOrChosen: Set<String> = []
    ) -> [String] {
        let runtimeVocabulary = contextVocabulary()
        let activePack = resolvedPack(with: runtimeVocabulary)
        let theme = starterTheme(for: draft, using: activePack)
        let themed: [String]
        let global: [String]
        switch slot.kind {
        case .anchor:
            themed = runtimeVocabulary.anchors + (theme?.anchors ?? [])
            global = activePack.concreteWords
        case .sense:
            themed = runtimeVocabulary.senses + (theme?.senses ?? [])
            global = activePack.sensoryWords
        case .motion:
            themed = runtimeVocabulary.verbs + (theme?.verbs ?? [])
            global = activePack.animateVerbs
        case .crossing:
            themed = theme?.crossings ?? []
            global = activePack.crossingWords
        }
        let selected = draft.selections[slot.id].map { [$0] } ?? []
        let ordered = context.hasRuntimeClues
            ? selected + themed + slot.options + global
            : selected + slot.options + themed + global
        let candidates = uniqueStarterOptions(ordered, limit: .max)
        return rotatingWords(
            candidates,
            pinnedKeys: selected + themed,
            avoiding: recentlyShownOrChosen,
            limit: limit,
            pinnedLimit: selected.isEmpty ? 2 : 3
        )
    }

    func selecting(_ option: String, for slot: SentenceStarterSlot, in draft: SentenceStarterDraft) -> SentenceStarterDraft {
        var updated = draft
        updated.selections[slot.id] = option
        return updated
    }

    func render(_ draft: SentenceStarterDraft) -> String {
        draft.template.slots.reduce(draft.template.pattern) { rendered, slot in
            let value = draft.selections[slot.id] ?? fallbackOption(for: slot.kind)
            return rendered.replacingOccurrences(of: "{\(slot.id)}", with: value)
        }
    }

    func souvenirShareText(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "\(trimmed)\n\n— One-Sentence Souvenir"
    }

    var replayPrompt: String {
        switch context.intent {
        case .letterReply:
            return "What part of their note are you answering first?"
        case .reflection:
            return "What fact made this thought true for you?"
        case .missionProof:
            return "What is the smallest piece of evidence you brought back?"
        case .souvenir, .marginNote:
            return pack.replayPrompt
        }
    }

    var replayHelper: String {
        switch context.intent {
        case .letterReply:
            return "Touch one detail they gave you, then let your own voice answer it."
        case .reflection:
            return "Begin with the object, moment, or body signal before explaining what it meant."
        case .missionProof:
            return "Name what you found and what it did. Field notes are allowed to be tiny."
        case .souvenir, .marginNote:
            return pack.replayHelper
        }
    }

    func hasAvoidWord(_ text: String) -> String? {
        firstMatchedWord(in: text, words: pack.avoidWords)
    }

    /// Grounded, body-giving swaps for a vague feeling word. Every word returned
    /// also lives in `sensoryWords`, so choosing one lights the "Body" craft mark
    /// and stays tappable for further refinement.
    private func alternatives(for word: String) -> [String] {
        switch word.lowercased() {
        case "tired", "busy":
            return ["heavy", "grainy", "stale", "frayed", "leaden", "thin"]
        case "sad":
            return ["hollow", "cold", "thin", "ashen", "grey", "faint"]
        case "happy", "good", "great":
            return ["warm", "bright", "gold", "amber", "loose", "lit"]
        case "bad", "weird":
            return ["sour", "crooked", "rusty", "sharp", "raw", "brittle"]
        case "nice", "fine", "okay", "ok":
            return ["warm", "soft", "faint", "flat", "pale", "dim"]
        case "interesting":
            return ["sharp", "bright", "lit", "crisp", "raw", "amber"]
        case "beautiful":
            return ["lit", "gold", "pale", "bright", "amber", "soft"]
        case "scared", "anxious", "nervous":
            return ["cold", "thin", "sharp", "brittle", "faint", "raw"]
        case "angry", "mad":
            return ["hot", "sharp", "loud", "raw", "copper", "leaden"]
        case "calm", "peaceful", "relaxed":
            return ["warm", "soft", "faint", "pale", "dim", "loose"]
        case "excited":
            return ["bright", "hot", "loud", "lit", "sharp", "crisp"]
        case "lonely":
            return ["hollow", "cold", "thin", "grey", "faint", "pale"]
        default:
            return ["warm", "cold", "rough", "dim", "sharp", "soft", "heavy"]
        }
    }

    private func firstMatchedWord(in text: String, words: [String]) -> String? {
        let lower = text.lowercased()
        for word in words {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word.lowercased()))\\b"
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return word
            }
        }
        return nil
    }

    private func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func containsAnyWord(from words: [String], in wordSet: Set<String>) -> Bool {
        words.contains { wordSet.contains($0.lowercased()) }
    }

    private func detectsWorldActor(in sentenceWords: [String], pack activePack: SentenceBuilderPack) -> Bool {
        let concrete = Set(activePack.concreteWords.compactMap { entry -> String? in
            let tokens = words(in: entry)
            return tokens.count == 1 ? tokens[0] : nil
        })
        let livingVerbs = Set(activePack.animateVerbs.compactMap { entry -> String? in
            let tokens = words(in: entry)
            return tokens.count == 1 ? tokens[0] : nil
        })
        let firstPersonSubjects: Set<String> = ["i", "we"]
        let firstPersonWords: Set<String> = ["i", "me", "my", "mine", "we", "us", "our", "ours"]
        guard !concrete.isEmpty, !livingVerbs.isEmpty else { return false }

        for index in sentenceWords.indices where concrete.contains(sentenceWords[index]) {
            let lookbehindStart = max(0, index - 4)
            let lookbehind = sentenceWords[lookbehindStart..<index]
            guard !lookbehind.contains(where: { firstPersonSubjects.contains($0) }) else { continue }

            let lookaheadEnd = min(sentenceWords.count, index + 5)
            guard index + 1 < lookaheadEnd else { continue }
            for verbIndex in (index + 1)..<lookaheadEnd where livingVerbs.contains(sentenceWords[verbIndex]) {
                let bridge = sentenceWords[(index + 1)..<verbIndex]
                if !bridge.contains(where: { firstPersonWords.contains($0) }) {
                    return true
                }
            }
        }
        return false
    }

    private func starterTheme(for draft: SentenceStarterDraft, using activePack: SentenceBuilderPack) -> LexicalTheme? {
        let selected = Set(draft.selections.values.flatMap { words(in: $0) })
        var best: (theme: LexicalTheme, score: Int)?
        for theme in activePack.themes {
            let score = theme.anchors.reduce(0) { $0 + (selected.contains($1.lowercased()) ? 1 : 0) }
            if score > 0, score > (best?.score ?? 0) {
                best = (theme, score)
            }
        }
        return best?.theme
    }

    private func craftMarks(
        text: String,
        words sentenceWords: [String],
        hasConcreteAnchor: Bool,
        hasSensoryDetail: Bool,
        hasLivingMotion: Bool,
        hasCrossedSense: Bool
    ) -> [SentenceBuilderCraftMark] {
        let closes = text.trimmingCharacters(in: .whitespacesAndNewlines).last.map { ".!?".contains($0) } ?? false
        let hasVoice = sentenceWords.contains { ["i", "me", "my", "we", "our", "you", "your"].contains($0) }
            || context.recipientName.map { recipient in
                let recipientWords = Set(words(in: recipient))
                return !recipientWords.isDisjoint(with: Set(sentenceWords))
            } ?? false
        let hasEcho = contextEchoes(in: sentenceWords)
        let hasMeaning = sentenceWords.contains {
            ["because", "so", "when", "while", "meant", "means", "noticed", "realized", "needed", "wanted"].contains($0)
        }
        let hasAction = hasLivingMotion || containsLikelyVerb(in: text)

        switch context.intent {
        case .letterReply:
            return [
                craftMark(.anchor, "Answer", sentenceWords.count >= 3, "Begin with the one thing you want to say back."),
                craftMark(.sense, "Echo", hasEcho, "Touch one detail or idea from the note you received."),
                craftMark(.motion, "Voice", hasVoice, "Let your own voice enter: I, we, you, or their name."),
                craftMark(.crossing, "Close", closes && sentenceWords.count >= 5, "Let the reply land with a complete thought.")
            ]
        case .missionProof:
            return [
                craftMark(.anchor, "Proof", hasConcreteAnchor, "Name the object, place, sound, or sight you found."),
                craftMark(.sense, "Detail", hasSensoryDetail, "Keep one observable color, texture, sound, smell, or pressure."),
                craftMark(.motion, "Action", hasAction, "Say what happened or what the world did."),
                craftMark(.crossing, "Return", closes && sentenceWords.count >= 4, "Bring the field note home as one complete sentence.")
            ]
        case .reflection:
            return [
                craftMark(.anchor, "Truth", sentenceWords.count >= 3, "Name what is true without polishing it away."),
                craftMark(.sense, "Evidence", hasConcreteAnchor || hasSensoryDetail, "Give the thought one real piece of evidence."),
                craftMark(.motion, "Meaning", hasMeaning, "Add the turn: because, when, so, or what you noticed."),
                craftMark(.crossing, "Land", closes && sentenceWords.count >= 5, "Let the thought arrive somewhere definite.")
            ]
        case .souvenir, .marginNote:
            return [
                craftMark(.anchor, "Thing", hasConcreteAnchor, "Name the object, place, body part, or weather."),
                craftMark(.sense, "Body", hasSensoryDetail, "Add temperature, texture, color, taste, sound, or smell."),
                craftMark(.motion, "Will", hasLivingMotion, "Let a nonhuman thing act with a plain verb."),
                craftMark(.crossing, "Cross", hasCrossedSense, "Let one sense borrow from another.")
            ]
        }
    }

    private func craftMark(
        _ id: SentenceBuilderStepKind,
        _ title: String,
        _ isPresent: Bool,
        _ hint: String
    ) -> SentenceBuilderCraftMark {
        SentenceBuilderCraftMark(id: id, title: title, isPresent: isPresent, hint: hint)
    }

    private func canStand(
        wordCount: Int,
        hasConcreteAnchor: Bool,
        hasSensoryDetail: Bool,
        hasLivingMotion: Bool,
        marks: [SentenceBuilderCraftMark]
    ) -> Bool {
        switch context.intent {
        case .letterReply:
            let hasEcho = marks.first(where: { $0.title == "Echo" })?.isPresent == true
            let hasVoice = marks.first(where: { $0.title == "Voice" })?.isPresent == true
            return wordCount >= 3 && (hasEcho || hasVoice)
        case .missionProof:
            return wordCount >= 3 && hasConcreteAnchor && (hasLivingMotion || marks.first(where: { $0.title == "Action" })?.isPresent == true)
        case .reflection:
            return wordCount >= 4 && (hasConcreteAnchor || hasSensoryDetail || marks.first(where: { $0.title == "Meaning" })?.isPresent == true)
        case .souvenir, .marginNote:
            return wordCount >= 4 && (hasConcreteAnchor || hasSensoryDetail || hasLivingMotion)
        }
    }

    private var contextualStarterTemplates: [SentenceStarterTemplate] {
        switch context.intent {
        case .letterReply:
            return [SentenceStarterTemplate(
                id: "context-reply",
                title: "A line back",
                pattern: "Your note about {anchor} left me feeling {sense}.",
                slots: [
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What stayed with you?", options: []),
                    SentenceStarterSlot(id: "sense", kind: .sense, title: "What did it leave?", options: [])
                ]
            )]
        case .reflection:
            return [SentenceStarterTemplate(
                id: "context-reflection",
                title: "What became clear",
                pattern: "When I noticed {anchor}, I felt {sense}.",
                slots: [
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What is the evidence?", options: []),
                    SentenceStarterSlot(id: "sense", kind: .sense, title: "How did it register?", options: [])
                ]
            )]
        case .missionProof:
            return [SentenceStarterTemplate(
                id: "context-proof",
                title: "Field evidence",
                pattern: "The {anchor} {motion}; that was the detail I brought back.",
                slots: [
                    SentenceStarterSlot(id: "anchor", kind: .anchor, title: "What did you find?", options: []),
                    SentenceStarterSlot(id: "motion", kind: .motion, title: "What did it do?", options: [])
                ]
            )]
        case .souvenir, .marginNote:
            return []
        }
    }

    private func suggestionScore(
        for suggestion: String,
        token: ScaffoldToken,
        theme: LexicalTheme?,
        runtimeVocabulary: SentenceContextVocabulary
    ) -> Int {
        let key = suggestion.lowercased()
        var score = runtimeVocabulary.priority[key, default: 0]
        if theme?.anchors.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame }) == true
            || theme?.senses.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame }) == true
            || theme?.verbs.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame }) == true {
            score += 20
        }
        if token.role == .misty, alternatives(for: token.word).contains(where: { $0 == key }) {
            score += 30
        }
        return score
    }

    private func grammaticallyFits(_ suggestion: String, replacing token: ScaffoldToken) -> Bool {
        let current = token.word.lowercased()
        let candidate = suggestion.lowercased()
        guard token.role == .motion else { return true }
        if current.hasSuffix("ing") { return candidate.hasSuffix("ing") }
        if current.hasSuffix("ed") { return candidate.hasSuffix("ed") || Self.irregularPastVerbs.contains(candidate) }
        if current.hasSuffix("s"), !current.hasSuffix("ss") { return candidate.hasSuffix("s") }
        return true
    }

    private static let irregularPastVerbs: Set<String> = [
        "caught", "held", "kept", "left", "made", "sat", "stood", "took", "went", "wore"
    ]

    func contextNote(for token: ScaffoldToken) -> String? {
        let vocabulary = contextVocabulary()
        let hasRelevantWords: Bool
        switch token.role {
        case .thing: hasRelevantWords = !vocabulary.anchors.isEmpty
        case .sense, .misty, .smoke: hasRelevantWords = !vocabulary.senses.isEmpty
        case .motion: hasRelevantWords = !vocabulary.verbs.isEmpty
        case .crossing, .plain: hasRelevantWords = false
        }
        return hasRelevantWords ? "First choices come from this page and its nearby context." : nil
    }

    private func contextEchoes(in sentenceWords: [String]) -> Bool {
        let clueWords = Set(words(in: [context.prompt, context.sourceText].joined(separator: " ")))
            .subtracting(Self.contextStopWords)
        return !clueWords.isDisjoint(with: Set(sentenceWords))
    }

    private func containsLikelyVerb(in text: String) -> Bool {
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var found = false
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, _ in
            if tag == .verb { found = true }
            return !found
        }
        return found
        #else
        return words(in: text).contains { $0.hasSuffix("ed") || $0.hasSuffix("ing") }
        #endif
    }

    private func contextVocabulary() -> SentenceContextVocabulary {
        guard context.hasRuntimeClues else { return SentenceContextVocabulary() }
        var vocabulary = SentenceContextVocabulary()
        let sources: [(String, Int)] = [
            (String(context.prompt.prefix(800)), 60),
            (String(context.sourceText.prefix(1_200)), 45),
            (context.weather ?? "", 40),
            (context.tags.joined(separator: " "), 35),
            (context.personalWords.joined(separator: " "), 32),
            (context.timeOfDay ?? "", 25)
        ] + context.recentMotifs.prefix(6).map { (String($0.prefix(320)), 20) }

        for (text, weight) in sources where !text.isEmpty {
            extractContextWords(from: text, weight: weight, into: &vocabulary)
        }
        vocabulary.anchors = vocabulary.anchors.uniquedPreservingOrder()
        vocabulary.senses = vocabulary.senses.uniquedPreservingOrder()
        vocabulary.verbs = vocabulary.verbs.uniquedPreservingOrder()
        return vocabulary
    }

    private func extractContextWords(
        from text: String,
        weight: Int,
        into vocabulary: inout SentenceContextVocabulary
    ) {
        let recipientWords = Set(context.recipientName.map { words(in: $0) } ?? [])

        func accept(_ surface: String, as role: SentenceRole) {
            let key = surface.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.count >= 2,
                  key.count <= 28,
                  !Self.contextStopWords.contains(key),
                  !recipientWords.contains(key),
                  key.rangeOfCharacter(from: .letters) != nil else { return }
            vocabulary.priority[key] = max(vocabulary.priority[key, default: 0], weight)
            switch role {
            case .thing: vocabulary.anchors.append(key)
            case .sense: vocabulary.senses.append(key)
            case .motion: vocabulary.verbs.append(key)
            default: break
            }
        }

        // Known pack vocabulary keeps its authored role even if the system
        // tagger reads an enchanted use differently.
        let tokenSet = Set(words(in: text))
        for word in pack.concreteWords where tokenSet.contains(word.lowercased()) { accept(word, as: .thing) }
        for word in pack.sensoryWords where tokenSet.contains(word.lowercased()) { accept(word, as: .sense) }
        for word in pack.animateVerbs where tokenSet.contains(word.lowercased()) { accept(word, as: .motion) }

        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, range in
            let surface = String(text[range]).lowercased()
            switch tag {
            case .noun: accept(surface, as: .thing)
            case .adjective: accept(surface, as: .sense)
            case .verb: accept(surface, as: .motion)
            default: break
            }
            return true
        }
        #endif
    }

    private static let contextStopWords: Set<String> = [
        "a", "about", "add", "an", "and", "answer", "anything", "are", "as", "ask", "back", "be", "book",
        "bring", "can", "catch", "choose", "come", "could", "day", "describe", "detail", "did", "do", "does",
        "feeling", "find", "first", "for", "from", "give", "had", "has", "have", "help", "here", "how", "i",
        "if", "in", "into", "is", "it", "keep", "last", "let", "line", "make", "may", "me", "moment", "name",
        "note", "of", "on", "one", "or", "page", "part", "prompt", "question", "reader", "remember", "reply", "say",
        "sentence", "small", "something", "that", "the", "their", "them", "then", "thing", "this", "to", "true",
        "use", "was", "we", "what", "when", "where", "which", "who", "why", "will", "with", "word", "write", "you", "your"
    ]

    /// Keeps the strongest page/theme matches visible while filling the remaining
    /// chip slots with words the reader has not just seen or chosen. Once the pool
    /// is exhausted, older words naturally become available again.
    private func rotatingMoves(
        _ candidates: [SentenceMove],
        pinnedKeys: [String],
        avoiding: Set<String>,
        limit: Int,
        pinnedLimit: Int = 2
    ) -> [SentenceMove] {
        guard limit > 0 else { return [] }
        let candidateByKey = Dictionary(
            candidates.map { ($0.word.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var seenPins = Set<String>()
        let pins = pinnedKeys
            .compactMap { candidateByKey[$0.lowercased()] }
            .filter { seenPins.insert($0.word.lowercased()).inserted }
            .prefix(min(pinnedLimit, limit))
        let pinnedSet = Set(pins.map { $0.word.lowercased() })
        let avoided = Set(avoiding.map { $0.lowercased() })
        let remaining = candidates.filter { !pinnedSet.contains($0.word.lowercased()) }
        let fresh = remaining.filter { !avoided.contains($0.word.lowercased()) }
        let seen = remaining.filter { avoided.contains($0.word.lowercased()) }
        return Array(pins) + Array((fresh + seen).prefix(max(0, limit - pins.count)))
    }

    private func rotatingWords(
        _ candidates: [String],
        pinnedKeys: [String],
        avoiding: Set<String>,
        limit: Int,
        pinnedLimit: Int = 2
    ) -> [String] {
        guard limit > 0 else { return [] }
        let candidateByKey = Dictionary(
            candidates.map { ($0.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let pins = pinnedKeys
            .compactMap { candidateByKey[$0.lowercased()] }
            .uniquedPreservingOrder()
            .prefix(min(pinnedLimit, limit))
        let pinnedSet = Set(pins.map { $0.lowercased() })
        let avoided = Set(avoiding.map { $0.lowercased() })
        let remaining = candidates.filter { !pinnedSet.contains($0.lowercased()) }
        let fresh = remaining.filter { !avoided.contains($0.lowercased()) }
        let seen = remaining.filter { avoided.contains($0.lowercased()) }
        return Array(pins) + Array((fresh + seen).prefix(max(0, limit - pins.count)))
    }

    private func interleavedSenseMoves(
        _ senses: [SentenceMove],
        crossings: [SentenceMove],
        pageSize: Int
    ) -> [SentenceMove] {
        guard !crossings.isEmpty, pageSize > 1 else { return senses + crossings }
        let crossingChunk = min(2, max(1, pageSize / 4))
        let senseChunk = max(1, pageSize - crossingChunk)
        var mixed: [SentenceMove] = []
        var senseIndex = 0
        var crossingIndex = 0
        while senseIndex < senses.count || crossingIndex < crossings.count {
            let nextSenseIndex = min(senses.count, senseIndex + senseChunk)
            mixed.append(contentsOf: senses[senseIndex..<nextSenseIndex])
            senseIndex = nextSenseIndex
            let nextCrossingIndex = min(crossings.count, crossingIndex + crossingChunk)
            mixed.append(contentsOf: crossings[crossingIndex..<nextCrossingIndex])
            crossingIndex = nextCrossingIndex
        }
        return mixed
    }

    private func uniqueStarterOptions(_ options: [String], limit: Int) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for option in options {
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            guard !trimmed.isEmpty, seen.insert(key).inserted else { continue }
            out.append(trimmed)
            if out.count >= limit { break }
        }
        return out
    }

    private func fallbackOption(for kind: SentenceStarterSlotKind) -> String {
        let activePack = resolvedPack
        switch kind {
        case .anchor:
            return activePack.concreteWords.first ?? "the room"
        case .sense:
            return activePack.sensoryWords.first ?? "soft"
        case .motion:
            return activePack.animateVerbs.first ?? "waited"
        case .crossing:
            return activePack.crossingWords.first ?? "paper quiet"
        }
    }

    private func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(seed.stableHash.magnitude % UInt(count))
    }
}
