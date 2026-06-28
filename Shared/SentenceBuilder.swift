import Foundation

enum SentenceBuilderStepKind: String, Codable, Equatable, CaseIterable {
    case anchor
    case sense
    case motion
    case crossing
    case cutMist
    case groundGlow
}

struct SentenceBuilderStep: Identifiable, Codable, Equatable {
    var id: String
    var kind: SentenceBuilderStepKind
    var title: String
    var question: String
    var helper: String
    var chips: [String]
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
    var steps: [SentenceBuilderStep] = []
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
        steps: [
            SentenceBuilderStep(
                id: "anchor",
                kind: .anchor,
                title: "Find the object",
                question: "What real thing remembers this best?",
                helper: "Name one object, place, body detail, or bit of weather. One noun is enough.",
                chips: ["glass", "door", "chair", "rain", "hands", "window", "floor", "coat"]
            ),
            SentenceBuilderStep(
                id: "sense",
                kind: .sense,
                title: "Give it a sense",
                question: "What did your body notice?",
                helper: "Add a smell, sound, texture, temperature, taste, or quality of light.",
                chips: ["cold", "warm", "tinny", "wet", "dusty", "sharp", "dim", "green"]
            ),
            SentenceBuilderStep(
                id: "motion",
                kind: .motion,
                title: "Let it move",
                question: "What verb makes the real thing feel alive?",
                helper: "Let one nonhuman thing act without turning it fake.",
                chips: ["waited", "leaned", "clicked", "held", "refused", "counted", "listened", "worried"]
            ),
            SentenceBuilderStep(
                id: "crossing",
                kind: .crossing,
                title: "Cross the wires",
                question: "If one sense borrowed from another, what would it become?",
                helper: "A sound can have a color. A mood can have a texture. Keep it small.",
                chips: ["blue sound", "paper quiet", "tin taste", "wool tired", "yellow light", "cold green"]
            )
        ],
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
        steps: [
            SentenceBuilderStep(
                id: "souvenir-anchor",
                kind: .anchor,
                title: "Choose the witness",
                question: "What small thing came back with the moment?",
                helper: "Pick the object, mark, smell, or scrap that could prove the memory happened.",
                chips: ["receipt", "key", "cloud", "handle", "mirror", "napkin", "curb", "pocket"]
            ),
            SentenceBuilderStep(
                id: "souvenir-sense",
                kind: .sense,
                title: "Press the sense",
                question: "What did it feel like before your mind named it?",
                helper: "Let the body answer before the explanation arrives.",
                chips: ["creased", "damp", "faded", "silver", "stale", "smoky"]
            ),
            SentenceBuilderStep(
                id: "souvenir-motion",
                kind: .motion,
                title: "Let it keep",
                question: "What did the thing seem to do with the memory?",
                helper: "A souvenir does not need to speak. It can tug, stay, follow, or hold.",
                chips: ["kept", "stayed", "followed", "pulled", "tugged"]
            )
        ],
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
            steps: mergedSteps(with: overlay.steps),
            starterTemplates: mergedStarterTemplates(with: overlay.starterTemplates),
            version: max(version, overlay.version),
            author: overlay.author.isEmpty ? author : overlay.author,
            availability: availability
        )
    }

    private func mergedSteps(with overlaySteps: [SentenceBuilderStep]) -> [SentenceBuilderStep] {
        var merged = steps
        for step in overlaySteps {
            if let index = merged.firstIndex(where: { $0.kind == step.kind }) {
                merged[index] = step
            } else {
                merged.append(step)
            }
        }
        return merged
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
        case crossingWords, themes, steps, starterTemplates, version, author, availability
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
        steps = try c.decodeIfPresent([SentenceBuilderStep].self, forKey: .steps) ?? []
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
    /// decay, and the worn edge. Not an entitlement-gated expansion; it is composed
    /// in-world only while `ShadowWonder` is active (after dark, when Duskthorn is
    /// ascendant, on hard/grey days, or in somber weather), so a normal run never
    /// turns goblin-core by accident. It also seeds the Shadow Sentence Runner's
    /// catchable words via `ShadowWonder.gameWords`.
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

    static func composedCore(readerLexicon: ReaderLexicon) -> SentenceBuilderPack {
        composed(onto: .core, readerLexicon: readerLexicon)
    }

    static func composedSouvenir() -> SentenceBuilderPack {
        if let hit = cache["souvenir"] { return hit }
        let pack = composed(onto: .core.merged(with: .souvenir))
        cache["souvenir"] = pack
        return pack
    }

    static func composedSouvenir(readerLexicon: ReaderLexicon) -> SentenceBuilderPack {
        composed(onto: .core.merged(with: .souvenir), readerLexicon: readerLexicon)
    }

    static func reload() { cache.removeAll() }
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
        updated[index].word = cleaned
        updated[index].role = SentenceScaffold.role(for: cleaned, using: pack)
        return SentenceScaffold(tokens: updated)
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

struct SentenceBuilderNudge: Equatable {
    var step: SentenceBuilderStep
    var highlightedWord: String?
    var canStandAsComplete: Bool
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
    var hasCrossedSense: Bool
    var memoryStrength: Int
    var craftMarks: [SentenceBuilderCraftMark]
    var diagnostics: [SentenceBuilderDiagnostic]

    var canStandAsComplete: Bool {
        wordCount >= 4 && (hasConcreteAnchor || hasSensoryDetail || hasLivingMotion)
    }

    var isVivid: Bool {
        memoryStrength >= 3
    }
}

struct SentenceBuilderAlchemyLevel: Identifiable, Equatable {
    var id: String
    var title: String
    var example: String
    var isCurrent: Bool
}

struct SentenceBuilderEngine {
    var pack: SentenceBuilderPack

    init(pack: SentenceBuilderPack = .core) {
        self.pack = pack
    }

    func nudge(for text: String, completedKinds: Set<SentenceBuilderStepKind> = []) -> SentenceBuilderNudge {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = analyze(trimmed)
        if let avoidWord = hasAvoidWord(trimmed),
           !completedKinds.contains(.groundGlow) {
            return SentenceBuilderNudge(
                step: glowStep(for: avoidWord),
                highlightedWord: avoidWord,
                canStandAsComplete: analysis.canStandAsComplete
            )
        }

        if let vagueWord = firstMatchedWord(in: trimmed, words: pack.vagueWords),
           !completedKinds.contains(.cutMist) {
            return SentenceBuilderNudge(
                step: mistStep(for: vagueWord),
                highlightedWord: vagueWord,
                canStandAsComplete: analysis.canStandAsComplete
            )
        }

        let orderedKinds: [SentenceBuilderStepKind] = [.anchor, .sense, .motion, .crossing]
        let nextKind = orderedKinds.first { kind in
            guard !completedKinds.contains(kind) else { return false }
            switch kind {
            case .anchor:
                return !analysis.hasConcreteAnchor
            case .sense:
                return !analysis.hasSensoryDetail
            case .motion:
                return !analysis.hasLivingMotion
            case .crossing:
                return analysis.memoryStrength >= 2 && !analysis.hasCrossedSense
            case .cutMist, .groundGlow:
                return false
            }
        } ?? orderedKinds.first { !completedKinds.contains($0) } ?? .anchor
        let step = pack.steps.first { $0.kind == nextKind } ?? pack.steps[0]
        return SentenceBuilderNudge(
            step: step,
            highlightedWord: nil,
            canStandAsComplete: analysis.canStandAsComplete
        )
    }

    func analyze(_ text: String) -> SentenceBuilderAnalysis {
        let normalizedWords = words(in: text)
        let wordCount = normalizedWords.count
        let wordSet = Set(normalizedWords)
        let lower = text.lowercased()

        let hasConcreteAnchor = containsAnyWord(from: pack.concreteWords, in: wordSet)
        let hasSensoryDetail = containsAnyWord(from: pack.sensoryWords, in: wordSet)
        let hasLivingMotion = containsAnyWord(from: pack.animateVerbs, in: wordSet)
        let hasCrossedSense = pack.crossingWords.contains { lower.contains($0.lowercased()) }
            || (hasSensoryDetail && lower.contains(" sound"))
            || (hasSensoryDetail && lower.contains(" taste"))
            || (hasSensoryDetail && lower.contains(" quiet"))

        let marks = [
            SentenceBuilderCraftMark(
                id: .anchor,
                title: "Thing",
                isPresent: hasConcreteAnchor,
                hint: "Name the object, place, body part, or weather."
            ),
            SentenceBuilderCraftMark(
                id: .sense,
                title: "Body",
                isPresent: hasSensoryDetail,
                hint: "Add temperature, texture, color, taste, sound, or smell."
            ),
            SentenceBuilderCraftMark(
                id: .motion,
                title: "Will",
                isPresent: hasLivingMotion,
                hint: "Let a nonhuman thing act with a plain verb."
            ),
            SentenceBuilderCraftMark(
                id: .crossing,
                title: "Cross",
                isPresent: hasCrossedSense,
                hint: "Let one sense borrow from another."
            )
        ]
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
        if wordCount >= 5 && !hasConcreteAnchor {
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
            hasCrossedSense: hasCrossedSense,
            memoryStrength: memoryStrength,
            craftMarks: marks,
            diagnostics: diagnostics
        )
    }

    /// Parse the user's current text into a grammar-safe scaffold of tagged tokens.
    func scaffold(for text: String) -> SentenceScaffold {
        SentenceScaffold.tag(text, using: pack)
    }

    /// The dominant context theme of a sentence: whichever pack theme has the most
    /// of its anchor nouns present. Drives context-aware chip ordering.
    func dominantTheme(in scaffold: SentenceScaffold) -> LexicalTheme? {
        guard !pack.themes.isEmpty else { return nil }
        let present = Set(scaffold.tokens.map { $0.word.lowercased() })
        var best: (theme: LexicalTheme, score: Int)?
        for theme in pack.themes {
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
    func moves(for token: ScaffoldToken, in scaffold: SentenceScaffold, limit: Int = 8) -> [SentenceMove] {
        let current = token.word.lowercased()
        let alreadyUsed = Set(scaffold.tokens.map { $0.word.lowercased() }).subtracting([current])
        let theme = dominantTheme(in: scaffold)

        // Theme words first (context), then the global pool — deduped, current and
        // already-present words removed, capped at `limit`.
        func compose(themed: [String], global: [String], group: String) -> [SentenceMove] {
            var seen = Set<String>()
            var out: [SentenceMove] = []
            for word in themed + global {
                let key = word.lowercased()
                guard key != current, !alreadyUsed.contains(key), seen.insert(key).inserted else { continue }
                out.append(SentenceMove(id: "\(group)-\(key)", label: word, word: word, group: group))
                if out.count >= limit { break }
            }
            return out
        }

        switch token.role {
        case .misty:
            return compose(themed: alternatives(for: token.word), global: theme?.senses ?? [], group: "ground")
        case .smoke:
            // Stage-smoke words become a plain physical quality the room can carry.
            return compose(themed: alternatives(for: token.word), global: (theme?.senses ?? []) + pack.sensoryWords, group: "ground")
        case .thing:
            return compose(themed: theme?.anchors ?? [], global: pack.concreteWords, group: "thing")
        case .sense:
            // Sharper senses (theme-biased), then always reserve room for a crossed-sense leap.
            let crossPool = (theme?.crossings ?? []) + pack.crossingWords
            let crossings = crossPool
                .filter { $0.lowercased() != current }
                .prefix(2)
                .map { SentenceMove(id: "cross-\($0.lowercased())", label: $0, word: $0, group: "cross") }
            let senseRoom = max(1, limit - crossings.count)
            let senses = Array(compose(themed: theme?.senses ?? [], global: pack.sensoryWords, group: "sense").prefix(senseRoom))
            return senses + crossings
        case .motion:
            return compose(themed: theme?.verbs ?? [], global: pack.animateVerbs, group: "motion")
        case .crossing:
            return compose(themed: theme?.crossings ?? [], global: pack.crossingWords, group: "cross")
        case .plain:
            return []
        }
    }

    func chips(for step: SentenceBuilderStep, text: String) -> [String] {
        let lower = text.lowercased()
        let unused = step.chips.filter { !lower.contains($0.lowercased()) }
        return unused.isEmpty ? step.chips : unused
    }

    func starterDraft(seed: String = "default") -> SentenceStarterDraft? {
        guard !pack.starterTemplates.isEmpty else { return nil }
        let template = pack.starterTemplates[stableIndex(for: seed, count: pack.starterTemplates.count)]
        var selections: [String: String] = [:]
        for slot in template.slots {
            selections[slot.id] = options(for: slot, in: SentenceStarterDraft(template: template, selections: selections), limit: 1).first
                ?? fallbackOption(for: slot.kind)
        }
        return SentenceStarterDraft(template: template, selections: selections)
    }

    func options(for slot: SentenceStarterSlot, in draft: SentenceStarterDraft, limit: Int = 8) -> [String] {
        let theme = starterTheme(for: draft)
        let themed: [String]
        let global: [String]
        switch slot.kind {
        case .anchor:
            themed = theme?.anchors ?? []
            global = pack.concreteWords
        case .sense:
            themed = theme?.senses ?? []
            global = pack.sensoryWords
        case .motion:
            themed = theme?.verbs ?? []
            global = pack.animateVerbs
        case .crossing:
            themed = theme?.crossings ?? []
            global = pack.crossingWords
        }
        return uniqueStarterOptions(slot.options + themed + global, limit: limit)
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

    func alchemyLevels(for text: String) -> [SentenceBuilderAlchemyLevel] {
        let analysis = analyze(text)
        return [
            SentenceBuilderAlchemyLevel(
                id: "label",
                title: "Label",
                example: "Dinner was good.",
                isCurrent: !analysis.hasConcreteAnchor && !analysis.hasSensoryDetail && !analysis.hasLivingMotion
            ),
            SentenceBuilderAlchemyLevel(
                id: "hook",
                title: "Hook",
                example: "The garlic hit the oil and made the kitchen warm.",
                isCurrent: analysis.canStandAsComplete && !analysis.isVivid
            ),
            SentenceBuilderAlchemyLevel(
                id: "spell",
                title: "Tiny spell",
                example: "The garlic woke up in the pan and the kitchen turned gold.",
                isCurrent: analysis.isVivid
            )
        ]
    }

    func souvenirShareText(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "\(trimmed)\n\n— One-Sentence Souvenir"
    }

    func phrase(for chip: String, step: SentenceBuilderStep) -> String {
        switch step.kind {
        case .anchor:
            return chip
        case .sense:
            return chip
        case .motion:
            return chip
        case .crossing:
            return chip
        case .cutMist:
            return chip
        case .groundGlow:
            return chip
        }
    }

    func append(_ phrase: String, to text: String) -> String {
        let cleanPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPhrase.isEmpty else { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cleanPhrase }

        if trimmed.hasSuffix(" ") || trimmed.hasSuffix("\n") {
            return text + cleanPhrase
        }
        if trimmed.hasSuffix(",") || trimmed.hasSuffix(";") || trimmed.hasSuffix(":") {
            return text + " " + cleanPhrase
        }
        return text + " " + cleanPhrase
    }

    func hasAvoidWord(_ text: String) -> String? {
        firstMatchedWord(in: text, words: pack.avoidWords)
    }

    private func mistStep(for word: String) -> SentenceBuilderStep {
        SentenceBuilderStep(
            id: "cut-mist-\(word)",
            kind: .cutMist,
            title: "Cut the mist",
            question: "Can '\(word)' become a texture, temperature, object, or gesture?",
            helper: "Keep the feeling, but give it a body.",
            chips: alternatives(for: word)
        )
    }

    private func glowStep(for word: String) -> SentenceBuilderStep {
        SentenceBuilderStep(
            id: "ground-glow-\(word)",
            kind: .groundGlow,
            title: "Ground the glow",
            question: "What ordinary thing could carry '\(word)' without saying it?",
            helper: "Let the magic arrive through matter: light on a wall, a cup, a hinge, a smell, a pressure in the hand.",
            chips: ["lamp", "hinge", "smell", "shadow", "pulse", "dust", "weight", "ring"]
        )
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

    private func starterTheme(for draft: SentenceStarterDraft) -> LexicalTheme? {
        let selected = Set(draft.selections.values.flatMap { words(in: $0) })
        var best: (theme: LexicalTheme, score: Int)?
        for theme in pack.themes {
            let score = theme.anchors.reduce(0) { $0 + (selected.contains($1.lowercased()) ? 1 : 0) }
            if score > 0, score > (best?.score ?? 0) {
                best = (theme, score)
            }
        }
        return best?.theme
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
        switch kind {
        case .anchor:
            return pack.concreteWords.first ?? "the room"
        case .sense:
            return pack.sensoryWords.first ?? "soft"
        case .motion:
            return pack.animateVerbs.first ?? "waited"
        case .crossing:
            return pack.crossingWords.first ?? "paper quiet"
        }
    }

    private func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(seed.stableHash.magnitude % UInt(count))
    }
}
