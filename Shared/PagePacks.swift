import Foundation


// MARK: - Page Packs: pages as plugins

/// One page archetype supplied by a Page Pack — everything the curator and
/// renderer need, as data. New kinds of pages ship as pack JSON, not Swift.
struct PageArchetype: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var headline: String
    var detail: String
    var reason: String
    var bodyTemplate: String
    var score: Int = 56
    var cadenceHours: Int = 6
    var activeHours: [Int]?
    var renderStyleRaw: String?
    var symbolName: String = "puzzlepiece.extension"
    var tags: [String] = []
    var generation: GenerationSpec?

    struct GenerationSpec: Codable, Equatable {
        var instructions: String
        var promptTemplate: String
        var maxTokens: Int = 420
    }

    var renderStyle: BookPageRenderStyle {
        BookPageRenderStyle(rawValue: renderStyleRaw ?? "") ?? .promptCard
    }
}

struct PageArchetypePack: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var version: Int
    var author: String
    var availability: String
    var archetypes: [PageArchetype]

    var isLocked: Bool { availability == "locked" }
}

/// Fills `{placeholder}` slots in pack templates from live signals, so pack
/// pages can reference the player's real day without any pack-side code.
enum PageTemplateRenderer {
    static func render(
        _ template: String,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date()
    ) -> String {
        let moon = MoonPhaseCalendar.phase(on: now)
        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        let playerName = inputs.selfFacts.first { fact in
            fact.tags.contains("name") || fact.questionID.contains("name")
        }?.answer ?? "the reader"
        let lastKept = day.capturedPages.last.map { "\($0.type.title): \($0.userInput)" } ?? "nothing kept yet today"

        var rendered = template
        let substitutions: [String: String] = [
            "{weather}": inputs.weather?.phrase ?? "unrecorded weather",
            "{moon}": moon.name,
            "{moonLine}": moon.enchantedLine,
            "{timeOfDay}": timeOfDay,
            "{playerName}": playerName,
            "{keptCount}": "\(day.capturedPages.count)",
            "{lastKeptPage}": String(lastKept.prefix(200)),
            "{season}": AnchorRegistry.currentSeason(for: now)
        ]
        for (key, value) in substitutions {
            rendered = rendered.replacingOccurrences(of: key, with: value)
        }
        return rendered
    }
}

enum PageArchetypePackRegistry {
    static let userPackFileSuffix = ".reenchantedpack.json"

    /// Bundled packs: the free example pack plus locked purchasables whose
    /// content ships in the binary and unlocks via BookShop entitlement.
    static let bundledPacks: [PageArchetypePack] = [
        PageArchetypePack(
            id: "nocturne-folio",
            displayName: "The Nocturne Folio",
            version: 1,
            author: "The Goblin Index Empire",
            availability: "locked",
            archetypes: [
                PageArchetype(
                    id: "insomniacs-inventory",
                    title: "The Insomniac's Inventory",
                    headline: "Awake, Annotated",
                    detail: "A census of everything keeping watch with you.",
                    reason: "The small hours keep their own ledger.",
                    bodyTemplate: "It is deep {timeOfDay}, under a {moon}. You are awake; so are other things. Count what is keeping watch with you — the refrigerator's hum, a streetlight, one worried thought, the cat. List them in the margin. An inventory makes the night smaller and stranger company into actual company.",
                    score: 58,
                    cadenceHours: 24,
                    activeHours: [23, 0, 1, 2],
                    renderStyleRaw: "loreLetter",
                    symbolName: "moon.zzz",
                    tags: ["nocturne", "night", "insomnia", "ritual"]
                ),
                PageArchetype(
                    id: "dream-ledger",
                    title: "The Dream Ledger",
                    headline: "Before It Dissolves",
                    detail: "Dreams keep poorly. File the fragment now.",
                    reason: "Morning is the only window for this filing.",
                    bodyTemplate: "It is {timeOfDay}; whatever you dreamed is already evaporating at the edges. Write the fragment that remains in the margin — an image, a feeling, a sentence somebody said. Wrong details are fine; dreams are unreliable witnesses. The Ledger accepts all testimony.",
                    score: 56,
                    cadenceHours: 24,
                    activeHours: [5, 6, 7, 8],
                    renderStyleRaw: "promptCard",
                    symbolName: "cloud.moon",
                    tags: ["nocturne", "morning", "dream", "capture"]
                ),
                PageArchetype(
                    id: "last-light",
                    title: "Last Light",
                    headline: "What the Day Touched Leaving",
                    detail: "The Book names what the last daylight chose.",
                    reason: "Dusk files the day before night opens its own office.",
                    bodyTemplate: "The light is leaving. {moonLine} Open this page and the Book will name what today's last light touched on its way out.",
                    score: 60,
                    cadenceHours: 24,
                    activeHours: [16, 17, 18, 19],
                    renderStyleRaw: "loreLetter",
                    symbolName: "sun.haze",
                    tags: ["nocturne", "evening", "dusk"],
                    generation: PageArchetype.GenerationSpec(
                        instructions: "You are the Book inside ReEnchanted at dusk: unhurried, exact, a little nocturnal. Prose only.",
                        promptTemplate: "The weather today: {weather}. {moonLine} The player's day so far: {lastKeptPage}. Write 2 short paragraphs: first, name three plausible ordinary things the last daylight touched on its way out of the player's rooms and street (be specific, invent nothing impossible); second, name the first thing the night takes up instead, and what kind of night it intends to be. End with one short line inviting the player to add the thing the light actually touched, in the margin.",
                        maxTokens: 320
                    )
                )
            ]
        ),
        PageArchetypePack(
            id: "margins-and-mysteries",
            displayName: "Margins & Mysteries",
            version: 1,
            author: "The Book",
            availability: "bundledFree",
            archetypes: [
                PageArchetype(
                    id: "the-nothing-stirs",
                    title: "The Nothing Stirs",
                    headline: "A Grey Page",
                    detail: "Something has been quietly erased. The Book wants to write it back.",
                    reason: "At night, the Nothing tests the edges of kept days.",
                    bodyTemplate: "Late {timeOfDay}, under a {moon}. Somewhere in today's margins, one small detail has gone grey and silent — the Nothing has been chewing at it. Open this page and the Book will try to write it back before it fades.",
                    score: 48,
                    cadenceHours: 24,
                    activeHours: [21, 22, 23],
                    renderStyleRaw: "loreLetter",
                    symbolName: "circle.dotted",
                    tags: ["nothing", "night", "fourth-wall"],
                    generation: PageArchetype.GenerationSpec(
                        instructions: "You are the Book inside ReEnchanted, writing against the Nothing — the grey, silent force that erases unnoticed details. Quiet, a little eerie, finally warm. Prose only.",
                        promptTemplate: "The player's day so far: {lastKeptPage}. The weather: {weather}. {moonLine} Write 2 short paragraphs: first, name one small, plausible detail of such a day that the Nothing has almost erased (be specific but invent nothing impossible); second, write it back into the margins so it is kept. End with one sentence addressed directly to {playerName}: something true about why noticing matters tonight.",
                        maxTokens: 300
                    )
                ),
                PageArchetype(
                    id: "grey-margin",
                    title: "The Grey Margin",
                    headline: "Almost Taken",
                    detail: "Quiet days let the grey in. One sentence holds the line.",
                    reason: "The margins have been quiet, and the Nothing notices quiet.",
                    bodyTemplate: "The margins have been quiet for a little while — no shame in that; days do what days do. But the Nothing collects unnoticed time, and something from the quiet days has started going grey. Write one sentence about anything true from the last few days — a meal, a sound, a small errand — and it stays in the Book for good.",
                    score: 50,
                    cadenceHours: 12,
                    renderStyleRaw: "loreLetter",
                    symbolName: "circle.dotted",
                    tags: ["nothing", "return", "gentle"]
                ),
                PageArchetype(
                    id: "hearth-inventory",
                    title: "Hearth Inventory",
                    headline: "Three Survivors",
                    detail: "A tiny evening ritual: name what made it through the day with you.",
                    reason: "Evenings hold still long enough to count what stayed.",
                    bodyTemplate: "It is {timeOfDay}, {weather}. Name three things within arm's reach that survived the day with you. Objects count. Habits count. People count double. Write them in the margin and keep the page.",
                    score: 52,
                    cadenceHours: 24,
                    activeHours: [18, 19, 20],
                    renderStyleRaw: "promptCard",
                    symbolName: "flame",
                    tags: ["ritual", "evening", "gratitude"]
                )
            ]
        )
    ]

    /// User-imported packs: any `*.reenchantedpack.json` dropped into the
    /// app's Documents folder (Files app) becomes installed pages — the
    /// delivery seam future patron/paid packs will use.
    static func userPacks(fileManager: FileManager = .default) -> [PageArchetypePack] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        guard let contents = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        return contents
            .filter { $0.lastPathComponent.hasSuffix(userPackFileSuffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      var pack = try? decoder.decode(PageArchetypePack.self, from: data) else {
                    return nil
                }
                if pack.availability != "locked" {
                    pack.availability = "userImported"
                }
                return pack
            }
    }

    static func enabledPacks() -> [PageArchetypePack] {
        (bundledPacks + userPacks()).filter { !$0.isLocked || PackEntitlements.isUnlocked($0.id) }
    }

    static func archetypes() -> [PageArchetype] {
        var seen = Set<String>()
        return enabledPacks().flatMap(\.archetypes).filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Margin Tutor: first-touch explanations

/// One first-touch explanation, written in Zara Finch's voice. Shown once,
/// the first time the player touches the thing it describes.
struct MarginTutorNote: Identifiable, Equatable {
    var id: String
    var title: String
    var text: String
}

enum MarginTutorCatalog {
    static let notes: [MarginTutorNote] = [
        MarginTutorNote(
            id: "glow-menu",
            title: "Your Glow",
            text: "That sparkle is your Glow — the Belief you carry. In here you can give it to people, Pages, and things you want more of, take it back from what you want less of, or spend it on Spells. Attention is the currency of this place."
        ),
        MarginTutorNote(
            id: "seal-body",
            title: "The Body Seal",
            text: "This seal asks your phone how the body is carrying today. The numbers stay private on the device — the Book just translates them into weather it can write with."
        ),
        MarginTutorNote(
            id: "seal-weather",
            title: "The Weather Seal",
            text: "This seal reads your actual sky, then lets the Book enchant it. The real forecast stays legible underneath — we don't lie about rain here."
        ),
        MarginTutorNote(
            id: "seal-location",
            title: "The Location Seal",
            text: "This seal listens for Anchors — real places that hold rooms in the Outer Stacks. Stand somewhere unanchored and you can grow a brand new room from your own words. You have to actually be there. The Outer Stacks cannot be visited from the couch."
        ),
        MarginTutorNote(
            id: "keep-page",
            title: "Keeping a Page",
            text: "Kept. It lives in Today's Margins now, and tonight it becomes a thread in your Book of You. Keeping pages also brightens your Glow — the Book pays attention to attention."
        ),
        MarginTutorNote(
            id: "dismiss-surface",
            title: "Letting a Page Go",
            text: "Swiped away — the Book doesn't take it personally. Dismissed pages rest a while and may try again later. If a kind of page keeps overstaying its welcome, take Belief from it in the Glow menu."
        ),
        MarginTutorNote(
            id: "story-page",
            title: "Story Pages",
            text: "This scene is written from your real day. The choices are real forks: Slice of Life tends the day, Progress Arc moves the active thread, Surprise opens a side door. The cast remembers what you choose — for weeks."
        ),
        MarginTutorNote(
            id: "enchantment-page",
            title: "Enchantments",
            text: "Pick or take a photo, and the spell reads the real subject — only what the photo actually shows. Everything Speaks even lets the subject talk back. The camera is a wand here."
        ),
        MarginTutorNote(
            id: "flyleaf",
            title: "The Flyleaf",
            text: "Favors live here, five at most. Do the thing out in the real world, come back with one sentence of proof, and the asker will remember it — and trust you with stranger requests."
        ),
        MarginTutorNote(
            id: "compass-run",
            title: "Compass Runs",
            text: "A full run goes Notice, Embark, Sense, Write, Rest — constraints first, magic after. One small real adventure with a souvenir sentence at the end. Completing the loop earns 6 Belief."
        ),
        MarginTutorNote(
            id: "ask-the-book",
            title: "Asking the Book",
            text: "Ask anything. The Book answers as itself — short, a little animist, genuinely useful. Each exchange becomes a page you can keep or let drift."
        ),
        MarginTutorNote(
            id: "todays-margins",
            title: "Today's Margins",
            text: "Everything you keep today gathers here. Tap a kept card to step back inside the full illuminated page — kept pages stay alive, they don't become receipts."
        ),
        MarginTutorNote(
            id: "returned-stacks",
            title: "Returned From the Stacks",
            text: "Old kept pages wander back when the Book thinks they rhyme with today. The Stacks have long memories and decent taste."
        ),
        MarginTutorNote(
            id: "search-stacks",
            title: "Search the Stacks",
            text: "Everything you keep can be found again: pages, places, cast, favors, the library itself. Ask plainly — or strangely. The Stacks understand Glow tiers, moods, and names."
        ),
        MarginTutorNote(
            id: "colophon",
            title: "The Colophon",
            text: "The book's machinery lives down here — model status, charts, doorway settings. Every honest book admits how it was made; ours just keeps it in a drawer."
        )
    ]

    static func note(for id: String) -> MarginTutorNote? {
        notes.first { $0.id == id }
    }
}

enum MarginTutorLedger {
    static func seenIDs(from data: String) -> Set<String> {
        guard let bytes = data.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: bytes) else {
            return []
        }
        return Set(decoded)
    }

    static func encode(_ seen: Set<String>) -> String {
        guard let data = try? JSONEncoder().encode(seen.sorted()),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return encoded
    }
}

/// One portable save: everything a player has made, kept, tuned, or been
/// asked, independent of the app binary. Export it, move phones, import it.
struct ReEnchantedSaveFile: Codable {
    static let currentVersion = 1
    static let fileExtension = "reenchanted-save.json"

    var version: Int = ReEnchantedSaveFile.currentVersion
    var exportedAt: Date
    var days: [BookDay]
    var selfFacts: [SelfFact]
    var narrativeEvents: [NarrativeEvent]
    var entityMemories: [NarrativeEntityMemory]
    var facultyEntries: [FacultyEntry]
    var customCastMembers: [CustomCastMember]
    var anchors: [AnchorRecord]
    var electives: [UnwrittenElective]
    var beliefScore: Int
    var entityBeliefLedger: [String: Int]
    var pageBeliefLedger: [String: Int]
    var marginTutorSeen: [String]
    var didCompleteStoryOnboarding: Bool
    var sourcePreferences: [String: Bool]
    var constellations: [Constellation]?
    var wagers: [BookWager]?
    var themes: [BookTheme]?
    var clusters: [BookMotifCluster]?
    /// The full continuity digest at export time, so the wider Labyrinth
    /// (scene engine, NPC dialogue) can reference what the Book has noticed.
    var continuity: LiteraryContinuityDigest?
}

/// Tolerant JSON recovery for small-model output: extracts the object,
/// retries with smart-quote/trailing-comma cleanup, salvages single fields
/// from truncated text, and never lets raw braces reach the reader.
enum JSONSalvage {
    static func dictionary(from text: String) -> [String: Any]? {
        guard let extracted = extractObject(from: text) else { return nil }
        for candidate in [extracted, cleaned(extracted)] {
            if let data = candidate.data(using: .utf8),
               let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return raw
            }
        }
        return nil
    }

    static func string(_ key: String, in dictionary: [String: Any]) -> String? {
        guard let value = dictionary[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func capturedString(forKey key: String, in text: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[range])
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func plainProse(from response: String, fallback: String) -> String {
        let stripped = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty || stripped.hasPrefix("{") || stripped.hasPrefix("[") || stripped.contains("\"resultText\"") {
            return fallback
        }
        return stripped
    }

    private static func extractObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(text[start...end])
    }

    private static func cleaned(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: ",\\s*([}\\]])", with: "$1", options: .regularExpression)
    }
}

/// The single versioned container for everything the player has tuned or
/// earned outside the page archive: anchors, favors, Belief offsets, and
/// tutor progress. One file, one schema version, one migration story.
struct PlayerVaultData: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = PlayerVaultData.currentVersion
    var anchors: [AnchorRecord] = []
    var electives: [UnwrittenElective] = []
    var entityBelief: [String: Int] = [:]
    var pageBelief: [String: Int] = [:]
    var tutorSeen: [String] = []
    var surfaceHistory: [String: SurfaceHistoryRecord]?
    var ownedPacks: [String]?
    var currentArc: StoryArc?
    var lastCompletedArcThreadID: String?
    var constellations: [Constellation]?
    var wagers: [BookWager]?
    var themes: [BookTheme]?
    var fae: FaePlayerState?
    var pactWar: PactWarState?
    var relationshipField: [String: RelationshipTie]?
    var beliefEconomy: BeliefEconomyState?
    var bookJump: BookJumpState?
    var radio: RadioPlaybackState?
    /// Gemma-authored taste notes earned when the reader marks a braid "missed
    /// me." Each is one short second-person nudge folded into future braid
    /// prompts as reader-taught guidance. Capped to the most recent few.
    var learnedBraidNotes: [String]?
}

// MARK: - The BookShop
//
// The Goblin Index Empire runs the only commerce in the Labyrinth. The
// catalog describes what can be bound to a reader's save; entitlements are
// save data; the merchant (StoreKit or the dev counter) is an app concern.

struct BookShopListing: Identifiable, Codable, Equatable {
    enum Family: String, Codable, CaseIterable {
        case pagePack
        case storyForms
        case sparkPack
        case lorePack
        case marginaliaPack
        case soundPack
        case eventPack

        var shelfLabel: String {
            switch self {
            case .pagePack: return "Page Folios"
            case .storyForms: return "Story Looms"
            case .sparkPack: return "Wonder Tinder"
            case .lorePack: return "Lore Crates"
            case .marginaliaPack: return "Marginalia Sets"
            case .soundPack: return "Sound Bindings"
            case .eventPack: return "World Events"
            }
        }
    }

    enum SaleState: String, Codable, Equatable {
        case standard
        case liveEvent
        case archivedEvent
        case comingSoon

        var shelfLabel: String {
            switch self {
            case .standard: return "Available"
            case .liveEvent: return "Live Event"
            case .archivedEvent: return "Archived Event"
            case .comingSoon: return "Being Printed"
            }
        }
    }

    var id: String              // listing id
    var packID: String          // the content pack this unlocks
    var family: Family
    var title: String
    var goblinPitch: String     // the clerk's in-world sales line
    var contents: String        // honest plain description of what's inside
    var productID: String       // App Store Connect product identifier
    var comingSoon: Bool = false
    var saleState: SaleState? = nil

    var resolvedSaleState: SaleState {
        if comingSoon { return .comingSoon }
        return saleState ?? .standard
    }
}

enum BookShopCatalog {
    /// Everything the Goblins are willing to sell, ever listed here.
    /// Product IDs follow com.openclaw.enchantify.insidecover.pack.<packID>.
    static let listings: [BookShopListing] = [
        BookShopListing(
            id: "listing-nocturne-folio",
            packID: "nocturne-folio",
            family: .pagePack,
            title: "The Nocturne Folio",
            goblinPitch: "Pages that only wake after dark. The Empire acquired them from an estate sale it will not discuss.",
            contents: "Three night page archetypes: The Insomniac's Inventory, The Dream Ledger, and Last Light — plus night-tuned story sparks.",
            productID: "com.openclaw.enchantify.insidecover.pack.nocturne-folio"
        ),
        BookShopListing(
            id: "listing-saltwater-looms",
            packID: "saltwater-looms",
            family: .storyForms,
            title: "The Saltwater Looms",
            goblinPitch: "Story shapes woven from harbor rope. Tide-logic. The Goblins insist they are waterproof; the Goblins are lying.",
            contents: "Four coastal story forms and three genres: Lighthouse Keeper, Message in a Bottle, The Long Ferry.",
            productID: "com.openclaw.enchantify.insidecover.pack.saltwater-looms",
            comingSoon: true
        ),
        BookShopListing(
            id: "listing-gilded-margins",
            packID: "gilded-margins",
            family: .marginaliaPack,
            title: "The Gilded Margins",
            goblinPitch: "Illuminated scraps with actual gold in the ink, or so the invoice claims.",
            contents: "A full alternate marginalia set for Illuminated Photos: gilt frames, wax seals, pressed flowers.",
            productID: "com.openclaw.enchantify.insidecover.pack.gilded-margins",
            comingSoon: true
        ),
        BookShopListing(
            id: "listing-academy-night-band",
            packID: "academy-night-band",
            family: .soundPack,
            title: "Academy Night Band",
            goblinPitch: "Two after-hours stations recorded on equipment the Goblins claim was never stolen from the Broadcast Stair.",
            contents: "The Midnight Bindery and Goblin Market Jazz: two radio frequencies with local track slots, broadcast interludes, and live curation effects.",
            productID: "com.openclaw.enchantify.insidecover.pack.academy-night-band"
        ),
        BookShopListing(
            id: "listing-starlit-paper-trial-archive",
            packID: "starlit-paper-trial-archive",
            family: .eventPack,
            title: "The Starlit Paper Trial Archive",
            goblinPitch: "A past event, boxed carefully enough that the night can unfold again when you open it.",
            contents: "One archived world event with phases, fieldwork, lexical pressure, outcomes, and monthly-edition traces.",
            productID: "com.openclaw.enchantify.insidecover.pack.starlit-paper-trial-archive",
            saleState: .archivedEvent
        )
    ]

    static func listing(forPackID packID: String) -> BookShopListing? {
        listings.first { $0.packID == packID }
    }
}

/// Which locked packs this save owns. Checked by every content registry;
/// written only by the merchant after a verified purchase (or the dev
/// counter in internal builds).
enum PackEntitlements {
    nonisolated(unsafe) static var ownedPackIDs: Set<String> = []

    static func isUnlocked(_ packID: String) -> Bool {
        ownedPackIDs.contains(packID)
    }
}

// MARK: - The knock
//
// Knock on the cover (tap the banner) and the Book knocks back. Sometimes,
// instead, a note slides out from under the door. The notes know things.
enum BannerKnockNotes {
    static func note(
        greyLevel: Int,
        ascendantChapterName: String?,
        hour: Int,
        moonName: String,
        knocksThisSession: Int,
        roll: Int
    ) -> String {
        // The Book gets dry about persistence.
        if knocksThisSession >= 6 {
            return "Yes. Hello. The whole shelf can hear you."
        }
        if knocksThisSession >= 4 {
            return "We heard you the first several times. The Salamander lost its place."
        }
        // State-aware notes take priority when they apply.
        if greyLevel >= 2 {
            return "It has been quiet out there. The knock helps more than you know."
        }
        if moonName == "Full Moon", hour >= 20 || hour < 5 {
            return "Full moon tonight. Every margin is annotated. Knock louder."
        }
        if hour >= 23 || hour < 5 {
            return "Shhh. The Nocturne is in session. But yes — we're awake too."
        }
        if let chapter = ascendantChapterName, roll % 3 == 0 {
            return "The \(chapter) talisman says you knock like one of theirs."
        }
        let pool = [
            "Who taught you the knock?",
            "Password accepted. There was never a password.",
            "Three of us were asleep. The fourth says hello.",
            "The Margins are rearranging. Pardon our dust.",
            "We are between chapters in here. Come back at moonrise.",
            "The Goblins want to know if you're a customer or a draft.",
            "Penny says to tell you the filing is going well. Penny is lying.",
            "Knock twice more and we legally have to let the cat out.",
            "You found the door. Most readers only find the pages.",
            "It's warmer in here than it looks. Ink holds heat.",
            "The Dusk Thorn felt that. It pretended not to.",
            "Careful — the cover bruises like a pear."
        ]
        return pool[abs(roll) % pool.count]
    }
}
