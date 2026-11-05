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
    var displayName: String {
        // Names minted before the doubled-article fix still say "The The …".
        (name ?? subjectName).replacingOccurrences(of: "The The ", with: "The ")
    }
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
        // "The %@ Lamp" around "The Body Page" is "The Body Page Lamp", not "The The …".
        var subject = subjectName
        if template.hasPrefix("The %@"), subject.lowercased().hasPrefix("the ") { subject = String(subject.dropFirst(4)) }
        return String(format: template, subject)
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
            name: "The Shoreline",
            words: ["anchor", "bay", "beach", "boat", "dock", "ferry", "fog", "harbor", "harbour", "lake", "ocean", "pier", "porch", "rain", "river", "shore", "shoreline", "tide", "water", "wave"],
            lineTemplate: "Water, weather, and the places you keep going back to have started sharing a page. The tide's been getting ideas."
        ),
        Family(
            id: "hearth",
            name: "The Hearth",
            words: ["amanda", "care", "comfort", "companion", "companionship", "family", "friend", "home", "lamp", "love", "porch", "safe", "safety", "tender", "warm"],
            lineTemplate: "Warmth, the people you trust, and the rooms that hold them keep turning up in the same handwriting. The lamp's taken sides."
        ),
        Family(
            id: "weather",
            name: "The Weather Glass",
            words: ["cloud", "cold", "dawn", "dusk", "fog", "moon", "rain", "season", "snow", "spring", "storm", "summer", "sun", "thunder", "weather", "wind", "winter"],
            lineTemplate: "The sky keeps punctuating what you write. I've stopped calling that a coincidence, and so has the sky."
        ),
        Family(
            id: "workbench",
            name: "The Workbench",
            words: ["build", "built", "code", "craft", "draw", "draft", "edit", "idea", "make", "making", "page", "project", "write", "writing"],
            lineTemplate: "Making a thing, fixing it, and refusing to abandon it are all one habit in here. The unfinished work is smug about how often you come back."
        ),
        Family(
            id: "body",
            name: "The Body Margin",
            words: ["awake", "body", "breakfast", "coffee", "energy", "food", "health", "hunger", "medicine", "rest", "sleep", "tired", "walk", "walking"],
            lineTemplate: "Sleep, food, and being tired stopped interrupting your story. They're the weather in it now. The kettle has opinions about your mornings."
        ),
        Family(
            id: "threshold",
            name: "The Threshold",
            words: ["begin", "beginning", "door", "gate", "leave", "leaving", "open", "opening", "return", "returning", "start", "threshold", "visit", "walk"],
            lineTemplate: "Leavings, returns, and small doorways keep answering each other. Your door counts every crossing and tells me."
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
    /// Set on a wager sealed from a crossing the Book judged worth saying
    /// (`CrossingWagers`). Graded by the next days that test it rather than by
    /// a word coming back, and it can open before `opensAt`, which is only its
    /// deadline. Optional so every older wager still opens.
    var test: Noticing.Test? = nil
    /// Set on a bet about the days ahead (`BookBets`): tomorrow, against the
    /// Curse, or a dare. Settled by the same day-by-day facts the grimoire
    /// counts. Optional so every older wager still opens.
    var bet: FeatureBet? = nil

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
        // Bets about the days ahead keep their own count (`BookBets`).
        let sealedCount = existing.filter { $0.isSealed && $0.bet == nil }.count
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
                    prediction: "I bet you write about \(signal.subjectName) again in the next \(windowDays) days. It keeps coming round, and I don't think it's finished with you.",
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
                    prediction: "You haven't written about \(signal.subjectName) for a while. I don't think it's gone. I think it's hiding. I bet it comes back in the next \(absenceWindowDays) days.",
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
        // Projected once, and only over the days a sealed bet can still see.
        let betStart = wagers.filter { $0.isSealed && $0.bet != nil }.map(\.sealedAt).min()
        let betDays = betStart.map { start in
            BookBets.featureDays(days.filter { $0.date >= calendar.startOfDay(for: start) }, calendar: calendar)
        } ?? [:]
        return wagers.map { wager in
            guard wager.isSealed else { return wager }
            if wager.bet != nil {
                return BookBets.resolved(wager, featureDays: betDays, now: now, calendar: calendar)
            }
            if wager.test != nil {
                let outcome = CrossingWagers.outcome(of: wager, days: days, calendar: calendar)
                guard outcome != nil || now >= wager.opensAt else { return wager }
                var resolved = wager
                resolved.status = outcome?.right == true ? .right : .wrong
                resolved.resolvedAt = now
                resolved.resolutionLine = CrossingWagers.resolutionLine(wager, outcome: outcome)
                return resolved
            }
            guard now >= wager.opensAt else { return wager }
            var resolved = wager
            let appeared = subjectAppeared(wager, in: days, calendar: calendar)
            resolved.status = appeared ? .right : .wrong
            resolved.resolvedAt = now
            resolved.resolutionLine = appeared
                ? "I was right! You wrote about \(wager.subjectName) again. I knew it."
                : "I was wrong. You didn't write about \(wager.subjectName) once. I'm writing that down, so I don't forget I got it wrong."
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

// MARK: - Bets on the days ahead
//
// The sealed margin's other bets. A pattern wager bets that a word comes back;
// these bet on the same day-by-day facts the grimoire already counts, so they
// can be settled honestly by the days themselves. Somebody always takes the
// other side, because a bet with nobody on the other side is just a guess:
// one of the Cast, the Curse, or the reader.

struct FeatureBet: Codable, Equatable {
    enum Kind: String, Codable, Equatable, CaseIterable {
        /// Tomorrow is a kind of day the Book already knows about. One of the
        /// Cast bets it goes the other way.
        case tomorrow
        /// Something the reader used to do has gone quiet. The Curse bets it's
        /// gone for good; the Book bets it isn't.
        case curse
        /// A word the reader keeps reaching for. The reader bets they can go
        /// without it; the Book bets they can't.
        case dare
    }

    var kind: Kind
    /// The grimoire feature that settles it.
    var featureID: String
    /// Grimoire day indices, both ends included.
    var fromDay: Int
    var untilDay: Int
    /// Who took the other side: one of the Cast, "the Curse", or "you".
    var opponent: String
    /// What the other side put up, when there is anything.
    var stake: String? = nil
    /// The finished statement that settles it ("you talked to me out loud"),
    /// kept so the opening reads in the same words as the sealing.
    var clause: String
    /// A dare counts only the days the reader wrote.
    var writingDaysNeeded: Int? = nil
}

enum BookBets {
    /// One bet sealed at a time, and a few days' rest after each.
    static let restDays = 3
    static let curseWindowDays = 7
    static let dareWritingDays = 3
    static let dareDeadlineDays = 21

    /// The Cast who'll take the other side of a tomorrow bet, and what each
    /// puts up. Small things, the kind a child would bet.
    static let takers: [(name: String, stake: String)] = [
        ("Wicker Eddies", "a button"),
        ("Pippa Pilcrow", "a pencil stub"),
        ("Serenity Brown", "three acorns"),
        ("Ambrose Trencher", "a jam tart")
    ]

    /// Reader verdicts that take a rule off the table.
    private static let untrusted: Set<BookObservationStatus> = [.notQuite, .doNotRead, .questioned, .forbidden]

    /// Feature families a bet against the Curse never picks: things the Book
    /// arranged (doing what it asked isn't the reader coming back), feelings
    /// the reader reported, and the bare fact of writing.
    private static let curseSkips: Set<String> = [
        "writing", "ink", "readerState", "working", "workingInitiator", "workingEpisode",
        "workingOutcome", "talisman", "errandOutcome", "asideReply", "jumpBook", "jumpOutcome"
    ]

    // MARK: Making a bet

    /// At most one new bet, taking turns between the kinds so the reader
    /// meets all three. Returns only the new bet; the caller appends it.
    static func mint(
        grimoire: GrimoireLedger,
        existing: [BookWager],
        now: Date,
        calendar: Calendar = .current
    ) -> [BookWager] {
        let bets = existing.filter { $0.bet != nil }
        guard !bets.contains(where: \.isSealed) else { return [] }
        if let last = bets.map(\.sealedAt).max(),
           now.timeIntervalSince(last) < Double(restDays) * 86_400 { return [] }
        let kinds = FeatureBet.Kind.allCases
        for offset in kinds.indices {
            let kind = kinds[(bets.count + offset) % kinds.count]
            let made: BookWager?
            switch kind {
            case .tomorrow: made = tomorrowBet(grimoire: grimoire, now: now, calendar: calendar)
            case .curse: made = curseBet(grimoire: grimoire, now: now, calendar: calendar)
            case .dare: made = dare(grimoire: grimoire, now: now, calendar: calendar)
            }
            if let made { return [made] }
        }
        return []
    }

    /// Tomorrow is a weekend, a full moon or a writer's birthday, and the Book
    /// knows what the reader does on days like that.
    static func tomorrowBet(grimoire: GrimoireLedger, now: Date, calendar: Calendar = .current) -> BookWager? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
              let after = calendar.date(byAdding: .day, value: 1, to: tomorrow) else { return nil }
        let slice = GrimoireSlice(days: [], calendar: calendar)
        let day = BookDay(id: BookDay.id(for: tomorrow, calendar: calendar), date: tomorrow, pages: [])
        // Only what the calendar already knows about tomorrow. The season is
        // left out: it would be the same bet every day for three months.
        let known = Set((
            DayShapeProjector.temporalFeatures(at: tomorrow, in: slice).filter { $0.domain == "weekPart" }
                + MoonProjector.features(forDay: day, in: slice)
                + AlmanacProjector.features(forDay: day, in: slice)
        ).map(\.id))
        let candidates = grimoire.standing
            .filter { $0.shape == .conditional && known.contains($0.conditionID) }
            .filter { $0.readerStatus.map { !untrusted.contains($0) } ?? true }
            .sorted { $0.strengthPeak != $1.strengthPeak ? $0.strengthPeak > $1.strengthPeak : $0.id < $1.id }
        for row in candidates {
            guard let condition = grimoire.ref(row.conditionID), condition.sensitivity == .ordinary,
                  let outcomeID = row.outcomeID, let outcome = grimoire.ref(outcomeID),
                  outcome.sensitivity == .ordinary, outcome.provenance == .readerAuthored,
                  let stats = grimoire.currentStats(for: row, calendar: calendar) else { continue }
            let index = GrimoireDay.index(for: tomorrow, calendar: calendar)
            let taker = takers[abs(index) % takers.count]
            return BookWager(
                id: "bet-tomorrow-\(BookDay.id(for: now, calendar: calendar))",
                subjectID: outcome.id,
                subjectName: outcome.label,
                kind: .pattern,
                prediction: "Tomorrow's one of your \(condition.label). On days like that, \(outcome.outcomeClause), "
                    + "\(stats.inHits) times out of \(stats.inCount). \(taker.name) bet me \(taker.stake) it won't happen this time. "
                    + "I bet it will.",
                sealedAt: now,
                opensAt: after.addingTimeInterval(86_400),
                status: .sealed,
                basisSignalID: row.id,
                basisLine: "I already know something about tomorrow.",
                bet: FeatureBet(
                    kind: .tomorrow, featureID: outcome.id, fromDay: index, untilDay: index,
                    opponent: taker.name, stake: taker.stake, clause: outcome.outcomeClause
                )
            )
        }
        return nil
    }

    /// Something the reader used to do every few days has gone quiet for
    /// weeks. That's the Curse's whole trick, so the Curse bets on it.
    static func curseBet(grimoire: GrimoireLedger, now: Date, calendar: Calendar = .current) -> BookWager? {
        let today = GrimoireDay.index(for: now, calendar: calendar)
        var best: (ref: LoomFeatureRef, gap: Int, count: Int)?
        for ref in grimoire.featureRefs
        where ref.provenance == .readerAuthored && ref.sensitivity == .ordinary
            && ref.role != .conditionOnly && !curseSkips.contains(ref.domain) {
            let days = grimoire.days(of: ref.id)
            guard days.count >= 6, let first = days.firstDay, let last = days.lastDay else { continue }
            let gap = today - last
            let usualGap = max(1, (last - first) / (days.count - 1))
            guard (14...60).contains(gap), usualGap <= 7, gap >= usualGap * 3 else { continue }
            // The steadiest habit wins; ties go to the id, so the same archive
            // always makes the same bet.
            if let current = best, current.count > days.count || (current.count == days.count && current.ref.id < ref.id) { continue }
            best = (ref, gap, days.count)
        }
        guard let best,
              let until = calendar.date(byAdding: .day, value: curseWindowDays + 1, to: calendar.startOfDay(for: now))
        else { return nil }
        let window = GrimoireVoice.spelledCount(curseWindowDays).lowercased()
        return BookWager(
            id: "bet-curse-\(BookDay.id(for: now, calendar: calendar))",
            subjectID: best.ref.id,
            subjectName: best.ref.label,
            kind: .absence,
            prediction: "The last time \(best.ref.outcomeClause) was \(best.gap) days ago. The Curse thinks that's gone for good. "
                + "That's what the Curse does: it makes things stop so quietly you don't notice. "
                + "I bet the Curse is wrong. I bet it happens again in the next \(window) days.",
            sealedAt: now,
            opensAt: until,
            status: .sealed,
            basisSignalID: best.ref.id,
            basisLine: "The Curse and I have a bet on.",
            bet: FeatureBet(
                kind: .curse, featureID: best.ref.id, fromDay: today, untilDay: today + curseWindowDays,
                opponent: "the Curse", clause: best.ref.outcomeClause
            )
        )
    }

    /// A word the reader reaches for nearly every time they write. The Book
    /// bets they can't go without it.
    static func dare(grimoire: GrimoireLedger, now: Date, calendar: Calendar = .current) -> BookWager? {
        let today = GrimoireDay.index(for: now, calendar: calendar)
        let recent = Array(grimoire.days(of: "writing:kept").days.filter { $0 > today - 30 && $0 <= today }.suffix(14))
        guard recent.count >= 6 else { return nil }
        var best: (word: String, id: String, hits: Int)?
        for ref in grimoire.featureRefs where ref.domain == "word" {
            let word = String(ref.id.dropFirst("word:".count))
            guard word.count >= 4, !BleedDataDesk.tenderWords.contains(word) else { continue }
            let days = grimoire.days(of: ref.id)
            let hits = recent.filter { days.contains($0) }.count
            guard hits >= 4, Double(hits) / Double(recent.count) >= 0.4 else { continue }
            if let current = best, current.hits > hits || (current.hits == hits && current.word < word) { continue }
            best = (word, ref.id, hits)
        }
        guard let best,
              let until = calendar.date(byAdding: .day, value: dareDeadlineDays + 1, to: calendar.startOfDay(for: now))
        else { return nil }
        let needed = GrimoireVoice.spelledCount(dareWritingDays).lowercased()
        return BookWager(
            id: "bet-dare-\(BookDay.id(for: now, calendar: calendar))",
            subjectID: best.id,
            subjectName: "the word “\(best.word)”",
            kind: .pattern,
            prediction: "I bet the word “\(best.word)” turns up again in the next \(needed) days you write. "
                + "It's been in \(best.hits) of your last \(recent.count) days of writing. Bet you can't keep it out. Go on. Prove me wrong.",
            sealedAt: now,
            opensAt: until,
            status: .sealed,
            basisSignalID: best.id,
            basisLine: "There's a word you keep reaching for.",
            // From tomorrow: today's writing may already have it in.
            bet: FeatureBet(
                kind: .dare, featureID: best.id, fromDay: today + 1, untilDay: today + dareDeadlineDays,
                opponent: "you", clause: "you used the word “\(best.word)”", writingDaysNeeded: dareWritingDays
            )
        )
    }

    // MARK: Settling a bet

    /// Which grimoire features each day carried, by grimoire day index.
    static func featureDays(_ days: [BookDay], calendar: Calendar = .current) -> [Int: Set<String>] {
        var found: [Int: Set<String>] = [:]
        for observation in GrimoireProjection.observations(from: GrimoireSlice(days: days, calendar: calendar)) {
            found[observation.day, default: []].formUnion(observation.features.map(\.id))
        }
        return found
    }

    /// Opens a bet once the days have settled it. `.right` means the Book won.
    static func resolved(
        _ wager: BookWager,
        featureDays: [Int: Set<String>],
        now: Date,
        calendar: Calendar = .current
    ) -> BookWager {
        guard let bet = wager.bet, wager.isSealed, bet.untilDay >= bet.fromDay else { return wager }
        let today = GrimoireDay.index(for: now, calendar: calendar)
        func carried(_ day: Int, _ id: String) -> Bool { featureDays[day]?.contains(id) == true }
        let lastSeen = min(bet.untilDay, today)
        let won: Bool
        let line: String
        switch bet.kind {
        case .tomorrow, .curse:
            let happened = lastSeen >= bet.fromDay && (bet.fromDay...lastSeen).contains { carried($0, bet.featureID) }
            guard happened || today > bet.untilDay else { return wager }
            won = happened
            line = settledLine(bet, bookWon: happened)
        case .dare:
            let needed = bet.writingDaysNeeded ?? dareWritingDays
            let writing = lastSeen >= bet.fromDay
                ? (bet.fromDay...lastSeen).filter { carried($0, "writing:kept") }.prefix(needed)
                : []
            if writing.contains(where: { carried($0, bet.featureID) }) {
                won = true
                line = settledLine(bet, bookWon: true)
            } else if writing.count == needed, let last = writing.last, last < today {
                // The last day it counts has to be over: the word could still
                // turn up tonight.
                won = false
                line = settledLine(bet, bookWon: false)
            } else if today > bet.untilDay {
                won = false
                line = "You didn't write on \(GrimoireVoice.spelledCount(needed).lowercased()) days before the seal's date, "
                    + "so nobody won. A draw goes to you."
            } else {
                return wager
            }
        }
        var resolved = wager
        resolved.status = won ? .right : .wrong
        resolved.resolvedAt = now
        resolved.resolutionLine = line
        return resolved
    }

    static func settledLine(_ bet: FeatureBet, bookWon: Bool) -> String {
        let happened = GrimoireVoice.opening(bet.clause)
        switch bet.kind {
        case .tomorrow:
            let stake = bet.stake ?? "the bet"
            return bookWon
                ? "\(happened) again, just like I said. I won \(stake) off \(bet.opponent)."
                : "It didn't happen. \(bet.opponent) won \(stake) off me and hasn't stopped grinning."
        case .curse:
            return bookWon
                ? "\(happened) again. The Curse lost this one, and I watched it lose."
                : "It didn't happen. The Curse won this round. It doesn't get to keep it. I'll bet against it again."
        case .dare:
            let word = bet.clause.replacingOccurrences(of: "you used the word ", with: "")
            return bookWon
                ? "You used \(word) again. I knew you couldn't help it. The word's very pleased with itself."
                : "\(GrimoireVoice.spelledCount(bet.writingDaysNeeded ?? dareWritingDays)) days of writing and not one \(word). "
                    + "You won. I lost, and I'm glad. The word's sulking."
        }
    }

    /// The name on the sealed Page.
    static func headline(_ bet: FeatureBet) -> String {
        switch bet.kind {
        case .tomorrow: return "A Bet With \(bet.opponent)"
        case .curse: return "A Bet Against the Curse"
        case .dare: return "I Dare You"
        }
    }

    /// When the seal comes off, said the way the bet works.
    static func openingLine(_ bet: FeatureBet) -> String? {
        switch bet.kind {
        case .tomorrow: return "The seal opens when tomorrow's over."
        case .curse: return nil
        case .dare:
            let needed = GrimoireVoice.spelledCount(bet.writingDaysNeeded ?? dareWritingDays).lowercased()
            return "The seal opens after your next \(needed) days of writing."
        }
    }
}
