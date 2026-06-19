import Foundation

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
}

struct WorldEventCalendar: Codable, Equatable {
    var startMonth: Int
    var startDay: Int
    var durationDays: Int
    var recurrence: WorldEventRecurrence
    var startYear: Int? = nil

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

struct WorldEventPhase: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var startsAtProgress: Double
    var packetLine: String
    var intensity: Int
    var lexicalRules: [WorldEventLexicalRule]
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
    var visualTreatment: String?
    var fieldworkPrompt: String
    var fieldworkPlaceholder: String
    var fieldworkRewardLine: String
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
    var outcome: WorldEventOutcome?
    var effects: [WorldEventEffect]
    var packet: EventInfluencePacket

    var influenceLine: String {
        let outcomeLine = outcome.map { "\nOutcome pressure: \($0.title). \($0.packetLine)" } ?? ""
        return """
        WORLD EVENT: \(title) — \(subtitle)
        Phase: \(phase.title) (\(Int(progress * 100))% through)
        \(packet.logline)
        \(phase.packetLine)
        Player touches recorded: \(playerTouchCount)
        Atmosphere: \(packet.atmosphere)
        \(outcomeLine)
        """
    }
}

enum WorldEventRegistry {
    static let userPackFileSuffix = ".reenchantedevents.json"

    static let bundledPacks: [WorldEventPack] = [
        WorldEventPack(
            id: "living-almanac",
            displayName: "The Living Almanac",
            version: 1,
            author: "The Book",
            availability: .bundledFree,
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
                      var pack = try? decoder.decode(WorldEventPack.self, from: data) else {
                    return nil
                }
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

    static let dictionaryRebellion = WorldEvent(
        id: "dictionary-rebellion",
        title: "The Dictionary Rebellion",
        subtitle: "Words are peeling off their definitions and gathering in the air.",
        calendar: WorldEventCalendar(startMonth: 9, startDay: 8, durationDays: 14, recurrence: .annual),
        phases: [
            WorldEventPhase(
                id: "omen",
                title: "Alphabet Weather",
                startsAtProgress: 0,
                packetLine: "Small words begin hesitating before they mean what they meant yesterday.",
                intensity: 3,
                lexicalRules: [
                    WorldEventLexicalRule(id: "ordinary-slips", words: ["ordinary", "fine", "later"], instruction: "Let these words feel unstable, as if they are considering resignation.")
                ]
            ),
            WorldEventPhase(
                id: "outbreak",
                title: "Definitions Peel",
                startsAtProgress: 0.22,
                packetLine: "Definitions are visibly separating from words; the Book treats language as a living protest.",
                intensity: 7,
                lexicalRules: [
                    WorldEventLexicalRule(id: "rebellious-abstractions", words: ["should", "normal", "useful"], instruction: "When these ideas appear, notice who benefits from the old definition.")
                ]
            ),
            WorldEventPhase(
                id: "assembly",
                title: "The Thesaurus Assembly",
                startsAtProgress: 0.58,
                packetLine: "Synonyms form factions. Antonyms exchange polite but furious letters.",
                intensity: 8,
                lexicalRules: [
                    WorldEventLexicalRule(id: "synonym-politics", words: ["meaning", "memory", "promise"], instruction: "Let near-meanings disagree without collapsing into a single answer.")
                ]
            ),
            WorldEventPhase(
                id: "afterimage",
                title: "New Definitions Dry",
                startsAtProgress: 0.86,
                packetLine: "The uprising is settling into revised margins; a few liberated words refuse to go back.",
                intensity: 4,
                lexicalRules: [
                    WorldEventLexicalRule(id: "afterimage-vocabulary", words: ["attention", "wonder", "home"], instruction: "Let one familiar word carry a new, earned shade of meaning.")
                ]
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
            WorldEventEffect(id: "boost-book-notices", target: .pageType, targetID: BookPageType.bookNotices.rawValue, tags: ["book", "notices", "words"], boost: 12, reason: "The Book is watching vocabulary misbehave."),
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
            visualTreatment: "loose letters, lifted labels, marginal correction marks",
            fieldworkPrompt: "Choose one ordinary word you used today. Give it a better definition, based on what it actually did.",
            fieldworkPlaceholder: "Example: Fine - a word that covers a room before anyone has checked whether the windows are open.",
            fieldworkRewardLine: "A kept definition becomes testimony. The rebellion will remember that you did not let the word go back unchanged."
        )
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
                ]
            ),
            WorldEventPhase(
                id: "hearing",
                title: "The Midnight Hearing",
                startsAtProgress: 0.35,
                packetLine: "The Book asks neglected scraps what they saw before they were folded away.",
                intensity: 7,
                lexicalRules: [
                    WorldEventLexicalRule(id: "accounting-words", words: ["proof", "owed", "kept"], instruction: "Let evidence feel practical, intimate, and a little luminous.")
                ]
            ),
            WorldEventPhase(
                id: "verdict",
                title: "Verdict in Blue Ink",
                startsAtProgress: 0.78,
                packetLine: "The trial resolves into annotations: what mattered, what was missed, what may return.",
                intensity: 5,
                lexicalRules: [
                    WorldEventLexicalRule(id: "verdict-words", words: ["remember", "return", "true"], instruction: "Let the final note leave a useful mark rather than a punishment.")
                ]
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
            WorldEventEffect(id: "paper-trial-notices", target: .pageType, targetID: BookPageType.bookNotices.rawValue, tags: ["archive", "paper"], boost: 8, reason: "The Book is docketing scraps."),
            WorldEventEffect(id: "paper-trial-letters", target: .pageType, targetID: BookPageType.letter.rawValue, tags: ["archive", "letters"], boost: 6, reason: "Letters are admissible evidence.")
        ],
        packet: EventInfluencePacket(
            logline: "An archived paper trial is open: ordinary scraps are being treated as witnesses to the reader's real life.",
            atmosphere: "blue-black ink, folded receipts, moonlit paper clips, a docket written in cramped marginalia",
            storyInstruction: "Let the scene notice practical paper without turning it into bureaucracy; every scrap remembers a hand.",
            classInstruction: "Frame the lesson around evidence, attention, and the difference between proof and meaning.",
            letterInstruction: "Let the sender mention one ordinary record they kept longer than expected.",
            monthlyEditionLine: "The Starlit Paper Trial left a few scraps glowing in the month's binding.",
            visualTreatment: "blue ink rulings, exhibit tags, moonlit paper edges",
            fieldworkPrompt: "Find one scrap of paper nearby. What does it prove happened?",
            fieldworkPlaceholder: "Example: A receipt proves I crossed town for soup and came home with thyme.",
            fieldworkRewardLine: "A scrap admitted into evidence becomes part of the archive. The Book will not treat it as trash."
        )
    )
}

enum WorldEventResolver {
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

    static func archivedEvents(
        now: Date,
        day: BookDay? = nil,
        inputs: BookSourceInputs = .empty,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [ResolvedWorldEvent] {
        WorldEventRegistry.enabledEvents(fileManager: fileManager).compactMap { packID, event in
            guard let interval = event.calendar.archivedInterval(asOf: now, calendar: calendar) else { return nil }
            return resolvedEvent(packID: packID, event: event, interval: interval, now: interval.end, day: day, inputs: inputs)
        }
        .sorted { $0.endsAt > $1.endsAt }
    }

    private static func resolvedEvent(
        packID: String,
        event: WorldEvent,
        interval: DateInterval,
        now: Date,
        day: BookDay?,
        inputs: BookSourceInputs
    ) -> ResolvedWorldEvent {
        let duration = max(1, interval.duration)
        let rawProgress = now.timeIntervalSince(interval.start) / duration
        let progress = min(1, max(0, rawProgress))
        let phase = phase(for: event, progress: progress)
        let touchCount = playerTouchCount(for: event, interval: interval, day: day, inputs: inputs)
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
            outcome: outcome,
            effects: event.effects + (outcome?.effects ?? []),
            packet: event.packet
        )
    }

    private static func phase(for event: WorldEvent, progress: Double) -> WorldEventPhase {
        event.phases
            .sorted { $0.startsAtProgress < $1.startsAtProgress }
            .last { progress >= $0.startsAtProgress }
            ?? event.phases.first
            ?? WorldEventPhase(id: "active", title: "Active", startsAtProgress: 0, packetLine: event.packet.logline, intensity: 5, lexicalRules: [])
    }

    private static func outcome(for event: WorldEvent, touchCount: Int) -> WorldEventOutcome? {
        event.outcomes
            .sorted { $0.minimumTouchCount < $1.minimumTouchCount }
            .last { touchCount >= $0.minimumTouchCount }
    }

    private static func playerTouchCount(
        for event: WorldEvent,
        interval: DateInterval,
        day: BookDay?,
        inputs: BookSourceInputs
    ) -> Int {
        var pagesByID: [String: BookPage] = [:]
        for page in inputs.days.flatMap(\.pages) {
            pagesByID[page.id] = page
        }
        for page in day?.pages ?? [] {
            pagesByID[page.id] = page
        }
        return pagesByID.values.filter { page in
            page.createdAt >= interval.start
                && page.createdAt < interval.end
                && page.tags.contains("event:\(event.id)")
        }.count
    }
}

extension Array where Element == ResolvedWorldEvent {
    var influencePacket: String {
        guard !isEmpty else { return "" }
        return map(\.influenceLine).joined(separator: "\n\n")
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
