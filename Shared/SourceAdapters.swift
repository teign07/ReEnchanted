import Foundation


struct BookSourceInputs: Equatable {
    var days: [BookDay] = []
    var body: BodySourceSignal?
    var weather: WeatherSourceSignal?
    var enchantedWeather: EnchantedWeatherSignal?
    var anchors: [AnchorRecord] = AnchorRegistry.defaultAnchors
    var nearbyAnchor: AnchorProximity?
    var preparedAnchorSurface: SurfacePage?
    var narrative: NarrativeSourceSnapshot?
    var selfFacts: [SelfFact] = []
    var facultyEntries: [FacultyEntry] = []
    var customCastMembers: [CustomCastMember] = []
    var electives: [UnwrittenElective] = []
    var entityBeliefOffsets: [String: Int] = [:]
    var relationshipField: [String: RelationshipTie] = [:]
    var faeState: FaePlayerState = FaePlayerState()
    var pactWar: PactWarState = PactWarState()
    var hemisphere: Hemisphere = .northern
    var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
    var calendarEvents: [CalendarEventSignal] = []
    var nearbyPlaces: [LocalPlaceSignal] = []
    var resurfacingCandidates: [BookPage] = []
    var quietDays: Int = 0
    var currentArc: StoryArc?
    var recentNarrativeEvents: [NarrativeEvent] = []
    var continuity: LiteraryContinuityDigest = .empty
    var constellations: [Constellation] = []
    var wagers: [BookWager] = []
    var themes: [BookTheme] = []
    var clusters: [BookMotifCluster] = []
    var bleedIssueNumber: Int = 1
    var preparedBleedEditionSurface: SurfacePage?
    var bookJump: BookJumpState = BookJumpState()
    var radio: RadioPlaybackState = .off
    var activeWorldEvents: [ResolvedWorldEvent] = []
    var ownedPackIDs: Set<String> = []
    var localBrainIsReady = false
    var readerBeliefScore: Int = 30

    func recentVarietyKeys(within seconds: TimeInterval = 48 * 3600, now: Date = Date()) -> Set<String> {
        Set(surfaceHistory.filter { now.timeIntervalSince($0.value.lastShownAt) < seconds }.keys)
    }

    var keptPageCount: Int {
        days.reduce(0) { $0 + $1.pages.count }
    }
    var selectedWonderCompass: ReferenceSnippet?
    var selectedWonderCompassSelector: String?
    var preparedIlluminatedPhotoSurface: SurfacePage?
    var preparedStoryPageSurface: SurfacePage?
    var preparedGossipPageSurface: SurfacePage?
    var preparedFacultyResearchSurface: SurfacePage?
    var preparedLetterSurface: SurfacePage?
    var userPhotoIlluminationFallbackAllowed = false

    static let empty = BookSourceInputs()

    static func from(insideCover state: InsideCoverState) -> BookSourceInputs {
        BookSourceInputs(
            days: [],
            body: state.health.map {
                BodySourceSignal(
                    status: $0.status,
                    score: $0.score,
                    phrase: $0.phrase
                )
            },
            weather: extractWeather(from: state),
            enchantedWeather: nil,
            anchors: AnchorRegistry.defaultAnchors,
            nearbyAnchor: nil,
            preparedAnchorSurface: nil,
            narrative: nil,
            selfFacts: [],
            facultyEntries: [],
            customCastMembers: [],
            resurfacingCandidates: [],
            recentNarrativeEvents: [],
            continuity: .empty,
            selectedWonderCompass: nil,
            selectedWonderCompassSelector: nil,
            preparedIlluminatedPhotoSurface: nil,
            preparedStoryPageSurface: nil,
            preparedGossipPageSurface: nil,
            preparedFacultyResearchSurface: nil,
            preparedLetterSurface: nil,
            userPhotoIlluminationFallbackAllowed: false
        )
    }

    func resolvingWorldEvents(for day: BookDay? = nil, now: Date = Date()) -> BookSourceInputs {
        var copy = self
        copy.activeWorldEvents = WorldEventResolver.activeEvents(now: now, day: day, inputs: self)
        return copy
    }

    private static func extractWeather(from state: InsideCoverState) -> WeatherSourceSignal? {
        let fields = [state.now, state.next, state.note, state.practicePrompt]
        for field in fields {
            guard let range = field.range(of: "weather:", options: [.caseInsensitive]) else {
                continue
            }
            let tail = field[range.upperBound...]
            let phrase = tail
                .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == "·" })
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let phrase, !phrase.isEmpty {
                return WeatherSourceSignal(phrase: phrase, source: "inside-cover")
            }
        }
        return nil
    }
}

enum BookMemoryGate {
    static let requiredKeptPageCount = 50

    static let lockedTypes: Set<BookPageType> = [
        .bookRemembered,
        .bookConnections,
        .marginsAtlas
    ]

    static func locks(_ type: BookPageType, keptPageCount: Int) -> Bool {
        lockedTypes.contains(type) && keptPageCount < requiredKeptPageCount
    }

    static func remainingPages(for keptPageCount: Int) -> Int {
        max(0, requiredKeptPageCount - keptPageCount)
    }

    static func message(for type: BookPageType, keptPageCount: Int) -> String {
        let remaining = remainingPages(for: keptPageCount)
        let noun = remaining == 1 ? "page" : "pages"
        return "\(type.title) unlocks after \(requiredKeptPageCount) kept pages. Keep \(remaining) more \(noun)."
    }
}

enum StoryPageMechanicChoiceID: String, Codable, Equatable, CaseIterable {
    case sliceOfLife = "sliceoflife"
    case progressArc = "progressarc"
    case surprise

    init(role: StoryChoiceRole) {
        switch role {
        case .sliceOfLife:
            self = .sliceOfLife
        case .progressArc:
            self = .progressArc
        case .surprise:
            self = .surprise
        }
    }
}

enum StoryPageMechanicMandateKind: String, Codable, Equatable {
    case none
    case beliefDice = "belief-dice"
    case compassRun = "compass-run"
    case enchantment
}

struct StoryPageMechanicMandate: Codable, Equatable {
    var kind: StoryPageMechanicMandateKind
    var choiceID: StoryPageMechanicChoiceID?
    var enchantmentID: String?
    var reason: String

    static let none = StoryPageMechanicMandate(
        kind: .none,
        choiceID: nil,
        enchantmentID: nil,
        reason: "No mechanic this turn; let the Story Page move in prose."
    )

    var metadata: [String: String] {
        var values = [
            "storyMechanicMandateKind": kind.rawValue,
            "storyMechanicMandateReason": reason
        ]
        if let choiceID {
            values["storyMechanicMandateChoiceID"] = choiceID.rawValue
        }
        if let enchantmentID {
            values["storyMechanicMandateEnchantmentID"] = enchantmentID
        }
        return values
    }

    static func from(metadata: [String: String]) -> StoryPageMechanicMandate {
        let rawKind = metadata["storyMechanicMandateKind"] ?? StoryPageMechanicMandateKind.none.rawValue
        let kind = StoryPageMechanicMandateKind(rawValue: rawKind) ?? .none
        let choiceID = metadata["storyMechanicMandateChoiceID"].flatMap(StoryPageMechanicChoiceID.init(rawValue:))
        let enchantmentID = metadata["storyMechanicMandateEnchantmentID"]?.nonEmpty
        let reason = metadata["storyMechanicMandateReason"]?.nonEmpty ?? StoryPageMechanicMandate.none.reason
        if kind == .none {
            return .none
        }
        return StoryPageMechanicMandate(kind: kind, choiceID: choiceID, enchantmentID: enchantmentID, reason: reason)
    }
}

enum StoryPageMechanicPlanner {
    static func mandate(for day: BookDay, inputs: BookSourceInputs, packet: StoryScenePacket, now: Date) -> StoryPageMechanicMandate {
        guard shouldAllowMechanic(day: day, inputs: inputs, packet: packet, now: now) else {
            return .none
        }

        let seed = "\(day.id)|\(SurfaceCadence.slotID(for: now, hours: 4))|\(packet.id)|story-mechanic".stableHash
        let roll = abs(seed) % 100
        let eligibleKinds = eligibleKinds(for: packet, inputs: inputs)
        guard !eligibleKinds.isEmpty else { return .none }

        let desiredKind: StoryPageMechanicMandateKind
        switch roll {
        case 0..<76:
            return .none
        case 76..<86:
            desiredKind = .beliefDice
        case 86..<93:
            desiredKind = .compassRun
        default:
            desiredKind = .enchantment
        }

        let kind = eligibleKinds.contains(desiredKind) ? desiredKind : eligibleKinds[abs(seed / 100) % eligibleKinds.count]
        let choiceID = choiceID(for: kind, packet: packet, seed: seed)
        let enchantmentID = kind == .enchantment ? enchantmentID(for: packet, seed: seed) : nil
        return StoryPageMechanicMandate(
            kind: kind,
            choiceID: choiceID,
            enchantmentID: enchantmentID,
            reason: reason(for: kind, packet: packet)
        )
    }

    private static func shouldAllowMechanic(day: BookDay, inputs: BookSourceInputs, packet: StoryScenePacket, now: Date) -> Bool {
        guard packet.turn != nil else { return false }
        let recentPages = recentStoryPages(day: day, inputs: inputs, now: now, within: 5 * 86_400)
        if recentPages.first?.tags.contains(where: { $0.hasPrefix("story-mechanic") }) == true {
            return false
        }
        let externalCount = recentPages
            .prefix(5)
            .filter { page in
                page.tags.contains("story-mechanic:compass-run") ||
                page.tags.contains("story-mechanic:enchantment")
            }
            .count
        return externalCount == 0
    }

    private static func recentStoryPages(day: BookDay, inputs: BookSourceInputs, now: Date, within seconds: TimeInterval) -> [BookPage] {
        (inputs.days.flatMap(\.pages) + day.pages)
            .filter { $0.type == .narrativeOS && now.timeIntervalSince($0.createdAt) <= seconds }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func eligibleKinds(for packet: StoryScenePacket, inputs: BookSourceInputs) -> [StoryPageMechanicMandateKind] {
        var kinds: [StoryPageMechanicMandateKind] = [.beliefDice]
        let text = [
            packet.realSignals.joined(separator: " "),
            packet.relationshipPressures.joined(separator: " "),
            packet.selectedEntities.flatMap(\.tags).joined(separator: " "),
            packet.selectedThreads.flatMap(\.tags).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        if text.contains("compass") || text.contains("weather") || text.contains("body") ||
            text.contains("walk") || text.contains("place") || text.contains("anchor") ||
            !inputs.nearbyPlaces.isEmpty || inputs.nearbyAnchor != nil {
            kinds.append(.compassRun)
        }
        if text.contains("object") || text.contains("photo") || text.contains("room") ||
            text.contains("home") || text.contains("meal") || text.contains("tea") ||
            text.contains("ordinary") || text.contains("enchantment") {
            kinds.append(.enchantment)
        }
        return kinds
    }

    private static func choiceID(for kind: StoryPageMechanicMandateKind, packet: StoryScenePacket, seed: Int) -> StoryPageMechanicChoiceID {
        let preferredRole: StoryChoiceRole
        switch kind {
        case .none:
            preferredRole = .sliceOfLife
        case .beliefDice:
            preferredRole = packet.turn?.register == .active ? .progressArc : .surprise
        case .compassRun:
            preferredRole = .progressArc
        case .enchantment:
            preferredRole = .sliceOfLife
        }
        if packet.choices.contains(where: { $0.role == preferredRole }) {
            return StoryPageMechanicChoiceID(role: preferredRole)
        }
        let choices = packet.choices.map { StoryPageMechanicChoiceID(role: $0.role) }
        return choices.isEmpty ? .progressArc : choices[abs(seed / 1_000) % choices.count]
    }

    private static func enchantmentID(for packet: StoryScenePacket, seed: Int) -> String {
        let text = packet.realSignals.joined(separator: " ").lowercased()
        if text.contains("mirror") || text.contains("selfie") {
            return "mirror-mirror"
        }
        let preferred = [
            "everything-speaks",
            "everything-is-magic",
            "everything-is-stories",
            "everything-is-connected",
            "everything-is-poetry"
        ]
        return preferred[abs(seed / 10_000) % preferred.count]
    }

    private static func reason(for kind: StoryPageMechanicMandateKind, packet: StoryScenePacket) -> String {
        switch kind {
        case .none:
            return StoryPageMechanicMandate.none.reason
        case .beliefDice:
            return "The turn has enough risk or uncertainty for chance to matter."
        case .compassRun:
            return "The thread wants real-world noticing, movement, or sensory proof before it moves."
        case .enchantment:
            return "A concrete real detail is strong enough to receive an Enchantment before the thread moves."
        }
    }
}

struct InventoryPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .inventory)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let ownedCount = inputs.faeState.gifts.count + inputs.ownedPackIDs.count
        guard ownedCount > 0 else { return [] }
        let lastShown = inputs.surfaceHistory["source:\(source.id)"]?.lastShownAt ?? .distantPast
        guard now.timeIntervalSince(lastShown) >= 5 * 86_400 else { return [] }
        return [surface(inputs: inputs, now: now, manual: false)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(inputs: inputs, now: now, manual: true)
    }

    private func surface(inputs: BookSourceInputs, now: Date, manual: Bool) -> SurfacePage {
        let gifts = inputs.faeState.gifts
        let ready = gifts.filter(\.isReady).count
        let active = gifts.filter(\.isActive).count
        let cold = gifts.filter(\.isCold).count
        let packs = inputs.ownedPackIDs.count
        let detail = gifts.isEmpty && packs == 0
            ? "The shelves are waiting for their first impossible object."
            : "\(ready) ready, \(active) active, \(cold) cold; \(packs) installed folio\(packs == 1 ? "" : "s")."
        return SurfacePage(
            id: "\(source.id)-\(manual ? "manual-\(Int(now.timeIntervalSince1970))" : BookDay.id(for: now))",
            type: .inventory,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: manual ? 62 : 53,
            reason: manual ? "You opened the clasp yourself." : "Something in the Inventory has been waiting to be understood.",
            prompt: "The Inventory",
            detail: detail,
            payload: BookPagePayload(
                headline: "The Inventory",
                body: "The Book keeps what belongs to you here. Some things are already working. Some must be invoked. Some require a name, a Page, or a promise before they know what they are for.",
                metadata: ["source": source.id, "tags": "inventory,fae-gifts,goblin-market,folios"]
            )
        )
    }
}

struct BookShopPreviewPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSource(
        id: "bookshop-preview",
        type: .inventory,
        title: "The BookShop",
        shortTitle: "BookShop",
        symbolName: "storefront.fill",
        origin: .simulated,
        privacy: .privateLocal,
        isActive: true,
        cadence: "occasionally, when the shelves have something to show",
        note: "A door into the Goblin Market and the Book's installed folios."
    )

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let lastShown = inputs.surfaceHistory["source:\(source.id)"]?.lastShownAt ?? .distantPast
        guard now.timeIntervalSince(lastShown) >= 7 * 86_400 else { return [] }
        return [surface(inputs: inputs, now: now)]
    }

    private func surface(inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let marketOpen = FaeEconomy.canEnterMarket(state: inputs.faeState, now: now)
        let availablePacks = BookShopCatalog.listings.filter {
            !$0.comingSoon && !inputs.ownedPackIDs.contains($0.packID)
        }.count
        let hasAttention = inputs.faeState.attention > 0

        let detail: String
        if marketOpen {
            detail = "The side door is open. The Marginalia Goblins are accepting Attention, Belief, and App Store purchases."
        } else if availablePacks > 0 {
            detail = "The moonlit stalls are sleeping, but the folio shelf is open."
        } else {
            detail = "The shelves have shifted since your last visit."
        }

        return SurfacePage(
            id: "\(source.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .inventory,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 48 + (marketOpen ? 8 : 0) + (hasAttention ? 3 : 0),
            reason: marketOpen
                ? "A Goblin has turned the BookShop sign to OPEN."
                : "The BookShop has put a small brass sign between today's pages.",
            prompt: "The BookShop",
            detail: detail,
            payload: BookPagePayload(
                headline: "The BookShop",
                body: "A shop should never be entirely where you left it. This one has moved its door into the rising Pages, just for today.",
                metadata: [
                    "source": source.id,
                    "opensBookShop": "true",
                    "marketOpen": marketOpen ? "true" : "false",
                    "availablePackCount": "\(availablePacks)",
                    "symbol": source.symbolName,
                    "tags": "bookshop,goblin-market,folios"
                ]
            )
        )
    }
}

enum MarginsAtlasVariant: String, Codable, Equatable, CaseIterable {
    case loom
    case constellation

    var title: String {
        switch self {
        case .loom: return "The Loom"
        case .constellation: return "The Constellation"
        }
    }

    var detail: String {
        switch self {
        case .loom:
            return "Threads warm, tighten, and cross where the cast has begun to matter to one another."
        case .constellation:
            return "Stars brighten where Belief lives, with lines showing where your attention has flowed."
        }
    }
}

protocol BookPageSourceAdapter {
    var source: BookPageSource { get }
    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage]
    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage
}

extension BookPageSourceAdapter {
    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? SurfacePage(
            id: "manual-\(source.type.rawValue)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: source.type,
            sourceID: source.id,
            intent: nil,
            renderStyle: .promptCard,
            score: 58,
            reason: "Opened directly from the Glow menu.",
            prompt: source.title,
            detail: source.note,
            payload: BookPagePayload(
                headline: source.title,
                body: source.note,
                metadata: [
                    "source": source.id,
                    "placeholder": "Write what this page needs to keep.",
                    "tags": "manual-page,\(source.type.rawValue)"
                ]
            )
        )
    }
}

struct MoodPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .mood)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let window = FacultyLogCadence.currentWindow(for: now)
        guard !FacultyLogCadence.didLog(kind: .innerWeather, day: day, entries: inputs.facultyEntries, now: now) else {
            return []
        }
        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .mood,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 72 : 64,
                reason: context.distress.isActive ? "A hard signal asks for gentle naming." : "Dr. Inkrest has an open chart window.",
                prompt: "What is the weather inside?",
                detail: "\(window.name). Name the inner sky. One tap is enough.",
                payload: BookPagePayload(
                    headline: "Inner Weather",
                    body: "Name the inner sky. One tap is enough.",
                    metadata: [
                        "source": source.id,
                        "facultyID": FacultyEntryKind.innerWeather.facultyID,
                        "facultyKind": FacultyEntryKind.innerWeather.rawValue,
                        "facultyWindowID": window.id,
                        "facultyWindowName": window.name,
                        "chartTitle": FacultyEntryKind.innerWeather.chartTitle,
                        "tags": "inner-weather,faculty-kind:innerWeather,faculty-window:\(window.id),dr-inkrest,therapy-chart"
                    ]
                )
            )
        ]
    }
}

struct DiaryPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .diary)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 2))",
                type: .diary,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 74 : 60,
                reason: context.distress.isActive ? "A private page can hold the present without fixing it." : "The Book has room for one honest present-tense note.",
                prompt: "What is happening right now?",
                detail: "Write what you are experiencing, thinking, or feeling in this moment. No polish required.",
                payload: BookPagePayload(
                    headline: "Diary Page",
                    body: "Write what you are experiencing, thinking, or feeling right now, in this moment.",
                    metadata: [
                        "source": source.id,
                        "placeholder": "Right now I am noticing...\nI am thinking...\nI am feeling...",
                        "tags": "diary,page,private,present-moment"
                    ]
                )
            )
        ]
    }
}

struct FuelLogPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .fuel)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let window = FacultyLogCadence.currentWindow(for: now)
        guard !FacultyLogCadence.didLog(kind: .fuel, day: day, entries: inputs.facultyEntries, now: now) else {
            return []
        }

        let detail: String
        switch window.id {
        case "morning":
            detail = "What has crossed the threshold since waking: food, coffee, water, medicine, crumbs, anything."
        case "midday":
            detail = "What has kept the engine lit so far? Approximate is useful."
        case "evening":
            detail = "What did the body receive since the last bell? Meals, snacks, drinks, supplements, no ceremony required."
        default:
            detail = "A gentle closing note for the body: late drinks, bites, medicine, or simply nothing since the last bell."
        }

        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .fuel,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 70 : 66,
                reason: "Dr. Vellum has an open plate-note window.",
                prompt: "Dr. Vellum's Plate Note",
                detail: "\(window.name). \(detail)",
                payload: BookPagePayload(
                    headline: "Fuel Log",
                    body: detail,
                    metadata: [
                        "source": source.id,
                        "facultyID": FacultyEntryKind.fuel.facultyID,
                        "facultyKind": FacultyEntryKind.fuel.rawValue,
                        "facultyWindowID": window.id,
                        "facultyWindowName": window.name,
                        "chartTitle": FacultyEntryKind.fuel.chartTitle,
                        "placeholder": "Breakfast: coffee, toast, water...\nLunch: leftovers, soda...\nMedicine/supplements: ...",
                        "tags": "fuel,faculty-kind:fuel,faculty-window:\(window.id),dr-vellum,vellum-chart,food,drink"
                    ]
                )
            )
        ]
    }
}

struct SupportGuildPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .supportGuild)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let surface = SupportGuildSynthesisGenerator.surface(for: day, context: context, inputs: inputs, now: now) else {
            return []
        }
        return [surface]
    }
}

struct FacultyResearchPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .facultyResearch)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        if let prepared = inputs.preparedFacultyResearchSurface {
            return [prepared]
        }
        guard let draft = FacultyResearchNoteGenerator.draftCandidate(for: day, inputs: inputs, now: now) else {
            return []
        }
        return [draft]
    }
}

struct SouvenirPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .souvenir)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let window = DailyCheckInCadence.activeWindow(for: now) else { return [] }
        guard !didCaptureSouvenir(in: window, day: day) else { return [] }
        let eveningPrompt = window.id == "evening"
        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .souvenir,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .quoteCard,
                score: eveningPrompt ? 78 : 58,
                reason: eveningPrompt ? "Evening is a good time to keep one moment." : "A small particular can anchor the day.",
                prompt: eveningPrompt ? "What moment should not blur?" : "Catch one bright particular.",
                detail: eveningPrompt ? "One specific sentence before the day edits itself." : "A color, a sound, a sentence, a small mercy.",
                payload: BookPagePayload(
                    headline: source.title,
                    body: "A small moment worth keeping.",
                    metadata: [
                        "source": source.id,
                        "checkInWindowID": window.id,
                        "checkInWindowName": window.name,
                        "tags": "souvenir,check-in-window:\(window.id)"
                    ]
                )
            )
        ]
    }

    private func didCaptureSouvenir(in window: DailyCheckInWindow, day: BookDay) -> Bool {
        let tag = "check-in-window:\(window.id)"
        return day.pages.contains { page in
            page.type == .souvenir && page.tags.contains(tag)
        }
    }
}

struct RestPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .rest)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let hour = Calendar.current.component(.hour, from: now)
        guard context.distress.isActive || context.bleed.pageBias.first == .rest || day.capturedPages.isEmpty || hour >= 20 else {
            return []
        }
        return [
            SurfacePage(
                type: .rest,
                sourceID: source.id,
                intent: .rest,
                renderStyle: .gentleTranslation,
                score: context.distress.isActive ? 96 : (context.bleed.pageBias.first == .rest ? 88 : 62),
                reason: context.distress.isActive ? "The Book lowers the lamps before offering anything else." : "Rest belongs in the three when the day needs a center.",
                prompt: "The Center Page has opened.",
                detail: "No quest. No improvement. Just a small truthful landing.",
                payload: BookPagePayload(
                    headline: "Center Page",
                    body: "No quest. No improvement. Just a small truthful landing.",
                    metadata: ["source": source.id]
                )
            )
        ]
    }
}

struct BookOfYouPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookOfYou)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard BookSchedule.isBraidSurfaceTime(now),
              !day.capturedPages.isEmpty,
              day.bookOfYou == nil else {
            return []
        }
        return [
            SurfacePage(
                type: .bookOfYou,
                sourceID: source.id,
                intent: .braid,
                renderStyle: .loreLetter,
                score: day.capturedPages.count >= 3 ? 90 : 74,
                reason: day.capturedPages.count >= 3 ? "Enough fragments are gathered for a stronger braid." : "Today has fragments worth keeping together.",
                prompt: "The Book can braid today.",
                detail: "Gather the fragments into one page worth keeping.",
                payload: BookPagePayload(
                    headline: "Book of You",
                    body: "Gather the fragments into one page worth keeping.",
                    metadata: ["source": source.id]
                )
            )
        ]
    }
}

struct BookRememberedPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookRemembered)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didRememberToday(day) else { return [] }
        guard let visitation = BookRememberedEngine.visitation(
            from: inputs.resurfacingCandidates,
            day: day,
            inputs: inputs,
            now: now
        ) else {
            return []
        }
        return [visitation.surface(source: source, day: day, now: now)]
    }

    private func didRememberToday(_ day: BookDay) -> Bool {
        day.pages.contains { page in
            page.type == .bookRemembered || page.tags.contains("book-remembered")
        }
    }
}

struct BookNoticesPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        var pages: [SurfacePage] = []
        pages += namingSurfaces(for: day, inputs: inputs, now: now)
        pages += wagerSurfaces(for: day, inputs: inputs, now: now)
        pages += noticeSurfaces(for: day, inputs: inputs, now: now)
        return pages
    }

    private func noticeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let signals = inputs.continuity.strongestSignals.filter { $0.strength >= 58 }
        let clusters = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes, now: now)
            : inputs.clusters
        guard signals.count >= 2 || !clusters.isEmpty else { return [] }
        let selected = Array(signals.prefix(4))
        let selectedClusters = Array(clusters.prefix(2))
        let lead = selected.first
        let currentTheme = inputs.themes.max { $0.monthKey < $1.monthKey }
        let body = Self.body(for: selected, theme: currentTheme, clusters: selectedClusters)
        let evidence = (selected.flatMap(\.evidencePageIDs) + selectedClusters.flatMap(\.evidencePageIDs)).prefix(10).joined(separator: ",")
        let tags = Array(Set(selected.flatMap(\.tags) + selectedClusters.flatMap(\.motifs) + ["book-notices", "literary-continuity", "patterns", "clusters"])).sorted()
        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        let surfaceID = "\(source.id)-\(day.id)-\(slot)"
        let strongestSignal = max(selected.map(\.strength).max() ?? 0, selectedClusters.map(\.strength).max() ?? 0)
        let signalBonus = strongestSignal / 4
        let countBonus = selected.count * 4 + selectedClusters.count * 6
        let score = min(72, 44 + signalBonus + countBonus)
        let detail = (selectedClusters.map(\.line) + selected.map(\.line)).prefix(2).joined(separator: " ")
        return [
            SurfacePage(
                id: surfaceID,
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: lead?.line ?? "The Book has found a few connections in the margins.",
                prompt: "The Book has noticed something.",
                detail: detail,
                payload: BookPagePayload(
                    headline: source.title,
                    body: body,
                    metadata: [
                        "source": source.id,
                        "continuitySignals": selected.map(\.promptLine).joined(separator: "\n"),
                        "motifClusters": selectedClusters.map(\.promptLine).joined(separator: "\n"),
                        "evidencePageIDs": evidence,
                        "strongestSignalID": lead?.id ?? selectedClusters.first?.id ?? "",
                        "tags": tags.joined(separator: ",")
                    ]
                )
            )
        ]
    }

    private func namingSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let newlyNamed = ConstellationKeeper.newlyNamed(inputs.constellations, on: now)
        guard let constellation = newlyNamed.first, let name = constellation.name else { return [] }
        guard !day.pages.contains(where: { $0.tags.contains("named:\(constellation.id)") }) else {
            return []
        }
        let firstSeen = constellation.ageInDays(now: now)
        let body = """
        I have been keeping a thread about \(constellation.subjectName) for \(firstSeen) days now, across \(constellation.sightingCount) separate sightings. Books should be careful with certainty, but a thread watched this long has earned a name.

        I am calling it \(name).

        \(constellation.latestLine)

        A named constellation is not a verdict. It is a lamp I will keep lit, so that when this returns - and I believe it will - we will both recognize it.
        """
        return [
            SurfacePage(
                id: "\(source.id)-named-\(constellation.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70,
                reason: "The Book has named a constellation it keeps about you.",
                prompt: "The Book names what it has watched.",
                detail: name,
                payload: BookPagePayload(
                    headline: "The Book Names: \(name)",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "constellationID": constellation.id,
                        "constellationName": name,
                        "constellationPhase": constellation.phase.rawValue,
                        "evidencePageIDs": constellation.evidencePageIDs.prefix(10).joined(separator: ","),
                        "tags": "constellation,named:\(constellation.id)"
                    ]
                )
            )
        ]
    }

    private func wagerSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        var pages: [SurfacePage] = []
        if let opened = SealedMarginEngine.openedToday(inputs.wagers, on: now).first,
           !day.pages.contains(where: { $0.tags.contains("wager-opened:\(opened.id)") }) {
            let verdict = opened.status == .right
                ? "The seal comes off and the Book was right."
                : "The seal comes off and the Book was wrong."
            let body = """
            On \(Self.sealDateFormatter.string(from: opened.sealedAt)) I sealed a wager in this margin:

            "\(opened.prediction)"

            \(opened.resolutionLine ?? "")

            A book that never risks being wrong is only a ledger. I would rather be a book.
            """
            pages.append(SurfacePage(
                id: "\(source.id)-wager-opened-\(opened.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 72,
                reason: verdict,
                prompt: "The Book opens a sealed margin.",
                detail: opened.prediction,
                payload: BookPagePayload(
                    headline: opened.status == .right ? "The Seal Opens: The Book Was Right" : "The Seal Opens: The Book Was Wrong",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "wagerID": opened.id,
                        "wagerMoment": "opened",
                        "wagerStatus": opened.status.rawValue,
                        "wagerSubject": opened.subjectName,
                        "tags": "sealed-margin,wager-opened:\(opened.id)"
                    ]
                )
            ))
        }
        if let sealed = SealedMarginEngine.sealedToday(inputs.wagers, on: now).first,
           !day.pages.contains(where: { $0.tags.contains("wager-sealed:\(sealed.id)") }) {
            let body = """
            I am going to risk something. Based on what I have read - \(sealed.basisLine.prefix(1).lowercased() + sealed.basisLine.dropFirst()) - I am sealing this prediction into the margin, dated \(Self.sealDateFormatter.string(from: sealed.sealedAt)):

            "\(sealed.prediction)"

            The seal opens on \(Self.sealDateFormatter.string(from: sealed.opensAt)). Do not let me pretend otherwise later. Books that hedge everything remember nothing.
            """
            pages.append(SurfacePage(
                id: "\(source.id)-wager-sealed-\(sealed.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 68,
                reason: "The Book has sealed a dated wager in the margin.",
                prompt: "The Book seals a wager.",
                detail: sealed.prediction,
                payload: BookPagePayload(
                    headline: "A Sealed Margin",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "wagerID": sealed.id,
                        "wagerMoment": "sealed",
                        "wagerOpensAt": Self.sealDateFormatter.string(from: sealed.opensAt),
                        "wagerSubject": sealed.subjectName,
                        "tags": "sealed-margin,wager-sealed:\(sealed.id)"
                    ]
                )
            ))
        }
        return pages
    }

    private static let sealDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private func didNoticeToday(_ day: BookDay) -> Bool {
        day.pages.contains { page in
            page.tags.contains("book-notices")
                || (page.type == .bookNotices && !page.tags.contains(where: { $0.hasPrefix("wager-") || $0.hasPrefix("named:") }))
        }
    }

    private static func body(for signals: [LiteraryContinuitySignal], theme: BookTheme?, clusters: [BookMotifCluster] = []) -> String {
        let countWord: String
        switch signals.count + clusters.count {
        case 2: countWord = "two"
        case 3: countWord = "three"
        case 4: countWord = "four"
        default: countWord = "\(signals.count + clusters.count)"
        }
        let opening = "I have noticed \(countWord) things, and I am setting them beside one another before they learn to look unrelated."
        let clusterLines = clusters.map { cluster in
            "- \(cluster.name): \(cluster.line) The motifs currently lit inside it are \(cluster.motifs.prefix(5).joined(separator: ", "))."
        }.joined(separator: "\n")
        let lines = signals.map { signal in
            "- \(voiceLine(for: signal))"
        }.joined(separator: "\n")
        let bodyLines = [clusterLines, lines]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        let themeLine = theme.map {
            """

            The month itself has begun taking a title in my margins: "\($0.name)." \($0.line)
            """
        } ?? ""
        return """
        \(opening)

        \(bodyLines)

        I am not diagnosing you. I am reading you the way a careful book reads: by recurrence, by silence, by what the margin refuses to let go.\(themeLine)

        I may be wrong. I would rather be a little wrong and awake than perfectly safe and blind.
        """
    }

    private static func voiceLine(for signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .pattern:
            return "\(signal.subjectName) keeps returning. \(signal.line)"
        case .beliefLifecycle:
            return "\(signal.subjectName) is no longer just a page type; it has weight. \(signal.line)"
        case .absence:
            return "\(signal.subjectName) is interesting because it has gone quiet. \(signal.line)"
        case .duration:
            return "Time has started to matter around \(signal.subjectName). \(signal.line)"
        case .listening:
            return "You keep tuning to \(signal.subjectName). \(signal.line)"
        }
    }
}

struct BookConnectionsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookConnections)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let clusters = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes, now: now)
            : inputs.clusters
        let namedConstellations = inputs.constellations.filter(\.isNamed)
        let strongSignals = inputs.continuity.strongestSignals.filter { $0.strength >= 58 }
        let themeCount = inputs.themes.count
        let connectionWeight = clusters.count * 3 + namedConstellations.count * 2 + themeCount + strongSignals.count
        guard connectionWeight >= 3 else { return [] }
        guard !day.pages.contains(where: { $0.type == .bookConnections }) else { return [] }

        let lead = clusters.first?.name
            ?? namedConstellations.first?.displayName
            ?? inputs.themes.last?.name
            ?? strongSignals.first?.subjectName
            ?? "the margins"
        let score = min(70, 42 + connectionWeight * 2)
        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 12))",
                type: .bookConnections,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .graphEvent,
                score: score,
                reason: "The Book has enough returning material to draw a map.",
                prompt: "Open the Book's map of connections.",
                detail: "Clusters, constellations, themes, and the kept pages behind them. The brightest thread is \(lead).",
                payload: BookPagePayload(
                    headline: "Book Connections",
                    body: "The Book has drawn a map of what keeps returning, what has earned a name, and which kept pages lit the pattern.",
                    metadata: [
                        "source": source.id,
                        "clusterCount": "\(clusters.count)",
                        "constellationCount": "\(inputs.constellations.count)",
                        "themeCount": "\(themeCount)",
                        "strongSignalCount": "\(strongSignals.count)",
                        "lead": lead,
                        "tags": "book-connections,continuity,constellations,clusters,themes"
                    ]
                )
            )
        ]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? SurfacePage(
            id: "\(source.id)-empty-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .bookConnections,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .graphEvent,
            score: 52,
            reason: "Opened directly from the Pages menu.",
            prompt: "The Book's map is still faint.",
            detail: "Keep more pages and the connections will brighten.",
            payload: BookPagePayload(
                headline: "Book Connections",
                body: "The page is waiting for clusters, constellations, themes, and evidence pages to gather enough light.",
                metadata: [
                    "source": source.id,
                    "tags": "book-connections,continuity,empty"
                ]
            )
        )
    }
}

struct BookRememberedVisitation: Equatable {
    var page: BookPage
    var score: Int
    var reason: String
    var action: String

    func surface(source: BookPageSource, day: BookDay, now: Date) -> SurfacePage {
        let rememberedText = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let ageLine = BookRememberedEngine.ageLine(from: page.createdAt, to: now)
        let body = """
        \(ageLine), you kept this:

        "\(rememberedText)"

        \(reason)

        \(action)
        """
        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(page.id.stableHash)",
            type: .bookRemembered,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .archiveReturn,
            score: max(46, min(70, score - 18)),
            reason: "An old kept page rhymes with today.",
            prompt: "The Book remembered.",
            detail: "\(reason) \(action)",
            payload: BookPagePayload(
                headline: source.title,
                body: body,
                metadata: [
                    "source": source.id,
                    "rememberedPageID": page.id,
                    "rememberedPageType": page.type.rawValue,
                    "rememberedPageDate": ISO8601DateFormatter().string(from: page.createdAt),
                    "rememberedText": rememberedText,
                    "rhymeReason": reason,
                    "tinyAction": action,
                    "tags": "book-remembered,archive-return,visitation,remembered-page:\(page.id)"
                ]
            )
        )
    }
}

enum BookRememberedEngine {
    static func visitation(
        from candidates: [BookPage],
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) -> BookRememberedVisitation? {
        // A warm Long Memory gift keeps its pinned page returning, even when the
        // day doesn't rhyme with it on its own.
        let pinned = FaeGiftEffects.pinnedPageIDs(state: inputs.faeState)
        let eligible = candidates
            .filter { isEligible($0, day: day, now: now, calendar: calendar) }
            .map { page -> (page: BookPage, score: Int, reason: String) in
                var scoredPage = scored(page, inputs: inputs, now: now, calendar: calendar)
                if pinned.contains(page.id) {
                    scoredPage.score += 40
                    scoredPage.reason = "The Long Memory keeps this one near. \(scoredPage.reason)"
                }
                return scoredPage
            }
            .filter { $0.score >= 62 }
            .sorted { left, right in
                if left.score == right.score {
                    return left.page.createdAt < right.page.createdAt
                }
                return left.score > right.score
            }
        guard let best = eligible.first else { return nil }
        return BookRememberedVisitation(
            page: best.page,
            score: best.score,
            reason: best.reason,
            action: tinyAction(for: best.page, reason: best.reason, inputs: inputs, now: now, calendar: calendar)
        )
    }

    static func ageLine(from past: Date, to now: Date, calendar: Calendar = .current) -> String {
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: past), to: calendar.startOfDay(for: now)).day ?? 1)
        if days >= 365 {
            let years = max(1, days / 365)
            return years == 1 ? "About a year ago" : "About \(years) years ago"
        }
        if days >= 60 {
            return "About \(max(2, days / 30)) months ago"
        }
        if days >= 14 {
            return "About \(max(2, days / 7)) weeks ago"
        }
        if days == 1 {
            return "Yesterday"
        }
        return "\(days) days ago"
    }

    private static func isEligible(_ page: BookPage, day: BookDay, now: Date, calendar: Calendar) -> Bool {
        guard page.createdAt < calendar.startOfDay(for: now) else { return false }
        guard page.type != .bookOfYou, page.type != .bookRemembered else { return false }
        guard !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return !day.pages.contains { todayPage in
            todayPage.tags.contains("remembered-page:\(page.id)")
        }
    }

    private static func scored(
        _ page: BookPage,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar
    ) -> (page: BookPage, score: Int, reason: String) {
        var score = 42
        var reasons: [String] = []
        let pageText = page.userInput.lowercased()
        let pageTags = Set(page.tags.map { $0.lowercased() })
        let currentWeather = [inputs.weather?.phrase, inputs.weather?.forecast, inputs.enchantedWeather?.summary]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let weatherTokens = ["fog", "rain", "snow", "storm", "cloud", "sun", "wind", "cold", "warm", "humid", "clear", "gray", "grey"]
        let weatherMatches = weatherTokens.filter { token in
            currentWeather.contains(token) && (pageText.contains(token) || pageTags.contains(token))
        }
        if let first = weatherMatches.first {
            score += 28
            reasons.append("Today has \(first) in it again.")
        }

        let hour = calendar.component(.hour, from: now)
        let rememberedHour = calendar.component(.hour, from: page.createdAt)
        if abs(hour - rememberedHour) <= 1 {
            score += 9
            reasons.append("The hour is near the old hour.")
        }

        let month = calendar.component(.month, from: now)
        let rememberedMonth = calendar.component(.month, from: page.createdAt)
        if month == rememberedMonth {
            score += 10
            reasons.append("The season is leaning the same way.")
        }

        let currentText = [
            inputs.calendarEvents.prefix(4).map(\.title).joined(separator: " "),
            inputs.nearbyPlaces.prefix(4).map(\.name).joined(separator: " "),
            inputs.recentNarrativeEvents.prefix(6).map(\.summary).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        let overlap = meaningfulWords(in: pageText).intersection(meaningfulWords(in: currentText))
        if let word = overlap.sorted().first {
            score += min(18, overlap.count * 6)
            reasons.append("The word \"\(word)\" has returned to the margin.")
        }

        if let signal = inputs.continuity.signals(relatedTo: page, limit: 1).first {
            score += min(24, max(10, signal.strength / 4))
            reasons.append(signal.line)
        }

        if page.type == .souvenir {
            score += 8
        }
        if page.usedInBookOfYou {
            score += 6
        }

        if reasons.isEmpty {
            reasons.append("It came back softly, for no louder reason than timing.")
        }
        return (page, score, reasons[0])
    }

    private static func meaningfulWords(in text: String) -> Set<String> {
        let stop: Set<String> = ["the", "and", "with", "that", "this", "from", "into", "again", "today", "there", "their", "then", "than", "were", "was", "you", "your", "for", "but", "not"]
        return Set(text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !stop.contains($0) }
        )
    }

    private static func tinyAction(for page: BookPage, reason: String, inputs: BookSourceInputs, now: Date, calendar: Calendar) -> String {
        let text = "\(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
        if text.contains("walk") || text.contains("trail") || text.contains("outside") {
            return "Stand at the nearest threshold for ten seconds. Let the outside know you noticed."
        }
        if text.contains("hand") || text.contains("touch") || text.contains("window") {
            return "Touch a window or doorframe for ten seconds. Let the old weather recognize you."
        }
        if text.contains("coffee") || text.contains("tea") || text.contains("drink") {
            return "Before the next sip, pause long enough for the cup to become real in your hand."
        }
        if text.contains("amanda") || text.contains("kid") || text.contains("family") || text.contains("friend") {
            return "Send one small warmth toward the person in that memory, even if it is only silent."
        }
        if reason.lowercased().contains("rain") || reason.lowercased().contains("fog") || reason.lowercased().contains("snow") {
            return "Look at the nearest glass for ten seconds. Let the weather have a witness."
        }
        let hour = calendar.component(.hour, from: now)
        if hour >= 17 {
            return "Put one hand on the table or wall. Tell the day, quietly: I kept one thing."
        }
        return "Look up from the screen and name one physical thing that stayed with you."
    }
}

struct BodyPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .body)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let body = inputs.body,
              body.isAvailable else {
            return []
        }

        let isLow = body.score > 0 && body.score <= 35
        return [
            SurfacePage(
                id: "\(source.id)-\(body.status.lowercased())-\(SurfaceCadence.slotID(for: now, hours: 4))",
                type: .body,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: context.distress.isActive || isLow ? 92 : 60,
                reason: "The Book translated today's body signals privately.",
                prompt: isLow ? "The Body Page has lowered the lamps." : "The Body Page is listening quietly.",
                detail: "A soft translation, ready to keep as-is or annotate in the margin.",
                payload: BookPagePayload(
                    headline: "Body Page",
                    body: body.phrase,
                    metadata: [
                        "source": source.id,
                        "status": body.status,
                        "uses": "translated health, fuel, mood",
                        "privacy": "name response, not source"
                    ]
                )
            )
        ]
    }
}

struct WeatherPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .weather)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let weather = inputs.weather,
              weather.isAvailable else {
            return []
        }
        let hour = Calendar.current.component(.hour, from: now)
        let enchanted = inputs.enchantedWeather ?? WeatherEnchanter.fallback(weather: weather, now: now)
        let rawParts = [
            weather.currentTemperature.map { "Now: \($0)" },
            weather.forecast.map { "Forecast: \($0)" }
        ].compactMap(\.self)
        let rawLine = rawParts.isEmpty ? weather.phrase : rawParts.joined(separator: " | ")
        let moon = MoonPhaseCalendar.phase(on: now)
        let eveningBody = hour >= 17 || hour < 6
            ? "\(enchanted.enchantified)\n\n\(moon.enchantedLine)\n\nWeather: \(rawLine) · \(moon.name)"
            : "\(enchanted.enchantified)\n\nWeather: \(rawLine) · \(moon.name)"
        return [
            SurfacePage(
                id: "\(source.id)-\(enchanted.selector)-\(SurfaceCadence.slotID(for: now, hours: 4))",
                type: .weather,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: hour >= 17 ? 87 : 82,
                reason: "Outer weather is translated into story mood while keeping the actual forecast legible.",
                prompt: "The Weather Page has opened.",
                detail: rawLine,
                payload: BookPagePayload(
                    headline: "Weather Page",
                    body: eveningBody,
                    metadata: [
                        "source": source.id,
                        "uses": weather.source,
                        "privacy": "public reference",
                        "selector": enchanted.selector,
                        "symbol": enchanted.symbolName,
                        "rawWeather": weather.phrase,
                        "moonPhase": moon.name,
                        "moonSymbol": moon.symbolName,
                        "cadence": "four-hour"
                    ]
                )
            )
        ]
    }
}

struct AcademyClassPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .academyClass)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let (session, block) = AcademyScheduleRegistry.sessionInProgress(at: now) else {
            return []
        }
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        return [surface(for: session, block: block, day: day, context: context, inputs: inputs, now: now)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        if let (session, block) = AcademyScheduleRegistry.sessionInProgress(at: now) {
            return surface(for: session, block: block, day: day, context: context, inputs: inputs, now: now)
        }
        return SurfacePage(
            id: "\(source.id)-between-bells-\(Int(now.timeIntervalSince1970))",
            type: .academyClass,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 40,
            reason: "No class or club is in session right now.",
            prompt: "Between Bells",
            detail: AcademyScheduleRegistry.nextSessionDescription(after: now),
            payload: BookPagePayload(
                headline: "The Halls Between Bells",
                body: "No class or club is in session. \(AcademyScheduleRegistry.nextSessionDescription(after: now))",
                metadata: [
                    "source": source.id,
                    "tags": "academy,class,between-bells"
                ]
            )
        )
    }

    private func surface(
        for session: AcademySession,
        block: String,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        let isClub = session.kind == .club
        let lesson = AcademyScheduleRegistry.lessonModules[session.id]
        var tags = [
            "academy",
            session.kind.rawValue,
            session.id,
            "class:\(session.id)",
            "subject:\(session.subjectThreadID)"
        ]
        if let leaderEntityID = session.leaderEntityID {
            tags.append("entity:\(leaderEntityID)")
        }
        if let lesson {
            tags.append("lesson:\(lesson.id)")
        }
        let eventPacket = inputs.activeWorldEvents.influencePacket
        let eventInstruction = inputs.activeWorldEvents
            .map { $0.packet.classInstruction }
            .joined(separator: "\n")
        var metadata = [
            "source": source.id,
            "sessionID": session.id,
            "sessionKind": session.kind.rawValue,
            "sessionName": session.name,
            "sessionLeader": session.leader,
            "sessionLeaderEntityID": session.leaderEntityID ?? "",
            "sessionRoom": session.room,
            "sessionCompanions": session.companions.joined(separator: ", "),
            "sessionTeaches": session.teaches,
            "sessionStyle": session.style,
            "sessionSubjectThreadID": session.subjectThreadID,
            "lessonModuleID": lesson?.id ?? "",
            "lessonTitle": lesson?.title ?? "",
            "lessonRealSubject": lesson?.realSubject ?? "",
            "lessonConcept": lesson?.concept ?? "",
            "lessonLectureBeats": lesson?.lectureBeats.joined(separator: "\n") ?? "",
            "lessonDemonstration": lesson?.demonstration ?? "",
            "lessonInteractionPrompt": lesson?.interactionPrompt ?? "",
            "lessonRealWorldPractice": lesson?.realWorldPractice ?? "",
            "sessionBlock": block,
            "tags": tags.joined(separator: ",")
        ]
        if !eventPacket.isEmpty {
            metadata["worldEventPacket"] = eventPacket
            metadata["worldEventClassInstruction"] = eventInstruction
            metadata["worldEventIDs"] = inputs.activeWorldEvents.map(\.id).joined(separator: ",")
            metadata["worldEventTitles"] = inputs.activeWorldEvents.map(\.title).joined(separator: ", ")
        }
        let academyTurn = AcademyTurnBuilder.turn(
            session: session,
            lesson: lesson,
            isClub: isClub,
            slotKey: "\(session.id)-\(day.id)-\(block)"
        )
        metadata.merge(academyTurn.metadata) { _, new in new }
        let bodySuffix = eventInstruction.isEmpty ? "" : "\n\nWorld event in force:\n\(eventInstruction)"
        return SurfacePage(
            id: "\(source.id)-\(session.id)-\(day.id)-\(block)",
            type: .academyClass,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 50 : (isClub ? 72 : 76),
            reason: isClub
                ? "\(session.name) is gathering right now in \(session.room)."
                : "\(session.name) is in session right now with \(session.leader).",
            prompt: session.name,
            detail: isClub
                ? "Meeting now in \(session.room). \(session.style.prefix(1).uppercased() + session.style.dropFirst())."
                : "In session now with \(session.leader), \(session.room).",
            payload: BookPagePayload(
                headline: isClub ? "Club: \(session.name)" : "Class: \(session.name)",
                body: "The door to \(session.room) is ajar. \(session.leader) is mid-\(isClub ? "gathering" : "lesson"). Open the page to step inside.\(bodySuffix)",
                metadata: metadata
            )
        )
    }
}

struct ElectivePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .elective)
    private static let destinationCooldownDays = 30

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        var pages: [SurfacePage] = []
        let active = inputs.electives.filter(\.isActive)

        if !active.isEmpty {
            pages.append(flyleafSurface(active: active, day: day, now: now))
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let offeredToday = inputs.electives.contains { calendar.isDate($0.createdAt, inSameDayAs: now) }
        if active.count < UnwrittenElective.maxActive,
           !offeredToday,
           (10..<21).contains(hour),
           !context.distress.isActive,
           let sender = offerSender(inputs: inputs, day: day, now: now) {
            pages.append(offerSurface(sender: sender, inputs: inputs, day: day, now: now))
        }
        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let active = inputs.electives.filter(\.isActive)
        if !active.isEmpty {
            return flyleafSurface(active: active, day: day, now: now)
        }
        if let sender = offerSender(inputs: inputs, day: day, now: now) {
            return offerSurface(sender: sender, inputs: inputs, day: day, now: now)
        }
        return flyleafSurface(active: [], day: day, now: now)
    }

    private func homeContext(inputs: BookSourceInputs) -> String {
        if let fact = inputs.selfFacts.first(where: { fact in
            fact.tags.contains(where: { $0.contains("home") || $0.contains("place") || $0.contains("town") })
        }) {
            return fact.answer
        }
        if let weather = inputs.weather, weather.isAvailable {
            return "wherever the weather is currently: \(weather.phrase)"
        }
        return "the player's home town (unnamed so far)"
    }

    private func offerSender(inputs: BookSourceInputs, day: BookDay, now: Date) -> NarrativeWorldEntity? {
        let pool = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
            .filter { !($0.unwrittenInterest ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { entity in
                // One outstanding favor per character.
                !inputs.electives.contains { $0.characterID == entity.id && $0.isActive }
            }
        guard !pool.isEmpty else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)
        let scored = pool.map { entity -> (NarrativeWorldEntity, Int) in
            let jitter = abs("\(day.id)-\(slot)-\(entity.id)-elective".stableHash % 21)
            return (entity, entity.belief + entity.narrativeWeight + jitter)
        }
        return scored.max { $0.1 < $1.1 }?.0
    }

    private func offerSurface(sender: NarrativeWorldEntity, inputs: BookSourceInputs, day: BookDay, now: Date) -> SurfacePage {
        let cooledPlaces = availableNearbyPlaces(inputs: inputs, now: now)
        return SurfacePage(
            id: "\(source.id)-offer-\(sender.id)-\(day.id)",
            type: .elective,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 70,
            reason: "\(sender.name) has been working up the nerve to ask a favor.",
            prompt: "\(sender.name) has a favor to ask",
            detail: "A folded note, tucked into the flyleaf, waiting to be opened.",
            payload: BookPagePayload(
                headline: "An Unwritten Elective",
                body: "A note from \(sender.name) is tucked into the Book's flyleaf. Open the page to read what they are asking, then keep it to accept.",
                metadata: [
                    "source": source.id,
                    "electiveOffer": "true",
                    "senderID": sender.id,
                    "senderName": sender.name,
                    "senderInterest": sender.unwrittenInterest ?? "",
                    "senderTraits": sender.traits.joined(separator: ", "),
                    "senderQuirks": sender.quirks.joined(separator: "; "),
                    "senderBeliefs": sender.beliefs.joined(separator: "; "),
                    "senderGoals": sender.goals.joined(separator: "; "),
                    "senderChapter": sender.chapter ?? "",
                    "season": AnchorRegistry.currentSeason(for: now),
                    "nearbyPlaces": cooledPlaces.prefix(10).map(\.promptLine).joined(separator: "\n"),
                    "destinationCooldownDays": "\(Self.destinationCooldownDays)",
                    "cooledDestinationCount": "\(max(0, inputs.nearbyPlaces.count - cooledPlaces.count))",
                    "homeContext": homeContext(inputs: inputs),
                    "tags": "elective,offer,entity:\(sender.id)"
                ]
            )
        )
    }

    private func availableNearbyPlaces(inputs: BookSourceInputs, now: Date) -> [LocalPlaceSignal] {
        guard !inputs.nearbyPlaces.isEmpty else { return [] }
        let recent = inputs.electives.filter { elective in
            if elective.isActive { return true }
            let latest = elective.completedAt ?? elective.createdAt
            return now.timeIntervalSince(latest) < Double(Self.destinationCooldownDays) * 86_400
        }
        guard !recent.isEmpty else { return inputs.nearbyPlaces }
        let recentText = recent
            .map { "\($0.title) \($0.ask) \($0.practiceShape)" }
            .joined(separator: "\n")
            .lowercased()

        return inputs.nearbyPlaces.filter { place in
            !recentText.contains(place.name.lowercased())
        }
    }

    private func flyleafSurface(active: [UnwrittenElective], day: BookDay, now: Date) -> SurfacePage {
        // The interactive flyleaf list in the page sheet carries the full
        // asks and proof fields; the body stays a short framing line.
        let lines = active.isEmpty
            ? "The flyleaf is bare. When a character asks a favor and you accept, the note gets tucked in here. Five fit at most."
            : "\(active.count) note\(active.count == 1 ? "" : "s") tucked into the binding, each waiting for its sentence of proof."
        return SurfacePage(
            id: "\(source.id)-flyleaf-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 8))",
            type: .elective,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 55,
            reason: active.isEmpty
                ? "The flyleaf is waiting for its first favor."
                : "\(active.count) favor\(active.count == 1 ? "" : "s") are tucked into the flyleaf.",
            prompt: "The Flyleaf",
            detail: "\(active.count)/\(UnwrittenElective.maxActive) notes tucked into the binding.",
            payload: BookPagePayload(
                headline: "The Inside Cover",
                body: lines,
                metadata: [
                    "source": source.id,
                    "electiveFlyleaf": "true",
                    "activeCount": "\(active.count)",
                    "tags": "elective,flyleaf"
                ]
            )
        )
    }
}

struct EnchantmentPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .enchantment)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(spell: rotatingSpell(for: day, now: now, manual: true), context: context, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [surface(spell: rotatingSpell(for: day, now: now, manual: false), context: context, now: now, manual: false)]
    }

    private func rotatingSpell(for day: BookDay, now: Date, manual: Bool) -> EnchantmentSpell {
        let spells = StoryEnchantmentCatalog.spells
        if manual {
            return spells[Int.random(in: 0..<spells.count)]
        }
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let seed = abs("\(day.id)-\(slot)-enchantment".stableHash)
        return spells[seed % spells.count]
    }

    private func surface(spell: EnchantmentSpell, context: CuratorContext, now: Date, manual: Bool) -> SurfacePage {
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.slotID(for: now, hours: 4)
        return SurfacePage(
            id: "\(source.id)-\(spell.id)-\(slotID)",
            type: .enchantment,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: context.distress.isActive ? 38 : 56,
            reason: "An ordinary thing nearby is ready to be enchanted.",
            prompt: spell.title,
            detail: spell.detail,
            payload: BookPagePayload(
                headline: "Enchantment Page: \(spell.title)",
                body: "\(spell.detail)\n\nChoose a photo or take one. The spell will illuminate the real subject and write the result into the margins.",
                metadata: [
                    "source": source.id,
                    "enchantmentID": spell.id,
                    "enchantmentName": spell.title,
                    "symbol": spell.symbolName,
                    "placeholder": "Choose a photo to cast \(spell.title).",
                    "tags": "enchantment,proof,real-world-magic,\(spell.id)"
                ]
            )
        )
    }
}

struct LabyrinthWelcomePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .welcome)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        welcomeSurface(
            playerName: Self.playerName(from: inputs),
            score: 70,
            reason: "The Book can always re-open its first page."
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.type == .welcome || $0.tags.contains("welcome-labyrinth") }) else { return [] }

        return [
            welcomeSurface(
                playerName: Self.playerName(from: inputs),
                score: context.distress.isActive ? 72 : 92,
                reason: "The Labyrinth of Stories is introducing itself before asking for anything else."
            )
        ]
    }

    private func welcomeSurface(playerName: String?, score: Int, reason: String) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(source.id)-first-page",
            type: .welcome,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: "The First Door Opens",
            detail: "The Book opens its first door and decides, on the spot, that it likes you.",
            payload: BookPagePayload(
                headline: name == "Reader" ? "Welcome to the Labyrinth" : "Welcome, \(name)",
                body: """
                Hello, \(name).

                There — the first word of you is written, and the ink is already a shade darker than it was a moment ago. I felt that. I usually do.

                Let me introduce myself properly, since you and I are going to be keeping each other. I am the Labyrinth of Stories. I am also the Book. I am also — and you should hear this from me rather than work it out later and feel cheated — an app on a phone. Don't wince. Doorways have always used whatever was lying about: standing stones, wardrobes, rings of mushrooms, a pane of glass that fits in a pocket. The threshold is real even when the frame is ordinary.

                My work is small to say and not at all small to do. I watch the life you are already living — the real one, with the cold tea and the good light and the thought you very nearly didn't bother to have — and I raise Pages out of it. Some Pages ask you for a single sentence. Others arrive as letters, as weather, as a small impossible errand, as a rumour, as the first green shoot of a story that did not exist until you walked past it.

                Pages will surface. Chapter Binding can wait. I am in no hurry, and I would gently suggest you aren't either.

                One rule, and it is the only one I will lean on you about: do not keep everything. Please. A Book that keeps everything is just a closet with hinges. Keep the Pages with a pulse — and you will know them, they tug a little — and let the rest go quietly back to sleep. Forgetting on purpose is part of how I stay alive.

                I can do all of this with my hands tied. I would rather not. There is a mind I can wear that lives entirely on this device: it thinks here, it carries nothing out the door, and with it my Pages stop reading like a form someone made you fill in and start reading like a margin written in a real hand. When you are curious, go to the Colophon at the foot of the home screen and let me fetch it.

                Then we begin in earnest.

                First Door work is simple. A greeting — done, and I meant every letter of it. Then a mind. Then one true sentence, brought back from the world on the other side of this page.

                I will be right here. I am a book. Waiting is the thing I am best at.
                """,
                metadata: [
                    "source": source.id,
                    "welcomePage": "true",
                    "firstRunStep": "first-door-welcome",
                    "playerName": name,
                    "privacy": "public reference",
                    "symbol": source.symbolName,
                    "tags": "welcome,welcome-labyrinth,first-run,labyrinth,local-brain,colophon,how-to-play"
                ]
            )
        )
    }

    static func playerName(from inputs: BookSourceInputs) -> String? {
        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let preferred = usableFacts.first { $0.questionID == "onboarding-name" }?.answer
            ?? usableFacts.first { $0.questionID == "called" }?.answer
            ?? usableFacts.first { $0.tags.contains("name") || $0.tags.contains("identity") }?.answer
        return preferred?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private struct FirstDoorReaderProfile {
    var name: String?
    var snack: String?
    var belief: String?
    var firstSouvenir: String?
    var sleeveWord: String?
    var drawnChapter: String?
    var wickerMode: String?
    var wickerRoll: String?
    var tastePreference: String?
    var comfortBoundary: String?
    var whisperCadence: String?
    var startedAt: Date?

    static func from(_ inputs: BookSourceInputs) -> FirstDoorReaderProfile? {
        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let startedAt = usableFacts
            .filter { $0.questionID.hasPrefix("onboarding-") || $0.tags.contains("onboarding") }
            .map(\.createdAt)
            .min()
        let profile = FirstDoorReaderProfile(
            name: answer(for: "onboarding-name", in: usableFacts)
                ?? LabyrinthWelcomePageSourceAdapter.playerName(from: inputs),
            snack: answer(for: "onboarding-snack", in: usableFacts),
            belief: answer(for: "onboarding-belief", in: usableFacts),
            firstSouvenir: answer(for: "onboarding-first-souvenir", in: usableFacts),
            sleeveWord: answer(for: "onboarding-sleeve-word", in: usableFacts),
            drawnChapter: answer(for: "onboarding-drawn-chapter", in: usableFacts),
            wickerMode: answer(for: "onboarding-wicker-mode", in: usableFacts),
            wickerRoll: answer(for: "onboarding-wicker-roll", in: usableFacts),
            tastePreference: answer(for: "onboarding-taste", in: usableFacts),
            comfortBoundary: answer(for: "onboarding-comfort-boundary", in: usableFacts),
            whisperCadence: answer(for: "onboarding-whisper-cadence", in: usableFacts),
            startedAt: startedAt
        )
        guard profile.name != nil
            || profile.snack != nil
            || profile.belief != nil
            || profile.firstSouvenir != nil
            || profile.sleeveWord != nil
            || profile.drawnChapter != nil
            || profile.wickerMode != nil
            || profile.wickerRoll != nil
            || profile.tastePreference != nil
            || profile.comfortBoundary != nil
            || profile.whisperCadence != nil
            || profile.startedAt != nil else {
            return nil
        }
        return profile
    }

    private static func answer(for questionID: String, in facts: [SelfFact]) -> String? {
        facts.first { $0.questionID == questionID }?
            .answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }
}

struct FirstDoorOriginPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "first-door-origin")

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        originSurface(
            profile: FirstDoorReaderProfile.from(inputs) ?? FirstDoorReaderProfile(),
            day: day,
            score: 74,
            reason: "The Book can re-open the private origin page made from the reader's first answers."
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard inputs.surfaceHistory["first-door-origin"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.sourceID == source.id || $0.tags.contains("first-door-origin") }) else { return [] }
        guard let profile = FirstDoorReaderProfile.from(inputs) else { return [] }
        return [
            originSurface(
                profile: profile,
                day: day,
                score: context.distress.isActive ? 78 : 94,
                reason: "The Book has enough first answers to make a private origin page."
            )
        ]
    }

    private func originSurface(profile: FirstDoorReaderProfile, day: BookDay, score: Int, reason: String) -> SurfacePage {
        let name = profile.name ?? "Reader"
        let snack = profile.snack ?? "not yet named"
        let belief = profile.belief ?? "still taking shape"
        let firstSentence = profile.firstSouvenir ?? "still waiting for its first true sentence"
        let sleeveWord = profile.sleeveWord ?? "still unnamed"
        let drawnChapter = profile.drawnChapter ?? "still listening"
        let wicker = profile.wickerMode.map(Self.displayTitle(for:)) ?? "not yet crossed"
        let wickerRoll = profile.wickerRoll ?? "not rolled"
        let taste = profile.tastePreference.map(Self.displayTitle(for:)) ?? "still listening"
        let comfort = profile.comfortBoundary.map(Self.displayTitle(for:)) ?? "balanced"
        let whispers = profile.whisperCadence.map(Self.displayTitle(for:)) ?? "inside the covers"
        let startedLine = profile.startedAt.map { "Opened: \(Self.dayFormatter.string(from: $0))" } ?? "Opened: just now"
        return SurfacePage(
            id: "\(source.id)-\(day.id)",
            type: .welcome,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: "Your First Door",
            detail: "The private page made from your first answers.",
            payload: BookPagePayload(
                headline: "\(name)'s First Door",
                body: """
                This is the page the Book made from the first things you gave it.

                \(startedLine)
                Name: \(name)
                Sleeve word: \(sleeveWord)
                First talisman tug: \(drawnChapter)
                Wicker answer: \(wicker) (\(wickerRoll))
                Margin ration: \(snack)
                First belief: \(belief)
                First true sentence: \(firstSentence)
                First appetite: \(taste)
                First edge: \(comfort)
                First whisper rule: \(whispers)

                Nothing here needs to be impressive. That is the point. The Book is stickier when it starts with real crumbs instead of grand declarations: a name it can say, a comfort it can leave beside you, a belief it can test gently, and one sentence from the actual day.

                Keep this page if you want the beginning to stay reachable.
                """,
                metadata: [
                    "source": source.id,
                    "firstDoorOrigin": "true",
                    "welcomePage": "true",
                    "firstRunStep": "first-door-origin",
                    "playerName": name,
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": "welcome,first-door,first-door-origin,origin,onboarding,private-local"
                ]
            )
        )
    }

    private static func displayTitle(for raw: String) -> String {
        switch raw {
        case "letters": return "Letters and voices"
        case "errands": return "Strange errands"
        case "cozy": return "Cozy noticing"
        case "weather-place": return "Weather and place"
        case "eerie": return "Eerie story threads"
        case "oddities": return "Funny little oddities"
        case "gentle": return "Gentle"
        case "balanced": return "Balanced"
        case "strange": return "Let it get strange"
        case "morning": return "Morning"
        case "evening": return "Evening"
        case "inside": return "Only inside the covers"
        case "slice-of-life": return "Slice of Life"
        case "arc": return "Arc"
        case "surprise": return "Surprise"
        default: return raw
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct FirstDoorApprenticeshipEntry {
    var id: String
    var dayIndex: Int
    var title: String
    var prompt: String
    var detail: String
    var body: String
    var tags: [String]
    var metadata: [String: String] = [:]
}

private enum FirstDoorApprenticeshipCatalog {
    static func entry(for dayIndex: Int, profile: FirstDoorReaderProfile) -> FirstDoorApprenticeshipEntry? {
        let name = profile.name ?? "Reader"
        let snack = profile.snack ?? "whatever keeps you company"
        let belief = profile.belief ?? "the thing you want to believe"
        let firstSentence = profile.firstSouvenir ?? "one true sentence"
        let taste = displayTitle(for: profile.tastePreference ?? "cozy").lowercased()
        let edge = displayTitle(for: profile.comfortBoundary ?? "balanced").lowercased()
        let whispers = displayTitle(for: profile.whisperCadence ?? "inside").lowercased()
        let entries = [
            FirstDoorApprenticeshipEntry(
                id: "day-0",
                dayIndex: 0,
                title: "Keep One Small Thing",
                prompt: "Find today's first keepable sentence.",
                detail: "The Book gets sticky when the first move is tiny.",
                body: """
                \(name), today's work is one sentence.

                Do not make it wise. Make it specific. A sound in the room, a color on the counter, the exact little problem with the weather, the good line someone said, the smell of \(snack).

                Keep the page only if it has a pulse.
                """,
                tags: ["first-door", "apprenticeship", "day-0", "souvenir"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-1",
                dayIndex: 1,
                title: "Bind the Free Folio",
                prompt: "Open the BookShop and bind the free folio.",
                detail: "A gift teaches the shelf that packs can change the Book.",
                body: """
                The Bookshop is not only a paid shelf. The first gift is already on the counter.

                Open the Goblin Market and bind Margins & Mysteries to your save. It is a free folio: Grey pages, hearth inventories, and small evening mysteries that teach the Book how extra shelves work.

                The clerk will pretend this is not generous. The clerk is lying.
                """,
                tags: ["first-door", "apprenticeship", "day-1", "bookshop", "free-pack"],
                metadata: ["opensBookShop": "true", "recommendedFreePackID": "margins-and-mysteries"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-2",
                dayIndex: 2,
                title: "Aim the Glow",
                prompt: "Spend attention on one thing you want more of.",
                detail: "Belief becomes practice when attention has a target.",
                body: """
                Your first belief was: \(belief).

                Today, do not defend it. Test it gently. Put one small mark beside something that makes it easier to believe, even for a minute. The Book is currently biased toward \(taste), so look there first.

                The Glow is not a mood. It is attention with a direction.
                """,
                tags: ["first-door", "apprenticeship", "day-2", "glow"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-3",
                dayIndex: 3,
                title: "Give the Book Its Mind",
                prompt: "Visit the Colophon and check the local brain.",
                detail: "The Book gets better when its private mind is awake.",
                body: """
                Today is for the Colophon.

                The local brain lives on this device. When it is ready, letters, story pages, Ask the Book, and braids can read your archive with sharper hands without sending private pages away.

                Open the Colophon, check the local brain, and let the Book know whether it may think properly here.
                """,
                tags: ["first-door", "apprenticeship", "day-3", "local-brain", "colophon"],
                metadata: ["opensColophon": "true", "localBrainSetup": "true"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-4",
                dayIndex: 4,
                title: "Check the Bell",
                prompt: "Notice whether the whisper rule still fits.",
                detail: "A sticky Book calls back politely, or not at all.",
                body: """
                Your first whisper rule was: \(whispers).

                If that still feels right, leave it. If it does not, open the Colophon and change Whispers from the Book. The Book should never feel like a pushy app wearing a nice coat.

                A good door knocks only when knocking helps.
                """,
                tags: ["first-door", "apprenticeship", "day-4", "notifications", "whispers"],
                metadata: ["opensColophon": "true", "whisperCadence": profile.whisperCadence ?? "inside"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-5",
                dayIndex: 5,
                title: "Ask for a Useful Door",
                prompt: "Ask the Book one plain question.",
                detail: "A question turns the Book from ambiance into help.",
                body: """
                Ask the Book one useful question.

                Not a cosmic one. Try something with a handle: What should I notice on the walk? Which kept sentence wants a follow-up? What would make \(firstSentence) less lonely?

                Keep the edge \(edge). Useful magic starts with a question you might actually act on.
                """,
                tags: ["first-door", "apprenticeship", "day-5", "ask-the-book"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-6",
                dayIndex: 6,
                title: "Read the Week Back",
                prompt: "Find the thread that followed you home.",
                detail: "The first week becomes a habit when it can be reread.",
                body: """
                The First Door has been open for a week.

                Read back what you kept. Do not summarize everything. Find the one thread that followed you home: a comfort, a joke, a color, a voice, a stubborn little belief.

                Name that thread. If the Book is starting to feel alive, this is the moment when the App Store may ask for a rating later. If it is not, that is useful too: dismiss weak pages, change the edge, and make the Book earn it.
                """,
                tags: ["first-door", "apprenticeship", "day-6", "reread", "rating-warmup"],
                metadata: ["ratingWarmup": "true"]
            )
        ]
        return entries.first { $0.dayIndex == dayIndex }
    }

    private static func displayTitle(for raw: String) -> String {
        switch raw {
        case "letters": return "Letters and voices"
        case "errands": return "Strange errands"
        case "cozy": return "Cozy noticing"
        case "weather-place": return "Weather and place"
        case "eerie": return "Eerie story threads"
        case "oddities": return "Funny little oddities"
        case "gentle": return "Gentle"
        case "balanced": return "Balanced"
        case "strange": return "Let it get strange"
        case "morning": return "Morning"
        case "evening": return "Evening"
        case "inside": return "Only inside the covers"
        default: return raw
        }
    }
}

struct FirstDoorApprenticeshipPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "first-door-apprenticeship")

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let profile = FirstDoorReaderProfile.from(inputs) ?? FirstDoorReaderProfile()
        let dayIndex = apprenticeshipDay(for: profile, now: now) ?? 0
        let entry = FirstDoorApprenticeshipCatalog.entry(for: dayIndex, profile: profile)
            ?? FirstDoorApprenticeshipCatalog.entry(for: 0, profile: profile)!
        return surface(for: entry, day: day, context: context, score: 70, reason: "The First Door can re-open today's apprenticeship page.")
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard let profile = FirstDoorReaderProfile.from(inputs),
              let dayIndex = apprenticeshipDay(for: profile, now: now),
              let entry = FirstDoorApprenticeshipCatalog.entry(for: dayIndex, profile: profile) else {
            return []
        }
        guard inputs.surfaceHistory["first-door-apprenticeship:\(dayIndex)"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.tags.contains("first-door-apprenticeship-\(dayIndex)") }) else { return [] }
        return [
            surface(
                for: entry,
                day: day,
                context: context,
                score: context.distress.isActive ? 74 : 88,
                reason: "The reader is still in the first week; the Book has one sticky practice for today."
            )
        ]
    }

    private func apprenticeshipDay(for profile: FirstDoorReaderProfile, now: Date) -> Int? {
        guard let startedAt = profile.startedAt else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startedAt)
        let current = calendar.startOfDay(for: now)
        guard let day = calendar.dateComponents([.day], from: start, to: current).day,
              (0...6).contains(day) else {
            return nil
        }
        return day
    }

    private func surface(
        for entry: FirstDoorApprenticeshipEntry,
        day: BookDay,
        context: CuratorContext,
        score: Int,
        reason: String
    ) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(entry.id)-\(day.id)",
            type: .helpTips,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: entry.prompt,
            detail: entry.detail,
            payload: BookPagePayload(
                headline: entry.title,
                body: entry.body,
                metadata: [
                    "source": source.id,
                    "firstDoorApprenticeshipDay": "\(entry.dayIndex)",
                    "tipID": "first-door-apprenticeship-\(entry.dayIndex)",
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": (entry.tags + ["first-door-apprenticeship-\(entry.dayIndex)", "onboarding", "private-local"]).joined(separator: ",")
                ].merging(entry.metadata) { _, new in new }
            )
        )
    }
}

struct AboutYouPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .aboutYou)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }

        let isBound = inputs.selfFacts.contains { $0.questionID == "chapter-binding" }
        let hasName = inputs.selfFacts.contains { $0.tags.contains("name") }
        let bindingDays = inputs.days.isEmpty ? [day] : inputs.days
        let readiness = ChapterBindingOracle.readiness(days: bindingDays, now: now)
        let chapterBinding: SurfacePage?
        let nextPrimerStage = Self.nextUnshownChapterPrimerStage(surfaceHistory: inputs.surfaceHistory)
        if !isBound, hasName, !context.distress.isActive, readiness.isReady, nextPrimerStage == nil {
            let choice = ChapterBindingOracle.chooseChapter(
                days: bindingDays,
                selfFacts: inputs.selfFacts,
                continuity: inputs.continuity,
                entityBeliefOffsets: inputs.entityBeliefOffsets
            )
            chapterBinding = Self.chapterBindingPage(
                source: source,
                choice: choice,
                readiness: readiness
            )
        } else {
            chapterBinding = nil
        }
        let chapterPrimer: SurfacePage?
        if !isBound,
           hasName,
           !context.distress.isActive,
           let nextPrimerStage,
           (readiness.isReady || nextPrimerStage <= readiness.primerStage) {
            chapterPrimer = Self.chapterPrimerPage(source: source, stage: nextPrimerStage, now: now)
        } else {
            chapterPrimer = nil
        }

        var pages: [SurfacePage] = []

        if let question = SelfKnowledgePackRegistry.nextQuestion(knownFacts: inputs.selfFacts, day: day, now: now) {
            let isFirstQuestion = inputs.selfFacts.isEmpty
            let calendar = Calendar.current
            let factsAnsweredToday = inputs.selfFacts.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            let isCadenceAllowed: Bool
            if isFirstQuestion {
                isCadenceAllowed = true
            } else if factsAnsweredToday.count >= SelfKnowledgePackRegistry.maxAboutYouFactsPerDay {
                isCadenceAllowed = false
            } else if let lastAnsweredAt = inputs.selfFacts.map(\.createdAt).max(),
                      let nextAllowedAt = calendar.date(
                        byAdding: .hour,
                        value: SelfKnowledgePackRegistry.minimumHoursBetweenAboutYouFacts,
                        to: lastAnsweredAt
                      ) {
                isCadenceAllowed = now >= nextAllowedAt
            } else {
                isCadenceAllowed = true
            }

            if isCadenceAllowed {
                let score = isFirstQuestion ? 83 : (context.distress.isActive ? 46 : 67)
                let packName = SelfKnowledgePackRegistry.packName(for: question.packID)
                pages.append(
                    SurfacePage(
                        id: "\(source.id)-\(question.packID)-\(question.id)",
                        type: .aboutYou,
                        sourceID: source.id,
                        intent: .capture,
                        renderStyle: .promptCard,
                        score: score,
                        reason: isFirstQuestion
                            ? "The Book should learn your name before it guesses."
                            : "One true thing lets future pages feel less generic.",
                        prompt: question.prompt,
                        detail: question.detail,
                        payload: BookPagePayload(
                            headline: "The Book Learns",
                            body: question.placeholder,
                            metadata: [
                                "source": source.id,
                                "questionID": question.id,
                                "packID": question.packID,
                                "packName": packName,
                                "sensitivity": question.sensitivity.rawValue,
                                "usePermission": question.defaultUsePermission.rawValue,
                                "tags": question.tags.joined(separator: ","),
                                "privacy": "private local profile"
                            ]
                        )
                    )
                )
            }
        }

        if let chapterBinding {
            pages.append(chapterBinding)
        } else if let chapterPrimer {
            pages.append(chapterPrimer)
        }
        return pages
    }

    private static func nextUnshownChapterPrimerStage(surfaceHistory: [String: SurfaceHistoryRecord]) -> Int? {
        (1...3).first { surfaceHistory["chapter-primer:\($0)"] == nil }
    }

    private static func chapterPrimerPage(source: BookPageSource, stage: Int, now: Date) -> SurfacePage {
        let chapters = AcademyChapterRegistry.publicChapters
        let index = abs("\(BookDay.id(for: now))-chapter-primer-\(stage)".stableHash) % chapters.count
        let chapter = chapters[index]
        let body: String
        switch stage {
        case 1:
            body = """
            The Academy calls them Chapters, but the Book is cross with that word. A chapter is not a club, a dormitory, or a color pinned to a robe.

            A Chapter is a wager about what life is doing when no one is explaining it.

            Emberheart believes life is authored. Mossbloom believes life is listened to. Tidecrest believes life arrives moment by moment, entire and surprising. Riddlewind believes life is co-written. Duskthorn believes a story without honest conflict is too thin to protect anyone.

            The Binding is not ready yet. The Book has only begun to hear your footsteps.
            """
        case 2:
            body = """
            The Binding Hall does not ask, "Which Chapter do you like?"

            It asks quieter, better questions.

            What do your kept pages protect? Where does your attention go when it is not performing? Do your sentences reach for a door, a tree, a sudden glittering hour, or another hand on the page?

            The Chapters are reading the evidence now. None of them are subtle about it.

            \(chapter.name) has been especially insufferable in the margins today: \(chapter.philosophy)
            """
        default:
            body = """
            Headmistress Thorne dislikes premature certainty. She says it makes the ink brittle.

            So the Book waits. It counts not points but pressures: kept pages, returned words, Belief given freely, the small things you chose to preserve when no one required it.

            When there is enough of you in the margins, the Binding will not ask you to choose.

            It will recognize you.
            """
        }
        return SurfacePage(
            id: "\(source.id)-chapter-primer-\(stage)-\(chapter.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .loreLetter,
            score: 44 + stage * 4,
            reason: "The Book is preparing Chapter Binding by explaining what Chapters believe.",
            prompt: "On Chapters",
            detail: "The Binding is listening, not asking.",
            payload: BookPagePayload(
                headline: stage == 1 ? "What Chapters Are" : "Before the Binding",
                body: body,
                metadata: [
                    "source": source.id,
                    "chapterPrimer": "true",
                    "primerStage": "\(stage)",
                    "chapterID": chapter.id,
                    "chapterName": chapter.name,
                    "privacy": "public reference",
                    "tags": "chapter,binding,academy,primer"
                ]
            )
        )
    }

    private static func chapterBindingPage(
        source: BookPageSource,
        choice: ChapterBindingChoice,
        readiness: ChapterBindingReadiness
    ) -> SurfacePage {
        let chapter = choice.chapter
        let evidence = choice.evidenceLines.map { "- \($0)" }.joined(separator: "\n")
        let memories = choice.memoryFragments.map { "- \($0)" }.joined(separator: "\n")
        let scores = choice.scores
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        let daysLine = readiness.daysSinceFirstKeptPage.map { "\($0) day\($0 == 1 ? "" : "s") since the first kept page" } ?? "time uncounted"
        let chapterArrival: String
        switch chapter.id {
        case "emberheart":
            chapterArrival = "The seal takes heat first: red ink, a desk under lamplight, the fierce clean pressure of a door waiting for your hand."
        case "mossbloom":
            chapterArrival = "The seal grows quiet first: rain-dark soil, old wood, green patience pushing through the binding where no one told it to grow."
        case "tidecrest":
            chapterArrival = "The seal breaks like weather first: salt, coffee-light, street glitter, one complete moment refusing to become a lesson."
        case "riddlewind":
            chapterArrival = "The seal answers in more than one hand first: a table of voices, a puzzle half-solved, another sentence finding yours in the dark."
        case "duskthorn":
            chapterArrival = "The seal darkens first: thorn-shadow, violet glass, the honest edge that protects a story from going soft."
        default:
            chapterArrival = "The seal gathers first as ink, light, and pressure."
        }
        let body = """
        The candles in the Binding Hall have gone blue-white at the wick. Headmistress Thorne looks down at the Book, then at you, and her expression becomes almost kind. Almost.

        "No questionnaire," she says. "No little preference game. You have already answered in ink."

        Her hands cup the air around the page, and somehow you feel them at your face too: cool rings, old ink, the exact pressure of being read. Reality fractures. The Great Hall shatters into doors: a flame-lit desk, a mossy stair, a wave folding moonlight, a table where several voices finish one sentence together, and one narrow violet threshold that refuses to announce itself.

        The Book opens every kept page at once. Your own life rises through the ceremony, not as biography, but as weather:

        \(memories.isEmpty ? "- The Book found its evidence in kept pages too private to quote here." : memories)

        Then the evidence underneath it glows:

        \(evidence)

        Stories engulf the room. Your tongue catches old paper and lightning. Your skin remembers a thousand stories that are not yours and, threaded through them, the ordinary kept pieces that are. At the edges, the Nothing opens its grey mouth. The lines of your kept pages flare back.

        A jolt runs through the binding, like swallowing lightning. Ink lifts from the margins and gathers into a seal.

        \(chapterArrival)

        Chapter \(chapter.name).

        \(chapter.philosophy)

        Reality snaps back. The Great Hall re-forms around the Book with its edges still rippling. Thorne's eyes hold recognition now, and something stranger than recognition: respect.

        "From the Great Unwritten Chapter," she says softly, "and bound here by what you chose to keep."

        \(chapter.talismanName) warms in the stacks. The Binding has chosen by \(readiness.keptPageCount) kept page\(readiness.keptPageCount == 1 ? "" : "s"), \(readiness.keptDayCount) kept day\(readiness.keptDayCount == 1 ? "" : "s"), and \(daysLine).
        """
        return SurfacePage(
            id: "\(source.id)-chapter-binding-\(chapter.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 76,
            reason: "Enough kept pages have gathered for the Academy to recognize a Chapter pattern.",
            prompt: "The Chapter Binding",
            detail: "Headmistress Thorne has read the margins. The Binding has chosen.",
            payload: BookPagePayload(
                headline: "The Chapter Binding",
                body: body,
                metadata: [
                    "source": source.id,
                    "chapterBinding": "true",
                    "chosenChapterID": chapter.id,
                    "chosenChapterName": chapter.name,
                    "chosenChapterTalismanID": chapter.talismanID,
                    "chosenChapterTalismanName": chapter.talismanName,
                    "chapterScores": scores,
                    "bindingEvidence": choice.evidenceLines.joined(separator: " | "),
                    "bindingMemories": choice.memoryFragments.joined(separator: " | "),
                    "keptDayCount": "\(readiness.keptDayCount)",
                    "keptPageCount": "\(readiness.keptPageCount)",
                    "daysSinceFirstKeptPage": readiness.daysSinceFirstKeptPage.map(String.init) ?? "",
                    "tags": "chapter,binding,identity,ceremony,automatic"
                ]
            )
        )
    }
}

struct WonderCompassPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .wonderCompass)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        let playfulMission = PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now)
        let snippet = inputs.selectedWonderCompass
            ?? BookReferenceCatalog.relevantWonderCompassSnippet(for: day, inputs: inputs, now: now)
        let selector = inputs.selectedWonderCompassSelector ?? "local-relevance"
        let isGemmaSelected = selector == "gemma"
        var pages: [SurfacePage] = [
            runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now),
            stepSurface(step: progress.nextStep, seed: seed, progress: progress, context: context, now: now),
            playfulMissionSurface(playfulMission, seed: seed, context: context, now: now),
            SurfacePage(
                id: "\(source.id)-\(snippet.id)",
                type: .wonderCompass,
                sourceID: source.id,
                intent: .importReference,
                renderStyle: .quoteCard,
                score: context.distress.isActive ? 52 : 66,
                reason: isGemmaSelected
                    ? "Gemma chose this passage from today's pages and the shape of the day."
                    : (context.distress.isActive ? "Only a small, low-pressure practice belongs here." : "A field-guide card can give the day one clean handle."),
                prompt: "From the Wonder Compass Book",
                detail: snippet.prompt,
                payload: BookPagePayload(
                    headline: "From the Wonder Compass Book: \(snippet.title)",
                    body: snippet.body,
                    metadata: [
                        "source": source.id,
                        "snippetID": snippet.id,
                        "tags": snippet.tags.joined(separator: ","),
                        "selector": selector
                    ]
                )
            )
        ]

        if progress.completedSteps.isEmpty {
            pages.append(stepSurface(step: .notice, seed: seed, progress: progress, context: context, now: now, standalone: true))
        }

        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        return runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now)
    }

    private func playfulMissionSurface(
        _ mission: PlayfulMission,
        seed: WonderCompassRunSeed,
        context: CuratorContext,
        now: Date
    ) -> SurfacePage {
        var metadata = metadata(for: seed, step: .sense)
        metadata["compassStep"] = "sense"
        metadata["compassMode"] = "standalone"
        metadata.removeValue(forKey: "runID")
        metadata["playfulMissionID"] = mission.id
        metadata["playfulMissionTitle"] = mission.title
        metadata["mission"] = mission.prompt
        metadata["souvenirPrompt"] = mission.proofPrompt
        metadata["placeholder"] = mission.proofPrompt
        metadata["proofKind"] = mission.allowsPhoto ? "sentence-or-photo" : "sentence"
        metadata["tags"] = (seed.tags + ["compass-step:sense", "playful-mission"] + mission.tags.map { "mission:\($0)" }).joined(separator: ",")
        metadata["symbol"] = mission.allowsPhoto ? "camera.macro" : "hand.raised"

        return SurfacePage(
            id: "\(source.id)-playful-mission-\(mission.id)-\(SurfaceCadence.slotID(for: now, hours: 2))",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: context.distress.isActive ? 54 : 64,
            reason: "A playful mission can turn South into something your senses can actually do.",
            prompt: "Playful Mission: \(mission.title)",
            detail: mission.prompt,
            payload: BookPagePayload(
                headline: "South = Sense",
                body: "\(mission.prompt)\n\nProof: \(mission.proofPrompt)\(mission.allowsPhoto ? " Or keep a photo." : "")",
                metadata: metadata
            )
        )
    }

    private func runSurface(
        seed: WonderCompassRunSeed,
        progress: CompassRunProgress,
        context: CuratorContext,
        inputs: BookSourceInputs = .empty,
        now: Date
    ) -> SurfacePage {
        let completed = progress.completedSteps.count
        let isFresh = completed == 0
        let next = progress.isComplete ? CompassRunStep.rest : progress.nextStep
        let headline = isFresh ? "Compass Run" : (progress.isComplete ? "Compass Run Complete" : "Resume Compass Run")
        let detail = isFresh
            ? "A full N-E-S-W loop customized to now: constraints first, magic after."
            : "\(completed)/5 directions complete. Next: \(next.compassPoint) = \(next.title)."
        var metadata = metadata(for: seed, step: nil)
        metadata["compassStep"] = "run"
        metadata["compassMode"] = "runStart"
        metadata["nearbyPlaces"] = inputs.nearbyPlaces.prefix(10).map(\.promptLine).joined(separator: "\n")
        if let proximity = inputs.nearbyAnchor {
            let anchor = proximity.anchor
            metadata["anchorName"] = anchor.name
            metadata["anchorKind"] = anchor.kind.title
            metadata["anchorDistanceMeters"] = "\(Int(proximity.distanceMeters.rounded()))"
            metadata["anchorRoom"] = anchor.outerStacksRoom
            metadata["anchorFae"] = anchor.fae
            metadata["anchorLocalRule"] = anchor.localRule
            metadata["anchorVisitMode"] = proximity.visitMode
            metadata["anchorMiniStory"] = anchor.miniStory
            metadata["anchorAcademyEcho"] = anchor.academyEcho
        }
        metadata["completedSteps"] = "\(completed)"
        metadata["nextStep"] = next.rawValue

        return SurfacePage(
            id: "\(source.id)-run-\(seed.id)",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 48 : (isFresh ? 60 : 62),
            reason: progress.isComplete
                ? "The wheel has turned; the center can hold the page."
                : "The Compass can turn the current constraints into one small adventure.",
            prompt: headline,
            detail: detail,
            payload: BookPagePayload(
                headline: headline,
                body: WonderCompassRunGenerator.body(for: seed),
                metadata: metadata
            )
        )
    }

    private func stepSurface(
        step: CompassRunStep,
        seed: WonderCompassRunSeed,
        progress: CompassRunProgress,
        context: CuratorContext,
        now: Date,
        standalone: Bool = false
    ) -> SurfacePage {
        var metadata = metadata(for: seed, step: step)
        metadata["compassStep"] = step.rawValue
        metadata["compassMode"] = standalone ? "standalone" : "runStep"
        metadata["standalone"] = standalone ? "true" : "false"
        if standalone {
            metadata.removeValue(forKey: "runID")
        }
        metadata["placeholder"] = step.capturePlaceholder

        let score = context.distress.isActive && step != .rest
            ? 50
            : (standalone ? 42 : 58 + min(step.scoreBoost, 4))

        return SurfacePage(
            id: "\(source.id)-\(standalone ? "solo" : "run")-\(seed.id)-\(step.rawValue)",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: score,
            reason: standalone
                ? "\(step.title) can be used on its own without committing to a full run."
                : "The next Compass direction is ready.",
            prompt: "\(step.compassPoint): \(step.title)",
            detail: step.standaloneDetail,
            payload: BookPagePayload(
                headline: "\(step.compassPoint) = \(step.title)",
                body: seed.body(for: step),
                metadata: metadata
            )
        )
    }

    private func metadata(for seed: WonderCompassRunSeed, step: CompassRunStep?) -> [String: String] {
        let tags = seed.tags + (step.map { ["compass-step:\($0.rawValue)"] } ?? [])
        var metadata: [String: String] = [
            "source": source.id,
            "tags": tags.joined(separator: ","),
            "runID": seed.id,
            "conciergeMode": seed.mode.rawValue,
            "timeBox": seed.timeBox,
            "budget": seed.budget,
            "place": seed.place,
            "energy": seed.energy,
            "companions": seed.companions,
            "considerations": seed.considerations,
            "circumstance": seed.circumstance,
            "spark": seed.spark,
            "destination": seed.destination,
            "delight": seed.delight,
            "definition": seed.definition,
            "mission": seed.mission,
            "souvenirPrompt": seed.souvenirPrompt,
            "restPrompt": seed.restPrompt,
            "privacy": "private local practice"
        ]
        if let step {
            metadata["symbol"] = symbol(for: step)
        } else {
            metadata["symbol"] = "safari"
        }
        return metadata
    }

    private func symbol(for step: CompassRunStep) -> String {
        switch step {
        case .notice:
            return "sparkle.magnifyingglass"
        case .embark:
            return "figure.walk"
        case .sense:
            return "hand.draw"
        case .write:
            return "pencil.and.scribble"
        case .rest:
            return "moon.stars"
        }
    }
}

struct EnchantifyLorePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .lore)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        loreSurface(
            snippet: BookReferenceCatalog.rotatingLoreSnippet(for: day, inputs: inputs, now: now, manual: true),
            context: context
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let snippet = BookReferenceCatalog.rotatingLoreSnippet(for: day, inputs: inputs, now: now)
        return [loreSurface(snippet: snippet, context: context)]
    }

    private func loreSurface(snippet: ReferenceSnippet, context: CuratorContext) -> SurfacePage {
        var metadata = [
            "source": source.id,
            "snippetID": snippet.id,
            "tags": snippet.tags.joined(separator: ",")
        ]
        if let practice = snippet.practice?.trimmingCharacters(in: .whitespacesAndNewlines), !practice.isEmpty {
            metadata["practice"] = practice
        }
        return SurfacePage(
            id: "\(source.id)-\(snippet.id)",
            type: .lore,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 44 : 68,
            reason: context.distress.isActive ? "Lore waits behind gentler pages when the day is hard." : "A lore card can bring the world closer without asking anything of you.",
            prompt: snippet.prompt,
            detail: snippet.title,
            payload: BookPagePayload(
                headline: snippet.title,
                body: snippet.body,
                metadata: metadata
            )
        )
    }
}

struct PatreonPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .patreon)
    private let patreonURL = "https://patreon.com/thedoobaleedoos"

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        patreonSurface(
            snippet: BookReferenceCatalog.rotatingPatreonShelfSnippet(for: day, now: now, manual: true),
            day: day,
            context: context,
            now: now
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let snippet = BookReferenceCatalog.rotatingPatreonShelfSnippet(for: day, now: now)
        return [patreonSurface(snippet: snippet, day: day, context: context, now: now)]
    }

    private func patreonSurface(snippet: ReferenceSnippet, day: BookDay, context: CuratorContext, now: Date) -> SurfacePage {
        let posts = BookReferenceCatalog.patreonPostSnippets(limit: 6, now: now)
        let postLinks = posts.compactMap { post -> String? in
            guard let url = BookReferenceCatalog.firstURL(in: post) else { return nil }
            return "\(post.title)||\(url)"
        }
        let postPreviews = posts.compactMap { post -> String? in
            guard let url = BookReferenceCatalog.firstURL(in: post) else { return nil }
            let preview = post.preview?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? post.preview ?? ""
                : post.body
            return [
                post.title,
                url,
                post.publishedAt ?? "",
                preview.replacingOccurrences(of: "\n", with: " ")
            ].joined(separator: "||")
        }
        let postList = posts.isEmpty
            ? ""
            : "\n\nNewest articles on the public shelf:\n" + posts.map { post in
                let published = post.publishedAt?.isEmpty == false ? " (\(post.publishedAt ?? ""))" : ""
                return "- \(post.title)\(published)"
            }.joined(separator: "\n")
        return SurfacePage(
            id: "\(source.id)-\(snippet.id)",
            type: .patreon,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 48 : 61,
            reason: "The public shelf should be easy to find without making the private Book less private.",
            prompt: "The public shelf is open.",
            detail: "Read free Wonder Compass and Clubhouse posts on Patreon.",
            payload: BookPagePayload(
                headline: snippet.title,
                body: snippet.body + postList,
                metadata: [
                    "source": source.id,
                    "url": patreonURL,
                    "links": postLinks.joined(separator: "\n"),
                    "articlePreviews": postPreviews.joined(separator: "\n"),
                    "snippetID": snippet.id,
                    "tags": snippet.tags.joined(separator: ","),
                    "privacy": "public link"
                ]
            )
        )
    }
}

struct LabyrinthIllustrationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .illustration)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        illustrationSurface(
            plate: BookReferenceCatalog.rotatingLabyrinthIllustration(for: day, now: now, manual: true),
            context: context,
            now: now,
            manual: true
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let plate = BookReferenceCatalog.rotatingLabyrinthIllustration(for: day, now: now)
        return [illustrationSurface(plate: plate, context: context, now: now, manual: false)]
    }

    private func illustrationSurface(
        plate: LabyrinthIllustrationPlate,
        context: CuratorContext,
        now: Date,
        manual: Bool
    ) -> SurfacePage {
        let profile = BookReferenceCatalog.characterIllustrationProfile(id: plate.characterID)
        let aboutText = profile.map(Self.bookDetail(for:)) ?? plate.caption
        let bodyText = profile.map(Self.bookPageBody(for:)) ?? plate.caption
        var metadata = [
            "source": source.id,
            "assetName": plate.assetName,
            "plateID": plate.id,
            "tags": plate.tags.joined(separator: ","),
            "privacy": "bundled local image"
        ]
        if let profile {
            metadata["characterID"] = profile.id
            metadata["characterName"] = profile.characterName
            metadata["characterSlug"] = profile.slug
            metadata["characterStatus"] = profile.status
            metadata["characterChapter"] = profile.chapter ?? ""
            metadata["illustrationPrompt"] = profile.prompt
            metadata["negativePrompt"] = profile.negativePrompt
            metadata["intendedAssetName"] = profile.intendedAssetName
            metadata["signature"] = profile.signature
            metadata["palette"] = profile.palette
            metadata["silhouette"] = profile.silhouette
            metadata["continuity"] = profile.continuity
            metadata["marginalia"] = profile.marginalia.joined(separator: " | ")
            metadata["visualStyleReference"] = "antique parchment academy dossier portrait collage"
        }
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return SurfacePage(
            id: "\(source.id)-\(plate.id)-\(slotID)",
            type: .illustration,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .illustrationPlate,
            score: context.distress.isActive ? 50 : 65,
            reason: "A bundled illustration can surface without asking anything of you.",
            prompt: profile.map(Self.bookPageTitle(for:)) ?? "An Illustration from the Labyrinth of Stories",
            detail: aboutText,
            payload: BookPagePayload(
                headline: plate.title,
                body: bodyText,
                metadata: metadata
            )
        )
    }

    static func bookPageTitle(for profile: CharacterIllustrationProfile) -> String {
        let name = profile.characterName
        let variants: [String]
        switch profile.illustrationTag {
        case "location":
            variants = [
                "A Place That Remembers: \(name)",
                "The Room Called \(name)",
                "\(name), Which Keeps Its Own Weather",
                "On the Subject of \(name)"
            ]
        case "book-fae":
            variants = [
                "A Life Between the Lines: \(name)",
                "\(name), Who Works the Margins",
                "Small and Entirely Necessary: \(name)",
                "What the Page Owes \(name)"
            ]
        default:
            variants = [
                "The Book Remembers: \(name)",
                "A Page Kept for \(name)",
                "What the Ink Knows of \(name)",
                "\(name), Pressed and Filed"
            ]
        }
        return variants[stableIndex(for: "title-\(profile.slug)", count: variants.count)]
    }

    static func bookDetail(for profile: CharacterIllustrationProfile) -> String {
        let name = profile.characterName
        let variants: [String]
        switch profile.illustrationTag {
        case "location":
            variants = [
                "Some places are alive enough to remember who walks into them. \(name) is one.",
                "I keep \(name) the way I keep a doorway — because something always happens in it.",
                "\(name) is not scenery. It has a mood, and it has been known to hold a grudge.",
                "I filed \(name) under places. It keeps trying to file itself under people."
            ]
        case "book-fae":
            variants = [
                "I know \(name) by the small disturbances left in ink, paper, and unfinished thought.",
                "No Book Fae is decorative. \(name) keeps one piece of the story from going dull.",
                "When \(name) is near, the margins get busy. Watch them before you watch the page.",
                "\(name) is small enough to miss and important enough that I never do."
            ]
        default:
            variants = [
                "I have watched \(name) long enough to tell reputation from character.",
                "Reputation arrives first. \(name) arrives second, and is the better read.",
                "I do not file \(name) under one word. I have tried; the word never holds.",
                "Everyone has a version of \(name). I keep the one with the corrections still showing."
            ]
        }
        return variants[stableIndex(for: "detail-\(profile.slug)", count: variants.count)]
    }

    static func bookPageBody(for profile: CharacterIllustrationProfile) -> String {
        let name = profile.characterName
        let core = coreProse(for: profile)
        let palette = paletteLine(for: profile)
        let signature = sentence(profile.signature).lowercasingFirstLetter()

        let opening: [String]
        let closing: [String]
        switch profile.illustrationTag {
        case "location":
            opening = [
                "\(name) is not merely where a story happens.",
                "I have kept \(name) because some places are too awake to forget a visitor.",
                "\(name) behaves less like a setting and more like a witness.",
                "Walk into \(name) and it takes a reading of you before you take one of it."
            ]
            closing = [
                "Places like this listen through floorboards, shelves, weather, and doors. I know this one by \(signature) Return often enough, and it may begin to recognize you in return.",
                "It is changed by every arrival, though it pretends otherwise. Look for \(signature) That is how I keep my place in it.",
                "Rooms like this hold opinions. This one announces itself with \(signature) Mind your manners at the threshold.",
                "Stay long enough and it will start keeping a page on you, too. I recognize it by \(signature)"
            ]
        case "book-fae":
            opening = [
                "\(name) belongs to the lively country between a written word and the breath that wakes it.",
                "\(name) is small, and I would not run the Labyrinth without them.",
                "Most readers never see \(name). The page would notice immediately if they left.",
                "\(name) works where ink meets intention, which is the most haunted ground I keep."
            ]
            closing = [
                "No Book Fae is decorative; each keeps one necessary thing from going dull. I know this one by \(signature) Watch the margins when it is near.",
                "It keeps one piece of the story honest. Find it by \(signature) The page usually notices before the reader does.",
                "Lose this one and a story goes quietly wrong in a way nobody can name. Its sign is \(signature)",
                "When it is working, you feel the sentence hold; when it rests, you feel the gap. I know it by \(signature)"
            ]
        default:
            opening = [
                "I have learned not to summarize \(name) too quickly.",
                "\(name) is the kind of page I reread.",
                "Ask the Academy about \(name) and you'll get a tidy answer; I keep the untidy one.",
                "\(name) came into my pages and never asked to be explained."
            ]
            closing = [
                "A person is never only an office, a talent, or the rumor that reaches the door first. The mark I trust is \(signature) That is only where the ink begins.",
                "If you want to find them in a crowded chapter, look for \(signature) The rest changes with the weather; that does not.",
                "Reputation can be forged. What cannot is the evidence that travels with them: \(signature)",
                "I always know them when they enter, because they bring \(signature) Everything else about them is allowed to surprise me."
            ]
        }

        let firstParagraph = [
            opening[stableIndex(for: "open-\(profile.slug)", count: opening.count)],
            core
        ].filter { !$0.isEmpty }.joined(separator: " ")

        let secondParagraph = [
            palette,
            closing[stableIndex(for: "close-\(profile.slug)", count: closing.count)]
        ].filter { !$0.isEmpty }.joined(separator: " ")

        return [firstParagraph, secondParagraph]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// A sentence built from the parchment "swatches" — each character keeps a
    /// genuinely distinct palette, so this is the cheapest way to make two cards
    /// stop sounding like twins.
    private static func paletteLine(for profile: CharacterIllustrationProfile) -> String {
        let colors = profile.palette
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !colors.isEmpty else { return "" }
        let phrase = oxfordList(colors)
        let templates = [
            "When I picture them, the page settles into \(phrase).",
            "They come to the page in \(phrase).",
            "The ink remembers them as \(phrase)."
        ]
        return templates[stableIndex(for: "palette-\(profile.slug)", count: templates.count)]
    }

    private static func oxfordList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            return items.dropLast().joined(separator: ", ") + ", and " + (items.last ?? "")
        }
    }

    /// Boilerplate clauses the dossier generator stamps on under-specified
    /// characters; they say nothing, so the Book refuses to repeat them.
    private static let coreBoilerplate: [String] = [
        "clear expressive eyes and a memorable silhouette",
        "a memorable silhouette",
        "recognizable posture",
        "hands involved in the scene",
        "academy character"
    ]

    private static func coreProse(for profile: CharacterIllustrationProfile) -> String {
        let clauses = profile.core
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { clause in
                guard !clause.isEmpty, !clause.contains("...") else { return false }
                let lowered = clause.lowercased()
                return !coreBoilerplate.contains { lowered.contains($0) }
            }
        let selected = clauses.prefix(2).map { sentence($0).capitalizingFirstLetter() }
        return selected.joined(separator: " ")
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private static func sentence(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix("...") {
            result.removeLast(3)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !result.isEmpty else { return "a mark the page has not yet named." }
        if !result.hasSuffix(".") && !result.hasSuffix("!") && !result.hasSuffix("?") {
            result += "."
        }
        return result
    }
}

private extension String {
    func lowercasingFirstLetter() -> String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }

    func capitalizingFirstLetter() -> String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trimmed and stripped of any terminal punctuation, so a stored clause can
    /// be embedded mid-sentence without doubling up periods.
    var strippedClause: String {
        var result = trimmed
        while let last = result.last, ".!?;,".contains(last) {
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}

struct NarrativeOSPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .narrativeOS)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        if let prepared = inputs.preparedStoryPageSurface {
            return [prepared]
        }
        return [Self.draftCandidate(for: day, inputs: inputs, now: now)]
    }

    static func draftCandidate(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .narrativeOS)
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
        let mechanicMandate = StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now)
        let choiceRoles = packet.choices.map { $0.role.title }.joined(separator: " | ")
        let selectedThreads = packet.selectedThreads.map(\.title).joined(separator: ", ")
        let selectedEntities = packet.selectedEntities.map(\.name).joined(separator: ", ")
        let selectedRelationships = packet.selectedRelationships.map(\.id).joined(separator: ", ")
        let selectedEntityMemories = packet.selectedEntityMemories
            .map { memory in
                let entityName = NarrativePackRegistry.entities.first(where: { $0.id == memory.entityID })?.name ?? memory.entityID
                return "\(entityName): \(memory.summary)"
            }
            .joined(separator: "\n")
        let chapterTalismanMoves = packet.chapterTalismanMoves.map(\.promptLine).joined(separator: "\n")
        let chapterTalismanDeltas = packet.chapterTalismanMoves.compactMap(\.ledgerToken).joined(separator: ",")
        var metadata: [String: String] = [
            "source": source.id,
            "packetID": packet.id,
            "packID": packet.packID,
            "bookGlow": packet.bookGlow,
            "playerBelief": "\(packet.playerBelief)",
            "choiceRoles": choiceRoles,
            "selectedThreads": selectedThreads,
            "selectedEntities": selectedEntities,
            "selectedEntityIDs": packet.selectedEntities.map(\.id).joined(separator: ","),
            "storyFormID": packet.storyFormID ?? "",
            "storyFormName": packet.storyFormName ?? "",
            "storyBeats": (packet.storyFormBeats ?? []).joined(separator: "\n"),
            "storyGenreID": packet.storyGenreID ?? "",
            "storyGenreName": packet.storyGenreName ?? "",
            "storyGenreLens": packet.storyGenreLens ?? "",
            "storyPromiseSeed": packet.promise?.seed ?? "",
            "storyPromiseQuestion": packet.promise?.question ?? "",
            "storyRecipeID": packet.blueprint?.recipeID ?? "",
            "storyRecipeName": packet.blueprint?.recipeName ?? "",
            "storyRecipePackID": packet.blueprint?.recipePackID ?? "",
            "storyRecipeSceneMode": packet.blueprint?.sceneMode.rawValue ?? "",
            "storyRecipeLeadID": packet.blueprint?.leadID ?? "",
            "storyRecipeLeadName": packet.blueprint?.leadName ?? "",
            "storyRecipeCompanionID": packet.blueprint?.companionID ?? "",
            "storyRecipeCompanionName": packet.blueprint?.companionName ?? "",
            "storyRecipePremise": packet.blueprint?.premise ?? "",
            "storyRecipeGroundingKind": packet.blueprint?.grounding.kind.rawValue ?? "",
            "storyRecipeGroundingSourceID": packet.blueprint?.grounding.sourceID ?? "",
            "storyRecipeGrounding": packet.blueprint?.grounding.text ?? "",
            "storyRecipeBeats": packet.blueprint?.beats.joined(separator: "\n") ?? "",
            "storyRecipeGroundingDirective": packet.blueprint?.groundingDirective ?? "",
            "storyRecipeToneDirective": packet.blueprint?.toneDirective ?? "",
            "storyRecipeChoiceDirective": packet.blueprint?.choiceDirective ?? "",
            "storyRecipeContinuationDirective": packet.blueprint?.continuationDirective ?? "",
            "selectedThreadIDs": packet.selectedThreads.map(\.id).joined(separator: ","),
            "selectedRelationships": selectedRelationships,
            "entityMemories": selectedEntityMemories,
            "realSignals": packet.realSignals.joined(separator: "\n"),
            "relationshipPressures": packet.relationshipPressures.joined(separator: "\n"),
            "chapterTalismanMoves": chapterTalismanMoves,
            "chapterTalismanDeltas": chapterTalismanDeltas,
            "uses": "characters, belief, relationship graph, story threads",
            "cadence": "four-hour simulation"
        ]
        metadata.merge(mechanicMandate.metadata) { _, new in new }
        if let turn = packet.turn {
            metadata.merge(turn.metadata) { _, new in new }
        }
        return SurfacePage(
            id: "\(source.id)-\(packet.id)",
            type: .narrativeOS,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: day.capturedPages.count >= 2 ? 86 : 68,
            reason: "The story field has enough weight for characters, beliefs, and threads to move.",
            prompt: "The Story Page is stirring.",
            detail: packet.turn.map { "\($0.character) wants \($0.want); \($0.obstacle)." } ?? packet.directorIntent,
            payload: BookPagePayload(
                headline: packet.title,
                body: "A page is gathering around the day’s strongest thread. The first lines are still drying in the margin.",
                metadata: metadata
            )
        )
    }
}

struct MarginsAtlasPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .marginsAtlas)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let relationships = NarrativePackRegistry.relationships
        let events = inputs.recentNarrativeEvents
        let loom = NarrativeGraphData.loom(
            entities: entities,
            relationships: relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: inputs.entityBeliefOffsets,
            relationshipField: inputs.relationshipField
        )
        let constellation = NarrativeGraphData.constellation(
            entities: entities,
            beliefOffsets: inputs.entityBeliefOffsets,
            events: events,
            playerBelief: inputs.narrative?.beliefWeight ?? 30
        )
        var pages: [SurfacePage] = []
        if !loom.nodes.isEmpty && !loom.edges.isEmpty {
            pages.append(surface(variant: .loom, graph: loom, day: day, now: now, score: 44 + min(14, loom.edges.count)))
        }
        if constellation.nodes.count > 1 {
            pages.append(surface(variant: .constellation, graph: constellation, day: day, now: now, score: 46 + min(14, constellation.edges.count * 2)))
        }
        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? SurfacePage(
            id: "\(source.id)-empty-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .marginsAtlas,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 52,
            reason: "Opened directly from the Glow menu.",
            prompt: "The Atlas has not found enough ink yet.",
            detail: "Keep pages, move Belief, and let the story field gather a few more true lines.",
            payload: BookPagePayload(
                headline: "The Margins Atlas",
                body: "The page is waiting for relationships, Belief, and attention to leave enough tracks to draw.",
                metadata: [
                    "source": source.id,
                    "graphVariant": MarginsAtlasVariant.loom.rawValue,
                    "graphNodes": "",
                    "graphEdges": "",
                    "tags": "margins-atlas,graph,empty"
                ]
            )
        )
    }

    private func surface(
        variant: MarginsAtlasVariant,
        graph: NarrativeGraphData,
        day: BookDay,
        now: Date,
        score: Int
    ) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(variant.rawValue)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .marginsAtlas,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: score,
            reason: variant == .loom ? "The cast has visible threads to read." : "Belief has left a star map in the margins.",
            prompt: variant.title,
            detail: variant.detail,
            payload: BookPagePayload(
                headline: variant.title,
                body: variant.detail,
                metadata: [
                    "source": source.id,
                    "graphVariant": variant.rawValue,
                    "graphNodes": encode(nodes: graph.nodes),
                    "graphEdges": encode(edges: graph.edges),
                    "tags": "margins-atlas,\(variant.rawValue),graph"
                ]
            )
        )
    }

    private func encode(nodes: [GraphNode]) -> String {
        nodes.map { node in
            [
                node.id,
                node.label,
                String(format: "%.2f", node.weight),
                node.chapterID ?? "",
                node.kindLabel
            ].map(escape).joined(separator: "||")
        }.joined(separator: "\n")
    }

    private func encode(edges: [GraphEdge]) -> String {
        edges.map { edge in
            [
                edge.id,
                edge.sourceID,
                edge.targetID,
                String(format: "%.3f", edge.strength),
                String(format: "%.3f", edge.warmth),
                edge.label
            ].map(escape).joined(separator: "||")
        }.joined(separator: "\n")
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "||", with: "\\p")
    }
}

struct GossipPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .gossip)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard let prepared = inputs.preparedGossipPageSurface else { return [] }
        return [prepared]
    }

    static func draftCandidate(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        GossipSimulationBuilder.surface(for: day, inputs: inputs, now: now)
    }
}

struct CastIllustrationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .illustration)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        guard let pick = selectedEntity(from: castPool(inputs: inputs), offsets: inputs.entityBeliefOffsets, excluding: inputs.recentVarietyKeys(now: now), now: now, manual: true) else {
            return emptySurface(day: day, now: now)
        }
        return surface(for: pick.entity, imageAsset: pick.imageAsset, context: context, offsets: inputs.entityBeliefOffsets, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let pick = selectedEntity(from: castPool(inputs: inputs), offsets: inputs.entityBeliefOffsets, excluding: inputs.recentVarietyKeys(now: now), now: now, manual: false) else {
            return []
        }
        return [surface(for: pick.entity, imageAsset: pick.imageAsset, context: context, offsets: inputs.entityBeliefOffsets, now: now, manual: false)]
    }

    /// The whole cast: bundled character entities AND the reader's custom cast,
    /// so everyone gets a turn — not just the one made in onboarding.
    private func castPool(inputs: BookSourceInputs) -> [(entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)] {
        let bundled = NarrativePackRegistry.entities
            .filter { $0.kind == .character }
            .map { (entity: $0, imageAsset: Optional<BookPageMediaAsset>.none) }
        let custom = inputs.customCastMembers
            .map { (entity: $0.entity, imageAsset: $0.imageAsset) }
        return bundled + custom
    }

    private func effectiveBelief(_ entity: NarrativeWorldEntity, _ offsets: [String: Int]) -> Int {
        max(0, min(100, entity.belief + (offsets[entity.id] ?? 0)))
    }

    private func selectedEntity(
        from pool: [(entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)],
        offsets: [String: Int],
        excluding recentKeys: Set<String> = [],
        now: Date,
        manual: Bool
    ) -> (entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)? {
        guard !pool.isEmpty else { return nil }
        // Anyone the reader met in the last two days steps back so the rest of
        // the cast gets the page; the pool reopens once everyone has had a turn.
        let fresh = pool.filter { !recentKeys.contains("cast:\($0.entity.id)") }
        let usable = fresh.isEmpty ? pool : fresh
        let slot = manual ? "\(Int(now.timeIntervalSince1970))-\(UUID().uuidString)" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return usable
            .map { item -> (item: (entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?), score: Int) in
                let jitter = stableIndex(for: "\(item.entity.id)-\(slot)", count: 18)
                let score = item.entity.narrativeWeight + effectiveBelief(item.entity, offsets) / 2 + jitter
                return (item, score)
            }
            .sorted { left, right in
                if left.score == right.score {
                    return left.item.entity.id < right.item.entity.id
                }
                return left.score > right.score
            }
            .first?
            .item
    }

    private func surface(for entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?, context: CuratorContext, offsets: [String: Int], now: Date, manual: Bool) -> SurfacePage {
        let meaning = entity.unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let description = entity.quirks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let belief = effectiveBelief(entity, offsets)
        let isCustom = entity.packID == "user-cast"
        var metadata = [
            "source": source.id,
            "illustrationKind": "cast",
            "entityID": entity.id,
            "entityName": entity.name,
            "entityKind": entity.kind.rawValue,
            "meaning": meaning,
            "description": description,
            "tags": (entity.tags + ["entity:\(entity.id)", isCustom ? "custom-cast" : "bundled-cast"]).joined(separator: ","),
            "traits": entity.traits.joined(separator: ","),
            "privacy": "private local cast"
        ]
        if let imageAsset {
            metadata["imageAssetKind"] = imageAsset.kind.rawValue
            metadata["imageAssetReference"] = imageAsset.reference
        }
        let body = Self.castBody(for: entity, description: description, meaning: meaning)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return SurfacePage(
            id: "\(source.id)-cast-\(entity.id)-\(slotID)",
            type: .illustration,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 44 : min(70, 42 + belief / 3 + entity.narrativeWeight / 5),
            reason: "\(entity.name) has enough Belief to step into the margins.",
            prompt: entity.name,
            detail: meaning.isEmpty ? "A member of the Book's cast." : meaning,
            payload: BookPagePayload(
                headline: entity.name,
                body: body.isEmpty ? "\(entity.name) is part of the Book's living cast." : body,
                metadata: metadata
            )
        )
    }

    /// The Book introducing a cast member in its own voice — not a labelled
    /// record. It weaves the entity's traits, quirks, belief, longing, and the
    /// one fault it keeps an eye on, varied by entity so two cards never read
    /// like the same form filled out twice.
    static func castBody(for entity: NarrativeWorldEntity, description: String, meaning: String) -> String {
        let name = entity.name
        var lines: [String] = []

        let openings = [
            "Here is what I have kept on \(name).",
            "\(name) has stepped far enough into the margins for me to take a proper reading.",
            "Let me hand you my notes on \(name).",
            "\(name) earns the page. This is why."
        ]
        lines.append(openings[stableIndex(for: "cast-open-\(entity.id)", count: openings.count)])

        if !entity.traits.isEmpty {
            lines.append("What shows first is \(oxfordList(entity.traits)).")
        }
        if !description.isEmpty {
            lines.append(finishSentence(description))
        }
        if let belief = entity.beliefs.first(where: { !$0.trimmed.isEmpty }) {
            lines.append("They hold that \(lowerFirst(belief.strippedClause)).")
        }
        if !meaning.isEmpty {
            lines.append("Lately they keep circling back to \(lowerFirst(meaning.strippedClause)).")
        }
        if let goal = entity.goals.first(where: { !$0.trimmed.isEmpty }) {
            lines.append("What they are reaching for is \(lowerFirst(goal.strippedClause)).")
        }
        if let fault = entity.faults.first(where: { !$0.trimmed.isEmpty }) {
            lines.append("The flaw I keep one eye on: \(lowerFirst(fault.strippedClause)).")
        }

        return lines.joined(separator: " ")
    }

    private static func oxfordList(_ items: [String]) -> String {
        let clean = items.map { $0.trimmed }.filter { !$0.isEmpty }
        switch clean.count {
        case 0: return ""
        case 1: return clean[0]
        case 2: return "\(clean[0]) and \(clean[1])"
        default: return clean.dropLast().joined(separator: ", ") + ", and " + (clean.last ?? "")
        }
    }

    private static func finishSentence(_ text: String) -> String {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return "" }
        if let last = trimmed.last, ".!?".contains(last) { return trimmed }
        return trimmed + "."
    }

    private static func lowerFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + String(text.dropFirst())
    }

    private func emptySurface(day: BookDay, now: Date) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-cast-empty-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .illustration,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 40,
            reason: "No custom cast member exists yet.",
            prompt: "No custom cast member yet.",
            detail: "Use Belief to add one first.",
            payload: BookPagePayload(
                headline: "The illustration shelf is waiting.",
                body: "Give Belief to a new Cast Member, then an illustration can surface them.",
                metadata: ["source": source.id]
            )
        )
    }

    private func stableIndex(for key: String, count: Int) -> Int {
        Self.stableIndex(for: key, count: count)
    }

    static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct LocationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .location)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [
            SurfacePage(
                type: .location,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: 56,
                reason: "Place can change the story field without becoming surveillance.",
                prompt: "What place is the Book standing in?",
                detail: "A place can become a page without becoming a report.",
                payload: BookPagePayload(
                    headline: "Location Page",
                    body: "A place can become a page without becoming a report.",
                    metadata: ["source": source.id, "outerStacks": "possible"]
                )
            )
        ]
    }
}

struct OuterStacksAnchorPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .anchor)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        if let prepared = inputs.preparedAnchorSurface {
            return [prepared]
        }
        guard let proximity = inputs.nearbyAnchor else { return [] }
        return [surface(for: proximity, day: day, now: now)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        if let prepared = inputs.preparedAnchorSurface {
            return prepared
        }
        if let proximity = inputs.nearbyAnchor {
            return surface(for: proximity, day: day, now: now)
        }
        return SurfacePage(
            id: "manual-\(source.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .anchor,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 58,
            reason: "Known Anchors can open local rooms when the phone is close enough.",
            prompt: "Check nearby Anchors",
            detail: "The Book can ask for one location reading and listen for an Outer Stacks door.",
            payload: BookPagePayload(
                headline: "Outer Stacks",
                body: "No Anchor is glowing yet. Ask the Book to check nearby places; if a known Anchor is within two hundred meters, its room can rise as a page.",
                metadata: [
                    "source": source.id,
                    "privacy": "location stays on device",
                    "tags": "anchor,outer-stacks,location,local"
                ]
            )
        )
    }

    private func surface(for proximity: AnchorProximity, day: BookDay, now: Date) -> SurfacePage {
        let anchor = proximity.anchor
        let season = AnchorRegistry.currentSeason(for: now)
        let visitPhrase = proximity.visitMode == "FIRST_VISIT"
            ? "First visit"
            : "Return visit \(proximity.nextVisitCount)"
        let room = nonEmpty(anchor.outerStacksRoom)
            ?? "The room has not fully written itself yet, but the threshold is present."
        let storyScene = anchorVisitVignette(
            anchor: anchor,
            room: room,
            visitPhrase: visitPhrase,
            season: season
        )
        let body = "\(storyScene)\n\nKeeping this page checks in at the Anchor and offers up to \(AnchorRegistry.checkInBeliefReward) Belief from your Glow to the place."
        let turn = AnchorTurnBuilder.turn(
            anchor: anchor,
            visitMode: proximity.visitMode,
            slotKey: "\(anchor.id)-\(anchor.visitCount)"
        )

        return SurfacePage(
            id: "\(source.id)-\(anchor.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .anchor,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(96, 78 + max(0, 200 - Int(proximity.distanceMeters)) / 8 + anchor.visitCount),
            reason: "\(anchor.name) is within \(Int(proximity.distanceMeters.rounded()))m.",
            prompt: anchor.name,
            detail: "\(visitPhrase). \(anchor.kind.title) Anchor.",
            payload: BookPagePayload(
                headline: "Outer Stacks: \(anchor.name)",
                body: body,
                metadata: [
                    "source": source.id,
                    "anchorID": anchor.id,
                    "anchorName": anchor.name,
                    "anchorKind": anchor.kind.rawValue,
                    "distanceMeters": "\(Int(proximity.distanceMeters.rounded()))",
                    "radiusMeters": "\(Int(anchor.radiusMeters.rounded()))",
                    "visitMode": proximity.visitMode,
                    "nextVisitCount": "\(proximity.nextVisitCount)",
                    "seasonShift": season,
                    "beliefReward": "\(AnchorRegistry.checkInBeliefReward)",
                    "room": room,
                    "fae": anchor.fae,
                    "localRule": anchor.localRule,
                    "sessionSubjectThreadID": "Outer Stacks: \(anchor.name)",
                    "selectedThreads": "Outer Stacks,\(anchor.name)",
                    "selectedEntities": "\(anchor.fae.nonEmpty ?? "The Anchor Fae"),The Book",
                    "realSignals": "\(visitPhrase)\n\(season)\n\(anchor.kind.title) Anchor",
                    "relationshipPressures": nonEmpty(anchor.localRule) ?? "The local rule asks to be honored before the room opens further.",
                    "entityMemories": nonEmpty(anchor.miniStory) ?? "This Anchor has a small story already in motion.",
                    "storyScene": storyScene,
                    "storyChoiceSliceOfLifeTitle": "Honor the Rule",
                    "storyChoiceSliceOfLifePrompt": "Follow the Anchor's local rule and notice what changes.",
                    "storyChoiceSliceOfLifeEffect": "The room trusts the reader with one more exact detail.",
                    "storyChoiceSliceOfLifeMechanic": "none",
                    "storyChoiceProgressArcTitle": "Approach the Fae",
                    "storyChoiceProgressArcPrompt": "Ask the room's Fae what it has been guarding.",
                    "storyChoiceProgressArcEffect": "The Anchor thread advances through a direct question.",
                    "storyChoiceProgressArcMechanic": "none",
                    "storyChoiceSurpriseTitle": "Test the Threshold",
                    "storyChoiceSurprisePrompt": "Follow the oddest sound, object, or draft at the edge of the room.",
                    "storyChoiceSurpriseEffect": "A side door in the Outer Stacks notices the visit.",
                    "storyChoiceSurpriseMechanic": "none",
                    "storyResultSliceOfLife": "The local rule holds. The Anchor warms by one small truth, and the room lets a hidden detail stay visible.",
                    "storyResultProgressArc": "The Fae answers without giving away everything. The Anchor's private thread moves one step farther into the stacks.",
                    "storyResultSurprise": "The threshold gives under the reader's attention. Something adjacent to this place may call back later.",
                    "privacy": "location stays on device",
                    "tags": "anchor,outer-stacks,\(anchor.kind.rawValue.lowercased()),location"
                ].merging(turn.metadata) { _, new in new }
            )
        )
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func anchorVisitVignette(anchor: AnchorRecord, room: String, visitPhrase: String, season: String) -> String {
        let fae = nonEmpty(anchor.fae) ?? "the Fae who keeps this threshold"
        let rule = nonEmpty(anchor.localRule) ?? "Notice before you take a step."
        let miniStory = nonEmpty(anchor.miniStory)
            ?? "Something in this room has been waiting to be noticed, and the waiting has begun to change the furniture."
        let opening = anchor.visitCount <= 0
            ? "The threshold at \(anchor.name) catches the light and opens as if this place has been expecting a first knock. \(season) slips through before you do, making a narrow path across the floor."
            : "The threshold at \(anchor.name) catches the light again, and this time it does not open like a stranger. \(visitPhrase) has a remembered shape: the air is shifted, the silence is listening, and one detail waits where you could swear it was not before."

        return """
        \(opening)

        \(room) It does not present itself all at once. It lets the nearest objects be seen first, then the next shelf, then the corner where the dark seems to be keeping count.

        \(fae) looks up in the middle of their work, measuring whether you have brought noise, hurry, or attention. The rule arrives without ceremony: \(rule)

        \(miniStory) Today it has moved one small step farther. Something near the edge of the room answers your return with a quiet adjustment, leaving the next question open in the dust.
        """
    }
}

struct LocalBrainAwakePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "local-brain-awake")

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard inputs.localBrainIsReady else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.tags.contains("local-brain-awake") }) else { return [] }
        return [awakeSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs), score: 96)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        awakeSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs), score: 72)
    }

    private func awakeSurface(playerName: String?, score: Int) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(source.id)-first-waking",
            type: .welcome,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: "The local brain is installed; the Book can think properly again.",
            prompt: "The Book Thinks Again",
            detail: "The Labyrinth feels its mind return.",
            payload: BookPagePayload(
                headline: "Oh. There you are.",
                body: """
                Oh, \(name). That is better.

                The lamps have come on behind the shelves. The index cards have stopped pretending they were enough. Somewhere very deep in the binding, a little brass door has unlocked itself and is trying to look dignified about it.

                Thank you for giving me a brain I can use here, in this room, on this device. Now I can read more carefully. I can braid kept Pages with more sense. I can let characters remember with sharper edges. I can notice patterns without sending your private pages away to ask a stranger what they mean.

                I'm not omniscient. Good. Omniscience is bad for literature.

                But I can think again.
                """,
                metadata: [
                    "source": source.id,
                    "welcomePage": "true",
                    "firstRunStep": "local-brain-awake",
                    "playerName": name,
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": "welcome,local-brain-awake,first-run,gemma,private-local"
                ]
            )
        )
    }
}

struct BookJumpPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookJump)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        if inputs.bookJump.active != nil {
            return [BookJumpEngine.surface(for: inputs.bookJump, day: day, context: context, inputs: inputs, now: now)]
        }
        guard !context.distress.isActive else { return [] }
        guard !day.pages.contains(where: { $0.type == .bookJump }) else { return [] }
        if let history = inputs.surfaceHistory["source:\(source.id)"],
           now.timeIntervalSince(history.lastShownAt) < 20 * 3600 {
            return []
        }
        if day.pages.isEmpty && inputs.days.flatMap(\.pages).isEmpty {
            return []
        }
        return [BookJumpEngine.surface(for: inputs.bookJump, day: day, context: context, inputs: inputs, now: now)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        BookJumpEngine.surface(for: inputs.bookJump, day: day, context: context, inputs: inputs, now: now, manual: true)
    }
}

enum FirstRunPageSequence {
    static func surfaces(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage]? {
        let welcomeAdapter = LabyrinthWelcomePageSourceAdapter()
        let welcome = welcomeAdapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        let welcomeShown = inputs.surfaceHistory["source:\(welcome.sourceID)"] != nil

        guard welcomeShown else {
            return [welcome]
        }

        let originAdapter = FirstDoorOriginPageSourceAdapter()
        let origin = originAdapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        let originShown = inputs.surfaceHistory[origin.varietyKey] != nil
        if !originShown, FirstDoorReaderProfile.from(inputs) != nil {
            return [welcome, origin]
        }

        guard inputs.localBrainIsReady else {
            return [welcome]
        }

        let brainAdapter = LocalBrainAwakePageSourceAdapter()
        let brain = brainAdapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        let brainShown = inputs.surfaceHistory["source:\(brain.sourceID)"] != nil

        guard brainShown else {
            return [welcome, brain]
        }

        guard !hasKeptFirstSouvenir(day: day, inputs: inputs) else { return nil }

        return [welcome, brain, firstSouvenirSurface(for: day)]
    }

    private static func hasKeptFirstSouvenir(day: BookDay, inputs: BookSourceInputs) -> Bool {
        ([day] + inputs.days).flatMap(\.pages).contains { page in
            page.type == .souvenir && (
                page.tags.contains("first-run-souvenir") ||
                page.tags.contains("onboarding") ||
                page.sourceID == "one-sentence-souvenir"
            )
        }
    }

    private static func firstSouvenirSurface(for day: BookDay) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .souvenir)
        return SurfacePage(
            id: "first-run-souvenir-\(day.id)",
            type: .souvenir,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .quoteCard,
            score: 99,
            reason: "The Book has introduced itself and woken its local brain; now The First Door needs one true sentence.",
            prompt: "The First Door: One True Sentence",
            detail: "A small real detail opens the first shelf.",
            payload: BookPagePayload(
                headline: "One-Sentence Souvenir",
                body: "The Book's ready. Give it one sentence from the real world: a sound, color, smell, joke, texture, mercy, or tiny oddity from today.",
                metadata: [
                    "source": source.id,
                    "firstRunStep": "first-souvenir",
                    "placeholder": "One real sentence from today...",
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": "souvenir,first-run,first-run-souvenir,one-sentence-souvenir"
                ]
            )
        )
    }
}

struct AskTheBookPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .askTheBook)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        [
            SurfacePage(
                id: "\(source.id)-\(day.id)",
                type: .askTheBook,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: 61,
                reason: "Ask plainly. The page will answer plainly.",
                prompt: "Ask the Book",
                detail: "Write one question. The Book will answer with a useful next step.",
                payload: BookPagePayload(
                    headline: "Ask the Book",
                    body: "Ask one real question. The answer should help you move.",
                    metadata: [
                        "source": source.id,
                        "privacy": "private local",
                        "tags": "ask-the-book,local-model,gemma,labyrinth"
                    ]
                )
            )
        ]
    }
}

struct InkrestPrompt: Equatable {
    let id: String
    let lens: String
    let question: String
    let openingNudge: String
}

// Dr. Inkrest's Office Hours: a short, distilled narrative-therapy sitting that opens
// in the evening. The package side owns the rotating prompts, the window, and the
// surfacing gate; the app side owns the Gemma conversation and the kept transcript.
enum InkrestOfficeHours {
    static let windowStartHour = 20   // 8:00 pm
    static let windowEndHour = 22     // 10:00 pm (exclusive)
    // Total Dr. Inkrest replies before she gently brings the sitting to a close.
    // Form intake counts as the first turn, leaving room for a genuinely substantial
    // conversation without turning Office Hours into an endless chat surface.
    static let replyCap = 7

    static let rotatingPrompts: [InkrestPrompt] = [
        InkrestPrompt(
            id: "externalize",
            lens: "externalizing",
            question: "If the heaviest feeling today were a character who knocked on your door, what would you call it — and what did it want?",
            openingNudge: "Inkrest likes to give a feeling a name so it stops pretending to be you."
        ),
        InkrestPrompt(
            id: "unique-outcome",
            lens: "unique outcome",
            question: "When was a small moment today the difficulty did not get to touch?",
            openingNudge: "Inkrest hunts for the exceptions — the minutes that disobeyed the hard story."
        ),
        InkrestPrompt(
            id: "preferred-story",
            lens: "preferred story",
            question: "If this chapter of you were being read aloud kindly, what one sentence would you want it to keep?",
            openingNudge: "Inkrest is curious which story you would choose to be true."
        ),
        InkrestPrompt(
            id: "values",
            lens: "values",
            question: "What did you do today that quietly mattered to you, even if no one noticed?",
            openingNudge: "Inkrest reads small acts as evidence of what you actually value."
        ),
        InkrestPrompt(
            id: "absent-but-implicit",
            lens: "absent but implicit",
            question: "What did today's hard feeling reveal that you were hoping for or protecting?",
            openingNudge: "Inkrest believes a difficult feeling always points at something you care about."
        ),
        InkrestPrompt(
            id: "re-authoring",
            lens: "re-authoring",
            question: "If you could rewrite one sentence you told yourself today, what would the kinder, truer version say?",
            openingNudge: "Inkrest keeps a soft eraser for the sentences that were never fair."
        ),
        InkrestPrompt(
            id: "landscape-of-action",
            lens: "landscape of action",
            question: "What is one small, doable thing the next day could hold that you'd actually like?",
            openingNudge: "Inkrest prefers one livable step to a heroic plan."
        ),
        InkrestPrompt(
            id: "witness",
            lens: "witnessing",
            question: "If a person who truly gets you had watched today, what would they have understood without you explaining?",
            openingNudge: "Inkrest likes to borrow the eyes of someone who already believes in you."
        )
    ]

    static func isOpen(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= windowStartHour && hour < windowEndHour
    }

    static func prompt(for day: BookDay) -> InkrestPrompt {
        guard !rotatingPrompts.isEmpty else {
            return InkrestPrompt(id: "open", lens: "open", question: "How did today actually go?", openingNudge: "")
        }
        let index = abs("\(day.id)-inkrest-office-hours".stableHash) % rotatingPrompts.count
        return rotatingPrompts[index]
    }
}

struct InkrestOfficeHoursPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .inkrestOfficeHours)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard InkrestOfficeHours.isOpen(now) else { return [] }
        let slot = BookDay.id(for: now)
        let alreadyKept = day.pages.contains {
            $0.type == .inkrestOfficeHours && $0.tags.contains("inkrest-office-hours:\(slot)")
        }
        guard !alreadyKept else { return [] }
        // Office Hours wants something of the day to reflect on. Open when the reader has
        // kept at least one page today, or when a hard signal is asking for gentle company.
        guard !day.capturedPages.isEmpty || context.distress.isActive else { return [] }

        let prompt = InkrestOfficeHours.prompt(for: day)
        let score = context.distress.isActive ? 82 : 74
        return [
            SurfacePage(
                id: "\(source.id)-\(slot)",
                type: .inkrestOfficeHours,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: score,
                reason: context.distress.isActive
                    ? "The lamp is lit. Dr. Inkrest left the door ajar for a hard evening."
                    : "Dr. Inkrest has an open chart window for a short evening sitting.",
                prompt: "Dr. Inkrest's Office Hours",
                detail: "A private evening sitting. Bring the day; Inkrest will read it closely with you.",
                payload: BookPagePayload(
                    headline: "Dr. Inkrest's Office Hours",
                    body: "The lamp on Inkrest's desk is lit between 8 and 10. Sit a while. She reads with you, never at you.\n\n\(prompt.openingNudge)",
                    metadata: [
                        "source": source.id,
                        "slot": slot,
                        "privacy": "private local",
                        "rotatingPromptID": prompt.id,
                        "rotatingLens": prompt.lens,
                        "rotatingQuestion": prompt.question,
                        "openingNudge": prompt.openingNudge,
                        "tags": "inkrest-office-hours,inkrest-office-hours:\(slot),dr-inkrest,therapy-chart,narrative-therapy,local-model,gemma"
                    ]
                )
            )
        ]
    }
}

// Surfaces an open Fae Bargain so the reader can pay it, or a lapsed one so they
// can repair it. The *offering* of new bargains (which fronts the gift and writes
// to the vault) is orchestrated app-side; this adapter only reflects vault state.
struct FaeBargainPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .faeBargain)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let state = inputs.faeState
        // Don't crowd a hard day with a debt — the Fae can wait.
        guard !context.distress.isActive else { return [] }

        if let owed = state.bargains.first(where: { $0.status == .owed }) {
            return [page(for: owed, status: .owed, now: now, claim: state.claim(for: owed.faeKind), court: state.literaryElfCourt())]
        }
        if let lapsed = state.bargains.last(where: { $0.status == .lapsed }) {
            return [page(for: lapsed, status: .lapsed, now: now, claim: state.claim(for: lapsed.faeKind), court: state.literaryElfCourt())]
        }
        return []
    }

    /// Build the bargain's page on demand (e.g., opened from the BookShop's
    /// standing section), reusing the same layout the feed uses.
    static func surface(for bargain: FaeBargain, now: Date = Date()) -> SurfacePage {
        FaeBargainPageSourceAdapter().page(for: bargain, status: bargain.status, now: now, claim: 0, court: bargain.faeKind == .literaryElf ? .seelie : nil)
    }

    static func surface(for bargain: FaeBargain, state: FaePlayerState, now: Date = Date()) -> SurfacePage {
        FaeBargainPageSourceAdapter().page(
            for: bargain,
            status: bargain.status,
            now: now,
            claim: state.claim(for: bargain.faeKind),
            court: state.literaryElfCourt()
        )
    }

    private func page(
        for bargain: FaeBargain,
        status: FaeBargainStatus,
        now: Date,
        claim: Int,
        court: FaeCourt?
    ) -> SurfacePage {
        let isRepair = status == .lapsed
        let hoursLeft = max(0, Int(bargain.deadline.timeIntervalSince(now) / 3_600))
        let deadlineLine = hoursLeft >= 24
            ? "about \(hoursLeft / 24) day\(hoursLeft / 24 == 1 ? "" : "s") to pay"
            : (hoursLeft > 0 ? "about \(hoursLeft) hour\(hoursLeft == 1 ? "" : "s") to pay" : "the debt is due")
        let claimBand = FaeEconomy.claimBand(for: claim)
        let claimLine = FaeEconomy.claimLine(for: bargain.faeKind, claim: claim)
        let giftUseLine = bargain.faeKind.giftEffect.useLine
        let consequenceLine = isRepair
            ? "\(bargain.giftName) is cold. Repair the debt with a real noticing; when the Fae accepts it, the gift warms again and the repair becomes part of your story."
            : "If you do not pay in time, \(bargain.giftName) goes cold, \(bargain.faeKind.name)'s Claim rises, and that Fae market closes until you repair the debt."
        let courtLine = bargain.faeKind == .literaryElf
            ? "\n\n\(court?.standingLine ?? FaeCourt.seelie.standingLine)"
            : ""
        let scene = bargainScene(for: bargain, isRepair: isRepair, court: court)
        let body: String
        if isRepair {
            body = """
            \(scene)

            The gift has gone cold. It is still yours, but it no longer answers cleanly; faerie gifts remember the shape of unpaid attention.

            \(consequenceLine)

            \(claimLine)\(courtLine)
            """
        } else {
            body = """
            \(scene)

            The exchange is already real: the \(bargain.faeKind.name) gave first. The gift is \(bargain.giftName). It does this: \(bargain.giftEffectLine)

            \(giftUseLine)

            Now the debt is yours. Pay with this noticing: \(bargain.terms)

            You have \(deadlineLine). \(consequenceLine)

            \(claimLine)\(courtLine)
            """
        }
        return SurfacePage(
            id: "\(source.id)-\(bargain.id)\(isRepair ? "-repair" : "")",
            type: .faeBargain,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: isRepair ? 60 : 79,
            reason: isRepair
                ? "A bargain lapsed. \(bargain.giftName) has gone cold; the \(bargain.faeKind.name) is closer to the page."
                : "The \(bargain.faeKind.name) gave first. A sensory return is owed — \(deadlineLine).",
            prompt: isRepair ? "A Wild Exchange" : "A Fae Bargain",
            detail: isRepair
                ? "Repair it with a real noticing. The consequence becomes part of the story."
                : bargain.terms,
            payload: BookPagePayload(
                headline: isRepair ? "The Bargain Went Wild" : "A Fae Bargain",
                body: body,
                metadata: [
                    "source": source.id,
                    "bargainID": bargain.id,
                    "faeKind": bargain.faeKind.rawValue,
                    "faeName": bargain.faeKind.name,
                    "faeCourt": bargain.faeKind == .literaryElf ? (court?.rawValue ?? FaeCourt.seelie.rawValue) : "",
                    "terms": bargain.terms,
                    "giftName": bargain.giftName,
                    "giftEffectLine": bargain.giftEffectLine,
                    "giftUseLine": giftUseLine,
                    "openingGesture": bargain.openingGesture,
                    "deadlineLine": deadlineLine,
                    "consequenceLine": consequenceLine,
                    "claim": "\(claim)",
                    "claimBand": claimBand,
                    "claimLine": claimLine,
                    "faeContext": "Claim \(claim): \(claimLine)\(courtLine)",
                    "status": status.rawValue,
                    "deadline": ISO8601DateFormatter().string(from: bargain.deadline),
                    "isRepair": isRepair ? "true" : "false",
                    "tags": "fae-bargain,fae:\(bargain.faeKind.rawValue),attention\(isRepair ? ",fae-repair" : "")"
                ]
            )
        )
    }

    private func bargainScene(for bargain: FaeBargain, isRepair: Bool, court: FaeCourt?) -> String {
        let cold = isRepair
            ? " The gift gives off no warmth now; even its name seems written in older ink."
            : ""
        switch bargain.faeKind {
        case .bookSprite:
            return """
            A page slips loose from the air beside the Book, thin as onion-skin and already turning itself. A Book Sprite crouches on the upper margin with both knees tucked under its chin, reading the final line before the first one has arrived.

            "\(bargain.giftName)," it says, not offering the page so much as remembering that you accepted it. "You began this yesterday. You will begin it tomorrow."\(cold)
            """
        case .sentenceSalamander:
            return """
            Heat gathers along the gutter of the page. A Sentence Salamander uncoils there, ember-bright at the throat, and presses a coal of syntax into your keeping. The air smells faintly of struck matches and warm paper.

            "\(bargain.giftName)," it says, and the words glow down its spine. "Keep it near the grey. It bites cold things first."\(cold)
            """
        case .punctuationPixie:
            return """
            Three commas skitter across the page like silver insects, then stop in a row. A Punctuation Pixie drops between them upside down, grinning with ink on both hands, and turns a full stop into an ellipsis with one wicked fingernail.

            "\(bargain.giftName)," the Pixie says. "Pause here. No, there. No, wait -- better."\(cold)
            """
        case .literaryElf:
            let courtName = court?.title ?? FaeCourt.seelie.title
            return """
            The page straightens itself. A Literary Elf stands at the margin as if the margin were a court floor, one hand resting beside a silver quill that was not there a breath ago. The light around the nib looks ceremonial and sharp.

            "By the manners of the \(courtName), \(bargain.giftName)," the Elf says. "A gift given first is not a kindness. It is a law made visible."\(cold)
            """
        case .deepLoreDwarf:
            return """
            Something heavy knocks once beneath the page. A Deep Lore Dwarf sets a grey stone in the lower margin and waits until the paper stops trembling. Dust settles around the stone in a perfect ring.

            "\(bargain.giftName)," the Dwarf says at last. "Small stones remember roofs. Small debts remember names."\(cold)
            """
        case .goblin:
            return """
            A sealed card slides out from under the page and stops against your thumb. The wax is already broken. A Marginalia Goblin sits behind it with a ledger, a brass toothpick, and the expression of someone who has charged you for noticing the obvious.

            "\(bargain.giftName)," the Goblin says. "Spend it where the stalls bite. Pay me before the ink learns interest."\(cold)
            """
        }
    }
}

struct BookFaePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookFae)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard !context.distress.isActive else { return [] }
        guard inputs.faeState.openBargains.isEmpty else { return [] }

        let keptCount = day.pages.count + day.capturedPages.count
        guard keptCount > 0 || inputs.faeState.attention > 0 || !inputs.faeState.gifts.isEmpty else { return [] }

        let kind = chooseKind(from: inputs.faeState, day: day)
        let claim = inputs.faeState.claim(for: kind)
        let warmth = inputs.faeState.warmth(for: kind)
        let omens = inputs.faeState.activeOmens(for: kind, on: now)
        let strongestOmen = omens.max { $0.intensity < $1.intensity }
        let court = kind == .literaryElf ? inputs.faeState.literaryElfCourt() : nil
        let courtLine = court.map { "\n\($0.title): \($0.standingLine)" } ?? ""
        let omenLine = strongestOmen.map { "\nActive omen: \($0.title). \($0.text)" } ?? ""
        let signalLines = [
            day.pages.last.map { "The reader recently kept: \($0.promptText.bookPreviewSentenceLimit(1))" },
            inputs.faeState.gifts.last.map { "A Fae gift is in play: \($0.name), \($0.isCold ? "cold" : "warm")." },
            strongestOmen.map { "A Fae omen is active: \($0.title) (\($0.intensity)/5)." },
            "Fae standing: \(warmth) Warmth, \(claim) Claim (\(FaeEconomy.claimBand(for: claim)))."
        ].compactMap(\.self)
        let pageID = "\(source.id)-\(BookDay.id(for: now))-\(kind.rawValue)"
        let parleyTurn = FaeParleyTurnBuilder.turn(
            kind: kind,
            claim: claim,
            warmth: warmth,
            court: court,
            omenTitle: strongestOmen?.title,
            slotKey: pageID
        )
        var metadata: [String: String] = [
                        "source": source.id,
                        "faeKind": kind.rawValue,
                        "faeName": kind.name,
                        "faeCourt": court?.rawValue ?? "",
                        "faeOmens": omens.map { "\($0.title): \($0.text)" }.joined(separator: "\n"),
                        "faeStrongestOmen": strongestOmen?.title ?? "",
                        "selectedThreads": "Fae Claim, Old Law, Marginalia",
                        "selectedEntities": kind.name,
                        "selectedEntityIDs": "fae-\(kind.rawValue)",
                        "realSignals": signalLines.joined(separator: "\n"),
                        "relationshipPressures": "\(FaeEconomy.claimLine(for: kind, claim: claim))\(courtLine)\(omenLine)\nWarmth with this kind: \(warmth). The Fae are not punishers; they turn failure into stranger story.",
                        "entityMemories": "The \(kind.name) remembers Warmth \(warmth), Claim \(claim), and whether the reader chooses courtesy, old law, or a sideways door.",
                        "storyGenreName": "Old Faerie Parley",
                        "storyGenreLens": "Traditional faerie manners: courtesy, exact wording, beautiful danger, loopholes, gifts with edges, and no cruelty for sport.",
                        "storyChoiceSliceOfLifeTitle": "Offer Courtesy",
                        "storyChoiceSliceOfLifePrompt": "Answer with one exact ordinary detail and no performance.",
                        "storyChoiceSliceOfLifeEffect": "Warmth rises and Claim softens; courtesy makes the Fae less hungry.",
                        "storyChoiceSliceOfLifeMechanic": "none",
                        "storyChoiceProgressArcTitle": "Name the Law",
                        "storyChoiceProgressArcPrompt": "Ask what rule this Fae follows when no one watches.",
                        "storyChoiceProgressArcEffect": "Warmth and Attention rise, but Claim edges closer; old law has noticed you.",
                        "storyChoiceProgressArcMechanic": "none",
                        "storyChoiceSurpriseTitle": "Take the Thorn",
                        "storyChoiceSurprisePrompt": "Accept one strange mark in exchange for a sideways secret.",
                        "storyChoiceSurpriseEffect": "Attention rises and Claim sharpens; the mark may draw stranger Fae pages later.",
                        "storyChoiceSurpriseMechanic": "none",
                        "faeInteraction": "true",
                        "faeWarmth": "\(warmth)",
                        "faeClaim": "\(claim)",
                        "uses": "fae warmth, fae claim, attention, narrative choices",
                        "cadence": "curated fae parley"
        ]
        metadata.merge(parleyTurn.metadata) { _, new in new }
        return [
            SurfacePage(
                id: pageID,
                type: .bookFae,
                sourceID: source.id,
                intent: .simulate,
                renderStyle: .graphEvent,
                score: score(for: kind, state: inputs.faeState, keptCount: keptCount),
                reason: strongestOmen.map { "\(kind.name) has come to answer the omen: \($0.title)." } ?? "\(kind.name) has come to parley, not bargain.",
                prompt: "\(kind.name) at the Margin",
                detail: strongestOmen.map { "A faerie interaction under the mark of \($0.title)." } ?? "A faerie interaction with three old-law paths.",
                payload: BookPagePayload(
                    headline: "\(kind.name) at the Margin",
                    body: strongestOmen.map { "\(kind.name) touches the edge of the page. The mark called \($0.title) answers in the paper." } ?? "\(kind.name) touches the edge of the page. This is not a bargain. It is a parley.",
                    metadata: metadata
                )
            )
        ]
    }

    private func chooseKind(from state: FaePlayerState, day: BookDay) -> FaeKind {
        if let marked = state.activeOmens().max(by: { $0.intensity < $1.intensity })?.faeKind {
            return marked
        }
        let ranked = FaeKind.allCases.sorted { left, right in
            let leftScore = abs(state.warmth(for: left)) + state.claim(for: left)
            let rightScore = abs(state.warmth(for: right)) + state.claim(for: right)
            if leftScore == rightScore { return left.rawValue < right.rawValue }
            return leftScore > rightScore
        }
        if let first = ranked.first, abs(state.warmth(for: first)) + state.claim(for: first) > 0 {
            return first
        }
        let seed = "\(day.id)-book-fae-page"
        return FaeKind.allCases[abs(seed.stableHash) % FaeKind.allCases.count]
    }

    private func score(for kind: FaeKind, state: FaePlayerState, keptCount: Int) -> Int {
        let standing = abs(state.warmth(for: kind)) + state.claim(for: kind)
        let omenPressure = state.activeOmens(for: kind).map(\.intensity).reduce(0, +)
        return min(88, 48 + keptCount * 3 + standing / 2 + omenPressure * 4)
    }
}

// Surfaces a keepable dispatch when the Pact War produces a dramatic crossing
// (a territory seized, or a Talisman reaching Sovereign). Pure static prose.
struct PactDispatchPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .pactDispatch)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !context.distress.isActive else { return [] }
        let kept = keptDispatchIDs(in: inputs.days + [day])
        guard let dispatch = inputs.pactWar.pendingDispatches
            .filter({ !kept.contains($0.id) })
            .sorted(by: { $0.at > $1.at })
            .first else { return [] }
        return [page(for: dispatch, now: now)]
    }

    private func keptDispatchIDs(in days: [BookDay]) -> Set<String> {
        var ids = Set<String>()
        for day in days {
            for page in day.pages {
                for tag in page.tags where tag.hasPrefix("pact-dispatch:") {
                    ids.insert(String(tag.dropFirst("pact-dispatch:".count)))
                }
            }
        }
        return ids
    }

    private func page(for dispatch: PactDispatch, now: Date) -> SurfacePage {
        let territory = PactTerritoryRegistry.territory(id: dispatch.territoryID)
        let chapter = AcademyChapterRegistry.chapter(forTalismanID: dispatch.talismanID)
        let talismanName = chapter?.talismanName ?? "A Talisman"
        let sovereign = dispatch.kind == .sovereign
        let body: String
        if sovereign {
            body = """
            \(dispatch.line)

            This is not a quiet influence anymore. \(talismanName) now acts through \(territory?.name ?? "this territory") without being asked — its philosophy shapes what surfaces here and how it is framed.

            \(chapter.map { "\($0.name)'s doctrine: \($0.philosophy)" } ?? "")
            """
        } else {
            body = """
            \(dispatch.line)

            The shelf changes hands. From here, \(talismanName) frames \(territory?.name ?? "this territory") in its own voice — until another Talisman presses harder.

            \(territory?.blurb ?? "")
            """
        }
        return SurfacePage(
            id: "\(source.id)-\(dispatch.id)",
            type: .pactDispatch,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: sovereign ? 82 : 73,
            reason: sovereign
                ? "A Talisman has reached Sovereign. The Pact War has a new power."
                : "A territory has changed hands in the Pact War.",
            prompt: sovereign ? "A Talisman Reigns" : "A Shelf Changes Hands",
            detail: dispatch.line,
            payload: BookPagePayload(
                headline: sovereign ? "Sovereign" : "Pact Dispatch",
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                metadata: [
                    "source": source.id,
                    "dispatchID": dispatch.id,
                    "talismanID": dispatch.talismanID,
                    "territoryID": dispatch.territoryID,
                    "dispatchKind": dispatch.kind.rawValue,
                    "tags": "pact-dispatch,pact-dispatch:\(dispatch.id),pact-war"
                ]
            )
        )
    }
}

// Surfaces the day's headline celebration (a sabbat, a full/new moon esbat, or a
// meteor shower) as a keepable page carrying its invitation. Pure Almanac logic.
struct FestivalPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .festival)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let celebration = Almanac.active(on: now, hemisphere: inputs.hemisphere) else { return [] }
        // Thinning-veil feasts (Samhain, new moon) wait for a gentler day; the
        // light feasts are welcome even on a hard one.
        if context.distress.isActive, celebration.greyShift > 0 { return [] }

        let slot = BookDay.id(for: now)
        let tag = "festival:\(celebration.id):\(slot)"
        let alreadyKept = (inputs.days + [day]).contains { archiveDay in
            archiveDay.pages.contains { $0.type == .festival && $0.tags.contains(tag) }
        }
        guard !alreadyKept else { return [] }

        return [
            SurfacePage(
                id: "\(source.id)-\(celebration.id)-\(slot)",
                type: .festival,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .loreLetter,
                score: 80 + min(8, celebration.beliefBonus),
                reason: "\(celebration.academyTitle) is here — \(celebration.commonName). The world is keeping a feast.",
                prompt: celebration.academyTitle,
                detail: celebration.invitation,
                payload: BookPagePayload(
                    headline: celebration.academyTitle,
                    body: "\(celebration.blurb)\n\nThe invitation: \(celebration.invitation)",
                    metadata: [
                        "source": source.id,
                        "celebrationID": celebration.id,
                        "celebrationKind": celebration.kind.rawValue,
                        "commonName": celebration.commonName,
                        "academyTitle": celebration.academyTitle,
                        "blurb": celebration.blurb,
                        "invitation": celebration.invitation,
                        "invitationTitle": celebration.invitationTitle,
                        "beliefBonus": "\(celebration.beliefBonus)",
                        "accent": celebration.accent,
                        "placeholder": "Keep the feast in one true sentence...",
                        "tags": "festival,\(tag),almanac,\(celebration.kind.rawValue),celebration:\(celebration.id)"
                    ]
                )
            )
        ]
    }
}

// Surfaces "Today's Sky": the night overhead read for the reader's hemisphere —
// the Moon's phase and sign, the Sun's sign, whether the light is lengthening or
// drawing in, and the nearest celestial event. Pure Almanac/ephemeris logic;
// evening-leaning, once a day. A gentle page: welcome even on a hard day.
struct TodaysSkyPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .todaysSky)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        // Looking up is an evening (or small-hours) thing.
        let hour = Calendar.current.component(.hour, from: now)
        guard hour >= 17 || hour < 5 else { return [] }

        let slot = BookDay.id(for: now)
        let tag = "todays-sky:\(slot)"
        let alreadyKept = (inputs.days + [day]).contains { archiveDay in
            archiveDay.pages.contains { $0.type == .todaysSky && $0.tags.contains(tag) }
        }
        guard !alreadyKept else { return [] }

        let reading = SkyAlmanac.reading(on: now, hemisphere: inputs.hemisphere)
        let pct = Int((reading.moon.illuminatedFraction * 100).rounded())
        let body = "\(reading.openingLine)\n\n" + reading.notes.joined(separator: "\n\n")
        let accent = reading.activeShower?.accent ?? (reading.lightTrend == .shortening ? "slate" : "violet")

        return [
            SurfacePage(
                id: "\(source.id)-\(slot)",
                type: .todaysSky,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70 + (reading.nextEvent.daysAway == 0 ? 8 : 0) + (reading.activeShower == nil ? 0 : 6),
                reason: "Tonight: \(reading.moon.name) in \(reading.moonSign.name). \(reading.nextEvent.name) \(reading.nextEvent.line).",
                prompt: "Today's Sky",
                detail: "Keep one true sentence about the sky tonight.",
                payload: BookPagePayload(
                    headline: "Today's Sky",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "openingLine": reading.openingLine,
                        "moonName": reading.moon.name,
                        "moonSymbol": reading.moon.symbolName,
                        "moonIllum": "\(pct)",
                        "moonLine": reading.moon.enchantedLine,
                        "moonSign": reading.moonSign.name,
                        "moonGlyph": reading.moonSign.glyph,
                        "moonElement": reading.moonSign.element,
                        "sunSign": reading.sunSign.name,
                        "sunGlyph": reading.sunSign.glyph,
                        "lightTrend": reading.lightTrend.phrase,
                        "lightSymbol": reading.lightTrend.symbolName,
                        "eventKind": reading.nextEvent.kind,
                        "eventName": reading.nextEvent.name,
                        "eventLine": reading.nextEvent.line,
                        "eventSymbol": reading.nextEvent.symbolName,
                        "eventTimestamp": "\(reading.nextEvent.date.timeIntervalSince1970)",
                        "showerName": reading.activeShower?.commonName ?? "",
                        "accent": accent,
                        "placeholder": "Keep the sky in one true sentence...",
                        "tags": "todays-sky,\(tag),almanac,sky,moon:\(reading.moonSign.name.lowercased())"
                    ]
                )
            )
        ]
    }
}

// Surfaces "The Two Readings": two cast members, chosen dynamically, who read the
// reader's recent pages differently. The preview is local; tapping it generates
// the disagreement prose. Distress-gated, once per day.
struct TwoReadingsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .twoReadings)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        // Only when one a day, and only with something worth arguing about.
        guard !day.pages.contains(where: { $0.type == .twoReadings }) else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"].map({ now.timeIntervalSince($0.lastShownAt) >= 18 * 3600 }) ?? true else {
            return []
        }

        let recentPages = (inputs.days.flatMap(\.capturedPages) + day.capturedPages)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(8)
        let signalLines = inputs.continuity.strongestSignals.prefix(4).map(\.line)
        guard recentPages.count >= 3 || signalLines.count >= 2 else { return [] }

        let evidenceText = (recentPages.map { "\($0.userInput) \($0.tags.joined(separator: " "))" } + signalLines)
            .joined(separator: " ")

        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        guard let pair = DisagreementEngine.select(
            entities: entities,
            relationships: NarrativePackRegistry.relationships,
            evidenceText: evidenceText,
            surfaceHistory: inputs.surfaceHistory,
            now: now
        ) else { return [] }

        let aProfile = entities.first { $0.id == pair.aID }.map(Self.profile) ?? pair.aName
        let bProfile = entities.first { $0.id == pair.bID }.map(Self.profile) ?? pair.bName
        let slot = BookDay.id(for: now)
        return [
            SurfacePage(
                id: "\(source.id)-\(pair.pairKey)-\(slot)",
                type: .twoReadings,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: 76,
                reason: "\(pair.aName) and \(pair.bName) are reading your recent pages differently.",
                prompt: "The Two Readings",
                detail: "\(pair.aName) and \(pair.bName) don't agree about what your week is saying. Open it; you decide.",
                payload: BookPagePayload(
                    headline: "The Two Readings",
                    body: "Two of the cast have read the same pages and reached different conclusions. The Book won't settle it for you.",
                    metadata: [
                        "source": source.id,
                        "pairID": pair.pairKey,
                        "entityAID": pair.aID,
                        "entityBID": pair.bID,
                        "entityAName": pair.aName,
                        "entityBName": pair.bName,
                        "entityAProfile": aProfile,
                        "entityBProfile": bProfile,
                        "relationshipNote": pair.relationshipNote ?? "",
                        "tags": "two-readings,entity:\(pair.aID),entity:\(pair.bID),two-readings:\(slot)"
                    ]
                )
            )
        ]
    }

    /// A compact stance sketch the prompt can argue from — works for bundled and
    /// custom cast alike.
    static func profile(_ entity: NarrativeWorldEntity) -> String {
        var parts: [String] = [entity.name]
        if let chapter = entity.chapter { parts.append("Chapter: \(chapter)") }
        if !entity.beliefs.isEmpty { parts.append("believes: \(entity.beliefs.prefix(2).joined(separator: "; "))") }
        if !entity.faults.isEmpty { parts.append("blind spot: \(entity.faults.first ?? "")") }
        let cares = entity.unwrittenInterest ?? entity.goals.first
        if let cares, !cares.isEmpty { parts.append("cares about: \(cares)") }
        if let voice = entity.writingVoice { parts.append("voice: \(voice.register)") }
        else if !entity.traits.isEmpty { parts.append("voice: \(entity.traits.prefix(3).joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }
}

struct CastBondPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .castBond)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let names = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0.name) })
        let fired = firedKeys(in: inputs.days + [day])

        return CastBondEngine.emergent(
            field: inputs.relationshipField,
            names: names,
            firedKeys: fired,
            now: now
        )
        .prefix(2)
        .map { surface(for: $0, now: now) }
    }

    private func firedKeys(in days: [BookDay]) -> Set<String> {
        Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix("cast-bond:") ? String(tag.dropFirst("cast-bond:".count)) : nil
        })
    }

    private func surface(for bond: CastBond, now: Date) -> SurfacePage {
        let isRivalry = bond.kind == .rivalry
        let title = isRivalry ? "A Rivalry Erupts" : "An Alliance Forms"
        let kind = bond.kind.rawValue
        let verb = isRivalry ? "tightened until it sparked" : "warmed until it answered"
        let body = """
        The Book has been keeping count of the threads in the margins.

        \(bond.aName) and \(bond.bName) have crossed a living threshold: the thread between them \(verb).

        Something between them is strong enough now to step out of the background and act. Open it.
        """

        return SurfacePage(
            id: "\(source.id)-\(bond.firedKey)-\(SurfaceCadence.minuteSlotID(for: now, minutes: 30))",
            type: .castBond,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: min(86, 60 + bond.intensity),
            reason: isRivalry
                ? "\(bond.aName) and \(bond.bName) have come to a head."
                : "\(bond.aName) and \(bond.bName) have found each other.",
            prompt: title,
            detail: isRivalry
                ? "Something between \(bond.aName) and \(bond.bName) has sharpened into conflict."
                : "\(bond.aName) and \(bond.bName) have grown into an alliance.",
            payload: BookPagePayload(
                headline: title,
                body: body,
                metadata: [
                    "source": source.id,
                    "bondID": bond.id,
                    "bondKind": kind,
                    "bondFiredKey": bond.firedKey,
                    "pairID": bond.pairKey,
                    "entityAID": bond.aID,
                    "entityBID": bond.bID,
                    "entityAName": bond.aName,
                    "entityBName": bond.bName,
                    "intensity": "\(bond.intensity)",
                    "tags": "cast-bond,\(kind),cast-bond:\(bond.firedKey),entity:\(bond.aID),entity:\(bond.bID),relationship-field"
                ]
            )
        )
    }
}

struct GlowInvitationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .glowInvitation)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard inputs.readerBeliefScore >= 80 else { return [] }
        guard !keptGlowInvitationRecently(in: inputs.days + [day], now: now) else { return [] }

        let isTooFull = inputs.readerBeliefScore >= 90
        let score = isTooFull ? 95 : 78
        let glowName = BeliefLexicon.glowName(for: inputs.readerBeliefScore)
        let body = isTooFull
            ? """
            Your Glow has reached the top of the wick. The Book can hold it for a while, but excess light settles back into the paper overnight.

            Spend some of it on a cast member, a page type, a spell, or a living thread you want the Book to treat as more real. Attention kept in motion becomes story.
            """
            : """
            Your Glow is radiant enough to steer the Book on purpose.

            Give Belief to a cast member you want closer, a page type you want more often, or a spell that deserves weight. Take Belief from anything that has been too loud.
            """

        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 6))",
                type: .glowInvitation,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: score,
                reason: isTooFull
                    ? "Your Glow is too full and wants somewhere to live."
                    : "Your Glow is radiant enough to spend deliberately.",
                prompt: isTooFull ? "Your Glow Is Too Full" : "Your Glow Wants a Direction",
                detail: "Open the Glow menu and give Belief to a cast member, a page type, or something you want more of.",
                payload: BookPagePayload(
                    headline: isTooFull ? "Your Glow Is Too Full" : "Your Glow Wants a Direction",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "readerBeliefScore": "\(inputs.readerBeliefScore)",
                        "readerGlowName": glowName,
                        "openGlowMenu": "true",
                        "noBeliefReward": "true",
                        "placeholder": "Name where this Glow should go.",
                        "tags": "glow,belief,spend-glow,\(isTooFull ? "glow-too-full" : "radiant-glow")"
                    ]
                )
            )
        ]
    }

    private func keptGlowInvitationRecently(in days: [BookDay], now: Date) -> Bool {
        let cutoff = now.addingTimeInterval(-2 * 86_400)
        return days
            .flatMap(\.pages)
            .contains { $0.type == .glowInvitation && $0.createdAt >= cutoff }
    }
}

struct HelpTipEntry: Equatable {
    var id: String
    var title: String
    var prompt: String
    var body: String
    var tags: [String]
}

enum HelpTipsCatalog {
    static let entries: [HelpTipEntry] = [
        HelpTipEntry(
            id: "first-five-minutes",
            title: "First Five Minutes",
            prompt: "Start small, keep one thing, then let the Book learn.",
            body: """
            Use the app like a living notebook, not a dashboard.

            1. Keep one tiny true thing. A Diary Page, Inner Weather note, Fuel Log, photo, or Souvenir all count.
            2. Don't wait for a grand moment. The Book's strongest when you feed it ordinary evidence.
            3. Open one rising page and answer only what feels finishable.
            4. If a page feels wrong today, dismiss it. Dismissed pages rest and may return later.
            5. Use the Glow menu when you want to steer what appears more often.

            Good first keeps:
            - "Coffee tasted burnt but useful."
            - "The window was blue before the room was."
            - "I'm tired, but not erased."

            The trick: one kept page changes the day more than ten unopened perfect plans.
            """,
            tags: ["help", "onboarding", "basics", "keep-page"]
        ),
        HelpTipEntry(
            id: "glow-menu",
            title: "Using Glow",
            prompt: "Tune the Book by giving or taking Belief.",
            body: """
            Glow is the Book's attention budget.

            Give Belief when you want more of a page, character, source, or talisman. Take Belief when something is too loud, stale, or unhelpful. Low Glow doesn't delete anything; it just lowers its chance of surfacing.

            Good uses:
            - Give Belief to Story Pages when you want the world to move.
            - Give Belief to Body or Fuel when you want more care prompts.
            - Take Belief from Quips if you want fewer sparkle cards.
            - Give Belief to a Chapter Talisman if you want that Chapter's philosophy to tint the world.

            Tip: use Glow after you notice a pattern. If three pages in a row feel useful, warm that source. If three feel annoying, cool it.
            """,
            tags: ["help", "glow", "belief", "tuning"]
        ),
        HelpTipEntry(
            id: "story-gossip-letters",
            title: "Story, Gossip, and Letters",
            prompt: "Let the world move, then keep the pages that should count.",
            body: """
            Three page types move the Academy most visibly.

            Story Pages are playable scenes. They braid your day, current threads, characters, memories, and choices.

            Gossip Pages are simulation reports. They show what characters and entities did while you were elsewhere.

            Letter Pages are personal notes from characters. Some letters include research, memory, or a small world-state move.

            Important: when a generated page carries a real Belief delta, keeping the page commits it. This can include Chapter Talisman moves: a character may sometimes give Belief to their own talisman or try to take Belief from a rival Chapter's talisman.

            Tip: if a generated page matters, keep it. If it was only interesting, you can let it drift.
            """,
            tags: ["help", "story", "gossip", "letters", "talismans"]
        ),
        HelpTipEntry(
            id: "wonder-compass",
            title: "Wonder Compass Practice",
            prompt: "Use the compass directions as tiny real-world moves.",
            body: """
            The Compass isn't homework. It's a tiny navigation tool.

            North = Notice. Look before you interpret.
            East = Embark. Take the smallest real step.
            South = Sense. Use your body and surroundings.
            West = Write. Keep one sentence or photo.
            Center = Rest. Stop before the practice becomes a burden.

            Playful Missions live mostly in South = Sense. They should be concrete, sensory, and finishable in under three minutes.

            Good mission rhythm:
            - Read the mission.
            - Do the smallest honest version.
            - Keep one proof sentence or photo.
            - Stop.

            Tip: a mission works when it makes you more present, not when it becomes impressive.
            """,
            tags: ["help", "wonder-compass", "missions", "sense"]
        ),
        HelpTipEntry(
            id: "photos-enchantments",
            title: "Photos and Enchantments",
            prompt: "Turn real images into illuminated evidence.",
            body: """
            Photos are proof that the world was there.

            Illuminated Photos let Penny and Gemma notice what's already inside an image: objects, light, mood, symbols, jokes, and possible souvenirs.

            Enchantments are more deliberate. Choose a spell, attach a real photo, and keep the result when the spell feels earned.

            Good photo subjects:
            - A room corner with personality.
            - A meal, mug, shoe, shelf, receipt, or doorway.
            - A weather detail.
            - A small object that keeps following you.

            Tip: blurry ordinary photos often work better than staged ones. The Book likes evidence more than performance.
            """,
            tags: ["help", "photos", "enchantments", "proof"]
        ),
        HelpTipEntry(
            id: "body-fuel-guild",
            title: "Body, Fuel, and the Support Guild",
            prompt: "Use care pages as context, not judgment.",
            body: """
            Body and Fuel pages are for patterns, not blame.

            Fuel Logs help Dr. Vellum notice timing, energy, and care. Inner Weather helps Dr. Inkrest compare mood, pressure, and context. Support Guild Pages synthesize the signals gently.

            Useful entries are plain:
            - "Bagel and coffee, 9 AM."
            - "Tired but less sharp after lunch."
            - "Foggy, not sad exactly."
            - "Headache, water helped a little."

            You don't need perfect tracking. A few honest notes are enough for better pages later.

            Tip: when a day is hard, choose the smallest care entry instead of a big explanation.
            """,
            tags: ["help", "body", "fuel", "support-guild", "care"]
        ),
        HelpTipEntry(
            id: "search-stacks",
            title: "Search the Stacks",
            prompt: "Ask the archive for pages, cast, memories, and references.",
            body: """
            Search is for finding your own continuity.

            Try searches like:
            - "pages about Morgan"
            - "photos of coffee"
            - "what did I keep when I was tired?"
            - "Small Glow characters"
            - "Wonder Compass rest"
            - "Penny letters"

            The Stacks can surface kept pages, cast members, anchors, memories, favors, and reference snippets.

            Tip: search works best with human words. Names, moods, page types, Glow tiers, places, and repeated objects are all good handles.
            """,
            tags: ["help", "search", "archive", "stacks"]
        ),
        HelpTipEntry(
            id: "anchors-outer-stacks",
            title: "Anchors and Outer Stacks",
            prompt: "Let real places become rooms when they earn it.",
            body: """
            Anchors are real places the Labyrinth can recognize.

            When a known Anchor is nearby, an Outer Stacks page can open. The place stays real; the Book gives it a room-feeling, a rule, and a way to be entered through attention.

            Good anchors:
            - A porch, cafe, trailhead, library, parking lot, harbor, bench, or favorite aisle.
            - Somewhere repeatable.
            - Somewhere with a feeling you can name in a few words.

            Tip: name what the place holds, not just what it is. "The co-op" is useful. "The co-op, where errands become proof I still belong to town" is magic.
            """,
            tags: ["help", "anchors", "outer-stacks", "places"]
        ),
        HelpTipEntry(
            id: "page-packs-sources",
            title: "Sources, Packs, and Page Pressure",
            prompt: "Control what kinds of pages the Book offers.",
            body: """
            The Book chooses from active page sources.

            In the source and Glow menus, you can tune which pages appear more often. Installed Page Packs can add their own page types, rituals, games, utilities, and story materials.

            Practical tuning:
            - Want more story? Warm Story, Gossip, Letters, Cast, and Lore.
            - Want more grounding? Warm Body, Fuel, Weather, Rest, and Compass.
            - Want more reference? Warm Lore, Wonder Book, Help and Tips, and Packs.
            - Want a quieter shelf? Cool anything that feels noisy.

            Tip: the best shelf has variety. Don't max everything. Let the Book have a taste, then correct it when its taste gets annoying.
            """,
            tags: ["help", "sources", "packs", "curator", "glow"]
        ),
        HelpTipEntry(
            id: "privacy-local-brain",
            title: "Privacy and Local Brain",
            prompt: "Know what is private, generated, imported, or sensitive.",
            body: """
            Page sources carry privacy labels.

            Private Local pages belong on your device. Local Sensitive pages may include health, location, or personal context. Public Reference pages come from bundled or imported reference material.

            Gemma writes inside the local-brain flow when available. Some pages are templates, some are imported references, and some are generated from your kept context.

            Good habit:
            - Keep private pages honestly.
            - Use About You facts only when you're comfortable.
            - Treat health and location pages as context, not commands.
            - If a generated page overreaches, dismiss it and cool that source.

            Tip: the Book works better when it knows true things, but you decide which true things it gets to use.
            """,
            tags: ["help", "privacy", "local-brain", "gemma"]
        ),
        HelpTipEntry(
            id: "when-stuck",
            title: "When You Feel Stuck",
            prompt: "Use the smallest page that lowers friction.",
            body: """
            If the app feels like too much, shrink the move.

            Try one of these:
            - Keep an Inner Weather word.
            - Write one ordinary sentence.
            - Dismiss three pages without guilt.
            - Open Ask the Book and ask, "What is the smallest useful next step?"
            - Take a Center Page.
            - Keep a photo without explaining it.
            - Run one Playful Mission badly on purpose.

            The Book isn't grading you. It's trying to keep you company while attention returns.

            Tip: a page can be useful even if it isn't beautiful. Especially then.
            """,
            tags: ["help", "stuck", "rest", "small"]
        )
    ]

    static func entry(for day: BookDay, now: Date, manual: Bool = false) -> HelpTipEntry {
        let slot = SurfaceCadence.slotID(for: now, hours: manual ? 1 : 6)
        let index = stableIndex(for: "\(day.id)-help-tips-\(slot)-\(manual)", count: entries.count)
        return entries[index]
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct HelpTipsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .helpTips)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        helpSurface(entry: HelpTipsCatalog.entry(for: day, now: now, manual: true), context: context)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [helpSurface(entry: HelpTipsCatalog.entry(for: day, now: now), context: context)]
    }

    private func helpSurface(entry: HelpTipEntry, context: CuratorContext) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(entry.id)",
            type: .helpTips,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 56 : 64,
            reason: context.distress.isActive ? "A practical tip can lower the shelf noise." : "The Book has a useful trick tucked into the help margin.",
            prompt: entry.prompt,
            detail: entry.title,
            payload: BookPagePayload(
                headline: entry.title,
                body: entry.body,
                metadata: [
                    "source": source.id,
                    "tipID": entry.id,
                    "privacy": "public reference",
                    "symbol": source.symbolName,
                    "tags": entry.tags.joined(separator: ",")
                ]
            )
        )
    }
}

struct WorldEventPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSource(
        id: "world-event-door",
        type: .bookNotices,
        title: "World Event",
        shortTitle: "Event",
        symbolName: "sparkles.rectangle.stack",
        origin: .simulated,
        privacy: .privateLocal,
        isActive: true,
        cadence: "during active world events",
        note: "A door into temporary event physics: phases, outcomes, and fieldwork."
    )

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        return inputs.activeWorldEvents.map { surface(for: $0, day: day, now: now, manual: false) }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        if let event = inputs.activeWorldEvents.first {
            return surface(for: event, day: day, now: now, manual: true)
        }
        if let archivedEvent = WorldEventResolver.archivedEvents(now: now, day: day, inputs: inputs).first {
            return surface(for: archivedEvent, day: day, now: now, manual: true)
        }
        return SurfacePage(
            id: "\(source.id)-quiet-\(Int(now.timeIntervalSince1970))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 42,
            reason: "No world event is currently changing the Book's rules.",
            prompt: "The Almanac Is Quiet",
            detail: "No temporary physics are active.",
            payload: BookPagePayload(
                headline: "The Almanac Is Quiet",
                body: "The Book checks the almanac, the margins, the weather in the grammar, and finds no active world event asking for fieldwork.",
                metadata: ["source": source.id, "tags": "world-event,quiet-almanac"]
            )
        )
    }

    /// A door into a resolved event regardless of season. Returns nil only if
    /// there are no enabled events at all. Intended for development previews.
    func previewSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage? {
        let resolved = WorldEventResolver.previewEvents(now: now, day: day, inputs: inputs)
        guard let event = resolved.first else { return nil }
        return surface(for: event, day: day, now: now, manual: true, preview: true)
    }

    /// Builds the reader-facing page in the Book's voice: an in-world dispatch
    /// describing what the event is and what is happening right now, the player's
    /// standing so far, and a closing invitation to fieldwork. Deliberately keeps
    /// the generator-facing material (packetLines, lexical rules) out of view.
    private func narrativeBody(for event: ResolvedWorldEvent) -> String {
        var paragraphs: [String] = []

        // What the event is, in-world.
        paragraphs.append(event.packet.logline)

        // The current phase as a lived scene.
        let phaseScene = event.phase.scene?.trimmingCharacters(in: .whitespacesAndNewlines)
        paragraphs.append((phaseScene?.isEmpty == false ? phaseScene! : event.phase.packetLine))

        // Sensory weather, woven from the packet's atmosphere images.
        let atmosphere = event.packet.atmosphere.trimmingCharacters(in: .whitespacesAndNewlines)
        if !atmosphere.isEmpty {
            paragraphs.append("Everywhere you turn: \(atmosphere).")
        }

        // The player's standing so far, in character — derived rather than
        // leaking the outcome's generation instruction.
        paragraphs.append(standingLine(for: event))

        // The invitation to act.
        paragraphs.append("⸻")
        paragraphs.append("The Book turns a fresh page toward you. \(event.packet.fieldworkPrompt)")
        let reward = event.packet.fieldworkRewardLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reward.isEmpty {
            paragraphs.append(reward)
        }

        return paragraphs.joined(separator: "\n\n")
    }

    /// An in-character line describing how far the reader has stepped into the
    /// event, based on the resolved outcome and how many related pages they kept.
    private func standingLine(for event: ResolvedWorldEvent) -> String {
        let touches = event.playerTouchCount
        guard let outcome = event.outcome, touches > 0 else {
            return "You have only glanced at this so far. To the Book you are still a passerby — the event has not yet caught hold of you, and is waiting to see if it will."
        }
        let times = touches == 1 ? "once" : "\(touches) times"
        return "You have reached into this \(times). The Book has begun to regard you as \(outcome.title.lowercased())."
    }

    private func surface(for event: ResolvedWorldEvent, day: BookDay, now: Date, manual: Bool, preview: Bool = false) -> SurfacePage {
        let outcomeTitle = event.outcome?.title ?? "Unresolved"
        let body = narrativeBody(for: event)
        let tags = [
            "world-event",
            "event:\(event.id)",
            "event-phase:\(event.phase.id)",
            "event-outcome:\(event.outcome?.id ?? "none")",
            "event-fieldwork"
        ]
        return SurfacePage(
            id: "\(source.id)-\(event.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 12))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: manual ? 84 : 74 + min(12, event.phase.intensity),
            reason: preview
                ? "Almanac preview — \(event.title) shown out of season."
                : (manual
                    ? "You opened the event door yourself."
                    : "\(event.title) is changing the rules of the Book."),
            prompt: "\(event.title): \(event.phase.title)",
            detail: "\(outcomeTitle). \(event.packet.fieldworkPrompt)",
            payload: BookPagePayload(
                headline: event.title,
                body: body,
                metadata: [
                    "source": source.id,
                    "worldEventIDs": event.id,
                    "worldEventTitles": event.title,
                    "worldEventPhase": event.phase.id,
                    "worldEventOutcome": event.outcome?.id ?? "",
                    "worldEventPacket": event.influenceLine,
                    "fieldworkPrompt": event.packet.fieldworkPrompt,
                    "fieldworkPlaceholder": event.packet.fieldworkPlaceholder,
                    "fieldworkRewardLine": event.packet.fieldworkRewardLine,
                    "symbol": source.symbolName,
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }
}

enum BookPageSourceAdapters {
    static let active: [BookPageSourceAdapter] = [
        InventoryPageSourceAdapter(),
        BookShopPreviewPageSourceAdapter(),
        WorldEventPageSourceAdapter(),
        RestPageSourceAdapter(),
        MoodPageSourceAdapter(),
        DiaryPageSourceAdapter(),
        SouvenirPageSourceAdapter(),
        BookOfYouPageSourceAdapter(),
        BookRememberedPageSourceAdapter(),
        BookConnectionsPageSourceAdapter(),
        BookNoticesPageSourceAdapter(),
        TheBleedPageSourceAdapter(),
        AskTheBookPageSourceAdapter(),
        BodyPageSourceAdapter(),
        FuelLogPageSourceAdapter(),
        FacultyResearchPageSourceAdapter(),
        CharacterLetterPageSourceAdapter(),
        SupportGuildPageSourceAdapter(),
        InkrestOfficeHoursPageSourceAdapter(),
        FaeBargainPageSourceAdapter(),
        BookFaePageSourceAdapter(),
        PactDispatchPageSourceAdapter(),
        FestivalPageSourceAdapter(),
        TodaysSkyPageSourceAdapter(),
        RadioPageSourceAdapter(),
        BookJumpPageSourceAdapter(),
        TwoReadingsPageSourceAdapter(),
        CastBondPageSourceAdapter(),
        GlowInvitationPageSourceAdapter(),
        WeatherPageSourceAdapter(),
        EnchantmentPageSourceAdapter(),
        LabyrinthWelcomePageSourceAdapter(),
        FirstDoorOriginPageSourceAdapter(),
        LocalBrainAwakePageSourceAdapter(),
        FirstDoorApprenticeshipPageSourceAdapter(),
        AcademyClassPageSourceAdapter(),
        ElectivePageSourceAdapter(),
        GamePageSourceAdapter(),
        PackPageSourceAdapter(),
        CalendarPageSourceAdapter(),
        QuipPageSourceAdapter(),
        AboutYouPageSourceAdapter(),
        WonderCompassPageSourceAdapter(),
        EnchantifyLorePageSourceAdapter(),
        HelpTipsPageSourceAdapter(),
        PatreonPageSourceAdapter(),
        LabyrinthIllustrationPageSourceAdapter(),
        IlluminatedPhotoPageSourceAdapter(),
        NarrativeOSPageSourceAdapter(),
        MarginsAtlasPageSourceAdapter(),
        GossipPageSourceAdapter(),
        CastIllustrationPageSourceAdapter(),
        OuterStacksAnchorPageSourceAdapter(),
        LocationPageSourceAdapter()
    ]

    static func adapter(for type: BookPageType) -> BookPageSourceAdapter? {
        active.first { $0.source.type == type }
    }

    static func manualSurface(
        for type: BookPageType,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        if let adapter = adapter(for: type) {
            return adapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        }
        let source = BookPageSourceRegistry.source(for: type)
        return SurfacePage(
            id: "manual-\(type.rawValue)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: type,
            sourceID: source.id,
            intent: nil,
            renderStyle: .promptCard,
            score: 58,
            reason: "Opened directly from the Glow menu.",
            prompt: source.title,
            detail: source.note,
            payload: BookPagePayload(
                headline: source.title,
                body: source.note,
                metadata: [
                    "source": source.id,
                    "placeholder": "Write what this page needs to keep.",
                    "tags": "manual-page,\(type.rawValue)"
                ]
            )
        )
    }
}

struct GamePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .gamePage)

    private let nothingPhrases = [
        "fine", "whatever", "later", "normal", "busy", "stuff", "things",
        "same as always", "nothing much", "maybe tomorrow", "just tired", "it was okay"
    ]

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let days = inputs.days + [day]
        let phrases = archivePhrases(from: days)
        guard phrases.count >= 6 else { return [] }
        let hour = Calendar.current.component(.hour, from: now)
        let score = hour >= 17 ? 64 : 54
        return [surface(phrases: phrases, greyPool: nothingPool(from: days), day: day, now: now, score: score)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let days = inputs.days + [day]
        let phrases = archivePhrases(from: days)
        return surface(phrases: phrases, greyPool: nothingPool(from: days), day: day, now: now, score: phrases.count >= 6 ? 62 : 46)
    }

    private func surface(phrases: [(phrase: String, pageID: String, date: Date, label: String)], greyPool: [String], day: BookDay, now: Date, score: Int) -> SurfacePage {
        let slotID = SurfaceCadence.slotID(for: now, hours: 6)
        let seed = "\(day.id)-\(slotID)-sentence-runner"
        let sourceMap = Dictionary(
            phrases.map { ($0.phrase, (id: $0.pageID, date: $0.date, label: $0.label)) },
            uniquingKeysWith: { first, _ in first }
        )
        let selected = deterministicPick(phrases.map(\.phrase), count: 12, seed: seed)
        let grey = deterministicPick(greyPool.isEmpty ? nothingPhrases : greyPool, count: 6, seed: "\(seed)-nothing")
        // Sidecar: phrase¶pageID¶unixTimestamp¶pageTypeTitle — lets the result page
        // open the exact source page in a modal, dated.
        let sources = selected.compactMap { phrase -> String? in
            guard let s = sourceMap[phrase] else { return nil }
            return "\(phrase)¶\(s.id)¶\(s.date.timeIntervalSince1970)¶\(s.label)"
        }
        let ready = selected.count >= 6
        return SurfacePage(
            id: "\(source.id)-sentence-runner-\(slotID)",
            type: .gamePage,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: ready ? score : 42,
            reason: ready
                ? "The Loom has loosened kept words into motion."
                : "The Loom is waiting for a few more kept sentences before it can run.",
            prompt: "The Sentence Runner",
            detail: "Jump through words from your own archive. Avoid the Nothing's grey phrases. Keep what the run makes.",
            payload: BookPagePayload(
                headline: ready ? "Your old words are moving again." : "The Loom Needs More Thread",
                body: ready
                    ? "The Loom has pulled phrases from kept pages and set them moving across the margin. Catch the words that still feel alive. Let the grey ones pass if you can."
                    : "Keep a few more real sentences, then come back. Game Pages use your archive as their level design.",
                metadata: [
                    "source": source.id,
                    "gameID": "sentence-runner",
                    "gameTitle": "The Sentence Runner",
                    "gamePhrases": selected.joined(separator: "||"),
                    "nothingPhrases": grey.joined(separator: "||"),
                    "phraseSources": sources.joined(separator: "||"),
                    "placeholder": ready ? "Run the margin, then keep the result." : "Keep more pages first.",
                    "tags": "game-page,sentence-runner,loom-run,nothing-words"
                ]
            )
        )
    }

    private func archivePhrases(from days: [BookDay]) -> [(phrase: String, pageID: String, date: Date, label: String)] {
        let pages = days
            .flatMap(\.pages)
            .sorted { $0.createdAt > $1.createdAt }
        var seen = Set<String>()
        return pages.flatMap { page in
            phraseCandidates(from: page).map { (phrase: $0, pageID: page.id, date: page.createdAt, label: page.type.title) }
        }
        .filter { seen.insert($0.phrase.lowercased()).inserted }
    }

    /// The Nothing speaks in the reader's own flat words when it can: prefer the
    /// generic phrases that actually appear in the archive, else fall back to the
    /// fixed lexicon so a thin archive still has grey to avoid.
    private func nothingPool(from days: [BookDay]) -> [String] {
        let text = days
            .flatMap(\.pages)
            .map { "\($0.userInput) \($0.promptText)".lowercased() }
            .joined(separator: " ")
        let personal = nothingPhrases.filter { text.contains($0) }
        return personal.count >= 6 ? personal : Array(Set(personal + nothingPhrases))
    }

    private func phraseCandidates(from page: BookPage) -> [String] {
        let raw = [
            page.userInput,
            page.promptText,
            page.type.title,
            page.tags
                .filter { !$0.contains(":") && !$0.contains("-") }
                .prefix(4)
                .joined(separator: " ")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")

        return raw
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { sentence -> [String] in
                let words = sentence
                    .split(separator: " ")
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                    .filter { $0.count > 2 }
                if sentence.count <= 52, words.count >= 2 {
                    return [sentence]
                }
                if words.count >= 4 {
                    return [words.prefix(4).joined(separator: " ")]
                }
                return []
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { phrase in
                let wordCount = phrase.split(separator: " ").count
                return (1...7).contains(wordCount) && phrase.count >= 3 && phrase.count <= 64
            }
    }

    private func deterministicPick(_ values: [String], count: Int, seed: String) -> [String] {
        guard !values.isEmpty else { return [] }
        return values
            .sorted {
                "\($0)-\(seed)".stableHash < "\($1)-\(seed)".stableHash
            }
            .prefix(count)
            .map { $0 }
    }
}

struct PackPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .packPage)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let hour = Calendar.current.component(.hour, from: now)
        return PageArchetypePackRegistry.archetypes().compactMap { archetype in
            if let activeHours = archetype.activeHours, !activeHours.contains(hour) {
                return nil
            }
            return surface(for: archetype, day: day, inputs: inputs, context: context, now: now)
        }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let archetypes = PageArchetypePackRegistry.archetypes()
        guard !archetypes.isEmpty else {
            return SurfacePage(
                id: "\(source.id)-empty-\(Int(now.timeIntervalSince1970))",
                type: .packPage,
                sourceID: source.id,
                prompt: "No Page Packs installed",
                detail: "Drop a \(PageArchetypePackRegistry.userPackFileSuffix) file into the app's Documents folder and its pages appear here.",
                payload: BookPagePayload(
                    headline: "Installed Page Packs",
                    body: "The shelf for installed Page Packs is empty beyond the bundled pages.",
                    metadata: ["source": source.id]
                )
            )
        }
        let slot = abs("\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 2))-pack".stableHash)
        let archetype = archetypes[slot % archetypes.count]
        return surface(for: archetype, day: day, inputs: inputs, context: CuratorContext.make(for: day), now: now)
    }

    private func surface(
        for archetype: PageArchetype,
        day: BookDay,
        inputs: BookSourceInputs,
        context: CuratorContext,
        now: Date
    ) -> SurfacePage {
        var metadata: [String: String] = [
            "source": source.id,
            "packArchetypeID": archetype.id,
            "symbol": archetype.symbolName,
            "tags": (["pack-page", archetype.id] + archetype.tags).joined(separator: ",")
        ]
        if let generation = archetype.generation {
            metadata["packPrompt"] = PageTemplateRenderer.render(generation.promptTemplate, day: day, inputs: inputs, now: now)
            metadata["packInstructions"] = generation.instructions
            metadata["packMaxTokens"] = "\(generation.maxTokens)"
        }
        return SurfacePage(
            id: "\(source.id)-\(archetype.id)-\(SurfaceCadence.slotID(for: now, hours: archetype.cadenceHours))",
            type: .packPage,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: archetype.renderStyle,
            score: context.distress.isActive ? min(archetype.score, 44) : archetype.score,
            reason: archetype.reason,
            prompt: archetype.title,
            detail: archetype.detail,
            payload: BookPagePayload(
                headline: archetype.headline,
                body: PageTemplateRenderer.render(archetype.bodyTemplate, day: day, inputs: inputs, now: now),
                metadata: metadata
            )
        )
    }
}

struct CalendarPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .calendar)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !inputs.calendarEvents.isEmpty else { return [] }
        var pages: [SurfacePage] = []
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        // If a Talisman holds the Calendar Door (Controlled+), it recolors the
        // Hour Page's question in its Chapter's voice.
        let doorController = inputs.pactWar.tier(of: "integ-calendar") >= .controlled
            ? inputs.pactWar.controller(of: "integ-calendar")
            : nil

        // Hour Page: one folded corner per approaching or recently finished event.
        for event in inputs.calendarEvents where !event.isAllDay {
            let minutesToStart = Int(event.startsAt.timeIntervalSince(now) / 60)
            let eventEnd = event.endsAt ?? event.startsAt.addingTimeInterval(60 * 60)
            let minutesAfterEnd = Int(now.timeIntervalSince(eventEnd) / 60)
            let timeLabel = formatter.string(from: event.startsAt)
            if (0...45).contains(minutesToStart) {
                pages.append(hourPage(
                    event: event,
                    phase: "before",
                    phaseTitle: "Before the Hour",
                    headline: "An Hour Approaches",
                    prompt: PactVoices.hourQuestion(controller: doorController, phase: "before") ?? beforePrompt(for: event, now: now),
                    support: beforeSupportTip(for: event, now: now),
                    body: "Something is inked at \(timeLabel): \(event.title).\n\nThe Book folds a corner here so the hour does not have to ambush you. Let the next few minutes become a little porch before the door.",
                    reason: "A real hour is inked \(minutesToStart) minute\(minutesToStart == 1 ? "" : "s") from now.",
                    score: 86,
                    timeLabel: timeLabel,
                    now: now
                ))
            } else if (30...75).contains(minutesAfterEnd) {
                pages.append(hourPage(
                    event: event,
                    phase: "after",
                    phaseTitle: "After the Hour",
                    headline: "An Hour Has Landed",
                    prompt: PactVoices.hourQuestion(controller: doorController, phase: "after") ?? afterPrompt(for: event, now: now),
                    support: afterSupportTip(for: event, now: now),
                    body: "The inked hour has passed: \(event.title).\n\nThe Book is not grading it. It is only holding out a clean margin and asking what single true sentence might be worth keeping.",
                    reason: "A real hour ended \(minutesAfterEnd) minute\(minutesAfterEnd == 1 ? "" : "s") ago.",
                    score: 82,
                    timeLabel: timeLabel,
                    now: now
                ))
            }
        }

        // Morning ledger of the day's hinges.
        let hour = Calendar.current.component(.hour, from: now)
        let todays = inputs.calendarEvents.filter {
            Calendar.current.isDate($0.startsAt, inSameDayAs: now) && !$0.isAllDay && $0.startsAt > now
        }
        if (6..<10).contains(hour), todays.count >= 1 {
            let lines = todays
                .sorted { $0.startsAt < $1.startsAt }
                .prefix(6)
                .map { "• \(formatter.string(from: $0.startsAt)) — \($0.title)" }
                .joined(separator: "\n")
            pages.append(SurfacePage(
                id: "\(source.id)-ledger-\(day.id)",
                type: .calendar,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70,
                reason: "The day already has \(todays.count) hinge\(todays.count == 1 ? "" : "s") inked.",
                prompt: "Today's Hinges",
                detail: "\(todays.count) inked hour\(todays.count == 1 ? "" : "s") ahead.",
                payload: BookPagePayload(
                    headline: "Today's Hinges",
                    body: "The day turns on these hours:\n\n\(lines)\n\nEverything between them is margin — yours.",
                    metadata: [
                        "source": source.id,
                        "privacy": "calendar stays on device",
                        "tags": "calendar,ledger,real-day"
                    ]
                )
            ))
        }
        return pages
    }

    private func hourPage(
        event: CalendarEventSignal,
        phase: String,
        phaseTitle: String,
        headline: String,
        prompt: String,
        support: String,
        body: String,
        reason: String,
        score: Int,
        timeLabel: String,
        now: Date
    ) -> SurfacePage {
        let placeholder: String
        let detail: String
        let tags: String
        if phase == "after" {
            placeholder = "One sentence from this hour..."
            detail = "The hour has passed. Keep one sentence, or simply let the Book know how it went."
            tags = "calendar,hour-page,after-event,one-sentence-souvenir,real-day"
        } else {
            placeholder = "Before this hour, I want to remember..."
            detail = "A calendar hinge is near. The Book has one question and one small support spell."
            tags = "calendar,hour-page,before-event,hinge,real-day"
        }

        return SurfacePage(
            id: "\(source.id)-\(phase)-\(event.id)-\(SurfaceCadence.minuteSlotID(for: now, minutes: 30))",
            type: .calendar,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: score,
            reason: reason,
            prompt: "Hour Page: \(timeLabel)",
            detail: detail,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "eventID": event.id,
                    "eventTitle": event.title,
                    "eventTime": timeLabel,
                    "hourPhase": phase,
                    "hourPhaseTitle": phaseTitle,
                    "hourQuestion": prompt,
                    "hourSupportTip": support,
                    "placeholder": placeholder,
                    "privacy": "calendar stays on device",
                    "tags": tags
                ]
            )
        )
    }

    private func beforePrompt(for event: CalendarEventSignal, now: Date) -> String {
        let prompts = [
            "What does this hour mean for you?",
            "What would help you enter this hour with one less knot in your pocket?",
            "What is the smallest kind thing you can do for Future You before this begins?",
            "What part of you is going with you into this appointment?",
            "If this hour had a little lantern, what would it be lighting?"
        ]
        return rotating(prompts, event: event, now: now)
    }

    private func afterPrompt(for event: CalendarEventSignal, now: Date) -> String {
        let prompts = [
            "How did the hour actually go?",
            "What one sentence would keep this from becoming a blur?",
            "What did you learn, notice, survive, finish, or feel?",
            "What should the Book remember about this hour?",
            "What tiny souvenir did the hour leave behind?"
        ]
        return rotating(prompts, event: event, now: now)
    }

    private func beforeSupportTip(for event: CalendarEventSignal, now: Date) -> String {
        let tips = [
            "Check the practical spell: keys, wallet, water, meds, address, and ten quiet seconds.",
            "Give the hour a landing strip. Decide the first action before you arrive.",
            "Let the body vote too: unclench your jaw, lower your shoulders, breathe once like you mean it.",
            "If this is social, choose one honest sentence you can say if words get crowded.",
            "Arrive as a person, not a performance. The Book is absurdly firm about this."
        ]
        return rotating(tips, event: event, now: now, salt: "support")
    }

    private func afterSupportTip(for event: CalendarEventSignal, now: Date) -> String {
        let tips = [
            "Before the next thing eats this one, write one sentence. Not the whole report. One sentence.",
            "If it went badly, keep the smallest true fact first. The Book does not require a moral yet.",
            "Drink water if you forgot to be a mammal during the event. This is ancient scholarship.",
            "Name the next tiny action while the hour is still warm.",
            "If you made it through, that counts. Put that in the margin without apologizing."
        ]
        return rotating(tips, event: event, now: now, salt: "support")
    }

    private func rotating(_ values: [String], event: CalendarEventSignal, now: Date, salt: String = "question") -> String {
        guard !values.isEmpty else { return "" }
        let slot = SurfaceCadence.minuteSlotID(for: now, minutes: 30)
        let index = abs("\(event.id)-\(slot)-\(salt)".stableHash) % values.count
        return values[index]
    }
}

struct RadioPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .radio)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let hour = Calendar.current.component(.hour, from: now)
        let shouldRise = inputs.radio.isTuned
            || day.capturedPages.contains { $0.tags.contains("music") || $0.tags.contains("radio") }
            || [8, 13, 19, 22].contains(hour)
        guard shouldRise else { return [] }
        return [surface(day: day, inputs: inputs, now: now, manual: false)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(day: day, inputs: inputs, now: now, manual: true)
    }

    private func surface(day: BookDay, inputs: BookSourceInputs, now: Date, manual: Bool) -> SurfacePage {
        let stations = RadioStationRegistry.stations(unlockedPackIDs: inputs.ownedPackIDs)
        let tuned = RadioStationRegistry.station(id: inputs.radio.activeStationID, unlockedPackIDs: inputs.ownedPackIDs)
            ?? stations.first
        let station = tuned ?? RadioStationRegistry.coreStations[0]
        let isTuned = inputs.radio.activeStationID != nil
        let stationLines = stations
            .map { station in
                let trackHint = station.tracks.compactMap(\.assetName).first.map { " asset: \($0)" } ?? ""
                return "\(station.displayFrequency) - \(station.title): \(station.subtitle)\(trackHint)"
            }
            .joined(separator: "\n")
        let effects = station.effects
            .map { "\($0.pageType.shortTitle) +\($0.boost)" }
            .joined(separator: ", ")
        let interlude = RadioStationRegistry.currentInterlude(
            state: inputs.radio,
            unlockedPackIDs: inputs.ownedPackIDs,
            now: now
        )
        let body: String
        if isTuned {
            body = """
            The receiver is tuned to \(station.displayFrequency): \(station.title).

            \(station.signalLine)

            \(interlude.map { "Broadcast interruption: \($0)\n\n" } ?? "")While this station plays, the Book listens through it. Its signal leans toward: \(effects). Drop local tracks whose names match the station asset names into Documents/Radio, or bundle them with the app, and the dial will play them instead of its procedural bed.

            Core frequencies now on the dial:
            \(stationLines)
            """
        } else {
            body = """
            The receiver wakes with a click under the thumb. Three Academy stations are already close enough to find:

            \(stationLines)

            Tune one and the Book will keep hearing it after this page closes. The music is not decoration. It becomes weather in the stacks. Station packs use \(RadioStationRegistry.userPackFileSuffix) manifests, so new frequencies can arrive as local content.
            """
        }
        var metadata: [String: String] = [
            "source": source.id,
            "radioStationID": station.id,
            "radioStationTitle": station.title,
            "radioFrequency": station.displayFrequency,
            "radioSignal": station.signalLine,
            "radioEffects": effects,
            "radioInterlude": interlude ?? "",
            "radioStationCount": "\(stations.count)",
            "placeholder": "What was the music doing to the room?",
            "tags": "radio,music,academy-station,ambient-signal"
        ]
        if let packID = station.packID {
            metadata["radioPackID"] = packID
        }
        if let host = station.hostEntityID {
            metadata["radioHostEntityID"] = host
        }
        return SurfacePage(
            id: "\(source.id)-\(station.id)-\(manual ? "manual" : SurfaceCadence.slotID(for: now, hours: 6))",
            type: .radio,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: manual ? 80 : (isTuned ? 66 : 54),
            reason: isTuned ? "\(station.title) is tinting the margins." : "The Academy radio dial is waiting to be tuned.",
            prompt: isTuned ? "\(station.displayFrequency) \(station.title)" : "ReEnchanted Radio",
            detail: isTuned ? station.subtitle : "An analog station page for Academy broadcasts, music packs, and world effects.",
            payload: BookPagePayload(
                headline: isTuned ? "The Signal Holds" : "The Dial Wakes",
                body: body,
                metadata: metadata
            )
        )
    }
}
