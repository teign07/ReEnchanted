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
        reason: String = "The Book has a little room for this page.",
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
        case .body, .fuel, .facultyResearch, .supportGuild, .weather, .note, .letter, .academyClass, .bookConnections, .bookNotices, .glowInvitation, .theBleed, .todaysSky, .bookJump, .radio, .inventory, .gamePage:
            return .reflect
        case .elective:
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
        case .illuminatedPhoto, .bookRemembered, .bookPocket:
            return .resurface
        case .location:
            return .reflect
        case .narrativeOS:
            return .simulate
        case .gossip:
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

extension SurfacePage {
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

struct HiddenMagicAttentionProfile: Equatable {
    var findingPages: [BookPage]
    var countsBySense: [HiddenMagicSense: Int]
    var distinctDayCount: Int

    static func make(days: [BookDay], calendar: Calendar = .current) -> HiddenMagicAttentionProfile {
        let pages = days
            .flatMap(\.capturedPages)
            .filter { $0.hiddenMagicFinding != nil }
            .sorted { $0.createdAt < $1.createdAt }
        var counts: [HiddenMagicSense: Int] = [:]
        for page in pages {
            if let sense = page.hiddenMagicFinding?.sense {
                counts[sense, default: 0] += 1
            }
        }
        let dayIDs = Set(pages.map { BookDay.id(for: $0.createdAt, calendar: calendar) })
        return HiddenMagicAttentionProfile(
            findingPages: pages,
            countsBySense: counts,
            distinctDayCount: dayIDs.count
        )
    }

    func count(for sense: HiddenMagicSense) -> Int {
        countsBySense[sense, default: 0]
    }

    var dominantSense: HiddenMagicSense? {
        countsBySense.max { left, right in
            if left.value == right.value { return left.key.rawValue > right.key.rawValue }
            return left.value < right.value
        }?.key
    }

    /// A gentle stretch, never a corrective verdict: among the senses the
    /// current Page knows how to teach, prefer the one the archive has practiced
    /// least. Stable tie-breaking prevents refresh jitter.
    func leastPracticed(in senses: [HiddenMagicSense], seed: String) -> HiddenMagicSense? {
        senses.min { left, right in
            let leftCount = count(for: left)
            let rightCount = count(for: right)
            if leftCount == rightCount {
                return abs("\(seed):\(left.rawValue)".stableHash) < abs("\(seed):\(right.rawValue)".stableHash)
            }
            return leftCount < rightCount
        }
    }

    var wayOfSeeing: HiddenMagicWayOfSeeing? {
        guard findingPages.count >= 4,
              distinctDayCount >= 2,
              let sense = dominantSense else { return nil }
        let count = count(for: sense)
        guard count >= 2 else { return nil }
        let tier = count >= 8 ? 3 : (count >= 5 ? 2 : 1)
        let evidence = findingPages
            .filter { $0.hiddenMagicFinding?.sense == sense }
            .suffix(3)
        guard evidence.count >= 2 else { return nil }
        let language: (title: String, claim: String, question: String)
        switch sense {
        case .sight:
            language = ("The Eye for Small Light", "You keep finding meaning in color, edges, reflections, shadows, and small arrangements before you explain the scene.", "Does sight really lead the way when hidden magic finds you?")
        case .sound:
            language = ("The Ear Under the Room", "You keep hearing the quiet layer beneath the obvious one: hums, refrains, rhythms, and sounds other people might leave in the background.", "Is listening one of the ways you make an ordinary place come alive?")
        case .touch:
            language = ("The Hand That Checks", "Texture, temperature, weight, and physical borders keep becoming evidence in your pages.", "Do you understand a moment more fully once your hands have met it?")
        case .scent:
            language = ("The Weather in the Air", "You keep using scent as a doorway into weather, place, food, and memory.", "Does scent open a place for you before words do?")
        case .taste:
            language = ("The Patient First Bite", "You keep finding time, travel, and detail inside ordinary food and drink.", "Is taste becoming one of your quickest routes back into the present?")
        case .body:
            language = ("The Body's Marginalia", "You keep noticing the body's small reports before turning them into scores or explanations.", "Does your body often notice the day before the rest of the Book does?")
        case .weather:
            language = ("The Reader of Weather", "Weather keeps becoming more than forecast in your pages: it changes light, sound, air, thresholds, and the shape of attention.", "Does weather genuinely change what becomes visible to you?")
        case .place:
            language = ("The Private Landmark", "You keep identifying the small clue that makes one place itself and nowhere else.", "Do places become memorable for you through their overlooked details?")
        case .people:
            language = ("The Borrowed Eye", "You keep noticing hands, voices, skills, refrains, and the things another person's attention chooses first.", "Is other people's way of noticing part of what makes the world larger for you?")
        case .kindness:
            language = ("The Evidence of Care", "You keep finding—or leaving—small signs that somebody made an ordinary passage easier for somebody else.", "Is quiet care one of the forms hidden magic takes most often in your life?")
        case .time:
            language = ("The Keeper of Traces", "You keep reading wear, repair, age, change, and leftovers as evidence that time passed through a thing.", "Do traces of time reliably catch your attention?")
        case .imagination:
            language = ("The Second Life of Things", "Ordinary objects keep suggesting voices, roles, motives, and secret jobs when you look at them.", "Does imagination help you see more of what is really there, rather than less?")
        }
        return HiddenMagicWayOfSeeing(
            sense: sense,
            tier: tier,
            title: language.title,
            claim: language.claim,
            question: language.question,
            evidencePages: Array(evidence)
        )
    }
}

struct HiddenMagicWayOfSeeing: Equatable {
    var sense: HiddenMagicSense
    var tier: Int
    var title: String
    var claim: String
    var question: String
    var evidencePages: [BookPage]

    var observationKey: String {
        "ways-of-seeing:\(sense.rawValue):tier-\(tier)"
    }
}

enum HiddenMagicPractice {
    private struct Variant {
        var sense: HiddenMagicSense
        var voice: String
        var action: String
        var proof: String
        var duration: Int = 60
        var modes: [HiddenMagicExpressionMode] = [.words, .photograph, .voice]
    }

    static func lens(from metadata: [String: String]) -> HiddenMagicLens? {
        guard metadata["hiddenMagicLens"] == "true",
              let id = metadata["hiddenMagicLensID"]?.nonEmpty,
              let senseRaw = metadata["hiddenMagicSense"],
              let sense = HiddenMagicSense(rawValue: senseRaw),
              let action = metadata["hiddenMagicAction"]?.nonEmpty,
              let proof = metadata["hiddenMagicProofPrompt"]?.nonEmpty else {
            return nil
        }
        let modes = metadata["hiddenMagicExpressionModes", default: "words,photograph,voice"]
            .split(separator: ",")
            .compactMap { HiddenMagicExpressionMode(rawValue: String($0)) }
        return HiddenMagicLens(
            id: id,
            sense: sense,
            voice: metadata["hiddenMagicVoice"]?.nonEmpty ?? "The Book lends you a lens",
            action: action,
            proofPrompt: proof,
            durationSeconds: Int(metadata["hiddenMagicDurationSeconds"] ?? "60") ?? 60,
            expressionModes: modes.isEmpty ? [.words] : modes
        )
    }

    static func lens(for surface: SurfacePage) -> HiddenMagicLens? {
        lens(from: surface.payload.metadata)
    }

    static func decorating(
        _ surface: SurfacePage,
        days: [BookDay],
        now: Date = Date()
    ) -> SurfacePage {
        guard surface.payload.metadata["keptPage"] != "true" else { return surface }
        if lens(for: surface) != nil { return surface }
        let profile = HiddenMagicAttentionProfile.make(days: days)
        guard let lens = proposedLens(for: surface, profile: profile, now: now) else { return surface }
        return surface.withMetadata(metadata(for: lens))
    }

    static func markingTaken(_ surface: SurfacePage) -> SurfacePage {
        guard lens(for: surface) != nil else { return surface }
        return surface.withMetadata(["hiddenMagicLensTaken": "true"])
    }

    static func finding(
        for surface: SurfacePage,
        input: String,
        media: [BookPageMediaAsset],
        now: Date = Date()
    ) -> HiddenMagicFinding? {
        guard let lens = lens(for: surface),
              surface.payload.metadata["hiddenMagicLensTaken"] == "true" else {
            return nil
        }
        let hasWords = input.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil
        let hasPhoto = media.contains { asset in
            switch asset.kind {
            case .bundledImage, .renderedImageFile, .photoLibraryAsset: return true
            case .audioFile: return false
            }
        }
        let hasVoice = media.contains { $0.kind == .audioFile }
        guard hasWords || hasPhoto || hasVoice else { return nil }
        var used: [HiddenMagicExpressionMode] = []
        if hasWords { used.append(.words) }
        if hasPhoto { used.append(.photograph) }
        if hasVoice { used.append(.voice) }
        return HiddenMagicFinding(
            lensID: lens.id,
            sense: lens.sense,
            action: lens.action,
            proofPrompt: lens.proofPrompt,
            expressionModes: used,
            foundAt: now
        )
    }

    static func receiptLine(for page: BookPage) -> String? {
        guard let finding = page.hiddenMagicFinding else { return nil }
        let proof = page.archivePreviewText?.bookPreviewSentenceLimit(1).nonEmpty
        if let proof {
            return "You found it through \(finding.sense.title.lowercased()): \(proof)"
        }
        if finding.expressionModes.contains(.photograph) {
            return "You found it through \(finding.sense.title.lowercased()) and kept the photograph as proof."
        }
        if finding.expressionModes.contains(.voice) {
            return "You found it through \(finding.sense.title.lowercased()) and kept it in your own voice."
        }
        return "You found it."
    }

    private static func metadata(for lens: HiddenMagicLens) -> [String: String] {
        [
            "hiddenMagicLens": "true",
            "hiddenMagicLensID": lens.id,
            "hiddenMagicSense": lens.sense.rawValue,
            "hiddenMagicVoice": lens.voice,
            "hiddenMagicAction": lens.action,
            "hiddenMagicProofPrompt": lens.proofPrompt,
            "hiddenMagicDurationSeconds": String(lens.durationSeconds),
            "hiddenMagicExpressionModes": lens.expressionModes.map(\.rawValue).joined(separator: ",")
        ]
    }

    private static func proposedLens(
        for surface: SurfacePage,
        profile: HiddenMagicAttentionProfile,
        now: Date
    ) -> HiddenMagicLens? {
        if surface.type == .wonderCompass,
           surface.payload.metadata["playfulMissionID"] != nil {
            let sense = inferredSense(from: surface.payload.metadata["tags", default: ""])
            let modes: [HiddenMagicExpressionMode] = surface.payload.metadata["proofKind"] == "sentence-or-photo"
                ? [.words, .photograph, .voice]
                : [.words, .voice]
            return HiddenMagicLens(
                id: "compass:\(surface.payload.metadata["playfulMissionID"] ?? surface.id)",
                sense: sense,
                voice: "South lends you a lens",
                action: surface.payload.metadata["mission"]?.nonEmpty ?? surface.detail,
                proofPrompt: surface.payload.metadata["souvenirPrompt"]?.nonEmpty ?? "Keep one exact thing you found.",
                durationSeconds: 180,
                expressionModes: modes
            )
        }

        let variants = variants(for: surface)
        guard !variants.isEmpty,
              let sense = profile.leastPracticed(in: variants.map(\.sense), seed: surface.id),
              let selected = variants.first(where: { $0.sense == sense }) else {
            return nil
        }
        return HiddenMagicLens(
            id: "\(surface.type.rawValue):\(selected.sense.rawValue):\(abs(surface.sourceID.stableHash))",
            sense: selected.sense,
            voice: selected.voice,
            action: selected.action,
            proofPrompt: selected.proof,
            durationSeconds: selected.duration,
            expressionModes: selected.modes
        )
    }

    private static func inferredSense(from tags: String) -> HiddenMagicSense {
        let tags = tags.lowercased()
        if tags.contains("people") || tags.contains("connection") { return .people }
        if tags.contains("kindness") || tags.contains("shared-wonder") { return .kindness }
        if tags.contains("sound") { return .sound }
        if tags.contains("scent") { return .scent }
        if tags.contains("taste") || tags.contains("fuel") { return .taste }
        if tags.contains("touch") || tags.contains("texture") { return .touch }
        if tags.contains("body") { return .body }
        if tags.contains("weather") || tags.contains("moon") || tags.contains("sky") { return .weather }
        if tags.contains("place") || tags.contains("outside") { return .place }
        if tags.contains("history") || tags.contains("old") { return .time }
        if tags.contains("imagination") || tags.contains("character") { return .imagination }
        return .sight
    }

    private static func variants(for surface: SurfacePage) -> [Variant] {
        switch surface.type {
        case .souvenir:
            return [
                Variant(sense: .sight, voice: "The Souvenir page looks up", action: "Look away from the Book. Find the smallest visible detail from today that would disappear in a summary.", proof: "Keep the detail in one sentence, photograph, or spoken line."),
                Variant(sense: .sound, voice: "The Souvenir page listens", action: "Be still until one sound from this exact moment separates itself from the background.", proof: "Keep the sound in your own words or voice."),
                Variant(sense: .time, voice: "The Souvenir page catches the day", action: "Find one ordinary thing near you that proves this particular day happened.", proof: "Keep what it proves before the day smooths over it.")
            ]
        case .diary:
            return [
                Variant(sense: .place, voice: "The diary opens a window", action: "Look at the room around you. Find one thing the events of today changed, moved, emptied, or left behind.", proof: "Begin with the changed thing, not a summary of the day."),
                Variant(sense: .sound, voice: "The diary lowers its voice", action: "Listen for the sound underneath your account of today: the machine, person, animal, or weather that was actually there.", proof: "Let that sound open the first true line."),
                Variant(sense: .touch, voice: "The diary asks for evidence", action: "Touch one safe object that traveled through today with you.", proof: "Keep what its surface remembers better than a timeline would.")
            ]
        case .mood:
            return [
                Variant(sense: .body, voice: "Inner Weather checks the instrument", action: "Take one unforced breath. Find the most specific place your mood has reached the body.", proof: "Name the place and the physical clue, without explaining it away.", modes: [.words, .voice]),
                Variant(sense: .weather, voice: "Inner Weather looks outside", action: "Find one piece of outer weather, light, or atmosphere that harmonizes with—or contradicts—your inner weather.", proof: "Keep the exact agreement or disagreement."),
                Variant(sense: .sight, voice: "Inner Weather borrows a color", action: "Look for the color in the room that feels closest to the present mood.", proof: "Keep the real color and where it was hiding.")
            ]
        case .body:
            return [
                Variant(sense: .body, voice: "The Body page listens before measuring", action: "Pause for one breath and find the body's clearest signal that is not a number.", proof: "Keep the signal in plain physical language.", modes: [.words, .voice]),
                Variant(sense: .touch, voice: "The Body page finds the border", action: "Notice the exact place your body meets a chair, floor, shoe, sleeve, or patch of air.", proof: "Keep the most specific border you found.", modes: [.words, .voice]),
                Variant(sense: .sound, voice: "The Body page listens inward", action: "Find one body sound or rhythm: breath, swallow, pulse, fabric, footfall.", proof: "Keep the rhythm without judging it.", modes: [.words, .voice])
            ]
        case .fuel:
            return [
                Variant(sense: .taste, voice: "The Fuel page slows one bite", action: "Give the next safe bite or sip five full seconds of attention before swallowing.", proof: "Keep three things that were actually in the taste.", modes: [.words, .voice]),
                Variant(sense: .scent, voice: "The Fuel page reads the air", action: "Smell the food or drink before tasting it. Make one prediction.", proof: "Keep the prediction and what the taste changed.", modes: [.words, .voice]),
                Variant(sense: .time, voice: "The Fuel page credits the journey", action: "Find the ingredient that took longest to grow, age, ferment, travel, or become ready.", proof: "Keep the ingredient and the time hidden inside it.")
            ]
        case .weather:
            return [
                Variant(sense: .weather, voice: "The Weather page opens the door", action: "Go to the nearest safe threshold and compare the air or light on its two sides.", proof: "Keep the first difference the forecast did not say."),
                Variant(sense: .sound, voice: "The Weather page listens past the forecast", action: "Find the smallest sound today's weather is making against a surface.", proof: "Keep the quiet weather-sound.", modes: [.words, .voice]),
                Variant(sense: .scent, voice: "The Weather page tests the air", action: "At a safe door or window, notice what the air smells like before naming the weather.", proof: "Keep the scent in concrete words.", modes: [.words, .voice])
            ]
        case .todaysSky:
            return [
                Variant(sense: .sight, voice: "Today's Sky asks for the real sky", action: "If it is safe and available, look at the actual sky until one color, edge, or depth contradicts the word 'sky.'", proof: "Keep the specific sky you saw."),
                Variant(sense: .weather, voice: "Today's Sky lowers to the horizon", action: "Find where the sky is touching a roof, tree, glass, hill, or artificial light.", proof: "Keep what happened at the edge."),
                Variant(sense: .time, voice: "Today's Sky keeps the hour", action: "Look for one clue in the light that tells the hour without a clock.", proof: "Keep the clue and the hour it suggested.")
            ]
        case .location:
            return [
                Variant(sense: .place, voice: "The Place page reads the ground", action: "Find one clue this place could not belong everywhere: a wear mark, local sound, material, sign, slope, or habit.", proof: "Keep the clue that makes here different from anywhere."),
                Variant(sense: .sound, voice: "The Place page closes its eyes", action: "Listen for the sound that gives this place away before sight does.", proof: "Keep the place's identifying sound.", modes: [.words, .voice]),
                Variant(sense: .sight, voice: "The Place page finds the overlooked landmark", action: "Find the smallest feature you could use to recognize this place on a future return.", proof: "Keep your private landmark.")
            ]
        case .anchor:
            let rule = surface.payload.metadata["anchorLocalRule"]?.nonEmpty
            return [
                Variant(sense: .place, voice: "The Outer Stacks open here", action: rule.map { "Enter this place by its own rule: \($0)" } ?? "Cross into this place slowly enough to notice what changes at its threshold.", proof: "Keep the clue that made this place become a room."),
                Variant(sense: .time, voice: "The Anchor remembers between visits", action: "Find one thing here that has changed since the last time—or one thing that has stubbornly refused to.", proof: "Keep the change or the refusal."),
                Variant(sense: .sight, voice: "The Anchor checks its edges", action: "Find the visible edge where this place seems to begin.", proof: "Keep the threshold you would draw on a secret map.")
            ]
        case .pactErrand:
            return [Variant(
                sense: inferredSense(from: surface.payload.metadata["tags", default: ""]),
                voice: "The errand crosses the binding",
                action: surface.detail.nonEmpty ?? surface.payload.body,
                proof: surface.payload.metadata["placeholder"]?.nonEmpty ?? "Keep the smallest observable result, including if nothing happened.",
                duration: 180,
                modes: [.words, .photograph, .voice]
            )]
        case .rest:
            return [
                Variant(sense: .touch, voice: "Rest notices what is holding you", action: "Let the nearest chair, bed, wall, floor, or patch of ground do all the holding for thirty seconds.", proof: "Keep one place it held you, or let the page remain quiet.", duration: 30, modes: [.words, .voice]),
                Variant(sense: .sound, voice: "Rest listens without hunting", action: "For thirty seconds, let sounds arrive without deciding which matters most.", proof: "Keep the last sound you remember, or leave the margin empty.", duration: 30, modes: [.words, .voice]),
                Variant(sense: .body, voice: "Rest gives the body the last word", action: "Stop adjusting for thirty seconds and notice what settles by itself.", proof: "Keep the settling only if a true line arrived.", duration: 30, modes: [.words, .voice])
            ]
        case .enchantment:
            return [
                Variant(sense: .sight, voice: "The Enchantment chooses a real subject", action: "Choose an ordinary subject you would normally pass without photographing. Give it the whole frame.", proof: "The photograph is proof; add one true line only if it wants one.", modes: [.photograph, .words, .voice]),
                Variant(sense: .imagination, voice: "The Enchantment asks what else is here", action: "Choose one ordinary subject and look until it begins suggesting a role, voice, mood, or secret job.", proof: "Keep the image and the first interpretation that surprised you.", modes: [.photograph, .words, .voice]),
                Variant(sense: .place, voice: "The Enchantment frames the background", action: "Photograph an ordinary subject together with the place that changes its meaning.", proof: "Keep the relationship between subject and place.", modes: [.photograph, .words, .voice])
            ]
        default:
            return []
        }
    }
}

extension SurfacePage {
    var hiddenMagicLens: HiddenMagicLens? {
        HiddenMagicPractice.lens(for: self)
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

/// From 8pm, the desk's evening resolution. On a day with kept pages it
/// teases the threads tonight's Book of You braid has already caught; on an
/// unwritten day it resolves the evening from the Book's own shelf instead —
/// rereading earlier days by lamplight, never counting what the reader owes.
/// Either way the reader gets a sanctioned ending without the braid's reveal
/// moving and without the desk going quiet.
enum BraidEmber {
    struct Ember: Equatable {
        enum Kind: Equatable {
            /// Two or three kept threads — tonight's braid is teased.
            case braid
            /// One kept thread — still enough to bind.
            case singleThread
            /// Nothing kept — the Book spends the evening on its own shelves.
            case lamplight
        }

        var kind: Kind
        var line: String
        var undertone: String
    }

    static let braidUndertone = "The Book of You braids tonight."
    static let lamplightUndertone = "Nothing owed. The Book is always ready to play."

    static let singleThreadLines = [
        "Tonight\u{2019}s braid holds a single thread: {thread}. One true thing is enough.",
        "One thread on the desk tonight \u{2014} {thread} \u{2014} and a whole braid to spin from it.",
        "Tonight\u{2019}s braid begins with {thread}. Small true things are load-bearing."
    ]

    /// Lamplight lines when one earlier day offers an echo.
    static let rereadLines = [
        "Today went straight to living \u{2014} the best chapters often do. I reread {echo} by lamplight; it still glows.",
        "Nothing crossed the desk today, so I took down {echo} and read it again. It holds.",
        "Today stayed in the Unwritten Chapter, where most good days live. {echo} kept me company.",
        "You gave the desk nothing today, and nothing was owed. I kept {echo} out on the stand anyway \u{2014} yours, waiting, glad of the company."
    ]

    /// Lamplight lines when two earlier days can be laid side by side.
    static let rhymeLines = [
        "Today went straight to living, so I read my own shelves: {echoA} laid beside {echoB}. They rhyme.",
        "The desk stayed clear today, so I shelved {echoA} next to {echoB}. Neighbors now.",
        "An unwritten day, so I visited old pages: {echoA} still glows, and {echoB} has not moved an inch.",
        "No ink today, and the Book kept your seat regardless: {echoA} beside {echoB}, both saved for whenever you next look."
    ]

    /// Lamplight lines when the archive has nothing to reread yet.
    static let hearthLines = [
        "Today went straight to living. The lamp is lit whenever you are.",
        "An unwritten day. Most good ones are. The shelf stays warm.",
        "No ink today, and no matter. The Book read by lamplight and left the door on the latch.",
        "Today asked nothing of you, and the Book chose you anyway. Lamp lit, door on the latch."
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
            return "Last night the braid held a single thread \u{2014} \(threads[0]). Here is what it made of it."
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
        let ranked = day.capturedPages.sorted {
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

/// Now and then — not every time — a page you swipe away leaves a little
/// something behind. A parting whisper from the Book: mostly a warm wink as the
/// page wanders off, and once in a rarer while, a keepsake that reads like it
/// slipped out of the page on its way to the stacks. Kept unpredictable on
/// purpose: often enough to be discovered, rare enough that it never becomes the
/// expected reply. Swiping still costs nothing — the whisper is pure delight.
enum PartingWhisper {
    /// The real thing a keepsake leaves behind: a small object the Book presses
    /// into its Pocket, where it stays. `object` names it for the collection;
    /// `glyph` is the SF Symbol the Pocket shows.
    struct Keepsake: Equatable {
        var object: String
        var glyph: String
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

    /// Roughly one swipe in six earns a whisper at all.
    static let whisperChance = 0.16
    /// Of those, a little under a third are the rarer keepsake — so a keepsake
    /// lands on about one swipe in twenty-two, and leaves a real object.
    static let keepsakeChance = 0.28

    /// `{page}` is filled with the page's short title, matching the mundane
    /// dismissal line's "the <kind> page" phrasing.
    static let winkLines = [
        "The {page} page tips its hat on the way out.",
        "Off it goes. The Book pretends not to watch the {page} page leave.",
        "The {page} page wanders back into the stacks, whistling.",
        "Gone \u{2014} but the {page} page left the door on the latch.",
        "The Book lets the {page} page go and keeps the spot warm with a thumb.",
        "The {page} page bows out. The margins hold its warmth a while.",
        "Away it drifts. The lamp leans after the {page} page, then settles.",
        "The {page} page slips off to nap in the stacks. The Book tucks it in."
    ]

    /// Each keepsake pairs the whispered line with the object it leaves in the
    /// Pocket and the glyph that stands for it.
    struct KeepsakeTemplate: Equatable {
        var line: String
        var object: String
        var glyph: String
    }

    static let keepsakeTemplates: [KeepsakeTemplate] = [
        KeepsakeTemplate(
            line: "The {page} page left a pressed petal in the gutter. The Book slips it into its Pocket.",
            object: "a pressed petal",
            glyph: "leaf"
        ),
        KeepsakeTemplate(
            line: "Something fell out of the {page} page as it went \u{2014} a single word, still warm. The Book pockets it.",
            object: "a still-warm word",
            glyph: "text.quote"
        ),
        KeepsakeTemplate(
            line: "The {page} page slipped away and left a coin of lamplight spinning on the desk. Into the Pocket it goes.",
            object: "a coin of lamplight",
            glyph: "sun.max"
        ),
        KeepsakeTemplate(
            line: "A loose thread came off the {page} page. The Book winds it round a finger and drops it in its Pocket.",
            object: "a loose gold thread",
            glyph: "scribble"
        ),
        KeepsakeTemplate(
            line: "The {page} page left a fingerprint of gold on the corner. The Book keeps it where only you will find it.",
            object: "a fingerprint of gold",
            glyph: "hand.point.up.left"
        ),
        KeepsakeTemplate(
            line: "On its way out, the {page} page whispered a rumor to the Book. The Book seals it in its Pocket \u{2014} unread, for now.",
            object: "a sealed rumor",
            glyph: "seal"
        )
    ]

    /// Weighty narrative and transactional cards keep their own partings, so the
    /// whisper stays out of their way.
    static let excludedTypes: Set<BookPageType> = [
        .bookOfYou, .faeBargain, .pactVerdict, .pactErrand, .pactDispatch, .welcome
    ]

    static func isEligible(_ surface: SurfacePage) -> Bool {
        if excludedTypes.contains(surface.type) { return false }
        if surface.payload.metadata["purchaseThankYou"] == "true" { return false }
        return true
    }

    /// Whether swiping `surface` away leaves a whisper, and which one. Draws its
    /// rolls from `generator`, so callers pass a live `SystemRandomNumberGenerator`
    /// for genuine unpredictability while tests inject a seeded one to pin the
    /// outcome.
    static func onDismiss<G: RandomNumberGenerator>(
        of surface: SurfacePage,
        whisperChance: Double = whisperChance,
        keepsakeChance: Double = keepsakeChance,
        using generator: inout G
    ) -> Whisper? {
        guard isEligible(surface) else { return nil }
        guard Double.random(in: 0..<1, using: &generator) < whisperChance else { return nil }

        let page = surface.type.shortTitle.lowercased()
        let isKeepsake = Double.random(in: 0..<1, using: &generator) < keepsakeChance
        if isKeepsake {
            let template = keepsakeTemplates[Int.random(in: 0..<keepsakeTemplates.count, using: &generator)]
            return Whisper(
                kind: .keepsake,
                line: template.line.replacingOccurrences(of: "{page}", with: page),
                keepsake: Keepsake(object: template.object, glyph: template.glyph)
            )
        }

        let line = winkLines[Int.random(in: 0..<winkLines.count, using: &generator)]
            .replacingOccurrences(of: "{page}", with: page)
        return Whisper(kind: .wink, line: line, keepsake: nil)
    }
}

/// One small thing a swiped-away page left behind, kept for good in the Book's
/// Pocket. Unlike a dismissed page (which can be called back), a keepsake is a
/// permanent trace — the consequence of letting pages go.
struct PocketKeepsake: Identifiable, Codable, Equatable {
    let id: String
    let dayID: String
    let pageType: BookPageType
    /// The short noun for the object, e.g. "a pressed petal".
    let object: String
    /// SF Symbol name shown beside it in the Pocket.
    let glyph: String
    let foundAt: Date
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

    /// Most recently found first — the order the Pocket shows.
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
        let rawCandidates = BookPageSourceAdapters.active.flatMap { adapter in
            adapter.candidates(for: day, context: context, inputs: inputs, now: now)
        }
        .map { WorldEventEffects.framed($0, events: inputs.activeWorldEvents) }
        .map { HiddenMagicPractice.decorating($0, days: inputs.days + [day], now: now) }
        let readableCandidates = rawCandidates.filter {
            BookObservationLedger.allows(
                $0,
                observations: inputs.bookObservations,
                boundaries: inputs.bookReadingBoundaries
            )
        }
        let candidates = MagicMomentGovernor.promotingEarnedReveal(
            in: readableCandidates,
            state: inputs.magicMoment
        )
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

        return picked
            .map { PactWarEffects.framed($0, state: inputs.pactWar) }
            .map { $0.withReaderLexiconLanguageLaw(inputs.readerLexicon) }
    }

    /// The slot a guaranteed injection (sovereign shelf, evening braid) may
    /// claim. Prefer a page already in the injected page's lane so the desk
    /// stays balanced; otherwise the last non-milestone, non-braid slot. Never
    /// returns a milestone slot — those are pinned and never evicted.
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
        // Three structural rules shape the desk, honored within rank order:
        //   1. Never repeat a source family — no two variants from the same
        //      preview system occupy the home shelf at once.
        //   2. Never repeat a kind of page — no two lore cards (or two of any
        //      type) on the shelf at once.
        //   3. Never stack blank-page "write one thing" prompts — at most one
        //      composition card (diary / souvenir / mood / about-you) at a time.
        // We would rather serve a shorter desk than break these rules.
        let deduped = unique(sortedPages)
        var picked: [SurfacePage] = []
        var pickedTypes: Set<BookPageType> = []
        var compositionCount = 0
        var debutCount = 0
        // One blank-page prompt per three-slot desk: the home shelf (limit 3)
        // shows at most one, while wider introspection queries still surface the
        // full set of composition cards.
        let compositionLimit = max(1, limit / 3)
        // Staged families debut one at a time on the desk, so an unlock is a
        // single felt reveal rather than a wall of novelty. Wider queries
        // (limit > 3) scale the allowance instead of starving.
        let debutLimit = max(1, limit / 3)

        func isDebut(_ page: SurfacePage) -> Bool {
            page.payload.metadata["firstReading"] == "true"
                ? false
                : IntroductionCurriculum.isManagedDebut(page.type, surfaceHistory: mood.surfaceHistory)
        }
        func canAdd(_ page: SurfacePage) -> Bool {
            guard picked.count < limit else { return false }
            guard !pickedTypes.contains(page.type) else { return false }
            if page.type.isCompositionPrompt, compositionCount >= compositionLimit { return false }
            if isDebut(page), debutCount >= debutLimit { return false }
            return true
        }
        func add(_ page: SurfacePage) {
            if isDebut(page) { debutCount += 1 }
            if page.type.isCompositionPrompt { compositionCount += 1 }
            picked.append(page)
            pickedTypes.insert(page.type)
        }

        // The home desk (limit 3) is balanced across three lanes so the loudest
        // world-sim pages can't take every slot: one page that reads the
        // reader's real life, one from the living Academy world, one from
        // everything else. Milestones are pinned above the lanes and never
        // evicted. Distress still shapes scoring and eligibility, but never
        // permits the world-sim to crowd the reader's real life off a complete
        // three-slot home desk. Wider introspection queries keep plain ranking.
        let laneBalanced = limit == 3
        if laneBalanced {
            // A reader who has deliberately poured Belief into a source has
            // asked to see it. Honor the strongest such request before lane
            // coverage, just as the pre-lane curator did.
            if let invested = deduped.first(where: {
                (preferences.pageBeliefProfiles[$0.sourceID]?.belief ?? 0) >= 80 && canAdd($0)
            }) {
                add(invested)
            }
            for page in deduped where page.isDeskMilestone && canAdd(page) { add(page) }
            for lane in DeskLane.allCases {
                guard picked.count < limit else { break }
                guard !picked.contains(where: { $0.type.deskLane == lane }) else { continue }
                if let page = deduped.first(where: { $0.type.deskLane == lane && canAdd($0) }) {
                    add(page)
                }
            }
            for page in deduped where canAdd(page) { add(page) }
            // Restore score order for display/stability; lane coverage is a
            // membership guarantee, not a reordering.
            let rank = Dictionary(uniqueKeysWithValues: deduped.enumerated().map { ($0.element.id, $0.offset) })
            picked.sort { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
        } else {
            for page in deduped where canAdd(page) { add(page) }
        }

        return picked
            .enumerated()
            .map { offset, page in RankedSurfacePage(page: page, rank: offset + 1) }
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
    /// it away), and only that slot refills — a background rebuild never
    /// reorders, evicts, or wholesale-replaces the shown desk. This matters
    /// because dozens of state changes bump `surfaceRefreshDate` (foregrounding,
    /// archive reloads, belief ticks, pack changes…), the curator's rank is
    /// time-sensitive, and adapters rotate cadence slots through their ids —
    /// so a naive rebuild reshuffles the desk constantly.
    ///
    /// A rebuild may still:
    ///   - refresh a shown card's content in place when the same logical slot
    ///     (`deskSlotKey`) comes back with changed content, and
    ///   - fill genuinely empty desk slots from the fresh curation order.
    static func stabilizedDeskOrder(
        previous: [SurfacePage],
        rebuilt: [SurfacePage],
        limit: Int = 3
    ) -> [SurfacePage] {
        guard !previous.isEmpty else { return Array(rebuilt.prefix(limit)) }

        let previousKeys = previous.map(\.deskSlotKey)
        // Duplicate slot keys (possible on paths that bypass the curator,
        // like the first-run sequence) make in-place matching ambiguous. A
        // fresh rebuild is safer than guessing which duplicate should stay.
        guard Set(previousKeys).count == previousKeys.count else { return Array(rebuilt.prefix(limit)) }

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

        // Stability applies while the same logical cards are being refreshed.
        // A real membership change means a card was kept, dismissed, unlocked,
        // or became ineligible, so the fresh desk is authoritative.
        let rebuiltKeys = rebuilt.map(\.deskSlotKey)
        guard Set(previousKeys) == Set(rebuiltKeys),
              Set(rebuiltKeys).count == rebuiltKeys.count else {
            return Array(rebuilt.prefix(limit))
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

    struct DeskRetirementResolution {
        var pages: [SurfacePage]
        var replacementIDByRetiringID: [String: String]
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
    static func resolvingRetiredDeskSlots(
        previous: [SurfacePage],
        retiringIDs: Set<String>,
        rebuilt: [SurfacePage],
        additionallyBlockedKeys: Set<String> = [],
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
        var replacementIDByRetiringID: [String: String] = [:]
        var resolved: [SurfacePage] = []

        for page in shown {
            guard activeRetiringIDs.contains(page.id) else {
                resolved.append(page)
                continue
            }

            guard let replacement = rebuilt.first(where: { candidate in
                !usedCandidateIDs.contains(candidate.id)
                    && candidate.curatorDeskExclusionKeys.isDisjoint(with: occupiedKeys)
                    && candidate.curatorDeskExclusionKeys.isDisjoint(with: additionallyBlockedKeys)
            }) else {
                continue
            }

            resolved.append(replacement)
            replacementIDByRetiringID[page.id] = replacement.id
            usedCandidateIDs.insert(replacement.id)
            occupiedKeys.formUnion(replacement.curatorDeskExclusionKeys)
        }

        return DeskRetirementResolution(
            pages: Array(resolved.prefix(limit)),
            replacementIDByRetiringID: replacementIDByRetiringID
        )
    }
}

// MARK: - Earned readings

enum ContextWeave {
    enum Tone: String, Equatable { case bright, heavy }
    enum Kind: String, Equatable { case manner, subject }

    struct Connection: Identifiable, Equatable {
        var id: String
        var kind: Kind
        var facetID: String
        var line: String
        var evidencePageIDs: [String]
        var inHits: Int
        var outHits: Int
    }

    static let brightInkWords: Set<String> = [
        "alive", "delight", "delighted", "glad", "grateful", "happy", "hopeful",
        "joy", "joyful", "laughed", "laughing", "playful", "relieved", "wonderful"
    ]
    static let heavyInkWords: Set<String> = [
        "afraid", "brittle", "dread", "empty", "exhausted", "grief", "heavy",
        "hopeless", "lonely", "lost", "sad", "tired", "weary", "worried"
    ]

    static func tone(of text: String) -> Tone? {
        let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        let bright = words.intersection(brightInkWords).count
        let heavy = words.intersection(heavyInkWords).count
        guard bright != heavy else { return nil }
        return bright > heavy ? .bright : .heavy
    }

    static func connections(days: [BookDay], calendar: Calendar = .current) -> [Connection] {
        let pages = days.flatMap(\.capturedPages).filter { $0.origin == .userAuthored }
        var result: [Connection] = []

        let weatherPages = pages.filter { $0.context != nil && !($0.context?.weatherTags.isEmpty ?? true) }
        let weatherTags = Set(weatherPages.flatMap { $0.context?.weatherTags ?? [] })
        for tag in weatherTags.sorted() {
            let inside = weatherPages.filter { $0.context?.weatherTags.contains(tag) == true }
            let outside = weatherPages.filter { $0.context?.weatherTags.contains(tag) == false }
            guard inside.count >= 5, outside.count >= 5,
                  Set(inside.map { BookDay.id(for: $0.createdAt) }).count >= 4 else { continue }
            for target in [Tone.heavy, .bright] {
                let inHits = inside.filter { tone(of: $0.userInput) == target }
                let outHits = outside.filter { tone(of: $0.userInput) == target }
                guard inHits.count >= 4,
                      Double(inHits.count) / Double(inside.count) >= 0.6,
                      Double(outHits.count) / Double(outside.count) <= 0.25 else { continue }
                let manner = target == .heavy ? "heavier ink" : "brighter ink"
                result.append(Connection(
                    id: "context-weather:\(tag)-\(target.rawValue)-ink",
                    kind: .manner,
                    facetID: "weather:\(tag)",
                    line: "Across \(numberWord(inHits.count)) kept pages, your sentences carried \(manner) while it was \(weatherPhrase(tag)). The comparison pages did not carry the same pattern.",
                    evidencePageIDs: Array(inHits.prefix(3).map(\.id)),
                    inHits: inHits.count,
                    outHits: outHits.count
                ))
            }
        }

        let afterDark = pages.filter { isAfterDark($0.createdAt, calendar: calendar) }
        let daytime = pages.filter { !isAfterDark($0.createdAt, calendar: calendar) }
        if afterDark.count >= 5, daytime.count >= 5 {
            let nightQuestions = afterDark.filter { $0.userInput.contains("?") }
            let dayQuestions = daytime.filter { $0.userInput.contains("?") }
            if nightQuestions.count >= 4,
               Double(nightQuestions.count) / Double(afterDark.count) >= 0.6,
               Double(dayQuestions.count) / Double(daytime.count) <= 0.25 {
                result.append(Connection(
                    id: "context-hour:night-asking",
                    kind: .manner,
                    facetID: "hour:night",
                    line: "Your pages ask more questions after dark: \(numberWord(nightQuestions.count)) separate pages carried a question, while the daytime pages mostly declared.",
                    evidencePageIDs: Array(nightQuestions.prefix(3).map(\.id)),
                    inHits: nightQuestions.count,
                    outHits: dayQuestions.count
                ))
            }
        }

        let weekend = pages.filter { calendar.isDateInWeekend($0.createdAt) }
        let weekday = pages.filter { !calendar.isDateInWeekend($0.createdAt) }
        if weekend.count >= 4, weekday.count >= 5 {
            let candidates = tokenCounts(in: weekend)
                .filter { $0.value >= 3 }
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            for (token, count) in candidates.prefix(3) {
                let weekdayHits = weekday.filter { subjectTokens(in: $0.userInput).contains(token) }
                guard weekdayHits.isEmpty else { continue }
                let evidence = weekend.filter { subjectTokens(in: $0.userInput).contains(token) }
                result.append(Connection(
                    id: "context-week:weekend-subject-\(token)",
                    kind: .subject,
                    facetID: "week:weekend",
                    line: "\(token.capitalized) has appeared on weekends in \(numberWord(count)) pages and never in the weekday comparison pages.",
                    evidencePageIDs: Array(evidence.prefix(3).map(\.id)),
                    inHits: count,
                    outHits: 0
                ))
            }
        }
        return result
    }

    private static func isAfterDark(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 20 || hour < 5
    }

    private static func weatherPhrase(_ tag: String) -> String {
        switch tag { case "rain": return "raining"; default: return tag }
    }

    private static func numberWord(_ value: Int) -> String {
        [0: "zero", 1: "one", 2: "two", 3: "three", 4: "four", 5: "five",
         6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten"][value] ?? String(value)
    }

    private static let subjectStopWords: Set<String> = [
        "about", "after", "again", "before", "could", "every", "from", "house",
        "kept", "letters", "their", "there", "these", "thing", "today", "while",
        "window", "with", "would"
    ]

    private static func subjectTokens(in text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init)
            .filter { $0.count >= 5 && !subjectStopWords.contains($0) })
    }

    private static func tokenCounts(in pages: [BookPage]) -> [String: Int] {
        pages.reduce(into: [:]) { counts, page in
            for token in subjectTokens(in: page.userInput) { counts[token, default: 0] += 1 }
        }
    }
}

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
    case kept
    case dismissed
    case loved
    case missed
}

struct ReaderLearningEvent: Identifiable, Codable, Equatable {
    var id: String
    var dayID: String
    var occurredAt: Date
    var action: ReaderLearningAction
    var surfaceID: String
    var sourceID: String
    var type: BookPageType
    var varietyKey: String
    var hour: Int
    var tags: [String]
    var evidence: String?

    init(
        id: String = UUID().uuidString,
        dayID: String,
        occurredAt: Date = Date(),
        action: ReaderLearningAction,
        surfaceID: String,
        sourceID: String,
        type: BookPageType,
        varietyKey: String,
        hour: Int,
        tags: [String] = [],
        evidence: String? = nil
    ) {
        self.id = id
        self.dayID = dayID
        self.occurredAt = occurredAt
        self.action = action
        self.surfaceID = surfaceID
        self.sourceID = sourceID
        self.type = type
        self.varietyKey = varietyKey
        self.hour = max(0, min(23, hour))
        self.tags = Array(Set(tags.map(\.readerLearningNormalizedTag).filter { !$0.isEmpty })).sorted()
        self.evidence = evidence?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty.map {
            String($0.prefix(160))
        }
    }
}

struct ReaderLearningAffinity: Codable, Equatable {
    var surfaced: Int = 0
    var kept: Int = 0
    var dismissed: Int = 0
    var loved: Int = 0
    var missed: Int = 0
    var lastUpdatedAt: Date?

    var meaningfulSignals: Int {
        kept + dismissed + loved + missed
    }

    var rawScore: Int {
        kept * 3 + loved * 6 - dismissed * 3 - missed * 5
    }

    mutating func record(_ event: ReaderLearningEvent) {
        switch event.action {
        case .surfaced:
            surfaced += 1
        case .kept:
            kept += 1
        case .dismissed:
            dismissed += 1
        case .loved:
            loved += 1
        case .missed:
            missed += 1
        }
        lastUpdatedAt = event.occurredAt
    }

    func curationAdjustment(scale: Int, maximum: Int) -> Int {
        guard meaningfulSignals > 0 else { return 0 }
        let confidence = min(scale, meaningfulSignals)
        let weighted = rawScore * confidence / scale
        return max(-maximum, min(maximum, weighted))
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

struct ReaderLearningModel: Codable, Equatable {
    static let currentVersion = 1
    static let maxEvents = 400

    var version: Int = ReaderLearningModel.currentVersion
    var events: [ReaderLearningEvent] = []
    var sourceAffinities: [String: ReaderLearningAffinity] = [:]
    var typeAffinities: [BookPageType: ReaderLearningAffinity] = [:]
    var tagAffinities: [String: ReaderLearningAffinity] = [:]
    var dailyDigests: [ReaderLearningDailyDigest] = []
    var lastUpdatedAt: Date?

    mutating func record(_ event: ReaderLearningEvent) {
        events.append(event)
        if events.count > Self.maxEvents {
            events = Array(events.suffix(Self.maxEvents))
        }

        sourceAffinities[event.sourceID, default: ReaderLearningAffinity()].record(event)
        typeAffinities[event.type, default: ReaderLearningAffinity()].record(event)
        for tag in event.tags.prefix(8) {
            tagAffinities[tag, default: ReaderLearningAffinity()].record(event)
        }
        lastUpdatedAt = event.occurredAt
        rebuildDailyDigest(for: event.dayID)
    }

    func scoreAdjustment(for page: SurfacePage) -> Int {
        let source = sourceAffinities[page.sourceID]?.curationAdjustment(scale: 4, maximum: 10) ?? 0
        let type = typeAffinities[page.type]?.curationAdjustment(scale: 5, maximum: 12) ?? 0
        let tag = page.readerLearningTags
            .compactMap { tagAffinities[$0]?.curationAdjustment(scale: 4, maximum: 4) }
            .sorted(by: >)
            .prefix(3)
            .reduce(0, +)
        return max(-16, min(20, source + type + tag))
    }

    func metrics(days: [BookDay] = [], now: Date = Date(), calendar: Calendar = .current) -> ReaderLearningMetrics {
        let firstEventAt = events.map(\.occurredAt).min()
        let firstPageAt = days.flatMap(\.pages).map(\.createdAt).min()
        let firstTouch = [firstEventAt, firstPageAt].compactMap { $0 }.min()
        let tenureDays = firstTouch.map { max(1, calendar.dateComponents([.day], from: $0, to: now).day ?? 0) } ?? 0
        let totals = events.reduce(into: [ReaderLearningAction: Int]()) { counts, event in
            counts[event.action, default: 0] += 1
        }
        return ReaderLearningMetrics(
            tenureDays: tenureDays,
            eventCount: events.count,
            meaningfulEventCount: events.filter { $0.action != .surfaced }.count,
            kept: totals[.kept] ?? 0,
            dismissed: totals[.dismissed] ?? 0,
            loved: totals[.loved] ?? 0,
            missed: totals[.missed] ?? 0,
            learnedSurfaceCount: sourceAffinities.values.filter { $0.meaningfulSignals > 0 }.count,
            activeDigestCount: dailyDigests.count
        )
    }

    func insights(now: Date = Date(), limit: Int = 4) -> [ReaderLearningInsight] {
        var insights: [ReaderLearningInsight] = []
        if let warming = strongestType(warming: true) {
            insights.append(ReaderLearningInsight(
                id: "warming-type-\(warming.type.rawValue)",
                kind: .warmingType,
                line: "\(warming.type.shortTitle) is warming in the margins.",
                evidence: "\(warming.affinity.kept + warming.affinity.loved) positive signals, \(warming.affinity.dismissed + warming.affinity.missed) cooling signals.",
                strength: warming.affinity.rawScore
            ))
        }
        if let cooling = strongestType(warming: false) {
            insights.append(ReaderLearningInsight(
                id: "cooling-type-\(cooling.type.rawValue)",
                kind: .coolingType,
                line: "The Book is letting \(cooling.type.shortTitle.lowercased()) rest.",
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
                line: "The Book is learning when pages land.",
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
        let dayEvents = events.filter { $0.dayID == dayID }
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

    var curatorServedHistoryKeys: [String] {
        var keys = [
            varietyKey,
            "source:\(sourceID)",
            CuratorVarietyGovernor.typeKey(for: type)
        ]
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

    var curatorDeskExclusionKeys: Set<String> {
        var keys = Set(curatorServedHistoryKeys)
        keys.insert(id)
        return keys
    }

    /// The desk slot a card logically occupies. Raw ids can't identify a slot:
    /// many adapters rotate a cadence slot (or a raw timestamp) through their
    /// candidate ids, so the same logical card comes back under a fresh id.
    /// The desk's structural rules (one source family, one type) make this
    /// pair unique per desk.
    var deskSlotKey: String {
        "\(sourceID)|\(type.rawValue)"
    }

    /// True when only the id differs — the card the reader sees is unchanged.
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
            payload.metadata["storyGenreID"].map { "genre:\($0)" },
            payload.metadata["storyFormID"].map { "form:\($0)" },
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

    /// The single source of truth for lane membership. `default` is `.other`
    /// so any future page kind (e.g. the coming quotation pages) lands in the
    /// grab-bag lane until it is deliberately reclassified.
    var deskLane: DeskLane {
        switch self {
        // Outward — the reader attends to the actual world / their own day.
        case .wonderCompass, .diary, .mood, .souvenir, .body, .fuel,
             .weather, .todaysSky, .location, .anchor, .pactErrand,
             .rest, .enchantment, .plainPage:
            return .outward
        // Fiction — the Academy world performs, corresponds, or contends.
        case .narrativeOS, .letter, .gossip, .facultyResearch, .supportGuild,
             .inkrestOfficeHours, .faeBargain, .bookFae, .academyClass,
             .elective, .festival, .twoReadings, .castBond, .bookJump,
             .wordNegotiation, .theBleed, .pactDispatch, .pactVerdict,
             .bookOfYou:
            return .fiction
        // Other — everything else: games, reference, returns, images, tools.
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

/// The Introduction Season: the wider world debuts in stages as the library
/// grows, instead of arriving all at once the moment the local brain wakes.
/// The ladder throttles variety, never volume — capture pages and the core
/// daily loop flow from day one, and each staged family enters as a single
/// felt reveal (`isManagedDebut` lets one debut per desk build).
///
/// Crucially it locks only a family's *first* appearance: anything the desk
/// has already shown — an arc in motion, a Weekly Issue riding the bindery
/// type, an existing reader's whole world — keeps flowing. The season
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

    /// Families with a staged debut. Anything absent is stage 0 — including
    /// the Book of You braid (the nightly core loop), bindery/inventory
    /// (they self-gate on archive readiness), and the 50-keep memory trio
    /// (BookMemoryGate governs those).
    static let requiredStage: [BookPageType: Int] = [
        .narrativeOS: 1, .academyClass: 1, .elective: 1, .gamePage: 1,
        .gossip: 2, .letter: 2, .facultyResearch: 2, .supportGuild: 2,
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
    /// these joins each build, so unlocks arrive one reveal at a time —
    /// stage-0 families are exempt, keeping a brand-new desk full.
    static func isManagedDebut(
        _ type: BookPageType,
        surfaceHistory: [String: SurfaceHistoryRecord]
    ) -> Bool {
        requiredStage[type] != nil
            && surfaceHistory[CuratorVarietyGovernor.typeKey(for: type)] == nil
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
    var earnedWonderTitle: WonderTitle?

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
                    + inputs.nothingGreyOffset
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
            composedTypesToday: composedCompositionTypes(in: inputs.days, on: now, calendar: calendar),
            earnedWonderTitle: WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
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
            // World events run on real, limited dates — the season's front
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
        // variety games — the distress-aware base scores choose care first.
        if distressActive {
            return 0
        }
        var delta = CuratorTimeAffinity.boost(for: page.type, at: now)

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
        if page.hiddenMagicLens != nil {
            // The outward lane is the delivery spine for real-world noticing.
            // This is a modest preference inside that lane, not a fourth desk
            // slot and not a new Page family.
            delta += 6
        }
        delta += WonderTitleRegistry.scoreBoost(for: page, title: earnedWonderTitle)

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
        // Routine pages stay in the deep stacks — reward by absence.
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
