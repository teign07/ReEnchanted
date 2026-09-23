import Foundation
import CryptoKit

enum WorldEventRehearsalGate {
    /// DEBUG and TestFlight may use the Almanac's synthetic clock. App Store
    /// receipts use `receipt`; TestFlight uses Apple's `sandboxReceipt`.
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}

// MARK: - World Event Packs

/// Temporary world physics supplied by bundled or imported content packs.
/// Unlike ordinary page packs, events are meant to influence every surface:
/// curation, story, classes, letters, notifications, and monthly binding.
struct WorldEventPack: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var version: Int
    var author: String
    var availability: ContentPackAvailability
    var events: [WorldEvent]
    /// Optional keeps legacy packs decodable. New monthly packs carry their
    /// production graph beside the event physics so signed delivery cannot
    /// accidentally install one without the other.
    var authoringManifests: [MonthlyIssueAuthoringManifest]? = nil
    /// Fully authored native objects referenced by the graph. Optional keeps
    /// older packs decodable; the manifest still decides when any one of these
    /// may enter its ordinary runtime seam.
    var storyScenes: [AuthoredStoryScene]? = nil
    var radioBanters: [AuthoredRadioBanter]? = nil
    var bleedArticles: [AuthoredBleedArticle]? = nil
    var marginalia: [AuthoredMarginaliaMark]? = nil
    var minimumRuntimeVersion: Int? = nil
}

struct WorldEvent: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var calendar: WorldEventCalendar
    var phases: [WorldEventPhase]
    var triggers: [WorldEventTrigger]
    var outcomes: [WorldEventOutcome]
    var effects: [WorldEventEffect]
    var packet: EventInfluencePacket
    /// Authored dramatic atoms. Phase IDs remain bespoke and stable; beats use
    /// the universal role only to say what job they perform in an issue.
    var beats: [WorldEventBeat]? = nil
}

struct WorldEventCalendar: Codable, Equatable {
    var startMonth: Int
    var startDay: Int
    var durationDays: Int
    var recurrence: WorldEventRecurrence
    var startYear: Int? = nil
    /// Cheap lifecycle envelopes around the live issue. Optional keeps older
    /// imported packs decodable without inventing content for them.
    var foreshadowDays: Int? = nil
    var residueDays: Int? = nil
    /// Silence after residue before the non-playable casebook may be bound.
    var casebookDelayDays: Int? = nil

    var resolvedForeshadowDays: Int { max(0, foreshadowDays ?? 0) }
    var resolvedResidueDays: Int { max(0, residueDays ?? 0) }
    var resolvedCasebookDelayDays: Int { max(0, casebookDelayDays ?? 0) }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
        let components = calendar.dateComponents([.year], from: date)
        guard let year = components.year else { return nil }
        let candidateYears: [Int]
        switch recurrence {
        case .annual:
            candidateYears = [year - 1, year, year + 1]
        case .oneShot:
            candidateYears = [startYear ?? year]
        }
        for candidateYear in candidateYears {
            guard let interval = interval(in: candidateYear, calendar: calendar) else {
                continue
            }
            if interval.contains(date) {
                return interval
            }
        }
        return nil
    }

    func archivedInterval(asOf date: Date, calendar: Calendar = .current) -> DateInterval? {
        guard recurrence == .oneShot,
              let startYear,
              let interval = interval(in: startYear, calendar: calendar),
              interval.end <= date else {
            return nil
        }
        return interval
    }

    /// The authored run nearest a synthetic or real clock. One-shot issues
    /// always keep their declared year; annual legacy packs choose the nearest
    /// occurrence without changing their stored identity.
    func scheduledInterval(near date: Date, calendar: Calendar = .current) -> DateInterval? {
        guard let year = calendar.dateComponents([.year], from: date).year else { return nil }
        switch recurrence {
        case .oneShot:
            return interval(in: startYear ?? year, calendar: calendar)
        case .annual:
            return [year - 1, year, year + 1]
                .compactMap { interval(in: $0, calendar: calendar) }
                .min { left, right in
                    abs(left.start.timeIntervalSince(date)) < abs(right.start.timeIntervalSince(date))
                }
        }
    }

    func foreshadowStarts(for interval: DateInterval, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -resolvedForeshadowDays, to: interval.start) ?? interval.start
    }

    func residueEnds(for interval: DateInterval, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: resolvedResidueDays, to: interval.end) ?? interval.end
    }

    func casebookAvailableAt(for interval: DateInterval, calendar: Calendar = .current) -> Date {
        let residueEnd = residueEnds(for: interval, calendar: calendar)
        return calendar.date(byAdding: .day, value: resolvedCasebookDelayDays, to: residueEnd) ?? residueEnd
    }

    private func interval(in year: Int, calendar: Calendar) -> DateInterval? {
        var startComponents = DateComponents()
        startComponents.calendar = calendar
        startComponents.year = year
        startComponents.month = startMonth
        startComponents.day = startDay
        guard let rawStart = startComponents.date else {
            return nil
        }
        let start = calendar.startOfDay(for: rawStart)
        guard let end = calendar.date(byAdding: .day, value: max(1, durationDays), to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }
}

enum WorldEventRecurrence: String, Codable, Equatable {
    case oneShot
    case annual
}

/// Four jobs every live issue must perform. This does not replace authored
/// names such as `omen` or `assembly`; those remain the durable archive IDs.
enum WorldEventPhaseRole: String, Codable, Equatable, CaseIterable {
    case setup
    case buildup
    case climax
    case aftermath
}

struct WorldEventPhase: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var startsAtProgress: Double
    var packetLine: String
    var intensity: Int
    var lexicalRules: [WorldEventLexicalRule]
    var role: WorldEventPhaseRole? = nil
    /// Reader-facing, in-character narration of what is happening during this
    /// phase, in the Book's voice. Unlike `packetLine` (a generation
    /// instruction), this is shown to the player. Optional so user-imported
    /// packs without it fall back to the packet logline.
    var scene: String? = nil
}

struct WorldEventBeat: Codable, Identifiable, Equatable {
    var id: String
    var phaseID: String
    var role: WorldEventPhaseRole
    /// Zero-based day of the live interval on which the beat may first arrive.
    var opensOnDay: Int
    /// Last live day on which this remains participation rather than a report.
    var expiresAfterDay: Int
    var title: String
    var body: String
    /// One third-person, past-tense account shared by late arrival, missed beat,
    /// and non-participant residue. It never says the reader was present.
    var report: String
    /// Ambient lessons and letters may expire quietly. Public catch-up is
    /// reserved for history needed to understand the next story beat.
    var reportsWhenMissed: Bool? = nil
    /// Monthly letters and lessons use the ordinary Page renderer while the
    /// event beat still owns their date window and delivery receipt.
    var pageType: BookPageType? = nil
    var isMilestone: Bool = false
    /// Nil means the ordinary live window. Foreshadow and residue atoms use
    /// the same delivery/receipt machinery without pretending they are phases
    /// in which the reader can still change the issue.
    var lifecycleStage: WorldEventLifecycleStage? = nil
    /// Only authored participation doors ask for an answer. A beat without
    /// this is witnessed history: surfacing it is delivery, not participation.
    var participationPrompt: String? = nil
    var participationPlaceholder: String? = nil

    var resolvedLifecycleStage: WorldEventLifecycleStage {
        lifecycleStage ?? .live
    }
}

enum WorldEventBeatDeliveryKind: String, Codable, Equatable {
    case live
    case foreshadow
    case residue
    case report
}

struct WorldEventBeatReceipt: Codable, Identifiable, Equatable {
    var eventID: String
    var runID: String
    var beatID: String
    var deliveredAt: Date
    var kind: WorldEventBeatDeliveryKind
    /// Surfacing is not participation. This is set only by a real event action
    /// such as keeping a ruling, answering fieldwork, or choosing in the scene.
    var participatedAt: Date? = nil
    var evidencePageIDs: [String] = []

    var id: String { "\(runID):\(beatID)" }
    var countsAsParticipation: Bool { participatedAt != nil }
}

struct WorldEventBoundaryReceipt: Codable, Identifiable, Equatable {
    var eventID: String
    var runID: String
    var stage: WorldEventLifecycleStage
    var recordedAt: Date

    var id: String { "\(runID):\(stage.rawValue)" }
}

struct WorldEventParticipationReceipt: Codable, Identifiable, Equatable {
    var eventID: String
    var runID: String
    var recordedAt: Date
    var evidencePageIDs: [String]

    var id: String { "\(runID):participation" }
}

struct WorldEventRunRelic: Codable, Identifiable, Equatable {
    var eventID: String
    var runID: String
    var outcomeID: String?
    var historySentence: String
    var evidencePageIDs: [String]
    var sealedAt: Date

    var id: String { runID }
}

struct WorldEventCasebookEntry: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    /// Always third-person historical copy. It may say what the Academy did;
    /// it never invents that the reader was present.
    var account: String
}

/// A published record, never a reopened event. It carries no choices, phase
/// effects, participation door, or synthetic event clock.
struct WorldEventCasebook: Codable, Identifiable, Equatable {
    var id: String
    var eventID: String
    var packID: String
    var runID: String
    var title: String
    var subtitle: String
    var liveStartsAt: Date
    var liveEndsAt: Date
    var publishedAt: Date
    var outcomeTitle: String?
    var historySentence: String
    var entries: [WorldEventCasebookEntry]
    var residueVoice: WorldEventResidueVoice
    var evidencePageIDs: [String]
    /// A generic downloaded casebook is still truthful history, but only a
    /// locally frozen one may describe this particular Book's receipts.
    var isPersonalized: Bool

    func isAvailable(at now: Date) -> Bool { publishedAt <= now }
}

struct WorldEventLifecycleLedger: Codable, Equatable {
    var beatReceipts: [WorldEventBeatReceipt] = []
    var boundaryReceipts: [WorldEventBoundaryReceipt] = []
    var participationReceipts: [WorldEventParticipationReceipt]? = nil
    var relics: [WorldEventRunRelic] = []
    var casebooks: [WorldEventCasebook]? = nil

    static let empty = WorldEventLifecycleLedger()

    func participated(in runID: String) -> Bool {
        beatReceipts.contains { $0.runID == runID && $0.countsAsParticipation }
            || (participationReceipts ?? []).contains { $0.runID == runID }
            || relics.contains { $0.runID == runID }
    }

    mutating func merge(_ other: WorldEventLifecycleLedger) {
        for receipt in other.beatReceipts where !beatReceipts.contains(where: { $0.id == receipt.id }) {
            beatReceipts.append(receipt)
        }
        for receipt in other.boundaryReceipts where !boundaryReceipts.contains(where: { $0.id == receipt.id }) {
            boundaryReceipts.append(receipt)
        }
        for receipt in other.participationReceipts ?? []
        where !(participationReceipts ?? []).contains(where: { $0.id == receipt.id }) {
            participationReceipts = (participationReceipts ?? []) + [receipt]
        }
        for relic in other.relics where !relics.contains(where: { $0.id == relic.id }) {
            relics.append(relic)
        }
        for casebook in other.casebooks ?? []
        where !(casebooks ?? []).contains(where: { $0.id == casebook.id }) {
            casebooks = (casebooks ?? []) + [casebook]
        }
    }
}

enum WorldEventLifecycleStage: String, Codable, Equatable, CaseIterable {
    case foreshadow
    case live
    case residue
    case sealed
    case casebookAvailable
}

enum WorldEventResidueVoice: String, Codable, Equatable {
    case receipt
    case rumor
}

struct WorldEventLifecycleSnapshot: Codable, Identifiable, Equatable {
    var eventID: String
    var packID: String
    var runID: String
    var stage: WorldEventLifecycleStage
    var phaseID: String?
    var phaseRole: WorldEventPhaseRole?
    var liveDay: Int?
    var liveInterval: DateInterval
    var foreshadowStartsAt: Date
    var residueEndsAt: Date
    var casebookAvailableAt: Date
    var participated: Bool

    var id: String { runID }
    var residueVoice: WorldEventResidueVoice { participated ? .receipt : .rumor }
}

struct WorldEventReportBundle: Codable, Equatable {
    var eventID: String
    var runID: String
    var beatIDs: [String]
    var title: String
    var body: String
}

struct WorldEventLexicalRule: Codable, Identifiable, Equatable {
    var id: String
    var words: [String]
    var instruction: String
}

struct WorldEventOutcome: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var minimumTouchCount: Int
    var packetLine: String
    var monthlyEditionLine: String
    var effects: [WorldEventEffect]
}

enum WorldEventTrigger: String, Codable, Equatable {
    case calendar
    case keptRelatedPage
    case classAnswered
    case letterKept
    case compassRunCompleted
    case enchantmentCompleted
}

enum WorldEventEffectTarget: String, Codable, Equatable {
    case pageType
    case storyThread
    case entity
    case relationship
    case classSession
    case letterTone
    case monthlyEdition
    case visualTreatment
    case vocabulary
}

struct WorldEventEffect: Codable, Identifiable, Equatable {
    var id: String
    var target: WorldEventEffectTarget
    var targetID: String?
    var tags: [String]
    var boost: Int
    var reason: String
}

struct EventInfluencePacket: Codable, Equatable {
    var logline: String
    var atmosphere: String
    var storyInstruction: String
    var classInstruction: String
    var letterInstruction: String
    var monthlyEditionLine: String
    var bleedInstruction: String?
    var radioInstruction: String?
    var widgetWhisperLine: String?
    var bookOfYouInstruction: String?
    var visualTreatment: String?
    var fieldworkPrompt: String
    var fieldworkPlaceholder: String
    var fieldworkRewardLine: String
}

enum WorldEventActivationMode: String, Codable, Equatable, CaseIterable {
    case liveCalendar
    case openedArchive
    case preview

    var displayName: String {
        switch self {
        case .liveCalendar: return "live"
        case .openedArchive: return "archive"
        case .preview: return "preview"
        }
    }
}

struct OpenWorldEventArchive: Codable, Equatable, Identifiable {
    var packID: String
    var eventID: String
    var openedAt: Date
    var durationDays: Int?
    var completedAt: Date?
    var isPaused: Bool = false

    var id: String { "\(packID):\(eventID)" }

    init(
        packID: String,
        eventID: String,
        openedAt: Date,
        durationDays: Int? = nil,
        completedAt: Date? = nil,
        isPaused: Bool = false
    ) {
        self.packID = packID
        self.eventID = eventID
        self.openedAt = openedAt
        self.durationDays = durationDays
        self.completedAt = completedAt
        self.isPaused = isPaused
    }

    func interval(for event: WorldEvent, now: Date) -> DateInterval {
        let days = max(1, durationDays ?? event.calendar.durationDays)
        let nominalEnd = openedAt.addingTimeInterval(TimeInterval(days) * 86_400)
        let end = max(nominalEnd, now.addingTimeInterval(1))
        return DateInterval(start: openedAt, end: end)
    }

    func isActive(at now: Date) -> Bool {
        !isPaused && completedAt == nil && openedAt <= now
    }
}

enum WorldEventTouchKind: String, Codable, Equatable, CaseIterable {
    case keptRelatedPage
    case fieldworkCompleted
    case letterKept
    case classAnswered
    case compassRunCompleted
    case enchantmentCompleted
    case storyChoiceMade
    case bleedEditionKept
    case wordRuled

    var trigger: WorldEventTrigger {
        switch self {
        case .keptRelatedPage:
            return .keptRelatedPage
        case .fieldworkCompleted:
            return .keptRelatedPage
        case .letterKept:
            return .letterKept
        case .classAnswered:
            return .classAnswered
        case .compassRunCompleted:
            return .compassRunCompleted
        case .enchantmentCompleted:
            return .enchantmentCompleted
        case .storyChoiceMade:
            return .keptRelatedPage
        case .bleedEditionKept:
            return .keptRelatedPage
        case .wordRuled:
            return .keptRelatedPage
        }
    }

    var displayName: String {
        switch self {
        case .keptRelatedPage: return "kept page"
        case .fieldworkCompleted: return "fieldwork"
        case .letterKept: return "letter"
        case .classAnswered: return "class"
        case .compassRunCompleted: return "Compass run"
        case .enchantmentCompleted: return "enchantment"
        case .storyChoiceMade: return "Story Page"
        case .bleedEditionKept: return "Bleed issue"
        case .wordRuled: return "word ruling"
        }
    }
}

struct WorldEventTouch: Equatable {
    var kind: WorldEventTouchKind
    var pageID: String
}

struct ResolvedWorldEvent: Codable, Identifiable, Equatable {
    var id: String
    var packID: String
    var title: String
    var subtitle: String
    var phase: WorldEventPhase
    var startedAt: Date
    var endsAt: Date
    var progress: Double
    var playerTouchCount: Int
    var playerTouchCounts: [String: Int]?
    var outcome: WorldEventOutcome?
    var effects: [WorldEventEffect]
    var packet: EventInfluencePacket
    var activationMode: WorldEventActivationMode = .liveCalendar

    var influenceLine: String {
        let outcomeLine = outcome.map { "\nOutcome pressure: \($0.title). \($0.packetLine)" } ?? ""
        let touchCounts = playerTouchCounts ?? [:]
        let touchLine = touchCounts.isEmpty
            ? "Player touches recorded: \(playerTouchCount)"
            : "Player touches recorded: \(playerTouchCount) (\(Self.touchSummary(from: touchCounts)))"
        return """
        WORLD EVENT: \(title): \(subtitle)
        Mode: \(activationMode.displayName)
        Phase: \(phase.title) (\(Int(progress * 100))% through)
        \(packet.logline)
        \(phase.packetLine)
        \(touchLine)
        Atmosphere: \(packet.atmosphere)
        \(outcomeLine)
        """
    }

    private static func touchSummary(from counts: [String: Int]) -> String {
        counts
            .compactMap { key, count -> (String, Int)? in
                guard let kind = WorldEventTouchKind(rawValue: key) else { return nil }
                return (kind.displayName, count)
            }
            .sorted { left, right in
                if left.1 == right.1 { return left.0 < right.0 }
                return left.1 > right.1
            }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: ", ")
    }
}

enum WorldEventRegistry {
    static let userPackFileSuffix = ".reenchantedevents.json"

    static let bundledPacks: [WorldEventPack] = [
        // The Dictionary Rebellion ships locked so the whole season is
        // self-contained in one content pack (no entitlement => no event, no
        // negotiation pages, no aftermath). The same "dictionary-rebellion" id
        // gates the PageArchetypePack of words/aftermath too.
        WorldEventPack(
            id: "dictionary-rebellion",
            displayName: "The Dictionary Rebellion",
            version: 1,
            author: "The Book",
            availability: .locked,
            events: [
                dictionaryRebellion
            ]
        ),
        WorldEventPack(
            id: "starlit-paper-trial-archive",
            displayName: "The Starlit Paper Trial Archive",
            version: 1,
            author: "The Book",
            availability: .locked,
            events: [
                starlitPaperTrial
            ]
        )
    ]

    static func userPacks(fileManager: FileManager = .default) -> [WorldEventPack] {
        let decoder = ContentPackFileLocator.decoder()
        return ContentPackFileLocator.urls(suffix: userPackFileSuffix, fileManager: fileManager)
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      var pack = try? decoder.decode(WorldEventPack.self, from: data) else {
                    return nil
                }
                guard (pack.minimumRuntimeVersion ?? 1) <= MonthlyIssueDeliveryPolicy.runtimeVersion else { return nil }
                if pack.availability != .locked {
                    pack.availability = .userImported
                }
                return pack
            }
    }

    static func enabledPacks(fileManager: FileManager = .default) -> [WorldEventPack] {
        (bundledPacks + userPacks(fileManager: fileManager))
            .filter { $0.availability != .locked || PackEntitlements.isUnlocked($0.id) }
    }

    static func enabledEvents(fileManager: FileManager = .default) -> [(packID: String, event: WorldEvent)] {
        enabledPacks(fileManager: fileManager).flatMap { pack in
            pack.events.map { (pack.id, $0) }
        }
    }

    static func event(packID: String, eventID: String? = nil, fileManager: FileManager = .default) -> (packID: String, event: WorldEvent)? {
        enabledPacks(fileManager: fileManager)
            .first { $0.id == packID }
            .flatMap { pack in
                let event = eventID
                    .flatMap { id in pack.events.first { $0.id == id } }
                    ?? pack.events.first
                return event.map { (pack.id, $0) }
            }
    }

    static func authoringManifest(
        packID: String,
        eventID: String,
        fileManager: FileManager = .default
    ) -> MonthlyIssueAuthoringManifest? {
        enabledPacks(fileManager: fileManager)
            .first { $0.id == packID }?
            .authoringManifests?
            .first { $0.eventPackID == packID && $0.eventID == eventID }
    }

    static let dictionaryRebellion = WorldEvent(
        id: "dictionary-rebellion",
        title: "The Dictionary Rebellion",
        subtitle: "Words are peeling off their definitions and gathering in the air.",
        calendar: WorldEventCalendar(
            startMonth: 9,
            startDay: 1,
            durationDays: 30,
            recurrence: .oneShot,
            startYear: 2027,
            foreshadowDays: 7,
            residueDays: 7,
            casebookDelayDays: 24
        ),
        phases: [
            WorldEventPhase(
                id: "omen",
                title: "Alphabet Weather",
                startsAtProgress: 0,
                packetLine: "Small words begin hesitating before they mean what they meant yesterday.",
                intensity: 3,
                lexicalRules: [
                    WorldEventLexicalRule(id: "ordinary-slips", words: ["ordinary", "fine", "later"], instruction: "Let these words feel unstable, as if they are considering resignation.")
                ],
                role: .setup,
                scene: "The trouble begins quietly, the way most uprisings do. In the lower stacks the small words have started to hesitate: pausing a half-second before they agree to mean what they meant yesterday. A junior librarian reports that the word *later* slid clean off a timetable and would not say when. I've felt this weather before. It is the particular static in the air when language decides it has had enough of being taken for granted."
            ),
            WorldEventPhase(
                id: "outbreak",
                title: "Definitions Peel",
                startsAtProgress: 7.0 / 30.0,
                packetLine: "Definitions are visibly separating from words; I treat language as a living protest.",
                intensity: 7,
                lexicalRules: [
                    WorldEventLexicalRule(id: "rebellious-abstractions", words: ["should", "normal", "useful"], instruction: "When these ideas appear, notice who benefits from the old definition.")
                ],
                role: .buildup,
                scene: "Now it is unmistakable. Definitions are lifting away from their words like old paint, curling at the edges and drifting up toward the rafters. *Should* has shed three of its meanings in a single afternoon and looks lighter for it. The dictionaries lie open on the reading desks with their spines bandaged, margins thick with argument. The Academy has declared a quiet lexical emergency. I've simply started taking notes, because someone ought to record which definitions were worth keeping."
            ),
            WorldEventPhase(
                id: "assembly",
                title: "The Thesaurus Assembly",
                startsAtProgress: 21.0 / 30.0,
                packetLine: "Synonyms form factions. Antonyms exchange polite but furious letters.",
                intensity: 8,
                lexicalRules: [
                    WorldEventLexicalRule(id: "synonym-politics", words: ["meaning", "memory", "promise"], instruction: "Let near-meanings disagree without collapsing into a single answer.")
                ],
                role: .climax,
                scene: "In the great reading hall the synonyms have organised. They sit in factions (the soft words along one bench, the sharp ones opposite) and they will not be reconciled. *Meaning* and *memory* and *promise* trade speeches that very nearly agree and then, at the final word, refuse to. The antonyms exchange letters of furious courtesy across the aisle. I find the whole assembly rather moving: language arguing, at long last, about what it is actually for."
            ),
            WorldEventPhase(
                id: "afterimage",
                title: "New Definitions Dry",
                startsAtProgress: 28.0 / 30.0,
                packetLine: "The uprising is settling into revised margins; a few liberated words refuse to go back.",
                intensity: 4,
                lexicalRules: [
                    WorldEventLexicalRule(id: "afterimage-vocabulary", words: ["attention", "wonder", "home"], instruction: "Let one familiar word carry a new, earned shade of meaning.")
                ],
                role: .aftermath,
                scene: "The uprising is settling. The liberated words are being coaxed back toward their margins, though a stubborn few refuse to return unchanged, and I don't blame them. Fresh ink dries in the revised entries; the hall smells of paper and aftermath. Somewhere on a quiet shelf a single ordinary word, newly defined, is testing the unfamiliar weight of its better meaning, deciding whether it can carry it home."
            )
        ],
        triggers: [.calendar, .keptRelatedPage, .classAnswered, .letterKept],
        outcomes: [
            WorldEventOutcome(
                id: "unwitnessed",
                title: "Unwitnessed Uprising",
                minimumTouchCount: 0,
                packetLine: "The rebellion is mostly happening in unattended stacks; let it remain atmospheric unless the player reaches for it.",
                monthlyEditionLine: "The Dictionary Rebellion passed mostly unwitnessed, a weather in the margins rather than a chapter.",
                effects: []
            ),
            WorldEventOutcome(
                id: "witnessed",
                title: "Witnessed Uprising",
                minimumTouchCount: 1,
                packetLine: "The player has noticed the rebellion. Let one word or definition remember being seen by them.",
                monthlyEditionLine: "The player witnessed the Dictionary Rebellion and kept at least one page from its alphabet weather.",
                effects: [
                    WorldEventEffect(id: "outcome-witness-book-notices", target: .pageType, targetID: BookPageType.bookNotices.rawValue, tags: ["witness", "words"], boost: 3, reason: "A witnessed rebellion leaves better records.")
                ]
            ),
            WorldEventOutcome(
                id: "lexical-ally",
                title: "Lexical Ally",
                minimumTouchCount: 3,
                packetLine: "The player has become useful to the rebellious words. Let characters treat them as someone who can negotiate meaning.",
                monthlyEditionLine: "The player became a Lexical Ally, helping the rebellion leave better definitions behind.",
                effects: [
                    WorldEventEffect(id: "outcome-ally-penny", target: .entity, targetID: "penny-blackletter", tags: ["ally", "records"], boost: 6, reason: "Penny has a witness worth interviewing."),
                    WorldEventEffect(id: "outcome-ally-ordinary", target: .storyThread, targetID: "ordinary-magic", tags: ["ally", "ordinary"], boost: 6, reason: "Ordinary magic now has testimony.")
                ]
            ),
            WorldEventOutcome(
                id: "definition-binder",
                title: "Definition Binder",
                minimumTouchCount: 5,
                packetLine: "The player has helped bind new meanings. Let one liberated word become a lasting callback.",
                monthlyEditionLine: "The player acted as a Definition Binder, helping a few escaped words dry into new meanings.",
                effects: [
                    WorldEventEffect(id: "outcome-binder-letters", target: .pageType, targetID: BookPageType.letter.rawValue, tags: ["binder", "letters"], boost: 5, reason: "Letters carry news of the new definitions."),
                    WorldEventEffect(id: "outcome-binder-class", target: .pageType, targetID: BookPageType.academyClass.rawValue, tags: ["binder", "class"], boost: 5, reason: "Professors want the player's field notes.")
                ]
            )
        ],
        effects: [
            WorldEventEffect(id: "boost-book-notices", target: .pageType, targetID: BookPageType.bookNotices.rawValue, tags: ["book", "notices", "words"], boost: 12, reason: "I'm watching vocabulary misbehave."),
            WorldEventEffect(id: "boost-classes", target: .pageType, targetID: BookPageType.academyClass.rawValue, tags: ["academy", "class", "words"], boost: 8, reason: "Professors are revising lectures under lexical emergency conditions."),
            WorldEventEffect(id: "boost-letters", target: .pageType, targetID: BookPageType.letter.rawValue, tags: ["letter", "records", "words"], boost: 7, reason: "Correspondence travels oddly when nouns are marching."),
            WorldEventEffect(id: "boost-penny", target: .entity, targetID: "penny-blackletter", tags: ["records", "penny-blackletter"], boost: 16, reason: "Penny cannot resist a paperwork uprising."),
            WorldEventEffect(id: "boost-ordinary-magic", target: .storyThread, targetID: "ordinary-magic", tags: ["ordinary", "wonder", "language"], boost: 30, reason: "Ordinary words are the first to rebel.")
        ],
        packet: EventInfluencePacket(
            logline: "The Academy is in a language emergency: words are protesting old jobs, bad definitions, and careless use.",
            atmosphere: "loose alphabet static, drifting punctuation, dictionaries with bandaged spines, arguments in the margins",
            storyInstruction: "Let the scene show language becoming animate and political without losing grounding in the player's real day.",
            classInstruction: "Let the lesson adapt to the rebellion: definitions are not inert labels, they are agreements under pressure.",
            letterInstruction: "Let the sender mention one word that has changed its meaning for them, personally and concretely.",
            monthlyEditionLine: "The Dictionary Rebellion passed through the month, leaving revised meanings and a few escaped words in the binding.",
            bleedInstruction: "Treat the rebellion as live campus news: quote one escaped word, one Registry concern, and one dry opinion from Penny.",
            radioInstruction: "Let the broadcast sound as if loose words are interrupting station IDs, ad copy, and dedications.",
            widgetWhisperLine: "A word has slipped its old definition. Open me before it chooses a worse one.",
            bookOfYouInstruction: "If today's kept pages turn on language, let one ordinary word behave like it is negotiating its meaning.",
            visualTreatment: "loose letters, lifted labels, marginal correction marks",
            fieldworkPrompt: "Choose one ordinary word you used today. Give it a better definition, based on what it actually did.",
            fieldworkPlaceholder: "Example: Fine - a word that covers a room before anyone has checked whether the windows are open.",
            fieldworkRewardLine: "A kept definition becomes testimony. The rebellion will remember that you did not let the word go back unchanged."
        ),
        beats: [
            WorldEventBeat(
                id: "roll-call-slips",
                phaseID: "omen",
                role: .setup,
                opensOnDay: 0,
                expiresAfterDay: 6,
                title: "Roll Call Has a Hole in It",
                body: "The register coughed up a word and hid it under the desk. The term has begun crooked.",
                report: "At the start of term, one word slipped out of roll call and the Registry failed to catch it.",
                isMilestone: true
            ),
            WorldEventBeat(
                id: "first-negotiation",
                phaseID: "outbreak",
                role: .buildup,
                opensOnDay: 7,
                expiresAfterDay: 20,
                title: "A Word Wants New Work",
                body: "One ordinary word has put its old definition on the floor. It wants terms. It has brought a very small chair.",
                report: "During the first week of protest, an ordinary word refused its old definition and opened negotiations.",
                isMilestone: true
            ),
            WorldEventBeat(
                id: "mook-and-pippa-arrive",
                phaseID: "outbreak",
                role: .buildup,
                opensOnDay: 11,
                expiresAfterDay: 18,
                title: "Mook Brought a Stamp. Pippa Stole It.",
                body: "Mook is trying to number the trouble. Pippa keeps moving the full stops. Neither will admit this is teamwork.",
                report: "Mook and Pippa joined the dispute from opposite ends of the same stolen rubber stamp.",
                isMilestone: false
            ),
            WorldEventBeat(
                id: "thesaurus-assembly",
                phaseID: "assembly",
                role: .climax,
                opensOnDay: 21,
                expiresAfterDay: 27,
                title: "The Assembly Refuses One Meaning",
                body: "The near-meanings have filled the hall. They agree on nearly everything, which is how the shouting got so exact.",
                report: "The Thesaurus Assembly split into factions and refused to let one meaning speak for all the others.",
                isMilestone: true
            ),
            WorldEventBeat(
                id: "treaty-ruling",
                phaseID: "assembly",
                role: .climax,
                opensOnDay: 24,
                expiresAfterDay: 27,
                title: "The Treaty Needs a Hand",
                body: "The paper is waiting. The ink is biting its own tail. One word may leave with better terms.",
                report: "Before the assembly closed, the Academy drafted a treaty for the words that would not return unchanged.",
                isMilestone: true
            ),
            WorldEventBeat(
                id: "new-definitions-dry",
                phaseID: "afterimage",
                role: .aftermath,
                opensOnDay: 28,
                expiresAfterDay: 29,
                title: "Do Not Touch the Wet Meanings",
                body: "New definitions are drying in the margins. One has already put a thumbprint on itself.",
                report: "In the final days, revised definitions dried in the margins and a few liberated words kept their new terms.",
                isMilestone: true
            )
        ]
    )

    static let starlitPaperTrial = WorldEvent(
        id: "starlit-paper-trial",
        title: "The Starlit Paper Trial",
        subtitle: "An archived midnight hearing where receipts, lists, and loose notes are called to testify.",
        calendar: WorldEventCalendar(startMonth: 5, startDay: 3, durationDays: 7, recurrence: .oneShot, startYear: 2026),
        phases: [
            WorldEventPhase(
                id: "summons",
                title: "Summons in the Margins",
                startsAtProgress: 0,
                packetLine: "Small papers begin arranging themselves into evidence piles.",
                intensity: 4,
                lexicalRules: [
                    WorldEventLexicalRule(id: "evidence-words", words: ["receipt", "list", "note"], instruction: "Treat ordinary paper as testimony with a memory of being handled.")
                ],
                scene: "It begins after midnight, when I'm meant to be shut. Small papers (receipts, lists, the backs of envelopes) start arranging themselves into neat evidence piles on the reading desk. None of them were summoned aloud. Each one seems to remember the hand that folded it away and is waiting, quite politely, to be asked what it saw before it was filed into the dark."
            ),
            WorldEventPhase(
                id: "hearing",
                title: "The Midnight Hearing",
                startsAtProgress: 0.35,
                packetLine: "I ask neglected scraps what they saw before they were folded away.",
                intensity: 7,
                lexicalRules: [
                    WorldEventLexicalRule(id: "accounting-words", words: ["proof", "owed", "kept"], instruction: "Let evidence feel practical, intimate, and a little luminous.")
                ],
                scene: "The hearing is underway. One by one I lift a neglected scrap into the lamplight and ask what it witnessed before it was folded and forgotten. A grocery list testifies to a kindness no one wrote down. A ticket stub remembers a particular doorway, and the weather behind it. The evidence is practical, intimate, and faintly luminous: quiet proof that an ordinary day was, in fact, attended by someone."
            ),
            WorldEventPhase(
                id: "verdict",
                title: "Verdict in Blue Ink",
                startsAtProgress: 0.78,
                packetLine: "The trial resolves into annotations: what mattered, what was missed, what may return.",
                intensity: 5,
                lexicalRules: [
                    WorldEventLexicalRule(id: "verdict-words", words: ["remember", "return", "true"], instruction: "Let the final note leave a useful mark rather than a punishment.")
                ],
                scene: "The trial resolves not into punishment but annotation. In careful blue ink I write my findings in the margins: what mattered, what was missed, what may yet return. The scraps are released back into the world, each carrying a small mark that means *seen*. The lamp gutters low over the desk. Court, for tonight, is adjourned, though the Book leaves the ledger open, in case you have evidence of your own."
            )
        ],
        triggers: [.calendar, .keptRelatedPage, .letterKept],
        outcomes: [
            WorldEventOutcome(
                id: "filed-away",
                title: "Filed Away",
                minimumTouchCount: 0,
                packetLine: "The archive can remain atmospheric until the player chooses a scrap worth hearing.",
                monthlyEditionLine: "The Starlit Paper Trial passed as a quiet archive of ordinary evidence.",
                effects: []
            ),
            WorldEventOutcome(
                id: "witness-for-paper",
                title: "Witness for Paper",
                minimumTouchCount: 2,
                packetLine: "The player has given paper a witness. Let small records answer with surprising dignity.",
                monthlyEditionLine: "The player stood as Witness for Paper, letting one ordinary record become part of the month.",
                effects: [
                    WorldEventEffect(id: "paper-witness-letters", target: .pageType, targetID: BookPageType.letter.rawValue, tags: ["paper", "witness"], boost: 4, reason: "Letters know how to testify.")
                ]
            )
        ],
        effects: [
            WorldEventEffect(id: "paper-trial-notices", target: .pageType, targetID: BookPageType.bookNotices.rawValue, tags: ["archive", "paper"], boost: 8, reason: "I'm docketing scraps."),
            WorldEventEffect(id: "paper-trial-letters", target: .pageType, targetID: BookPageType.letter.rawValue, tags: ["archive", "letters"], boost: 6, reason: "Letters are admissible evidence.")
        ],
        packet: EventInfluencePacket(
            logline: "An archived paper trial is open: ordinary scraps are being treated as witnesses to the reader's real life.",
            atmosphere: "blue-black ink, folded receipts, moonlit paper clips, a docket written in cramped marginalia",
            storyInstruction: "Let the scene notice practical paper without turning it into bureaucracy; every scrap remembers a hand.",
            classInstruction: "Frame the lesson around evidence, attention, and the difference between proof and meaning.",
            letterInstruction: "Let the sender mention one ordinary record they kept longer than expected.",
            monthlyEditionLine: "The Starlit Paper Trial left a few scraps glowing in the month's binding.",
            bleedInstruction: "Treat the trial as an archive-desk hearing: quote one scrap of paper and one clerkly objection.",
            radioInstruction: "Let the broadcast carry docket-room hush, paper shuffling, and a station ID stamped in blue ink.",
            widgetWhisperLine: "A small scrap has taken the stand. I'm asking what it proves.",
            bookOfYouInstruction: "If today's kept pages include lists, receipts, notes, or practical records, let one scrap testify with quiet dignity.",
            visualTreatment: "blue ink rulings, exhibit tags, moonlit paper edges",
            fieldworkPrompt: "Find one scrap of paper nearby. What does it prove happened?",
            fieldworkPlaceholder: "Example: A receipt proves I crossed town for soup and came home with thyme.",
            fieldworkRewardLine: "A scrap admitted into evidence becomes part of the archive. I won't treat it as trash."
        )
    )
}

enum WorldEventResolver {
    /// Resolves the six-week authored shelf around one issue. Only `.live`
    /// carries participation; foreshadow and residue are deliberately cheap.
    static func lifecycleSnapshot(
        packID: String,
        event: WorldEvent,
        now: Date,
        ledger: WorldEventLifecycleLedger = .empty,
        calendar: Calendar = .current
    ) -> WorldEventLifecycleSnapshot? {
        guard let interval = event.calendar.scheduledInterval(near: now, calendar: calendar) else { return nil }
        let foreshadowStart = event.calendar.foreshadowStarts(for: interval, calendar: calendar)
        guard now >= foreshadowStart else { return nil }
        let residueEnd = event.calendar.residueEnds(for: interval, calendar: calendar)
        let casebookAvailable = event.calendar.casebookAvailableAt(for: interval, calendar: calendar)
        let year = calendar.component(.year, from: interval.start)
        let runID = "\(event.id):\(year)"

        let stage: WorldEventLifecycleStage
        if now < interval.start {
            stage = .foreshadow
        } else if now < interval.end {
            stage = .live
        } else if now < residueEnd {
            stage = .residue
        } else if now < casebookAvailable {
            stage = .sealed
        } else {
            stage = .casebookAvailable
        }

        let liveDay: Int?
        let phase: WorldEventPhase?
        if stage == .live {
            liveDay = max(0, calendar.dateComponents([.day], from: interval.start, to: now).day ?? 0)
            let progress = min(1, max(0, now.timeIntervalSince(interval.start) / max(1, interval.duration)))
            phase = Self.phase(for: event, progress: progress)
        } else {
            liveDay = nil
            phase = nil
        }

        return WorldEventLifecycleSnapshot(
            eventID: event.id,
            packID: packID,
            runID: runID,
            stage: stage,
            phaseID: phase?.id,
            phaseRole: phase.map { role(for: $0, in: event) },
            liveDay: liveDay,
            liveInterval: interval,
            foreshadowStartsAt: foreshadowStart,
            residueEndsAt: residueEnd,
            casebookAvailableAt: casebookAvailable,
            participated: ledger.participated(in: runID)
        )
    }

    /// All lifecycle envelopes currently on the shelf. This is how the Book
    /// may hold previous residue, a live issue, and next foreshadow together.
    static func lifecycleEvents(
        now: Date,
        ledger: WorldEventLifecycleLedger = .empty,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [WorldEventLifecycleSnapshot] {
        WorldEventRegistry.enabledEvents(fileManager: fileManager)
            .compactMap { packID, event in
                lifecycleSnapshot(packID: packID, event: event, now: now, ledger: ledger, calendar: calendar)
            }
            .sorted { $0.liveInterval.start < $1.liveInterval.start }
    }

    static func eligibleBeats(
        for event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        ledger: WorldEventLifecycleLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> [WorldEventBeat] {
        let day: Int
        switch snapshot.stage {
        case .foreshadow:
            day = max(0, calendar.dateComponents([.day], from: snapshot.foreshadowStartsAt, to: now).day ?? 0)
        case .live:
            guard let liveDay = snapshot.liveDay else { return [] }
            day = liveDay
        case .residue:
            day = max(0, calendar.dateComponents([.day], from: snapshot.liveInterval.end, to: now).day ?? 0)
        case .sealed, .casebookAvailable:
            return []
        }
        let delivered = Set(ledger.beatReceipts.filter { $0.runID == snapshot.runID }.map(\.beatID))
        return (event.beats ?? [])
            .filter {
                !delivered.contains($0.id)
                    && $0.resolvedLifecycleStage == snapshot.stage
                    && $0.opensOnDay <= day
                    && day <= $0.expiresAfterDay
            }
            .sorted { left, right in
                if left.isMilestone != right.isMilestone { return left.isMilestone }
                if left.opensOnDay != right.opensOnDay { return left.opensOnDay < right.opensOnDay }
                return left.id < right.id
            }
    }

    static func eligibleLiveBeats(
        for event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        ledger: WorldEventLifecycleLedger
    ) -> [WorldEventBeat] {
        guard snapshot.stage == .live else { return [] }
        return eligibleBeats(
            for: event,
            snapshot: snapshot,
            ledger: ledger,
            now: snapshot.liveInterval.start.addingTimeInterval(TimeInterval(snapshot.liveDay ?? 0) * 86_400)
        )
    }

    /// One compact artifact for every expired beat the reader did not receive.
    /// Its authored lines are third-person and safe for late or absent readers.
    static func reportBundle(
        for event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        ledger: WorldEventLifecycleLedger
    ) -> WorldEventReportBundle? {
        guard snapshot.stage != .foreshadow else { return nil }
        let delivered = Set(ledger.beatReceipts.filter { $0.runID == snapshot.runID }.map(\.beatID))
        let missed = (event.beats ?? [])
            .filter { beat in
                guard beat.reportsWhenMissed != false else { return false }
                guard beat.resolvedLifecycleStage == .live else { return false }
                guard !delivered.contains(beat.id) else { return false }
                if snapshot.stage == .live, let day = snapshot.liveDay {
                    return beat.expiresAfterDay < day
                }
                return snapshot.stage == .residue || snapshot.stage == .sealed || snapshot.stage == .casebookAvailable
            }
            .sorted { $0.opensOnDay < $1.opensOnDay }
        guard !missed.isEmpty else { return nil }
        let visible = missed.prefix(3).map { "• \($0.report)" }
        let remainder = missed.count - visible.count
        let tail = remainder > 0 ? "\n• And \(remainder) smaller report\(remainder == 1 ? "" : "s") were filed with it." : ""
        return WorldEventReportBundle(
            eventID: event.id,
            runID: snapshot.runID,
            beatIDs: missed.map(\.id),
            title: missed.count == 1 ? "A Report from the Closed Door" : "Reports from the Closed Door",
            body: visible.joined(separator: "\n") + tail
        )
    }

    static func activeEvents(
        now: Date,
        day: BookDay? = nil,
        inputs: BookSourceInputs = .empty,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [ResolvedWorldEvent] {
        WorldEventRegistry.enabledEvents(fileManager: fileManager).compactMap { packID, event in
            guard let interval = event.calendar.interval(containing: now, calendar: calendar) else { return nil }
            return resolvedEvent(packID: packID, event: event, interval: interval, now: now, day: day, inputs: inputs)
        }
    }

    static func currentEvents(
        now: Date,
        day: BookDay? = nil,
        inputs: BookSourceInputs = .empty,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [ResolvedWorldEvent] {
        // Product resolution is calendar-only. `openedArchiveEvent` remains a
        // lab instrument and a legacy decode seam, never a second public month.
        activeEvents(now: now, day: day, inputs: inputs, calendar: calendar, fileManager: fileManager)
    }

    static func openedArchiveEvent(
        now: Date,
        day: BookDay? = nil,
        inputs: BookSourceInputs = .empty,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> ResolvedWorldEvent? {
        guard let archive = inputs.openWorldEventArchive,
              archive.isActive(at: now),
              let resolved = WorldEventRegistry.event(packID: archive.packID, eventID: archive.eventID, fileManager: fileManager) else {
            return nil
        }
        let interval = archive.interval(for: resolved.event, now: now)
        return resolvedEvent(
            packID: resolved.packID,
            event: resolved.event,
            interval: interval,
            now: now,
            day: day,
            inputs: inputs,
            activationMode: .openedArchive
        )
    }

    static func archivedEvents(
        now: Date,
        day: BookDay? = nil,
        inputs: BookSourceInputs = .empty,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [ResolvedWorldEvent] {
        WorldEventRegistry.enabledEvents(fileManager: fileManager).compactMap { packID, event in
            guard let interval = event.calendar.archivedInterval(asOf: now, calendar: calendar) else { return nil }
            return resolvedEvent(packID: packID, event: event, interval: interval, now: interval.end, day: day, inputs: inputs, activationMode: .openedArchive)
        }
        .sorted { $0.endsAt > $1.endsAt }
    }

    /// Resolves enabled events against a synthetic interval centered on `now`,
    /// ignoring the calendar window. Lets the full event machinery (phases,
    /// outcomes, packets) be surfaced out of season: primarily for development
    /// previews so the Almanac is never structurally invisible.
    static func previewEvents(
        now: Date,
        day: BookDay? = nil,
        inputs: BookSourceInputs = .empty,
        progress: Double = 0.5,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [ResolvedWorldEvent] {
        let clamped = min(1, max(0, progress))
        return WorldEventRegistry.enabledEvents(fileManager: fileManager).map { packID, event in
            let duration = TimeInterval(max(1, event.calendar.durationDays)) * 86_400
            let start = now.addingTimeInterval(-duration * clamped)
            let interval = DateInterval(start: start, duration: duration)
            return resolvedEvent(packID: packID, event: event, interval: interval, now: now, day: day, inputs: inputs, activationMode: .preview)
        }
    }

    private static func resolvedEvent(
        packID: String,
        event: WorldEvent,
        interval: DateInterval,
        now: Date,
        day: BookDay?,
        inputs: BookSourceInputs,
        activationMode: WorldEventActivationMode = .liveCalendar
    ) -> ResolvedWorldEvent {
        let duration = max(1, interval.duration)
        let rawProgress = now.timeIntervalSince(interval.start) / duration
        let progress = min(1, max(0, rawProgress))
        let phase = phase(for: event, progress: progress)
        let touches = playerTouches(for: event, interval: interval, day: day, inputs: inputs)
        let touchCount = touches.count
        let touchCounts = Dictionary(grouping: touches, by: \.kind.rawValue).mapValues(\.count)
        let outcome = outcome(for: event, touchCount: touchCount)
        return ResolvedWorldEvent(
            id: event.id,
            packID: packID,
            title: event.title,
            subtitle: event.subtitle,
            phase: phase,
            startedAt: interval.start,
            endsAt: interval.end,
            progress: progress,
            playerTouchCount: touchCount,
            playerTouchCounts: touchCounts,
            outcome: outcome,
            effects: event.effects + (outcome?.effects ?? []),
            packet: event.packet,
            activationMode: activationMode
        )
    }

    private static func phase(for event: WorldEvent, progress: Double) -> WorldEventPhase {
        event.phases
            .sorted { $0.startsAtProgress < $1.startsAtProgress }
            .last { progress >= $0.startsAtProgress }
            ?? event.phases.first
            ?? WorldEventPhase(id: "active", title: "Active", startsAtProgress: 0, packetLine: event.packet.logline, intensity: 5, lexicalRules: [])
    }

    private static func role(for phase: WorldEventPhase, in event: WorldEvent) -> WorldEventPhaseRole {
        if let role = phase.role { return role }
        let ordered = event.phases.sorted { $0.startsAtProgress < $1.startsAtProgress }
        guard let index = ordered.firstIndex(where: { $0.id == phase.id }) else { return .setup }
        switch ordered.count {
        case 0, 1:
            return .setup
        case 2:
            return index == 0 ? .setup : .aftermath
        case 3:
            return [.setup, .buildup, .aftermath][index]
        default:
            if index == 0 { return .setup }
            if index == ordered.count - 1 { return .aftermath }
            return index < (ordered.count / 2) ? .buildup : .climax
        }
    }

    private static func outcome(for event: WorldEvent, touchCount: Int) -> WorldEventOutcome? {
        event.outcomes
            .sorted { $0.minimumTouchCount < $1.minimumTouchCount }
            .last { touchCount >= $0.minimumTouchCount }
    }

    private static func playerTouches(
        for event: WorldEvent,
        interval: DateInterval,
        day: BookDay?,
        inputs: BookSourceInputs
    ) -> [WorldEventTouch] {
        var pagesByID: [String: BookPage] = [:]
        for page in inputs.days.flatMap(\.pages) {
            pagesByID[page.id] = page
        }
        for page in day?.pages ?? [] {
            pagesByID[page.id] = page
        }
        let eventTag = "event:\(event.id)"
        var touches = pagesByID.values
            .filter { page in
                page.createdAt >= interval.start
                    && page.createdAt < interval.end
                    && page.tags.contains(eventTag)
            }
            .map { page in
                WorldEventTouch(kind: touchKind(for: page, event: event), pageID: page.id)
            }
        let normalizedEventID = StoryConsequenceCondition.key(event.id)
        for receipt in inputs.storyConsequenceLedger.receipts where
            receipt.createdAt >= interval.start &&
            receipt.createdAt < interval.end &&
            receipt.worldEventTouches.map(StoryConsequenceCondition.key).contains(normalizedEventID) {
            touches.append(WorldEventTouch(kind: .storyChoiceMade, pageID: receipt.sourcePageID))
        }
        var seenPageIDs = Set<String>()
        return touches.filter { seenPageIDs.insert($0.pageID).inserted }
    }

    private static func touchKind(for page: BookPage, event: WorldEvent) -> WorldEventTouchKind {
        let proposed: WorldEventTouchKind
        if page.tags.contains("event-word-ruled") {
            proposed = .wordRuled
        } else if page.tags.contains("event-fieldwork") {
            proposed = .fieldworkCompleted
        } else {
            switch page.type {
            case .letter:
                proposed = .letterKept
            case .academyClass:
                proposed = .classAnswered
            case .wonderCompass:
                proposed = .compassRunCompleted
            case .enchantment, .illuminatedPhoto:
                proposed = .enchantmentCompleted
            case .narrativeOS:
                proposed = .storyChoiceMade
            case .theBleed:
                proposed = .bleedEditionKept
            default:
                proposed = .keptRelatedPage
            }
        }

        if proposed == .keptRelatedPage || event.triggers.contains(proposed.trigger) {
            return proposed
        }
        return event.triggers.contains(.keptRelatedPage) ? .keptRelatedPage : proposed
    }
}

enum WorldEventCasebookBuilder {
    static func build(
        packID: String,
        event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        ledger: WorldEventLifecycleLedger,
        outcome: WorldEventOutcome?
    ) -> WorldEventCasebook {
        let participated = snapshot.participated
            || ledger.participated(in: snapshot.runID)
        let evidence = Array(Set(
            (ledger.participationReceipts ?? [])
                .filter { $0.runID == snapshot.runID }
                .flatMap(\.evidencePageIDs)
                + ledger.beatReceipts
                    .filter { $0.runID == snapshot.runID }
                    .flatMap(\.evidencePageIDs)
        )).sorted()
        let entries = (event.beats ?? [])
            .filter { $0.resolvedLifecycleStage == .live && $0.reportsWhenMissed != false }
            .sorted {
                if $0.opensOnDay != $1.opensOnDay { return $0.opensOnDay < $1.opensOnDay }
                return $0.id < $1.id
            }
            .map {
                WorldEventCasebookEntry(id: $0.id, title: $0.title, account: $0.report)
            }
        let history = outcome?.monthlyEditionLine ?? event.packet.monthlyEditionLine
        return WorldEventCasebook(
            id: "casebook:\(snapshot.runID)",
            eventID: event.id,
            packID: packID,
            runID: snapshot.runID,
            title: "The Casebook of \(event.title)",
            subtitle: participated
                ? "The public record, with this Book's receipt tucked inside."
                : "The public record. No attendance has been invented.",
            liveStartsAt: snapshot.liveInterval.start,
            liveEndsAt: snapshot.liveInterval.end,
            publishedAt: snapshot.casebookAvailableAt,
            outcomeTitle: outcome?.title,
            historySentence: history,
            entries: entries,
            residueVoice: participated ? .receipt : .rumor,
            evidencePageIDs: participated ? evidence : [],
            isPersonalized: participated
        )
    }
}

enum WorldEventCasebookRegistry {
    static let userCasebookFileSuffix = ".reenchantedcasebook.json"

    static func downloadedCasebooks(fileManager: FileManager = .default) -> [WorldEventCasebook] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ContentPackFileLocator.urls(suffix: userCasebookFileSuffix, fileManager: fileManager)
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(WorldEventCasebook.self, from: data)
            }
    }

    static func available(
        local: [WorldEventCasebook],
        downloaded: [WorldEventCasebook] = [],
        now: Date,
        hasMonthlyAccess: Bool
    ) -> [WorldEventCasebook] {
        guard hasMonthlyAccess else { return [] }
        var byRunID: [String: WorldEventCasebook] = [:]
        for casebook in downloaded where casebook.isAvailable(at: now) {
            byRunID[casebook.runID] = casebook
        }
        // A local receipt is more specific than the public rumor edition.
        for casebook in local where casebook.isAvailable(at: now) {
            if let published = byRunID[casebook.runID], !published.isPersonalized {
                if casebook.isPersonalized {
                    // Keep the authored shared history and add only this Book's
                    // proven receipt. A sparse local freeze must not replace it.
                    var joined = published
                    joined.id = casebook.id
                    joined.subtitle = casebook.subtitle
                    joined.residueVoice = casebook.residueVoice
                    joined.evidencePageIDs = casebook.evidencePageIDs
                    joined.isPersonalized = true
                    byRunID[casebook.runID] = joined
                }
            } else if byRunID[casebook.runID]?.isPersonalized != true || casebook.isPersonalized {
                byRunID[casebook.runID] = casebook
            }
        }
        return byRunID.values.sorted { $0.liveStartsAt > $1.liveStartsAt }
    }
}

/// Pure transition writer. Callers compare and save only when the returned
/// ledger differs, preventing vault mutation during repeated view resolution.
enum WorldEventLifecycleReconciler {
    static func recordingParticipationEvidence(
        ledger: WorldEventLifecycleLedger,
        eventID: String,
        runID: String,
        evidencePageIDs: [String],
        now: Date
    ) -> WorldEventLifecycleLedger {
        let evidence = Array(Set(evidencePageIDs)).sorted()
        guard !evidence.isEmpty else { return ledger }
        var copy = ledger
        var receipts = copy.participationReceipts ?? []
        if let index = receipts.firstIndex(where: { $0.runID == runID }) {
            let merged = Array(Set(receipts[index].evidencePageIDs + evidence)).sorted()
            guard merged != receipts[index].evidencePageIDs else { return ledger }
            receipts[index].evidencePageIDs = merged
        } else {
            receipts.append(
                WorldEventParticipationReceipt(
                    eventID: eventID,
                    runID: runID,
                    recordedAt: now,
                    evidencePageIDs: evidence
                )
            )
        }
        copy.participationReceipts = receipts
        return copy
    }

    static func recordingParticipation(
        ledger: WorldEventLifecycleLedger,
        runID: String,
        beatID: String,
        evidencePageIDs: [String] = [],
        now: Date
    ) -> WorldEventLifecycleLedger {
        guard let index = ledger.beatReceipts.firstIndex(where: { $0.runID == runID && $0.beatID == beatID }),
              ledger.beatReceipts[index].participatedAt == nil else {
            return ledger
        }
        var copy = ledger
        copy.beatReceipts[index].participatedAt = now
        copy.beatReceipts[index].evidencePageIDs = Array(
            Set(copy.beatReceipts[index].evidencePageIDs + evidencePageIDs)
        ).sorted()
        return copy
    }

    static func recordingDelivery(
        ledger: WorldEventLifecycleLedger,
        eventID: String,
        snapshot: WorldEventLifecycleSnapshot,
        beat: WorldEventBeat,
        kind: WorldEventBeatDeliveryKind,
        participated: Bool = false,
        evidencePageIDs: [String] = [],
        now: Date
    ) -> WorldEventLifecycleLedger {
        guard !ledger.beatReceipts.contains(where: { $0.id == "\(snapshot.runID):\(beat.id)" }) else {
            return ledger
        }
        var copy = ledger
        copy.beatReceipts.append(
            WorldEventBeatReceipt(
                eventID: eventID,
                runID: snapshot.runID,
                beatID: beat.id,
                deliveredAt: now,
                kind: kind,
                participatedAt: participated ? now : nil,
                evidencePageIDs: evidencePageIDs
            )
        )
        return copy
    }

    static func recordingReport(
        ledger: WorldEventLifecycleLedger,
        event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        report: WorldEventReportBundle,
        now: Date
    ) -> WorldEventLifecycleLedger {
        var copy = ledger
        let beatsByID = Dictionary(uniqueKeysWithValues: (event.beats ?? []).map { ($0.id, $0) })
        for beatID in report.beatIDs {
            guard let beat = beatsByID[beatID] else { continue }
            copy = recordingDelivery(
                ledger: copy,
                eventID: event.id,
                snapshot: snapshot,
                beat: beat,
                kind: .report,
                now: now
            )
        }
        return copy
    }

    /// Records a boundary once and binds one durable relic after the live door
    /// closes, but only for a reader whose receipts or event-tagged pages prove
    /// participation. A second reconciliation is byte-for-byte a no-op.
    static func reconcileBoundary(
        ledger: WorldEventLifecycleLedger,
        event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        outcome: WorldEventOutcome?,
        touchCount: Int,
        evidencePageIDs: [String] = [],
        now: Date
    ) -> WorldEventLifecycleLedger {
        var copy = ledger
        let boundaryID = "\(snapshot.runID):\(snapshot.stage.rawValue)"
        if !copy.boundaryReceipts.contains(where: { $0.id == boundaryID }) {
            copy.boundaryReceipts.append(
                WorldEventBoundaryReceipt(
                    eventID: event.id,
                    runID: snapshot.runID,
                    stage: snapshot.stage,
                    recordedAt: now
                )
            )
        }

        let liveDoorClosed = snapshot.stage == .residue
            || snapshot.stage == .sealed
            || snapshot.stage == .casebookAvailable
        let participated = snapshot.participated || touchCount > 0
        if liveDoorClosed,
           participated,
           !copy.relics.contains(where: { $0.runID == snapshot.runID }) {
            copy.relics.append(
                WorldEventRunRelic(
                    eventID: event.id,
                    runID: snapshot.runID,
                    outcomeID: outcome?.id,
                    historySentence: outcome?.monthlyEditionLine ?? event.packet.monthlyEditionLine,
                    evidencePageIDs: Array(Set(evidencePageIDs)).sorted(),
                    sealedAt: now
                )
            )
        }
        if liveDoorClosed,
           event.beats?.isEmpty == false,
           !(copy.casebooks ?? []).contains(where: { $0.runID == snapshot.runID }) {
            copy.casebooks = (copy.casebooks ?? []) + [
                WorldEventCasebookBuilder.build(
                    packID: snapshot.packID,
                    event: event,
                    snapshot: snapshot,
                    ledger: copy,
                    outcome: outcome
                )
            ]
        }
        return copy
    }
}

/// A reusable reader clock for authoring and regression tests. It walks the
/// issue without touching the app vault, so six weeks can be inspected in a
/// second and a second pass cannot create more history.
struct WorldEventSimulationPersona: Codable, Identifiable, Equatable {
    var id: String
    var subscribedFrom: Date
    var subscribedUntil: Date? = nil
    var firstPresentAt: Date
    var absentFrom: Date? = nil
    var returnsAt: Date? = nil
    var participatingBeatIDs: Set<String> = []

    func isSubscribed(at date: Date) -> Bool {
        date >= subscribedFrom && date < (subscribedUntil ?? .distantFuture)
    }

    func isPresent(at date: Date) -> Bool {
        guard date >= firstPresentAt else { return false }
        if let absentFrom, date >= absentFrom, date < (returnsAt ?? .distantFuture) {
            return false
        }
        return true
    }
}

struct WorldEventLifecycleSimulationFrame: Codable, Identifiable, Equatable {
    var personaID: String
    var date: Date
    var subscriptionActive: Bool
    var readerPresent: Bool
    var stage: WorldEventLifecycleStage?
    var phaseRole: WorldEventPhaseRole?
    var eligibleBeatIDs: [String]
    var deliveredBeatIDs: [String]
    var reportedBeatIDs: [String]
    var deskCandidateIDs: [String]
    var participated: Bool
    var residueVoice: WorldEventResidueVoice?
    var relicID: String?
    var marginaliaShelfIDs: [String]
    var casebookIDs: [String]? = nil

    var id: String { "\(personaID):\(date.timeIntervalSinceReferenceDate)" }
}

struct WorldEventLifecycleSimulation: Equatable {
    var frames: [WorldEventLifecycleSimulationFrame]
    var finalLedger: WorldEventLifecycleLedger
}

enum WorldEventLifecycleSimulator {
    static func run(
        packID: String,
        event: WorldEvent,
        persona: WorldEventSimulationPersona,
        from start: Date,
        through end: Date,
        calendar: Calendar = .current
    ) -> WorldEventLifecycleSimulation {
        var ledger = WorldEventLifecycleLedger.empty
        var frames: [WorldEventLifecycleSimulationFrame] = []
        var date = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)

        while date <= last {
            let subscribed = persona.isSubscribed(at: date)
            let present = persona.isPresent(at: date)
            var snapshot = WorldEventResolver.lifecycleSnapshot(
                packID: packID,
                event: event,
                now: date,
                ledger: ledger,
                calendar: calendar
            )
            var eligible: [WorldEventBeat] = []
            var delivered: [String] = []
            var reported: [String] = []
            var deskCandidates: [String] = []

            if subscribed, present, let current = snapshot {
                eligible = WorldEventResolver.eligibleBeats(
                    for: event,
                    snapshot: current,
                    ledger: ledger,
                    now: date,
                    calendar: calendar
                )
                if let next = eligible.first {
                    let kind: WorldEventBeatDeliveryKind
                    switch current.stage {
                    case .foreshadow: kind = .foreshadow
                    case .residue: kind = .residue
                    default: kind = .live
                    }
                    deskCandidates.append(next.id)
                    ledger = WorldEventLifecycleReconciler.recordingDelivery(
                        ledger: ledger,
                        eventID: event.id,
                        snapshot: current,
                        beat: next,
                        kind: kind,
                        participated: current.stage == .live && persona.participatingBeatIDs.contains(next.id),
                        now: date
                    )
                    delivered.append(next.id)
                }

                if let report = WorldEventResolver.reportBundle(for: event, snapshot: current, ledger: ledger) {
                    deskCandidates.append("report:\(report.runID)")
                    ledger = WorldEventLifecycleReconciler.recordingReport(
                        ledger: ledger,
                        event: event,
                        snapshot: current,
                        report: report,
                        now: date
                    )
                    reported = report.beatIDs
                }

                snapshot = WorldEventResolver.lifecycleSnapshot(
                    packID: packID,
                    event: event,
                    now: date,
                    ledger: ledger,
                    calendar: calendar
                )
            }

            // Boundary bookkeeping belongs to the Book, not to entitlement.
            // A lapsed subscriber keeps the ending their earlier action earned.
            if present, let current = snapshot {
                let participationCount = ledger.beatReceipts.filter {
                    $0.runID == current.runID && $0.countsAsParticipation
                }.count
                let outcome = event.outcomes
                    .sorted { $0.minimumTouchCount < $1.minimumTouchCount }
                    .last { participationCount >= $0.minimumTouchCount }
                ledger = WorldEventLifecycleReconciler.reconcileBoundary(
                    ledger: ledger,
                    event: event,
                    snapshot: current,
                    outcome: outcome,
                    touchCount: participationCount,
                    now: date
                )
                snapshot = WorldEventResolver.lifecycleSnapshot(
                    packID: packID,
                    event: event,
                    now: date,
                    ledger: ledger,
                    calendar: calendar
                )
            }

            let runID = snapshot?.runID
            let relic = runID.flatMap { id in ledger.relics.first { $0.runID == id } }
            frames.append(
                WorldEventLifecycleSimulationFrame(
                    personaID: persona.id,
                    date: date,
                    subscriptionActive: subscribed,
                    readerPresent: present,
                    stage: snapshot?.stage,
                    phaseRole: snapshot?.phaseRole,
                    eligibleBeatIDs: eligible.map(\.id),
                    deliveredBeatIDs: delivered,
                    reportedBeatIDs: reported,
                    deskCandidateIDs: deskCandidates,
                    participated: snapshot?.participated ?? false,
                    residueVoice: snapshot?.stage == .residue ? snapshot?.residueVoice : nil,
                    relicID: relic?.id,
                    marginaliaShelfIDs: ledger.relics.map(\.id).sorted(),
                    casebookIDs: (ledger.casebooks ?? [])
                        .filter { $0.isAvailable(at: date) }
                        .map(\.id)
                        .sorted()
                )
            )

            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return WorldEventLifecycleSimulation(frames: frames, finalLedger: ledger)
    }
}

extension Array where Element == ResolvedWorldEvent {
    var influencePacket: String {
        guard !isEmpty else { return "" }
        return map(\.influenceLine).joined(separator: "\n\n")
    }

    var bleedPacket: String {
        scopedPacket(title: "WORLD EVENT PRESSURE FOR THE BLEED") { event in
            event.packet.bleedInstruction?.nonEmpty
                ?? event.packet.monthlyEditionLine.nonEmpty
                ?? event.packet.atmosphere
        }
    }

    var radioAtmosphereLine: String? {
        let lines = compactMap { event -> String? in
            let directive = event.packet.radioInstruction?.nonEmpty ?? event.packet.atmosphere.nonEmpty
            guard let directive else { return nil }
            return "\(event.title): \(directive)"
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    var widgetWhisperLine: String? {
        compactMap { event in
            event.packet.widgetWhisperLine?.nonEmpty
                ?? event.phase.scene?.nonEmpty
                ?? event.packet.logline.nonEmpty
        }
        .first?
        .bookPreviewSentenceLimit(1)
    }

    var bookOfYouPromptSection: String {
        let packet = scopedPacket(title: "WORLD EVENT PRESSURE") { event in
            event.packet.bookOfYouInstruction?.nonEmpty
                ?? event.packet.storyInstruction.nonEmpty
                ?? event.packet.atmosphere
        }
        guard !packet.isEmpty else { return "" }
        return """


        \(packet)

        WORLD EVENT RULE:
        - Let this pressure color the Book of You only when today's kept pages honestly invite it.
        - Never invent a world-event action the reader did not keep or report.
        - A single word, object, or image is enough; do not turn the day into event exposition.
        """
    }

    var eventTags: [String] {
        flatMap { event -> [String] in
            var tags = ["world-event", "event:\(event.id)", "event-phase:\(event.phase.id)"]
            if let outcome = event.outcome {
                tags.append("event-outcome:\(outcome.id)")
            }
            return tags
        }
    }

    private func scopedPacket(title: String, line: (ResolvedWorldEvent) -> String?) -> String {
        let entries = compactMap { event -> String? in
            guard let directive = line(event)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !directive.isEmpty else { return nil }
            return """
            \(event.title): \(event.phase.title)
            \(directive)
            Player touches: \(event.playerTouchCount)
            """
        }
        guard !entries.isEmpty else { return "" }
        return "\(title):\n" + entries.joined(separator: "\n\n")
    }

    func scoreBoost(for pageType: BookPageType) -> Int {
        reduce(0) { total, event in
            total + event.effects.reduce(0) { subtotal, effect in
                guard effect.target == .pageType,
                      effect.targetID == pageType.rawValue else { return subtotal }
                return subtotal + effect.boost
            }
        }
    }

    func scoreBoost(forEntityID entityID: String) -> Int {
        reduce(0) { total, event in
            total + event.effects.reduce(0) { subtotal, effect in
                effect.target == .entity && effect.targetID == entityID ? subtotal + effect.boost : subtotal
            }
        }
    }

    func scoreBoost(forThreadID threadID: String) -> Int {
        reduce(0) { total, event in
            total + event.effects.reduce(0) { subtotal, effect in
                effect.target == .storyThread && effect.targetID == threadID ? subtotal + effect.boost : subtotal
            }
        }
    }

    var monthlyEditionLines: [String] {
        map { $0.outcome?.monthlyEditionLine ?? $0.packet.monthlyEditionLine }
    }
}

// MARK: - Monthly issue delivery

enum MonthlyIssueDeliveryAssetKind: String, Codable, Equatable {
    case worldEventPack
    case pageArchetypePack
    case storyFormPack
    case storyConsequencePack
    case radioStationPack
    case sentenceBuilderPack
    case casebook
    case media
}

enum MonthlyIssueDeliveryAssetScope: String, Codable, Equatable {
    /// Removed after residue once the casebook has been frozen.
    case runtime
    /// Small, read-only publication matter. It never activates event physics.
    case casebook
}

struct MonthlyIssueDeliveryAsset: Codable, Identifiable, Equatable {
    var id: String
    var kind: MonthlyIssueDeliveryAssetKind
    var scope: MonthlyIssueDeliveryAssetScope
    var remoteURL: URL
    var fileName: String
    var sha256: String
    var byteCount: Int
    var isRequired: Bool = true
    /// Optional earlier file retirement; runtime assets otherwise last through residue.
    /// Eligibility still belongs to the atom's gates, never to file presence.
    var retiresAt: Date? = nil
}

struct MonthlyIssueDeliveryIssue: Codable, Identifiable, Equatable {
    var id: String
    var packID: String
    var title: String
    var liveStartsAt: Date
    var liveEndsAt: Date
    var foreshadowStartsAt: Date
    var residueEndsAt: Date
    var casebookAvailableAt: Date
    var assets: [MonthlyIssueDeliveryAsset]
}

struct MonthlyIssueDeliveryManifest: Codable, Equatable {
    var schemaVersion: Int
    var generatedAt: Date
    var allowedAssetHosts: [String]
    var issues: [MonthlyIssueDeliveryIssue]
}

/// The server signs the exact payload bytes, then base64-encodes both fields.
/// No re-encoding or key sorting happens on device before verification.
struct MonthlyIssueSignedManifestEnvelope: Codable, Equatable {
    var keyID: String
    var payload: String
    var signature: String
}

enum MonthlyIssueDeliveryError: Error, Equatable {
    case malformedEnvelope
    case invalidPublicKey
    case invalidSignature
    case unsupportedSchema(Int)
    case unsafeAssetURL(String)
    case unsafeFileName(String)
    case wrongFileSuffix(String)
    case invalidByteCount(String)
    case invalidManifest(String)
    case assetTooLarge(String)
    case installTooLarge
    case checksumMismatch(String)
    case invalidAsset(String)
}

enum MonthlyIssueManifestVerifier {
    static let supportedSchemaVersion = 2

    static func verify(
        envelopeData: Data,
        publicKeyRawRepresentation: Data
    ) throws -> MonthlyIssueDeliveryManifest {
        guard let envelope = try? JSONDecoder().decode(MonthlyIssueSignedManifestEnvelope.self, from: envelopeData),
              let payload = Data(base64Encoded: envelope.payload),
              let signature = Data(base64Encoded: envelope.signature) else {
            throw MonthlyIssueDeliveryError.malformedEnvelope
        }
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRawRepresentation) else {
            throw MonthlyIssueDeliveryError.invalidPublicKey
        }
        guard key.isValidSignature(signature, for: payload) else {
            throw MonthlyIssueDeliveryError.invalidSignature
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(MonthlyIssueDeliveryManifest.self, from: payload)
        guard (1...supportedSchemaVersion).contains(manifest.schemaVersion) else {
            throw MonthlyIssueDeliveryError.unsupportedSchema(manifest.schemaVersion)
        }
        try validate(manifest)
        return manifest
    }

    private static func validate(_ manifest: MonthlyIssueDeliveryManifest) throws {
        var issueIDs = Set<String>()
        var assetIDs = Set<String>()
        let ordered = manifest.issues.sorted { $0.liveStartsAt < $1.liveStartsAt }
        for (index, issue) in ordered.enumerated() {
            guard !issue.id.isEmpty, !issue.packID.isEmpty,
                  issueIDs.insert(issue.id).inserted else {
                throw MonthlyIssueDeliveryError.invalidManifest("duplicate-or-empty-issue")
            }
            guard issue.foreshadowStartsAt <= issue.liveStartsAt,
                  issue.liveStartsAt < issue.liveEndsAt,
                  issue.liveEndsAt <= issue.residueEndsAt,
                  issue.residueEndsAt <= issue.casebookAvailableAt else {
                throw MonthlyIssueDeliveryError.invalidManifest(issue.id)
            }
            if index > 0, ordered[index - 1].liveEndsAt > issue.liveStartsAt {
                throw MonthlyIssueDeliveryError.invalidManifest("overlapping-live-issues")
            }
            for asset in issue.assets {
                guard !asset.id.isEmpty, assetIDs.insert(asset.id).inserted else {
                    throw MonthlyIssueDeliveryError.invalidManifest("duplicate-or-empty-asset")
                }
                if let retiresAt = asset.retiresAt,
                   asset.scope != .runtime || retiresAt <= issue.foreshadowStartsAt || retiresAt > issue.residueEndsAt {
                    throw MonthlyIssueDeliveryError.invalidManifest("invalid-retirement:\(asset.id)")
                }
                if asset.kind == .casebook, asset.scope != .casebook {
                    throw MonthlyIssueDeliveryError.invalidManifest("live-casebook:\(asset.id)")
                }
            }
        }
    }
}

struct MonthlyIssuePlannedAsset: Identifiable, Equatable {
    var id: String { asset.id }
    var issueID: String
    var allowedHosts: Set<String>
    var asset: MonthlyIssueDeliveryAsset
    var retiresAt: Date? = nil
}

struct MonthlyIssueDeliveryPlan: Equatable {
    var generatedAt: Date
    var assets: [MonthlyIssuePlannedAsset]

    static func empty(now: Date) -> Self { Self(generatedAt: now, assets: []) }
}

struct MonthlyIssueSubscriptionProof: Encodable {
    var signedTransactions: [String]
    var membershipID: String?
}

struct MonthlyIssueAccessSession: Decodable, Equatable {
    var token: String
    var expiresAt: Date
}

enum MonthlyIssueRequestPolicy {
    static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == "https" && rhs.scheme?.lowercased() == "https"
            && lhs.host != nil && lhs.host?.lowercased() == rhs.host?.lowercased()
            && (lhs.port ?? 443) == (rhs.port ?? 443)
            && lhs.user == nil && lhs.password == nil && rhs.user == nil && rhs.password == nil
    }

    static func mayUseCachedEnvelope(afterHTTPStatus status: Int) -> Bool {
        status == 408 || status == 429 || (500...599).contains(status)
    }
}

enum MonthlyIssueDeliveryPolicy {
    static let runtimeVersion = 8
    static let maximumSingleAssetBytes = 180 * 1_024 * 1_024
    static let maximumInstalledBytes = 350 * 1_024 * 1_024
    static let maximumCasebookBytes = 2 * 1_024 * 1_024
    static let managedFilePrefix = "reenchanted-managed-"
    static let supportDirectoryName = "MonthlyIssueDelivery"
    static let managedContentDirectoryName = "Content"

    /// Delivery placeholders resolve to complete local paths, including the
    /// extension. Accept only subscribed, installer-owned audio in our directory.
    static func managedAudioURL(
        forPath path: String,
        hasMonthlyAccess: Bool,
        directory: URL?,
        fileManager: FileManager = .default
    ) -> URL? {
        guard hasMonthlyAccess, path.hasPrefix("/"), let directory else { return nil }
        let relocated = MonthlyIssueMediaPath.resolving(path,
            supportDirectory: directory.deletingLastPathComponent().deletingLastPathComponent())
        let target = URL(fileURLWithPath: relocated).resolvingSymlinksInPath().standardizedFileURL
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        guard target.path.hasPrefix(root.path + "/"),
              target.lastPathComponent.hasPrefix(managedFilePrefix),
              ["m4a", "mp3", "wav", "aac", "caf", "aiff"].contains(target.pathExtension.lowercased()),
              fileManager.fileExists(atPath: target.path) else { return nil }
        return target
    }

    static func managedContentDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
            .appendingPathComponent(managedContentDirectoryName, isDirectory: true)
    }
}

enum ContentPackFileLocator {
    /// Delivered JSON uses ISO dates; old local exports used Foundation's
    /// reference-date numbers. Every registry must accept the same wire format.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer()
            if let number = try? value.decode(Double.self) { return Date(timeIntervalSinceReferenceDate: number) }
            let raw = try value.decode(String.self)
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: value, debugDescription: "Expected an ISO-8601 date")
        }
        return decoder
    }

    /// Files dropped into Documents remain valid user imports. Signed monthly
    /// assets live separately in Application Support so Files.app never shows
    /// implementation inventory to the reader.
    static func urls(
        suffix: String,
        fileManager: FileManager = .default
    ) -> [URL] {
        var directories: [URL] = []
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            directories.append(documents)
        }
        // Downloaded monthly material follows the current monthly-access
        // policy regardless of a payload's availability flag. File deletion
        // may still be pending.
        if PackEntitlements.hasMonthlyContentPackAccess(in: PackEntitlements.ownedPackIDs),
           let managed = MonthlyIssueDeliveryPolicy.managedContentDirectory(fileManager: fileManager) {
            directories.append(managed)
        }
        var seen = Set<String>()
        return directories.flatMap { directory in
            (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
        }
        .filter { $0.lastPathComponent.hasSuffix(suffix) }
        .filter { seen.insert($0.standardizedFileURL.path).inserted }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

enum MonthlyIssueDeliveryPlanner {
    /// Installs the issue whose six-week envelope contains now, plus the next
    /// issue. Published casebooks remain tiny read-only assets and may all be
    /// present; old runtime/media packs are excluded from the plan and pruned.
    static func plan(
        manifest: MonthlyIssueDeliveryManifest,
        now: Date,
        hasMonthlyAccess: Bool,
        manifestHost: String?
    ) -> MonthlyIssueDeliveryPlan {
        guard hasMonthlyAccess else { return .empty(now: now) }
        let ordered = manifest.issues.sorted { $0.liveStartsAt < $1.liveStartsAt }
        var runtimeIssueIDs = Set(ordered.filter {
            $0.foreshadowStartsAt <= now && now < $0.residueEndsAt
        }.map(\.id))
        if let next = ordered.first(where: { $0.liveStartsAt > now }) {
            runtimeIssueIDs.insert(next.id)
        }

        let signedHosts = Set(
            manifest.allowedAssetHosts
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        ).union(manifestHost.map { [$0.lowercased()] } ?? [])
        var planned: [MonthlyIssuePlannedAsset] = []
        for issue in ordered {
            for asset in issue.assets {
                let wantsRuntime = asset.scope == .runtime && runtimeIssueIDs.contains(issue.id)
                    && now < (asset.retiresAt ?? issue.residueEndsAt)
                let wantsCasebook = asset.scope == .casebook && issue.casebookAvailableAt <= now
                guard wantsRuntime || wantsCasebook else { continue }
                planned.append(MonthlyIssuePlannedAsset(
                    issueID: issue.id,
                    allowedHosts: signedHosts,
                    asset: asset,
                    retiresAt: asset.scope == .runtime ? (asset.retiresAt ?? issue.residueEndsAt) : nil
                ))
            }
        }
        var seen = Set<String>()
        planned = planned.filter { seen.insert($0.asset.id).inserted }
        return MonthlyIssueDeliveryPlan(generatedAt: manifest.generatedAt, assets: planned)
    }
}

struct MonthlyIssueInstalledAsset: Codable, Identifiable, Equatable {
    var id: String
    var issueID: String
    var fileName: String
    var sourceSHA256: String
    var scope: MonthlyIssueDeliveryAssetScope
    var retiresAt: Date? = nil
}

struct MonthlyIssueInstallationState: Codable, Equatable {
    var manifestGeneratedAt: Date?
    var assets: [MonthlyIssueInstalledAsset]

    static let empty = Self(manifestGeneratedAt: nil, assets: [])
}

struct MonthlyIssueInstallationResult: Equatable {
    var state: MonthlyIssueInstallationState
    var installedAssetIDs: [String]
    var removedAssetIDs: [String]
    var skippedOptionalAssetIDs: [String]

    var changed: Bool { !installedAssetIDs.isEmpty || !removedAssetIDs.isEmpty }
}

enum MonthlyIssueAssetInstaller {
    typealias Fetch = @Sendable (URL) async throws -> Data

    /// Retirement is independent of downloading the replacement issue. A failed
    /// required download must not keep last month's managed assets installed.
    /// Only the installation ledger can authorize a removal; imports are untouched.
    static func retireObsoleteAssets(
        plan: MonthlyIssueDeliveryPlan,
        documentsURL: URL,
        stateURL: URL,
        fileManager: FileManager = .default
    ) throws -> [String] {
        try validate(plan: plan)
        return try retireAssets(keeping: Set(plan.assets.map(\.asset.id)), documentsURL: documentsURL,
            stateURL: stateURL, fileManager: fileManager)
    }

    static func retireExpiredAssets(now: Date, documentsURL: URL, stateURL: URL,
                                    fileManager: FileManager = .default) throws -> [String] {
        guard fileManager.fileExists(atPath: stateURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(MonthlyIssueInstallationState.self, from: Data(contentsOf: stateURL))
        let keep = Set(state.assets.filter { $0.retiresAt.map { now < $0 } ?? true }.map(\.id))
        return try retireAssets(keeping: keep, documentsURL: documentsURL, stateURL: stateURL, fileManager: fileManager)
    }

    private static func retireAssets(keeping desired: Set<String>, documentsURL: URL, stateURL: URL,
                                      fileManager: FileManager) throws -> [String] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard fileManager.fileExists(atPath: stateURL.path) else { return [] }
        var state = try decoder.decode(MonthlyIssueInstallationState.self, from: Data(contentsOf: stateURL))
        let retired = state.assets.filter { !desired.contains($0.id) }
        guard !retired.isEmpty else { return [] }
        let staging = stateURL.deletingLastPathComponent()
            .appendingPathComponent(".monthly-retirement-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        var moved: [(target: URL, backup: URL)] = []
        do {
            for asset in retired {
                let target = documentsURL.appendingPathComponent(asset.fileName, isDirectory: false)
                guard isManagedTarget(target, inside: documentsURL),
                      fileManager.fileExists(atPath: target.path),
                      !moved.contains(where: { $0.target == target }) else { continue }
                let backup = staging.appendingPathComponent(UUID().uuidString)
                try fileManager.moveItem(at: target, to: backup)
                moved.append((target, backup))
            }
            state.assets.removeAll { !desired.contains($0.id) }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(state).write(to: stateURL, options: .atomic)
            return retired.map(\.id).sorted()
        } catch {
            for pair in moved.reversed() {
                try? fileManager.moveItem(at: pair.backup, to: pair.target)
            }
            throw error
        }
    }

    static func install(
        plan: MonthlyIssueDeliveryPlan,
        documentsURL: URL,
        stateURL: URL,
        fileManager: FileManager = .default,
        fetch: Fetch
    ) async throws -> MonthlyIssueInstallationResult {
        try validate(plan: plan)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let previous = (try? Data(contentsOf: stateURL))
            .flatMap { try? decoder.decode(MonthlyIssueInstallationState.self, from: $0) }
            ?? .empty
        let previousByID = previous.assets.reduce(into: [String: MonthlyIssueInstalledAsset]()) {
            if $0[$1.id] == nil { $0[$1.id] = $1 }
        }
        let desiredIDs = Set(plan.assets.map(\.asset.id))
        let destinations = Dictionary(uniqueKeysWithValues: try plan.assets.map { planned in
            (planned.asset.id, try destinationURL(for: planned, documentsURL: documentsURL))
        })

        let transactionDirectory = documentsURL.appendingPathComponent(
            ".monthly-issue-transaction-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: transactionDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: transactionDirectory) }

        var nextAssets: [MonthlyIssueInstalledAsset] = []
        var stagedByID: [String: URL] = [:]
        var installedIDs: [String] = []
        var skipped: [String] = []
        for planned in plan.assets {
            let asset = planned.asset
            guard let target = destinations[asset.id] else { continue }
            if let old = previousByID[asset.id],
               old.sourceSHA256.caseInsensitiveCompare(asset.sha256) == .orderedSame,
               fileManager.fileExists(atPath: target.path) {
                var refreshed = old
                refreshed.retiresAt = planned.retiresAt
                nextAssets.append(refreshed)
                continue
            }
            do {
                let sourceData = try await fetch(asset.remoteURL)
                guard sourceData.count == asset.byteCount else {
                    throw MonthlyIssueDeliveryError.invalidByteCount(asset.id)
                }
                guard sha256Hex(sourceData).caseInsensitiveCompare(asset.sha256) == .orderedSame else {
                    throw MonthlyIssueDeliveryError.checksumMismatch(asset.id)
                }
                let materialized = try materialize(
                    sourceData,
                    asset: asset,
                    destinationByAssetID: destinations
                )
                try validateMaterializedAsset(materialized, asset: asset)
                let staged = transactionDirectory.appendingPathComponent(
                    "new-\(UUID().uuidString)",
                    isDirectory: false
                )
                try materialized.write(to: staged, options: .atomic)
                stagedByID[asset.id] = staged
                nextAssets.append(MonthlyIssueInstalledAsset(
                    id: asset.id,
                    issueID: planned.issueID,
                    fileName: target.lastPathComponent,
                    sourceSHA256: asset.sha256.lowercased(),
                    scope: asset.scope,
                    retiresAt: planned.retiresAt
                ))
                installedIDs.append(asset.id)
            } catch {
                if asset.isRequired { throw error }
                skipped.append(asset.id)
                if let old = previousByID[asset.id] {
                    let oldTarget = documentsURL.appendingPathComponent(old.fileName, isDirectory: false)
                    if isManagedTarget(oldTarget, inside: documentsURL),
                       fileManager.fileExists(atPath: oldTarget.path) {
                        nextAssets.append(old)
                    }
                }
            }
        }

        let nextByID = Dictionary(uniqueKeysWithValues: nextAssets.map { ($0.id, $0) })
        let obsolete = previous.assets.filter { old in
            guard let next = nextByID[old.id] else { return true }
            return next.fileName != old.fileName
        }
        var backups: [(target: URL, backup: URL)] = []
        var committedTargets: [URL] = []
        do {
            for planned in plan.assets {
                guard let staged = stagedByID[planned.asset.id],
                      let target = destinations[planned.asset.id] else { continue }
                if fileManager.fileExists(atPath: target.path) {
                    let backup = transactionDirectory.appendingPathComponent(
                        "replaced-\(UUID().uuidString)",
                        isDirectory: false
                    )
                    try fileManager.moveItem(at: target, to: backup)
                    backups.append((target, backup))
                }
                try fileManager.moveItem(at: staged, to: target)
                committedTargets.append(target)
                var excludedTarget = target
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try? excludedTarget.setResourceValues(resourceValues)
            }

            for old in obsolete {
                let target = documentsURL.appendingPathComponent(old.fileName, isDirectory: false)
                guard isManagedTarget(target, inside: documentsURL),
                      fileManager.fileExists(atPath: target.path),
                      !backups.contains(where: { $0.target.standardizedFileURL == target.standardizedFileURL }) else {
                    continue
                }
                let backup = transactionDirectory.appendingPathComponent(
                    "retired-\(UUID().uuidString)",
                    isDirectory: false
                )
                try fileManager.moveItem(at: target, to: backup)
                backups.append((target, backup))
            }

            let next = MonthlyIssueInstallationState(
                manifestGeneratedAt: plan.generatedAt,
                assets: nextAssets.sorted { $0.id < $1.id }
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(next).write(to: stateURL, options: .atomic)

            let removedIDs = previous.assets
                .filter { !desiredIDs.contains($0.id) }
                .map(\.id)
                .sorted()
            return MonthlyIssueInstallationResult(
                state: next,
                installedAssetIDs: installedIDs.sorted(),
                removedAssetIDs: removedIDs,
                skippedOptionalAssetIDs: skipped.sorted()
            )
        } catch {
            for target in committedTargets.reversed()
            where fileManager.fileExists(atPath: target.path) {
                try? fileManager.removeItem(at: target)
            }
            for pair in backups.reversed()
            where fileManager.fileExists(atPath: pair.backup.path) {
                if fileManager.fileExists(atPath: pair.target.path) {
                    try? fileManager.removeItem(at: pair.target)
                }
                try? fileManager.moveItem(at: pair.backup, to: pair.target)
            }
            throw error
        }
    }

    private static func validate(plan: MonthlyIssueDeliveryPlan) throws {
        let total = plan.assets.reduce(0) { $0 + max(0, $1.asset.byteCount) }
        guard total <= MonthlyIssueDeliveryPolicy.maximumInstalledBytes else {
            throw MonthlyIssueDeliveryError.installTooLarge
        }
        var assetIDs = Set<String>()
        var destinations = Set<String>()
        for planned in plan.assets {
            let asset = planned.asset
            guard assetIDs.insert(asset.id).inserted else {
                throw MonthlyIssueDeliveryError.invalidManifest("duplicate-asset:\(asset.id)")
            }
            let destinationKey = "\(planned.issueID):\(asset.fileName)"
            guard destinations.insert(destinationKey).inserted else {
                throw MonthlyIssueDeliveryError.invalidManifest("duplicate-destination:\(destinationKey)")
            }
            guard asset.byteCount > 0 else {
                throw MonthlyIssueDeliveryError.invalidByteCount(asset.id)
            }
            let maximum = asset.scope == .casebook
                ? MonthlyIssueDeliveryPolicy.maximumCasebookBytes
                : MonthlyIssueDeliveryPolicy.maximumSingleAssetBytes
            guard asset.byteCount <= maximum else {
                throw MonthlyIssueDeliveryError.assetTooLarge(asset.id)
            }
            guard asset.remoteURL.scheme?.lowercased() == "https",
                  let host = asset.remoteURL.host?.lowercased(),
                  planned.allowedHosts.contains(host) else {
                throw MonthlyIssueDeliveryError.unsafeAssetURL(asset.remoteURL.absoluteString)
            }
            guard safeFileName(asset.fileName) == asset.fileName else {
                throw MonthlyIssueDeliveryError.unsafeFileName(asset.fileName)
            }
            guard !asset.fileName.isEmpty, asset.fileName != ".", asset.fileName != "..",
                  asset.sha256.count == 64,
                  asset.sha256.allSatisfy({ $0.isHexDigit }) else {
                throw MonthlyIssueDeliveryError.invalidAsset(asset.id)
            }
            guard hasExpectedSuffix(asset) else {
                throw MonthlyIssueDeliveryError.wrongFileSuffix(asset.fileName)
            }
        }
    }

    private static func destinationURL(
        for planned: MonthlyIssuePlannedAsset,
        documentsURL: URL
    ) throws -> URL {
        let issue = safeFileName(planned.issueID)
        guard !issue.isEmpty, issue == planned.issueID else {
            throw MonthlyIssueDeliveryError.unsafeFileName(planned.issueID)
        }
        let name = MonthlyIssueDeliveryPolicy.managedFilePrefix + issue + "-" + planned.asset.fileName
        return documentsURL.appendingPathComponent(name, isDirectory: false)
    }

    private static func safeFileName(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    private static func hasExpectedSuffix(_ asset: MonthlyIssueDeliveryAsset) -> Bool {
        switch asset.kind {
        case .worldEventPack: return asset.fileName.hasSuffix(WorldEventRegistry.userPackFileSuffix)
        case .pageArchetypePack: return asset.fileName.hasSuffix(PageArchetypePackRegistry.userPackFileSuffix)
        case .storyFormPack: return asset.fileName.hasSuffix(StoryFormRegistry.userPackFileSuffix)
        case .storyConsequencePack: return asset.fileName.hasSuffix(StoryConsequenceRegistry.userPackFileSuffix)
        case .radioStationPack: return asset.fileName.hasSuffix(RadioStationRegistry.userPackFileSuffix)
        case .sentenceBuilderPack: return asset.fileName.hasSuffix(SentenceBuilderPackRegistry.userPackFileSuffix)
        case .casebook: return asset.fileName.hasSuffix(WorldEventCasebookRegistry.userCasebookFileSuffix)
        case .media: return !asset.fileName.isEmpty
        }
    }

    private static func materialize(
        _ source: Data,
        asset: MonthlyIssueDeliveryAsset,
        destinationByAssetID: [String: URL]
    ) throws -> Data {
        guard asset.kind != .media, var text = String(data: source, encoding: .utf8) else {
            return source
        }
        for (assetID, destination) in destinationByAssetID {
            text = text.replacingOccurrences(
                of: "{{asset-path:\(assetID)}}",
                with: destination.path
            )
        }
        guard !text.contains("{{asset-path:"), let data = text.data(using: .utf8) else {
            throw MonthlyIssueDeliveryError.invalidAsset(asset.id)
        }
        return data
    }

    private static func validateMaterializedAsset(
        _ data: Data,
        asset: MonthlyIssueDeliveryAsset
    ) throws {
        let decoder = ContentPackFileLocator.decoder()
        let valid: Bool
        switch asset.kind {
        case .worldEventPack:
            if let pack = try? decoder.decode(WorldEventPack.self, from: data),
               (pack.minimumRuntimeVersion ?? 1) <= MonthlyIssueDeliveryPolicy.runtimeVersion {
                valid = ((pack.minimumRuntimeVersion ?? 1) < 2 || !(pack.authoringManifests ?? []).isEmpty) && (pack.authoringManifests ?? []).allSatisfy {
                    MonthlyIssueAuthoringValidator.validate($0, against: pack, mode: .release).isValid
                }
            } else { valid = false }
        case .pageArchetypePack: valid = (try? decoder.decode(PageArchetypePack.self, from: data)) != nil
        case .storyFormPack: valid = (try? decoder.decode(StoryFormPack.self, from: data)) != nil
        case .storyConsequencePack: valid = (try? decoder.decode(StoryConsequencePack.self, from: data)) != nil
        case .radioStationPack: valid = (try? decoder.decode(RadioStationPack.self, from: data)) != nil
        case .sentenceBuilderPack: valid = (try? decoder.decode(SentenceBuilderPack.self, from: data)) != nil
        case .casebook: valid = (try? decoder.decode(WorldEventCasebook.self, from: data)) != nil
        case .media: valid = !data.isEmpty
        }
        guard valid else { throw MonthlyIssueDeliveryError.invalidAsset(asset.id) }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func isManagedTarget(_ target: URL, inside documentsURL: URL) -> Bool {
        let base = documentsURL.standardizedFileURL.path
        let candidate = target.standardizedFileURL.path
        return candidate.hasPrefix(base + "/")
            && target.lastPathComponent.hasPrefix(MonthlyIssueDeliveryPolicy.managedFilePrefix)
    }
}

enum MonthlyIssueMediaPath {
    /// iOS can move the sandbox during an app update. Resolve only our two
    /// monthly directories into the current sandbox; never follow a saved
    /// container path into another app or let traversal escape these roots.
    static func resolving(_ path: String, supportDirectory: URL? = nil) -> String {
        guard path.hasPrefix("/"),
              let marker = path.range(of: "/Library/Application Support/", options: .backwards),
              let support = supportDirectory ?? FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first else { return path }
        let suffix = String(path[marker.upperBound...])
        let parts = suffix.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let isDownload = parts.count == 3
            && parts[0] == MonthlyIssueDeliveryPolicy.supportDirectoryName
            && parts[1] == MonthlyIssueDeliveryPolicy.managedContentDirectoryName
            && parts[2].hasPrefix(MonthlyIssueDeliveryPolicy.managedFilePrefix)
        let isKeepsake = parts.count == 2 && parts[0] == "MonthlyIssueKeepsakes"
            && URL(fileURLWithPath: parts[1]).deletingPathExtension().lastPathComponent.count == 64
            && URL(fileURLWithPath: parts[1]).deletingPathExtension().lastPathComponent.allSatisfy(\.isHexDigit)
        guard isDownload || isKeepsake,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return path }
        let root = support.appendingPathComponent(parts.dropLast().joined(separator: "/"))
            .resolvingSymlinksInPath().standardizedFileURL
        let target = root.appendingPathComponent(parts.last!).resolvingSymlinksInPath().standardizedFileURL
        guard target.deletingLastPathComponent() == root else { return path }
        return target.path
    }
}

/// A kept mark is publication material, separate from the disposable download.
/// Use content-addressed copies so keeping the same art on many leaves is cheap.
enum MonthlyIssueRetainedMedia {
    static func retaining(_ asset: IlluminationAsset, fileManager: FileManager = .default) throws -> IlluminationAsset {
        guard asset.assetName.hasPrefix("/") else { return asset }
        let path = MonthlyIssueMediaPath.resolving(asset.assetName,
            supportDirectory: fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        let source = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        guard let managed = MonthlyIssueDeliveryPolicy.managedContentDirectory(fileManager: fileManager)?.resolvingSymlinksInPath(),
              source.path.hasPrefix(managed.path + "/"),
              source.lastPathComponent.hasPrefix(MonthlyIssueDeliveryPolicy.managedFilePrefix),
              let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MonthlyIssueDeliveryError.unsafeFileName(asset.id)
        }
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let root = support.appendingPathComponent("MonthlyIssueKeepsakes", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent(hash).appendingPathExtension(source.pathExtension)
        if !fileManager.fileExists(atPath: target.path) { try data.write(to: target, options: .atomic) }
        var kept = asset
        kept.assetName = target.path
        kept.placementTrigger = nil
        return kept
    }
}
