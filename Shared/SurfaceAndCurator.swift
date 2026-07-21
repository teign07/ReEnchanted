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
        if type == .bookPocket,
           let encodedKeepsakes = payload.metadata[PocketKeepsakeArchive.metadataKey] {
            assets.append(contentsOf: PocketKeepsakeArchive.decode(encodedKeepsakes)
                .flatMap { $0.mediaAssets ?? [] })
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
        "Off it goes. The Book pretends not to watch the {page} page leave.",
        "The {page} page wanders back into the stacks, whistling.",
        "Gone \u{2014} but the {page} page left the door on the latch.",
        "The Book lets the {page} page go and keeps the spot warm with a thumb.",
        "The {page} page bows out. The margins hold its warmth a while.",
        "Away it drifts. The lamp leans after the {page} page, then settles.",
        "The {page} page slips off to nap in the stacks. The Book tucks it in."
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
        let bookRelationship = BookRelationshipLedger.snapshot(inputs: inputs, now: now)
        let rawCandidates = (
            BookPageSourceAdapters.active.flatMap { adapter in
                adapter.candidates(for: day, context: context, inputs: inputs, now: now)
            }
            + BookInteriorSurfaces.candidates(for: day, inputs: inputs, now: now)
        )
        .map { WorldEventEffects.framed($0, events: inputs.activeWorldEvents) }
        .map { BookRelationshipVoice.decorating($0, relationship: bookRelationship) }
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
                now: now
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
        // — guarantee one of its pages a slot if the feed didn't already pick one
        // and the day isn't hard. Pure surfacing; no model call.
        let sovereignTypes = PactWarEffects.sovereignShelfPageTypes(state: inputs.pactWar)
        if !longGameOwnsInterventionSlot,
           !sovereignTypes.isEmpty,
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
                   && !BookMemoryGate.locks(candidate.type, keptPageCount: inputs.keptPageCount)
           }) {
            if picked.count < limit {
                picked.append(tarot)
            } else if let victim = injectionVictimIndex(in: picked, preferringLane: tarot.type.deskLane) {
                picked[victim] = tarot
            }
        }

        let framed = picked
            .map { PactWarEffects.framed($0, state: inputs.pactWar) }
            .map { $0.withReaderLexiconLanguageLaw(inputs.readerLexicon) }
        return BookPersonalityActuator.enacting(
            in: framed,
            interior: inputs.bookInterior,
            day: day
        )
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
        now: Date = Date()
    ) -> [RankedSurfacePage] {
        // Hard filters: a reader's disabled sources and first-hours hidden types
        // are never overridden.
        let allowed = candidates
            .filter { preferences.allows($0) }
            .filter { mood.allows($0) }
            .filter { !BookMemoryGate.locks($0.type, keptPageCount: mood.keptPageCount) }
            .filter {
                CuratorNoveltyPolicy.allowsAutomaticSurface(
                    $0,
                    history: mood.surfaceHistory,
                    preferences: preferences
                )
            }
        // The type-refresh cooldown only adds variety — it must never starve the
        // desk. Prefer pages that are off cooldown, but if that would leave the
        // homescreen empty, fall back to the full allowed pool.
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
        //   1. Never repeat a source family — no two variants from the same
        //      preview system occupy the home shelf at once.
        //   2. Never repeat a kind of page — no two lore cards (or two of any
        //      type) on the shelf at once.
        //   3. Never stack blank-page "write one thing" prompts — at most one
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
        let deduped = unique(selectionOrder)
        var picked: [SurfacePage] = []
        var pickedTypes: Set<BookPageType> = []
        var compositionCount = 0
        var debutCount = 0
        var actionCommissionCount = 0
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

        func isDebut(_ page: SurfacePage) -> Bool {
            page.payload.metadata["firstReading"] == "true"
                ? false
                : IntroductionCurriculum.isManagedDebut(page.type, surfaceHistory: mood.surfaceHistory)
        }
        func canAdd(_ page: SurfacePage) -> Bool {
            guard picked.count < limit else { return false }
            guard !pickedTypes.contains(page.type) else { return false }
            let isBuildingVisibleDesk = picked.count < visibleLimit
            let currentCompositionLimit = isBuildingVisibleDesk ? 1 : compositionLimit
            let currentDebutLimit = isBuildingVisibleDesk ? 1 : debutLimit
            let currentActionLimit = isBuildingVisibleDesk ? 1 : actionCommissionLimit
            if page.type.isCompositionPrompt, compositionCount >= currentCompositionLimit { return false }
            if isDebut(page), debutCount >= currentDebutLimit { return false }
            if page.isReaderActionCommission, actionCommissionCount >= currentActionLimit { return false }
            return true
        }
        func add(_ page: SurfacePage) {
            if isDebut(page) { debutCount += 1 }
            if page.type.isCompositionPrompt { compositionCount += 1 }
            if page.isReaderActionCommission { actionCommissionCount += 1 }
            picked.append(page)
            pickedTypes.insert(page.type)
        }

        // The visible three-card prefix is balanced across lanes even when the
        // caller asks for a deeper refill bench. Previously `limit: 12` bypassed
        // this branch and the UI then displayed an unbalanced `prefix(3)`.
        let balancesVisibleDesk = limit >= 3
        // Milestones are promises the Book has already earned the right to
        // fulfill. Give them first claim on the visible prefix; additional
        // milestones remain first in the deeper selection order below.
        for page in deduped where page.isDeskMilestone && picked.count < visibleLimit && canAdd(page) {
            add(page)
        }
        if balancesVisibleDesk {
            for lane in DeskLane.allCases {
                guard picked.count < visibleLimit else { break }
                guard !picked.contains(where: { $0.type.deskLane == lane }) else { continue }
                if let page = deduped.first(where: { $0.type.deskLane == lane && canAdd($0) }) {
                    add(page)
                }
            }
            for page in deduped where picked.count < visibleLimit && canAdd(page) { add(page) }
            // Restore score order inside the visible trio, then append the deep
            // bench in rank order without allowing it to displace that trio.
            let rank = Dictionary(uniqueKeysWithValues: deduped.enumerated().map { ($0.element.id, $0.offset) })
            picked.sort { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
        }
        for page in deduped where canAdd(page) { add(page) }

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
        now: Date = Date()
    ) -> [CuratorCandidateTrace] {
        candidates.map { page in
            let preferenceAllowed = preferences.allows(page)
            let moodAllowed = mood.allows(page)
            let memoryAllowed = !BookMemoryGate.locks(page.type, keptPageCount: mood.keptPageCount)
            let noveltyAllowed = CuratorNoveltyPolicy.allowsAutomaticSurface(
                page,
                history: mood.surfaceHistory,
                preferences: preferences
            )
            let rejection: String?
            if !preferenceAllowed {
                rejection = "dismissed-or-disabled"
            } else if !moodAllowed {
                rejection = "introduction-or-first-hours-gate"
            } else if !memoryAllowed {
                rejection = "memory-maturity-gate"
            } else if !noveltyAllowed {
                rejection = "exact-repeat-needs-belief"
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
        // like the first-run sequence) make in-place matching ambiguous —
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
    var isNewType: Bool
    var isNewSource: Bool
    var isNewContent: Bool
    var rejection: String?
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
    case followedThread
    case keepsakeEarned
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
    /// Coarse context captured at the interaction itself. This lets the Book
    /// compare what the reader actually opened or chose with weather, hour,
    /// place, and reader-named inner weather later. Older ledgers decode with
    /// no snapshot, and coordinates/calendar titles are never stored here.
    var context: BookPageContextSnapshot?

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
        evidence: String? = nil,
        context: BookPageContextSnapshot? = nil
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
        self.context = context
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
        case .opened, .acted, .recognized, .followedThread, .keepsakeEarned:
            // Moment-to-moment telemetry describes the interaction without
            // warming or cooling the curator's taste model.
            break
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

    var openToActionRatePercent: Int {
        guard opened > 0 else { return 0 }
        return Int((Double(actionsWithinThirtySeconds) / Double(opened) * 100).rounded())
    }
}

struct ReaderLearningModel: Codable, Equatable {
    static let currentVersion = 1
    static let maxEvents = 800

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
        // Learned taste is a tie-breaker inside the fresh pool. It should help
        // the Book choose *which new Page* lands, never overpower discovery.
        return max(-8, min(8, source + type + tag))
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
            meaningfulEventCount: events.filter {
                switch $0.action {
                case .acted, .followedThread, .keepsakeEarned, .kept, .dismissed, .loved, .missed:
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
        let openedEvents = events.filter { $0.action == .opened }
        let actedEvents = events.filter { $0.action == .acted }
        let recognized = events.filter { $0.action == .recognized }.count
        let followed = events.filter { $0.action == .followedThread }.count
        let keepsakes = events.filter { $0.action == .keepsakeEarned }.count
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

        return ReaderMomentumMetrics(
            opened: openedEvents.count,
            acted: actedEvents.count,
            recognized: recognized,
            followedThreads: followed,
            keepsakesEarned: keepsakes,
            actionsWithinThirtySeconds: responseTimes.filter { $0 <= 30 }.count,
            medianOpenToActionSeconds: median
        )
    }

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

/// Gives prose-first Pages one immediate act above their deeper material.
/// Pages that already open directly into a game, conversation, reading,
/// transaction, or multi-step ritual keep their native first move.
enum MomentaryAttentionEngine {
    static let pagesWithNativeFirstMove: Set<BookPageType> = [
        .askTheBook, .radio, .gamePage, .bookJump, .faeBargain, .bookFae,
        .pactVerdict, .pactErrand, .narrativeOS, .academyClass, .tarot,
        .enchantment, .inkrestOfficeHours, .twoReadings, .wordNegotiation,
        .plainPage, .bookOfYou
    ]

    static func prompt(
        for surface: SurfacePage,
        learning: ReaderLearningModel
    ) -> MomentaryActionPrompt? {
        guard !pagesWithNativeFirstMove.contains(surface.type),
              surface.payload.metadata["keptReadback"] != "true" else {
            return nil
        }
        let stage = ReaderAttentionMasteryStage.current(for: learning)
        switch stage {
        case .notice:
            return MomentaryActionPrompt(
                stage: stage,
                question: "What caught first?",
                placeholder: "One word is enough",
                buttonTitle: "Let it catch"
            )
        case .name:
            return MomentaryActionPrompt(
                stage: stage,
                question: "What has the strongest charge?",
                placeholder: "Name the detail",
                buttonTitle: "Give it ink"
            )
        case .connect:
            return MomentaryActionPrompt(
                stage: stage,
                question: "What does this touch in your life?",
                placeholder: "A person, place, memory, or object",
                buttonTitle: "Start the thread"
            )
        case .transform:
            return MomentaryActionPrompt(
                stage: stage,
                question: "What will you carry out of this Page?",
                placeholder: "One small change",
                buttonTitle: "Carry it out"
            )
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
            return "The Book catches “\(clipped)” before the rest of the Page can explain it."
        case .name:
            return "“\(clipped)” takes ink. The Page knows what you meant."
        case .connect:
            return "“\(clipped)” touches the Page. A thread has started."
        case .transform:
            return "“\(clipped)” leaves the Page with you. The Book marks the change."
        }
    }
}

/// A single causal handoff after a substantial Keep. It names the reader's
/// exact material and asks for one more connection; it never chains itself.
enum MomentaryThreadFollowUp {
    static let sourceID = "momentary-thread-follow-up"

    static func surface(
        after page: BookPage,
        keptFrom surface: SurfacePage,
        learning: ReaderLearningModel
    ) -> SurfacePage? {
        guard surface.payload.metadata["momentaryThreadFollowUp"] != "true",
              surface.type != .bookConnections,
              page.origin == .userAuthored else {
            return nil
        }
        let input = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.split(whereSeparator: { $0.isWhitespace }).count >= 2 else { return nil }
        let thread = KeepMarginalia.featuredWord(in: input)
            ?? String(input.prefix(42)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thread.isEmpty else { return nil }
        let stage = ReaderAttentionMasteryStage.current(for: learning)
        let nextQuestion: String
        switch stage {
        case .notice, .name:
            nextQuestion = "Where else have you noticed it?"
        case .connect:
            nextQuestion = "What person, place, or memory answers it?"
        case .transform:
            nextQuestion = "What could it change before the day is over?"
        }
        return SurfacePage(
            id: "momentary-thread-\(page.id)",
            type: .bookConnections,
            sourceID: sourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: 96,
            reason: "This rose because you kept “\(thread)”.",
            prompt: "You kept “\(thread)”. \(nextQuestion)",
            detail: "One more true connection, if it has one. If nothing answers, let the thread rest.",
            payload: BookPagePayload(
                headline: "The Thread That Answered",
                body: "The Book has not invented a connection. It is holding your own words open long enough for you to notice whether something real answers them.",
                metadata: [
                    "momentaryThreadFollowUp": "true",
                    "threadParentPageID": page.id,
                    "threadWord": thread,
                    "surfaceLabel": "A Thread Answered",
                    "tags": "momentary-attention,causal-follow-up"
                ]
            )
        )
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

    /// Pages that commission a concrete action from the reader. This is wider
    /// than `isCompositionPrompt`: a mission and an apprenticeship can otherwise
    /// stack despite asking for two different kinds of effort.
    var isReaderActionCommission: Bool {
        if payload.metadata["curatorActionCommission"] == "true"
            || payload.metadata["playfulMissionID"]?.nonEmpty != nil
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

/// Freshness is decided before learned taste. A reader's implicit preferences
/// choose among genuinely available Pages; only explicit Belief gives an exact
/// Page permission to return automatically.
enum CuratorNoveltyPolicy {
    static let repeatBeliefThreshold = 45
    static let belovedBeliefThreshold = 80

    static func belief(
        for page: SurfacePage,
        preferences: CuratorSurfacePreferences
    ) -> Int {
        let recordedBelief = preferences.pageBeliefProfiles[page.sourceID]?.belief
            ?? BookPageSourceRegistry.beliefProfile(for: page.source).belief
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
        preferences: CuratorSurfacePreferences
    ) -> Bool {
        if isNewContent(page, history: history) { return true }
        if page.isDeskMilestone { return true }
        if isActiveContinuation(page) { return true }
        return belief(for: page, preferences: preferences) >= repeatBeliefThreshold
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

/// A small, explicit promise that onboarding choices can tip close curation
/// calls without becoming permanent filters. Kept behavior and learned Belief
/// remain stronger evidence; this only gives the first desk a recognizable
/// accent from the shelf the reader asked for.
enum FirstDoorCurationAffinity {
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
    var onboardingTaste: String?
    var onboardingChapter: String?
    var onboardingComfort: String?

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
            earnedWonderTitle: WonderTitleRegistry.earnedTitle(from: inputs.selfFacts),
            onboardingTaste: onboardingAnswer("onboarding-taste", in: inputs.selfFacts),
            onboardingChapter: onboardingAnswer("onboarding-drawn-chapter", in: inputs.selfFacts),
            onboardingComfort: onboardingAnswer("onboarding-comfort-boundary", in: inputs.selfFacts)
        )
    }

    private static func onboardingAnswer(_ questionID: String, in facts: [SelfFact]) -> String? {
        facts.first {
            $0.questionID == questionID && $0.usePermission != .doNotUse
        }?.answer.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
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
        delta += WonderTitleRegistry.scoreBoost(for: page, title: earnedWonderTitle)
        delta += FirstDoorCurationAffinity.boost(
            for: page,
            taste: onboardingTaste,
            chapter: onboardingChapter,
            comfort: onboardingComfort
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
