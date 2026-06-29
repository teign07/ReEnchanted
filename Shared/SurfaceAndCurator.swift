import Foundation


struct BraidRecoveryState: Codable, Equatable {
    private(set) var canRetry = false
    private(set) var lastError: String?

    var retryActionTitle: String? {
        canRetry ? "Try again" : nil
    }

    mutating func beginAttempt() {
        canRetry = false
    }

    mutating func recordFailure(_ error: String, day: BookDay) {
        guard day.bookOfYou == nil, !day.capturedPages.isEmpty else {
            canRetry = false
            lastError = nil
            return
        }
        canRetry = true
        lastError = error
    }

    mutating func recordSuccess() {
        canRetry = false
        lastError = nil
    }

    static func dayByMarkingCapturedPagesUsed(_ day: BookDay, braid: BookPage) -> BookDay {
        var updatedDay = day
        let capturedIDs = Set(day.capturedPages.map(\.id))
        updatedDay.pages = updatedDay.pages.map { page in
            var updated = page
            if capturedIDs.contains(updated.id) {
                updated.usedInBookOfYou = true
            }
            return updated
        }
        updatedDay.pages.append(braid)
        return updatedDay
    }
}

struct PreparedPageRecoveryState: Codable, Equatable {
    private(set) var lastFailureAt: Date?
    var cooldown: TimeInterval

    init(lastFailureAt: Date? = nil, cooldown: TimeInterval = 20 * 60) {
        self.lastFailureAt = lastFailureAt
        self.cooldown = cooldown
    }

    func shouldBegin(
        isPreparing: Bool,
        isLocalBrainWorking: Bool,
        preparedSurface: SurfacePage?,
        slotID: String,
        requiredMetadataKey: String,
        now: Date
    ) -> Bool {
        guard !isPreparing, !isLocalBrainWorking else { return false }
        guard !isCoolingDown(now: now) else { return false }
        return !Self.preparedSurfaceIsCurrent(
            preparedSurface,
            slotID: slotID,
            requiredMetadataKey: requiredMetadataKey
        )
    }

    func isCoolingDown(now: Date) -> Bool {
        guard let lastFailureAt else { return false }
        return now.timeIntervalSince(lastFailureAt) < cooldown
    }

    mutating func recordFailure(at date: Date = Date()) {
        lastFailureAt = date
    }

    mutating func recordSuccess() {
        lastFailureAt = nil
    }

    static func preparedSurfaceIsCurrent(
        _ surface: SurfacePage?,
        slotID: String,
        requiredMetadataKey: String
    ) -> Bool {
        guard let surface,
              surface.payload.metadata["slotID"] == slotID,
              surface.payload.metadata[requiredMetadataKey]?.isEmpty == false else {
            return false
        }
        return true
    }
}

struct WorkBlockingState: Codable, Equatable {
    var isLocalBrainWorking = false
    var localBrainStatus: String?
    var isBraiding = false
    var isPreparingAutomaticIllumination = false
    var isPreparingStoryPage = false
    var isPreparingGossipPage = false
    var isPreparingFacultyResearchPage = false
    var isPreparingLetterPage = false
    var isPreparingBleedEdition = false
    var isRequestingWeather = false

    var labWorkStatus: String {
        if let localBrainStatus {
            return localBrainStatus
        }
        if isBraiding {
            return "braiding"
        }
        if isPreparingAutomaticIllumination {
            return "preparing illumination"
        }
        if isPreparingStoryPage {
            return "preparing story"
        }
        if isPreparingGossipPage {
            return "preparing gossip"
        }
        if isPreparingFacultyResearchPage {
            return "preparing faculty research"
        }
        if isPreparingLetterPage {
            return "preparing letter"
        }
        if isPreparingBleedEdition {
            return "running the presses"
        }
        return "idle"
    }

    func canOpenSurface(needsLocalBrain: Bool) -> Bool {
        !(isLocalBrainWorking && needsLocalBrain)
    }

    func surfaceBusyIndicator(for type: BookPageType) -> Bool {
        switch type {
        case .bookOfYou:
            return isBraiding
        case .narrativeOS:
            return isPreparingStoryPage
        case .bookFae:
            return isPreparingStoryPage
        case .gossip:
            return isPreparingGossipPage
        case .facultyResearch:
            return isPreparingFacultyResearchPage
        case .letter:
            return isPreparingLetterPage
        case .theBleed:
            return isPreparingBleedEdition
        case .weather:
            return isRequestingWeather
        case .illuminatedPhoto:
            return isPreparingAutomaticIllumination
        default:
            return false
        }
    }

    var canStartBraid: Bool {
        !isBraiding && !isLocalBrainWorking
    }

    var canRequestWeather: Bool {
        !isLocalBrainWorking
    }
}

struct SurfaceReadinessState: Codable, Equatable {
    var type: BookPageType
    var metadata: [String: String]

    init(surface: SurfacePage) {
        self.init(type: surface.type, metadata: surface.payload.metadata)
    }

    init(type: BookPageType, metadata: [String: String] = [:]) {
        self.type = type
        self.metadata = metadata
    }

    var needsLocalBrainToOpen: Bool {
        switch type {
        case .bookOfYou:
            return true
        case .illuminatedPhoto:
            return !hasNonEmptyMetadata("renderedPreviewPath")
        case .narrativeOS:
            return !hasNonEmptyMetadata("storyScene")
        case .bookFae:
            return !hasNonEmptyMetadata("storyScene")
        case .gossip:
            return !hasNonEmptyMetadata("gossipProse")
        case .theBleed:
            return !hasNonEmptyMetadata("bleedProse")
        case .bookJump:
            return !hasNonEmptyMetadata("bookJumpProse")
        case .facultyResearch:
            return !hasNonEmptyMetadata("researchProse")
        case .weather:
            return metadata["selector"] == "fallback"
        case .supportGuild:
            return !hasNonEmptyMetadata("guildProse")
        case .twoReadings:
            return !hasNonEmptyMetadata("twoReadingsProse")
        case .castBond:
            return !hasNonEmptyMetadata("castBondProse")
        case .academyClass:
            return hasNonEmptyMetadata("sessionID") && !hasNonEmptyMetadata("classProse")
        case .elective:
            return metadata["electiveOffer"] == "true" && !hasNonEmptyMetadata("electiveAsk")
        case .packPage:
            return hasNonEmptyMetadata("packPrompt") && !hasNonEmptyMetadata("packProse")
        case .wordNegotiation:
            return false
        case .gamePage:
            return false
        default:
            return false
        }
    }

    private func hasNonEmptyMetadata(_ key: String) -> Bool {
        metadata[key]?.isEmpty == false
    }
}

enum SurfaceActionDecision: Codable, Equatable {
    case blocked(message: String)
    case braid
    case open
}

struct SurfaceActionRouter: Codable, Equatable {
    var workState: WorkBlockingState

    func decision(for type: BookPageType, readiness: SurfaceReadinessState) -> SurfaceActionDecision {
        guard workState.canOpenSurface(needsLocalBrain: readiness.needsLocalBrainToOpen) else {
            return .blocked(message: "The Book is already writing. One moment, please.")
        }
        if type == .bookOfYou {
            return .braid
        }
        return .open
    }
}

struct SurfacePage: Identifiable, Equatable, Codable {
    let id: String
    let type: BookPageType
    let sourceID: String
    let intent: BookPageIntent
    let renderStyle: BookPageRenderStyle
    let score: Int
    let reason: String
    let prompt: String
    let detail: String
    let payload: BookPagePayload

    var source: BookPageSource {
        BookPageSourceRegistry.source(id: sourceID, fallbackType: type)
    }

    var origin: BookPageOrigin {
        source.origin
    }

    var privacy: BookPagePrivacy {
        source.privacy
    }

    var mediaAssets: [BookPageMediaAsset] {
        var assets: [BookPageMediaAsset] = []
        if type == .illustration,
           let assetName = nonEmptyMetadataValue("assetName") {
            assets.append(BookPageMediaAsset(
                kind: .bundledImage,
                reference: assetName,
                caption: payload.headline,
                sourceID: sourceID,
                metadata: payload.metadata
            ))
        }
        if type == .illuminatedPhoto || type == .enchantment {
            if let renderedPath = nonEmptyMetadataValue("renderedPreviewPath") {
                assets.append(BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: renderedPath,
                    caption: payload.headline,
                    sourceID: sourceID,
                    metadata: payload.metadata
                ))
            }
            if let assetLocalIdentifier = nonEmptyMetadataValue("assetLocalIdentifier") {
                assets.append(BookPageMediaAsset(
                    kind: .photoLibraryAsset,
                    reference: assetLocalIdentifier,
                    caption: payload.headline,
                    sourceID: sourceID,
                    metadata: payload.metadata
                ))
            }
        }
        if let proofImagePath = nonEmptyMetadataValue("proofImagePath") {
            assets.append(BookPageMediaAsset(
                kind: .renderedImageFile,
                reference: proofImagePath,
                caption: payload.metadata["proofCaption"] ?? payload.headline,
                sourceID: sourceID,
                metadata: payload.metadata
            ))
        }
        if ["cast", "location"].contains(payload.metadata["illustrationKind"]),
           let kindRawValue = nonEmptyMetadataValue("imageAssetKind"),
           let kind = BookPageMediaAsset.Kind(rawValue: kindRawValue),
           let reference = nonEmptyMetadataValue("imageAssetReference") {
            assets.append(BookPageMediaAsset(
                kind: kind,
                reference: reference,
                caption: payload.headline,
                sourceID: sourceID,
                metadata: payload.metadata
            ))
        }
        return assets
    }

    init(
        id: String? = nil,
        type: BookPageType,
        sourceID: String? = nil,
        intent: BookPageIntent? = nil,
        renderStyle: BookPageRenderStyle = .promptCard,
        score: Int = 50,
        reason: String = "The Book has room for this page.",
        prompt: String,
        detail: String,
        payload: BookPagePayload? = nil
    ) {
        let source = BookPageSourceRegistry.source(for: type)
        self.type = type
        self.sourceID = sourceID ?? source.id
        self.intent = intent ?? Self.defaultIntent(for: type)
        self.id = id ?? "\(self.sourceID)-\(self.intent.rawValue)"
        self.renderStyle = renderStyle
        self.score = score
        self.reason = reason
        self.prompt = prompt
        self.detail = detail
        self.payload = payload ?? BookPagePayload(headline: prompt, body: detail)
    }

    private static func defaultIntent(for type: BookPageType) -> BookPageIntent {
        switch type {
        case .rest:
            return .rest
        case .bookOfYou:
            return .braid
        case .askTheBook, .anchor, .inkrestOfficeHours:
            return .reflect
        case .faeBargain:
            return .capture
        case .bookFae:
            return .simulate
        case .pactDispatch:
            return .importReference
        case .pactVerdict:
            return .reflect
        case .pactErrand:
            return .capture
        case .festival:
            return .capture
        case .twoReadings:
            return .reflect
        case .castBond:
            return .importReference
        case .body, .fuel, .facultyResearch, .supportGuild, .weather, .letter, .academyClass, .bookConnections, .bookNotices, .glowInvitation, .theBleed, .todaysSky, .bookJump, .radio, .inventory, .gamePage:
            return .reflect
        case .elective:
            return .capture
        case .packPage, .wordNegotiation:
            return .reflect
        case .calendar:
            return .reflect
        case .wonderCompass, .lore, .patreon, .illustration, .quip, .helpTips, .welcome, .marginsAtlas, .bindery:
            return .importReference
        case .enchantment:
            return .capture
        case .illuminatedPhoto, .bookRemembered:
            return .resurface
        case .location:
            return .reflect
        case .narrativeOS:
            return .simulate
        case .gossip:
            return .simulate
        case .mood, .diary, .souvenir, .aboutYou:
            return .capture
        }
    }

    private func nonEmptyMetadataValue(_ key: String) -> String? {
        let value = payload.metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}

extension SurfacePage {
    func withReaderLexiconLanguageLaw(_ lexicon: ReaderLexicon) -> SurfacePage {
        let section = lexicon.languageLawSection().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !section.isEmpty else { return self }
        var metadata = payload.metadata
        metadata["readerLexiconPromptSection"] = section
        metadata["readerLexiconRedefinedWords"] = lexicon.redefinedEntries
            .map(\.word)
            .uniqueLexiconWords()
            .joined(separator: ",")
        metadata["readerLexiconEatenWords"] = lexicon.eatenEntries
            .map(\.word)
            .uniqueLexiconWords()
            .joined(separator: ",")
        if let treaty = lexicon.treaty {
            metadata["readerLexiconTreaty"] = treaty.rawValue
        }
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

    static func illuminatedPhotoSurface(
        draft: IlluminatedPhotoDraft,
        renderedURL: URL?,
        idSuffix: String
    ) -> SurfacePage? {
        let source = BookPageSourceRegistry.source(for: .illuminatedPhoto)
        var metadata: [String: String] = [
            "source": source.id,
            "sourceAssetName": draft.sourceAssetName,
            "assetLocalIdentifier": draft.assetLocalIdentifier,
            "template": draft.compositionPlan.templateId.rawValue,
            "assetPack": draft.compositionPlan.assetPackId,
            "status": draft.status.rawValue,
            "privacy": "private local draft",
            "fieldNote": draft.analysis.marginalia.fieldNote,
            "stampLabel": draft.analysis.marginalia.stampLabel,
            "observations": draft.analysis.marginalia.observationList.joined(separator: " | "),
            "closingLine": draft.analysis.marginalia.closingLine,
            "scene": draft.analysis.scene,
            "motifs": draft.analysis.motifs.joined(separator: ","),
            "mood": draft.analysis.mood,
            "souvenirs": draft.analysis.souvenirCandidates.joined(separator: " | ")
        ]
        if let renderedURL {
            metadata["renderedPreviewPath"] = renderedURL.path
        }

        return SurfacePage(
            id: "\(source.id)-\(draft.assetLocalIdentifier.stableHash)-\(idSuffix)",
            type: .illuminatedPhoto,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .illuminatedPhoto,
            score: 96,
            reason: "Penny found a photo with ink on it.",
            prompt: "Found in the Margins",
            detail: "The Book found this in the camera roll and made it a page worth considering.",
            payload: BookPagePayload(
                headline: draft.analysis.marginalia.stampLabel,
                body: draft.analysis.marginalia.closingLine,
                metadata: metadata
            )
        )
    }
}

private extension Array where Element == String {
    func uniqueLexiconWords() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for word in self {
            let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(word)
        }
        return result
    }
}

struct CuratorContext: Equatable {
    var distress: DistressSignals
    var bleed: BleedTranslation
    var stepBack: StepBackEligibility

    static func make(for day: BookDay, recentDays: [BookDay]? = nil) -> CuratorContext {
        let distress = DistressSignals.evaluate(day: day)
        return CuratorContext(
            distress: distress,
            bleed: BleedTranslator.translate(distress: distress),
            stepBack: StepBackEligibility.evaluate(
                recentDays: recentDays ?? [day],
                distress: distress
            )
        )
    }
}

enum SurfaceCadence {
    static func slotID(for date: Date, hours: Int = 2, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let slot = (components.hour ?? 0) / max(1, hours)
        return String(format: "%04d-%02d-%02d-s%02d", year, month, day, slot)
    }

    static func minuteSlotID(for date: Date, minutes: Int = 20, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let slot = ((components.minute ?? 0) / max(1, minutes)) * max(1, minutes)
        return String(format: "%04d-%02d-%02d-h%02d-m%02d", year, month, day, hour, slot)
    }
}

struct DailyCheckInWindow: Equatable {
    var id: String
    var name: String
    var startMinute: Int
    var endMinute: Int
}

enum DailyCheckInCadence {
    static let windows: [DailyCheckInWindow] = [
        DailyCheckInWindow(id: "morning", name: "Morning Check-In", startMinute: 7 * 60, endMinute: 10 * 60 + 30),
        DailyCheckInWindow(id: "midday", name: "Midday Check-In", startMinute: 12 * 60, endMinute: 15 * 60 + 30),
        DailyCheckInWindow(id: "evening", name: "Evening Check-In", startMinute: 17 * 60 + 30, endMinute: 19 * 60 + 30)
    ]

    static func currentWindow(for date: Date = Date(), calendar: Calendar = .current) -> DailyCheckInWindow {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return windows.first { minute >= $0.startMinute && minute < $0.endMinute }
            ?? windows.min { left, right in
                abs(minute - left.startMinute) < abs(minute - right.startMinute)
            }
            ?? windows[0]
    }

    static func activeWindow(for date: Date = Date(), calendar: Calendar = .current) -> DailyCheckInWindow? {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return windows.first { minute >= $0.startMinute && minute < $0.endMinute }
    }
}

struct SurfaceDismissalLedger: Codable, Equatable {
    var dismissedAtByDay: [String: [String: Date]]

    init(dismissedAtByDay: [String: [String: Date]] = [:]) {
        self.dismissedAtByDay = dismissedAtByDay
    }

    mutating func dismiss(surfaceID: String, dayID: String, at date: Date) {
        var dayDismissals = dismissedAtByDay[dayID] ?? [:]
        dayDismissals[surfaceID] = date
        dismissedAtByDay[dayID] = dayDismissals
    }

    mutating func restore(surfaceID: String, dayID: String) {
        dismissedAtByDay[dayID]?[surfaceID] = nil
        if dismissedAtByDay[dayID]?.isEmpty == true {
            dismissedAtByDay[dayID] = nil
        }
    }

    func activeDismissedSurfaceIDs(for dayID: String, now: Date, ttl: TimeInterval) -> Set<String> {
        let cutoff = now.addingTimeInterval(-ttl)
        return Set((dismissedAtByDay[dayID] ?? [:]).compactMap { surfaceID, dismissedAt in
            dismissedAt > cutoff ? surfaceID : nil
        })
    }

    mutating func prune(now: Date, ttl: TimeInterval) {
        let cutoff = now.addingTimeInterval(-ttl)
        dismissedAtByDay = dismissedAtByDay.reduce(into: [:]) { result, entry in
            let activeDismissals = entry.value.filter { $0.value > cutoff }
            if !activeDismissals.isEmpty {
                result[entry.key] = activeDismissals
            }
        }
    }
}

enum BookCurator {
    static func surfacedPages(for day: BookDay, now: Date = Date(), limit: Int = 3) -> [SurfacePage] {
        surfacedPages(for: day, context: .make(for: day), inputs: .empty, now: now, limit: limit)
    }

    static func surfacedPages(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date(),
        limit: Int = 3,
        preferences: CuratorSurfacePreferences = .none
    ) -> [SurfacePage] {
        surfacedPages(
            for: day,
            context: .make(for: day),
            inputs: inputs,
            now: now,
            limit: limit,
            preferences: preferences
        )
    }

    static func surfacedPages(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        limit: Int = 3,
        preferences: CuratorSurfacePreferences = .none
    ) -> [SurfacePage] {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let candidates = BookPageSourceAdapters.active.flatMap { adapter in
            adapter.candidates(for: day, context: context, inputs: inputs, now: now)
        }.map { WorldEventEffects.framed($0, events: inputs.activeWorldEvents) }
        let mood = CuratorMood.make(inputs: inputs, distressActive: context.distress.isActive, now: now)
        var picked = rankedPages(
            from: candidates,
            limit: limit,
            preferences: preferences,
            mood: mood,
            now: now
        ).map(\.page)

        // Sovereign automation: a Talisman that reigns over a shelf acts unasked
        // — guarantee one of its pages a slot if the feed didn't already pick one
        // and the day isn't hard. Pure surfacing; no model call.
        let sovereignTypes = PactWarEffects.sovereignShelfPageTypes(state: inputs.pactWar)
        if !sovereignTypes.isEmpty,
           !context.distress.isActive,
           !picked.contains(where: { sovereignTypes.contains($0.type) }),
           let inject = candidates.first(where: { candidate in
               sovereignTypes.contains(candidate.type) && !picked.contains(where: { $0.id == candidate.id })
           }) {
            if picked.isEmpty {
                picked = [inject]
            } else {
                picked[picked.count - 1] = inject
            }
        }

        if BookSchedule.shouldAutoBraid(now),
           !picked.contains(where: { $0.type == .bookOfYou }),
           let braid = candidates.first(where: { candidate in
               candidate.type == .bookOfYou
                   && preferences.allows(candidate)
                   && mood.allows(candidate)
                   && !BookMemoryGate.locks(candidate.type, keptPageCount: inputs.keptPageCount)
           }) {
            if picked.isEmpty {
                picked = [braid]
            } else {
                picked[picked.count - 1] = braid
            }
        }

        return picked
            .map { PactWarEffects.framed($0, state: inputs.pactWar) }
            .map { $0.withReaderLexiconLanguageLaw(inputs.readerLexicon) }
    }

    static func rankedPages(
        from candidates: [SurfacePage],
        limit: Int = 3,
        preferences: CuratorSurfacePreferences = .none,
        mood: CuratorMood = .neutral,
        now: Date = Date()
    ) -> [RankedSurfacePage] {
        // Hard filters: a reader's disabled sources and first-hours hidden types
        // are never overridden.
        let allowed = candidates
            .filter { preferences.allows($0) }
            .filter { mood.allows($0) }
            .filter { !BookMemoryGate.locks($0.type, keptPageCount: mood.keptPageCount) }
        // The type-refresh cooldown only adds variety — it must never starve the
        // desk. Prefer pages that are off cooldown, but if that would leave the
        // homescreen empty, fall back to the full allowed pool.
        let offCooldown = allowed.filter { mood.allowsTypeRefresh(for: $0, now: now) }
        let pool = offCooldown.isEmpty ? allowed : offCooldown
        let sortedPages = pool
            .enumerated()
            .sorted { left, right in
                let leftScore = preferences.adjustedScore(for: left.element) + mood.adjustment(for: left.element, now: now)
                let rightScore = preferences.adjustedScore(for: right.element) + mood.adjustment(for: right.element, now: now)
                if leftScore == rightScore {
                    return left.offset < right.offset
                }
                return leftScore > rightScore
            }
            .map(\.element)
        // Two structural rules shape the desk, honored within rank order:
        //   1. Never repeat a kind of page — no two lore cards (or two of any
        //      type) on the shelf at once.
        //   2. Never stack blank-page "write one thing" prompts — at most one
        //      composition card (diary / souvenir / mood / about-you) at a time.
        // We would rather serve a shorter desk than break either rule.
        let deduped = unique(sortedPages)
        var picked: [SurfacePage] = []
        var pickedTypes: Set<BookPageType> = []
        var compositionCount = 0
        // One blank-page prompt per three-slot desk: the home shelf (limit 3)
        // shows at most one, while wider introspection queries still surface the
        // full set of composition cards.
        let compositionLimit = max(1, limit / 3)
        for page in deduped where picked.count < limit {
            guard !pickedTypes.contains(page.type) else { continue }
            if page.type.isCompositionPrompt, compositionCount >= compositionLimit { continue }
            picked.append(page)
            pickedTypes.insert(page.type)
            if page.type.isCompositionPrompt { compositionCount += 1 }
        }
        return picked
            .enumerated()
            .map { offset, page in RankedSurfacePage(page: page, rank: offset + 1) }
    }

    private static func unique(_ pages: [SurfacePage]) -> [SurfacePage] {
        var seen = Set<String>()
        return pages.filter { page in
            seen.insert(page.id).inserted
        }
    }
}

enum WorldEventEffects {
    static func framed(_ page: SurfacePage, events: [ResolvedWorldEvent]) -> SurfacePage {
        let boost = events.scoreBoost(for: page.type)
        guard boost != 0 || !events.isEmpty else { return page }
        var metadata = page.payload.metadata
        if !events.isEmpty {
            metadata["worldEventIDs"] = events.map(\.id).joined(separator: ",")
            metadata["worldEventTitles"] = events.map(\.title).joined(separator: ", ")
            metadata["worldEventPacket"] = events.influencePacket
            metadata["worldEventOutcomes"] = events.compactMap(\.outcome?.id).joined(separator: ",")
            let existingTags = metadata["tags"].map { tags in
                tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            } ?? []
            let eventTags = events.flatMap { event -> [String] in
                var tags = ["world-event", "event:\(event.id)", "event-phase:\(event.phase.id)"]
                if let outcome = event.outcome {
                    tags.append("event-outcome:\(outcome.id)")
                }
                return tags
            }
            metadata["tags"] = Array(Set(existingTags + eventTags)).sorted().joined(separator: ",")
        }
        let payload = BookPagePayload(
            headline: page.payload.headline,
            body: page.payload.body,
            metadata: metadata
        )
        return SurfacePage(
            id: page.id,
            type: page.type,
            sourceID: page.sourceID,
            intent: page.intent,
            renderStyle: page.renderStyle,
            score: page.score + boost,
            reason: boost == 0 ? page.reason : "\(page.reason) \(events.first?.title ?? "A world event") is tugging this page upward.",
            prompt: page.prompt,
            detail: page.detail,
            payload: payload
        )
    }
}

// MARK: - Curator awareness

/// One served-surface memory: when something last rose, and how often lately.
struct SurfaceHistoryRecord: Codable, Equatable {
    var lastShownAt: Date
    var recentShowCount: Int
}

struct CalendarEventSignal: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var startsAt: Date
    var endsAt: Date? = nil
    var isAllDay: Bool
}

extension SurfacePage {
    var isStoryPlayablePage: Bool {
        switch type {
        case .narrativeOS, .bookFae, .academyClass:
            return true
        case .anchor:
            return payload.metadata["anchorOffer"] != "true" &&
                payload.metadata["anchorID"]?.nonEmpty != nil
        default:
            return false
        }
    }

    /// What "the same page again" means to a reader: the content identity,
    /// not the surface id (which changes every slot).
    var varietyKey: String {
        if let id = payload.metadata["pairID"]?.nonEmpty { return "tworeadings:\(id)" }
        if let id = payload.metadata["entityID"]?.nonEmpty { return "cast:\(id)" }
        if let id = payload.metadata["snippetID"]?.nonEmpty { return "snippet:\(id)" }
        if let id = payload.metadata["quipID"]?.nonEmpty { return "quip:\(id)" }
        if let id = payload.metadata["assetName"]?.nonEmpty { return "plate:\(id)" }
        if let id = payload.metadata["packArchetypeID"]?.nonEmpty { return "pack:\(id)" }
        if payload.metadata["chapterPrimer"] == "true",
           let stage = payload.metadata["primerStage"]?.nonEmpty {
            return "chapter-primer:\(stage)"
        }
        if payload.metadata["chapterBinding"] == "true" { return "chapter-binding" }
        if let id = payload.metadata["sessionID"]?.nonEmpty { return "session:\(id)" }
        if let id = payload.metadata["senderID"]?.nonEmpty { return "sender:\(id)" }
        if let id = payload.metadata["anchorID"]?.nonEmpty { return "anchor:\(id)" }
        if let id = payload.metadata["storyRecipeID"]?.nonEmpty { return "recipe:\(id)" }
        if let id = payload.metadata["storyFormID"]?.nonEmpty { return "form:\(id)" }
        if let id = payload.metadata["bookJumpID"]?.nonEmpty {
            let action = payload.metadata["bookJumpAction"]?.nonEmpty ?? "step"
            return "bookjump:\(id):\(action)"
        }
        if let id = payload.metadata["bookID"]?.nonEmpty { return "bookjump-book:\(id)" }
        if payload.metadata["firstDoorOrigin"] == "true" { return "first-door-origin" }
        if let id = payload.metadata["firstDoorApprenticeshipDay"]?.nonEmpty { return "first-door-apprenticeship:\(id)" }
        if let id = payload.metadata["tipID"]?.nonEmpty { return "tip:\(id)" }
        return "source:\(sourceID)"
    }

    var supplementalStoryVarietyKeys: [String] {
        guard type == .narrativeOS else { return [] }
        var keys: [String] = []
        if let id = payload.metadata["storyFormID"]?.nonEmpty { keys.append("form:\(id)") }
        if let id = payload.metadata["storyGenreID"]?.nonEmpty { keys.append("genre:\(id)") }
        return keys
    }
}

extension BookPageType {
    /// Cards that hand the reader a blank field and ask them to compose an
    /// original sentence. The desk should never present more than one of these
    /// at once, and should stop asking once the reader has written today.
    var isCompositionPrompt: Bool {
        switch self {
        case .mood, .diary, .souvenir, .aboutYou:
            return true
        default:
            return false
        }
    }
}

/// Penalizes what the reader has already seen, on a forgetting curve.
enum CuratorVarietyGovernor {
    static func typeKey(for type: BookPageType) -> String {
        "type:\(type.rawValue)"
    }

    static func fatiguePenalty(
        forKey key: String,
        history: [String: SurfaceHistoryRecord],
        now: Date = Date()
    ) -> Int {
        guard let record = history[key] else { return 0 }
        let hours = now.timeIntervalSince(record.lastShownAt) / 3600
        var penalty: Int
        switch hours {
        case ..<6: penalty = 34
        case ..<24: penalty = 22
        case ..<72: penalty = 10
        case ..<168: penalty = 4
        default: penalty = 0
        }
        if record.recentShowCount >= 3 { penalty += 10 }
        if record.recentShowCount >= 6 { penalty += 12 }
        return penalty
    }

    static func recordingServed(
        keys: [String],
        into history: [String: SurfaceHistoryRecord],
        now: Date = Date()
    ) -> [String: SurfaceHistoryRecord] {
        var updated = history
        for key in keys {
            if var record = updated[key] {
                // A week of quiet resets the habit counter.
                if now.timeIntervalSince(record.lastShownAt) > 7 * 86_400 {
                    record.recentShowCount = 0
                }
                record.recentShowCount += 1
                record.lastShownAt = now
                updated[key] = record
            } else {
                updated[key] = SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1)
            }
        }
        // Keep the ledger small: drop anything silent for a month.
        return updated.filter { now.timeIntervalSince($0.value.lastShownAt) < 31 * 86_400 }
    }
}

/// Hour-of-day affinities: the Book reads differently at breakfast than at
/// midnight. Small nudges, never vetoes.
enum CuratorTimeAffinity {
    static func boost(for type: BookPageType, at date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return boost(for: type, hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    static func boost(for type: BookPageType, hour: Int) -> Int {
        boost(for: type, hour: hour, minute: 0)
    }

    private static func boost(for type: BookPageType, hour: Int, minute: Int) -> Int {
        if let checkInBoost = dailyCheckInBoost(for: type, hour: hour, minute: minute) {
            return checkInBoost
        }
        switch hour {
        case 5..<11:
            switch type {
            case .weather: return 5
            case .body, .mood: return 4
            case .fuel, .wonderCompass: return 2
            case .narrativeOS, .bookFae, .marginsAtlas, .bookConnections, .bookRemembered, .gossip, .bookJump: return -3
            default: return 0
            }
        case 11..<17:
            switch type {
            case .quip, .wonderCompass: return 3
            case .illustration, .aboutYou, .elective: return 2
            case .bookOfYou: return -3
            default: return 0
            }
        case 17..<21:
            switch type {
            case .bookOfYou: return 6
            case .narrativeOS, .bookFae, .marginsAtlas, .bookConnections, .bookRemembered, .bookJump: return 4
            case .supportGuild, .letter, .fuel: return 3
            case .rest: return 2
            default: return 0
            }
        default:
            switch type {
            case .lore, .rest, .helpTips, .welcome: return 4
            case .packPage, .wordNegotiation: return 3
            case .illustration, .narrativeOS, .bookFae, .marginsAtlas, .bookConnections, .bookRemembered, .bookJump, .radio: return 2
            // Late night the desk should soothe, not assign homework: ease
            // blank-page prompts down so they don't greet a midnight check-in.
            case .diary, .souvenir, .mood, .aboutYou: return -6
            case .body: return -4
            case .wonderCompass: return -4
            default: return 0
            }
        }
    }

    private static func dailyCheckInBoost(for type: BookPageType, hour: Int, minute: Int) -> Int? {
        let minuteOfDay = hour * 60 + minute
        let rotations: [String: (primary: BookPageType, secondary: BookPageType, tertiary: BookPageType)] = [
            "morning": (.mood, .fuel, .souvenir),
            "midday": (.fuel, .souvenir, .mood),
            "evening": (.souvenir, .mood, .fuel)
        ]
        guard let window = DailyCheckInCadence.windows.first(where: { minuteOfDay >= $0.startMinute && minuteOfDay < $0.endMinute }),
              let rotation = rotations[window.id] else {
            return nil
        }
        let elapsed = minuteOfDay - window.startMinute
        let sliceLength = max(1, (window.endMinute - window.startMinute) / 3)
        let active: BookPageType
        switch elapsed / sliceLength {
        case 0:
            active = rotation.primary
        case 1:
            active = rotation.secondary
        default:
            active = rotation.tertiary
        }
        switch type {
        case active:
            return 24
        case rotation.primary, rotation.secondary, rotation.tertiary:
            return -18
        default:
            return nil
        }
    }
}

/// Everything the curator should feel before ranking: the clock, the
/// narrative temperature, what was recently served, and the shape of the
/// real day's calendar.
struct CuratorMood {
    var hour: Int = 12
    var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
    var narrativeHeat: Int = 0
    var hasFreshEntityMemory: Bool = false
    var minutesToNextCalendarEvent: Int?
    var distressActive: Bool = false
    var greyLevel: Int = 0
    var reshelvedSourceIDs: Set<String> = []
    var pactWar: PactWarState = PactWarState()
    var almanacBoosts: [BookPageType: Int] = [:]
    var isFirstHours: Bool = false
    var keptPageCount: Int = 0
    var composedTypesToday: Set<BookPageType> = []

    static let neutral = CuratorMood()

    static func make(inputs: BookSourceInputs, distressActive: Bool = false, now: Date = Date(), calendar: Calendar = .current) -> CuratorMood {
        let recentEvents = (inputs.narrative?.recentEventCount ?? 0)
        let freshMemory = (inputs.narrative?.entityMemories ?? [])
            .contains { now.timeIntervalSince($0.createdAt) < 48 * 3600 }
        let nextEventMinutes = inputs.calendarEvents
            .filter { !$0.isAllDay && $0.startsAt > now }
            .map { Int($0.startsAt.timeIntervalSince(now) / 60) }
            .min()
        return CuratorMood(
            hour: calendar.component(.hour, from: now),
            surfaceHistory: inputs.surfaceHistory,
            narrativeHeat: recentEvents,
            hasFreshEntityMemory: freshMemory,
            minutesToNextCalendarEvent: nextEventMinutes,
            distressActive: distressActive,
            greyLevel: NothingTide.greyLevel(
                quietDays: inputs.quietDays,
                narrativeHeat: recentEvents,
                distressActive: distressActive,
                celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: inputs.hemisphere)
                    + BookJumpEngine.greyShift(state: inputs.bookJump, now: now)
                    + RadioStationRegistry.greyShift(state: inputs.radio, now: now)
            ),
            reshelvedSourceIDs: FaeGiftEffects.reshelvedSourceIDs(
                state: inputs.faeState,
                surfaceHistory: inputs.surfaceHistory,
                now: now
            ),
            pactWar: inputs.pactWar,
            almanacBoosts: Almanac.surfaceBoosts(on: now, hemisphere: inputs.hemisphere)
                .merging(BookJumpEngine.surfaceBoosts(state: inputs.bookJump, now: now)) { $0 + $1 }
                .merging(RadioStationRegistry.surfaceBoosts(state: inputs.radio, unlockedPackIDs: inputs.ownedPackIDs)) { $0 + $1 }
                .merging(RadioStationRegistry.heldSurfaceBoosts(state: inputs.radio)) { $0 + $1 },
            isFirstHours: firstHoursActive(inputs: inputs, now: now),
            keptPageCount: inputs.keptPageCount,
            composedTypesToday: composedCompositionTypes(in: inputs.days, on: now, calendar: calendar)
        )
    }

    /// Which blank-page prompts the reader has already answered today — so the
    /// desk doesn't keep asking for a page they've already written.
    private static func composedCompositionTypes(in days: [BookDay], on date: Date, calendar: Calendar) -> Set<BookPageType> {
        var types: Set<BookPageType> = []
        for day in days {
            for page in day.pages where page.type.isCompositionPrompt {
                if calendar.isDate(page.createdAt, inSameDayAs: date) {
                    types.insert(page.type)
                }
            }
        }
        return types
    }

    func allows(_ page: SurfacePage) -> Bool {
        guard isFirstHours else { return true }
        if page.type == .bookJump,
           let action = page.payload.metadata["bookJumpAction"],
           action != BookJumpAction.start.rawValue {
            return true
        }
        return !Self.firstHoursHiddenTypes.contains(page.type)
    }

    func allowsTypeRefresh(for page: SurfacePage, now: Date = Date()) -> Bool {
        guard let record = surfaceHistory[CuratorVarietyGovernor.typeKey(for: page.type)] else {
            return true
        }
        return now.timeIntervalSince(record.lastShownAt) >= Self.typeRefreshCooldown
    }

    func adjustment(for page: SurfacePage, now: Date = Date()) -> Int {
        // When the day is hard, the Book goes quiet: no ambiance, no
        // variety games — the distress-aware base scores choose care first.
        if distressActive {
            return 0
        }
        var delta = CuratorTimeAffinity.boost(for: page.type, at: now)

        if isFirstHours {
            delta += Self.firstHoursOrientationBoosts[page.type] ?? 0
        }

        delta -= CuratorVarietyGovernor.fatiguePenalty(forKey: page.varietyKey, history: surfaceHistory, now: now)
        delta -= quietReflectionPenalty(for: page, now: now)

        // Don't nag for writing the reader has already done today: a page they
        // already wrote drops hard, and once they've composed anything the
        // remaining blank-page prompts lean back so the desk can reward instead.
        if page.type.isCompositionPrompt {
            if composedTypesToday.contains(page.type) {
                delta -= 30
            } else if !composedTypesToday.isEmpty {
                delta -= 12
            }
        }

        // A warm Reshelving gift pulls one resting kind of page back to the front.
        if reshelvedSourceIDs.contains(page.sourceID) {
            delta += 16
        }

        // A Talisman that holds a shelf (Controlled+) shapes its timing.
        delta += PactWarEffects.shelfBoost(for: page.type, state: pactWar)

        // The Almanac leans the feast's themes forward.
        delta += almanacBoosts[page.type] ?? 0
        delta += wonderCompassFocusBoost(for: page)

        // Narrative heat: a field full of fresh events favors story-bearing
        // pages; a cold field favors pages that gather new material.
        let storyBearing: Set<BookPageType> = [.narrativeOS, .bookFae, .gossip, .letter, .illustration, .supportGuild]
        let materialGathering: Set<BookPageType> = [.diary, .mood, .aboutYou, .souvenir]
        if narrativeHeat >= 6, storyBearing.contains(page.type) {
            delta += min(8, narrativeHeat / 2)
        } else if narrativeHeat == 0, materialGathering.contains(page.type) {
            delta += 4
        }
        if hasFreshEntityMemory, ["cast", "location"].contains(page.payload.metadata["illustrationKind"]) {
            delta += 4
        }

        // The Nothing's tide: when the grey is up, its pages step forward
        // and material-gathering pages get a small lantern. At grey zero
        // the Nothing pages stay in the deep stacks — reward by absence.
        if greyLevel >= 1 {
            if page.payload.metadata["packArchetypeID"] == "the-nothing-stirs" || page.payload.metadata["packArchetypeID"] == "grey-margin" {
                delta += 6 + greyLevel * 4
            }
            if [.diary, .souvenir, .mood].contains(page.type) {
                delta += greyLevel * 2
            }
        } else if page.payload.metadata["packArchetypeID"] == "the-nothing-stirs" {
            delta -= 10
        }

        // A real-world hinge approaching: keep the desk light.
        if let minutes = minutesToNextCalendarEvent, minutes <= 45 {
            let heavy: Set<BookPageType> = [.narrativeOS, .bookFae, .marginsAtlas, .bookConnections, .bookRemembered, .gossip, .facultyResearch, .letter, .supportGuild, .bookOfYou, .bookJump]
            if heavy.contains(page.type) {
                delta -= 12
            }
            if page.type == .calendar {
                delta += 10
            }
        }
        return delta
    }

    private func wonderCompassFocusBoost(for page: SurfacePage) -> Int {
        guard page.type == .wonderCompass else { return 0 }
        if page.payload.metadata["playfulMissionID"]?.nonEmpty != nil {
            return 12
        }
        if page.payload.metadata["compassStep"] == CompassRunStep.notice.rawValue,
           page.payload.metadata["compassMode"] == "standalone" {
            return 8
        }
        return 0
    }

    private static let firstHoursDuration: TimeInterval = 6 * 3600
    private static let typeRefreshCooldown: TimeInterval = 30 * 60

    private static let firstHoursHiddenTypes: Set<BookPageType> = [
        .faeBargain,
        .bookRemembered,
        .bookConnections,
        .marginsAtlas,
        .theBleed,
        .bookJump,
        .pactDispatch,
        .pactVerdict,
        .pactErrand
    ]

    private static let firstHoursOrientationBoosts: [BookPageType: Int] = [
        .helpTips: 18,
        .welcome: 16,
        .lore: 10,
        .mood: 10,
        .fuel: 10,
        .body: 8,
        .weather: 8,
        .souvenir: 8,
        .wonderCompass: 6,
        .narrativeOS: 4,
        .calendar: 4,
        .quip: 3,
        .rest: 3
    ]

    private static func firstHoursActive(inputs: BookSourceInputs, now: Date) -> Bool {
        let pageDates = inputs.days.flatMap(\.pages).map(\.createdAt)
        let selfFactDates = inputs.selfFacts.map(\.createdAt)
        let firstTouch = (pageDates + selfFactDates).min()
        guard let firstTouch else {
            return inputs.days.isEmpty
                && inputs.selfFacts.isEmpty
                && inputs.surfaceHistory.isEmpty
                && inputs.body == nil
                && inputs.weather == nil
                && inputs.enchantedWeather == nil
                && inputs.narrative == nil
        }
        return now.timeIntervalSince(firstTouch) < firstHoursDuration
    }

    private func quietReflectionPenalty(for page: SurfacePage, now: Date) -> Int {
        let quietTypes: Set<BookPageType> = [.marginsAtlas, .bookConnections, .bookRemembered, .bookNotices]
        guard quietTypes.contains(page.type) else { return 0 }

        var penalty = 4
        let sourceKeys = ["source:\(page.sourceID)", page.varietyKey]
        let recentRecords = sourceKeys.compactMap { surfaceHistory[$0] }
        let recentHours = recentRecords.map { now.timeIntervalSince($0.lastShownAt) / 3600 }
        if recentHours.contains(where: { $0 < 24 }) {
            penalty += 24
        } else if recentHours.contains(where: { $0 < 72 }) {
            penalty += 14
        } else if recentHours.contains(where: { $0 < 168 }) {
            penalty += 6
        }
        if recentRecords.contains(where: { $0.recentShowCount >= 2 }) {
            penalty += 8
        }
        return penalty
    }
}
