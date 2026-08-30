import Foundation

// MARK: - Shared authored-content orchestration vocabulary

/// The native instrument that delivered an authored atom. Letters, classes,
/// notices, and fieldwork are all Pages; the distinction belongs in their
/// content tags rather than in a parallel delivery system.
enum AuthoredContentChannel: String, Codable, Equatable, CaseIterable {
    case page
    case storyScene
    case marginalia
    case radioBanter
    case bleedArticle
}

/// What actually happened to one authored atom. Delivery is deliberately
/// separate from participation: putting a Page in the folio, playing a radio
/// break, and receiving a reader choice are different receipts.
enum AuthoredContentReceiptState: String, Codable, Equatable, CaseIterable {
    case delivered
    case opened
    case played
    case acted
    case kept
    case completed
    case dismissed

    fileprivate var isDeliveryEvent: Bool {
        self == .delivered || self == .played
    }

    fileprivate func satisfies(_ required: Self) -> Bool {
        switch required {
        case .delivered:
            return true
        case .opened:
            return self == .opened || self == .acted || self == .kept || self == .completed
        case .played:
            return self == .played
        case .acted:
            return self == .acted || self == .kept || self == .completed
        case .kept:
            return self == .kept
        case .completed:
            return self == .completed
        case .dismissed:
            return self == .dismissed
        }
    }
}

/// The authored shelf on which a receipt belongs. `scopeID` is normally an
/// issue or event ID; `runID` distinguishes occurrences; `phaseID` permits a
/// repeatable atom to be once-per-phase without pretending phases are issues.
struct AuthoredContentScope: Codable, Equatable {
    var scopeID: String? = nil
    var runID: String? = nil
    var phaseID: String? = nil

    static let unscoped = AuthoredContentScope()
}

/// One immutable observation about delivery or engagement. `occurrenceID`
/// comes from the native surface (desk slot, playout item, edition insert,
/// and so on), making repeated reconciliation idempotent without collapsing
/// two legitimate deliveries of repeatable content.
struct AuthoredContentReceipt: Codable, Identifiable, Equatable {
    var id: String
    var contentID: String
    var occurrenceID: String
    var channel: AuthoredContentChannel
    var scope: AuthoredContentScope
    var state: AuthoredContentReceiptState
    var recordedAt: Date
    var choiceID: String? = nil
    var evidencePageIDs: [String] = []

    init(
        contentID: String,
        occurrenceID: String,
        channel: AuthoredContentChannel,
        scope: AuthoredContentScope = .unscoped,
        state: AuthoredContentReceiptState,
        recordedAt: Date,
        choiceID: String? = nil,
        evidencePageIDs: [String] = []
    ) {
        self.id = Self.receiptID(
            contentID: contentID,
            occurrenceID: occurrenceID,
            state: state
        )
        self.contentID = contentID
        self.occurrenceID = occurrenceID
        self.channel = channel
        self.scope = scope
        self.state = state
        self.recordedAt = recordedAt
        self.choiceID = choiceID
        self.evidencePageIDs = Array(Set(evidencePageIDs)).sorted()
    }

    private static func receiptID(
        contentID: String,
        occurrenceID: String,
        state: AuthoredContentReceiptState
    ) -> String {
        "authored-content:\(contentID):\(occurrenceID):\(state.rawValue)"
    }
}

struct AuthoredContentReceiptQuery: Codable, Equatable {
    var contentID: String
    var state: AuthoredContentReceiptState = .delivered
    var channel: AuthoredContentChannel? = nil
    var scopeID: String? = nil
    var runID: String? = nil
    var phaseID: String? = nil
    var withinHours: Int? = nil
    var minimumOccurrences: Int = 1
}

/// A portable, append-only receipt shelf. Existing ledgers remain the source
/// of truth for their domains; this is the cross-media index that can answer
/// whether a Page, article, or broadcast actually arrived.
struct AuthoredContentReceiptLedger: Codable, Equatable {
    var receipts: [AuthoredContentReceipt] = []

    static let empty = AuthoredContentReceiptLedger()

    func matching(
        _ query: AuthoredContentReceiptQuery,
        now: Date
    ) -> [AuthoredContentReceipt] {
        receipts.filter { receipt in
            guard receipt.contentID == query.contentID,
                  receipt.state.satisfies(query.state) else {
                return false
            }
            if let channel = query.channel, receipt.channel != channel { return false }
            if let scopeID = query.scopeID, receipt.scope.scopeID != scopeID { return false }
            if let runID = query.runID, receipt.scope.runID != runID { return false }
            if let phaseID = query.phaseID, receipt.scope.phaseID != phaseID { return false }
            if let withinHours = query.withinHours {
                let horizon = TimeInterval(max(0, withinHours)) * 3_600
                guard receipt.recordedAt <= now,
                      now.timeIntervalSince(receipt.recordedAt) <= horizon else {
                    return false
                }
            }
            return receipt.recordedAt <= now
        }
    }

    func satisfies(
        _ query: AuthoredContentReceiptQuery,
        now: Date
    ) -> Bool {
        let occurrences = Set(matching(query, now: now).map(\.occurrenceID))
        return occurrences.count >= max(1, query.minimumOccurrences)
    }

    func recording(_ receipt: AuthoredContentReceipt) -> Self {
        var copy = self
        if let index = copy.receipts.firstIndex(where: { $0.id == receipt.id }) {
            let existing = copy.receipts[index]
            let evidence = Array(Set(existing.evidencePageIDs + receipt.evidencePageIDs)).sorted()
            let choice = existing.choiceID ?? receipt.choiceID
            let recordedAt = min(existing.recordedAt, receipt.recordedAt)
            guard evidence != existing.evidencePageIDs
                    || choice != existing.choiceID
                    || recordedAt != existing.recordedAt else {
                return self
            }
            copy.receipts[index].evidencePageIDs = evidence
            copy.receipts[index].choiceID = choice
            copy.receipts[index].recordedAt = recordedAt
        } else {
            copy.receipts.append(receipt)
            copy.receipts.sort {
                if $0.recordedAt == $1.recordedAt { return $0.id < $1.id }
                return $0.recordedAt < $1.recordedAt
            }
        }
        return copy
    }

    mutating func merge(_ other: Self) {
        for receipt in other.receipts {
            self = recording(receipt)
        }
    }

    fileprivate func deliveryReceipts(
        contentID: String,
        scopeID: String? = nil,
        runID: String? = nil,
        phaseID: String? = nil,
        now: Date
    ) -> [AuthoredContentReceipt] {
        receipts.filter { receipt in
            guard receipt.contentID == contentID,
                  receipt.state.isDeliveryEvent,
                  receipt.recordedAt <= now else {
                return false
            }
            if let scopeID, receipt.scope.scopeID != scopeID { return false }
            if let runID, receipt.scope.runID != runID { return false }
            if let phaseID, receipt.scope.phaseID != phaseID { return false }
            return true
        }
    }
}

enum AuthoredContentDependencyScope: String, Codable, Equatable {
    case ever
    case sameScope
    case sameRun
    case samePhase
}

enum AuthoredContentDependencyFailurePolicy: String, Codable, Equatable {
    case wait
    case reportThenContinue
    case expire
}

struct AuthoredContentDependency: Codable, Equatable {
    var contentID: String
    var requiredState: AuthoredContentReceiptState = .delivered
    var scope: AuthoredContentDependencyScope = .sameRun
    var withinHours: Int? = nil
    var minimumOccurrences: Int = 1
    var failurePolicy: AuthoredContentDependencyFailurePolicy = .wait

    func isSatisfied(
        in ledger: AuthoredContentReceiptLedger,
        currentScope: AuthoredContentScope,
        now: Date
    ) -> Bool {
        var query = AuthoredContentReceiptQuery(
            contentID: contentID,
            state: requiredState,
            withinHours: withinHours,
            minimumOccurrences: minimumOccurrences
        )
        switch scope {
        case .ever:
            break
        case .sameScope:
            query.scopeID = currentScope.scopeID
        case .sameRun:
            query.scopeID = currentScope.scopeID
            query.runID = currentScope.runID
        case .samePhase:
            guard currentScope.phaseID != nil else { return false }
            query.scopeID = currentScope.scopeID
            query.runID = currentScope.runID
            query.phaseID = currentScope.phaseID
        }
        return ledger.satisfies(query, now: now)
    }
}

enum AuthoredContentOccurrenceKind: String, Codable, Equatable {
    case onceEver
    case oncePerRun
    case oncePerPhase
    case repeatable
    case untilOpened
    case untilActed
}

struct AuthoredContentOccurrencePolicy: Codable, Equatable {
    var kind: AuthoredContentOccurrenceKind
    var cooldownHours: Int? = nil
    var maxPerRun: Int? = nil

    static let oncePerRun = AuthoredContentOccurrencePolicy(kind: .oncePerRun)

    func allows(
        contentID: String,
        scope: AuthoredContentScope,
        ledger: AuthoredContentReceiptLedger,
        now: Date
    ) -> Bool {
        let allDeliveries = ledger.deliveryReceipts(contentID: contentID, now: now)
        let runDeliveries = ledger.deliveryReceipts(
            contentID: contentID,
            scopeID: scope.scopeID,
            runID: scope.runID,
            now: now
        )
        switch kind {
        case .onceEver:
            return allDeliveries.isEmpty
        case .oncePerRun:
            guard scope.scopeID != nil || scope.runID != nil else {
                return allDeliveries.isEmpty
            }
            return runDeliveries.isEmpty
        case .oncePerPhase:
            guard let phaseID = scope.phaseID else { return false }
            return ledger.deliveryReceipts(
                contentID: contentID,
                scopeID: scope.scopeID,
                runID: scope.runID,
                phaseID: phaseID,
                now: now
            ).isEmpty
        case .repeatable:
            let occurrenceCount = Set(runDeliveries.map(\.occurrenceID)).count
            if let maxPerRun, occurrenceCount >= max(0, maxPerRun) {
                return false
            }
            if let cooldownHours,
               let latest = runDeliveries.map(\.recordedAt).max(),
               now.timeIntervalSince(latest) < TimeInterval(max(0, cooldownHours)) * 3_600 {
                return false
            }
            return true
        case .untilOpened:
            return !ledger.satisfies(
                scopedQuery(contentID: contentID, state: .opened, scope: scope),
                now: now
            )
        case .untilActed:
            return !ledger.satisfies(
                scopedQuery(contentID: contentID, state: .acted, scope: scope),
                now: now
            )
        }
    }

    private func scopedQuery(
        contentID: String,
        state: AuthoredContentReceiptState,
        scope: AuthoredContentScope
    ) -> AuthoredContentReceiptQuery {
        AuthoredContentReceiptQuery(
            contentID: contentID,
            state: state,
            scopeID: scope.scopeID,
            runID: scope.runID
        )
    }
}

// MARK: - Shared conditions

struct AuthoredContentWorldEventContext: Equatable {
    var eventID: String
    var packID: String?
    var runID: String?
    var phaseID: String?
    var phaseTitle: String?
    var phaseRole: WorldEventPhaseRole?
    var lifecycleStage: WorldEventLifecycleStage
    var activationMode: WorldEventActivationMode?
    var liveDay: Int?
    var touchCount: Int
}

/// One event predicate is matched against one resolved event. Keeping ID,
/// phase, role, lifecycle, mode, and touch requirements together prevents an
/// event ID from accidentally combining with another event's matching phase.
struct AuthoredContentWorldEventQuery: Codable, Equatable {
    var eventIDs: [String] = []
    var runIDs: [String] = []
    var phaseIDs: [String] = []
    var phaseRoles: [WorldEventPhaseRole] = []
    var lifecycleStages: [WorldEventLifecycleStage] = []
    var activationModes: [WorldEventActivationMode] = []
    var minimumTouches: Int? = nil
    var minimumLiveDay: Int? = nil
    var maximumLiveDay: Int? = nil

    func matches(_ event: AuthoredContentWorldEventContext) -> Bool {
        if !eventIDs.isEmpty, !eventIDs.contains(where: { Self.matches($0, event.eventID) }) {
            return false
        }
        if !runIDs.isEmpty {
            guard let runID = event.runID,
                  runIDs.contains(where: { Self.matches($0, runID) }) else {
                return false
            }
        }
        if !phaseIDs.isEmpty {
            let candidates = [event.phaseID, event.phaseTitle].compactMap { $0 }
            guard phaseIDs.contains(where: { wanted in
                candidates.contains(where: { Self.matches(wanted, $0) })
            }) else {
                return false
            }
        }
        if !phaseRoles.isEmpty {
            guard let role = event.phaseRole, phaseRoles.contains(role) else { return false }
        }
        if !lifecycleStages.isEmpty, !lifecycleStages.contains(event.lifecycleStage) {
            return false
        }
        if !activationModes.isEmpty {
            guard let mode = event.activationMode, activationModes.contains(mode) else { return false }
        }
        if let minimumTouches, event.touchCount < minimumTouches { return false }
        if let minimumLiveDay {
            guard let liveDay = event.liveDay, liveDay >= minimumLiveDay else { return false }
        }
        if let maximumLiveDay {
            guard let liveDay = event.liveDay, liveDay <= maximumLiveDay else { return false }
        }
        return true
    }

    private static func matches(_ left: String, _ right: String) -> Bool {
        normalize(left) == normalize(right)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

/// Runtime facts visible to a shared gate. The optional legacy contexts are
/// compatibility bridges, not a second source of truth: they preserve exact
/// old Page and Radio semantics while new authored atoms use the common fields.
struct AuthoredContentGateContext {
    var now: Date
    var timeBand: String?
    var month: Int?
    var weekday: Int?
    var weekOfYear: Int?
    var moonPhase: String?
    var weatherTags: Set<String>
    var worldEvents: [AuthoredContentWorldEventContext]
    var standingLedger: StandingLedger
    var receiptLedger: AuthoredContentReceiptLedger
    var contentScope: AuthoredContentScope
    var raritySeed: String
    var legacyPageContext: PageTriggerContext?
    var legacyRadioContext: RadioWorldContext?

    init(
        now: Date,
        timeBand: String? = nil,
        month: Int? = nil,
        weekday: Int? = nil,
        weekOfYear: Int? = nil,
        moonPhase: String? = nil,
        weatherTags: Set<String> = [],
        worldEvents: [AuthoredContentWorldEventContext] = [],
        standingLedger: StandingLedger = .unwritten,
        receiptLedger: AuthoredContentReceiptLedger = .empty,
        contentScope: AuthoredContentScope = .unscoped,
        raritySeed: String = "",
        legacyPageContext: PageTriggerContext? = nil,
        legacyRadioContext: RadioWorldContext? = nil
    ) {
        self.now = now
        self.timeBand = timeBand
        self.month = month
        self.weekday = weekday
        self.weekOfYear = weekOfYear
        self.moonPhase = moonPhase
        self.weatherTags = Set(weatherTags.map(Self.normalize))
        self.worldEvents = worldEvents
        self.standingLedger = standingLedger
        self.receiptLedger = receiptLedger
        self.contentScope = contentScope
        self.raritySeed = raritySeed
        self.legacyPageContext = legacyPageContext
        self.legacyRadioContext = legacyRadioContext
    }

    static func page(
        _ context: PageTriggerContext,
        lifecycle: [WorldEventLifecycleSnapshot] = [],
        receiptLedger: AuthoredContentReceiptLedger = .empty,
        contentScope: AuthoredContentScope = .unscoped
    ) -> Self {
        let calendar = context.calendar
        return Self(
            now: context.now,
            timeBand: context.timeBand,
            month: context.month,
            weekday: context.weekday,
            weekOfYear: calendar.component(.weekOfYear, from: context.now),
            moonPhase: context.moonPhase,
            weatherTags: context.weatherTags,
            worldEvents: eventContexts(active: context.activeWorldEvents, lifecycle: lifecycle),
            standingLedger: context.inputs.standingLedger,
            receiptLedger: receiptLedger,
            contentScope: contentScope,
            raritySeed: context.day.id,
            legacyPageContext: context
        )
    }

    static func radio(
        _ context: RadioWorldContext,
        moonPhase: String? = nil,
        lifecycle: [WorldEventLifecycleSnapshot] = [],
        standingLedger: StandingLedger = .unwritten,
        receiptLedger: AuthoredContentReceiptLedger = .empty,
        contentScope: AuthoredContentScope = .unscoped,
        raritySeed: String = ""
    ) -> Self {
        Self(
            now: context.now ?? Date(),
            timeBand: context.timeOfDay,
            month: context.month,
            weekday: context.weekday,
            weekOfYear: context.weekOfYear,
            moonPhase: moonPhase,
            weatherTags: context.pageContext.weatherTags,
            worldEvents: eventContexts(active: context.activeWorldEvents, lifecycle: lifecycle),
            standingLedger: standingLedger,
            receiptLedger: receiptLedger,
            contentScope: contentScope,
            raritySeed: raritySeed,
            legacyRadioContext: context
        )
    }

    private static func eventContexts(
        active: [ResolvedWorldEvent],
        lifecycle: [WorldEventLifecycleSnapshot]
    ) -> [AuthoredContentWorldEventContext] {
        var contexts = lifecycle.map { snapshot -> AuthoredContentWorldEventContext in
            let resolved = active.first { $0.id == snapshot.eventID && $0.packID == snapshot.packID }
            return AuthoredContentWorldEventContext(
                eventID: snapshot.eventID,
                packID: snapshot.packID,
                runID: snapshot.runID,
                phaseID: snapshot.phaseID,
                phaseTitle: resolved?.phase.title,
                phaseRole: snapshot.phaseRole ?? resolved?.phase.role,
                lifecycleStage: snapshot.stage,
                activationMode: resolved?.activationMode,
                liveDay: snapshot.liveDay,
                touchCount: resolved?.playerTouchCount ?? 0
            )
        }
        let represented = Set(contexts.map { "\($0.packID ?? ""):\($0.eventID)" })
        contexts += active.compactMap { event in
            let key = "\(event.packID):\(event.id)"
            guard !represented.contains(key) else { return nil }
            return AuthoredContentWorldEventContext(
                eventID: event.id,
                packID: event.packID,
                runID: nil,
                phaseID: event.phase.id,
                phaseTitle: event.phase.title,
                phaseRole: event.phase.role,
                lifecycleStage: .live,
                activationMode: event.activationMode,
                liveDay: nil,
                touchCount: event.playerTouchCount
            )
        }
        return contexts
    }

    fileprivate static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum AuthoredContentPredicate: Equatable {
    case timeBands([String])
    case months([Int])
    case weekdays([Int])
    case weeksOfYear([Int])
    case dateWindow(startsAt: Date?, endsAt: Date?)
    case moonPhases([String])
    case weatherTagsAny([String])
    case worldEvent(AuthoredContentWorldEventQuery)
    case receipt(AuthoredContentReceiptQuery)
    case standingBand(field: StandingField, bands: [StandingBand])
    case rarity(Double)
    case legacyPageTrigger(PageTrigger)
    case legacyRadioConditions(RadioBanter.Conditions)

    func allows(in context: AuthoredContentGateContext, contentID: String) -> Bool {
        switch self {
        case .timeBands(let values):
            guard !values.isEmpty else { return true }
            guard let actual = context.timeBand else { return false }
            return Self.contains(actual, in: values)
        case .months(let values):
            guard !values.isEmpty else { return true }
            guard let actual = context.month else { return false }
            return values.contains(actual)
        case .weekdays(let values):
            guard !values.isEmpty else { return true }
            guard let actual = context.weekday else { return false }
            return values.contains(actual)
        case .weeksOfYear(let values):
            guard !values.isEmpty else { return true }
            guard let actual = context.weekOfYear else { return false }
            return values.contains(actual)
        case .dateWindow(let startsAt, let endsAt):
            if let startsAt, context.now < startsAt { return false }
            if let endsAt, context.now >= endsAt { return false }
            return true
        case .moonPhases(let values):
            guard !values.isEmpty else { return true }
            guard let actual = context.moonPhase else { return false }
            return Self.contains(actual, in: values)
        case .weatherTagsAny(let values):
            guard !values.isEmpty else { return true }
            let wanted = Set(values.map(AuthoredContentGateContext.normalize))
            return !wanted.isDisjoint(with: context.weatherTags)
        case .worldEvent(let query):
            return context.worldEvents.contains(where: query.matches)
        case .receipt(let query):
            return context.receiptLedger.satisfies(query, now: context.now)
        case .standingBand(let field, let bands):
            guard !bands.isEmpty, let actual = context.standingLedger.band(field) else { return false }
            return bands.contains(actual)
        case .rarity(let probability):
            let clamped = min(1, max(0, probability))
            if clamped <= 0 { return false }
            if clamped >= 1 { return true }
            let bucket = Self.stableBucket("\(context.raritySeed)|\(contentID)|authored-content-rarity")
            return Double(bucket) / 10_000 < clamped
        case .legacyPageTrigger(let trigger):
            guard let pageContext = context.legacyPageContext else { return false }
            return trigger.allows(context: pageContext, archetypeID: contentID)
        case .legacyRadioConditions(let conditions):
            guard let radioContext = context.legacyRadioContext else { return false }
            return radioContext.satisfies(conditions)
        }
    }

    private static func contains(_ value: String, in candidates: [String]) -> Bool {
        let normalized = AuthoredContentGateContext.normalize(value)
        return candidates.contains { AuthoredContentGateContext.normalize($0) == normalized }
    }

    private static func stableBucket(_ value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 10_000)
    }
}

extension AuthoredContentPredicate: Codable {
    private enum Kind: String, Codable {
        case timeBands, months, weekdays, weeksOfYear, dateWindow, moonPhases
        case weatherTagsAny, worldEvent, receipt, standingBand, rarity
        case legacyPageTrigger, legacyRadioConditions
    }

    private enum CodingKeys: String, CodingKey {
        case kind, strings, integers, startsAt, endsAt, worldEvent, receipt
        case standingField, standingBands, probability, pageTrigger, radioConditions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .timeBands:
            self = .timeBands(try container.decode([String].self, forKey: .strings))
        case .months:
            self = .months(try container.decode([Int].self, forKey: .integers))
        case .weekdays:
            self = .weekdays(try container.decode([Int].self, forKey: .integers))
        case .weeksOfYear:
            self = .weeksOfYear(try container.decode([Int].self, forKey: .integers))
        case .dateWindow:
            self = .dateWindow(
                startsAt: try container.decodeIfPresent(Date.self, forKey: .startsAt),
                endsAt: try container.decodeIfPresent(Date.self, forKey: .endsAt)
            )
        case .moonPhases:
            self = .moonPhases(try container.decode([String].self, forKey: .strings))
        case .weatherTagsAny:
            self = .weatherTagsAny(try container.decode([String].self, forKey: .strings))
        case .worldEvent:
            self = .worldEvent(try container.decode(AuthoredContentWorldEventQuery.self, forKey: .worldEvent))
        case .receipt:
            self = .receipt(try container.decode(AuthoredContentReceiptQuery.self, forKey: .receipt))
        case .standingBand:
            self = .standingBand(
                field: try container.decode(StandingField.self, forKey: .standingField),
                bands: try container.decode([StandingBand].self, forKey: .standingBands)
            )
        case .rarity:
            self = .rarity(try container.decode(Double.self, forKey: .probability))
        case .legacyPageTrigger:
            self = .legacyPageTrigger(try container.decode(PageTrigger.self, forKey: .pageTrigger))
        case .legacyRadioConditions:
            self = .legacyRadioConditions(try container.decode(RadioBanter.Conditions.self, forKey: .radioConditions))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .timeBands(let values):
            try container.encode(Kind.timeBands, forKey: .kind)
            try container.encode(values, forKey: .strings)
        case .months(let values):
            try container.encode(Kind.months, forKey: .kind)
            try container.encode(values, forKey: .integers)
        case .weekdays(let values):
            try container.encode(Kind.weekdays, forKey: .kind)
            try container.encode(values, forKey: .integers)
        case .weeksOfYear(let values):
            try container.encode(Kind.weeksOfYear, forKey: .kind)
            try container.encode(values, forKey: .integers)
        case .dateWindow(let startsAt, let endsAt):
            try container.encode(Kind.dateWindow, forKey: .kind)
            try container.encodeIfPresent(startsAt, forKey: .startsAt)
            try container.encodeIfPresent(endsAt, forKey: .endsAt)
        case .moonPhases(let values):
            try container.encode(Kind.moonPhases, forKey: .kind)
            try container.encode(values, forKey: .strings)
        case .weatherTagsAny(let values):
            try container.encode(Kind.weatherTagsAny, forKey: .kind)
            try container.encode(values, forKey: .strings)
        case .worldEvent(let query):
            try container.encode(Kind.worldEvent, forKey: .kind)
            try container.encode(query, forKey: .worldEvent)
        case .receipt(let query):
            try container.encode(Kind.receipt, forKey: .kind)
            try container.encode(query, forKey: .receipt)
        case .standingBand(let field, let bands):
            try container.encode(Kind.standingBand, forKey: .kind)
            try container.encode(field, forKey: .standingField)
            try container.encode(bands, forKey: .standingBands)
        case .rarity(let probability):
            try container.encode(Kind.rarity, forKey: .kind)
            try container.encode(probability, forKey: .probability)
        case .legacyPageTrigger(let trigger):
            try container.encode(Kind.legacyPageTrigger, forKey: .kind)
            try container.encode(trigger, forKey: .pageTrigger)
        case .legacyRadioConditions(let conditions):
            try container.encode(Kind.legacyRadioConditions, forKey: .kind)
            try container.encode(conditions, forKey: .radioConditions)
        }
    }
}

/// Two shallow composition levels keep pack JSON readable while still
/// covering practical authoring: every `allOf`, at least one `anyOf`, and none
/// of `noneOf`. More elaborate story sequencing belongs in dependencies.
struct AuthoredContentGate: Codable, Equatable {
    var allOf: [AuthoredContentPredicate]
    var anyOf: [AuthoredContentPredicate]
    var noneOf: [AuthoredContentPredicate]

    init(
        allOf: [AuthoredContentPredicate] = [],
        anyOf: [AuthoredContentPredicate] = [],
        noneOf: [AuthoredContentPredicate] = []
    ) {
        self.allOf = allOf
        self.anyOf = anyOf
        self.noneOf = noneOf
    }

    init(pageTrigger: PageTrigger) {
        self.init(allOf: [.legacyPageTrigger(pageTrigger)])
    }

    init(radioConditions: RadioBanter.Conditions) {
        self.init(allOf: [.legacyRadioConditions(radioConditions)])
    }

    func allows(in context: AuthoredContentGateContext, contentID: String) -> Bool {
        guard allOf.allSatisfy({ $0.allows(in: context, contentID: contentID) }) else {
            return false
        }
        if !anyOf.isEmpty,
           !anyOf.contains(where: { $0.allows(in: context, contentID: contentID) }) {
            return false
        }
        if noneOf.contains(where: { $0.allows(in: context, contentID: contentID) }) {
            return false
        }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case allOf, anyOf, noneOf
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allOf = try container.decodeIfPresent([AuthoredContentPredicate].self, forKey: .allOf) ?? []
        anyOf = try container.decodeIfPresent([AuthoredContentPredicate].self, forKey: .anyOf) ?? []
        noneOf = try container.decodeIfPresent([AuthoredContentPredicate].self, forKey: .noneOf) ?? []
    }
}
