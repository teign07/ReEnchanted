import Foundation

@MainActor
enum BookDatabase {
    static let schemaVersion = BookArchiveDatabase.schemaVersion
    static let storeFileName = "labyrinth-book.store"
    typealias PageQuery = BookPageQuery
    typealias Report = BookArchiveDatabase.Report
    typealias LoadSource = BookArchiveDatabase.LoadSource

    private static var overrideStoreURL: URL?
    private static var database = BookArchiveDatabase(storeURL: resolvedStoreURL())

    static var storeURL: URL {
        if let overrideStoreURL {
            return overrideStoreURL
        }
        return resolvedStoreURL()
    }

    static var backupDirectoryURL: URL {
        database.backupDirectoryURL
    }

    static func withStoreURL<T>(_ url: URL, perform work: () throws -> T) rethrows -> T {
        let previousURL = overrideStoreURL
        let previousDatabase = database
        overrideStoreURL = url
        database = BookArchiveDatabase(storeURL: url)
        defer {
            overrideStoreURL = previousURL
            database = previousDatabase
        }
        return try work()
    }

    static func loadDays(migratingFrom legacyDays: @autoclosure () -> [BookDay]) -> [BookDay] {
        refreshDatabaseIfNeeded()
        return database.loadDays(migratingFrom: legacyDays())
    }

    /// A private handle for work that must stay off the main actor (launch
    /// hydration, foreground reloads, Siri/Spotlight entity queries, braid
    /// context building). The caller owns the instance, so the main actor's
    /// shared one is never touched from another thread. Test store overrides
    /// don't apply here — this always reads the real store.
    nonisolated static func detachedDatabase() -> BookArchiveDatabase {
        BookArchiveDatabase(storeURL: resolvedStoreURL())
    }

    /// One-shot read of the archive for off-main callers.
    nonisolated static func loadDaysDetached() -> [BookDay] {
        detachedDatabase().loadDays(migratingFrom: BookStore.loadDays())
    }

    static func saveDays(_ days: [BookDay]) throws {
        refreshDatabaseIfNeeded()
        try database.saveDays(days)
    }

    static func upsert(_ day: BookDay, fallbackDays: [BookDay]) throws -> [BookDay] {
        refreshDatabaseIfNeeded()
        return try database.upsert(day, fallbackDays: fallbackDays)
    }

    static func day(id: String) throws -> BookDay? {
        refreshDatabaseIfNeeded()
        return try database.day(id: id)
    }

    static func pages(matching query: PageQuery) throws -> [BookPage] {
        refreshDatabaseIfNeeded()
        return try database.pages(matching: query)
    }

    static func resurfacingCandidates(before date: Date = Date(), limit: Int = 12) throws -> [BookPage] {
        refreshDatabaseIfNeeded()
        return try database.resurfacingCandidates(before: date, limit: limit)
    }

    static func recordResurfacing(page: BookPage, reason: String, surface: String = "home") throws {
        refreshDatabaseIfNeeded()
        try database.recordResurfacing(page: page, reason: reason, surface: surface)
    }

    static func selfFacts() throws -> [SelfFact] {
        refreshDatabaseIfNeeded()
        return try database.selfFacts()
    }

    static func upsertSelfFact(_ fact: SelfFact) throws {
        refreshDatabaseIfNeeded()
        try database.upsertSelfFact(fact)
    }

    static func narrativeEvents(limit: Int = 100) throws -> [NarrativeEvent] {
        refreshDatabaseIfNeeded()
        return try database.narrativeEvents(limit: limit)
    }

    static func upsertNarrativeEvent(_ event: NarrativeEvent) throws {
        refreshDatabaseIfNeeded()
        try database.upsertNarrativeEvent(event)
    }

    static func entityMemories(entityIDs: [String]? = nil, limit: Int = 80) throws -> [NarrativeEntityMemory] {
        refreshDatabaseIfNeeded()
        return try database.entityMemories(entityIDs: entityIDs, limit: limit)
    }

    static func upsertEntityMemory(_ memory: NarrativeEntityMemory) throws {
        refreshDatabaseIfNeeded()
        try database.upsertEntityMemory(memory)
    }

    static func customCastMembers(limit: Int = 200) throws -> [CustomCastMember] {
        refreshDatabaseIfNeeded()
        return try database.customCastMembers(limit: limit)
    }

    static func upsertCustomCastMember(_ member: CustomCastMember) throws {
        refreshDatabaseIfNeeded()
        try database.upsertCustomCastMember(member)
    }

    static func facultyEntries(
        kind: FacultyEntryKind? = nil,
        dayIDs: [String]? = nil,
        since: Date? = nil,
        limit: Int = 120
    ) throws -> [FacultyEntry] {
        refreshDatabaseIfNeeded()
        return try database.facultyEntries(kind: kind, dayIDs: dayIDs, since: since, limit: limit)
    }

    static func upsertFacultyEntry(_ entry: FacultyEntry) throws {
        refreshDatabaseIfNeeded()
        try database.upsertFacultyEntry(entry)
    }

    static func exportArchive(generatedAt: Date = Date()) throws -> BookArchiveExport {
        refreshDatabaseIfNeeded()
        return try database.exportArchive(generatedAt: generatedAt)
    }

    static func writeBackup(generatedAt: Date = Date()) throws -> URL {
        refreshDatabaseIfNeeded()
        return try database.writeBackup(generatedAt: generatedAt)
    }

    static func writeBackup(days: [BookDay], generatedAt: Date = Date(), reason: String) throws -> URL {
        refreshDatabaseIfNeeded()
        return try database.writeBackup(days: days, generatedAt: generatedAt, reason: reason)
    }

    static func report(for days: [BookDay]) -> Report {
        refreshDatabaseIfNeeded()
        return database.report(for: days)
    }

    private static func refreshDatabaseIfNeeded() {
        let currentURL = storeURL
        if database.storeURL != currentURL {
            database = BookArchiveDatabase(storeURL: currentURL)
        }
    }

    nonisolated private static func resolvedStoreURL() -> URL {
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent(storeFileName)
    }
}
