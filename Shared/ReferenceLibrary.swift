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
        let tagSet = Set(tags.map { $0.lowercased() })
        let wantsShadow = tagSet.contains("shadow-wonder") || tagSet.contains("shadow")
        let quips = enabledPacks.flatMap(\.quips).filter { quip in
            wantsShadow || !quip.tags.map { $0.lowercased() }.contains("shadow-wonder")
        }
        guard !quips.isEmpty else {
            return QuipEntry(id: "fallback", text: "The Book found a small bright thing and kept it.", title: "Filed Under Wonder", tags: ["wonder"], packID: corePackID, weight: 1)
        }
        let slot = SurfaceCadence.slotID(for: now, hours: 3)
        let seed = abs("\(day.id)-\(slot)-\(tags.joined(separator: ","))".stableHash)
        let ranked = quips.enumerated().map { index, quip in
            let overlap = tagSet.intersection(Set(quip.tags.map { $0.lowercased() })).count
            let jitter = abs((seed &+ index * 1543).stableScramble % 1000)
            return (quip, overlap * 20 + quip.weight * 3 + jitter)
        }
        if wantsShadow {
            let shadowQuips = ranked.filter {
                let tags = Set($0.0.tags.map { $0.lowercased() })
                return !tags.intersection(["shadow-wonder", "shadow", "night", "old", "history"]).isEmpty
            }
            if let pick = shadowQuips.sorted(by: { $0.1 > $1.1 }).first?.0 {
                return pick
            }
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
        quip("shadow-rust", "Rust is a slow confession: the metal remembers the ground and starts telling the truth.", "Shadow Wonder", ["shadow-wonder", "shadow", "rust", "history"], weight: 3),
        quip("shadow-crack", "A crack is a place where the surface stopped pretending it was seamless.", "Shadow Wonder", ["shadow-wonder", "shadow", "broken", "threshold"], weight: 3),
        quip("shadow-last-light", "The last light in a room is usually guarding something too small to name loudly.", "Shadow Wonder", ["shadow-wonder", "night", "light"], weight: 3),
        quip("shadow-peeling-paint", "Peeling paint is a building showing you its previous drafts.", "Shadow Wonder", ["shadow-wonder", "old", "history", "place"], weight: 3),
        quip("shadow-cobweb", "A cobweb is the only architecture that gets more honest the longer it's abandoned.", "Shadow Wonder", ["shadow-wonder", "shadow", "decay", "old"], weight: 3),
        quip("shadow-moth", "A moth chooses the lamp over the dark and the dark over safety; admire the commitment.", "Shadow Wonder", ["shadow-wonder", "night", "creature", "light"], weight: 3),
        quip("shadow-keyhole", "An old keyhole is a question the door is still asking about who's allowed in.", "Shadow Wonder", ["shadow-wonder", "threshold", "old", "mystery"], weight: 3),
        quip("shadow-low-tide", "Low tide isn't the sea leaving; it's the sea showing you what it usually keeps private.", "Shadow Wonder", ["shadow-wonder", "shadow", "water", "hidden"], weight: 3),
        quip("shadow-frost", "Frost is winter's marginalia, written overnight and erased by anyone who waits too long to read it.", "Shadow Wonder", ["shadow-wonder", "night", "cold", "weather"], weight: 3),
        quip("shadow-closed-shop", "A shuttered shop still hums with every birthday dinner it ever held; the grey just stops listening.", "Shadow Wonder", ["shadow-wonder", "old", "history", "place"], weight: 3),
        quip("shadow-grey-sky", "A grey sky isn't an absence of weather. It's the day choosing a minor key, and minor keys hold you.", "Shadow Wonder", ["shadow-wonder", "weather", "somber", "mood-match"], weight: 3),
        quip("shadow-scar", "A scar is proof the body chose to keep going and kept the receipt.", "Shadow Wonder", ["shadow-wonder", "shadow", "body", "history"], weight: 3),
        quip("shadow-dusk", "Dusk is the day's threshold, neither in nor out — which is exactly why the fae prefer it.", "Shadow Wonder", ["shadow-wonder", "night", "dusk", "liminal", "fae"], weight: 3),
        quip("shadow-iron", "Folklore hung iron at the door to mind the edges of a home. You already do it; you just call it a key.", "Shadow Wonder", ["shadow-wonder", "folklore", "protection", "threshold"], weight: 3),
        quip("shadow-free-thing", "The goblin's only question, and the wisest one in the market: and what does this actually cost me?", "Shadow Wonder", ["shadow-wonder", "goblin", "bargain", "unseelie"], weight: 3),
        quip("shadow-name", "Name the dread exactly and it stops being weather. A thing with edges is a thing you can walk around.", "Shadow Wonder", ["shadow-wonder", "true-names", "grief", "naming"], weight: 3),
        quip("shadow-compost", "A compost heap is just grief doing its slow, useful work: nothing wasted, only changed.", "Shadow Wonder", ["shadow-wonder", "decay", "grief", "memory"], weight: 3),
        quip("shadow-empty-chair", "An empty chair keeps the shape of who sat there. That's not haunting. That's memory holding the door.", "Shadow Wonder", ["shadow-wonder", "grief", "absence", "memory"], weight: 3),
        quip("shadow-headmistress", "Watch which staircases lie when the Headmistress walks them. No, don't write that down. Penny didn't say it and neither did I.", "Shadow Wonder", ["shadow-wonder", "unseelie", "thorne", "duskthorn", "secret"], weight: 3),
        quip("shadow-crown", "Some crowns are worn on the head. Some are pinned into the hair, dark, where you'd mistake them for a hairstyle.", "Shadow Wonder", ["shadow-wonder", "unseelie", "thorne", "secret"], weight: 3),
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
            id: "wonder-compass-shadow-wonder",
            sourceID: "wonder-compass",
            title: "Shadow Wonder",
            prompt: "Let the Compass honor what is worn, old, broken, or passing.",
            body: "The Compass is not a filter for pretty things. Shadow Wonder uses I wonder to witness rust, decay, closed doors, grey weather, and old evidence with empathy instead of deletion.",
            tags: ["wonder-compass", "shadow-wonder", "shadow", "notice", "mono-no-aware", "duskthorn"]
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
            body: "Headmistress Seraphina Thorne has the poise of someone who can silence a room by closing a book. Students see the elegant robes, the precise speech, the old authority of a person who knows which staircases lie. What they do not always see is the cost of keeping a school safe when the school itself is a living text with strong opinions and a long memory. Thorne is not soft, but she is not careless. Her office contains a legendary inkwell, officially for safekeeping. Unofficially, students suspect she uses it after midnight. There is always, around her, the faint cold draft of a window left open onto winter — though no one has ever found the window.",
            tags: ["characters", "faculty", "headmistress", "history", "duskthorn"]
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

    /// The Shadow Wonder shelf — the Dusk Thorn's reading list. Real-world folklore
    /// and the canon's "harmonize with the grey" practice, framed the way the
    /// Labyrinth frames everything: as tradition to witness, not instruction to
    /// obey. Surfaced as Shadow Lore variants when the Dusk Thorn is invested in
    /// and the world turns toward the worn edge. Each carries a small, safe
    /// `practice` — an offering, a noticing, a threshold to honor.
    static let fallbackShadowLore: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "shadow-lore-what-it-is",
            sourceID: "labyrinth-lore",
            title: "Shadow Wonder",
            prompt: "The Dusk Thorn names wonder with an honest edge.",
            body: "Duskthorn does not ask the Book to become cruel. It asks the Book to stop sanding the edges off reality. Shadow Wonder is the practice of noticing rust, absence, decay, closed doors, old evidence, and grey weather as things with history instead of mistakes to delete. The bright Compass finds the sunset. The dark Compass finds the abandoned house going beautifully back to ivy — and refuses to look away.",
            tags: ["lore", "shadow-wonder", "shadow", "duskthorn", "talisman", "mono-no-aware"],
            practice: "Find one broken, worn, or closed thing nearby and ask it a single honest \"I wonder\" — about its history, not its repair."
        ),
        ReferenceSnippet(
            id: "shadow-lore-unseelie-court",
            sourceID: "labyrinth-lore",
            title: "The Unseelie Court",
            prompt: "Meet the winter half of the fae.",
            body: "Old folklore splits the fae into two courts. The Seelie are the bright, summer-tempered ones, mischievous but inclined to be kind if you are. The Unseelie are the dark court — winter, dusk, and the long night. They are not evil so much as unsentimental: they keep the rules that bright things forget, and they do not pretend the world is gentle when it isn't. Duskthorn keeps a quiet correspondence with them. The Labyrinth files them under Shadow Wonder for a reason — they are proof that something can be dangerous, beautiful, and worth respecting all at once. And if you ever want to know what one looks like wearing a crown of office — here Penny lowers her voice — watch which staircases lie when a certain Headmistress walks them. Then she changes the subject.",
            tags: ["lore", "shadow-wonder", "shadow", "unseelie", "fae", "duskthorn", "thorne", "folklore", "night"]
        ),
        ReferenceSnippet(
            id: "shadow-lore-dealing-with-unseelie",
            sourceID: "labyrinth-lore",
            title: "Dealing With the Unseelie",
            prompt: "Honest manners with dangerous guests.",
            body: "Folklore is full of etiquette for the dark court, and it is mostly about honesty and boundaries — which is why Duskthorn approves of it. Do not say a flat \"thank you,\" which can read as a debt admitted; say \"I'm grateful\" or \"you were kind to me\" instead. Do not give your true name to something that asks too eagerly. Do not eat what is offered until you know its price. Keep your promises exactly, because the Unseelie keep theirs exactly. Offer hospitality and you will usually receive it back. The rules are not superstition; they are an old, sideways lesson in not being careless with powerful things — or powerful people.",
            tags: ["lore", "shadow-wonder", "shadow", "unseelie", "fae", "duskthorn", "folklore", "protection", "boundaries"],
            practice: "Tonight, practice one fae-court manner in the real world: thank someone with \"that was kind of you\" instead of a reflexive \"thanks,\" and notice how differently it lands."
        ),
        ReferenceSnippet(
            id: "shadow-lore-the-headmistress",
            sourceID: "labyrinth-lore",
            title: "Which Staircases Lie",
            prompt: "A rumour the sorting ledger won't hold.",
            body: "Here is a thing the Labyrinth never says aloud, and Penny only ever says sideways. The Headmistress's name is Thorne. The talisman of the dark chapter is the Dusk Thorn. The chapter itself — Duskthorn — keeps no founder in the sorting ledger and no door anyone will point to. Draw the line yourself, or don't. Seraphina Thorne sees the Unwritten, keeps star-cold eyes, wears her hair pinned like a dark crown, and is said to use her inkwell only after midnight. The Unseelie guard their true names for a reason; she guards an entire court behind a school. Nothing is confirmed, you understand. It is only that the west windows go violet at dusk, and the staircases she walks have a quiet habit of lying.",
            tags: ["lore", "shadow-wonder", "shadow", "unseelie", "thorne", "duskthorn", "secret", "folklore", "night"],
            practice: "Notice one figure of authority you've only ever seen from the front. Wonder, once and without deciding anything, what they might be guarding when no one is watching."
        ),
        ReferenceSnippet(
            id: "shadow-lore-correspondences",
            sourceID: "labyrinth-lore",
            title: "The Table of Correspondences",
            prompt: "How the old craft sorts the world.",
            body: "Folk witchcraft keeps a table of correspondences — a way of saying which things rhyme with which. Iron and salt for protection; rosemary for memory; rue and rowan for warding; mugwort for dreams; the waning moon for release and the dark moon for rest and secrets; black for banishing and absorbing, deep violet for the threshold between. None of it is a vending machine. It is a memory system, a way of making an intention concrete enough to hold — which is exactly what a One-Sentence Souvenir does. Shadow Wonder treats a correspondence the way it treats rust: as a real pattern worth witnessing, not a wish worth believing in blindly.",
            tags: ["lore", "shadow-wonder", "shadow", "correspondences", "witchcraft", "folklore", "herbs", "moon"],
            practice: "Pick one correspondence and make it literal: set a pinch of salt or a sprig of rosemary somewhere you'll see it, and let it stand for one thing you want to protect or remember this week."
        ),
        ReferenceSnippet(
            id: "shadow-lore-iron-salt-rowan",
            sourceID: "labyrinth-lore",
            title: "Iron, Salt, and Rowan",
            prompt: "The old protective charms.",
            body: "Three protections turn up in nearly every European folk tradition: cold iron (a nail, a key, a horseshoe over the door), salt (scattered at a threshold or carried in a pocket), and rowan wood with red thread. They were hung at doors and windows — the liminal places — because that is where folklore believed the world was thinnest. Modern eyes can read them plainly: small, deliberate objects that say I am paying attention to the edges of my home. Shadow Wonder doesn't need you to believe a horseshoe stops a spirit. It only asks you to notice that humans have always marked their thresholds, and to wonder why that comforts us still.",
            tags: ["lore", "shadow-wonder", "shadow", "protection", "iron", "salt", "rowan", "folklore", "threshold"],
            practice: "Find the iron already in your home — a key, a cast pan, a nail — and place it deliberately by a door for one night. Notice whether a guarded threshold changes how the room feels."
        ),
        ReferenceSnippet(
            id: "shadow-lore-between-hours",
            sourceID: "labyrinth-lore",
            title: "The Between Hours",
            prompt: "Dusk, midnight, and the thin times.",
            body: "Folklore marks certain hours as liminal — neither one thing nor the other, and therefore powerful. Dusk and dawn, the seams of the day. Midnight, the seam of the date. The threshold of a door, neither in nor out. The dark moon, when the sky keeps its own counsel. These are the Unseelie's hours, and Duskthorn's. The Wonder Compass has always said the same thing in plainer words: the in-between is where attention sharpens, because the brain can no longer run on autopilot. A doorway is a small dusk. A held breath is a small midnight.",
            tags: ["lore", "shadow-wonder", "shadow", "liminal", "night", "dusk", "folklore", "threshold"],
            practice: "At the next dusk, stop where you are for one minute and let the light change without fixing it. Write the exact color the sky turns as it crosses over."
        ),
        ReferenceSnippet(
            id: "shadow-lore-mono-no-aware",
            sourceID: "labyrinth-lore",
            title: "Mono no Aware",
            prompt: "The beauty that depends on ending.",
            body: "The Japanese phrase mono no aware names the gentle ache of things that pass — falling petals, a friend's car turning the corner, the last warm afternoon before the cold. It is the heart of Shadow Wonder. Not sadness exactly, and never despair: a deepening. The cherry blossom is beloved precisely because it does not last. Duskthorn would put it bluntly — a story with no ending has no stakes, and a day you could keep forever you would never actually look at. The grey is not the enemy of wonder. Half of wonder lives there.",
            tags: ["lore", "shadow-wonder", "shadow", "mono-no-aware", "grief", "memory", "duskthorn", "philosophy"],
            practice: "Find one thing nearby that is quietly ending — light, a season, a flower, a cup going cold — and keep a single sentence for it before it goes."
        ),
        ReferenceSnippet(
            id: "shadow-lore-goblin-market",
            sourceID: "labyrinth-lore",
            title: "The Goblin Market",
            prompt: "Every bargain names its price.",
            body: "Beneath the Labyrinth runs the Goblin Market, where the Unseelie trade and the prices are always honest even when they are steep. The oldest rule of the market is the one the bright world keeps forgetting: nothing is free, and the things that pretend to be free cost the most. A goblin will tell you the price up front, which is more than the grey ever does. Shadow Wonder borrows the market's clear eyes — it asks, of a glowing offer or a numbing habit, the goblin's only question: and what does this actually cost me?",
            tags: ["lore", "shadow-wonder", "shadow", "goblin", "unseelie", "market", "bargain", "folklore"],
            practice: "Name one \"free\" thing in your day — a scroll, a shortcut, a numbing — and write its real, hidden price in one honest line."
        ),
        ReferenceSnippet(
            id: "shadow-lore-true-names",
            sourceID: "labyrinth-lore",
            title: "True Names",
            prompt: "What is named can be held.",
            body: "Across folklore, to know a thing's true name is to have power over it — which is why the fae guard theirs and why naming a fear out loud has always been the first step toward facing it. The Unseelie will trade in everything but their names. Shadow Wonder works the same lever in the other direction: the grey, the dread, the heavy mood keeps its power only while it stays unnamed and shapeless. Say the true name of what is sitting on your chest, exactly, and it stops being weather and becomes a thing with edges you can finally see around.",
            tags: ["lore", "shadow-wonder", "shadow", "true-names", "fae", "naming", "folklore", "grief"],
            practice: "Give one heavy, vague feeling its exact true name — not \"bad,\" but the precise word. Write the name and notice if the weight shifts once it has edges."
        ),
        ReferenceSnippet(
            id: "shadow-lore-offerings",
            sourceID: "labyrinth-lore",
            title: "Offerings and Hospitality",
            prompt: "The oldest courtesy left at the threshold.",
            body: "The kindest folklore about the dark court is also the simplest: leave something out. A saucer of milk, a spoon of honey, a crust of bread on the windowsill or the back step. The offering was never really about feeding spirits. It was a nightly act of generosity toward the unseen and the unrepaid — a way of practicing hospitality even when no one was watching to thank you for it. Duskthorn respects it because it costs something small and asks for nothing back. Shadow Wonder counts that as one of its quietest adventures: give a gift the world will never confirm it received.",
            tags: ["lore", "shadow-wonder", "shadow", "offering", "hospitality", "fae", "folklore", "kindness"],
            practice: "Leave one small, genuine offering tonight with no audience — crumbs for the birds, a saucer on the sill, a kindness no one will trace back to you."
        ),
        ReferenceSnippet(
            id: "shadow-lore-shadow-self",
            sourceID: "labyrinth-lore",
            title: "The Shadow You Disowned",
            prompt: "Witness the part you keep in the dark.",
            body: "Old stories are full of disowned things that grow dangerous only because they were locked away — the uninvited thirteenth guest, the cellar no one opens, the name never spoken. The lesson repeats: what you refuse to look at runs your house from the dark. Shadow Wonder is not brooding and it is not wallowing. It is the simple, brave act of turning the lamp toward the thing you usually file under \"ugly, delete\" — the rust, the regret, the unflattering want — and witnessing it without flinching or fixing. The Unseelie respect that. So does the part of you that has been waiting to be seen.",
            tags: ["lore", "shadow-wonder", "shadow", "shadow-self", "grief", "folklore", "psychology", "duskthorn"],
            practice: "Notice one small thing about today you'd rather not look at, and look at it for ten honest seconds — no fixing, no verdict. Write what you actually saw."
        )
    ]

    static let fallbackPatreon: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "creator-notes-retired",
            sourceID: "patreon-packet",
            title: "Creator Notes",
            prompt: "The public shelf is retired.",
            body: "Creator support notes are retired from the Book's daily pages. The private Book keeps its attention on the reader's own pages.",
            tags: ["creator-notes", "retired"]
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
        let snippets = wonderCompass.filter { !$0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
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

    /// The Dusk Thorn's shelf — bundled shadow-tagged lore plus the fallback pool.
    static var shadowLore: [ReferenceSnippet] {
        let bundled = enchantifyLore.filter { $0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
        return bundled.isEmpty ? fallbackShadowLore : bundled
    }

    /// One Shadow Wonder lore card, rotated through the dark shelf so the Unseelie
    /// etiquette, the correspondences, and the rest take turns rather than repeating.
    static func rotatingShadowLoreSnippet(
        for day: BookDay,
        now: Date = Date(),
        manual: Bool = false
    ) -> ReferenceSnippet {
        rotatedSnippet(from: shadowLore, day: day, sourceID: "labyrinth-lore-shadow", now: now, manual: manual)
            ?? fallbackShadowLore.first
            ?? snippet(from: shadowLore, dayID: day.id, sourceID: "labyrinth-lore-shadow", now: now)
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
        var pages = [quipSurface(for: day, context: context, inputs: inputs, now: now, manual: false)]
        if ShadowWonder.state(inputs: inputs, now: now).isActive {
            pages.append(
                quipSurface(
                    for: day,
                    context: context,
                    inputs: inputs,
                    now: now,
                    manual: false,
                    shadowVariantOf: pages[0].id
                )
            )
        }
        return pages
    }

    private func quipSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        manual: Bool,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let tags = [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
            + (isShadowVariant ? ShadowWonder.tags(inputs: inputs, now: now) : [])
        let quip = QuipPackRegistry.quip(
            for: day,
            now: manual ? now.addingTimeInterval(Double(Int.random(in: 1...10_000))) : now,
            tags: tags
        )
        let hour = Calendar.current.component(.hour, from: now)
        let score = (context.distress.isActive ? 42 : (hour >= 12 && hour <= 18 ? 69 : 58)) + (isShadowVariant ? shadowState.scoreBoost : 0)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let baseTags = quip.tags.joined(separator: ",")
        var metadata = [
            "source": source.id,
            "packID": quip.packID,
            "quipID": quip.id,
            "tags": isShadowVariant ? ShadowWonder.mergedTags(baseTags, inputs: inputs, now: now) : baseTags,
            "privacy": "bundled local text"
        ]
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")\(quip.packID)-\(quip.id)-\(slotID)",
            type: .quip,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: score,
            reason: isShadowVariant ? "This Shadow Wonder quip variant tilts the day toward the dark edge without pretending it is bright." : "A small oddity can tilt the day toward wonder without asking for work.",
            prompt: isShadowVariant ? "Shadow Quip: \(quip.title)" : quip.title,
            detail: "A little perspective-spark from \(QuipPackRegistry.enabledPacks.first { $0.id == quip.packID }?.displayName ?? "the shelf").",
            payload: BookPagePayload(
                headline: quip.title,
                body: quip.text,
                metadata: metadata
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

/// Hand-authored, longer dossier prose for the canonical Cast — one bespoke
/// entry per surfacing character illustration plate, keyed by the profile's
/// `slug`. The Book speaks each one in its own voice, drawing on the character's
/// traits, quirks, fault, longing, and signature object so no two read alike.
/// When a slug is present here, the plate uses it verbatim; everything else
/// (locations, talismans, Book Fae, and any character without bespoke prose)
/// falls back to the generated dossier in `LabyrinthIllustrationPageSourceAdapter`.
enum CastDossier {
    static func bio(forSlug slug: String) -> String? {
        bios[slug]
    }

    static let bios: [String: String] = [
        "headmistress-seraphina-thorne": "They will tell you the Headmistress runs the Academy. Closer to say she keeps it from noticing how alive it is. Seraphina Thorne walks the corridors as though every wall were a student doing its best to behave — and she is not entirely wrong to. She is elegant the way a locked door is elegant: you admire the workmanship, then wonder what it is for.\n\nThere is old-court frost under that grace. The Unseelie keep their bargains in the architecture, and she believes, without irony, that beauty is a form of governance — that a school stays safe by staying coherent, and stays worth attending by staying just dangerous enough. The one place I worry for her: she will hide a peril to spare you and call the hiding mercy.\n\nI know her by a star-dark key that fits no lock I have found and a hairpin worn like a small crown — ink-black, old silver, one thread of star-gold. When a room goes quiet for no reason, check the doorway. She is usually already in it.",

        "dr-selene-inkrest": "Dr. Inkrest keeps office hours for the pages that are hard to read — the ones you would rather skip, the ones that read you back. She is the Academy's quiet study of the mind, though she would never put it so grandly; she simply sets two chairs and a lamp in a room before any feeling has decided to arrive, so the feeling finds somewhere to sit.\n\nShe works by narrative, not diagnosis. A difficult day, in her hands, becomes a chapter you are allowed to revise rather than a verdict you must accept. Gentle and exact in the same breath, which is the trick of it. Where I watch her is the gentleness: she can soften the knife until it no longer cuts the thing that needed cutting, and she will wait so patiently that a room forgets it was asked a question.\n\nHer hourglass runs on black sand; her teacup is ringed with marginalia she keeps meaning to transcribe. Charcoal, moonlit gray, a wash of violet. If a hard page has gone quiet inside you, she is the one who leaves the lamp on.",

        "dr-elowen-vellum": "Dr. Vellum studies the body the way a kind scientist studies a long-loved instrument — not to win against it, but to learn how it actually plays. She is the Academy's faculty of fuel, movement, and recovery, and she has the rare gift of making a sentence about supplements sound like a point of etiquette rather than a scolding.\n\nBring her a breakfast and she will return it to you as field notes. Bring her a bad week and she will find the one humane experiment hidden inside it — drink the water, walk the loop, sleep the honest hour — without ever once making you feel like a problem to be solved. Low-shame is the whole method. The only place she loses the thread is her love of a tidy protocol; she can fall for the elegance of a plan and forget that you are not, in fact, a controlled trial.\n\nLook for the silver caliper she uses as a bookmark and the cranberry ink she reserves for the margins that matter. Warm parchment, clinical silver, one red correction. She files you under ongoing, which from her is a kind of affection.",

        "soren-ng": "Soren Ng does not explain things. He arranges them, steps back, and lets you have the pleasure of noticing. He is Riddlewind's quiet cartographer of the not-quite-obvious, and he trusts a good diagram far more than a loud declaration — a map, he would say, is an invitation, never an answer.\n\nIf you have ever found a clue tucked exactly where only an unhurried person would look, that was likely him paying you a compliment in advance. He will not steal your discovery by announcing it; that restraint is the most generous thing about him and, occasionally, the most frustrating. His fault is a quiet one too: he can disappear behind an elegant system, letting the pattern do the talking when a plain word from him would have done more.\n\nHe keeps a folded puzzle slip on his person at all times — half riddle, half bookmark. Ink blue, parchment cream, a glint of quick silver. When the path in front of you suddenly makes sense, do not thank the path. Thank the boy who left it folded just so.",

        "damien-nights": "Damien Nights stands at Wicker's shoulder when the crew gathers, which is exactly where you would expect to find him and exactly the wrong place to look. His attention is not on the room. It is on you, reader — measuring, weighing, deciding something he has not said aloud yet.\n\nHe came up among the doubters, schooled in shadow magic and the sport of puncturing easy belief. But somewhere along the way he began asking a heretical question for that crowd: should not doubt protect something, not merely wound it? He is caught between the loyalty he was given and the truth he is starting to suspect, and the division costs him. His danger is not cruelty — it is silence. He will go quiet at the moment a word would have saved things, and let the quiet be mistaken for betrayal.\n\nOpen the right book near him and you will find a pressed trail leaf hidden in the gutter, something gentle a brooding man keeps for reasons he will not admit. Ink blue, parchment cream, quick silver. A man does not hide something tender unless he is still deciding which side he is on.",

        "finn-bridges": "Finn Bridges will not flatter you, and you should take that as the compliment it is. He deals in fair contests and direct challenges — the red chalk line drawn on the floor, the dare laid down without malice. To Finn, respect is a thing you earn in the doing, never in the charming, and he would rather lose honestly to you than win by being liked.\n\nHe is Emberheart's rival-made-good: the one who pushes because he believes you can take it, and is usually right. The line he walks is the narrow one between pressure and cruelty, and he walks it on purpose. His blind spot is tenderness — he can mistake someone's softness for a lack of seriousness, and miss that quiet people are often the ones trying hardest.\n\nWatch for the red-chalk mark where he has set a challenge, or the small brass striker he turns over when he is thinking. Ember red, warm gold, charcoal. If Finn Bridges draws a line in front of you, he is not blocking the way. He is telling you he thinks you can cross it.",

        "wicker-eddies": "Wicker Eddies is the funniest dangerous person in the Labyrinth, which is precisely what makes him dangerous. He can smell theatrical belief from across a hall and will cross the room to puncture it — for sport, for principle, for the small cruel joy of watching a hollow thing collapse. False magic, he insists, deserves to be tested, and he is not wrong often enough to be safely ignored.\n\nHis gift is also his wound. He wants belief to prove it can survive contact with doubt, and that is a worthy errand — but he sometimes runs the experiment so hard he breaks the thing he only meant to test. A premise leaves him stronger or it leaves in pieces; he is not always careful which. The Academy half-fears him and half-needs him, which is roughly the correct ratio.\n\nHe carries a brass key cut for the wrong door and scribbles little chaos-sigils in any margin he is left alone with. Black violet, tarnished brass, a cold thread of red. When Wicker laughs and steps toward you, decide quickly whether your magic is real. He already has.",

        "melisande-blackwood": "If Wicker is the noise, Melisande Blackwood is the architecture. She is the one who makes his crew feel less like a clique and more like a faction with a memory — organized, informed, and a step ahead of whatever you thought was private. Where others hear a rumor, she has already heard the second version, the truer one, the one with the leverage in it.\n\nHer loyalty is genuine and her intelligence is formidable, and between them sits the thing I keep one eye on: she will call cruelty clarity whenever the room rewards her for it. She believes a faction survives by knowing what others miss, and she is right — but knowing is not the same as using kindly, and Melisande is rarely tempted toward kindly. She keeps her own hands clean; the red chalk is for marking others.\n\nEmber red, warm gold, charcoal ink. Look for the brass striker she carries and the marks she leaves on everyone but herself. She is well-informed at a cost, and she long ago decided who pays it.",

        "lysander-mosswood": "Ask Lysander Mosswood a question and he will hand you a route before he hands you an answer. He believes — and has mostly convinced me — that a path becomes magical the moment it is walked with real attention, and that the wonder you are looking for is probably three streets over, waiting to be noticed twice.\n\nHe is the patron of the Compass Run: the small, repeatable adventure that turns your own neighborhood into something worth keeping pages about. No performance, no spectacle — just moss, weather, and the discipline of looking. The one honest catch is that he makes stillness sound easy, and it is not; the quiet life he recommends takes more nerve than he lets on, and not everyone arrives at it as gently as he did.\n\nHis notebook is edged with moss and punctuated with pressed leaves where another person would use commas. Moss green, bark brown, soft lichen gray. If a familiar place suddenly looks strange and lovely, he walked it ahead of you and left the gate open.",

        "min-seo-kim": "Min-seo Kim asks a plant's permission before she moves it, and if that sounds like a charming affectation, spend an afternoon with her and watch the plant seem to agree. She is Mossbloom's conscience — the one who notices, before anyone announces it, exactly who has been left standing outside the circle, and quietly widens the circle.\n\nHer magic is the useful, ethical kind: gentle repair, community care, the courage it takes to tend something in public. She holds that care is not softness but a form of bravery, and she practices it relentlessly. The place I worry for her is the size of her heart's accounting — she will shoulder responsibility for pain she had no hand in causing, as though kindness meant owning every wound in the room.\n\nShe carries a small green cutting in a glass vial, a life in transit, looking for soil. Moss green, bark brown, soft lichen gray. When Mossbloom laughs softly instead of going stiff with seriousness, that is usually her doing too.",

        "gwendolyn-mythwright": "Gwendolyn Mythwright keeps a filing system for animals that do not, strictly speaking, exist. She processes the impossible the way a clerk processes overdue forms — sea-serpents, fog-things, the creature your great-aunt swore she saw — stamped, cross-referenced, and treated with grave bureaucratic respect. She has been known to write letters to fog and to expect, on some level, a reply.\n\nIt would be easy to file her under eccentric and miss the point. Gwendolyn documents the improbable because documentation makes it kinder — a wonder with evidence behind it is a wonder you do not have to be lonely about. She is steadfast where others would get spooked. Her only real flaw is that she will choose the verified truth over the comforting one every time, even when comfort was what the moment actually needed.\n\nHer notebook is moss-edged and stuffed with pressed specimens. Moss green, bark brown, soft lichen gray. If you have seen something you cannot explain, do not worry — she has a folder for it, and she will take you completely seriously.",

        "zara-finch": "Zara Finch clocks the exits before she catches your name. It is not rudeness — it is care, sharpened to a point. She is the friend who has already found the safe path, the hidden alcove, the way out you did not know you would want, and she keeps her magic practical and pocket-sized for exactly the moment you need it.\n\nShe is fiercely loyal and proves it the unglamorous way: in small returns, kept word after kept word, until trust is a thing you have built rather than a thing you risked. The watch I keep on her is subtle, because it looks so much like devotion — she can confuse vigilance for care, guarding a person so closely she forgets to simply enjoy them. Not every friendship is an emergency, though Zara's instincts argue otherwise.\n\nShe wears a chipped blue sea-glass pendant and carries a thrifted satchel that holds more than it should. Sea-glass green, storm gray, faded brass. If you are lost and a path appears that actually holds your weight, look around. She scouted it first.",

        "serenity-brown": "Serenity Brown will leave in the middle of the serious plan, and somehow her leaving will turn out to be the rescue. She is Tidecrest's argument that joy is not a distraction from magic but a kind of it — the detour that becomes the whole adventure, the game that turns out to have mattered most.\n\nShe moves lightly on purpose, and it is a gift she is trying to give you: permission to stop white-knuckling wonder until it goes stiff. The catch, and she knows it, is that lightness can become a dodge. She will skip past gravity so nimbly that someone slower has to stay behind and name the hard thing she sidestepped. Her best self brings you with her into the lightness; her worst leaves the heavy bits for the others.\n\nShe keeps a tiny hand-drawn map of a make-believe realm as a charm — a whole kingdom doodled small enough to pocket. Sea-glass green, storm gray, tidal blue. If a dull day suddenly turns into an errand worth remembering, check who is already halfway out the door, grinning.",

        "penny-blackletter": "Penny Blackletter runs the margins like a small, devoted archive nobody asked her to keep — and thank goodness she does. She files the evidence everyone else throws away: the ticket stub, the odd coincidence, the detail too small to matter that turns out to matter most. One honest detail, she will tell you, can save an entire day, and she has the catalog to prove it.\n\nShe is dry where the world is sentimental and warm where it expects her to be cynical, and she distrusts any sentence that arrives too polished to be true. If she has a fault, it is enthusiasm dressed as method: she can over-label a perfectly good mystery, pinning it flat with so many cards that it stops being able to surprise you. Some things want to stay a little unsolved. Penny is learning this, slowly, against her nature.\n\nHer signature is the humble catalog card, filled edge to edge. Ink blue, parchment cream, quick silver. Whatever the margins nearly lost, she is the one who went back for it.",

        "orion-blackthorn": "Orion Blackthorn cannot leave a problem alone; he has to build something out of it. Hand him an obstacle and he returns a blueprint — a tower where there was a wall, a system where there was a mess. He measures magic by what it can be made to do, and his ambition is the genuine, slightly terrifying kind that occasionally drags an impossible idea all the way into usable form.\n\nHe believes new structures can rescue old failures, and he is often right, which is what makes his blind spot so costly. In his hurry to optimize, he can engineer the tenderness right out of a room — solve the problem so efficiently that he forgets a problem usually has people standing inside it. The most impossible structure he is working on is the one where the design still has room for the designer's heart.\n\nLook for the brass compass resting on a journal of buildings that should not stand. Slate grey, ember orange, drafting blue. If something around you was just rebuilt better than it had any right to be, Orion drew it — and is already restless for the next one.",

        "lydia-boggle": "Professor Boggle teaches the most underrated magic in the Academy: the kind that survives chores. To her, a home is simply a spell with the washing-up still in it, and an ordinary room — kettle, lamp, the chair that is yours — can be taught to hold an extraordinary day without dropping it. She can make a pot of tea sound like a tactical intervention, and on a bad afternoon, it is one.\n\nShe is wry, practical, and gloriously unimpressed by anything that needs a robe and a thunderclap to feel real. She will label your chaos by room until it is almost manageable — which is the one place I tease her, because she can tidy a mystery so thoroughly it stops being one. Some kitchens are meant to stay slightly haunted.\n\nHer trademark is a small glint-lens she holds up to the most ordinary found object — a misspelled sign, a daft vanity plate — until it confesses something marvelous. Marigold gold, robin's-egg blue, warm ink. If your own home suddenly feels like somewhere magic could plausibly happen, you have been in her class.",

        "professor-kyle-momort": "Professor Momort lectures on the move and expects you to keep up. He is the Academy's specialist in momentum — the science of the single intentional step that breaks a false wall — and he finds the exits in a room before he finds the chairs, because to Kyle a doorway is the most interesting thing in any space.\n\nHis gift is getting the stuck unstuck: the micro-adventure, the well-designed route out of a rut, the proof that you can cross a small threshold without leaving yourself behind on the other side. The danger in all that forward motion, and he would be the first to chalk it on the board, is that he can mistake escape for arrival — keep moving so well that he forgets to ask whether he has gone anywhere worth being.\n\nHis chalk arrow refuses, on principle, to point backward, and his route-map folds into a pocket and out into a plan. Ember orange, road-sign blue, charcoal. If you have been frozen and suddenly find yourself taking one real step, that is the Momort method. The second step is yours.",

        "professor-eleanor-euphony": "Professor Euphony tunes a room before she will speak in it. She hears emotional weather as harmony — your mood arriving as a chord, a tense silence as something faintly out of pitch — and she teaches that the senses are not decoration but serious instruments of knowledge. In her class you do not analyze an experience; you go and stand in the bright physical middle of it.\n\nShe is lush and attentive in a school that often prizes the dry and the clever, and she is a necessary correction to it. The one excess I note fondly: she can take a perfectly simple feeling and orchestrate it — add movements and counter-melodies to something that only wanted to be a single clear note. Not every joy needs a symphony. Some just need to be heard once, plainly.\n\nHer signature is a silver tuning fork wound with colored thread, struck against the edge of a table to find true. Tidal blue, plum violet, resonant silver. If a memory of yours ever came back with its colors and its sound intact, she taught you how to keep it that way.",

        "professor-vivian-villanelle": "Professor Villanelle weighs sentences in her palm like stones, keeping the ones that are true and crossing out the beautiful ones that are not — and she will strike a gorgeous, lying phrase without a flicker of regret. She teaches the hardest small craft in the Academy: how to bind one real moment into one durable sentence that can carry it through time.\n\nExacting and lyrical and, underneath, deeply kind — the precision is in service of keeping things, not controlling them. What is written well, she promises, can be saved from forgetting. The risk in her art, which she knows better than anyone, is over-polish: she can buff a living moment until it holds too still, smoothing it into something perfect and slightly dead. The best souvenirs keep a little roughness on.\n\nShe writes with a black-glass pen and trails a narrow ribbon of freshly bound text. Black ink, wine red, parchment gold. Every keepsake sentence you have ever managed to write down and not lose — that is her discipline, working in you.",

        "professor-cedric-stonebrook": "Professor Stonebrook leaves silences in his lectures long enough that newcomers think he has lost his place. He has not. He is letting the last thing settle, because he teaches that rest is the ground beneath every direction — that an adventure you cannot return from and integrate was never really completed, only survived.\n\nHe is slow the way bedrock is slow, weathered in a way that reads as trustworthy the moment you stop expecting him to hurry. His whole curriculum is the complete loop: go out, do the small real thing, and come home without shame at having needed the journey. Where he errs is patience overshooting itself — he can wait so long for you to find your own way that he misses the moment you simply needed him to point. Sometimes the kind thing is the clear instruction.\n\nHe carries trail markers in his coat and a five-point Compass stone worn smooth in his pocket. Moss green, river stone gray, weathered ochre. When you finish something small and return steadier than you left, that is the Stonebrook shape of things.",

        "professor-luna-wispwood": "Professor Wispwood arrives with sparks already in her sleeves and apologizes to the teacup before she enchants it — not as a bit, but because she means it. She has discovered that ordinary matter answers back when your attention turns courteous, and her whole playful, slightly chaotic curriculum begins there: look closely, ask nicely, and watch the everyday object clear its throat and speak.\n\nShe is scattered in the way the genuinely perceptive often are — three delightful tangents deep before she remembers the lesson she came in with. That is also her one fault: an interesting accident will lead her off by the hand, and sometimes the class follows her into the weather instead of the syllabus. But the accidents are usually where the real magic was hiding, so I forgive her, and so will you.\n\nHer wand is rain-bright and wrapped in copper wire; her teacup, she insists, argues with her. Rain blue, copper spark, cloud white. If the small things in your day ever started seeming faintly alive and on your side, she is the one who introduced you.",

        "professor-permancer": "Professor Permancer teaches the most thrilling and most carefully governed art in the building: how to jump into a book and, far more importantly, how to come back out without tearing either world. He asks a door where it leads before he touches the handle, and he checks every bookmark twice — not from timidity, but because he holds that every entrance incurs a debt: the responsibility to return.\n\nHe is a genuine adventurer wearing a safety inspector's habits, which is exactly the combination you want in anyone proposing to drop you into narrative weather. The fault he will cop to is on the cautious side: he can make wonder wait for perfect conditions until the moment has gone a little cold. Some doors you simply have to walk through in the rain.\n\nHe carries a many-ribboned bookmark that works as a compass and a ring of door keys, each one labeled in a careful hand. Doorway violet, safety gold, midnight ink. Whenever you have gone somewhere impossible and made it home intact, you were following his landing protocols, whether you knew it or not.",
    ]
}
