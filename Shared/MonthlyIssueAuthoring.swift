import Foundation

// MARK: - Monthly issue authoring manifest

/// The authoring manifest is deliberately separate from the signed delivery
/// manifest. Delivery answers which verified files belong on the device;
/// authoring answers whether those files add up to a coherent live month.
enum MonthlyIssuePublicationKind: String, Codable, Equatable {
    case rehearsal
    case publicIssue
}

enum MonthlyIssueProductionStatus: String, Codable, Equatable, CaseIterable {
    case planned
    case draft
    case ready
    case reuse
    case cut

    var countsAsReady: Bool {
        self == .ready || self == .reuse
    }
}

enum MonthlyIssueContentPriority: String, Codable, Equatable, CaseIterable {
    /// May appear when the ordinary compositor has room.
    case ambient
    /// Should be noticeably present during its window.
    case featured
    /// Part of the issue's dramatic through-line.
    case spine
    /// A once-only turn that may claim the issue's milestone slot.
    case milestone

    /// A tilt, not a guarantee. The Curator's separate reservation policy is
    /// what lets live spine work skip the line; these small lifts merely make
    /// featured connective tissue easier to notice through ordinary ranking.
    var curatorScoreLift: Int {
        switch self {
        case .ambient: return 0
        case .featured: return 8
        case .spine: return 12
        case .milestone: return 16
        }
    }

    var curatorRank: Int {
        switch self {
        case .ambient: return 0
        case .featured: return 1
        case .spine: return 2
        case .milestone: return 3
        }
    }
}

enum MonthlyIssueContentAudience: String, Codable, Equatable {
    case everyone
    case participants
    case nonparticipants
}

enum MonthlyIssueNarrativeVoice: String, Codable, Equatable {
    /// Present-tense fiction or information that makes no participation claim.
    case immediate
    /// Third-person history safe for every reader.
    case publicReport
    /// A consequence that may appear only when participation is receipted.
    case participantReceipt
    /// Secondhand history for a reader who was not there.
    case nonparticipantRumor
}

enum MonthlyIssueInteractionKind: String, Codable, Equatable, CaseIterable {
    case none
    case choice
    case readerResponse
    case readerEvidence
    case fieldMission

    var acceptsParticipation: Bool { self != .none }
}

/// References stay native. A radio script remains a Radio object, a Bleed
/// article remains a Bleed object, and letters/classes remain ordinary Pages.
enum MonthlyIssueContentReferenceKind: String, Codable, Equatable {
    case worldEventBeat
    case pageArchetype
    case storyScene
    case marginalia
    case radioBanter
    case bleedArticle

    func supports(_ channel: AuthoredContentChannel) -> Bool {
        switch self {
        case .worldEventBeat:
            return channel == .page || channel == .storyScene
        case .pageArchetype:
            return channel == .page
        case .storyScene:
            return channel == .storyScene
        case .marginalia:
            return channel == .marginalia
        case .radioBanter:
            return channel == .radioBanter
        case .bleedArticle:
            return channel == .bleedArticle
        }
    }
}

struct MonthlyIssueContentReference: Codable, Equatable {
    var kind: MonthlyIssueContentReferenceKind
    var id: String
}

/// Foreshadow and residue are lifecycle shelves, not extra dramatic phases.
/// Consequently only live atoms carry a phase ID and universal phase role.
struct MonthlyIssueContentPlacement: Codable, Equatable {
    var lifecycleStage: WorldEventLifecycleStage
    var phaseID: String? = nil
    var phaseRole: WorldEventPhaseRole? = nil

    fileprivate var chronologicalRank: Int {
        switch lifecycleStage {
        case .foreshadow:
            return 0
        case .live:
            switch phaseRole {
            case .setup: return 1
            case .buildup: return 2
            case .climax: return 3
            case .aftermath: return 4
            // A phase-spanning ambient mark can depend on a Buildup event and
            // remain visible in Climax. Rank it at the end of the live span.
            case nil: return 4
            }
        case .residue:
            return 5
        case .sealed:
            return 6
        case .casebookAvailable:
            return 7
        }
    }
}

/// An authored follow-up may have a different live window from its first offer.
/// Missions use it after acceptance; node stories use it after an opening.
struct MonthlyIssueFollowUpWindow: Codable, Equatable {
    var placement: MonthlyIssueContentPlacement
    var gate: AuthoredContentGate = AuthoredContentGate()
}

typealias MonthlyIssueMissionReturn = MonthlyIssueFollowUpWindow

struct MonthlyIssueContentAtom: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var reference: MonthlyIssueContentReference
    var channel: AuthoredContentChannel
    var placement: MonthlyIssueContentPlacement
    var audience: MonthlyIssueContentAudience = .everyone
    var voice: MonthlyIssueNarrativeVoice = .immediate
    var interaction: MonthlyIssueInteractionKind = .none
    var priority: MonthlyIssueContentPriority = .ambient
    var gate: AuthoredContentGate = AuthoredContentGate()
    var occurrence: AuthoredContentOccurrencePolicy = .oncePerRun
    var dependencies: [AuthoredContentDependency] = []
    var productionStatus: MonthlyIssueProductionStatus = .planned
    var isRequired: Bool = true
    /// Tags subdivide the Page channel into letters, classes, fieldwork, and
    /// other native families without minting parallel delivery channels.
    var tags: [String] = []
    /// The original invitation can close while an accepted field return stays open.
    var missionReturn: MonthlyIssueMissionReturn? = nil
    /// An opened, unfinished node story may resume after its first-offer window.
    var storyContinuation: MonthlyIssueFollowUpWindow? = nil
    var concludesRun: Bool? = nil
    var survivesConclusion: Bool? = nil

    func isClosed(scope: AuthoredContentScope, ledger: AuthoredContentReceiptLedger, now: Date) -> Bool {
        placement.lifecycleStage == .live && survivesConclusion != true && ledger.satisfies(
            AuthoredContentReceiptQuery(contentID: "issue-conclusion", state: .concluded,
                scopeID: scope.scopeID, runID: scope.runID), now: now)
    }

    func resolvingMissionReturn(scope: AuthoredContentScope, ledger: AuthoredContentReceiptLedger, now: Date) -> Self {
        guard let missionReturn, ledger.satisfies(AuthoredContentReceiptQuery(contentID: id,
            state: .accepted, scopeID: scope.scopeID, runID: scope.runID), now: now) else { return self }
        var result = self
        result.placement = missionReturn.placement
        result.gate = missionReturn.gate
        result.interaction = .readerEvidence
        result.occurrence = AuthoredContentOccurrencePolicy(kind: .untilResolved)
        return result
    }

    func hasOpenStoryProgress(scope: AuthoredContentScope, ledger: AuthoredContentReceiptLedger, now: Date) -> Bool {
        guard storyContinuation != nil else { return false }
        let matching = ledger.receipts.filter {
            $0.contentID == id && $0.scope.scopeID == scope.scopeID && $0.scope.runID == scope.runID
                && $0.recordedAt <= now
        }
        return matching.contains { $0.state == .opened || $0.state == .nodeCompleted }
            && !matching.contains { $0.state == .kept || $0.state == .completed || $0.state == .dismissed }
    }

    func resolvingFollowUp(scope: AuthoredContentScope, ledger: AuthoredContentReceiptLedger, now: Date) -> Self {
        let mission = resolvingMissionReturn(scope: scope, ledger: ledger, now: now)
        guard let storyContinuation, hasOpenStoryProgress(scope: scope, ledger: ledger, now: now) else { return mission }
        var result = mission
        result.placement = storyContinuation.placement
        result.gate = storyContinuation.gate
        return result
    }
}

/// Every live phase names its opening atom and its direction packet. The
/// opening is reader-facing; the packet is backstage instruction shared by
/// story, class, visual, and connective-tissue systems.
struct MonthlyIssuePhasePlan: Codable, Identifiable, Equatable {
    var phaseID: String
    var role: WorldEventPhaseRole
    var openingContentID: String
    var directionPacketID: String
    var directionStatus: MonthlyIssueProductionStatus = .planned

    var id: String { phaseID }
}

/// A programmable row in the phase production matrix. Requirements are
/// opt-in: a medium may stay silent in a phase unless the issue declares a row
/// for it. `tagsAll` lets the Page channel count letters, classes, or fieldwork.
struct MonthlyIssueCoverageRequirement: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var channel: AuthoredContentChannel? = nil
    var lifecycleStage: WorldEventLifecycleStage? = nil
    var phaseRole: WorldEventPhaseRole? = nil
    var priorities: [MonthlyIssueContentPriority] = []
    var interactions: [MonthlyIssueInteractionKind] = []
    var tagsAll: [String] = []
    var minimumReady: Int
    var maximumReady: Int? = nil

    func matches(_ atom: MonthlyIssueContentAtom) -> Bool {
        guard atom.productionStatus.countsAsReady else { return false }
        if let channel, atom.channel != channel { return false }
        if let lifecycleStage, atom.placement.lifecycleStage != lifecycleStage { return false }
        if let phaseRole, atom.placement.phaseRole != phaseRole { return false }
        if !priorities.isEmpty, !priorities.contains(atom.priority) { return false }
        if !interactions.isEmpty, !interactions.contains(atom.interaction) { return false }
        let atomTags = Set(atom.tags.map(Self.normalize))
        if !tagsAll.allSatisfy({ atomTags.contains(Self.normalize($0)) }) { return false }
        return true
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct MonthlyIssueAuthoringManifest: Codable, Identifiable, Equatable {
    static let supportedSchemaVersion = 1

    var schemaVersion: Int = supportedSchemaVersion
    var id: String
    var issueNumber: Int
    var publicationKind: MonthlyIssuePublicationKind
    var title: String
    var eventPackID: String
    var eventID: String
    var phasePlans: [MonthlyIssuePhasePlan]
    var content: [MonthlyIssueContentAtom]
    var coverageRequirements: [MonthlyIssueCoverageRequirement]
    /// Ordinary Pages outside this issue may still unlock an atom. Declaring
    /// their IDs keeps that dependency intentional and auditable.
    var externalContentIDs: [String] = []

    var releaseContent: [MonthlyIssueContentAtom] {
        content.filter { $0.productionStatus.countsAsReady }
    }
}

// MARK: - Authoring validation

enum MonthlyIssueAuthoringValidationMode: String, Codable, Equatable {
    case working
    case release
}

enum MonthlyIssueAuthoringDiagnosticSeverity: String, Codable, Equatable {
    case warning
    case error
}

enum MonthlyIssueAuthoringDiagnosticCode: String, Codable, Equatable {
    case unsupportedSchema
    case invalidIssueIdentity
    case publicationNumberMismatch
    case packMismatch
    case missingEvent
    case eventMustBeOneShot
    case missingStartYear
    case lifecycleEnvelopeTooLong
    case duplicatePhaseID
    case missingPhaseRole
    case duplicatePhaseRole
    case phaseOrderInvalid
    case invalidPhaseProgress
    case invalidEventBeat
    case missingPhaseBeat
    case duplicatePhasePlan
    case missingPhasePlan
    case phasePlanOrderInvalid
    case phasePlanMismatch
    case missingPhaseOpening
    case invalidDirectionPacket
    case duplicateContentID
    case duplicateExternalContentID
    case duplicateNativeContentID
    case invalidContentReference
    case invalidContentPlacement
    case unsafeNonliveContent
    case unsafeAudienceVoice
    case incompleteRequiredContent
    case invalidOccurrence
    case invalidDependency
    case missingDependency
    case futureDependency
    case dependencyCycle
    case invalidGatePredicate
    case missingCoverageRequirements
    case duplicateCoverageRequirement
    case invalidCoverageRequirement
    case coverageBelowMinimum
    case coverageAboveMaximum
    case tooManyForeshadowHints
}

struct MonthlyIssueAuthoringDiagnostic: Codable, Identifiable, Equatable {
    var severity: MonthlyIssueAuthoringDiagnosticSeverity
    var code: MonthlyIssueAuthoringDiagnosticCode
    var subjectID: String?
    var message: String

    var id: String {
        "\(severity.rawValue):\(code.rawValue):\(subjectID ?? "issue"):\(message)"
    }
}

struct MonthlyIssueAuthoringValidationReport: Codable, Equatable {
    var diagnostics: [MonthlyIssueAuthoringDiagnostic]

    var errors: [MonthlyIssueAuthoringDiagnostic] {
        diagnostics.filter { $0.severity == .error }
    }

    var warnings: [MonthlyIssueAuthoringDiagnostic] {
        diagnostics.filter { $0.severity == .warning }
    }

    var isValid: Bool { errors.isEmpty }

    func contains(_ code: MonthlyIssueAuthoringDiagnosticCode) -> Bool {
        diagnostics.contains { $0.code == code }
    }
}

enum MonthlyIssueAuthoringValidator {
    static func validate(
        _ manifest: MonthlyIssueAuthoringManifest,
        against pack: WorldEventPack,
        mode: MonthlyIssueAuthoringValidationMode = .working
    ) -> MonthlyIssueAuthoringValidationReport {
        var diagnostics: [MonthlyIssueAuthoringDiagnostic] = []
        let completionSeverity: MonthlyIssueAuthoringDiagnosticSeverity = mode == .release ? .error : .warning

        func add(
            _ code: MonthlyIssueAuthoringDiagnosticCode,
            _ message: String,
            subjectID: String? = nil,
            severity: MonthlyIssueAuthoringDiagnosticSeverity = .error
        ) {
            diagnostics.append(MonthlyIssueAuthoringDiagnostic(
                severity: severity,
                code: code,
                subjectID: subjectID,
                message: message
            ))
        }

        guard manifest.schemaVersion == MonthlyIssueAuthoringManifest.supportedSchemaVersion else {
            add(.unsupportedSchema, "Unsupported authoring schema \(manifest.schemaVersion).")
            return report(diagnostics)
        }

        for scene in pack.storyScenes ?? [] {
            for message in AuthoredStoryProgress.diagnostics(for: scene) {
                add(.invalidContentReference, message, subjectID: scene.id)
            }
        }

        if isBlank(manifest.id) || isBlank(manifest.title)
            || isBlank(manifest.eventPackID) || isBlank(manifest.eventID) {
            add(.invalidIssueIdentity, "Issue, title, pack, and event IDs must all be present.")
        }
        switch manifest.publicationKind {
        case .rehearsal where manifest.issueNumber != 0:
            add(.publicationNumberMismatch, "A rehearsal must be Issue Zero.")
        case .publicIssue where manifest.issueNumber < 1:
            add(.publicationNumberMismatch, "A public issue number must be at least one.")
        default:
            break
        }
        guard pack.id == manifest.eventPackID else {
            add(.packMismatch, "Manifest names pack \(manifest.eventPackID), not \(pack.id).")
            return report(diagnostics)
        }
        guard let event = pack.events.first(where: { $0.id == manifest.eventID }) else {
            add(.missingEvent, "Pack \(pack.id) does not contain event \(manifest.eventID).")
            return report(diagnostics)
        }

        if event.calendar.recurrence != .oneShot {
            add(.eventMustBeOneShot, "A monthly issue must have one authored run, not annual replay.", subjectID: event.id)
        }
        if event.calendar.startYear == nil {
            add(.missingStartYear, "A monthly issue needs an explicit start year.", subjectID: event.id)
        }
        if event.calendar.resolvedForeshadowDays > 7 || event.calendar.resolvedResidueDays > 7 {
            add(.lifecycleEnvelopeTooLong, "Foreshadow and residue may each occupy at most seven days.", subjectID: event.id)
        }

        let phasesByID = validateEventPhases(event, add: add)
        validateEventBeats(event, manifest: manifest, pack: pack,
            phasesByID: phasesByID, completionSeverity: completionSeverity, add: add)

        var atomsByID: [String: MonthlyIssueContentAtom] = [:]
        for atom in manifest.content {
            if isBlank(atom.id) {
                add(.duplicateContentID, "A content atom has an empty ID.")
            } else if atomsByID[atom.id] != nil {
                add(.duplicateContentID, "Content ID \(atom.id) appears more than once.", subjectID: atom.id)
            } else {
                atomsByID[atom.id] = atom
            }
        }

        var externalIDs = Set<String>()
        for contentID in manifest.externalContentIDs {
            if isBlank(contentID) || !externalIDs.insert(contentID).inserted || atomsByID[contentID] != nil {
                add(.duplicateExternalContentID, "External content ID \(contentID) is empty, duplicated, or owned by this issue.", subjectID: contentID)
            }
        }

        validateNativeContentIDs(pack, add: add)

        for atom in manifest.content {
            validateContentAtom(
                atom,
                pack: pack,
                event: event,
                phasesByID: phasesByID,
                atomsByID: atomsByID,
                externalIDs: externalIDs,
                completionSeverity: completionSeverity,
                add: add
            )
        }

        validatePhasePlans(
            manifest.phasePlans,
            phasesByID: phasesByID,
            atomsByID: atomsByID,
            completionSeverity: completionSeverity,
            add: add
        )
        validateDependencies(
            manifest.content,
            atomsByID: atomsByID,
            externalIDs: externalIDs,
            add: add
        )
        for cycleID in dependencyCycleIDs(in: manifest.content) {
            add(.dependencyCycle, "Content dependencies contain a cycle through \(cycleID).", subjectID: cycleID)
        }

        validateCoverage(
            manifest.coverageRequirements,
            content: manifest.content,
            completionSeverity: completionSeverity,
            add: add
        )

        let foreshadowKeys = foreshadowHintKeys(event: event, content: manifest.releaseContent)
        if foreshadowKeys.count > 2 {
            add(
                .tooManyForeshadowHints,
                "Foreshadow contains \(foreshadowKeys.count) atoms; the limit is two.",
                severity: completionSeverity
            )
        }

        return report(diagnostics)
    }

    private static func validateNativeContentIDs(
        _ pack: WorldEventPack,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        func validate<Content: MonthlyIssueNativeContent>(_ contents: [Content], kind: String) {
            var ids = Set<String>()
            for content in contents where isBlank(content.id) || !ids.insert(content.id).inserted {
                add(
                    .duplicateNativeContentID,
                    "\(kind) ID \(content.id) is empty or duplicated.",
                    content.id,
                    .error
                )
            }
        }
        validate(pack.storyScenes ?? [], kind: "Story Scene")
        validate(pack.radioBanters ?? [], kind: "Radio banter")
        validate(pack.bleedArticles ?? [], kind: "Bleed article")
        validate(pack.marginalia ?? [], kind: "Marginalia")
    }

    private static func validateEventPhases(
        _ event: WorldEvent,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) -> [String: WorldEventPhase] {
        var phasesByID: [String: WorldEventPhase] = [:]
        var phasesByRole: [WorldEventPhaseRole: [WorldEventPhase]] = [:]
        for phase in event.phases {
            if isBlank(phase.id) || phasesByID[phase.id] != nil {
                add(.duplicatePhaseID, "Phase ID \(phase.id) is empty or duplicated.", phase.id, .error)
            } else {
                phasesByID[phase.id] = phase
            }
            guard let role = phase.role else {
                add(.missingPhaseRole, "Phase \(phase.id) has no universal role.", phase.id, .error)
                continue
            }
            phasesByRole[role, default: []].append(phase)
            if !phase.startsAtProgress.isFinite || !(0..<1).contains(phase.startsAtProgress) {
                add(.invalidPhaseProgress, "Phase \(phase.id) must begin within live progress 0..<1.", phase.id, .error)
            }
        }
        for role in WorldEventPhaseRole.allCases {
            let matches = phasesByRole[role] ?? []
            if matches.isEmpty {
                add(.missingPhaseRole, "The event has no \(role.rawValue) phase.", role.rawValue, .error)
            } else if matches.count > 1 {
                add(.duplicatePhaseRole, "The event has more than one \(role.rawValue) phase.", role.rawValue, .error)
            }
        }
        let ordered = event.phases.sorted { $0.startsAtProgress < $1.startsAtProgress }
        let roles = ordered.compactMap(\.role)
        if roles != WorldEventPhaseRole.allCases
            || ordered.first?.startsAtProgress != 0
            || zip(ordered, ordered.dropFirst()).contains(where: { $0.startsAtProgress >= $1.startsAtProgress }) {
            add(.phaseOrderInvalid, "Phases must advance once through Setup, Buildup, Climax, and Aftermath, beginning at zero.", event.id, .error)
        }
        return phasesByID
    }

    private static func validateEventBeats(
        _ event: WorldEvent,
        manifest: MonthlyIssueAuthoringManifest,
        pack: WorldEventPack,
        phasesByID: [String: WorldEventPhase],
        completionSeverity: MonthlyIssueAuthoringDiagnosticSeverity,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        var beatIDs = Set<String>()
        var liveRoles = Set<WorldEventPhaseRole>()
        for beat in event.beats ?? [] {
            let stage = beat.resolvedLifecycleStage
            let phase = phasesByID[beat.phaseID]
            let stageDays: Int
            switch stage {
            case .foreshadow: stageDays = event.calendar.resolvedForeshadowDays
            case .live: stageDays = event.calendar.durationDays
            case .residue: stageDays = event.calendar.resolvedResidueDays
            case .sealed, .casebookAvailable: stageDays = 0
            }
            let invalidWindow = stageDays <= 0
                || beat.opensOnDay < 0
                || beat.expiresAfterDay < beat.opensOnDay
                || beat.expiresAfterDay >= stageDays
            if isBlank(beat.id) || !beatIDs.insert(beat.id).inserted
                || isBlank(beat.title) || isBlank(beat.body) || isBlank(beat.report)
                || phase == nil || phase?.role != beat.role || invalidWindow {
                add(.invalidEventBeat, "Beat \(beat.id) has an invalid identity, report, phase, role, or lifecycle window.", beat.id, .error)
            }
            if stage == .live {
                liveRoles.insert(beat.role)
            } else if stage == .sealed || stage == .casebookAvailable
                || beat.isMilestone || beat.participationPrompt != nil || beat.participationPlaceholder != nil {
                add(.invalidEventBeat, "Non-live beat \(beat.id) may not be a milestone or accept participation.", beat.id, .error)
            }
            if beat.participationPrompt == nil, beat.participationPlaceholder != nil {
                add(.invalidEventBeat, "Beat \(beat.id) has a placeholder without a participation prompt.", beat.id, .error)
            }
        }
        // A ready native Story Page can open a phase. Requiring a second World
        // Event beat there would repeat the same narrative turn on another Page.
        let storyOpeningRoles = Set(manifest.phasePlans.compactMap { plan -> WorldEventPhaseRole? in
            guard phasesByID[plan.phaseID]?.role == plan.role,
                  let atom = manifest.content.first(where: { $0.id == plan.openingContentID }),
                  atom.productionStatus.countsAsReady,
                  atom.reference.kind == .storyScene, atom.channel == .storyScene,
                  atom.placement.lifecycleStage == .live,
                  atom.placement.phaseID == plan.phaseID, atom.placement.phaseRole == plan.role,
                  pack.storyScenes?.contains(where: {
                      $0.id == atom.reference.id && $0.packID == manifest.eventPackID && $0.eventID == manifest.eventID
                  }) == true else { return nil }
            return plan.role
        })
        for role in WorldEventPhaseRole.allCases where !liveRoles.contains(role) && !storyOpeningRoles.contains(role) {
            add(.missingPhaseBeat, "The \(role.rawValue) phase has no authored live beat.", role.rawValue, completionSeverity)
        }
    }

    private static func validateContentAtom(
        _ atom: MonthlyIssueContentAtom,
        pack: WorldEventPack,
        event: WorldEvent,
        phasesByID: [String: WorldEventPhase],
        atomsByID: [String: MonthlyIssueContentAtom],
        externalIDs: Set<String>,
        completionSeverity: MonthlyIssueAuthoringDiagnosticSeverity,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        if isBlank(atom.title) || isBlank(atom.reference.id) || !atom.reference.kind.supports(atom.channel) {
            add(.invalidContentReference, "Content \(atom.id) has no usable title/reference or its reference does not match its channel.", atom.id, .error)
        }
        if atom.reference.kind == .worldEventBeat {
            guard let beat = (event.beats ?? []).first(where: { $0.id == atom.reference.id }) else {
                add(.invalidContentReference, "Content \(atom.id) refers to missing event beat \(atom.reference.id).", atom.id, .error)
                return
            }
            if beat.resolvedLifecycleStage != atom.placement.lifecycleStage
                || (atom.placement.lifecycleStage == .live
                    && (beat.phaseID != atom.placement.phaseID || beat.role != atom.placement.phaseRole)) {
                add(.invalidContentPlacement, "Content \(atom.id) does not occupy the same lifecycle position as beat \(beat.id).", atom.id, .error)
            }
        }
        switch atom.reference.kind {
        case .storyScene:
            guard let scene = pack.storyScenes?.first(where: { $0.id == atom.reference.id }),
                  scene.packID == pack.id,
                  scene.eventID == event.id,
                  !isBlank(scene.title),
                  !isBlank(scene.opening),
                  !isBlank(scene.prompt) else {
                add(.invalidContentReference, "Content \(atom.id) refers to a missing or incomplete authored Story Scene.", atom.id, .error)
                break
            }
            if scene.nodes?.contains(where: { $0.carryForward != nil || $0.findingInsertion != nil }) == true && (pack.minimumRuntimeVersion ?? 1) < 5 {
                add(.invalidContentReference, "Cross-scene choices and finding insertions require runtime version 5.", atom.id, .error)
            }
            if scene.revisitsObservation == true && (atom.missionReturn == nil || (pack.minimumRuntimeVersion ?? 1) < 6) {
                add(.invalidContentReference, "Observation revisits need a mission return and runtime version 6.", atom.id, .error)
            }
            if scene.allowsFindingUse == true && (atom.missionReturn == nil || (pack.minimumRuntimeVersion ?? 1) < 4) {
                add(.invalidContentReference, "Finding permissions need a mission return and runtime version 4.", atom.id, .error)
            }
            if scene.missionKeptResponse != nil && (atom.missionReturn == nil || (pack.minimumRuntimeVersion ?? 1) < 3) {
                add(.invalidContentReference, "An authored finding response needs a mission return and runtime version 3.", atom.id, .error)
            }
            if scene.jump != nil && scene.nodes == nil {
                add(.invalidContentReference, "A supervised jump needs a complete node graph.", atom.id, .error)
            }
            if scene.jump?.allowsReaderAnchor == true && (pack.minimumRuntimeVersion ?? 1) < 3 {
                add(.invalidContentReference, "Reader-selected supervised anchors require runtime version 3.", atom.id, .error)
            }
            if scene.jump?.lastLiveDay != nil && (pack.minimumRuntimeVersion ?? 1) < 3 {
                add(.invalidContentReference, "A supervised visit deadline requires runtime version 3.", atom.id, .error)
            }
            if let lastDay = scene.jump?.lastLiveDay, !(0..<event.calendar.durationDays).contains(lastDay) {
                add(.invalidContentReference, "A supervised visit deadline must fall inside the live issue.", atom.id, .error)
            }
            if let reportDay = scene.reportAfterLiveDay, !(0..<event.calendar.durationDays).contains(reportDay) {
                add(.invalidContentReference, "Report deadlines use zero-based live-day indexes within the event.", atom.id, .error)
            }
            if scene.nodes != nil {
                if atom.occurrence.kind != .untilResolved || (pack.minimumRuntimeVersion ?? 1) < 2 {
                    add(.invalidOccurrence, "Node scenes need runtime 2 and untilResolved occurrence.", atom.id, .error)
                }
                if scene.jump != nil && scene.nodes?.contains(where: { $0.jumpAction == .return || $0.choices.contains(where: { $0.jumpAction == .return }) }) != true {
                    add(.invalidContentReference, "A supervised episode needs an authored return.", atom.id, .error)
                }
            }
            if atom.interaction == .choice, scene.nodes == nil,
               scene.choices.count < 2 || scene.choices.contains(where: {
                   isBlank($0.id) || isBlank($0.title) || isBlank($0.prompt) || isBlank($0.result)
               }) {
                add(.invalidContentReference, "Choice scene \(scene.id) needs at least two fully authored choices and results.", atom.id, .error)
            }
            if atom.missionReturn != nil {
                if scene.nodes != nil || !scene.choices.isEmpty {
                    add(.invalidContentReference, "An accepted crossing needs its own invitation/return atom, separate from a choice graph.", atom.id, .error)
                }
                if scene.missionReturnPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    add(.invalidContentReference, "A mission return needs an authored return prompt.", atom.id, .error)
                }
            }
            if atom.interaction == .fieldMission,
               scene.missionInvitation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                add(.invalidContentReference, "Field mission \(scene.id) needs an authored real-world invitation.", atom.id, .error)
            }
        case .radioBanter:
            guard let authored = pack.radioBanters?.first(where: { $0.id == atom.reference.id }),
                  authored.packID == pack.id,
                  authored.eventID == event.id,
                  authored.banter.id == authored.id,
                  !isBlank(authored.stationID),
                  !isBlank(authored.banter.caption) else {
                add(.invalidContentReference, "Content \(atom.id) refers to missing or incomplete authored Radio banter.", atom.id, .error)
                break
            }
        case .bleedArticle:
            guard let article = pack.bleedArticles?.first(where: { $0.id == atom.reference.id }),
                  article.packID == pack.id,
                  article.eventID == event.id,
                  !isBlank(article.title),
                  !isBlank(article.byline),
                  !isBlank(article.body),
                  !article.editionKinds.isEmpty else {
                add(.invalidContentReference, "Content \(atom.id) refers to a missing or incomplete authored Bleed article.", atom.id, .error)
                break
            }
        case .marginalia:
            guard let mark = pack.marginalia?.first(where: { $0.id == atom.reference.id }),
                  mark.packID == pack.id,
                  mark.eventID == event.id,
                  !isBlank(mark.assetPackID),
                  !isBlank(mark.assetID) else {
                add(.invalidContentReference, "Content \(atom.id) refers to missing or incomplete authored marginalia.", atom.id, .error)
                break
            }
        case .worldEventBeat, .pageArchetype:
            break
        }

        switch atom.placement.lifecycleStage {
        case .live:
            if atom.placement.phaseID == nil && atom.placement.phaseRole == nil {
                // A small ambient mark can straddle a phase change while one
                // stable once-per-run identity and its date gate remain intact.
                if atom.channel != .marginalia || atom.interaction != .none || atom.priority != .ambient
                    || (pack.minimumRuntimeVersion ?? 1) < 8 {
                    add(.invalidContentPlacement, "Only runtime 8 ambient marginalia may span live phases without a phase ID.", atom.id, .error)
                }
            } else {
                guard let phaseID = atom.placement.phaseID,
                      let role = atom.placement.phaseRole,
                      let phase = phasesByID[phaseID],
                      phase.role == role else {
                    add(.invalidContentPlacement, "Live content \(atom.id) needs a matching event phase ID and role.", atom.id, .error)
                    break
                }
            }
        case .foreshadow, .residue:
            if atom.placement.phaseID != nil || atom.placement.phaseRole != nil {
                add(.invalidContentPlacement, "Foreshadow and residue are not live phases and may not carry phase identity.", atom.id, .error)
            }
            if atom.interaction.acceptsParticipation || atom.priority == .spine || atom.priority == .milestone {
                add(.unsafeNonliveContent, "Non-live content \(atom.id) may not accept participation or claim spine/milestone pressure.", atom.id, .error)
            }
        case .sealed, .casebookAvailable:
            add(.invalidContentPlacement, "Sealed and casebook shelves do not deliver live authored atoms.", atom.id, .error)
        }

        if atom.interaction.acceptsParticipation, atom.audience == .nonparticipants {
            add(.unsafeAudienceVoice, "Nonparticipant-only content \(atom.id) cannot ask for participation.", atom.id, .error)
        }
        if atom.voice == .participantReceipt, atom.audience != .participants {
            add(.unsafeAudienceVoice, "A participant receipt must be restricted to receipted participants.", atom.id, .error)
        }
        if atom.voice == .nonparticipantRumor, atom.audience != .nonparticipants {
            add(.unsafeAudienceVoice, "A nonparticipant rumor must be restricted to nonparticipants.", atom.id, .error)
        }
        if atom.placement.lifecycleStage == .residue {
            let safe = (atom.audience == .participants && atom.voice == .participantReceipt)
                || (atom.audience == .nonparticipants && atom.voice == .nonparticipantRumor)
                || (atom.audience == .everyone && atom.voice == .publicReport)
            if !safe {
                add(.unsafeAudienceVoice, "Residue must be a participant receipt, a nonparticipant rumor, or a public third-person report.", atom.id, .error)
            }
        }

        if (atom.missionReturn != nil || atom.concludesRun != nil || atom.survivesConclusion != nil),
           (pack.minimumRuntimeVersion ?? 1) < 2 {
            add(.invalidOccurrence, "Mission returns and early conclusions require runtime 2.", atom.id, .error)
        }
        if atom.isRequired && !atom.productionStatus.countsAsReady {
            add(
                .incompleteRequiredContent,
                "Required content \(atom.id) is \(atom.productionStatus.rawValue), not ready or reusable.",
                atom.id,
                completionSeverity
            )
        }
        if let missionReturn = atom.missionReturn {
            let placement = missionReturn.placement
            if placement.lifecycleStage != .live || (placement.phaseID == nil) != (placement.phaseRole == nil)
                || placement.phaseID.map({ phasesByID[$0]?.role != placement.phaseRole }) == true {
                add(.invalidContentPlacement, "Mission returns need a live window and, if named, a matching phase and role.", atom.id, .error)
            }
            validateGate(missionReturn.gate, subjectID: atom.id,
                knownContentIDs: Set(atomsByID.keys).union(externalIDs), event: event, add: add)
        }
        if let continuation = atom.storyContinuation {
            let scene = pack.storyScenes?.first {
                $0.id == atom.reference.id && $0.packID == pack.id && $0.eventID == event.id
            }
            if atom.reference.kind != .storyScene || atom.channel != .storyScene
                || atom.interaction != .choice || atom.occurrence.kind != .untilResolved
                || atom.missionReturn != nil || scene?.nodes?.isEmpty != false
                || (pack.minimumRuntimeVersion ?? 1) < 7 {
                add(.invalidOccurrence, "Story continuation needs a node-choice scene, untilResolved occurrence, and runtime 7.", atom.id, .error)
            }
            let placement = continuation.placement
            if placement.lifecycleStage != .live || (placement.phaseID == nil) != (placement.phaseRole == nil)
                || placement.phaseID.map({ phasesByID[$0]?.role != placement.phaseRole }) == true {
                add(.invalidContentPlacement, "Story continuation needs a live window and a matching phase when named.", atom.id, .error)
            }
            validateGate(continuation.gate, subjectID: atom.id,
                knownContentIDs: Set(atomsByID.keys).union(externalIDs), event: event, add: add)
        }
        validateOccurrence(atom, add: add)
        validateGate(
            atom.gate,
            subjectID: atom.id,
            knownContentIDs: Set(atomsByID.values
                .filter { $0.productionStatus != .cut }
                .map(\.id))
                .union(externalIDs),
            event: event,
            add: add
        )
    }

    private static func validateOccurrence(
        _ atom: MonthlyIssueContentAtom,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        let policy = atom.occurrence
        if atom.id == "issue-conclusion" {
            add(.invalidOccurrence, "issue-conclusion is reserved for the runtime's end-of-run receipt.", atom.id, .error)
        }
        if atom.missionReturn != nil && (atom.interaction != .fieldMission || policy.kind != .untilResolved) {
            add(.invalidOccurrence, "A mission return needs a field invitation with untilResolved occurrence.", atom.id, .error)
        }
        if let cooldown = policy.cooldownHours, cooldown <= 0 {
            add(.invalidOccurrence, "Cooldown for \(atom.id) must be positive.", atom.id, .error)
        }
        if let maximum = policy.maxPerRun, maximum <= 0 {
            add(.invalidOccurrence, "Maximum occurrences for \(atom.id) must be positive.", atom.id, .error)
        }
        switch policy.kind {
        case .repeatable:
            if policy.cooldownHours == nil && policy.maxPerRun == nil {
                add(.invalidOccurrence, "Repeatable content \(atom.id) needs a cooldown or per-run ceiling.", atom.id, .error)
            }
        case .oncePerPhase:
            if atom.placement.lifecycleStage != .live || atom.placement.phaseID == nil {
                add(.invalidOccurrence, "Once-per-phase content \(atom.id) must occupy a live phase.", atom.id, .error)
            }
            if policy.cooldownHours != nil || policy.maxPerRun != nil {
                add(.invalidOccurrence, "Once-per-phase content \(atom.id) may not also carry repeat controls.", atom.id, .error)
            }
        case .untilActed:
            if !atom.interaction.acceptsParticipation {
                add(.invalidOccurrence, "Until-acted content \(atom.id) must offer an action.", atom.id, .error)
            }
            if policy.cooldownHours != nil || policy.maxPerRun != nil {
                add(.invalidOccurrence, "Until-acted content \(atom.id) may not also carry repeat controls.", atom.id, .error)
            }
        case .onceEver, .oncePerRun, .untilOpened, .untilResolved:
            if policy.cooldownHours != nil || policy.maxPerRun != nil {
                add(.invalidOccurrence, "Non-repeatable content \(atom.id) may not carry repeat controls.", atom.id, .error)
            }
        }
    }

    private static func validatePhasePlans(
        _ plans: [MonthlyIssuePhasePlan],
        phasesByID: [String: WorldEventPhase],
        atomsByID: [String: MonthlyIssueContentAtom],
        completionSeverity: MonthlyIssueAuthoringDiagnosticSeverity,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        var planIDs = Set<String>()
        var planRoles = Set<WorldEventPhaseRole>()
        for plan in plans {
            if isBlank(plan.phaseID) || !planIDs.insert(plan.phaseID).inserted || !planRoles.insert(plan.role).inserted {
                add(.duplicatePhasePlan, "Phase plan \(plan.phaseID) duplicates a phase ID or role.", plan.phaseID, .error)
            }
            if phasesByID[plan.phaseID]?.role != plan.role {
                add(.phasePlanMismatch, "Phase plan \(plan.phaseID) does not match its event phase role.", plan.phaseID, .error)
            }
            guard let opening = atomsByID[plan.openingContentID], opening.productionStatus != .cut else {
                add(.missingPhaseOpening, "Phase \(plan.phaseID) has no usable opening atom.", plan.phaseID, .error)
                continue
            }
            if opening.placement.lifecycleStage != .live
                || opening.placement.phaseID != plan.phaseID
                || opening.placement.phaseRole != plan.role
                || !(opening.priority == .spine || opening.priority == .milestone) {
                add(.missingPhaseOpening, "Opening \(opening.id) is not spine/milestone content in phase \(plan.phaseID).", plan.phaseID, .error)
            }
            if !opening.productionStatus.countsAsReady {
                add(.missingPhaseOpening, "Opening \(opening.id) is not ready for release.", opening.id, completionSeverity)
            }
            if isBlank(plan.directionPacketID) || !plan.directionStatus.countsAsReady {
                add(.invalidDirectionPacket, "Phase \(plan.phaseID) needs one ready direction packet.", plan.phaseID, completionSeverity)
            }
        }
        for role in WorldEventPhaseRole.allCases where !planRoles.contains(role) {
            add(.missingPhasePlan, "The manifest has no \(role.rawValue) phase plan.", role.rawValue, .error)
        }
        if plans.map(\.role) != WorldEventPhaseRole.allCases {
            add(.phasePlanOrderInvalid, "Phase plans must be written in Setup, Buildup, Climax, Aftermath order.", nil, .error)
        }
    }

    private static func validateDependencies(
        _ content: [MonthlyIssueContentAtom],
        atomsByID: [String: MonthlyIssueContentAtom],
        externalIDs: Set<String>,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        for atom in content where atom.productionStatus != .cut {
            for dependency in atom.dependencies {
                if isBlank(dependency.contentID) || dependency.contentID == atom.id
                    || dependency.minimumOccurrences <= 0
                    || (dependency.withinHours.map { $0 <= 0 } ?? false) {
                    add(.invalidDependency, "Content \(atom.id) has an invalid or self-referential dependency.", atom.id, .error)
                    continue
                }
                guard let target = atomsByID[dependency.contentID] else {
                    if !externalIDs.contains(dependency.contentID) {
                        add(.missingDependency, "Content \(atom.id) depends on undeclared \(dependency.contentID).", atom.id, .error)
                    }
                    continue
                }
                if target.productionStatus == .cut {
                    add(.missingDependency, "Content \(atom.id) depends on cut content \(target.id).", atom.id, .error)
                }
                if target.placement.chronologicalRank > atom.placement.chronologicalRank {
                    add(.futureDependency, "Content \(atom.id) depends on later content \(target.id).", atom.id, .error)
                }
                if dependency.requiredState == .played, target.channel != .radioBanter {
                    add(.invalidDependency, "Only Radio content can satisfy a played receipt.", atom.id, .error)
                }
                if (dependency.requiredState == .acted || dependency.requiredState == .completed)
                    && !target.interaction.acceptsParticipation {
                    add(.invalidDependency, "Content \(target.id) cannot satisfy an action receipt.", atom.id, .error)
                }
            }
        }
    }

    private static func dependencyCycleIDs(
        in content: [MonthlyIssueContentAtom]
    ) -> [String] {
        let activeIDs = Set(content.filter { $0.productionStatus != .cut }.map(\.id))
        let edges = Dictionary(uniqueKeysWithValues: content.compactMap { atom -> (String, [String])? in
            guard activeIDs.contains(atom.id) else { return nil }
            return (atom.id, atom.dependencies.map(\.contentID).filter(activeIDs.contains))
        })
        var state: [String: Int] = [:]
        var stack: [String] = []
        var cycleIDs = Set<String>()

        func visit(_ id: String) {
            if state[id] == 2 { return }
            if state[id] == 1 {
                if let index = stack.firstIndex(of: id) {
                    cycleIDs.formUnion(stack[index...])
                } else {
                    cycleIDs.insert(id)
                }
                return
            }
            state[id] = 1
            stack.append(id)
            for dependencyID in edges[id] ?? [] {
                visit(dependencyID)
            }
            _ = stack.popLast()
            state[id] = 2
        }
        for id in activeIDs.sorted() { visit(id) }
        return cycleIDs.sorted()
    }

    private static func validateGate(
        _ gate: AuthoredContentGate,
        subjectID: String,
        knownContentIDs: Set<String>,
        event: WorldEvent,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        for predicate in gate.allOf + gate.anyOf + gate.noneOf {
            let invalid: Bool
            switch predicate {
            case .timeBands(let values), .moonPhases(let values), .weatherTagsAny(let values):
                invalid = values.isEmpty || values.contains(where: isBlank)
            case .months(let values):
                invalid = values.isEmpty || values.contains { !(1...12).contains($0) }
            case .weekdays(let values):
                invalid = values.isEmpty || values.contains { !(1...7).contains($0) }
            case .weeksOfYear(let values):
                invalid = values.isEmpty || values.contains { !(1...53).contains($0) }
            case .dateWindow(let startsAt, let endsAt):
                invalid = startsAt == nil && endsAt == nil
                    || (startsAt != nil && endsAt != nil && startsAt! >= endsAt!)
            case .worldEvent(let query):
                let currentEventIsNamed = query.eventIDs.isEmpty
                    || query.eventIDs.contains { normalize($0) == normalize(event.id) }
                let foreignPhase = currentEventIsNamed && query.phaseIDs.contains { phaseID in
                    !event.phases.contains { normalize($0.id) == normalize(phaseID) || normalize($0.title) == normalize(phaseID) }
                }
                invalid = foreignPhase
                    || (query.minimumTouches.map { $0 < 0 } ?? false)
                    || (query.minimumLiveDay.map { $0 < 0 } ?? false)
                    || (query.maximumLiveDay.map { $0 < 0 } ?? false)
                    || (query.minimumLiveDay != nil && query.maximumLiveDay != nil
                        && query.minimumLiveDay! > query.maximumLiveDay!)
            case .receipt(let query):
                invalid = isBlank(query.contentID)
                    || !knownContentIDs.contains(query.contentID)
                    || query.minimumOccurrences <= 0
                    || (query.withinHours.map { $0 <= 0 } ?? false)
            case .standingBand(_, let bands):
                invalid = bands.isEmpty
            case .rarity(let probability):
                invalid = !probability.isFinite || !(0...1).contains(probability)
            case .legacyPageTrigger, .legacyRadioConditions:
                invalid = false
            }
            if invalid {
                add(.invalidGatePredicate, "Content \(subjectID) contains an empty, impossible, or undeclared gate predicate.", subjectID, .error)
            }
        }
    }

    private static func validateCoverage(
        _ requirements: [MonthlyIssueCoverageRequirement],
        content: [MonthlyIssueContentAtom],
        completionSeverity: MonthlyIssueAuthoringDiagnosticSeverity,
        add: (
            MonthlyIssueAuthoringDiagnosticCode,
            String,
            String?,
            MonthlyIssueAuthoringDiagnosticSeverity
        ) -> Void
    ) {
        if requirements.isEmpty {
            add(.missingCoverageRequirements, "The issue has no production-count requirements.", nil, .error)
            return
        }
        var ids = Set<String>()
        for requirement in requirements {
            if isBlank(requirement.id) || !ids.insert(requirement.id).inserted {
                add(.duplicateCoverageRequirement, "Coverage requirement \(requirement.id) is empty or duplicated.", requirement.id, .error)
                continue
            }
            if isBlank(requirement.label) || requirement.minimumReady < 0
                || (requirement.maximumReady.map { $0 < requirement.minimumReady } ?? false)
                || (requirement.lifecycleStage != nil
                    && requirement.lifecycleStage != .live
                    && requirement.phaseRole != nil)
                || requirement.tagsAll.contains(where: isBlank) {
                add(.invalidCoverageRequirement, "Coverage requirement \(requirement.id) has an invalid label, count, or selector.", requirement.id, .error)
                continue
            }
            let count = content.filter(requirement.matches).count
            if count < requirement.minimumReady {
                add(
                    .coverageBelowMinimum,
                    "\(requirement.label) has \(count) ready; it needs at least \(requirement.minimumReady).",
                    requirement.id,
                    completionSeverity
                )
            }
            if let maximum = requirement.maximumReady, count > maximum {
                add(
                    .coverageAboveMaximum,
                    "\(requirement.label) has \(count) ready; its production ceiling is \(maximum).",
                    requirement.id,
                    completionSeverity
                )
            }
        }
    }

    private static func foreshadowHintKeys(
        event: WorldEvent,
        content: [MonthlyIssueContentAtom]
    ) -> Set<String> {
        var keys = Set((event.beats ?? [])
            .filter { $0.resolvedLifecycleStage == .foreshadow }
            .map { "beat:\($0.id)" })
        for atom in content where atom.placement.lifecycleStage == .foreshadow {
            let key = atom.reference.kind == .worldEventBeat
                ? "beat:\(atom.reference.id)"
                : "content:\(atom.id)"
            keys.insert(key)
        }
        return keys
    }

    private static func report(
        _ diagnostics: [MonthlyIssueAuthoringDiagnostic]
    ) -> MonthlyIssueAuthoringValidationReport {
        MonthlyIssueAuthoringValidationReport(diagnostics: diagnostics.sorted { left, right in
            if left.severity != right.severity { return left.severity.rawValue < right.severity.rawValue }
            if left.code != right.code { return left.code.rawValue < right.code.rawValue }
            return (left.subjectID ?? "") < (right.subjectID ?? "")
        })
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Page curation contract

/// Stable metadata shared by native Page adapters, the Curator, and delivery
/// receipts. Monthly content remains a native Page; these fields only explain
/// why this particular Page belongs to this particular issue occurrence.
enum MonthlyIssuePageMetadata {
    static let issueID = "authoredIssueID"
    static let issueNumber = "authoredIssueNumber"
    static let eventID = "authoredIssueEventID"
    static let contentID = "authoredContentID"
    static let channel = "authoredContentChannel"
    static let priority = "authoredIssuePriority"
    static let lifecycleStage = "authoredIssueLifecycleStage"
    static let scopeID = "authoredContentScopeID"
    static let runID = "authoredContentRunID"
    static let phaseID = "authoredContentPhaseID"
    static let occurrenceID = "authoredContentOccurrenceID"
    static let referenceKind = "authoredContentReferenceKind"
    static let referenceID = "authoredContentReferenceID"
    static let interaction = "authoredContentInteraction"
    static let narrativeVoice = "authoredContentNarrativeVoice"
    static let authoredStoryScene = "authoredStoryScene"
    static let mayReserve = "authoredIssueMayReserve"
    static let claimHistoryKey = "authoredIssueClaimHistoryKey"

    static func dailyClaimHistoryKey(issueID: String, dayID: String) -> String {
        "authored-issue-claim:\(issueID):\(dayID)"
    }
}

/// Resolves issue authoring data onto ordinary Page candidates before ranking.
/// A referenced Page that is not ready, is in the wrong lifecycle position, or
/// has not earned its dependencies is withheld rather than leaking around the
/// manifest through its native adapter.
enum MonthlyIssuePageCuration {
    private struct Match {
        var manifest: MonthlyIssueAuthoringManifest
        var atom: MonthlyIssueContentAtom
        var snapshot: WorldEventLifecycleSnapshot
    }

    static func preparing(
        _ pages: [SurfacePage],
        manifests: [MonthlyIssueAuthoringManifest],
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        lifecycleOverride: [WorldEventLifecycleSnapshot]? = nil
    ) -> [SurfacePage] {
        guard !manifests.isEmpty else { return pages.filter { !isIssueOffer($0) } }
        let lifecycle = lifecycleOverride ?? WorldEventResolver.lifecycleEvents(
            now: now,
            ledger: inputs.worldEventLifecycle
        )
        let pageContext = PageTriggerContext(day: day, inputs: inputs, now: now, resolveMissingWorldEvents: lifecycleOverride == nil)
        let prepared = pages.compactMap {
            preparing(
                $0,
                manifests: manifests,
                day: day,
                inputs: inputs,
                now: now,
                lifecycle: lifecycle,
                pageContext: pageContext
            )
        }
        return fairlyOffering(prepared, ledger: inputs.authoredContentReceipts)
    }

    /// Rotate eligible offers at the curation boundary, never by writing a
    /// dismissal or completion. Published desks still keep their existing pages.
    static func fairlyOffering(_ pages: [SurfacePage], ledger: AuthoredContentReceiptLedger) -> [SurfacePage] {
        struct OfferKey: Hashable { var issue: String?; var run: String?; var content: String? }
        var lastOpenedByKey: [OfferKey: Date] = [:]
        for receipt in ledger.receipts where receipt.state == .opened {
            let key = OfferKey(issue: receipt.scope.scopeID, run: receipt.scope.runID, content: receipt.contentID)
            lastOpenedByKey[key] = max(lastOpenedByKey[key] ?? .distantPast, receipt.recordedAt)
        }
        let groups = Dictionary(grouping: pages.indices.filter { pages[$0].belongsToAuthoredIssue }) {
            (pages[$0].payload.metadata[MonthlyIssuePageMetadata.issueID] ?? "") + "|"
                + (pages[$0].payload.metadata[MonthlyIssuePageMetadata.runID] ?? "")
        }
        var result = pages
        for indices in groups.values where indices.count > 1 {
            func lastOpened(_ index: Int) -> Date {
                let m = pages[index].payload.metadata
                return lastOpenedByKey[OfferKey(issue: m[MonthlyIssuePageMetadata.issueID],
                    run: m[MonthlyIssuePageMetadata.runID], content: m[MonthlyIssuePageMetadata.contentID])] ?? .distantPast
            }
            guard let next = indices.min(by: {
                let a = lastOpened($0), b = lastOpened($1)
                if a != b { return a < b }
                return pages[$0].score == pages[$1].score ? pages[$0].id < pages[$1].id : pages[$0].score > pages[$1].score
            }), indices.contains(where: { lastOpened($0) > lastOpened(next) }) else { continue }
            let page = pages[next]
            var metadata = page.payload.metadata
            metadata["authoredFairOffer"] = "true"
            if let claimKey = indices.compactMap({ pages[$0].payload.metadata[MonthlyIssuePageMetadata.claimHistoryKey] }).first {
                metadata[MonthlyIssuePageMetadata.mayReserve] = "true"
                metadata[MonthlyIssuePageMetadata.claimHistoryKey] = claimKey
            }
            result[next] = SurfacePage(id: page.id, type: page.type, sourceID: page.sourceID,
                intent: page.intent, renderStyle: page.renderStyle,
                score: (indices.map { pages[$0].score }.max() ?? page.score) + 1,
                reason: page.reason, prompt: page.prompt, detail: page.detail,
                payload: BookPagePayload(headline: page.payload.headline, body: page.payload.body, metadata: metadata))
        }
        return result
    }

    static func preparing(
        _ page: SurfacePage,
        manifests: [MonthlyIssueAuthoringManifest],
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        guard !manifests.isEmpty else { return isIssueOffer(page) ? nil : page }
        let lifecycle = WorldEventResolver.lifecycleEvents(
            now: now,
            ledger: inputs.worldEventLifecycle
        )
        let pageContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        return preparing(
            page,
            manifests: manifests,
            day: day,
            inputs: inputs,
            now: now,
            lifecycle: lifecycle,
            pageContext: pageContext
        )
    }

    private static func preparing(
        _ page: SurfacePage,
        manifests: [MonthlyIssueAuthoringManifest],
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        lifecycle: [WorldEventLifecycleSnapshot],
        pageContext: PageTriggerContext
    ) -> SurfacePage? {
        let referenced = manifests.flatMap { manifest in
            manifest.content.compactMap { atom in
                referenceMatches(atom.reference, manifest: manifest, page: page)
                    ? (manifest, atom)
                    : nil
            }
        }
        guard !referenced.isEmpty else { return isIssueOffer(page) ? nil : page }

        let isReport = page.payload.metadata["worldEventDeliveryKind"]
            == WorldEventBeatDeliveryKind.report.rawValue
        let eligible: [Match] = referenced.compactMap { manifest, original in
            guard let current = lifecycle.first(where: { $0.packID == manifest.eventPackID && $0.eventID == manifest.eventID }) else { return nil }
            let atom = original.resolvingFollowUp(scope: AuthoredContentScope(scopeID: manifest.id, runID: current.runID),
                ledger: inputs.authoredContentReceipts, now: now)
            guard atom.productionStatus.countsAsReady,
                  atom.channel == .page || atom.channel == .storyScene,
                  let snapshot = lifecycle.first(where: {
                      $0.packID == manifest.eventPackID && $0.eventID == manifest.eventID
                  }),
                  placement(atom.placement, matches: snapshot),
                  audience(atom.audience, matchesParticipation: snapshot.participated)
            else { return nil }

            let scope = AuthoredContentScope(
                scopeID: manifest.id,
                runID: snapshot.runID,
                phaseID: snapshot.phaseID
            )
            let gateContext = AuthoredContentGateContext.page(
                pageContext,
                lifecycle: lifecycle,
                receiptLedger: inputs.authoredContentReceipts,
                contentScope: scope
            )
            guard !atom.isClosed(scope: scope, ledger: inputs.authoredContentReceipts, now: now),
                  atom.gate.allows(in: gateContext, contentID: atom.id),
                  atom.occurrence.allows(
                      contentID: atom.id,
                      scope: scope,
                      ledger: inputs.authoredContentReceipts,
                      now: now
                  ),
                  atom.dependencies.allSatisfy({ dependency in
                      dependency.isSatisfied(
                          in: inputs.authoredContentReceipts,
                          currentScope: scope,
                          now: now
                      ) || (dependency.failurePolicy == .reportThenContinue && isReport)
                        || MonthlyIssueCatchUp.report(for: dependency, manifest: manifest, scenes: inputs.authoredStoryScenes,
                            snapshot: snapshot, ledger: inputs.authoredContentReceipts, now: now) != nil
                  })
            else { return nil }
            return Match(manifest: manifest, atom: atom, snapshot: snapshot)
        }
        guard let selected = eligible.sorted(by: preferred).first else {
            return nil
        }
        let prepared = applying(selected, to: page, day: day)
        return MonthlyIssueCatchUp.preparing(prepared, atom: selected.atom, manifest: selected.manifest,
            inputs: inputs, scope: AuthoredContentScope(scopeID: selected.manifest.id, runID: selected.snapshot.runID,
                phaseID: selected.snapshot.phaseID), snapshot: selected.snapshot, now: now)
    }

    /// Only transient candidates pass here. Kept BookPages live in the archive
    /// and are not withdrawn when an issue expires or access ends.
    private static func isIssueOffer(_ page: SurfacePage) -> Bool {
        page.payload.metadata[MonthlyIssuePageMetadata.issueID] != nil
            || page.payload.metadata[MonthlyIssuePageMetadata.authoredStoryScene] == "true"
    }

    private static func preferred(_ left: Match, _ right: Match) -> Bool {
        if left.atom.priority.curatorRank != right.atom.priority.curatorRank {
            return left.atom.priority.curatorRank > right.atom.priority.curatorRank
        }
        if left.manifest.issueNumber != right.manifest.issueNumber {
            return left.manifest.issueNumber > right.manifest.issueNumber
        }
        return left.atom.id < right.atom.id
    }

    private static func applying(_ match: Match, to page: SurfacePage, day: BookDay) -> SurfacePage {
        let atom = match.atom
        let manifest = match.manifest
        let snapshot = match.snapshot
        let mayReserve = snapshot.stage == .live
            && (atom.priority == .spine || atom.priority == .milestone)
        var metadata = page.payload.metadata
        metadata[MonthlyIssuePageMetadata.issueID] = manifest.id
        metadata[MonthlyIssuePageMetadata.issueNumber] = "\(manifest.issueNumber)"
        metadata[MonthlyIssuePageMetadata.eventID] = manifest.eventID
        metadata[MonthlyIssuePageMetadata.contentID] = atom.id
        metadata[MonthlyIssuePageMetadata.channel] = atom.channel.rawValue
        metadata[MonthlyIssuePageMetadata.priority] = atom.priority.rawValue
        metadata[MonthlyIssuePageMetadata.lifecycleStage] = snapshot.stage.rawValue
        metadata[MonthlyIssuePageMetadata.scopeID] = manifest.id
        metadata[MonthlyIssuePageMetadata.runID] = snapshot.runID
        metadata[MonthlyIssuePageMetadata.phaseID] = snapshot.phaseID
        let isMissionReturn = atom.missionReturn != nil && atom.interaction == .readerEvidence
        let pageID = page.id + (isMissionReturn ? "-return" : "")
        metadata[MonthlyIssuePageMetadata.occurrenceID] = pageID
        metadata[MonthlyIssuePageMetadata.referenceKind] = atom.reference.kind.rawValue
        metadata[MonthlyIssuePageMetadata.referenceID] = atom.reference.id
        let missionOffer = atom.missionReturn != nil && atom.interaction == .fieldMission
        metadata["authoredMissionOffer"] = missionOffer ? "true" : "false"
        metadata["authoredConcludesRun"] = atom.concludesRun == true ? "true" : "false"
        if isMissionReturn {
            metadata["storyScene"] = metadata["livedMissionReturnPrompt"] ?? page.payload.body
            metadata[AuthoredStoryScenePageAdapter.choicesMetadataKey] = "[]"
        }
        let nodeWithoutChoices = metadata["authoredStoryNodeID"] != nil && metadata[AuthoredStoryScenePageAdapter.choicesMetadataKey] == "[]"
        metadata[MonthlyIssuePageMetadata.interaction] = missionOffer || nodeWithoutChoices ? MonthlyIssueInteractionKind.none.rawValue : atom.interaction.rawValue
        metadata[MonthlyIssuePageMetadata.narrativeVoice] = atom.voice.rawValue
        if mayReserve {
            metadata[MonthlyIssuePageMetadata.mayReserve] = "true"
            metadata[MonthlyIssuePageMetadata.claimHistoryKey] =
                MonthlyIssuePageMetadata.dailyClaimHistoryKey(
                    issueID: manifest.id,
                    dayID: day.id
                )
        }
        let prepared = SurfacePage(
            id: pageID,
            type: page.type,
            sourceID: page.sourceID,
            intent: page.intent,
            renderStyle: page.renderStyle,
            score: page.score + atom.priority.curatorScoreLift,
            reason: page.reason,
            prompt: atom.missionReturn != nil && !missionOffer ? (metadata["livedMissionReturnPrompt"] ?? page.prompt) : page.prompt,
            detail: page.detail,
            payload: BookPagePayload(
                headline: page.payload.headline,
                body: atom.missionReturn != nil && !missionOffer ? (metadata["livedMissionReturnPrompt"] ?? page.payload.body) : page.payload.body,
                metadata: metadata
            )
        )
        if atom.channel == .storyScene {
            return prepared.withPageCapabilities(
                AuthoredStoryScenePageAdapter.capabilities(for: atom.interaction)
            )
        }
        return prepared
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

    private static func referenceMatches(
        _ reference: MonthlyIssueContentReference,
        manifest: MonthlyIssueAuthoringManifest,
        page: SurfacePage
    ) -> Bool {
        let metadata = page.payload.metadata
        if metadata[MonthlyIssuePageMetadata.referenceKind] == reference.kind.rawValue,
           metadata[MonthlyIssuePageMetadata.referenceID] == reference.id {
            if reference.kind == .storyScene {
                return metadata["worldEventPackID"] == manifest.eventPackID
                    && metadata["worldEventIDs"] == manifest.eventID
            }
            return true
        }
        switch reference.kind {
        case .worldEventBeat:
            let eventIDs = commaSeparated(metadata["worldEventIDs"])
            let beatIDs = commaSeparated(metadata["worldEventBeatIDs"])
            return eventIDs.contains(manifest.eventID) && beatIDs.contains(reference.id)
        case .pageArchetype:
            return metadata["packArchetypeID"] == reference.id
        case .storyScene:
            return metadata["worldEventPackID"] == manifest.eventPackID
                && metadata["worldEventIDs"] == manifest.eventID
                && (metadata["storySceneID"] == reference.id
                    || metadata["authoredStorySceneID"] == reference.id
                )
        case .marginalia, .radioBanter, .bleedArticle:
            return false
        }
    }

    private static func commaSeparated(_ raw: String?) -> Set<String> {
        Set((raw ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
    }
}

extension SurfacePage {
    var authoredIssuePriority: MonthlyIssueContentPriority? {
        payload.metadata[MonthlyIssuePageMetadata.priority]
            .flatMap(MonthlyIssueContentPriority.init(rawValue:))
    }

    var belongsToAuthoredIssue: Bool {
        payload.metadata[MonthlyIssuePageMetadata.issueID]?.nonEmpty != nil
    }

    var mayReserveAuthoredIssueSlot: Bool {
        payload.metadata[MonthlyIssuePageMetadata.mayReserve] == "true"
    }

    func authoredContentDeliveryReceipt(servedAt: Date) -> AuthoredContentReceipt? {
        authoredContentReceipts(state: .delivered, at: servedAt).first
    }
}
