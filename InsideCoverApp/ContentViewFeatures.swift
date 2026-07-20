import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

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

    var bookwideMarginaliaAchievementContext: BookwideMarginaliaAchievement.Context {
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
            pages: days.flatMap(\.pages),
            anchors: anchorLedger,
            entityBeliefOffsets: entityBeliefLedger,
            completedBookJumps: completedBookJumps,
            completedCompassRuns: completedCompassRuns,
            completedElectives: electives.filter { $0.completedAt != nil }.count,
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
        return [
            "\(context.pages.count)",
            "\(context.keptDayIDs.count)",
            typeCounts,
            weatherCounts,
            "\(context.pages.filter { $0.context?.dayPart == "night" }.count)",
            "\(context.pages.filter(\.hasMarginaliaAchievementVisual).count)",
            "\(context.readerAnchors.count)",
            "\(Set(context.readerAnchors.map(\.kind)).count)",
            "\(context.anchors.reduce(0) { $0 + $1.visitCount })",
            "\(context.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] ?? 0)",
            "\(context.completedBookJumps)",
            "\(context.completedCompassRuns)",
            "\(context.completedElectives)",
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
        let line = additionalCount > 0
            ? "\(first.name), and \(additionalCount) more \(additionalCount == 1 ? "achievement" : "achievements"). \(rewardCount) new marks are waiting in Pagewright."
            : "\(first.name). \(rewardCount) new \(rewardCount == 1 ? "mark is" : "marks are") waiting in Pagewright."
        let note = KeepMarginalia.Note(
            castSlug: "marginalia-goblin",
            castName: "Marginalia Goblin",
            assetName: "LabyrinthFaeMarginaliaGoblin",
            line: line,
            carryOutLine: "Earned marks stay open. The ledger does not ask twice."
        )
        marginaliaAchievementUnlockTitle = additionalCount > 0
            ? "\(newlyCompleted.count) MARGINALIA ACHIEVEMENTS"
            : first.name.uppercased()
        withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
            marginaliaAchievementUnlockNote = note
        }
        BookFeedback.play(.braidComplete)
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
        persist(day: day, message: "The scrapbook page is tucked into the Book.")
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
            "pagewright": "true"
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

    var marginaliaSealsRow: some View {
        HStack(alignment: .top, spacing: 9) {
            MarginaliaSealButton(
                title: "Input",
                systemImage: "camera.aperture",
                wax: Color(red: 0.20, green: 0.34, blue: 0.48),
                seed: 29,
                isBusy: busySealID == "camera",
                action: { presentInputChoices() }
            )
            MarginaliaSealButton(
                title: "Body",
                systemImage: "figure.walk",
                wax: Color(red: 0.58, green: 0.16, blue: 0.18),
                seed: 3,
                isBusy: busySealID == "body",
                action: { Task { await pressBodySeal() } }
            )
            MarginaliaSealButton(
                title: "Location",
                systemImage: "mappin.and.ellipse",
                wax: Color(red: 0.36, green: 0.28, blue: 0.55),
                seed: 23,
                isBusy: busySealID == "location" || busySealID == "weather" || isAnchoringPlace,
                action: { presentLocationSealChoices() }
            )
            MarginaliaSealButton(
                title: radioManager.isPlaying ? "On Air" : "Radio",
                systemImage: radioManager.isPlaying ? "dot.radiowaves.left.and.right" : "radio",
                wax: radioManager.isPlaying ? BookPalette.teal : Color(red: 0.74, green: 0.52, blue: 0.16),
                seed: 17,
                isBusy: busySealID == "radio",
                action: { Task { await pressRadioSeal() } }
            )
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
    }

    /// The Margin-Glass seal: opens the illuminated-photo page, which is the
    /// Book's camera. Mirrors the other seals — press to summon a page from a
    /// real-world source, here the reader's own eyes/lens.
    @MainActor
    func pressGlassSeal() async {
        guard busySealID == nil else { return }
        busySealID = "camera"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-camera")
        selectedSurface = freshCameraFirstSurface()
    }

    @MainActor
    func pressRadioSeal() async {
        guard busySealID == nil else { return }
        busySealID = "radio"
        defer { busySealID = nil }
        BookFeedback.play(.sourceRefresh)
        tutorTouch("seal-radio")
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
        tutorTouch("seal-location")
        isLocationSealChoicesPresented = true
    }

    /// The Input seal is the "add anything" door: photo, plain text, or
    /// voice. Tapping it fans out into those three, mirroring the Location seal.
    func presentInputChoices() {
        guard busySealID == nil else { return }
        BookFeedback.play(.tap)
        tutorTouch("seal-camera")
        isInputChoicesPresented = true
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
            selectedSurface = anchorOfferSurface(latitude: latitude, longitude: longitude)
        }
    }

    func anchorOfferSurface(latitude: Double, longitude: Double) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .anchor)
        return SurfacePage(
            id: "anchor-offer-\(Int(Date().timeIntervalSince1970))",
            type: .anchor,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 88,
            reason: "No Anchor is lit within two hundred meters. This place could become one.",
            prompt: "Anchor this place?",
            detail: "The Book can grow an Outer Stacks room from where you are standing.",
            payload: BookPagePayload(
                headline: "An Unanchored Place",
                body: "No Anchor is lit within two hundred meters of where you stand. Name this place and tell the Book what it holds for you. Your exact words become the room.",
                metadata: [
                    "source": source.id,
                    "anchorOffer": "true",
                    "latitude": "\(latitude)",
                    "longitude": "\(longitude)",
                    "privacy": "location stays on device",
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
            body = "\(scene)\n\nKeeping this page checks in at the Anchor and offers up to \(AnchorRegistry.checkInBeliefReward) Belief from your Glow to the place."
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
        withAnimation(.easeInOut(duration: 0.4)) {
            didCompleteStoryOnboarding = true
        }
        saveOnboardingFact(
            questionID: "onboarding-snack",
            question: "What is your favorite snack to eat while reading?",
            answer: result.snack,
            tags: ["snack", "delight", "onboarding"]
        )
        if !result.favoritePerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-favorite-person",
                question: "Who is one of your favorite people?",
                answer: result.favoritePerson,
                tags: ["person", "favorite-person", "people-of-the-book", "onboarding"],
                sensitivity: .identity,
                usePermission: .privateContext
            )
            _ = introducePerson(
                name: result.favoritePerson,
                words: "One of my favorite people"
            )
        }
        saveOnboardingFact(
            questionID: "onboarding-name",
            question: "What should the Book call you?",
            answer: result.name,
            tags: ["name", "identity", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-belief",
            question: "What do you believe in?",
            answer: result.belief,
            tags: ["belief", "core", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-sleeve-word",
            question: "Which word caught on your sleeve?",
            answer: result.sleeveWord,
            tags: ["arrival", "sleeve-word", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-taste",
            question: "What should the Book bring you more of?",
            answer: result.tastePreference,
            tags: ["taste", "curation", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-comfort-boundary",
            question: "How sharp should the Book get?",
            answer: result.comfortBoundary,
            tags: ["comfort", "tone", "grey", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-whisper-cadence",
            question: "When should the Book tap the glass?",
            answer: result.whisperCadence,
            tags: ["notifications", "whispers", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-wicker-mode",
            question: "How did you answer Wicker?",
            answer: result.wickerMode,
            tags: ["wicker", "story-shape", "belief-roll", "onboarding"]
        )
        saveOnboardingFact(
            questionID: "onboarding-wicker-roll",
            question: "Did your first Wicker Belief roll hold?",
            answer: result.wickerMode.isEmpty ? "" : (result.wickerRollSucceeded ? "success" : "failure"),
            tags: ["wicker", "belief-roll", result.wickerRollSucceeded ? "success" : "failure", "onboarding"]
        )
        for wagerID in result.confirmedWagers {
            guard let wager = FirstWagers.wager(id: wagerID) else { continue }
            saveOnboardingFact(
                questionID: FirstWagers.questionID(for: wager.id),
                question: "A night-one wager the Book made about you.",
                answer: wager.guess,
                tags: ["wager", FirstWagers.confirmedTag, "onboarding", "barnum"]
            )
        }
        applyOnboardingChapterAffinity(result.drawnChapterID)
        applyOnboardingWhisperPreference(result.whisperCadence)
        if !result.firstSouvenir.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-first-souvenir",
                question: "What was the first true sentence you kept?",
                answer: result.firstSouvenir,
                tags: ["souvenir", "first-page", "onboarding"]
            )
            keepOnboardingSouvenirIfNeeded(result.firstSouvenir)
        }
        if result.investedBelief, !result.belief.isEmpty {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                beliefScore = max(0, beliefScore - 3)
            }
            saveCustomCastMember(CustomCastMemberDraft(
                name: result.belief,
                kind: .motif,
                meaning: "The player's stated core belief, planted with 3 Belief on their first day in the Labyrinth.",
                description: "Spoken aloud to Zara Finch at the threshold: \"\(result.belief)\"",
                traits: ["planted", "core"],
                beliefs: [result.belief],
                goals: ["shape what finds the player here"],
                tags: ["core-belief", "onboarding", "belief-invested", "glow-bright"],
                imageData: nil,
                startingGlow: 34
            ))
        }
        statusMessage = result.name.isEmpty
            ? "The Academy doors are open."
            : "The Academy doors are open, \(result.name)."

        // The Standing Order offer comes first; onboarding then ends on its own
        // ceremonial peak — the reader's first edition, bound — fired once the
        // paywall closes, so the celebration is the true final beat.
        let willOfferStandingOrder = !didOfferStandingOrder && !PackEntitlements.hasStandingOrder
        if willOfferStandingOrder {
            didOfferStandingOrder = true
            // Illustrate the pitch with the reader's own first-edition cover.
            standingOrderHeroArtifact = BookOfYouShareArtifact(
                title: "The First Door",
                excerpt: result.firstSouvenir.nonEmpty ?? "One true thing, kept before anyone explained keeping.",
                dateLine: Date().formatted(date: .abbreviated, time: .omitted),
                themeName: "Ordinary life",
                chapterName: result.name.nonEmpty.map { "\($0)'s first edition" } ?? "Your first edition",
                seed: (result.name + "|" + result.belief).stableHash
            )
            // Celebration is owed after the paywall dismisses.
            pendingFirstEditionReaderName = result.name
            showStandingOrderPaywall = true
        } else {
            // No offer to make — go straight to the finale celebration.
            celebrateFirstEdition(readerName: result.name)
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
        let amount = min(3, beliefScore)
        guard amount > 0 else { return }
        let talisman = GlowEntityMenuItem(
            id: chapter.talismanID,
            name: chapter.talismanName,
            kind: "talisman",
            glow: 0,
            line: chapter.storyBias
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = max(0, beliefScore - amount)
        }
        adjustEntityBelief(talisman, delta: amount, kind: .beliefInvested, playerBeliefDelta: -amount)
    }

    func applyOnboardingWhisperPreference(_ cadence: String) {
        let trimmed = cadence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let chosen = BookWhisperCadence(rawValue: trimmed) ?? .inside
        bookWhispersEnabled = chosen.enablesBookWhispers
        promptWhispersEnabled = chosen.enablesPromptWhispers
        BookWhispers.refreshSchedule(
            enabled: bookWhispersEnabled,
            cadence: chosen,
            electives: electives,
            whisperController: whisperController,
            festivalWhisper: festivalWhisperToday,
            bookInterior: sourceInputs.bookInterior
        )
        BookWhispers.refreshPromptWhispers(
            enabled: promptWhispersEnabled,
            cadence: chosen,
            day: today,
            inputs: sourceInputs,
            whisperController: whisperController,
            whisperSovereign: whisperSovereign,
            eventWhisper: worldEventWhisperToday
        )
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
            statusMessage = "That illuminated plate is already tucked into Today's Margins."
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
            promptText: "The First Door illuminated a photo.",
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
        persist(day: day, message: "The First Door illuminated photo is tucked into Today's Margins.")
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
            appLog.error("Onboarding fact save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var electives: [UnwrittenElective] {
        guard let data = electiveLedgerData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([UnwrittenElective].self, from: data) else {
            return []
        }
        return decoded
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
        guard updated != base else { return }
        vault.data.bookInterior = updated
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
            now: now
        )
        guard updated != base else { return }
        vault.data.bookInterior = updated
        vault.save()
    }

    func saveElectives(_ list: [UnwrittenElective]) {
        guard let data = try? JSONEncoder().encode(list),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        electiveLedgerData = encoded
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        BookWhispers.refreshSchedule(enabled: bookWhispersEnabled, cadence: bookWhisperCadence, electives: list, whisperController: whisperController, festivalWhisper: festivalWhisperToday, bookInterior: sourceInputs.bookInterior)
        BookWhispers.refreshPromptWhispers(enabled: promptWhispersEnabled, cadence: bookWhisperCadence, day: today, inputs: sourceInputs, whisperController: whisperController, whisperSovereign: whisperSovereign, eventWhisper: worldEventWhisperToday)
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
            : "The favor is tucked into the flyleaf. The Book will keep its promise without keeping score."
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
                mediaAssets: [photoAsset].compactMap { $0 }
            )
            var day = today
            day.pages.append(proofPage)
            persist(day: day, message: "The quest proof is tucked into the Book.")
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
            ? "\(elective.characterName) will remember this. +\(UnwrittenElective.completionBeliefReward) Belief."
            : "\(bookCompletionLine ?? "You brought the favor back. The Book will remember it.") +\(UnwrittenElective.completionBeliefReward) Belief."
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

        let fallbackWriter = FakeOuterStacksRoomWriter()
        let spec: OuterStacksRoomSpec
        if let written = try? await makeOuterStacksRoomWriter().room(
            anchorName: draft.name,
            playerWords: draft.words,
            kind: draft.kind,
            weather: weatherPhrase,
            moon: moon.name,
            season: season,
            belief: startingBelief
        ) {
            spec = written
        } else if let offline = try? await fallbackWriter.room(
            anchorName: draft.name,
            playerWords: draft.words,
            kind: draft.kind,
            weather: weatherPhrase,
            moon: moon.name,
            season: season,
            belief: startingBelief
        ) {
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
            lastVisited: "none"
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
            bookNoticeEvidence: vault.data.bookNoticeEvidence,
            magicMoment: vault.data.magicMoment,
            bookObservations: vault.data.bookObservations,
            bookReadingBoundaries: vault.data.bookReadingBoundaries,
            nothingGreyOffset: vault.data.nothingGreyOffset,
            readerLearning: vault.data.readerLearning,
            openWorldEventArchive: vault.data.openWorldEventArchive,
            overnightConnectionDrafts: vault.data.overnightConnectionDrafts,
            chosenQuill: vault.data.chosenQuill,
            people: vault.data.people,
            continuity: continuity,
            firstRunEngaged: vault.data.firstRunEngaged,
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
                ? "The Book is sealed — though some photographs were too heavy to carry along."
                : "The Book is sealed: a complete copy, pages and photographs alike."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The save file would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    /// Write every kept page as plain Markdown — readable anywhere, no app
    /// required — and hand it to the share sheet.
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
            statusMessage = "The Book's continuity is bound and ready to share."
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
        vault.data.constellations = advanced
        vault.data.wagers = wagers
        vault.data.themes = themes
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
        if let announcement, announcement.payload.metadata["bleedBriefs"]?.isEmpty == false {
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

        var briefs = TheBleedEditionBuilder.decodedBriefs(surface.payload.metadata["bleedBriefs"] ?? "")
        guard !briefs.isEmpty else {
            statusMessage = "The type tray came up empty. Penny is re-sorting the briefs."
            return false
        }
        let kind = BleedEditionKind(rawValue: surface.payload.metadata["bleedEditionKind"] ?? "") ?? .morning
        let issueNumber = Int(surface.payload.metadata["bleedIssueNumber"] ?? "") ?? 1

        if briefs.contains(where: { $0.id == "weather-desk" }) {
            var weatherInputs = sourceInputs
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
        if let interest {
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
        let candidate: (headline: String, body: String)? = {
            if let prepared = generation.preparedBleedEditionSurface,
               let prose = prepared.payload.metadata["bleedProse"]?.nonEmpty {
                return (prepared.payload.headline, prose)
            }
            if let kept = today.pages.last(where: { $0.type == .theBleed && !$0.userInput.isEmpty }) {
                return (kept.promptText.nonEmpty ?? "The Bleed", kept.userInput)
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
            try BleedPDFWriter.write(headline: candidate.headline, body: candidate.body, to: url)
            preparedBleedPDFURL = url
            statusMessage = "The Bleed is bound for sharing."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The edition would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    /// The months that actually kept pages, newest first — what the player can
    /// choose to bind. Each entry carries the month's first instant, a readable
    /// label, and how many pages it holds.
    var bindableEditionMonths: [(start: Date, label: String, pageCount: Int)] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for day in days where !day.pages.isEmpty {
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: day.date)) else { continue }
            counts[monthStart, default: 0] += day.pages.count
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return counts.keys.sorted(by: >).map { start in
            (start: start, label: formatter.string(from: start), pageCount: counts[start] ?? 0)
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
        WeeklyIssue.current(days: days, today: today, now: Date())
    }

    /// The exact edition the BookShop should preview for physical printing.
    @MainActor
    var printPreviewEdition: MonthlyEdition? {
        resolveEditionForBinding()
    }

    /// Binds the month to a PDF. The deterministic foreword/closing generated by
    /// `MonthlyEditionBuilder` are fallback scaffolding; the export path asks the
    /// on-device brain for fresh wrapper prose before sewing the PDF.
    /// Resolves which month the binder should sew: the month named on the shelf,
    /// else the previous calendar month, else the most recent month that kept
    /// pages. Returns nil if there is nothing with content to bind. Shared by the
    /// screen-PDF bind and the print-ready export.
    @MainActor
    private func resolveEditionForBinding() -> MonthlyEdition? {
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
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                startDate: monthStart,
                endDate: end,
                generatedAt: now,
                includePrivateWeatherSummary: includePrivateWeatherInMonthlyBinding
            )
        }
        let edition: MonthlyEdition
        if let chosen = selectedEditionMonth {
            edition = buildMonth(starting: chosen)
        } else {
            var auto = MonthlyEditionBuilder.previousMonth(
                from: days,
                events: archiveEvents,
                entityMemories: archiveMemories,
                entityBelief: entityBeliefLedger,
                pageBelief: pageBeliefLedger,
                constellations: vault.data.constellations ?? [],
                wagers: vault.data.wagers ?? [],
                themes: vault.data.themes ?? [],
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                now: now,
                includePrivateWeatherSummary: includePrivateWeatherInMonthlyBinding
            )
            if auto.isEmpty, let latestMonth = bindableEditionMonths.first?.start {
                auto = buildMonth(starting: latestMonth)
            }
            edition = auto
        }
        return edition.isEmpty ? nil : edition
    }

    @MainActor
    func exportMonthlyEdition(useGemmaClosing _: Bool = false) {
        guard let edition = resolveEditionForBinding() else {
            colophonBindingNote = "I turned to that month and found the leaves still blank. Keep a page or two there first, and I'll have something to sew."
            BookFeedback.play(.error)
            return
        }
        let pending = edition
        colophonBindingNote = "Asking Gemma to write the cover leaves for \(edition.monthName)…"
        Task { @MainActor in
            let bound = await gemmaMonthlyBinding(for: pending)
            do {
                try bindMonthlyEditionPDF(bound)
            } catch {
                colophonBindingNote = "The thread snapped mid-stitch — the month would not bind. (\(error.localizedDescription))"
                BookFeedback.play(.error)
            }
        }
    }

    @MainActor
    func exportWeeklyIssuePDF(forceRebind: Bool = false) {
        guard weeklyIssueBindingNote == nil else { return }
        guard let issue = currentWeeklyIssue else {
            colophonBindingNote = "No weekly issue is ready to bind yet. A week needs to close with enough kept pages first."
            BookFeedback.play(.error)
            return
        }
        // The reader takes over from here; if it was launched from the BookShop,
        // close the shop so the issue can present cleanly over the main body.
        let wasShopOpen = isBookShopPresented
        isBookShopPresented = false

        // If this exact issue is already wrapped, re-open the reader instantly —
        // unless the reader explicitly asked for a fresh (re-written) bind.
        if !forceRebind,
           let cached = cachedWeeklyIssueReader,
           cached.issue.number == issue.number,
           FileManager.default.fileExists(atPath: cached.cardURL.path),
           FileManager.default.fileExists(atPath: cached.pdfURL.path) {
            do {
                let kept = try keepWeeklyIssue(cached)
                cachedWeeklyIssueReader = kept
                presentWeeklyIssueReader(kept, afterShopDismiss: wasShopOpen)
            } catch {
                colophonBindingNote = "The issue opened, but it would not stay on the shelf: \(error.localizedDescription)"
                presentWeeklyIssueReader(cached, afterShopDismiss: wasShopOpen)
            }
            return
        }

        // "Wait for Gemma": if the on-device brain is installed we ask it to
        // bind the daily braids into a story, then write the issue's wrapper
        // prose. The first pass loads the model and can take a while, so a visible
        // progress overlay stays up until the reading copy is pressed.
        let brainReady = LocalModelManager.report().isReady
        let progress = brainReady
            ? "The Book is writing Issue No. \(issue.number) in its own words…\nThe first pass can take a moment while the local brain wakes."
            : "The local brain is resting — binding Issue No. \(issue.number) in the Book's standard hand…"
        weeklyIssueBindingNote = progress
        colophonBindingNote = progress

        Task { @MainActor in
            let wrapper: (bindingStory: String?, editorialNote: String?, closingNote: String?) = brainReady
                ? await gemmaWeeklyIssueBinding(for: issue)
                : (nil, nil, nil)
            do {
                var boundIssue = issue
                boundIssue.bindingStory = wrapper.bindingStory
                let card = WeeklyIssueShareCard.make(issue: boundIssue, selfFacts: sourceInputs.selfFacts)
                let directory = FileManager.default.temporaryDirectory
                let cardURL = directory
                    .appendingPathComponent("ReEnchanted-Weekly-Wrap-\(issue.number).png")
                try WeeklyIssueShareCardRenderer.write(card, to: cardURL)
                let url = directory
                    .appendingPathComponent("ReEnchanted-Weekly-Issue-\(issue.number).pdf")
                let readerName = CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs)
                try WeeklyIssuePDFWriter.write(
                    boundIssue,
                    readerName: readerName,
                    shareCard: card,
                    editorialNote: wrapper.editorialNote,
                    closingNote: wrapper.closingNote,
                    to: url
                )
                preparedWeeklyIssueCardURL = cardURL
                preparedWeeklyIssuePDFURL = url
                let reader = WeeklyIssueReader(
                    issue: boundIssue,
                    card: card,
                    readerName: readerName,
                    editorialNote: wrapper.editorialNote,
                    closingNote: wrapper.closingNote,
                    cardURL: cardURL,
                    pdfURL: url
                )
                let keptReader = try keepWeeklyIssue(reader)
                cachedWeeklyIssueReader = keptReader
                weeklyIssueBindingNote = nil
                presentWeeklyIssueReader(keptReader, afterShopDismiss: wasShopOpen)
                colophonBindingNote = wrapper.bindingStory != nil
                    ? "Issue No. \(issue.number) is wrapped around the story its daily bindings became, and kept on the Book of You shelf."
                    : "Issue No. \(issue.number) is wrapped and kept on the Book of You shelf."
                BookFeedback.play(.braidComplete)
            } catch {
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
    private func keepWeeklyIssue(_ reader: WeeklyIssueReader) throws -> WeeklyIssueReader {
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
            keptAt: Date()
        )
        let tag = "weekly-issue:\(reader.issue.number)"
        let storyParagraphs = keptReader.issue.bindingStory.map { [$0] } ?? []
        let body = ([keptReader.editorialLead]
            + storyParagraphs
            + reader.issue.highlights.map { "• \($0)" }
            + [keptReader.closingLine])
            .joined(separator: "\n\n")

        var archiveDay = today
        if let dayIndex = days.firstIndex(where: { day in day.pages.contains { $0.tags.contains(tag) } }),
           let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.tags.contains(tag) }) {
            archiveDay = days[dayIndex]
            var page = archiveDay.pages[pageIndex]
            page.promptText = "Weekly Issue No. \(reader.issue.number) · \(reader.issue.dateRange)"
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
                promptText: "Weekly Issue No. \(reader.issue.number) · \(reader.issue.dateRange)",
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
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func weeklyIssueCardAsset(url: URL, issue: WeeklyIssue) -> BookPageMediaAsset {
        BookPageMediaAsset(
            kind: .renderedImageFile,
            reference: url.path,
            caption: "The cover of Weekly Issue No. \(issue.number), \(issue.dateRange).",
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

    /// Builds the two files a print-on-demand house needs — a full-bleed interior
    /// and a spine-aware cover wrap — and surfaces both under the share mark. No
    /// account, backend, or fee yet: the reader hand-uploads them to a printer
    /// like Lulu for a physical hardcover proof.
    @MainActor
    func exportPrintReadyEdition(spec: PrintSpec = .hardcover6x9) {
        guard let edition = resolveEditionForBinding() else {
            colophonBindingNote = "I turned to that month and found the leaves still blank. Keep a page or two there first, and I'll have something to press."
            BookFeedback.play(.error)
            return
        }
        colophonBindingNote = "Setting \(edition.monthName) for the press…"
        Task { @MainActor in
            let bound = await gemmaMonthlyBinding(for: edition)
            do {
                try exportPrintReadyEdition(bound, spec: spec)
            } catch {
                colophonBindingNote = "The press would not take it — \(error.localizedDescription)"
                BookFeedback.play(.error)
            }
        }
    }

    @MainActor
    private func exportPrintReadyEdition(_ edition: MonthlyEdition, spec: PrintSpec) throws {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let stamp = formatter.string(from: edition.startDate)
            let dir = FileManager.default.temporaryDirectory
            let interiorURL = dir.appendingPathComponent("ReEnchanted-Print-Interior-\(stamp).pdf")
            let coverURL = dir.appendingPathComponent("ReEnchanted-Print-Cover-\(stamp).pdf")

            let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: spec, to: interiorURL)
            try MonthlyEditionPDFWriter.writeCoverWrap(edition, spec: spec, pageCount: pages, to: coverURL)

            preparedPrintInteriorURL = interiorURL
            preparedPrintCoverURL = coverURL
            let spine = PrintGeometry.spineWidthInches(pageCount: pages, spec: spec)
            let trim = "\(String(format: "%g", spec.trimWidthInches))×\(String(format: "%g", spec.trimHeightInches))in"
            colophonBindingNote = "\(edition.monthName) is ready for the press as \(spec.name) — a \(trim) interior of \(pages) pages and a cover wrap with a \(String(format: "%.2f", spine))in spine. Share both files, then upload them to a printer like Lulu."
            // The print-ready export gets its own foil-stamp ceremony, not the braid cue.
            celebratePrintReady(
                monthName: edition.monthName,
                subtitle: "A \(pages)-page \(trim) hardcover, set for the press."
            )
        } catch {
            throw error
        }
    }

    /// Writes a built edition to a PDF, surfaces it under the share mark, and
    /// keeps it durably so it reopens from the Book of You shelf later.
    @MainActor
    private func bindMonthlyEditionPDF(_ edition: MonthlyEdition) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: edition.startDate)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReEnchanted-Monthly-\(monthKey).pdf")
        try MonthlyEditionPDFWriter.write(edition, to: url)
        preparedMonthlyEditionURL = url
        // Move the edition onto the Book of You shelf so it can be reopened after
        // launch, not just shared from this session's transient PDF.
        try keepMonthlyEdition(edition, monthKey: monthKey, renderedPDF: url)
        colophonBindingNote = "\(edition.monthName) is bound — \(edition.pageCount) \(edition.pageCount == 1 ? "page" : "pages") sewn between covers, and kept on the Book of You shelf."
        // The Monthly Binding gets its own ceremonial peak, not the shared braid cue.
        celebrateMonthlyBinding(monthName: edition.monthName, pageCount: edition.pageCount)
    }

    /// Moves a bound edition's PDF out of the temporary directory and records it
    /// as a real archive page. Re-binding a month replaces that month's artifact
    /// rather than adding a duplicate card to the Book of You shelf.
    @MainActor
    private func keepMonthlyEdition(_ edition: MonthlyEdition, monthKey: String, renderedPDF: URL) throws {
        let directory = try monthlyEditionArchiveDirectory()
        let pdfURL = directory.appendingPathComponent("Monthly-Edition-\(monthKey).pdf")
        try replaceArchiveFile(at: pdfURL, with: renderedPDF)

        let artifact = KeptMonthlyEditionArtifact(
            edition: edition,
            monthKey: monthKey,
            pdfPath: pdfURL.path,
            keptAt: Date()
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
    }

    /// Reopens an archived monthly edition. If iOS has cleared its rendered PDF,
    /// the stored edition is enough to press the file again without rebuilding
    /// the month.
    @MainActor
    func openKeptMonthlyEdition(_ page: BookPage) {
        guard let artifact = page.monthlyEditionArtifact else { return }
        do {
            let directory = try monthlyEditionArchiveDirectory()
            let pdfURL = directory.appendingPathComponent("Monthly-Edition-\(artifact.monthKey).pdf")
            if !FileManager.default.fileExists(atPath: pdfURL.path) {
                try MonthlyEditionPDFWriter.write(artifact.edition, to: pdfURL)
            }
            monthlyEditionReader = MonthlyEditionReader(edition: artifact.edition, pdfURL: pdfURL)
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

    @MainActor
    private func gemmaWeeklyIssueBinding(for issue: WeeklyIssue) async -> (bindingStory: String?, editorialNote: String?, closingNote: String?) {
        // The local inference gate intentionally permits one live generation at
        // a time. Running these as `async let` made one half race the other and
        // often return nil as "busy," which could leave the issue half-written.
        let bindingStory = await gemmaWeeklyBindingStory(for: issue)
        weeklyIssueBindingNote = bindingStory == nil
            ? "The daily bindings are gathered. Gemma is writing the editor's note…"
            : "The week has become a story. Gemma is writing the editor's note…"
        let editorialNote = await gemmaWeeklyIssueEditorialNote(for: issue)
        weeklyIssueBindingNote = "The editor's note is dry. Gemma is writing the last page…"
        let closingNote = await gemmaWeeklyIssueClosingNote(for: issue)
        weeklyIssueBindingNote = "The words are ready. Pressing the reading copy and share card…"
        return (bindingStory, editorialNote, closingNote)
    }

    @MainActor
    private func gemmaWeeklyBindingStory(for issue: WeeklyIssue) async -> String? {
        guard let spec = BindingStoryPromptBuilder.weekly(for: issue) else { return nil }
        guard let raw = await LocalBrainProse.write(
            prompt: spec.prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: spec.maxTokens,
            sourceID: spec.sourceID,
            tags: ["edition", "weekly-issue", "binding-story", "gemma"]
        ) else { return nil }
        let cleaned = BraidTextPolisher.polishedBookOfYou(raw, maxParagraphs: 5, maxWords: 430)
        return cleaned.nonEmpty
    }

    @MainActor
    private func gemmaWeeklyIssueEditorialNote(for issue: WeeklyIssue) async -> String? {
        if let spec = BindingStoryPromptBuilder.weekly(for: issue),
           let raw = await LocalBrainProse.write(
               prompt: spec.prompt,
               instructions: BraidInstructions.bookOfYou,
               maxTokens: spec.maxTokens,
               sourceID: spec.sourceID,
               tags: ["edition", "weekly-issue", "binding-story", "gemma"]
           ) {
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return cleaned }
        }
        let highlights = issue.highlights.isEmpty
            ? "- No highlight lines were available."
            : issue.highlights.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        Write the editor's note for Issue No. \(issue.number) of The Book of You Weekly Issue, in the Book's own voice, addressed to the reader. It covers \(issue.dateRange) and gathers \(issue.keptCount) kept pages.
        \(BookVoice.animism)
        Highlights:
        \(highlights)
        Set-aside note: \(issue.setAsideLine ?? "none")
        Write 1 or 2 short paragraphs. Make the week feel whole without pretending it was grand. Do not invent events beyond the supplied highlights.
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
    private func gemmaWeeklyIssueClosingNote(for issue: WeeklyIssue) async -> String? {
        let highlights = issue.highlights.isEmpty
            ? "- No highlight lines were available."
            : issue.highlights.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        Write the closing note for Issue No. \(issue.number) of The Book of You Weekly Issue, in the Book's own voice, addressed to the reader. It covers \(issue.dateRange) and gathers \(issue.keptCount) kept pages.
        \(BookVoice.animism)
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
    private func gemmaMonthlyBinding(for edition: MonthlyEdition) async -> MonthlyEdition {
        var bound = edition
        async let foreword = gemmaMonthlyForeword(for: edition)
        async let closing = gemmaMonthlyClosing(for: edition)
        async let bindingStory = gemmaMonthlyBindingStory(for: edition)
        if let gemma = await foreword {
            bound.foreword = gemma
        }
        if let gemma = await gemmaMonthlyClosing(for: edition) {
            bound.closing = gemma
        }
        if let story = await bindingStory {
            bound.bindingStory = story
            let storyItem = MonthlyEditionItem(
                id: "monthly-binding-story",
                kind: .continuity,
                title: "The Month, Braided",
                body: story,
                date: edition.endDate,
                pageType: .bookOfYou,
                sourceID: "monthly-binding-story",
                mediaAssets: [],
                tags: ["monthly-binding-story", "binding-of-bindings"]
            )
            bound.sections.removeAll { $0.id == "monthly-binding-story" }
            let storySection = MonthlyEditionSection(
                id: "monthly-binding-story",
                title: "The Month, Braided",
                note: "A continuous story drawn from the month's nightly Book of You pages and its most meaningful eligible keeps.",
                items: [storyItem]
            )
            let insertionIndex = bound.sections.firstIndex { $0.id == "daily-braids" } ?? bound.sections.endIndex
            bound.sections.insert(storySection, at: insertionIndex)
        }
        return bound
    }

    @MainActor
    private func gemmaMonthlyBindingStory(for edition: MonthlyEdition) async -> String? {
        guard let spec = BindingStoryPromptBuilder.monthly(for: edition) else { return nil }
        guard let raw = await LocalBrainProse.write(
            prompt: spec.prompt,
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
    private func gemmaMonthlyForeword(for edition: MonthlyEdition) async -> String? {
        let material = monthlyBindingPromptMaterial(for: edition)
        let prompt = """
        Write the foreword to \(edition.monthName) for The Book of You, in the Book's own voice, addressed to the reader. It is opening a bound monthly chapter with \(edition.pageCount) pages across \(edition.dayCount) days.
        \(BookVoice.animism)
        Theme: \(material.themeLine)
        What kept returning this month: \(material.signals)
        Named threads: \(material.named)
        Book Memory Spine from nightly braids:
        \(material.memorySpine)
        Selected reader-authored passages from meaningful parts of eligible keeps:
        \(material.passageCompass)
        Write 2 to 4 short paragraphs. Be specific to the supplied material. Do not invent events. End on the line "- The Book".
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
    private func gemmaMonthlyClosing(for edition: MonthlyEdition) async -> String? {
        let material = monthlyBindingPromptMaterial(for: edition)
        let prompt = """
        Write the closing paragraph of \(edition.monthName) for The Book of You, in the Book's own voice: warm, literary, second-person, addressed to the reader. It bound \(edition.pageCount) pages across \(edition.dayCount) days.
        \(BookVoice.animism)
        Theme: \(material.themeLine)
        What kept returning this month: \(material.signals)
        Named threads still alight: \(material.named)
        Book Memory Spine from nightly braids:
        \(material.memorySpine)
        Selected reader-authored passages from meaningful parts of eligible keeps:
        \(material.passageCompass)
        Two or three short paragraphs. End on the line "- The Book". Do not invent events; only reflect what is given.
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

    @MainActor
    private func gemmaAnnualBinding(for annual: AnnualEdition) async -> AnnualEdition {
        var bound = annual
        async let foreword = gemmaAnnualForeword(for: annual)
        async let closing = gemmaAnnualClosing(for: annual)
        if let gemma = await foreword {
            bound.foreword = gemma
        }
        if let gemma = await closing {
            bound.closing = gemma
        }
        return bound
    }

    private func annualBindingPromptMaterial(for annual: AnnualEdition) -> String {
        let chapters = annual.chapters.map { chapter in
            let theme = chapter.theme.map { " - \($0.name): \($0.line)" } ?? ""
            return "- \(chapter.monthName): \(chapter.pageCount) pages\(theme)"
        }.joined(separator: "\n")
        let signals = annual.continuity.strongestSignals.prefix(6).map { "- \($0.line)" }.joined(separator: "\n")
        let named = annual.namedConstellations.prefix(6).map { "- \($0.displayName): \($0.latestLine)" }.joined(separator: "\n")
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
        Annual Book Memory Spine:
        \(spine)
        """
    }

    @MainActor
    private func gemmaAnnualForeword(for annual: AnnualEdition) async -> String? {
        let prompt = """
        Write the foreword to The \(annual.year) Annual of The Book of You, in the Book's own voice, addressed to the reader. It is opening a bound annual volume with \(annual.pageCount) pages across \(annual.dayCount) days and \(annual.chapters.count) chapters.
        \(BookVoice.animism)
        \(annualBindingPromptMaterial(for: annual))
        Write 3 to 5 short paragraphs. Read the year as one arc, but do not invent events beyond the supplied material. End on the line "- The Book".
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
    private func gemmaAnnualClosing(for annual: AnnualEdition) async -> String? {
        let prompt = """
        Write the closing back-matter note for The \(annual.year) Annual of The Book of You, in the Book's own voice, addressed to the reader after they have reached the end of the annual.
        \(BookVoice.animism)
        \(annualBindingPromptMaterial(for: annual))
        Write 2 or 3 short paragraphs. Let it feel final but not grandiose: the year is kept, the next page is blank on purpose. Do not invent events. End on the line "- The Book".
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
    func exportAnnualEdition() {
        do {
            let archiveEvents = (try? BookDatabase.narrativeEvents(limit: 20000)) ?? narrativeEvents
            let archiveMemories = (try? BookDatabase.entityMemories(limit: 20000)) ?? entityMemories
            // Bind the most recent year that actually kept pages: this year if it
            // has any, otherwise the year before.
            let calendar = Calendar.current
            let thisYear = calendar.component(.year, from: Date())
            let yearsWithPages = Set(days.filter { !$0.pages.isEmpty }.map { calendar.component(.year, from: $0.date) })
            let targetYear = yearsWithPages.contains(thisYear) ? thisYear : (yearsWithPages.max() ?? thisYear)
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
                readerName: CharacterLetterPageGenerator.preferredPlayerName(inputs: sourceInputs),
                now: Date()
            )
            guard !annual.isEmpty else {
                statusMessage = "There are no kept pages yet to bind into an annual."
                BookFeedback.play(.error)
                return
            }
            statusMessage = "Asking Gemma to write the year’s cover leaves…"
            Task { @MainActor in
                let bound = await gemmaAnnualBinding(for: annual)
                do {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("ReEnchanted-Annual-\(targetYear).pdf")
                    try MonthlyEditionPDFWriter.writeAnnual(bound, to: url)
                    preparedAnnualEditionURL = url
                    statusMessage = "The \(targetYear) annual is bound — \(bound.chapters.count) \(bound.chapters.count == 1 ? "chapter" : "chapters"), ready to share."
                    BookFeedback.play(.braidComplete)
                } catch {
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
            if let importedEvidence = save.bookNoticeEvidence {
                vault.data.bookNoticeEvidence = max(vault.data.bookNoticeEvidence ?? 0, importedEvidence)
            }
            if let importedMagicMoment = save.magicMoment {
                let current = vault.data.magicMoment ?? MagicMomentState()
                vault.data.magicMoment = importedMagicMoment.sessionCount > current.sessionCount
                    ? importedMagicMoment
                    : current
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
            statusMessage = "The save file has been read back into the Book: \(save.days.count) days, \(save.selfFacts.count) facts, \(save.anchors.count) anchors."
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
        let context = LocalModelManager.braidContext(
            for: day,
            days: days,
            themes: vault.data.themes ?? [],
            entityBeliefOffsets: entityBeliefLedger,
            learnedNotes: vault.data.learnedBraidNotes ?? [],
            readerLexicon: vault.data.readerLexicon ?? ReaderLexicon(),
            readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
        )
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
        return "The Book listened, and will carry this into the next page: \(note)"
    }

    /// "Rewrite this braid" → Gemma rewrites the missed braid; the deterministic
    /// taster referees, so the page is only replaced when it reads truer.
    @MainActor
    func rewriteBraid(pageID: String) async -> String {
        guard let (dayIndex, pageIndex, page) = locatedBraidPage(pageID: pageID) else {
            return "The Book reached for that page, but it had already moved."
        }
        let day0 = days[dayIndex]
        guard !DistressSignals.evaluate(day: today).isActive else {
            return "Not tonight. The Book is keeping the day gently and left the page as it is."
        }
        let context = LocalModelManager.braidContext(
            for: day0,
            days: days,
            themes: vault.data.themes ?? [],
            entityBeliefOffsets: entityBeliefLedger,
            learnedNotes: vault.data.learnedBraidNotes ?? [],
            readerLexicon: vault.data.readerLexicon ?? ReaderLexicon(),
            readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
        )
        let weak = BraidLearningLoop.weakDimensionNotes(for: page, context: context)
        let prompt = LocalModelManager.braidRewritePrompt(
            for: day0, priorBraid: page.userInput, weakNotes: weak, context: context
        )
        guard let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: BraidInstructions.bookOfYou,
            maxTokens: 620,
            sourceID: "braid-rewrite",
            tags: ["braid", "rewrite", "gemma"]
        ) else {
            return "The Book reached for new words, but the local brain was quiet. Try again in a moment."
        }
        let revised = BraidTextPolisher.polishedBookOfYou(raw)
        guard !revised.isEmpty else {
            return "The Book reached for new words, but the local brain was quiet. Try again in a moment."
        }
        // Referee: keep the rewrite only if it tastes better than the original.
        var candidate = page
        candidate.userInput = revised
        let originalScore = BraidTastingRoom.score(page: page, context: context)
        let revisedScore = BraidTastingRoom.score(page: candidate, context: context)
        guard revisedScore.total > originalScore.total else {
            return "The Book reread it, tried another way, and decided your page already held. It kept the original."
        }
        var day = days[dayIndex]
        var updated = day.pages[pageIndex]
        updated.userInput = revised
        updated.tags = Set(updated.tags).union(["braid-rewritten"]).sorted()
        updated = BraidPageDetails.annotated(updated, context: context)
        day.pages[pageIndex] = updated
        persist(day: day, message: "The Book rewrote the page closer to your day.")
        if selectedSurface?.payload.metadata["keptPageID"] == pageID {
            selectedSurface = keptSurface(for: updated)
        }
        surfaceRefreshDate = Date()
        BookFeedback.play(.braidComplete)
        return "The Book rewrote the page closer to your day."
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
            if !firstAudit.passed,
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
                let repairedAudit = await CharacterFidelityReviewer.audit(
                    prose: repaired,
                    canon: canon,
                    context: "repaired \(base.type.rawValue) surface \(base.payload.headline)",
                    sourceID: sourceID
                )
                if repairedAudit.passed || repairedAudit.score >= firstAudit.score {
                    prose = repaired
                }
            }
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

        let aStance = stanceLine(for: aProfile, name: aName, fallback: "the page is asking for care before interpretation")
        let bStance = stanceLine(for: bProfile, name: bName, fallback: "the page is asking for movement before certainty")
        let bridge = note.map { "\n\nBetween them, the old thread hums: \($0)" } ?? ""
        let opening = pageText.map { text in
            let quoted = "“\(text)”"
            return authored
                ? "\(aName) and \(bName) both stopped on the page you wrote — \(quoted) — and did not come back with the same weather in their hands."
                : "\(aName) and \(bName) both stopped on the same kept page — \(quoted) — and did not come back with the same weather in their hands."
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
            fallbackBody: "\(aName) and \(bName) crossed a \(kind) threshold in the Loom. The Book saw the thread change color, and from then on the web no longer treated them as strangers."
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
            if !firstAudit.passed,
               let repaired = await LocalBrainProse.write(
                    prompt: "\(prompt)\n\nCHARACTER CONTINUITY REPAIR:\n\(firstAudit.feedback)\nReturn every required labeled section again.",
                    instructions: instructions,
                    maxTokens: 760,
                    sourceID: "support-guild",
                    tags: ["support-guild", "dr-vellum", "dr-inkrest", "character-repair"]
               ),
               !repaired.hasPrefix("{") {
                let repairedAudit = await CharacterFidelityReviewer.audit(
                    prose: repaired,
                    canon: canon,
                    context: "repaired Support Guild consultation",
                    sourceID: "support-guild"
                )
                if repairedAudit.passed || repairedAudit.score >= firstAudit.score {
                    raw = repaired
                }
            }
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
            appLog.error("Academy lesson prose fell back: \(error.localizedDescription, privacy: .public)")
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
            instructions: base.payload.metadata["packInstructions"] ?? "You are the Book inside ReEnchanted. \(BookVoice.animismLine) Write the requested page in prose only.",
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

        Keep this page to accept. The note will be tucked into the flyleaf — \(electives.filter(\.isActive).count)/\(UnwrittenElective.maxActive) slots used.
        """
        return SurfacePage(
            id: base.id,
            type: base.type,
            sourceID: base.sourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: base.score,
            reason: base.reason,
            prompt: "\(offer.title) — \(base.payload.metadata["senderName"] ?? "a character")",
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
                selectedSurface = searchInfoSurface(
                    title: anchor.name,
                    headline: "Outer Stacks: \(anchor.name)",
                    body: "\(anchor.kind.title) Anchor, anchored \(anchor.created). Visits: \(anchor.visitCount).\n\nYour words: \(anchor.playerWords)\n\nRoom: \(anchor.outerStacksRoom)\n\nFae: \(anchor.fae)\n\nLocal rule: \(anchor.localRule)\n\nStand within two hundred meters and press the Location seal to step inside.",
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
    func unlockPack(_ packID: String) {
        guard !PackEntitlements.isUnlocked(packID) else { return }
        PackEntitlements.ownedPackIDs.insert(packID)
        vault.data.ownedPacks = Array(PackEntitlements.ownedPackIDs).sorted()
        SentenceBuilderPackRegistry.reload()
        let openedArchive = openWorldEventArchiveIfUseful(forPackID: packID, now: Date())
        vault.save()
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        let title = BookShopCatalog.listing(forPackID: packID)?.title ?? packID
        statusMessage = ""
        presentPurchaseThankYouSurface(packID: packID, title: title, openedArchive: openedArchive)
        BookFeedback.play(.braidComplete)
    }

    @MainActor
    private func presentPurchaseThankYouSurface(packID: String, title: String, openedArchive: Bool) {
        let surface = purchaseThankYouPage(packID: packID, title: title, openedArchive: openedArchive)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            purchaseThankYouSurface = surface
        }
    }

    private func purchaseThankYouPage(packID: String, title: String, openedArchive: Bool) -> SurfacePage {
        let isStandingOrder = packID == PackEntitlements.standingOrderPackID
        let headline = isStandingOrder
            ? "The Standing Order is open. Thank you."
            : "\(title) is bound. Thank you."
        let archiveLine = openedArchive
            ? "\n\nThe first archive door is already open; its arc will unfold from today."
            : "\n\nNew pages from this binding can now find their way to the desk."
        let body = """
        Creator's Note

        Thank you for helping keep ReEnchanted alive. This Book is built out of small strange things: pages that notice back, sounds from the margins, odd little doors, and real bindings you can keep.

        Your support buys the quiet practical magic too: time to write, draw, tune, test, and keep the Book kind. No hovering receipt should have to sit above your feed forever; this note is just a warm slip of paper, here long enough to be read, then ready to be swiped away.\(archiveLine)
        """

        return SurfacePage(
            id: "purchase-thanks-\(packID)-\(Int(Date().timeIntervalSince1970))",
            type: .patreon,
            sourceID: "creator-thanks",
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 98,
            reason: "A creator's note arrived with the binding.",
            prompt: headline,
            detail: "A readable thank-you page, tucked into Pages Rising.",
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: [
                    "source": "creator-thanks",
                    "surfaceLabel": "Thank you",
                    "symbol": "heart.fill",
                    "purchaseThankYou": "true",
                    "packID": packID,
                    "packTitle": title,
                    "tags": "creator-note,purchase-thanks,\(isStandingOrder ? "standing-order" : "content-pack")"
                ]
            )
        )
    }

    /// Closes an entitlement the App Store no longer vouches for. Only the
    /// Standing Order ever travels this path — outright purchases are permanent.
    @MainActor
    func revokePack(_ packID: String) {
        guard PackEntitlements.ownedPackIDs.contains(packID) else { return }
        PackEntitlements.ownedPackIDs.remove(packID)
        vault.data.ownedPacks = Array(PackEntitlements.ownedPackIDs).sorted()
        SentenceBuilderPackRegistry.reload()
        vault.save()
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        if packID == PackEntitlements.standingOrderPackID {
            statusMessage = "The Standing Order has quietly closed. Nothing is taken \u{2014} every page you wrote is still yours, bound in plain ink, and the lamp stays lit. Reopen the order whenever you like."
        }
    }

    @MainActor
    @discardableResult
    func openWorldEventArchiveIfUseful(forPackID packID: String, now: Date = Date()) -> Bool {
        guard BookShopCatalog.listing(forPackID: packID)?.family == .eventPack,
              let resolved = WorldEventRegistry.event(packID: packID) else {
            return false
        }
        let live = WorldEventResolver.activeEvents(now: now, day: today, inputs: sourceInputs)
        guard !live.contains(where: { $0.id == resolved.event.id }) else {
            return false
        }
        vault.data.openWorldEventArchive = OpenWorldEventArchive(
            packID: resolved.packID,
            eventID: resolved.event.id,
            openedAt: now,
            durationDays: resolved.event.calendar.durationDays
        )
        return true
    }

    @MainActor
    func activateWorldEventArchive(packID: String) {
        guard PackEntitlements.isUnlocked(packID) else { return }
        let title = BookShopCatalog.listing(forPackID: packID)?.title ?? packID
        if openWorldEventArchiveIfUseful(forPackID: packID, now: Date()) {
            vault.save()
            surfaceRefreshDate = Date()
            rebuildSurfaceCache()
            statusMessage = "\(title) is open as your current archive."
            BookFeedback.play(.braidComplete)
        } else {
            statusMessage = "\(title) is already live in the world, or has no archive event to open."
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
                appLog.error("Fuel enrichment save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - The knock

    /// Tap the banner: a knock on the cover. Knock twice within a breath
    /// and something inside answers — usually with knocks, sometimes with
    /// a note slid under the door.
    @MainActor
    func knockOnTheCover() {
        BookFeedback.play(.knock)
        let now = Date()
        defer { lastKnockAt = now }

        guard let last = lastKnockAt, now.timeIntervalSince(last) < 1.2 else {
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

enum PagewrightMarkTrayCategory: String, CaseIterable, Identifiable {
    case tape
    case seals
    case fieldMarks
    case papers
    case grain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tape: return "Tape"
        case .seals: return "Seals"
        case .fieldMarks: return "Field"
        case .papers: return "Paper"
        case .grain: return "Grain"
        }
    }

    var symbolName: String {
        switch self {
        case .tape: return "paperclip"
        case .seals: return "seal"
        case .fieldMarks: return "tag"
        case .papers: return "doc.on.doc"
        case .grain: return "square.dashed"
        }
    }

    var kind: IlluminationAssetKind {
        switch self {
        case .tape: return .tape
        case .seals: return .stamp
        case .fieldMarks: return .doodle
        case .papers: return .paperScrap
        case .grain: return .overlay
        }
    }

    var tags: [String] {
        switch self {
        case .tape: return ["tape", "generic"]
        case .seals: return ["stamp", "round", "label"]
        case .fieldMarks: return ["field", "tag", "compass", "marginalia"]
        case .papers: return ["scrap", "torn", "blank"]
        case .grain: return ["grain", "speckles", "edge"]
        }
    }
}

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

enum PagewrightBackground: String, CaseIterable, Identifiable {
    case parchment
    case vellum
    case ledger
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parchment: return "Parchment"
        case .vellum: return "Vellum"
        case .ledger: return "Ledger"
        case .night: return "Night"
        }
    }

    var symbolName: String {
        switch self {
        case .parchment: return "doc.text"
        case .vellum: return "square.dashed"
        case .ledger: return "list.bullet.rectangle"
        case .night: return "moon.stars"
        }
    }

    var swatch: Color {
        switch self {
        case .parchment: return Color(red: 0.78, green: 0.61, blue: 0.36)
        case .vellum: return Color(red: 0.90, green: 0.82, blue: 0.66)
        case .ledger: return Color(red: 0.38, green: 0.54, blue: 0.53)
        case .night: return Color(red: 0.14, green: 0.17, blue: 0.23)
        }
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

private struct PagewrightMarginaliaAssetKey: Hashable {
    var kindRawValue: String
    var tagsKey: String

    init(kind: IlluminationAssetKind, tags: [String]) {
        self.kindRawValue = kind.rawValue
        self.tagsKey = tags
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: "|")
    }
}

private struct PagewrightMarginaliaAssetCache {
    static let empty = PagewrightMarginaliaAssetCache()

    private static let defaultRequests: [(kind: IlluminationAssetKind, tags: [String])] = [
        (.stamp, ["stamp", "round", "label"]),
        (.doodle, ["edge", "light", "marginalia"]),
        (.paperScrap, ["scrap", "torn", "blank"]),
        (.doodle, ["field", "tag", "compass", "marginalia"]),
        (.tape, ["tape", "generic"]),
        (.overlay, ["grain", "speckles", "edge"])
    ]

    var packID: String = ""
    var assetsByName: [String: IlluminationAsset] = [:]
    var assetsByKey: [PagewrightMarginaliaAssetKey: [IlluminationAsset]] = [:]

    init() {}

    init(pack: IlluminationAssetPack) {
        let allAssets = pack.allAssets
        self.packID = pack.id
        self.assetsByName = Dictionary(allAssets.map { ($0.assetName, $0) }, uniquingKeysWith: { first, _ in first })

        var keyedAssets: [PagewrightMarginaliaAssetKey: [IlluminationAsset]] = [:]
        for request in Self.defaultRequests {
            let key = PagewrightMarginaliaAssetKey(kind: request.kind, tags: request.tags)
            keyedAssets[key] = Self.sortedAssets(allAssets, kind: request.kind, tags: request.tags)
        }
        self.assetsByKey = keyedAssets
    }

    func assets(kind: IlluminationAssetKind, tags: [String], count: Int) -> [IlluminationAsset] {
        let key = PagewrightMarginaliaAssetKey(kind: kind, tags: tags)
        return Array((assetsByKey[key] ?? []).prefix(count))
    }

    private static func sortedAssets(_ allAssets: [IlluminationAsset], kind: IlluminationAssetKind, tags: [String]) -> [IlluminationAsset] {
        let wanted = Set(tags.map { $0.lowercased() })
        return allAssets
            .filter { $0.kind == kind }
            .sorted { left, right in
                let leftScore = wanted.intersection(Set(left.tags.map { $0.lowercased() })).count
                let rightScore = wanted.intersection(Set(right.tags.map { $0.lowercased() })).count
                if leftScore == rightScore { return left.id < right.id }
                return leftScore > rightScore
            }
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
    indirect enum Trigger {
        case keptPages(Int)
        case keptPageType(BookPageType, Int)
        case distinctKeptDays(Int)
        case keptInWeather(tags: Set<String>?, count: Int)
        case keptAtNight(Int)
        case keptVisualPages(Int)
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
            case .distinctKeptDays(let count):
                return context.keptDayIDs.count >= count
            case .keptInWeather(let tags, let count):
                return context.weatherKeptCount(tags: tags) >= count
            case .keptAtNight(let count):
                return context.pages.filter { $0.context?.dayPart == "night" }.count >= count
            case .keptVisualPages(let count):
                return context.pages.filter(\.hasMarginaliaAchievementVisual).count >= count
            case .anchorsCreated(let count):
                return context.readerAnchors.count >= count
            case .distinctAnchorKinds(let count):
                return Set(context.readerAnchors.map(\.kind)).count >= count
            case .anchorVisits(let count):
                return context.anchors.reduce(0) { $0 + $1.visitCount } >= count
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
                return "\(min(context.pages.count, count))/\(count) pages kept"
            case .keptPageType(let type, let count):
                let current = context.pages.filter { $0.type == type }.count
                return "\(min(current, count))/\(count) \(type.shortTitle.lowercased()) pages"
            case .distinctKeptDays(let count):
                return "\(min(context.keptDayIDs.count, count))/\(count) kept days"
            case .keptInWeather(let tags, let count):
                let current = context.weatherKeptCount(tags: tags)
                let label = tags?.sorted().joined(separator: " or ") ?? "recorded weather"
                return "\(min(current, count))/\(count) pages kept in \(label)"
            case .keptAtNight(let count):
                let current = context.pages.filter { $0.context?.dayPart == "night" }.count
                return "\(min(current, count))/\(count) pages kept at night"
            case .keptVisualPages(let count):
                let current = context.pages.filter(\.hasMarginaliaAchievementVisual).count
                return "\(min(current, count))/\(count) visual pages"
            case .anchorsCreated(let count):
                return "\(min(context.readerAnchors.count, count))/\(count) Anchors made"
            case .distinctAnchorKinds(let count):
                let current = Set(context.readerAnchors.map(\.kind)).count
                return "\(min(current, count))/\(count) Anchor kinds"
            case .anchorVisits(let count):
                let current = context.anchors.reduce(0) { $0 + $1.visitCount }
                return "\(min(current, count))/\(count) Anchor visits"
            case .shadowWonder:
                return isComplete(in: context) ? "Shadow Wonder awake" : "Dusk Thorn still waiting"
            case .completedBookJumps(let count):
                return "\(min(context.completedBookJumps, count))/\(count) Book Jumps returned"
            case .completedCompassRuns(let count):
                return "\(min(context.completedCompassRuns, count))/\(count) Compass runs"
            case .completedElectives(let count):
                return "\(min(context.completedElectives, count))/\(count) electives completed"
            case .chosenQuill:
                return context.hasChosenQuill ? "quill chosen" : "quill still waiting"
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
        var completedElectives: Int
        var hasChosenQuill: Bool

        var keptDayIDs: Set<String> {
            Set(pages.map { BookDay.id(for: $0.createdAt) })
        }

        var readerAnchors: [AnchorRecord] {
            anchors.filter { $0.id.hasPrefix("user-anchor-") }
        }

        func weatherKeptCount(tags: Set<String>?) -> Int {
            pages.filter { page in
                let pageTags = Set(page.context?.weatherTags ?? [])
                if let tags {
                    return !pageTags.isDisjoint(with: tags)
                }
                return page.type == .weather || !pageTags.isEmpty
            }.count
        }
    }

    var id: String
    var name: String
    var riddle: String
    var hint: String
    var trigger: Trigger
    var rewardAssetIDs: [String]

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

    static let all: [BookwideMarginaliaAchievement] = [
        achievement(
            "first-margin", "The First Margin",
            "The Book only needs one kept thing before it starts writing in the corners.",
            "Keep your first page anywhere in the Book.",
            .keptPages(1),
            ["illumination_paper_deckled", "illumination_reported_small"]
        ),
        achievement(
            "shelf-begun", "A Shelf Begun",
            "Five kept pages are no longer a pile. They are a shelf.",
            "Keep five pages of any kind.",
            .keptPages(5),
            ["illumination_blank_summary", "tape_01"]
        ),
        achievement(
            "archive-stirs", "The Archive Stirs",
            "Twenty-five pages make enough paper for the archive to turn over in its sleep.",
            "Keep twenty-five pages across the Book.",
            .keptPages(25),
            ["illumination_library_acquired", "illumination_edge_remembers"]
        ),
        achievement(
            "hundred-leaves", "One Hundred Leaves",
            "A hundred pages have learned the particular sound of your attention.",
            "Keep one hundred pages.",
            .keptPages(100),
            ["illumination_archive_quiet", "illumination_margins_speak", "overlay_speckles_01"]
        ),
        achievement(
            "first-souvenir", "Something to Bring Home",
            "One true sentence can carry an entire day by the handle.",
            "Keep one One-Sentence Souvenir.",
            .keptPageType(.souvenir, 1),
            ["illumination_small_astonishments"]
        ),
        achievement(
            "five-souvenirs", "The Small Astonishments Drawer",
            "Five carried sentences are enough to begin a private museum.",
            "Keep five One-Sentence Souvenirs.",
            .keptPageType(.souvenir, 5),
            ["illumination_witness_ordinary", "illumination_ordinary_wonder"]
        ),
        achievement(
            "twelve-souvenirs", "A Dozen Days, Carried",
            "Twelve days have each surrendered one sentence worth taking.",
            "Keep twelve One-Sentence Souvenirs.",
            .keptPageType(.souvenir, 12),
            ["illumination_passage_ticket", "illumination_unannounced", "illumination_thyme_stamp"]
        ),
        achievement(
            "weather-witness", "Weather Witness",
            "Keep a page while the sky is willing to sign as a witness.",
            "Keep one page with recorded real-world weather.",
            .keptInWeather(tags: nil, count: 1),
            ["illumination_weather_cabinet", "illumination_blank_field"]
        ),
        achievement(
            "weather-ledger", "The Weather Ledger",
            "The sky has signed three separate pages. The ledger believes you now.",
            "Keep three pages with recorded real-world weather.",
            .keptInWeather(tags: nil, count: 3),
            ["illumination_field_note_harbor", "illumination_observation_small"]
        ),
        achievement(
            "rain-kept", "Rain, Kept",
            "The rain was happening and you kept something anyway.",
            "Keep a page while the recorded weather includes rain.",
            .keptInWeather(tags: ["rain"], count: 1),
            ["illumination_rain_collected", "illumination_lighthouse_01"]
        ),
        achievement(
            "storm-lantern", "Lantern in a Storm",
            "A storm crossed the page without putting out the lamp.",
            "Keep a page while the recorded weather includes a storm.",
            .keptInWeather(tags: ["storm"], count: 1),
            ["illumination_lighthouse_02", "overlay_edge_vignette_01"]
        ),
        achievement(
            "snowbound-margin", "The Snowbound Margin",
            "Snow quieted the world long enough for one page to be heard.",
            "Keep a page while the recorded weather includes snow or ice.",
            .keptInWeather(tags: ["snow"], count: 1),
            ["illumination_paper_moth", "illumination_pale_feather"]
        ),
        achievement(
            "fog-archive", "Filed in Fog",
            "The world withheld its edges. You kept a page without demanding them back.",
            "Keep a page while the recorded weather includes fog.",
            .keptInWeather(tags: ["fog"], count: 1),
            ["illumination_borrowed_hush", "illumination_moon_strip"]
        ),
        achievement(
            "wind-written", "Written Sideways by Wind",
            "The wind tried to edit the day. You kept its corrections.",
            "Keep a page while the recorded weather includes wind.",
            .keptInWeather(tags: ["wind"], count: 1),
            ["illumination_windy_tag"]
        ),
        achievement(
            "bright-weather", "Three Bright Witnesses",
            "Three pages were kept while the world had its lamps on.",
            "Keep three pages while the recorded weather is bright.",
            .keptInWeather(tags: ["bright"], count: 3),
            ["illumination_pressed_fern", "illumination_lamp_remembered"]
        ),
        achievement(
            "night-keeper", "Keeper After Midnight",
            "Three pages know what your attention sounds like after dark.",
            "Keep three pages during the night.",
            .keptAtNight(3),
            ["illumination_moon_row", "illumination_starlight"]
        ),
        achievement(
            "first-anchor", "A Door Where None Was",
            "You stood somewhere real and taught the Outer Stacks a new room.",
            "Create your first Anchor.",
            .anchorsCreated(1),
            ["doodle_anchor_01", "illumination_map_unseen"]
        ),
        achievement(
            "three-anchors", "A Private Geography",
            "Three made places are enough for a map that did not exist before you.",
            "Create three Anchors.",
            .anchorsCreated(3),
            ["illumination_compass_reminder", "illumination_astrolabe_stamp"]
        ),
        achievement(
            "three-anchor-kinds", "The Five Verbs of Place",
            "Notice, embark, sense, write, rest. Three of the verbs now have rooms.",
            "Create Anchors of three different kinds.",
            .distinctAnchorKinds(3),
            ["doodle_sailboat_01", "doodle_compass_01", "illumination_kept_tide"]
        ),
        achievement(
            "anchor-returner", "The Door Remembers You",
            "A made place becomes a relationship when you return.",
            "Make five total visits to Anchors.",
            .anchorVisits(5),
            ["illumination_patient_day", "illumination_map_fragment"]
        ),
        achievement(
            "shadow-wonder", "Shadow Wonder",
            "You fed the Dusk Thorn, and it answered from the beautiful worn edge.",
            "Raise the Dusk Thorn from no Belief to positive Belief.",
            .shadowWonder,
            ["illumination_belief_margin", "illumination_moon_marker", "illumination_brown_feather"]
        ),
        achievement(
            "rest-five", "Five Quiet Centers",
            "Five times, you let rest be a page instead of an absence.",
            "Keep five Center Pages.",
            .keptPageType(.rest, 5),
            ["illumination_quiet_pages", "illumination_moss_return"]
        ),
        achievement(
            "visible-proof", "Visible Proof",
            "Three pages brought back light in a form the eye could keep.",
            "Keep three pages containing photographs or rendered images.",
            .keptVisualPages(3),
            ["illumination_frame_attention", "illumination_ink_proof"]
        ),
        achievement(
            "first-book-jump", "Returned Through the Spine",
            "You went into an old story and came home carrying one true thing.",
            "Complete one Book Jump and return with a souvenir.",
            .completedBookJumps(1),
            ["illumination_moth_ticket"]
        ),
        achievement(
            "three-book-jumps", "Frequent Visitor to Impossible Libraries",
            "Three stories have stamped your return papers.",
            "Complete three Book Jumps and return with souvenirs.",
            .completedBookJumps(3),
            ["illumination_wander_record", "illumination_dreams_ticket"]
        ),
        achievement(
            "first-compass-run", "The Compass Moved",
            "Notice, embark, sense, write, rest: the needle has seen the whole ritual.",
            "Complete one Wonder Compass run.",
            .completedCompassRuns(1),
            ["illumination_paper_compass"]
        ),
        achievement(
            "three-compass-runs", "Known to the Needle",
            "After three journeys, the Compass no longer mistakes you for a tourist.",
            "Complete three Wonder Compass runs.",
            .completedCompassRuns(3),
            ["stamp_west_write"]
        ),
        achievement(
            "chosen-quill", "Chosen in Return",
            "You did not merely choose an instrument. One of them chose back.",
            "Complete the Pen Choosing and keep your chosen quill.",
            .chosenQuill,
            ["illumination_inkwell", "illumination_script_strip"]
        ),
        achievement(
            "first-elective", "Fieldwork Submitted",
            "A professor asked for proof from the real world, and you brought it.",
            "Complete one Unwritten Elective.",
            .completedElectives(1),
            ["illumination_clover_tag", "illumination_lavender_stamp"]
        ),
        achievement(
            "three-tarot-readings", "Three Dealings with Chance",
            "Three spreads have answered without pretending to be verdicts.",
            "Keep three Tarot readings.",
            .keptPageType(.tarot, 3),
            ["illumination_constellation", "illumination_luna_moth"]
        ),
        achievement(
            "three-letters", "Letters Know the Way",
            "Three letters have crossed the Margins and found a place to land.",
            "Keep three Letter pages.",
            .keptPageType(.letter, 3),
            ["illumination_letters_margins", "illumination_daylight_missed"]
        ),
        achievement(
            "three-plain-pages", "The Sacred Dumb Door",
            "Three times, you asked for no prompt and wrote anyway.",
            "Keep three Plain Pages.",
            .keptPageType(.plainPage, 3),
            ["scrap_note_torn_01"]
        ),
        achievement(
            "remembered-three", "The Book Remembered",
            "Three old pages returned with reasons, not merely recurrence.",
            "Keep three Book Remembered pages.",
            .keptPageType(.bookRemembered, 3),
            ["illumination_keep_moment", "illumination_found_margins"]
        ),
        achievement(
            "first-binding", "Bound for the Shelf",
            "Loose days became an artifact with a spine.",
            "Keep one Bindery page, weekly issue, or edition.",
            .keptPageType(.bindery, 1),
            ["illumination_living_story", "illumination_lanterns_lit"]
        ),
        achievement(
            "seven-kept-days", "A Week with Margins",
            "Seven different days have each left something behind.",
            "Keep pages on seven different days.",
            .distinctKeptDays(7),
            ["illumination_blank_date"]
        )
    ]

    private static func achievement(
        _ id: String,
        _ name: String,
        _ riddle: String,
        _ hint: String,
        _ trigger: Trigger,
        _ rewardAssetIDs: [String]
    ) -> BookwideMarginaliaAchievement {
        precondition((1...3).contains(rewardAssetIDs.count), "Marginalia achievements must reveal 1–3 marks.")
        return BookwideMarginaliaAchievement(
            id: id,
            name: name,
            riddle: riddle,
            hint: hint,
            trigger: trigger,
            rewardAssetIDs: rewardAssetIDs
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
                return BookwideMarginaliaAchievement.achievement(id: id)?.name ?? "A Book-wide achievement"
            }
        }

        var hint: String {
            switch self {
            case .selectedScraps(let count):
                return "Add \(count == 1 ? "one kept page" : "\(count) kept pages") to the Pagewright canvas."
            case .selectedAnyType(let types):
                return "Add a kept \(Self.typeList(types).lowercased()) page to the canvas."
            case .format(let format):
                return "Switch the Pagewright format to \(format.shareName)."
            case .template(let template):
                return "Apply the \(template.title) template."
            case .background(let background):
                return "Choose the \(background.title) background in Materials."
            case .marginaliaStyle(let style):
                return "Choose \(style.title) as the printed marginalia style."
            case .pinnedNotes(let count):
                return "Add \(count == 1 ? "a pinned note" : "\(count) pinned notes") to the scrapbook."
            case .placedMarks(let count):
                return "Place \(count == 1 ? "one unlocked mark" : "\(count) unlocked marks") on the canvas."
            case .distinctSelectedTypes(let count):
                return "Select kept pages from \(count) different page types."
            case .litDays(let count):
                return "Select pages from \(count) different kept days."
            case .visualScrap:
                return "Add a kept page that has a photo, rendered card, or other visual asset."
            case .exportedDraft:
                return "Make a PDF or PNG from this scrapbook page."
            case .namedDraft:
                return "Change the title from the default to a name of your own."
            case .editedPullQuote:
                return "Select a scrap, open Quotes, and choose one of its pull quotes."
            case .bookwide(let id):
                return BookwideMarginaliaAchievement.achievement(id: id)?.hint
                    ?? "Complete this achievement elsewhere in the Book."
            }
        }

        func progress(in context: Context) -> String {
            switch self {
            case .selectedScraps(let count):
                return "\(min(context.selectedPages.count, count))/\(count) kept scraps"
            case .selectedAnyType:
                return isComplete(in: context) ? "matching scrap gathered" : "matching scrap still needed"
            case .format(let format):
                return context.format == format ? "\(format.shareName) chosen" : "\(format.shareName) still needed"
            case .template(let template):
                return context.template == template ? "\(template.title) applied" : "\(template.title) still needed"
            case .background(let background):
                return context.background == background ? "\(background.title) chosen" : "\(background.title) still needed"
            case .marginaliaStyle(let style):
                return context.marginaliaStyle == style ? "\(style.title) chosen" : "\(style.title) still needed"
            case .pinnedNotes(let count):
                return "\(min(context.pinnedNoteCount, count))/\(count) pinned notes"
            case .placedMarks(let count):
                return "\(min(context.placedMarkCount, count))/\(count) marks placed"
            case .distinctSelectedTypes(let count):
                return "\(min(context.selectedTypes.count, count))/\(count) page kinds"
            case .litDays(let count):
                return "\(min(context.selectedDayIDs.count, count))/\(count) kept days"
            case .visualScrap:
                return context.hasVisualScrap ? "visual scrap gathered" : "visual scrap still needed"
            case .exportedDraft:
                return context.hasExport ? "artifact made" : "PDF or PNG still needed"
            case .namedDraft:
                return context.hasCustomTitle ? "page named" : "a true title still needed"
            case .editedPullQuote:
                return context.hasEditedPullQuote ? "pull quote chosen" : "pull quote still needed"
            case .bookwide(let id):
                guard let achievement = BookwideMarginaliaAchievement.achievement(id: id) else {
                    return "achievement unavailable"
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

    var title: String {
        "\(name) — \(Self.assetDisplayName(assetID))"
    }

    var hiddenHint: String {
        "\(riddle)\nSpend 1 Belief to turn the riddle into exact instructions."
    }

    var requirementSummary: String {
        requirements.map(\.title).joined(separator: " · ")
    }

    func revealedHint(in context: Context) -> String {
        let instructions = requirements.map(\.hint).joined(separator: " ")
        let progress = requirements.map { $0.progress(in: context) }.joined(separator: " · ")
        return "\(instructions)\nProgress: \(progress)."
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
        name: "The First Cut",
        riddle: "One kept thing is enough to give the scissors courage.",
        requirements: [.selectedScraps(1)]
    )
    private static let namedFlyleaf = Quest(
        id: "named-flyleaf",
        name: "A Name in the Flyleaf",
        riddle: "The page wants a name that only its maker would have chosen.",
        requirements: [.namedDraft]
    )
    private static let pressedBetweenPages = Quest(
        id: "pressed-between-pages",
        name: "Pressed Between Pages",
        riddle: "Bring the green world inside, then let a flower keep watch.",
        requirements: [.selectedAnyType([.weather, .location, .souvenir]), .marginaliaStyle(.pressedFlower)]
    )
    private static let nightPaper = Quest(
        id: "night-paper",
        name: "Paper After Midnight",
        riddle: "Two scraps are waiting for the lamps to go out.",
        requirements: [.selectedScraps(2), .background(.night)]
    )
    private static let cartographersOffcut = Quest(
        id: "cartographers-offcut",
        name: "The Cartographer's Offcut",
        riddle: "A direction means more after the road has lasted two days.",
        requirements: [.selectedAnyType([.wonderCompass, .anchor, .location]), .litDays(2)]
    )
    private static let evidenceSlip = Quest(
        id: "evidence-slip",
        name: "The Evidence Slip",
        riddle: "File the page carefully, but choose the sentence yourself.",
        requirements: [.template(.fieldNotes), .editedPullQuote]
    )
    private static let greenBinding = Quest(
        id: "green-binding",
        name: "The Green Binding",
        riddle: "A flower and a handwritten thought can hold almost anything together.",
        requirements: [.marginaliaStyle(.pressedFlower), .pinnedNotes(1)]
    )
    private static let heldTogether = Quest(
        id: "held-together",
        name: "Held Together on Purpose",
        riddle: "Name the page. Place one earned mark. The tear becomes part of the design.",
        requirements: [.namedDraft, .placedMarks(1)]
    )
    private static let archivistsSeal = Quest(
        id: "archivists-seal",
        name: "The Archivist's Seal",
        riddle: "Five scraps from more than one day are enough to become an archive.",
        requirements: [.selectedScraps(5), .litDays(2)]
    )
    private static let lunaPost = Quest(
        id: "luna-post",
        name: "Luna Post",
        riddle: "Address a letter after dark. The moths will handle delivery.",
        requirements: [.format(.letterPacket), .background(.night)]
    )
    private static let northboundSeal = Quest(
        id: "northbound-seal",
        name: "The Northbound Seal",
        riddle: "Find a bearing, then gather three different kinds of proof.",
        requirements: [.selectedAnyType([.wonderCompass, .anchor, .location]), .distinctSelectedTypes(3)]
    )
    private static let astonishmentCertified = Quest(
        id: "astonishment-certified",
        name: "Small Astonishment, Certified",
        riddle: "The ordinary thing needs a witness and a proper name.",
        requirements: [.selectedAnyType([.souvenir, .narrativeOS, .bookNotices]), .namedDraft]
    )
    private static let officiallyObserved = Quest(
        id: "officially-observed",
        name: "Officially Observed",
        riddle: "Set out the field ledger and pin down what the form forgot to ask.",
        requirements: [.template(.fieldNotes), .pinnedNotes(1)]
    )
    private static let creatureWasHere = Quest(
        id: "creature-was-here",
        name: "A Creature Was Here",
        riddle: "A small pocket and one visible piece of evidence should do it.",
        requirements: [.format(.pocketPage), .visualScrap]
    )
    private static let sealOfAssembly = Quest(
        id: "seal-of-assembly",
        name: "The Seal of Assembly",
        riddle: "Three scraps, one wax seal: now it counts as a gathering.",
        requirements: [.selectedScraps(3), .marginaliaStyle(.waxSeal)]
    )
    private static let visibleEvidence = Quest(
        id: "visible-evidence",
        name: "The Visible Evidence",
        riddle: "Let a picture lead. Scatter the rest around it.",
        requirements: [.visualScrap, .template(.polaroidScatter)]
    )
    private static let inkbound = Quest(
        id: "inkbound",
        name: "Inkbound",
        riddle: "Two notes and one chosen sentence will make the ink take the oath.",
        requirements: [.pinnedNotes(2), .editedPullQuote]
    )
    private static let handmadeConstellation = Quest(
        id: "handmade-constellation",
        name: "A Handmade Constellation",
        riddle: "Three kinds of page become a sky when the ink learns stars.",
        requirements: [.distinctSelectedTypes(3), .marginaliaStyle(.inkStars)]
    )
    private static let passageGranted = Quest(
        id: "passage-granted",
        name: "Passage Granted",
        riddle: "Put a true name on a letter and the ticket will recognize you.",
        requirements: [.format(.letterPacket), .namedDraft]
    )
    private static let lettersThroughMargins = Quest(
        id: "letters-through-margins",
        name: "Letters Through the Margins",
        riddle: "A letter travels farther with a private note pinned inside.",
        requirements: [.format(.letterPacket), .pinnedNotes(1)]
    )
    private static let harborLedger = Quest(
        id: "harbor-ledger",
        name: "The Harbor Ledger",
        riddle: "Bring weather or water to the ruled green page. The harbor keeps accounts.",
        requirements: [.selectedAnyType([.weather, .todaysSky, .location, .anchor]), .background(.ledger)]
    )
    private static let unlostOnPurpose = Quest(
        id: "unlost-on-purpose",
        name: "Unlost on Purpose",
        riddle: "A compass is only a beginning. Keep walking until three days touch the map.",
        requirements: [.selectedAnyType([.wonderCompass, .anchor, .location]), .litDays(3)]
    )
    private static let nocturneCollector = Quest(
        id: "nocturne-collector",
        name: "The Nocturne Collector",
        riddle: "Three kept days look different under the same night sky.",
        requirements: [.litDays(3), .background(.night)]
    )
    private static let greenhousePressing = Quest(
        id: "greenhouse-pressing",
        name: "The Greenhouse Pressing",
        riddle: "Study one living scrap closely enough for the ledger to grow leaves.",
        requirements: [.selectedAnyType([.weather, .location, .souvenir]), .template(.fieldNotes)]
    )
    private static let keeperOfQuiet = Quest(
        id: "keeper-of-quiet",
        name: "Keeper of Quiet",
        riddle: "Rest belongs on vellum. Give it somewhere soft to remain.",
        requirements: [.selectedAnyType([.rest, .bookRemembered, .bookPocket]), .background(.vellum)]
    )
    private static let filedUnderAstonishment = Quest(
        id: "filed-under-astonishment",
        name: "Filed Under Astonishment",
        riddle: "The field desk wants three unlike specimens before it opens the drawer.",
        requirements: [.template(.fieldNotes), .distinctSelectedTypes(3)]
    )
    private static let usualInterrupted = Quest(
        id: "usual-interrupted",
        name: "The Usual, Interrupted",
        riddle: "Give an ordinary wonder permission to make a beautiful mess.",
        requirements: [.selectedAnyType([.souvenir, .narrativeOS, .bookNotices]), .template(.softChaos)]
    )
    private static let pocketFamiliar = Quest(
        id: "pocket-familiar",
        name: "The Pocket Familiar",
        riddle: "Make a pocket for company, then leave it two small instructions.",
        requirements: [.format(.pocketPage), .pinnedNotes(2)]
    )
    private static let weeklyIlluminator = Quest(
        id: "weekly-illuminator",
        name: "The Weekly Illuminator",
        riddle: "Five days and a little shrine are enough to relight the story.",
        requirements: [.template(.weeklyShrine), .litDays(5)]
    )
    private static let livingArchive = Quest(
        id: "living-archive",
        name: "The Living Archive",
        riddle: "Gather five scraps, then decide which sentence survives the filing.",
        requirements: [.selectedScraps(5), .editedPullQuote]
    )
    private static let softChaosLicense = Quest(
        id: "soft-chaos-license",
        name: "License for Soft Chaos",
        riddle: "Three earned marks placed without apology will loosen the feather.",
        requirements: [.template(.softChaos), .placedMarks(3)]
    )
    private static let witnessedEdge = Quest(
        id: "witnessed-edge",
        name: "The Witnessed Edge",
        riddle: "Name the page and choose the line that proves you really looked.",
        requirements: [.namedDraft, .editedPullQuote]
    )
    private static let marginApprentice = Quest(
        id: "margin-apprentice",
        name: "The Margin Apprentice",
        riddle: "Two kept scraps are enough for the margins to start teaching back.",
        requirements: [.selectedScraps(2)]
    )
    private static let finalVarnish = Quest(
        id: "final-varnish",
        name: "The Final Varnish",
        riddle: "Give the work its true name, then let it leave the studio once.",
        requirements: [.namedDraft, .exportedDraft]
    )
}

struct PagewrightSheet: View {
    private struct MarginaliaUnlockNotice: Equatable {
        var questID: String
        var title: String
        var markCount: Int
        var additionalQuestCount: Int
    }

    let keptPages: [BookPage]
    let bookwideAchievementContext: BookwideMarginaliaAchievement.Context
    let initialPageIDs: [String]
    let initialPDFURL: URL?
    let initialPNGURL: URL?
    let onExportPDF: (PagewrightDraft) -> URL?
    let onExportPNG: (PagewrightDraft) -> URL?
    let onKeep: (PagewrightDraft, URL?, URL?) -> Void

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
    @State private var marginalia: PagewrightMarginaliaStyle = .pressedFlower
    @State private var noteDraft = ""
    @State private var noteStyle: PagewrightPinnedNoteStyle = .margin
    @State private var pinnedNotes: [PagewrightPinnedNote] = []
    @State private var personalPhotos: [PagewrightPersonalPhoto] = []
    @State private var canvasElements: [PagewrightCanvasElement] = []
    @State private var activeElementID: String?
    @State private var dragOrigins: [String: CGPoint] = [:]
    @State private var scaleOrigins: [String: CGFloat] = [:]
    @State private var rotationOrigins: [String: Double] = [:]
    @State private var selectedTemplate: PagewrightTemplate = .memoryWall
    @State private var selectedMarginaliaPackID = CoreMarginsPack.id
    @State private var sharedURL: URL?
    @State private var sharedPNGURL: URL?
    @State private var editingScrapTextElementID: String?
    @State private var activeTrayMode: PagewrightTrayMode?
    @State private var selectedScrapTrayScope: PagewrightScrapTrayScope = .all
    @State private var selectedMarkTrayCategory: PagewrightMarkTrayCategory = .tape
    @State private var pageCache = PagewrightPageCache.empty
    @State private var marginaliaAssetCache = PagewrightMarginaliaAssetCache.empty
    @State private var isManipulatingElement = false
    #if canImport(PhotosUI)
    @State private var pendingPersonalPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPersonalPhotos = false
    @State private var personalPhotoImportMessage: String?
    #endif
    @FocusState private var focusedScrapTextElementID: String?

    /// Shared with the rest of the Book by key — the Pagewright reads and spends
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
    /// A locked mark the reader tapped — drives the achievement/hint sheet.
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

    private func isMarginaliaUnlocked(_ asset: IlluminationAsset) -> Bool {
        let achievement = PagewrightMarginaliaAchievement.achievement(for: asset)
        return completedMarginaliaAchievementIDs.contains(achievement.questID)
            || achievement.isComplete(in: marginaliaAchievementContext)
    }

    private func refreshMarginaliaAchievements(announce: Bool = true) {
        let achievements = selectedMarginaliaPack.allAssets.map(PagewrightMarginaliaAchievement.achievement)
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
        refreshMarginaliaAssetCacheIfNeeded()
    }

    private func refreshMarginaliaAssetCacheIfNeeded() {
        let pack = selectedMarginaliaPack
        guard marginaliaAssetCache.packID != pack.id else { return }
        marginaliaAssetCache = PagewrightMarginaliaAssetCache(pack: pack)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isWide = proxy.size.width >= 820
                Group {
                    if isWide {
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
            .navigationTitle("Scrapbook Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BookPalette.nightText)
                }
                ToolbarItem(placement: .primaryAction) {
                    exportMenu
                }
            }
            .onAppear {
                ensureSelectedMarginaliaPackIsUnlocked()
                refreshStudioCachesIfNeeded()
                guard selectedIDs.isEmpty else { return }
                let availableIDs = Set(keptPages.map(\.id))
                let seededIDs = initialPageIDs.filter(availableIDs.contains)
                selectedIDs = seededIDs.isEmpty
                    ? keptPages.prefix(format.defaultSelectionCount).map(\.id)
                    : seededIDs
                activePageID = selectedIDs.first
                seedPullQuotes()
                if seededIDs.isEmpty {
                    syncCanvasElements()
                } else {
                    applyTemplate(.polaroidScatter, replaceSelection: false)
                    if title == "A Page I Kept" {
                        title = "Things the Book Kept"
                    }
                    #if canImport(Photos)
                    Task { await replaceThirdSeedScrapWithRandomLibraryPhoto() }
                    #endif
                }
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
                refreshMarginaliaAssetCacheIfNeeded()
            }
            .onChange(of: selectedMarginaliaPackID) { _, _ in
                refreshMarginaliaAssetCacheIfNeeded()
                refreshMarginaliaAchievements(announce: false)
                invalidateExports()
            }
            .onChange(of: marginaliaAchievementSignature) { _, _ in
                refreshMarginaliaAchievements()
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
                                Text("MARGINALIA EARNED")
                                    .font(.caption2.weight(.black))
                                    .tracking(0.9)
                                    .foregroundStyle(BookPalette.violet)
                                Text(notice.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(BookPalette.nightText)
                                Text(
                                    notice.additionalQuestCount > 0
                                        ? "+ \(notice.additionalQuestCount) more \(notice.additionalQuestCount == 1 ? "achievement" : "achievements") · \(notice.markCount) new marks opened permanently."
                                        : "\(notice.markCount) new \(notice.markCount == 1 ? "mark" : "marks") opened permanently."
                                )
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
                compactToolDock
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
        .animation(.snappy(duration: 0.22), value: activeTrayMode?.id)
    }

    private var compactCanvasViewport: some View {
        ScrollView(.vertical, showsIndicators: false) {
            compactScrapbookCanvas
                .padding(.bottom, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .layoutPriority(1)
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
        HStack(spacing: 7) {
            compactToolButton("Scraps", "tray.full", isActive: activeTrayMode == .scraps) {
                toggleTray(.scraps)
            }
            compactToolMenu("Layout", "rectangle.grid.2x2") { layoutMenuContent }
            compactToolMenu("Paper", "paintpalette") { materialsMenuContent }
            compactToolButton("Marks", "seal", isActive: activeTrayMode == .marks) {
                toggleTray(.marks)
            }
            compactToolMenu("Quote", "text.quote") { quoteMenuContent }
            compactToolMenu("Export", "square.and.arrow.up") { bindMenuContent }
        }
        .padding(8)
        .background(BookPalette.nightText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func toggleTray(_ mode: PagewrightTrayMode) {
        activeTrayMode = activeTrayMode == mode ? nil : mode
        focusedScrapTextElementID = nil
        if activeTrayMode == .scraps {
            tutorTouch("scrapbook-scraps")
        } else if activeTrayMode == .marks {
            tutorTouch("scrapbook-marks")
        }
        BookFeedback.pressTick()
    }

    private func compactToolButton(_ title: String, _ symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.callout.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bookPress(playsHaptic: false))
        .foregroundStyle(isActive ? BookPalette.nightPanel : BookPalette.nightText)
        .background(isActive ? BookPalette.lampGold : BookPalette.nightText.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func compactToolMenu<Content: View>(
        _ title: String,
        _ symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.callout.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bookPress(playsHaptic: false))
        .foregroundStyle(BookPalette.nightText)
        .background(BookPalette.nightText.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.26), radius: 18, y: 8)
        .padding(.bottom, 66)
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
                Text(selectedMarginaliaPack.displayName)
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
                }
            }

            if let personalPhotoImportMessage {
                Text(personalPhotoImportMessage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.58))
            }
        }
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
    private func replaceThirdSeedScrapWithRandomLibraryPhoto() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let resolvedStatus = status == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            : status
        guard resolvedStatus == .authorized || resolvedStatus == .limited else { return }

        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        guard assets.count > 0 else { return }
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
              image.size.height > 0 else { return }

        let photo = PagewrightPersonalPhoto(
            data: jpeg,
            aspectRatio: image.size.width / image.size.height
        )
        await MainActor.run {
            // The surfaced spread remains exactly three scraps: two things
            // already kept by the Book and one uncropped photograph from the
            // reader's library. If Photos is unavailable, the original three
            // kept scraps remain in place.
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PagewrightMarkTrayCategory.allCases) { category in
                        markCategoryButton(category)
                    }
                }
                .padding(.vertical, 1)
            }

            let assets = visibleMarkTrayAssets
            if assets.isEmpty {
                ContentUnavailableView("No marks here", systemImage: selectedMarkTrayCategory.symbolName, description: Text("Choose another category."))
                    .foregroundStyle(BookPalette.nightText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(assets) { asset in
                            markAssetTile(asset)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .confirmationDialog(
            "Open this mark?",
            isPresented: Binding(
                get: { pendingUnlockMarginalia != nil },
                set: { if !$0 { pendingUnlockMarginalia = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingUnlockMarginalia
        ) { asset in
            if !isMarginaliaHintRevealed(asset) {
                Button("Reveal hint for 1 Belief") {
                    tutorTouch("scrapbook-achievements")
                    revealMarginaliaHint(asset)
                }
            }
            if isMarginaliaUnlocked(asset) {
                Button("Place mark") {
                    addPackMarginalia(asset)
                    pendingUnlockMarginalia = nil
                }
            }
            Button("Not yet", role: .cancel) { pendingUnlockMarginalia = nil }
        } message: { asset in
            let achievement = PagewrightMarginaliaAchievement.achievement(for: asset)
            if isMarginaliaUnlocked(asset) {
                Text("\(achievement.title)\nUnlocked. Place it on the page.")
            } else if isMarginaliaHintRevealed(asset) {
                Text("\(achievement.title)\n\(achievement.revealedHint(in: marginaliaAchievementContext))\nYou hold \(beliefScore) Belief.")
            } else {
                Text("\(achievement.title)\n\(achievement.hiddenHint)\nYou hold \(beliefScore) Belief.")
            }
        }
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
            return "Earned · \(achievement.name)"
        }
        if isMarginaliaHintRevealed(asset) {
            return achievement.requirementSummary
        }
        return achievement.name
    }

    private func markCategoryButton(_ category: PagewrightMarkTrayCategory) -> some View {
        Button {
            selectedMarkTrayCategory = category
            BookFeedback.pressTick()
        } label: {
            Label(category.title, systemImage: category.symbolName)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedMarkTrayCategory == category ? BookPalette.nightPanel : BookPalette.nightText)
        .background(selectedMarkTrayCategory == category ? BookPalette.lampGold : BookPalette.nightText.opacity(0.07), in: Capsule())
    }

    private var visibleMarkTrayAssets: [IlluminationAsset] {
        previewAssets(
            kind: selectedMarkTrayCategory.kind,
            tags: selectedMarkTrayCategory.tags,
            count: 80
        )
    }

    private func previewAssets(kind: IlluminationAssetKind, tags: [String], count: Int) -> [IlluminationAsset] {
        let assets = packAssets(kind: kind, tags: tags, count: count)
        let unlocked = assets.filter(isMarginaliaUnlocked)
        let locked = assets.filter { !isMarginaliaUnlocked($0) }
        // Keep earned marks first, but let the whole collection be discoverable.
        // Locked marks carry their achievement requirement in the gallery rather
        // than disappearing behind an arbitrary preview limit.
        return unlocked + locked
    }

    private func markAssetTile(_ asset: IlluminationAsset) -> some View {
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

    @ViewBuilder
    private var scrapsMenuContent: some View {
        Menu("Day") {
            Button("All kept days") { selectedDayID = PagewrightDayBucket.allID }
            ForEach(buckets.prefix(18)) { bucket in
                Button("\(bucket.title) (\(bucket.count))") { selectedDayID = bucket.id }
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
        }
        .disabled(selectedIDs.isEmpty)
    }

    @ViewBuilder
    private var layoutMenuContent: some View {
        Button {
            composeWithBook()
        } label: {
            Label("Compose with Book", systemImage: "wand.and.stars")
        }
        .disabled(keptPages.isEmpty)
        Divider()
        ForEach(PagewrightTemplate.allCases) { template in
            Button {
                applyTemplate(template, replaceSelection: false)
            } label: {
                Label(template.title, systemImage: selectedTemplate == template ? "checkmark" : template.symbolName)
            }
        }
        Divider()
        Button("Tidy selected layout") {
            resetCanvasLayout()
        }
    }

    @ViewBuilder
    private var formatMenuContent: some View {
        ForEach(PagewrightFormat.allCases) { option in
            Button {
                format = option
            } label: {
                Label(option.shareName, systemImage: format == option ? "checkmark" : option.symbolName)
            }
        }
    }

    @ViewBuilder
    private var materialsMenuContent: some View {
        Menu("Background") {
            ForEach(PagewrightBackground.allCases) { option in
                Button {
                    background = option
                    invalidateExports()
                } label: {
                    Label(option.title, systemImage: background == option ? "checkmark" : option.symbolName)
                }
            }
        }
        Menu("Marginalia pack") {
            ForEach(unlockedMarginaliaPacks) { pack in
                Button {
                    selectedMarginaliaPackID = pack.id
                    invalidateExports()
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
            } label: {
                Label(option.title, systemImage: marginalia == option ? "checkmark" : option.symbolName)
            }
        }
    }

    @ViewBuilder
    private var marginaliaMenuContent: some View {
        Text(selectedMarginaliaPack.displayName)
        marginaliaAssetMenu("Wandering Seals", kind: .stamp, tags: ["stamp", "round", "label"])
        marginaliaAssetMenu("Illuminate Edges", kind: .doodle, tags: ["edge", "light", "marginalia"])
        marginaliaAssetMenu("Pressed Scraps", kind: .paperScrap, tags: ["scrap", "torn", "blank"])
        marginaliaAssetMenu("Field Marks", kind: .doodle, tags: ["field", "tag", "compass"])
        marginaliaAssetMenu("Tape Corners", kind: .tape, tags: ["tape", "generic"])
        marginaliaAssetMenu("Paper Grain", kind: .overlay, tags: ["grain", "speckles", "edge"])
        Divider()
        if let element = activeElement, element.kind == .marginaliaAsset {
            Button("Delete selected mark", role: .destructive) { deleteElement(element) }
        }
    }

    @ViewBuilder
    private func marginaliaAssetMenu(_ title: String, kind: IlluminationAssetKind, tags: [String]) -> some View {
        let assets = previewAssets(kind: kind, tags: tags, count: 12)
        if assets.isEmpty {
            Button(title) {}
                .disabled(true)
        } else {
            Menu(title) {
                ForEach(assets) { asset in
                    Button {
                        openMarginaliaLock(asset)
                    } label: {
                        Label(
                            isMarginaliaUnlocked(asset) ? markAssetTitle(asset) : lockedMarginaliaMenuTitle(for: asset),
                            systemImage: isMarginaliaUnlocked(asset) ? markAssetSymbol(kind) : "lock"
                        )
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
        } label: {
            Label("Make PDF", systemImage: "doc.richtext")
        }
        .disabled(!hasPrimaryCanvasContent)
        Button {
            renderCurrentPNG()
        } label: {
            Label("Make PNG", systemImage: "photo")
        }
        .disabled(!hasPrimaryCanvasContent)
        Button {
            keepCurrentDraft()
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
        return "\(page.type.shortTitle) - \(cached.dateLabel) - \(excerpt)"
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

                    if let element = activeElement {
                        selectedElementHUD(element)
                            .position(
                                x: min(canvasSize.width - 104, max(104, element.x * canvasSize.width)),
                                y: min(canvasSize.height - 28, max(32, element.y * canvasSize.height - 78))
                            )
                            .zIndex(10_000)
                    }
                }
                .dropDestination(for: String.self) { ids, location in
                    BookFeedback.pressTick()
                    for (offset, id) in ids.enumerated() {
                        addSelectedPage(
                            id,
                            at: CGPoint(
                                x: min(0.88, max(0.12, location.x / max(1, canvasSize.width) + CGFloat(offset) * 0.03)),
                                y: min(0.88, max(0.18, location.y / max(1, canvasSize.height) + CGFloat(offset) * 0.03))
                            )
                        )
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
            }
            .aspectRatio(612.0 / 792.0, contentMode: .fit)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(BookPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
            }
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
                .foregroundStyle(background == .night ? BookPalette.nightText : BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note)
                    .font(.system(.callout, design: .serif))
                    .italic()
                    .foregroundStyle((background == .night ? BookPalette.nightText : BookPalette.ink).opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyCanvas: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add a photo or kept page", systemImage: "hand.draw")
                .font(.headline.weight(.bold))
            Text("Choose your own photos above, tap a page in the archive, or drag a scrap into the canvas.")
                .font(.callout)
        }
        .foregroundStyle(background == .night ? BookPalette.nightText.opacity(0.72) : BookPalette.ink.opacity(0.68))
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
        .background((background == .night ? Color.white : Color.black).opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var pageBackground: some View {
        ZStack {
            switch background {
            case .parchment:
                BookPalette.paper
                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            case .vellum:
                LinearGradient(
                    colors: [Color(red: 0.96, green: 0.91, blue: 0.80), Color(red: 0.86, green: 0.78, blue: 0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .ledger:
                Color(red: 0.89, green: 0.93, blue: 0.87)
                VStack(spacing: 28) {
                    ForEach(0..<18, id: \.self) { _ in
                        Rectangle()
                            .fill(BookPalette.teal.opacity(0.10))
                            .frame(height: 1)
                    }
                }
            case .night:
                LinearGradient(
                    colors: [Color(red: 0.09, green: 0.12, blue: 0.17), Color(red: 0.19, green: 0.16, blue: 0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
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
                        .foregroundStyle((background == .night ? BookPalette.lampGold : BookPalette.teal).opacity(0.18))
                }
                Spacer()
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private func canvasElement(_ element: PagewrightCanvasElement, canvasSize: CGSize) -> some View {
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
            if let image = UIImage(data: photo.data) {
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
        .rotationEffect(.degrees(element.rotation))
        .position(x: element.x * canvasSize.width, y: element.y * canvasSize.height)
        .gesture(elementManipulationGesture(for: element, canvasSize: canvasSize))
        .zIndex(Double(element.z))
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
        .draggable(page.id)
        .rotationEffect(.degrees(element.rotation))
        .position(x: element.x * canvasSize.width, y: element.y * canvasSize.height)
        .gesture(elementManipulationGesture(for: element, canvasSize: canvasSize), including: isEditing ? .none : .all)
        .zIndex(Double(element.z))
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
        .rotationEffect(.degrees(element.rotation))
        .position(x: element.x * canvasSize.width, y: element.y * canvasSize.height)
        .gesture(elementManipulationGesture(for: element, canvasSize: canvasSize))
        .zIndex(Double(element.z))
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
        .rotationEffect(.degrees(element.rotation))
        .position(x: element.x * canvasSize.width, y: element.y * canvasSize.height)
        .gesture(elementManipulationGesture(for: element, canvasSize: canvasSize))
        .zIndex(Double(element.z))
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

    private func elementManipulationGesture(for element: PagewrightCanvasElement, canvasSize: CGSize) -> some Gesture {
        dragGesture(for: element, canvasSize: canvasSize)
            .simultaneously(with: scaleGesture(for: element))
            .simultaneously(with: rotationGesture(for: element))
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

    private func endElementManipulation() {
        if isManipulatingElement,
           dragOrigins.isEmpty,
           scaleOrigins.isEmpty,
           rotationOrigins.isEmpty {
            isManipulatingElement = false
        }
    }

    private func dragGesture(for element: PagewrightCanvasElement, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                beginElementManipulation(element)
                if dragOrigins[element.id] == nil {
                    BookFeedback.pressTick()
                }
                let origin = dragOrigins[element.id] ?? CGPoint(x: element.x, y: element.y)
                dragOrigins[element.id] = origin
                updateElement(element.id) { item in
                    item.x = min(0.94, max(0.06, origin.x + value.translation.width / max(1, canvasSize.width)))
                    item.y = min(0.94, max(0.06, origin.y + value.translation.height / max(1, canvasSize.height)))
                }
            }
            .onEnded { _ in
                dragOrigins[element.id] = nil
                endElementManipulation()
            }
    }

    private func scaleGesture(for element: PagewrightCanvasElement) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                beginElementManipulation(element)
                if scaleOrigins[element.id] == nil {
                    BookFeedback.pressTick()
                }
                let origin = scaleOrigins[element.id] ?? element.width
                scaleOrigins[element.id] = origin
                updateElement(element.id) { item in
                    item.width = clampedWidth(for: item.kind, proposed: origin * value)
                }
            }
            .onEnded { _ in
                scaleOrigins[element.id] = nil
                endElementManipulation()
                BookFeedback.pressTick()
            }
    }

    private func rotationGesture(for element: PagewrightCanvasElement) -> some Gesture {
        RotationGesture()
            .onChanged { angle in
                beginElementManipulation(element)
                if rotationOrigins[element.id] == nil {
                    BookFeedback.pressTick()
                }
                let origin = rotationOrigins[element.id] ?? element.rotation
                rotationOrigins[element.id] = origin
                updateElement(element.id) { item in
                    item.rotation = min(32, max(-32, origin + angle.degrees))
                }
            }
            .onEnded { _ in
                rotationOrigins[element.id] = nil
                endElementManipulation()
                BookFeedback.pressTick()
            }
    }

    private func clampedWidth(for kind: PagewrightCanvasElement.Kind, proposed: CGFloat) -> CGFloat {
        let minimum: CGFloat = kind == .note ? 0.18 : 0.12
        let maximum: CGFloat = (kind == .marginaliaAsset || kind == .personalPhoto)
            ? 0.86
            : (kind == .note ? 0.46 : 0.62)
        return min(maximum, max(minimum, proposed))
    }

    private func noteBackground(_ style: PagewrightPinnedNoteStyle) -> Color {
        switch style {
        case .margin: return BookPalette.paper.opacity(0.58)
        case .sticky: return BookPalette.lampGold.opacity(0.22)
        case .stamp: return BookPalette.teal.opacity(0.12)
        case .torn: return Color.white.opacity(0.52)
        }
    }

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Materials")
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)

            Picker("Background", selection: $background) {
                ForEach(PagewrightBackground.allCases) { option in
                    Label(option.title, systemImage: option.symbolName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: background) { _, _ in invalidateExports() }

            Picker("Marginalia pack", selection: $selectedMarginaliaPackID) {
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
                Label("Pack Marginalia", systemImage: "seal")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BookPalette.nightText)
                Spacer()
                Text(selectedMarginaliaPack.displayName)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                    .lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                packButton("Wandering Seals", "seal", kind: .stamp, tags: ["stamp", "round", "label"], count: 2)
                packButton("Illuminate Edges", "sparkles", kind: .doodle, tags: ["edge", "light", "marginalia"], count: 3)
                packButton("Pressed Scraps", "doc.on.doc", kind: .paperScrap, tags: ["scrap", "torn", "blank"], count: 2)
                packButton("Field Marks", "tag", kind: .doodle, tags: ["field", "tag", "compass"], count: 3)
                packButton("Tape Corners", "paperclip", kind: .tape, tags: ["tape", "generic"], count: 2)
                packButton("Paper Grain", "square.dashed", kind: .overlay, tags: ["grain", "speckles", "edge"], count: 1)
            }
        }
        .padding(14)
        .background(BookPalette.nightText.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func packButton(_ title: String, _ symbol: String, kind: IlluminationAssetKind, tags: [String], count: Int) -> some View {
        Button {
            addPackMarginalia(kind: kind, tags: tags, count: count)
        } label: {
            Label(title, systemImage: symbol)
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
        invalidateExports()
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
        case .weeklyShrine: return "A week can be small and still be holy."
        case .softChaos: return "No need to make it neater than it was."
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

    private func addPackMarginalia(kind: IlluminationAssetKind, tags: [String], count: Int) {
        // Bulk placement only flows through marks whose achievements are already
        // complete. Locked marks can reveal hints, but never auto-place.
        let assets = packAssets(kind: kind, tags: tags, count: count).filter(isMarginaliaUnlocked)
        guard !assets.isEmpty else { return }
        for (index, asset) in assets.enumerated() {
            canvasElements.append(packAssetElement(for: asset, index: index))
        }
        activeElementID = canvasElements.last?.id
        invalidateExports()
    }

    private func addPackMarginalia(_ asset: IlluminationAsset) {
        // The single chokepoint: a still-locked mark routes to the achievement
        // and hint sheet instead of landing on the page.
        guard isMarginaliaUnlocked(asset) else {
            tutorTouch("scrapbook-achievements")
            pendingUnlockMarginalia = asset
            BookFeedback.pressTick()
            return
        }
        tutorTouch("scrapbook-marks")
        canvasElements.append(packAssetElement(for: asset, index: 0))
        activeElementID = canvasElements.last?.id
        invalidateExports()
        BookFeedback.pressTick()
    }

    private func packAssets(kind: IlluminationAssetKind, tags: [String], count: Int) -> [IlluminationAsset] {
        if marginaliaAssetCache.packID == selectedMarginaliaPack.id {
            return marginaliaAssetCache.assets(kind: kind, tags: tags, count: count)
        }
        return PagewrightMarginaliaAssetCache(pack: selectedMarginaliaPack)
            .assets(kind: kind, tags: tags, count: count)
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
        if marginaliaAssetCache.packID == selectedMarginaliaPack.id,
           let asset = marginaliaAssetCache.assetsByName[assetName] {
            return asset
        }
        return PagewrightMarginaliaAssetCache(pack: selectedMarginaliaPack)
            .assetsByName[assetName]
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
            ?? (page.pagewrightVisualMediaAssets.isEmpty ? "A kept page." : "A kept page with \(page.pagewrightVisualMediaAssets.count) visual artifact\(page.pagewrightVisualMediaAssets.count == 1 ? "" : "s").")
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
    private static let mutedInk = UIColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 0.62)
    private static let paper = UIColor(red: 0.97, green: 0.91, blue: 0.78, alpha: 1)
    private static let warmPaper = UIColor(red: 0.91, green: 0.82, blue: 0.64, alpha: 1)
    private static let gold = UIColor(red: 0.72, green: 0.43, blue: 0.16, alpha: 1)
    private static let teal = UIColor(red: 0.08, green: 0.42, blue: 0.45, alpha: 1)

    static func write(draft: PagewrightDraft, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            drawPageBackground(draft.background)
            drawCover(draft)

            context.beginPage()
            drawPageBackground(draft.background)
            drawRunningHeader(draft: draft)
            drawComposedCanvas(draft)
            drawColophon(draft: draft, y: pageSize.height - 112)
        }
    }

    static func writePNG(draft: PagewrightDraft, to url: URL) throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: pageSize, format: format)
        let image = renderer.image { _ in
            drawPageBackground(draft.background)
            drawRunningHeader(draft: draft)
            drawComposedCanvas(draft)
        }
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    private static func drawPageBackground(_ background: PagewrightBackground) {
        paperColor(for: background).setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: pageSize)).fill()

        switch background {
        case .ledger:
            teal.withAlphaComponent(0.10).setFill()
            for index in 0..<24 {
                let y = CGFloat(index) * 34 + 18
                UIBezierPath(rect: CGRect(x: 0, y: y, width: pageSize.width, height: 1)).fill()
            }
        case .night:
            gold.withAlphaComponent(0.08).setFill()
            for index in 0..<18 {
                let x = CGFloat((index * 37) % 560) + 22
                let y = CGFloat((index * 61) % 720) + 30
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)).fill()
            }
        default:
            warmPaper.withAlphaComponent(0.32).setFill()
            for index in 0..<14 {
                let y = CGFloat(index) * 58 + 12
                UIBezierPath(rect: CGRect(x: 0, y: y, width: pageSize.width, height: 1)).fill()
            }
        }

        gold.withAlphaComponent(0.16).setStroke()
        let border = UIBezierPath(roundedRect: CGRect(x: 28, y: 28, width: pageSize.width - 56, height: pageSize.height - 56), cornerRadius: 14)
        border.lineWidth = 1
        border.stroke()
    }

    @discardableResult
    private static func drawCover(_ draft: PagewrightDraft) -> CGFloat {
        let symbol = UIImage(systemName: draft.format.symbolName)
        symbol?.withTintColor(gold, renderingMode: .alwaysOriginal).draw(in: CGRect(x: margin, y: 54, width: 28, height: 28))

        drawText(
            draft.format.shareName.uppercased(),
            font: .systemFont(ofSize: 10, weight: .black),
            color: teal,
            rect: CGRect(x: margin + 38, y: 58, width: 260, height: 20),
            tracking: 1.8
        )

        let titleHeight = drawText(
            draft.title,
            font: .serifFont(ofSize: 32, weight: .bold),
            color: ink,
            rect: CGRect(x: margin, y: 100, width: pageSize.width - margin * 2, height: 92)
        )
        var y = 108 + titleHeight + 16

        if !draft.note.isEmpty {
            let noteHeight = drawText(
                draft.note,
                font: .italicSystemFont(ofSize: 13),
                color: mutedInk,
                rect: CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 80)
            )
            y += noteHeight + 20
        }

        let pageWord = draft.pages.count == 1 ? "page" : "pages"
        let photoWord = draft.personalPhotos.count == 1 ? "photo" : "photos"
        drawText(
            "\(draft.pages.count) kept \(pageWord) and \(draft.personalPhotos.count) personal \(photoWord), arranged by hand.",
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: mutedInk,
            rect: CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 20),
            alignment: .left
        )

        drawText(
            "\(draft.background.title) paper / \(draft.marginalia.title)",
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: mutedInk,
            rect: CGRect(x: margin, y: y + 22, width: pageSize.width - margin * 2, height: 18),
            alignment: .left
        )
        return y + 62
    }

    private static func drawRunningHeader(draft: PagewrightDraft) {
        drawText(
            draft.title,
            font: .systemFont(ofSize: 10, weight: .bold),
            color: mutedInk,
            rect: CGRect(x: margin, y: 54, width: pageSize.width - margin * 2, height: 18)
        )
        gold.withAlphaComponent(0.24).setStroke()
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: 78))
        rule.addLine(to: CGPoint(x: pageSize.width - margin, y: 78))
        rule.lineWidth = 1
        rule.stroke()
    }

    private static func drawComposedCanvas(_ draft: PagewrightDraft) {
        let canvasRect = CGRect(x: 46, y: 98, width: pageSize.width - 92, height: pageSize.height - 166)
        UIColor.white.withAlphaComponent(draft.background == .night ? 0.03 : 0.16).setFill()
        UIBezierPath(roundedRect: canvasRect, cornerRadius: 14).fill()

        drawText(
            draft.title,
            font: .serifFont(ofSize: 28, weight: .bold),
            color: draft.background == .night ? UIColor.white.withAlphaComponent(0.92) : ink,
            rect: canvasRect.insetBy(dx: 20, dy: 18),
            alignment: .left
        )
        if !draft.note.isEmpty {
            drawText(
                draft.note,
                font: .italicSystemFont(ofSize: 11),
                color: draft.background == .night ? UIColor.white.withAlphaComponent(0.68) : mutedInk,
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

        drawMarginalia(draft.marginalia, in: canvasRect)
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

    private static func drawMarginalia(_ style: PagewrightMarginaliaStyle, in rect: CGRect) {
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
            symbol.withTintColor(gold.withAlphaComponent(0.26), renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: x, y: y, width: 28, height: 28))
        }
    }

    private static func drawColophon(draft: PagewrightDraft, y: CGFloat) {
        let rect = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 72)
        teal.withAlphaComponent(0.10).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()

        drawText(
            "Bound by ReEnchanted Pagewright. Shared deliberately: only the photos, scraps, notes, and marks placed here are printed.",
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: mutedInk,
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

    private static func paperColor(for background: PagewrightBackground) -> UIColor {
        switch background {
        case .parchment: return paper
        case .vellum: return UIColor(red: 0.94, green: 0.88, blue: 0.74, alpha: 1)
        case .ledger: return UIColor(red: 0.88, green: 0.92, blue: 0.84, alpha: 1)
        case .night: return UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 1)
        }
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

// MARK: - Plain Page: the sacred dumb door
//
// One tap from the Input seal. No prompt, no framing, no cast voice. The
// reader writes (or speaks) anything; on Keep it enters the archive as an
// unprocessed `.plainPage`. Deliberately does NOT reuse CapturePageSheet — the
// whole point is that the entry moment is not enchanted.
struct PlainPageSheet: View {
    let autoRecord: Bool
    let onKeep: (String, [BookPageMediaAsset]) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = KeptVoiceRecorder()
    @State private var text = ""
    @State private var voiceAsset: BookPageMediaAsset?
    @State private var voiceMessage: String?
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
                }

                if let voiceMessage {
                    Label(voiceMessage, systemImage: "waveform")
                        .font(.footnote)
                        .foregroundStyle(BookPalette.teal)
                }

                HStack(spacing: 12) {
                    Button {
                        toggleRecording()
                    } label: {
                        Label(
                            recorder.isRecording ? "Stop (\(Self.duration(recorder.elapsed)))" : "Speak",
                            systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle"
                        )
                    }
                    .tint(recorder.isRecording ? BookPalette.lampGold : BookPalette.teal)

                    Spacer()

                    Button("Keep") {
                        if recorder.isRecording { toggleRecording() }
                        onKeep(text, voiceAsset.map { [$0] } ?? [])
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(!canKeep)
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
            if let url = recorder.stop() {
                voiceAsset = BookPageMediaAsset(
                    kind: .audioFile,
                    reference: url.path,
                    caption: "",
                    sourceID: "plain-page",
                    metadata: ["keptVoice": "true"]
                )
                voiceMessage = "Voice kept."
                BookFeedback.play(.keepPage)
            } else {
                voiceMessage = "Nothing was recorded."
            }
        } else {
            voiceAsset = nil
            voiceMessage = nil
            BookFeedback.play(.tap)
            if !recorder.start() {
                voiceMessage = "The microphone could not start."
            }
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
