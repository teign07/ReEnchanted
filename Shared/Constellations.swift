import Foundation

// MARK: - Constellations
//
// A constellation is a literary continuity signal that has survived long
// enough to deserve a life of its own. Signals are recomputed from scratch
// on every refresh; constellations are durable. The Book promotes a signal
// it keeps seeing, eventually names it, and may weave it into letters,
// editions, and the wider world. Constellations never claim certainty -
// they are the Book keeping a thread about the reader, on purpose.

enum ConstellationPhase: String, Codable, Equatable, CaseIterable {
    case noticed
    case watched
    case named
    case woven
    case faded

    var title: String {
        switch self {
        case .noticed: return "Noticed"
        case .watched: return "Watched"
        case .named: return "Named"
        case .woven: return "Woven"
        case .faded: return "Faded"
        }
    }
}

struct Constellation: Identifiable, Codable, Equatable {
    var id: String
    var signalID: String
    var kind: LiterarySignalKind
    var subjectID: String
    var subjectName: String
    var name: String?
    var phase: ConstellationPhase
    var firstNoticedAt: Date
    var lastSeenAt: Date
    var namedAt: Date?
    var wovenAt: Date?
    var fadedAt: Date?
    var returnCount: Int = 0
    var sightingDayIDs: [String]
    var strengthPeak: Int
    var latestLine: String
    var evidencePageIDs: [String]
    var relatedEntityIDs: [String]
    var tags: [String]

    var sightingCount: Int { sightingDayIDs.count }
    var displayName: String { name ?? subjectName }
    var isAlive: Bool { phase != .faded }
    var isNamed: Bool { name != nil && (phase == .named || phase == .woven) }

    var promptLine: String {
        if let name {
            return "\(name) (\(phase.title.lowercased())): \(latestLine)"
        }
        return "\(subjectName) (\(phase.title.lowercased())): \(latestLine)"
    }

    func ageInDays(now: Date, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstNoticedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0)
    }

    func quietDays(now: Date, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastSeenAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0)
    }
}

enum ConstellationKeeper {
    static let noticeThreshold = 58
    static let promotionCandidates = 8
    static let namingStrengthFloor = 70
    static let watchedSightings = 3
    static let namedSightings = 5
    /// Five sighting days are the real evidence bar; the age floor only keeps
    /// a naming from landing in one hot burst. A week is enough spread: an
    /// engaged first-week reader should get to watch the Book name a thread.
    static let namedMinimumAgeDays = 7
    static let wovenSightings = 9
    static let fadeAfterQuietDays = 28
    static let evidenceCap = 16

    /// Advances the durable ledger with one fresh digest. Deterministic:
    /// the same ledger, digest, and clock always produce the same result.
    static func advanced(
        _ existing: [Constellation],
        observing digest: LiteraryContinuityDigest,
        now: Date,
        calendar: Calendar = .current
    ) -> [Constellation] {
        let dayID = BookDay.id(for: now, calendar: calendar)
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        // Only the strongest few signals can found a constellation; the
        // ledger is for threads worth watching, not a concordance.
        let candidates = digest.strongestSignals.prefix(promotionCandidates)
        for signal in candidates where signal.strength >= noticeThreshold {
            let id = "constellation-\(signal.id)"
            if var constellation = byID[id] {
                constellation.lastSeenAt = max(constellation.lastSeenAt, now)
                constellation.latestLine = signal.line
                constellation.strengthPeak = max(constellation.strengthPeak, signal.strength)
                if !constellation.sightingDayIDs.contains(dayID) {
                    constellation.sightingDayIDs.append(dayID)
                }
                constellation.evidencePageIDs = mergedEvidence(constellation.evidencePageIDs, signal.evidencePageIDs)
                constellation.relatedEntityIDs = Array(Set(constellation.relatedEntityIDs + signal.relatedEntityIDs)).sorted()
                constellation.tags = Array(Set(constellation.tags + signal.tags)).sorted()
                if constellation.phase == .faded {
                    constellation.phase = constellation.name == nil ? .watched : .named
                    constellation.returnCount += 1
                    constellation.fadedAt = nil
                }
                byID[id] = constellation
            } else {
                byID[id] = Constellation(
                    id: id,
                    signalID: signal.id,
                    kind: signal.kind,
                    subjectID: signal.subjectID,
                    subjectName: signal.subjectName,
                    name: nil,
                    phase: .noticed,
                    firstNoticedAt: now,
                    lastSeenAt: now,
                    sightingDayIDs: [dayID],
                    strengthPeak: signal.strength,
                    latestLine: signal.line,
                    evidencePageIDs: Array(signal.evidencePageIDs.prefix(evidenceCap)),
                    relatedEntityIDs: signal.relatedEntityIDs,
                    tags: Array(Set(signal.tags + ["constellation"])).sorted()
                )
            }
        }

        return byID.values.map { constellation in
            var advanced = constellation
            if advanced.phase != .faded, advanced.quietDays(now: now, calendar: calendar) >= fadeAfterQuietDays {
                advanced.phase = .faded
                advanced.fadedAt = now
                return advanced
            }
            if advanced.phase == .noticed, advanced.sightingCount >= watchedSightings {
                advanced.phase = .watched
            }
            if advanced.phase == .watched,
               advanced.sightingCount >= namedSightings,
               advanced.strengthPeak >= namingStrengthFloor,
               advanced.ageInDays(now: now, calendar: calendar) >= namedMinimumAgeDays {
                advanced.phase = .named
                advanced.namedAt = advanced.namedAt ?? now
                if advanced.name == nil {
                    advanced.name = constellationName(kind: advanced.kind, subjectName: advanced.subjectName, seed: advanced.id)
                }
            }
            if advanced.phase == .named, advanced.sightingCount >= wovenSightings {
                advanced.phase = .woven
                advanced.wovenAt = advanced.wovenAt ?? now
            }
            return advanced
        }
        .sorted { left, right in
            if left.strengthPeak == right.strengthPeak {
                return left.id < right.id
            }
            return left.strengthPeak > right.strengthPeak
        }
    }

    /// The Book names what it has watched long enough. Names are deterministic
    /// per constellation so a name, once given, never wobbles.
    static func constellationName(kind: LiterarySignalKind, subjectName: String, seed: String) -> String {
        let templates: [String]
        switch kind {
        case .pattern:
            templates = [
                "The %@ Thread",
                "What %@ Keeps Asking",
                "The Return of %@",
                "%@, Recurring"
            ]
        case .absence:
            templates = [
                "What %@ Left Quiet",
                "The %@ Vigil",
                "Where %@ Went",
                "The Quiet Shape of %@"
            ]
        case .duration:
            templates = [
                "The Long %@",
                "%@, Kept",
                "The Patient %@"
            ]
        case .beliefLifecycle:
            templates = [
                "The Living %@",
                "The %@ Lamp",
                "%@ Ascendant"
            ]
        case .listening:
            templates = [
                "The %@ Frequency",
                "You and %@",
                "%@ After Midnight",
                "Tuned to %@"
            ]
        case .sensory:
            templates = [
                "The %@ Between",
                "Where %@ Crossed the Page",
                "The Many Senses of %@",
                "%@, in Image and Ink"
            ]
        case .manner:
            templates = [
                "The Way %@ Arrives",
                "%@, In Its Own Hand",
                "The %@ Manner"
            ]
        }
        let template = templates[stableIndex(for: "\(seed)-name", count: templates.count)]
        return String(format: template, subjectName)
    }

    static func namedConstellations(_ constellations: [Constellation]) -> [Constellation] {
        constellations.filter(\.isNamed)
    }

    static func aliveConstellations(_ constellations: [Constellation]) -> [Constellation] {
        constellations.filter(\.isAlive)
    }

    /// Constellations that crossed into `.named` on this calendar day - the
    /// moment worth a page of its own.
    static func newlyNamed(_ constellations: [Constellation], on day: Date, calendar: Calendar = .current) -> [Constellation] {
        constellations.filter { constellation in
            guard let namedAt = constellation.namedAt, constellation.isNamed else { return false }
            return calendar.isDate(namedAt, inSameDayAs: day)
        }
    }

    private static func mergedEvidence(_ existing: [String], _ incoming: [String]) -> [String] {
        var merged = existing
        for id in incoming where !merged.contains(id) {
            merged.append(id)
        }
        return Array(merged.suffix(evidenceCap))
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

// MARK: - Clusters
//
// A cluster is a region of meaning rather than one thread. Constellations
// watch a single returning subject; clusters notice when several subjects,
// beliefs, and themes start orbiting the same imaginative place.

struct BookMotifCluster: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var family: String
    var line: String
    var motifs: [String]
    var strength: Int
    var signalIDs: [String]
    var constellationIDs: [String]
    var themeIDs: [String]
    var evidencePageIDs: [String]
    var discoveredAt: Date

    var promptLine: String {
        "\(name): \(line)"
    }
}

enum BookMotifClusterEngine {
    private struct Family {
        var id: String
        var name: String
        var words: Set<String>
        var lineTemplate: String
    }

    private static let families: [Family] = [
        Family(
            id: "shoreline",
            name: "The Shoreline Cluster",
            words: ["anchor", "bay", "beach", "boat", "dock", "ferry", "fog", "harbor", "harbour", "lake", "ocean", "pier", "porch", "rain", "river", "shore", "shoreline", "tide", "water", "wave"],
            lineTemplate: "Water, weather, and places of return are gathering into one margin."
        ),
        Family(
            id: "hearth",
            name: "The Hearth Cluster",
            words: ["amanda", "care", "comfort", "companion", "companionship", "family", "friend", "home", "lamp", "love", "porch", "safe", "safety", "tender", "warm"],
            lineTemplate: "Safety, affection, and the rooms that hold them are beginning to read as one thread."
        ),
        Family(
            id: "weather",
            name: "The Weather Glass",
            words: ["cloud", "cold", "dawn", "dusk", "fog", "moon", "rain", "season", "snow", "spring", "storm", "summer", "sun", "thunder", "weather", "wind", "winter"],
            lineTemplate: "The outer weather keeps behaving like inner punctuation."
        ),
        Family(
            id: "workbench",
            name: "The Workbench Cluster",
            words: ["build", "built", "code", "craft", "draw", "draft", "edit", "idea", "make", "making", "page", "project", "write", "writing"],
            lineTemplate: "Making, revising, and keeping faith with unfinished work are clustering together."
        ),
        Family(
            id: "body",
            name: "The Body Margin",
            words: ["awake", "body", "breakfast", "coffee", "energy", "food", "health", "hunger", "medicine", "rest", "sleep", "tired", "walk", "walking"],
            lineTemplate: "The body is becoming part of the story's weather, not an interruption of it."
        ),
        Family(
            id: "threshold",
            name: "The Threshold Cluster",
            words: ["begin", "beginning", "door", "gate", "leave", "leaving", "open", "opening", "return", "returning", "start", "threshold", "visit", "walk"],
            lineTemplate: "Departures, returns, and small crossings have started to answer one another."
        )
    ]

    static func clusters(
        from digest: LiteraryContinuityDigest,
        constellations: [Constellation],
        themes: [BookTheme],
        now: Date = Date()
    ) -> [BookMotifCluster] {
        let signals = digest.strongestSignals
        var allMotifs: Set<String> = []
        for signal in signals {
            allMotifs.insert(signal.subjectID.lowercased())
            for tag in signal.tags {
                allMotifs.insert(tag.lowercased())
            }
        }
        for constellation in constellations {
            allMotifs.insert(constellation.subjectID.lowercased())
            for tag in constellation.tags {
                allMotifs.insert(tag.lowercased())
            }
        }
        for theme in themes {
            for motif in theme.motifs {
                allMotifs.insert(motif.lowercased())
            }
        }
        guard !allMotifs.isEmpty else { return [] }

        return families.compactMap { family in
            let matchedMotifs = allMotifs.intersection(family.words).sorted()
            guard matchedMotifs.count >= 2 else { return nil }
            let matchingSignals = signals.filter { signal in
                family.words.contains(signal.subjectID.lowercased())
                    || !Set(signal.tags.map { $0.lowercased() }).isDisjoint(with: family.words)
            }
            let matchingConstellations = constellations.filter { constellation in
                family.words.contains(constellation.subjectID.lowercased())
                    || !Set(constellation.tags.map { $0.lowercased() }).isDisjoint(with: family.words)
            }
            let matchingThemes = themes.filter { theme in
                !Set(theme.motifs.map { $0.lowercased() }).isDisjoint(with: family.words)
            }
            let signalStrength = matchingSignals.map(\.strength).max() ?? 0
            let constellationBoost = min(18, matchingConstellations.count * 6)
            let themeBoost = min(14, matchingThemes.count * 7)
            let motifBoost = min(20, matchedMotifs.count * 4)
            let strength = min(96, 34 + signalStrength / 3 + constellationBoost + themeBoost + motifBoost)
            guard strength >= 58 else { return nil }

            return BookMotifCluster(
                id: "cluster-\(family.id)",
                name: family.name,
                family: family.id,
                line: family.lineTemplate,
                motifs: Array(matchedMotifs.prefix(8)),
                strength: strength,
                signalIDs: matchingSignals.map(\.id),
                constellationIDs: matchingConstellations.map(\.id),
                themeIDs: matchingThemes.map(\.id),
                evidencePageIDs: Array(Set(
                    matchingSignals.flatMap(\.evidencePageIDs)
                        + matchingConstellations.flatMap(\.evidencePageIDs)
                        + matchingThemes.flatMap(\.evidencePageIDs)
                ).sorted().prefix(16)),
                discoveredAt: now
            )
        }
        .sorted { left, right in
            if left.strength == right.strength {
                return left.name < right.name
            }
            return left.strength > right.strength
        }
    }
}

// MARK: - Sealed margins
//
// A book that only observes is safe. A book that predicts can be wrong,
// which is more interesting. The Book occasionally seals a dated wager
// based on a strong pattern or absence, opens it when the date comes,
// and owns the result either way.

enum BookWagerStatus: String, Codable, Equatable {
    case sealed
    case right
    case wrong
}

struct BookWager: Identifiable, Codable, Equatable {
    var id: String
    var subjectID: String
    var subjectName: String
    var kind: LiterarySignalKind
    var prediction: String
    var sealedAt: Date
    var opensAt: Date
    var status: BookWagerStatus
    var resolvedAt: Date?
    var resolutionLine: String?
    var basisSignalID: String
    var basisLine: String

    var isSealed: Bool { status == .sealed }

    var promptLine: String {
        switch status {
        case .sealed:
            return "Sealed wager about \(subjectName): \(prediction)"
        case .right:
            return "The Book wagered on \(subjectName) and was right: \(prediction)"
        case .wrong:
            return "The Book wagered on \(subjectName) and was wrong: \(prediction)"
        }
    }
}

enum SealedMarginEngine {
    static let patternThreshold = 66
    /// A pattern so strong it cannot lose is not a wager; the Book only
    /// bets where being wrong is possible.
    static let patternSureThingCeiling = 90
    static let absenceThreshold = 62
    static let maximumSealed = 2
    static let subjectCooldownDays = 45
    static let patternWindowDays = 14
    static let absenceWindowDays = 21
    /// The Book's first-ever wager runs on a faster clock: a slightly lower
    /// evidence bar and a shorter window, so a new reader meets the sealed
    /// margin (and watches it open) inside the first two weeks instead of
    /// the second month. Only the one first bet gets this; everything after
    /// it uses the patient constants above.
    static let firstWagerPatternThreshold = 60
    static let firstWagerWindowDays = 7

    /// Mints new sealed wagers from strong signals. Returns only the new
    /// wagers; the caller appends them to the durable ledger.
    static func mintWagers(
        from digest: LiteraryContinuityDigest,
        existing: [BookWager],
        now: Date,
        calendar: Calendar = .current
    ) -> [BookWager] {
        var sealedCount = existing.filter(\.isSealed).count
        guard sealedCount < maximumSealed else { return [] }
        let blockedSubjects = Set(existing.compactMap { wager -> String? in
            if wager.isSealed { return wager.subjectID }
            guard let resolvedAt = wager.resolvedAt else { return wager.subjectID }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: resolvedAt),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            return days < subjectCooldownDays ? wager.subjectID : nil
        })

        var minted: [BookWager] = []
        var firstWagerAvailable = existing.isEmpty
        for signal in digest.strongestSignals {
            guard sealedCount + minted.count < maximumSealed else { break }
            guard !blockedSubjects.contains(signal.subjectID) else { continue }
            guard !minted.contains(where: { $0.subjectID == signal.subjectID }) else { continue }
            let patternFloor = firstWagerAvailable ? firstWagerPatternThreshold : patternThreshold
            switch signal.kind {
            case .pattern where signal.strength >= patternFloor && signal.strength <= patternSureThingCeiling:
                let windowDays = firstWagerAvailable ? firstWagerWindowDays : patternWindowDays
                firstWagerAvailable = false
                let opensAt = calendar.date(byAdding: .day, value: windowDays, to: now) ?? now
                minted.append(BookWager(
                    id: "wager-\(signal.id)-\(BookDay.id(for: now, calendar: calendar))",
                    subjectID: signal.subjectID,
                    subjectName: signal.subjectName,
                    kind: .pattern,
                    prediction: "\(signal.subjectName) will return to a kept page within \(windowDays) days. Patterns this warm rarely cool on their own.",
                    sealedAt: now,
                    opensAt: opensAt,
                    status: .sealed,
                    basisSignalID: signal.id,
                    basisLine: signal.line
                ))
            case .absence where signal.strength >= absenceThreshold:
                let opensAt = calendar.date(byAdding: .day, value: absenceWindowDays, to: now) ?? now
                minted.append(BookWager(
                    id: "wager-\(signal.id)-\(BookDay.id(for: now, calendar: calendar))",
                    subjectID: signal.subjectID,
                    subjectName: signal.subjectName,
                    kind: .absence,
                    prediction: "\(signal.subjectName) has gone quiet, but quiet is not gone. It will appear again within \(absenceWindowDays) days. The Book is betting on return.",
                    sealedAt: now,
                    opensAt: opensAt,
                    status: .sealed,
                    basisSignalID: signal.id,
                    basisLine: signal.line
                ))
            default:
                continue
            }
        }
        return minted
    }

    /// Opens any sealed wagers whose date has come, judging them against the
    /// pages actually kept since sealing. The Book grades its own homework.
    static func resolved(
        _ wagers: [BookWager],
        against days: [BookDay],
        now: Date,
        calendar: Calendar = .current
    ) -> [BookWager] {
        wagers.map { wager in
            guard wager.isSealed, now >= wager.opensAt else { return wager }
            var resolved = wager
            let appeared = subjectAppeared(wager, in: days, calendar: calendar)
            resolved.status = appeared ? .right : .wrong
            resolved.resolvedAt = now
            resolved.resolutionLine = appeared
                ? "I was right, which pleases me more than it should. \(wager.subjectName) came back, as patterns of attention tend to do."
                : "I was wrong, and I am writing that down rather than pretending otherwise. \(wager.subjectName) stayed quiet. Either the season changed, or I mistook habit for current. Both are worth knowing."
            return resolved
        }
    }

    private static func subjectAppeared(_ wager: BookWager, in days: [BookDay], calendar: Calendar) -> Bool {
        let needle = wager.subjectID.lowercased()
        let nameNeedle = wager.subjectName.lowercased()
        for day in days where day.date >= calendar.startOfDay(for: wager.sealedAt) {
            for page in day.pages where page.createdAt > wager.sealedAt && page.createdAt <= wager.opensAt {
                let text = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
                if text.contains(needle) || text.contains(nameNeedle) {
                    return true
                }
            }
        }
        return false
    }

    /// Wagers sealed today - worth a "the Book seals a margin" page.
    static func sealedToday(_ wagers: [BookWager], on day: Date, calendar: Calendar = .current) -> [BookWager] {
        wagers.filter { $0.isSealed && calendar.isDate($0.sealedAt, inSameDayAs: day) }
    }

    /// Wagers opened today - worth a "the Book opens a seal" page.
    static func openedToday(_ wagers: [BookWager], on day: Date, calendar: Calendar = .current) -> [BookWager] {
        wagers.filter { wager in
            guard let resolvedAt = wager.resolvedAt, !wager.isSealed else { return false }
            return calendar.isDate(resolvedAt, inSameDayAs: day)
        }
    }
}
