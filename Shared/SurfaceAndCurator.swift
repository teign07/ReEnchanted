import Foundation


/// The nightly braid follows the last braid, not the civil calendar. A Page
/// kept at 10 p.m. after the 9:30 braid belongs to the next loose bundle even
/// after midnight passes.
struct NightlyBraidWindow {
    static func pendingPages(
        for day: BookDay,
        previousDays: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BookPage] {
        let archive = uniquePages(in: previousDays + [day])
        let lastBraidAt = archive
            .filter { $0.type == .bookOfYou && $0.createdAt <= now }
            .map(\.createdAt)
            .max()
        // Before the Book has ever braided, retain the established first-day
        // behavior rather than pulling an arbitrarily large archive into its
        // first local-model prompt.
        let floor = lastBraidAt ?? calendar.startOfDay(for: now)

        return archive
            .filter { page in
                page.type != .bookOfYou
                    && BraidPromptBuilder.isBraidEligible(page)
                    && !page.usedInBookOfYou
                    && page.createdAt > floor
                    && page.createdAt <= now
            }
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    }

    static func readingDay(
        for day: BookDay,
        previousDays: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BookDay {
        let pending = pendingPages(
            for: day,
            previousDays: previousDays,
            now: now,
            calendar: calendar
        )
        return BookDay(
            id: day.id,
            date: day.date,
            pages: pending,
            captureWindowPageIDs: pending.map(\.id)
        )
    }

    static func readingDay(
        for day: BookDay,
        pageIDs: Set<String>,
        previousDays: [BookDay]
    ) -> BookDay {
        let pages = uniquePages(in: previousDays + [day])
            .filter { pageIDs.contains($0.id) && BraidPromptBuilder.isBraidEligible($0) }
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        return BookDay(
            id: day.id,
            date: day.date,
            pages: pages,
            captureWindowPageIDs: pages.map(\.id)
        )
    }

    private static func uniquePages(in days: [BookDay]) -> [BookPage] {
        var pagesByID: [String: BookPage] = [:]
        for page in days.flatMap(\.pages) {
            pagesByID[page.id] = page
        }
        return Array(pagesByID.values)
    }
}


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

    static func dayByMarkingCapturedPagesUsed(
        _ day: BookDay,
        braid: BookPage,
        usedPageIDs: Set<String>? = nil
    ) -> BookDay {
        var updatedDay = day
        let capturedIDs = usedPageIDs ?? Set(day.capturedPages.map(\.id))
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

    /// Marks every Page consumed by a cross-midnight braid in its actual
    /// archived day. The generated braid itself is still seated on today.
    static func daysByMarkingPagesUsed(
        _ days: [BookDay],
        pageIDs: Set<String>
    ) -> [BookDay] {
        days.map { day in
            var updatedDay = day
            updatedDay.pages = day.pages.map { page in
                guard pageIDs.contains(page.id) else { return page }
                var updated = page
                updated.usedInBookOfYou = true
                return updated
            }
            return updatedDay
        }
    }

    /// What happened when tonight's braid met the one already on the day.
    enum Adoption: Equatable {
        /// There was no braid yet, or the new page won the tasting.
        case adopted
        /// A braid already on the day read better, so it stays official.
        /// The new page is still on the day unless the caller asked to replace.
        case keptExisting
    }

    /// Adopt a finished braid, deciding *by quality* which page is the day's
    /// official Book of You.
    ///
    /// `BookDay.bookOfYou` reads the last braid on the day, so before this
    /// existed "which braid is official" was decided by whichever generation
    /// finished most recently. A reader who asked for another one and got a
    /// thinner page silently lost the page they preferred. The same selector
    /// that picks between candidates inside one generation now also picks
    /// between generations, and the winner is re-seated last.
    ///
    /// - Parameter replacingPrior: `true` for "re-braid the last", where the
    ///   reader asked for a replacement rather than a second page. Even then a
    ///   worse rewrite is discarded: unravelling is a request for a better
    ///   page, not a promise to accept whatever comes back.
    static func dayByAdoptingBraid(
        _ day: BookDay,
        braid: BookPage,
        usedPageIDs: Set<String>? = nil,
        context: BraidPromptBuilder.Context,
        replacingPrior: Bool = false
    ) -> (day: BookDay, adoption: Adoption) {
        let priorBraids = day.pages.filter { $0.type == .bookOfYou }
        var updatedDay = dayByMarkingCapturedPagesUsed(
            day,
            braid: braid,
            usedPageIDs: usedPageIDs
        )
        guard let incumbent = priorBraids.last else {
            return (updatedDay, .adopted)
        }

        let winner = BraidGenerationSelector.bestUsable(
            from: [incumbent, braid],
            day: updatedDay,
            context: context
        )?.page
        // A tasting that cannot separate them (both register-broken, say) keeps
        // the page the reader already has rather than churning it.
        let newPageWon = winner?.id == braid.id

        if newPageWon {
            if replacingPrior {
                updatedDay.pages.removeAll { $0.id == incumbent.id }
            }
            return (updatedDay, .adopted)
        }

        if replacingPrior {
            updatedDay.pages.removeAll { $0.id == braid.id }
            return (updatedDay, .keptExisting)
        }
        // Keep both, but re-seat the incumbent last so it stays official.
        if let index = updatedDay.pages.firstIndex(where: { $0.id == incumbent.id }) {
            let page = updatedDay.pages.remove(at: index)
            updatedDay.pages.append(page)
        }
        return (updatedDay, .keptExisting)
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
        case .gossip, .bookAside:
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
        case .gossip, .bookAside:
            return !hasNonEmptyMetadata("gossipProse")
        case .note:
            return !hasNonEmptyMetadata("noteProse")
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
            return .blocked(message: "I'm already writing. One moment, please.")
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
        var assets = BookPageMediaAsset.decodedFromSurfaceMetadata(
            payload.metadata[BookPageMediaAsset.surfaceMetadataKey]
        )
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
        if let kindRawValue = nonEmptyMetadataValue("imageAssetKind"),
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
        if type == .bookPocket,
           let encodedKeepsakes = payload.metadata[PocketKeepsakeArchive.metadataKey] {
            assets.append(contentsOf: PocketKeepsakeArchive.decode(encodedKeepsakes)
                .flatMap { $0.mediaAssets ?? [] })
        }
        if type == .theBleed,
           let encodedPlates = payload.metadata[TheBleedEditionBuilder.plateAssetsMetadataKey] {
            assets.append(contentsOf: TheBleedEditionBuilder.decodedPlateAssets(encodedPlates))
        }
        var seenMedia = Set<String>()
        assets = assets.filter { asset in
            seenMedia.insert("\(asset.kind.rawValue):\(asset.reference)").inserted
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
        reason: String = "I have a little room for this page.",
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
        case .askTheBook, .anchor, .inkrestOfficeHours, .tarot:
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
        case .taleBound:
            // Bound whole and handed over. There is nothing to answer.
            return .reflect
        case .castBond:
            return .importReference
        case .body, .fuel, .facultyResearch, .supportGuild, .weather, .note, .letter, .academyClass, .bookConnections, .bookNotices, .glowInvitation, .theBleed, .todaysSky, .bookJump, .radio, .inventory, .gamePage:
            return .reflect
        case .elective:
            return .capture
        case .wickerDare:
            return .capture
        case .packPage, .wordNegotiation:
            return .reflect
        case .calendar:
            return .reflect
        case .wonderCompass, .lore, .patreon, .illustration, .quip, .quotes, .helpTips, .welcome, .marginsAtlas, .bindery:
            return .importReference
        case .affirmations:
            return .reflect
        case .enchantment:
            return .capture
        case .illuminatedPhoto, .bookRemembered, .bookPocket, .frontMatter:
            return .resurface
        case .location:
            return .reflect
        case .narrativeOS:
            return .simulate
        case .gossip, .bookAside:
            return .simulate
        case .mood, .diary, .souvenir, .aboutYou, .plainPage:
            return .capture
        }
    }

    private func nonEmptyMetadataValue(_ key: String) -> String? {
        let value = payload.metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}

// MARK: - Exact-Page capability contract

/// Private stage directions for what one concrete Page can honestly ask of the
/// reader and what kind of lived result it can create. This belongs to the
/// exact Page, not merely its Page type: two Wonder Compass Pages can require
/// very different amounts of time, movement, context, and courage.
///
/// Legacy Pages receive a conservative inferred contract. Authored adapters
/// can attach a precise contract without changing SurfacePage's persisted
/// shape, because the versioned contract travels in string-only metadata.
enum PageCapabilityAuthorship: String, Codable, Equatable {
    case inferred
    case authored
}

enum PageCapabilityEffort: String, Codable, Equatable, CaseIterable {
    case glance
    case small
    case involved
}

/// How much of the desk's ordinary taste the Curator will give up rather than
/// hand back a shelf that is emptier than its material.
///
/// Ordered by cost: the ask caps go first because a second writing prompt is
/// merely less elegant, while a second debut or commission spends something the
/// reader feels. Nothing here can lift a correctness rule.
enum DeskCapRelaxation: Int, CaseIterable {
    case none
    case asks
    case debutsAndActions

    /// The order the Curator is willing to give things up in.
    static let escalation: [DeskCapRelaxation] = [.asks, .debutsAndActions]

    var liftsAskCaps: Bool { self != .none }
    var liftsDebutAndActionCaps: Bool { self == .debutsAndActions }
}

enum PageCapabilityReach: String, Codable, Equatable, CaseIterable {
    case insideBook
    case nearbyWorld
    case plannedWorld
}

enum PageCapabilityMobility: String, Codable, Equatable, CaseIterable {
    case stationary
    case shortDistance
    case extendedTravel
}

enum PageCapabilityCost: String, Codable, Equatable, CaseIterable {
    case free
    case optionalSpend
}

enum PageCapabilityProofMode: String, Codable, Equatable, CaseIterable {
    case response
    case observation
    case photograph
    case voice
    case place
    case person
}

enum PageEmotionalFunction: String, Codable, Equatable, CaseIterable {
    case soothe
    case notice
    case wonder
    case play
    case connect
    case express
    case remember
    case act
}

/// Only genuine prerequisites are hard gates. Preferences, present capacity,
/// effort, reach, and emotional fit remain weighted pressures so an imperfect
/// inference can never silently make an otherwise possible Page disappear.
enum PageCapabilityRequirement: String, Codable, Equatable, CaseIterable {
    case weatherContext
    case locationContext
    case nearbyPlace
    case nearbyAnchor
    case openCalendarWindow
    case someCapacity
    case wideCapacity
}

struct PageCapabilityContract: Codable, Equatable {
    static let currentVersion = 1
    static let metadataKey = "pageCapabilityContract"

    var version: Int
    var authorship: PageCapabilityAuthorship
    var supportedMovements: [BookReenchantmentMovement]
    var supportedRoles: [BookSessionRole]
    var emotionalFunctions: [PageEmotionalFunction]
    var effort: PageCapabilityEffort
    var reach: PageCapabilityReach
    var mobility: PageCapabilityMobility
    var cost: PageCapabilityCost
    var estimatedMinutes: Int
    var asksReader: Bool
    /// 0 means nearly frictionless; 1 means a high-pressure commission.
    var pressureCost: Double
    var proofModes: [PageCapabilityProofMode]
    var requirements: [PageCapabilityRequirement]

    init(
        version: Int = PageCapabilityContract.currentVersion,
        authorship: PageCapabilityAuthorship = .authored,
        supportedMovements: [BookReenchantmentMovement] = BookReenchantmentMovement.allCases,
        supportedRoles: [BookSessionRole] = BookSessionRole.allCases,
        emotionalFunctions: [PageEmotionalFunction] = [.notice],
        effort: PageCapabilityEffort = .small,
        reach: PageCapabilityReach = .insideBook,
        mobility: PageCapabilityMobility = .stationary,
        cost: PageCapabilityCost = .free,
        estimatedMinutes: Int = 5,
        asksReader: Bool = false,
        pressureCost: Double = 0.08,
        proofModes: [PageCapabilityProofMode] = [],
        requirements: [PageCapabilityRequirement] = []
    ) {
        self.version = version
        self.authorship = authorship
        self.supportedMovements = supportedMovements
        self.supportedRoles = supportedRoles
        self.emotionalFunctions = emotionalFunctions
        self.effort = effort
        self.reach = reach
        self.mobility = mobility
        self.cost = cost
        self.estimatedMinutes = max(1, estimatedMinutes)
        self.asksReader = asksReader
        self.pressureCost = max(0, min(1, pressureCost))
        self.proofModes = proofModes
        self.requirements = requirements
    }

    var signature: String {
        let parts = [
            "v\(version)", authorship.rawValue,
            supportedMovements.map(\.rawValue).sorted().joined(separator: "."),
            supportedRoles.map(\.rawValue).sorted().joined(separator: "."),
            emotionalFunctions.map(\.rawValue).sorted().joined(separator: "."),
            effort.rawValue, reach.rawValue, mobility.rawValue, cost.rawValue,
            String(estimatedMinutes), String(asksReader), String(pressureCost),
            proofModes.map(\.rawValue).sorted().joined(separator: "."),
            requirements.map(\.rawValue).sorted().joined(separator: ".")
        ]
        return "page-capability-v\(version)-\(abs(parts.joined(separator: "|").stableHash))"
    }

    func isEligible(in mood: CuratorMood) -> Bool {
        requirements.allSatisfy { requirement in
            switch requirement {
            case .weatherContext:
                return mood.hasWeatherContext
            case .locationContext:
                return mood.hasCoarseLocationContext
            case .nearbyPlace:
                return mood.hasNearbyPlaces
            case .nearbyAnchor:
                return mood.hasNearbyAnchor
            case .openCalendarWindow:
                guard let minutes = mood.minutesToNextCalendarEvent else { return true }
                return minutes > estimatedMinutes + 10
            case .someCapacity:
                guard let capacity = mood.readerCurrentState.capacity else { return true }
                return capacity >= 4
            case .wideCapacity:
                guard let capacity = mood.readerCurrentState.capacity else { return true }
                return capacity >= 8
            }
        }
    }

    /// Soft fit for the reader's actual moment. Every eligible Page keeps a
    /// nonzero path; this changes probability, never possibility.
    func selectionMultiplier(
        mood: CuratorMood,
        movement: BookReenchantmentMovement?,
        role: BookSessionRole?
    ) -> Double {
        var multiplier = 1.0

        if authorship == .authored, let movement, !supportedMovements.isEmpty {
            multiplier *= supportedMovements.contains(movement) ? 1.14 : 0.72
        }
        if authorship == .authored, let role, !supportedRoles.isEmpty {
            multiplier *= supportedRoles.contains(role) ? 1.08 : 0.80
        }

        if let capacity = mood.readerCurrentState.capacity {
            if capacity <= 3 {
                switch effort {
                case .glance: multiplier *= 1.30
                case .small: multiplier *= 0.78
                case .involved: multiplier *= 0.34
                }
                if asksReader { multiplier *= 0.82 }
            } else if capacity >= 8 {
                switch effort {
                case .glance: multiplier *= 0.94
                case .small: multiplier *= 1.04
                case .involved: multiplier *= 1.16
                }
            }
        }

        if mood.upcomingCalendarEventCount >= 3
            || (mood.minutesToNextCalendarEvent.map { $0 <= 45 } ?? false) {
            multiplier *= effort == .glance ? 1.20 : (effort == .involved ? 0.58 : 0.88)
        }

        if mood.distressActive {
            multiplier *= emotionalFunctions.contains(.soothe) ? 1.28 : 1
            multiplier *= pressureCost >= 0.75 ? 0.28 : (asksReader ? 0.72 : 1.08)
        }

        let profile = mood.declaredCuration
        if reach != .insideBook {
            switch profile.leavingHome {
            case "keep wonder indoors": multiplier *= 0.22
            case "only when i choose it", "ask gently": multiplier *= 0.62
            default: break
            }
        }
        if mobility != .stationary,
           let access = profile.movementAccess,
           ["short distances", "seated options", "no stairs"].contains(access) {
            multiplier *= mobility == .extendedTravel ? 0.24 : 0.58
        }
        if let budget = profile.timeBudget {
            if budget == "one minute" {
                multiplier *= estimatedMinutes <= 1 ? 1.22 : (estimatedMinutes > 10 ? 0.30 : 0.66)
            } else if budget == "ten minutes", estimatedMinutes > 10 {
                multiplier *= 0.54
            }
        }
        if cost == .optionalSpend,
           (profile.moneyBoundary == "free by default" || profile.moneyBoundary == "ask first") {
            multiplier *= 0.34
        }

        return max(0.04, min(2.4, multiplier))
    }

    func branchMultiplier(for branch: BookPreparedExperimentBranch) -> Double {
        switch branch {
        case .afterDismissal:
            if pressureCost >= 0.75 { return 0.06 }
            if asksReader || pressureCost >= 0.30 { return 0.24 }
            if emotionalFunctions.contains(.soothe) { return 1.80 }
            return 1.05
        case .afterKeep:
            if emotionalFunctions.contains(.remember) || emotionalFunctions.contains(.connect) {
                return 1.45
            }
            if pressureCost >= 0.75 { return 0.62 }
            return 1.08
        case .current, .adaptive:
            return 1
        }
    }

    func applying(to surface: SurfacePage) -> SurfacePage {
        guard let data = try? JSONEncoder().encode(self) else { return surface }
        return surface.withMetadata([
            Self.metadataKey: data.base64EncodedString(),
            "pageCapabilityVersion": String(version),
            "pageCapabilitySignature": signature,
            "pageCapabilityAuthorship": authorship.rawValue,
            "pageCapabilityEffort": effort.rawValue,
            "pageCapabilityReach": reach.rawValue,
            "pageCapabilityEstimatedMinutes": String(estimatedMinutes),
            "pageCapabilityPressureCost": String(pressureCost),
            "pageCapabilityProofModes": proofModes.map(\.rawValue).joined(separator: ","),
            "pageCapabilityEmotionalFunctions": emotionalFunctions.map(\.rawValue).joined(separator: ",")
        ])
    }

    static func read(from surface: SurfacePage) -> PageCapabilityContract? {
        guard let encoded = surface.payload.metadata[metadataKey],
              let data = Data(base64Encoded: encoded),
              let contract = try? JSONDecoder().decode(PageCapabilityContract.self, from: data),
              contract.version == currentVersion else {
            return nil
        }
        return contract
    }

    static func inferred(for page: SurfacePage) -> PageCapabilityContract {
        let tags = Set((page.payload.metadata["tags"] ?? "")
            .split(separator: ",")
            .map { String($0).readerLearningNormalizedTag })
        let action = page.isReaderActionCommission
        let asks = page.isReaderFacingAsk

        let effort: PageCapabilityEffort
        if action || [.bookJump, .facultyResearch, .marginsAtlas, .narrativeOS].contains(page.type) {
            effort = .involved
        } else if asks || page.type.isCompositionPrompt {
            effort = .small
        } else {
            effort = .glance
        }

        let reach: PageCapabilityReach
        if [.bookJump, .festival, .calendar].contains(page.type) {
            reach = .plannedWorld
        } else if [.wonderCompass, .anchor, .location, .pactErrand, .wickerDare, .elective].contains(page.type)
                    || !tags.isDisjoint(with: ["outward", "walking", "outing"]) {
            reach = .nearbyWorld
        } else {
            reach = .insideBook
        }

        let emotionalFunctions: [PageEmotionalFunction]
        switch page.type {
        case .rest, .body, .fuel, .weather, .radio:
            emotionalFunctions = [.soothe, .notice]
        case .wonderCompass, .todaysSky, .location, .enchantment, .illuminatedPhoto:
            emotionalFunctions = [.notice, .wonder]
        case .quip, .gamePage, .wickerDare, .bookFae:
            emotionalFunctions = [.play, .wonder]
        case .letter, .castBond, .supportGuild, .bookConnections:
            emotionalFunctions = [.connect]
        case .diary, .mood, .aboutYou, .plainPage:
            emotionalFunctions = [.express]
        case .souvenir, .bookRemembered, .bookPocket:
            emotionalFunctions = [.remember]
        default:
            emotionalFunctions = action ? [.act, .wonder] : [.notice]
        }

        var proofModes: [PageCapabilityProofMode] = []
        if page.type.isCompositionPrompt || [.mood, .aboutYou].contains(page.type) { proofModes.append(.response) }
        if action || [.wonderCompass, .souvenir].contains(page.type) { proofModes.append(.observation) }
        if [.illuminatedPhoto, .enchantment].contains(page.type) { proofModes.append(.photograph) }
        if [.location, .anchor].contains(page.type) { proofModes.append(.place) }
        if [.letter, .castBond, .supportGuild].contains(page.type) { proofModes.append(.person) }

        let pressure: Double
        if action { pressure = 1 }
        else if page.type.isCompositionPrompt { pressure = 0.55 }
        else if asks { pressure = 0.35 }
        else { pressure = 0.08 }

        return PageCapabilityContract(
            authorship: .inferred,
            emotionalFunctions: emotionalFunctions,
            effort: effort,
            reach: reach,
            mobility: reach == .insideBook ? .stationary : (reach == .plannedWorld ? .extendedTravel : .shortDistance),
            cost: tags.isDisjoint(with: ["spend", "shopping", "purchase", "paid"])
                && !page.opensSpending ? .free : .optionalSpend,
            estimatedMinutes: effort == .glance ? 1 : (effort == .small ? 5 : 20),
            asksReader: asks,
            pressureCost: pressure,
            proofModes: proofModes
        )
    }
}

/// How an exact Page crosses, or deliberately does not cross, the boundary
/// between the Book and ordinary life.
///
/// This is not another curation score. It resolves the selected Page's
/// capability into an epistemic promise: what the Page may invite, what sort
/// of return it may accept, and whether a lived receipt is even possible.
enum LivedEncounterMode: String, Codable, Equatable, CaseIterable {
    /// The experience completes inside the Book. A Story choice or Diary answer
    /// may matter deeply, but cannot be evidence that ordinary life changed.
    case contained
    /// The Page may direct attention outward without asking the reader to
    /// perform or report anything.
    case witness
    /// The Page gently offers an outward action and an optional return.
    case invitation
    /// The Page explicitly commissions an outward action.
    case commission
}

/// A universal, versioned law for the seam between Pages and lived evidence.
///
/// Every selected Page receives one. Most Pages are honestly `.contained`.
/// Outward Pages can name an invitation and the evidence they are permitted to
/// recognize, but the contract never claims that opening, keeping, proximity,
/// or generated prose proves an encounter occurred.
struct LivedEncounterContract: Codable, Equatable {
    static let currentVersion = 1
    static let metadataKey = "livedEncounterContract"

    var version: Int
    var authorship: PageCapabilityAuthorship
    var mode: LivedEncounterMode
    var encounterID: String
    var invitation: String
    var returnPrompt: String
    var acceptedProofModes: [PageCapabilityProofMode]
    var facets: [LivedWonderFacet]
    /// Nil means the Book owes no scheduled outcome question. A non-nil value
    /// is only a lower bound; a later governor may wait longer or stay silent.
    var earliestFollowUpHours: Int?
    var sourceCapabilitySignature: String

    init(
        version: Int = LivedEncounterContract.currentVersion,
        authorship: PageCapabilityAuthorship = .authored,
        mode: LivedEncounterMode,
        encounterID: String,
        invitation: String = "",
        returnPrompt: String = "",
        acceptedProofModes: [PageCapabilityProofMode] = [],
        facets: [LivedWonderFacet] = [],
        earliestFollowUpHours: Int? = nil,
        sourceCapabilitySignature: String = ""
    ) {
        self.version = version
        self.authorship = authorship
        self.mode = mode
        self.encounterID = encounterID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.invitation = invitation.trimmingCharacters(in: .whitespacesAndNewlines)
        self.returnPrompt = returnPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.acceptedProofModes = acceptedProofModes.reduce(into: []) { result, mode in
            if !result.contains(mode) { result.append(mode) }
        }.sorted { $0.rawValue < $1.rawValue }
        self.facets = facets.reduce(into: []) { result, facet in
            if !result.contains(facet) { result.append(facet) }
        }.sorted { $0.rawValue < $1.rawValue }
        self.earliestFollowUpHours = earliestFollowUpHours.map { max(1, $0) }
        self.sourceCapabilitySignature = sourceCapabilitySignature
    }

    var signature: String {
        let parts = [
            "v\(version)",
            authorship.rawValue,
            mode.rawValue,
            encounterID,
            invitation,
            returnPrompt,
            acceptedProofModes.map(\.rawValue).joined(separator: "."),
            facets.map(\.rawValue).joined(separator: "."),
            earliestFollowUpHours.map(String.init) ?? "",
            sourceCapabilitySignature
        ]
        return "lived-encounter-v\(version)-\(abs(parts.joined(separator: "|").stableHash))"
    }

    /// A contract can authorize a receipt; it cannot create one. Returned
    /// evidence must still satisfy one of the accepted modes.
    var mayMintLivedReceipt: Bool {
        (mode == .invitation || mode == .commission)
            && !encounterID.isEmpty
            && !invitation.isEmpty
            && acceptedProofModes.contains(where: { $0 != .response })
    }

    func acceptedEvidenceModes(
        readerInput: String,
        mediaAssets: [BookPageMediaAsset]
    ) -> [PageCapabilityProofMode] {
        guard mayMintLivedReceipt else { return [] }
        let hasReaderWords = readerInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let hasPhotograph = mediaAssets.contains { asset in
            guard [.renderedImageFile, .photoLibraryAsset].contains(asset.kind) else {
                return false
            }
            return asset.metadata["proofPhoto"] == "true"
                || asset.metadata["uneditedPhoto"] == "true"
                || asset.metadata["cameraSeal"] == "true"
                || asset.metadata["pressedPhotograph"] == "true"
                || asset.metadata["proofImagePath"]?.nonEmpty != nil
        }
        let hasVoice = mediaAssets.contains {
            $0.kind == .audioFile
                && ($0.metadata["keptVoice"] == "true" || $0.metadata["proofVoice"] == "true")
        }
        var evidence: [PageCapabilityProofMode] = []

        // Words are reader attestation, not independent verification. They may
        // satisfy an observation/place/person return, but a mere in-Book
        // response is deliberately excluded from lived proof.
        if hasReaderWords {
            evidence += acceptedProofModes.filter {
                [.observation, .place, .person].contains($0)
            }
        }
        if hasPhotograph, acceptedProofModes.contains(.photograph) {
            evidence.append(.photograph)
        }
        if hasVoice, acceptedProofModes.contains(.voice) {
            evidence.append(.voice)
        }
        return evidence.reduce(into: []) { result, mode in
            if !result.contains(mode) { result.append(mode) }
        }.sorted { $0.rawValue < $1.rawValue }
    }

    func applying(to surface: SurfacePage) -> SurfacePage {
        guard let data = try? JSONEncoder().encode(self) else { return surface }
        return surface.withMetadata([
            Self.metadataKey: data.base64EncodedString(),
            "livedEncounterVersion": String(version),
            "livedEncounterSignature": signature,
            "livedEncounterAuthorship": authorship.rawValue,
            "livedEncounterMode": mode.rawValue,
            "livedEncounterID": encounterID,
            "livedEncounterProofModes": acceptedProofModes.map(\.rawValue).joined(separator: ","),
            "livedEncounterFacets": facets.map(\.rawValue).joined(separator: ",")
        ])
    }

    static func read(from surface: SurfacePage) -> LivedEncounterContract? {
        guard let encoded = surface.payload.metadata[metadataKey],
              let data = Data(base64Encoded: encoded),
              let contract = try? JSONDecoder().decode(LivedEncounterContract.self, from: data),
              contract.version == currentVersion else {
            return nil
        }
        return contract
    }

    static func inferred(for surface: SurfacePage) -> LivedEncounterContract {
        let capability = surface.pageCapabilities
        let mode: LivedEncounterMode
        if capability.reach == .insideBook {
            mode = .contained
        } else if surface.spendsCuratorActionBudget {
            mode = .commission
        } else if capability.asksReader || surface.isReaderFacingAsk {
            mode = .invitation
        } else {
            mode = .witness
        }

        let metadata = surface.payload.metadata
        let encounterID = [
            metadata["playfulMissionID"],
            metadata["wickerDareID"],
            metadata["runID"],
            metadata["academyActivityID"],
            metadata["academyActivity"],
            metadata["pactErrandID"],
            metadata["errandID"],
            metadata["faeBargainID"],
            metadata["bargainID"],
            metadata["bookWorkingID"],
            metadata["bookCampaignID"],
            metadata["electiveID"]
        ]
            .compactMap { $0?.nonEmpty }
            .first
            ?? "encounter-\(abs("\(surface.sourceID)|\(surface.curatorContentNoveltyKey)".stableHash))"
        let invitation = metadata["missionPrompt"]?.nonEmpty
            ?? metadata["mission"]?.nonEmpty
            ?? metadata["wickerDarePrompt"]?.nonEmpty
            ?? metadata["electiveAsk"]?.nonEmpty
            ?? metadata["academyActivityInvitation"]?.nonEmpty
            ?? metadata["terms"]?.nonEmpty
            ?? metadata["bookCampaignIntendedEffect"]?.nonEmpty
            ?? surface.payload.body.nonEmpty
            ?? surface.detail.nonEmpty
            ?? surface.prompt
        let returnPrompt = metadata["souvenirPrompt"]?.nonEmpty
            ?? metadata["placeholder"]?.nonEmpty
            ?? metadata["electivePractice"]?.nonEmpty
            ?? metadata["proofPrompt"]?.nonEmpty
            ?? (mode == .invitation || mode == .commission
                ? "Bring back one exact thing that actually happened."
                : "")
        let proofModes = mode == .invitation || mode == .commission
            ? capability.proofModes.filter { $0 != .response }
            : []
        let facets = inferredFacets(from: capability)
        let followUpHours: Int?
        switch mode {
        case .commission:
            followUpHours = 24
        case .invitation:
            followUpHours = facets.contains(.deliberateReturn) ? 72 : 48
        case .contained, .witness:
            followUpHours = nil
        }
        return LivedEncounterContract(
            authorship: .inferred,
            mode: mode,
            encounterID: encounterID,
            invitation: invitation,
            returnPrompt: returnPrompt,
            acceptedProofModes: proofModes,
            facets: facets,
            earliestFollowUpHours: followUpHours,
            sourceCapabilitySignature: capability.signature
        )
    }

    private static func inferredFacets(
        from capability: PageCapabilityContract
    ) -> [LivedWonderFacet] {
        var facets: [LivedWonderFacet] = []
        func include(_ facet: LivedWonderFacet, when condition: Bool) {
            if condition, !facets.contains(facet) { facets.append(facet) }
        }

        include(.exactAttention, when:
            capability.emotionalFunctions.contains(.notice)
                || capability.emotionalFunctions.contains(.wonder)
                || capability.proofModes.contains(.observation)
        )
        include(.worldOtherness, when:
            capability.emotionalFunctions.contains(.wonder)
                && capability.reach != .insideBook
        )
        include(.selfAuthorship, when:
            capability.emotionalFunctions.contains(.act)
                || capability.emotionalFunctions.contains(.play)
        )
        include(.personalLanguage, when:
            capability.emotionalFunctions.contains(.express)
                || capability.proofModes.contains(.response)
        )
        include(.livingConnection, when:
            capability.emotionalFunctions.contains(.connect)
                || capability.proofModes.contains(.person)
        )
        include(.deliberateReturn, when:
            capability.emotionalFunctions.contains(.remember)
        )

        if capability.supportedMovements.count < BookReenchantmentMovement.allCases.count {
            for movement in capability.supportedMovements {
                switch movement {
                case .freshSight: include(.exactAttention, when: true)
                case .livingWorld: include(.worldOtherness, when: true)
                case .scriptFreedom: include(.scriptFreedom, when: true)
                case .chosenDetour: include(.selfAuthorship, when: true)
                case .exactLanguage: include(.personalLanguage, when: true)
                case .humanOtherness: include(.livingConnection, when: true)
                case .livingContinuity: include(.deliberateReturn, when: true)
                case .shelter: break
                }
            }
        }
        return Array(facets.prefix(3))
    }
}

extension SurfacePage {
    var pageCapabilities: PageCapabilityContract {
        PageCapabilityContract.read(from: self) ?? PageCapabilityContract.inferred(for: self)
    }

    func withPageCapabilities(_ contract: PageCapabilityContract) -> SurfacePage {
        contract.applying(to: self)
    }

    var livedEncounterContract: LivedEncounterContract {
        LivedEncounterContract.read(from: self) ?? LivedEncounterContract.inferred(for: self)
    }

    func withLivedEncounterContract(_ contract: LivedEncounterContract) -> SurfacePage {
        contract.applying(to: self)
    }

    /// Stamps inferred legacy behavior as well as authored behavior onto the
    /// selected Page, making the exact decision inspectable in private receipts.
    func withResolvedPageCapabilities() -> SurfacePage {
        let capabilityResolved = pageCapabilities.applying(to: self)
        return capabilityResolved.livedEncounterContract.applying(to: capabilityResolved)
    }

    func withMetadata(_ additions: [String: String]) -> SurfacePage {
        var metadata = payload.metadata
        metadata.merge(additions) { _, new in new }
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
            reason: "Penny found a photo with some ink hiding on it!",
            prompt: "Found in the Margins",
            detail: "The Book spotted this in your camera roll and turned it into a page worth a look.",
            payload: BookPagePayload(
                headline: draft.analysis.marginalia.stampLabel,
                body: draft.analysis.marginalia.closingLine,
                metadata: metadata
            )
        )
    }
}

// MARK: - Hidden magic practice

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

/// From 8pm, the desk's evening resolution. On a day with kept pages it
/// teases the threads tonight's Book of You braid has already caught; on an
/// unwritten day it resolves the evening from the Book's own shelf instead:
/// rereading earlier days by lamplight, never counting what the reader owes.
/// Either way the reader gets a sanctioned ending without the braid's reveal
/// moving and without the desk going quiet.
enum BraidEmber {
    struct Ember: Equatable {
        enum Kind: Equatable {
            /// Two or three kept threads: tonight's braid is teased.
            case braid
            /// One kept thread: still enough to bind.
            case singleThread
            /// Nothing kept: the Book spends the evening on its own shelves.
            case lamplight
        }

        var kind: Kind
        var line: String
        var undertone: String
    }

    static let braidUndertone = "The Book of You braids tonight."
    static let lamplightUndertone = "Nothing owed. I found my own trouble."

    static let singleThreadLines = [
        "Tonight\u{2019}s braid holds one thread: {thread}. Watch what I get out of it.",
        "One thread on the desk tonight, {thread}, and I intend to make a scene of it.",
        "Tonight\u{2019}s braid starts at {thread}. That's plenty. I've worked with less."
    ]

    /// Lamplight lines when one earlier day offers an echo.
    static let rereadLines = [
        "You lived it instead of writing it. Fine. I pulled {echo} down again and it still works.",
        "Nothing crossed the desk today, so I reread {echo}. Holds up. I checked twice.",
        "Today stayed unwritten. {echo} kept me busy, and it will be smug about that.",
        "Empty desk. I had {echo} out all evening and I'm not putting it back yet."
    ]

    /// Lamplight lines when two earlier days can be laid side by side.
    static let rhymeLines = [
        "Nothing today, so I went through my own shelves: {echoA} next to {echoB}. They rhyme. I did that on purpose.",
        "The desk stayed clear, so I shoved {echoA} up against {echoB}. Neighbors now. They'll cope.",
        "An unwritten day, so I went digging: {echoA} still glows, and {echoB} hasn't moved an inch, the stubborn thing.",
        "No ink today. I spent it stacking {echoA} beside {echoB} to see what they'd do. They did something."
    ]

    /// Lamplight lines when the archive has nothing to reread yet.
    static let hearthLines = [
        "You lived today instead of writing it. I spent it arguing with the index.",
        "An unwritten day. I filled mine reorganizing the shelf by smell.",
        "No ink today. I've been prying at a page that won't open. Still won't.",
        "Nothing on the desk. I got on with my evening. It was eventful."
    ]

    static func evening(
        for day: BookDay,
        previousDays: [BookDay] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Ember? {
        guard calendar.component(.hour, from: now) >= 20 else { return nil }
        let threads = threadLabels(for: day)
        let seed = KeepMarginalia.seed(for: "ember:\(day.id)")
        switch threads.count {
        case 0:
            let echoes = eveningEchoes(before: day, previousDays: previousDays, now: now, calendar: calendar)
            let line: String
            switch echoes.count {
            case 0:
                line = hearthLines[Int(seed % UInt64(hearthLines.count))]
            case 1:
                line = rereadLines[Int((seed >> 8) % UInt64(rereadLines.count))]
                    .replacingOccurrences(of: "{echo}", with: echoes[0])
            default:
                line = rhymeLines[Int((seed >> 8) % UInt64(rhymeLines.count))]
                    .replacingOccurrences(of: "{echoA}", with: echoes[0])
                    .replacingOccurrences(of: "{echoB}", with: echoes[1])
            }
            return Ember(kind: .lamplight, line: line, undertone: lamplightUndertone)
        case 1:
            let line = singleThreadLines[Int((seed >> 8) % UInt64(singleThreadLines.count))]
                .replacingOccurrences(of: "{thread}", with: threads[0])
            return Ember(kind: .singleThread, line: line, undertone: braidUndertone)
        default:
            let countWord = threads.count == 2 ? "two" : "three"
            let joined = threads.count == 2
                ? "\(threads[0]) and \(threads[1])"
                : "\(threads[0]), \(threads[1]), and \(threads[2])"
            return Ember(
                kind: .braid,
                line: "Tonight\u{2019}s braid has caught \(countWord) threads: \(joined).",
                undertone: braidUndertone
            )
        }
    }

    /// Up to `limit` echo phrases from the most recent earlier days that kept
    /// anything, strongest label per day, deduped across days: "yesterday's
    /// harbor", "Tuesday's kettle", "the harbor from June 3".
    static func eveningEchoes(
        before day: BookDay,
        previousDays: [BookDay],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = 2
    ) -> [String] {
        // Day IDs are "YYYY-MM-DD", so lexicographic order is chronological.
        let prior = previousDays
            .filter { $0.id < day.id }
            .sorted { $0.id > $1.id }
            .prefix(30)
        var phrases: [String] = []
        var bareSeen: Set<String> = []
        for pastDay in prior {
            guard let label = threadLabels(for: pastDay).first else { continue }
            let bare = bareLabel(label)
            guard !bare.isEmpty, !bareSeen.contains(bare) else { continue }
            bareSeen.insert(bare)
            phrases.append(echoPhrase(bare: bare, dayDate: pastDay.date, now: now, calendar: calendar))
            if phrases.count >= limit { break }
        }
        return phrases
    }

    /// "harbor" from "the harbor" / "a weather".
    static func bareLabel(_ label: String) -> String {
        for article in ["the ", "a ", "an "] where label.hasPrefix(article) {
            return String(label.dropFirst(article.count))
        }
        return label
    }

    static func echoPhrase(bare: String, dayDate: Date, now: Date, calendar: Calendar = .current) -> String {
        let daysApart = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: dayDate),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if daysApart == 1 {
            return "yesterday\u{2019}s \(bare)"
        }
        if daysApart <= 6 {
            return "\(dayDate.formatted(.dateTime.weekday(.wide)))\u{2019}s \(bare)"
        }
        return "the \(bare) from \(dayDate.formatted(.dateTime.month(.wide).day()))"
    }

    /// The morning callback that pays off the evening ember: it names the exact
    /// same threads the ember promised, so the braid reveal reads as a kept
    /// promise instead of a scheduled delivery. Mirrors `evening(...)`'s three
    /// kept-thread cases; nil on an unwritten day, which had no promise to keep.
    static func keptPromiseLine(for day: BookDay) -> String? {
        let threads = threadLabels(for: day)
        switch threads.count {
        case 0:
            return nil
        case 1:
            return "Last night the braid held a single thread: \(threads[0]). Here is what it made of it."
        case 2:
            return "Last night the braid caught \(threads[0]) and \(threads[1]). Here is what it made of them."
        default:
            return "Last night the braid caught \(threads[0]), \(threads[1]), and \(threads[2]). Here is what it made of them."
        }
    }

    /// Up to three short labels for today's captured pages, strongest first.
    /// A page with prose is named by its most vivid word; a wordless log is
    /// named by its page type.
    static func threadLabels(for day: BookDay) -> [String] {
        threadLabels(for: day.capturedPages)
    }

    /// The same concrete-label selection over an arbitrary group of pages,
    /// used by the weekly Bindery so a promised thread can travel farther than
    /// a single evening.
    static func threadLabels(for pages: [BookPage]) -> [String] {
        let ranked = pages.sorted {
            let left = StorySpark.score($0.userInput.nonEmpty ?? $0.promptText)
            let right = StorySpark.score($1.userInput.nonEmpty ?? $1.promptText)
            if left == right { return $0.createdAt > $1.createdAt }
            return left > right
        }
        var labels: [String] = []
        for page in ranked {
            let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let label: String
            if let word = KeepMarginalia.featuredWord(in: text) {
                label = "the \(word)"
            } else if !text.isEmpty {
                label = "the \(page.type.shortTitle.lowercased())"
            } else {
                label = "a \(page.type.shortTitle.lowercased())"
            }
            if !labels.contains(label) { labels.append(label) }
            if labels.count == 3 { break }
        }
        return labels
    }
}

/// A page that leaves gets a warm, deterministic closing line. Rare permanent
/// fragments are no longer paid out for cycling through dismissals; they are
/// earned by distinct acts of attention through `AttentionKeepsakeGovernor`.
enum PartingWhisper {
    /// A recognizable fragment of the Page that left: its real title and words,
    /// plus any visual it carried. The Pocket keeps provenance rather than
    /// inventing a decorative object unrelated to the dismissed Page.
    struct Keepsake: Equatable {
        var object: String
        var glyph: String
        var title: String
        var excerpt: String
        var reason: String
        var mediaAssets: [BookPageMediaAsset]
    }

    struct Whisper: Equatable {
        enum Kind: Equatable {
            /// The common case: a small aside as the page slips away.
            case wink
            /// The rarer case: the page left a real object behind.
            case keepsake
        }

        var kind: Kind
        var line: String
        /// Present only for `.keepsake`: the object to press into the Pocket.
        var keepsake: Keepsake?
    }

    /// `{page}` is filled with the page's short title, matching the mundane
    /// dismissal line's "the <kind> page" phrasing.
    static let winkLines = [
        "The {page} page tips its hat on the way out.",
        "Off it goes. I pretend not to watch the {page} page leave.",
        "The {page} page wanders back into the stacks, whistling.",
        "Gone. The {page} page took something with it. I'll work out what.",
        "I let the {page} page go and immediately want it back.",
        "The {page} page bows out. The margins boo, briefly.",
        "Away it goes. The lamp leans after the {page} page like a nosy neighbour.",
        "The {page} page slips off into the stacks to sulk. It'll live."
    ]

    /// Weighty narrative and transactional cards keep their own partings, so the
    /// whisper stays out of their way.
    static let excludedTypes: Set<BookPageType> = [
        .bookOfYou, .bookPocket, .faeBargain, .pactVerdict, .pactErrand, .pactDispatch, .welcome
    ]

    static func isEligible(_ surface: SurfacePage) -> Bool {
        if excludedTypes.contains(surface.type) { return false }
        if surface.payload.metadata["purchaseThankYou"] == "true" { return false }
        return true
    }

    static func closingLine(for surface: SurfacePage) -> String? {
        guard isEligible(surface) else { return nil }
        let page = surface.type.shortTitle.lowercased()
        let lineIndex = Int(surface.id.stableHash.magnitude % UInt(winkLines.count))
        return winkLines[lineIndex]
            .replacingOccurrences(of: "{page}", with: page)
    }

    static func keepsake(from surface: SurfacePage, evidence: String) -> Keepsake {
        let title = clean(surface.payload.headline).nonEmpty
            ?? clean(surface.prompt).nonEmpty
            ?? surface.type.title
        let excerptCandidates = [evidence, surface.payload.body, surface.detail, surface.reason, surface.prompt]
            .map(clean)
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(title) != .orderedSame }
        let excerpt = clipped(excerptCandidates.first ?? title, limit: 420)
        return Keepsake(
            object: title,
            glyph: surface.type.symbolName,
            title: title,
            excerpt: excerpt,
            reason: clean(surface.reason),
            mediaAssets: Array(surface.mediaAssets.prefix(3))
        )
    }

    private static func clean(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        let prefix = value.prefix(limit)
        let end = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<end]) + "\u{2026}"
    }
}

enum AttentionKeepsakeGovernor {
    static let distinctActionsToEarn = 4

    /// Four different Pages must receive real attention since the last fragment.
    /// Opening, refreshing, and repeating the same Page never advance the gate.
    static func isEarned(in learning: ReaderLearningModel) -> Bool {
        let sinceLastKeepsake = learning.events.reversed().prefix {
            $0.action != .keepsakeEarned
        }
        let meaningfulSurfaceIDs = Set(sinceLastKeepsake.compactMap { event -> String? in
            switch event.action {
            case .acted, .kept, .loved, .followedThread:
                return event.surfaceID
            default:
                return nil
            }
        })
        return meaningfulSurfaceIDs.count >= distinctActionsToEarn
    }
}

/// One small thing a Page pressed loose after the reader gave it meaningful
/// attention, kept for good in the Book's Pocket.
struct PocketKeepsake: Identifiable, Codable, Equatable {
    let id: String
    let dayID: String
    let pageType: BookPageType
    /// Legacy display label. New keepsakes use the dismissed Page's headline.
    let object: String
    /// SF Symbol name shown beside it in the Pocket.
    let glyph: String
    let foundAt: Date
    /// Rich provenance added after the Pocket began keeping Page fragments.
    /// These are optional so previously stored decorative keepsakes still decode.
    let sourceSurfaceID: String?
    let title: String?
    let excerpt: String?
    let reason: String?
    let mediaAssets: [BookPageMediaAsset]?

    init(
        id: String,
        dayID: String,
        pageType: BookPageType,
        object: String,
        glyph: String,
        foundAt: Date,
        sourceSurfaceID: String? = nil,
        title: String? = nil,
        excerpt: String? = nil,
        reason: String? = nil,
        mediaAssets: [BookPageMediaAsset]? = nil
    ) {
        self.id = id
        self.dayID = dayID
        self.pageType = pageType
        self.object = object
        self.glyph = glyph
        self.foundAt = foundAt
        self.sourceSurfaceID = sourceSurfaceID
        self.title = title
        self.excerpt = excerpt
        self.reason = reason
        self.mediaAssets = mediaAssets
    }

    var isRealPageFragment: Bool {
        sourceSurfaceID?.isEmpty == false && excerpt?.isEmpty == false
    }
}

/// Rich keepsakes ride through string-only surface metadata as base-64 JSON.
/// The legacy line format remains alongside it so old Pocket Pages still open.
enum PocketKeepsakeArchive {
    static let metadataKey = "pocketKeepsakes"

    static func encode(_ keepsakes: [PocketKeepsake]) -> String {
        guard let data = try? JSONEncoder().encode(keepsakes) else { return "" }
        return data.base64EncodedString()
    }

    static func decode(_ encoded: String) -> [PocketKeepsake] {
        guard let data = Data(base64Encoded: encoded),
              let keepsakes = try? JSONDecoder().decode([PocketKeepsake].self, from: data) else {
            return []
        }
        return keepsakes
    }
}

/// The Book's Pocket: an accumulating collection of keepsakes. Newest keepsakes
/// push out the oldest once it fills, so it stays a pocket, not an archive.
struct PocketLedger: Codable, Equatable {
    private(set) var keepsakes: [PocketKeepsake] = []

    static let capacity = 60

    mutating func press(_ keepsake: PocketKeepsake) {
        keepsakes.removeAll { $0.id == keepsake.id }
        keepsakes.append(keepsake)
        if keepsakes.count > Self.capacity {
            keepsakes.removeFirst(keepsakes.count - Self.capacity)
        }
    }

    /// Most recently found first: the order the Pocket shows.
    var newestFirst: [PocketKeepsake] {
        keepsakes.sorted { $0.foundAt > $1.foundAt }
    }

    var isEmpty: Bool { keepsakes.isEmpty }
    var count: Int { keepsakes.count }
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

    /// Whether a moment falls inside a given window, by the clock rather than
    /// by any tag the page happens to carry. Pages kept outside the ordinary
    /// check-in path: the onboarding souvenir, an imported page, anything a
    /// future flow adds: are invisible to a tag test and would let the Book
    /// ask the same question twice in one window.
    static func window(_ window: DailyCheckInWindow, contains date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minute >= window.startMinute && minute < window.endMinute
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

enum ReaderAlivenessCurationContext {
    static func facets(inputs: BookSourceInputs, now: Date, calendar: Calendar = .current) -> Set<String> {
        var facets: Set<String> = []
        let hour = calendar.component(.hour, from: now)
        let dayPart: String
        switch hour {
        case 5...11: dayPart = "morning"
        case 12...16: dayPart = "afternoon"
        case 17...20: dayPart = "evening"
        default: dayPart = "night"
        }
        facets.insert("time:\(dayPart)")
        if let place = inputs.currentLocationLabel?.nonEmpty {
            facets.insert("place:\(place.readerLearningNormalizedTag)")
        }
        if let anchor = inputs.nearbyAnchor?.anchor.id.nonEmpty {
            facets.insert("anchor:\(anchor.readerLearningNormalizedTag)")
        }
        let weather = [inputs.weather?.phrase, inputs.enchantedWeather?.summary]
            .compactMap { $0 }.joined(separator: " ").lowercased()
        let weatherTerms = ["rain", "storm", "snow", "wind", "fog", "mist", "cloud", "sun", "clear", "heat", "cold"]
        for term in weatherTerms where weather.contains(term) {
            facets.insert("weather:\(term)")
        }
        let activeEvents = inputs.calendarEvents.filter {
            $0.startsAt <= now && ($0.endsAt ?? $0.startsAt.addingTimeInterval(3600)) >= now
        }
        facets.insert("day-load:\(activeEvents.isEmpty ? "open" : (activeEvents.count >= 3 ? "crowded" : "held"))")
        let readerState = inputs.readerStatePulses.currentState(now: now)
        if let value = readerState.aliveness {
            facets.insert("state:aliveness:\(stateBand(value))")
        }
        if let value = readerState.wonder {
            facets.insert("state:wonder:\(stateBand(value))")
        }
        if let value = readerState.hiddenMagic {
            facets.insert("state:hidden-magic:\(stateBand(value))")
        }
        if let value = readerState.capacity {
            facets.insert("state:capacity:\(capacityBand(value))")
        }
        return facets
    }

    private static func stateBand(_ score: Int) -> String {
        switch score {
        case ...3: return "closed"
        case 4...5: return "flicker"
        case 6...7: return "open"
        default: return "vivid"
        }
    }

    private static func capacityBand(_ score: Int) -> String {
        switch score {
        case ...3: return "little"
        case 4...7: return "some"
        default: return "wide"
        }
    }

    static func addingSurfaceFacets(_ base: Set<String>, page: SurfacePage) -> Set<String> {
        var facets = base
        for tag in page.readerLearningTags where
            tag.hasPrefix("person:") || tag.hasPrefix("entity:") || tag.hasPrefix("sender:") {
            facets.insert(tag)
        }
        return facets
    }

    /// A non-reversible bucket for causal comparison. The raw place, weather,
    /// and company facets stay in the local aliveness portrait; opportunity
    /// receipts need only know that two selection moments were comparable.
    static func contextKey(_ facets: Set<String>) -> String {
        let seed = facets.sorted().joined(separator: "|")
        return "ctx-\(abs(seed.stableHash))"
    }
}

// MARK: - Live opportunity interrupts

/// A material change in the reader's present context that can make one exact
/// Page unusually timely. These are private policy terms, never reader labels.
enum BookLiveOpportunityKind: String, Codable, Equatable, CaseIterable {
    case shelterNeeded
    case nearbyAnchorArrived
    case weatherTurned
    case placeOpened
    case calendarWindowOpened
    case capacityOpened
}

enum BookLiveOpportunityCapacityBand: String, Codable, Equatable {
    case unknown
    case little
    case some
    case wide

    init(_ value: Int?) {
        guard let value else { self = .unknown; return }
        switch value {
        case ...3: self = .little
        case 4...7: self = .some
        default: self = .wide
        }
    }
}

/// A bounded, local snapshot of only the facts needed to tell whether an old
/// prepared score has missed a newly opened door. It contains no coordinates,
/// calendar titles, reader prose, or raw state-poll answers.
struct BookLiveOpportunityContext: Codable, Equatable {
    var contextKey: String
    var capturedAt: Date
    var nearbyAnchorID: String?
    var hasNearbyPlaces: Bool
    var placeContext: String?
    var salientWeatherTags: [String]
    var calendarIsOccupied: Bool
    var minutesToNextCalendarEvent: Int?
    var capacityBand: BookLiveOpportunityCapacityBand
    var distressActive: Bool

    static func capture(
        inputs: BookSourceInputs,
        distressActive: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> BookLiveOpportunityContext {
        let facets = ReaderAlivenessCurationContext.facets(
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        let weatherTerms: Set<String> = [
            "storm", "rain", "snow", "fog", "wind", "cloud", "bright",
            "hot", "cold"
        ]
        let weatherTags = Set(RadioPageContext.weatherTags(
            weather: inputs.weather,
            enchanted: inputs.enchantedWeather
        ).map(\.readerLearningNormalizedTag))
        let salient = weatherTerms.filter { term in
            weatherTags.contains(term) || weatherTags.contains("weather:\(term)")
        }.sorted()
        let activeEvents = inputs.calendarEvents.filter { event in
            let end = event.endsAt ?? event.startsAt.addingTimeInterval(3600)
            return !event.isAllDay && event.startsAt <= now && end >= now
        }
        let nextEventMinutes = inputs.calendarEvents
            .filter { !$0.isAllDay && $0.startsAt > now }
            .map { Int($0.startsAt.timeIntervalSince(now) / 60) }
            .min()
        return BookLiveOpportunityContext(
            contextKey: ReaderAlivenessCurationContext.contextKey(facets),
            capturedAt: now,
            nearbyAnchorID: inputs.nearbyAnchor?.anchor.id.nonEmpty,
            hasNearbyPlaces: !inputs.nearbyPlaces.isEmpty,
            placeContext: inputs.currentPlaceContext?.rawValue,
            salientWeatherTags: salient,
            calendarIsOccupied: !activeEvents.isEmpty,
            minutesToNextCalendarEvent: nextEventMinutes,
            capacityBand: BookLiveOpportunityCapacityBand(
                inputs.readerStatePulses.currentState(now: now).capacity
            ),
            distressActive: distressActive
        )
    }
}

/// The Director's short-lived nomination of one exact Page. Nomination is not
/// success, evidence, or a notification entitlement; it only says this Page is
/// the best honest use of a context hinge that may soon close.
struct BookLiveOpportunityDirective: Codable, Equatable {
    var kind: BookLiveOpportunityKind
    var signature: String
    var targetSurfaceID: String
    var targetSourceID: String
    var targetType: BookPageType
    var targetContentKey: String
    var movement: BookReenchantmentMovement
    var priority: Int
    var reason: String
    var createdAt: Date
    var expiresAt: Date

    func matches(_ page: SurfacePage) -> Bool {
        page.id == targetSurfaceID
            || (page.sourceID == targetSourceID
                && page.type == targetType
                && page.curatorContentNoveltyKey == targetContentKey)
    }
}

/// Pure, deterministic policy for the rare moment when the world should be
/// allowed to amend a still-active score. It requires an actual transition,
/// an eligible authored Page whose capabilities match that transition, and a
/// stronger hinge than any live opportunity already conducting the session.
enum BookLiveOpportunityPlanner {
    private struct Trigger {
        var kind: BookLiveOpportunityKind
        var priority: Int
        var lifetime: TimeInterval
    }

    static func directive(
        from origin: BookLiveOpportunityContext,
        to current: BookLiveOpportunityContext,
        activeIntention: BookSessionIntention,
        candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        readerAliveness: ReaderAlivenessModel,
        now: Date
    ) -> BookLiveOpportunityDirective? {
        guard activeIntention.ambition != .revelation,
              activeIntention.ambition != .intervention
                || activeIntention.liveOpportunity != nil else { return nil }

        let triggers = detectedTriggers(from: origin, to: current)
            .sorted { left, right in
                if left.priority != right.priority { return left.priority > right.priority }
                return left.kind.rawValue < right.kind.rawValue
            }
        guard !triggers.isEmpty else { return nil }

        let eligibleIDs = Set(BookCurator.candidateTrace(
            from: candidates,
            preferences: preferences,
            mood: mood,
            now: now
        ).filter { $0.rejection == nil }.map(\.surfaceID))

        for trigger in triggers {
            if let existing = activeIntention.liveOpportunity,
               now < existing.expiresAt,
               existing.priority >= trigger.priority {
                continue
            }
            let fitting = candidates.filter { page in
                eligibleIDs.contains(page.id)
                    && !page.isDeskMilestone
                    && page.payload.metadata["firstRunStep"] == nil
                    && matches(trigger.kind, page: page, current: current)
                    && (!page.spendsHighPressureCausalBudget
                        || readerAliveness.allowsHighPressureCausalAttempt(now: now))
            }
            guard let page = fitting.max(by: { left, right in
                let leftScore = score(left, for: trigger, preferences: preferences)
                let rightScore = score(right, for: trigger, preferences: preferences)
                if leftScore != rightScore { return leftScore < rightScore }
                return left.id > right.id
            }) else { continue }

            let movement = preferredMovement(for: trigger.kind, page: page)
            let signatureSeed = [
                current.contextKey,
                trigger.kind.rawValue,
                page.sourceID,
                page.curatorContentNoveltyKey
            ].joined(separator: "|")
            return BookLiveOpportunityDirective(
                kind: trigger.kind,
                signature: "live-opportunity-\(abs(signatureSeed.stableHash))",
                targetSurfaceID: page.id,
                targetSourceID: page.sourceID,
                targetType: page.type,
                targetContentKey: page.curatorContentNoveltyKey,
                movement: movement,
                priority: trigger.priority,
                reason: reason(for: trigger.kind),
                createdAt: now,
                expiresAt: now.addingTimeInterval(trigger.lifetime)
            )
        }
        return nil
    }

    private static func detectedTriggers(
        from origin: BookLiveOpportunityContext,
        to current: BookLiveOpportunityContext
    ) -> [Trigger] {
        var triggers: [Trigger] = []
        let capacityFellLow = origin.capacityBand != .little && current.capacityBand == .little
        if (!origin.distressActive && current.distressActive) || capacityFellLow {
            triggers.append(Trigger(kind: .shelterNeeded, priority: 130, lifetime: 30 * 60))
        }
        if let anchorID = current.nearbyAnchorID,
           anchorID != origin.nearbyAnchorID {
            triggers.append(Trigger(kind: .nearbyAnchorArrived, priority: 120, lifetime: 45 * 60))
        }
        let oldWeather = Set(origin.salientWeatherTags)
        let newWeather = Set(current.salientWeatherTags)
        if !newWeather.subtracting(oldWeather).isEmpty {
            triggers.append(Trigger(kind: .weatherTurned, priority: 95, lifetime: 75 * 60))
        }
        if (!origin.hasNearbyPlaces && current.hasNearbyPlaces)
            || (current.placeContext != nil && current.placeContext != origin.placeContext) {
            triggers.append(Trigger(kind: .placeOpened, priority: 90, lifetime: 90 * 60))
        }
        let originWasClosed = origin.calendarIsOccupied
            || (origin.minutesToNextCalendarEvent.map { $0 <= 20 } ?? false)
        let currentIsOpen = !current.calendarIsOccupied
            && (current.minutesToNextCalendarEvent.map { $0 >= 35 } ?? true)
        if originWasClosed && currentIsOpen {
            triggers.append(Trigger(kind: .calendarWindowOpened, priority: 88, lifetime: 90 * 60))
        }
        if origin.capacityBand == .little && current.capacityBand == .wide {
            triggers.append(Trigger(kind: .capacityOpened, priority: 82, lifetime: 2 * 3600))
        }
        return triggers
    }

    private static func matches(
        _ kind: BookLiveOpportunityKind,
        page: SurfacePage,
        current: BookLiveOpportunityContext
    ) -> Bool {
        let capability = page.pageCapabilities
        switch kind {
        case .shelterNeeded:
            return capability.emotionalFunctions.contains(.soothe)
                && capability.effort != .involved
                && capability.pressureCost <= 0.24
        case .nearbyAnchorArrived:
            return page.type == .anchor || capability.requirements.contains(.nearbyAnchor)
        case .weatherTurned:
            let pageTags = Set(page.readerLearningTags)
            let weatherMatches = current.salientWeatherTags.contains { term in
                pageTags.contains(term) || pageTags.contains("weather:\(term)")
            }
            return page.type == .weather
                || page.type == .todaysSky
                || capability.requirements.contains(.weatherContext)
                || weatherMatches
        case .placeOpened:
            return capability.requirements.contains(.nearbyPlace)
                || capability.requirements.contains(.nearbyAnchor)
                || capability.reach == .nearbyWorld
        case .calendarWindowOpened:
            let available = current.minutesToNextCalendarEvent ?? 120
            return (capability.reach == .plannedWorld || capability.effort == .involved)
                && capability.estimatedMinutes + 10 < available
        case .capacityOpened:
            return capability.effort == .involved || capability.reach == .plannedWorld
        }
    }

    private static func score(
        _ page: SurfacePage,
        for trigger: Trigger,
        preferences: CuratorSurfacePreferences
    ) -> Double {
        let capability = page.pageCapabilities
        var value = Double(trigger.priority * 10 + page.score)
        if capability.authorship == .authored { value += 35 }
        if capability.proofModes.isEmpty == false { value += 12 }
        value += preferences.beliefSelectionMultiplier(for: page) * 20
        value -= capability.pressureCost * 24
        value -= Double(max(0, capability.estimatedMinutes - 10)) * 0.35
        return value
    }

    private static func preferredMovement(
        for kind: BookLiveOpportunityKind,
        page: SurfacePage
    ) -> BookReenchantmentMovement {
        let preferred: [BookReenchantmentMovement]
        switch kind {
        case .shelterNeeded: preferred = [.shelter, .freshSight]
        case .nearbyAnchorArrived, .weatherTurned, .placeOpened:
            preferred = [.livingWorld, .freshSight, .chosenDetour]
        case .calendarWindowOpened, .capacityOpened:
            preferred = [.chosenDetour, .scriptFreedom, .livingWorld]
        }
        return preferred.first(where: { page.pageCapabilities.supportedMovements.contains($0) })
            ?? page.pageCapabilities.supportedMovements.first
            ?? preferred[0]
    }

    private static func reason(for kind: BookLiveOpportunityKind) -> String {
        switch kind {
        case .shelterNeeded:
            return "The reader's available capacity changed enough that the old score should yield to one gentler Page."
        case .nearbyAnchorArrived:
            return "A live Outer Stacks Anchor entered reach while the earlier score was still conducting."
        case .weatherTurned:
            return "The weather acquired a timely, perceivable feature the earlier score could not have used."
        case .placeOpened:
            return "The reader arrived in a place with a newly usable nearby-world possibility."
        case .calendarWindowOpened:
            return "A real opening appeared in the day and can hold one finite undertaking."
        case .capacityOpened:
            return "The reader now has enough stated capacity for a larger possibility that was previously ill-timed."
        }
    }
}

enum BookSessionDirector {
    private struct MovementCandidate {
        var movement: BookReenchantmentMovement
        var support: Int
        var evidencePageIDs: [String]
        var reason: String
    }

    static func intention(
        for day: BookDay,
        inputs: BookSourceInputs,
        candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        distressActive: Bool,
        now: Date
    ) -> BookSessionIntention {
        let sessionSeed = "\(day.id)|\(Int(now.timeIntervalSince1970 / (4 * 3600)))"
        let liveContext = BookLiveOpportunityContext.capture(
            inputs: inputs,
            distressActive: distressActive,
            now: now
        )
        let liveMood = CuratorMood.make(
            inputs: inputs,
            distressActive: distressActive,
            now: now
        )
        func isSleeping(_ intention: BookSessionIntention) -> Bool {
            preferences.dismissedSurfaceIDs.contains(intention.restKey)
        }
        if let active = inputs.activeBookSessionIntention,
           active.isActive(on: day.id, now: now),
           !isSleeping(active) {
            if let origin = active.originContext,
               let directive = BookLiveOpportunityPlanner.directive(
                   from: origin,
                   to: liveContext,
                   activeIntention: active,
                   candidates: candidates,
                   preferences: preferences,
                   mood: liveMood,
                   readerAliveness: inputs.readerAliveness,
                   now: now
               ) {
                return make(
                    movement: directive.movement,
                    ambition: directive.kind == .shelterNeeded ? .glint : .intervention,
                    evidencePageIDs: [],
                    reason: directive.reason,
                    dayID: day.id,
                    seed: sessionSeed + "|" + directive.signature,
                    now: now,
                    originContext: liveContext,
                    liveOpportunity: directive,
                    expiresAtOverride: directive.expiresAt
                )
            }
            return active
        }

        if distressActive {
            return make(
                movement: .shelter,
                ambition: .glint,
                evidencePageIDs: day.pages.suffix(2).map(\.id),
                reason: "The current day asked me to lower effort and offer shelter.",
                dayID: day.id,
                seed: sessionSeed,
                now: now,
                originContext: liveContext
            )
        }

        if let campaign = inputs.bookInterior.longGame?.currentCampaign,
           campaign.mayClaimDeskSlot {
            let campaignIntention = make(
                movement: BookReenchantmentMovement(capacity: campaign.capacity),
                ambition: campaign.beat == .return ? .return : .intervention,
                evidencePageIDs: Array(Set(campaign.edgeEvidencePageIDs + campaign.outcomeEvidencePageIDs)).sorted(),
                reason: "A finite Long Game campaign has one evidence-backed real-world effect in progress.",
                dayID: day.id,
                seed: sessionSeed + "|" + campaign.id,
                now: now,
                originContext: liveContext
            )
            if !isSleeping(campaignIntention) { return campaignIntention }
        }

        if candidates.contains(where: { $0.payload.metadata["magicMoment"] == "true" }) {
            let evidenceIDs = candidates
                .filter { $0.payload.metadata["magicMoment"] == "true" }
                .flatMap { ($0.payload.metadata["bookActEvidencePageIDs"] ?? "").split(separator: ",").map(String.init) }
            let revealIntention = make(
                movement: .livingContinuity,
                ambition: .revelation,
                evidencePageIDs: Array(Set(evidenceIDs)).sorted(),
                reason: "Meaningful attention earned an evidence-backed reveal.",
                dayID: day.id,
                seed: sessionSeed + "|earned-reveal",
                now: now,
                originContext: liveContext
            )
            if !isSleeping(revealIntention) { return revealIntention }
        }

        let recentPages = (inputs.days + [day])
            .flatMap(\.pages)
            .sorted { $0.createdAt > $1.createdAt }
        let recentAuthored = recentPages.filter(\.hasReaderContribution)
        var movements: [MovementCandidate] = [
            MovementCandidate(
                movement: .freshSight,
                support: 16 + (inputs.weather == nil ? 0 : 5) + (inputs.nearbyAnchor == nil ? 0 : 4),
                evidencePageIDs: recentAuthored.prefix(1).map(\.id),
                reason: "The present day contains something concrete the reader can meet with fresh attention."
            ),
            MovementCandidate(
                movement: .livingWorld,
                support: 8 + (inputs.weather == nil ? 0 : 8) + (inputs.currentLocationLabel == nil ? 0 : 7)
                    + (inputs.nearbyPlaces.isEmpty ? 0 : 5),
                evidencePageIDs: recentPages.filter { [.weather, .location, .todaysSky, .anchor].contains($0.type) }.prefix(3).map(\.id),
                reason: "Place, weather, or nearby nonhuman business can become more than backdrop."
            ),
            MovementCandidate(
                movement: .scriptFreedom,
                support: 8 + min(8, inputs.selfFacts.count),
                evidencePageIDs: recentAuthored.prefix(2).map(\.id),
                reason: "The reader has supplied enough authorship for one ordinary rule to become less inevitable."
            ),
            MovementCandidate(
                movement: .chosenDetour,
                support: 9 + (livingEdgeCount(in: recentAuthored) * 5),
                evidencePageIDs: livingEdgeIDs(in: recentAuthored),
                reason: "A reader-authored desire or an open part of the day can support one chosen detour."
            ),
            MovementCandidate(
                movement: .exactLanguage,
                // Measured on the reader's own writing, not on `userInput`,
                // which on a prepared Page holds the Book's prose. A page kept
                // with only a photograph on it has a reader contribution and no
                // words, and was counting toward "the reader's own words".
                support: 7 + min(14, recentAuthored.filter { $0.readerAuthoredTextForAnalysis != nil }.count * 2),
                evidencePageIDs: recentAuthored.filter { $0.readerAuthoredTextForAnalysis != nil }.prefix(3).map(\.id),
                reason: "The reader's own words can make one blurred experience more exact."
            ),
            MovementCandidate(
                movement: .humanOtherness,
                support: 5 + min(15, inputs.people.threads.count * 4) + min(6, inputs.customCastMembers.count),
                evidencePageIDs: recentPages.filter { $0.tags.contains(where: { $0.hasPrefix("person:") || $0.hasPrefix("entity:") }) }.prefix(3).map(\.id),
                reason: "A person inside me can be met as another world rather than a familiar role."
            ),
            MovementCandidate(
                movement: .livingContinuity,
                support: 4 + min(18, inputs.resurfacingCandidates.count * 3) + min(8, inputs.continuity.signals.count),
                evidencePageIDs: Array(inputs.resurfacingCandidates.prefix(3).map(\.id)),
                reason: "Earlier life has enough surviving evidence to acquire a second life in the present."
            )
        ]

        // A pulse changes the remedy, never the eligibility of a movement.
        // Low capacity asks for shelter and small attention; a vivid day can
        // carry a larger detour. The learned outcome model still gets the
        // final weighted vote below.
        let readerState = inputs.readerStatePulses.currentState(now: now)
        func addSupport(_ amount: Int, to movement: BookReenchantmentMovement) {
            guard let index = movements.firstIndex(where: { $0.movement == movement }) else { return }
            movements[index].support += amount
        }
        if let capacity = readerState.capacity {
            if capacity <= 3 {
                addSupport(10, to: .freshSight)
                addSupport(-7, to: .chosenDetour)
                addSupport(-5, to: .humanOtherness)
            } else if capacity >= 8 {
                addSupport(7, to: .chosenDetour)
                addSupport(4, to: .humanOtherness)
            }
        }
        if let wonder = readerState.wonder, wonder <= 3 {
            addSupport(9, to: .freshSight)
            addSupport(7, to: .livingWorld)
        }
        if let aliveness = readerState.aliveness {
            if aliveness <= 3 {
                addSupport(6, to: .freshSight)
                addSupport(5, to: .livingWorld)
            } else if aliveness >= 8 {
                addSupport(5, to: .chosenDetour)
                addSupport(4, to: .humanOtherness)
            }
        }

        if let longGame = inputs.bookInterior.longGame,
           let hypothesis = longGame.hypotheses.first {
            let movement = BookReenchantmentMovement(capacity: hypothesis.capacity)
            if let index = movements.firstIndex(where: { $0.movement == movement }) {
                let hypothesisPageIDs = longGame.evidence
                    .filter { hypothesis.evidenceIDs.contains($0.id) }
                    .flatMap(\.evidencePageIDs)
                movements[index].support += 20
                movements[index].evidencePageIDs.append(contentsOf: hypothesisPageIDs)
                movements[index].reason = "My current cautious hypothesis and the present life point toward the same capacity."
            }
        }

        movements = movements.filter { movement in
            let seed = sessionSeed + "|" + movement.movement.rawValue
            let intentionID = BookSessionIntention.sessionID(
                dayID: day.id,
                movement: movement.movement,
                seed: seed
            )
            return !preferences.dismissedSurfaceIDs.contains(
                BookSessionIntention.restKey(for: intentionID)
            ) && candidates.contains {
                BookSessionComposer.intentionFit(for: $0, movement: movement.movement) > 0
            }
        }
        let movementContextKey = ReaderAlivenessCurationContext.contextKey(
            ReaderAlivenessCurationContext.facets(inputs: inputs, now: now)
        )
        let chosen = weightedMovement(
            movements,
            candidates: candidates,
            preferences: preferences,
            aliveness: inputs.readerAliveness,
            now: now,
            contextKey: movementContextKey,
            seed: sessionSeed
        ) ?? movements.first ?? MovementCandidate(
            movement: .shelter,
            support: 1,
            evidencePageIDs: [],
            reason: "Every active experiment is resting, so I offer undirected shelter instead."
        )
        let evidenceIDs = Array(Set(chosen.evidencePageIDs)).sorted()
        let ambition: BookSessionAmbition = chosen.movement == .livingContinuity && !evidenceIDs.isEmpty
            ? .return
            : (evidenceIDs.count >= 2 ? .connection : .glint)
        let causalMovementReceipt = causalMovementReceipt(
            chosen: chosen,
            among: movements,
            candidates: candidates,
            preferences: preferences,
            aliveness: inputs.readerAliveness,
            contextKey: movementContextKey,
            sessionID: BookSessionIntention.sessionID(
                dayID: day.id,
                movement: chosen.movement,
                seed: sessionSeed + "|" + chosen.movement.rawValue
            ),
            now: now
        )
        return make(
            movement: chosen.movement,
            ambition: ambition,
            evidencePageIDs: evidenceIDs,
            reason: chosen.reason,
            dayID: day.id,
            seed: sessionSeed + "|" + chosen.movement.rawValue,
            now: now,
            causalMovementReceipt: causalMovementReceipt,
            originContext: liveContext
        )
    }

    private static func make(
        movement: BookReenchantmentMovement,
        ambition: BookSessionAmbition,
        evidencePageIDs: [String],
        reason: String,
        dayID: String,
        seed: String,
        now: Date,
        causalMovementReceipt: CausalMovementReceipt? = nil,
        originContext: BookLiveOpportunityContext? = nil,
        liveOpportunity: BookLiveOpportunityDirective? = nil,
        expiresAtOverride: Date? = nil
    ) -> BookSessionIntention {
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(6 * 3600)
        let expiresAt = min(
            min(now.addingTimeInterval(6 * 3600), nextDay),
            expiresAtOverride ?? .distantFuture
        )
        return BookSessionIntention(
            id: BookSessionIntention.sessionID(dayID: dayID, movement: movement, seed: seed),
            dayID: dayID,
            movement: movement,
            ambition: ambition,
            evidencePageIDs: evidencePageIDs,
            evidenceReason: reason,
            createdAt: now,
            expiresAt: expiresAt,
            seed: seed,
            causalMovementReceipt: causalMovementReceipt,
            originContext: originContext,
            liveOpportunity: liveOpportunity
        )
    }

    private static func weightedMovement(
        _ movements: [MovementCandidate],
        candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        aliveness: ReaderAlivenessModel,
        now: Date,
        contextKey: String,
        seed: String
    ) -> MovementCandidate? {
        movements.min { left, right in
            movementRace(
                left,
                candidates: candidates,
                preferences: preferences,
                aliveness: aliveness,
                now: now,
                contextKey: contextKey,
                seed: seed
            ) < movementRace(
                right,
                candidates: candidates,
                preferences: preferences,
                aliveness: aliveness,
                now: now,
                contextKey: contextKey,
                seed: seed
            )
        }
    }

    private static func movementRace(
        _ candidate: MovementCandidate,
        candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        aliveness: ReaderAlivenessModel,
        now: Date,
        contextKey: String,
        seed: String
    ) -> Double {
        let weight = movementWeight(
            candidate,
            candidates: candidates,
            preferences: preferences,
            aliveness: aliveness,
            now: now,
            contextKey: contextKey
        )
        return weightedRace(seed: "\(seed)|movement|\(candidate.movement.rawValue)", weight: weight)
    }

    private static func movementWeight(
        _ candidate: MovementCandidate,
        candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        aliveness: ReaderAlivenessModel,
        now: Date,
        contextKey: String
    ) -> Double {
        let relevant = candidates.filter {
            BookSessionComposer.intentionFit(for: $0, movement: candidate.movement) > 0
        }
        let belief = relevant.map { preferences.beliefSelectionMultiplier(for: $0) }.max() ?? 0.35
        let exploration = aliveness.movementExplorationMultiplier(candidate.movement, now: now)
        let causal = aliveness.causalMovementUpliftMultiplier(
            movement: candidate.movement,
            contextKey: contextKey,
            now: now
        )
        return max(0.1, Double(max(1, candidate.support)) * belief * exploration * causal)
    }

    private static func causalMovementReceipt(
        chosen: MovementCandidate,
        among movements: [MovementCandidate],
        candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        aliveness: ReaderAlivenessModel,
        contextKey: String,
        sessionID: String,
        now: Date
    ) -> CausalMovementReceipt? {
        guard movements.count >= 2 else { return nil }
        let weighted = movements.map { movement in
            CausalMovementCandidate(
                movement: movement.movement,
                weight: movementWeight(
                    movement,
                    candidates: candidates,
                    preferences: preferences,
                    aliveness: aliveness,
                    now: now,
                    contextKey: contextKey
                )
            )
        }
        guard let selected = weighted.first(where: { $0.movement == chosen.movement }) else { return nil }
        let total = weighted.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        let idSeed = "\(sessionID)|movement|\(contextKey)"
        return CausalMovementReceipt(
            id: "causal-movement-\(abs(idSeed.stableHash))",
            policyVersion: CausalMovementReceipt.currentPolicyVersion,
            sessionID: sessionID,
            chosenMovement: chosen.movement,
            contextKey: contextKey,
            propensity: max(0.000_001, min(1, selected.weight / total)),
            candidates: weighted,
            selectedAt: now
        )
    }

    private static func livingEdgeCount(in pages: [BookPage]) -> Int {
        livingEdgeIDs(in: pages).count
    }

    private static func livingEdgeIDs(in pages: [BookPage]) -> [String] {
        let markers = ["i want", "i wish", "i keep meaning", "someday", "my dream", "i'd love", "i miss"]
        return pages.filter { page in
            let text = [page.userInput, page.playerReply].joined(separator: " ").lowercased()
            return markers.contains(where: text.contains)
        }.prefix(3).map(\.id)
    }

    fileprivate static func weightedRace(seed: String, weight: Double) -> Double {
        let scrambled = abs(seed.stableHash.stableScramble % 1_000_000)
        let unit = Double(scrambled + 1) / 1_000_001.0
        return -log(unit) / max(0.0001, weight)
    }
}

enum BookSessionComposer {
    static func intentionFit(for page: SurfacePage, movement: BookReenchantmentMovement) -> Int {
        let preferred: Set<BookPageType>
        switch movement {
        case .freshSight:
            preferred = [.plainPage, .souvenir, .wonderCompass, .weather, .body, .mood, .enchantment, .quip, .quotes]
        case .livingWorld:
            preferred = [.wonderCompass, .location, .todaysSky, .weather, .anchor, .bookNotices, .enchantment, .lore]
        case .scriptFreedom:
            preferred = [.wordNegotiation, .affirmations, .faeBargain, .bookNotices, .wonderCompass, .narrativeOS]
        case .chosenDetour:
            preferred = [.wonderCompass, .elective, .narrativeOS, .enchantment, .plainPage, .bookJump]
        case .exactLanguage:
            preferred = [.wordNegotiation, .diary, .souvenir, .quotes, .bookNotices, .plainPage]
        case .humanOtherness:
            preferred = [.letter, .note, .elective, .bookConnections, .gossip, .castBond, .bookFae]
        case .livingContinuity:
            preferred = [.bookRemembered, .bookConnections, .bookOfYou, .bookPocket, .bindery, .bookNotices]
        case .shelter:
            preferred = [.rest, .body, .weather, .plainPage, .mood, .quotes, .radio]
        }
        var value = preferred.contains(page.type) ? 18 : 0
        if movement == .livingContinuity, [.resurface, .braid, .reflect].contains(page.intent) { value += 8 }
        if movement == .shelter, page.intent == .rest { value += 12 }
        if [.freshSight, .livingWorld, .chosenDetour].contains(movement), page.type.deskLane == .outward { value += 5 }
        if movement == .humanOtherness,
           page.readerLearningTags.contains(where: { $0.hasPrefix("person:") || $0.hasPrefix("entity:") || $0.hasPrefix("sender:") }) {
            value += 8
        }
        return value
    }

    static func roleFit(for page: SurfacePage, role: BookSessionRole, movement: BookReenchantmentMovement) -> Int {
        switch role {
        case .door:
            var value = intentionFit(for: page, movement: movement)
            if page.type.deskLane == .outward || page.isReaderActionCommission { value += 12 }
            if [.capture, .rest, .resurface].contains(page.intent) { value += 6 }
            if movement == .livingContinuity, [.bookRemembered, .bookConnections, .bookOfYou].contains(page.type) { value += 14 }
            return value
        case .echo:
            var value = intentionFit(for: page, movement: movement) / 2
            if [.reflect, .resurface, .braid].contains(page.intent) { value += 14 }
            if [.bookNotices, .bookRemembered, .bookConnections, .bookPocket, .bookOfYou].contains(page.type) { value += 12 }
            if page.isReaderActionCommission { value -= 20 }
            return value
        case .horizon:
            var value = intentionFit(for: page, movement: movement) / 3
            if page.type.deskLane == .fiction || page.intent == .importReference || page.intent == .simulate { value += 14 }
            if [.lore, .quotes, .quip, .radio, .narrativeOS, .letter, .gossip, .facultyResearch].contains(page.type) { value += 7 }
            if page.isReaderActionCommission { value -= 24 }
            return value
        }
    }

    static func preferredRole(for page: SurfacePage, movement: BookReenchantmentMovement) -> BookSessionRole {
        BookSessionRole.allCases.max {
            roleFit(for: page, role: $0, movement: movement)
                < roleFit(for: page, role: $1, movement: movement)
        } ?? .horizon
    }
}

/// Private notation for the Curator's background-prepared score. The first act
/// is visible; the next two acts are conditional responses to Keep and clean
/// refusal; later acts are adaptive reserve. A prepared causal receipt remains
/// dormant until `recordServedSurfaces` records that the Page actually rose.
enum BookPreparedExperimentScore {
    static let metadataBatchID = "bookPreparedExperimentBatchID"
    static let metadataActIndex = "bookPreparedExperimentActIndex"
    static let metadataBranch = "bookPreparedExperimentBranch"
    static let metadataContextKey = "bookPreparedExperimentContextKey"
    static let metadataPreparedAt = "bookPreparedExperimentPreparedAt"

    static func branch(forActIndex index: Int) -> BookPreparedExperimentBranch {
        switch index {
        case 0: return .current
        case 1: return .afterKeep
        case 2: return .afterDismissal
        default: return .adaptive
        }
    }

    static func preparing(
        _ surface: SurfacePage,
        intention: BookSessionIntention,
        role: BookSessionRole,
        actIndex: Int,
        contextKey: String,
        now: Date
    ) -> SurfacePage {
        var payload = surface.payload
        payload.metadata[metadataBatchID] = "prepared-\(intention.id)"
        payload.metadata[metadataActIndex] = String(max(0, actIndex))
        payload.metadata[metadataBranch] = branch(forActIndex: actIndex).rawValue
        payload.metadata[metadataContextKey] = contextKey
        payload.metadata[metadataPreparedAt] = String(now.timeIntervalSince1970)
        payload.metadata[BookSessionIntention.metadataRole] = role.rawValue
        return SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: payload
        )
    }
}

/// A swipe is navigation before it is judgment. The first distinct Door
/// refusal keeps the score alive and selects its prepared gentler branch. A
/// second distinct Door refusal sleeps this score for the ordinary dismissal
/// window. Neither event, by itself, is durable evidence against the Page
/// family, movement, or reader.
enum BookPreparedExperimentDismissalPolicy {
    static func sleepsExperiment(
        afterDismissing surface: SurfacePage,
        learning: ReaderLearningModel
    ) -> Bool {
        guard surface.preparedExperimentRole == .door,
              let intention = BookSessionIntention.read(from: surface),
              intention.movement != .shelter else {
            return false
        }
        let intentionID = intention.id
        let sessionTag = "book-session-id:\(intentionID)".readerLearningNormalizedTag
        let doorTag = "book-session-role:\(BookSessionRole.door.rawValue)".readerLearningNormalizedTag
        let priorDistinctDoors = Set(learning.events.compactMap { event -> String? in
            guard event.action == .dismissed,
                  event.surfaceID != surface.id,
                  event.tags.contains(sessionTag),
                  event.tags.contains(doorTag) else { return nil }
            return event.surfaceID
        })
        return !priorDistinctDoors.isEmpty
    }
}

extension SurfacePage {
    var isLiveOpportunityInterruptTarget: Bool {
        payload.metadata[BookSessionIntention.metadataLiveOpportunityTarget] == "true"
    }

    var preparedExperimentActIndex: Int? {
        payload.metadata[BookPreparedExperimentScore.metadataActIndex].flatMap(Int.init)
    }

    var preparedExperimentBranch: BookPreparedExperimentBranch? {
        payload.metadata[BookPreparedExperimentScore.metadataBranch]
            .flatMap(BookPreparedExperimentBranch.init(rawValue:))
    }

    var preparedExperimentContextKey: String? {
        payload.metadata[BookPreparedExperimentScore.metadataContextKey]
    }

    var preparedExperimentIntentionID: String? {
        payload.metadata[BookSessionIntention.metadataID]
    }

    var preparedExperimentRole: BookSessionRole? {
        payload.metadata[BookSessionIntention.metadataRole]
            .flatMap(BookSessionRole.init(rawValue:))
    }

    var preparedExperimentRestKey: String? {
        preparedExperimentIntentionID.map(BookSessionIntention.restKey(for:))
    }

    func preparedExperimentIsFresh(contextKey: String, now: Date) -> Bool {
        guard let preparedContext = preparedExperimentContextKey else { return true }
        guard preparedContext == contextKey else { return false }
        guard let intention = BookSessionIntention.read(from: self) else { return false }
        return intention.isActive(on: intention.dayID, now: now)
    }
}

/// Decides when concrete reader-authored evidence is owed one visible return.
/// It stores no prose and creates no engagement cadence: a debt exists only
/// when new evidence arrived after the last earned trace, and it rests for
/// three days between appearances.
enum EarnedReaderTracePolicy {
    static let minimumRestSeconds: TimeInterval = 3 * 86_400

    static func owedEvidencePage(
        day: BookDay,
        inputs: BookSourceInputs,
        distressActive: Bool,
        now: Date
    ) -> BookPage? {
        guard !distressActive,
              inputs.libraryReadyForReflectivePages(includingToday: day, now: now)
        else {
            return nil
        }
        let evidence = (inputs.days + [day])
            .flatMap(\.capturedPages)
            .filter { page in
                page.createdAt < now && page.hasReaderContribution
            }
            .sorted { left, right in
                if left.createdAt == right.createdAt { return left.id > right.id }
                return left.createdAt > right.createdAt
            }
        guard let newest = evidence.first else { return nil }
        guard let lastTraceAt = inputs.surfaceHistory[SurfacePage.earnedReaderTraceHistoryKey]?.lastShownAt else {
            return newest
        }
        guard newest.createdAt > lastTraceAt,
              now.timeIntervalSince(lastTraceAt) >= minimumRestSeconds else {
            return nil
        }
        return newest
    }
}

enum BookCurator {
    static func surfacedPages(for day: BookDay, now: Date = Date(), limit: Int = 3) -> [SurfacePage] {
        surfacedPages(for: day, context: .make(for: day), inputs: .empty, now: now, limit: limit)
    }

    /// The exact privacy-filtered opportunity set the Curator may rank.
    ///
    /// This is exposed internally for the Curator Observatory so diagnostics
    /// inspect the same candidates as production curation rather than
    /// reconstructing a parallel approximation.
    static func candidatePool(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs = .empty,
        now: Date = Date()
    ) -> [SurfacePage] {
        candidatePool(
            for: day,
            context: context,
            resolvedInputs: inputs.resolvingWorldEvents(for: day, now: now),
            now: now
        )
    }

    private static func candidatePool(
        for day: BookDay,
        context: CuratorContext,
        resolvedInputs inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        let preparedSurfaceIDs = Set([
            inputs.preparedAnchorSurface?.id,
            inputs.preparedIlluminatedPhotoSurface?.id,
            inputs.preparedStoryPageSurface?.id,
            inputs.preparedGossipPageSurface?.id,
            inputs.preparedFacultyResearchSurface?.id,
            inputs.preparedLetterSurface?.id,
            inputs.preparedBleedEditionSurface?.id
        ].compactMap { $0 })
        let rawCandidates = (
            BookPageSourceAdapters.active.flatMap { adapter in
                adapter.candidates(for: day, context: context, inputs: inputs, now: now)
            }
            + BookInteriorSurfaces.candidates(for: day, inputs: inputs, now: now)
        )
        .map { WorldEventEffects.framed($0, events: inputs.activeWorldEvents) }
        // An experiment the twin is running today lifts the kind of page its
        // belief is betting on. It adds nothing to the desk and outranks
        // nothing outright: it tilts what was already on offer, so the reader
        // is still choosing from their own day. Nil unless the reader has
        // opened the workings door; see `TwinExperimenter.arrangeable`.
        .map { page -> SurfacePage in
            guard let experiment = inputs.arrangedExperiment,
                  TwinExperimenter.isArrangeableSurface(page) else { return page }
            var payload = page.payload
            let tag = TwinExperimenter.arrangementTagPrefix + experiment.id
            payload.metadata["tags"] = [payload.metadata["tags"], tag]
                .compactMap { $0?.nonEmpty }
                .joined(separator: ",")
            payload.metadata["twinArrangementID"] = experiment.id
            return SurfacePage(
                id: page.id,
                type: page.type,
                sourceID: page.sourceID,
                intent: page.intent,
                renderStyle: page.renderStyle,
                score: page.score + TwinExperimenter.arrangementBoost,
                reason: page.reason,
                prompt: page.prompt,
                detail: page.detail,
                payload: payload
            )
        }
        .map { page in
            guard preparedSurfaceIDs.contains(page.id) else { return page }
            var payload = page.payload
            payload.metadata["curatorPreparedArtifact"] = "true"
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
        .map {
            BookInteriorVoice.influencing(
                $0,
                interior: inputs.bookInterior,
                allowCampaign: !context.distress.isActive
            )
        }
        let readableCandidates = rawCandidates.filter {
            BookObservationLedger.allows(
                $0,
                observations: inputs.bookObservations,
                boundaries: inputs.bookReadingBoundaries
            )
        }
        return MagicMomentGovernor.promotingEarnedReveal(
            in: readableCandidates,
            state: inputs.magicMoment
        )
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
        let bookRelationship = BookRelationshipLedger.snapshot(inputs: inputs, now: now)
        let candidates = candidatePool(
            for: day,
            context: context,
            resolvedInputs: inputs,
            now: now
        )
        let mood = CuratorMood.make(inputs: inputs, distressActive: context.distress.isActive, now: now)
        let alivenessFacets = ReaderAlivenessCurationContext.facets(inputs: inputs, now: now)
        let sessionIntention = BookSessionDirector.intention(
            for: day,
            inputs: inputs,
            candidates: candidates,
            preferences: preferences,
            distressActive: context.distress.isActive,
            now: now
        )
        var picked = rankedPages(
            from: candidates,
            limit: limit,
            preferences: preferences,
            mood: mood,
            now: now,
            intention: sessionIntention,
            selectionSeed: sessionIntention.seed,
            readerAliveness: inputs.readerAliveness,
            alivenessFacets: alivenessFacets
        ).map(\.page)

        // A live opportunity directive has already passed the Director's
        // transition, eligibility, pressure, and exact-Page tests. Reserve its
        // nominated Page inside the prepared score if the ordinary weighted
        // race did not seat it. This is not an extra commission: when needed it
        // replaces the score's existing ask/action or a conflicting family.
        if let directive = sessionIntention.liveOpportunity,
           now < directive.expiresAt,
           !picked.contains(where: directive.matches),
           let exactOpportunity = candidates.first(where: { candidate in
               directive.matches(candidate)
                   && preferences.allows(candidate)
                   && mood.allows(candidate)
                   && candidate.pageCapabilities.isEligible(in: mood)
           }) {
            if picked.count < limit {
                picked.append(exactOpportunity)
            } else {
                let protected: (SurfacePage) -> Bool = {
                    $0.isDeskMilestone || $0.type == .bookOfYou
                }
                let conflictingIndex = picked.lastIndex(where: {
                    !protected($0)
                        && ($0.type == exactOpportunity.type
                            || $0.sourceID == exactOpportunity.sourceID
                            || !$0.curatorDeskExclusionKeys.isDisjoint(
                                with: exactOpportunity.curatorDeskExclusionKeys
                            ))
                })
                let pressureIndex = exactOpportunity.spendsCuratorActionBudget
                    ? picked.lastIndex(where: { !protected($0) && $0.spendsCuratorActionBudget })
                    : (exactOpportunity.spendsCuratorAskBudget
                        ? picked.lastIndex(where: { !protected($0) && $0.spendsCuratorAskBudget })
                        : nil)
                let victim = conflictingIndex
                    ?? pressureIndex
                    ?? injectionVictimIndex(
                        in: picked,
                        preferringLane: exactOpportunity.type.deskLane
                    )
                if let victim, !protected(picked[victim]) {
                    picked[victim] = exactOpportunity
                }
            }
        }

        // The Long Game is strategy, not flavor text. When its current
        // hypothesis has a genuinely eligible Page available, reserve one
        // ordinary slot for that kind of interruption. The Page itself stays
        // casual; the directive receipt remains in metadata. A recent clean
        // rejection cools this tactic so intention never becomes pestering.
        if !context.distress.isActive,
           let hypothesis = inputs.bookInterior.longGame?.hypotheses.first,
           inputs.bookInterior.longGame?.currentCampaign?.mayClaimDeskSlot != false,
           longGameDirectiveMayPress(
                hypothesis,
                learning: inputs.readerLearning,
                now: now
           ),
           !picked.contains(where: {
               $0.payload.metadata["bookCurationDirectiveID"] != nil
                   || $0.payload.metadata["bookCampaignID"] != nil
           }) {
            let campaignID = inputs.bookInterior.longGame?.currentCampaign?.id
            let strategic = rankedPages(
                from: candidates.filter {
                    if let campaignID {
                        return $0.payload.metadata["bookCampaignID"] == campaignID
                    }
                    return $0.payload.metadata["bookCurationDirectiveID"]
                        == BookCurationDirective.make(from: hypothesis).id
                },
                limit: 1,
                preferences: preferences,
                mood: mood,
                now: now,
                intention: sessionIntention,
                selectionSeed: sessionIntention.seed + "|strategic",
                readerAliveness: inputs.readerAliveness,
                alivenessFacets: alivenessFacets
            ).first?.page
            if let strategic,
               !picked.contains(where: { $0.id == strategic.id }) {
                if picked.count < limit {
                    picked.append(strategic)
                } else if let victim = injectionVictimIndex(
                    in: picked,
                    preferringLane: strategic.type.deskLane
                ) {
                    picked[victim] = strategic
                }
            }
        }

        // One Book, one will. When the Long Game has deliberately claimed a
        // desk slot, lower-level rituals may still arrive through ordinary
        // ranking, but they do not also force themselves onto the desk. This
        // keeps the Director's finite intervention from becoming a chorus of
        // simultaneous asks. The nightly braid is exempt below: it returns
        // memory rather than commissioning another real-world action.
        let longGameOwnsInterventionSlot = picked.contains {
            $0.payload.metadata["bookCurationDirectiveID"] != nil
                || $0.payload.metadata["bookCampaignID"] != nil
        }

        // Sovereign automation: a Talisman that reigns over a shelf acts unasked
        //: guarantee one of its pages a slot if the feed didn't already pick one
        // and the day isn't hard. Pure surfacing; no model call.
        let sovereignTypes = PactWarEffects.sovereignShelfPageTypes(state: inputs.pactWar)
        if !longGameOwnsInterventionSlot,
           !sovereignTypes.isEmpty,
           !context.distress.isActive,
           !picked.contains(where: { sovereignTypes.contains($0.type) }),
           let inject = candidates.first(where: { candidate in
               sovereignTypes.contains(candidate.type)
                   && candidate.pageCapabilities.isEligible(in: mood)
                   && !picked.contains(where: { $0.id == candidate.id })
           }) {
            if picked.isEmpty {
                picked = [inject]
            } else if let victim = injectionVictimIndex(in: picked, preferringLane: inject.type.deskLane) {
                picked[victim] = inject
            }
        }

        if BookOfYouPageSourceAdapter.mayShowBraid(for: day, previousDays: inputs.days, now: now),
           !picked.contains(where: { $0.type == .bookOfYou }),
           let braid = candidates.first(where: { candidate in
               candidate.type == .bookOfYou
                   && preferences.allows(candidate)
                   && mood.allows(candidate)
                   && candidate.pageCapabilities.isEligible(in: mood)
                   && !BookMemoryGate.locks(candidate.type, keptPageCount: inputs.keptPageCount)
           }) {
            if picked.isEmpty {
                picked = [braid]
            } else if let victim = injectionVictimIndex(in: picked, preferringLane: .fiction) {
                // The braid is the fiction slot; it may replace an existing
                // non-braid fiction page so the desk stays balanced.
                picked[victim] = braid
            }
        }

        // Tarot is a daily ritual once the reader's archive is mature enough.
        // Give today's invitation an ordinary desk slot if ranking did not
        // already choose it. It never evicts a milestone or the evening braid,
        // and the candidate itself has already yielded to distress and a
        // reading kept earlier on the same calendar day.
        if !longGameOwnsInterventionSlot,
           !picked.contains(where: { $0.type == .tarot }),
           let tarot = candidates.first(where: { candidate in
               candidate.type == .tarot
                   && preferences.allows(candidate)
                   && mood.allows(candidate)
                   && candidate.pageCapabilities.isEligible(in: mood)
                   && !BookMemoryGate.locks(candidate.type, keptPageCount: inputs.keptPageCount)
           }) {
            let visibleLimit = min(3, max(0, limit))
            let existingVisibleAsk = picked.indices.prefix(visibleLimit).last(where: {
                picked[$0].spendsCuratorAskBudget
            })
            if tarot.spendsCuratorAskBudget,
               let existingVisibleAsk,
               !picked[existingVisibleAsk].isDeskMilestone,
               picked[existingVisibleAsk].type != .bookOfYou {
                // Tarot is an ordinary invitation, not permission to put a
                // second question on the desk. If it enters, it takes the
                // existing ask's chair.
                picked[existingVisibleAsk] = tarot
            } else if tarot.spendsCuratorAskBudget, existingVisibleAsk != nil {
                // A protected question already owns the reader's attention.
            } else if picked.count < limit {
                picked.append(tarot)
            } else if let victim = injectionVictimIndex(in: picked, preferringLane: tarot.type.deskLane) {
                picked[victim] = tarot
            }
        }

        picked = reservingEarnedReaderTraceIfOwed(
            in: picked,
            candidates: candidates,
            day: day,
            inputs: inputs,
            context: context,
            preferences: preferences,
            mood: mood,
            now: now,
            limit: limit,
            intention: sessionIntention,
            readerAliveness: inputs.readerAliveness,
            alivenessFacets: alivenessFacets
        )

        let experimentContextKey = ReaderAlivenessCurationContext.contextKey(alivenessFacets)
        picked = picked.enumerated().map { offset, page in
            let resolvedPage = page.withResolvedPageCapabilities()
            let capablePage = sessionIntention.liveOpportunity?.matches(resolvedPage) == true
                ? CausalCurationReceipt.removing(from: resolvedPage)
                : resolvedPage
            let role = capablePage.preparedExperimentRole
                ?? BookSessionComposer.preferredRole(for: capablePage, movement: sessionIntention.movement)
            let intended = capablePage.payload.metadata[BookSessionIntention.metadataID] == nil
                ? sessionIntention.applying(to: capablePage, role: role)
                : capablePage
            // Injections and editorial debts may have replaced an already
            // composed slot. Re-key every final Page by its actual act position
            // so the committed reserve remains one coherent prepared score.
            return BookPreparedExperimentScore.preparing(
                intended,
                intention: sessionIntention,
                role: role,
                actIndex: offset / BookDeskRound.openingCapacity,
                contextKey: experimentContextKey,
                now: now
            )
        }
        let framed = picked
            .map { PactWarEffects.framed($0, state: inputs.pactWar) }
            .map { $0.withReaderLexiconLanguageLaw(inputs.readerLexicon) }
        let telling = bookRelationship.telling(at: now)
        let voiced = framed.map {
            BookCharacterStanceEditor.voicing($0, telling: telling)
        }
        return BookInterjectionEditor.decoratingDesk(
            voiced,
            interior: inputs.bookInterior,
            days: inputs.days,
            selfFacts: inputs.selfFacts,
            relationship: bookRelationship,
            receipts: inputs.bookAsideReceipts,
            appetite: inputs.bookWorkings.authority.appetite,
            distressActive: context.distress.isActive,
            rutward: inputs.inferredSignals.net > 0,
            now: now
        )
    }

    /// Reader-authored evidence creates one bounded editorial debt: once the
    /// Book is mature enough to reflect, a later desk should visibly spend that
    /// evidence instead of allowing every return Page to lose the lottery.
    ///
    /// The debt is not a feed cadence. It only reopens after new evidence, rests
    /// for at least three days, yields completely to distress, and reserves at
    /// most one ordinary Echo slot.
    private static func reservingEarnedReaderTraceIfOwed(
        in picked: [SurfacePage],
        candidates: [SurfacePage],
        day: BookDay,
        inputs: BookSourceInputs,
        context: CuratorContext,
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        now: Date,
        limit: Int,
        intention: BookSessionIntention,
        readerAliveness: ReaderAlivenessModel,
        alivenessFacets: Set<String>
    ) -> [SurfacePage] {
        let visibleLimit = min(3, max(0, limit))
        guard visibleLimit > 0,
              !context.distress.isActive,
              inputs.libraryReadyForReflectivePages(includingToday: day, now: now),
              !picked.prefix(visibleLimit).contains(where: \.carriesEarnedReaderTrace)
        else {
            return picked
        }

        guard EarnedReaderTracePolicy.owedEvidencePage(
            day: day,
            inputs: inputs,
            distressActive: context.distress.isActive,
            now: now
        ) != nil else { return picked }

        let eligible = candidates.filter { page in
            page.carriesEarnedReaderTrace
                && preferences.allows(page)
                && mood.allows(page)
                && page.pageCapabilities.isEligible(in: mood)
                && !BookMemoryGate.locks(page.type, keptPageCount: mood.keptPageCount)
                && CuratorNoveltyPolicy.allowsAutomaticSurface(
                    page,
                    history: mood.surfaceHistory,
                    preferences: preferences,
                    now: now
                )
        }
        guard let trace = weightedOrder(
            eligible,
            preferences: preferences,
            mood: mood,
            now: now,
            intention: intention,
            role: .echo,
            readerAliveness: readerAliveness,
            alivenessFacets: alivenessFacets,
            seed: intention.seed + "|earned-reader-trace"
        ).first else {
            return picked
        }

        let tracePage = intention.applying(to: trace, role: .echo)
        var result = picked
        let visibleIndices = Array(result.indices.prefix(visibleLimit))
        let conflicts = visibleIndices.filter {
            !result[$0].curatorDeskExclusionKeys.isDisjoint(with: tracePage.curatorDeskExclusionKeys)
        }

        func isProtected(_ page: SurfacePage) -> Bool {
            page.isDeskMilestone
                || page.type == .bookOfYou
                || page.payload.metadata["curatorPreparedArtifact"] == "true"
                || (
                    page.payload.metadata["bookCurationDirectiveID"] != nil
                        && page.spendsCuratorActionBudget
                )
                || page.payload.metadata["bookCampaignID"] != nil
        }

        let victim: Int?
        if let conflict = conflicts.first {
            victim = isProtected(result[conflict]) ? nil : conflict
        } else if result.count < visibleLimit {
            result.append(tracePage)
            return result
        } else {
            let replaceable = visibleIndices.filter { !isProtected(result[$0]) }
            if tracePage.spendsCuratorAskBudget,
               let existingAsk = replaceable.last(where: { result[$0].spendsCuratorAskBudget }) {
                victim = existingAsk
            } else if let echo = replaceable.last(where: {
                result[$0].payload.metadata[BookSessionIntention.metadataRole]
                    == BookSessionRole.echo.rawValue
            }) {
                victim = echo
            } else if let sameLane = replaceable.last(where: {
                result[$0].type.deskLane == tracePage.type.deskLane
            }) {
                victim = sameLane
            } else {
                victim = replaceable.last
            }
        }

        guard let victim else { return picked }
        if tracePage.spendsCuratorAskBudget,
           result.indices.contains(where: { index in
               index != victim
                   && index < visibleLimit
                   && result[index].spendsCuratorAskBudget
           }) {
            return picked
        }
        result[victim] = tracePage
        return result
    }

    /// The slot a guaranteed injection (sovereign shelf, evening braid) may
    /// claim. Prefer a page already in the injected page's lane so the desk
    /// stays balanced; otherwise the last non-milestone, non-braid slot. Never
    /// returns a milestone slot: those are pinned and never evicted.
    private static func injectionVictimIndex(
        in picked: [SurfacePage],
        preferringLane lane: DeskLane
    ) -> Int? {
        if let sameLane = picked.lastIndex(where: {
            $0.type.deskLane == lane && !$0.isDeskMilestone && $0.type != .bookOfYou
        }) {
            return sameLane
        }
        return picked.lastIndex(where: { !$0.isDeskMilestone && $0.type != .bookOfYou })
    }

    static func longGameDirectiveMayPress(
        _ hypothesis: BookLongGameHypothesis,
        learning: ReaderLearningModel,
        now: Date
    ) -> Bool {
        let tag = "long-game:\(hypothesis.capacity.rawValue)".readerLearningNormalizedTag
        guard let lastMeaningful = learning.events
            .filter({ event in
                event.tags.contains(tag)
                    && [.kept, .loved, .dismissed, .missed].contains(event.action)
            })
            .max(by: { $0.occurredAt < $1.occurredAt }) else {
            return true
        }
        if lastMeaningful.action == .dismissed || lastMeaningful.action == .missed {
            return now.timeIntervalSince(lastMeaningful.occurredAt) >= 3 * 86_400
        }
        return true
    }

    static func rankedPages(
        from candidates: [SurfacePage],
        limit: Int = 3,
        preferences: CuratorSurfacePreferences = .none,
        mood: CuratorMood = .neutral,
        now: Date = Date(),
        intention: BookSessionIntention? = nil,
        selectionSeed: String? = nil,
        readerAliveness: ReaderAlivenessModel = .unwritten,
        alivenessFacets: Set<String> = []
    ) -> [RankedSurfacePage] {
        // Hard filters: a reader's disabled sources and first-hours hidden types
        // are never overridden.
        let allowed = candidates
            .filter { preferences.allows($0) }
            .filter { mood.allows($0) }
            .filter { $0.pageCapabilities.isEligible(in: mood) }
            .filter { !BookMemoryGate.locks($0.type, keptPageCount: mood.keptPageCount) }
            .filter {
                CuratorNoveltyPolicy.allowsAutomaticSurface(
                    $0,
                    history: mood.surfaceHistory,
                    preferences: preferences,
                    now: now
                )
            }
        // The type-refresh cooldown only adds variety: it must never starve the
        // desk. Prefer pages that are off cooldown, but if that would leave the
        // homescreen empty, fall back to the full allowed pool.
        //
        // The fallback is deliberately "empty", not "short": suppression is
        // allowed to hand back a two-card desk rather than repeat a type the
        // reader saw twenty minutes ago (see
        // `testRecentlySurfacedPageTypeIsSuppressedBriefly`). Only a desk with
        // nothing on it is worse than a repeat.
        let offCooldown = allowed.filter { mood.allowsTypeRefresh(for: $0, now: now) }
        let pool = offCooldown.isEmpty ? allowed : offCooldown
        let sortedPages = pool
            .enumerated()
            .sorted { left, right in
                let leftScore = totalScore(for: left.element, preferences: preferences, mood: mood, now: now)
                let rightScore = totalScore(for: right.element, preferences: preferences, mood: mood, now: now)
                if leftScore == rightScore {
                    return left.offset < right.offset
                }
                return leftScore > rightScore
            }
            .map(\.element)
        // Three structural rules shape the desk, honored within rank order:
        //   1. Never repeat a source family: no two variants from the same
        //      preview system occupy the home shelf at once.
        //   2. Never repeat a kind of page: no two lore cards (or two of any
        //      type) on the shelf at once.
        //   3. Never stack blank-page "write one thing" prompts: at most one
        //      composition card (diary / souvenir / mood / about-you) at a time.
        // We would rather serve a shorter desk than break these rules.
        // A milestone wins any source/type exclusion collision before ordinary
        // cards are deduplicated. Its score still determines display order
        // later; this only protects its membership in the available shelf.
        let selectionOrder = sortedPages.enumerated().sorted { left, right in
            if left.element.isDeskMilestone != right.element.isDeskMilestone {
                return left.element.isDeskMilestone
            }
            return left.offset < right.offset
        }.map(\.element)
        // Stage one works with one representative per Page type. This keeps a
        // prolific family from buying twenty lottery tickets merely because it
        // supplied twenty variants. Stage two (inside `weightedOrder`) receives
        // the full `selectionOrder` and chooses the exact Page only after the
        // family has won its place.
        let typeRepresentatives = unique(selectionOrder)
        var picked: [SurfacePage] = []
        var pickedTypes: Set<BookPageType> = []
        var pickedSourceIDs: Set<String> = []
        var compositionCount = 0
        /// How much of the desk's taste the Curator is currently prepared to
        /// give up in order to hand back a furnished shelf. See the escalation
        /// after the main selection for what this is protecting against.
        var relaxation = DeskCapRelaxation.none
        var debutCount = 0
        var actionCommissionCount = 0
        var readerFacingAskCount = 0
        let visibleLimit = min(3, max(0, limit))
        // One blank-page prompt per three-slot desk: the home shelf (limit 3)
        // shows at most one, while wider introspection queries still surface the
        // full set of composition cards.
        let compositionLimit = max(1, limit / 3)
        // Staged families debut one at a time on the desk, so an unlock is a
        // single felt reveal rather than a wall of novelty. Wider queries
        // (limit > 3) scale the allowance instead of starving.
        let debutLimit = max(1, limit / 3)
        let actionCommissionLimit = max(1, limit / 3)
        let preparedContextKey = ReaderAlivenessCurationContext.contextKey(alivenessFacets)

        func isDebut(_ page: SurfacePage) -> Bool {
            page.payload.metadata["firstReading"] == "true"
                ? false
                : IntroductionCurriculum.isManagedDebut(page.type, surfaceHistory: mood.surfaceHistory)
        }
        func canAdd(_ page: SurfacePage) -> Bool {
            guard picked.count < limit else { return false }
            guard !pickedTypes.contains(page.type) else { return false }
            guard !pickedSourceIDs.contains(page.sourceID) else { return false }
            let isBuildingVisibleDesk = picked.count < visibleLimit
            // Preference caps. Each yields once the desk would otherwise come
            // back degenerate: see the escalation below.
            let currentCompositionLimit = relaxation.liftsAskCaps
                ? max(visibleLimit, compositionLimit)
                : (isBuildingVisibleDesk ? 1 : compositionLimit)
            let currentDebutLimit = relaxation.liftsDebutAndActionCaps
                ? max(visibleLimit, debutLimit)
                : (isBuildingVisibleDesk ? 1 : debutLimit)
            let currentActionLimit = relaxation.liftsDebutAndActionCaps
                ? max(visibleLimit, actionCommissionLimit)
                : (isBuildingVisibleDesk ? 1 : actionCommissionLimit)
            if page.type.isCompositionPrompt, compositionCount >= currentCompositionLimit { return false }
            if isDebut(page), debutCount >= currentDebutLimit { return false }
            if page.spendsCuratorActionBudget, actionCommissionCount >= currentActionLimit { return false }
            if isBuildingVisibleDesk, !relaxation.liftsAskCaps,
               page.spendsCuratorAskBudget, readerFacingAskCount >= 1 { return false }
            if page.spendsHighPressureCausalBudget,
               !page.isDeskMilestone,
               page.payload.metadata["firstRunStep"] == nil,
               !readerAliveness.allowsHighPressureCausalAttempt(now: now) { return false }
            return true
        }
        func add(
            _ page: SurfacePage,
            role: BookSessionRole? = nil,
            causalCandidates: [SurfacePage]? = nil,
            actIndex: Int = 0
        ) {
            let capablePage = page.withResolvedPageCapabilities()
            if isDebut(page) { debutCount += 1 }
            if page.type.isCompositionPrompt { compositionCount += 1 }
            if page.spendsCuratorActionBudget { actionCommissionCount += 1 }
            if page.spendsCuratorAskBudget { readerFacingAskCount += 1 }
            if let intention {
                let preparedBranch = BookPreparedExperimentScore.branch(forActIndex: actIndex)
                let selected: SurfacePage
                if let role,
                   intention.movement != .shelter,
                   let causalCandidates,
                   causalCandidates.count >= 2,
                   let receipt = causalReceipt(
                       for: capablePage,
                       among: causalCandidates,
                       preferences: preferences,
                       mood: mood,
                       now: now,
                       intention: intention,
                       role: role,
                       branch: preparedBranch,
                       readerAliveness: readerAliveness,
                       alivenessFacets: alivenessFacets
                   ) {
                    selected = receipt.applying(to: capablePage)
                } else {
                    selected = capablePage
                }
                let assignedRole = role
                    ?? BookSessionComposer.preferredRole(for: page, movement: intention.movement)
                let intended = intention.applying(
                    to: selected,
                    role: assignedRole
                )
                picked.append(BookPreparedExperimentScore.preparing(
                    intended,
                    intention: intention,
                    role: assignedRole,
                    actIndex: actIndex,
                    contextKey: preparedContextKey,
                    now: now
                ))
            } else {
                picked.append(capablePage)
            }
            pickedTypes.insert(page.type)
            pickedSourceIDs.insert(page.sourceID)
        }

        // The visible three-card prefix is balanced across lanes even when the
        // caller asks for a deeper refill bench. Previously `limit: 12` bypassed
        // this branch and the UI then displayed an unbalanced `prefix(3)`.
        let balancesVisibleDesk = limit >= 3
        // Milestones are promises the Book has already earned the right to
        // fulfill. Give them first claim on the visible prefix; additional
        // milestones remain first in the deeper selection order below.
        for page in typeRepresentatives where page.isDeskMilestone && picked.count < visibleLimit && canAdd(page) {
            add(page, role: picked.isEmpty ? .door : intention.map {
                BookSessionComposer.preferredRole(for: page, movement: $0.movement)
            })
        }
        // A generated or rendered artifact is work the reader explicitly
        // commissioned and the Book has finished. It reaches the visible desk
        // before ordinary probabilistic composition, without displacing a
        // protected milestone or breaking the one-commission boundary.
        for page in typeRepresentatives
            where page.payload.metadata["curatorPreparedArtifact"] == "true"
                && picked.count < visibleLimit
                && canAdd(page) {
            add(page, role: picked.isEmpty ? .door : intention.map {
                BookSessionComposer.preferredRole(for: page, movement: $0.movement)
            })
        }
        // If the desk has gone a week without turning toward the reader, the
        // best page that reflects them gets the next claim on the visible
        // prefix. It sits below milestones and finished commissions (promises
        // already made) and above ordinary composition. `typeRepresentatives`
        // is in rank order, so this takes the strongest available one.
        if balancesVisibleDesk,
           CuratorMirrorFloor.isOwed(
               history: mood.surfaceHistory,
               now: now,
               distressActive: mood.distressActive
           ),
           picked.count < visibleLimit,
           // A page carrying the earned reader trace is already governed by
           // `EarnedReaderTracePolicy`, which owes it a specific session role
           // (`.echo`, a return rather than an opening). Claiming it here would
           // stamp `.door` on it and then satisfy that policy's own guard, so
           // the debt would be silently spent in the wrong voice. Leave those
           // to the policy; the floor takes any other mirror.
           let mirror = typeRepresentatives.first(where: {
               $0.type.reflectsTheReader && !$0.carriesEarnedReaderTrace && canAdd($0)
           }) {
            add(mirror, role: picked.isEmpty ? .door : intention.map {
                BookSessionComposer.preferredRole(for: mirror, movement: $0.movement)
            })
        }
        let belovedReservationRoll = intention.map {
            abs(($0.seed + "|beloved-first-refusal").stableHash.stableScramble % 4)
        }
        if let intention,
           belovedReservationRoll != 0,
           picked.count < visibleLimit {
            // Very high Belief gives one coherent favorite first refusal on an
            // ordinary slot. It is still absent when resting, disabled, gated,
            // incompatible with every session role, or displaced by promises
            // the Book has already earned the duty to keep.
            let belovedCandidates = selectionOrder
                .filter { page in
                    CuratorNoveltyPolicy.belief(for: page, preferences: preferences)
                        >= CuratorNoveltyPolicy.belovedBeliefThreshold
                        && BookSessionRole.allCases.contains(where: { role in
                            BookSessionComposer.roleFit(for: page, role: role, movement: intention.movement) > 0
                        })
                        && canAdd(page)
                }
            let belovedByType = Dictionary(grouping: belovedCandidates, by: \.type)
            let belovedType = belovedByType.keys.max { leftType, rightType in
                let left = belovedByType[leftType] ?? []
                let right = belovedByType[rightType] ?? []
                let leftBelief = left.map { CuratorNoveltyPolicy.belief(for: $0, preferences: preferences) }.max() ?? 0
                let rightBelief = right.map { CuratorNoveltyPolicy.belief(for: $0, preferences: preferences) }.max() ?? 0
                if leftBelief == rightBelief {
                    let leftScore = left.map { totalScore(for: $0, preferences: preferences, mood: mood, now: now) }.max() ?? 0
                    let rightScore = right.map { totalScore(for: $0, preferences: preferences, mood: mood, now: now) }.max() ?? 0
                    if leftScore == rightScore {
                        return leftType.rawValue < rightType.rawValue
                    }
                    return leftScore < rightScore
                }
                return leftBelief < rightBelief
            }
            if let belovedType {
                // Belief first reserves the family. Then every eligible Page in
                // it (including its low-Belief surprises) receives the ordinary
                // second-stage exact-Page draw.
                let familyPages = selectionOrder.filter { page in
                    page.type == belovedType
                        && canAdd(page)
                        && BookSessionRole.allCases.contains(where: { role in
                            BookSessionComposer.roleFit(for: page, role: role, movement: intention.movement) > 0
                        })
                }
                let beloved = weightedOrder(
                    familyPages,
                    preferences: preferences,
                    mood: mood,
                    now: now,
                    intention: intention,
                    role: nil,
                    readerAliveness: readerAliveness,
                    alivenessFacets: alivenessFacets,
                    seed: intention.seed + "|beloved-page-detail"
                ).first
                if let beloved {
                    add(
                        beloved,
                        role: BookSessionComposer.preferredRole(for: beloved, movement: intention.movement)
                    )
                }
            }
        }
        if balancesVisibleDesk || intention != nil {
            if let intention, let selectionSeed {
                // A visible desk is a sentence before it is a taxonomy. Choose
                // one Door, Echo, and Horizon when honest candidates exist;
                // lane diversity remains the fallback rather than forcing an
                // unrelated card into a coherent session.
                for role in BookSessionRole.allCases {
                    guard picked.count < visibleLimit else { break }
                    guard !picked.contains(where: {
                        $0.payload.metadata[BookSessionIntention.metadataRole] == role.rawValue
                    }) else { continue }
                    if role == .door,
                       intention.movement == .shelter,
                       let rest = typeRepresentatives.first(where: { $0.type == .rest && canAdd($0) }) {
                        add(rest, role: .door)
                        continue
                    }
                    let eligibleRoleCandidates = selectionOrder.filter(canAdd)
                    let roleOrder = weightedOrder(
                        eligibleRoleCandidates,
                        preferences: preferences,
                        mood: mood,
                        now: now,
                        intention: intention,
                        role: role,
                        branch: .current,
                        readerAliveness: readerAliveness,
                        alivenessFacets: alivenessFacets,
                        seed: selectionSeed + "|" + role.rawValue
                    )
                    if let page = roleOrder.first {
                        add(page, role: role, causalCandidates: eligibleRoleCandidates)
                    }
                }
                for page in typeRepresentatives where picked.count < visibleLimit && canAdd(page) { add(page) }
            } else {
                for lane in DeskLane.allCases {
                    guard picked.count < visibleLimit else { break }
                    guard !picked.contains(where: { $0.type.deskLane == lane }) else { continue }
                    if let page = typeRepresentatives.first(where: { $0.type.deskLane == lane && canAdd($0) }) {
                        add(page)
                    }
                }
                for page in typeRepresentatives where picked.count < visibleLimit && canAdd(page) { add(page) }
                // Restore score order inside the visible trio, then append the
                // deep bench in rank order without displacing that trio.
                let rank = Dictionary(uniqueKeysWithValues: typeRepresentatives.enumerated().map { ($0.element.id, $0.offset) })
                picked.sort { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
            }
        }
        if let intention, let selectionSeed {
            // The deep bench is not a heap of leftovers. Compose it as further
            // Door / Echo / Horizon acts under the same experiment, with a
            // Keep branch, a clean-refusal branch, then adaptive reserve. Each
            // Page receives its own dormant causal assignment now and activates
            // only if it actually reaches the visible desk.
            var actIndex = 1
            while picked.count < limit {
                let countBeforeAct = picked.count
                // Branching decides how the next honest trio is arranged; it
                // does not give a low-ranked Page permission to vault the
                // Curator's entire bench. This preserves broad discoverability
                // while still preparing meaningfully different responses.
                let actFrontier = Array(typeRepresentatives.filter(canAdd).prefix(
                    BookSessionRole.allCases.count
                ))
                for role in BookSessionRole.allCases {
                    guard picked.count < limit else { break }
                    let frontierCandidates = actFrontier.filter(canAdd)
                    let eligibleRoleCandidates = frontierCandidates.isEmpty
                        ? typeRepresentatives.filter(canAdd)
                        : frontierCandidates
                    guard !eligibleRoleCandidates.isEmpty else { break }
                    let branch = BookPreparedExperimentScore.branch(forActIndex: actIndex)
                    let roleOrder = weightedOrder(
                        eligibleRoleCandidates,
                        preferences: preferences,
                        mood: mood,
                        now: now,
                        intention: intention,
                        role: role,
                        branch: branch,
                        readerAliveness: readerAliveness,
                        alivenessFacets: alivenessFacets,
                        seed: "\(selectionSeed)|prepared-act-\(actIndex)|\(branch.rawValue)|\(role.rawValue)"
                    )
                    guard let page = roleOrder.first else { continue }
                    add(
                        page,
                        role: role,
                        causalCandidates: eligibleRoleCandidates,
                        actIndex: actIndex
                    )
                }
                guard picked.count > countBeforeAct else { break }
                actIndex += 1
            }
        } else {
            for page in typeRepresentatives where canAdd(page) { add(page) }
        }

        // MARK: The furnishing invariant
        //
        // The desk is never shorter than its material allows for reasons that
        // are only preferences.
        //
        // Four separate bugs have had exactly this shape: a sensible cap,
        // written as a hard rule, quietly handing the reader a one-card desk.
        // The cooldown fallback that only fired at zero; the mirror floor that
        // outranked kindness; the composition limit and the one-ask cap
        // starving a young library. Patching them one at a time only waits for
        // the fifth, so every preference cap now yields here, in a fixed order
        // of how much character it costs to give up.
        //
        // Two things never yield, and both are correctness rather than taste:
        // no duplicate type or source family on one desk, and the high-pressure
        // attempt gate: relaxing that would corrupt the counterfactual it
        // exists to protect, which is the one cap with a principled reason to
        // starve a desk rather than bend.
        for level in DeskCapRelaxation.escalation {
            guard picked.count < visibleLimit else { break }
            let before = picked.count
            relaxation = level
            for page in typeRepresentatives where canAdd(page) { add(page) }
            // Stop as soon as a level buys nothing; the shortfall is material,
            // not taste, and a shorter desk is the honest answer.
            if picked.count == before, level == DeskCapRelaxation.escalation.last { break }
        }
        relaxation = .none

        return picked
            .enumerated()
            .map { offset, page in RankedSurfacePage(page: page, rank: offset + 1) }
    }

    /// Private diagnostics for answering “why am I seeing this again?” without
    /// exporting reader data or changing the ranking result.
    static func candidateTrace(
        from candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences = .none,
        mood: CuratorMood = .neutral,
        now: Date = Date(),
        intention: BookSessionIntention? = nil
    ) -> [CuratorCandidateTrace] {
        candidates.map { page in
            let preferenceAllowed = preferences.allows(page)
            let moodAllowed = mood.allows(page)
            let capability = page.pageCapabilities
            let capabilityAllowed = capability.isEligible(in: mood)
            let memoryAllowed = !BookMemoryGate.locks(page.type, keptPageCount: mood.keptPageCount)
            let noveltyAllowed = CuratorNoveltyPolicy.allowsAutomaticSurface(
                page,
                history: mood.surfaceHistory,
                preferences: preferences,
                now: now
            )
            let rejection: String?
            if !preferenceAllowed {
                rejection = "dismissed-or-disabled"
            } else if !moodAllowed {
                rejection = "introduction-or-first-hours-gate"
            } else if !capabilityAllowed {
                rejection = "capability-requirements-unmet"
            } else if !memoryAllowed {
                rejection = "memory-maturity-gate"
            } else if !noveltyAllowed {
                rejection = "exact-repeat-resting"
            } else {
                rejection = nil
            }
            return CuratorCandidateTrace(
                surfaceID: page.id,
                sourceID: page.sourceID,
                type: page.type,
                lane: page.type.deskLane,
                totalScore: totalScore(for: page, preferences: preferences, mood: mood, now: now),
                belief: CuratorNoveltyPolicy.belief(for: page, preferences: preferences),
                beliefSelectionMultiplier: preferences.beliefSelectionMultiplier(for: page),
                capabilitySignature: capability.signature,
                capabilityEffort: capability.effort,
                capabilityReach: capability.reach,
                capabilityFitMultiplier: capability.selectionMultiplier(
                    mood: mood,
                    movement: intention?.movement,
                    role: intention.map { BookSessionComposer.preferredRole(for: page, movement: $0.movement) }
                ),
                capabilityAllowed: capabilityAllowed,
                movement: intention?.movement,
                intentionFit: intention.map { BookSessionComposer.intentionFit(for: page, movement: $0.movement) } ?? 0,
                preferredRole: intention.map { BookSessionComposer.preferredRole(for: page, movement: $0.movement) },
                isNewType: CuratorNoveltyPolicy.isNewType(page, history: mood.surfaceHistory),
                isNewSource: CuratorNoveltyPolicy.isNewSource(page, history: mood.surfaceHistory),
                isNewContent: CuratorNoveltyPolicy.isNewContent(page, history: mood.surfaceHistory),
                rejection: rejection
            )
        }
    }

    private static func totalScore(
        for page: SurfacePage,
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        now: Date
    ) -> Int {
        preferences.adjustedScore(for: page)
            + mood.adjustment(for: page, now: now)
            + CuratorNoveltyPolicy.adjustment(
                for: page,
                history: mood.surfaceHistory,
                preferences: preferences,
                now: now
            )
    }

    /// A deterministic two-stage weighted permutation. Page types race first;
    /// then the concrete Pages inside each type race for the right to represent
    /// that family. Variant count therefore never increases a type's chance of
    /// being chosen, while every eligible individual Page keeps nonzero odds.
    private static func weightedOrder(
        _ pages: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        now: Date,
        intention: BookSessionIntention,
        role: BookSessionRole?,
        branch: BookPreparedExperimentBranch = .current,
        readerAliveness: ReaderAlivenessModel,
        alivenessFacets: Set<String>,
        seed: String
    ) -> [SurfacePage] {
        // Duplicate renderings of the same readable Page are one candidate,
        // not extra tickets in the within-type race.
        var seenContent = Set<String>()
        let indexed = pages.enumerated().compactMap { offset, page -> (offset: Int, page: SurfacePage)? in
            guard seenContent.insert(page.curatorContentNoveltyKey).inserted else { return nil }
            return (offset, page)
        }
        let families = Dictionary(grouping: indexed, by: { $0.page.type })
        let orderedTypes = families.keys.sorted { leftType, rightType in
            let left = families[leftType] ?? []
            let right = families[rightType] ?? []
            let leftWeight = left.map {
                selectionWeight(
                    for: $0.page,
                    preferences: preferences,
                    mood: mood,
                    now: now,
                    intention: intention,
                    role: role,
                    branch: branch,
                    readerAliveness: readerAliveness,
                    alivenessFacets: alivenessFacets
                )
            }.max() ?? 0.0001
            let rightWeight = right.map {
                selectionWeight(
                    for: $0.page,
                    preferences: preferences,
                    mood: mood,
                    now: now,
                    intention: intention,
                    role: role,
                    branch: branch,
                    readerAliveness: readerAliveness,
                    alivenessFacets: alivenessFacets
                )
            }.max() ?? 0.0001
            let leftRace = BookSessionDirector.weightedRace(
                seed: "\(seed)|page-type|\(leftType.rawValue)",
                weight: leftWeight
            )
            let rightRace = BookSessionDirector.weightedRace(
                seed: "\(seed)|page-type|\(rightType.rawValue)",
                weight: rightWeight
            )
            if leftRace == rightRace { return leftType.rawValue < rightType.rawValue }
            return leftRace < rightRace
        }
        return orderedTypes.compactMap { type -> SurfacePage? in
            guard let variants = families[type] else { return nil }
            return variants.sorted { left, right in
                let leftRace = selectionRace(
                    for: left.page,
                    originalOffset: left.offset,
                    preferences: preferences,
                    mood: mood,
                    now: now,
                    intention: intention,
                    role: role,
                    branch: branch,
                    readerAliveness: readerAliveness,
                    alivenessFacets: alivenessFacets,
                    seed: seed + "|page-detail|" + type.rawValue
                )
                let rightRace = selectionRace(
                    for: right.page,
                    originalOffset: right.offset,
                    preferences: preferences,
                    mood: mood,
                    now: now,
                    intention: intention,
                    role: role,
                    branch: branch,
                    readerAliveness: readerAliveness,
                    alivenessFacets: alivenessFacets,
                    seed: seed + "|page-detail|" + type.rawValue
                )
                if leftRace == rightRace { return left.offset < right.offset }
                return leftRace < rightRace
            }.first?.page
        }
    }

    private static func selectionRace(
        for page: SurfacePage,
        originalOffset: Int,
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        now: Date,
        intention: BookSessionIntention,
        role: BookSessionRole?,
        branch: BookPreparedExperimentBranch,
        readerAliveness: ReaderAlivenessModel,
        alivenessFacets: Set<String>,
        seed: String
    ) -> Double {
        let weight = selectionWeight(
            for: page,
            preferences: preferences,
            mood: mood,
            now: now,
            intention: intention,
            role: role,
            branch: branch,
            readerAliveness: readerAliveness,
            alivenessFacets: alivenessFacets
        )
        return BookSessionDirector.weightedRace(
            seed: "\(seed)|\(page.sourceID)|\(page.curatorContentNoveltyKey)|\(originalOffset)",
            weight: weight
        )
    }

    private static func selectionWeight(
        for page: SurfacePage,
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        now: Date,
        intention: BookSessionIntention,
        role: BookSessionRole?,
        branch: BookPreparedExperimentBranch,
        readerAliveness: ReaderAlivenessModel,
        alivenessFacets: Set<String>
    ) -> Double {
        let score = totalScore(for: page, preferences: preferences, mood: mood, now: now)
        let scoreWeight = max(0.2, min(2.4, 1.0 + Double(score - 60) / 80.0))
        let intentionPoints = BookSessionComposer.intentionFit(for: page, movement: intention.movement)
        let intentionWeight = 0.35 + Double(max(0, intentionPoints)) / 18.0
        let rolePoints = role.map {
            BookSessionComposer.roleFit(for: page, role: $0, movement: intention.movement)
        } ?? 0
        let roleWeight = role == nil ? 1.0 : max(0.18, 0.35 + Double(max(0, rolePoints)) / 18.0)
        let beliefWeight = preferences.beliefSelectionMultiplier(for: page)
        let intimateFacets = ReaderAlivenessCurationContext.addingSurfaceFacets(alivenessFacets, page: page)
        let alivenessWeight = readerAliveness.curationMultiplier(
            movement: intention.movement,
            sourceID: page.sourceID,
            currentFacets: intimateFacets,
            now: now
        )
        let contextKey = ReaderAlivenessCurationContext.contextKey(alivenessFacets)
        let causalWeight = role.map {
            readerAliveness.causalUpliftMultiplier(
                movement: intention.movement,
                role: $0,
                sourceID: page.sourceID,
                contextKey: contextKey,
                now: now
            )
        } ?? 1
        let capability = page.pageCapabilities
        let capabilityWeight = capability.selectionMultiplier(
            mood: mood,
            movement: intention.movement,
            role: role
        )
        let branchWeight = capability.branchMultiplier(for: branch)
        return max(
            0.0001,
            scoreWeight * intentionWeight * roleWeight * beliefWeight * alivenessWeight
                * causalWeight * capabilityWeight * branchWeight
        )
    }

    private static func causalReceipt(
        for selected: SurfacePage,
        among candidates: [SurfacePage],
        preferences: CuratorSurfacePreferences,
        mood: CuratorMood,
        now: Date,
        intention: BookSessionIntention,
        role: BookSessionRole,
        branch: BookPreparedExperimentBranch,
        readerAliveness: ReaderAlivenessModel,
        alivenessFacets: Set<String>
    ) -> CausalCurationReceipt? {
        let contextKey = ReaderAlivenessCurationContext.contextKey(alivenessFacets)
        let weightedPages = candidates.map { page -> (page: SurfacePage, candidate: CausalCurationCandidate) in
            let armID = causalArmID(
                for: page,
                intention: intention,
                role: role,
                branch: branch,
                contextKey: contextKey
            )
            return (page, CausalCurationCandidate(
                sourceID: page.sourceID,
                armID: armID,
                weight: selectionWeight(
                    for: page,
                    preferences: preferences,
                    mood: mood,
                    now: now,
                    intention: intention,
                    role: role,
                    branch: branch,
                    readerAliveness: readerAliveness,
                    alivenessFacets: alivenessFacets
                )
            ))
        }
        // Collapse duplicate renderings of the same semantic Page, never all
        // variants of a source. Page types receive one family weight (their
        // strongest currently eligible offering), then the exact variants race
        // only inside the chosen family.
        let byArm = Dictionary(grouping: weightedPages, by: { $0.candidate.armID })
        let uniquePages = byArm.values.compactMap { duplicates in
            duplicates.max { $0.candidate.weight < $1.candidate.weight }
        }
        let weighted = uniquePages.map(\.candidate).sorted { $0.armID < $1.armID }
        let chosenArmID = causalArmID(
            for: selected,
            intention: intention,
            role: role,
            branch: branch,
            contextKey: contextKey
        )
        guard weighted.count >= 2,
              let chosen = weighted.first(where: { $0.armID == chosenArmID }) else { return nil }
        let byType = Dictionary(grouping: uniquePages, by: { $0.page.type })
        let typeWeights = byType.mapValues { variants in
            variants.map { max(0, $0.candidate.weight) }.max() ?? 0
        }
        let totalTypeWeight = typeWeights.values.reduce(0, +)
        let chosenTypeWeight = typeWeights[selected.type] ?? 0
        let chosenTypePages = byType[selected.type] ?? []
        let withinTypeTotal = chosenTypePages.reduce(0) { $0 + max(0, $1.candidate.weight) }
        guard totalTypeWeight > 0, chosenTypeWeight > 0, withinTypeTotal > 0 else { return nil }
        let typePropensity = chosenTypeWeight / totalTypeWeight
        let pagePropensity = max(0, chosen.weight) / withinTypeTotal
        let overallPropensity = typePropensity * pagePropensity
        let pressureCost = selected.pageCapabilities.pressureCost
        let idSeed = "\(intention.id)|\(role.rawValue)|\(chosenArmID)|\(contextKey)"
        return CausalCurationReceipt(
            id: "causal-\(abs(idSeed.stableHash))",
            policyVersion: CausalCurationReceipt.currentPolicyVersion,
            sessionID: intention.id,
            movement: intention.movement,
            role: role,
            chosenSourceID: selected.sourceID,
            chosenArmID: chosenArmID,
            contextKey: contextKey,
            propensity: max(0.000_001, min(1, overallPropensity)),
            candidates: weighted,
            pressureCost: pressureCost,
            selectedAt: now,
            movementReceipt: intention.causalMovementReceipt,
            chosenType: selected.type,
            typePropensity: max(0.000_001, min(1, typePropensity)),
            pagePropensityWithinType: max(0.000_001, min(1, pagePropensity)),
            pageCandidateCountWithinType: chosenTypePages.count
        )
    }

    private static func causalArmID(
        for page: SurfacePage,
        intention: BookSessionIntention,
        role: BookSessionRole,
        branch: BookPreparedExperimentBranch,
        contextKey: String
    ) -> String {
        "\(intention.movement.rawValue)-\(role.rawValue)-\(branch.rawValue)-\(page.type.rawValue)-\(page.curatorContentNoveltyKey)-\(contextKey)"
            .readerLearningNormalizedTag
    }

    private static func unique(_ pages: [SurfacePage]) -> [SurfacePage] {
        var seen = Set<String>()
        return pages.filter { page in
            let keys = page.curatorDeskExclusionKeys
            guard keys.isDisjoint(with: seen) else { return false }
            seen.formUnion(keys)
            return true
        }
    }

    /// The desk's stability contract: cards the reader is looking at stay
    /// where they are. Only the reader removes a card (keeping it or swiping
    /// it away), and only that slot refills: a background rebuild never
    /// reorders, evicts, or wholesale-replaces the shown desk. This matters
    /// because dozens of state changes bump `surfaceRefreshDate` (foregrounding,
    /// archive reloads, belief ticks, pack changes…), the curator's rank is
    /// time-sensitive, and adapters rotate cadence slots through their ids:
    /// so a naive rebuild reshuffles the desk constantly.
    ///
    /// A rebuild may still:
    ///   - refresh a shown card's content in place when the same logical slot
    ///     (`deskSlotKey`) comes back with changed content, and
    ///   - fill genuinely empty desk slots from the fresh curation order.
    /// Compose the published block as repeated Door / Echo / Horizon acts.
    ///
    /// The Curator has always known this rhythm — a way in, the Book reflecting
    /// something back, then the world beyond — and it already composed the deep
    /// bench that way. The head of the block never got it: after selection,
    /// `picked` was re-sorted into score order, so the reader met three Pages
    /// ranked by score and then six arranged as acts. One block, two different
    /// ideas of what order means.
    ///
    /// That mattered less when three cards sat on a desk and the reader chose
    /// where to look. Turning one leaf at a time, order *is* the experience, so
    /// the whole block keeps one rhythm.
    ///
    /// This reorders only. Membership, rank, and every cap the Curator applied
    /// during selection are left exactly as they were: within a single beat the
    /// better-ranked Page still wins, and no Page is added, dropped, or
    /// re-scored. Roles the Curator already stamped are honoured; anything
    /// unstamped is fitted with the same `roleFit` the Curator uses, under the
    /// movement the block itself is carrying.
    static func readingArc(_ pages: [SurfacePage]) -> [SurfacePage] {
        guard pages.count > 2 else { return pages }

        // Every Page in a block belongs to one session, so the first intention
        // found speaks for all of them. Without one there is no movement to fit
        // against, and only stamped roles can be trusted.
        let movement = pages.lazy.compactMap { BookSessionIntention.read(from: $0)?.movement }.first

        // A block with neither a movement nor a stamped role has no rhythm to
        // compose — an unranked evergreen fallback, or a first-run sequence that
        // never went through session composition. Lane spacing is then the best
        // variety available, so hand over rather than shuffling to no purpose.
        guard movement != nil || pages.contains(where: { $0.preparedExperimentRole != nil }) else {
            return readingSequence(pages)
        }

        func role(of page: SurfacePage) -> BookSessionRole? {
            if let stamped = page.preparedExperimentRole { return stamped }
            guard let movement else { return nil }
            return BookSessionComposer.preferredRole(for: page, movement: movement)
        }

        var remaining = Array(pages.enumerated())
        var ordered: [SurfacePage] = []

        while !remaining.isEmpty {
            for beat in BookSessionRole.allCases {
                guard !remaining.isEmpty else { break }

                // Prefer a Page that wants this beat. Among those, rank decides.
                let wanted = remaining.first(where: { role(of: $0.element) == beat })
                // Otherwise let the movement say which of the survivors comes
                // closest, so a thin block still moves through the rhythm rather
                // than collapsing back into a ranked list.
                let fitted: (offset: Int, element: SurfacePage)? = movement.flatMap { movement in
                    remaining.max {
                        let left = BookSessionComposer.roleFit(for: $0.element, role: beat, movement: movement)
                        let right = BookSessionComposer.roleFit(for: $1.element, role: beat, movement: movement)
                        // Ties fall to the better-ranked Page: `max` keeps the
                        // later element on equality, so invert on a tie.
                        return left == right ? $0.offset > $1.offset : left < right
                    }
                }

                let chosen = wanted ?? fitted ?? remaining[0]
                remaining.removeAll { $0.offset == chosen.offset }
                ordered.append(chosen.element)
            }
        }

        return ordered
    }

    /// Space same-lane Pages apart along the block the reader turns through.
    ///
    /// The three-card desk needed variety to be visible *at a glance*, so lane
    /// balance was a property of a set: one outward, one fiction, one other,
    /// all on screen together. The folio shows one leaf at a time, so no reader
    /// ever sees two Pages at once and lane collision cannot be seen at all.
    /// What they feel instead is monotony *across turns* — which the old rule
    /// never governed, because it only ever covered the visible three.
    ///
    /// So variety becomes a run-length rule over the whole published block. The
    /// opening Page is never moved: it is the reader's entire first impression,
    /// and rank chose it. After that, a Page that would extend a same-lane run
    /// past `maxRun` yields to the best-ranked Page of another lane. Rank order
    /// is otherwise preserved, so this spaces the block without re-ranking it.
    static func readingSequence(
        _ pages: [SurfacePage],
        maxRun: Int = 2
    ) -> [SurfacePage] {
        guard pages.count > 2, maxRun >= 1 else { return pages }

        var remaining = pages
        var ordered: [SurfacePage] = [remaining.removeFirst()]
        var currentLane = ordered[0].type.deskLane
        var run = 1

        while !remaining.isEmpty {
            let pickIndex: Int
            if run >= maxRun,
               let relief = remaining.firstIndex(where: { $0.type.deskLane != currentLane }) {
                pickIndex = relief
            } else {
                // Either the run has room, or every Page left shares the lane
                // and spacing is simply not available. Rank wins in both cases.
                pickIndex = 0
            }

            let next = remaining.remove(at: pickIndex)
            if next.type.deskLane == currentLane {
                run += 1
            } else {
                currentLane = next.type.deskLane
                run = 1
            }
            ordered.append(next)
        }

        return ordered
    }

    static func stabilizedDeskOrder(
        previous: [SurfacePage],
        rebuilt: [SurfacePage],
        limit: Int = 3
    ) -> [SurfacePage] {
        guard !previous.isEmpty else { return Array(rebuilt.prefix(limit)) }

        let previousKeys = previous.map(\.deskSlotKey)
        // Duplicate slot keys (possible on paths that bypass the curator,
        // like the first-run sequence) make in-place matching ambiguous:
        // hold the shown desk untouched rather than guess.
        guard Set(previousKeys).count == previousKeys.count else { return previous }

        // An armed magic moment is the one deliberate exception to desk
        // stability. It should feel like a page the Book tucked in, not a
        // candidate waiting invisibly behind three familiar cards. Never
        // interrupt another milestone or evict the evening braid; when an
        // ordinary slot is available, let the earned reveal arrive on top.
        if limit > 0,
           let magic = rebuilt.first(where: { $0.payload.metadata["magicMoment"] == "true" }),
           !previous.contains(where: { shown in
               shown.id == magic.id
                   || (shown.payload.metadata["observationKey"]?.nonEmpty != nil
                       && shown.payload.metadata["observationKey"] == magic.payload.metadata["observationKey"])
           }),
           !previous.contains(where: { $0.payload.metadata["firstReading"] == "true" }) {
            var survivors = previous
            let conflictingIndex = survivors.lastIndex(where: {
                !$0.curatorDeskExclusionKeys.isDisjoint(with: magic.curatorDeskExclusionKeys)
            })
            let victimIndex = conflictingIndex ?? (survivors.count >= limit
                ? injectionVictimIndex(in: survivors, preferringLane: magic.type.deskLane)
                : nil)

            if let victimIndex,
               !survivors[victimIndex].isDeskMilestone,
               survivors[victimIndex].type != .bookOfYou {
                survivors.remove(at: victimIndex)
                var desk = [magic]
                var occupiedSlots: Set<String> = [magic.deskSlotKey]
                var occupiedKeys = Set(magic.curatorDeskExclusionKeys)
                for candidate in survivors + rebuilt where desk.count < limit {
                    guard !occupiedSlots.contains(candidate.deskSlotKey),
                          candidate.curatorDeskExclusionKeys.isDisjoint(with: occupiedKeys)
                    else { continue }
                    desk.append(candidate)
                    occupiedSlots.insert(candidate.deskSlotKey)
                    occupiedKeys.formUnion(candidate.curatorDeskExclusionKeys)
                }
                return desk
            } else if survivors.count < limit {
                return Array(([magic] + survivors).prefix(limit))
            }
        }

        let rebuiltByKey = Dictionary(
            rebuilt.map { ($0.deskSlotKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var desk = previous.map { shown -> SurfacePage in
            guard let fresh = rebuiltByKey[shown.deskSlotKey] else { return shown }
            return fresh.contentMatches(shown) ? shown : fresh
        }

        // Fill only genuinely empty slots; shown cards keep their places.
        var occupiedSlots = Set(desk.map(\.deskSlotKey))
        var occupiedKeys = Set(desk.flatMap(\.curatorDeskExclusionKeys))
        for candidate in rebuilt where desk.count < limit {
            guard !occupiedSlots.contains(candidate.deskSlotKey),
                  candidate.curatorDeskExclusionKeys.isDisjoint(with: occupiedKeys)
            else { continue }
            desk.append(candidate)
            occupiedSlots.insert(candidate.deskSlotKey)
            occupiedKeys.formUnion(candidate.curatorDeskExclusionKeys)
        }
        return desk
    }

    /// Gives one newly timely Page the top of an untouched desk without
    /// sacrificing promises or stacking asks. Callers must enforce the
    /// untouched-desk condition; a reader who has already begun choosing keeps
    /// the encounter exactly as met and receives this Page from the bench at
    /// the next vacancy instead.
    static func insertingLiveOpportunityIntoUntouchedDesk(
        previous: [SurfacePage],
        rebuilt: [SurfacePage],
        limit: Int = 3
    ) -> [SurfacePage] {
        guard limit > 0,
              let opportunity = rebuilt.first(where: \.isLiveOpportunityInterruptTarget),
              !previous.contains(where: { $0.id == opportunity.id }),
              !previous.contains(where: { $0.payload.metadata["firstRunStep"] != nil }) else {
            return stabilizedDeskOrder(previous: previous, rebuilt: rebuilt, limit: limit)
        }

        let protected: (SurfacePage) -> Bool = {
            $0.isDeskMilestone || $0.type == .bookOfYou
        }
        var survivors = Array(previous.prefix(limit)).filter { $0.id != opportunity.id }
        let conflictingIndex = survivors.lastIndex(where: {
            !protected($0)
                && ($0.type == opportunity.type
                    || $0.sourceID == opportunity.sourceID
                    || !$0.curatorDeskExclusionKeys.isDisjoint(with: opportunity.curatorDeskExclusionKeys))
        })
        let pressureIndex = opportunity.spendsCuratorActionBudget
            ? survivors.lastIndex(where: { !protected($0) && $0.spendsCuratorActionBudget })
            : (opportunity.spendsCuratorAskBudget
                ? survivors.lastIndex(where: { !protected($0) && $0.spendsCuratorAskBudget })
                : nil)
        let victimIndex = conflictingIndex
            ?? pressureIndex
            ?? (survivors.count >= limit
                ? injectionVictimIndex(in: survivors, preferringLane: opportunity.type.deskLane)
                : nil)

        if let victimIndex {
            guard !protected(survivors[victimIndex]) else {
                return stabilizedDeskOrder(previous: previous, rebuilt: rebuilt, limit: limit)
            }
            survivors.remove(at: victimIndex)
        } else if survivors.count >= limit {
            // A completely protected desk is stronger than timeliness. The
            // opportunity remains first in the prepared bench instead.
            return stabilizedDeskOrder(previous: previous, rebuilt: rebuilt, limit: limit)
        }

        var desk = [opportunity]
        var occupiedSlots: Set<String> = [opportunity.deskSlotKey]
        var occupiedKeys = Set(opportunity.curatorDeskExclusionKeys)
        var actionCount = opportunity.spendsCuratorActionBudget ? 1 : 0
        var askCount = opportunity.spendsCuratorAskBudget ? 1 : 0
        for candidate in survivors + rebuilt where desk.count < limit {
            guard candidate.id != opportunity.id,
                  !occupiedSlots.contains(candidate.deskSlotKey),
                  candidate.curatorDeskExclusionKeys.isDisjoint(with: occupiedKeys),
                  !candidate.spendsCuratorActionBudget || actionCount == 0,
                  !candidate.spendsCuratorAskBudget || askCount == 0 else { continue }
            desk.append(candidate)
            occupiedSlots.insert(candidate.deskSlotKey)
            occupiedKeys.formUnion(candidate.curatorDeskExclusionKeys)
            if candidate.spendsCuratorActionBudget { actionCount += 1 }
            if candidate.spendsCuratorAskBudget { askCount += 1 }
        }
        return desk
    }

    struct DeskRetirementResolution {
        var pages: [SurfacePage]
        var replacementIDByRetiringID: [String: String]

        func replacesAll(_ retiringIDs: Set<String>) -> Bool {
            !retiringIDs.isEmpty
                && Set(replacementIDByRetiringID.keys) == retiringIDs
        }
    }

    /// Restores an explicitly dismissed card without sacrificing a survivor if
    /// the original replacement is no longer identifiable. When a refill has
    /// merely appended a new card after a no-candidate retirement, insertion at
    /// the saved slot followed by truncation preserves the original desk order.
    static func restoringRetiredDeskSlot(
        current: [SurfacePage],
        surface: SurfacePage,
        replacementID: String?,
        preferredIndex: Int?,
        limit: Int = 3
    ) -> [SurfacePage] {
        guard limit > 0 else { return [] }
        var restored = Array(current.prefix(limit))
        guard !restored.contains(where: { $0.id == surface.id }) else { return restored }

        if let replacementID,
           let replacementIndex = restored.firstIndex(where: { $0.id == replacementID }) {
            restored[replacementIndex] = surface
        } else {
            let fallbackIndex = restored.count < limit ? restored.count : 0
            let insertionIndex = min(max(0, preferredIndex ?? fallbackIndex), restored.count)
            restored.insert(surface, at: insertionIndex)
        }
        return Array(restored.prefix(limit))
    }

    /// Resolves one or more already-hidden desk slots without ever publishing an
    /// intermediate short desk. Surviving cards keep their order; each outgoing
    /// card is replaced at its own position by the first non-conflicting rebuilt
    /// candidate. A slot is removed only in this final resolution when no valid
    /// replacement exists.
    /// Orders an already-prepared bench for an instantaneous reader-triggered
    /// refill. Ordinary exits stay inside the same score and prefer the branch
    /// composed for that response and the role that just became vacant. Once
    /// repeated distinct Door refusals sleep the score, its remaining prepared
    /// candidates wait with it and a newly directed Door takes over. Stale
    /// prepared context is discarded; unscored emergency play remains a final
    /// neutral fallback.
    static func preparedReplacementOrder(
        candidates: [SurfacePage],
        departing: SurfacePage,
        outcome: BookSessionExitOutcome,
        contextKey: String,
        now: Date,
        sleepsExperiment: Bool
    ) -> [SurfacePage] {
        let departingIntentionID = departing.preparedExperimentIntentionID
        let departingRole = departing.preparedExperimentRole
        return candidates.enumerated()
            .filter { _, candidate in
                let isFresh = candidate.preparedExperimentContextKey == nil
                    || candidate.preparedExperimentIsFresh(contextKey: contextKey, now: now)
                guard isFresh else { return false }
                if sleepsExperiment,
                   let departingIntentionID,
                   candidate.preparedExperimentIntentionID == departingIntentionID {
                    return false
                }
                return true
            }
            .sorted { left, right in
                func score(_ candidate: SurfacePage) -> Int {
                    let candidateIntentionID = candidate.preparedExperimentIntentionID
                    let isNeutral = candidateIntentionID == nil
                    var value = isNeutral ? -1_000 : 0
                    if sleepsExperiment {
                        if candidateIntentionID != nil,
                           candidateIntentionID != departingIntentionID { value += 1_000 }
                        if candidate.preparedExperimentRole == .door { value += 180 }
                        if candidate.preparedExperimentActIndex == 0 { value += 80 }
                    } else {
                        if candidateIntentionID == departingIntentionID { value += 1_000 }
                        if candidate.preparedExperimentBranch?.matches(outcome) == true { value += 240 }
                        if candidate.preparedExperimentRole == departingRole { value += 120 }
                        if candidate.preparedExperimentBranch == .adaptive { value += 30 }
                    }
                    value -= candidate.preparedExperimentActIndex ?? 99
                    return value
                }
                let leftScore = score(left.element)
                let rightScore = score(right.element)
                if leftScore == rightScore { return left.offset < right.offset }
                return leftScore > rightScore
            }
            .map(\.element)
    }

    static func resolvingRetiredDeskSlots(
        previous: [SurfacePage],
        retiringIDs: Set<String>,
        rebuilt: [SurfacePage],
        preferredCandidatesByRetiringID: [String: [SurfacePage]] = [:],
        additionallyBlockedKeys: Set<String> = [],
        enforcesVisiblePressureBudget: Bool = true,
        limit: Int = 3
    ) -> DeskRetirementResolution {
        let shown = Array(previous.prefix(limit))
        let shownIDs = Set(shown.map(\.id))
        let activeRetiringIDs = retiringIDs.intersection(shownIDs)
        guard !activeRetiringIDs.isEmpty else {
            return DeskRetirementResolution(
                pages: shown,
                replacementIDByRetiringID: [:]
            )
        }

        let survivors = shown.filter { !activeRetiringIDs.contains($0.id) }
        var occupiedKeys = Set(survivors.flatMap(\.curatorDeskExclusionKeys))
        var usedCandidateIDs = Set(survivors.map(\.id))
        let visibleSurvivors = shown.prefix(BookDeskRound.openingCapacity)
            .filter { !activeRetiringIDs.contains($0.id) }
        var actionCommissionCount = visibleSurvivors.filter(\.spendsCuratorActionBudget).count
        var readerFacingAskCount = visibleSurvivors.filter(\.spendsCuratorAskBudget).count
        var replacementIDByRetiringID: [String: String] = [:]
        var resolved: [SurfacePage] = []

        for (slotIndex, page) in shown.enumerated() {
            guard activeRetiringIDs.contains(page.id) else {
                resolved.append(page)
                continue
            }

            let replacementPool = preferredCandidatesByRetiringID[page.id] ?? rebuilt
            let fillsVisibleSlot = slotIndex < BookDeskRound.openingCapacity
            guard let replacement = replacementPool.first(where: { candidate in
                !usedCandidateIDs.contains(candidate.id)
                    // A blank writing Page has already spent the reader's
                    // sentence-making attention. Its immediate successor must
                    // change the mode, even when another composition Page is
                    // the highest-ranked refill candidate.
                    && !(activeRetiringIDs.count == 1
                        && page.type.isCompositionPrompt
                        && candidate.type.isCompositionPrompt)
                    && candidate.curatorDeskExclusionKeys.isDisjoint(with: occupiedKeys)
                    && candidate.curatorDeskExclusionKeys.isDisjoint(with: additionallyBlockedKeys)
                    && (!enforcesVisiblePressureBudget || !fillsVisibleSlot || !candidate.spendsCuratorActionBudget || actionCommissionCount == 0)
                    && (!enforcesVisiblePressureBudget || !fillsVisibleSlot || !candidate.spendsCuratorAskBudget || readerFacingAskCount == 0)
            }) else {
                continue
            }

            resolved.append(replacement)
            replacementIDByRetiringID[page.id] = replacement.id
            usedCandidateIDs.insert(replacement.id)
            occupiedKeys.formUnion(replacement.curatorDeskExclusionKeys)
            if enforcesVisiblePressureBudget, fillsVisibleSlot, replacement.spendsCuratorActionBudget {
                actionCommissionCount += 1
            }
            if enforcesVisiblePressureBudget, fillsVisibleSlot, replacement.spendsCuratorAskBudget {
                readerFacingAskCount += 1
            }
        }

        return DeskRetirementResolution(
            pages: Array(resolved.prefix(limit)),
            replacementIDByRetiringID: replacementIDByRetiringID
        )
    }

    /// Replaces the whole visible desk for an explicit reader refresh. Unlike
    /// `stabilizedDeskOrder`, this is allowed to evict shown cards, but it only
    /// publishes when every visible slot has a non-conflicting replacement so
    /// pull-to-refresh can never leave a shortened or half-refreshed desk.
    static func refreshedDeskOrder(
        previous: [SurfacePage],
        rebuilt: [SurfacePage],
        limit: Int = 3
    ) -> [SurfacePage] {
        let shown = Array(previous.prefix(limit))
        guard !shown.isEmpty else { return Array(rebuilt.prefix(limit)) }

        let retiringIDs = Set(shown.map(\.id))
        let outgoingKeys = Set(shown.flatMap(\.curatorDeskExclusionKeys))
        let resolution = resolvingRetiredDeskSlots(
            previous: shown,
            retiringIDs: retiringIDs,
            rebuilt: rebuilt,
            additionallyBlockedKeys: outgoingKeys,
            enforcesVisiblePressureBudget: false,
            limit: limit
        )
        return resolution.replacesAll(retiringIDs) ? resolution.pages : shown
    }
}

struct CuratorCandidateTrace: Equatable {
    var surfaceID: String
    var sourceID: String
    var type: BookPageType
    var lane: DeskLane
    var totalScore: Int
    var belief: Int
    var beliefSelectionMultiplier: Double
    var capabilitySignature: String
    var capabilityEffort: PageCapabilityEffort
    var capabilityReach: PageCapabilityReach
    var capabilityFitMultiplier: Double
    var capabilityAllowed: Bool
    var movement: BookReenchantmentMovement?
    var intentionFit: Int
    var preferredRole: BookSessionRole?
    var isNewType: Bool
    var isNewSource: Bool
    var isNewContent: Bool
    var rejection: String?
}

// MARK: - Curator Observatory

/// The outcome state of one Page opportunity as seen by the private
/// Observatory. In-Book interaction is intentionally separate from qualified
/// lived support, and counter-evidence has its own first-class state.
enum CuratorObservatoryOutcomeState: String, Equatable {
    case notCausal
    case awaitingEvidence
    case interactionOnly
    case livedSupport
    case counterEvidence
    case mixed
}

struct CuratorObservatoryNorthStar: Equatable {
    var direction: ReaderReenchantmentDirection
    var confidence: Int
    var currentScore: Int?
    var sevenDayAverage: Double?
    var thirtyDayChange: Double?
    var distinctMeasuredDays: Int
    var livedProofCount: Int
    var counterSignalCount: Int
    var causalOutcomeCount: Int
    var evidenceStreamCount: Int
}

struct CuratorObservatoryIntention: Equatable {
    var id: String
    var movement: BookReenchantmentMovement
    var ambition: BookSessionAmbition
    var evidenceCount: Int
    var expiresAt: Date
    var liveOpportunityKind: BookLiveOpportunityKind?
}

struct CuratorObservatoryStrategy: Equatable {
    var id: String
    var status: BookReenchantmentStrategyStatus
    var capacity: BookLongGameCapacity
    var movement: BookReenchantmentMovement
    var tactic: BookCampaignTactic
    var confidence: Int
    var outcomeEvidenceCount: Int
    var packetSignature: String
}

struct CuratorObservatoryCandidate: Equatable, Identifiable {
    var id: String { surfaceID }
    var surfaceID: String
    var sourceID: String
    var type: BookPageType
    var lane: DeskLane
    var isVisible: Bool
    var totalScore: Int
    var belief: Int
    var beliefSelectionMultiplier: Double
    var capabilitySignature: String
    var capabilityEffort: PageCapabilityEffort
    var capabilityReach: PageCapabilityReach
    var capabilityFitMultiplier: Double
    var intentionFit: Int
    var preferredRole: BookSessionRole?
    var isNewType: Bool
    var isNewSource: Bool
    var isNewContent: Bool
    var rejection: String?
}

struct CuratorObservatoryCausalEffect: Equatable {
    var treatmentCount: Int
    var controlCount: Int
    var estimatedUplift: Double
    var conservativeLowerBound: Double
    var conservativeUpperBound: Double
    var usedExactContext: Bool
    var appliedMultiplier: Double
    /// Specificity-weighted evidence behind the reading. Reported alongside the
    /// raw row counts because a reading assembled from neighbouring roles or
    /// contexts holds less than the same number of local rows would.
    var effectiveTreatmentSamples: Double = 0
    var effectiveControlSamples: Double = 0

    /// Deliberately the same rule the ledger applies before it will move the
    /// desk. These two drifting apart would let the Observatory report a
    /// reading the Curator never acted on, or hide one it did.
    var isLearned: Bool {
        effectiveTreatmentSamples >= CausalUpliftEstimate.minimumEffectiveSamples
            && effectiveControlSamples >= CausalUpliftEstimate.minimumEffectiveSamples
    }
}

struct CuratorObservatoryExposure: Equatable, Identifiable {
    var id: String { surfaceID }
    var surfaceID: String
    var sourceID: String
    var type: BookPageType
    var movement: BookReenchantmentMovement?
    var role: BookSessionRole?
    var actIndex: Int?
    var branch: BookPreparedExperimentBranch?
    var encounterMode: LivedEncounterMode
    var mayMintLivedReceipt: Bool
    var capabilitySignature: String
    var causalOpportunityID: String?
    var assignmentPropensity: Double?
    var alternativeCount: Int
    var outcomeState: CuratorObservatoryOutcomeState
    var qualifiedOutcomeCount: Int
    var interactionOnlyCount: Int
    var latestOutcomeKind: CausalAlivenessOutcomeKind?
    var latestOutcomeValue: Double?
    var causalEffect: CuratorObservatoryCausalEffect?
}

struct CuratorObservatoryCausalSummary: Equatable {
    var pageOpportunityCount: Int
    var movementOpportunityCount: Int
    var qualifiedOutcomeCount: Int
    var interactionOnlyOutcomeCount: Int
    var livedSupportCount: Int
    var counterEvidenceCount: Int
    var unresolvedOpportunityCount: Int
}

enum CuratorObservatoryColdStartStage: String, Equatable {
    case unseeded
    case seeded
    case testing
    case evidenceLed
}

/// A prose-free account of what currently authorizes cold-start curation.
/// Declared answers are kept visibly separate from qualified lived outcomes so
/// neither diagnostics nor future policy can quietly relabel a preference as
/// evidence that an intervention worked.
struct CuratorObservatoryColdStart: Equatable {
    var stage: CuratorObservatoryColdStartStage
    var onboardingPriorCount: Int
    var declaredPriorCount: Int
    var boundaryCount: Int
    var currentStateDimensionCount: Int
    var qualifiedOutcomeCount: Int
    var answeredHighValueQuestionCount: Int
    var missingHighValueQuestionIDs: [String]
}

/// One bounded, local, prose-free audit of the Curator's whole causal chain.
///
/// The Observatory does not become another analytics authority. It projects
/// the production candidate trace, committed Page metadata, causal ledger,
/// Re-enchantment reading, and active Long Game strategy into a single
/// inspectable value. It contains no Page copy, reader prose, coordinates,
/// place names, Calendar titles, media, or raw state-poll answers.
struct CuratorObservatorySnapshot: Equatable {
    static let currentVersion = 2

    var version: Int
    var builtAt: Date
    var dayID: String
    var candidateCount: Int
    var eligibleCandidateCount: Int
    var rejectedCandidateCount: Int
    var rejectionCounts: [String: Int]
    var candidates: [CuratorObservatoryCandidate]
    var exposures: [CuratorObservatoryExposure]
    var intention: CuratorObservatoryIntention?
    var movementEffect: CuratorObservatoryCausalEffect?
    var northStar: CuratorObservatoryNorthStar
    var activeStrategy: CuratorObservatoryStrategy?
    var causal: CuratorObservatoryCausalSummary
    var coldStart: CuratorObservatoryColdStart
}

enum CuratorObservatory {
    static let maxCandidateRows = 96
    static let maxExposureRows = 12

    static func snapshot(
        day: BookDay,
        candidates: [SurfacePage],
        visibleSurfaces: [SurfacePage],
        inputs: BookSourceInputs,
        preferences: CuratorSurfacePreferences = .none,
        distressActive: Bool = false,
        now: Date = Date()
    ) -> CuratorObservatorySnapshot {
        let mood = CuratorMood.make(
            inputs: inputs,
            distressActive: distressActive,
            now: now
        )
        let intention = visibleSurfaces.lazy.compactMap(BookSessionIntention.read(from:)).first
            ?? inputs.activeBookSessionIntention
        let traces = BookCurator.candidateTrace(
            from: candidates,
            preferences: preferences,
            mood: mood,
            now: now,
            intention: intention
        )
        let visibleIDs = Set(visibleSurfaces.map(\.id))
        let candidateRows = traces.map { trace in
            CuratorObservatoryCandidate(
                surfaceID: trace.surfaceID,
                sourceID: trace.sourceID,
                type: trace.type,
                lane: trace.lane,
                isVisible: visibleIDs.contains(trace.surfaceID),
                totalScore: trace.totalScore,
                belief: trace.belief,
                beliefSelectionMultiplier: trace.beliefSelectionMultiplier,
                capabilitySignature: trace.capabilitySignature,
                capabilityEffort: trace.capabilityEffort,
                capabilityReach: trace.capabilityReach,
                capabilityFitMultiplier: trace.capabilityFitMultiplier,
                intentionFit: trace.intentionFit,
                preferredRole: trace.preferredRole,
                isNewType: trace.isNewType,
                isNewSource: trace.isNewSource,
                isNewContent: trace.isNewContent,
                rejection: trace.rejection
            )
        }
        .sorted { left, right in
            if left.isVisible != right.isVisible { return left.isVisible }
            if (left.rejection == nil) != (right.rejection == nil) {
                return left.rejection == nil
            }
            if left.totalScore != right.totalScore { return left.totalScore > right.totalScore }
            return left.surfaceID < right.surfaceID
        }
        let ledger = inputs.readerAliveness.causalLedger ?? .unwritten
        let exposures = visibleSurfaces.prefix(maxExposureRows).map {
            exposure(for: $0, ledger: ledger, now: now)
        }
        let reading = ReaderReenchantmentMeasure.reading(
            pulses: inputs.readerStatePulses,
            aliveness: inputs.readerAliveness,
            longGame: inputs.bookInterior.longGame,
            learning: inputs.readerLearning,
            days: inputs.days + [day],
            now: now
        )
        let qualifiedOutcomes = ledger.outcomes.filter(\.kind.isQualified)
        let interactionOnly = ledger.outcomes.filter { !$0.kind.isQualified }
        let counter = qualifiedOutcomes.filter(isCounterEvidence)
        let support = qualifiedOutcomes.filter {
            !isCounterEvidence($0) && $0.value > 0
        }
        let opportunityIDsWithQualifiedOutcome = Set(qualifiedOutcomes.map(\.opportunityID))
        let allOpportunityIDs = Set(
            ledger.opportunities.map(\.id) + ledger.movementOpportunities.map(\.id)
        )
        let rejectionCounts = Dictionary(grouping: traces.compactMap(\.rejection), by: { $0 })
            .mapValues(\.count)
        let coldStart = coldStartReading(
            inputs: inputs,
            qualifiedOutcomeCount: qualifiedOutcomes.count,
            now: now
        )

        return CuratorObservatorySnapshot(
            version: CuratorObservatorySnapshot.currentVersion,
            builtAt: now,
            dayID: day.id,
            candidateCount: traces.count,
            eligibleCandidateCount: traces.filter { $0.rejection == nil }.count,
            rejectedCandidateCount: traces.filter { $0.rejection != nil }.count,
            rejectionCounts: rejectionCounts,
            candidates: Array(candidateRows.prefix(maxCandidateRows)),
            exposures: exposures,
            intention: intention.map {
                CuratorObservatoryIntention(
                    id: $0.id,
                    movement: $0.movement,
                    ambition: $0.ambition,
                    evidenceCount: $0.evidencePageIDs.count,
                    expiresAt: $0.expiresAt,
                    liveOpportunityKind: $0.liveOpportunity?.kind
                )
            },
            movementEffect: intention.flatMap {
                movementEffect(for: $0, ledger: ledger, now: now)
            },
            northStar: CuratorObservatoryNorthStar(
                direction: reading.direction,
                confidence: reading.confidence,
                currentScore: reading.currentScore,
                sevenDayAverage: reading.sevenDayAverage,
                thirtyDayChange: reading.thirtyDayChange,
                distinctMeasuredDays: reading.distinctMeasuredDays,
                livedProofCount: reading.livedProofCount,
                counterSignalCount: reading.counterSignalCount,
                causalOutcomeCount: reading.causalOutcomeCount,
                evidenceStreamCount: reading.evidenceStreamCount
            ),
            activeStrategy: inputs.bookInterior.longGame?.activeStrategy.map {
                CuratorObservatoryStrategy(
                    id: $0.id,
                    status: $0.status,
                    capacity: $0.capacity,
                    movement: $0.movement,
                    tactic: $0.tactic,
                    confidence: $0.confidence,
                    outcomeEvidenceCount: $0.outcomeEvidenceIDs.count,
                    packetSignature: $0.packetSignature
                )
            },
            causal: CuratorObservatoryCausalSummary(
                pageOpportunityCount: ledger.opportunities.count,
                movementOpportunityCount: ledger.movementOpportunities.count,
                qualifiedOutcomeCount: qualifiedOutcomes.count,
                interactionOnlyOutcomeCount: interactionOnly.count,
                livedSupportCount: support.count,
                counterEvidenceCount: counter.count,
                unresolvedOpportunityCount: allOpportunityIDs
                    .subtracting(opportunityIDsWithQualifiedOutcome)
                    .count
            ),
            coldStart: coldStart
        )
    }

    private static func coldStartReading(
        inputs: BookSourceInputs,
        qualifiedOutcomeCount: Int,
        now: Date
    ) -> CuratorObservatoryColdStart {
        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let answeredIDs = Set(usableFacts.map(\.questionID))
        let onboardingPriorIDs: Set<String> = [
            "onboarding-rut-strongest",
            "onboarding-most-alive",
            "onboarding-magic-source",
            "onboarding-taste",
            "onboarding-comfort-boundary",
            "onboarding-drawn-chapter"
        ]
        let boundaryIDs: Set<String> = [
            "leaving-home",
            "movement-access",
            "time-budget",
            "money-boundary"
        ]
        let declaredPriorIDs = SelfKnowledgePackRegistry.causalColdStartQuestionIDs
            .subtracting(boundaryIDs)
        let currentState = inputs.readerStatePulses.currentState(now: now)
        let stateCount = [
            currentState.aliveness,
            currentState.wonder,
            currentState.hiddenMagic,
            currentState.capacity
        ].compactMap { $0 }.count
        let onboardingCount = answeredIDs.intersection(onboardingPriorIDs).count
        let answeredHighValue = answeredIDs
            .intersection(SelfKnowledgePackRegistry.causalColdStartQuestionIDs)
            .count
        let stage: CuratorObservatoryColdStartStage
        if qualifiedOutcomeCount >= 6 {
            stage = .evidenceLed
        } else if qualifiedOutcomeCount > 0 {
            stage = .testing
        } else if onboardingCount > 0 || answeredHighValue > 0 {
            stage = .seeded
        } else {
            stage = .unseeded
        }

        return CuratorObservatoryColdStart(
            stage: stage,
            onboardingPriorCount: onboardingCount,
            declaredPriorCount: answeredIDs.intersection(declaredPriorIDs).count,
            boundaryCount: answeredIDs.intersection(boundaryIDs).count,
            currentStateDimensionCount: stateCount,
            qualifiedOutcomeCount: qualifiedOutcomeCount,
            answeredHighValueQuestionCount: answeredHighValue,
            missingHighValueQuestionIDs: SelfKnowledgePackRegistry.causalColdStartQuestionOrder
                .filter { !answeredIDs.contains($0) }
        )
    }

    private static func exposure(
        for surface: SurfacePage,
        ledger: CausalCurationLedger,
        now: Date
    ) -> CuratorObservatoryExposure {
        let intention = BookSessionIntention.read(from: surface)
        let receipt = CausalCurationReceipt.read(from: surface)
        let outcomes = receipt.map { receipt in
            ledger.outcomes
                .filter { $0.opportunityID == receipt.id }
                .sorted { $0.occurredAt < $1.occurredAt }
        } ?? []
        let qualified = outcomes.filter(\.kind.isQualified)
        let interactions = outcomes.filter { !$0.kind.isQualified }
        let hasCounter = qualified.contains(where: isCounterEvidence)
        let hasSupport = qualified.contains { !isCounterEvidence($0) && $0.value > 0 }
        let state: CuratorObservatoryOutcomeState
        if receipt == nil {
            state = .notCausal
        } else if hasCounter && hasSupport {
            state = .mixed
        } else if hasCounter {
            state = .counterEvidence
        } else if hasSupport {
            state = .livedSupport
        } else if !interactions.isEmpty {
            state = .interactionOnly
        } else {
            state = .awaitingEvidence
        }
        let contract = surface.livedEncounterContract
        return CuratorObservatoryExposure(
            surfaceID: surface.id,
            sourceID: surface.sourceID,
            type: surface.type,
            movement: intention?.movement,
            role: surface.preparedExperimentRole,
            actIndex: surface.preparedExperimentActIndex,
            branch: surface.preparedExperimentBranch,
            encounterMode: contract.mode,
            mayMintLivedReceipt: contract.mayMintLivedReceipt,
            capabilitySignature: surface.pageCapabilities.signature,
            causalOpportunityID: receipt?.id,
            assignmentPropensity: receipt?.propensity,
            alternativeCount: receipt?.candidates.count ?? 0,
            outcomeState: state,
            qualifiedOutcomeCount: qualified.count,
            interactionOnlyCount: interactions.count,
            latestOutcomeKind: outcomes.last?.kind,
            latestOutcomeValue: outcomes.last?.value,
            causalEffect: receipt.map {
                effect(
                    movement: $0.movement,
                    role: $0.role,
                    sourceID: $0.chosenSourceID,
                    contextKey: $0.contextKey,
                    ledger: ledger,
                    now: now
                )
            }
        )
    }

    private static func effect(
        movement: BookReenchantmentMovement,
        role: BookSessionRole,
        sourceID: String,
        contextKey: String,
        ledger: CausalCurationLedger,
        now: Date
    ) -> CuratorObservatoryCausalEffect {
        let estimate = ledger.estimate(
            movement: movement,
            role: role,
            sourceID: sourceID,
            contextKey: contextKey,
            now: now
        )
        return CuratorObservatoryCausalEffect(
            treatmentCount: estimate.treatmentCount,
            controlCount: estimate.controlCount,
            estimatedUplift: estimate.estimatedUplift,
            conservativeLowerBound: estimate.conservativeLowerBound,
            conservativeUpperBound: estimate.conservativeUpperBound,
            usedExactContext: estimate.usedExactContext,
            appliedMultiplier: ledger.multiplier(
                movement: movement,
                role: role,
                sourceID: sourceID,
                contextKey: contextKey,
                now: now
            ),
            effectiveTreatmentSamples: estimate.effectiveTreatmentSamples,
            effectiveControlSamples: estimate.effectiveControlSamples
        )
    }

    private static func movementEffect(
        for intention: BookSessionIntention,
        ledger: CausalCurationLedger,
        now: Date
    ) -> CuratorObservatoryCausalEffect? {
        guard let receipt = intention.causalMovementReceipt else { return nil }
        let estimate = ledger.movementEstimate(
            movement: receipt.chosenMovement,
            contextKey: receipt.contextKey,
            now: now
        )
        return CuratorObservatoryCausalEffect(
            treatmentCount: estimate.treatmentCount,
            controlCount: estimate.controlCount,
            estimatedUplift: estimate.estimatedUplift,
            conservativeLowerBound: estimate.conservativeLowerBound,
            conservativeUpperBound: estimate.conservativeUpperBound,
            usedExactContext: estimate.usedExactContext,
            appliedMultiplier: ledger.movementMultiplier(
                movement: receipt.chosenMovement,
                contextKey: receipt.contextKey,
                now: now
            ),
            effectiveTreatmentSamples: estimate.effectiveTreatmentSamples,
            effectiveControlSamples: estimate.effectiveControlSamples
        )
    }

    private static func isCounterEvidence(_ outcome: CausalCurationOutcome) -> Bool {
        outcome.kind == .declined
            || outcome.kind == .contradicted
            || outcome.value <= 0
    }
}

// MARK: - Earned readings

enum BookObservationLedger {
    static func key(for surface: SurfacePage) -> String? {
        let metadata = surface.payload.metadata
        if let explicit = metadata["observationKey"]?.nonEmpty { return explicit }
        if let id = metadata["connectionID"]?.nonEmpty { return "connection:\(id)" }
        if metadata["howYouSee"] == "true" { return "how-you-see" }
        if let id = metadata["personSlug"]?.nonEmpty {
            if metadata["personQuietDays"] != nil { return "person-return:\(id):\(metadata["personQuietDays"] ?? "0")" }
            return "person:\(id)"
        }
        if let pageID = metadata["rememberedPageID"]?.nonEmpty {
            let reason = metadata["rhymeReason"]?.nonEmpty ?? surface.reason
            return "remembered:\(pageID):\(abs(reason.stableHash))"
        }
        if let id = metadata["strongestSignalID"]?.nonEmpty { return "notice:\(id)" }
        return nil
    }

    static func kind(for surface: SurfacePage) -> String {
        let metadata = surface.payload.metadata
        if surface.type == .bookRemembered { return "remembered" }
        if metadata["howYouSee"] == "true" { return "how-you-see" }
        if let kind = metadata["connectionKind"]?.nonEmpty { return kind }
        if metadata["personSlug"] != nil { return "person" }
        return "notice"
    }

    static func evidencePageIDs(for surface: SurfacePage) -> [String] {
        surface.payload.metadata["evidencePageIDs"]?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    static func allows(
        _ surface: SurfacePage,
        observations: [BookObservationRecord],
        boundaries: [BookReadingBoundary]
    ) -> Bool {
        guard let key = key(for: surface) else { return true }
        if boundaries.contains(where: { $0.id == key }) { return false }
        return !observations.contains(where: { $0.id == key })
    }

    static func recording(
        surface: SurfacePage,
        status: BookObservationStatus,
        in records: [BookObservationRecord],
        now: Date = Date()
    ) -> [BookObservationRecord] {
        guard let key = key(for: surface) else { return records }
        var updated = records
        if let index = updated.firstIndex(where: { $0.id == key }) {
            updated[index].status = status
            updated[index].updatedAt = now
        } else {
            updated.append(BookObservationRecord(
                id: key,
                kind: kind(for: surface),
                status: status,
                evidencePageIDs: evidencePageIDs(for: surface),
                firstPresentedAt: now,
                updatedAt: now
            ))
        }
        return Array(updated.sorted { $0.updatedAt < $1.updatedAt }.suffix(200))
    }
}

extension MagicMomentGovernor {
    /// Promotes one evidence-backed reading into a protected desk milestone.
    /// The evidence quality supplies most of the weight; a stable per-session
    /// jitter changes which good candidate wins when several are ready.
    static func promotingEarnedReveal(
        in candidates: [SurfacePage],
        state: MagicMomentState
    ) -> [SurfacePage] {
        guard state.isArmed,
              !candidates.contains(where: { $0.payload.metadata["firstReading"] == "true" }) else {
            return candidates
        }
        let eligible = candidates.filter { page in
            guard page.payload.metadata["firstReading"] != "true" else { return false }
            return page.payload.metadata["magicMomentEligible"] == "true"
                || page.type == .bookRemembered
                || page.payload.metadata["connectionNarrative"] == "true"
                || page.payload.metadata["howYouSee"] == "true"
        }
        guard let selected = eligible.max(by: { revealValue($0, state: state) < revealValue($1, state: state) }) else {
            return candidates
        }
        let promoted = selected.promotedMagicMoment()
        return candidates.map { $0.id == selected.id ? promoted : $0 }
    }

    private static func revealValue(_ page: SurfacePage, state: MagicMomentState) -> Int {
        let metadata = page.payload.metadata
        let base: Int
        if metadata["howYouSee"] == "true" { base = 100 }
        else if metadata["connectionKind"] == "semantic" { base = 98 }
        else if metadata["connectionKind"] == "recurrence" { base = 94 }
        else if metadata["connectionKind"] == "context" { base = 92 }
        else if page.type == .bookRemembered { base = 86 }
        else if metadata["personQuietDays"] != nil { base = 82 }
        else { base = 76 }
        let key = BookObservationLedger.key(for: page) ?? page.id
        let jitter = abs("magic:\(state.sessionCount):\(key)".stableHash) % 25
        return base + jitter
    }
}

private extension SurfacePage {
    func promotedMagicMoment() -> SurfacePage {
        var metadata = payload.metadata
        metadata["magicMoment"] = "true"
        metadata["milestone"] = "true"
        if metadata["observationKey"] == nil {
            metadata["observationKey"] = BookObservationLedger.key(for: self)
        }
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: max(94, score),
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(headline: payload.headline, body: payload.body, metadata: metadata)
        )
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

enum ReaderLearningAction: String, Codable, Equatable {
    case surfaced
    case opened
    case acted
    case recognized
    case broughtFromElsewhere
    case followedThread
    case keepsakeEarned
    case kept
    case dismissed
    case loved
    case missed
}

struct ReaderLearningEvent: Identifiable, Codable, Equatable {
    /// An interaction recorded only so the private momentum ledger can see
    /// completion of the universal Keep gesture. It must not teach taste or
    /// resolve a causal/aliveness experiment as a distinct native action.
    static let momentumOnlyTag = "reader-learning-scope:momentum-only"
    /// A Page-local refusal. The event may remain in the bounded interaction
    /// log so the Page can still function, but no adaptive system may learn
    /// taste, timing, momentum, aliveness, or causal uplift from it.
    static let curationLearningForbiddenTag = "curation-learning-forbidden"

    var id: String
    var dayID: String
    var occurredAt: Date
    var action: ReaderLearningAction
    var surfaceID: String
    var sourceID: String
    var type: BookPageType
    var varietyKey: String
    /// Identity of the exact readable Page, not merely its family or recipe.
    /// Optional so every existing on-device learning ledger still decodes.
    var contentKey: String? = nil
    var hour: Int
    var tags: [String]
    var evidence: String?
    /// Coarse context captured at the interaction itself. This lets the Book
    /// compare what the reader actually opened or chose with weather, hour,
    /// place, and reader-named inner weather later. Older ledgers decode with
    /// no snapshot, and coordinates/calendar titles are never stored here.
    var context: BookPageContextSnapshot?
    /// Present only for ordinary randomized Curator choices. It records the
    /// eligible alternatives and selection propensity needed to distinguish
    /// causal uplift from the Book merely repeating its own preferences.
    var causalReceipt: CausalCurationReceipt?
    /// Session-level randomized movement choice. Kept separately from the
    /// Page receipt so a protected or deterministic Page can still report the
    /// outcome of an otherwise ordinary movement experiment.
    var causalMovementReceipt: CausalMovementReceipt?

    var isMomentumOnly: Bool {
        tags.contains(Self.momentumOnlyTag)
    }

    var allowsCurationLearning: Bool {
        !tags.contains(Self.curationLearningForbiddenTag)
    }

    init(
        id: String = UUID().uuidString,
        dayID: String,
        occurredAt: Date = Date(),
        action: ReaderLearningAction,
        surfaceID: String,
        sourceID: String,
        type: BookPageType,
        varietyKey: String,
        contentKey: String? = nil,
        hour: Int,
        tags: [String] = [],
        evidence: String? = nil,
        context: BookPageContextSnapshot? = nil,
        causalReceipt: CausalCurationReceipt? = nil,
        causalMovementReceipt: CausalMovementReceipt? = nil
    ) {
        self.id = id
        self.dayID = dayID
        self.occurredAt = occurredAt
        self.action = action
        self.surfaceID = surfaceID
        self.sourceID = sourceID
        self.type = type
        self.varietyKey = varietyKey
        self.contentKey = contentKey
        self.hour = max(0, min(23, hour))
        self.tags = Array(Set(tags.map(\.readerLearningNormalizedTag).filter { !$0.isEmpty })).sorted()
        self.evidence = evidence?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty.map {
            String($0.prefix(160))
        }
        self.context = context
        self.causalReceipt = causalReceipt
        self.causalMovementReceipt = causalMovementReceipt
    }
}

struct ReaderLearningAffinity: Codable, Equatable {
    var surfaced: Int = 0
    var kept: Int = 0
    var dismissed: Int = 0
    var loved: Int = 0
    var missed: Int = 0
    /// A Page's own native action was taken: a choice made, a ritual run, a
    /// game played. Real participation, but still inside the Book.
    var acted: Int = 0
    /// Something the reader selected from outside the Book's candidate set.
    /// Strong taste evidence, but not yet proof that ordinary life changed.
    var broughtFromElsewhere: Int = 0
    /// The reader came back to this later of their own accord. A crossing:
    /// the Page reached past the session it was shown in.
    var followedThread: Int = 0
    /// Something from the reader's actual life got pressed into the Book
    /// because of this Page. The strongest evidence the Book can hold.
    var keepsakeEarned: Int = 0
    var lastUpdatedAt: Date?

    /// Recency-weighted running totals, faded toward the reader's latest answer
    /// each time this family is touched. The integer counters above are the
    /// reader's whole history and stay that way: they answer "what happened" for
    /// metrics and receipts. These answer the different question the desk needs:
    /// what does the reader seem to want *now*.
    private var fadedTaste: Double = 0
    private var fadedCrossing: Double = 0
    private var fadedSignals: Double = 0

    /// What each kind of answer is worth to taste. Referenced by both the
    /// lifetime `rawScore` and the faded accumulator, so the two can never drift
    /// into disagreeing about what a keepsake is worth.
    private enum Weight {
        static let keepsakeEarned = 10
        static let followedThread = 8
        static let loved = 6
        static let broughtFromElsewhere = 5
        static let kept = 3
        static let acted = 2
        static let dismissed = -3
        static let missed = -5

        static let keepsakeCrossing = 3
        static let followedThreadCrossing = 2
    }

    /// How quickly taste goes quiet, measured in the reader's own answering
    /// time rather than the calendar.
    ///
    /// Wall-clock decay would punish absence: a reader coming back after six
    /// months would find every preference they had taught the Book faded, having
    /// done nothing but live. The Book already holds that time away must not
    /// count against a reader, and taste follows the same rule: staleness here
    /// means "many answers ago", never "long ago". A preference last confirmed
    /// four months of active reading back argues half as hard as a fresh one, and
    /// past a year of it barely argues at all, which is roughly where the causal
    /// layer stops listening too.
    static let tasteHalfLifeDays = 120.0

    /// Signals the taste model is willing to learn from. Crossings count here
    /// as well as appraisals: going outside is a stronger statement about
    /// what a reader wants than tapping a heart is.
    var meaningfulSignals: Int {
        kept + dismissed + loved + missed + acted + broughtFromElsewhere + followedThread + keepsakeEarned
    }

    /// The Book's day-to-day taste gradient.
    ///
    /// This deliberately reproduces the ordering the causal layer already
    /// uses when it scores lived outcomes (`CausalCurationLedger`: keepsake
    /// 0.75 > later return 0.65 > loved 0.45 > kept 0.12 > acted 0.08). Those
    /// two layers used to contradict each other in writing: the causal layer
    /// noting that a lived receipt "must outrank" a love, while this one
    /// discarded every crossing signal and made a tapped heart the single
    /// strongest thing a Page could earn. A Page that sent the reader out the
    /// door and brought them back with something was worth exactly zero here.
    var rawScore: Int {
        keepsakeEarned * Weight.keepsakeEarned
            + followedThread * Weight.followedThread
            + loved * Weight.loved
            + broughtFromElsewhere * Weight.broughtFromElsewhere
            + kept * Weight.kept
            + acted * Weight.acted
            + dismissed * Weight.dismissed
            + missed * Weight.missed
    }

    mutating func record(_ event: ReaderLearningEvent) {
        fade(to: event.occurredAt)
        switch event.action {
        case .surfaced:
            surfaced += 1
        case .opened, .recognized:
            // Being shown a Page and glancing at it says nothing about whether
            // it was worth showing.
            break
        case .acted:
            acted += 1
            accumulate(taste: Weight.acted)
        case .broughtFromElsewhere:
            if event.tags.contains("prompted-capture") {
                // Still a real choice, but the Book supplied the occasion.
                kept += 1
                accumulate(taste: Weight.kept)
            } else {
                broughtFromElsewhere += 1
                accumulate(taste: Weight.broughtFromElsewhere)
            }
        case .followedThread:
            followedThread += 1
            accumulate(taste: Weight.followedThread, crossing: Weight.followedThreadCrossing)
        case .keepsakeEarned:
            keepsakeEarned += 1
            accumulate(taste: Weight.keepsakeEarned, crossing: Weight.keepsakeCrossing)
        case .kept:
            kept += 1
            accumulate(taste: Weight.kept)
        case .dismissed:
            dismissed += 1
            accumulate(taste: Weight.dismissed)
        case .loved:
            loved += 1
            accumulate(taste: Weight.loved)
        case .missed:
            missed += 1
            accumulate(taste: Weight.missed)
        }
        lastUpdatedAt = event.occurredAt
    }

    private mutating func accumulate(taste: Int, crossing: Int = 0) {
        fadedTaste += Double(taste)
        fadedCrossing += Double(crossing)
        fadedSignals += 1
    }

    /// Carry the accumulators forward to a new moment in the reader's answering
    /// time. Everything already banked gets quieter; nothing is discarded.
    private mutating func fade(to moment: Date) {
        let factor = Self.fadeFactor(from: lastUpdatedAt, to: moment)
        guard factor < 1 else { return }
        fadedTaste *= factor
        fadedCrossing *= factor
        fadedSignals *= factor
    }

    private static func fadeFactor(from: Date?, to: Date) -> Double {
        guard let from else { return 1 }
        let days = to.timeIntervalSince(from) / 86_400
        guard days > 0 else { return 1 }
        return pow(0.5, days / tasteHalfLifeDays)
    }

    /// The three faded totals as of `reference`: normally the reader's most
    /// recent answer anywhere in the Book, so a family that has gone quiet while
    /// others kept earning answers argues progressively less. Passing nil reads
    /// them as of this family's own last answer, with no further fading.
    private func faded(at reference: Date?) -> (taste: Double, crossing: Double, signals: Double) {
        let factor = reference.map { Self.fadeFactor(from: lastUpdatedAt, to: $0) } ?? 1
        return (fadedTaste * factor, fadedCrossing * factor, fadedSignals * factor)
    }

    /// Positive signals that crossed beyond the session rather than merely
    /// happening inside the Book. Reported separately so the Book can tell
    /// "they participated here" from "this survived into their life."
    var crossingSignals: Int {
        followedThread + keepsakeEarned
    }

    /// Crossing evidence on its own scale, weighted the same way `rawScore`
    /// weights it. Used for the curation budget that only real-life evidence
    /// can spend.
    var crossingScore: Int {
        keepsakeEarned * Weight.keepsakeCrossing + followedThread * Weight.followedThreadCrossing
    }

    /// Crossing evidence as it stands now rather than as it ever stood. A walk
    /// the reader took because of this family last spring is real and stays in
    /// `crossingScore`; it should not go on buying desk space forever.
    func crossingScore(asOf reference: Date?) -> Int {
        Int(faded(at: reference).crossing.rounded())
    }

    func curationAdjustment(scale: Int, maximum: Int, asOf reference: Date? = nil) -> Int {
        let faded = faded(at: reference)
        guard faded.signals > 0 else { return 0 }
        let confidence = min(Double(scale), faded.signals)
        let weighted = faded.taste * confidence / Double(scale)
        return max(-maximum, min(maximum, Int(weighted.rounded())))
    }

    /// Confidence the desk still has in this family, in faded answers. Used
    /// where exploration should reopen once a settled question has gone stale.
    func settledSignals(asOf reference: Date?) -> Double {
        faded(at: reference).signals
    }

    init() {}

    /// Hand-written so ledgers saved before crossings were counted decode with
    /// zeros instead of failing. (Synthesized `Decodable` ignores property
    /// defaults and demands every key.) `ReaderLearningModel` then replays its
    /// retained events to fill those zeros in.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surfaced = try container.decodeIfPresent(Int.self, forKey: .surfaced) ?? 0
        kept = try container.decodeIfPresent(Int.self, forKey: .kept) ?? 0
        dismissed = try container.decodeIfPresent(Int.self, forKey: .dismissed) ?? 0
        loved = try container.decodeIfPresent(Int.self, forKey: .loved) ?? 0
        missed = try container.decodeIfPresent(Int.self, forKey: .missed) ?? 0
        acted = try container.decodeIfPresent(Int.self, forKey: .acted) ?? 0
        broughtFromElsewhere = try container.decodeIfPresent(Int.self, forKey: .broughtFromElsewhere) ?? 0
        followedThread = try container.decodeIfPresent(Int.self, forKey: .followedThread) ?? 0
        keepsakeEarned = try container.decodeIfPresent(Int.self, forKey: .keepsakeEarned) ?? 0
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        fadedTaste = try container.decodeIfPresent(Double.self, forKey: .fadedTaste) ?? 0
        fadedCrossing = try container.decodeIfPresent(Double.self, forKey: .fadedCrossing) ?? 0
        fadedSignals = try container.decodeIfPresent(Double.self, forKey: .fadedSignals) ?? 0
    }
}

struct ReaderLearningDailyDigest: Codable, Equatable {
    var dayID: String
    var learnedAt: Date
    var eventCount: Int
    var strongestType: BookPageType?
    var strongestTag: String?
    var coolingType: BookPageType?
}

enum ReaderLearningInsightKind: String, Codable, Equatable {
    case warmingType
    case coolingType
    case warmingTag
    case timeWindow
    case compounding
}

struct ReaderLearningInsight: Identifiable, Codable, Equatable {
    var id: String
    var kind: ReaderLearningInsightKind
    var line: String
    var evidence: String
    var strength: Int
}

struct ReaderLearningMetrics: Codable, Equatable {
    var tenureDays: Int
    var eventCount: Int
    var meaningfulEventCount: Int
    var kept: Int
    var dismissed: Int
    var loved: Int
    var missed: Int
    var learnedSurfaceCount: Int
    var activeDigestCount: Int

    var positiveRatePercent: Int {
        let total = kept + dismissed + loved + missed
        guard total > 0 else { return 0 }
        return Int(((Double(kept + loved) / Double(total)) * 100).rounded())
    }
}

/// Private, on-device measures of whether Pages become meaningful quickly.
/// These deliberately omit session duration: success is a completed act of
/// attention, not keeping the reader inside the app.
struct ReaderMomentumMetrics: Equatable {
    var opened: Int
    var acted: Int
    var recognized: Int
    var followedThreads: Int
    var keepsakesEarned: Int
    var actionsWithinThirtySeconds: Int
    var medianOpenToActionSeconds: Double?
    /// Captures the reader made without the Book having just put a desk in
    /// front of them.
    var unpromptedCaptures: Int = 0
    /// Captures made in the wake of a freshly surfaced desk.
    var promptedCaptures: Int = 0

    var openToActionRatePercent: Int {
        guard opened > 0 else { return 0 }
        return Int((Double(actionsWithinThirtySeconds) / Double(opened) * 100).rounded())
    }

    /// One leading indicator of transfer into ordinary life, never the Book's
    /// north star by itself. The long-term `ReaderReenchantmentMeasure` must
    /// read this alongside direct state, lived proof, longitudinal change,
    /// counter-signals, and attributable outcomes.
    var unpromptedCaptureRatePercent: Int {
        let total = unpromptedCaptures + promptedCaptures
        guard total > 0 else { return 0 }
        return Int((Double(unpromptedCaptures) / Double(total) * 100).rounded())
    }
}

struct ReaderLearningModel: Codable, Equatable {
    /// 6: Page-local curation refusals became a central model boundary, and
    /// in-Book actions stopped buying the crossing-only score premium.
    /// 7: Taste fades with the reader's answering time instead of standing
    /// forever, and the tables became derived from the retained log rather than a
    /// parallel history that outlived it.
    static let currentVersion = 7
    static let maxEvents = 800

    var version: Int = ReaderLearningModel.currentVersion
    var events: [ReaderLearningEvent] = []
    var sourceAffinities: [String: ReaderLearningAffinity] = [:]
    var typeAffinities: [BookPageType: ReaderLearningAffinity] = [:]
    var tagAffinities: [String: ReaderLearningAffinity] = [:]
    /// Exact-page learning sits below type/source learning. Optional preserves
    /// backward decoding; it is materialized on the first new interaction.
    var contentAffinities: [String: ReaderLearningAffinity]? = nil
    var dailyDigests: [ReaderLearningDailyDigest] = []
    var lastUpdatedAt: Date?

    init() {}

    /// Self-healing decode. A ledger written before crossings were scored is
    /// rebuilt from its own event log on the way in, so every read path gets a
    /// migrated model without each of them having to know about it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        events = try container.decodeIfPresent([ReaderLearningEvent].self, forKey: .events) ?? []
        sourceAffinities = try container.decodeIfPresent([String: ReaderLearningAffinity].self, forKey: .sourceAffinities) ?? [:]
        typeAffinities = try container.decodeIfPresent([BookPageType: ReaderLearningAffinity].self, forKey: .typeAffinities) ?? [:]
        tagAffinities = try container.decodeIfPresent([String: ReaderLearningAffinity].self, forKey: .tagAffinities) ?? [:]
        contentAffinities = try container.decodeIfPresent([String: ReaderLearningAffinity].self, forKey: .contentAffinities)
        dailyDigests = try container.decodeIfPresent([ReaderLearningDailyDigest].self, forKey: .dailyDigests) ?? []
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)

        if version < Self.currentVersion {
            rebuildAffinitiesFromEvents()
            version = Self.currentVersion
        }
    }

    mutating func record(_ event: ReaderLearningEvent) {
        events.append(event)
        if events.count > Self.maxEvents {
            events = Array(events.suffix(Self.maxEvents))
        }

        apply(event)
        lastUpdatedAt = event.occurredAt
        rebuildDailyDigest(for: event.dayID)
    }

    /// Fold one event into the affinity tables without touching the event log,
    /// so a migration can replay history through exactly the same path a live
    /// interaction takes.
    private mutating func apply(_ event: ReaderLearningEvent) {
        guard !event.isMomentumOnly, event.allowsCurationLearning else { return }
        sourceAffinities[event.sourceID, default: ReaderLearningAffinity()].record(event)
        typeAffinities[event.type, default: ReaderLearningAffinity()].record(event)
        let contentKey = event.contentKey ?? event.varietyKey
        var exact = contentAffinities ?? [:]
        exact[contentKey, default: ReaderLearningAffinity()].record(event)
        contentAffinities = exact
        for tag in event.tags.prefix(8) {
            tagAffinities[tag, default: ReaderLearningAffinity()].record(event)
        }
    }

    /// Discard the affinity tables and rebuild them from the retained event
    /// log. Used when the scoring rules change under an existing Book: the
    /// counters a older ledger never kept are recovered rather than left at
    /// zero. Fidelity is bounded by `maxEvents`: crossings older than the
    /// retained window are gone, and the Book relearns them from here.
    mutating func rebuildAffinitiesFromEvents() {
        sourceAffinities = [:]
        typeAffinities = [:]
        tagAffinities = [:]
        contentAffinities = [:]
        for event in events {
            apply(event)
        }
        lastUpdatedAt = events.last?.occurredAt ?? lastUpdatedAt
    }

    /// The moment every faded total is read against: the reader's most recent
    /// answer anywhere in the Book. A family that has gone quiet while the reader
    /// kept answering elsewhere argues progressively less, while a reader who has
    /// simply been away loses nothing: their last session is still the present
    /// as far as taste is concerned.
    private var tasteReference: Date? {
        lastUpdatedAt ?? events.last?.occurredAt
    }

    func scoreAdjustment(for page: SurfacePage) -> Int {
        let asOf = tasteReference
        let source = sourceAffinities[page.sourceID]?.curationAdjustment(scale: 4, maximum: 10, asOf: asOf) ?? 0
        let type = typeAffinities[page.type]?.curationAdjustment(scale: 5, maximum: 12, asOf: asOf) ?? 0
        let content = contentAffinities?[page.curatorContentNoveltyKey]?
            .curationAdjustment(scale: 5, maximum: 10, asOf: asOf) ?? 0
        let tag = page.readerLearningTags
            .compactMap { tagAffinities[$0]?.curationAdjustment(scale: 4, maximum: 4, asOf: asOf) }
            .sorted(by: >)
            .prefix(3)
            .reduce(0, +)
        // Shared family learning establishes the broad lane; exact-page
        // learning remains visible above that common baseline so two Pages in
        // the same source/type can still separate. Neither layer may overpower
        // discovery.
        let family = max(-8, min(8, source + type + tag))
        let taste = max(-12, min(12, family + content))
        return max(-12, min(Self.maximumAdjustment, taste + crossingAdjustment(for: page)))
    }

    /// The ceiling on `scoreAdjustment`. The six points above the taste cap of
    /// 12 are reachable only through `crossingAdjustment`: nothing a reader
    /// does inside the Book can buy them.
    static let maximumAdjustment = 18

    /// How strongly the reader's own history argues for a story recipe and the
    /// lane it belongs to.
    ///
    /// The Curator has always made the final pick between the four recipe
    /// variants a Story Page arrives as, but the engine that *builds* those
    /// four never heard what the Curator learned: it narrowed ~35 recipes
    /// using consequence-derived boosts alone. So a recipe the reader reliably
    /// kept, and walked out into their life after, could not improve its odds
    /// of being offered at all. This is the missing return path.
    ///
    /// The recipe is the more specific claim and outweighs its lane.
    ///
    /// As on the desk, the taste terms saturate quickly: four signals is
    /// enough to peg both, so a crossing and a tapped heart would otherwise
    /// end up arguing equally hard. The points above `storyTasteCeiling` are
    /// therefore reachable only through crossings: no amount of admiring a
    /// recipe inside the Book makes it as likely to be offered as one the
    /// reader walked out of the house after.
    static let storyTasteCeiling = 10
    static let storyCrossingHeadroom = 4
    static let storyAffinityCeiling = storyTasteCeiling + storyCrossingHeadroom

    func storyRecipeAffinity(recipeID: String, lane: String) -> Int {
        let asOf = tasteReference
        let recipe = tagAffinities["recipe:\(recipeID)".readerLearningNormalizedTag]
        let laneTag = tagAffinities["lane:\(lane)".readerLearningNormalizedTag]
        let taste = max(-Self.storyTasteCeiling, min(
            Self.storyTasteCeiling,
            (recipe?.curationAdjustment(scale: 4, maximum: 8, asOf: asOf) ?? 0)
                + (laneTag?.curationAdjustment(scale: 5, maximum: 5, asOf: asOf) ?? 0)
        ))
        let crossings = (recipe?.crossingScore(asOf: asOf) ?? 0) + (laneTag?.crossingScore(asOf: asOf) ?? 0)
        let crossing = min(Self.storyCrossingHeadroom, (crossings + 2) / 4)
        return max(-12, min(Self.storyAffinityCeiling, taste + crossing))
    }

    /// How much room exploration should still have for a given recipe.
    ///
    /// A flat jitter treats a recipe the Book has watched the reader answer
    /// twenty times exactly like one it has never shown. Exploration is only
    /// worth its noise while the Book is still ignorant, so the width closes
    /// as real signals accumulate: the Book stops rolling dice about a
    /// question its reader has already answered.
    /// Read against faded signals, so a question the reader answered twenty times
    /// two hundred answers ago reopens rather than staying closed on the strength
    /// of a conversation neither party remembers.
    func storyExplorationWidth(recipeID: String, fullWidth: Int = 5) -> Int {
        let signals = Int(
            (tagAffinities["recipe:\(recipeID)".readerLearningNormalizedTag]?
                .settledSignals(asOf: tasteReference) ?? 0).rounded()
        )
        guard signals > 0 else { return fullWidth }
        return max(1, fullWidth - min(fullWidth - 1, signals))
    }

    /// A curation budget that only real-life evidence can spend.
    ///
    /// The taste caps saturate quickly: two loves is enough to peg a family
    /// at the ceiling, so raising the weight of crossings inside `rawScore`
    /// alone would get flattened before it reached the desk: a family the
    /// reader physically went outside for would rank identically to one they
    /// merely enjoyed looking at. This term sits outside that clamp so the
    /// distinction survives all the way to the desk.
    private func crossingAdjustment(for page: SurfacePage) -> Int {
        let asOf = tasteReference
        let family = (sourceAffinities[page.sourceID]?.crossingScore(asOf: asOf) ?? 0)
            + (typeAffinities[page.type]?.crossingScore(asOf: asOf) ?? 0)
        let familyPoints = min(6, (family + 1) / 2)
        // Whole families share a source and a type: every Story Page does,
        // whichever of the four recipe variants it is, so a family-level
        // score cannot tell one variant from another, and being shared it
        // saturates, hiding the differences underneath it. Where the reader
        // has history with a page's own tags, those decide instead. A recorded
        // tag with no crossings is real evidence too: it says this particular
        // lane or recipe is admired rather than acted on.
        let recordedTagScores = page.readerLearningTags
            .compactMap { tagAffinities[$0]?.crossingScore(asOf: asOf) }
        guard let bestTag = recordedTagScores.max() else { return familyPoints }
        return min(6, (bestTag + 1) / 2)
    }

    func metrics(days: [BookDay] = [], now: Date = Date(), calendar: Calendar = .current) -> ReaderLearningMetrics {
        let learningEvents = events.filter(\.allowsCurationLearning)
        let firstEventAt = learningEvents.map(\.occurredAt).min()
        let firstPageAt = days.flatMap(\.pages).map(\.createdAt).min()
        let firstTouch = [firstEventAt, firstPageAt].compactMap { $0 }.min()
        let tenureDays = firstTouch.map { max(1, calendar.dateComponents([.day], from: $0, to: now).day ?? 0) } ?? 0
        let totals = learningEvents.reduce(into: [ReaderLearningAction: Int]()) { counts, event in
            counts[event.action, default: 0] += 1
        }
        return ReaderLearningMetrics(
            tenureDays: tenureDays,
            eventCount: learningEvents.count,
            meaningfulEventCount: learningEvents.filter {
                switch $0.action {
                case .acted, .broughtFromElsewhere, .followedThread, .keepsakeEarned, .kept, .dismissed, .loved, .missed:
                    return true
                case .surfaced, .opened, .recognized:
                    return false
                }
            }.count,
            kept: totals[.kept] ?? 0,
            dismissed: totals[.dismissed] ?? 0,
            loved: totals[.loved] ?? 0,
            missed: totals[.missed] ?? 0,
            learnedSurfaceCount: sourceAffinities.values.filter { $0.meaningfulSignals > 0 }.count,
            activeDigestCount: dailyDigests.count
        )
    }

    func momentumMetrics() -> ReaderMomentumMetrics {
        let learningEvents = events.filter(\.allowsCurationLearning)
        let openedEvents = learningEvents.filter { $0.action == .opened }
        let actedEvents = learningEvents.filter { $0.action == .acted }
        let recognized = learningEvents.filter { $0.action == .recognized }.count
        let followed = learningEvents.filter { $0.action == .followedThread }.count
        let keepsakes = learningEvents.filter { $0.action == .keepsakeEarned }.count
        var responseTimes: [TimeInterval] = []

        for opened in openedEvents {
            guard let acted = actedEvents.first(where: {
                $0.surfaceID == opened.surfaceID && $0.occurredAt >= opened.occurredAt
            }) else { continue }
            responseTimes.append(acted.occurredAt.timeIntervalSince(opened.occurredAt))
        }
        responseTimes.sort()
        let median: Double?
        if responseTimes.isEmpty {
            median = nil
        } else if responseTimes.count.isMultiple(of: 2) {
            let upper = responseTimes.count / 2
            median = (responseTimes[upper - 1] + responseTimes[upper]) / 2
        } else {
            median = responseTimes[responseTimes.count / 2]
        }

        let surfacedEvents = learningEvents.filter { $0.action == .surfaced }
        var unprompted = 0
        var prompted = 0
        for capture in learningEvents where
            capture.action == .kept
                || capture.action == .keepsakeEarned
                || capture.action == .broughtFromElsewhere {
            let wasPrompted: Bool
            if capture.tags.contains("unprompted-capture") {
                wasPrompted = false
            } else if capture.tags.contains("prompted-capture") {
                wasPrompted = true
            } else if capture.action == .broughtFromElsewhere {
                // The extension has the honest prompt receipt; unrelated app
                // openings must not launder an outside discovery into a reply.
                wasPrompted = false
            } else {
                wasPrompted = surfacedEvents.contains { surfaced in
                    let sameThread = surfaced.surfaceID == capture.surfaceID
                        || (
                            surfaced.contentKey?.nonEmpty != nil
                                && surfaced.contentKey?.nonEmpty == capture.contentKey?.nonEmpty
                        )
                    return sameThread
                        && surfaced.occurredAt <= capture.occurredAt
                        && capture.occurredAt.timeIntervalSince(surfaced.occurredAt) <= Self.unpromptedCaptureWindow
                }
            }
            if wasPrompted { prompted += 1 } else { unprompted += 1 }
        }

        return ReaderMomentumMetrics(
            opened: openedEvents.count,
            acted: actedEvents.count,
            recognized: recognized,
            followedThreads: followed,
            keepsakesEarned: keepsakes,
            actionsWithinThirtySeconds: responseTimes.filter { $0 <= 30 }.count,
            medianOpenToActionSeconds: median,
            unpromptedCaptures: unprompted,
            promptedCaptures: prompted
        )
    }

    /// How long after the Book lays out a desk a capture still counts as
    /// answering that desk rather than arriving on the reader's own initiative.
    static let unpromptedCaptureWindow: TimeInterval = 3600

    /// Native Page interactions can record an `.acted` event without reviving
    /// the removed generic capture box. A Keep is the universal native action;
    /// this gate prevents it from double-counting Pages whose game, choice, or
    /// ritual already recorded an action after opening.
    func needsNativeAction(for surfaceID: String) -> Bool {
        guard let openIndex = events.lastIndex(where: {
            $0.surfaceID == surfaceID && $0.action == .opened
        }) else {
            return false
        }
        return !events[events.index(after: openIndex)...].contains {
            $0.surfaceID == surfaceID && $0.action == .acted
        }
    }

    /// Returns the earlier deliberate encounter that makes today's opening a
    /// genuine return. Mere serving does not begin a thread, and one thread can
    /// earn at most one return receipt per local day.
    func followedThreadOrigin(
        surfaceID: String,
        contentKey: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> ReaderLearningEvent? {
        let todayID = BookDay.id(for: now, calendar: calendar)
        let prior = events.filter { event in
            guard event.occurredAt < now,
                  !calendar.isDate(event.occurredAt, inSameDayAs: now) else {
                return false
            }
            let sameThread = event.surfaceID == surfaceID
                || (
                    contentKey?.nonEmpty != nil
                        && event.contentKey?.nonEmpty == contentKey?.nonEmpty
                )
            guard sameThread else { return false }
            switch event.action {
            case .opened, .acted, .recognized, .broughtFromElsewhere,
                    .followedThread, .keepsakeEarned, .kept, .loved:
                return true
            case .surfaced, .dismissed, .missed:
                return false
            }
        }
        guard let origin = prior.max(by: { $0.occurredAt < $1.occurredAt }) else {
            return nil
        }
        let alreadyRecorded = events.contains {
            $0.action == .followedThread
                && $0.dayID == todayID
                && (
                    $0.surfaceID == surfaceID
                        || (
                            contentKey?.nonEmpty != nil
                                && $0.contentKey?.nonEmpty == contentKey?.nonEmpty
                        )
                )
        }
        return alreadyRecorded ? nil : origin
    }

    func insights(now: Date = Date(), limit: Int = 4) -> [ReaderLearningInsight] {
        var insights: [ReaderLearningInsight] = []
        if let warming = strongestType(warming: true) {
            insights.append(ReaderLearningInsight(
                id: "warming-type-\(warming.type.rawValue)",
                kind: .warmingType,
                line: "\(warming.type.shortTitle) is warming in the margins.",
                evidence: {
                    let positive = warming.affinity.kept + warming.affinity.loved + warming.affinity.crossingSignals
                    let cooling = warming.affinity.dismissed + warming.affinity.missed
                    let crossings = warming.affinity.crossingSignals
                    let base = "\(positive) positive signals, \(cooling) cooling signals."
                    guard crossings > 0 else { return base }
                    return "\(base) \(crossings) of them left the page."
                }(),
                strength: warming.affinity.rawScore
            ))
        }
        if let cooling = strongestType(warming: false) {
            insights.append(ReaderLearningInsight(
                id: "cooling-type-\(cooling.type.rawValue)",
                kind: .coolingType,
                line: "I'm letting \(cooling.type.shortTitle.lowercased()) rest.",
                evidence: "\(cooling.affinity.dismissed + cooling.affinity.missed) cooling signals.",
                strength: abs(cooling.affinity.rawScore)
            ))
        }
        if let tag = strongestTag() {
            insights.append(ReaderLearningInsight(
                id: "warming-tag-\(tag.key)",
                kind: .warmingTag,
                line: "A pattern keeps returning: \(tag.key.replacingOccurrences(of: "-", with: " ")).",
                evidence: "\(tag.affinity.kept + tag.affinity.loved) positive signals taught this tag.",
                strength: tag.affinity.rawScore
            ))
        }
        if let hour = strongestPositiveHour() {
            insights.append(ReaderLearningInsight(
                id: "time-window-\(hour)",
                kind: .timeWindow,
                line: "I'm learning when pages land.",
                evidence: "Positive keeps cluster around \(Self.hourLabel(hour)).",
                strength: 4
            ))
        }
        let metrics = metrics(now: now)
        if metrics.meaningfulEventCount >= 6 {
            insights.append(ReaderLearningInsight(
                id: "compounding-\(metrics.meaningfulEventCount)",
                kind: .compounding,
                line: "This Book is no longer starting from zero.",
                evidence: "\(metrics.meaningfulEventCount) reader decisions now shape curation across \(metrics.learnedSurfaceCount) surfaces.",
                strength: min(20, metrics.meaningfulEventCount)
            ))
        }
        return insights
            .sorted {
                if $0.strength == $1.strength { return $0.id < $1.id }
                return $0.strength > $1.strength
            }
            .prefix(limit)
            .map { $0 }
    }

    func shortSummary(now: Date = Date()) -> String? {
        let metrics = metrics(now: now)
        guard metrics.meaningfulEventCount >= 3 else { return nil }

        var clauses: [String] = []
        if let warming = strongestType(warming: true) {
            clauses.append("\(warming.type.shortTitle) has been landing")
        }
        if let tag = strongestTag() {
            clauses.append("\(tag.key.replacingOccurrences(of: "-", with: " ")) keeps returning")
        }
        if let cooling = strongestType(warming: false) {
            clauses.append("\(cooling.type.shortTitle.lowercased()) wants more quiet")
        }
        if let hour = strongestPositiveHour() {
            clauses.append("pages tend to meet you in the \(Self.hourLabel(hour))")
        }

        guard !clauses.isEmpty else {
            return "\(metrics.meaningfulEventCount) choices have started shaping the next prompts."
        }
        return clauses.prefix(3).joined(separator: "; ") + "."
    }

    func promptLines(now: Date = Date(), limit: Int = 4) -> [String] {
        insights(now: now, limit: limit).map { "\($0.line) \($0.evidence)" }
    }

    func merged(with imported: ReaderLearningModel) -> ReaderLearningModel {
        var merged = ReaderLearningModel()
        for event in (events + imported.events).sorted(by: { $0.occurredAt < $1.occurredAt }) {
            if !merged.events.contains(where: { $0.id == event.id }) {
                merged.record(event)
            }
        }
        return merged
    }

    private mutating func rebuildDailyDigest(for dayID: String) {
        let dayEvents = events.filter {
            $0.dayID == dayID && $0.allowsCurationLearning
        }
        guard !dayEvents.isEmpty else { return }
        let positiveActions: Set<ReaderLearningAction> = [.kept, .loved]
        let negativeActions: Set<ReaderLearningAction> = [.dismissed, .missed]

        let typeScores = dayEvents.reduce(into: [BookPageType: Int]()) { scores, event in
            if positiveActions.contains(event.action) { scores[event.type, default: 0] += 1 }
            if negativeActions.contains(event.action) { scores[event.type, default: 0] -= 1 }
        }
        let tagScores = dayEvents.reduce(into: [String: Int]()) { scores, event in
            for tag in event.tags {
                if positiveActions.contains(event.action) { scores[tag, default: 0] += 1 }
                if negativeActions.contains(event.action) { scores[tag, default: 0] -= 1 }
            }
        }

        let digest = ReaderLearningDailyDigest(
            dayID: dayID,
            learnedAt: dayEvents.map(\.occurredAt).max() ?? Date(),
            eventCount: dayEvents.count,
            strongestType: typeScores.filter { $0.value > 0 }.max { $0.value < $1.value }?.key,
            strongestTag: tagScores.filter { $0.value > 0 }.max { $0.value < $1.value }?.key,
            coolingType: typeScores.filter { $0.value < 0 }.min { $0.value < $1.value }?.key
        )
        dailyDigests.removeAll { $0.dayID == dayID }
        dailyDigests.append(digest)
        dailyDigests = Array(dailyDigests.sorted { $0.learnedAt < $1.learnedAt }.suffix(45))
    }

    private func strongestType(warming: Bool) -> (type: BookPageType, affinity: ReaderLearningAffinity)? {
        typeAffinities
            .filter { _, affinity in
                affinity.meaningfulSignals >= 2 && (warming ? affinity.rawScore > 0 : affinity.rawScore < 0)
            }
            .map { (type: $0.key, affinity: $0.value) }
            .sorted {
                let left = abs($0.affinity.rawScore)
                let right = abs($1.affinity.rawScore)
                if left == right { return $0.type.rawValue < $1.type.rawValue }
                return left > right
            }
            .first
    }

    private func strongestTag() -> (key: String, affinity: ReaderLearningAffinity)? {
        tagAffinities
            .filter { key, affinity in
                affinity.rawScore > 0 && affinity.meaningfulSignals >= 2 && !Self.ignoredInsightTags.contains(key)
            }
            .map { (key: $0.key, affinity: $0.value) }
            .sorted {
                if $0.affinity.rawScore == $1.affinity.rawScore { return $0.key < $1.key }
                return $0.affinity.rawScore > $1.affinity.rawScore
            }
            .first
    }

    private func strongestPositiveHour() -> Int? {
        let counts = events.reduce(into: [Int: Int]()) { counts, event in
            guard event.allowsCurationLearning else { return }
            switch event.action {
            case .kept, .loved:
                counts[event.hour, default: 0] += 1
            default:
                break
            }
        }
        return counts.filter { $0.value >= 2 }.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }.first?.key
    }

    private static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }

    private static let ignoredInsightTags: Set<String> = [
        "book-notices", "literary-continuity", "patterns", "clusters"
    ]
}

enum ReaderAttentionMasteryStage: String, Codable, CaseIterable, Equatable {
    case notice
    case name
    case connect
    case transform

    var title: String { rawValue.uppercased() }

    static func current(for learning: ReaderLearningModel) -> Self {
        let actedSurfaceIDs = Set(learning.events.compactMap { event -> String? in
            switch event.action {
            case .acted, .followedThread, .kept, .loved:
                return event.surfaceID
            default:
                return nil
            }
        })
        switch actedSurfaceIDs.count {
        case 0..<4: return .notice
        case 4..<12: return .name
        case 12..<30: return .connect
        default: return .transform
        }
    }
}

struct MomentaryActionPrompt: Equatable {
    var stage: ReaderAttentionMasteryStage
    var question: String
    var placeholder: String
    var buttonTitle: String
}

struct MomentaryActionOutcome: Equatable {
    var recognitionLine: String
    var keepsakeLine: String?
}

/// A replenished published desk window. Slot keys survive cadence-rotated page
/// ids, while resolved slots are continuously replaced from the Curator's
/// already-ranked reserve.
struct BookDeskRound: Equatable {
    /// The opening — the Pages the reader meets first, and the only ones the
    /// old three-card desk ever showed at once. It still names the head of the
    /// block for scoring purposes; it is no longer "everything the reader can
    /// see", because the folio publishes the whole block as turnable leaves.
    static let openingCapacity = 3
    /// What the reader can actually reach by turning: the published block, and
    /// the size of each further pull when they ask to go deeper.
    static let reserveCapacity = 9
    /// Ranked material held back for those further pulls. Never displayed whole.
    static let candidateBenchCapacity = 27

    enum Resolution: Equatable { case waiting, opened, passed }
    private(set) var resolutions: [String: Resolution] = [:]
    var slotKeys: Set<String> { Set(resolutions.keys) }
    var hasPublishedPages: Bool { !resolutions.isEmpty }
    func isTracking(_ page: SurfacePage) -> Bool { resolutions[page.deskSlotKey] != nil }
    var isTouched: Bool { resolutions.values.contains { $0 != .waiting } }

    mutating func begin(with pages: [SurfacePage]) {
        var keys: [String] = []
        for page in pages where keys.count < Self.reserveCapacity && !keys.contains(page.deskSlotKey) {
            keys.append(page.deskSlotKey)
        }
        resolutions = Dictionary(uniqueKeysWithValues: keys.map { ($0, .waiting) })
    }
    /// Launch enrichment may deepen an untouched desk before the reader acts.
    /// If its logical slots change, track the Pages that are actually visible.
    /// Once any Page has been resolved, the published encounter is frozen.
    mutating func reconcileUntouched(with pages: [SurfacePage]) {
        guard !isTouched else { return }
        begin(with: pages)
    }
    /// Repairs the tracker after a fallback retirement publishes a different
    /// page into an existing desk. Existing answers survive by logical slot;
    /// genuinely new slots enter as waiting. This keeps a recovered desk from
    /// sending its next swipe back through the slow, untracked fallback path.
    mutating func reconcilePublished(with pages: [SurfacePage]) {
        var next: [String: Resolution] = [:]
        for page in pages.prefix(Self.reserveCapacity) where next[page.deskSlotKey] == nil {
            next[page.deskSlotKey] = resolutions[page.deskSlotKey] ?? .waiting
        }
        resolutions = next
    }
    /// Opening one Page does not discard the reserve. The Page remains a
    /// resolved member of the current window until it is kept or sent away,
    /// and every waiting card behind it remains available.
    mutating func openKeepingReserve(_ page: SurfacePage) { resolve(page, as: .opened) }
    mutating func open(_ page: SurfacePage) { resolve(page, as: .opened) }
    mutating func pass(_ page: SurfacePage) { resolve(page, as: .passed) }
    mutating func undoPass(_ page: SurfacePage) {
        guard resolutions[page.deskSlotKey] == .passed else { return }
        resolutions[page.deskSlotKey] = .waiting
    }
    private mutating func resolve(_ page: SurfacePage, as next: Resolution) {
        let key = page.deskSlotKey
        guard let current = resolutions[key], current != .opened else { return }
        if current == .passed && next == .passed { return }
        resolutions[key] = next
    }
}

/// The Book's last, local cupboard. These Pages never compete with a healthy
/// Curator result; they exist only so a new, heavily-disabled, or temporarily
/// underprepared Book can still offer something honest to read or do.
enum BookEvergreenPlayReserve {
    private struct Seed {
        var type: BookPageType
        var prompt: String
        var detail: String
        var body: String? = nil
        var tags: String
        /// Anything the page type needs in order to be a working Page rather
        /// than an empty frame. A Believing without countersigns, or a Quip
        /// without a quip, opens and does nothing.
        var extraMetadata: [String: String] = [:]
    }

    private static let seeds: [Seed] = [
        Seed(type: .souvenir, prompt: "Steal One Sentence From Right Now", detail: "Look up. Grab one exact thing from this minute before it goes — a sound, a smell, what someone just said. Write it in the box below.", tags: "souvenir,noticing,exact-language"),
        Seed(type: .diary, prompt: "The Smallest True Thing", detail: "One sentence in the box below. Make it small and make it true. Don't tidy it up for me.", tags: "journal,truth,ordinary"),
        Seed(type: .mood, prompt: "What Weather Is In The Room?", detail: "Pick the weather that matches how you are, or write your own below. I'm not going to try to clear it up.", tags: "inner-weather,capacity,shelter"),
        Seed(
            type: .affirmations,
            // A Believing page puts the believing itself in the prompt. This
            // seed used to put a *title* there and offer nothing to react to,
            // so the card opened as an empty frame that asked the reader to do
            // all of the work. The premise is sound: a believing the reader
            // may amend is the countersign mechanic with a twist: it simply
            // needs an actual sentence to amend.
            prompt: "You are not behind. You are carrying more than the version of you who made the plan.",
            detail: "That one's mine, not yours. Keep it, cross it out, or write the truer version underneath: I'd rather have your sentence than my own.",
            tags: "believing,language,choice",
            extraMetadata: [
                "affirmationKind": "gift",
                "countersigns": "I'll keep it.||Not quite.||We'll see.",
                "placeholder": "The truer version is…",
                "surfaceLabel": "Believing"
            ]
        ),
        Seed(type: .aboutYou, prompt: "One Thing I Should Know", detail: "Tell me something about you in the box below. Odd, dull, inconvenient, whatever. I'd rather know than guess.", tags: "about-you,curiosity,reader-authored"),
        Seed(type: .body, prompt: "Where Is Today Sitting In You?", detail: "Shoulders? Jaw? Stomach? Feet? Write where it's sitting below. I'm not going to diagnose you and you don't have to fix it.", tags: "body,noticing,capacity"),
        Seed(type: .fuel, prompt: "What Would Make The Next Hour Kinder?", detail: "Water, food, a walk, a nap, warmth, fresh air, or something better. Name one below and go and get it.", tags: "fuel,care,next-hour"),
        Seed(type: .quotes, prompt: "A Sentence Looking For Company", detail: "Here's a line off my shelves. Say below whether it has anything to do with your day, or tell me it doesn't.", tags: "quote,language,reading"),
        Seed(
            type: .quip,
            prompt: "The Margin Has Something To Add",
            detail: "A bit of Academy nonsense that shoved its way in here. Tell me what you make of it below.",
            body: "The Academy has ruled that every obvious fact must spend one afternoon wearing a false moustache. This is called perspective.",
            tags: "quip,play,academy"
        ),
        Seed(type: .wonderCompass, prompt: "Point Somewhere Slightly Sideways", detail: "Do one small thing differently in the next hour — a new route, a slower look, the other chair. Then come back and write what you noticed.", tags: "wonder-compass,detour,noticing"),
        Seed(type: .note, prompt: "Leave A Note Where Tomorrow Can Find It", detail: "Write something below for the you who wakes up tomorrow. A warning, a nudge, a kindness. They'll find it.", tags: "note,tomorrow,reader-authored"),
        Seed(type: .rest, prompt: "A Page With No Ambition", detail: "Nothing is being asked of you here. Sit for one breath, or shut me and go. The Page will keep.", tags: "rest,shelter,no-pressure")
    ]

    static func pages(
        now: Date,
        generation: Int = 0,
        keptPageCount: Int = BookMemoryGate.requiredKeptPageCount
    ) -> [SurfacePage] {
        let slot = SurfaceCadence.slotID(for: now, hours: 6)
        let generation = max(0, generation)
        return seeds.enumerated().compactMap { index, seed in
            // The emergency cupboard must obey the same maturity boundary as
            // the ordinary Curator. Otherwise it can put a Page on the desk
            // that `openDeskSurface` is required to refuse when tapped.
            guard !BookMemoryGate.locks(seed.type, keptPageCount: keptPageCount) else {
                return nil
            }
            return SurfacePage(
                id: "evergreen-play-\(seed.type.rawValue)-\(slot)-g\(generation)-\(index)",
                type: seed.type,
                // This last-resort shelf is structural, not a disguised return
                // of a source the reader disabled. Normal source settings still
                // govern every ordinary Curator candidate above it.
                sourceID: "evergreen-play-reserve-\(seed.type.rawValue)",
                score: 20 - index,
                reason: "The deeper stacks are still gathering, so I opened my always-ready cupboard.",
                prompt: seed.prompt,
                detail: seed.detail,
                payload: BookPagePayload(
                    headline: seed.prompt,
                    body: seed.body ?? seed.detail,
                    metadata: seed.extraMetadata.merging([
                        "evergreenPlayReserve": "true",
                        // Structural play keeps the Book inexhaustible but is
                        // never allowed to masquerade as a causal assignment
                        // or teach the intimate Curator from emergency use.
                        "curationLearning": "forbidden",
                        // Deliberately free of `generation`. This key is the
                        // identity of the readable Page, and the rest interval
                        // in `allowsAutomaticSurface` is keyed on it, so
                        // folding a rotation counter in meant every dismissal
                        // minted a Page the Book had never seen, and the reader
                        // could not put the same card down. Dismissing it was
                        // what brought it back.
                        "noveltyKey": "evergreen-\(index)",
                        "tags": "\(seed.tags),\(ReaderLearningEvent.curationLearningForbiddenTag)"
                    ]) { _, structural in structural }
                )
            )
        }
    }
}

enum EnchantedSnackFirstBeat: Equatable {
    case momentary(MomentaryActionPrompt)
    case native
}

/// Gives prose-first Pages one immediate act above their deeper material.
/// Pages that already open directly into a game, conversation, reading,
/// transaction, or multi-step ritual keep their native first move.
enum MomentaryAttentionEngine {
    static let pagesWithNativeFirstMove: Set<BookPageType> = [
        .askTheBook, .radio, .gamePage, .bookJump, .faeBargain, .bookFae,
        .pactVerdict, .pactErrand, .narrativeOS, .academyClass, .tarot,
        .enchantment, .inkrestOfficeHours, .twoReadings, .wordNegotiation,
        .plainPage, .bookOfYou, .mood, .aboutYou, .affirmations, .inventory,
        .marginsAtlas, .calendar, .location, .anchor, .wonderCompass, .elective
    ]

    static func prompt(
        for surface: SurfacePage,
        learning: ReaderLearningModel
    ) -> MomentaryActionPrompt? {
        if case let .momentary(prompt) = firstBeat(for: surface, learning: learning) { return prompt }
        return nil
    }

    static func firstBeat(
        for surface: SurfacePage,
        learning: ReaderLearningModel
    ) -> EnchantedSnackFirstBeat {
        guard !pagesWithNativeFirstMove.contains(surface.type),
              surface.payload.metadata["keptReadback"] != "true",
              !hasSpecializedFirstMove(surface) else {
            return .native
        }
        let stage = ReaderAttentionMasteryStage.current(for: learning)
        switch stage {
        case .notice:
            return .momentary(MomentaryActionPrompt(
                stage: stage,
                question: "What caught first?",
                placeholder: "One word is enough",
                buttonTitle: "Let it catch"
            ))
        case .name:
            return .momentary(MomentaryActionPrompt(
                stage: stage,
                question: "What has the strongest charge?",
                placeholder: "Name the detail",
                buttonTitle: "Give it ink"
            ))
        case .connect:
            return .momentary(MomentaryActionPrompt(
                stage: stage,
                question: "What does this touch in your life?",
                placeholder: "A person, place, memory, or object",
                buttonTitle: "Start the thread"
            ))
        case .transform:
            return .momentary(MomentaryActionPrompt(
                stage: stage,
                question: "What will you carry out of this Page?",
                placeholder: "One small change",
                buttonTitle: "Carry it out"
            ))
        }
    }

    private static func hasSpecializedFirstMove(_ surface: SurfacePage) -> Bool {
        let metadata = surface.payload.metadata
        return ["playfulMissionID", "anchorOffer", "anchorID", "moodChoice", "aboutYouChoice",
                "affirmationCountersign", "preparedRitual", "opensBookShop", "opensPagewright"].contains {
            metadata[$0]?.nonEmpty != nil
        }
    }

    static func recognition(
        for rawText: String,
        stage: ReaderAttentionMasteryStage
    ) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = trimmed.count > 90
            ? String(trimmed.prefix(87)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
            : trimmed
        guard !clipped.isEmpty else { return "" }
        switch stage {
        case .notice:
            return "I catch “\(clipped)” before the rest of the Page can explain it."
        case .name:
            return "“\(clipped)” takes ink. The Page knows what you meant."
        case .connect:
            return "“\(clipped)” touches the Page. A thread has started."
        case .transform:
            return "“\(clipped)” leaves the Page with you. I mark the change."
        }
    }
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

    /// A rare, must-see moment the Book has earned the right to show: the
    /// first reading, a constellation naming, a sealed or opened wager. These
    /// are pinned above the desk's three lanes and are never evicted.
    var isDeskMilestone: Bool { payload.metadata["milestone"] == "true" }

    /// What "the same page again" means to a reader: the content identity,
    /// not the surface id (which changes every slot).
    var varietyKey: String {
        if let family = payload.metadata["compassFamily"]?.nonEmpty { return "compass:\(family)" }
        if let id = payload.metadata["pairID"]?.nonEmpty { return "tworeadings:\(id)" }
        if let id = payload.metadata["entityID"]?.nonEmpty { return "cast:\(id)" }
        if let id = payload.metadata["snippetID"]?.nonEmpty { return "snippet:\(id)" }
        if let id = payload.metadata["quipID"]?.nonEmpty { return "quip:\(id)" }
        if let id = payload.metadata["assetName"]?.nonEmpty { return "plate:\(id)" }
        if let id = payload.metadata["packArchetypeID"]?.nonEmpty { return "pack:\(id)" }
        if let id = payload.metadata["constellationID"]?.nonEmpty { return "constellation:\(id)" }
        if payload.metadata["chapterPrimer"] == "true",
           let stage = payload.metadata["primerStage"]?.nonEmpty {
            return "chapter-primer:\(stage)"
        }
        if payload.metadata["chapterBinding"] == "true" { return "chapter-binding" }
        if let id = payload.metadata["sessionID"]?.nonEmpty { return "session:\(id)" }
        if let id = payload.metadata["senderID"]?.nonEmpty { return "sender:\(id)" }
        if let id = payload.metadata["anchorID"]?.nonEmpty { return "anchor:\(id)" }
        if let id = payload.metadata["storyRecipeID"]?.nonEmpty { return "recipe:\(id)" }
        if let id = payload.metadata["journalPromptID"]?.nonEmpty { return "journal:\(id)" }
        if let id = payload.metadata["tarotSpreadID"]?.nonEmpty { return "tarot-spread:\(id)" }
        if let id = payload.metadata["storyFormID"]?.nonEmpty { return "form:\(id)" }
        if let id = payload.metadata["bookJumpID"]?.nonEmpty {
            let action = payload.metadata["bookJumpAction"]?.nonEmpty ?? "step"
            return "bookjump:\(id):\(action)"
        }
        if let id = payload.metadata["bookID"]?.nonEmpty { return "bookjump-book:\(id)" }
        if payload.metadata["firstDoorOrigin"] == "true" { return "first-door-origin" }
        if let id = payload.metadata["firstDoorApprenticeshipDay"]?.nonEmpty { return "first-door-apprenticeship:\(id)" }
        if let id = payload.metadata["tipID"]?.nonEmpty { return "tip:\(id)" }
        // Some dynamic families do not own a named catalog id. Their visible
        // copy is still an individual Page and must not collapse back into the
        // source family for curation or learning.
        return curatorContentNoveltyKey
    }

    /// The identity of the actual readable Page, independent of cadence ids and
    /// source-family rotation. Adapters may provide a semantic `noveltyKey`;
    /// otherwise the reader-visible copy forms a stable local fingerprint.
    var curatorContentNoveltyKey: String {
        if let explicit = payload.metadata["noveltyKey"]?.nonEmpty {
            return "content:\(sourceID):\(explicit)"
        }
        let visibleCopy = [
            type.rawValue,
            sourceID,
            prompt,
            detail,
            payload.headline,
            payload.body
        ].joined(separator: "¶")
        return "content:\(sourceID):\(visibleCopy.stableHash)"
    }

    var supplementalStoryVarietyKeys: [String] {
        guard type == .narrativeOS else { return [] }
        var keys: [String] = []
        if let id = payload.metadata["storyFormID"]?.nonEmpty { keys.append("form:\(id)") }
        if let id = payload.metadata["storyGenreID"]?.nonEmpty { keys.append("genre:\(id)") }
        return keys
    }

    var curatorServedHistoryKeys: [String] {
        var keys = [
            curatorContentNoveltyKey,
            varietyKey,
            "source:\(sourceID)",
            CuratorVarietyGovernor.typeKey(for: type)
        ]
        if let recurrenceKey = curatorAutomaticRecurrenceHistoryKey {
            keys.append(recurrenceKey)
        }
        if carriesEarnedReaderTrace {
            keys.append(Self.earnedReaderTraceHistoryKey)
        }
        if let missionID = payload.metadata["playfulMissionID"]?.nonEmpty {
            keys.append("playful-mission:\(missionID)")
        }
        keys.append(contentsOf: supplementalStoryVarietyKeys)

        var uniqueKeys: [String] = []
        var seen = Set<String>()
        for key in keys where seen.insert(key).inserted {
            uniqueKeys.append(key)
        }
        return uniqueKeys
    }

    /// A deliberately recurring Page owns a dated occurrence rather than a
    /// one-off piece of prose. The prose may stay reassuringly familiar while
    /// the bell, day, or newspaper edition advances. Recording this key lets a
    /// new occurrence return without allowing the same occurrence to nag.
    var curatorAutomaticRecurrenceHistoryKey: String? {
        guard let slot = payload.metadata["automaticRecurrenceSlot"]?.nonEmpty else {
            return nil
        }
        return "recurrence:\(sourceID):\(slot)"
    }

    var curatorDeskExclusionKeys: Set<String> {
        var keys = Set(curatorServedHistoryKeys)
        keys.insert(id)
        return keys
    }

    /// A swipe rests the exact readable idea and its semantic occurrence, not
    /// its whole Page Type or source family. Broad control belongs to explicit
    /// source settings and Belief; otherwise an inexhaustible desk can be
    /// accidentally exhausted one family at a time.
    var curatorDismissalRestKeys: Set<String> {
        Set(curatorDeskExclusionKeys.filter {
            !$0.hasPrefix("source:") && !$0.hasPrefix("type:")
        })
    }

    /// The desk slot a card logically occupies. Raw ids can't identify a slot:
    /// many adapters rotate a cadence slot (or a raw timestamp) through their
    /// candidate ids, so the same logical card comes back under a fresh id.
    /// The desk's structural rules (one source family, one type) make this
    /// pair unique per desk.
    var deskSlotKey: String {
        "\(sourceID)|\(type.rawValue)"
    }

    /// Pages that commission a concrete action from the reader. This is wider
    /// than `isCompositionPrompt`: a mission and an apprenticeship can otherwise
    /// stack despite asking for two different kinds of effort.
    var isReaderActionCommission: Bool {
        if payload.metadata["curatorActionCommission"] == "true"
            || payload.metadata["playfulMissionID"]?.nonEmpty != nil
            || type == .wickerDare
            || payload.metadata["calendarDoorPreview"] == "true" {
            return true
        }
        switch payload.metadata["firstRunStep"] {
        case "calendar-door", "compass-run", "first-mission", "local-brain-setup":
            return true
        default:
            return false
        }
    }

    /// One global history key records when the visible desk last spent
    /// reader-authored evidence. It is intentionally about the encounter, not
    /// a particular source family: Diary quoting an old sentence and Book
    /// Remembered returning it both satisfy the same editorial debt.
    static var earnedReaderTraceHistoryKey: String {
        "desk:earned-reader-trace"
    }

    /// A Page whose visible copy is grounded in something the reader actually
    /// wrote or brought back. Profile facts and generic personalization do not
    /// qualify; the Page must carry a concrete receipt into the encounter.
    var carriesEarnedReaderTrace: Bool {
        let metadata = payload.metadata
        if metadata["earnedReaderTrace"] == "true" { return true }
        if type == .bookRemembered {
            return metadata["rememberedText"]?.nonEmpty != nil
                || metadata["livedQuestReturn"] == "true"
        }
        if type == .diary {
            return metadata["journalEvidencePageID"]?.nonEmpty != nil
                && metadata["journalEvidenceExcerpt"]?.nonEmpty != nil
        }
        if type == .twoReadings {
            return metadata["anchorPageID"]?.nonEmpty != nil
                && metadata["anchorPageText"]?.nonEmpty != nil
        }
        guard type == .bookNotices else { return false }
        if metadata["firstReading"] == "true"
            || metadata["bookAsksSourcePageID"]?.nonEmpty != nil {
            return true
        }
        return metadata["evidencePageIDs"]?.nonEmpty != nil
            && (
                metadata["tinyPatternCards"]?.nonEmpty != nil
                    || metadata["observationKey"]?.nonEmpty != nil
                    || metadata["connectionNarrative"] == "true"
            )
    }

    /// The effort the reader feels in the prose, whether or not an adapter
    /// Whether opening this Page can lead to the reader spending money.
    ///
    /// The reader is asked in onboarding whether money is a boundary - "free by
    /// default", "ask first" - and two separate mechanisms were built to honour
    /// the answer: the capability contract's `cost`, and a direct scoring
    /// demotion. Both keyed off tags `spend`, `shopping`, `purchase` and `paid`,
    /// and **nothing in the app has ever produced any of them**, so a reader who
    /// asked to be kept away from spending was shown the BookShop and the
    /// Bindery ranked exactly as if they were free.
    ///
    /// Derived rather than hand-tagged, because hand-tagging is what drifted:
    /// `opensBookShop` is already the marker every commerce surface sets to say
    /// where it leads, so the two cannot fall out of step again.
    var opensSpending: Bool {
        payload.metadata["opensBookShop"] == "true"
            || payload.metadata["binderyShelf"] == "true"
    }

    /// remembered to mark a formal commission. This keeps a mission from
    /// sharing the desk with a journal question or another imperative card.
    var isReaderFacingAsk: Bool {
        if isReaderActionCommission || type.isCompositionPrompt { return true }
        let imperativeOpenings = [
            "keep ", "write ", "find ", "choose ", "name ", "give ",
            "replace ", "use ", "move ", "notice ", "open ", "take ",
            "ask ", "spend ", "visit ", "let ", "look ", "pick ",
            "stand ", "answer ", "log ", "bring ", "turn "
        ]
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let detail = detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if imperativeOpenings.contains(where: prompt.hasPrefix)
            || imperativeOpenings.contains(where: detail.hasPrefix) {
            return true
        }
        let questionTypes: Set<BookPageType> = [
            .mood,
            .diary,
            .souvenir,
            .body,
            .fuel,
            .aboutYou
        ]
        return prompt.contains("?") && questionTypes.contains(type)
    }

    /// Structural desk budgets read the authored exact-Page contract when one
    /// exists, while preserving legacy markers during the gradual migration.
    var spendsCuratorActionBudget: Bool {
        isReaderActionCommission || pageCapabilities.pressureCost >= 0.75
    }

    /// The rolling-week causal safeguard is narrower than the visible desk's
    /// one-action rule. A five-minute mission still occupies the desk's single
    /// action slot, but it must not be treated as a third high-pressure attempt.
    var spendsHighPressureCausalBudget: Bool {
        pageCapabilities.pressureCost >= 0.75
    }

    var spendsCuratorAskBudget: Bool {
        isReaderFacingAsk || pageCapabilities.asksReader
    }

    /// True when only the id differs: the card the reader sees is unchanged.
    func contentMatches(_ other: SurfacePage) -> Bool {
        type == other.type
            && sourceID == other.sourceID
            && intent == other.intent
            && renderStyle == other.renderStyle
            && score == other.score
            && reason == other.reason
            && prompt == other.prompt
            && detail == other.detail
            && payload == other.payload
    }

    var readerLearningTags: [String] {
        let rawTags = payload.metadata["tags"]?
            .split(separator: ",")
            .map { String($0) } ?? []
        let metadataTags = [
            payload.metadata["illustrationKind"],
            // These all come from `?? ""` sources on the story packet, so they
            // must be emptiness-checked or they emit bare "genre:" noise into
            // the tag affinities.
            payload.metadata["storyGenreID"]?.nonEmpty.map { "genre:\($0)" },
            payload.metadata["storyFormID"]?.nonEmpty.map { "form:\($0)" },
            // A Story Page arrives as one of four recipe variants, so choosing
            // between them is a decision the Curator already makes. Until these
            // three became tags it made that decision blind: it could learn
            // that a reader likes cozy-mystery, but not which recipe, what kind
            // of material the scene was built from, or whether the world was
            // running its own errand or retelling the reader's day.
            payload.metadata["storyRecipeID"]?.nonEmpty.map { "recipe:\($0)" },
            payload.metadata["storyRecipeGroundingKind"]?.nonEmpty.map { "grounding:\($0)" },
            payload.metadata["storyLane"]?.nonEmpty.map { "lane:\($0)" },
            payload.metadata["senderID"].map { "sender:\($0)" },
            payload.metadata["entityID"].map { "entity:\($0)" },
            payload.metadata["anchorID"].map { "anchor:\($0)" },
            payload.metadata["packArchetypeID"].map { "pack:\($0)" }
        ].compactMap { $0 }
        return Array(Set((rawTags + metadataTags).map(\.readerLearningNormalizedTag).filter { !$0.isEmpty })).sorted()
    }
}

/// The three balancing lanes of the home desk. Every page kind belongs to
/// exactly one, so the shelf can guarantee one of each.
enum DeskLane: String, CaseIterable {
    case outward   // the lens: reading your real life, body, and day
    case fiction   // the living Academy world: story, cast, faculty, fae, war
    case other     // play, reference, returns, images, utility
}

/// A floor under being seen.
///
/// The three lanes guarantee the reader their own day and the Academy world
/// every single session. Nothing guaranteed them a page that is *about them*:
/// the reflective pages sit in `.other` and can lose the grab-bag slot to a
/// help tip for weeks at a stretch without any rule being broken.
///
/// So: if no page that reflects the reader has surfaced in a week, the best
/// available one gets first claim on the visible desk: after milestones and
/// finished commissions, which are promises already made, and before ordinary
/// probabilistic composition.
///
/// This is a floor, not a quota. It does nothing in a week where the Book
/// already noticed something out loud, and it can offer nothing when the
/// library is too young to have produced a reflective page at all.
enum CuratorMirrorFloor {
    /// A week: long enough that an active reader hits it only when the desk
    /// genuinely never turned toward them, short enough that "this thing knows
    /// me" survives a quiet stretch.
    static let quietDays = 7

    /// Whether the desk owes the reader a page about themselves.
    ///
    /// A hard day is never the moment to hand somebody a map of themselves.
    /// The pages this floor draws from are reflective and heavy: the curator
    /// already pushes `.marginsAtlas` down when the reader is tired or
    /// over-booked, and pushes `.rest` up, so a floor that outranked those
    /// rules would quietly undo them on exactly the days they were written
    /// for. The debt is not cancelled by distress, only deferred: the reader
    /// is still owed a mirror, and will be handed one when the day can hold it.
    static func isOwed(
        history: [String: SurfaceHistoryRecord],
        now: Date,
        distressActive: Bool = false
    ) -> Bool {
        guard !distressActive else { return false }
        let cutoff = now.addingTimeInterval(-Double(quietDays) * 86_400)
        let lastMirror = BookPageType.allCases
            .filter(\.reflectsTheReader)
            .compactMap { history[CuratorVarietyGovernor.typeKey(for: $0)]?.lastShownAt }
            .max()
        // Nothing reflective has ever surfaced: the strongest possible case for
        // being owed one. A young library is protected without a guard here:
        // the floor can only promote a candidate the adapters already produced,
        // and their maturity gates decide when that is.
        guard let lastMirror else { return true }
        return lastMirror < cutoff
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

    /// Pages whose whole job is to show the reader back to themselves: the
    /// Book's claim to have read them, rather than to have generated something.
    ///
    /// These all land in the `.other` lane, which is correct as far as lane
    /// balance goes (they are neither the reader's day nor the Academy world)
    /// but leaves them competing for one grab-bag slot against help tips, the
    /// inventory, and the shop preview. Lane membership alone therefore
    /// guarantees the reader world content every session and never guarantees
    /// a single page that is about them. `CuratorMirrorFloor` is the floor
    /// under that; this is the set it draws from.
    ///
    /// Deliberately excluded: `.bookOfYou` and `.twoReadings`, which reflect
    /// the reader but sit in the `.fiction` lane and are already surfaced by
    /// lane balance; and `.aboutYou`, which asks a question rather than
    /// returning an answer.
    var reflectsTheReader: Bool {
        switch self {
        case .bookNotices, .bookRemembered, .bookConnections, .marginsAtlas, .bookPocket:
            return true
        default:
            return false
        }
    }

    /// The single source of truth for lane membership. `default` is `.other`
    /// so any future page kind (e.g. the coming quotation pages) lands in the
    /// grab-bag lane until it is deliberately reclassified.
    var deskLane: DeskLane {
        switch self {
        // Outward: the reader attends to the actual world / their own day.
        case .wonderCompass, .diary, .mood, .souvenir, .body, .fuel,
             .weather, .todaysSky, .location, .anchor, .pactErrand,
             .rest, .enchantment, .plainPage:
            return .outward
        // Fiction: the Academy world performs, corresponds, or contends.
        case .narrativeOS, .letter, .gossip, .bookAside, .facultyResearch, .supportGuild,
             .inkrestOfficeHours, .faeBargain, .bookFae, .academyClass,
             .elective, .festival, .twoReadings, .castBond, .bookJump,
             .wordNegotiation, .theBleed, .pactDispatch, .pactVerdict,
             .bookOfYou:
            return .fiction
        // Other: everything else: games, reference, returns, images, tools.
        default:
            return .other
        }
    }

    /// Retained for later phases; derived so lane membership has one home.
    var pointsOutward: Bool { deskLane == .outward }

    /// Private support logs may feed faculty charts, but keeping them should not
    /// visibly warm a named cast member's Belief.
    var suppressesCastBeliefRipple: Bool {
        switch self {
        case .fuel, .mood:
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
        // Keep enough memory for seasonal ceremony and interpretation rests.
        // The ledger stores tiny counters, not Page prose; four months lets a
        // ninety-day promise remain enforceable without growing forever.
        return updated.filter { now.timeIntervalSince($0.value.lastShownAt) < 121 * 86_400 }
    }
}

/// Freshness is decided before learned taste. A reader's implicit preferences
/// choose among genuinely available Pages; only explicit Belief gives an exact
/// Page permission to return automatically.
enum CuratorNoveltyPolicy {
    /// Retained as a meaningful compatibility landmark: at this Belief an
    /// exact Page's ordinary overnight rest is just under twenty-five hours.
    /// It is no longer a yes/no eligibility threshold.
    static let repeatBeliefThreshold = 45
    static let belovedBeliefThreshold = 80

    static func belief(
        for page: SurfacePage,
        preferences: CuratorSurfacePreferences
    ) -> Int {
        let recordedBelief = preferences.beliefProfile(for: page).belief
        guard let rawStartingBelief = page.payload.metadata["startingPageBelief"],
              let startingBelief = Int(rawStartingBelief) else {
            return recordedBelief
        }
        // Some authored doors intentionally arrive already believed in. Treat
        // that explicit starting Belief exactly like the score path does, so a
        // generated preview is not rejected as an uninvested repeat before it
        // has had a chance to become its actual Page.
        return max(recordedBelief, max(0, min(100, startingBelief)))
    }

    static func isNewContent(
        _ page: SurfacePage,
        history: [String: SurfaceHistoryRecord]
    ) -> Bool {
        history[page.curatorContentNoveltyKey] == nil
    }

    static func isNewSource(
        _ page: SurfacePage,
        history: [String: SurfaceHistoryRecord]
    ) -> Bool {
        history["source:\(page.sourceID)"] == nil
    }

    static func isNewType(
        _ page: SurfacePage,
        history: [String: SurfaceHistoryRecord]
    ) -> Bool {
        history[CuratorVarietyGovernor.typeKey(for: page.type)] == nil
    }

    static func allowsAutomaticSurface(
        _ page: SurfacePage,
        history: [String: SurfaceHistoryRecord],
        preferences: CuratorSurfacePreferences,
        now: Date
    ) -> Bool {
        // Canonical rituals advance by their own clock. A new dated bell or
        // edition is eligible even when its visible wording is intentionally
        // familiar; once served, that exact occurrence stays off the desk.
        if let recurrenceKey = page.curatorAutomaticRecurrenceHistoryKey {
            return history[recurrenceKey] == nil
        }
        if isNewContent(page, history: history) { return true }
        guard let record = history[page.curatorContentNoveltyKey] else { return true }
        // A protected milestone may win its first desk, but it does not own
        // every later desk merely because the reader did not keep it. Rare
        // ceremonies opt into a long resting interval; keeping them still
        // retires them permanently through their adapter's evidence gate.
        if let rawDays = page.payload.metadata["automaticRepeatRestDays"],
           let restDays = Double(rawDays), restDays > 0 {
            return now.timeIntervalSince(record.lastShownAt) >= restDays * 86_400
        }
        if page.isDeskMilestone { return true }
        if isActiveContinuation(page) { return true }
        let belief = belief(for: page, preferences: preferences)
        // Familiar low-Belief content rests longer, but Belief is never an
        // eligibility veto. Even the quietest Page can eventually return.
        let ordinaryCooldownHours = 18.0 + (Double(100 - belief) * 0.12)
        // Interpretive prose becomes stale much faster than a utility card.
        // These are exact-content floors, not type-family bans: a genuinely
        // different Notice or bond may still surface immediately.
        let editorialFloorHours: Double
        switch page.type {
        case .bookNotices:
            editorialFloorHours = 21 * 24
        case .castBond:
            editorialFloorHours = 30 * 24
        default:
            editorialFloorHours = 0
        }
        let cooldownHours = max(ordinaryCooldownHours, editorialFloorHours)
        return now.timeIntervalSince(record.lastShownAt) >= cooldownHours * 3600
    }

    static func adjustment(
        for page: SurfacePage,
        history: [String: SurfaceHistoryRecord],
        preferences: CuratorSurfacePreferences,
        now: Date
    ) -> Int {
        let pageBelief = belief(for: page, preferences: preferences)
        var delta = 0

        if isNewType(page, history: history) {
            delta += 36
        } else if isNewSource(page, history: history) {
            delta += 24
        } else if isNewContent(page, history: history) {
            delta += 14
        }

        // A familiar family still rests between genuinely different Pages.
        // Strong Belief shortens that rest, but never removes the new-type lead.
        if pageBelief < belovedBeliefThreshold {
            delta -= recencyPenalty(
                record: history["source:\(page.sourceID)"],
                now: now,
                sixHour: 16,
                day: 8
            )
            delta -= recencyPenalty(
                record: history[CuratorVarietyGovernor.typeKey(for: page.type)],
                now: now,
                sixHour: 8,
                day: 4
            )
        }
        return delta
    }

    private static func recencyPenalty(
        record: SurfaceHistoryRecord?,
        now: Date,
        sixHour: Int,
        day: Int
    ) -> Int {
        guard let record else { return 0 }
        let age = now.timeIntervalSince(record.lastShownAt)
        if age < 6 * 3600 { return sixHour }
        if age < 24 * 3600 { return day }
        return 0
    }

    private static func isActiveContinuation(_ page: SurfacePage) -> Bool {
        if page.payload.metadata["curatorContinuation"] == "true" { return true }
        if page.type == .bookJump,
           let action = page.payload.metadata["bookJumpAction"],
           action != BookJumpAction.start.rawValue {
            return true
        }
        return false
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
            case .affirmations: return 3
            case .fuel, .wonderCompass: return 2
            case .narrativeOS, .bookFae, .marginsAtlas, .bookConnections, .bookRemembered, .gossip, .bookJump: return -3
            default: return 0
            }
        case 11..<17:
            switch type {
            case .quip, .quotes, .wonderCompass: return 3
            case .illustration, .aboutYou, .elective: return 2
            case .bookOfYou: return -3
            default: return 0
            }
        case 17..<22:
            switch type {
            case .bookOfYou: return 6
            case .narrativeOS, .bookFae, .marginsAtlas, .bookConnections, .bookRemembered, .bookJump: return 4
            case .diary: return 6
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

/// The Introduction Season: the wider world debuts in stages as the library
/// grows, instead of arriving all at once the moment the local brain wakes.
/// The ladder throttles variety, never volume: capture pages and the core
/// daily loop flow from day one, and each staged family enters as a single
/// felt reveal (`isManagedDebut` lets one debut per desk build).
///
/// Crucially it locks only a family's *first* appearance: anything the desk
/// has already shown: an arc in motion, a Weekly Issue riding the bindery
/// type, an existing reader's whole world: keeps flowing. The season
/// staggers debuts; it never confiscates.
enum IntroductionCurriculum {
    /// Kept pages required to enter each stage. Stage 0 is the open door.
    static let stageThresholds = [0, 3, 6, 12]

    static func stage(forKeptPageCount count: Int) -> Int {
        var reached = 0
        for (index, threshold) in stageThresholds.enumerated() where count >= threshold {
            reached = index
        }
        return reached
    }

    /// Families with a staged debut. Anything absent is stage 0: including
    /// the Book of You braid (the nightly core loop), bindery/inventory, and
    /// the memory trio (Book Remembered, Book Connections, the Margins Atlas).
    /// Those all self-gate on having real material, and size their claims to
    /// the evidence they hold rather than waiting on a keep count.
    static let requiredStage: [BookPageType: Int] = [
        .narrativeOS: 1, .academyClass: 1, .elective: 1, .gamePage: 1,
        .gossip: 2, .bookAside: 2, .letter: 2, .facultyResearch: 2, .supportGuild: 2,
        .inkrestOfficeHours: 2, .glowInvitation: 2, .wordNegotiation: 2,
        .castBond: 2, .twoReadings: 2, .bookNotices: 2, .festival: 2,
        .bookJump: 2,
        .faeBargain: 3, .bookFae: 3, .pactDispatch: 3, .pactVerdict: 3,
        .pactErrand: 3, .theBleed: 3
    ]

    static func locks(
        _ type: BookPageType,
        keptPageCount: Int,
        surfaceHistory: [String: SurfaceHistoryRecord]
    ) -> Bool {
        guard let required = requiredStage[type] else { return false }
        guard stage(forKeptPageCount: keptPageCount) < required else { return false }
        return surfaceHistory[CuratorVarietyGovernor.typeKey(for: type)] == nil
    }

    /// True for a staged family the desk has never shown. At most one of
    /// these joins each build, so unlocks arrive one reveal at a time:
    /// stage-0 families are exempt, keeping a brand-new desk full.
    static func isManagedDebut(
        _ type: BookPageType,
        surfaceHistory: [String: SurfaceHistoryRecord]
    ) -> Bool {
        requiredStage[type] != nil
            && surfaceHistory[CuratorVarietyGovernor.typeKey(for: type)] == nil
    }
}

/// A small, explicit promise that onboarding choices can tip close curation
/// calls without becoming permanent filters. Kept behavior and learned Belief
/// remain stronger evidence; this only gives the first desk a recognizable
/// accent from the shelf the reader asked for.
enum InscriptionCurationAffinity {
    static func boost(
        for page: SurfacePage,
        taste: String?,
        chapter: String?,
        comfort: String?
    ) -> Int {
        var value = tasteBoost(for: page.type, taste: taste)
        value += chapterBoost(for: page.type, chapter: chapter)
        value += comfortBoost(for: page.type, comfort: comfort)
        return value
    }

    private static func tasteBoost(for type: BookPageType, taste: String?) -> Int {
        switch taste?.lowercased() {
        case "letters":
            return [.letter, .gossip, .illustration, .castBond, .supportGuild].contains(type) ? 6 : 0
        case "errands":
            return [.wonderCompass, .enchantment, .pactErrand, .bookJump].contains(type) ? 6 : 0
        case "cozy":
            return [.mood, .souvenir, .rest, .weather].contains(type) ? 6 : 0
        case "weather-place":
            return [.weather, .todaysSky, .location, .anchor].contains(type) ? 6 : 0
        case "eerie":
            return [.narrativeOS, .bookFae, .theBleed, .letter].contains(type) ? 6 : 0
        case "oddities":
            return [.quip, .lore, .wonderCompass, .wordNegotiation].contains(type) ? 6 : 0
        default:
            return 0
        }
    }

    private static func chapterBoost(for type: BookPageType, chapter: String?) -> Int {
        switch chapter?.lowercased() {
        case "emberheart":
            return [.diary, .aboutYou, .narrativeOS, .enchantment].contains(type) ? 3 : 0
        case "mossbloom":
            return [.weather, .rest, .souvenir, .wonderCompass].contains(type) ? 3 : 0
        case "tidecrest":
            return [.wonderCompass, .quip, .enchantment].contains(type) ? 3 : 0
        case "riddlewind":
            return [.letter, .gossip, .castBond, .supportGuild].contains(type) ? 3 : 0
        case "duskthorn":
            return [.narrativeOS, .bookFae, .theBleed, .wordNegotiation].contains(type) ? 3 : 0
        default:
            return 0
        }
    }

    private static func comfortBoost(for type: BookPageType, comfort: String?) -> Int {
        switch comfort?.lowercased() {
        case "gentle":
            return [.rest, .mood, .souvenir].contains(type) ? 2 : 0
        case "strange":
            return [.narrativeOS, .lore, .wonderCompass, .bookFae].contains(type) ? 2 : 0
        default:
            return 0
        }
    }
}

/// A bounded authorial nudge from the reader's actual day. These signals make
/// context relevant at both stages of hierarchical curation without becoming
/// eligibility gates: an unrelated Page always keeps its ordinary path.
enum CuratorWorldContextAffinity {
    static func boost(for page: SurfacePage, mood: CuratorMood) -> Int {
        var delta = 0
        let pageTags = Set(
            (page.payload.metadata["tags"] ?? "")
                .split(separator: ",")
                .map { String($0).readerLearningNormalizedTag }
                .filter { !$0.isEmpty }
        )

        if mood.hasWeatherContext {
            switch page.type {
            case .weather: delta += 8
            case .todaysSky: delta += 5
            case .wonderCompass, .enchantment: delta += 4
            case .location, .souvenir, .quip: delta += 2
            default: break
            }
            if !pageTags.isDisjoint(with: mood.weatherContextTags) {
                delta += 4
            }

            // Some weather is not background; it is an occasion. Let the Book
            // come to the window with the reader when a storm, snow, or fog is
            // actually present, without making ordinary clear weather feel
            // deficient or turning weather into an eligibility gate.
            let occasionTags: Set<String> = ["storm", "thunder", "snow", "fog"]
            let presentOccasions = mood.weatherContextTags.intersection(occasionTags)
            if !presentOccasions.isEmpty {
                switch page.type {
                case .weather: delta += 6
                case .todaysSky: delta += 4
                case .wonderCompass, .enchantment: delta += 3
                case .radio, .souvenir, .location: delta += 2
                default: break
                }
                if !pageTags.isDisjoint(with: presentOccasions) {
                    delta += 4
                }
            }
        }

        if mood.hasCoarseLocationContext {
            switch page.type {
            case .location: delta += 8
            case .wonderCompass: delta += 5
            case .enchantment, .pactErrand: delta += 4
            case .elective, .souvenir, .plainPage: delta += 2
            default: break
            }
        }
        if let place = mood.currentPlaceContext {
            switch place {
            case .home:
                if [.rest, .diary, .enchantment, .illuminatedPhoto, .bookOfYou].contains(page.type) { delta += 6 }
                if [.wonderCompass, .pactErrand].contains(page.type) { delta -= 2 }
            case .work:
                if [.quip, .rest, .souvenir, .wonderCompass].contains(page.type) { delta += 4 }
                if [.bookOfYou, .facultyResearch].contains(page.type) { delta -= 2 }
            case .cafe, .library:
                if [.quotes, .diary, .lore, .wonderCompass].contains(page.type) { delta += 4 }
            case .harbor, .park, .waterfront, .trail:
                if [.wonderCompass, .weather, .location, .enchantment, .souvenir].contains(page.type) { delta += 5 }
            case .store:
                if [.pactErrand, .wonderCompass, .location, .quip].contains(page.type) { delta += 4 }
            case .transit, .neighborhood:
                if [.wonderCompass, .location, .radio, .souvenir].contains(page.type) { delta += 4 }
            case .indoors:
                if [.enchantment, .illuminatedPhoto, .diary, .rest].contains(page.type) { delta += 3 }
            case .current, .other:
                break
            }
        }
        if mood.hasNearbyPlaces {
            switch page.type {
            case .location, .wonderCompass: delta += 4
            case .elective, .pactErrand, .wickerDare: delta += 3
            default: break
            }
            if page.payload.metadata["nearbyPlaces"]?.nonEmpty != nil {
                delta += 2
            }
        }
        if mood.hasNearbyAnchor {
            switch page.type {
            case .anchor: delta += 12
            case .location, .wonderCompass: delta += 5
            default: break
            }
        }

        if mood.upcomingCalendarEventCount > 0 {
            if page.type == .calendar { delta += 8 }
            if mood.upcomingCalendarEventCount >= 3 {
                let lightPages: Set<BookPageType> = [.calendar, .rest, .body, .fuel, .souvenir, .weather, .quip]
                let heavyPages: Set<BookPageType> = [.narrativeOS, .bookOfYou, .bookJump, .facultyResearch, .marginsAtlas]
                if lightPages.contains(page.type) { delta += 4 }
                if heavyPages.contains(page.type) { delta -= 4 }
            }
        }
        return delta
    }
}

/// Only answers the reader deliberately gave the Book enter this profile.
/// It translates a few known, bounded choices into curation pressure; freeform
/// autobiography remains story material rather than something the algorithm
/// pretends to understand perfectly.
struct ReaderDeclaredCurationProfile: Equatable {
    var leavingHome: String?
    var movementAccess: String?
    var timeBudget: String?
    var moneyBoundary: String?
    var desiredSurprise: String?
    var sensoryDoor: String?
    var favoriteWeather: String?
    var bestTime: String?
    var energyWindow: String?
    var socialEnergy: String?
    var favoritePlaceKind: String?
    var hardTransition: String?
    var wonderEntry: String?
    var onboardingRutContext: String?
    var onboardingAliveContext: String?
    var onboardingMagicSource: String?

    static let empty = ReaderDeclaredCurationProfile()

    static func make(from facts: [SelfFact]) -> ReaderDeclaredCurationProfile {
        func answer(_ questionID: String) -> String? {
            facts
                .filter { $0.questionID == questionID && $0.usePermission != .doNotUse }
                .max { $0.updatedAt < $1.updatedAt }?
                .answer
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .nonEmpty
        }
        return ReaderDeclaredCurationProfile(
            leavingHome: answer("leaving-home"),
            movementAccess: answer("movement-access"),
            timeBudget: answer("time-budget"),
            moneyBoundary: answer("money-boundary"),
            desiredSurprise: answer("desired-surprise"),
            sensoryDoor: answer("sensory-door"),
            favoriteWeather: answer("favorite-weather"),
            bestTime: answer("best-time"),
            energyWindow: answer("energy-window"),
            socialEnergy: answer("social-energy"),
            favoritePlaceKind: answer("favorite-kind-of-place"),
            hardTransition: answer("transition-hard"),
            wonderEntry: answer("wonder-entry"),
            onboardingRutContext: answer("onboarding-rut-strongest"),
            onboardingAliveContext: answer("onboarding-most-alive"),
            onboardingMagicSource: answer("onboarding-magic-source")
        )
    }
}

/// Explicit answers are meaningful votes, not permanent boxes. Strongly stated
/// access and spending edges get the largest pressure; tastes get a smaller
/// nudge and still leave room for surprise.
enum CuratorSelfKnowledgeAffinity {
    static func boost(for page: SurfacePage, mood: CuratorMood) -> Int {
        let profile = mood.declaredCuration
        let tags = Set(
            (page.payload.metadata["tags"] ?? "")
                .split(separator: ",")
                .map { String($0).readerLearningNormalizedTag }
                .filter { !$0.isEmpty }
        )
        let outwardTypes: Set<BookPageType> = [.anchor, .location, .pactErrand]
        let indoorTypes: Set<BookPageType> = [.rest, .diary, .enchantment, .illuminatedPhoto, .bookOfYou]
        let heavyTypes: Set<BookPageType> = [.narrativeOS, .bookJump, .facultyResearch, .marginsAtlas]
        let quickTypes: Set<BookPageType> = [.quip, .weather, .todaysSky, .souvenir, .rest, .aboutYou]
        var delta = 0

        if profile.leavingHome == "keep wonder indoors" {
            if indoorTypes.contains(page.type) { delta += 8 }
            if outwardTypes.contains(page.type) { delta -= 12 }
            if tags.contains("outward") || tags.contains("walking") || tags.contains("outing") { delta -= 18 }
        } else if profile.leavingHome == "only when i choose it" || profile.leavingHome == "ask gently" {
            if indoorTypes.contains(page.type) { delta += 2 }
            if outwardTypes.contains(page.type) { delta -= 3 }
            if tags.contains("outward") || tags.contains("walking") || tags.contains("outing") { delta -= 6 }
        }

        if let movementAccess = profile.movementAccess,
           ["short distances", "seated options", "no stairs"].contains(movementAccess) {
            if outwardTypes.contains(page.type) { delta -= 3 }
            if tags.contains("walking") || tags.contains("stairs") || tags.contains("long-distance") { delta -= 12 }
            if page.type == .rest || tags.contains("seated") { delta += 4 }
        }

        if profile.timeBudget == "one minute" || profile.timeBudget == "ten minutes" {
            if quickTypes.contains(page.type) { delta += 5 }
            if heavyTypes.contains(page.type) { delta -= 8 }
        }

        if profile.moneyBoundary == "free by default" || profile.moneyBoundary == "ask first" {
            if page.opensSpending
                || tags.contains("spend") || tags.contains("shopping")
                || tags.contains("purchase") || tags.contains("paid") {
                delta -= 14
            }
            if tags.contains("free") { delta += 4 }
        }

        switch profile.desiredSurprise {
        case "a strange fact":
            if [.lore, .quotes, .facultyResearch].contains(page.type) { delta += 4 }
        case "a beautiful place":
            if [.location, .wonderCompass, .weather, .illuminatedPhoto].contains(page.type) { delta += 4 }
        case "a joke":
            if page.type == .quip { delta += 6 }
        case "a message from someone":
            if [.letter, .radio].contains(page.type) { delta += 4 }
        case "a tiny challenge":
            if [.pactErrand, .wonderCompass, .wickerDare].contains(page.type) { delta += 4 }
        default:
            break
        }

        switch profile.sensoryDoor {
        case "sound":
            if page.type == .radio { delta += 4 }
        case "color":
            if [.illuminatedPhoto, .weather, .todaysSky].contains(page.type) { delta += 4 }
        case "texture":
            if [.souvenir, .enchantment].contains(page.type) { delta += 3 }
        case "movement":
            if [.wonderCompass, .anchor].contains(page.type) { delta += 3 }
        default:
            break
        }

        let favoriteWeatherTags = weatherTags(in: profile.favoriteWeather)
        if page.type == .weather, !tags.isDisjoint(with: favoriteWeatherTags) {
            delta += 4
        }

        if isReadersTime(profile.bestTime, hour: mood.hour) {
            if [.wonderCompass, .enchantment, .location, .souvenir].contains(page.type) { delta += 3 }
        }

        // The Inscription's three life questions are causal priors, not causal
        // proof. They tip early close calls toward the doors the reader named
        // while leaving every eligible Page a path to the desk. Later lived
        // outcomes can become stronger evidence; these answers remain the
        // reader's revisable editorial hand.
        delta += onboardingAliveBoost(
            for: page,
            answer: profile.onboardingAliveContext
        )
        delta += onboardingMagicBoost(
            for: page,
            answer: profile.onboardingMagicSource,
            pageTags: tags,
            weatherTags: mood.weatherContextTags
        )
        delta += onboardingRutFit(
            for: page,
            answer: profile.onboardingRutContext
        )

        switch profile.socialEnergy {
        case "usually alone":
            if [.rest, .diary, .souvenir, .wonderCompass].contains(page.type) { delta += 3 }
            if tags.contains("requires-company") { delta -= 8 }
        case "with one person":
            if [.letter, .castBond, .wonderCompass, .souvenir].contains(page.type) { delta += 3 }
        case "with a small group":
            if [.supportGuild, .wonderCompass, .pactErrand].contains(page.type) { delta += 3 }
        default:
            break
        }

        if let favoritePlaceKind = profile.favoritePlaceKind {
            let placeWords = Set(
                favoritePlaceKind
                    .split(whereSeparator: { !$0.isLetter })
                    .map { String($0).readerLearningNormalizedTag }
            )
            if [.location, .anchor, .wonderCompass, .weather].contains(page.type),
               !tags.isDisjoint(with: placeWords) {
                delta += 4
            }
        }

        if profile.hardTransition != nil {
            // Knowing a transition is difficult should make the Book smaller
            // and more immediately usable, never more demanding.
            if quickTypes.contains(page.type) { delta += 2 }
            if heavyTypes.contains(page.type) { delta -= 3 }
        }
        return delta
    }

    private static func onboardingAliveBoost(
        for page: SurfacePage,
        answer: String?
    ) -> Int {
        switch answer {
        case "making something":
            return [.enchantment, .illuminatedPhoto, .plainPage, .souvenir].contains(page.type) ? 5 : 0
        case "outside somewhere":
            return [.wonderCompass, .location, .anchor, .weather, .todaysSky].contains(page.type) ? 5 : 0
        case "with people i love":
            return [.letter, .castBond, .supportGuild, .radio, .gossip].contains(page.type) ? 5 : 0
        case "moving my body":
            return [.wonderCompass, .anchor, .location].contains(page.type) ? 5 : 0
        case "learning something":
            return [.lore, .quotes, .facultyResearch, .theBleed].contains(page.type) ? 5 : 0
        case "alone and unhurried":
            return [.rest, .diary, .souvenir, .weather].contains(page.type) ? 5 : 0
        case "helping someone":
            return [.supportGuild, .letter, .pactErrand, .castBond].contains(page.type) ? 5 : 0
        case "lost in a story":
            return [.narrativeOS, .bookFae, .lore, .bookJump].contains(page.type) ? 5 : 0
        default:
            return 0
        }
    }

    private static func onboardingMagicBoost(
        for page: SurfacePage,
        answer: String?,
        pageTags: Set<String>,
        weatherTags: Set<String>
    ) -> Int {
        switch answer {
        case "music landing just right":
            return page.type == .radio ? 7 : 0
        case "wild weather":
            var value = [.weather, .todaysSky, .wonderCompass, .enchantment, .radio].contains(page.type) ? 6 : 0
            if !pageTags.isDisjoint(with: weatherTags) { value += 5 }
            return value
        case "places with a charge":
            return [.location, .anchor, .wonderCompass, .enchantment].contains(page.type) ? 6 : 0
        case "strange coincidences":
            return [.bookConnections, .bookNotices, .theBleed, .lore].contains(page.type) ? 6 : 0
        case "tiny beautiful details":
            return [.wonderCompass, .illuminatedPhoto, .souvenir, .bookNotices].contains(page.type) ? 6 : 0
        case "making someone laugh":
            return [.quip, .letter, .radio, .gossip].contains(page.type) ? 6 : 0
        case "dreams and imagination":
            return [.narrativeOS, .bookFae, .illustration, .lore].contains(page.type) ? 6 : 0
        case "people i love":
            return [.letter, .castBond, .supportGuild, .souvenir].contains(page.type) ? 6 : 0
        default:
            return 0
        }
    }

    private static func onboardingRutFit(
        for page: SurfacePage,
        answer: String?
    ) -> Int {
        switch answer {
        case "work swallows the day":
            if [.quip, .rest, .souvenir, .wonderCompass].contains(page.type) { return 3 }
            if [.facultyResearch, .bookOfYou].contains(page.type) { return -2 }
        case "my phone eats the edges":
            return [.wonderCompass, .todaysSky, .weather, .location].contains(page.type) ? 3 : 0
        case "chores all blur together":
            return [.enchantment, .quip, .souvenir, .wonderCompass].contains(page.type) ? 3 : 0
        case "i'm tired before i begin":
            if [.rest, .weather, .quip, .souvenir].contains(page.type) { return 4 }
            if [.bookJump, .facultyResearch, .marginsAtlas].contains(page.type) { return -4 }
        case "my days feel the same":
            return [.wonderCompass, .enchantment, .quip, .bookNotices].contains(page.type) ? 3 : 0
        case "i keep waiting for later":
            return [.wonderCompass, .souvenir, .enchantment].contains(page.type) ? 3 : 0
        default:
            break
        }
        return 0
    }

    private static func weatherTags(in answer: String?) -> Set<String> {
        guard let answer else { return [] }
        var tags: Set<String> = []
        if answer.contains("rain") { tags.insert("rain") }
        if answer.contains("thunder") || answer.contains("storm") { tags.insert("storm") }
        if answer.contains("snow") { tags.insert("snow") }
        if answer.contains("fog") || answer.contains("mist") { tags.insert("fog") }
        if answer.contains("sun") { tags.insert("sun") }
        if answer.contains("wind") { tags.insert("wind") }
        return tags
    }

    private static func isReadersTime(_ answer: String?, hour: Int) -> Bool {
        switch answer {
        case "early morning": return (5..<10).contains(hour)
        case "the middle of the day": return (11..<15).contains(hour)
        case "dusk": return (17..<21).contains(hour)
        case "late night": return hour >= 21 || hour < 2
        default: return false
        }
    }
}

/// Everything the curator should feel before ranking: the clock, the
/// narrative temperature, what was recently served, and the shape of the
/// real day outside the Book.
enum CuratorReaderStateAffinity {
    static func boost(
        for page: SurfacePage,
        state: ReaderCurrentState,
        reading: ReaderReenchantmentMetrics
    ) -> Int {
        var delta = 0

        if let capacity = state.capacity {
            let lightDoors: Set<BookPageType> = [
                .rest, .weather, .todaysSky, .quip, .souvenir, .aboutYou
            ]
            let longDoors: Set<BookPageType> = [
                .narrativeOS, .bookJump, .facultyResearch, .bookConnections,
                .marginsAtlas, .supportGuild, .bookOfYou
            ]
            if capacity <= 3 {
                if lightDoors.contains(page.type) { delta += 7 }
                if longDoors.contains(page.type) { delta -= 10 }
            } else if capacity >= 8, longDoors.contains(page.type) {
                delta += 4
            }
        }

        if let aliveness = state.aliveness {
            if aliveness <= 3 {
                if [.rest, .mood, .weather, .radio].contains(page.type) { delta += 5 }
                if [.wonderCompass, .todaysSky, .enchantment, .quip].contains(page.type) { delta += 3 }
            } else if aliveness >= 8,
                      [.wonderCompass, .location, .narrativeOS, .letter, .souvenir].contains(page.type) {
                delta += 4
            }
        }

        if let wonder = state.wonder {
            if wonder <= 3,
               [.weather, .location, .todaysSky, .wonderCompass, .enchantment, .quip].contains(page.type) {
                // When wonder is scarce, prefer doors with something concrete
                // outside the reader rather than another abstract diagnosis.
                delta += 6
            } else if wonder >= 8,
                      [.souvenir, .diary, .narrativeOS, .bookOfYou, .illustration].contains(page.type) {
                delta += 4
            }
        }

        if let hiddenMagic = state.hiddenMagic, hiddenMagic >= 7,
           [.souvenir, .diary, .illustration, .bookNotices, .bookRemembered].contains(page.type) {
            delta += 4
        }

        switch reading.direction {
        case .dimming:
            if [.wonderCompass, .weather, .todaysSky, .location, .enchantment, .quip].contains(page.type) {
                delta += 6
            }
            if [.bookConnections, .marginsAtlas, .facultyResearch].contains(page.type) {
                delta -= 5
            }
        case .holding:
            if [.bookRemembered, .souvenir, .wonderCompass].contains(page.type) {
                delta += 3
            }
        case .brightening:
            if [.wonderCompass, .location, .letter, .souvenir, .narrativeOS].contains(page.type) {
                delta += 4
            }
        case .notEnoughEvidence:
            break
        }
        return delta
    }
}

struct CuratorMood {
    var hour: Int = 12
    var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
    var narrativeHeat: Int = 0
    var hasFreshEntityMemory: Bool = false
    var minutesToNextCalendarEvent: Int?
    var upcomingCalendarEventCount: Int = 0
    var hasWeatherContext = false
    var weatherContextTags: Set<String> = []
    var hasCoarseLocationContext = false
    var currentPlaceContext: CompassPlaceContext?
    var hasNearbyPlaces = false
    var hasNearbyAnchor = false
    var distressActive: Bool = false
    var greyLevel: Int = 0
    /// Routine is presumed to be ordinary weather. This pressure can shape the
    /// desk silently even when there is not enough evidence to warn the reader.
    var rutPressure: Int = 0
    var mayNameRut: Bool = false
    var reshelvedSourceIDs: Set<String> = []
    var pactWar: PactWarState = PactWarState()
    var almanacBoosts: [BookPageType: Int] = [:]
    var isFirstHours: Bool = false
    var keptPageCount: Int = 0
    var composedTypesToday: Set<BookPageType> = []
    /// The reader's role, composed with their epithet and hands. Curation
    /// weight is the role plus the hands: what draws them, and what they do
    /// about it once they have it, so the hands question the Book asks during
    /// onboarding changes the desk rather than only the prose.
    var readerRole: ComposedRole?
    var rutWonderEntry: String?
    var onboardingTaste: String?
    var onboardingChapter: String?
    var onboardingComfort: String?
    var declaredCuration: ReaderDeclaredCurationProfile = .empty
    var readerCurrentState: ReaderCurrentState = .unknown
    var readerReenchantmentReading: ReaderReenchantmentMetrics = .unwritten

    static let neutral = CuratorMood()

    static func make(inputs: BookSourceInputs, distressActive: Bool = false, now: Date = Date(), calendar: Calendar = .current) -> CuratorMood {
        let recentEvents = (inputs.narrative?.recentEventCount ?? 0)
        let freshMemory = (inputs.narrative?.entityMemories ?? [])
            .contains { now.timeIntervalSince($0.createdAt) < 48 * 3600 }
        let nextEventMinutes = inputs.calendarEvents
            .filter { !$0.isAllDay && $0.startsAt > now }
            .map { Int($0.startsAt.timeIntervalSince(now) / 60) }
            .min()
        let upcomingEventCount = inputs.calendarEvents.filter {
            !$0.isAllDay
                && $0.startsAt > now
                && $0.startsAt <= now.addingTimeInterval(12 * 3600)
        }.count
        let weatherTags = Set(
            RadioPageContext.weatherTags(
                weather: inputs.weather,
                enchanted: inputs.enchantedWeather
            ).map(\.readerLearningNormalizedTag)
        )
        let rut = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: distressActive,
            now: now,
            calendar: calendar
        )
        let storyGrey = NothingTide.greyLevel(
            readerRutPressure: rut.mayNameRut ? rut.pressure : 0,
            narrativeHeat: recentEvents,
            distressActive: distressActive,
            celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: inputs.hemisphere)
                + BookJumpEngine.greyShift(state: inputs.bookJump, now: now)
                + RadioStationRegistry.greyShift(state: inputs.radio, now: now)
                + (inputs.faeState.activeGifts.contains { $0.effect == .quieting } ? -1 : 0)
                + inputs.nothingGreyOffset
        )
        return CuratorMood(
            hour: calendar.component(.hour, from: now),
            surfaceHistory: inputs.surfaceHistory,
            narrativeHeat: recentEvents,
            hasFreshEntityMemory: freshMemory,
            minutesToNextCalendarEvent: nextEventMinutes,
            upcomingCalendarEventCount: upcomingEventCount,
            hasWeatherContext: inputs.weather != nil || inputs.enchantedWeather != nil,
            weatherContextTags: weatherTags,
            hasCoarseLocationContext: inputs.currentLocationLabel?.nonEmpty != nil,
            currentPlaceContext: inputs.currentPlaceContext,
            hasNearbyPlaces: !inputs.nearbyPlaces.isEmpty,
            hasNearbyAnchor: inputs.nearbyAnchor != nil,
            distressActive: distressActive,
            greyLevel: storyGrey,
            rutPressure: rut.pressure,
            mayNameRut: rut.mayNameRut,
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
            composedTypesToday: composedCompositionTypes(in: inputs.days, on: now, calendar: calendar),
            readerRole: ReaderRoleRegistry.currentRole(from: inputs.selfFacts),
            rutWonderEntry: onboardingAnswer("wonder-entry", in: inputs.selfFacts),
            onboardingTaste: onboardingAnswer("onboarding-taste", in: inputs.selfFacts),
            onboardingChapter: onboardingAnswer("onboarding-drawn-chapter", in: inputs.selfFacts),
            onboardingComfort: onboardingAnswer("onboarding-comfort-boundary", in: inputs.selfFacts),
            declaredCuration: ReaderDeclaredCurationProfile.make(from: inputs.selfFacts),
            readerCurrentState: inputs.readerStatePulses.currentState(now: now),
            readerReenchantmentReading: ReaderReenchantmentMeasure.reading(
                pulses: inputs.readerStatePulses,
                aliveness: inputs.readerAliveness,
                longGame: inputs.bookInterior.longGame,
                learning: inputs.readerLearning,
                days: inputs.days,
                now: now,
                calendar: calendar
            )
        )
    }

    private static func onboardingAnswer(_ questionID: String, in facts: [SelfFact]) -> String? {
        facts.first {
            $0.questionID == questionID && $0.usePermission != .doNotUse
        }?.answer.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// Which blank-page prompts the reader has already answered today, so the
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
        if RutInterventionPolicy.namesTheRut(page), !mayNameRut {
            return false
        }
        if IntroductionCurriculum.locks(page.type, keptPageCount: keptPageCount, surfaceHistory: surfaceHistory) {
            // The First Reading is a deliberately early Book Notices milestone:
            // it fires at three kept pages as proof the Book has started reading
            // back, while ordinary Book Notices still wait for the stage-2 door.
            if page.payload.metadata["firstReading"] == "true" {
                return true
            }
            // A jump already in motion is a continuation, not a debut.
            let isActiveJump = page.type == .bookJump
                && page.payload.metadata["bookJumpAction"] != BookJumpAction.start.rawValue
                && page.payload.metadata["bookJumpAction"] != nil
            // World events run on real, limited dates: the season's front
            // door must not wait for a stage a new reader can't reach in time.
            let isWorldEventDoor = page.sourceID == "world-event-door"
            if !isActiveJump && !isWorldEventDoor { return false }
        }
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
        let cooldown = Self.slowDeskTypes.contains(page.type)
            ? Self.slowDeskRefreshCooldown
            : Self.typeRefreshCooldown
        return now.timeIntervalSince(record.lastShownAt) >= cooldown
    }

    func adjustment(for page: SurfacePage, now: Date = Date()) -> Int {
        // When the day is hard, the Book goes quiet: no ambiance, no
        // variety games: the distress-aware base scores choose care first.
        if distressActive {
            return 0
        }
        var delta = CuratorTimeAffinity.boost(for: page.type, at: now)
        delta += CuratorWorldContextAffinity.boost(for: page, mood: self)
        delta += CuratorSelfKnowledgeAffinity.boost(for: page, mood: self)
        delta += CuratorReaderStateAffinity.boost(
            for: page,
            state: readerCurrentState,
            reading: readerReenchantmentReading
        )

        if isFirstHours {
            delta += Self.firstHoursOrientationBoosts[page.type] ?? 0
        }

        // A staged family's very first appearance leans forward, so a stage
        // unlock is felt soon after it is earned rather than lost in the rank.
        if IntroductionCurriculum.isManagedDebut(page.type, surfaceHistory: surfaceHistory),
           !IntroductionCurriculum.locks(page.type, keptPageCount: keptPageCount, surfaceHistory: surfaceHistory) {
            delta += 10
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
        delta += ReaderRoleRegistry.scoreBoost(for: page, role: readerRole)
        delta += InscriptionCurationAffinity.boost(
            for: page,
            taste: onboardingTaste,
            chapter: onboardingChapter,
            comfort: onboardingComfort
        )
        delta += RutInterventionPolicy.scoreBoost(
            for: page,
            pressure: rutPressure,
            preferredDoor: rutWonderEntry
        )

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

        // The Rut's tide: when the grey is up, its pages step forward
        // and material-gathering pages get a small lantern. At grey zero
        // Routine pages stay in the deep stacks: reward by absence.
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
    private static let slowDeskRefreshCooldown: TimeInterval = 72 * 3600
    static let slowDeskTypes: Set<BookPageType> = [.radio, .inventory, .helpTips, .patreon, .quip]

    private static let firstHoursHiddenTypes: Set<BookPageType> = [
        .faeBargain,
        .bookRemembered,
        .bookConnections,
        .marginsAtlas,
        .theBleed,
        .bookJump,
        .pactDispatch,
        .pactVerdict,
        .pactErrand,
        .wickerDare
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

/// The curator fights Routine mainly by changing what it offers, not by
/// repeatedly telling the reader they are in trouble. Naming Pages require
/// corroboration; small doors into attention get a standing quiet advantage.
enum RutInterventionPolicy {
    private static let namingArchetypes: Set<String> = [
        "the-nothing-stirs", "grey-margin"
    ]

    static func namesTheRut(_ page: SurfacePage) -> Bool {
        guard let id = page.payload.metadata["packArchetypeID"] else { return false }
        return namingArchetypes.contains(id)
    }

    static func scoreBoost(
        for page: SurfacePage,
        pressure: Int,
        preferredDoor: String? = nil
    ) -> Int {
        guard pressure > 0 else { return 0 }
        if namesTheRut(page) {
            return pressure >= 2 ? 4 + pressure * 2 : 0
        }
        var isPerspectiveDoor = page.type == .wonderCompass
            || page.type == .anchor
            || page.type == .quip
            || page.type == .todaysSky
            || page.type == .enchantment
            || page.payload.metadata["playfulMissionID"]?.nonEmpty != nil
            || page.payload.metadata["variant"] == "grey-edge"
        let preference = preferredDoor?.lowercased() ?? ""
        let matchesPreferredDoor: Bool
        if preference.contains("pocket") || preference.contains("adventure") {
            matchesPreferredDoor = page.type == .anchor || page.type == .wonderCompass
        } else if preference.contains("making") || preference.contains("make") {
            matchesPreferredDoor = page.type == .enchantment || page.type == .wonderCompass
        } else if preference.contains("people") {
            matchesPreferredDoor = page.type == .letter || page.type == .castBond
        } else if preference.contains("color") {
            matchesPreferredDoor = page.type == .enchantment || page.type == .todaysSky || page.type == .wonderCompass
        } else if preference.contains("quiet") || preference.contains("looking out") {
            matchesPreferredDoor = page.type == .todaysSky || page.type == .anchor || page.type == .wonderCompass
        } else if preference.contains("odd") || preference.contains("detail") {
            matchesPreferredDoor = page.type == .quip || page.type == .wonderCompass
        } else {
            matchesPreferredDoor = false
        }
        isPerspectiveDoor = isPerspectiveDoor || matchesPreferredDoor
        guard isPerspectiveDoor else { return 0 }
        return min(12, 2 + pressure * 2 + (matchesPreferredDoor ? 3 : 0))
    }
}
