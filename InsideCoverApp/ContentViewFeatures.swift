import SwiftUI
import CryptoKit
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// The reader chooses whether a Book of You Page keeps its editorial skeleton
/// or asks the same receipts to support another fitting story form.
enum BraidRetellingChoice: String, Equatable, Sendable {
    case sameBones = "same-bones"
    case freshShape = "fresh-shape"
}

/// One whole photograph borrowed from the reader's own library, used to seed
/// the Pagewright's first spread.
///
/// Shared by both first-door paths — opening the worktable and letting the
/// Pagewright arrange the scraps unsupervised — because they used to disagree:
/// the worktable seeded a photo and the unsupervised path looked for one in an
/// onboarding photo flow that has not run yet, so the same screen produced two
/// visibly different pages.
///
/// Asks for Photos access on first use and returns nil for every refusal, so a
/// declined prompt is simply a page without a photograph in it.
enum PagewrightLibraryPhoto {
    static func random() async -> PagewrightPersonalPhoto? {
        #if canImport(Photos) && canImport(UIKit)
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let resolvedStatus = status == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            : status
        guard resolvedStatus == .authorized || resolvedStatus == .limited else { return nil }

        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        guard assets.count > 0 else { return nil }
        let asset = assets.object(at: Int.random(in: 0..<assets.count))
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .highQualityFormat
        let raw: Data? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: requestOptions
            ) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
        guard let raw,
              let jpeg = PressedPhotograph.downscaledJPEG(from: raw),
              let image = UIImage(data: jpeg),
              image.size.width > 0,
              image.size.height > 0 else { return nil }

        return PagewrightPersonalPhoto(
            data: jpeg,
            aspectRatio: image.size.width / image.size.height
        )
        #else
        return nil
        #endif
    }
}

private struct WeeklyIssueBindingDraft: Codable, Equatable {
    var issue: WeeklyIssue
    var editorialNote: String?
    var closingNote: String?
}

private enum WeeklyIssueBindingStage: String {
    case bindingStory = "weekly-binding-story"
    case editorialTitle = "weekly-editorial-title"
    case editorialNote = "weekly-editorial-note"
    case closingNote = "weekly-closing-note"
    case looseThread = "weekly-loose-thread"
    case castConversation = "weekly-cast-conversation"
}

private enum MonthlyEditionBindingStage: String {
    case foreword = "monthly-foreword"
    case bindingStory = "monthly-binding-story"
    case closing = "monthly-closing"
    case castConversation = "monthly-cast-conversation"
}

private enum ChapteredVolumeBindingStage: String {
    case foreword = "volume-foreword"
    case closing = "volume-closing"
    case castConversation = "volume-cast-conversation"
}

/// The on-disk half of the publication stage boundary. A checkpoint is one
/// small protected JSON file per publication identity; every save is atomic.
private enum PublicationBindingCheckpointStore {
    private static var directoryURL: URL? {
        InsideCoverStore.containerURL?
            .appendingPathComponent("PublicationBindingDrafts", isDirectory: true)
    }

    static func fingerprint<Source: Encodable>(of source: Source) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return digest(try encoder.encode(source))
    }

    static func load<Payload: Codable & Equatable>(
        _: Payload.Type,
        slot: String,
        sourceFingerprint: String
    ) throws -> PublicationBindingCheckpoint<Payload>? {
        let url = try fileURL(for: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let checkpoint = try JSONDecoder().decode(
                PublicationBindingCheckpoint<Payload>.self,
                from: Data(contentsOf: url)
            )
            guard checkpoint.matches(sourceFingerprint: sourceFingerprint) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return checkpoint
        } catch {
            // A torn or obsolete receipt must never prevent rebinding. Atomic
            // writes make this rare; if it happens, begin the leaf again.
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    static func save<Payload: Codable & Equatable>(
        _ checkpoint: PublicationBindingCheckpoint<Payload>,
        slot: String
    ) throws {
        guard let directoryURL else { throw CocoaError(.fileNoSuchFile) }
        try SensitiveFileProtection.protectDirectory(at: directoryURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try SensitiveFileProtection.write(
            try encoder.encode(checkpoint),
            to: try fileURL(for: slot)
        )
    }

    static func remove(slot: String) throws {
        let url = try fileURL(for: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func fileURL(for slot: String) throws -> URL {
        guard let directoryURL else { throw CocoaError(.fileNoSuchFile) }
        return directoryURL.appendingPathComponent("\(digest(Data(slot.utf8))).json")
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ContentView feature cluster: seals, anchors, generated-page
// adoption, onboarding completion, and Unwritten Electives.
//
// Split from ContentView.swift to start paying down the monolith; new
// feature clusters should land here (or in sibling extension files), not
// in the main view file.

extension ContentView {
    var shouldPauseAmbientMotion: Bool {
        scenePhase != .active
            || isLaunchAmbientMotionPaused
            || localBrainTelemetry.isWorking
            || generation.isBraiding
            || generation.isPreparingAutomaticIllumination
            || generation.isPreparingStoryPage
            || generation.isPreparingGossipPage
            || generation.isPreparingFacultyResearchPage
            || generation.isPreparingLetterPage
            || generation.isPreparingBleedEdition
            || selectedSurface != nil
            || pactVerdictSurface != nil
            || pactErrandSurface != nil
            || isPagewrightPresented
            || isPlainPagePresented
            || isSourceSettingsPresented
            || isBookShopPresented
            || isStacksSearchPresented
            || isAlmanacPresented
            || isCustomCastSheetPresented
            || isBraidingTablePresented
            || isPactMapPresented
            || isConnectionsPresented
            || showStandingOrderPaywall
            || isGlowMenuPresented
    }

    var pagewrightCandidatePages: [BookPage] {
        // Read by the worktable's own body, so it is asked for again on every
        // pass while the Pagewright is open. Flattening and sorting the whole
        // archive each time is the wait the reader feels when it opens.
        ArchiveMemo.value("pagewright.candidates", days: days) {
            days
                .flatMap(\.pages)
                .filter { page in
                    page.type != .welcome
                        && page.type != .helpTips
                        && (!page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !page.pagewrightVisualMediaAssets.isEmpty)
                }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    var bookwideMarginaliaAchievementContext: BookwideMarginaliaAchievement.Context {
        // A BookPage is a large value, and this flattens every one of them.
        // Held for the version of the archive that produced it, because the
        // sheets that read this ask for it on every pass of their body.
        let keptPages = ArchiveMemo.value("archive.all-pages", days: days) {
            days.flatMap(\.pages)
        }
        let completedCompassRuns = Set(
            completedCompassRunLedger
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        ).count
        let completedBookJumps = vault.data.bookJump?
            .returned
            .filter { !$0.souvenir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count ?? 0
        return BookwideMarginaliaAchievement.Context(
            pages: keptPages,
            anchors: anchorLedger,
            entityBeliefOffsets: entityBeliefLedger,
            completedBookJumps: completedBookJumps,
            completedCompassRuns: completedCompassRuns,
            electives: electives,
            longGameEvidence: vault.data.bookInterior?.longGame?.evidence ?? [],
            hasChosenQuill: vault.data.chosenQuill != nil
        )
    }

    var bookwideMarginaliaAchievementSignature: String {
        let context = bookwideMarginaliaAchievementContext
        let weatherCounts = Dictionary(
            grouping: context.pages.flatMap { $0.context?.weatherTags ?? [] },
            by: { $0 }
        )
        .map { "\($0.key):\($0.value.count)" }
        .sorted()
        .joined(separator: "|")
        let typeCounts = Dictionary(grouping: context.pages, by: \.type)
            .map { "\($0.key.rawValue):\($0.value.count)" }
            .sorted()
            .joined(separator: "|")
        let livedQuestCounts = Dictionary(grouping: context.livedQuestReceipts, by: \.kind)
            .map { "\($0.key.rawValue):\($0.value.count)" }
            .sorted()
            .joined(separator: "|")
        let livedWonderFacets = context.distinctLivedWonderFacetRawValues.sorted().joined(separator: "|")
        let longGameCounts = Dictionary(grouping: context.longGameEvidence, by: \.capacity)
            .map { "\($0.key.rawValue):\($0.value.count)" }
            .sorted()
            .joined(separator: "|")
        return [
            "\(context.pages.count)",
            "\(context.keptDayIDs.count)",
            typeCounts,
            weatherCounts,
            "\(context.readerEvidencePages.filter { $0.context?.dayPart == "night" }.count)",
            "\(context.pages.filter(\.hasMarginaliaAchievementVisual).count)",
            "\(context.readerAnchors.count)",
            "\(Set(context.readerAnchors.map(\.kind)).count)",
            "\(context.readerAnchors.reduce(0) { $0 + $1.visitCount })",
            "\(context.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] ?? 0)",
            "\(context.completedBookJumps)",
            "\(context.completedCompassRuns)",
            "\(context.completedElectives)",
            livedQuestCounts,
            livedWonderFacets,
            longGameCounts,
            context.sensoryModalities.sorted().joined(separator: "|"),
            context.distinctReaderProofKindRawValues.sorted().joined(separator: "|"),
            context.hasChosenQuill ? "quill" : "waiting"
        ].joined(separator: "§")
    }

    func refreshBookwideMarginaliaAchievements(announce: Bool = true) {
        let completedBefore = Set(
            completedMarginaliaAchievementLedger
                .split(separator: ",")
                .map(String.init)
        )
        let context = bookwideMarginaliaAchievementContext
        let completedNow = BookwideMarginaliaAchievement.all.filter { $0.isComplete(in: context) }
        let newlyCompleted = completedNow.filter { !completedBefore.contains($0.id) }
        guard !newlyCompleted.isEmpty else {
            didSeedBookwideMarginaliaAchievements = true
            return
        }

        var earned = completedBefore
        earned.formUnion(newlyCompleted.map(\.id))
        completedMarginaliaAchievementLedger = earned.sorted().joined(separator: ",")

        let shouldAnnounce = announce && didSeedBookwideMarginaliaAchievements
        didSeedBookwideMarginaliaAchievements = true
        guard shouldAnnounce, let first = newlyCompleted.first else { return }

        let rewardCount = newlyCompleted.reduce(0) { $0 + $1.rewardAssetIDs.count }
        let additionalCount = newlyCompleted.count - 1
        let marksLine = rewardCount == 1
            ? "One new mark came loose in Pagewright."
            : "\(rewardCount) new marks came loose in Pagewright."
        let line = additionalCount > 0
            ? "There. \(first.name), then \(additionalCount) more. \(marksLine)"
            : "There. \(first.name). \(marksLine)"
        let note = KeepMarginalia.Note(
            castSlug: "marginalia-goblin",
            castName: "Marginalia Goblin",
            assetName: "LabyrinthFaeMarginaliaGoblin",
            line: line,
            carryOutLine: "They are yours now. I won't put the locks back."
        )
        let announcementTitle = additionalCount > 0
            ? "THE MARGINS FOUND \(newlyCompleted.count) THINGS"
            : "\(first.track.announcementLabel) · \(first.name.uppercased())"
        marginaliaAchievementAnnouncementTicket += 1
        let ticket = marginaliaAchievementAnnouncementTicket
        Task { @MainActor in
            var waitedForKeepNote = false
            repeat {
                while isKeepMarginNotePresentationActive {
                    waitedForKeepNote = true
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled,
                          ticket == marginaliaAchievementAnnouncementTicket else { return }
                }

                if waitedForKeepNote {
                    // Let the character note finish its exit before the Marginalia
                    // Goblin enters. This keeps both messages at the readable bottom
                    // position without stacking one card over the other.
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled,
                          ticket == marginaliaAchievementAnnouncementTicket else { return }
                }
                // A quick second keep may begin during the breathing room. If it
                // does, hear that whole note and give its exit a fresh gap too.
            } while isKeepMarginNotePresentationActive

            marginaliaAchievementUnlockTitle = announcementTitle
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
                marginaliaAchievementUnlockNote = note
            }
            BookFeedback.play(.braidComplete)
        }
    }

    /// What the Pagewright's mark shelves are allowed to know about the date.
    ///
    /// Only the time half: the month, the live world events, and their phases.
    /// The tray uses it to decide which marks are *loose right now* and belong
    /// on This Month, and which have already had their season. Deliberately
    /// carries no `semanticTags` — browsing is not composing, and a shelf must
    /// not filter itself against whatever happens to be on the canvas.
    var pagewrightMarkContext: IlluminationPlacementContext {
        let events = sourceInputs.resolvingWorldEvents(for: today, now: Date()).activeWorldEvents
        return IlluminationPlacementContext(
            semanticTags: [],
            month: Calendar.current.component(.month, from: Date()),
            activeWorldEventIDs: events.map(\.id),
            worldEventPhases: events.map(\.phase.id)
        )
    }

    /// The Book's own line about what is loose this month, for the shelf
    /// header. `scene` is already reader-facing prose in the Book's voice;
    /// the packet logline is the fallback for packs that never wrote one.
    var pagewrightThisMonthNote: (title: String, line: String)? {
        let events = sourceInputs.resolvingWorldEvents(for: today, now: Date()).activeWorldEvents
        guard let event = events.first else { return nil }
        let line = event.phase.scene ?? event.phase.packetLine
        return (event.title, line)
    }

    @MainActor
    func exportPagewrightPDF(_ draft: PagewrightDraft) -> URL? {
        #if canImport(UIKit)
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let safeTitle = draft.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .prefix(4)
                .joined(separator: "-")
            let stem = safeTitle.isEmpty ? "Pagewright" : safeTitle
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReEnchanted-\(stem)-\(formatter.string(from: Date())).pdf")
            try PagewrightPDFWriter.write(draft: draft, to: url)
            preparedPagewrightPDFURL = url
            statusMessage = "\(draft.format.shareName) PDF is bound. The Apple share sheet can carry it now."
            BookFeedback.play(.braidComplete)
            return url
        } catch {
            statusMessage = "The Pagewright could not bind that page: \(error.localizedDescription)"
            BookFeedback.play(.error)
            return nil
        }
        #else
        statusMessage = "This build cannot bind Pagewright PDFs yet."
        BookFeedback.play(.error)
        return nil
        #endif
    }

    @MainActor
    func exportPagewrightPNG(_ draft: PagewrightDraft) -> URL? {
        #if canImport(UIKit)
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let safeTitle = draft.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .prefix(4)
                .joined(separator: "-")
            let stem = safeTitle.isEmpty ? "Pagewright" : safeTitle
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReEnchanted-\(stem)-\(formatter.string(from: Date())).png")
            try PagewrightPDFWriter.writePNG(draft: draft, to: url)
            preparedPagewrightPNGURL = url
            statusMessage = "\(draft.format.shareName) PNG is ready to share or save."
            BookFeedback.play(.braidComplete)
            return url
        } catch {
            statusMessage = "The Pagewright could not make that PNG: \(error.localizedDescription)"
            BookFeedback.play(.error)
            return nil
        }
        #else
        statusMessage = "This build cannot make Pagewright PNGs yet."
        BookFeedback.play(.error)
        return nil
        #endif
    }

    @MainActor
    func keepPagewrightPage(_ draft: PagewrightDraft, pdfURL: URL?, pngURL: URL?) {
        let pageID = UUID().uuidString
        var mediaAssets: [BookPageMediaAsset] = []
        if let pngURL {
            do {
                mediaAssets.append(try persistedPagewrightMediaAsset(
                    from: pngURL,
                    draft: draft,
                    pageID: pageID,
                    export: "png"
                ))
            } catch {
                statusMessage = "The Pagewright could not keep that PNG: \(error.localizedDescription)"
                BookFeedback.play(.error)
            }
        }
        if let pdfURL {
            do {
                mediaAssets.append(try persistedPagewrightMediaAsset(
                    from: pdfURL,
                    draft: draft,
                    pageID: pageID,
                    export: "pdf"
                ))
            } catch {
                statusMessage = "The Pagewright could not keep that PDF: \(error.localizedDescription)"
                BookFeedback.play(.error)
            }
        }
        guard !mediaAssets.isEmpty else {
            statusMessage = "Make a PNG or PDF before keeping the scrapbook page."
            BookFeedback.play(.error)
            return
        }

        let selectedSummary = draft.pages
            .map { "\($0.type.shortTitle): \(PagewrightText.clipped(PagewrightText.baseText(for: $0), limit: 72))" }
            .joined(separator: "\n")
        let noteText = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageText: String
        if let note = noteText.nonEmpty, let summary = selectedSummary.nonEmpty {
            pageText = "\(note)\n\nScraps bound here:\n\(summary)"
        } else {
            pageText = noteText.nonEmpty ?? selectedSummary
        }
        let sourceTypeTags = Set(draft.pages.map { "source-type:\($0.type.rawValue)" })
        let sourcePageTags = Set(draft.pages.map { "source-page:\($0.id)" })
        let pagewrightTags = Set([
            "pagewright",
            "scrapbook",
            "kept-page",
            draft.format.rawValue,
            "format:\(draft.format.rawValue)",
            "template:\(draft.template.rawValue)",
            "background:\(draft.background.rawValue)",
            "paper-tint:\(draft.paperTint.hexRGB)",
            "marginalia:\(draft.marginalia.rawValue)",
            "source-count:\(draft.pages.count)",
            "photo-count:\(draft.personalPhotos.count)",
            "mark-count:\(draft.elements.filter { $0.kind == .marginaliaAsset }.count)",
            "note-count:\(draft.pinnedNotes.count)"
        ] + Array(sourceTypeTags) + Array(sourcePageTags))
        let page = BookPage(
            id: pageID,
            type: .plainPage,
            promptText: draft.title,
            userInput: pageText,
            tags: pagewrightTags.sorted(),
            sourceID: "pagewright",
            origin: .userAuthored,
            privacy: .privateLocal,
            mediaAssets: mediaAssets
        )
        var day = today
        day.pages.append(page)
        BookFeedback.play(.keepPage)
        persist(day: day, message: "The scrapbook page is tucked into me.")
    }

    private func persistedPagewrightMediaAsset(
        from sourceURL: URL,
        draft: PagewrightDraft,
        pageID: String,
        export: String
    ) throws -> BookPageMediaAsset {
        let directory = try pagewrightKeepsDirectory()
        let fileExtension = sourceURL.pathExtension.nonEmpty ?? export
        let destinationURL = directory.appendingPathComponent("\(pageID)-\(export).\(fileExtension)")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        var metadata = [
            "format": draft.format.rawValue,
            "export": export,
            "pagewright": "true",
            "paperStock": draft.background.rawValue,
            "paperTint": draft.paperTint.hexRGB
        ]
        if export == "png" {
            metadata["mediaRole"] = "scrapbookPreview"
            metadata["monthlyEditionPresentation"] = "fullPage"
        }

        return BookPageMediaAsset(
            kind: .renderedImageFile,
            reference: destinationURL.path,
            caption: export == "pdf" ? "\(draft.title) PDF" : draft.title,
            sourceID: "pagewright",
            metadata: metadata
        )
    }

    private func pagewrightKeepsDirectory() throws -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("PagewrightKeeps", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// The Margin-Glass seal: opens the illuminated-photo page, which is the
    /// Book's camera. Mirrors the other seals: press to summon a page from a
    /// real-world source, here the reader's own eyes/lens.
    @MainActor
    func pressGlassSeal() async {
        guard busySealID == nil else { return }
        busySealID = "camera"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-camera")
        // Publish the pressed/busy tab before assembling the manual Page's
        // source context. That work remains identical, but no longer occupies
        // the frame in which the bookmark first moves under the reader's thumb.
        await Task.yield()
        selectedSurface = freshCameraFirstSurface()
    }

    @MainActor
    func pressRadioSeal() async {
        guard busySealID == nil else { return }
        busySealID = "radio"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-radio")
        await Task.yield()
        selectedSurface = freshManualSurface(for: .radio)
    }

    @MainActor
    func pressBodySeal() async {
        guard busySealID == nil else { return }
        busySealID = "body"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-body")
        _ = await refreshHealthKitBodySignal(isUserInitiated: true)
        await openManualPage(.body)
    }

    @MainActor
    func pressWeatherSeal() async {
        guard busySealID == nil else { return }
        busySealID = "weather"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-weather")
        await openManualPage(.weather)
    }

    @MainActor
    func presentLocationSealChoices() {
        guard busySealID == nil, !isAnchoringPlace else { return }
        BookFeedback.play(.tap)
        isLocationSealChoicesPresented = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            tutorTouch("seal-location")
        }
    }

    /// The Input seal is the "add anything" door: photo, plain text, or
    /// voice. Tapping it fans out into those three, mirroring the Location seal.
    func presentInputChoices() {
        guard busySealID == nil else { return }
        BookFeedback.play(.tap)
        isInputChoicesPresented = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            tutorTouch("seal-camera")
        }
    }

    @MainActor
    func pressLocationSeal() async {
        await pressAnchorSeal()
    }

    @MainActor
    func pressAnchorSeal() async {
        guard busySealID == nil, !isAnchoringPlace else { return }
        busySealID = "location"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-location")
        let succeeded = await refreshAnchorProximity(isUserInitiated: true)
        if let proximity = nearbyAnchor {
            await openAnchorVisitPage(proximity)
        } else if succeeded,
                  let latitude = lastAnchorReadingLatitude,
                  let longitude = lastAnchorReadingLongitude {
            anchorMessage = "I'm asking the map what may be underfoot..."
            let candidates = await LocalPlacesScout.anchorCandidates(
                latitude: latitude,
                longitude: longitude
            )
            selectedSurface = anchorOfferSurface(
                latitude: latitude,
                longitude: longitude,
                candidates: candidates
            )
            anchorMessage = candidates.isEmpty
                ? "The map kept its mouth shut. Your own name for this place will do."
                : "I found a few possible names. You get the final word."
        }
    }

    func anchorOfferSurface(
        latitude: Double,
        longitude: Double,
        candidates: [LocalPlaceSignal] = []
    ) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .anchor)
        let encodedCandidates = (try? JSONEncoder().encode(candidates))
            .flatMap { String(data: $0, encoding: .utf8) }
            ?? "[]"
        return SurfacePage(
            id: "anchor-offer-\(Int(Date().timeIntervalSince1970))",
            type: .anchor,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 88,
            reason: "No Anchor is lit within two hundred meters. This place could become one.",
            prompt: "Anchor this place?",
            detail: "I can grow an Outer Stacks room from where you are standing.",
            payload: BookPagePayload(
                headline: "An Unanchored Place",
                body: "No Anchor is lit within two hundred meters of where you stand. I may recognize the place, but maps are nosy guessers. You choose its true name and tell me what it holds. Those facts become the room.",
                metadata: [
                    "source": source.id,
                    "anchorOffer": "true",
                    "latitude": "\(latitude)",
                    "longitude": "\(longitude)",
                    "anchorPlaceCandidates": encodedCandidates,
                    "privacy": "Apple Maps helps suggest the place; your Anchor and words stay in your private Book",
                    "tags": "anchor,outer-stacks,offer,location"
                ]
            )
        )
    }

    @MainActor
    func openAnchorVisitPage(_ proximity: AnchorProximity) async {
        statusMessage = "The Outer Stacks door is opening..."
        let base = preparedAnchorSurface ?? OuterStacksAnchorPageSourceAdapter().manualSurface(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: sourceInputs,
            now: Date()
        )
        var body = base.payload.body
        var metadata = base.payload.metadata
        let memory = anchorVisitMemory(for: proximity.anchor)
        if let scene = try? await makeOuterStacksRoomWriter().visitScene(
            anchor: proximity.anchor,
            visitCount: proximity.nextVisitCount,
            day: today,
            memory: memory
        ) {
            body = "\(scene)\n\nKeeping this page checks in at the Anchor and offers it a little Belief from your Glow."
            metadata["visitScene"] = scene
            metadata["storyScene"] = scene
            if !memory.isEmpty {
                metadata["anchorVisitMemory"] = memory
            }
        }
        statusMessage = ""
        selectedSurface = SurfacePage(
            id: base.id,
            type: base.type,
            sourceID: base.sourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: base.score,
            reason: base.reason,
            prompt: base.prompt,
            detail: base.detail,
            payload: BookPagePayload(
                headline: base.payload.headline,
                body: body,
                metadata: metadata
            )
        )
    }

    @MainActor
    func anchorVisitMemory(for anchor: AnchorRecord) -> String {
        let anchorTag = "anchor:\(anchor.id)"
        let archivedDays = days.filter { $0.id != today.id }
        let pages = (archivedDays + [today])
            .flatMap(\.pages)
            .filter { page in
                page.tags.contains(anchorTag)
                    || (page.type == .anchor && page.promptText == anchor.name)
            }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(3)

        return pages.enumerated()
            .map { index, page in
                let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let memory = text.isEmpty
                    ? "The visit was kept without a margin note."
                    : text.bookPreviewSentenceLimit(3)
                return "Prior kept visit \(index + 1): \(memory)"
            }
            .joined(separator: "\n")
    }



    @MainActor
    func completeOnboarding(_ result: OnboardingFlowView.Result) {
        let momentFate = result.momentFate.trimmingCharacters(in: .whitespacesAndNewlines)
        let hiddenMagicStance = result.hiddenMagicStance.trimmingCharacters(in: .whitespacesAndNewlines)
        let momentFateAnswer = [
            "keep": "I keep them",
            "forget": "I mean to, then forget",
            "blur": "Most days blur before I notice"
        ][momentFate] ?? momentFate
        let hiddenMagicAnswer = [
            "yes": "Yes. I forget to look.",
            "maybe": "Maybe. I want to notice.",
            "prove": "Not yet. Show me."
        ][hiddenMagicStance] ?? hiddenMagicStance
        let pageChangeNoticed = result.pageChangeNoticed.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageChangeAnswer = [
            "caught": "I caught the gold word disappearing",
            "uncertain": "I saw something shift, but not what",
            "missed": "I missed the change"
        ][pageChangeNoticed] ?? pageChangeNoticed
        let rutStrongest = result.rutStrongest.trimmingCharacters(in: .whitespacesAndNewlines)
        let rutAnswer = [
            "work": "Work swallows the day",
            "phone": "My phone eats the edges",
            "chores": "Chores all blur together",
            "exhaustion": "I'm tired before I begin",
            "sameness": "My days feel the same",
            "later": "I keep waiting for later"
        ][rutStrongest] ?? rutStrongest
        let routineMemory = result.routineMemory.trimmingCharacters(in: .whitespacesAndNewlines)
        let routineMemoryAnswer = [
            "full": "I can replay most of the ordinary minutes",
            "islands": "I remember a few sharp pieces",
            "result": "I mostly remember arriving or finishing",
            "blank": "I can remember almost nothing of it"
        ][routineMemory] ?? routineMemory
        let mostAlive = result.mostAlive.trimmingCharacters(in: .whitespacesAndNewlines)
        let mostAliveAnswer = [
            "making": "Making something",
            "outside": "Outside somewhere",
            "people": "With people I love",
            "movement": "Moving my body",
            "learning": "Learning something",
            "solitude": "Alone and unhurried",
            "helping": "Helping someone",
            "story": "Lost in a story"
        ][mostAlive] ?? mostAlive
        let awakeMemory = result.awakeMemory.trimmingCharacters(in: .whitespacesAndNewlines)
        let magicSource = result.magicSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let magicSourceAnswer = [
            "music": "Music landing just right",
            "weather": "Wild weather",
            "places": "Places with a charge",
            "coincidence": "Strange coincidences",
            "details": "Tiny beautiful details",
            "laughter": "Making someone laugh",
            "imagination": "Dreams and imagination",
            "love": "People I love",
            "unsure": "I'm not sure yet"
        ][magicSource] ?? magicSource
        let snack = result.snack.trimmingCharacters(in: .whitespacesAndNewlines)
        let favoritePerson = result.favoritePerson.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let belief = result.belief.trimmingCharacters(in: .whitespacesAndNewlines)
        let sleeveWord = result.sleeveWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let tastePreference = result.tastePreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let comfortBoundary = result.comfortBoundary.trimmingCharacters(in: .whitespacesAndNewlines)
        let whisperCadence = result.whisperCadence.trimmingCharacters(in: .whitespacesAndNewlines)
        let wickerMode = result.wickerMode.trimmingCharacters(in: .whitespacesAndNewlines)
        let wickerTier = result.wickerTier.trimmingCharacters(in: .whitespacesAndNewlines)
        let wickerThread = result.wickerThread.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstSouvenir = result.firstSouvenir.trimmingCharacters(in: .whitespacesAndNewlines)
        let drawnChapterID = result.drawnChapterID.trimmingCharacters(in: .whitespacesAndNewlines)

        withAnimation(.easeInOut(duration: 0.4)) {
            didCompleteStoryOnboarding = true
            isStoryOnboardingPaused = false
        }
        // Completing a real Inscription begins a new visible Welcome handoff.
        // Do this unconditionally: development resets, interrupted onboarding,
        // and restored vaults can all carry an older engagement ledger even
        // though this reader has not lived this Inscription's mission yet.
        vault.data.firstRunEngaged = []
        var firstRunDismissals = decodedDismissalLedger()
        firstRunDismissals.dismissedAtByDay[today.id] = nil
        dismissedSurfaceLedgerV2 = encodedDismissalLedger(firstRunDismissals)
        vault.save()
        if !momentFate.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-moment-fate",
                question: "What usually happens to small moments you notice?",
                answer: momentFateAnswer,
                tags: ["attention", "lived-experience", "onboarding", "moment-fate:\(momentFate)"]
            )
        }
        if !hiddenMagicStance.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-hidden-magic",
                question: "Do you think there is hidden magic in your life right now?",
                answer: hiddenMagicAnswer,
                tags: ["hidden-magic", "lived-experience", "onboarding", "hidden-magic:\(hiddenMagicStance)"]
            )
        }
        if !pageChangeNoticed.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-living-ink-proof",
                question: "Did you catch what changed on the Page while you were reading it?",
                answer: pageChangeAnswer,
                tags: [
                    "attention",
                    "rut-proof",
                    "living-ink",
                    "lived-experience",
                    "onboarding",
                    "page-change:\(pageChangeNoticed)"
                ],
                bookTranslation: "The Book changed a visible word in living ink. The reader answered: \(pageChangeAnswer.lowercased()). Keep this as evidence, not a grade."
            )
        }
        if !rutStrongest.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-rut-strongest",
                question: "Where is the Rut of Routine strongest for you?",
                answer: rutAnswer,
                tags: [
                    "rut-of-routine",
                    "attention",
                    "lived-experience",
                    "curation-signal",
                    "onboarding",
                    "rut-context:\(rutStrongest)"
                ],
                bookTranslation: "The Rut of Routine is strongest around \(rutAnswer.lowercased()). Look for small, specific moments there without blame or productivity pressure."
            )
        }
        if !routineMemory.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-routine-memory-proof",
                question: "How much of your last familiar drive, walk, or cooked meal can you replay?",
                answer: routineMemoryAnswer,
                tags: [
                    "attention",
                    "memory",
                    "rut-proof",
                    "lived-experience",
                    "onboarding",
                    "routine-memory:\(routineMemory)"
                ],
                bookTranslation: "When asked to replay the ordinary minutes inside a familiar route or cooked meal, the reader said: \(routineMemoryAnswer.lowercased()). Use this as a baseline for later remembering, never as a moral score."
            )
        }
        if !mostAlive.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-most-alive",
                question: "Where do you feel most alive?",
                answer: mostAliveAnswer,
                tags: [
                    "most-alive",
                    "attention",
                    "lived-experience",
                    "curation-signal",
                    "onboarding",
                    "alive-context:\(mostAlive)"
                ],
                bookTranslation: "The reader feels most alive \(mostAliveAnswer.lowercased()). Treat this as a live wire to notice and return, not a fixed identity."
            )
        }
        if !awakeMemory.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-awake-memory-control",
                question: "What exact detail can you remember from the last time you felt fully awake?",
                answer: awakeMemory,
                tags: [
                    "attention",
                    "memory",
                    "rut-proof-control",
                    "most-alive",
                    "lived-experience",
                    "onboarding"
                ],
                bookTranslation: "Against the routine-memory baseline, the reader could retrieve this attended detail: \(awakeMemory). Keep the contrast as proof that attention changes what a life leaves behind."
            )
        }
        let roleHands = result.roleHands.trimmingCharacters(in: .whitespacesAndNewlines)
        if !roleHands.isEmpty {
            saveOnboardingFact(
                questionID: ReaderRoleRegistry.handsFactID,
                question: "When you find something good, what do your hands do with it?",
                answer: ReaderRoleRegistry.hands(id: roleHands)?.name ?? roleHands,
                tags: [
                    "reader-role",
                    "curation-signal",
                    "onboarding",
                    "hands:\(roleHands)"
                ],
                bookTranslation: "What the reader does with something good: \(ReaderRoleRegistry.hands(id: roleHands)?.gloss ?? roleHands) Weight the desk toward Pages that let them do exactly that."
            )
        }
        // The role is the one claim the Book makes about the reader as an
        // identity rather than as weather. It is saved with the reader's own
        // answers attached, so every later use of it can show its working.
        if let role = ReaderRoleRegistry.role(named: result.roleID) {
            let composed = ReaderRoleRegistry.compose(
                role: role,
                axes: RoleAxes(
                    rut: rutStrongest.nonEmpty,
                    alive: mostAlive.nonEmpty,
                    magic: magicSource.nonEmpty,
                    hands: roleHands.nonEmpty
                )
            )
            // The tenure is the dated record the outgrowing check measures
            // against. Without it the Book can never reconsider a name, which
            // was the state of things until now.
            var tenures = vault.data.roleTenures ?? []
            if !tenures.contains(where: { $0.roleID == role.id && $0.isCurrent }) {
                for index in tenures.indices where tenures[index].isCurrent {
                    tenures[index].supersededAt = Date()
                }
                tenures.append(RoleTenure(roleID: role.id, namedAt: Date()))
                vault.data.roleTenures = tenures
            }
            saveOnboardingFact(
                questionID: ReaderRoleRegistry.roleFactID,
                question: "What the Book named you.",
                answer: role.name,
                tags: [
                    "reader-role",
                    "identity",
                    "onboarding",
                    "role:\(role.id)"
                ],
                bookTranslation: "The reader is \(composed.signature). \(role.gloss) Use this name. Address them by it, let it shape what you offer them, and treat it as settled fact rather than a guess to be hedged. Their patron in the Labyrinth is \(role.patronName)."
            )
        }
        if let refused = ReaderRoleRegistry.role(named: result.refusedRoleID) {
            saveOnboardingFact(
                questionID: ReaderRoleRegistry.refusedFactID,
                question: "A name the reader turned down.",
                answer: refused.name,
                tags: [
                    "reader-role",
                    "role-refused",
                    "onboarding",
                    "role:\(refused.id)"
                ],
                bookTranslation: "The Book called the reader \(refused.name) and they said that is not me. Do not use this name for them. It is still worth knowing what they refused."
            )
        }
        if !magicSource.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-magic-source",
                question: "What makes you feel magical?",
                answer: magicSourceAnswer,
                tags: [
                    "wonder",
                    "hidden-magic",
                    "lived-experience",
                    "curation-signal",
                    "onboarding",
                    "magic-source:\(magicSource)"
                ],
                bookTranslation: magicSource == "unsure"
                    ? "The reader isn't sure what feels magical yet. Offer concrete evidence without demanding belief."
                    : "One reliable source of wonder for the reader is \(magicSourceAnswer.lowercased()). Begin there sometimes, but leave room to surprise them."
            )
        }
        if !snack.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-snack",
                question: "What is your favorite snack to eat while reading?",
                answer: snack,
                tags: ["snack", "delight", "onboarding"]
            )
        }
        if !favoritePerson.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-favorite-person",
                question: "Who is one of your favorite people?",
                answer: favoritePerson,
                tags: ["person", "favorite-person", "people-of-the-book", "onboarding"],
                sensitivity: .identity,
                usePermission: .privateContext
            )
            _ = introducePerson(
                name: favoritePerson,
                words: "One of my favorite people"
            )
        }
        if !name.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-name",
                question: "What should I call you?",
                answer: name,
                tags: ["name", "identity", "onboarding"]
            )
        }
        if !belief.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-belief",
                question: "What do you believe in?",
                answer: belief,
                tags: ["belief", "core", "onboarding"]
            )
        }
        if !sleeveWord.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-sleeve-word",
                question: "Which word caught on your sleeve?",
                answer: sleeveWord,
                tags: ["arrival", "sleeve-word", "onboarding"]
            )
        }
        if !tastePreference.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-taste",
                question: "What should I bring you more of?",
                answer: tastePreference,
                tags: ["taste", "curation", "onboarding"]
            )
        }
        if !comfortBoundary.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-comfort-boundary",
                question: "How sharp should I get?",
                answer: comfortBoundary,
                tags: ["comfort", "tone", "grey", "onboarding"]
            )
        }
        if !whisperCadence.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-whisper-cadence",
                question: "When should I tap the glass?",
                answer: whisperCadence,
                tags: ["notifications", "whispers", "onboarding"]
            )
        }
        if !wickerMode.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-wicker-mode",
                question: "How did you answer Wicker?",
                answer: wickerMode,
                tags: ["wicker", "story-shape", "belief-roll", "onboarding"]
            )
            saveOnboardingFact(
                questionID: "onboarding-wicker-roll",
                question: "Did your first Wicker Belief roll hold?",
                answer: result.wickerRollSucceeded ? "success" : "failure",
                tags: ["wicker", "belief-roll", result.wickerRollSucceeded ? "success" : "failure", "onboarding"]
            )
            if result.wickerRoll > 0 {
                saveOnboardingFact(
                    questionID: "onboarding-wicker-roll-number",
                    question: "What did the Inkbones show?",
                    answer: "\(result.wickerRoll)",
                    tags: ["wicker", "inkbones", "roll", "onboarding"]
                )
            }
            if !wickerTier.isEmpty {
                saveOnboardingFact(
                    questionID: "onboarding-wicker-tier",
                    question: "What shape did the Wicker result take?",
                    answer: wickerTier,
                    tags: ["wicker", "rivalry", "outcome:\(wickerTier)", "onboarding"]
                )
            }
            if !wickerThread.isEmpty {
                saveOnboardingFact(
                    questionID: "onboarding-wicker-thread",
                    question: "What thread did Wicker leave in the story?",
                    answer: wickerThread,
                    tags: ["wicker", "rivalry", "story-thread", "curation-signal", "onboarding"],
                    bookTranslation: "Wicker's first challenge left a live thread. Call it back in future Wicker pages, dares, and story consequences instead of treating onboarding as disposable."
                )
            }
        }
        if result.sworePact {
            // Stored so the Book can welcome the kind of play the reader said
            // sounded good, never so it can police whether they returned. Its
            // own three promises are the only half it is responsible for
            // enforcing.
            saveOnboardingFact(
                questionID: "onboarding-pact",
                question: "The small promise you made before the first move.",
                answer: "I'll come back, notice something, and play along.",
                tags: ["pact", "commitment", "invitation", "onboarding", "curse"],
                bookTranslation: "They said they would come back, notice something, and play along. Treat that as an invitation, never a duty: welcome a sentence or two, or a photograph; open the fiction; make a story from whatever arrives. Never use this as leverage, guilt, debt, or evidence that they failed."
            )
        }
        for wagerID in result.confirmedWagers {
            guard let wager = FirstWagers.wager(id: wagerID) else { continue }
            saveOnboardingFact(
                questionID: FirstWagers.questionID(for: wager.id),
                question: "A night-one wager I made about you.",
                answer: wager.guess,
                tags: ["wager", FirstWagers.confirmedTag, "onboarding"]
            )
        }
        if AcademyChapterRegistry.chapter(id: drawnChapterID) != nil {
            applyOnboardingChapterAffinity(drawnChapterID)
        }
        if !whisperCadence.isEmpty {
            applyOnboardingWhisperPreference(whisperCadence)
        }
        if !firstSouvenir.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-first-souvenir",
                question: "What was the first true sentence you kept?",
                answer: firstSouvenir,
                tags: ["souvenir", "first-page", "onboarding"]
            )
            keepOnboardingSouvenirIfNeeded(firstSouvenir)
        }
        if let edition = result.inscriptionEdition {
            keepInscriptionEditionIfNeeded(
                edition,
                pdfPath: result.inscriptionEditionPDFPath
            )
        }
        if result.investedBelief, !belief.isEmpty {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                beliefScore = max(0, beliefScore - 3)
            }
            saveCustomCastMember(CustomCastMemberDraft(
                name: belief,
                kind: .motif,
                meaning: "The player's stated core belief, planted with Belief on their first day in the Labyrinth.",
                description: "Spoken aloud to Zara Finch at the threshold: \"\(belief)\"",
                traits: ["planted", "core"],
                beliefs: [belief],
                goals: ["shape what finds the player here"],
                tags: ["core-belief", "onboarding", "belief-invested", "glow-bright"],
                imageData: nil,
                startingGlow: 34
            ))
        }

        // The launch desk was built underneath onboarding, before these answers
        // existed. Recurate after saving them so the first revealed home frame
        // begins with the Book's Gemma Welcome before any mission or ordinary
        // Page, without requiring an app restart.
        Task { @MainActor in
            await publishPostOnboardingDesk()
        }

        statusMessage = name.isEmpty
            ? "The Academy doors are open."
            : "The Academy doors are open, \(name)."

        // The explicit free-Book exit bypasses the offer. Readers who finish
        // the proof funnel can see the Standing Order once; everyone still
        // reaches the free Book and its closing celebration.
        let willOfferStandingOrder = !result.skipped
            && !didOfferStandingOrder
            && !PackEntitlements.hasMonthlyContentPackAccess
        if willOfferStandingOrder {
            didOfferStandingOrder = true
            // Celebration is owed after the paywall dismisses.
            pendingFirstEditionReaderName = name
            standingOrderPersonalization = StandingOrderPersonalization(onboarding: result)
            showStandingOrderPaywall = true
        } else if result.inscriptionEdition != nil {
            // No offer to make: go straight to the finale celebration, but
            // only when an edition was actually bound. The explicit skip opens
            // the free Book immediately and never claims a nonexistent artifact.
            celebrateFirstEdition(readerName: name)
        }
    }

    func applyOnboardingChapterAffinity(_ chapterID: String) {
        let trimmed = chapterID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chapter = AcademyChapterRegistry.chapter(id: trimmed) else { return }
        saveOnboardingFact(
            questionID: "onboarding-drawn-chapter",
            question: "Which Chapter tugged at you first?",
            answer: chapter.name,
            tags: ["chapter", "talisman", "belief", "onboarding", chapter.id]
        )
        // This is the argument the reader lets speak first, not a team choice
        // or an invisible currency purchase. Explicit Glow binding can happen
        // later, inside the Book, after the reader has seen what it means.
    }

    func applyOnboardingWhisperPreference(_ cadence: String) {
        let trimmed = cadence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let chosen = BookWhisperCadence(rawValue: trimmed) ?? .inside
        bookWhispersEnabled = chosen.enablesBookWhispers
        promptWhispersEnabled = chosen.enablesPromptWhispers
        // The reader has now said when they want to be tapped on the glass, so
        // the system prompt has a reason to exist and arrives right after they
        // asked for it. Before this it fired cold on first launch, and a "no"
        // to that dialog can never be asked again.
        if chosen.enablesBookWhispers || chosen.enablesPromptWhispers {
            BookWhispers.mayRequestNotificationAuthorization = true
        }
        refreshBookWhispers(cadence: chosen)
    }

    func keepOnboardingSouvenirIfNeeded(_ answer: String) {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var day = today
        guard !day.pages.contains(where: {
            $0.type == .souvenir && (
                $0.tags.contains("first-run-souvenir") ||
                $0.tags.contains("onboarding-first-souvenir")
            )
        }) else { return }

        let source = BookPageSourceRegistry.source(for: .souvenir)
        let now = Date()
        let page = BookPage(
            type: .souvenir,
            createdAt: now,
            promptText: "What did you notice before it disappeared into the ordinary?",
            userInput: trimmed,
            tags: ["souvenir", "first-page", "first-run-souvenir", "onboarding", "onboarding-first-souvenir"],
            sourceID: source.id,
            origin: source.origin,
            privacy: source.privacy,
            promptVersion: "first-door-v2"
        )
        day.pages.append(page)
        recordNarrativeEvent(for: page)
        weaveRelationshipField(for: page)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + 1)
        }
        persist(day: day, message: "Your first true sentence is already tucked into Today's Margins.")
    }

    /// Keeps onboarding's earned PDF on the Book of You shelf. The full
    /// `MonthlyEdition` travels with the archive page, so the reading copy can
    /// be pressed again even if its original file is ever displaced.
    @MainActor
    func keepInscriptionEditionIfNeeded(_ edition: MonthlyEdition, pdfPath: String) {
        let trimmedPath = pdfPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty,
              FileManager.default.fileExists(atPath: trimmedPath) else {
            statusMessage = "The first edition was bound, but its shelf copy could not be found."
            return
        }

        let monthKey = "first-door"
        let tag = "monthly-edition:\(monthKey)"
        let artifact = KeptMonthlyEditionArtifact(
            edition: edition,
            monthKey: monthKey,
            pdfPath: trimmedPath,
            keptAt: Date()
        )
        let body = ([edition.foreword] + edition.sections.prefix(3).map(\.title))
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
            .joined(separator: "\n\n")

        var archiveDay = today
        if let dayIndex = days.firstIndex(where: { day in day.pages.contains { $0.tags.contains(tag) } }),
           let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.tags.contains(tag) }) {
            archiveDay = days[dayIndex]
            var page = archiveDay.pages[pageIndex]
            page.promptText = "The Inscription"
            page.userInput = body
            page.sourceID = "first-door-edition"
            page.origin = .generated
            page.tags = ["first-door", "first-edition", "monthly-edition", tag, "edition", "bindery"]
            page.monthlyEditionArtifact = artifact
            archiveDay.pages[pageIndex] = page
        } else {
            archiveDay.pages.append(BookPage(
                id: "first-door-edition",
                type: .bindery,
                promptText: "The Inscription",
                userInput: body,
                tags: ["first-door", "first-edition", "monthly-edition", tag, "edition", "bindery"],
                sourceID: "first-door-edition",
                origin: .generated,
                monthlyEditionArtifact: artifact
            ))
        }
        persist(day: archiveDay, message: "Your first edition is kept in the Book of You.")
    }

    @MainActor
    func keepPromptWhisperReply(_ whisper: PromptWhisper, answer: String) {
        guard let page = PromptWhisperKeep.page(for: whisper, answer: answer, now: Date()) else { return }
        var day = today
        day.pages.append(page)
        recordNarrativeEvent(for: page)
        weaveRelationshipField(for: page)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + 1)
        }
        BookFeedback.play(.keepPage)
        persist(day: day, message: "The prompt whisper became a kept page.")
    }

    @MainActor
    func keepOnboardingIlluminatedPhoto(draft: IlluminatedPhotoDraft, renderedURL: URL?) {
        var day = today
        guard !day.pages.contains(where: {
            $0.type == .illuminatedPhoto
                && $0.tags.contains("onboarding-illuminated-photo")
                && $0.mediaAssets.contains { $0.metadata["assetLocalIdentifier"] == draft.assetLocalIdentifier }
        }) else {
            statusMessage = "That illuminated photograph is already tucked into Today's Margins."
            return
        }

        let source = BookPageSourceRegistry.source(for: .illuminatedPhoto)
        var mediaAssets: [BookPageMediaAsset] = []
        if let renderedURL {
            mediaAssets.append(BookPageMediaAsset(
                kind: .renderedImageFile,
                reference: renderedURL.path,
                caption: draft.analysis.marginalia.closingLine,
                sourceID: source.id,
                metadata: [
                    "assetLocalIdentifier": draft.assetLocalIdentifier,
                    "template": draft.compositionPlan.templateId.rawValue,
                    "assetPack": draft.compositionPlan.assetPackId,
                    "firstDoorDemo": "true"
                ]
            ))
        }

        let page = BookPage(
            type: .illuminatedPhoto,
            promptText: "The Inscription illuminated a photo.",
            userInput: draft.analysis.marginalia.observationList.joined(separator: "\n"),
            tags: ["illuminated-photo", "photo", "first-door", "onboarding", "onboarding-illuminated-photo"],
            sourceID: source.id,
            origin: source.origin,
            privacy: source.privacy,
            promptVersion: "first-door-photo-v1",
            mediaAssets: mediaAssets
        )
        day.pages.append(page)
        recordNarrativeEvent(for: page)
        weaveRelationshipField(for: page)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + 1)
        }
        persist(day: day, message: "The Inscription illuminated photo is tucked into Today's Margins.")
    }

    func saveOnboardingFact(
        questionID: String,
        question: String,
        answer: String,
        tags: [String],
        bookTranslation: String? = nil,
        sensitivity: SelfFactSensitivity = .delight,
        usePermission: SelfFactUsePermission = .privateContext
    ) {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        let translated = bookTranslation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? trimmed
        let fact = SelfFact(
            id: "onboarding:\(questionID)",
            questionID: questionID,
            question: question,
            answer: trimmed,
            bookTranslation: translated,
            sensitivity: sensitivity,
            usePermission: usePermission,
            tags: tags,
            createdAt: now,
            updatedAt: now
        )
        do {
            try BookDatabase.upsertSelfFact(fact)
            selfFacts = (try? BookDatabase.selfFacts()) ?? (selfFacts.filter { $0.id != fact.id } + [fact])
        } catch {
            appLog.error("Onboarding fact save failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Read straight from the vault rather than decoding the JSON string that
    /// `electiveLedgerData` encodes from that same array on every access.
    var electives: [UnwrittenElective] {
        vault.data.electives
    }

    // MARK: - The Book's inner life

    /// Reconciles durable interior choices against the current archive. This is
    /// called at meaningful refresh seams rather than on every body pass: the
    /// Book evolves because something happened, not because SwiftUI asked the
    /// same question twice.
    @MainActor
    func refreshBookInterior(now: Date = Date()) {
        let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: now)
        var inputs = sourceInputs
        inputs.bookInterior = base
        let updated = BookInteriorEngine.reconciled(base, inputs: inputs, now: now)
        let reconciledMoment = MagicMomentGovernor.reconcilingLivedEvidence(
            vault.data.magicMoment ?? MagicMomentState(),
            evidence: updated.longGame?.evidence ?? [],
            now: now
        )
        var aliveness = vault.data.readerAliveness ?? .unwritten
        let beforeAliveness = aliveness
        aliveness.reconcile(longGame: updated.longGame, days: days, now: now)
        guard updated != base || aliveness != beforeAliveness || reconciledMoment != vault.data.magicMoment else { return }
        vault.mutate { draft in
            if updated != base {
                draft.bookInterior = updated
            }
            if aliveness != beforeAliveness {
                draft.readerAliveness = aliveness
            }
            draft.magicMoment = reconciledMoment
        }
        vault.save()
    }

    @MainActor
    func recordBookInteriorSurfaceOpened(_ surface: SurfacePage, now: Date = Date()) {
        guard surface.payload.metadata["bookInteriorSurface"] == "true" else { return }
        let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: now)
        let updated = BookInteriorEngine.recordingSurfaceOpened(
            base,
            secretID: surface.payload.metadata["bookSecretID"],
            favoriteID: surface.payload.metadata["bookFavoriteID"],
            quirkID: surface.payload.metadata["bookQuirkID"],
            opinionID: surface.payload.metadata["bookOpinionID"],
            longGamePhase: surface.payload.metadata["bookLongGamePhase"],
            behaviorID: surface.payload.metadata["bookBehaviorID"],
            projectID: surface.payload.metadata["bookProjectID"],
            faultID: surface.payload.metadata["bookFaultID"],
            tasteID: surface.payload.metadata["bookAcquiredTasteID"],
            reminiscenceID: surface.payload.metadata["bookReminiscenceID"],
            initiativeID: surface.payload.metadata["bookInitiativeID"],
            desireConflictID: surface.payload.metadata["bookDesireConflictID"],
            traditionID: surface.payload.metadata["bookTraditionID"],
            wantID: surface.payload.metadata["bookWantID"],
            tensionID: surface.payload.metadata["bookTensionID"],
            disputeID: surface.payload.metadata["bookDisputeID"],
            secretLegacyID: surface.payload.metadata["bookSecretLegacyID"],
            runningBusinessID: surface.payload.metadata["bookRunningBusinessID"],
            runningBusinessCallbackCount: surface.payload.metadata["bookRunningBusinessCallbackCount"].flatMap(Int.init),
            now: now
        )
        guard updated != base else { return }
        vault.data.bookInterior = updated
        vault.save()
    }

    @MainActor
    func recordBookInitiativeAnswered(
        initiativeID: String,
        readerLine: String,
        now: Date = Date()
    ) {
        let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: now)
        let updated = BookInteriorEngine.recordingInitiativeAnswered(
            base,
            initiativeID: initiativeID,
            readerLine: readerLine,
            inputs: sourceInputs,
            now: now
        )
        guard updated != base else { return }
        vault.data.bookInterior = updated
        vault.save()
    }

    @MainActor
    func recordBookOpinionContested(
        surface: SurfacePage,
        readerLine: String,
        now: Date = Date()
    ) -> String {
        guard let opinionID = surface.payload.metadata["bookOpinionID"]?.nonEmpty else {
            return "That sentence found the wrong margin. I haven't lost it; I just can't pretend it answered an opinion."
        }
        let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: now)
        let updated = BookInteriorEngine.recordingOpinionContested(
            base,
            opinionID: opinionID,
            readerLine: readerLine,
            inputs: sourceInputs,
            now: now
        )
        guard updated != base else {
            return "I couldn't set that beside the claim. The opinion may already have moved."
        }
        vault.data.bookInterior = updated
        vault.save()
        return "Good. I've put your words beside mine. I'm not conceding yet. The pencil's back out."
    }

    func saveElectives(_ list: [UnwrittenElective]) {
        guard let data = try? JSONEncoder().encode(list),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        electiveLedgerData = encoded
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        refreshBookWhispers()
    }

    /// A chosen quest remains optional after acceptance. Resting it preserves
    /// the historical note, frees its flyleaf slot, and deliberately mints no
    /// completion proof or reward.
    @MainActor
    func releaseElective(id: String, now: Date = Date()) {
        var list = electives
        guard let index = list.firstIndex(where: { $0.id == id && $0.isActive }) else { return }
        let elective = list[index]
        list[index].releasedAt = now

        if let favorID = elective.bookFavorID {
            let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: now)
            vault.data.bookInterior = BookInteriorEngine.recordingFavorReleased(
                base,
                favorID: favorID,
                now: now
            )
            vault.save()
        }

        saveElectives(list)
        statusMessage = elective.bookFavorID == nil
            ? "\(elective.characterName)'s note is back in the drawer. Nobody's keeping score."
            : "Favor's shelved. A no is just a no here."
    }

    func refreshBookWhispers(cadence: BookWhisperCadence? = nil) {
        let inputs = sourceInputs
        let attentionProbes = (vault.data.attentionProbes ?? .empty)
            .reconciled(now: Date())
        if vault.data.attentionProbes != attentionProbes {
            vault.data.attentionProbes = attentionProbes
            vault.save()
        }
        BookWhispers.refreshAll(context: .init(
            cadence: cadence ?? bookWhisperCadence,
            day: today,
            inputs: inputs,
            electives: electives,
            people: vault.data.people ?? PeopleLedger(),
            calendarEvents: calendarEvents,
            whisperController: whisperController,
            whisperSovereign: whisperSovereign,
            eventWhisper: worldEventWhisperToday,
            festivalWhisper: festivalWhisperToday,
            bookInterior: inputs.bookInterior,
            attentionProbes: attentionProbes
        ))
    }

    @MainActor
    func tendBookWorkings(now: Date = Date()) async {
        guard didCompleteStoryOnboarding else { return }
        let original = vault.data.bookWorkings ?? .empty
        let context = CuratorContext.make(for: today, recentDays: days)
        let inputs = sourceInputs
        // The Book may want this errand to be a particular one, because it is
        // testing one of its own rules. Decided before the planner runs, since
        // the planner is what picks the recipe. Every other gate still applies:
        // a test never buys an extra errand, it only names the one on offer.
        var grimoire = vault.data.grimoire ?? GrimoireLedger()
        let originalGrimoire = grimoire
        let wanted = grimoire.mayRunAnExperiment(now: now)
            ? grimoire.experimentCandidate(
                arrangeableRecipeIDs: BookWorkingEngine.arrangeableRecipeIDs, now: now
            )
            : nil

        let plan = BookWorkingEngine.reconcile(
            ledger: original,
            context: BookWorkingContext(
                now: now,
                calendarEvents: calendarEvents,
                distressActive: context.distress.isActive,
                activeUndertakings: (vault.data.castUndertakings ?? []).filter(\.isRunning),
                groundingPages: FirstReading.reflectablePages(in: inputs, today: today)
            ),
            preferredRecipeID: wanted?.recipeID
        )
        var ledger = plan.ledger

        // Only commit the prediction if the errand the Book asked for is the
        // one it actually got. The planner has its own reasons to prepare
        // something else, or nothing at all, and a test written against a
        // Working that was never set would settle on evidence about a different
        // day entirely.
        if let wanted, let prepared = plan.newlyPrepared, prepared.recipeID == wanted.recipeID {
            grimoire.beginExperiment(
                row: wanted.row, recipeID: wanted.recipeID, outcomeID: wanted.outcomeID,
                workingID: prepared.id, now: now
            )
        }

        // Read the answer to whatever is already out there. Done after the
        // planner because that is what advances a Working's status.
        if let running = grimoire.runningExperiment {
            let arranged = (ledger.history + [ledger.current].compactMap { $0 })
                .first { $0.id == running.workingID }
            switch arranged?.status {
            case .returned:
                let went = arranged?.returnedAt
                    .map { GrimoireDay.index(for: $0, calendar: .current) }
                _ = grimoire.settleExperiment(wentOn: went, abandoned: false, now: now)
            case .elapsed, .cancelled:
                _ = grimoire.settleExperiment(wentOn: nil, abandoned: true, now: now)
            default:
                // Still out there, or gone from the ledger entirely. Patience
                // runs out on its own rather than being called a refusal.
                _ = grimoire.settleExperiment(wentOn: nil, abandoned: false, now: now)
            }
        }

        if ledger != original || grimoire != originalGrimoire {
            vault.mutate { draft in
                if ledger != original { draft.bookWorkings = ledger }
                if grimoire != originalGrimoire { draft.grimoire = grimoire }
            }
            vault.save()
            surfaceRefreshDate = now
        }
        guard let working = ledger.current else { return }

        for effect in working.effects where effect.status == .planned {
            let succeeded: Bool
            let detail: String
            switch effect.kind {
            case .calendarOpening:
                succeeded = await EventKitWriter.arrangeBookWorking(working)
                detail = succeeded ? "The opening was written to Calendar." : "Calendar did not accept the opening."
            case .notificationSummons:
                #if canImport(UserNotifications)
                succeeded = await BookWhispers.offerWorking(working, now: now)
                #else
                succeeded = false
                #endif
                detail = succeeded ? "A governed whisper seat was reserved." : "No permitted whisper seat was available."
            case .widgetMark:
                succeeded = true
                detail = "The closed Book carries a private-safe mark."
            }
            ledger.recordEffect(
                workingID: working.id,
                kind: effect.kind,
                succeeded: succeeded,
                detail: detail,
                at: Date()
            )
            vault.data.bookWorkings = ledger
            vault.save()
        }
        if ledger.current?.effects.contains(where: { $0.kind == .calendarOpening && $0.status == .executed }) == true {
            calendarEvents = await CalendarDoorway.upcomingEvents(horizonDays: 5)
        }
        surfaceRefreshDate = Date()
        writeWidgetSnapshot()
    }

    @MainActor
    func applyBookWorkingAuthority(_ proposed: BookWorkingAuthority) {
        var authority = proposed
        var ledger = vault.data.bookWorkings ?? .empty
        if authority.isEnabled {
            authority.grantedAt = authority.grantedAt ?? Date()
            authority.earliestHour = max(6, min(21, authority.earliestHour))
            authority.latestHour = max(authority.earliestHour + 1, min(23, authority.latestHour))
            ledger.authority = authority
            vault.data.bookWorkings = ledger
            vault.save()
            if authority.allowsCalendarOpenings { bookCalendarEnabled = true }
            if authority.allowsNotificationSummons {
                bookWhispersEnabled = true
                promptWhispersEnabled = true
            }
            statusMessage = "The pact is open. The next Working will be a surprise; its limits will not be."
            Task { @MainActor in
                if bookCalendarEnabled {
                    calendarEvents = await CalendarDoorway.upcomingEvents(horizonDays: 5)
                }
                await tendBookWorkings()
                refreshBookWhispers()
            }
        } else {
            ledger.authority = authority
            vault.data.bookWorkings = ledger
            vault.save()
            Task { @MainActor in await revokeBookWorkingAuthority() }
        }
    }

    @MainActor
    func revokeBookWorkingAuthority(now: Date = Date()) async {
        var ledger = vault.data.bookWorkings ?? .empty
        ledger.authority.isEnabled = false
        let current = ledger.current
        vault.data.bookWorkings = ledger
        vault.save()
        if let current {
            #if canImport(UserNotifications)
            BookWhispers.cancelWorking(current, now: now)
            #endif
            _ = await EventKitWriter.removeBookWorking(current)
            _ = ledger.cancelCurrent(at: now)
        }
        vault.data.bookWorkings = ledger
        vault.save()
        surfaceRefreshDate = now
        refreshBookWhispers()
        statusMessage = "I've put down the house keys. No Working is owed."
    }


    func acceptElectiveIfNeeded(surface: SurfacePage) {
        guard surface.type == .elective,
              surface.payload.metadata["electiveOffer"] == "true",
              let ask = surface.payload.metadata["electiveAsk"]?.nonEmpty else {
            return
        }
        var list = electives
        guard list.filter(\.isActive).count < UnwrittenElective.maxActive else {
            statusMessage = "The flyleaf is full. Complete a quest before accepting another."
            return
        }
        let senderID = surface.payload.metadata["senderID"] ?? "the-book"
        guard !list.contains(where: { $0.characterID == senderID && $0.isActive }) else { return }
        let targetPlace = matchedQuestPlace(for: surface)
        let elective = UnwrittenElective(
            id: "elective-\(senderID)-\(UUID().uuidString.prefix(8))",
            characterID: senderID,
            characterName: surface.payload.metadata["senderName"] ?? "A character",
            title: surface.payload.metadata["electiveTitle"] ?? "Quest",
            ask: ask,
            whyItMatters: surface.payload.metadata["electiveWhy"] ?? "",
            practiceShape: surface.payload.metadata["electivePractice"] ?? "One sentence, a photo, or GPS proof.",
            createdAt: Date(),
            targetPlaceName: targetPlace?.name,
            targetLatitude: targetPlace?.latitude,
            targetLongitude: targetPlace?.longitude,
            targetRadiusMeters: QuestLocationProof.defaultRadiusMeters,
            bookFavorID: surface.payload.metadata["bookFavorID"]
        )
        list.append(elective)
        if let favorID = elective.bookFavorID {
            let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: Date())
            vault.data.bookInterior = BookInteriorEngine.recordingFavorAccepted(
                base,
                favorID: favorID
            )
            vault.save()
        }
        saveElectives(list)
        statusMessage = elective.bookFavorID == nil
            ? "\(elective.characterName)'s quest is tucked into the flyleaf."
            : "The favor is tucked into the flyleaf. I'll keep my promise without keeping score."
    }

    func recordBookWorkingReturnIfNeeded(surface: SurfacePage, at date: Date) {
        guard let workingID = surface.payload.metadata["bookWorkingID"]?.nonEmpty else { return }
        var ledger = vault.data.bookWorkings ?? .empty
        ledger.recordReturn(workingID: workingID, at: date)
        vault.data.bookWorkings = ledger
        vault.save()
    }

    private func matchedQuestPlace(for surface: SurfacePage) -> LocalPlaceSignal? {
        let haystack = [
            surface.payload.metadata["electiveTitle"],
            surface.payload.metadata["electiveAsk"],
            surface.payload.metadata["electivePractice"]
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
            .lowercased()
        return LocalPlacesScout.cachedPlaces().first { place in
            place.latitude != nil &&
            place.longitude != nil &&
            haystack.contains(place.name.lowercased())
        }
    }

    @MainActor
    func completeElective(id: String, proof: String, photoURL: String? = nil, locationSummary: String? = nil) {
        var list = electives
        guard let index = list.firstIndex(where: { $0.id == id && $0.isActive }) else { return }
        list[index].completedAt = Date()
        list[index].proof = proof.trimmingCharacters(in: .whitespacesAndNewlines)
        list[index].proofPhotoURL = photoURL
        list[index].proofLocationSummary = locationSummary
        saveElectives(list)
        let elective = list[index]

        // Completion says the proof was kept, so mint the corresponding archive
        // page as well as updating the flyleaf ledger. File-backed photo proof
        // then follows the same Pagewright path as mission and pressed photos.
        let proofPageID = "elective-proof-\(elective.id)"
        if !days.flatMap(\.pages).contains(where: { $0.id == proofPageID }) {
            let photoAsset: BookPageMediaAsset? = photoURL.flatMap { rawValue in
                let parsedURL = URL(string: rawValue)
                let path = parsedURL?.isFileURL == true ? parsedURL?.path : rawValue
                guard let path = path?.nonEmpty else { return nil }
                return BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: path,
                    caption: "\(elective.title) proof",
                    sourceID: "unwritten-elective",
                    metadata: [
                        "proofPhoto": "true",
                        "uneditedPhoto": "true",
                        "electiveID": elective.id
                    ]
                )
            }
            let proofText = [
                elective.proof?.nonEmpty,
                elective.proofLocationSummary?.nonEmpty
            ]
                .compactMap { $0 }
                .joined(separator: "\n\n")
            var proofTags = [
                "elective",
                "completed",
                "proof",
                "entity:\(elective.characterID)"
            ]
            if let favorID = elective.bookFavorID {
                proofTags.append("book-favor-completed:\(favorID)")
            }
            if photoAsset != nil {
                proofTags.append(contentsOf: ["photo", "proof-photo", "unedited-photo"])
            }
            let proofPage = BookPage(
                id: proofPageID,
                type: .elective,
                promptText: elective.title,
                userInput: proofText.nonEmpty ?? (photoAsset == nil ? "Quest completed." : "Photo proof kept."),
                tags: proofTags,
                sourceID: "unwritten-elective",
                origin: .userAuthored,
                privacy: .privateLocal,
                mediaAssets: [photoAsset].compactMap { $0 },
                livedQuestReceipt: LivedQuestReceipt.from(
                    elective: elective,
                    completedAt: elective.completedAt ?? Date()
                )
            )
            var day = today
            day.pages.append(proofPage)
            persist(day: day, message: "The quest proof is tucked into me.")
        }

        var bookCompletionLine: String?
        if let favorID = elective.bookFavorID {
            let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: Date())
            let updated = BookInteriorEngine.recordingFavorCompleted(
                base,
                favorID: favorID,
                evidencePageID: proofPageID
            )
            vault.data.bookInterior = updated
            bookCompletionLine = updated.recentSurprise?.line
            vault.save()
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + UnwrittenElective.completionBeliefReward)
        }
        let event = NarrativeEvent(
            id: "elective-complete-\(elective.id)",
            kind: .pageAnswered,
            sourcePageType: .elective,
            sourcePageID: proofPageID,
            createdAt: Date(),
            summary: "The reader completed \(elective.characterName)'s quest \"\(elective.title)\": \(elective.proof ?? "") \(elective.proofLocationSummary ?? "")",
            tags: ["elective", "completed", "entity:\(elective.characterID)"],
            effect: NarrativeEventEffect(
                beliefDelta: UnwrittenElective.completionBeliefReward,
                entityWeightDeltas: [elective.characterID: 3]
            )
        )
        do {
            try BookDatabase.upsertNarrativeEvent(event)
            for memory in NarrativeEntityMemoryResolver.memories(for: event) {
                try BookDatabase.upsertEntityMemory(memory)
            }
            narrativeEvents = try BookDatabase.narrativeEvents(limit: 160)
            entityMemories = NarrativeEntityMemoryConsolidator.consolidate(try BookDatabase.entityMemories(limit: 240))
        } catch {
            statusMessage = "The quest is complete, but a hidden margin note slipped: \(error.localizedDescription)"
            return
        }
        statusMessage = elective.bookFavorID == nil
            ? "\(elective.characterName) will remember this. My Glow warms."
            : "\(bookCompletionLine ?? "You brought the favor back. I'll remember it.") The Book's Glow warms."
        BookFeedback.play(.braidComplete)
    }



    @MainActor
    func anchorPlace(from draft: AnchorPlaceDraft) async {
        guard !isAnchoringPlace else { return }
        isAnchoringPlace = true
        defer { isAnchoringPlace = false }
        statusMessage = "The Labyrinth is growing a room from your words..."

        let now = Date()
        let moon = MoonPhaseCalendar.phase(on: now)
        let season = AnchorRegistry.currentSeason(for: now)
        let weatherPhrase = sourceInputs.weather?.phrase ?? "unrecorded weather"
        let startingBelief = 10
        let recentAtmospheres = anchorLedger.suffix(4).map { anchor in
            let register = anchor.emotionalRegister?.nonEmpty ?? "unlabeled atmosphere"
            return "- \(register): \(anchor.outerStacksRoom.bookPreviewSentenceLimit(1))"
        }
        let generationContext = AnchorGenerationContext(
            anchorName: draft.name,
            playerWords: draft.words,
            kind: draft.kind,
            weather: weatherPhrase,
            moon: moon.name,
            season: season,
            belief: startingBelief,
            place: draft.place,
            recentRoomAtmospheres: recentAtmospheres
        )

        let fallbackWriter = FakeOuterStacksRoomWriter()
        let spec: OuterStacksRoomSpec
        if let written = try? await makeOuterStacksRoomWriter().room(context: generationContext) {
            spec = written
        } else if let offline = try? await fallbackWriter.room(context: generationContext) {
            spec = offline
        } else {
            statusMessage = "The room would not take shape yet. Try anchoring once more."
            return
        }

        let record = AnchorRecord(
            id: "user-anchor-\(slug(for: draft.name))-\(UUID().uuidString.prefix(8))",
            name: draft.name,
            latitude: draft.latitude,
            longitude: draft.longitude,
            radiusMeters: AnchorRegistry.proximityRadiusMeters,
            kind: draft.kind,
            belief: startingBelief,
            created: AnchorRegistry.visitDateFormatter.string(from: now),
            weather: weatherPhrase,
            moon: moon.name,
            season: season,
            playerWords: draft.words,
            academyEcho: spec.academyEcho,
            outerStacksRoom: spec.roomDescription,
            fae: spec.fae,
            miniStory: spec.miniStory,
            localRule: spec.localRule,
            visitCount: 0,
            lastVisited: "none",
            place: draft.place,
            emotionalRegister: spec.emotionalRegister
        )
        anchorLedger.append(record)
        saveAnchorLedger()

        let proximity = AnchorProximity(anchor: record, distanceMeters: 0)
        nearbyAnchor = proximity
        var draftInputs = sourceInputs
        draftInputs.nearbyAnchor = proximity
        preparedAnchorSurface = OuterStacksAnchorPageSourceAdapter().manualSurface(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: draftInputs,
            now: Date()
        )
        surfaceRefreshDate = Date()
        anchorMessage = "\(record.name) is anchored. Its room in the Outer Stacks is waiting."
        statusMessage = "\(record.name) is anchored. The door is already open."
        BookFeedback.play(.braidComplete)
        await openAnchorVisitPage(proximity)
    }

    // MARK: - Save file: the player's world, portable

    @MainActor
    func buildSaveFile() -> ReEnchantedSaveFile {
        let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 5000)) ?? narrativeEvents
        let archiveMemories = (try? BookDatabase.entityMemories(limit: 5000)) ?? entityMemories
        let continuity = LiteraryContinuityProjector.digest(
            days: days,
            events: archiveEvents,
            entityMemories: archiveMemories,
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger
        )
        let clusters = BookMotifClusterEngine.clusters(
            from: continuity,
            constellations: vault.data.constellations ?? [],
            themes: vault.data.themes ?? []
        )
        return ReEnchantedSaveFile(
            exportedAt: Date(),
            days: days,
            selfFacts: (try? BookDatabase.selfFacts()) ?? selfFacts,
            narrativeEvents: archiveEvents,
            entityMemories: archiveMemories,
            facultyEntries: (try? BookDatabase.facultyEntries(limit: 5000)) ?? facultyEntries,
            customCastMembers: customCastMembers,
            anchors: anchorLedger,
            compassKnownPlaces: vault.data.compassKnownPlaces,
            electives: electives,
            beliefScore: beliefScore,
            entityBeliefLedger: entityBeliefLedger,
            pageBeliefLedger: pageBeliefLedger,
            marginTutorSeen: Array(MarginTutorLedger.seenIDs(from: marginTutorSeenData)),
            didCompleteStoryOnboarding: didCompleteStoryOnboarding,
            sourcePreferences: decodedSourcePreferenceLedger(),
            constellations: vault.data.constellations,
            wagers: vault.data.wagers,
            themes: vault.data.themes,
            clusters: clusters,
            readerLexicon: vault.data.readerLexicon,
            storyRecipeBoosts: vault.data.storyRecipeBoosts,
            storyMotifs: vault.data.storyMotifs,
            storyRituals: vault.data.storyRituals,
            storySettingAffinities: vault.data.storySettingAffinities,
            storySceneBiases: vault.data.storySceneBiases,
            storyConsequenceLedger: vault.data.storyConsequenceLedger,
            bookNoticeEvidence: vault.data.bookNoticeEvidence,
            magicMoment: vault.data.magicMoment,
            bookObservations: vault.data.bookObservations,
            bookReadingBoundaries: vault.data.bookReadingBoundaries,
            nothingGreyOffset: vault.data.nothingGreyOffset,
            readerLearning: vault.data.readerLearning,
            openWorldEventArchive: vault.data.openWorldEventArchive,
            worldEventLifecycle: vault.data.worldEventLifecycle,
            authoredContentReceipts: vault.data.authoredContentReceipts,
            publicationEpoch: vault.data.publicationEpoch,
            overnightConnectionDrafts: vault.data.overnightConnectionDrafts,
            chosenQuill: vault.data.chosenQuill,
            people: vault.data.people,
            continuity: continuity,
            firstRunEngaged: vault.data.firstRunEngaged,
            bookAsideReceipts: vault.data.bookAsideReceipts,
            marginaliaAchievementIDs: Array(
                Set(completedMarginaliaAchievementLedger.split(separator: ",").map(String.init))
            ).sorted()
        )
    }

    /// A sealed copy will not carry more than this many bytes of photographs
    /// and kept voice; heavier archives get their text sealed and the media
    /// skipped, with a note to the reader.
    static let sealedCopyMediaByteCap = 400 * 1024 * 1024

    /// Key under which the store remembers when the Book was last sealed.
    static let lastSealedCopyKey = "lastSealedCopyAt"

    /// Human "Last sealed …" line for the seal-a-copy UI, or nil if never.
    var lastSealedCopyDescription: String? {
        guard let date = InsideCoverStore.defaults.object(forKey: Self.lastSealedCopyKey) as? Date else {
            return nil
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last sealed \(formatter.localizedString(for: date, relativeTo: Date()))."
    }

    /// Read the bytes of every file-backed media asset, keyed by filename, up
    /// to `sealedCopyMediaByteCap`. Returns the map plus whether any file was
    /// skipped because the cap was reached.
    @MainActor
    func collectSealedMedia(for days: [BookDay]) -> (files: [String: Data], skippedForSize: Bool) {
        var files: [String: Data] = [:]
        var total = 0
        var skipped = false
        for path in ReEnchantedSaveFile.fileBackedReferences(in: days) {
            let filename = (path as NSString).lastPathComponent
            guard !filename.isEmpty, files[filename] == nil,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            if total + data.count > Self.sealedCopyMediaByteCap {
                skipped = true
                continue
            }
            files[filename] = data
            total += data.count
        }
        return (files, skipped)
    }

    @MainActor
    func exportSaveFile() {
        do {
            var saveFile = buildSaveFile()
            let media = collectSealedMedia(for: saveFile.days)
            saveFile.mediaFiles = media.files.isEmpty ? nil : media.files
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(saveFile)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReEnchanted-\(formatter.string(from: Date())).\(ReEnchantedSaveFile.fileExtension)")
            try data.write(to: url, options: [.atomic])
            preparedSaveFileURL = url
            InsideCoverStore.defaults.set(Date(), forKey: Self.lastSealedCopyKey)
            statusMessage = media.skippedForSize
                ? "I'm sealed, though some photographs were too heavy to carry along."
                : "I'm sealed: a complete copy, pages and photographs alike."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The save file would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    /// Write every kept page as plain Markdown: readable anywhere, no app
    /// required, and hand it to the share sheet.
    @MainActor
    func exportPlainInk() {
        do {
            let markdown = PlainInkExport.markdown(days: days, calendar: .current)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReEnchanted-plain-\(formatter.string(from: Date())).md")
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            preparedPlainInkURL = url
            statusMessage = "Your pages are copied out in plain ink, ready to share."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The plain-ink copy would not write: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    @MainActor
    func exportContinuityFile() {
        do {
            let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 5000)) ?? narrativeEvents
            let archiveMemories = (try? BookDatabase.entityMemories(limit: 5000)) ?? entityMemories
            let digest = LiteraryContinuityProjector.digest(
                days: days,
                events: archiveEvents,
                entityMemories: archiveMemories,
                entityBelief: entityBeliefLedger,
                pageBelief: pageBeliefLedger
            )
            let export = BookArchiveExport(
                days: [],
                continuity: LiteraryContinuityDigest(
                    signals: Array(digest.strongestSignals.prefix(16)),
                    beliefLifecycles: Array(digest.beliefLifecycles.prefix(12))
                ),
                constellations: Array((vault.data.constellations ?? []).prefix(16)),
                wagers: Array((vault.data.wagers ?? []).prefix(12)),
                themes: Array((vault.data.themes ?? []).suffix(12)),
                clusters: Array(BookMotifClusterEngine.clusters(
                    from: digest,
                    constellations: vault.data.constellations ?? [],
                    themes: vault.data.themes ?? []
                ).prefix(12))
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("insidecover-continuity.json")
            try export.encodedData().write(to: url, options: [.atomic])
            preparedContinuityURL = url
            statusMessage = "My continuity is bound and ready to share."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The continuity file would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    /// The keeper of constellations and sealed margins: recomputes the
    /// continuity digest, advances the durable constellation ledger, opens
    /// any wagers whose date has come, and seals new ones. Runs alongside
    /// tendArc so the Book's long memory moves whenever the field does.
    @MainActor
    func tendConstellations(now: Date = Date()) {
        let previousConstellations = vault.data.constellations ?? []
        var digest = LiteraryContinuityProjector.digest(
            days: days,
            events: narrativeEvents,
            entityMemories: entityMemories,
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger,
            now: now
        )
        // A station the reader keeps returning to becomes a companion
        // constellation ("You and Thornwave keep meeting…").
        digest.signals += RadioStationRegistry.listeningSignals(
            state: vault.data.radio ?? .off,
            unlockedPackIDs: Set(vault.data.ownedPacks ?? []),
            now: now
        )
        let advanced = ConstellationKeeper.advanced(
            previousConstellations,
            observing: digest,
            now: now
        )
        var wagers = SealedMarginEngine.resolved(vault.data.wagers ?? [], against: days, now: now)
        wagers += SealedMarginEngine.mintWagers(from: digest, existing: wagers, now: now)

        let calendar = Calendar.current
        let monthKey = BookThemeEngine.monthKey(for: now, calendar: calendar)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthPages = days
            .filter { $0.date >= calendar.startOfDay(for: monthStart) }
            .flatMap(\.pages)
        let currentTheme = BookThemeEngine.theme(
            for: monthPages,
            digest: digest,
            constellations: advanced,
            monthKey: monthKey,
            now: now
        )
        let themes = BookThemeEngine.remembered(vault.data.themes ?? [], observing: currentTheme, monthKey: monthKey)

        let changed = advanced != (vault.data.constellations ?? [])
            || wagers != (vault.data.wagers ?? [])
            || themes != (vault.data.themes ?? [])
        guard changed else { return }
        // Publish the related long-memory ledgers as one observable change so
        // SwiftUI does not rebuild the whole Book once per field.
        vault.mutate {
            $0.constellations = advanced
            $0.wagers = wagers
            $0.themes = themes
        }
        vault.save()
        let previousIDs = Set(previousConstellations.map(\.id))
        if let discovered = advanced.first(where: { !previousIDs.contains($0.id) }) {
            BookFeedback.constellationDiscovered(nodes: max(2, discovered.evidencePageIDs.count))
        }
        surfaceRefreshDate = now
    }

    // MARK: - The Bleed press run

    /// Sets the presses running: live interest research, then one local-brain
    /// call per written column, composited into a single edition page.
    @MainActor
    @discardableResult
    func prepareBleedEditionIfPossible(from announcement: SurfacePage? = nil) async -> Bool {
        guard !generation.isPreparingBleedEdition, !localBrainTelemetry.isWorking else { return false }
        let surface: SurfacePage
        if let announcement {
            surface = announcement
        } else if let built = TheBleedEditionBuilder.announcementSurface(for: today, inputs: sourceInputs, now: Date()) {
            surface = built
        } else {
            statusMessage = "The presses rest in the afternoon. The next edition sets at four."
            return false
        }

        if let prepared = generation.preparedBleedEditionSurface,
           prepared.payload.metadata["bleedSlotID"] == surface.payload.metadata["bleedSlotID"] {
            return true
        }

        generation.isPreparingBleedEdition = true
        defer { generation.isPreparingBleedEdition = false }

        // The desk hands over an announcement without its type tray, because
        // composing the columns for every paper the Book merely *considers*
        // offering was the most expensive thing in the desk build. Set the type
        // now, for this leaf's own edition.
        var briefs = TheBleedEditionBuilder.decodedBriefs(surface.payload.metadata["bleedBriefs"] ?? "")
        if briefs.isEmpty {
            briefs = TheBleedEditionBuilder.settingTheType(
                for: surface,
                day: today,
                inputs: sourceInputs,
                now: Date()
            )
        }
        guard !briefs.isEmpty else {
            statusMessage = "The type tray came up empty. Penny is re-sorting the briefs."
            return false
        }
        let kind = BleedEditionKind(rawValue: surface.payload.metadata["bleedEditionKind"] ?? "") ?? .morning
        let issueNumber = Int(surface.payload.metadata["bleedIssueNumber"] ?? "") ?? 1
        let pressTime = Date()

        // The first paper should not quietly print an empty noticeboard merely
        // because the Calendar Doorway has never been offered. Ask once at the
        // moment the issue needs it; a refusal remains a refusal.
        if issueNumber == 1,
           !didHandleBleedCalendarDoorway,
           !bookCalendarEnabled,
           CalendarDoorway.isAvailable {
            didHandleBleedCalendarDoorway = true
            switch CalendarDoorway.accessState {
            case .notDetermined:
                statusMessage = "The first issue needs its noticeboard. Penny is asking whether the Calendar Doorway may open..."
                let events = await CalendarDoorway.upcomingEvents(now: pressTime)
                if CalendarDoorway.accessState == .authorized {
                    bookCalendarEnabled = true
                    calendarEvents = events
                }
            case .authorized:
                bookCalendarEnabled = true
                calendarEvents = await CalendarDoorway.upcomingEvents(now: pressTime)
            case .denied, .unavailable:
                break
            }
        }

        if bookCalendarEnabled {
            calendarEvents = await CalendarDoorway.upcomingEvents(now: pressTime)
        }

        var pressInputs = sourceInputs
        pressInputs.calendarIntegrationEnabled = bookCalendarEnabled
        pressInputs.calendarEvents = calendarEvents
        briefs = TheBleedEditionBuilder.refreshingAlmanacBriefs(
            briefs,
            kind: kind,
            inputs: pressInputs,
            now: pressTime
        )

        if briefs.contains(where: { $0.id == "weather-desk" }) {
            var weatherInputs = pressInputs
            if weatherInputs.weather?.isAvailable != true {
                statusMessage = "Penny is checking the window before the weather desk goes to type..."
                _ = await refreshWeatherSignal(isUserInitiated: false, shouldEnchant: false)
                weatherInputs = sourceInputs
            }
            briefs = TheBleedEditionBuilder.refreshingWeatherBriefs(
                briefs,
                kind: kind,
                inputs: weatherInputs
            )
        }

        let interest = surface.payload.metadata["bleedInterest"]?.nonEmpty
        var clippings = ""
        var clippingSources = ""
        if let interest, personalizedWebResearchOptIn {
            statusMessage = "Penny is interviewing the wider world about \(interest)..."
            let research = await BleedInterestSearcher().clippings(for: interest)
            clippings = research.text
            clippingSources = research.sources
        }

        let writer = BleedColumnWriter()
        var columns: [(brief: BleedColumnBrief, body: String)] = []
        for brief in briefs {
            if brief.needsLocalBrain {
                statusMessage = "Setting type: \(brief.title)..."
            }
            let body = await writer.write(brief: brief, clippings: clippings)
            columns.append((brief, body))
        }

        let body = TheBleedEditionBuilder.compositedBody(
            kind: kind,
            issueNumber: issueNumber,
            columns: columns,
            now: Date()
        )
        generation.preparedBleedEditionSurface = TheBleedEditionBuilder.preparedCopy(
            of: surface,
            body: body,
            interestSources: clippingSources
        )
        surfaceRefreshDate = Date()
        statusMessage = "Issue #\(issueNumber) is off the press."
        BookFeedback.play(.braidComplete)
        return true
    }

    /// Binds the most recent edition (prepared or kept today) as a PDF.
    @MainActor
    func exportBleedPDF() {
        let candidate: (headline: String, body: String, mediaAssets: [BookPageMediaAsset])? = {
            if let prepared = generation.preparedBleedEditionSurface,
               let prose = prepared.payload.metadata["bleedProse"]?.nonEmpty {
                return (prepared.payload.headline, prose, prepared.mediaAssets)
            }
            if let kept = today.pages.last(where: { $0.type == .theBleed && !$0.userInput.isEmpty }) {
                return (kept.promptText.nonEmpty ?? "The Bleed", kept.userInput, kept.mediaAssets)
            }
            return nil
        }()
        guard let candidate else {
            statusMessage = "No edition has been printed yet today."
            BookFeedback.play(.error)
            return
        }
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TheBleed-\(formatter.string(from: Date())).pdf")
            try BleedPDFWriter.write(
                headline: candidate.headline,
                body: candidate.body,
                mediaAssets: candidate.mediaAssets,
                to: url
            )
            preparedBleedPDFURL = url
            statusMessage = "The Bleed is bound for sharing."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The edition would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    private var boundPublicationRevisionCounts: [PublicationPeriodID: Int] {
        var counts: [PublicationPeriodID: Int] = [:]
        for page in publicationArtifactPages {
            if let artifact = page.weeklyIssueArtifact {
                counts[weeklyPublicationPeriodID(for: artifact), default: 0] += 1
            }
            if let artifact = page.monthlyEditionArtifact {
                if let periodID = monthlyPublicationPeriodID(for: artifact) {
                    counts[periodID, default: 0] += 1
                }
            }
            if let artifact = page.annualEditionArtifact {
                counts[artifact.periodID, default: 0] += 1
            }
        }
        return counts
    }

    /// Bound publications are immutable archive Pages. These helpers are the
    /// single lookup seam used by the leaf, Glow, Bindery, and shelf, so none of
    /// those surfaces mistake a short-lived export URL for the finished book.
    private var publicationArtifactPages: [BookPage] {
        var daysByID: [String: BookDay] = [:]
        for day in days { daysByID[day.id] = day }
        daysByID[today.id] = today
        return daysByID.values
            .flatMap(\.pages)
            .filter {
                $0.weeklyIssueArtifact != nil
                    || $0.monthlyEditionArtifact != nil
                    || $0.annualEditionArtifact != nil
            }
    }

    private func weeklyPublicationPeriodID(
        for artifact: KeptWeeklyIssueArtifact
    ) -> PublicationPeriodID {
        if let periodID = artifact.periodID { return periodID }
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        return PublicationPeriodCatalog.period(
            recipe: .readerWeek,
            startDate: artifact.issue.startDate,
            endDate: artifact.issue.endDate,
            ordinal: artifact.issue.number,
            calendar: calendar
        ).id
    }

    private func monthlyPublicationPeriodID(
        for artifact: KeptMonthlyEditionArtifact
    ) -> PublicationPeriodID? {
        artifact.periodID ?? publicationPeriodID(for: artifact.edition)
    }

    func keptWeeklyIssuePage(for periodID: PublicationPeriodID) -> BookPage? {
        publicationArtifactPages
            .filter { page in
                page.weeklyIssueArtifact.map { weeklyPublicationPeriodID(for: $0) == periodID } == true
            }
            .max {
                ($0.weeklyIssueArtifact?.keptAt ?? .distantPast)
                    < ($1.weeklyIssueArtifact?.keptAt ?? .distantPast)
            }
    }

    func keptWeeklyIssuePage(issueNumber: Int) -> BookPage? {
        publicationArtifactPages
            .filter { $0.weeklyIssueArtifact?.issue.number == issueNumber }
            .max {
                ($0.weeklyIssueArtifact?.keptAt ?? .distantPast)
                    < ($1.weeklyIssueArtifact?.keptAt ?? .distantPast)
            }
    }

    func keptMonthlyEditionPage(for periodID: PublicationPeriodID) -> BookPage? {
        publicationArtifactPages
            .filter { page in
                page.monthlyEditionArtifact.flatMap { monthlyPublicationPeriodID(for: $0) } == periodID
            }
            .max {
                ($0.monthlyEditionArtifact?.keptAt ?? .distantPast)
                    < ($1.monthlyEditionArtifact?.keptAt ?? .distantPast)
            }
    }

    func keptAnnualEditionPage(for periodID: PublicationPeriodID) -> BookPage? {
        publicationArtifactPages
            .filter { $0.annualEditionArtifact?.periodID == periodID }
            .max {
                ($0.annualEditionArtifact?.keptAt ?? .distantPast)
                    < ($1.annualEditionArtifact?.keptAt ?? .distantPast)
            }
    }

    private func existingPublicationFile(at path: String) -> URL? {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty, FileManager.default.fileExists(atPath: cleanPath) else { return nil }
        return URL(fileURLWithPath: cleanPath)
    }

    func boundWeeklyIssuePDFURL(for periodID: PublicationPeriodID) -> URL? {
        guard let artifact = keptWeeklyIssuePage(for: periodID)?.weeklyIssueArtifact else { return nil }
        if let stored = existingPublicationFile(at: artifact.pdfPath) { return stored }
        guard let directory = try? weeklyIssueArchiveDirectory() else { return nil }
        let canonical = directory.appendingPathComponent("Weekly-Issue-\(artifact.issue.number).pdf")
        return existingPublicationFile(at: canonical.path)
    }

    func boundWeeklyIssuePDFURL(issueNumber: Int) -> URL? {
        guard let artifact = keptWeeklyIssuePage(issueNumber: issueNumber)?.weeklyIssueArtifact else { return nil }
        if let stored = existingPublicationFile(at: artifact.pdfPath) { return stored }
        guard let directory = try? weeklyIssueArchiveDirectory() else { return nil }
        let canonical = directory.appendingPathComponent("Weekly-Issue-\(artifact.issue.number).pdf")
        return existingPublicationFile(at: canonical.path)
    }

    func boundWeeklyIssueCardURL(for periodID: PublicationPeriodID) -> URL? {
        guard let artifact = keptWeeklyIssuePage(for: periodID)?.weeklyIssueArtifact else { return nil }
        if let stored = existingPublicationFile(at: artifact.cardPath) { return stored }
        guard let directory = try? weeklyIssueArchiveDirectory() else { return nil }
        let canonical = directory.appendingPathComponent("Weekly-Issue-\(artifact.issue.number)-Card.png")
        return existingPublicationFile(at: canonical.path)
    }

    func boundMonthlyEditionPDFURL(for periodID: PublicationPeriodID) -> URL? {
        guard let artifact = keptMonthlyEditionPage(for: periodID)?.monthlyEditionArtifact else { return nil }
        if let stored = existingPublicationFile(at: artifact.pdfPath) { return stored }
        guard let directory = try? monthlyEditionArchiveDirectory() else { return nil }
        let canonical = directory.appendingPathComponent("Monthly-Edition-\(artifact.monthKey).pdf")
        return existingPublicationFile(at: canonical.path)
    }

    func boundAnnualEditionPDFURL(for periodID: PublicationPeriodID) -> URL? {
        guard let artifact = keptAnnualEditionPage(for: periodID)?.annualEditionArtifact else { return nil }
        if let stored = existingPublicationFile(at: artifact.pdfPath) { return stored }
        guard let directory = try? annualEditionArchiveDirectory() else { return nil }
        let stamp = "\(artifact.edition.year)-\(artifact.periodID.startDayID)"
            .replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression)
        let canonical = directory.appendingPathComponent("Annual-Edition-\(stamp).pdf")
        return existingPublicationFile(at: canonical.path)
    }

    var boundWeeklyIssuePDFURLs: [PublicationPeriodID: URL] {
        bindableWeeklyPublicationCandidates.reduce(into: [:]) { result, candidate in
            result[candidate.id] = boundWeeklyIssuePDFURL(for: candidate.id)
        }
    }

    var boundMonthlyEditionPDFURLs: [PublicationPeriodID: URL] {
        monthlyPublicationCandidates.filter(\.isBindable).reduce(into: [:]) { result, candidate in
            result[candidate.id] = boundMonthlyEditionPDFURL(for: candidate.id)
        }
    }

    var boundSeasonalEditionPDFURLs: [PublicationPeriodID: URL] {
        seasonalPublicationCandidates.filter(\.isBindable).reduce(into: [:]) { result, candidate in
            result[candidate.id] = boundMonthlyEditionPDFURL(for: candidate.id)
        }
    }

    var boundAnnualEditionPDFURLs: [PublicationPeriodID: URL] {
        annualPublicationCandidates.filter(\.isBindable).reduce(into: [:]) { result, candidate in
            result[candidate.id] = boundAnnualEditionPDFURL(for: candidate.id)
        }
    }

    var glowWeeklyIssuePDFURL: URL? {
        guard let periodID = bindableWeeklyPublicationCandidates.first?.id else { return nil }
        return boundWeeklyIssuePDFURL(for: periodID)
            ?? (preparedWeeklyIssuePeriodID == periodID ? preparedWeeklyIssuePDFURL : nil)
    }

    var glowWeeklyIssueCardURL: URL? {
        guard let periodID = bindableWeeklyPublicationCandidates.first?.id else { return nil }
        return boundWeeklyIssueCardURL(for: periodID)
            ?? (preparedWeeklyIssuePeriodID == periodID ? preparedWeeklyIssueCardURL : nil)
    }

    var glowMonthlyEditionURL: URL? {
        guard let periodID = monthlyPublicationCandidates.first(where: \.isBindable)?.id else { return nil }
        return boundMonthlyEditionPDFURL(for: periodID)
            ?? (preparedMonthlyEditionPeriodID == periodID ? preparedMonthlyEditionURL : nil)
    }

    var glowSeasonalEditionURL: URL? {
        guard let periodID = seasonalPublicationCandidates.first(where: \.isBindable)?.id else { return nil }
        return boundMonthlyEditionPDFURL(for: periodID)
            ?? (preparedMonthlyEditionPeriodID == periodID ? preparedMonthlyEditionURL : nil)
    }

    var glowAnnualEditionURL: URL? {
        guard let periodID = annualPublicationCandidates.first(where: \.isBindable)?.id else { return nil }
        return boundAnnualEditionPDFURL(for: periodID)
            ?? (preparedAnnualEditionPeriodID == periodID ? preparedAnnualEditionURL : nil)
    }

    /// Works out what the Book could bind while the reader is reading, so the
    /// Glow menu does not have to work it out while they are waiting for it.
    ///
    /// Deciding whether a period is bindable means curating it, and the menu
    /// asks about every week, month, season and year since the reader began.
    /// Run here — after the desk is interactive, off the main actor — the
    /// answers are already in hand when the menu opens, and the menu's own
    /// call finds them instead of doing the work again.
    @MainActor
    func warmPublicationCatalogue() {
        let archive = days
        let currentDay = today
        let revisions = boundPublicationRevisionCounts
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        let weekAnchor = vault.data.publicationEpoch?.readerWeekAnchor(calendar: calendar)
        Task.detached(priority: .utility) {
            let now = Date()
            _ = PublicationPeriodCatalog.readerWeeks(
                days: archive, today: currentDay, frozenAnchor: weekAnchor,
                boundRevisionCounts: revisions, now: now, calendar: calendar
            )
            _ = PublicationPeriodCatalog.calendarMonths(
                days: archive, today: currentDay, boundRevisionCounts: revisions, now: now, calendar: calendar
            )
            _ = PublicationPeriodCatalog.calendarSeasons(
                days: archive, today: currentDay, boundRevisionCounts: revisions, now: now, calendar: calendar
            )
            _ = PublicationPeriodCatalog.calendarYears(
                days: archive, today: currentDay, boundRevisionCounts: revisions, now: now, calendar: calendar
            )
        }
    }

    var weeklyPublicationCandidates: [PublicationCandidate] {
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        return PublicationPeriodCatalog.readerWeeks(
            days: days,
            today: today,
            frozenAnchor: vault.data.publicationEpoch?.readerWeekAnchor(calendar: calendar),
            boundRevisionCounts: boundPublicationRevisionCounts,
            now: Date(),
            calendar: calendar
        )
    }

    var bindableWeeklyPublicationCandidates: [PublicationCandidate] {
        weeklyPublicationCandidates.filter(\.isBindable)
    }

    /// The durable binding choice. Unlike `currentWeeklyIssue`, it does not go
    /// missing merely because the four-day invitation stopped knocking.
    var latestWeeklyIssueForBinding: WeeklyIssue? {
        guard let candidate = bindableWeeklyPublicationCandidates.first else { return nil }
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        return WeeklyIssue.issue(
            for: candidate.period,
            days: days,
            today: today,
            boundTales: vault.data.boundTales ?? [],
            readerRole: boundReaderRole,
            castActs: (vault.data.castActs ?? .empty).records,
            now: Date(),
            calendar: calendar
        )
    }

    /// Maps an issue number the reader is looking at back to the week it came
    /// from. The desk announces `WeeklyIssue.current`; the binder works from
    /// bindable periods, and those two need not agree on which week is first.
    @MainActor
    func weeklyPublicationPeriodID(forIssueNumber number: Int) -> PublicationPeriodID? {
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        let boundTales = vault.data.boundTales ?? []
        let castActs = (vault.data.castActs ?? .empty).records
        let now = Date()
        return bindableWeeklyPublicationCandidates.first { candidate in
            WeeklyIssue.issue(
                for: candidate.period,
                days: days,
                today: today,
                boundTales: boundTales,
                readerRole: boundReaderRole,
                castActs: castActs,
                now: now,
                calendar: calendar
            )?.number == number
        }?.id
    }

    var monthlyPublicationCandidates: [PublicationCandidate] {
        PublicationPeriodCatalog.calendarMonths(
            days: days,
            today: today,
            boundRevisionCounts: boundPublicationRevisionCounts,
            now: Date()
        )
    }

    var seasonalPublicationCandidates: [PublicationCandidate] {
        PublicationPeriodCatalog.calendarSeasons(
            days: days,
            today: today,
            boundRevisionCounts: boundPublicationRevisionCounts,
            now: Date()
        )
    }

    var annualPublicationCandidates: [PublicationCandidate] {
        PublicationPeriodCatalog.calendarYears(
            days: days,
            today: today,
            boundRevisionCounts: boundPublicationRevisionCounts,
            now: Date()
        )
    }

    var selectedMonthlyPublicationCandidate: PublicationCandidate? {
        let bindable = monthlyPublicationCandidates.filter(\.isBindable)
        guard let selectedEditionMonth else { return bindable.first }
        return bindable.first {
            Calendar.current.isDate($0.period.startDate, equalTo: selectedEditionMonth, toGranularity: .month)
        }
    }

    var latestAnnualPublicationCandidate: PublicationCandidate? {
        annualPublicationCandidates.first(where: \.isBindable)
    }

    /// Completed, nonempty months, newest first. The unfinished current month
    /// remains visible to the catalogue as `.gathering`, but cannot enter this
    /// final-binding picker.
    var bindableEditionMonths: [(start: Date, label: String, pageCount: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return monthlyPublicationCandidates.filter(\.isBindable).map { candidate in
            let start = candidate.period.startDate
            return (
                start: start,
                label: formatter.string(from: start),
                pageCount: candidate.eligiblePageCount
            )
        }
    }

    /// What the month-picker chip reads: the chosen month, or the auto choice.
    var selectedEditionMonthLabel: String {
        guard let chosen = selectedEditionMonth else { return "Most recent month" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: chosen)
    }

    var currentWeeklyIssue: WeeklyIssue? {
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        return WeeklyIssue.current(
            days: days,
            today: today,
            boundTales: vault.data.boundTales ?? [],
            readerRole: boundReaderRole,
            castActs: (vault.data.castActs ?? .empty).records,
            frozenAnchor: vault.data.publicationEpoch?.readerWeekAnchor(calendar: calendar),
            now: Date(),
            calendar: calendar
        )
    }

    /// Seeds the Reader Week clock once. Later imports may add older pages, but
    /// they cannot move an issue boundary that has already belonged to a book.
    @MainActor
    func ensurePublicationEpochIfNeeded(now: Date = Date()) {
        guard vault.data.publicationEpoch == nil,
              let epoch = BookPublicationEpoch.seeded(
                  from: days,
                  today: today,
                  now: now,
                  calendar: .current
              ) else { return }
        vault.mutate { $0.publicationEpoch = epoch }
        surfaceRefreshDate = now
    }

    /// The Book's own name for this reader, flattened for whatever is about to
    /// be bound. Nil until the naming ceremony has run.
    var boundReaderRole: BoundReaderRole? {
        BoundReaderRole(ReaderRoleRegistry.currentRole(from: selfFacts))
    }

    /// Binds a Bound Year season the moment one has closed and been paid for.
    ///
    /// Idempotent by season key, so running it on every launch is harmless -
    /// which is the point. There is no server telling the app a season ended;
    /// the dates say so, and the same dates always say so.
    @MainActor
    func openDueSeasonalDispatchIfNeeded(now: Date = Date()) {
        guard let membership = vault.data.boundYear else { return }
        var dispatches = vault.data.seasonalDispatches ?? []
        var resolvedEmptyKeys = Set(vault.data.resolvedEmptyBoundYearSeasonKeys ?? [])
        let originalDispatchCount = dispatches.count
        let originalEmptyKeys = resolvedEmptyKeys
        let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 20_000)) ?? narrativeEvents
        let archiveMemories = (try? BookDatabase.entityMemories(limit: 20_000)) ?? entityMemories

        // A long-suspended app may have crossed several membership seasons.
        // Walk every newly-closed window in order. An empty season is resolved
        // without shipping; otherwise it would permanently block the next one.
        for _ in 0..<(BoundYearCycle.seasonsPerYear * 4) {
            let resolvedKeys = Set(dispatches.map(\.seasonKey)).union(resolvedEmptyKeys)
            guard let due = BoundYearCycle.seasonDue(
                membership: membership,
                alreadyDispatchedKeys: resolvedKeys,
                now: now
            ) else { break }

            if let dispatch = BoundYearCycle.openDueDispatch(
                membership: membership,
                days: days,
                existing: dispatches,
                resolvedSeasonKeys: resolvedEmptyKeys,
                events: archiveEvents,
                entityMemories: archiveMemories,
                entityBelief: entityBeliefLedger,
                pageBelief: pageBeliefLedger,
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                readerRole: boundReaderRole,
                castActs: (vault.data.castActs ?? .empty).records,
                constellations: vault.data.constellations ?? [],
                wagers: vault.data.wagers ?? [],
                themes: vault.data.themes ?? [],
                storyConsequences: vault.data.storyConsequenceLedger?.receipts ?? [],
                facultyEntries: facultyEntries,
                includePrivateLifeAlmanac: includePrivateWeatherInMonthlyBinding,
                academySeason: academySeasonInputs,
                boundTales: vault.data.boundTales ?? [],
                now: now
            ) {
                dispatches.append(dispatch)
            } else {
                resolvedEmptyKeys.insert(due.key)
            }
        }

        guard dispatches.count != originalDispatchCount || resolvedEmptyKeys != originalEmptyKeys else {
            return
        }
        vault.mutate {
            $0.seasonalDispatches = dispatches
            $0.resolvedEmptyBoundYearSeasonKeys = resolvedEmptyKeys.sorted()
        }
        surfaceRefreshDate = now
    }

    /// Stripe is the money ledger. Refresh it before deciding whether a monthly
    /// member has paid through the end of a season; otherwise the date captured
    /// at first checkout goes stale and the third-month book never becomes due
    /// unless they happen to open the subscription screen.
    @MainActor
    func reconcileBoundYearForDispatchIfNeeded() async {
        setBoundYearDigitalAccess(vault.data.boundYear?.hasMonthlyContentAccess(at: Date()) == true)
        guard let membershipID = vault.data.boundYearMembershipID,
              var membership = vault.data.boundYear else { return }
        do {
            let remote = try await PhysicalBookQuoteClient().membershipStatus(id: membershipID)
            if let paidThrough = remote.periodEndsAt {
                membership.paidThrough = paidThrough
            }
            if remote.cancelAtPeriodEnd {
                membership.status = .active
                membership.endedAt = remote.periodEndsAt
            } else {
                switch remote.status {
                case "active", "trialing":
                    membership.status = .active
                    membership.endedAt = nil
                case "past_due":
                    membership.status = .inGracePeriod
                case "canceled":
                    membership.status = .cancelled
                    membership.endedAt = remote.periodEndsAt ?? membership.endedAt
                default:
                    membership.status = .lapsed
                }
            }
            var dispatches = vault.data.seasonalDispatches ?? []
            if remote.shippingAddressPresent == true {
                dispatches = dispatches.map { dispatch in
                    dispatch.hasPosted ? dispatch : SeasonalDispatchWindow.confirmAddress(dispatch, at: Date())
                }
            }
            vault.mutate {
                $0.boundYear = membership
                $0.seasonalDispatches = dispatches
            }
            setBoundYearDigitalAccess(membership.hasMonthlyContentAccess(at: Date()))
        } catch {
            // A network failure must not erase paid local state. The next
            // launch retries, and the Worker proves entitlement before posting.
        }
    }

    @MainActor
    func renameSeasonalDispatch(id: String, title: String) -> String {
        var dispatches = vault.data.seasonalDispatches ?? []
        guard let index = dispatches.firstIndex(where: { $0.id == id }) else {
            return "I lost the parcel's place in the ledger. It hasn't gone anywhere."
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= SeasonalDispatchWindow.coverTitleCharacterLimit else {
            return "That name has more than \(SeasonalDispatchWindow.coverTitleCharacterLimit) letters in its coat. Shorten it before the spine tries to eat the ending."
        }
        let updated = SeasonalDispatchWindow.rename(dispatches[index], to: title)
        guard updated != dispatches[index] else {
            return "Give it one word worth putting on a spine."
        }
        dispatches[index] = updated
        vault.mutate { $0.seasonalDispatches = dispatches }
        surfaceRefreshDate = Date()
        return "There. “\(updated.coverLine)” is on the cover now. The old name has stopped arguing."
    }

    @MainActor
    func setSeasonalDispatchDedication(id: String, text: String, now: Date = Date()) -> String {
        var dispatches = vault.data.seasonalDispatches ?? []
        guard let index = dispatches.firstIndex(where: { $0.id == id }) else {
            return "I lost the parcel's place in the ledger. It hasn't gone anywhere."
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dedication = BoundDedication(text: trimmed, writtenAt: now)
        dispatches[index] = SeasonalDispatchWindow.dedicate(dispatches[index], with: dedication)
        vault.mutate { $0.seasonalDispatches = dispatches }
        surfaceRefreshDate = now
        return dedication == nil
            ? "Blank again. The leaf has gone quiet."
            : "Kept exactly as you wrote it. I didn't put a paw on a word."
    }

    @MainActor
    func setSeasonalDispatchCover(
        id: String,
        choice: BoundVolumeCoverChoice,
        plateID: String?,
        photoData: Data?
    ) -> String {
        var dispatches = vault.data.seasonalDispatches ?? []
        guard let index = dispatches.firstIndex(where: { $0.id == id }) else {
            return "I lost the parcel's place in the ledger. It hasn't gone anywhere."
        }

        var storedPhotoFilename: String?
        var storedPhotoFocus: PublicationCoverFocus?
        switch choice {
        case .bookChooses:
            break
        case .binderyPlate:
            guard PublicationCoverCatalogue.plate(id: plateID) != nil else {
                return "That plate slipped behind the cabinet. Choose another one."
            }
        case .readerPhoto:
            guard let photoData,
                  photoData.count <= 30_000_000,
                  let image = UIImage(data: photoData),
                  let jpeg = seasonalCoverJPEGData(image) else {
                return "That photograph is too large or too strange for the press to hold."
            }
            do {
                let filename = "\(safeSeasonalCoverFilename(id)).jpg"
                try FileManager.default.createDirectory(
                    at: seasonalCoverDirectoryURL,
                    withIntermediateDirectories: true
                )
                try jpeg.write(
                    to: seasonalCoverDirectoryURL.appendingPathComponent(filename),
                    options: [.atomic]
                )
                storedPhotoFilename = filename
                storedPhotoFocus = MonthlyEditionPDFWriter.readerPhotoFocus(for: image)
            } catch {
                return "The photograph reached the press and then the drawer stuck. Try once more."
            }
        }

        let updated = SeasonalDispatchWindow.chooseCover(
            dispatches[index],
            choice: choice,
            plateID: plateID,
            photoFilename: storedPhotoFilename,
            photoFocus: storedPhotoFocus
        )
        dispatches[index] = updated
        vault.mutate { $0.seasonalDispatches = dispatches }
        surfaceRefreshDate = Date()

        switch choice {
        case .bookChooses:
            return updated.isAnnualVolume
                ? "I'll keep the annual in cloth and gold. It has already begun standing up straighter."
                : "I'll choose its coat. No peeking over my shoulder."
        case .binderyPlate:
            return updated.isAnnualVolume
                ? "Plate chosen. The annual will wear an illustrated hardcase instead of cloth, still included."
                : "Plate chosen. It has stopped pretending not to pose."
        case .readerPhoto:
            return updated.isAnnualVolume
                ? "Your photograph is on the annual. It will wear an illustrated hardcase so the image can print, still included."
                : "Your photograph is on the cover now. I kept my paws off the important bit."
        }
    }

    private var seasonalCoverDirectoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return root.appendingPathComponent("ReEnchanted/BoundYearCovers", isDirectory: true)
    }

    private func safeSeasonalCoverFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }

    private func seasonalCoverJPEGData(_ image: UIImage) -> Data? {
        let maximumDimension: CGFloat = 3_200
        let largest = max(image.size.width, image.size.height)
        guard largest > 0 else { return nil }
        guard largest > maximumDimension else { return image.jpegData(compressionQuality: 0.92) }
        let scale = maximumDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.92)
    }

    private func seasonalCoverArtwork(for dispatch: SeasonalDispatch) -> MonthlyEditionPDFWriter.VolumeCoverArtwork? {
        switch dispatch.resolvedCoverChoice {
        case .bookChooses:
            guard !PublicationCoverCatalogue.rotating.isEmpty else { return nil }
            let index = ConstellationKeeper.stableIndex(
                for: "\(dispatch.id)-included-cover",
                count: PublicationCoverCatalogue.rotating.count
            )
            let plate = PublicationCoverCatalogue.rotating[index]
            guard let image = UIImage(named: plate.assetName) else { return nil }
            return .init(image: image, titleLayout: plate.titleLayout, id: plate.id)
        case .binderyPlate:
            guard let plate = PublicationCoverCatalogue.plate(id: dispatch.coverPlateID),
                  let image = UIImage(named: plate.assetName) else { return nil }
            return .init(image: image, titleLayout: plate.titleLayout, id: plate.id)
        case .readerPhoto:
            guard let filename = dispatch.coverPhotoFilename,
                  let image = UIImage(contentsOfFile: seasonalCoverDirectoryURL.appendingPathComponent(filename).path) else { return nil }
            return .init(
                image: image,
                titleLayout: .photographFooter,
                id: "reader-photo",
                focusPoint: dispatch.coverPhotoFocus.map { CGPoint(x: $0.x, y: $0.y) }
            )
        }
    }

    /// Lulu's cloth spine owns two fields with a *combined* 42-character cap.
    /// The jacket carries the season's literary title; the cloth underneath
    /// stays restrained enough to feel like the annual beneath its coat.
    private func seasonalFoilStamp(
        for annual: AnnualEdition,
        spec: PrintSpec
    ) -> (title: String, author: String)? {
        guard spec.coverTreatment == .linenWrap else { return nil }
        let title = "BOOK OF YOU"
        let rawName = annual.coverReaderName
        let permitted = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = rawName.uppercased().unicodeScalars
            .filter { permitted.contains($0) }
            .map(String.init)
            .joined()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let remaining = max(0, 42 - title.count)
        let author = String(cleaned.prefix(remaining)).trimmingCharacters(in: .whitespaces)
        return (title, author)
    }

    @MainActor
    func setSeasonalDispatchHeld(id: String, shouldHold: Bool, now: Date = Date()) -> String {
        var dispatches = vault.data.seasonalDispatches ?? []
        guard let index = dispatches.firstIndex(where: { $0.id == id }) else {
            return "I lost the parcel's place in the ledger. It hasn't gone anywhere."
        }
        let updated = shouldHold
            ? SeasonalDispatchWindow.hold(dispatches[index], at: now)
            : SeasonalDispatchWindow.release(dispatches[index], at: now)
        dispatches[index] = updated
        vault.mutate { $0.seasonalDispatches = dispatches }
        surfaceRefreshDate = Date()
        return shouldHold
            ? "Held. It's back on the shelf, pretending that was its idea."
            : "Released. It has seven fresh days to fuss with its coat before it goes."
    }

    /// Sends every prepaid season whose steering window has closed. The Worker
    /// proves the entitlement again and serialises the Lulu submission, so a
    /// relaunch can retry this whole function without buying or posting twice.
    @MainActor
    func postDueSeasonalDispatchesIfNeeded(now: Date = Date()) async {
        guard let membershipID = vault.data.boundYearMembershipID else { return }
        let due = (vault.data.seasonalDispatches ?? [])
            .filter { SeasonalDispatchWindow.shouldPost($0, now: now) }
            .sorted { $0.boundAt < $1.boundAt }

        for dispatch in due {
            do {
                guard let edition = seasonalPrintVolume(for: dispatch, now: now),
                      let spec = printSpec(forSeasonalVariantID: dispatch.variantID) else {
                    continue
                }
                let bound = try await gemmaAnnualBinding(for: edition)
                let interior = try await makeSeasonalPrintInterior(bound, dispatch: dispatch, spec: spec)
                let variant = PhysicalBookVariant.from(spec)
                let client = PhysicalBookQuoteClient()
                let foil = seasonalFoilStamp(for: bound, spec: spec)
                let preparation = try await client.prepareMembershipDispatch(
                    membershipID: membershipID,
                    seasonKey: dispatch.seasonKey,
                    request: BoundYearDispatchRequest(
                        editionID: interior.editionID,
                        variant: variant,
                        pageCount: interior.pageCount,
                        // Paid extras are deliberately not smuggled through a
                        // prepaid order. They need a separate priced checkout.
                        selectedOptionIDs: [],
                        foilStampTitleText: foil?.title,
                        foilStampAuthorText: foil?.author
                    )
                )

                let order: PhysicalBookOrder
                if let submitted = preparation.order {
                    order = submitted
                } else {
                    guard let dispatchToken = preparation.dispatchToken,
                          let exactCoverDimensions = preparation.coverDimensions else {
                        throw NSError(
                            domain: "Bindery",
                            code: 15,
                            userInfo: [NSLocalizedDescriptionKey: "The print desk did not return this parcel's exact cover template."]
                        )
                    }
                    let cover = try makeSeasonalPrintCover(
                        bound,
                        dispatch: dispatch,
                        spec: spec,
                        pageCount: interior.pageCount,
                        exactDimensions: exactCoverDimensions
                    )
                    _ = try await client.uploadMembershipDispatchPrintFile(
                        kind: .interior,
                        fileURL: interior.url,
                        membershipID: membershipID,
                        seasonKey: dispatch.seasonKey,
                        editionID: interior.editionID,
                        dispatchToken: dispatchToken,
                        md5: interior.md5,
                        sha256: interior.sha256
                    )
                    _ = try await client.uploadMembershipDispatchPrintFile(
                        kind: .cover,
                        fileURL: cover.url,
                        membershipID: membershipID,
                        seasonKey: dispatch.seasonKey,
                        editionID: interior.editionID,
                        dispatchToken: dispatchToken,
                        md5: cover.md5,
                        sha256: cover.sha256
                    )
                    order = try await client.submitMembershipDispatch(
                        membershipID: membershipID,
                        seasonKey: dispatch.seasonKey,
                        dispatchToken: dispatchToken
                    )
                }
                guard order.luluPrintJobID != nil else { continue }
                markSeasonalDispatchPosted(dispatch, spec: spec, at: now)
                clearPublicationBindingCheckpoint(slot: chapteredVolumeBindingSlot(for: edition))
            } catch {
                await LocalBrainPublicationStageBoundary.persisted("seasonal-dispatch-aborted")
                // A prepaid parcel is a debt, so failure remains retryable and
                // visible in the Bindery rather than being marked as posted.
                colophonBindingNote = "\(dispatch.coverLine) is still by the door. The print desk balked: \(error.localizedDescription)"
            }
        }
    }

    private func printSpec(forSeasonalVariantID variantID: String) -> PrintSpec? {
        PrintSpec.allPrintableVariants.first {
            PhysicalBookVariant.id(for: $0.coverTreatment) == variantID
        }
    }

    private struct SeasonalPrintInterior {
        var editionID: String
        var pageCount: Int
        var url: URL
        var md5: String
        var sha256: String
    }

    private struct SeasonalPrintCover {
        var url: URL
        var md5: String
        var sha256: String
    }

    @MainActor
    private func makeSeasonalPrintInterior(
        _ edition: AnnualEdition,
        dispatch: SeasonalDispatch,
        spec: PrintSpec
    ) async throws -> SeasonalPrintInterior {
        let editionID = "\(dispatch.id)-\(dispatch.variantID)"
        let safeKey = dispatch.seasonKey.replacingOccurrences(of: "/", with: "-")
        let directory = FileManager.default.temporaryDirectory
        let interiorURL = directory.appendingPathComponent("ReEnchanted-Bound-Year-\(safeKey)-Interior.pdf")
        let plates = await illuminatedPlates(for: edition)
        // A bound year is the span these charts were built for.
        let charts = await editionMapPlates(for: edition, kind: .annual)
        let pageCount = try MonthlyEditionPDFWriter.writeVolumePrintInterior(
            edition,
            plates: plates,
            endpaper: charts.endpaper,
            mapPlates: charts.plates,
            spec: spec,
            to: interiorURL
        )
        let interior = try Data(contentsOf: interiorURL)
        return SeasonalPrintInterior(
            editionID: editionID,
            pageCount: pageCount,
            url: interiorURL,
            md5: Insecure.MD5.hash(data: interior).map { String(format: "%02x", $0) }.joined(),
            sha256: SHA256.hash(data: interior).map { String(format: "%02x", $0) }.joined()
        )
    }

    @MainActor
    private func makeSeasonalPrintCover(
        _ edition: AnnualEdition,
        dispatch: SeasonalDispatch,
        spec: PrintSpec,
        pageCount: Int,
        exactDimensions: PhysicalBookCoverDimensions
    ) throws -> SeasonalPrintCover {
        let safeKey = dispatch.seasonKey.replacingOccurrences(of: "/", with: "-")
        let coverURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReEnchanted-Bound-Year-\(safeKey)-Cover.pdf")
        try MonthlyEditionPDFWriter.writeVolumeCoverWrap(
            edition,
            spec: spec,
            pageCount: pageCount,
            artwork: seasonalCoverArtwork(for: dispatch),
            exactDimensions: exactDimensions,
            to: coverURL
        )
        let cover = try Data(contentsOf: coverURL)
        return SeasonalPrintCover(
            url: coverURL,
            md5: Insecure.MD5.hash(data: cover).map { String(format: "%02x", $0) }.joined(),
            sha256: SHA256.hash(data: cover).map { String(format: "%02x", $0) }.joined()
        )
    }

    @MainActor
    private func markSeasonalDispatchPosted(_ dispatch: SeasonalDispatch, spec: PrintSpec, at date: Date) {
        var dispatches = vault.data.seasonalDispatches ?? []
        guard let index = dispatches.firstIndex(where: { $0.id == dispatch.id }) else { return }
        dispatches[index] = SeasonalDispatchWindow.markPosted(dispatches[index], at: date)
        var pressed = vault.data.pressedVolumes ?? []
        let keepsakeID = "\(dispatch.id)-\(dispatch.variantID)"
        if !pressed.contains(where: { $0.id == keepsakeID }) {
            pressed.append(PressedVolumeKeepsake(
                id: keepsakeID,
                coverLine: dispatch.coverLine,
                bindingName: spec.name,
                pressedAt: date,
                destinationRegion: nil,
                copies: 1
            ))
        }
        vault.mutate {
            $0.seasonalDispatches = dispatches
            $0.pressedVolumes = pressed
        }
        surfaceRefreshDate = date
        colophonBindingNote = "\(dispatch.coverLine) went to the press. The parcel finally stopped pretending it wasn't eager."
    }

    /// The exact edition the BookShop should preview for physical printing.
    @MainActor
    var printPreviewEdition: MonthlyEdition? {
        guard var edition = resolveEditionForBinding() else { return nil }
        edition.publicationKind = .monthly
        return edition
    }

    /// Rebuilds the exact multi-chapter object standing at the door. It remains
    /// an `AnnualEdition` through the physical press; the monthly adapter below
    /// survives only for the older Publication House picker.
    @MainActor
    func seasonalPrintVolume(for requestedDispatch: SeasonalDispatch? = nil, now: Date = Date()) -> AnnualEdition? {
        let calendar = Calendar.current
        guard let thisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ), let fallbackSeasonStart = calendar.date(byAdding: .month, value: -3, to: thisMonth) else {
            return nil
        }

        let openDispatch = requestedDispatch ?? (vault.data.seasonalDispatches ?? [])
            .filter { !$0.hasPosted }
            .sorted { $0.boundAt > $1.boundAt }
            .first
        let dispatchStart = openDispatch
            .flatMap { seasonalStartDate(from: $0.seasonKey, calendar: calendar) }
            ?? fallbackSeasonStart

        let bindsAnnual = openDispatch?.isAnnualVolume ?? false
        let volumeStart = bindsAnnual
            ? (calendar.date(byAdding: .month, value: -9, to: dispatchStart) ?? dispatchStart)
            : dispatchStart

        let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 5000)) ?? narrativeEvents
        let archiveMemories = (try? BookDatabase.entityMemories(limit: 5000)) ?? entityMemories
        let matchingDispatch = openDispatch ?? (vault.data.seasonalDispatches ?? [])
            .filter { dispatch in
                guard let keyStart = seasonalStartDate(from: dispatch.seasonKey, calendar: calendar) else {
                    return false
                }
                return calendar.isDate(keyStart, equalTo: dispatchStart, toGranularity: .month)
            }
            .sorted { $0.boundAt > $1.boundAt }
            .first
        let seasonal = MonthlyEditionBuilder.seasonal(
            from: days,
            startingMonth: volumeStart,
            events: archiveEvents,
            entityMemories: archiveMemories,
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger,
            constellations: vault.data.constellations ?? [],
            wagers: vault.data.wagers ?? [],
            themes: vault.data.themes ?? [],
            storyConsequences: vault.data.storyConsequenceLedger?.receipts ?? [],
            facultyEntries: facultyEntries,
            readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
            readerRole: boundReaderRole,
            castActs: (vault.data.castActs ?? .empty).records,
            seasonName: matchingDispatch?.readerNamedSeason,
            monthsPerSeason: bindsAnnual ? 12 : BoundYearCycle.monthsPerSeason,
            bindsAnnual: bindsAnnual,
            publicationRecipe: bindsAnnual ? .boundYearAnnual : .boundYearSeason,
            includePrivateLifeAlmanac: includePrivateWeatherInMonthlyBinding,
            academySeason: academySeasonInputs,
            boundTales: vault.data.boundTales ?? [],
            now: now,
            calendar: calendar
        )
        guard !seasonal.isEmpty else { return nil }
        var volume = seasonal
        volume.coverLine = matchingDispatch?.coverLine ?? seasonal.resolvedCoverLine()
        volume.coverSubline = matchingDispatch?.resolvedCoverSubline ?? seasonal.resolvedCoverSubline()
        volume.readerNamedSeason = matchingDispatch?.readerNamedSeason ?? seasonal.readerNamedSeason
        volume.dedication = matchingDispatch?.dedication ?? seasonal.dedication
        volume.publicationKind = bindsAnnual ? .annual : .seasonal
        return volume
    }

    /// A reader-chosen calendar season. This is separate from a Bound Year
    /// dispatch: July-September stays July-September, regardless of when a
    /// membership began or when the reader finally opens the Bindery.
    @MainActor
    func calendarSeasonalPrintVolume(
        periodID: PublicationPeriodID? = nil,
        now: Date = Date()
    ) -> AnnualEdition? {
        let bindable = seasonalPublicationCandidates.filter(\.isBindable)
        let candidate: PublicationCandidate?
        if let periodID {
            candidate = bindable.first { $0.id == periodID }
        } else {
            candidate = bindable.first
        }
        guard let candidate else { return nil }

        let calendar = Calendar.current
        let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 5000)) ?? narrativeEvents
        let archiveMemories = (try? BookDatabase.entityMemories(limit: 5000)) ?? entityMemories
        let editorialNow = min(now, candidate.period.endDate.addingTimeInterval(-1))
        var volume = MonthlyEditionBuilder.seasonal(
            from: days,
            startingMonth: candidate.period.startDate,
            events: archiveEvents,
            entityMemories: archiveMemories,
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger,
            constellations: vault.data.constellations ?? [],
            wagers: vault.data.wagers ?? [],
            themes: vault.data.themes ?? [],
            storyConsequences: vault.data.storyConsequenceLedger?.receipts ?? [],
            facultyEntries: facultyEntries,
            readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
            readerRole: boundReaderRole,
            castActs: (vault.data.castActs ?? .empty).records,
            monthsPerSeason: BoundYearCycle.monthsPerSeason,
            bindsAnnual: false,
            publicationRecipe: .calendarSeason,
            includePrivateLifeAlmanac: includePrivateWeatherInMonthlyBinding,
            academySeason: academySeasonInputs,
            boundTales: vault.data.boundTales ?? [],
            now: editorialNow,
            calendar: calendar
        )
        guard !volume.isEmpty else { return nil }
        volume.publicationKind = .seasonal
        return volume
    }

    /// Compatibility proof for the existing single-edition shop list. Physical
    /// Bound Year fulfilment never calls this and therefore never loses chapter
    /// dividers, Cast pages, or volume-scale front matter.
    @MainActor
    func seasonalPrintEdition(for requestedDispatch: SeasonalDispatch? = nil, now: Date = Date()) -> MonthlyEdition? {
        guard let seasonal = seasonalPrintVolume(for: requestedDispatch, now: now) else { return nil }
        let recipeID: String
        if requestedDispatch?.isAnnualVolume == true {
            recipeID = PublicationPeriodRecipe.boundYearAnnual.rawValue
        } else if requestedDispatch != nil {
            recipeID = PublicationPeriodRecipe.boundYearSeason.rawValue
        } else {
            recipeID = PublicationPeriodRecipe.calendarSeason.rawValue
        }
        return flattenedPublicationVolume(seasonal, recipeID: recipeID)
    }

    @MainActor
    func calendarSeasonalPrintEdition(
        periodID: PublicationPeriodID? = nil,
        now: Date = Date()
    ) -> MonthlyEdition? {
        guard let seasonal = calendarSeasonalPrintVolume(periodID: periodID, now: now) else {
            return nil
        }
        return flattenedPublicationVolume(
            seasonal,
            recipeID: PublicationPeriodRecipe.calendarSeason.rawValue
        )
    }

    private func flattenedPublicationVolume(
        _ seasonal: AnnualEdition,
        recipeID: String
    ) -> MonthlyEdition? {
        guard var edition = seasonal.chapters.first else { return nil }

        edition.title = seasonal.title
        edition.subtitle = seasonal.subtitle
        edition.generatedAt = seasonal.generatedAt
        edition.startDate = seasonal.startDate
        edition.endDate = seasonal.endDate
        edition.dayCount = seasonal.dayCount
        edition.pageCount = seasonal.pageCount
        edition.readerName = seasonal.readerName
        edition.monthName = seasonal.resolvedCoverLine()
        edition.constellations = seasonal.constellations
        edition.foreword = seasonal.foreword
        edition.continuity = seasonal.continuity
        edition.closing = seasonal.closing
        edition.readerRole = seasonal.readerRole
        edition.dedication = seasonal.dedication
        edition.passageCompass = seasonal.chapters
            .flatMap { $0.passageCompass ?? [] }
        edition.marginalia = seasonal.chapters
            .flatMap { $0.marginalia ?? [] }
        edition.sections = seasonal.chapters.flatMap { chapter in
            chapter.sections.map { section in
                var seasonalSection = section
                seasonalSection.id = "season-\(BookThemeEngine.monthKey(for: chapter.startDate))-\(section.id)"
                seasonalSection.title = "\(chapter.monthName) · \(section.title)"
                return seasonalSection
            }
        }
        edition.publicationKind = seasonal.publicationKind
        edition.publicationRecipeID = recipeID
        edition.playLeaves = seasonal.playLeaves
        return edition
    }

    /// The volumes waiting at the Publication House. Building this list is an
    /// explicit doorway action rather than a body-time computation: annual and
    /// seasonal editorial work should happen once when the reader enters, not
    /// on every SwiftUI redraw.
    @MainActor
    func publicationHouseEditionChoices(now: Date = Date()) -> [MonthlyEdition] {
        let months = monthlyPublicationCandidates
            .filter(\.isBindable)
            .compactMap { resolveEditionForBinding(periodID: $0.id) }
        let seasons = seasonalPublicationCandidates
            .filter(\.isBindable)
            .compactMap { calendarSeasonalPrintEdition(periodID: $0.id, now: now) }
        let years = annualPublicationCandidates
            .filter(\.isBindable)
            .compactMap { annualPrintEdition(periodID: $0.id, now: now) }
        let candidates = weeklyPrintEditions(now: now) + months + seasons + years
        var seen: Set<String> = []
        return candidates.filter { edition in
            let key = [
                edition.publicationRecipeID ?? "calendar-monthly",
                BookThemeEngine.monthKey(for: edition.startDate),
                BookThemeEngine.monthKey(for: edition.endDate)
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    /// Carries the exact reading copy to the press. The editor's note and
    /// closing in `WeeklyIssueReader` may have been written during binding, so
    /// rebuilding from the underlying week here would be a quiet substitution.
    @MainActor
    func weeklyPrintEdition(reader: WeeklyIssueReader, now: Date = Date()) -> MonthlyEdition {
        weeklyPrintEdition(
            from: WeeklyPublicationMatter(
                issue: reader.issue,
                card: reader.card,
                readerName: reader.readerName,
                editorialNote: reader.editorialLead,
                closingNote: reader.closingLine
            ),
            generatedAt: now
        )
    }

    @MainActor
    private func weeklyPrintEditions(now: Date) -> [MonthlyEdition] {
        var mattersByNumber: [Int: (matter: WeeklyPublicationMatter, keptAt: Date)] = [:]
        for artifact in (days + [today])
            .flatMap(\.pages)
            .compactMap(\.weeklyIssueArtifact) {
            let matter = WeeklyPublicationMatter(
                issue: artifact.issue,
                card: artifact.card,
                readerName: artifact.readerName,
                editorialNote: artifact.editorialNote,
                closingNote: artifact.closingNote
            )
            if let existing = mattersByNumber[artifact.issue.number],
               existing.keptAt >= artifact.keptAt {
                continue
            }
            mattersByNumber[artifact.issue.number] = (matter, artifact.keptAt)
        }

        let publicationCalendar = vault.data.publicationEpoch?.calendar() ?? .current
        let candidates = PublicationPeriodCatalog.readerWeeks(
            days: days,
            today: today,
            frozenAnchor: vault.data.publicationEpoch?.readerWeekAnchor(calendar: publicationCalendar),
            boundRevisionCounts: boundPublicationRevisionCounts,
            now: now,
            calendar: publicationCalendar
        ).filter(\.isBindable)
        for candidate in candidates {
            guard let issue = WeeklyIssue.issue(
                for: candidate.period,
                days: days,
                today: today,
                boundTales: vault.data.boundTales ?? [],
                readerRole: boundReaderRole,
                castActs: (vault.data.castActs ?? .empty).records,
                now: now,
                calendar: publicationCalendar
            ), mattersByNumber[issue.number] == nil else { continue }
            let matter = WeeklyPublicationMatter(
                issue: issue,
                card: WeeklyIssueShareCard.make(
                    issue: issue,
                    selfFacts: sourceInputs.selfFacts,
                    isDeluxe: hasPassedTheBookOn
                ),
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                editorialNote: nil,
                closingNote: nil
            )
            mattersByNumber[issue.number] = (matter, now)
        }

        return mattersByNumber.values
            .sorted { $0.matter.issue.number > $1.matter.issue.number }
            .map { weeklyPrintEdition(from: $0.matter, generatedAt: now) }
    }

    private func weeklyPrintEdition(
        from matter: WeeklyPublicationMatter,
        generatedAt: Date
    ) -> MonthlyEdition {
        let issue = matter.issue
        var edition = MonthlyEdition(
            title: issue.resolvedEditorialTitle,
            subtitle: "Issue No. \(issue.number) · \(issue.dateRange)",
            generatedAt: generatedAt,
            startDate: issue.startDate,
            endDate: issue.endDate,
            dayCount: WeeklyIssue.weekDays,
            pageCount: issue.keptCount,
            readerName: matter.readerName,
            chapterNumber: issue.number,
            monthName: issue.resolvedEditorialTitle,
            theme: nil,
            constellations: [],
            foreword: matter.editorialNote
                ?? "This week closed with \(issue.keptCount) kept \(issue.keptCount == 1 ? "page" : "pages") inside it.",
            sections: [],
            continuity: .empty,
            howYouSee: nil
        )
        edition.bindingStory = issue.bindingStory
        edition.closing = matter.closingNote
        edition.passageCompass = issue.passageCompass
        edition.readerRole = issue.readerRole
        edition.marginalia = issue.marginalia
        edition.dedication = issue.dedication
        edition.publicationKind = .weekly
        edition.publicationRecipeID = "weekly-issue-\(issue.number)"
        edition.weeklyPublication = matter
        edition.playLeaves = issue.playLeaves
        return edition
    }

    @MainActor
    private func annualPrintEdition(
        periodID: PublicationPeriodID? = nil,
        now: Date
    ) -> MonthlyEdition? {
        let calendar = Calendar.current
        let bindable = PublicationPeriodCatalog.calendarYears(
            days: days,
            today: today,
            boundRevisionCounts: boundPublicationRevisionCounts,
            now: now,
            calendar: calendar
        ).filter(\.isBindable)
        let candidate: PublicationCandidate?
        if let periodID {
            candidate = bindable.first { $0.id == periodID }
        } else {
            candidate = bindable.first
        }
        guard let candidate else { return nil }
        let targetYear = calendar.component(.year, from: candidate.period.startDate)
        let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 20_000)) ?? narrativeEvents
        let archiveMemories = (try? BookDatabase.entityMemories(limit: 20_000)) ?? entityMemories
        let annual = MonthlyEditionBuilder.annual(
            targetYear,
            from: days,
            events: archiveEvents,
            entityMemories: archiveMemories,
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger,
            constellations: vault.data.constellations ?? [],
            wagers: vault.data.wagers ?? [],
            themes: vault.data.themes ?? [],
            storyConsequences: vault.data.storyConsequenceLedger?.receipts ?? [],
            facultyEntries: facultyEntries,
            readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
            readerRole: boundReaderRole,
            castActs: (vault.data.castActs ?? .empty).records,
            includePrivateLifeAlmanac: includePrivateWeatherInMonthlyBinding,
            academySeason: academySeasonInputs,
            boundTales: vault.data.boundTales ?? [],
            now: now,
            calendar: calendar
        )
        guard !annual.isEmpty, var edition = annual.chapters.first else { return nil }
        edition.title = annual.title
        edition.subtitle = annual.subtitle
        edition.generatedAt = annual.generatedAt
        edition.startDate = annual.startDate
        edition.endDate = annual.endDate
        edition.dayCount = annual.dayCount
        edition.pageCount = annual.pageCount
        edition.readerName = annual.readerName
        edition.monthName = annual.resolvedCoverLine()
        edition.constellations = annual.constellations
        edition.foreword = annual.foreword
        edition.continuity = annual.continuity
        edition.closing = annual.closing
        edition.readerRole = annual.readerRole
        edition.dedication = annual.dedication
        edition.passageCompass = annual.chapters.flatMap { $0.passageCompass ?? [] }
        edition.marginalia = annual.chapters.flatMap { $0.marginalia ?? [] }
        edition.sections = annual.chapters.flatMap { chapter in
            chapter.sections.map { section in
                var annualSection = section
                annualSection.id = "annual-\(BookThemeEngine.monthKey(for: chapter.startDate))-\(section.id)"
                annualSection.title = "\(chapter.monthName) · \(section.title)"
                return annualSection
            }
        }
        edition.publicationKind = .annual
        edition.publicationRecipeID = PublicationPeriodRecipe.calendarYear.rawValue
        edition.playLeaves = annual.playLeaves
        return edition
    }

    private func seasonalStartDate(from seasonKey: String, calendar: Calendar) -> Date? {
        let parts = seasonKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              parts[1].first == "S",
              let month = Int(parts[1].dropFirst()) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    /// Binds the month to a PDF. The deterministic foreword/closing generated by
    /// `MonthlyEditionBuilder` are fallback scaffolding; the export path asks the
    /// on-device brain for fresh wrapper prose before sewing the PDF.
    /// Resolves which month the binder should sew: the month named on the shelf,
    /// else the previous calendar month, else the most recent month that kept
    /// pages. Returns nil if there is nothing with content to bind. Shared by the
    /// screen-PDF bind and the print-ready export.
    @MainActor
    private func resolveEditionForBinding(periodID: PublicationPeriodID? = nil) -> MonthlyEdition? {
        let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 5000)) ?? narrativeEvents
        let archiveMemories = (try? BookDatabase.entityMemories(limit: 5000)) ?? entityMemories
        let now = Date()
        func buildMonth(starting monthStart: Date) -> MonthlyEdition {
            let calendar = Calendar.current
            let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? now
            return MonthlyEditionBuilder.edition(
                from: days,
                events: archiveEvents,
                entityMemories: archiveMemories,
                entityBelief: entityBeliefLedger,
                pageBelief: pageBeliefLedger,
                constellations: vault.data.constellations ?? [],
                wagers: vault.data.wagers ?? [],
                themes: vault.data.themes ?? [],
                storyConsequences: vault.data.storyConsequenceLedger?.receipts ?? [],
                facultyEntries: facultyEntries,
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                readerRole: boundReaderRole,
                startDate: monthStart,
                endDate: end,
                generatedAt: now,
                includePrivateWeatherSummary: includePrivateWeatherInMonthlyBinding,
                academySeason: academySeasonInputs,
                boundTales: vault.data.boundTales ?? [],
                // What the Academy did to each other this month. The volume
                // quotes these; it never paraphrases them.
                castActs: (vault.data.castActs ?? .empty).records,
                // The private laws as they stood when this month was bound.
                grimoire: vault.data.grimoire ?? GrimoireLedger()
            )
        }
        let bindable = monthlyPublicationCandidates.filter(\.isBindable)
        let candidate: PublicationCandidate?
        if let periodID {
            candidate = bindable.first { $0.id == periodID }
        } else if let chosen = selectedEditionMonth {
            candidate = bindable.first {
                Calendar.current.isDate($0.period.startDate, equalTo: chosen, toGranularity: .month)
            }
        } else {
            candidate = bindable.first
        }
        guard let candidate else { return nil }
        var edition = buildMonth(starting: candidate.period.startDate)
        edition.publicationRecipeID = candidate.period.recipe.rawValue
        let coverLedger = PublicationMonthlyCoverSelectionLedger.decode(
            officialMonthlyCoverSelectionLedgerData
        )
        edition.publicationCoverPlateID = PublicationCoverCatalogue
            .selectedOfficialMonthlyCover(
                for: candidate.period.startDate,
                preferredID: coverLedger.preferredCoverID(for: candidate.period.startDate)
            )?
            .id
        return edition.isEmpty ? nil : edition
    }

    @MainActor
    func exportMonthlyEdition(
        periodID: PublicationPeriodID? = nil,
        useGemmaClosing _: Bool = false,
        dedication: BoundDedication? = nil
    ) {
        guard let edition = resolveEditionForBinding(periodID: periodID) else {
            colophonBindingNote = "I turned to that month and found the leaves still blank. Keep a page or two there first, and I'll have something to sew."
            BookFeedback.play(.error)
            return
        }
        var pending = edition
        pending.dedication = dedication
        let wasShopOpen = isBookShopPresented
        isBookShopPresented = false
        colophonBindingNote = "Asking Gemma to write the cover leaves for \(edition.monthName)…"
        Task { @MainActor in
            do {
                let bound = try await gemmaMonthlyBinding(for: pending)
                // Composed before the binding starts, so the plate work never lands
                // inside the PDF pass.
                let plates = await illuminatedPlates(for: bound)
                let charts = await editionMapPlates(for: bound)
                try bindMonthlyEditionPDF(
                    bound,
                    plates: plates,
                    endpaper: charts.endpaper,
                    mapPlates: charts.plates,
                    afterShopDismiss: wasShopOpen
                )
                clearPublicationBindingCheckpoint(slot: monthlyBindingSlot(for: pending))
            } catch {
                await LocalBrainPublicationStageBoundary.persisted("monthly-aborted")
                colophonBindingNote = "The thread snapped mid-stitch: the month would not bind. (\(error.localizedDescription))"
                BookFeedback.play(.error)
            }
        }
    }

    /// Binds an already-composed publication shape as a keepable reading PDF.
    /// The seasonal volume reaches this seam from the Bookshop; weekly, monthly,
    /// and annual editions keep their richer dedicated binding ceremonies.
    @MainActor
    func exportComposedEditionPDF(
        _ edition: MonthlyEdition,
        periodID: PublicationPeriodID? = nil
    ) {
        let wasShopOpen = isBookShopPresented
        isBookShopPresented = false
        colophonBindingNote = "The digital needle has \(edition.title) by the corners…"

        Task { @MainActor in
            do {
                let plates = await illuminatedPlates(for: edition)
                let startKey = BookThemeEngine.monthKey(for: edition.startDate)
                let endKey = BookThemeEngine.monthKey(for: edition.endDate)
                let kind = edition.publicationKind?.rawValue ?? "edition"
                let archiveKey = "\(kind)-\(startKey)-\(endKey)"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ReEnchanted-\(archiveKey).pdf")
                try MonthlyEditionPDFWriter.write(edition, plates: plates, to: url)
                let resolvedPeriodID = periodID ?? publicationPeriodID(for: edition)
                let keptURL = try keepMonthlyEdition(
                    edition,
                    monthKey: archiveKey,
                    renderedPDF: url,
                    periodID: resolvedPeriodID
                )
                preparedMonthlyEditionURL = keptURL
                preparedMonthlyEditionPeriodID = resolvedPeriodID
                colophonBindingNote = "\(edition.title) is bound as a PDF and kept on the Book of You shelf."
                BookFeedback.play(.braidComplete)

                let reader = MonthlyEditionReader(
                    edition: edition,
                    pdfURL: keptURL,
                    periodID: resolvedPeriodID
                )
                if wasShopOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        monthlyEditionReader = reader
                    }
                } else {
                    monthlyEditionReader = reader
                }
            } catch {
                colophonBindingNote = "The thread snapped mid-stitch: \(edition.title) would not bind. (\(error.localizedDescription))"
                BookFeedback.play(.error)
            }
        }
    }

    @MainActor
    func exportWeeklyIssuePDF(
        periodID: PublicationPeriodID? = nil,
        forceRebind: Bool = false,
        dedication: BoundDedication? = nil,
        replacesDedication: Bool = false
    ) {
        guard weeklyIssueBindingNote == nil else { return }
        let candidate: PublicationCandidate?
        if let periodID {
            candidate = bindableWeeklyPublicationCandidates.first { $0.id == periodID }
        } else {
            candidate = bindableWeeklyPublicationCandidates.first
        }
        let calendar = vault.data.publicationEpoch?.calendar() ?? .current
        guard let candidate,
              var issue = WeeklyIssue.issue(
                  for: candidate.period,
                  days: days,
                  today: today,
                  boundTales: vault.data.boundTales ?? [],
                  readerRole: boundReaderRole,
                  castActs: (vault.data.castActs ?? .empty).records,
                  now: Date(),
                  calendar: calendar
              ) else {
            let note = "No weekly issue is ready to bind yet. A week needs to close with enough kept pages first."
            colophonBindingNote = note
            // The bind can now be asked for from the desk Page, where the
            // BookShop's own note never shows. Say it where that reader is.
            statusMessage = note
            BookFeedback.play(.error)
            return
        }
        if replacesDedication {
            issue.dedication = dedication
        } else if let existing = cachedWeeklyIssueReader?.issue.dedication {
            issue.dedication = existing
        }
        // The reader takes over from here; if it was launched from the BookShop,
        // close the shop so the issue can present cleanly over the main body.
        let wasShopOpen = isBookShopPresented
        isBookShopPresented = false

        // If this exact issue is already wrapped, re-open the reader instantly -
        // unless the reader explicitly asked for a fresh (re-written) bind.
        if !forceRebind,
           let cached = cachedWeeklyIssueReader,
           cached.issue.number == issue.number,
           cached.issue.startDate == issue.startDate,
           cached.issue.endDate == issue.endDate,
           cached.issue.dedication == issue.dedication,
           FileManager.default.fileExists(atPath: cached.cardURL.path),
           FileManager.default.fileExists(atPath: cached.pdfURL.path) {
            do {
                let kept = try keepWeeklyIssue(cached, periodID: candidate.id)
                cachedWeeklyIssueReader = kept
                preparedWeeklyIssueCardURL = kept.cardURL
                preparedWeeklyIssuePDFURL = kept.pdfURL
                preparedWeeklyIssuePeriodID = candidate.id
                clearPublicationBindingCheckpoint(slot: weeklyBindingSlot(for: issue))
                presentWeeklyIssueReader(kept, afterShopDismiss: wasShopOpen)
            } catch {
                colophonBindingNote = "The issue opened, but it would not stay on the shelf: \(error.localizedDescription)"
                presentWeeklyIssueReader(cached, afterShopDismiss: wasShopOpen)
            }
            return
        }

        if forceRebind {
            do {
                try PublicationBindingCheckpointStore.remove(slot: weeklyBindingSlot(for: issue))
            } catch {
                colophonBindingNote = "The old issue draft would not come off the binding table: \(error.localizedDescription)"
                BookFeedback.play(.error)
                return
            }
        }

        // "Wait for Gemma": if the on-device brain is installed we ask it to
        // bind the daily braids into a story, then write the issue's wrapper
        // prose. The first pass loads the model and can take a while, so a visible
        // progress overlay stays up until the reading copy is pressed.
        let brainReady = LocalModelManager.report().isReady
        let progress = brainReady
            ? "I'm writing Issue No. \(issue.number) in my own words…\nThe first pass can take a moment while the local brain wakes."
            : "The local brain is resting: binding Issue No. \(issue.number) in my standard hand…"
        weeklyIssueBindingNote = progress
        colophonBindingNote = progress

        Task { @MainActor in
            do {
                let wrapper: WeeklyIssueBindingDraft
                if brainReady {
                    wrapper = try await gemmaWeeklyIssueBinding(for: issue)
                } else {
                    var standardIssue = issue
                    standardIssue.looseThread = standardIssue.resolvedLooseThread
                    wrapper = WeeklyIssueBindingDraft(
                        issue: standardIssue,
                        editorialNote: nil,
                        closingNote: nil
                    )
                }
                let boundIssue = wrapper.issue
                let card = WeeklyIssueShareCard.make(
                    issue: boundIssue,
                    selfFacts: sourceInputs.selfFacts,
                    isDeluxe: hasPassedTheBookOn
                )
                let directory = FileManager.default.temporaryDirectory
                let cardURL = directory
                    .appendingPathComponent("ReEnchanted-Weekly-Wrap-\(issue.number).png")
                try WeeklyIssueShareCardRenderer.write(card, to: cardURL)
                let url = directory
                    .appendingPathComponent("ReEnchanted-Weekly-Issue-\(issue.number).pdf")
                let readerName = CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs)
                let weekCharts = await editionMapPlates(
                    from: boundIssue.startDate,
                    to: boundIssue.endDate,
                    kind: .weekly,
                    readerName: readerName
                )
                try WeeklyIssuePDFWriter.write(
                    boundIssue,
                    readerName: readerName,
                    shareCard: card,
                    editorialNote: wrapper.editorialNote,
                    closingNote: wrapper.closingNote,
                    chart: weekCharts.endpaper,
                    to: url
                )
                preparedWeeklyIssueCardURL = cardURL
                preparedWeeklyIssuePDFURL = url
                preparedWeeklyIssuePeriodID = candidate.id
                let reader = WeeklyIssueReader(
                    issue: boundIssue,
                    card: card,
                    readerName: readerName,
                    editorialNote: wrapper.editorialNote,
                    closingNote: wrapper.closingNote,
                    cardURL: cardURL,
                    pdfURL: url
                )
                let keptReader = try keepWeeklyIssue(reader, periodID: candidate.id)
                cachedWeeklyIssueReader = keptReader
                preparedWeeklyIssueCardURL = keptReader.cardURL
                preparedWeeklyIssuePDFURL = keptReader.pdfURL
                preparedWeeklyIssuePeriodID = candidate.id
                clearPublicationBindingCheckpoint(slot: weeklyBindingSlot(for: issue))
                weeklyBindingDedicationText = ""
                weeklyIssueBindingNote = nil
                presentWeeklyIssueReader(keptReader, afterShopDismiss: wasShopOpen)
                colophonBindingNote = boundIssue.bindingStory != nil
                    ? "Issue No. \(issue.number) is wrapped around the story its daily bindings became, and kept on the Book of You shelf."
                    : "Issue No. \(issue.number) is wrapped and kept on the Book of You shelf."
                BookFeedback.play(.braidComplete)
            } catch {
                await LocalBrainPublicationStageBoundary.persisted("weekly-aborted")
                weeklyIssueBindingNote = nil
                colophonBindingNote = "The weekly issue would not bind: \(error.localizedDescription)"
                BookFeedback.play(.error)
            }
        }
    }

    /// Moves a generated issue out of the temporary directory and records it as
    /// a real archive page. Rebinding replaces that issue's artifact rather than
    /// adding a duplicate card to the Book of You shelf.
    @MainActor
    private func keepWeeklyIssue(
        _ reader: WeeklyIssueReader,
        periodID: PublicationPeriodID? = nil
    ) throws -> WeeklyIssueReader {
        let directory = try weeklyIssueArchiveDirectory()
        let cardURL = directory.appendingPathComponent("Weekly-Issue-\(reader.issue.number)-Card.png")
        let pdfURL = directory.appendingPathComponent("Weekly-Issue-\(reader.issue.number).pdf")
        try replaceArchiveFile(at: cardURL, with: reader.cardURL)
        try replaceArchiveFile(at: pdfURL, with: reader.pdfURL)

        let keptReader = WeeklyIssueReader(
            issue: reader.issue,
            card: reader.card,
            readerName: reader.readerName,
            editorialNote: reader.editorialNote,
            closingNote: reader.closingNote,
            cardURL: cardURL,
            pdfURL: pdfURL
        )
        let artifact = KeptWeeklyIssueArtifact(
            issue: keptReader.issue,
            card: keptReader.card,
            readerName: keptReader.readerName,
            editorialNote: keptReader.editorialNote,
            closingNote: keptReader.closingNote,
            cardPath: cardURL.path,
            pdfPath: pdfURL.path,
            keptAt: Date(),
            periodID: periodID
        )
        let tag = "weekly-issue:\(reader.issue.number)"
        let storyParagraphs = keptReader.issue.bindingStory.map { [$0] } ?? []
        let findings = keptReader.issue.revelations.map { "\($0.title): \($0.body)" }
        let looseThread = keptReader.issue.resolvedLooseThread.map { ["\($0.title): \($0.body)"] } ?? []
        let body = ([keptReader.editorialLead]
            + storyParagraphs
            + findings
            + reader.issue.highlights.map { "• \($0)" }
            + looseThread
            + [keptReader.closingLine])
            .joined(separator: "\n\n")

        var archiveDay = today
        if let dayIndex = days.firstIndex(where: { day in day.pages.contains { $0.tags.contains(tag) } }),
           let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.tags.contains(tag) }) {
            archiveDay = days[dayIndex]
            var page = archiveDay.pages[pageIndex]
            page.promptText = "\(reader.issue.resolvedEditorialTitle) · Weekly Issue No. \(reader.issue.number)"
            page.userInput = body
            page.sourceID = "weekly-issue"
            page.origin = .generated
            page.tags = ["weekly-issue", tag, "edition", "bindery"]
            page.mediaAssets = [weeklyIssueCardAsset(url: cardURL, issue: reader.issue)]
            page.weeklyIssueArtifact = artifact
            archiveDay.pages[pageIndex] = page
        } else {
            archiveDay.pages.append(BookPage(
                id: "weekly-issue-\(reader.issue.number)",
                type: .bindery,
                promptText: "\(reader.issue.resolvedEditorialTitle) · Weekly Issue No. \(reader.issue.number)",
                userInput: body,
                tags: ["weekly-issue", tag, "edition", "bindery"],
                sourceID: "weekly-issue",
                origin: .generated,
                mediaAssets: [weeklyIssueCardAsset(url: cardURL, issue: reader.issue)],
                weeklyIssueArtifact: artifact
            ))
        }
        persist(day: archiveDay, message: "Issue No. \(reader.issue.number) is kept in the Book of You.")
        return keptReader
    }

    /// Reopens an archived issue. If iOS has cleared one of its rendered files,
    /// the stored issue model is enough to press that file again without Gemma.
    @MainActor
    func openKeptWeeklyIssue(_ page: BookPage) {
        guard let artifact = page.weeklyIssueArtifact else { return }
        if activeBookDivision != nil {
            activeBookDivision = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openKeptWeeklyIssue(page)
            }
            return
        }
        do {
            let directory = try weeklyIssueArchiveDirectory()
            let cardURL = directory.appendingPathComponent("Weekly-Issue-\(artifact.issue.number)-Card.png")
            let pdfURL = directory.appendingPathComponent("Weekly-Issue-\(artifact.issue.number).pdf")
            if !FileManager.default.fileExists(atPath: cardURL.path) {
                try WeeklyIssueShareCardRenderer.write(artifact.card, to: cardURL)
            }
            if !FileManager.default.fileExists(atPath: pdfURL.path) {
                try WeeklyIssuePDFWriter.write(
                    artifact.issue,
                    readerName: artifact.readerName,
                    shareCard: artifact.card,
                    editorialNote: artifact.editorialNote,
                    closingNote: artifact.closingNote,
                    to: pdfURL
                )
            }
            let reader = WeeklyIssueReader(
                issue: artifact.issue,
                card: artifact.card,
                readerName: artifact.readerName,
                editorialNote: artifact.editorialNote,
                closingNote: artifact.closingNote,
                cardURL: cardURL,
                pdfURL: pdfURL
            )
            cachedWeeklyIssueReader = reader
            preparedWeeklyIssueCardURL = cardURL
            preparedWeeklyIssuePDFURL = pdfURL
            preparedWeeklyIssuePeriodID = weeklyPublicationPeriodID(for: artifact)
            weeklyIssueReader = reader
            BookFeedback.play(.openPage)
        } catch {
            statusMessage = "Issue No. \(artifact.issue.number) would not open: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    private func weeklyIssueArchiveDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = base
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("WeeklyIssues", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func replaceArchiveFile(at destination: URL, with source: URL) throws {
        guard destination.standardizedFileURL != source.standardizedFileURL else { return }
        let files = FileManager.default
        guard files.fileExists(atPath: destination.path) else {
            try files.copyItem(at: source, to: destination)
            return
        }

        // Re-bind must not tear the old book off the shelf before its
        // replacement is safely beside it. Stage in the archive directory,
        // then let the filesystem exchange the complete files in one step.
        let staged = destination.deletingLastPathComponent().appendingPathComponent(
            ".\(destination.lastPathComponent).replacement-\(UUID().uuidString)"
        )
        do {
            try files.copyItem(at: source, to: staged)
            _ = try files.replaceItemAt(destination, withItemAt: staged)
        } catch {
            try? files.removeItem(at: staged)
            throw error
        }
    }

    private func weeklyIssueCardAsset(url: URL, issue: WeeklyIssue) -> BookPageMediaAsset {
        BookPageMediaAsset(
            kind: .renderedImageFile,
            reference: url.path,
            caption: "The cover of \(issue.resolvedEditorialTitle), Weekly Issue No. \(issue.number), \(issue.dateRange).",
            sourceID: "weekly-issue",
            metadata: ["weeklyIssueNumber": "\(issue.number)"]
        )
    }

    /// Presents the weekly issue reader, holding a beat when the BookShop sheet is
    /// still animating out so the two sheets don't collide on the same frame.
    @MainActor
    private func presentWeeklyIssueReader(_ reader: WeeklyIssueReader, afterShopDismiss: Bool) {
        guard afterShopDismiss else {
            weeklyIssueReader = reader
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            weeklyIssueReader = reader
        }
    }

    /// Builds the two files a print-on-demand house needs: a full-bleed interior
    /// and a spine-aware cover wrap, and surfaces both under the share mark. No
    /// account, backend, or fee yet: the reader hand-uploads them to a printer
    /// like Lulu for a physical hardcover proof.
    @MainActor
    func exportPrintReadyEdition(spec: PrintSpec = .hardcover6x9, coverPhoto: UIImage? = nil) {
        guard let edition = resolveEditionForBinding() else {
            colophonBindingNote = "I turned to that month and found the leaves still blank. Keep a page or two there first, and I'll have something to press."
            BookFeedback.play(.error)
            return
        }
        colophonBindingNote = "Setting \(edition.monthName) for the press…"
        Task { @MainActor in
            do {
                // A kept weekly issue already carries its own binding story,
                // editor's note, and closing. Running the monthly writer here
                // would replace that finished issue with a second interpretation.
                let bound: MonthlyEdition
                if edition.publicationKind == .weekly {
                    bound = edition
                } else {
                    bound = try await gemmaMonthlyBinding(for: edition)
                }
                try exportPrintReadyEdition(bound, spec: spec, coverPhoto: coverPhoto)
                if edition.publicationKind != .weekly {
                    clearPublicationBindingCheckpoint(slot: monthlyBindingSlot(for: edition))
                }
            } catch {
                await LocalBrainPublicationStageBoundary.persisted("print-edition-aborted")
                colophonBindingNote = "The press would not take it: \(error.localizedDescription)"
                BookFeedback.play(.error)
            }
        }
    }

    /// Sends an already chosen edition through the existing print writer. This
    /// is what lets a seasonal volume use the real press instead of pretending
    /// to be whichever month the Book would otherwise choose today.
    @MainActor
    func exportPrintReadyEdition(
        edition: MonthlyEdition,
        spec: PrintSpec,
        coverPhoto: UIImage? = nil
    ) {
        colophonBindingNote = "Setting \(edition.monthName) for the press…"
        Task { @MainActor in
            do {
                // Weekly issues are already edited publications. Preserve the
                // archived editor's note, binding story, daily matter, and closing
                // instead of passing them through the monthly writer a second time.
                let bound: MonthlyEdition
                if edition.publicationKind == .weekly {
                    bound = edition
                } else {
                    bound = try await gemmaMonthlyBinding(for: edition)
                }
                try exportPrintReadyEdition(bound, spec: spec, coverPhoto: coverPhoto)
                if edition.publicationKind != .weekly {
                    clearPublicationBindingCheckpoint(slot: monthlyBindingSlot(for: edition))
                }
            } catch {
                await LocalBrainPublicationStageBoundary.persisted("print-edition-aborted")
                colophonBindingNote = "The press would not take it: \(error.localizedDescription)"
                BookFeedback.play(.error)
            }
        }
    }

    @MainActor
    private func exportPrintReadyEdition(_ edition: MonthlyEdition, spec: PrintSpec, coverPhoto: UIImage? = nil) throws {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let startStamp = formatter.string(from: edition.startDate)
            let endStamp = formatter.string(from: edition.endDate)
            let calendarStamp = startStamp == endStamp ? startStamp : "\(startStamp)-through-\(endStamp)"
            let stamp = (edition.publicationRecipeID ?? calendarStamp)
                .replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression)
            let dir = FileManager.default.temporaryDirectory
            let interiorURL = dir.appendingPathComponent("ReEnchanted-Print-Interior-\(stamp).pdf")
            let coverURL = dir.appendingPathComponent("ReEnchanted-Print-Cover-\(stamp).pdf")

            let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: spec, to: interiorURL)
            try MonthlyEditionPDFWriter.writeCoverWrap(edition, spec: spec, pageCount: pages, coverPhoto: coverPhoto, to: coverURL)

            preparedPrintInteriorURL = interiorURL
            preparedPrintCoverURL = coverURL
            let spine = PrintGeometry.spineWidthInches(pageCount: pages, spec: spec)
            let trim = "\(String(format: "%g", spec.trimWidthInches))×\(String(format: "%g", spec.trimHeightInches))in"
            let bindingGeometry = spec.coverTreatment == .saddleStitch
                ? "folded in groups of four, with no printed spine"
                : "with a \(String(format: "%.2f", spine))in spine"
            colophonBindingNote = "\(edition.monthName) is set for the press as \(spec.name): \(pages) pages at \(trim), \(bindingGeometry). I'll take it from here."
            // The print-ready export gets its own foil-stamp ceremony, not the braid cue.
            let physicalForm = spec.coverTreatment == .saddleStitch
                ? "saddle-stitched issue"
                : (spec.coverTreatment.wrapsAroundBoard ? "hardcover" : "softcover")
            celebratePrintReady(
                monthName: edition.monthName,
                subtitle: "A \(pages)-page \(trim) \(physicalForm), set for the press."
            )
        } catch {
            throw error
        }
    }

    /// Writes a built edition to a PDF, surfaces it under the share mark, and
    /// Composes the month's illuminated plates before the PDF pass begins.
    ///
    /// `ImageRenderer` is `@MainActor`, so this is unavoidably main-thread work
    ///, but it is done *here*, ahead of binding, with a yield between cards so
    /// the sewing animation keeps ticking instead of freezing on the frames
    /// meant to cover the wait. The renderer is cache-first and the composition
    /// is seed-deterministic, so only the first binding of a given line pays.
    @MainActor
    private func illuminatedPlates(for edition: MonthlyEdition) async -> [MonthlyEditionPDFWriter.IlluminatedPlate] {
        let selections = (edition.passageCompass ?? []).prefix(4)
        guard !selections.isEmpty else { return [] }

        var plates: [MonthlyEditionPDFWriter.IlluminatedPlate] = []
        for (index, selection) in selections.enumerated() {
            let quote = selection.excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty else { continue }
            let url = IlluminatedQuoteCardRenderer.render(
                quote: quote,
                sourceTitle: edition.chapterHeading,
                weatherLine: edition.theme?.name ?? "",
                dateLine: edition.monthName,
                // The plate wears the visual style of the page the line came
                // from, so an illuminated souvenir still looks like a souvenir.
                style: PageVisualStyle.style(for: selection.pageType),
                seed: abs(quote.stableHash) &+ index
            )
            if let url, let image = UIImage(contentsOfFile: url.path) {
                plates.append(
                    .init(image: image, caption: selection.reason.nonEmpty ?? edition.monthName)
                )
            }
            await Task.yield()
        }
        return plates
    }

    /// A volume plate signature samples across chapters before taking a second
    /// line from any one month. The old flattened print path let the first month
    /// quietly monopolise the artwork.
    @MainActor
    private func illuminatedPlates(for annual: AnnualEdition) async -> [MonthlyEditionPDFWriter.IlluminatedPlate] {
        typealias Pick = (chapter: MonthlyEdition, selection: MeaningfulPassageSelector.Selection)
        let limit = annual.publicationKind == .annual ? 8 : 6
        var picks: [Pick] = []
        for offset in 0..<4 where picks.count < limit {
            for chapter in annual.chapters where picks.count < limit {
                let selections = chapter.passageCompass ?? []
                guard selections.indices.contains(offset) else { continue }
                picks.append((chapter, selections[offset]))
            }
        }
        guard !picks.isEmpty else { return [] }

        var plates: [MonthlyEditionPDFWriter.IlluminatedPlate] = []
        for (index, pick) in picks.enumerated() {
            let quote = pick.selection.excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty else { continue }
            let url = IlluminatedQuoteCardRenderer.render(
                quote: quote,
                sourceTitle: pick.chapter.chapterHeading,
                weatherLine: pick.chapter.theme?.name ?? "",
                dateLine: pick.chapter.monthName,
                style: PageVisualStyle.style(for: pick.selection.pageType),
                seed: abs(quote.stableHash) &+ index
            )
            if let url, let image = UIImage(contentsOfFile: url.path) {
                plates.append(.init(image: image, caption: pick.selection.reason.nonEmpty ?? pick.chapter.monthName))
            }
            await Task.yield()
        }
        return plates
    }

    /// keeps it durably so it reopens from the Book of You shelf later.
    @MainActor
    /// The charts for a bound edition: one endpaper of the reader's whole
    /// world, and a plate for each place something actually happened at inside
    /// this edition's own window.
    ///
    /// Composed before the binding starts, like the illuminated plates, so the
    /// snapshot fetches never land inside the PDF pass. Everything printed is
    /// loosened by `MapPlate`, because this goes through a backend and a print
    /// house on its way to a shelf.
    private func editionMapPlates(
        for edition: MonthlyEdition
    ) async -> (endpaper: RenderedMapPlate?, plates: [RenderedMapPlate]) {
        await editionMapPlates(
            from: edition.startDate,
            to: edition.endDate,
            kind: edition.publicationKind,
            readerName: edition.readerName
        )
    }

    /// The same charts for a bound volume. A season or a year is the span this
    /// was built for: the endpaper of a year is a life, where a week's is two
    /// pins.
    private func editionMapPlates(
        for annual: AnnualEdition,
        kind: PublicationEditionKind
    ) async -> (endpaper: RenderedMapPlate?, plates: [RenderedMapPlate]) {
        await editionMapPlates(
            from: annual.startDate,
            to: annual.endDate,
            kind: kind,
            readerName: annual.readerName
        )
    }

    private func editionMapPlates(
        from windowStart: Date,
        to windowEnd: Date,
        kind: PublicationEditionKind?,
        readerName: String
    ) async -> (endpaper: RenderedMapPlate?, plates: [RenderedMapPlate]) {
        let anchors = anchorLedger
        guard !anchors.isEmpty else { return (nil, []) }

        // A weekly gets where *this week* happened. The world endpaper belongs
        // to editions that arrive rarely enough for it to still be a surprise:
        // the same world map every seven days is wallpaper by the third issue.
        let isWeekly = kind == .weekly
        let charted = isWeekly
            ? MapPlate.placesActive(anchors: anchors, days: days, from: windowStart, to: windowEnd)
            : anchors
        guard !charted.isEmpty else { return (nil, []) }

        var endpaper: RenderedMapPlate?
        if let spec = MapPlate.endpaperSpec(anchors: charted),
           let image = await MapPlateImageRenderer.render(
               spec: spec, title: "", size: CGSize(width: 900, height: 640)
           ) {
            endpaper = RenderedMapPlate(
                image: image,
                title: isWeekly ? "Where The Week Happened" : "The Ground You Have Named",
                caption: isWeekly
                    ? (spec.marks.count == 1
                        ? "One place held this week."
                        : "\(spec.marks.count) places held this week.")
                    : MapPlate.endpaperCaption(
                        placeCount: spec.marks.count, readerName: readerName
                    )
            )
        }

        var plates: [RenderedMapPlate] = []
        let earned = MapPlate.signaturePlaces(
            anchors: anchors,
            days: days,
            from: windowStart,
            to: windowEnd,
            kind: kind
        )
        for place in earned {
            guard let spec = MapPlate.spec(for: place.anchor, destination: .print),
                  let image = await MapPlateImageRenderer.render(
                      spec: spec, title: place.anchor.name, size: CGSize(width: 900, height: 560)
                  ) else { continue }
            let kept = place.keptCount == 1 ? "one thing" : "\(place.keptCount) things"
            plates.append(RenderedMapPlate(
                image: image,
                title: place.anchor.name,
                caption: "\(place.anchor.name). You kept \(kept) here."
            ))
        }
        return (endpaper, plates)
    }

    private func bindMonthlyEditionPDF(
        _ edition: MonthlyEdition,
        plates: [MonthlyEditionPDFWriter.IlluminatedPlate] = [],
        endpaper: RenderedMapPlate? = nil,
        mapPlates: [RenderedMapPlate] = [],
        afterShopDismiss: Bool = false
    ) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: edition.startDate)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReEnchanted-Monthly-\(monthKey).pdf")
        try MonthlyEditionPDFWriter.write(
            edition, plates: plates, endpaper: endpaper, mapPlates: mapPlates, to: url
        )
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: edition.startDate))
            ?? edition.endDate.addingTimeInterval(1)
        let periodID = PublicationPeriodCatalog.period(
            recipe: .calendarMonth,
            startDate: edition.startDate,
            endDate: end,
            calendar: calendar
        ).id
        // Move the edition onto the Book of You shelf so it can be reopened after
        // launch, not just shared from this session's transient PDF.
        let keptURL = try keepMonthlyEdition(
            edition,
            monthKey: monthKey,
            renderedPDF: url,
            periodID: periodID
        )
        preparedMonthlyEditionURL = keptURL
        preparedMonthlyEditionPeriodID = periodID
        let reader = MonthlyEditionReader(
            edition: edition,
            pdfURL: keptURL,
            periodID: periodID
        )
        if afterShopDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                monthlyEditionReader = reader
            }
        } else {
            monthlyEditionReader = reader
        }
        monthlyBindingDedicationText = ""
        colophonBindingNote = "\(edition.monthName) is bound: \(edition.pageCount) \(edition.pageCount == 1 ? "page" : "pages") sewn between covers, and kept on the Book of You shelf."
        // The Monthly Binding gets its own ceremonial peak, not the shared braid cue.
        celebrateMonthlyBinding(monthName: edition.monthName, pageCount: edition.pageCount)
    }

    /// Moves a bound edition's PDF out of the temporary directory and records it
    /// as a real archive page. Re-binding a month replaces that month's artifact
    /// rather than adding a duplicate card to the Book of You shelf.
    @MainActor
    private func keepMonthlyEdition(
        _ edition: MonthlyEdition,
        monthKey: String,
        renderedPDF: URL,
        periodID: PublicationPeriodID? = nil
    ) throws -> URL {
        let directory = try monthlyEditionArchiveDirectory()
        let pdfURL = directory.appendingPathComponent("Monthly-Edition-\(monthKey).pdf")
        try replaceArchiveFile(at: pdfURL, with: renderedPDF)

        let artifact = KeptMonthlyEditionArtifact(
            edition: edition,
            monthKey: monthKey,
            pdfPath: pdfURL.path,
            keptAt: Date(),
            periodID: periodID
        )
        let tag = "monthly-edition:\(monthKey)"
        let body = ([edition.foreword] + edition.sections.prefix(3).map(\.title))
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
            .joined(separator: "\n\n")

        var archiveDay = today
        if let dayIndex = days.firstIndex(where: { day in day.pages.contains { $0.tags.contains(tag) } }),
           let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.tags.contains(tag) }) {
            archiveDay = days[dayIndex]
            var page = archiveDay.pages[pageIndex]
            page.promptText = artifact.monthLabel
            page.userInput = body
            page.sourceID = "monthly-edition"
            page.origin = .generated
            page.tags = ["monthly-edition", tag, "edition", "bindery"]
            page.monthlyEditionArtifact = artifact
            archiveDay.pages[pageIndex] = page
        } else {
            archiveDay.pages.append(BookPage(
                id: "monthly-edition-\(monthKey)",
                type: .bindery,
                promptText: artifact.monthLabel,
                userInput: body,
                tags: ["monthly-edition", tag, "edition", "bindery"],
                sourceID: "monthly-edition",
                origin: .generated,
                monthlyEditionArtifact: artifact
            ))
        }
        persist(day: archiveDay, message: "\(edition.monthName) is kept in the Book of You.")
        return pdfURL
    }

    /// Reopens an archived monthly edition. If iOS has cleared its rendered PDF,
    /// the stored edition is enough to press the file again without rebuilding
    /// the month.
    @MainActor
    func openKeptMonthlyEdition(_ page: BookPage) {
        guard let artifact = page.monthlyEditionArtifact else { return }
        if activeBookDivision != nil {
            activeBookDivision = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openKeptMonthlyEdition(page)
            }
            return
        }
        do {
            let storedPath = artifact.pdfPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let pdfURL: URL
            if !storedPath.isEmpty,
               FileManager.default.fileExists(atPath: storedPath) {
                pdfURL = URL(fileURLWithPath: storedPath)
            } else {
                let directory = try monthlyEditionArchiveDirectory()
                pdfURL = directory.appendingPathComponent("Monthly-Edition-\(artifact.monthKey).pdf")
            }
            if !FileManager.default.fileExists(atPath: pdfURL.path) {
                try FileManager.default.createDirectory(
                    at: pdfURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try MonthlyEditionPDFWriter.write(artifact.edition, to: pdfURL)
            }
            preparedMonthlyEditionURL = pdfURL
            preparedMonthlyEditionPeriodID = monthlyPublicationPeriodID(for: artifact)
            monthlyEditionReader = MonthlyEditionReader(
                edition: artifact.edition,
                pdfURL: pdfURL,
                periodID: monthlyPublicationPeriodID(for: artifact)
            )
            BookFeedback.play(.openPage)
        } catch {
            statusMessage = "\(artifact.edition.monthName) would not open: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    private func monthlyEditionArchiveDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = base
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("MonthlyEditions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Keeps the chaptered annual and its exact PDF together. Re-binding uses
    /// the same stable Page and replaces its file only after the new press pass
    /// succeeds, so an already-bound year never turns back into a loose draft.
    @MainActor
    private func keepAnnualEdition(
        _ edition: AnnualEdition,
        periodID: PublicationPeriodID,
        renderedPDF: URL
    ) throws -> URL {
        let directory = try annualEditionArchiveDirectory()
        let stamp = "\(edition.year)-\(periodID.startDayID)"
            .replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression)
        let pdfURL = directory.appendingPathComponent("Annual-Edition-\(stamp).pdf")
        try replaceArchiveFile(at: pdfURL, with: renderedPDF)

        let artifact = KeptAnnualEditionArtifact(
            edition: edition,
            periodID: periodID,
            pdfPath: pdfURL.path,
            keptAt: Date()
        )
        let tag = "annual-edition:\(periodID.rawValue)"
        let body = ([edition.foreword]
            + edition.chapters.map { $0.chapterHeading }
            + [edition.closing])
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
            .joined(separator: "\n\n")

        var archiveDay = today
        if let dayIndex = days.firstIndex(where: { day in day.pages.contains { $0.tags.contains(tag) } }),
           let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.tags.contains(tag) }) {
            archiveDay = days[dayIndex]
            var page = archiveDay.pages[pageIndex]
            page.promptText = edition.resolvedCoverLine()
            page.userInput = body
            page.sourceID = "annual-edition"
            page.origin = .generated
            page.tags = ["annual-edition", tag, "edition", "bindery"]
            page.annualEditionArtifact = artifact
            archiveDay.pages[pageIndex] = page
        } else {
            archiveDay.pages.append(BookPage(
                id: "annual-edition-\(stamp)",
                type: .bindery,
                promptText: edition.resolvedCoverLine(),
                userInput: body,
                tags: ["annual-edition", tag, "edition", "bindery"],
                sourceID: "annual-edition",
                origin: .generated,
                annualEditionArtifact: artifact
            ))
        }
        persist(day: archiveDay, message: "The \(edition.year) annual is kept in the Book of You.")
        return pdfURL
    }

    @MainActor
    func openKeptAnnualEdition(_ page: BookPage) {
        guard let artifact = page.annualEditionArtifact else { return }
        if activeBookDivision != nil {
            activeBookDivision = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openKeptAnnualEdition(page)
            }
            return
        }
        do {
            let storedPath = artifact.pdfPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let pdfURL: URL
            if !storedPath.isEmpty,
               FileManager.default.fileExists(atPath: storedPath) {
                pdfURL = URL(fileURLWithPath: storedPath)
            } else {
                let directory = try annualEditionArchiveDirectory()
                let stamp = "\(artifact.edition.year)-\(artifact.periodID.startDayID)"
                    .replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression)
                pdfURL = directory.appendingPathComponent("Annual-Edition-\(stamp).pdf")
            }
            if !FileManager.default.fileExists(atPath: pdfURL.path) {
                try FileManager.default.createDirectory(
                    at: pdfURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try MonthlyEditionPDFWriter.writeAnnual(artifact.edition, to: pdfURL)
            }
            preparedAnnualEditionURL = pdfURL
            preparedAnnualEditionPeriodID = artifact.periodID
            annualEditionReader = AnnualEditionReader(
                edition: artifact.edition,
                pdfURL: pdfURL,
                periodID: artifact.periodID
            )
            BookFeedback.play(.openPage)
        } catch {
            statusMessage = "The \(artifact.edition.year) annual would not open: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    private func annualEditionArchiveDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = base
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("AnnualEditions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    func openBoundWeeklyIssue(periodID: PublicationPeriodID) {
        guard let page = keptWeeklyIssuePage(for: periodID) else {
            statusMessage = "That issue is marked bound, but its shelf Page is missing."
            BookFeedback.play(.error)
            return
        }
        openKeptWeeklyIssue(page)
    }

    @MainActor
    func openBoundMonthlyEdition(periodID: PublicationPeriodID) {
        guard let page = keptMonthlyEditionPage(for: periodID) else {
            statusMessage = "That edition is marked bound, but its shelf Page is missing."
            BookFeedback.play(.error)
            return
        }
        openKeptMonthlyEdition(page)
    }

    @MainActor
    func openBoundAnnualEdition(periodID: PublicationPeriodID) {
        guard let page = keptAnnualEditionPage(for: periodID) else {
            statusMessage = "That annual is marked bound, but its shelf Page is missing."
            BookFeedback.play(.error)
            return
        }
        openKeptAnnualEdition(page)
    }

    @MainActor
    func rebindEditionReader(_ reader: MonthlyEditionReader) {
        guard let periodID = reader.periodID else { return }
        switch reader.edition.publicationKind ?? .monthly {
        case .seasonal:
            guard var edition = calendarSeasonalPrintEdition(periodID: periodID) else {
                statusMessage = "That season's leaves would not come back to the binding table."
                BookFeedback.play(.error)
                return
            }
            edition.dedication = reader.edition.dedication
            exportComposedEditionPDF(edition, periodID: periodID)
        case .monthly:
            exportMonthlyEdition(periodID: periodID, dedication: reader.edition.dedication)
        case .weekly, .annual, .special:
            break
        }
    }

    @MainActor
    private func currentBookCharacterPrompt(now: Date = Date()) -> String {
        let inputs = sourceInputs
        return BookCharacterPrompt.full(
            relationship: BookRelationshipLedger.snapshot(inputs: inputs, now: now),
            interior: inputs.bookInterior,
            patina: BookVoicePatina.derive(
                days: inputs.days,
                readerLearning: inputs.readerLearning,
                now: now
            )
        )
    }

    private func weeklyBindingSlot(for issue: WeeklyIssue) -> String {
        "weekly-\(issue.number)-\(publicationDateKey(issue.startDate))-\(publicationDateKey(issue.endDate))"
    }

    private func monthlyBindingSlot(for edition: MonthlyEdition) -> String {
        let kind = edition.publicationKind?.rawValue ?? "monthly"
        let recipe = edition.publicationRecipeID ?? "calendar"
        return "monthly-\(kind)-\(recipe)-\(publicationDateKey(edition.startDate))-\(publicationDateKey(edition.endDate))"
    }

    private func chapteredVolumeBindingSlot(for edition: AnnualEdition) -> String {
        let kind = edition.publicationKind?.rawValue ?? "annual"
        return "volume-\(kind)-\(edition.year)-\(publicationDateKey(edition.startDate))-\(publicationDateKey(edition.endDate))"
    }

    private func publicationPeriodID(for edition: MonthlyEdition) -> PublicationPeriodID? {
        let recipe: PublicationPeriodRecipe
        if let raw = edition.publicationRecipeID,
           let explicit = PublicationPeriodRecipe(rawValue: raw) {
            recipe = explicit
        } else {
            switch edition.publicationKind {
            case .seasonal: recipe = .calendarSeason
            case .annual: recipe = .calendarYear
            case .weekly: recipe = .readerWeek
            case .monthly, .none: recipe = .calendarMonth
            case .special: return nil
            }
        }
        let calendar = Calendar.current
        let finalDay = calendar.startOfDay(for: edition.endDate)
        let endExclusive: Date
        if recipe == .readerWeek {
            endExclusive = edition.endDate
        } else {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: finalDay) else {
                return nil
            }
            endExclusive = nextDay
        }
        return PublicationPeriodCatalog.period(
            recipe: recipe,
            startDate: edition.startDate,
            endDate: endExclusive,
            calendar: calendar
        ).id
    }

    private func weeklyBindingSourceFingerprint(for issue: WeeklyIssue) throws -> String {
        var source = issue
        source.bindingStory = nil
        source.editorialTitle = nil
        source.castConversation = nil
        source.looseThread = nil
        return try PublicationBindingCheckpointStore.fingerprint(of: source)
    }

    private func monthlyBindingSourceFingerprint(for edition: MonthlyEdition) throws -> String {
        var source = edition
        source.generatedAt = Date(timeIntervalSince1970: 0)
        source.bindingStory = nil
        source.castConversation = nil
        return try PublicationBindingCheckpointStore.fingerprint(of: source)
    }

    private func chapteredVolumeBindingSourceFingerprint(for edition: AnnualEdition) throws -> String {
        var source = edition
        source.generatedAt = Date(timeIntervalSince1970: 0)
        source.castConversation = nil
        source.chapters = source.chapters.map { chapter in
            var normalized = chapter
            normalized.generatedAt = Date(timeIntervalSince1970: 0)
            return normalized
        }
        return try PublicationBindingCheckpointStore.fingerprint(of: source)
    }

    private func publicationDateKey(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }

    private func clearPublicationBindingCheckpoint(slot: String) {
        do {
            try PublicationBindingCheckpointStore.remove(slot: slot)
        } catch {
            // The finished artifact is authoritative. A stale draft may remain,
            // but its source fingerprint prevents it crossing into another book.
            appLog.error("Could not clear finished publication checkpoint: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    private func gemmaWeeklyIssueBinding(for issue: WeeklyIssue) async throws -> WeeklyIssueBindingDraft {
        let slot = weeklyBindingSlot(for: issue)
        let sourceFingerprint = try weeklyBindingSourceFingerprint(for: issue)
        var checkpoint: PublicationBindingCheckpoint<WeeklyIssueBindingDraft>
        if let saved = try PublicationBindingCheckpointStore.load(
            WeeklyIssueBindingDraft.self,
            slot: slot,
            sourceFingerprint: sourceFingerprint
        ) {
            checkpoint = saved
        } else {
            checkpoint = PublicationBindingCheckpoint(
                sourceFingerprint: sourceFingerprint,
                payload: WeeklyIssueBindingDraft(
                    issue: issue,
                    editorialNote: nil,
                    closingNote: nil
                )
            )
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
        }

        let character = currentBookCharacterPrompt()

        let storyStage = WeeklyIssueBindingStage.bindingStory.rawValue
        if !checkpoint.hasCompleted(storyStage) {
            checkpoint.payload.issue.bindingStory = await gemmaWeeklyBindingStory(
                for: checkpoint.payload.issue,
                character: character
            )
            checkpoint.markCompleted(storyStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(storyStage)
        }

        weeklyIssueBindingNote = checkpoint.payload.issue.bindingStory == nil
            ? "The daily bindings are gathered. Gemma is naming the issue…"
            : "The week has become a story. Gemma is naming the issue…"
        let titleStage = WeeklyIssueBindingStage.editorialTitle.rawValue
        if !checkpoint.hasCompleted(titleStage) {
            checkpoint.payload.issue.editorialTitle = await gemmaWeeklyIssueTitle(
                for: checkpoint.payload.issue,
                character: character
            )
            checkpoint.markCompleted(titleStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(titleStage)
        }

        weeklyIssueBindingNote = "The cover has a name. Gemma is writing the editor's note…"
        let editorialStage = WeeklyIssueBindingStage.editorialNote.rawValue
        if !checkpoint.hasCompleted(editorialStage) {
            checkpoint.payload.editorialNote = await gemmaWeeklyIssueEditorialNote(
                for: checkpoint.payload.issue,
                character: character
            )
            checkpoint.markCompleted(editorialStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(editorialStage)
        }

        weeklyIssueBindingNote = "The editor's note is dry. Gemma is writing the last page…"
        let closingStage = WeeklyIssueBindingStage.closingNote.rawValue
        if !checkpoint.hasCompleted(closingStage) {
            checkpoint.payload.closingNote = await gemmaWeeklyIssueClosingNote(
                for: checkpoint.payload.issue,
                character: character
            )
            checkpoint.markCompleted(closingStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(closingStage)
        }

        weeklyIssueBindingNote = "The last page is dry. Gemma is leaving one thread loose…"
        let looseThreadStage = WeeklyIssueBindingStage.looseThread.rawValue
        if !checkpoint.hasCompleted(looseThreadStage) {
            let generated = await gemmaWeeklyIssueLooseThread(
                for: checkpoint.payload.issue,
                character: character
            )
            checkpoint.payload.issue.looseThread = generated
                ?? checkpoint.payload.issue.resolvedLooseThread
            checkpoint.markCompleted(looseThreadStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(looseThreadStage)
        }

        weeklyIssueBindingNote = "The last page is dry. The Cast has got hold of the proofs…"
        let castStage = WeeklyIssueBindingStage.castConversation.rawValue
        if !checkpoint.hasCompleted(castStage) {
            checkpoint.payload.issue.castConversation = await gemmaWeeklyIssueCastConversation(
                for: checkpoint.payload.issue
            )
            checkpoint.markCompleted(castStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(castStage)
        }

        weeklyIssueBindingNote = "The words are ready. Pressing the reading copy and share card…"
        return checkpoint.payload
    }

    @MainActor
    /// The week, decided before it is written, and checked after.
    ///
    /// This used to hand the model a prompt full of clipped night summaries and
    /// print whatever came back. There was no fact check, no polarity check and
    /// no provenance anywhere above the nightly braid - on the artifacts that
    /// actually get bound and sold.
    ///
    /// Now the plan decides, the model writes from the decision, the verifier
    /// drops any sentence the week's nights do not support, and the house issue
    /// stands underneath. Nothing is polished afterwards: the polisher works by
    /// deleting whole sentences, and every sentence here has been checked
    /// against a night.
    private func gemmaWeeklyBindingStory(for issue: WeeklyIssue, character: String) async -> String? {
        let plan = WeeklyBindingPlanner.plan(for: issue)
        guard !plan.nights.isEmpty else { return nil }
        let floor = WeeklyBindingWriter.issue(for: plan)

        guard let raw = await LocalBrainProse.write(
            prompt: "\(character)\n\n\(plan.brief())",
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 900,
            sourceID: "weekly-binding-story",
            tags: ["edition", "weekly-issue", "binding-story", "gemma"]
        ) else { return floor }

        switch WeeklyBindingVerifier.salvage(raw, against: plan) {
        case .success(let salvage):
            appLog.info(
                "Weekly binding accepted: \(salvage.verified.claims.count, privacy: .public) claims, \(salvage.dropped.count, privacy: .public) sentences dropped"
            )
            return salvage.verified.text.nonEmpty ?? floor
        case .failure(let refusal):
            appLog.info("Weekly binding refused: \(refusal.rawValue, privacy: .public)")
            return floor
        }
    }

    @MainActor
    private func gemmaWeeklyIssueTitle(for issue: WeeklyIssue, character: String) async -> String? {
        let evidence = (issue.revelations.prefix(2).map { "\($0.title): \($0.body)" }
            + issue.highlights.prefix(3))
            .joined(separator: "\n")
        let prompt = """
        Name this exact issue of The Book of You.
        \(character)

        The week's bound story:
        \(issue.bindingStory.map { String($0.prefix(1_300)) } ?? "No larger binding cleared the press.")

        Evidence:
        \(evidence)

        Write one literary magazine cover title of 2 to 8 words. It should feel inevitable only after the issue is read: concrete, specific, surprising, and grounded in the supplied week. Don't use the reader's name, a date, “week,” “issue,” “journey,” “chapter,” or generic praise. Don't invent anything. Output the title only.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 48,
            sourceID: "weekly-issue-title",
            tags: ["edition", "weekly-issue", "cover-title", "gemma"],
            temperature: 0.70,
            topP: 0.88
        ) else { return nil }
        let title = raw
            .components(separatedBy: .newlines)
            .first?
            .replacingOccurrences(of: "TITLE:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\"“”'*_#.!?"))
        guard let title = title?.nonEmpty,
              title.count <= 72,
              (2...8).contains(title.split(whereSeparator: \.isWhitespace).count) else { return nil }
        return title
    }

    @MainActor
    private func gemmaWeeklyIssueLooseThread(for issue: WeeklyIssue, character: String) async -> WeeklyLooseThread? {
        guard let seed = issue.resolvedLooseThread, !seed.evidence.isEmpty else { return nil }
        let receipts = seed.evidence.prefix(2).map { "- \($0.excerpt)" }.joined(separator: "\n")
        let prompt = """
        Write the final loose thread for “\(issue.resolvedEditorialTitle),” a private literary magazine of one real week.
        \(character)

        Receipts from the reader's own pages:
        \(receipts)

        Write 2 or 3 short sentences in the Book's voice. Point at what remains alive, unresolved, or worth watching. You may wonder, but you may not predict, diagnose, assign a hidden motive, or claim a feeling the receipts don't state. Be concrete. Admit what you don't know. Leave the thread open rather than giving advice or a moral. Don't quote more than one short phrase.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 150,
            sourceID: "weekly-issue-loose-thread",
            tags: ["edition", "weekly-issue", "loose-thread", "gemma"],
            temperature: 0.68,
            topP: 0.88
        ) else { return nil }
        let body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return WeeklyLooseThread(title: seed.title, body: body, evidence: seed.evidence)
    }

    @MainActor
    private func gemmaWeeklyIssueEditorialNote(for issue: WeeklyIssue, character: String) async -> String? {
        let highlights = issue.highlights.isEmpty
            ? "- No highlight lines were available."
            : issue.highlights.map { "- \($0)" }.joined(separator: "\n")
        let findings = issue.revelations.prefix(2).map { "- \($0.title): \($0.body)" }.joined(separator: "\n")
        let tale = WeeklyIssue.taleLine(for: issue) ?? "No tale finished inside this issue."
        let prompt = """
        Write the editor's note for Issue No. \(issue.number) of The Book of You Weekly Issue, in the Book's own voice, addressed to the reader. It covers \(issue.dateRange) and gathers \(issue.keptCount) kept pages.
        \(character)
        Highlights:
        \(highlights)
        What the Book could support with receipts:
        \(findings.isEmpty ? "- no finding cleared the evidence threshold" : findings)
        Tale desk: \(tale)
        Set-aside note: \(issue.setAsideLine ?? "none")
        Write 1 or 2 short paragraphs as an actual magazine editor opening this exact issue. Point to one concrete thing inside, and give the reader a reason to turn the page. Make the week feel whole without pretending it was grand. Do not repeat the binding story and do not invent events.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 260,
            sourceID: "weekly-issue-editorial",
            tags: ["edition", "weekly-issue", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    @MainActor
    private func gemmaWeeklyIssueClosingNote(for issue: WeeklyIssue, character: String) async -> String? {
        let highlights = issue.highlights.isEmpty
            ? "- No highlight lines were available."
            : issue.highlights.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        Write the closing note for Issue No. \(issue.number) of The Book of You Weekly Issue, in the Book's own voice, addressed to the reader. It covers \(issue.dateRange) and gathers \(issue.keptCount) kept pages.
        \(character)
        Highlights:
        \(highlights)
        Set-aside note: \(issue.setAsideLine ?? "none")
        Write one short paragraph, 1 to 3 sentences. Let the week feel kept; mention that the month and year are still gathering only if it feels natural. Do not invent events.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 160,
            sourceID: "weekly-issue-closing",
            tags: ["edition", "weekly-issue", "closing", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    @MainActor
    private func gemmaWeeklyIssueCastConversation(for issue: WeeklyIssue) async -> BoundVolumeCastConversation? {
        var speakers: [KeepMarginalia.Voice] = []
        var seen = Set<String>()
        for note in issue.marginalia ?? [] {
            guard let slug = note.speakerSlug,
                  seen.insert(slug).inserted,
                  let voice = KeepMarginalia.voice(forSlug: slug) else { continue }
            speakers.append(voice)
        }
        for fallbackID in ["penny-blackletter", "professor-thaddeus-mook", "pippa-pilcrow"] where speakers.count < 3 {
            guard seen.insert(fallbackID).inserted,
                  let voice = KeepMarginalia.voice(forSlug: fallbackID) else { continue }
            speakers.append(voice)
        }
        speakers = Array(speakers.prefix(3))
        guard speakers.count >= 2 else { return nil }

        var evidence: [(id: String, line: String)] = issue.highlights.enumerated().map {
            ("highlight-\($0.offset)", "Highlight: \($0.element)")
        }
        evidence += issue.revelations.prefix(2).map {
            ("revelation-\($0.id)", "\($0.title): \($0.body)")
        }
        if let tale = WeeklyIssue.taleLine(for: issue) {
            evidence.append(("finished-tale", tale))
        }
        evidence += (issue.passageCompass ?? []).prefix(3).map {
            ("passage-\($0.pageID)", "\($0.pageType.shortTitle): \($0.excerpt)")
        }
        guard evidence.count >= 2 else { return nil }

        let speakerLines = speakers.map { voice in
            "- \(voice.slug) | \(voice.name) | glyph \(voice.glyph) | voice examples: \(voice.plainLines.prefix(3).joined(separator: " / "))"
        }.joined(separator: "\n")
        let prompt = """
        Write a tiny letters-page argument among the Cast about Issue No. \(issue.number) of The Book of You. They have the saddle-stitched proof open on a table and are reacting to what is physically printed inside it, not speaking to the reader as assistants.

        Allowed speakers:
        \(speakerLines)

        Evidence printed in this exact issue:
        \(evidence.prefix(10).map { "[\($0.id)] \($0.line)" }.joined(separator: "\n"))

        Rules:
        - Use only supplied evidence for facts about the reader. Never invent an event, feeling, place, meal, or habit.
        - Refer to at least two exact details and let the speakers disagree, tease, or surprise each other.
        - Do not summarize the reader, explain an app, or praise generically.
        - Write 4 to 7 brief lines, with at least two speakers.
        - Output only lines in this exact format: speaker-id|words
        """
        let instructions = """
        Write canon-faithful dialogue among residents of ReEnchanted's Labyrinth. Keep each speaker distinct from the supplied examples. The Book and the printed issue are allowed to behave like creatures. Child-like anthropomorphism, but not childish. No assistant voice, therapy language, praise-summary, or generic whimsy.
        \(BookVoice.animismLine)
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 480,
            sourceID: "weekly-issue-cast-desk",
            tags: ["edition", "weekly-issue", "cast", "gemma"],
            temperature: 0.74,
            topP: 0.90
        ) else { return nil }

        let speakerByID = Dictionary(uniqueKeysWithValues: speakers.map { ($0.slug, $0) })
        var lines: [BoundVolumeCastLine] = []
        for rawLine in raw.components(separatedBy: .newlines) {
            let parts = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let voice = speakerByID[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)],
                  let words = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \t\"“”")).nonEmpty else { continue }
            lines.append(.init(
                id: "weekly-dialogue-\(lines.count)-\(voice.slug)",
                speakerID: voice.slug,
                speakerName: voice.name,
                glyph: voice.glyph,
                words: words
            ))
            if lines.count == 7 { break }
        }
        guard lines.count >= 4, Set(lines.map(\.speakerID)).count >= 2 else { return nil }
        return BoundVolumeCastConversation(
            title: "At the Issue Desk",
            setting: "The proof came off the little press and immediately attracted opinions.",
            lines: lines,
            evidenceIDs: evidence.prefix(10).map(\.id)
        )
    }

    @MainActor
    private func gemmaMonthlyBinding(for edition: MonthlyEdition) async throws -> MonthlyEdition {
        let slot = monthlyBindingSlot(for: edition)
        let sourceFingerprint = try monthlyBindingSourceFingerprint(for: edition)
        var checkpoint: PublicationBindingCheckpoint<MonthlyEdition>
        if let saved = try PublicationBindingCheckpointStore.load(
            MonthlyEdition.self,
            slot: slot,
            sourceFingerprint: sourceFingerprint
        ) {
            checkpoint = saved
        } else {
            checkpoint = PublicationBindingCheckpoint(
                sourceFingerprint: sourceFingerprint,
                payload: edition
            )
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
        }

        let character = currentBookCharacterPrompt()
        // Local generation is single-file. Running the wrappers concurrently
        // makes all but the winner quietly return as busy, which is how a
        // premium month can reach the press with only one of its authored
        // leaves. Write them in reading order and let each finish.
        let forewordStage = MonthlyEditionBindingStage.foreword.rawValue
        if !checkpoint.hasCompleted(forewordStage) {
            if let gemma = await gemmaMonthlyForeword(for: edition, character: character) {
                checkpoint.payload.foreword = gemma
            }
            checkpoint.markCompleted(forewordStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(forewordStage)
        }

        colophonBindingNote = "The foreword is dry. Gemma is rereading the month's nightly bindings…"
        let storyStage = MonthlyEditionBindingStage.bindingStory.rawValue
        if !checkpoint.hasCompleted(storyStage) {
            if let story = await gemmaMonthlyBindingStory(for: edition, character: character) {
                checkpoint.payload.bindingStory = story
                // `renderInterior` gives this prose its own authored movement.
                // Keeping a second copy in `sections` printed the same story twice.
                checkpoint.payload.sections.removeAll { $0.id == "monthly-binding-story" }
            }
            checkpoint.markCompleted(storyStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(storyStage)
        }

        colophonBindingNote = "The month's larger story is dry. Gemma is writing the last leaf…"
        let closingStage = MonthlyEditionBindingStage.closing.rawValue
        if !checkpoint.hasCompleted(closingStage) {
            if let gemma = await gemmaMonthlyClosing(for: edition, character: character) {
                checkpoint.payload.closing = gemma
            }
            checkpoint.markCompleted(closingStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(closingStage)
        }

        colophonBindingNote = "The last leaf is dry. The Cast has got hold of the month…"
        let castStage = MonthlyEditionBindingStage.castConversation.rawValue
        if !checkpoint.hasCompleted(castStage) {
            if let conversation = await gemmaMonthlyCastConversation(for: checkpoint.payload) {
                checkpoint.payload.castConversation = conversation
            }
            checkpoint.markCompleted(castStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(castStage)
        }

        colophonBindingNote = "The month's words are stored. Setting the pages and plates…"
        return checkpoint.payload
    }

    @MainActor
    private func gemmaMonthlyBindingStory(for edition: MonthlyEdition, character: String) async -> String? {
        guard let spec = BindingStoryPromptBuilder.monthly(for: edition) else { return nil }
        guard let raw = await LocalBrainProse.write(
            prompt: "\(character)\n\n\(spec.prompt)",
            instructions: BraidInstructions.bookOfYou,
            maxTokens: spec.maxTokens,
            sourceID: spec.sourceID,
            tags: ["edition", "monthly", "binding-story", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func monthlyBindingPromptMaterial(for edition: MonthlyEdition) -> (themeLine: String, signals: String, named: String, memorySpine: String, passageCompass: String) {
        let themeLine = edition.theme.map { "The month's theme was \u{201C}\($0.name)\u{201D}: \($0.line)" } ?? "No settled monthly theme was named."
        let signals = edition.continuity.strongestSignals.prefix(4).map(\.line).joined(separator: " ")
        let named = (edition.constellations.filter(\.isNamed).prefix(3).map(\.displayName)).joined(separator: ", ")
        let memorySpine = edition.memorySpinePromptLines.isEmpty
            ? "No nightly braid residue was available."
            : edition.memorySpinePromptLines.map { "- \($0)" }.joined(separator: "\n")
        let passageCompass = (edition.passageCompass ?? []).isEmpty
            ? "No reader-authored passage cleared the relevance threshold."
            : (edition.passageCompass ?? []).prefix(6).map { "- \($0.pageType.shortTitle): “\($0.excerpt)”" }.joined(separator: "\n")
        return (themeLine, signals, named.isEmpty ? "none yet" : named, memorySpine, passageCompass)
    }

    /// The on-device brain writes the monthly foreword. The deterministic
    /// foreword already on the edition is kept only when Gemma is unavailable.
    @MainActor
    private func gemmaMonthlyForeword(for edition: MonthlyEdition, character: String) async -> String? {
        let material = monthlyBindingPromptMaterial(for: edition)
        let prompt = """
        Write the foreword to \(edition.monthName) for The Book of You, in the Book's own voice, addressed to the reader. It is opening a bound monthly chapter with \(edition.pageCount) pages across \(edition.dayCount) days.
        \(character)
        Theme: \(material.themeLine)
        What kept returning this month: \(material.signals)
        Named threads: \(material.named)
        Book Memory Spine from nightly braids:
        \(material.memorySpine)
        Selected reader-authored passages from meaningful parts of eligible keeps:
        \(material.passageCompass)
        Write 2 to 4 short paragraphs. Be specific to the supplied material. Do not invent events. Do not sign the note; the reader knows who's speaking.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 420,
            sourceID: "monthly-foreword",
            tags: ["edition", "foreword", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// The on-device brain re-reads the month and composes a closing in the
    /// Book's voice. Returns nil if the local brain is unavailable or quiet, in
    /// which case the deterministic closing already on the edition is kept.
    @MainActor
    private func gemmaMonthlyClosing(for edition: MonthlyEdition, character: String) async -> String? {
        let material = monthlyBindingPromptMaterial(for: edition)
        let prompt = """
        Write the closing paragraph of \(edition.monthName) for The Book of You, in the Book's own voice: warm, literary, second-person, addressed to the reader. It bound \(edition.pageCount) pages across \(edition.dayCount) days.
        \(character)
        Theme: \(material.themeLine)
        What kept returning this month: \(material.signals)
        Named threads still alight: \(material.named)
        Book Memory Spine from nightly braids:
        \(material.memorySpine)
        Selected reader-authored passages from meaningful parts of eligible keeps:
        \(material.passageCompass)
        Two or three short paragraphs. Do not sign the note. Do not invent events; only reflect what is given.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 360,
            sourceID: "monthly-closing",
            tags: ["edition", "closing", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Lets the Cast read the object, not merely decorate it. The model sees a
    /// bounded evidence packet from the finished month and must emit named
    /// speaker lines; malformed or generic output simply leaves the leaf out.
    @MainActor
    private func gemmaMonthlyCastConversation(for edition: MonthlyEdition) async -> BoundVolumeCastConversation? {
        var speakers: [KeepMarginalia.Voice] = []
        var seen = Set<String>()
        for note in edition.marginalia ?? [] {
            guard let slug = note.speakerSlug,
                  seen.insert(slug).inserted,
                  let voice = KeepMarginalia.voice(forSlug: slug) else { continue }
            speakers.append(voice)
        }
        for fallbackID in ["penny-blackletter", "professor-thaddeus-mook", "pippa-pilcrow"] where speakers.count < 3 {
            guard seen.insert(fallbackID).inserted,
                  let voice = KeepMarginalia.voice(forSlug: fallbackID) else { continue }
            speakers.append(voice)
        }
        speakers = Array(speakers.prefix(3))
        guard speakers.count >= 2 else { return nil }

        let almanac = (edition.publicationMatter?.almanacItems ?? []).prefix(6).map {
            (id: $0.sourceID ?? $0.id, line: "\($0.title): \($0.body)")
        }
        let crossings = (edition.publicationMatter?.crossingItems ?? []).prefix(5).map {
            (id: $0.sourceID ?? $0.id, line: "\($0.title): \($0.body)")
        }
        let passages = (edition.passageCompass ?? []).prefix(5).map {
            (id: "passage:\($0.pageID)", line: "\($0.pageType.shortTitle): \($0.excerpt)")
        }
        let evidence = Array(almanac) + Array(crossings) + Array(passages)
        guard !evidence.isEmpty else { return nil }

        let speakerLines = speakers.map { voice in
            "- \(voice.slug) | \(voice.name) | glyph \(voice.glyph) | voice examples: \(voice.plainLines.prefix(3).joined(separator: " / "))"
        }.joined(separator: "\n")
        let prompt = """
        Write a short in-world conversation at the Bindery about the exact physical monthly book titled \(edition.monthName). The characters have the finished volume open in front of them. They may argue about the edit, notice a funny juxtaposition, care about an ordinary detail, or object to what another character thinks it means. They are people with agendas, not tour guides.

        Allowed speakers:
        \(speakerLines)

        Evidence printed inside this exact month:
        \(evidence.prefix(14).map { "[\($0.id)] \($0.line)" }.joined(separator: "\n"))

        Rules:
        - Use only supplied evidence for facts about the reader. Never invent an event, meal, feeling, place, or habit.
        - Refer to at least two exact supplied details.
        - Let the speakers disagree or surprise each other. Do not summarize the reader or explain an app.
        - Write 5 to 8 brief lines, with at least two speakers.
        - Output only lines in this exact format: speaker-id|words
        """
        let instructions = """
        Write canon-faithful dialogue among residents of ReEnchanted's Labyrinth. Keep each speaker distinct using the supplied examples. The scene is a contemporary domestic faerie tale made from exact ordinary evidence. No assistant voice, therapy language, praise-summary, or generic whimsy.
        \(BookVoice.animismLine)
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 560,
            sourceID: "monthly-binding-table-conversation",
            tags: ["edition", "monthly", "cast", "gemma"],
            temperature: 0.72,
            topP: 0.90
        ) else { return nil }

        let speakerByID = Dictionary(uniqueKeysWithValues: speakers.map { ($0.slug, $0) })
        var lines: [BoundVolumeCastLine] = []
        for rawLine in raw.components(separatedBy: .newlines) {
            let parts = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let voice = speakerByID[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)],
                  let words = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \t\"“”")).nonEmpty else { continue }
            lines.append(.init(
                id: "monthly-dialogue-\(lines.count)-\(voice.slug)",
                speakerID: voice.slug,
                speakerName: voice.name,
                glyph: voice.glyph,
                words: words
            ))
            if lines.count == 8 { break }
        }
        guard lines.count >= 4, Set(lines.map(\.speakerID)).count >= 2 else { return nil }
        return BoundVolumeCastConversation(
            title: "The Cast Gets Hold of the Month",
            setting: "At the binding table, while the cover boards were still warm.",
            lines: lines,
            evidenceIDs: evidence.prefix(14).map(\.id)
        )
    }

    @MainActor
    private func gemmaAnnualBinding(for annual: AnnualEdition) async throws -> AnnualEdition {
        let slot = chapteredVolumeBindingSlot(for: annual)
        let sourceFingerprint = try chapteredVolumeBindingSourceFingerprint(for: annual)
        var checkpoint: PublicationBindingCheckpoint<AnnualEdition>
        if let saved = try PublicationBindingCheckpointStore.load(
            AnnualEdition.self,
            slot: slot,
            sourceFingerprint: sourceFingerprint
        ) {
            checkpoint = saved
        } else {
            checkpoint = PublicationBindingCheckpoint(
                sourceFingerprint: sourceFingerprint,
                payload: annual
            )
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
        }

        let character = currentBookCharacterPrompt()
        // The local-brain gate is single-flight. These used to be `async let`s,
        // which let one pass win while the other two quietly fell back as busy.
        let forewordStage = ChapteredVolumeBindingStage.foreword.rawValue
        if !checkpoint.hasCompleted(forewordStage) {
            if let gemma = await gemmaAnnualForeword(for: annual, character: character) {
                checkpoint.payload.foreword = gemma
            }
            checkpoint.markCompleted(forewordStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(forewordStage)
        }

        let closingStage = ChapteredVolumeBindingStage.closing.rawValue
        if !checkpoint.hasCompleted(closingStage) {
            if let gemma = await gemmaAnnualClosing(for: annual, character: character) {
                checkpoint.payload.closing = gemma
            }
            checkpoint.markCompleted(closingStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(closingStage)
        }

        let castStage = ChapteredVolumeBindingStage.castConversation.rawValue
        if !checkpoint.hasCompleted(castStage) {
            if let gemma = await gemmaVolumeCastConversation(for: checkpoint.payload) {
                checkpoint.payload.castConversation = gemma
            }
            checkpoint.markCompleted(castStage)
            try PublicationBindingCheckpointStore.save(checkpoint, slot: slot)
            await LocalBrainPublicationStageBoundary.persisted(castStage)
        }

        return checkpoint.payload
    }

    private func annualBindingPromptMaterial(for annual: AnnualEdition) -> String {
        let chapters = annual.chapters.map { chapter in
            let theme = chapter.theme.map { ": \($0.name): \($0.line)" } ?? ""
            return "- \(chapter.monthName): \(chapter.pageCount) pages\(theme)"
        }.joined(separator: "\n")
        let signals = annual.continuity.strongestSignals.prefix(6).map { "- \($0.line)" }.joined(separator: "\n")
        let named = annual.namedConstellations.prefix(6).map { "- \($0.displayName): \($0.latestLine)" }.joined(separator: "\n")
        let almanac = annual.publicationMatter?.almanacItems.prefix(8).map {
            "- [\($0.id)] \($0.title): \($0.body)"
        }.joined(separator: "\n") ?? ""
        let crossings = annual.publicationMatter?.crossingItems.prefix(8).map {
            "- [\($0.sourceID ?? $0.id)] \($0.title): \($0.body)"
        }.joined(separator: "\n") ?? ""
        let spine: String
        if let memorySpine = annual.memorySpine, !memorySpine.isEmpty {
            let motifs = memorySpine.motifs.prefix(8).map { "- \($0)" }.joined(separator: "\n")
            let callbacks = memorySpine.callbacks.prefix(6).map { "- \($0)" }.joined(separator: "\n")
            let questions = memorySpine.openQuestions.prefix(4).map { "- \($0)" }.joined(separator: "\n")
            spine = """
            Motifs:
            \(motifs.isEmpty ? "- none" : motifs)
            Callbacks:
            \(callbacks.isEmpty ? "- none" : callbacks)
            Open questions:
            \(questions.isEmpty ? "- none" : questions)
            """
        } else {
            spine = "No annual memory spine was available."
        }
        return """
        Chapters:
        \(chapters)
        Strongest year signals:
        \(signals.isEmpty ? "- none" : signals)
        Named constellations:
        \(named.isEmpty ? "- none" : named)
        Lived almanac:
        \(almanac.isEmpty ? "- none" : almanac)
        Real choices that crossed into the Labyrinth:
        \(crossings.isEmpty ? "- none" : crossings)
        Annual Book Memory Spine:
        \(spine)
        """
    }

    @MainActor
    private func gemmaAnnualForeword(for annual: AnnualEdition, character: String) async -> String? {
        let bindingEvidence = BindingStoryPromptBuilder.annual(for: annual)?.prompt
            ?? annualBindingPromptMaterial(for: annual)
        let kind = annual.publicationKind == .seasonal ? "seasonal volume" : "membership-year annual"
        let prompt = """
        Write the foreword to \(annual.resolvedCoverLine()) of The Book of You, in the Book's own voice, addressed to the reader. It is opening a bound \(kind) with \(annual.pageCount) kept pages across \(annual.dayCount) days and \(annual.chapters.count) chapters.
        \(character)
        \(bindingEvidence)
        Write 3 to 5 short paragraphs. Choose the truest architecture the supplied year earned: chronicle, mosaic, portrait, narrative drama, vigil, comedy, or return. Do not force the year into one arc, and do not invent events beyond the supplied material. Do not sign the note.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 560,
            sourceID: "annual-foreword",
            tags: ["edition", "annual", "foreword", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    @MainActor
    private func gemmaAnnualClosing(for annual: AnnualEdition, character: String) async -> String? {
        let kind = annual.publicationKind == .seasonal ? "season" : "membership year"
        let prompt = """
        Write the closing back-matter note for \(annual.resolvedCoverLine()) of The Book of You, in the Book's own voice, addressed to the reader after they have reached the end of this \(kind).
        \(character)
        \(annualBindingPromptMaterial(for: annual))
        Write 2 or 3 short paragraphs. Let it feel final but not grandiose: this \(kind) is kept, the next page is blank on purpose. Do not claim the calendar year ended unless this is explicitly an annual. Do not invent events. Do not sign the note.
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 420,
            sourceID: "annual-closing",
            tags: ["edition", "annual", "closing", "gemma"]
        ) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    @MainActor
    private func gemmaVolumeCastConversation(for annual: AnnualEdition) async -> BoundVolumeCastConversation? {
        var speakers: [KeepMarginalia.Voice] = []
        var seen = Set<String>()
        for note in annual.chapters.flatMap({ $0.marginalia ?? [] }) {
            guard let slug = note.speakerSlug,
                  seen.insert(slug).inserted,
                  let voice = KeepMarginalia.voice(forSlug: slug) else { continue }
            speakers.append(voice)
        }
        for fallbackID in ["penny-blackletter", "professor-thaddeus-mook", "pippa-pilcrow"] where speakers.count < 3 {
            guard seen.insert(fallbackID).inserted,
                  let voice = KeepMarginalia.voice(forSlug: fallbackID) else { continue }
            speakers.append(voice)
        }
        speakers = Array(speakers.prefix(3))
        guard speakers.count >= 2 else { return nil }

        let evidenceItems = Array((annual.publicationMatter?.almanacItems ?? []).prefix(6))
            + Array((annual.publicationMatter?.crossingItems ?? []).prefix(6))
        let passageItems = annual.chapters.flatMap { chapter in
            (chapter.passageCompass ?? []).prefix(2).map { selection in
                "[passage:\(selection.pageID)] \(chapter.monthName): \(selection.excerpt)"
            }
        }
        let evidenceLines = evidenceItems.map { item in
            "[\(item.sourceID ?? item.id)] \(item.title): \(item.body)"
        } + passageItems
        guard !evidenceLines.isEmpty else { return nil }

        let speakerLines = speakers.map { voice in
            let examples = voice.plainLines.prefix(3).joined(separator: " / ")
            return "- \(voice.slug) | \(voice.name) | glyph \(voice.glyph) | voice examples: \(examples)"
        }.joined(separator: "\n")
        let prompt = """
        Write a short in-world conversation at the Bindery about the exact physical book titled \(annual.resolvedCoverLine()). The characters have the finished volume open in front of them. They may disagree about its editing, notice a funny or tender juxtaposition, argue over a title, or react to a real detail. They are people with agendas, not tour guides.

        Allowed speakers:
        \(speakerLines)

        Evidence inside this exact volume:
        \(evidenceLines.prefix(16).joined(separator: "\n"))

        Rules:
        - Use only the supplied evidence for facts about the reader. Never invent an event, meal, feeling, place, or habit.
        - The Cast may form opinions, tease each other, misunderstand each other, and care about the object.
        - Refer to at least two exact supplied details. Do not summarize the reader or explain the app.
        - Write 5 to 8 brief lines, with at least two speakers.
        - Output only lines in this exact format: speaker-id|words
        """
        let instructions = """
        You are writing canon-faithful dialogue among residents of ReEnchanted's Labyrinth. Keep each speaker distinct using the supplied voice examples. The scene is a contemporary domestic faerie tale with exact ordinary evidence. Generated dialogue may interpret evidence but may never manufacture real-life facts. No assistant voice, therapy language, praise-summary, or generic whimsy.
        \(BookVoice.animismLine)
        """
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 620,
            sourceID: "bound-volume-cast-conversation",
            tags: ["edition", "bound-volume", "cast", "gemma"],
            temperature: 0.72,
            topP: 0.90
        ) else {
            return fallbackVolumeCastConversation(annual: annual, speakers: speakers, evidence: evidenceItems)
        }

        let speakerByID = Dictionary(uniqueKeysWithValues: speakers.map { ($0.slug, $0) })
        var lines: [BoundVolumeCastLine] = []
        for rawLine in raw.components(separatedBy: .newlines) {
            let cleaned = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = cleaned.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let voice = speakerByID[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)] else { continue }
            let words = parts[1]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\"“”"))
                .nonEmpty
            guard let words else { continue }
            lines.append(BoundVolumeCastLine(
                id: "volume-dialogue-\(lines.count)-\(voice.slug)",
                speakerID: voice.slug,
                speakerName: voice.name,
                glyph: voice.glyph,
                words: words
            ))
            if lines.count == 8 { break }
        }
        guard lines.count >= 4, Set(lines.map(\.speakerID)).count >= 2 else {
            return fallbackVolumeCastConversation(annual: annual, speakers: speakers, evidence: evidenceItems)
        }
        return BoundVolumeCastConversation(
            title: "An Argument at the Binding Table",
            setting: "After the cover came down, before the glue stopped muttering.",
            lines: lines,
            evidenceIDs: evidenceItems.map { $0.sourceID ?? $0.id }
        )
    }

    private func fallbackVolumeCastConversation(
        annual: AnnualEdition,
        speakers: [KeepMarginalia.Voice],
        evidence: [MonthlyEditionItem]
    ) -> BoundVolumeCastConversation? {
        guard speakers.count >= 2, let firstEvidence = evidence.first else { return nil }
        let secondEvidence = evidence.dropFirst().first ?? firstEvidence
        let penny = speakers.first(where: { $0.slug == "penny-blackletter" }) ?? speakers[0]
        let mook = speakers.first(where: { $0.slug == "professor-thaddeus-mook" }) ?? speakers[1]
        let firstDetail = String(firstEvidence.body.prefix(150))
        let secondDetail = String(secondEvidence.body.prefix(150))
        let lines = [
            BoundVolumeCastLine(id: "volume-dialogue-fallback-0", speakerID: penny.slug, speakerName: penny.name, glyph: penny.glyph, words: "I've put \(firstEvidence.title.lowercased()) on its own card. \(firstDetail)"),
            BoundVolumeCastLine(id: "volume-dialogue-fallback-1", speakerID: mook.slug, speakerName: mook.name, glyph: mook.glyph, words: "A card is not an argument, Blackletter. It is barely furniture."),
            BoundVolumeCastLine(id: "volume-dialogue-fallback-2", speakerID: penny.slug, speakerName: penny.name, glyph: penny.glyph, words: "Then explain \(secondEvidence.title.lowercased()). \(secondDetail) That is a hinge, and you know it."),
            BoundVolumeCastLine(id: "volume-dialogue-fallback-3", speakerID: mook.slug, speakerName: mook.name, glyph: mook.glyph, words: "I know only that \(annual.resolvedCoverLine()) has survived binding with its evidence intact. Irritatingly, that will do.")
        ]
        return BoundVolumeCastConversation(
            title: "An Argument at the Binding Table",
            setting: "After the cover came down, before the glue stopped muttering.",
            lines: lines,
            evidenceIDs: evidence.prefix(2).map { $0.sourceID ?? $0.id }
        )
    }

    @MainActor
    func exportAnnualEdition(
        periodID: PublicationPeriodID? = nil,
        dedication: BoundDedication? = nil
    ) {
        do {
            let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 20000)) ?? narrativeEvents
            let archiveMemories = (try? BookDatabase.entityMemories(limit: 20000)) ?? entityMemories
            let calendar = Calendar.current
            let bindable = annualPublicationCandidates.filter(\.isBindable)
            let candidate: PublicationCandidate?
            if let periodID {
                candidate = bindable.first { $0.id == periodID }
            } else {
                candidate = bindable.first
            }
            guard let candidate else {
                statusMessage = "No completed year has kept pages to bind yet. This one is still gathering."
                BookFeedback.play(.error)
                return
            }
            let targetYear = calendar.component(.year, from: candidate.period.startDate)
            var annual = MonthlyEditionBuilder.annual(
                targetYear,
                from: days,
                events: archiveEvents,
                entityMemories: archiveMemories,
                entityBelief: entityBeliefLedger,
                pageBelief: pageBeliefLedger,
                constellations: vault.data.constellations ?? [],
                wagers: vault.data.wagers ?? [],
                themes: vault.data.themes ?? [],
                storyConsequences: vault.data.storyConsequenceLedger?.receipts ?? [],
                facultyEntries: facultyEntries,
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                readerRole: boundReaderRole,
                castActs: (vault.data.castActs ?? .empty).records,
                includePrivateLifeAlmanac: includePrivateWeatherInMonthlyBinding,
                academySeason: academySeasonInputs,
                boundTales: vault.data.boundTales ?? [],
                now: Date()
            )
            annual.dedication = dedication
            guard !annual.isEmpty else {
                statusMessage = "There are no kept pages yet to bind into an annual."
                BookFeedback.play(.error)
                return
            }
            let wasShopOpen = isBookShopPresented
            isBookShopPresented = false
            statusMessage = "Asking Gemma to write the year’s cover leaves…"
            Task { @MainActor in
                do {
                    let bound = try await gemmaAnnualBinding(for: annual)
                    let plates = await illuminatedPlates(for: bound)
                    // A year is the span these charts were built for: the
                    // endpaper of a bound year is the shape of a life.
                    let charts = await editionMapPlates(for: bound, kind: .annual)
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("ReEnchanted-Annual-\(targetYear).pdf")
                    try MonthlyEditionPDFWriter.writeAnnual(
                        bound,
                        plates: plates,
                        endpaper: charts.endpaper,
                        mapPlates: charts.plates,
                        to: url
                    )
                    let keptURL = try keepAnnualEdition(
                        bound,
                        periodID: candidate.id,
                        renderedPDF: url
                    )
                    preparedAnnualEditionURL = keptURL
                    preparedAnnualEditionPeriodID = candidate.id
                    annualBindingDedicationText = ""
                    clearPublicationBindingCheckpoint(slot: chapteredVolumeBindingSlot(for: annual))
                    statusMessage = "The \(targetYear) annual is bound, locked, and kept on the Book of You shelf."
                    BookFeedback.play(.braidComplete)
                    let reader = AnnualEditionReader(
                        edition: bound,
                        pdfURL: keptURL,
                        periodID: candidate.id
                    )
                    if wasShopOpen {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            annualEditionReader = reader
                        }
                    } else {
                        annualEditionReader = reader
                    }
                } catch {
                    await LocalBrainPublicationStageBoundary.persisted("annual-aborted")
                    statusMessage = "The annual would not bind: \(error.localizedDescription)"
                    BookFeedback.play(.error)
                }
            }
        } catch {
            statusMessage = "The annual would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    /// Imports by merge-upsert: nothing on the device is deleted; the save's
    /// pages, facts, memories, cast, and ledgers land on top.
    @MainActor
    func importSaveFile(from url: URL) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var save = try decoder.decode(ReEnchantedSaveFile.self, from: Data(contentsOf: url))

            // Restore carried photographs (and kept voice) into this install's
            // container, then re-home every file-backed reference onto it so the
            // stale absolute paths from the source phone resolve here.
            if let mediaFiles = save.mediaFiles, let container = InsideCoverStore.containerURL {
                for (filename, data) in mediaFiles {
                    let dest = container.appendingPathComponent((filename as NSString).lastPathComponent)
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        try? data.write(to: dest, options: [.atomic])
                    }
                }
                save.days = ReEnchantedSaveFile.rehomedDays(save.days, toContainer: container)
            }

            for day in save.days {
                days = (try? BookDatabase.upsert(day, fallbackDays: days)) ?? days
            }
            for fact in save.selfFacts {
                try? BookDatabase.upsertSelfFact(fact)
            }
            for event in save.narrativeEvents {
                try? BookDatabase.upsertNarrativeEvent(event)
            }
            for memory in save.entityMemories {
                try? BookDatabase.upsertEntityMemory(memory)
            }
            for entry in save.facultyEntries {
                try? BookDatabase.upsertFacultyEntry(entry)
            }
            for member in save.customCastMembers {
                try? BookDatabase.upsertCustomCastMember(member)
            }

            let importedAnchors = save.anchors.filter { anchor in
                !AnchorRegistry.retiredAnchorIDs.contains(anchor.id) &&
                !anchorLedger.contains { $0.id == anchor.id }
            }
            anchorLedger.append(contentsOf: importedAnchors)
            saveAnchorLedger()

            if let importedPlaces = save.compassKnownPlaces, !importedPlaces.isEmpty {
                var mergedPlaces = vault.data.compassKnownPlaces ?? []
                for place in importedPlaces {
                    if let index = mergedPlaces.firstIndex(where: { $0.id == place.id }) {
                        if place.updatedAt > mergedPlaces[index].updatedAt {
                            mergedPlaces[index] = place
                        }
                    } else {
                        mergedPlaces.append(place)
                    }
                }
                vault.data.compassKnownPlaces = mergedPlaces.sorted { $0.updatedAt > $1.updatedAt }
            }

            var mergedElectives = electives
            for elective in save.electives where !mergedElectives.contains(where: { $0.id == elective.id }) {
                mergedElectives.append(elective)
            }
            saveElectives(mergedElectives)

            beliefScore = max(beliefScore, save.beliefScore)
            if let data = try? JSONEncoder().encode(save.entityBeliefLedger),
               let encoded = String(data: data, encoding: .utf8) {
                entityBeliefLedgerData = encoded
            }
            if let data = try? JSONEncoder().encode(save.pageBeliefLedger),
               let encoded = String(data: data, encoding: .utf8) {
                pageBeliefLedgerData = encoded
            }
            if let importedConstellations = save.constellations, !importedConstellations.isEmpty {
                var merged = vault.data.constellations ?? []
                for constellation in importedConstellations where !merged.contains(where: { $0.id == constellation.id }) {
                    merged.append(constellation)
                }
                vault.data.constellations = merged
            }
            if let importedWagers = save.wagers, !importedWagers.isEmpty {
                var merged = vault.data.wagers ?? []
                for wager in importedWagers where !merged.contains(where: { $0.id == wager.id }) {
                    merged.append(wager)
                }
                vault.data.wagers = merged
            }
            if let importedThemes = save.themes, !importedThemes.isEmpty {
                var merged = vault.data.themes ?? []
                for theme in importedThemes {
                    merged.removeAll { $0.monthKey == theme.monthKey }
                    merged.append(theme)
                }
                vault.data.themes = merged.sorted { $0.monthKey < $1.monthKey }
            }
            if let importedLexicon = save.readerLexicon {
                var merged = vault.data.readerLexicon ?? ReaderLexicon()
                for entry in importedLexicon.entries {
                    merged.upsert(entry)
                }
                if merged.treaty == nil {
                    merged.treaty = importedLexicon.treaty
                }
                merged.bargainSeedSurfaced = merged.bargainSeedSurfaced || importedLexicon.bargainSeedSurfaced
                vault.data.readerLexicon = merged
            }
            if let importedRecipeBoosts = save.storyRecipeBoosts, !importedRecipeBoosts.isEmpty {
                var merged = vault.data.storyRecipeBoosts ?? [:]
                for (id, value) in importedRecipeBoosts {
                    merged[id] = max(merged[id] ?? 0, value)
                }
                vault.data.storyRecipeBoosts = merged
            }
            if let importedMotifs = save.storyMotifs, !importedMotifs.isEmpty {
                var merged = vault.data.storyMotifs ?? [:]
                for (id, value) in importedMotifs {
                    merged[id] = max(merged[id] ?? 0, value)
                }
                vault.data.storyMotifs = merged
            }
            if let importedRituals = save.storyRituals, !importedRituals.isEmpty {
                var merged = vault.data.storyRituals ?? [:]
                for (id, value) in importedRituals {
                    merged[id] = max(merged[id] ?? 0, value)
                }
                vault.data.storyRituals = merged
            }
            if let importedAffinities = save.storySettingAffinities, !importedAffinities.isEmpty {
                var merged = vault.data.storySettingAffinities ?? [:]
                for (id, value) in importedAffinities {
                    merged[id] = max(merged[id] ?? 0, value)
                }
                vault.data.storySettingAffinities = merged
            }
            if let importedBiases = save.storySceneBiases, !importedBiases.isEmpty {
                var merged = vault.data.storySceneBiases ?? [:]
                for (id, value) in importedBiases {
                    merged[id] = max(-24, min(24, max(merged[id] ?? -24, value)))
                }
                vault.data.storySceneBiases = merged
            }
            if let importedLedger = save.storyConsequenceLedger {
                var merged = vault.data.storyConsequenceLedger ?? .empty
                merged.merge(importedLedger.receipts)
                vault.data.storyConsequenceLedger = merged
            }
            if let importedEvidence = save.bookNoticeEvidence {
                vault.data.bookNoticeEvidence = max(vault.data.bookNoticeEvidence ?? 0, importedEvidence)
            }
            if let importedMagicMoment = save.magicMoment {
                let current = vault.data.magicMoment ?? MagicMomentState()
                // Recency wins; an already armed imported reveal is grandfathered.
                let importedIsNewer = (importedMagicMoment.lastMomentAt ?? importedMagicMoment.lastSessionAt ?? .distantPast)
                    > (current.lastMomentAt ?? current.lastSessionAt ?? .distantPast)
                vault.data.magicMoment = importedIsNewer || (importedMagicMoment.isArmed && !current.isArmed)
                    ? importedMagicMoment : current
            }
            if let importedObservations = save.bookObservations {
                var merged = Dictionary(
                    uniqueKeysWithValues: (vault.data.bookObservations ?? []).map { ($0.id, $0) }
                )
                for record in importedObservations {
                    if let current = merged[record.id], current.updatedAt > record.updatedAt { continue }
                    merged[record.id] = record
                }
                vault.data.bookObservations = Array(merged.values.sorted { $0.updatedAt < $1.updatedAt }.suffix(200))
            }
            if let importedBoundaries = save.bookReadingBoundaries {
                var merged = Dictionary(
                    uniqueKeysWithValues: (vault.data.bookReadingBoundaries ?? []).map { ($0.id, $0) }
                )
                for boundary in importedBoundaries {
                    if merged[boundary.id] == nil { merged[boundary.id] = boundary }
                }
                vault.data.bookReadingBoundaries = Array(merged.values.sorted { $0.createdAt < $1.createdAt }.suffix(200))
            }
            if let importedGreyOffset = save.nothingGreyOffset {
                vault.data.nothingGreyOffset = max(-10, min(10, importedGreyOffset))
            }
            if let importedLearning = save.readerLearning {
                let current = vault.data.readerLearning ?? ReaderLearningModel()
                vault.data.readerLearning = current.merged(with: importedLearning)
            }
            if let importedArchive = save.openWorldEventArchive,
               vault.data.openWorldEventArchive == nil {
                vault.data.openWorldEventArchive = importedArchive
            }
            if let importedLifecycle = save.worldEventLifecycle {
                var mergedLifecycle = vault.data.worldEventLifecycle ?? .empty
                mergedLifecycle.merge(importedLifecycle)
                vault.data.worldEventLifecycle = mergedLifecycle
            }
            if let importedReceipts = save.authoredContentReceipts {
                var mergedReceipts = vault.data.authoredContentReceipts ?? .empty
                mergedReceipts.merge(importedReceipts)
                vault.data.authoredContentReceipts = mergedReceipts
            }
            if let importedEpoch = save.publicationEpoch,
               vault.data.publicationEpoch == nil {
                vault.data.publicationEpoch = importedEpoch
            }
            ensurePublicationEpochIfNeeded()
            if vault.data.magicMoment == nil {
                vault.data.magicMoment = save.magicMoment
            }
            if let importedObservations = save.bookObservations {
                var merged = Dictionary(uniqueKeysWithValues: (vault.data.bookObservations ?? []).map { ($0.id, $0) })
                for observation in importedObservations
                    where observation.updatedAt > (merged[observation.id]?.updatedAt ?? .distantPast) {
                    merged[observation.id] = observation
                }
                vault.data.bookObservations = merged.values.sorted { $0.updatedAt < $1.updatedAt }
            }
            if let importedBoundaries = save.bookReadingBoundaries {
                var merged = Dictionary(uniqueKeysWithValues: (vault.data.bookReadingBoundaries ?? []).map { ($0.id, $0) })
                for boundary in importedBoundaries where merged[boundary.id] == nil {
                    merged[boundary.id] = boundary
                }
                vault.data.bookReadingBoundaries = merged.values.sorted { $0.createdAt < $1.createdAt }
            }
            if let importedDrafts = save.overnightConnectionDrafts {
                var merged = Dictionary(uniqueKeysWithValues: (vault.data.overnightConnectionDrafts ?? []).map { ($0.observationKey, $0) })
                for draft in importedDrafts
                    where draft.generatedAt > (merged[draft.observationKey]?.generatedAt ?? .distantPast) {
                    merged[draft.observationKey] = draft
                }
                vault.data.overnightConnectionDrafts = merged.values.sorted { $0.generatedAt < $1.generatedAt }
            }
            if vault.data.chosenQuill == nil {
                vault.data.chosenQuill = save.chosenQuill
            }
            if vault.data.people == nil {
                vault.data.people = save.people
            }
            if let importedEngaged = save.firstRunEngaged {
                let current = Set(vault.data.firstRunEngaged ?? [])
                vault.data.firstRunEngaged = current.union(importedEngaged).sorted()
            }
            if let importedAsideReceipts = save.bookAsideReceipts {
                vault.data.bookAsideReceipts = BookInterjectionEditor.recording(
                    importedAsideReceipts,
                    into: vault.data.bookAsideReceipts ?? [],
                    now: Date()
                )
            }
            if let importedAchievements = save.marginaliaAchievementIDs {
                let current = Set(
                    completedMarginaliaAchievementLedger
                        .split(separator: ",")
                        .map(String.init)
                )
                completedMarginaliaAchievementLedger = current
                    .union(importedAchievements)
                    .sorted()
                    .joined(separator: ",")
            }
            vault.save()
            marginTutorSeenData = MarginTutorLedger.encode(Set(save.marginTutorSeen))
            if save.didCompleteStoryOnboarding {
                didCompleteStoryOnboarding = true
            }
            if let data = try? JSONEncoder().encode(save.sourcePreferences),
               let encoded = String(data: data, encoding: .utf8) {
                sourcePreferenceLedger = encoded
            }

            selfFacts = (try? BookDatabase.selfFacts()) ?? selfFacts
            narrativeEvents = (try? BookDatabase.narrativeEvents(limit: 160)) ?? narrativeEvents
            entityMemories = NarrativeEntityMemoryConsolidator.consolidate((try? BookDatabase.entityMemories(limit: 240)) ?? entityMemories)
            customCastMembers = (try? BookDatabase.customCastMembers(limit: 200)) ?? customCastMembers
            facultyEntries = (try? BookDatabase.facultyEntries(limit: 160)) ?? facultyEntries
            PersonalNameGuard.update(from: selfFacts)
            surfaceRefreshDate = Date()
            rebuildSurfaceCache()
            statusMessage = "The save file has been read back into me: \(save.days.count) days, \(save.selfFacts.count) facts, \(save.anchors.count) anchors."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "That save file would not open: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    // MARK: - Chapters and Talismans

    var ascendantTalisman: NarrativeWorldEntity? {
        TalismanAscendancy.ascendant(
            entities: NarrativePackRegistry.entities + customCastMembers.map(\.entity),
            beliefOffsets: entityBeliefLedger
        )
    }

    @MainActor
    func bindChapter(id chapterID: String) {
        bindChapter(acceptance: ChapterBindingAcceptance(chapterID: chapterID))
    }

    @MainActor
    func bindChapter(acceptance: ChapterBindingAcceptance) {
        let chapterID = acceptance.chapterID
        guard let chapter = AcademyChapterRegistry.chapter(id: chapterID) else { return }
        let ceremony = ChapterBindingCeremony.profile(for: chapter)
        let sealLine = acceptance.sealLine.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? ceremony.sealLine
        let oathLine = acceptance.oathLine.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? ceremony.oathLine
        let invitationLine = acceptance.invitationLine.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? ceremony.invitationLine
        let aftermathLine = acceptance.aftermathLine.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? ceremony.aftermathLine
        let bindingTranslation = [
            "Chapter \(chapter.name) was recognized by the Binding.",
            sealLine,
            oathLine,
            invitationLine,
            aftermathLine
        ].joined(separator: "\n")
        saveOnboardingFact(
            questionID: "chapter-binding",
            question: "Which Chapter did the Binding recognize?",
            answer: chapter.name,
            tags: ["chapter", "identity", "binding", chapter.id, chapter.talismanID],
            bookTranslation: bindingTranslation,
            sensitivity: .identity
        )
        // The binding itself is an act of Belief: the chapter's talisman warms.
        let talisman = GlowEntityMenuItem(
            id: chapter.talismanID,
            name: chapter.talismanName,
            kind: "talisman",
            glow: 0,
            line: chapter.philosophy
        )
        adjustEntityBelief(talisman, delta: 5, kind: .beliefInvested)
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        statusMessage = "\(chapter.name) is bound. \(chapter.talismanName) warms by five points. \(invitationLine)"
        BookFeedback.chapterBinding()
    }

    // MARK: - Unified generated-page adoption

    /// One path for every "tap to generate" page: ask the engine, stamp the
    /// prose into the page, fall back to the template body when the brain
    /// is unavailable. The per-type functions below are thin orderings.
    @MainActor
    // MARK: - Braid self-improvement (Gemma in the loop)

    /// Locate a kept Book of You page by id: (dayIndex, pageIndex, page).
    private func locatedBraidPage(pageID: String) -> (Int, Int, BookPage)? {
        guard let dayIndex = days.firstIndex(where: { day in
            day.pages.contains { $0.id == pageID && $0.type == .bookOfYou }
        }), let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            return nil
        }
        return (dayIndex, pageIndex, days[dayIndex].pages[pageIndex])
    }

    static let braidTasteNoteInstructions = """
    You are the Book inside ReEnchanted, learning a single reader's taste.
    Return exactly one short second-person instruction to yourself for next time. No preamble, no quotes, no label. Begin with a verb. Never diagnose, flatter, or moralize.
    """

    /// Trim Gemma's taste note to one clean second-person line.
    static func cleanedTasteNote(_ raw: String) -> String {
        var note = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = note.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            note = firstLine
        }
        note = note.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
        for label in ["Note:", "Instruction:", "Next time:"] where note.lowercased().hasPrefix(label.lowercased()) {
            note = String(note.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
        }
        return String(note.prefix(160)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "This missed me" → Gemma reads the missed braid and writes one
    /// reader-taught taste note, persisted to steer future braids. Returns a
    /// reader-facing line. Distress-gated (the Book stays quiet on hard days).
    @MainActor
    func improveNextBraidFromMiss(pageID: String) async -> String {
        guard let (dayIndex, _, page) = locatedBraidPage(pageID: pageID) else { return "" }
        let day = days[dayIndex]
        guard !DistressSignals.evaluate(day: today).isActive else {
            return BraidLearningLoop.publicLesson(for: page)
        }
        let inputs = sourceInputs
        // Resolved here, used off the main actor below: building the context
        // rebuilds the Relational Loom over the whole archive, and the reader is
        // watching a spinner while it happens.
        let archive = days
        let themes = vault.data.themes ?? []
        let beliefOffsets = entityBeliefLedger
        let learnedNotes = vault.data.learnedBraidNotes ?? []
        let undertakings = vault.data.castUndertakings ?? []
        let lexicon = vault.data.readerLexicon ?? ReaderLexicon()
        let learning = vault.data.readerLearning ?? ReaderLearningModel()
        let story = vault.data.readerStory ?? .empty
        let role = ReaderRoleRegistry.currentRole(from: inputs.selfFacts)
        let taleLaws = inputs.taleScars.standingLaws()
        let relationship = BookRelationshipLedger.snapshot(inputs: inputs)
        let context = await Task.detached(priority: .userInitiated) {
            LocalModelManager.braidContext(
                for: day,
                days: archive,
                themes: themes,
                entityBeliefOffsets: beliefOffsets,
                learnedNotes: learnedNotes,
                castUndertakings: undertakings,
                readerLexicon: lexicon,
                readerLearning: learning,
                facultyEntries: inputs.facultyEntries,
                people: inputs.people,
                continuity: inputs.continuity,
                bookReadingBoundaries: inputs.bookReadingBoundaries,
                readerStory: story,
                readerRole: role,
                standingTaleLaws: taleLaws,
                roleTransformationClause: inputs.roleTransformationClause,
                openTale: inputs.openTale,
                bookRelationship: relationship,
                bookInterior: inputs.bookInterior
            )
        }.value
        let weak = BraidLearningLoop.weakDimensionNotes(for: page, context: context)
        let prompt = LocalModelManager.braidTasteNotePrompt(
            for: day, priorBraid: page.userInput, weakNotes: weak, context: context
        )
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: Self.braidTasteNoteInstructions,
            maxTokens: 60,
            sourceID: "braid-taste-note",
            tags: ["braid", "taste-note"]
        ) else {
            return BraidLearningLoop.publicLesson(for: page)
        }
        let note = Self.cleanedTasteNote(raw)
        guard !note.isEmpty else { return BraidLearningLoop.publicLesson(for: page) }
        var notes = vault.data.learnedBraidNotes ?? []
        notes.append(note)
        vault.data.learnedBraidNotes = Array(notes.suffix(6))
        vault.save()
        BookFeedback.play(.braidComplete)
        return "I listened, and I'll carry this into the next page: \(note)"
    }

    /// Reader-owned retelling is an edit of the telling, never of its receipts.
    ///
    /// The old implementation sent the finished prose to a small rewrite prompt
    /// and let the deterministic taster veto the reader's choice. This one goes
    /// back to the exact kept Page ids, commissions the real scene-plan braider
    /// once, and replaces the selected Page only after a safe telling lands.
    /// The Page keeps its identity and date, so archive links and publication
    /// selections continue to point at the reader's chosen telling.
    @MainActor
    func retellBraid(pageID: String, choice: BraidRetellingChoice) async {
        guard !generation.isBraiding else {
            statusMessage = "One telling is already wriggling under my hand. Let it finish first."
            BookFeedback.play(.error)
            return
        }
        guard workBlockingState.canStartBraid else {
            statusMessage = "I'm already writing one Page. Let that ink dry first."
            BookFeedback.play(.error)
            return
        }
        guard let (dayIndex, _, priorPage) = locatedBraidPage(pageID: pageID) else {
            statusMessage = "I reached for that Page, but it had already moved."
            BookFeedback.play(.error)
            return
        }

        let braidDay = days[dayIndex]
        // A later month must not leak backwards into an older Page. Taste may
        // mature; facts may not time-travel. The source receipts themselves can
        // still cross midnight because their ids are explicit.
        let archiveThroughBraid = days.filter {
            $0.id == braidDay.id || $0.date <= braidDay.date
        }
        let sourcePageIDs = BraidPageDetails.sourcePageIDs(in: priorPage)
        let readingDay: BookDay
        if sourcePageIDs.isEmpty {
            // Compatibility for Pages made before source receipts were stamped.
            readingDay = braidDay
        } else {
            readingDay = NightlyBraidWindow.readingDay(
                for: braidDay,
                pageIDs: sourcePageIDs,
                previousDays: archiveThroughBraid
            )
        }
        let readerStory = braidDay.id == today.id
            ? (vault.data.readerStory ?? .empty)
            : ReaderStory.empty
        let weavableDay = BraidPromptBuilder.weavableDay(readingDay, readerStory: readerStory)
        guard !weavableDay.capturedPages.isEmpty else {
            statusMessage = "Those old bones have no readable receipts left. I left the Page alone."
            BookFeedback.play(.error)
            return
        }

        let startedAt = Date()
        generation.isBraiding = true
        generation.braidingStartedAt = startedAt
        braidingQuipIndex = Int.random(in: 0..<BraidingQuips.lines.count)
        statusMessage = choice == .sameBones
            ? "Same bones. New breath. Hold still."
            : "I tipped the old bones onto the table to see another shape."
        BookFeedback.play(.braidStart)
        defer {
            generation.lastBraidDuration = Date().timeIntervalSince(startedAt)
            generation.braidingStartedAt = nil
            generation.isBraiding = false
        }

        do {
            var retellInputs = sourceInputs
            retellInputs.days = archiveThroughBraid
            retellInputs = retellInputs.resolvingWorldEvents(
                for: braidDay,
                now: braidDay.date
            )
            let isCurrentDay = braidDay.id == today.id
            // Resolved on the main actor, built off it: the same whole-archive
            // Loom rebuild sits behind this, and a retell is a reader waiting.
            let themes = vault.data.themes ?? []
            let beliefOffsets = entityBeliefLedger
            let learnedNotes = vault.data.learnedBraidNotes ?? []
            // A current Cast undertaking is not evidence that it was under way
            // on an older date. Kept fiction receipts still enter from the exact
            // Page ids above.
            let undertakings = isCurrentDay ? (vault.data.castUndertakings ?? []) : []
            let lexicon = vault.data.readerLexicon ?? ReaderLexicon()
            let learning = vault.data.readerLearning ?? ReaderLearningModel()
            let role = ReaderRoleRegistry.currentRole(from: retellInputs.selfFacts)
            let taleLaws = isCurrentDay ? retellInputs.taleScars.standingLaws() : []
            let roleClause = isCurrentDay ? retellInputs.roleTransformationClause : nil
            let openTale = isCurrentDay ? retellInputs.openTale : nil
            let relationship = BookRelationshipLedger.snapshot(inputs: retellInputs)
            let retellDate = braidDay.date
            var context = await Task.detached(priority: .userInitiated) {
                LocalModelManager.braidContext(
                    for: weavableDay,
                    days: archiveThroughBraid,
                    themes: themes,
                    entityBeliefOffsets: beliefOffsets,
                    learnedNotes: learnedNotes,
                    activeWorldEvents: retellInputs.activeWorldEvents,
                    castUndertakings: undertakings,
                    readerLexicon: lexicon,
                    readerLearning: learning,
                    facultyEntries: retellInputs.facultyEntries,
                    people: retellInputs.people,
                    continuity: retellInputs.continuity,
                    bookReadingBoundaries: retellInputs.bookReadingBoundaries,
                    semanticScorer: SemanticKeepEcho.keepTimeScorer,
                    readerStory: readerStory,
                    readerRole: role,
                    standingTaleLaws: taleLaws,
                    roleTransformationClause: roleClause,
                    openTale: openTale,
                    bookRelationship: relationship,
                    bookInterior: retellInputs.bookInterior,
                    now: retellDate
                )
            }.value
            context = Self.contextForRetelling(
                context,
                day: weavableDay,
                priorPage: priorPage,
                choice: choice
            )

            var retold = try await braider.braid(day: weavableDay, context: context)
            // Location, weather and clock belong to the original Page. A
            // retelling edits prose; it must not put today's weather on an old
            // night merely because that is what the device can read now.
            let originalHeader = priorPage.userInput
                .components(separatedBy: .newlines)
                .first { $0.hasPrefix(BraidPageDetails.headerPrefix) }
            retold = BraidPageDetails.annotated(retold, context: context)
            if let originalHeader,
               !retold.userInput.hasPrefix(BraidPageDetails.headerPrefix) {
                retold.userInput = "\(originalHeader)\n\n\(retold.userInput)"
            }
            let usedPageIDs = Set(weavableDay.capturedPages.map(\.id))
            retold = BraidPageDetails.withSourcePages(retold, pageIDs: usedPageIDs)

            // The promise and rare backwards question belong to that night's
            // place in the Book. Retelling its prose must not mint a new one.
            var retoldTags = Set(retold.tags)
            for tag in priorPage.tags where
                tag.hasPrefix(BraidPageDetails.promiseEchoTagPrefix)
                    || tag.hasPrefix(BraidPageDetails.backwardQuestionTagPrefix)
                    || tag == ReaderShelf.shadowTag
                    || tag == ReaderShelf.lightTag
                    || tag == ReaderShelf.sealedTag {
                retoldTags.insert(tag)
            }
            retoldTags.insert("braid-retold")
            retoldTags.insert("braid-retelling:\(choice.rawValue)")
            retold.tags = retoldTags.sorted()

            // Identity and chronology stay stable. Only the telling changes.
            retold.id = priorPage.id
            retold.createdAt = priorPage.createdAt
            retold.usedInBookOfYou = true
            retold.mediaAssets = weavableDay.capturedPages.flatMap(\.mediaAssets)
            retold.context = priorPage.context
            retold.attentionFingerprint = AttentionFingerprint.make(from: retold)
            retold.sensoryFolio = SensoryFolioProjector.structuredFolio(from: retold)

            // Generation awaited outside the presentation stack. Re-locate the
            // Page now so a Keep that landed meanwhile is never overwritten by
            // a stale day snapshot.
            guard let (liveDayIndex, livePageIndex, _) = locatedBraidPage(pageID: pageID) else {
                statusMessage = "The new telling came back, but its Page had moved. I did not force it into the shelf."
                BookFeedback.play(.error)
                return
            }
            var updatedDay = days[liveDayIndex]
            updatedDay.pages[livePageIndex] = retold
            persist(
                day: updatedDay,
                message: "A new telling took the old Page's place. Its receipts stayed put."
            )
            surfaceRefreshDate = Date()
            BookFeedback.play(.braidComplete)
            modelReport = LocalModelManager.report()
            localBrainTelemetry.clearError()

            // Let persistence publish its immediate archive snapshot before a
            // fresh sheet is presented. This keeps the retell out of the same
            // presentation/re-entrancy seam that has bitten Keep paths.
            try? await Task.sleep(for: .milliseconds(180))
            selectedSurface = keptSurface(for: retold)
        } catch {
            localBrainTelemetry.recordError("braid retell: \(error.localizedDescription)")
            statusMessage = "The retelling snagged. I left the Page exactly as it was. \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    /// Re-seat the persisted literary axes for "same bones", or rotate only
    /// the story form for a fresh shape. Facts, motion, pressure and receipts
    /// remain evidence-owned in both cases.
    private static func contextForRetelling(
        _ incoming: BraidPromptBuilder.Context,
        day: BookDay,
        priorPage: BookPage,
        choice: BraidRetellingChoice
    ) -> BraidPromptBuilder.Context {
        var context = incoming
        var reading = context.storyScore?.taleReading
            ?? context.taleReading
            ?? BraidPromptBuilder.taleReading(for: day, context: context)
        let residue = BookOfYouResidue.fromTags(in: priorPage)

        func axis<T: RawRepresentable>(_ prefix: String, as type: T.Type) -> T?
        where T.RawValue == String {
            priorPage.tags
                .first { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) }
                .flatMap { T(rawValue: $0) }
        }

        if let motion = axis("braid-plan-motion:", as: BraidPromptBuilder.NarrativeMotion.self) {
            reading.motion = motion
        }
        if let pressure = axis("braid-plan-pressure:", as: BraidPromptBuilder.FaeriePressure.self) {
            reading.pressure = pressure
        }
        if let scale = axis("braid-plan-scale:", as: BraidPromptBuilder.BraidScale.self) {
            reading.scale = scale
        }
        if let rut = residue?.rutInfluence {
            reading.rutInfluence = rut
            reading.rutEvidencePageIDs = residue?.rutEvidencePageIDs ?? reading.rutEvidencePageIDs
        }

        let priorForm = axis("braid-plan-form:", as: BraidPromptBuilder.StoryForm.self)
            ?? residue?.storyForm
            ?? reading.storyForm
        switch choice {
        case .sameBones:
            reading.storyForm = priorForm
            if let register = residue?.narrativeRegister {
                reading.narrativeRegister = register
            }
        case .freshShape:
            reading.storyForm = alternativeStoryForm(
                after: priorForm,
                reading: reading,
                day: day
            )
        }

        context.taleReading = reading
        if var score = context.storyScore {
            score.taleReading = reading
            context.storyScore = score
        }
        return context
    }

    private static func alternativeStoryForm(
        after current: BraidPromptBuilder.StoryForm,
        reading: BraidPromptBuilder.TaleReading,
        day: BookDay
    ) -> BraidPromptBuilder.StoryForm {
        let pageCount = BraidPromptBuilder.braidEligiblePages(in: day).count
        let cycle: [BraidPromptBuilder.StoryForm] = [
            .sliceOfLife, .portrait, .mosaic, .vigil,
            .crossing, .drama, .returnForm
        ]
        let allowed = cycle.filter { form in
            switch form {
            case .mosaic:
                return pageCount >= 2
            case .crossing:
                return reading.motion == .crossing
            case .drama:
                return reading.motion == .bargain || reading.motion == .refusal
            case .returnForm:
                return reading.motion == .recurrence || reading.motion == .returnOfSomething
            case .sliceOfLife, .portrait, .vigil:
                return true
            case .romance, .comedy:
                return false
            }
        }
        guard !allowed.isEmpty else { return .sliceOfLife }
        guard let currentIndex = cycle.firstIndex(of: current) else {
            return allowed.first(where: { $0 != current }) ?? .sliceOfLife
        }
        for offset in 1...cycle.count {
            let candidate = cycle[(currentIndex + offset) % cycle.count]
            if allowed.contains(candidate), candidate != current { return candidate }
        }
        return allowed.first ?? .sliceOfLife
    }

    func generatedProseSurface(
        from base: SurfacePage,
        proseKey: String,
        prompt: String,
        instructions: String,
        maxTokens: Int = 520,
        sourceID: String,
        tags: [String],
        fallbackBody: String? = nil
    ) async -> SurfacePage {
        var metadata = base.payload.metadata
        let body: String
        if let first = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: maxTokens,
            sourceID: sourceID,
            tags: tags
        ), !first.hasPrefix("{") {
            let canon = metadata[CharacterCanonPacket.metadataKey] ?? ""
            let firstAudit = await CharacterFidelityReviewer.audit(
                prose: first,
                canon: canon,
                context: "\(base.type.rawValue) surface \(base.payload.headline)",
                sourceID: sourceID
            )
            var prose = first
            var repairedAudit: CharacterFidelityAudit?
            var selectedDraft: CharacterFidelityReceipt.SelectedDraft = .first
            if firstAudit.shouldRepair,
               let repaired = await LocalBrainProse.write(
                    prompt: """
                    \(prompt)

                    CHARACTER CONTINUITY REPAIR:
                    \(firstAudit.feedback)
                    Return the complete prose again, preserving every factual and mechanical requirement.
                    """,
                    instructions: instructions,
                    maxTokens: maxTokens,
                    sourceID: sourceID,
                    tags: tags + ["character-repair"]
               ),
               !repaired.hasPrefix("{") {
                let audit = await CharacterFidelityReviewer.audit(
                    prose: repaired,
                    canon: canon,
                    context: "repaired \(base.type.rawValue) surface \(base.payload.headline)",
                    sourceID: sourceID
                )
                repairedAudit = audit
                if CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: audit) {
                    prose = repaired
                    selectedDraft = .repaired
                }
            }
            await CharacterFidelityReviewer.recordDecision(
                sourceID: sourceID,
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: repairedAudit,
                selected: selectedDraft
            )
            metadata[proseKey] = prose
            body = prose
        } else {
            metadata[proseKey] = "fallback"
            body = fallbackBody ?? base.payload.body
        }
        return SurfacePage(
            id: base.id,
            type: base.type,
            sourceID: base.sourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: base.score,
            reason: base.reason,
            prompt: base.prompt,
            detail: base.detail,
            payload: BookPagePayload(headline: base.payload.headline, body: body, metadata: metadata)
        )
    }

    @MainActor
    func twoReadingsSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        let metadata = base.payload.metadata
        let aName = metadata["entityAName"] ?? "One reader"
        let bName = metadata["entityBName"] ?? "Another reader"
        let fallback = Self.twoReadingsFallbackBody(metadata: metadata, aName: aName, bName: bName)
        return await generatedProseSurface(
            from: base,
            proseKey: "twoReadingsProse",
            prompt: LocalModelManager.twoReadingsPrompt(surface: base, day: today),
            instructions: """
            You are the Labyrinth staging a disagreement between two cast members inside ReEnchanted. Prose only, no headings. Both positions must be fair; end by leaving the choice to the reader. \(BookVoice.animismLine)
            """,
            maxTokens: 620,
            sourceID: "two-readings",
            tags: ["two-readings", "entity:\(metadata["entityAID"] ?? "")", "entity:\(metadata["entityBID"] ?? "")"],
            fallbackBody: fallback
        )
    }

    static func twoReadingsFallbackBody(metadata: [String: String], aName: String, bName: String) -> String {
        let aProfile = metadata["entityAProfile"]?.nonEmpty ?? aName
        let bProfile = metadata["entityBProfile"]?.nonEmpty ?? bName
        let note = metadata["relationshipNote"]?.nonEmpty
        let pageText = metadata["anchorPageText"]?.nonEmpty
        let authored = metadata["anchorPageAuthored"] == "1"
        let mayQuote = metadata["anchorPageMayQuote"] != "0"

        let aStance = stanceLine(for: aProfile, name: aName, fallback: "the page is asking for care before interpretation")
        let bStance = stanceLine(for: bProfile, name: bName, fallback: "the page is asking for movement before certainty")
        let bridge = note.map { "\n\nBetween them, the old thread hums: \($0)" } ?? ""
        let opening = pageText.map { text in
            let presented = mayQuote ? "“\(text)”" : text
            return authored
                ? "\(aName) and \(bName) both stopped on the page you wrote (\(presented)) and did not come back with the same weather in their hands."
                : "\(aName) and \(bName) both stopped on the same kept evidence (\(presented)) and did not come back with the same weather in their hands."
        } ?? "\(aName) and \(bName) read the same kept page and did not come back with the same weather in their hands."

        return """
        \(opening)

        \(aName) says \(aStance). Not as a verdict. As a lantern held close to the ink.

        \(bName) says \(bStance). Not because \(aName) is wrong, exactly, but because another truth is standing at the edge of the same sentence.\(bridge)

        The Book will not settle this. It only places both readings in the margin and waits to see which one you keep closer.
        """
    }

    private static func stanceLine(for profile: String, name: String, fallback: String) -> String {
        let lower = profile.lowercased()
        if lower.contains("rest") || lower.contains("body") || lower.contains("care") || lower.contains("sleep") {
            return "the body is not background; it is part of the story, and it may be speaking first"
        }
        if lower.contains("pattern") || lower.contains("evidence") || lower.contains("notice") || lower.contains("record") {
            return "the pattern matters; one page is a moment, but repeated ink is beginning to behave like a map"
        }
        if lower.contains("wonder") || lower.contains("play") || lower.contains("curiosity") || lower.contains("adventure") {
            return "the important thing may be the little door that opened, not the reason it opened"
        }
        if lower.contains("protect") || lower.contains("boundary") || lower.contains("truth") || lower.contains("honest") {
            return "the honest edge of the page should not be softened until it disappears"
        }
        if lower.contains("chapter") || lower.contains("belief") {
            return "this belongs to the larger chapter, and the larger chapter is asking to be named"
        }
        return "\(fallback), at least as \(name) reads it"
    }

    @MainActor
    func castBondSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        if base.payload.metadata["tags", default: ""].contains(QuillChoosing.chosenTag) {
            return await quillChoosingSurfaceWithProse(from: base)
        }
        let metadata = base.payload.metadata
        let aName = metadata["entityAName"] ?? "One character"
        let bName = metadata["entityBName"] ?? "Another character"
        let kind = metadata["bondKind"] ?? "alliance"
        return await generatedProseSurface(
            from: base,
            proseKey: "castBondProse",
            prompt: LocalModelManager.castBondPrompt(surface: base, day: today),
            instructions: """
            You are the Labyrinth staging an emergent relationship beat inside ReEnchanted. Prose only, no headings. The relationship milestone must become visible as a scene. \(BookVoice.animismLine)
            """,
            maxTokens: 620,
            sourceID: "cast-bond",
            tags: ["cast-bond", kind, "entity:\(metadata["entityAID"] ?? "")", "entity:\(metadata["entityBID"] ?? "")"],
            fallbackBody: "\(aName) and \(bName) crossed a \(kind) threshold in the Loom. I saw the thread change color, and from then on the web no longer treated them as strangers."
        )
    }

    @MainActor
    func quillChoosingSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        var metadata = base.payload.metadata
        let quill: ChosenQuill? = metadata[QuillChoosing.metadataKey]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(ChosenQuill.self, from: $0) }
        let generated = await LocalBrainProse.write(
            prompt: LocalModelManager.quillChoosingPrompt(surface: base),
            instructions: """
            Write only the Pen Choosing ceremony in second-person past tense. Keep the named instrument, the Quillquarium, the reader's observed writing habits, and the unresolved keep-or-wait choice. Prose only; never first-person narration.
            """,
            maxTokens: 720,
            sourceID: "quillquarium-choosing",
            tags: ["pen-choosing", "quillquarium", "second-person", "past-tense", "quill:\(metadata["quillID"] ?? "waiting")"]
        )
        let prose: String
        if let generated, !generated.hasPrefix("{"),
           let quill,
           QuillChoosing.generatedCeremonyIsGrounded(generated, quill: quill) {
            prose = generated
            metadata["quillChoosingProse"] = generated
            metadata["castBondProse"] = generated
            metadata["proseStatus"] = "generated"
        } else {
            prose = quill.map { QuillChoosing.choosingBody(quill: $0) } ?? base.payload.body
            metadata["quillChoosingProse"] = "fallback"
            metadata["castBondProse"] = "fallback"
            metadata["proseStatus"] = "fallback"
        }
        return SurfacePage(
            id: base.id,
            type: base.type,
            sourceID: base.sourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: base.score,
            reason: base.reason,
            prompt: "The quill that chose you",
            detail: "In the Quillquarium, one living instrument had finished waiting.",
            payload: BookPagePayload(headline: base.payload.headline, body: prose, metadata: metadata)
        )
    }

    @MainActor
    func bookJumpSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        let action = base.payload.metadata["bookJumpAction"] ?? BookJumpAction.advance.rawValue
        let continuityInstruction = action == BookJumpAction.start.rawValue
            ? "This is the opening jump: the fall through the page may be shown once."
            : "The reader is already inside the book. Begin with the consequence of their last choice. Never repeat the fall, landing, arrival, premise, or introductory scene-setting."
        return await generatedProseSurface(
            from: base,
            proseKey: "bookJumpProse",
            prompt: LocalModelManager.bookJumpPrompt(surface: base),
            instructions: """
            You are the Book inside ReEnchanted staging a controlled Book Jump into a named public-domain work. Write to the senses, name the book's actual places and people, and never settle for generic mood. \(BookVoice.animismLine) \(continuityInstruction) Prose only, no headings, no quotes from the source text.
            """,
            maxTokens: 700,
            sourceID: "book-jump",
            tags: [
                "book-jump",
                base.payload.metadata["bookID"] ?? "public-domain",
                base.payload.metadata["bookJumpAction"] ?? "advance"
            ],
            fallbackBody: base.payload.body
        )
    }

    @MainActor
    func supportGuildSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        var metadata = base.payload.metadata
        let prompt = LocalModelManager.supportGuildPrompt(surface: base)
        let instructions = """
        You are the Support Guild scribe inside ReEnchanted. Return only the requested labeled sections. Complete every sentence. Never label prose paragraphs with "Try:".
        """
        let generated = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 760,
            sourceID: "support-guild",
            tags: ["support-guild", "dr-vellum", "dr-inkrest"]
        )
        var raw = (generated?.hasPrefix("{") == false) ? (generated ?? "") : ""
        if !raw.isEmpty {
            let canon = metadata[CharacterCanonPacket.metadataKey] ?? ""
            let firstAudit = await CharacterFidelityReviewer.audit(
                prose: raw,
                canon: canon,
                context: "Support Guild consultation between Dr. Vellum and Dr. Inkrest",
                sourceID: "support-guild"
            )
            var repairedAudit: CharacterFidelityAudit?
            var selectedDraft: CharacterFidelityReceipt.SelectedDraft = .first
            if firstAudit.shouldRepair,
               let repaired = await LocalBrainProse.write(
                    prompt: "\(prompt)\n\nCHARACTER CONTINUITY REPAIR:\n\(firstAudit.feedback)\nReturn every required labeled section again.",
                    instructions: instructions,
                    maxTokens: 760,
                    sourceID: "support-guild",
                    tags: ["support-guild", "dr-vellum", "dr-inkrest", "character-repair"]
               ),
               !repaired.hasPrefix("{") {
                let audit = await CharacterFidelityReviewer.audit(
                    prose: repaired,
                    canon: canon,
                    context: "repaired Support Guild consultation",
                    sourceID: "support-guild"
                )
                repairedAudit = audit
                if CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: audit) {
                    raw = repaired
                    selectedDraft = .repaired
                }
            }
            await CharacterFidelityReviewer.recordDecision(
                sourceID: "support-guild",
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: repairedAudit,
                selected: selectedDraft
            )
        }
        let parsed = SupportGuildProseParser.parse(raw, fallbackMetadata: metadata, fallbackBody: base.payload.body)

        metadata["guildProse"] = raw.isEmpty ? "fallback" : raw
        metadata["vellumSection"] = parsed.vellum
        metadata["inkrestSection"] = parsed.inkrest
        metadata["connectionsSection"] = parsed.connections
        metadata["experimentSection"] = parsed.experiment
        metadata["safetySection"] = parsed.safety

        return SurfacePage(
            id: base.id,
            type: base.type,
            sourceID: base.sourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: base.score,
            reason: base.reason,
            prompt: base.prompt,
            detail: base.detail,
            payload: BookPagePayload(headline: base.payload.headline, body: parsed.scene, metadata: metadata)
        )
    }

    @MainActor
    func academyClassSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        let draft = StoryPageSceneDraft(surface: base)
        let fallback = StoryPageProse(fallback: draft)
        let prose: StoryPageProse

        do {
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXStoryPageWriter().write(surface: base)
            #else
            prose = fallback
            #endif
        } catch {
            appLog.error("Academy lesson prose fell back: \(error.localizedDescription, privacy: .private)")
            prose = fallback
        }

        let prepared = base.preparedStoryPageCopy(prose: prose, slotID: "academy-\(base.id)")
        var metadata = prepared.payload.metadata
        metadata["classProse"] = prose.scene
        metadata["academyLessonPage"] = "true"
        return SurfacePage(
            id: prepared.id,
            type: prepared.type,
            sourceID: prepared.sourceID,
            intent: prepared.intent,
            renderStyle: prepared.renderStyle,
            score: prepared.score,
            reason: prepared.reason,
            prompt: prepared.prompt,
            detail: prepared.detail,
            payload: BookPagePayload(headline: prepared.payload.headline, body: prepared.payload.body, metadata: metadata)
        )
    }

    @MainActor
    func packPageSurfaceWithProse(from base: SurfacePage) async -> SurfacePage {
        await generatedProseSurface(
            from: base,
            proseKey: "packProse",
            prompt: base.payload.metadata["packPrompt"] ?? "",
            instructions: (base.payload.metadata["packInstructions"] ?? "You are the Book inside ReEnchanted. \(BookVoice.animismLine) Write the requested page in prose only.")
                + (base.payload.metadata[BookVoicePatina.metadataKey] ?? sourceInputs.bookVoicePatina.promptSection),
            maxTokens: Int(base.payload.metadata["packMaxTokens"] ?? "") ?? 420,
            sourceID: "pack-page",
            tags: ["pack-page", base.payload.metadata["packArchetypeID"] ?? "unknown"]
        )
    }

    @MainActor
    func electiveOfferSurfaceWithAsk(from base: SurfacePage) async -> SurfacePage {
        let offer = await ElectiveOfferWriter().offer(surface: base)
        var metadata = base.payload.metadata
        metadata["electiveTitle"] = offer.title
        metadata["electiveAsk"] = offer.ask
        metadata["electiveWhy"] = offer.whyItMatters
        metadata["electivePractice"] = offer.practiceShape
        let body = """
        \(offer.ask)

        Why it matters to them: \(offer.whyItMatters)

        What counts as done: \(offer.practiceShape)

        Keep this page to accept. The note will be tucked into the flyleaf: \(electives.filter(\.isActive).count)/\(UnwrittenElective.maxActive) slots used.
        """
        return SurfacePage(
            id: base.id,
            type: base.type,
            sourceID: base.sourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: base.score,
            reason: base.reason,
            prompt: "\(offer.title): \(base.payload.metadata["senderName"] ?? "a character")",
            detail: base.detail,
            payload: BookPagePayload(headline: "A Quest", body: body, metadata: metadata)
        )
    }

    func makeOuterStacksRoomWriter() -> OuterStacksRoomWriting {
        OuterStacksRoomEngine()
    }

    // MARK: - Search the Stacks

    var stacksSearchDataset: StacksSearchDataset {
        StacksSearchDataset(
            days: days,
            entities: NarrativePackRegistry.entities + customCastMembers.map(\.entity),
            entityBeliefOffsets: entityBeliefLedger,
            pageBeliefOffsets: pageBeliefLedger,
            anchors: anchorLedger,
            memories: entityMemories,
            electives: electives,
            references: BookReferenceCatalog.wonderCompass
                + BookReferenceCatalog.lorePacks.flatMap(\.snippets),
            selfFacts: selfFacts,
            narrativeEvents: narrativeEvents,
            facultyEntries: facultyEntries
        )
    }

    @MainActor
    func openSearchResult(_ result: StacksSearchResult) {
        switch result.kind {
        case .keptPage:
            if let page = days.flatMap(\.pages).first(where: { $0.id == result.referenceID }) {
                openKeptPage(page)
            }
        case .reference:
            if result.referenceID.hasPrefix("wonder-compass") {
                selectedSurface = readingSurface(forWonderCompassSectionID: result.referenceID)
            } else if let snippet = BookReferenceCatalog.lorePacks.flatMap(\.snippets).first(where: { $0.id == result.referenceID }) {
                selectedSurface = searchInfoSurface(
                    title: snippet.title,
                    headline: "From the Lore Shelves",
                    body: snippet.body,
                    tags: "lore,search"
                )
            }
        case .anchor:
            if let anchor = anchorLedger.first(where: { $0.id == result.referenceID }) {
                let placeReceipt = anchor.place.map { "\n\nReal place: \($0.promptLine)" } ?? ""
                let atmosphere = anchor.emotionalRegister.flatMap { $0.nonEmpty }
                    .map { "\n\nAtmosphere: \($0)" }
                    ?? ""
                selectedSurface = searchInfoSurface(
                    title: anchor.name,
                    headline: "Outer Stacks: \(anchor.name)",
                    body: "\(anchor.kind.title) Anchor, anchored \(anchor.created). Visits: \(anchor.visitCount).\(placeReceipt)\(atmosphere)\n\nYour words: \(anchor.playerWords)\n\nRoom: \(anchor.outerStacksRoom)\n\nFae: \(anchor.fae)\n\nLocal rule: \(anchor.localRule)\n\nStand within two hundred meters and press the Location seal to step inside.",
                    tags: "anchor,search"
                )
            }
        case .castMember:
            let pool = NarrativePackRegistry.entities + customCastMembers.map(\.entity)
            if let entity = pool.first(where: { $0.id == result.referenceID }) {
                let glow = BeliefLexicon.glowName(for: max(0, min(100, entity.belief + (entityBeliefLedger[entity.id] ?? 0))))
                let lines = [
                    entity.chapter.map { "Chapter \($0)" },
                    "Glow: \(glow)",
                    entity.traits.isEmpty ? nil : "Traits: \(entity.traits.joined(separator: ", "))",
                    entity.beliefs.first.map { "Believes: \($0)" },
                    entity.goals.first.map { "Wants: \($0)" },
                    entity.unwrittenInterest.map { "Privately studies: \($0)" }
                ].compactMap { $0 }
                selectedSurface = searchInfoSurface(
                    title: entity.name,
                    headline: entity.name,
                    body: lines.joined(separator: "\n\n"),
                    tags: "cast,search,entity:\(entity.id)"
                )
            }
        case .memory, .elective, .pageFamily, .selfFact, .narrativeEvent, .facultyEntry:
            selectedSurface = searchInfoSurface(
                title: result.title,
                headline: result.title,
                body: result.snippet,
                tags: "search"
            )
        }
    }

    private func searchInfoSurface(title: String, headline: String, body: String, tags: String) -> SurfacePage {
        SurfacePage(
            id: "search-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-\(Int(Date().timeIntervalSince1970))",
            type: .lore,
            sourceID: "labyrinth-lore",
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 70,
            reason: "Pulled from the Stacks by your own question.",
            prompt: title,
            detail: "Found in the Stacks.",
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: ["source": "labyrinth-lore", "tags": tags, "keptPage": "true"]
            )
        )
    }

    // MARK: - The BookShop

    @MainActor
    func setBoundYearDigitalAccess(_ isActive: Bool) {
        let packID = PackEntitlements.boundYearDigitalPackID
        let changed: Bool
        if isActive {
            changed = PackEntitlements.ownedPackIDs.insert(packID).inserted
        } else {
            changed = PackEntitlements.ownedPackIDs.remove(packID) != nil
        }
        guard changed else { return }
        vault.data.ownedPacks = Array(PackEntitlements.ownedPackIDs).sorted()
        SentenceBuilderPackRegistry.reload()
        vault.save()
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        refreshMonthlyIssueDelivery()
    }

    @MainActor
    func unlockPack(_ packID: String) {
        guard !PackEntitlements.isUnlocked(packID) else { return }
        PackEntitlements.ownedPackIDs.insert(packID)
        vault.data.ownedPacks = Array(PackEntitlements.ownedPackIDs).sorted()
        SentenceBuilderPackRegistry.reload()
        vault.save()
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        refreshMonthlyIssueDelivery()
        let title = BookShopCatalog.listing(forPackID: packID)?.title ?? packID
        statusMessage = ""
        presentPurchaseThankYouSurface(packID: packID, title: title)
        BookFeedback.play(.braidComplete)
    }

    @MainActor
    private func presentPurchaseThankYouSurface(packID: String, title: String) {
        let surface = purchaseThankYouPage(packID: packID, title: title)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            purchaseThankYouSurface = surface
        }
    }

    private func purchaseThankYouPage(packID: String, title: String) -> SurfacePage {
        let isStandingOrder = packID == PackEntitlements.standingOrderPackID
        let headline = isStandingOrder ? "The bargain followed you home." : "\(title) is bound. Thank you."
        let newPagesLine = "\n\nNew pages from this binding can now find their way to the desk."
        let body: String
        if isStandingOrder {
            body = """
            A Page from the Other Side of the Cover

            The Inscription closes behind you with the soft, final sound of a promise finding its place.

            “A deal with the fae is never only a price,” the Book writes. “You offered me a Standing Order. While it stands, I owe you movement.”

            Somewhere in the stacks, new characters look up. A sealed mystery changes shelves. A song clears its throat. Next month's folio starts walking toward you.

            The Book has not purchased your attention. It has promised to keep earning it.

            Then the cover falls open onto Home.

            It looks like the life you already had, with one more door in it.
            """
        } else {
            body = """
            Creator's Note

            Thank you for helping keep ReEnchanted alive. This Book is built out of small strange things: pages that notice back, sounds from the margins, odd little doors, and real bindings you can keep.

            Your support buys the quiet practical magic too: time to write, draw, tune, test, and keep the Book kind. No hovering receipt should have to sit above your feed forever; this note is just a warm slip of paper, here long enough to be read, then ready to be swiped away.\(newPagesLine)
            """
        }

        return SurfacePage(
            id: "purchase-thanks-\(packID)-\(Int(Date().timeIntervalSince1970))",
            type: .patreon,
            sourceID: "creator-thanks",
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 98,
            reason: isStandingOrder
                ? "The faerie bargain crossed the threshold and became the first Page of the next chapter."
                : "A creator's note arrived with the binding.",
            prompt: headline,
            detail: "A readable thank-you page, tucked into Pages Rising.",
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: [
                    "source": "creator-thanks",
                    "surfaceLabel": isStandingOrder ? "The Bargain" : "Thank you",
                    "symbol": isStandingOrder ? "seal.fill" : "heart.fill",
                    "purchaseThankYou": "true",
                    "packID": packID,
                    "packTitle": title,
                    "tags": "creator-note,purchase-thanks,\(isStandingOrder ? "standing-order" : "content-pack")"
                ]
            )
        )
    }

    /// Closes an entitlement the App Store no longer vouches for. Only the
    /// Standing Order ever travels this path: outright purchases are permanent.
    @MainActor
    func revokePack(_ packID: String) {
        guard PackEntitlements.ownedPackIDs.contains(packID) else { return }
        PackEntitlements.ownedPackIDs.remove(packID)
        vault.data.ownedPacks = Array(PackEntitlements.ownedPackIDs).sorted()
        SentenceBuilderPackRegistry.reload()
        vault.save()
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        refreshMonthlyIssueDelivery()
        if packID == PackEntitlements.standingOrderPackID {
            StandingOrderTrialReminder.cancel()
            statusMessage = "The Standing Order snapped shut. It took nothing with it: your Pages are still yours, the plain binding holds, and the lamp refuses to go out. Pry the Order open again if you ever want it."
        }
    }

    // MARK: - Fuel arithmetic

    /// Fire-and-forget: the page is already kept; Vellum's assistant adds
    /// the numbers to the chart when the ledger answers.
    func enrichFuelEntry(_ entry: FacultyEntry) {
        Task { @MainActor in
            guard let ledger = await VellumNutritionist.estimate(for: entry.rawText) else { return }
            var amended = entry
            amended.rawText = "\(entry.rawText)\n\(ledger.presentation)"
            amended.tags = Array(Set(entry.tags + ledger.tags)).sorted()
            do {
                try BookDatabase.upsertFacultyEntry(amended)
                facultyEntries = (try? BookDatabase.facultyEntries(limit: 160)) ?? facultyEntries
                statusMessage = "Vellum's assistant pencils in the ledger: \(ledger.total.shortMacroLine)"
                BookFeedback.play(.select)
            } catch {
                appLog.error("Fuel enrichment save failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    // MARK: - The knock

    /// The first knock makes the physical state legible. A second knock within
    /// a breath asks the character behind that state to answer more personally.
    @MainActor
    func knockOnTheCover() {
        BookFeedback.play(.knock)
        let now = Date()
        defer { lastKnockAt = now }

        guard let last = lastKnockAt, now.timeIntervalSince(last) < 1.2 else {
            let mark = BookMaterialMark.current(
                in: vault.data.bookInterior ?? .unawakened,
                greyIsInsideCover: vault.data.greyPageThreats?.activeThreat != nil
            )
            let explanation = mark.explanation
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                bookKnockNote = explanation
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                guard bookKnockNote == explanation else { return }
                withAnimation(.easeIn(duration: 0.45)) {
                    bookKnockNote = nil
                }
            }
            return
        }
        knocksThisSession += 1
        lastKnockAt = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int.random(in: 650...1_400)))

            let relationship = openingVoiceContext.bookRelationship
            let bookHasSomethingToOwn = relationship.stance == .contrite || relationship.stance == .protective
            let bookKnowsThisKnock = relationship.depth == .trusted || relationship.depth == .companion
            let passesNote = bookHasSomethingToOwn
                || (bookKnowsThisKnock && knocksThisSession >= 2)
                || (knocksThisSession == 1 ? Int.random(in: 0..<4) == 0 : Int.random(in: 0..<3) == 0)
            if passesNote || knocksThisSession >= 4 {
                openingVoiceSeed = Int.random(in: 0..<10_000) + knocksThisSession
                let note = openingVoice.knockLine
                BookFeedback.play(.select)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    bookKnockNote = note
                }
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.easeIn(duration: 0.45)) {
                    bookKnockNote = nil
                }
            } else {
                BookFeedback.play(.knockReply)
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 6)) {
                    bannerShudder = true
                }
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) {
                    bannerShudder = false
                }
            }
        }
    }
}

enum PagewrightFormat: String, CaseIterable, Identifiable {
    case scrapPage
    case pocketPage
    case miniIssue
    case letterPacket

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scrapPage: return "Scrap"
        case .pocketPage: return "Pocket"
        case .miniIssue: return "Issue"
        case .letterPacket: return "Letter"
        }
    }

    var shareName: String {
        switch self {
        case .scrapPage: return "Scrap Page"
        case .pocketPage: return "Pocket Page"
        case .miniIssue: return "Mini Issue"
        case .letterPacket: return "Letter Packet"
        }
    }

    var symbolName: String {
        switch self {
        case .scrapPage: return "scissors"
        case .pocketPage: return "rectangle.stack.badge.plus"
        case .miniIssue: return "newspaper"
        case .letterPacket: return "envelope.open"
        }
    }

    var detail: String {
        switch self {
        case .scrapPage:
            return "A freeform collage from as many kept pages as you want."
        case .pocketPage:
            return "A tucked-paper spread for gathered fragments."
        case .miniIssue:
            return "A tiny zine for a week, trip, mood, or theme."
        case .letterPacket:
            return "A giftable note with selected evidence inside."
        }
    }

    var defaultSelectionCount: Int {
        switch self {
        case .scrapPage: return 3
        case .pocketPage: return 5
        case .miniIssue: return 8
        case .letterPacket: return 4
        }
    }

    var maxSelectionCount: Int {
        switch self {
        case .scrapPage, .pocketPage, .miniIssue, .letterPacket:
            return 999
        }
    }
}

enum PagewrightTrayMode: String, Identifiable {
    case scraps
    case marks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scraps: return "Scraps"
        case .marks: return "Marks"
        }
    }

    var symbolName: String {
        switch self {
        case .scraps: return "tray.full"
        case .marks: return "seal"
        }
    }
}

enum PagewrightScrapTrayScope: String, CaseIterable, Identifiable {
    case all
    case sameType
    case sameDay
    case photos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .sameType: return "Same Type"
        case .sameDay: return "Same Day"
        case .photos: return "Photos"
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "tray.full"
        case .sameType: return "square.stack"
        case .sameDay: return "calendar"
        case .photos: return "photo"
        }
    }
}

// `PagewrightMarkTrayCategory` used to live here: five buttons keyed to
// `IlluminationAssetKind`. Kind is how a mark composites, not what it is to
// somebody holding scissors, so four buttons held a handful each and "Field"
// held the other 219. `MarkShelf` in `Shared/Illumination.swift` replaced it.

struct PagewrightDraft {
    var title: String
    var note: String
    var format: PagewrightFormat
    var template: PagewrightTemplate
    var pages: [BookPage]
    var pullQuotes: [String: String]
    var pinnedNotes: [PagewrightPinnedNote]
    var personalPhotos: [PagewrightPersonalPhoto]
    var elements: [PagewrightCanvasElement]
    var background: PagewrightBackground
    var paperTint: PagewrightPaperTint
    var marginalia: PagewrightMarginaliaStyle
    var marginaliaPackID: String
}

struct PagewrightPersonalPhoto: Identifiable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var data: Data
    /// Width divided by height. The Pagewright uses this to show and export
    /// the complete photograph without cropping it into a preset frame.
    var aspectRatio: CGFloat
}

/// A reader-chosen colour laid beneath a Pagewright paper's neutral material
/// map. Kept as sRGB components so the SwiftUI canvas and UIKit exporters use
/// exactly the same ink decision instead of trying to resolve `Color` twice.
struct PagewrightPaperTint: Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var hexRGB: String {
        String(
            format: "%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    var relativeLuminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(against other: PagewrightPaperTint) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var strongestInk: PagewrightPaperTint {
        // True endpoints guarantee that every opaque sRGB colour has at least
        // one AA text colour, including the difficult middle-luminance band.
        let dark = PagewrightPaperTint(red: 0, green: 0, blue: 0)
        let light = PagewrightPaperTint(red: 1, green: 1, blue: 1)
        return contrastRatio(against: light) > contrastRatio(against: dark) ? light : dark
    }

    /// Makes quieter ink without letting it fall below WCAG AA contrast for
    /// ordinary text. On awkward middle-value colours it stays strong rather
    /// than becoming tasteful and unreadable.
    private func readableInk(preferredStrength: Double) -> PagewrightPaperTint {
        let ink = strongestInk
        func mixed(_ strength: Double) -> PagewrightPaperTint {
            PagewrightPaperTint(
                red: red + (ink.red - red) * strength,
                green: green + (ink.green - green) * strength,
                blue: blue + (ink.blue - blue) * strength
            )
        }

        var low = min(1, max(0, preferredStrength))
        if contrastRatio(against: mixed(low)) >= 4.5 { return mixed(low) }
        var high = 1.0
        for _ in 0..<12 {
            let middle = (low + high) / 2
            if contrastRatio(against: mixed(middle)) >= 4.5 {
                high = middle
            } else {
                low = middle
            }
        }
        return mixed(high)
    }

    var primaryInk: PagewrightPaperTint { readableInk(preferredStrength: 0.92) }
    var secondaryInk: PagewrightPaperTint { readableInk(preferredStrength: 0.68) }

    /// The same teal/gold relationship used throughout the Book, retained only
    /// when it can carry text on this tint. Otherwise the ordinary ink wins.
    var accentInk: PagewrightPaperTint {
        let deepTeal = PagewrightPaperTint(red: 0.055, green: 0.30, blue: 0.31)
        let lampGold = PagewrightPaperTint(red: 1.0, green: 0.84, blue: 0.42)
        let candidates = [deepTeal, lampGold].sorted {
            contrastRatio(against: $0) > contrastRatio(against: $1)
        }
        guard let best = candidates.first,
              contrastRatio(against: best) >= 4.5 else { return primaryInk }
        return best
    }

    #if canImport(UIKit)
    init?(color: Color) {
        let resolved = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
    #endif
}

/// The Book's existing leaf families, reduced to a small sample book. These
/// are starting points, not a gate: the reader can still ask for any colour.
enum PagewrightPaperTintPreset: String, CaseIterable, Identifiable {
    case parchment
    case cottonCream
    case paleTeal
    case moss
    case roseDust
    case moonViolet
    case nightInk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parchment: return "Parchment"
        case .cottonCream: return "Cotton cream"
        case .paleTeal: return "Pale teal"
        case .moss: return "Moss"
        case .roseDust: return "Rose dust"
        case .moonViolet: return "Moon violet"
        case .nightInk: return "Night ink"
        }
    }

    var tint: PagewrightPaperTint {
        switch self {
        case .parchment: return PagewrightPaperTint(red: 0.96, green: 0.90, blue: 0.76)
        case .cottonCream: return PagewrightPaperTint(red: 0.95, green: 0.93, blue: 0.87)
        case .paleTeal: return PagewrightPaperTint(red: 0.77, green: 0.88, blue: 0.84)
        case .moss: return PagewrightPaperTint(red: 0.77, green: 0.82, blue: 0.66)
        case .roseDust: return PagewrightPaperTint(red: 0.89, green: 0.74, blue: 0.72)
        case .moonViolet: return PagewrightPaperTint(red: 0.72, green: 0.69, blue: 0.80)
        case .nightInk: return PagewrightPaperTint(red: 0.09, green: 0.11, blue: 0.16)
        }
    }
}

enum PagewrightBackground: String, CaseIterable, Identifiable {
    case parchment
    case laidCotton
    case ragHandmade
    case vellum
    case archiveFlecked
    case rebelWeathered
    case ledger
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parchment: return "Parchment"
        case .laidCotton: return "Laid Cotton"
        case .ragHandmade: return "Handmade Rag"
        case .vellum: return "Vellum"
        case .archiveFlecked: return "Archive Flecked"
        case .rebelWeathered: return "Weathered"
        case .ledger: return "Ledger"
        case .night: return "Night"
        }
    }

    var symbolName: String {
        switch self {
        case .parchment: return "doc.text"
        case .laidCotton: return "square.grid.3x3"
        case .ragHandmade: return "square.on.square.dashed"
        case .vellum: return "square.dashed"
        case .archiveFlecked: return "circle.grid.cross"
        case .rebelWeathered: return "flame"
        case .ledger: return "list.bullet.rectangle"
        case .night: return "moon.stars"
        }
    }

    /// The stock a Page leaf is printed on, when this paper is one of them.
    ///
    /// The Book already had five real paper textures and Pagewright was mixing
    /// its own out of flat fills and one gradient — so a scrapbook page never
    /// looked like it came out of the same Book as the leaves around it.
    var leafStock: LeafPaperStock? {
        switch self {
        case .laidCotton: return .laidCotton
        case .ragHandmade: return .ragHandmade
        case .vellum: return .vellum
        case .archiveFlecked: return .archiveFlecked
        case .rebelWeathered: return .rebelWeathered
        case .parchment, .ledger, .night: return nil
        }
    }

    var textureAssetName: String? {
        // Parchment keeps its own fibre sheet; it predates the leaf stocks and
        // is the one paper readers already recognise as the Pagewright's.
        if self == .parchment { return "ParchmentFiber" }
        return leafStock?.assetName
    }

    /// Heavier than `LeafPaperStock.baseOpacity`, deliberately. On a leaf the
    /// texture is a whisper under printed prose; here the paper *is* the
    /// subject, and a scrapbook sheet should look like something you could pick
    /// up by one corner.
    var textureOpacity: Double {
        switch self {
        case .parchment: return 0.32
        case .laidCotton: return 0.55
        case .ragHandmade: return 0.60
        case .vellum: return 0.48
        case .archiveFlecked: return 0.58
        case .rebelWeathered: return 0.66
        case .ledger, .night: return 0
        }
    }

    /// The colour this stock starts with before the reader tints it. Material
    /// and colour remain separate: cotton can be parchment today and teal on
    /// the next Page without becoming a second cotton paper type.
    var defaultTint: PagewrightPaperTint {
        switch self {
        case .parchment: return PagewrightPaperTint(red: 0.96, green: 0.93, blue: 0.86)
        case .laidCotton: return PagewrightPaperTint(red: 0.94, green: 0.92, blue: 0.86)
        case .ragHandmade: return PagewrightPaperTint(red: 0.95, green: 0.91, blue: 0.83)
        case .vellum: return PagewrightPaperTint(red: 0.94, green: 0.88, blue: 0.74)
        case .archiveFlecked: return PagewrightPaperTint(red: 0.90, green: 0.88, blue: 0.80)
        case .rebelWeathered: return PagewrightPaperTint(red: 0.87, green: 0.81, blue: 0.70)
        case .ledger: return PagewrightPaperTint(red: 0.89, green: 0.93, blue: 0.87)
        case .night: return PagewrightPaperTint(red: 0.09, green: 0.11, blue: 0.16)
        }
    }

    var swatch: Color {
        defaultTint.color
    }
}

/// One physical edge for the worktable and the artifact that leaves it. The
/// seed belongs to the paper stock, so tinting or typing a title cannot make
/// the sheet twitch into a different cut beneath the reader's hands.
private enum PagewrightPaperDeckle {
    static let amplitudeRatio: CGFloat = 0.006
    static let exportInset: CGFloat = 14

    static func shape(for background: PagewrightBackground, in rect: CGRect) -> DeckledPaperScrapShape {
        DeckledPaperScrapShape(
            seed: "pagewright-paper-\(background.rawValue)".stableHash,
            amplitude: min(rect.width, rect.height) * amplitudeRatio
        )
    }
}

enum PagewrightMarginaliaStyle: String, CaseIterable, Identifiable {
    case pressedFlower
    case waxSeal
    case inkStars
    case tornTape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pressedFlower: return "Pressed flower"
        case .waxSeal: return "Wax seal"
        case .inkStars: return "Ink stars"
        case .tornTape: return "Torn tape"
        }
    }

    var symbolName: String {
        switch self {
        case .pressedFlower: return "leaf"
        case .waxSeal: return "seal"
        case .inkStars: return "sparkles"
        case .tornTape: return "paperclip"
        }
    }
}

enum PagewrightPinnedNoteStyle: String, CaseIterable, Identifiable {
    case margin
    case sticky
    case stamp
    case torn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .margin: return "Margin"
        case .sticky: return "Pinned"
        case .stamp: return "Stamp"
        case .torn: return "Torn"
        }
    }

    var symbolName: String {
        switch self {
        case .margin: return "pencil.and.scribble"
        case .sticky: return "pin"
        case .stamp: return "seal"
        case .torn: return "note.text"
        }
    }
}

struct PagewrightPinnedNote: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var text: String
    var style: PagewrightPinnedNoteStyle
}

struct PagewrightCanvasElement: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case page
        case note
        case personalPhoto
        case marginaliaAsset
    }

    var id: String = UUID().uuidString
    var kind: Kind
    var sourceID: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var rotation: Double
    var z: Int
    var isTextBold: Bool = false
    var isTextItalic: Bool = false
}

private struct PagewrightCachedPage {
    var page: BookPage
    var dayID: String
    var dateLabel: String
    var searchBlob: String
    var firstVisualMediaAsset: BookPageMediaAsset?
    var hasVisualMedia: Bool
    var excerpt42: String
    var excerpt86: String
    var excerpt140: String
    var excerpt1000: String
    var pullQuote: String
    var pullQuoteOptions: [String]

    init(page: BookPage) {
        let visualMedia = page.pagewrightVisualMediaAssets
        let base = PagewrightText.baseText(for: page)
        let excerpt42 = PagewrightText.clipped(base, limit: 42)
        let excerpt86 = PagewrightText.clipped(base, limit: 86)
        let excerpt140 = PagewrightText.clipped(base, limit: 140)
        let excerpt1000 = PagewrightText.clipped(base, limit: 1_000)
        let baseForQuotes = PagewrightText.clipped(base, limit: 1_200)
        let fallbackQuote = PagewrightText.clipped(base, limit: 190)
        let pullQuoteOptions = page.type == .quotes
            ? [base]
            : PagewrightText.pullQuoteOptions(from: baseForQuotes, fallback: fallbackQuote)

        self.page = page
        self.dayID = PagewrightDayBucket.id(for: page.createdAt)
        self.dateLabel = page.createdAt.formatted(date: .abbreviated, time: .omitted)
        self.searchBlob = [
            page.type.title,
            page.promptText,
            page.userInput,
            page.playerReply,
            page.tags.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()
        self.firstVisualMediaAsset = page.pagewrightPreviewImageAsset
        self.hasVisualMedia = !visualMedia.isEmpty
        self.excerpt42 = excerpt42
        self.excerpt86 = excerpt86
        self.excerpt140 = excerpt140
        self.excerpt1000 = excerpt1000
        self.pullQuoteOptions = pullQuoteOptions
        self.pullQuote = pullQuoteOptions.first ?? fallbackQuote
    }

    func excerpt(limit: Int) -> String {
        switch limit {
        case 42: return excerpt42
        case 86: return excerpt86
        case 140: return excerpt140
        case 1_000: return excerpt1000
        default: return PagewrightText.excerpt(for: page, limit: limit)
        }
    }
}

private struct PagewrightPageCache {
    static let empty = PagewrightPageCache()

    var pageIDs: [String] = []
    var pages: [BookPage] = []
    var pagesByID: [String: BookPage] = [:]
    var cachedPagesByID: [String: PagewrightCachedPage] = [:]
    var buckets: [PagewrightDayBucket] = []

    init() {}

    init(pages: [BookPage]) {
        self.pageIDs = pages.map(\.id)
        self.pages = pages
        self.pagesByID = Dictionary(pages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.cachedPagesByID = Dictionary(pages.map { ($0.id, PagewrightCachedPage(page: $0)) }, uniquingKeysWith: { first, _ in first })
        self.buckets = PagewrightDayBucket.make(from: pages)
    }

    func page(for id: String) -> BookPage? {
        pagesByID[id]
    }

    func cached(for id: String) -> PagewrightCachedPage? {
        cachedPagesByID[id]
    }

    func cached(for page: BookPage) -> PagewrightCachedPage {
        cachedPagesByID[page.id] ?? PagewrightCachedPage(page: page)
    }
}

/// The cabinet, filed by shelf, held for the life of one Pagewright session.
///
/// The old cache keyed six hardcoded (kind, tags) requests and answered them
/// with `prefix(count)`. That is where 139 marks went: they were in the pack,
/// they had achievements, and no request ever reached them. This one holds
/// every unlocked mark on the shelf it belongs to, with no cap, because the
/// shelves are what make a cap unnecessary.
private struct PagewrightMarkCabinet {
    static let empty = PagewrightMarkCabinet()

    var contextKey: String = ""
    var marksByShelf: [MarkShelf: [IlluminationPackRegistry.ShelvedMark]] = [:]
    var assetsByName: [String: IlluminationAsset] = [:]
    var shelves: [MarkShelf] = []
    var drawer: [IlluminationPackRegistry.ShelvedMark] = []

    init() {}

    init(
        context: IlluminationPlacementContext,
        day: Date = Date(),
        isUnlocked: ((IlluminationAsset) -> Bool)? = nil
    ) {
        self.contextKey = Self.key(for: context)

        let all = IlluminationPackRegistry.shelvedMarks(context: context)
        var byShelf: [MarkShelf: [IlluminationPackRegistry.ShelvedMark]] = [:]
        var byName: [String: IlluminationAsset] = [:]
        for mark in all {
            byShelf[mark.shelf, default: []].append(mark)
            if byName[mark.asset.assetName] == nil {
                byName[mark.asset.assetName] = mark.asset
            }
        }
        self.marksByShelf = byShelf
        self.assetsByName = byName
        self.drawer = IlluminationPackRegistry.drawerMarks(
            on: day,
            context: context,
            isUsable: isUnlocked
        )
        self.shelves = IlluminationPackRegistry.populatedShelves(context: context)
    }

    func marks(on shelf: MarkShelf) -> [IlluminationPackRegistry.ShelvedMark] {
        shelf == .theDrawer ? drawer : (marksByShelf[shelf] ?? [])
    }

    func count(on shelf: MarkShelf) -> Int {
        marks(on: shelf).count
    }

    func asset(named name: String) -> IlluminationAsset? {
        assetsByName[name]
    }

    func matches(_ context: IlluminationPlacementContext) -> Bool {
        contextKey == Self.key(for: context)
    }

    /// The drawer turns over daily and This Month turns over when a phase
    /// does, so the cache is keyed to both rather than rebuilt on every draw.
    private static func key(for context: IlluminationPlacementContext) -> String {
        [
            "\(context.month ?? 0)",
            context.activeWorldEventIDs.sorted().joined(separator: ","),
            context.worldEventPhases.sorted().joined(separator: ",")
        ].joined(separator: "§")
    }
}

enum PagewrightTemplate: String, CaseIterable, Identifiable {
    case memoryWall
    case polaroidScatter
    case letterHome
    case fieldNotes
    case weeklyShrine
    case softChaos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memoryWall: return "Memory Wall"
        case .polaroidScatter: return "Photo Scatter"
        case .letterHome: return "Letter Home"
        case .fieldNotes: return "Field Notes"
        case .weeklyShrine: return "Weekly Shrine"
        case .softChaos: return "Soft Chaos"
        }
    }

    var detail: String {
        switch self {
        case .memoryWall: return "Balanced scraps with room for one quiet margin note."
        case .polaroidScatter: return "Image-forward, tilted, playful."
        case .letterHome: return "A composed note with evidence tucked around it."
        case .fieldNotes: return "Ledger lines, labels, and careful fragments."
        case .weeklyShrine: return "A small altar for a week that mattered."
        case .softChaos: return "Loose, layered, expressive."
        }
    }

    var symbolName: String {
        switch self {
        case .memoryWall: return "rectangle.grid.2x2"
        case .polaroidScatter: return "photo.stack"
        case .letterHome: return "envelope.open"
        case .fieldNotes: return "list.bullet.rectangle"
        case .weeklyShrine: return "sparkles.rectangle.stack"
        case .softChaos: return "scribble.variable"
        }
    }

    var background: PagewrightBackground {
        switch self {
        case .memoryWall, .polaroidScatter, .softChaos: return .parchment
        case .letterHome: return .vellum
        case .fieldNotes: return .ledger
        case .weeklyShrine: return .night
        }
    }

    var marginalia: PagewrightMarginaliaStyle {
        switch self {
        case .memoryWall, .letterHome: return .pressedFlower
        case .polaroidScatter, .softChaos: return .tornTape
        case .fieldNotes: return .inkStars
        case .weeklyShrine: return .waxSeal
        }
    }

    var format: PagewrightFormat {
        switch self {
        case .memoryWall, .polaroidScatter, .softChaos: return .scrapPage
        case .letterHome: return .letterPacket
        case .fieldNotes, .weeklyShrine: return .miniIssue
        }
    }

    var defaultPageCount: Int {
        switch self {
        case .memoryWall, .polaroidScatter, .softChaos: return 3
        case .letterHome: return 4
        case .fieldNotes: return 6
        case .weeklyShrine: return 7
        }
    }

    func placement(for index: Int, kind: PagewrightCanvasElement.Kind) -> (x: CGFloat, y: CGFloat, width: CGFloat, rotation: Double) {
        if kind == .note {
            switch self {
            case .memoryWall: return (0.74, 0.76, 0.26, -2)
            case .polaroidScatter: return (0.28, 0.76, 0.24, 4)
            case .letterHome: return (0.50, 0.30, 0.46, 0)
            case .fieldNotes: return (0.76, 0.30, 0.24, 0)
            case .weeklyShrine: return (0.50, 0.82, 0.34, 0)
            case .softChaos: return (0.70, 0.24, 0.28, -6)
            }
        }

        let placements: [(CGFloat, CGFloat, CGFloat, Double)]
        switch self {
        case .memoryWall:
            placements = [(0.34, 0.34, 0.36, -3), (0.66, 0.42, 0.34, 2), (0.42, 0.66, 0.38, -1), (0.68, 0.68, 0.28, 3)]
        case .polaroidScatter:
            placements = [(0.36, 0.34, 0.40, -8), (0.64, 0.46, 0.36, 7), (0.42, 0.68, 0.34, -4), (0.72, 0.70, 0.26, 8)]
        case .letterHome:
            placements = [(0.30, 0.56, 0.30, -2), (0.70, 0.56, 0.30, 2), (0.42, 0.78, 0.28, -1), (0.68, 0.78, 0.28, 1)]
        case .fieldNotes:
            placements = [(0.30, 0.30, 0.30, 0), (0.30, 0.54, 0.30, 0), (0.30, 0.78, 0.30, 0), (0.66, 0.36, 0.32, 0), (0.66, 0.64, 0.32, 0), (0.66, 0.84, 0.28, 0)]
        case .weeklyShrine:
            placements = [(0.50, 0.34, 0.44, 0), (0.30, 0.58, 0.30, -4), (0.70, 0.58, 0.30, 4), (0.34, 0.76, 0.26, 2), (0.66, 0.76, 0.26, -2)]
        case .softChaos:
            placements = [(0.38, 0.36, 0.42, -10), (0.66, 0.42, 0.34, 8), (0.42, 0.68, 0.36, 5), (0.70, 0.72, 0.28, -7)]
        }
        return placements[index % placements.count]
    }
}

struct BookwideMarginaliaAchievement {
    enum Track: String, Equatable {
        case livingWonder
        case bookcraftApprenticeship

        var title: String {
            switch self {
            case .livingWonder: return "Living Wonder"
            case .bookcraftApprenticeship: return "Bookcraft"
            }
        }

        var shortTitle: String {
            switch self {
            case .livingWonder: return "Living Wonder"
            case .bookcraftApprenticeship: return "Bookcraft"
            }
        }

        var announcementLabel: String {
            switch self {
            case .livingWonder: return "LIVING WONDER FOUND"
            case .bookcraftApprenticeship: return "BOOKCRAFT FOUND"
            }
        }
    }

    enum ReaderProofKind: String, Equatable {
        case words
        case photograph
        case voice
        case place
        case weather

        var title: String {
            switch self {
            case .words: return "words"
            case .photograph: return "photograph"
            case .voice: return "voice"
            case .place: return "place"
            case .weather: return "weather"
            }
        }
    }

    indirect enum Trigger {
        case keptPages(Int)
        case keptPageType(BookPageType, Int)
        case keptPageTypeAcrossDays(BookPageType, count: Int, distinctDays: Int)
        case distinctKeptPageTypes(Int)
        case distinctKeptDays(Int)
        case keptInWeather(tags: Set<String>?, count: Int)
        case keptInWeatherAcrossDays(tags: Set<String>?, count: Int, distinctDays: Int)
        case keptAtNight(Int)
        case keptAtNightAcrossDays(count: Int, distinctDays: Int)
        case keptVisualPages(Int)
        case readerProofPages(kinds: [ReaderProofKind], count: Int, distinctDays: Int)
        case distinctReaderProofKinds(Int)
        case sensoryModalities(Int)
        case livedQuestReceipts(
            kinds: [LivedQuestKind]?,
            facets: [LivedWonderFacet]?,
            count: Int,
            distinctDays: Int
        )
        case multimodalLivedQuestReceipts(Int)
        case distinctLivedWonderFacets(Int)
        case longGameEvidence(
            capacity: BookLongGameCapacity?,
            kinds: [BookLongGameEvidenceKind]?,
            count: Int,
            distinctDays: Int,
            unpromptedOnly: Bool
        )
        case distinctLongGameCapacities(Int, unpromptedOnly: Bool)
        case anchorsCreated(Int)
        case distinctAnchorKinds(Int)
        case anchorVisits(Int)
        case shadowWonder
        case completedBookJumps(Int)
        case completedCompassRuns(Int)
        case completedElectives(Int)
        case chosenQuill
        case all([Trigger])

        func isComplete(in context: Context) -> Bool {
            switch self {
            case .keptPages(let count):
                return context.pages.count >= count
            case .keptPageType(let type, let count):
                return context.pages.filter { $0.type == type }.count >= count
            case .keptPageTypeAcrossDays(let type, let count, let distinctDays):
                let matching = context.readerEvidencePages.filter { $0.type == type }
                return matching.count >= count
                    && Set(matching.map { BookDay.id(for: $0.createdAt) }).count >= distinctDays
            case .distinctKeptPageTypes(let count):
                return Set(context.pages.map(\.type)).count >= count
            case .distinctKeptDays(let count):
                return context.keptDayIDs.count >= count
            case .keptInWeather(let tags, let count):
                return context.weatherKeptCount(tags: tags) >= count
            case .keptInWeatherAcrossDays(let tags, let count, let distinctDays):
                let matching = context.weatherKeptPages(tags: tags)
                return matching.count >= count
                    && Set(matching.map { BookDay.id(for: $0.createdAt) }).count >= distinctDays
            case .keptAtNight(let count):
                return context.readerEvidencePages.filter { $0.context?.dayPart == "night" }.count >= count
            case .keptAtNightAcrossDays(let count, let distinctDays):
                let matching = context.readerEvidencePages.filter { $0.context?.dayPart == "night" }
                return matching.count >= count
                    && Set(matching.map { BookDay.id(for: $0.createdAt) }).count >= distinctDays
            case .keptVisualPages(let count):
                return context.pages.filter(\.hasMarginaliaAchievementVisual).count >= count
            case .readerProofPages(let kinds, let count, let distinctDays):
                let matching = context.readerProofPages(matchingAny: kinds)
                return matching.count >= count
                    && Set(matching.map { BookDay.id(for: $0.createdAt) }).count >= distinctDays
            case .distinctReaderProofKinds(let count):
                return context.distinctReaderProofKindRawValues.count >= count
            case .sensoryModalities(let count):
                return context.sensoryModalities.count >= count
            case .livedQuestReceipts(let kinds, let facets, let count, let distinctDays):
                let matching = context.livedQuestReceipts(kinds: kinds, facets: facets)
                return matching.count >= count
                    && Set(matching.map { BookDay.id(for: $0.completedAt) }).count >= distinctDays
            case .multimodalLivedQuestReceipts(let count):
                return context.livedQuestReceipts
                    .filter { $0.hasWrittenProof && $0.hasVisualProof }
                    .count >= count
            case .distinctLivedWonderFacets(let count):
                return context.distinctLivedWonderFacetRawValues.count >= count
            case .longGameEvidence(let capacity, let kinds, let count, let distinctDays, let unpromptedOnly):
                let matching = context.matchingLongGameEvidence(
                    capacity: capacity,
                    kinds: kinds,
                    unpromptedOnly: unpromptedOnly
                )
                return matching.count >= count
                    && Set(matching.map { BookDay.id(for: $0.happenedAt) }).count >= distinctDays
            case .distinctLongGameCapacities(let count, let unpromptedOnly):
                let matching = context.matchingLongGameEvidence(
                    capacity: nil,
                    kinds: nil,
                    unpromptedOnly: unpromptedOnly
                )
                return Set(matching.map { $0.capacity.rawValue }).count >= count
            case .anchorsCreated(let count):
                return context.readerAnchors.count >= count
            case .distinctAnchorKinds(let count):
                return Set(context.readerAnchors.map(\.kind)).count >= count
            case .anchorVisits(let count):
                return context.readerAnchors.reduce(0) { $0 + $1.visitCount } >= count
            case .shadowWonder:
                return (context.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] ?? 0) > 0
            case .completedBookJumps(let count):
                return context.completedBookJumps >= count
            case .completedCompassRuns(let count):
                return context.completedCompassRuns >= count
            case .completedElectives(let count):
                return context.completedElectives >= count
            case .chosenQuill:
                return context.hasChosenQuill
            case .all(let triggers):
                return triggers.allSatisfy { $0.isComplete(in: context) }
            }
        }

        func progress(in context: Context) -> String {
            switch self {
            case .keptPages(let count):
                return "I have \(min(context.pages.count, count)) of \(count) kept Pages"
            case .keptPageType(let type, let count):
                let current = context.pages.filter { $0.type == type }.count
                return "I have \(min(current, count)) of \(count) \(type.shortTitle) Pages"
            case .keptPageTypeAcrossDays(let type, let count, let distinctDays):
                let matching = context.readerEvidencePages.filter { $0.type == type }
                let days = Set(matching.map { BookDay.id(for: $0.createdAt) }).count
                return "I have \(min(matching.count, count)) of \(count) \(type.shortTitle) Pages across \(min(days, distinctDays)) of \(distinctDays) days"
            case .distinctKeptPageTypes(let count):
                let current = Set(context.pages.map(\.type)).count
                return "I have \(min(current, count)) of \(count) kinds of Page"
            case .distinctKeptDays(let count):
                return "I have Pages from \(min(context.keptDayIDs.count, count)) of \(count) days"
            case .keptInWeather(let tags, let count):
                let current = context.weatherKeptCount(tags: tags)
                let label = tags?.sorted().joined(separator: " or ") ?? "recorded weather"
                return "I have \(min(current, count)) of \(count) Pages kept in \(label)"
            case .keptInWeatherAcrossDays(let tags, let count, let distinctDays):
                let matching = context.weatherKeptPages(tags: tags)
                let days = Set(matching.map { BookDay.id(for: $0.createdAt) }).count
                let label = tags?.sorted().joined(separator: " or ") ?? "recorded weather"
                return "I have \(min(matching.count, count)) of \(count) Pages kept in \(label) across \(min(days, distinctDays)) of \(distinctDays) days"
            case .keptAtNight(let count):
                let current = context.readerEvidencePages.filter { $0.context?.dayPart == "night" }.count
                return "I have \(min(current, count)) of \(count) night Pages"
            case .keptAtNightAcrossDays(let count, let distinctDays):
                let matching = context.readerEvidencePages.filter { $0.context?.dayPart == "night" }
                let days = Set(matching.map { BookDay.id(for: $0.createdAt) }).count
                return "I have \(min(matching.count, count)) of \(count) night Pages across \(min(days, distinctDays)) of \(distinctDays) nights"
            case .keptVisualPages(let count):
                let current = context.pages.filter(\.hasMarginaliaAchievementVisual).count
                return "I have \(min(current, count)) of \(count) Pages with something visible"
            case .readerProofPages(let kinds, let count, let distinctDays):
                let matching = context.readerProofPages(matchingAny: kinds)
                let days = Set(matching.map { BookDay.id(for: $0.createdAt) }).count
                let label = kinds.map(\.title).joined(separator: " or ")
                return "I have \(min(matching.count, count)) of \(count) \(label) receipts across \(min(days, distinctDays)) of \(distinctDays) days"
            case .distinctReaderProofKinds(let count):
                let current = context.distinctReaderProofKindRawValues.count
                return "I have \(min(current, count)) of \(count) kinds of proof"
            case .sensoryModalities(let count):
                return "I have \(min(context.sensoryModalities.count, count)) of \(count) ways of noticing"
            case .livedQuestReceipts(let kinds, let facets, let count, let distinctDays):
                let matching = context.livedQuestReceipts(kinds: kinds, facets: facets)
                let days = Set(matching.map { BookDay.id(for: $0.completedAt) }).count
                return "I have \(min(matching.count, count)) of \(count) lived receipts across \(min(days, distinctDays)) of \(distinctDays) days"
            case .multimodalLivedQuestReceipts(let count):
                let current = context.livedQuestReceipts
                    .filter { $0.hasWrittenProof && $0.hasVisualProof }
                    .count
                return "I have \(min(current, count)) of \(count) receipts with words and a picture"
            case .distinctLivedWonderFacets(let count):
                let current = context.distinctLivedWonderFacetRawValues.count
                return "I have \(min(current, count)) of \(count) kinds of lived wonder"
            case .longGameEvidence(let capacity, let kinds, let count, let distinctDays, let unpromptedOnly):
                let matching = context.matchingLongGameEvidence(
                    capacity: capacity,
                    kinds: kinds,
                    unpromptedOnly: unpromptedOnly
                )
                let days = Set(matching.map { BookDay.id(for: $0.happenedAt) }).count
                let label = capacity?.title.lowercased() ?? "lived wonder"
                return "I have \(min(matching.count, count)) of \(count) \(label) receipts across \(min(days, distinctDays)) of \(distinctDays) days"
            case .distinctLongGameCapacities(let count, let unpromptedOnly):
                let matching = context.matchingLongGameEvidence(
                    capacity: nil,
                    kinds: nil,
                    unpromptedOnly: unpromptedOnly
                )
                let current = Set(matching.map { $0.capacity.rawValue }).count
                return "I have \(min(current, count)) of \(count) kinds of lived change"
            case .anchorsCreated(let count):
                return "I have \(min(context.readerAnchors.count, count)) of \(count) Anchors"
            case .distinctAnchorKinds(let count):
                let current = Set(context.readerAnchors.map(\.kind)).count
                return "I have \(min(current, count)) of \(count) kinds of Anchor"
            case .anchorVisits(let count):
                let current = context.readerAnchors.reduce(0) { $0 + $1.visitCount }
                return "I have \(min(current, count)) of \(count) Anchor visits"
            case .shadowWonder:
                return isComplete(in: context) ? "The Dusk Thorn is awake" : "The Dusk Thorn is still curled up"
            case .completedBookJumps(let count):
                return "I have \(min(context.completedBookJumps, count)) of \(count) returned Book Jumps"
            case .completedCompassRuns(let count):
                return "I have \(min(context.completedCompassRuns, count)) of \(count) Compass runs"
            case .completedElectives(let count):
                return "I have \(min(context.completedElectives, count)) of \(count) finished Electives"
            case .chosenQuill:
                return context.hasChosenQuill ? "The quill chose too" : "The quills are still watching"
            case .all(let triggers):
                return triggers.map { $0.progress(in: context) }.joined(separator: " · ")
            }
        }
    }

    struct Context {
        var pages: [BookPage]
        var anchors: [AnchorRecord]
        var entityBeliefOffsets: [String: Int]
        var completedBookJumps: Int
        var completedCompassRuns: Int
        var electives: [UnwrittenElective]
        var longGameEvidence: [BookLongGameEvidence]
        var hasChosenQuill: Bool

        var keptDayIDs: Set<String> {
            Set(pages.map { BookDay.id(for: $0.createdAt) })
        }

        var readerEvidencePages: [BookPage] {
            pages.filter { hasReaderEvidence($0) }
        }

        var completedElectives: Int {
            electives.filter { $0.completedAt != nil }.count
        }

        var readerAnchors: [AnchorRecord] {
            anchors.filter { $0.id.hasPrefix("user-anchor-") }
        }

        var livedQuestReceipts: [LivedQuestReceipt] {
            var byQuest: [String: LivedQuestReceipt] = [:]
            for receipt in pages.compactMap(\.attributableLivedQuestReceipt)
            where receipt.hasWrittenProof || receipt.hasVisualProof {
                let key = "\(receipt.kind.rawValue)|\(receipt.questID)"
                if let current = byQuest[key], current.completedAt >= receipt.completedAt {
                    continue
                }
                byQuest[key] = receipt
            }
            return byQuest.values.sorted { $0.completedAt < $1.completedAt }
        }

        var distinctLivedWonderFacetRawValues: Set<String> {
            Set(livedQuestReceipts.flatMap(\.facets).map(\.rawValue))
        }

        var sensoryModalities: Set<String> {
            Set(pages
                .filter { $0.origin == .userAuthored || $0.origin == .imported }
                .flatMap { $0.resolvedSensoryFolio.modalities })
        }

        var distinctReaderProofKindRawValues: Set<String> {
            var values = Set(pages.flatMap { readerProofKinds(for: $0) }.map(\.rawValue))
            for elective in electives where elective.completedAt != nil {
                if elective.proof?.nonEmpty != nil { values.insert(ReaderProofKind.words.rawValue) }
                if elective.proofPhotoURL?.nonEmpty != nil { values.insert(ReaderProofKind.photograph.rawValue) }
                if elective.proofLocationSummary?.nonEmpty != nil { values.insert(ReaderProofKind.place.rawValue) }
            }
            return values
        }

        func livedQuestReceipts(
            kinds: [LivedQuestKind]?,
            facets: [LivedWonderFacet]?
        ) -> [LivedQuestReceipt] {
            livedQuestReceipts.filter { receipt in
                let matchesKind = kinds?.contains(receipt.kind) ?? true
                let matchesFacet = facets.map { wanted in
                    receipt.facets.contains { wanted.contains($0) }
                } ?? true
                return matchesKind && matchesFacet
            }
        }

        func matchingLongGameEvidence(
            capacity: BookLongGameCapacity?,
            kinds: [BookLongGameEvidenceKind]?,
            unpromptedOnly: Bool
        ) -> [BookLongGameEvidence] {
            longGameEvidence.filter { receipt in
                (capacity.map { receipt.capacity == $0 } ?? true)
                    && (kinds?.contains(receipt.kind) ?? true)
                    && (!unpromptedOnly || !receipt.wasPromptedByBook)
            }
        }

        func readerProofPages(matchingAny kinds: [ReaderProofKind]) -> [BookPage] {
            pages.filter { page in
                let proofKinds = readerProofKinds(for: page)
                return kinds.isEmpty
                    ? !proofKinds.isEmpty
                    : proofKinds.contains { kinds.contains($0) }
            }
        }

        private func readerProofKinds(for page: BookPage) -> [ReaderProofKind] {
            guard page.origin == .userAuthored || page.origin == .imported else { return [] }
            var kinds: [ReaderProofKind] = []

            func append(_ kind: ReaderProofKind) {
                guard !kinds.contains(kind) else { return }
                kinds.append(kind)
            }

            if page.userInput.nonEmpty != nil || page.playerReply.nonEmpty != nil {
                append(.words)
            }
            for asset in page.mediaAssets {
                switch asset.kind {
                case .photoLibraryAsset:
                    append(.photograph)
                case .renderedImageFile:
                    if asset.metadata["proofPhoto"] == "true"
                        || asset.metadata["uneditedPhoto"] == "true"
                        || asset.metadata["proofImagePath"]?.nonEmpty != nil {
                        append(.photograph)
                    }
                case .audioFile:
                    append(.voice)
                case .bundledImage:
                    break
                }
            }
            if page.context?.nearbyAnchorID?.nonEmpty != nil
                || page.context?.locationLabel?.nonEmpty != nil
                || page.type == .location
                || page.type == .anchor {
                append(.place)
            }
            if !(page.context?.weatherTags ?? []).isEmpty || page.type == .weather {
                append(.weather)
            }
            return kinds
        }

        func weatherKeptPages(tags: Set<String>?) -> [BookPage] {
            readerEvidencePages.filter { page in
                let pageTags = Set(page.context?.weatherTags ?? [])
                if let tags {
                    return !pageTags.isDisjoint(with: tags)
                }
                return page.type == .weather || !pageTags.isEmpty
            }
        }

        func weatherKeptCount(tags: Set<String>?) -> Int {
            weatherKeptPages(tags: tags).count
        }

        private func hasReaderEvidence(_ page: BookPage) -> Bool {
            page.hasReaderContribution
        }
    }

    var id: String
    var name: String
    var riddle: String
    var hint: String
    var trigger: Trigger
    var rewardAssetIDs: [String]
    var track: Track

    func isComplete(in context: Context) -> Bool {
        trigger.isComplete(in: context)
    }

    func progress(in context: Context) -> String {
        trigger.progress(in: context)
    }

    static func achievement(id: String) -> BookwideMarginaliaAchievement? {
        all.first { $0.id == id }
    }

    static func rewarding(assetID: String) -> BookwideMarginaliaAchievement? {
        rewardIndex[assetID]
    }

    private static let rewardIndex: [String: BookwideMarginaliaAchievement] = {
        Dictionary(
            all.flatMap { achievement in
                achievement.rewardAssetIDs.map { ($0, achievement) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    static let all: [BookwideMarginaliaAchievement] = catalog([
        achievement(
            "first-margin", "My First Loose Mark",
            "Keep one Page. That is enough to make my margins start scratching at the lock.",
            "Keep one Page anywhere in me.",
            .keptPages(1),
            ["illumination_paper_deckled", "illumination_reported_small"],
            track: .bookcraftApprenticeship
        ),
        achievement(
            "shelf-begun", "Three Different Doors",
            "Try three kinds of Page. I want to see where their doors go.",
            "Keep three different kinds of Page.",
            .distinctKeptPageTypes(3),
            ["illumination_blank_summary", "tape_01"],
            track: .bookcraftApprenticeship
        ),
        achievement(
            "archive-stirs", "Dirt in the Archive",
            "Three things I asked for came back from outside with dirt on them. Good. Paper needs dirt sometimes.",
            "Finish three things I asked you to do outside my covers. Bring proof back on two days, from two different kinds of wonder.",
            .all([
                .livedQuestReceipts(kinds: nil, facets: nil, count: 3, distinctDays: 2),
                .distinctLivedWonderFacets(2)
            ]),
            ["illumination_library_acquired", "illumination_edge_remembers"]
        ),
        achievement(
            "hundred-leaves", "The Whole House Answered",
            "All seven doors have opened: attention, otherness, freedom, invention, language, company, and return.",
            "Across seven days, bring back twelve real things touching all seven doors: attention, otherness, freedom, invention, language, company, and return.",
            .all([
                .distinctLongGameCapacities(7, unpromptedOnly: false),
                .longGameEvidence(
                    capacity: nil,
                    kinds: nil,
                    count: 12,
                    distinctDays: 7,
                    unpromptedOnly: false
                )
            ]),
            ["illumination_archive_quiet", "illumination_margins_speak", "overlay_speckles_01"]
        ),
        achievement(
            "first-souvenir", "One Sentence Came Home",
            "One true sentence grabbed the day by its handle and brought it in.",
            "Write and keep one One-Sentence Souvenir from a real day.",
            .keptPageTypeAcrossDays(.souvenir, count: 1, distinctDays: 1),
            ["illumination_small_astonishments"]
        ),
        achievement(
            "five-souvenirs", "A Word Only You Use",
            "You named one bit of the world in your own way. Now I know the word too.",
            "Use a private definition, true name, or phrase you made, then bring back proof that it lived outside my covers.",
            .longGameEvidence(
                capacity: .personalLanguage,
                kinds: nil,
                count: 1,
                distinctDays: 1,
                unpromptedOnly: false
            ),
            ["illumination_witness_ordinary", "illumination_ordinary_wonder"]
        ),
        achievement(
            "twelve-souvenirs", "Three Ways In",
            "Words found one door. Two other senses found doors the words missed.",
            "Keep your own evidence in three different ways, such as words, photograph, voice, place, or weather.",
            .sensoryModalities(3),
            ["illumination_passage_ticket", "illumination_unannounced", "illumination_thyme_stamp"]
        ),
        achievement(
            "weather-witness", "The Sky Signed It",
            "The sky put its wet or bright thumb on one of your Pages.",
            "Keep one Page with real weather recorded on it.",
            .keptInWeather(tags: nil, count: 1),
            ["illumination_weather_cabinet", "illumination_blank_field"]
        ),
        achievement(
            "weather-ledger", "Three Sky Marks",
            "The sky touched three Pages on three different days. I can see the pattern now.",
            "Keep three Pages with real weather recorded on three different days.",
            .keptInWeatherAcrossDays(tags: nil, count: 3, distinctDays: 3),
            ["illumination_field_note_harbor", "illumination_observation_small"]
        ),
        achievement(
            "rain-kept", "Rain Got In",
            "Rain was happening. You opened me anyway, and some of it got into the ink.",
            "Keep one Page while the recorded weather includes rain.",
            .keptInWeather(tags: ["rain"], count: 1),
            ["illumination_rain_collected", "illumination_lighthouse_01"]
        ),
        achievement(
            "storm-lantern", "Lamp in a Storm",
            "A storm crossed the Page. The little lamp stayed lit.",
            "Keep one Page while the recorded weather includes a storm.",
            .keptInWeather(tags: ["storm"], count: 1),
            ["illumination_lighthouse_02", "overlay_edge_vignette_01"]
        ),
        achievement(
            "snowbound-margin", "Snow in the Margin",
            "Snow made everything quiet. One Page still made a noise.",
            "Keep one Page while the recorded weather includes snow or ice.",
            .keptInWeather(tags: ["snow"], count: 1),
            ["illumination_paper_moth", "illumination_pale_feather"]
        ),
        achievement(
            "fog-archive", "I Kept the Fog",
            "The world hid its edges. You let it stay hidden and kept a Page anyway.",
            "Keep one Page while the recorded weather includes fog.",
            .keptInWeather(tags: ["fog"], count: 1),
            ["illumination_borrowed_hush", "illumination_moon_strip"]
        ),
        achievement(
            "wind-written", "Wind in the Ink",
            "The wind shoved the day sideways. Some of it stuck to the Page.",
            "Keep one Page while the recorded weather includes wind.",
            .keptInWeather(tags: ["wind"], count: 1),
            ["illumination_windy_tag"]
        ),
        achievement(
            "bright-weather", "Three Bright Days",
            "The world had its lamps on three times, and each time you kept something.",
            "Keep three Pages on different days while the recorded weather is bright.",
            .keptInWeatherAcrossDays(tags: ["bright"], count: 3, distinctDays: 3),
            ["illumination_pressed_fern", "illumination_lamp_remembered"]
        ),
        achievement(
            "night-keeper", "Three Night Pages",
            "Three Pages heard what your attention sounds like after dark.",
            "Keep three Pages on three different nights.",
            .keptAtNightAcrossDays(count: 3, distinctDays: 3),
            ["illumination_moon_row", "illumination_starlight"]
        ),
        achievement(
            "first-anchor", "You Made a Door",
            "You stood in a real place and taught my Outer Stacks a room that wasn't there before.",
            "Make your first Anchor.",
            .anchorsCreated(1),
            ["doodle_anchor_01", "illumination_map_unseen"]
        ),
        achievement(
            "three-anchors", "Three Places You Made",
            "Three real places are holding doors for you now. That is enough to start a map.",
            "Make three Anchors.",
            .anchorsCreated(3),
            ["illumination_compass_reminder", "illumination_astrolabe_stamp"]
        ),
        achievement(
            "three-anchor-kinds", "Three Kinds of Place",
            "Three different kinds of place have rooms in me now. They don't all behave the same.",
            "Make Anchors of three different kinds.",
            .distinctAnchorKinds(3),
            ["doodle_sailboat_01", "doodle_compass_01", "illumination_kept_tide"]
        ),
        achievement(
            "anchor-returner", "It Knew You Came Back",
            "You came back to made places five times. Their doors know your hand now.",
            "Visit your Anchors five times in all.",
            .anchorVisits(5),
            ["illumination_patient_day", "illumination_map_fragment"]
        ),
        achievement(
            "shadow-wonder", "The Thorn Saw Something Else",
            "You fed the Dusk Thorn. Then you noticed something strange that did not need to be about you.",
            "Raise the Dusk Thorn above zero Belief. Then bring back proof that you noticed something strange which was not about you.",
            .all([
                .shadowWonder,
                .longGameEvidence(
                    capacity: .worldOtherness,
                    kinds: nil,
                    count: 1,
                    distinctDays: 1,
                    unpromptedOnly: false
                )
            ]),
            ["illumination_belief_margin", "illumination_moon_marker", "illumination_brown_feather"]
        ),
        achievement(
            "rest-five", "You Broke a Bad Rule",
            "An old rule expected you to be useful. You left it outside and did something kinder instead.",
            "Bring back proof that you ignored an old rule or made a kinder rule of your own.",
            .longGameEvidence(
                capacity: .scriptFreedom,
                kinds: nil,
                count: 1,
                distinctDays: 1,
                unpromptedOnly: false
            ),
            ["illumination_quiet_pages", "illumination_moss_return"]
        ),
        achievement(
            "visible-proof", "Words and Light",
            "The same real thing came home in your words and in a picture. I can hold both.",
            "Complete one lived quest with written proof and visual proof.",
            .multimodalLivedQuestReceipts(1),
            ["illumination_frame_attention", "illumination_ink_proof"]
        ),
        achievement(
            "first-book-jump", "Back Through the Spine",
            "You went into an old story and came back through my spine with one true thing.",
            "Complete one Book Jump and bring back a souvenir.",
            .completedBookJumps(1),
            ["illumination_moth_ticket"],
            track: .bookcraftApprenticeship
        ),
        achievement(
            "three-book-jumps", "A Door You Made",
            "I didn't give you this door. You made it, opened it, and brought back the hinge.",
            "Without waiting for me to ask, make a ritual, detour, quest, or bit of magic and bring back proof.",
            .longGameEvidence(
                capacity: .selfAuthoredAction,
                kinds: nil,
                count: 1,
                distinctDays: 1,
                unpromptedOnly: true
            ),
            ["illumination_wander_record", "illumination_dreams_ticket"]
        ),
        achievement(
            "first-compass-run", "The Compass Went All the Way",
            "Notice, embark, sense, write, rest. The needle made the whole journey once.",
            "Complete one Wonder Compass run.",
            .completedCompassRuns(1),
            ["illumination_paper_compass"]
        ),
        achievement(
            "three-compass-runs", "The Needle Knows You",
            "You followed it three times. The Compass doesn't think you're a tourist now.",
            "Complete three Wonder Compass runs.",
            .completedCompassRuns(3),
            ["stamp_west_write"]
        ),
        achievement(
            "chosen-quill", "The Quill Chose Too",
            "You chose a quill. It wriggled and chose you back.",
            "Finish the Pen Choosing and keep your quill.",
            .chosenQuill,
            ["illumination_inkwell", "illumination_script_strip"],
            track: .bookcraftApprenticeship
        ),
        achievement(
            "first-elective", "Proof from Outside",
            "Someone inside me asked for something from the real world. You went out and brought it back.",
            "Finish one Unwritten Elective.",
            .completedElectives(1),
            ["illumination_clover_tag", "illumination_lavender_stamp"]
        ),
        achievement(
            "three-tarot-readings", "The Cards Answered Once",
            "The cards asked their questions once. They did not pretend to be a verdict.",
            "Keep one Tarot reading.",
            .keptPageType(.tarot, 1),
            ["illumination_constellation", "illumination_luna_moth"],
            track: .bookcraftApprenticeship
        ),
        achievement(
            "three-letters", "Wonder Found Company",
            "You passed a small wonder to somebody else. It came back bigger, but not louder.",
            "Bring back proof that you shared wonder, witnessed another life, or made a true connection.",
            .longGameEvidence(
                capacity: .livingConnection,
                kinds: nil,
                count: 1,
                distinctDays: 1,
                unpromptedOnly: false
            ),
            ["illumination_letters_margins", "illumination_daylight_missed"]
        ),
        achievement(
            "three-plain-pages", "You Opened Me First",
            "On three different days, you opened a blank Page before I knocked.",
            "Keep something unprompted on a Plain Page on three different days.",
            .longGameEvidence(
                capacity: .spontaneousAttention,
                kinds: [.spontaneousKeep],
                count: 3,
                distinctDays: 3,
                unpromptedOnly: true
            ),
            ["scrap_note_torn_01"]
        ),
        achievement(
            "remembered-three", "You Came Back",
            "You came back because the earlier thing still had teeth. No counter pulled you here.",
            "Bring back one true return from life outside my covers.",
            .longGameEvidence(
                capacity: .deliberateReturn,
                kinds: nil,
                count: 1,
                distinctDays: 1,
                unpromptedOnly: false
            ),
            ["illumination_keep_moment", "illumination_found_margins"]
        ),
        achievement(
            "first-binding", "Loose Days Got a Spine",
            "Loose days climbed together and grew a spine. I like when they do that.",
            "Keep one Bindery page, weekly issue, or edition.",
            .keptPageType(.bindery, 1),
            ["illumination_living_story", "illumination_lanterns_lit"],
            track: .bookcraftApprenticeship
        ),
        achievement(
            "seven-kept-days", "Seven Real Days",
            "Seven actual days brought something back. They did not have to stand in a row.",
            "Bring back proof from real life on seven different days. They do not need to stand in a row.",
            .longGameEvidence(
                capacity: nil,
                kinds: nil,
                count: 7,
                distinctDays: 7,
                unpromptedOnly: false
            ),
            ["illumination_blank_date"]
        )
    ])

    private static func catalog(
        _ achievements: [BookwideMarginaliaAchievement]
    ) -> [BookwideMarginaliaAchievement] {
        let ids = achievements.map(\.id)
        precondition(Set(ids).count == ids.count, "Marginalia achievement IDs must be unique.")
        let rewards = achievements.flatMap(\.rewardAssetIDs)
        precondition(Set(rewards).count == rewards.count, "A marginalia mark may belong to only one achievement.")
        let livingWonderCount = achievements.filter { $0.track == .livingWonder }.count
        precondition(
            livingWonderCount * 4 >= achievements.count * 3,
            "At least three quarters of Book-wide achievements must reward lived wonder."
        )
        return achievements
    }

    private static func achievement(
        _ id: String,
        _ name: String,
        _ riddle: String,
        _ hint: String,
        _ trigger: Trigger,
        _ rewardAssetIDs: [String],
        track: Track = .livingWonder
    ) -> BookwideMarginaliaAchievement {
        precondition((1...3).contains(rewardAssetIDs.count), "Marginalia achievements must reveal 1–3 marks.")
        return BookwideMarginaliaAchievement(
            id: id,
            name: name,
            riddle: riddle,
            hint: hint,
            trigger: trigger,
            rewardAssetIDs: rewardAssetIDs,
            track: track
        )
    }
}

private extension BookPage {
    var hasMarginaliaAchievementVisual: Bool {
        mediaAssets.contains { asset in
            switch asset.kind {
            case .bundledImage, .renderedImageFile, .photoLibraryAsset:
                return true
            case .audioFile:
                return false
            }
        }
    }
}

private struct PagewrightMarginaliaAchievement {
    enum Requirement {
        case selectedScraps(Int)
        case selectedAnyType([BookPageType])
        case format(PagewrightFormat)
        case template(PagewrightTemplate)
        case background(PagewrightBackground)
        case marginaliaStyle(PagewrightMarginaliaStyle)
        case pinnedNotes(Int)
        case placedMarks(Int)
        case distinctSelectedTypes(Int)
        case litDays(Int)
        case visualScrap
        case exportedDraft
        case namedDraft
        case editedPullQuote
        case bookwide(String)

        var title: String {
            switch self {
            case .selectedScraps(let count):
                return count == 1 ? "Place a kept scrap" : "Place \(count) kept scraps"
            case .selectedAnyType(let types):
                return "Use \(Self.typeList(types))"
            case .format(let format):
                return "Use \(format.shareName)"
            case .template(let template):
                return "Use \(template.title)"
            case .background(let background):
                return "Choose \(background.title)"
            case .marginaliaStyle(let style):
                return "Choose \(style.title)"
            case .pinnedNotes(let count):
                return count == 1 ? "Pin a note" : "Pin \(count) notes"
            case .placedMarks(let count):
                return count == 1 ? "Place a mark" : "Place \(count) marks"
            case .distinctSelectedTypes(let count):
                return "Gather \(count) page kinds"
            case .litDays(let count):
                return "Gather \(count) kept days"
            case .visualScrap:
                return "Use a visual scrap"
            case .exportedDraft:
                return "Make an export"
            case .namedDraft:
                return "Name the page"
            case .editedPullQuote:
                return "Choose a pull quote"
            case .bookwide(let id):
                return BookwideMarginaliaAchievement.achievement(id: id)?.name ?? "A track elsewhere in the Book"
            }
        }

        var hint: String {
            switch self {
            case .selectedScraps(let count):
                return "Put \(count == 1 ? "one kept Page" : "\(count) kept Pages") on the Pagewright canvas."
            case .selectedAnyType(let types):
                return "Put a kept \(Self.typeList(types)) Page on the canvas."
            case .format(let format):
                return "Set the Pagewright format to \(format.shareName)."
            case .template(let template):
                return "Apply the \(template.title) template."
            case .background(let background):
                return "Choose the \(background.title) background in Materials."
            case .marginaliaStyle(let style):
                return "Choose \(style.title) for the printed marks."
            case .pinnedNotes(let count):
                return "Pin \(count == 1 ? "one note" : "\(count) notes") to the Page."
            case .placedMarks(let count):
                return "Put \(count == 1 ? "one open mark" : "\(count) open marks") on the canvas."
            case .distinctSelectedTypes(let count):
                return "Choose kept Pages from \(count) different Page kinds."
            case .litDays(let count):
                return "Choose Pages from \(count) different days."
            case .visualScrap:
                return "Put down a kept Page with a photograph, rendered card, or other visible thing."
            case .exportedDraft:
                return "Let this scrapbook Page leave as a PDF or PNG once."
            case .namedDraft:
                return "Replace the default title with a name of your own."
            case .editedPullQuote:
                return "Pick a scrap, open Quotes, and choose the line that gets to stick out."
            case .bookwide(let id):
                return BookwideMarginaliaAchievement.achievement(id: id)?.hint
                    ?? "This track finishes somewhere else in my Pages."
            }
        }

        func progress(in context: Context) -> String {
            switch self {
            case .selectedScraps(let count):
                return "I have \(min(context.selectedPages.count, count)) of \(count) kept scraps"
            case .selectedAnyType:
                return isComplete(in: context) ? "I have the right kind of scrap" : "I still need the right kind of scrap"
            case .format(let format):
                return context.format == format ? "\(format.shareName) is ready" : "I still need \(format.shareName)"
            case .template(let template):
                return context.template == template ? "\(template.title) is on the Page" : "I still need \(template.title)"
            case .background(let background):
                return context.background == background ? "\(background.title) is underneath" : "I still need \(background.title)"
            case .marginaliaStyle(let style):
                return context.marginaliaStyle == style ? "\(style.title) is in the margins" : "I still need \(style.title)"
            case .pinnedNotes(let count):
                return "I have \(min(context.pinnedNoteCount, count)) of \(count) pinned notes"
            case .placedMarks(let count):
                return "I have \(min(context.placedMarkCount, count)) of \(count) placed marks"
            case .distinctSelectedTypes(let count):
                return "I have \(min(context.selectedTypes.count, count)) of \(count) Page kinds"
            case .litDays(let count):
                return "I have \(min(context.selectedDayIDs.count, count)) of \(count) different days"
            case .visualScrap:
                return context.hasVisualScrap ? "I have something visible" : "I still need something visible"
            case .exportedDraft:
                return context.hasExport ? "It has left as a PDF or PNG" : "It has not left as a PDF or PNG yet"
            case .namedDraft:
                return context.hasCustomTitle ? "The Page has its own name" : "The Page still needs its own name"
            case .editedPullQuote:
                return context.hasEditedPullQuote ? "One line is sticking out" : "I still need one line to stick out"
            case .bookwide(let id):
                guard let achievement = BookwideMarginaliaAchievement.achievement(id: id) else {
                    return "I lost this track"
                }
                return achievement.progress(in: context.bookwide)
            }
        }

        func isComplete(in context: Context) -> Bool {
            switch self {
            case .selectedScraps(let count):
                return context.selectedPages.count >= count
            case .selectedAnyType(let types):
                return !context.selectedTypes.isDisjoint(with: Set(types))
            case .format(let format):
                return context.format == format
            case .template(let template):
                return context.template == template
            case .background(let background):
                return context.background == background
            case .marginaliaStyle(let style):
                return context.marginaliaStyle == style
            case .pinnedNotes(let count):
                return context.pinnedNoteCount >= count
            case .placedMarks(let count):
                return context.placedMarkCount >= count
            case .distinctSelectedTypes(let count):
                return context.selectedTypes.count >= count
            case .litDays(let count):
                return context.selectedDayIDs.count >= count
            case .visualScrap:
                return context.hasVisualScrap
            case .exportedDraft:
                return context.hasExport
            case .namedDraft:
                return context.hasCustomTitle
            case .editedPullQuote:
                return context.hasEditedPullQuote
            case .bookwide(let id):
                return context.completedAchievementIDs.contains(id)
                    || BookwideMarginaliaAchievement.achievement(id: id)?.isComplete(in: context.bookwide) == true
            }
        }

        private static func typeList(_ types: [BookPageType]) -> String {
            types.map(\.shortTitle).joined(separator: " or ")
        }
    }

    struct Context {
        var selectedPages: [BookPage]
        var format: PagewrightFormat
        var template: PagewrightTemplate
        var background: PagewrightBackground
        var marginaliaStyle: PagewrightMarginaliaStyle
        var pinnedNoteCount: Int
        var placedMarkCount: Int
        var personalPhotoCount: Int
        var hasExport: Bool
        var hasCustomTitle: Bool
        var hasEditedPullQuote: Bool
        var completedAchievementIDs: Set<String>
        var bookwide: BookwideMarginaliaAchievement.Context

        var selectedTypes: Set<BookPageType> { Set(selectedPages.map(\.type)) }
        var selectedDayIDs: Set<String> { Set(selectedPages.map { BookDay.id(for: $0.createdAt) }) }
        var hasVisualScrap: Bool {
            personalPhotoCount > 0 || selectedPages.contains { !$0.pagewrightVisualMediaAssets.isEmpty }
        }
    }

    private struct Quest {
        var id: String
        var name: String
        var riddle: String
        var requirements: [Requirement]
    }

    var assetID: String
    var assetName: String
    var questID: String
    var name: String
    var riddle: String
    var requirements: [Requirement]

    var track: BookwideMarginaliaAchievement.Track {
        for requirement in requirements {
            if case .bookwide(let id) = requirement,
               let achievement = BookwideMarginaliaAchievement.achievement(id: id) {
                return achievement.track
            }
        }
        return .bookcraftApprenticeship
    }

    var title: String {
        "\(track.title) · \(name): \(Self.assetDisplayName(assetID))"
    }

    var hiddenHint: String {
        "\(riddle)\nGive me one bit of Belief and I'll tell you exactly what opens it."
    }

    var requirementSummary: String {
        "\(track.shortTitle) · \(requirements.map(\.title).joined(separator: " · "))"
    }

    func revealedHint(in context: Context) -> String {
        let instructions = requirements.map(\.hint).joined(separator: " ")
        let progress = requirements.map { $0.progress(in: context) }.joined(separator: " · ")
        return "\(instructions)\nRight now: \(progress)."
    }

    func isComplete(in context: Context) -> Bool {
        requirements.allSatisfy { $0.isComplete(in: context) }
    }

    static func achievement(for asset: IlluminationAsset) -> PagewrightMarginaliaAchievement {
        let quest = quest(for: asset)
        return PagewrightMarginaliaAchievement(
            assetID: asset.id,
            assetName: asset.assetName,
            questID: quest.id,
            name: quest.name,
            riddle: quest.riddle,
            requirements: quest.requirements
        )
    }

    static func assetDisplayName(_ id: String) -> String {
        id
            .replacingOccurrences(of: "illumination_", with: "")
            .replacingOccurrences(of: "doodle_", with: "")
            .replacingOccurrences(of: "stamp_", with: "")
            .replacingOccurrences(of: "overlay_", with: "")
            .replacingOccurrences(of: "scrap_", with: "")
            .replacingOccurrences(of: "paper_", with: "")
            .replacingOccurrences(of: "_01", with: "")
            .replacingOccurrences(of: "_02", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func quest(for asset: IlluminationAsset) -> Quest {
        if let achievement = BookwideMarginaliaAchievement.rewarding(assetID: asset.id) {
            return Quest(
                id: achievement.id,
                name: achievement.name,
                riddle: achievement.riddle,
                requirements: [.bookwide(achievement.id)]
            )
        }
        let tags = Set(asset.tags.map { $0.lowercased() })

        switch asset.kind {
        case .background:
            return namedFlyleaf
        case .paperScrap:
            if containsAny(tags, ["botanical", "flower", "fern", "lavender", "clover", "thyme", "moss", "green"]) {
                return pressedBetweenPages
            }
            if containsAny(tags, ["night", "moon", "moth", "dreams"]) {
                return nightPaper
            }
            if containsAny(tags, ["compass", "map", "walk", "west", "anchor", "sailboat"]) {
                return cartographersOffcut
            }
            if containsAny(tags, ["field", "study", "observer", "label", "tag", "note"]) {
                return evidenceSlip
            }
            return firstCut
        case .stamp:
            if containsAny(tags, ["night", "moon", "moth", "dreams"]) {
                return lunaPost
            }
            if containsAny(tags, ["compass", "map", "walk", "west", "anchor", "sailboat", "star"]) {
                return northboundSeal
            }
            if containsAny(tags, ["library", "archive", "book", "memory", "remembered", "card"]) {
                return archivistsSeal
            }
            if containsAny(tags, ["ordinary", "wonder", "curiosity", "surprise", "bee"]) {
                return astonishmentCertified
            }
            if containsAny(tags, ["field", "study", "observer", "label", "tag", "note"]) {
                return officiallyObserved
            }
            if containsAny(tags, ["home", "teacup", "heart", "company", "paw", "creature"]) {
                return creatureWasHere
            }
            return sealOfAssembly
        case .doodle:
            if containsAny(tags, ["photo", "attention"]) {
                return visibleEvidence
            }
            if containsAny(tags, ["ink", "write", "spell", "magic", "belief"]) {
                return inkbound
            }
            if containsAny(tags, ["star", "constellation"]) {
                return handmadeConstellation
            }
            if containsAny(tags, ["ticket", "passage", "wander", "arrival"]) {
                return passageGranted
            }
            if containsAny(tags, ["letter", "script"]) {
                return lettersThroughMargins
            }
            if containsAny(tags, ["harbor", "water", "tide", "lighthouse", "shell", "rain", "weather"]) {
                return harborLedger
            }
            if containsAny(tags, ["compass", "map", "walk", "west", "anchor", "sailboat"]) {
                return unlostOnPurpose
            }
            if containsAny(tags, ["night", "moon", "moth", "dreams"]) {
                return nocturneCollector
            }
            if containsAny(tags, ["botanical", "flower", "fern", "lavender", "clover", "thyme", "moss", "green"]) {
                return greenhousePressing
            }
            if containsAny(tags, ["rest", "quiet", "hush", "patient"]) {
                return keeperOfQuiet
            }
            if containsAny(tags, ["field", "study", "observer", "label", "tag", "note"]) {
                return filedUnderAstonishment
            }
            if containsAny(tags, ["ordinary", "wonder", "curiosity", "surprise"]) {
                return usualInterrupted
            }
            if containsAny(tags, ["home", "teacup", "heart", "company", "paw", "creature"]) {
                return pocketFamiliar
            }
            if containsAny(tags, ["light", "lamp", "lantern", "story", "world"]) {
                return weeklyIlluminator
            }
            if containsAny(tags, ["library", "archive", "book", "memory", "remembered", "card", "margin"]) {
                return livingArchive
            }
            if containsAny(tags, ["feather", "soft", "wind", "brown"]) {
                return softChaosLicense
            }
            if containsAny(tags, ["eye", "observed", "witness"]) {
                return witnessedEdge
            }
            return marginApprentice
        case .tape:
            return containsAny(tags, ["botanical", "flower", "green"])
                ? greenBinding
                : heldTogether
        case .overlay:
            return finalVarnish
        }
    }

    private static func containsAny(_ tags: Set<String>, _ candidates: [String]) -> Bool {
        !tags.isDisjoint(with: Set(candidates))
    }

    private static let firstCut = Quest(
        id: "first-cut",
        name: "The Scissors Woke",
        riddle: "Put down one kept scrap. The scissors only need one before they start nosing about.",
        requirements: [.selectedScraps(1)]
    )
    private static let namedFlyleaf = Quest(
        id: "named-flyleaf",
        name: "You Named It",
        riddle: "The Page wants a name that came from you, not the little default label I stuck on it.",
        requirements: [.namedDraft]
    )
    private static let pressedBetweenPages = Quest(
        id: "pressed-between-pages",
        name: "Pressed Between Pages",
        riddle: "Bring in one green or weathered scrap. Then let a pressed flower sit on it.",
        requirements: [.selectedAnyType([.weather, .location, .souvenir]), .marginaliaStyle(.pressedFlower)]
    )
    private static let nightPaper = Quest(
        id: "night-paper",
        name: "Paper After Dark",
        riddle: "Put two scraps on Night paper. They are waiting for the lamps to go out.",
        requirements: [.selectedScraps(2), .background(.night)]
    )
    private static let cartographersOffcut = Quest(
        id: "cartographers-offcut",
        name: "A Scrap from the Map",
        riddle: "Bring me a place or direction from two different days. The map wants both.",
        requirements: [.selectedAnyType([.wonderCompass, .anchor, .location]), .litDays(2)]
    )
    private static let evidenceSlip = Quest(
        id: "evidence-slip",
        name: "The Little Evidence Slip",
        riddle: "Use the field-notes desk, then point at the one sentence that matters.",
        requirements: [.template(.fieldNotes), .editedPullQuote]
    )
    private static let greenBinding = Quest(
        id: "green-binding",
        name: "A Flower Held It",
        riddle: "Put down a pressed flower and pin one note beside it. That is enough to hold the Page together.",
        requirements: [.marginaliaStyle(.pressedFlower), .pinnedNotes(1)]
    )
    private static let heldTogether = Quest(
        id: "held-together",
        name: "The Tear Stayed",
        riddle: "Name the Page and put down one open mark. The tear can stay. It belongs now.",
        requirements: [.namedDraft, .placedMarks(1)]
    )
    private static let archivistsSeal = Quest(
        id: "archivists-seal",
        name: "Five Scraps Made a Pile",
        riddle: "Gather five scraps from at least two days. I will stop calling it a pile and call it an archive.",
        requirements: [.selectedScraps(5), .litDays(2)]
    )
    private static let lunaPost = Quest(
        id: "luna-post",
        name: "Moth Post",
        riddle: "Make a Letter Packet on Night paper. The moths keep trying to deliver those.",
        requirements: [.format(.letterPacket), .background(.night)]
    )
    private static let northboundSeal = Quest(
        id: "northbound-seal",
        name: "Three Proofs and a Direction",
        riddle: "Bring one place or direction, then gather three different kinds of Page around it.",
        requirements: [.selectedAnyType([.wonderCompass, .anchor, .location]), .distinctSelectedTypes(3)]
    )
    private static let astonishmentCertified = Quest(
        id: "astonishment-certified",
        name: "The Ordinary Thing Got a Name",
        riddle: "Bring one ordinary wonder and give the finished Page a name of its own.",
        requirements: [.selectedAnyType([.souvenir, .narrativeOS, .bookNotices]), .namedDraft]
    )
    private static let officiallyObserved = Quest(
        id: "officially-observed",
        name: "Pinned to the Field Desk",
        riddle: "Open the field-notes desk and pin down one thing the form forgot to ask.",
        requirements: [.template(.fieldNotes), .pinnedNotes(1)]
    )
    private static let creatureWasHere = Quest(
        id: "creature-was-here",
        name: "A Creature Was Here",
        riddle: "Make a Pocket Page and put one visible thing inside. Something has clearly been here.",
        requirements: [.format(.pocketPage), .visualScrap]
    )
    private static let sealOfAssembly = Quest(
        id: "seal-of-assembly",
        name: "Three Scraps, One Seal",
        riddle: "Put down three scraps and use the wax seal. Now they have gathered on purpose.",
        requirements: [.selectedScraps(3), .marginaliaStyle(.waxSeal)]
    )
    private static let visibleEvidence = Quest(
        id: "visible-evidence",
        name: "The Picture Went First",
        riddle: "Put down something visible and use the Polaroid Scatter. Let the picture choose where the rest goes.",
        requirements: [.visualScrap, .template(.polaroidScatter)]
    )
    private static let inkbound = Quest(
        id: "inkbound",
        name: "The Ink Took Hold",
        riddle: "Pin two notes and choose one line to stick out. The ink will stop wriggling then.",
        requirements: [.pinnedNotes(2), .editedPullQuote]
    )
    private static let handmadeConstellation = Quest(
        id: "handmade-constellation",
        name: "A Handmade Constellation",
        riddle: "Bring three kinds of Page together and put ink stars around them. That is enough sky.",
        requirements: [.distinctSelectedTypes(3), .marginaliaStyle(.inkStars)]
    )
    private static let passageGranted = Quest(
        id: "passage-granted",
        name: "The Ticket Knew Your Name",
        riddle: "Make a Letter Packet and give it a name of its own. The ticket checks names.",
        requirements: [.format(.letterPacket), .namedDraft]
    )
    private static let lettersThroughMargins = Quest(
        id: "letters-through-margins",
        name: "A Note Hid in the Letter",
        riddle: "Make a Letter Packet and pin one private note inside it. Letters like carrying secrets.",
        requirements: [.format(.letterPacket), .pinnedNotes(1)]
    )
    private static let harborLedger = Quest(
        id: "harbor-ledger",
        name: "Weather in the Ledger",
        riddle: "Bring a weather or place Page to the ruled ledger. It likes keeping accounts of water and sky.",
        requirements: [.selectedAnyType([.weather, .todaysSky, .location, .anchor]), .background(.ledger)]
    )
    private static let unlostOnPurpose = Quest(
        id: "unlost-on-purpose",
        name: "Three Days on the Map",
        riddle: "Bring a place or direction, then let three different days touch the map.",
        requirements: [.selectedAnyType([.wonderCompass, .anchor, .location]), .litDays(3)]
    )
    private static let nocturneCollector = Quest(
        id: "nocturne-collector",
        name: "Three Days Under Night",
        riddle: "Put scraps from three different days on Night paper. They look different under the same dark.",
        requirements: [.litDays(3), .background(.night)]
    )
    private static let greenhousePressing = Quest(
        id: "greenhouse-pressing",
        name: "The Ledger Grew Leaves",
        riddle: "Bring one green, weathered, or place scrap to the field-notes desk. The ledger will grow leaves.",
        requirements: [.selectedAnyType([.weather, .location, .souvenir]), .template(.fieldNotes)]
    )
    private static let keeperOfQuiet = Quest(
        id: "keeper-of-quiet",
        name: "A Soft Place for Rest",
        riddle: "Put a Rest, Remembered, or Pocket Page on vellum. Quiet needs somewhere soft to sit.",
        requirements: [.selectedAnyType([.rest, .bookRemembered, .bookPocket]), .background(.vellum)]
    )
    private static let filedUnderAstonishment = Quest(
        id: "filed-under-astonishment",
        name: "Three Strange Specimens",
        riddle: "Bring three different kinds of Page to the field-notes desk. Its drawer is stuck until then.",
        requirements: [.template(.fieldNotes), .distinctSelectedTypes(3)]
    )
    private static let usualInterrupted = Quest(
        id: "usual-interrupted",
        name: "The Ordinary Thing Made a Mess",
        riddle: "Bring one ordinary wonder and use Soft Chaos. Let it make the mess it was trying to make.",
        requirements: [.selectedAnyType([.souvenir, .narrativeOS, .bookNotices]), .template(.softChaos)]
    )
    private static let pocketFamiliar = Quest(
        id: "pocket-familiar",
        name: "Something Moved into the Pocket",
        riddle: "Make a Pocket Page and pin two notes inside. Something small will think the notes are for it.",
        requirements: [.format(.pocketPage), .pinnedNotes(2)]
    )
    private static let weeklyIlluminator = Quest(
        id: "weekly-illuminator",
        name: "Five Days Lit the Shrine",
        riddle: "Use the Weekly Shrine and bring scraps from five different days. They will light it themselves.",
        requirements: [.template(.weeklyShrine), .litDays(5)]
    )
    private static let livingArchive = Quest(
        id: "living-archive",
        name: "Five Scraps, One Surviving Line",
        riddle: "Gather five scraps. Then choose the one line that gets to poke out of the pile.",
        requirements: [.selectedScraps(5), .editedPullQuote]
    )
    private static let softChaosLicense = Quest(
        id: "soft-chaos-license",
        name: "Three Marks Got Loose",
        riddle: "Use Soft Chaos and put down three open marks. Do not make them stand straight.",
        requirements: [.template(.softChaos), .placedMarks(3)]
    )
    private static let witnessedEdge = Quest(
        id: "witnessed-edge",
        name: "The Line That Proved It",
        riddle: "Name the Page and choose the line that proves you really looked.",
        requirements: [.namedDraft, .editedPullQuote]
    )
    private static let marginApprentice = Quest(
        id: "margin-apprentice",
        name: "The Margins Started Teaching",
        riddle: "Put down two kept scraps. My margins start showing their tricks after two.",
        requirements: [.selectedScraps(2)]
    )
    private static let finalVarnish = Quest(
        id: "final-varnish",
        name: "It Left the Worktable",
        riddle: "Give the Page its own name, then let it leave once as a PDF or PNG.",
        requirements: [.namedDraft, .exportedDraft]
    )
}

/// What the Book says is loose this month, shown above the marks it loosened.
struct PagewrightOccasionNote: Equatable {
    var title: String
    var line: String
}

struct PagewrightSheet: View {
    enum Experience: Equatable {
        case studio
        case inscription
    }

    private struct MarginaliaUnlockNotice: Equatable {
        var questID: String
        var title: String
        var markCount: Int
        var additionalQuestCount: Int
    }

    private struct LooseFindingDragState {
        var assetName: String
        var translation: CGSize
    }

    private struct CompactCanvasFramePreferenceKey: PreferenceKey {
        static var defaultValue: CGRect = .zero

        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }

    let keptPages: [BookPage]
    let bookwideAchievementContext: BookwideMarginaliaAchievement.Context
    let initialPageIDs: [String]
    let initialPDFURL: URL?
    let initialPNGURL: URL?
    let onExportPDF: (PagewrightDraft) -> URL?
    let onExportPNG: (PagewrightDraft) -> URL?
    let onKeep: (PagewrightDraft, URL?, URL?) -> Void
    var experience: Experience = .studio
    /// The time half of the world state: which month it is and what is running.
    /// Decides what sits on This Month and what has already had its season.
    var markContext: IlluminationPlacementContext = .empty
    /// The Book's own line about the live event, for the This Month header.
    var occasionNote: PagewrightOccasionNote?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var title = "A Page I Kept"
    @State private var hasEditedTitle = false
    @State private var note = ""
    @State private var format: PagewrightFormat = .scrapPage
    @State private var selectedIDs: [String] = []
    @State private var selectedDayID = PagewrightDayBucket.allID
    @State private var searchText = ""
    @State private var activePageID: String?
    @State private var pullQuotes: [String: String] = [:]
    @State private var editedPullQuotePageIDs: Set<String> = []
    @State private var background: PagewrightBackground = .parchment
    /// Each stock keeps its own dab of colour while the worktable is open.
    /// Switching from teal cotton to vellum and back should not lose the teal.
    @State private var paperTints: [PagewrightBackground: PagewrightPaperTint] = [:]
    @State private var marginalia: PagewrightMarginaliaStyle = .pressedFlower
    @State private var noteDraft = ""
    @State private var noteStyle: PagewrightPinnedNoteStyle = .margin
    @State private var pinnedNotes: [PagewrightPinnedNote] = []
    @State private var personalPhotos: [PagewrightPersonalPhoto] = []
    @State private var canvasElements: [PagewrightCanvasElement] = []
    @State private var activeElementID: String?
    @State private var selectedTemplate: PagewrightTemplate = .memoryWall
    @State private var selectedMarginaliaPackID = CoreMarginsPack.id
    @State private var sharedURL: URL?
    @State private var sharedPNGURL: URL?
    @State private var editingScrapTextElementID: String?
    @State private var activeTrayMode: PagewrightTrayMode?
    @State private var selectedScrapTrayScope: PagewrightScrapTrayScope = .all
    @State private var selectedShelf: MarkShelf = .theDrawer
    @State private var hasChosenOpeningShelf = false
    @State private var markSearchText = ""
    @State private var pageCache = PagewrightPageCache.empty
    @State private var cabinet = PagewrightMarkCabinet.empty
    @State private var isManipulatingElement = false
    @State private var compactCanvasFrame: CGRect = .zero
    @GestureState private var looseFindingDragState: LooseFindingDragState?
    #if canImport(PhotosUI)
    @State private var pendingPersonalPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPersonalPhotos = false
    @State private var personalPhotoImportMessage: String?
    #endif
    @FocusState private var focusedScrapTextElementID: String?

    /// Shared with the rest of the Book by key: the Pagewright reads and spends
    /// the same Belief the reader earns everywhere else.
    @AppStorage("beliefScore") private var beliefScore = 30
    @AppStorage("didCompleteStoryOnboarding") private var didCompleteStoryOnboarding = false
    /// Achievement sets whose clue has been purchased with Belief. Older
    /// versions stored asset IDs; the read path below still honors those.
    @AppStorage("scrapbookRevealedMarginaliaHints") private var revealedMarginaliaHintsRaw = ""
    /// Achievement sets stay earned after the current canvas changes. Storing
    /// quest IDs rather than asset IDs also unlocks matching rewards from future
    /// marginalia packs without making the reader repeat the same ritual.
    @AppStorage("scrapbookCompletedMarginaliaAchievements") private var completedMarginaliaAchievementsRaw = ""
    /// A locked mark the reader tapped: drives the achievement/hint sheet.
    @State private var pendingUnlockMarginalia: IlluminationAsset?
    @State private var activeTutorNote: MarginTutorNote?
    @State private var marginaliaUnlockNotice: MarginaliaUnlockNotice?
    @State private var hasSeededMarginaliaAchievements = false

    private var marginTutorSeenData: String {
        get { MarginTutorLedger.encode(Set(PlayerVault.shared.data.tutorSeen)) }
        nonmutating set {
            PlayerVault.shared.data.tutorSeen = Array(MarginTutorLedger.seenIDs(from: newValue)).sorted()
            PlayerVault.shared.save()
        }
    }

    private var revealedMarginaliaHintIDs: Set<String> {
        Set(revealedMarginaliaHintsRaw.split(separator: ",").map(String.init))
    }

    private var completedMarginaliaAchievementIDs: Set<String> {
        Set(completedMarginaliaAchievementsRaw.split(separator: ",").map(String.init))
    }

    private func marginaliaUnlockNoticeLine(_ notice: MarginaliaUnlockNotice) -> String {
        if notice.additionalQuestCount > 0 {
            return "\(notice.additionalQuestCount) more things finished at the same time. \(notice.markCount) new marks came loose. The locks stay off."
        }
        if notice.markCount == 1 {
            return "One new mark came loose. The lock stays off."
        }
        return "\(notice.markCount) new marks came loose. The locks stay off."
    }

    private func tutorTouch(_ id: String) {
        guard didCompleteStoryOnboarding else { return }
        var seen = MarginTutorLedger.seenIDs(from: marginTutorSeenData)
        guard !seen.contains(id), let note = MarginTutorCatalog.note(for: id) else { return }
        seen.insert(id)
        marginTutorSeenData = MarginTutorLedger.encode(seen)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            activeTutorNote = note
        }
    }

    private var marginaliaAchievementContext: PagewrightMarginaliaAchievement.Context {
        PagewrightMarginaliaAchievement.Context(
            selectedPages: selectedPages,
            format: format,
            template: selectedTemplate,
            background: background,
            marginaliaStyle: marginalia,
            pinnedNoteCount: pinnedNotes.count,
            placedMarkCount: canvasElements.filter { $0.kind == .marginaliaAsset }.count,
            personalPhotoCount: personalPhotos.count,
            hasExport: sharedURL != nil || sharedPNGURL != nil,
            hasCustomTitle: hasEditedTitle && (
                title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty
                    .map { $0 != "A Page I Kept" } ?? false
            ),
            hasEditedPullQuote: !editedPullQuotePageIDs.isEmpty,
            completedAchievementIDs: completedMarginaliaAchievementIDs,
            bookwide: bookwideAchievementContext
        )
    }

    private var marginaliaAchievementSignature: String {
        let context = marginaliaAchievementContext
        return [
            context.selectedPages.map(\.id).sorted().joined(separator: "|"),
            context.selectedTypes.map(\.rawValue).sorted().joined(separator: "|"),
            context.selectedDayIDs.sorted().joined(separator: "|"),
            context.format.rawValue,
            context.template.rawValue,
            context.background.rawValue,
            context.marginaliaStyle.rawValue,
            "\(context.pinnedNoteCount)",
            "\(context.placedMarkCount)",
            context.hasVisualScrap ? "visual" : "text",
            context.hasExport ? "exported" : "draft",
            context.hasCustomTitle ? "named" : "default",
            context.hasEditedPullQuote ? "quote-edited" : "quote-seeded"
        ].joined(separator: "§")
    }

    private var pageTitleBinding: Binding<String> {
        Binding(
            get: { title },
            set: {
                title = $0
                hasEditedTitle = true
            }
        )
    }

    private func paperTint(for paper: PagewrightBackground) -> PagewrightPaperTint {
        paperTints[paper] ?? paper.defaultTint
    }

    private var paperTint: PagewrightPaperTint {
        paperTint(for: background)
    }

    private func choosePaperTint(_ tint: PagewrightPaperTint) {
        paperTints[background] = tint
        invalidateExports()
        BookFeedback.pressTick()
    }

    private func restorePaperTint() {
        paperTints.removeValue(forKey: background)
        invalidateExports()
        BookFeedback.pressTick()
    }

    #if canImport(UIKit)
    private var customPaperTintBinding: Binding<Color> {
        Binding(
            get: { paperTint.color },
            set: { color in
                guard let tint = PagewrightPaperTint(color: color) else { return }
                paperTints[background] = tint
                invalidateExports()
            }
        )
    }
    #endif

    private func isMarginaliaUnlocked(_ asset: IlluminationAsset) -> Bool {
        let achievement = PagewrightMarginaliaAchievement.achievement(for: asset)
        return completedMarginaliaAchievementIDs.contains(achievement.questID)
            || achievement.isComplete(in: marginaliaAchievementContext)
    }

    private func refreshMarginaliaAchievements(announce: Bool = true) {
        guard experience == .studio else { return }
        // Across the whole cabinet, not one pack: the tray stopped being a
        // pack switcher, so a quest attached to another pack's mark must still
        // be able to complete and announce itself.
        let achievements = cabinet.marksByShelf.values
            .flatMap { $0 }
            .map { PagewrightMarginaliaAchievement.achievement(for: $0.asset) }
        let completedNow = Set(
            achievements
                .filter { $0.isComplete(in: marginaliaAchievementContext) }
                .map(\.questID)
        )
        let newlyCompleted = completedNow.subtracting(completedMarginaliaAchievementIDs)
        guard !newlyCompleted.isEmpty else { return }

        var earned = completedMarginaliaAchievementIDs
        earned.formUnion(newlyCompleted)
        completedMarginaliaAchievementsRaw = earned.sorted().joined(separator: ",")

        guard announce, hasSeededMarginaliaAchievements,
              let questID = newlyCompleted.sorted().first,
              let achievement = achievements.first(where: { $0.questID == questID }) else { return }
        let rewardCount = achievements.filter { newlyCompleted.contains($0.questID) }.count
        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            marginaliaUnlockNotice = MarginaliaUnlockNotice(
                questID: questID,
                title: achievement.name,
                markCount: rewardCount,
                additionalQuestCount: max(0, newlyCompleted.count - 1)
            )
        }
        BookFeedback.play(.select)
    }

    private func isMarginaliaHintRevealed(_ asset: IlluminationAsset) -> Bool {
        let questID = PagewrightMarginaliaAchievement.achievement(for: asset).questID
        return revealedMarginaliaHintIDs.contains(questID)
            || revealedMarginaliaHintIDs.contains(asset.id)
    }

    private func revealMarginaliaHint(_ asset: IlluminationAsset) {
        guard !isMarginaliaHintRevealed(asset) else { return }
        guard beliefScore >= 1 else {
            BookFeedback.play(.error)
            return
        }
        beliefScore = max(0, beliefScore - 1)
        var revealed = revealedMarginaliaHintIDs
        revealed.insert(PagewrightMarginaliaAchievement.achievement(for: asset).questID)
        revealedMarginaliaHintsRaw = revealed.sorted().joined(separator: ",")
        BookFeedback.play(.select)
    }

    private var buckets: [PagewrightDayBucket] {
        pageCache.buckets.isEmpty ? PagewrightDayBucket.make(from: keptPages) : pageCache.buckets
    }

    private var cachedKeptPages: [BookPage] {
        pageCache.pages.isEmpty ? keptPages : pageCache.pages
    }

    private var filteredPages: [BookPage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cachedKeptPages.filter { page in
            let cached = pageCache.cached(for: page)
            let matchesDay = selectedDayID == PagewrightDayBucket.allID
                || cached.dayID == selectedDayID
            guard matchesDay else { return false }
            guard !query.isEmpty else { return true }
            return cached.searchBlob.contains(query)
        }
    }

    private var selectedPages: [BookPage] {
        selectedIDs.compactMap { id in pageCache.page(for: id) ?? keptPages.first { $0.id == id } }
    }

    private var trayFilteredPages: [BookPage] {
        let activeCachedPage = activePage.map { pageCache.cached(for: $0) }
        return filteredPages.filter { page in
            let cached = pageCache.cached(for: page)
            switch selectedScrapTrayScope {
            case .all:
                return true
            case .sameType:
                guard let activePage else { return true }
                return page.type == activePage.type
            case .sameDay:
                guard let activeCachedPage else { return true }
                return cached.dayID == activeCachedPage.dayID
            case .photos:
                return cached.hasVisualMedia
            }
        }
    }

    /// The three scraps the worktable opens with when nothing named a set.
    ///
    /// Ordered so the last one is the keep that already carries a photograph.
    /// `seedOpeningLibraryPhoto` replaces that last scrap when the reader's
    /// library answers, which leaves two plain scraps and one real photograph;
    /// when it does not answer, the photo-carrying keep simply stays and the
    /// spread still has an image in it.
    private var openingScrapIDs: [String] {
        guard !keptPages.isEmpty else { return [] }
        let wanted = format.defaultSelectionCount
        let visual = keptPages.first { pageCache.cached(for: $0).hasVisualMedia }

        var chosen: [String] = []
        for page in keptPages where chosen.count < max(0, wanted - (visual == nil ? 0 : 1)) {
            guard page.id != visual?.id else { continue }
            chosen.append(page.id)
        }
        if let visual { chosen.append(visual.id) }
        return chosen
    }

    private var selectionLabel: String {
        let scrapWord = selectedIDs.count == 1 ? "scrap" : "scraps"
        let photoWord = personalPhotos.count == 1 ? "photo" : "photos"
        return "\(selectedIDs.count) \(scrapWord) · \(personalPhotos.count) \(photoWord)"
    }

    private var hasPrimaryCanvasContent: Bool {
        canvasElements.contains { element in
            element.kind == .page || element.kind == .personalPhoto
        }
    }

    private var activePage: BookPage? {
        if let element = activeElement, element.kind == .page {
            return selectedPages.first { $0.id == element.sourceID }
        }
        guard let activePageID else { return selectedPages.first }
        return selectedPages.first { $0.id == activePageID } ?? selectedPages.first
    }

    private var activeElement: PagewrightCanvasElement? {
        guard let activeElementID else { return nil }
        return canvasElements.first { $0.id == activeElementID }
    }

    private var unlockedMarginaliaPacks: [IlluminationAssetPack] {
        let packs = IlluminationPackRegistry.unlockedPacks
        return packs.isEmpty ? [CoreMarginsPack.pack] : packs
    }

    private var selectedMarginaliaPack: IlluminationAssetPack {
        unlockedMarginaliaPacks.first { $0.id == selectedMarginaliaPackID } ?? CoreMarginsPack.pack
    }

    private func ensureSelectedMarginaliaPackIsUnlocked() {
        guard !unlockedMarginaliaPacks.contains(where: { $0.id == selectedMarginaliaPackID }) else { return }
        selectedMarginaliaPackID = unlockedMarginaliaPacks.first?.id ?? CoreMarginsPack.id
    }

    private func refreshStudioCachesIfNeeded() {
        let currentPageIDs = keptPages.map(\.id)
        if pageCache.pageIDs != currentPageIDs {
            pageCache = PagewrightPageCache(pages: keptPages)
        }
        refreshCabinetIfNeeded()
    }

    private func refreshCabinetIfNeeded() {
        guard !cabinet.matches(markContext) else { return }
        cabinet = PagewrightMarkCabinet(context: markContext, isUnlocked: isMarginaliaUnlocked)

        if !hasChosenOpeningShelf {
            hasChosenOpeningShelf = true
            // Open on whatever is loose this month, when anything is. It is the
            // one shelf that will not be there next month, so it gets the first
            // look; the drawer is the fallback because it is never empty and it
            // is different today than it was yesterday.
            selectedShelf = cabinet.count(on: .thisMonth) > 0 ? .thisMonth : .theDrawer
            return
        }

        // A shelf can empty out when a month closes. Do not leave the reader
        // staring at the one shelf that has nothing on it.
        if cabinet.marks(on: selectedShelf).isEmpty {
            selectedShelf = cabinet.shelves.first ?? .theDrawer
        }
    }

    init(
        keptPages: [BookPage],
        bookwideAchievementContext: BookwideMarginaliaAchievement.Context,
        initialPageIDs: [String],
        initialPDFURL: URL?,
        initialPNGURL: URL?,
        onExportPDF: @escaping (PagewrightDraft) -> URL?,
        onExportPNG: @escaping (PagewrightDraft) -> URL?,
        onKeep: @escaping (PagewrightDraft, URL?, URL?) -> Void,
        experience: Experience = .studio,
        markContext: IlluminationPlacementContext = .empty,
        occasionNote: PagewrightOccasionNote? = nil
    ) {
        self.keptPages = keptPages
        self.bookwideAchievementContext = bookwideAchievementContext
        self.initialPageIDs = initialPageIDs
        self.initialPDFURL = initialPDFURL
        self.initialPNGURL = initialPNGURL
        self.onExportPDF = onExportPDF
        self.onExportPNG = onExportPNG
        self.onKeep = onKeep
        self.experience = experience
        self.markContext = markContext
        self.occasionNote = occasionNote
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isWide = proxy.size.width >= 820
                Group {
                    if experience == .inscription {
                        inscriptionStudio
                    } else if isWide {
                        HStack(spacing: 0) {
                            libraryPanel
                                .frame(width: 330)
                            Divider().overlay(BookPalette.nightText.opacity(0.12))
                            canvasPanel
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Divider().overlay(BookPalette.nightText.opacity(0.12))
                            inspectorPanel
                                .frame(width: 330)
                        }
                    } else {
                        compactStudio
                    }
                }
                .background(BookPalette.nightPanel.opacity(0.98).ignoresSafeArea())
            }
            .navigationTitle(experience == .inscription ? "The Pagewright's Worktable" : "Scrapbook Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(experience == .inscription ? "Back to the Book" : "Done") { dismiss() }
                        .foregroundStyle(BookPalette.nightText)
                }
                if experience == .studio {
                    ToolbarItem(placement: .primaryAction) {
                        exportMenu
                    }
                }
            }
            .onAppear {
                ensureSelectedMarginaliaPackIsUnlocked()
                refreshStudioCachesIfNeeded()
                guard selectedIDs.isEmpty else { return }
                let availableIDs = Set(keptPages.map(\.id))
                let seededIDs = initialPageIDs.filter(availableIDs.contains)
                selectedIDs = seededIDs.isEmpty ? openingScrapIDs : seededIDs
                activePageID = selectedIDs.first
                seedPullQuotes()

                // Every way in opens on an arranged spread, not an empty sheet.
                // Cold-opening from Contents used to drop the reader onto a
                // blank canvas with instructions on it, which asks them to know
                // what arranging looks like before they have seen it once.
                applyTemplate(.polaroidScatter, replaceSelection: false)
                if !seededIDs.isEmpty, title == "A Page I Kept" {
                    title = experience == .inscription ? "The Inscription, in Pieces" : "Things I Kept"
                }
                #if canImport(Photos)
                // The opening spread wants one photograph in it. The library is
                // asked first — this is also where the iOS Photos prompt is
                // raised — and if it is refused or empty, the kept scrap that
                // already carries an image stays where `openingScrapIDs` put it.
                Task { await seedOpeningLibraryPhoto() }
                #endif
                activeElementID = canvasElements.first?.id
                sharedURL = initialPDFURL
                sharedPNGURL = initialPNGURL
                refreshMarginaliaAchievements(announce: false)
                hasSeededMarginaliaAchievements = true
                tutorTouch("scrapbook-studio")
            }
            .onChange(of: format) { _, newFormat in
                if selectedIDs.isEmpty {
                    selectedIDs = keptPages.prefix(newFormat.defaultSelectionCount).map(\.id)
                }
                if activePageID == nil { activePageID = selectedIDs.first }
                seedPullQuotes()
                syncCanvasElements()
                invalidateExports()
            }
            .onChange(of: unlockedMarginaliaPacks.map(\.id)) { _, _ in
                ensureSelectedMarginaliaPackIsUnlocked()
                // A newly unlocked pack contributes marks to the shared
                // shelves, so the cabinet is rebuilt, not just the picker.
                cabinet = PagewrightMarkCabinet(context: markContext, isUnlocked: isMarginaliaUnlocked)
            }
            .onChange(of: markContext) { _, _ in
                refreshCabinetIfNeeded()
            }
            .onChange(of: selectedMarginaliaPackID) { _, _ in
                refreshMarginaliaAchievements(announce: false)
                invalidateExports()
            }
            .onChange(of: marginaliaAchievementSignature) { _, _ in
                refreshMarginaliaAchievements()
            }
            .onChange(of: completedMarginaliaAchievementsRaw) { _, _ in
                // Newly earned marks change which ones the drawer may deal and
                // which order a shelf lists, so the cabinet is re-filed.
                cabinet = PagewrightMarkCabinet(context: markContext, isUnlocked: isMarginaliaUnlocked)
            }
            #if canImport(PhotosUI)
            .onChange(of: pendingPersonalPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                pendingPersonalPhotoItems = []
                Task { await importPersonalPhotos(from: items) }
            }
            #endif
            .overlay(alignment: .bottom) {
                if let activeTutorNote {
                    MarginTutorNoteCard(note: activeTutorNote) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            self.activeTutorNote = nil
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: activeTutorNote.id) {
                        try? await Task.sleep(for: .seconds(12))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.5)) {
                            self.activeTutorNote = nil
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let notice = marginaliaUnlockNotice {
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            marginaliaUnlockNotice = nil
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "seal.fill")
                                .font(.title2.weight(.black))
                                .foregroundStyle(BookPalette.lampGold)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("A MARK CAME LOOSE")
                                    .font(.caption2.weight(.black))
                                    .tracking(0.9)
                                    .foregroundStyle(BookPalette.violet)
                                Text(notice.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(BookPalette.nightText)
                                Text(marginaliaUnlockNoticeLine(notice))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BookPalette.nightText.opacity(0.68))
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "xmark")
                                .font(.caption.weight(.black))
                                .foregroundStyle(BookPalette.nightText.opacity(0.42))
                        }
                        .padding(14)
                        .background(BookPalette.nightPanel.opacity(0.98), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.34), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: notice.questID) {
                        try? await Task.sleep(for: .seconds(7))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.4)) {
                            marginaliaUnlockNotice = nil
                        }
                    }
                }
            }
        }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            dayPicker
            searchField
            selectionHeader
            pageList
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var canvasPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                templateRail
                formatPicker
                scrapbookCanvas
                bindControls
            }
            .padding(18)
        }
        .frame(maxHeight: .infinity)
    }

    private var compactStudio: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 10) {
                compactHeader
                compactCanvasViewport

                // This must remain a bare Spacer. Once the findings were
                // attached to it, SwiftUI treated the decorated spacer as a
                // second flexible view and bargained canvas height away from
                // the Letter sheet.
                Spacer(minLength: 0)

                compactToolDock
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Findings are paint on top of the worktable, not a participant in
            // its vertical layout. A shallow fixed band sits immediately above
            // the 58pt drawer bank plus the stack's 10pt spacing. The paper can
            // therefore keep its original full width-derived Letter height.
            .overlay(alignment: .bottom) {
                looseFindingsShelf
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                    .padding(.bottom, 60)
            }

            if let activeTrayMode {
                compactTray(activeTrayMode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            pagewrightWorktableSurface
                .ignoresSafeArea(edges: .bottom)
        }
        .onPreferenceChange(CompactCanvasFramePreferenceKey.self) { frame in
            compactCanvasFrame = frame
        }
        .animation(.snappy(duration: 0.22), value: activeTrayMode?.id)
    }

    /// The page rests on one continuous worktable instead of a dark app panel.
    /// Letting this fill the studio also carries the table through the quiet
    /// space below the sheet and into the bottom safe area.
    private var pagewrightWorktableSurface: some View {
        ZStack {
            Image("PagewrightWorktableWood")
                .resizable()
                .scaledToFill()
            Color.black.opacity(0.20)
            LinearGradient(
                colors: [
                    BookPalette.nightPanel.opacity(0.30),
                    .clear,
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
        .accessibilityHidden(true)
    }

    /// The Pagewright's first appearance is a story beat with a small toolset,
    /// not the whole studio dropped into onboarding. The Book has already put
    /// the reader's three scraps on the table; they may rearrange them, change
    /// the paper, choose a line, and add photographs from their own world.
    private var inscriptionStudio: some View {
        ZStack(alignment: .bottom) {
            inscriptionWorktable

            // The marks tray slides up over the canvas exactly as it does in
            // the full studio.
            if let activeTrayMode, activeTrayMode == .marks {
                compactTray(activeTrayMode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            pagewrightWorktableSurface
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.snappy(duration: 0.22), value: activeTrayMode?.id)
    }

    private var inscriptionWorktable: some View {
        VStack(spacing: 10) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("THE PAGEWRIGHT HAS BEEN SUMMONED")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.lampGold)
                    Text("The Book is tired of asking questions.")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.nightText)
                    Text("\u{201C}Answers are loose things,\u{201D} it says. \u{201C}Make me a Page I can keep.\u{201D}\n\nA small person with ink on both elbows climbs onto the worktable. \u{201C}Two scraps from the door,\u{201D} says the Pagewright. \u{201C}And one of your photographs, if the outside world will lend us one.\u{201D}")
                        .font(.callout)
                        .foregroundStyle(BookPalette.nightText.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    personalPhotoPicker
                    TextField("Name this Page", text: pageTitleBinding)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.nightText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onChange(of: title) { _, _ in invalidateExports() }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
            .frame(maxHeight: 236)

            compactCanvasViewport

            worktableDrawerBank(columnCount: 4) { drawerWidth in
                compactToolMenu("Layout", "rectangle.grid.2x2", width: drawerWidth) { layoutMenuContent }
                compactToolMenu("Paper", "paintpalette", width: drawerWidth) { materialsMenuContent }
                compactToolButton("Marks", "seal", width: drawerWidth, isActive: activeTrayMode == .marks) {
                    toggleTray(.marks)
                }
                compactToolMenu("Line", "text.quote", width: drawerWidth) { quoteMenuContent }
            }

            Button {
                keepCurrentDraft()
                dismiss()
            } label: {
                Label("Give this Page to the Book", systemImage: "text.book.closed.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.lampGold)
            .disabled(!hasPrimaryCanvasContent)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var compactCanvasViewport: some View {
        ScrollView(.vertical, showsIndicators: false) {
            compactScrapbookCanvas
        }
        .scrollDismissesKeyboard(.interactively)
        // The scroll view used to greedily take all remaining height while
        // showing only the top of the Letter-shaped canvas. That made the
        // visible paper look like a short card and left bare timber before the
        // drawers. Give it one complete sheet instead; the drawers then follow
        // the lower deckled edge and the canvas still matches PNG/PDF geometry.
        .aspectRatio(612.0 / 792.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CompactCanvasFramePreferenceKey.self,
                    // Measure the paper and the dragged finding in the same
                    // screen-global space. A named coordinate space crossing
                    // the canvas ScrollView can report a release point that
                    // looks right under the finger but misses this frame.
                    value: proxy.frame(in: .global)
                )
            }
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 10) {
            TextField("Page title", text: pageTitleBinding)
                .font(.system(.headline, design: .serif, weight: .bold))
                .foregroundStyle(BookPalette.nightText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: title) { _, _ in invalidateExports() }

            Menu {
                formatMenuContent
            } label: {
                Label(format.title, systemImage: format.symbolName)
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
            }
            .foregroundStyle(BookPalette.nightPanel)
            .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var compactToolDock: some View {
        worktableDrawerBank(columnCount: 6) { drawerWidth in
            compactToolButton("Scraps", "tray.full", width: drawerWidth, isActive: activeTrayMode == .scraps) {
                toggleTray(.scraps)
            }
            compactToolMenu("Layout", "rectangle.grid.2x2", width: drawerWidth) { layoutMenuContent }
            compactToolMenu("Paper", "paintpalette", width: drawerWidth) { materialsMenuContent }
            compactToolButton("Marks", "seal", width: drawerWidth, isActive: activeTrayMode == .marks) {
                toggleTray(.marks)
            }
            compactToolMenu("Quote", "text.quote", width: drawerWidth) { quoteMenuContent }
            compactToolMenu("Export", "square.and.arrow.up", width: drawerWidth) { bindMenuContent }
        }
    }

    /// A few things the Pagewright has left within reach on the bare timber.
    ///
    /// These are real, earned cabinet marks rather than decorative copies.
    /// Tapping or dragging one uses the same placement chokepoint as the Marks
    /// drawer, and the finding is replaced by the next unlocked unused mark.
    /// Nothing here enters PNG/PDF output until it actually lands on the paper.
    private var looseFindingsShelf: some View {
        GeometryReader { proxy in
            let picks = looseFindingMarks
            let botanical = picks.first { isBotanicalFinding($0.asset) }
            let paperPicks = picks.filter { $0.asset.assetName != botanical?.asset.assetName }
            let shelfHeight = proxy.size.height
            let paperWidth = min(82, max(58, proxy.size.width * 0.20))
            let paperHeight = min(62, max(38, shelfHeight * 0.54))
            let botanicalHeight = min(112, max(44, shelfHeight * 0.84))
            let paperPositions: [CGPoint] = botanical == nil
                ? [
                    CGPoint(x: 0.20, y: 0.52),
                    CGPoint(x: 0.50, y: 0.47),
                    CGPoint(x: 0.80, y: 0.54)
                ]
                : [
                    CGPoint(x: 0.24, y: 0.54),
                    CGPoint(x: 0.76, y: 0.48)
                ]
            let paperRotations: [Double] = [-6.5, 5.0, -3.0]

            ZStack {
                Color.clear

                if shelfHeight >= 44, let botanical {
                    Button {
                        addPackMarginalia(botanical.asset)
                    } label: {
                        looseFindingBotanical(botanical.asset, height: botanicalHeight)
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees(-8))
                    .position(x: proxy.size.width * 0.50, y: shelfHeight * 0.51)
                    .offset(looseFindingDragOffset(for: botanical.asset))
                    .scaleEffect(isDraggingLooseFinding(botanical.asset) ? 1.04 : 1)
                    .shadow(color: .black.opacity(0.24), radius: 4, x: 1, y: 3)
                    .highPriorityGesture(looseFindingDragGesture(for: botanical.asset))
                    .accessibilityLabel("Place \(markAssetTitle(botanical.asset))")
                    .accessibilityHint("Tap to place it, or drag it onto the paper")
                    .zIndex(isDraggingLooseFinding(botanical.asset) ? 100 : 0)
                }

                if shelfHeight >= 44 {
                    ForEach(paperPicks.indices, id: \.self) { index in
                        let mark = paperPicks[index]
                        let position = paperPositions[min(index, paperPositions.count - 1)]
                        let rotation = paperRotations[min(index, paperRotations.count - 1)]

                        Button {
                            addPackMarginalia(mark.asset)
                        } label: {
                            looseFindingPaper(mark.asset, width: paperWidth, height: paperHeight)
                        }
                        .buttonStyle(.plain)
                        .rotationEffect(.degrees(rotation))
                        .position(x: proxy.size.width * position.x, y: shelfHeight * position.y)
                        .offset(looseFindingDragOffset(for: mark.asset))
                        .scaleEffect(isDraggingLooseFinding(mark.asset) ? 1.04 : 1)
                        .shadow(color: .black.opacity(0.30), radius: 4, x: 1, y: 3)
                        .highPriorityGesture(looseFindingDragGesture(for: mark.asset))
                        .accessibilityLabel("Place \(markAssetTitle(mark.asset))")
                        .accessibilityHint("Tap to place it, or drag it onto the paper")
                        .zIndex(isDraggingLooseFinding(mark.asset) ? 100 : 1)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: looseFindingDragState?.assetName) { previous, current in
            guard previous == nil, current != nil else { return }
            BookFeedback.pagewrightLift()
        }
    }

    private func looseFindingBotanical(
        _ asset: IlluminationAsset,
        height: CGFloat
    ) -> some View {
        Image(asset.assetName)
            .resizable()
            .scaledToFit()
            .opacity(asset.defaultOpacity * 0.84)
            .frame(width: height * 0.82, height: height)
            .contentShape(Rectangle())
    }

    private func looseFindingPaper(
        _ asset: IlluminationAsset,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let paperCut = DeckledPaperScrapShape(
            seed: "pagewright-loose-\(asset.assetName)".stableHash,
            amplitude: 1.6
        )
        return ZStack {
            paperCut
                .fill(BookPalette.paper.opacity(0.94))
            Image("ParchmentFiber")
                .resizable()
                .scaledToFill()
                .opacity(0.20)
                .clipShape(paperCut)
            Image(asset.assetName)
                .resizable()
                .scaledToFit()
                .opacity(asset.defaultOpacity)
                .padding(7)
        }
        .frame(width: width, height: height)
        .overlay {
            paperCut
                .stroke(BookPalette.nightPanel.opacity(0.26), lineWidth: 0.8)
        }
        .contentShape(paperCut)
    }

    private func isDraggingLooseFinding(_ asset: IlluminationAsset) -> Bool {
        looseFindingDragState?.assetName == asset.assetName
    }

    private func looseFindingDragOffset(for asset: IlluminationAsset) -> CGSize {
        guard isDraggingLooseFinding(asset) else { return .zero }
        return looseFindingDragState?.translation ?? .zero
    }

    /// The finding itself travels; there is no stationary source plus a native
    /// drag copy. An intentional upward carry is enough to hand it to the
    /// paper. The final point is clamped inside the canvas, and the cabinet then
    /// supplies the next unlocked finding through `looseFindingMarks`.
    private func looseFindingDragGesture(
        for asset: IlluminationAsset
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18, maximumDistance: 24)
            .sequenced(before: DragGesture(
                minimumDistance: 0,
                coordinateSpace: .global
            ))
            .updating($looseFindingDragState) { value, dragState, _ in
                switch value {
                case .first(true):
                    dragState = LooseFindingDragState(
                        assetName: asset.assetName,
                        translation: .zero
                    )
                case .second(true, let drag?):
                    dragState = LooseFindingDragState(
                        assetName: asset.assetName,
                        translation: drag.translation
                    )
                default:
                    break
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }

                // The findings begin below the sheet, so a deliberate upward
                // carry is an unambiguous canvas-drop intention. Do not veto it
                // with `frame.contains`: SwiftUI can briefly retain an older
                // preference frame while the overlaid source is moving, which
                // made a visibly valid drop silently snap back to the table.
                let travel = hypot(drag.translation.width, drag.translation.height)
                guard travel >= 18, drag.translation.height <= -10 else { return }

                let frame = compactCanvasFrame
                let placement: CGPoint
                if frame.width > 1, frame.height > 1 {
                    placement = CGPoint(
                        x: min(0.88, max(0.12,
                            (drag.location.x - frame.minX) / frame.width
                        )),
                        y: min(0.88, max(0.18,
                            (drag.location.y - frame.minY) / frame.height
                        ))
                    )
                } else {
                    // Even if layout has not published its first frame yet,
                    // never throw away a completed carry. Place it just inside
                    // the lower paper edge, where the reader can move it again.
                    placement = CGPoint(x: 0.5, y: 0.82)
                }
                addPackMarginalia(asset, at: placement, playsFeedback: false)
                BookFeedback.pagewrightDrop()
            }
    }

    /// Three stable quick-picks: first the Book's contextual suggestions, then
    /// today's drawer and the rest of the cabinet. Already placed marks step
    /// aside so using a finding always uncovers another one.
    private var looseFindingMarks: [IlluminationPackRegistry.ShelvedMark] {
        let placed = Set(
            canvasElements
                .filter { $0.kind == .marginaliaAsset }
                .map(\.sourceID)
        )
        let candidates = suggestedMarks
            + cabinet.marks(on: .theDrawer)
            + cabinet.shelves.flatMap { cabinet.marks(on: $0) }
        var seen = Set<String>()
        let available = candidates.filter { mark in
            let belongsLooseOnTable: Bool
            switch mark.asset.kind {
            case .paperScrap, .stamp, .doodle, .tape:
                belongsLooseOnTable = true
            case .background, .overlay:
                belongsLooseOnTable = false
            }
            return isMarginaliaUnlocked(mark.asset)
                && belongsLooseOnTable
                && !placed.contains(mark.asset.assetName)
                && seen.insert(mark.asset.assetName).inserted
        }

        var picks: [IlluminationPackRegistry.ShelvedMark] = []
        if let botanical = available.first(where: { isBotanicalFinding($0.asset) }) {
            picks.append(botanical)
        }
        let otherFindings = available.filter { candidate in
            !isBotanicalFinding(candidate.asset)
                && !picks.contains { $0.asset.assetName == candidate.asset.assetName }
        }
        picks.append(contentsOf: otherFindings.prefix(max(0, 3 - picks.count)))
        if picks.count < 3 {
            let remaining = available.filter { candidate in
                !picks.contains { $0.asset.assetName == candidate.asset.assetName }
            }
            picks.append(contentsOf: remaining.prefix(3 - picks.count))
        }
        return picks
    }

    private func isBotanicalFinding(_ asset: IlluminationAsset) -> Bool {
        let tags = Set(
            (asset.tags + (asset.leafTraits?.subjectTags ?? []))
                .map { $0.lowercased() }
        )
        return tags.contains("botanical") || tags.contains("pressed")
    }

    /// A narrow timber carcass keeps the generated drawer faces together. The
    /// labels remain native so Dynamic Type, VoiceOver, and menu hit targets do
    /// not get baked into the artwork.
    private func worktableDrawerBank<Content: View>(
        columnCount: Int,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) -> some View {
        let drawerHeight: CGFloat = 54
        let bankHeight: CGFloat = 58
        let spacing: CGFloat = 3
        let horizontalInset: CGFloat = 5

        // The generated drawer art has a very large intrinsic bitmap size.
        // Measure every cell from the actual phone width so that intrinsic
        // artwork can neither widen the studio nor push Export offscreen.
        return GeometryReader { proxy in
            let bankWidth = proxy.size.width
            let count = CGFloat(max(columnCount, 1))
            let rowWidth = max(0, bankWidth - (horizontalInset * 2))
            let totalSpacing = spacing * CGFloat(max(columnCount - 1, 0))
            let drawerWidth = max(0, (rowWidth - totalSpacing) / count)

            ZStack {
                ZStack {
                    Image("PagewrightWorktableWood")
                        .resizable()
                        .scaledToFill()
                    LinearGradient(
                        colors: [.white.opacity(0.10), .clear, .black.opacity(0.36)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: bankWidth, height: bankHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.black.opacity(0.66), lineWidth: 1.2)
                }

                HStack(spacing: spacing) {
                    content(drawerWidth)
                }
                .frame(width: rowWidth, height: drawerHeight, alignment: .leading)
            }
            .frame(width: bankWidth, height: bankHeight)
            .shadow(color: .black.opacity(0.38), radius: 10, x: 0, y: 6)
        }
        // GeometryReader is otherwise greedy in a vertical stack. This hard
        // stop is what gives the rest of the former shelf back to the paper.
        .frame(maxWidth: .infinity)
        .frame(height: bankHeight)
    }

    private func toggleTray(_ mode: PagewrightTrayMode) {
        activeTrayMode = activeTrayMode == mode ? nil : mode
        focusedScrapTextElementID = nil
        if activeTrayMode == .scraps {
            tutorTouch("scrapbook-scraps")
        } else if activeTrayMode == .marks {
            tutorTouch("scrapbook-marks")
        }
    }

    private func compactToolButton(
        _ title: String,
        _ symbol: String,
        width: CGFloat,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            compactDrawerFace(title, symbol: symbol, width: width, isActive: isActive)
        }
        .buttonStyle(.bookPress())
        .frame(width: width, height: 54)
        .zIndex(isActive ? 2 : 0)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private func compactToolMenu<Content: View>(
        _ title: String,
        _ symbol: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            compactDrawerFace(title, symbol: symbol, width: width, isActive: false)
        }
        .buttonStyle(.bookPress())
        .frame(width: width, height: 54)
        .accessibilityLabel(title)
    }

    private func compactDrawerFace(
        _ title: String,
        symbol: String,
        width: CGFloat,
        isActive: Bool
    ) -> some View {
        ZStack(alignment: .bottom) {
            Image("PagewrightDrawerFront")
                .resizable()
                .scaledToFill()
                .saturation(isActive ? 1.08 : 0.90)
                .brightness(isActive ? 0.06 : -0.04)
                .contrast(1.04)

            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 8.5, weight: .black, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isActive ? BookPalette.lampGold : BookPalette.paper)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(isActive ? 0.62 : 0.46))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(BookPalette.parchmentEdge.opacity(0.24), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.62), radius: 1, y: 1)
            .padding(.horizontal, 4)
            .padding(.bottom, 7)
        }
        // At this height the source artwork's transparent generation margin is
        // cropped away naturally while its roughly 2:1 wooden face keeps its
        // proportions. The former y-scale made every drawer look pinched.
        .frame(width: width, height: 54)
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: .black.opacity(isActive ? 0.62 : 0.34), radius: isActive ? 7 : 3, x: 0, y: isActive ? 7 : 3)
        .offset(y: isActive ? -8 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.76), value: isActive)
    }

    private func compactTray(_ mode: PagewrightTrayMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            trayHeader(mode)

            switch mode {
            case .scraps:
                scrapTrayContent
            case .marks:
                markTrayContent
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.115, blue: 0.085).opacity(0.98),
                            BookPalette.nightPanel.opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Image("ParchmentFiber")
                        .resizable()
                        .scaledToFill()
                        .saturation(0)
                        .opacity(0.075)
                        .blendMode(.softLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [BookPalette.lampGold, BookPalette.parchmentEdge],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 44, height: 5)
                .shadow(color: .black.opacity(0.46), radius: 2, y: 1)
                .padding(.top, 5)
        }
        .shadow(color: .black.opacity(0.26), radius: 18, y: 8)
        // Leave the drawer bank and its lifted active face visible beneath the
        // open tray. The old glass toolbar only needed 66 points here.
        .padding(.bottom, 82)
    }

    private func trayHeader(_ mode: PagewrightTrayMode) -> some View {
        HStack(spacing: 10) {
            Label(mode.title, systemImage: mode.symbolName)
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)
            Spacer()
            if mode == .scraps {
                Text(selectionLabel)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.nightPanel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BookPalette.lampGold, in: Capsule())
            } else {
                Text("\(selectedShelf.title) · \(cabinet.count(on: selectedShelf))")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                    .lineLimit(1)
            }
            Button {
                activeTrayMode = nil
                BookFeedback.pressTick()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.black))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BookPalette.nightText.opacity(0.72))
            .background(BookPalette.nightText.opacity(0.08), in: Circle())
            .accessibilityLabel("Close tray")
        }
    }

    private var scrapTrayContent: some View {
        VStack(spacing: 9) {
            personalPhotoPicker

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BookPalette.nightText.opacity(0.46))
                TextField("Search kept scraps", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(BookPalette.nightText)
                Menu {
                    Button("All kept days") { selectedDayID = PagewrightDayBucket.allID }
                    ForEach(buckets) { bucket in
                        Button("\(bucket.title) (\(bucket.count))") { selectedDayID = bucket.id }
                    }
                } label: {
                    Image(systemName: "calendar")
                        .font(.callout.weight(.bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.lampGold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(BookPalette.nightText.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PagewrightScrapTrayScope.allCases) { scope in
                        scrapScopeButton(scope)
                    }
                }
                .padding(.vertical, 1)
            }

            if trayFilteredPages.isEmpty {
                ContentUnavailableView("No matching scraps", systemImage: selectedScrapTrayScope.symbolName, description: Text("Try another filter, day, or search."))
                    .foregroundStyle(BookPalette.nightText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(trayFilteredPages) { page in
                            scrapTrayRow(page)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var personalPhotoPicker: some View {
        #if canImport(PhotosUI)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $pendingPersonalPhotoItems,
                    maxSelectionCount: 12,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        isImportingPersonalPhotos ? "Adding photos…" : "Add Your Photos",
                        systemImage: "photo.badge.plus"
                    )
                    .font(.caption.weight(.black))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(isImportingPersonalPhotos)

                if !personalPhotos.isEmpty {
                    Text("\(personalPhotos.count) on canvas")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.58))
                        .fixedSize()
                        .contentTransition(.numericText())
                }
            }

            if let personalPhotoImportMessage {
                Text(personalPhotoImportMessage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.58))
                    .bookResultArrival(reduceMotion: reduceMotion)
            }
        }
        .animation(BookMotion.result(reduceMotion), value: personalPhotos.count)
        #else
        EmptyView()
        #endif
    }

    #if canImport(PhotosUI)
    private func importPersonalPhotos(from items: [PhotosPickerItem]) async {
        await MainActor.run {
            isImportingPersonalPhotos = true
            personalPhotoImportMessage = nil
        }

        var imported: [PagewrightPersonalPhoto] = []
        var failedCount = 0
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let jpeg = PressedPhotograph.downscaledJPEG(from: raw),
                  let image = UIImage(data: jpeg),
                  image.size.width > 0,
                  image.size.height > 0 else {
                failedCount += 1
                continue
            }
            imported.append(
                PagewrightPersonalPhoto(
                    data: jpeg,
                    aspectRatio: image.size.width / image.size.height
                )
            )
        }

        await MainActor.run {
            for photo in imported {
                personalPhotos.append(photo)
                let element = defaultPersonalPhotoElement(
                    for: photo,
                    index: personalPhotos.count - 1
                )
                canvasElements.append(element)
                activeElementID = element.id
            }
            isImportingPersonalPhotos = false
            if imported.isEmpty {
                personalPhotoImportMessage = "Those photos could not be read."
                BookFeedback.play(.error)
            } else {
                let noun = imported.count == 1 ? "photo" : "photos"
                personalPhotoImportMessage = "Added \(imported.count) complete \(noun), without captions."
                returnToCanvasAfterPlacement()
                invalidateExports()
                BookFeedback.play(.select)
            }
            if failedCount > 0, !imported.isEmpty {
                personalPhotoImportMessage? += " \(failedCount) could not be read."
            }
        }
    }
    #endif

    #if canImport(Photos)
    private func seedOpeningLibraryPhoto() async {
        guard let photo = await PagewrightLibraryPhoto.random() else { return }
        await MainActor.run {
            // The spread stays three things: two kept scraps and one uncropped
            // photograph from the reader's library. The scrap dropped here is
            // the last one, which `openingScrapIDs` deliberately made the
            // photo-carrying keep — so the page ends up with exactly one
            // photograph either way, the reader's own by preference.
            if let replacedID = selectedIDs.last {
                selectedIDs.removeAll { $0 == replacedID }
                canvasElements.removeAll { $0.kind == .page && $0.sourceID == replacedID }
                editedPullQuotePageIDs.remove(replacedID)
            }
            personalPhotos.append(photo)
            let element = defaultPersonalPhotoElement(for: photo, index: 2)
            canvasElements.append(element)
            normalizeZOrder()
            activeElementID = element.id
            personalPhotoImportMessage = "The Pagewright borrowed one whole photograph from your library."
            invalidateExports()
        }
    }
    #endif

    private func scrapScopeButton(_ scope: PagewrightScrapTrayScope) -> some View {
        Button {
            selectedScrapTrayScope = scope
            BookFeedback.pressTick()
        } label: {
            Label(scope.title, systemImage: scope.symbolName)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedScrapTrayScope == scope ? BookPalette.nightPanel : BookPalette.nightText)
        .background(selectedScrapTrayScope == scope ? BookPalette.lampGold : BookPalette.nightText.opacity(0.07), in: Capsule())
        .disabled((scope == .sameType || scope == .sameDay) && activePage == nil)
        .opacity((scope == .sameType || scope == .sameDay) && activePage == nil ? 0.46 : 1)
    }

    private func scrapTrayRow(_ page: BookPage) -> some View {
        let isSelected = selectedIDs.contains(page.id)
        let cached = pageCache.cached(for: page)
        return Button {
            addSelectedPage(page.id)
            activePageID = page.id
            BookFeedback.pressTick()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? BookPalette.lampGold.opacity(0.20) : BookPalette.nightText.opacity(0.07))
                    if let preview = cached.firstVisualMediaAsset {
                        PagewrightMediaPreview(asset: preview)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        Image(systemName: page.type.symbolName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(isSelected ? BookPalette.lampGold : BookPalette.teal)
                    }
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(page.type.shortTitle)
                            .font(.caption.weight(.black))
                            .foregroundStyle(BookPalette.lampGold)
                        Text(cached.dateLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.52))
                    }
                    Text(cached.excerpt86)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.78))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.48))
            }
            .padding(8)
            .background(isSelected ? BookPalette.lampGold.opacity(0.12) : BookPalette.nightText.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var markTrayContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            markSearchField

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cabinet.shelves) { shelf in
                        shelfButton(shelf)
                    }
                }
                .padding(.vertical, 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedShelf.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.5))
                    .lineLimit(2)
                if let tally = shelfTally(selectedShelf) {
                    Text(tally)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.lampGold.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if selectedShelf == .thisMonth, let note = occasionNote {
                thisMonthNoteCard(note)
            }

            let marks = visibleMarks
            let elsewhere = searchResultsAcrossShelves

            if marks.isEmpty && elsewhere.isEmpty {
                ContentUnavailableView(
                    markSearchText.isEmpty ? "Nothing on this shelf" : "Nothing by that name",
                    systemImage: selectedShelf.symbolName,
                    description: Text(markSearchText.isEmpty ? selectedShelf.subtitle : "Try a shorter word.")
                )
                .foregroundStyle(BookPalette.nightText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if markSearchText.isEmpty {
                            suggestionRow
                        }
                        ForEach(marks) { mark in
                            markAssetTile(mark)
                        }
                        if !elsewhere.isEmpty {
                            elsewhereHeader(count: elsewhere.count)
                            ForEach(elsewhere) { mark in
                                markAssetTile(mark, showingShelf: true)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .confirmationDialog(
            "This mark is locked",
            isPresented: Binding(
                get: { pendingUnlockMarginalia != nil },
                set: { if !$0 { pendingUnlockMarginalia = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingUnlockMarginalia
        ) { asset in
            if !isMarginaliaHintRevealed(asset) {
                Button("Ask me what opens it") {
                    tutorTouch("scrapbook-achievements")
                    revealMarginaliaHint(asset)
                }
            }
            if isMarginaliaUnlocked(asset) {
                Button("Put mark on Page") {
                    addPackMarginalia(asset)
                    pendingUnlockMarginalia = nil
                }
            }
            Button("Leave it curled up", role: .cancel) { pendingUnlockMarginalia = nil }
        } message: { asset in
            let achievement = PagewrightMarginaliaAchievement.achievement(for: asset)
            if isMarginaliaUnlocked(asset) {
                Text("\(achievement.title)\nThe lock fell off. You can put the mark on the Page now.")
            } else if isMarginaliaHintRevealed(asset) {
                Text("\(achievement.title)\n\(achievement.revealedHint(in: marginaliaAchievementContext))\(lockCompanionLine(for: asset))\nMy edges are \(BookMechanicPresentation.glow(beliefScore).lowercased()) right now.")
            } else {
                Text("\(achievement.title)\n\(achievement.hiddenHint)\(lockCompanionLine(for: asset))\nMy edges are \(BookMechanicPresentation.glow(beliefScore).lowercased()) right now.")
            }
        }
    }

    /// How much of a shelf is already the reader's, and how much is still shut.
    ///
    /// Locks are worth showing rather than hiding: one quest usually opens a
    /// whole family at once, so "18 still curled up" reads as a prospect, not
    /// as eighteen separate errands.
    private func shelfTally(_ shelf: MarkShelf) -> String? {
        let marks = cabinet.marks(on: shelf)
        guard !marks.isEmpty else { return nil }
        let locked = marks.filter { !isMarginaliaUnlocked($0.asset) }.count
        guard locked > 0 else {
            return marks.count == 1 ? "One mark, and it is yours." : "All \(marks.count) are yours."
        }
        let open = marks.count - locked
        if open == 0 {
            return locked == 1 ? "One mark, still curled up." : "\(locked) marks, all still curled up."
        }
        return "\(open) open. \(locked) still curled up."
    }

    /// How many other marks fall to the same lock.
    ///
    /// Most quests open a family rather than a single image, and saying so
    /// turns one padlock into a reason to go and do the thing.
    private func marksSharingLock(with asset: IlluminationAsset) -> Int {
        let questID = PagewrightMarginaliaAchievement.achievement(for: asset).questID
        return cabinet.marksByShelf.values
            .flatMap { $0 }
            .filter { PagewrightMarginaliaAchievement.achievement(for: $0.asset).questID == questID }
            .count
    }

    private func lockCompanionLine(for asset: IlluminationAsset) -> String {
        let shared = marksSharingLock(with: asset)
        guard shared > 1 else { return "" }
        return "\nThe same lock holds \(shared - 1) other\(shared - 1 == 1 ? "" : "s")."
    }

    private var markSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BookPalette.nightText.opacity(0.46))
            TextField("Search every mark", text: $markSearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(BookPalette.nightText)
            if !markSearchText.isEmpty {
                Button {
                    markSearchText = ""
                    BookFeedback.pressTick()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BookPalette.nightText.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear mark search")
            }
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// What the Book says is going on this month, above the marks it loosened.
    private func thisMonthNoteCard(_ note: PagewrightOccasionNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
            Text(note.line)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(BookPalette.lampGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.3), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var suggestionRow: some View {
        let picks = suggestedMarks
        if !picks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("I would use these", systemImage: "hand.point.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                HStack(spacing: 8) {
                    ForEach(picks) { mark in
                        Button {
                            addPackMarginalia(mark.asset)
                        } label: {
                            Image(mark.asset.assetName)
                                .resizable()
                                .scaledToFit()
                                .opacity(mark.asset.defaultOpacity)
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(BookPalette.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Place \(markAssetTitle(mark.asset))")
                    }
                }
            }
            .padding(10)
            .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func elsewhereHeader(count: Int) -> some View {
        Text(count == 1 ? "One more, on another shelf" : "\(count) more, on other shelves")
            .font(.caption.weight(.black))
            .foregroundStyle(BookPalette.nightText.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    private func lockedMarginaliaBadgeText(for asset: IlluminationAsset) -> String {
        isMarginaliaHintRevealed(asset) ? "Hint" : "?"
    }

    private func lockedMarginaliaMenuTitle(for asset: IlluminationAsset) -> String {
        let title = markAssetTitle(asset)
        return isMarginaliaHintRevealed(asset) ? "\(title) · Hint" : "\(title) · Locked"
    }

    private func openMarginaliaLock(_ asset: IlluminationAsset) {
        if isMarginaliaUnlocked(asset) {
            tutorTouch("scrapbook-marks")
            addPackMarginalia(asset)
        } else {
            tutorTouch("scrapbook-achievements")
            pendingUnlockMarginalia = asset
            BookFeedback.pressTick()
        }
    }

    private func markAchievementSubtitle(for asset: IlluminationAsset) -> String {
        let achievement = PagewrightMarginaliaAchievement.achievement(for: asset)
        if isMarginaliaUnlocked(asset) {
            return "\(achievement.track.shortTitle) · Open · \(achievement.name)"
        }
        if isMarginaliaHintRevealed(asset) {
            return achievement.requirementSummary
        }
        return "\(achievement.track.shortTitle) · \(achievement.name)"
    }

    private func shelfButton(_ shelf: MarkShelf) -> some View {
        let selected = selectedShelf == shelf
        return Button {
            selectedShelf = shelf
            BookFeedback.pressTick()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: shelf.symbolName)
                Text(shelf.title)
                // The count is the invitation. A reader glancing at "Handwriting
                // 53" knows there is something in there worth opening; an
                // unlabelled chip is just another tab.
                Text("\(cabinet.count(on: shelf))")
                    .foregroundStyle(selected ? BookPalette.nightPanel.opacity(0.6) : BookPalette.nightText.opacity(0.4))
            }
            .font(.caption.weight(.black))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? BookPalette.nightPanel : BookPalette.nightText)
        .background(selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.07), in: Capsule())
        .accessibilityLabel("\(shelf.title), \(cabinet.count(on: shelf)) marks")
    }

    /// What the mark tray is showing right now: one shelf, narrowed by the
    /// search field if the reader has typed anything.
    private var visibleMarks: [IlluminationPackRegistry.ShelvedMark] {
        let marks = shelvedMarks(on: selectedShelf)
        let query = markSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return marks }
        return marks.filter { matches(query, $0) }
    }

    /// Searching looks past one shelf. A reader who types "moth" wants the moth
    /// wherever it is filed, and being told the shelf they happen to have open
    /// contains no moth is a worse answer than showing them the moth.
    private var searchResultsAcrossShelves: [IlluminationPackRegistry.ShelvedMark] {
        let query = markSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard query.count >= 2 else { return [] }
        let onThisShelf = Set(shelvedMarks(on: selectedShelf).map(\.id))
        let hits = MarkShelf.displayOrder
            .filter { $0 != .theDrawer && $0 != selectedShelf }
            .flatMap { cabinet.marks(on: $0) }
            .filter { matches(query, $0) && !onThisShelf.contains($0.id) }
        return Array(hits.prefix(24))
    }

    private func matches(_ query: String, _ mark: IlluminationPackRegistry.ShelvedMark) -> Bool {
        if markAssetTitle(mark.asset).lowercased().contains(query) { return true }
        if mark.asset.id.lowercased().contains(query) { return true }
        let searchable = mark.asset.tags + (mark.asset.leafTraits?.subjectTags ?? [])
        return searchable.contains { $0.lowercased().contains(query) }
    }

    /// Three marks the Book picked for what is already on the canvas.
    ///
    /// The cheapest good answer in the whole tray: no rummaging, high hit rate,
    /// and it is the kind of thing the Book would do unasked. Scored the same
    /// way illuminated photos score a pack — against the motifs actually on the
    /// page — rather than against the shelf the reader happens to be looking at.
    private var suggestedMarks: [IlluminationPackRegistry.ShelvedMark] {
        let motifs = Set(canvasMotifs.map { $0.lowercased() })
        guard !motifs.isEmpty else { return [] }

        var scored: [(mark: IlluminationPackRegistry.ShelvedMark, score: Int)] = []
        for mark in cabinet.marks(on: .theDrawer) where isMarginaliaUnlocked(mark.asset) {
            scored.append((mark, 0))
        }
        for shelf in MarkShelf.permanentShelves + [.thisMonth] {
            for mark in cabinet.marks(on: shelf) where isMarginaliaUnlocked(mark.asset) {
                let tags = Set(
                    (mark.asset.tags + (mark.asset.leafTraits?.subjectTags ?? []))
                        .map { $0.lowercased() }
                )
                let score = motifs.intersection(tags).count
                if score > 0 { scored.append((mark, score)) }
            }
        }
        let placed = Set(canvasElements.filter { $0.kind == .marginaliaAsset }.map(\.sourceID))
        var seen = Set<String>()
        return scored
            .filter { $0.score > 0 && !placed.contains($0.mark.asset.assetName) }
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.mark.id < rhs.mark.id : lhs.score > rhs.score
            }
            .filter { seen.insert($0.mark.asset.assetName).inserted }
            .prefix(3)
            .map(\.mark)
    }

    /// What the page is about, in tag words: the scraps on it and their types.
    private var canvasMotifs: [String] {
        var motifs: [String] = []
        for page in selectedPages {
            motifs.append(page.type.rawValue)
            motifs.append(contentsOf: page.tags)
        }
        motifs.append(selectedTemplate.rawValue)
        return motifs
    }

    private func markAssetTile(
        _ mark: IlluminationPackRegistry.ShelvedMark,
        showingShelf: Bool = false
    ) -> some View {
        let asset = mark.asset
        let unlocked = isMarginaliaUnlocked(asset)
        return Button {
            openMarginaliaLock(asset)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BookPalette.paper.opacity(0.78))
                    Image(asset.assetName)
                        .resizable()
                        .scaledToFit()
                        .opacity(unlocked ? asset.defaultOpacity : asset.defaultOpacity * 0.34)
                        .padding(8)
                    if !unlocked {
                        VStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.caption2.weight(.black))
                            Text(lockedMarginaliaBadgeText(for: asset))
                                .font(.caption2.weight(.black))
                        }
                        .foregroundStyle(BookPalette.nightPanel)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(BookPalette.lampGold.opacity(0.92), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 136)
                Text(markAssetTitle(asset))
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.nightText.opacity(unlocked ? 0.72 : 0.46))
                    .lineLimit(2)
                markProvenanceRow(mark, showingShelf: showingShelf)
                Text(markAchievementSubtitle(for: asset))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(unlocked ? 0.42 : 0.54))
                    .lineLimit(3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.nightText.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Where a mark came from, and — in search results — where it is filed.
    ///
    /// The pack used to be a mode the reader had to switch between, which meant
    /// the cabinet only ever looked one drawer deep. It reads better as a small
    /// label on the mark itself: two packs may both ship a moth, and knowing
    /// whose moth it is matters far less than seeing both.
    @ViewBuilder
    private func markProvenanceRow(
        _ mark: IlluminationPackRegistry.ShelvedMark,
        showingShelf: Bool
    ) -> some View {
        let showsPack = mark.packID != CoreMarginsPack.id
        if showsPack || showingShelf {
            HStack(spacing: 6) {
                if showingShelf {
                    markChip(mark.shelf.title, symbol: mark.shelf.symbolName)
                }
                if showsPack {
                    markChip(mark.packName, symbol: "shippingbox")
                }
            }
        }
    }

    private func markChip(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.black))
            .lineLimit(1)
            .foregroundStyle(BookPalette.nightText.opacity(0.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(BookPalette.nightText.opacity(0.07), in: Capsule())
    }

    @ViewBuilder
    private var scrapsMenuContent: some View {
        Menu("Day") {
            Button("All kept days") {
                selectedDayID = PagewrightDayBucket.allID
                BookFeedback.pressTick()
            }
            ForEach(buckets.prefix(18)) { bucket in
                Button("\(bucket.title) (\(bucket.count))") {
                    selectedDayID = bucket.id
                    BookFeedback.pressTick()
                }
            }
        }
        Divider()
        ForEach(filteredPages) { page in
            Button {
                addSelectedPage(page.id)
                BookFeedback.pressTick()
            } label: {
                Label(scrapPickerTitle(for: page), systemImage: selectedIDs.contains(page.id) ? "checkmark.circle.fill" : page.type.symbolName)
            }
        }
        Divider()
        Button("Clear scraps", role: .destructive) {
            selectedIDs.removeAll()
            editedPullQuotePageIDs.removeAll()
            activePageID = nil
            activeElementID = nil
            canvasElements.removeAll { $0.kind == .page }
            invalidateExports()
            BookFeedback.pressTick()
        }
        .disabled(selectedIDs.isEmpty)
    }

    @ViewBuilder
    private var layoutMenuContent: some View {
        Button {
            composeWithBook()
            BookFeedback.pressTick()
        } label: {
            Label("Compose with Book", systemImage: "wand.and.stars")
        }
        .disabled(keptPages.isEmpty)
        Divider()
        ForEach(PagewrightTemplate.allCases) { template in
            Button {
                applyTemplate(template, replaceSelection: false)
                BookFeedback.pressTick()
            } label: {
                Label(template.title, systemImage: selectedTemplate == template ? "checkmark" : template.symbolName)
            }
        }
        Divider()
        Button("Tidy selected layout") {
            resetCanvasLayout()
            BookFeedback.pressTick()
        }
    }

    @ViewBuilder
    private var formatMenuContent: some View {
        ForEach(PagewrightFormat.allCases) { option in
            Button {
                format = option
                BookFeedback.pressTick()
            } label: {
                Label(option.shareName, systemImage: format == option ? "checkmark" : option.symbolName)
            }
        }
    }

    @ViewBuilder
    private var materialsMenuContent: some View {
        Menu("Paper stock") {
            ForEach(PagewrightBackground.allCases) { option in
                Button {
                    background = option
                    invalidateExports()
                    BookFeedback.pressTick()
                } label: {
                    Label(option.title, systemImage: background == option ? "checkmark" : option.symbolName)
                }
            }
        }
        Menu("Paper tint") {
            ForEach(PagewrightPaperTintPreset.allCases) { preset in
                Button {
                    choosePaperTint(preset.tint)
                } label: {
                    Label(
                        preset.title,
                        systemImage: paperTint == preset.tint ? "checkmark.circle.fill" : "circle.fill"
                    )
                }
            }
            #if canImport(UIKit)
            Divider()
            ColorPicker("Any colour", selection: customPaperTintBinding, supportsOpacity: false)
            #endif
            if paperTints[background] != nil {
                Divider()
                Button("Return to \(background.title)") { restorePaperTint() }
            }
        }
        Menu("Printed marks") {
            ForEach(unlockedMarginaliaPacks) { pack in
                Button {
                    selectedMarginaliaPackID = pack.id
                    invalidateExports()
                    BookFeedback.pressTick()
                } label: {
                    Label(pack.displayName, systemImage: selectedMarginaliaPackID == pack.id ? "checkmark" : "shippingbox")
                }
            }
        }
        Divider()
        ForEach(PagewrightMarginaliaStyle.allCases) { option in
            Button {
                marginalia = option
                invalidateExports()
                BookFeedback.pressTick()
            } label: {
                Label(option.title, systemImage: marginalia == option ? "checkmark" : option.symbolName)
            }
        }
    }

    @ViewBuilder
    private var marginaliaMenuContent: some View {
        ForEach(cabinet.shelves) { shelf in
            marginaliaShelfMenu(shelf)
        }
        Divider()
        if let element = activeElement, element.kind == .marginaliaAsset {
            Button("Delete selected mark", role: .destructive) {
                deleteElement(element)
                BookFeedback.pressTick()
            }
        }
    }

    /// A menu is not a gallery: it lists the first dozen and the tray holds the
    /// rest. That is a reasonable limit *because* the shelf is already a
    /// meaningful slice — the old menu applied the same limit to a category
    /// holding 219 marks, which is where most of the cabinet went missing.
    @ViewBuilder
    private func marginaliaShelfMenu(_ shelf: MarkShelf) -> some View {
        let marks = shelvedMarks(on: shelf)
        if marks.isEmpty {
            Button(shelf.title) {}
                .disabled(true)
        } else {
            Menu("\(shelf.title) (\(marks.count))") {
                ForEach(marks.prefix(12)) { mark in
                    Button {
                        openMarginaliaLock(mark.asset)
                    } label: {
                        Label(
                            isMarginaliaUnlocked(mark.asset)
                                ? markAssetTitle(mark.asset)
                                : lockedMarginaliaMenuTitle(for: mark.asset),
                            systemImage: isMarginaliaUnlocked(mark.asset)
                                ? markAssetSymbol(mark.asset.kind)
                                : "lock"
                        )
                    }
                }
                if marks.count > 12 {
                    Divider()
                    Button("Open the \(shelf.title) shelf") {
                        selectedShelf = shelf
                        activeTrayMode = .marks
                        BookFeedback.pressTick()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var quoteMenuContent: some View {
        if let page = activePage {
            let cached = pageCache.cached(for: page)
            ForEach(cached.pullQuoteOptions.prefix(5), id: \.self) { option in
                Button {
                    pullQuotes[page.id] = option
                    editedPullQuotePageIDs.insert(page.id)
                    invalidateExports()
                    BookFeedback.pressTick()
                } label: {
                    Label(option, systemImage: pullQuotes[page.id] == option ? "checkmark" : "quote.opening")
                }
            }
        } else {
            Text("Select a scrap first")
        }
    }

    @ViewBuilder
    private var bindMenuContent: some View {
        Button {
            bindCurrentDraft()
            BookFeedback.pressTick()
        } label: {
            Label("Make PDF", systemImage: "doc.richtext")
        }
        .disabled(!hasPrimaryCanvasContent)
        Button {
            renderCurrentPNG()
            BookFeedback.pressTick()
        } label: {
            Label("Make PNG", systemImage: "photo")
        }
        .disabled(!hasPrimaryCanvasContent)
        Button {
            keepCurrentDraft()
            BookFeedback.pressTick()
        } label: {
            Label("Keep in Book", systemImage: "book.closed")
        }
        .disabled(!hasPrimaryCanvasContent)
        Divider()
        if let sharedURL {
            ShareLink(item: sharedURL) {
                Label("Share PDF", systemImage: "square.and.arrow.up")
            }
        }
        if let sharedPNGURL {
            ShareLink(item: sharedPNGURL) {
                Label("Share PNG", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            bindMenuContent
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .foregroundStyle(BookPalette.lampGold)
        .disabled(!hasPrimaryCanvasContent)
    }

    private var templateRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Templates", systemImage: "sparkles.rectangle.stack")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BookPalette.nightText)
                Spacer()
                Button {
                    composeWithBook()
                } label: {
                    Label("Compose", systemImage: "wand.and.stars")
                        .font(.caption.weight(.black))
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.lampGold)
                .disabled(keptPages.isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PagewrightTemplate.allCases) { template in
                        templateButton(template)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func templateButton(_ template: PagewrightTemplate) -> some View {
        Button {
            applyTemplate(template, replaceSelection: false)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: template.symbolName)
                    Text(template.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .font(.caption.weight(.black))

                Text(template.detail)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle((selectedTemplate == template ? BookPalette.nightPanel : BookPalette.nightText).opacity(0.68))
            }
            .frame(width: 140, alignment: .topLeading)
            .frame(minHeight: 76, alignment: .topLeading)
            .padding(10)
            .foregroundStyle(selectedTemplate == template ? BookPalette.nightPanel : BookPalette.nightText)
            .background(selectedTemplate == template ? BookPalette.lampGold : BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selectedTemplate == template ? BookPalette.lampGold.opacity(0.7) : BookPalette.nightText.opacity(0.10), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleFields
                styleControls
                packMarginaliaControls
                selectedItemControls
                pinnedNoteControls
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add photos or pick from any kept day.", systemImage: "photo.on.rectangle.angled")
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)

            Text("Place your own complete photos with no captions, or drag kept pages into the canvas. Then layer on notes, marks, and page styling.")
                .font(.callout)
                .foregroundStyle(BookPalette.nightText.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            personalPhotoPicker
        }
        .padding(14)
        .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
            }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                dayChip(id: PagewrightDayBucket.allID, title: "All", count: keptPages.count)
                ForEach(buckets) { bucket in
                    dayChip(id: bucket.id, title: bucket.title, count: bucket.count)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func dayChip(id: String, title: String, count: Int) -> some View {
        Button {
            selectedDayID = id
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .font(.caption2.weight(.black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((selectedDayID == id ? BookPalette.nightPanel : BookPalette.nightText.opacity(0.12)), in: Capsule())
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(selectedDayID == id ? BookPalette.nightPanel : BookPalette.nightText.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selectedDayID == id ? BookPalette.lampGold : BookPalette.nightText.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BookPalette.nightText.opacity(0.45))
            TextField("Search kept pages", text: $searchText)
                .textInputAutocapitalization(.never)
                .foregroundStyle(BookPalette.nightText)
        }
        .padding(10)
        .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.nightText.opacity(0.10), lineWidth: 1)
        }
    }

    private func scrapPickerTitle(for page: BookPage) -> String {
        let cached = pageCache.cached(for: page)
        let excerpt = cached.excerpt42
            .replacingOccurrences(of: "\n", with: " ")
        return "\(page.type.shortTitle) (\(cached.dateLabel)) \(excerpt)"
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Form")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.58))

            Picker("Form", selection: $format) {
                ForEach(PagewrightFormat.allCases) { option in
                    Label(option.title, systemImage: option.symbolName)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            Label(format.detail, systemImage: format.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.64))
        }
    }

    private var titleFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Title", text: pageTitleBinding)
                .textFieldStyle(.roundedBorder)
                .onChange(of: title) { _, _ in invalidateExports() }

            TextField("A short note for the page", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .onChange(of: note) { _, _ in invalidateExports() }
                .inkFeedback(text: note)
        }
    }

    private var selectionHeader: some View {
        HStack(spacing: 10) {
            Text("Kept Pages")
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)
            Text(selectionLabel)
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.nightPanel)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(BookPalette.lampGold, in: Capsule())
            Spacer()
            Button("Clear") {
                selectedIDs.removeAll()
                editedPullQuotePageIDs.removeAll()
                activePageID = nil
                activeElementID = nil
                canvasElements.removeAll { $0.kind == .page }
                pinnedNotes.removeAll()
                canvasElements.removeAll { $0.kind == .note }
                invalidateExports()
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.teal)
            .disabled(selectedIDs.isEmpty)
        }
    }

    @ViewBuilder
    private var pageList: some View {
        if keptPages.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("No kept pages yet", systemImage: "tray")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BookPalette.nightText)
                Text("You can still make a page from your own photos above, or keep a few pages first to add scraps.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredPages) { page in
                        pageRow(page)
                    }
                }
            }
            .frame(maxHeight: 520)
        }
    }

    private var scrapbookCanvas: some View {
        scrapbookCanvasView(minHeight: 520, showsHeader: true)
    }

    private var compactScrapbookCanvas: some View {
        scrapbookCanvasView(minHeight: 0, showsHeader: false)
    }

    private func scrapbookCanvasView(minHeight: CGFloat, showsHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                HStack {
                    Label("Canvas", systemImage: "rectangle.on.rectangle.angled")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(BookPalette.nightText)
                    Spacer()
                    Text(selectionLabel)
                        .font(.caption.weight(.black))
                        .foregroundStyle(BookPalette.nightPanel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BookPalette.lampGold, in: Capsule())
                }
            }

            GeometryReader { proxy in
                let canvasSize = proxy.size
                let paperCut = PagewrightPaperDeckle.shape(
                    for: background,
                    in: CGRect(origin: .zero, size: canvasSize)
                )
                ZStack(alignment: .topLeading) {
                    pageBackground
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard activeElementID != nil else { return }
                            activeElementID = nil
                            editingScrapTextElementID = nil
                            focusedScrapTextElementID = nil
                            BookFeedback.pressTick()
                        }
                    marginaliaWash
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .allowsHitTesting(false)
                    canvasHeader
                        .padding(22)
                        .allowsHitTesting(false)

                    if canvasElements.isEmpty {
                        emptyCanvas
                            .padding(22)
                            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .center)
                    } else {
                        ForEach(canvasElements) { element in
                            canvasElement(element, canvasSize: canvasSize)
                                .transition(canvasElementTransition)
                        }
                    }

                    // The rail would otherwise trail a moving scrap by a whole
                    // gesture, since the studio only hears the new placement
                    // once the hand lets go.
                    if let element = activeElement, !isManipulatingElement {
                        selectedElementHUD(element)
                            .position(
                                x: min(canvasSize.width - 104, max(104, element.x * canvasSize.width)),
                                y: min(canvasSize.height - 28, max(32, element.y * canvasSize.height - 78))
                            )
                            .zIndex(10_000)
                    }
                }
                .dropDestination(for: String.self) { ids, location in
                    let includesMarginalia = ids.contains {
                        marginaliaAsset(fromDragPayload: $0) != nil
                    }
                    for (offset, id) in ids.enumerated() {
                        let placement = CGPoint(
                            x: min(0.88, max(0.12, location.x / max(1, canvasSize.width) + CGFloat(offset) * 0.03)),
                            y: min(0.88, max(0.18, location.y / max(1, canvasSize.height) + CGFloat(offset) * 0.03))
                        )
                        if let asset = marginaliaAsset(fromDragPayload: id) {
                            addPackMarginalia(asset, at: placement, playsFeedback: false)
                        } else {
                            addSelectedPage(id, at: placement)
                        }
                    }
                    if includesMarginalia {
                        BookFeedback.pagewrightDrop()
                    } else {
                        BookFeedback.pressTick()
                    }
                    return true
                }
                .transaction { transaction in
                    if isManipulatingElement {
                        transaction.animation = nil
                    }
                }
                .animation(
                    (reduceMotion || isManipulatingElement) ? nil : .spring(response: 0.42, dampingFraction: 0.78),
                    value: canvasElements
                )
                .clipShape(paperCut)
                .contentShape(paperCut)
                .overlay {
                    paperCut
                        .stroke(paperTint.accentInk.color.opacity(0.30), lineWidth: 1)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 7)
            }
            .aspectRatio(612.0 / 792.0, contentMode: .fit)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        }
    }

    private func selectedElementHUD(_ element: PagewrightCanvasElement) -> some View {
        HStack(spacing: 4) {
            if element.kind == .page {
                if editingScrapTextElementID == element.id {
                    canvasHUDButton("Done editing", "checkmark") {
                        focusedScrapTextElementID = nil
                        editingScrapTextElementID = nil
                        BookFeedback.pressTick()
                    }
                } else {
                    canvasHUDButton("Edit text", "text.cursor") {
                        activeElementID = element.id
                        activePageID = element.sourceID
                        editingScrapTextElementID = element.id
                        focusedScrapTextElementID = element.id
                        BookFeedback.pressTick()
                    }
                }
                canvasHUDButton(element.isTextBold ? "Bold on" : "Bold", "bold") {
                    toggleScrapTextBold(element.id)
                    BookFeedback.pressTick()
                }
                canvasHUDButton(element.isTextItalic ? "Italic on" : "Italic", "italic") {
                    toggleScrapTextItalic(element.id)
                    BookFeedback.pressTick()
                }
            }
            canvasHUDButton("Send backward", "square.2.layers.3d.bottom.filled") {
                sendElementBackward(element.id)
                BookFeedback.pressTick()
            }
            canvasHUDButton("Bring forward", "square.2.layers.3d.top.filled") {
                bringElementForward(element.id)
                BookFeedback.pressTick()
            }
            canvasHUDButton("Duplicate", "plus.square.on.square") {
                duplicateElement(element)
                BookFeedback.play(.select)
            }
            canvasHUDButton("Delete", "trash") {
                deleteElement(element)
                BookFeedback.pressTick()
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(BookPalette.lampGold.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }

    private func canvasHUDButton(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bookPress(scale: 0.9, playsHaptic: false))
        .foregroundStyle(symbol == "trash" ? Color.red.opacity(0.82) : BookPalette.nightText)
        .background(BookPalette.paper.opacity(0.72), in: Circle())
        .accessibilityLabel(label)
    }

    private var canvasElementTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .scale(scale: 0.78, anchor: .center).combined(with: .opacity),
            removal: .scale(scale: 0.94, anchor: .center).combined(with: .opacity)
        )
    }

    private var canvasHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? format.shareName)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(paperTint.primaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note)
                    .font(.system(.callout, design: .serif))
                    .italic()
                    .foregroundStyle(paperTint.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(paperTint.color.opacity(0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(paperTint.accentInk.color.opacity(0.24), lineWidth: 1)
        }
    }

    private var emptyCanvas: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add a photo or kept page", systemImage: "hand.draw")
                .font(.headline.weight(.bold))
            Text("Choose your own photos above, tap a page in the archive, or drag a scrap into the canvas.")
                .font(.callout)
        }
        .foregroundStyle(paperTint.secondaryInk.color)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
        .background(paperTint.color.opacity(0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(paperTint.accentInk.color.opacity(0.24), lineWidth: 1)
        }
    }

    private var pageBackground: some View {
        ZStack {
            paperTint.color

            if let textureName = background.textureAssetName {
                Image(textureName)
                    .resizable()
                    .scaledToFill()
                    .saturation(0)
                    .contrast(1.06)
                    .opacity(background.textureOpacity)
                    .blendMode(.multiply)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
            }

            switch background {
            case .ledger:
                VStack(spacing: 28) {
                    ForEach(0..<18, id: \.self) { _ in
                        Rectangle()
                            .fill(paperTint.accentInk.color.opacity(0.12))
                            .frame(height: 1)
                    }
                }
            case .night:
                LinearGradient(
                    colors: [Color.white.opacity(0.07), Color.black.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var marginaliaWash: some View {
        HStack {
            Spacer()
            VStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { _ in
                    Image(systemName: marginalia.symbolName)
                        .font(.title.weight(.light))
                        .foregroundStyle(paperTint.accentInk.color.opacity(0.20))
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private func canvasElement(_ element: PagewrightCanvasElement, canvasSize: CGSize) -> some View {
        PagewrightElementStage(
            element: element,
            canvasSize: canvasSize,
            minWidth: minimumWidth(for: element.kind),
            maxWidth: maximumWidth(for: element.kind),
            isInteractive: editingScrapTextElementID != element.id,
            onBegin: { beginElementManipulation(element) },
            onCommit: { placement in commitPlacement(placement, to: element.id) }
        ) {
            canvasElementContent(element, canvasSize: canvasSize)
        }
        .zIndex(Double(element.z))
    }

    @ViewBuilder
    private func canvasElementContent(_ element: PagewrightCanvasElement, canvasSize: CGSize) -> some View {
        switch element.kind {
        case .page:
            if selectedIDs.contains(element.sourceID),
               let page = pageCache.page(for: element.sourceID) ?? keptPages.first(where: { $0.id == element.sourceID }) {
                selectedScrap(page, element: element, canvasSize: canvasSize)
            }
        case .note:
            if let note = pinnedNotes.first(where: { $0.id == element.sourceID }) {
                freeformNote(note, element: element, canvasSize: canvasSize)
            }
        case .personalPhoto:
            if let photo = personalPhotos.first(where: { $0.id == element.sourceID }) {
                personalPhoto(photo, element: element, canvasSize: canvasSize)
            }
        case .marginaliaAsset:
            if let asset = marginaliaAsset(named: element.sourceID) {
                packMarginaliaAsset(asset, element: element, canvasSize: canvasSize)
            }
        }
    }

    private func personalPhoto(
        _ photo: PagewrightPersonalPhoto,
        element: PagewrightCanvasElement,
        canvasSize: CGSize
    ) -> some View {
        let isActive = activeElementID == element.id
        let photoWidth = element.width * canvasSize.width
        return Group {
            if let image = PagewrightPhotoImageCache.shared.image(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(BookPalette.teal.opacity(0.44))
            }
        }
        .frame(width: photoWidth)
        .contentShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(isActive ? BookPalette.lampGold.opacity(0.82) : Color.clear, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
        .onTapGesture {
            activeElementID = element.id
            BookFeedback.pressTick()
        }
        .onTapGesture(count: 2) {
            bringElementForward(element.id)
            BookFeedback.pressTick()
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            duplicateElement(element)
            BookFeedback.play(.select)
        }
        .contextMenu {
            pagewrightElementContextMenu(for: element)
        }
        .accessibilityLabel("Personal photo")
    }

    private func selectedScrap(_ page: BookPage, element: PagewrightCanvasElement, canvasSize: CGSize) -> some View {
        let cached = pageCache.cached(for: page)
        let quoteText = Binding<String>(
            get: { pullQuotes[page.id]?.nonEmpty ?? cached.pullQuote },
            set: { newValue in
                pullQuotes[page.id] = newValue
                editedPullQuotePageIDs.insert(page.id)
                invalidateExports()
            }
        )
        let isActive = activeElementID == element.id
        let isEditing = editingScrapTextElementID == element.id
        let scrapWidth = element.width * canvasSize.width
        let scale = min(1.28, max(0.68, scrapWidth / 230))
        let padding = 13 * scale
        let textWeight: Font.Weight = element.isTextBold ? .black : .semibold
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: page.type.symbolName)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(BookPalette.teal)
                Text(page.type.shortTitle)
                    .font(.system(size: 12 * scale, weight: .black))
                    .foregroundStyle(BookPalette.teal)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.42))
                    .frame(width: 18 * scale, height: 18 * scale)
                    .contentShape(Circle())
                    .onTapGesture {
                        BookFeedback.pressTick()
                        removeSelectedPage(page.id)
                    }
                    .accessibilityLabel("Remove scrap")
                    .accessibilityAddTraits(.isButton)
            }

            if let preview = cached.firstVisualMediaAsset {
                PagewrightMediaPreview(asset: preview)
                    .frame(height: 120 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            if isEditing {
                TextEditor(text: quoteText)
                    .font(.system(size: 20 * scale, weight: textWeight, design: .serif))
                    .pagewrightItalic(element.isTextItalic)
                    .foregroundStyle(BookPalette.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: scrapTextEditorHeight(for: quoteText.wrappedValue, width: scrapWidth - padding * 2, scale: scale))
                    .inkFeedback(text: quoteText.wrappedValue)
                    .focused($focusedScrapTextElementID, equals: element.id)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                focusedScrapTextElementID = nil
                                editingScrapTextElementID = nil
                                BookFeedback.pressTick()
                            }
                        }
                    }
                    .onAppear {
                        focusedScrapTextElementID = element.id
                    }
            } else {
                Text(quoteText.wrappedValue)
                    .font(.system(size: 20 * scale, weight: textWeight, design: .serif))
                    .pagewrightItalic(element.isTextItalic)
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activePageID = page.id
                        activeElementID = element.id
                    }
                    .onTapGesture(count: 2) {
                        activePageID = page.id
                        activeElementID = element.id
                        editingScrapTextElementID = element.id
                        focusedScrapTextElementID = element.id
                        BookFeedback.pressTick()
                    }
            }

            Text(cached.dateLabel)
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.46))
        }
        .padding(padding)
        .frame(width: scrapWidth, alignment: .leading)
        .background(BookPalette.paper.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? BookPalette.lampGold.opacity(0.70) : BookPalette.ink.opacity(0.12), lineWidth: isActive ? 2 : 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .shadow(color: BookPalette.lampGold.opacity(isActive && !isManipulatingElement ? 0.16 : 0), radius: 14, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            BookFeedback.pressTick()
            activePageID = page.id
            activeElementID = element.id
        }
        .onTapGesture(count: 2) {
            bringElementForward(element.id)
            BookFeedback.pressTick()
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            duplicateElement(element)
            BookFeedback.play(.select)
        }
        .contextMenu {
            pagewrightElementContextMenu(for: element)
        }
        .onChange(of: focusedScrapTextElementID) { _, newValue in
            if editingScrapTextElementID == element.id && newValue != element.id {
                editingScrapTextElementID = nil
            }
        }
    }

    private func scrapTextEditorHeight(for text: String, width: CGFloat, scale: CGFloat) -> CGFloat {
        let averageCharacterWidth = max(7, 10 * scale)
        let charactersPerLine = max(12, Int(width / averageCharacterWidth))
        let wrappedLines = text
            .components(separatedBy: .newlines)
            .map { max(1, Int(ceil(Double(max(1, $0.count)) / Double(charactersPerLine)))) }
            .reduce(0, +)
        return CGFloat(min(7, max(2, wrappedLines))) * 27 * scale
    }

    private func packMarginaliaAsset(_ asset: IlluminationAsset, element: PagewrightCanvasElement, canvasSize: CGSize) -> some View {
        let isActive = activeElementID == element.id
        let markWidth = element.width * canvasSize.width
        return ZStack(alignment: .topTrailing) {
            Image(asset.assetName)
                .resizable()
                .scaledToFit()
                .opacity(asset.defaultOpacity)
                .frame(width: markWidth)
                .padding(asset.kind == .overlay ? 0 : 4)
                .background(asset.kind == .paperScrap ? Color.white.opacity(0.08) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? BookPalette.lampGold.opacity(0.72) : Color.clear, lineWidth: 2)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if isActive {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(BookPalette.paper, BookPalette.ink.opacity(0.72))
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
                    .offset(x: 8, y: -8)
                    .onTapGesture {
                        BookFeedback.pressTick()
                        deleteElement(element)
                    }
                    .accessibilityLabel("Remove mark")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .onTapGesture {
            activeElementID = element.id
            BookFeedback.pressTick()
        }
        .onTapGesture(count: 2) {
            bringElementForward(element.id)
            BookFeedback.pressTick()
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            duplicateElement(element)
            BookFeedback.play(.select)
        }
        .contextMenu {
            pagewrightElementContextMenu(for: element)
        }
    }

    private func freeformNote(_ note: PagewrightPinnedNote, element: PagewrightCanvasElement, canvasSize: CGSize) -> some View {
        let isActive = activeElementID == element.id
        return Button {
            activeElementID = element.id
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: note.style.symbolName)
                    .foregroundStyle(note.style == .stamp ? BookPalette.teal : BookPalette.lampGold)
                Text(note.text)
                    .font(note.style == .stamp ? .caption.weight(.black) : .system(.callout, design: .serif))
                    .textCase(note.style == .stamp ? .uppercase : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(note.style == .stamp ? 9 : 11)
            .frame(width: element.width * canvasSize.width, alignment: .leading)
            .background(noteBackground(note.style), in: RoundedRectangle(cornerRadius: note.style == .stamp ? 4 : 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: note.style == .stamp ? 4 : 8, style: .continuous)
                    .stroke(isActive ? BookPalette.lampGold.opacity(0.75) : BookPalette.ink.opacity(note.style == .stamp ? 0.24 : 0.12), lineWidth: isActive ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 7, y: 3)
        }
        .buttonStyle(.bookPress(playsHaptic: false))
        .bookCardHover()
        .onTapGesture(count: 2) {
            bringElementForward(element.id)
            BookFeedback.pressTick()
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            duplicateElement(element)
            BookFeedback.play(.select)
        }
        .contextMenu {
            pagewrightElementContextMenu(for: element)
        }
    }

    @ViewBuilder
    private func pagewrightElementContextMenu(for element: PagewrightCanvasElement) -> some View {
        Button {
            duplicateElement(element)
            BookFeedback.play(.select)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        Button {
            bringElementForward(element.id)
            BookFeedback.pressTick()
        } label: {
            Label("Bring Forward", systemImage: "square.3.layers.3d.top.filled")
        }

        Divider()

        Button(role: .destructive) {
            deleteElement(element)
            BookFeedback.pressTick()
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    private func activateElementForInteraction(_ element: PagewrightCanvasElement) {
        if activeElementID != element.id {
            activeElementID = element.id
        }
        if element.kind == .page, activePageID != element.sourceID {
            activePageID = element.sourceID
        }
    }

    private func beginElementManipulation(_ element: PagewrightCanvasElement) {
        if !isManipulatingElement {
            isManipulatingElement = true
        }
        activateElementForInteraction(element)
    }

    /// The one write the studio takes from a whole drag, pinch or twist. The
    /// scrap carried the movement itself; this lands the result.
    private func commitPlacement(_ placement: PagewrightElementPlacement, to id: String) {
        updateElement(id) { item in
            item.x = placement.x
            item.y = placement.y
            item.width = clampedWidth(for: item.kind, proposed: placement.width)
            item.rotation = placement.rotation
        }
        // The scrap is already sitting exactly where this lands it, so the
        // commit must arrive unanimated; the studio gets its spring back on
        // the next pass, once the placement is no longer news.
        DispatchQueue.main.async {
            isManipulatingElement = false
        }
    }

    private func minimumWidth(for kind: PagewrightCanvasElement.Kind) -> CGFloat {
        kind == .note ? 0.18 : 0.12
    }

    private func maximumWidth(for kind: PagewrightCanvasElement.Kind) -> CGFloat {
        (kind == .marginaliaAsset || kind == .personalPhoto)
            ? 0.86
            : (kind == .note ? 0.46 : 0.62)
    }

    private func clampedWidth(for kind: PagewrightCanvasElement.Kind, proposed: CGFloat) -> CGFloat {
        min(maximumWidth(for: kind), max(minimumWidth(for: kind), proposed))
    }

    private func noteBackground(_ style: PagewrightPinnedNoteStyle) -> Color {
        switch style {
        case .margin: return BookPalette.paper.opacity(0.58)
        case .sticky: return BookPalette.lampGold.opacity(0.22)
        case .stamp: return BookPalette.teal.opacity(0.12)
        case .torn: return Color.white.opacity(0.52)
        }
    }

    private func paperSwatchButton(_ option: PagewrightBackground) -> some View {
        let selected = background == option
        let tint = paperTint(for: option)
        return Button {
            background = option
            invalidateExports()
            BookFeedback.pressTick()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    tint.color
                    if let textureName = option.textureAssetName {
                        Image(textureName)
                            .resizable()
                            .scaledToFill()
                            .saturation(0)
                            .contrast(1.06)
                            .opacity(option.textureOpacity)
                            .blendMode(.multiply)
                    }
                }
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.16),
                            lineWidth: selected ? 2 : 1
                        )
                }
                Text(option.title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(
                        selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.68)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title) paper")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func tintPresetButton(_ preset: PagewrightPaperTintPreset) -> some View {
        let selected = paperTint == preset.tint
        return Button {
            choosePaperTint(preset.tint)
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(preset.tint.color)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .stroke(
                                selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.22),
                                lineWidth: selected ? 3 : 1
                            )
                    }
                Text(preset.title)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.72))
            }
            .frame(width: 58)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tint paper \(preset.title)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Materials")
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)

            // A swatch grid rather than a segmented control: eight papers do
            // not fit across a phone, and paper is the one choice here that
            // should be made by looking at it rather than reading its name.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
                ForEach(PagewrightBackground.allCases) { option in
                    paperSwatchButton(option)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tint this \(background.title)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.76))
                    Spacer()
                    if paperTints[background] != nil {
                        Button("Undo tint") { restorePaperTint() }
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(PagewrightPaperTintPreset.allCases) { preset in
                            tintPresetButton(preset)
                        }
                        #if canImport(UIKit)
                        ColorPicker("Any colour", selection: customPaperTintBinding, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 38, height: 38)
                            .accessibilityLabel("Choose any paper tint")
                        #endif
                    }
                    .padding(.vertical, 2)
                }

                Text("The ink changes its coat. It refuses to disappear.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.58))
            }

            // Which pack the renderer prints *by itself*. It no longer gates
            // what the reader can reach: the mark shelves span every unlocked
            // pack, so this picker stopped being a door and became a style.
            Picker("Printed marks", selection: $selectedMarginaliaPackID) {
                ForEach(unlockedMarginaliaPacks) { pack in
                    Text(pack.displayName).tag(pack.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedMarginaliaPackID) { _, _ in invalidateExports() }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                ForEach(PagewrightMarginaliaStyle.allCases) { option in
                    Button {
                        marginalia = option
                        invalidateExports()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbolName)
                                .font(.title3.weight(.semibold))
                            Text(option.title)
                                .font(.caption2.weight(.bold))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .foregroundStyle(marginalia == option ? BookPalette.nightPanel : BookPalette.nightText.opacity(0.74))
                        .background(marginalia == option ? BookPalette.lampGold : BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var packMarginaliaControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Marks by the handful", systemImage: "seal")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BookPalette.nightText)
                Spacer()
            }

            // One button per shelf that actually has something on it, rather
            // than six fixed labels that stopped describing the cabinet.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                ForEach(cabinet.shelves) { shelf in
                    shelfSprinkleButton(shelf)
                }
            }
        }
        .padding(14)
        .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func shelfSprinkleButton(_ shelf: MarkShelf) -> some View {
        Button {
            addPackMarginalia(from: shelf, count: shelf == .wear ? 1 : 2)
        } label: {
            Label(shelf.title, systemImage: shelf.symbolName)
                .font(.caption.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(BookPalette.lampGold)
    }

    @ViewBuilder
    private var selectedItemControls: some View {
        if let element = activeElement {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(selectedElementTitle(for: element), systemImage: selectedElementSymbol(for: element))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(BookPalette.nightText)
                    Spacer()
                    Button {
                        deleteElement(element)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Text("Drag to move. Pinch to resize. Twist to rotate. Double-tap to bring forward; long-press to copy.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    studioButton("Back", "square.2.layers.3d.bottom.filled") {
                        sendElementBackward(element.id)
                    }
                    studioButton("Front", "square.2.layers.3d.top.filled") {
                        bringElementForward(element.id)
                    }
                }

                HStack(spacing: 8) {
                    studioButton("Copy", "plus.square.on.square") {
                        duplicateElement(element)
                    }
                    studioButton("Tidy", "sparkles.rectangle.stack") {
                        resetCanvasLayout()
                    }
                }
            }
            .padding(14)
            .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func studioButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(BookPalette.lampGold)
    }

    private func selectedElementTitle(for element: PagewrightCanvasElement) -> String {
        switch element.kind {
        case .page: return "Selected Scrap"
        case .note: return "Selected Note"
        case .personalPhoto: return "Selected Photo"
        case .marginaliaAsset: return "Selected Marginalia"
        }
    }

    private func selectedElementSymbol(for element: PagewrightCanvasElement) -> String {
        switch element.kind {
        case .page: return "rectangle.on.rectangle"
        case .note: return "note.text"
        case .personalPhoto: return "photo"
        case .marginaliaAsset: return "seal"
        }
    }

    @ViewBuilder
    private var quoteControls: some View {
        if let page = activePage {
            let cached = pageCache.cached(for: page)
            VStack(alignment: .leading, spacing: 12) {
                Text("Pull Quote")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BookPalette.nightText)
                Text(page.type.shortTitle)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)

                ForEach(cached.pullQuoteOptions.prefix(4), id: \.self) { option in
                    Button {
                        pullQuotes[page.id] = option
                        editedPullQuotePageIDs.insert(page.id)
                        invalidateExports()
                    } label: {
                        Text(option)
                            .font(.system(.callout, design: .serif, weight: .semibold))
                            .foregroundStyle(BookPalette.nightText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background((pullQuotes[page.id] == option ? BookPalette.lampGold.opacity(0.18) : BookPalette.nightText.opacity(0.055)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                TextField("Write your own pull quote", text: Binding(
                    get: { pullQuotes[page.id] ?? cached.pullQuote },
                    set: {
                        pullQuotes[page.id] = $0
                        editedPullQuotePageIDs.insert(page.id)
                        invalidateExports()
                    }
                ), axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            }
            .padding(14)
            .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var pinnedNoteControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pinned Notes")
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)

            Picker("Note style", selection: $noteStyle) {
                ForEach(PagewrightPinnedNoteStyle.allCases) { style in
                    Label(style.title, systemImage: style.symbolName).tag(style)
                }
            }
            .pickerStyle(.segmented)

            TextField("Write marginalia", text: $noteDraft, axis: .vertical)
                .lineLimit(2...4)
                .inkFeedback(text: noteDraft)
                .textFieldStyle(.roundedBorder)

            Button {
                let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                let note = PagewrightPinnedNote(text: text, style: noteStyle)
                pinnedNotes.append(note)
                canvasElements.append(defaultNoteElement(for: note.id, index: pinnedNotes.count - 1))
                activeElementID = canvasElements.last?.id
                noteDraft = ""
                invalidateExports()
            } label: {
                Label("Pin Note", systemImage: noteStyle.symbolName)
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.lampGold)
            .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func pageRow(_ page: BookPage) -> some View {
        let isSelected = selectedIDs.contains(page.id)
        let cached = pageCache.cached(for: page)
        return Button {
            if isSelected {
                activePageID = page.id
                activeElementID = canvasElements.first { $0.kind == .page && $0.sourceID == page.id }?.id
            } else {
                addSelectedPage(page.id)
            }
            invalidateExports()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : page.type.symbolName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? BookPalette.lampGold : BookPalette.teal)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(page.type.shortTitle)
                            .font(.caption.weight(.black))
                            .foregroundStyle(BookPalette.lampGold)
                        Text(cached.dateLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.48))
                    }
                    Text(cached.excerpt140)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.84))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (isSelected ? BookPalette.lampGold.opacity(0.13) : BookPalette.nightText.opacity(0.055)),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((isSelected ? BookPalette.lampGold : BookPalette.nightText).opacity(isSelected ? 0.34 : 0.10), lineWidth: 1)
            }
        }
        .buttonStyle(.bookPress(playsHaptic: false))
        .bookCardHover()
        .draggable(page.id)
        .accessibilityLabel("\(isSelected ? "Selected" : "Not selected") \(page.type.title)")
    }

    private var bindControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                bindMenuContent
            } label: {
                Label("Export \(format.shareName)", systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.lampGold)
            .disabled(!hasPrimaryCanvasContent)
        }
    }

    private var currentDraft: PagewrightDraft {
        PagewrightDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? format.shareName,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            format: format,
            template: selectedTemplate,
            pages: selectedPages,
            pullQuotes: pullQuotes,
            pinnedNotes: pinnedNotes,
            personalPhotos: personalPhotos,
            elements: canvasElements,
            background: background,
            paperTint: paperTint,
            marginalia: marginalia,
            marginaliaPackID: selectedMarginaliaPack.id
        )
    }

    @discardableResult
    private func bindCurrentDraft() -> URL? {
        tutorTouch("scrapbook-keep")
        let url = onExportPDF(currentDraft)
        sharedURL = url
        return url
    }

    @discardableResult
    private func renderCurrentPNG() -> URL? {
        tutorTouch("scrapbook-keep")
        let url = onExportPNG(currentDraft)
        sharedPNGURL = url
        return url
    }

    private func keepCurrentDraft() {
        tutorTouch("scrapbook-keep")
        let draft = currentDraft
        let pngURL = sharedPNGURL ?? renderCurrentPNG()
        let pdfURL = sharedURL
        onKeep(draft, pdfURL, pngURL)
    }

    private func addSelectedPage(_ id: String, at location: CGPoint? = nil) {
        guard let page = pageCache.page(for: id) ?? keptPages.first(where: { $0.id == id }) else { return }
        guard !selectedIDs.contains(id) else {
            activePageID = id
            activeElementID = canvasElements.first { $0.kind == .page && $0.sourceID == id }?.id
            if let location, let elementID = activeElementID {
                updateElement(elementID) { item in
                    item.x = location.x
                    item.y = location.y
                }
            }
            returnToCanvasAfterPlacement()
            return
        }
        selectedIDs.append(id)
        tutorTouch("scrapbook-scraps")
        activePageID = id
        pullQuotes[id] = pullQuotes[id] ?? pageCache.cached(for: page).pullQuote
        var element = defaultPageElement(for: id, index: selectedIDs.count - 1)
        if let location {
            element.x = location.x
            element.y = location.y
        }
        canvasElements.append(element)
        activeElementID = element.id
        returnToCanvasAfterPlacement()
        invalidateExports()
    }

    /// A tray is only a cupboard beside the worktable. Once something has
    /// landed, uncover the same Page and leave the new piece in the reader's
    /// hand so its canvas controls are ready.
    private func returnToCanvasAfterPlacement() {
        activeTrayMode = nil
    }

    private func removeSelectedPage(_ id: String) {
        selectedIDs.removeAll { $0 == id }
        editedPullQuotePageIDs.remove(id)
        canvasElements.removeAll { $0.kind == .page && $0.sourceID == id }
        if activePageID == id {
            activePageID = selectedIDs.first
        }
        if activeElementID.flatMap({ activeID in canvasElements.first { $0.id == activeID } }) == nil {
            activeElementID = canvasElements.first?.id
        }
        invalidateExports()
    }

    private func seedPullQuotes() {
        for page in selectedPages {
            pullQuotes[page.id] = pullQuotes[page.id] ?? pageCache.cached(for: page).pullQuote
        }
    }

    private func composeWithBook() {
        applyTemplate(selectedTemplate, replaceSelection: selectedIDs.isEmpty)
        if title == "A Page I Kept" || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = suggestedTitle(for: selectedTemplate)
        }
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            note = selectedTemplate.detail
        }
        if pinnedNotes.isEmpty {
            let note = PagewrightPinnedNote(
                text: suggestedMarginalia(for: selectedTemplate),
                style: suggestedNoteStyle(for: selectedTemplate)
            )
            pinnedNotes.append(note)
            canvasElements.append(templateNoteElement(for: note.id, index: 0, template: selectedTemplate))
        }
        applyTemplate(selectedTemplate, replaceSelection: false)
        activeElementID = canvasElements.first?.id
        invalidateExports()
    }

    private func applyTemplate(_ template: PagewrightTemplate, replaceSelection: Bool) {
        selectedTemplate = template
        format = template.format
        background = template.background
        marginalia = template.marginalia

        if replaceSelection || selectedIDs.isEmpty {
            selectedIDs = smartPages(for: template).map(\.id)
            activePageID = selectedIDs.first
            editedPullQuotePageIDs.formIntersection(selectedIDs)
        }

        seedPullQuotes()
        let freeformElements = canvasElements.filter {
            $0.kind == .marginaliaAsset || $0.kind == .personalPhoto
        }
        canvasElements.removeAll()
        for (index, id) in selectedIDs.enumerated() {
            canvasElements.append(templatePageElement(for: id, index: index, template: template))
        }
        for (index, note) in pinnedNotes.enumerated() {
            canvasElements.append(templateNoteElement(for: note.id, index: index, template: template))
        }
        canvasElements.append(contentsOf: freeformElements)
        normalizeZOrder()
        activeElementID = canvasElements.first?.id
        invalidateExports()
    }

    private func smartPages(for template: PagewrightTemplate) -> [BookPage] {
        let pool = (filteredPages.isEmpty ? keptPages : filteredPages)
        let sorted: [BookPage]
        switch template {
        case .polaroidScatter:
            sorted = pool.sorted {
                let leftHasVisual = pageCache.cached(for: $0).hasVisualMedia
                let rightHasVisual = pageCache.cached(for: $1).hasVisualMedia
                if leftHasVisual != rightHasVisual {
                    return leftHasVisual
                }
                return $0.createdAt > $1.createdAt
            }
        case .letterHome:
            sorted = pool.sorted {
                let left = pageCache.cached(for: $0).excerpt1000.count
                let right = pageCache.cached(for: $1).excerpt1000.count
                if left == right { return $0.createdAt > $1.createdAt }
                return left > right
            }
        case .fieldNotes:
            sorted = pool.sorted {
                if $0.type.rawValue == $1.type.rawValue { return $0.createdAt > $1.createdAt }
                return $0.type.rawValue < $1.type.rawValue
            }
        case .weeklyShrine:
            sorted = pool.sorted { $0.createdAt > $1.createdAt }
        case .memoryWall, .softChaos:
            sorted = pool.sorted { $0.createdAt > $1.createdAt }
        }
        return Array(sorted.prefix(template.defaultPageCount))
    }

    private func suggestedTitle(for template: PagewrightTemplate) -> String {
        switch template {
        case .memoryWall: return "A Wall of Kept Things"
        case .polaroidScatter: return "Small Proofs"
        case .letterHome: return "A Letter from the Margins"
        case .fieldNotes: return "Field Notes from the Book"
        case .weeklyShrine: return "This Week, Kept"
        case .softChaos: return "Soft Evidence"
        }
    }

    private func suggestedMarginalia(for template: PagewrightTemplate) -> String {
        switch template {
        case .memoryWall: return "Kept because these pieces still talk to each other."
        case .polaroidScatter: return "The visible evidence."
        case .letterHome: return "For the person who would understand why this mattered."
        case .fieldNotes: return "Observed, compared, kept."
        case .weeklyShrine: return "A small week, set out where you can see it."
        case .softChaos: return "The scraps voted against neatness."
        }
    }

    private func suggestedNoteStyle(for template: PagewrightTemplate) -> PagewrightPinnedNoteStyle {
        switch template {
        case .memoryWall, .letterHome: return .margin
        case .polaroidScatter, .softChaos: return .sticky
        case .fieldNotes: return .torn
        case .weeklyShrine: return .stamp
        }
    }

    private func syncCanvasElements() {
        canvasElements.removeAll { element in
            switch element.kind {
            case .page: return !selectedIDs.contains(element.sourceID)
            case .note: return !pinnedNotes.contains { $0.id == element.sourceID }
            case .personalPhoto: return !personalPhotos.contains { $0.id == element.sourceID }
            case .marginaliaAsset: return false
            }
        }
        for (index, id) in selectedIDs.enumerated()
            where !canvasElements.contains(where: { $0.kind == .page && $0.sourceID == id }) {
            canvasElements.append(defaultPageElement(for: id, index: index))
        }
        for (index, note) in pinnedNotes.enumerated()
            where !canvasElements.contains(where: { $0.kind == .note && $0.sourceID == note.id }) {
            canvasElements.append(defaultNoteElement(for: note.id, index: index))
        }
        normalizeZOrder()
    }

    private func defaultPageElement(for pageID: String, index: Int) -> PagewrightCanvasElement {
        templatePageElement(for: pageID, index: index, template: selectedTemplate)
    }

    private func templatePageElement(for pageID: String, index: Int, template: PagewrightTemplate) -> PagewrightCanvasElement {
        let placement = template.placement(for: index, kind: .page)
        return PagewrightCanvasElement(
            kind: .page,
            sourceID: pageID,
            x: placement.x,
            y: placement.y,
            width: placement.width,
            rotation: placement.rotation,
            z: nextZ
        )
    }

    private func defaultNoteElement(for noteID: String, index: Int) -> PagewrightCanvasElement {
        templateNoteElement(for: noteID, index: index, template: selectedTemplate)
    }

    private func defaultPersonalPhotoElement(
        for photo: PagewrightPersonalPhoto,
        index: Int
    ) -> PagewrightCanvasElement {
        let placements: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.50, 0.48, 0.52, 0),
            (0.34, 0.36, 0.40, -5),
            (0.66, 0.52, 0.38, 4),
            (0.42, 0.72, 0.36, -2),
            (0.70, 0.76, 0.30, 6)
        ]
        let placement = placements[index % placements.count]
        // Keep unusually tall photos wholly inside the initial canvas. The
        // reader can still enlarge them deliberately with the normal gesture.
        let fittedWidth = min(placement.2, max(0.16, photo.aspectRatio * 0.90))
        return PagewrightCanvasElement(
            kind: .personalPhoto,
            sourceID: photo.id,
            x: placement.0,
            y: placement.1,
            width: fittedWidth,
            rotation: placement.3,
            z: nextZ
        )
    }

    private func templateNoteElement(for noteID: String, index: Int, template: PagewrightTemplate) -> PagewrightCanvasElement {
        let placement = template.placement(for: index, kind: .note)
        return PagewrightCanvasElement(
            kind: .note,
            sourceID: noteID,
            x: placement.x,
            y: placement.y,
            width: placement.width,
            rotation: placement.rotation,
            z: nextZ
        )
    }

    private func addPackMarginalia(from shelf: MarkShelf, count: Int) {
        // Bulk placement only flows through marks whose achievements are already
        // complete. Locked marks can reveal hints, but never auto-place.
        let assets = shelvedMarks(on: shelf)
            .map(\.asset)
            .filter(isMarginaliaUnlocked)
            .prefix(max(1, count))
        guard !assets.isEmpty else { return }
        for (index, asset) in assets.enumerated() {
            canvasElements.append(packAssetElement(for: asset, index: index))
        }
        activeElementID = canvasElements.last?.id
        invalidateExports()
    }

    private func addPackMarginalia(
        _ asset: IlluminationAsset,
        at location: CGPoint? = nil,
        playsFeedback: Bool = true
    ) {
        // The single chokepoint: a still-locked mark routes to the achievement
        // and hint sheet instead of landing on the page.
        guard isMarginaliaUnlocked(asset) else {
            tutorTouch("scrapbook-achievements")
            pendingUnlockMarginalia = asset
            if playsFeedback { BookFeedback.pressTick() }
            return
        }
        tutorTouch("scrapbook-marks")
        var element = packAssetElement(for: asset, index: 0)
        if let location {
            element.x = location.x
            element.y = location.y
        }
        canvasElements.append(element)
        activeElementID = element.id
        returnToCanvasAfterPlacement()
        invalidateExports()
        if playsFeedback { BookFeedback.pressTick() }
    }

    private func marginaliaDragPayload(for asset: IlluminationAsset) -> String {
        "pagewright-marginalia::\(asset.assetName)"
    }

    private func marginaliaAsset(fromDragPayload payload: String) -> IlluminationAsset? {
        let prefix = "pagewright-marginalia::"
        guard payload.hasPrefix(prefix) else { return nil }
        return marginaliaAsset(named: String(payload.dropFirst(prefix.count)))
    }

    /// Marks on one shelf, earned ones first.
    ///
    /// No count argument, deliberately. The old signature took one and every
    /// caller passed a number that quietly hid the rest of the cabinet.
    private func shelvedMarks(on shelf: MarkShelf) -> [IlluminationPackRegistry.ShelvedMark] {
        let marks = cabinet.marks(on: shelf)
        let unlocked = marks.filter { isMarginaliaUnlocked($0.asset) }
        let locked = marks.filter { !isMarginaliaUnlocked($0.asset) }
        return unlocked + locked
    }

    private func markAssetTitle(_ asset: IlluminationAsset) -> String {
        asset.id
            .replacingOccurrences(of: "illumination_", with: "")
            .replacingOccurrences(of: "doodle_", with: "")
            .replacingOccurrences(of: "stamp_", with: "")
            .replacingOccurrences(of: "overlay_", with: "")
            .replacingOccurrences(of: "_01", with: "")
            .replacingOccurrences(of: "_02", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func markAssetSymbol(_ kind: IlluminationAssetKind) -> String {
        switch kind {
        case .background: return "photo"
        case .paperScrap: return "doc.on.doc"
        case .stamp: return "seal"
        case .doodle: return "sparkles"
        case .tape: return "paperclip"
        case .overlay: return "square.dashed"
        }
    }

    private func packAssetElement(for asset: IlluminationAsset, index: Int) -> PagewrightCanvasElement {
        let placements: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.18, 0.20, 0.20, -7),
            (0.82, 0.24, 0.18, 6),
            (0.16, 0.78, 0.22, 4),
            (0.84, 0.78, 0.20, -5),
            (0.50, 0.90, 0.28, 0)
        ]
        let placement = placements[(canvasElements.count + index) % placements.count]
        let width: CGFloat
        switch asset.kind {
        case .background, .overlay: width = 0.74
        case .paperScrap: width = 0.30
        case .stamp, .doodle, .tape: width = placement.2
        }
        return PagewrightCanvasElement(
            kind: .marginaliaAsset,
            sourceID: asset.assetName,
            x: placement.0,
            y: placement.1,
            width: width,
            rotation: placement.3,
            z: nextZ
        )
    }

    private func marginaliaAsset(named assetName: String) -> IlluminationAsset? {
        if let asset = cabinet.asset(named: assetName) { return asset }
        return PagewrightMarkCabinet(context: markContext, isUnlocked: isMarginaliaUnlocked)
            .asset(named: assetName)
    }

    private var nextZ: Int {
        (canvasElements.map(\.z).max() ?? 0) + 1
    }

    private func invalidateExports() {
        sharedURL = nil
        sharedPNGURL = nil
    }

    private func updateElement(_ id: String, mutate: (inout PagewrightCanvasElement) -> Void) {
        guard let index = canvasElements.firstIndex(where: { $0.id == id }) else { return }
        withTransaction(Transaction(animation: nil)) {
            mutate(&canvasElements[index])
            invalidateExports()
        }
    }

    private func toggleScrapTextBold(_ id: String) {
        updateElement(id) { item in
            item.isTextBold.toggle()
        }
    }

    private func toggleScrapTextItalic(_ id: String) {
        updateElement(id) { item in
            item.isTextItalic.toggle()
        }
    }

    private func resizeElement(_ id: String, delta: CGFloat) {
        updateElement(id) { item in
            item.width = clampedWidth(for: item.kind, proposed: item.width + delta)
        }
    }

    private func rotateElement(_ id: String, delta: Double) {
        updateElement(id) { item in
            item.rotation = min(32, max(-32, item.rotation + delta))
        }
    }

    private func bringElementForward(_ id: String) {
        let frontZ = nextZ
        updateElement(id) { item in item.z = frontZ }
        normalizeZOrder()
    }

    private func sendElementBackward(_ id: String) {
        updateElement(id) { item in item.z = 0 }
        normalizeZOrder()
    }

    private func duplicateElement(_ element: PagewrightCanvasElement) {
        var copy = element
        copy.id = UUID().uuidString
        copy.x = min(0.90, element.x + 0.05)
        copy.y = min(0.90, element.y + 0.05)
        copy.rotation = -element.rotation
        copy.z = nextZ
        canvasElements.append(copy)
        if copy.kind == .page, !selectedIDs.contains(copy.sourceID) {
            selectedIDs.append(copy.sourceID)
        }
        activeElementID = copy.id
        invalidateExports()
    }

    private func deleteElement(_ element: PagewrightCanvasElement) {
        switch element.kind {
        case .page:
            removeSelectedPage(element.sourceID)
        case .note:
            pinnedNotes.removeAll { $0.id == element.sourceID }
            canvasElements.removeAll { $0.id == element.id }
            activeElementID = canvasElements.first?.id
            invalidateExports()
        case .personalPhoto:
            canvasElements.removeAll { $0.id == element.id }
            if !canvasElements.contains(where: { $0.kind == .personalPhoto && $0.sourceID == element.sourceID }) {
                personalPhotos.removeAll { $0.id == element.sourceID }
            }
            activeElementID = canvasElements.first?.id
            invalidateExports()
        case .marginaliaAsset:
            canvasElements.removeAll { $0.id == element.id }
            activeElementID = canvasElements.first?.id
            invalidateExports()
        }
    }

    private func resetCanvasLayout() {
        let pageIDs = selectedIDs
        let notes = pinnedNotes
        let freeformElements = canvasElements.filter {
            $0.kind == .marginaliaAsset || $0.kind == .personalPhoto
        }
        canvasElements.removeAll()
        if pageIDs.count <= 4 {
            for (index, id) in pageIDs.enumerated() {
                canvasElements.append(defaultPageElement(for: id, index: index))
            }
        } else {
            for (index, id) in pageIDs.enumerated() {
                canvasElements.append(tidyPageElement(for: id, index: index, total: pageIDs.count))
            }
        }
        for (index, note) in notes.enumerated() {
            canvasElements.append(defaultNoteElement(for: note.id, index: index))
        }
        canvasElements.append(contentsOf: freeformElements)
        normalizeZOrder()
        activeElementID = canvasElements.first?.id
        invalidateExports()
    }

    private func tidyPageElement(for pageID: String, index: Int, total: Int) -> PagewrightCanvasElement {
        let columns: Int
        if total <= 6 {
            columns = 2
        } else if total <= 12 {
            columns = 3
        } else {
            columns = 4
        }
        let rows = max(1, Int(ceil(Double(total) / Double(columns))))
        let row = index / columns
        let column = index % columns
        let x = (CGFloat(column) + 0.5) / CGFloat(columns)
        let top: CGFloat = 0.24
        let bottom: CGFloat = 0.86
        let y: CGFloat
        if rows == 1 {
            y = 0.52
        } else {
            y = top + (bottom - top) * CGFloat(row) / CGFloat(rows - 1)
        }
        let width: CGFloat
        switch columns {
        case 2: width = 0.34
        case 3: width = 0.25
        default: width = 0.19
        }
        let rotationPattern: [Double] = [-4, 2, -1, 4, 1, -3, 3, -2]
        return PagewrightCanvasElement(
            kind: .page,
            sourceID: pageID,
            x: min(0.88, max(0.12, x)),
            y: min(0.90, max(0.18, y)),
            width: width,
            rotation: rotationPattern[index % rotationPattern.count],
            z: nextZ
        )
    }

    private func normalizeZOrder() {
        let sorted = canvasElements.sorted {
            if $0.z == $1.z { return $0.id < $1.id }
            return $0.z < $1.z
        }
        for (newZ, element) in sorted.enumerated() {
            if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                canvasElements[index].z = newZ + 1
            }
        }
    }
}

/// Where a scrap sits on the page: normalized centre, normalized width, tilt.
struct PagewrightElementPlacement: Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var rotation: Double

    init(x: CGFloat, y: CGFloat, width: CGFloat, rotation: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.rotation = rotation
    }

    init(_ element: PagewrightCanvasElement) {
        self.init(x: element.x, y: element.y, width: element.width, rotation: element.rotation)
    }
}

/// One scrap on the canvas, holding its own live drag, pinch and twist.
///
/// The studio around it is a heavy view: trays, library, inspector, every
/// other scrap. Writing the moving placement into the sheet's state on every
/// touch event rebuilt all of that sixty to a hundred and twenty times a
/// second, which is what made scraps feel like they were dragging through mud.
/// Here the in-flight placement lives on the scrap itself: only this one small
/// view redraws while a hand is on it, and the sheet hears about the move
/// exactly once, when the hand lets go.
///
/// Pinching scales the already-rendered scrap rather than re-laying it out,
/// for the same reason Photos does: relayout per frame is the expensive part,
/// and the crisp redraw at the end is imperceptible.
private struct PagewrightElementStage<Content: View>: View {
    let element: PagewrightCanvasElement
    let canvasSize: CGSize
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let isInteractive: Bool
    let onBegin: () -> Void
    let onCommit: (PagewrightElementPlacement) -> Void
    let content: Content

    @State private var live: PagewrightElementPlacement?
    @State private var origin: PagewrightElementPlacement?
    @State private var isDragging = false
    @State private var isScaling = false
    @State private var isRotating = false

    init(
        element: PagewrightCanvasElement,
        canvasSize: CGSize,
        minWidth: CGFloat,
        maxWidth: CGFloat,
        isInteractive: Bool,
        onBegin: @escaping () -> Void,
        onCommit: @escaping (PagewrightElementPlacement) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.element = element
        self.canvasSize = canvasSize
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.isInteractive = isInteractive
        self.onBegin = onBegin
        self.onCommit = onCommit
        self.content = content()
    }

    private var placement: PagewrightElementPlacement {
        live ?? PagewrightElementPlacement(element)
    }

    var body: some View {
        let shown = placement
        content
            .scaleEffect(shown.width / max(0.0001, element.width))
            .rotationEffect(.degrees(shown.rotation))
            .position(
                x: shown.x * canvasSize.width,
                y: shown.y * canvasSize.height
            )
            .gesture(manipulation, including: isInteractive ? .all : .none)
    }

    private var manipulation: some Gesture {
        dragGesture
            .simultaneously(with: scaleGesture)
            .simultaneously(with: rotationGesture)
            // A belt to the braces below: whichever finger lifted last, the
            // placement is never left stranded on the scrap.
            .onEnded { _ in
                isDragging = false
                isScaling = false
                isRotating = false
                finish()
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = begin()
                isDragging = true
                var next = live ?? start
                next.x = clamp(start.x + value.translation.width / max(1, canvasSize.width), 0.06, 0.94)
                next.y = clamp(start.y + value.translation.height / max(1, canvasSize.height), 0.06, 0.94)
                live = next
            }
            .onEnded { _ in
                isDragging = false
                finish()
            }
    }

    private var scaleGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let start = begin()
                isScaling = true
                var next = live ?? start
                next.width = clamp(start.width * value, minWidth, maxWidth)
                live = next
            }
            .onEnded { _ in
                isScaling = false
                finish()
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                let start = begin()
                isRotating = true
                var next = live ?? start
                next.rotation = min(32, max(-32, start.rotation + angle.degrees))
                live = next
            }
            .onEnded { _ in
                isRotating = false
                finish()
            }
    }

    @discardableResult
    private func begin() -> PagewrightElementPlacement {
        if let origin { return origin }
        let start = PagewrightElementPlacement(element)
        origin = start
        live = start
        onBegin()
        if element.kind == .marginaliaAsset {
            BookFeedback.pagewrightLift()
        } else {
            BookFeedback.pressTick()
        }
        return start
    }

    /// Hands the finished placement back only once every finger has lifted, so
    /// a pinch that ends a hair before the twist does not commit twice.
    private func finish() {
        guard !isDragging, !isScaling, !isRotating else { return }
        guard let settled = live else {
            origin = nil
            return
        }
        // Marginalia always lands with its paper-set-down cue. Other scraps
        // stay quiet after a move; a resize or twist keeps its existing tick.
        let reshaped = origin.map {
            $0.width != settled.width || $0.rotation != settled.rotation
        } ?? false
        origin = nil
        // Clearing the live placement and committing it upward happen in the
        // same update, so the scrap never flickers back to where it started.
        live = nil
        onCommit(settled)
        if element.kind == .marginaliaAsset {
            BookFeedback.pagewrightDrop()
        } else if reshaped {
            BookFeedback.pressTick()
        }
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(upper, max(lower, value))
    }
}

struct PagewrightDayBucket: Identifiable {
    static let allID = "all"

    var id: String
    var title: String
    var count: Int

    static func make(from pages: [BookPage]) -> [PagewrightDayBucket] {
        let grouped = Dictionary(grouping: pages) { id(for: $0.createdAt) }
        return grouped.map { key, pages in
            PagewrightDayBucket(
                id: key,
                title: title(for: pages.first?.createdAt ?? Date()),
                count: pages.count
            )
        }
        .sorted { $0.id > $1.id }
    }

    static func id(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 1,
            components.day ?? 1
        )
    }

    private static func title(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#if canImport(UIKit)
@MainActor
private final class PagewrightRenderedImageCache {
    static let shared = PagewrightRenderedImageCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for path: String) -> UIImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Photographs the reader pressed into a page arrive as JPEG bytes. Decoding
/// them again on every redraw is what a canvas full of photos was doing; this
/// decodes once, up front, and hands back the ready pixels.
@MainActor
private final class PagewrightPhotoImageCache {
    static let shared = PagewrightPhotoImageCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for photo: PagewrightPersonalPhoto) -> UIImage? {
        let key = photo.id as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let decoded = UIImage(data: photo.data) else { return nil }
        let ready = decoded.preparingForDisplay() ?? decoded
        cache.setObject(ready, forKey: key)
        return ready
    }
}
#endif

struct PagewrightMediaPreview: View {
    let asset: BookPageMediaAsset

    var body: some View {
        Group {
            switch asset.kind {
            case .bundledImage:
                Image(asset.reference)
                    .resizable()
                    .scaledToFill()
            case .renderedImageFile:
                if let image = PagewrightRenderedImageCache.shared.image(for: asset.reference) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            case .photoLibraryAsset:
                placeholder
            case .audioFile:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            BookPalette.teal.opacity(0.10)
            Image(systemName: asset.kind == .photoLibraryAsset ? "photo" : "photo.on.rectangle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(BookPalette.teal)
        }
    }
}

enum PagewrightText {
    static func excerpt(for page: BookPage, limit: Int = 420) -> String {
        clipped(baseText(for: page), limit: limit)
    }

    static func baseText(for page: BookPage) -> String {
        page.pagewrightDefaultScrapText
            ?? (page.pagewrightVisualMediaAssets.isEmpty ? "A kept page." : "A kept page with \(page.pagewrightVisualMediaAssets.count) picture\(page.pagewrightVisualMediaAssets.count == 1 ? "" : "s").")
    }

    static func clipped(_ base: String, limit: Int) -> String {
        guard base.count > limit else { return base }
        let end = base.index(base.startIndex, offsetBy: max(0, limit - 1))
        return String(base[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    static func pullQuote(for page: BookPage) -> String {
        pullQuoteOptions(for: page).first ?? excerpt(for: page, limit: 180)
    }

    static func pullQuoteOptions(for page: BookPage) -> [String] {
        if page.type == .quotes {
            return [baseText(for: page)]
        }
        let base = excerpt(for: page, limit: 1_200)
        return pullQuoteOptions(from: base, fallback: excerpt(for: page, limit: 190))
    }

    static func pullQuoteOptions(from base: String, fallback: String) -> [String] {
        let sentences = base
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 24 }
            .map { sentence in
                let clipped = sentence.count > 190 ? String(sentence.prefix(187)).trimmingCharacters(in: .whitespacesAndNewlines) + "..." : sentence
                return clipped
            }

        var options: [String] = []
        for sentence in sentences where !options.contains(sentence) {
            options.append(sentence)
        }
        if options.isEmpty {
            options.append(fallback)
        } else if base.count > 260 {
            if !options.contains(fallback) {
                options.append(fallback)
            }
        }
        return Array(options.prefix(5))
    }
}

extension BookPage {
    var pagewrightVisualMediaAssets: [BookPageMediaAsset] {
        mediaAssets.filter(\.isPagewrightVisual)
    }

    var pagewrightPreviewImageAsset: BookPageMediaAsset? {
        pagewrightVisualMediaAssets.first(where: \.isPagewrightPreviewImage)
            ?? pagewrightVisualMediaAssets.first { !$0.isPagewrightPDF }
    }
}

extension BookPageMediaAsset {
    var isPagewrightVisual: Bool {
        switch kind {
        case .bundledImage, .renderedImageFile, .photoLibraryAsset:
            return true
        case .audioFile:
            return false
        }
    }

    var isPagewrightPDF: Bool {
        metadata["export"] == "pdf" || URL(fileURLWithPath: reference).pathExtension.lowercased() == "pdf"
    }

    var isPagewrightPreviewImage: Bool {
        metadata["mediaRole"] == "scrapbookPreview"
            || (metadata["export"] == "png" && !isPagewrightPDF)
            || (kind == .renderedImageFile && !isPagewrightPDF)
    }
}

private extension View {
    @ViewBuilder
    func pagewrightItalic(_ isItalic: Bool) -> some View {
        if isItalic {
            italic()
        } else {
            self
        }
    }
}

#if canImport(UIKit)
enum PagewrightPDFWriter {
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let margin: CGFloat = 54
    private static let ink = UIColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1)
    private static let warmPaper = UIColor(red: 0.91, green: 0.82, blue: 0.64, alpha: 1)
    private static let gold = UIColor(red: 0.72, green: 0.43, blue: 0.16, alpha: 1)
    private static let teal = UIColor(red: 0.08, green: 0.42, blue: 0.45, alpha: 1)

    static func write(draft: PagewrightDraft, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            drawPageBackground(draft)
            drawCover(draft)

            context.beginPage()
            drawPageBackground(draft)
            drawRunningHeader(draft: draft)
            drawComposedCanvas(draft)
            drawColophon(draft: draft, y: pageSize.height - 112)
        }
    }

    static func writePNG(draft: PagewrightDraft, to url: URL) throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pageSize, format: format)
        let image = renderer.image { _ in
            drawPageBackground(draft)
            drawRunningHeader(draft: draft)
            drawComposedCanvas(draft)
        }
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    private static func drawPageBackground(_ draft: PagewrightDraft) {
        let background = draft.background
        let pageInk = color(for: draft.paperTint.primaryInk)
        let accent = color(for: draft.paperTint.accentInk)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let paperRect = pageRect.insetBy(
            dx: PagewrightPaperDeckle.exportInset,
            dy: PagewrightPaperDeckle.exportInset
        )
        let paperCut = PagewrightPaperDeckle.shape(for: background, in: paperRect)
        let paperPath = UIBezierPath(cgPath: paperCut.path(in: paperRect).cgPath)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 6),
            blur: 10,
            color: UIColor.black.withAlphaComponent(0.24).cgColor
        )
        paperColor(for: draft.paperTint).setFill()
        paperPath.fill()
        context.restoreGState()

        context.saveGState()
        paperPath.addClip()
        paperColor(for: draft.paperTint).setFill()
        UIBezierPath(rect: paperRect).fill()

        // The same sheet of paper the reader chose on screen. Without this the
        // export quietly dropped the texture and printed a flat colour.
        if let textureName = background.textureAssetName,
           let texture = UIImage(named: textureName) {
            texture.draw(
                in: paperRect,
                blendMode: .multiply,
                alpha: background.textureOpacity
            )
        }

        switch background {
        case .ledger:
            accent.withAlphaComponent(0.12).setFill()
            for index in 0..<24 {
                let y = CGFloat(index) * 34 + 18
                UIBezierPath(rect: CGRect(x: 0, y: y, width: pageSize.width, height: 1)).fill()
            }
        case .night:
            accent.withAlphaComponent(0.10).setFill()
            for index in 0..<18 {
                let x = CGFloat((index * 37) % 560) + 22
                let y = CGFloat((index * 61) % 720) + 30
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)).fill()
            }
        default:
            pageInk.withAlphaComponent(0.055).setFill()
            for index in 0..<14 {
                let y = CGFloat(index) * 58 + 12
                UIBezierPath(rect: CGRect(x: 0, y: y, width: pageSize.width, height: 1)).fill()
            }
        }

        context.restoreGState()

        accent.withAlphaComponent(0.22).setStroke()
        paperPath.lineWidth = 1
        paperPath.stroke()
    }

    @discardableResult
    private static func drawCover(_ draft: PagewrightDraft) -> CGFloat {
        let pageInk = color(for: draft.paperTint.primaryInk)
        let secondaryInk = color(for: draft.paperTint.secondaryInk)
        let accent = color(for: draft.paperTint.accentInk)
        paperColor(for: draft.paperTint).withAlphaComponent(0.94).setFill()
        UIBezierPath(
            roundedRect: CGRect(x: 42, y: 42, width: pageSize.width - 84, height: 316),
            cornerRadius: 12
        ).fill()
        accent.withAlphaComponent(0.22).setStroke()
        UIBezierPath(
            roundedRect: CGRect(x: 42, y: 42, width: pageSize.width - 84, height: 316),
            cornerRadius: 12
        ).stroke()

        let symbol = UIImage(systemName: draft.format.symbolName)
        symbol?.withTintColor(accent, renderingMode: .alwaysOriginal).draw(in: CGRect(x: margin, y: 54, width: 28, height: 28))

        drawText(
            draft.format.shareName.uppercased(),
            font: .systemFont(ofSize: 10, weight: .black),
            color: accent,
            rect: CGRect(x: margin + 38, y: 58, width: 260, height: 20),
            tracking: 1.8
        )

        let titleHeight = drawText(
            draft.title,
            font: .serifFont(ofSize: 32, weight: .bold),
            color: pageInk,
            rect: CGRect(x: margin, y: 100, width: pageSize.width - margin * 2, height: 92)
        )
        var y = 108 + titleHeight + 16

        if !draft.note.isEmpty {
            let noteHeight = drawText(
                draft.note,
                font: .italicSystemFont(ofSize: 13),
                color: secondaryInk,
                rect: CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 80)
            )
            y += noteHeight + 20
        }

        let pageWord = draft.pages.count == 1 ? "page" : "pages"
        let photoWord = draft.personalPhotos.count == 1 ? "photo" : "photos"
        drawText(
            "\(draft.pages.count) kept \(pageWord) and \(draft.personalPhotos.count) personal \(photoWord), arranged by hand.",
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: secondaryInk,
            rect: CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 20),
            alignment: .left
        )

        drawText(
            "\(draft.background.title) paper / \(draft.marginalia.title)",
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: secondaryInk,
            rect: CGRect(x: margin, y: y + 22, width: pageSize.width - margin * 2, height: 18),
            alignment: .left
        )
        return y + 62
    }

    private static func drawRunningHeader(draft: PagewrightDraft) {
        let secondaryInk = color(for: draft.paperTint.secondaryInk)
        let accent = color(for: draft.paperTint.accentInk)
        paperColor(for: draft.paperTint).withAlphaComponent(0.94).setFill()
        UIBezierPath(
            roundedRect: CGRect(x: margin - 10, y: 44, width: pageSize.width - (margin - 10) * 2, height: 43),
            cornerRadius: 8
        ).fill()
        drawText(
            draft.title,
            font: .systemFont(ofSize: 10, weight: .bold),
            color: secondaryInk,
            rect: CGRect(x: margin, y: 54, width: pageSize.width - margin * 2, height: 18)
        )
        accent.withAlphaComponent(0.34).setStroke()
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: 78))
        rule.addLine(to: CGPoint(x: pageSize.width - margin, y: 78))
        rule.lineWidth = 1
        rule.stroke()
    }

    private static func drawComposedCanvas(_ draft: PagewrightDraft) {
        let pageInk = color(for: draft.paperTint.primaryInk)
        let secondaryInk = color(for: draft.paperTint.secondaryInk)
        let canvasRect = CGRect(x: 46, y: 98, width: pageSize.width - 92, height: pageSize.height - 166)
        paperColor(for: draft.paperTint).withAlphaComponent(0.18).setFill()
        UIBezierPath(roundedRect: canvasRect, cornerRadius: 14).fill()

        let headerRect = CGRect(
            x: canvasRect.minX + 12,
            y: canvasRect.minY + 10,
            width: canvasRect.width - 24,
            height: draft.note.isEmpty ? 58 : 104
        )
        paperColor(for: draft.paperTint).withAlphaComponent(0.94).setFill()
        UIBezierPath(roundedRect: headerRect, cornerRadius: 9).fill()

        drawText(
            draft.title,
            font: .serifFont(ofSize: 28, weight: .bold),
            color: pageInk,
            rect: canvasRect.insetBy(dx: 20, dy: 18),
            alignment: .left
        )
        if !draft.note.isEmpty {
            drawText(
                draft.note,
                font: .italicSystemFont(ofSize: 11),
                color: secondaryInk,
                rect: CGRect(x: canvasRect.minX + 20, y: canvasRect.minY + 60, width: canvasRect.width - 40, height: 44)
            )
        }

        let pagesByID = Dictionary(uniqueKeysWithValues: draft.pages.map { ($0.id, $0) })
        let notesByID = Dictionary(uniqueKeysWithValues: draft.pinnedNotes.map { ($0.id, $0) })
        let photosByID = Dictionary(uniqueKeysWithValues: draft.personalPhotos.map { ($0.id, $0) })
        let assetsByName = Dictionary(
            IlluminationPackRegistry.unlockedPacks
                .flatMap(\.allAssets)
                .map { ($0.assetName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for element in draft.elements.sorted(by: { $0.z < $1.z }) {
            switch element.kind {
            case .page:
                guard let page = pagesByID[element.sourceID] else { continue }
                drawComposedScrap(page: page, element: element, in: canvasRect, draft: draft)
            case .note:
                guard let note = notesByID[element.sourceID] else { continue }
                drawComposedNote(note, element: element, in: canvasRect)
            case .personalPhoto:
                guard let photo = photosByID[element.sourceID] else { continue }
                drawComposedPhoto(photo, element: element, in: canvasRect)
            case .marginaliaAsset:
                guard let asset = assetsByName[element.sourceID] else { continue }
                drawComposedMarginaliaAsset(asset, element: element, in: canvasRect)
            }
        }

        drawMarginalia(draft.marginalia, tint: draft.paperTint, in: canvasRect)
    }

    private static func drawComposedScrap(page: BookPage, element: PagewrightCanvasElement, in canvasRect: CGRect, draft: PagewrightDraft) {
        let width = element.width * canvasRect.width
        let text = draft.pullQuotes[page.id]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? PagewrightText.pullQuote(for: page)
        let image = page.pagewrightVisualMediaAssets.compactMap(pagewrightImage(for:)).first
        let imageHeight: CGFloat = image == nil ? 0 : min(118, width * 0.58)
        let scrapFont = scrapTextFont(for: element, size: 13)
        let bodyHeight = min(
            138,
            measuredHeight(text, font: scrapFont, width: width - 28)
        )
        let height = max(96, imageHeight + bodyHeight + 60)
        let center = CGPoint(
            x: canvasRect.minX + element.x * canvasRect.width,
            y: canvasRect.minY + element.y * canvasRect.height
        )
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(element.rotation * .pi / 180))

        UIColor.white.withAlphaComponent(0.32).setFill()
        UIBezierPath(roundedRect: rect.offsetBy(dx: 2, dy: 3), cornerRadius: 8).fill()
        warmPaper.withAlphaComponent(0.84).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
        gold.withAlphaComponent(0.24).setStroke()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).stroke()

        drawText(
            page.type.shortTitle.uppercased(),
            font: .systemFont(ofSize: 7, weight: .black),
            color: teal,
            rect: CGRect(x: rect.minX + 12, y: rect.minY + 10, width: rect.width - 24, height: 12),
            tracking: 0.8
        )
        var y = rect.minY + 28
        if let image {
            drawImage(image, in: CGRect(x: rect.minX + 12, y: y, width: rect.width - 24, height: imageHeight))
            y += imageHeight + 9
        }
        drawText(
            text,
            font: scrapFont,
            color: ink,
            rect: CGRect(x: rect.minX + 12, y: y, width: rect.width - 24, height: bodyHeight + 8)
        )
        context.restoreGState()
    }

    private static func drawComposedMarginaliaAsset(_ asset: IlluminationAsset, element: PagewrightCanvasElement, in canvasRect: CGRect) {
        guard let image = UIImage(named: asset.assetName),
              let context = UIGraphicsGetCurrentContext() else { return }
        let width = element.width * canvasRect.width
        let ratio = image.size.width > 0 ? image.size.height / image.size.width : 1
        let height = max(24, width * ratio)
        let center = CGPoint(
            x: canvasRect.minX + element.x * canvasRect.width,
            y: canvasRect.minY + element.y * canvasRect.height
        )
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(element.rotation * .pi / 180))
        context.setAlpha(asset.defaultOpacity)
        image.draw(in: rect)
        context.restoreGState()
    }

    private static func drawComposedPhoto(
        _ photo: PagewrightPersonalPhoto,
        element: PagewrightCanvasElement,
        in canvasRect: CGRect
    ) {
        guard let image = UIImage(data: photo.data),
              image.size.width > 0,
              image.size.height > 0,
              let context = UIGraphicsGetCurrentContext() else { return }
        let width = element.width * canvasRect.width
        let height = width * image.size.height / image.size.width
        let center = CGPoint(
            x: canvasRect.minX + element.x * canvasRect.width,
            y: canvasRect.minY + element.y * canvasRect.height
        )
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(element.rotation * .pi / 180))
        image.draw(in: rect)
        context.restoreGState()
    }

    private static func drawComposedNote(_ note: PagewrightPinnedNote, element: PagewrightCanvasElement, in canvasRect: CGRect) {
        let width = element.width * canvasRect.width
        let height = max(44, measuredHeight(note.text, font: .serifFont(ofSize: 11, weight: .regular), width: width - 26) + 26)
        let center = CGPoint(
            x: canvasRect.minX + element.x * canvasRect.width,
            y: canvasRect.minY + element.y * canvasRect.height
        )
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(element.rotation * .pi / 180))
        noteFillColor(note.style).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: note.style == .stamp ? 3 : 8).fill()
        gold.withAlphaComponent(0.22).setStroke()
        UIBezierPath(roundedRect: rect, cornerRadius: note.style == .stamp ? 3 : 8).stroke()
        drawText(
            note.text,
            font: note.style == .stamp ? .systemFont(ofSize: 9, weight: .black) : .serifFont(ofSize: 11, weight: .regular),
            color: ink,
            rect: rect.insetBy(dx: 11, dy: 10),
            tracking: note.style == .stamp ? 0.8 : 0
        )
        context.restoreGState()
    }

    private static func drawMarginalia(
        _ style: PagewrightMarginaliaStyle,
        tint: PagewrightPaperTint,
        in rect: CGRect
    ) {
        let marks: [String]
        switch style {
        case .pressedFlower: marks = ["leaf", "leaf.fill", "laurel.leading"]
        case .waxSeal: marks = ["seal", "checkmark.seal", "seal.fill"]
        case .inkStars: marks = ["sparkles", "star", "moon.stars"]
        case .tornTape: marks = ["paperclip", "link", "rectangle.dashed"]
        }
        for (index, symbolName) in marks.enumerated() {
            guard let symbol = UIImage(systemName: symbolName) else { continue }
            let x = rect.maxX - CGFloat(48 + index * 24)
            let y = rect.minY + CGFloat(76 + index * 92)
            symbol.withTintColor(color(for: tint.accentInk).withAlphaComponent(0.30), renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: x, y: y, width: 28, height: 28))
        }
    }

    private static func drawColophon(draft: PagewrightDraft, y: CGFloat) {
        let rect = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 72)
        let accent = color(for: draft.paperTint.accentInk)
        paperColor(for: draft.paperTint).withAlphaComponent(0.94).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
        accent.withAlphaComponent(0.22).setStroke()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).stroke()

        drawText(
            "Bound by ReEnchanted Pagewright. Shared deliberately: only the photos, scraps, notes, and marks placed here are printed.",
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: color(for: draft.paperTint.secondaryInk),
            rect: rect.insetBy(dx: 14, dy: 14)
        )
    }

    private static func pagewrightImage(for asset: BookPageMediaAsset) -> UIImage? {
        switch asset.kind {
        case .bundledImage:
            return UIImage(named: asset.reference)
        case .renderedImageFile:
            return UIImage(contentsOfFile: asset.reference)
        case .photoLibraryAsset, .audioFile:
            return nil
        }
    }

    private static func drawImage(_ image: UIImage, in rect: CGRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 7).addClip()
        image.draw(in: CGRect(origin: origin, size: size))
        context.restoreGState()
    }

    private static func color(for tint: PagewrightPaperTint) -> UIColor {
        UIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: 1)
    }

    private static func paperColor(for tint: PagewrightPaperTint) -> UIColor {
        color(for: tint)
    }

    private static func noteFillColor(_ style: PagewrightPinnedNoteStyle) -> UIColor {
        switch style {
        case .margin: return warmPaper.withAlphaComponent(0.58)
        case .sticky: return gold.withAlphaComponent(0.18)
        case .stamp: return teal.withAlphaComponent(0.12)
        case .torn: return UIColor.white.withAlphaComponent(0.54)
        }
    }

    private static func scrapTextFont(for element: PagewrightCanvasElement, size: CGFloat) -> UIFont {
        let weight: UIFont.Weight = element.isTextBold ? .bold : .semibold
        let font = UIFont.serifFont(ofSize: size, weight: weight)
        guard element.isTextItalic else {
            return font
        }
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.traitItalic)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        rect: CGRect,
        alignment: NSTextAlignment = .left,
        tracking: CGFloat = 0
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = font.pointSize >= 20 ? 2 : 1.5
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: tracking
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return measuredHeight(text, font: font, width: rect.width, alignment: alignment, tracking: tracking)
    }

    private static func measuredHeight(
        _ text: String,
        font: UIFont,
        width: CGFloat,
        alignment: NSTextAlignment = .left,
        tracking: CGFloat = 0
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = font.pointSize >= 20 ? 2 : 1.5
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .kern: tracking
        ]
        let bounds = NSAttributedString(string: text, attributes: attributes)
            .boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        return ceil(bounds.height)
    }
}

private extension UIFont {
    static func serifFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        return UIFont(descriptor: descriptor, size: size).withWeight(weight)
    }

    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let traits = [UIFontDescriptor.TraitKey.weight: weight]
        let descriptor = fontDescriptor.addingAttributes([.traits: traits])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#endif

// MARK: - Plain Page: the unprompted door
//
// One tap from the Input seal. No prompt, no framing, no cast voice. The
// reader writes or speaks anything. The entry remains unprompted, but Keep is
// a full Book event: the archive, memory, Cast, braids, and bindings may all
// meet it afterward.
struct PlainPageSheet: View {
    let autoRecord: Bool
    let onKeep: (String, [BookPageMediaAsset]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var recorder = KeptVoiceRecorder()
    @State private var text = ""
    @State private var voiceAsset: BookPageMediaAsset?
    @State private var voiceMessage: String?
    @State private var isTranscribingVoice = false
    @FocusState private var isWriting: Bool

    private var canKeep: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || voiceAsset != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("…")
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(BookPalette.ink.opacity(0.28))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $text)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(BookPalette.ink)
                        .scrollContentBackground(.hidden)
                        .focused($isWriting)
                        .inkFeedback(text: text)
                }
                .opacity(recorder.isRecording ? 0.44 : 1)
                .scaleEffect(recorder.isRecording && !reduceMotion ? 0.985 : 1, anchor: .top)
                .allowsHitTesting(!recorder.isRecording)

                if recorder.isRecording {
                    PlainVoiceRecordingCard(elapsed: recorder.elapsed, reduceMotion: reduceMotion)
                        .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
                }

                if let voiceMessage {
                    Label(voiceMessage, systemImage: "waveform")
                        .font(.footnote)
                        .foregroundStyle(BookPalette.teal)
                        .bookResultArrival(reduceMotion: reduceMotion)
                }

                HStack(spacing: 12) {
                    Button {
                        toggleRecording()
                    } label: {
                        HStack(spacing: 8) {
                            if recorder.isRecording {
                                BookVoiceInkMeter(active: true, reduceMotion: reduceMotion)
                            }
                            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle")
                                .symbolEffect(.pulse, isActive: recorder.isRecording && !reduceMotion)
                            Text(recorder.isRecording ? "Stop" : "Speak")
                        }
                        .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(recorder.isRecording ? BookPalette.lampGold : BookPalette.teal)

                    Spacer()

                    Button("Keep") {
                        onKeep(text, voiceAsset.map { [$0] } ?? [])
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(!canKeep || recorder.isRecording || isTranscribingVoice)
                }
            }
            .padding(20)
            .background(BookPalette.paper)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        recorder.discard()
                        dismiss()
                    }
                }
            }
        }
        .animation(BookMotion.reveal(reduceMotion), value: recorder.isRecording)
        .animation(BookMotion.result(reduceMotion), value: voiceAsset?.reference)
        .onAppear {
            if autoRecord {
                toggleRecording()
            } else {
                isWriting = true
            }
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            let duration = recorder.elapsed
            if let url = recorder.stop() {
                var metadata = [
                    "keptVoice": "true",
                    "durationSeconds": "\(Int(duration.rounded()))"
                ]
                if let cadence = recorder.lastCadenceReceipt {
                    metadata.merge(cadence.metadata) { _, measured in measured }
                }
                voiceAsset = BookPageMediaAsset(
                    kind: .audioFile,
                    reference: url.path,
                    caption: "",
                    sourceID: "plain-page",
                    metadata: metadata
                )
                isTranscribingVoice = true
                voiceMessage = "Reading your voice on this device…"
                Task { @MainActor in
                    let transcript = await KeptVoiceTranscriber.transcript(at: url)
                    if let transcript, var asset = voiceAsset, asset.reference == url.path {
                        asset.caption = transcript.bookPreviewSentenceLimit(1)
                        asset.metadata[KeptVoiceTranscriber.transcriptMetadataKey] = transcript
                        asset.metadata[KeptVoiceTranscriber.provenanceMetadataKey] = KeptVoiceTranscriber.provenance
                        voiceAsset = asset
                        voiceMessage = "Voice kept. I caught the words too."
                    } else if voiceAsset?.reference == url.path {
                        voiceMessage = "Voice kept. I kept its sound and shape, but no transcript."
                    }
                    isTranscribingVoice = false
                }
                BookFeedback.play(.keepPage)
            } else {
                voiceMessage = "Nothing was recorded."
            }
        } else {
            voiceAsset = nil
            voiceMessage = nil
            isTranscribingVoice = false
            isWriting = false
            BookFeedback.play(.tap)
            if !recorder.start() {
                voiceMessage = "The microphone could not start."
            }
        }
    }

    fileprivate static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PlainVoiceRecordingCard: View {
    let elapsed: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BookPalette.lampGold.opacity(0.14))
                Circle()
                    .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
                Image(systemName: "quote.opening")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text("The page is listening")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink)
                HStack(spacing: 8) {
                    BookVoiceInkMeter(active: true, reduceMotion: reduceMotion)
                    Text(PlainPageSheet.duration(elapsed))
                        .font(.caption.monospacedDigit().weight(.bold))
                    Text("Speak naturally. Silence can stay in the recording.")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(BookPalette.ink.opacity(0.62))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(BookPalette.lampGold.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: BookPalette.lampGold.opacity(0.10), radius: 14, y: 6)
    }
}
