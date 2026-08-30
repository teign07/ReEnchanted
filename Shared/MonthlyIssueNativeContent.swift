import Foundation

// MARK: - Native authored objects

/// A monthly issue does not mint a second set of media players or Page types.
/// These objects are the authored payloads consumed by the Book's existing
/// Story Page, Radio, Bleed, illumination, and Pagewright seams.
protocol MonthlyIssueNativeContent: Identifiable, Codable, Equatable where ID == String {
    var id: String { get }
    var packID: String { get }
    var eventID: String { get }
}

extension MonthlyIssueNativeContent {
    var monthlyIssueScopedID: String { "\(packID):\(eventID):\(id)" }
}

/// Delivered packs are release-validated, but runtime ingestion still refuses
/// to make a duplicate-ID JSON mistake into a process trap. Validation reports
/// the duplicate; this index simply keeps the first object deterministically.
private func monthlyIssueNativeIndex<Content: MonthlyIssueNativeContent>(
    _ contents: [Content]
) -> [String: Content] {
    contents.reduce(into: [:]) { index, content in
        if index[content.monthlyIssueScopedID] == nil {
            index[content.monthlyIssueScopedID] = content
        }
    }
}

struct AuthoredStorySceneChoice: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var prompt: String
    var result: String
    var effectLine: String = ""
    var symbolName: String? = nil
    var consequenceTags: [String] = []
}

/// One fully pre-written Story Page. The manifest owns its interaction mode:
/// the same Page family can be a plain scene, a choice, a response, a proof
/// return, or a field mission without asking a model to finish the fiction.
struct AuthoredStoryScene: MonthlyIssueNativeContent {
    var id: String
    var packID: String
    var eventID: String
    var title: String
    var opening: String
    var prompt: String
    var detail: String
    var responsePlaceholder: String? = nil
    var missionInvitation: String? = nil
    var missionReturnPrompt: String? = nil
    var choices: [AuthoredStorySceneChoice] = []
    var entities: [String] = []
    var tags: [String] = []
}

struct AuthoredRadioBanter: MonthlyIssueNativeContent {
    var id: String
    var packID: String
    var eventID: String
    var stationID: String
    var banter: RadioBanter
}

struct AuthoredBleedArticle: MonthlyIssueNativeContent {
    var id: String
    var packID: String
    var eventID: String
    var title: String
    var byline: String
    var body: String
    var editionKinds: [BleedEditionKind] = BleedEditionKind.allCases
    var tags: [String] = []
}

/// A directed use of an installed illumination asset. The asset remains in
/// Pagewright's permanent cabinet; this object only decides when the Curator
/// may pencil it onto one of the issue's published leaves.
struct AuthoredMarginaliaMark: MonthlyIssueNativeContent {
    var id: String
    var packID: String
    var eventID: String
    var assetPackID: String
    var assetID: String
    var tags: [String] = []
    var targetPageTypes: [BookPageType] = []
    var targetSourceIDs: [String] = []
    var targetTagsAny: [String] = []

    func accepts(_ page: SurfacePage) -> Bool {
        if !targetPageTypes.isEmpty, !targetPageTypes.contains(page.type) { return false }
        if !targetSourceIDs.isEmpty, !targetSourceIDs.contains(page.sourceID) { return false }
        if !targetTagsAny.isEmpty {
            let pageTags = Set(page.readerLearningTags.map(Self.normalized))
            guard targetTagsAny.map(Self.normalized).contains(where: pageTags.contains) else {
                return false
            }
        }
        return true
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - One resolver for every native seam

struct ResolvedMonthlyIssueContent: Equatable {
    var manifest: MonthlyIssueAuthoringManifest
    var atom: MonthlyIssueContentAtom
    var snapshot: WorldEventLifecycleSnapshot

    var scope: AuthoredContentScope {
        AuthoredContentScope(
            scopeID: manifest.id,
            runID: snapshot.runID,
            phaseID: snapshot.phaseID
        )
    }

    func receipt(
        occurrenceID: String,
        state: AuthoredContentReceiptState,
        at now: Date,
        choiceID: String? = nil,
        evidencePageIDs: [String] = []
    ) -> AuthoredContentReceipt {
        AuthoredContentReceipt(
            contentID: atom.id,
            occurrenceID: occurrenceID,
            channel: atom.channel,
            scope: scope,
            state: state,
            recordedAt: now,
            choiceID: choiceID,
            evidencePageIDs: evidencePageIDs
        )
    }
}

enum MonthlyIssueContentResolver {
    static func eligible(
        channel: AuthoredContentChannel,
        referenceKind: MonthlyIssueContentReferenceKind,
        referenceID: String? = nil,
        day: BookDay,
        inputs rawInputs: BookSourceInputs,
        now: Date,
        lifecycleOverride: [WorldEventLifecycleSnapshot]? = nil
    ) -> [ResolvedMonthlyIssueContent] {
        let inputs = rawInputs.resolvingWorldEvents(for: day, now: now)
        let lifecycle = lifecycleOverride ?? WorldEventResolver.lifecycleEvents(
            now: now,
            ledger: inputs.worldEventLifecycle
        )
        let pageContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        return inputs.monthlyIssueAuthoringManifests.flatMap { manifest in
            manifest.content.compactMap { atom in
                guard atom.productionStatus.countsAsReady,
                      atom.channel == channel,
                      atom.reference.kind == referenceKind,
                      referenceID.map({ atom.reference.id == $0 }) ?? true,
                      let snapshot = lifecycle.first(where: {
                          $0.packID == manifest.eventPackID && $0.eventID == manifest.eventID
                      }),
                      placement(atom.placement, matches: snapshot),
                      audience(atom.audience, matchesParticipation: snapshot.participated)
                else { return nil }

                let resolved = ResolvedMonthlyIssueContent(
                    manifest: manifest,
                    atom: atom,
                    snapshot: snapshot
                )
                let gateContext = AuthoredContentGateContext.page(
                    pageContext,
                    lifecycle: lifecycle,
                    receiptLedger: inputs.authoredContentReceipts,
                    contentScope: resolved.scope
                )
                let isReport = atom.voice == .publicReport || atom.voice == .nonparticipantRumor
                guard atom.gate.allows(in: gateContext, contentID: atom.id),
                      atom.occurrence.allows(
                          contentID: atom.id,
                          scope: resolved.scope,
                          ledger: inputs.authoredContentReceipts,
                          now: now
                      ),
                      atom.dependencies.allSatisfy({ dependency in
                          dependency.isSatisfied(
                              in: inputs.authoredContentReceipts,
                              currentScope: resolved.scope,
                              now: now
                          ) || (dependency.failurePolicy == .reportThenContinue && isReport)
                      })
                else { return nil }
                return resolved
            }
        }.sorted(by: preferred)
    }

    private static func placement(
        _ placement: MonthlyIssueContentPlacement,
        matches snapshot: WorldEventLifecycleSnapshot
    ) -> Bool {
        guard placement.lifecycleStage == snapshot.stage else { return false }
        if placement.lifecycleStage == .live {
            if let phaseID = placement.phaseID, phaseID != snapshot.phaseID { return false }
            if let role = placement.phaseRole, role != snapshot.phaseRole { return false }
        }
        return true
    }

    private static func audience(
        _ audience: MonthlyIssueContentAudience,
        matchesParticipation participated: Bool
    ) -> Bool {
        switch audience {
        case .everyone: return true
        case .participants: return participated
        case .nonparticipants: return !participated
        }
    }

    private static func preferred(
        _ left: ResolvedMonthlyIssueContent,
        _ right: ResolvedMonthlyIssueContent
    ) -> Bool {
        if left.atom.priority.curatorRank != right.atom.priority.curatorRank {
            return left.atom.priority.curatorRank > right.atom.priority.curatorRank
        }
        if left.manifest.issueNumber != right.manifest.issueNumber {
            return left.manifest.issueNumber > right.manifest.issueNumber
        }
        return left.atom.id < right.atom.id
    }
}

// MARK: - Surface receipts and attachments

struct AuthoredContentSurfaceAttachment: Codable, Equatable {
    var contentID: String
    var occurrenceID: String
    var channel: AuthoredContentChannel
    var scope: AuthoredContentScope

    func receipt(state: AuthoredContentReceiptState, at now: Date) -> AuthoredContentReceipt {
        AuthoredContentReceipt(
            contentID: contentID,
            occurrenceID: occurrenceID,
            channel: channel,
            scope: scope,
            state: state,
            recordedAt: now
        )
    }
}

enum AuthoredContentSurfaceAttachments {
    static let metadataKey = "authoredContentAttachments"

    static func encoded(_ attachments: [AuthoredContentSurfaceAttachment]) -> String {
        guard let data = try? JSONEncoder().encode(attachments),
              let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }

    static func decoded(_ raw: String?) -> [AuthoredContentSurfaceAttachment] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AuthoredContentSurfaceAttachment].self, from: data)) ?? []
    }
}

extension SurfacePage {
    func authoredContentReceipts(
        state: AuthoredContentReceiptState,
        at now: Date,
        choiceID: String? = nil,
        evidencePageIDs: [String] = []
    ) -> [AuthoredContentReceipt] {
        var receipts: [AuthoredContentReceipt] = []
        if let contentID = payload.metadata[MonthlyIssuePageMetadata.contentID]?.nonEmpty,
           let channelRaw = payload.metadata[MonthlyIssuePageMetadata.channel],
           let channel = AuthoredContentChannel(rawValue: channelRaw) {
            receipts.append(AuthoredContentReceipt(
                contentID: contentID,
                occurrenceID: payload.metadata[MonthlyIssuePageMetadata.occurrenceID]?.nonEmpty ?? id,
                channel: channel,
                scope: AuthoredContentScope(
                    scopeID: payload.metadata[MonthlyIssuePageMetadata.scopeID]?.nonEmpty,
                    runID: payload.metadata[MonthlyIssuePageMetadata.runID]?.nonEmpty,
                    phaseID: payload.metadata[MonthlyIssuePageMetadata.phaseID]?.nonEmpty
                ),
                state: state,
                recordedAt: now,
                choiceID: choiceID,
                evidencePageIDs: evidencePageIDs
            ))
        }
        receipts += AuthoredContentSurfaceAttachments
            .decoded(payload.metadata[AuthoredContentSurfaceAttachments.metadataKey])
            .map { attachment in
                AuthoredContentReceipt(
                    contentID: attachment.contentID,
                    occurrenceID: attachment.occurrenceID,
                    channel: attachment.channel,
                    scope: attachment.scope,
                    state: state,
                    recordedAt: now,
                    choiceID: choiceID,
                    evidencePageIDs: evidencePageIDs
                )
            }
        var seen = Set<String>()
        return receipts.filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Native Story Page adapter

enum AuthoredStoryScenePageAdapter {
    static let choicesMetadataKey = "authoredStoryChoices"

    static func candidates(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        let referenced = Set(inputs.monthlyIssueAuthoringManifests.flatMap { manifest in
            manifest.content.compactMap { atom in
                atom.reference.kind == .storyScene
                    ? "\(manifest.eventPackID):\(manifest.eventID):\(atom.reference.id)"
                    : nil
            }
        })
        guard !referenced.isEmpty else { return [] }
        return inputs.authoredStoryScenes
            .filter { referenced.contains($0.monthlyIssueScopedID) }
            .map { surface(for: $0, day: day, now: now) }
    }

    private static func surface(
        for scene: AuthoredStoryScene,
        day: BookDay,
        now: Date
    ) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .narrativeOS)
        let encodedChoices: String = {
            guard let data = try? JSONEncoder().encode(scene.choices),
                  let text = String(data: data, encoding: .utf8) else { return "[]" }
            return text
        }()
        let tags = Array(Set(
            scene.tags + [
                "authored-story-scene",
                "event:\(scene.eventID)",
                "world-event:\(scene.eventID)"
            ]
        )).sorted()
        return SurfacePage(
            id: "authored-story-scene-\(scene.id)-\(Int(now.timeIntervalSince1970 / 3_600))",
            type: .narrativeOS,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 82,
            reason: "A scene in this month's margins has reached its turn.",
            prompt: scene.prompt,
            detail: scene.detail,
            payload: BookPagePayload(
                headline: scene.title,
                body: scene.opening,
                metadata: [
                    "source": source.id,
                    MonthlyIssuePageMetadata.authoredStoryScene: "true",
                    "authoredStorySceneID": scene.id,
                    "storySceneID": scene.id,
                    "storyScene": scene.opening,
                    choicesMetadataKey: encodedChoices,
                    "selectedEntities": scene.entities.joined(separator: ", "),
                    "placeholder": scene.responsePlaceholder ?? scene.missionReturnPrompt ?? "",
                    "livedMissionInvitation": scene.missionInvitation ?? "",
                    "livedMissionReturnPrompt": scene.missionReturnPrompt ?? "",
                    MonthlyIssuePageMetadata.referenceKind: MonthlyIssueContentReferenceKind.storyScene.rawValue,
                    MonthlyIssuePageMetadata.referenceID: scene.id,
                    "worldEventIDs": scene.eventID,
                    "worldEventPackID": scene.packID,
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }

    static func capabilities(for interaction: MonthlyIssueInteractionKind) -> PageCapabilityContract {
        switch interaction {
        case .none:
            return PageCapabilityContract(
                supportedMovements: [.livingWorld, .humanOtherness],
                supportedRoles: [.horizon, .echo],
                emotionalFunctions: [.wonder, .remember],
                effort: .glance,
                reach: .insideBook,
                estimatedMinutes: 3,
                asksReader: false,
                pressureCost: 0.04
            )
        case .choice:
            return PageCapabilityContract(
                supportedMovements: [.livingWorld, .scriptFreedom, .humanOtherness],
                supportedRoles: [.horizon, .door],
                emotionalFunctions: [.wonder, .play, .act],
                effort: .small,
                reach: .insideBook,
                estimatedMinutes: 6,
                asksReader: true,
                pressureCost: 0.18,
                proofModes: [.response]
            )
        case .readerResponse:
            return PageCapabilityContract(
                supportedMovements: [.exactLanguage, .scriptFreedom],
                supportedRoles: [.door],
                emotionalFunctions: [.express, .act],
                effort: .small,
                reach: .insideBook,
                estimatedMinutes: 5,
                asksReader: true,
                pressureCost: 0.22,
                proofModes: [.response]
            )
        case .readerEvidence:
            return PageCapabilityContract(
                supportedMovements: [.freshSight, .livingContinuity],
                supportedRoles: [.door, .echo],
                emotionalFunctions: [.notice, .remember, .act],
                effort: .small,
                reach: .nearbyWorld,
                estimatedMinutes: 8,
                asksReader: true,
                pressureCost: 0.36,
                proofModes: [.response, .observation, .photograph, .voice]
            )
        case .fieldMission:
            return PageCapabilityContract(
                supportedMovements: [.freshSight, .chosenDetour, .livingContinuity],
                supportedRoles: [.door],
                emotionalFunctions: [.wonder, .play, .act],
                effort: .involved,
                reach: .nearbyWorld,
                estimatedMinutes: 20,
                asksReader: true,
                pressureCost: 0.68,
                proofModes: [.response, .observation, .photograph, .voice, .place]
            )
        }
    }
}

// MARK: - Native media resolution

struct ResolvedAuthoredRadioBanter: Equatable {
    var content: ResolvedMonthlyIssueContent
    var authored: AuthoredRadioBanter
    var occurrenceID: String
}

enum AuthoredRadioBanterResolver {
    static func eligible(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> [ResolvedAuthoredRadioBanter] {
        let resolvedInputs = inputs.resolvingWorldEvents(for: day, now: now)
        let artifacts = monthlyIssueNativeIndex(resolvedInputs.authoredRadioBanters)
        return MonthlyIssueContentResolver.eligible(
            channel: .radioBanter,
            referenceKind: .radioBanter,
            day: day,
            inputs: resolvedInputs,
            now: now
        ).compactMap { content in
            let artifactID = "\(content.manifest.eventPackID):\(content.manifest.eventID):\(content.atom.reference.id)"
            guard let authored = artifacts[artifactID],
                  authored.packID == content.manifest.eventPackID,
                  authored.eventID == content.manifest.eventID else { return nil }
            return ResolvedAuthoredRadioBanter(
                content: content,
                authored: authored,
                occurrenceID: "radio-\(authored.id)-\(Int(now.timeIntervalSince1970 / 900))"
            )
        }
    }
}

struct ResolvedAuthoredBleedArticle: Equatable {
    var content: ResolvedMonthlyIssueContent
    var authored: AuthoredBleedArticle
    var brief: BleedColumnBrief
    var attachment: AuthoredContentSurfaceAttachment
}

enum AuthoredBleedArticleResolver {
    static func eligible(
        kind: BleedEditionKind,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> [ResolvedAuthoredBleedArticle] {
        let resolvedInputs = inputs.resolvingWorldEvents(for: day, now: now)
        let artifacts = monthlyIssueNativeIndex(resolvedInputs.authoredBleedArticles)
        let occurrenceSlot = TheBleedEditionBuilder.slotID(for: kind, day: day)
        return MonthlyIssueContentResolver.eligible(
            channel: .bleedArticle,
            referenceKind: .bleedArticle,
            day: day,
            inputs: resolvedInputs,
            now: now
        ).compactMap { content in
            let artifactID = "\(content.manifest.eventPackID):\(content.manifest.eventID):\(content.atom.reference.id)"
            guard let article = artifacts[artifactID],
                  article.packID == content.manifest.eventPackID,
                  article.eventID == content.manifest.eventID,
                  article.editionKinds.contains(kind) else { return nil }
            let occurrenceID = "bleed-\(article.id)-\(occurrenceSlot)"
            return ResolvedAuthoredBleedArticle(
                content: content,
                authored: article,
                brief: BleedColumnBrief(
                    id: "authored-\(article.id)",
                    title: article.title,
                    byline: article.byline,
                    composedBody: article.body,
                    packet: "",
                    maxTokens: 0
                ),
                attachment: AuthoredContentSurfaceAttachment(
                    contentID: content.atom.id,
                    occurrenceID: occurrenceID,
                    channel: .bleedArticle,
                    scope: content.scope
                )
            )
        }
    }
}

struct ResolvedAuthoredMarginalia: Equatable {
    var content: ResolvedMonthlyIssueContent
    var authored: AuthoredMarginaliaMark
}

enum MonthlyIssueMarginaliaDresser {
    /// One directed issue mark per nine-leaf published block. Occurrence and
    /// cooldown rules may make it rarer; nothing can make it noisier.
    static func dressing(
        _ pages: [SurfacePage],
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        distressActive: Bool
    ) -> [SurfacePage] {
        guard !distressActive, !pages.isEmpty else { return pages }
        let resolvedInputs = inputs.resolvingWorldEvents(for: day, now: now)
        let artifacts = monthlyIssueNativeIndex(resolvedInputs.authoredMarginaliaMarks)
        let eligible: [ResolvedAuthoredMarginalia] = MonthlyIssueContentResolver.eligible(
            channel: .marginalia,
            referenceKind: .marginalia,
            day: day,
            inputs: resolvedInputs,
            now: now
        ).compactMap { content in
            let artifactID = "\(content.manifest.eventPackID):\(content.manifest.eventID):\(content.atom.reference.id)"
            guard let mark = artifacts[artifactID],
                  mark.packID == content.manifest.eventPackID,
                  mark.eventID == content.manifest.eventID else { return nil }
            return ResolvedAuthoredMarginalia(content: content, authored: mark)
        }
        guard !eligible.isEmpty else { return pages }

        let publishedLimit = min(pages.count, BookDeskRound.reserveCapacity)
        for resolved in eligible {
            guard let index = pages.indices.prefix(publishedLimit).first(where: { index in
                let page = pages[index]
                return page.payload.metadata["firstRunStep"] == nil
                    && page.payload.metadata["authoredMarginaliaID"] == nil
                    && resolved.authored.accepts(page)
            }) else { continue }
            var result = pages
            let occurrenceID = "marginalia-\(resolved.authored.id)-\(day.id)"
            let attachment = AuthoredContentSurfaceAttachment(
                contentID: resolved.content.atom.id,
                occurrenceID: occurrenceID,
                channel: .marginalia,
                scope: resolved.content.scope
            )
            let existingAttachments = AuthoredContentSurfaceAttachments.decoded(
                result[index].payload.metadata[AuthoredContentSurfaceAttachments.metadataKey]
            )
            result[index] = result[index].withMetadata([
                "authoredMarginaliaID": resolved.authored.id,
                "authoredMarginaliaAssetID": resolved.authored.assetID,
                "marginaliaPackID": resolved.authored.assetPackID,
                "marginaliaTags": resolved.authored.tags.joined(separator: ","),
                "decorationWorldEventIDs": resolved.authored.eventID,
                AuthoredContentSurfaceAttachments.metadataKey:
                    AuthoredContentSurfaceAttachments.encoded(existingAttachments + [attachment])
            ])
            return result
        }
        return pages
    }
}

// MARK: - Synthetic-clock authoring instrument

struct MonthlyIssueSimulationPersona: Codable, Identifiable, Equatable {
    var id: String
    var subscribedFrom: Date
    var subscribedUntil: Date? = nil
    var firstPresentAt: Date
    var absentFrom: Date? = nil
    var returnsAt: Date? = nil
    /// Content IDs for which this synthetic reader supplies a real answer,
    /// choice, or return. Merely receiving content never implies participation.
    var participatingContentIDs: Set<String> = []

    func isSubscribed(at date: Date) -> Bool {
        date >= subscribedFrom && date < (subscribedUntil ?? .distantFuture)
    }

    func isPresent(at date: Date) -> Bool {
        guard date >= firstPresentAt else { return false }
        if let absentFrom, date >= absentFrom, date < (returnsAt ?? .distantFuture) {
            return false
        }
        return true
    }
}

struct MonthlyIssueSimulationFrame: Codable, Identifiable, Equatable {
    var personaID: String
    var date: Date
    var subscriptionActive: Bool
    var readerPresent: Bool
    var lifecycleStage: WorldEventLifecycleStage?
    var phaseRole: WorldEventPhaseRole?
    var residueVoice: WorldEventResidueVoice?
    var eligiblePageContentIDs: [String]
    var eligibleStorySceneIDs: [String]
    var eligibleRadioBanterIDs: [String]
    var eligibleBleedArticleIDs: [String]
    var eligibleMarginaliaIDs: [String]
    var deliveredContentIDs: [String]
    var participated: Bool

    var id: String { "\(personaID):\(date.timeIntervalSinceReferenceDate)" }
}

struct MonthlyIssueAuthoringSimulation: Equatable {
    var frames: [MonthlyIssueSimulationFrame]
    var finalLifecycleLedger: WorldEventLifecycleLedger
    var finalContentLedger: AuthoredContentReceiptLedger
}

enum MonthlyIssueAuthoringSimulator {
    /// Walks the six-week shelf at morning, evening, and night. It uses the
    /// production gate/dependency/occurrence resolver and the production
    /// receipt types, but never touches the app vault or waits for wall time.
    static func run(
        pack: WorldEventPack,
        manifestID: String,
        persona: MonthlyIssueSimulationPersona,
        from start: Date,
        through end: Date,
        sampleHours: [Int] = [9, 18, 23],
        calendar: Calendar = .current
    ) -> MonthlyIssueAuthoringSimulation {
        guard let manifest = pack.authoringManifests?.first(where: { $0.id == manifestID }),
              let event = pack.events.first(where: { $0.id == manifest.eventID }) else {
            return MonthlyIssueAuthoringSimulation(
                frames: [],
                finalLifecycleLedger: .empty,
                finalContentLedger: .empty
            )
        }

        var lifecycleLedger = WorldEventLifecycleLedger.empty
        var contentLedger = AuthoredContentReceiptLedger.empty
        var frames: [MonthlyIssueSimulationFrame] = []
        var date = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let hours = Array(Set(sampleHours.filter { (0...23).contains($0) })).sorted()

        while date <= last {
            for hour in hours {
                let now = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
                let subscribed = persona.isSubscribed(at: now)
                let present = persona.isPresent(at: now)
                var snapshot = WorldEventResolver.lifecycleSnapshot(
                    packID: pack.id,
                    event: event,
                    now: now,
                    ledger: lifecycleLedger,
                    calendar: calendar
                )

                var inputs = BookSourceInputs.empty
                inputs.monthlyIssueAuthoringManifests = [manifest]
                inputs.authoredStoryScenes = pack.storyScenes ?? []
                inputs.authoredRadioBanters = pack.radioBanters ?? []
                inputs.authoredBleedArticles = pack.bleedArticles ?? []
                inputs.authoredMarginaliaMarks = pack.marginalia ?? []
                inputs.authoredContentReceipts = contentLedger
                inputs.worldEventLifecycle = lifecycleLedger
                let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: date, pages: [])

                func eligible(
                    _ channel: AuthoredContentChannel,
                    _ referenceKind: MonthlyIssueContentReferenceKind
                ) -> [ResolvedMonthlyIssueContent] {
                    guard subscribed, present, let snapshot else { return [] }
                    return MonthlyIssueContentResolver.eligible(
                        channel: channel,
                        referenceKind: referenceKind,
                        day: day,
                        inputs: inputs,
                        now: now,
                        lifecycleOverride: [snapshot]
                    )
                }

                let page = eligible(.page, .pageArchetype)
                    + eligible(.page, .worldEventBeat)
                let story = eligible(.storyScene, .storyScene)
                    + eligible(.storyScene, .worldEventBeat)
                let radio = eligible(.radioBanter, .radioBanter)
                let bleed = eligible(.bleedArticle, .bleedArticle)
                let marginalia = eligible(.marginalia, .marginalia)

                // One item per native channel at a sampling instant mirrors
                // the production density ceilings: one issue Page and one
                // directed mark per block, one article per edition, one break
                // at a playout turn. A dependency therefore advances on the
                // next sample rather than avalanching in the same desk build.
                let deliveries = [page.first, story.first, radio.first, bleed.first, marginalia.first]
                    .compactMap { $0 }
                var deliveredIDs: [String] = []
                for resolved in deliveries {
                    let occurrenceID = "simulation:\(persona.id):\(resolved.atom.channel.rawValue):\(Int(now.timeIntervalSince1970))"
                    let deliveryState: AuthoredContentReceiptState = resolved.atom.channel == .radioBanter
                        ? .played
                        : .delivered
                    contentLedger = contentLedger.recording(resolved.receipt(
                        occurrenceID: occurrenceID,
                        state: deliveryState,
                        at: now
                    ))
                    deliveredIDs.append(resolved.atom.id)

                    if persona.participatingContentIDs.contains(resolved.atom.id),
                       resolved.atom.interaction.acceptsParticipation,
                       snapshot?.stage == .live {
                        contentLedger = contentLedger.recording(resolved.receipt(
                            occurrenceID: occurrenceID,
                            state: .completed,
                            at: now,
                            evidencePageIDs: ["simulation-evidence:\(persona.id):\(resolved.atom.id)"]
                        ))
                        if let runID = snapshot?.runID {
                            lifecycleLedger = WorldEventLifecycleReconciler.recordingParticipationEvidence(
                                ledger: lifecycleLedger,
                                eventID: event.id,
                                runID: runID,
                                evidencePageIDs: ["simulation-evidence:\(persona.id):\(resolved.atom.id)"],
                                now: now
                            )
                            snapshot = WorldEventResolver.lifecycleSnapshot(
                                packID: pack.id,
                                event: event,
                                now: now,
                                ledger: lifecycleLedger,
                                calendar: calendar
                            )
                        }
                    }
                }

                frames.append(MonthlyIssueSimulationFrame(
                    personaID: persona.id,
                    date: now,
                    subscriptionActive: subscribed,
                    readerPresent: present,
                    lifecycleStage: snapshot?.stage,
                    phaseRole: snapshot?.phaseRole,
                    residueVoice: snapshot?.stage == .residue ? snapshot?.residueVoice : nil,
                    eligiblePageContentIDs: page.map(\.atom.id),
                    eligibleStorySceneIDs: story.map(\.atom.id),
                    eligibleRadioBanterIDs: radio.map(\.atom.id),
                    eligibleBleedArticleIDs: bleed.map(\.atom.id),
                    eligibleMarginaliaIDs: marginalia.map(\.atom.id),
                    deliveredContentIDs: deliveredIDs.sorted(),
                    participated: snapshot?.participated ?? false
                ))
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? end.addingTimeInterval(1)
        }

        return MonthlyIssueAuthoringSimulation(
            frames: frames,
            finalLifecycleLedger: lifecycleLedger,
            finalContentLedger: contentLedger
        )
    }
}
