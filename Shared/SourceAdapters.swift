import Foundation


/// Tunable thresholds gating the emergent/reflective pages that comment on the
/// reader's library rather than capture new material.
enum EmergentPageMaturity {
    /// Minimum kept fragments before reflective pages may surface.
    static let minimumKeptPages = 4
    /// How long after the first kept page reflective pages stay folded away.
    static let minimumAgeSeconds: TimeInterval = 6 * 3600
}

struct BookSourceInputs: Equatable {
    var days: [BookDay] = []
    var bookInterior: BookInteriorState = .unawakened
    var magicMoment: MagicMomentState = MagicMomentState()
    var bookObservations: [BookObservationRecord] = []
    var bookReadingBoundaries: [BookReadingBoundary] = []
    var overnightConnectionDrafts: [OvernightConnectionDraft] = []
    var chosenQuill: ChosenQuill?
    var body: BodySourceSignal?
    var weather: WeatherSourceSignal?
    var enchantedWeather: EnchantedWeatherSignal?
    /// A coarse, freshly resolved label for where the reader is now (for
    /// example "Home" or "Portland"). Nearby POIs are discovery candidates,
    /// not proof that the reader is standing inside one of them.
    var currentLocationLabel: String?
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
    var readerLearning: ReaderLearningModel = ReaderLearningModel()
    var calendarEvents: [CalendarEventSignal] = []
    var calendarIntegrationEnabled = true
    var nearbyPlaces: [LocalPlaceSignal] = []
    var resurfacingCandidates: [BookPage] = []
    var quietDays: Int = 0
    var nothingGreyOffset: Int = 0
    var storyRecipeBoosts: [String: Int] = [:]
    var storyMotifs: [String: Int] = [:]
    var storyRituals: [String: Int] = [:]
    var storySettingAffinities: [String: Int] = [:]
    var storySceneBiases: [String: Int] = [:]
    var bookNoticeEvidence: Int = 0
    var currentArc: StoryArc?
    var recentNarrativeEvents: [NarrativeEvent] = []
    var continuity: LiteraryContinuityDigest = .empty
    /// Rebuildable from reader-authored kept prose. It is cached beside the
    /// continuity digest so rendered views never rescan a years-long archive.
    var bookVoicePatina: BookVoicePatina = .unwritten
    var constellations: [Constellation] = []
    var wagers: [BookWager] = []
    var themes: [BookTheme] = []
    var clusters: [BookMotifCluster] = []
    var bleedIssueNumber: Int = 1
    var preparedBleedEditionSurface: SurfacePage?
    var bookJump: BookJumpState = BookJumpState()
    var radio: RadioPlaybackState = .off
    var activeWorldEvents: [ResolvedWorldEvent] = []
    var openWorldEventArchive: OpenWorldEventArchive?
    var ownedPackIDs: Set<String> = []
    var readerLexicon: ReaderLexicon = ReaderLexicon()
    var localBrainIsReady = false
    var readerBeliefScore: Int = 30
    var pocket: PocketLedger = PocketLedger()
    /// The reader's typed corrections to braids that missed, from the vault —
    /// TaughtReading speaks them back as proof the Book was listening.
    var learnedBraidNotes: [String] = []
    /// A word-disjoint "same feeling" pairing for The Book Notices, computed
    /// off-main beside the continuity digest (NLEmbedding is not free). Nil on
    /// the synchronous fallback path; the Notices page simply omits the beat.
    var semanticNoticePairing: SemanticNoticePairing? = nil
    /// Enables sentence-embedding relevance when a generated surface chooses a
    /// meaningful passage from the reader's keeps. Surface builds set this only
    /// on their detached executor; synchronous previews still receive the same
    /// lexical, fingerprint, archive, and passage-salience fallback without
    /// main-thread ML.
    var semanticPassageSelectionEnabled = false
    /// History keys of first-run steps the reader engaged with (opened or
    /// deliberately swiped away). The first-run script advances on these, not
    /// on served-history, so a card can't be skipped by merely flashing past.
    var firstRunEngagedKeys: Set<String> = []
    /// The People of the Book ledger from the vault. The Book reads it as a
    /// witness; a person only enters the story when the reader writes them in
    /// (the thread then carries a linked custom cast member).
    var people: PeopleLedger = PeopleLedger()
    /// A deliberately public, server-curated snapshot. It is nil unless the
    /// reader independently opted into bringing Public Margins into the Book.
    var publicMargins: PublicMarginsSnapshot?

    func recentVarietyKeys(within seconds: TimeInterval = 48 * 3600, now: Date = Date()) -> Set<String> {
        Set(surfaceHistory.filter { now.timeIntervalSince($0.value.lastShownAt) < seconds }.keys)
    }

    var keptPageCount: Int {
        days.reduce(0) { $0 + $1.pages.count }
    }

    /// Emergent/reflective pages — The Two Readings, the Loom (cast bonds), Book
    /// Notices, Book Remembers, and Constellations — only mean something once a
    /// few kept pages have built up and the book has aged past its first hours.
    /// Holding them back keeps the early days about capturing, not commentary.
    /// `today` is folded in because the current day usually isn't in `days` yet.
    func libraryReadyForReflectivePages(includingToday today: BookDay? = nil, now: Date = Date()) -> Bool {
        let allDays = today.map { days + [$0] } ?? days
        let captured = allDays.flatMap(\.capturedPages)
        guard captured.count >= EmergentPageMaturity.minimumKeptPages else { return false }
        guard let first = captured.map(\.createdAt).min() else { return false }
        return now.timeIntervalSince(first) >= EmergentPageMaturity.minimumAgeSeconds
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
        copy.activeWorldEvents = WorldEventResolver.currentEvents(now: now, day: day, inputs: self)
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

// MARK: - Overnight connection review

enum OvernightConnectionReview {
    private struct Response: Decodable {
        var connections: [Connection]
    }

    private struct Connection: Decodable {
        var candidateID: String
        var confidence: Int
        var headline: String
        var interpretation: String
        var question: String
    }

    static func candidates(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date()
    ) -> [OvernightConnectionCandidate] {
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: day,
            context: .make(for: day),
            inputs: inputs,
            now: now
        )
        return surfaces.compactMap { surface in
            let metadata = surface.payload.metadata
            guard metadata["connectionNarrative"] == "true" || metadata["hiddenMagicWayOfSeeing"] == "true" else { return nil }
            let evidence = BookObservationLedger.evidencePageIDs(for: surface)
            guard evidence.count >= 2,
                  let observationKey = BookObservationLedger.key(for: surface) else { return nil }
            return OvernightConnectionCandidate(
                id: metadata["connectionID"]?.nonEmpty ?? surface.id,
                observationKey: observationKey,
                kind: metadata["connectionKind"]?.nonEmpty ?? BookObservationLedger.kind(for: surface),
                deterministicFinding: surface.detail.nonEmpty ?? surface.payload.body,
                evidencePageIDs: evidence,
                evidenceCards: metadata["tinyPatternCards"] ?? ""
            )
        }
    }

    static func evidenceSignature(for candidates: [OvernightConnectionCandidate]) -> String {
        let material = candidates
            .sorted { $0.id < $1.id }
            .map { candidate in
                [candidate.id, candidate.observationKey, candidate.kind,
                 candidate.evidencePageIDs.joined(separator: ","), candidate.evidenceCards]
                    .joined(separator: "|")
            }
            .joined(separator: "\n")
        let hash = material.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    static func drafts(
        from response: String,
        candidates: [OvernightConnectionCandidate],
        now: Date = Date()
    ) -> [OvernightConnectionDraft] {
        guard let data = response.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let signature = evidenceSignature(for: candidates)
        let forbidden = ["diagnosis", "diagnose", "trauma", "attachment style", "anxious", "depressed", "disorder"]
        return decoded.connections.compactMap { reading in
            guard let candidate = byID[reading.candidateID],
                  (70...100).contains(reading.confidence),
                  reading.headline.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil,
                  reading.interpretation.split(separator: " ").count >= 8,
                  reading.question.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") else { return nil }
            let claim = "\(reading.headline) \(reading.interpretation) \(reading.question)".lowercased()
            guard !forbidden.contains(where: claim.contains) else { return nil }
            return OvernightConnectionDraft(
                observationKey: candidate.observationKey,
                candidateID: candidate.id,
                evidenceSignature: signature,
                kind: candidate.kind,
                headline: reading.headline.trimmingCharacters(in: .whitespacesAndNewlines),
                interpretation: reading.interpretation.trimmingCharacters(in: .whitespacesAndNewlines),
                question: reading.question.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: reading.confidence,
                evidencePageIDs: candidate.evidencePageIDs,
                evidenceCards: candidate.evidenceCards,
                generatedAt: now
            )
        }
    }

    static func surfaces(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date()
    ) -> [SurfacePage] {
        let pageIDs = Set((inputs.days + [day]).flatMap(\.pages).map(\.id))
        return inputs.overnightConnectionDrafts.compactMap { draft in
            guard draft.confidence >= 70,
                  draft.evidencePageIDs.count >= 2,
                  draft.evidencePageIDs.allSatisfy(pageIDs.contains),
                  !inputs.bookReadingBoundaries.contains(where: { $0.id == draft.observationKey }),
                  !inputs.bookObservations.contains(where: { $0.id == draft.observationKey }) else { return nil }
            let body = """
            I put these pages beside one another overnight.

            \(draft.interpretation)

            \(draft.question)

            This is a reading, not a verdict. The source pages are below, and you may correct me.
            """
            return SurfacePage(
                id: "overnight-connection-\(draft.candidateID)-\(day.id)",
                type: .bookNotices,
                sourceID: BookPageSourceRegistry.source(for: .bookNotices).id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 91,
                reason: "The night reader found an evidence-backed connection between kept pages.",
                prompt: "The Book left a page tucked in overnight.",
                detail: draft.interpretation,
                payload: BookPagePayload(
                    headline: draft.headline,
                    body: body,
                    metadata: [
                        "source": BookPageSourceRegistry.source(for: .bookNotices).id,
                        "overnightConnection": "true",
                        "connectionNarrative": "true",
                        "connectionKind": draft.kind,
                        "connectionID": draft.candidateID,
                        "observationKey": draft.observationKey,
                        "magicMomentEligible": "true",
                        "evidencePageIDs": draft.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": draft.evidenceCards,
                        "feedbackPrompt": "Did the Book read this right?",
                        "tags": "book-notices,overnight-connection,local-memory"
                    ]
                )
            )
        }
    }
}

struct OvernightConnectionPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !context.distress.isActive else { return [] }
        return OvernightConnectionReview.surfaces(for: day, inputs: inputs, now: now)
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
        if type == .patreon || type == .quip {
            return keptPageCount < 30
        }
        return lockedTypes.contains(type) && keptPageCount < requiredKeptPageCount
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
        let isClashRecipe = packet.blueprint.flatMap { blueprint in
            StoryFormRegistry.recipes.first { $0.id == blueprint.recipeID }
        }?.preferredTags.contains("clash") ?? false
        if isClashRecipe {
            return StoryPageMechanicMandate(
                kind: .beliefDice,
                choiceID: choiceID(for: .beliefDice, packet: packet, seed: seed),
                enchantmentID: nil,
                reason: "A clash is underway; the confrontation choice carries the Belief dice."
            )
        }
        let roll = abs(seed) % 100
        var eligibleKinds = eligibleKinds(for: packet, inputs: inputs)
        if recentlyCompletedExternalMechanic(day: day, inputs: inputs, now: now) {
            eligibleKinds.removeAll { $0 == .compassRun || $0 == .enchantment }
        }
        guard !eligibleKinds.isEmpty else { return .none }

        let desiredKind: StoryPageMechanicMandateKind
        let pacing = mechanicPacing()
        if roll < pacing.noneBelow {
            return .none
        } else if roll < pacing.beliefBelow {
            desiredKind = .beliefDice
        } else if roll < pacing.compassBelow {
            desiredKind = .compassRun
        } else {
            desiredKind = .enchantment
        }

        guard eligibleKinds.contains(desiredKind) else { return .none }
        let kind = desiredKind
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
        return true
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

    private static func recentlyCompletedExternalMechanic(day: BookDay, inputs: BookSourceInputs, now: Date) -> Bool {
        recentStoryPages(day: day, inputs: inputs, now: now, within: 5 * 86_400)
            .prefix(5)
            .contains { page in
                storyMechanicTags(for: page).contains("compass-run") ||
                    storyMechanicTags(for: page).contains("enchantment")
            }
    }

    private static func storyMechanicTags(for page: BookPage) -> Set<String> {
        let tags = Set(page.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var mechanics = Set<String>()
        if tags.contains("story-mechanic:compass-run") || (tags.contains("story-mechanic") && tags.contains("compass-run")) {
            mechanics.insert("compass-run")
        }
        if tags.contains("story-mechanic:enchantment") || (tags.contains("story-mechanic") && tags.contains("enchantment")) {
            mechanics.insert("enchantment")
        }
        if tags.contains("story-mechanic:belief-dice") || (tags.contains("story-mechanic") && tags.contains("belief-dice")) {
            mechanics.insert("belief-dice")
        }
        return mechanics
    }

    private static func mechanicPacing() -> (noneBelow: Int, beliefBelow: Int, compassBelow: Int) {
        // Belief Dice are the fun, low-friction default Story Page mechanic:
        // just under half of eligible pages. Compass Runs and Enchantments are
        // rarer bridges into real-world proof.
        return (45, 89, 95)
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
            reason: manual ? "You popped the clasp yourself." : "Something in the Inventory has been waiting for you to figure it out.",
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
            !$0.comingSoon && !PackEntitlements.owns($0.packID, in: inputs.ownedPackIDs)
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
    case company

    var title: String {
        switch self {
        case .loom: return "The Loom"
        case .constellation: return "The Constellation"
        case .company: return "The Company You Keep"
        }
    }

    var detail: String {
        switch self {
        case .loom:
            return "The threads get warm and pull tight wherever the cast has started to really care about each other."
        case .constellation:
            return "The stars glow brightest where your Belief lives, and little lines show where your attention has been wandering."
        case .company:
            return "Real people, shared interests, ordinary rituals, and the different doors through which they enter your life."
        }
    }
}

protocol BookPageSourceAdapter {
    var source: BookPageSource { get }
    /// Declared here (not just defaulted in the extension) so an override on a
    /// concrete adapter dispatches dynamically when called on the existential.
    var servedSourceIDs: [String] { get }
    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage]
    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage
}

extension BookPageSourceAdapter {
    /// Every active source ID this adapter can stamp onto a surfaced page.
    /// Most adapters serve only their own `source`; a few (e.g. the Wonder
    /// Compass) fan one adapter out across several child source IDs so those
    /// children can carry their own Belief and titles. The curator invariant
    /// "every active source has an adapter" reads this, not just `source.id`.
    var servedSourceIDs: [String] { [source.id] }

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
        let baseTags = "inner-weather,faculty-kind:innerWeather,faculty-window:\(window.id),dr-inkrest,therapy-chart"
        var pages = [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .mood,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 72 : 64,
                reason: context.distress.isActive ? "Something heavy showed up, and it just wants a gentle name." : "Dr. Inkrest left a little chart window open for you.",
                prompt: "What's the weather like inside you?",
                detail: "\(window.name). Give the sky inside you a name. One tap is plenty.",
                payload: BookPagePayload(
                    headline: "Inner Weather",
                    body: "Give the sky inside you a name. One tap is plenty.",
                    metadata: [
                        "source": source.id,
                        "facultyID": FacultyEntryKind.innerWeather.facultyID,
                        "facultyKind": FacultyEntryKind.innerWeather.rawValue,
                        "facultyWindowID": window.id,
                        "facultyWindowName": window.name,
                        "chartTitle": FacultyEntryKind.innerWeather.chartTitle,
                        "tags": baseTags
                    ]
                )
            )
        ]
        // Shadow Wonder: the same chart, but with the book's "harmonize with the
        // grey" permission — name the inner sky honestly, overcast and all.
        let shadow = ShadowWonder.state(inputs: inputs, now: now)
        if shadow.isActive {
            var metadata = pages[0].payload.metadata
            metadata["tags"] = ShadowWonder.mergedTags(baseTags + ",mood-match", inputs: inputs, now: now)
            metadata["shadowVariantOf"] = pages[0].id
            metadata["variant"] = "shadow-wonder"
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-\(day.id)-\(window.id)",
                    type: .mood,
                    sourceID: source.id,
                    intent: .capture,
                    renderStyle: .promptCard,
                    score: (context.distress.isActive ? 72 : 64) + shadow.scoreBoost,
                    reason: "Shadow Wonder says it's okay to hum along with the grey instead of trying to make it bright.",
                    prompt: "What's the weather inside — the real, quiet, grey kind?",
                    detail: "\(window.name). The grey is allowed. Name the sky inside you exactly how it is, clouds and all. One honest tap is plenty.",
                    payload: BookPagePayload(
                        headline: "Inner Weather",
                        body: "Name the inner sky in its true key. A minor key still holds you. One honest tap is enough.",
                        metadata: metadata
                    )
                )
            )
        }
        return pages
    }
}

enum JournalPromptFamily: String, CaseIterable {
    case wonder
    case authorship
    case listening
    case moment
    case connection
    case shadow
    case traditional
    case mischief
    case rest
}

enum JournalPromptContext: String {
    case none
    case recentPage
    case person
    case place
    case weather
    case recurringThread
}

struct JournalPromptEntry: Equatable {
    var id: String
    var family: JournalPromptFamily
    var title: String
    var question: String
    var deeperQuestion: String
    var placeholder: String
    var semanticHints: [String]
    var context: JournalPromptContext = .none
    var authorEntityID: String? = nil
    var authorName: String? = nil
    var authorLead: String? = nil

    var isCastAuthored: Bool { authorEntityID != nil }

    var semanticDocument: String {
        ([title, question, deeperQuestion] + semanticHints + [family.rawValue])
            .joined(separator: " ")
    }
}

struct JournalPromptSelection: Equatable {
    var entry: JournalPromptEntry
    var question: String
    var deeperQuestion: String
    var selector: String
    var evidencePageID: String?
    var evidenceExcerpt: String?
    var contextLabel: String?
}

enum JournalPromptCatalog {
    static let entries: [JournalPromptEntry] = [
        prompt("almost-missed", .wonder, "The Thing That Nearly Vanished",
               "What did you almost miss today?",
               "What made you look twice?",
               "I almost missed...",
               ["notice", "detail", "ordinary", "sensory", "attention", "small moment"]),
        prompt("ordinary-broke-character", .wonder, "When Ordinary Broke Character",
               "What ordinary thing briefly stopped being ordinary today?",
               "What changed: the thing, the light, the timing, or you?",
               "For a moment...",
               ["wonder", "surprise", "object", "place", "light", "unexpected"]),
        prompt("sound-punctuation", .wonder, "The Day's Punctuation",
               "What sound served as the day's punctuation?",
               "Was it a period, question mark, comma, or something less grammatical?",
               "The sound was...",
               ["sound", "voice", "music", "weather", "room", "rhythm"]),
        prompt("light-favorites", .wonder, "The Light Chose Favorites",
               "Where did the light behave as if it had chosen a favorite?",
               "What did it make visible that the room usually keeps quiet?",
               "The light chose...",
               ["light", "color", "window", "weather", "room", "sight", "photo"]),
        prompt("undocumented-side-quest", .mischief, "The Undocumented Side Quest",
               "What was today's unofficial side quest?",
               "At what exact moment did you accidentally accept it?",
               "The side quest began when...",
               ["errand", "adventure", "unexpected", "detour", "funny", "problem", "quest"]),
        prompt("smallest-scandal", .mischief, "A Very Small Scandal",
               "What was the day's smallest, least consequential scandal?",
               "Who—or what—behaved most suspiciously?",
               "The scandal involved...",
               ["funny", "awkward", "pet", "food", "object", "mistake", "ridiculous"]),
        prompt("object-performance-review", .mischief, "An Overdue Performance Review",
               "Which object near you worked hardest today without proper recognition?",
               "What rating does it receive, and what must management improve?",
               "Employee of the day...",
               ["object", "home", "work", "tool", "funny", "care", "ordinary"]),
        prompt("academy-transfer-student", .mischief, "Today's Transfer Student",
               "If today arrived at the Academy as a transfer student, what would be suspicious about it?",
               "Which Chapter would claim it first?",
               "Today arrived wearing...",
               ["day", "academy", "character", "funny", "weather", "mood", "story"]),
        prompt("two-percent", .authorship, "Two Percent Different",
               "What did you change your mind about by two percent?",
               "What tiny piece of evidence moved it?",
               "I am not entirely where I was on...",
               ["choice", "change", "decision", "belief", "learn", "evidence"]),
        prompt("chosen-moment", .authorship, "The Moment You Authored",
               "Where did you make a choice today instead of simply continuing?",
               "What became possible because you interrupted the default?",
               "I chose...",
               ["choice", "agency", "boundary", "decision", "courage", "change"]),
        prompt("tomorrow-line", .authorship, "A Line for Tomorrow",
               "What sentence do you need to be able to read tomorrow morning?",
               "Can it be both kind and completely true?",
               "Tomorrow, remember...",
               ["tomorrow", "intention", "choice", "courage", "need", "future"]),
        prompt("world-already-saying", .listening, "Before You Answered",
               "What was the world already trying to show you today?",
               "What happened when you stopped trying to make it mean something else?",
               "It kept showing me...",
               ["listen", "nature", "weather", "pattern", "signal", "patience", "notice"]),
        prompt("kept-returning", .listening, "The Returning Thing",
               "What kept returning to your attention after you dismissed it?",
               "What if recurrence, not loudness, is what made it important?",
               "It returned when...",
               ["repeat", "pattern", "memory", "attention", "thought", "object", "person"]),
        prompt("complete-without-lesson", .moment, "No Lesson Required",
               "Which part of today deserves no lesson, silver lining, or character growth?",
               "What changes if you let it remain complete exactly as it was?",
               "It was enough that...",
               ["moment", "present", "rest", "complete", "ordinary", "no lesson"]),
        prompt("first-surprise", .moment, "The Unplanned Hour",
               "What caught you genuinely off guard today?",
               "What did the surprise make vivid for a moment?",
               "I did not expect...",
               ["surprise", "unexpected", "moment", "change", "delight", "weather"]),
        prompt("room-temperature", .connection, "Who Changed the Room?",
               "Who changed the temperature of a room today simply by entering it?",
               "What did your body notice before your mind supplied the explanation?",
               "When they arrived...",
               ["person", "people", "relationship", "room", "body", "presence"]),
        prompt("still-echoing", .connection, "Still Echoing",
               "What did someone say that is still echoing?",
               "Is the echo carrying their meaning, or one you added later?",
               "They said...",
               ["person", "conversation", "voice", "relationship", "words", "memory"]),
        prompt("invisible-work", .connection, "The Work Nobody Announced",
               "Whose invisible work made your day easier?",
               "What exactly did they do that could have disappeared into 'nothing'?",
               "Because they...",
               ["person", "care", "kindness", "work", "family", "friend", "gratitude"]),
        prompt("convenient-truth", .shadow, "Waiting for a Better Time",
               "What truth are you waiting to become more convenient before admitting?",
               "What is the smallest honest version you can write without turning it into a verdict?",
               "The inconvenient part is...",
               ["truth", "avoid", "conflict", "boundary", "decision", "fear", "honest"]),
        prompt("protecting-avoidance", .shadow, "The Guard at the Door",
               "What might your avoidance be trying to protect?",
               "Can you thank the guard without giving it permanent control of the door?",
               "The guard thinks...",
               ["avoid", "protect", "fear", "conflict", "boundary", "care", "door"]),
        prompt("changed-room", .traditional, "Evidence of Today",
               "Look around. What did today's events change, move, empty, dirty, finish, or leave behind?",
               "Begin with the changed thing instead of a summary.",
               "The room proves today happened because...",
               ["day", "room", "object", "evidence", "home", "work", "detail"]),
        prompt("plain-chronology", .traditional, "What Happened",
               "What happened today? Tell it plainly. Which moment still has heat?",
               "Why that moment and not the supposedly important one?",
               "Today...",
               ["journal", "day", "memory", "event", "reflection", "traditional"]),
        prompt("hard-and-helped", .traditional, "Hard / Helped",
               "What was hard today? What helped—even a little?",
               "What does the size of the help tell you about what you actually needed?",
               "What was hard...\nWhat helped...",
               ["hard", "help", "care", "support", "tired", "reflection", "traditional"]),
        prompt("three-concrete-goods", .traditional, "Three Good Things with Names",
               "Name three good things, but no abstractions: give the person, object, place, sound, or action.",
               "Which one would be easiest to overlook tomorrow?",
               "1.\n2.\n3.",
               ["gratitude", "good", "person", "object", "place", "sound", "traditional"]),
        prompt("tomorrow-contain", .traditional, "A Shape for Tomorrow",
               "What do you need tomorrow to contain?",
               "What is the smallest form that need could honestly take?",
               "Tomorrow needs...",
               ["tomorrow", "need", "plan", "care", "rest", "traditional"]),
        prompt("free-page", .traditional, "No Discovery Required",
               "Write freely for five minutes. You do not have to discover anything.",
               "If a true sentence appears, let it stay unpolished.",
               "Start anywhere...",
               ["free write", "journal", "thought", "feeling", "traditional", "private"]),
        prompt("unfinished-permission", .rest, "Allowed to Remain Unfinished",
               "What may remain unfinished tonight without becoming a failure?",
               "What would closing the cover look like in practical terms?",
               "Tonight, I am leaving...",
               ["rest", "unfinished", "tired", "night", "permission", "care"]),
        prompt("stop-performing", .rest, "After the Performance",
               "What can stop performing now that the day is ending?",
               "What is still true when nobody needs anything from it?",
               "It can stop...",
               ["rest", "night", "work", "body", "performance", "quiet"]),
        prompt("survived-with-you", .rest, "The Things That Made It Home",
               "Name three things within reach that survived the day with you.",
               "Which one seems most ready to be put down?",
               "Still here with me...",
               ["rest", "object", "home", "night", "survive", "inventory"]),
        prompt("page-left-out", .wonder, "What the Page Left Out",
               "This line is still warm from today: “{excerpt}” What did it leave out?",
               "Was the missing thing too small, too strange, or too close to name the first time?",
               "What it left out...",
               ["page", "memory", "detail", "missing", "notice", "evidence"],
               context: .recentPage),
        prompt("routine-cross-examination", .wonder, "Evidence Against an Ordinary Day",
               "Routine claims nothing happened. Your own page says: “{excerpt}” What does that line prove?",
               "What would Routine prefer you call insignificant?",
               "It proves...",
               ["routine", "evidence", "ordinary", "page", "memory", "wonder"],
               context: .recentPage),
        prompt("named-person-temperature", .connection, "A Person in the Margins",
               "{person} crossed the Book's margins recently. What did their presence change that a timeline would miss?",
               "What detail belongs specifically to them and no one else?",
               "When {person} was there...",
               ["person", "relationship", "presence", "memory", "change"],
               context: .person),
        prompt("place-at-this-hour", .moment, "This Place, This Hour",
               "What is {place} like at this exact hour—not generally, but tonight?",
               "What would be gone if you returned at noon?",
               "At this hour, {place}...",
               ["place", "location", "night", "room", "weather", "time"],
               context: .place),
        prompt("weather-made-visible", .listening, "What the Weather Revealed",
               "The weather arrived as “{weather}.” What did it make easier to notice?",
               "What did the forecast fail to mention?",
               "The weather revealed...",
               ["weather", "outside", "sound", "light", "body", "place"],
               context: .weather),
        prompt("thread-keeps-pulling", .listening, "The Thread That Keeps Pulling",
               "The Book keeps finding “{thread}” in the recent margins. What do you think is actually gathering there?",
               "What would be too early—or too neat—to conclude?",
               "The thread might be...",
               ["pattern", "theme", "repeat", "memory", "meaning", "notice"],
               context: .recurringThread),

        prompt("penny-evidence", .wonder, "Filed as Contradictory Evidence",
               "Penny Blackletter requests one detail proving today was not merely a repeat of yesterday.",
               "Would the evidence survive cross-examination by someone extremely committed to being bored?",
               "Evidence, item one...",
               ["evidence", "detail", "routine", "archive", "ordinary", "funny"],
               author: ("penny-blackletter", "Penny Blackletter", "Penny has opened a file. Apparently the day is under investigation.")),
        prompt("wicker-premise", .shadow, "The Premise Wicker Doesn't Buy",
               "Which explanation about today sounds tidy, reasonable—and not entirely true?",
               "What exact fact makes the premise wobble?",
               "The tidy version is...",
               ["truth", "conflict", "premise", "doubt", "avoid", "evidence"],
               author: ("wicker-eddies", "Wicker Eddies", "Wicker underlined this twice, which is rarely a peaceful sign.")),
        prompt("zara-small-return", .connection, "A Small Return",
               "Who proved something through one small return today—coming back, following through, remembering, or making room?",
               "What trust did that tiny act build?",
               "The small return was...",
               ["trust", "friendship", "person", "return", "care", "relationship"],
               author: ("zara-finch", "Zara Finch", "Zara left this question beside the safest path through the page.")),
        prompt("stonebrook-set-down", .rest, "Put One Thing Down",
               "What are you still carrying only because you have not formally put it down?",
               "What would count as setting it down for tonight—not forever?",
               "For tonight, I can put down...",
               ["rest", "night", "carry", "unfinished", "body", "care"],
               author: ("professor-cedric-stonebrook", "Professor Cedric Stonebrook", "Professor Stonebrook has turned the hourglass on its side.")),
        prompt("villanelle-true-line", .traditional, "One Line That Holds",
               "Write one sentence from today that is true enough to carry time.",
               "Which pretty but inaccurate word can you cross out?",
               "The sentence is...",
               ["sentence", "write", "memory", "true", "detail", "souvenir"],
               author: ("professor-vivian-villanelle", "Professor Vivian Villanelle", "Professor Villanelle is weighing the sentence in her palm.")),
        prompt("wispwood-object", .mischief, "The Object's Complaint",
               "Choose one nearby object. If it were allowed one calm, specific complaint about today, what would it say?",
               "What visible fact supports its case?",
               "The object says...",
               ["object", "voice", "home", "funny", "enchantment", "evidence"],
               author: ("professor-luna-wispwood", "Professor Luna Wispwood", "Professor Wispwood apologized to the object before handing it the floor."))
    ]

    private static func prompt(
        _ id: String,
        _ family: JournalPromptFamily,
        _ title: String,
        _ question: String,
        _ deeperQuestion: String,
        _ placeholder: String,
        _ semanticHints: [String],
        context: JournalPromptContext = .none,
        author: (id: String, name: String, lead: String)? = nil
    ) -> JournalPromptEntry {
        JournalPromptEntry(
            id: id,
            family: family,
            title: title,
            question: question,
            deeperQuestion: deeperQuestion,
            placeholder: placeholder,
            semanticHints: semanticHints,
            context: context,
            authorEntityID: author?.id,
            authorName: author?.name,
            authorLead: author?.lead
        )
    }
}

enum JournalPromptSelector {
    private struct Signals {
        var recentPages: [BookPage]
        var personName: String?
        var placeName: String?
        var weather: String?
        var recurringThread: String?
        var query: String
        var queryWords: Set<String>
    }

    static func select(
        day: BookDay,
        inputs: BookSourceInputs,
        context: CuratorContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scorer: StacksSemanticScoring? = nil
    ) -> JournalPromptSelection {
        let signals = signals(day: day, inputs: inputs, now: now)
        let hour = calendar.component(.hour, from: now)
        let isEvening = (17..<22).contains(hour)
        let isVeryLate = hour >= 22 || hour < 5
        let recentPromptIDs = recentTagValues(prefix: "journal-prompt:", pages: signals.recentPages)
        let recentFamilies = recentTagValues(prefix: "journal-family:", pages: signals.recentPages)
        let recentCastPage = signals.recentPages.prefix(8).contains {
            $0.tags.contains(where: { $0.hasPrefix("journal-author:") && $0 != "journal-author:the-book" })
        }
        let castTurn = !context.distress.isActive
            && !isVeryLate
            && !recentCastPage
            && abs("\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 6))-journal-cast".stableHash) % 5 == 0
        let enabledCastIDs = Set(NarrativePackRegistry.entities.map(\.id))

        var candidates = JournalPromptCatalog.entries.filter { entry in
            guard contextAvailable(entry.context, signals: signals) else { return false }
            if castTurn {
                guard entry.isCastAuthored,
                      let authorID = entry.authorEntityID,
                      enabledCastIDs.contains(authorID) else {
                    return false
                }
            } else if entry.isCastAuthored {
                return false
            }
            if context.distress.isActive && [.shadow, .mischief].contains(entry.family) {
                return false
            }
            if isVeryLate && [.shadow, .authorship, .mischief].contains(entry.family) {
                return false
            }
            return true
        }
        if candidates.isEmpty {
            candidates = JournalPromptCatalog.entries.filter { !$0.isCastAuthored && $0.context == .none }
        }

        var scored = candidates.map { entry -> (entry: JournalPromptEntry, score: Int, similarity: Double?) in
            let entryWords = SemanticKeepEcho.contentWords(in: entry.semanticDocument)
            let overlap = signals.queryWords.intersection(entryWords).count
            var score = 30 + min(30, overlap * 6)
            if entry.context != .none { score += 12 }
            if isEvening { score += eveningBoost(entry.family) }
            if isVeryLate && [.rest, .traditional, .listening].contains(entry.family) { score += 16 }
            if context.distress.isActive && [.rest, .traditional, .listening].contains(entry.family) { score += 18 }
            if recentPromptIDs.contains(entry.id) { score -= 80 }
            if recentFamilies.prefix(2).contains(entry.family.rawValue) { score -= 12 }
            if entry.isCastAuthored { score += 4 }
            score += abs("\(day.id)-\(entry.id)-journal".stableHash) % 9
            return (entry, score, nil)
        }
        scored.sort { rankedBefore($0, $1) }

        if let scorer, !signals.query.isEmpty {
            for index in scored.indices.prefix(12) {
                guard let similarity = scorer.similarity(
                    between: signals.query,
                    and: scored[index].entry.semanticDocument
                ) else { continue }
                scored[index].similarity = similarity
                scored[index].score += Int((similarity * 36).rounded())
            }
            scored.sort { rankedBefore($0, $1) }
        }

        let selected = scored.first?.entry
            ?? JournalPromptCatalog.entries.first(where: { $0.id == "plain-chronology" })!
        let evidencePage = bestEvidencePage(
            for: selected,
            pages: signals.recentPages,
            scorer: scorer
        )
        let excerpt = evidencePage.flatMap { clippedEvidence(from: $0) }
        let values: [String: String] = [
            "excerpt": excerpt ?? "one small thing happened",
            "person": signals.personName ?? "someone",
            "place": signals.placeName ?? "this place",
            "weather": signals.weather ?? "the weather outside",
            "thread": signals.recurringThread ?? "something unfinished"
        ]
        return JournalPromptSelection(
            entry: selected,
            question: replacingPlaceholders(in: selected.question, values: values),
            deeperQuestion: replacingPlaceholders(in: selected.deeperQuestion, values: values),
            selector: scorer == nil ? "context-lexical" : "context-semantic-lexical",
            evidencePageID: selected.context == .recentPage ? evidencePage?.id : nil,
            evidenceExcerpt: selected.context == .recentPage ? excerpt : nil,
            contextLabel: contextLabel(for: selected.context, signals: signals)
        )
    }

    private static func signals(day: BookDay, inputs: BookSourceInputs, now: Date) -> Signals {
        let cutoff = now.addingTimeInterval(-21 * 86_400)
        let pages = Dictionary(
            (inputs.days.suffix(21).flatMap(\.capturedPages) + day.capturedPages)
                .filter { $0.createdAt >= cutoff }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, second in first.createdAt >= second.createdAt ? first : second }
        ).values.sorted { left, right in
            if left.createdAt == right.createdAt { return left.id < right.id }
            return left.createdAt > right.createdAt
        }
        let authored = pages.filter {
            $0.origin == .userAuthored && $0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil
        }
        let pageText = authored.prefix(14).map { page in
            "\(page.userInput) \(page.tags.joined(separator: " ")) \(page.resolvedAttentionFingerprint.patternText)"
        }
        let usableFacts = inputs.selfFacts
            .filter { $0.usePermission != .doNotUse }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { "\($0.answer) \($0.tags.joined(separator: " "))" }
        let recurring = inputs.themes.sorted { $0.strength > $1.strength }.first?.name.nonEmpty
            ?? inputs.clusters.sorted { $0.strength > $1.strength }.first?.name.nonEmpty
        let person = inputs.people.threads
            .filter { !$0.resting }
            .sorted { left, right in
                if left.lastMentionDay == right.lastMentionDay { return left.name < right.name }
                return left.lastMentionDay > right.lastMentionDay
            }
            .first?.name.nonEmpty
        let place = inputs.currentLocationLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? inputs.nearbyAnchor?.anchor.name.nonEmpty
        let weather = inputs.weather?.phrase.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? inputs.enchantedWeather?.summary.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let queryPieces = pageText + usableFacts + [person, place, weather, recurring].compactMap { $0 }
        let query = String(queryPieces.joined(separator: ". ").prefix(2_400))
        return Signals(
            recentPages: pages,
            personName: person,
            placeName: place,
            weather: weather.map { String($0.prefix(140)) },
            recurringThread: recurring,
            query: query,
            queryWords: SemanticKeepEcho.contentWords(in: query)
        )
    }

    private static func contextAvailable(_ context: JournalPromptContext, signals: Signals) -> Bool {
        switch context {
        case .none: return true
        case .recentPage: return signals.recentPages.contains { clippedEvidence(from: $0) != nil }
        case .person: return signals.personName != nil
        case .place: return signals.placeName != nil
        case .weather: return signals.weather != nil
        case .recurringThread: return signals.recurringThread != nil
        }
    }

    private static func bestEvidencePage(
        for entry: JournalPromptEntry,
        pages: [BookPage],
        scorer: StacksSemanticScoring?
    ) -> BookPage? {
        let candidates = pages.filter { clippedEvidence(from: $0) != nil }.prefix(16)
        let hintWords = SemanticKeepEcho.contentWords(in: entry.semanticDocument)
        return candidates.enumerated().map { index, page in
            let text = clippedEvidence(from: page) ?? ""
            let words = SemanticKeepEcho.contentWords(in: "\(text) \(page.tags.joined(separator: " ")) \(page.resolvedAttentionFingerprint.patternText)")
            let lexical = hintWords.intersection(words).count * 8
            let semantic = scorer?.similarity(between: entry.semanticDocument, and: text) ?? 0
            return (page, lexical + Int((semantic * 40).rounded()) + max(0, 8 - index))
        }.max { left, right in
            if left.1 == right.1 { return left.0.createdAt < right.0.createdAt }
            return left.1 < right.1
        }?.0
    }

    private static func clippedEvidence(from page: BookPage) -> String? {
        let input = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        let firstLine = input.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? input
        let oneSentence = firstLine.bookPreviewSentenceLimit(1)
        guard !oneSentence.isEmpty else { return nil }
        if oneSentence.count <= 120 { return oneSentence }
        let prefix = oneSentence.prefix(120)
        let end = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<end]) + "\u{2026}"
    }

    private static func recentTagValues(prefix: String, pages: [BookPage]) -> [String] {
        pages.flatMap(\.tags).compactMap { tag in
            guard tag.hasPrefix(prefix) else { return nil }
            return String(tag.dropFirst(prefix.count))
        }
    }

    private static func eveningBoost(_ family: JournalPromptFamily) -> Int {
        switch family {
        case .wonder, .connection, .traditional: return 10
        case .moment, .listening, .rest: return 8
        case .authorship, .shadow, .mischief: return 5
        }
    }

    private static func rankedBefore(
        _ left: (entry: JournalPromptEntry, score: Int, similarity: Double?),
        _ right: (entry: JournalPromptEntry, score: Int, similarity: Double?)
    ) -> Bool {
        if left.score != right.score { return left.score > right.score }
        if left.similarity != right.similarity {
            return (left.similarity ?? 0) > (right.similarity ?? 0)
        }
        return left.entry.id < right.entry.id
    }

    private static func replacingPlaceholders(in text: String, values: [String: String]) -> String {
        values.reduce(text) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    private static func contextLabel(for context: JournalPromptContext, signals: Signals) -> String? {
        switch context {
        case .none, .recentPage: return nil
        case .person: return signals.personName
        case .place: return signals.placeName
        case .weather: return signals.weather
        case .recurringThread: return signals.recurringThread
        }
    }
}

struct DiaryPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .diary)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let scorer = inputs.semanticPassageSelectionEnabled ? SemanticKeepEcho.keepTimeScorer : nil
        let selection = JournalPromptSelector.select(
            day: day,
            inputs: inputs,
            context: context,
            now: now,
            scorer: scorer
        )
        let hour = Calendar.current.component(.hour, from: now)
        let isEvening = (17..<22).contains(hour)
        let isVeryLate = hour >= 22 || hour < 5
        let score: Int
        if isVeryLate {
            score = context.distress.isActive ? 58 : 50
        } else if isEvening {
            score = context.distress.isActive ? 72 : 70
        } else {
            score = context.distress.isActive ? 70 : 58
        }

        var metadata: [String: String] = [
            "source": source.id,
            "placeholder": selection.entry.placeholder,
            "journalPromptID": selection.entry.id,
            "journalFamily": selection.entry.family.rawValue,
            "journalDeeperQuestion": selection.deeperQuestion,
            "journalSelector": selection.selector,
            "journalSemanticallyAware": "true",
            "journalAuthorID": selection.entry.authorEntityID ?? "the-book",
            "journalAuthorName": selection.entry.authorName ?? "The Book",
            "tags": [
                "journal",
                "journal-page",
                "private",
                "journal-prompt:\(selection.entry.id)",
                "journal-family:\(selection.entry.family.rawValue)",
                "journal-author:\(selection.entry.authorEntityID ?? "the-book")"
            ].joined(separator: ",")
        ]
        if let evidencePageID = selection.evidencePageID {
            metadata["journalEvidencePageID"] = evidencePageID
        }
        if let evidenceExcerpt = selection.evidenceExcerpt {
            metadata["journalEvidenceExcerpt"] = evidenceExcerpt
        }
        if let contextLabel = selection.contextLabel {
            metadata["journalContextLabel"] = contextLabel
        }
        let authorLead = selection.entry.authorLead.map { "\($0)\n\n" } ?? ""
        let body = "\(authorLead)\(selection.question)\n\nOne sentence is enough."
        let detail: String
        if let author = selection.entry.authorName {
            detail = "\(author) left one question in the margin. Answer briefly or turn the page in your own time."
        } else if isVeryLate {
            detail = "A small question only. The Book would rather you sleep than perform an insight."
        } else {
            detail = "The Book chose one question from the shape of the day. Answer briefly or keep going."
        }

        return [
            SurfacePage(
                id: "\(source.id)-journal-\(selection.entry.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 6))",
                type: .diary,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: score,
                reason: context.distress.isActive
                    ? "A private Journal Page can hold one true thing without trying to repair it."
                    : isEvening
                    ? "Evening gives the Book enough of the day to ask one unusually good question."
                    : "The Book found a question that fits the material already gathering in the margins.",
                prompt: selection.question,
                detail: detail,
                payload: BookPagePayload(
                    headline: selection.entry.title,
                    body: body,
                    metadata: metadata
                )
            )
        ]
    }
}

struct PlainPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .plainPage)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let pages = Self.pagewrightSeedPages(from: inputs.days, limit: 3)
        guard pages.count >= 3 else { return [] }

        let slot = SurfaceCadence.slotID(for: now, hours: 72)
        return [
            SurfacePage(
                id: "pagewright-invitation-\(slot)",
                type: .plainPage,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 34 : 67,
                reason: "The Pagewright has enough of the reader's own material to begin a spread.",
                prompt: "The Pagewright Has Laid Things Out",
                detail: "A few things you kept are already waiting on the canvas — photographs, illuminated plates, and scraps from the Book. Move them until they belong together.",
                payload: BookPagePayload(
                    headline: "A Pagewright Spread Is Waiting",
                    body: "The Pagewright has been through the kept pages with clean hands and questionable scissors.\n\nA few pieces are already on the table. Open the spread and arrange what belongs together.",
                    metadata: [
                        "source": "pagewright",
                        "opensPagewright": "true",
                        "pagewrightPageIDs": pages.map(\.id).joined(separator: ","),
                        "symbol": "scissors",
                        "tags": "pagewright,scrapbook,kept-pages,invitation"
                    ]
                )
            )
        ]
    }

    static func pagewrightSeedPages(from days: [BookDay], limit: Int = 3) -> [BookPage] {
        let candidates = days
            .flatMap(\.pages)
            .filter {
                $0.type != .welcome
                    && $0.type != .helpTips
                    && ($0.pagewrightDefaultScrapText != nil || Self.hasPagewrightVisual($0))
            }
            .sorted { lhs, rhs in
                let lhsVisual = Self.hasPagewrightVisual(lhs)
                let rhsVisual = Self.hasPagewrightVisual(rhs)
                if lhsVisual != rhsVisual { return lhsVisual }
                let lhsIlluminated = lhs.type == .illuminatedPhoto
                let rhsIlluminated = rhs.type == .illuminatedPhoto
                if lhsIlluminated != rhsIlluminated { return lhsIlluminated }
                return lhs.createdAt > rhs.createdAt
            }

        var selected: [BookPage] = []
        var selectedTypes: Set<BookPageType> = []
        for page in candidates where selected.count < limit {
            if selected.count < 3 || !selectedTypes.contains(page.type) {
                selected.append(page)
                selectedTypes.insert(page.type)
            }
        }
        if selected.count < limit {
            selected.append(contentsOf: candidates.filter { candidate in
                !selected.contains(where: { $0.id == candidate.id })
            }.prefix(limit - selected.count))
        }
        return selected
    }

    private static func hasPagewrightVisual(_ page: BookPage) -> Bool {
        page.mediaAssets.contains { asset in
            switch asset.kind {
            case .bundledImage, .renderedImageFile, .photoLibraryAsset:
                return true
            case .audioFile:
                return false
            }
        }
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
                reason: "Dr. Vellum left a plate-note window open for you.",
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
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let greyLevel = NothingTide.greyLevel(
            quietDays: inputs.quietDays,
            narrativeHeat: inputs.narrative?.recentEventCount ?? 0,
            distressActive: false,
            celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: inputs.hemisphere)
                + BookJumpEngine.greyShift(state: inputs.bookJump, now: now)
                + RadioStationRegistry.greyShift(state: inputs.radio, now: now)
                + inputs.nothingGreyOffset
        )
        var pages = [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .souvenir,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .quoteCard,
                score: eveningPrompt ? 78 : 58,
                reason: eveningPrompt ? "Evenings are a cozy time to tuck one little moment away." : "One tiny thing can hold the whole day still.",
                prompt: eveningPrompt ? "What moment do you not want to go blurry?" : "Catch one bright little thing.",
                detail: eveningPrompt ? "One specific sentence, before the day forgets it." : "A color, a sound, a sentence, one small kindness.",
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
        if greyLevel >= 2 {
            pages.append(
                SurfacePage(
                    id: "\(source.id)-grey-edge-\(day.id)-\(window.id)",
                    type: .souvenir,
                    sourceID: source.id,
                    intent: .capture,
                    renderStyle: .quoteCard,
                    score: 88 + greyLevel * 3,
                    reason: "The grey is leaning in close, but one true little sentence can turn the light back up.",
                    prompt: "Name one real thing you can reach right now.",
                    detail: "A color, a sound, a texture — one small proof the day isn't empty.",
                    payload: BookPagePayload(
                        headline: "One-Sentence Souvenir",
                        body: "The grey edge is creeping up to the desk. Keep one exact thing it can't squish flat.",
                        metadata: [
                            "source": source.id,
                            "checkInWindowID": window.id,
                            "checkInWindowName": window.name,
                            "variant": "grey-edge",
                            "greyLevel": "\(greyLevel)",
                            "tags": "souvenir,grey-edge,check-in-window:\(window.id)"
                        ]
                    )
                )
            )
        }
        if shadowState.isActive {
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-wonder-\(day.id)-\(window.id)",
                    type: .souvenir,
                    sourceID: source.id,
                    intent: .capture,
                    renderStyle: .quoteCard,
                    score: (eveningPrompt ? 78 : 58) + shadowState.scoreBoost,
                    reason: "Shadow Wonder is awake, so this souvenir can love the worn-out edge instead of scrubbing it shiny.",
                    prompt: "Shadow Souvenir: what worn old thing shouldn't be thrown away?",
                    detail: "One sentence of shadow wonder: rust, a repair, old evidence, quiet grey beauty.",
                    payload: BookPagePayload(
                        headline: "Shadow One-Sentence Souvenir",
                        body: ShadowWonder.souvenirPrompt,
                        metadata: [
                            "source": source.id,
                            "checkInWindowID": window.id,
                            "checkInWindowName": window.name,
                            "shadowVariantOf": "\(source.id)-\(day.id)-\(window.id)",
                            "variant": "shadow-wonder",
                            "tags": ShadowWonder.mergedTags("souvenir,check-in-window:\(window.id)", inputs: inputs, now: now)
                        ]
                    )
                )
            )
        }
        return pages
    }

    private func didCaptureSouvenir(in window: DailyCheckInWindow, day: BookDay) -> Bool {
        let tag = "check-in-window:\(window.id)"
        return day.pages.contains { page in
            page.type == .souvenir && page.tags.contains(tag)
        }
    }
}

/// A single "Gear Shifter" from Wonder Compass Chapter 10 (Center = Rest): one small,
/// concrete way to drop out of Beta (numbing) into Alpha (awake rest) or Theta (deep
/// rest). The Center Page offers one at a time, chosen by the hour and the day's state —
/// never as a task, always as a relief. "Find the one that feels like a relief, not a chore."
struct CenterGearShifter: Equatable {
    enum Gear: String, Equatable {
        case alpha
        case theta

        /// The short label the page shows beside the shifter's name.
        var label: String {
            switch self {
            case .alpha: return "Alpha — recharge, stay awake"
            case .theta: return "Theta — deeper repair"
            }
        }
    }

    let id: String
    let title: String
    let gear: Gear
    /// The concrete thing to do — phrased as an invitation, not an instruction.
    let move: String
    /// Why it works, in the chapter's reassuring voice.
    let why: String
    /// An SF Symbol name for the shifter.
    let symbol: String
}

/// The Chapter-10 menu of Gear Shifters, plus the logic for choosing which one the
/// Center Page leads with given the hour and the day's state.
enum CenterGearShifterMenu {
    // MARK: Alpha triggers — recharge while staying awake and present.

    static let softGaze = CenterGearShifter(
        id: "soft-gaze",
        title: "The Soft Gaze",
        gear: .alpha,
        move: "Soften your eyes on one spot ahead. Without moving them, let the far corners of the room arrive in your vision at the same time.",
        why: "Wide, panoramic vision tells the oldest part of your brain that nothing is hunting you. Your breath slows on its own and your shoulders drop half an inch. It's a biological all-clear.",
        symbol: "eye"
    )

    static let rhythmicLoop = CenterGearShifter(
        id: "rhythmic-loop",
        title: "The Rhythmic Loop",
        gear: .alpha,
        move: "Give your hands one small repeating motion — doodle slow spirals, shuffle a deck, knit a row, slice something for later.",
        why: "Low-stakes rhythm keeps the fidgety part of you busy so the rest of your mind can finally drift.",
        symbol: "hand.draw"
    )

    static let fractalSoak = CenterGearShifter(
        id: "fractal-soak",
        title: "The Fractal Soak",
        gear: .alpha,
        move: "Find a tree, a cloud, or moving water. Look at it for the length of a few breaths. Don't name it — just let your eyes wander the branches.",
        why: "Nature is built of fractals: the same pattern as your lungs and the veins in your wrist. Your brain reads it as family and stops spending energy. Oh. Family. I can rest here.",
        symbol: "leaf"
    )

    // MARK: Theta triggers — deeper repair and quiet breakthroughs.

    static let boredWalk = CenterGearShifter(
        id: "bored-walk",
        title: "The Bored Walk",
        gear: .theta,
        move: "Leave the phone here. Walk a route you already know by heart — no podcast, no step count. Just let your feet keep time.",
        why: "A familiar rhythm lets your mind go down to the basement and sort the day. The answer you've been chasing has been waiting there for the noise to stop.",
        symbol: "figure.walk"
    )

    static let auditory = CenterGearShifter(
        id: "auditory-entrainment",
        title: "Auditory Entrainment",
        gear: .theta,
        move: "Headphones on. Put on brown noise or binaural beats — not white noise, it's too harsh. Let it be the only thing arriving.",
        why: "Your brain syncs its rhythm to what it hears, like a tuning fork. You're tuning yourself to a slower station.",
        symbol: "headphones"
    )

    static let noddies = CenterGearShifter(
        id: "the-noddies",
        title: "The Noddies",
        gear: .theta,
        move: "Lie down for twenty minutes (a sip of coffee first, if you like — it lands right as you surface). Drift toward the edge of sleep and don't cross it.",
        why: "That twilight border is where the subconscious leaves gifts. It's where Edison and Dalí went fishing for the ideas no one else could reach.",
        symbol: "moon.zzz"
    )

    /// Every shifter, in menu order, so the page can cycle through them when the
    /// reader asks for another.
    static let all: [CenterGearShifter] = [
        softGaze, rhythmicLoop, fractalSoak, boredWalk, auditory, noddies
    ]

    static func shifter(id: String) -> CenterGearShifter? {
        all.first { $0.id == id }
    }

    /// Pick the shifter the Center Page leads with. Distress gets the gentlest
    /// all-clear; evenings lean toward deep Theta rest; daytime offers awake Alpha
    /// recharges. The `seed` rotates the choice within a pool day to day.
    static func choose(hour: Int, distressActive: Bool, daylight: Bool, seed: Int) -> CenterGearShifter {
        if distressActive {
            // The fastest, lowest-effort relief when the day is already too much.
            return softGaze
        }
        let evening = hour >= 20 || hour < 6
        let pool: [CenterGearShifter]
        if evening {
            pool = daylight ? [boredWalk, auditory, noddies] : [auditory, noddies]
        } else if daylight {
            pool = [fractalSoak, rhythmicLoop, softGaze, boredWalk]
        } else {
            pool = [rhythmicLoop, softGaze, auditory]
        }
        let index = ((seed % pool.count) + pool.count) % pool.count
        return pool[index]
    }
}

/// The framing prose the Center Page reads before its two small reliefs. Lifted from
/// Chapter 10's "Numbing vs. Resting" — kept short so the page stays low and gentle.
enum CenterPageCopy {
    static let body = """
    You thought you were resting. Most of us aren't — we're numbing. Two hours of scrolling and you stand up tired but wired, jaw tight, because your brain was running a marathon the whole time. Numbing turns the static down. Rest turns the radio off.

    This page is the radio off. Nothing here needs finishing. Rest isn't the prize you earn after the work — in the physics of the Compass it's the pin the needle turns on. Loosen the pin and the whole needle wobbles.

    So: a minute of doing nothing, then one small relief. Neither is a task. If even sixty seconds feels long, ten is a whole beginning.
    """
}

struct RestPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .rest)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let hour = Calendar.current.component(.hour, from: now)
        guard context.distress.isActive || context.bleed.pageBias.first == .rest || day.capturedPages.isEmpty || hour >= 20 else {
            return []
        }
        let daylight = (7..<19).contains(hour)
        let gear = CenterGearShifterMenu.choose(
            hour: hour,
            distressActive: context.distress.isActive,
            daylight: daylight,
            seed: day.id.stableHash
        )
        var pages = [
            SurfacePage(
                type: .rest,
                sourceID: source.id,
                intent: .rest,
                renderStyle: .gentleTranslation,
                score: context.distress.isActive ? 96 : (context.bleed.pageBias.first == .rest ? 88 : 62),
                reason: context.distress.isActive ? "The Book turns the lamps down low before it offers you anything else." : "Sometimes the day just needs a quiet middle to rest in.",
                prompt: "The Center Page just opened.",
                detail: "No quest. No fixing. Just a small, true place to land.",
                payload: BookPagePayload(
                    headline: "Center Page",
                    body: CenterPageCopy.body,
                    metadata: [
                        "source": source.id,
                        "centerGearID": gear.id
                    ]
                )
            )
        ]
        // Shadow Wonder: the Center kept by lamplight — Quiet Hours in the dark,
        // rest as the still center of the dark Compass rather than a failure to adventure.
        let shadow = ShadowWonder.state(inputs: inputs, now: now)
        if shadow.isActive {
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-rest",
                    type: .rest,
                    sourceID: source.id,
                    intent: .rest,
                    renderStyle: .gentleTranslation,
                    score: (context.distress.isActive ? 96 : (context.bleed.pageBias.first == .rest ? 88 : 62)) + shadow.scoreBoost,
                    reason: "Shadow Wonder keeps the Center lit by one small lamp; resting is the still, quiet middle of the dark Compass.",
                    prompt: "Quiet Hours just opened in the dark.",
                    detail: "No quest, no fixing, no making it brighter. Let the room keep its shadows and just land here a while.",
                    payload: BookPagePayload(
                        headline: "Center Page",
                        body: CenterPageCopy.body,
                        metadata: [
                            "source": source.id,
                            "centerGearID": gear.id,
                            "shadowVariantOf": "\(source.id)-rest",
                            "variant": "shadow-wonder",
                            "tags": ShadowWonder.mergedTags("center,rest,quiet-hours", inputs: inputs, now: now)
                        ]
                    )
                )
            )
        }
        return pages
    }
}

struct BookOfYouPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookOfYou)

    /// The very first braid of an install is allowed to arrive early — as soon
    /// as a few pages are kept — so a reader who onboards in the morning still
    /// sees the write → read-back loop close in the same session. Every braid
    /// after this one waits for the evening rhythm.
    static let firstBraidPageThreshold = 3

    static func mayShowBraid(for day: BookDay, previousDays: [BookDay], now: Date) -> Bool {
        guard day.bookOfYou == nil, !day.capturedPages.isEmpty else { return false }
        if BookSchedule.isBraidSurfaceTime(now) { return true }
        let everBraided = (previousDays + [day]).contains { $0.bookOfYou != nil }
        return !everBraided && day.capturedPages.count >= firstBraidPageThreshold
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard Self.mayShowBraid(for: day, previousDays: inputs.days, now: now) else {
            return []
        }
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        var metadata = ["source": source.id]
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }
        let titleLine = title.map { " A \($0.name) braid should show its receipts." } ?? ""
        return [
            SurfacePage(
                type: .bookOfYou,
                sourceID: source.id,
                intent: .braid,
                renderStyle: .loreLetter,
                score: day.capturedPages.count >= 3 ? 90 : 74,
                reason: day.capturedPages.count >= 3 ? "There are enough little bits now to braid something really strong." : "Today has a few little bits worth tying together.",
                prompt: title.map { "The Book wants to braid a \($0.name) day." } ?? "The Book wants to braid today.",
                detail: "Gather all the little bits into one page worth keeping.\(titleLine)",
                payload: BookPagePayload(
                    headline: "Book of You",
                    body: title.map { "Gather the fragments into one \($0.name) page worth keeping.\n\n\($0.compassLine)" } ?? "Gather the fragments into one page worth keeping.",
                    metadata: metadata
                )
            )
        ]
    }
}

enum ReturnedStackRole: String, Codable, CaseIterable {
    case rhyme
    case longMemory
    case wildCard

    var title: String {
        switch self {
        case .rhyme: return "The Rhyme"
        case .longMemory: return "The Long Memory"
        case .wildCard: return "The Wild Card"
        }
    }

    var subtitle: String {
        switch self {
        case .rhyme: return "Something in the recent margins called this back."
        case .longMemory: return "The Stacks refuse to let a long silence become disappearance."
        case .wildCard: return "One page returns without having to justify itself."
        }
    }

    var symbolName: String {
        switch self {
        case .rhyme: return "point.3.connected.trianglepath.dotted"
        case .longMemory: return "lamp.desk"
        case .wildCard: return "sparkles"
        }
    }
}

struct ReturnedStackCard: Identifiable, Equatable {
    var page: BookPage
    var role: ReturnedStackRole
    var reason: String
    var tinyAction: String

    var id: String { page.id }
}

/// The daily ritual behind Returned From the Stacks.
///
/// Its three chairs have different laws: a recent rhyme, a page that has waited
/// longest for light, and one sanctioned surprise. Selection is deterministic
/// for the calendar day and persisted by `BookArchiveDatabase`, so opening the
/// fold does not reshuffle it. Recent returns rest before they may be selected
/// again, with a shorter emergency rest only when a young archive would
/// otherwise leave a chair empty.
enum ReturnedStacksRitual {
    static let surfacePrefix = "returned-stacks"
    static let preferredRestDays = 14
    static let emergencyRestDays = 3

    private struct Connection {
        var score: Int
        var reason: String
    }

    static func surfaceName(role: ReturnedStackRole, index: Int) -> String {
        "\(surfacePrefix):\(index):\(role.rawValue)"
    }

    static func isEligible(_ page: BookPage) -> Bool {
        let excludedTypes: Set<BookPageType> = [
            .mood, .rest, .body, .fuel, .weather,
            .bookOfYou, .bookRemembered, .bookPocket,
            .helpTips, .welcome, .inventory, .bindery,
            .radio, .calendar, .todaysSky
        ]
        guard !excludedTypes.contains(page.type),
              page.privacy != .localSensitive,
              let preview = page.archivePreviewText?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              preview.count >= 12 else {
            return false
        }
        return true
    }

    static func cards(
        from days: [BookDay],
        history: [BookArchiveResurfacing],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [ReturnedStackCard] {
        guard limit > 0 else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        let allPages = days
            .flatMap(\.pages)
            .filter { $0.createdAt < startOfToday && isEligible($0) }
        let pagesByID = Dictionary(uniqueKeysWithValues: allPages.map { ($0.id, $0) })

        let todaysHistory = history
            .filter {
                $0.surface.hasPrefix(surfacePrefix)
                    && $0.surfacedAt >= startOfToday
                    && $0.surfacedAt <= now
            }
            .sorted { historyIndex($0.surface) < historyIndex($1.surface) }
        var cards = todaysHistory.compactMap { event -> ReturnedStackCard? in
            guard let page = pagesByID[event.pageID] else { return nil }
            return ReturnedStackCard(
                page: page,
                role: historyRole(event.surface) ?? .wildCard,
                reason: event.reason,
                tinyAction: tinyAction(for: page)
            )
        }
        if cards.count >= limit {
            return Array(cards.prefix(limit))
        }

        let selectedIDs = Set(cards.map(\.page.id))
        let returnedAtByPageID = history
            .filter { $0.surface.hasPrefix(surfacePrefix) }
            .reduce(into: [String: Date]()) { result, event in
                result[event.pageID] = max(result[event.pageID] ?? .distantPast, event.surfacedAt)
            }
        let references = referencePages(from: days, before: now, calendar: calendar)
        let preferredCutoff = calendar.date(byAdding: .day, value: -preferredRestDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(-preferredRestDays) * 86_400)
        let emergencyCutoff = calendar.date(byAdding: .day, value: -emergencyRestDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(-emergencyRestDays) * 86_400)

        func available(afterRestingSince cutoff: Date) -> [BookPage] {
            allPages.filter { page in
                !selectedIDs.contains(page.id)
                    && (returnedAtByPageID[page.id] ?? .distantPast) < cutoff
            }
        }

        var pool = available(afterRestingSince: preferredCutoff)
        if pool.count < limit - cards.count {
            pool = available(afterRestingSince: emergencyCutoff)
        }
        if pool.count < limit - cards.count {
            pool = allPages.filter { !selectedIDs.contains($0.id) }
        }

        let missingRoles = ReturnedStackRole.allCases.filter { role in
            !cards.contains { $0.role == role }
        }
        var usedTypes = Set(cards.map(\.page.type))
        for role in missingRoles where cards.count < limit {
            guard !pool.isEmpty else { break }
            let choice: BookPage
            let reason: String
            switch role {
            case .rhyme:
                let ranked = pool
                    .map { ($0, connection(for: $0, references: references, now: now, calendar: calendar)) }
                    .sorted { left, right in
                        if left.1.score == right.1.score {
                            return stableDailyRank(pageID: left.0.id, now: now, calendar: calendar)
                                < stableDailyRank(pageID: right.0.id, now: now, calendar: calendar)
                        }
                        return left.1.score > right.1.score
                    }
                guard let best = ranked.first else { continue }
                choice = best.0
                reason = best.1.reason
            case .longMemory:
                choice = pool.sorted { left, right in
                    let leftReturn = returnedAtByPageID[left.id] ?? .distantPast
                    let rightReturn = returnedAtByPageID[right.id] ?? .distantPast
                    if leftReturn == rightReturn { return left.createdAt < right.createdAt }
                    return leftReturn < rightReturn
                }[0]
                reason = longMemoryReason(
                    for: choice,
                    lastReturnedAt: returnedAtByPageID[choice.id],
                    now: now,
                    calendar: calendar
                )
            case .wildCard:
                let diverse = pool.filter { !usedTypes.contains($0.type) }
                let choices = diverse.isEmpty ? pool : diverse
                choice = choices.min {
                    stableDailyRank(pageID: $0.id, now: now, calendar: calendar)
                        < stableDailyRank(pageID: $1.id, now: now, calendar: calendar)
                } ?? choices[0]
                reason = wildCardReason(for: choice, now: now, calendar: calendar)
            }

            cards.append(
                ReturnedStackCard(
                    page: choice,
                    role: role,
                    reason: reason,
                    tinyAction: tinyAction(for: choice)
                )
            )
            pool.removeAll { $0.id == choice.id }
            usedTypes.insert(choice.type)
        }
        return Array(cards.prefix(limit))
    }

    private static func referencePages(
        from days: [BookDay],
        before now: Date,
        calendar: Calendar
    ) -> [BookPage] {
        let recentCutoff = calendar.date(byAdding: .day, value: -4, to: now)
            ?? now.addingTimeInterval(-4 * 86_400)
        return days
            .flatMap(\.pages)
            .filter {
                $0.createdAt >= recentCutoff
                    && $0.createdAt <= now
                    && isEligible($0)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .map { $0 }
    }

    private static func connection(
        for page: BookPage,
        references: [BookPage],
        now: Date,
        calendar: Calendar
    ) -> Connection {
        if let semantic = references.first(where: {
            $0.tags.contains("\(SemanticKeepEcho.sourceTagPrefix)\(page.id)")
        }), let line = semantic.tags
            .first(where: { $0.hasPrefix(SemanticKeepEcho.lineTagPrefix) })
            .map({ String($0.dropFirst(SemanticKeepEcho.lineTagPrefix.count)) })
            .flatMap(\.nonEmpty) {
            return Connection(score: 140, reason: line)
        }

        let pageWords = meaningfulWords(in: page.archivePreviewText ?? "")
        let wordMatches = references.compactMap { reference -> (BookPage, String)? in
            let overlap = pageWords.intersection(meaningfulWords(in: reference.archivePreviewText ?? ""))
            guard let word = overlap.sorted(by: {
                if $0.count == $1.count { return $0 < $1 }
                return $0.count > $1.count
            }).first else { return nil }
            return (reference, word)
        }
        if let match = wordMatches.sorted(by: { $0.1.count > $1.1.count }).first {
            let when = relativeDay(match.0.createdAt, now: now, calendar: calendar)
            return Connection(
                score: 90 + match.1.count,
                reason: "\(when) used “\(match.1)” again. The Stacks heard the rhyme."
            )
        }

        if let pageContext = page.context {
            for reference in references {
                guard let referenceContext = reference.context else { continue }
                let sharedWeather = Set(pageContext.weatherTags).intersection(referenceContext.weatherTags)
                if let weather = sharedWeather.sorted().first {
                    return Connection(
                        score: 76,
                        reason: "\(relativeDay(reference.createdAt, now: now, calendar: calendar)) carried \(weather) too—the same weather that pressed this page."
                    )
                }
                if let anchor = pageContext.nearbyAnchorID,
                   anchor == referenceContext.nearbyAnchorID {
                    return Connection(
                        score: 70,
                        reason: "A recent page was kept near the same Anchor. The place remembered this one."
                    )
                }
                if pageContext.dayPart == referenceContext.dayPart {
                    return Connection(
                        score: 42,
                        reason: "A recent \(referenceContext.dayPart) page struck the same hour-bell as this one."
                    )
                }
            }
        }

        let month = calendar.component(.month, from: page.createdAt)
        if month == calendar.component(.month, from: now) {
            return Connection(
                score: 36,
                reason: "The year has reached the month that first held this page. The light is leaning the same way."
            )
        }
        let weekday = calendar.component(.weekday, from: page.createdAt)
        if weekday == calendar.component(.weekday, from: now) {
            return Connection(
                score: 30,
                reason: "This was written on the same turn of the week. The calendar left the door unlatched."
            )
        }
        return Connection(
            score: 20 + (page.usedInBookOfYou ? 8 : 0),
            reason: "A recent margin and this page share no obvious word. The Book is keeping the quieter rhyme."
        )
    }

    private static func longMemoryReason(
        for page: BookPage,
        lastReturnedAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> String {
        if let lastReturnedAt {
            let days = ageDays(from: lastReturnedAt, to: now, calendar: calendar)
            return "This page has rested \(days) day\(days == 1 ? "" : "s") since its last return. Its lamp is due."
        }
        let days = ageDays(from: page.createdAt, to: now, calendar: calendar)
        return "This page has waited \(days) day\(days == 1 ? "" : "s") without once being called upstairs."
    }

    private static func wildCardReason(for page: BookPage, now: Date, calendar: Calendar) -> String {
        let month = page.createdAt.formatted(.dateTime.month(.wide))
        let year = calendar.component(.year, from: page.createdAt)
        let sameYear = year == calendar.component(.year, from: now)
        let when = sameYear ? month : "\(month) \(year)"
        return "One return each day is chosen by chance, so the Book cannot become predictable. Today’s fell open to \(when)."
    }

    private static func tinyAction(for page: BookPage) -> String {
        let text = "\(page.archivePreviewText ?? "") \(page.tags.joined(separator: " "))".lowercased()
        if text.contains("walk") || text.contains("outside") || text.contains("trail") {
            return "Step to the nearest threshold and see what the old page notices now."
        }
        if text.contains("coffee") || text.contains("tea") || text.contains("cup") {
            return "Let your next cup become completely real in your hand before the first sip."
        }
        if text.contains("friend") || text.contains("family") || page.type == .letter {
            return "Send one small warmth toward the person in this page—even if it stays silent."
        }
        if page.type == .wonderCompass || page.type == .location {
            return "Look up and name one direction the day could still take."
        }
        return "Look up from the Book and find one physical detail this page would understand."
    }

    private static func meaningfulWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
        )
    }

    private static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today’s margin" }
        if calendar.isDateInYesterday(date) { return "Yesterday’s margin" }
        let days = ageDays(from: date, to: now, calendar: calendar)
        return "A margin from \(days) days ago"
    }

    private static func ageDays(from date: Date, to now: Date, calendar: Calendar) -> Int {
        max(
            1,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: now)
            ).day ?? 1
        )
    }

    private static func stableDailyRank(pageID: String, now: Date, calendar: Calendar) -> UInt64 {
        KeepMarginalia.seed(for: "\(BookDay.id(for: now, calendar: calendar))-\(pageID)-returned-stacks")
    }

    private static func historyIndex(_ surface: String) -> Int {
        let parts = surface.split(separator: ":")
        guard parts.count >= 2 else { return .max }
        return Int(parts[1]) ?? .max
    }

    private static func historyRole(_ surface: String) -> ReturnedStackRole? {
        let parts = surface.split(separator: ":")
        guard let raw = parts.last else { return nil }
        return ReturnedStackRole(rawValue: String(raw))
    }
}

struct BookRememberedPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookRemembered)
    /// How long a returned archive page rests before the Book may return it
    /// again. A remembered page should feel found, not scheduled.
    static let rememberedRestDays = 45

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        guard !didRememberToday(day) else { return [] }
        let restingPageIDs = Self.rememberedPageIDs(
            days: inputs.days + [day],
            within: Self.rememberedRestDays,
            now: now
        )
        guard let visitation = BookRememberedEngine.visitation(
            from: inputs.resurfacingCandidates.filter { !restingPageIDs.contains($0.id) },
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

    /// Page IDs recently returned by Book Remembered, recovered from the kept
    /// page tags (`remembered-page:<id>`), so no separate vault flag is needed.
    static func rememberedPageIDs(days: [BookDay], within restDays: Int, now: Date) -> Set<String> {
        let cutoff = now.addingTimeInterval(TimeInterval(-restDays) * 86_400)
        return Set(
            days.flatMap(\.pages)
                .filter { $0.createdAt >= cutoff && $0.createdAt <= now }
                .flatMap(\.tags)
                .compactMap { tag in
                    tag.hasPrefix("remembered-page:") ? String(tag.dropFirst("remembered-page:".count)) : nil
                }
        )
    }
}

/// Surfaces "The Book's Pocket" now and then, once a few keepsakes have gathered
/// from pages the reader swiped away. The surface id is keyed to the keepsake
/// count, so adding a keepsake creates a fresh Pocket Page even while an earlier
/// pocketful is resting after dismissal.
struct BookPocketPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookPocket)

    /// The pocket needs to gather a little before it's worth emptying out.
    static let minimumKeepsakes = 2
    /// How many keepsakes the emptied-out letter shows at once.
    static let shownKeepsakes = 8

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let pocket = inputs.pocket
        guard pocket.count >= Self.minimumKeepsakes else { return [] }
        guard !openedPocketToday(day) else { return [] }

        let shown = Array(pocket.newestFirst.prefix(Self.shownKeepsakes))
        let latest = shown.first
        // Keyed to the count so a newly filled pocket is distinct from the last.
        let surfaceID = "\(source.id)-\(pocket.count)"
        let score = min(60, 40 + pocket.count * 2)
        let serialized = shown.map { keepsake in
            [keepsake.glyph, keepsake.object, keepsake.pageType.shortTitle, "\(keepsake.foundAt.timeIntervalSince1970)"]
                .joined(separator: "\u{1F}")
        }.joined(separator: "\n")
        let richKeepsakes = PocketKeepsakeArchive.encode(shown)

        return [
            SurfacePage(
                id: surfaceID,
                type: .bookPocket,
                sourceID: source.id,
                intent: .resurface,
                renderStyle: .loreLetter,
                score: score,
                reason: latest.map { "The Book has been keeping \($0.object) and a few other small things." }
                    ?? "The Book turns out its Pocket.",
                prompt: "The Book turns out its Pocket.",
                detail: shown.prefix(2).map(\.object).joined(separator: ", "),
                payload: BookPagePayload(
                    headline: "The Book's Pocket",
                    body: Self.body(for: shown, total: pocket.count),
                    metadata: [
                        "source": source.id,
                        "pocketItems": serialized,
                        PocketKeepsakeArchive.metadataKey: richKeepsakes,
                        "pocketTotal": "\(pocket.count)",
                        "tags": "book-pocket,keepsake,parting-whisper,local-memory"
                    ]
                )
            )
        ]
    }

    private func openedPocketToday(_ day: BookDay) -> Bool {
        day.pages.contains { $0.type == .bookPocket || $0.tags.contains("book-pocket") }
    }

    static func body(for keepsakes: [PocketKeepsake], total: Int) -> String {
        let opener = "I turned out my Pocket onto the desk. These are real fragments of the pages that left: their words, their pictures, and where they came from — kept, because letting a Page go should not make it vanish without a trace."
        let lines = keepsakes.map { keepsake in
            let title = keepsake.title?.nonEmpty ?? keepsake.object
            let excerpt = keepsake.excerpt?.nonEmpty.map { " — \u{201C}\($0)\u{201D}" } ?? ""
            return "\u{2022} \(title), from the \(keepsake.pageType.shortTitle.lowercased()) Page\(excerpt)"
        }
        let more = total > keepsakes.count ? "\n\n(\(total - keepsakes.count) more wait deeper in the lining.)" : ""
        return opener + "\n\n" + lines.joined(separator: "\n") + more
    }
}

/// The Book's earliest honest proof that it read *you*.
///
/// The pattern-noticing in `BookNoticesPageSourceAdapter` needs weeks of archive
/// before it can honestly claim a recurring motif, so it stays folded away
/// behind `libraryReadyForReflectivePages`. That leaves the crucial first days
/// carried entirely by atmosphere. This fills the gap: the first time a handful
/// of pages exist, the Book reflects *those specific pages* back — the reader's
/// own words, the rhythm of their keeping, and at most one tentative thread that
/// genuinely appears in two of them. It never claims a pattern it cannot show,
/// and it says as much out loud.
/// Night-one guesses the Book ventures before it has read a single page — cold
/// reading with the con removed. Each is Barnum-grade (near-universal for the
/// reader this app is for) but framed as a *wager*, not knowledge, because the
/// payoff comes later: once real pages exist, `FirstReading` turns a confirmed
/// wager into a receipt ("I guessed X; I no longer have to guess — here is
/// where you Y"). Barnum on night one, proof by day three.
enum FirstWagers {
    struct Wager: Identifiable, Equatable {
        let id: String
        /// The guess, in the Book's voice, addressed to the reader.
        let guess: String
        /// A compact restatement for the later receipt ("you notice more than
        /// you mention").
        let trait: String
        /// Lowercased words in a kept page that would confirm the wager. Kept
        /// honest: the receipt only fires when one genuinely appears.
        let receiptKeywords: [String]
        /// How the Book frames the kept page it found as proof of the wager.
        let receiptLead: String
    }

    static let confirmedTag = "first-wager"

    static let all: [Wager] = [
        Wager(
            id: "notices",
            guess: "You notice more than you let on. A slant of light, a face in a crowd, the exact wrong thing someone said — it stays with you after everyone else has walked past.",
            trait: "you notice more than you mention",
            receiptKeywords: ["light", "noticed", "saw", "small", "quiet", "corner", "window", "sky", "colour", "color", "smell", "sound", "the way"],
            receiptLead: "Here you are, noticing something almost no one would have stopped for"
        ),
        Wager(
            id: "keeper",
            guess: "You have been the one who remembers things for other people — the birthdays, the exact story, who takes their tea how. You keep more of everyone's life than they know.",
            trait: "you carry other people's small things",
            receiptKeywords: ["remember", "mother", "father", "mom", "dad", "mum", "friend", "daughter", "son", "kids", "sister", "brother", "her", "him", "them"],
            receiptLead: "Here you are, holding a piece of someone else's day for them"
        ),
        Wager(
            id: "tired-but-here",
            guess: "Some days you perform \u{201C}fine\u{201D} well enough that no one checks on you. I think I can already tell the difference between your fine and your okay.",
            trait: "you can carry a hard day quietly",
            receiptKeywords: ["tired", "exhausted", "fine", "okay", "hard", "enough", "again", "still", "long day", "too much"],
            receiptLead: "This looks like a day you carried without making anyone else carry it"
        ),
        Wager(
            id: "beauty-seeker",
            guess: "You go looking for small beauty on purpose — a good sky, a warm window, the right song — even on ordinary days. Maybe especially then.",
            trait: "you reach for beauty on purpose",
            receiptKeywords: ["beautiful", "pretty", "gold", "golden", "sunset", "flower", "garden", "rain", "snow", "moon", "star", "light", "song", "music"],
            receiptLead: "Here is one of the small beautiful things you went and found"
        ),
        Wager(
            id: "words-person",
            guess: "You think in words. Somewhere there are sentences, lists, or half-notes you have kept for years, whether or not anyone ever read them.",
            trait: "you have always kept words",
            receiptKeywords: ["wrote", "word", "words", "book", "read", "letter", "note", "page", "story", "said", "wrote down"],
            receiptLead: "This is your hand, keeping words the way I wagered you always have"
        ),
        Wager(
            id: "quiet-strength",
            guess: "You are steadier than you feel. People lean on you, and you let them, even on the days you would rather be the one leaning.",
            trait: "you are the steady one",
            receiptKeywords: ["help", "helped", "need", "needed", "tried", "managed", "made it", "got through", "kept going", "held"],
            receiptLead: "This is the steadiness I guessed at, showing up in one ordinary line"
        )
    ]

    static func wager(id: String) -> Wager? { all.first { $0.id == id } }

    static func questionID(for id: String) -> String { "onboarding-wager-\(id)" }

    static func wager(forQuestionID questionID: String) -> Wager? {
        let prefix = "onboarding-wager-"
        guard questionID.hasPrefix(prefix) else { return nil }
        return wager(id: String(questionID.dropFirst(prefix.count)))
    }

    /// A stable three for this install, so the reader always sees the same set
    /// and the payoff can reference exactly what it guessed.
    static func three(seed: String) -> [Wager] {
        guard all.count > 3 else { return all }
        let start = Int(abs(seed.stableHash) % all.count)
        return (0..<3).map { all[(start + $0) % all.count] }
    }
}

enum FirstReading {
    struct Reflection: Equatable {
        var pageCount: Int
        var dayCount: Int
        var fragments: [String]
        var threadWord: String?
        var threadCount: Int
    }

    /// Body and fuel logs stay out of the Book's commentary, matching
    /// `EditionCurator` and `KeepMarginalia`.
    static func reflectablePages(in inputs: BookSourceInputs, today: BookDay) -> [BookPage] {
        var days = inputs.days
        if let existing = days.firstIndex(where: { $0.id == today.id }) {
            days[existing] = today
        } else {
            days.append(today)
        }
        return reflectablePages(in: days)
    }

    /// The same privacy boundary over an already assembled Book. Keeping this
    /// overload here lets the app detect the exact Keep that wakes the First
    /// Reading without reimplementing its eligibility rules in SwiftUI.
    static func reflectablePages(in days: [BookDay]) -> [BookPage] {
        days
            .flatMap(\.capturedPages)
            .filter { !EditionCurator.defaultPrivateTypes.contains($0.type) }
    }

    /// Concrete words honest enough to name a thread around — things a reader
    /// would recognise as "a thing," never moods or filler.
    static let threadLexicon: [String] = [
        "rain", "snow", "fog", "mist", "wind", "sun", "moon", "cloud", "storm",
        "sky", "dusk", "dawn", "night", "star", "stars",
        "kitchen", "window", "door", "street", "garden", "porch", "room", "car",
        "road", "shore", "harbor", "water", "sea", "river",
        "cup", "mug", "book", "page", "lamp", "key", "candle", "photo", "letter",
        "coffee", "tea", "light", "shadow", "music", "song",
        "mother", "father", "dog", "cat", "friend", "home"
    ]

    static func reflection(for pages: [BookPage], now: Date = Date(), calendar: Calendar = .current) -> Reflection? {
        guard pages.count >= 3 else { return nil }
        let dayCount = Set(pages.map { BookDay.id(for: $0.createdAt, calendar: calendar) }).count
        let fragments = self.fragments(from: pages)
        guard fragments.count >= 2 else { return nil }
        let (word, count) = thread(in: pages)
        return Reflection(
            pageCount: pages.count,
            dayCount: max(1, dayCount),
            fragments: fragments,
            threadWord: word,
            threadCount: count
        )
    }

    /// Up to three ways to name the reader's kept pages back to them, most vivid
    /// first. Pages with real prose are quoted in the reader's own words;
    /// wordless logs are named by what they are.
    static func fragments(from pages: [BookPage]) -> [String] {
        let ranked = pages.sorted { a, b in
            let sa = StorySpark.score(text(of: a))
            let sb = StorySpark.score(text(of: b))
            if sa == sb { return a.createdAt > b.createdAt }
            return sa > sb
        }
        var seen: Set<String> = []
        var out: [String] = []
        for page in ranked {
            let fragment = self.fragment(for: page)
            let key = fragment.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(fragment)
            if out.count == 3 { break }
        }
        return out
    }

    private static func text(of page: BookPage) -> String {
        (page.userInput.nonEmpty ?? page.promptText).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fragment(for page: BookPage) -> String {
        let raw = text(of: page)
        let words = raw.split { !$0.isLetter && !$0.isNumber }
        if words.count >= 3 {
            let sentence = StorySpark.sentence(from: page)
                .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
            if !sentence.isEmpty {
                return "\u{201C}\(sentence)\u{201D}"
            }
        }
        return named(page)
    }

    private static func named(_ page: BookPage) -> String {
        switch page.type {
        case .mood: return "a page of how the day felt"
        case .weather: return "the weather you sealed"
        case .souvenir: return "a sentence you kept"
        case .diary: return "a note you left yourself"
        case .location: return "a place you marked"
        case .illuminatedPhoto, .illustration: return "an image you illuminated"
        default: return "a page you kept"
        }
    }

    /// The single most-shared concrete word, if one genuinely appears in two or
    /// more pages. Deterministic: ties break toward the lexicon's order.
    static func thread(in pages: [BookPage]) -> (word: String?, count: Int) {
        let wordSets: [Set<String>] = pages.map { page in
            Set(text(of: page).lowercased().split { !$0.isLetter }.map(String.init))
        }
        var best: String?
        var bestCount = 0
        for candidate in threadLexicon {
            let count = wordSets.reduce(0) { $0 + ($1.contains(candidate) ? 1 : 0) }
            if count >= 2 && count > bestCount {
                best = candidate
                bestCount = count
            }
        }
        return (best, bestCount)
    }

    static func body(for reflection: Reflection) -> String {
        compose(reflection, wagerReceipt: nil)
    }

    /// Overload used once real pages exist and a night-one wager can be paid
    /// off. Kept separate so the plain `body(for:)` reference in tests and
    /// callers keeps resolving.
    static func body(for reflection: Reflection, wagerReceipt: String?) -> String {
        compose(reflection, wagerReceipt: wagerReceipt)
    }

    private static func compose(_ reflection: Reflection, wagerReceipt: String?) -> String {
        var out = "I have read what you kept — \(countPhrase(reflection)). Not a life yet, but I read every word, and I was paying attention.\n\n"
        out += reflectionParagraph(reflection.fragments)
        if let word = reflection.threadWord {
            out += "\n\n\(threadSentence(word: word, count: reflection.threadCount))"
        }
        if let wagerReceipt {
            out += "\n\n\(wagerReceipt)"
        }
        out += "\n\nBooks should be careful with certainty, so I will not pretend to know you yet. But keep leaving pages, and the shapes will come — who keeps appearing, what you turn toward, what the quiet is about. For now I am only reading, and glad to be."
        return out
    }

    /// Turns a confirmed night-one wager into a receipt when a kept page bears
    /// it out. Prefers a real match (the reader's own words as proof); falls
    /// back to an honest "still watching" callback so a confirmed wager is
    /// never silently dropped.
    static func wagerReceipt(selfFacts: [SelfFact], pages: [BookPage]) -> String? {
        let confirmed = selfFacts
            .filter { $0.tags.contains(FirstWagers.confirmedTag) }
            .compactMap { FirstWagers.wager(forQuestionID: $0.questionID) }
        guard !confirmed.isEmpty else { return nil }

        for wager in confirmed {
            for page in pages {
                let haystack = text(of: page).lowercased()
                guard wager.receiptKeywords.contains(where: { haystack.contains($0) }) else { continue }
                return "On your very first night, before I had read a page of you, I made a wager: \(wager.guess) I no longer have to guess. \(wager.receiptLead) — \(fragment(for: page))."
            }
        }

        let wager = confirmed[0]
        return "On your first night I wagered one thing about you before I had read anything: that \(wager.trait). I have not forgotten the bet. I am still watching to see if I was right."
    }

    private static func countPhrase(_ r: Reflection) -> String {
        let pageWord = spelled(r.pageCount)
        let pages = r.pageCount == 1 ? "page" : "pages"
        if r.dayCount <= 1 {
            return "\(pageWord) \(pages), all in one sitting"
        }
        return "\(pageWord) \(pages), across \(spelled(r.dayCount)) days"
    }

    private static func reflectionParagraph(_ fragments: [String]) -> String {
        switch fragments.count {
        case ...1:
            return "You kept \(fragments.first ?? "a page")."
        case 2:
            return "You kept \(fragments[0]). And \(fragments[1])."
        default:
            return "You kept \(fragments[0]). Then \(fragments[1]). And \(fragments[2]) — the one I keep returning to."
        }
    }

    private static func threadSentence(word: String, count: Int) -> String {
        let lead = count >= 3 ? "\(spelled(count)) times now" : "twice now"
        let capped = lead.prefix(1).uppercased() + lead.dropFirst()
        return "\(capped), something about \(word). It may be nothing — I have only noted it in pencil."
    }

    private static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        return (0...12).contains(n) ? words[n] : "\(n)"
    }
}

// MARK: - The Book Asks

/// A reader is most believed when they ask a question only a reader could ask.
/// The Book's way in is the reader's own hedge words — *again, still, finally,
/// almost* — each one a door to a page that was never written: an "again"
/// means there was a first time, a "finally" means there was a wait. The Book
/// quotes the exact sentence back and asks about the untold part. One question
/// a week at most, never on a hard day, never the same page twice.
enum BookAsks {
    struct Question: Equatable {
        var sourcePageID: String
        var hedgeWord: String
        var sentence: String
    }

    /// Each hedge implies its own kind of untold page; the probe line is the
    /// Book wondering about exactly that. Order is narrative priority when a
    /// sentence carries more than one.
    static let hedges: [(word: String, probe: String)] = [
        ("again", "An \u{201C}again\u{201D} means there was a first time, and the first time is not in any page I hold. What was it like?"),
        ("still", "A \u{201C}still\u{201D} has been carrying something for a while now. How long, would you say?"),
        ("anymore", "An \u{201C}anymore\u{201D} marks the place where something stopped. When did it stop?"),
        ("finally", "A \u{201C}finally\u{201D} is the last page of a chapter I never got to read. What was the waiting made of?"),
        ("almost", "An \u{201C}almost\u{201D} is a door that did not quite open. What stopped it?"),
        ("this time", "A \u{201C}this time\u{201D} admits there were other times. I have been quietly wondering about those."),
        ("as usual", "An \u{201C}as usual\u{201D} — I missed the becoming. When did this turn usual?"),
        ("for once", "A \u{201C}for once\u{201D} makes me wonder what it is like the rest of the time.")
    ]

    /// The freshest question the recent archive offers: the most recent
    /// user-authored prose page (last seven days) whose sentence carries a
    /// hedge, skipping pages the Book has already asked about.
    static func question(
        in days: [BookDay],
        askedSourcePageIDs: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Question? {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let candidates = days
            .flatMap(\.capturedPages)
            .filter { page in
                page.origin == .userAuthored
                    && page.createdAt >= cutoff
                    && page.createdAt <= now
                    && !EditionCurator.defaultPrivateTypes.contains(page.type)
                    && !page.tags.contains("book-asks")
                    && !askedSourcePageIDs.contains(page.id)
            }
            .sorted { $0.createdAt > $1.createdAt }

        for page in candidates {
            let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.split(separator: " ").count >= 5 else { continue }
            for sentence in sentences(in: text) {
                for hedge in hedges where containsWholeWord(hedge.word, in: sentence) {
                    return Question(
                        sourcePageID: page.id,
                        hedgeWord: hedge.word,
                        sentence: clipped(sentence)
                    )
                }
            }
        }
        return nil
    }

    static func body(for question: Question) -> String {
        let probe = hedges.first { $0.word == question.hedgeWord }?.probe
            ?? "The Book has been wondering about the part you did not write down."
        return """
        You wrote:

        \u{201C}\(question.sentence)\u{201D}

        I keep snagging on that \u{201C}\(question.hedgeWord).\u{201D} Small words carry the biggest freight. \(probe)

        If you want to answer, write it here and keep the page — I will put it beside the one that asked. If not, let it wait. Pencil questions do not rust.
        """
    }

    static func sentences(in text: String) -> [String] {
        text.split(omittingEmptySubsequences: true) { ".!?\n".contains($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func containsWholeWord(_ word: String, in sentence: String) -> Bool {
        sentence.lowercased()
            .range(of: "\\b\(word)\\b", options: .regularExpression) != nil
    }

    /// The quoted sentence never becomes a wall of text on the notice.
    static func clipped(_ sentence: String, limit: Int = 110) -> String {
        guard sentence.count > limit else { return sentence }
        let cut = sentence.prefix(limit)
        let lastSpace = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<lastSpace]) + "\u{2026}"
    }

    /// Source pages already asked about, recovered from kept question pages'
    /// tags — no vault flag, the archive itself remembers.
    static func askedSourcePageIDs(in days: [BookDay]) -> Set<String> {
        Set(
            days.flatMap(\.pages)
                .flatMap(\.tags)
                .compactMap { tag in
                    tag.hasPrefix("book-asks-src-") ? String(tag.dropFirst("book-asks-src-".count)) : nil
                }
        )
    }

    /// The weekly governor: a kept question inside the window means the Book
    /// already used its one ask.
    static func askedRecently(in days: [BookDay], now: Date = Date()) -> Bool {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        return days.flatMap(\.pages).contains { page in
            page.tags.contains("book-asks") && page.createdAt >= cutoff
        }
    }
}

/// Surfaces `BookAsks` as a `.bookNotices` page: one pointed question grounded
/// in the reader's exact sentence. Starts only after the First Reading window
/// has passed (eight or more kept pages), at most one a week, suppressed on
/// hard days, and never about the same source page twice.
struct BookAsksPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let readable = FirstReading.reflectablePages(in: inputs, today: day)
        guard readable.count >= 8 else { return [] }
        guard !context.distress.isActive else { return [] }
        guard !BookAsks.askedRecently(in: allDays, now: now) else { return [] }
        guard let question = BookAsks.question(
            in: allDays,
            askedSourcePageIDs: BookAsks.askedSourcePageIDs(in: allDays),
            now: now
        ) else { return [] }

        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        return [
            SurfacePage(
                id: "\(source.id)-book-asks-\(question.sourcePageID)-\(slot)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                // Below the once-ever milestones (First Reading 80, wager 72,
                // naming 70): a question is an invitation, not an event, and it
                // can wait for a calm desk without losing anything.
                score: 68,
                reason: "The Book found a small word in your pages it cannot stop wondering about.",
                prompt: "The Book has a question.",
                detail: "\u{201C}\(question.sentence)\u{201D}",
                payload: BookPagePayload(
                    headline: "The Book Asks",
                    body: BookAsks.body(for: question),
                    metadata: [
                        "source": source.id,
                        "bookAsks": "true",
                        "bookAsksWord": question.hedgeWord,
                        "bookAsksSourcePageID": question.sourcePageID,
                        "tags": "book-asks,book-asks-src-\(question.sourcePageID),book-notices,local-memory"
                    ]
                )
            )
        ]
    }
}

/// Surfaces `FirstReading` as an early, honest `.bookNotices` page. It fires in
/// the narrow window before the pattern-noticing gate opens, exactly once (the
/// reader's kept copy carries a `first-reading` tag that suppresses it forever),
/// and scores modestly so a genuine pattern notice outranks it once one exists.
struct FirstReadingPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let pages = FirstReading.reflectablePages(in: inputs, today: day)
        // Early window only: enough kept pages to reflect, but not yet deep
        // enough for the pattern-noticing in Book Notices to carry the weight.
        guard (3...7).contains(pages.count) else { return [] }
        // A milestone: once the reader keeps this reading, it never returns.
        let alreadyKept = (inputs.days + [day])
            .flatMap(\.pages)
            .contains { $0.tags.contains("first-reading") }
        guard !alreadyKept else { return [] }
        // On a hard day the Book goes quiet and leads with care. This milestone
        // is once-ever and self-suppressing, so it simply waits for a calmer
        // session rather than crowding out gentleness.
        guard !context.distress.isActive else { return [] }
        guard let reflection = FirstReading.reflection(for: pages, now: now) else { return [] }

        let wagerReceipt = FirstReading.wagerReceipt(selfFacts: inputs.selfFacts, pages: pages)
        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        return [
            SurfacePage(
                id: "\(source.id)-first-reading-\(slot)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                // A priority reflective milestone — scored a step above the
                // Book's other must-see reflective moments (constellation
                // naming 70, sealed wager 72) because this is the reader's first
                // proof of being read, but deliberately below orientation and
                // the distress/rest overrides (88–96) so a busy or hard desk
                // still leads with care. Hard days are handled by the distress
                // guard above; it is re-offered on calm sessions until kept.
                score: 80,
                reason: "The Book read all the pages you kept, every one.",
                prompt: "The Book has been reading you.",
                detail: reflection.fragments.first ?? "The Book read what you kept.",
                payload: BookPagePayload(
                    headline: "The Book Reads Back",
                    body: FirstReading.body(for: reflection, wagerReceipt: wagerReceipt),
                    metadata: [
                        "source": source.id,
                        "firstReading": "true",
                        "milestone": "true",
                        "wagerReceipt": wagerReceipt == nil ? "false" : "true",
                        "reflectedPageCount": "\(reflection.pageCount)",
                        "tags": "first-reading,book-notices,proof-of-reading,local-memory"
                    ]
                )
            )
        ]
    }
}

/// Deterministic pool pick shared by the reflective surfaces: the same seed
/// and salt always choose the same line, so a given page rereads identically
/// while its siblings differ. Repetition of scaffolding prose is the fastest
/// way for reflection to start reading as template.
enum ReflectiveProse {
    static func pick(_ options: [String], seed: UInt64, salt: UInt64) -> String {
        options[Int((seed &+ salt &* 7_919) % UInt64(options.count))]
    }
}

struct BookNoticesPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        var pages: [SurfacePage] = []
        // Relationship play does not require a mature archive. Once the reader
        // has deliberately opened a person thread, the Book can offer one
        // fitting door into ordinary life. Distress and witness-only remain
        // hard stops.
        if !context.distress.isActive {
            let contextQuestions = personContextQuestionSurfaces(for: day, inputs: inputs, now: now)
            pages += contextQuestions
            if contextQuestions.isEmpty {
                pages += personPlaySurfaces(for: day, inputs: inputs, now: now)
            }
        }
        // Patterns, namings, and wagers only mean something once the library has
        // enough kept pages to find a pattern in.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return pages }
        pages += namingSurfaces(for: day, inputs: inputs, now: now)
        pages += wagerSurfaces(for: day, inputs: inputs, now: now)
        pages += watchedThreadSurfaces(for: day, inputs: inputs, now: now)
        pages += learningSurfaces(for: day, inputs: inputs, now: now)
        pages += howYouSeeSurfaces(for: day, inputs: inputs, now: now)
        // The People of the Book speak only on a gentle desk: suggestions and
        // absence observations both stay silent under distress.
        if !context.distress.isActive {
            pages += personSuggestionSurfaces(for: day, inputs: inputs, now: now)
            pages += personQuietSurfaces(for: day, inputs: inputs, now: now)
        }
        pages += OvernightConnectionReview.surfaces(for: day, inputs: inputs, now: now)
        pages += relationalLoomSurfaces(for: day, inputs: inputs, now: now)
        pages += sensoryLoomSurfaces(for: day, inputs: inputs, now: now)
        pages += connectionNarrativeSurfaces(for: day, inputs: inputs, now: now)
        pages += contextWeaveSurfaces(for: day, inputs: inputs, now: now)
        pages += noticeSurfaces(for: day, inputs: inputs, now: now)
        return pages
    }

    /// The general many-to-many reading. Unlike the older specialized paths,
    /// this does not know about "Wicker plus rain" or "Slice of Life after
    /// dark." It asks the same contrast-tested question of every trustworthy
    /// pair of dimensions and lets the evidence decide what deserves speech.
    private func relationalLoomSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = Self.spokenConnectionIDs(days: allDays)
        let connections = RelationalLoom.connections(
            days: allDays,
            readerLearning: inputs.readerLearning,
            facultyEntries: inputs.facultyEntries,
            people: inputs.people,
            continuity: inputs.continuity
        )
        let constellations = RelationalLoom.constellations(connections: connections)
        if let constellation = constellations.first(where: { !spoken.contains($0.id) }) {
            let cards = constellation.evidence.map { evidence in
                let symbol = constellation.branches.first(where: { $0.evidence.contains(evidence) })?
                    .outcome.symbolName ?? "point.3.connected.trianglepath.dotted"
                return NoticePatternCard(
                    title: "\(Self.connectionDateFormatter.string(from: evidence.occurredAt)) · \(evidence.title)",
                    text: evidence.text,
                    symbol: symbol
                )
            }
            let outcomeLabels = constellation.branches.map { $0.outcome.label }
            let spokeTags = ([constellation.id] + constellation.branches.map(\.id))
                .map { "\(Self.connectionSpokeTagPrefix)\($0)" }
                .joined(separator: ",")
            let body = """
            I found more than a pair this time.

            \(constellation.line)

            I did not make one grand tensor and ask it for a mood. Each branch had to survive its own real comparison elsewhere in the archive. Only then did I lay the branches together: \(outcomeLabels.joined(separator: ", ")). The cards below are the Pages that let me say it.

            This may still be a glimmer. It is inspectable, local, and correctable. If this constellation joins things that should remain separate, tell me; I will bar this exact reading without forgetting the Pages themselves.
            """
            return [SurfacePage(
                id: "\(source.id)-relational-constellation-\(constellation.id)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: min(98, constellation.evidenceTier.surfaceScoreBase + 6 + constellation.strength / 12),
                reason: "Several independently tested branches met around the same condition.",
                prompt: "Several distant corners of the Book touched at once.",
                detail: constellation.line.bookPreviewSentenceLimit(1),
                payload: BookPagePayload(
                    headline: constellation.headline,
                    body: body,
                    metadata: [
                        "source": source.id,
                        "connectionNarrative": "true",
                        "connectionKind": "relational-constellation",
                        "connectionID": constellation.id,
                        "observationKey": constellation.observationKey,
                        "relationalCondition": constellation.condition.label,
                        "relationalOutcomes": outcomeLabels.joined(separator: ", "),
                        "relationalBranchCount": "\(constellation.branches.count)",
                        "relationalEvidenceTier": constellation.evidenceTier.rawValue,
                        "magicMomentEligible": "true",
                        "evidencePageIDs": constellation.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                        "feedbackPrompt": "Do these parts of your Book truly meet here?",
                        "tags": "book-notices,relational-loom,cross-media,constellation-reading,connection-narrative,\(spokeTags),local-memory"
                    ]
                )
            )]
        }
        guard let connection = connections.first(where: { !spoken.contains($0.id) }) else { return [] }

        let cards = connection.evidence.map { evidence in
            NoticePatternCard(
                title: "\(Self.connectionDateFormatter.string(from: evidence.occurredAt)) · \(evidence.title)",
                text: evidence.text,
                symbol: connection.outcome.symbolName
            )
        }
        let body = """
        I have stopped keeping weather in one drawer, photographs in another, choices in a third, and characters in the cupboard marked Fiction. I laid every trustworthy little receipt where it could meet every other one. Most of them had nothing to say.

        \(connection.line)

        This relationship was not programmed as a rule. The same Loom compares subjects, meanings, Pages, choices, people you confirmed, characters, hours, weather, places, voice cadence, photographic form, and reader-named inner weather. It spoke because this pair held across more than one day and had a real elsewhere to compare itself with.

        A pattern is not a cause and it is not a verdict about you. It is two corners of your Book touching. If they do not belong together, tell me; I will stop reading them that way.
        """
        return [SurfacePage(
            id: "\(source.id)-relational-\(connection.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(96, connection.evidenceTier.surfaceScoreBase + connection.strength / 12),
            reason: "Two different parts of the reader's Book kept choosing each other across a real contrast group.",
            prompt: "Two distant corners of the Book touched.",
            detail: connection.line.bookPreviewSentenceLimit(1),
            payload: BookPagePayload(
                headline: connection.headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "relational",
                    "connectionID": connection.id,
                    "observationKey": connection.observationKey,
                    "relationalCondition": connection.condition.label,
                    "relationalOutcome": connection.outcome.label,
                    "relationalInHits": "\(connection.inHits)",
                    "relationalInCount": "\(connection.inCount)",
                    "relationalOutHits": "\(connection.outHits)",
                    "relationalOutCount": "\(connection.outCount)",
                    "relationalEvidenceTier": connection.evidenceTier.rawValue,
                    "magicMomentEligible": "true",
                    "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "feedbackPrompt": "Do these two parts of your Book belong together?",
                    "tags": "book-notices,relational-loom,many-to-many,connection-narrative,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                ]
            )
        )]
    }

    /// The first Sensory Loom ceremony. A local image-language vector found
    /// prose on other days that gathered closer to one photograph than the
    /// rest of the archive did. The vector discovers; these source Pages are
    /// the receipt, and the reader still decides whether the kinship is real.
    private func sensoryLoomSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = Self.spokenConnectionIDs(days: allDays)
        guard let connection = SensoryLoom.connections(pages: allDays.flatMap(\.capturedPages))
            .first(where: { !spoken.contains($0.id) }) else { return [] }

        let pagesByID = Dictionary(
            allDays.flatMap(\.capturedPages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        let evidence = connection.evidencePageIDs.compactMap { pagesByID[$0] }
        guard evidence.count >= SensoryLoom.minimumEvidencePages else { return [] }
        let photographIDs = Set(connection.photographPageIDs)
        let cards = evidence.prefix(4).map { page in
            let isPhotograph = photographIDs.contains(page.id)
            return NoticePatternCard(
                title: "\(Self.connectionDateFormatter.string(from: page.createdAt)) · \(isPhotograph ? "Photograph" : "Ink")",
                text: Self.connectionExcerpt(from: page),
                symbol: isPhotograph ? "photo" : "text.quote"
            )
        }
        let contextSentence = connection.sharedContextTokens.first.map {
            "There was another small agreement around them too: \($0.replacingOccurrences(of: "-", with: " "))."
        } ?? ""
        let body = """
        I tried something new with these Pages. I let the photograph keep its shapes and the prose keep its words, then asked whether either recognized the other.

        \(connection.line)

        \(contextSentence)

        This is not a label I brought with me. It is a possible private symbol forming between your own Pages. I have put the evidence on the desk because resemblance is not truth until its reader recognizes it.
        """
        return [SurfacePage(
            id: "\(source.id)-sensory-\(connection.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(94, 82 + connection.strength / 10),
            reason: "A photograph and several Pages of reader-authored prose recognized the same private shape.",
            prompt: "The Book's senses crossed.",
            detail: connection.line.bookPreviewSentenceLimit(1),
            payload: BookPagePayload(
                headline: "The Image and the Ink",
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "sensory",
                    "connectionID": connection.id,
                    "sensoryMotifID": connection.motifID,
                    "sensoryMotifName": connection.motifName,
                    "sensoryPairingKind": "image-ink",
                    "sensoryMeanSimilarity": String(format: "%.3f", connection.meanSimilarity),
                    "sensoryContrastGap": String(format: "%.3f", connection.contrastGap),
                    // Evidence tiers may grow as more Pages arrive, but a hard
                    // boundary belongs to the stable sense-pair + motif. "Do
                    // not read me this way" must not return wearing new IDs.
                    "observationKey": "sensory-pairing:image-ink:\(connection.motifID)",
                    "magicMomentEligible": "true",
                    "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "feedbackPrompt": "Do the image and the ink belong to the same thread?",
                    "tags": "book-notices,sensory-loom,cross-media,connection-narrative,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                ]
            )
        )]
    }

    /// The general relationship finder speaking: a writing habit that keeps
    /// choosing one real-world condition — heavier ink in the rain, questions
    /// after dark, a subject that only visits on weekends. Every claim is
    /// two-sided and counted before it is spoken, and each connection speaks
    /// once per evidence tier, remembered through the same spoke tags the
    /// narrative connections use.
    private func contextWeaveSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = Self.spokenConnectionIDs(days: allDays)
        let connections = ContextWeave.connections(days: allDays)
        guard let connection = connections.first(where: { !spoken.contains($0.id) }) else { return [] }

        let pagesByID = Dictionary(
            allDays.flatMap(\.capturedPages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        let evidence = connection.evidencePageIDs.compactMap { pagesByID[$0] }
        let cards = evidence.map { page in
            NoticePatternCard(
                title: Self.connectionDateFormatter.string(from: page.createdAt),
                text: Self.connectionExcerpt(from: page),
                symbol: "cloud.sun"
            )
        }
        let body = """
        I have started laying pages side by side by what the world was doing when you kept them — the sky, the hour, how crowded the day was. Mostly the pages shrug. This time they did not.

        \(connection.line)

        \(connection.kind == .subject
            ? "Once is a visit. This many times, always through the same door, is a habit of your attention."
            : "The counts are small and I hold them loosely. But the lean is real enough that I wanted to show you rather than keep it.")

        I am not diagnosing you. I only notice which doors your sentences prefer in which weather. If I have read this wrong, say so — I keep those lessons.
        """
        return [SurfacePage(
            id: "\(source.id)-context-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(86, 74 + connection.strength / 8),
            reason: "A writing habit and a real-world condition kept choosing each other across the archive.",
            prompt: "The Book found a connection in your pages.",
            detail: connection.line.bookPreviewSentenceLimit(1),
            payload: BookPagePayload(
                headline: connection.headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "context",
                    "connectionID": connection.id,
                    "connectionFacet": connection.facetID,
                    "observationKey": "connection:\(connection.id)",
                    "magicMomentEligible": "true",
                    "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "feedbackPrompt": "Do these pages and this part of the day belong together?",
                    "tags": "book-notices,connection-narrative,context-connection,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                ]
            )
        )]
    }

    /// A high-evidence notice that reads several actual kept pages as one
    /// developing thread. This sits beside the ordinary continuity notice: it
    /// does not replace the wider pattern ledger, and it stays silent unless
    /// the archive can put the source pages themselves on the table.
    private func connectionNarrativeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let pagesByID = Dictionary(
            allDays.flatMap(\.capturedPages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        let spoken = Self.spokenConnectionIDs(days: allDays)

        if let pairing = inputs.semanticNoticePairing,
           let older = pagesByID[pairing.sourcePageID],
           let newer = pagesByID[pairing.anchorPageID],
           Self.isNarrativeConnectionEvidence(older),
           Self.isNarrativeConnectionEvidence(newer) {
            let connectionID = "semantic-\(older.id)-\(newer.id)"
            if !spoken.contains(connectionID) {
                return [Self.semanticConnectionSurface(
                    source: source,
                    day: day,
                    older: older,
                    newer: newer,
                    pairing: pairing,
                    connectionID: connectionID,
                    now: now
                )]
            }
        }

        for connection in ContextWeave.connections(days: allDays) {
            guard !spoken.contains(connection.id) else { continue }
            let evidence = connection.evidencePageIDs.compactMap { pagesByID[$0] }
            guard evidence.count >= 2 else { continue }
            let cards = evidence.map { page in
                NoticePatternCard(
                    title: Self.connectionDateFormatter.string(from: page.createdAt),
                    text: Self.connectionExcerpt(from: page),
                    symbol: connection.kind == .manner ? "text.line.first.and.arrowtriangle.forward" : "bookmark"
                )
            }
            let body = """
            I found a relationship between the conditions around these pages and the way the ink arrived.

            \(connection.line)

            I am showing the source pages because I am noticing, not diagnosing. If the comparison is wrong, say so; a careful Book must be correctable.
            """
            return [SurfacePage(
                id: "\(source.id)-\(connection.id)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 90,
                reason: "Several kept pages changed together with their recorded real-world context.",
                prompt: "The Book noticed the world leaning on the ink.",
                detail: connection.line,
                payload: BookPagePayload(
                    headline: "The Weather Around the Words",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "connectionNarrative": "true",
                        "connectionKind": "context",
                        "connectionID": connection.id,
                        "observationKey": "connection:\(connection.id)",
                        "magicMomentEligible": "true",
                        "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                        "feedbackPrompt": "Did the Book read this right?",
                        "tags": "book-notices,connection-narrative,context-connection,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                    ]
                )
            )]
        }

        for signal in inputs.continuity.strongestSignals where signal.kind == .pattern && signal.strength >= 62 {
            let evidence = signal.evidencePageIDs
                .compactMap { pagesByID[$0] }
                .filter(Self.isNarrativeConnectionEvidence)
                .sorted { left, right in
                    if left.createdAt == right.createdAt { return left.id < right.id }
                    return left.createdAt < right.createdAt
                }
            let distinctDays = Set(evidence.map { BookDay.id(for: $0.createdAt) })
            guard evidence.count >= 3,
                  distinctDays.count >= 3,
                  let first = evidence.first,
                  let last = evidence.last,
                  last.createdAt.timeIntervalSince(first.createdAt) >= 6 * 86_400 else { continue }

            let middle = evidence[evidence.count / 2]
            let selected = [first, middle, last]
            let connectionID = "signal-\(signal.id)-\(selected.map(\.id).joined(separator: "-"))"
            guard !spoken.contains(connectionID) else { continue }
            return [Self.recurringConnectionSurface(
                source: source,
                day: day,
                signal: signal,
                pages: selected,
                connectionID: connectionID,
                now: now
            )]
        }
        return []
    }

    private static let connectionSpokeTagPrefix = "connection-spoke:"

    private static func spokenConnectionIDs(days: [BookDay]) -> Set<String> {
        Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            guard tag.hasPrefix(connectionSpokeTagPrefix) else { return nil }
            return String(tag.dropFirst(connectionSpokeTagPrefix.count))
        })
    }

    private static func isNarrativeConnectionEvidence(_ page: BookPage) -> Bool {
        page.origin == .userAuthored
            && !EditionCurator.defaultPrivateTypes.contains(page.type)
            && page.userInput.split { !$0.isLetter && !$0.isNumber }.count >= 5
    }

    private static func semanticConnectionSurface(
        source: BookPageSource,
        day: BookDay,
        older: BookPage,
        newer: BookPage,
        pairing: SemanticNoticePairing,
        connectionID: String,
        now: Date
    ) -> SurfacePage {
        let olderDate = connectionDateFormatter.string(from: older.createdAt)
        let newerDate = connectionDateFormatter.string(from: newer.createdAt)
        let body = """
        I found two pages in different parts of the archive. They do not borrow each other's important words.

        On \(olderDate), you kept:

        \u{201C}\(pairing.sourceExcerpt)\u{201D}

        On \(newerDate), you kept:

        \u{201C}\(pairing.anchorExcerpt)\u{201D}

        The newer page does not repeat the older one. Still, each changes how the other reads. Put together, they make a small before-and-after without telling me which one is the before.

        Whatever joins them lives below vocabulary. I will not name the feeling on your behalf; that would flatten it. I have only left their corners touching, because the pages seemed less alone that way.
        """
        let cards = [
            NoticePatternCard(title: olderDate, text: pairing.sourceExcerpt, symbol: "book.closed"),
            NoticePatternCard(title: newerDate, text: pairing.anchorExcerpt, symbol: "book.pages")
        ]
        return SurfacePage(
            id: "\(source.id)-thread-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 88,
            reason: "Two kept pages far apart changed meaning when the Book set them side by side.",
            prompt: "Two of your kept pages found each other.",
            detail: "\u{201C}\(pairing.sourceExcerpt)\u{201D} / \u{201C}\(pairing.anchorExcerpt)\u{201D}",
            payload: BookPagePayload(
                headline: "The Thread Between",
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "semantic",
                    "connectionID": connectionID,
                    "observationKey": "connection:\(connectionID)",
                    "magicMomentEligible": "true",
                    "evidencePageIDs": "\(older.id),\(newer.id)",
                    "tinyPatternCards": encodeNoticePatternCards(cards),
                    "feedbackPrompt": "Do these two pages belong together?",
                    "tags": "book-notices,connection-narrative,semantic-connection,\(connectionSpokeTagPrefix)\(connectionID),local-memory"
                ]
            )
        )
    }

    private static func recurringConnectionSurface(
        source: BookPageSource,
        day: BookDay,
        signal: LiteraryContinuitySignal,
        pages: [BookPage],
        connectionID: String,
        now: Date
    ) -> SurfacePage {
        let dates = pages.map { connectionDateFormatter.string(from: $0.createdAt) }
        let excerpts = pages.map { connectionExcerpt(from: $0) }
        let subject = signal.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = """
        I pulled three pages because \(subject.lowercased()) was holding all of them by one corner.

        On \(dates[0]), in a \(pages[0].type.title.lowercased()) page, you kept:

        \u{201C}\(excerpts[0])\u{201D}

        Then on \(dates[1]):

        \u{201C}\(excerpts[1])\u{201D}

        Most recently, on \(dates[2]):

        \u{201C}\(excerpts[2])\u{201D}

        The first page might have been chance. The second made a rhyme. The third made the earlier two turn their faces toward it. That is the connection I notice: not the same sentence three times, but your attention choosing the same door on three different days.

        I do not yet know what \(subject.lowercased()) means in your book. I know it keeps accepting different pieces of your life without going blank. So I have put these pages together. Their corners seemed relieved.
        """
        let cards = zip(dates, excerpts).map { date, excerpt in
            NoticePatternCard(title: date, text: excerpt, symbol: "bookmark")
        }
        return SurfacePage(
            id: "\(source.id)-thread-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(87, 78 + signal.strength / 10),
            reason: "Three reader-authored pages have begun behaving like one continuing thread.",
            prompt: "Three of your kept pages found each other.",
            detail: "\(subject) returned across \(dates.joined(separator: ", ")).",
            payload: BookPagePayload(
                headline: "The Thread Between",
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "recurrence",
                    "connectionID": connectionID,
                    "observationKey": "connection:\(connectionID)",
                    "magicMomentEligible": "true",
                    "connectionSubject": subject,
                    "continuitySignals": signal.promptLine,
                    "evidencePageIDs": pages.map(\.id).joined(separator: ","),
                    "tinyPatternCards": encodeNoticePatternCards(cards),
                    "feedbackPrompt": "Is this a real thread in your life, or only a rhyme?",
                    "tags": "book-notices,connection-narrative,spoke:\(signal.id),\(connectionSpokeTagPrefix)\(connectionID),local-memory"
                ]
            )
        )
    }

    private static func connectionExcerpt(from page: BookPage) -> String {
        BookAsks.clipped(page.userInput.bookPreviewSentenceLimit(1), limit: 150)
    }

    private static let connectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    /// Findings are allowed to become an opinion only after the reader has
    /// supplied repeat evidence on separate days. The Page asks for
    /// confirmation; it never turns a practice history into a diagnosis.
    private func howYouSeeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        guard !Self.spokenSignalIDs(days: allDays, within: 90, now: now).contains("how-you-see"),
              let receipt = HowYouSee.receipt(days: allDays, now: now) else { return [] }
        let body = """
        I am careful with certainty. But this I can show you, in your own hand.

        In \(receipt.earlierMonthName) you kept: "\(receipt.earlierQuote)"

        This week you kept: "\(receipt.recentQuote)"

        The second one has weather in it, and weight, and something moving. The world did not get better written. You started reading it closer. I only keep the pages — the seeing is yours.
        """
        let cards = [
            NoticePatternCard(title: "Then", text: "\(receipt.earlierMonthName): \(receipt.earlierQuote)", symbol: "text.quote"),
            NoticePatternCard(title: "Now", text: receipt.recentQuote, symbol: "sparkles")
        ]
        return [SurfacePage(
            id: "\(source.id)-how-you-see-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 86,
            reason: "The Book found proof that the reader's own seeing has changed.",
            prompt: "The Book shows you your own eyes changing.",
            detail: receipt.recentQuote,
            payload: BookPagePayload(
                headline: "How You See",
                body: body,
                metadata: [
                    "source": source.id,
                    "howYouSee": "true",
                    "observationKey": "how-you-see",
                    "magicMomentEligible": "true",
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "feedbackPrompt": "Does this change in how you see feel true?",
                    "tags": "book-notices,how-you-see,spoke:how-you-see,local-memory"
                ]
            )
        )]
    }

    private func learningSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didLearnToday(day) else { return [] }
        let metrics = inputs.readerLearning.metrics(days: inputs.days + [day], now: now)
        let momentum = inputs.readerLearning.momentumMetrics()
        guard metrics.meaningfulEventCount >= 4 else { return [] }
        let insights = inputs.readerLearning.insights(now: now, limit: 4)
        guard !insights.isEmpty else { return [] }
        let summary = inputs.readerLearning.shortSummary(now: now)
        let body = Self.learningBody(insights: insights, metrics: metrics, summary: summary)
        let evidence = insights.map { "- \($0.line) \($0.evidence)" }.joined(separator: "\n")
        let patternCards = Self.learningPatternCards(insights: insights, metrics: metrics)
        let score = min(74, 46 + min(16, metrics.meaningfulEventCount / 2) + insights.count * 3)
        return [
            SurfacePage(
                id: "\(source.id)-book-learns-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: "The Book figured out a few things about how pages find you, and wants to show you.",
                prompt: "The Book shows off what it learned.",
                detail: insights.prefix(2).map(\.line).joined(separator: " "),
                payload: BookPagePayload(
                    headline: "The Book Learns",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "bookLearning": "true",
                        "learningMetrics": "tenureDays:\(metrics.tenureDays),events:\(metrics.eventCount),positiveRate:\(metrics.positiveRatePercent)",
                        "momentumMetrics": "opened:\(momentum.opened),acted:\(momentum.acted),within30s:\(momentum.actionsWithinThirtySeconds),openToActionRate:\(momentum.openToActionRatePercent),recognized:\(momentum.recognized),followedThreads:\(momentum.followedThreads),keepsakes:\(momentum.keepsakesEarned),medianSeconds:\(momentum.medianOpenToActionSeconds.map { String(format: "%.1f", $0) } ?? "none")",
                        "learningInsights": evidence,
                        "learningSummary": summary ?? "",
                        "tinyPatternCards": Self.encodeNoticePatternCards(patternCards),
                        "adaptiveActions": Self.adaptiveActions(forLearningInsights: insights).joined(separator: "\n"),
                        "feedbackPrompt": "Did the Book read this right?",
                        "tags": "book-learning,reader-learning,book-notices,local-memory"
                    ]
                )
            )
        ]
    }

    // MARK: The People of the Book (Witness Law surfaces)
    //
    // Confirm-on-suggest, quiet, and return — the only places the Book speaks
    // about real people. Everything here quotes the reader's own hand and
    // asks; nothing here (or anywhere) writes words for a real person.

    private func personContextQuestionSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let resting = Self.spokenSignalIDs(days: allDays, within: 45, now: now)
        let hypotheses = inputs.people.threads
            .filter { !$0.resting }
            .flatMap { PeopleOfTheBook.relationshipHypotheses(for: $0, days: allDays) }
            .filter { !resting.contains($0.id) }
            .sorted { $0.id < $1.id }
        guard let hypothesis = hypotheses.first else { return [] }
        let slug = PeopleOfTheBook.slug(for: hypothesis.personName)
        let body = """
        I think I may have learned something about how \(hypothesis.personName) lives in your life — but people are not facts I am allowed to smuggle past you.

        In your own hand:
        “\(hypothesis.evidenceQuote)”

        \(hypothesis.question) If I read this wrong, teach me differently. Until then it remains a question, not part of their chapter.
        """
        return [
            SurfacePage(
                id: "\(source.id)-\(hypothesis.id)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 66,
                reason: "The Book found an explicit relationship clue in the reader's own words and is asking before believing it.",
                prompt: "May I remember this about \(hypothesis.personName)?",
                detail: hypothesis.question,
                payload: BookPagePayload(
                    headline: "A Question About a Thread",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "personName": hypothesis.personName,
                        "personSlug": slug,
                        "personContextHypothesisID": hypothesis.id,
                        "personContextKind": hypothesis.kind.rawValue,
                        "personContextValue": hypothesis.value,
                        "personContextDisplayValue": hypothesis.displayValue,
                        "evidencePageIDs": hypothesis.evidencePageIDs.joined(separator: ","),
                        "adaptiveActions": ["confirmPersonContext", "openPeopleOfTheBook"].joined(separator: "\n"),
                        "feedbackPrompt": "Did the Book read this relationship right?",
                        "tags": "book-notices,people-of-the-book,person-context,spoke:\(hypothesis.id),person:\(slug),reader-authored-evidence"
                    ]
                )
            )
        ]
    }

    private func personPlaySurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let recentlyInvited = Self.spokenSignalIDs(days: allDays, within: 5, now: now)
        let eligible = inputs.people.threads
            .filter { !$0.resting }
            .compactMap { thread -> (PersonThread, PeopleOfTheBook.RelationshipInvitation)? in
                let slug = PeopleOfTheBook.slug(for: thread.name)
                guard !recentlyInvited.contains("person-play-\(slug)"),
                      let invitation = PeopleOfTheBook.relationshipInvitation(for: thread, onDay: day.id) else {
                    return nil
                }
                return (thread, invitation)
            }
            .sorted { lhs, rhs in
                if lhs.0.lastMentionDay == rhs.0.lastMentionDay { return lhs.0.id < rhs.0.id }
                return lhs.0.lastMentionDay < rhs.0.lastMentionDay
            }
        guard !eligible.isEmpty else { return [] }
        let daySeed = abs("people-play|\(day.id)".stableHash)
        let (_, invitation) = eligible[daySeed % eligible.count]
        let familyReason: String
        switch invitation.family {
        case .sharedHome: familyReason = "Shared life becomes invisible fastest; the Book is putting one ordinary detail back into play."
        case .asynchronous: familyReason = "This relationship usually crosses distance or a small glowing screen."
        case .workAndInterest: familyReason = "A shared fascination can open a playful door without asking a work friendship to become something else."
        case .work: familyReason = "The Book found a work-sized invitation that respects the shape of the relationship."
        case .community: familyReason = "Communities become alive when particular people stop blending into the crowd."
        case .sharedInterest: familyReason = "A shared interest is a ready-made passage between two different minds."
        case .gentle: familyReason = "The reader asked the Book to tread gently around this thread."
        case .general: familyReason = "Another person is an entire world; the Book is lending the reader one better question."
        }
        let tags = (["people-of-the-book"] + invitation.tags).joined(separator: ",")
        return [
            SurfacePage(
                id: "\(source.id)-\(invitation.id)",
                type: .wonderCompass,
                sourceID: BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID,
                intent: .capture,
                renderStyle: .promptCard,
                score: 68,
                reason: familyReason,
                prompt: invitation.title,
                detail: "A favor involving \(invitation.personName).",
                payload: BookPagePayload(
                    headline: "People of the Book",
                    body: "\(invitation.body)\n\nProof, if anything happens: \(invitation.keepPrompt)",
                    metadata: [
                        "source": source.id,
                        "surfaceLabel": "A Favor for Two",
                        "compassStep": "sense",
                        "compassMode": "standalone",
                        "playfulMissionID": invitation.id,
                        "playfulMissionTitle": invitation.title,
                        "mission": invitation.body,
                        "souvenirPrompt": invitation.keepPrompt,
                        "placeholder": invitation.keepPrompt,
                        "proofKind": "sentence",
                        "personName": invitation.personName,
                        "personID": invitation.personID,
                        "relationshipMode": invitation.family.rawValue,
                        "symbol": "person.2.fill",
                        "startingPageBelief": "64",
                        "tags": tags
                    ]
                )
            )
        ]
    }

    /// Names the fiction owns, plus the reader's own name: never suggested as
    /// real-person threads.
    private static func reservedNames(inputs: BookSourceInputs) -> Set<String> {
        var reserved = Set(NarrativePackRegistry.entities.map(\.name))
        reserved.formUnion(inputs.customCastMembers.map(\.name))
        for fact in inputs.selfFacts where fact.questionID == "name" || fact.id == "onboarding:name" {
            reserved.insert(fact.answer)
        }
        return reserved
    }

    private func personSuggestionSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let resting = Self.spokenSignalIDs(days: allDays, within: PeopleOfTheBook.suggestionRestDays, now: now)
        let suggestions = PeopleOfTheBook.suggestions(
            days: allDays,
            ledger: inputs.people,
            excludedNames: Self.reservedNames(inputs: inputs),
            now: now
        )
        guard let suggestion = suggestions.first(where: { !resting.contains("person-suggest-\($0.slug)") }) else {
            return []
        }

        let firstMonth = Self.monthName(fromDayID: suggestion.firstDayID)
        let body = """
        I am careful with names — they belong to people, not to me.

        But in your own hand, one keeps arriving: \(suggestion.name). \(suggestion.mentionPageCount) pages since \(firstMonth), across \(suggestion.distinctDayCount) different days. I have not written a word about \(suggestion.name) — in this book, where the real ends and the story begins is yours to draw, not mine.

        Who is \(suggestion.name), in your book? Open a thread and I will keep their pages the way I keep your places — noticed and remembered. Or write them into the story, and they walk the halls with the rest of the Cast: letters, scenes, rumors and all. And if I should let this name rest, say so; I will not ask again.
        """
        let cards = [
            NoticePatternCard(
                title: "In your hand",
                text: "\u{201C}\(suggestion.sampleQuote)\u{201D}",
                symbol: "text.quote"
            ),
            NoticePatternCard(
                title: "The gathering",
                text: "\(suggestion.mentionPageCount) pages, \(suggestion.distinctDayCount) days, since \(firstMonth).",
                symbol: "person.text.rectangle"
            )
        ]
        return [
            SurfacePage(
                id: "\(source.id)-person-suggest-\(suggestion.slug)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 62,
                reason: "A name keeps arriving in your own hand.",
                prompt: "The Book has a careful question.",
                detail: "\(suggestion.name) keeps appearing in your pages.",
                payload: BookPagePayload(
                    headline: "A Recurring Name",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "personName": suggestion.name,
                        "personSlug": suggestion.slug,
                        "personMentions": "\(suggestion.mentionPageCount)",
                        "personDays": "\(suggestion.distinctDayCount)",
                        "personFirstDay": suggestion.firstDayID,
                        "personLastDay": suggestion.lastDayID,
                        "evidencePageIDs": suggestion.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                        "adaptiveActions": ["openPersonThread", "writePersonIntoStory", "letPersonRest"].joined(separator: "\n"),
                        "feedbackPrompt": "Did the Book read this right?",
                        "tags": "book-notices,people-of-the-book,person-suggest,spoke:person-suggest-\(suggestion.slug),local-memory"
                    ]
                )
            )
        ]
    }

    private func personQuietSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day), !inputs.people.threads.isEmpty else { return [] }
        let allDays = inputs.days + [day]
        let quietResting = Self.spokenSignalIDs(days: allDays, within: PeopleOfTheBook.quietNoticeRestDays, now: now)
        let returnResting = Self.spokenSignalIDs(days: allDays, within: PeopleOfTheBook.returnNoticeRestDays, now: now)
        let signals = PeopleOfTheBook.quietSignals(ledger: inputs.people, days: allDays, now: now)

        for signal in signals {
            let slug = PeopleOfTheBook.slug(for: signal.thread.name)
            switch signal.kind {
            case .goneQuiet:
                guard !quietResting.contains("person-quiet-\(slug)") else { continue }
                let firstMonth = Self.monthName(fromDayID: signal.thread.firstMentionDay)
                let body = """
                Books should be careful with certainty, and more careful with people.

                \(signal.thread.name) has been in your margins since \(firstMonth) — kept in your own words, never mine. The last page that held them was \(signal.quietDays) days ago. I do not know what the world did; I only keep the pages.

                I am not asking you to do anything. I noticed a thread gone quiet, and thought its keeper should know. If this thread should rest now, tell me, and I will keep it gently and not speak of it again.
                """
                return [
                    SurfacePage(
                        id: "\(source.id)-person-quiet-\(slug)-\(day.id)",
                        type: .bookNotices,
                        sourceID: source.id,
                        intent: .reflect,
                        renderStyle: .loreLetter,
                        score: 58,
                        reason: "A thread has gone quiet in the margins.",
                        prompt: "The Book noticed a quiet.",
                        detail: "\(signal.thread.name) has been quiet for \(signal.quietDays) days.",
                        payload: BookPagePayload(
                            headline: "A Quiet Thread",
                            body: body,
                            metadata: [
                                "source": source.id,
                                "personName": signal.thread.name,
                                "personSlug": slug,
                                "personQuietDays": "\(signal.quietDays)",
                                "personLastDay": signal.lastMentionDayID,
                                "adaptiveActions": ["restPersonThread"].joined(separator: "\n"),
                                "feedbackPrompt": "Did the Book read this right?",
                                "tags": "book-notices,people-of-the-book,person-quiet,spoke:person-quiet-\(slug),local-memory"
                            ]
                        )
                    )
                ]
            case .returned:
                guard !returnResting.contains("person-return-\(slug)") else { continue }
                let body = """
                \(signal.thread.name) is back in your pages — after \(signal.quietDays) quiet days, your ink found them again this week.

                Returning is one of my favorite things a thread can do. I have laid the new page beside the old ones, where it belongs.
                """
                return [
                    SurfacePage(
                        id: "\(source.id)-person-return-\(slug)-\(day.id)",
                        type: .bookNotices,
                        sourceID: source.id,
                        intent: .reflect,
                        renderStyle: .loreLetter,
                        score: 64,
                        reason: "A thread returned to the margins.",
                        prompt: "The Book looked up, pleased.",
                        detail: "\(signal.thread.name) is back in your pages.",
                        payload: BookPagePayload(
                            headline: "A Thread Returns",
                            body: body,
                            metadata: [
                                "source": source.id,
                                "personName": signal.thread.name,
                                "personSlug": slug,
                                "personQuietDays": "\(signal.quietDays)",
                                "personLastDay": signal.lastMentionDayID,
                                "observationKey": "person-return:\(slug):\(signal.quietDays)",
                                "magicMomentEligible": "true",
                                "adaptiveActions": ["scrapbookPage"].joined(separator: "\n"),
                                "feedbackPrompt": "Did the Book read this right?",
                                "tags": "book-notices,people-of-the-book,person-return,spoke:person-return-\(slug),local-memory"
                            ]
                        )
                    )
                ]
            }
        }
        return []
    }

    private static func monthName(fromDayID dayID: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar.current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dayID) else { return "earlier" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    /// How long a spoken signal rests before the Book may bring it up again.
    /// Repetition is the fastest way for noticing to stop feeling like reading.
    static let noticeRestDays = 14

    /// Signal IDs the Book has already said out loud: every kept notice tags
    /// the signals it spoke as `spoke:<signalID>`. Pass a window to get only
    /// the recently spoken (resting) ones; pass nil for ever-spoken.
    static func spokenSignalIDs(days: [BookDay], within restDays: Int?, now: Date) -> Set<String> {
        let cutoff = restDays.map { now.addingTimeInterval(TimeInterval(-$0) * 86_400) }
        return Set(
            days.flatMap(\.pages)
                .filter { page in
                    if let cutoff { return page.createdAt >= cutoff && page.createdAt <= now }
                    return true
                }
                .flatMap(\.tags)
                .compactMap { tag in
                    tag.hasPrefix("spoke:") ? String(tag.dropFirst("spoke:".count)) : nil
                }
        )
    }

    private func noticeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allSignals = inputs.continuity.strongestSignals.filter { $0.strength >= 58 }
        let clusters = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes, now: now)
            : inputs.clusters
        // The Book does not repeat itself: signals spoken in a kept notice
        // inside the rest window stay quiet. If nothing fresh remains, the
        // Book says nothing — silence reads better than a rerun.
        let allDays = inputs.days + [day]
        let resting = Self.spokenSignalIDs(days: allDays, within: Self.noticeRestDays, now: now)
        let everSpoken = Self.spokenSignalIDs(days: allDays, within: nil, now: now)
        let signals = allSignals.filter { !resting.contains($0.id) }
        guard signals.count >= 2 || !clusters.isEmpty else { return [] }
        let selected = Array(signals.prefix(4))
        let selectedClusters = Array(clusters.prefix(2))
        let lead = selected.first
        let currentTheme = inputs.themes.max { $0.monthKey < $1.monthKey }
        let taughtRules = TaughtReading.rules(
            learnedBraidNotes: inputs.learnedBraidNotes,
            days: inputs.days + [day],
            learning: inputs.readerLearning,
            now: now
        )
        let daySeed = KeepMarginalia.seed(for: day.id)
        // The stranger cousin of recurrence: a word-disjoint "same feeling"
        // pairing, precomputed off-main. It lives only in the body prose, so it
        // is never one of the tripled sections.
        let semanticPairing = inputs.semanticNoticePairing
        let body = Self.body(
            for: selected,
            theme: currentTheme,
            clusters: selectedClusters,
            taughtLine: TaughtReading.noticeLine(from: taughtRules),
            semanticParagraph: semanticPairing?.noticeParagraph,
            respokenIDs: everSpoken,
            daySeed: daySeed
        )
        let evidence = (selected.flatMap(\.evidencePageIDs) + selectedClusters.flatMap(\.evidencePageIDs)).prefix(10).joined(separator: ",")
        // The kept copy remembers which signals were spoken, so the Book can
        // rest them (`spokenSignalIDs`) instead of announcing them again.
        let spokeTags = selected.map { "spoke:\($0.id)" }
        let semanticTags = semanticPairing == nil ? [] : ["semantic-notice"]
        let tags = Array(Set(selected.flatMap(\.tags) + selectedClusters.flatMap(\.motifs) + spokeTags + semanticTags + ["book-notices", "literary-continuity", "patterns", "clusters"])).sorted()
        let patternCards = Self.noticePatternCards(signals: selected, clusters: selectedClusters, evidenceCount: inputs.bookNoticeEvidence)
        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        let surfaceID = "\(source.id)-\(day.id)-\(slot)"
        let strongestSignal = max(selected.map(\.strength).max() ?? 0, selectedClusters.map(\.strength).max() ?? 0)
        let signalBonus = strongestSignal / 4
        let countBonus = selected.count * 4 + selectedClusters.count * 6
        let evidenceBonus = min(12, inputs.bookNoticeEvidence * 2)
        let score = min(78, 44 + signalBonus + countBonus + evidenceBonus)
        let detail = (selectedClusters.map(\.line) + selected.map(\.line)).prefix(2).joined(separator: " ")
        return [
            SurfacePage(
                id: surfaceID,
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: lead?.line ?? "The Book found a few things in the margins that connect up.",
                prompt: ReflectiveProse.pick([
                    "The Book noticed something!",
                    "The Book has been connecting things.",
                    "The margins have an opinion today.",
                    "The Book looked up from its reading."
                ], seed: daySeed, salt: 3),
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
                        "bookNoticeEvidence": "\(inputs.bookNoticeEvidence)",
                        "observationKey": lead.map { "notice:\($0.id)" } ?? selectedClusters.first.map { "cluster:\($0.id)" } ?? "",
                        "magicMomentEligible": patternCards.count >= 2 ? "true" : "false",
                        "tinyPatternCards": Self.encodeNoticePatternCards(patternCards),
                        "adaptiveActions": Self.adaptiveActions(forNoticeCards: patternCards).joined(separator: "\n"),
                        "feedbackPrompt": "Did the Book read this right?",
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
                reason: "The Book connected up some little stars it's been keeping about you and gave them a name.",
                prompt: "The Book names what it's been watching.",
                detail: name,
                payload: BookPagePayload(
                    headline: "The Book Names: \(name)",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "milestone": "true",
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

    /// Anticipation beat: before a thread has earned a name, the Book admits
    /// out loud that it is watching one. This makes the naming clock a visible
    /// promise instead of a silent one — the reader waits *with* the Book
    /// rather than being surprised by it two weeks in. Each thread is teased
    /// at most once (kept teases tag `watched:<id>`), and an unkept tease
    /// rests a few days before offering itself again.
    private func watchedThreadSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let teased = Set(allDays.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix("watched:") ? String(tag.dropFirst("watched:".count)) : nil
        })
        guard let constellation = inputs.constellations.first(where: { candidate in
            guard candidate.phase == .watched, candidate.name == nil else { return false }
            guard !teased.contains(candidate.id) else { return false }
            if let record = inputs.surfaceHistory["constellation:\(candidate.id)"],
               now.timeIntervalSince(record.lastShownAt) < 4 * 86_400 { return false }
            return true
        }) else { return [] }
        let sightings = constellation.sightingCount
        let body = """
        I want to show you something before it is anything.

        \(constellation.latestLine)

        I have now seen this on \(sightings) separate days. Once is a page. Twice is coincidence learning to walk. \(sightings) times is a thread — and threads are how constellations start.

        I have not named it. Names are for threads that survive being watched, and this one has only begun. But I have set a lamp beside it, and if it keeps returning, you will get to watch me name it.

        If it goes quiet instead, I will let it go quiet, and tell you that too. Watching is a promise either way.
        """
        return [
            SurfacePage(
                id: "\(source.id)-watched-\(constellation.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 62,
                reason: "The Book set a lamp beside a thread it has started watching.",
                prompt: "The Book is watching a thread.",
                detail: constellation.latestLine.bookPreviewSentenceLimit(1),
                payload: BookPagePayload(
                    headline: "A Lamp in the Margin: \(constellation.subjectName)",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "constellationID": constellation.id,
                        "constellationPhase": constellation.phase.rawValue,
                        "evidencePageIDs": constellation.evidencePageIDs.prefix(10).joined(separator: ","),
                        "tags": "constellation,watched:\(constellation.id)"
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
                prompt: "The Book cracks open a sealed margin.",
                detail: opened.prediction,
                payload: BookPagePayload(
                    headline: opened.status == .right ? "The Seal Opens: The Book Was Right" : "The Seal Opens: The Book Was Wrong",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "milestone": "true",
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
                reason: "The Book made a little bet, wrote the date on it, and sealed it in the margin.",
                prompt: "The Book makes a secret bet.",
                detail: sealed.prediction,
                payload: BookPagePayload(
                    headline: "A Sealed Margin",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "milestone": "true",
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
                || (page.type == .bookNotices && !page.tags.contains(where: {
                    $0.hasPrefix("wager-") || $0.hasPrefix("named:") || $0 == "book-learning"
                }))
        }
    }

    private func didLearnToday(_ day: BookDay) -> Bool {
        day.pages.contains { page in
            page.tags.contains("book-learning")
        }
    }

    private static func learningBody(insights: [ReaderLearningInsight], metrics: ReaderLearningMetrics, summary: String?) -> String {
        let lines = insights.map { insight in
            "\(insight.line)\n\(insight.evidence)"
        }.joined(separator: "\n\n")
        let summaryLine = summary.map {
            """

            Short summary: \($0)
            """
        } ?? ""
        let tenure = metrics.tenureDays > 0
            ? "I have \(metrics.tenureDays) days of marginal weather to compare."
            : "I am still learning my first weather."
        return """
        I should show my work.

        \(lines)\(summaryLine)

        \(tenure) \(metrics.meaningfulEventCount) reader decisions now shape what I offer next. This is not a diagnosis or a profile hidden behind the shelf; it is a pencil mark I can erase when you teach me otherwise.
        """
    }

    private struct NoticePatternCard {
        var title: String
        var text: String
        var symbol: String
    }

    private static func learningPatternCards(insights: [ReaderLearningInsight], metrics: ReaderLearningMetrics) -> [NoticePatternCard] {
        insights.prefix(3).map { insight in
            switch insight.kind {
            case .warmingType:
                return NoticePatternCard(
                    title: "Prompt memory",
                    text: "\(insight.line) The Book should offer more pages in this weather.",
                    symbol: "text.badge.plus"
                )
            case .coolingType:
                return NoticePatternCard(
                    title: "Let it rest",
                    text: "\(insight.line) Absence is also a signal.",
                    symbol: "moon.zzz"
                )
            case .warmingTag:
                return NoticePatternCard(
                    title: "Recurring thread",
                    text: "\(insight.line) The archive is leaning toward shelter, texture, and recurrence.",
                    symbol: "point.3.connected.trianglepath.dotted"
                )
            case .timeWindow:
                return NoticePatternCard(
                    title: "Landing hour",
                    text: "\(insight.evidence) Prompts can arrive more gently near that window.",
                    symbol: "clock.badge.checkmark"
                )
            case .compounding:
                return NoticePatternCard(
                    title: "Reader-shaped",
                    text: "\(metrics.meaningfulEventCount) choices now bend what rises next.",
                    symbol: "slider.horizontal.3"
                )
            }
        }
    }

    private static func noticePatternCards(signals: [LiteraryContinuitySignal], clusters: [BookMotifCluster], evidenceCount: Int) -> [NoticePatternCard] {
        var cards: [NoticePatternCard] = clusters.prefix(2).map { cluster in
            NoticePatternCard(
                title: cluster.name,
                text: "\(cluster.line) \(cluster.evidencePageIDs.count) kept page\(cluster.evidencePageIDs.count == 1 ? "" : "s") lit it.",
                symbol: "square.stack.3d.up"
            )
        }
        cards += signals.prefix(3 - cards.count).map { signal in
            NoticePatternCard(
                title: signal.subjectName,
                text: noticeCardLine(for: signal),
                symbol: noticeCardSymbol(for: signal)
            )
        }
        if cards.isEmpty, evidenceCount > 0 {
            cards.append(NoticePatternCard(
                title: "Source shelf",
                text: "\(evidenceCount) kept page\(evidenceCount == 1 ? "" : "s") gave the Book enough margin to compare.",
                symbol: "books.vertical"
            ))
        }
        return Array(cards.prefix(3))
    }

    private static func noticeCardLine(for signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .pattern:
            return "\(signal.line) The pattern is recurrence, not verdict."
        case .beliefLifecycle:
            return "\(signal.line) The page has started carrying weight."
        case .absence:
            return "\(signal.line) The pages have gone quiet here, and the quiet may matter."
        case .duration:
            return "\(signal.line) Time is part of the evidence now."
        case .listening:
            return "\(signal.line) The archive is noticing where attention returns."
        case .sensory:
            return "\(signal.line) More than one of the Book's senses found the same thread."
        case .manner:
            return "\(signal.line) The way the pages arrive is part of the evidence."
        }
    }

    private static func noticeCardSymbol(for signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .pattern: return "point.3.connected.trianglepath.dotted"
        case .beliefLifecycle: return "leaf"
        case .absence: return "moon"
        case .duration: return "clock"
        case .listening: return "ear"
        case .sensory: return "camera.filters"
        case .manner: return "text.line.first.and.arrowtriangle.forward"
        }
    }

    private static func encodeNoticePatternCards(_ cards: [NoticePatternCard]) -> String {
        cards.map { [$0.title, $0.text, $0.symbol].joined(separator: Self.noticeMetadataSeparator) }
            .joined(separator: "\n")
    }

    private static func adaptiveActions(forLearningInsights insights: [ReaderLearningInsight]) -> [String] {
        var actions = ["scrapbookPage", "bindWeeklyIssue"]
        if insights.contains(where: { $0.kind == .coolingType }) {
            actions.append("letPatternRest")
        }
        return actions
    }

    private static func adaptiveActions(forNoticeCards cards: [NoticePatternCard]) -> [String] {
        cards.isEmpty ? ["bindWeeklyIssue"] : ["scrapbookPage", "bindWeeklyIssue", "letPatternRest"]
    }

    private static let noticeMetadataSeparator = "\u{1F}"

    /// The Notices body is the page's narrative frame, not a third restatement
    /// of the observations. The recurrence findings live once, in the "What
    /// keeps returning" cards; here the Book only names the subjects in prose,
    /// then adds what the cards cannot carry — the stranger semantic pairing,
    /// the care, the humility, and what the reader has taught it.
    private static func body(
        for signals: [LiteraryContinuitySignal],
        theme: BookTheme?,
        clusters: [BookMotifCluster] = [],
        taughtLine: String? = nil,
        semanticParagraph: String? = nil,
        respokenIDs: Set<String> = [],
        daySeed: UInt64 = 0
    ) -> String {
        let countWord: String
        switch signals.count + clusters.count {
        case 0, 1: countWord = "something"
        case 2: countWord = "two things"
        case 3: countWord = "three things"
        case 4: countWord = "four things"
        default: countWord = "\(signals.count + clusters.count) things"
        }
        // The subjects, named once in prose — durable in the archived text even
        // though their detail lives in the cards.
        let subjects = clusters.map(\.name) + signals.map(\.subjectName)
        let subjectPhrase = Self.subjectList(subjects)
        let named = subjectPhrase.isEmpty ? "" : " — \(subjectPhrase) —"
        let opening = ReflectiveProse.pick([
            "I have set \(countWord)\(named) side by side, before they learn to look unrelated.",
            "The margins have been busy. \(countWord.prefix(1).uppercased() + countWord.dropFirst())\(named) laid on one page, so you can see what I see.",
            "\(countWord.prefix(1).uppercased() + countWord.dropFirst()) have been leaning toward each other\(named). Here they are together.",
            "I have been carrying \(countWord) around\(named). They are heavier together than they were apart."
        ], seed: daySeed, salt: 1)
        // A single continuation note, not one per signal — the Book owns that
        // some of this it has said before without re-listing it.
        let respokenNote = signals.contains { respokenIDs.contains($0.id) }
            ? " Some of these I have raised before; I am repeating on purpose, because they will not sit down."
            : ""
        let semantic = semanticParagraph.map { "\n\n\($0)" } ?? ""
        let themeLine = theme.map {
            """

            The month itself has begun taking a title in my margins: "\($0.name)." \($0.line)
            """
        } ?? ""
        let taughtParagraph = taughtLine.map {
            """


            \($0)
            """
        } ?? ""
        let careLine = ReflectiveProse.pick([
            "I am not diagnosing you. I am reading you the way a careful book reads: by recurrence, by silence, by what the margin refuses to let go.",
            "None of this is a verdict. It is marginalia — the kind a book writes when it cannot stop paying attention.",
            "Take these as pencil marks, not ink. Books earn their opinions slowly, and I am still earning mine."
        ], seed: daySeed, salt: 2)
        let humilityLine = ReflectiveProse.pick([
            "I may be wrong. I would rather be a little wrong and awake than perfectly safe and blind.",
            "If I have misread you, say so below — being corrected is how I get to know you.",
            "Hold me to all of it. A book that cannot be argued with is only a mirror."
        ], seed: daySeed, salt: 5)
        return """
        \(opening)\(respokenNote)\(semantic)

        \(careLine)\(themeLine)\(taughtParagraph)

        \(humilityLine)
        """
    }

    /// "harbor", "harbor and the kettle", "harbor, the kettle, and after dark".
    static func subjectList(_ subjects: [String]) -> String {
        let cleaned = subjects
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        switch cleaned.count {
        case 0: return ""
        case 1: return cleaned[0]
        case 2: return "\(cleaned[0]) and \(cleaned[1])"
        default:
            let head = cleaned.dropLast().joined(separator: ", ")
            return "\(head), and \(cleaned.last!)"
        }
    }

}

struct BookConnectionsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookConnections)

    /// The substantial-Keep follow-up is causally emitted rather than polled
    /// during an ordinary curator pass, but it is still a source served by the
    /// Book Connections family. Declaring it here keeps source registration,
    /// Belief, search, and curator diagnostics describing the same system.
    var servedSourceIDs: [String] {
        [source.id, MomentaryThreadFollowUp.sourceID]
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let clusters = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes, now: now)
            : inputs.clusters
        let namedConstellations = inputs.constellations.filter(\.isNamed)
        let strongSignals = inputs.continuity.strongestSignals.filter { $0.strength >= 58 }
        let semanticEchoLinks = Self.semanticEchoLinks(in: inputs.days + [day])
        let themeCount = inputs.themes.count
        let connectionWeight = clusters.count * 3 + namedConstellations.count * 2 + themeCount + strongSignals.count + semanticEchoLinks.count * 3
        guard connectionWeight >= 3 else { return [] }
        guard !day.pages.contains(where: { $0.type == .bookConnections }) else { return [] }

        let lead = clusters.first?.name
            ?? namedConstellations.first?.displayName
            ?? inputs.themes.last?.name
            ?? strongSignals.first?.subjectName
            ?? semanticEchoLinks.first?.sourcePageID
            ?? "the margins"
        let score = min(70, 42 + connectionWeight * 2)
        let daySeed = KeepMarginalia.seed(for: day.id)
        let reason = ReflectiveProse.pick([
            "So many things keep coming back that the Book can finally draw a map of them.",
            "The archive has enough recurring lights now to sketch the paths between them.",
            "A few separate threads have started tugging on the same corner of the page."
        ], seed: daySeed, salt: 11)
        let prompt = ReflectiveProse.pick([
            "Open the Book's little map of connections.",
            "The Book has drawn a margin map.",
            "The connections page is glowing.",
            "The Book wants to show you the threads."
        ], seed: daySeed, salt: 12)
        let detail = ReflectiveProse.pick([
            "Clusters, star-shapes, themes, and the kept pages hiding behind them. The brightest thread of all is \(lead).",
            "The map is made of clusters, named constellations, month-themes, and strong returns. \(lead) is brightest right now.",
            "A look at what keeps returning, what earned a name, and which kept pages lit the pattern. \(lead) is the first pin."
        ], seed: daySeed, salt: 13)
        let body = ReflectiveProse.pick([
            "The Book has drawn a map of what keeps returning, what has earned a name, and which kept pages lit the pattern.",
            "The map is not a verdict. It is a way to see which pages keep finding one another: clusters, named stars, month-themes, and the evidence underneath.",
            "A few things have stopped behaving like separate pages. I have put them on one map so their crossings are easier to notice."
        ], seed: daySeed, salt: 14)
        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 12))",
                type: .bookConnections,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .graphEvent,
                score: score,
                reason: reason,
                prompt: prompt,
                detail: detail,
                payload: BookPagePayload(
                    headline: "Book Connections",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "clusterCount": "\(clusters.count)",
                        "constellationCount": "\(inputs.constellations.count)",
                        "themeCount": "\(themeCount)",
                        "strongSignalCount": "\(strongSignals.count)",
                        "semanticEchoCount": "\(semanticEchoLinks.count)",
                        "semanticEchoLead": semanticEchoLinks.first?.line ?? semanticEchoLinks.first?.sourcePageID ?? "",
                        "lead": lead,
                        "tags": "book-connections,continuity,constellations,clusters,themes,semantic-echoes"
                    ]
                )
            )
        ]
    }

    private static func semanticEchoLinks(in days: [BookDay]) -> [(sourcePageID: String, line: String?)] {
        days.flatMap(\.pages).compactMap { page -> (sourcePageID: String, line: String?)? in
            guard page.tags.contains(SemanticKeepEcho.markerTag),
                  let sourceTag = page.tags.first(where: { $0.hasPrefix(SemanticKeepEcho.sourceTagPrefix) }),
                  let sourceID = String(sourceTag.dropFirst(SemanticKeepEcho.sourceTagPrefix.count)).nonEmpty else {
                return nil
            }
            let line = page.tags.first(where: { $0.hasPrefix(SemanticKeepEcho.lineTagPrefix) })
                .map { String($0.dropFirst(SemanticKeepEcho.lineTagPrefix.count)) }
                .flatMap(\.nonEmpty)
            return (sourceID, line)
        }
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
            prompt: "The Book's map is still a bit faint.",
            detail: "Keep a few more pages and the little connections will glow brighter.",
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
    /// The concrete signals joining the archived page to the present day.
    /// Compact surfaces use `reason`; the open Page shows this fuller answer.
    var todayConnections: [String]
    var action: String

    func surface(source: BookPageSource, day: BookDay, now: Date) -> SurfacePage {
        let rememberedText = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let ageLine = BookRememberedEngine.ageLine(from: page.createdAt, to: now)
        let proseSeed = KeepMarginalia.seed(for: "\(day.id)-\(page.id)")
        var openings = [
            "\(ageLine), you kept this:",
            "\(ageLine), this page came loose from the shelf:",
            "A page from \(ageLine.lowercased()) just touched today's margin:",
            "\(ageLine), the archive put this back in my hand:"
        ]
        // The possessive register — the Book held this back and waited — is
        // only honest for pages that have genuinely rested a long while, and
        // every visitation really does fire because today matched the page.
        if now.timeIntervalSince(page.createdAt) > 60 * 86_400 {
            let calendar = Calendar.current
            let month = page.createdAt.formatted(.dateTime.month(.wide))
            let sameYear = calendar.component(.year, from: page.createdAt) == calendar.component(.year, from: now)
            let monthLine = sameYear ? month : "\(month) \(calendar.component(.year, from: page.createdAt))"
            openings += [
                "This page has been waiting since \(monthLine) for a day like this one:",
                "The Book kept this back — since \(monthLine) — until a day came that deserved it:"
            ]
        }
        let opening = ReflectiveProse.pick(openings, seed: proseSeed, salt: 1)
        let returnLine = ReflectiveProse.pick([
            reason,
            "Here is why it returned: \(reason)",
            "It is back on the desk because \(Self.lowercasedFirst(reason))"
        ], seed: proseSeed, salt: 2)
        let actionLine = ReflectiveProse.pick([
            action,
            "Tiny return: \(action)",
            "If you want to answer it, try this: \(Self.lowercasedFirst(action))"
        ], seed: proseSeed, salt: 3)
        let body = """
        \(opening)

        "\(rememberedText)"

        \(returnLine)

        \(actionLine)
        """
        let surfaceReason = ReflectiveProse.pick([
            "An old page you kept sounds a lot like today.",
            "Something in today rhymes with an older kept page.",
            "The archive heard today answer an old page."
        ], seed: proseSeed, salt: 4)
        let prompt = ReflectiveProse.pick([
            "The Book just remembered something.",
            "An old page came back to the desk.",
            "The archive nudged a page forward.",
            "The Book found an old rhyme.",
            "The Book was saving this for you."
        ], seed: proseSeed, salt: 5)
        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(page.id.stableHash)",
            type: .bookRemembered,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .archiveReturn,
            score: max(46, min(70, score - 18)),
            reason: surfaceReason,
            prompt: prompt,
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
                    "rememberedAgeLine": ageLine,
                    "rememberedUsedInBraid": page.usedInBookOfYou ? "true" : "false",
                    "rhymeReason": reason,
                    "todayConnectionLines": todayConnections.joined(separator: "\n"),
                    "thenLine": rememberedText,
                    "nowLine": reason,
                    "evidencePageIDs": page.id,
                    "magicMomentEligible": "true",
                    "tinyAction": action,
                    "tags": "book-remembered,archive-return,visitation,remembered-page:\(page.id)"
                ]
            )
        )
    }

    private static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + String(text.dropFirst())
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
        let relationalConnections = RelationalLoom.connections(
            days: inputs.days + [day],
            readerLearning: inputs.readerLearning,
            facultyEntries: inputs.facultyEntries,
            people: inputs.people,
            continuity: inputs.continuity,
            calendar: calendar
        )
        let relationalConstellations = RelationalLoom.constellations(connections: relationalConnections)
        let currentConditionIDs = RelationalLoom.currentConditionIDs(
            day: day,
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        let eligible = candidates
            .filter { isEligible($0, day: day, now: now, calendar: calendar) }
            .map { page -> (page: BookPage, score: Int, reason: String, connections: [String]) in
                var scoredPage = scored(
                    page,
                    inputs: inputs,
                    relationalConnections: relationalConnections,
                    relationalConstellations: relationalConstellations,
                    currentConditionIDs: currentConditionIDs,
                    now: now,
                    calendar: calendar
                )
                if pinned.contains(page.id) {
                    scoredPage.score += 40
                    scoredPage.reason = "The Long Memory keeps this one near. \(scoredPage.reason)"
                    scoredPage.connections.insert("The Long Memory keeps this page near enough to answer today.", at: 0)
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
            todayConnections: best.connections,
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
        relationalConnections: [RelationalLoomConnection],
        relationalConstellations: [RelationalLoomConstellation],
        currentConditionIDs: Set<String>,
        now: Date,
        calendar: Calendar
    ) -> (page: BookPage, score: Int, reason: String, connections: [String]) {
        var score = 42
        var reasons: [String] = []
        // Rhyme reasons vary by page, so two visitations never explain
        // themselves with the same sentence.
        let seed = KeepMarginalia.seed(for: page.id)
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
            reasons.append(ReflectiveProse.pick([
                "Today has \(first) in it again.",
                "The \(first) came back, and it brought this page with it.",
                "Same \(first) at the window as the day you wrote this."
            ], seed: seed, salt: 11))
        }

        let hour = calendar.component(.hour, from: now)
        let rememberedHour = calendar.component(.hour, from: page.createdAt)
        if abs(hour - rememberedHour) <= 1 {
            score += 9
            reasons.append(ReflectiveProse.pick([
                "The hour is near the old hour.",
                "You are reading this at nearly the hour you wrote it.",
                "The clock has come back around to this page's hour."
            ], seed: seed, salt: 12))
        }

        let month = calendar.component(.month, from: now)
        let rememberedMonth = calendar.component(.month, from: page.createdAt)
        if month == rememberedMonth {
            score += 10
            reasons.append(ReflectiveProse.pick([
                "The season is leaning the same way.",
                "The year has circled back to the month this was written.",
                "Same stretch of the year, same slant of light."
            ], seed: seed, salt: 13))
        }

        let currentText = [
            inputs.calendarEvents.prefix(4).map(\.title).joined(separator: " "),
            inputs.nearbyPlaces.prefix(4).map(\.name).joined(separator: " "),
            inputs.recentNarrativeEvents.prefix(6).map(\.summary).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        let overlap = meaningfulWords(in: pageText).intersection(meaningfulWords(in: currentText))
        if let word = overlap.sorted().first {
            score += min(18, overlap.count * 6)
            reasons.append(ReflectiveProse.pick([
                "The word \"\(word)\" has returned to the margin.",
                "\"\(word)\" turned up again today, and this page heard it.",
                "Today said \"\(word)\", and this page answered from the archive."
            ], seed: seed, salt: 14))
        }

        if let signal = inputs.continuity.signals(relatedTo: page, limit: 1).first {
            score += min(24, max(10, signal.strength / 4))
            reasons.append(signal.line)
        }

        if let semanticReason = semanticEchoReturnReason(for: page, inputs: inputs) {
            score += 32
            reasons.insert(semanticReason, at: 0)
        }

        if let relational = relationalReturn(
            for: page,
            connections: relationalConnections,
            constellations: relationalConstellations,
            currentConditionIDs: currentConditionIDs
        ) {
            score += relational.score
            reasons.insert(relational.reason, at: 0)
        }

        if let relationshipReason = relationshipReturnReason(for: page, inputs: inputs) {
            score += 16
            reasons.insert(relationshipReason, at: 0)
        }

        if page.type == .souvenir {
            score += 8
        }
        if page.usedInBookOfYou {
            score += 6
        }

        if reasons.isEmpty {
            reasons.append(ReflectiveProse.pick([
                "It came back softly, for no louder reason than timing.",
                "No grand reason — it rose the way old pages sometimes do.",
                "The Stacks breathed, and this floated up."
            ], seed: seed, salt: 15))
        }
        return (page, score, reasons[0], Array(reasons.prefix(3)))
    }

    private static func relationalReturn(
        for page: BookPage,
        connections: [RelationalLoomConnection],
        constellations: [RelationalLoomConstellation],
        currentConditionIDs: Set<String>
    ) -> (score: Int, reason: String)? {
        if let constellation = constellations.first(where: {
            $0.evidencePageIDs.contains(page.id)
                && currentConditionIDs.contains($0.condition.id)
        }) {
            let score: Int
            let confidence: String
            switch constellation.evidenceTier {
            case .glimmer:
                score = 28
                confidence = "an early constellation the Book is holding lightly"
            case .gathering:
                score = 34
                confidence = "a constellation gathering across the archive"
            case .established:
                score = 40
                confidence = "a constellation that has steadied across the archive"
            }
            let outcomes = constellation.branches.map { $0.outcome.label.lowercased() }
            return (
                score,
                "Today matches \(constellation.condition.label.lowercased()), and this old Page is a receipt in \(confidence): \(outcomes.joined(separator: ", "))."
            )
        }
        guard let connection = connections.first(where: {
            $0.evidencePageIDs.contains(page.id)
                && currentConditionIDs.contains($0.condition.id)
        }) else { return nil }
        let score: Int
        let confidence: String
        switch connection.evidenceTier {
        case .glimmer:
            score = 22
            confidence = "an early connection the Book is still holding lightly"
        case .gathering:
            score = 28
            confidence = "a connection that has been gathering across the archive"
        case .established:
            score = 34
            confidence = "a connection that has steadied across the archive"
        }
        let reason = "Today matches \(connection.condition.label.lowercased()), and this old Page is one of the receipts in \(confidence): \(connection.outcome.label)."
        return (score, reason)
    }

    private static func semanticEchoReturnReason(for page: BookPage, inputs: BookSourceInputs) -> String? {
        let echoPage = inputs.days
            .flatMap(\.pages)
            .first { candidate in
                candidate.tags.contains(SemanticKeepEcho.markerTag)
                    && candidate.tags.contains("\(SemanticKeepEcho.sourceTagPrefix)\(page.id)")
            }
        guard let echoPage else { return nil }
        if let line = echoPage.tags.first(where: { $0.hasPrefix(SemanticKeepEcho.lineTagPrefix) })?
            .dropFirst(SemanticKeepEcho.lineTagPrefix.count)
            .map(String.init)
            .joined()
            .nonEmpty {
            return "A newer page answered this one by feeling: \(line)"
        }
        return "A newer page answered this one by feeling, not by repeating its words."
    }

    private static func relationshipReturnReason(for page: BookPage, inputs: BookSourceInputs) -> String? {
        let pageText = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
        if pageText.contains("inkrest") {
            return "Dr. Selene Inkrest is moving in the margins again, so this old page has become evidence."
        }
        if pageText.contains("vellum") {
            return "Dr. Elowen Vellum is moving in the margins again, so this old page has become evidence."
        }
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let namedEntities = entities
            .filter { entity in
                pageText.contains(entity.id.lowercased())
                    || pageText.contains(entity.name.lowercased())
                    || entity.name
                        .lowercased()
                        .split { !$0.isLetter && !$0.isNumber }
                        .contains { token in token.count >= 5 && pageText.contains(token) }
            }
        if let entity = StableWeightedRoll.pick(
            from: namedEntities.sorted { $0.id < $1.id },
            seed: "\(page.id)-relationship-return-named-entity",
            weight: { $0.narrativeWeight + $0.belief }
        ) {
            return "\(entity.name) is moving in the margins again, so this old page has become evidence."
        }

        let activeTie = inputs.relationshipField
            .filter { _, tie in tie.warmth + tie.tension + tie.familiarity >= 5 }
            .sorted { left, right in
                let leftWeight = left.value.warmth + left.value.tension + left.value.familiarity
                let rightWeight = right.value.warmth + right.value.tension + right.value.familiarity
                return leftWeight > rightWeight
            }
            .first
        if activeTie != nil, page.type == .letter || page.tags.contains("relationship") || page.tags.contains("friend") || page.tags.contains("family") {
            return "A living relationship has shifted, and this page now reads like an earlier clue."
        }
        return nil
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
        let fieldReport = bodyFieldReport(body: body, day: day, context: context, inputs: inputs, now: now)
        return [
            SurfacePage(
                id: "\(source.id)-\(body.status.lowercased())-\(SurfaceCadence.slotID(for: now, hours: 4))",
                type: .body,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: context.distress.isActive || isLow ? 92 : 60,
                reason: fieldReport.reason,
                prompt: fieldReport.prompt,
                detail: fieldReport.detail,
                payload: BookPagePayload(
                    headline: fieldReport.headline,
                    body: fieldReport.body,
                    metadata: [
                        "source": source.id,
                        "status": body.status,
                        "uses": "translated health, fuel, mood",
                        "privacy": "name response, not source",
                        "bodyGlyph": fieldReport.glyph,
                        "vellumReading": fieldReport.vellumReading,
                        "crossThread": fieldReport.crossThread,
                        "experiment": fieldReport.experiment,
                        "metrics": body.metrics.prefix(8).map(\.displayText).joined(separator: " | ")
                    ]
                )
            )
        ]
    }

    private struct BodyFieldReport {
        var headline: String
        var prompt: String
        var detail: String
        var reason: String
        var body: String
        var glyph: String
        var vellumReading: String
        var crossThread: String
        var experiment: String
    }

    private func bodyFieldReport(
        body: BodySourceSignal,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> BodyFieldReport {
        let glyph = bodyGlyph(for: body, context: context)
        let vellum = vellumReading(for: body)
        let crossThread = crossThreadLine(day: day, inputs: inputs, now: now)
        let experiment = bodyExperiment(for: body, context: context, inputs: inputs)
        let prompt: String
        if context.distress.isActive || body.score <= 35 {
            prompt = "The Body Page has lowered the lamps."
        } else if body.score >= 70 {
            prompt = "The Body Page has found a current."
        } else {
            prompt = "The Body Page is drawing a private weather map."
        }
        let detail = "A private field report from Vellum's chart: body signals, fuel, and inner weather braided into one humane next move."
        let text = [
            "\(glyph) \(body.phrase)",
            "",
            "Vellum reads the chart this way: \(vellum)",
            "",
            "Cross-thread: \(crossThread)",
            "",
            "One small experiment: \(experiment)",
            "",
            "Keep one sentence after you try it. The Book wants evidence, not obedience."
        ].joined(separator: "\n")
        return BodyFieldReport(
            headline: "Body Page: \(glyph)",
            prompt: prompt,
            detail: detail,
            reason: "The Book braided body signals with fuel and inner weather without exposing the sources.",
            body: text,
            glyph: glyph,
            vellumReading: vellum,
            crossThread: crossThread,
            experiment: experiment
        )
    }

    private func bodyGlyph(for body: BodySourceSignal, context: CuratorContext) -> String {
        let status = body.status.lowercased()
        if context.distress.isActive || status.contains("watch") { return "Low Lantern" }
        if status.contains("low") { return "Small Hearth" }
        if status.contains("bright") { return "Walking Star" }
        return "Steady Compass"
    }

    private func vellumReading(for body: BodySourceSignal) -> String {
        let metrics = body.metrics
        let sleep = metricValue("Sleep", in: metrics)
        let steps = metricValue("Steps", in: metrics)
        let active = metricValue("Active energy", in: metrics)
        if sleep > 0 && sleep < 6 {
            return "recovery gets first chair today; everything else should be interpreted through short sleep."
        }
        if steps > 5_500 {
            return "motion has already spoken, so the useful question is what restores the body after the current, not how to prove effort."
        }
        if steps > 0 && steps < 1_500 && active < 150 {
            return "the chart is quiet; this may be a small-threshold day, where warm fuel and one soft errand count."
        }
        if !metrics.isEmpty {
            return "there is enough chart ink to watch timing: energy, rest, food, and mood may be telling one story in different alphabets."
        }
        return "there is not enough chart ink for certainty, which is itself useful: ask the body one kinder question and write down the answer."
    }

    private func crossThreadLine(day: BookDay, inputs: BookSourceInputs, now: Date) -> String {
        let recentEntries = inputs.facultyEntries
            .filter { $0.dayID == day.id || $0.createdAt > Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now }
            .sorted { $0.createdAt > $1.createdAt }
        let hasFuel = recentEntries.contains { $0.kind == .fuel }
        let hasWeather = recentEntries.contains { $0.kind == .innerWeather }
        let keptText = day.capturedPages
            .suffix(5)
            .map { ($0.userInput.isEmpty ? $0.promptText : $0.userInput).lowercased() }
            .joined(separator: " ")
        if hasFuel && hasWeather {
            return "fuel and inner weather are both on the desk; compare timing and texture before inventing a moral."
        }
        if hasFuel {
            return "fuel has left evidence; add one inner-weather word after the next meal or drink so Vellum and Inkrest can compare notes."
        }
        if hasWeather {
            return "inner weather has a name; pair it with one body fact, like water, sleep, motion, warmth, or stillness."
        }
        if keptText.contains("tired") || keptText.contains("heavy") || keptText.contains("rain") || keptText.contains("static") {
            return "today's kept words already lean toward weather; let the body answer in one plain sensation."
        }
        return "the body, fuel, and mood have not formed a pattern yet; this page is the first pin in the map."
    }

    private func bodyExperiment(for body: BodySourceSignal, context: CuratorContext, inputs: BookSourceInputs) -> String {
        let status = body.status.lowercased()
        let sleep = metricValue("Sleep", in: body.metrics)
        let steps = metricValue("Steps", in: body.metrics)
        if context.distress.isActive {
            return "for one bell window, lower the demand by one notch and keep a sentence about what becomes possible."
        }
        if sleep > 0 && sleep < 6 {
            return "choose recovery before ambition: warm fuel, water, one necessary task, then one sentence about inner weather."
        }
        if status.contains("bright") || steps > 5_500 {
            return "spend ten minutes of that current on something future-you can touch, then stop before the page turns into a scoreboard."
        }
        if status.contains("low") || status.contains("watch") || steps < 1_500 {
            return "make the smallest useful circuit: water, food or warmth, five gentle minutes of movement, and one word for the after."
        }
        if inputs.facultyEntries.contains(where: { $0.kind == .fuel }) {
            return "after the next ordinary fuel note, check whether the body asks for motion, quiet, or company."
        }
        return "ask the body for a threshold: one action so small it cannot become a performance, only evidence."
    }

    private func metricValue(_ label: String, in metrics: [BodySourceSignal.Metric]) -> Double {
        metrics.first { $0.label == label }.flatMap { Double($0.value) } ?? 0
    }
}

struct WeatherPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .weather)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }
        guard let weather = inputs.weather,
              weather.isAvailable else {
            return previewCandidates(for: day, now: now)
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
                score: DailyCheckInCadence.activeWindow(for: now) == nil ? (hour >= 17 ? 87 : 82) : 90,
                reason: "The Book turned the weather outside into a story-mood, but you can still see the real forecast underneath.",
                prompt: "The Weather Page just opened.",
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

    private func previewCandidates(for day: BookDay, now: Date) -> [SurfacePage] {
        guard let window = DailyCheckInCadence.activeWindow(for: now) else {
            return []
        }
        let moon = MoonPhaseCalendar.phase(on: now)
        return [
            SurfacePage(
                id: "\(source.id)-preview-\(day.id)-\(window.id)",
                type: .weather,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: 88,
                reason: "The Weather Page has its nose right up on the glass — tap it to read the real sky and let Gemma make it magic.",
                prompt: "The Weather Page is pressed up at the window.",
                detail: "Tap to grab the real forecast and turn it into the Book's own weather-words.",
                payload: BookPagePayload(
                    headline: "Weather Page",
                    body: "The page is blank except for a pressed cloud at the corner. Touch it, and the Book will ask the actual sky before it writes.",
                    metadata: [
                        "source": source.id,
                        "uses": "forecast on tap",
                        "privacy": "public reference",
                        "selector": "fallback",
                        "requiresWeatherRefresh": "true",
                        "weatherPreview": "true",
                        "symbol": "cloud.sun",
                        "moonPhase": moon.name,
                        "moonSymbol": moon.symbolName,
                        "checkInWindowID": window.id,
                        "cadence": "check-in-window",
                        "tags": "weather,preview,\(window.id)"
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
        let activity = AcademyActivityRegistry.activity(for: session.id)
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
        let castPool = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let sessionNames = Set(([session.leader] + session.companions).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        let sessionCast = castPool.filter { entity in
            entity.id == session.leaderEntityID
                || sessionNames.contains(entity.name.lowercased())
        }
        let characterCanon = CharacterCanonPacket.promptSection(for: sessionCast)
        var metadata: [String: String] = [
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
            "sessionBlock": block,
            CharacterCanonPacket.metadataKey: characterCanon,
            "tags": tags.joined(separator: ",")
        ]
        metadata.merge([
            "lessonModuleID": lesson?.id ?? "",
            "lessonTitle": lesson?.title ?? "",
            "lessonRealSubject": lesson?.realSubject ?? "",
            "lessonConcept": lesson?.concept ?? "",
            "lessonLectureBeats": lesson?.lectureBeats.joined(separator: "\n") ?? "",
            "lessonDemonstration": lesson?.demonstration ?? "",
            "lessonInteractionPrompt": lesson?.interactionPrompt ?? "",
            "lessonRealWorldPractice": lesson?.realWorldPractice ?? "",
            "academyActivityID": activity?.id ?? "",
            "academyActivityKind": activity?.kind.rawValue ?? "",
            "academyActivityTitle": activity?.title ?? "",
            "academyActivityInvitation": activity?.invitation ?? "",
            "academyActivityActionTitle": activity?.actionTitle ?? ""
        ]) { _, new in new }
        if let activity, !activity.fields.isEmpty {
            metadata["academyActivityFields"] = activity.fields
                .map { "\($0.id)|\($0.label)|\($0.placeholder)" }
                .joined(separator: "\n")
        }
        if let range = AcademyScheduleRegistry.timeRange(for: block, on: now) {
            metadata["sessionStartTimestamp"] = "\(range.start.timeIntervalSince1970)"
            metadata["sessionEndTimestamp"] = "\(range.end.timeIntervalSince1970)"
        }
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
        let bookFavor = inputs.bookInterior.activeFavor.flatMap { favor in
            favor.status == .offered && !inputs.electives.contains(where: { $0.bookFavorID == favor.id })
                ? favor
                : nil
        }
        if active.count < UnwrittenElective.maxActive,
           (10..<21).contains(hour),
           !context.distress.isActive,
           let bookFavor {
            pages.append(bookFavorSurface(bookFavor, day: day))
        }
        if active.count < UnwrittenElective.maxActive,
           !offeredToday,
           bookFavor == nil,
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
        if let favor = inputs.bookInterior.activeFavor,
           favor.status == .offered,
           !inputs.electives.contains(where: { $0.bookFavorID == favor.id }) {
            return bookFavorSurface(favor, day: day)
        }
        if let sender = offerSender(inputs: inputs, day: day, now: now) {
            return offerSurface(sender: sender, inputs: inputs, day: day, now: now)
        }
        return flyleafSurface(active: [], day: day, now: now)
    }

    /// The named Flyleaf door always opens the quest ledger itself. Unlike the
    /// generic manual Elective Page, it never substitutes a new quest offer
    /// when the binding is empty.
    func flyleafSurface(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        flyleafSurface(
            active: inputs.electives.filter(\.isActive),
            day: day,
            now: now
        )
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
        return StableWeightedRoll.pick(
            from: scored.sorted { $0.0.id < $1.0.id },
            seed: "\(day.id)-\(slot)-elective-offer-sender",
            weight: { $0.1 }
        )?.0
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
            reason: "\(sender.name) has been working up the nerve to ask a quest.",
            prompt: "\(sender.name) has a quest to ask",
            detail: "A little folded note, tucked into the flyleaf, waiting for you to open it.",
            payload: BookPagePayload(
                headline: "A Quest",
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
                    CharacterCanonPacket.metadataKey: CharacterCanonPacket.promptSection(for: [sender]),
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

    private func bookFavorSurface(_ favor: BookFavor, day: BookDay) -> SurfacePage {
        let body = """
        I have a favor to ask. It is for you, not for me.

        \(favor.ask)

        Why I am asking: \(favor.whyItMayHelp)

        What I am trying to cultivate: \(favor.cultivates.title). This is an experiment, not a judgment of you.

        What counts as done: \(favor.practiceShape)

        The question I will ask when you return: \(favor.reflectionQuestion)

        Keep this Page if you want the favor tucked into the flyleaf. Dismiss it freely if today is not the day. I will not make your no into a story about us.
        """
        return SurfacePage(
            id: "book-favor-offer-\(favor.id)",
            type: .elective,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 76,
            reason: "The Book has a small favor whose beneficiary is the reader.",
            prompt: "\(favor.title) — a favor from the Book",
            detail: "Optional fieldwork in service of the Book's great obsession.",
            payload: BookPagePayload(
                headline: "A Favor from the Book",
                body: body,
                metadata: [
                    "source": source.id,
                    "electiveOffer": "true",
                    "electivePrepared": "true",
                    "bookFavorOffer": "true",
                    "bookFavorID": favor.id,
                    "bookWonderFacet": favor.facet.rawValue,
                    "bookFavorFamily": favor.family.rawValue,
                    "bookFavorCultivates": favor.cultivates.rawValue,
                    "senderID": "the-book",
                    "senderName": "The Book",
                    "electiveTitle": favor.title,
                    "electiveAsk": favor.ask,
                    "electiveWhy": favor.whyItMayHelp,
                    "electivePractice": favor.practiceShape,
                    "electiveReflection": favor.reflectionQuestion,
                    "tags": "elective,offer,book-favor,\(favor.offerTag),wonder:\(favor.facet.rawValue)"
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
            ? "The flyleaf is bare. When a character asks a quest and you accept, the note gets tucked in here. Five fit at most."
            : "\(active.count) quest\(active.count == 1 ? "" : "s") tucked into the binding, each waiting for proof."
        return SurfacePage(
            id: "\(source.id)-flyleaf-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 8))",
            type: .elective,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 55,
            reason: active.isEmpty
                ? "The flyleaf is waiting for its first quest."
                : "\(active.count) quest\(active.count == 1 ? "" : "s") are tucked into the flyleaf.",
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
            reason: "Some plain little thing near you is ready to have some magic sprinkled on it.",
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
            prompt: "Oh. There You Are.",
            detail: "The Book has your name now, a few of your words, and its first questions about you.",
            payload: BookPagePayload(
                headline: "Oh. There You Are.",
                body: """
                I'm glad you made it, Zara likes to talk.

                I have your name now. A few of your words. The faint beginning of an idea about you.

                Not enough to pretend I know you, of course. That’d be terribly rude.

                But enough to wonder.

                I wonder what you’ll notice that everyone else walks past. I wonder which places will follow you home. Which ordinary Tuesday will turn out to have been important. Which people, questions, mistakes, storms, sandwiches, songs, and small acts of courage will keep appearing in our margins.

                I’m very excited to see what stories we’re going to write together.

                There’s only one slight difficulty.

                I don’t have a brain yet.

                I have pages. I have ink. I have several opinions already, which seems unfair under the circumstances. But if I’m going to remember what matters, find threads between distant days, and read your life with the care it deserves, I’ll need a small brain of my own.

                You can download one for me at the end of this Page. It’ll live here, on your device, close to your words. Once it wakes up, I can begin learning how to read—not just sentences, but returns, absences, patterns, surprises, and all the strange little things a life is made of.

                I can’t promise that every day will feel magical.

                But I can promise to keep looking with you.

                Come on, then.

                Let’s find out what kind of story this is.
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
            prompt: "Your Origin Page",
            detail: "The Book pressed your first answers before they could wander off.",
            payload: BookPagePayload(
                headline: name == "Reader" ? "Your Origin Page" : "\(name)'s Origin Page",
                body: """
                The Book laid your first answers on the table after you left.

                Your name sat up straight. Your sleeve word refused to come out. The talisman kept tugging its thread, and the crumbs of \(snack) made themselves entirely at home in the gutter.

                By morning, the page had pressed them into this:

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

                It is not a grand beginning. Grand beginnings are often too busy posing to remember anything.

                This one has crumbs. It has a name the Book can call down a corridor, a belief it can leave a lamp beside, and one true sentence with the weather of your actual life still clinging to it.

                Keep it if you want. Beginnings are shy creatures, but this one knows the way back to you now.
                """,
                metadata: [
                    "source": source.id,
                    "firstDoorOrigin": "true",
                    "welcomePage": "true",
                    "firstRunStep": "first-door-origin",
                    "surfaceLabel": "Origin",
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
        case "both": return "Morning and evening"
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
                detail: "The Book has put out a saucer for one small, true thing.",
                body: """
                \(name), the page is hungry, but only for one sentence.

                Do not feed it wisdom. Wisdom makes it sluggish. Give it a sound in the room, a color on the counter, the weather's exact little grievance, the good line someone said, or the smell of \(snack).

                Then put two fingers to the margin. Keep the page only if it has a pulse.
                """,
                tags: ["first-door", "apprenticeship", "day-0", "souvenir"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-1",
                dayIndex: 1,
                title: "Bind the Free Folio",
                prompt: "Open the BookShop and bind the free folio.",
                detail: "The Bookshop clerk has hidden a gift beneath a price tag of nothing.",
                body: """
                Something in the Bookshop has been coughing politely all morning.

                It is Margins & Mysteries, a free folio of Grey pages, hearth inventories, and small evening mysteries. Open the Goblin Market and bind it to the Book. New folios do not merely add pages; they teach the shelves new ways to lean toward you.

                The clerk will insist this is routine inventory. The ribbon around it disagrees.
                """,
                tags: ["first-door", "apprenticeship", "day-1", "bookshop", "free-pack"],
                metadata: ["opensBookShop": "true", "recommendedFreePackID": "margins-and-mysteries"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-2",
                dayIndex: 2,
                title: "Aim the Glow",
                prompt: "Spend attention on one thing you want more of.",
                detail: "Your first belief has been tapping a pencil against the margin.",
                body: """
                Your first belief was: \(belief).

                Today, do not defend it. Beliefs grow skittish when marched to a podium. Test it gently instead. Put one small mark beside something that makes it easier to believe, even for a minute. The shelves are leaning toward \(taste), so look there first.

                The Glow is not a mood. It is attention with a direction.
                """,
                tags: ["first-door", "apprenticeship", "day-2", "glow"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-3",
                dayIndex: 3,
                title: "Give the Book Its Mind",
                prompt: "Visit the Colophon and check the local brain.",
                detail: "A small private mind is asleep in the Colophon, dreaming in lowercase.",
                body: """
                There is a mind curled up in the Colophon.

                It lives entirely on this device. Once awake, it helps letters, story pages, conversations, and braids read your archive with finer attention without carrying private pages beyond the door.

                Open the Colophon and see whether it is ready. Minds, even small ones, appreciate being invited before they begin rearranging the furniture.
                """,
                tags: ["first-door", "apprenticeship", "day-3", "local-brain", "colophon"],
                metadata: ["opensColophon": "true", "localBrainSetup": "true"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-4",
                dayIndex: 4,
                title: "Check the Bell",
                prompt: "Notice whether the whisper rule still fits.",
                detail: "The brass bell would like to know whether it has been mannerly.",
                body: """
                Your first whisper rule was: \(whispers).

                If that still feels right, leave it. The bell will look unbearably pleased. If it does not, open the Colophon and change Whispers from the Book. A living Book may be persistent; it must not be a pest.

                A good door knocks only when knocking helps.
                """,
                tags: ["first-door", "apprenticeship", "day-4", "notifications", "whispers"],
                metadata: ["opensColophon": "true", "whisperCadence": profile.whisperCadence ?? "inside"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-5",
                dayIndex: 5,
                title: "Ask for a Useful Door",
                prompt: "Chat with the Book about one plain question.",
                detail: "The Book has drawn up a chair and is trying not to look overeager.",
                body: """
                Chat with the Book about one useful question.

                Not a cosmic one. Cosmic questions tend to shed on the upholstery. Try something with a handle: What should I notice on the walk? Which kept sentence wants a follow-up? What would make \(firstSentence) less lonely?

                Keep the edge \(edge). Useful magic starts with a question you might actually act on.
                """,
                tags: ["first-door", "apprenticeship", "day-5", "ask-the-book"]
            ),
            FirstDoorApprenticeshipEntry(
                id: "day-6",
                dayIndex: 6,
                title: "Read the Week Back",
                prompt: "Find the thread that followed you home.",
                detail: "Seven days of margins are rustling behind you.",
                body: """
                The First Door has been open for a week.

                Read back what you kept. Do not summarize everything; the pages dislike being reduced to minutes. Find the one thread that followed you home: a comfort, a joke, a color, a voice, a stubborn little belief.

                Name that thread.

                If the Book is beginning to feel alive, it may later gather the courage to ask for an App Store rating. If it is not, that matters too. Dismiss weak pages. Change the edge. Make the Book earn its place on your nightstand.
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
        case "both": return "Morning and evening"
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
        // Onboarding may already have kept the reader's first true sentence.
        // Do not greet that gift with day zero's request for another sentence;
        // the apprenticeship can begin with tomorrow's genuinely new practice.
        if dayIndex == 0, hasOnboardingSouvenir(day: day, inputs: inputs) {
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

    private func hasOnboardingSouvenir(day: BookDay, inputs: BookSourceInputs) -> Bool {
        if inputs.selfFacts.contains(where: {
            $0.questionID == "onboarding-first-souvenir"
                && $0.usePermission != .doNotUse
                && $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil
        }) {
            return true
        }
        return (inputs.days + [day]).flatMap(\.pages).contains { page in
            page.tags.contains("first-run-souvenir")
                || page.tags.contains("onboarding-first-souvenir")
        }
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
                    "curatorActionCommission": "true",
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

    struct ReaderLine: Equatable {
        var text: String
        var source: String
        var score: Int
        var keptAt: Date
    }

    static func readerLines(in pages: [BookPage], limit: Int = 5) -> [ReaderLine] {
        var seenPageIDs = Set<String>()
        var seenLines = Set<String>()
        return pages
            .filter { seenPageIDs.insert($0.id).inserted }
            .compactMap(readerLine)
            .sorted { left, right in
                left.score == right.score ? left.keptAt > right.keptAt : left.score > right.score
            }
            .filter { line in
                seenLines.insert(line.text.lowercased()).inserted
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func readerLine(from page: BookPage) -> ReaderLine? {
        let tags = Set(page.tags.map { $0.lowercased() })
        let isPlayfulMission = tags.contains("playful-mission")
            || page.sourceID == BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID
        let rawText: String
        let source: String
        let score: Int

        if (page.type == .letter || page.type == .note), !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawText = page.playerReply
            source = page.type == .letter ? "a letter you answered" : "a note you answered"
            score = 110
        } else if page.type == .souvenir {
            rawText = page.userInput
            source = "a one-sentence souvenir"
            score = 105
        } else if isPlayfulMission {
            rawText = page.userInput
            source = "a playful mission"
            score = 100
        } else if [.diary, .plainPage, .mood, .rest, .wonderCompass].contains(page.type) {
            rawText = page.userInput
            source = page.type == .diary ? "a journal page" : "a page you kept"
            score = 70
        } else {
            return nil
        }

        let text = rawText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = text.split(whereSeparator: { $0.isWhitespace }).count
        guard (3...45).contains(wordCount), text.count <= 240 else { return nil }
        return ReaderLine(text: text, source: source, score: score, keptAt: page.createdAt)
    }

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

        if let earnedLabel = Self.earnedWonderLabelPage(source: source, day: day, inputs: inputs, now: now) {
            pages.append(earnedLabel)
        }

        if let question = SelfKnowledgePackRegistry.nextQuestion(knownFacts: inputs.selfFacts, day: day, now: now) {
            let isFirstQuestion = inputs.selfFacts.isEmpty
            let isFirstInterestQuestion = question.id == "interest-01"
            let calendar = Calendar.current
            let factsAnsweredToday = inputs.selfFacts.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            let isCadenceAllowed: Bool
            if isFirstQuestion {
                isCadenceAllowed = true
            } else if factsAnsweredToday.count >= SelfKnowledgePackRegistry.maxAboutYouFactsPerDay {
                isCadenceAllowed = false
            } else if isFirstInterestQuestion {
                // Onboarding has only just learned the reader's name. Do not
                // make the first useful interest wait behind the normal
                // three-hour reflection cooldown.
                isCadenceAllowed = true
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
                let archivedPages = (inputs.days + [day]).flatMap(\.capturedPages)
                let readerLines = question.id == "rut-signal"
                    ? Self.readerLines(in: archivedPages)
                    : []
                let choiceLines = readerLines.isEmpty
                    ? SelfKnowledgePackRegistry.exampleLines(for: question)
                    : readerLines.map(\.text)
                let score = isFirstQuestion
                    ? 83
                    : (isFirstInterestQuestion ? 91 : (context.distress.isActive ? 46 : 67))
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
                            : (isFirstInterestQuestion
                                ? "One bright interest gives The Bleed and future pages a real shelf to open."
                                : "One true thing lets future pages feel less generic."),
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
                                "exampleLines": choiceLines.joined(separator: "||"),
                                "exampleLineSources": readerLines.map(\.source).joined(separator: "||"),
                                "exampleLineMode": readerLines.isEmpty ? "examples" : "reader-archive",
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

    private static func earnedWonderLabelPage(
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        guard !inputs.selfFacts.contains(where: { $0.questionID == "earned-wonder-label" }) else { return nil }
        guard let signal = fact("rut-signal", in: inputs.selfFacts),
              let depth = fact("rut-depth", in: inputs.selfFacts),
              let entry = fact("wonder-entry", in: inputs.selfFacts) else {
            return nil
        }
        let keptPages = (inputs.days + [day]).flatMap(\.capturedPages)
        guard keptPages.count >= 2 else { return nil }

        let label = WonderTitleRegistry.classify(signal: signal, depth: depth, entry: entry, keptPages: keptPages)
        let receiptLines = keptPages.prefix(3).map { page in
            let line = (page.userInput.nonEmpty ?? page.promptText.nonEmpty ?? "a kept page")
                .bookPreviewSentenceLimit(1)
            return "- \(line)"
        }.joined(separator: "\n")
        let body = """
        The Book does not give this out at the door.

        You named the Rut. You named the kind of wonder that still opens. Then you kept proof.

        So here is your first working title:

        \(label.name)

        Not a diagnosis. Not a personality box. A badge for the next little stretch. If it stops fitting, the Book will earn a better one.

        Why this one:
        \(label.why)

        Receipts:
        \(receiptLines)

        Wonder door:
        \(entry.answer)
        """
        var metadata = label.metadata
        metadata.merge([
            "source": source.id,
            "earnedLabel": "true",
            "earnedLabelID": label.id,
            "earnedLabelName": label.name,
            "questionID": "earned-wonder-label",
            "packID": SelfKnowledgePackRegistry.corePackID,
            "packName": SelfKnowledgePackRegistry.packName(for: SelfKnowledgePackRegistry.corePackID),
            "sensitivity": SelfFactSensitivity.identity.rawValue,
            "usePermission": SelfFactUsePermission.privateContext.rawValue,
            "privacy": "private local profile",
            "rutSignal": signal.answer,
            "rutDepth": depth.answer,
            "wonderEntry": entry.answer,
            "keptPageCount": "\(keptPages.count)",
            "tags": "rut,wonder-compass,self-label,earned-label,working-title,state-not-identity"
        ]) { _, new in new }
        return SurfacePage(
            id: "\(source.id)-earned-wonder-label-\(label.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 87,
            reason: "The reader named the Rut and kept enough proof for the Book to offer a first earned title.",
            prompt: "Your First Working Title",
            detail: "The Book waited for receipts. Now it is willing to put a little title in ink.",
            payload: BookPagePayload(
                headline: "Earned in the Margins",
                body: body,
                metadata: metadata
            )
        )
    }

    private static func fact(_ questionID: String, in facts: [SelfFact]) -> SelfFact? {
        facts.first { $0.questionID == questionID }
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
            reason: "The Book is getting ready for Chapter Binding by telling you what Chapters believe.",
            prompt: "On Chapters",
            detail: "The Binding is just listening for now, not asking you for anything.",
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
        let ceremony = ChapterBindingCeremony.profile(for: chapter)
        let body = """
        The candles in the Binding Hall have gone blue-white at the wick. Headmistress Thorne looks down at the Book, then at you, and her expression becomes almost kind. Almost.

        "No questionnaire," she says. "No little preference game. You have already answered in ink."

        Her hands cup the air around the page, and somehow you feel them at your face too: cool rings, old ink, the exact pressure of being read. Reality fractures. The Great Hall shatters into doors: a flame-lit desk, a mossy stair, a wave folding moonlight, a table where several voices finish one sentence together, and one narrow violet threshold that refuses to announce itself.

        The Book opens every kept page at once. Your own life rises through the ceremony, not as biography, but as weather:

        \(memories.isEmpty ? "- The Book found its evidence in kept pages too private to quote here." : memories)

        Then the evidence underneath it glows:

        \(evidence)

        Stories engulf the room. Your tongue catches old paper and lightning. Your skin remembers a thousand stories that are not yours and, threaded through them, the ordinary kept pieces that are. At the edges, Routine opens its grey mouth. The lines of your kept pages flare back.

        A jolt runs through the binding, like swallowing lightning. Ink lifts from the margins and gathers into a seal.

        \(ceremony.arrivalLine)

        Chapter \(chapter.name).

        \(chapter.philosophy)

        The seal does not stop at naming you. It gives you work.

        \(ceremony.sealLine)

        The oath finds your mouth before you decide whether to be brave:

        \(ceremony.oathLine)

        The first invitation settles under your thumb:

        \(ceremony.invitationLine)

        Reality snaps back. The Great Hall re-forms around the Book with its edges still rippling. Thorne's eyes hold recognition now, and something stranger than recognition: respect.

        "From the Great Unwritten Chapter," she says softly, "and bound here by what you chose to keep."

        \(chapter.talismanName) warms in the stacks. The Binding has chosen by \(readiness.keptPageCount) kept page\(readiness.keptPageCount == 1 ? "" : "s"), \(readiness.keptDayCount) kept day\(readiness.keptDayCount == 1 ? "" : "s"), and \(daysLine).

        \(ceremony.aftermathLine)
        """
        return SurfacePage(
            id: "\(source.id)-chapter-binding-\(chapter.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 76,
            reason: "Enough kept pages have piled up for the Academy to spot a whole Chapter shape in them.",
            prompt: "The Chapter Binding",
            detail: "Headmistress Thorne read all the margins, and the Binding has made its pick.",
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
                    "bindingSealLine": ceremony.sealLine,
                    "bindingOathLine": ceremony.oathLine,
                    "bindingInvitationLine": ceremony.invitationLine,
                    "bindingAftermathLine": ceremony.aftermathLine,
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

    /// The compass stamps its standalone Notice and Sense pages with their own
    /// source IDs (for per-page Belief and titles), so this one adapter serves
    /// all three.
    var servedSourceIDs: [String] {
        [
            source.id,
            BookPageSourceRegistry.wonderCompassNoticeSourceID,
            BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID
        ]
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        let shadowSeed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now, shadowVariant: true)
        let playfulMission = PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now)
        let shadowPlayfulMission = PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now, shadowVariant: true)
        let snippet = inputs.selectedWonderCompass
            ?? BookReferenceCatalog.relevantWonderCompassSnippet(for: day, inputs: inputs, now: now)
        let selector = inputs.selectedWonderCompassSelector ?? "local-relevance"
        let isGemmaSelected = selector == "gemma"
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        var pages: [SurfacePage] = [
            runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now),
            stepSurface(step: progress.nextStep, seed: seed, progress: progress, context: context, inputs: inputs, now: now),
            playfulMissionSurface(playfulMission, seed: seed, context: context, inputs: inputs, now: now),
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
                        "compassFamily": "wonder-compass",
                        "snippetID": snippet.id,
                        "tags": snippet.tags.joined(separator: ","),
                        "selector": selector
                    ]
                )
            )
        ]
        pages.append(contentsOf: pennySentenceMasterySurfaces(context: context, now: now))

        if progress.completedSteps.isEmpty {
            let standaloneNotice = stepSurface(step: .notice, seed: seed, progress: progress, context: context, inputs: inputs, now: now, standalone: true)
            pages.append(standaloneNotice)
            // The purest North = Notice "I wonder" card earns its own shadow sibling,
            // carrying a mono-no-aware spark from the dark shelf.
            if shadowState.isActive {
                pages.append(stepSurface(step: .notice, seed: shadowSeed, progress: progress, context: context, inputs: inputs, now: now, standalone: true, shadowVariantOf: standaloneNotice.id))
            }
        }

        if shadowState.isActive {
            pages.append(runSurface(seed: shadowSeed, progress: progress, context: context, inputs: inputs, now: now, shadowVariantOf: "\(source.id)-run-\(seed.id)"))
            pages.append(stepSurface(step: progress.nextStep, seed: shadowSeed, progress: progress, context: context, inputs: inputs, now: now, shadowVariantOf: "\(source.id)-run-\(seed.id)-\(progress.nextStep.rawValue)"))
            pages.append(playfulMissionSurface(shadowPlayfulMission, seed: shadowSeed, context: context, inputs: inputs, now: now, shadowVariantOf: "\(source.id)-playful-mission-\(playfulMission.id)-\(SurfaceCadence.slotID(for: now, hours: 2))"))
            let shadowSnippet = BookReferenceCatalog.fallbackWonderCompass.first { $0.id == "wonder-compass-shadow-wonder" }
                ?? snippet
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-\(shadowSnippet.id)",
                    type: .wonderCompass,
                    sourceID: source.id,
                    intent: .importReference,
                    renderStyle: .quoteCard,
                    score: (context.distress.isActive ? 52 : 66) + shadowState.scoreBoost,
                    reason: "Shadow Wonder is unlocked; this passage variant can help the Compass honor the worn edge.",
                    prompt: "Shadow Wonder from the Compass Book",
                    detail: shadowSnippet.prompt,
                    payload: BookPagePayload(
                        headline: "From the Wonder Compass Book: \(shadowSnippet.title)",
                        body: shadowSnippet.body,
                        metadata: [
                            "source": source.id,
                            "compassFamily": "wonder-compass",
                            "snippetID": shadowSnippet.id,
                            "shadowVariantOf": "\(source.id)-\(snippet.id)",
                            "variant": "shadow-wonder",
                            "tags": ShadowWonder.mergedTags(shadowSnippet.tags.joined(separator: ","), inputs: inputs, now: now),
                            "selector": selector
                        ]
                    )
                )
            )
        }

        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        return runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now)
    }

    /// Rebuilds the exact actionable page carried by a tapped prompt whisper.
    /// Mission text comes from the scheduled snapshot rather than today's
    /// rotating registry result, so opening the notification cannot reroll it.
    func promptWhisperSurface(
        for whisper: PromptWhisper,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        guard whisper.kind == .mission,
              whisper.id.hasPrefix("mission-") else {
            return checkInSurface(for: whisper, context: context, now: now)
        }

        let missionID = String(whisper.id.dropFirst("mission-".count))
        let registeredMission = PlayfulMissionRegistry.missions.first { $0.id == missionID }
        let mission = PlayfulMission(
            id: missionID,
            title: whisper.title,
            prompt: whisper.body,
            proofPrompt: whisper.keepPrompt,
            tags: whisper.tags,
            allowsPhoto: whisper.allowsPhoto ?? registeredMission?.allowsPhoto ?? false
        )
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        return playfulMissionSurface(
            mission,
            seed: seed,
            context: context,
            inputs: inputs,
            now: now
        )
        .withMetadata([
            "openedFromPromptWhisper": "true",
            "promptWhisperID": whisper.id
        ])
    }

    private func checkInSurface(
        for whisper: PromptWhisper,
        context: CuratorContext,
        now: Date
    ) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .souvenir)
        return SurfacePage(
            id: "prompt-whisper-\(whisper.id)-\(SurfaceCadence.slotID(for: now, hours: 2))",
            type: .souvenir,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: context.distress.isActive ? 52 : 64,
            reason: "The reader opened this exact prompt from the Book's whisper.",
            prompt: whisper.title,
            detail: whisper.body,
            payload: BookPagePayload(
                headline: whisper.title,
                body: whisper.body,
                metadata: [
                    "source": source.id,
                    "placeholder": whisper.keepPrompt,
                    "souvenirPrompt": whisper.keepPrompt,
                    "promptWhisperID": whisper.id,
                    "openedFromPromptWhisper": "true",
                    "tags": (["souvenir", "prompt-whisper", whisper.kind.rawValue] + whisper.tags)
                        .joined(separator: ",")
                ]
            )
        )
    }

    private func playfulMissionSurface(
        _ mission: PlayfulMission,
        seed: WonderCompassRunSeed,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        var metadata = metadata(for: seed, step: .sense)
        metadata["compassStep"] = "sense"
        metadata["compassMode"] = "standalone"
        metadata.removeValue(forKey: "runID")
        metadata["playfulMissionID"] = mission.id
        metadata["curatorActionCommission"] = "true"
        metadata["playfulMissionTitle"] = mission.title
        metadata["mission"] = mission.prompt
        metadata["souvenirPrompt"] = mission.proofPrompt
        metadata["placeholder"] = mission.proofPrompt
        metadata["proofKind"] = mission.allowsPhoto ? "sentence-or-photo" : "sentence"
        let tags = (seed.tags + ["compass-step:sense", "playful-mission"] + mission.tags.map { "mission:\($0)" }).joined(separator: ",")
        metadata["tags"] = isShadowVariant ? ShadowWonder.mergedTags(tags, inputs: inputs, now: now) : tags
        metadata["source"] = BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID
        metadata["symbol"] = mission.allowsPhoto ? "camera.macro" : "hand.raised"
        metadata["startingPageBelief"] = "62"
        let isNaturalPhenomenonMission = mission.tags.contains("natural-phenomenon")
        if isNaturalPhenomenonMission {
            metadata["naturalPhenomenonMission"] = "true"
        }
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        let titleLine = title.map { "\n\n\($0.name) pull: \($0.compassLine)" } ?? ""

        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")playful-mission-\(mission.id)-\(SurfaceCadence.slotID(for: now, hours: 2))",
            type: .wonderCompass,
            sourceID: BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: (context.distress.isActive ? 54 : 64) + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant
                ? "This Shadow Wonder variant lets the senses investigate the dark edge safely."
                : isNaturalPhenomenonMission
                ? "South is responding to the live sky, weather, or place around you."
                : "A playful mission can turn South into something your senses can actually do.",
            prompt: isShadowVariant ? "Shadow Playful Mission: \(mission.title)" : "Playful Mission: \(mission.title)",
            detail: title.map { "\($0.name): \(mission.prompt)" } ?? mission.prompt,
            payload: BookPagePayload(
                headline: "South = Sense",
                body: "\(mission.prompt)\n\nProof: \(mission.proofPrompt)\(mission.allowsPhoto ? " Or keep a photo." : "")\(titleLine)",
                metadata: metadata
            )
        )
    }

    private func pennySentenceMasterySurfaces(context: CuratorContext, now: Date) -> [SurfacePage] {
        let slotID = SurfaceCadence.slotID(for: now, hours: 12)
        return PennySentenceMasteryLesson.allCases.map { lesson in
            let tags = lesson.tags.joined(separator: ",")
            return SurfacePage(
                id: "\(source.id)-penny-sentence-\(lesson.rawValue)-\(slotID)",
                type: .wonderCompass,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: (context.distress.isActive ? 46 : 56) + lesson.order,
                reason: "Competence and mastery focus: Penny turns Chapter 9's West = Write practice into one learnable sentence move.",
                prompt: "Penny Blackletter: \(lesson.title)",
                detail: lesson.focusLine,
                payload: BookPagePayload(
                    headline: "How to Write Better Sentences: \(lesson.title)",
                    body: """
                    Filed by Penny Blackletter, after Chapter 9: West = Write.

                    \(lesson.pennyBriefing)

                    Practice: \(lesson.practicePrompt)
                    """,
                    metadata: [
                        "source": source.id,
                        "compassFamily": "wonder-compass",
                        "snippetID": "wonder-compass-chapter9",
                        "chapterSourceID": "wonder-compass-chapter9",
                        "pennySentenceLesson": lesson.rawValue,
                        "pennySentenceLessonOrder": "\(lesson.order)",
                        "pennySentenceLessonTitle": lesson.title,
                        "pennySentenceLessonFocus": lesson.focusLine,
                        "pennySentenceLessonHint": lesson.masteryHint,
                        "placeholder": lesson.placeholder,
                        "symbol": lesson.symbolName,
                        "tags": tags
                    ]
                )
            )
        }
    }

    private func runSurface(
        seed: WonderCompassRunSeed,
        progress: CompassRunProgress,
        context: CuratorContext,
        inputs: BookSourceInputs = .empty,
        now: Date,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let completed = progress.completedSteps.count
        let isFresh = completed == 0
        let next = progress.isComplete ? CompassRunStep.rest : progress.nextStep
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let headline = isShadowVariant
            ? (isFresh ? "Shadow Compass Run" : (progress.isComplete ? "Shadow Compass Run Complete" : "Resume Shadow Compass Run"))
            : (isFresh ? "Compass Run" : (progress.isComplete ? "Compass Run Complete" : "Resume Compass Run"))
        let detail = isFresh
            ? "A full N-E-S-W loop customized to now: constraints first, magic after."
            : "\(completed)/5 directions complete. Next: \(next.compassPoint) = \(next.title)."
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        let titleLine = title.map { "\n\n\($0.name) angle: \($0.compassLine)" } ?? ""
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
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }

        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")run-\(seed.id)",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .quoteCard,
            score: (context.distress.isActive ? 48 : (isFresh ? 60 : 62)) + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant
                ? "This Shadow Wonder variant can turn the difficult, old, or overlooked thing into a real quest."
                : progress.isComplete
                ? "The wheel has turned; the center can hold the page."
                : "The Compass can turn the current constraints into one small adventure.",
            prompt: headline,
            detail: title.map { "\($0.name): \(detail)" } ?? detail,
            payload: BookPagePayload(
                headline: headline,
                body: "\(WonderCompassRunGenerator.body(for: seed))\(titleLine)",
                metadata: metadata
            )
        )
    }

    private func stepSurface(
        step: CompassRunStep,
        seed: WonderCompassRunSeed,
        progress: CompassRunProgress,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        standalone: Bool = false,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        var metadata = metadata(for: seed, step: step)
        metadata["compassStep"] = step.rawValue
        metadata["compassMode"] = standalone ? "standalone" : "runStep"
        metadata["standalone"] = standalone ? "true" : "false"
        if standalone {
            metadata.removeValue(forKey: "runID")
        }
        if standalone, step == .notice {
            metadata["startingPageBelief"] = "62"
        }
        let pageSourceID = standalone && step == .notice
            ? BookPageSourceRegistry.wonderCompassNoticeSourceID
            : source.id
        metadata["source"] = pageSourceID
        metadata["placeholder"] = step.capturePlaceholder
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }

        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        let score = context.distress.isActive && step != .rest
            ? 50
            : (standalone ? 42 : 58 + min(step.scoreBoost, 4))

        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")\(standalone ? "solo" : "run")-\(seed.id)-\(step.rawValue)",
            type: .wonderCompass,
            sourceID: pageSourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: score + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant
                ? "This Shadow Wonder variant can start with the thing you usually look past."
                : standalone
                ? "\(step.title) can be used on its own without committing to a full run."
                : "The next Compass direction is ready.",
            prompt: "\(step.compassPoint): \(step.title)",
            detail: title.map { "\($0.name): \(step.standaloneDetail)" } ?? step.standaloneDetail,
            payload: BookPagePayload(
                headline: "\(step.compassPoint) = \(step.title)",
                body: "\(seed.body(for: step))\(title.map { "\n\n\($0.name) angle: \($0.compassLine)" } ?? "")",
                metadata: metadata
            )
        )
    }

    private func metadata(for seed: WonderCompassRunSeed, step: CompassRunStep?) -> [String: String] {
        let tags = seed.tags + (step.map { ["compass-step:\($0.rawValue)"] } ?? [])
        var metadata: [String: String] = [
            "source": source.id,
            "compassFamily": "wonder-compass",
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
            context: context,
            inputs: inputs,
            now: now
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let snippet = BookReferenceCatalog.rotatingLoreSnippet(for: day, inputs: inputs, now: now)
        var pages = [loreSurface(snippet: snippet, context: context, inputs: inputs, now: now)]
        if ShadowWonder.state(inputs: inputs, now: now).isActive {
            pages.append(
                loreSurface(
                    snippet: BookReferenceCatalog.rotatingShadowLoreSnippet(for: day, now: now),
                    context: context,
                    inputs: inputs,
                    now: now,
                    shadowVariantOf: pages[0].id
                )
            )
        }
        return pages
    }

    private func loreSurface(
        snippet: ReferenceSnippet,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        var metadata = [
            "source": source.id,
            "snippetID": snippet.id,
            "tags": isShadowVariant
                ? ShadowWonder.mergedTags(snippet.tags.joined(separator: ","), inputs: inputs, now: now)
                : snippet.tags.joined(separator: ",")
        ]
        if let practice = snippet.practice?.trimmingCharacters(in: .whitespacesAndNewlines), !practice.isEmpty {
            metadata["practice"] = practice
        }
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")\(snippet.id)",
            type: .lore,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: (context.distress.isActive ? 44 : 68) + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant ? "This Shadow Wonder lore card scoots the honest, worn edge to the front." : (context.distress.isActive ? "Lore hangs back behind the gentler pages when the day feels heavy." : "A lore card can bring the world a little closer without asking anything of you."),
            prompt: isShadowVariant ? "Shadow Lore: \(snippet.prompt)" : snippet.prompt,
            detail: snippet.title,
            payload: BookPagePayload(
                headline: snippet.title,
                body: snippet.body,
                metadata: metadata
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
            reason: "A little illustration can pop up just to be looked at, no strings attached.",
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
        // A hand-authored dossier always wins over the generated one. Only the
        // canonical Cast has bespoke prose; locations, talismans, Book Fae, and
        // any character without an entry fall through to the generator below.
        if let bespoke = CastDossier.bio(forSlug: profile.slug) {
            return bespoke
        }
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
        let selectedThreadIDs = packet.selectedThreads.map(\.id).joined(separator: ",")
        let selectedEntities = packet.selectedEntities.map(\.name).joined(separator: ", ")
        let storySetting = packet.selectedEntities.first { $0.kind == .location }
        let storySettingDetail = storySetting.map { setting in
            [
                setting.unwrittenInterest,
                setting.traits.isEmpty ? nil : "Traits: \(setting.traits.joined(separator: ", "))",
                setting.quirks.first.map { "Specific behavior: \($0)" },
                setting.goals.first.map { "Scene job: \($0)" }
            ]
            .compactMap { $0?.nonEmpty }
            .joined(separator: " ")
        } ?? ""
        let selectedRelationships = packet.selectedRelationships.map(\.id).joined(separator: ", ")
        let selectedEntityMemories = packet.selectedEntityMemories
            .map { memory in
                let entityName = NarrativePackRegistry.entities.first(where: { $0.id == memory.entityID })?.name ?? memory.entityID
                return "\(entityName): \(memory.summary)"
            }
            .joined(separator: "\n")
        let characterCanon = CharacterCanonPacket.promptSection(
            for: packet.selectedEntities,
            contextLines: packet.relationshipPressures + packet.selectedEntityMemories.map(\.summary)
        )
        let chapterTalismanMoves = packet.chapterTalismanMoves.map(\.promptLine).joined(separator: "\n")
        let chapterTalismanDeltas = packet.chapterTalismanMoves.compactMap(\.ledgerToken).joined(separator: ",")
        var metadata: [String: String] = [
            "source": source.id,
            "packetID": packet.id,
            "packID": packet.packID,
            "bookGlow": packet.bookGlow,
            "playerBelief": "\(packet.playerBelief)",
            "choiceRoles": choiceRoles,
            "storyThreadDisplayTitle": packet.playableThreadTitle,
            "storyThreadUnderlyingTitles": selectedThreads,
            "storyThreadUnderlyingIDs": selectedThreadIDs,
            "selectedThreads": selectedThreads,
            "selectedEntities": selectedEntities,
            "selectedEntityIDs": packet.selectedEntities.map(\.id).joined(separator: ","),
            "storySettingID": storySetting?.id ?? "",
            "storySettingName": storySetting?.name ?? "",
            "storySettingDetail": storySettingDetail,
            "storyFormID": packet.storyFormID ?? "",
            "storyFormName": packet.storyFormName ?? "",
            "storyBeats": (packet.storyFormBeats ?? []).joined(separator: "\n"),
            "storyGenreID": packet.storyGenreID ?? "",
            "storyGenreName": packet.storyGenreName ?? "",
            "storyGenreLens": packet.storyGenreLens ?? "",
            "storyGenreExemplar": packet.storyGenreExemplar ?? "",
            "storyGenrePalette": (packet.storyGenrePalette ?? []).joined(separator: " | "),
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
            "storyGroundingSelectionReason": packet.blueprint?.grounding.selectionReason ?? "",
            "storyGroundingSemanticSimilarity": packet.blueprint?.grounding.semanticSimilarity.map { String(format: "%.3f", $0) } ?? "",
            "storyRecipeBeats": packet.blueprint?.beats.joined(separator: "\n") ?? "",
            "storyRecipeGroundingDirective": packet.blueprint?.groundingDirective ?? "",
            "storyRecipeToneDirective": packet.blueprint?.toneDirective ?? "",
            "storyRecipeChoiceDirective": packet.blueprint?.choiceDirective ?? "",
            "storyRecipeContinuationDirective": packet.blueprint?.continuationDirective ?? "",
            "storyQuillDirective": inputs.chosenQuill.map(QuillChoosing.storyDirective(for:)) ?? "",
            "selectedThreadIDs": selectedThreadIDs,
            "selectedRelationships": selectedRelationships,
            "entityMemories": selectedEntityMemories,
            CharacterCanonPacket.metadataKey: characterCanon,
            "realSignals": packet.realSignals.joined(separator: "\n"),
            "relationshipPressures": packet.relationshipPressures.joined(separator: "\n"),
            "chapterTalismanMoves": chapterTalismanMoves,
            "chapterTalismanDeltas": chapterTalismanDeltas,
            "uses": "characters, locations, belief, relationship graph, story threads",
            "cadence": "four-hour simulation"
        ]
        if let grounding = packet.blueprint?.grounding, grounding.kind == .keptPage {
            metadata["tags"] = [
                metadata["tags"],
                MeaningfulPassageSelector.storyUsedTag,
                "\(MeaningfulPassageSelector.legacyStorySourceTagPrefix)\(grounding.sourceID)",
                "\(MeaningfulPassageSelector.sourceTagPrefix)\(grounding.sourceID)",
                "meaningful-source-use:story"
            ]
            .compactMap { $0?.nonEmpty }
            .joined(separator: ",")
        }
        if packet.blueprint?.recipeID == "souvenir-door",
           let grounding = packet.blueprint?.grounding {
            let sparkSentence = grounding.text
                .replacingOccurrences(of: "Story Spark from One-Sentence Souvenir: ", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            metadata["storySparkSourcePageID"] = grounding.sourceID
            metadata["storySparkSentence"] = sparkSentence
            metadata["tags"] = [
                metadata["tags"],
                "story-spark",
                "story-spark-source:\(grounding.sourceID)",
                "story-spark-recipe",
                "souvenir-door"
            ]
            .compactMap { $0?.nonEmpty }
            .joined(separator: ",")
        }
        metadata.merge(mechanicMandate.metadata) { _, new in new }
        if let turn = packet.turn {
            metadata.merge(turn.metadata) { _, new in new }
        }
        let isStorySpark = packet.blueprint?.recipeID == "souvenir-door"
        return SurfacePage(
            id: "\(source.id)-\(packet.id)",
            type: .narrativeOS,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: day.capturedPages.count >= 2 ? 86 : 68,
            reason: isStorySpark
                ? "One sentence you kept has a whole little door hiding inside it."
                : "The story is wide awake now, and the characters are itching to do something.",
            prompt: isStorySpark ? "Want this little sentence to open a door?" : "A Story Page is waking up and rubbing its eyes.",
            detail: packet.turn.map { "\($0.character) wants \($0.want); \($0.obstacle)." } ?? packet.directorIntent,
            payload: BookPagePayload(
                headline: packet.title,
                body: isStorySpark
                    ? "The Book keeps leaning over one sentence you kept. Its first lines are still a little damp in the corners."
                    : "A page is quietly gathering itself around something you can play with today. The deeper stuff is still hiding under the floorboards, giggling.",
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
        let company = PeopleOfTheBook.knowledgeGraph(ledger: inputs.people, days: inputs.days + [day]).atlasGraph
        var pages: [SurfacePage] = []
        if !loom.nodes.isEmpty && !loom.edges.isEmpty {
            pages.append(surface(variant: .loom, graph: loom, day: day, now: now, score: 44 + min(14, loom.edges.count)))
        }
        if constellation.nodes.count > 1 {
            pages.append(surface(variant: .constellation, graph: constellation, day: day, now: now, score: 46 + min(14, constellation.edges.count * 2)))
        }
        if company.nodes.count > 1 && !company.edges.isEmpty {
            pages.append(surface(variant: .company, graph: company, day: day, now: now, score: 48 + min(14, company.edges.count)))
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
            prompt: "The Atlas is still hunting for enough ink.",
            detail: "Keep some pages, nudge your Belief around, and let the story leave a few more tracks to follow.",
            payload: BookPagePayload(
                headline: "The Margins Atlas",
                body: "The page is waiting for your people, your Belief, and your attention to leave enough little footprints to trace.",
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
            reason: {
                switch variant {
                case .loom: return "The cast left threads all over the place, and now you can see them."
                case .constellation: return "Belief drew a little star map in the margins."
                case .company: return "The real people in the reader's life have begun to form a constellation of their own."
                }
            }(),
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
                    "tags": "margins-atlas,\(variant.rawValue),graph\(variant == .company ? ",people-of-the-book,life-knowledge" : "")"
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

    /// The whole illustration-facing cast: bundled characters, bundled
    /// locations, and the reader's custom cast, so places can earn pages by
    /// Belief and narrative weight without becoming speaking characters.
    private func castPool(inputs: BookSourceInputs) -> [(entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)] {
        let bundled = NarrativePackRegistry.entities
            .filter { $0.kind == .character || $0.kind == .location }
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
        let stronglyBelieved = usable.filter { (offsets[$0.entity.id] ?? 0) >= 50 }
        if let strongest = stronglyBelieved.sorted(by: { left, right in
            let leftOffset = offsets[left.entity.id] ?? 0
            let rightOffset = offsets[right.entity.id] ?? 0
            if leftOffset != rightOffset { return leftOffset > rightOffset }
            let leftBelief = effectiveBelief(left.entity, offsets)
            let rightBelief = effectiveBelief(right.entity, offsets)
            if leftBelief != rightBelief { return leftBelief > rightBelief }
            if left.entity.narrativeWeight != right.entity.narrativeWeight {
                return left.entity.narrativeWeight > right.entity.narrativeWeight
            }
            return left.entity.id < right.entity.id
        }).first {
            return strongest
        }
        let slot = manual ? "\(Int(now.timeIntervalSince1970))-\(UUID().uuidString)" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let scored = usable
            .map { item -> (item: (entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?), score: Int) in
                let jitter = stableIndex(for: "\(item.entity.id)-\(slot)", count: 18)
                let score = item.entity.narrativeWeight + effectiveBelief(item.entity, offsets) / 2 + jitter
                return (item, score)
            }
            .sorted { $0.item.entity.id < $1.item.entity.id }
        return StableWeightedRoll.pick(
            from: scored,
            seed: "\(slot)-cast-illustration-entity",
            weight: { $0.score }
        )?.item
    }

    private func surface(for entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?, context: CuratorContext, offsets: [String: Int], now: Date, manual: Bool) -> SurfacePage {
        let meaning = entity.unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let description = entity.quirks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let belief = effectiveBelief(entity, offsets)
        let isLocation = entity.kind == .location
        let isCustom = entity.packID == "user-cast"
        var metadata = [
            "source": source.id,
            "illustrationKind": isLocation ? "location" : "cast",
            "entityID": entity.id,
            "entityName": entity.name,
            "entityKind": entity.kind.rawValue,
            "meaning": meaning,
            "description": description,
            "tags": (entity.tags + ["entity:\(entity.id)", isCustom ? "custom-cast" : (isLocation ? "bundled-location" : "bundled-cast")]).joined(separator: ","),
            "traits": entity.traits.joined(separator: ","),
            "privacy": "private local cast"
        ]
        if let imageAsset {
            metadata["imageAssetKind"] = imageAsset.kind.rawValue
            metadata["imageAssetReference"] = imageAsset.reference
        }
        // A bundled cast member with real dossier art should show that full
        // illustration in the body and shelf preview — not just the medallion
        // in the header. When a matching illustration profile exists we also
        // hand the page that profile's richer, character-specific prose so the
        // card reads like a dossier instead of a filled-in form.
        let profile = imageAsset == nil ? CharacterPortrait.profile(forName: entity.name) : nil
        if let profile, let bundledAsset = CharacterPortrait.bundledAssetName(forName: entity.name) {
            metadata["assetName"] = bundledAsset
            metadata["characterID"] = profile.id
            metadata["characterSlug"] = profile.slug
        }
        let body = profile.map(LabyrinthIllustrationPageSourceAdapter.bookPageBody(for:))
            ?? Self.castBody(for: entity, description: description, meaning: meaning)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return SurfacePage(
            id: "\(source.id)-cast-\(entity.id)-\(slotID)",
            type: .illustration,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 44 : min(70, 42 + belief / 3 + entity.narrativeWeight / 5),
            reason: "\(entity.name) has enough Belief now to tiptoe right into the margins.",
            prompt: entity.name,
            detail: profile.map(LabyrinthIllustrationPageSourceAdapter.bookDetail(for:))
                ?? (meaning.isEmpty ? (isLocation ? "A place in the Book's living world." : "A member of the Book's cast.") : meaning),
            payload: BookPagePayload(
                headline: entity.name,
                body: body.isEmpty ? "\(entity.name) is part of the Book's living world." : body,
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

        let openings = entity.kind == .location
            ? [
                "Here is where \(name) has begun to matter.",
                "\(name) has gathered enough Belief to become more than backdrop.",
                "Let me hand you my map-notes on \(name).",
                "\(name) earns the page. This is why."
            ]
            : [
                "Here is what I have kept on \(name).",
                "\(name) has stepped far enough into the margins for me to take a proper reading.",
                "Let me hand you my notes on \(name).",
                "\(name) earns the page. This is why."
            ]
        lines.append(openings[stableIndex(for: "cast-open-\(entity.id)", count: openings.count)])

        if !entity.traits.isEmpty {
            lines.append(entity.kind == .location
                ? "What the room gives first is \(oxfordList(entity.traits))."
                : "What shows first is \(oxfordList(entity.traits)).")
        }
        if !description.isEmpty {
            lines.append(finishSentence(description))
        }
        if let belief = entity.beliefs.first(where: { !$0.trimmed.isEmpty }) {
            lines.append(entity.kind == .location
                ? "The place keeps insisting that \(lowerFirst(belief.strippedClause))."
                : "They hold that \(lowerFirst(belief.strippedClause)).")
        }
        if !meaning.isEmpty {
            lines.append(entity.kind == .location
                ? "Lately its doors keep circling back to \(lowerFirst(meaning.strippedClause))."
                : "Lately they keep circling back to \(lowerFirst(meaning.strippedClause)).")
        }
        if let goal = entity.goals.first(where: { !$0.trimmed.isEmpty }) {
            lines.append(entity.kind == .location
                ? "Its job in the story field is to \(lowerFirst(goal.strippedClause))."
                : "What they are reaching for is \(lowerFirst(goal.strippedClause)).")
        }
        if let fault = entity.faults.first(where: { !$0.trimmed.isEmpty }) {
            lines.append(entity.kind == .location
                ? "The risk I keep one eye on: \(lowerFirst(fault.strippedClause))."
                : "The flaw I keep one eye on: \(lowerFirst(fault.strippedClause)).")
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
            reason: "You haven't made your own cast member yet.",
            prompt: "No custom cast member yet.",
            detail: "Spend a little Belief to add one first.",
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
                reason: "Where you are can change the story without the Book ever spying on you.",
                prompt: "What place is the Book standing in with you?",
                detail: "A place can turn into a page without ever turning into a report on you.",
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
            reason: "Anchors it already knows can open little local rooms when your device gets close enough.",
            prompt: "Check nearby Anchors",
            detail: "The Book can peek at your location just once and listen for an Outer Stacks door.",
            payload: BookPagePayload(
                headline: "Outer Stacks",
                body: "No Anchor is glowing yet. Chat with the Book about nearby places; if a known Anchor is within two hundred meters, its room can rise as a page.",
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
            reason: "The local brain is all set up now, so the Book can think properly again!",
            prompt: "The Book Thinks Again",
            detail: "The Labyrinth can feel its mind coming back, and it's so happy.",
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
    /// A step is done when the reader engaged with its card — opened it or
    /// deliberately swiped it away — never merely because the desk served it
    /// once. Served-history advancement let a few quick desk rebuilds (right
    /// after the local brain finished downloading, say) burn through steps
    /// nobody read, and full curation overrode the rest of the onboarding.
    private static func engaged(_ key: String, inputs: BookSourceInputs) -> Bool {
        inputs.firstRunEngagedKeys.contains(key)
    }

    static func surfaces(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage]? {
        let welcomeAdapter = LabyrinthWelcomePageSourceAdapter()
        let welcome = welcomeAdapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        let welcomeShown = engaged("source:\(welcome.sourceID)", inputs: inputs)

        guard welcomeShown else {
            return [welcome]
        }

        let originAdapter = FirstDoorOriginPageSourceAdapter()
        let origin = originAdapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        let originShown = engaged(origin.varietyKey, inputs: inputs)
        if !originShown, FirstDoorReaderProfile.from(inputs) != nil {
            return [origin]
        }

        // The local brain remains optional, but its First Door introduction must
        // actually get a turn before the ordinary desk arrives. Once the reader
        // opens or dismisses this one ceremonial card, the deterministic feed can
        // flow and the install becomes the quiet rider below.
        guard inputs.localBrainIsReady else {
            let setup = localBrainSetupSurface(
                playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs)
            )
            return engaged("source:\(setup.sourceID)", inputs: inputs) ? nil : [setup]
        }

        let brainAdapter = LocalBrainAwakePageSourceAdapter()
        let brain = brainAdapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        let brainShown = engaged("source:\(brain.sourceID)", inputs: inputs)

        guard brainShown else {
            return [brain]
        }

        if !engaged("source:\(enchantmentIntroSourceID)", inputs: inputs),
           !day.pages.contains(where: { $0.tags.contains("first-run-enchantment-intro") }) {
            return [enchantmentIntroSurface(for: day, context: context, inputs: inputs, now: now)]
        }

        let calendarAdapter = CalendarPageSourceAdapter()
        let calendarDoor = calendarAdapter.previewSurface(for: day)
        let calendarDoorShown = engaged(calendarDoor.varietyKey, inputs: inputs)
        if !inputs.calendarIntegrationEnabled, !calendarDoorShown {
            return [calendarDoor]
        }

        if shouldSurfaceCompassRunAfterBrain(inputs: inputs, day: day, now: now) {
            return [compassRunIntroSurface(for: day, context: context, inputs: inputs, now: now)]
        }

        guard !engaged("source:\(firstMissionSourceID)", inputs: inputs),
              !day.pages.contains(where: { $0.tags.contains("first-run-mission") }) else {
            return nil
        }
        return [firstMissionSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs))]
    }

    /// Every active First Door beat is a deliberate single-page ceremony. It
    /// owns Pages Rising until the reader opens or dismisses it; ordinary cards
    /// cannot bury the introduction beneath a busier desk. Completed Welcome and
    /// Brain cards still do not follow later steps around the desk.
    static func mergingCurrentStep(
        _ firstRun: [SurfacePage]?,
        into feed: [SurfacePage],
        limit: Int
    ) -> [SurfacePage] {
        guard limit > 0, let current = firstRun?.last else {
            return Array(feed.prefix(max(0, limit)))
        }
        return [current]
    }

    /// Every engagement key the first-run script consults, in step order.
    /// Doubles as the one-time migration vocabulary: readers who already had
    /// a step *served* under the old advancement rule are treated as engaged,
    /// so nobody replays onboarding they have already lived past.
    static var stepEngagementKeys: [String] {
        [
            "source:\(BookPageSourceRegistry.source(for: .welcome).id)",
            "first-door-origin",
            "source:\(localBrainSetupSourceID)",
            "source:local-brain-awake",
            "source:\(enchantmentIntroSourceID)",
            "source:\(BookPageSourceRegistry.source(for: .calendar).id)",
            "source:\(compassRunIntroSourceID)",
            "source:\(firstMissionSourceID)"
        ]
    }

    static func seededEngagementKeys(fromServedHistory history: [String: SurfaceHistoryRecord]) -> [String] {
        stepEngagementKeys.filter { history[$0] != nil }
    }

    static let firstMissionSourceID = "first-run-mission"
    static let localBrainSetupSourceID = "first-run-local-brain-setup"
    static let enchantmentIntroSourceID = "first-run-enchantment-intro"
    static let compassRunIntroSourceID = "first-run-compass-run"
    static let compassRunDelayAfterBrain: TimeInterval = 30 * 60
    static let compassRunWindowAfterBrain: TimeInterval = 8 * 3600

    private static func localBrainSetupSurface(playerName: String?) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(localBrainSetupSourceID)-gemma",
            type: .helpTips,
            sourceID: localBrainSetupSourceID,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 40,
            reason: "An optional upgrade: install the Book's private little brain whenever you like, to deepen the hand it writes in.",
            prompt: "Optional: Wake the Local Brain",
            detail: "Deepen the Book's private mind on this device whenever you like — the everyday Pages are already flowing.",
            payload: BookPagePayload(
                headline: "Wake the Mind in the Margins",
                body: """
                Your Pages are already turning up, \(name) — this is how to make them richer.

                The Labyrinth writes fine on its own, but with a private mind that lives entirely on this device it does better: it reads your kept Pages with more care, writes in a warmer hand, and turns loose scraps into story. Nothing leaves the device.

                Tap Download the private mind, right here on this page, and I'll fetch the local Gemma brain while you carry on. It's a real download, so give it a moment — the everyday Pages keep coming either way. (The same install lives in the Colophon at the foot of the home screen, if you'd rather do it there.)

                I'll keep offering this until it's done, because it matters. Once the mind is awake, this card rests for good.
                """,
                metadata: [
                    "source": localBrainSetupSourceID,
                    "firstRunStep": "local-brain-setup",
                    "playerName": name,
                    "privacy": "private local",
                    "symbol": "brain.head.profile",
                    "tags": "help-tips,first-run,local-brain,gemma,colophon,setup,onboarding"
                ]
            )
        )
    }

    /// The local-brain install, offered as a rider beside the ordinary feed once
    /// the First Door greeting has been shown. The private mind is integral to the
    /// product, so this keeps surfacing every build until Gemma is actually
    /// installed — it only falls silent once the brain is ready (or before the
    /// welcome has been seen, so it never crowds the first greeting).
    static func pendingLocalBrainUpgrade(inputs: BookSourceInputs) -> SurfacePage? {
        guard !inputs.localBrainIsReady else { return nil }
        guard engaged(
            "source:\(BookPageSourceRegistry.source(for: .welcome).id)",
            inputs: inputs
        ) else { return nil }
        return localBrainSetupSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs))
    }

    /// Slots an optional rider (e.g. the local-brain upgrade) into the last
    /// visible position of the ordinary feed so real Pages always lead. No-ops
    /// if the rider is absent or already present in the feed.
    static func mergingUpgradeRider(_ rider: SurfacePage?, into feed: [SurfacePage], limit: Int) -> [SurfacePage] {
        guard let rider else { return feed }
        guard !feed.contains(where: { $0.sourceID == rider.sourceID }) else { return feed }
        let lead = Array(feed.prefix(max(0, limit - 1)))
        return lead + [rider]
    }

    private static func firstMissionSurface(playerName: String?) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(firstMissionSourceID)-first-waking",
            type: .helpTips,
            sourceID: firstMissionSourceID,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 99,
            reason: "The Book has said hi and woken up its brain, and now it wants to send you off with one small first mission.",
            prompt: "The First Door: Your First Mission",
            detail: "A tiny, playful errand to take out into your real day.",
            payload: BookPagePayload(
                headline: "A Small Mission, Should You Accept It",
                body: """
                The Book says you're properly furnished now, \(name) — a name, a working mind, the lot. So it asked who should hand you your first mission, and I volunteered before it finished the sentence. Pippa Pilcrow. I set punctuation loose for a living. You'll hear the others complain about me soon enough.

                The mission. Small. Deniable. Entirely yours:

                Sometime today, catch the Book one thing from the real world it could not have guessed — a sound through a wall, the exact wrong colour of the sky, a stranger's good sentence, a smell that opened a door in your head. You don't have to write it down this second. Just go looking, on purpose, with the Book in your pocket.

                Three things worth knowing while you're out:

                • Keep the Pages with a pulse, and let the rest go back to sleep. A Book that hoards everything is only a heavy drawer.
                • The four marks at the foot of the desk — Body, Weather, Location, Radio — are doors, not decorations. Tap one when you want a Page to surface from where you actually are.
                • Glow is belief made visible. Spend it on the people and ideas you want the Book to take seriously, and it will.

                When you bring your catch back, I'll be in the margin waiting for it. First one there gets to write the note.

                — Pippa, of the margins

                (P.S. The full stop on this letter has tried to escape twice already. I admire that in a punctuation mark.)
                """,
                metadata: [
                    "source": firstMissionSourceID,
                    "firstRunStep": "first-mission",
                    "playerName": name,
                    "privacy": "public reference",
                    "symbol": "scope",
                    "portraitAsset": "LabyrinthCharacterPilcrow",
                    "tags": "help-tips,first-run,first-run-mission,mission,labyrinth"
                ]
            )
        )
    }

    private static func enchantmentIntroSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let base = EnchantmentPageSourceAdapter().manualSurface(for: day, context: context, inputs: inputs, now: now)
        var metadata = base.payload.metadata
        metadata["source"] = enchantmentIntroSourceID
        metadata["firstRunStep"] = "enchantment-intro"
        metadata["firstRunEnchantmentIntro"] = "true"
        metadata["tags"] = "\(metadata["tags"] ?? "enchantment"),first-run,first-run-enchantment-intro,onboarding,local-brain-ready"
        return SurfacePage(
            id: "\(enchantmentIntroSourceID)-\(BookDay.id(for: now))",
            type: base.type,
            sourceID: enchantmentIntroSourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: 98,
            reason: "The local brain is wide awake now, so Enchantments can turn a real photo into private little bits of magic.",
            prompt: "The First Door: Cast an Enchantment",
            detail: "Pick or snap one plain photo and let the Book light up the magic that's already hiding in it.",
            payload: BookPagePayload(
                headline: "Cast an Enchantment",
                body: """
                The Book has its private mind back. That means a photo can be more than a picture now.

                Choose or take one ordinary image — a mug, a shelf, a pet, a doorway, a plate, the light on the floor. An Enchantment reads the real subject locally, then writes what it notices into the margins.

                Start small. The spell works best when the thing is true.
                """,
                metadata: metadata
            )
        )
    }

    private static func shouldSurfaceCompassRunAfterBrain(inputs: BookSourceInputs, day: BookDay, now: Date) -> Bool {
        guard !engaged("source:\(compassRunIntroSourceID)", inputs: inputs) else { return false }
        guard !day.pages.contains(where: { $0.tags.contains("first-run-compass-run") || $0.tags.contains("wonder-compass-run") }) else { return false }
        // The offer window is anchored to when the brain card was *served*:
        // it is a time-of-day beat ("right after the brain woke"), so the
        // served clock is the honest one even though step advancement is not.
        guard let brainShownAt = inputs.surfaceHistory["source:local-brain-awake"]?.lastShownAt else { return false }
        let elapsed = now.timeIntervalSince(brainShownAt)
        return elapsed >= compassRunDelayAfterBrain && elapsed <= compassRunWindowAfterBrain
    }

    private static func compassRunIntroSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let base = WonderCompassPageSourceAdapter().manualSurface(for: day, context: context, inputs: inputs, now: now)
        var metadata = base.payload.metadata
        metadata["source"] = compassRunIntroSourceID
        metadata["firstRunStep"] = "compass-run"
        metadata["firstRunCompassRun"] = "true"
        metadata["tags"] = "\(metadata["tags"] ?? "wonder-compass"),first-run,first-run-compass-run,onboarding,local-brain-ready"
        return SurfacePage(
            id: "\(compassRunIntroSourceID)-\(BookDay.id(for: now))",
            type: base.type,
            sourceID: compassRunIntroSourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: 97,
            reason: "Right after the local brain wakes up is the perfect time to try a whole Compass Run.",
            prompt: "The First Door: Compass Run",
            detail: "Do Notice, Embark, Sense, Write, and Rest as one little real-world loop.",
            payload: BookPagePayload(
                headline: "Take the Compass Out",
                body: base.payload.body,
                metadata: metadata
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
                reason: "The Book can open its own Stacks now — kept Pages, weather, places, Fuel and Inner Weather charts, lore, and the threads between them.",
                prompt: "Chat with the Book",
                detail: "Ask naturally—even for a count or a pattern. The Book will search what it is allowed to remember and show which records helped it answer.",
                payload: BookPagePayload(
                    headline: "Chat with the Book",
                    body: "Ask about a person, place, old Page, story thread, feeling, weather, Fuel Log, Inner Weather entry, piece of lore, or something that may have changed over time. The Book can count recorded days and compare dated notes without pretending that a pattern proves a cause. It will leave the records it consulted beneath its answer.",
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

        // A fresh proposal sits on the desk first — opening it is what accepts it.
        if let offered = state.bargains.first(where: { $0.status == .offered }) {
            return [page(for: offered, status: .offered, now: now, claim: state.claim(for: offered.faeKind), court: state.literaryElfCourt())]
        }
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
        let isOffer = status == .offered
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
        } else if isOffer {
            body = """
            \(scene)

            The \(bargain.faeKind.name) is holding \(bargain.giftName) out across the page — offered, not yet given. It would do this: \(bargain.giftEffectLine)

            \(giftUseLine)

            Open this page to take the gift; the noticing it asks for becomes yours: \(bargain.terms). Leave it unopened and the Fae simply draw the offer back — nothing owed, nothing spent.

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
                : (isOffer
                    ? "The \(bargain.faeKind.name) is holding a gift out. Open the page to accept the bargain — or swipe it away, untaken."
                    : "The \(bargain.faeKind.name) gave first. A sensory return is owed — \(deadlineLine)."),
            prompt: isRepair ? "A Wild Exchange" : (isOffer ? "A Fae Offer" : "A Fae Bargain"),
            detail: isRepair
                ? "Repair it with a real noticing. The consequence becomes part of the story."
                : bargain.terms,
            payload: BookPagePayload(
                headline: isRepair ? "The Bargain Went Wild" : (isOffer ? "A Fae Offer" : "A Fae Bargain"),
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
                        "storyGenreExemplar": "\"You kept a morning I wanted,\" the visitor said, turning a page it could not touch. \"Name your price for it.\" Its courtesy was exact, the way frost is exact. \"And do be precise. The last reader traded loosely, and we are collecting still.\"",
                        "storyGenrePalette": "exact wording | a page it cannot touch | frost | the price of a kept morning | thorn | gift with an edge | old law | a debt of attention",
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
        let baseMetadata: [String: String] = [
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

        var pages = [
            SurfacePage(
                id: "\(source.id)-\(slot)",
                type: .todaysSky,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70 + (reading.nextEvent.daysAway == 0 ? 8 : 0) + (reading.activeShower == nil ? 0 : 6),
                reason: "Tonight: \(reading.moon.name) in \(reading.moonSign.name). \(reading.nextEvent.name) \(reading.nextEvent.line).",
                prompt: "Today's Sky",
                detail: "Keep one true little sentence about the sky tonight.",
                payload: BookPagePayload(
                    headline: "Today's Sky",
                    body: body,
                    metadata: baseMetadata
                )
            )
        ]
        // Shadow Wonder: the same almanac read as the Unseelie's sky — the dark
        // and waning moon, the between-hours, the dark that the stars need to show.
        let shadow = ShadowWonder.state(inputs: inputs, now: now)
        if shadow.isActive {
            let isDarkMoon = reading.moon.illuminatedFraction <= 0.5
            var metadata = baseMetadata
            metadata["accent"] = "violet"
            metadata["placeholder"] = "Keep the dark sky in one true sentence..."
            metadata["shadowVariantOf"] = "\(source.id)-\(slot)"
            metadata["variant"] = "shadow-wonder"
            metadata["tags"] = ShadowWonder.mergedTags(baseMetadata["tags"] ?? "", inputs: inputs, now: now, extra: ["dark-moon", "between-hours"])
            let shadowOpening = isDarkMoon
                ? "The moon keeps its own counsel tonight — \(reading.moon.name), barely lit. The old craft calls the dark moon a time for rest and secrets, not for starting things."
                : "Even at \(reading.moon.name), the sky tonight belongs to the between-hours. The dark is not the absence of the sky; it is what lets the sky be seen at all."
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-\(slot)",
                    type: .todaysSky,
                    sourceID: source.id,
                    intent: .reflect,
                    renderStyle: .loreLetter,
                    score: 70 + (reading.nextEvent.daysAway == 0 ? 8 : 0) + (reading.activeShower == nil ? 0 : 6) + shadow.scoreBoost,
                    reason: "Shadow Wonder reads the Unseelie's sky: \(reading.moon.name) in \(reading.moonSign.name), and the dark that lets the stars show.",
                    prompt: "Tonight's Dark Sky",
                    detail: "Keep one true little sentence about the dark sky — the quiet moon, the cold, the in-between hour.",
                    payload: BookPagePayload(
                        headline: "Today's Sky",
                        body: "\(shadowOpening)\n\n" + reading.notes.joined(separator: "\n\n"),
                        metadata: metadata
                    )
                )
            )
        }
        return pages
    }
}

// Surfaces "The Two Readings": two cast members, chosen dynamically, who read the
// reader's recent pages differently. The preview is local; tapping it generates
// the disagreement prose. Distress-gated, once per day.
struct TwoReadingsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .twoReadings)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        // Hold back until the library has enough kept pages to argue over.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        // Only when one a day, and only with something worth arguing about.
        guard !day.pages.contains(where: { $0.type == .twoReadings }) else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"].map({ now.timeIntervalSince($0.lastShownAt) >= 18 * 3600 }) ?? true else {
            return []
        }

        // Anchor the disagreement on ONE real kept page — preferably one the
        // reader wrote themselves — so the cast argues about something concrete,
        // not a vague "what your week is saying". Skip pages already argued over
        // by either The Two Readings or The Reading.
        let used = Self.usedPageIDs(in: inputs.days + [day])
        let allPages = (inputs.days.flatMap(\.capturedPages) + day.capturedPages)
            .sorted { $0.createdAt > $1.createdAt }
            .filter { !used.contains($0.id) && !$0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let anchor = allPages.first(where: { $0.origin == .userAuthored }) ?? allPages.first else {
            return []
        }

        // Pair selection is biased toward the anchor page so the two voices have
        // a real stake in this particular entry.
        let evidenceText = "\(anchor.userInput) \(anchor.tags.joined(separator: " "))"
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
        let characterCanon = CharacterCanonPacket.promptSection(
            for: entities.filter { $0.id == pair.aID || $0.id == pair.bID },
            contextLines: [pair.relationshipNote].compactMap { $0 }
        )
        let clipped = PactReadings.clip(anchor.userInput)
        let authoredNote = anchor.origin == .userAuthored ? "the page you wrote" : "one of your kept pages"
        return [
            SurfacePage(
                id: "\(source.id)-\(pair.pairKey)-\(anchor.id)",
                type: .twoReadings,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: 76,
                reason: "\(pair.aName) and \(pair.bName) are reading \(authoredNote) differently.",
                prompt: "The Two Readings",
                detail: "\(pair.aName) and \(pair.bName) read \(authoredNote) — \(clipped) — and disagree about it. Open it; you decide.",
                payload: BookPagePayload(
                    headline: "The Two Readings",
                    body: "\(pair.aName) and \(pair.bName) both stopped on the same page of yours — \(clipped) — and came back with different readings. The Book won't settle it for you.",
                    metadata: [
                        "source": source.id,
                        "pairID": pair.pairKey,
                        "entityAID": pair.aID,
                        "entityBID": pair.bID,
                        "entityAName": pair.aName,
                        "entityBName": pair.bName,
                        "entityAProfile": aProfile,
                        "entityBProfile": bProfile,
                        CharacterCanonPacket.metadataKey: characterCanon,
                        "relationshipNote": pair.relationshipNote ?? "",
                        "anchorPageID": anchor.id,
                        "anchorPageText": anchor.userInput,
                        "anchorPageAuthored": anchor.origin == .userAuthored ? "1" : "0",
                        "tags": "two-readings,entity:\(pair.aID),entity:\(pair.bID),two-readings:\(anchor.id)"
                    ]
                )
            )
        ]
    }

    /// Page ids already argued over by The Two Readings (`two-readings:<id>`) or
    /// The Reading (`pact-verdict:<id>`), so the two pages never collide.
    static func usedPageIDs(in days: [BookDay]) -> Set<String> {
        var ids = Set<String>()
        for day in days {
            for page in day.pages {
                for tag in page.tags {
                    if tag.hasPrefix("two-readings:") {
                        ids.insert(String(tag.dropFirst("two-readings:".count)))
                    } else if tag.hasPrefix("pact-verdict:") {
                        ids.insert(String(tag.dropFirst("pact-verdict:".count)))
                    }
                }
            }
        }
        return ids
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

// Surfaces "The Reading": two rival Talismans read one of the reader's real kept
// pages through opposite philosophies, and the reader rules. The matchup and the
// territory at stake are dictated by the live Pact War state. Static prose, no
// model call; distress-gated, once per ~18h, and never re-asks a page already ruled.
struct PactVerdictPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .pactVerdict)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard !day.pages.contains(where: { $0.type == .pactVerdict }) else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"].map({ now.timeIntervalSince($0.lastShownAt) >= 18 * 3600 }) ?? true else {
            return []
        }

        // Pick the most recent kept page a shelf governs and that hasn't been
        // ruled here or already argued over by The Two Readings.
        let ruled = ruledPageIDs(in: inputs.days + [day])
            .union(TwoReadingsPageSourceAdapter.usedPageIDs(in: inputs.days + [day]))
        let candidate = (inputs.days.flatMap(\.capturedPages) + day.capturedPages)
            .sorted { $0.createdAt > $1.createdAt }
            .first { !ruled.contains($0.id) && PactTerritoryRegistry.shelf(governing: $0.type) != nil }
        guard let page = candidate,
              let shelf = PactTerritoryRegistry.shelf(governing: page.type) else { return [] }

        // The matchup is dictated by the real territory: its controller (or the
        // first Talisman aligned to the shelf) vs. a different Talisman that wants it.
        let aligned = AcademyChapterRegistry.chapters.map(\.talismanID)
            .filter { PactWarEngine.isAligned($0, shelf.id) }
        let talismanA = inputs.pactWar.controller(of: shelf.id)
            ?? aligned.first
            ?? AcademyChapterRegistry.chapters[0].talismanID
        let talismanB = pickChallenger(against: talismanA, shelf: shelf, aligned: aligned, state: inputs.pactWar)
        guard talismanA != talismanB else { return [] }

        let nameA = AcademyChapterRegistry.chapter(forTalismanID: talismanA)?.talismanName ?? "A Talisman"
        let nameB = AcademyChapterRegistry.chapter(forTalismanID: talismanB)?.talismanName ?? "A Talisman"
        let readingA = PactReadings.reading(talismanID: talismanA, pageText: page.userInput)
        let readingB = PactReadings.reading(talismanID: talismanB, pageText: page.userInput)

        let body = """
        Two Talismans have stopped on the same page of your life — \(PactReadings.clip(page.userInput)) — and they cannot agree on what it was.

        \(nameA): \(readingA)

        \(nameB): \(readingB)

        The Book won't settle it. You were there. Rule for the reading that's true, and \(shelf.name) shifts toward it.
        """

        return [
            SurfacePage(
                id: "\(source.id)-\(page.id)",
                type: .pactVerdict,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 79,
                reason: "\(nameA) and \(nameB) are fighting over what one of your real days meant.",
                prompt: "The Pact War Report",
                detail: "\(nameA) and \(nameB) read the same kept page differently. You rule — and \(shelf.name) moves.",
                payload: BookPagePayload(
                    headline: "The Pact War Report",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "pageID": page.id,
                        "territoryID": shelf.id,
                        "territoryName": shelf.name,
                        "talismanA": talismanA,
                        "talismanB": talismanB,
                        "talismanAName": nameA,
                        "talismanBName": nameB,
                        "readingA": readingA,
                        "readingB": readingB,
                        "tags": "pact-verdict,pact-war,pact-verdict:\(page.id)"
                    ]
                )
            )
        ]
    }

    /// Page ids already ruled (or kept) — tagged `pact-verdict:<pageID>`.
    private func ruledPageIDs(in days: [BookDay]) -> Set<String> {
        var ids = Set<String>()
        for day in days {
            for page in day.pages {
                for tag in page.tags where tag.hasPrefix("pact-verdict:") {
                    ids.insert(String(tag.dropFirst("pact-verdict:".count)))
                }
            }
        }
        return ids
    }

    /// A different Talisman that wants this shelf: the strongest aligned rival to
    /// the holder, else the strongest non-holder by control, else any other.
    private func pickChallenger(against holder: String, shelf: PactTerritory, aligned: [String], state: PactWarState) -> String {
        let rivalsAligned = aligned.filter { $0 != holder }
        if let best = rivalsAligned.max(by: { state.control($0, shelf.id) < state.control($1, shelf.id) }) {
            return best
        }
        let others = AcademyChapterRegistry.chapters.map(\.talismanID).filter { $0 != holder }
        return others.max(by: { state.control($0, shelf.id) < state.control($1, shelf.id) }) ?? holder
    }
}

// Surfaces "A Talisman's Errand": a talisman that holds a foothold sends the reader
// into the real day, paid in a field report. Mirrors the Fae Bargain's surfacing —
// one open errand at a time, distress-gated.
struct PactErrandPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .pactErrand)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard let errand = inputs.pactWar.openErrand else { return [] }
        return [page(for: errand, now: now)]
    }

    private func page(for errand: PactErrand, now: Date) -> SurfacePage {
        let chapter = AcademyChapterRegistry.chapter(forTalismanID: errand.talismanID)
        let name = chapter?.talismanName ?? "A Talisman"
        let territory = PactTerritoryRegistry.territory(id: errand.territoryID)
        let hoursLeft = max(0, Int(errand.deadline.timeIntervalSince(now) / 3_600))
        let deadlineLine = hoursLeft >= 24
            ? "about \(hoursLeft / 24) day\(hoursLeft / 24 == 1 ? "" : "s") to run it"
            : (hoursLeft > 0 ? "about \(hoursLeft) hour\(hoursLeft == 1 ? "" : "s") to run it" : "the errand is due now")
        let body = """
        \(errand.openingLine)

        \(name) already holds \(territory?.name ?? "ground in the war") and wants more — but not by simulation. It wants you to go and do something in the real day.

        The errand: \(errand.terms)

        You have \(deadlineLine). Bring back a true field report, and \(name) gains \(territory?.name ?? "its territory") — the noticing you did becomes its ground.\(chapter.map { "\n\n\($0.name)'s doctrine: \($0.philosophy)" } ?? "")
        """
        return SurfacePage(
            id: "\(source.id)-\(errand.id)",
            type: .pactErrand,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 77,
            reason: "\(name) has set you an errand in the real day.",
            prompt: "A Talisman's Errand",
            detail: errand.terms,
            payload: BookPagePayload(
                headline: "A Talisman's Errand",
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                metadata: [
                    "source": source.id,
                    "errandID": errand.id,
                    "talismanID": errand.talismanID,
                    "talismanName": name,
                    "territoryID": errand.territoryID,
                    "territoryName": territory?.name ?? "",
                    "terms": errand.terms,
                    "openingLine": errand.openingLine,
                    "tags": "pact-errand,pact-war"
                ]
            )
        )
    }
}

struct CastBondPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .castBond)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        // The Loom only changes the web once the reader has kept enough to move it.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
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
        .map { surface(for: $0, entities: entities, now: now) }
    }

    private func firedKeys(in days: [BookDay]) -> Set<String> {
        Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix("cast-bond:") ? String(tag.dropFirst("cast-bond:".count)) : nil
        })
    }

    private func surface(for bond: CastBond, entities: [NarrativeWorldEntity], now: Date) -> SurfacePage {
        let isRivalry = bond.kind == .rivalry
        let title = isRivalry ? "A Rivalry Erupts" : "An Alliance Forms"
        let kind = bond.kind.rawValue
        let verb = isRivalry ? "tightened until it sparked" : "warmed until it answered"
        let body = """
        The Book has been keeping count of the threads in the margins.

        \(bond.aName) and \(bond.bName) have crossed a living threshold: the thread between them \(verb).

        Something between them is strong enough now to step out of the background and act. Open it.
        """
        let characterCanon = CharacterCanonPacket.promptSection(
            for: entities.filter { $0.id == bond.aID || $0.id == bond.bID },
            contextLines: [
                "\(bond.aName) and \(bond.bName) have crossed a \(bond.kind.rawValue) threshold at intensity \(bond.intensity)."
            ]
        )

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
                    CharacterCanonPacket.metadataKey: characterCanon,
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
            Your Glow has reached the top of the wick. It is bright enough to wake Story Pages, carry Letters through the stacks, unfold Notes, or call a Fae Parley into fuller ink.

            You can also give it directly to a cast member, page type, spell, or living thread you want the Book to treat as more real. Attention kept in motion becomes story.
            """
            : """
            Your Glow is radiant enough to steer the Book on purpose.

            Spend it when a fiction door asks to open, give it to a cast member you want closer, or warm a page type you want more often.
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
                    ? "Your Glow is so full it's spilling over and wants somewhere to go."
                    : "Your Glow is bright enough now to spend on purpose.",
                prompt: isTooFull ? "Your Glow Is Too Full" : "Your Glow Wants a Direction",
                detail: "Wake fiction when it calls, or open the Glow menu and hand Belief to something you'd like more of.",
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

/// Calls the reader to the Bindery at the turn of a month, once the month just
/// past holds enough bound-worthy pages to earn a cover. It is a nudge, not a
/// page to keep: tapping it opens the BookShop's Bindery shelf (via the same
/// `opensBookShop` route the BookShop preview uses), where the actual binding,
/// sharing, and — later — physical printing live. Swiping it away costs nothing,
/// and it returns at most once per month.
/// Surfaces the reader's most recently completed week as a keepable *issue* —
/// the fast retention beat ("your week became an issue") that the deferred
/// monthly/annual bindings can't give. It shares the `.bindery` page family but
/// carries its own source so it never touches the monthly Bindery's once-per-
/// month history. Distress-gated; each issue is offered once and retired when
/// kept (tag `weekly-issue:<n>`).
struct WeeklyIssuePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "weekly-issue", fallbackType: .bindery)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard let issue = WeeklyIssue.current(days: inputs.days, today: day, now: now) else { return [] }

        // Each issue is offered once; keeping it retires that number forever.
        let keptTag = "weekly-issue:\(issue.number)"
        let alreadyKept = (inputs.days + [day]).flatMap(\.pages).contains { $0.tags.contains(keptTag) }
        guard !alreadyKept else { return [] }

        let issueLabel = "Issue No. \(issue.number)"
        let pageWord = issue.keptCount == 1 ? "page" : "pages"
        let headline = issue.isFirstIssue ? "Your First Issue" : "This Week Became an Issue"
        let issueDays = Self.issueDays(from: inputs.days + [day], issue: issue)
        let memory = BindingMemorySpine.digest(days: issueDays, now: issue.endDate, limit: 7)
        let coverStory = memory.braids.first.map { "\($0.residue.title) - \($0.residue.callbackCandidate ?? $0.residue.keptLine)" }
        let refrain = memory.motifCounts.prefix(4).map(\.motif).joined(separator: ", ").nonEmpty
        let opener = issue.isFirstIssue
            ? "Seven days ago you opened the Book for the first time. The week looked up, surprised to have pages, and I tried to hold it carefully."
            : "Another seven days have closed. The week came in with its pockets full, and I gathered what was still warm while you were busy living it."
        let highlightBlock = issue.highlights.isEmpty
            ? ""
            : "\n\n" + issue.highlights.map { "\u{2022} \($0)" }.joined(separator: "\n")
        let memoryBlock = Self.memoryBlock(coverStory: coverStory, refrain: refrain, memory: memory)
        let setAside = issue.setAsideLine.map { "\n\n\($0)" } ?? ""
        let scrapbook = Self.scrapbookLine(for: issue).map { "\n\n\($0)" } ?? ""
        let body = """
        \(issueLabel) \u{2014} \(issue.dateRange)

        \(opener) \(issue.keptCount) \(pageWord) you kept, gathered into a week you can hold.\(memoryBlock)\(highlightBlock)\(scrapbook)\(setAside)

        The month and the year are still gathering their coats. This week is already whole — keep the issue, and I will shelve it where it can hum to itself.

        Made with ReEnchanted · reenchanted.app
        """

        // The first issue is a milestone retention beat, scored a touch higher;
        // later issues stay solid but below orientation and distress/rest.
        let score = issue.isFirstIssue ? 82 : 74
        return [
            SurfacePage(
                id: "\(source.id)-\(issue.number)",
                type: .bindery,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: issue.isFirstIssue ? "Your first week became an issue." : "Your week became an issue.",
                prompt: issueLabel,
                detail: "\(issue.keptCount) \(pageWord) from \(issue.dateRange), gathered into an issue.",
                payload: BookPagePayload(
                    headline: headline,
                    body: body,
                    metadata: [
                        "source": source.id,
                        "weeklyIssue": "true",
                        "weeklyIssueNumber": "\(issue.number)",
                        "weeklyIssueRange": issue.dateRange,
                        "weeklyIssueKeptCount": "\(issue.keptCount)",
                        "weeklyIssueHighlights": issue.highlights.joined(separator: "\n"),
                        "weeklyIssueCoverStory": coverStory ?? "",
                        "weeklyIssueRefrain": refrain ?? "",
                        "weeklyIssueMemoryCallbacks": memory.braids.prefix(4).map { $0.residue.callbackCandidate ?? $0.residue.keptLine }.joined(separator: "\n"),
                        "weeklyIssueScrapbookCount": "\(issue.scrapbookCount)",
                        "weeklyIssueScrapbookTitles": issue.scrapbookTitles.joined(separator: "\n"),
                        "weeklyIssueFirst": issue.isFirstIssue ? "true" : "false",
                        "publicSeal": "Made with ReEnchanted · reenchanted.app",
                        "noBeliefReward": "true",
                        "tags": "weekly-issue,edition,\(keptTag),bindery"
                    ]
                )
            )
        ]
    }

    private static func issueDays(from days: [BookDay], issue: WeeklyIssue) -> [BookDay] {
        days.filter { day in
            day.date >= Calendar.current.startOfDay(for: issue.startDate)
                && day.date < Calendar.current.startOfDay(for: issue.endDate)
        }
    }

    private static func scrapbookLine(for issue: WeeklyIssue) -> String? {
        guard issue.scrapbookCount > 0 else { return nil }
        let noun = issue.scrapbookCount == 1 ? "scrapbook page" : "scrapbook pages"
        let titleLine = issue.scrapbookTitles.isEmpty ? "" : " I tucked in \(issue.scrapbookTitles.joined(separator: "; "))."
        return "I also kept \(issue.scrapbookCount) \(noun) you composed by hand.\(titleLine)"
    }

    private static func memoryBlock(coverStory: String?, refrain: String?, memory: BindingMemoryDigest) -> String {
        guard coverStory != nil || refrain != nil || !memory.braids.isEmpty else { return "" }
        let cover = coverStory.map { "\n\nCover story: \($0)" } ?? ""
        let refrainLine = refrain.map { "\nThe week's refrain: \($0). It came back tapping." } ?? ""
        let oldPage = memory.braids.dropFirst().first?.residue.callbackCandidate.map {
            "\nAn older page answered from its shelf: \($0)."
        } ?? ""
        let watching = memory.braids.first?.residue.openedQuestion.map {
            "\nWhat I am watching with both page-corners raised: \($0)"
        } ?? ""
        return cover + refrainLine + oldPage + watching
    }
}

struct BinderyPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bindery)

    /// How many days into a fresh month we still call the reader to the bindery
    /// for the month just past, while it is still warm.
    private let bindingWindowDays = 8
    /// A month must offer at least this many bound-worthy pages (after the
    /// EditionCurator samples the mundane logs) to be worth a cover. This also
    /// doubles as a maturity gate: a brand-new library has nothing to bind.
    private let minimumBoundPages = 3

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let calendar = Calendar.current

        // Only early in a fresh month, while the month just past is complete.
        guard calendar.component(.day, from: now) <= bindingWindowDays else { return [] }

        // Once per month — don't call twice in the same window.
        let lastShown = inputs.surfaceHistory["source:\(source.id)"]?.lastShownAt ?? .distantPast
        if lastShown != .distantPast,
           calendar.isDate(lastShown, equalTo: now, toGranularity: .month) {
            return []
        }

        guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else {
            return []
        }

        // Gather last month's pages and curate them exactly as the binder would,
        // so the count we promise matches the chapter the reader will get.
        let lastMonthPages = (inputs.days + [day])
            .filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
            .flatMap(\.pages)
        guard !lastMonthPages.isEmpty else { return [] }

        let curated = EditionCurator.curate(lastMonthPages, now: now)
        guard curated.keptCount >= minimumBoundPages else { return [] }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: lastMonthStart)
        let pageWord = curated.keptCount == 1 ? "page" : "pages"

        var detail = "\(monthName) is complete — \(curated.keptCount) \(pageWord) ready to be sewn into a chapter."
        if let setAside = curated.setAsideLine {
            detail += " \(setAside)"
        }

        return [
            SurfacePage(
                id: "\(source.id)-\(calendar.component(.year, from: lastMonthStart))-\(calendar.component(.month, from: lastMonthStart))",
                type: .bindery,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 72,
                reason: "Last month is ready to bind.",
                prompt: "The Bindery Is Open",
                detail: detail,
                payload: BookPagePayload(
                    headline: "\(monthName) Wants a Cover",
                    body: """
                    The leaves of \(monthName) have stopped turning. \(curated.keptCount) \(pageWord) stand ready to be sewn between covers — yours to keep, to share, or to send out for a real cloth binding.

                    Step into the Bindery and decide how \(monthName) should be remembered.
                    """,
                    metadata: [
                        "source": source.id,
                        "opensBookShop": "true",
                        "binderyShelf": "true",
                        "binderyMonthName": monthName,
                        "binderyPageCount": "\(curated.keptCount)",
                        "noBeliefReward": "true",
                        "symbol": source.symbolName,
                        "tags": "bindery,binding,edition,monthly-chapter"
                    ]
                )
            )
        ]
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
    static let systemEntries: [HelpTipEntry] = [
        HelpTipEntry(
            id: "first-five-minutes",
            title: "First Five Minutes",
            prompt: "Start small, keep whatever tugs at you, and let the Book learn.",
            body: """
            Use the app like a living notebook, not a dashboard.

            1. Keep one small thing that feels alive. A Journal Page, Inner Weather note, Fuel Log, photo, or Souvenir all count.
            2. Don't wait for a grand moment. The Book's strongest when you feed it ordinary evidence.
            3. Open one rising page and answer only what feels finishable.
            4. If a page feels wrong today, dismiss it. Dismissed pages rest and may return later.
            5. Use the Glow menu when you want to steer what appears more often.

            Good first moves:
            - Keep the Page that tugs.
            - Add a photo, body note, weather note, or small detail when it helps.
            - Let dull Pages go quietly. The Book learns from that too.

            The trick: one kept page changes the day more than ten unopened perfect plans.
            """,
            tags: ["help", "onboarding", "basics", "keep-page"]
        ),
        HelpTipEntry(
            id: "glow-menu",
            title: "Using Glow",
            prompt: "Tune the Book by giving it, or taking back, a little Belief.",
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
            prompt: "Let the world wander around, then keep the pages that should really count.",
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
            prompt: "Use the compass directions as tiny little real-world moves.",
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
            prompt: "Turn real photos into little glowing bits of proof.",
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
            prompt: "Use care pages as gentle context, never as a telling-off.",
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
            prompt: "Ask the archive for pages, cast, memories, and little references.",
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
            prompt: "Let real places turn into little rooms once they've earned it.",
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
            prompt: "You get to pick what kinds of pages the Book brings you.",
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
            prompt: "Know which pages are private, made-up, brought in, or a bit sensitive.",
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
            prompt: "Reach for the tiniest page that makes things feel easier.",
            body: """
            If the app feels like too much, shrink the move.

            Try one of these:
            - Keep an Inner Weather word.
            - Write one ordinary sentence.
            - Dismiss three pages without guilt.
            - Open Chat with the Book and ask, "What is the smallest useful next step?"
            - Take a Center Page.
            - Keep a photo without explaining it.
            - Run one Playful Mission badly on purpose.

            The Book isn't grading you. It's trying to keep you company while attention returns.

            Tip: a page can be useful even if it isn't beautiful. Especially then.
            """,
            tags: ["help", "stuck", "rest", "small"]
        )
    ]

    /// One small way to alter the texture of ordinary life. These are tips,
    /// not assignments: each surfaced page carries exactly one enchantment and
    /// leaves the reader free to adopt it, adapt it, or merely enjoy the idea.
    static let everydayEnchantmentEntries: [HelpTipEntry] = [
        enchantment(
            "wonder-ringtone", "Give Your Phone a Better Voice",
            "Replace one default ringtone with a sound that makes interruption feel less like an alarm.",
            "Default ringtones make every caller sound like a minor emergency. Choose one sound with a different emotional shape: a soft bell, rain on a window, three piano notes, a frog, a train arriving, or a tiny recording from somewhere you love.\n\nOne changed sound is enough. The magic is deciding what gets to enter your day sounding like itself.",
            ["sound", "phone", "ritual"]
        ),
        enchantment(
            "wonder-alarm-name", "Rename One Alarm",
            "Turn one alarm label into a message from the version of you who set it.",
            "An alarm named “7:30” is a noise with paperwork. Give one alarm a line that changes the moment it arrives: “The kettle chapter,” “Shoes, keys, tiny courage,” or “Tomorrow asked nicely.”\n\nKeep the time exactly the same. You aren't optimizing the morning; you're letting your past self speak with better manners.",
            ["time", "phone", "words"]
        ),
        enchantment(
            "wonder-wallpaper-door", "Put a Door on the Screen",
            "Use a photo from your real life as a phone wallpaper that opens attention instead of demanding it.",
            "Choose a photograph of a doorway, path, window, tree, strange shadow, or ordinary place you want to keep seeing. It doesn't need to be beautiful. It needs to contain somewhere your eyes can enter.\n\nThe screen already gets hundreds of glances. Give some of those glances a place to go.",
            ["phone", "photo", "attention", "door"]
        ),
        enchantment(
            "wonder-device-name", "Give the Machine a True Name",
            "Rename one device according to its actual temperament.",
            "The printer isn't “OfficeJet 4520” if it jams whenever company is coming. The speaker isn't “Living Room” if it only cooperates with jazz. Give one device a name earned from evidence.\n\nA true name can be affectionate, dramatic, or mildly prosecutorial. Afterward, every connection menu becomes a tiny piece of household lore.",
            ["technology", "naming", "home"]
        ),
        enchantment(
            "wonder-portal-playlist", "Choose Portal Music",
            "Give one repeated transition its own short piece of music.",
            "Pick a song for leaving work, beginning dinner, starting the drive home, opening the curtains, or putting the room to bed. Use the same one often enough that the first notes become a threshold.\n\nThe song doesn't describe the moment. It teaches your body that one world is ending and another is beginning.",
            ["sound", "music", "threshold", "ritual"]
        ),
        enchantment(
            "wonder-object-personality", "Notice Who the Object Is",
            "Personify one object you use every day, but make its personality answer to evidence.",
            "Choose the kettle, car, favorite pen, stubborn drawer, old coat, or lamp. Watch how it behaves. Is it patient, theatrical, fussy, loyal, overqualified, always cold?\n\nYou don't have to pretend it's alive. Just stop pretending it has no character. Familiar things become visible again when they are allowed a point of view.",
            ["object", "imagination", "attention"]
        ),
        enchantment(
            "wonder-household-guardian", "Appoint a Household Guardian",
            "Choose one ordinary object to guard a small part of the day.",
            "A key bowl can guard departures. A lamp can guard the reading hour. A chipped mug can guard slow mornings. Pick one object already doing the work and make the appointment official.\n\nNothing supernatural has to happen. The guardian's job is to remind you what this little territory is for.",
            ["object", "home", "protection", "ritual"]
        ),
        enchantment(
            "wonder-room-title", "Give the Room a Secret Title",
            "Name one familiar place for what happens there, not what the floor plan calls it.",
            "The hallway might be The Sock Migration. The porch might be The Weather Office. One end of the couch might be The Recovery Wing.\n\nKeep the title private or tell the household. Either way, the room stops being generic and starts holding a particular kind of life.",
            ["place", "home", "naming", "words"]
        ),
        enchantment(
            "wonder-museum-label", "Write One Museum Label",
            "Give one meaningful ordinary object the label a museum would write after you were famous.",
            "Name the object, the approximate year, the material, and why it survived. Keep it to two or three lines. A taped measuring cup and a concert wristband deserve the same grave curatorial respect.\n\nYou may never display the label. Writing it is enough to notice that your life already has artifacts.",
            ["object", "memory", "writing", "museum"]
        ),
        enchantment(
            "wonder-good-spoon", "Declare the Good Spoon",
            "Choose the best spoon in the drawer and stop acting as if all spoons are equal.",
            "You already know which one balances correctly, fits the bowl, and doesn't have the regrettable edge. Give it a title and use it deliberately for something small.\n\nPreference is a form of attention. The kingdom can survive one openly favored spoon.",
            ["object", "food", "home", "preference"]
        ),
        enchantment(
            "wonder-victory-cup", "Keep a Cup for Tiny Victories",
            "Choose one cup or glass that only comes out when an ordinary thing deserves marking.",
            "Use it when the difficult call is over, the laundry is folded, the walk happened, the form was sent, or the day simply remained survivable. The drink can be water.\n\nCeremony doesn't require grandeur. It requires one object behaving differently because the moment counted.",
            ["object", "ritual", "celebration", "home"]
        ),
        enchantment(
            "wonder-departure-ritual", "Make Leaving a Threshold",
            "Choose one tiny action that means you have truly left one place for another.",
            "Touch the doorframe, straighten one object, say “house held,” ring a small bell, or take one deliberate breath after the latch clicks. Use the same action whenever it helps.\n\nThe ritual shouldn't delay you. It gives the crossing an edge, so your body doesn't have to drag the whole previous room along.",
            ["threshold", "ritual", "home", "body"]
        ),
        enchantment(
            "wonder-dusk-lamp", "Appoint a Dusk Lamp",
            "Let one lamp mark the moment the day becomes evening.",
            "Choose a lamp with warm light and turn it on at dusk before the larger room lights, whenever you happen to notice the change. If flame suits you, a safely placed candle or battery candle can do the same job.\n\nThe lamp isn't for brightness. It's the household noticing that the sky changed shifts.",
            ["light", "dusk", "home", "ritual"]
        ),
        enchantment(
            "wonder-window-weather", "Keep a Weather Window",
            "Choose one window as the place where you check what the day is actually doing.",
            "Before accepting the forecast's summary, look through that window for ten seconds. Notice the nearest moving thing, the color of the light, and whether the glass feels like a boundary or an invitation.\n\nYou don't need a weather practice. You need one reliable place where weather is allowed to be more than data.",
            ["weather", "window", "attention", "place"]
        ),
        enchantment(
            "wonder-scent-key", "Choose a Scent Key",
            "Pair one safe, familiar scent with a kind of moment you want to enter more easily.",
            "It might be orange peel while beginning the evening, rosemary before writing, a particular tea while reading, or hand lotion at the end of work. Choose something your body already welcomes; skip fragrance if scent is difficult for you.\n\nRepeated gently, the scent becomes a key your nervous system recognizes before language arrives.",
            ["scent", "body", "ritual", "care"]
        ),
        enchantment(
            "wonder-secret-costume", "Wear One Secret Costume Piece",
            "Add one private, slightly ridiculous detail to an otherwise ordinary outfit.",
            "Constellation socks, a bright lining, a tiny pin, a serious ring with an unserious meaning, or a color nobody else can see all count. It doesn't need to attract attention.\n\nThe point is to know that beneath the day's dress code, you dressed for a more interesting story.",
            ["clothing", "play", "color", "private"]
        ),
        enchantment(
            "wonder-ring-spell", "Give a Ring One Sentence",
            "Attach a short intention to a ring, bracelet, watch, or other thing you already touch.",
            "Choose a sentence small enough to remain true: “Look once more,” “Stay on my own side,” “Soft hands,” or “This hour is real.” Remember it whenever your fingers find the object.\n\nThe jewelry doesn't make the sentence true. It keeps you from forgetting which truth you meant to practice.",
            ["object", "body", "words", "talisman"]
        ),
        enchantment(
            "wonder-pocket-talisman", "Carry an Unimportant Talisman",
            "Put one small, safe, almost worthless object in your pocket and let it represent the day.",
            "A smooth stone, washer, bead, acorn cap, foreign coin, button, or folded scrap will do. Choose it for texture or private logic, not monetary value.\n\nTouch it once when the day goes strange. At night, decide whether its service is finished or whether it earned another day.",
            ["object", "touch", "talisman", "pocket"]
        ),
        enchantment(
            "wonder-future-note", "Hide a Note for Future You",
            "Leave one kind or funny sentence where a later version of you will find it naturally.",
            "Put it in a coat pocket, suitcase, book, glove compartment, seasonal box, or the back of a drawer. Don't make it advice. Make it company.\n\nA good note says, “You found the pocket,” “Still excellent taste in coats,” or one true thing this future person may need returned.",
            ["writing", "time", "kindness", "memory"]
        ),
        enchantment(
            "wonder-seasonal-shelf", "Keep a One-Shelf Season",
            "Let one tiny surface change as the real season changes.",
            "Use a windowsill, saucer, corner of a shelf, or small tray. Hold only a few found or ordinary things: a leaf, stone, seedpod, postcard, ribbon, shell, or color that belongs to now.\n\nThis isn't decorating the whole house. It's giving time one visible place to leave its coat.",
            ["season", "home", "nature", "time"]
        ),
        enchantment(
            "wonder-route-landmarks", "Name the Landmarks on Your Route",
            "Give private names to three things on a route you travel often.",
            "The tree leaning over the road, the suspicious mailbox, the excellent puddle, and the corner where the light changes can become real landmarks. Use names based on what you actually notice.\n\nThe route hasn't changed. It has acquired chapters, which is often enough to make repetition visible again.",
            ["place", "route", "naming", "attention"]
        ),
        enchantment(
            "wonder-urban-familiar", "Choose an Urban Familiar",
            "Adopt one recurring nonhuman neighbor as a character in the local story.",
            "Choose a crow, pigeon, squirrel, street tree, delivery robot, bus, or impossible weed you see more than once. Don't invent a bond it hasn't offered. Learn its habits instead.\n\nA familiar begins as recognition: there you are again, doing your strange little work beside mine.",
            ["creature", "place", "attention", "character"]
        ),
        enchantment(
            "wonder-chore-ceremony", "Give One Chore an Opening Ceremony",
            "Start one recurring chore with the same tiny flourish every time.",
            "Roll up your sleeves with absurd seriousness, play one opening song, announce the first dish, light the laundry beacon, or salute the vacuum. Keep the flourish shorter than the chore.\n\nThe ceremony doesn't make work disappear. It turns “I should” into “the scene has begun.”",
            ["home", "ritual", "work", "play"]
        ),
        enchantment(
            "wonder-water-glass", "Let Water Wear Formal Clothes",
            "Drink ordinary water from a vessel usually saved for something more important.",
            "Use the beautiful glass, tiny cup, inherited tumbler, silver-rimmed thing, or ridiculous straw on a day with no guests and no occasion. Notice whether the water acquires posture.\n\nUseful things don't have to wait for a worthy future. Being alive and thirsty is already an occasion.",
            ["water", "object", "care", "celebration"]
        ),
        enchantment(
            "wonder-visible-mend", "Let One Repair Be Beautiful",
            "When a safe, repairable object needs mending, consider making the repair visible on purpose.",
            "Use contrasting thread, a handsome patch, colored tape, a marked date, or one careful line that admits where the break happened. Choose only a repair you can make safely; structural and electrical repairs still belong to experts.\n\nA visible mend lets the object keep both truths: it broke, and someone chose it again.",
            ["repair", "object", "care", "craft"]
        ),
        enchantment(
            "wonder-plant-title", "Give the Plant a Job Title",
            "Assign one plant a household role based on what it already does.",
            "The windowsill pothos may be Director of Reaching. The herb pot may be Minister of Supper. The determined weed outside may be Boundary Counsel.\n\nThe title is a joke with an attention hook inside it. Once appointed, the plant becomes harder to pass without seeing.",
            ["plant", "home", "naming", "attention"]
        ),
        enchantment(
            "wonder-house-holiday", "Invent a Tiny Household Holiday",
            "Give one recurring ordinary event a name and one modest tradition.",
            "The first open-window evening, the return of a favorite seasonal snack, changing the sheets, or the day the hallway gets its sunlight can become an annual or monthly observance. One food, song, toast, or photograph is plenty.\n\nA holiday is just attention that remembered to come back.",
            ["home", "ritual", "calendar", "celebration"]
        ),
        enchantment(
            "wonder-good-chair", "Make the Good Chair Official",
            "Decide which seat is the best seat for one particular kind of moment.",
            "Not the best chair in general: the rain-watching chair, phone-call step, shoe-tying edge, late-night reading corner, or place where hard news is allowed to land. Name its jurisdiction.\n\nA place becomes easier to enter when it knows what it is for.",
            ["home", "place", "rest", "naming"]
        ),
        enchantment(
            "wonder-sound-postcard", "Keep a Sound Postcard",
            "Record ten seconds of a place you want to remember without narrating over it.",
            "Capture the kitchen before guests arrive, rain in the parking lot, a train platform, summer insects, the washing machine in an old apartment, or the quiet after snow. Respect other people's privacy and avoid recording conversations.\n\nName the file with the place and date. Later, it won't sound like audio. It'll sound like a door.",
            ["sound", "memory", "place", "phone"]
        ),
        enchantment(
            "wonder-wifi-name", "Name the Invisible Weather",
            "Give your Wi-Fi network a name that makes the invisible household atmosphere more interesting.",
            "Choose something welcoming, local, and safe to show nearby strangers: “The Lantern Window,” “Moths Welcome,” “Third-Floor Weather,” or a private piece of neighborhood lore. Don't put personal information in it.\n\nThe signal was already passing through the walls. A name simply lets it knock with character.",
            ["technology", "home", "naming", "weather"]
        ),
        enchantment(
            "wonder-house-word", "Invent One Household Word",
            "Name a recurring experience your household understands but ordinary language has neglected.",
            "It might be the cold patch by the stairs, the silence after the dishwasher stops, the pile that is clean but not put away, or the exact light that means someone will soon say “Should we eat?”\n\nUse the word again. Private vocabulary turns repeated life from background noise into shared folklore.",
            ["words", "home", "naming", "folklore"]
        )
    ]

    static let entries: [HelpTipEntry] = systemEntries + everydayEnchantmentEntries

    static func entry(for day: BookDay, now: Date, manual: Bool = false) -> HelpTipEntry {
        let slot = SurfaceCadence.slotID(for: now, hours: manual ? 1 : 6)
        let key = "\(day.id)-help-tips-\(slot)-\(manual)"
        // Keep practical app guidance alive while letting the larger everyday-
        // enchantment shelf take two of every three deterministic lanes.
        let pool = stableIndex(for: "\(key)-lane", count: 3) == 0
            ? systemEntries
            : everydayEnchantmentEntries
        let index = stableIndex(for: key, count: pool.count)
        return pool[index]
    }

    private static func enchantment(
        _ id: String,
        _ title: String,
        _ prompt: String,
        _ body: String,
        _ tags: [String]
    ) -> HelpTipEntry {
        HelpTipEntry(
            id: id,
            title: title,
            prompt: prompt,
            body: body,
            tags: ["help", "everyday-enchantment", "wonder-filled", "magic"] + tags
        )
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
            detail: "Nothing strange is happening in the world's rules right now.",
            payload: BookPagePayload(
                headline: "The Almanac Is Quiet",
                body: "The Book peeks at the almanac, the margins, and the weather living in the grammar, and finds nothing out there tugging its sleeve for fieldwork today.",
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
            "event-mode:\(event.activationMode.rawValue)",
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
                    "worldEventMode": event.activationMode.rawValue,
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

struct QuotePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .quotes)

    private static let lines: [(quote: String, author: String)] = [
        ("The universe is full of magical things patiently waiting for our wits to grow sharper.", "Eden Phillpotts"),
        ("To see a World in a Grain of Sand and a Heaven in a Wild Flower.", "William Blake"),
        ("The question is not what you look at, but what you see.", "Henry David Thoreau"),
        ("There are always flowers for those who want to see them.", "Henri Matisse"),
        ("Adopt the pace of nature: her secret is patience.", "Ralph Waldo Emerson"),
        ("Nothing is worth more than this day.", "Johann Wolfgang von Goethe")
    ]

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let index = abs("quote:\(day.id):\(slot)".stableHash) % Self.lines.count
        let line = Self.lines[index]
        return [SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)",
            type: .quotes,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 48 : 61,
            reason: "A borrowed line can sharpen the eye without telling the reader what to feel.",
            prompt: "A line to keep, if it catches.",
            detail: "\(line.quote) — \(line.author)",
            payload: BookPagePayload(
                headline: "A Quote to Keep",
                body: "“\(line.quote)”\n\n— \(line.author)",
                metadata: [
                    "source": source.id,
                    "quoteAuthor": line.author,
                    "tags": "quote,attention,wonder"
                ]
            )
        )]
    }
}

struct PublicMarginsCreatorPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "public-margins-creators", fallbackType: .quotes)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let snapshot = inputs.publicMargins,
              !snapshot.creatorPosts.isEmpty else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)
        let index = abs("public-creator:\(day.id):\(slot)".stableHash) % snapshot.creatorPosts.count
        let post = snapshot.creatorPosts[index]
        let handle = post.authorUsername.hasPrefix("@") ? post.authorUsername : "@\(post.authorUsername)"
        return [SurfacePage(
            id: "\(source.id)-\(post.id)",
            type: .quotes,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 34 : 57,
            reason: "A reviewed public voice noticed something worth looking at twice.",
            prompt: "Elsewhere, someone noticed.",
            detail: post.text,
            payload: BookPagePayload(
                headline: "Elsewhere, Someone Noticed",
                body: "\(post.text)\n\n— \(post.authorName) (\(handle))\n\(post.createdAt)",
                metadata: [
                    "source": source.id,
                    "url": post.permalink,
                    "platform": "x",
                    "xPostID": post.id,
                    "xAuthorName": post.authorName,
                    "xAuthorUsername": handle,
                    "xCreatedAt": post.createdAt,
                    "tags": "public-margins,creator,attention,wonder"
                ]
            )
        )]
    }
}

struct PublicMarginsCommunityPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "public-margins-community", fallbackType: .quotes)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, let snapshot = inputs.publicMargins else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)

        if !snapshot.souvenirs.isEmpty {
            let index = abs("public-souvenir:\(day.id):\(slot)".stableHash) % snapshot.souvenirs.count
            let souvenir = snapshot.souvenirs[index]
            return [SurfacePage(
                id: "\(source.id)-\(souvenir.id)",
                type: .quotes,
                sourceID: source.id,
                intent: .importReference,
                renderStyle: .quoteCard,
                score: context.distress.isActive ? 38 : 55,
                reason: "Someone deliberately left one small sentence in the communal margin.",
                prompt: "A sentence left in the margin.",
                detail: souvenir.text,
                payload: BookPagePayload(
                    headline: "From the Public Margins",
                    body: "“\(souvenir.text)”\n\n— offered anonymously by a reader",
                    metadata: [
                        "source": source.id,
                        "publicContributionID": souvenir.id,
                        "tags": "public-margins,community,souvenir"
                    ]
                )
            )]
        }

        // Social-platform broadcasts are deliberately not a Book source. The
        // compatibility field may still decode from older snapshots, but the
        // app only admits moderated reader souvenirs through this doorway.
        return []
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
        PlainPageSourceAdapter(),
        SouvenirPageSourceAdapter(),
        BookOfYouPageSourceAdapter(),
        BookRememberedPageSourceAdapter(),
        BookConnectionsPageSourceAdapter(),
        FirstReadingPageSourceAdapter(),
        QuillChoosingPageSourceAdapter(),
        BookAsksPageSourceAdapter(),
        OvernightConnectionPageSourceAdapter(),
        BookNoticesPageSourceAdapter(),
        QuillChoosingPageSourceAdapter(),
        BookPocketPageSourceAdapter(),
        TheBleedPageSourceAdapter(),
        AskTheBookPageSourceAdapter(),
        BodyPageSourceAdapter(),
        FuelLogPageSourceAdapter(),
        FacultyResearchPageSourceAdapter(),
        StudentNotePageSourceAdapter(),
        CharacterLetterPageSourceAdapter(),
        SupportGuildPageSourceAdapter(),
        InkrestOfficeHoursPageSourceAdapter(),
        FaeBargainPageSourceAdapter(),
        BookFaePageSourceAdapter(),
        PactDispatchPageSourceAdapter(),
        PactVerdictPageSourceAdapter(),
        PactErrandPageSourceAdapter(),
        FestivalPageSourceAdapter(),
        TodaysSkyPageSourceAdapter(),
        RadioPageSourceAdapter(),
        BookJumpPageSourceAdapter(),
        TwoReadingsPageSourceAdapter(),
        CastBondPageSourceAdapter(),
        GlowInvitationPageSourceAdapter(),
        WeeklyIssuePageSourceAdapter(),
        BinderyPageSourceAdapter(),
        WeatherPageSourceAdapter(),
        EnchantmentPageSourceAdapter(),
        LabyrinthWelcomePageSourceAdapter(),
        FirstDoorOriginPageSourceAdapter(),
        LocalBrainAwakePageSourceAdapter(),
        FirstDoorApprenticeshipPageSourceAdapter(),
        AcademyClassPageSourceAdapter(),
        ElectivePageSourceAdapter(),
        GamePageSourceAdapter(),
        WordNegotiationPageSourceAdapter(),
        PackPageSourceAdapter(),
        CalendarPageSourceAdapter(),
        PublicMarginsCommunityPageSourceAdapter(),
        QuotePageSourceAdapter(),
        QuipPageSourceAdapter(),
        QuotesPageSourceAdapter(),
        AffirmationsPageSourceAdapter(),
        AboutYouPageSourceAdapter(),
        TarotPageSourceAdapter(),
        WonderCompassPageSourceAdapter(),
        EnchantifyLorePageSourceAdapter(),
        HelpTipsPageSourceAdapter(),
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

/// A small authored rhythm for a Sentence Runner outing. These are not difficulty
/// gates: each gives the same reader-owned words a different physical cadence.
enum SentenceRunnerRunShape: String, CaseIterable, Equatable {
    case lowRoad
    case staircase
    case weather

    var title: String {
        switch self {
        case .lowRoad: return "The Low Road"
        case .staircase: return "The Staircase"
        case .weather: return "Weather in the Margins"
        }
    }

    var invitation: String {
        switch self {
        case .lowRoad: return "A spacious run for listening to what comes close."
        case .staircase: return "A rising run: catch a line one step at a time."
        case .weather: return "A brisk, grey-streaked run with more chances to make a rescue."
        }
    }

    var runDuration: TimeInterval {
        switch self {
        case .lowRoad: return 31
        case .staircase: return 28
        case .weather: return 26
        }
    }

    var scrollSpeed: CGFloat {
        switch self {
        case .lowRoad: return 145
        case .staircase: return 168
        case .weather: return 186
        }
    }

    static func selected(seed: String) -> Self {
        allCases[Int(seed.stableHash.magnitude % UInt(allCases.count))]
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
        let greyPool = nothingPool(from: days)
        var pages = [surface(phrases: phrases, greyPool: greyPool, day: day, now: now, score: score)]
        // The Shadow Sentence Runner: a worn-edge variant of the game that drops the
        // Thornlight lexicon into the margin alongside the reader's own kept words.
        // Emitted as a higher-scored variant so it wins the gamePage slot when active.
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        if shadowState.isActive {
            pages.append(
                surface(
                    phrases: phrases,
                    greyPool: greyPool,
                    day: day,
                    now: now,
                    score: score + shadowState.scoreBoost,
                    shadow: shadowState,
                    shadowInputs: inputs
                )
            )
        }
        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let days = inputs.days + [day]
        let phrases = archivePhrases(from: days)
        return surface(phrases: phrases, greyPool: nothingPool(from: days), day: day, now: now, score: phrases.count >= 6 ? 62 : 46)
    }

    private func surface(
        phrases: [(phrase: String, pageID: String, date: Date, label: String)],
        greyPool: [String],
        day: BookDay,
        now: Date,
        score: Int,
        shadow: ShadowWonder.State? = nil,
        shadowInputs: BookSourceInputs? = nil
    ) -> SurfacePage {
        let isShadow = shadow?.isActive == true
        let slotID = SurfaceCadence.slotID(for: now, hours: 6)
        let seed = "\(day.id)-\(slotID)-sentence-runner\(isShadow ? "-shadow" : "")"
        let runShape = SentenceRunnerRunShape.selected(seed: "\(seed)-shape")
        let sourceMap = Dictionary(
            phrases.map { ($0.phrase, (id: $0.pageID, date: $0.date, label: $0.label)) },
            uniquingKeysWith: { first, _ in first }
        )
        var selected = deterministicPick(phrases.map(\.phrase), count: 12, seed: seed)
        if isShadow {
            // Thread the Thornlight lexicon through the reader's own kept words so
            // the run reads goblin-core without losing its personal level design.
            let shadowWords = deterministicPick(ShadowWonder.gameWords, count: 6, seed: "\(seed)-thornlight")
            selected = Array((Array(selected.prefix(8)) + shadowWords).prefix(14))
        }
        let grey = deterministicPick(greyPool.isEmpty ? nothingPhrases : greyPool, count: 6, seed: "\(seed)-nothing")
        // Sidecar: phrase¶pageID¶unixTimestamp¶pageTypeTitle — lets the result page
        // open the exact source page in a modal, dated. Thornlight words have no
        // source page, so they simply omit a sidecar entry.
        let sources = selected.compactMap { phrase -> String? in
            guard let s = sourceMap[phrase] else { return nil }
            return "\(phrase)¶\(s.id)¶\(s.date.timeIntervalSince1970)¶\(s.label)"
        }
        let ready = selected.count >= 6
        var metadata: [String: String] = [
            "source": source.id,
            "gameID": isShadow ? "shadow-sentence-runner" : "sentence-runner",
            "gameTitle": isShadow ? "The Shadow Runner" : "The Sentence Runner",
            "runnerShape": runShape.rawValue,
            "runnerShapeTitle": runShape.title,
            "gamePhrases": selected.joined(separator: "||"),
            "nothingPhrases": grey.joined(separator: "||"),
            "phraseSources": sources.joined(separator: "||"),
            "placeholder": ready ? "Run the margin, then keep the result." : "Keep more pages first.",
            "tags": isShadow
                ? ShadowWonder.mergedTags("game-page,sentence-runner,loom-run,nothing-words,shadow-runner", inputs: shadowInputs ?? .empty, now: now)
                : "game-page,sentence-runner,loom-run,nothing-words"
        ]
        if isShadow {
            metadata["variant"] = "shadow-wonder"
            metadata["shadowVariantOf"] = "\(source.id)-sentence-runner-\(slotID)"
        }
        return SurfacePage(
            id: "\(source.id)-sentence-runner-\(slotID)\(isShadow ? "-shadow" : "")",
            type: .gamePage,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: ready ? score : 42,
            reason: isShadow
                ? "Shadow Wonder is unlocked; the Thornlight lexicon runs the margin with your kept words."
                : (ready
                    ? "The Loom has loosened kept words into motion."
                    : "The Loom is waiting for a few more kept sentences before it can run."),
            prompt: isShadow ? "The Shadow Runner" : "The Sentence Runner",
            detail: isShadow
                ? "Jump through your kept words and the worn-edge lexicon — rust, thorn, dusk. Avoid Routine's grey. Keep the dark, honest sentence the run makes."
                : "Jump through words from your own archive. Avoid Routine's grey phrases. Keep what the run makes.",
            payload: BookPagePayload(
                headline: ready
                    ? (isShadow ? "Your worn words are moving in the dark." : "Your old words are moving again.")
                    : "The Loom Needs More Thread",
                body: ready
                    ? (isShadow
                        ? "The Loom has pulled phrases from kept pages and laced them with the Thornlight lexicon — rust, dusk, thorn, decay. Catch what time has touched. Beauty here does not need to be cheerful."
                        : "The Loom has pulled phrases from kept pages and set them moving across the margin. Catch the words that still feel alive. Let the grey ones pass if you can.")
                    : "Keep a few more real sentences, then come back. Game Pages use your archive as their level design.",
                metadata: metadata
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

    /// The Rut of Routine speaks in the reader's own flat words when it can: prefer the
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
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        return PageArchetypePackRegistry.archetypes().compactMap { archetype in
            if let activeHours = archetype.activeHours, !activeHours.contains(hour) {
                return nil
            }
            if let trigger = archetype.trigger,
               !trigger.allows(context: triggerContext, archetypeID: archetype.id) {
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
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        let eligibleArchetypes = archetypes.filter { archetype in
            archetype.trigger?.allows(context: triggerContext, archetypeID: archetype.id) ?? true
        }
        let pool = eligibleArchetypes.isEmpty ? archetypes : eligibleArchetypes
        let slot = abs("\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 2))-pack".stableHash)
        let archetype = pool[slot % pool.count]
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
        if archetype.trigger != nil {
            let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
            metadata["triggered"] = "true"
            metadata["triggerTimeBand"] = triggerContext.timeBand
            metadata["triggerMoonPhase"] = triggerContext.moonPhase
            metadata["triggerWorldEventIDs"] = triggerContext.activeWorldEvents.map(\.id).joined(separator: ",")
        }
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

struct WordNegotiationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .wordNegotiation)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        return candidates(
            from: PageArchetypePackRegistry.wordNegotiations(),
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
    }

    func candidates(
        from definitions: [WordNegotiationDefinition],
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        return definitions
            .filter { $0.isEligible(context: triggerContext, readerLexicon: inputs.readerLexicon) }
            .sorted { left, right in
                if left.score == right.score {
                    return "\(day.id)-\(left.id)".stableHash < "\(day.id)-\(right.id)".stableHash
                }
                return left.score > right.score
            }
            .map { surface(for: $0, day: day, inputs: inputs, now: now) }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        let definitions = PageArchetypePackRegistry.wordNegotiations()
        let pool = definitions.filter { $0.isEligible(context: triggerContext, readerLexicon: inputs.readerLexicon) }
        guard let definition = (pool.isEmpty ? definitions : pool).first else {
            return SurfacePage(
                id: "\(source.id)-empty-\(Int(now.timeIntervalSince1970))",
                type: .wordNegotiation,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 34,
                reason: "No installed pack has offered a living word yet.",
                prompt: "No Word Is Waiting",
                detail: "A content pack can add words that ask the reader for a ruling.",
                payload: BookPagePayload(
                    headline: "The Dictionary Desk Is Quiet",
                    body: "No living word is waiting for a ruling. When an installed pack offers one, this desk will open.",
                    metadata: ["source": source.id, "tags": "word-negotiation,quiet"]
                )
            )
        }
        return surface(for: definition, day: day, inputs: inputs, now: now)
    }

    private func surface(
        for definition: WordNegotiationDefinition,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        let defaultChoice = definition.choice(for: nil)
        var tags = ["word-negotiation", "lexicon-word:\(definition.stableWordID)"] + definition.tags
        if let eventID = definition.eventID?.nonEmpty {
            tags.append("event:\(eventID)")
            tags.append("event-word-ruled")
        }
        if let phaseID = definition.phaseID?.nonEmpty {
            tags.append("event-phase:\(phaseID)")
        }
        if definition.isMissingSeed {
            tags.append("missing-word-seed")
        }

        var metadata: [String: String] = [
            "source": source.id,
            "wordNegotiationID": definition.id,
            "wordNegotiationWordID": definition.stableWordID,
            "wordNegotiationWord": definition.word,
            "wordNegotiationOriginalSense": definition.originalSense,
            "wordNegotiationGrievance": definition.grievance,
            "wordNegotiationCategory": definition.category.rawValue,
            "wordNegotiationOrigin": definition.origin.rawValue,
            "wordNegotiationDefaultRuling": defaultChoice?.ruling.rawValue ?? "",
            "wordNegotiationIsMissingSeed": definition.isMissingSeed ? "true" : "false",
            "wordNegotiationChoices": encodedChoices(definition.choices),
            "symbol": definition.symbolName,
            "placeholder": defaultChoice.map { "Rule: \($0.title). Add one sentence about why." } ?? "Record what the word could not say.",
            "tags": tags.joined(separator: ",")
        ]
        if let eventID = definition.eventID {
            metadata["worldEventIDs"] = eventID
            metadata["wordNegotiationEventID"] = eventID
        }
        if let phaseID = definition.phaseID {
            metadata["wordNegotiationPhaseID"] = phaseID
        }
        if let eventModes = definition.eventModes, !eventModes.isEmpty {
            metadata["wordNegotiationEventModes"] = eventModes.joined(separator: ",")
        }
        for choice in definition.choices {
            let prefix = "wordNegotiationChoice.\(choice.ruling.rawValue)"
            metadata["\(prefix).title"] = choice.title
            metadata["\(prefix).detail"] = choice.detail
            metadata["\(prefix).sense"] = choice.resultingSense ?? ""
            metadata["\(prefix).response"] = choice.responseLine ?? ""
            metadata["\(prefix).category"] = choice.category?.rawValue ?? ""
        }

        return SurfacePage(
            id: "\(source.id)-\(definition.id)-\(SurfaceCadence.slotID(for: now, hours: definition.cadenceHours))",
            type: .wordNegotiation,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: definition.score,
            reason: "A living word from an installed pack is asking for a ruling.",
            prompt: "Rule on \(definition.word)",
            detail: definition.grievance,
            payload: BookPagePayload(
                headline: "\(definition.word) has left its old line.",
                body: body(for: definition),
                metadata: metadata
            )
        )
    }

    private func body(for definition: WordNegotiationDefinition) -> String {
        var paragraphs = [
            "Original sense: \(definition.originalSense)",
            "Grievance: \(definition.grievance)"
        ]
        if definition.isMissingSeed {
            paragraphs.append("This word is present only as a cold outline. A pack may mark it as missing so the Book can remember that it could not be ruled.")
        }
        if !definition.choices.isEmpty {
            let choices = definition.choices.map { choice in
                "- \(choice.title): \(choice.detail)"
            }.joined(separator: "\n")
            paragraphs.append("Possible rulings:\n\(choices)")
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private func encodedChoices(_ choices: [WordNegotiationChoice]) -> String {
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
}

struct CalendarPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .calendar)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        if !inputs.calendarIntegrationEnabled, inputs.calendarEvents.isEmpty {
            guard !context.distress.isActive,
                  inputs.surfaceHistory["source:\(source.id)"] == nil else {
                return []
            }
            return [calendarDoorPreview(day: day, score: 78)]
        }
        guard !inputs.calendarEvents.isEmpty else { return [] }
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

    func previewSurface(for day: BookDay, score: Int = 96) -> SurfacePage {
        calendarDoorPreview(day: day, score: score)
    }

    private func calendarDoorPreview(day: BookDay, score: Int) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-door-preview-\(day.id)",
            type: .calendar,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: score,
            reason: "Bellkeeper Elian is offering to open the Calendar Doorway before the wider game fully unfolds.",
            prompt: "The Calendar Door is waiting.",
            detail: "Let the Book read today's hinges: appointments, deadlines, departures, and returns stay on this device.",
            payload: BookPagePayload(
                headline: "A Door Marked Today",
                body: """
                Bellkeeper Elian has found a narrow brass door in the colophon and dragged it into the light.

                Open it, and the Book may read your upcoming Calendar events on this device: not to judge the day, not to publish the day, but to notice its hinges. A meeting can become an Hour Page before it begins. An appointment can leave one clean margin after it lands. The morning paper can print the day's posted turns instead of pretending time is a blank hallway.

                The door is optional. Closed, the Book still works. Open, it gets better at arriving before the hour does.
                """,
                metadata: [
                    "source": source.id,
                    "calendarDoorPreview": "true",
                    "requiresCalendarPermission": "true",
                    "privacy": "calendar stays on device",
                    "symbol": source.symbolName,
                    "tags": "calendar,calendar-door,preview,first-run,permission"
                ]
            )
        )
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

/// The station reads the reader back over the air: an occasional on-air
/// dedication built from a page she actually kept. The Book remembering her is
/// one thing; the world visibly carrying her words is another — that is the
/// chosen feeling, so dedications stay infrequent and always quote real ink.
enum RadioDedication {
    static func line(recentKeptPages: [BookPage], dayID: String, now: Date) -> String? {
        // Roughly one day in three, so the dial keeps the power to surprise.
        guard abs("\(dayID)-radio-dedication".stableHash) % 3 == 0 else { return nil }
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let candidates = recentKeptPages.filter {
            $0.createdAt >= cutoff && $0.createdAt <= now
                && !$0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !candidates.isEmpty else { return nil }
        let page = candidates[abs("\(dayID)-dedication-page".stableHash) % candidates.count]
        let raw = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = raw.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? raw
        let words = firstLine.split { $0.isWhitespace }.map(String.init)
        let quote = words.count <= 14 ? firstLine : words.prefix(14).joined(separator: " ") + "\u{2026}"
        return ReflectiveProse.pick([
            "The volume dips between songs. \u{201C}\(quote)\u{201D} \u{2014} read slowly, once. \u{201C}That one goes out to the one who wrote it. You know who you are.\u{201D}",
            "A dedication, almost shy: a listener kept the words \u{201C}\(quote)\u{201D} this week, and the station has been humming them since.",
            "\u{201C}Tonight's dedication isn't from a listener,\u{201D} the host says. \u{201C}It's to one. For the page that said: '\(quote)'.\u{201D}"
        ], seed: KeepMarginalia.seed(for: "\(dayID)-\(page.id)"), salt: 6)
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
        let dedication = isTuned ? RadioDedication.line(
            recentKeptPages: day.capturedPages + inputs.days.flatMap(\.capturedPages),
            dayID: day.id,
            now: now
        ) : nil
        let body: String
        if isTuned {
            body = """
            The receiver is tuned to \(station.displayFrequency): \(station.title).

            \(station.signalLine)

            \(dedication.map { "\($0)\n\n" } ?? "")\(interlude.map { "Broadcast interruption: \($0)\n\n" } ?? "")While this station plays, the Book listens through it. Its signal leans toward: \(effects). Drop local tracks whose names match the station asset names into Documents/Radio, or bundle them with the app, and the dial will play them instead of its procedural bed.

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
            "radioDedication": dedication ?? "",
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
