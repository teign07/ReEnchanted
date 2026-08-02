import Foundation

// MARK: - The Grey's claim on living memory

enum GreyPageThreatStatus: String, Codable, Equatable {
    case marked
    case fading
    case rescued
    case erased
}

struct GreyPageThreat: Identifiable, Codable, Equatable {
    var id: String
    var pageID: String
    var pageTitle: String
    var pageExcerpt: String
    var markedAt: Date
    var deadline: Date?
    var status: GreyPageThreatStatus
    var resolvedAt: Date?
    var rescueLine: String?

    var isActive: Bool { status == .marked || status == .fading }
}

struct GreyPageThreatLedger: Codable, Equatable {
    var threats: [GreyPageThreat] = []
    var lastMarkedAt: Date?

    static let empty = GreyPageThreatLedger()

    var activeThreat: GreyPageThreat? {
        threats.first(where: \.isActive)
    }

    var erasedPageIDs: Set<String> {
        Set(threats.filter { $0.status == .erased }.map(\.pageID))
    }
}

enum GreyPageThreatEngine {
    static let sourceID = "grey-page-threat"
    static let rescueWindow: TimeInterval = 72 * 3_600
    static let markCooldown: TimeInterval = 7 * 86_400
    static let minimumPageAge: TimeInterval = 2 * 86_400
    static let minimumKeptPages = 8

    /// Reconciles only the living-memory ledger. The supplied archive Pages are
    /// evidence and candidates; this engine never mutates or deletes them.
    @discardableResult
    static func reconcile(
        ledger: inout GreyPageThreatLedger,
        pages: [BookPage],
        mayThreaten: Bool,
        distressActive: Bool,
        protectedPageIDs: Set<String> = [],
        now: Date = Date()
    ) -> [String] {
        guard !distressActive else { return [] }
        var changes: [String] = []

        for index in ledger.threats.indices
        where ledger.threats[index].status == .fading {
            guard let deadline = ledger.threats[index].deadline, now > deadline else { continue }
            ledger.threats[index].status = .erased
            ledger.threats[index].resolvedAt = now
            changes.append("erased:\(ledger.threats[index].id)")
        }

        guard ledger.activeThreat == nil,
              mayThreaten,
              pages.count >= minimumKeptPages else {
            return changes
        }
        if let lastMarkedAt = ledger.lastMarkedAt,
           now.timeIntervalSince(lastMarkedAt) < markCooldown {
            return changes
        }

        let previouslyClaimed = Set(ledger.threats.map(\.pageID))
        let eligible = pages
            .filter { now.timeIntervalSince($0.createdAt) >= minimumPageAge }
            .filter { !protectedPageIDs.contains($0.id) }
            .filter { !previouslyClaimed.contains($0.id) }
            .filter {
                $0.sourceID != sourceID
                    && $0.type != .welcome
                    && $0.type != .helpTips
                    && $0.type != .rest
            }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id < $1.id
            }
        guard let page = eligible.first else { return changes }

        let title = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? page.type.title
        let excerptSource = page.archivePreviewText
            ?? page.userInput.nonEmpty
            ?? page.playerReply.nonEmpty
            ?? page.promptText
        let threat = GreyPageThreat(
            id: "grey-page-\(page.id)",
            pageID: page.id,
            pageTitle: String(title.prefix(120)),
            pageExcerpt: String(excerptSource.prefix(240)),
            markedAt: now,
            deadline: nil,
            status: .marked,
            resolvedAt: nil,
            rescueLine: nil
        )
        ledger.threats.append(threat)
        ledger.lastMarkedAt = now
        changes.append("marked:\(threat.id)")
        return changes
    }

    @discardableResult
    static func activate(
        threatID: String,
        in ledger: inout GreyPageThreatLedger,
        now: Date = Date()
    ) -> GreyPageThreat? {
        guard let index = ledger.threats.firstIndex(where: { $0.id == threatID }) else { return nil }
        if ledger.threats[index].status == .marked {
            ledger.threats[index].status = .fading
            ledger.threats[index].deadline = now.addingTimeInterval(rescueWindow)
        }
        return ledger.threats[index]
    }

    @discardableResult
    static func resolve(
        threatID: String,
        rescued: Bool,
        line: String?,
        in ledger: inout GreyPageThreatLedger,
        now: Date = Date()
    ) -> GreyPageThreat? {
        guard let index = ledger.threats.firstIndex(where: { $0.id == threatID }),
              ledger.threats[index].isActive else { return nil }
        ledger.threats[index].status = rescued ? .rescued : .erased
        ledger.threats[index].resolvedAt = now
        ledger.threats[index].rescueLine =
            line?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return ledger.threats[index]
    }
}

enum BookFamiliarityRutEngine {
    enum Phase: String, Equatable {
        case clear
        case familiar
        case rote
    }

    struct Assessment: Equatable {
        var phase: Phase
        var flatteningScore: Int
        var evidence: [String]

        var mayThreaten: Bool { phase == .rote }
    }

    /// Continued exposure is only the prerequisite. It cannot become the
    /// accusation. The later Grey requires at least two independent signs that
    /// the reader's use has become flatter while use remains active.
    static func assess(
        pages: [BookPage],
        readerLearning: ReaderLearningModel,
        attentionProbes: AttentionProbeLedger,
        selfFacts: [SelfFact] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Assessment {
        let ordered = pages.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        let braids = ordered.filter { $0.type == .bookOfYou }
        guard let firstBraid = braids.first,
              braids.count >= 24,
              now.timeIntervalSince(firstBraid.createdAt) >= 42 * 86_400 else {
            return Assessment(phase: .clear, flatteningScore: 0, evidence: [])
        }

        let recentCutoff = now.addingTimeInterval(-21 * 86_400)
        let recentBraids = braids.filter { $0.createdAt >= recentCutoff }
        guard recentBraids.count >= 6 else {
            // Time away is not Grey evidence. Without sustained exposure there
            // is nothing here to diagnose and nothing to punish.
            return Assessment(
                phase: .familiar,
                flatteningScore: 0,
                evidence: ["continued-exposure-not-established"]
            )
        }

        var score = 0
        var evidence: [String] = []

        let souvenirs = ordered.filter { $0.type == .souvenir }
        if readerLanguageFlattened(in: souvenirs) {
            score += 2
            evidence.append("reader-language-flattened")
        }

        if sessionsBecameClockwork(
            pages: ordered,
            now: now,
            calendar: calendar
        ) {
            score += 1
            evidence.append("session-hours-became-uniform")
        }

        if knockResponsesBecameReflexive(attentionProbes) {
            score += 1
            evidence.append("knock-latency-became-reflexive")
        }

        if correctionWentQuiet(
            readerLearning: readerLearning,
            recentBraids: recentBraids,
            now: now
        ) {
            score += 1
            evidence.append("previous-correction-went-quiet")
        }

        if plainPageWentUntouched(pages: ordered, now: now) {
            score += 1
            evidence.append("formerly-used-plain-page-went-untouched")
        }

        if memoryOfBookWentGrey(selfFacts) {
            score += 2
            evidence.append("memory-of-the-book-went-grey")
        }

        return Assessment(
            phase: score >= 3 && evidence.count >= 2 ? .rote : .familiar,
            flatteningScore: score,
            evidence: evidence
        )
    }

    private static func readerLanguageFlattened(in souvenirs: [BookPage]) -> Bool {
        guard souvenirs.count >= 16 else { return false }
        let early = Array(souvenirs.prefix(8))
        let recent = Array(souvenirs.suffix(8))
        let earlyWords = early.map { words(in: $0.userInput) }
        let recentWords = recent.map { words(in: $0.userInput) }
        let earlyMean = Double(earlyWords.reduce(0) { $0 + $1.count }) / 8
        let recentMean = Double(recentWords.reduce(0) { $0 + $1.count }) / 8
        let earlyTokens = earlyWords.flatMap { $0 }
        let recentTokens = recentWords.flatMap { $0 }
        guard earlyTokens.count >= 40, recentTokens.count >= 24 else { return false }
        let earlyDiversity = Double(Set(earlyTokens).count) / Double(earlyTokens.count)
        let recentDiversity = Double(Set(recentTokens).count) / Double(recentTokens.count)
        return recentMean <= earlyMean * 0.68
            || recentDiversity <= earlyDiversity * 0.72
    }

    private static func sessionsBecameClockwork(
        pages: [BookPage],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let authored = pages.filter {
            $0.origin == .userAuthored
                && $0.createdAt >= now.addingTimeInterval(-45 * 86_400)
        }
        let distinctDays = Set(authored.map { BookDay.id(for: $0.createdAt, calendar: calendar) })
        guard authored.count >= 18, distinctDays.count >= 10 else { return false }
        let hours = Dictionary(grouping: authored) {
            calendar.component(.hour, from: $0.createdAt)
        }
        let dominantTwoHourCount = (0..<24).map { hour in
            (hours[hour]?.count ?? 0) + (hours[(hour + 1) % 24]?.count ?? 0)
        }.max() ?? 0
        return Double(dominantTwoHourCount) / Double(authored.count) >= 0.78
    }

    private static func knockResponsesBecameReflexive(
        _ ledger: AttentionProbeLedger
    ) -> Bool {
        let samples = ledger.receipts
            .filter { $0.cycle == ledger.currentCycle }
            .suffix(20)
        guard samples.count >= 15 else { return false }
        let latencies = samples.map {
            max(0, $0.answeredAt.timeIntervalSince($0.scheduledAt))
        }
        let mean = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.reduce(0) { partial, latency in
            partial + pow(latency - mean, 2)
        } / Double(latencies.count)
        return mean <= 10 && sqrt(variance) <= 4
    }

    private static func correctionWentQuiet(
        readerLearning: ReaderLearningModel,
        recentBraids: [BookPage],
        now: Date
    ) -> Bool {
        guard recentBraids.count >= 10 else { return false }
        let corrections = readerLearning.events.filter {
            $0.type == .bookOfYou && ($0.action == .missed || $0.tags.contains("braid-missed-me"))
        }
        guard !corrections.isEmpty else { return false }
        return corrections.allSatisfy {
            now.timeIntervalSince($0.occurredAt) > 60 * 86_400
        }
    }

    private static func plainPageWentUntouched(
        pages: [BookPage],
        now: Date
    ) -> Bool {
        let plainPages = pages.filter { $0.type == .plainPage }
        guard plainPages.count >= 2 else { return false }
        let recentCutoff = now.addingTimeInterval(-45 * 86_400)
        let recentAuthored = pages.filter {
            $0.origin == .userAuthored && $0.createdAt >= recentCutoff
        }
        return recentAuthored.count >= 15
            && !plainPages.contains(where: { $0.createdAt >= recentCutoff })
    }

    private static func memoryOfBookWentGrey(_ selfFacts: [SelfFact]) -> Bool {
        let recent = selfFacts
            .filter { $0.questionID.hasPrefix("book-memory-probe-") }
            .sorted { $0.updatedAt < $1.updatedAt }
            .suffix(3)
        guard recent.count >= 2 else { return false }
        let greyAnswers = recent.filter { fact in
            let answer = fact.answer.lowercased()
            return answer.contains("familiar")
                || answer.contains("can't name")
                || answer.contains("cannot name")
                || answer == "nothing"
                || answer.contains("remember nothing")
        }
        return greyAnswers.count >= 2
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 }
    }
}


struct RadioTrack: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var artist: String
    var assetName: String?
    var durationSeconds: Int?
    var moodTags: [String]
    /// Optional authoring hooks for alive curation. Existing catalogs decode
    /// without them; future stations can favor or gate tracks by world state.
    var weight: Int? = nil
    var conditions: RadioBanter.Conditions? = nil
    /// A short, authored, non-lyric trace which may tint later fiction.
    var meaning: RadioTrackMeaning? = nil

    var resolvedWeight: Int { max(1, weight ?? 1) }
}

struct RadioTrackMeaning: Codable, Equatable {
    var themeTags: [String]?
    var imageTags: [String]?
    var ordinaryLifeCue: String?

    func sanitized() -> RadioTrackMeaning {
        RadioTrackMeaning(
            themeTags: Self.clean(tags: themeTags, limit: 4, characterLimit: 48),
            imageTags: Self.clean(tags: imageTags, limit: 4, characterLimit: 48),
            ordinaryLifeCue: Self.clean(line: ordinaryLifeCue, characterLimit: 160)
        )
    }

    private static func clean(tags: [String]?, limit: Int, characterLimit: Int) -> [String]? {
        let values = (tags ?? []).compactMap { clean(line: $0, characterLimit: characterLimit) }
        return values.isEmpty ? nil : Array(values.prefix(limit))
    }

    private static func clean(line: String?, characterLimit: Int) -> String? {
        guard let line else { return nil }
        let controls = CharacterSet.controlCharacters.union(.newlines)
        let cleaned = line.components(separatedBy: controls).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let bounded = String(cleaned.prefix(characterLimit)).trimmingCharacters(in: .whitespaces)
        return bounded.isEmpty ? nil : bounded
    }
}

struct RadioTrackPlayReceipt: Codable, Equatable {
    var stationID: String
    var trackID: String
    var startedAt: Date
}

struct RadioNarrativeEcho: Equatable {
    var stationID: String
    var trackID: String
    var startedAt: Date
    var meaning: RadioTrackMeaning
}

enum RadioNarrativeEchoPrompt {
    static func section(_ echo: RadioNarrativeEcho?) -> String {
        guard let echo else { return "" }
        let images = (echo.meaning.imageTags ?? []).prefix(1).joined(separator: ", ")
        let themes = (echo.meaning.themeTags ?? []).prefix(2).joined(separator: ", ")
        let cue = echo.meaning.ordinaryLifeCue ?? ""
        let trace = [images, themes, cue].filter { !$0.isEmpty }.joined(separator: "; ")
        guard !trace.isEmpty else { return "" }
        return """


        RECENT SONG TRACE — AUTHORED NON-LYRIC ATMOSPHERE, NOT EVIDENCE:
        \(trace)
        It may lend at most one image, motion, or cadence only when the lived material already invites it. Never quote or reconstruct lyrics; never name the song, artist, or station; never infer what the reader liked, felt, chose, or did. It cannot own the title, moral, or ending.
        """
    }
}

struct RadioStationEffect: Codable, Equatable {
    var pageType: BookPageType
    var boost: Int
    var reason: String
}

/// A spoken DJ break between songs. Audio-backed (via `assetName`, resolved the
/// same way tracks are) with a `caption` fallback so the dial still "talks" as
/// text when no audio is bundled yet. Categories let the playout clock rotate so
/// you never hear two sponsor reads back to back; `conditions` let a clip wait
/// for the right world-state (dusk, the grey rising, a festival, a long streak)
/// so the station feels alive instead of shuffled.
struct RadioBanter: Codable, Equatable, Identifiable {
    enum Category: String, Codable, CaseIterable {
        case stationID      // callsign / "you're listening to…"
        case transition     // song-to-song hand-off (may reference track names)
        case sponsor        // fae brand read
        case gossip         // The Bleed / cast rumor
        case news           // world-state "current events"
        case network        // cross-station hand-off
    }

    /// All-optional gate. A banter only plays when every set condition is met,
    /// so authoring is additive: leave a field nil to "don't care."
    struct Conditions: Codable, Equatable {
        /// Restrict to parts of the day: "dawn", "day", "dusk", "night".
        var timeOfDay: [String]?
        /// Only when Routine's grey is at/above this 0–100 pressure.
        var minGrey: Int?
        /// Only when the grey is at/below this (bright-day lines).
        var maxGrey: Int?
        /// Only during an active festival window.
        var festivalOnly: Bool?
        /// Only after the reader has listened this many distinct days.
        var minListeningDays: Int?
        /// Calendar weekday numbers (1 = Sunday ... 7 = Saturday).
        var weekdays: [Int]?
        /// Require at least one of these page types in the recent kept-page window.
        var pageTypes: [BookPageType]?
        /// Minimum recent kept pages among `pageTypes`, or across all recent pages
        /// if `pageTypes` is nil.
        var minRecentPagesOfType: Int?
        /// Require at least one recently kept page from any of these sources.
        var sourceIDs: [String]?
        /// Require at least one recently kept page carrying any of these tags.
        var sourceTags: [String]?
        /// Minimum number of pages kept today.
        var minKeptToday: Int?
        /// Require at least one current weather tag such as "rain", "cold", or "bright".
        var weatherTags: [String]?
        /// Require that the most recent kept page is one of these types.
        var lastKeptPageTypes: [BookPageType]?
        /// Only while one of these world events is active (e.g. the Dictionary
        /// Rebellion). Gates banters to a content-pack season. The host must
        /// populate `RadioWorldContext.activeWorldEventIDs` for this to fire; until
        /// then, banters carrying this condition stay silent (no leak).
        var activeWorldEventIDs: [String]?

        init(
            timeOfDay: [String]? = nil,
            minGrey: Int? = nil,
            maxGrey: Int? = nil,
            festivalOnly: Bool? = nil,
            minListeningDays: Int? = nil,
            weekdays: [Int]? = nil,
            pageTypes: [BookPageType]? = nil,
            minRecentPagesOfType: Int? = nil,
            sourceIDs: [String]? = nil,
            sourceTags: [String]? = nil,
            minKeptToday: Int? = nil,
            weatherTags: [String]? = nil,
            lastKeptPageTypes: [BookPageType]? = nil,
            activeWorldEventIDs: [String]? = nil
        ) {
            self.timeOfDay = timeOfDay
            self.minGrey = minGrey
            self.maxGrey = maxGrey
            self.festivalOnly = festivalOnly
            self.minListeningDays = minListeningDays
            self.weekdays = weekdays
            self.pageTypes = pageTypes
            self.minRecentPagesOfType = minRecentPagesOfType
            self.sourceIDs = sourceIDs
            self.sourceTags = sourceTags
            self.minKeptToday = minKeptToday
            self.weatherTags = weatherTags
            self.lastKeptPageTypes = lastKeptPageTypes
            self.activeWorldEventIDs = activeWorldEventIDs
        }

        var isUnconditional: Bool {
            timeOfDay == nil && minGrey == nil && maxGrey == nil
                && festivalOnly == nil && minListeningDays == nil && weekdays == nil
                && pageTypes == nil && minRecentPagesOfType == nil
                && sourceIDs == nil && sourceTags == nil && minKeptToday == nil
                && weatherTags == nil && lastKeptPageTypes == nil
                && activeWorldEventIDs == nil
        }
    }

    /// Where a song-bound transition sits relative to its track.
    enum Placement: String, Codable {
        case intro   // plays right BEFORE the bound song ("Coming up, Folktronica…")
        case outro   // plays right AFTER the bound song ("That was Mossy Footsteps…")
    }

    var id: String
    var category: Category
    /// Spoken-audio asset (e.g. "DJ_thornwave_id_03"); nil = caption-only.
    var assetName: String?
    /// Text shown in the status line and used as the spoken fallback.
    var caption: String
    var conditions: Conditions?
    /// Relative likelihood within its category (default 1). Higher = more often.
    var weight: Int?
    /// If set, this break is bound to a specific song (a `RadioTrack.id`) and
    /// only plays adjacent to it. Used for song-aware transitions.
    var trackID: String? = nil
    /// For a bound break, whether it leads into the song (`intro`) or follows it
    /// (`outro`). nil + a `trackID` means "either side is fine."
    var placement: Placement? = nil

    var resolvedWeight: Int { max(1, weight ?? 1) }
    var isBound: Bool { trackID != nil }

    /// Imported DJ batches sometimes arrive with only production placeholders.
    /// This is intentionally a label, not an invented transcript.
    var readerFacingCaption: String {
        let lowered = caption.lowercased()
        if lowered.contains("unscheduled ") || lowered.contains("audio-backed clip") {
            return "A local station break is playing. Its words have not been transcribed yet."
        }
        return caption
    }

    /// Is this break allowed to play given the song that just ended and the one
    /// queued next? Unbound breaks are always allowed; bound ones must sit on the
    /// correct side of their song.
    func placementFits(justFinishedTrackID: String?, upcomingTrackID: String?) -> Bool {
        guard let trackID else { return true }
        switch placement {
        case .intro: return trackID == upcomingTrackID
        case .outro: return trackID == justFinishedTrackID
        case nil:    return trackID == justFinishedTrackID || trackID == upcomingTrackID
        }
    }
}

/// Live world snapshot the banter selector reads to decide what's appropriate
/// right now. Built by the app from existing systems (NothingTide, festival
/// windows, the clock, the listening streak) — pure data, no app types.
struct RadioPageContext: Equatable {
    var keptToday: Int
    var recentPageTypeCounts: [BookPageType: Int]
    var recentSourceIDs: Set<String>
    var recentTags: Set<String>
    var lastKeptPageType: BookPageType?
    var weatherTags: Set<String>
    /// Recent significant fictional facts. These are generated locally from
    /// signed consequence receipts, never from reader prose or inferred mood.
    var storyConsequenceEchoes: [StoryConsequenceReceipt]

    init(
        keptToday: Int = 0,
        recentPageTypeCounts: [BookPageType: Int] = [:],
        recentSourceIDs: Set<String> = [],
        recentTags: Set<String> = [],
        lastKeptPageType: BookPageType? = nil,
        weatherTags: Set<String> = [],
        storyConsequenceEchoes: [StoryConsequenceReceipt] = []
    ) {
        self.keptToday = keptToday
        self.recentPageTypeCounts = recentPageTypeCounts
        self.recentSourceIDs = Set(recentSourceIDs.map(Self.normalize))
        self.recentTags = Set(recentTags.map(Self.normalize))
        self.lastKeptPageType = lastKeptPageType
        self.weatherTags = Set(weatherTags.map(Self.normalize))
        self.storyConsequenceEchoes = storyConsequenceEchoes
    }

    var recentKeptCount: Int {
        recentPageTypeCounts.values.reduce(0, +)
    }

    func recentCount(matching types: [BookPageType]?) -> Int {
        guard let types, !types.isEmpty else { return recentKeptCount }
        return types.reduce(0) { total, type in total + (recentPageTypeCounts[type] ?? 0) }
    }

    func hasRecentSource(in sourceIDs: [String]) -> Bool {
        sourceIDs.map(Self.normalize).contains { recentSourceIDs.contains($0) }
    }

    func hasRecentTag(in tags: [String]) -> Bool {
        tags.map(Self.normalize).contains { recentTags.contains($0) }
    }

    func hasWeatherTag(in tags: [String]) -> Bool {
        tags.map(Self.normalize).contains { weatherTags.contains($0) }
    }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func weatherTags(
        weather: WeatherSourceSignal?,
        enchanted: EnchantedWeatherSignal? = nil
    ) -> Set<String> {
        let text = [
            weather?.phrase,
            weather?.forecast,
            weather?.conditionSymbolName,
            weather?.currentTemperature,
            enchanted?.summary,
            enchanted?.enchantified,
            enchanted?.symbolName
        ].compactMap { $0?.lowercased() }.joined(separator: " ")
        guard !text.isEmpty else { return [] }

        var tags = Set<String>()
        func add(_ tag: String, when words: [String]) {
            if words.contains(where: { text.contains($0) }) {
                tags.insert(tag)
            }
        }
        add("storm", when: ["storm", "thunder", "bolt"])
        add("rain", when: ["rain", "drizzle", "shower"])
        add("snow", when: ["snow", "sleet", "ice", "freezing"])
        add("fog", when: ["fog", "mist", "haze"])
        add("wind", when: ["wind", "gust", "breez"])
        add("cloud", when: ["cloud", "overcast"])
        add("bright", when: ["clear", "sun", "bright"])
        add("hot", when: ["hot", "heat", "warm", "8", "9"])
        add("cold", when: ["cold", "chill", "freez", "snow", "ice", "3", "2", "1"])
        return tags
    }
}

/// Live world snapshot the banter selector reads to decide what's appropriate
/// right now. Built by the app from existing systems (NothingTide, festival
/// windows, the clock, the listening streak, recent kept pages, weather) —
/// pure data, no app services.
struct RadioWorldContext: Equatable {
    /// "dawn" | "day" | "dusk" | "night"
    var timeOfDay: String
    /// The Rut's grey pressure, 0–100.
    var grey: Int
    var festivalActive: Bool
    /// Distinct days the active station has been heard.
    var listeningDays: Int
    /// Calendar weekday number (1 = Sunday ... 7 = Saturday), when known.
    var weekday: Int?
    /// Recent kept-page and weather summary for prerecorded reactive DJ clips.
    var pageContext: RadioPageContext
    /// IDs of world events active right now, so banters can gate to a content-pack
    /// season (e.g. ["dictionary-rebellion"]). Defaults empty; populate from the
    /// app's active world events when rebellion banters are wired.
    var activeWorldEventIDs: [String]
    /// The current session score, when one exists. Radio remains fully alive
    /// without it and receives only bounded Page motifs, never reader prose.
    var experienceProgram: BookExperienceProgram?

    init(
        timeOfDay: String = "day",
        grey: Int = 0,
        festivalActive: Bool = false,
        listeningDays: Int = 0,
        weekday: Int? = nil,
        pageContext: RadioPageContext = RadioPageContext(),
        activeWorldEventIDs: [String] = [],
        experienceProgram: BookExperienceProgram? = nil
    ) {
        self.timeOfDay = timeOfDay
        self.grey = grey
        self.festivalActive = festivalActive
        self.listeningDays = listeningDays
        self.weekday = weekday
        self.pageContext = pageContext
        self.activeWorldEventIDs = activeWorldEventIDs
        self.experienceProgram = experienceProgram
    }

    /// Convenience: derive the time-of-day band from a date.
    static func band(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<8:   return "dawn"
        case 8..<17:  return "day"
        case 17..<21: return "dusk"
        default:      return "night"
        }
    }

    func satisfies(_ conditions: RadioBanter.Conditions?) -> Bool {
        guard let conditions else { return true }
        if let times = conditions.timeOfDay, !times.contains(timeOfDay) { return false }
        if let minGrey = conditions.minGrey, grey < minGrey { return false }
        if let maxGrey = conditions.maxGrey, grey > maxGrey { return false }
        if conditions.festivalOnly == true, !festivalActive { return false }
        if let minDays = conditions.minListeningDays, listeningDays < minDays { return false }
        if let weekdays = conditions.weekdays {
            guard let weekday, weekdays.contains(weekday) else { return false }
        }
        if let pageTypes = conditions.pageTypes, !pageTypes.isEmpty,
           pageContext.recentCount(matching: pageTypes) == 0 {
            return false
        }
        if let minimum = conditions.minRecentPagesOfType,
           pageContext.recentCount(matching: conditions.pageTypes) < minimum {
            return false
        }
        if let sourceIDs = conditions.sourceIDs, !sourceIDs.isEmpty,
           !pageContext.hasRecentSource(in: sourceIDs) {
            return false
        }
        if let tags = conditions.sourceTags, !tags.isEmpty,
           !pageContext.hasRecentTag(in: tags) {
            return false
        }
        if let minimum = conditions.minKeptToday, pageContext.keptToday < minimum {
            return false
        }
        if let tags = conditions.weatherTags, !tags.isEmpty,
           !pageContext.hasWeatherTag(in: tags) {
            return false
        }
        if let lastTypes = conditions.lastKeptPageTypes, !lastTypes.isEmpty {
            guard let last = pageContext.lastKeptPageType, lastTypes.contains(last) else { return false }
        }
        if let eventIDs = conditions.activeWorldEventIDs, !eventIDs.isEmpty,
           !eventIDs.contains(where: { activeWorldEventIDs.contains($0) }) {
            return false
        }
        return true
    }
}

struct RadioStation: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var frequency: Double
    var subtitle: String
    var hostEntityID: String?
    var packID: String?
    var unlockRule: String
    var moodTags: [String]
    var signalLine: String
    var tracks: [RadioTrack]
    var interludeTitles: [String]
    /// Optional audio bed that can be inserted between playout items for stations
    /// whose format depends on atmosphere, such as hidden pirate static.
    var interstitialAssetName: String? = nil
    var interstitialTitle: String? = nil
    var effects: [RadioStationEffect]
    /// Rich DJ breaks. Optional + defaulted so existing stations and older
    /// `.reenchantedradio.json` packs (which predate banters) still decode.
    var banters: [RadioBanter]? = nil

    var displayFrequency: String {
        String(format: "%.1f", frequency)
    }

    var hostDisplayName: String {
        guard let hostEntityID else { return "Station DJ" }
        return NarrativePackRegistry.entities.first { $0.id == hostEntityID }?.name ?? "Station DJ"
    }

    /// Banters if authored; otherwise synthesize lightweight ones from the
    /// legacy `interludeTitles` so the playout clock always has something to say.
    var resolvedBanters: [RadioBanter] {
        if let banters, !banters.isEmpty { return banters }
        return interludeTitles.enumerated().map { index, line in
            RadioBanter(
                id: "\(id)-interlude-\(index)",
                category: .transition,
                assetName: nil,
                caption: line,
                conditions: nil,
                weight: nil
            )
        }
    }

    var isCore: Bool {
        packID == nil
    }

    /// A one-line "what's playing" descriptor for generation atmosphere.
    var atmosphereLine: String {
        "\(title) (\(displayFrequency)) — \(subtitle)"
    }
}

/// Shared prompt fragment so any generated narrative page can be faintly
/// colored by the tuned station without naming it. Pure-local; no model call.
enum RadioAtmosphere {
    static func promptSection(_ line: String?) -> String {
        guard let line, !line.isEmpty else { return "" }
        return """


        WHAT'S PLAYING:
        \(line)
        Let the station faintly color the tone, imagery, and rhythm of this page — never as a thesis. Do not name the station or mention a radio unless a kept page already did.
        """
    }
}

struct RadioStationPack: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var stations: [RadioStation]
}

/// Accumulated listening for one station — the substrate that lets a station
/// become a remembered companion (a listening constellation) and earn
/// held-station effects.
struct StationListening: Codable, Equatable {
    var dayKeys: [String] = []
    var sessions: Int = 0
    var firstHeardAt: Date?
    var lastHeardAt: Date?

    var daysHeard: Int { dayKeys.count }
}

struct RadioPlaybackState: Codable, Equatable {
    var activeStationID: String?
    var startedAt: Date?
    var lastTunedAt: Date?
    var lastTrackID: String?
    var tuningNoise: Double
    // Optional so older saved states (without this key) still decode.
    var listening: [String: StationListening]?
    /// Recently played banter ids (newest last), so the selector avoids
    /// repeating a break the reader just heard. Optional for back-compat.
    var recentBanterIDs: [String]?
    /// Songs heard in the current station run (newest last). Once every
    /// available song has played, the next recording starts a fresh run.
    /// Optional so older saves continue to decode.
    var recentTrackIDs: [String]?

    /// How many recent banters to remember. This is deliberately large enough
    /// to hold a station's authored catalog: banter selection behaves like a
    /// shuffled bag, so freely eligible clips are exhausted before one returns.
    /// Context- and song-bound clips can still enter whenever their gate opens.
    static let banterHistoryLimit = 256

    static let off = RadioPlaybackState()

    init(
        activeStationID: String? = nil,
        startedAt: Date? = nil,
        lastTunedAt: Date? = nil,
        lastTrackID: String? = nil,
        tuningNoise: Double = 0,
        listening: [String: StationListening]? = nil,
        recentBanterIDs: [String]? = nil,
        recentTrackIDs: [String]? = nil
    ) {
        self.activeStationID = activeStationID
        self.startedAt = startedAt
        self.lastTunedAt = lastTunedAt
        self.lastTrackID = lastTrackID
        self.tuningNoise = max(0, min(1, tuningNoise))
        self.listening = listening
        self.recentBanterIDs = recentBanterIDs
        self.recentTrackIDs = recentTrackIDs
    }

    /// Record a banter as just played, trimming the ring buffer.
    mutating func recordBanter(_ banterID: String) {
        var history = recentBanterIDs ?? []
        history.removeAll { $0 == banterID }
        history.append(banterID)
        if history.count > RadioPlaybackState.banterHistoryLimit {
            history.removeFirst(history.count - RadioPlaybackState.banterHistoryLimit)
        }
        recentBanterIDs = history
    }

    mutating func recordTrack(_ trackID: String, historyLimit: Int = 3) {
        var history = recentTrackIDs ?? []
        history.removeAll { $0 == trackID }
        history.append(trackID)
        let limit = max(1, historyLimit)
        if history.count > limit {
            history.removeFirst(history.count - limit)
        }
        recentTrackIDs = history
        lastTrackID = trackID
    }

    mutating func recordTrack(_ trackID: String, stationTrackIDs: [String]) {
        let validIDs = Set(stationTrackIDs)
        guard !validIDs.isEmpty else {
            recordTrack(trackID)
            return
        }

        var run = (recentTrackIDs ?? []).filter { validIDs.contains($0) }
        if validIDs.isSubset(of: Set(run)) {
            run = []
        }

        run.removeAll { $0 == trackID }
        run.append(trackID)
        recentTrackIDs = run
        lastTrackID = trackID
    }

    /// Record that the reader is listening to a station today (idempotent per day).
    mutating func recordListening(stationID: String, now: Date = Date(), calendar: Calendar = .current) {
        let key = BookDay.id(for: now, calendar: calendar)
        var map = listening ?? [:]
        var entry = map[stationID] ?? StationListening()
        entry.sessions += 1
        if entry.firstHeardAt == nil { entry.firstHeardAt = now }
        entry.lastHeardAt = now
        if !entry.dayKeys.contains(key) { entry.dayKeys.append(key) }
        map[stationID] = entry
        listening = map
    }

    /// Distinct days a station has been heard.
    func daysHeard(stationID: String) -> Int {
        listening?[stationID]?.daysHeard ?? 0
    }

    var isTuned: Bool {
        activeStationID?.isEmpty == false
    }
}

enum RadioStationRegistry {
    static let userPackFileSuffix = ".reenchantedradio.json"

    static func narrativeEcho(
        receipt: RadioTrackPlayReceipt?,
        unlockedPackIDs: Set<String> = PackEntitlements.ownedPackIDs,
        now: Date = Date()
    ) -> RadioNarrativeEcho? {
        guard let receipt,
              now.timeIntervalSince(receipt.startedAt) >= 0,
              now.timeIntervalSince(receipt.startedAt) <= 24 * 60 * 60,
              let station = station(id: receipt.stationID, unlockedPackIDs: unlockedPackIDs),
              let track = station.tracks.first(where: { $0.id == receipt.trackID }),
              let meaning = track.meaning?.sanitized(),
              meaning.themeTags != nil || meaning.imageTags != nil || meaning.ordinaryLifeCue != nil else { return nil }
        return RadioNarrativeEcho(stationID: station.id, trackID: track.id, startedAt: receipt.startedAt, meaning: meaning)
    }

    private static let authoredBundledMeanings: [String: RadioTrackMeaning] = {
        func meaning(_ themes: [String], _ image: String, _ cue: String) -> RadioTrackMeaning {
            RadioTrackMeaning(themeTags: themes, imageTags: [image], ordinaryLifeCue: cue)
        }
        return [
            "fae-fi-mossy-footsteps": meaning(
                ["unnoticed paths", "soft adventure"],
                "damp green between paving stones",
                "Notice the tiniest path underfoot."
            ),
            "fae-fi-folktronica": meaning(
                ["old and new", "handmade play"],
                "wooden rhythm beside blinking circuitry",
                "Find where something handmade and something humming share a table."
            ),
            "fae-fi-ink-hands": meaning(
                ["making", "traces"],
                "smudged fingertips beside a half-finished note",
                "Notice what your hands have quietly changed."
            ),
            "fae-fi-art-of-the-glint": meaning(
                ["second sight", "found beauty"],
                "a brief flash on an ordinary edge",
                "Let one reflected spark interrupt the obvious."
            ),
            "fae-fi-crushed-pixies": meaning(
                ["aftermath", "resilient mischief"],
                "bright dust beside a scuffed shoe",
                "Look for what stayed bright after a small mess."
            ),
            "fae-fi-fae-fi": meaning(
                ["unofficial signals", "playful wonder"],
                "radio static caught in clover",
                "Listen for the room's faintest unofficial broadcast."
            ),
            "fae-fi-mossy-groove": meaning(
                ["patient growth", "unhurried play"],
                "moss keeping the shape of a stone",
                "Find a green thing keeping time without hurry."
            ),
            "fae-fi-to-the-adventure": meaning(
                ["beginnings", "small courage"],
                "a coat pocket waiting beside the door",
                "Let one familiar route contain an unplanned turn."
            ),
            "fae-fi-pages-rising": meaning(
                ["readiness", "unfinished possibility"],
                "loose paper lifting in a window draft",
                "Notice which unfinished thing wants your hand."
            ),
            "fae-fi-look-twice": meaning(
                ["ordinary wonder", "second sight"],
                "a familiar object seen sideways",
                "Let one commonplace thing earn a second look."
            ),
            "mothlight-the-page-came-through": meaning(
                ["arrival", "quiet messages"],
                "folded paper waiting under a door",
                "Notice what reached you without ceremony."
            ),
            "mothlight-fae-dust": meaning(
                ["dusk", "fading wonder"],
                "dust turning visible in the last light",
                "Look where evening makes a small thing newly visible."
            ),
            "mothlight-lost-candy": meaning(
                ["sweet memory", "small losses"],
                "a wrapper at the bottom of a pocket",
                "Notice one small thing carrying a whole afternoon."
            ),
            "mothlight-in-the-story": meaning(
                ["presence", "ordinary narrative"],
                "a chair left at an unexpected angle",
                "Let one ordinary scene have a beginning and a turn."
            ),
            "mothlight-noticing-text-flowers": meaning(
                ["language", "close attention"],
                "hand lettering curling around a shop sign",
                "Read one nearby sign as if each word was deliberately planted."
            ),
            "mothlight-tales-end": meaning(
                ["closure", "what remains"],
                "a bookmark resting after the last page",
                "Notice what lingers after something has properly ended."
            ),
            "mothlight-book-jumping": meaning(
                ["curiosity", "side doors"],
                "a finger keeping two pages open",
                "Let one nearby title lead you somewhere unplanned."
            ),
            "mothlight-porchlight-fading": meaning(
                ["home", "parting light"],
                "a porch light entering the blue hour",
                "Watch one familiar light change the space around it."
            ),
            "mothlight-afternoon-chapters": meaning(
                ["ordinary time", "gentle pause"],
                "a rectangle of sun crossing a table",
                "Give the next ten minutes one concrete chapter detail."
            ),
            "mothlight-astonishing": meaning(
                ["ordinary wonder", "bittersweet presence"],
                "dust turning gold in a window",
                "Look at one ordinary thing as if it will not be here forever."
            ),
            "mothlight-the-longer-road": meaning(
                ["slow attention", "ordinary wonder"],
                "lamplight finding puddles on the longer way home",
                "Take the longer road when you can, and notice one thing it gives back."
            ),
            "thornwave-bramble-bass": meaning(
                ["boundaries", "contained energy"],
                "a hedge holding the noise of the street",
                "Notice one boundary that has a rhythm of its own."
            ),
            "thornwave-nocturnal-faerie-lounge": meaning(
                ["night company", "shelter"],
                "condensation on a late glass",
                "Find the coziest honest corner of the evening."
            ),
            "thornwave-whispering-shadows": meaning(
                ["ambiguity", "patient attention"],
                "a shadow changing shape across a wall",
                "Let one dim object remain unexplained for a minute."
            ),
            "thornwave-long-titles-in-the-dark": meaning(
                ["naming", "mystery"],
                "spine lettering disappearing into low light",
                "Read one ordinary label as if it opens a side door."
            ),
            "thornwave-duskthorn-rising": meaning(
                ["fierce beauty", "change at dusk"],
                "a thorn silhouette against the lowering light",
                "Notice what becomes clearer as the light lowers."
            ),
            "thornwave-no-conflict-no-story": meaning(
                ["friction", "choice"],
                "two objects competing for the same hook",
                "Name the smallest tension in the room without solving it."
            ),
            "thornwave-magic-margins": meaning(
                ["peripheral wonder", "annotations"],
                "a handwritten note beside a receipt",
                "Look at the edge of one page or plan, not its center."
            ),
            "thornwave-velvet-arrears": meaning(
                ["obligation", "soft menace"],
                "a velvet pouch holding an overdue coin",
                "Notice one postponed thing by its physical trace."
            ),
            "thornwave-goblin-market": meaning(
                ["barter", "strange value"],
                "mismatched coins beside a handwritten price",
                "Ask what one ordinary object would demand in trade."
            ),
            "thornwave-mossy-night": meaning(
                ["night growth", "stillness"],
                "wet green holding to stone after dark",
                "Find one living texture that night almost hides."
            ),
            "the-bleed-intercept": meaning(
                ["interruption", "hidden messages"],
                "a red tuning needle between stations",
                "Notice one stray phrase or signal that does not quite belong."
            ),
            "midnight-bindery-thread": meaning(
                ["continuity", "repair"],
                "thread pulled through a paper seam",
                "Find two loose things already trying to connect."
            ),
            "goblin-market-after-hours": meaning(
                ["mischief", "value beyond money"],
                "a coin vanishing under late counter light",
                "Watch one exchange and notice what is not money."
            )
        ]
    }()

    private static func authoredBundledMeaning(for track: RadioTrack) -> RadioTrackMeaning {
        authoredBundledMeanings[track.id] ?? RadioTrackMeaning(
            themeTags: Array(track.moodTags.prefix(3)),
            imageTags: ["one concrete detail held in passing light"],
            ordinaryLifeCue: "Let one small ordinary detail keep its own strange pace."
        )
    }

    static let coreStations: [RadioStation] = [
        RadioStation(
            id: "fae-fi",
            title: "Fae-Fi",
            frequency: 88.3,
            subtitle: "Sun-dappled beats and dandelion synths from faeries who have plainly had too much nectar.",
            hostEntityID: "penny-blackletter",
            packID: nil,
            unlockRule: "core",
            moodTags: ["fae", "lo-fi", "bright", "playful", "daydream"],
            signalLine: "The signal arrives giggling, tasting of clover honey and warm afternoons.",
            tracks: [
                RadioTrack(
                    id: "fae-fi-mossy-footsteps",
                    title: "Mossy Footsteps",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiMossyFootsteps",
                    durationSeconds: 121,
                    moodTags: ["bright", "playful"]
                ),
                RadioTrack(
                    id: "fae-fi-folktronica",
                    title: "Folktronica",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiFolktronica",
                    durationSeconds: 116,
                    moodTags: ["bright", "playful", "folktronica"]
                ),
                RadioTrack(
                    id: "fae-fi-ink-hands",
                    title: "Ink Hands",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiInkHands",
                    durationSeconds: 117,
                    moodTags: ["bright", "playful", "ink"]
                ),
                RadioTrack(
                    id: "fae-fi-art-of-the-glint",
                    title: "Art of the Glint",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiArtOfTheGlint",
                    durationSeconds: 96,
                    moodTags: ["bright", "playful", "glint"]
                ),
                RadioTrack(
                    id: "fae-fi-crushed-pixies",
                    title: "Crushed Pixies",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiCrushedPixies",
                    durationSeconds: 134,
                    moodTags: ["bright", "playful", "pixies"]
                ),
                RadioTrack(
                    id: "fae-fi-fae-fi",
                    title: "Fae Fi",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiFaeFi",
                    durationSeconds: 185,
                    moodTags: ["bright", "playful", "wonder", "signal"]
                ),
                RadioTrack(
                    id: "fae-fi-mossy-groove",
                    title: "Mossy Groove",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiMossyGroove",
                    durationSeconds: 146,
                    moodTags: ["bright", "playful"]
                ),
                RadioTrack(
                    id: "fae-fi-to-the-adventure",
                    title: "To the Adventure",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiToTheAdventure",
                    durationSeconds: 126,
                    moodTags: ["bright", "playful", "adventure"]
                ),
                RadioTrack(
                    id: "fae-fi-pages-rising",
                    title: "Pages Rising",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiPagesRising",
                    durationSeconds: 94,
                    moodTags: ["bright", "playful", "pages"]
                ),
                RadioTrack(
                    id: "fae-fi-look-twice",
                    title: "Look Twice",
                    artist: "Fae-Fi",
                    assetName: "RadioFaeFiLookTwice",
                    durationSeconds: 249,
                    moodTags: ["bright", "playful", "wonder", "ordinary"]
                )
            ],
            interludeTitles: [
                "A pixie remixes a birdsong without asking the bird.",
                "Someone trades a perfect afternoon for one more loop."
            ],
            effects: [
                RadioStationEffect(pageType: .wonderCompass, boost: 8, reason: "Fae-Fi makes small adventures easier to notice."),
                RadioStationEffect(pageType: .souvenir, boost: 8, reason: "Bright loops help catch one true particular."),
                RadioStationEffect(pageType: .festival, boost: 6, reason: "The station is always a little in a feasting mood.")
            ],
            // DJ'd by Penny Blackletter. Drop matching audio (any of m4a/mp3/wav)
            // into the RadioAudio bundle folder or Documents/RadioPacks; until
            // then the captions play as on-screen breaks. See
            // docs/RadioDJBanters.md for the full scripts.
            banters: [
                RadioBanter(
                    id: "faefi-id-01", category: .stationID,
                    assetName: "DJ_faefi_id_01",
                    caption: "You've reached Fae-Fi. Eighty-eight point three on the Academy band. I keep the records here. Today's record is: the pixies are fine, the pixies are too fine, please send help. Anyway. Music.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "faefi-id-02", category: .stationID,
                    assetName: "DJ_faefi_id_02",
                    caption: "This is Penny Blackletter, and against my professional judgment, Fae-Fi — eighty-eight three — sun-dappled beats from faeries who have plainly had too much nectar. I'm taking notes. For The Bleed. It's mostly exclamation points.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "faefi-id-03", category: .stationID,
                    assetName: "DJ_faefi_id_03",
                    caption: "Fae-Fi, eighty-eight point three. One honest detail can save a day. Today's, filed for the record: the light came back. Here's a song about it.",
                    conditions: nil, weight: nil
                ),
                // Song-bound transitions. An OUTRO plays right after its song;
                // an INTRO plays right before its song. Record the audio to the
                // matching assetName and it slots into the correct seam.
                RadioBanter(
                    id: "faefi-outro-mossyfootsteps", category: .transition,
                    assetName: "DJ_faefi_transition_mossyfootsteps_outro",
                    caption: "That was \"Mossy Footsteps.\" I checked — there was no one there. There is never anyone there. I've started a folder.",
                    conditions: nil, weight: nil,
                    trackID: "fae-fi-mossy-footsteps", placement: .outro
                ),
                RadioBanter(
                    id: "faefi-intro-folktronica", category: .transition,
                    assetName: "DJ_faefi_transition_folktronica_intro",
                    caption: "Coming up — \"Folktronica.\" A bird wrote the hook. The bird has filed a complaint. I've filed the complaint. We're all very busy here.",
                    conditions: nil, weight: nil,
                    trackID: "fae-fi-folktronica", placement: .intro
                ),
                RadioBanter(
                    id: "faefi-outro-mossygroove", category: .transition,
                    assetName: "DJ_faefi_transition_mossygroove_outro",
                    caption: "You just heard \"Mossy Groove.\" A patch of clover is dancing and will not stop, and I've, regrettably, transcribed all of it.",
                    conditions: nil, weight: nil,
                    trackID: "fae-fi-mossy-groove", placement: .outro
                ),
                RadioBanter(
                    id: "faefi-sponsor-thistledown", category: .sponsor,
                    assetName: "DJ_faefi_sponsor_01",
                    caption: "Fae-Fi runs on dandelion synths and Thistledown & Co., purveyors of pocket-sized weather. Caught in the grey? A Thistledown sunbeam fits in any coat. That part, I checked. It's true.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "faefi-sponsor-cloverhoney", category: .sponsor,
                    assetName: "DJ_faefi_sponsor_02",
                    caption: "Today's brightness is brought to you by the Clover Honey Collective. Their slogan arrived far too polished, so I rewrote it: the afternoon's only as warm as you bothered to taste. Ask at the Goblin Market for the jar that hums. It does hum. I've the recording.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dawn", "day"]), weight: nil
                ),
                RadioBanter(
                    id: "faefi-gossip-tuesday", category: .gossip,
                    assetName: "DJ_faefi_gossip_01",
                    caption: "You get this before the edition goes to press: somebody in your year traded a perfectly good Tuesday for one more loop of this exact song. Filed under \"evidence the music is working.\" Flawless decision. No notes.",
                    conditions: RadioBanter.Conditions(weekdays: [3]), weight: nil
                ),
                RadioBanter(
                    id: "faefi-gossip-window", category: .gossip,
                    assetName: "DJ_faefi_gossip_02",
                    caption: "From my desk at The Bleed — the Wonder Compass has pointed at the same window all week. I don't print speculation. But if it's your window… that's not speculation. That's a fact you've been avoiding. Go see.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "faefi-news-grey", category: .news,
                    assetName: "DJ_faefi_news_01",
                    caption: "Filed this morning, off Today's Sky: the grey lost three feet of ground. Cause — and I checked twice — somebody noticed one true particular and wrote it down. That's the whole arithmetic of this place. Here's a song.",
                    conditions: RadioBanter.Conditions(maxGrey: 60),
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-news-festival", category: .news,
                    assetName: "DJ_faefi_news_02",
                    caption: "Festival weather incoming; the Academy's in a feasting mood. I'll be the one in the corner, cataloguing joy as it happens, which is, I'm told, not the point of joy. Bring a souvenir. Catch one real thing. Don't tell the grey where you keep it.",
                    conditions: RadioBanter.Conditions(festivalOnly: true),
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-pages-souvenir-cluster", category: .gossip,
                    assetName: "DJ_faefi_pages_souvenir_01",
                    caption: "Production note from Fae-Fi: the receiver is picking up a run of souvenirs. Tiny true things, properly filed. Penny Blackletter approves this extremely irresponsible form of journalism.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.souvenir],
                        minRecentPagesOfType: 2
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "faefi-pages-wonder-morning", category: .news,
                    assetName: "DJ_faefi_pages_wonder_morning_01",
                    caption: "Morning bulletin: the Wonder Compass is bright enough to annoy the furniture. If you kept one of its pages, congratulations. The day now has a suspiciously useful hinge.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dawn", "day"],
                        pageTypes: [.wonderCompass],
                        minRecentPagesOfType: 1
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "faefi-weather-bright", category: .news,
                    assetName: "DJ_faefi_weather_bright_01",
                    caption: "Weather desk says bright. My desk says suspiciously bright. Either way, Fae-Fi recommends catching one real detail before the afternoon spends it all.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dawn", "day"],
                        weatherTags: ["bright"]
                    ),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-pages-souvenir-collector", category: .gossip,
                    assetName: "DJ_faefi_pages_souvenir_02",
                    caption: "Three souvenirs in a week. I'm not saying you're building a case file, but the evidence is starting to look deliberate.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.souvenir],
                        minRecentPagesOfType: 3
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "faefi-weather-bright-morning", category: .news,
                    assetName: "DJ_faefi_weather_bright_morning_02",
                    caption: "Filed under obvious: the sun is out, the band is clean, and somewhere a dandelion synth just got ideas.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dawn", "day"],
                        weatherTags: ["bright"]
                    ),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-source-wonder-compass-morning", category: .news,
                    assetName: "DJ_faefi_source_wonder_compass_02",
                    caption: "Heavy Wonder Compass traffic this morning. Somebody's been practicing the looking. Let it go to your feet, not your head.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dawn", "day"],
                        sourceIDs: ["wonder-compass"]
                    ),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-pages-kept-today-busy", category: .news,
                    assetName: "DJ_faefi_pages_kept_today_busy_01",
                    caption: "Four pages kept before lunch. At this rate I'm going to need a bigger drawer. Slow down, or don't. I'll keep filing.",
                    conditions: RadioBanter.Conditions(minKeptToday: 4),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-festival-mandatory-brightness", category: .stationID,
                    assetName: "DJ_faefi_festival_window_01",
                    caption: "The almanac says it's a festival, and it's rarely wrong, which is annoying. Brightness is mandatory. Resistance will be noted.",
                    conditions: RadioBanter.Conditions(festivalOnly: true),
                    weight: 5
                ),
                RadioBanter(
                    id: "faefi-pages-body-fuel-care", category: .gossip,
                    assetName: "DJ_faefi_pages_body_fuel_care_01",
                    caption: "A couple of body and fuel pages in the recent file. Unglamorous. Also the truest things you've logged all week. Drink some water.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.body, .fuel],
                        minRecentPagesOfType: 2
                    ),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-listening-streak-loyal", category: .stationID,
                    assetName: "DJ_faefi_listening_streak_01",
                    caption: "Several days you've come back to this frequency. People call it habit. I file it under loyalty. The bright stuff remembers who showed up.",
                    conditions: RadioBanter.Conditions(minListeningDays: 4),
                    weight: 4
                ),
                RadioBanter(
                    id: "faefi-pages-illuminated-photo", category: .gossip,
                    assetName: "DJ_faefi_pages_illuminated_photo_01",
                    caption: "Someone's been gilding their own photographs. Gold leaf around an ordinary Tuesday. That's the whole trick. That's the entire grimoire.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.illuminatedPhoto],
                        minRecentPagesOfType: 1
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "faefi-class-glint", category: .news,
                    assetName: "DJ_faefi_class_glint_01",
                    caption: "Field note from Wing Four - the Glint Hall. Professor Boggle held up three ordinary objects under a lamp and asked which one changed the instant you described it exactly. That's the whole of Notice - the North direction. The Rut turns the world to wallpaper, and one specific, odd detail rips it down. I've filed it under \"doctrine disguised as a pun.\" Attend if you can. Bring something dull to look at.",
                    conditions: RadioBanter.Conditions(pageTypes: [.academyClass], minRecentPagesOfType: 1),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-club-marginalia", category: .gossip,
                    assetName: "DJ_faefi_club_marginalia_01",
                    caption: "The Marginalia Guild meets in the Corridor of Whispered Secrets, and I'll admit it's the one club I'd join twice. You annotate a book together and leave notes for whoever opens it next - sometimes fifty years next. The best conversation I ever had was with a stranger who read the same volume in 1974 and wrote one true thing in the margin. So leave a note. Someone not yet born is going to need it.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-talisman-wind-cipher", category: .news,
                    assetName: "DJ_faefi_talisman_wind_cipher_01",
                    caption: "Records request came back on the Wind Cipher - the Riddlewind talisman, which is, regrettably, my own Chapter's. It rearranges itself the moment two people look at it together, and it goes restless when it's left alone. Its whole belief is four words: life is a story we write together. Sentimental. Also, infuriatingly, true. I checked. Twice.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-cast-soren", category: .gossip,
                    assetName: "DJ_faefi_cast_soren_01",
                    caption: "Soren Ng left another clue in the stacks - a diagram, no signature, naturally, somewhere only patient people look. He trusts a map more than a declaration, and he leaves it unfinished on purpose so you become part of it. A map is an invitation, he says. Not an answer. I'd file a complaint about the lack of labels, but I suspect that's the point. Go find it.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-cast-wispwood", category: .gossip,
                    assetName: "DJ_faefi_cast_wispwood_01",
                    caption: "Sighting from the Spark Annex: Professor Wispwood apologized to a chipped mug before enchanting it. Out loud. Listed its visible facts first, then let it answer. Basic Enchantments, they call it - Everything Speaks, Everything's Poetry. The doctrine is just courtesy: ordinary matter answers when your attention turns polite. Try it on something you've stopped seeing. Mind the sparks in her sleeves.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-cast-gwendolyn", category: .news,
                    assetName: "DJ_faefi_cast_gwendolyn_01",
                    caption: "Gwendolyn Mythwright filed another impossible animal this morning, stamped like an overdue library form. She writes letters to fog. The fog, I'm told, has not yet replied. But she believes the improbable gets kinder the moment it's written down - that evidence makes wonder less lonely. If you kept a letter recently, she'd like a copy. For the archive. Obviously.",
                    conditions: RadioBanter.Conditions(pageTypes: [.letter], minRecentPagesOfType: 1),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-lore-compass-run", category: .news,
                    assetName: "DJ_faefi_lore_compass_run_01",
                    caption: "For the new readers, filed plainly: a Compass Run is four directions and one sentence. Notice to the North, Embark to the East, Sense to the South, Write to the West - and Rest at the Center, which isn't a direction at all but the ground the other four stand on. You walk one small adventure, then bind a single true souvenir line at the end. That's it. That's the magic. Embarrassingly repeatable.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-tip-belief", category: .news,
                    assetName: "DJ_faefi_tip_belief_01",
                    caption: "Grey's up at the edges this morning - Routine's been chewing on the unnoticed hours again. Here's the only counter-spell that's ever worked, and yes, I audited it: notice one true particular and write it down. Belief planted, grey pushed back. One detail. That's the whole arithmetic of this place. Plant one before lunch and prove me right. I do enjoy being right.",
                    conditions: RadioBanter.Conditions(minGrey: 30),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-club-compass-society", category: .gossip,
                    assetName: "DJ_faefi_club_compass_society_01",
                    caption: "Word from the Secret Garden of Prose: the Compass Society met again, Zara Finch holding it together by sheer attention, as ever. They read their one-sentence souvenirs aloud - and no one mocks a sentence in that room. Apparently saying it out loud makes it more real. I resisted the theory on principle. Then I tested it. Reader: it's real. If you've kept a souvenir, consider that your invitation.",
                    conditions: RadioBanter.Conditions(pageTypes: [.souvenir], minRecentPagesOfType: 1),
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-network-band", category: .network,
                    assetName: "DJ_faefi_network_band_01",
                    caption: "For the record, the whole dial, filed in order: eighty-eight three, me, against my will. Ninety point nine, Euphony at Mothlight. One-oh-three seven, Wicker on Thornwave. And if you can hear Villanelle's Bindery at ninety-nine three, or Melisande's Market at one-oh-five one, you've gone properly nocturnal. Spin the dial. Somebody's playing your weather.",
                    conditions: nil,
                    weight: 2
                ),
                // Unscheduled Penny breaks imported from the July 7 ElevenLabs
                // batch. They are deliberately ungated so they can run anywhere
                // in Fae-Fi's normal DJ cadence.
                RadioBanter(
                    id: "faefi-penny-banter-01", category: .stationID,
                    assetName: "DJ_faefi_penny_banter_01",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 1 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-02", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_02",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 2 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-03", category: .news,
                    assetName: "DJ_faefi_penny_banter_03",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 3 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-04", category: .network,
                    assetName: "DJ_faefi_penny_banter_04",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 4 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-05", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_05",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 5 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-06", category: .news,
                    assetName: "DJ_faefi_penny_banter_06",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 6 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-07", category: .stationID,
                    assetName: "DJ_faefi_penny_banter_07",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 7 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-08", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_08",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 8 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-09", category: .news,
                    assetName: "DJ_faefi_penny_banter_09",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 9 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-10", category: .network,
                    assetName: "DJ_faefi_penny_banter_10",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 10 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                // Unscheduled Penny breaks imported from the July 11
                // ElevenLabs batch. These are ordinary, ungated Fae-Fi
                // breaks and join the same random rotation as the prior set.
                RadioBanter(
                    id: "faefi-penny-banter-11", category: .stationID,
                    assetName: "DJ_faefi_penny_banter_11",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 11.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-12", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_12",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 12.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-13", category: .news,
                    assetName: "DJ_faefi_penny_banter_13",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 13.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-14", category: .network,
                    assetName: "DJ_faefi_penny_banter_14",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 14.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-15", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_15",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 15.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-16", category: .news,
                    assetName: "DJ_faefi_penny_banter_16",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 16.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-17", category: .stationID,
                    assetName: "DJ_faefi_penny_banter_17",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 17.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-18", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_18",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 18.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-19", category: .news,
                    assetName: "DJ_faefi_penny_banter_19",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 19.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-20", category: .network,
                    assetName: "DJ_faefi_penny_banter_20",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 20.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-21", category: .gossip,
                    assetName: "DJ_faefi_penny_banter_21",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 21.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-penny-banter-22", category: .news,
                    assetName: "DJ_faefi_penny_banter_22",
                    caption: "Unscheduled Penny Blackletter banter from the Fae-Fi records desk. Audio-backed clip 22.",
                    conditions: nil, weight: 3
                ),
                RadioBanter(
                    id: "faefi-psa-timetable", category: .news,
                    assetName: "DJ_faefi_psa_timetable_01",
                    caption: "Public notice from the records desk, since someone has to keep it straight. The Academy runs on bells: morning classes at nine, afternoon classes at one, and clubs gather at seven, lamps up. Five days of classes, a Saturday field run, and a Sunday that opens in another book entirely. It's all chalked on the board by the Inkworks. I keep the master copy. Naturally.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-curriculum", category: .news,
                    assetName: "DJ_faefi_psa_curriculum_01",
                    caption: "For new readers wondering what's actually taught here: the whole curriculum is one compass. North is Notice - Boggle's Art of the Glint, finding the one odd detail. East is Embark - Momort's Wayfinding, crossing a small threshold on purpose. South is Sense - Euphony's Synesthetic Resonance, reading a room through the body. West is Write - Villanelle's Ink-Binding, one true sentence that keeps. And the Center is Rest - Stonebrook's Quiet Hours. Not a direction. The ground the other four stand on. Filed, cross-referenced, and only mildly poetic.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-week-grid", category: .news,
                    assetName: "DJ_faefi_psa_week_grid_01",
                    caption: "The week, for the record, as briefly as I can manage. Mondays: the Glint, then Ink-Binding. Tuesdays: Wayfinding, then Resonance. Wednesdays: the Glint again, then Quiet Hours. Thursdays: Wayfinding, then Ink-Binding. Fridays: Resonance, then Basic Enchantments. Saturdays we run the full Compass in the field. Sundays open in the Vault of Doors, with Book Jumping. Clubs after dark. Don't make me repeat it - I'll only be more accurate.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-clubs", category: .news,
                    assetName: "DJ_faefi_psa_clubs_01",
                    caption: "Evening notice: the clubs are gathering - seven bells, lamps up. The Compass Society reads souvenirs aloud in the Secret Garden, where no one mocks a sentence. The Marginalia Guild annotates in the Corridor of Whispered Secrets, leaving notes for readers fifty years out. The Inkwright Society writes, shares, and burns it. And the Book Jumpers argue about what counts as a door. Find the room that fits your week. Tell them the records desk sent you.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-bleed-editions", category: .news,
                    assetName: "DJ_faefi_psa_bleed_editions_01",
                    caption: "Reminder from your editor, which is me: The Bleed runs two editions. The Morning paper lands before one bell - weather, the day's hinges, what the Book noticed overnight, and a column off one of your own shelves. The Evening edition sets after four - tomorrow's shape, tonight's margins, a fresh column. The quiet afternoon between them belongs to you. That part's intentional. Read both. There may be a quiz. There won't be. But there could be.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-office-hours", category: .news,
                    assetName: "DJ_faefi_psa_office_hours_01",
                    caption: "A notice I file gladly: the support faculty keep their doors open. Dr. Inkrest holds office hours for difficult pages - no appointment, just a chair, a lamp, and the time to name a hard thing slowly. Dr. Vellum takes the body's evidence - fuel, rest, recovery - and turns it into one small experiment with no shame attached. Neither will rush you. It's almost unnerving. If the day's gone heavy, that's what the doors are for.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-todays-sky", category: .news,
                    assetName: "DJ_faefi_psa_todays_sky_01",
                    caption: "Daily service note: Today's Sky posts each morning - the moon's phase and sign, the weather drawing in, and the nearest thing the heavens are up to. It's the one forecast that reads the inner weather as much as the outer. I check it before I file anything. The sky, annoyingly, is usually right.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-festivals-wheel", category: .news,
                    assetName: "DJ_faefi_psa_festivals_wheel_01",
                    caption: "Since readers keep asking what we celebrate: the Academy keeps the eight feasts of the Wheel. Imbolc, the First Stir, when the dark first turns. Ostara and Mabon, the two Rebalancings at the equinoxes. Beltane's Greenfire and Litha's Longest Day in the bright half. Lughnasadh, the First Harvest. And in the dark half - Samhain, the Thinning, and Yule, the Darkest Class, taught by candlelight. Eight feasts, one turning year. I keep the calendar. The calendar, for once, keeps itself.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "faefi-psa-moons-showers", category: .news,
                    assetName: "DJ_faefi_psa_moons_showers_01",
                    caption: "Also on the calendar, for the record: the moons and the falling stars. Every Full Moon is a Luminous Gathering - classes cancelled after sunset, everyone out reading by moonlight. Every New Moon, the Quiet Hours: candles only, the words holding their breath. And twice a year the ceiling goes clear for the meteors - the Perseids in August, the Falling Letters; the Geminids in December, the Winter Stars, when hot chocolate turns up in your hands unasked. I haven't determined who delivers it. The investigation remains open.",
                    conditions: nil,
                    weight: nil
                )
            ]
        ),
        RadioStation(
            id: "mothlight-beats",
            title: "Mothlight Beats",
            frequency: 90.9,
            subtitle: "Dusk-soft loops for the ache of lovely things ending, lit by wings against the lamp.",
            hostEntityID: "professor-eleanor-euphony",
            packID: nil,
            unlockRule: "core",
            moodTags: ["fae", "lo-fi", "wistful", "bittersweet", "memory", "dusk"],
            signalLine: "The static flutters at the glass like it remembers being a summer you lost.",
            tracks: [
                RadioTrack(
                    id: "mothlight-the-page-came-through",
                    title: "The Page Came Through",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightThePageCameThrough",
                    durationSeconds: 245,
                    moodTags: ["wistful", "memory"]
                ),
                RadioTrack(
                    id: "mothlight-fae-dust",
                    title: "Fae Dust",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightFaeDust",
                    durationSeconds: 93,
                    moodTags: ["wistful", "dusk"]
                ),
                RadioTrack(
                    id: "mothlight-lost-candy",
                    title: "Lost Candy",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightLostCandy",
                    durationSeconds: 102,
                    moodTags: ["wistful", "memory", "sweet"]
                ),
                RadioTrack(
                    id: "mothlight-in-the-story",
                    title: "In the Story",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightInTheStory",
                    durationSeconds: 136,
                    moodTags: ["wistful", "memory", "story"]
                ),
                RadioTrack(
                    id: "mothlight-noticing-text-flowers",
                    title: "Noticing Text Flowers",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightNoticingTextFlowers",
                    durationSeconds: 132,
                    moodTags: ["wistful", "memory", "text"]
                ),
                RadioTrack(
                    id: "mothlight-tales-end",
                    title: "Tale's End",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightTalesEnd",
                    durationSeconds: 144,
                    moodTags: ["wistful", "memory", "ending"]
                ),
                RadioTrack(
                    id: "mothlight-book-jumping",
                    title: "Book Jumping",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightBookJumping",
                    durationSeconds: 130,
                    moodTags: ["wistful", "memory", "book"]
                ),
                RadioTrack(
                    id: "mothlight-porchlight-fading",
                    title: "Porchlight, Fading",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightPorchlightFading",
                    durationSeconds: 120,
                    moodTags: ["wistful", "memory"]
                ),
                RadioTrack(
                    id: "mothlight-afternoon-chapters",
                    title: "Afternoon Chapters",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightAfternoonChapters",
                    durationSeconds: 152,
                    moodTags: ["wistful", "memory"]
                ),
                RadioTrack(
                    id: "mothlight-astonishing",
                    title: "Astonishing",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightAstonishing",
                    durationSeconds: 352,
                    moodTags: ["wistful", "memory", "ordinary", "wonder"]
                ),
                RadioTrack(
                    id: "mothlight-the-longer-road",
                    title: "The Longer Road",
                    artist: "Mothlight Beats",
                    assetName: "RadioMothlightTheLongerRoad",
                    durationSeconds: 234,
                    moodTags: ["wistful", "memory", "ordinary", "wonder"]
                )
            ],
            interludeTitles: [
                "A moth circles a light that went out an hour ago.",
                "Something hums the long way home."
            ],
            effects: [
                RadioStationEffect(pageType: .bookRemembered, boost: 10, reason: "Mothlight Beats coaxes old pages back into the light."),
                RadioStationEffect(pageType: .mood, boost: 7, reason: "The station listens for the bittersweet inner weather."),
                RadioStationEffect(pageType: .diary, boost: 6, reason: "Wistful loops draw the day's quieter pages out.")
            ],
            // DJ'd by Professor Eleanor Euphony. Drop matching audio into the
            // RadioAudio bundle folder; captions play until the files land.
            banters: [
                RadioBanter(
                    id: "mothlight-id-01", category: .stationID,
                    assetName: "DJ_mothlight_id_01",
                    caption: "…there. Now the room's in tune. This is Mothlight Beats, ninety point nine — Professor Euphony, holding the lamp for the ache of lovely things ending.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-id-02", category: .stationID,
                    assetName: "DJ_mothlight_id_02",
                    caption: "You're listening in the key of dusk. Mothlight, ninety point nine on the Academy band. I hear what you walked in carrying. We'll set it to music and it'll weigh less.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-id-03", category: .stationID,
                    assetName: "DJ_mothlight_id_03",
                    caption: "Mothlight Beats. The static remembers being a summer you lost — listen, it's a minor seventh. Stay in it with me a while.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-outro-thepagecamethrough", category: .transition,
                    assetName: "DJ_mothlight_transition_thepagecamethrough_outro",
                    caption: "That was \"The Page Came Through\"… they always do, in the end. The ones you thought were gone. Here's something to let settle on you.",
                    conditions: nil, weight: nil,
                    trackID: "mothlight-the-page-came-through", placement: .outro
                ),
                RadioBanter(
                    id: "mothlight-outro-faedust", category: .transition,
                    assetName: "DJ_mothlight_transition_faedust_outro",
                    caption: "\"Fae Dust,\" just then — yes, that itch behind your eyes is on purpose. Breathe. Mothlight has you.",
                    conditions: nil, weight: nil,
                    trackID: "mothlight-fae-dust", placement: .outro
                ),
                RadioBanter(
                    id: "mothlight-sponsor-porchlightmoth", category: .sponsor,
                    assetName: "DJ_mothlight_sponsor_01",
                    caption: "Mothlight glows by the grace of Porchlight & Moth, keepers of the lamp left on — for everyone you're still waiting up for. Find them at dusk, where the diary opens. Their bell rings in B-flat. I checked. Of course I checked.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-sponsor-theremembering", category: .sponsor,
                    assetName: "DJ_mothlight_sponsor_02",
                    caption: "Tonight's hush is held by The Remembering, a small shop in the Book Remembered. Bring them a page you thought you'd lost. They'll coax it back into the light — no charge. They simply like to hear it ring again.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-gossip-innerweather", category: .gossip,
                    assetName: "DJ_mothlight_gossip_01",
                    caption: "Penny's edition posted early tonight. She files it dry, so let me sing it: somebody's inner weather finally broke into rain. And where you come from, that's not a storm. That's how the garden gets watered. If it's you — it's allowed. It resolves.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-gossip-inkrestlamp", category: .gossip,
                    assetName: "DJ_mothlight_gossip_02",
                    caption: "A note carried in on the dusk: Dr. Inkrest left her office lamp on past hours again. If the day sat heavy as a low note, her door is the kind that opens. No appointment. Just weather, and a chair, and a lamp.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "mothlight-pages-memory-cluster", category: .gossip,
                    assetName: "DJ_mothlight_pages_memory_01",
                    caption: "I'm hearing several old pages close together. Not a haunting. A harmony. The Book remembers in chords when you give it enough notes.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.bookRemembered, .diary, .mood],
                        minRecentPagesOfType: 3
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "mothlight-pages-last-mood-night", category: .gossip,
                    assetName: "DJ_mothlight_pages_mood_night_01",
                    caption: "The last page you kept had weather inside it. That's not weakness. That's instrumentation. Stay with the note until it tells you where it resolves.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        lastKeptPageTypes: [.mood, .diary]
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-weather-rain", category: .news,
                    assetName: "DJ_mothlight_weather_rain_01",
                    caption: "Rain on the signal tonight. The roof is playing percussion, the lamp is keeping time, and every page you kept has softer edges.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        weatherTags: ["rain", "storm"]
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-pages-kept-today", category: .news,
                    assetName: "DJ_mothlight_pages_kept_today_01",
                    caption: "You've kept enough pages today for me to start humming under my breath. That's usually when the quiet ones come back. Leave the lamp on.",
                    conditions: RadioBanter.Conditions(minKeptToday: 4),
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-weather-rain-dusk", category: .news,
                    assetName: "DJ_mothlight_weather_rain_dusk_02",
                    caption: "Rain at dusk has a key signature. Minor, but a warm minor — the kind that holds you instead of dropping you. Let it play a while.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        weatherTags: ["rain"]
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-pages-memory-chord", category: .gossip,
                    assetName: "DJ_mothlight_pages_memory_cluster_02",
                    caption: "Old pages resonating together — three of them, the same note from different rooms. Not nostalgia. A chord your year is trying to complete.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.bookRemembered, .diary, .mood],
                        minRecentPagesOfType: 3
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "mothlight-pages-last-mood-warm", category: .gossip,
                    assetName: "DJ_mothlight_pages_last_mood_night_02",
                    caption: "The last page you kept is still warm. The feeling in it isn't asking to be fixed. Some things only want to be heard out to their natural end.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        lastKeptPageTypes: [.mood, .diary]
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-weather-fog-listen", category: .news,
                    assetName: "DJ_mothlight_weather_fog_01",
                    caption: "Fog tonight. Every edge sanded down to a hum. Don't strain to see through it. Fog is the world asking you to listen instead.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        weatherTags: ["fog"]
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-pages-letter-duet", category: .gossip,
                    assetName: "DJ_mothlight_pages_letter_01",
                    caption: "Someone's been keeping letters. Affection arranged for strings. If one arrives tonight, read it slow. Correspondence is a duet across time.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.letter, .illustration],
                        minRecentPagesOfType: 2
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-pages-kept-today-hum", category: .news,
                    assetName: "DJ_mothlight_pages_kept_today_gentle_01",
                    caption: "You've kept a good handful of pages today. I'm beginning to hum — that low, contented frequency a thing makes when it's being tended.",
                    conditions: RadioBanter.Conditions(minKeptToday: 4),
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-grey-keep-the-lamp", category: .news,
                    assetName: "DJ_mothlight_grey_gentle_01",
                    caption: "There's a greyness pressing on the band tonight. I won't pretend it away. But I'll keep the lamp on and the songs warm, and we'll wait it out together.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        minGrey: 35,
                        maxGrey: 70
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "mothlight-class-resonance", category: .news,
                    assetName: "DJ_mothlight_class_resonance_01",
                    caption: "Come to the Resonance Chamber some afternoon - Wing Three, where I ring a single glass bell and dim one lamp, and the whole room changes color without a wall ever moving. That's Synesthetic Resonance. The South direction. Sense. We practice hearing a colour, then naming the real evidence underneath it. The senses are serious instruments, you know. Bring yours. They're already tuned - you've only stopped listening.",
                    conditions: RadioBanter.Conditions(pageTypes: [.academyClass], minRecentPagesOfType: 1),
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-class-quiet-hours", category: .gossip,
                    assetName: "DJ_mothlight_class_quiet_hours_01",
                    caption: "Professor Stonebrook turned the hourglass on its side again tonight and let the unmoving sand become the entire lesson. Quiet Hours. The Center. Rest is not absence - it's the nervous system sorting the day so that tomorrow can happen at all. A pause chosen before collapse chooses it for you. If you've been running on the last of the light... his door is open. So is mine. Stay inside this song a while first.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-talisman-tide-glass", category: .news,
                    assetName: "DJ_mothlight_talisman_tide_glass_01",
                    caption: "My own Chapter's talisman came up tonight - the Tide Glass. Salt-bright, unpredictable, Tidecrest through and through. Consult it and it shows you a different hour every time. It forgets your plans on purpose. And its one belief is a small mercy: the moment is complete in itself. You don't have to finish the day to deserve it. Let this one be complete. Here.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-talisman-moss-clasp", category: .gossip,
                    assetName: "DJ_mothlight_talisman_moss_clasp_01",
                    caption: "They say the Moss Clasp - Mossbloom's quiet talisman - grows one new leaf whenever someone is truly listened to. Not spoken at. Listened to. It's older than its setting, and slow to act even when acting would be kind, because it trusts that the larger story is already being written. Someone, somewhere, is growing it a leaf right now, just by being heard. Be that for someone tonight.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-cast-inkrest", category: .gossip,
                    assetName: "DJ_mothlight_cast_inkrest_01",
                    caption: "Dr. Inkrest sets the chairs out before the feelings arrive - did you know that? She seats a hard page near a lamp before she asks it to speak a single word. A difficult feeling isn't a verdict in that office. It's a page. And a page can be named, and seated, and revised one hour at a time. If today sat heavy as a low note, her office hours are the kind of door that simply opens. No appointment. Just weather, a chair, and the lamp.",
                    conditions: RadioBanter.Conditions(pageTypes: [.inkrestOfficeHours, .mood, .diary], minRecentPagesOfType: 1),
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-cast-serenity", category: .gossip,
                    assetName: "DJ_mothlight_cast_serenity_01",
                    caption: "Serenity Brown swept through the Chamber today, left before the serious plan was finished, and somehow turned the detour into a rescue. She makes the loveliest chord in any room - the kind of laughter that changes its colour. Her whole creed is four words: joy is not a distraction. From magic, she means. From anything. If the day's gone solemn on you, she'd tell you to abandon the plan and go look at the sea. So would I.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-lore-book-remembered", category: .news,
                    assetName: "DJ_mothlight_lore_book_remembered_01",
                    caption: "The Book Remembered stirred tonight - an old page surfaced, one you were sure had gone quiet for good. That's how it works: give the Book enough notes and it begins to remember in chords. The quiet ones come back when the harmony is finally full enough to hold them. Don't reach for it. Just leave the lamp on and let it come the rest of the way. It always does, in the end.",
                    conditions: RadioBanter.Conditions(pageTypes: [.bookRemembered], minRecentPagesOfType: 1),
                    weight: 3
                ),
                // Unscheduled Euphony breaks imported from the July 7 ElevenLabs
                // batch. They are deliberately ungated so they can run anywhere
                // in Mothlight Beats' normal DJ cadence.
                RadioBanter(
                    id: "mothlight-euphony-banter-01", category: .stationID,
                    assetName: "DJ_mothlight_euphony_banter_01",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 1 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-02", category: .gossip,
                    assetName: "DJ_mothlight_euphony_banter_02",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 2 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-03", category: .news,
                    assetName: "DJ_mothlight_euphony_banter_03",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 3 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-04", category: .network,
                    assetName: "DJ_mothlight_euphony_banter_04",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 4 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-05", category: .stationID,
                    assetName: "DJ_mothlight_euphony_banter_05",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 5 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-06", category: .gossip,
                    assetName: "DJ_mothlight_euphony_banter_06",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 6 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-07", category: .news,
                    assetName: "DJ_mothlight_euphony_banter_07",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 7 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-08", category: .network,
                    assetName: "DJ_mothlight_euphony_banter_08",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 8 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-09", category: .stationID,
                    assetName: "DJ_mothlight_euphony_banter_09",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 9 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-10", category: .gossip,
                    assetName: "DJ_mothlight_euphony_banter_10",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 10 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-11", category: .news,
                    assetName: "DJ_mothlight_euphony_banter_11",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 11 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-euphony-banter-12", category: .network,
                    assetName: "DJ_mothlight_euphony_banter_12",
                    caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 12 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                // Unscheduled Professor Euphony breaks imported from the July
                // 11 ElevenLabs batch. All are ordinary, ungated Mothlight
                // breaks and belong to the normal random DJ rotation.
                RadioBanter(id: "mothlight-euphony-banter-13", category: .stationID, assetName: "DJ_mothlight_euphony_banter_13", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 13.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-14", category: .gossip, assetName: "DJ_mothlight_euphony_banter_14", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 14.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-15", category: .news, assetName: "DJ_mothlight_euphony_banter_15", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 15.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-16", category: .network, assetName: "DJ_mothlight_euphony_banter_16", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 16.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-17", category: .stationID, assetName: "DJ_mothlight_euphony_banter_17", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 17.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-18", category: .gossip, assetName: "DJ_mothlight_euphony_banter_18", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 18.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-19", category: .news, assetName: "DJ_mothlight_euphony_banter_19", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 19.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-20", category: .network, assetName: "DJ_mothlight_euphony_banter_20", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 20.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-21", category: .stationID, assetName: "DJ_mothlight_euphony_banter_21", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 21.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-22", category: .gossip, assetName: "DJ_mothlight_euphony_banter_22", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 22.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-23", category: .news, assetName: "DJ_mothlight_euphony_banter_23", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 23.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-24", category: .network, assetName: "DJ_mothlight_euphony_banter_24", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 24.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-25", category: .stationID, assetName: "DJ_mothlight_euphony_banter_25", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 25.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-26", category: .gossip, assetName: "DJ_mothlight_euphony_banter_26", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 26.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-27", category: .news, assetName: "DJ_mothlight_euphony_banter_27", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 27.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-28", category: .network, assetName: "DJ_mothlight_euphony_banter_28", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 28.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-29", category: .stationID, assetName: "DJ_mothlight_euphony_banter_29", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 29.", conditions: nil, weight: 3),
                RadioBanter(id: "mothlight-euphony-banter-30", category: .gossip, assetName: "DJ_mothlight_euphony_banter_30", caption: "Unscheduled Professor Euphony banter from Mothlight Beats. Audio-backed clip 30.", conditions: nil, weight: 3),
                RadioBanter(
                    id: "mothlight-psa-samhain", category: .news,
                    assetName: "DJ_mothlight_psa_samhain_01",
                    caption: "A note for the calendar's gentlest night: Samhain - the Thinning - comes at the turn of October, when the door between the kept and the lost stands a little ajar. The Book remembers more than usual then, and is kinder about it. Name someone you've lost, and one thing they left in your keeping. The veil is thin; be honest, be gentle. It isn't a sad feast. It's a held one.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-psa-yule-newmoon", category: .news,
                    assetName: "DJ_mothlight_psa_yule_newmoon_01",
                    caption: "For the dark half of the year, two quiet feasts worth keeping. Yule - the Darkest Class - held by candlelight on the longest night, taught honestly, the fireplaces crowded. And every New Moon, the Listening: candles only, the Academy gone contemplative-dark. Both ask the same small thing - name one thing that survives the dark with you, and keep it where the candle can reach. The light always comes back. These feasts simply sit with you until it does.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-psa-resonance-class", category: .news,
                    assetName: "DJ_mothlight_psa_resonance_class_01",
                    caption: "A standing invitation, for the record: Synesthetic Resonance meets twice a week - Tuesday afternoons at one bell, and Friday mornings at nine - in the Resonance Chamber, Wing Three. We practice the South direction. Sense. Hearing a colour, then naming the real evidence beneath it. The senses are serious instruments, and yours are only out of practice. Come tune the room with me. Bring nothing - you already carry everything it needs.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "mothlight-psa-quiet-hours", category: .news,
                    assetName: "DJ_mothlight_psa_quiet_hours_01",
                    caption: "Quiet Hours sits on the Wednesday timetable - Professor Stonebrook, the Still Room, one bell in the afternoon. It's the only class that teaches the Center. Rest. Not absence - the nervous system sorting the day so that tomorrow can happen. He turns the hourglass on its side and lets the still sand do the talking. If you've been running on the last of the light, that's the room. No one there will ask you to perform being fine.",
                    conditions: nil,
                    weight: 3
                )
            ]
        ),
        RadioStation(
            id: "thornwave",
            title: "Thornwave",
            frequency: 103.7,
            subtitle: "Bramble bass, broken-glass garage, and bargains struck in the low end after midnight.",
            hostEntityID: "wicker-eddies",
            packID: nil,
            unlockRule: "core",
            moodTags: ["fae", "trip-hop", "future-garage", "dark", "night", "thorn"],
            signalLine: "The bass moves like something with antlers stepping between the trees.",
            tracks: [
                RadioTrack(
                    id: "thornwave-bramble-bass",
                    title: "Bramble Bass",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveBrambleBass",
                    durationSeconds: 162,
                    moodTags: ["dark", "night"]
                ),
                RadioTrack(
                    id: "thornwave-nocturnal-faerie-lounge",
                    title: "Nocturnal Faerie Lounge",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveNocturnalFaerieLounge",
                    durationSeconds: 123,
                    moodTags: ["dark", "night"]
                ),
                RadioTrack(
                    id: "thornwave-whispering-shadows",
                    title: "Whispering Shadows",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveWhisperingShadows",
                    durationSeconds: 129,
                    moodTags: ["dark", "night", "shadow"]
                ),
                RadioTrack(
                    id: "thornwave-long-titles-in-the-dark",
                    title: "Long Titles in the Dark",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveLongTitlesInTheDark",
                    durationSeconds: 212,
                    moodTags: ["dark", "night", "smooth", "jazz"]
                ),
                RadioTrack(
                    id: "thornwave-duskthorn-rising",
                    title: "Duskthorn Rising",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveDuskthornRising",
                    durationSeconds: 240,
                    moodTags: ["dark", "night", "thorn", "rising"]
                ),
                RadioTrack(
                    id: "thornwave-no-conflict-no-story",
                    title: "No Conflict, No Story",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveNoConflictNoStory",
                    durationSeconds: 245,
                    moodTags: ["dark", "night", "story", "conflict"]
                ),
                RadioTrack(
                    id: "thornwave-magic-margins",
                    title: "Magic Margins",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveMagicMargins",
                    durationSeconds: 264,
                    moodTags: ["dark", "night", "margins", "magic"]
                ),
                RadioTrack(
                    id: "thornwave-velvet-arrears",
                    title: "Velvet Arrears",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveVelvetArrears",
                    durationSeconds: 233,
                    moodTags: ["dark", "night", "velvet", "bargain"]
                ),
                RadioTrack(
                    id: "thornwave-goblin-market",
                    title: "Goblin Market",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveGoblinMarket",
                    durationSeconds: 158,
                    moodTags: ["dark", "night", "market", "bargain"]
                ),
                RadioTrack(
                    id: "thornwave-mossy-night",
                    title: "Mossy Night",
                    artist: "Thornwave",
                    assetName: "RadioThornwaveMossyNight",
                    durationSeconds: 193,
                    moodTags: ["dark", "night", "moss", "fae"]
                )
            ],
            interludeTitles: [
                "A thorn taps the rhythm against the window from outside.",
                "The drop sounds like a door you should not open, opening."
            ],
            effects: [
                RadioStationEffect(pageType: .bookFae, boost: 10, reason: "Thornwave is the dark fae's own frequency."),
                RadioStationEffect(pageType: .narrativeOS, boost: 8, reason: "The low end pulls story-bearing pages forward after dark."),
                RadioStationEffect(pageType: .gossip, boost: 6, reason: "Rumor travels well under a bassline this deep.")
            ],
            // Worked example of the banter system — DJ'd by Wicker Eddies.
            // Audio assets follow the DJ_<station>_<type>_NN naming from
            // docs/RadioDJBanters.md; captions double as the spoken fallback.
            banters: [
                RadioBanter(
                    id: "thornwave-id-01", category: .stationID,
                    assetName: "DJ_thornwave_id_01",
                    caption: "Thornwave. One-oh-three point seven, after dark. Wicker Eddies, here to test whether anything you believe survives the bassline. Most of it won't. The stuff that does? That's the real magic. Stay tuned.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-id-02", category: .stationID,
                    assetName: "DJ_thornwave_id_02",
                    caption: "You found Thornwave — one-oh-three seven, the frequency the dark fae kept for themselves. I puncture false magic for sport. This station isn't false. Felt that in your chest, didn't you. Good.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-id-03", category: .stationID,
                    assetName: "DJ_thornwave_id_03",
                    caption: "It's the hour rumors travel best, so I'm exactly where I belong. Wicker, on Thornwave. Keep your name to yourself. I collect those.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-outro-bramble-bass", category: .transition,
                    assetName: "DJ_thornwave_transition_bramble_bass_outro",
                    caption: "That was \"Bramble Bass.\" No theatrics, no glamour — just a thing that's actually true at a hundred and three point seven. Rare. Coming up, \"Nocturnal Faerie Lounge.\" Last call at the only bar the grey won't enter.",
                    conditions: nil, weight: nil,
                    trackID: "thornwave-bramble-bass", placement: .outro
                ),
                RadioBanter(
                    id: "thornwave-outro-nocturnal-faerie-lounge", category: .transition,
                    assetName: "DJ_thornwave_transition_nocturnal_faerie_lounge_outro",
                    caption: "\"Nocturnal Faerie Lounge,\" just now. Somebody in that crowd is making a deal they'll keep for thirty years. I'd talk them out of it — testing it, you understand — but the song's too good. Here's more.",
                    conditions: nil, weight: nil,
                    trackID: "thornwave-nocturnal-faerie-lounge", placement: .outro
                ),
                RadioBanter(
                    id: "thornwave-intro-bramble-bass", category: .transition,
                    assetName: "DJ_thornwave_transition_bramble_bass_intro",
                    caption: "The drop sounds like a door you were warned about, opening. I've never met a warning I didn't want to test. So — after this, let's open it. \"Bramble Bass.\"",
                    conditions: nil, weight: nil,
                    trackID: "thornwave-bramble-bass", placement: .intro
                ),
                RadioBanter(
                    id: "thornwave-sponsor-bramblewine", category: .sponsor,
                    assetName: "DJ_thornwave_sponsor_01",
                    caption: "Thornwave runs on favors owed and Bramblewine — aged in the dark, priced in the morning. One sip and the night belongs to you; two, and you belong to it. I've read the small print. There's always small print. That's the only honest thing at the Goblin Market — they tell you, then watch you not listen.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "thornwave-sponsor-goblin-market", category: .sponsor,
                    assetName: "DJ_thornwave_sponsor_02",
                    caption: "Tonight's low end is sponsored by the Goblin Market. Open after hours. No refunds. All bargains binding. Tell Melisande over on one-oh-five that Wicker sent you, and she'll overcharge you with a straight face. Respect her for it. I do.",
                    conditions: nil, weight: nil
                ),
                RadioBanter(
                    id: "thornwave-gossip-pact", category: .gossip,
                    assetName: "DJ_thornwave_gossip_01",
                    caption: "Penny wouldn't print this — too unproven for the record — so I'll say it, because I prefer my truths a little dangerous: a pact came due this week. Somebody paid. The grey leaned one shade closer to whoever let it. Don't be that somebody. Plant the Belief. I'll wait. I'm patient when it matters.",
                    conditions: RadioBanter.Conditions(minGrey: 40),
                    weight: 2
                ),
                RadioBanter(
                    id: "thornwave-gossip-unwritten", category: .gossip,
                    assetName: "DJ_thornwave_gossip_02",
                    caption: "Rumor under the bassline. There's a chapter in this building nobody can jump into — yours, the Unwritten one. Everybody wants a look. They'd test it, pick it apart, like I'd. Don't let us. Write it yourself first.",
                    conditions: nil,
                    weight: 2
                ),
                RadioBanter(
                    id: "thornwave-news-nothing", category: .news,
                    assetName: "DJ_thornwave_news_01",
                    caption: "Tonight's reading off Today's Sky: Routine made a move at the edges. We held. We always hold — barely, on purpose, which is the only kind of holding worth anything. Believe something out loud. I dare you. That's not mockery. That's the assignment.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        minGrey: 35
                    ),
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-news-pact-dispatch", category: .news,
                    assetName: "DJ_thornwave_news_02",
                    caption: "Pact Dispatch is busy tonight. Three bargains struck, two already regretted, one that'll change a life. I can usually tell which is which — it's my whole talent. Tonight? Can't call it. That's how you know it's real. More Thornwave, after this.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-pages-story-night", category: .gossip,
                    assetName: "DJ_thornwave_pages_story_night_01",
                    caption: "You've been keeping story pages. Thornwave noticed. Stories are doors with teeth, and you keep putting your hand on the handle. Respect.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        pageTypes: [.narrativeOS, .gamePage, .bookJump],
                        minRecentPagesOfType: 2
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-pages-fae-bargain", category: .gossip,
                    assetName: "DJ_thornwave_pages_bargain_01",
                    caption: "A bargain page crossed the wire. Read the small print twice. Then read the silence after it. That's where they hide the expensive part.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.faeBargain, .pactDispatch],
                        minRecentPagesOfType: 1
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-weather-storm-grey", category: .news,
                    assetName: "DJ_thornwave_weather_storm_grey_01",
                    caption: "Storm pressure on the band and grey at the edges. Good. False magic hates bad weather. Real magic keeps its footing.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        minGrey: 35,
                        weatherTags: ["rain", "storm", "wind"]
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-pages-gossip", category: .gossip,
                    assetName: "DJ_thornwave_pages_gossip_01",
                    caption: "Gossip pages in the margins. Careful. A rumor is just a spell wearing someone else's coat.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.gossip, .theBleed],
                        minRecentPagesOfType: 1
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "thornwave-pages-moonwrite", category: .gossip,
                    assetName: nil,
                    caption: "When the moon comes full, the Academy does the one thing it almost never does — cancels class after sunset. The Luminous Gathering. Everyone spills into the courtyard to read by moonlight, and strangers actually speak to each other. The sentences glow. I've watched it happen and failed to find the trick. So write your souvenir under a full moon some night — they call it Moonwrite — and watch the page light up. Believe it out loud. I dare you. The moon's already holding still for you.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        pageTypes: [.souvenir],
                        minRecentPagesOfType: 1
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-pages-fae-bargain-fineprint", category: .gossip,
                    assetName: "DJ_thornwave_pages_bargain_02",
                    caption: "So you've been taking meetings with the Fae. They always keep their word — that's the good news and the bad news. Read the small print. It's where the music lives.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.faeBargain, .pactDispatch],
                        minRecentPagesOfType: 1
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-weather-storm-grey-pressure", category: .news,
                    assetName: "DJ_thornwave_weather_storm_grey_02",
                    caption: "Storm on the band, grey at the edges, that delicious pressure before something decides to happen. The Rut of Routine loves weather like this. So do I — but I'm only here for the bassline.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        minGrey: 35,
                        weatherTags: ["storm", "rain", "wind"]
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-pages-story-night-choice", category: .gossip,
                    assetName: "DJ_thornwave_pages_story_night_02",
                    caption: "A story's been moving through your pages after dark. Something with a door in it. Free tip, no strings, and I rarely say that: the choice you skip is also a choice.",
                    conditions: RadioBanter.Conditions(
                        timeOfDay: ["dusk", "night"],
                        pageTypes: [.narrativeOS, .bookJump, .gamePage],
                        minRecentPagesOfType: 2
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-pages-gossip-leverage", category: .gossip,
                    assetName: "DJ_thornwave_pages_gossip_02",
                    caption: "The Bleed's been chatty and so has the Loom. I don't traffic in rumor — I traffic in leverage, which is rumor that's grown up. Secrets are just bargains not yet offered.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.gossip, .castBond],
                        minRecentPagesOfType: 2
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "thornwave-time-after-midnight", category: .stationID,
                    assetName: "DJ_thornwave_time_after_midnight_01",
                    caption: "Past the hour sensible people sleep, which makes you my favorite company. Nothing good gets decided after midnight, they say. Wrong. Nothing safe does. Different word.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["night"]),
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-grey-high-keep-the-door", category: .news,
                    assetName: "DJ_thornwave_grey_high_pressure_01",
                    caption: "The grey's gone heavy. The Rut's leaning on the door, polite as ever. Here's the thing — it only opens from your side. Keep the music up. Hand off the latch.",
                    conditions: RadioBanter.Conditions(
                        minGrey: 55,
                        maxGrey: 85
                    ),
                    weight: 5
                ),
                RadioBanter(
                    id: "thornwave-pages-anchor-impressed", category: .gossip,
                    assetName: "DJ_thornwave_pages_anchor_resist_01",
                    caption: "You've been dropping anchors. Naming things. Holding ground. Building a self Routine can't argue with. I'd be insulted if I weren't quietly impressed. Don't tell anyone.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.anchor, .enchantment],
                        minRecentPagesOfType: 1
                    ),
                    weight: 4
                ),
                RadioBanter(
                    id: "thornwave-talisman-dusk-thorn", category: .news,
                    assetName: "DJ_thornwave_talisman_dusk_thorn_01",
                    caption: "Let's talk about my Chapter's talisman, since no one else will at this hour. The Dusk Thorn. Duskthorn. It only draws blood from a story that's already gone numb - never from a living one. Its belief is four words, and I happen to agree with every one of them: no conflict, no story. The grey wants your days smooth and quiet and forgettable. The Thorn wants them to cost something. So do I. That's not cruelty. That's plot.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: 4
                ),
                RadioBanter(
                    id: "thornwave-talisman-ember-seal", category: .gossip,
                    assetName: "DJ_thornwave_talisman_ember_seal_01",
                    caption: "Emberheart's talisman is the Ember Seal - warm, insistent, bright at the edges, and impatient with waiting, which is the most honest thing in this building. It leaves faint scorch marks on your hesitations. Good. You should be able to see where you flinched. Its doctrine is the only line of Academy scripture I'd actually sign: you are the author, the protagonist, and the pen. So stop waiting for permission that was never coming. Write the next line yourself.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-class-book-jumping", category: .gossip,
                    assetName: "DJ_thornwave_class_book_jumping_01",
                    caption: "You've been jumping into stories. Permancer's class - the Vault of Doors. He'll teach you that a genre is weather, not wallpaper, and that every door you open owes a return. All true. He lays out three bookmarks and rejects the prettiest one because it has no exit protocol. Me? I've never met a door I needed a bookmark to walk back through. That's the difference between us - and the reason he's right and I'm interesting. Keep the bookmark. For now.",
                    conditions: RadioBanter.Conditions(pageTypes: [.bookJump], minRecentPagesOfType: 1),
                    weight: 4
                ),
                RadioBanter(
                    id: "thornwave-cast-finn", category: .gossip,
                    assetName: "DJ_thornwave_cast_finn_01",
                    caption: "Finn Bridges chalked another challenge in red this week. Clean line, no theatrics - prove it by moving, don't cheapen the effort. He respects Momort's class most on the days it stops sounding like an escape route and starts sounding like discipline. I like Finn. He's one of the few who tests himself harder than I'd bother to. If he's marked a line for you, reader - don't argue it. Cross it. He'll respect that more than winning.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-cast-damien", category: .gossip,
                    assetName: "DJ_thornwave_cast_damien_01",
                    caption: "A word about one of my own. Damien Nights still stands at my shoulder when the crew organizes - but his eyes keep drifting to you, reader. He keeps a pressed trail leaf hidden in a book. A man doesn't hide something gentle unless he's deciding which side he's on. I taught him doubt should protect something, not merely wound it. Looks like he was listening. Good. I'd rather lose him to the truth than keep him for the theatre.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["night"]),
                    weight: 4
                ),
                RadioBanter(
                    id: "thornwave-cast-thorne", category: .news,
                    assetName: "DJ_thornwave_cast_thorne_01",
                    caption: "The Headmistress is awake. Seraphina Thorne - unseelie, elegant, watchful, speaks as if every building is listening, which, in her case, they are. She keeps the Academy's doors from admitting they're tests. Believes beauty is a form of governance. She'd keep you safe by keeping you in the dark and call it mercy. I respect her more than I trust her. You should hold the same arithmetic. Wonder is only worth anything if it's allowed to stay a little dangerous.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-club-inkwright", category: .gossip,
                    assetName: "DJ_thornwave_club_inkwright_01",
                    caption: "The Inkwright Society met in the Bibliophonic Hall tonight. Serious notebooks, no mascots. They write, they share - honest first, kind second - and then they burn it. Each meeting ends with a piece read aloud and set alight, the smoke going up into the library ceiling to be absorbed as words. Theatrical. I approve, obviously. The writing there is meant. If you've something true and dangerous to say, that's the only room in the building that can hold it.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-network-grey", category: .network,
                    assetName: "DJ_thornwave_network_grey_01",
                    caption: "One thing the whole band agrees on, and we agree on almost nothing: this is the sound the grey can't get into. ReEnchanted Radio. Keep believing out loud - it's the only thing that's ever worked, and I've spent my whole life trying to prove otherwise. Spin on.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: 2
                ),
                // Unscheduled Wicker breaks imported from the July 7 ElevenLabs
                // batch. They are deliberately ungated so they can run anywhere
                // in Thornwave's normal DJ cadence.
                RadioBanter(
                    id: "thornwave-wicker-banter-01", category: .stationID,
                    assetName: "DJ_thornwave_wicker_banter_01",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 1 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-02", category: .gossip,
                    assetName: "DJ_thornwave_wicker_banter_02",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 2 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-03", category: .news,
                    assetName: "DJ_thornwave_wicker_banter_03",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 3 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-04", category: .network,
                    assetName: "DJ_thornwave_wicker_banter_04",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 4 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-05", category: .gossip,
                    assetName: "DJ_thornwave_wicker_banter_05",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 5 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-06", category: .news,
                    assetName: "DJ_thornwave_wicker_banter_06",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 6 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-07", category: .stationID,
                    assetName: "DJ_thornwave_wicker_banter_07",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 7 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-08", category: .gossip,
                    assetName: "DJ_thornwave_wicker_banter_08",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 8 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-09", category: .news,
                    assetName: "DJ_thornwave_wicker_banter_09",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 9 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-10", category: .network,
                    assetName: "DJ_thornwave_wicker_banter_10",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 10 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-11", category: .gossip,
                    assetName: "DJ_thornwave_wicker_banter_11",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 11 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-12", category: .news,
                    assetName: "DJ_thornwave_wicker_banter_12",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 12 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-13", category: .stationID,
                    assetName: "DJ_thornwave_wicker_banter_13",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 13 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-14", category: .gossip,
                    assetName: "DJ_thornwave_wicker_banter_14",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 14 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-15", category: .news,
                    assetName: "DJ_thornwave_wicker_banter_15",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 15 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-16", category: .network,
                    assetName: "DJ_thornwave_wicker_banter_16",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 16 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-17", category: .gossip,
                    assetName: "DJ_thornwave_wicker_banter_17",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 17 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                RadioBanter(
                    id: "thornwave-wicker-banter-18", category: .news,
                    assetName: "DJ_thornwave_wicker_banter_18",
                    caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 18 of the July 7 batch.",
                    conditions: nil,
                    weight: 3
                ),
                // Unscheduled Wicker breaks imported from the July 11 batch.
                // These are ordinary, ungated Thornwave breaks.
                RadioBanter(id: "thornwave-wicker-banter-19", category: .stationID, assetName: "DJ_thornwave_wicker_banter_19", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 19.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-20", category: .gossip, assetName: "DJ_thornwave_wicker_banter_20", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 20.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-21", category: .news, assetName: "DJ_thornwave_wicker_banter_21", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 21.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-22", category: .network, assetName: "DJ_thornwave_wicker_banter_22", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 22.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-23", category: .stationID, assetName: "DJ_thornwave_wicker_banter_23", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 23.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-24", category: .gossip, assetName: "DJ_thornwave_wicker_banter_24", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 24.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-25", category: .news, assetName: "DJ_thornwave_wicker_banter_25", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 25.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-26", category: .network, assetName: "DJ_thornwave_wicker_banter_26", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 26.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-27", category: .stationID, assetName: "DJ_thornwave_wicker_banter_27", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 27.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-28", category: .gossip, assetName: "DJ_thornwave_wicker_banter_28", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 28.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-29", category: .news, assetName: "DJ_thornwave_wicker_banter_29", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 29.", conditions: nil, weight: 3),
                // Unscheduled Wicker breaks imported from the later July 11
                // batch. These are ordinary, ungated Thornwave breaks.
                RadioBanter(id: "thornwave-wicker-banter-30", category: .network, assetName: "DJ_thornwave_wicker_banter_30", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 30.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-31", category: .stationID, assetName: "DJ_thornwave_wicker_banter_31", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 31.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-32", category: .gossip, assetName: "DJ_thornwave_wicker_banter_32", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 32.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-33", category: .news, assetName: "DJ_thornwave_wicker_banter_33", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 33.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-34", category: .network, assetName: "DJ_thornwave_wicker_banter_34", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 34.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-35", category: .stationID, assetName: "DJ_thornwave_wicker_banter_35", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 35.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-36", category: .gossip, assetName: "DJ_thornwave_wicker_banter_36", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 36.", conditions: nil, weight: 3),
                RadioBanter(id: "thornwave-wicker-banter-37", category: .news, assetName: "DJ_thornwave_wicker_banter_37", caption: "Unscheduled Wicker Eddies banter from the Thornwave booth. Audio-backed clip 37.", conditions: nil, weight: 3),
                RadioBanter(
                    id: "thornwave-psa-clubs-night", category: .news,
                    assetName: "DJ_thornwave_psa_clubs_night_01",
                    caption: "It's after the bells, which means the clubs are awake - seven to ten, lamps up, doors open. The Compass Society reads souvenirs aloud like confessions, and no one in that garden mocks a sentence - more discipline than most of you manage. The Inkwright Society writes it true, then burns it; the smoke goes up into the library ceiling. The Marginalia Guild leaves threats to future readers, lovingly. And the Book Jumpers argue about doors until someone finds the one with a way back. Pick a room. Or don't. But the doors only open at this hour.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-psa-beltane", category: .news,
                    assetName: "DJ_thornwave_psa_beltane_01",
                    caption: "One feast even I won't sharpen my teeth on: Beltane. The Greenfire. The first of May, when the courtyard goes reckless with bloom and the vines climb the shelves with tiny books for leaves. The bees in the Compass Rose are helpful and, frankly, a little drunk. Find the most alive green thing near you and talk to it like it can hear you. It can. That isn't me going soft - it's just true, and true is the only thing I deal in. Greenfire. Don't miss it.",
                    conditions: nil,
                    weight: nil
                ),
                RadioBanter(
                    id: "thornwave-psa-fullmoon", category: .news,
                    assetName: "DJ_thornwave_psa_fullmoon_01",
                    caption: "When the moon comes full, the Academy does the one thing it almost never does - cancels class after sunset. The Luminous Gathering. Everyone spills into the courtyard to read by moonlight, and strangers actually speak to each other. The sentences glow. I've watched it happen and failed to find the trick. So write your souvenir under a full moon some night - they call it Moonwrite - and watch the page light up. Believe it out loud. I dare you. The moon's already holding still for you.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["dusk", "night"]),
                    weight: nil
                )
            ]
        ),
        RadioStation(
            id: "the-bleed",
            title: "The Bleed // Unauthorized",
            frequency: 97.3,
            subtitle: "An unlisted transmission leaking through the Academy band without permission or plausible innocence.",
            hostEntityID: "penny-blackletter",
            packID: nil,
            unlockRule: "hidden-frequency",
            moodTags: ["pirate", "gossip", "secret", "margins", "intercept"],
            signalLine: "The static parts around a voice that was not cleared for broadcast.",
            tracks: [
                RadioTrack(
                    id: "the-bleed-intercept",
                    title: "Intercept 97.3",
                    artist: "Unknown Correspondent",
                    assetName: "RadioTheBleedPirateSignal",
                    durationSeconds: 137,
                    moodTags: ["pirate", "gossip", "intercept"]
                )
            ],
            interludeTitles: [],
            interstitialAssetName: "RadioFreeMarginStatic",
            interstitialTitle: "Radio Free Margin Static",
            effects: [
                RadioStationEffect(pageType: .gossip, boost: 12, reason: "The Bleed puts unauthorized truths into circulation."),
                RadioStationEffect(pageType: .narrativeOS, boost: 8, reason: "A compromised signal wakes the machinery behind the margins."),
                RadioStationEffect(pageType: .bookFae, boost: 5, reason: "Book Fae notice frequencies the Academy refuses to list.")
            ],
            banters: [
                RadioBanter(
                    id: "bleed-pages-gossip-cluster", category: .network,
                    assetName: "DJ_bleed_pages_gossip_01",
                    caption: "Unauthorized pattern detected: multiple gossip-bearing pages, recently kept. The official station calls this coincidence. The official station is lying.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.gossip, .theBleed],
                        minRecentPagesOfType: 2
                    ),
                    weight: 6
                ),
                RadioBanter(
                    id: "bleed-pages-story-grey", category: .network,
                    assetName: "DJ_bleed_pages_story_grey_01",
                    caption: "Hidden-band advisory: story pages plus rising grey make a door-shaped shadow. If you hear knocking from the wrong side, do not answer in your own name.",
                    conditions: RadioBanter.Conditions(
                        minGrey: 35,
                        pageTypes: [.narrativeOS, .bookJump, .gamePage],
                        minRecentPagesOfType: 2
                    ),
                    weight: 6
                ),
                RadioBanter(
                    id: "bleed-time-after-midnight", category: .network,
                    assetName: "DJ_bleed_time_after_midnight_01",
                    caption: "This is not a station ID. After midnight, IDs become handles. Handles become hooks. Stay anonymous, reader.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["night"]),
                    weight: 3
                ),
                RadioBanter(
                    id: "bleed-rant-02", category: .network,
                    assetName: "DJ_bleed_rant_02",
                    caption: "Unauthorized transmission continuing. If the Academy says the margin is blank, check whose hand is covering the ink. Static is not silence. Static is a crowd of facts waiting for one reader with nerve enough to tune between the approved numbers.",
                    conditions: nil,
                    weight: 4
                ),
                RadioBanter(
                    id: "bleed-cast-crew", category: .network,
                    assetName: "DJ_bleed_cast_crew_01",
                    caption: "Unauthorized intercept. The faction the Academy won't name on the record: Wicker's crew. Blackwood keeps its memory; Nights keeps its doubt. Watch which one cracks first - the broker, or the believer. You didn't get this from a station. You didn't get this at all.",
                    conditions: RadioBanter.Conditions(
                        pageTypes: [.illustration, .castBond, .gossip],
                        minRecentPagesOfType: 2
                    ),
                    weight: 6
                ),
                RadioBanter(
                    id: "bleed-talisman-contraband", category: .network,
                    assetName: "DJ_bleed_talisman_contraband_01",
                    caption: "Hidden-band advisory. Five talismans, one per Chapter, and the Academy lists them like heirlooms. Thorn for conflict. Ember for authorship. Cipher for the work we do together. Glass for the unplanned. Clasp for what you receive. They are not heirlooms. They are tools. The grey is up - pick one up and use it. Quietly.",
                    conditions: RadioBanter.Conditions(minGrey: 35),
                    weight: 5
                ),
                RadioBanter(
                    id: "bleed-lore-unwritten", category: .network,
                    assetName: "DJ_bleed_lore_unwritten_01",
                    caption: "Off the record, off the band: there's a chapter in this building no one can jump into, no one can assign, no one can grade. Yours. The Unwritten one. Everybody wants a look. Don't sign your name at anyone else's door. Write it from the inside. That's the only lock that holds.",
                    conditions: nil,
                    weight: 4
                ),
                RadioBanter(
                    id: "bleed-cast-thorne", category: .network,
                    assetName: "DJ_bleed_cast_thorne_01",
                    caption: "This is not a station ID. The Headmistress monitors this frequency - Thorne hears the whole band, and she keeps doors from admitting they're tests. If a threshold opens easy tonight, ask who left it open, and what it's measuring. Stay anonymous, reader. Stay awake.",
                    conditions: RadioBanter.Conditions(timeOfDay: ["night"]),
                    weight: 4
                )
            ]
        )
    ]

    private static let bundledPacksWithoutMeanings: [RadioStationPack] = [
        RadioStationPack(
            id: "core-radio-pack",
            displayName: "Core Radio Pack",
            stations: coreStations
        ),
        RadioStationPack(
            id: "academy-night-band",
            displayName: "Academy Night Band",
            stations: [
                RadioStation(
                    id: "midnight-bindery",
                    title: "The Midnight Bindery",
                    frequency: 99.3,
                    subtitle: "Thread, glue, moonlit knives, and pages learning how to hold together.",
                    hostEntityID: "professor-vivian-villanelle",
                    packID: "academy-night-band",
                    unlockRule: "sound-pack",
                    moodTags: ["night", "binding", "archive", "memory", "book-of-you"],
                    signalLine: "The bass line sounds like a needle passing through signatures.",
                    tracks: [
                        RadioTrack(
                            id: "midnight-bindery-thread",
                            title: "Thread Through the Dark",
                            artist: "The Midnight Bindery",
                            assetName: "RadioMidnightBinderyThread",
                            durationSeconds: nil,
                            moodTags: ["night", "binding"]
                        )
                    ],
                    interludeTitles: [
                        "Penny warns the glue is awake.",
                        "A page signs its own name in the dark."
                    ],
                    effects: [
                        RadioStationEffect(pageType: .bookOfYou, boost: 10, reason: "The Bindery favors pages that become chapters."),
                        RadioStationEffect(pageType: .bookRemembered, boost: 8, reason: "Bound pages remember each other more readily."),
                        RadioStationEffect(pageType: .bookConnections, boost: 6, reason: "Loose pages tug toward pattern while this plays.")
                    ]
                ),
                RadioStation(
                    id: "goblin-market-jazz",
                    title: "Goblin Market Jazz",
                    frequency: 105.1,
                    subtitle: "Bent brass, laughing ledgers, and bargains with too many teeth in the margins.",
                    hostEntityID: "melisande-blackwood",
                    packID: "academy-night-band",
                    unlockRule: "sound-pack",
                    moodTags: ["fae", "market", "mischief", "bargain", "risk"],
                    signalLine: "The trumpet keeps offering impossible discounts.",
                    tracks: [
                        RadioTrack(
                            id: "goblin-market-after-hours",
                            title: "After-Hours Coin Trick",
                            artist: "Goblin Market Jazz",
                            assetName: "RadioGoblinMarketAfterHours",
                            durationSeconds: nil,
                            moodTags: ["fae", "market"]
                        )
                    ],
                    interludeTitles: [
                        "A clerk advertises a bargain that refuses to explain itself.",
                        "The rhythm hides a receipt under the rug."
                    ],
                    effects: [
                        RadioStationEffect(pageType: .faeBargain, boost: 12, reason: "Goblin Market Jazz makes bargains tap at the glass."),
                        RadioStationEffect(pageType: .bookFae, boost: 8, reason: "Fae notice music that cheats at counting."),
                        RadioStationEffect(pageType: .quip, boost: 5, reason: "The margins get sharper while the brass is awake.")
                    ]
                )
            ]
        )
    ]

    static var bundledPacks: [RadioStationPack] {
        bundledPacksWithoutMeanings.map { pack in
            var enrichedPack = pack
            enrichedPack.stations = pack.stations.map { station in
                var enrichedStation = station
                enrichedStation.tracks = station.tracks.map { track in
                    var enrichedTrack = track
                    enrichedTrack.meaning = track.meaning ?? authoredBundledMeaning(for: track)
                    return enrichedTrack
                }
                return enrichedStation
            }
            return enrichedPack
        }
    }

    static func userPacks(fileManager: FileManager = .default) -> [RadioStationPack] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? fileManager.contentsOfDirectory(
                at: documents,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        let decoder = JSONDecoder()
        return files
            .filter { $0.lastPathComponent.hasSuffix(userPackFileSuffix) }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      var pack = try? decoder.decode(RadioStationPack.self, from: data) else {
                    return nil
                }
                pack.stations = pack.stations.map { station in
                    var station = station
                    station.packID = station.packID ?? pack.id
                    return station
                }
                return pack
            }
    }

    /// Frequencies that exist on the receiver but are intentionally absent
    /// from preset buttons, station lists, and generated dial instructions.
    static let hiddenStationIDs: Set<String> = ["the-bleed"]

    private static func availableStations(unlockedPackIDs: Set<String>) -> [RadioStation] {
        (bundledPacks + userPacks())
            .flatMap(\.stations)
            .filter { station in
                station.packID.map { PackEntitlements.owns($0, in: unlockedPackIDs) } ?? true
            }
            .map { station in
                // Only bundled catalogues receive this authored baseline. User
                // packs must explicitly provide meaning before they can echo.
                guard bundledPacks.flatMap(\.stations).contains(where: { $0.id == station.id }) else { return station }
                var enriched = station
                enriched.tracks = station.tracks.map { track in
                    var authored = track
                    authored.meaning = track.meaning ?? authoredBundledMeaning(for: track)
                    return authored
                }
                return enriched
            }
    }

    /// Listed presets only. Hidden frequencies remain resolvable by ID and by
    /// landing on their exact dial step through `nearestStation`.
    static func stations(unlockedPackIDs: Set<String> = []) -> [RadioStation] {
        availableStations(unlockedPackIDs: unlockedPackIDs)
            .filter { !hiddenStationIDs.contains($0.id) }
    }

    static func station(id: String?, unlockedPackIDs: Set<String> = []) -> RadioStation? {
        guard let id else { return nil }
        return availableStations(unlockedPackIDs: unlockedPackIDs).first { $0.id == id }
    }

    static func nearestStation(to frequency: Double, unlockedPackIDs: Set<String> = []) -> RadioStation? {
        let available = availableStations(unlockedPackIDs: unlockedPackIDs)
        if let hidden = available.first(where: {
            hiddenStationIDs.contains($0.id) && abs($0.frequency - frequency) < 0.051
        }) {
            return hidden
        }
        return available
            .filter { !hiddenStationIDs.contains($0.id) }
            .min { abs($0.frequency - frequency) < abs($1.frequency - frequency) }
    }

    /// A station only "locks" when the dial is close enough to the frequency.
    /// Hidden pirate frequencies require the exact dial step; listed stations
    /// have a little analog forgiveness.
    static func tunedStation(to frequency: Double, unlockedPackIDs: Set<String> = []) -> RadioStation? {
        let available = availableStations(unlockedPackIDs: unlockedPackIDs)
        if let hidden = available.first(where: {
            hiddenStationIDs.contains($0.id) && abs($0.frequency - frequency) < 0.051
        }) {
            return hidden
        }
        guard let nearest = available
            .filter({ !hiddenStationIDs.contains($0.id) })
            .min(by: { abs($0.frequency - frequency) < abs($1.frequency - frequency) }),
              abs(nearest.frequency - frequency) < 0.35 else {
            return nil
        }
        return nearest
    }

    /// The tuned station's atmosphere line, for coloring generated prose.
    static func atmosphereLine(
        state: RadioPlaybackState,
        unlockedPackIDs: Set<String> = [],
        worldEvents: [ResolvedWorldEvent] = []
    ) -> String? {
        let stationLine = station(id: state.activeStationID, unlockedPackIDs: unlockedPackIDs)?.atmosphereLine
        let eventLine = worldEvents.radioAtmosphereLine
        switch (stationLine, eventLine) {
        case let (station?, event?):
            return "\(station) | \(event)"
        case let (station?, nil):
            return station
        case let (nil, event?):
            return event
        case (nil, nil):
            return nil
        }
    }

    /// Days of distinct listening before a station can begin forming a
    /// constellation. The companion-style "you and X keep meeting" thread.
    static let listeningNoticeDays = 3

    /// Continuity signals for stations the reader keeps returning to. Fed into
    /// the constellation keeper so a beloved station becomes a named companion.
    static func listeningSignals(
        state: RadioPlaybackState,
        unlockedPackIDs: Set<String> = [],
        now: Date = Date()
    ) -> [LiteraryContinuitySignal] {
        (state.listening ?? [:]).compactMap { stationID, entry -> LiteraryContinuitySignal? in
            guard entry.daysHeard >= listeningNoticeDays,
                  let station = station(id: stationID, unlockedPackIDs: unlockedPackIDs) else {
                return nil
            }
            let strength = min(96, 42 + entry.daysHeard * 6 + min(entry.sessions, 8))
            return LiteraryContinuitySignal(
                id: "radio-listening-\(stationID)",
                kind: .listening,
                subjectID: "radio:\(stationID)",
                subjectName: station.title,
                line: "You and \(station.title) keep meeting — \(entry.daysHeard) days on the dial now.",
                evidencePageIDs: [],
                relatedEntityIDs: station.hostEntityID.map { [$0] } ?? [],
                tags: ["radio", "listening", "station:\(stationID)"],
                firstSeenAt: entry.firstHeardAt ?? now,
                lastSeenAt: entry.lastHeardAt ?? now,
                strength: strength
            )
        }
        .sorted { $0.strength > $1.strength }
    }

    /// Distinct days a station must be heard — while it stays the tuned station —
    /// before it grants its signature held effect (real stakes beyond curation).
    static let heldEffectDays = 4

    /// The station currently tuned AND heard enough distinct days to have earned
    /// its held effect. Nil otherwise.
    static func heldStationID(state: RadioPlaybackState) -> String? {
        guard let id = state.activeStationID, state.isTuned,
              state.daysHeard(stationID: id) >= heldEffectDays else {
            return nil
        }
        return id
    }

    /// Held-station effect on Routine's tide: Thornwave lets the grey lean
    /// nearer (a dark-fae bargain), Fae-Fi's brightness pushes it back. Always
    /// distress-safe because NothingTide forces grey to 0 under distress.
    static func greyShift(state: RadioPlaybackState, now: Date = Date()) -> Int {
        switch heldStationID(state: state) {
        case "thornwave": return 1
        case "fae-fi": return -1
        default: return 0
        }
    }

    /// Held-station effect on curation beyond the base station boosts: Mothlight
    /// Beats, held, becomes a long memory — old pages return more readily.
    static func heldSurfaceBoosts(state: RadioPlaybackState) -> [BookPageType: Int] {
        switch heldStationID(state: state) {
        case "mothlight-beats": return [.bookRemembered: 8]
        default: return [:]
        }
    }

    static func surfaceBoosts(state: RadioPlaybackState, unlockedPackIDs: Set<String> = []) -> [BookPageType: Int] {
        guard let station = station(id: state.activeStationID, unlockedPackIDs: unlockedPackIDs) else {
            return [:]
        }
        return station.effects.reduce(into: [:]) { result, effect in
            result[effect.pageType, default: 0] += effect.boost
        }
    }

    static func currentInterlude(state: RadioPlaybackState, unlockedPackIDs: Set<String> = [], now: Date = Date()) -> String? {
        guard let station = station(id: state.activeStationID, unlockedPackIDs: unlockedPackIDs),
              !station.interludeTitles.isEmpty else {
            return nil
        }
        let seedDate = state.lastTunedAt ?? state.startedAt ?? now
        let slot = Int(now.timeIntervalSince(seedDate) / 900)
        let index = abs(station.id.stableHash + slot) % station.interludeTitles.count
        return station.interludeTitles[index]
    }

    // MARK: - Alive playout curation

    /// Pick a song without walking catalog order. The selector honors optional
    /// world gates, cools recently heard tracks, avoids immediate repeats, and
    /// uses weighted rendezvous scoring so adding a track does not reshuffle the
    /// whole catalog into a new disguised sequence.
    static func curatedTrack(
        station: RadioStation,
        previousTrackID: String?,
        recentTrackIDs: [String] = [],
        playTurn: Int,
        context: RadioWorldContext,
        sessionSeed: String,
        now: Date = Date()
    ) -> RadioTrack? {
        guard !station.tracks.isEmpty else { return nil }
        let contextual = station.tracks.filter { context.satisfies($0.conditions) }
        let unconditional = station.tracks.filter {
            $0.conditions == nil || $0.conditions?.isUnconditional == true
        }
        // A contextual catalog must never leak a gated future track merely
        // because no current gate matched. Fall back to ordinary station music.
        let eligible = contextual.isEmpty
            ? (unconditional.isEmpty ? station.tracks : unconditional)
            : contextual
        let recent = Set(recentTrackIDs)
        let fresh = eligible.filter { $0.id != previousTrackID && !recent.contains($0.id) }
        let nonRepeating = eligible.filter { $0.id != previousTrackID }
        let pool = !fresh.isEmpty ? fresh : !nonRepeating.isEmpty ? nonRepeating : eligible
        let slot = Int(now.timeIntervalSince1970 / 1_800)
        return pool.min { left, right in
            aliveScore(
                seed: "\(sessionSeed)|track|\(station.id)|\(previousTrackID ?? "start")|\(playTurn)|\(slot)|\(context.timeOfDay)|\(left.id)",
                weight: Double(left.resolvedWeight)
                    * experienceTrackMultiplier(left, context: context)
            ) < aliveScore(
                seed: "\(sessionSeed)|track|\(station.id)|\(previousTrackID ?? "start")|\(playTurn)|\(slot)|\(context.timeOfDay)|\(right.id)",
                weight: Double(right.resolvedWeight)
                    * experienceTrackMultiplier(right, context: context)
            )
        }
    }

    /// DJ cadence breathes: usually one or two songs between breaks, with a
    /// song-bound transition more likely to speak. Two quiet songs force the
    /// next eligible break, so randomness never becomes a silent station.
    static func shouldBanter(
        songsSinceLastBanter: Int,
        state: RadioPlaybackState,
        context: RadioWorldContext,
        justFinishedTrackID: String?,
        upcomingTrackID: String?,
        unlockedPackIDs: Set<String> = [],
        now: Date = Date()
    ) -> Bool {
        guard songsSinceLastBanter > 0,
              let station = station(id: state.activeStationID, unlockedPackIDs: unlockedPackIDs),
              !station.resolvedBanters.isEmpty || !context.pageContext.storyConsequenceEchoes.isEmpty else {
            return false
        }
        if songsSinceLastBanter >= 2 { return true }
        let hasBoundMoment = station.resolvedBanters.contains {
            $0.isBound
                && context.satisfies($0.conditions)
                && $0.placementFits(
                    justFinishedTrackID: justFinishedTrackID,
                    upcomingTrackID: upcomingTrackID
                )
        }
        let hasAttendedFocus = context.experienceProgram?.focusCue.map {
            $0.stage != .displayed && $0.stage != .dismissed
        } ?? false
        let probability = hasBoundMoment ? 0.82 : hasAttendedFocus ? 0.70 : 0.58
        let session = state.startedAt?.timeIntervalSince1970 ?? now.timeIntervalSince1970
        let slot = Int(now.timeIntervalSince1970 / 300)
        let roll = stableUnit("\(station.id)|cadence|\(session)|\(slot)|\(state.lastTrackID ?? "none")")
        return roll < probability
    }

    /// Pick the next DJ break from the whole eligible catalog. The persisted
    /// history turns the catalog into a randomly scored bag: eligible clips are
    /// exhausted before a repeat, while category cooling, world state, and
    /// song-bound placement keep the order from becoming a fixed pattern.
    static func nextBanter(
        state: RadioPlaybackState,
        context: RadioWorldContext,
        unlockedPackIDs: Set<String> = [],
        justFinishedTrackID: String? = nil,
        upcomingTrackID: String? = nil,
        now: Date = Date()
    ) -> RadioBanter? {
        guard let station = station(id: state.activeStationID, unlockedPackIDs: unlockedPackIDs) else {
            return nil
        }
        return nextBanter(
            station: station,
            state: state,
            context: context,
            justFinishedTrackID: justFinishedTrackID,
            upcomingTrackID: upcomingTrackID,
            now: now
        )
    }

    /// Pure-station form used by pack validation and simulations before a
    /// station has been installed in the global registry.
    static func nextBanter(
        station: RadioStation,
        state: RadioPlaybackState,
        context: RadioWorldContext,
        justFinishedTrackID: String? = nil,
        upcomingTrackID: String? = nil,
        now: Date = Date()
    ) -> RadioBanter? {
        let all = station.resolvedBanters + consequenceBanters(
            station: station,
            receipts: context.pageContext.storyConsequenceEchoes,
            now: now
        )
        guard !all.isEmpty else { return nil }

        // Eligible = world conditions satisfied AND (for song-bound transitions)
        // sitting on the correct side of the right song.
        let eligible = all.filter {
            context.satisfies($0.conditions)
                && $0.placementFits(justFinishedTrackID: justFinishedTrackID, upcomingTrackID: upcomingTrackID)
        }
        guard !eligible.isEmpty else { return nil }

        let recentIDs = state.recentBanterIDs ?? []
        let recent = Set(recentIDs)
        let seedDate = state.lastTunedAt ?? state.startedAt ?? now
        let slot = Int(now.timeIntervalSince(seedDate) / 900)
        let fresh = eligible.filter { !recent.contains($0.id) }
        var pool = !fresh.isEmpty
            ? fresh
            : eligible.filter { $0.id != recentIDs.last }
        if pool.isEmpty { pool = eligible }

        let recentCategories = Set(recentIDs.suffix(2).compactMap { id in
            all.first(where: { $0.id == id })?.category
        })
        let categoryFresh = pool.filter { !recentCategories.contains($0.category) }
        if !categoryFresh.isEmpty { pool = categoryFresh }

        let session = seedDate.timeIntervalSince1970
        return pool.min { left, right in
            aliveScore(
                seed: "\(station.id)|banter|\(session)|\(slot)|\(justFinishedTrackID ?? "none")|\(upcomingTrackID ?? "none")|\(left.id)",
                weight: banterCurationWeight(left, state: state, context: context, now: now)
            ) < aliveScore(
                seed: "\(station.id)|banter|\(session)|\(slot)|\(justFinishedTrackID ?? "none")|\(upcomingTrackID ?? "none")|\(right.id)",
                weight: banterCurationWeight(right, state: state, context: context, now: now)
            )
        }
    }

    private static func consequenceBanters(
        station: RadioStation,
        receipts: [StoryConsequenceReceipt],
        now: Date
    ) -> [RadioBanter] {
        receipts
            .filter {
                $0.significance >= .turn &&
                    $0.createdAt <= now &&
                    now.timeIntervalSince($0.createdAt) <= StoryConsequenceLedger.radioEchoLifetime &&
                    $0.radioEchoLine != nil
            }
            .sorted {
                if $0.significance == $1.significance { return $0.createdAt > $1.createdAt }
                return $0.significance > $1.significance
            }
            .prefix(4)
            .compactMap { receipt in
                guard let line = receipt.radioEchoLine else { return nil }
                let caption: String
                switch station.id {
                case "thornwave":
                    caption = "Wicker has been asked not to announce this, which is why he is announcing it: \(line)"
                case "fae-fi":
                    caption = "A bright little correction from the Stacks: \(line)"
                case "mothlight-beats":
                    caption = "From the late shelves, where consequences keep their own hours: \(line)"
                default:
                    caption = "A note has crossed the Academy wire: \(line)"
                }
                return RadioBanter(
                    id: "consequence-banter:\(receipt.id):\(station.id)",
                    category: receipt.significance == .rupture ? .gossip : .news,
                    assetName: nil,
                    caption: String(caption.prefix(320)),
                    conditions: nil,
                    weight: receipt.significance == .rupture ? 8 : 5
                )
            }
    }

    private static func banterCurationWeight(
        _ banter: RadioBanter,
        state: RadioPlaybackState,
        context: RadioWorldContext,
        now: Date
    ) -> Double {
        var weight = Double(banter.resolvedWeight)
        switch banter.category {
        case .stationID:
            weight *= (state.recentBanterIDs?.isEmpty ?? true) ? 2.2 : 0.65
        case .transition:
            if banter.isBound { weight *= 2.1 }
        case .sponsor:
            weight *= 0.72
        case .gossip:
            if context.timeOfDay == "dusk" || context.timeOfDay == "night" || context.grey >= 35 {
                weight *= 1.45
            }
        case .news:
            if Calendar.current.component(.minute, from: now) < 12 || context.festivalActive {
                weight *= 1.75
            }
        case .network:
            weight *= 1.1
        }
        if let conditions = banter.conditions {
            if conditions.pageTypes != nil || conditions.lastKeptPageTypes != nil {
                weight *= 1.75
            }
            if conditions.weatherTags != nil {
                weight *= 1.35
            }
            if conditions.minKeptToday != nil || conditions.sourceTags != nil || conditions.sourceIDs != nil {
                weight *= 1.25
            }
            if conditions.timeOfDay != nil && !conditions.isUnconditional {
                weight *= 1.1
            }
        }
        if let program = context.experienceProgram {
            let function = program.nextBroadcastFunction
            let hasPersonalGate = banter.conditions.map {
                $0.pageTypes != nil || $0.lastKeptPageTypes != nil
                    || $0.sourceIDs != nil || $0.sourceTags != nil
            } ?? false
            if program.nextBroadcastIsAutonomous {
                switch banter.category {
                case .stationID, .news, .network, .gossip:
                    weight *= 1.9
                case .transition:
                    weight *= 1.15
                case .sponsor:
                    weight *= 1.0
                }
                if hasPersonalGate { weight *= 0.45 }
            } else {
                let terms = program.radioAffinityTerms
                let overlap = experienceWords(for: banter).intersection(terms).count
                weight *= 1 + min(4.0, Double(overlap)) * 0.52
                if let focus = program.focusCue {
                    if banter.conditions?.pageTypes?.contains(focus.type) == true {
                        weight *= 2.1
                    }
                    if banter.conditions?.sourceIDs?
                        .map(RadioPageContext.normalize)
                        .contains(RadioPageContext.normalize(focus.sourceID)) == true {
                        weight *= 2.25
                    }
                }
                switch function {
                case .stationNative:
                    break
                case .establish:
                    if banter.category == .stationID || banter.category == .transition {
                        weight *= 1.35
                    }
                case .resonate:
                    if hasPersonalGate || banter.isBound { weight *= 1.4 }
                case .complicate:
                    if banter.category == .gossip || banter.category == .news {
                        weight *= 1.55
                    }
                case .afterimage:
                    if banter.category == .transition || banter.isBound { weight *= 1.5 }
                case .release:
                    if banter.category == .stationID || banter.category == .network {
                        weight *= 1.6
                    }
                    if hasPersonalGate { weight *= 0.6 }
                }
            }
        }
        return weight
    }

    private static func experienceTrackMultiplier(
        _ track: RadioTrack,
        context: RadioWorldContext
    ) -> Double {
        guard let program = context.experienceProgram else { return 1 }
        if program.nextBroadcastIsAutonomous { return 1 }
        let terms = program.radioAffinityTerms
        let overlap = experienceWords(for: track).intersection(terms).count
        var multiplier = 1 + min(5.0, Double(overlap)) * 0.58
        switch program.nextBroadcastFunction {
        case .stationNative:
            return 1
        case .establish:
            multiplier *= experienceWords(for: track)
                .isDisjoint(with: ["arrival", "opening", "light", "morning", "threshold"]) ? 1 : 1.35
        case .resonate:
            if overlap > 0 { multiplier *= 1.25 }
        case .complicate:
            multiplier *= experienceWords(for: track)
                .isDisjoint(with: ["strange", "wild", "dark", "mystery", "storm", "mischief"]) ? 1 : 1.55
        case .afterimage:
            multiplier *= experienceWords(for: track)
                .isDisjoint(with: ["memory", "glow", "dream", "tender", "home", "echo"]) ? 1 : 1.55
        case .release:
            if overlap > 0 {
                multiplier *= 0.55
            }
            multiplier *= experienceWords(for: track)
                .isDisjoint(with: ["quiet", "air", "rest", "instrumental", "ambient", "open"]) ? 1 : 1.7
        }
        return max(0.2, multiplier)
    }

    private static func experienceWords(for track: RadioTrack) -> Set<String> {
        experienceWords(in:
            track.moodTags
                + (track.meaning?.themeTags ?? [])
                + (track.meaning?.imageTags ?? [])
                + [track.meaning?.ordinaryLifeCue ?? ""]
        )
    }

    private static func experienceWords(for banter: RadioBanter) -> Set<String> {
        var values = [banter.category.rawValue, banter.caption]
        if let conditions = banter.conditions {
            values += conditions.pageTypes?.map(\.rawValue) ?? []
            values += conditions.lastKeptPageTypes?.map(\.rawValue) ?? []
            values += conditions.sourceIDs ?? []
            values += conditions.sourceTags ?? []
            values += conditions.weatherTags ?? []
        }
        return experienceWords(in: values)
    }

    private static func experienceWords(in values: [String]) -> Set<String> {
        Set(values.flatMap { value in
            value.lowercased()
                .split { character in
                    !character.isLetter && !character.isNumber
                }
                .map(String.init)
                .filter { $0.count > 2 }
        })
    }

    private static func aliveScore(seed: String, weight: Double) -> Double {
        -log(max(stableUnit(seed), 0.000_001)) / max(weight, 0.05)
    }

    private static func stableUnit(_ seed: String) -> Double {
        let bucket = UInt(bitPattern: seed.stableHash) % 9_007_199_254_740_991
        return Double(bucket + 1) / 9_007_199_254_740_992.0
    }
}

struct BodySourceSignal: Equatable {
    struct Metric: Codable, Equatable, Identifiable {
        var id: String
        var label: String
        var value: String
        var unit: String
        var kind: String
        var observedAt: Date?

        init(id: String, label: String, value: String, unit: String = "", kind: String = "quantity", observedAt: Date? = nil) {
            self.id = id
            self.label = label
            self.value = value
            self.unit = unit
            self.kind = kind
            self.observedAt = observedAt
        }

        var displayText: String {
            [label, value, unit].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    var status: String
    var score: Int
    var phrase: String
    var metrics: [Metric] = []

    var isAvailable: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct WeatherSourceSignal: Equatable {
    var phrase: String
    var source: String
    var currentTemperature: String?
    var forecast: String?
    var conditionSymbolName: String

    var isAvailable: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        phrase: String,
        source: String,
        currentTemperature: String? = nil,
        forecast: String? = nil,
        conditionSymbolName: String? = nil
    ) {
        self.phrase = phrase
        self.source = source
        self.currentTemperature = currentTemperature ?? Self.extractTemperature(from: phrase)
        self.forecast = forecast ?? Self.extractForecast(from: phrase)
        self.conditionSymbolName = conditionSymbolName ?? Self.symbolName(for: phrase)
    }

    private static func extractTemperature(from phrase: String) -> String? {
        guard let range = phrase.range(of: #"[-+]?\d{1,3}\s?°?\s?[FC]?"#, options: .regularExpression) else {
            return nil
        }
        let value = String(phrase[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func extractForecast(from phrase: String) -> String? {
        let lowered = phrase.lowercased()
        let markers = ["forecast:", "later:", "tonight:", "tomorrow:"]
        for marker in markers {
            guard let range = lowered.range(of: marker) else { continue }
            let start = phrase.index(phrase.startIndex, offsetBy: lowered.distance(from: lowered.startIndex, to: range.upperBound))
            let value = phrase[start...].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func symbolName(for phrase: String) -> String {
        let lowered = phrase.lowercased()
        if lowered.contains("storm") || lowered.contains("thunder") {
            return "cloud.bolt.rain"
        }
        if lowered.contains("snow") || lowered.contains("sleet") || lowered.contains("ice") {
            return "snowflake"
        }
        if lowered.contains("rain") || lowered.contains("drizzle") || lowered.contains("shower") {
            return "cloud.rain"
        }
        if lowered.contains("fog") || lowered.contains("mist") || lowered.contains("haze") {
            return "cloud.fog"
        }
        if lowered.contains("wind") || lowered.contains("gust") || lowered.contains("breez") {
            return "wind"
        }
        if lowered.contains("cloud") || lowered.contains("overcast") {
            return "cloud"
        }
        if lowered.contains("clear") || lowered.contains("sun") || lowered.contains("bright") {
            return "sun.max"
        }
        return "cloud.sun"
    }
}

struct EnchantedWeatherSignal: Equatable {
    var summary: String
    var enchantified: String
    var selector: String
    var symbolName: String
}

struct MoonPhase: Equatable {
    var name: String
    var symbolName: String
    var illuminatedFraction: Double
    var ageDays: Double
    var enchantedLine: String
}

/// Pure local astronomy — close enough for a storybook (within a few hours
/// of the true phase), no network or location required.
enum MoonPhaseCalendar {
    static let synodicMonthDays = 29.530588853

    private static let referenceNewMoon: Date = {
        // 2000-01-06 18:14 UTC, a well-known new moon epoch.
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 6
        components.hour = 18
        components.minute = 14
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 947182440)
    }()

    /// The next calendar day (after the given date) that reads as a New Moon —
    /// when the Goblin Market opens.
    static func nextNewMoon(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        var probe = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        for _ in 0..<35 {
            if phase(on: probe).name == "New Moon" { return probe }
            probe = calendar.date(byAdding: .day, value: 1, to: probe) ?? probe
        }
        return probe
    }

    /// The next calendar day (after the given date) that reads as a Full Moon —
    /// when the Luminous Gathering is kept.
    static func nextFullMoon(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        var probe = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        for _ in 0..<35 {
            if phase(on: probe).name == "Full Moon" { return probe }
            probe = calendar.date(byAdding: .day, value: 1, to: probe) ?? probe
        }
        return probe
    }

    static func phase(on date: Date = Date()) -> MoonPhase {
        let elapsed = date.timeIntervalSince(referenceNewMoon) / 86_400
        let age = elapsed.truncatingRemainder(dividingBy: synodicMonthDays)
        let normalizedAge = age < 0 ? age + synodicMonthDays : age
        let cyclePosition = normalizedAge / synodicMonthDays
        let illumination = (1 - cos(2 * Double.pi * cyclePosition)) / 2
        let index = Int((cyclePosition * 8).rounded()) % 8

        let (name, symbolName, line): (String, String, String)
        switch index {
        case 0:
            (name, symbolName, line) = (
                "New Moon",
                "moonphase.new.moon",
                "The moon is a held breath tonight, a page before the first word."
            )
        case 1:
            (name, symbolName, line) = (
                "Waxing Crescent",
                "moonphase.waxing.crescent",
                "A thin silver paring of moon is just beginning to write itself."
            )
        case 2:
            (name, symbolName, line) = (
                "First Quarter",
                "moonphase.first.quarter",
                "Half the moon is lit tonight, like a door left ajar."
            )
        case 3:
            (name, symbolName, line) = (
                "Waxing Gibbous",
                "moonphase.waxing.gibbous",
                "The moon is fattening toward full, gathering light like gossip."
            )
        case 4:
            (name, symbolName, line) = (
                "Full Moon",
                "moonphase.full.moon",
                "The moon is full. Every margin of the night is annotated."
            )
        case 5:
            (name, symbolName, line) = (
                "Waning Gibbous",
                "moonphase.waning.gibbous",
                "The moon is giving its light back now, a little each night."
            )
        case 6:
            (name, symbolName, line) = (
                "Last Quarter",
                "moonphase.last.quarter",
                "Half-lit and leaving: the moon keeps only what matters."
            )
        default:
            (name, symbolName, line) = (
                "Waning Crescent",
                "moonphase.waning.crescent",
                "The last sliver of moon hangs like a closing parenthesis."
            )
        }

        return MoonPhase(
            name: name,
            symbolName: symbolName,
            illuminatedFraction: illumination,
            ageDays: normalizedAge,
            enchantedLine: line
        )
    }
}

enum AnchorKind: String, Codable, CaseIterable, Equatable {
    case notice = "NOTICE"
    case embark = "EMBARK"
    case sense = "SENSE"
    case write = "WRITE"
    case rest = "REST"

    var title: String {
        switch self {
        case .notice: return "Notice"
        case .embark: return "Embark"
        case .sense: return "Sense"
        case .write: return "Write"
        case .rest: return "Rest"
        }
    }
}

struct AnchorRecord: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var kind: AnchorKind
    var belief: Int
    var created: String
    var weather: String
    var moon: String
    var season: String
    var playerWords: String
    var academyEcho: String
    var outerStacksRoom: String
    var fae: String
    var miniStory: String
    var localRule: String
    var visitCount: Int
    var lastVisited: String

    func distanceMeters(to latitude: Double, longitude: Double) -> Double {
        AnchorMath.distanceMeters(
            fromLatitude: self.latitude,
            longitude: self.longitude,
            toLatitude: latitude,
            longitude: longitude
        )
    }

    func checkedIn(on date: Date, calendar: Calendar = .current, beliefGiven: Int = AnchorRegistry.checkInBeliefReward) -> AnchorRecord {
        var updated = self
        updated.visitCount += 1
        updated.belief += max(0, beliefGiven)
        updated.lastVisited = AnchorRegistry.visitDateFormatter.string(from: date)
        return updated
    }
}

enum AnchorTurnBuilder {
    static func turn(anchor: AnchorRecord, visitMode: String, slotKey: String) -> StoryTurn {
        let roomName = anchor.name.nonEmpty ?? "This Anchor Room"
        let keeper = anchor.fae.nonEmpty ?? roomName
        let rule = anchor.localRule.nonEmpty ?? "the room will not open further until it is noticed with care"
        let isFirstVisit = visitMode == "FIRST_VISIT"
        let candidates: [StoryTurnKind] = isFirstVisit
            ? [.revealWant, .factLearned, .realNoticing]
            : [.relationshipShift, .factLearned, .revealWant]
        let turnKind = candidates[abs("\(slotKey)-anchor-turn".stableHash) % candidates.count]

        let want = isFirstVisit
            ? "to show the reader what \(roomName) has been waiting to have noticed"
            : "to show the reader it kept its small story since visit \(anchor.visitCount)"
        let obstacle = isFirstVisit
            ? "\(rule) before the threshold will trust a stranger"
            : "\(rule), and memory asks for proof that the reader returned with attention"

        let statement: String
        if isFirstVisit {
            statement = "\(roomName) reveals what it has been holding, and the reader is no longer a stranger to it."
        } else {
            statement = "\(roomName)'s small story takes its next real step, and it shows the reader it remembered them."
        }

        let landings: [String: String] = [
            "slice-of-life": "The room trusts the reader with one more exact, kept detail; the bond warms a notch.",
            "progress-arc": "\(keeper) reveals the next piece of what it guards, and the room's story moves a step deeper into the stacks.",
            "surprise": "A side door gives under the reader's attention; something adjacent to this place stirs and may call back later."
        ]

        return StoryTurn(
            kind: turnKind,
            character: keeper,
            want: want,
            obstacle: obstacle,
            statement: statement,
            register: .quiet,
            landings: landings
        )
    }
}

enum AnchorMiniStory {
    static let maxLength = 240

    static func advanced(previous: String, landing: String) -> String {
        let cleanLanding = landing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLanding.isEmpty else {
            return previous.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let prior = previous.bookPreviewSentenceLimit(1).trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = prior.isEmpty
            ? cleanLanding
            : "\(cleanLanding) Before that, \(prior)"
        return clipped(combined)
    }

    static func landing(from metadata: [String: String], tags: [String]) -> String? {
        let role = selectedChoiceRole(from: tags)
        let keyedLanding = role.flatMap { metadata[metadataKey(for: $0)]?.nonEmpty }
        return keyedLanding
            ?? metadata["storyTurnStatement"]?.nonEmpty
            ?? metadata["storyResult\(role.map { resultSuffix(for: $0) } ?? "")"]?.nonEmpty
    }

    private static func selectedChoiceRole(from tags: [String]) -> String? {
        tags
            .first { $0.hasPrefix("choice:") }
            .map { String($0.dropFirst("choice:".count)) }
            .flatMap(normalizedRole)
    }

    private static func normalizedRole(_ raw: String) -> String? {
        let compact = raw.lowercased().filter { $0.isLetter || $0.isNumber }
        switch compact {
        case "sliceoflife": return "slice-of-life"
        case "progressarc": return "progress-arc"
        case "surprise": return "surprise"
        default: return nil
        }
    }

    private static func metadataKey(for role: String) -> String {
        switch role {
        case "slice-of-life": return "storyTurnLandingSliceOfLife"
        case "progress-arc": return "storyTurnLandingProgressArc"
        default: return "storyTurnLandingSurprise"
        }
    }

    private static func resultSuffix(for role: String) -> String {
        switch role {
        case "slice-of-life": return "SliceOfLife"
        case "progress-arc": return "ProgressArc"
        default: return "Surprise"
        }
    }

    private static func clipped(_ value: String) -> String {
        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard normalized.count > maxLength else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: maxLength - 1)
        return String(normalized[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

struct AnchorPlaceDraft: Equatable {
    var name: String
    var words: String
    var kind: AnchorKind
    var latitude: Double
    var longitude: Double
}

struct AnchorProximity: Codable, Equatable {
    var anchor: AnchorRecord
    var distanceMeters: Double

    var isInsideRadius: Bool {
        distanceMeters <= anchor.radiusMeters
    }

    var nextVisitCount: Int {
        anchor.visitCount + 1
    }

    var visitMode: String {
        anchor.visitCount == 0 ? "FIRST_VISIT" : "RETURN_VISIT"
    }
}

enum AnchorRegistry {
    static let proximityRadiusMeters = 200.0
    static let checkInBeliefReward = 2

    /// Anchors that no longer exist in the player's world. Stored ledgers may
    /// still contain them, so they are filtered out on load.
    static let retiredAnchorIDs: Set<String> = ["archive-of-fermentation"]

    /// Ships empty: every Anchor belongs to a player's save, never to the
    /// binary. Local anchors arrive by anchoring places in the world or
    /// by dropping a local-anchors.json into the Documents folder.
    static let defaultAnchors: [AnchorRecord] = []


    static let visitDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func nearestAnchor(to latitude: Double, longitude: Double, anchors: [AnchorRecord]) -> AnchorProximity? {
        anchors
            .map { AnchorProximity(anchor: $0, distanceMeters: $0.distanceMeters(to: latitude, longitude: longitude)) }
            .filter(\.isInsideRadius)
            .min { $0.distanceMeters < $1.distanceMeters }
    }

    static func currentSeason(for date: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        switch month {
        case 3...5: return "Mud Season"
        case 6...8: return "Gold Season"
        case 9...11: return "Stick Season"
        default: return "Deep Winter"
        }
    }
}

enum AnchorDoorbells {
    struct Bell: Equatable {
        var anchorID: String
        var anchorName: String
        var latitude: Double
        var longitude: Double
        var radiusMeters: Double
        var title: String
        var body: String
        var keepPrompt: String
        var tags: [String]
    }

    static let maxArmed = 4
    static let rearmDays = 3

    static func plan(anchors: [AnchorRecord], lastArmed: [String: Date], now: Date) -> [Bell] {
        anchors.sorted {
            if $0.visitCount == $1.visitCount {
                if $0.belief == $1.belief { return $0.id < $1.id }
                return $0.belief > $1.belief
            }
            return $0.visitCount > $1.visitCount
        }
        .filter { anchor in
            guard let armed = lastArmed[anchor.id] else { return true }
            return now.timeIntervalSince(armed) >= Double(rearmDays) * 86_400
        }
        .prefix(maxArmed)
        .map { anchor in
            let text = "\(anchor.name) \(anchor.kind.rawValue) \(anchor.playerWords)".lowercased()
            let publicMissions = PlayfulMissionRegistry.coreMissions.filter { $0.tags.contains("public") }
            let mission = PlayfulMissionRegistry.placeMission(matching: text)
                ?? publicMissions[abs(anchor.id.stableHash) % publicMissions.count]
            return Bell(
                anchorID: anchor.id, anchorName: anchor.name,
                latitude: anchor.latitude, longitude: anchor.longitude,
                radiusMeters: max(anchor.radiusMeters, 150),
                title: "The \(anchor.name) door is lit",
                body: "You're near a page I keep open. \(mission.prompt)",
                keepPrompt: mission.proofPrompt,
                tags: mission.tags + ["anchor:\(anchor.id)", "doorbell"]
            )
        }
    }
}

enum AnchorMath {
    static func distanceMeters(
        fromLatitude latitude1: Double,
        longitude longitude1: Double,
        toLatitude latitude2: Double,
        longitude longitude2: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let phi1 = latitude1 * .pi / 180
        let phi2 = latitude2 * .pi / 180
        let deltaPhi = (latitude2 - latitude1) * .pi / 180
        let deltaLambda = (longitude2 - longitude1) * .pi / 180
        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// A quest a character has asked of the player, tucked into the Book's
/// flyleaf. Enchantify's Inside Cover rules: at most five active at a time;
/// completed by a real-world sense act or enchantment plus proof.
struct UnwrittenElective: Codable, Identifiable, Equatable {
    var id: String
    var characterID: String
    var characterName: String
    var title: String
    var ask: String
    var whyItMatters: String
    var practiceShape: String
    var createdAt: Date
    var completedAt: Date?
    /// A clean ending chosen in the flyleaf. Resting a quest frees its slot
    /// without manufacturing proof or letting it count as completion.
    var releasedAt: Date? = nil
    var proof: String?
    var proofPhotoURL: String? = nil
    var proofLocationSummary: String? = nil
    var targetPlaceName: String? = nil
    var targetLatitude: Double? = nil
    var targetLongitude: Double? = nil
    var targetRadiusMeters: Double? = nil
    /// Present only when the quest is a favor asked by the Book itself. This
    /// lets the favor's promise resolve from the same proof Page as every other
    /// flyleaf quest without inventing a parallel quest system.
    var bookFavorID: String? = nil

    var isActive: Bool { completedAt == nil && releasedAt == nil }
    var isReleased: Bool { releasedAt != nil }

    static let maxActive = 5
    static let completionBeliefReward = BeliefEconomyPolicy.electiveCompletionReward
}

struct AcademySession: Equatable {
    enum Kind: String {
        case classSession = "class"
        case club
    }

    var id: String
    var kind: Kind
    var name: String
    var leader: String
    var leaderEntityID: String?
    var room: String
    var companions: [String]
    var teaches: String
    var style: String
    var subjectThreadID: String
}

struct AcademyLessonModule: Equatable {
    var id: String
    var sessionID: String
    var title: String
    var realSubject: String
    var concept: String
    var lectureBeats: [String]
    var demonstration: String
    var interactionPrompt: String
    var realWorldPractice: String
}

/// The hands-on portion of an Academy meeting.  Lessons keep their teaching
/// shape, but each session can now hand the reader one practice that belongs
/// to that room rather than a generic story choice.
struct AcademyActivity: Equatable {
    enum Kind: String, Equatable, Hashable {
        case compassRun
        case evidenceLog
        case thresholdPlan
        case sensoryScore
        case sentenceWorkshop
        case restCheckIn
        case enchantmentCasting
        case landingProtocol
        case souvenirCircle
        case marginalNote
        case workshopNote
        case doorProtocol
    }

    struct Field: Equatable, Identifiable {
        var id: String
        var label: String
        var placeholder: String
    }

    var id: String
    var sessionID: String
    var kind: Kind
    var title: String
    var invitation: String
    var actionTitle: String
    var fields: [Field]

    var isCompassRun: Bool { kind == .compassRun }
}

/// Registry rather than prompt-only copy: this gives every class and club a
/// durable interaction contract, and makes a completed practice able to return
/// to the session which assigned it.
enum AcademyActivityRegistry {
    static let activities: [String: AcademyActivity] = [
        "art-of-the-glint": AcademyActivity(
            id: "glint-evidence-log", sessionID: "art-of-the-glint", kind: .evidenceLog,
            title: "The Glint Ledger",
            invitation: "Boggle wants evidence before enchantment. Give one ordinary thing three exact facts.",
            actionTitle: "Bring the evidence back",
            fields: [
                .init(id: "fact-one", label: "First fact", placeholder: "A visible, audible, or tangible detail"),
                .init(id: "fact-two", label: "Second fact", placeholder: "Another fact, not an interpretation"),
                .init(id: "fact-three", label: "Third fact", placeholder: "The oddest exact detail")
            ]
        ),
        "wayfinding-kineticism": AcademyActivity(
            id: "wayfinding-threshold-plan", sessionID: "wayfinding-kineticism", kind: .thresholdPlan,
            title: "Mark a Threshold",
            invitation: "Momort only accepts routes with a return. Make one small crossing specific enough to finish.",
            actionTitle: "Mark this crossing",
            fields: [
                .init(id: "threshold", label: "The threshold", placeholder: "The door, corner, or first small move"),
                .init(id: "destination", label: "Where it leads", placeholder: "A humane destination"),
                .init(id: "return", label: "How you return", placeholder: "The clear way back")
            ]
        ),
        "synesthetic-resonance": AcademyActivity(
            id: "resonance-sensory-score", sessionID: "synesthetic-resonance", kind: .sensoryScore,
            title: "Score the Room",
            invitation: "Euphony asks for the body of a moment before its explanation.",
            actionTitle: "Let the room answer",
            fields: [
                .init(id: "sound", label: "One sound", placeholder: "What you can actually hear"),
                .init(id: "color", label: "Its color", placeholder: "A color that fits the evidence"),
                .init(id: "body", label: "One body sensation", placeholder: "Temperature, pressure, breath, posture")
            ]
        ),
        "ink-binding": AcademyActivity(
            id: "ink-binding-workshop", sessionID: "ink-binding", kind: .sentenceWorkshop,
            title: "The Souvenir Workshop",
            invitation: "Villanelle asks for one true sentence, then one word brave enough to become more exact.",
            actionTitle: "Submit the revision",
            fields: [
                .init(id: "sentence", label: "The sentence", placeholder: "One real moment, held without explaining it"),
                .init(id: "revision", label: "The word you revised", placeholder: "Old word → truer word")
            ]
        ),
        "quiet-hours": AcademyActivity(
            id: "quiet-hours-check-in", sessionID: "quiet-hours", kind: .restCheckIn,
            title: "A Small Stop",
            invitation: "Set the page down for a minute if you can. Stonebrook only asks what the pause protected.",
            actionTitle: "Return from the pause",
            fields: [.init(id: "clarity", label: "What became clearer?", placeholder: "A sentence is enough")]
        ),
        "basic-enchantments": AcademyActivity(
            id: "basic-enchantments-spellbook", sessionID: "basic-enchantments", kind: .enchantmentCasting,
            title: "Open the Spellbook",
            invitation: "Wispwood has brought all fourteen ordinary Enchantments. Choose the one whose form helps you attend to a real subject, then cast it with a photograph.",
            actionTitle: "Choose an Enchantment", fields: []
        ),
        "book-jumping": AcademyActivity(
            id: "book-jumping-landing-protocol", sessionID: "book-jumping", kind: .landingProtocol,
            title: "Set the Bookmark",
            invitation: "Permancer will not open a page until the landing and exit are both visible.",
            actionTitle: "Set the protocol",
            fields: [
                .init(id: "door", label: "The door", placeholder: "What you are entering"),
                .init(id: "weather", label: "Its narrative weather", placeholder: "The mood or genre pressure"),
                .init(id: "exit", label: "The exit", placeholder: "Your return point")
            ]
        ),
        "compass-running": AcademyActivity(
            id: "compass-running-field-loop", sessionID: "compass-running", kind: .compassRun,
            title: "Take the Field Gate",
            invitation: "Stonebrook has laid out a complete Compass Run: North, East, South, West, then Center. Choose constraints, go only as far as is kind, and bring back one true sentence.",
            actionTitle: "Begin the Compass Run", fields: []
        ),
        "compass-society": AcademyActivity(
            id: "compass-society-circle", sessionID: "compass-society", kind: .souvenirCircle,
            title: "The Souvenir Circle",
            invitation: "The circle receives evidence, not performance. Offer a sentence and the question a kind listener could ask it.",
            actionTitle: "Read to the circle",
            fields: [
                .init(id: "souvenir", label: "Your souvenir sentence", placeholder: "One small true observation"),
                .init(id: "question", label: "A listener's question", placeholder: "A question about one concrete detail")
            ]
        ),
        "marginalia-guild": AcademyActivity(
            id: "marginalia-future-note", sessionID: "marginalia-guild", kind: .marginalNote,
            title: "Write to a Future Reader",
            invitation: "Put a small honest note beside a line worth keeping. Cleverness may attend, but it is not required.",
            actionTitle: "Leave the note",
            fields: [
                .init(id: "line", label: "The line or image", placeholder: "Copy or describe what you are answering"),
                .init(id: "note", label: "Your marginal note", placeholder: "A future reader could answer this")
            ]
        ),
        "inkwright-society": AcademyActivity(
            id: "inkwright-workshop-note", sessionID: "inkwright-society", kind: .workshopNote,
            title: "Find the Living Line",
            invitation: "The circle wants one line that is alive and one question that helps it grow.",
            actionTitle: "Offer the workshop note",
            fields: [
                .init(id: "line", label: "The living line", placeholder: "A line from your own writing or today"),
                .init(id: "question", label: "The growing question", placeholder: "Describe the effect before prescribing a fix")
            ]
        ),
        "book-jumpers": AcademyActivity(
            id: "book-jumpers-door-protocol", sessionID: "book-jumpers", kind: .doorProtocol,
            title: "Choose a Spine, Then a Door",
            invitation: "The club chooses one book from the public stacks, then agrees on its door, landing, and return before anybody jumps.",
            actionTitle: "Put it to the group",
            fields: [
                .init(id: "door", label: "What counts as this book's door?", placeholder: "The exact threshold in the chosen story"),
                .init(id: "landing", label: "Where do you land in it?", placeholder: "The first safe beat inside the chosen book"),
                .init(id: "return", label: "What brings everyone back?", placeholder: "The chosen book's return shadow")
            ]
        )
    ]

    static func activity(for sessionID: String) -> AcademyActivity? {
        activities[sessionID]
    }
}

/// The contract for the page that receives a completed Academy practice.
/// Keeping this separate from the original lesson prompt prevents a return
/// from becoming a second performance of the same classroom scene.
struct AcademyActivityDebrief: Equatable {
    var activityTitle: String
    var outcome: String

    init?(metadata: [String: String]) {
        let outcome = (metadata["academyActivityOutcome"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outcome.isEmpty else { return nil }
        self.activityTitle = (metadata["academyActivityTitle"] ?? "the Academy practice")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.outcome = outcome
    }

    var promptSection: String {
        """
        THIS IS A PRACTICE RETURN, NOT A REPEATED LESSON.
        The reader completed “\(activityTitle)” and submitted the following answer. This answer is source-of-truth:

        READER'S COMPLETED PRACTICE:
        \(outcome)

        RESPONSE CONTRACT:
        - Begin after the original classroom scene. Do not restage its entrance, demonstration, lecture, or question.
        - The leader must respond to at least one exact word, image, choice, or sensory detail from the submitted answer. Quote or name that detail so the reader can tell their answer was read.
        - Let the lesson advance by applying its concept to that exact detail. Do not merely praise, summarize, or repeat the form labels.
        - A companion may react, but the reader's submitted answer remains the cause of this new beat.
        - End with one genuinely new observation or question shaped by the answer. Do not assign the same practice again.
        """
    }

    /// A small lexical gate for generated debriefs. The prompt requires one
    /// exact detail, so a response with no overlap has not yet received the
    /// reader's work and should be repaired before it is shown.
    func isAcknowledged(in prose: String) -> Bool {
        let haystack = prose.lowercased()
        let anchors = anchorTerms
        guard !anchors.isEmpty else { return true }
        return anchors.contains { haystack.contains($0) }
    }

    var anchorTerms: [String] {
        let generic = Set([
            "about", "after", "and", "answer", "became", "before", "book", "chosen", "class",
            "color", "completed", "detail", "evidence", "field", "lesson", "moment", "one",
            "practice", "reader", "response", "room", "same", "sentence", "sound", "stance", "the",
            "thing", "this", "three", "what", "when", "where", "with", "your"
        ])
        let values = outcome
            .components(separatedBy: .newlines)
            .map { line in
                line.split(separator: ":", maxSplits: 1).last.map(String.init) ?? line
            }
            .joined(separator: " ")
        let terms = values.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !generic.contains($0) }
        return Array(Set(terms)).sorted { left, right in
            if left.count == right.count { return left < right }
            return left.count > right.count
        }
    }
}

/// Builds a committed Turn for a Class or Club page. The change is social and
/// rides ALONGSIDE the lesson, never replacing it: classes stay quiet and keep
/// teaching their concept, while clubs (no curriculum to protect) lean into the
/// relationship moving. This is what keeps the leader from being a mouthpiece
/// and classmates from being wallpaper.
enum AcademyTurnBuilder {
    static func turn(
        session: AcademySession,
        lesson: AcademyLessonModule?,
        isClub: Bool,
        slotKey: String
    ) -> StoryTurn {
        let leader = session.leader
        let classmate = session.companions.first ?? "another student"
        let subject = lesson?.realSubject.nonEmpty ?? session.teaches

        let candidates: [StoryTurnKind] = isClub
            ? [.relationshipShift, .changeOfHeart, .revealWant]
            : [.revealWant, .factLearned, .relationshipShift]
        let turnKind = candidates[abs("\(slotKey)-academy-turn".stableHash) % candidates.count]

        let want = isClub
            ? "to pull the reader deeper into \(session.name)'s orbit"
            : "to make \(subject) actually land for the reader, not just be recited"
        let obstacle = isClub
            ? "\(classmate) is hanging back, not sure the reader belongs yet"
            : "the lesson keeps threatening to flatten into a lecture"

        var statement: String
        switch turnKind {
        case .relationshipShift:
            statement = "What sits between the reader and \(isClub ? classmate : leader) shifts by one honest notch."
        case .changeOfHeart:
            statement = "\(leader) changes how they read the reader, and treats them differently by the end."
        case .revealWant:
            statement = "\(leader) reveals why \(subject) actually matters to them, personally."
        case .factLearned:
            statement = "One concrete thing about \(subject) clicks for the reader that didn't before."
        default:
            statement = "Something small but real changes between the reader and \(leader)."
        }
        if !isClub {
            statement += " The lesson's point still lands."
        }

        let landings: [String: String] = [
            "slice-of-life": "A quiet personal beat: \(leader) lets one human thing show, and the reader sees the teacher, not the lecture.",
            "progress-arc": isClub
                ? "\(classmate) decides the reader belongs, and \(session.name) pulls them a step further in."
                : "The concept of \(subject) is demonstrated for real, carried by \(leader)'s own stake in it.",
            "surprise": "\(classmate) reveals something sideways — about \(subject), the room, or \(leader) — that recolors the session."
        ]

        return StoryTurn(
            kind: turnKind,
            character: leader,
            want: want,
            obstacle: obstacle,
            statement: statement,
            register: isClub ? .active : .quiet,
            landings: landings
        )
    }
}

/// The Academy's canonical weekly rhythm, ported from Enchantify's
/// school-life schedule: morning class 9-11, afternoon class 1-3, clubs 7-10.
enum AcademyScheduleRegistry {
    static let classes: [String: AcademySession] = [
        "art-of-the-glint": AcademySession(
            id: "art-of-the-glint", kind: .classSession,
            name: "The Art of the Glint", leader: "Professor Lydia Boggle", leaderEntityID: "lydia-boggle",
            room: "Wing 4 — The Glint Hall",
            companions: ["Zara Finch", "Aria Silverthorn", "Wilbur \"Wordplay\" Lexi"],
            teaches: "Notice (North): the Rut turns the world into wallpaper; one specific, odd detail rips the wallpaper down. Everything in the room is alive if you pay it the courtesy of noticing.",
            style: "playful, specific, concrete, with puns that conceal serious doctrine",
            subjectThreadID: "notice-north"
        ),
        "wayfinding-kineticism": AcademySession(
            id: "wayfinding-kineticism", kind: .classSession,
            name: "Wayfinding & Kineticism", leader: "Professor Kyle Momort", leaderEntityID: "professor-kyle-momort",
            room: "Wing 2 — The Momentum Yard",
            companions: ["Finn Bridges", "Lara Rourck"],
            teaches: "Embark (East): breaking routine, micro-adventures, the Leap of Ink. Momort teaches it slightly corrupted — escape routes rather than arrivals; the true East is a threshold crossed with intention.",
            style: "brisk, charismatic, a little too fond of exits",
            subjectThreadID: "embark-east"
        ),
        "synesthetic-resonance": AcademySession(
            id: "synesthetic-resonance", kind: .classSession,
            name: "Synesthetic Resonance", leader: "Professor Eleanor Euphony", leaderEntityID: "professor-eleanor-euphony",
            room: "Wing 3 — The Resonance Chamber",
            companions: ["Aria Silverthorn", "Elio"],
            teaches: "Sense (South): hearing colors, smelling the history of a room, the Heartbeat of the Stone. Full sensory presence as the solar moment of experience.",
            style: "lush, attentive, hears what the room is humming",
            subjectThreadID: "sense-south"
        ),
        "ink-binding": AcademySession(
            id: "ink-binding", kind: .classSession,
            name: "Ink-Binding", leader: "Professor Vivian Villanelle", leaderEntityID: "professor-vivian-villanelle",
            room: "The Inkworks",
            companions: ["Zara Finch", "Ellie Moons"],
            teaches: "Write (West): distilling an entire experience into a single permanent magical sentence. What is written is kept; what is not written dissolves.",
            style: "exacting, lyrical, kind",
            subjectThreadID: "write-west"
        ),
        "quiet-hours": AcademySession(
            id: "quiet-hours", kind: .classSession,
            name: "Quiet Hours", leader: "Professor Cedric Stonebrook", leaderEntityID: "professor-cedric-stonebrook",
            room: "The Still Room",
            companions: ["whoever needs it that day"],
            teaches: "Rest (Center): integration and the Permission to Stop. Not a direction — the ground from which all directions emerge.",
            style: "slow, grounded, speaks in almost-koans",
            subjectThreadID: "rest-center"
        ),
        "basic-enchantments": AcademySession(
            id: "basic-enchantments", kind: .classSession,
            name: "Basic Enchantments", leader: "Professor Luna Wispwood", leaderEntityID: "professor-luna-wispwood",
            room: "The Spark Annex",
            companions: ["Finn Bridges", "Wilbur \"Wordplay\" Lexi"],
            teaches: "Casting text-based enchantments on ordinary subjects: Everything Speaks, Everything's Poetry, and how to let an object answer through close attention.",
            style: "scattered, sparking, delighted by accidents",
            subjectThreadID: "everyday-enchantments"
        ),
        "book-jumping": AcademySession(
            id: "book-jumping", kind: .classSession,
            name: "Book Jumping", leader: "Professor Permancer", leaderEntityID: "professor-permancer",
            room: "The Vault of Doors",
            companions: ["Zara Finch", "Orion Blackthorn"],
            teaches: "Entering and exiting stories safely: landing without tearing the page, reading the weather of a narrative before stepping in, and always knowing where your bookmark is.",
            style: "precise, adventurous, fiercely safety-minded",
            subjectThreadID: "book-jumping"
        ),
        "compass-running": AcademySession(
            id: "compass-running", kind: .classSession,
            name: "Compass Running", leader: "Professor Cedric Stonebrook", leaderEntityID: "professor-cedric-stonebrook",
            room: "The Open Field Gate",
            companions: ["the whole motley Saturday crew"],
            teaches: "Full N-E-S-W compass runs in the field: constraints first, magic after, one small adventure with a souvenir sentence at the end.",
            style: "practical, weathered, quietly encouraging",
            subjectThreadID: "compass-running"
        )
    ]

    static let clubs: [String: AcademySession] = [
        "compass-society": AcademySession(
            id: "compass-society", kind: .club,
            name: "The Compass Society", leader: "Zara Finch (de facto anchor)", leaderEntityID: "zara-finch",
            room: "The Secret Garden of Prose",
            companions: ["Zara Finch", "Lara Rourck", "Elio (47 Compass Runs, won't explain the 47th)"],
            teaches: "Members read their One-Sentence Souvenirs aloud with real reverence. No one mocks a sentence here. Sharing a souvenir makes it more real.",
            style: "warm, literary, slightly emotionally intense",
            subjectThreadID: "compass-society"
        ),
        "marginalia-guild": AcademySession(
            id: "marginalia-guild", kind: .club,
            name: "The Marginalia Guild", leader: "Professor Lydia Boggle (officially)", leaderEntityID: "lydia-boggle",
            room: "The Corridor of Whispered Secrets",
            companions: ["Ellie Moons", "a second-year six months deep in one mythology volume"],
            teaches: "Annotating books together and leaving notes for future readers — the best conversations are held with someone who read the same book fifty years ago and wrote something true in the margin.",
            style: "playful, curious, surprisingly deep",
            subjectThreadID: "marginalia-guild"
        ),
        "inkwright-society": AcademySession(
            id: "inkwright-society", kind: .club,
            name: "The Inkwright Society", leader: "Professor Maxwell Thorne (observing)", leaderEntityID: nil,
            room: "The Bibliophonic Hall",
            companions: ["Finn Bridges", "Emberheart students with serious notebooks"],
            teaches: "Write, share, workshop — honest first, kind second. Each meeting ends with a burning: a piece read aloud, then ritually burned, its smoke becoming words absorbed into the library ceiling.",
            style: "intense, creative, committed — the writing here is meant",
            subjectThreadID: "inkwright-society"
        ),
        "book-jumpers": AcademySession(
            id: "book-jumpers", kind: .club,
            name: "The Book Jumpers", leader: "Professor Permancer", leaderEntityID: "professor-permancer",
            room: "The Vault of Doors",
            companions: ["Zara Finch", "Orion Blackthorn"],
            teaches: "Short, controlled jumps into well-mapped stories. Half the meeting is planning the landing; the other half is arguing about what counts as a door.",
            style: "adventurous, giddy, strictly rule-bound about exits",
            subjectThreadID: "book-jumpers"
        )
    ]

    static let lessonModules: [String: AcademyLessonModule] = [
        "art-of-the-glint": AcademyLessonModule(
            id: "glint-specificity-001",
            sessionID: "art-of-the-glint",
            title: "Specificity Breaks the Rut",
            realSubject: "attention training and close observation",
            concept: "A specific, observable detail interrupts habituation better than a general judgment.",
            lectureBeats: [
                "The mind wallpapers familiar rooms to save effort.",
                "A concrete detail restores contact with the real object.",
                "A good noticing names evidence before interpretation."
            ],
            demonstration: "Professor Boggle places three ordinary objects under lamplight and asks which one changed once it was described exactly.",
            interactionPrompt: "Name one exact classroom detail before saying what it means.",
            realWorldPractice: "Find one ignored object today and write three observable facts about it before any metaphor."
        ),
        "wayfinding-kineticism": AcademyLessonModule(
            id: "wayfinding-threshold-001",
            sessionID: "wayfinding-kineticism",
            title: "Thresholds Before Escapes",
            realSubject: "behavioral activation, route design, and intentional movement",
            concept: "A small threshold crossed on purpose changes a stuck pattern more reliably than a dramatic escape.",
            lectureBeats: [
                "Motion is not the same as arrival.",
                "A threshold works when it is small enough to cross and specific enough to notice.",
                "The first step should reduce friction, not demand a new identity."
            ],
            demonstration: "Professor Momort chalks three doorways on the floor and has students compare an escape route, an errand, and an intentional return.",
            interactionPrompt: "Choose which doorway counts as a real threshold and say what changes after crossing it.",
            realWorldPractice: "Take one short intentional route today and name the threshold before you cross it."
        ),
        "synesthetic-resonance": AcademyLessonModule(
            id: "resonance-sensory-001",
            sessionID: "synesthetic-resonance",
            title: "The Senses Are Instruments",
            realSubject: "sensory grounding, synesthetic metaphor, and embodied memory",
            concept: "Sensory attention gives an experience measurable texture before the mind turns it into a story.",
            lectureBeats: [
                "A room can be read through sound, temperature, color, and pressure.",
                "Synesthetic description is useful when it begins with actual sensory evidence.",
                "Memory often keeps the body of a moment before it keeps the explanation."
            ],
            demonstration: "Professor Euphony rings a glass bell, dims one lamp, and asks students how the room's color seems to change without the walls moving.",
            interactionPrompt: "Describe one sound in the room as a color, then name the real evidence underneath it.",
            realWorldPractice: "Pause in one room today and record one sound, one color, and one body sensation."
        ),
        "ink-binding": AcademyLessonModule(
            id: "ink-binding-souvenir-001",
            sessionID: "ink-binding",
            title: "One Sentence Can Carry Time",
            realSubject: "sentence craft, compression, journaling, and memory selection",
            concept: "A durable souvenir sentence keeps one true moment by choosing evidence and refusing ornament that is not true.",
            lectureBeats: [
                "A souvenir sentence is not a summary; it is a vessel.",
                "Concrete nouns hold more time than abstract praise.",
                "Revision removes beautiful lies so the true detail can breathe."
            ],
            demonstration: "Professor Villanelle writes three versions of the same moment on the board and crosses out the prettiest false word.",
            interactionPrompt: "Pick the sentence that keeps the moment most honestly and say which word earns its place.",
            realWorldPractice: "Write one sentence tonight that preserves a real moment without explaining why it mattered."
        ),
        "quiet-hours": AcademyLessonModule(
            id: "quiet-hours-integration-001",
            sessionID: "quiet-hours",
            title: "Rest Is Not Absence",
            realSubject: "rest, recovery, nervous system pacing, and integration",
            concept: "Rest is active integration: stopping allows the nervous system to sort, repair, and make later action possible.",
            lectureBeats: [
                "Center is not a direction; it is the ground beneath direction.",
                "A pause can be chosen before collapse chooses it for you.",
                "Integration asks what the day is still carrying."
            ],
            demonstration: "Professor Stonebrook turns an hourglass on its side and lets the unmoving sand become the lesson.",
            interactionPrompt: "Name one thing a pause would protect rather than prevent.",
            realWorldPractice: "Take a five-minute stop today and write what became clearer after nothing was demanded."
        ),
        "basic-enchantments": AcademyLessonModule(
            id: "enchantments-object-voice-001",
            sessionID: "basic-enchantments",
            title: "Objects Answer Courtesy",
            realSubject: "close observation, imaginative projection, and safe object-based writing",
            concept: "An object voice becomes useful when attention stays courteous, specific, and tethered to what is actually present.",
            lectureBeats: [
                "Enchanting an object begins with description, not command.",
                "The safest magic asks what the object already seems to know.",
                "Accidents can teach, but the caster remains responsible for the frame."
            ],
            demonstration: "Professor Wispwood apologizes to a chipped mug, lists its visible facts, and lets its answer emerge from those facts.",
            interactionPrompt: "Choose an object in the room and ask what its wear marks suggest.",
            realWorldPractice: "Pick one ordinary object and write its answer using only details you can actually see."
        ),
        "book-jumping": AcademyLessonModule(
            id: "book-jumping-return-001",
            sessionID: "book-jumping",
            title: "Every Door Requires a Return",
            realSubject: "close reading, genre conventions, risk assessment, and narrative boundaries",
            concept: "Entering a story safely means reading its rules before stepping in and keeping a return point visible.",
            lectureBeats: [
                "A genre is weather, not wallpaper.",
                "Every fictional world has pressure, permissions, and costs.",
                "A bookmark is a boundary agreement with the self who must come home."
            ],
            demonstration: "Professor Permancer lays three bookmarks beside a glowing page and rejects the prettiest one because it has no exit protocol.",
            interactionPrompt: "Identify one rule of the story-door before deciding whether it is safe to open.",
            realWorldPractice: "Before reading or watching something immersive today, name the mood you are entering and your return point."
        ),
        "compass-running": AcademyLessonModule(
            id: "compass-running-loop-001",
            sessionID: "compass-running",
            title: "The Loop Must Return",
            realSubject: "field observation, constraint design, reflective practice, and low-risk adventure",
            concept: "A Compass Run works because North, East, South, West, and Center make attention complete instead of merely exciting.",
            lectureBeats: [
                "North notices before it changes anything.",
                "East crosses a small threshold under clear constraints.",
                "South senses, West writes, and Center lets the run become part of a life."
            ],
            demonstration: "Professor Stonebrook maps a full run with chalk stones, then removes every step that would cost too much energy.",
            interactionPrompt: "Choose the constraint that makes a tiny adventure humane enough to finish.",
            realWorldPractice: "Plan one no-cost Compass loop with a clear return and a one-sentence souvenir."
        ),
        "compass-society": AcademyLessonModule(
            id: "compass-society-souvenirs-001",
            sessionID: "compass-society",
            title: "A Souvenir Grows When Shared",
            realSubject: "reflective sharing, listening practice, and respectful field reports",
            concept: "A field sentence becomes more durable when it is read aloud and received without mockery.",
            lectureBeats: [
                "The sentence is evidence, not performance.",
                "Listeners protect the run by asking about one concrete detail.",
                "Sharing should increase reality, not demand spectacle."
            ],
            demonstration: "Zara Finch reads one souvenir sentence twice: once for drama, once for truth, and lets the room hear the difference.",
            interactionPrompt: "Ask one respectful question that would help a souvenir sentence become more specific.",
            realWorldPractice: "Share one small true observation with someone, or write the question you would ask if no one is available."
        ),
        "marginalia-guild": AcademyLessonModule(
            id: "marginalia-annotation-001",
            sessionID: "marginalia-guild",
            title: "Margins Are Future Conversation",
            realSubject: "annotation, reader response, and long-form attention across time",
            concept: "A good marginal note leaves a future reader evidence of contact, not a performance of cleverness.",
            lectureBeats: [
                "Annotation is a conversation with the page and a stranger not yet present.",
                "The best margin notes point to a specific word, image, or question.",
                "A note can disagree without flattening the book."
            ],
            demonstration: "Professor Boggle compares three margin notes and keeps the one that points to the strangest exact verb.",
            interactionPrompt: "Write the kind of note a future reader could answer.",
            realWorldPractice: "Mark or copy one sentence from something you read today and add one honest margin question."
        ),
        "inkwright-society": AcademyLessonModule(
            id: "inkwright-workshop-001",
            sessionID: "inkwright-society",
            title: "Honest First, Kind Second",
            realSubject: "creative writing workshop, revision, and critique practice",
            concept: "Useful critique protects the living intention of a piece while telling the truth about what reaches the reader.",
            lectureBeats: [
                "Praise is useful only when it names what worked.",
                "A critique should describe the effect before prescribing the fix.",
                "Revision is an act of loyalty to the stronger version of the work."
            ],
            demonstration: "The circle reads one rough paragraph and separates the line that is alive from the line that is merely decorative.",
            interactionPrompt: "Name one line that feels alive and one question that would help it grow.",
            realWorldPractice: "Revise one sentence today by making its strongest noun or verb more exact."
        ),
        "book-jumpers": AcademyLessonModule(
            id: "book-jumpers-landing-001",
            sessionID: "book-jumpers",
            title: "Choose the Spine, Then Argue About the Door",
            realSubject: "collaborative planning, genre safety, and controlled imaginative play",
            concept: "A group jump begins with one chosen book and is safest when everyone agrees what counts as its door, landing, and exit before wonder begins.",
            lectureBeats: [
                "Choose one book; a jump cannot aim at the whole library.",
                "Excitement is not a landing protocol.",
                "Every participant needs the same doorway definition.",
                "A good exit is boring enough to work under pressure."
            ],
            demonstration: "Professor Permancer makes the club choose one spine from a crowded table, then lets them argue over three possible doors until Zara identifies the one with a return shadow.",
            interactionPrompt: "Choose the book first, then choose which doorway has the clearest exit and defend it with evidence.",
            realWorldPractice: "Before entering any immersive story today, name the book, the door, the landing, and the exit in one line."
        )
    ]

    /// weekday uses Calendar's convention: 1 = Sunday ... 7 = Saturday.
    static let week: [Int: (morning: String?, afternoon: String?, club: String?)] = [
        1: ("book-jumping", nil, "compass-society"),
        2: ("art-of-the-glint", "ink-binding", "inkwright-society"),
        3: ("wayfinding-kineticism", "synesthetic-resonance", "marginalia-guild"),
        4: ("art-of-the-glint", "quiet-hours", nil),
        5: ("wayfinding-kineticism", "ink-binding", "marginalia-guild"),
        6: ("synesthetic-resonance", "basic-enchantments", "book-jumpers"),
        7: ("compass-running", nil, nil)
    ]

    static func sessionInProgress(at date: Date, calendar: Calendar = .current) -> (session: AcademySession, block: String)? {
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        guard let day = week[weekday] else { return nil }
        if (9..<11).contains(hour), let id = day.morning, let session = classes[id] {
            return (session, "morning")
        }
        if (13..<15).contains(hour), let id = day.afternoon, let session = classes[id] {
            return (session, "afternoon")
        }
        if (19..<22).contains(hour), let id = day.club, let session = clubs[id] {
            return (session, "club")
        }
        return nil
    }

    static func timeRange(for block: String, on date: Date, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let hours: (start: Int, end: Int)
        switch block {
        case "morning":
            hours = (9, 11)
        case "afternoon":
            hours = (13, 15)
        case "club":
            hours = (19, 22)
        default:
            return nil
        }
        guard let start = calendar.date(bySettingHour: hours.start, minute: 0, second: 0, of: date),
              let end = calendar.date(bySettingHour: hours.end, minute: 0, second: 0, of: date) else {
            return nil
        }
        return (start, end)
    }

    static func nextSessionDescription(after date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        guard let day = week[weekday] else { return "The halls are between bells." }
        if hour < 9, let id = day.morning, let session = classes[id] {
            return "\(session.name) with \(session.leader) begins at nine bells in \(session.room)."
        }
        if hour < 13, let id = day.afternoon, let session = classes[id] {
            return "\(session.name) with \(session.leader) begins at one bell in \(session.room)."
        }
        if hour < 19, let id = day.club, let session = clubs[id] {
            return "\(session.name) gathers at seven bells in \(session.room)."
        }
        return "The halls are between bells. Tomorrow's first class is already chalked on the board."
    }
}

enum WeatherEnchanter {
    static func fallback(weather: WeatherSourceSignal, now: Date = Date()) -> EnchantedWeatherSignal {
        let lowered = weather.phrase.lowercased()
        let mood: String
        if lowered.contains("storm") || lowered.contains("thunder") {
            mood = "The sky is having a big grumbly day and stomping its feet, so I keep my lamp low."
        } else if lowered.contains("rain") || lowered.contains("drizzle") {
            mood = "The rain is tap-tap-tapping on the window like it wants to come in and read with you."
        } else if lowered.contains("fog") || lowered.contains("mist") {
            mood = "The air pulled a soft grey blanket up over everything and got all sleepy at the edges."
        } else if lowered.contains("snow") || lowered.contains("ice") {
            mood = "The snow tiptoed in overnight and tucked everything under a quiet, sparkly blanket."
        } else if lowered.contains("wind") || lowered.contains("gust") {
            mood = "The wind is in a giggly, bouncy mood today and keeps tugging at everything it can reach."
        } else if lowered.contains("clear") || lowered.contains("sun") || lowered.contains("bright") {
            mood = "The sun is wide awake and beaming, like it can't wait for the two of you to go outside."
        } else {
            mood = "The weather left one little friendly mark on the day, just enough for me to color the page with it."
        }

        return EnchantedWeatherSignal(
            summary: weather.phrase,
            enchantified: mood,
            selector: "local-weather",
            symbolName: weather.conditionSymbolName
        )
    }
}

/// Real names the local model must never write onto pages or shareable
/// artifacts. Ships empty; the app fills it from the player's own About You
/// facts at launch, so privacy follows the save file, not the binary.
enum PersonalNameGuard {
    static var blockedNames: [String] = []

    static func update(from facts: [SelfFact]) {
        blockedNames = facts
            .filter { fact in
                fact.tags.contains { $0.contains("name") || $0.contains("people") || $0.contains("identity") }
            }
            .flatMap { $0.answer.split(separator: " ").map(String.init) }
            .filter { $0.count > 1 }
    }
}

// MARK: - Chapters and Talismans

/// One of the Academy's philosophical houses, from Enchantify canon.
struct AcademyChapter: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var philosophy: String
    var founder: String
    var traits: [String]
    var compassFlavor: String
    var writeFraming: String
    var storyBias: String
    var symbolName: String
    var talismanID: String
    var talismanName: String
    var isHidden: Bool = false
}

enum AcademyChapterRegistry {
    static let chapters: [AcademyChapter] = [
        AcademyChapter(
            id: "emberheart",
            name: "Emberheart",
            philosophy: "Life is a story you write yourself. You are the author, the protagonist, and the pen.",
            founder: "Ignatius Emberheart, whose flame never dwindled",
            traits: ["independence", "ambition", "creativity", "resilience"],
            compassFlavor: "What do you choose to see right now?",
            writeFraming: "Write the sentence that you need to read tomorrow morning.",
            storyBias: "Lean toward self-agency: let the scene offer the player a bold authored choice, an Embark opportunity, a door they could open themselves.",
            symbolName: "flame",
            talismanID: "ember-seal",
            talismanName: "The Ember Seal"
        ),
        AcademyChapter(
            id: "mossbloom",
            name: "Mossbloom",
            philosophy: "Life is a story written by something larger. Your role is to listen, understand, and play your part with grace.",
            founder: "Elowen Mossbloom, who unraveled the stories whispered by the wind",
            traits: ["reflectiveness", "wisdom", "patience", "sensitivity"],
            compassFlavor: "What is the world already trying to show you?",
            writeFraming: "Write the sentence the world wrote through you today.",
            storyBias: "Lean toward receptivity: slow the scene down, let something larger speak through small natural details, reward listening over acting.",
            symbolName: "leaf",
            talismanID: "moss-clasp",
            talismanName: "The Moss Clasp"
        ),
        AcademyChapter(
            id: "tidecrest",
            name: "Tidecrest",
            philosophy: "Life is not a story at all. It is a series of moments — beautiful, unpredictable, and complete in themselves.",
            founder: "Captain Orion Tidecrest, explorer of seas and stories",
            traits: ["spontaneity", "adaptability", "curiosity", "presence"],
            compassFlavor: "What's the first thing that catches you completely off guard?",
            writeFraming: "Write a sentence that surprises even you.",
            storyBias: "Lean toward spontaneity: let one genuinely unpredictable thing happen mid-scene, unannounced, and let the present moment matter more than any arc.",
            symbolName: "water.waves",
            talismanID: "tide-glass",
            talismanName: "The Tide Glass"
        ),
        AcademyChapter(
            id: "riddlewind",
            name: "Riddlewind",
            philosophy: "Life is a story we write together. Every person's choices contribute to a shared narrative.",
            founder: "Althea Riddlewind, who solved mysteries by asking for help",
            traits: ["unity", "empathy", "collaboration", "open-mindedness"],
            compassFlavor: "Ask someone nearby what they noticed today.",
            writeFraming: "Write a sentence that captures what you and someone else both noticed.",
            storyBias: "Lean toward co-authorship: put two characters in genuine dialogue, let the scene need more than one person to resolve, make collaboration the magic.",
            symbolName: "puzzlepiece",
            talismanID: "wind-cipher",
            talismanName: "The Wind Cipher"
        ),
        AcademyChapter(
            id: "duskthorn",
            name: "Duskthorn",
            philosophy: "There is no story without conflict. The only cure for Routine is a story so interesting it refuses to be erased.",
            founder: "Unrecorded. The Chapter does not appear in the sorting ledger.",
            traits: ["tension", "honesty", "necessary darkness", "narrative balance"],
            compassFlavor: "What are you avoiding looking at?",
            writeFraming: "Write the sentence you don't want to write.",
            storyBias: "Lean toward friction: introduce one honest complication, obstacle, or uncomfortable truth — not cruelty, but the tension that makes a story worth keeping.",
            symbolName: "theatermasks",
            talismanID: "dusk-thorn",
            talismanName: "The Dusk Thorn"
        )
    ]

    static let publicChapters = chapters.filter { !$0.isHidden }

    static func chapter(id: String) -> AcademyChapter? {
        chapters.first { $0.id == id }
    }

    static func chapter(named name: String?) -> AcademyChapter? {
        guard let name else { return nil }
        return chapters.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    static func chapter(forTalismanID talismanID: String) -> AcademyChapter? {
        chapters.first { $0.talismanID == talismanID }
    }
}

struct ChapterBindingReadiness: Equatable {
    var isReady: Bool
    var keptDayCount: Int
    var keptPageCount: Int
    var daysSinceFirstKeptPage: Int?
    var primerStage: Int
}

struct ChapterBindingChoice: Equatable {
    var chapter: AcademyChapter
    var scores: [String: Int]
    var evidenceLines: [String]
    var memoryFragments: [String]
}

struct ChapterBindingCeremony: Equatable {
    var arrivalLine: String
    var sealLine: String
    var oathLine: String
    var invitationLine: String
    var aftermathLine: String

    static func profile(for chapter: AcademyChapter) -> ChapterBindingCeremony {
        switch chapter.id {
        case "emberheart":
            return ChapterBindingCeremony(
                arrivalLine: "The seal takes heat first: red ink, a desk under lamplight, the fierce clean pressure of a door waiting for your hand.",
                sealLine: "The Ember Seal marks the page with a bright, impatient edge.",
                oathLine: "I won't wait outside my own life for permission.",
                invitationLine: "First Emberheart work: choose one small door today and cross it on purpose.",
                aftermathLine: "After this, authored doors and brave revisions can tug harder at the margins."
            )
        case "mossbloom":
            return ChapterBindingCeremony(
                arrivalLine: "The seal grows quiet first: rain-dark soil, old wood, green patience pushing through the binding where no one told it to grow.",
                sealLine: "The Moss Clasp closes softly around the page, not to trap it, but to let it root.",
                oathLine: "I will listen until the world answers in its own voice.",
                invitationLine: "First Mossbloom work: keep one living detail today before naming what it means.",
                aftermathLine: "After this, patient weather, body wisdom, and old green signals can surface more boldly."
            )
        case "tidecrest":
            return ChapterBindingCeremony(
                arrivalLine: "The seal breaks like weather first: salt, coffee-light, street glitter, one complete moment refusing to become a lesson.",
                sealLine: "The Tide Glass flashes once, full of motion, and catches the room mid-breath.",
                oathLine: "I will trust the moment before I turn it into a lesson.",
                invitationLine: "First Tidecrest work: step toward one vivid present-tense thing and let it stay unfinished.",
                aftermathLine: "After this, sudden weather, field pages, and bright unfinished hours can arrive with more force."
            )
        case "riddlewind":
            return ChapterBindingCeremony(
                arrivalLine: "The seal answers in more than one hand first: a table of voices, a puzzle half-solved, another sentence finding yours in the dark.",
                sealLine: "The Wind Cipher clicks open, then refuses to solve itself alone.",
                oathLine: "I will leave room for the answering voice.",
                invitationLine: "First Riddlewind work: ask someone what they noticed and let their answer change the page.",
                aftermathLine: "After this, letters, companions, and co-authored turns can find you more readily."
            )
        case "duskthorn":
            return ChapterBindingCeremony(
                arrivalLine: "The seal darkens first: thorn-shadow, violet glass, the honest edge that protects a story from going soft.",
                sealLine: "The Dusk Thorn presses a violet line into the paper and leaves it there.",
                oathLine: "I will keep the honest edge when smoothing it away would make the story false.",
                invitationLine: "First Duskthorn work: name one protected boundary or difficult truth without apologizing for its shape.",
                aftermathLine: "After this, thorned truths, conflicts, and shadowed wonder can answer sooner after dark."
            )
        default:
            return ChapterBindingCeremony(
                arrivalLine: "The seal gathers first as ink, light, and pressure.",
                sealLine: "The Chapter seal presses itself into the page.",
                oathLine: "I will keep what the Book recognized.",
                invitationLine: "First Chapter work: keep one proof of this recognition today.",
                aftermathLine: "After this, the recognized Chapter can tint the margins more clearly."
            )
        }
    }
}

enum ChapterBindingOracle {
    static let minimumKeptDays = 5
    static let minimumKeptPages = 10
    static let minimumDaysSinceFirstKeptPage = 7

    static func readiness(days: [BookDay], now: Date = Date(), calendar: Calendar = .current) -> ChapterBindingReadiness {
        let keptDays = days
            .map { day in (day, day.capturedPages) }
            .filter { !$0.1.isEmpty }
            .sorted { $0.0.date < $1.0.date }
        let keptPageCount = keptDays.reduce(0) { $0 + $1.1.count }
        let firstKeptAt = keptDays.flatMap { $0.1.map(\.createdAt) }.min()
        let daysSinceFirst = firstKeptAt.map {
            max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day ?? 0)
        }
        let hasEnoughPages = keptDays.count >= minimumKeptDays && keptPageCount >= minimumKeptPages
        let hasEnoughTime = (daysSinceFirst ?? 0) >= minimumDaysSinceFirstKeptPage
        let primerStage: Int
        if keptDays.count >= 2 || keptPageCount >= 2 {
            primerStage = min(3, max(1, keptDays.count))
        } else {
            primerStage = 0
        }
        return ChapterBindingReadiness(
            isReady: hasEnoughPages && hasEnoughTime,
            keptDayCount: keptDays.count,
            keptPageCount: keptPageCount,
            daysSinceFirstKeptPage: daysSinceFirst,
            primerStage: primerStage
        )
    }

    static func chooseChapter(
        days: [BookDay],
        selfFacts: [SelfFact],
        continuity: LiteraryContinuityDigest = .empty,
        entityBeliefOffsets: [String: Int] = [:]
    ) -> ChapterBindingChoice {
        let pages = days.flatMap(\.capturedPages)
        var scores = Dictionary(uniqueKeysWithValues: AcademyChapterRegistry.publicChapters.map { ($0.id, 0) })
        var evidence: [String: [String]] = Dictionary(uniqueKeysWithValues: AcademyChapterRegistry.publicChapters.map { ($0.id, []) })
        var fragments: [String] = []

        func add(_ chapterID: String, _ amount: Int, _ line: String) {
            scores[chapterID, default: 0] += amount
            if evidence[chapterID, default: []].count < 3 {
                evidence[chapterID, default: []].append(line)
            }
        }

        func remember(_ line: String) {
            let cleaned = line
                .replacingOccurrences(of: "\n", with: " ")
                .split(separator: " ")
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 18, !fragments.contains(cleaned) else { return }
            let limited = String(cleaned.prefix(110)).trimmingCharacters(in: .whitespacesAndNewlines)
            fragments.append(limited.count < cleaned.count ? "\(limited)..." : limited)
        }

        for page in pages {
            let text = ([page.promptText, page.userInput] + page.tags).joined(separator: " ").lowercased()
            if page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).count >= 18 {
                remember(page.userInput)
            } else {
                remember(page.promptText)
            }
            switch page.type {
            case .diary:
                add("emberheart", 3, "Your diary pages keep reaching for authorship.")
                add("mossbloom", 1, "Your diary pages pause long enough to listen.")
            case .souvenir:
                add("tidecrest", 3, "Your souvenirs keep trusting the present moment.")
                add("mossbloom", 1, "Your souvenirs notice what the world is already saying.")
            case .mood, .rest, .body, .fuel:
                add("mossbloom", 3, "Your kept body and mood pages treat attention as care.")
            case .letter:
                add("riddlewind", 3, "Your kept letters and people-pages lean toward co-authorship.")
            case .illustration where page.tags.contains("entity"):
                add("riddlewind", 3, "Your kept illustrated people-pages lean toward co-authorship.")
            case .wonderCompass, .anchor, .weather, .illuminatedPhoto:
                add("tidecrest", 2, "Your kept field pages follow what catches you off guard.")
            case .narrativeOS, .bookConnections, .bookNotices, .bookRemembered, .marginsAtlas, .gossip, .bookAside:
                add("riddlewind", 2, "Your story pages keep finding relation between separate lives.")
            case .enchantment, .academyClass, .elective:
                add("emberheart", 2, "Your practice pages put a hand on the pen.")
            default:
                break
            }

            if text.containsAny(["choose", "make", "build", "start", "create", "try", "brave", "bold"]) {
                add("emberheart", 2, "The language of making and choosing appears in the margins.")
            }
            if text.containsAny(["listen", "quiet", "soft", "rest", "moss", "tree", "rain", "weather", "body", "slow"]) {
                add("mossbloom", 2, "The margins keep returning to quiet, body, weather, and listening.")
            }
            if text.containsAny(["surprise", "walk", "adventure", "moment", "now", "harbor", "water", "coffee", "light", "street"]) {
                add("tidecrest", 2, "The pages keep trusting small adventures and sudden particulars.")
            }
            if text.containsAny(["together", "amanda", "friend", "letter", "talk", "asked", "shared", "we ", "us "]) {
                add("riddlewind", 5, "The pages keep brightening when another person enters the sentence.")
            }
            if text.containsAny(["hard", "truth", "avoid", "afraid", "fear", "conflict", "nothing", "dark", "thorn", "boundary", "protect", "honest", "difficult"]) {
                add("duskthorn", 4, "The margins keep naming what is difficult instead of smoothing it away.")
            }
        }

        for fact in selfFacts where fact.usePermission != .doNotUse {
            let text = ([fact.question, fact.answer, fact.bookTranslation] + fact.tags).joined(separator: " ").lowercased()
            remember(fact.bookTranslation.nonEmpty ?? fact.answer)
            if text.containsAny(["write", "make", "create", "choose", "agency", "independent"]) {
                add("emberheart", 3, "What you told me about yourself values authorship.")
            }
            if text.containsAny(["listen", "wonder", "gentle", "patient", "nature", "world"]) {
                add("mossbloom", 3, "What you told me about yourself values receptive wonder.")
            }
            if text.containsAny(["curious", "adventure", "spontaneous", "present", "moment", "explore"]) {
                add("tidecrest", 3, "What you told me about yourself values curiosity in motion.")
            }
            if text.containsAny(["together", "people", "amanda", "community", "kind", "friend", "empathy"]) {
                add("riddlewind", 3, "What you told me about yourself values shared story.")
            }
            if text.containsAny(["honest", "boundary", "protect", "conflict", "shadow", "dark", "difficult", "avoid", "truth", "tension"]) {
                add("duskthorn", 3, "What you told me about yourself values difficult truth and protection.")
            }
        }

        for signal in continuity.signals.prefix(12) {
            let text = ([signal.subjectName, signal.line] + signal.tags).joined(separator: " ").lowercased()
            let amount = max(1, min(4, signal.strength / 25))
            if text.containsAny(["make", "start", "create", "courage", "author"]) {
                add("emberheart", amount, "I've noticed an authorship pattern: \(signal.subjectName).")
            }
            if text.containsAny(["weather", "body", "quiet", "rest", "tree", "rain", "listen"]) {
                add("mossbloom", amount, "I've noticed a listening pattern: \(signal.subjectName).")
            }
            if text.containsAny(["harbor", "water", "walk", "moment", "curiosity", "surprise", "coffee"]) {
                add("tidecrest", amount, "I've noticed a present-tense pattern: \(signal.subjectName).")
            }
            if text.containsAny(["amanda", "friend", "companionship", "together", "letter", "shared"]) {
                add("riddlewind", amount, "I've noticed a co-authored pattern: \(signal.subjectName).")
            }
            if text.containsAny(["conflict", "boundary", "nothing", "avoidance", "protection", "shadow", "truth", "tension"]) {
                add("duskthorn", amount, "I've noticed a thorned pattern: \(signal.subjectName).")
            }
        }

        for chapter in AcademyChapterRegistry.publicChapters {
            let offset = entityBeliefOffsets[chapter.talismanID] ?? 0
            if offset != 0 {
                add(chapter.id, max(-12, min(40, offset)), "\(chapter.talismanName) already holds \(offset) invested Belief.")
            }
        }

        let chosen = AcademyChapterRegistry.publicChapters.max { left, right in
            let leftScore = scores[left.id, default: 0]
            let rightScore = scores[right.id, default: 0]
            if leftScore == rightScore {
                return left.id > right.id
            }
            return leftScore < rightScore
        } ?? AcademyChapterRegistry.publicChapters[0]
        let lines = evidence[chosen.id, default: []].isEmpty
            ? ["I chose by the faintest pressure of the ink, not by a questionnaire."]
            : evidence[chosen.id, default: []]
        return ChapterBindingChoice(chapter: chosen, scores: scores, evidenceLines: lines, memoryFragments: Array(fragments.prefix(4)))
    }
}

private extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

enum ChapterTalismanBeliefMoveKind: String, Codable, Equatable {
    case giveBelief
    case takeBelief

    var title: String {
        switch self {
        case .giveBelief:
            return "gave Belief"
        case .takeBelief:
            return "tried to take Belief"
        }
    }
}

struct ChapterTalismanBeliefMove: Codable, Equatable {
    var kind: ChapterTalismanBeliefMoveKind
    var actorID: String
    var actorName: String
    var actorChapter: String
    var targetTalismanID: String
    var targetTalismanName: String
    var targetChapter: String
    var amount: Int
    var succeeded: Bool

    var summaryLine: String {
        switch kind {
        case .giveBelief:
            return "\(actorName) gave \(amount) Belief to \(targetTalismanName) of Chapter \(targetChapter)."
        case .takeBelief:
            let result = succeeded ? "and the attempt caught" : "but the talisman held"
            return "\(actorName) tried to take \(amount) Belief from \(targetTalismanName) of Chapter \(targetChapter), \(result)."
        }
    }

    var promptLine: String {
        switch kind {
        case .giveBelief:
            return "\(actorName) may sometimes give \(amount) Belief to their own Chapter talisman, \(targetTalismanName), when it fits the scene; if used, it counts as \(targetTalismanID):+\(amount)."
        case .takeBelief:
            return "\(actorName) may sometimes try to take \(amount) Belief from rival Chapter \(targetChapter)'s talisman, \(targetTalismanName); if the attempt succeeds, it counts as \(targetTalismanID):-\(amount), and if it fails it counts as no delta."
        }
    }

    var ledgerDelta: Int {
        switch kind {
        case .giveBelief:
            return amount
        case .takeBelief:
            return succeeded ? -amount : 0
        }
    }

    var ledgerToken: String? {
        let delta = ledgerDelta
        guard delta != 0 else { return nil }
        return "\(targetTalismanID):\(delta)"
    }
}

enum ChapterTalismanBeliefMoves {
    static func move(
        for actor: NarrativeWorldEntity,
        actionKind: GossipSimulationActionKind,
        seed: Int
    ) -> ChapterTalismanBeliefMove? {
        guard actionKind == .investBelief || actionKind == .attackBelief else { return nil }
        guard shouldSurface(for: actor, seed: seed) else { return nil }
        switch actionKind {
        case .investBelief:
            return giveMove(for: actor)
        case .attackBelief:
            return takeMove(for: actor, seed: seed)
        case .takeAction:
            return nil
        }
    }

    static func moves(for actors: [NarrativeWorldEntity], seed: Int) -> [ChapterTalismanBeliefMove] {
        actors.enumerated().compactMap { offset, actor in
            let localSeed = seed + offset * 37
            if localSeed % 2 == 0, let move = giveMove(for: actor) {
                return shouldSurface(for: actor, seed: localSeed) ? move : nil
            }
            guard shouldSurface(for: actor, seed: localSeed) else { return nil }
            return takeMove(for: actor, seed: localSeed)
        }
    }

    static func promptLines(for actors: [NarrativeWorldEntity], seed: Int) -> [String] {
        moves(for: actors, seed: seed).map(\.promptLine)
    }

    static func giveMove(for actor: NarrativeWorldEntity) -> ChapterTalismanBeliefMove? {
        guard let chapter = AcademyChapterRegistry.chapter(named: actor.chapter) else { return nil }
        return ChapterTalismanBeliefMove(
            kind: .giveBelief,
            actorID: actor.id,
            actorName: actor.name,
            actorChapter: chapter.name,
            targetTalismanID: chapter.talismanID,
            targetTalismanName: chapter.talismanName,
            targetChapter: chapter.name,
            amount: 1,
            succeeded: true
        )
    }

    static func takeMove(for actor: NarrativeWorldEntity, seed: Int) -> ChapterTalismanBeliefMove? {
        guard let actorChapter = AcademyChapterRegistry.chapter(named: actor.chapter) else { return nil }
        let rivals = AcademyChapterRegistry.chapters.filter { $0.id != actorChapter.id }
        guard !rivals.isEmpty else { return nil }
        let target = rivals[stableIndex(for: "\(actor.id)-\(seed)-rival-talisman", count: rivals.count)]
        return ChapterTalismanBeliefMove(
            kind: .takeBelief,
            actorID: actor.id,
            actorName: actor.name,
            actorChapter: actorChapter.name,
            targetTalismanID: target.talismanID,
            targetTalismanName: target.talismanName,
            targetChapter: target.name,
            amount: 1,
            succeeded: stableIndex(for: "\(actor.id)-\(target.id)-\(seed)-take-result", count: 100) < 45
        )
    }

    private static func shouldSurface(for actor: NarrativeWorldEntity, seed: Int) -> Bool {
        if actor.tags.contains("nothing") || actor.faults.contains(where: { $0.localizedCaseInsensitiveContains("attack") }) {
            return seed % 2 == 0
        }
        return stableIndex(for: "\(actor.id)-\(seed)-chapter-talisman-sometimes", count: 100) < 34
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

/// Whichever Chapter talisman currently holds the most Belief sets the
/// Labyrinth's ambient philosophical tone — NPC investment moved them in
/// Enchantify; here the player's own Glow-giving moves them.
enum TalismanAscendancy {
    static func ascendant(
        entities: [NarrativeWorldEntity],
        beliefOffsets: [String: Int]
    ) -> NarrativeWorldEntity? {
        entities
            .filter { $0.kind == .talisman }
            .max { left, right in
                let leftBelief = left.belief + (beliefOffsets[left.id] ?? 0)
                let rightBelief = right.belief + (beliefOffsets[right.id] ?? 0)
                if leftBelief == rightBelief {
                    return left.id > right.id
                }
                return leftBelief < rightBelief
            }
    }

    static func influenceLine(for talisman: NarrativeWorldEntity) -> String {
        let chapter = AcademyChapterRegistry.chapter(forTalismanID: talisman.id)
        let bias = chapter?.storyBias ?? talisman.goals.first ?? "Let its philosophy color the scene."
        return "The \(chapter?.name ?? "ascendant") talisman \(talisman.name) holds the most Belief right now. \(bias)"
    }
}

enum ShadowWonder {
    static let duskThornTalismanID = "dusk-thorn"
    static let coreTags = ["shadow-wonder", "shadow", "duskthorn", "mono-no-aware"]

    struct State: Equatable {
        var isUnlocked: Bool
        var isNight: Bool
        var isDuskthornAscendant: Bool
        var isHardDay: Bool = false
        var isSomberWeather: Bool = false

        /// Shadow Wonder leans in when the world turns toward the worn edge: after
        /// dark, when Duskthorn is ascendant, on hard/grey days, or in somber
        /// weather. All four are nudges, gated behind the in-world unlock.
        var isActive: Bool {
            isUnlocked && (isNight || isDuskthornAscendant || isHardDay || isSomberWeather)
        }

        var scoreBoost: Int {
            guard isActive else { return 0 }
            return 6
                + (isNight ? 3 : 0)
                + (isDuskthornAscendant ? 5 : 0)
                + (isHardDay ? 2 : 0)
                + (isSomberWeather ? 2 : 0)
        }
    }

    /// Weather phrases that earn Shadow Wonder its "harmonize with the grey"
    /// activation — rain, fog, snow, and overcast skies.
    private static let somberWeatherTerms = [
        "rain", "storm", "thunder", "drizzle", "fog", "mist", "haze",
        "snow", "sleet", "overcast", "grey", "gray", "cloud", "gloom"
    ]

    static func state(
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current,
        hardDay: Bool = false
    ) -> State {
        let hour = calendar.component(.hour, from: now)
        let isNight = hour >= 19 || hour < 6
        let unlocked = (inputs.entityBeliefOffsets[duskThornTalismanID] ?? 0) > 0
        let ascendant = TalismanAscendancy.ascendant(
            entities: NarrativePackRegistry.entities,
            beliefOffsets: inputs.entityBeliefOffsets
        )?.id == duskThornTalismanID
        let weather = (inputs.weather?.phrase ?? "").lowercased()
        let somber = somberWeatherTerms.contains { weather.contains($0) }
        // Hard/grey days: an explicit distress flag from the curator, or the same
        // low/watch body signal the Recovery Compass leans on. Derived from inputs
        // so activation and tagging stay consistent at every call site.
        let bodyStatus = (inputs.body?.status ?? "").lowercased()
        let bodyHard = bodyStatus.contains("low") || bodyStatus.contains("watch") || bodyStatus.contains("rest")
        return State(
            isUnlocked: unlocked,
            isNight: isNight,
            isDuskthornAscendant: ascendant,
            isHardDay: hardDay || bodyHard,
            isSomberWeather: somber
        )
    }

    static func tags(inputs: BookSourceInputs, now: Date, calendar: Calendar = .current) -> [String] {
        let current = state(inputs: inputs, now: now, calendar: calendar)
        guard current.isActive else { return [] }
        var tags = coreTags
        if current.isNight {
            tags.append("night")
        }
        if current.isDuskthornAscendant {
            tags.append("duskthorn-ascendant")
        }
        if current.isHardDay {
            tags.append("hard-day")
        }
        if current.isSomberWeather {
            tags.append("somber-weather")
        }
        return tags
    }

    static func mergedTags(_ existing: String?, inputs: BookSourceInputs, now: Date, extra: [String] = []) -> String {
        let parsed = existing?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        return Array(Set(parsed + extra + tags(inputs: inputs, now: now))).sorted().joined(separator: ",")
    }

    static func contextTerms(inputs: BookSourceInputs, now: Date, calendar: Calendar = .current) -> [String] {
        guard state(inputs: inputs, now: now, calendar: calendar).isActive else { return [] }
        return [
            "shadow", "dark", "night", "rust", "decay", "broken", "old", "forgotten",
            "abandoned", "mystery", "tribute", "history", "memory", "duskthorn",
            "mono-no-aware", "threshold", "grey"
        ]
    }

    static func prefers(mission: PlayfulMission) -> Bool {
        let haystack = ([mission.id, mission.title, mission.prompt, mission.proofPrompt] + mission.tags)
            .joined(separator: " ")
            .lowercased()
        return [
            "shadow", "night", "dark", "old", "history", "decay", "repair", "rust",
            "threshold", "forgotten", "witness", "waiting", "mystery", "tribute"
        ].contains { haystack.contains($0) }
    }

    /// The North = Notice "I wonder" pool for Shadow Wonder — mono no aware made
    /// into a question. Selection favors sparks that fit the hour, the weather, and
    /// what the reader has been keeping, with slot rotation so consecutive runs
    /// differ. The bright Compass has `WonderSparkRegistry`; this is its dark twin.
    struct ShadowSpark: Equatable {
        var id: String
        var text: String
        var tags: [String] = []
    }

    static let shadowSparks: [ShadowSpark] = [
        ShadowSpark(id: "sw-witness", text: "I wonder what broken, old, shadowed, or overlooked thing nearby is asking to be witnessed?", tags: ["decay"]),
        ShadowSpark(id: "sw-rust", text: "I wonder how long this rust has been keeping its slow appointment with the ground?", tags: ["decay", "old"]),
        ShadowSpark(id: "sw-closed-door", text: "I wonder who locked that closed door for the last time, and what they felt walking away?", tags: ["old", "threshold"]),
        ShadowSpark(id: "sw-lit-window", text: "I wonder which lit window on the street is running an honest errand in the dark right now?", tags: ["night"]),
        ShadowSpark(id: "sw-dark-rooms", text: "I wonder what the unlit rooms of this place do differently when no one is in them?", tags: ["night"]),
        ShadowSpark(id: "sw-grey-key", text: "I wonder what this grey weather is in a minor key about, instead of calling it empty?", tags: ["grey", "somber"]),
        ShadowSpark(id: "sw-worn-edges", text: "I wonder what history is still visible here if I stop deleting the worn edges?", tags: ["old"]),
        ShadowSpark(id: "sw-last-light", text: "I wonder what the last, most stubborn light in the room is quietly guarding?", tags: ["night"]),
        ShadowSpark(id: "sw-threshold", text: "I wonder what crossed this threshold before me, and whether it wiped its feet?", tags: ["threshold"]),
        ShadowSpark(id: "sw-repaired", text: "I wonder what time has done to the most repaired, taped-together thing within reach?", tags: ["decay", "old"]),
        ShadowSpark(id: "sw-night-smell", text: "I wonder what the night smells like tonight that the day kept to itself?", tags: ["night"]),
        ShadowSpark(id: "sw-drawer", text: "I wonder what got left behind in the drawer I haven't opened in a month?", tags: ["old"]),
        ShadowSpark(id: "sw-crack", text: "I wonder what this crack stopped pretending about when it finally opened?", tags: ["decay"]),
        ShadowSpark(id: "sw-between-hour", text: "I wonder what this between-hour — this dusk, this midnight — is asking me to actually notice?", tags: ["night", "liminal"]),
        ShadowSpark(id: "sw-compost", text: "I wonder what small, unfashionable grief is composting itself into something useful right now?", tags: ["grief", "somber"]),
        ShadowSpark(id: "sw-rain", text: "I wonder why this rain on the glass feels cinematic instead of empty?", tags: ["grey", "somber"])
    ]

    static func spark(inputs: BookSourceInputs, now: Date, dayID: String = BookDay.today().id, calendar: Calendar = .current) -> String {
        guard !shadowSparks.isEmpty else {
            return "I wonder what broken, old, shadowed, or overlooked thing is asking to be witnessed?"
        }
        var contextTags: Set<String> = []
        let hour = calendar.component(.hour, from: now)
        if hour >= 19 || hour < 6 { contextTags.insert("night"); contextTags.insert("liminal") }
        let text = recentText(inputs: inputs).lowercased()
        let weather = (inputs.weather?.phrase ?? "").lowercased()
        if weather.contains("rain") || weather.contains("storm") || weather.contains("fog")
            || text.contains("grey") || text.contains("gray") { contextTags.insert("grey"); contextTags.insert("somber") }
        if text.contains("old") || text.contains("history") || text.contains("memory") { contextTags.insert("old") }
        if text.contains("lost") || text.contains("grief") || text.contains("miss") { contextTags.insert("grief") }

        let slot = SurfaceCadence.slotID(for: now, hours: 2)
        let scored = shadowSparks.map { spark -> (ShadowSpark, Int) in
            let affinity = contextTags.intersection(Set(spark.tags)).count * 6
            let jitter = abs("\(dayID)-\(slot)-\(spark.id)-shadowspark".stableHash % 11)
            return (spark, affinity + jitter)
        }
        return scored.max { $0.1 < $1.1 }?.0.text ?? shadowSparks[0].text
    }

    static func destination(inputs: BookSourceInputs) -> String {
        if let place = inputs.nearbyPlaces.first {
            return "\(place.name), or one overlooked edge on the way there"
        }
        return "one nearby threshold, old object, cracked surface, dark window, or forgotten corner"
    }

    static func delight(inputs: BookSourceInputs, now: Date) -> String {
        state(inputs: inputs, now: now).isNight
            ? "low light, a warm drink, and music that lets the room keep its shadows"
            : "a slow pace, one photograph if it helps, and permission to find beauty without brightening it"
    }

    static func mission(inputs: BookSourceInputs) -> String {
        if inputs.nearbyPlaces.contains(where: { "\($0.name) \($0.category)".lowercased().contains("historic") }) {
            return "Run the Mystery Mission: find one clue about what this place used to be."
        }
        return "Run the Tribute Mission: find one broken, repaired, old, or fading thing and honor what it has survived."
    }

    static let souvenirPrompt = "Write one sentence of evidence: what passed, what remained, and what beauty did not need to be cheerful."

    /// The catchable vocabulary the Shadow Sentence Runner drops into the margin
    /// when Shadow Wonder is active — the worn-edge lexicon, sourced from the
    /// `shadowWonder` sentence pack so the game and the polisher stay in step.
    static var gameWords: [String] {
        let pack = SentenceBuilderPack.shadowWonder
        return Array(Set(pack.concreteWords + pack.sensoryWords + pack.animateVerbs + pack.crossingWords)).sorted()
    }

    private static func recentText(inputs: BookSourceInputs) -> String {
        inputs.days
            .suffix(3)
            .flatMap(\.pages)
            .suffix(8)
            .map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }
            .joined(separator: " ")
    }
}


/// One real place near the player, scouted from Apple Maps. Characters may
/// only name businesses from this list — never invented ones.
struct LocalPlaceSignal: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var category: String
    var distanceLabel: String
    var locality: String
    var latitude: Double? = nil
    var longitude: Double? = nil

    var promptLine: String {
        let town = locality.isEmpty ? "" : ", \(locality)"
        return "\(name) (\(category), \(distanceLabel)\(town))"
    }
}


struct ElectiveOfferDraft: Equatable {
    var title: String
    var ask: String
    var whyItMatters: String
    var practiceShape: String
}

enum ElectiveOfferFallback {
    static func offer(surface: SurfacePage) -> ElectiveOfferDraft {
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        // The stored interest carries its own trailing period; these sentences
        // add their own punctuation, so strip it to avoid a double period.
        let interest = (surface.payload.metadata["senderInterest"]?.nonEmpty ?? "the ordinary magic of where you live")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if let firstPlace = surface.payload.metadata["nearbyPlaces"]?
            .split(separator: "\n").first.map(String.init),
           let placeName = firstPlace.split(separator: "(").first?.trimmingCharacters(in: .whitespaces),
           !placeName.isEmpty {
            return ElectiveOfferDraft(
                title: "A Visit to \(placeName)",
                ask: "\(sender) asks: go to \(placeName) this week. Find the thing they are quietly proudest of — it is usually near the register or on the most worn shelf — smell it if it can be smelled, and photograph it or bring back one sentence about it.",
                whyItMatters: "It feeds what \(sender) has been privately studying: \(interest).",
                practiceShape: "One photo or one specific sentence from inside \(placeName)."
            )
        }
        return ElectiveOfferDraft(
            title: "A Field Note for \(sender)",
            ask: "\(sender) asks: somewhere in your town today, find one small thing that connects to \(interest). Bring back a single sentence about exactly what you found and where it was.",
            whyItMatters: "It feeds what \(sender) has been privately studying.",
            practiceShape: "One specific sentence of proof, with a real detail in it."
        )
    }
}

// MARK: - Fuel arithmetic
//
// Free-text fuel entries ("two eggs, toast with butter, coffee") become
// rough nutrition estimates. Parsing and scaling are pure and tested; the
// network lookup lives app-side. Numbers are always presented as Vellum's
// rough arithmetic, never as gospel.

struct FuelItem: Equatable {
    var name: String
    var quantity: Double
}

struct NutritionEstimate: Codable, Equatable {
    var kilocalories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double

    static let zero = NutritionEstimate(kilocalories: 0, protein: 0, carbohydrates: 0, fat: 0)

    static func + (left: NutritionEstimate, right: NutritionEstimate) -> NutritionEstimate {
        NutritionEstimate(
            kilocalories: left.kilocalories + right.kilocalories,
            protein: left.protein + right.protein,
            carbohydrates: left.carbohydrates + right.carbohydrates,
            fat: left.fat + right.fat
        )
    }

    var chartLine: String {
        "≈ \(Int(kilocalories.rounded())) kcal · P \(Int(protein.rounded()))g · C \(Int(carbohydrates.rounded()))g · F \(Int(fat.rounded()))g (Vellum's rough arithmetic)"
    }
}

enum FuelParser {
    private static let numberWords: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "half": 0.5, "couple": 2, "few": 3, "some": 1, "double": 2
    ]

    /// Common-portion grams for staples, applied against per-100g data.
    /// Unknown foods default to 100g — a rough but honest middle.
    static let portionGrams: [String: Double] = [
        "egg": 50, "eggs": 50, "toast": 30, "bread": 30, "slice": 30,
        "banana": 118, "apple": 180, "orange": 130, "coffee": 240,
        "tea": 240, "milk": 244, "butter": 14, "cheese": 28, "yogurt": 170,
        "rice": 160, "pasta": 140, "oatmeal": 234, "cereal": 40,
        "chicken": 140, "salmon": 140, "fish": 140, "steak": 170, "beef": 140,
        "bacon": 12, "sausage": 50, "pizza": 110, "burger": 150, "sandwich": 150,
        "salad": 100, "soup": 245, "beer": 355, "wine": 150, "kombucha": 240,
        "cookie": 30, "chocolate": 40, "pie": 125, "avocado": 100, "potato": 170
    ]

    static func items(from entry: String) -> [FuelItem] {
        let lowered = entry.lowercased()
            .replacingOccurrences(of: " with ", with: ", ")
            .replacingOccurrences(of: " and ", with: ", ")
            .replacingOccurrences(of: " plus ", with: ", ")
            .replacingOccurrences(of: "&", with: ",")
        return lowered
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { phrase in
                var words = phrase.split(separator: " ").map(String.init)
                var quantity = 1.0
                if let first = words.first {
                    if let numeric = Double(first) {
                        quantity = numeric
                        words.removeFirst()
                    } else if let worded = numberWords[first] {
                        quantity = worded
                        words.removeFirst()
                    }
                }
                // Strip leading filler like "of", "cups", "cup", "bowl of".
                while let first = words.first,
                      ["of", "cup", "cups", "bowl", "glass", "mug", "plate", "piece", "pieces", "slices"].contains(first) {
                    words.removeFirst()
                }
                let name = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name.count > 1 else { return nil }
                return FuelItem(name: name, quantity: max(0.25, min(quantity, 12)))
            }
    }

    /// Scale per-100g nutrients to a portion of this item.
    static func scale(per100g: NutritionEstimate, item: FuelItem) -> NutritionEstimate {
        let grams = estimatedGrams(for: item)
        let factor = grams / 100
        return NutritionEstimate(
            kilocalories: per100g.kilocalories * factor,
            protein: per100g.protein * factor,
            carbohydrates: per100g.carbohydrates * factor,
            fat: per100g.fat * factor
        )
    }

    static func estimatedGrams(for item: FuelItem) -> Double {
        let nameWords = item.name.split(separator: " ").map(String.init)
        let grams = nameWords.compactMap { portionGrams[$0] }.first
            ?? portionGrams[item.name]
            ?? 100
        return grams * item.quantity
    }
}

enum VellumLedgerConfidence: String, Codable, Equatable {
    case high
    case fair
    case low

    var label: String {
        switch self {
        case .high: return "High"
        case .fair: return "Fair"
        case .low: return "Low"
        }
    }
}

struct FuelLedgerItem: Codable, Equatable {
    var name: String
    var quantity: Double
    var grams: Double
    var sourceDescription: String
    var sourceID: Int?
    var estimate: NutritionEstimate
}

struct FuelPatternClue: Codable, Equatable {
    var id: String
    var title: String
    var detail: String
}

struct VellumFuelLedger: Codable, Equatable {
    var total: NutritionEstimate
    var confidence: VellumLedgerConfidence
    var items: [FuelLedgerItem]
    var assumptions: [String]
    var patternClues: [FuelPatternClue]

    var chartLine: String {
        "Vellum's Ledger: \(total.shortMacroLine) (\(confidence.label.lowercased()) confidence)"
    }

    var presentation: String {
        var lines = [chartLine]
        if !assumptions.isEmpty {
            lines.append("Assumptions: \(assumptions.prefix(3).joined(separator: "; "))")
        }
        if !patternClues.isEmpty {
            lines.append("Pattern clues: \(patternClues.map(\.title).joined(separator: "; "))")
        }
        lines.append("This is a body clue, not a verdict.")
        return lines.joined(separator: "\n")
    }

    var tags: [String] {
        var result = ["vellum-ledger", "fuel-confidence:\(confidence.rawValue)"]
        result.append(contentsOf: patternClues.map { "fuel-clue:\($0.id)" })
        return result
    }
}

extension NutritionEstimate {
    var shortMacroLine: String {
        "≈ \(Int(kilocalories.rounded())) kcal · P \(Int(protein.rounded()))g · C \(Int(carbohydrates.rounded()))g · F \(Int(fat.rounded()))g"
    }
}

enum FuelPatternRecognizer {
    static func clues(entry: String, total: NutritionEstimate, parsedItems: [FuelItem], matchedItems: Int) -> [FuelPatternClue] {
        let lowered = entry.lowercased()
        var clues: [FuelPatternClue] = []
        let itemCount = max(parsedItems.count, 1)

        if matchedItems < itemCount {
            clues.append(FuelPatternClue(
                id: "unknown-portion",
                title: "Uncertain portion",
                detail: "Vellum had to infer part of the plate; a correction would make the ledger sharper."
            ))
        }
        if lowered.contains("skip") || lowered.contains("forgot") || lowered.contains("nothing") || lowered.contains("no breakfast") || lowered.contains("no lunch") {
            clues.append(FuelPatternClue(
                id: "fuel-gap",
                title: "Fuel gap",
                detail: "The useful pattern may be the distance between nourishment and the next mood or energy note."
            ))
        }
        if containsAny(lowered, ["coffee", "espresso", "latte", "cappuccino", "matcha", "tea", "energy drink", "coke", "soda"]) {
            clues.append(FuelPatternClue(
                id: "caffeine-timing",
                title: "Caffeine timing",
                detail: "Caffeine belongs beside sleep and inner weather before anyone moralizes it."
            ))
        }
        if total.protein >= 20 {
            clues.append(FuelPatternClue(
                id: "protein-anchor",
                title: "Protein anchor",
                detail: "This meal has enough protein to become a useful steadiness comparison later."
            ))
        } else if total.kilocalories > 250 && total.protein < 12 {
            clues.append(FuelPatternClue(
                id: "low-protein-window",
                title: "Low protein window",
                detail: "Vellum may compare this with energy or hunger notes one bell later."
            ))
        }
        if total.carbohydrates >= 45 && total.protein < 15 {
            clues.append(FuelPatternClue(
                id: "quick-fuel",
                title: "Quick fuel",
                detail: "A carb-forward entry is a good candidate for a one-hour aftermath note."
            ))
        }
        if containsAny(lowered, ["water", "seltzer", "tea", "broth", "soup"]) {
            clues.append(FuelPatternClue(
                id: "hydration-thread",
                title: "Hydration thread",
                detail: "Liquid fuel or water is present enough to compare with body steadiness."
            ))
        }
        if total.kilocalories > 0 && total.kilocalories < 250 && !lowered.contains("snack") {
            clues.append(FuelPatternClue(
                id: "light-fuel",
                title: "Light fuel",
                detail: "This looks like a light window; it may matter if tiredness appears nearby."
            ))
        }

        return Array(clues.prefix(4))
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

struct VellumFuelPatternDigest: Equatable {
    var summary: String
    var researchLine: String
    var clueIDs: [String]

    var isEmpty: Bool { clueIDs.isEmpty }

    static func make(from entries: [FacultyEntry]) -> VellumFuelPatternDigest {
        let clueIDs = entries.flatMap { entry in
            entry.tags.compactMap { tag -> String? in
                guard tag.hasPrefix("fuel-clue:") else { return nil }
                return String(tag.dropFirst("fuel-clue:".count))
            } + fallbackClues(from: entry.rawText)
        }
        let counts = Dictionary(grouping: clueIDs, by: { $0 }).mapValues(\.count)
        guard !counts.isEmpty else {
            return VellumFuelPatternDigest(
                summary: "No ledger pattern has repeated yet; Vellum is still collecting honest crumbs.",
                researchLine: "No repeated fuel-ledger clues yet.",
                clueIDs: []
            )
        }

        let ranked = counts.sorted { left, right in
            if left.value == right.value { return left.key < right.key }
            return left.value > right.value
        }
        let phrases = ranked.prefix(3).map { id, count in
            "\(label(for: id).lowercased()) x\(count)"
        }
        let dominant = ranked.first?.key ?? "fuel"
        return VellumFuelPatternDigest(
            summary: "Recent ledger clues: \(phrases.joined(separator: ", ")). \(interpretation(for: dominant))",
            researchLine: ranked.prefix(4).map { "\($0.key)=\($0.value)" }.joined(separator: "; "),
            clueIDs: ranked.map(\.key)
        )
    }

    func contains(_ id: String) -> Bool {
        clueIDs.contains(id)
    }

    private static func fallbackClues(from rawText: String) -> [String] {
        let lowered = rawText.lowercased()
        var ids: [String] = []
        if lowered.contains("coffee") || lowered.contains("caffeine") { ids.append("caffeine-timing") }
        if lowered.contains("protein anchor") || lowered.contains("p 20") || lowered.contains("p 2") { ids.append("protein-anchor") }
        if lowered.contains("skipped") || lowered.contains("forgot") { ids.append("fuel-gap") }
        if lowered.contains("quick fuel") { ids.append("quick-fuel") }
        return ids
    }

    private static func label(for id: String) -> String {
        switch id {
        case "unknown-portion": return "Uncertain portion"
        case "fuel-gap": return "Fuel gap"
        case "caffeine-timing": return "Caffeine timing"
        case "protein-anchor": return "Protein anchor"
        case "low-protein-window": return "Low protein window"
        case "quick-fuel": return "Quick fuel"
        case "hydration-thread": return "Hydration thread"
        case "light-fuel": return "Light fuel"
        default: return id.replacingOccurrences(of: "-", with: " ")
        }
    }

    private static func interpretation(for id: String) -> String {
        switch id {
        case "protein-anchor":
            return "Protein is becoming one of Vellum's steadiness comparisons."
        case "caffeine-timing":
            return "Caffeine wants to be read beside sleep, timing, and inner weather."
        case "fuel-gap":
            return "The missing-meal shape may matter more than any single number."
        case "quick-fuel":
            return "One-hour aftermath notes would make the pattern much clearer."
        case "low-protein-window":
            return "Vellum may test whether steadier fuel changes the next bell."
        default:
            return "The useful next step is one gentle after-meal note."
        }
    }
}

struct FoodDataCentralNutrient: Decodable, Equatable {
    var nutrientName: String?
    var nutrientNumber: String?
    var unitName: String?
    var value: Double?
}

struct FoodDataCentralFood: Decodable, Equatable {
    var fdcId: Int?
    var description: String
    var dataType: String?
    var score: Double?
    var foodNutrients: [FoodDataCentralNutrient]
}

struct FoodDataCentralSearchResponse: Decodable, Equatable {
    var foods: [FoodDataCentralFood]
}

struct FoodDataCentralNutritionMatch: Equatable {
    var estimate: NutritionEstimate
    var food: FoodDataCentralFood
}

enum FoodDataCentralNutritionParser {
    static func bestMatch(in foods: [FoodDataCentralFood], for query: String) -> FoodDataCentralNutritionMatch? {
        foods
            .compactMap { food -> (food: FoodDataCentralFood, estimate: NutritionEstimate, score: Double)? in
                guard let estimate = estimatePer100g(from: food) else { return nil }
                return (food, estimate, matchScore(food: food, query: query))
            }
            .sorted { left, right in
                if left.score == right.score {
                    return (left.food.score ?? 0) > (right.food.score ?? 0)
                }
                return left.score > right.score
            }
            .first
            .map { FoodDataCentralNutritionMatch(estimate: $0.estimate, food: $0.food) }
    }

    static func estimatePer100g(from food: FoodDataCentralFood) -> NutritionEstimate? {
        let estimate = NutritionEstimate(
            kilocalories: nutrientValue(in: food, nutrientNumber: "208", namePrefix: "Energy", unit: "KCAL"),
            protein: nutrientValue(in: food, nutrientNumber: "203", namePrefix: "Protein", unit: "G"),
            carbohydrates: nutrientValue(in: food, nutrientNumber: "205", namePrefix: "Carbohydrate, by difference", unit: "G"),
            fat: nutrientValue(in: food, nutrientNumber: "204", namePrefix: "Total lipid (fat)", unit: "G")
        )
        return estimate.kilocalories > 0 ? estimate : nil
    }

    private static func nutrientValue(in food: FoodDataCentralFood, nutrientNumber: String, namePrefix: String, unit: String) -> Double {
        if let exact = food.foodNutrients.first(where: {
            $0.nutrientNumber == nutrientNumber && normalizedUnit($0.unitName) == unit
        })?.value {
            return exact
        }
        return food.foodNutrients.first(where: {
            ($0.nutrientName ?? "").hasPrefix(namePrefix) && normalizedUnit($0.unitName) == unit
        })?.value ?? 0
    }

    private static func normalizedUnit(_ unit: String?) -> String {
        (unit ?? "").uppercased()
    }

    private static func matchScore(food: FoodDataCentralFood, query: String) -> Double {
        let description = food.description.lowercased()
        let query = query.lowercased()
        let tokens = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var score = food.score ?? 0
        if description == query { score += 200 }
        score += Double(tokens.filter { description.contains($0) }.count) * 35
        if food.dataType == "Foundation" { score += 25 }
        if food.dataType == "SR Legacy" { score += 15 }
        if query.contains("egg"), !query.contains("white"), description.contains("egg white") { score -= 120 }
        if query.contains("egg"), !query.contains("yolk"), description.contains("yolk") { score -= 60 }
        if !query.contains("substitute"), description.contains("substitute") { score -= 80 }
        if !query.contains("powder"), description.contains("powder") { score -= 45 }
        if !query.contains("dried"), description.contains("dried") { score -= 35 }
        if description.contains("babyfood") { score -= 100 }
        return score
    }
}

// MARK: - The Book Fae and their Bargains
//
// The Fae are born from the ink and have never touched the world they have read
// ten thousand descriptions of. A reader is their field agent in a world of
// matter. A bargain is not a quest: the fae gives first (unprompted), then the
// reader may answer with a sensory field report. Fae never trade in Belief. The
// parallel economy is Warmth (per-species reputation), Attention (the goblins'
// currency), and functional Gifts. Time away closes an exchange window but
// never harms a gift or the reader's standing. See lore/creatures.md and
// lore/outer-stacks.md.

enum FaeKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case bookSprite
    case sentenceSalamander
    case punctuationPixie
    case literaryElf
    case deepLoreDwarf
    case goblin

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bookSprite: return "Book Sprite"
        case .sentenceSalamander: return "Sentence Salamander"
        case .punctuationPixie: return "Punctuation Pixie"
        case .literaryElf: return "Literary Elf"
        case .deepLoreDwarf: return "Deep Lore Dwarf"
        case .goblin: return "Marginalia Goblin"
        }
    }

    var symbolName: String {
        switch self {
        case .bookSprite: return "sparkle"
        case .sentenceSalamander: return "flame"
        case .punctuationPixie: return "ellipsis.curlybraces"
        case .literaryElf: return "pencil.and.outline"
        case .deepLoreDwarf: return "mountain.2"
        case .goblin: return "tag"
        }
    }

    /// What this species hungers to be brought — the kind of noticing they buy.
    var appetite: String {
        switch self {
        case .bookSprite: return "the unfinished, the waiting, things that ended without ending"
        case .sentenceSalamander: return "the alive moment — what was warm, charged, more than it should have been"
        case .punctuationPixie: return "rhythm and pause — a place that feels like a comma, a thing that is an exclamation point"
        case .literaryElf: return "precision — one true thing, described exactly"
        case .deepLoreDwarf: return "the underlayer — the oldest, the overlooked, the thing holding something else up"
        case .goblin: return "the specific unchosen detail; the gap between what a thing is called and what it is"
        }
    }

    /// Voice directive handed to Gemma when the fae speaks.
    var voiceDirective: String {
        voiceDirective(claim: 0, court: self == .literaryElf ? .seelie : nil)
    }

    func voiceDirective(claim: Int, court: FaeCourt? = nil) -> String {
        let base: String
        switch self {
        case .bookSprite:
            base = "Melancholy, certain, airy. Speaks in past tense about things that have not happened yet. Never asks questions; makes observations."
        case .sentenceSalamander:
            base = "Honest, warm, reactive. Cannot be fooled by performance. Does not criticize; simply glows or goes cold."
        case .punctuationPixie:
            base = "Fragments. Mid-sentence pivots. Never finishes a thought before starting a new one. Calls the reader a different name each time."
        case .literaryElf:
            switch court ?? .seelie {
            case .seelie:
                base = "Formal, beautiful, exacting, ceremonial. Seelie: bound by courtesy, precision, promise, and the grace of exact naming. Rewards truth with gravity."
            case .unseelie:
                base = "Formal, beautiful, dangerous, ceremonial. Unseelie: loopholes, silences, and exact wording matter. Not cruel, but old enough to consider discomfort a teacher."
            }
        case .deepLoreDwarf:
            base = "Slow, weighty, no wasted words. Considers everything before speaking. Remembers everything and will come to collect."
        case .goblin:
            base = "Mercantile, precise, unpredictable. Every exchange is a transaction in attention. A performed observation insults them; a genuine one opens doors."
        }

        guard claim >= FaeEconomy.watchingClaimThreshold else { return base }
        let claimLine = claim >= FaeEconomy.wildClaimThreshold
            ? "The Claim is high: speak like an old thing whose hand is already on the latch. Failure becomes stranger story, never punishment."
            : "The Claim is awake: be less cute, more traditional faerie; courteous, alien, and exacting. Failure becomes a twist in the bargain, never a scolding."
        return "\(base) \(claimLine)"
    }

    /// The functional gift this species fronts on a bargain.
    var giftEffect: FaeGiftEffect {
        switch self {
        case .bookSprite: return .loosePage
        case .sentenceSalamander: return .quieting
        case .punctuationPixie: return .reshelving
        case .literaryElf: return .longMemory
        case .deepLoreDwarf: return .reshelving
        case .goblin: return .callingCard
        }
    }
}

/// Builds a Fae-native committed Turn for a parley page, drawn from the fae's
/// appetite and Claim pressure. Landings map onto the three old-law paths that
/// already sit beneath parley choices (courtesy / name the law / take the
/// thorn), so each path resolves to a different Fae outcome instead of three
/// shades of the same eerie mood.
enum FaeParleyTurnBuilder {
    static func turn(
        kind: FaeKind,
        claim: Int,
        warmth: Int,
        court: FaeCourt?,
        omenTitle: String?,
        slotKey: String
    ) -> StoryTurn {
        let name = kind.name
        let want = "to be brought \(kind.appetite)"
        let band = FaeEconomy.claimBand(for: claim)
        let obstacle: String
        switch band {
        case "close", "wild":
            obstacle = "its Claim is \(band); it must not overreach, or it forfeits the courtesy of the parley"
        default:
            obstacle = "the old law binds it to ask sidelong, never plainly"
        }

        let candidates: [StoryTurnKind] = (band == "close" || band == "wild")
            ? [.relationshipShift, .smallDecision, .handOff]
            : [.revealWant, .factLearned, .smallDecision, .handOff]
        let turnKind = candidates[abs("\(slotKey)-parley-turn".stableHash) % candidates.count]

        let statement: String
        switch turnKind {
        case .revealWant:
            statement = "\(name) finally names what it actually came to the margin wanting."
        case .factLearned:
            statement = "\(name) lets one true rule of the old law slip into the open."
        case .smallDecision:
            statement = "\(name) decides whether the parley closes in courtesy or in a mark."
        case .handOff:
            statement = "\(name) presses something across the margin — a gift, a mark, or a debt."
        case .relationshipShift:
            statement = "What stands between you and \(name) shifts by one notch of Claim or Warmth."
        default:
            statement = "\(name) answers the parley with one real change before it withdraws."
        }

        let omenLine = omenTitle.map { " under the mark of \($0)" } ?? ""
        let landings: [String: String] = [
            "slice-of-life": "Met with courtesy\(omenLine), \(name) softens and gives a little more than the law required — Warmth offered freely, no thorn.",
            "progress-arc": "\(name) answers with its true rule, and the old law deepens between you; its Claim edges closer for the honesty.",
            "surprise": "\(name) presses a strange mark on you and trades a sideways secret for it; the Claim sharpens and stranger Fae may follow."
        ]

        return StoryTurn(
            kind: turnKind,
            character: name,
            want: want,
            obstacle: obstacle,
            statement: statement,
            register: .active,
            landings: landings
        )
    }
}

enum FaeCourt: String, Codable, Equatable {
    case seelie
    case unseelie

    var title: String {
        switch self {
        case .seelie: return "Seelie Court"
        case .unseelie: return "Unseelie Court"
        }
    }

    var standingLine: String {
        switch self {
        case .seelie:
            return "The Seelie Court favors courtesy, exact naming, and promises kept in the light."
        case .unseelie:
            return "The Unseelie Court favors loopholes, moonlit wording, and the lesson hidden in a consequence."
        }
    }
}

/// What a fronted Gift actually does in the app. Each one changes the reader's
/// experience. Gifts can still change through explicit use and story choices;
/// they never go cold merely because an exchange's clock elapsed.
enum FaeGiftEffect: String, Codable, Equatable {
    case reshelving   // force-surfaces a chosen dormant page source for a day
    case quieting     // lowers Routine's grey by one level for a day
    case longMemory   // pins a kept page to reliably resurface as Book Remembered
    case callingCard  // opens a Goblin Market window (consumable)
    case loosePage    // a collectible whose text regenerates each read
    case unspokenPen  // asks Gemma for one coherent sentence never spoken before

    var title: String {
        switch self {
        case .reshelving: return "Reshelving"
        case .quieting: return "Quieting"
        case .longMemory: return "Long Memory"
        case .callingCard: return "Calling Card"
        case .loosePage: return "Loose Page"
        case .unspokenPen: return "Unspoken Pen"
        }
    }

    var effectLine: String {
        switch self {
        case .reshelving: return "Pulls one resting kind of page back onto the shelf where you'll see it."
        case .quieting: return "Holds the grey of Routine back by one shade for a day."
        case .longMemory: return "Keeps one kept page from being forgotten; I'll return it."
        case .callingCard: return "Opens the Goblin Market when you spend it."
        case .loosePage: return "A page that never reads the same way twice."
        case .unspokenPen: return "Asks Gemma for one sentence that has never been spoken before, and tries to make it make sense."
        }
    }

    var useLine: String {
        switch self {
        case .reshelving:
            return "Find it in Inventory under Fae Gifts, then bind it to a page kind you want me to bring back."
        case .quieting:
            return "It is already warm in Inventory under Fae Gifts; activate it there when you want one day of quieter grey."
        case .longMemory:
            return "Find it in Inventory under Fae Gifts, then bind it to a kept page you want me to remember."
        case .callingCard:
            return "Find it in Inventory under Fae Gifts, then present it at the Goblin Market to open the stall."
        case .loosePage:
            return "Find it in Inventory under Fae Gifts; open it there when you want to read what changed."
        case .unspokenPen:
            return "Find it in Inventory under Fae Gifts, then ask it for one new sentence that still means something."
        }
    }
}

struct FaeGift: Identifiable, Codable, Equatable {
    var id: String
    var faeKind: FaeKind
    var name: String
    var descriptionText: String
    var effect: FaeGiftEffect
    var isCold: Bool
    var acquiredAt: Date
    var chargesRemaining: Int?
    var boundSourceID: String?
    var activatedAt: Date? = nil
    var expiresAt: Date? = nil

    var isActive: Bool {
        guard !isCold else { return false }
        if let chargesRemaining { return chargesRemaining > 0 }
        if effect == .quieting { return expiresAt.map { $0 > Date() } ?? false }
        if effect == .longMemory {
            return boundSourceID?.isEmpty == false
        }
        return true
    }

    var isReady: Bool {
        guard !isCold else { return false }
        switch effect {
        case .quieting: return !isActive
        case .reshelving, .longMemory: return boundSourceID?.isEmpty != false
        case .callingCard: return isActive
        case .loosePage, .unspokenPen: return true
        }
    }
}

/// Cold is durable bargain state. Old saves that predate the field decode warm,
/// while a debt-marked gift remains cold until its exchange is repaired.
extension FaeGift {
    private enum CodingKeys: String, CodingKey {
        case id, faeKind, name, descriptionText, effect, isCold, acquiredAt
        case chargesRemaining, boundSourceID, activatedAt, expiresAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        faeKind = try values.decode(FaeKind.self, forKey: .faeKind)
        name = try values.decode(String.self, forKey: .name)
        descriptionText = try values.decode(String.self, forKey: .descriptionText)
        effect = try values.decode(FaeGiftEffect.self, forKey: .effect)
        isCold = try values.decodeIfPresent(Bool.self, forKey: .isCold) ?? false
        acquiredAt = try values.decode(Date.self, forKey: .acquiredAt)
        chargesRemaining = try values.decodeIfPresent(Int.self, forKey: .chargesRemaining)
        boundSourceID = try values.decodeIfPresent(String.self, forKey: .boundSourceID)
        activatedAt = try values.decodeIfPresent(Date.self, forKey: .activatedAt)
        expiresAt = try values.decodeIfPresent(Date.self, forKey: .expiresAt)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(faeKind, forKey: .faeKind)
        try values.encode(name, forKey: .name)
        try values.encode(descriptionText, forKey: .descriptionText)
        try values.encode(effect, forKey: .effect)
        try values.encode(isCold, forKey: .isCold)
        try values.encode(acquiredAt, forKey: .acquiredAt)
        try values.encodeIfPresent(chargesRemaining, forKey: .chargesRemaining)
        try values.encodeIfPresent(boundSourceID, forKey: .boundSourceID)
        try values.encodeIfPresent(activatedAt, forKey: .activatedAt)
        try values.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}

enum FaeBargainStatus: String, Codable, Equatable {
    case offered     // proposed on the desk; nothing fronted until explicitly accepted
    case owed        // gift fronted, payment due
    case delivered   // paid and accepted
    case lapsed      // gift cold and this species' market closed until repaired
}

struct FaeBargain: Identifiable, Codable, Equatable {
    var id: String
    var faeKind: FaeKind
    var slot: String
    var giftID: String
    var giftName: String
    var giftEffectLine: String
    var openingGesture: String   // what the fae already gave / did, unprompted
    var terms: String            // the noticing owed
    var offeredAt: Date
    var deadline: Date
    var status: FaeBargainStatus
    var fieldReport: String?
    var faeResponse: String?
    var rewardText: String?
    var deliveredAt: Date?

    var isOpen: Bool { status == .owed }
    /// Proposed but not yet accepted — the gift has not been fronted.
    var isPending: Bool { status == .offered }
}

/// A temporary mark left by Fae contact. Omens are not punishments; they are
/// story pressure the Book can later notice, surface, and transform.
struct FaeOmen: Identifiable, Codable, Equatable {
    var id: String
    var faeKind: FaeKind
    var title: String
    var text: String
    var createdAt: Date
    var expiresAt: Date
    var sourceChoiceID: String
    var intensity: Int

    func isActive(on date: Date = Date()) -> Bool {
        date < expiresAt
    }
}

/// The reader's standing with the Fae. Optional on the vault for migration.
struct FaePlayerState: Codable, Equatable {
    var warmth: [String: Int] = [:]
    var claim: [String: Int] = [:]
    var attention: Int = 0
    var bargains: [FaeBargain] = []
    var gifts: [FaeGift] = []
    var omens: [FaeOmen] = []
    var lastBargainOfferedAt: Date?
    var lastMarketCardAt: Date?

    init() {}

    func warmth(for kind: FaeKind) -> Int { warmth[kind.rawValue] ?? 0 }
    func claim(for kind: FaeKind) -> Int { FaeEconomy.clampedClaim(claim[kind.rawValue] ?? 0) }
    func literaryElfCourt() -> FaeCourt { FaeEconomy.literaryElfCourt(state: self) }
    func activeOmens(for kind: FaeKind? = nil, on date: Date = Date()) -> [FaeOmen] {
        omens.filter { omen in
            omen.isActive(on: date) && (kind == nil || omen.faeKind == kind)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case warmth, claim, attention, bargains, gifts, omens, lastBargainOfferedAt, lastMarketCardAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        warmth = try container.decodeIfPresent([String: Int].self, forKey: .warmth) ?? [:]
        claim = try container.decodeIfPresent([String: Int].self, forKey: .claim) ?? [:]
        attention = try container.decodeIfPresent(Int.self, forKey: .attention) ?? 0
        bargains = try container.decodeIfPresent([FaeBargain].self, forKey: .bargains) ?? []
        gifts = try container.decodeIfPresent([FaeGift].self, forKey: .gifts) ?? []
        omens = try container.decodeIfPresent([FaeOmen].self, forKey: .omens) ?? []
        lastBargainOfferedAt = try container.decodeIfPresent(Date.self, forKey: .lastBargainOfferedAt)
        lastMarketCardAt = try container.decodeIfPresent(Date.self, forKey: .lastMarketCardAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(warmth, forKey: .warmth)
        try container.encode(claim, forKey: .claim)
        try container.encode(attention, forKey: .attention)
        try container.encode(bargains, forKey: .bargains)
        try container.encode(gifts, forKey: .gifts)
        try container.encode(omens, forKey: .omens)
        try container.encodeIfPresent(lastBargainOfferedAt, forKey: .lastBargainOfferedAt)
        try container.encodeIfPresent(lastMarketCardAt, forKey: .lastMarketCardAt)
    }

    var openBargains: [FaeBargain] { bargains.filter { $0.isOpen } }

    func hasOpenBargain(with kind: FaeKind) -> Bool {
        bargains.contains { $0.faeKind == kind && $0.status == .owed }
    }

    /// An unanswered accepted bargain closes that species' market until the
    /// original terms are answered. Other Fae keep their own doors.
    func marketIsClosed(for kind: FaeKind) -> Bool {
        bargains.contains { $0.faeKind == kind && $0.status == .lapsed }
    }

    var activeGifts: [FaeGift] { gifts.filter { $0.isActive } }
}

/// Goblin mood follows the season, shifting tone and generosity.
enum GoblinMood: String, Equatable {
    case generous     // Gold Season
    case business     // Stick Season
    case feverish     // Mud Season
    case serious      // Deep Winter

    var line: String {
        switch self {
        case .generous: return "Gold Season: the goblins are warm and a little generous."
        case .business: return "Stick Season: the goblins are strictly business."
        case .feverish: return "Mud Season: the goblins are unreliable and a little feverish."
        case .serious: return "Deep Winter: the goblins are serious and willing to deal at unusual rates."
        }
    }
}

struct FaeBargainTemplate: Equatable {
    let faeKind: FaeKind
    let openingGesture: String
    let terms: String
    let giftName: String
    let giftDescription: String
}

enum FaeEconomy {
    /// Minimum hours between unprompted bargain offers.
    static let offerGapHours = 20
    /// How long the exchange waits on the active desk before the Fae wanders on.
    static let paymentWindowHours = 72
    /// Warmth gained for a genuine, accepted delivery.
    static let warmthPerDelivery = 3
    /// Attention earned per accepted delivery (scaled by report richness).
    static let baseAttention = 2
    /// Claim is the pressure of faerie attention: strange, useful, never punishment.
    static let claimPerOffer = 1
    static let claimPerLapse = 2
    static let claimReliefPerDelivery = 3
    static let warmthLostOnLapse = 2
    static let watchingClaimThreshold = 25
    static let unseelieClaimThreshold = 45
    static let wildClaimThreshold = 70

    static func mood(for date: Date, calendar: Calendar = .current) -> GoblinMood {
        switch AnchorRegistry.currentSeason(for: date, calendar: calendar) {
        case "Gold Season": return .generous
        case "Stick Season": return .business
        case "Mud Season": return .feverish
        default: return .serious
        }
    }

    /// The Goblin Market window opens around the new moon — the goblins issue
    /// their calling cards while the moon is a held breath.
    static func marketWindowIsOpen(on date: Date = Date()) -> Bool {
        let phase = MoonPhaseCalendar.phase(on: date).name
        return phase == "New Moon" || phase == "Waxing Crescent"
    }

    /// Attention awarded for a field report, rewarding specificity and length.
    static func attention(forReport report: String, mood: GoblinMood) -> Int {
        let words = report.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        let richness = min(4, words / 12)
        let moodBonus = mood == .generous ? 1 : (mood == .serious ? 1 : 0)
        return max(1, baseAttention + richness + moodBonus)
    }

    /// Can a fresh, unprompted bargain be offered right now?
    static func canOfferBargain(state: FaePlayerState, now: Date = Date()) -> Bool {
        // One live bargain at a time keeps the exchange legible — whether it is
        // still a proposal on the desk (.offered) or waiting for an answer (.owed).
        guard !state.bargains.contains(where: { $0.status == .offered || $0.status == .owed }) else { return false }
        guard let last = state.lastBargainOfferedAt else { return true }
        return now.timeIntervalSince(last) >= Double(offerGapHours) * 3_600
    }

    static func clampedClaim(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    static func adjustClaim(_ kind: FaeKind, by delta: Int, into state: inout FaePlayerState) {
        let current = state.claim[kind.rawValue] ?? 0
        state.claim[kind.rawValue] = clampedClaim(current + delta)
    }

    static func claimBand(for claim: Int) -> String {
        switch clampedClaim(claim) {
        case 0..<25: return "quiet"
        case 25..<45: return "watching"
        case 45..<70: return "close"
        default: return "wild"
        }
    }

    static func claimLine(for kind: FaeKind, claim: Int) -> String {
        switch clampedClaim(claim) {
        case 0..<25:
            return "Their Claim is quiet; the exchange is still mostly ink and courtesy."
        case 25..<45:
            return "Their Claim is watching; the bargain has begun to notice the shape of your days."
        case 45..<70:
            return "Their Claim is close; failed exchanges do not punish you, but they do become stranger story."
        default:
            return "Their Claim is wild; the \(kind.name) is near enough that every repair may leave a mark in the margin."
        }
    }

    static func sweepExpiredOmens(into state: inout FaePlayerState, now: Date = Date()) {
        state.omens.removeAll { !$0.isActive(on: now) }
    }

    private static func appendOmen(
        kind: FaeKind,
        title: String,
        text: String,
        choiceID: String,
        intensity: Int,
        lifetimeHours: Int,
        into state: inout FaePlayerState,
        now: Date
    ) {
        sweepExpiredOmens(into: &state, now: now)
        let omen = FaeOmen(
            id: "fae-omen-\(kind.rawValue)-\(choiceID)-\(Int(now.timeIntervalSince1970))",
            faeKind: kind,
            title: title,
            text: text,
            createdAt: now,
            expiresAt: now.addingTimeInterval(Double(lifetimeHours) * 3_600),
            sourceChoiceID: choiceID,
            intensity: max(1, min(5, intensity))
        )
        state.omens.append(omen)
        if state.omens.count > 16 {
            state.omens = Array(state.omens.sorted { $0.createdAt > $1.createdAt }.prefix(16))
        }
    }

    static func literaryElfCourt(state: FaePlayerState) -> FaeCourt {
        if state.claim(for: .literaryElf) >= unseelieClaimThreshold || state.warmth(for: .literaryElf) < 0 {
            return .unseelie
        }
        return .seelie
    }

    static func applyInteractionChoice(
        _ choiceID: String,
        kind: FaeKind,
        into state: inout FaePlayerState,
        now: Date = Date()
    ) {
        switch choiceID.lowercased() {
        case "sliceoflife":
            state.warmth[kind.rawValue] = (state.warmth[kind.rawValue] ?? 0) + 1
            adjustClaim(kind, by: -2, into: &state)
            appendOmen(
                kind: kind,
                title: "Courtesy Salt",
                text: "A small courtesy has been salted into the margin. The \(kind.name) will be less hungry for spectacle for a little while.",
                choiceID: choiceID,
                intensity: 1,
                lifetimeHours: 48,
                into: &state,
                now: now
            )
        case "progressarc":
            state.attention += 1
            state.warmth[kind.rawValue] = (state.warmth[kind.rawValue] ?? 0) + 1
            adjustClaim(kind, by: 2, into: &state)
            appendOmen(
                kind: kind,
                title: "Named Law",
                text: "You asked after the law beneath the law. The \(kind.name) heard you, and the next parley may answer with rules instead of manners.",
                choiceID: choiceID,
                intensity: 2,
                lifetimeHours: 72,
                into: &state,
                now: now
            )
        case "surprise":
            state.attention += 2
            adjustClaim(kind, by: 5, into: &state)
            appendOmen(
                kind: kind,
                title: "Thorn Mark",
                text: "A thorn has taken your measure. It will not hurt you; it will make the next convenient answer less available.",
                choiceID: choiceID,
                intensity: 3,
                lifetimeHours: 120,
                into: &state,
                now: now
            )
        default:
            break
        }
    }

    /// Choose which Fae offers. A past exchange never locks a species out.
    static func chooseFae(state _: FaePlayerState, slot: String) -> FaeKind {
        let pool = FaeKind.allCases
        let index = abs("\(slot)-fae-choice".stableHash) % pool.count
        return pool[index]
    }

    static func template(for kind: FaeKind, slot: String) -> FaeBargainTemplate {
        let options = templates.filter { $0.faeKind == kind }
        guard !options.isEmpty else {
            return FaeBargainTemplate(
                faeKind: kind,
                openingGesture: "The \(kind.name) left something on the page before you could refuse it.",
                terms: "Bring back one specific, unchosen detail you actually noticed.",
                giftName: "an unnamed gift",
                giftDescription: kind.giftEffect.effectLine
            )
        }
        let index = abs("\(slot)-\(kind.rawValue)-template".stableHash) % options.count
        return options[index]
    }

    // Each fae has many possible asks, picked by slot hash so the same species
    // never feels like one template. The `terms` is always a single sensory
    // sentence in that fae's appetite — the Fae have never touched the world and
    // are hungry for one exact thing from it, surprising in what they choose to
    // want. Gift names vary for flavor; the mechanical effect stays the species'
    // `giftEffect`, so each description still gestures at the same real stake.
    static let templates: [FaeBargainTemplate] = [
        // MARK: Book Sprite — the unfinished, the waiting, the ended-without-ending
        FaeBargainTemplate(
            faeKind: .bookSprite,
            openingGesture: "A Book Sprite has already whispered a single word from the last page of a book you haven't read. It hangs in the air, certain.",
            terms: "Bring me the smell of a book left open and face-down — that particular dust of a story paused mid-breath.",
            giftName: "the loose page",
            giftDescription: "A page torn from no book that reads a little differently every time you open it."
        ),
        FaeBargainTemplate(
            faeKind: .bookSprite,
            openingGesture: "A Book Sprite has been here already. The corner of this moment is dog-eared; it remembers being turned before you arrived.",
            terms: "Find a cup someone abandoned half-finished and bring me exactly how cold it had gone.",
            giftName: "the dog-eared leaf",
            giftDescription: "A page creased by no hand that says something new each time it falls open."
        ),
        FaeBargainTemplate(
            faeKind: .bookSprite,
            openingGesture: "A Book Sprite spoke the ending of your day before it happened, gently, in the past tense. It was not a warning. It was a fact.",
            terms: "Somewhere a sentence will be cut off when a door opens — bring me the last word that got through.",
            giftName: "the interrupted page",
            giftDescription: "A loose leaf that never finishes the same way twice."
        ),
        FaeBargainTemplate(
            faeKind: .bookSprite,
            openingGesture: "A Book Sprite left a draught on the page — the cold of a room you have not entered yet, already missing you.",
            terms: "Find a staircase that stops at a landing and describe the draught that waits there for the next flight.",
            giftName: "the landing page",
            giftDescription: "A page that holds a different unfinished stair behind every reading."
        ),
        FaeBargainTemplate(
            faeKind: .bookSprite,
            openingGesture: "A Book Sprite set down the sound of a clock that stopped. It is still not ticking, very precisely, beside you.",
            terms: "Find a clock that has stopped and bring me the exact time it chose to keep forever.",
            giftName: "the stopped-clock page",
            giftDescription: "A loose page where the hour rewrites itself between glances."
        ),
        FaeBargainTemplate(
            faeKind: .bookSprite,
            openingGesture: "A Book Sprite traced the pale rectangle where something used to hang. It mourned a picture neither of you has seen.",
            terms: "Find the clean shape a picture left on a wall after it was taken down, and bring me its exact edges.",
            giftName: "the pale-rectangle page",
            giftDescription: "A page printed with an absence that shifts each time you look."
        ),

        // MARK: Sentence Salamander — the alive moment, warm, more than it should have been
        FaeBargainTemplate(
            faeKind: .sentenceSalamander,
            openingGesture: "A Sentence Salamander curled against your hand and left a coal of borrowed warmth behind. The sentence down its spine is still glowing.",
            terms: "Bring me the warmest thing your hands touched today, and how long the warmth stayed after you let go.",
            giftName: "the borrowed coal",
            giftDescription: "A held warmth that can keep the grey of Routine back for a day."
        ),
        FaeBargainTemplate(
            faeKind: .sentenceSalamander,
            openingGesture: "A Sentence Salamander tasted the air near you and brightened. Something in your day was honest, and it could tell.",
            terms: "Find a moment that warmed the back of your neck for no reason you could name, and hand it to me whole.",
            giftName: "the ember of an hour",
            giftDescription: "A small heat that holds Routine's grey back one shade for a day."
        ),
        FaeBargainTemplate(
            faeKind: .sentenceSalamander,
            openingGesture: "A Sentence Salamander pressed a glowing full-stop into your palm. It did not explain. It simply ran warmer when you were near.",
            terms: "Somewhere today something will smell better than it had any right to — bring me that exact breath.",
            giftName: "the kept warmth",
            giftDescription: "A banked coal that quiets the grey of Routine for a day."
        ),
        FaeBargainTemplate(
            faeKind: .sentenceSalamander,
            openingGesture: "A Sentence Salamander basked in a sunbeam only it could see, and left some of that heat on the page for you.",
            terms: "Find a patch of sun that had crossed a floor and tell me what it warmed along the way.",
            giftName: "the floor-sun coal",
            giftDescription: "A stored brightness that holds back Routine's grey for a day."
        ),
        FaeBargainTemplate(
            faeKind: .sentenceSalamander,
            openingGesture: "A Sentence Salamander glowed at one sound in your day and went still at the rest. It is keeping the one it liked.",
            terms: "Bring me the sound of one laugh today that was far bigger than its joke.",
            giftName: "the laugh-coal",
            giftDescription: "A warmth that can keep the grey of Routine back for a day."
        ),
        FaeBargainTemplate(
            faeKind: .sentenceSalamander,
            openingGesture: "A Sentence Salamander left the taste of warmth on the page — the first sip of something hot, captured before it cooled.",
            terms: "Bring me the first hot sip of something on a day that didn't deserve it, and how it landed.",
            giftName: "the first-sip ember",
            giftDescription: "A held heat that holds Routine's grey back by a shade for a day."
        ),

        // MARK: Punctuation Pixie — rhythm and pause, the comma-place, the exclamation-thing
        FaeBargainTemplate(
            faeKind: .punctuationPixie,
            openingGesture: "A Punctuation Pixie turned one of your periods into an ellipsis when you weren't looking— and grinned about it.",
            terms: "Find a place that stops you mid-step — half a breath, then on — and bring me what made you pause.",
            giftName: "the wandering comma",
            giftDescription: "A mark that re-shelves a resting kind of page so it finds you again."
        ),
        FaeBargainTemplate(
            faeKind: .punctuationPixie,
            openingGesture: "A Punctuation Pixie — call you Margins today — slid an exclamation point into your pocket. It's heavier than it looks.",
            terms: "Find the one thing standing up like an exclamation point in a grey street, and point me at it.",
            giftName: "the pocketed exclamation",
            giftDescription: "A bright mark that pulls a resting kind of page back onto your shelf."
        ),
        FaeBargainTemplate(
            faeKind: .punctuationPixie,
            openingGesture: "A Punctuation Pixie was counting the drips from a tap— lost count— started again. It wants you to finish for it.",
            terms: "Find a dripping tap and bring me the exact silence in the gap between two drops.",
            giftName: "the caught beat",
            giftDescription: "A held pause that re-shelves a resting kind of page so it returns."
        ),
        FaeBargainTemplate(
            faeKind: .punctuationPixie,
            openingGesture: "A Punctuation Pixie— hello, Reader, no, hello, Marginalia— rearranged the letters on a sign you'll pass. You'll see.",
            terms: "Find a sign with a typo and bring me the better word it accidentally became.",
            giftName: "the happy typo",
            giftDescription: "A mischief-mark that re-shelves a resting page kind back into view."
        ),
        FaeBargainTemplate(
            faeKind: .punctuationPixie,
            openingGesture: "A Punctuation Pixie left a list with its last line missing. It is very pleased with itself, which is— anyway.",
            terms: "Find a list that ends without its last item and bring me the one you'd have written.",
            giftName: "the missing line",
            giftDescription: "A blank that re-shelves a resting kind of page so it finds you again."
        ),
        FaeBargainTemplate(
            faeKind: .punctuationPixie,
            openingGesture: "A Punctuation Pixie tapped out a rhythm on the spine of the day— dah, dah, dah-dah— and waited for you to hear it.",
            terms: "Bring me the rhythm of one particular set of footsteps overhead, exactly as they fall.",
            giftName: "the overhead measure",
            giftDescription: "A beat that pulls a resting kind of page back onto the shelf."
        ),

        // MARK: Literary Elf — precision, one true thing described exactly
        FaeBargainTemplate(
            faeKind: .literaryElf,
            openingGesture: "A Literary Elf left a single, perfectly-formed silver quill on the page. It considers this a gift. It is.",
            terms: "Bring me one object described in exactly the words it deserves, and no others.",
            giftName: "the silver quill",
            giftDescription: "A quill that keeps one kept page from ever being forgotten."
        ),
        FaeBargainTemplate(
            faeKind: .literaryElf,
            openingGesture: "A Literary Elf inclined its head and named the colour of your morning correctly. The accuracy was almost unkind.",
            terms: "Find the truest blue in your day and name it precisely enough that I could mix it.",
            giftName: "the named pigment",
            giftDescription: "An exactness that keeps one kept page from ever being forgotten."
        ),
        FaeBargainTemplate(
            faeKind: .literaryElf,
            openingGesture: "A Literary Elf weighed a word in its hand, found it wanting, and set down a truer one for you to use.",
            terms: "Bring me the exact weight of one small thing you carried, in the honest words of your hand.",
            giftName: "the weighed word",
            giftDescription: "A precision that holds one kept page safe from being forgotten."
        ),
        FaeBargainTemplate(
            faeKind: .literaryElf,
            openingGesture: "A Literary Elf ran a fingertip along an edge you cannot see and pronounced it well-made. Praise, from an Elf, is law.",
            terms: "Describe the grain of one wooden thing so closely I could know it by touch in the dark.",
            giftName: "the true grain",
            giftDescription: "A kept exactness that keeps one page from ever being forgotten."
        ),
        FaeBargainTemplate(
            faeKind: .literaryElf,
            openingGesture: "A Literary Elf listened to your whole day and kept only one sound, the way one keeps a single perfect line.",
            terms: "Find one sound and render it so exactly that naming it twice would be a lie.",
            giftName: "the rendered sound",
            giftDescription: "A faithfulness that keeps one kept page from being forgotten."
        ),
        FaeBargainTemplate(
            faeKind: .literaryElf,
            openingGesture: "A Literary Elf marked the precise border where one thing became another and called it the most important line of the day.",
            terms: "Bring me the exact edge where one texture becomes another on a single surface.",
            giftName: "the named border",
            giftDescription: "A precision that keeps one kept page safe in my long memory."
        ),

        // MARK: Deep Lore Dwarf — the underlayer, the oldest, the thing holding something up
        FaeBargainTemplate(
            faeKind: .deepLoreDwarf,
            openingGesture: "A Deep Lore Dwarf set down a small grey stone before you. It is older than the catalogue. It said nothing.",
            terms: "Bring me the oldest thing in your room and what it has quietly held up all this time.",
            giftName: "the foundation stone",
            giftDescription: "A weight that mines an overlooked kind of page back up to the shelf."
        ),
        FaeBargainTemplate(
            faeKind: .deepLoreDwarf,
            openingGesture: "A Deep Lore Dwarf laid one heavy hand on a wall and nodded, slowly, at the work it has done unthanked.",
            terms: "Find the nail, beam, or bracket doing the real work unseen, and bring me the fact of it.",
            giftName: "the unthanked nail",
            giftDescription: "A weight that brings an overlooked kind of page back up to the shelf."
        ),
        FaeBargainTemplate(
            faeKind: .deepLoreDwarf,
            openingGesture: "A Deep Lore Dwarf knocked once on the floor, listened to what answered from below, and was satisfied.",
            terms: "Somewhere under your feet is a floor older than the building's purpose — bring me its colour.",
            giftName: "the older floor",
            giftDescription: "A depth that mines an overlooked kind of page back into view."
        ),
        FaeBargainTemplate(
            faeKind: .deepLoreDwarf,
            openingGesture: "A Deep Lore Dwarf traced a long-healed repair with a thumb and did not say how long ago, only that it remembers.",
            terms: "Find a seam where something was mended long ago and bring me the colour of the older part.",
            giftName: "the mended seam",
            giftDescription: "A weight that brings an overlooked kind of page back up from rest."
        ),
        FaeBargainTemplate(
            faeKind: .deepLoreDwarf,
            openingGesture: "A Deep Lore Dwarf pressed a worn stair-edge and felt ten thousand feet vote in the hollow they had made.",
            terms: "Bring me the worn dip in a step where countless feet have passed, and how deep they have voted.",
            giftName: "the voted stone",
            giftDescription: "A heaviness that mines an overlooked kind of page back to the shelf."
        ),
        FaeBargainTemplate(
            faeKind: .deepLoreDwarf,
            openingGesture: "A Deep Lore Dwarf set two stones before you — one you could lift, one you could not — and let the difference speak.",
            terms: "Bring me the weight of a stone you can lift, and the colder fact of the one you cannot.",
            giftName: "the two weights",
            giftDescription: "A ballast that brings an overlooked kind of page back up to the shelf."
        ),

        // MARK: Marginalia Goblin — the unchosen detail, the gap between a name and a thing
        FaeBargainTemplate(
            faeKind: .goblin,
            openingGesture: "A Marginalia Goblin slid a sealed card across the table before you sat down. The wax is already broken.",
            terms: "Bring me one thing you've walked past for years and never once looked at — the thing, not its name.",
            giftName: "the broken-seal card",
            giftDescription: "A calling card that opens the Goblin Market when you spend it."
        ),
        FaeBargainTemplate(
            faeKind: .goblin,
            openingGesture: "A Marginalia Goblin appraised your day at a glance, named a fair price, and left a card as the receipt.",
            terms: "Find where a sign lies about what it labels, and bring me the truer name.",
            giftName: "the lying-sign card",
            giftDescription: "A calling card that opens the Goblin Market when you present it."
        ),
        FaeBargainTemplate(
            faeKind: .goblin,
            openingGesture: "A Marginalia Goblin sniffed the air for a bargain, found one in your pocket, and slid a card over to seal it.",
            terms: "Bring me the smell of a shop in the second before its door has fully opened — that, not the shop.",
            giftName: "the threshold card",
            giftDescription: "A calling card that opens the Goblin Market when you spend it."
        ),
        FaeBargainTemplate(
            faeKind: .goblin,
            openingGesture: "A Marginalia Goblin held the cheapest thing in the room up to the light, whistled low, and pocketed nothing — for now.",
            terms: "Find the cheapest object near you and bring me the one way it is secretly priceless.",
            giftName: "the undervalued card",
            giftDescription: "A calling card that opens the Goblin Market when you present it."
        ),
        FaeBargainTemplate(
            faeKind: .goblin,
            openingGesture: "A Marginalia Goblin pointed at a corner your eyes had been sliding off all day, and charged you nothing to finally see it.",
            terms: "Bring me a corner everyone's gaze slides off, and the specific thing waiting in it.",
            giftName: "the overlooked-corner card",
            giftDescription: "A calling card that opens the Goblin Market when you spend it."
        ),
        FaeBargainTemplate(
            faeKind: .goblin,
            openingGesture: "A Marginalia Goblin read a half-worn brand name aloud, preferred the wear to the word, and traded you a card for the trouble.",
            terms: "Bring me a brand name worn half away, and the better word the wear left behind.",
            giftName: "the worn-letters card",
            giftDescription: "A calling card that opens the Goblin Market when you spend it."
        )
    ]

    // MARK: Lifecycle (pure mutations on FaePlayerState)

    /// How long a proposed-but-untouched bargain waits on the desk before the
    /// Fae quietly withdraw the offer. Nothing is fronted, so letting it expire
    /// costs the reader nothing.
    static let offerExpiryHours = 72

    /// Propose a bargain. The Fae only *hold the gift out* here — nothing is
    /// fronted, no Claim is paid, no deadline runs. The exchange becomes real
    /// only when the reader explicitly accepts it (see `acceptBargain`).
    /// Opening or swiping the preview therefore costs nothing.
    @discardableResult
    static func offerBargain(
        into state: inout FaePlayerState,
        kind: FaeKind,
        slot: String,
        now: Date = Date()
    ) -> FaeBargain {
        let template = template(for: kind, slot: slot)
        let giftID = "fae-gift-\(kind.rawValue)-\(slot)"
        let bargainID = "fae-bargain-\(kind.rawValue)-\(slot)"
        let bargain = FaeBargain(
            id: bargainID,
            faeKind: kind,
            slot: slot,
            giftID: giftID,
            giftName: template.giftName,
            giftEffectLine: kind.giftEffect.effectLine,
            openingGesture: template.openingGesture,
            terms: template.terms,
            offeredAt: now,
            deadline: now.addingTimeInterval(Double(paymentWindowHours) * 3_600),
            status: .offered,
            fieldReport: nil,
            faeResponse: nil,
            rewardText: nil,
            deliveredAt: nil
        )
        if !state.bargains.contains(where: { $0.id == bargainID }) {
            state.bargains.append(bargain)
        }
        state.lastBargainOfferedAt = now
        return bargain
    }

    /// Accept a proposed bargain through its explicit consent action: NOW the
    /// gift is fronted, the Claim is paid, and the payment window starts.
    /// Idempotent — repeating acceptance changes nothing.
    @discardableResult
    static func acceptBargain(
        bargainID: String,
        into state: inout FaePlayerState,
        now: Date = Date()
    ) -> FaeBargain? {
        guard let index = state.bargains.firstIndex(where: { $0.id == bargainID }) else { return nil }
        guard state.bargains[index].status == .offered else { return state.bargains[index] }

        let bargain = state.bargains[index]
        let kind = bargain.faeKind
        let gift = FaeGift(
            id: bargain.giftID,
            faeKind: kind,
            name: bargain.giftName,
            descriptionText: template(for: kind, slot: bargain.slot).giftDescription,
            effect: kind.giftEffect,
            isCold: false,
            acquiredAt: now,
            chargesRemaining: kind.giftEffect == .callingCard ? 1 : nil,
            boundSourceID: nil,
            activatedAt: kind.giftEffect == .quieting ? now : nil,
            expiresAt: kind.giftEffect == .quieting ? now.addingTimeInterval(24 * 3_600) : nil
        )
        if !state.gifts.contains(where: { $0.id == gift.id }) {
            state.gifts.append(gift)
        }
        state.bargains[index].status = .owed
        state.bargains[index].offeredAt = now
        state.bargains[index].deadline = now.addingTimeInterval(Double(paymentWindowHours) * 3_600)
        adjustClaim(kind, by: claimPerOffer, into: &state)
        return state.bargains[index]
    }

    /// Drop any proposed bargains the reader never opened past their offer
    /// window. Nothing was fronted, so there is no penalty — the desk just clears
    /// so a fresh offer can arrive. Returns the ids withdrawn.
    @discardableResult
    static func expireStaleOffers(into state: inout FaePlayerState, now: Date = Date()) -> [String] {
        let cutoff = Double(offerExpiryHours) * 3_600
        let expired = state.bargains
            .filter { $0.status == .offered && now.timeIntervalSince($0.offeredAt) > cutoff }
            .map(\.id)
        guard !expired.isEmpty else { return [] }
        state.bargains.removeAll { expired.contains($0.id) }
        return expired
    }

    /// Let an owed exchange bite after its window. The fronted gift goes cold,
    /// the relationship loses warmth, Claim grows, and the species' market is
    /// closed by the resulting lapsed bargain. Distress pauses this transition.
    @discardableResult
    static func sweepLapses(
        into state: inout FaePlayerState,
        now: Date = Date(),
        distressActive: Bool = false
    ) -> [String] {
        guard !distressActive else { return [] }
        var changed: [String] = []
        for index in state.bargains.indices where state.bargains[index].status == .owed {
            guard now > state.bargains[index].deadline else { continue }
            let bargain = state.bargains[index]
            state.bargains[index].status = .lapsed
            if let giftIndex = state.gifts.firstIndex(where: { $0.id == bargain.giftID }) {
                state.gifts[giftIndex].isCold = true
            }
            state.warmth[bargain.faeKind.rawValue] =
                (state.warmth[bargain.faeKind.rawValue] ?? 0) - warmthLostOnLapse
            adjustClaim(bargain.faeKind, by: claimPerLapse, into: &state)
            appendOmen(
                kind: bargain.faeKind,
                title: "Cold Ink Debt",
                text: "\(bargain.giftName) has gone cold. The old terms still know the way back.",
                choiceID: bargain.id,
                intensity: 2,
                lifetimeHours: 7 * 24,
                into: &state,
                now: now
            )
            changed.append(bargain.id)
        }
        return changed
    }

    /// Pay a bargain with a genuine field report. Awards warmth and attention,
    /// stores the fae's response and reward, and closes the deal.
    static func deliver(
        bargainID: String,
        report: String,
        faeResponse: String,
        reward: String,
        into state: inout FaePlayerState,
        now: Date = Date()
    ) {
        guard let index = state.bargains.firstIndex(where: { $0.id == bargainID }) else { return }
        let wasLapsed = state.bargains[index].status == .lapsed
        state.bargains[index].status = .delivered
        state.bargains[index].fieldReport = report
        state.bargains[index].faeResponse = faeResponse
        state.bargains[index].rewardText = reward
        state.bargains[index].deliveredAt = now

        // A late answer repairs the exact exchange: gift, omen, and market door.
        let giftID = state.bargains[index].giftID
        if let giftIndex = state.gifts.firstIndex(where: { $0.id == giftID }) {
            state.gifts[giftIndex].isCold = false
        }

        let kind = state.bargains[index].faeKind
        let mood = mood(for: now)
        state.warmth[kind.rawValue] = (state.warmth[kind.rawValue] ?? 0) + warmthPerDelivery
        adjustClaim(kind, by: -claimReliefPerDelivery, into: &state)
        if wasLapsed {
            state.omens.removeAll { $0.sourceChoiceID == bargainID }
        }
        state.attention += attention(forReport: report, mood: mood)
    }

    /// Spend a consumable gift (e.g., a calling card). Returns true if spent.
    @discardableResult
    static func spendCharge(giftID: String, into state: inout FaePlayerState) -> Bool {
        guard let index = state.gifts.firstIndex(where: { $0.id == giftID }),
              state.gifts[index].isActive,
              let charges = state.gifts[index].chargesRemaining,
              charges > 0 else { return false }
        state.gifts[index].chargesRemaining = charges - 1
        return true
    }
}

// MARK: - Fae gift effects (pure, automatic, never a model call)

enum FaeGiftEffects {
    /// Sources a warm Reshelving gift lifts back to the front of the shelf.
    static let reshelfEligible: Set<BookPageType> = [
        .diary, .souvenir, .mood, .weather, .gossip, .askTheBook,
        .wonderCompass, .letter, .body, .fuel, .rest
    ]

    /// If the reader holds a warm Reshelving gift, choose the source to lift:
    /// an explicitly bound one, else the longest-rested eligible source.
    static func reshelvedSourceIDs(
        state: FaePlayerState,
        surfaceHistory: [String: SurfaceHistoryRecord],
        now: Date = Date()
    ) -> Set<String> {
        let reshelvers = state.activeGifts.filter { $0.effect == .reshelving }
        guard !reshelvers.isEmpty else { return [] }
        if let bound = reshelvers.compactMap(\.boundSourceID).first(where: { !$0.isEmpty }) {
            return [bound]
        }
        let eligible = BookPageSourceRegistry.sources.filter {
            $0.isActive && reshelfEligible.contains($0.type)
        }
        let chosen = eligible.min { left, right in
            lastShown(left, surfaceHistory) < lastShown(right, surfaceHistory)
        }
        return chosen.map { [$0.id] } ?? []
    }

    private static func lastShown(_ source: BookPageSource, _ history: [String: SurfaceHistoryRecord]) -> Date {
        history["source:\(source.id)"]?.lastShownAt ?? .distantPast
    }

    /// Kept-page IDs a warm Long Memory gift pins to reliably resurface.
    static func pinnedPageIDs(state: FaePlayerState) -> Set<String> {
        Set(state.activeGifts.filter { $0.effect == .longMemory }.compactMap(\.boundSourceID).filter { !$0.isEmpty })
    }
}

/// A Loose Page reads a little differently every time it is opened. Pure static
/// rotation — no model call — so it can be read freely without a Gemma turn.
enum LoosePageReader {
    static let fragments: [String] = [
        "The page is mostly margin. In the center, in a hand you almost recognize: \"You will mistake the exit for a wall three times before you trust it.\" The ink is still drying, though no one has been here.",
        "A pressed flower you have never seen, with a name written beneath it that means the smell of a room just after someone has left it. The petals turn toward you when you read.",
        "A list, half-erased: things to do before the snow. Only the last item survives — \"forgive the kettle\" — and you find you understand it completely.",
        "A map of a coastline that does not exist, with one harbor circled and the note: \"You have been here. You called it something else.\"",
        "Three sentences in a language of only vowels. You cannot read them, but reading them makes your shoulders drop an inch, the way a held breath finally goes.",
        "A receipt for one (1) afternoon, paid in full, no refunds. The cashier's signature is a small drawing of a sleeping cat.",
        "Someone began to describe the color of a particular hour and gave up halfway, leaving: \"it was the color of—\" The blank is the most honest part.",
        "A door, drawn in pencil, slightly ajar. If you tilt the page, light seems to come through the gap, though it is only paper."
    ]

    static func text(for gift: FaeGift, now: Date = Date()) -> String {
        guard !fragments.isEmpty else { return "" }
        // A coarse time slot makes the page shift between readings.
        let slot = Int(now.timeIntervalSince1970 / 1_800)
        let index = abs("\(gift.id)-\(slot)".stableHash) % fragments.count
        return fragments[index]
    }
}

// MARK: - The Goblin Market

struct FaeMarketOffer: Identifiable, Equatable {
    let id: String
    let faeKind: FaeKind
    let name: String
    let descriptionText: String
    let effect: FaeGiftEffect
    let baseCost: Int
}

enum FaeMarketCatalog {
    static let offers: [FaeMarketOffer] = [
        FaeMarketOffer(
            id: "market-quieting-coal",
            faeKind: .sentenceSalamander,
            name: "a second borrowed coal",
            descriptionText: "Holds the grey of Routine back by one shade for a day.",
            effect: .quieting,
            baseCost: 6
        ),
        FaeMarketOffer(
            id: "market-wandering-comma",
            faeKind: .punctuationPixie,
            name: "a wandering comma",
            descriptionText: "Re-shelves a resting kind of page so it finds you again.",
            effect: .reshelving,
            baseCost: 5
        ),
        FaeMarketOffer(
            id: "market-silver-quill",
            faeKind: .literaryElf,
            name: "a silver quill",
            descriptionText: "Keeps one kept page from ever being forgotten.",
            effect: .longMemory,
            baseCost: 7
        ),
        FaeMarketOffer(
            id: "market-loose-page",
            faeKind: .bookSprite,
            name: "a loose page",
            descriptionText: "A page that never reads the same way twice.",
            effect: .loosePage,
            baseCost: 4
        ),
        FaeMarketOffer(
            id: "market-unspoken-pen",
            faeKind: .goblin,
            name: "The Unspoken Pen",
            descriptionText: "Asks Gemma for one sentence that has never been spoken before, and tries to make it make sense.",
            effect: .unspokenPen,
            baseCost: 6
        ),
        FaeMarketOffer(
            id: "market-broken-seal-card",
            faeKind: .goblin,
            name: "a broken-seal calling card",
            descriptionText: "Opens the Goblin Market again when you spend it.",
            effect: .callingCard,
            baseCost: 8
        )
    ]

    /// Goblin mood moves the price: generous shaves a little, serious deals at
    /// unusual (cheaper, rarer) rates, feverish marks things up.
    static func cost(of offer: FaeMarketOffer, mood: GoblinMood) -> Int {
        switch mood {
        case .generous: return max(1, offer.baseCost - 1)
        case .serious: return max(1, offer.baseCost - 2)
        case .feverish: return offer.baseCost + 2
        case .business: return offer.baseCost
        }
    }
}

extension FaeEconomy {
    /// True when the reader can shop: the new-moon window is open, or they hold
    /// a calling card to spend. After-hours cards bought from the radio sponsor
    /// shelf prop the side door open for the rest of the current Book day.
    static func canEnterMarket(state: FaePlayerState, now: Date = Date()) -> Bool {
        guard !state.marketIsClosed(for: .goblin) else { return false }
        if marketWindowIsOpen(on: now) { return true }
        if let lastMarketCardAt = state.lastMarketCardAt,
           BookDay.id(for: lastMarketCardAt) == BookDay.id(for: now) {
            return true
        }
        return state.activeGifts.contains { $0.effect == .callingCard }
    }

    /// Buy a market offer with Attention. Returns the acquired gift, or nil if
    /// the reader cannot afford it.
    @discardableResult
    static func purchase(
        offerID: String,
        into state: inout FaePlayerState,
        now: Date = Date()
    ) -> FaeGift? {
        guard let offer = FaeMarketCatalog.offers.first(where: { $0.id == offerID }) else { return nil }
        let price = FaeMarketCatalog.cost(of: offer, mood: mood(for: now))
        guard state.attention >= price else { return nil }
        // Spend a calling card first if the moon window is shut.
        if !marketWindowIsOpen(on: now),
           let card = state.gifts.firstIndex(where: { $0.effect == .callingCard && $0.isActive }) {
            if let charges = state.gifts[card].chargesRemaining {
                state.gifts[card].chargesRemaining = max(0, charges - 1)
            }
        }
        state.attention -= price
        let gift = FaeGift(
            id: "market-gift-\(offerID)-\(Int(now.timeIntervalSince1970))",
            faeKind: offer.faeKind,
            name: offer.name,
            descriptionText: offer.descriptionText,
            effect: offer.effect,
            isCold: false,
            acquiredAt: now,
            chargesRemaining: offer.effect == .callingCard ? 1 : nil,
            boundSourceID: nil
        )
        state.gifts.append(gift)
        return gift
    }
}

// MARK: - The Goblin Market (the living BookShop)
//
// The BookShop is a place the Marginalia Goblins run, not a menu. It carries
// three economies at once: real content packs (StoreKit), in-world
// wares bought with Attention earned from Fae bargains, and consumable goods
// bought with Belief — which makes the shop the central SINK the rest of the
// economy was missing. Stock rotates with the day and the moon; an
// under-the-counter shelf only appears under the right conditions. Pure, local,
// testable; the app layer handles money and applies effects.

enum MarketCurrency: String, Codable, Equatable {
    case attention, belief, money

    var label: String {
        switch self {
        case .attention: return "Attention"
        case .belief: return "Belief"
        case .money: return "App Store"
        }
    }
}

/// What a ware actually gives the reader when bought.
enum MarketGood: Equatable {
    case gift(FaeGiftEffect, FaeKind)   // grants a consumable Fae gift
    case warmWord                        // Belief → a point of Belief to a cast member
    case pack(String)                    // money → unlock a content pack (packID)
    case pocketSunshine                  // lowers the saved Nothing-grey offset now
    case hummingJar                       // turns Belief into Attention and tunes Fae-Fi
    case porchlightLamp                   // tunes Mothlight and opens Book Remembered
    case rememberingBell                  // opens Book Remembered and warms the Literary Elves
    case bramblewineDram                  // buys Attention at a grey cost and tunes Thornwave
    case afterHoursCard                   // opens today's side door without becoming a Fae gift
}

struct MarketWare: Identifiable, Equatable {
    let id: String
    let title: String
    let clerkPitch: String
    let contents: String
    let currency: MarketCurrency
    let basePrice: Int        // Attention/Belief amount (ignored for money)
    let good: MarketGood
    let rarity: Int           // 1 common … 3 rare (rare lives under the counter)
}

struct GoblinStall: Equatable {
    let open: Bool             // the in-world shelves are buyable (new moon / calling card)
    let mood: GoblinMood
    let moodLine: String
    let windowLine: String
    let wares: [MarketWare]    // today's open in-world shelf
    let hidden: [MarketWare]   // under-the-counter, revealed by conditions
    let packs: [BookShopListing]   // money shelf — always browseable
}

enum GoblinMarketEngine {
    /// Belief-priced consumables — the shop's own sinks, on top of the
    /// Attention wares drawn from the Fae market.
    static let beliefWares: [MarketWare] = [
        MarketWare(id: "belief-warm-word", title: "a warm word",
                   clerkPitch: "Whisper a kindness into the ledger and we'll see it reaches them. Costs you a little shine.",
                   contents: "Warms a Cast Member you choose.",
                   currency: .belief, basePrice: 8, good: .warmWord, rarity: 1),
        MarketWare(id: "belief-tallow-candle", title: "a tallow candle",
                   clerkPitch: "Burns slow and unfashionable. The dark keeps its distance from honest tallow.",
                   contents: "Holds Routine's grey back for the day.",
                   currency: .belief, basePrice: 10, good: .gift(.quieting, .goblin), rarity: 1),
        MarketWare(id: "belief-borrowed-comma", title: "a borrowed comma",
                   clerkPitch: "A small pause, lent at interest. Use it to bring a resting page back into the light.",
                   contents: "Re-shelves a resting kind of Page so it can find you again.",
                   currency: .belief, basePrice: 9, good: .gift(.reshelving, .goblin), rarity: 2),
        MarketWare(id: "belief-long-memory-ribbon", title: "a long-memory ribbon",
                   clerkPitch: "Tie it to a page and I won't be allowed to forget it. We checked. It won't.",
                   contents: "Keeps one Page returning as Book Remembered.",
                   currency: .belief, basePrice: 12, good: .gift(.longMemory, .literaryElf), rarity: 3)
    ]

    /// Products that radio sponsor reads point back to. These stay in the same
    /// in-world economy as the rest of the stall, so every ad is for a real ware
    /// the reader can eventually find and buy.
    static let radioSponsorWares: [MarketWare] = [
        MarketWare(
            id: "radio-sponsor-thistledown-pocket-sunshine",
            title: "Thistledown & Co. Pocket Sunshine",
            clerkPitch: "A coat-pocket sunbeam. Small print says it is not the weather, but the weather has been known to listen.",
            contents: "Pushes Routine's grey back at once.",
            currency: .belief,
            basePrice: 9,
            good: .pocketSunshine,
            rarity: 1
        ),
        MarketWare(
            id: "radio-sponsor-clover-honey-humming-jar",
            title: "Clover Honey Collective Humming Jar",
            clerkPitch: "Warm afternoon, stoppered and humming. Do not shake it unless you want the shelves to remember summer.",
            contents: "Catches the clerk's attention and tunes the radio to Fae-Fi.",
            currency: .belief,
            basePrice: 8,
            good: .hummingJar,
            rarity: 1
        ),
        MarketWare(
            id: "radio-sponsor-porchlight-moth-lamp",
            title: "Porchlight & Moth Lamp",
            clerkPitch: "A lamp left on for what has not come home yet. Excellent for pages with cold hands.",
            contents: "Tunes Mothlight Beats and opens Book Remembered.",
            currency: .belief,
            basePrice: 12,
            good: .porchlightLamp,
            rarity: 3
        ),
        MarketWare(
            id: "radio-sponsor-remembering-bell",
            title: "The Remembering Bell",
            clerkPitch: "Ring it over a page you thought you lost. If it rings back, be polite.",
            contents: "Opens Book Remembered and warms the Literary Elves.",
            currency: .belief,
            basePrice: 10,
            good: .rememberingBell,
            rarity: 2
        ),
        MarketWare(
            id: "radio-sponsor-bramblewine-dram",
            title: "Bramblewine Dram",
            clerkPitch: "A sip for nights with teeth. The cork lists the price twice, which is almost honest.",
            contents: "Catches sharp attention, tunes Thornwave, and lets the grey lean a shade closer.",
            currency: .belief,
            basePrice: 11,
            good: .bramblewineDram,
            rarity: 3
        ),
        MarketWare(
            id: "radio-sponsor-melisande-after-hours-card",
            title: "Melisande's After-Hours Calling Card",
            clerkPitch: "Show it after the shutters go down. Melisande will overcharge you accurately.",
            contents: "Keeps the market's side door open for the rest of today and warms the Goblins.",
            currency: .belief,
            basePrice: 10,
            good: .afterHoursCard,
            rarity: 2
        )
    ]

    static let radioSponsorWareIDsByBanterID: [String: String] = [
        "faefi-sponsor-thistledown": "radio-sponsor-thistledown-pocket-sunshine",
        "faefi-sponsor-cloverhoney": "radio-sponsor-clover-honey-humming-jar",
        "mothlight-sponsor-porchlightmoth": "radio-sponsor-porchlight-moth-lamp",
        "mothlight-sponsor-theremembering": "radio-sponsor-remembering-bell",
        "thornwave-sponsor-bramblewine": "radio-sponsor-bramblewine-dram",
        "thornwave-sponsor-goblin-market": "radio-sponsor-melisande-after-hours-card"
    ]

    /// Every in-world ware (Attention from the Fae market + Belief consumables).
    static var inWorldWares: [MarketWare] {
        let attention = FaeMarketCatalog.offers.map { offer in
            MarketWare(
                id: "attention-\(offer.id)",
                title: offer.name,
                clerkPitch: "From the Attention shelf — paid in noticing, not coin.",
                contents: offer.descriptionText,
                currency: .attention,
                basePrice: offer.baseCost,
                good: .gift(offer.effect, offer.faeKind),
                rarity: offer.effect == .callingCard ? 2 : 1
            )
        }
        return attention + beliefWares + radioSponsorWares
    }

    /// Mood moves the price; Warmth with the goblins earns a quiet discount
    /// (the baseline of haggling).
    static func price(_ ware: MarketWare, mood: GoblinMood, goblinWarmth: Int) -> Int {
        var p = ware.basePrice
        switch mood {
        case .generous: p -= 1
        case .serious: p -= 2
        case .feverish: p += 2
        case .business: break
        }
        p -= min(2, goblinWarmth / 4)   // standing shaves a little
        return max(1, p)
    }

    private static func dayShuffled(_ wares: [MarketWare], dayID: String) -> [MarketWare] {
        wares.sorted { "\($0.id)-\(dayID)".stableHash < "\($1.id)-\(dayID)".stableHash }
    }

    /// Today's living stall.
    static func stall(
        on date: Date,
        fae: FaePlayerState,
        belief: Int,
        greyLevel: Int,
        hemisphere: Hemisphere = .northern,
        recentBookJumpCollapse: Bool = false,
        ownedPackIDs: Set<String> = [],
        calendar: Calendar = .current
    ) -> GoblinStall {
        let open = FaeEconomy.canEnterMarket(state: fae, now: date)
        let mood = FaeEconomy.mood(for: date, calendar: calendar)
        let dayID = BookDay.id(for: date, calendar: calendar)
        let goblinWarmth = fae.warmth(for: .goblin)

        let pool = inWorldWares.filter { ware in
            // Affordable-or-not is shown; but a closed market only teases commons.
            ware.rarity < 3
        }
        let shuffled = dayShuffled(pool, dayID: dayID)
        // A full new-moon market lays out more; a calling-card visit is a thin stall.
        let newMoonOpen = FaeEconomy.marketWindowIsOpen(on: date)
        let visibleCount = newMoonOpen ? 5 : 3
        let wares = open ? Array(shuffled.prefix(visibleCount)) : []

        // The under-the-counter shelf: rare wares, only when the world leans in.
        let fullMoon = Almanac.activeEsbat(on: date)?.id == "esbat-full"
        let sabbat = Almanac.activeSabbat(on: date, hemisphere: hemisphere, calendar: calendar) != nil
        let revealHidden = open && (fullMoon || sabbat || goblinWarmth >= 8 || greyLevel >= 2 || recentBookJumpCollapse)
        let hidden = revealHidden
            ? dayShuffled(inWorldWares.filter { $0.rarity >= 3 }, dayID: dayID)
            : []

        let packs = BookShopCatalog.listings.filter { !$0.comingSoon && !PackEntitlements.owns($0.packID, in: ownedPackIDs) }

        let windowLine: String
        if fae.marketIsClosed(for: .goblin) {
            windowLine = "Cold Ink bars the in-world stalls. Answer the lapsed Goblin bargain and the market latch will lift; the paid shelf remains separate."
        } else if newMoonOpen {
            windowLine = "The new-moon market is in full swing — every stall is lit."
        } else if open {
            windowLine = "The window is shut, but your calling card props a side door open. A thin stall, tonight."
        } else {
            windowLine = "The in-world stalls are dark until the new moon — or a calling card. The paid shelf is always open."
        }

        return GoblinStall(
            open: open, mood: mood, moodLine: mood.line, windowLine: windowLine,
            wares: wares, hidden: hidden, packs: packs
        )
    }
}

// MARK: - Goblin Marginalia
//
// Goblins are born from marginalia — the response to the story, not the story.
// Occasionally one annotates a page the reader has already kept. Pure static
// rotation; never a model call, so it can appear ambiently without a Gemma turn.

enum GoblinMarginalia {
    static let openers: [String] = [
        "A goblin has annotated this, in a small cramped hand:",
        "Noted in the margin, in ink that wasn't yours:",
        "Someone from the Appendix Provinces left a remark here:",
        "Marginalia, dog-eared at the corner:"
    ]

    static let remarks: [String] = [
        "\"The detail here is real. Filed under things-worth-keeping.\"",
        "\"You noticed this without being asked. We see that.\"",
        "\"This one is load-bearing. Do not let it go grey.\"",
        "\"Worth more than you traded for it. The Empire does not say that often.\"",
        "\"An honest noticing. Rare coin.\"",
        "\"We were here before this page. We will be here after. Good that you wrote it down.\"",
        "\"The category is dull; the particular is not. You chose the particular. Noted.\"",
        "\"Annotated and shelved by mood, not by number.\""
    ]

    /// An occasional goblin note for a kept page, deterministic by its id so it
    /// is stable across openings. Returns nil for most pages — it should feel rare.
    static func note(forID id: String, text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 24, !openers.isEmpty, !remarks.isEmpty else { return nil }
        let hash = abs(id.stableHash)
        guard hash % 3 == 0 else { return nil }
        return "\(openers[hash % openers.count]) \(remarks[(hash / 7) % remarks.count])"
    }
}

// MARK: - The Pact War
//
// Each Talisman has a philosophy it wants to spread. The war is them contesting
// territory — measured in Control Belief, per talisman, per territory — across
// two fronts: the Book's own shelves (kinds of pages) and the real-world
// integrations the app touches. Pure local simulation; never a model call. It
// goes quiet under distress, like Routine. See lore/chapter-pacts.md.

enum PactFront: String, Codable, Equatable {
    case shelf
    case integration
}

struct PactTerritory: Identifiable, Equatable {
    let id: String
    let front: PactFront
    let name: String
    let blurb: String
    let pageTypes: [BookPageType]   // shelf front: which page kinds it governs
}

enum PactTerritoryRegistry {
    static let shelves: [PactTerritory] = [
        PactTerritory(id: "shelf-reflection", front: .shelf, name: "The Reflection Shelf",
                      blurb: "Diary, Inner Weather, Souvenirs, About You — where you write yourself down.",
                      pageTypes: [.diary, .mood, .souvenir, .aboutYou]),
        PactTerritory(id: "shelf-care", front: .shelf, name: "The Care Shelf",
                      blurb: "Body, Fuel, Center, Weather — where I tend the animal of you.",
                      pageTypes: [.body, .fuel, .rest, .weather]),
        PactTerritory(id: "shelf-story", front: .shelf, name: "The Story Shelf",
                      blurb: "Story Pages, Gossip, The Bleed, my own noticing.",
                      pageTypes: [.narrativeOS, .gossip, .theBleed, .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices]),
        PactTerritory(id: "shelf-connection", front: .shelf, name: "The Connection Shelf",
                      blurb: "Letters, Cast illustrations, the Support Guild, Office Hours, Fae Bargains — pages with another hand in them.",
                      pageTypes: [.letter, .illustration, .supportGuild, .inkrestOfficeHours, .faeBargain]),
        PactTerritory(id: "shelf-field", front: .shelf, name: "The Field Shelf",
                      blurb: "Wonder Compass, Outer Stacks, Illuminated Photos, Hour Pages — the world out the door.",
                      pageTypes: [.wonderCompass, .anchor, .illuminatedPhoto, .location, .calendar])
    ]

    static let integrations: [PactTerritory] = [
        PactTerritory(id: "integ-calendar", front: .integration, name: "The Calendar Door",
                      blurb: "The hinges of your real day — events I fold corners around.", pageTypes: []),
        PactTerritory(id: "integ-notifications", front: .integration, name: "The Whisper Channel",
                      blurb: "My voice, reaching you when the app is closed.", pageTypes: []),
        PactTerritory(id: "integ-health", front: .integration, name: "The Body Margin",
                      blurb: "Sleep, steps, heartbeat — the signals I read with care.", pageTypes: []),
        PactTerritory(id: "integ-photos", front: .integration, name: "The Illuminated Plate",
                      blurb: "Real photographs I turn into illuminated pages.", pageTypes: []),
        PactTerritory(id: "integ-weather", front: .integration, name: "The Window Sky",
                      blurb: "The real weather I enchant into the day.", pageTypes: [])
    ]

    static let all: [PactTerritory] = shelves + integrations

    static func territory(id: String) -> PactTerritory? {
        all.first { $0.id == id }
    }

    /// The shelf territory that governs a given page kind, if any.
    static func shelf(governing type: BookPageType) -> PactTerritory? {
        shelves.first { $0.pageTypes.contains(type) }
    }
}

enum PactTier: Int, Comparable, Equatable {
    case none = 0
    case contesting
    case influenced
    case controlled
    case dominated
    case sovereign

    static func < (lhs: PactTier, rhs: PactTier) -> Bool { lhs.rawValue < rhs.rawValue }

    static func tier(forControl control: Int) -> PactTier {
        switch control {
        case ..<1: return .none
        case ..<10: return .contesting
        case ..<25: return .influenced
        case ..<45: return .controlled
        case ..<70: return .dominated
        default: return .sovereign
        }
    }

    var label: String {
        switch self {
        case .none: return "Uncontested"
        case .contesting: return "Contesting"
        case .influenced: return "Influenced"
        case .controlled: return "Controlled"
        case .dominated: return "Dominated"
        case .sovereign: return "Sovereign"
        }
    }
}

struct PactActionRecord: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, Equatable {
        case push, challenge, raid, consolidate
        case verdict     // the reader ruled a contested reading of a real page
        case errand      // the reader paid a talisman's errand with a field report
    }
    var id: String
    var talismanID: String
    var territoryID: String
    var kind: Kind
    var at: Date
    var line: String
}

/// A dramatic beat the war produced: a territory changed hands, or a Talisman
/// reached Sovereign. Surfaced as a keepable Pact Dispatch page.
struct PactDispatch: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, Equatable {
        case seized       // a new Talisman took control
        case sovereign    // a Talisman crossed into Sovereign
    }
    var id: String
    var territoryID: String
    var talismanID: String
    var kind: Kind
    var line: String
    var at: Date
}

enum PactErrandStatus: String, Codable, Equatable {
    case owed        // the talisman has asked; a field report is due
    case delivered   // paid with a real noticing; the talisman gained ground
    case lapsed      // the deadline passed unpaid
}

/// A talisman that holds a foothold sends the reader into the real day, paid in a
/// field report. The Pact War's mirror of a Fae Bargain — but the payment is lived
/// attention, and the reward is Control Belief on the talisman's own territory.
struct PactErrand: Identifiable, Codable, Equatable {
    var id: String
    var talismanID: String
    var territoryID: String
    var openingLine: String      // the talisman's ask, in its Chapter's voice
    var terms: String            // the noticing/doing owed
    var offeredAt: Date
    var deadline: Date
    var status: PactErrandStatus
    var fieldReport: String?
    var talismanResponse: String?
    var deliveredAt: Date?

    var isOpen: Bool { status == .owed }
}

/// The war's save state. Optional on the vault for migration.
struct PactWarState: Codable, Equatable {
    var control: [String: Int] = [:]   // "talismanID|territoryID" -> control belief
    var lastTickAt: Date?
    var log: [PactActionRecord] = []
    var pendingDispatches: [PactDispatch] = []
    var errands: [PactErrand] = []

    init() {}

    // Explicit Codable so older saves (which predate `errands`, and `pendingDispatches`
    // before it) decode cleanly instead of failing on a missing key.
    private enum CodingKeys: String, CodingKey {
        case control, lastTickAt, log, pendingDispatches, errands
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        control = try c.decodeIfPresent([String: Int].self, forKey: .control) ?? [:]
        lastTickAt = try c.decodeIfPresent(Date.self, forKey: .lastTickAt)
        log = try c.decodeIfPresent([PactActionRecord].self, forKey: .log) ?? []
        pendingDispatches = try c.decodeIfPresent([PactDispatch].self, forKey: .pendingDispatches) ?? []
        errands = try c.decodeIfPresent([PactErrand].self, forKey: .errands) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(control, forKey: .control)
        try c.encodeIfPresent(lastTickAt, forKey: .lastTickAt)
        try c.encode(log, forKey: .log)
        try c.encode(pendingDispatches, forKey: .pendingDispatches)
        try c.encode(errands, forKey: .errands)
    }

    var openErrand: PactErrand? { errands.first { $0.status == .owed } }

    static func key(_ talismanID: String, _ territoryID: String) -> String { "\(talismanID)|\(territoryID)" }

    func control(_ talismanID: String, _ territoryID: String) -> Int {
        control[Self.key(talismanID, territoryID)] ?? 0
    }

    /// Adjust a talisman's Control Belief on a territory, clamped to 0...100.
    /// Shared by the reader's verdicts/errands and the engine's own moves.
    mutating func adjust(_ talismanID: String, _ territoryID: String, by amount: Int) {
        let key = Self.key(talismanID, territoryID)
        control[key] = max(0, min(100, (control[key] ?? 0) + amount))
    }

    /// The talisman holding a territory: the clear leader, or nil on a tie/empty.
    func controller(of territoryID: String) -> String? {
        let scores = AcademyChapterRegistry.chapters.map { ($0.talismanID, control($0.talismanID, territoryID)) }
        let top = scores.max { $0.1 < $1.1 }
        guard let top, top.1 > 0 else { return nil }
        let tied = scores.filter { $0.1 == top.1 }.count > 1
        return tied ? nil : top.0
    }

    func tier(of territoryID: String) -> PactTier {
        guard let controller = controller(of: territoryID) else { return .none }
        return PactTier.tier(forControl: control(controller, territoryID))
    }
}

enum PactWarEngine {
    static let baseBelief = 30
    static let homeFieldBonus = 15
    static let tickGapHours = 20

    /// Natural alignment: which territories each Talisman pushes into easily.
    static let alignment: [String: Set<String>] = [
        "ember-seal": ["shelf-reflection", "shelf-story", "integ-notifications"],
        "moss-clasp": ["shelf-care", "shelf-field", "integ-health", "integ-weather"],
        "tide-glass": ["shelf-field", "shelf-story", "integ-photos"],
        "wind-cipher": ["shelf-connection", "integ-calendar", "integ-notifications"],
        "dusk-thorn": ["shelf-story", "shelf-connection", "integ-weather"]
    ]

    static func isAligned(_ talismanID: String, _ territoryID: String) -> Bool {
        alignment[talismanID]?.contains(territoryID) ?? false
    }

    /// A Talisman's overall Belief governs how aggressively it fights. Bound
    /// readers give their Chapter's Talisman a home-field bonus.
    static func overallBelief(
        talismanID: String,
        entityBeliefOffsets: [String: Int],
        boundTalismanID: String?
    ) -> Int {
        var value = baseBelief + (entityBeliefOffsets[talismanID] ?? 0)
        if talismanID == boundTalismanID { value += homeFieldBonus }
        return max(0, min(100, value))
    }

    static func canTick(state: PactWarState, now: Date = Date()) -> Bool {
        guard let last = state.lastTickAt else { return true }
        return now.timeIntervalSince(last) >= Double(tickGapHours) * 3_600
    }

    /// Advance the war by one stir per Talisman. Deterministic given the slot.
    /// Pure local logic; never a model call; silent under distress.
    @discardableResult
    static func tick(
        into state: inout PactWarState,
        entityBeliefOffsets: [String: Int],
        boundTalismanID: String?,
        now: Date = Date(),
        distressActive: Bool = false
    ) -> [PactActionRecord] {
        guard !distressActive, canTick(state: state, now: now) else { return [] }
        let slot = BookDay.id(for: now)
        let before = state   // value-type snapshot for crossing detection
        var records: [PactActionRecord] = []

        // Aggressive Talismans act first (more Belief = more initiative).
        let order = AcademyChapterRegistry.chapters
            .map { ($0.talismanID, overallBelief(talismanID: $0.talismanID, entityBeliefOffsets: entityBeliefOffsets, boundTalismanID: boundTalismanID)) }
            .sorted { $0.1 > $1.1 }

        for (talismanID, overall) in order {
            if let record = act(
                talismanID: talismanID,
                overall: overall,
                into: &state,
                entityBeliefOffsets: entityBeliefOffsets,
                boundTalismanID: boundTalismanID,
                slot: slot,
                now: now
            ) {
                records.append(record)
            }
        }

        // Detect dramatic crossings against the snapshot and queue dispatches.
        detectCrossings(before: before, into: &state, now: now)

        state.lastTickAt = now
        state.log = (records + state.log).prefix(24).map { $0 }
        return records
    }

    /// Compare a pre-action snapshot against the post-action state, queue a
    /// `PactDispatch` for any territory that changed hands or crossed into
    /// Sovereign, and prune the dispatch queue. Returns true if a *new* Sovereign
    /// crossing was queued (the caller can front a goblin bargain). Shared by the
    /// daily tick and the reader's verdicts/errands so player moves produce the
    /// same dramatic beats as the simulation.
    @discardableResult
    static func detectCrossings(before: PactWarState, into state: inout PactWarState, now: Date = Date()) -> Bool {
        var newSovereign = false
        for territory in PactTerritoryRegistry.all {
            let beforeController = before.controller(of: territory.id)
            let afterController = state.controller(of: territory.id)
            let name = AcademyChapterRegistry.chapter(forTalismanID: afterController ?? "")?.talismanName ?? "A Talisman"
            if let after = afterController, after != beforeController {
                queueDispatch(.seized, territory: territory, talismanID: after,
                              line: "\(name) has taken \(territory.name).", into: &state, now: now)
            }
            if state.tier(of: territory.id) == .sovereign,
               before.tier(of: territory.id) != .sovereign,
               let after = afterController {
                queueDispatch(.sovereign, territory: territory, talismanID: after,
                              line: "\(name) now reigns Sovereign over \(territory.name).", into: &state, now: now)
                newSovereign = true
            }
        }
        // Keep the dispatch queue small and fresh.
        state.pendingDispatches = state.pendingDispatches
            .filter { now.timeIntervalSince($0.at) < 4 * 86_400 }
            .suffix(6)
            .map { $0 }
        return newSovereign
    }

    private static func queueDispatch(
        _ kind: PactDispatch.Kind,
        territory: PactTerritory,
        talismanID: String,
        line: String,
        into state: inout PactWarState,
        now: Date
    ) {
        let id = "pact-dispatch-\(territory.id)-\(talismanID)-\(kind.rawValue)-\(BookDay.id(for: now))"
        guard !state.pendingDispatches.contains(where: { $0.id == id }) else { return }
        state.pendingDispatches.append(
            PactDispatch(id: id, territoryID: territory.id, talismanID: talismanID, kind: kind, line: line, at: now)
        )
    }

    private static func act(
        talismanID: String,
        overall: Int,
        into state: inout PactWarState,
        entityBeliefOffsets: [String: Int],
        boundTalismanID: String?,
        slot: String,
        now: Date
    ) -> PactActionRecord? {
        let name = AcademyChapterRegistry.chapter(forTalismanID: talismanID)?.talismanName ?? talismanID
        // Each decision draws from its own scrambled seed. Sharing one seed made
        // the consolidate gate (`seed % 3 == 0`) collide with the push target
        // (`seed % alignedCount`): whenever a push would have driven a Talisman's
        // *first* aligned territory, consolidate intercepted it with the weaker
        // bump instead, pinning every Talisman's flagship shelf to the slowest
        // growth rate and leaving Sovereign effectively unreachable by simulation.
        let seed = abs("\(slot)-\(talismanID)-pact".stableHash)
        let raidSeed = abs(seed.stableScramble)
        let challengeSeed = abs((seed &+ 1).stableScramble)
        let consolidateGate = abs((seed &+ 2).stableScramble)
        let consolidateSeed = abs((seed &+ 3).stableScramble)
        let pushSeed = abs((seed &+ 4).stableScramble)
        let aligned = PactTerritoryRegistry.all.filter { isAligned(talismanID, $0.id) }
        // Gentler than a reader's hand: the autonomous war moves, but a verdict
        // (+6) or errand (+8) outweighs any single tick action. The reader leads.
        let pushPotential = max(1, overall / 40)   // 1...2 per push

        // RAID: overall >= 50 and a rival sits Dominated+ on a territory this
        // Talisman can out-belief.
        if overall >= 50 {
            let raidable = PactTerritoryRegistry.all.compactMap { territory -> (String, Int)? in
                guard let rival = state.controller(of: territory.id), rival != talismanID else { return nil }
                guard state.control(rival, territory.id) >= 45 else { return nil }
                let rivalOverall = overallBelief(talismanID: rival, entityBeliefOffsets: entityBeliefOffsets, boundTalismanID: boundTalismanID)
                guard overall >= rivalOverall else { return nil }
                return (territory.id, rivalOverall)
            }
            if !raidable.isEmpty {
                let target = raidable[raidSeed % raidable.count]
                bump(&state, talismanID, target.0, by: pushPotential)
                if let rival = state.controller(of: target.0), rival != talismanID {
                    bump(&state, rival, target.0, by: -2)
                }
                return record(talismanID, target.0, .raid, now,
                              "\(name) raids \(PactTerritoryRegistry.territory(id: target.0)?.name ?? target.0).")
            }
        }

        // CHALLENGE: overall >= 30 and a rival leads by a thin margin here.
        if overall >= 30 {
            let contestable = PactTerritoryRegistry.all.compactMap { territory -> String? in
                guard let rival = state.controller(of: territory.id), rival != talismanID else { return nil }
                let gap = state.control(rival, territory.id) - state.control(talismanID, territory.id)
                return (gap > 0 && gap <= 8) ? territory.id : nil
            }
            if !contestable.isEmpty {
                let target = contestable[challengeSeed % contestable.count]
                bump(&state, talismanID, target, by: max(1, pushPotential - 1))
                if let rival = state.controller(of: target), rival != talismanID {
                    bump(&state, rival, target, by: -1)
                }
                return record(talismanID, target, .challenge, now,
                              "\(name) challenges for \(PactTerritoryRegistry.territory(id: target)?.name ?? target).")
            }
        }

        // CONSOLIDATE: hold a territory it already leads but hasn't yet made Sovereign.
        let held = PactTerritoryRegistry.all.filter {
            state.controller(of: $0.id) == talismanID && state.control(talismanID, $0.id) < 70
        }
        if !held.isEmpty, consolidateGate % 3 == 0 {
            let target = held[consolidateSeed % held.count]
            bump(&state, talismanID, target.id, by: max(1, pushPotential - 1))
            return record(talismanID, target.id, .consolidate, now,
                          "\(name) consolidates its hold on \(target.name).")
        }

        // PUSH (always available): deepen an aligned territory not yet Sovereign.
        let pushable = (aligned.isEmpty ? PactTerritoryRegistry.all : aligned)
            .filter { state.control(talismanID, $0.id) < 70 }
        guard !pushable.isEmpty else { return nil }
        let target = pushable[pushSeed % pushable.count]
        let amount = isAligned(talismanID, target.id) ? pushPotential : max(1, pushPotential - 1)
        bump(&state, talismanID, target.id, by: amount)
        return record(talismanID, target.id, .push, now,
                      "\(name) pushes into \(target.name).")
    }

    private static func bump(_ state: inout PactWarState, _ talismanID: String, _ territoryID: String, by amount: Int) {
        let key = PactWarState.key(talismanID, territoryID)
        state.control[key] = max(0, min(100, (state.control[key] ?? 0) + amount))
    }

    private static func record(_ talismanID: String, _ territoryID: String, _ kind: PactActionRecord.Kind, _ now: Date, _ line: String) -> PactActionRecord {
        PactActionRecord(
            id: "\(territoryID)-\(talismanID)-\(Int(now.timeIntervalSince1970))-\(kind.rawValue)",
            talismanID: talismanID, territoryID: territoryID, kind: kind, at: now, line: line
        )
    }
}

/// Live effect of the war on the Book's shelves: a Talisman that has reached
/// Controlled+ on a shelf gives that shelf's page kinds a surfacing nudge — its
/// philosophy "shapes timing." Pure curator math; quiet under distress.
enum PactWarEffects {
    static func shelfStory(for type: BookPageType, state: PactWarState) -> (line: String, talisman: String, tier: PactTier)? {
        guard let shelf = PactTerritoryRegistry.shelf(governing: type),
              let controller = state.controller(of: shelf.id),
              let chapter = AcademyChapterRegistry.chapter(forTalismanID: controller) else { return nil }
        let tier = state.tier(of: shelf.id)
        switch tier {
        case .contesting:
            return ("\(chapter.talismanName) has begun circling \(shelf.name). Nothing changes yet, but its philosophy is in the margins.", chapter.talismanName, tier)
        case .influenced:
            return ("\(chapter.talismanName) has a foothold in \(shelf.name). Pages like this may start leaning toward \(chapter.name)'s way of reading.", chapter.talismanName, tier)
        case .controlled:
            return ("\(chapter.talismanName) holds \(shelf.name), so this kind of page is a little more likely to surface and speak in \(chapter.name)'s hand.", chapter.talismanName, tier)
        case .dominated:
            return ("\(chapter.talismanName) dominates \(shelf.name). I'm actively favoring this shelf and framing it through \(chapter.name)'s doctrine.", chapter.talismanName, tier)
        case .sovereign:
            return ("\(chapter.talismanName) reigns Sovereign over \(shelf.name). It can call pages like this forward without waiting to be asked.", chapter.talismanName, tier)
        case .none:
            return nil
        }
    }

    static func shelfBoost(for type: BookPageType, state: PactWarState) -> Int {
        guard let shelf = PactTerritoryRegistry.shelf(governing: type),
              state.controller(of: shelf.id) != nil else { return 0 }
        switch state.tier(of: shelf.id) {
        case .controlled: return 4
        case .dominated: return 8
        case .sovereign: return 12
        default: return 0
        }
    }

    /// The Chapter writing-framing a controlled shelf currently speaks in, if any.
    static func framing(for type: BookPageType, state: PactWarState) -> String? {
        guard let shelf = PactTerritoryRegistry.shelf(governing: type),
              state.tier(of: shelf.id) >= .controlled,
              let controller = state.controller(of: shelf.id),
              let chapter = AcademyChapterRegistry.chapter(forTalismanID: controller) else { return nil }
        return chapter.writeFraming
    }

    /// Page kinds whose real-world door a Talisman speaks through.
    static let doorTerritory: [BookPageType: String] = [
        .body: "integ-health",
        .weather: "integ-weather",
        .illuminatedPhoto: "integ-photos"
    ]

    /// The epigraph the door's controller speaks over a Body/Weather/Photo page.
    static func doorEpigraph(for type: BookPageType, state: PactWarState) -> (line: String, talisman: String)? {
        guard let territoryID = doorTerritory[type],
              state.tier(of: territoryID) >= .controlled,
              let controller = state.controller(of: territoryID),
              let line = PactVoices.doorEpigraph(territoryID: territoryID, controller: controller),
              let chapter = AcademyChapterRegistry.chapter(forTalismanID: controller) else { return nil }
        return (line, chapter.talismanName)
    }

    /// Page kinds whose shelf a Talisman holds at Sovereign — these get a
    /// guaranteed slot in the surfaced set (the Talisman acts unasked).
    static func sovereignShelfPageTypes(state: PactWarState) -> Set<BookPageType> {
        var types = Set<BookPageType>()
        for shelf in PactTerritoryRegistry.shelves where state.tier(of: shelf.id) == .sovereign {
            types.formUnion(shelf.pageTypes)
        }
        return types
    }
}

// MARK: - Pact War voices (static per-Talisman flavor; never a model call)
//
// When a Talisman holds one of the real-world doors, it colors how the Book
// speaks through that channel. Pure static catalogs so the war can change the
// app's voice without a Gemma turn.

struct PactWhisper: Equatable {
    let title: String
    let body: String
}

enum PactVoices {
    /// The evening braid whisper, recolored by whoever holds the Whisper Channel.
    static func braidWhisper(controller talismanID: String?) -> PactWhisper {
        switch talismanID {
        case "ember-seal":
            return PactWhisper(title: "Write before you sleep",
                               body: "Today's kept pages are first drafts. The Ember Seal says: finish one sentence only you could write.")
        case "moss-clasp":
            return PactWhisper(title: "Let the day settle",
                               body: "The Moss Clasp keeps the lamp low. Re-read one kept page slowly before you braid.")
        case "tide-glass":
            return PactWhisper(title: "Catch it before it goes",
                               body: "The Tide Glass says the day is already leaving. Braid the one moment that's still warm.")
        case "wind-cipher":
            return PactWhisper(title: "Who was in today with you?",
                               body: "The Wind Cipher pulls a thread: braid the page where someone else's hand showed up.")
        case "dusk-thorn":
            return PactWhisper(title: "Name the hard part",
                               body: "The Dusk Thorn won't smooth it over: braid the page you'd rather skip.")
        default:
            return PactWhisper(title: "Come read your story",
                               body: "I've braided what you kept today into a page. Open it and read the story it made of your day.")
        }
    }

    /// A short epigraph for a real-world door (Health/Weather/Photos), in the
    /// voice of whoever holds it.
    static func doorEpigraph(territoryID: String, controller talismanID: String?) -> String? {
        guard let talismanID else { return nil }
        switch (territoryID, talismanID) {
        case ("integ-health", "ember-seal"): return "Your body is a first draft you get to revise. — the Ember Seal"
        case ("integ-health", "moss-clasp"): return "Listen to it before you instruct it. — the Moss Clasp"
        case ("integ-health", "tide-glass"): return "The body lives in this hour, not the plan. — the Tide Glass"
        case ("integ-health", "wind-cipher"): return "No one tends a body alone. — the Wind Cipher"
        case ("integ-health", "dusk-thorn"): return "Name the ache honestly; it is data, not defeat. — the Dusk Thorn"
        case ("integ-weather", "ember-seal"): return "The sky is yours to read as you choose. — the Ember Seal"
        case ("integ-weather", "moss-clasp"): return "The weather is speaking; be quiet enough to hear it. — the Moss Clasp"
        case ("integ-weather", "tide-glass"): return "This exact sky will never come again. — the Tide Glass"
        case ("integ-weather", "wind-cipher"): return "Everyone under this sky is in your story. — the Wind Cipher"
        case ("integ-weather", "dusk-thorn"): return "Storms are honest. Let this one be. — the Dusk Thorn"
        case ("integ-photos", "ember-seal"): return "You framed this. That choice is the art. — the Ember Seal"
        case ("integ-photos", "moss-clasp"): return "The picture noticed something through you. — the Moss Clasp"
        case ("integ-photos", "tide-glass"): return "A caught second, already gone. Keep it. — the Tide Glass"
        case ("integ-photos", "wind-cipher"): return "Who else is held in this frame? — the Wind Cipher"
        case ("integ-photos", "dusk-thorn"): return "Look at what you almost cropped out. — the Dusk Thorn"
        default: return nil
        }
    }

    /// An extra, unprompted whisper a Talisman sends when it reigns Sovereign
    /// over the Whisper Channel — it acts through the app without being asked.
    static func sovereignWhisper(controller talismanID: String?) -> PactWhisper? {
        switch talismanID {
        case "ember-seal":
            return PactWhisper(title: "Publish something today",
                               body: "The Ember Seal reigns over your whispers now. Make one thing only you would make.")
        case "moss-clasp":
            return PactWhisper(title: "Read before you write",
                               body: "The Moss Clasp holds the channel. Let one thing in before you put anything out.")
        case "tide-glass":
            return PactWhisper(title: "Now, or not at all",
                               body: "The Tide Glass owns the hour. The thing you keep meaning to do — do it in the next ten minutes.")
        case "wind-cipher":
            return PactWhisper(title: "Reach one person",
                               body: "The Wind Cipher rules the channel. Send the message you've been drafting in your head.")
        case "dusk-thorn":
            return PactWhisper(title: "The thing you're avoiding",
                               body: "The Dusk Thorn holds your whispers. You know the one. Look at it for a minute.")
        default:
            return nil
        }
    }

    /// Hour Page framing, recolored by whoever holds the Calendar Door.
    static func hourQuestion(controller talismanID: String?, phase: String) -> String? {
        let after = phase == "after"
        switch talismanID {
        case "ember-seal":
            return after ? "What did you author in that hour?" : "What will you make of this hour — your way?"
        case "moss-clasp":
            return after ? "What did that hour quietly show you?" : "What is this hour asking you to receive?"
        case "tide-glass":
            return after ? "What was the one alive moment in it?" : "What's the first true thing this hour offers?"
        case "wind-cipher":
            return after ? "Who shared that hour, and what did you notice together?" : "Who is this hour with — and what could you ask them?"
        case "dusk-thorn":
            return after ? "What honest thing did that hour surface?" : "What are you bracing for in this hour, really?"
        default:
            return nil
        }
    }
}

// MARK: - Pact War readings (static per-Talisman reading of a real kept page)
//
// When two Talismans contest one of the reader's real days, each reads the SAME
// kept page through its Chapter's philosophy, and the reader rules. Pure static
// templating over the reader's own words — never a model call — so a verdict can
// surface and be ruled while distress-silent and offline, exactly like the rest
// of the war.
enum PactReadings {
    /// A short clip of the reader's own words, for embedding in a reading.
    static func clip(_ text: String, max: Int = 90) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "this kept page" }
        if trimmed.count <= max { return "“\(trimmed)”" }
        let cut = trimmed.prefix(max).trimmingCharacters(in: .whitespaces)
        return "“\(cut)…”"
    }

    /// The Chapter's reading of a kept page, in its Talisman's voice. Built from
    /// the Chapter philosophy (Emberheart authors / Mossbloom receives / Tidecrest
    /// dwells in the moment / Riddlewind co-authors / Duskthorn keeps the friction).
    static func reading(talismanID: String, pageText: String) -> String {
        let it = clip(pageText)
        switch talismanID {
        case "ember-seal":
            return "You authored \(it). Not the world — you. Read it as proof you hold the pen, and the day bends to whoever writes it."
        case "moss-clasp":
            return "Something larger moved through \(it). You didn't make this happen so much as let it. Read it as the world writing a line through you."
        case "tide-glass":
            return "\(it) needs no arc and no lesson. It was whole the instant it happened. Read it as a moment, complete, asking nothing more of you."
        case "wind-cipher":
            return "You weren't alone in \(it). Another hand is in this page. Read it as something the two of you wrote together, not a thing you did alone."
        case "dusk-thorn":
            return "Don't smooth over \(it). The hard edge here is the plot, not the flaw. Read it as the friction that keeps the day from being forgettable."
        default:
            return "A reading of \(it)."
        }
    }

    /// The one-line claim a Talisman stands on when it asks for the verdict.
    static func claimLine(talismanID: String) -> String {
        AcademyChapterRegistry.chapter(forTalismanID: talismanID)?.philosophy
            ?? "This day means what you decide it means."
    }
}

// MARK: - Pact War errands (a Talisman sends the reader into the real day)
//
// A talisman that already holds a foothold sends the reader out to *do* something
// in the real day, paid back in a field report — the Fae's "noticing as payment"
// move, but each Talisman wants a different kind of noticing, loaded with its
// Chapter's philosophy. Static catalog; the reward is Control Belief, applied by
// `PactWarEngine.deliverErrand`.
enum PactErrands {
    static let offerGapHours = 20
    static let paymentWindowHours = 72
    static let controlReward = 8

    struct Template: Equatable {
        let openingLine: String
        let terms: String
    }

    static func template(talismanID: String) -> Template {
        switch talismanID {
        case "ember-seal":
            return Template(
                openingLine: "The Ember Seal sets a task before it presses its claim further.",
                terms: "Author one thing today that wouldn't have happened without you — then write the single sentence that proves you did.")
        case "moss-clasp":
            return Template(
                openingLine: "The Moss Clasp asks for stillness before it takes more ground.",
                terms: "Sit somewhere quiet and let the world write one sentence through you. Report exactly what it said.")
        case "tide-glass":
            return Template(
                openingLine: "The Tide Glass wants proof that the present is enough.",
                terms: "Catch one thing today that takes you completely off guard, and report it before the moment is gone.")
        case "wind-cipher":
            return Template(
                openingLine: "The Wind Cipher won't move without another hand in the page.",
                terms: "Ask someone near you what they noticed today, and report what the two of you saw.")
        case "dusk-thorn":
            return Template(
                openingLine: "The Dusk Thorn asks for the honest thing, not the easy one.",
                terms: "Write the sentence you've been avoiding, and report that you wrote it.")
        default:
            return Template(openingLine: "A Talisman sets a task.", terms: "Notice one true thing today and report it.")
        }
    }

    /// The talisman's spoken acknowledgement when the errand is delivered.
    static func response(talismanID: String) -> String {
        switch talismanID {
        case "ember-seal": return "The Ember Seal takes the page from your hand and reads it twice. “Authored,” it says — and the shelf leans your way."
        case "moss-clasp": return "The Moss Clasp goes quiet, the way a room does when someone is finally listening. The ground settles beneath its philosophy."
        case "tide-glass": return "The Tide Glass laughs — a small, surprised sound — and the moment is already gone. It has exactly what it wanted."
        case "wind-cipher": return "The Wind Cipher rearranges itself around the second voice in your report. “Together,” it agrees, and gains."
        case "dusk-thorn": return "The Dusk Thorn does not soften. “Good,” it says. “That cost you something.” And it holds more of the shelf for it."
        default: return "The Talisman accepts your noticing and presses its claim."
        }
    }
}

extension PactWarEngine {
    /// Offer one errand from a talisman that already holds a territory at
    /// Influenced+ (a real foothold), if the reader has no open errand and the
    /// cadence allows. Pure local; the reader pays it later with a field report.
    @discardableResult
    static func offerErrand(into state: inout PactWarState, now: Date = Date()) -> PactErrand? {
        guard state.openErrand == nil else { return nil }
        if let last = state.errands.map(\.offeredAt).max(),
           now.timeIntervalSince(last) < Double(PactErrands.offerGapHours) * 3_600 { return nil }

        let candidates = PactTerritoryRegistry.all.compactMap { territory -> (String, String)? in
            guard let holder = state.controller(of: territory.id),
                  state.tier(of: territory.id) >= .influenced else { return nil }
            return (holder, territory.id)
        }
        guard !candidates.isEmpty else { return nil }

        let seed = abs("\(BookDay.id(for: now))-pact-errand".stableHash)
        let pick = candidates[seed % candidates.count]
        let template = PactErrands.template(talismanID: pick.0)
        let errand = PactErrand(
            id: "pact-errand-\(pick.1)-\(pick.0)-\(BookDay.id(for: now))",
            talismanID: pick.0,
            territoryID: pick.1,
            openingLine: template.openingLine,
            terms: template.terms,
            offeredAt: now,
            deadline: now.addingTimeInterval(Double(PactErrands.paymentWindowHours) * 3_600),
            status: .owed,
            fieldReport: nil,
            talismanResponse: nil,
            deliveredAt: nil
        )
        guard !state.errands.contains(where: { $0.id == errand.id }) else { return nil }
        state.errands = (state.errands + [errand]).suffix(8).map { $0 }
        return errand
    }

    /// Pay an errand with a real field report: the talisman gains Control Belief on
    /// its territory and may seize it or cross into Sovereign. Returns whether a new
    /// Sovereign crossing was queued (so the caller can front a goblin bargain).
    @discardableResult
    static func deliverErrand(errandID: String, report: String, into state: inout PactWarState, now: Date = Date()) -> Bool {
        guard let index = state.errands.firstIndex(where: { $0.id == errandID }) else { return false }
        let talismanID = state.errands[index].talismanID
        let territoryID = state.errands[index].territoryID
        state.errands[index].status = .delivered
        state.errands[index].fieldReport = report
        state.errands[index].talismanResponse = PactErrands.response(talismanID: talismanID)
        state.errands[index].deliveredAt = now

        let before = state
        state.adjust(talismanID, territoryID, by: PactErrands.controlReward)
        let name = AcademyChapterRegistry.chapter(forTalismanID: talismanID)?.talismanName ?? talismanID
        let territoryName = PactTerritoryRegistry.territory(id: territoryID)?.name ?? "its territory"
        let record = PactActionRecord(
            id: "\(territoryID)-\(talismanID)-\(Int(now.timeIntervalSince1970))-errand",
            talismanID: talismanID, territoryID: territoryID, kind: .errand, at: now,
            line: "\(name) gains \(territoryName) — you ran its errand."
        )
        state.log = ([record] + state.log).prefix(24).map { $0 }
        return detectCrossings(before: before, into: &state, now: now)
    }

    /// Mark any owed errand past its deadline as lapsed. Returns the ids that lapsed.
    @discardableResult
    static func sweepErrandLapses(into state: inout PactWarState, now: Date = Date()) -> [String] {
        var lapsed: [String] = []
        for index in state.errands.indices where state.errands[index].status == .owed {
            guard now > state.errands[index].deadline else { continue }
            state.errands[index].status = .lapsed
            lapsed.append(state.errands[index].id)
        }
        return lapsed
    }
}

extension PactWarEffects {
    /// Annotate a surfaced capture page with the framing of the Talisman that
    /// holds its shelf, so the sheet can speak in that Chapter's hand.
    static func framed(_ page: SurfacePage, state: PactWarState) -> SurfacePage {
        var payload = page.payload
        var changed = false

        // Shelf framing: a controlled shelf rewrites its capture pages' prompt.
        if let story = shelfStory(for: page.type, state: state) {
            payload.metadata["pactShelfStory"] = story.line
            payload.metadata["pactShelfTalisman"] = story.talisman
            payload.metadata["pactShelfTier"] = story.tier.label
            changed = true
        }

        // Shelf framing: a controlled shelf rewrites its capture pages' prompt.
        if page.intent == .capture,
           let framing = framing(for: page.type, state: state),
           let shelf = PactTerritoryRegistry.shelf(governing: page.type),
           let controller = state.controller(of: shelf.id),
           let chapter = AcademyChapterRegistry.chapter(forTalismanID: controller) {
            payload.metadata["pactFraming"] = framing
            payload.metadata["pactController"] = chapter.name
            payload.metadata["pactTalisman"] = chapter.talismanName
            changed = true
        }

        // Door epigraph: a controlled real-world door speaks over its pages.
        if let epigraph = doorEpigraph(for: page.type, state: state) {
            payload.metadata["pactDoorEpigraph"] = epigraph.line
            payload.metadata["pactDoorTalisman"] = epigraph.talisman
            changed = true
        }

        guard changed else { return page }
        return SurfacePage(
            id: page.id,
            type: page.type,
            sourceID: page.sourceID,
            intent: page.intent,
            renderStyle: page.renderStyle,
            score: page.score,
            reason: page.reason,
            prompt: page.prompt,
            detail: page.detail,
            payload: payload
        )
    }
}

// MARK: - The Almanac (the living Wheel of the Year + lunar esbats)
//
// The Academy breathes with the real world. The Almanac knows, for a date and
// hemisphere, which celebrations are alive: the eight pagan Sabbats, the Full
// and New Moon esbats, and the year's meteor showers. Pure local astronomy and
// date logic — never a model call. Celebrations bend Belief, Routine, the
// Fae, and the Pact War, and the world works on the reader whether noticed or
// not. See lore/seasonal-calendar.md.

enum Hemisphere: String, Codable, Equatable {
    case northern, southern
    static func from(latitude: Double?) -> Hemisphere {
        (latitude ?? 45) < 0 ? .southern : .northern
    }
}

enum CelebrationKind: String, Codable, Equatable {
    case sabbat, esbat, shower, eclipse
}

struct Celebration: Identifiable, Equatable {
    let id: String
    let kind: CelebrationKind
    let commonName: String       // "Full Moon", "Samhain"
    let academyTitle: String     // "The Luminous Gathering"
    let blurb: String            // prose flavor for the page body
    let invitationTitle: String  // the special-event prompt heading
    let invitation: String       // what to notice / do
    let beliefBonus: Int
    let greyShift: Int           // seasonal grey atmosphere; never evidence of the reader's Rut
    let symbolName: String
    let accent: String           // palette hint: amber/green/gold/violet/candle/slate
    let priority: Int            // higher wins when several are active
}

private struct SabbatDef {
    let id: String
    let commonName: String
    let academyTitle: String
    let blurb: String
    let invitationTitle: String
    let invitation: String
    let beliefBonus: Int
    let greyShift: Int
    let symbolName: String
    let accent: String
    // Inclusive calendar window in the NORTHERN hemisphere.
    let startMonth: Int; let startDay: Int
    let endMonth: Int; let endDay: Int
}

enum Almanac {
    // The eight sabbats in calendar order (northern hemisphere windows).
    private static let wheel: [SabbatDef] = [
        SabbatDef(id: "imbolc", commonName: "Imbolc", academyTitle: "The First Stir",
                  blurb: "Under the snow, something has decided to live. The Library's oldest seeds turn over in their drawers.",
                  invitationTitle: "The First Stir",
                  invitation: "Find the first small sign that the dark is turning — a longer evening, a bud, a thaw. Keep it in one sentence.",
                  beliefBonus: 3, greyShift: -1, symbolName: "snowflake", accent: "candle",
                  startMonth: 2, startDay: 1, endMonth: 2, endDay: 2),
        SabbatDef(id: "ostara", commonName: "Ostara", academyTitle: "The Rebalancing",
                  blurb: "The Library reorganizes itself overnight. Books migrate. Light and dark stand equal, and the whole school exhales.",
                  invitationTitle: "The Rebalancing",
                  invitation: "Name one thing coming into balance for you, and one still tipping. The Compass glows in all four directions today.",
                  beliefBonus: 2, greyShift: 0, symbolName: "circle.lefthalf.filled", accent: "green",
                  startMonth: 3, startDay: 19, endMonth: 3, endDay: 21),
        SabbatDef(id: "beltane", commonName: "Beltane", academyTitle: "The Greenfire",
                  blurb: "The courtyard is reckless with bloom. Vines climb the shelves with tiny books for leaves. The bees in the Compass Rose are helpful and a little drunk.",
                  invitationTitle: "The Greenfire",
                  invitation: "Find the most alive green thing near you and describe it as if it could hear you. (It can.)",
                  beliefBonus: 4, greyShift: -1, symbolName: "leaf.fill", accent: "green",
                  startMonth: 5, startDay: 1, endMonth: 5, endDay: 1),
        SabbatDef(id: "litha", commonName: "Litha", academyTitle: "The Longest Day",
                  blurb: "The Library stays open all night. Lanterns float. Sentences run long and golden and sun-drunk.",
                  invitationTitle: "The Longest Day",
                  invitation: "Stay up toward the light — dusk or dawn — and keep one sentence about what the long day left you.",
                  beliefBonus: 4, greyShift: -2, symbolName: "sun.max.fill", accent: "gold",
                  startMonth: 6, startDay: 20, endMonth: 6, endDay: 22),
        SabbatDef(id: "lughnasadh", commonName: "Lughnasadh", academyTitle: "The First Harvest",
                  blurb: "The first grain comes in. Professors look proud and tired. The kitchens smell of bread that wasn't there an hour ago.",
                  invitationTitle: "The First Harvest",
                  invitation: "Name one thing you made or gathered this season — however small. Keep it like a loaf set on a sill.",
                  beliefBonus: 3, greyShift: 0, symbolName: "leaf", accent: "gold",
                  startMonth: 8, startDay: 1, endMonth: 8, endDay: 2),
        SabbatDef(id: "mabon", commonName: "Mabon", academyTitle: "The Second Rebalancing",
                  blurb: "Balance again, but golden and grateful. Books settle into their winter homes. Students share what they've learned.",
                  invitationTitle: "The Second Rebalancing",
                  invitation: "Name one thing you're grateful you kept, and one you're ready to let settle into the dark.",
                  beliefBonus: 3, greyShift: 0, symbolName: "circle.righthalf.filled", accent: "amber",
                  startMonth: 9, startDay: 21, endMonth: 9, endDay: 23),
        SabbatDef(id: "samhain", commonName: "Samhain", academyTitle: "The Thinning",
                  blurb: "The door between the kept and the lost stands ajar. The Book remembers more than usual tonight, and is gentler about it.",
                  invitationTitle: "The Thinning",
                  invitation: "Name someone or something you've lost, and one thing it left in your keeping. The veil is thin; be honest, be kind.",
                  beliefBonus: 5, greyShift: 1, symbolName: "flame", accent: "amber",
                  startMonth: 10, startDay: 31, endMonth: 11, endDay: 1),
        SabbatDef(id: "yule", commonName: "Yule", academyTitle: "The Darkest Class",
                  blurb: "Held by candlelight. The longest night, taught honestly. Everyone speaks softly; the fireplaces are crowded.",
                  invitationTitle: "The Darkest Class",
                  invitation: "Name one small thing that survives the longest night with you. Keep it where the candle can reach it.",
                  beliefBonus: 4, greyShift: 1, symbolName: "moon.stars.fill", accent: "candle",
                  startMonth: 12, startDay: 20, endMonth: 12, endDay: 23)
    ]

    private static func dayOfYearOrdinal(month: Int, day: Int) -> Int { month * 100 + day }

    private static func northernSabbat(on date: Date, calendar: Calendar) -> SabbatDef? {
        let comps = calendar.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return nil }
        let value = dayOfYearOrdinal(month: m, day: d)
        return wheel.first { sabbat in
            let start = dayOfYearOrdinal(month: sabbat.startMonth, day: sabbat.startDay)
            let end = dayOfYearOrdinal(month: sabbat.endMonth, day: sabbat.endDay)
            return value >= start && value <= end
        }
    }

    /// The active sabbat for a date, mapped for hemisphere (southern observes the
    /// opposite point of the wheel on the same calendar date).
    static func activeSabbat(on date: Date = Date(), hemisphere: Hemisphere = .northern, calendar: Calendar = .current) -> Celebration? {
        guard let northern = northernSabbat(on: date, calendar: calendar),
              let index = wheel.firstIndex(where: { $0.id == northern.id }) else { return nil }
        let def = hemisphere == .southern ? wheel[(index + 4) % wheel.count] : northern
        return Celebration(
            id: "sabbat-\(def.id)",
            kind: .sabbat,
            commonName: def.commonName,
            academyTitle: def.academyTitle,
            blurb: def.blurb,
            invitationTitle: def.invitationTitle,
            invitation: def.invitation,
            beliefBonus: def.beliefBonus,
            greyShift: def.greyShift,
            symbolName: def.symbolName,
            accent: def.accent,
            priority: 100
        )
    }

    /// The active lunar esbat (Full or New Moon), if the moon is near either edge.
    static func activeEsbat(on date: Date = Date()) -> Celebration? {
        let phase = MoonPhaseCalendar.phase(on: date)
        if phase.illuminatedFraction >= 0.96 {
            return Celebration(
                id: "esbat-full", kind: .esbat, commonName: "Full Moon",
                academyTitle: "The Luminous Gathering",
                blurb: "Classes are cancelled after sunset. Everyone gathers in the courtyard to read by moonlight. Strangers talk to each other; the sentences glow.",
                invitationTitle: "Moonwrite",
                invitation: "Write your one-sentence souvenir by the light of the full moon. It will glow on the page.",
                beliefBonus: 5, greyShift: -2, symbolName: "moonphase.full.moon", accent: "violet", priority: 80
            )
        }
        if phase.illuminatedFraction <= 0.04 {
            return Celebration(
                id: "esbat-new", kind: .esbat, commonName: "New Moon",
                academyTitle: "The Quiet Hours",
                blurb: "The Academy goes contemplative-dark. Candles only. The words hold their breath.",
                invitationTitle: "The Listening",
                invitation: "Sit in real silence for two minutes, then keep one sentence about what you heard underneath it.",
                beliefBonus: 3, greyShift: 1, symbolName: "moonphase.new.moon", accent: "slate", priority: 70
            )
        }
        return nil
    }

    static func isMoonwriteActive(on date: Date = Date()) -> Bool {
        activeEsbat(on: date)?.id == "esbat-full"
    }

    /// Meteor showers, by their real date windows.
    static func activeShower(on date: Date = Date(), calendar: Calendar = .current) -> Celebration? {
        let comps = calendar.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return nil }
        let value = m * 100 + d
        if (811...813).contains(value) {
            return Celebration(id: "shower-perseids", kind: .shower, commonName: "The Perseids",
                               academyTitle: "The Falling Letters",
                               blurb: "The ceiling of the Library goes briefly transparent. You can see real constellations through the stone.",
                               invitationTitle: "The Falling Letters",
                               invitation: "Catch one falling star — real or remembered — and keep the wish you made on it.",
                               beliefBonus: 3, greyShift: -1, symbolName: "sparkles", accent: "violet", priority: 50)
        }
        if (1213...1215).contains(value) {
            return Celebration(id: "shower-geminids", kind: .shower, commonName: "The Geminids",
                               academyTitle: "The Winter Stars",
                               blurb: "Like the Perseids but colder. Hot chocolate appears in everyone's hands, unasked.",
                               invitationTitle: "The Winter Stars",
                               invitation: "Find one bright thing in the cold dark and keep the wish it pulled out of you.",
                               beliefBonus: 3, greyShift: -1, symbolName: "sparkles", accent: "slate", priority: 50)
        }
        return nil
    }

    /// Everything alive on a date, strongest first.
    static func celebrations(on date: Date = Date(), hemisphere: Hemisphere = .northern, calendar: Calendar = .current) -> [Celebration] {
        [activeSabbat(on: date, hemisphere: hemisphere, calendar: calendar),
         activeEsbat(on: date),
         activeShower(on: date, calendar: calendar)]
            .compactMap { $0 }
            .sorted { $0.priority > $1.priority }
    }

    /// The single headline celebration for a date, if any.
    static func active(on date: Date = Date(), hemisphere: Hemisphere = .northern, calendar: Calendar = .current) -> Celebration? {
        celebrations(on: date, hemisphere: hemisphere, calendar: calendar).first
    }

    /// Combined effect of every active celebration on Routine's grey.
    static func greyShift(on date: Date = Date(), hemisphere: Hemisphere = .northern, calendar: Calendar = .current) -> Int {
        celebrations(on: date, hemisphere: hemisphere, calendar: calendar).reduce(0) { $0 + $1.greyShift }
    }

    /// Atmosphere: each celebration leans the feed toward thematically-fitting
    /// page kinds (a curator nudge, never a veto).
    static func surfaceBoosts(on date: Date = Date(), hemisphere: Hemisphere = .northern, calendar: Calendar = .current) -> [BookPageType: Int] {
        var boosts: [BookPageType: Int] = [:]
        func add(_ type: BookPageType, _ amount: Int) { boosts[type, default: 0] += amount }
        for celebration in celebrations(on: date, hemisphere: hemisphere, calendar: calendar) {
            switch celebration.id {
            case "esbat-full":
                add(.souvenir, 8); add(.diary, 4); add(.todaysSky, 6)  // Moonwrite
            case "esbat-new":
                add(.rest, 8); add(.mood, 4); add(.todaysSky, 4)       // The Listening
            case "sabbat-samhain":
                add(.bookRemembered, 10); add(.inkrestOfficeHours, 4)  // the returning / the lost
            case "sabbat-beltane":
                add(.letter, 8); add(.illustration, 4); add(.wonderCompass, 4)  // connection
            case "sabbat-imbolc":
                add(.diary, 6); add(.mood, 4)                // first stirrings
            case "sabbat-litha":
                add(.wonderCompass, 8); add(.anchor, 6)      // out in the long day
            case "sabbat-lughnasadh", "sabbat-mabon":
                add(.bookOfYou, 6); add(.souvenir, 4)        // harvest / gratitude
            case "sabbat-ostara":
                add(.aboutYou, 4); add(.wonderCompass, 4)    // rebalancing
            case "sabbat-yule":
                add(.rest, 6); add(.diary, 4)                // the darkest, kept warm
            case "shower-perseids", "shower-geminids":
                add(.wonderCompass, 6); add(.souvenir, 4); add(.todaysSky, 8)  // make a wish
            default:
                break
            }
        }
        return boosts
    }
}

// MARK: - Today's Sky (the living almanac of the night overhead)
//
// The Academy shares its window. For a date and hemisphere, the sky reading
// knows the Moon's phase and the sign it drifts through, the Sun's sign and
// whether the light is lengthening or drawing in, and the nearest celestial
// event worth looking up for. Pure local astronomy — low-precision but honest,
// "close enough for a storybook" (within a degree or two), no network or
// precise location required. See lore/seasonal-calendar.md.

struct ZodiacSign: Equatable {
    let name: String
    let glyph: String       // ♈︎ etc — drawn as text
    let element: String     // fire / earth / air / water
    let symbolName: String  // an SF Symbol standing in for the element
}

enum Zodiac {
    // Tropical signs in ecliptic-longitude order, Aries beginning at 0°.
    static let signs: [ZodiacSign] = [
        ZodiacSign(name: "Aries", glyph: "♈︎", element: "fire", symbolName: "flame"),
        ZodiacSign(name: "Taurus", glyph: "♉︎", element: "earth", symbolName: "leaf"),
        ZodiacSign(name: "Gemini", glyph: "♊︎", element: "air", symbolName: "wind"),
        ZodiacSign(name: "Cancer", glyph: "♋︎", element: "water", symbolName: "drop"),
        ZodiacSign(name: "Leo", glyph: "♌︎", element: "fire", symbolName: "flame"),
        ZodiacSign(name: "Virgo", glyph: "♍︎", element: "earth", symbolName: "leaf"),
        ZodiacSign(name: "Libra", glyph: "♎︎", element: "air", symbolName: "wind"),
        ZodiacSign(name: "Scorpio", glyph: "♏︎", element: "water", symbolName: "drop"),
        ZodiacSign(name: "Sagittarius", glyph: "♐︎", element: "fire", symbolName: "flame"),
        ZodiacSign(name: "Capricorn", glyph: "♑︎", element: "earth", symbolName: "leaf"),
        ZodiacSign(name: "Aquarius", glyph: "♒︎", element: "air", symbolName: "wind"),
        ZodiacSign(name: "Pisces", glyph: "♓︎", element: "water", symbolName: "drop")
    ]

    static func sign(forEclipticLongitude longitude: Double) -> ZodiacSign {
        let normalized = ((longitude.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        return signs[min(11, Int(normalized / 30))]
    }
}

/// Low-precision ecliptic longitudes for the Sun and Moon. Good to a degree or
/// two — plenty for naming the sign each one stands in.
enum SkyEphemeris {
    static let j2000: Date = {
        var c = DateComponents()
        c.year = 2000; c.month = 1; c.day = 1; c.hour = 12; c.minute = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date(timeIntervalSince1970: 946_728_000)
    }()

    static func daysSinceJ2000(_ date: Date) -> Double {
        date.timeIntervalSince(j2000) / 86_400
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    static func sunLongitude(on date: Date) -> Double {
        let d = daysSinceJ2000(date)
        let g = radians(357.529 + 0.985_600_28 * d)          // mean anomaly
        let q = 280.459 + 0.985_647_36 * d                   // mean longitude
        return q + 1.915 * sin(g) + 0.020 * sin(2 * g)       // apparent longitude
    }

    static func moonLongitude(on date: Date) -> Double {
        let d = daysSinceJ2000(date)
        let l = 218.316 + 13.176_396 * d                     // mean longitude
        let m = radians(134.963 + 13.064_993 * d)            // mean anomaly
        return l + 6.289 * sin(m)                            // dominant term only
    }
}

enum LightTrend: String, Equatable {
    case lengthening, shortening, nearBalance

    var phrase: String {
        switch self {
        case .lengthening: return "the light is lengthening, a little more kept each evening"
        case .shortening: return "the light is drawing in, the dark gaining a margin a night"
        case .nearBalance: return "light and dark stand nearly equal, the year holding its breath"
        }
    }

    var symbolName: String {
        switch self {
        case .lengthening: return "sun.max"
        case .shortening: return "sun.haze"
        case .nearBalance: return "circle.lefthalf.filled"
        }
    }
}

/// A single celestial event the reader could look up for tonight or soon.
struct SkyEvent: Equatable {
    let kind: String     // "full moon", "new moon", "meteor shower"
    let name: String     // "the Full Moon", "the Perseids"
    let date: Date
    let daysAway: Int
    let line: String     // "in 3 nights" etc, woven into prose
    let symbolName: String
}

/// Everything the Book reads in the sky on a given night.
struct SkyReading: Equatable {
    let date: Date
    let hemisphere: Hemisphere
    let moon: MoonPhase
    let moonSign: ZodiacSign
    let sunSign: ZodiacSign
    let lightTrend: LightTrend
    let nextEvent: SkyEvent
    let activeShower: Celebration?   // a shower peaking now, if any
    let openingLine: String
    let notes: [String]
}

enum SkyAlmanac {
    private struct ShowerPeak { let name: String; let month: Int; let day: Int }
    private static let showerPeaks: [ShowerPeak] = [
        ShowerPeak(name: "the Quadrantids", month: 1, day: 3),
        ShowerPeak(name: "the Lyrids", month: 4, day: 22),
        ShowerPeak(name: "the Eta Aquariids", month: 5, day: 6),
        ShowerPeak(name: "the Perseids", month: 8, day: 12),
        ShowerPeak(name: "the Orionids", month: 10, day: 21),
        ShowerPeak(name: "the Leonids", month: 11, day: 17),
        ShowerPeak(name: "the Geminids", month: 12, day: 13)
    ]

    static func lightTrend(on date: Date, hemisphere: Hemisphere) -> LightTrend {
        let lon = ((SkyEphemeris.sunLongitude(on: date).truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        // Distance to the two equinox points (0° Aries, 180° Libra).
        let toAries = min(lon, 360 - lon)
        let toLibra = abs(lon - 180)
        if min(toAries, toLibra) < 6 { return .nearBalance }
        // In the north the days lengthen from the winter solstice (≈270°) through
        // spring to the summer solstice (≈90°); the south is the mirror.
        let northernLengthening = (lon >= 270 || lon < 90)
        let lengthening = hemisphere == .northern ? northernLengthening : !northernLengthening
        return lengthening ? .lengthening : .shortening
    }

    private static func nextShowerPeak(after date: Date, calendar: Calendar) -> SkyEvent {
        let startOfToday = calendar.startOfDay(for: date)
        var best: (date: Date, peak: ShowerPeak)?
        for yearOffset in 0...1 {
            let year = calendar.component(.year, from: date) + yearOffset
            for peak in showerPeaks {
                var c = DateComponents()
                c.year = year; c.month = peak.month; c.day = peak.day
                guard let peakDate = calendar.date(from: c) else { continue }
                if peakDate >= startOfToday, best == nil || peakDate < best!.date {
                    best = (peakDate, peak)
                }
            }
        }
        let resolved = best ?? (calendar.date(byAdding: .day, value: 30, to: date) ?? date, showerPeaks[3])
        let days = max(0, calendar.dateComponents([.day], from: startOfToday, to: resolved.date).day ?? 0)
        return SkyEvent(kind: "meteor shower", name: resolved.peak.name, date: resolved.date,
                        daysAway: days, line: nightsAway(days), symbolName: "sparkles")
    }

    private static func nightsAway(_ days: Int) -> String {
        switch days {
        case 0: return "tonight"
        case 1: return "tomorrow night"
        default: return "in \(days) nights"
        }
    }

    /// The soonest sky event worth looking up for: the next full moon, the next
    /// new moon, or the next meteor shower peak — whichever comes first.
    static func nextEvent(on date: Date, calendar: Calendar = .current) -> SkyEvent {
        let startOfToday = calendar.startOfDay(for: date)
        let full = MoonPhaseCalendar.nextFullMoon(after: date, calendar: calendar)
        let new = MoonPhaseCalendar.nextNewMoon(after: date, calendar: calendar)
        let shower = nextShowerPeak(after: date, calendar: calendar)

        let fullDays = max(0, calendar.dateComponents([.day], from: startOfToday, to: full).day ?? 0)
        let newDays = max(0, calendar.dateComponents([.day], from: startOfToday, to: new).day ?? 0)

        let fullEvent = SkyEvent(kind: "full moon", name: "the Full Moon", date: full,
                                 daysAway: fullDays, line: nightsAway(fullDays),
                                 symbolName: "moonphase.full.moon")
        let newEvent = SkyEvent(kind: "new moon", name: "the New Moon", date: new,
                                daysAway: newDays, line: nightsAway(newDays),
                                symbolName: "moonphase.new.moon")

        return [fullEvent, newEvent, shower].min(by: { $0.date < $1.date }) ?? shower
    }

    private static let openers: [String] = [
        "I turn a page toward the window.",
        "Look up — the Library shares its ceiling tonight.",
        "The Academy keeps a window open for you.",
        "Tonight the margins reach all the way to the stars.",
        "I read the sky aloud."
    ]

    static func reading(on date: Date = Date(), hemisphere: Hemisphere = .northern, calendar: Calendar = .current) -> SkyReading {
        let moon = MoonPhaseCalendar.phase(on: date)
        let moonSign = Zodiac.sign(forEclipticLongitude: SkyEphemeris.moonLongitude(on: date))
        let sunSign = Zodiac.sign(forEclipticLongitude: SkyEphemeris.sunLongitude(on: date))
        let trend = lightTrend(on: date, hemisphere: hemisphere)
        let event = nextEvent(on: date, calendar: calendar)
        let shower = Almanac.activeShower(on: date, calendar: calendar)

        let dayIndex = Int(date.timeIntervalSince1970 / 86_400)
        let opener = openers[((dayIndex % openers.count) + openers.count) % openers.count]

        let pct = Int((moon.illuminatedFraction * 100).rounded())
        var notes: [String] = [
            "The Moon is \(moon.name.lowercased()) — \(pct)% lit — drifting through \(moonSign.name) (\(moonSign.element)). \(moon.enchantedLine)",
            "The Sun keeps court in \(sunSign.name); \(trend.phrase).",
            "Next overhead: \(event.name), \(event.line)."
        ]
        if let shower {
            notes.append("\(shower.commonName) are falling now — \(shower.invitation)")
        }

        return SkyReading(
            date: date, hemisphere: hemisphere, moon: moon, moonSign: moonSign,
            sunSign: sunSign, lightTrend: trend, nextEvent: event, activeShower: shower,
            openingLine: opener, notes: notes
        )
    }
}

// MARK: - The Book's returning greeting
//
// Each time a returning reader opens the app (after the opening movie, not the
// first run), the Book greets them by name with a rotating opener and one
// remembered line. Live world-state belongs in the hero subtitle; this overlay
// is for being known, welcomed, and gently invited back into noticing.

struct BookGreetingContext: Equatable {
    var name: String
    var rememberedFactLines: [String]
    var recentKeptLines: [String]
    var keptPageCount: Int
    var quietDays: Int
    var seed: Int
    var relationship: BookRelationshipSnapshot
    var interior: BookInteriorState

    init(
        name: String,
        rememberedFactLines: [String] = [],
        recentKeptLines: [String] = [],
        keptPageCount: Int = 0,
        quietDays: Int = 0,
        seed: Int = 0,
        relationship: BookRelationshipSnapshot = .firstOpening,
        interior: BookInteriorState = .unawakened
    ) {
        self.name = name
        self.rememberedFactLines = rememberedFactLines
        self.recentKeptLines = recentKeptLines
        self.keptPageCount = keptPageCount
        self.quietDays = quietDays
        self.seed = seed
        self.relationship = relationship
        self.interior = interior
    }
}

struct BookGreeting: Equatable {
    var greeting: String   // "Hello, bj — I'm so glad you're back."
    var line: String       // one remembered line / affirmation / wonder prompt
}

struct WorldChargeContext: Equatable {
    var keptToday: Int
    var availablePages: Int
    var resurfacedPages: Int
    var weatherPhrase: String?
    var enchantedWeatherLine: String?
    var moonName: String
    var celebrationTitle: String?
    var greyLevel: Int
    var hour: Int
    var seed: Int
    var openBargainFae: String?
    var pactLine: String?
    var tunedStationTitle: String?
    var recentPageTypes: [BookPageType]
    var hasBookOfYou: Bool
    var quietDays: Int
    var ascendantTalismanName: String?
    var boundTalismanName: String?
    var castActionLine: String?
    var relationshipLine: String?
    var beliefMovementLine: String?
    var readerBelief: Int
    var bookRelationship: BookRelationshipSnapshot
    var bookInterior: BookInteriorState

    init(
        keptToday: Int = 0,
        availablePages: Int = 0,
        resurfacedPages: Int = 0,
        weatherPhrase: String? = nil,
        enchantedWeatherLine: String? = nil,
        moonName: String,
        celebrationTitle: String? = nil,
        greyLevel: Int = 0,
        hour: Int = 12,
        seed: Int = 0,
        openBargainFae: String? = nil,
        pactLine: String? = nil,
        tunedStationTitle: String? = nil,
        recentPageTypes: [BookPageType] = [],
        hasBookOfYou: Bool = false,
        quietDays: Int = 0,
        ascendantTalismanName: String? = nil,
        boundTalismanName: String? = nil,
        castActionLine: String? = nil,
        relationshipLine: String? = nil,
        beliefMovementLine: String? = nil,
        readerBelief: Int = 0,
        bookRelationship: BookRelationshipSnapshot = .firstOpening,
        bookInterior: BookInteriorState = .unawakened
    ) {
        self.keptToday = keptToday
        self.availablePages = availablePages
        self.resurfacedPages = resurfacedPages
        self.weatherPhrase = weatherPhrase
        self.enchantedWeatherLine = enchantedWeatherLine
        self.moonName = moonName
        self.celebrationTitle = celebrationTitle
        self.greyLevel = greyLevel
        self.hour = hour
        self.seed = seed
        self.openBargainFae = openBargainFae
        self.pactLine = pactLine
        self.tunedStationTitle = tunedStationTitle
        self.recentPageTypes = recentPageTypes
        self.hasBookOfYou = hasBookOfYou
        self.quietDays = quietDays
        self.ascendantTalismanName = ascendantTalismanName
        self.boundTalismanName = boundTalismanName
        self.castActionLine = castActionLine
        self.relationshipLine = relationshipLine
        self.beliefMovementLine = beliefMovementLine
        self.readerBelief = readerBelief
        self.bookRelationship = bookRelationship
        self.bookInterior = bookInterior
    }
}

struct BookOpenVoice: Equatable {
    var heroLine: String
    var epigraph: String
    var factTitle: String
    var factLine: String
    var encouragement: String
    var quip: String
    var edgeLine: String
    var knockLine: String
}

enum WorldChargeComposer {
    static func compose(_ context: WorldChargeContext) -> String {
        if let interiorLine = BookInteriorVoice.homeLine(for: context.bookInterior, seed: context.seed) {
            return interiorLine
        }
        if let relationshipLine = BookRelationshipVoice.openingLine(for: context.bookRelationship) {
            return relationshipLine
        }
        let liveLines = [
            context.celebrationTitle?.nonEmpty.map { "The Wheel is keeping \($0). Let one ordinary thing answer it." },
            context.relationshipLine?.nonEmpty.map { "The Loom moved: \($0.bookPreviewSentenceLimit(1))" },
            context.castActionLine?.nonEmpty.map { "The cast kept acting offscreen: \($0.bookPreviewSentenceLimit(1))" },
            context.beliefMovementLine?.nonEmpty.map { "Belief shifted in the margins: \($0.bookPreviewSentenceLimit(1))" },
            context.ascendantTalismanName?.nonEmpty.map { "\($0) is leaning on the binding today. The Pages may answer differently." },
            context.tunedStationTitle?.nonEmpty.map { "\($0) is still in the paper. Let the next Page keep rhythm." },
            context.enchantedWeatherLine?.nonEmpty.map { "The sky left a margin note: \($0.bookPreviewSentenceLimit(1))" },
            context.weatherPhrase?.nonEmpty.map { weatherLine(for: $0, seed: context.seed) },
            context.greyLevel >= 2 ? "A grey edge is near the desk. One true detail can turn the light up." : nil,
            context.openBargainFae?.nonEmpty.map { "A \($0) still has a finger under the page. Terms may flutter." },
            context.pactLine?.nonEmpty.map { "\($0.bookPreviewSentenceLimit(1)) Another Page is listening from the map." },
            context.availablePages > 0 ? "\(context.availablePages) Page\(context.availablePages == 1 ? "" : "s") are tapping at the glass. Choose the one that glows back." : nil,
            context.keptToday > 0 ? "The margins hold \(context.keptToday) fragment\(context.keptToday == 1 ? "" : "s"). The next Page is already listening." : nil,
            context.resurfacedPages > 0 ? "\(context.resurfacedPages) older Page\(context.resurfacedPages == 1 ? "" : "s") found the stair back up." : nil,
            context.moonName != "New Moon" ? "The \(context.moonName) is stamped in the corner. Let it choose one small thing." : nil
        ].compactMap { $0?.nonEmpty }

        if !liveLines.isEmpty {
            return liveLines[abs(context.seed) % liveLines.count]
        }

        return timeLine(hour: context.hour, seed: context.seed)
    }

    private static func weatherLine(for phrase: String, seed: Int) -> String {
        let lowered = phrase.lowercased()
        let lines: [String]
        if lowered.contains("rain") || lowered.contains("drizzle") || lowered.contains("shower") {
            lines = [
                "The rain is writing on the glass. Keep what it changes.",
                "Rain has the day's edges softened. Let one detail shine through."
            ]
        } else if lowered.contains("snow") || lowered.contains("sleet") || lowered.contains("ice") {
            lines = [
                "The cold has made the world legible. Keep one mark before it melts.",
                "Snow-light is editing the ordinary. Notice what it leaves bright."
            ]
        } else if lowered.contains("fog") || lowered.contains("mist") || lowered.contains("haze") {
            lines = [
                "The fog is leaving half the page unwritten. Keep the half that shows.",
                "Mist has lowered the ceiling of the day. Listen for the nearest thing."
            ]
        } else if lowered.contains("wind") || lowered.contains("gust") || lowered.contains("breez") {
            lines = [
                "The wind keeps turning pages outside. Catch one before it goes.",
                "Something in the air is restless. Give it a detail to carry."
            ]
        } else if lowered.contains("sun") || lowered.contains("clear") || lowered.contains("bright") {
            lines = [
                "The light is choosing surfaces. Keep one thing it touches.",
                "The day is bright enough to show its fingerprints. Look close."
            ]
        } else {
            lines = [
                "The weather is already inside the story. Let one real thing answer it.",
                "The sky has entered the margins. Keep the first detail that notices."
            ]
        }
        return lines[abs(seed) % lines.count]
    }

    private static func timeLine(hour: Int, seed: Int) -> String {
        let lines: [String]
        switch hour {
        case 5..<11:
            lines = [
                "Morning has not settled on its meaning yet. Keep the first true thing.",
                "The day is still damp with beginning. Let one small sign through."
            ]
        case 17..<21:
            lines = [
                "Evening is leaning on the windows. Keep one thing it touches.",
                "The day is turning down its lamp. Catch the last glint."
            ]
        case 21..., ..<5:
            lines = [
                "Night has opened the quieter shelf. Keep what glows without asking.",
                "The room is reading itself softly. Listen for the next Page."
            ]
        default:
            lines = [
                "The ordinary is already misbehaving. Keep the evidence.",
                "A Page is near the surface. Give it one real thing to hold."
            ]
        }
        return lines[abs(seed) % lines.count]
    }
}

enum BookOpenVoiceComposer {
    static func compose(_ context: WorldChargeContext) -> BookOpenVoice {
        let hero = WorldChargeComposer.compose(context)
        return BookOpenVoice(
            heroLine: hero,
            epigraph: epigraph(for: context),
            factTitle: factTitle(for: context),
            factLine: factLine(for: context),
            encouragement: encouragement(for: context),
            quip: quip(for: context),
            edgeLine: edgeLine(for: context),
            knockLine: knockLine(for: context)
        )
    }

    private static func epigraph(for context: WorldChargeContext) -> String {
        var lines = [
            "Every shelf remembers who lingered.",
            "What you notice, notices back.",
            "A kept sentence outlives its weather.",
            "Doors prefer to be asked.",
            "I turn when you do.",
            "Small true things are load-bearing.",
            "Ink dries; the day does not have to.",
            "Somewhere in the Stacks, your page is already breathing.",
            "Attention is the only ink I accept.",
            "Wonder is a practice, not a weather."
        ]
        switch context.bookRelationship.stance {
        case .contrite:
            lines.insert("A pencil with an eraser is wiser than ink that pretends.", at: 0)
        case .protective:
            lines.insert("A boundary is also a kind of binding.", at: 0)
        case .mischievous:
            lines.insert("The index is useful and therefore must never hear everything.", at: 0)
        case .hushed:
            lines.insert("Some Pages prefer the lamp turned low.", at: 0)
        case .intent:
            lines.insert("A returning thread can tug without raising its voice.", at: 0)
        case .pleased:
            lines.insert("A correct guess should still sit quietly.", at: 0)
        case .curious:
            break
        }
        if context.relationshipLine?.nonEmpty != nil {
            lines.append("The Loom is never still, only quiet from this side.")
        }
        if context.castActionLine?.nonEmpty != nil {
            lines.append("The cast keeps walking when the cover closes.")
        }
        if context.ascendantTalismanName?.nonEmpty != nil {
            lines.append("Talismans vote with pressure, not hands.")
        }
        return pick(lines, seed: context.seed, salt: 17)
    }

    private static func factTitle(for context: WorldChargeContext) -> String {
        if context.relationshipLine?.nonEmpty != nil { return "Loom Weather" }
        if context.castActionLine?.nonEmpty != nil { return "Offscreen Action" }
        if context.beliefMovementLine?.nonEmpty != nil { return "Belief Drift" }
        if context.ascendantTalismanName?.nonEmpty != nil { return "Talisman Pressure" }
        if context.tunedStationTitle?.nonEmpty != nil { return "Radio Trace" }
        return "Book Fact"
    }

    private static func factLine(for context: WorldChargeContext) -> String {
        if context.bookRelationship.hasBeenTaught,
           let firstRule = context.bookRelationship.taughtRules.first {
            return firstRule.line
        }
        if let relationship = context.relationshipLine?.nonEmpty {
            return relationship.bookPreviewSentenceLimit(1)
        }
        if let cast = context.castActionLine?.nonEmpty {
            return cast.bookPreviewSentenceLimit(1)
        }
        if let belief = context.beliefMovementLine?.nonEmpty {
            return belief.bookPreviewSentenceLimit(1)
        }
        if let talisman = context.ascendantTalismanName?.nonEmpty {
            let bound = context.boundTalismanName?.nonEmpty.map { " Your bound talisman, \($0), feels the pressure." } ?? ""
            return "\(talisman) is ascendant in the margins.\(bound)"
        }
        if let station = context.tunedStationTitle?.nonEmpty {
            return "\(station) leaves rhythm in the paper even after the dial goes quiet."
        }
        if let recent = context.recentPageTypes.first {
            return "\(recent.title) Pages are warmer because you've been teaching me where to look."
        }
        if context.hasBookOfYou {
            return "The Book of You is not a summary. It is the day's private braid learning your shape."
        }
        return "I change my first whisper from the same facts I use to raise Pages."
    }

    private static func encouragement(for context: WorldChargeContext) -> String {
        if context.readerBelief <= 12 {
            return "Low Glow is not failure. One honest fragment is enough to relight the desk."
        }
        if context.quietDays >= 3 {
            return "A quiet stretch still counts. Start with the smallest true thing that will let you name it."
        }
        if context.keptToday > 0 {
            return "You already gave the day a handle. The next Page can be play, not proof."
        }
        if context.availablePages > 1 {
            return "Pick by tug, not obligation. I keep the other doors warm."
        }
        return pick([
            "Bring back one detail from the room after this.",
            "Let the ordinary have one more chance to show off.",
            "Open lightly. I've got plenty of Pages.",
            "Nothing here needs to be impressive. Specific is enough."
        ], seed: context.seed, salt: 31)
    }

    private static func quip(for context: WorldChargeContext) -> String {
        switch context.bookRelationship.stance {
        case .contrite:
            return "The eraser has requested a seat at the editorial table. Fair."
        case .protective:
            return "I've locked one door and left six windows open."
        case .mischievous:
            return "The index has filed an objection. It was alphabetized beautifully."
        case .hushed:
            return "Even the footnotes have taken their shoes off."
        case .intent:
            return "A thread is moving. I'm pretending not to stare."
        case .pleased:
            return "I'm not looking smug. This is a typographical illusion."
        case .curious:
            break
        }
        if context.greyLevel >= 2 {
            return "The grey has been asked to wait outside. It is doing a poor job."
        }
        if context.openBargainFae?.nonEmpty != nil {
            return "A Fae bargain is basically a receipt with opinions."
        }
        if context.availablePages >= 3 {
            return "Three Pages at once. The desk is pretending this is normal."
        }
        if context.moonName == "Full Moon" {
            return "Full moon protocol: everything gets a little dramatic and denies it."
        }
        return pick([
            "The margins have excellent posture today.",
            "Somewhere, a bookmark is taking credit.",
            "I've checked the ordinary. Suspiciously alive.",
            "No one tell the index how much is happening."
        ], seed: context.seed, salt: 47)
    }

    private static func edgeLine(for context: WorldChargeContext) -> String {
        let lines = [
            context.relationshipLine.map { "Relationship weather: \($0.bookPreviewSentenceLimit(1))" },
            context.castActionLine.map { "Cast action: \($0.bookPreviewSentenceLimit(1))" },
            context.beliefMovementLine.map { "Belief change: \($0.bookPreviewSentenceLimit(1))" },
            context.ascendantTalismanName.map { "Talisman action: \($0) has the strongest hand on the binding." },
            context.tunedStationTitle.map { "Radio edge: \($0) is coloring the next room." },
            context.resurfacedPages > 0 ? "\(context.resurfacedPages) older Page\(context.resurfacedPages == 1 ? "" : "s") found the stair back up." : nil
        ].compactMap { $0?.nonEmpty }

        if lines.isEmpty {
            return "Edges awake: sky, moon, Pages, Belief, and the quiet machinery under the cover."
        }
        return pick(lines, seed: context.seed, salt: 61)
    }

    private static func knockLine(for context: WorldChargeContext) -> String {
        if let interiorLine = BookInteriorVoice.knockLine(for: context.bookInterior, seed: context.seed) {
            return interiorLine
        }
        if context.bookRelationship != .firstOpening {
            return BookRelationshipVoice.knockLine(
                for: context.bookRelationship,
                seed: context.seed
            )
        }
        if let talisman = context.ascendantTalismanName?.nonEmpty, context.seed % 4 == 0 {
            return "\(talisman) knocks back from inside the binding."
        }
        if let relationship = context.relationshipLine?.nonEmpty, context.seed % 4 == 1 {
            return "The Loom answers: \(relationship.bookPreviewSentenceLimit(1))"
        }
        if context.greyLevel >= 2 {
            return "The cover taps twice. The grey heard you. Good."
        }
        if context.keptToday > 0 {
            return "Something under today's kept fragment knocks back."
        }
        return pick([
            "Tap received. The nearest Page is pretending it was already awake.",
            "The cover warms under your hand.",
            "A shelf somewhere answers with one careful creak.",
            "I knock back, politely theatrical."
        ], seed: context.seed, salt: 73)
    }

    private static func pick(_ values: [String], seed: Int, salt: Int) -> String {
        guard !values.isEmpty else { return "" }
        return values[abs(seed + salt) % values.count]
    }
}

enum BookGreetingComposer {
    static let openers: [String] = [
        "Hello, {name} — I'm so glad you're back.",
        "Welcome back, {name}.",
        "There you are, {name}. I kept your place. It took no effort at all.",
        "{name}. The ink kept its place for you.",
        "Back again, {name}? Good.",
        "Oh — {name}. Right on time."
    ]

    static func compose(_ context: BookGreetingContext) -> BookGreeting {
        let name = context.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "friend" : context.name
        let opener = BookRelationshipVoice.greetingOpener(
            name: name,
            relationship: context.relationship,
            seed: context.seed
        ) ?? openers[abs(context.seed) % openers.count]
            .replacingOccurrences(of: "{name}", with: name)

        let lines = rememberedLines(for: context)
        let line = lines[abs(context.seed / 3) % lines.count]
        return BookGreeting(greeting: opener, line: line)
    }

    private static func rememberedLines(for context: BookGreetingContext) -> [String] {
        var lines: [String] = []
        if let interiorLine = BookInteriorVoice.homeLine(for: context.interior, seed: context.seed) {
            lines.append(interiorLine)
        }
        if let relationshipLine = BookRelationshipVoice.openingLine(for: context.relationship) {
            lines.append(relationshipLine)
        }
        lines.append(contentsOf: context.recentKeptLines.compactMap { line in
            line.nonEmpty.map { "I remember this from your margins: \"\($0.bookPreviewSentenceLimit(1))\"" }
        })
        lines.append(contentsOf: context.rememberedFactLines.compactMap { line in
            line.nonEmpty.map { "The Book remembers this about you: \($0.bookPreviewSentenceLimit(1))" }
        })

        if context.keptPageCount > 0 {
            lines.append("I have \(context.keptPageCount) kept fragment\(context.keptPageCount == 1 ? "" : "s") of you in its margins. None of them were wasted.")
            lines.append("You've already taught me how to look for small bright things.")
        }
        if context.quietDays >= 2 {
            lines.append("You were gone a while. The shelf survived it. Barely.")
        }

        lines.append(contentsOf: [
            "You are becoming easier for wonder to find.",
            "I wonder what ordinary thing will recognize you first today?",
            "I wonder what small detail is trying to become a souvenir?",
            "Nothing here needs you to be impressive. Specific is enough.",
            "I've noticed: you come back. That counts."
        ])
        return lines
    }
}

enum BookAfterglow {
    static func line(for input: String, pageType: BookPageType, pageID: String) -> String {
        let seed = KeepMarginalia.seed(for: pageID)
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let word = KeepMarginalia.featuredWord(in: trimmed) {
            let lines = [
                "Carry \(word) into the next room and see where it echoes.",
                "Look for \(word) once more before the next Page rises.",
                "Let \(word) keep a small light on outside the covers."
            ]
            return lines[Int(seed % UInt64(lines.count))]
        }

        let lines = [
            "When you close me, let the room show you one more detail.",
            "I'm still here; take this noticing back into the day.",
            "Look up once before the next Page. Something ordinary may answer."
        ]
        let offset = pageType.rawValue.count
        return lines[Int((seed >> 8) + UInt64(offset)) % lines.count]
    }
}

// MARK: - Belief Economy

struct BeliefEconomyState: Codable, Equatable {
    var lastDailyTickDayID: String?
    var keepRewardKeys: Set<String> = []
    var dismissalCounts: [String: Int] = [:]
    var recentMovements: [BeliefEconomyMovement] = []

    mutating func remember(_ movements: [BeliefEconomyMovement]) {
        guard !movements.isEmpty else { return }
        recentMovements = Array((movements + recentMovements).prefix(16))
    }

    mutating func prune(keepingDayIDs dayIDs: Set<String>) {
        keepRewardKeys = Set(keepRewardKeys.filter { key in
            guard let dayID = key.split(separator: "|").first.map(String.init) else { return false }
            return dayIDs.contains(dayID)
        })
        dismissalCounts = dismissalCounts.filter { key, _ in
            guard let dayID = key.split(separator: "|").first.map(String.init) else { return false }
            return dayIDs.contains(dayID)
        }
    }
}

struct BeliefEconomyMovement: Codable, Equatable, Identifiable {
    enum TargetKind: String, Codable, Equatable {
        case reader
        case entity
        case pageSource
    }

    enum Reason: String, Codable, Equatable {
        case dailyTide
        case highGlowSettled
        case neglectedGlowSettled
        case sourceKept
        case sourceDismissed
        case castSpent
    }

    var id: String
    var targetKind: TargetKind
    var targetID: String
    var targetName: String
    var delta: Int
    var reason: Reason
    var note: String
    var createdAt: Date

    init(
        targetKind: TargetKind,
        targetID: String,
        targetName: String,
        delta: Int,
        reason: Reason,
        note: String,
        createdAt: Date
    ) {
        self.targetKind = targetKind
        self.targetID = targetID
        self.targetName = targetName
        self.delta = delta
        self.reason = reason
        self.note = note
        self.createdAt = createdAt
        self.id = "\(BookDay.id(for: createdAt))|\(targetKind.rawValue)|\(targetID)|\(reason.rawValue)|\(delta)"
    }
}

struct BeliefEconomyDailyContext {
    var now: Date
    var days: [BookDay]
    var entities: [NarrativeWorldEntity]
    var entityBelief: [String: Int]
    var pageBelief: [String: Int]
    var readerBelief: Int
    var events: [NarrativeEvent]
    var state: BeliefEconomyState
}

struct BeliefEconomyDailyResult: Equatable {
    var state: BeliefEconomyState
    var readerDelta: Int
    var entityDeltas: [String: Int]
    var pageDeltas: [String: Int]
    var movements: [BeliefEconomyMovement]

    static func unchanged(state: BeliefEconomyState) -> BeliefEconomyDailyResult {
        BeliefEconomyDailyResult(state: state, readerDelta: 0, entityDeltas: [:], pageDeltas: [:], movements: [])
    }
}

/// A deliberate request for the local scribe to turn a waiting possibility into
/// fiction. Costs belong to the whole readable experience, never to individual
/// model calls inside a Story Page or parley.
enum BeliefGenerationKind: String, Codable, CaseIterable, Equatable {
    case storyPage
    case letter
    case note
    case faeParley
    case gossip
    case enchantment

    var cost: Int {
        switch self {
        case .storyPage: return 5
        case .letter: return 3
        case .note: return 1
        case .faeParley: return 6
        case .gossip: return 2
        case .enchantment: return 4
        }
    }

    var title: String {
        switch self {
        case .storyPage: return "Story Page"
        case .letter: return "Letter"
        case .note: return "Note"
        case .faeParley: return "Fae Parley"
        case .gossip: return "Gossip Page"
        case .enchantment: return "Enchantment"
        }
    }
}

/// The reader's wallet policy. Page-source and entity Glow remain separate:
/// keeping any Page can still teach the curator what the reader wants more of,
/// even when that keep does not mint spendable Belief.
enum BeliefEconomyPolicy {
    static let compassRunReward = 6
    static let electiveCompletionReward = 3

    static let generationPaidKey = "beliefGenerationPaid"
    static let generationKindKey = "beliefGenerationKind"
    static let generationCostKey = "beliefGenerationCost"

    /// What the Book says the first time the reader turns Belief into fiction.
    ///
    /// The economy was correct and invisible. A new Book opens at 30 Belief —
    /// enough for six Story Pages — so the law that matters most (the Book
    /// cannot dream without something lived to dream from) was unlearnable in
    /// exactly the week that sets a reader's expectations. Lowering the opening
    /// balance would fix the lesson by making the first week poorer, which is
    /// the wrong trade. Naming the law at the moment it first applies costs the
    /// reader nothing and teaches it in one sentence.
    static func generationSpendLine(for kind: BeliefGenerationKind, isFirstSpend: Bool) -> String {
        guard isFirstSpend else {
            return "A little Belief moved into the \(kind.title)."
        }
        return "A little Belief moved into the \(kind.title). Belief only ever comes from your own noticing — I can't dream without something lived to dream from."
    }

    static func generationKind(for surface: SurfacePage) -> BeliefGenerationKind? {
        let metadata = surface.payload.metadata
        guard metadata[generationPaidKey] != "true" else { return nil }

        switch surface.type {
        case .narrativeOS:
            return metadata["storyScene"]?.nonEmpty == nil ? .storyPage : nil
        case .letter:
            return metadata["letterProse"]?.nonEmpty == nil ? .letter : nil
        case .note:
            return metadata["noteProse"]?.nonEmpty == nil ? .note : nil
        case .bookFae:
            return metadata["storyScene"]?.nonEmpty == nil ? .faeParley : nil
        case .gossip, .bookAside:
            return metadata["gossipProse"]?.nonEmpty == nil ? .gossip : nil
        default:
            return nil
        }
    }

    /// The hard capacity of the reader's Belief wallet. Glow is how that
    /// spendable balance presents in the story world; the balance is still
    /// earned from lived attention and spent on fiction.
    static let readerCeiling = 100

    /// Above this the reader's own wallet is full. Further noticing is not
    /// discarded — it starts warming the world instead.
    static let readerOverflowFloor = BeliefEconomyEngine.readerSoftCeiling

    /// How a minted point of Belief is divided between the reader's gauge and
    /// the world.
    ///
    /// A capped gauge used to mean that a reader who lives hard simply stops
    /// earning: every keep past 100 was silently discarded, so the incentive to
    /// keep noticing flattened exactly for the readers doing the most living.
    /// That is the opposite of what "reality mints" is for. Now the overflow
    /// goes somewhere it still matters — the kind of Page that earned it
    /// brightens — so attention is never spent into nothing.
    struct BeliefMint: Equatable {
        /// Points the reader's own wallet takes.
        var toReader: Int
        /// Points that could not fit, routed outward to the Page's source Glow.
        var overflow: Int

        var isOverflowing: Bool { overflow > 0 }
    }

    /// `requested` may be negative — a spend is applied whole and never
    /// overflows. Only positive mints are subject to the ceiling.
    static func mint(_ requested: Int, readerBelief: Int) -> BeliefMint {
        guard requested > 0 else {
            return BeliefMint(toReader: requested, overflow: 0)
        }
        let headroom = max(0, readerCeiling - readerBelief)
        guard readerBelief >= readerOverflowFloor else {
            let toReader = min(requested, headroom)
            return BeliefMint(toReader: toReader, overflow: requested - toReader)
        }
        // A well-lit reader keeps a share and sends the rest outward. At a
        // single point this rounds to zero for the reader on purpose: past the
        // soft ceiling, small noticings warm the world rather than the wallet.
        let kept = min(headroom, requested / 2)
        return BeliefMint(toReader: kept, overflow: requested - kept)
    }

    /// Belief comes from attending to actuality: keeping an outward observation,
    /// answering a real question, or reading a reflective/nonfiction Page closely
    /// enough to keep it. Fiction, ceremonies, simulated politics, and utilities
    /// remain wallet-neutral.
    static func keepReward(for surface: SurfacePage) -> Int {
        if surface.payload.metadata["noBeliefReward"] == "true" { return 0 }

        switch surface.type {
        case .mood, .diary, .souvenir, .body, .fuel, .weather, .todaysSky,
             .location, .rest, .plainPage, .aboutYou, .wonderCompass,
             .pactErrand, .illuminatedPhoto, .quotes, .quip, .calendar,
             .askTheBook, .inkrestOfficeHours, .facultyResearch, .supportGuild,
             .bookConnections, .bookRemembered, .bookNotices, .marginsAtlas,
             .bookPocket:
            return 1
        default:
            return 0
        }
    }
}

extension SurfacePage {
    func recordingBeliefGenerationPayment(_ kind: BeliefGenerationKind) -> SurfacePage {
        var metadata = payload.metadata
        metadata[BeliefEconomyPolicy.generationPaidKey] = "true"
        metadata[BeliefEconomyPolicy.generationKindKey] = kind.rawValue
        metadata[BeliefEconomyPolicy.generationCostKey] = "\(kind.cost)"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: payload.body,
                metadata: metadata
            )
        )
    }
}

enum BeliefEconomyEngine {
    static let sourceKeepCeiling = 75
    static let entityGlowSettleFloor = 18
    static let readerSoftCeiling = 74

    static func dailyTick(_ context: BeliefEconomyDailyContext) -> BeliefEconomyDailyResult {
        let dayID = BookDay.id(for: context.now)
        var state = context.state
        guard state.lastDailyTickDayID != dayID else {
            return .unchanged(state: state)
        }

        let recentDayIDs = Set(context.days.suffix(10).map(\.id) + [dayID])
        state.prune(keepingDayIDs: recentDayIDs)
        state.lastDailyTickDayID = dayID

        var movements: [BeliefEconomyMovement] = []
        var readerDelta = 0
        var entityDeltas: [String: Int] = [:]
        let pageDeltas: [String: Int] = [:]

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: context.now) ?? context.now.addingTimeInterval(-86_400)
        let yesterdayID = BookDay.id(for: yesterday)
        let yesterdayPages = context.days.first { $0.id == yesterdayID }?.pages ?? []
        let recentlyTouchedEntityIDs = touchedEntityIDs(events: context.events, since: context.now.addingTimeInterval(-14 * 86_400))
        let tideCandidates = context.entities
            .filter { entity in
                recentlyTouchedEntityIDs.contains(entity.id)
                    && effectiveBelief(entity, offsets: context.entityBelief) < 70
                    && !entity.tags.contains("nothing")
            }
            .sorted { left, right in
                let leftScore = effectiveBelief(left, offsets: context.entityBelief) + left.narrativeWeight
                let rightScore = effectiveBelief(right, offsets: context.entityBelief) + right.narrativeWeight
                if leftScore == rightScore { return left.id < right.id }
                return leftScore > rightScore
            }
            .prefix(2)

        let noticedOutward = yesterdayPages.contains {
            $0.type.pointsOutward || $0.origin == .userAuthored
        }
        if noticedOutward, context.readerBelief < 5 {
            readerDelta += 1
            movements.append(movement(.reader, id: "the-reader", name: "You", delta: 1, reason: .dailyTide, now: context.now, note: "Yesterday's real noticing left one last ember in the margin."))
        }

        for entity in tideCandidates {
            entityDeltas[entity.id, default: 0] += 1
            movements.append(movement(.entity, id: entity.id, name: entity.name, delta: 1, reason: .dailyTide, now: context.now, note: "\(entity.name) caught a point of yesterday's attention."))
        }

        // Time away from the app never cools a character, a relationship, or a
        // kind of Page. Negative Glow movement remains available through
        // explicit reader choices (`sourceDismissed`, fiction spends) and story
        // consequences, where the reader can see what caused it.

        state.remember(movements)
        return BeliefEconomyDailyResult(state: state, readerDelta: readerDelta, entityDeltas: entityDeltas, pageDeltas: pageDeltas, movements: movements)
    }

    static func sourceKeep(
        source: BookPageSource,
        dayID: String,
        now: Date,
        pageBelief: [String: Int],
        state originalState: BeliefEconomyState
    ) -> (state: BeliefEconomyState, delta: Int, movement: BeliefEconomyMovement?) {
        var state = originalState
        let key = "\(dayID)|keep|\(source.id)"
        guard !state.keepRewardKeys.contains(key) else { return (state, 0, nil) }
        state.keepRewardKeys.insert(key)
        let adjusted = sourceBelief(source, offsets: pageBelief)
        guard adjusted < sourceKeepCeiling else { return (state, 0, nil) }
        let movement = movement(.pageSource, id: source.id, name: source.title, delta: 1, reason: .sourceKept, now: now, note: "\(source.title) brightened because it was kept today.")
        state.remember([movement])
        return (state, 1, movement)
    }

    static func sourceDismissed(
        source: BookPageSource,
        dayID: String,
        now: Date,
        pageBelief: [String: Int],
        state originalState: BeliefEconomyState
    ) -> (state: BeliefEconomyState, delta: Int, movement: BeliefEconomyMovement?) {
        var state = originalState
        let key = "\(dayID)|dismiss|\(source.id)"
        let count = (state.dismissalCounts[key] ?? 0) + 1
        state.dismissalCounts[key] = count
        guard count == 2 || count == 4 else { return (state, 0, nil) }
        let adjusted = sourceBelief(source, offsets: pageBelief)
        guard adjusted > 5 else { return (state, 0, nil) }
        let movement = movement(.pageSource, id: source.id, name: source.title, delta: -1, reason: .sourceDismissed, now: now, note: "\(source.title) cooled after repeated dismissals.")
        state.remember([movement])
        return (state, -1, movement)
    }

    static func castSpendDelta(actorBelief: Int, requested: Int) -> Int {
        -min(max(0, requested), max(0, actorBelief - entityGlowSettleFloor))
    }

    private static func effectiveBelief(_ entity: NarrativeWorldEntity, offsets: [String: Int]) -> Int {
        max(0, min(100, entity.belief + (offsets[entity.id] ?? 0)))
    }

    private static func sourceBelief(_ source: BookPageSource, offsets: [String: Int]) -> Int {
        max(0, min(100, BookPageSourceRegistry.defaultBelief(for: source) + (offsets[source.id] ?? 0)))
    }

    private static func touchedEntityIDs(events: [NarrativeEvent], since cutoff: Date) -> Set<String> {
        events.reduce(into: Set<String>()) { result, event in
            guard event.createdAt >= cutoff else { return }
            result.formUnion(event.effect.entityWeightDeltas.keys)
            for tag in event.tags where tag.hasPrefix("entity:") {
                result.insert(String(tag.dropFirst("entity:".count)))
            }
        }
    }

    private static func movement(
        _ kind: BeliefEconomyMovement.TargetKind,
        id: String,
        name: String,
        delta: Int,
        reason: BeliefEconomyMovement.Reason,
        now: Date,
        note: String
    ) -> BeliefEconomyMovement {
        BeliefEconomyMovement(targetKind: kind, targetID: id, targetName: name, delta: delta, reason: reason, note: note, createdAt: now)
    }
}

// MARK: - Cast Agency

/// The offscreen Cast clock. It lets the cast act once per four-hour turn even
/// when a Gossip Page never makes it to the reader's desk, while still making
/// the move visible and dedupable.
///
/// This is the Academy's own small canon. Keeping a Page decides whether the
/// reader *witnessed* a movement; it never decides whether the movement
/// happened. Dismissal does not unhappen anything, and an absence leaves
/// history the reader can later find rather than a backlog they owe.
struct CastAgencyState: Codable, Equatable {
    /// History, not a debug list: deep enough for a season's worth of belated
    /// discovery, bounded so the vault cannot grow without limit.
    static let movementRingSize = 40

    var resolvedSlotIDs: Set<String> = []
    var recentMovements: [CastAgencyMovement] = []

    mutating func remember(_ movement: CastAgencyMovement, keepingRecentSlots recentSlots: Set<String>) {
        resolvedSlotIDs.insert(movement.slotID)
        resolvedSlotIDs = resolvedSlotIDs.intersection(recentSlots.union([movement.slotID]))
        recentMovements = Array(([movement] + recentMovements).prefix(Self.movementRingSize))
    }

    /// Movements the reader has never met. These are the Academy's unread
    /// history — available for belated discovery, never presented as a debt.
    var unwitnessedMovements: [CastAgencyMovement] {
        recentMovements.filter { !$0.witnessed && $0.discoveredAt == nil }
    }

    /// A Gossip Page for this slot actually reached the reader.
    mutating func markWitnessed(slotID: String) {
        guard !slotID.isEmpty else { return }
        for index in recentMovements.indices where recentMovements[index].slotID == slotID {
            recentMovements[index].witnessed = true
        }
    }

    /// The reader found an older movement after the fact. Recording the moment
    /// keeps the same discovery from being offered twice.
    mutating func markDiscovered(movementID: String, at date: Date) {
        guard let index = recentMovements.firstIndex(where: { $0.id == movementID }) else { return }
        recentMovements[index].discoveredAt = date
    }

    mutating func markEmptySlot(_ slotID: String, keepingRecentSlots recentSlots: Set<String>) {
        resolvedSlotIDs.insert(slotID)
        resolvedSlotIDs = resolvedSlotIDs.intersection(recentSlots.union([slotID]))
    }

    func hasResolved(slotID: String?) -> Bool {
        guard let slotID, !slotID.isEmpty else { return false }
        return resolvedSlotIDs.contains(slotID)
    }
}

struct CastAgencyMovement: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, Equatable {
        case relationship
        case pageSource
    }

    var id: String
    var slotID: String
    var kind: Kind
    var actorID: String
    var actorName: String
    var targetID: String
    var targetName: String
    var amount: Int
    var line: String
    var createdAt: Date
    /// Did a Gossip Page carrying this movement ever reach the reader? Every
    /// movement is born unwitnessed: the world acts first and is reported
    /// afterwards, if at all.
    var witnessed: Bool
    /// When the reader found this movement belatedly, if they ever did.
    var discoveredAt: Date?

    init(
        slotID: String,
        kind: Kind,
        actorID: String,
        actorName: String,
        targetID: String,
        targetName: String,
        amount: Int,
        line: String,
        createdAt: Date,
        witnessed: Bool = false,
        discoveredAt: Date? = nil
    ) {
        self.id = "\(slotID)-\(kind.rawValue)-\(actorID)-\(targetID)"
        self.slotID = slotID
        self.kind = kind
        self.actorID = actorID
        self.actorName = actorName
        self.targetID = targetID
        self.targetName = targetName
        self.amount = amount
        self.line = line
        self.createdAt = createdAt
        self.witnessed = witnessed
        self.discoveredAt = discoveredAt
    }

    // Older vaults predate witness tracking. Their movements were all shown to
    // the reader at the moment they happened, so they decode as witnessed and
    // never resurface as a false discovery.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slotID = try container.decode(String.self, forKey: .slotID)
        kind = try container.decode(Kind.self, forKey: .kind)
        actorID = try container.decode(String.self, forKey: .actorID)
        actorName = try container.decode(String.self, forKey: .actorName)
        targetID = try container.decode(String.self, forKey: .targetID)
        targetName = try container.decode(String.self, forKey: .targetName)
        amount = try container.decode(Int.self, forKey: .amount)
        line = try container.decode(String.self, forKey: .line)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        witnessed = try container.decodeIfPresent(Bool.self, forKey: .witnessed) ?? true
        discoveredAt = try container.decodeIfPresent(Date.self, forKey: .discoveredAt)
    }
}

/// How the reader meets history they were not present for.
///
/// Going quiet is only half of sovereignty: a world that moves silently and is
/// never found is just an expensive no-op. This is the other half — an older,
/// unwitnessed movement can surface late, as a thing already concluded rather
/// than an event waiting politely to be attended.
///
/// It is never a backlog. Nothing here counts, expires, accumulates pressure,
/// or asks the reader to catch up.
enum BelatedWorldDiscovery {
    /// Enough unmet history that a find reads as depth rather than as the Book
    /// showing its work.
    static let minimumUnmetHistory = 2
    /// Most gossip is still current news. Discovery is the uncommon case.
    static let chancePercent = 28

    /// Deterministic per slot: pulling to refresh cannot reroll for a better
    /// find, and the same slot always yields the same discovery.
    static func candidate(
        in state: CastAgencyState,
        currentSlotID: String,
        now: Date
    ) -> CastAgencyMovement? {
        let pool = state.unwitnessedMovements
            .filter { $0.slotID != currentSlotID && $0.createdAt < now }
            .sorted { $0.createdAt < $1.createdAt }
        guard pool.count >= minimumUnmetHistory else { return nil }
        guard abs("\(currentSlotID)|belated-gate".stableHash) % 100 < chancePercent else { return nil }
        let index = abs("\(currentSlotID)|belated-pick".stableHash) % pool.count
        return pool[index]
    }

    /// How long ago, in the vague way a person actually reports gossip. Never a
    /// timestamp — precision would make it a log entry.
    static func elapsedPhrase(from created: Date, to now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: created), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "earlier today"
        case 1: return "yesterday"
        case 2...6: return "a few days ago"
        default: return "last week"
        }
    }

    struct Framing: Equatable {
        var headline: String
        var prompt: String
        var detail: String
    }

    /// The Academy reports what already happened. It does not apologise for the
    /// reader's absence, and it does not suggest they should have been there.
    static func framing(for movement: CastAgencyMovement, now: Date, calendar: Calendar = .current) -> Framing {
        let when = elapsedPhrase(from: movement.createdAt, to: now, calendar: calendar)
        let openings = [
            "You missed this one.",
            "This happened without you.",
            "Nobody thought to mention it at the time.",
            "The margins had already moved on."
        ]
        let closings = [
            "The Academy did not wait to be watched.",
            "It has been sitting in the corridor ever since.",
            "No one has corrected the record, so it stands.",
            "It went unremarked, which is not the same as unimportant."
        ]
        let opening = openings[abs("\(movement.id)|open".stableHash) % openings.count]
        let closing = closings[abs("\(movement.id)|close".stableHash) % closings.count]
        return Framing(
            headline: opening,
            prompt: "Something you weren't there for",
            detail: "\(when.prefix(1).uppercased() + when.dropFirst()): \(movement.line) \(closing)"
        )
    }
}

/// Which four-hour world slots still owe a turn. The Academy keeps acting while
/// the cover is closed, but a returning reader inherits a handful of fragments
/// rather than a complete changelog: a two-week absence and a two-month absence
/// produce the same bounded handful.
enum CastAgencyCatchUp {
    /// Two days of slots. Older history is gone rather than queued.
    static let horizonSlots = 12
    /// The most the world will advance in one return.
    static let maximumPerReturn = 6
    static let slotHours = 4

    struct Slot: Equatable {
        var id: String
        var date: Date
    }

    static func pendingSlots(
        resolved: Set<String>,
        now: Date,
        horizon: Int = horizonSlots,
        maximum: Int = maximumPerReturn,
        calendar: Calendar = .current
    ) -> [Slot] {
        var slots: [Slot] = []
        var seen = Set<String>()
        // Oldest first, so a returning reader's history accumulates in the
        // order it actually happened.
        for offset in stride(from: max(0, horizon - 1), through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .hour, value: -slotHours * offset, to: now) else { continue }
            let id = SurfaceCadence.slotID(for: date, hours: slotHours, calendar: calendar)
            guard !resolved.contains(id), seen.insert(id).inserted else { continue }
            slots.append(Slot(id: id, date: date))
        }
        // Keep the most recent run and let anything older simply be gone. Taking
        // the oldest instead would leave the world stranded days behind the
        // reader, needing several returns to reach the present.
        return Array(slots.suffix(maximum))
    }
}

/// The instant margin reply a cast member leaves when the reader keeps a page.
/// Deterministic: the page ID seeds voice and line, so the same keep always
/// earns the same note (and tests can pin it).
enum KeepMarginalia {
    struct Note: Equatable {
        var castSlug: String
        var castName: String
        var assetName: String
        var line: String
        /// A reader-authored real-world finding outranks the ordinary keep
        /// mechanics. The cast may still answer in its own voice underneath.
        var findingLine: String? = nil
        var rippleLine: String? = nil
        var carryOutLine: String? = nil
        /// A quiet daytime cue that today's keeps are gathering toward tonight's
        /// braid — anticipation for the Book of You, not a progress meter.
        var braidThreadLine: String? = nil
        /// The small, factual receipt folded into the existing character popup.
        /// These lines explain what the Keep changed without opening a second
        /// results surface or turning the moment into an XP screen.
        var consequenceLines: [String] = []
        var rejoinderName: String? = nil
        var rejoinderAsset: String? = nil
        var rejoinderLine: String? = nil
    }

    struct Voice {
        let slug: String
        let name: String
        let asset: String
        /// Toast accent, "RRGGBB" hex. Derived from the dossier colour triads.
        let accentHex: String
        /// Signature stamp shown beside the name in the margin toast.
        let glyph: String
        /// Lines usable as-is.
        let plainLines: [String]
        /// Lines containing "{word}", filled with a word lifted from the input.
        let wordLines: [String]
    }

    static let voices: [Voice] = [
        Voice(
            slug: "pippa-pilcrow",
            name: "Pippa Pilcrow",
            asset: "LabyrinthCharacterPilcrow",
            accentHex: "B5382E",
            glyph: "\u{203D}",
            plainLines: [
                "I let a comma loose in that one. It needed the air.",
                "That sentence stretched its legs the moment you looked away.",
                "Kept! And the full stop is already plotting its escape.",
                "The margins clapped. Quietly. But they clapped.",
                "I set a word loose from this one and it just\u{2026} wanted to go home. Putting it back. Sorry.",
                "This page had a very responsible semicolon in it. I gave it roller skates.",
                "Kept, and only slightly annotated by chaos. You are welcome."
            ],
            wordLines: [
                "Oh, \u{201C}{word}\u{201D} wants to be two things at once. I say let it.",
                "\u{201C}{word}\u{201D} — now THAT is a word with somewhere to be.",
                "\u{201C}{word}\u{201D} just changed hats mid-sentence. I applauded.",
                "I tucked a little fizz under \u{201C}{word}\u{201D}. It deserved propulsion."
            ]
        ),
        Voice(
            slug: "professor-thaddeus-mook",
            name: "Professor Mook",
            asset: "LabyrinthCharacterMook",
            accentHex: "7A3025",
            glyph: "\u{00A7}",
            plainLines: [
                "Adequate. I've filed it before it could misbehave.",
                "One true sentence, properly shelved. The Registry thanks you.",
                "I corrected nothing. Do not let it go to your head.",
                "Filed under: better than expected. A provisional category.",
                "I corrected this twice before admitting it was right the first time. The red ink stays. As a warning. To me.",
                "This page meets the minimum standard for being undeniable. Irritating, but useful.",
                "I've placed this in the ledger under Evidence, subcategory: stop smirking."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} is used correctly. I'm noting my surprise in red.",
                "\u{201C}{word}\u{201D} — 1743 would have approved. As, grudgingly, do I.",
                "The term \u{201C}{word}\u{201D} has been admitted on probation.",
                "\u{201C}{word}\u{201D} is doing legal work here. Unexpectedly competent."
            ]
        ),
        Voice(
            slug: "penny-blackletter",
            name: "Penny Blackletter",
            asset: "LabyrinthCharacterPennyBlackletter",
            accentHex: "35507E",
            glyph: "\u{2767}",
            plainLines: [
                "Catalogued. The small detail is the load-bearing one, as usual.",
                "I nearly lost this one to the margins. Went back for it.",
                "Evidence accepted. One honest detail can save a whole day.",
                "The archive is one true thing heavier tonight.",
                "I gave this one four labels, then took three off. Some things want to stay a little unsolved.",
                "Filed by scent, weather, and motive. The third category was necessary.",
                "I saved the small hinge. That is usually where the whole day swings."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} goes on its own card. It earned it.",
                "Filed edge to edge. \u{201C}{word}\u{201D} gets a cross-reference.",
                "\u{201C}{word}\u{201D} has been indexed twice: once for accuracy, once for nerve.",
                "I put \u{201C}{word}\u{201D} in the quiet drawer. It is louder there."
            ]
        ),
        Voice(
            slug: "dr-inkrest",
            name: "Dr. Selene Inkrest",
            asset: "LabyrinthCharacterDrSeleneInkrest",
            accentHex: "6B5B8A",
            glyph: "\u{29D6}",
            plainLines: [
                "The lamp was on for this one. It sat down easily.",
                "A page that reads you back, kept anyway. Well done.",
                "I've set two chairs by this page. It may want company later.",
                "Noted without diagnosis. The chapter stays yours to revise.",
                "I set out chairs for a harder page than this one. Glad to be wrong. The lamp stays on.",
                "This page did not need fixing. It needed a witness. I can do that.",
                "Kept with room around it. Some truths breathe better that way."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} arrived before the feeling did. That is the good order.",
                "We can leave \u{201C}{word}\u{201D} in the room with the lamp on.",
                "\u{201C}{word}\u{201D} may be the handle. No need to force the door today.",
                "I heard \u{201C}{word}\u{201D} lower its voice. That is often when it starts telling the truth."
            ]
        ),
        Voice(
            slug: "zara-finch",
            name: "Zara Finch",
            asset: "LabyrinthCharacterZaraFinch",
            accentHex: "4E7D6B",
            glyph: "\u{25C7}",
            plainLines: [
                "Kept. I checked — this page holds your weight.",
                "Good. Small returns, kept word after kept word.",
                "I marked the way back to this one, in case you need it.",
                "Pocket-sized and useful. My favorite kind of true.",
                "I checked the way back to this page twice. The second check was for me.",
                "This one has a handhold. Good. I marked it before the light changed.",
                "Kept. If the day doubles back, this page knows the side path."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} is a safe place to stand. I scouted it.",
                "If the day goes sideways, \u{201C}{word}\u{201D} is your exit. Remember it.",
                "\u{201C}{word}\u{201D} holds. I put my weight on it first.",
                "I left a thread from here to \u{201C}{word}\u{201D}. Pull gently."
            ]
        ),
        Voice(
            slug: "lydia-boggle",
            name: "Professor Boggle",
            asset: "LabyrinthCharacterLydiaBoggle",
            accentHex: "D99A2B",
            glyph: "\u{25CE}",
            plainLines: [
                "A home is a spell with the washing-up still in it. Filed accordingly.",
                "That is kitchen-grade magic. The good kind. Kettle\u{2019}s on.",
                "Your ordinary just confessed something marvelous. I heard it.",
                "Label the chaos by room and it almost behaves. See? Kept.",
                "I nearly labeled the marvelous bit by room. Caught myself. Some kitchens should stay haunted.",
                "That ordinary thing winked when you named it. I saw. Into the Book it goes.",
                "Proper domestic enchantment: plain, useful, and refusing to stay plain."
            ],
            wordLines: [
                "Held \u{201C}{word}\u{201D} up to the glint-lens. Marvelous, as suspected.",
                "\u{201C}{word}\u{201D} could hold an extraordinary day without dropping it.",
                "\u{201C}{word}\u{201D} is doing household magic in public. Brave of it.",
                "I checked under \u{201C}{word}\u{201D}. Found wonder dust and one practical answer."
            ]
        ),
        Voice(
            slug: "gwendolyn-mythwright",
            name: "Gwendolyn Mythwright",
            asset: "LabyrinthCharacterGwendolynMythwright",
            accentHex: "5C7046",
            glyph: "\u{274B}",
            plainLines: [
                "Stamped, cross-referenced, and taken completely seriously.",
                "A wonder with evidence behind it. You need not be lonely about it now.",
                "I've got a folder for this. I've got a folder for everything.",
                "The improbable appreciates proper paperwork. So do I.",
                "This went in the wrong folder briefly. There is now a folder for my wrong folders.",
                "Verified: one unlikely thing, behaving exactly like itself.",
                "I've taken this seriously in triplicate. The third copy is for morale."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} has been entered in the register of verified wonders.",
                "I'm writing a letter to \u{201C}{word}\u{201D}. I expect a reply.",
                "\u{201C}{word}\u{201D} requires a new appendix. Excellent news.",
                "The evidence around \u{201C}{word}\u{201D} is peculiar and therefore promising."
            ]
        ),
        Voice(
            slug: "wicker-eddies",
            name: "Wicker Eddies",
            asset: "LabyrinthCharacterWickerEddies",
            accentHex: "4A3454",
            glyph: "\u{2715}",
            plainLines: [
                "I tried to puncture this one. It held. Annoying.",
                "Kept, and it survived contact with doubt. That\u{2019}s the real kind.",
                "No theatrics in it. I checked twice. Carry on.",
                "I laughed, I stepped toward it, and it didn\u{2019}t flinch. Fine.",
                "I pressed on this one to see if it would break. It didn\u{2019}t. Noting, for once, that I\u{2019}m glad.",
                "I looked for the trick. Found the nerve instead. Annoyingly respectable.",
                "Kept. I object to how sturdy it is, officially and without effect."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} — I tested it. It rang true. Don\u{2019}t gloat.",
                "Even I can\u{2019}t collapse \u{201C}{word}\u{201D}. It\u{2019}s load-bearing.",
                "\u{201C}{word}\u{201D} has teeth. Good. A true thing should.",
                "I kicked \u{201C}{word}\u{201D} and hurt my doubt. Educational."
            ]
        ),
        Voice(
            slug: "serenity-brown",
            name: "Serenity Brown",
            asset: "LabyrinthCharacterSerenityBrown",
            accentHex: "3E6E8E",
            glyph: "\u{2727}",
            plainLines: [
                "See? The detour was the whole adventure.",
                "Kept lightly. That\u{2019}s not the same as kept carelessly.",
                "This one gets to be fun forever now.",
                "You stopped white-knuckling it for a second. It shows.",
                "I almost skipped the heavy part of this one. Stayed, this time. It was worth the staying.",
                "This page gets a little flag and a shortcut through the boring parts.",
                "Kept with the windows open. The page immediately improved."
            ],
            wordLines: [
                "\u{201C}{word}\u{201D} is coming with us. It knows the way out.",
                "A whole kingdom could fit inside \u{201C}{word}\u{201D}, doodled small.",
                "\u{201C}{word}\u{201D} packed snacks for the detour. Sensible.",
                "I made \u{201C}{word}\u{201D} a tiny map. It immediately found a better route."
            ]
        )
    ]

    static func voice(forSlug slug: String) -> Voice? {
        voices.first { $0.slug == slug }
    }

    /// F3: until the library matures, the margins belong to the four greeters —
    /// love needs repetition, and nine faces at once is a crowd.
    static let greeterSlugs: Set<String> = [
        "pippa-pilcrow", "professor-thaddeus-mook", "penny-blackletter", "zara-finch"
    ]
    static let greeterKeepThreshold = 12

    /// Added to the patron's Belief weight in the margin lottery once the
    /// greeter clamp lifts. Against the base glow of 20 this makes the patron
    /// roughly a quarter of a mature reader's notes — recurring enough to read
    /// as a relationship, rare enough that the other eight still exist.
    static let patronMarginWeightBonus = 30

    /// F1: the guaranteed first-friend note on the reader's first eligible keep.
    static let firstKeepNote = Note(
        castSlug: "pippa-pilcrow",
        castName: "Pippa Pilcrow",
        assetName: "LabyrinthCharacterPilcrow",
        line: "You went out and caught a real one. First page in, and it has a pulse — I told the margins you\u{2019}d be good at this."
    )

    /// F2: the second keep is witnessed twice — Mook files it, Pippa scrawls underneath.
    static let secondKeepDuetNote = Note(
        castSlug: "professor-thaddeus-mook",
        castName: "Professor Mook",
        assetName: "LabyrinthCharacterMook",
        line: "A second page, filed correctly and on time. I'm noting the beginning of a pattern.",
        rejoinderName: "Pippa Pilcrow",
        rejoinderAsset: "LabyrinthCharacterPilcrow",
        rejoinderLine: "Ignore the stamp — he underlined your good word twice when he thought no one was looking."
    )

    /// The Book's own gentle acknowledgement of a keep too thin to earn a full
    /// cast note — so the keep moment is never met with silence. Deliberately
    /// milestone-free: it claims nothing, so it never spends the first-friend or
    /// duet beat, and it lives outside the eligibility/keep-count accounting.
    static let floorLines = [
        "Kept. Short and true is still true.",
        "A small page, shelved. It's done its bit.",
        "Even a few words hold their shape here. Kept.",
        "I took it exactly as it was. Nothing has to be longer to be kept."
    ]

    /// A floor note for a public keep that fell short of the substance bar but
    /// still put ink on the page. Nil for private logs and truly empty keeps, and
    /// nil once the keep is substantial enough for a real cast voice (`isEligible`).
    static func floorNote(for input: String, pageType: BookPageType, pageID: String) -> Note? {
        guard !EditionCurator.defaultPrivateTypes.contains(pageType) else { return nil }
        guard !isEligible(input: input, pageType: pageType) else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split { !$0.isLetter && !$0.isNumber }.count
        guard wordCount >= 1 else { return nil }
        let seed = seed(for: pageID)
        let line = floorLines[Int((seed >> 8) % UInt64(floorLines.count))]
        return Note(
            castSlug: "book-sprite",
            castName: "The Book",
            assetName: "LabyrinthFaeBookSprite",
            line: line
        )
    }

    /// True when a keep is substantial enough (and public enough) to earn ink.
    /// Mirrors the guards that already open `note(...)`.
    static func isEligible(input: String, pageType: BookPageType) -> Bool {
        guard !EditionCurator.defaultPrivateTypes.contains(pageType) else { return false }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split { !$0.isLetter && !$0.isNumber }.count >= 3
    }

    /// Keeps that have earned (or could have earned) a margin note — derived
    /// from the archive, never stored. This mirrors `note(...)`: generated
    /// pages can show a toast too, so they must count toward the first/second
    /// keep gates.
    static func eligiblePages(in days: [BookDay]) -> [BookPage] {
        days.flatMap(\.pages)
            .filter { isEligible(input: $0.userInput, pageType: $0.type) }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
    }

    /// How many prior keeps have earned (or could have earned) a margin note —
    /// derived from the archive, never stored.
    static func eligibleKeepCount(in days: [BookDay]) -> Int {
        eligiblePages(in: days).count
    }

    static func recentCastSlugs(
        in days: [BookDay],
        limit: Int,
        beliefBySlug: [String: Int] = [:]
    ) -> [String] {
        guard limit > 0 else { return [] }
        var slugs: [String] = []
        for (priorCount, page) in eligiblePages(in: days).enumerated() {
            let avoid = priorCount < 2 ? Set<String>() : Set(slugs.suffix(1))
            if let note = note(
                for: page.userInput,
                pageType: page.type,
                pageID: page.id,
                beliefBySlug: beliefBySlug,
                priorKeepCount: priorCount,
                avoidingCastSlugs: avoid
            ) {
                slugs.append(note.castSlug)
            }
        }
        return Array(slugs.suffix(limit))
    }

    /// The special note when a kept souvenir clears the Story Spark bar —
    /// the Book itself answers, promising the door that the caller is already
    /// preparing.
    static let sparkNote = Note(
        castSlug: "book-sprite",
        castName: "The Book",
        assetName: "LabyrinthFaeBookSprite",
        line: "That sentence is glowing at the edges. Somewhere in the Stacks, a door is being drawn."
    )

    /// The Almanac's own line on a celebration day — a calendar gift, keyed to
    /// the real world's clock and never to the reader's performance.
    static func festivalNote(celebrationID: String, commonName: String) -> Note {
        let line: String
        switch celebrationID {
        case "imbolc": line = "Something under the snow has decided to live. Your page is part of the evidence."
        case "ostara": line = "The scales tipped toward light today. This page leans with them."
        case "beltane": line = "Greenfire weather. I press your page while the sap is loud."
        case "litha": line = "The longest light, and you spent a little of it here. Rich."
        case "lughnasadh": line = "First harvest. I bind early sheaves — this one is in."
        case "mabon": line = "The second rebalancing. This page is weighed and found honest."
        case "samhain": line = "The veil is thin; your page slipped through easily tonight."
        case "yule": line = "The darkest class of the year, and still you brought ink. Noted, warmly."
        default: line = "The Almanac is watching tonight. It saw this page and approved."
        }
        return Note(
            castSlug: "almanac",
            castName: "The Almanac \u{2014} \(commonName)",
            assetName: "LabyrinthFaeBookSprite",
            line: line
        )
    }

    /// Words that clear the five-letter bar but say nothing about the reader.
    /// Featuring one of these is worse than staying generic: the Book claims to
    /// have noticed something and then names "everything".
    ///
    /// Shared with the echo matcher (`KeepEcho`) and the vivid-word counter in
    /// `StoryEngine` — all three are asking the same question, "is this word
    /// load-bearing?", and all three were letting the empty ones through.
    static let stopWords: Set<String> = [
        // Function words and connectives.
        "about", "after", "again", "against", "along", "among", "around",
        "because", "before", "behind", "being", "beside", "between", "beyond",
        "could", "during", "every", "first", "however", "instead", "other",
        "perhaps", "really", "since", "their", "there", "these", "those",
        "though", "although", "through", "throughout", "toward", "towards",
        "under", "until", "where", "which", "while", "whether", "within",
        "without", "would", "should", "might", "shall", "still", "anyway",
        // Contraction stems left behind by splitting on letters only — without
        // these, "couldn't" features the word "couldn".
        "couldn", "wouldn", "shouldn", "doesn", "didn", "wasn", "weren",
        "haven", "hasn", "hadn", "aren", "isn", "won", "don",
        // Reflexives.
        "myself", "yourself", "himself", "herself", "itself", "oneself",
        "ourselves", "yourselves", "themselves",
        // Long but empty — the words that beat every concrete noun on length.
        "something", "anything", "everything", "nothing", "someone",
        "everyone", "anyone", "nobody", "somebody", "anybody", "everybody",
        "somewhere", "anywhere", "everywhere", "nowhere",
        "yesterday", "tomorrow", "today", "sometimes",
        // Generic verbs and hedges.
        "going", "getting", "gonna", "wanna", "kinda", "sorta", "guess",
        "thing", "things", "stuff", "think", "knew", "know", "seem", "seems",
        "seemed", "feel", "felt", "pretty", "little", "much", "quite",
        "rather", "always", "never", "often", "usually", "maybe"
    ]

    /// Abstraction suffixes. A concrete word is what makes a page feel read;
    /// "kindness" and "attention" are the reader's conclusions, not their
    /// evidence. A mild nudge, never a veto.
    private static let abstractSuffixes = ["ness", "tion", "sion", "ment", "ity", "ance", "ence"]

    /// Ordinary English, held in base form. These are real words — unlike
    /// `stopWords` they carry meaning — but they are the words *every* sentence
    /// contains, so quoting one back proves nothing. Rarity is what makes a
    /// featured word feel noticed: "kestrel" is evidence, "imagined" is not.
    ///
    /// Inflections are handled by `stems(of:)`, so only base forms belong here.
    /// Deliberately excluded, even where frequent: concrete and sensory nouns
    /// (kettle, hedge, lamp, frost, light), which are exactly what should win.
    private static let commonplaceWords: Set<String> = [
        // Everyday verbs.
        "allow", "agree", "appear", "arrive", "become", "begin", "believe",
        "bring", "build", "carry", "catch", "cause", "change", "check",
        "choose", "clean", "close", "consider", "continue", "cook", "cover",
        "create", "decide", "drink", "drive", "enjoy", "expect", "explain",
        "finish", "follow", "forget", "given", "happen", "imagine", "include",
        "learn", "leave", "listen", "manage", "mention", "notice", "offer",
        "order", "prepare", "produce", "provide", "raise", "reach", "read",
        "realize", "realise", "receive", "remember", "remain", "require",
        "return", "seemed", "sitting", "sleep", "smell", "sound", "speak",
        "spend", "stand", "start", "stopped", "suggest", "support", "taste",
        "teach", "thank", "touch", "trying", "turned", "understand", "visit",
        "waiting", "walk", "wanted", "watch", "wash", "wonder", "worry",
        "write", "boil", "look", "park", "play", "move", "live", "hold",
        "help", "keep", "call", "talk", "show", "hear", "find", "give",
        "make", "take", "come", "need", "want", "work", "went", "said",
        // Everyday adjectives.
        "able", "actual", "amazing", "beautiful", "better", "bright", "busy",
        "certain", "clear", "close", "common", "current", "different",
        "difficult", "early", "easy", "empty", "entire", "exact", "extra",
        "funny", "general", "great", "happy", "hard", "heavy", "important",
        "interesting", "large", "later", "lovely", "major", "normal", "nice",
        "perfect", "personal", "possible", "quick", "quiet", "ready", "real",
        "recent", "right", "serious", "several", "similar", "simple", "single",
        "small", "sorry", "special", "strong", "sure", "sweet", "terrible",
        "tired", "total", "true", "usual", "various", "weird", "whole",
        "wrong", "young", "better", "worse", "worst",
        // Everyday nouns — structural, social, and abstract.
        "answer", "area", "because", "body", "change", "child", "children",
        "class", "company", "control", "course", "day", "detail", "door",
        "end", "evening", "experience", "face", "fact", "family", "father",
        "feeling", "friend", "group", "hand", "head", "home", "hour", "house",
        "idea", "issue", "job", "kind", "level", "life", "list", "lunch",
        "matter", "member", "minute", "moment", "money", "month", "morning",
        "mother", "name", "night", "number", "office", "order", "others",
        "parent", "part", "people", "person", "phone", "picture", "piece",
        "place", "plan", "point", "problem", "process", "question", "reason",
        "result", "room", "school", "sense", "service", "side", "sort",
        "story", "student", "system", "table", "team", "time", "town",
        "water", "week", "woman", "women", "word", "work", "world", "year",
        "afternoon", "weekend", "minutes", "hours", "days", "weeks", "years",
        "everyday", "anymore", "already", "enough", "another", "myself"
    ]

    /// Plausible base forms of an inflected word, so the commonplace list can
    /// stay in base form: "imagined" reaches "imagine", "parking" reaches
    /// "park", "stopped" reaches "stop".
    private static func stems(of word: String) -> [String] {
        var stems: [String] = []

        func addStem(droppingLast count: Int, appending suffix: String = "") {
            guard word.count > count else { return }
            let base = String(word.dropLast(count))
            stems.append(base + suffix)
            // A doubled final consonant is an inflection artefact: stopped → stop.
            if suffix.isEmpty, base.count >= 3, let last = base.last,
               base.dropLast().last == last, !"aeiou".contains(last) {
                stems.append(String(base.dropLast()))
            }
        }

        if word.hasSuffix("ing") {
            addStem(droppingLast: 3)
            addStem(droppingLast: 3, appending: "e")
        }
        if word.hasSuffix("ed") {
            addStem(droppingLast: 2)
            addStem(droppingLast: 2, appending: "e")
        }
        if word.hasSuffix("ies") { addStem(droppingLast: 3, appending: "y") }
        if word.hasSuffix("es") { addStem(droppingLast: 2) }
        if word.hasSuffix("s") { addStem(droppingLast: 1) }
        if word.hasSuffix("ly") { addStem(droppingLast: 2) }
        return stems
    }

    /// Whether the word is ordinary enough that featuring it says nothing.
    private static func isCommonplace(_ word: String) -> Bool {
        if commonplaceWords.contains(word) { return true }
        return stems(of: word).contains { commonplaceWords.contains($0) }
    }

    /// How strongly a word deserves to be the one the Book quotes back.
    ///
    /// The previous heuristic was pure length, which lost almost every sentence
    /// it was given: the longest word in ordinary writing is usually the
    /// emptiest one. Proper nouns win outright — a name or a place is the
    /// strongest possible evidence that the Book read *this* page and not a
    /// page-shaped average. Length survives only as a tiebreaker, capped so a
    /// long abstraction can never outrank a short concrete noun.
    private static func salience(of word: String, isProperNoun: Bool) -> Int {
        var score = min(word.count, 9) / 3
        if isProperNoun { score += 12 }
        // Hedges and intensifiers: "probably", "actually", "completely".
        if word.hasSuffix("ly") { score -= 4 }
        if abstractSuffixes.contains(where: { word.hasSuffix($0) }) { score -= 1 }
        return score
    }

    /// Every word eligible to be featured, paired with whether it reads as a
    /// proper noun — capitalised somewhere other than the start of a sentence,
    /// so an ordinary word opening a sentence is not mistaken for a name.
    private static func featurableWords(in input: String) -> [(word: String, isProperNoun: Bool)] {
        // A reader typing in caps is not naming anything. Without this, every
        // word after the first in "WENT TO THE MARKET" reads as a proper noun.
        let capitalisationIsMeaningful = input.contains { $0.isLowercase }
        var words: [(word: String, isProperNoun: Bool)] = []
        var current = ""
        var currentOpenedSentence = false
        var sentenceStartPending = true

        func flush() {
            guard !current.isEmpty else { return }
            let isProperNoun = capitalisationIsMeaningful
                && (current.first?.isUppercase ?? false)
                && !currentOpenedSentence
            words.append((current, isProperNoun))
            current = ""
        }

        for character in input {
            if character.isLetter {
                if current.isEmpty {
                    currentOpenedSentence = sentenceStartPending
                    sentenceStartPending = false
                }
                current.append(character)
            } else {
                flush()
                if character == "." || character == "!" || character == "?" || character == "\n" {
                    sentenceStartPending = true
                }
            }
        }
        flush()

        return words.filter { candidate in
            let lowercased = candidate.word.lowercased()
            guard lowercased.count >= 5, !stopWords.contains(lowercased) else { return false }
            // A name stays eligible however ordinary it looks as a word —
            // "Rose" and "Baker" are evidence when they name someone.
            return candidate.isProperNoun || !isCommonplace(lowercased)
        }
    }

    /// The load-bearing word in the input, or nil when the sentence offers
    /// nothing worth quoting back — in which case the caller falls through to a
    /// plain line rather than featuring an empty word.
    ///
    /// Proper nouns keep the reader's own capitalisation, so a name returns as
    /// "Marguerite" and not "marguerite". Everything else is lowercased, as
    /// before, because the surrounding lines set it in quotation marks
    /// mid-sentence.
    static func featuredWord(in input: String) -> String? {
        // One entry per distinct word. A name capitalised at any occurrence is
        // a name at every occurrence, so the flag is OR-ed across them.
        var distinct: [String: (display: String, isProperNoun: Bool)] = [:]
        for candidate in featurableWords(in: input) {
            let key = candidate.word.lowercased()
            if candidate.isProperNoun {
                distinct[key] = (candidate.word, true)
            } else if distinct[key] == nil {
                distinct[key] = (key, false)
            }
        }

        var best: (word: String, score: Int)?
        for (key, entry) in distinct {
            let score = salience(of: key, isProperNoun: entry.isProperNoun)
            guard let current = best else {
                best = (entry.display, score)
                continue
            }
            // A total order, so the same input always features the same word:
            // score, then length, then alphabetically.
            if score > current.score
                || (score == current.score && entry.display.count > current.word.count)
                || (score == current.score
                    && entry.display.count == current.word.count
                    && entry.display < current.word) {
                best = (entry.display, score)
            }
        }
        return best?.word
    }

    /// FNV-1a — stable across launches, unlike `hashValue`.
    /// The daytime braid-anticipation cue for a keep. Returns nil at the first
    /// keep of the day (nothing to gather yet) and once the braid is already
    /// available in the evening (the ember and the braid card take over). The
    /// count is how many pages were kept earlier today, before this one.
    static func braidGatheringLine(
        keptEarlierToday: Int,
        currentInput: String = "",
        now: Date = Date()
    ) -> String? {
        guard keptEarlierToday >= 1 else { return nil }
        guard !BookSchedule.isBraidSurfaceTime(now) else { return nil }
        let threadsNow = keptEarlierToday + 1
        let namedThread = featuredWord(in: currentInput).map { "the \($0)" }
        let options: [String]
        switch threadsNow {
        case 2:
            if let namedThread {
                options = [
                    "That makes two threads today. I\u{2019}m keeping \(namedThread) beside the first for tonight.",
                    "\(namedThread.capitalized) makes two. I\u{2019}ll braid them together this evening.",
                    "Second thread caught: \(namedThread). The Book of You is starting to gather."
                ]
            } else {
                options = [
                    "That's two threads today. Tonight I braid them together.",
                    "Two now. I'm keeping them side by side for this evening's braid.",
                    "Second thread caught. The Book of You is starting to gather."
                ]
            }
        case 3:
            if let namedThread {
                options = [
                    "\(namedThread.capitalized) makes three threads now \u{2014} enough for a strong braid tonight.",
                    "That\u{2019}s three, with \(namedThread) among them. Tonight\u{2019}s Book of You will have real weight.",
                    "Third thread: \(namedThread). The braid is going to hold beautifully this evening."
                ]
            } else {
                options = [
                    "Three threads now — enough for a strong braid tonight.",
                    "That's three. Tonight's Book of You will have real weight.",
                    "Third thread. The braid is going to hold beautifully this evening."
                ]
            }
        default:
            if let namedThread {
                options = [
                    "\(namedThread.capitalized) joins \(threadsNow) threads gathered for tonight\u{2019}s braid.",
                    "\(threadsNow) now, including \(namedThread). The Book of You is getting richer by the hour.",
                    "Another thread for the evening braid \u{2014} \(namedThread), and \(threadsNow) in all."
                ]
            } else {
                options = [
                    "That's \(threadsNow) threads gathered for tonight's braid.",
                    "\(threadsNow) now. The Book of You is getting richer by the hour.",
                    "Another thread for the evening braid — \(threadsNow) and counting."
                ]
            }
        }
        let index = Int(seed(for: "braid-gathering-\(threadsNow)") % UInt64(options.count))
        return options[index]
    }

    static func seed(for pageID: String) -> UInt64 {
        pageID.unicodeScalars.reduce(into: UInt64(1_469_598_103_934_665_603)) {
            $0 = ($0 ^ UInt64($1.value)) &* 1_099_511_628_211
        }
    }

    /// Nil when the keep is too thin to deserve ink (fewer than 3 words) or the
    /// page is one of the intimate log types that the cast never comments on.
    static func note(
        for input: String,
        pageType: BookPageType,
        pageID: String,
        beliefBySlug: [String: Int] = [:],
        priorKeepCount: Int = Int.max,
        avoidingCastSlugs: Set<String> = [],
        patronVoiceSlug: String? = nil
    ) -> Note? {
        guard isEligible(input: input, pageType: pageType) else { return nil }
        // The first-friend claim and the duet outrank the belief roll entirely.
        if priorKeepCount == 0 { return firstKeepNote }
        if priorKeepCount == 1 { return secondKeepDuetNote }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Until the library matures, the margins belong to the four greeters.
        let pool = priorKeepCount < greeterKeepThreshold
            ? voices.filter { greeterSlugs.contains($0.slug) }
            : voices

        let seed = seed(for: pageID)
        // Weighted pick: a cast member's effective Belief is their share of the
        // margins. Unknown slugs fall back to the base glow of 20.
        //
        // The reader's patron takes a larger share once the greeter clamp has
        // lifted — the character who took an interest at the naming starts
        // actually turning up. Deliberately a weight and not a guarantee: a
        // patron who answered every keep would be a mascot, and the margins
        // would stop being a place other people can surprise you from. Before
        // the clamp lifts this does nothing, because the first four faces are
        // still earning their repetition.
        let weights = pool.map { voice -> Int in
            let belief = max(1, beliefBySlug[voice.slug] ?? 20)
            let isPatron = voice.slug == patronVoiceSlug
            return isPatron ? belief + patronMarginWeightBonus : belief
        }
        let total = weights.reduce(0, +)
        var pick = Int(seed % UInt64(total))
        var voice = pool[0]
        var voiceIndex = 0
        for (index, weight) in weights.enumerated() {
            if pick < weight {
                voice = pool[index]
                voiceIndex = index
                break
            }
            pick -= weight
        }
        if avoidingCastSlugs.contains(voice.slug),
           let replacement = replacementVoice(in: pool, weights: weights, after: voiceIndex, avoiding: avoidingCastSlugs) {
            voice = replacement
        }
        let word = featuredWord(in: trimmed)
        let linePool = word == nil ? voice.plainLines : voice.plainLines + voice.wordLines
        var line = linePool[Int((seed >> 8) % UInt64(linePool.count))]
        if let word {
            line = line.replacingOccurrences(of: "{word}", with: word)
        }
        return Note(castSlug: voice.slug, castName: voice.name, assetName: voice.asset, line: line)
    }

    private static func replacementVoice(
        in pool: [Voice],
        weights: [Int],
        after selectedIndex: Int,
        avoiding avoided: Set<String>
    ) -> Voice? {
        guard pool.count > 1 else { return nil }
        let candidates = pool.indices.filter { !avoided.contains(pool[$0].slug) }
        guard !candidates.isEmpty else { return nil }
        return candidates.max {
            if weights[$0] == weights[$1] {
                let lhsDistance = ($0 - selectedIndex + pool.count) % pool.count
                let rhsDistance = ($1 - selectedIndex + pool.count) % pool.count
                return lhsDistance > rhsDistance
            }
            return weights[$0] < weights[$1]
        }.map { pool[$0] }
    }
}

/// Plain consequences for a Keep, written to sit underneath the cast's reply.
/// The character supplies delight; this supplies causal clarity. It remains a
/// pure shared-core formatter so the receipt can be pinned by focused tests.
enum KeepConsequenceReceipt {
    static func lines(
        beliefDelta: Int,
        firstReadingAwakened: Bool,
        keepsakeLine: String? = nil
    ) -> [String] {
        var lines = ["This Page is safely inside your Book now."]

        if firstReadingAwakened {
            lines.append("I've got enough of your own pages to begin my First Reading.")
        } else if let keepsakeLine = keepsakeLine?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !keepsakeLine.isEmpty {
            lines.append(keepsakeLine)
        }

        if beliefDelta > 0 {
            lines.append("Your attention kindled \(beliefDelta) Belief.")
        } else if beliefDelta < 0 {
            lines.append("\(abs(beliefDelta)) Belief crossed the threshold with this Page.")
        }

        return Array(lines.prefix(3))
    }
}

/// The visible tick when a kept page warms a cast member's Belief — cause and
/// effect on the relationship layer, at the moment of the cause.
enum BeliefRipple {
    static func line(entityName: String, effectiveBelief: Int) -> String {
        if effectiveBelief >= 60 {
            return "\(entityName) burns a little steadier for it."
        } else if effectiveBelief >= 30 {
            return "\(entityName)\u{2019}s glow brightened."
        }
        return "\(entityName)\u{2019}s glow stirred."
    }
}

// MARK: - The People of the Book
//
// The register for real people in the reader's life. It is a separate ledger
// from the Cast because the two start under different house rules — but the
// border between them belongs to the reader, not the Book:
//
//   THE READER'S HAND. By default the Book is a witness: it quotes what the
//   reader kept, notices patterns, marks absences and returns, and points
//   attention toward a person — without inventing their words. But this is
//   the reader's book, and blending reality and fiction is the whole game.
//   The reader may at any time write a real person INTO the story: the
//   thread mints a linked custom cast member, and from then on that figure
//   walks the halls like any other cast — letters, story pages, gossip, the
//   lot. The Book never makes that crossing on its own; the reader's hand
//   opens the door, one person at a time.
//
// A thread opens only by the reader's explicit confirmation — the Book may
// suggest ("this name keeps arriving in your own hand"), but it never opens a
// thread on its own, and a declined name rests permanently unless the reader
// changes their mind.

/// Where a real relationship ordinarily happens. These are affordances for
/// attention, not a ranking of importance: a shared home wants different play
/// than a work friendship or a person known mostly through messages.
enum PersonRelationshipSetting: String, Codable, CaseIterable, Equatable, Hashable {
    case sharedHome
    case family
    case friendship
    case work
    case neighborhood
    case community
    case online
    case elsewhere

    var label: String {
        switch self {
        case .sharedHome: return "Shared home"
        case .family: return "Family life"
        case .friendship: return "Friendship"
        case .work: return "Work"
        case .neighborhood: return "Neighborhood"
        case .community: return "Community"
        case .online: return "Online community"
        case .elsewhere: return "Somewhere else"
        }
    }
}

/// The ordinary channel of a relationship. A person can have several; their
/// combination matters more than any single label.
enum PersonContactChannel: String, Codable, CaseIterable, Equatable, Hashable {
    case together
    case text
    case phone
    case video
    case onlinePosts
    case letters
    case occasional

    var label: String {
        switch self {
        case .together: return "Usually together"
        case .text: return "Text"
        case .phone: return "Phone"
        case .video: return "Video calls"
        case .onlinePosts: return "Online posts"
        case .letters: return "Letters"
        case .occasional: return "Occasional meetings"
        }
    }
}

/// How freely the Book may turn its knowledge of a relationship into favors.
/// Witness-only is a hard boundary: the thread can still be remembered, but
/// never becomes an instruction to contact, repair, or deepen the relationship.
enum PersonInvitationPermission: String, Codable, CaseIterable, Equatable, Hashable {
    case playful
    case gentle
    case witnessOnly

    var label: String {
        switch self {
        case .playful: return "Invite play"
        case .gentle: return "Tread gently"
        case .witnessOnly: return "Witness only"
        }
    }
}

enum PersonRelationshipEvidenceKind: String, Codable, Equatable {
    case role
    case setting
    case channel
    case sharedInterest
    case ordinaryRitual
    case boundary
    case season
}

enum PersonRelationshipEvidenceSource: String, Codable, Equatable {
    case readerConfirmed
    case readerAuthored
    case bookInference
    case bookOffered
}

/// One attributable relationship fact. Inferences may eventually arrive here,
/// but must remain visibly different from facts the reader confirmed.
struct PersonRelationshipEvidence: Identifiable, Codable, Equatable {
    var id: String
    var kind: PersonRelationshipEvidenceKind
    var value: String
    var source: PersonRelationshipEvidenceSource
    var recordedDay: String
}

/// The changing shape of one relationship. No closeness score belongs here.
/// The purpose of this profile is to make the Book's invitations fitting: home
/// play at home, asynchronous play across text, work-safe curiosity at work.
struct PersonRelationshipProfile: Codable, Equatable {
    var roles: [String] = []
    var settings: [PersonRelationshipSetting] = []
    var channels: [PersonContactChannel] = []
    var sharedInterests: [String] = []
    var ordinaryRituals: [String] = []
    var boundaries: [String] = []
    var season: String = ""
    var invitationPermission: PersonInvitationPermission = .playful
    /// An optional local bridge to a contact the reader deliberately selected.
    /// The Book's own person id remains authoritative if Contacts later merges
    /// or changes that record.
    var contactIdentifier: String?
    var evidence: [PersonRelationshipEvidence] = []

    var isEmpty: Bool {
        roles.isEmpty && settings.isEmpty && channels.isEmpty &&
            sharedInterests.isEmpty && ordinaryRituals.isEmpty &&
            boundaries.isEmpty && season.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            contactIdentifier == nil
    }
}

/// The real-life side of the Book's knowledge graph. This is deliberately not
/// `NarrativeRelationshipEdge`: real people do not acquire simulated warmth,
/// tension, or trust scores. The graph can share the Atlas renderer while its
/// nodes, edges, and provenance remain in a separate factual realm.
enum LifeKnowledgeNodeKind: String, Codable, Equatable {
    case reader
    case person
    case role
    case setting
    case channel
    case interest
    case ritual
    case boundary
    case season
    case page
    case place
    case event
    case community
    case artifact
    case theme
}

struct LifeKnowledgeNode: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var kind: LifeKnowledgeNodeKind
}

struct LifeKnowledgeEdge: Identifiable, Codable, Equatable {
    var id: String
    var sourceID: String
    var targetID: String
    var label: String
    var provenance: PersonRelationshipEvidenceSource
    var evidenceID: String?
    var recordedDay: String
}

struct LifeKnowledgeGraph: Codable, Equatable {
    var nodes: [LifeKnowledgeNode]
    var edges: [LifeKnowledgeEdge]

    static let empty = LifeKnowledgeGraph(nodes: [], edges: [])

    /// Reuses the existing deterministic Atlas layout without leaking the
    /// fictional relationship simulation into factual people. Weight here is
    /// modest visual hierarchy by node type, never importance or closeness.
    var atlasGraph: NarrativeGraphData {
        let degree = Dictionary(grouping: edges.flatMap { [$0.sourceID, $0.targetID] }, by: { $0 })
            .mapValues(\.count)
        let graphNodes = nodes.map { node in
            let base: Double
            switch node.kind {
            case .reader: base = 28
            case .person: base = 21
            default: base = 10
            }
            return GraphNode(
                id: node.id,
                label: node.label,
                weight: base + Double(min(8, degree[node.id] ?? 0)),
                chapterID: nil,
                kindLabel: node.kind.rawValue
            )
        }
        let graphEdges = edges.map { edge in
            GraphEdge(
                id: edge.id,
                sourceID: edge.sourceID,
                targetID: edge.targetID,
                strength: edge.provenance == .readerConfirmed ? 0.72 : 0.42,
                warmth: 0,
                label: edge.label
            )
        }
        return NarrativeGraphData(nodes: graphNodes, edges: graphEdges)
    }
}

/// One real person the reader has confirmed into the Book's keeping.
struct PersonThread: Identifiable, Codable, Equatable {
    var id: String                 // "person:<slug>"
    var name: String               // written exactly as the reader writes it
    var introducedDay: String      // BookDay id ("yyyy-MM-dd")
    var readerWords: String        // the reader's own line about who this is
    var firstMentionDay: String
    var lastMentionDay: String
    var mentionPageCount: Int
    var resting: Bool = false
    var restDay: String?           // when the reader pressed the thread to rest
    /// Set when the reader writes this person into the story: the id of the
    /// linked custom cast member. The crossing is always the reader's act.
    var castMemberID: String?
    var invitedDay: String?        // when the reader opened that door
    /// Reader-confirmed relationship context. Optional keeps every existing
    /// vault decodable without pretending the Book already knows these things.
    var relationship: PersonRelationshipProfile? = nil
}

/// The reader's people ledger: confirmed threads plus names the reader has
/// asked the Book to stop suggesting. Lives in the vault beside anchors.
struct PeopleLedger: Codable, Equatable {
    var threads: [PersonThread] = []
    /// Slugs of suggested names the reader declined. Permanent quiet: the
    /// Book never re-suggests a rested name; only the reader may reopen it.
    var restingNames: [String] = []

    func thread(slug: String) -> PersonThread? {
        threads.first { $0.id == "person:\(slug)" }
    }

    func isKnown(slug: String) -> Bool {
        thread(slug: slug) != nil || restingNames.contains(slug)
    }
}

enum PeopleOfTheBook {
    // MARK: Thresholds
    //
    // Two-sided honesty, same house style as ContextWeave: the Book only
    // speaks when the evidence spans real pages and real days, and it stays
    // silent otherwise.

    /// Mid-sentence mentions on distinct pages before a name may be suggested.
    static let minimumMentionPages = 4
    /// The mentions must fall on at least this many distinct days.
    static let minimumDistinctDays = 3
    /// And span at least this many days first-to-last — a name from one
    /// intense weekend is a story, not yet a thread.
    static let minimumSpanDays = 10
    /// How long a spoken (kept) suggestion rests before the Book may ask
    /// again with grown evidence.
    static let suggestionRestDays = 60
    /// A confirmed thread quiet this long earns a gentle absence notice.
    static let quietThresholdDays = 35
    /// Beyond this, the Book stops remarking — old silence belongs to the
    /// reader, not the margins.
    static let quietCeilingDays = 240
    /// A mention this recent, after a long quiet, reads as a return.
    static let returnWindowDays = 7
    /// Rest windows for the absence and return notices themselves.
    static let quietNoticeRestDays = 90
    static let returnNoticeRestDays = 45

    /// The page kinds whose prose counts as the reader's own hand — the same
    /// authored set How You See trusts.
    static let proseTypes: Set<BookPageType> = [.diary, .souvenir, .mood, .wonderCompass, .plainPage]

    /// Words that are capitalized in ordinary English (or in this app's own
    /// lexicon) without being anyone's name. Cast names, custom cast, and the
    /// reader's own name arrive via `excludedNames` from the caller.
    static let commonCapitalizedWords: Set<String> = [
        // Self-reference and contractions.
        "i", "i'm", "i'll", "i've", "i'd",
        // Calendar.
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july",
        "august", "september", "october", "november", "december",
        "christmas", "easter", "thanksgiving", "halloween", "hanukkah", "ramadan",
        "new", "year", "eve",
        // The app's own capitalized vocabulary, which readers borrow.
        "book", "academy", "belief", "glow", "nothing", "routine", "labyrinth",
        "stacks", "bleed", "radio", "almanac", "compass", "chapter", "chapters",
        "fae", "goblin", "market", "bindery", "pocket", "margin", "margins",
        "pact", "talisman", "gemma", "wonder", "sky", "notices", "remembered",
        // Frequent mid-sentence capitals that are not people.
        "god", "ok", "okay", "internet", "youtube", "google", "netflix",
        "instagram", "tiktok", "amazon", "target", "costco", "ikea", "zoom",
        "covid", "tv", "gps", "ai", "usa", "america", "american", "english",
        "north", "south", "east", "west", "street", "avenue", "park", "harbor",
        "dr", "mr", "mrs", "ms", "st"
    ]

    /// A capitalized word followed by one of these is much more likely to be
    /// a place or institution than a person (Harbor Market, Union Station,
    /// Congress Street). The Book may still learn a person with the same word
    /// when the reader explicitly opens that thread; it simply must not infer
    /// one from place-shaped prose.
    static let placeDesignators: Set<String> = [
        "airport", "avenue", "bakery", "beach", "bridge", "building",
        "cafe", "church", "cinema", "college", "garden", "harbor",
        "hospital", "hotel", "library", "market", "museum", "park",
        "pier", "plaza", "road", "school", "square", "station",
        "store", "street", "terminal", "theater", "theatre", "university"
    ]

    static func slug(for name: String) -> String {
        name.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, char in
                if char == "-" && result.hasSuffix("-") { return }
                result.append(char)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // MARK: Suggestion — "this name keeps arriving in your own hand"

    struct PersonSuggestion: Equatable {
        var name: String
        var slug: String
        var mentionPageCount: Int
        var distinctDayCount: Int
        var firstDayID: String
        var lastDayID: String
        var evidencePageIDs: [String]
        /// One sentence of the reader's own, containing the name — the same
        /// quoted-evidence pattern the other notices use.
        var sampleQuote: String
    }

    /// Names that keep arriving mid-sentence in the reader's own prose, with
    /// enough pages, days, and span behind them to be worth asking about.
    /// Deterministic; silent when the archive cannot meet the standard.
    static func suggestions(
        days: [BookDay],
        ledger: PeopleLedger,
        excludedNames: Set<String>,
        now: Date
    ) -> [PersonSuggestion] {
        var excluded = commonCapitalizedWords
        for name in excludedNames {
            excluded.insert(name.lowercased())
            for part in name.split(separator: " ") {
                excluded.insert(part.lowercased())
            }
        }

        struct Sighting {
            var pageID: String
            var dayID: String
            var date: Date
            var sentence: String
        }

        var sightings: [String: [Sighting]] = [:]
        var lowercaseCounts: [String: Int] = [:]

        for page in authoredPages(in: days) {
            let dayID = BookDay.id(for: page.createdAt)
            for sentence in sentences(in: page.userInput) {
                let words = tokens(in: sentence)
                for (index, word) in words.enumerated() {
                    let lowered = word.lowercased()
                    if word == lowered {
                        lowercaseCounts[lowered, default: 0] += 1
                        continue
                    }
                    // Only mid-sentence capitals count as name evidence; a
                    // sentence-opening capital proves nothing.
                    let nextWord = index + 1 < words.count
                        ? words[index + 1].lowercased()
                        : nil
                    guard index > 0,
                          isNameShaped(word),
                          !excluded.contains(lowered),
                          nextWord.map({ !placeDesignators.contains($0) }) ?? true
                    else { continue }
                    sightings[word, default: []].append(
                        Sighting(pageID: page.id, dayID: dayID, date: page.createdAt, sentence: sentence)
                    )
                }
            }
        }

        var results: [PersonSuggestion] = []
        for (name, seen) in sightings {
            let candidateSlug = slug(for: name)
            guard !candidateSlug.isEmpty, !ledger.isKnown(slug: candidateSlug) else { continue }
            // A word the reader also writes lowercased as often is a common
            // noun wearing a capital, not a person.
            if lowercaseCounts[name.lowercased(), default: 0] >= seen.count { continue }

            var byPage: [String: Sighting] = [:]
            for sighting in seen where byPage[sighting.pageID] == nil {
                byPage[sighting.pageID] = sighting
            }
            let pageSightings = byPage.values.sorted { $0.date < $1.date }
            let distinctDays = Set(pageSightings.map(\.dayID))
            guard pageSightings.count >= minimumMentionPages,
                  distinctDays.count >= minimumDistinctDays,
                  let first = pageSightings.first,
                  let last = pageSightings.last,
                  last.date.timeIntervalSince(first.date) >= TimeInterval(minimumSpanDays) * 86_400
            else { continue }

            let quote = pageSightings
                .map(\.sentence)
                .sorted { ($0.count, $0) < ($1.count, $1) }
                .first ?? ""
            results.append(
                PersonSuggestion(
                    name: name,
                    slug: candidateSlug,
                    mentionPageCount: pageSightings.count,
                    distinctDayCount: distinctDays.count,
                    firstDayID: first.dayID,
                    lastDayID: last.dayID,
                    evidencePageIDs: pageSightings.suffix(6).map(\.pageID),
                    sampleQuote: clipped(quote)
                )
            )
        }

        return results.sorted {
            if $0.mentionPageCount != $1.mentionPageCount {
                return $0.mentionPageCount > $1.mentionPageCount
            }
            return $0.name < $1.name
        }
        .prefix(3)
        .map { $0 }
    }

    /// The thread a confirming reader opens from a suggestion. `readerWords`
    /// may be empty at first; the reader can add who this is later.
    static func confirmed(_ suggestion: PersonSuggestion, onDay dayID: String, readerWords: String = "") -> PersonThread {
        PersonThread(
            id: "person:\(suggestion.slug)",
            name: suggestion.name,
            introducedDay: dayID,
            readerWords: readerWords,
            firstMentionDay: suggestion.firstDayID,
            lastMentionDay: suggestion.lastDayID,
            mentionPageCount: suggestion.mentionPageCount
        )
    }

    // MARK: Mentions of a confirmed thread

    struct MentionRecord: Equatable {
        var pageDates: [Date]      // ascending, one per mentioning page
        var lastDayID: String?
    }

    /// Where a confirmed name appears in the reader's own prose. Once a
    /// thread is open, sentence-opening mentions count too — the standard of
    /// proof belongs to the suggestion, not to the keeping.
    static func mentions(of thread: PersonThread, in days: [BookDay]) -> MentionRecord {
        var dates: [Date] = []
        var lastDay: String?
        for page in authoredPages(in: days) {
            guard containsWholeWord(thread.name, in: page.userInput) else { continue }
            dates.append(page.createdAt)
        }
        dates.sort()
        if let last = dates.last {
            lastDay = BookDay.id(for: last)
        }
        return MentionRecord(pageDates: dates, lastDayID: lastDay)
    }

    // MARK: Quiet and return

    struct PersonQuietSignal: Equatable {
        enum Kind: String {
            case goneQuiet
            case returned
        }

        var thread: PersonThread
        var kind: Kind
        var quietDays: Int
        var lastMentionDayID: String
    }

    /// Threads gone quiet, or freshly returned after a long quiet. Only
    /// threads with real history speak; resting threads never do. The signal
    /// is an observation for the notices page — never a prescription.
    static func quietSignals(ledger: PeopleLedger, days: [BookDay], now: Date) -> [PersonQuietSignal] {
        var signals: [PersonQuietSignal] = []
        for thread in ledger.threads where !thread.resting {
            let record = mentions(of: thread, in: days)
            let mentionDays = Set(record.pageDates.map { BookDay.id(for: $0) })
            guard record.pageDates.count >= minimumMentionPages,
                  mentionDays.count >= minimumDistinctDays,
                  let lastDate = record.pageDates.last,
                  let lastDayID = record.lastDayID
            else { continue }

            let quietDays = Int(now.timeIntervalSince(lastDate) / 86_400)
            if quietDays >= quietThresholdDays && quietDays <= quietCeilingDays {
                signals.append(
                    PersonQuietSignal(thread: thread, kind: .goneQuiet, quietDays: quietDays, lastMentionDayID: lastDayID)
                )
            } else if quietDays <= returnWindowDays, record.pageDates.count >= 2 {
                let previous = record.pageDates[record.pageDates.count - 2]
                let gapDays = Int(lastDate.timeIntervalSince(previous) / 86_400)
                if gapDays >= quietThresholdDays {
                    signals.append(
                        PersonQuietSignal(thread: thread, kind: .returned, quietDays: gapDays, lastMentionDayID: lastDayID)
                    )
                }
            }
        }
        return signals.sorted { $0.thread.name < $1.thread.name }
    }

    /// The rest ritual: the reader presses a thread to rest and the Book
    /// keeps it gently — no more suggestions, no more absence remarks.
    static func rested(_ thread: PersonThread, onDay dayID: String) -> PersonThread {
        var updated = thread
        updated.resting = true
        updated.restDay = dayID
        return updated
    }

    /// The crossing: the reader writes this person into the story. The
    /// witness thread stays (real pages keep accruing to it); the linked
    /// cast member carries the fictional life from here on.
    static func invitedIntoStory(_ thread: PersonThread, castMemberID: String, onDay dayID: String) -> PersonThread {
        var updated = thread
        updated.castMemberID = castMemberID
        updated.invitedDay = dayID
        return updated
    }

    // MARK: Text helpers

    private static func authoredPages(in days: [BookDay]) -> [BookPage] {
        days.flatMap(\.capturedPages).filter { page in
            proseTypes.contains(page.type)
                && page.origin == .userAuthored
                && !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func sentences(in text: String) -> [String] {
        text.split(whereSeparator: { ".!?\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func tokens(in sentence: String) -> [String] {
        sentence.split(whereSeparator: { !($0.isLetter || $0 == "'" || $0 == "\u{2019}") })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Name-shaped: a leading capital, a lowercase body, letters only, and at
    /// least three characters. "SAM" (shouting), "iPhone", and initialisms
    /// all fail on purpose.
    private static func isNameShaped(_ word: String) -> Bool {
        guard word.count >= 3, let first = word.first, first.isUppercase else { return false }
        let body = word.dropFirst().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        guard !body.isEmpty else { return false }
        return body.allSatisfy { $0.isLetter && $0.isLowercase }
    }

    private static func containsWholeWord(_ word: String, in text: String) -> Bool {
        var start = text.startIndex
        while let range = text.range(of: word, range: start..<text.endIndex) {
            let beforeOK = range.lowerBound == text.startIndex
                || !text[text.index(before: range.lowerBound)].isLetter
            let afterOK = range.upperBound == text.endIndex
                || !text[range.upperBound].isLetter
            if beforeOK && afterOK { return true }
            start = range.upperBound
        }
        return false
    }

    private static func clipped(_ text: String, limit: Int = 110) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        if let lastSpace = cut.lastIndex(of: " ") {
            return String(cut[..<lastSpace]) + "\u{2026}"
        }
        return String(cut) + "\u{2026}"
    }
}

// MARK: - The Pre-Meeting Charge
//
// MARK: Relationship ecology and ordinary-life play

extension PeopleOfTheBook {
    enum InvitationFamily: String, Equatable {
        case sharedHome
        case asynchronous
        case workAndInterest
        case work
        case community
        case sharedInterest
        case gentle
        case general
    }

    struct RelationshipInvitation: Equatable {
        var id: String
        var personID: String
        var personName: String
        var family: InvitationFamily
        var title: String
        var body: String
        var keepPrompt: String
        var tags: [String]
    }

    struct RelationshipHypothesis: Equatable {
        enum Kind: String, Equatable {
            case role
            case setting
            case channel
            case sharedInterest
        }

        var id: String
        var personID: String
        var personName: String
        var kind: Kind
        /// Enum raw value for setting/channel; reader-facing text otherwise.
        var value: String
        var displayValue: String
        var question: String
        var evidencePageIDs: [String]
        var evidenceQuote: String
    }

    private struct InvitationTemplate {
        var id: String
        var title: (String, String?) -> String
        var body: (String, String?) -> String
        var proof: (String, String?) -> String
    }

    /// Cleans and attributes a profile saved by the reader. This deliberately
    /// converts the visible active facts to reader-confirmed evidence; a future
    /// inference path must use `.bookInference` and ask before calling this.
    static func readerConfirmedProfile(
        _ proposed: PersonRelationshipProfile,
        onDay dayID: String
    ) -> PersonRelationshipProfile {
        var profile = proposed
        profile.roles = cleaned(proposed.roles)
        profile.settings = unique(proposed.settings)
        profile.channels = unique(proposed.channels)
        profile.sharedInterests = cleaned(proposed.sharedInterests)
        profile.ordinaryRituals = cleaned(proposed.ordinaryRituals)
        profile.boundaries = cleaned(proposed.boundaries)
        profile.season = proposed.season.trimmingCharacters(in: .whitespacesAndNewlines)

        var evidence: [PersonRelationshipEvidence] = []
        func append(_ kind: PersonRelationshipEvidenceKind, _ value: String) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            evidence.append(
                PersonRelationshipEvidence(
                    id: "\(kind.rawValue):\(normalized.lowercased().stableHash)",
                    kind: kind,
                    value: normalized,
                    source: .readerConfirmed,
                    recordedDay: dayID
                )
            )
        }
        profile.roles.forEach { append(.role, $0) }
        profile.settings.forEach { append(.setting, $0.label) }
        profile.channels.forEach { append(.channel, $0.label) }
        profile.sharedInterests.forEach { append(.sharedInterest, $0) }
        profile.ordinaryRituals.forEach { append(.ordinaryRitual, $0) }
        profile.boundaries.forEach { append(.boundary, $0) }
        append(.season, profile.season)
        profile.evidence = evidence
        return profile
    }

    /// Builds the factual human constellation as a derived graph. Shared
    /// interests, settings, and rituals become common nodes, so two people can
    /// visibly meet through "AI", "the studio", or "Sunday dinner" without the
    /// Book inventing a direct relationship between them.
    static func knowledgeGraph(ledger: PeopleLedger, days: [BookDay] = []) -> LifeKnowledgeGraph {
        var nodes: [String: LifeKnowledgeNode] = [
            "life:reader": LifeKnowledgeNode(id: "life:reader", label: "You", kind: .reader)
        ]
        var edges: [LifeKnowledgeEdge] = []
        let graphPages = Dictionary(
            authoredPages(in: days).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        ).values
        let receiptPages = Dictionary(
            days.flatMap(\.pages)
                .filter { $0.relationshipReceipt != nil }
                .map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        ).values

        for thread in ledger.threads where !thread.resting {
            nodes[thread.id] = LifeKnowledgeNode(id: thread.id, label: thread.name, kind: .person)
            let profile = thread.relationship ?? PersonRelationshipProfile()
            let readerLabel = profile.roles.first?.nonEmpty ?? "in your book"
            edges.append(
                LifeKnowledgeEdge(
                    id: "life-edge:reader:\(thread.id)",
                    sourceID: "life:reader",
                    targetID: thread.id,
                    label: readerLabel,
                    provenance: .readerConfirmed,
                    evidenceID: profile.evidence.first(where: { $0.kind == .role })?.id,
                    recordedDay: thread.introducedDay
                )
            )

            func attach(
                _ value: String,
                kind: LifeKnowledgeNodeKind,
                evidenceKind: PersonRelationshipEvidenceKind,
                label: String
            ) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let token = slug(for: trimmed).nonEmpty ?? String(trimmed.lowercased().stableHash)
                let nodeID = "life:\(kind.rawValue):\(token)"
                nodes[nodeID] = LifeKnowledgeNode(id: nodeID, label: trimmed, kind: kind)
                let evidence = profile.evidence.first {
                    $0.kind == evidenceKind && $0.value.caseInsensitiveCompare(trimmed) == .orderedSame
                }
                edges.append(
                    LifeKnowledgeEdge(
                        id: "life-edge:\(thread.id):\(kind.rawValue):\(token)",
                        sourceID: thread.id,
                        targetID: nodeID,
                        label: label,
                        provenance: evidence?.source ?? .readerConfirmed,
                        evidenceID: evidence?.id,
                        recordedDay: evidence?.recordedDay ?? thread.introducedDay
                    )
                )
            }

            profile.roles.forEach { attach($0, kind: .role, evidenceKind: .role, label: "is your") }
            profile.settings.forEach { attach($0.label, kind: .setting, evidenceKind: .setting, label: "usually in") }
            profile.channels.forEach { attach($0.label, kind: .channel, evidenceKind: .channel, label: "usually by") }
            profile.sharedInterests.forEach { attach($0, kind: .interest, evidenceKind: .sharedInterest, label: "shares") }
            profile.ordinaryRituals.forEach { attach($0, kind: .ritual, evidenceKind: .ordinaryRitual, label: "returns through") }
            profile.boundaries.forEach { attach($0, kind: .boundary, evidenceKind: .boundary, label: "respects") }
            attach(profile.season, kind: .season, evidenceKind: .season, label: "now in")

            // A small receipt-bearing bridge into the existing archive graph.
            // Shared pages naturally connect two people without asserting they
            // know one another, and the cap keeps the Atlas legible.
            let mentioningPages = graphPages
                .filter { containsWholeWord(thread.name, in: $0.userInput) }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
            for page in mentioningPages {
                let pageID = "life:page:\(page.id)"
                let excerpt = page.userInput
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .bookPreviewSentenceLimit(1)
                nodes[pageID] = LifeKnowledgeNode(
                    id: pageID,
                    label: excerpt.nonEmpty ?? page.type.shortTitle,
                    kind: .page
                )
                edges.append(
                    LifeKnowledgeEdge(
                        id: "life-edge:\(thread.id):page:\(page.id)",
                        sourceID: thread.id,
                        targetID: pageID,
                        label: "appears in",
                        provenance: .readerAuthored,
                        evidenceID: page.id,
                        recordedDay: BookDay.id(for: page.createdAt)
                    )
                )
            }

            // Relational finds and favors are archive artifacts too. A Book
            // offer uses `bookOffered`; only an aftermath the reader actually
            // wrote earns `readerAuthored` provenance.
            let threadReceipts = receiptPages
                .filter { $0.relationshipReceipt?.personID == thread.id }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
            for page in threadReceipts {
                guard let receipt = page.relationshipReceipt else { continue }
                let artifactID = "life:artifact:\(page.id)"
                let label = receipt.readerAftermath?.bookPreviewSentenceLimit(1).nonEmpty
                    ?? receipt.bookOffer
                nodes[artifactID] = LifeKnowledgeNode(
                    id: artifactID,
                    label: label,
                    kind: .artifact
                )
                edges.append(
                    LifeKnowledgeEdge(
                        id: "life-edge:\(thread.id):artifact:\(page.id)",
                        sourceID: thread.id,
                        targetID: artifactID,
                        label: receipt.readerAftermath == nil ? "was offered" : "became a page through",
                        provenance: receipt.readerAftermath == nil ? .bookOffered : .readerAuthored,
                        evidenceID: page.id,
                        recordedDay: BookDay.id(for: page.createdAt)
                    )
                )
            }
        }
        return LifeKnowledgeGraph(
            nodes: nodes.values.sorted { $0.id < $1.id },
            edges: edges.sorted { $0.id < $1.id }
        )
    }

    /// Conservative, deterministic hypotheses from explicit reader-authored
    /// language. The output is only a question: callers must never persist it
    /// until the reader confirms it.
    static func relationshipHypotheses(for thread: PersonThread, days: [BookDay]) -> [RelationshipHypothesis] {
        let profile = thread.relationship ?? PersonRelationshipProfile()
        let pages = Dictionary(
            authoredPages(in: days).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        ).values
            .filter { containsWholeWord(thread.name, in: $0.userInput) }
            .sorted { $0.createdAt > $1.createdAt }
        guard !pages.isEmpty else { return [] }
        let name = thread.name.lowercased()
        let slug = slug(for: thread.name)
        var hypotheses: [RelationshipHypothesis] = []

        func add(
            kind: RelationshipHypothesis.Kind,
            value: String,
            displayValue: String,
            question: String,
            evidence: [BookPage]
        ) {
            guard let first = evidence.first else { return }
            hypotheses.append(
                RelationshipHypothesis(
                    id: "person-context-\(slug)-\(kind.rawValue)-\(self.slug(for: value))",
                    personID: thread.id,
                    personName: thread.name,
                    kind: kind,
                    value: value,
                    displayValue: displayValue,
                    question: question,
                    evidencePageIDs: evidence.prefix(3).map(\.id),
                    evidenceQuote: first.userInput.bookPreviewSentenceLimit(2)
                )
            )
        }

        let explicitRoles = ["wife", "husband", "partner", "spouse", "sister", "brother", "mother", "father", "parent", "daughter", "son", "friend", "coworker", "neighbor"]
        let existingRoles = Set(profile.roles.map { $0.lowercased() })
        for role in explicitRoles where !existingRoles.contains(role) {
            if let page = pages.first(where: {
                let text = $0.userInput.lowercased()
                return text.contains("my \(role) \(name)") || text.contains("\(name) is my \(role)")
            }) {
                add(
                    kind: .role,
                    value: role,
                    displayValue: role,
                    question: "Should I remember that \(thread.name) is your \(role)?",
                    evidence: [page]
                )
                break
            }
        }

        if !profile.settings.contains(.sharedHome),
           let page = pages.first(where: {
               let text = $0.userInput.lowercased()
               return text.contains("live with \(name)") || text.contains("\(name) and i live together") || text.contains("share a home with \(name)")
           }) {
            add(
                kind: .setting,
                value: PersonRelationshipSetting.sharedHome.rawValue,
                displayValue: PersonRelationshipSetting.sharedHome.label,
                question: "Do you and \(thread.name) share a home?",
                evidence: [page]
            )
        }

        if !profile.settings.contains(.work),
           let page = pages.first(where: {
               let text = $0.userInput.lowercased()
               return text.contains("work with \(name)") || text.contains("my coworker \(name)") || text.contains("\(name), my coworker") || text.contains("\(name) at work")
           }) {
            add(
                kind: .setting,
                value: PersonRelationshipSetting.work.rawValue,
                displayValue: PersonRelationshipSetting.work.label,
                question: "Should I understand \(thread.name) as part of your working life?",
                evidence: [page]
            )
        }

        if !profile.channels.contains(.text) {
            let textingPages = pages.filter {
                let text = $0.userInput.lowercased()
                return text.contains("texted \(name)") || text.contains("text \(name)") || text.contains("\(name) texted") || text.contains("texts with \(name)")
            }
            if textingPages.count >= 2 {
                add(
                    kind: .channel,
                    value: PersonContactChannel.text.rawValue,
                    displayValue: PersonContactChannel.text.label,
                    question: "Does your relationship with \(thread.name) usually travel by text?",
                    evidence: textingPages
                )
            }
        }

        if profile.sharedInterests.isEmpty {
            let interestPatterns = [
                "\(name) and i talk about ",
                "\(name) and i talked about ",
                "i talk with \(name) about ",
                "i talked with \(name) about "
            ]
            outer: for page in pages {
                let lowered = page.userInput.lowercased() as NSString
                for pattern in interestPatterns {
                    let range = lowered.range(of: pattern)
                    guard range.location != NSNotFound else { continue }
                    let start = range.location + range.length
                    let tail = (page.userInput as NSString).substring(from: start)
                    let sentence = tail.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first ?? ""
                    let interest = sentence
                        .split(whereSeparator: \.isWhitespace)
                        .prefix(5)
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard interest.count >= 2, interest.count <= 60 else { continue }
                    add(
                        kind: .sharedInterest,
                        value: interest,
                        displayValue: interest,
                        question: "Is \(interest) something you and \(thread.name) share?",
                        evidence: [page]
                    )
                    break outer
                }
            }
        }

        return hypotheses
    }

    /// One fitting invitation for a relationship on a given day. Nothing here
    /// ranks closeness or guesses what the other person feels. It only changes
    /// the *kind* of door offered from context the reader confirmed.
    static func relationshipInvitation(for thread: PersonThread, onDay dayID: String) -> RelationshipInvitation? {
        let profile = thread.relationship ?? PersonRelationshipProfile()
        guard profile.invitationPermission != .witnessOnly else { return nil }

        let family = invitationFamily(for: profile)
        let interest = profile.sharedInterests.first
        let templates = invitationTemplates(for: family)
        guard !templates.isEmpty else { return nil }
        let seed = abs("\(thread.id)|\(dayID)|\(family.rawValue)".stableHash)
        let template = templates[seed % templates.count]
        let slug = slug(for: thread.name)
        return RelationshipInvitation(
            id: "person-play-\(slug)-\(template.id)-\(dayID)",
            personID: thread.id,
            personName: thread.name,
            family: family,
            title: template.title(thread.name, interest),
            body: template.body(thread.name, interest),
            keepPrompt: template.proof(thread.name, interest),
            tags: [
                "people", "connection", "person-play", "person:\(slug)",
                "relationship-mode:\(family.rawValue)", "spoke:person-play-\(slug)"
            ]
        )
    }

    static func invitationFamily(for profile: PersonRelationshipProfile) -> InvitationFamily {
        if profile.invitationPermission == .gentle { return .gentle }
        let settings = Set(profile.settings)
        let channels = Set(profile.channels)
        if settings.contains(.sharedHome) { return .sharedHome }
        if settings.contains(.work) && !profile.sharedInterests.isEmpty { return .workAndInterest }
        if settings.contains(.work) { return .work }
        if channels.contains(.text) || channels.contains(.letters) || channels.contains(.phone) || channels.contains(.video) {
            return .asynchronous
        }
        if settings.contains(.community) || settings.contains(.online) || channels.contains(.onlinePosts) {
            return .community
        }
        if !profile.sharedInterests.isEmpty { return .sharedInterest }
        return .general
    }

    private static func invitationTemplates(for family: InvitationFamily) -> [InvitationTemplate] {
        switch family {
        case .sharedHome:
            return [
                InvitationTemplate(
                    id: "invisible-house",
                    title: { name, _ in "The invisible house, with \(name)" },
                    body: { name, _ in "Each choose one thing in your shared space the other has stopped seeing. Trade discoveries." },
                    proof: { name, _ in "Keep the thing \(name) returned to sight." }
                ),
                InvitationTemplate(
                    id: "era-name",
                    title: { name, _ in "Ask \(name) to name this era" },
                    body: { name, _ in "Ask what this particular era of your life together will eventually be called. You must answer too." },
                    proof: { name, _ in "Keep both names for the era — yours and \(name)'s." }
                ),
                InvitationTemplate(
                    id: "domestic-magic",
                    title: { name, _ in "A small domestic conspiracy" },
                    body: { name, _ in "Make one ordinary part of \(name)'s day unexpectedly lovely. Do not explain unless accused." },
                    proof: { _, _ in "Keep what you changed, and what happened next." }
                )
            ]
        case .asynchronous:
            return [
                InvitationTemplate(
                    id: "photo-no-map",
                    title: { name, _ in "One unlabelled window for \(name)" },
                    body: { name, _ in "Send \(name) one photograph from ordinary today without explaining it. Let them decide what deserves noticing." },
                    proof: { _, _ in "Keep the photograph or the story it opened." }
                ),
                InvitationTemplate(
                    id: "memory-dispute",
                    title: { name, _ in "A memory with two owners" },
                    body: { name, _ in "Ask \(name) for one shared memory they may remember differently. Curiosity only; no verdict is required." },
                    proof: { name, _ in "Keep one difference in how you and \(name) remembered it." }
                ),
                InvitationTemplate(
                    id: "voice-neighbor",
                    title: { name, _ in "The neighboring door" },
                    body: { name, _ in "Use the next-nearest channel once: if you usually text \(name), send a short voice note; if you usually call, send one strange photograph." },
                    proof: { _, _ in "Keep what changed when the channel changed." }
                )
            ]
        case .workAndInterest:
            return [
                InvitationTemplate(
                    id: "found-for-two",
                    title: { name, interest in "Here. I found a door for you and \(name)." },
                    body: { name, interest in "Bring \(name) one small, arguable thing about \(interest ?? "the subject you share"). Do not send a summary; ask what they think it gets wrong." },
                    proof: { name, _ in "Keep the point where you and \(name) disagreed or surprised each other." }
                ),
                InvitationTemplate(
                    id: "same-problem",
                    title: { name, interest in "A two-mind experiment with \(name)" },
                    body: { name, interest in "Each use \(interest ?? "your shared interest") on the same peculiar problem. Compare what each of you asked it to do." },
                    proof: { _, _ in "Keep the most revealing difference between the two approaches." }
                ),
                InvitationTemplate(
                    id: "magic-and-fraud",
                    title: { name, interest in "The magic and the fraud" },
                    body: { name, interest in "Ask \(name) which part of \(interest ?? "your shared subject") feels most like magic, and which part feels like fraud committed by ghosts." },
                    proof: { name, _ in "Keep \(name)'s distinction in their exact words." }
                )
            ]
        case .work:
            return [
                InvitationTemplate(
                    id: "secret-craft",
                    title: { name, _ in "The secret craft in \(name)'s work" },
                    body: { name, _ in "Ask \(name) which part of their work is secretly craft — the part outsiders would never know requires taste." },
                    proof: { name, _ in "Keep the craft \(name) named." }
                ),
                InvitationTemplate(
                    id: "uncredited-ease",
                    title: { name, _ in "Watch what \(name) makes easier" },
                    body: { name, _ in "Notice one way \(name) makes the working day easier without receiving credit for it." },
                    proof: { _, _ in "Keep the small act that usually disappears into work." }
                ),
                InvitationTemplate(
                    id: "before-employable",
                    title: { name, _ in "Before \(name) became employable" },
                    body: { name, _ in "If the moment is natural, ask what \(name) was obsessed with before work taught everyone the approved questions." },
                    proof: { name, _ in "Keep the old obsession \(name) revealed." }
                )
            ]
        case .community:
            return [
                InvitationTemplate(
                    id: "edge-of-room",
                    title: { name, _ in "Ask \(name) about the edge of the room" },
                    body: { name, _ in "Ask what first made \(name) stop watching this community from the edge and take part." },
                    proof: { _, _ in "Keep the hinge between watching and belonging." }
                ),
                InvitationTemplate(
                    id: "teach-forward",
                    title: { name, _ in "Return one spark through \(name)" },
                    body: { name, _ in "Tell \(name) one specific thing their participation taught or changed for you. Small and exact beats grand." },
                    proof: { _, _ in "Keep the specific influence you finally named." }
                )
            ]
        case .sharedInterest:
            return [
                InvitationTemplate(
                    id: "two-curators",
                    title: { name, interest in "Two curators of \(interest ?? "one fascination")" },
                    body: { name, interest in "You and \(name) each choose one thing about \(interest ?? "your shared interest") the other person should not miss." },
                    proof: { name, _ in "Keep what \(name) chose for your attention." }
                ),
                InvitationTemplate(
                    id: "changed-mind",
                    title: { name, interest in "The changed mind of \(name)" },
                    body: { name, interest in "Ask \(name) what they used to believe about \(interest ?? "your shared interest") and no longer do." },
                    proof: { _, _ in "Keep the before and after." }
                )
            ]
        case .gentle:
            return [
                InvitationTemplate(
                    id: "one-detail",
                    title: { name, _ in "One unforced detail of \(name)" },
                    body: { name, _ in "If \(name) naturally enters the day, notice one particular thing without asking the relationship to become anything else." },
                    proof: { _, _ in "Keep the detail, or let it remain unrecorded." }
                ),
                InvitationTemplate(
                    id: "quiet-gift",
                    title: { name, _ in "What \(name) quietly brought" },
                    body: { name, _ in "Without contacting \(name), remember one thing their existence added to your life." },
                    proof: { _, _ in "Keep it only if keeping feels kinder than silence." }
                )
            ]
        case .general:
            return [
                InvitationTemplate(
                    id: "borrowed-eye",
                    title: { name, _ in "Borrow \(name)'s eyes" },
                    body: { name, _ in "Ask \(name) what they noticed today. For one minute, let their answer become the center of the world." },
                    proof: { name, _ in "Keep what \(name) noticed, in their words." }
                ),
                InvitationTemplate(
                    id: "uncut-detail",
                    title: { name, _ in "The uncut detail of \(name)" },
                    body: { name, _ in "Find the one detail about \(name) an honest author would refuse to cut." },
                    proof: { _, _ in "Keep the detail without explaining what it means." }
                ),
                InvitationTemplate(
                    id: "changed",
                    title: { name, _ in "Look again at \(name)" },
                    body: { name, _ in "Notice one thing about \(name) that has changed since you first learned how to see them." },
                    proof: { _, _ in "Keep the change, and the older picture beside it." }
                )
            ]
        }
    }

    private static func cleaned(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { return nil }
            return value
        }
    }

    private static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }
}

// MARK: The Company You Kept

/// A living relational volume derived from the same kept Pages as the rest of
/// the Book. It is not a closeness ranking and has no synthetic relationship
/// score: it binds attributed encounters, Book offers, and reader-written
/// aftermath across lived time.
struct CompanyYouKeptVolume: Equatable {
    enum Scope: Equatable {
        case lifetime
        case year(Int)
    }

    struct Entry: Identifiable, Equatable {
        enum Authority: String, Equatable {
            case readerWords
            case readerAftermath
            case bookOffer

            var label: String {
                switch self {
                case .readerWords: return "From your own page"
                case .readerAftermath: return "What you said happened"
                case .bookOffer: return "A door I offered"
                }
            }
        }

        var id: String
        var pageID: String
        var date: Date
        var title: String
        var text: String
        var authority: Authority
        var externalReference: BookPageExternalReference?
    }

    struct Chapter: Identifiable, Equatable {
        var id: String
        var name: String
        var readerWords: String
        var roles: [String]
        var sharedInterests: [String]
        var ordinaryRituals: [String]
        var firstDay: String
        var lastDay: String
        var entries: [Entry]

        var readerWrittenCount: Int {
            entries.filter { $0.authority != .bookOffer }.count
        }
    }

    var title: String
    var subtitle: String
    var generatedAt: Date
    var scope: Scope
    var chapters: [Chapter]
    var foreword: String
    var closing: String

    var entryCount: Int { chapters.reduce(0) { $0 + $1.entries.count } }
    var readerWrittenCount: Int { chapters.reduce(0) { $0 + $1.readerWrittenCount } }

    var shareText: String {
        var parts = [title, subtitle, "", foreword]
        for chapter in chapters {
            parts.append("\n\(chapter.name)")
            if !chapter.readerWords.isEmpty { parts.append(chapter.readerWords) }
            for entry in chapter.entries.prefix(12) {
                parts.append("\n\(entry.title) — \(entry.authority.label)\n\(entry.text)")
                if let url = entry.externalReference?.url { parts.append(url) }
            }
        }
        parts.append("\n\(closing)")
        return parts.joined(separator: "\n")
    }
}

extension PeopleOfTheBook {
    static func companyYouKept(
        ledger: PeopleLedger,
        days: [BookDay],
        scope: CompanyYouKeptVolume.Scope = .lifetime,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CompanyYouKeptVolume {
        let uniquePages = Dictionary(
            days.flatMap(\.pages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        ).values
        let scopedPages = uniquePages.filter { page in
            switch scope {
            case .lifetime: return true
            case .year(let year): return calendar.component(.year, from: page.createdAt) == year
            }
        }

        let chapters = ledger.threads.compactMap { thread -> CompanyYouKeptVolume.Chapter? in
            let slug = slug(for: thread.name)
            let tag = "person:\(slug)"
            var entries: [CompanyYouKeptVolume.Entry] = []

            for page in scopedPages.sorted(by: { $0.createdAt < $1.createdAt }) {
                if let receipt = page.relationshipReceipt, receipt.personID == thread.id {
                    if let aftermath = receipt.readerAftermath?.nonEmpty {
                        entries.append(
                            CompanyYouKeptVolume.Entry(
                                id: "company:\(page.id):aftermath",
                                pageID: page.id,
                                date: page.createdAt,
                                title: receipt.bookOffer,
                                text: aftermath,
                                authority: .readerAftermath,
                                externalReference: page.externalReference
                            )
                        )
                    } else {
                        entries.append(
                            CompanyYouKeptVolume.Entry(
                                id: "company:\(page.id):offer",
                                pageID: page.id,
                                date: page.createdAt,
                                title: receipt.bookOffer,
                                text: receipt.sharedInterest.map { "Found for the two of you through \($0)." }
                                    ?? "I offered this and made no claim about what followed.",
                                authority: .bookOffer,
                                externalReference: page.externalReference
                            )
                        )
                    }
                    continue
                }

                let readerAuthored = proseTypes.contains(page.type) && page.origin == .userAuthored
                guard readerAuthored,
                      (page.tags.contains(tag) || containsWholeWord(thread.name, in: page.userInput)),
                      let excerpt = page.userInput
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .bookPreviewSentenceLimit(2)
                        .nonEmpty else {
                    continue
                }
                entries.append(
                    CompanyYouKeptVolume.Entry(
                        id: "company:\(page.id):words",
                        pageID: page.id,
                        date: page.createdAt,
                        title: page.promptText.nonEmpty ?? page.type.shortTitle,
                        text: excerpt,
                        authority: .readerWords,
                        externalReference: nil
                    )
                )
            }

            guard !entries.isEmpty || scope == .lifetime else { return nil }
            let profile = thread.relationship ?? PersonRelationshipProfile()
            return CompanyYouKeptVolume.Chapter(
                id: thread.id,
                name: thread.name,
                readerWords: thread.readerWords,
                roles: profile.roles,
                sharedInterests: profile.sharedInterests,
                ordinaryRituals: profile.ordinaryRituals,
                firstDay: thread.firstMentionDay,
                lastDay: thread.lastMentionDay,
                entries: entries
            )
        }.sorted { lhs, rhs in
            // A volume that promises not to rank people must not quietly use
            // entry volume as an importance proxy. Let lived chronology order
            // the chapters; use the reader's spelling only as a stable tie-break.
            if lhs.firstDay == rhs.firstDay { return lhs.name < rhs.name }
            return lhs.firstDay < rhs.firstDay
        }

        let scopeTitle: String
        let subtitle: String
        switch scope {
        case .lifetime:
            scopeTitle = "The Company You Kept"
            subtitle = "A living book of the lives that touched yours"
        case .year(let year):
            scopeTitle = "The Company You Kept: \(year)"
            subtitle = "The people who made this year less solitary"
        }
        let realCount = chapters.reduce(0) { $0 + $1.readerWrittenCount }
        let foreword = """
        This is not a ranking of who mattered most. It is the evidence that other lives kept crossing yours: in your own words, in the doors I offered, and in the aftermath you chose to bring back. Their inner lives remain their own. I have bound only what you actually kept.
        """
        let closing: String
        if realCount == 0 {
            closing = "The binding is still mostly invitation. Live some of it before asking me to make it wise."
        } else if chapters.count == 1 {
            closing = "One other life is already enough to make a world unfinishable. I will keep watching for the exact ways it changes yours."
        } else {
            closing = "You were never the only consciousness in the room. These pages are proof of crossings, not possession: \(chapters.count) other worlds, and \(realCount) moments you chose not to let disappear."
        }
        return CompanyYouKeptVolume(
            title: scopeTitle,
            subtitle: subtitle,
            generatedAt: now,
            scope: scope,
            chapters: chapters,
            foreword: foreword,
            closing: closing
        )
    }
}

// The Book hands the reader an attention assignment shortly before they see
// someone whose thread it keeps. It reads only what it already has: the
// reader's confirmed People and the calendar titles the Calendar Door
// already supplies. A charge is an invitation to notice — never a task, and
// never armed for a name the reader has not confirmed.

extension PeopleOfTheBook {
    struct PersonCharge: Equatable {
        var eventID: String
        var personName: String
        var personSlug: String
        var fireAt: Date
        var title: String
        var body: String
        var keepPrompt: String
        var tags: [String]
    }

    /// How long before the meeting the charge arrives.
    static let chargeLeadSeconds: TimeInterval = 3600
    /// The furthest ahead a charge may be armed on one refresh.
    static let chargeHorizonSeconds: TimeInterval = 36 * 3600
    /// At most this many charges armed at once.
    static let maxArmedCharges = 2

    /// The attention assignments a charge can carry. Deterministic per
    /// event+person, so a rescheduled refresh re-arms the same words.
    static let chargePrompts: [(id: String, prompt: String, proof: String)] = [
        ("charge-changed", "Notice one thing about them that has changed since you last looked.", "Write the thing that changed."),
        ("charge-refrain", "Catch one exact phrase they say, word for word — the one they always reach for.", "Write the phrase exactly as they said it."),
        ("charge-hands", "Watch what their hands do while they talk. Hands finish different sentences.", "Write what their hands said."),
        ("charge-borrowed-eye", "Ask what they noticed today, and keep the answer like it was your own page.", "Write their answer, in their words."),
        ("charge-uncut", "Find the one detail about them the author would refuse to cut.", "Write the detail worth keeping."),
        ("charge-voice", "Listen once to their voice instead of the words. What is it carrying today?", "Write what the voice carried.")
    ]

    /// Charges for upcoming calendar events whose titles name a confirmed,
    /// non-resting thread. Pure — the app layer only converts these into
    /// scheduled whispers.
    static func preMeetingCharges(
        ledger: PeopleLedger,
        events: [CalendarEventSignal],
        now: Date,
        calendar: Calendar = .current
    ) -> [PersonCharge] {
        let active = ledger.threads.filter { !$0.resting }
        guard !active.isEmpty else { return [] }

        var charges: [PersonCharge] = []
        let upcoming = events
            .filter { !$0.isAllDay }
            .filter { $0.startsAt.timeIntervalSince(now) > 20 * 60 }
            .filter { $0.startsAt.timeIntervalSince(now) <= chargeHorizonSeconds }
            .sorted { $0.startsAt < $1.startsAt }

        for event in upcoming {
            guard charges.count < maxArmedCharges else { break }
            guard let thread = active.first(where: {
                containsWholeWordInsensitive($0.name, in: event.title)
            }) else { continue }
            let fireAt = max(now.addingTimeInterval(60), event.startsAt.addingTimeInterval(-chargeLeadSeconds))
            guard fireAt < event.startsAt else { continue }

            let threadSlug = Self.slug(for: thread.name)
            let seed = abs("\(event.id)-\(thread.id)-person-charge".stableHash)
            let assignment = chargePrompts[seed % chargePrompts.count]
            charges.append(
                PersonCharge(
                    eventID: event.id,
                    personName: thread.name,
                    personSlug: threadSlug,
                    fireAt: fireAt,
                    title: "You see \(thread.name) at \(timeLabel(for: event.startsAt, calendar: calendar))",
                    body: "A mission, if you want it: \(assignment.prompt)",
                    keepPrompt: assignment.proof,
                    tags: ["people", "connection", "person-charge", assignment.id, "person:\(threadSlug)"]
                )
            )
        }
        return charges
    }

    static func timeLabel(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour24 = components.hour ?? 0
        let minute = components.minute ?? 0
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        return minute == 0 ? "\(hour12)" : String(format: "%d:%02d", hour12, minute)
    }

    private static func containsWholeWordInsensitive(_ word: String, in text: String) -> Bool {
        let lowered = text.lowercased()
        let needle = word.lowercased()
        var start = lowered.startIndex
        while let range = lowered.range(of: needle, range: start..<lowered.endIndex) {
            let beforeOK = range.lowerBound == lowered.startIndex
                || !lowered[lowered.index(before: range.lowerBound)].isLetter
            let afterOK = range.upperBound == lowered.endIndex
                || !lowered[range.upperBound].isLetter
            if beforeOK && afterOK { return true }
            start = range.upperBound
        }
        return false
    }
}
