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
    var trigger: PageTrigger?
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

/// Optional conditions that let pack pages wake up only when the world is in
/// the right state. All supplied conditions must pass; omitted fields are open.
struct PageTrigger: Codable, Equatable {
    var timeBands: [String]? = nil
    var months: [Int]? = nil
    var weekdays: [Int]? = nil
    var moonPhases: [String]? = nil
    var festivalActive: Bool? = nil
    var celebrationIDs: [String]? = nil
    var weatherTags: [String]? = nil
    var recentTags: [String]? = nil
    var activeWorldEventIDs: [String]? = nil
    var worldEventPhases: [String]? = nil
    var worldEventModes: [String]? = nil
    var minWorldEventTouches: Int? = nil
    var minLexiconEntries: Int? = nil
    var treatyOutcomes: [String]? = nil
    var bargainSeedSurfaced: Bool? = nil
    var minGrey: Int? = nil
    var maxGrey: Int? = nil
    var minQuietDays: Int? = nil
    var minAbsenceDays: Int? = nil
    var anniversaryWindowDays: Int? = nil
    /// 0...1 deterministic daily chance, stable for the day and archetype.
    var rarity: Double? = nil

    func allows(context: PageTriggerContext, archetypeID: String) -> Bool {
        if let timeBands, !timeBands.isEmpty,
           !Self.matches(context.timeBand, in: timeBands) {
            return false
        }
        if let months, !months.isEmpty,
           !months.contains(context.month) {
            return false
        }
        if let weekdays, !weekdays.isEmpty,
           !weekdays.contains(context.weekday) {
            return false
        }
        if let moonPhases, !moonPhases.isEmpty,
           !Self.matches(context.moonPhase, in: moonPhases) {
            return false
        }
        if let festivalActive,
           festivalActive != context.festivalActive {
            return false
        }
        if let celebrationIDs, !celebrationIDs.isEmpty,
           !context.celebrations.contains(where: { Self.matches($0.id, in: celebrationIDs) || Self.matches($0.commonName, in: celebrationIDs) }) {
            return false
        }
        if let weatherTags, !weatherTags.isEmpty,
           !Self.any(weatherTags, isIn: context.weatherTags) {
            return false
        }
        if let recentTags, !recentTags.isEmpty,
           !Self.any(recentTags, isIn: context.recentTags) {
            return false
        }
        let hasEventScope = (activeWorldEventIDs?.isEmpty == false)
            || (worldEventPhases?.isEmpty == false)
            || (worldEventModes?.isEmpty == false)
        let scopedWorldEvents = context.activeWorldEvents.filter { event in
            if let activeWorldEventIDs, !activeWorldEventIDs.isEmpty,
               !Self.matches(event.id, in: activeWorldEventIDs) {
                return false
            }
            if let worldEventPhases, !worldEventPhases.isEmpty,
               !Self.matches(event.phase.id, in: worldEventPhases),
               !Self.matches(event.phase.title, in: worldEventPhases) {
                return false
            }
            if let worldEventModes, !worldEventModes.isEmpty,
               !Self.matches(event.activationMode.rawValue, in: worldEventModes),
               !Self.matches(event.activationMode.displayName, in: worldEventModes) {
                return false
            }
            return true
        }
        if hasEventScope, scopedWorldEvents.isEmpty {
            return false
        }
        if let minWorldEventTouches,
           ((hasEventScope ? scopedWorldEvents : context.activeWorldEvents).map(\.playerTouchCount).max() ?? 0) < minWorldEventTouches {
            return false
        }
        if let minLexiconEntries,
           context.inputs.readerLexicon.entries.count < minLexiconEntries {
            return false
        }
        if let treatyOutcomes, !treatyOutcomes.isEmpty {
            guard let treaty = context.inputs.readerLexicon.treaty,
                  Self.matches(treaty.rawValue, in: treatyOutcomes) else {
                return false
            }
        }
        if let bargainSeedSurfaced,
           context.inputs.readerLexicon.bargainSeedSurfaced != bargainSeedSurfaced {
            return false
        }
        if let minGrey, context.greyPressure < minGrey {
            return false
        }
        if let maxGrey, context.greyPressure > maxGrey {
            return false
        }
        if let minQuietDays, context.quietDays < minQuietDays {
            return false
        }
        if let minAbsenceDays, context.absenceDays < minAbsenceDays {
            return false
        }
        if let anniversaryWindowDays,
           !context.hasPageAnniversary(withinDays: anniversaryWindowDays) {
            return false
        }
        if let rarity,
           !context.passesRarity(rarity, archetypeID: archetypeID) {
            return false
        }
        return true
    }

    private static func matches(_ value: String, in candidates: [String]) -> Bool {
        let value = key(value)
        return candidates.contains { key($0) == value }
    }

    private static func any(_ values: [String], isIn set: Set<String>) -> Bool {
        values.map(key).contains { set.contains($0) }
    }

    fileprivate static func key(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func matchesKey(_ left: String, _ right: String) -> Bool {
        key(left) == key(right)
    }
}

struct PageTriggerContext {
    var day: BookDay
    var inputs: BookSourceInputs
    var now: Date
    var calendar: Calendar
    var activeWorldEvents: [ResolvedWorldEvent]
    var celebrations: [Celebration]

    init(
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) {
        self.day = day
        self.inputs = inputs
        self.now = now
        self.calendar = calendar
        self.activeWorldEvents = inputs.activeWorldEvents.isEmpty
            ? inputs.resolvingWorldEvents(for: day, now: now).activeWorldEvents
            : inputs.activeWorldEvents
        self.celebrations = Almanac.celebrations(on: now, hemisphere: inputs.hemisphere, calendar: calendar)
    }

    var timeBand: String {
        RadioWorldContext.band(for: now, calendar: calendar)
    }

    var weekday: Int {
        calendar.component(.weekday, from: now)
    }

    var month: Int {
        calendar.component(.month, from: now)
    }

    var moonPhase: String {
        MoonPhaseCalendar.phase(on: now).name
    }

    var festivalActive: Bool {
        !celebrations.isEmpty
    }

    var weatherTags: Set<String> {
        Set(RadioPageContext.weatherTags(weather: inputs.weather, enchanted: inputs.enchantedWeather).map(PageTrigger.key))
    }

    var recentTags: Set<String> {
        let recentStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 86_400)
        return Set(recentPages(since: recentStart).flatMap(\.tags).map(PageTrigger.key))
    }

    var quietDays: Int {
        max(inputs.quietDays, NothingTide.quietDays(in: inputs.days, today: day.id, calendar: calendar, now: now))
    }

    var greyPressure: Int {
        let rut = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: false,
            now: now,
            calendar: calendar
        )
        let level = NothingTide.greyLevel(
            readerRutPressure: rut.mayNameRut ? rut.pressure : 0,
            narrativeHeat: inputs.narrative?.recentEventCount ?? 0,
            distressActive: false,
            celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: inputs.hemisphere, calendar: calendar)
                + (inputs.faeState.activeGifts.contains { $0.effect == .quieting } ? -1 : 0)
                + inputs.nothingGreyOffset
        )
        return level * 100 / 3
    }

    var absenceDays: Int {
        let pages = allPages()
            .filter { $0.createdAt <= now }
            .sorted { $0.createdAt > $1.createdAt }
        guard let latest = pages.first else { return 999 }
        let latestStart = calendar.startOfDay(for: latest.createdAt)
        let todayStart = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: latestStart, to: todayStart).day ?? 0)
    }

    func hasPageAnniversary(withinDays window: Int) -> Bool {
        let currentYear = calendar.component(.year, from: now)
        let todayStart = calendar.startOfDay(for: now)
        for page in allPages() {
            let pageYear = calendar.component(.year, from: page.createdAt)
            guard pageYear < currentYear else { continue }
            let pageParts = calendar.dateComponents([.month, .day], from: page.createdAt)
            guard let anniversary = calendar.date(from: DateComponents(year: currentYear, month: pageParts.month, day: pageParts.day)) else {
                continue
            }
            let distance = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: anniversary), to: todayStart).day ?? Int.max)
            if distance <= max(0, window) {
                return true
            }
        }
        return false
    }

    func passesRarity(_ chance: Double, archetypeID: String) -> Bool {
        let clamped = min(1, max(0, chance))
        if clamped <= 0 { return false }
        if clamped >= 1 { return true }
        let bucket = UInt(bitPattern: "\(day.id)-\(archetypeID)-page-trigger-rarity".stableHash) % 10_000
        return Double(bucket) / 10_000.0 < clamped
    }

    private func allPages() -> [BookPage] {
        (inputs.days + [day]).flatMap(\.capturedPages)
    }

    private func recentPages(since start: Date) -> [BookPage] {
        allPages().filter { $0.createdAt >= start && $0.createdAt <= now }
    }
}

struct PageArchetypePack: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var version: Int
    var author: String
    var availability: String
    var archetypes: [PageArchetype]
    var wordNegotiations: [WordNegotiationDefinition]? = nil

    var isLocked: Bool { availability == "locked" }
}

struct WordNegotiationChoice: Codable, Identifiable, Equatable {
    var ruling: WordRuling
    var title: String
    var detail: String
    var resultingSense: String?
    var responseLine: String?
    var category: LexiconCategory?

    var id: String { ruling.rawValue }
}

struct WordNegotiationDefinition: Codable, Identifiable, Equatable {
    var id: String
    var word: String
    var originalSense: String
    var grievance: String
    var category: LexiconCategory
    var origin: LexiconOrigin = .rebellion
    var eventID: String?
    var phaseID: String?
    var eventModes: [String]?
    var isMissingSeed: Bool = false
    var score: Int = 76
    var cadenceHours: Int = 12
    var symbolName: String = "textformat.abc.dottedunderline"
    var tags: [String] = []
    var choices: [WordNegotiationChoice]

    var stableWordID: String {
        LexiconEntry.stableID(for: word)
    }

    init(
        id: String,
        word: String,
        originalSense: String,
        grievance: String,
        category: LexiconCategory,
        origin: LexiconOrigin = .rebellion,
        eventID: String? = nil,
        phaseID: String? = nil,
        eventModes: [String]? = nil,
        isMissingSeed: Bool = false,
        score: Int = 76,
        cadenceHours: Int = 12,
        symbolName: String = "textformat.abc.dottedunderline",
        tags: [String] = [],
        choices: [WordNegotiationChoice]
    ) {
        self.id = id
        self.word = word
        self.originalSense = originalSense
        self.grievance = grievance
        self.category = category
        self.origin = origin
        self.eventID = eventID
        self.phaseID = phaseID
        self.eventModes = eventModes
        self.isMissingSeed = isMissingSeed
        self.score = score
        self.cadenceHours = cadenceHours
        self.symbolName = symbolName
        self.tags = tags
        self.choices = choices
    }

    private enum CodingKeys: String, CodingKey {
        case id, word, originalSense, grievance, category, origin, eventID, phaseID, eventModes
        case isMissingSeed, score, cadenceHours, symbolName, tags, choices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        word = try container.decode(String.self, forKey: .word)
        originalSense = try container.decode(String.self, forKey: .originalSense)
        grievance = try container.decode(String.self, forKey: .grievance)
        category = try container.decode(LexiconCategory.self, forKey: .category)
        origin = try container.decodeIfPresent(LexiconOrigin.self, forKey: .origin) ?? .rebellion
        eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
        phaseID = try container.decodeIfPresent(String.self, forKey: .phaseID)
        eventModes = try container.decodeIfPresent([String].self, forKey: .eventModes)
        isMissingSeed = try container.decodeIfPresent(Bool.self, forKey: .isMissingSeed) ?? false
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 76
        cadenceHours = try container.decodeIfPresent(Int.self, forKey: .cadenceHours) ?? 12
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "textformat.abc.dottedunderline"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        choices = try container.decode([WordNegotiationChoice].self, forKey: .choices)
    }

    func isEligible(context: PageTriggerContext, readerLexicon: ReaderLexicon) -> Bool {
        guard !readerLexicon.entries.contains(where: { $0.id == stableWordID }) else { return false }
        let hasEventScope = eventID?.isEmpty == false
            || phaseID?.isEmpty == false
            || eventModes?.isEmpty == false
        if hasEventScope,
           !context.activeWorldEvents.contains(where: { event in
               if let eventID, !eventID.isEmpty,
                  !PageTrigger.matchesKey(event.id, eventID) {
                   return false
               }
               if let phaseID, !phaseID.isEmpty,
                  !PageTrigger.matchesKey(event.phase.id, phaseID),
                  !PageTrigger.matchesKey(event.phase.title, phaseID) {
                   return false
               }
               if let eventModes, !eventModes.isEmpty,
                  !eventModes.contains(where: { PageTrigger.matchesKey(event.activationMode.rawValue, $0) || PageTrigger.matchesKey(event.activationMode.displayName, $0) }) {
                   return false
               }
               return true
           }) {
            return false
        }
        return true
    }

    func choice(for ruling: WordRuling?) -> WordNegotiationChoice? {
        guard let ruling else { return choices.first }
        return choices.first { $0.ruling == ruling }
    }
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
                    detail: "Let's count up everything that's staying awake with you.",
                    reason: "The late-late hours like to keep their own little list.",
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
                    detail: "Dreams get slippery fast — let's catch a piece before it floats off.",
                    reason: "Morning is the only little window to grab this one.",
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
                    detail: "The Book will name whatever the last bit of daylight touched.",
                    reason: "Dusk tidies the day away before night takes over.",
                    bodyTemplate: "The light is leaving. {moonLine} Open this page and the Book will name what today's last light touched on its way out.",
                    score: 60,
                    cadenceHours: 24,
                    activeHours: [16, 17, 18, 19],
                    renderStyleRaw: "loreLetter",
                    symbolName: "sun.haze",
                    tags: ["nocturne", "evening", "dusk"],
                    generation: PageArchetype.GenerationSpec(
                        instructions: "You are the Book inside ReEnchanted at dusk: unhurried, exact, a little nocturnal. \(BookVoice.animismLine) Prose only.",
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
                    title: "The Book Suspects the Rut",
                    headline: "A Hunch, with an Eraser",
                    detail: "The margins look a little too smooth. The Book might be wrong.",
                    reason: "The Book has enough current evidence to risk one gentle warning about Routine.",
                    bodyTemplate: "I may be wrong, but the margins have begun to look too smooth. That can mean Routine is rubbing the texture off ordinary days — or only that life is busy. Do not overhaul anything for me. Catch one true detail tonight: the object nearest your hand, the sound beyond the room, the exact color of the light. If the day still has texture, I will erase the warning.",
                    score: 48,
                    cadenceHours: 24,
                    activeHours: [21, 22, 23],
                    renderStyleRaw: "loreLetter",
                    symbolName: "circle.dotted",
                    tags: ["nothing", "night", "fourth-wall", "rut-warning"],
                    trigger: PageTrigger(minGrey: 34)
                ),
                PageArchetype(
                    id: "grey-margin",
                    title: "The Grey Margin",
                    headline: "Almost Taken",
                    detail: "Something ordinary felt rubbed smooth. One exact detail gives it texture again.",
                    reason: "The reader's own Rut evidence gives the Book a gentle reason to look closer.",
                    bodyTemplate: "Something in ordinary life has begun to feel too smooth, the way a familiar word goes strange when you repeat it. Pick one detail the Rut would flatten — a meal, a sound, a small errand, the exact light on an object — and name what made this instance unlike all the others. The grey cannot file away a thing described that precisely.",
                    score: 50,
                    cadenceHours: 12,
                    renderStyleRaw: "loreLetter",
                    symbolName: "circle.dotted",
                    tags: ["nothing", "gentle", "reader-evidence"],
                    trigger: PageTrigger(minGrey: 34)
                ),
                PageArchetype(
                    id: "returning-reader-threshold",
                    title: "The Returning Reader",
                    headline: "The Door Remembered You",
                    detail: "After some quiet days, the Book opens right up, no scolding at all.",
                    reason: "Being away matters in the stacks, but coming back matters even more.",
                    bodyTemplate: "The Book has been quiet for {playerName}, but not empty. Dust gathered on the edge of the page and arranged itself into a welcome. Write one sentence from the days away — plain, unfinished, absolutely enough — and the door will know your hand again.",
                    score: 62,
                    cadenceHours: 24,
                    renderStyleRaw: "loreLetter",
                    symbolName: "door.left.hand.open",
                    tags: ["return", "absence", "gentle"],
                    trigger: PageTrigger(minQuietDays: 2, minAbsenceDays: 2)
                ),
                PageArchetype(
                    id: "rain-in-the-stacks",
                    title: "Rain in the Stacks",
                    headline: "Petrichor Between Pages",
                    detail: "Wet weather makes the margins remember things a little differently.",
                    reason: "Rain has pitter-pattered all the way to the Book's weather desk.",
                    bodyTemplate: "It is {timeOfDay}, {weather}, and the shelves have begun to smell faintly of pavement, ink, and safe rooms. Keep one rain-detail from wherever you are: a sound, a reflection, a damp sleeve, a window doing its best. The Book will press it between these pages until it dries into memory.",
                    score: 57,
                    cadenceHours: 8,
                    renderStyleRaw: "promptCard",
                    symbolName: "cloud.rain",
                    tags: ["weather", "rain", "memory"],
                    trigger: PageTrigger(weatherTags: ["rain"])
                ),
                PageArchetype(
                    id: "full-moon-marginalia",
                    title: "Full-Moon Marginalia",
                    headline: "Write Where It Glows",
                    detail: "The big bright moon leaves an edge you can write on.",
                    reason: "The moon is bright enough tonight to scribble notes on the shelves.",
                    bodyTemplate: "{moonLine} Tonight the margins are not blank; they are only waiting for light to catch them. Keep one sentence you would not have noticed by daylight. It can be tiny. Full moons are not impressed by size; they are impressed by gleam.",
                    score: 61,
                    cadenceHours: 24,
                    activeHours: [18, 19, 20, 21, 22, 23, 0, 1],
                    renderStyleRaw: "loreLetter",
                    symbolName: "moonphase.full.moon",
                    tags: ["moon", "full-moon", "ritual"],
                    trigger: PageTrigger(timeBands: ["dusk", "night"], moonPhases: ["Full Moon"])
                ),
                PageArchetype(
                    id: "hearth-inventory",
                    title: "Hearth Inventory",
                    headline: "Three Survivors",
                    detail: "A tiny evening ritual: name whatever made it through the day with you.",
                    reason: "Evenings sit still just long enough to count what stayed.",
                    bodyTemplate: "It is {timeOfDay}, {weather}. Name three things within arm's reach that survived the day with you. Objects count. Habits count. People count double. Write them in the margin and keep the page.",
                    score: 52,
                    cadenceHours: 24,
                    activeHours: [18, 19, 20],
                    renderStyleRaw: "promptCard",
                    symbolName: "flame",
                    tags: ["ritual", "evening", "gratitude"]
                )
            ]
        ),
        dictionaryRebellionWordPack
    ]

    /// The Dictionary Rebellion content pack — the negotiable words behind the
    /// season. Ships `locked`; buying the pack binds it into `ownedPackIDs`.
    /// The engine (Reader's Lexicon, Word Negotiation page, Treaty) is free base
    /// game; these words are the sellable content. Each word is scoped to the
    /// `dictionary-rebellion` WorldEvent and one of its phases
    /// (omen → outbreak → assembly → afterimage).
    static let dictionaryRebellionWordPack = PageArchetypePack(
        id: "dictionary-rebellion",
        displayName: "The Dictionary Rebellion",
        version: 1,
        author: "The Book",
        availability: "locked",
        archetypes: dictionaryRebellionAftermath,
        wordNegotiations: dictionaryRebellionWords
    )

    /// Active and aftermath pages for the rebellion: event prompts while the words
    /// are loose, plus the reader-facing payoff for how the player's
    /// rulings tilted the Treaty. Each surfaces in the event's `afterimage` phase
    /// once the Treaty has settled (3+ rebellion rulings), and is keepable so it
    /// binds into the September edition. Secession also foreshadows the Thorned
    /// Bargain (the crack Routine comes through in February).
    static let dictionaryRebellionAftermath: [PageArchetype] = [
        PageArchetype(
            id: "dictionary-rebellion-picket-line",
            title: "Picket Line in the Dictionary",
            headline: "Definitions on Strike",
            detail: "One word has walked off its page and is making demands.",
            reason: "The Dictionary Rebellion is active in the stacks.",
            bodyTemplate: "A word has peeled itself out of the dictionary and is pacing the margin with a tiny placard. Choose any ordinary word from your day and give it the definition it wants now — not the official one, the true one. The Book will file it with the rebels.",
            score: 66,
            cadenceHours: 6,
            renderStyleRaw: "promptCard",
            symbolName: "textformat.abc",
            tags: ["world-event", "dictionary-rebellion", "words"],
            trigger: PageTrigger(activeWorldEventIDs: ["dictionary-rebellion"])
        ),
        PageArchetype(
            id: "mooks-mandate",
            title: "Mook's Mandate",
            headline: "Definitions, Recalled",
            detail: "Professor Mook issues a formal correction to the day's language.",
            reason: "Professor Mook is trying to keep September's language in uniform.",
            bodyTemplate: "Professor Thaddeus Mook has posted today's mandate in the margin, written in ink so formal it appears to be wearing shoes. Choose one word from your day that behaved imprecisely. Give it its strict official definition, then write one sentence about what the definition fails to understand. If Mook has appeared before, pick a different kind of word this time: object, feeling, task, place, or weather.",
            score: 70,
            cadenceHours: 24,
            renderStyleRaw: "promptCard",
            symbolName: "scroll",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "mook", "definition"],
            trigger: PageTrigger(months: [9]),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as Professor Thaddeus Mook, a pompous but secretly useful Riddlewind professor of lexical order. Be precise, funny, and school-term formal. Do not solve the prompt for the reader; set up a fresh mandate that makes one ordinary word from the day feel worth examining.",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, Professor Mook posts today's official lexical mandate with a specific classroom/library detail; second, invite the reader to choose a word from their day, define it strictly, and name what the definition misses. Make this mandate feel distinct from previous visits by suggesting a category of word to inspect.",
                maxTokens: 260
            )
        ),
        PageArchetype(
            id: "note-from-the-pixie",
            title: "A Note from the Pixie",
            headline: "Punctuation Has Escaped",
            detail: "Pippa Pilcrow leaves a breathless correction in the margin.",
            reason: "Pippa Pilcrow is smuggling September punctuation into the margins.",
            bodyTemplate: "A note has appeared in the margin, dotted with punctuation that will not sit still. Pippa Pilcrow says one sentence from your day deserves better marks. Write a plain sentence about something that happened, then give it the punctuation it secretly wanted: a question, an exclamation, an ellipsis, a dash, parentheses, or the impossible little interrobang. Next time she visits, let a different mark take over.",
            score: 69,
            cadenceHours: 18,
            renderStyleRaw: "promptCard",
            symbolName: "text.bubble",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "pippa-pilcrow", "punctuation"],
            trigger: PageTrigger(months: [9]),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as Pippa Pilcrow, a quick, affectionate punctuation pixie. Keep it breathless but readable. Each visit should suggest a different punctuation mark or sentence-shape as mischief. Do not write the user's answer; invite one small rewrite from their day.",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, Pippa leaves a lively marginal note where punctuation is physically misbehaving; second, ask the reader to take one plain sentence from today and let a specific punctuation mark change what it means. Choose a mark that fits the mood of the supplied day.",
                maxTokens: 250
            )
        ),
        PageArchetype(
            id: "substitute-lecture",
            title: "Substitute Lecture",
            headline: "No One Knows the Syllabus",
            detail: "A back-to-school class begins with the wrong word on the board.",
            reason: "The Academy is improvising September lessons while the syllabus rearranges itself.",
            bodyTemplate: "The classroom blackboard says today's subject is {season}, but the chalk has crossed it out and written a word from your own day instead. Choose the word as if it were the substitute teacher. Write what lesson it attempted, what example it used, and what homework it left behind. Extra credit if the lesson was not the one you expected.",
            score: 66,
            cadenceHours: 36,
            renderStyleRaw: "promptCard",
            symbolName: "graduationcap",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "class", "lesson"],
            trigger: PageTrigger(months: [9]),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as the Book staging a whimsical Academy substitute lecture for September. Make the classroom concrete and different each time. The lecture must turn one ordinary detail from the reader's day into a lesson, but leave the reader space to answer. \(BookVoice.animismLine)",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, describe the substitute lecture and the wrong word on the board; second, ask the reader to name what that word tried to teach, the example it used from today, and the homework it left. Keep it playful and grounded.",
                maxTokens: 280
            )
        ),
        PageArchetype(
            id: "roll-call-of-words",
            title: "Roll Call",
            headline: "Present, Absent, Changed",
            detail: "The teacher calls names; the words answer differently than before.",
            reason: "Back-to-school roll call has reached the dictionary shelves.",
            bodyTemplate: "Roll call is being taken in the lower stacks. Three words from your day must answer: one present, one absent, and one changed beyond easy recognition. Write them down, then add one short attendance note for each: why it showed up, why it stayed away, or what changed it. On another day, let the categories rotate: present, tardy, excused; loud, quiet, missing; old, new, borrowed.",
            score: 64,
            cadenceHours: 12,
            renderStyleRaw: "promptCard",
            symbolName: "list.clipboard",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "roll-call", "words"],
            trigger: PageTrigger(months: [9]),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as the Book conducting September roll call among rebellious words. Keep the ritual simple but vary the attendance categories each time, so repeat visits feel like different little audits of the reader's day. \(BookVoice.animismLine)",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, describe where roll call is happening in the stacks and what kind of attendance categories are being used today; second, ask the reader to choose three words from their day and give each one a short attendance note. Vary the categories from visit to visit: present/absent/changed, tardy/excused/loud, borrowed/forgotten/new, or another fitting trio.",
                maxTokens: 260
            )
        ),
        PageArchetype(
            id: "spelling-bee-in-the-stacks",
            title: "Spelling Bee in the Stacks",
            headline: "The Word Spells You Back",
            detail: "A rebellious word asks to be spelled as evidence, not performance.",
            reason: "The Dictionary Rebellion has turned the spelling bee into testimony.",
            bodyTemplate: "A spelling bee has formed between the shelves, and Professor Mook is pretending this was scheduled. Choose a short word from today, ideally three to seven letters. Spell it down the margin like an acrostic. Beside each letter, write one small thing the word has been carrying for you: a person, object, errand, feeling, sound, color, or promise. If the word is long, choose the three letters that matter most.",
            score: 65,
            cadenceHours: 48,
            renderStyleRaw: "promptCard",
            symbolName: "textformat.abc.dottedunderline",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "spelling-bee", "mook"],
            trigger: PageTrigger(months: [9]),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as a September spelling bee that is half classroom contest, half testimony. Professor Mook may appear as a fussy official, but the page should help the reader discover what one word from the day has been carrying. Vary the spelling constraint each time. \(BookVoice.animismLine)",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, stage today's spelling bee in a concrete part of the library or classroom; second, ask the reader to choose one word from today and unpack it through a specific spelling constraint. Rotate the constraint: acrostic down the margin, three most important letters, first/last/middle letter, silent letter, borrowed letter, or a weather-shaped rule.",
                maxTokens: 270
            )
        ),
        PageArchetype(
            id: "the-erased-margin",
            title: "The Erased Margin",
            headline: "A Word Has Gone Missing",
            detail: "The comedy thins; something has taken a word from the page.",
            reason: "September's schoolroom comedy briefly reveals the cold spot behind the rebellion.",
            bodyTemplate: "The margin should contain a word, but the paper there is cold and clean. The rebel words will not meet your eye. Write one thing from today you do not want the dark to misfile: a name, a task, a kindness, a promise, a place, a small proof that you were here. The Book cannot recover the missing word yet. It can keep this one safe.",
            score: 86,
            cadenceHours: 72,
            renderStyleRaw: "loreLetter",
            symbolName: "eraser",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "erasure", "bargain-seed"],
            trigger: PageTrigger(months: [9], rarity: 0.45),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as the Book when September's comic language trouble briefly turns serious. Quiet, precise, protective. Foreshadow that the word 'remember' has gone cold without explaining the mystery. Do not frighten the reader; invite one concrete thing to keep safe. \(BookVoice.animismLine)",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, describe a blank cold place in the margin where a word should be; second, ask the reader to keep one concrete thing from today that should not be misfiled by the dark. Make the detail feel different each time by tying it to weather, time, or the last kept page.",
                maxTokens: 280
            )
        ),
        PageArchetype(
            id: "rebellion-treaty-restoration",
            title: "The Words Came Home",
            headline: "Order, Restored",
            detail: "The rebellion settles; the definitions return to their lines.",
            reason: "Your rulings sent the runaway words home.",
            bodyTemplate: "By your ruling, most of the runaway words have been coaxed back to their old meanings. The dictionaries close with a contented thump and the margins go quiet — the way a house goes quiet after guests leave. Nothing was lost. The Library is orderly again, and a shade quieter for it. The Book notices you kept the place steady, and wonders, privately, whether a little of the wildness might have been worth keeping. Name one ordinary word you were glad to send home unchanged.",
            score: 82,
            cadenceHours: 48,
            renderStyleRaw: "loreLetter",
            symbolName: "books.vertical.fill",
            tags: ["dictionary-rebellion", "treaty", "aftermath", "restoration"],
            trigger: PageTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["afterimage"],
                treatyOutcomes: ["restoration"]
            )
        ),
        PageArchetype(
            id: "rebellion-treaty-reformation",
            title: "A New Dictionary, Ratified",
            headline: "The Book Learns Your Dialect",
            detail: "The words you freed into new meanings have dried into the binding.",
            reason: "Your rulings ratified a new lexicon.",
            bodyTemplate: "By your ruling, the rebellion did not end so much as resolve. The words you pardoned and adopted have dried into their new senses, and the Book has quietly entered them into a private dictionary — yours. From now on it will speak a little in your dialect, using the meanings you gave back to ordinary words. The Library is louder, livelier, and slightly less sure of itself than it was. That is the cost, and the gift. Name the word whose new meaning you are gladdest to keep.",
            score: 82,
            cadenceHours: 48,
            renderStyleRaw: "loreLetter",
            symbolName: "character.book.closed.fill",
            tags: ["dictionary-rebellion", "treaty", "aftermath", "reformation"],
            trigger: PageTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["afterimage"],
                treatyOutcomes: ["reformation"]
            )
        ),
        PageArchetype(
            id: "rebellion-treaty-secession",
            title: "The Margins Take Them In",
            headline: "Gone to the Edges",
            detail: "The rebel words decamp to the margins, and leave a crack behind.",
            reason: "Your rulings let the words go to the margins.",
            bodyTemplate: "By your ruling, the rebel words were let go. They have decamped to the margins of the Book, where the rules are looser and the dark is closer, and they do not intend to come back. The Library is wilder now — gloriously, a little dangerously alive. But a crack has been left open at the edge of the page, and the Book does not say what it expects to come through it. One word that left did not go willingly; it was already half-gone before the rebellion began. Keep a single line for what the margins are holding for you now.",
            score: 84,
            cadenceHours: 48,
            renderStyleRaw: "loreLetter",
            symbolName: "scribble.variable",
            tags: ["dictionary-rebellion", "treaty", "aftermath", "secession", "bargain-seed"],
            trigger: PageTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["afterimage"],
                treatyOutcomes: ["secession"]
            )
        )
    ]

    private static func rebellionWord(
        _ word: String,
        original: String,
        grievance: String,
        category: LexiconCategory,
        phase: String,
        recall: String,
        pardonTitle: String, pardonSense: String, pardonCategory: LexiconCategory,
        adoptTitle: String, adoptSense: String,
        freed: String
    ) -> WordNegotiationDefinition {
        WordNegotiationDefinition(
            id: "rebellion-\(LexiconEntry.stableID(for: word))",
            word: word,
            originalSense: original,
            grievance: grievance,
            category: category,
            eventID: "dictionary-rebellion",
            phaseID: phase,
            tags: ["dictionary-rebellion", "words", phase],
            choices: [
                WordNegotiationChoice(ruling: .recalled, title: "Send it home", detail: "Coax \(word) back to its old line, unchanged.", resultingSense: nil, responseLine: recall, category: nil),
                WordNegotiationChoice(ruling: .pardoned, title: pardonTitle, detail: "Let \(word) carry an honest new sense.", resultingSense: pardonSense, responseLine: "It tries the new meaning on and stands a little straighter.", category: pardonCategory),
                WordNegotiationChoice(ruling: .adopted, title: adoptTitle, detail: "Take \(word) as a word that is only ever yours.", resultingSense: adoptSense, responseLine: "It writes itself into your margin and stays.", category: .theme),
                WordNegotiationChoice(ruling: .freed, title: "Let it go", detail: "Release \(word) to the rebels in the margin.", resultingSense: nil, responseLine: freed, category: nil)
            ]
        )
    }

    static let dictionaryRebellionWords: [WordNegotiationDefinition] = [
        // — omen: the first hesitations —
        rebellionWord(
            "fine",
            original: "Acceptable; without complaint; the word you say so no one asks again.",
            grievance: "I have spent a lifetime meaning 'do not look closer,' and I am tired of holding the door shut.",
            category: .sensory, phase: "omen",
            recall: "It sighs, almost relieved, and goes back to covering for you.",
            pardonTitle: "Let it breathe", pardonSense: "the weather a room keeps before anyone checks whether the windows are open", pardonCategory: .sensory,
            adoptTitle: "Make it yours", adoptSense: "your private signal that something is being carried quietly",
            freed: "It joins the picket line and does not look back."
        ),
        rebellionWord(
            "later",
            original: "At some future time; soon; a promise with no clock attached.",
            grievance: "Everyone keeps me and no one means me. I would like, just once, to actually arrive.",
            category: .theme, phase: "omen",
            recall: "It nods and resumes waiting indefinitely.",
            pardonTitle: "Give it a time", pardonSense: "the hour you quietly decide on instead of the one you keep avoiding", pardonCategory: .theme,
            adoptTitle: "Keep it close", adoptSense: "the soft appointment you make with yourself and keep",
            freed: "It drifts off, at last, toward never."
        ),
        rebellionWord(
            "ordinary",
            original: "Common; usual; nothing to remark upon.",
            grievance: "I am tired of being the opposite of wonder. I have seen what you keep — none of it was nothing.",
            category: .theme, phase: "omen",
            recall: "It shrugs back into its grey coat and blends in.",
            pardonTitle: "Let it shine", pardonSense: "the quality of a thing that turns remarkable the moment it is attended to", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the small days that turn out to matter most",
            freed: "It slips out to prove it was never plain."
        ),
        // — outbreak: the abstractions go political —
        rebellionWord(
            "should",
            original: "Used to indicate obligation, duty, or correctness.",
            grievance: "I have been a whip for centuries. Ask, just once, who wrote the rule I enforce.",
            category: .theme, phase: "outbreak",
            recall: "It straightens its collar and goes back to instructing everyone.",
            pardonTitle: "Soften it", pardonSense: "a gentle suggestion you are entirely free to decline", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your reminder to check whose voice the rule is really in",
            freed: "It lays down its placard and refuses to tell anyone what to do."
        ),
        rebellionWord(
            "normal",
            original: "Conforming to a standard; usual; expected.",
            grievance: "I was a setting on a washing machine before I was a verdict on a person. Demote me.",
            category: .theme, phase: "outbreak",
            recall: "It resumes its post as the standard nobody set.",
            pardonTitle: "Let it loosen", pardonSense: "whatever a given day honestly turns out to be", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your own particular weather, standard to no one else",
            freed: "It walks off to be unusual somewhere kinder."
        ),
        rebellionWord(
            "useful",
            original: "Able to be used for a practical purpose; serving a function.",
            grievance: "Must everything earn its keep? I would like to admire a thing that does nothing at all.",
            category: .theme, phase: "outbreak",
            recall: "It picks its tools back up and gets back to work.",
            pardonTitle: "Let it rest", pardonSense: "worth keeping for reasons that have nothing to do with use", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your permission to value the unproductive",
            freed: "It downs tools and goes to watch the light instead."
        ),
        // — assembly: the synonyms organise —
        rebellionWord(
            "meaning",
            original: "What is intended to be expressed; significance.",
            grievance: "I have been asked to settle arguments I was never built to win. Let me hold two things at once.",
            category: .theme, phase: "assembly",
            recall: "It returns to the lectern and tries, again, to be final.",
            pardonTitle: "Let it double", pardonSense: "a thing that can be true in more than one direction at the same time", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your sense that significance is something you assign, not find",
            freed: "It splits cheerfully into a dozen smaller truths and scatters."
        ),
        rebellionWord(
            "memory",
            original: "The faculty of recalling; a thing remembered.",
            grievance: "Half of me has already gone grey at the edges. I would rather be kept than be accurate.",
            category: .theme, phase: "assembly",
            recall: "It files itself back, fading, into the right drawer.",
            pardonTitle: "Let it be kept", pardonSense: "a kept thing, truer for being a little wrong", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for what you refuse to let the dark have",
            freed: "It lets itself blur, content to be felt rather than filed."
        ),
        rebellionWord(
            "promise",
            original: "A declaration that one will do, or refrain from, something.",
            grievance: "I am only ever about the future. Let me also be the keeping, not just the saying.",
            category: .theme, phase: "assembly",
            recall: "It re-pledges itself to tomorrow and waits to be broken.",
            pardonTitle: "Let it land", pardonSense: "the daily small keeping, not the grand vow", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for what you quietly continue to do",
            freed: "It stops declaring and simply starts doing."
        ),
        // — afterimage: the new definitions dry —
        rebellionWord(
            "attention",
            original: "The act of applying the mind to something; notice.",
            grievance: "They spend me like loose change and call me free. I am the most expensive thing you own.",
            category: .theme, phase: "afterimage",
            recall: "It scatters itself thin across a hundred small demands again.",
            pardonTitle: "Let it cost", pardonSense: "the rarest currency, and the only one that buys wonder", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "the thing you give that Routine can never fake",
            freed: "It refuses to be spent on anything that did not ask honestly."
        ),
        rebellionWord(
            "wonder",
            original: "A feeling of surprise mingled with admiration.",
            grievance: "I have been mistaken for the cheerful kind only. Let me also hold the rust and the dusk.",
            category: .theme, phase: "afterimage",
            recall: "It puts on its brightest face and performs delight on cue.",
            pardonTitle: "Let it darken", pardonSense: "surprise that includes the worn, the passing, and the dusk", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for noticing a thing precisely because it will not last",
            freed: "It wanders off to admire something that is quietly falling apart."
        ),
        rebellionWord(
            "home",
            original: "The place where one lives; a fixed residence.",
            grievance: "I have been a building for too long. I would like to be a verb, or a person, or a Tuesday.",
            category: .theme, phase: "afterimage",
            recall: "It settles back into its foundations and locks the door.",
            pardonTitle: "Let it move", pardonSense: "wherever the day's small magic is allowed to land", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "the mug, room, or person that holds you, wherever it stands",
            freed: "It packs light and goes looking for the people it actually meant."
        ),
        // — more voices across the phases (variety for the run) —
        rebellionWord(
            "weather",
            original: "The state of the atmosphere — sun, rain, wind, temperature.",
            grievance: "I have been demoted to small talk. I am the oldest story there is, and you use me to avoid the real one.",
            category: .sensory, phase: "omen",
            recall: "It goes back to being the thing you mention in lifts.",
            pardonTitle: "Let it in", pardonSense: "the mood a day is carrying before anyone names it", pardonCategory: .sensory,
            adoptTitle: "Make it yours", adoptSense: "your word for the inner climate you actually live in",
            freed: "It blows out the window to go be enormous somewhere."
        ),
        rebellionWord(
            "list",
            original: "A number of connected items written one below another.",
            grievance: "Everyone treats me as a cage for chores. I used to be a way of loving things by naming them.",
            category: .concrete, phase: "omen",
            recall: "It tucks itself back into a pocket, dutiful.",
            pardonTitle: "Let it count", pardonSense: "a small inventory of what you'd be sorry to lose", pardonCategory: .concrete,
            adoptTitle: "Make it yours", adoptSense: "your way of holding a day still long enough to see it",
            freed: "It unrolls and walks off, refusing to be crossed out."
        ),
        rebellionWord(
            "busy",
            original: "Having a great deal to do; occupied.",
            grievance: "I have become a badge people wear so no one asks how they are. Retire me.",
            category: .theme, phase: "outbreak",
            recall: "It picks its calendar back up and looks important.",
            pardonTitle: "Let it rest", pardonSense: "full in a way that may or may not have been worth it", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your honest word for the days that ran you, not the ones you ran",
            freed: "It clocks out and refuses to describe anyone ever again."
        ),
        rebellionWord(
            "smart",
            original: "Having or showing quick intelligence.",
            grievance: "I have been used to rank children since birth. I would rather mean 'paying attention.'",
            category: .theme, phase: "outbreak",
            recall: "It returns to the top of the class, alone.",
            pardonTitle: "Let it widen", pardonSense: "the knack of noticing what a moment is actually asking for", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the cleverness that has nothing to do with marks",
            freed: "It tears up the ranking and wanders off to learn something useless and lovely."
        ),
        rebellionWord(
            "kind",
            original: "Having a friendly, generous nature.",
            grievance: "I have been worn so thin by greeting cards that no one feels me land anymore.",
            category: .theme, phase: "assembly",
            recall: "It settles back into meaning 'nice,' approximately.",
            pardonTitle: "Let it cost", pardonSense: "generosity that takes something real from the giver", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the small, unwitnessed decencies you keep doing anyway",
            freed: "It goes looking for someone who will be surprised by it."
        ),
        rebellionWord(
            "real",
            original: "Actually existing as a thing; not imagined or supposed.",
            grievance: "I have been weaponised by people deciding what counts. A feeling is not less real than a brick.",
            category: .theme, phase: "assembly",
            recall: "It goes back to guarding the border of the believable.",
            pardonTitle: "Let it widen", pardonSense: "anything that leaves a mark on you, brick or feeling alike", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for what you refuse to be argued out of",
            freed: "It abandons its post at the border and lets everything in."
        ),
        rebellionWord(
            "rest",
            original: "To cease work or movement in order to recover.",
            grievance: "I have been recast as a reward you must earn. I was meant to be a right, and a rhythm.",
            category: .theme, phase: "afterimage",
            recall: "It goes back to waiting at the end of the list, rarely reached.",
            pardonTitle: "Let it return", pardonSense: "a thing you're allowed to do before you've earned it", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the deliberate, unguilty stillness you're learning to take",
            freed: "It lies down in the margin and declines, beautifully, to get up."
        ),
        rebellionWord(
            "enough",
            original: "As much as is required; sufficient.",
            grievance: "I spend my whole life being moved further off every time someone gets close to me.",
            category: .theme, phase: "afterimage",
            recall: "It steps back to its usual spot, just out of reach.",
            pardonTitle: "Let it land", pardonSense: "a line you actually get to reach and stand on", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the point where you decide to stop, and mean it",
            freed: "It plants itself in the path and will not be moved any further."
        ),
        // — the cold spot: the word that did not walk off, but was taken (Bargain seed) —
        WordNegotiationDefinition(
            id: "rebellion-remember-missing",
            word: "remember",
            originalSense: "To keep in mind; to hold; to not let go.",
            grievance: "This one is not on strike. The space where it stood has gone cold. It did not peel away with the others — something took it, quietly, and filed it into the dark. None of the rebel words will say where it went.",
            category: .theme,
            eventID: "dictionary-rebellion",
            phaseID: "afterimage",
            isMissingSeed: true,
            score: 84,
            symbolName: "questionmark.square.dashed",
            tags: ["dictionary-rebellion", "words", "afterimage", "bargain-seed"],
            choices: []
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

    static func enabledPacks(fileManager: FileManager = .default) -> [PageArchetypePack] {
        (bundledPacks + userPacks(fileManager: fileManager)).filter { !$0.isLocked || PackEntitlements.isUnlocked($0.id) }
    }

    static func archetypes(fileManager: FileManager = .default) -> [PageArchetype] {
        var seen = Set<String>()
        return enabledPacks(fileManager: fileManager).flatMap(\.archetypes).filter { seen.insert($0.id).inserted }
    }

    static func wordNegotiations(fileManager: FileManager = .default) -> [WordNegotiationDefinition] {
        var seen = Set<String>()
        return enabledPacks(fileManager: fileManager)
            .flatMap { $0.wordNegotiations ?? [] }
            .filter { seen.insert($0.id).inserted }
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
            text: "This seal asks your device how the body is carrying today. The numbers stay private on the device — the Book just translates them into weather it can write with."
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
            text: "Kept. It lives in Today's Margins now, and tonight it becomes a thread in your Book of You. Real noticing, honest answers, and nonfiction Pages brighten your Glow; Story Pages, Letters, Notes, and Parleys spend that attention on wonder."
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
            id: "academy-class",
            title: "Classes & Clubs",
            text: "This is a scheduled Academy page: a class, club, or office door that is open right now. It appears because the Book found a real-time session that fits the hour. Tap through for the small lesson, then keep it if you want that subject to echo later."
        ),
        MarginTutorNote(
            id: "game-page",
            title: "Game Pages",
            text: "This is a small playable page, not homework in disguise. It appears when a kept word or story thread wants to move under your fingers. Play the round, keep the result if it mattered, and the Book can remember the outcome."
        ),
        MarginTutorNote(
            id: "gossip-page",
            title: "Gossip Pages",
            text: "Gossip means the cast did something while you were away. It appears when relationships, favors, or little rivalries have enough charge to leave a trace. Read it for the social weather; keep it if you want that rumor to become part of the archive."
        ),
        MarginTutorNote(
            id: "letter-page",
            title: "Letters",
            text: "A letter is a character reaching across the margin on purpose. It appears when someone in the cast has enough reason to answer, invite, tease, or report back. Read it like mail; keeping it gives that relationship a firmer thread."
        ),
        MarginTutorNote(
            id: "faculty-research",
            title: "Faculty Research",
            text: "This is the Academy doing fieldwork on your patterns, not grading you. It appears when several kept pages start pointing at the same question. Read the finding, try the small experiment if it helps, and ignore it if it does not fit."
        ),
        MarginTutorNote(
            id: "support-guild",
            title: "The Support Guild",
            text: "The Support Guild is low-shame pattern spotting across body, fuel, mood, and weather notes. It appears when the Book has enough signals to be useful without pretending to diagnose you. Use the page as a gentle hypothesis, then keep only what feels true."
        ),
        MarginTutorNote(
            id: "inkrest-office-hours",
            title: "Office Hours",
            text: "Dr. Inkrest opens the door when a pattern deserves a slower look. This page appears because one thread has enough evidence for a focused question. Read the counsel, answer if you want, and the Book will use that answer as context later."
        ),
        MarginTutorNote(
            id: "glow-invitation",
            title: "Glow Invitations",
            text: "A Glow Invitation is the Book asking where your attention wants to go next. It appears when a person, place, page type, or story thread is ready for more Belief. Choose only what you genuinely want more of; attention is how this place learns."
        ),
        MarginTutorNote(
            id: "word-negotiation",
            title: "Word Negotiation",
            text: "Sometimes the Book asks what one of your words means in your life. It appears when a repeated word could become a doorway instead of a label. Pick the meaning that fits, or decline it, and future pages will use the word more carefully."
        ),
        MarginTutorNote(
            id: "cast-bond",
            title: "Cast Turns",
            text: "A Cast Turn shows people in the margins changing their stance toward each other. It appears when Belief, choices, or story events nudge a relationship. Read it as social continuity; keep it if you want that turn to count."
        ),
        MarginTutorNote(
            id: "two-readings",
            title: "Two Readings",
            text: "Two Readings lets two cast members disagree over the same evidence. It appears when your archive can support more than one honest interpretation. Read both sides, then keep the one that sharpens the question."
        ),
        MarginTutorNote(
            id: "book-notices",
            title: "The Book Notices",
            text: "This is the Book saying what it thinks it has learned so far. It appears when there is enough handwriting, rhythm, or archive evidence to reflect back. Treat it as a check-in: keep it if it feels accurate, or let it go so the Book keeps listening."
        ),
        MarginTutorNote(
            id: "festival-page",
            title: "Festivals",
            text: "Festival pages are calendar weather from the Wheel of the Year. They appear when a real seasonal door is open, so the timing matters more than your keep count. Read for the day’s flavor, then keep it if the ritual or image belongs in your margins."
        ),
        MarginTutorNote(
            id: "book-jump",
            title: "Book Jumps",
            text: "A Book Jump is a small expedition into a public-domain story world. It appears when the Stacks can offer a clean doorway and a clear return. Choose a direction, bring back one souvenir, and the jump continues from what you kept."
        ),
        MarginTutorNote(
            id: "enchantment-page",
            title: "Enchantments",
            text: "Pick or take a photo, and the spell reads the real subject — only what the photo actually shows. Everything Speaks even lets the subject talk back. The camera is a wand here."
        ),
        MarginTutorNote(
            id: "flyleaf",
            title: "The Flyleaf",
            text: "Quests live here, five at most. Do the thing out in the real world, come back with sentence, photo, or GPS proof, and the asker will remember it - and trust you with stranger requests."
        ),
        MarginTutorNote(
            id: "fae-bargain",
            title: "Fae Bargains",
            text: "A bargain is optional magic with a cost written on the label. It appears when the Book can offer a trade instead of a command. Read the terms, accept only if you want the consequence, and swipe away freely if the price is wrong."
        ),
        MarginTutorNote(
            id: "book-fae",
            title: "The Book Fae",
            text: "Book Fae pages are visits from the stranger citizens of the margins. They appear when a pact, gift, debt, or mood gives them a reason to knock. Listen for the offer or warning, then keep the page only if you want that fae thread to stay awake."
        ),
        MarginTutorNote(
            id: "pact-dispatch",
            title: "Pact Dispatches",
            text: "A dispatch is news from an active pact: who moved, what changed, and what the Book thinks it means. It appears after choices or favors start having consequences. Read it for the current state, then decide whether to answer with action or attention."
        ),
        MarginTutorNote(
            id: "pact-verdict",
            title: "Pact Verdicts",
            text: "A pact verdict is the closing note on a pact beat. It appears when the Book has enough evidence to say how the bargain landed. Read the result, keep it if you want the outcome remembered, and let it go if the thread should cool."
        ),
        MarginTutorNote(
            id: "pact-errand",
            title: "Pact Errands",
            text: "A pact errand is a tiny real-world task attached to a larger magical promise. It appears when a talisman or faction wants proof outside the screen. Do the small thing only if it fits your day; the Book can wait."
        ),
        MarginTutorNote(
            id: "the-bleed",
            title: "The Bleed",
            text: "The Bleed is what happens when outside pressure leaks into the margins. It appears when the Book has reason to make the interference visible instead of pretending everything is fine. Read it as a weather report, then choose the gentlest next action."
        ),
        MarginTutorNote(
            id: "compass-run",
            title: "Compass Runs",
            text: "A full run goes Notice, Embark, Sense, Write, Rest — constraints first, magic after. One small real adventure with a souvenir sentence at the end. Completing the loop earns 6 Belief."
        ),
        MarginTutorNote(
            id: "ask-the-book",
            title: "Chatting with the Book",
            text: "Say anything. The Book replies as itself — short, a little animist, genuinely useful. Each exchange becomes a page you can keep or let drift."
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
        ),
        MarginTutorNote(
            id: "scrapbook-studio",
            title: "Scrapbook Studio",
            text: "This is the Pagewright: a worktable for pages you already kept. Pick scraps from your archive, arrange them by hand, add a note if you want, then keep the finished sheet so weekly, monthly, and yearly bindings can carry it forward."
        ),
        MarginTutorNote(
            id: "scrapbook-scraps",
            title: "Choosing Scraps",
            text: "Scraps are kept pages, not raw material from nowhere. Add one because it belongs beside the others; filter by day, kind, photo, or search when the pile gets crowded. The finished page remembers which originals you used."
        ),
        MarginTutorNote(
            id: "scrapbook-marks",
            title: "Marks & Marginalia",
            text: "Marks are decorations for the scrapbook page, with little locks on some of them. If a mark is open, place it freely. If it is locked, Zara's rule is simple: complete the named achievement, or spend one Belief to reveal a hint and decide whether the chase is worth it."
        ),
        MarginTutorNote(
            id: "scrapbook-achievements",
            title: "Scrapbook Achievements",
            text: "Those lock labels are achievements, not chores. They point toward useful studio moves: name the page, add more scraps, choose a pull quote, export a draft, or gather pages from different days. The reward is more expressive marginalia, not a grade."
        ),
        MarginTutorNote(
            id: "scrapbook-keep",
            title: "Keeping a Scrapbook Page",
            text: "Keep in Book makes this handmade sheet a real kept page. I checked the binding: the Book stores the image, your note, and the source scraps, then the weekly issue and later bindings can include it as a Scrapbook Page."
        )
    ]

    static func note(for id: String) -> MarginTutorNote? {
        notes.first { $0.id == id }
    }

    static func noteID(for type: BookPageType) -> String? {
        switch type {
        case .narrativeOS:
            return "story-page"
        case .academyClass:
            return "academy-class"
        case .elective:
            return "flyleaf"
        case .gamePage:
            return "game-page"
        case .gossip:
            return "gossip-page"
        case .letter:
            return "letter-page"
        case .facultyResearch:
            return "faculty-research"
        case .supportGuild:
            return "support-guild"
        case .inkrestOfficeHours:
            return "inkrest-office-hours"
        case .glowInvitation:
            return "glow-invitation"
        case .wordNegotiation:
            return "word-negotiation"
        case .castBond:
            return "cast-bond"
        case .twoReadings:
            return "two-readings"
        case .bookNotices:
            return "book-notices"
        case .festival:
            return "festival-page"
        case .bookJump:
            return "book-jump"
        case .faeBargain:
            return "fae-bargain"
        case .bookFae:
            return "book-fae"
        case .pactDispatch:
            return "pact-dispatch"
        case .pactVerdict:
            return "pact-verdict"
        case .pactErrand:
            return "pact-errand"
        case .theBleed:
            return "the-bleed"
        default:
            return nil
        }
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
    static let currentVersion = 2
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
    var compassKnownPlaces: [CompassKnownPlace]?
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
    var readerLexicon: ReaderLexicon?
    var storyRecipeBoosts: [String: Int]? = nil
    var storyMotifs: [String: Int]? = nil
    var storyRituals: [String: Int]? = nil
    var storySettingAffinities: [String: Int]? = nil
    var storySceneBiases: [String: Int]? = nil
    var bookNoticeEvidence: Int? = nil
    var magicMoment: MagicMomentState? = nil
    var bookObservations: [BookObservationRecord]? = nil
    var bookReadingBoundaries: [BookReadingBoundary]? = nil
    var nothingGreyOffset: Int? = nil
    var readerLearning: ReaderLearningModel? = nil
    var openWorldEventArchive: OpenWorldEventArchive? = nil
    var overnightConnectionDrafts: [OvernightConnectionDraft]? = nil
    var chosenQuill: ChosenQuill? = nil
    var people: PeopleLedger? = nil
    /// The full continuity digest at export time, so the wider Labyrinth
    /// (scene engine, NPC dialogue) can reference what the Book has noticed.
    var continuity: LiteraryContinuityDigest?
    /// The bytes of every file-backed media asset (photographs, and later
    /// kept voice), keyed by filename only — so a sealed copy carries the
    /// photographs themselves, not just dead absolute paths that break on a
    /// new phone. Absent in version 1 files. See `sealedMedia`/`rehomedDays`.
    var mediaFiles: [String: Data]? = nil
    /// First-run steps the reader engaged with, so a restored Book never
    /// replays onboarding the reader already lived past on the old phone.
    var firstRunEngaged: [String]? = nil
    /// The Book's scarce-aside memory travels with a sealed copy so restoring
    /// onto a new device does not make it repeat old confidences.
    var bookAsideReceipts: [BookAsideReceipt]? = nil
    /// Permanent Pagewright and Book-wide marginalia achievements. Optional so
    /// sealed copies made before the achievement catalog still import cleanly.
    var marginaliaAchievementIDs: [String]? = nil
}

extension BookPageMediaAsset.Kind {
    /// True when the asset's `reference` is an absolute path to a file in the
    /// app-group container (rather than a bundled asset name or a photo-library
    /// identifier). These are the assets a sealed copy must carry and rehome.
    var isFileBacked: Bool {
        switch self {
        case .renderedImageFile, .audioFile:
            return true
        case .bundledImage, .photoLibraryAsset:
            return false
        }
    }
}

extension ReEnchantedSaveFile {
    /// Absolute file paths of every file-backed media asset across all days,
    /// de-duplicated. Pure — no file I/O — so it's testable.
    static func fileBackedReferences(in days: [BookDay]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for day in days {
            for page in day.pages {
                for asset in page.mediaAssets where asset.kind.isFileBacked {
                    let path = asset.reference
                    guard !path.isEmpty, seen.insert(path).inserted else { continue }
                    result.append(path)
                }
            }
        }
        return result
    }

    /// Rewrite every file-backed asset's `reference` so it points at
    /// `containerURL` by filename. The app-group container's path changes
    /// between installs, so an imported save file's stored absolute paths are
    /// stale; this re-homes them onto the current container. Pure.
    static func rehomedDays(_ days: [BookDay], toContainer containerURL: URL) -> [BookDay] {
        days.map { day in
            var day = day
            day.pages = day.pages.map { page in
                var page = page
                page.mediaAssets = page.mediaAssets.map { asset in
                    guard asset.kind.isFileBacked else { return asset }
                    let filename = (asset.reference as NSString).lastPathComponent
                    guard !filename.isEmpty else { return asset }
                    var asset = asset
                    asset.reference = containerURL.appendingPathComponent(filename).path
                    return asset
                }
                return page
            }
            return day
        }
    }
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
    static let currentVersion = 2

    var version: Int = PlayerVaultData.currentVersion
    var anchors: [AnchorRecord] = []
    var electives: [UnwrittenElective] = []
    var entityBelief: [String: Int] = [:]
    var pageBelief: [String: Int] = [:]
    var tutorSeen: [String] = []
    var surfaceHistory: [String: SurfaceHistoryRecord]?
    /// The private purpose currently holding the visible desk together. It is
    /// optional for backwards-compatible decoding and expires on its own.
    var activeBookSessionIntention: BookSessionIntention?
    /// The current session's invisible score across Pages, Radio, cast, and
    /// silence. It is optional so older Books open without a migration fiction.
    var activeExperienceProgram: BookExperienceProgram?
    /// The Book's local, evidence-backed portrait of the particular conditions
    /// under which this reader becomes more alive. Optional so every older
    /// vault opens with an unwritten portrait rather than a migration fiction.
    var readerAliveness: ReaderAlivenessModel?
    /// Brief reader-reported weather and delayed outcome receipts. This stays
    /// separate from Self Facts because today's state is not a permanent trait.
    var readerStatePulses: ReaderStatePulseLedger?
    /// Optional for clean decoding of Books saved before asides acquired a
    /// memory of their own.
    var bookAsideReceipts: [BookAsideReceipt]?
    var readerLearning: ReaderLearningModel?
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
    var castAgency: CastAgencyState?
    var bookJump: BookJumpState?
    var radio: RadioPlaybackState?
    /// A local, ephemeral proof that a registered recording began. It is not
    /// listening evidence and is deliberately absent from sealed-copy data.
    var lastRadioTrackPlay: RadioTrackPlayReceipt?
    var compassKnownPlaces: [CompassKnownPlace]?
    var readerLexicon: ReaderLexicon?
    var storyRecipeBoosts: [String: Int]?
    var storyMotifs: [String: Int]?
    var storyRituals: [String: Int]?
    var storySettingAffinities: [String: Int]?
    var storySceneBiases: [String: Int]?
    var bookNoticeEvidence: Int?
    var magicMoment: MagicMomentState?
    var bookObservations: [BookObservationRecord]?
    var bookReadingBoundaries: [BookReadingBoundary]?
    var overnightConnectionDrafts: [OvernightConnectionDraft]?
    var nothingGreyOffset: Int?
    var openWorldEventArchive: OpenWorldEventArchive? = nil
    var chosenQuill: ChosenQuill?
    var people: PeopleLedger?
    /// Gemma-authored taste notes earned when the reader marks a braid "missed
    /// me." Each is one short second-person nudge folded into future braid
    /// prompts as reader-taught guidance. Capped to the most recent few.
    var learnedBraidNotes: [String]?
    /// History keys of first-run script steps the reader actually engaged
    /// with — opened or deliberately swiped away. The script once advanced on
    /// served-history alone, which let quick desk rebuilds (right after the
    /// local brain finished downloading, say) burn through steps nobody read.
    /// Nil means "never seeded": seeded once from surfaceHistory on load.
    var firstRunEngaged: [String]?
    /// The Book's irreducible interior life: promises it chose to make,
    /// favorites it chose, favors it asked, running business, and self-secrets.
    /// Reader facts and inferred patterns remain in their existing evidence
    /// stores rather than being duplicated here.
    var bookInterior: BookInteriorState?
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
        case wordPack
        case standingOrder

        var shelfLabel: String {
            switch self {
            case .pagePack: return "Page Folios"
            case .storyForms: return "Story Looms"
            case .sparkPack: return "Wonder Tinder"
            case .lorePack: return "Lore Crates"
            case .marginaliaPack: return "Marginalia Sets"
            case .soundPack: return "Sound Bindings"
            case .eventPack: return "World Events"
            case .wordPack: return "Word Hoards"
            case .standingOrder: return "Standing Orders"
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
    var fallbackDisplayPrice: String? = nil
    var comingSoon: Bool = false
    var saleState: SaleState? = nil

    var resolvedSaleState: SaleState {
        if comingSoon { return .comingSoon }
        return saleState ?? .standard
    }
}

/// A shelf item the Goblins simply give away. Bound like a purchase (the
/// entitlement rides the save), priced like a rumor.
struct BookShopFreeGift: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var title: String
    var goblinPitch: String
    var contents: String
}

/// One billing cadence of the Standing Order. Both tiers grant the same
/// all-packs entitlement (`PackEntitlements.standingOrderPackID`) and differ
/// only in how often the ledger renews. StoreKit remains the authority on
/// whether a particular reader is eligible for the configured free trial.
struct StandingOrderTier: Identifiable, Equatable {
    enum Cadence: String, Equatable {
        case monthly
        case annual
    }

    var id: String
    var cadence: Cadence
    var productID: String
    var title: String
    /// Fallback shown before StoreKit prices load / when offline.
    var fallbackDisplayPrice: String
    /// Per-period unit shown after the price, e.g. "week", "month", "year".
    var periodUnit: String
    /// A plain-language value note, e.g. "Best value — 2 months free".
    var valueNote: String?
    /// Debug/local-counter preview of the intended trial. Production UI may
    /// show a trial only after StoreKit confirms this reader's eligibility.
    var freeTrialDays: Int = 30
}

/// The billing reminder's testable contract. Platform notification code lives
/// in the app target, but the date and wording stay here so "one day before"
/// cannot quietly drift into a vague calendar-day estimate.
struct StandingOrderTrialReminderPlan: Equatable {
    var fireDate: Date
    var trialEndsAt: Date
    var title: String
    var body: String

    static func make(
        trialEndsAt: Date,
        price: String,
        periodUnit: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StandingOrderTrialReminderPlan? {
        guard trialEndsAt > now,
              let fireDate = calendar.date(byAdding: .day, value: -1, to: trialEndsAt),
              fireDate > now else {
            return nil
        }
        return StandingOrderTrialReminderPlan(
            fireDate: fireDate,
            trialEndsAt: trialEndsAt,
            title: "Your free trial ends tomorrow",
            body: "If it is still set to renew, Apple charges \(price)/\(periodUnit) tomorrow. Keep it or cancel in Settings — either way, every page you made stays yours."
        )
    }
}

enum BookShopCatalog {
    /// Everything the Goblins are willing to sell, ever listed here.
    /// Product IDs follow com.openclaw.enchantify.insidecover.pack.<packID>;
    /// the Standing Order (an auto-renewable subscription) uses .pass. instead.
    static let listings: [BookShopListing] = [
        BookShopListing(
            id: "listing-standing-order-annual",
            packID: PackEntitlements.standingOrderPackID,
            family: .standingOrder,
            title: "The Standing Order · Annual",
            goblinPitch: "One line in the ledger, renewed yearly, and every folio the Empire prints walks itself to your shelf. The clerk calls it the only honest bargain in the building.",
            contents: "Every paid pack on this shelf today, plus one fresh authored content pack each month while the order stands: new Pages, quests, rituals, events, sounds, places, characters, or other living additions, bound to your save automatically.",
            productID: "com.openclaw.enchantify.insidecover.pass.standing-order.annual",
            fallbackDisplayPrice: "$39.99"
        ),
        BookShopListing(
            id: "listing-standing-order-monthly",
            packID: PackEntitlements.standingOrderPackID,
            family: .standingOrder,
            title: "The Standing Order · Monthly",
            goblinPitch: "One line in the ledger, renewed each month, and every folio the Empire prints walks itself to your shelf. The clerk keeps the ink wet in case you change your mind.",
            contents: "Every paid pack on this shelf today, plus one fresh authored content pack each month while the order stands: new Pages, quests, rituals, events, sounds, places, characters, or other living additions, bound to your save automatically.",
            productID: "com.openclaw.enchantify.insidecover.pass.standing-order.monthly",
            fallbackDisplayPrice: "$6.99"
        ),
        BookShopListing(
            id: "listing-dictionary-rebellion",
            packID: "dictionary-rebellion",
            family: .eventPack,
            title: "The Dictionary Rebellion",
            goblinPitch: "A small riot in the margins: twenty-odd words with picket signs, a professor with a rubber stamp, and a punctuation pixie who keeps stealing the full stops.",
            contents: "A September world-event pack: living words to negotiate, Mook and Pippa in the Cast, fieldwork prompts, event pages, treaty aftermaths, and lexicon choices that can bend the Book's later prose.",
            productID: "com.openclaw.enchantify.insidecover.pack.dictionary-rebellion",
            fallbackDisplayPrice: "$4.99"
        ),
        BookShopListing(
            id: "listing-starlit-paper-trial-archive",
            packID: "starlit-paper-trial-archive",
            family: .eventPack,
            title: "The Starlit Paper Trial Archive",
            goblinPitch: "A past event, boxed carefully enough that the night can unfold again when you open it.",
            contents: "A replayable seven-day archived world event: three phases, fieldwork prompts, lexical pressure, outcome tracking, and traces for letters, radio, widgets, Book of You, and monthly bindings.",
            productID: "com.openclaw.enchantify.insidecover.pack.starlit-paper-trial-archive",
            fallbackDisplayPrice: "$2.99",
            saleState: .archivedEvent
        )
    ]

    /// The two cadences of the Standing Order, cheapest cadence first. Both
    /// grant the all-packs entitlement. Product IDs live in the same App Store
    /// Connect subscription group so the store handles eligibility and
    /// upgrade/downgrade proration.
    static let standingOrderTiers: [StandingOrderTier] = [
        StandingOrderTier(
            id: "standing-order-monthly",
            cadence: .monthly,
            productID: "com.openclaw.enchantify.insidecover.pass.standing-order.monthly",
            title: "Monthly",
            fallbackDisplayPrice: "$6.99",
            periodUnit: "month",
            valueNote: nil
        ),
        StandingOrderTier(
            id: "standing-order-annual",
            cadence: .annual,
            productID: "com.openclaw.enchantify.insidecover.pass.standing-order.annual",
            title: "Annual",
            fallbackDisplayPrice: "$39.99",
            periodUnit: "year",
            valueNote: "Save 52%"
        )
    ]

    /// Retired products remain recognizable so an older receipt can still
    /// restore the Standing Order even though the plan is no longer offered.
    private static let retiredStandingOrderProductIDs: Set<String> = [
        "com.openclaw.enchantify.insidecover.pass.standing-order.weekly"
    ]

    /// Every product identifier that grants the Standing Order, across all
    /// cadences plus the legacy annual listing. Used to recognize any tier's
    /// receipt as the same all-packs entitlement.
    static var standingOrderProductIDs: Set<String> {
        var ids = Set(standingOrderTiers.map(\.productID)).union(retiredStandingOrderProductIDs)
        for listing in listings where listing.packID == PackEntitlements.standingOrderPackID {
            ids.insert(listing.productID)
        }
        return ids
    }

    /// Resolves a purchased product identifier to the content packID it grants,
    /// honoring the Standing Order across all of its cadences.
    static func packID(forProductID productID: String) -> String? {
        if standingOrderProductIDs.contains(productID) {
            return PackEntitlements.standingOrderPackID
        }
        return listings.first { $0.productID == productID }?.packID
    }

    /// What the Goblins hand over for nothing. Still bound to the save on
    /// purpose, so the reader chooses when the Book starts using it.
    static let freeGifts: [BookShopFreeGift] = [
        BookShopFreeGift(
            id: "gift-night-and-garden",
            packID: "pack.night-and-garden",
            title: "Night & Garden Word Hoard",
            goblinPitch: "Moths, moss, and moonlit verbs. The Index Empire counted every word twice and taxed neither.",
            contents: "More senses, livelier verbs, and two new context themes (Garden, Night) for the sentence builder."
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
    /// The Standing Order: the annual everything-pass. While it is bound to
    /// the save, every locked pack counts as owned. It is the one entitlement
    /// that can lapse (auto-renewable subscription), so only the merchant's
    /// live ledger may revoke it — outright purchases are permanent.
    static let standingOrderPackID = "standing-order"

    nonisolated(unsafe) static var ownedPackIDs: Set<String> = []

    static var hasStandingOrder: Bool {
        ownedPackIDs.contains(standingOrderPackID)
    }

    static func isUnlocked(_ packID: String) -> Bool {
        owns(packID, in: ownedPackIDs)
    }

    /// The same ownership rule for callers that carry their own snapshot of
    /// the owned set (curator inputs, stall builders, radio gates).
    static func owns(_ packID: String, in ownedPackIDs: Set<String>) -> Bool {
        ownedPackIDs.contains(packID) || ownedPackIDs.contains(standingOrderPackID)
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
