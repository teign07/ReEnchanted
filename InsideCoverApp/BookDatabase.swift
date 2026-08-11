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
    /// don't apply here: this always reads the real store.
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

    static func returnedStacksCards(
        from days: [BookDay],
        now: Date = Date(),
        limit: Int = 3
    ) throws -> [ReturnedStackCard] {
        refreshDatabaseIfNeeded()
        return try database.returnedStacksCards(from: days, now: now, limit: limit)
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

    // MARK: - The Daybook
    //
    // Every write is off-main by construction: the tick runs on a detached
    // instance so a day boundary crossing at foreground can never touch the
    // desk build. The main-actor reads here exist for tests and for the
    // reader-facing surfaces that arrive in later phases.

    static func daybookEntries(since: Date? = nil, limit: Int = 400) throws -> [DaybookEntry] {
        refreshDatabaseIfNeeded()
        return try database.daybookEntries(since: since, limit: limit)
    }

    static func daybookEntry(dayID: String) throws -> DaybookEntry? {
        refreshDatabaseIfNeeded()
        return try database.daybookEntry(dayID: dayID)
    }

    @discardableResult
    static func upsertDaybookEntry(_ entry: DaybookEntry) throws -> Bool {
        refreshDatabaseIfNeeded()
        return try database.upsertDaybookEntry(entry)
    }

    /// Records today's row and fills any gap behind it, oldest first. Returns
    /// the number of rows actually written. Safe to call on every foreground:
    /// the upsert is keyed by dayID and refuses to demote a live row.
    nonisolated static func tickDaybookDetached(
        entry: DaybookEntry,
        days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let database = detachedDatabase()
        do {
            let recorded = (try? database.recordedDaybookDayIDs()) ?? []
            let backfill = DaybookRecorder.backfill(
                recordedDayIDs: recorded,
                days: days,
                now: now,
                calendar: calendar
            )
            var written = try database.upsertDaybookEntries(backfill)
            if try database.upsertDaybookEntry(entry) { written += 1 }

            // A row written earlier in a day the reader kept writing into can be
            // left behind by its own archive. The gap walk won't revisit it, so
            // correct the trailing window against what was actually kept.
            let recent = (try? database.daybookEntries(limit: 32)) ?? []
            let corrections = DaybookRecorder.reconciliations(
                entries: recent,
                days: days,
                now: now,
                calendar: calendar
            ).filter { $0.dayID != entry.dayID }
            written += try database.upsertDaybookEntries(corrections)

            return written
        } catch {
            // The Daybook is a quiet observer. A failed tick costs one row of
            // history and must never surface to the reader or fail a session.
            return 0
        }
    }

    nonisolated static func daybookEntriesDetached(since: Date? = nil, limit: Int = 400) -> [DaybookEntry] {
        (try? detachedDatabase().daybookEntries(since: since, limit: limit)) ?? []
    }

    /// Ticks the Daybook and posts the result to a fresh Standing Ledger, all on
    /// the caller's detached executor. Returns the Ledger for the caller to hand
    /// back to the vault on the main actor.
    ///
    /// The two are done together because the Ledger is only ever as current as
    /// the last row, and walking ninety days twice would be work for nothing.
    nonisolated static func tickDaybookAndPostLedger(
        entry: DaybookEntry,
        days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (ledger: StandingLedger, signals: InferredReaderSignals, rows: [DaybookEntry]) {
        _ = tickDaybookDetached(entry: entry, days: days, now: now, calendar: calendar)
        let rows = daybookEntriesDetached(limit: StandingGate.longWindow + 32)
        let ledger = StandingLedgerBuilder.build(entries: rows, now: now, calendar: calendar)

        // The behavioural lane reads the reader's own prose over the last two
        // fortnights, so it only needs the recent archive.
        let recentPages = days
            .flatMap(\.capturedPages)
            .filter { page in
                guard let cutoff = calendar.date(byAdding: .day, value: -60, to: now) else { return true }
                return page.createdAt >= cutoff
            }
        let signals = InferredSignalReader.read(
            pages: recentPages,
            rows: rows,
            ledger: ledger,
            now: now,
            calendar: calendar
        )
        return (ledger, signals, rows)
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

/// Reads the durable archive rather than the launch-time view cache. ContentView
/// intentionally hydrates bounded event/memory windows for responsiveness; a
/// direct question to the Book is the moment to consult the complete local store.
actor AskTheBookArchiveMemoryReader {
    static let shared = AskTheBookArchiveMemoryReader()

    func retrieve(
        query: String,
        previousTurns: [AskTheBookTurn],
        baseline: StacksSearchDataset
    ) -> AskTheBookMemoryPacket {
        let database = BookDatabase.detachedDatabase()
        var dataset = baseline
        dataset.days = database.loadDays(migratingFrom: baseline.days)
        if let facts = try? database.selfFacts() {
            dataset.selfFacts = facts
        }
        if let events = try? database.narrativeEvents(limit: 20_000) {
            dataset.narrativeEvents = events
        }
        if let memories = try? database.entityMemories(entityIDs: nil, limit: 20_000) {
            dataset.memories = NarrativeEntityMemoryConsolidator.consolidate(memories)
        }
        if let entries = try? database.facultyEntries(
            kind: nil,
            dayIDs: nil,
            since: nil,
            limit: 20_000
        ) {
            dataset.facultyEntries = entries
        }
        if let customCast = try? database.customCastMembers(limit: 5_000) {
            dataset.entities = NarrativePackRegistry.entities + customCast.map(\.entity)
        }
        return AskTheBookMemoryRetriever.retrieve(
            query: query,
            previousTurns: previousTurns,
            from: dataset
        )
    }
}
