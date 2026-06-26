import Foundation


struct ReferenceSnippet: Codable, Identifiable, Equatable {
    var id: String
    var sourceID: String
    var title: String
    var prompt: String
    var body: String
    var tags: [String]
    /// An invitation the Book hands the reader — a small thing to try, notice,
    /// or answer in the real world. Optional so older bundles still decode.
    var practice: String? = nil
    var url: String? = nil
    var publishedAt: String? = nil
    var preview: String? = nil
}

struct LabyrinthIllustrationPlate: Identifiable, Equatable {
    var id: String
    var assetName: String
    var title: String
    var caption: String
    var note: String
    var tags: [String]
    var characterID: String? = nil
}

struct CharacterIllustrationProfile: Identifiable, Codable, Equatable {
    var id: String
    var characterName: String
    var slug: String
    var status: String
    var chapter: String?
    var core: String
    var signature: String
    var palette: String
    var silhouette: String
    var continuity: String
    var avoid: String
    var assetName: String?
    var intendedAssetName: String
    var prompt: String
    var negativePrompt: String
    var marginalia: [String]
    var tags: [String]

    var hasBundledAsset: Bool {
        assetName?.isEmpty == false
    }

    var illustrationDossierKind: String {
        if tags.contains("location") || status == "location" { return "Location dossier" }
        if tags.contains("book-fae") || status == "book-fae" { return "Book Fae dossier" }
        return "Character dossier"
    }

    var illustrationTag: String {
        if tags.contains("location") || status == "location" { return "location" }
        if tags.contains("book-fae") || status == "book-fae" { return "book-fae" }
        return "character"
    }
}

enum QuipPackAvailability: String, Codable, Equatable {
    case bundledFree
    case patron
    case paid
    case userImported
    case locked
}

struct QuipPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: QuipPackAvailability
    var quips: [QuipEntry]
}

struct QuipEntry: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var title: String
    var tags: [String]
    var packID: String
    var weight: Int
}

enum SelfFactSensitivity: String, Codable, Equatable, CaseIterable {
    case identity
    case comfort
    case delight
    case values
    case story
}

enum SelfFactUsePermission: String, Codable, Equatable, CaseIterable {
    case privateContext
    case quoteAllowed
    case storyOnly
    case doNotUse
}

struct SelfFact: Identifiable, Codable, Equatable {
    var id: String
    var questionID: String
    var question: String
    var answer: String
    var bookTranslation: String
    var sensitivity: SelfFactSensitivity
    var usePermission: SelfFactUsePermission
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
}

struct AboutYouQuestion: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var prompt: String
    var detail: String
    var placeholder: String
    var sensitivity: SelfFactSensitivity
    var defaultUsePermission: SelfFactUsePermission
    var tags: [String]
    var priority: Int
}

struct SelfKnowledgePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: ContentPackAvailability
    var questions: [AboutYouQuestion]
}

enum SelfKnowledgePackRegistry {
    static let corePackID = "core-self-knowledge"
    static let maxAboutYouFactsPerDay = 3
    static let minimumHoursBetweenAboutYouFacts = 3
    static let maxInterestFacts = 7

    static let bundledPacks: [SelfKnowledgePack] = [
        SelfKnowledgePack(
            id: corePackID,
            displayName: "Core Self-Knowledge Pack",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            questions: coreQuestions
        )
    ]

    static var enabledPacks: [SelfKnowledgePack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var questions: [AboutYouQuestion] {
        enabledPacks.flatMap(\.questions)
    }

    static func question(id: String) -> AboutYouQuestion? {
        questions.first { $0.id == id }
    }

    static func packName(for packID: String) -> String {
        enabledPacks.first { $0.id == packID }?.displayName ?? "the shelf"
    }

    static func nextQuestion(knownFacts: [SelfFact], day: BookDay, now: Date) -> AboutYouQuestion? {
        let answered = Set(knownFacts.map(\.questionID))
        let answeredInterestCount = knownFacts.filter { $0.questionID.hasPrefix("interest-") }.count
        let available = questions.filter { question in
            if question.id.hasPrefix("interest-") {
                guard answeredInterestCount < maxInterestFacts else { return false }
                if question.id == "interest-01" {
                    return !answered.contains(question.id)
                }
                let expectedID = String(format: "interest-%02d", answeredInterestCount + 1)
                return question.id == expectedID && !answered.contains(question.id)
            }
            return !answered.contains(question.id)
        }
        guard !available.isEmpty else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        let seed = abs("\(day.id)-about-you-\(slot)".stableHash)
        return available.sorted { left, right in
            let leftScore = left.priority * 1000 + abs((seed ^ left.id.stableHash ^ left.packID.stableHash) % 997)
            let rightScore = right.priority * 1000 + abs((seed ^ right.id.stableHash ^ right.packID.stableHash) % 997)
            return leftScore > rightScore
        }.first
    }

    static func translation(for question: AboutYouQuestion, answer: String) -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch question.sensitivity {
        case .identity:
            return "The Book may call you \(trimmed) when the page needs to remember who is holding it."
        case .comfort:
            return "The Book will treat this as a signal for comfort, shelter, and the shape of gentleness."
        case .delight:
            if question.tags.contains("interest") {
                return "The Book will keep this interest near the desk, ready to tint scenes, quips, and invitations."
            }
            return "The Book will let this tint future pages when wonder needs a familiar spark."
        case .values:
            return "The Book will give this belief weight when Story Pages choose what matters."
        case .story:
            return "The Book will carry this as story-shape, not a box: a pattern to notice, not a verdict."
        }
    }

    private static let coreQuestions: [AboutYouQuestion] = [
        question("home-place", "Where do you call home?", "A place can be true without being precise.", "A town, coast, room, region, or kind of place.", .comfort, .privateContext, ["home", "place"], 88),
        question("home-meaning", "What does home mean to you?", "Not the address. The feeling the Book should recognize.", "Safety, noise, chosen people, a porch light...", .comfort, .storyOnly, ["home", "meaning"], 84),
        question("favorite-color", "What color keeps finding you?", "The Book can tint future pages with a little more you in them.", "Blue, moss green, marigold, storm gray...", .delight, .privateContext, ["color", "delight"], 78),
        question("interest-01", "What's an interest of yours?", "The Book wants to know what lights your shelves from the inside.", "Sailing, cooking, weird history, cozy games, old maps...", .delight, .privateContext, ["interest", "delight", "story-seed"], 77),
        question("interest-02", "What's another interest of yours?", "Interests make excellent doors. The Book is collecting keys slowly.", "A hobby, subject, fandom, craft, place, creature, question...", .delight, .privateContext, ["interest", "delight", "story-seed"], 65),
        question("interest-03", "What's another interest of yours?", "A second shelf has opened. Put one bright thing on it.", "Something you read about, make, watch, collect, or chase...", .delight, .privateContext, ["interest", "delight", "story-seed"], 64),
        question("interest-04", "What's another interest of yours?", "The Book is learning what kinds of doors you notice first.", "A world, practice, problem, texture, tool, era, mystery...", .delight, .privateContext, ["interest", "delight", "story-seed"], 63),
        question("interest-05", "What's another interest of yours?", "Some interests are lanterns. Some are secret staircases.", "Tiny, grand, serious, silly. All of them count.", .delight, .privateContext, ["interest", "delight", "story-seed"], 62),
        question("interest-06", "What's another interest of yours?", "The Book is nearly done stocking this shelf for now.", "A thing you could talk about for ten minutes too long...", .delight, .privateContext, ["interest", "delight", "story-seed"], 61),
        question("interest-07", "What's one last interest for this shelf?", "Seven is plenty. The Book can make a map from here.", "One more spark the Story Pages should know about.", .delight, .privateContext, ["interest", "delight", "story-seed"], 60),
        question("small-delight", "What small thing reliably delights you?", "A tiny delight is a strong lantern.", "A food, sound, texture, joke, place, creature...", .delight, .privateContext, ["delight", "wonder"], 76),
        question("rest-shape", "What does real rest look like for you?", "The Book should learn the difference between rest and merely stopping.", "Quiet, movement, sleep, music, being left alone...", .comfort, .privateContext, ["rest", "care"], 72),
        question("belief", "What do you believe in, even on tired days?", "One sturdy sentence for the shelf.", "Kindness, curiosity, making things, second chances...", .values, .storyOnly, ["values", "belief"], 68),
        question("protect", "What do you protect?", "The Story Page will need to know what has weight.", "People, time, wonder, honesty, softness, the work...", .values, .storyOnly, ["values", "protection"], 62),
        question("becoming", "What kind of person are you trying to become?", "Not as homework. As a north star.", "Braver, gentler, more alive, less hidden...", .values, .storyOnly, ["growth", "values"], 58),
        question("story-role", "What role do you usually play in a group?", "Every story field has patterns. This one can learn yours gently.", "Guide, comic relief, caretaker, scout, skeptic...", .story, .storyOnly, ["story", "role"], 52)
    ]

    private static func question(
        _ id: String,
        _ prompt: String,
        _ detail: String,
        _ placeholder: String,
        _ sensitivity: SelfFactSensitivity,
        _ permission: SelfFactUsePermission,
        _ tags: [String],
        _ priority: Int
    ) -> AboutYouQuestion {
        AboutYouQuestion(
            id: id,
            packID: corePackID,
            prompt: prompt,
            detail: detail,
            placeholder: placeholder,
            sensitivity: sensitivity,
            defaultUsePermission: permission,
            tags: tags,
            priority: priority
        )
    }
}

struct BookReferenceLibraryPayload: Codable, Equatable {
    var version: Int
    var wonderCompass: [ReferenceSnippet]
    var enchantifyLore: [ReferenceSnippet]
    var patreon: [ReferenceSnippet]?
    var characterIllustrations: [CharacterIllustrationProfile]

    enum CodingKeys: String, CodingKey {
        case version
        case wonderCompass
        case enchantifyLore
        case patreon
        case characterIllustrations
    }

    init(
        version: Int,
        wonderCompass: [ReferenceSnippet],
        enchantifyLore: [ReferenceSnippet],
        patreon: [ReferenceSnippet]?,
        characterIllustrations: [CharacterIllustrationProfile] = []
    ) {
        self.version = version
        self.wonderCompass = wonderCompass
        self.enchantifyLore = enchantifyLore
        self.patreon = patreon
        self.characterIllustrations = characterIllustrations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        wonderCompass = try container.decode([ReferenceSnippet].self, forKey: .wonderCompass)
        enchantifyLore = try container.decode([ReferenceSnippet].self, forKey: .enchantifyLore)
        patreon = try container.decodeIfPresent([ReferenceSnippet].self, forKey: .patreon)
        characterIllustrations = try container.decodeIfPresent([CharacterIllustrationProfile].self, forKey: .characterIllustrations) ?? []
    }

    static let empty = BookReferenceLibraryPayload(version: 0, wonderCompass: [], enchantifyLore: [], patreon: [], characterIllustrations: [])
}

enum QuipPackRegistry {
    static let corePackID = "core-oddities"

    static let bundledPacks: [QuipPack] = [
        QuipPack(
            id: corePackID,
            displayName: "Core Oddities Pack",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            quips: coreQuips
        )
    ]

    static var enabledPacks: [QuipPack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static func quip(for day: BookDay, now: Date, tags: [String] = []) -> QuipEntry {
        let quips = enabledPacks.flatMap(\.quips)
        guard !quips.isEmpty else {
            return QuipEntry(id: "fallback", text: "The Book found a small bright thing and kept it.", title: "Filed Under Wonder", tags: ["wonder"], packID: corePackID, weight: 1)
        }
        let slot = SurfaceCadence.slotID(for: now, hours: 3)
        let seed = abs("\(day.id)-\(slot)-\(tags.joined(separator: ","))".stableHash)
        let tagSet = Set(tags.map { $0.lowercased() })
        let ranked = quips.enumerated().map { index, quip in
            let overlap = tagSet.intersection(Set(quip.tags.map { $0.lowercased() })).count
            let jitter = abs((seed &+ index * 1543).stableScramble % 1000)
            return (quip, overlap * 20 + quip.weight * 3 + jitter)
        }
        return ranked.sorted { $0.1 > $1.1 }.first?.0 ?? quips[seed % quips.count]
    }

    private static let coreQuips: [QuipEntry] = [
        quip("tree-squirrel", "Squirrels are the part of the tree that runs.", "Whimsical Observation", ["nature", "creature", "tree"]),
        quip("tiny-sun", "A candle is a tiny sun with manners.", "Small Light", ["light", "home", "night"]),
        quip("fog-forgetting", "Fog is the weather forgetting where it put things.", "Weather Oddity", ["weather", "fog"]),
        quip("sky-handwriting", "Rain is the sky practicing handwriting.", "Weather Oddity", ["weather", "rain", "ink"]),
        quip("forest-thought", "A mushroom is a thought the forest had overnight.", "Forest Note", ["nature", "forest", "fungus"]),
        quip("library-forest", "A library is a forest that learned alphabetical order.", "Bookish Oddity", ["book", "library", "forest"]),
        quip("bookmark-job", "A bookmark is a tiny pause with a job.", "Bookish Oddity", ["book", "reading"]),
        quip("liquid-ghost", "Ink is a liquid ghost.", "Ink Note", ["ink", "writing"]),
        quip("field-remember", "Paper is a field that agreed to remember.", "Paper Note", ["paper", "memory", "writing"]),
        quip("book-breathing", "Margins are where books breathe.", "Bookish Oddity", ["book", "margin"]),
        quip("tiny-midnight", "An inkwell is a tiny midnight.", "Ink Note", ["ink", "night"]),
        quip("borrow-lantern", "Reading is borrowing someone else's lantern.", "Reading Note", ["book", "light"]),
        quip("recipe-spell", "A recipe is a spell that ends in dishes.", "Kitchen Spell", ["home", "food", "magic"]),
        quip("keys-doors", "Keys are tiny arguments with doors.", "Object Note", ["home", "door"]),
        quip("teacup-thought", "A teacup is a bathtub for a thought.", "Tea Note", ["home", "tea"]),
        quip("seed-summer", "A seed is a locked room full of summer.", "Botanical Note", ["nature", "garden"]),
        quip("roots-writing", "Roots are trees writing underground.", "Botanical Note", ["nature", "tree"]),
        quip("year-editing", "Autumn is the year editing itself.", "Seasonal Note", ["weather", "season"]),
        quip("portable-courage", "A lantern is portable courage.", "Small Light", ["light", "night"]),
        quip("private-museum", "A pocket is a tiny private museum.", "Object Note", ["ordinary", "memory"]),
        quip("manicule", "A manicule is the little pointing hand drawn in old book margins. A tiny medieval cursor.", "Bookish Oddity", ["book", "margin", "history"], weight: 2),
        quip("palimpsest", "A palimpsest is a reused page where older writing still ghosts through. A haunted notebook.", "Bookish Oddity", ["book", "history", "ghost"], weight: 2),
        quip("fore-edge", "Some old books hide paintings on their page edges, visible only when fanned.", "Bookish Oddity", ["book", "art", "hidden"], weight: 2),
        quip("lapis-sky", "Some manuscripts used blue made from lapis lazuli, once more expensive than gold. Imagine budgeting for sky.", "Bookish Oddity", ["book", "color", "history"], weight: 2),
        quip("book-leaf", "A leaf has two pages. A page has one face. Books are secretly botanical.", "Bookish Oddity", ["book", "botanical"], weight: 2),
        quip("serif-feet", "Serifs are tiny feet on letters. Sans serif letters go barefoot.", "Type Note", ["book", "letter", "type"]),
        quip("old-book-smell", "The smell of old books often comes from lignin breaking down. Time has a vanilla-adjacent perfume.", "Bookish Oddity", ["book", "smell", "time"], weight: 2),
        quip("petrichor", "Rain does not just fall. It wakes the smell of the earth.", "Science Oddity", ["weather", "rain", "earth"], weight: 2),
        quip("sea-stars", "Bioluminescence is the sea inventing stars under pressure.", "Science Oddity", ["sea", "light", "science"], weight: 2),
        quip("stardust", "You are not metaphorically stardust. You are chemically, literally stardust.", "Science Oddity", ["space", "body", "science"], weight: 2),
        quip("glacier-blue", "A glacier is time moving slowly enough to become a landscape.", "Science Oddity", ["ice", "time", "weather"]),
        quip("fungus-apple", "The visible mushroom is the apple. The forest underground is the tree.", "Science Oddity", ["forest", "fungus", "nature"]),
        quip("pearl-wound", "A pearl is a wound that learned polish.", "Science Oddity", ["sea", "shell"]),
        quip("octopus-curiosity", "An octopus is what happens when curiosity gets eight hands.", "Science Oddity", ["sea", "creature"]),
        quip("whale-cathedral", "A whale song is a cathedral built out of breath.", "Science Oddity", ["sea", "creature", "sound"]),
        quip("bird-map", "A bird migration is a map written inside a body.", "Science Oddity", ["sky", "bird", "map"]),
        quip("bee-cartography", "A bee dance is cartography with an abdomen.", "Science Oddity", ["bee", "map", "creature"]),
        quip("spider-poem", "A spiderweb is a trap, a house, and a poem under tension.", "Science Oddity", ["web", "creature"]),
        quip("rust-memory", "Rust is iron remembering it used to be in the ground.", "Whimsical Observation", ["ordinary", "earth"]),
        quip("road-question", "A road is a question the town keeps asking the horizon.", "Whimsical Observation", ["place", "walk"]),
        quip("roots-walk", "Roots are the tree refusing to admit it can't walk.", "Whimsical Observation", ["tree", "nature"]),
        quip("library-quiet", "A library is the only building designed to be quieter than the people inside it.", "Bookish Oddity", ["book", "library"]),
        quip("book-breath", "An unread book is the most patient object in any house.", "Bookish Oddity", ["book", "home"]),
        quip("photo-key", "A photograph doesn't hold the memory. You do. The photo is just where you left the key.", "Memory Note", ["memory", "photo"]),
        quip("novelty-save", "Novelty is just the save button.", "Memory Note", ["memory", "attention"])
    ]

    private static func quip(_ id: String, _ text: String, _ title: String, _ tags: [String], weight: Int = 1) -> QuipEntry {
        QuipEntry(id: id, text: text, title: title, tags: tags, packID: corePackID, weight: weight)
    }
}

enum BookReferenceCatalog {
    static var wonderCompass: [ReferenceSnippet] {
        bundledLibrary.wonderCompass.isEmpty ? fallbackWonderCompass : bundledLibrary.wonderCompass
    }

    static var enchantifyLore: [ReferenceSnippet] {
        LorePackRegistry.snippets(
            coreSnippets: bundledLibrary.enchantifyLore.isEmpty ? fallbackEnchantifyLore : bundledLibrary.enchantifyLore
        )
    }

    static var lorePacks: [LorePack] {
        LorePackRegistry.enabledPacks(
            coreSnippets: bundledLibrary.enchantifyLore.isEmpty ? fallbackEnchantifyLore : bundledLibrary.enchantifyLore
        )
    }

    static var patreon: [ReferenceSnippet] {
        let snippets = bundledLibrary.patreon ?? []
        return snippets.isEmpty ? fallbackPatreon : snippets
    }

    static var characterIllustrations: [CharacterIllustrationProfile] {
        let profiles = bundledLibrary.characterIllustrations
        return profiles.isEmpty ? fallbackCharacterIllustrations + fallbackScheduledProfessorIllustrations : profiles
    }

    static var labyrinthIllustrations: [LabyrinthIllustrationPlate] {
        characterIllustrationPlates
    }

    static let bundledCharacterIllustrationAssetNames: Set<String> = [
        "LabyrinthCharacterDrElowenVellum",
        "LabyrinthCharacterGwendolynMythwright",
        "LabyrinthCharacterSorenNg",
        "LabyrinthCharacterLydiaBoggle",
        "LabyrinthCharacterProfessorKyleMomort",
        "LabyrinthCharacterProfessorEleanorEuphony",
        "LabyrinthCharacterProfessorVivianVillanelle",
        "LabyrinthCharacterProfessorCedricStonebrook",
        "LabyrinthCharacterProfessorLunaWispwood",
        "LabyrinthCharacterProfessorPermancer",
        "LabyrinthTalismanEmberSeal",
        "LabyrinthTalismanMossClasp",
        "LabyrinthTalismanTideGlass",
        "LabyrinthTalismanWindCipher",
        "LabyrinthTalismanDuskThorn",
        "LabyrinthCharacterDrSeleneInkrest",
        "LabyrinthCharacterHeadmistressSeraphinaThorne",
        "LabyrinthCharacterOrionBlackthorn",
        "LabyrinthCharacterPennyBlackletter",
        "LabyrinthCharacterSerenityBrown",
        "LabyrinthCharacterFinnBridges",
        "LabyrinthCharacterLysanderMosswood",
        "LabyrinthCharacterDamienNights",
        "LabyrinthCharacterMinSeoKim",
        "LabyrinthCharacterMelisandeBlackwood",
        "LabyrinthCharacterWickerEddies",
        "LabyrinthCharacterZaraFinch",
        "LabyrinthFaeBookSprite",
        "LabyrinthFaeSentenceSalamander",
        "LabyrinthFaePunctuationPixie",
        "LabyrinthFaeDeepLoreDwarf",
        "LabyrinthFaeMarginaliaGoblin",
        "LabyrinthLocationOuterStacks",
        "LabyrinthLocationStacks",
        "LabyrinthLocationGreatHall",
        "LabyrinthLocationKitchens",
        "LabyrinthLocationQuillquarium",
        "LabyrinthLocationBookBurrow",
        "LabyrinthLocationDorm"
    ]

    private static var characterIllustrationPlates: [LabyrinthIllustrationPlate] {
        characterIllustrations.compactMap { profile in
            let assetName = profile.assetName?.isEmpty == false ? profile.assetName ?? profile.intendedAssetName : profile.intendedAssetName
            guard bundledCharacterIllustrationAssetNames.contains(assetName) else {
                return nil
            }
            return LabyrinthIllustrationPlate(
                id: "character-\(profile.slug)",
                assetName: assetName,
                title: profile.characterName,
                caption: profile.core,
                note: "\(profile.illustrationDossierKind) illustration. Signature: \(profile.signature). Marginalia: \(profile.marginalia.joined(separator: " | ")).",
                tags: Array((["illustration", profile.illustrationTag, profile.slug] + profile.tags).prefix(8)),
                characterID: profile.id
            )
        }
    }

    private static let fallbackCharacterIllustrations = [
        CharacterIllustrationProfile(
            id: "headmistress-seraphina-thorne",
            characterName: "Headmistress Seraphina Thorne",
            slug: "headmistress-seraphina-thorne",
            status: "canonical",
            chapter: "Duskthorn",
            core: "Leads the Academy; sees the Unwritten; ageless literary-elf face; star-cold eyes; hair pinned like a dark crown.",
            signature: "an antique star-dark key and a crownlike hairpin",
            palette: "ink black, old silver, star-gold",
            silhouette: "regal stillness; one hand resting on an antique key",
            continuity: "Preserve these identifiers across images; clothes, pose, age-light, and mood may vary with the scene.",
            avoid: "generic anime face, room-first composition, inconsistent signature object, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterHeadmistressSeraphinaThorne",
            intendedAssetName: "LabyrinthCharacterHeadmistressSeraphinaThorne",
            prompt: "Create an Enchantify Academy character dossier illustration in sparse graphite and ink, watercolor washes, jewel-color accents, and character-specific parchment marginalia.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, polished digital fantasy portrait, and inconsistent signature object.",
            marginalia: [
                "file tab labeled Headmistress Seraphina Thorne",
                "signature evidence: an antique star-dark key and a crownlike hairpin",
                "jewel-color swatches: ink black, old silver, star-gold"
            ],
            tags: ["canonical", "character", "duskthorn", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "vesper-thorne",
            characterName: "Vesper Thorne",
            slug: "vesper-thorne",
            status: "canonical",
            chapter: "Duskthorn",
            core: "Duskthorn Enchantment Guardian; safeguards honesty, boundaries, and necessary friction; clear expressive eyes and a memorable silhouette",
            signature: "a blackthorn ward-pin",
            palette: "black violet, thorn green, tarnished silver",
            silhouette: "still posture; one hand near the ward-pin",
            continuity: "Preserve these identifiers across images; clothes, pose, age-light, and mood may vary with the scene.",
            avoid: "generic anime face, room-first composition, inconsistent signature object, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterVesperThorne",
            intendedAssetName: "LabyrinthCharacterVesperThorne",
            prompt: "Create an Enchantify Academy character dossier illustration in sparse graphite and ink, watercolor washes, black-violet jewel accents, and Duskthorn parchment marginalia.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, polished digital fantasy portrait, and inconsistent signature object.",
            marginalia: [
                "file tab labeled Vesper Thorne",
                "signature evidence: a blackthorn ward-pin",
                "jewel-color swatches: black violet, thorn green, tarnished silver",
                "chapter mark: Duskthorn"
            ],
            tags: ["canonical", "character", "duskthorn", "illustration", "vesper-thorne"]
        )
    ]

    private static let fallbackScheduledProfessorIllustrations = [
        CharacterIllustrationProfile(
            id: "lydia-boggle",
            characterName: "Professor Lydia Boggle",
            slug: "lydia-boggle",
            status: "canonical",
            chapter: "Riddlewind",
            core: "Professor of The Art of the Glint — the noticing class. Humorous, witty, mid-laugh; an animist with a chaos streak who finds the glint in the garbage and pays the world the attention it's owed. Always a pun ready.",
            signature: "a small glint-lens held up to an ordinary found object (a misspelled sign, an odd vanity plate)",
            palette: "marigold gold, robin's-egg blue, warm ink",
            silhouette: "caught mid-delight, holding an ordinary object up to the light as if it were evidence",
            continuity: "Preserve these identifiers across images; clothes, pose, age-light, and mood may vary with the scene.",
            avoid: "solemn sage, tidy academic portrait, inconsistent signature object, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterLydiaBoggle",
            intendedAssetName: "LabyrinthCharacterLydiaBoggle",
            prompt: "Create an Enchantify Academy character dossier illustration in the house style: sparse graphite and ink linework, watercolor washes, jewel-color accents, and character-specific parchment marginalia. A single character, centered, knowing and a little uncanny — not a generic portrait. Subject: Professor Lydia Boggle — playful Riddlewind professor of noticing, animist with a chaos sensibility, mid-laugh, holding an ordinary object up to the light like evidence. Signature: a small glint-lens and odd found objects (a misspelled sign, a vanity plate). Palette: marigold gold, robin's-egg blue, warm ink.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, polished digital fantasy portrait, room-first composition, and inconsistent signature object.",
            marginalia: [
                "file tab labeled Professor Lydia Boggle",
                "signature evidence: a glint-lens and an ordinary object held to the light",
                "jewel-color swatches: marigold gold, robin's-egg blue, warm ink",
                "margin note: \"what does it know? — wait for it\""
            ],
            tags: ["canonical", "character", "riddlewind", "noticing", "glint", "illustration", "lydia-boggle"]
        ),
        CharacterIllustrationProfile(
            id: "professor-kyle-momort",
            characterName: "Professor Kyle Momort",
            slug: "professor-kyle-momort",
            status: "canonical",
            chapter: "Emberheart",
            core: "Professor of Wayfinding and Narrative Kineticism; brisk, charismatic, and a little too fond of exits; teaches intentional momentum and small crossed thresholds.",
            signature: "a folding route-map and a chalk arrow that refuses to point backward",
            palette: "ember orange, road-sign blue, charcoal ink",
            silhouette: "already in motion, coat turning behind him, one hand marking a route",
            continuity: "Preserve the moving posture, folding route-map, chalk arrow, and quick amused expression.",
            avoid: "static lecturer, generic adventurer, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorKyleMomort",
            intendedAssetName: "LabyrinthCharacterProfessorKyleMomort",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Kyle Momort in motion with a folding route-map and impossible chalk arrow; ember orange, road-sign blue, charcoal ink; kinetic marginalia and threshold diagrams.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, static office portrait, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Kyle Momort", "signature evidence: folding route-map and chalk arrow", "chapter mark: Emberheart"],
            tags: ["canonical", "character", "faculty", "professor", "emberheart", "wayfinding", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-eleanor-euphony",
            characterName: "Professor Eleanor Euphony",
            slug: "professor-eleanor-euphony",
            status: "canonical",
            chapter: "Tidecrest",
            core: "Professor of Synesthetic Resonance; lush, attentive, and able to hear the emotional weather humming inside a room.",
            signature: "a silver tuning fork wound with colored thread",
            palette: "tidal blue, plum violet, resonant silver",
            silhouette: "head tilted toward an unheard chord, tuning fork poised near one palm",
            continuity: "Preserve the listening posture, colored-thread tuning fork, and sensory notation in the margins.",
            avoid: "stage singer, generic musician, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorEleanorEuphony",
            intendedAssetName: "LabyrinthCharacterProfessorEleanorEuphony",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Eleanor Euphony listening to a silver tuning fork wound with colored thread; tidal blue, plum violet, resonant silver; marginal notes that translate sound into color.",
            negativePrompt: "Avoid concert imagery, glossy anime, generic fantasy pinup, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Eleanor Euphony", "signature evidence: silver tuning fork and colored thread", "chapter mark: Tidecrest"],
            tags: ["canonical", "character", "faculty", "professor", "tidecrest", "sound", "sense", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-vivian-villanelle",
            characterName: "Professor Vivian Villanelle",
            slug: "professor-vivian-villanelle",
            status: "canonical",
            chapter: "Riddlewind",
            core: "Professor of Ink-Binding and Souvenir Craft; exacting, lyrical, and kind; teaches students to keep one true moment in one durable sentence.",
            signature: "a black-glass pen and a narrow ribbon of freshly bound text",
            palette: "black ink, wine red, parchment gold",
            silhouette: "composed and exact, weighing a sentence between pen and fingertips",
            continuity: "Preserve the black-glass pen, ribbon of text, and precise editorial gaze.",
            avoid: "generic poet, quill cliché, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorVivianVillanelle",
            intendedAssetName: "LabyrinthCharacterProfessorVivianVillanelle",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Vivian Villanelle with a black-glass pen and ribbon of bound text; black ink, wine red, parchment gold; edited sentences and souvenir scraps in the margins.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, generic quill portrait, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Vivian Villanelle", "signature evidence: black-glass pen and bound sentence", "chapter mark: Riddlewind"],
            tags: ["canonical", "character", "faculty", "professor", "riddlewind", "writing", "souvenir", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-cedric-stonebrook",
            characterName: "Professor Cedric Stonebrook",
            slug: "professor-cedric-stonebrook",
            status: "canonical",
            chapter: "Mossbloom",
            core: "Professor of Quiet Hours and Compass Running; slow, grounded, and weathered; teaches complete small adventures with Rest at their center.",
            signature: "a palm-sized trail marker and a five-point Compass stone",
            palette: "moss green, river stone gray, weathered ochre",
            silhouette: "steady and unhurried, seated or standing as if the ground has accepted him",
            continuity: "Preserve the trail marker, Compass stone, weathered coat, and unhurried expression.",
            avoid: "mountain-man caricature, mystical guru, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorCedricStonebrook",
            intendedAssetName: "LabyrinthCharacterProfessorCedricStonebrook",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Cedric Stonebrook with a small trail marker and five-point Compass stone; moss green, river gray, weathered ochre; quiet field notes in the margins.",
            negativePrompt: "Avoid guru clichés, glossy anime, generic fantasy pinup, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Cedric Stonebrook", "signature evidence: trail marker and Compass stone", "chapter mark: Mossbloom"],
            tags: ["canonical", "character", "faculty", "professor", "mossbloom", "rest", "compass-run", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-luna-wispwood",
            characterName: "Professor Luna Wispwood",
            slug: "professor-luna-wispwood",
            status: "canonical",
            chapter: "Tidecrest",
            core: "Professor of Basic Enchantments; scattered, sparking, and delighted by useful accidents; teaches ordinary objects to answer close attention.",
            signature: "a rain-bright wand wrapped in copper wire and a softly argumentative teacup",
            palette: "rain blue, copper spark, cloud white",
            silhouette: "wind-touched and slightly disheveled, one sleeve giving off a harmless spark",
            continuity: "Preserve the copper-wrapped wand, argumentative teacup, sparks, and rain-lit appearance.",
            avoid: "generic witch, dangerous explosion, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorLunaWispwood",
            intendedAssetName: "LabyrinthCharacterProfessorLunaWispwood",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Luna Wispwood with a copper-wrapped rain-bright wand and enchanted teacup; rain blue, copper spark, cloud white; object replies scribbled in the margins.",
            negativePrompt: "Avoid generic witch imagery, glossy anime, destructive magic, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Luna Wispwood", "signature evidence: copper-wrapped wand and enchanted teacup", "chapter mark: Tidecrest"],
            tags: ["canonical", "character", "faculty", "professor", "tidecrest", "enchantment", "objects", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-permancer",
            characterName: "Professor Permancer",
            slug: "professor-permancer",
            status: "canonical",
            chapter: "Duskthorn",
            core: "Professor of Book Jumping; precise, adventurous, and fiercely safety-minded; teaches narrative weather, controlled landings, and responsible returns.",
            signature: "a many-ribboned bookmark compass and a ring of labeled door keys",
            palette: "doorway violet, safety gold, midnight ink",
            silhouette: "poised at a threshold, one hand on a bookmark compass and the other counting keys",
            continuity: "Preserve the bookmark compass, labeled keys, threshold posture, and alert measuring gaze.",
            avoid: "reckless adventurer, generic wizard, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorPermancer",
            intendedAssetName: "LabyrinthCharacterProfessorPermancer",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Permancer at a story-door with a many-ribboned bookmark compass and labeled keys; doorway violet, safety gold, midnight ink; landing diagrams in the margins.",
            negativePrompt: "Avoid reckless action poses, glossy anime, generic fantasy wizard, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Permancer", "signature evidence: bookmark compass and labeled door keys", "chapter mark: Duskthorn"],
            tags: ["canonical", "character", "faculty", "professor", "duskthorn", "book-jump", "threshold", "illustration"]
        )
    ]

    private static let bundledLibrary: BookReferenceLibraryPayload = {
        // A local library dropped into Documents overrides the bundled
        // one: the shipped app stays generic while a player's own lore
        // rides along as save data, not binary.
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let local = documents.appendingPathComponent("LocalReferenceLibrary.json")
            if let data = try? Data(contentsOf: local),
               let payload = try? JSONDecoder().decode(BookReferenceLibraryPayload.self, from: data) {
                return payload
            }
        }
        guard let url = Bundle.main.url(forResource: "BookReferenceLibrary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(BookReferenceLibraryPayload.self, from: data) else {
            return .empty
        }
        return payload
    }()

    static let fallbackWonderCompass: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "wonder-compass-core-loop",
            sourceID: "wonder-compass",
            title: "The Wonder Compass",
            prompt: "Try one small Compass loop.",
            body: "Notice a spark. Embark across one tiny threshold. Sense with a playful mission. Write one sentence before the moment blurs. Rest stays at the center.",
            tags: ["wonder-compass", "practice", "notice", "embark", "sense", "write", "rest"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-one-sentence",
            sourceID: "wonder-compass",
            title: "One-Sentence Souvenir",
            prompt: "Keep one bright particular.",
            body: "A single specific sentence can hold the shape of an entire day. Capture a color, sound, texture, image, or tiny mercy before your brain files it under ordinary.",
            tags: ["wonder-compass", "souvenir", "write", "memory"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-rest-center",
            sourceID: "wonder-compass",
            title: "Center Means Rest",
            prompt: "Let rest be part of the practice.",
            body: "Rest is not failure to adventure. Rest is the center of the Compass. Some days the most radical expedition is stopping before the day breaks you.",
            tags: ["wonder-compass", "rest", "center", "care"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-dark-loop",
            sourceID: "wonder-compass",
            title: "The Compass In The Dark",
            prompt: "Use the smallest true thing.",
            body: "On hard days, the Compass gets smaller. Notice one object that is not dying. Embark by moving one inch. Sense without judging. Write evidence: I was here.",
            tags: ["wonder-compass", "hard-day", "rest", "survival"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-playful-mission",
            sourceID: "wonder-compass",
            title: "Playful Mission",
            prompt: "Give your senses a tiny game.",
            body: "Pick an action, an adjective, and a sense: find three rough textures, listen for five tiny sounds, hunt one impossible shade of blue. Play makes attention easier to hold.",
            tags: ["wonder-compass", "sense", "play"]
        )
    ]

    static let fallbackEnchantifyLore: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "labyrinth-lore-book-of-you",
            sourceID: "labyrinth-lore",
            title: "The Book of You",
            prompt: "Let today become a page worth keeping.",
            body: "The Book of You is the private volume that waits closest to the reader. It does not demand grand adventures. It notices the cup left beside the bed, the weather at the window, the sentence that would have vanished if no one had written it down. When a page is kept, the Book does not announce a score. It simply grows warmer, as if one more lamp has been lit in a long room.",
            tags: ["book-of-you", "memory", "private", "rooms"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-academy",
            sourceID: "labyrinth-lore",
            title: "The Academy of Unlikely Arts",
            prompt: "Step through the school-shaped margin.",
            body: "The Academy is a school built inside a living library. Its corridors behave like chapters, its classrooms keep weather of their own, and its professors tend to believe ordinary life is already enchanted but poorly indexed. Students learn by paying attention, losing their way responsibly, and returning with evidence. The school is less interested in spectacle than in whether a person can notice a true thing and carry it home intact.",
            tags: ["academy", "school", "history", "classes"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-penny-blackletter",
            sourceID: "labyrinth-lore",
            title: "Penny Blackletter",
            prompt: "Let Penny file the ridiculous evidence.",
            body: "Penny Blackletter runs the margins as if every overlooked detail might become tomorrow's headline. She writes fast, loves a field note, distrusts any sentence that arrives too polished, and has never met a strange little scrap of paper she could not put to work. Penny is warm under the theatrical deadlines. She believes a day is not truly lost if one honest detail can still be recovered from it.",
            tags: ["characters", "penny", "marginalia", "letters"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-letters",
            sourceID: "labyrinth-lore",
            title: "Letters From The Margins",
            prompt: "A message can arrive from elsewhere.",
            body: "Letters in the Labyrinth do not arrive merely to explain things. They arrive with tea rings, crossed-out sentences, pressed flowers, bad timing, and the faint sense that someone hesitated before folding the page. A good letter carries relationship: what the sender wants, what they fear asking, what they noticed when the reader was elsewhere, and which door they are quietly hoping will open next.",
            tags: ["letters", "characters", "relationships", "margins"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-outer-stacks",
            sourceID: "labyrinth-lore",
            title: "The Outer Stacks",
            prompt: "Let a place become a room.",
            body: "Beyond the Academy's catalogued halls are the Outer Stacks, where real places gather room-feelings. A harbor may become a tidal reading room. A cafe may keep a tiny kingdom beneath the sugar packets. A parking lot may hold a door that only appears when the light hits the asphalt correctly. The Outer Stacks do not make places less real. They make them more themselves.",
            tags: ["outer-stacks", "location", "rooms", "place"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-rooms",
            sourceID: "labyrinth-lore",
            title: "Rooms That Behave Like Pages",
            prompt: "Open the door that has been waiting.",
            body: "Rooms in the Labyrinth are not neutral containers. A room has a mood, a history, a preferred volume, and sometimes a private grudge against certain shoes. The Quillquarium is full of writing instruments swimming through the air until the right one chooses the right student. The Book Burrow is where lamps, blankets, snacks, and low voices make hanging out feel like a valid form of magic. The Dorm is the reader's private continuity room: shaped by kept pages, souvenirs, letters, chapter weather, and chosen comforts, but careful never to invent private facts. A Story Page can borrow any of these rooms when a day needs shape, shelter, or mischief.",
            tags: ["classes", "locations", "rooms", "story", "quillquarium", "book-burrow", "dormitory"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-classes",
            sourceID: "labyrinth-lore",
            title: "The Compass Core Classes",
            prompt: "Let the school turn attention into practice.",
            body: "Every student eventually meets the foundation classes. Professor Lydia Boggle teaches the Art of the Glint, where ordinary objects are treated as witnesses. Professor Kyle Momort teaches Wayfinding and Narrative Kineticism, and his students learn that motion has consequences even when it begins as one step. Professor Eleanor Euphony teaches Synesthetic Resonance, where rooms have temperature, colors have weight, and the senses are given serious academic standing. Professor Vivian Villanelle teaches Ink-Binding and Souvenir Craft, where a sentence becomes a small vessel for time.",
            tags: ["classes", "faculty", "school", "schedule"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-schedule",
            sourceID: "labyrinth-lore",
            title: "The Shape of a School Day",
            prompt: "Notice the bells beneath the ordinary day.",
            body: "A school day at the Academy has a rhythm, though the building enjoys bending it. Morning classes run when the corridors are bright enough to be optimistic. Afternoon classes take the settled hours, when the Library has formed opinions and students are less easily impressed. Clubs gather under lamps in rooms that pretend not to be listening. Between these formal hours are the true passages: breakfast gossip, corridor weather, the note slipped under a door, and the friend waiting outside the room with a question folded into silence.",
            tags: ["classes", "schedule", "school", "student-life"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-headmistress-thorne",
            sourceID: "labyrinth-lore",
            title: "Headmistress Seraphina Thorne",
            prompt: "Let authority enter with a hidden page.",
            body: "Headmistress Seraphina Thorne has the poise of someone who can silence a room by closing a book. Students see the elegant robes, the precise speech, the old authority of a person who knows which staircases lie. What they do not always see is the cost of keeping a school safe when the school itself is a living text with strong opinions and a long memory. Thorne is not soft, but she is not careless. Her office contains a legendary inkwell, officially for safekeeping. Unofficially, students suspect she uses it after midnight.",
            tags: ["characters", "faculty", "headmistress", "history"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-history",
            sourceID: "labyrinth-lore",
            title: "Unreliable Academy History",
            prompt: "Let the old stories misbehave politely.",
            body: "Academy history is full of incidents recorded with suspiciously careful handwriting. During the Day of the Living Literary Figures, Sherlock Holmes, Alice, and Dracula appeared in the cafeteria at the same time; Holmes deduced the menu, Alice critiqued the architecture, and Dracula objected to the lighting. The Pages of Laughter and Tears once made an entire class alternate between hysterics and sobbing until someone discovered the comedy and tragedy pages had been shelved out of order. These stories are told as warnings, but students mostly hear invitations.",
            tags: ["academy", "history", "school", "story"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-weather",
            sourceID: "labyrinth-lore",
            title: "Weather in the Stacks",
            prompt: "Let the sky annotate the page.",
            body: "Weather at the Academy is never only meteorological, but it is never merely symbolic either. Fog makes professors cancel class to watch the harbor disappear by degrees. Rain turns corridors into quieter arguments. Bright cold sharpens the ink. Heat makes the paper curl and the students theatrical. The Library cloud above the great ceiling changes color when the building is thinking about something it does not intend to say aloud. A weather page should remain legible, but the Book may name the mood of the response. The reader should feel tended, not watched.",
            tags: ["atmosphere", "school", "weather", "world"]
        )
    ]

    static let fallbackPatreon: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "patreon-clubhouse-free-shelf",
            sourceID: "patreon-packet",
            title: "Patreon Clubhouse",
            prompt: "The free shelf is open.",
            body: "The Wonder Compass ebook, printable play-sheets, Spark menus, Playful Mission menus, and Clubhouse notes live at patreon.com/thedoobaleedoos. The practice is free; the attention is real.",
            tags: ["patreon", "clubhouse", "wonder-compass", "free"]
        )
    ]

    static func dailyWonderCompassSnippet(for day: BookDay, now: Date = Date()) -> ReferenceSnippet {
        snippet(from: wonderCompass, dayID: day.id, sourceID: "wonder-compass", now: now)
    }

    static func relevantWonderCompassSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date()
    ) -> ReferenceSnippet {
        relevantWonderCompassSnippets(for: day, inputs: inputs, now: now, limit: 1).first
            ?? dailyWonderCompassSnippet(for: day, now: now)
    }

    static func rotatingWonderCompassSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        manual: Bool = false
    ) -> ReferenceSnippet {
        let pool = relevantWonderCompassSnippets(for: day, inputs: inputs, now: now, limit: 8)
        return rotatedSnippet(from: pool, day: day, sourceID: "wonder-compass", now: now, manual: manual)
            ?? dailyWonderCompassSnippet(for: day, now: now)
    }

    static func relevantWonderCompassSnippets(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        limit: Int = 8
    ) -> [ReferenceSnippet] {
        let snippets = wonderCompass
        guard !snippets.isEmpty else { return [] }

        let contextTerms = wonderCompassContextTerms(for: day, inputs: inputs, now: now)
        let rotationSlot = referenceRotationSlot(for: now)
        let recentKeys = inputs.recentVarietyKeys(now: now)
        let scored = snippets.enumerated().map { offset, snippet in
            let haystack = ([snippet.title, snippet.prompt, snippet.body] + snippet.tags)
                .joined(separator: " ")
                .lowercased()
            var score = contextTerms.reduce(0) { partial, term in
                haystack.contains(term) ? partial + 1 : partial
            }
            // A chapter the reader was just shown yields the lectern.
            if recentKeys.contains("snippet:\(snippet.id)") {
                score -= 3
            }
            return (offset: offset, snippet: snippet, score: score)
        }

        return scored
            .sorted { left, right in
                if left.score == right.score {
                    let daySeed = stableIndex(for: "\(day.id)-\(rotationSlot)-\(left.snippet.id)-wonder-compass-relevance", count: 10_000)
                    let otherSeed = stableIndex(for: "\(day.id)-\(rotationSlot)-\(right.snippet.id)-wonder-compass-relevance", count: 10_000)
                    if daySeed == otherSeed {
                        return left.offset < right.offset
                    }
                    return daySeed < otherSeed
                }
                return left.score > right.score
            }
            .prefix(max(1, limit))
            .map(\.snippet)
    }

    static func dailyEnchantifyLoreSnippet(for day: BookDay, now: Date = Date()) -> ReferenceSnippet {
        snippet(from: enchantifyLore, dayID: day.id, sourceID: "labyrinth-lore", now: now)
    }

    static func relevantLoreSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date()
    ) -> ReferenceSnippet {
        relevantLoreSnippets(for: day, inputs: inputs, now: now, limit: 1).first
            ?? dailyEnchantifyLoreSnippet(for: day, now: now)
    }

    static func rotatingLoreSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        manual: Bool = false
    ) -> ReferenceSnippet {
        let pool = relevantLoreSnippets(for: day, inputs: inputs, now: now, limit: 8)
        return rotatedSnippet(from: pool, day: day, sourceID: "labyrinth-lore", now: now, manual: manual)
            ?? dailyEnchantifyLoreSnippet(for: day, now: now)
    }

    static func relevantLoreSnippets(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        limit: Int = 6
    ) -> [ReferenceSnippet] {
        let snippets = enchantifyLore
        guard !snippets.isEmpty else { return [] }

        let contextTerms = loreContextTerms(for: day, inputs: inputs, now: now)
        let rotationSlot = referenceRotationSlot(for: now)
        let recentKeys = inputs.recentVarietyKeys(now: now)
        let scored = snippets.enumerated().map { offset, snippet in
            let haystack = ([snippet.title, snippet.prompt, snippet.body] + snippet.tags)
                .joined(separator: " ")
                .lowercased()
            var score = contextTerms.reduce(0) { partial, term in
                haystack.contains(term) ? partial + 1 : partial
            }
            if recentKeys.contains("snippet:\(snippet.id)") {
                score -= 3
            }
            return (offset: offset, snippet: snippet, score: score)
        }

        return scored
            .sorted { left, right in
                if left.score == right.score {
                    let leftSeed = stableIndex(for: "\(day.id)-\(rotationSlot)-\(left.snippet.id)-labyrinth-lore-relevance", count: 10_000)
                    let rightSeed = stableIndex(for: "\(day.id)-\(rotationSlot)-\(right.snippet.id)-labyrinth-lore-relevance", count: 10_000)
                    if leftSeed == rightSeed {
                        return left.offset < right.offset
                    }
                    return leftSeed < rightSeed
                }
                return left.score > right.score
            }
            .prefix(max(1, limit))
            .map(\.snippet)
    }

    static func patreonShelfSnippet(now: Date = Date()) -> ReferenceSnippet {
        snippet(from: patreon, dayID: currentDayID(now), sourceID: "patreon-packet", now: now)
    }

    static func rotatingPatreonShelfSnippet(for day: BookDay, now: Date = Date(), manual: Bool = false) -> ReferenceSnippet {
        let pool = patreon.isEmpty ? [] : patreon
        return rotatedSnippet(from: pool, day: day, sourceID: "patreon-packet", now: now, manual: manual)
            ?? patreonShelfSnippet(now: now)
    }

    static func patreonPostSnippets(limit: Int = 6, now: Date = Date()) -> [ReferenceSnippet] {
        let posts = patreon
            .filter { snippet in
                snippet.url?.isEmpty == false
                    || snippet.body.range(of: "https://", options: [.caseInsensitive]) != nil
                    || snippet.body.range(of: "http://", options: [.caseInsensitive]) != nil
            }
            .sorted { left, right in
                let leftDate = left.publishedAt ?? ""
                let rightDate = right.publishedAt ?? ""
                if leftDate == rightDate {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return leftDate > rightDate
            }
        guard !posts.isEmpty else { return [] }
        return Array(posts.prefix(max(1, limit)))
    }

    static func labyrinthIllustration(for day: BookDay, now: Date = Date()) -> LabyrinthIllustrationPlate {
        guard !labyrinthIllustrations.isEmpty else {
            return LabyrinthIllustrationPlate(
                id: "empty",
                assetName: "",
                title: "Illustration",
                caption: "The illustration shelf is empty for now.",
                note: "Add character dossier assets to wake this page.",
                tags: ["illustration"]
            )
        }
        let seed = "\(day.id)-labyrinth-illustrations-\(referenceRotationSlot(for: now, hours: 1))"
        return labyrinthIllustrations[stableIndex(for: seed, count: labyrinthIllustrations.count)]
    }

    static func rotatingLabyrinthIllustration(for day: BookDay, now: Date = Date(), manual: Bool = false) -> LabyrinthIllustrationPlate {
        guard !labyrinthIllustrations.isEmpty else {
            return labyrinthIllustration(for: day, now: now)
        }
        let slot = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let seed = "\(day.id)-labyrinth-illustrations-\(slot)-\(manual ? "manual" : "curator")"
        return labyrinthIllustrations[stableIndex(for: seed, count: labyrinthIllustrations.count)]
    }

    private static func rotatedSnippet(
        from snippets: [ReferenceSnippet],
        day: BookDay,
        sourceID: String,
        now: Date,
        manual: Bool
    ) -> ReferenceSnippet? {
        guard !snippets.isEmpty else { return nil }
        let slot = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let seed = "\(day.id)-\(sourceID)-\(slot)-\(manual ? "manual" : "curator")"
        return snippets[stableIndex(for: seed, count: snippets.count)]
    }

    static func characterIllustrationProfile(id: String?) -> CharacterIllustrationProfile? {
        guard let id else { return nil }
        return characterIllustrations.first { $0.id == id }
    }

    static func firstURL(in snippet: ReferenceSnippet) -> String? {
        snippet.url?.isEmpty == false ? snippet.url : firstURL(in: snippet.body)
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    private static func currentDayID(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func snippet(from snippets: [ReferenceSnippet], dayID: String, sourceID: String, now: Date) -> ReferenceSnippet {
        guard !snippets.isEmpty else {
            return ReferenceSnippet(
                id: "\(sourceID)-empty",
                sourceID: sourceID,
                title: "Reference Page",
                prompt: "A reference page is waiting.",
                body: "The Book knows this shelf exists, but no snippets have been loaded yet.",
                tags: [sourceID]
            )
        }

        let seed = "\(dayID)-\(sourceID)-\(referenceRotationSlot(for: now))"
        let index = stableIndex(for: seed, count: snippets.count)
        return snippets[index]
    }

    private static func referenceRotationSlot(for date: Date, hours: Int = 2, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour], from: date)
        return (components.hour ?? 0) / max(1, hours)
    }

    private static func wonderCompassContextTerms(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [String] {
        var terms: Set<String> = ["wonder", "notice"]
        let hour = Calendar.current.component(.hour, from: now)

        if hour >= 18 {
            terms.formUnion(["souvenir", "write", "memory", "sentence"])
        }
        if hour >= 20 {
            terms.formUnion(["rest", "center", "care"])
        }

        for page in day.capturedPages {
            terms.formUnion(page.tags.map { $0.lowercased() })
            let lowered = page.userInput.lowercased()
            if lowered.contains("tired") || lowered.contains("low") || lowered.contains("hard") || lowered.contains("heavy") {
                terms.formUnion(["rest", "care", "hard-day"])
            }
            if lowered.contains("walk") || lowered.contains("outside") || lowered.contains("errand") {
                terms.formUnion(["embark", "practice"])
            }
            if lowered.contains("saw") || lowered.contains("heard") || lowered.contains("felt") || lowered.contains("smell") {
                terms.formUnion(["sense", "notice"])
            }
            if lowered.contains("remember") || lowered.contains("moment") || lowered.contains("today") {
                terms.formUnion(["souvenir", "write", "memory"])
            }
            if lowered.contains("play") || lowered.contains("fun") || lowered.contains("silly") {
                terms.formUnion(["play", "mission"])
            }
        }

        if let body = inputs.body {
            let lowered = "\(body.status) \(body.phrase)".lowercased()
            if body.score > 0 && body.score <= 35 || lowered.contains("low") || lowered.contains("gentle") {
                terms.formUnion(["rest", "center", "care", "hard-day"])
            }
        }

        if let weather = inputs.weather {
            let lowered = weather.phrase.lowercased()
            if lowered.contains("rain") || lowered.contains("fog") || lowered.contains("storm") {
                terms.formUnion(["sense", "notice", "rest"])
            }
            if lowered.contains("sun") || lowered.contains("bright") || lowered.contains("clear") {
                terms.formUnion(["embark", "play", "notice"])
            }
        }

        for fact in inputs.selfFacts where fact.usePermission != .doNotUse {
            terms.formUnion(fact.tags.map { $0.lowercased() })
            let lowered = "\(fact.question) \(fact.answer)".lowercased()
            if lowered.contains("home") {
                terms.formUnion(["home", "rest", "care"])
            }
            if lowered.contains("color") || lowered.contains("delight") || lowered.contains("joy") {
                terms.formUnion(["play", "wonder", "notice"])
            }
            if lowered.contains("rest") || lowered.contains("quiet") || lowered.contains("sleep") {
                terms.formUnion(["rest", "center", "care"])
            }
            if lowered.contains("believe") || lowered.contains("protect") || lowered.contains("become") {
                terms.formUnion(["belief", "practice", "memory"])
            }
        }

        return Array(terms)
    }

    private static func loreContextTerms(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [String] {
        var terms = Set(wonderCompassContextTerms(for: day, inputs: inputs, now: now))
        terms.formUnion(["academy", "book", "characters", "lore", "rooms", "school", "story"])

        let hour = Calendar.current.component(.hour, from: now)
        if hour < 11 {
            terms.formUnion(["schedule", "classes", "today"])
        } else if hour >= 18 {
            terms.formUnion(["letters", "dormitory", "student-life"])
        }

        if inputs.weather != nil {
            terms.formUnion(["weather", "atmosphere"])
        }
        if inputs.body != nil {
            terms.formUnion(["body", "care"])
        }
        if inputs.selfFacts.contains(where: { $0.usePermission != .doNotUse && $0.tags.contains("home") }) {
            terms.formUnion(["home", "dormitory", "rooms"])
        }

        return Array(terms)
    }

    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let value = seed.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)).multipliedReportingOverflow(by: 1_099_511_628_211).partialValue
        }
        return Int(value % UInt64(count))
    }
}

struct QuipPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .quip)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        quipSurface(for: day, context: context, inputs: inputs, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [quipSurface(for: day, context: context, inputs: inputs, now: now, manual: false)]
    }

    private func quipSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date, manual: Bool) -> SurfacePage {
        let tags = [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
        let quip = QuipPackRegistry.quip(
            for: day,
            now: manual ? now.addingTimeInterval(Double(Int.random(in: 1...10_000))) : now,
            tags: tags
        )
        let hour = Calendar.current.component(.hour, from: now)
        let score = context.distress.isActive ? 42 : (hour >= 12 && hour <= 18 ? 69 : 58)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return SurfacePage(
            id: "\(source.id)-\(quip.packID)-\(quip.id)-\(slotID)",
            type: .quip,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: score,
            reason: "A small oddity can tilt the day toward wonder without asking for work.",
            prompt: quip.title,
            detail: "A little perspective-spark from \(QuipPackRegistry.enabledPacks.first { $0.id == quip.packID }?.displayName ?? "the shelf").",
            payload: BookPagePayload(
                headline: quip.title,
                body: quip.text,
                metadata: [
                    "source": source.id,
                    "packID": quip.packID,
                    "quipID": quip.id,
                    "tags": quip.tags.joined(separator: ","),
                    "privacy": "bundled local text"
                ]
            )
        )
    }
}

/// Resolves a character (by display name) to its official illustration profile —
/// the bundled portrait asset when one exists, and always the described palette,
/// signature, and core so a themed medallion can stand in where art doesn't yet.
enum CharacterPortrait {
    static func profile(forName name: String) -> CharacterIllustrationProfile? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty else { return nil }
        return BookReferenceCatalog.characterIllustrations.first {
            $0.characterName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
    }

    /// The asset name this character's art *would* use. The view checks whether
    /// that image actually exists in the catalog — so dropping a generated PNG in
    /// is the only step needed to light up a portrait, no Swift edits.
    static func intendedAssetName(forName name: String) -> String? {
        guard let profile = profile(forName: name) else { return nil }
        return profile.assetName?.nonEmpty ?? profile.intendedAssetName.nonEmpty
    }

    /// The bundled image asset for this character, or nil if only a description
    /// exists (use the medallion fallback then).
    static func bundledAssetName(forName name: String) -> String? {
        guard let profile = profile(forName: name) else { return nil }
        let asset = profile.assetName?.nonEmpty ?? profile.intendedAssetName
        return BookReferenceCatalog.bundledCharacterIllustrationAssetNames.contains(asset) ? asset : nil
    }

    /// The character's official palette words (e.g. "ink black, old silver"),
    /// for tinting a fallback medallion.
    static func paletteWords(forName name: String) -> [String] {
        (profile(forName: name)?.palette ?? "")
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    static func initials(forName name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
