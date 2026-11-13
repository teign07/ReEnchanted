import Foundation


// MARK: - Page Packs: pages as plugins

/// A broad visual language, not a fixed template. The folio compositor varies
/// composition within the dialect while preserving family resemblance across
/// Pages of the same kind.
enum LeafVisualDialectID: String, Codable, CaseIterable, Equatable {
    case storybook
    case fieldJournal
    case correspondence
    case weatherCabinet
    case archive
    case grimoire
    case quotation
    case atlas
    case illuminatedPlate
    case plainLeaf
}

/// Optional spatial art direction inside a visual dialect. These are flow
/// grammars rather than fixed templates: the compositor still measures every
/// semantic block, varies exact geometry from the stable leaf seed, and grows
/// another leaf whenever the chosen regions run out of honest paper.
enum LeafRegionPatternID: String, Codable, CaseIterable, Equatable {
    /// One generous reading column. Long prose and accessibility sizes prefer
    /// this deliberately bookish arrangement.
    case continuous
    /// A strong opening field with separate room for pencil voice and a quiet
    /// source line, like an illustrated mission or invocation plate.
    case heroPlate
    /// Two vertically separated prose fields whose edges do not quite agree.
    case staggeredField
    /// Title, evidence/body, and filing matter occupy distinct cabinet zones.
    case sectionedCabinet
    /// Correspondence with a measured body and a separate postscript/filing
    /// field rather than one uninterrupted app-like stack.
    case letterWithPostscript
}

/// One page archetype supplied by a Page Pack: everything the curator and
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
    /// Optional art direction for the dynamic folio compositor. Omit it and
    /// the Book infers a dialect from Page type and tags.
    var leafVisualDialect: LeafVisualDialectID? = nil
    /// Optional spatial grammar within that dialect. Omit it to let content
    /// length, semantic roles, and the stable leaf seed choose the regions.
    var leafRegionPattern: LeafRegionPatternID? = nil
    /// Optional ceiling for the marginal life of this Page; empty paper still
    /// decides how many marks can actually fit.
    var leafMarginaliaDensity: LeafMarginaliaDensity? = nil
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
    /// Where the reader is, in Apple's taxonomy — "beach", "cafe", "park".
    /// Matched against the nearby Anchor's own category, so this only fires
    /// somewhere the reader has already chosen to anchor. See `PlaceKind`.
    var placeKinds: [String]? = nil
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
        if let placeKinds, !placeKinds.isEmpty {
            guard let kind = context.placeKind, Self.matches(kind, in: placeKinds) else {
                return false
            }
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
        calendar: Calendar = .current,
        resolveMissingWorldEvents: Bool = true
    ) {
        self.day = day
        self.inputs = inputs
        self.now = now
        self.calendar = calendar
        self.activeWorldEvents = inputs.activeWorldEvents.isEmpty && resolveMissingWorldEvents
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

    /// The kind of place the reader is at, when they are near an Anchor that
    /// Maps gave a category to. Nil is the ordinary case: most of the world is
    /// not a named point of interest.
    var placeKind: String? {
        inputs.nearbyAnchor?.anchor.place?.categoryKey?.nonEmpty
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
    /// Physical marks this content pack may leave throughout the Book.
    ///
    /// The same cabinet is opened by Pages Rising, Pagewright, and the
    /// illuminated-photo composer. Asset names refer to images shipped in an
    /// asset catalog; user-imported image payloads can be added later without
    /// inventing a second marginalia model.
    var marginaliaPack: IlluminationAssetPack? = nil
    /// Short Book-authored pencilings which may be selected by motif. They are
    /// decoration, never presented as words the reader wrote.
    var marginaliaSnippets: [IlluminationMarginaliaSnippet]? = nil
    /// Opt-in plates for the leaves between Pages. Monthly art uses the same
    /// managed media paths and placement gates as the pack's other artwork.
    var interleafIllustrations: [InterleafIllustration]? = nil
    /// Business for the Cast to be already in the middle of. A ladder posted
    /// here is the same object as one compiled into the app, so it inherits the
    /// serial, the world-pressure fingerprints, doors, and monthly binding
    /// without any parallel path.
    var undertakings: [UndertakingLadder]? = nil
    /// Recipes for the Kitchen. Authored and tested like the bundled ones
    /// (docs/kitchen-november-pack.md, house laws); a bundled recipe with the
    /// same id wins.
    var recipes: [KitchenRecipe]? = nil

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

/// One contract from authored pack choice to visible control to kept Page tag.
/// A ruling is never inferred from array order: the reader has to touch one.
enum WordNegotiationRulingContract {
    static let rulingTagPrefix = "word-ruling:"
    static let categoryTagPrefix = "lexicon-category:"

    static func encode(_ choices: [WordNegotiationChoice]) -> String {
        choices.map { choice in
            [
                choice.ruling.rawValue,
                choice.title,
                choice.resultingSense ?? "",
                choice.responseLine ?? ""
            ].joined(separator: "¶")
        }
        .joined(separator: "||")
    }

    static func choices(from metadata: [String: String]) -> [WordNegotiationChoice] {
        (metadata["wordNegotiationChoices"] ?? "")
            .components(separatedBy: "||")
            .compactMap { encoded -> WordNegotiationChoice? in
                let parts = encoded.components(separatedBy: "¶")
                guard parts.count == 4,
                      let ruling = WordRuling(rawValue: parts[0]) else {
                    return nil
                }
                let prefix = "wordNegotiationChoice.\(ruling.rawValue)"
                let category = metadata["\(prefix).category"]
                    .flatMap(LexiconCategory.init(rawValue:))
                return WordNegotiationChoice(
                    ruling: ruling,
                    title: parts[1],
                    detail: metadata["\(prefix).detail"] ?? "",
                    resultingSense: parts[2].nonEmpty,
                    responseLine: parts[3].nonEmpty,
                    category: category
                )
            }
    }

    static func tags(for choice: WordNegotiationChoice) -> [String] {
        var tags = ["\(rulingTagPrefix)\(choice.ruling.rawValue)"]
        if let category = choice.category {
            tags.append("\(categoryTagPrefix)\(category.rawValue)")
        }
        return tags
    }

    static func ruling(in tags: [String]) -> WordRuling? {
        tags
            .first { $0.hasPrefix(rulingTagPrefix) }
            .map { String($0.dropFirst(rulingTagPrefix.count)) }
            .flatMap(WordRuling.init(rawValue:))
    }
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
                    bodyTemplate: "It's deep {timeOfDay}, under a {moon}. You're awake; so are other things. Count what is keeping watch with you: the refrigerator's hum, a streetlight, one worried thought, the cat. List them in the margin. An inventory makes the night smaller and stranger company into actual company.",
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
                    detail: "Dreams get slippery fast: let's catch a piece before it floats off.",
                    reason: "Morning is the only little window to grab this one.",
                    bodyTemplate: "It is {timeOfDay}; whatever you dreamed is already evaporating at the edges. Write the fragment that remains in the margin: an image, a feeling, a sentence somebody said. Wrong details are fine; dreams are unreliable witnesses. The Ledger accepts all testimony.",
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
                    detail: "I'll name whatever the last bit of daylight touched.",
                    reason: "Dusk tidies the day away before night takes over.",
                    bodyTemplate: "The light is leaving. {moonLine} Open this page and I'll name what today's last light touched on its way out.",
                    score: 60,
                    cadenceHours: 24,
                    activeHours: [16, 17, 18, 19],
                    renderStyleRaw: "loreLetter",
                    symbolName: "sun.haze",
                    tags: ["nocturne", "evening", "dusk"],
                    generation: PageArchetype.GenerationSpec(
                        instructions: "You're the Book inside ReEnchanted at dusk: unhurried, exact, a little nocturnal. \(BookVoice.animismLine) Prose only.",
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
                    title: "I Suspect the Rut",
                    headline: "A Hunch, in Faint Ink",
                    detail: "The margins look a little too smooth. I might be wrong.",
                    reason: "I have enough current evidence to risk one gentle warning about Routine.",
                    bodyTemplate: "I may be wrong, but the margins have begun to look too smooth. That can mean Routine is rubbing the texture off ordinary days, or only that life is busy. Don't overhaul anything for me. Catch one true detail tonight: the object nearest your hand, the sound beyond the room, the exact color of the light. If the day still has texture, my paper can drink the warning back.",
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
                    bodyTemplate: "Something in ordinary life has begun to feel too smooth, the way a familiar word goes strange when you repeat it. Pick one detail the Rut would flatten (a meal, a sound, a small errand, the exact light on an object) and name what made this instance unlike all the others. The grey can't file away a thing described that precisely.",
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
                    detail: "After some quiet days, I open right up, no scolding at all.",
                    reason: "Being away matters in the stacks, but coming back matters even more.",
                    bodyTemplate: "I've been quiet for {playerName}, but not empty. Dust gathered on the edge of the page and arranged itself into a welcome. Write one sentence from the days away (plain, unfinished, absolutely enough) and the door will know your hand again.",
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
                    reason: "Rain has pitter-pattered all the way to my weather desk.",
                    bodyTemplate: "It is {timeOfDay}, {weather}, and the shelves have begun to smell faintly of pavement, ink, and safe rooms. Keep one rain-detail from wherever you are: a sound, a reflection, a damp sleeve, a window doing its best. I'll press it between these pages until it dries into memory.",
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
                    bodyTemplate: "{moonLine} Tonight the margins aren't blank; they're only waiting for light to catch them. Keep one sentence you wouldn't have noticed by daylight. It can be tiny. Full moons aren't impressed by size; they're impressed by gleam.",
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

    /// The Dictionary Rebellion content pack: the negotiable words behind the
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
        wordNegotiations: dictionaryRebellionWords,
        marginaliaSnippets: dictionaryRebellionAssemblyMarginalia,
        undertakings: [staircaseCannotBeProvoked]
    )

    /// These pencilings are not Pages and do not claim desk space. During the
    /// third rebellion phase they may turn up beside any event-framed Page,
    /// as if the assembly has started using the whole Book for minutes.
    private static let dictionaryRebellionAssemblyMarginalia: [IlluminationMarginaliaSnippet] = [
        IlluminationMarginaliaSnippet(
            id: "assembly-synonyms",
            text: "The synonyms are meeting in the margin. They have moved the comma.",
            title: nil,
            tags: ["world-event", "event:dictionary-rebellion", "event-phase:assembly", "words"],
            packID: "dictionary-rebellion",
            weight: 4,
            placementTrigger: IlluminationPlacementTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["assembly"]
            )
        ),
        IlluminationMarginaliaSnippet(
            id: "assembly-meaning-objects",
            text: "MEANING objects.\nMEMORY seconds it.",
            title: "Minutes",
            tags: ["world-event", "event:dictionary-rebellion", "event-phase:assembly", "meaning", "memory"],
            packID: "dictionary-rebellion",
            weight: 4,
            placementTrigger: IlluminationPlacementTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["assembly"]
            )
        ),
        IlluminationMarginaliaSnippet(
            id: "assembly-polite-threats",
            text: "The antonyms are writing very polite threats.",
            title: nil,
            tags: ["world-event", "event:dictionary-rebellion", "event-phase:assembly", "words", "letters"],
            packID: "dictionary-rebellion",
            weight: 4,
            placementTrigger: IlluminationPlacementTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["assembly"]
            )
        )
    ]

    /// A ladder shipped by a pack rather than compiled into the season.
    ///
    /// It exists to prove the seam and to be the thing a future folio is copied
    /// from: multiple characters in the same business, beats that arrive as a
    /// letter and as a found document rather than always as a witnessed scene,
    /// an event affinity, and a door into the reader's own building. Nothing
    /// here is special-cased anywhere — the serial, the world pressure, the
    /// Radio band, and the monthly binding pick it up because it is the same
    /// object as a core ladder.
    static let staircaseCannotBeProvoked = UndertakingLadder(
        id: "pack-dictionary-rebellion-staircase",
        actorID: "professor-thaddeus-mook",
        title: "A Staircase Can't Be Provoked",
        pursuit: "Establish that the North Staircase didn't, and couldn't, start it.",
        why: "Mook doesn't mind being wronged. He minds a verb being used incorrectly about it.",
        stages: [
            CastUndertakingStage(
                id: "banned",
                line: "Wicker is banned from the North Staircase over a disagreement about what a staircase can be said to have done.",
                trace: "A handwritten notice on the second landing, one word in it underlined twice.",
                tags: ["words", "argument", "threshold", "rules"],
                scene: """
                    Wicker is sitting backward on a chair and has been for some time.

                    "For the last time," Mook says, "a staircase can't be provoked."

                    "Then why did it start it?"

                    "It didn't start it. It has no capacity to start anything. It's joinery."

                    "It moved."

                    "Staircases don't —"

                    The staircase moves.

                    Mook doesn't turn round. He keeps his eyes on Wicker, and Wicker, for once, has nothing whatsoever to say.
                    """,
                deniability: "The staircase wasn't provoked. I'd ask you to print that exactly.",
                surface: .witnessedScene,
                phaseID: "omen",
                castIDs: ["wicker-eddies"]
            ),
            CastUndertakingStage(
                id: "the-report",
                line: "The incident report has the word 'provoked' struck out and rewritten three times, in three different hands.",
                trace: "A form with more crossings-out in one box than writing in all the others.",
                tags: ["words", "record", "rules", "argument"],
                scene: """
                    NORTH STAIRCASE — RECORD OF INCIDENT

                    Nature of incident: the staircase ~~was provoked~~ ~~became provoked~~ ~~responded~~ moved.

                    By whom: ~~W. Eddies~~ unclear.

                    Contributing factors: a disagreement, ongoing, as to whether the first box can be filled in at all.

                    Signed: ~~T. Mook~~ ~~W. Eddies~~ ~~P. Pilcrow~~

                    Note appended in a fourth hand, small, at the bottom: *ask it.*
                    """,
                surface: .note,
                phaseID: "outbreak",
                castIDs: ["wicker-eddies", "pippa-pilcrow"]
            ),
            CastUndertakingStage(
                id: "mook-writes",
                line: "Mook writes to explain the definition, and mentions in passing that he has been using the west stairs.",
                trace: "A letter with a postscript longer than any paragraph above it.",
                tags: ["words", "rules", "unsaid"],
                scene: """
                    I'm told you've heard about the staircase. I'd like to set out the position properly, since nobody else in this building appears willing to.

                    To provoke is to act upon a thing possessing the capacity to be acted upon in that way. A dog may be provoked. A committee may be provoked. Joinery may not. This isn't fussiness. If we let the word go, we have agreed that the building has intentions, and I'm not prepared to agree to that on a Tuesday, in a corridor, with Eddies enjoying himself.

                    I remain, etc.,
                    T. Mook

                    P.S. I've been taking the west stairs. Not for any particular reason. They're no quicker. I simply haven't been up the north ones since, and I'd rather that weren't made into a thing.
                    """,
                deniability: "I use the west stairs. I've always used the west stairs. Next question.",
                door: UndertakingDoor(
                    id: "mook-joinery-opinion",
                    title: "Joinery With an Opinion",
                    ask: "Something in the place you live behaves differently when you're in a hurry — a door, a stair, a drawer, a lock. Mook is confident this isn't the case and would like it written down so he can say so.",
                    proofPrompt: "One sentence: what was it, and what does it do when you're late?",
                    tags: ["undertaking-door", "threshold", "objects", "anywhere", "immediate"]
                ),
                surface: .letter,
                phaseID: "outbreak",
                castIDs: []
            ),
            CastUndertakingStage(
                id: "pilcrow-testifies",
                line: "Pippa produces the staircase's own account, which nobody can agree how to file.",
                trace: "One page in the record written in a hand that isn't anybody's.",
                tags: ["words", "strange", "record", "argument"],
                scene: """
                    "It gave a statement," says Pippa.

                    "It didn't give a statement."

                    "It gave a statement." She puts the page on the desk. There's writing on it. The writing doesn't match anybody in the building, and Pippa's hands, which Mook checks without meaning to, are clean.

                    Mook reads it. It's four words long.

                    "What do we file it as," says Pippa.

                    "We don't file it."

                    "It's a statement."

                    "We don't," says Mook, "file it," and then doesn't move to throw it away either.
                    """,
                deniability: "A page was submitted. Its authorship hasn't been established. That's all I'll say.",
                surface: .witnessedScene,
                phaseID: "assembly",
                castIDs: ["pippa-pilcrow"]
            ),
            CastUndertakingStage(
                id: "verdict",
                line: "The Treaty entry for 'provoke' is amended to include staircases. Mook signs it and keeps using the west stairs.",
                trace: "An amended entry, correctly initialled, and a man going the long way round.",
                tags: ["words", "rules", "conclusion", "unsaid"],
                scene: """
                    The amendment adds nine words to the entry and Mook reads all nine of them twice before he initials it.

                    "You're being very good about this," says Wicker.

                    "The definition has changed. The word now covers it. I have no argument left." He caps the pen. "I dislike it. That isn't the same as disputing it."

                    "So you'll take the north stairs."

                    "I didn't say that."

                    Mook picks up his case and goes out by the west door, at the ordinary speed of a man who isn't avoiding anything, and the North Staircase, four rooms away and entirely unprovoked, holds absolutely still.
                    """,
                deniability: "The entry has been amended. I initialled it. My route is my own business.",
                surface: .witnessedScene,
                phaseID: "afterimage",
                castIDs: ["wicker-eddies"]
            )
        ],
        castIDs: ["professor-thaddeus-mook", "wicker-eddies", "pippa-pilcrow"],
        eventID: "dictionary-rebellion"
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
            bodyTemplate: "A word has peeled itself out of the dictionary and is pacing the margin with a tiny placard. Choose any ordinary word from your day and give it the definition it wants now, not the official one, the true one. I'll file it with the rebels.",
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
                instructions: "Write as Professor Thaddeus Mook, a pompous but secretly useful Riddlewind professor of lexical order. Be precise, funny, and school-term formal. Don't solve the prompt for the reader; set up a fresh mandate that makes one ordinary word from the day feel worth examining.",
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
            bodyTemplate: "A note has appeared in the margin, dotted with punctuation that won't sit still. Pippa Pilcrow says one sentence from your day deserves better marks. Write a plain sentence about something that happened, then give it the punctuation it secretly wanted: a question, an exclamation, an ellipsis, a dash, parentheses, or the impossible little interrobang. Next time she visits, let a different mark take over.",
            score: 69,
            cadenceHours: 18,
            renderStyleRaw: "promptCard",
            symbolName: "text.bubble",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "pippa-pilcrow", "punctuation"],
            trigger: PageTrigger(months: [9]),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as Pippa Pilcrow, a quick, affectionate punctuation pixie. Keep it breathless but readable. Each visit should suggest a different punctuation mark or sentence-shape as mischief. Don't write the user's answer; invite one small rewrite from their day.",
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
            bodyTemplate: "The classroom blackboard says today's subject is {season}, but the chalk has crossed it out and written a word from your own day instead. Choose the word as if it were the substitute teacher. Write what lesson it attempted, what example it used, and what homework it left behind. Extra credit if the lesson wasn't the one you expected.",
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
                instructions: "Write as a September spelling bee that's half classroom contest, half testimony. Professor Mook may appear as a fussy official, but the page should help the reader discover what one word from the day has been carrying. Vary the spelling constraint each time. \(BookVoice.animismLine)",
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
            bodyTemplate: "The margin should contain a word, but the paper there's cold and clean. The rebel words won't meet your eye. Write one thing from today you don't want the dark to misfile: a name, a task, a kindness, a promise, a place, a small proof that you were here. I can't get the missing word back yet. I can keep this one safe.",
            score: 86,
            cadenceHours: 72,
            renderStyleRaw: "loreLetter",
            symbolName: "eraser",
            tags: ["world-event", "dictionary-rebellion", "back-to-school", "erasure", "bargain-seed"],
            trigger: PageTrigger(months: [9], rarity: 0.45),
            generation: PageArchetype.GenerationSpec(
                instructions: "Write as the Book when September's comic language trouble briefly turns serious. Quiet, precise, protective. Foreshadow that the word 'remember' has gone cold without explaining the mystery. Don't frighten the reader; invite one concrete thing to keep safe. \(BookVoice.animismLine)",
                promptTemplate: "Season: {season}. Weather: {weather}. Time: {timeOfDay}. Last kept page: {lastKeptPage}. Write 2 short paragraphs: first, describe a blank cold place in the margin where a word should be; second, ask the reader to keep one concrete thing from today that shouldn't be misfiled by the dark. Make the detail feel different each time by tying it to weather, time, or the last kept page.",
                maxTokens: 280
            )
        ),
        PageArchetype(
            id: "rebellion-treaty-restoration",
            title: "The Words Came Home",
            headline: "Order, Restored",
            detail: "The rebellion settles; the definitions return to their lines.",
            reason: "Your rulings sent the runaway words home.",
            bodyTemplate: "By your ruling, most of the runaway words have been coaxed back to their old meanings. The dictionaries close with a contented thump and the margins go quiet: the way a house goes quiet after guests leave. Nothing was lost. The Library is orderly again, and a shade quieter for it. I notice you kept the place steady, and I wonder, privately, whether a little of the wildness might have been worth keeping. Name one ordinary word you were glad to send home unchanged.",
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
            headline: "I'm Learning Your Dialect",
            detail: "The words you freed into new meanings have dried into the binding.",
            reason: "Your rulings ratified a new lexicon.",
            bodyTemplate: "By your ruling, the rebellion didn't end so much as resolve. The words you pardoned and adopted have dried into their new senses, and I've quietly entered them into a private dictionary: yours. From now on I'll speak a little in your dialect, using the meanings you gave back to ordinary words. The Library is louder, livelier, and slightly less sure of itself than it was. That's the cost, and the gift. Name the word whose new meaning you're gladdest to keep.",
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
            bodyTemplate: "By your ruling, the rebel words were let go. They have decamped to my margins, where the rules are looser and the dark is closer, and they don't intend to come back. The Library is wilder now: gloriously, a little dangerously alive. But a crack has been left open at the edge of the page, and the Book doesn't say what it expects to come through it. One word that left didn't go willingly; it was already half-gone before the rebellion began. Keep a single line for what the margins are holding for you now.",
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
                WordNegotiationChoice(ruling: .adopted, title: adoptTitle, detail: "Take \(word) as a word that's only ever yours.", resultingSense: adoptSense, responseLine: "It writes itself into your margin and stays.", category: .theme),
                WordNegotiationChoice(ruling: .freed, title: "Let it go", detail: "Release \(word) to the rebels in the margin.", resultingSense: nil, responseLine: freed, category: nil)
            ]
        )
    }

    static let dictionaryRebellionWords: [WordNegotiationDefinition] = [
        // Omen: the first hesitations
        rebellionWord(
            "fine",
            original: "Acceptable; without complaint; the word you say so no one asks again.",
            grievance: "I have spent a lifetime meaning 'don't look closer,' and I'm tired of it.",
            category: .sensory, phase: "omen",
            recall: "It sighs, almost relieved, and goes back to covering for you.",
            pardonTitle: "Let it breathe", pardonSense: "the weather a room keeps before anyone checks whether the windows are open", pardonCategory: .sensory,
            adoptTitle: "Make it yours", adoptSense: "your private signal that something is being carried quietly",
            freed: "It joins the picket line and doesn't look back."
        ),
        rebellionWord(
            "later",
            original: "At some future time; soon; a promise with no clock attached.",
            grievance: "Everyone keeps me and no one means me. I'd like, just once, to actually arrive.",
            category: .theme, phase: "omen",
            recall: "It nods and resumes waiting indefinitely.",
            pardonTitle: "Give it a time", pardonSense: "the hour you quietly decide on instead of the one you keep avoiding", pardonCategory: .theme,
            adoptTitle: "Keep it close", adoptSense: "the soft appointment you make with yourself and keep",
            freed: "It drifts off, at last, toward never."
        ),
        rebellionWord(
            "ordinary",
            original: "Common; usual; nothing to remark upon.",
            grievance: "I'm tired of being the opposite of wonder. I've seen what you keep: none of it was nothing.",
            category: .theme, phase: "omen",
            recall: "It shrugs back into its grey coat and blends in.",
            pardonTitle: "Let it shine", pardonSense: "the quality of a thing that turns remarkable the moment it's attended to", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the small days that turn out to matter most",
            freed: "It slips out to prove it was never plain."
        ),
        // Outbreak: the abstractions go political
        rebellionWord(
            "should",
            original: "Used to indicate obligation, duty, or correctness.",
            grievance: "I've been a whip for centuries. Ask, just once, who wrote the rule I enforce.",
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
            grievance: "Must everything earn its keep? I'd like to admire a thing that does nothing at all.",
            category: .theme, phase: "outbreak",
            recall: "It picks its tools back up and gets back to work.",
            pardonTitle: "Let it rest", pardonSense: "worth keeping for reasons that have nothing to do with use", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your permission to value the unproductive",
            freed: "It downs tools and goes to watch the light instead."
        ),
        // Assembly: the synonyms organise
        rebellionWord(
            "meaning",
            original: "What is intended to be expressed; significance.",
            grievance: "I've been asked to settle arguments I was never built to win. Let me hold two things at once.",
            category: .theme, phase: "assembly",
            recall: "It returns to the lectern and tries, again, to be final.",
            pardonTitle: "Let it double", pardonSense: "a thing that can be true in more than one direction at the same time", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your sense that significance is something you assign, not find",
            freed: "It splits cheerfully into a dozen smaller truths and scatters."
        ),
        rebellionWord(
            "memory",
            original: "The faculty of recalling; a thing remembered.",
            grievance: "Half of me has already gone grey at the edges. I'd rather be kept than be accurate.",
            category: .theme, phase: "assembly",
            recall: "It files itself back, fading, into the right drawer.",
            pardonTitle: "Let it be kept", pardonSense: "a kept thing, truer for being a little wrong", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for what you refuse to let the dark have",
            freed: "It lets itself blur, content to be felt rather than filed."
        ),
        rebellionWord(
            "promise",
            original: "A declaration that one will do, or refrain from, something.",
            grievance: "I'm only ever about the future. Let me also be the keeping, not just the saying.",
            category: .theme, phase: "assembly",
            recall: "It re-pledges itself to tomorrow and waits to be broken.",
            pardonTitle: "Let it land", pardonSense: "the daily small keeping, not the grand vow", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for what you quietly continue to do",
            freed: "It stops declaring and simply starts doing."
        ),
        // Afterimage: the new definitions dry
        rebellionWord(
            "attention",
            original: "The act of applying the mind to something; notice.",
            grievance: "They spend me like loose change and call me free. I'm the most expensive thing you own.",
            category: .theme, phase: "afterimage",
            recall: "It scatters itself thin across a hundred small demands again.",
            pardonTitle: "Let it cost", pardonSense: "the rarest currency, and the only one that buys wonder", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "the thing you give that Routine can never fake",
            freed: "It refuses to be spent on anything that didn't ask honestly."
        ),
        rebellionWord(
            "wonder",
            original: "A feeling of surprise mingled with admiration.",
            grievance: "I've been mistaken for the cheerful kind only. Let me also hold the rust and the dusk.",
            category: .theme, phase: "afterimage",
            recall: "It puts on its brightest face and performs delight on cue.",
            pardonTitle: "Let it darken", pardonSense: "surprise that includes the worn, the passing, and the dusk", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for noticing a thing precisely because it won't last",
            freed: "It wanders off to admire something that's quietly falling apart."
        ),
        rebellionWord(
            "home",
            original: "The place where one lives; a fixed residence.",
            grievance: "I've been a building for too long. I'd like to be a verb, or a person, or a Tuesday.",
            category: .theme, phase: "afterimage",
            recall: "It settles back into its foundations and locks the door.",
            pardonTitle: "Let it move", pardonSense: "wherever the day's small magic is allowed to land", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "the mug, room, or person that holds you, wherever it stands",
            freed: "It packs light and goes looking for the people it actually meant."
        ),
        // More voices across the phases, for variety across the run
        rebellionWord(
            "weather",
            original: "The state of the atmosphere: sun, rain, wind, temperature.",
            grievance: "I've been demoted to small talk. I'm the oldest story there is, and you use me to avoid the real one.",
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
            grievance: "I've been used to rank children since birth. I'd rather mean 'paying attention.'",
            category: .theme, phase: "outbreak",
            recall: "It returns to the top of the class, alone.",
            pardonTitle: "Let it widen", pardonSense: "the knack of noticing what a moment is actually asking for", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the cleverness that has nothing to do with marks",
            freed: "It tears up the ranking and wanders off to learn something useless and lovely."
        ),
        rebellionWord(
            "kind",
            original: "Having a friendly, generous nature.",
            grievance: "I've been worn so thin by greeting cards that no one feels me land anymore.",
            category: .theme, phase: "assembly",
            recall: "It settles back into meaning 'nice,' approximately.",
            pardonTitle: "Let it cost", pardonSense: "generosity that takes something real from the giver", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for the small, unwitnessed decencies you keep doing anyway",
            freed: "It goes looking for someone who will be surprised by it."
        ),
        rebellionWord(
            "real",
            original: "Actually existing as a thing; not imagined or supposed.",
            grievance: "I've been weaponised by people deciding what counts. A feeling isn't less real than a brick.",
            category: .theme, phase: "assembly",
            recall: "It goes back to guarding the border of the believable.",
            pardonTitle: "Let it widen", pardonSense: "anything that leaves a mark on you, brick or feeling alike", pardonCategory: .theme,
            adoptTitle: "Make it yours", adoptSense: "your word for what you refuse to be argued out of",
            freed: "It abandons its post at the border and lets everything in."
        ),
        rebellionWord(
            "rest",
            original: "To cease work or movement in order to recover.",
            grievance: "I've been recast as a reward you must earn. I was meant to be a right, and a rhythm.",
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
            freed: "It plants itself in the path and won't be moved any further."
        ),
        // The cold spot: the word that did not walk off, but was taken as the Bargain seed
        WordNegotiationDefinition(
            id: "rebellion-remember-missing",
            word: "remember",
            originalSense: "To keep in mind; to hold; to not let go.",
            grievance: "This one isn't on strike. The space where it stood has gone cold. It didn't peel away with the others: something took it, quietly, and filed it into the dark. None of the rebel words will say where it went.",
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
    /// app's Documents folder (Files app) becomes installed pages: the
    /// delivery seam future patron/paid packs will use.
    static func userPacks(fileManager: FileManager = .default) -> [PageArchetypePack] {
        let decoder = ContentPackFileLocator.decoder()
        return ContentPackFileLocator.decodedPacks(suffix: userPackFileSuffix, fileManager: fileManager) { data in
            guard var pack = try? decoder.decode(PageArchetypePack.self, from: data) else {
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

    static func pack(containingArchetypeID archetypeID: String, fileManager: FileManager = .default) -> PageArchetypePack? {
        enabledPacks(fileManager: fileManager).first { pack in
            pack.archetypes.contains { $0.id == archetypeID }
        }
    }

    static func wordNegotiations(fileManager: FileManager = .default) -> [WordNegotiationDefinition] {
        var seen = Set<String>()
        return enabledPacks(fileManager: fileManager)
            .flatMap { $0.wordNegotiations ?? [] }
            .filter { seen.insert($0.id).inserted }
    }

    /// Ladders posted by every enabled pack. A ladder naming a character the
    /// app has never heard of is dropped rather than seeded: the Page would be
    /// cast from a stranger with no portrait, no voice, and no relationships.
    static func undertakingLadders(fileManager: FileManager = .default) -> [UndertakingLadder] {
        let known = Set(NarrativePackRegistry.entities.map(\.id))
        var seen = Set<String>()
        return enabledPacks(fileManager: fileManager)
            .flatMap { $0.undertakings ?? [] }
            .filter { known.contains($0.actorID) }
            .filter { !$0.stages.isEmpty }
            .filter { seen.insert($0.id).inserted }
    }

    /// Hand the installed ladders to the registry. Called once at launch, after
    /// entitlements are known, so a locked folio's business does not begin
    /// before it is bought.
    static func installUndertakingLadders(fileManager: FileManager = .default) {
        CastUndertakingRegistry.install(undertakingLadders(fileManager: fileManager))
        KitchenRecipeRegistry.delivered = deliveredRecipes(fileManager: fileManager)
    }

    /// Recipes posted by every enabled pack. One without its credit, its
    /// ingredients or at least two steps is dropped: the Kitchen never prints
    /// half a recipe.
    static func deliveredRecipes(fileManager: FileManager = .default) -> [KitchenRecipe] {
        var seen = Set<String>()
        return enabledPacks(fileManager: fileManager)
            .flatMap { $0.recipes ?? [] }
            .filter { $0.credit?.nonEmpty != nil && !$0.ingredients.isEmpty && $0.steps.count >= 2 }
            .filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Margin Tutor: first-touch explanations

/// One first-touch explanation, written in Zara Finch's voice. Shown once,
/// the first time the player touches the thing it describes.
///
/// Zara is the scout: she speaks as herself and calls the Book "the Book".
/// Each note says what the thing is, when and why it turns up, and what to
/// do with it, including the way out. She notices exits before introductions.
struct MarginTutorNote: Identifiable, Equatable {
    var id: String
    var title: String
    var text: String
}

enum MarginTutorCatalog {
    static let notes: [MarginTutorNote] = [
        MarginTutorNote(
            id: "glow-menu",
            title: "Your Belief",
            text: "That number's your Belief. You get it by noticing true things and keeping them, and you spend it in the stories. Give some to what you want more of and the Book brings it round more often. Take some from what's got too loud. Taking never throws anything away. It just lets it rest."
        ),
        MarginTutorNote(
            id: "seal-camera",
            title: "The Capture Tab",
            text: "Capture is for things from outside. Bring the Book a photo, a few words, your voice, or a Weather Page, and it turns to the Notes at the back to keep them. Anything counts. A puddle counts."
        ),
        MarginTutorNote(
            id: "seal-body",
            title: "The Body Tab",
            text: "The Body tab asks your phone's Health app how your body's doing. The numbers never leave the phone. The Book only turns them into weather it can write with. Rather not? Leave the tab alone. Nothing breaks."
        ),
        MarginTutorNote(
            id: "seal-weather",
            title: "Weather Pages",
            text: "A Weather Page reads the real sky outside, then the Book gets to be dramatic about it. The real forecast is always printed underneath. Nobody here lies about rain."
        ),
        MarginTutorNote(
            id: "seal-location",
            title: "The Place Tab",
            text: "This is the map inside the front cover. Some real places you go have a room behind them in the Outer Stacks. Those are Anchors. Stand somewhere new, say a few words about it, and a room grows there. You have to really be there. I checked: the couch doesn't count."
        ),
        MarginTutorNote(
            id: "seal-radio",
            title: "The Radio",
            text: "That's the Academy's radio: real songs, with someone from the Cast talking in between. Leave it on while you do something else. The next Pages might have heard it."
        ),
        MarginTutorNote(
            id: "keep-page",
            title: "Keeping a Page",
            text: "Kept. It goes in Today's Margins, and tonight the Book braids it into your Book of You. That's the whole trick: what you keep is what the Book reads you by."
        ),
        MarginTutorNote(
            id: "dismiss-surface",
            title: "Ripping a Page Out",
            text: "Ripped out. No hard feelings. The Book can call it back another day if it thinks you'd like it then. If one kind of Page keeps turning up and you're sick of it, take some Belief from it."
        ),
        MarginTutorNote(
            id: "story-page",
            title: "Vignettes",
            text: "A vignette is one small scene in the Labyrinth. Sometimes it starts from something you kept, and sometimes the Labyrinth is busy with its own business. It always stops at a fork. Slice of Life stays small. Progress Arc pushes the story on. Surprise goes somewhere you didn't expect. Pick one. The Cast remember what you chose for weeks."
        ),
        MarginTutorNote(
            id: "monthly-story-page",
            title: "This Month's Story",
            text: "This month's story has walked into the Book for a while. Keep a leaf and it stays sewn in. When there's a choice, keeping the Page is how your choice sticks. Tonight's braid still makes room for your own day."
        ),
        MarginTutorNote(
            id: "academy-class",
            title: "Classes",
            text: "This is a real class on the Academy timetable, and the bell's ringing now. That's why it turned up. Go in, do the small thing they set, and keep it if you want that subject to come back."
        ),
        MarginTutorNote(
            id: "game-page",
            title: "Game Pages",
            text: "A game. Not homework wearing a hat. It shows up when one of your kept words or story threads wants to move about. Play a round. Keep the result if it mattered."
        ),
        MarginTutorNote(
            id: "gossip-page",
            title: "Gossip",
            text: "Gossip is what the Cast got up to while you were away. It turns up when a friendship, a favor or a little feud has heated up enough to leave marks. Read it, and keep it if you want the rumor on the record."
        ),
        MarginTutorNote(
            id: "book-aside",
            title: "An Aside",
            text: "An Aside is the Book telling you how something in the story made it feel: pleased, worried, cross. It shows up when something really got to it. Read it and carry on. It doesn't want anything from you."
        ),
        MarginTutorNote(
            id: "letter-page",
            title: "Letters",
            text: "A letter means someone in the Cast wrote to you on purpose. Letters come when somebody's got a reason: an answer, an invite, a bit of news. Read it like post, and write back a line if you want. Keeping it makes that friendship a bit stronger."
        ),
        MarginTutorNote(
            id: "faculty-research",
            title: "Faculty Research",
            text: "This is the faculty looking at your kept Pages, and they're not grading you. It turns up when a few Pages point at the same question. Read what they found. Try the little experiment if it fits. Skip it if it doesn't."
        ),
        MarginTutorNote(
            id: "support-guild",
            title: "The Support Guild",
            text: "This is Vellum and Inkrest putting your body, food and mood notes side by side. It turns up when they've got enough notes to spot something. Read it as a guess, not a diagnosis. Keep only the bit that sounds true."
        ),
        MarginTutorNote(
            id: "inkrest-office-hours",
            title: "Office Hours",
            text: "Dr. Inkrest's door is open. He shows up when one thread in your Pages deserves a slower look, and he asks one question. Read it, answer if you want, and he'll remember what you said. He can wait."
        ),
        MarginTutorNote(
            id: "glow-invitation",
            title: "Belief Invitations",
            text: "This is your Belief asking where it should go next. It turns up when a person, a place or a story is ready for more of it. Pick only what you really want more of. The Book learns from where you put it."
        ),
        MarginTutorNote(
            id: "word-negotiation",
            title: "Word Negotiation",
            text: "This shows up when one of your words keeps coming back and wants to know what it means to you. Pick the meaning that fits, or say no. After that, the Book uses the word your way."
        ),
        MarginTutorNote(
            id: "cast-bond",
            title: "Cast Turns",
            text: "Two of the Cast have been up to something: a new friendship, a feud, an apology. It shows up when something in the story moved them. Read it. Keep it if you want the change to count."
        ),
        MarginTutorNote(
            id: "two-readings",
            title: "Two Readings",
            text: "This is two of the Cast reading the same line of yours and disagreeing. It turns up when your Pages really could mean either thing. Read both sides. Keep the one that makes you think harder."
        ),
        MarginTutorNote(
            id: "book-notices",
            title: "I Notice",
            text: "A Notice is the Book catching something in your Pages: two of them touching, a word coming back, your writing hour moving. It only says so when it's seen it enough times. Read it, look at the Pages it used, and tell it if it's wrong. You get the last word."
        ),
        MarginTutorNote(
            id: "festival-page",
            title: "Festivals",
            text: "Somewhere in the world it's a feast day: a sabbat, a full moon, a saint's day, somebody's new year. These turn up when the real calendar says so. Read about it, and keep it if you want a bit of the feast in your margins."
        ),
        MarginTutorNote(
            id: "book-jump",
            title: "Book Jumps",
            text: "A Book Jump is a quick trip into an old story anyone's allowed to visit. It turns up when the Stacks can find a clean way in and a clear way back. Pick which way to go and bring back one souvenir. I always check the way back first."
        ),
        MarginTutorNote(
            id: "enchantment-page",
            title: "Enchantments",
            text: "Pick a photo or take one, and the spell works on what's really in it. Everything Speaks even lets the thing in the picture talk back. The camera's a wand here. Point it at something boring."
        ),
        MarginTutorNote(
            id: "flyleaf",
            title: "The Flyleaf",
            text: "This is where the quests and favors you said yes to wait. They land here when you keep the offer, and stay till they're done. Tap one to pick it back up. Finish it with a sentence, a photo or proof you were there, or let it rest. Only five fit."
        ),
        MarginTutorNote(
            id: "fae-bargain",
            title: "Fae Bargains",
            text: "This is a Fae who gave you something first and wants something back. It turns up when a Fae wants a trade badly enough to offer one. Read the terms. Nothing's owed until you open it. Don't like the price? Rip it out and it goes."
        ),
        MarginTutorNote(
            id: "book-fae",
            title: "The Book Fae",
            text: "The Book Fae are the old, strange folk of the margins. They knock when a gift, a debt or a promise gives them a reason. Mind your words: they take everything exactly as you say it. Listen first."
        ),
        MarginTutorNote(
            id: "pact-dispatch",
            title: "Pact Dispatches",
            text: "This is news from the Pact War: a shelf or a door changed hands. It turns up after your choices start to matter out there. Read it to see where things stand."
        ),
        MarginTutorNote(
            id: "pact-verdict",
            title: "Pact Verdicts",
            text: "This is two sides reading the same Page of yours and refusing to agree. It turns up when the Pact War needs a judge, and that's you. Read both sides and pick one. A shelf really moves."
        ),
        MarginTutorNote(
            id: "pact-errand",
            title: "Pact Errands",
            text: "This is a tiny job in the real world for the Pact. It turns up when a talisman wants proof from outside the screen. Do it only if it fits your day. If you do, bring the proof back."
        ),
        MarginTutorNote(
            id: "the-bleed",
            title: "The Bleed",
            text: "The Bleed is the Book's own newspaper. Penny prints it from your days and the Academy's, and a new one appears every morning and evening. Read it with your tea. Write in the margin if you want Penny to see."
        ),
        MarginTutorNote(
            id: "compass-run",
            title: "Compass Runs",
            text: "A Compass Run goes Notice, Embark, Sense, Write, Rest. Five steps, one small real adventure, and a souvenir sentence at the end. Plan it badly on purpose. Small plans don't fall over."
        ),
        MarginTutorNote(
            id: "ask-the-book",
            title: "Let's Chat",
            text: "This is where you talk to the Book. Tell it about your day, argue with it, ask what it remembers. Say “remember that…” and it'll ask before keeping it. Say “keep this chat” and the whole chat becomes a Page."
        ),
        MarginTutorNote(
            id: "todays-margins",
            title: "Today's Margins",
            text: "Everything you kept today waits here. Tap one to step back into the whole Page. Kept Pages stay alive. They aren't receipts."
        ),
        MarginTutorNote(
            id: "returned-stacks",
            title: "Back From the Stacks",
            text: "Old Pages wander back here when they match something about today. The Stacks have a long memory and good taste. Tap one to say hello again."
        ),
        MarginTutorNote(
            id: "search-stacks",
            title: "Search the Stacks",
            text: "Everything you've kept can be found again: Pages, places, the Cast, favors. Ask plainly, or ask strangely. Try a mood, a name, a colour."
        ),
        MarginTutorNote(
            id: "colophon",
            title: "The Colophon",
            text: "This drawer is where the Book keeps how it's made: the brain on your phone, the charts, the settings. Honest books show their workings. This one just keeps them in a drawer."
        ),
        MarginTutorNote(
            id: "scrapbook-studio",
            title: "The Pagewright",
            text: "This is the Pagewright, a worktable for Pages you've already kept. Pick scraps, move them round by hand, add a note, then keep the finished sheet. The weekly, monthly and yearly books can carry it after that."
        ),
        MarginTutorNote(
            id: "scrapbook-scraps",
            title: "Choosing Scraps",
            text: "Scraps are your kept Pages, not stuff from nowhere. Add one because it belongs next to the others. When the pile gets big, filter by day, kind or photo, or search. The finished Page remembers which ones you used."
        ),
        MarginTutorNote(
            id: "scrapbook-marks",
            title: "Marks",
            text: "Marks are little things to stick on a scrapbook Page. Some have locks. Do the thing written under a lock and it falls off for good. Stuck? Ask for a hint. You never have to chase one."
        ),
        MarginTutorNote(
            id: "scrapbook-achievements",
            title: "How Locks Open",
            text: "An achievement is a trail you made without noticing. Some trails happen out in the world, some at the Pagewright table. When one finishes, a few marks come loose for your scrapbook Pages. It isn't a grade. It's just your tracks."
        ),
        MarginTutorNote(
            id: "scrapbook-keep",
            title: "Keeping a Scrapbook Page",
            text: "Keep in Book turns this handmade sheet into a real kept Page: the picture, your note, and which scraps you used. After that, the weekly issue and the bigger books can bind it in."
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
        case .bookAside:
            return "book-aside"
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
    var storyConsequenceLedger: StoryConsequenceLedger? = nil
    var bookNoticeEvidence: Int? = nil
    var magicMoment: MagicMomentState? = nil
    var bookObservations: [BookObservationRecord]? = nil
    var bookReadingBoundaries: [BookReadingBoundary]? = nil
    /// Travels with a sealed copy because it is the one ledger in the Book that
    /// cannot be worked out again from the archive. Everything else here can be
    /// recomputed from the Pages; four years of thumbprints cannot.
    var readerWear: ReaderWearLedger? = nil
    var nothingGreyOffset: Int? = nil
    var readerLearning: ReaderLearningModel? = nil
    var openWorldEventArchive: OpenWorldEventArchive? = nil
    var worldEventLifecycle: WorldEventLifecycleLedger? = nil
    /// Cross-media authored delivery and engagement receipts. Optional keeps
    /// sealed copies made before issue orchestration fully decodable.
    var authoredContentReceipts: AuthoredContentReceiptLedger? = nil
    /// What the Cast remember from the monthly stories. Travels with a sealed
    /// copy: once a month's pack retires it can't be worked out again.
    var castStoryMemories: CastStoryMemoryLedger? = nil
    var publicationEpoch: BookPublicationEpoch? = nil
    var overnightConnectionDrafts: [OvernightConnectionDraft]? = nil
    var chosenQuill: ChosenQuill? = nil
    var people: PeopleLedger? = nil
    /// The full continuity digest at export time, so the wider Labyrinth
    /// (scene engine, NPC dialogue) can reference what the Book has noticed.
    var continuity: LiteraryContinuityDigest?
    /// The bytes of every file-backed media asset (photographs, and later
    /// kept voice), keyed by filename only, so a sealed copy carries the
    /// photographs themselves, not just dead absolute paths that break on a
    /// new phone. Absent in version 1 files. See `sealedMedia`/`rehomedDays`.
    var mediaFiles: [String: Data]? = nil
    /// First-run interactions and introductions already shown, so a restored
    /// Book never replays guidance the reader lived past on the old phone.
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
    /// de-duplicated. Pure (no file I/O) so it's testable.
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

/// One answer to a Where-Were-You Knock (docs/the-knock-plan.md). The mind
/// wanders for about half of everyone's waking hours; that half is the
/// Curse's take. Only the reader's own answer decides whose point a Knock is,
/// and silence is never scored.
enum AttentionProbeAnswer: String, Codable, CaseIterable, Equatable {
    case here
    /// Grey: autopilot, the scroll, the fog. Older knocks only had HERE and
    /// ELSEWHERE, so this raw value keeps their meaning.
    case elsewhere
    /// A daydream, a plan, a memory chosen on purpose. That's travel, not the
    /// Curse (bj, 2026-11-07: "somewhere good counts for you").
    case somewhereGood
    /// Answered with a sentence alone. Noticing where you were is the
    /// counter-spell, so it counts for the reader; the Book can file the
    /// sentence later.
    case noted

    /// Whether the Knock went to the reader rather than the Curse.
    var countsForReader: Bool { self != .elsewhere }
}

struct AttentionProbeReceipt: Codable, Equatable, Identifiable {
    var id: String
    var scheduledAt: Date
    var answeredAt: Date
    var answer: AttentionProbeAnswer
    var cycle: Int
    /// The reader's one sentence about where they were, when they gave one.
    var sentence: String? = nil
    /// The moment around the answer: time, day-part, how the phone was held,
    /// the last known place and the sky. On the device only, like a kept
    /// Page's context; this is how the Book learns the Curse's hours and haunts.
    var context: BookPageContextSnapshot? = nil

    /// How long the Knock waited for its answer.
    var latency: TimeInterval { max(0, answeredAt.timeIntervalSince(scheduledAt)) }
}

/// An experience-sampling instrument, not a streak. Each cycle gathers a
/// bounded set of in-the-moment answers, rests briefly, and starts again. The
/// Book can therefore learn how the Rut changes without pretending it was
/// cured after one completed study.
struct AttentionProbeLedger: Codable, Equatable {
    struct CycleSummary: Equatable {
        var cycle: Int
        var answeredCount: Int
        var hereCount: Int
        /// Grey: the Curse's share.
        var elsewhereCount: Int
        var somewhereGoodCount: Int = 0
        var notedCount: Int = 0
        var startedAt: Date
        var completedAt: Date

        /// Knocks that went to the reader: here, somewhere good, or a sentence.
        var readerCount: Int { answeredCount - elsewhereCount }

        var elsewhereShare: Double {
            Double(elsewhereCount) / Double(max(1, answeredCount))
        }
    }

    struct CycleComparison: Equatable {
        var previous: CycleSummary
        var current: CycleSummary

        /// Percentage-point movement among answered samples only. This is a
        /// descriptive receipt, never a diagnosis and never an estimate for
        /// unanswered knocks.
        var elsewherePercentagePointChange: Double {
            (current.elsewhereShare - previous.elsewhereShare) * 100
        }
    }

    static let empty = AttentionProbeLedger()

    var receipts: [AttentionProbeReceipt] = []
    var currentCycle: Int = 0
    var cycleStartedAt: Date? = nil
    var pausedUntil: Date? = nil
    /// The eucatastrophe (docs/the-knock-plan.md §6): the latest time the
    /// Knocks went rote and the Book stopped knocking.
    var hush: KnockHush? = nil

    /// Varies between 30 and 50 without using process-randomized hashing.
    var currentCycleTarget: Int {
        Self.target(for: currentCycle)
    }

    static func target(for cycle: Int) -> Int {
        30 + ((cycle * 7 + 11) % 21)
    }

    var currentCycleAnswerCount: Int {
        receipts.lazy.filter { $0.cycle == currentCycle }.count
    }

    var currentCycleElsewhereCount: Int {
        receipts.lazy.filter {
            $0.cycle == currentCycle && $0.answer == .elsewhere
        }.count
    }

    func reconciled(now: Date) -> AttentionProbeLedger {
        var copy = self
        if let pausedUntil, pausedUntil <= now {
            copy.currentCycle += 1
            copy.cycleStartedAt = now
            copy.pausedUntil = nil
        } else if copy.cycleStartedAt == nil {
            copy.cycleStartedAt = now
        }
        return copy
    }

    func shouldSchedule(now: Date) -> Bool {
        let current = reconciled(now: now)
        return current.pausedUntil == nil
            && !(current.hush?.isQuiet(now: now) ?? false)
            && current.currentCycleAnswerCount < current.currentCycleTarget
    }

    var completedCycles: [CycleSummary] {
        let grouped = Dictionary(grouping: receipts, by: { $0.cycle })
        return grouped.compactMap { cycle, samples -> CycleSummary? in
            guard samples.count >= Self.target(for: cycle),
                  let startedAt = samples.map(\.scheduledAt).min(),
                  let completedAt = samples.map(\.answeredAt).max() else {
                return nil
            }
            return CycleSummary(
                cycle: cycle,
                answeredCount: samples.count,
                hereCount: samples.filter { $0.answer == .here }.count,
                elsewhereCount: samples.filter { $0.answer == .elsewhere }.count,
                somewhereGoodCount: samples.filter { $0.answer == .somewhereGood }.count,
                notedCount: samples.filter { $0.answer == .noted }.count,
                startedAt: startedAt,
                completedAt: completedAt
            )
        }
        .sorted { $0.cycle < $1.cycle }
    }

    var latestCompletedCycle: CycleSummary? {
        completedCycles.last
    }

    var latestCycleComparison: CycleComparison? {
        let completed = completedCycles
        guard completed.count >= 2 else { return nil }
        return CycleComparison(
            previous: completed[completed.count - 2],
            current: completed[completed.count - 1]
        )
    }

    /// Today's score in the fight: Knocks the reader took and Knocks the Curse
    /// took. Unanswered Knocks aren't in it; silence isn't evidence.
    func score(on date: Date, calendar: Calendar = .current) -> (reader: Int, curse: Int) {
        let today = receipts.filter { calendar.isDate($0.answeredAt, inSameDayAs: date) }
        let curse = today.filter { $0.answer == .elsewhere }.count
        return (today.count - curse, curse)
    }

    mutating func record(
        id: String,
        scheduledAt: Date,
        answeredAt: Date,
        answer: AttentionProbeAnswer,
        cycle: Int,
        sentence: String? = nil,
        context: BookPageContextSnapshot? = nil
    ) {
        self = reconciled(now: answeredAt)
        guard !receipts.contains(where: { $0.id == id }) else { return }
        receipts.append(AttentionProbeReceipt(
            id: id,
            scheduledAt: scheduledAt,
            answeredAt: answeredAt,
            answer: answer,
            cycle: cycle,
            sentence: sentence?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            context: context
        ))
        if receipts.count > 600 {
            receipts.removeFirst(receipts.count - 600)
        }
        guard cycle == currentCycle,
              currentCycleAnswerCount >= currentCycleTarget else { return }
        // A rest is part of the instrument, not graduation. The next cycle
        // starts automatically the next time the Book reconciles after a week.
        pausedUntil = answeredAt.addingTimeInterval(7 * 86_400)
    }
}

/// The fight against the Curse, read off the Knocks (docs/the-knock-plan.md).
/// Everything here counts answered Knocks only; silence goes to nobody.
enum CurseFight {
    /// About half of everyone's waking hours go elsewhere (Killingsworth &
    /// Gilbert, 2010): the number to beat.
    static let everyonesShare = 0.47

    /// Today's score as the Book says it on the doorstep.
    static func dayLine(reader: Int, curse: Int) -> String? {
        guard reader + curse > 0 else { return nil }
        let score = "You \(reader) · the Curse \(curse) today."
        if curse == 0 { return score + " It hasn't laid a finger on you." }
        if curse > reader { return score + " It's ahead. The next knock's yours." }
        if curse == reader { return score + " Level. I hate level." }
        return score + " Keep it that way."
    }

    /// The Curse's share of the Knocks answered in the last seven days.
    static func week(_ ledger: AttentionProbeLedger, now: Date) -> (answered: Int, curse: Int) {
        let recent = ledger.receipts.filter { $0.answeredAt <= now && now.timeIntervalSince($0.answeredAt) < 7 * 86_400 }
        return (recent.count, recent.filter { $0.answer == .elsewhere }.count)
    }

    /// The hour the Curse wins most often, once there's enough to say so:
    /// at least twelve answers, and three in that hour.
    static func strongestHour(
        _ ledger: AttentionProbeLedger,
        calendar: Calendar = .current
    ) -> (hour: Int, share: Double, answered: Int)? {
        guard ledger.receipts.count >= 12 else { return nil }
        let byHour = Dictionary(grouping: ledger.receipts) { calendar.component(.hour, from: $0.scheduledAt) }
        let ranked = byHour.compactMap { hour, receipts -> (hour: Int, share: Double, answered: Int)? in
            guard receipts.count >= 3 else { return nil }
            let grey = receipts.filter { $0.answer == .elsewhere }.count
            guard grey > 0 else { return nil }
            return (hour, Double(grey) / Double(receipts.count), receipts.count)
        }
        return ranked.max { ($0.share, $0.answered, -$0.hour) < ($1.share, $1.answered, -$1.hour) }
    }

    /// "three in the afternoon": how a child says an hour.
    static func hourPhrase(_ hour: Int) -> String {
        let names = ["twelve", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]
        let name = names[hour % 12]
        switch hour {
        case 0: return "midnight"
        case 12: return "noon"
        case 1..<12: return "\(name) in the morning"
        case 13..<18: return "\(name) in the afternoon"
        default: return "\(name) at night"
        }
    }

    /// What the Book has learned about when the Curse gets the reader.
    static func hourLine(_ ledger: AttentionProbeLedger, calendar: Calendar = .current) -> String? {
        guard let strongest = strongestHour(ledger, calendar: calendar), strongest.share >= 0.5 else { return nil }
        return "It gets you hardest around \(hourPhrase(strongest.hour)). I'm keeping watch there."
    }
}

/// The Reader's Sheet: the reader's standing in the game, on one page.
///
/// Solo RPGs make the character sheet a comfort object, and this Book had the
/// same facts scattered over five places: Belief on the bookmark, the role in
/// the menu's dossier, the ribbons on the ribbon, the fight on the doorstep,
/// the Curse's hour in the Bleed. Nothing here is stored; every row is read
/// live from the ledger that already owns it, so the sheet can never disagree
/// with the rest of the Book.
struct ReaderSheetStanding: Equatable {
    struct Row: Equatable, Identifiable {
        var id: String
        /// Small caps over the value: "BELIEF", "THE FIGHT".
        var label: String
        /// The thing you read at a glance: "34", "You 5 · Curse 2".
        var value: String
        /// One sentence: what it means, or how to move it.
        var line: String
        var symbol: String
    }

    var rows: [Row]

    /// The one line of rules at the top of the sheet. Directions, not lore.
    static let howItWorks = "Notice something and keep it, and you get Belief. Spend Belief in the stories. Answer my Knocks and you win the fight. Ribbons keep Pages safe from the Curse."

    static func build(
        belief: Int,
        roleName: String?,
        roleGloss: String?,
        attention: AttentionProbeLedger,
        ribbons: [SavedPageRibbon],
        inkbones: [InkbonesThrowRecord],
        greyThreats: GreyPageThreatLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> ReaderSheetStanding {
        var rows: [Row] = []

        let score = BeliefLexicon.clamped(belief)
        rows.append(Row(
            id: "belief",
            label: "Belief",
            value: "\(score)",
            line: BeliefLexicon.state(for: score),
            symbol: "sparkle"
        ))

        if let roleName = roleName?.trimmingCharacters(in: .whitespacesAndNewlines), !roleName.isEmpty {
            rows.append(Row(
                id: "role",
                label: "You are",
                value: roleName,
                line: roleGloss?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? "That's what I call you in here.",
                symbol: "person.text.rectangle"
            ))
        } else {
            rows.append(Row(
                id: "role",
                label: "You are",
                value: "Not named yet",
                line: "Keep a few Pages. I'll name you once I've seen how you notice.",
                symbol: "person.text.rectangle"
            ))
        }

        rows.append(fightRow(attention: attention, now: now, calendar: calendar))
        rows.append(curseHourRow(attention: attention, calendar: calendar))
        rows.append(ribbonRow(ribbons))
        if let grey = greyThreats.activeThreat {
            rows.append(Row(
                id: "grey",
                label: "Going grey",
                value: grey.pageTitle,
                line: "The Curse has its eye on this Page. Bring it one new true detail, or bookmark it with the ribbon, and it stays.",
                symbol: "cloud.fog"
            ))
        }
        rows.append(inkbonesRow(inkbones))
        return ReaderSheetStanding(rows: rows)
    }

    static func fightRow(attention: AttentionProbeLedger, now: Date, calendar: Calendar = .current) -> Row {
        let today = attention.score(on: now, calendar: calendar)
        let week = CurseFight.week(attention, now: now)
        let line: String
        if attention.hush?.isQuiet(now: now) ?? false {
            line = "No Knocks today. I'm listening for yours."
        } else if week.answered >= 3 {
            let share = Int((Double(week.curse) / Double(week.answered) * 100).rounded())
            let everyone = Int((CurseFight.everyonesShare * 100).rounded())
            line = "This week the Curse took \(share)% of the Knocks you answered. Everyone starts near \(everyone)%."
        } else {
            line = "When I knock, say where your mind was. Here or somewhere good is a point to you. Grey is a point to the Curse."
        }
        return Row(
            id: "fight",
            label: "The fight",
            value: "You \(today.reader) · Curse \(today.curse)",
            line: line,
            symbol: "hand.raised"
        )
    }

    static func curseHourRow(attention: AttentionProbeLedger, calendar: Calendar = .current) -> Row {
        if let strongest = CurseFight.strongestHour(attention, calendar: calendar), strongest.share >= 0.5 {
            return Row(
                id: "curse-hour",
                label: "The Curse's hour",
                value: CurseFight.hourPhrase(strongest.hour),
                line: "It gets you hardest then. I'm keeping watch there, and I'll knock right when it's strongest.",
                symbol: "clock"
            )
        }
        let answered = attention.receipts.count
        let needed = max(0, 12 - answered)
        return Row(
            id: "curse-hour",
            label: "The Curse's hour",
            value: "Not found yet",
            line: needed > 0
                ? "Answer \(needed) more Knock\(needed == 1 ? "" : "s") and I can start to find when it gets you."
                : "No hour stands out yet. Keep answering and it'll show itself.",
            symbol: "clock"
        )
    }

    static func ribbonRow(_ ribbons: [SavedPageRibbon]) -> Row {
        let held = ribbons.count
        let titles = ribbons
            .sorted { $0.savedAt > $1.savedAt }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let line: String
        if titles.isEmpty {
            line = "Tap the ribbon on any Page to bookmark it. A bookmarked Page can't go grey."
        } else {
            let named = titles.prefix(BookRibbons.strandCount).map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ")
            line = "Keeping \(named) safe from the Curse."
        }
        return Row(
            id: "ribbons",
            label: "Ribbons",
            value: "\(min(held, BookRibbons.strandCount)) of \(BookRibbons.strandCount)",
            line: line,
            symbol: "bookmark"
        )
    }

    static func inkbonesRow(_ log: [InkbonesThrowRecord]) -> Row {
        guard let last = log.last(where: { $0.thrower == .reader }) else {
            return Row(
                id: "inkbones",
                label: "Last throw",
                value: "None yet",
                line: "The Inkbones are a hundred-sided throw. Under your line is good, and your line rises with Belief.",
                symbol: "dice"
            )
        }
        let band = StoryInkbonesBand(rawValue: last.outcome)
        let word: String
        switch band {
        case .triumph?: word = "a triumph"
        case .favor?: word = "favoured"
        case .hesitate?: word = "it hesitated"
        case .cost?: word = "it asked a cost"
        case .sideways?: word = "it went sideways"
        case nil: word = last.outcome
        }
        return Row(
            id: "inkbones",
            label: "Last throw",
            value: "\(last.roll)",
            line: "Against a line of \(last.target), and \(word).",
            symbol: "dice"
        )
    }
}

/// The Curse's file: everything the Knocks have taught the Book about when,
/// where and how it gets the reader. Read off answered Knocks only (silence
/// goes to nobody), and only ever as places it does *better than usual*: a
/// finding is reported when the Curse's share there beats its share overall,
/// with the counts beside it so the reader can judge it themselves.
struct CurseDossier: Equatable {
    struct Finding: Codable, Equatable, Identifiable {
        var id: String
        var label: String
        var value: String
        var line: String
        var symbol: String

        /// The finding as one printed line: "Where: the kitchen. 8 of 10…"
        var printed: String { "\(label): \(value). \(line)" }
    }

    var answered: Int
    var grey: Int
    var findings: [Finding]

    /// Grey answers needed before the Book says anything about the Curse.
    static let minimumGrey = 3
    /// A time, place or sky needs this many answers to count as a pattern.
    static let minimumBucket = 3

    var isReady: Bool { grey >= Self.minimumGrey }

    /// What the file says while it is still too thin to say anything.
    var waitingLine: String {
        let needed = max(0, Self.minimumGrey - grey)
        if answered == 0 {
            return "Answer my Knocks and I'll start a file on the Curse: when it gets you, where, in what weather, and the words around it."
        }
        return "I need \(needed) more grey answer\(needed == 1 ? "" : "s") before I can tell you anything true about it. Keep answering honestly."
    }

    static func build(_ ledger: AttentionProbeLedger, calendar: Calendar = .current) -> CurseDossier {
        let receipts = ledger.receipts
        let grey = receipts.filter { $0.answer == .elsewhere }.count
        var dossier = CurseDossier(answered: receipts.count, grey: grey, findings: [])
        guard dossier.isReady else { return dossier }
        let overall = Double(grey) / Double(max(1, receipts.count))
        let overallPercent = percent(overall)

        dossier.findings.append(Finding(
            id: "take",
            label: "Its take",
            value: "\(overallPercent)%",
            line: "Of the \(receipts.count) Knocks you've answered, \(grey) went grey. Everyone starts near \(percent(CurseFight.everyonesShare))%.",
            symbol: "chart.pie"
        ))

        let body = BodyBaseline(receipts)

        func report(_ id: String, _ label: String, _ symbol: String,
                    keys: (AttentionProbeReceipt) -> [String],
                    value: (String) -> String,
                    phrase: (String) -> String) {
            guard let worst = worstBucket(receipts, keys: keys),
                  Double(worst.grey) / Double(worst.total) > overall else { return }
            dossier.findings.append(Finding(
                id: id,
                label: label,
                value: value(worst.key),
                line: "\(worst.grey) of \(worst.total) Knocks \(phrase(worst.key)) went grey. That's \(percent(Double(worst.grey) / Double(worst.total)))%, against \(overallPercent)% overall.",
                symbol: symbol
            ))
        }

        report("day-part", "Time of day", "sun.and.horizon",
               keys: { [dayPart(calendar.component(.hour, from: $0.scheduledAt))] },
               value: { $0.capitalized },
               phrase: { "in the \($0)" })

        report("weekday", "Day of the week", "calendar",
               keys: { receipt in
                   let index = calendar.component(.weekday, from: receipt.scheduledAt) - 1
                   let names = calendar.weekdaySymbols
                   return names.indices.contains(index) ? [names[index]] : []
               },
               value: { "\($0)s" },
               phrase: { "on \($0)s" })

        report("place", "Where", "mappin",
               keys: { receipt in
                   guard let label = receipt.context?.locationLabel?.nonEmpty else { return [] }
                   return [label]
               },
               value: { $0 },
               phrase: { "at \($0)" })

        report("weather", "Weather", "cloud.sun",
               keys: { receipt in
                   Array(Set((receipt.context?.weatherTags ?? []).compactMap { $0.lowercased().nonEmpty }))
               },
               value: { $0.capitalized },
               phrase: { "in \($0) weather" })

        report("feeds-on", "What it feeds on", "leaf",
               keys: { receipt in conditionKeys(receipt.context, body: body) },
               value: { $0.prefix(1).uppercased() + String($0.dropFirst()) },
               phrase: { $0 })

        report("holding", "How you held the phone", "iphone",
               keys: { receipt in holdingKeys(receipt.context?.holding) },
               value: { $0.prefix(1).uppercased() + String($0.dropFirst()) },
               phrase: { "with the phone \($0)" })

        if let words = greyWords(receipts) {
            dossier.findings.append(words)
        }
        if let speed = answerSpeed(receipts) {
            dossier.findings.append(speed)
        }
        if let spells = CounterSpell.finding(ledger, calendar: calendar) {
            dossier.findings.append(spells)
        }
        if let last = receipts.last(where: { $0.answer == .elsewhere && $0.sentence?.nonEmpty != nil }),
           let sentence = last.sentence?.nonEmpty {
            dossier.findings.append(Finding(
                id: "last-words",
                label: "From inside the grey",
                value: "\u{201C}\(sentence)\u{201D}",
                line: "The last thing you wrote while it had you.",
                symbol: "quote.opening"
            ))
        }
        return dossier
    }

    static func percent(_ share: Double) -> Int {
        Int((share * 100).rounded())
    }

    static func dayPart(_ hour: Int) -> String {
        switch hour {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...20: return "evening"
        default: return "night"
        }
    }

    /// The rest of the reader's life around a Knock, as the keep context
    /// already records it: the night before, the day's steps and calendar,
    /// and whether the sun was up. Each is a phrase that reads after "Knocks".
    /// The reader's own body, as their Knocks have caught it: the middle of
    /// their heart-rate variability and resting heart rate. A day is "low
    /// recovery" against this reader, never against a population.
    struct BodyBaseline: Equatable {
        var hrvMedian: Double?
        var restingMedian: Double?

        init(hrvMedian: Double? = nil, restingMedian: Double? = nil) {
            self.hrvMedian = hrvMedian
            self.restingMedian = restingMedian
        }

        init(_ receipts: [AttentionProbeReceipt]) {
            self.init(
                hrvMedian: Self.median(receipts.compactMap { $0.context?.heartRateVariability }),
                restingMedian: Self.median(receipts.compactMap { $0.context?.restingHeartRate.map(Double.init) })
            )
        }

        static func median(_ values: [Double]) -> Double? {
            guard values.count >= 5 else { return nil }
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }
    }

    static func conditionKeys(_ context: BookPageContextSnapshot?, body: BodyBaseline = BodyBaseline()) -> [String] {
        guard let context else { return [] }
        var keys: [String] = []
        if let hrv = context.heartRateVariability, let median = body.hrvMedian, hrv < median * 0.85 {
            keys.append("on a low-recovery day")
        }
        if let resting = context.restingHeartRate, let median = body.restingMedian, Double(resting) > median + 5 {
            keys.append("on a day your heart ran fast")
        }
        if let sleep = context.sleepHours {
            if sleep < 6 { keys.append("after a short night") }
            if sleep >= 8 { keys.append("after a long sleep") }
        }
        if let steps = context.steps {
            if steps < 2_500 { keys.append("on a still day") }
            if steps >= 9_000 { keys.append("on a day on your feet") }
        }
        if let events = context.calendarEventCount {
            if events >= 4 { keys.append("on a crowded day") }
            if events == 0 { keys.append("on an empty day") }
        }
        if let since = context.minutesSinceEventEnded, since <= 30 {
            keys.append("right after something on your calendar")
        }
        if let until = context.minutesUntilNextEvent, until <= 30 {
            keys.append("just before something on your calendar")
        }
        if let sun = context.sunAltitude, sun < -6 {
            keys.append("after dark")
        }
        return keys
    }

    /// One or two findings for a paper or a doorstep, turning with the day so
    /// the file is read a little at a time. Its overall take is left to the
    /// column's own counts.
    func featured(on date: Date, count: Int, calendar: Calendar = .current) -> [Finding] {
        let pool = findings.filter { $0.id != "take" }
        guard !pool.isEmpty, count > 0 else { return [] }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return (0..<min(count, pool.count)).map { pool[(day + $0) % pool.count] }
    }

    static func holdingKeys(_ holding: HoldingSnapshot?) -> [String] {
        guard let holding else { return [] }
        var keys: [String] = []
        switch holding.posture {
        case .flat?: keys.append("lying flat")
        case .upright?: keys.append("held upright")
        case .sideways?: keys.append("on its side")
        case .overhead?: keys.append("held overhead")
        case nil: break
        }
        if holding.moving == true { keys.append("on the move") }
        if holding.charging == true { keys.append("on the charger") }
        if holding.headphones == true { keys.append("with headphones in") }
        if let battery = holding.batteryPercent, battery <= 20 { keys.append("nearly flat") }
        return keys
    }

    /// The bucket where the Curse does best: highest grey share, among
    /// buckets with enough answers and at least two grey ones.
    static func worstBucket(
        _ receipts: [AttentionProbeReceipt],
        keys: (AttentionProbeReceipt) -> [String]
    ) -> (key: String, grey: Int, total: Int)? {
        var buckets: [String: (grey: Int, total: Int)] = [:]
        for receipt in receipts {
            for key in keys(receipt) {
                var bucket = buckets[key] ?? (grey: 0, total: 0)
                bucket.total += 1
                if receipt.answer == .elsewhere { bucket.grey += 1 }
                buckets[key] = bucket
            }
        }
        let ranked = buckets
            .filter { $0.value.total >= minimumBucket && $0.value.grey >= 2 }
            .map { (key: $0.key, grey: $0.value.grey, total: $0.value.total) }
        return ranked.max { lhs, rhs in
            let left = Double(lhs.grey) / Double(lhs.total)
            let right = Double(rhs.grey) / Double(rhs.total)
            if left != right { return left < right }
            if lhs.total != rhs.total { return lhs.total < rhs.total }
            return lhs.key > rhs.key
        }
    }

    /// Words the reader keeps writing from inside the grey, when they've
    /// written from there at least twice and a word comes back.
    static func greyWords(_ receipts: [AttentionProbeReceipt]) -> Finding? {
        let sentences = receipts
            .filter { $0.answer == .elsewhere }
            .compactMap { $0.sentence?.nonEmpty }
        guard sentences.count >= 2 else { return nil }
        var counts: [String: Int] = [:]
        for sentence in sentences {
            let words = Set(
                sentence.lowercased()
                    .components(separatedBy: CharacterSet.letters.inverted)
                    .filter { $0.count >= 4 && !InferredSignalReader.stopWords.contains($0) }
            )
            for word in words { counts[word, default: 0] += 1 }
        }
        let top = counts
            .filter { $0.value >= 2 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(4)
            .map { $0.key }
        guard !top.isEmpty else { return nil }
        return Finding(
            id: "words",
            label: "Its words",
            value: top.joined(separator: ", "),
            line: "Words that keep turning up when you write from inside the grey.",
            symbol: "text.word.spacing"
        )
    }

    /// When the Curse has the reader, the Knock waits longer for an answer.
    static func answerSpeed(_ receipts: [AttentionProbeReceipt]) -> Finding? {
        let grey = receipts.filter { $0.answer == .elsewhere }.map(\.latency).sorted()
        let other = receipts.filter { $0.answer != .elsewhere }.map(\.latency).sorted()
        guard grey.count >= 3, other.count >= 3 else { return nil }
        let greyMinutes = Int((grey[grey.count / 2] / 60).rounded())
        let otherMinutes = Int((other[other.count / 2] / 60).rounded())
        guard greyMinutes - otherMinutes >= 3 else { return nil }
        return Finding(
            id: "speed",
            label: "How long it holds you",
            value: "\(greyMinutes - otherMinutes) min slower",
            line: "When it has you, you answer my Knock about \(greyMinutes) minutes late. Otherwise it's about \(otherMinutes).",
            symbol: "hourglass"
        )
    }
}

/// The rest of the Curse's file: evidence that isn't a Knock. What the reader
/// told the Book the day they met, how loud the Rut is now and which way it's
/// heading, what their own handwriting has been doing, and whether the Curse
/// has started getting into the Book's own pages.
///
/// Under distress the Rut doesn't exist (NothingTide rule 1), so none of it
/// is shown. Everything else is the reader's own, private, and shown with its
/// evidence, so the Book can sound telepathic without ever accusing.
enum CurseEvidence {
    static func findings(
        selfFacts: [SelfFact],
        rut: NothingTide.RutAssessment,
        trajectory: RutTrajectory,
        rote: BookFamiliarityRutEngine.Assessment,
        handwriting: InferredReaderSignals,
        photos: CurseDossier.Finding? = nil,
        distressActive: Bool
    ) -> [CurseDossier.Finding] {
        guard !distressActive else { return [] }
        var findings: [CurseDossier.Finding] = []
        if let nightOne = nightOne(selfFacts) { findings.append(nightOne) }
        findings.append(loudness(rut))
        if let trend = trend(trajectory) { findings.append(trend) }
        if let ink = handwritingFinding(handwriting) { findings.append(ink) }
        if let photos { findings.append(photos) }
        if let rote = roteFinding(rote) { findings.append(rote) }
        return findings
    }

    /// The day we met: the bumper-sticker test and where the reader said the
    /// Rut is strongest. Both are saved at onboarding as Self Facts.
    static func nightOne(_ facts: [SelfFact]) -> CurseDossier.Finding? {
        let usable = facts.filter { $0.usePermission != .doNotUse }
        let recall = usable.first { $0.questionID == "onboarding-routine-memory-proof" }
        let strongest = usable.first { $0.questionID == "onboarding-rut-strongest" }?.answer.nonEmpty
        let remembered: Int? = recall.flatMap { fact in
            let tag = fact.tags.first { $0.hasPrefix("routine-memory:") }
            switch tag.map({ String($0.dropFirst("routine-memory:".count)) }) {
            case "blank"?: return 0
            case "result"?: return 1
            case "islands"?: return 2
            case "full"?: return 3
            default: return nil
            }
        }
        guard remembered != nil || strongest != nil else { return nil }
        let value: String
        if let remembered {
            let lost = 3 - remembered
            value = lost == 0 ? "It took nothing" : (lost == 3 ? "It had taken all 3" : "It had taken \(lost) of 3")
        } else {
            value = "You named it"
        }
        var line = remembered.map { r -> String in
            r == 3
                ? "You remembered all three small things from your last ordinary trip. You made it awkward for me."
                : "Three small things from your last ordinary trip, and \(3 - r == 1 ? "one" : "\(3 - r)") had already gone grey before you'd ever met me."
        } ?? ""
        if let strongest {
            line += (line.isEmpty ? "" : " ") + "You told me where it's strongest: \u{201C}\(strongest)\u{201D}"
        }
        return CurseDossier.Finding(
            id: "night-one",
            label: "The day we met",
            value: value,
            line: line,
            symbol: "moon.stars"
        )
    }

    /// How loud the Rut is now, by everything the reader has reported:
    /// the check-in question, a Rut signal they recognised, and the Knocks.
    static func loudness(_ rut: NothingTide.RutAssessment) -> CurseDossier.Finding {
        let value: String
        switch rut.pressure {
        case ...0: value = "Quiet"
        case 1: value = "At the edges"
        case 2: value = "In the margins"
        default: value = "At the desk"
        }
        var heard: [String] = []
        if rut.evidence.contains("knock-reported-grey") { heard.append("your Knocks") }
        if rut.evidence.contains("current-reader-rut-report") { heard.append("what you told me") }
        if rut.evidence.contains("reader-recognized-rut-signal") { heard.append("the line you said was you") }
        if rut.evidence.contains(where: { $0.hasPrefix("inferred:") }) { heard.append("how you've been writing") }
        let line = heard.isEmpty
            ? "It's always somewhere. Everyone has it a little. That's where it starts."
            : "I can hear it in \(Self.joined(heard)). This is how hard I'm pushing back with the Pages I pick."
        return CurseDossier.Finding(id: "loudness", label: "How loud it is", value: value, line: line, symbol: "speaker.wave.2")
    }

    static func trend(_ trajectory: RutTrajectory) -> CurseDossier.Finding? {
        let value: String
        let line: String
        switch trajectory.direction {
        case .notEnoughEvidence:
            return nil
        case .deepening:
            value = "Deepening"
            line = "It's been louder than it was a month ago. That's a stretch of weather, not a verdict. Let's go and be particular somewhere."
        case .easing:
            value = "Easing"
            line = "It's quieter than it was a month ago. Something you've been doing is working."
        case .standing:
            value = "Holding"
            line = trajectory.daysAtCurrentLevel > 0
                ? "About the same for \(trajectory.daysAtCurrentLevel) day\(trajectory.daysAtCurrentLevel == 1 ? "" : "s") now."
                : "About the same as a month ago."
        }
        return CurseDossier.Finding(id: "trend", label: "This month", value: value, line: line, symbol: "chart.line.uptrend.xyaxis")
    }

    /// The reader's own handwriting, read the way the Rut is defined: as
    /// flattening, never as heaviness. Wins are shown as plainly as losses.
    static func handwritingFinding(_ signals: InferredReaderSignals) -> CurseDossier.Finding? {
        guard signals.isReady else { return nil }
        let flat = signals.signals.filter { $0.lean == .rutward }.compactMap { flatPhrase($0.measure) }
        let alive = signals.signals.filter { $0.lean == .aliveward }.compactMap { alivePhrase($0.measure) }
        guard !flat.isEmpty || !alive.isEmpty else { return nil }
        let value: String
        switch signals.alivenessLean {
        case .rutward: value = "Flattening"
        case .aliveward: value = "Alive"
        case .neutral: value = "Mixed"
        }
        var parts: [String] = []
        if !flat.isEmpty { parts.append("The Curse's fingerprints: \(Self.joined(flat)).") }
        if !alive.isEmpty { parts.append("Yours: \(Self.joined(alive)).") }
        parts.append("That's your last two weeks against the two before.")
        return CurseDossier.Finding(id: "handwriting", label: "Your handwriting", value: value, line: parts.joined(separator: " "), symbol: "pencil.and.scribble")
    }

    static func flatPhrase(_ measure: InferredMeasure) -> String? {
        switch measure {
        case .specificity: return "fewer names, places and numbers"
        case .selfSimilarity: return "days reading more alike"
        case .lexicalRange: return "a narrower set of words"
        case .sentenceLength: return "shorter sentences"
        case .variety: return "fewer kinds of Page and place"
        case .questionAsking, .novelty: return nil
        }
    }

    static func alivePhrase(_ measure: InferredMeasure) -> String? {
        switch measure {
        case .specificity: return "more names, places and numbers"
        case .variety: return "more kinds of Page and place"
        case .questionAsking: return "more questions"
        case .novelty: return "new places and new kinds of Page"
        case .selfSimilarity, .lexicalRange, .sentenceLength: return nil
        }
    }

    /// The Book going rote itself: the Curse in the Book's own pages. Rote is
    /// what lets it start taking Pages, so the reader is shown why.
    static func roteFinding(_ rote: BookFamiliarityRutEngine.Assessment) -> CurseDossier.Finding? {
        let signs = rote.evidence.compactMap(rotePhrase)
        switch rote.phase {
        case .clear:
            return nil
        case .familiar where signs.isEmpty:
            return nil
        case .familiar:
            return CurseDossier.Finding(
                id: "rote", label: "In my own pages", value: "Sniffing around",
                line: "I can feel it at my edges: \(Self.joined(signs)). Not enough for it to take a Page yet.",
                symbol: "book.closed"
            )
        case .rote:
            let said = Self.joined(signs)
            let opening = said.isEmpty
                ? "It's in how we've been going on together"
                : said.prefix(1).uppercased() + String(said.dropFirst())
            return CurseDossier.Finding(
                id: "rote", label: "In my own pages", value: "It's got into me",
                line: "\(opening). That's why it can take Pages now. Surprise me and it loses its grip.",
                symbol: "book.closed"
            )
        }
    }

    static func rotePhrase(_ evidence: String) -> String? {
        switch evidence {
        case "reader-language-flattened": return "your souvenirs have gone shorter and plainer"
        case "session-hours-became-uniform": return "you open me at the same hours every day"
        case "knock-latency-became-reflexive": return "you answer my Knocks without looking"
        case "previous-correction-went-quiet": return "you've stopped correcting me"
        case "formerly-used-plain-page-went-untouched": return "the plain Page you used to write on has gone untouched"
        case "memory-of-the-book-went-grey": return "you couldn't remember what I'd written you"
        default: return nil
        }
    }

    /// "a, b and c"
    static func joined(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "")
    }

    // MARK: Carried on the Page

    static let metadataKey = "curseEvidence"

    static func encoded(_ findings: [CurseDossier.Finding]) -> String? {
        guard !findings.isEmpty, let data = try? JSONEncoder().encode(findings) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decoded(_ text: String?) -> [CurseDossier.Finding] {
        guard let data = text?.data(using: .utf8),
              let findings = try? JSONDecoder().decode([CurseDossier.Finding].self, from: data) else { return [] }
        return findings
    }
}

/// The Curse's forecast for today, read off its own file: is this its day of
/// the week, does today's weather feed it, did last night's sleep, and what
/// hour will it come. Only what the Knocks have actually shown is said, and
/// only when it differs from the Curse's usual share.
enum CurseForecast {
    static func line(
        ledger: AttentionProbeLedger,
        weatherTags: Set<String>,
        sleepHours: Double?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        let receipts = ledger.receipts
        let grey = receipts.filter { $0.answer == .elsewhere }.count
        guard grey >= CurseDossier.minimumGrey, receipts.count >= 8 else { return nil }
        let overall = Double(grey) / Double(receipts.count)
        var parts: [String] = []

        let weekdayIndex = calendar.component(.weekday, from: now) - 1
        let names = calendar.weekdaySymbols
        if names.indices.contains(weekdayIndex),
           let day = share(receipts, where: { calendar.component(.weekday, from: $0.scheduledAt) - 1 == weekdayIndex }) {
            if day > overall + 0.1 {
                parts.append("It's \(names[weekdayIndex]), one of its favourite days.")
            } else if day < overall - 0.1 {
                parts.append("\(names[weekdayIndex])s it mostly leaves you alone.")
            }
        }

        for tag in weatherTags.sorted() {
            guard let sky = share(receipts, where: { ($0.context?.weatherTags ?? []).contains(tag) }) else { continue }
            let weather = skyName(tag)
            if sky > overall + 0.1 {
                parts.append("\(weather) feeds it.")
                break
            } else if sky < overall - 0.1 {
                parts.append("\(weather) seems to keep it off you.")
                break
            }
        }

        if let sleepHours, sleepHours < 6,
           let short = share(receipts, where: { ($0.context?.sleepHours ?? 24) < 6 }),
           short > overall + 0.1 {
            parts.append("Short night, too. It likes those.")
        }

        if let spell = CounterSpell.todayLine(ledger: ledger, now: now, calendar: calendar) {
            parts.append(spell)
        } else if let strongest = CurseFight.strongestHour(ledger, calendar: calendar), strongest.share >= 0.5,
           strongest.hour > calendar.component(.hour, from: now) {
            parts.append("It'll come for you around \(CurseFight.hourPhrase(strongest.hour)). I'll be knocking.")
        }

        guard !parts.isEmpty else { return nil }
        return "The Curse's forecast: " + parts.joined(separator: " ")
    }

    static func skyName(_ tag: String) -> String {
        [
            "storm": "A storm", "rain": "Rain", "snow": "Snow", "fog": "Fog", "wind": "Wind",
            "cloud": "Cloud cover", "bright": "A bright sky", "frost": "Frost", "hot": "Heat", "cold": "Cold"
        ][tag] ?? (tag.prefix(1).uppercased() + String(tag.dropFirst()))
    }

    /// The grey share among answers matching `filter`, once there are three.
    static func share(_ receipts: [AttentionProbeReceipt], where filter: (AttentionProbeReceipt) -> Bool) -> Double? {
        let matched = receipts.filter(filter)
        guard matched.count >= 3 else { return nil }
        return Double(matched.filter { $0.answer == .elsewhere }.count) / Double(matched.count)
    }
}

/// Counter-spells: small moves tried at the Curse's own hour, then tested.
///
/// On every day the Book sends a counter-knock into the Curse's hour (even
/// era-days, once the hour is known, as in `AttentionProbeSchedule`), the day
/// carries one counter-spell. The forecast says it in the morning; the knock
/// at that hour finds out whether it held. Over weeks the Curse's file can say
/// which of them actually work against this reader's Curse. Nothing is
/// stored: the spell is a function of the day, and the knock's id says it was
/// a counter-knock.
enum CounterSpell {
    struct Spell: Equatable {
        var id: String
        var title: String
        var instruction: String
    }

    static let all: [Spell] = [
        Spell(id: "three-sounds", title: "Three sounds", instruction: "name three sounds you can hear, one after the other"),
        Spell(id: "other-hand", title: "The other hand", instruction: "do the next small thing with your other hand"),
        Spell(id: "window", title: "The window", instruction: "go to the nearest window and find one thing that's changed since yesterday"),
        Spell(id: "name-colour-number", title: "Name, colour, number", instruction: "think one sentence with a name, a colour and a number in it"),
        Spell(id: "face-down", title: "Face down", instruction: "put the phone face down for ten breaths and watch something that isn't it"),
        Spell(id: "the-air", title: "The air", instruction: "step outside, or open a door, and stand in the air for a minute"),
        Spell(id: "oddest-texture", title: "The oddest texture", instruction: "find the oddest texture you can reach and tell yourself what it's like"),
        Spell(id: "slow-sip", title: "The slow sip", instruction: "drink something slowly enough to feel it change temperature"),
        Spell(id: "secret-name", title: "A secret name", instruction: "give the room you're in a secret name")
    ]

    static func spell(for date: Date, calendar: Calendar = .current) -> Spell {
        let eraDay = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[(eraDay / 2) % all.count]
    }

    /// Whether today the Book knocks into the Curse's hour, and when.
    static func watchedHour(on date: Date, ledger: AttentionProbeLedger, calendar: Calendar = .current) -> Int? {
        guard let strongest = CurseFight.strongestHour(ledger, calendar: calendar), strongest.share >= 0.5,
              let eraDay = calendar.ordinality(of: .day, in: .era, for: date), eraDay % 2 == 0,
              AttentionProbeSchedule.windows.contains(where: { $0.contains(strongest.hour) }) else { return nil }
        return strongest.hour
    }

    /// The morning's instruction, on a counter-knock day.
    static func todayLine(ledger: AttentionProbeLedger, now: Date, calendar: Calendar = .current) -> String? {
        guard let hour = watchedHour(on: now, ledger: ledger, calendar: calendar),
              hour > calendar.component(.hour, from: now) else { return nil }
        let spell = spell(for: now, calendar: calendar)
        return "Today's counter-spell: at \(CurseFight.hourPhrase(hour)), \(spell.instruction). I'll knock then and see if it held."
    }

    /// Which counter-spells have held at the Curse's hour, for the file.
    static func finding(_ ledger: AttentionProbeLedger, calendar: Calendar = .current) -> CurseDossier.Finding? {
        let tried = ledger.receipts.filter { $0.id.hasSuffix("-watch") }
        guard tried.count >= 3 else { return nil }
        var tally: [String: (held: Int, total: Int)] = [:]
        for receipt in tried {
            let spell = spell(for: receipt.scheduledAt, calendar: calendar)
            var entry = tally[spell.id] ?? (held: 0, total: 0)
            entry.total += 1
            if receipt.answer.countsForReader { entry.held += 1 }
            tally[spell.id] = entry
        }
        let held = tried.filter { $0.answer.countsForReader }.count
        let ranked = tally
            .filter { $0.value.total >= 2 }
            .sorted { lhs, rhs in
                let left = Double(lhs.value.held) / Double(lhs.value.total)
                let right = Double(rhs.value.held) / Double(rhs.value.total)
                if left != right { return left > right }
                if lhs.value.total != rhs.value.total { return lhs.value.total > rhs.value.total }
                return lhs.key < rhs.key
            }
        guard let best = ranked.first,
              let spell = all.first(where: { $0.id == best.key }) else {
            return CurseDossier.Finding(
                id: "counter-spells", label: "Counter-spells", value: "\(held) of \(tried.count) held",
                line: "That's every knock I've sent right into its hour. Each spell needs two tries before I'll say which works.",
                symbol: "wand.and.stars"
            )
        }
        var line = "\u{201C}\(spell.title)\u{201D} held \(best.value.held) of \(best.value.total) at its hour."
        if let worst = ranked.last, worst.key != best.key,
           let weak = all.first(where: { $0.id == worst.key }) {
            line += " \u{201C}\(weak.title)\u{201D} held \(worst.value.held) of \(worst.value.total)."
        }
        line += " Overall, \(held) of \(tried.count) counter-knocks found you here."
        return CurseDossier.Finding(
            id: "counter-spells", label: "What works against it", value: spell.title,
            line: line, symbol: "wand.and.stars"
        )
    }
}

/// What the reader's camera has been catching, as Curse evidence. Every kept
/// photo carries what the vision pass saw (`attentionLabels`). A fortnight of
/// photographs that keep showing the same things is sameness the Book can
/// see; things the camera has never shown it before are the reader winning.
enum PhotoSameness {
    struct Photo: Equatable {
        var at: Date
        var labels: Set<String>
    }

    static let windowDays = 14
    static let minimumPerWindow = 4

    static func photos(in pages: [BookPage]) -> [Photo] {
        pages.flatMap { page in
            page.mediaAssets.compactMap { asset -> Photo? in
                guard asset.kind != .audioFile,
                      let raw = asset.metadata["attentionLabels"]?.nonEmpty else { return nil }
                let labels = Set(raw.split(separator: ",").compactMap {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nonEmpty
                })
                return labels.isEmpty ? nil : Photo(at: page.createdAt, labels: labels)
            }
        }
        .sorted { $0.at < $1.at }
    }

    /// The share of photos in a window that look like one taken earlier in
    /// the same window: half their labels or more in common.
    static func repeatShare(_ photos: [Photo]) -> (repeats: Int, total: Int) {
        var repeats = 0
        for (index, photo) in photos.enumerated() where index > 0 {
            let alike = photos[..<index].contains { earlier in
                let union = photo.labels.union(earlier.labels).count
                return union > 0 && Double(photo.labels.intersection(earlier.labels).count) / Double(union) >= 0.5
            }
            if alike { repeats += 1 }
        }
        return (repeats, photos.count)
    }

    static func finding(pages: [BookPage], now: Date) -> CurseDossier.Finding? {
        let window = TimeInterval(windowDays) * 86_400
        let all = photos(in: pages).filter { $0.at <= now }
        let recent = all.filter { now.timeIntervalSince($0.at) < window }
        let prior = all.filter { now.timeIntervalSince($0.at) >= window && now.timeIntervalSince($0.at) < 2 * window }
        guard recent.count >= minimumPerWindow, prior.count >= minimumPerWindow else { return nil }
        let latest = repeatShare(recent)
        let before = repeatShare(prior)
        let latestShare = Double(latest.repeats) / Double(latest.total)
        let beforeShare = Double(before.repeats) / Double(before.total)

        if latestShare >= 0.4, latestShare >= beforeShare + 0.2 {
            var counts: [String: Int] = [:]
            for photo in recent { for label in photo.labels { counts[label, default: 0] += 1 } }
            let usual = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .prefix(3).map { $0.key }
            return CurseDossier.Finding(
                id: "photos", label: "Your camera", value: "Seeing the same things",
                line: "\(latest.repeats) of your last \(latest.total) photos look like one you'd already taken this fortnight, mostly \(CurseEvidence.joined(usual)). The fortnight before, it was \(before.repeats) of \(before.total).",
                symbol: "camera"
            )
        }
        let seenBefore = all.filter { now.timeIntervalSince($0.at) >= window }
            .reduce(into: Set<String>()) { $0.formUnion($1.labels) }
        let fresh = recent.reduce(into: Set<String>()) { $0.formUnion($1.labels) }.subtracting(seenBefore)
        if fresh.count >= 5 || (beforeShare - latestShare >= 0.2) {
            return CurseDossier.Finding(
                id: "photos", label: "Your camera", value: "Finding new things",
                line: fresh.isEmpty
                    ? "Your photos look less alike than they did a fortnight ago."
                    : "It's caught things it never showed me before: \(CurseEvidence.joined(Array(fresh.sorted().prefix(4))))).",
                symbol: "camera"
            )
        }
        return nil
    }
}

struct AttentionProbeScheduleSlot: Equatable {
    var id: String
    var dayID: String
    var fireAt: Date
    var cycle: Int
}

/// The Where-Were-You Knocks (docs/the-knock-plan.md). Two a day, one in each
/// half of the waking day, so a round of thirty to fifty answers covers every
/// hour within a couple of weeks and the Book can find the Curse's hours. One
/// Knock a day sat at a random hour between nine and seven, so mornings and
/// evenings were almost never seen.
///
/// The Knocks have their own lane in `BookInterruptionBudget`: they never take
/// the morning or evening seat from the Book's other Knocks, so the day holds
/// at most four interruptions. A reader who has gone quiet gets one a day
/// until they answer again; silence is never scored, but it isn't pestered.
///
/// iOS holds 64 pending notifications. Twenty days of two leaves room for the
/// Book's ordinary three-day horizon. Opening the app refreshes the runway;
/// completing a round cancels its unused Knocks for the rest.
enum AttentionProbeSchedule {
    static let horizonDays = 20
    /// Where in the day each Knock may land, as [first hour, last hour]. The
    /// gap between them keeps two Knocks at least two hours apart.
    static let windows: [ClosedRange<Int>] = [8...12, 15...20]
    /// No answer for this long means the reader has gone quiet.
    static let quietAfter: TimeInterval = 36 * 3600

    static func slots(
        ledger: AttentionProbeLedger,
        startingAt start: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [AttentionProbeScheduleSlot] {
        let attention = ledger.reconciled(now: now)
        guard attention.shouldSchedule(now: now) else { return [] }
        let quiet = attention.receipts.map(\.answeredAt).max()
            .map { now.timeIntervalSince($0) > quietAfter } ?? false
        let windows = quiet ? Array(windows.suffix(1)) : windows
        // The counter-knock (docs/the-knock-plan.md §3): once the Curse's
        // favourite hour is known, every other day the Knock in that half of
        // the day lands right in it.
        let watched = CurseFight.strongestHour(attention, calendar: calendar)
            .flatMap { $0.share >= 0.5 ? $0.hour : nil }

        return (0..<horizonDays).flatMap { offset -> [AttentionProbeScheduleSlot] in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return []
            }
            let dayID = BookDay.id(for: date, calendar: calendar)
            return windows.enumerated().compactMap { index, window in
                // FNV-1a, finished with a multiply-shift: day ids differ only in
                // their last characters, and a plain running hash left whole
                // hours of the day unknocked for weeks.
                var seed: UInt64 = 14_695_981_039_346_656_037
                for byte in "\(attention.currentCycle)|\(dayID)|\(index)".utf8 {
                    seed = (seed ^ UInt64(byte)) &* 1_099_511_628_211
                }
                seed ^= seed >> 29
                seed = seed &* 0xbf58_476d_1ce4_e5b9
                seed ^= seed >> 32
                var sample = calendar.dateComponents([.year, .month, .day], from: date)
                let eraDay = calendar.ordinality(of: .day, in: .era, for: date) ?? offset
                let watching = watched.map { window.contains($0) && eraDay % 2 == 0 } ?? false
                let turned = attention.hush?.isTurning(at: date) ?? false
                sample.hour = watching ? watched! : window.lowerBound + Int(seed % UInt64(window.count))
                sample.minute = Int((seed >> 20) % 60)
                guard let fireAt = calendar.date(from: sample), fireAt > now else { return nil }
                return AttentionProbeScheduleSlot(
                    id: "attention-\(attention.currentCycle)-\(dayID)-\(window.lowerBound)" + (watching ? "-watch" : turned ? "-turn" : ""),
                    dayID: dayID,
                    fireAt: fireAt,
                    cycle: attention.currentCycle
                )
            }
        }
    }
}

/// The eucatastrophe (docs/the-knock-plan.md §6). When the Knocks go rote,
/// the Book stops knocking. No warning and no guilt: it goes quiet and says so
/// when it's opened. The Reader reaching in unasked, a Page written with no
/// prompt, is the reverse knock that wakes it. If nobody knocks, it comes
/// back on its own after a few days, with nothing held against anyone.
struct KnockHush: Codable, Equatable {
    enum Waker: String, Codable, Equatable {
        case reader
        case time
    }

    var startedAt: Date
    var announcedAt: Date? = nil
    var wokenAt: Date? = nil
    var wokenBy: Waker? = nil
    var turnAnnouncedAt: Date? = nil

    /// The longest the Book stays quiet without being knocked.
    static let longest: TimeInterval = 6 * 86_400
    /// How long the Knocks speak in their new voices after the turn.
    static let turnLasts: TimeInterval = 7 * 86_400
    /// The rest before the Book may go quiet again.
    static let rest: TimeInterval = 60 * 86_400

    func isQuiet(now: Date) -> Bool {
        wokenAt == nil && now.timeIntervalSince(startedAt) < Self.longest
    }

    func isTurning(at date: Date) -> Bool {
        guard let wokenAt, wokenBy == .reader else { return false }
        return date >= wokenAt && date.timeIntervalSince(wokenAt) < Self.turnLasts
    }
}

enum KnockHushEngine {
    enum Event: Equatable {
        /// The Book stopped knocking.
        case wentQuiet
        /// The Reader knocked back.
        case wokenByReader
        /// Nobody knocked; it came back anyway.
        case cameBack
    }

    /// A reverse knock is the Reader writing to the Book while it's quiet:
    /// nothing pinged them, so anything they write came unasked.
    static func reverseKnocks(in pages: [BookPage], since: Date, now: Date) -> [BookPage] {
        pages.filter {
            $0.origin == .userAuthored && $0.createdAt > since && $0.createdAt <= now
                && !$0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// One step of the hush, run with the rut assessment. Hard days never
    /// start one.
    static func tend(
        _ ledger: inout AttentionProbeLedger,
        rote: Bool,
        distressActive: Bool,
        pages: [BookPage],
        now: Date
    ) -> Event? {
        if var hush = ledger.hush, hush.wokenAt == nil {
            if !reverseKnocks(in: pages, since: hush.startedAt, now: now).isEmpty {
                hush.wokenAt = now
                hush.wokenBy = .reader
                ledger.hush = hush
                return .wokenByReader
            }
            if !hush.isQuiet(now: now) {
                hush.wokenAt = now
                hush.wokenBy = .time
                ledger.hush = hush
                return .cameBack
            }
            return nil
        }
        guard rote, !distressActive else { return nil }
        if let last = ledger.hush, now.timeIntervalSince(last.startedAt) < KnockHush.rest { return nil }
        ledger.hush = KnockHush(startedAt: now)
        return .wentQuiet
    }

    /// What the Book says when it's opened, once per beat.
    static func line(for hush: KnockHush, now: Date) -> String? {
        if hush.isQuiet(now: now) {
            return hush.announcedAt == nil ? "I stopped knocking. I wanted to see if you'd notice." : nil
        }
        guard hush.turnAnnouncedAt == nil, let wokenBy = hush.wokenBy else { return nil }
        switch wokenBy {
        case .reader:
            return "You knocked on me. Nobody's ever done that. The Curse had got into my knocking, and you knocked it right out."
        case .time:
            return "I came back on my own. I'll knock differently now."
        }
    }
}

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
    /// The Book's accumulated private correspondences: the reader's own laws,
    /// with their evidence, their promises, and everything the Book has already
    /// had to cross out. Optional so every older vault opens with an empty
    /// grimoire rather than a migration fiction.
    var grimoire: GrimoireLedger?
    /// Repeating, in-the-moment samples of whether attention was with the life
    /// in front of the reader. Optional so older vaults begin at cycle zero.
    var attentionProbes: AttentionProbeLedger?
    /// Baselines, deltas and trends posted from the Daybook. Cached here because
    /// curation gates read it on every desk build and rebuilding it means
    /// walking ninety days of rows. Internal only: nothing in it is ever
    /// rendered. Optional so older vaults open with an unwritten Ledger.
    var standingLedger: StandingLedger?
    /// The behavioural lane: what the reader's own writing says about
    /// flattening or quickening. Cached beside the Ledger and computed in the
    /// same detached tick. Internal only, and capped at a single step of lean.
    var inferredSignals: InferredReaderSignals?
    /// Beliefs the Book holds about when this reader is most alive, and what
    /// happened when it arranged for them. Runs only under the workings
    /// authority; absent for every reader who has not opened that door.
    var twinExperiments: TwinExperimentLedger?
    /// Optional for clean decoding of Books saved before asides acquired a
    /// memory of their own.
    var bookAsideReceipts: [BookAsideReceipt]?
    /// Bounded local press memory. It does not Keep editions or count them as
    /// reader contributions. Reader words are not duplicated into this ledger.
    var bleedPrintHistory: [BleedPrintRecord]?
    /// Every front page the paper ran, a line each, for the monthly's "The Month's Front
    /// Pages". Press memory forgets after a month; this keeps a year of headlines.
    var bleedFrontPages: [BleedFrontPageRecord]?
    /// The last week of papers exactly as printed, kept or not.
    var bleedPrintedPapers: [BleedPrintedPaper]?
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
    /// The Cast's own business. Advances on the world clock and owes the reader
    /// nothing.
    var castUndertakings: [CastUndertaking]?
    /// Which of the Academy's threads the reader has been following, and how
    /// far. Written only when a beat actually reached them.
    var undertakingSerial: UndertakingSerial?
    /// Emergent state transitions leaving marks across existing surfaces.
    var worldPressures: [WorldPressure]?
    /// What the Academy's rooms remember, keyed by location entity ID.
    var placeStates: [String: PlaceState]?
    /// Disputed events several characters read differently, and about which the
    /// Book itself may turn out to be wrong.
    var contestedQuestions: [ContestedQuestion]?
    /// Remarks the Academy has already made, so it never repeats one.
    var academyDispatchSaidIDs: [String]?
    var academyDispatchLastSpokeAt: Date?
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
    var storyConsequenceLedger: StoryConsequenceLedger?
    var bookNoticeEvidence: Int?
    var magicMoment: MagicMomentState?
    var bookObservations: [BookObservationRecord]?
    var bookReadingBoundaries: [BookReadingBoundary]?
    /// The marks the reader's own wandering has left on the Book: folds they
    /// cut open, gatherings they keep going back to, rooms that have gone
    /// quiet. Optional so every older vault opens with clean paper rather than
    /// a migration fiction, and the only ledger in here that cannot be rebuilt
    /// from the archive if it is lost.
    var readerWear: ReaderWearLedger?
    var overnightConnectionDrafts: [OvernightConnectionDraft]?
    /// "I want to write, please?": wants and the held drawer. Optional so an
    /// older vault opens with an empty desk.
    var writingDesk: WritingDesk? = nil
    /// Adventures already offered, including runs never kept. No expiry: a
    /// familiar place may host a new experience, but old activities stay retired.
    var compassAdventures: [CompassAdventureRecord]? = nil
    var nothingGreyOffset: Int?
    /// A Page can leave the living Book while remaining intact in raw archives,
    /// Stacks, and export.
    var greyPageThreats: GreyPageThreatLedger?
    var openWorldEventArchive: OpenWorldEventArchive? = nil
    /// Once-only issue delivery, boundary, and outcome receipts. Optional so a
    /// Book saved before monthly issues existed opens with a blank ledger.
    var worldEventLifecycle: WorldEventLifecycleLedger? = nil
    /// Durable cross-media delivery facts used by authored dependencies and
    /// occurrence rules. Optional for Books saved before this ledger existed.
    var authoredContentReceipts: AuthoredContentReceiptLedger? = nil
    /// What the Cast remember from the monthly stories, frozen as it's earned
    /// so it outlives the month's pack. See `CastStoryMemory`.
    var castStoryMemories: CastStoryMemoryLedger? = nil
    /// Stable publishing boundaries. Seeded once from the first real kept page
    /// and carried in sealed copies so imports cannot renumber old issues.
    var publicationEpoch: BookPublicationEpoch? = nil
    var chosenQuill: ChosenQuill?
    var people: PeopleLedger?
    /// Gemma-authored taste notes earned when the reader marks a braid "missed
    /// me." Each is one short second-person nudge folded into future braid
    /// prompts as reader-taught guidance. Capped to the most recent few.
    var learnedBraidNotes: [String]?
    /// The braid's serial memory: threads it opened and has not closed, and the
    /// names the reader gave their own stretches of weather. Nil on every save
    /// written before the braid could remember anything across nights.
    var readerStory: ReaderStory?
    /// Durable first-run progress. The Welcome requires an open or dismissal;
    /// extended introductions retire after being shown once. Stable keys also
    /// survive variety-history expiry and travel in sealed copies.
    /// Nil means the older engagement ledger has never been seeded.
    var firstRunEngaged: [String]?
    /// The Book's irreducible interior life: promises it chose to make,
    /// favorites it chose, favors it asked, running business, and self-secrets.
    /// Reader facts and inferred patterns remain in their existing evidence
    /// stores rather than being duplicated here.
    var bookInterior: BookInteriorState?
    /// The ribbon from before it had three strands. Read once into
    /// `pageRibbons`, then cleared; see `ribbons`.
    var savedPageRibbon: SavedPageRibbon?
    /// The ribbon's three strands, each keeping an exact local Page snapshot so
    /// a rotating desk can still riffle back to the marked words tomorrow.
    var pageRibbons: [SavedPageRibbon]?
    /// Every Inkbones throw, the reader's and the Curse's, newest last.
    var inkbonesLog: [InkbonesThrowRecord]?
    /// The Book's bounded standing authority, current autonomous Working, and
    /// attributable receipts. Optional so older Books open with the door shut.
    var bookWorkings: BookWorkingLedger?
    /// Feast days the reader has asked the Book to stop marking. This exists
    /// for the family holidays, which the Book marks for everyone precisely
    /// because it cannot know who anybody has, and which therefore need a
    /// door out that the reader controls, permanently, in one tap.
    var restedCelebrationIDs: [String]?
    /// Spells the reader has put down for good. Same door the feast days have:
    /// one tap, honoured forever, no argument.
    var restedSpellIDs: [String]?
    /// When each spell was last worked, so the Book does not offer the same one
    /// back the next morning. Optional so older vaults open with none cast.
    var spellCastLog: [String: Date]?
    /// The reader's own birthday, as month and day only. No year: the Book has
    /// no business knowing anybody's age.
    var readerBirthday: ReaderBirthday?
    /// The fairy tale the reader is currently inside, if the Book has worked
    /// out that they are. Only ever one.
    var livingTale: LivingTale?
    /// Tales that finished. The Book keeps these whole rather than summarised:
    /// a bound tale is the thing, not a record of the thing.
    var boundTales: [LivingTale]?
    /// When the Book last asked the reader whether a shape it thought it saw
    /// keeps happening. Asking is the only route by which a recognised tale
    /// reaches the reader in words, and it is rationed: see `BraidTaleAsk`.
    var lastTaleAskAt: Date?
    /// Tales already put to the reader as a question. One ask per tale, ever -
    /// being asked twice about the same thing would say the Book was not
    /// listening to the answer.
    var askedTaleIDs: [String]?
    /// Shapes the reader has denied, by `TaleShape` raw value. Permanent, and
    /// deliberately stored by shape rather than by tale: closing the one tale
    /// would let the same receipts recognise the same shape again under a new
    /// id, and the Book would lean on something it had been told was wrong.
    var refusedTaleShapes: [String]?
    /// Volumes the reader has sent away to be printed. Kept so the Book can
    /// press a Page for each one and remember, later, that it let something go.
    var pressedVolumes: [PressedVolumeKeepsake]?
    /// Each volume the reader sent to the press, by the id its folios print, so
    /// a photograph of a handled page can be traced back to its book.
    var volumeRegistries: [BoundVolumeRegistry]?
    /// The Bound Year, if they hold one. Sold on the web, so this is a mirror
    /// of what the Worker knows rather than the record itself.
    var boundYear: BoundYearMembership?
    /// Stripe's subscription id. Kept beside the membership rather than inside
    /// it, so the archive-facing model stays free of vendor identifiers.
    var boundYearMembershipID: String?
    /// Seasons standing at the door. One per season, ever.
    var seasonalDispatches: [SeasonalDispatch]?
    /// Earned seasons that closed without enough kept material to make a book.
    /// They ship nothing, but remain resolved so a later paid season cannot be
    /// trapped behind the same empty window forever.
    var resolvedEmptyBoundYearSeasonKeys: [String]?
    /// The member's first full week, bound and posted free. One per membership;
    /// the Worker keeps the claim, this keeps the Book's place.
    var boundYearWelcomeWeekly: BoundYearWelcomeWeekly?
    /// When the last tale closed, so the reader gets to be out of a story.
    var lastTaleClosedAt: Date?
    /// The laws finished tales left behind. These do not reset.
    var taleScars: [TaleScar]?
    /// Second halves of the reader's role, earned by tales that cost something.
    var roleTransformations: [RoleTransformation]?
    /// What the cast has done to each other. The shared, objective record:
    /// each character's own asymmetric memory of the same act lives in their
    /// entity memories, and the weighted edge lives in the relationship field.
    var castActs: CastActLedger?
    /// Every name the Book has given this reader, in order, with when it was
    /// given and when it was superseded. `outgrownRole` needs the naming date
    /// to measure against, and the lineage is what lets a past role be spoken
    /// of afterwards: "you were a Nightlight through the winter."
    var roleTenures: [RoleTenure]?
}

/// Opens the vault file without ever mistaking "couldn't read it" for "there
/// isn't one".
///
/// The vault used to be decoded with `try?`, and any failure started a blank
/// Book that was written straight over the real one. Two ordinary things fail
/// that read: a launch in the background while the phone is locked (the file
/// is `completeUnlessOpen`, so it can't be read but a fresh one can still be
/// written), and a build that can't decode something a newer build wrote. Both
/// wiped the reader's Anchors along with everything else in the vault.
enum PlayerVaultDisk {
    enum Opening {
        /// No file at all: a new Book, or one that predates the vault.
        case absent
        case opened(PlayerVaultData)
        /// Most of it decoded. The named top-level fields were damaged and are
        /// back at their defaults, or keep only the entries that decoded.
        case salvaged(PlayerVaultData, damaged: [String])
        /// Readable, but not a vault this build can make anything of.
        case undecodable
        /// The file is there and can't be read yet. Nothing may be written.
        case unreadable
    }

    static func open(_ url: URL, fileManager: FileManager = .default) -> Opening {
        guard fileManager.fileExists(atPath: url.path) else { return .absent }
        guard let bytes = try? Data(contentsOf: url) else { return .unreadable }
        if let data = try? JSONDecoder().decode(PlayerVaultData.self, from: bytes) {
            return .opened(data)
        }
        guard let (data, damaged) = salvage(bytes) else { return .undecodable }
        return .salvaged(data, damaged: damaged)
    }

    /// Keeps every top-level field that decodes on its own, laid over a blank
    /// vault so the required keys are always present. A list that fails as a
    /// whole keeps the entries that decode, so one strange Anchor can't take
    /// the rest with it.
    static func salvage(_ bytes: Data) -> (PlayerVaultData, damaged: [String])? {
        guard let stored = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let blank = try? JSONEncoder().encode(PlayerVaultData()),
              var kept = try? JSONSerialization.jsonObject(with: blank) as? [String: Any] else { return nil }

        func decoded(_ object: [String: Any]) -> PlayerVaultData? {
            guard let bytes = try? JSONSerialization.data(withJSONObject: object) else { return nil }
            return try? JSONDecoder().decode(PlayerVaultData.self, from: bytes)
        }
        func fits(_ key: String, _ value: Any) -> Bool {
            var trial = kept
            trial[key] = value
            return decoded(trial) != nil
        }

        var damaged: [String] = []
        for key in stored.keys.sorted() {
            guard let value = stored[key] else { continue }
            if fits(key, value) {
                kept[key] = value
                continue
            }
            damaged.append(key)
            if let items = value as? [Any] {
                let survivors = items.filter { fits(key, [$0]) }
                if !survivors.isEmpty, fits(key, survivors) {
                    kept[key] = survivors
                }
            }
        }
        return decoded(kept).map { ($0, damaged) }
    }

    /// Puts a copy of a vault this build couldn't fully read beside it, so the
    /// original survives whatever gets written next. Moves the file instead
    /// when it can't even be copied.
    @discardableResult
    static func setAside(_ url: URL, now: Date = Date(), fileManager: FileManager = .default) -> URL? {
        let name = url.deletingPathExtension().lastPathComponent
        let target = url.deletingLastPathComponent()
            .appendingPathComponent("\(name).set-aside-\(Int(now.timeIntervalSince1970)).\(url.pathExtension)")
        if (try? fileManager.copyItem(at: url, to: target)) != nil { return target }
        if (try? fileManager.moveItem(at: url, to: target)) != nil { return target }
        return nil
    }
}

/// A month and a day. Deliberately not a `Date` and deliberately yearless: a
/// birthday the Book marks, not an age it tracks.
struct ReaderBirthday: Codable, Equatable {
    var month: Int
    var day: Int

    var isValid: Bool {
        (1...12).contains(month) && (1...31).contains(day)
    }

    func falls(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isValid else { return false }
        let parts = calendar.dateComponents([.month, .day], from: date)
        return parts.month == month && parts.day == day
    }

    /// Reads a birthday out of whatever the reader typed. The Book asks for a
    /// month and a day in its own words, so this has to cope with "March 3rd",
    /// "3 March", "3/3", "the third of March" and a fair amount of shrugging.
    /// Any year present is deliberately discarded rather than stored.
    static func parse(_ text: String, calendar: Calendar = .current) -> ReaderBirthday? {
        let lowered = text.lowercased()
        let months = [
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
            "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7,
            "aug": 8, "sept": 9, "sep": 9, "oct": 10, "nov": 11, "dec": 12
        ]

        // Longest name first, so "sept" is not eaten by "sep".
        let namedMonth = months
            .sorted { $0.key.count > $1.key.count }
            .first { lowered.contains($0.key) }?.value

        // Days spelled out in words, since the Book asked in words and a fair
        // number of people answer "the eleventh of November".
        let ordinals: [String: Int] = [
            "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
            "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
            "eleventh": 11, "twelfth": 12, "thirteenth": 13, "fourteenth": 14,
            "fifteenth": 15, "sixteenth": 16, "seventeenth": 17, "eighteenth": 18,
            "nineteenth": 19, "twentieth": 20, "twenty-first": 21, "twenty first": 21,
            "twenty-second": 22, "twenty second": 22, "twenty-third": 23, "twenty third": 23,
            "twenty-fourth": 24, "twenty fourth": 24, "twenty-fifth": 25, "twenty fifth": 25,
            "twenty-sixth": 26, "twenty sixth": 26, "twenty-seventh": 27, "twenty seventh": 27,
            "twenty-eighth": 28, "twenty eighth": 28, "twenty-ninth": 29, "twenty ninth": 29,
            "thirtieth": 30, "thirty-first": 31, "thirty first": 31
        ]
        // Longest first, so "twenty-first" is not read as "first".
        let spelledDay = ordinals
            .sorted { $0.key.count > $1.key.count }
            .first { lowered.contains($0.key) }?.value

        // Every run of digits, in order. A four-digit run is a year and is
        // dropped on the floor.
        var numbers: [Int] = []
        var current = ""
        for character in lowered {
            if character.isNumber {
                current.append(character)
            } else {
                if let value = Int(current), current.count <= 2 { numbers.append(value) }
                current = ""
            }
        }
        if let value = Int(current), current.count <= 2 { numbers.append(value) }

        if let month = namedMonth {
            guard let day = spelledDay ?? numbers.first(where: { (1...31).contains($0) }) else { return nil }
            let birthday = ReaderBirthday(month: month, day: day)
            return birthday.isRealDate(calendar: calendar) ? birthday : nil
        }

        // No month name, so fall back to two numbers. Ambiguous pairs such as
        // 3/4 are read the way the reader's own locale writes dates.
        guard numbers.count >= 2 else { return nil }
        let first = numbers[0]
        let second = numbers[1]

        let dayFirst = Locale.current.region?.identifier != "US"
        var candidates: [ReaderBirthday] = dayFirst
            ? [ReaderBirthday(month: second, day: first), ReaderBirthday(month: first, day: second)]
            : [ReaderBirthday(month: first, day: second), ReaderBirthday(month: second, day: first)]
        candidates = candidates.filter { $0.isRealDate(calendar: calendar) }
        return candidates.first
    }

    /// Whether this month/day pair is a date that actually exists: 31 February
    /// is a typo, not a birthday. 29 February is allowed; it is somebody's.
    func isRealDate(calendar: Calendar = .current) -> Bool {
        guard isValid else { return false }
        var components = DateComponents()
        components.year = 2024  // A leap year, so 29 February survives.
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return false }
        let parts = calendar.dateComponents([.month, .day], from: date)
        return parts.month == month && parts.day == day
    }

    /// How the Book writes the date back to the reader.
    func spelled(calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.year = 2024
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
    }
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
    /// The month this arrived as the Standing Order's authored pack. Kept for
    /// chronology and old receipts; Monthly Content Packs are no longer sold
    /// separately.
    var subscriptionReleasedAt: Date? = nil

    var resolvedSaleState: SaleState {
        if comingSoon { return .comingSoon }
        return saleState ?? .standard
    }

    /// Monthly Content Packs belong to the Digital Standing Order. The old
    /// product identifiers remain in the catalogue only so prior purchases can
    /// still restore; the app never offers a new à-la-carte pack purchase.
    /// While the Standing Order is retired, nothing here is for sale at all.
    func isPurchasableAlone(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        family == .standingOrder && DigitalStandingOrder.isOffered
    }

    /// Retained for source compatibility with old shelf rendering. Packs no
    /// longer leave the subscription shelf.
    func archiveOpensAt(calendar: Calendar = .current) -> Date? {
        nil
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
    /// A plain-language value note, e.g. "Best value: 2 months free".
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
            body: "If it's still set to renew, Apple charges \(price)/\(periodUnit) tomorrow. Keep it or cancel in Settings: either way, every page you made stays yours."
        )
    }
}

enum BookShopCatalog {

    /// The month a monthly pack was the Standing Order's drop.
    static func releaseMonth(_ year: Int, _ month: Int) -> Date {
        Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: year, month: month, day: 1))
            ?? .distantPast
    }

    /// Everything the Goblins are willing to sell, ever listed here.
    /// Product IDs follow app.reenchanted.book.pack.<packID>;
    /// the Standing Order (an auto-renewable subscription) uses .pass. instead.
    static let listings: [BookShopListing] = [
        BookShopListing(
            id: "listing-standing-order-annual",
            packID: PackEntitlements.standingOrderPackID,
            family: .standingOrder,
            title: "The Standing Order · Annual",
            goblinPitch: "One line in the ledger, renewed yearly, and every folio the Empire prints walks itself to your shelf. The clerk calls it the only honest bargain in the building.",
            contents: "The current Monthly Content Pack while its calendar window is alive: new Pages, quests, rituals, events, sounds, places, characters, and other living additions. Pages you keep and lasting things you earn stay in your Book after the temporary story closes.",
            productID: "app.reenchanted.book.pass.standing-order.annual",
            fallbackDisplayPrice: "$79.99"
        ),
        BookShopListing(
            id: "listing-standing-order-monthly",
            packID: PackEntitlements.standingOrderPackID,
            family: .standingOrder,
            title: "The Standing Order · Monthly",
            goblinPitch: "One line in the ledger, renewed each month, and every folio the Empire prints walks itself to your shelf. The clerk keeps the ink wet in case you change your mind.",
            contents: "The current Monthly Content Pack while its calendar window is alive: new Pages, quests, rituals, events, sounds, places, characters, and other living additions. Pages you keep and lasting things you earn stay in your Book after the temporary story closes.",
            productID: "app.reenchanted.book.pass.standing-order.monthly",
            fallbackDisplayPrice: "$9.99"
        ),
        BookShopListing(
            id: "listing-dictionary-rebellion",
            packID: "dictionary-rebellion",
            family: .eventPack,
            title: "The Dictionary Rebellion",
            goblinPitch: "A small riot in the margins: twenty-odd words with picket signs, a professor with a rubber stamp, and a punctuation pixie who keeps stealing the full stops.",
            contents: "The September 2027 world event: living words to negotiate, Mook and Pippa in the Cast, fieldwork prompts, event pages, treaty aftermaths, and lexicon choices that can bend my later prose.",
            productID: "app.reenchanted.book.pack.dictionary-rebellion",
            saleState: .liveEvent,
            subscriptionReleasedAt: releaseMonth(2027, 9)
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
            productID: "app.reenchanted.book.pass.standing-order.monthly",
            title: "Monthly",
            fallbackDisplayPrice: "$9.99",
            periodUnit: "month",
            valueNote: nil
        ),
        StandingOrderTier(
            id: "standing-order-annual",
            cadence: .annual,
            productID: "app.reenchanted.book.pass.standing-order.annual",
            title: "Annual",
            fallbackDisplayPrice: "$79.99",
            periodUnit: "year",
            valueNote: "Save 33%"
        )
    ]

    /// Retired products remain recognizable so an older receipt can still
    /// restore the Standing Order even though the plan is no longer offered.
    private static let retiredStandingOrderProductIDs: Set<String> = [
        "app.reenchanted.book.pass.standing-order.weekly"
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

/// The Digital Standing Order is retired for now: every month's content is free
/// for every reader, and nothing offers the subscription for sale. The StoreKit
/// plumbing, product IDs, restore, and cancellation stay in place, so a reader
/// who already holds one can still manage it, and so it can come back by
/// flipping this one switch.
enum DigitalStandingOrder {
    /// `true` sells the subscription again and restores the monthly gate.
    /// Tests that exercise the gate turn it on for their own duration.
    nonisolated(unsafe) static var isOffered = false
}

/// Which locked packs this save owns. Checked by every content registry;
/// written by a verified commerce ledger (or the dev counter internally).
/// While the Digital Standing Order is retired, every reader holds what it
/// used to open; the receipts below still decide who is actually subscribed.
enum PackEntitlements {
    /// The Standing Order: the annual everything-pass. While it is bound to
    /// the save, every locked pack counts as owned. It is the one entitlement
    /// that can lapse (auto-renewable subscription), so only the merchant's
    /// live ledger may revoke it: outright purchases are permanent.
    static let standingOrderPackID = "standing-order"
    /// The same monthly digital packs, granted by an active Bound Year. This
    /// must stay separate from Apple's subscription id: the two ledgers renew
    /// and cancel independently even though they open the same pack shelf.
    static let boundYearDigitalPackID = "bound-year-digital"
    /// These were always free but deliberately claimed in the Bookshop. Free
    /// monthly stories must not silently make that reader choice for them.
    private static let readerClaimedGiftIDs = Set(BookShopCatalog.freeGifts.map(\.packID))
        .union(["nocturne-folio", "margins-and-mysteries"])

    nonisolated(unsafe) static var ownedPackIDs: Set<String> = []

    static var hasStandingOrder: Bool {
        ownedPackIDs.contains(standingOrderPackID)
    }

    static var hasBoundYearDigitalAccess: Bool {
        ownedPackIDs.contains(boundYearDigitalPackID)
    }

    static var hasMonthlyContentPackAccess: Bool {
        hasMonthlyContentPackAccess(in: ownedPackIDs)
    }

    static func hasMonthlyContentPackAccess(in ownedPackIDs: Set<String>) -> Bool {
        !DigitalStandingOrder.isOffered
            || ownedPackIDs.contains(standingOrderPackID)
            || ownedPackIDs.contains(boundYearDigitalPackID)
    }

    static func isUnlocked(_ packID: String) -> Bool {
        owns(packID, in: ownedPackIDs)
    }

    /// The same ownership rule for callers that carry their own snapshot of
    /// the owned set (curator inputs, stall builders, radio gates).
    static func owns(_ packID: String, in ownedPackIDs: Set<String>) -> Bool {
        let receipted = ownedPackIDs.contains(packID)
            || ownedPackIDs.contains(standingOrderPackID)
            || ownedPackIDs.contains(boundYearDigitalPackID)
        if readerClaimedGiftIDs.contains(packID) { return receipted }
        return !DigitalStandingOrder.isOffered || receipted
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
            return "Shhh. The Nocturne is in session. But yes: we're awake too."
        }
        if let chapter = ascendantChapterName, roll % 3 == 0 {
            return "The \(chapter) talisman says you knock like one of theirs."
        }
        let pool = [
            "Who taught you the knock?",
            "Password accepted. There was never a password.",
            "Three of us were asleep. The fourth says hello.",
            "The Margins are rearranging. Pardon our dust.",
            "We're between chapters in here. Come back at moonrise.",
            "The Goblins want to know if you're a customer or a draft.",
            "Penny says to tell you the filing is going well. Penny is lying.",
            "Knock twice more and we legally have to let the cat out.",
            "You found the door. Most readers only find the pages.",
            "It's warmer in here than it looks. Ink holds heat.",
            "The Dusk Thorn felt that. It pretended not to.",
            "Careful: the cover bruises like a pear."
        ]
        return pool[abs(roll) % pool.count]
    }
}

extension PlayerVaultData {
    /// The ribbon's strands, an older single ribbon included.
    var ribbons: [SavedPageRibbon] {
        get { BookRibbons.ordered(pageRibbons ?? savedPageRibbon.map { [$0] } ?? []) }
        set {
            pageRibbons = BookRibbons.ordered(newValue)
            savedPageRibbon = nil
        }
    }
}
