import SwiftUI

// MARK: - ContentView feature cluster: seals, anchors, generated-page
// adoption, onboarding completion, and Unwritten Electives.
//
// Split from ContentView.swift to start paying down the monolith; new
// feature clusters should land here (or in sibling extension files), not
// in the main view file.

extension ContentView {
    var marginaliaSealsRow: some View {
        HStack(alignment: .top, spacing: 14) {
            MarginaliaSealButton(
                title: "Body",
                systemImage: "figure.walk",
                wax: Color(red: 0.58, green: 0.16, blue: 0.18),
                seed: 3,
                isBusy: busySealID == "body",
                action: { Task { await pressBodySeal() } }
            )
            MarginaliaSealButton(
                title: "Weather",
                systemImage: "cloud.sun.fill",
                wax: BookPalette.teal,
                seed: 11,
                isBusy: busySealID == "weather",
                action: { Task { await pressWeatherSeal() } }
            )
            MarginaliaSealButton(
                title: "Location",
                systemImage: "mappin.and.ellipse",
                wax: Color(red: 0.36, green: 0.28, blue: 0.55),
                seed: 23,
                isBusy: busySealID == "location" || isAnchoringPlace,
                action: { Task { await pressLocationSeal() } }
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
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
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
    func pressLocationSeal() async {
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
        if !result.firstSouvenir.isEmpty {
            saveOnboardingFact(
                questionID: "onboarding-first-souvenir",
                question: "What was the first true sentence you kept?",
                answer: result.firstSouvenir,
                tags: ["souvenir", "first-page", "onboarding"]
            )
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
        BookFeedback.play(.braidComplete)
    }

    func saveOnboardingFact(questionID: String, question: String, answer: String, tags: [String]) {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        let fact = SelfFact(
            id: "onboarding:\(questionID)",
            questionID: questionID,
            question: question,
            answer: trimmed,
            bookTranslation: trimmed,
            sensitivity: .delight,
            usePermission: .privateContext,
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

    func saveElectives(_ list: [UnwrittenElective]) {
        guard let data = try? JSONEncoder().encode(list),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        electiveLedgerData = encoded
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        BookWhispers.refreshSchedule(enabled: bookWhispersEnabled, electives: list, whisperController: whisperController, whisperSovereign: whisperSovereign, festivalWhisper: festivalWhisperToday)
    }


    func acceptElectiveIfNeeded(surface: SurfacePage) {
        guard surface.type == .elective,
              surface.payload.metadata["electiveOffer"] == "true",
              let ask = surface.payload.metadata["electiveAsk"]?.nonEmpty else {
            return
        }
        var list = electives
        guard list.filter(\.isActive).count < UnwrittenElective.maxActive else {
            statusMessage = "The flyleaf is full. Complete a favor before accepting another."
            return
        }
        let senderID = surface.payload.metadata["senderID"] ?? "the-book"
        guard !list.contains(where: { $0.characterID == senderID && $0.isActive }) else { return }
        let elective = UnwrittenElective(
            id: "elective-\(senderID)-\(UUID().uuidString.prefix(8))",
            characterID: senderID,
            characterName: surface.payload.metadata["senderName"] ?? "A character",
            title: surface.payload.metadata["electiveTitle"] ?? "An Unwritten Elective",
            ask: ask,
            whyItMatters: surface.payload.metadata["electiveWhy"] ?? "",
            practiceShape: surface.payload.metadata["electivePractice"] ?? "One sentence of proof.",
            createdAt: Date()
        )
        list.append(elective)
        saveElectives(list)
        statusMessage = "\(elective.characterName)'s favor is tucked into the flyleaf."
    }

    @MainActor
    func completeElective(id: String, proof: String) {
        var list = electives
        guard let index = list.firstIndex(where: { $0.id == id && $0.isActive }) else { return }
        list[index].completedAt = Date()
        list[index].proof = proof.trimmingCharacters(in: .whitespacesAndNewlines)
        saveElectives(list)
        let elective = list[index]

        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + UnwrittenElective.completionBeliefReward)
        }
        let event = NarrativeEvent(
            id: "elective-complete-\(elective.id)",
            kind: .pageAnswered,
            sourcePageType: .elective,
            sourcePageID: nil,
            createdAt: Date(),
            summary: "The reader completed \(elective.characterName)'s favor \"\(elective.title)\": \(elective.proof ?? "")",
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
            statusMessage = "The favor is complete, but a hidden margin note slipped: \(error.localizedDescription)"
            return
        }
        statusMessage = "\(elective.characterName) will remember this. +\(UnwrittenElective.completionBeliefReward) Belief."
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
            continuity: continuity
        )
    }

    @MainActor
    func exportSaveFile() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(buildSaveFile())
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReEnchanted-\(formatter.string(from: Date())).\(ReEnchantedSaveFile.fileExtension)")
            try data.write(to: url, options: [.atomic])
            preparedSaveFileURL = url
            statusMessage = "The save file is bound and ready to share."
            BookFeedback.play(.braidComplete)
        } catch {
            statusMessage = "The save file would not bind: \(error.localizedDescription)"
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

        let briefs = TheBleedEditionBuilder.decodedBriefs(surface.payload.metadata["bleedBriefs"] ?? "")
        guard !briefs.isEmpty else {
            statusMessage = "The type tray came up empty. Penny is re-sorting the briefs."
            return false
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

        let kind = BleedEditionKind(rawValue: surface.payload.metadata["bleedEditionKind"] ?? "") ?? .morning
        let issueNumber = Int(surface.payload.metadata["bleedIssueNumber"] ?? "") ?? 1
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

    /// Binds the month to a PDF. By default the conclusion is the instant,
    /// deterministic `BookForewordWriter.closing(...)`; pass `useGemmaClosing`
    /// to have the on-device brain compose a fresh last word instead (slower,
    /// and it falls back to the deterministic closing if Gemma is quiet).
    @MainActor
    func exportMonthlyEdition(useGemmaClosing: Bool = false) {
        do {
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
                    generatedAt: now
                )
            }
            var edition: MonthlyEdition
            if let chosen = selectedEditionMonth {
                // The player named a month from the shelf — bind exactly that one.
                edition = buildMonth(starting: chosen)
            } else {
                // No choice made: prefer the previous calendar month, then fall back
                // to the most recent month that actually kept pages.
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
                    now: now
                )
                if auto.isEmpty, let latestMonth = bindableEditionMonths.first?.start {
                    auto = buildMonth(starting: latestMonth)
                }
                edition = auto
            }
            guard !edition.isEmpty else {
                colophonBindingNote = "I turned to that month and found the leaves still blank. Keep a page or two there first, and I'll have something to sew."
                BookFeedback.play(.error)
                return
            }
            if useGemmaClosing {
                // Ask the on-device brain for the last word, then bind.
                let pending = edition
                colophonBindingNote = "Asking Gemma for the last word on \(edition.monthName)…"
                Task { @MainActor in
                    var bound = pending
                    if let gemma = await gemmaMonthlyClosing(for: pending) {
                        bound.closing = gemma
                    }
                    do {
                        try bindMonthlyEditionPDF(bound)
                    } catch {
                        colophonBindingNote = "The thread snapped mid-stitch — the month would not bind. (\(error.localizedDescription))"
                        BookFeedback.play(.error)
                    }
                }
                return
            }

            try bindMonthlyEditionPDF(edition)
        } catch {
            colophonBindingNote = "The thread snapped mid-stitch — the month would not bind. (\(error.localizedDescription))"
            BookFeedback.play(.error)
        }
    }

    /// Writes a built edition to a temp PDF and surfaces it under the share mark.
    @MainActor
    private func bindMonthlyEditionPDF(_ edition: MonthlyEdition) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReEnchanted-Monthly-\(formatter.string(from: edition.startDate)).pdf")
        try MonthlyEditionPDFWriter.write(edition, to: url)
        preparedMonthlyEditionURL = url
        colophonBindingNote = "\(edition.monthName) is bound — \(edition.pageCount) \(edition.pageCount == 1 ? "page" : "pages") sewn between covers, waiting under the share mark."
        BookFeedback.play(.braidComplete)
    }

    /// The on-device brain re-reads the month and composes a closing in the
    /// Book's voice. Returns nil if the local brain is unavailable or quiet, in
    /// which case the deterministic closing already on the edition is kept.
    @MainActor
    private func gemmaMonthlyClosing(for edition: MonthlyEdition) async -> String? {
        let themeLine = edition.theme.map { "The month's theme was \u{201C}\($0.name)\u{201D}: \($0.line)" } ?? ""
        let signals = edition.continuity.strongestSignals.prefix(4).map(\.line).joined(separator: " ")
        let named = (edition.constellations.filter(\.isNamed).prefix(3).map(\.displayName)).joined(separator: ", ")
        let prompt = """
        Write the closing paragraph of \(edition.monthName) for The Book of You, in the Book's own voice: warm, literary, second-person, addressed to the reader. It bound \(edition.pageCount) pages across \(edition.dayCount) days. \(themeLine)
        What kept returning this month: \(signals)
        Named threads still alight: \(named.isEmpty ? "none yet" : named)
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
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReEnchanted-Annual-\(targetYear).pdf")
            try MonthlyEditionPDFWriter.writeAnnual(annual, to: url)
            preparedAnnualEditionURL = url
            statusMessage = "The \(targetYear) annual is bound — \(annual.chapters.count) \(annual.chapters.count == 1 ? "chapter" : "chapters"), ready to share."
            BookFeedback.play(.braidComplete)
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
            let save = try decoder.decode(ReEnchantedSaveFile.self, from: Data(contentsOf: url))

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
        guard let chapter = AcademyChapterRegistry.chapter(id: chapterID) else { return }
        saveOnboardingFact(
            questionID: "chapter-binding",
            question: "Which Chapter did the Binding recognize?",
            answer: chapter.name,
            tags: ["chapter", "identity", "binding", chapter.id]
        )
        // The binding itself is an act of Belief: the chapter's talisman warms.
        let talisman = GlowEntityMenuItem(
            id: chapter.talismanID,
            name: chapter.talismanName,
            kind: "talisman",
            glow: 0,
            line: chapter.philosophy
        )
        adjustEntityBelief(talisman, delta: 2, kind: .beliefInvested)
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        statusMessage = "The binding holds. Chapter \(chapter.name) claims your margins, and \(chapter.talismanName) warms by two points."
        BookFeedback.play(.braidComplete)
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
            learnedNotes: vault.data.learnedBraidNotes ?? []
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
            learnedNotes: vault.data.learnedBraidNotes ?? []
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
        if let prose = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: maxTokens,
            sourceID: sourceID,
            tags: tags
        ), !prose.hasPrefix("{") {
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
            You are the Labyrinth staging a disagreement between two cast members inside ReEnchanted. Prose only, no headings. Both positions must be fair; end by leaving the choice to the reader.
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

        let aStance = stanceLine(for: aProfile, name: aName, fallback: "the pages are asking for care before interpretation")
        let bStance = stanceLine(for: bProfile, name: bName, fallback: "the pages are asking for movement before certainty")
        let bridge = note.map { "\n\nBetween them, the old thread hums: \($0)" } ?? ""

        return """
        \(aName) and \(bName) read the same recent pages and did not come back with the same weather in their hands.

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
        let metadata = base.payload.metadata
        let aName = metadata["entityAName"] ?? "One character"
        let bName = metadata["entityBName"] ?? "Another character"
        let kind = metadata["bondKind"] ?? "alliance"
        return await generatedProseSurface(
            from: base,
            proseKey: "castBondProse",
            prompt: LocalModelManager.castBondPrompt(surface: base, day: today),
            instructions: """
            You are the Labyrinth staging an emergent relationship beat inside ReEnchanted. Prose only, no headings. The relationship milestone must become visible as a scene.
            """,
            maxTokens: 620,
            sourceID: "cast-bond",
            tags: ["cast-bond", kind, "entity:\(metadata["entityAID"] ?? "")", "entity:\(metadata["entityBID"] ?? "")"],
            fallbackBody: "\(aName) and \(bName) crossed a \(kind) threshold in the Loom. The Book saw the thread change color, and from then on the web no longer treated them as strangers."
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
            You are the Book inside ReEnchanted staging a controlled Book Jump into a named public-domain work. Write to the senses, name the book's actual places and people, and never settle for generic mood. \(continuityInstruction) Prose only, no headings, no quotes from the source text.
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
        let generated = await LocalBrainProse.write(
            prompt: LocalModelManager.supportGuildPrompt(surface: base),
            instructions: """
            You are the Support Guild scribe inside ReEnchanted. Return only the requested labeled sections. Complete every sentence. Never label prose paragraphs with "Try:".
            """,
            maxTokens: 760,
            sourceID: "support-guild",
            tags: ["support-guild", "dr-vellum", "dr-inkrest"]
        )
        let raw = (generated?.hasPrefix("{") == false) ? (generated ?? "") : ""
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
            instructions: base.payload.metadata["packInstructions"] ?? "You are the Book inside ReEnchanted. Write the requested page in prose only.",
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
            payload: BookPagePayload(headline: "An Unwritten Elective", body: body, metadata: metadata)
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
                + BookReferenceCatalog.lorePacks.flatMap(\.snippets)
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
        case .memory, .elective, .pageFamily:
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
        vault.save()
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        let title = BookShopCatalog.listing(forPackID: packID)?.title ?? packID
        statusMessage = "\(title) is bound to your save. New pages will find their way to the desk."
        BookFeedback.play(.braidComplete)
    }

    // MARK: - Fuel arithmetic

    /// Fire-and-forget: the page is already kept; Vellum's assistant adds
    /// the numbers to the chart when the ledger answers.
    func enrichFuelEntry(_ entry: FacultyEntry) {
        Task { @MainActor in
            guard let estimate = await VellumNutritionist.estimate(for: entry.rawText) else { return }
            var amended = entry
            amended.rawText = "\(entry.rawText)\n\(estimate.chartLine)"
            do {
                try BookDatabase.upsertFacultyEntry(amended)
                facultyEntries = (try? BookDatabase.facultyEntries(limit: 160)) ?? facultyEntries
                statusMessage = "Vellum's assistant pencils in the numbers: \(estimate.chartLine)"
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

            let passesNote = knocksThisSession == 1 ? Int.random(in: 0..<4) == 0 : Int.random(in: 0..<3) == 0
            if passesNote || knocksThisSession >= 4 {
                let note = BannerKnockNotes.note(
                    greyLevel: NothingTide.greyLevel(
                        quietDays: NothingTide.quietDays(in: days, today: today.id),
                        narrativeHeat: narrativeEvents.prefix(24).count,
                        distressActive: false
                    ),
                    ascendantChapterName: ascendantTalisman.flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0.id)?.name },
                    hour: Calendar.current.component(.hour, from: now),
                    moonName: MoonPhaseCalendar.phase().name,
                    knocksThisSession: knocksThisSession,
                    roll: Int.random(in: 0..<1_000)
                )
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
