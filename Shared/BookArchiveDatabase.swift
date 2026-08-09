import Foundation
import SwiftData

@Model
final class StoredArchiveDay {
    @Attribute(.unique) var id: String
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \StoredArchivePage.day) var pages: [StoredArchivePage]

    init(id: String, date: Date, pages: [StoredArchivePage] = []) {
        self.id = id
        self.date = date
        self.pages = pages
    }
}

@Model
final class StoredArchivePage {
    @Attribute(.unique) var id: String
    var typeRawValue: String
    var createdAt: Date
    var promptText: String
    var userInput: String
    var playerReply: String = ""
    var tagsData: Data
    var usedInBookOfYou: Bool
    var sourceID: String
    var originRawValue: String
    var privacyRawValue: String
    var promptVersion: String?
    var mediaAssetsData: Data?
    var contextData: Data?
    var tarotReadingData: Data? = nil
    /// The complete archive value. The individual columns above remain useful
    /// for SwiftData identity, sorting, and lightweight migration from existing
    /// stores; this payload prevents new `BookPage` evidence from being silently
    /// omitted whenever the value type grows.
    var pageData: Data? = nil
    var day: StoredArchiveDay?

    init(page: BookPage) {
        id = page.id
        typeRawValue = page.type.rawValue
        createdAt = page.createdAt
        promptText = page.promptText
        userInput = page.userInput
        playerReply = page.playerReply
        tagsData = (try? JSONEncoder().encode(page.tags)) ?? Data()
        usedInBookOfYou = page.usedInBookOfYou
        sourceID = page.sourceID
        originRawValue = page.origin.rawValue
        privacyRawValue = page.privacy.rawValue
        promptVersion = page.promptVersion
        mediaAssetsData = try? JSONEncoder().encode(page.mediaAssets)
        contextData = page.context.flatMap { try? JSONEncoder().encode($0) }
        tarotReadingData = page.tarotReadingArtifact.flatMap { try? JSONEncoder().encode($0) }
        pageData = try? JSONEncoder().encode(page)
    }

    var bookPage: BookPage {
        if let pageData,
           let page = try? JSONDecoder().decode(BookPage.self, from: pageData) {
            return page
        }

        // Rows created before the complete payload was added still retain the
        // original archive fields. They decode here and acquire `pageData` the
        // next time their day is persisted.
        let decodedTags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        let decodedMediaAssets = mediaAssetsData
            .flatMap { try? JSONDecoder().decode([BookPageMediaAsset].self, from: $0) } ?? []
        let decodedContext = contextData
            .flatMap { try? JSONDecoder().decode(BookPageContextSnapshot.self, from: $0) }
        let decodedTarotReading = tarotReadingData
            .flatMap { try? JSONDecoder().decode(TarotReadingArtifact.self, from: $0) }
        let type = BookPageType.legacyCompatible(rawValue: typeRawValue) ?? .souvenir
        return BookPage(
            id: id,
            type: type,
            createdAt: createdAt,
            promptText: promptText,
            userInput: userInput,
            playerReply: playerReply,
            tags: decodedTags,
            usedInBookOfYou: usedInBookOfYou,
            sourceID: sourceID,
            origin: BookPageOrigin(rawValue: originRawValue),
            privacy: BookPagePrivacy(rawValue: privacyRawValue) ?? .privateLocal,
            promptVersion: promptVersion,
            mediaAssets: decodedMediaAssets,
            context: decodedContext,
            tarotReadingArtifact: decodedTarotReading
        )
    }
}

@Model
final class StoredArchiveResurfacingEvent {
    @Attribute(.unique) var id: String
    var pageID: String
    var surfacedAt: Date
    var reason: String
    var surface: String
    var wasUsed: Bool

    init(
        id: String = UUID().uuidString,
        pageID: String,
        surfacedAt: Date = Date(),
        reason: String,
        surface: String,
        wasUsed: Bool = false
    ) {
        self.id = id
        self.pageID = pageID
        self.surface = surface
        self.surfacedAt = surfacedAt
        self.reason = reason
        self.wasUsed = wasUsed
    }
}

struct BookArchiveResurfacing: Identifiable, Equatable {
    var id: String
    var pageID: String
    var surfacedAt: Date
    var reason: String
    var surface: String
    var wasUsed: Bool
}

extension StoredArchiveResurfacingEvent {
    var resurfacing: BookArchiveResurfacing {
        BookArchiveResurfacing(
            id: id,
            pageID: pageID,
            surfacedAt: surfacedAt,
            reason: reason,
            surface: surface,
            wasUsed: wasUsed
        )
    }
}

@Model
final class StoredSelfFact {
    @Attribute(.unique) var id: String
    var questionID: String
    var question: String
    var answer: String
    var bookTranslation: String
    var sensitivityRawValue: String
    var usePermissionRawValue: String
    var tagsData: Data
    var createdAt: Date
    var updatedAt: Date

    init(fact: SelfFact) {
        id = fact.id
        questionID = fact.questionID
        question = fact.question
        answer = fact.answer
        bookTranslation = fact.bookTranslation
        sensitivityRawValue = fact.sensitivity.rawValue
        usePermissionRawValue = fact.usePermission.rawValue
        tagsData = (try? JSONEncoder().encode(fact.tags)) ?? Data()
        createdAt = fact.createdAt
        updatedAt = fact.updatedAt
    }

    var selfFact: SelfFact {
        SelfFact(
            id: id,
            questionID: questionID,
            question: question,
            answer: answer,
            bookTranslation: bookTranslation,
            sensitivity: SelfFactSensitivity(rawValue: sensitivityRawValue) ?? .delight,
            usePermission: SelfFactUsePermission(rawValue: usePermissionRawValue) ?? .privateContext,
            tags: (try? JSONDecoder().decode([String].self, from: tagsData)) ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(with fact: SelfFact) {
        questionID = fact.questionID
        question = fact.question
        answer = fact.answer
        bookTranslation = fact.bookTranslation
        sensitivityRawValue = fact.sensitivity.rawValue
        usePermissionRawValue = fact.usePermission.rawValue
        tagsData = (try? JSONEncoder().encode(fact.tags)) ?? Data()
        createdAt = fact.createdAt
        updatedAt = fact.updatedAt
    }
}

@Model
final class StoredNarrativeEvent {
    @Attribute(.unique) var id: String
    var kindRawValue: String
    var sourcePageTypeRawValue: String?
    var sourcePageID: String?
    var createdAt: Date
    var summary: String
    var tagsData: Data
    var effectData: Data

    init(event: NarrativeEvent) {
        id = event.id
        kindRawValue = event.kind.rawValue
        sourcePageTypeRawValue = event.sourcePageType?.rawValue
        sourcePageID = event.sourcePageID
        createdAt = event.createdAt
        summary = event.summary
        tagsData = (try? JSONEncoder().encode(event.tags)) ?? Data()
        effectData = (try? JSONEncoder().encode(event.effect)) ?? Data()
    }

    var narrativeEvent: NarrativeEvent {
        NarrativeEvent(
            id: id,
            kind: NarrativeEventKind(rawValue: kindRawValue) ?? .pageKept,
            sourcePageType: sourcePageTypeRawValue.flatMap(BookPageType.init(rawValue:)),
            sourcePageID: sourcePageID,
            createdAt: createdAt,
            summary: summary,
            tags: (try? JSONDecoder().decode([String].self, from: tagsData)) ?? [],
            effect: (try? JSONDecoder().decode(NarrativeEventEffect.self, from: effectData)) ?? NarrativeEventEffect()
        )
    }

    func update(with event: NarrativeEvent) {
        kindRawValue = event.kind.rawValue
        sourcePageTypeRawValue = event.sourcePageType?.rawValue
        sourcePageID = event.sourcePageID
        createdAt = event.createdAt
        summary = event.summary
        tagsData = (try? JSONEncoder().encode(event.tags)) ?? Data()
        effectData = (try? JSONEncoder().encode(event.effect)) ?? Data()
    }
}

@Model
final class StoredNarrativeEntityMemory {
    @Attribute(.unique) var id: String
    var entityID: String
    var sourceEventID: String
    var sourcePageID: String?
    var createdAt: Date
    var summary: String
    var tagsData: Data
    var narrativeWeight: Int

    init(memory: NarrativeEntityMemory) {
        id = memory.id
        entityID = memory.entityID
        sourceEventID = memory.sourceEventID
        sourcePageID = memory.sourcePageID
        createdAt = memory.createdAt
        summary = memory.summary
        tagsData = (try? JSONEncoder().encode(memory.tags)) ?? Data()
        narrativeWeight = memory.narrativeWeight
    }

    var entityMemory: NarrativeEntityMemory {
        NarrativeEntityMemory(
            id: id,
            entityID: entityID,
            sourceEventID: sourceEventID,
            sourcePageID: sourcePageID,
            summary: summary,
            tags: (try? JSONDecoder().decode([String].self, from: tagsData)) ?? [],
            narrativeWeight: narrativeWeight,
            createdAt: createdAt
        )
    }

    func update(with memory: NarrativeEntityMemory) {
        entityID = memory.entityID
        sourceEventID = memory.sourceEventID
        sourcePageID = memory.sourcePageID
        createdAt = memory.createdAt
        summary = memory.summary
        tagsData = (try? JSONEncoder().encode(memory.tags)) ?? Data()
        narrativeWeight = memory.narrativeWeight
    }
}

@Model
final class StoredCustomCastMember {
    @Attribute(.unique) var id: String
    var name: String
    var kindRawValue: String
    var meaning: String
    var descriptionText: String
    var traitsData: Data
    var beliefsData: Data
    var goalsData: Data
    var tagsData: Data
    var baseBelief: Int
    var narrativeWeight: Int
    var createdAt: Date
    var updatedAt: Date
    var imageAssetData: Data?

    init(member: CustomCastMember) {
        id = member.id
        name = member.name
        kindRawValue = member.kind.rawValue
        meaning = member.meaning
        descriptionText = member.description
        traitsData = (try? JSONEncoder().encode(member.traits)) ?? Data()
        beliefsData = (try? JSONEncoder().encode(member.beliefs)) ?? Data()
        goalsData = (try? JSONEncoder().encode(member.goals)) ?? Data()
        tagsData = (try? JSONEncoder().encode(member.tags)) ?? Data()
        baseBelief = member.baseBelief
        narrativeWeight = member.narrativeWeight
        createdAt = member.createdAt
        updatedAt = member.updatedAt
        imageAssetData = member.imageAsset.flatMap { try? JSONEncoder().encode($0) }
    }

    var customCastMember: CustomCastMember {
        CustomCastMember(
            id: id,
            name: name,
            kind: NarrativeEntityKind(rawValue: kindRawValue) ?? .object,
            meaning: meaning,
            description: descriptionText,
            traits: (try? JSONDecoder().decode([String].self, from: traitsData)) ?? [],
            beliefs: (try? JSONDecoder().decode([String].self, from: beliefsData)) ?? [],
            goals: (try? JSONDecoder().decode([String].self, from: goalsData)) ?? [],
            tags: (try? JSONDecoder().decode([String].self, from: tagsData)) ?? [],
            baseBelief: baseBelief,
            narrativeWeight: narrativeWeight,
            createdAt: createdAt,
            updatedAt: updatedAt,
            imageAsset: imageAssetData.flatMap { try? JSONDecoder().decode(BookPageMediaAsset.self, from: $0) }
        )
    }

    func update(with member: CustomCastMember) {
        name = member.name
        kindRawValue = member.kind.rawValue
        meaning = member.meaning
        descriptionText = member.description
        traitsData = (try? JSONEncoder().encode(member.traits)) ?? Data()
        beliefsData = (try? JSONEncoder().encode(member.beliefs)) ?? Data()
        goalsData = (try? JSONEncoder().encode(member.goals)) ?? Data()
        tagsData = (try? JSONEncoder().encode(member.tags)) ?? Data()
        baseBelief = member.baseBelief
        narrativeWeight = member.narrativeWeight
        createdAt = member.createdAt
        updatedAt = member.updatedAt
        imageAssetData = member.imageAsset.flatMap { try? JSONEncoder().encode($0) }
    }
}

@Model
final class StoredFacultyEntry {
    @Attribute(.unique) var id: String
    var kindRawValue: String
    var facultyID: String
    var dayID: String
    var sourcePageID: String?
    var createdAt: Date
    var windowID: String
    var windowName: String
    var rawText: String
    var tagsData: Data

    init(entry: FacultyEntry) {
        id = entry.id
        kindRawValue = entry.kind.rawValue
        facultyID = entry.facultyID
        dayID = entry.dayID
        sourcePageID = entry.sourcePageID
        createdAt = entry.createdAt
        windowID = entry.windowID
        windowName = entry.windowName
        rawText = entry.rawText
        tagsData = (try? JSONEncoder().encode(entry.tags)) ?? Data()
    }

    var facultyEntry: FacultyEntry {
        FacultyEntry(
            id: id,
            kind: FacultyEntryKind(rawValue: kindRawValue) ?? .fuel,
            facultyID: facultyID,
            dayID: dayID,
            sourcePageID: sourcePageID,
            createdAt: createdAt,
            windowID: windowID,
            windowName: windowName,
            rawText: rawText,
            tags: (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        )
    }

    func update(with entry: FacultyEntry) {
        kindRawValue = entry.kind.rawValue
        facultyID = entry.facultyID
        dayID = entry.dayID
        sourcePageID = entry.sourcePageID
        createdAt = entry.createdAt
        windowID = entry.windowID
        windowName = entry.windowName
        rawText = entry.rawText
        tagsData = (try? JSONEncoder().encode(entry.tags)) ?? Data()
    }
}

/// One raw row per calendar day, kept or not. The Daybook is append-only and
/// upserted by `dayID`, so a day can never acquire a second row.
///
/// The payload is stored as encoded JSON rather than ~40 stored properties.
/// The row is written and read whole, never queried by field, and the fields
/// will keep arriving as later phases expand what a day records — a Codable
/// blob absorbs that without a store migration each time. `dayID` and `date`
/// stay first-class so gap-walking and windowed reads remain real queries.
@Model
final class StoredDaybookEntry {
    @Attribute(.unique) var dayID: String
    var date: Date
    var fidelityRawValue: String
    var writtenAt: Date
    var payloadData: Data

    init(entry: DaybookEntry) {
        dayID = entry.dayID
        date = entry.date
        fidelityRawValue = entry.fidelity.rawValue
        writtenAt = entry.writtenAt
        payloadData = (try? JSONEncoder().encode(entry)) ?? Data()
    }

    var daybookEntry: DaybookEntry? {
        try? JSONDecoder().decode(DaybookEntry.self, from: payloadData)
    }

    func update(with entry: DaybookEntry) {
        date = entry.date
        fidelityRawValue = entry.fidelity.rawValue
        writtenAt = entry.writtenAt
        payloadData = (try? JSONEncoder().encode(entry)) ?? Data()
    }
}

/// Not thread-safe: each instance tracks load-source/error state, so an
/// instance must stay on one actor. The app's shared instance lives behind
/// the @MainActor `BookDatabase` wrapper; background readers (Siri queries,
/// braid context) open their own short-lived instance instead.
final class BookArchiveDatabase {
    /// 7: the Daybook — one row per calendar day, whether or not anything was kept.
    static let schemaVersion = 7
    static let backupDirectoryName = "BookArchiveBackups"

    enum LoadSource: String, Equatable {
        case swiftData
        case migratedFromJSON
        case fallbackJSON
    }

    struct Report: Equatable {
        var schemaVersion: Int
        var storagePath: String
        var dayCount: Int
        var pageCount: Int
        var loadSource: LoadSource
        var lastError: String?
        var backupCount: Int
        var lastBackupPath: String?
    }

    let storeURL: URL
    private(set) var lastLoadSource: LoadSource = .fallbackJSON
    private(set) var lastError: String?
    private(set) var lastBackupURL: URL?
    /// Creating a SwiftData `ModelContainer` opens and prepares the store. A
    /// single keep can perform several related archive writes, so rebuilding the
    /// container for every query serializes repeated store setup on the caller's
    /// actor. Each database instance is actor-confined; reuse its container and
    /// create lightweight contexts per operation instead.
    private var modelContainer: ModelContainer?

    var backupDirectoryURL: URL {
        storeURL.deletingLastPathComponent().appendingPathComponent(Self.backupDirectoryName, isDirectory: true)
    }

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    /// The legacy JSON archive is only decoded when SwiftData has nothing to
    /// offer — once migrated, the (whole-history) decode never runs again.
    func loadDays(migratingFrom legacyDays: @autoclosure () -> [BookDay]) -> [BookDay] {
        var decodedLegacyDays: [BookDay]?
        func legacy() -> [BookDay] {
            if let decodedLegacyDays { return decodedLegacyDays }
            let days = legacyDays()
            decodedLegacyDays = days
            return days
        }

        do {
            let context = try makeContext()
            let storedDays = try fetchDays(in: context)
            if !storedDays.isEmpty {
                lastLoadSource = .swiftData
                lastError = nil
                return storedDays
            }

            let migratingDays = legacy()
            if migratingDays.contains(where: { !$0.pages.isEmpty }) {
                lastBackupURL = try writeBackup(days: migratingDays, generatedAt: Date(), reason: "pre-swiftdata-migration")
            }
            try saveDays(migratingDays, in: context)
            lastLoadSource = .migratedFromJSON
            lastError = nil
            return migratingDays
        } catch {
            lastLoadSource = .fallbackJSON
            lastError = error.localizedDescription
            return legacy()
        }
    }

    func saveDays(_ days: [BookDay]) throws {
        let context = try makeContext()
        try saveDays(days, in: context)
        lastLoadSource = .swiftData
        lastError = nil
    }

    func upsert(_ day: BookDay, fallbackDays: [BookDay]) throws -> [BookDay] {
        let context = try makeContext()
        try upsert(day, in: context)
        let days = try fetchDays(in: context)
        lastLoadSource = .swiftData
        lastError = nil
        return days.isEmpty ? fallbackDays : days
    }

    func day(id: String) throws -> BookDay? {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredArchiveDay>(
            predicate: #Predicate { day in
                day.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { storedDay in
            BookDay(
                id: storedDay.id,
                date: storedDay.date,
                pages: storedDay.pages
                    .map(\.bookPage)
                    .sorted { $0.createdAt < $1.createdAt }
            )
        }
    }

    func pages(matching query: BookPageQuery) throws -> [BookPage] {
        let context = try makeContext()
        let descriptor = FetchDescriptor<StoredArchivePage>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let fetchedPages = try context.fetch(descriptor)
        return fetchedPages
            .lazy
            .map(\.bookPage)
            .filter { page in BookArchiveIndex.matches(page, query: query) }
            .prefix(max(query.limit, 0))
            .map { $0 }
    }

    func resurfacingCandidates(before date: Date = Date(), calendar: Calendar = .current, limit: Int = 12) throws -> [BookPage] {
        let startOfDay = calendar.startOfDay(for: date)
        let context = try makeContext()
        let descriptor = FetchDescriptor<StoredArchivePage>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .lazy
            .map(\.bookPage)
            .filter { $0.createdAt < startOfDay && ReturnedStacksRitual.isEligible($0) }
            .prefix(max(limit, 0))
            .map { $0 }
    }

    func resurfacingHistory(
        surfacePrefix: String? = nil,
        since: Date? = nil,
        limit: Int = 500
    ) throws -> [BookArchiveResurfacing] {
        let context = try makeContext()
        let descriptor = FetchDescriptor<StoredArchiveResurfacingEvent>(
            sortBy: [SortDescriptor(\.surfacedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .lazy
            .filter { event in
                (surfacePrefix == nil || event.surface.hasPrefix(surfacePrefix ?? ""))
                    && (since == nil || event.surfacedAt >= since ?? .distantPast)
            }
            .prefix(max(limit, 0))
            .map(\.resurfacing)
    }

    func returnedStacksCards(
        from days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 3
    ) throws -> [ReturnedStackCard] {
        let history = try resurfacingHistory(surfacePrefix: ReturnedStacksRitual.surfacePrefix)
        let cards = ReturnedStacksRitual.cards(
            from: days,
            history: history,
            now: now,
            calendar: calendar,
            limit: limit
        )
        let startOfDay = calendar.startOfDay(for: now)
        let alreadyRecorded = Set(
            history
                .filter { $0.surfacedAt >= startOfDay }
                .map(\.pageID)
        )
        for (index, card) in cards.enumerated() where !alreadyRecorded.contains(card.page.id) {
            try recordResurfacing(
                page: card.page,
                reason: card.reason,
                surface: ReturnedStacksRitual.surfaceName(role: card.role, index: index),
                id: "\(ReturnedStacksRitual.surfacePrefix)-\(BookDay.id(for: now, calendar: calendar))-\(card.page.id)",
                surfacedAt: now
            )
        }
        return cards
    }

    func recordResurfacing(
        page: BookPage,
        reason: String,
        surface: String = "home",
        id: String = UUID().uuidString,
        surfacedAt: Date = Date()
    ) throws {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredArchiveResurfacingEvent>(
            predicate: #Predicate { storedEvent in
                storedEvent.id == id
            }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }
        let event = StoredArchiveResurfacingEvent(
            id: id,
            pageID: page.id,
            surfacedAt: surfacedAt,
            reason: reason,
            surface: surface
        )
        context.insert(event)
        try context.save()
    }

    func selfFacts() throws -> [SelfFact] {
        let context = try makeContext()
        let descriptor = FetchDescriptor<StoredSelfFact>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map(\.selfFact)
    }

    func upsertSelfFact(_ fact: SelfFact) throws {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredSelfFact>(
            predicate: #Predicate { storedFact in
                storedFact.id == fact.id
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.update(with: fact)
        } else {
            context.insert(StoredSelfFact(fact: fact))
        }
        try context.save()
    }

    func narrativeEvents(limit: Int = 100) throws -> [NarrativeEvent] {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredNarrativeEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit, 0)
        return try context.fetch(descriptor).map(\.narrativeEvent)
    }

    func upsertNarrativeEvent(_ event: NarrativeEvent) throws {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredNarrativeEvent>(
            predicate: #Predicate { storedEvent in
                storedEvent.id == event.id
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.update(with: event)
        } else {
            context.insert(StoredNarrativeEvent(event: event))
        }
        try context.save()
    }

    func entityMemories(entityIDs: [String]? = nil, limit: Int = 80) throws -> [NarrativeEntityMemory] {
        let context = try makeContext()
        let memories: [StoredNarrativeEntityMemory]
        if let entityIDs, !entityIDs.isEmpty {
            let wanted = Set(entityIDs)
            memories = try context.fetch(FetchDescriptor<StoredNarrativeEntityMemory>(
                sortBy: [
                    SortDescriptor(\.narrativeWeight, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse)
                ]
            )).filter { wanted.contains($0.entityID) }
        } else {
            var descriptor = FetchDescriptor<StoredNarrativeEntityMemory>(
                sortBy: [
                    SortDescriptor(\.narrativeWeight, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse)
                ]
            )
            descriptor.fetchLimit = max(limit, 0)
            memories = try context.fetch(descriptor)
        }
        return memories.prefix(max(limit, 0)).map(\.entityMemory)
    }

    func upsertEntityMemory(_ memory: NarrativeEntityMemory) throws {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredNarrativeEntityMemory>(
            predicate: #Predicate { storedMemory in
                storedMemory.id == memory.id
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.update(with: memory)
        } else {
            context.insert(StoredNarrativeEntityMemory(memory: memory))
        }
        try context.save()
    }

    func customCastMembers(limit: Int = 200) throws -> [CustomCastMember] {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredCustomCastMember>(
            sortBy: [
                SortDescriptor(\.narrativeWeight, order: .reverse),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = max(limit, 0)
        return try context.fetch(descriptor).map(\.customCastMember)
    }

    func upsertCustomCastMember(_ member: CustomCastMember) throws {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredCustomCastMember>(
            predicate: #Predicate { storedMember in
                storedMember.id == member.id
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.update(with: member)
        } else {
            context.insert(StoredCustomCastMember(member: member))
        }
        try context.save()
    }

    func facultyEntries(kind: FacultyEntryKind? = nil, dayIDs: [String]? = nil, since: Date? = nil, limit: Int = 120) throws -> [FacultyEntry] {
        let context = try makeContext()
        let wantedDayIDs = dayIDs.map(Set.init)
        var descriptor = FetchDescriptor<StoredFacultyEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit * 3, limit)
        return try context.fetch(descriptor)
            .lazy
            .map(\.facultyEntry)
            .filter { entry in
                if let kind, entry.kind != kind {
                    return false
                }
                if let wantedDayIDs, !wantedDayIDs.contains(entry.dayID) {
                    return false
                }
                if let since, entry.createdAt < since {
                    return false
                }
                return true
            }
            .prefix(max(limit, 0))
            .map { $0 }
    }

    func upsertFacultyEntry(_ entry: FacultyEntry) throws {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredFacultyEntry>(
            predicate: #Predicate { storedEntry in
                storedEntry.id == entry.id
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.update(with: entry)
        } else {
            context.insert(StoredFacultyEntry(entry: entry))
        }
        try context.save()
    }

    // MARK: - The Daybook

    /// Rows newest-first. `limit` is generous by default because the Ledger's
    /// baselines want a 90-day window and the caller is always off-main.
    func daybookEntries(since: Date? = nil, limit: Int = 400) throws -> [DaybookEntry] {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredDaybookEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit, 0)
        return try context.fetch(descriptor)
            .compactMap(\.daybookEntry)
            .filter { entry in
                guard let since else { return true }
                return entry.date >= since
            }
    }

    /// Just the identifiers, for the gap walk. Decoding 90 payloads to find out
    /// which days already have a row would be work for nothing.
    func recordedDaybookDayIDs(limit: Int = 400) throws -> Set<String> {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredDaybookEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit, 0)
        return Set(try context.fetch(descriptor).map(\.dayID))
    }

    func daybookEntry(dayID: String) throws -> DaybookEntry? {
        let context = try makeContext()
        var descriptor = FetchDescriptor<StoredDaybookEntry>(
            predicate: #Predicate { row in
                row.dayID == dayID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.daybookEntry
    }

    /// Upsert by `dayID`. A live row always wins over a reconstructed or absent
    /// one for the same day; the reverse is refused, so a backfill walk can
    /// never overwrite what the Book actually watched happen.
    @discardableResult
    func upsertDaybookEntry(_ entry: DaybookEntry) throws -> Bool {
        let context = try makeContext()
        let id = entry.dayID
        var descriptor = FetchDescriptor<StoredDaybookEntry>(
            predicate: #Predicate { row in
                row.dayID == id
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            let existingFidelity = DaybookEntry.Fidelity(rawValue: existing.fidelityRawValue)
            guard Self.mayReplace(existingFidelity, with: entry.fidelity) else { return false }
            existing.update(with: entry)
        } else {
            context.insert(StoredDaybookEntry(entry: entry))
        }
        try context.save()
        return true
    }

    @discardableResult
    func upsertDaybookEntries(_ entries: [DaybookEntry]) throws -> Int {
        var written = 0
        for entry in entries where try upsertDaybookEntry(entry) {
            written += 1
        }
        return written
    }

    /// live > reconstructed > absent. A row may always be replaced by one of the
    /// same fidelity (the live tick refreshes today's counts all day long).
    static func mayReplace(
        _ existing: DaybookEntry.Fidelity?,
        with incoming: DaybookEntry.Fidelity
    ) -> Bool {
        func rank(_ fidelity: DaybookEntry.Fidelity) -> Int {
            switch fidelity {
            case .absent: return 0
            case .reconstructed: return 1
            case .live: return 2
            }
        }
        guard let existing else { return true }
        return rank(incoming) >= rank(existing)
    }

    func exportArchive(generatedAt: Date = Date()) throws -> BookArchiveExport {
        let context = try makeContext()
        return BookArchiveExport(generatedAt: generatedAt, days: try fetchDays(in: context))
    }

    func writeBackup(generatedAt: Date = Date()) throws -> URL {
        let archive = try exportArchive(generatedAt: generatedAt)
        let url = try writeArchiveBackup(archive, generatedAt: generatedAt, reason: "manual")
        lastBackupURL = url
        return url
    }

    func writeBackup(days: [BookDay], generatedAt: Date = Date(), reason: String) throws -> URL {
        let archive = BookArchiveExport(generatedAt: generatedAt, days: days)
        let url = try writeArchiveBackup(archive, generatedAt: generatedAt, reason: reason)
        lastBackupURL = url
        return url
    }

    func report(for days: [BookDay]) -> Report {
        Report(
            schemaVersion: Self.schemaVersion,
            storagePath: storeURL.path,
            dayCount: days.count,
            pageCount: days.reduce(0) { count, day in count + day.pages.count },
            loadSource: lastLoadSource,
            lastError: lastError,
            backupCount: backupCount(),
            lastBackupPath: lastBackupURL?.path
        )
    }

    private func writeArchiveBackup(_ archive: BookArchiveExport, generatedAt: Date, reason: String) throws -> URL {
        try SensitiveFileProtection.protectDirectory(at: backupDirectoryURL)
        let url = backupDirectoryURL.appendingPathComponent(backupFileName(for: generatedAt, reason: reason))
        try SensitiveFileProtection.write(archive.encodedData(), to: url)
        return url
    }

    private func makeContext() throws -> ModelContext {
        if let modelContainer {
            return ModelContext(modelContainer)
        }

        try SensitiveFileProtection.protectDirectory(at: storeURL.deletingLastPathComponent())

        let schema = Schema([
            StoredArchiveDay.self,
            StoredArchivePage.self,
            StoredArchiveResurfacingEvent.self,
            StoredSelfFact.self,
            StoredNarrativeEvent.self,
            StoredNarrativeEntityMemory.self,
            StoredCustomCastMember.self,
            StoredFacultyEntry.self,
            StoredDaybookEntry.self
        ])
        let configuration = ModelConfiguration(
            "LabyrinthBook",
            schema: schema,
            url: storeURL
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        try? SensitiveFileProtection.protectItem(at: storeURL)
        try? SensitiveFileProtection.protectItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        try? SensitiveFileProtection.protectItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
        modelContainer = container
        return ModelContext(container)
    }

    private func backupFileName(for date: Date, reason: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let safeTimestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return "book-archive-\(reason)-\(safeTimestamp).json"
    }

    private func backupCount() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }
        return files.filter { $0.pathExtension.lowercased() == "json" }.count
    }

    private func fetchDays(in context: ModelContext) throws -> [BookDay] {
        let descriptor = FetchDescriptor<StoredArchiveDay>(
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor).map { storedDay in
            BookDay(
                id: storedDay.id,
                date: storedDay.date,
                pages: storedDay.pages
                    .map(\.bookPage)
                    .sorted { $0.createdAt < $1.createdAt }
            )
        }
    }

    private func saveDays(_ days: [BookDay], in context: ModelContext) throws {
        let existingDays = try context.fetch(FetchDescriptor<StoredArchiveDay>())
        for day in existingDays {
            context.delete(day)
        }

        for day in BookArchiveExport(days: days).days {
            let storedDay = StoredArchiveDay(id: day.id, date: day.date)
            storedDay.pages = day.pages
                .sorted { $0.createdAt < $1.createdAt }
                .map { StoredArchivePage(page: $0) }
            context.insert(storedDay)
        }

        try context.save()
    }

    private func upsert(_ day: BookDay, in context: ModelContext) throws {
        let normalizedDay = BookArchiveExport(days: [day]).days.first ?? day
        var descriptor = FetchDescriptor<StoredArchiveDay>(
            predicate: #Predicate { storedDay in
                storedDay.id == normalizedDay.id
            }
        )
        descriptor.fetchLimit = 1
        if let existingDay = try context.fetch(descriptor).first {
            context.delete(existingDay)
        }

        let storedDay = StoredArchiveDay(id: normalizedDay.id, date: normalizedDay.date)
        storedDay.pages = normalizedDay.pages
            .sorted { $0.createdAt < $1.createdAt }
            .map { StoredArchivePage(page: $0) }
        context.insert(storedDay)
        try context.save()
    }
}
