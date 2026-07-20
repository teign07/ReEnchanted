import XCTest
@testable import InsideCoverCore

@MainActor
final class BookArchiveDatabaseTests: XCTestCase {
    func testMigratesLegacyDaysCreatesBackupAndReloadsFromSwiftData() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let legacyDays = [
            day(id: "wrong-1", day: 1, pageIDs: ["souvenir-1"]),
            day(id: "wrong-2", day: 2, pageIDs: ["souvenir-2", "body-2"])
        ]

        let migrated = database.loadDays(migratingFrom: legacyDays)

        XCTAssertEqual(migrated.map(\.id), ["wrong-1", "wrong-2"])
        XCTAssertEqual(database.report(for: migrated).loadSource, .migratedFromJSON)
        XCTAssertEqual(database.report(for: migrated).backupCount, 1)

        let reloadedDatabase = BookArchiveDatabase(storeURL: harness.storeURL)
        let reloaded = reloadedDatabase.loadDays(migratingFrom: [])

        XCTAssertEqual(reloaded.map(\.id), ["2026-06-01", "2026-06-02"])
        XCTAssertEqual(reloaded.flatMap(\.pages).map(\.id), ["souvenir-1", "body-2", "souvenir-2"])
        XCTAssertEqual(reloadedDatabase.report(for: reloaded).loadSource, .swiftData)
    }

    func testQueriesAndResurfacingCandidatesReadFromDatabase() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        try database.saveDays([
            day(id: "one", day: 1, pageIDs: ["souvenir-old"], usedInBookOfYou: true),
            day(id: "two", day: 2, pageIDs: ["wonder"], type: .wonderCompass, sourceID: "wonder-compass"),
            day(id: "three", day: 3, pageIDs: ["souvenir-today"], usedInBookOfYou: true)
        ])

        let wonderPages = try database.pages(matching: BookPageQuery(type: .wonderCompass, sourceID: "wonder-compass", limit: 10))
        let resurfacing = try database.resurfacingCandidates(before: date(day: 3, hour: 12), calendar: calendar, limit: 10)

        XCTAssertEqual(wonderPages.map(\.id), ["wonder"])
        XCTAssertEqual(resurfacing.map(\.id), ["souvenir-old"])
    }

    func testDailyReturnedStacksSelectionPersistsAndRereadsWithoutReshuffling() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let archive = (1...5).map { dayNumber in
            BookDay(
                id: "day-\(dayNumber)",
                date: date(day: dayNumber, hour: 9),
                pages: [
                    BookPage(
                        id: "returnable-\(dayNumber)",
                        type: dayNumber.isMultiple(of: 2) ? .diary : .souvenir,
                        createdAt: date(day: dayNumber, hour: 12),
                        promptText: "A kept page",
                        userInput: "A sufficiently particular sentence from archive day \(dayNumber)."
                    )
                ]
            )
        }
        try database.saveDays(archive)
        let now = date(day: 10, hour: 9)

        let first = try database.returnedStacksCards(from: archive, now: now)
        let second = try database.returnedStacksCards(from: archive, now: now)
        let history = try database.resurfacingHistory(surfacePrefix: ReturnedStacksRitual.surfacePrefix)

        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(first, second)
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(Set(history.map(\.pageID)), Set(first.map(\.page.id)))
    }

    func testMediaAssetsPersistThroughSwiftDataReload() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let visualPage = BookPage(
            id: "kept-visual",
            type: .illustration,
            createdAt: date(day: 1, hour: 14),
            promptText: "An Illustration from the Labyrinth of Stories",
            userInput: "The Book kept a picture of the margin light.",
            tags: ["illustration"],
            sourceID: "labyrinth-illustrations",
            origin: .imported,
            privacy: .publicReference,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .bundledImage,
                    reference: "IlluminatedPhotoSource",
                    caption: "Character Dossier Plate",
                    sourceID: "labyrinth-illustrations",
                    metadata: ["plateID": "character-headmistress-seraphina-thorne"]
                )
            ]
        )

        try database.saveDays([
            BookDay(id: "one", date: date(day: 1, hour: 9), pages: [visualPage])
        ])

        let reloaded = try BookArchiveDatabase(storeURL: harness.storeURL)
            .pages(matching: BookPageQuery(type: .illustration, limit: 10))
        let media = try XCTUnwrap(reloaded.first?.mediaAssets.first)

        XCTAssertEqual(media.kind, .bundledImage)
        XCTAssertEqual(media.reference, "IlluminatedPhotoSource")
        XCTAssertEqual(media.caption, "Character Dossier Plate")
        XCTAssertEqual(media.metadata["plateID"], "character-headmistress-seraphina-thorne")
    }

    func testUpsertReplacesCalendarDayAndPreservesOtherDays() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        try database.saveDays([
            day(id: "one", day: 1, pageIDs: ["a"]),
            day(id: "two", day: 2, pageIDs: ["b"])
        ])

        let replacement = day(id: "wrong-two", day: 2, pageIDs: ["c", "d"])
        let days = try database.upsert(replacement, fallbackDays: [])

        XCTAssertEqual(days.map(\.id), ["2026-06-01", "2026-06-02"])
        XCTAssertEqual(days[0].pages.map(\.id), ["a"])
        XCTAssertEqual(days[1].pages.map(\.id), ["d", "c"])
    }

    func testSelfFactsUpsertAndReloadFromSwiftData() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let first = selfFact(
            answer: "Avery",
            translation: "The Book may call you Avery."
        )
        try database.upsertSelfFact(first)

        var updated = first
        updated.answer = "Beej"
        updated.bookTranslation = "The Book may call you Beej."
        updated.updatedAt = date(day: 1, hour: 13)
        try database.upsertSelfFact(updated)

        let reloaded = try BookArchiveDatabase(storeURL: harness.storeURL).selfFacts()

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.questionID, "called")
        XCTAssertEqual(reloaded.first?.answer, "Beej")
        XCTAssertEqual(reloaded.first?.bookTranslation, "The Book may call you Beej.")
    }

    func testNarrativeEventsUpsertAndReloadFromSwiftData() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let weatherPage = page(
            id: "weather-page-kept",
            type: .weather,
            createdAt: date(day: 1, hour: 14),
            sourceID: "weather-page"
        )
        let firstEvent = NarrativeEventResolver.event(forKept: weatherPage)

        try database.upsertNarrativeEvent(firstEvent)
        var updatedEvent = firstEvent
        updatedEvent.summary = "The Weather Page tugged the silver thread."
        updatedEvent.effect.threadWeightDeltas["weather-in-the-stacks"] = 7
        try database.upsertNarrativeEvent(updatedEvent)

        let reloaded = try BookArchiveDatabase(storeURL: harness.storeURL).narrativeEvents()

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.id, firstEvent.id)
        XCTAssertEqual(reloaded.first?.summary, "The Weather Page tugged the silver thread.")
        XCTAssertEqual(reloaded.first?.effect.threadWeightDeltas["weather-in-the-stacks"], 7)
        XCTAssertGreaterThan(reloaded.first?.effect.entityWeightDeltas["weather-page"] ?? 0, 0)
    }

    func testNarrativeEventsReturnNewestFirstAndHonorLimit() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let early = NarrativeEventResolver.event(forKept: page(
            id: "early",
            type: .souvenir,
            createdAt: date(day: 1, hour: 8)
        ))
        let late = NarrativeEventResolver.event(forKept: page(
            id: "late",
            type: .illuminatedPhoto,
            createdAt: date(day: 1, hour: 18)
        ))

        try database.upsertNarrativeEvent(early)
        try database.upsertNarrativeEvent(late)

        XCTAssertEqual(try database.narrativeEvents(limit: 1).map(\.id), [late.id])
        XCTAssertEqual(try database.narrativeEvents(limit: 10).map(\.id), [late.id, early.id])
    }

    func testPageCreatedBeforeMidnightStaysOnYesterdayAfterCalendarRolls() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let lateNight = date(day: 1, hour: 23, minute: 58)
        let nextMorning = date(day: 2, hour: 8)
        var yesterday = BookDay.day(containing: lateNight, calendar: calendar)
        yesterday.pages = [
            page(id: "late-souvenir", createdAt: lateNight)
        ]

        try database.saveDays([yesterday])

        let yesterdayID = BookDay.id(for: lateNight, calendar: calendar)
        let todayID = BookDay.id(for: nextMorning, calendar: calendar)
        let reloadedYesterday = try XCTUnwrap(database.day(id: yesterdayID))
        let generatedToday = BookDay.day(containing: nextMorning, calendar: calendar)

        XCTAssertEqual(reloadedYesterday.id, "2026-06-01")
        XCTAssertEqual(reloadedYesterday.pages.map(\.id), ["late-souvenir"])
        XCTAssertEqual(generatedToday.id, todayID)
        XCTAssertNil(try database.day(id: todayID))
    }

    func testNewLaunchAfterMidnightCreatesSecondDayWithoutOverwritingYesterday() throws {
        let harness = try DatabaseHarness()
        let database = BookArchiveDatabase(storeURL: harness.storeURL)
        let lateNight = date(day: 1, hour: 23, minute: 58)
        let nextMorning = date(day: 2, hour: 8, minute: 5)
        var yesterday = BookDay.day(containing: lateNight, calendar: calendar)
        yesterday.pages = [
            page(id: "late-souvenir", createdAt: lateNight)
        ]
        var today = BookDay.day(containing: nextMorning, calendar: calendar)
        today.pages = [
            page(id: "morning-weather", type: .weather, createdAt: nextMorning, sourceID: "weather-page")
        ]
        try database.saveDays([yesterday])

        let days = try database.upsert(today, fallbackDays: [])

        XCTAssertEqual(days.map(\.id), ["2026-06-01", "2026-06-02"])
        XCTAssertEqual(days[0].pages.map(\.id), ["late-souvenir"])
        XCTAssertEqual(days[1].pages.map(\.id), ["morning-weather"])
    }

    private struct DatabaseHarness {
        var directory: URL
        var storeURL: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("inside-cover-db-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storeURL = directory.appendingPathComponent("test.store")
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func day(
        id: String,
        day: Int,
        pageIDs: [String],
        type: BookPageType = .souvenir,
        sourceID: String = "one-sentence-souvenir",
        usedInBookOfYou: Bool = false
    ) -> BookDay {
        BookDay(
            id: id,
            date: date(day: day, hour: 9),
            pages: pageIDs.enumerated().map { offset, id in
                BookPage(
                    id: id,
                    type: id.hasPrefix("body") ? .body : type,
                    createdAt: date(day: day, hour: 12 - offset),
                    promptText: "Prompt \(id)",
                    userInput: "Page \(id)",
                    tags: ["database"],
                    usedInBookOfYou: usedInBookOfYou,
                    sourceID: id.hasPrefix("body") ? "body-page" : sourceID,
                    privacy: id.hasPrefix("body") ? .localSensitive : .privateLocal
                )
            }
        )
    }

    private func date(day: Int, hour: Int) -> Date {
        date(day: day, hour: hour, minute: 0)
    }

    private func date(day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date()
    }

    private func page(
        id: String,
        type: BookPageType = .souvenir,
        createdAt: Date,
        sourceID: String = "one-sentence-souvenir"
    ) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: createdAt,
            promptText: "Prompt \(id)",
            userInput: "Page \(id)",
            tags: ["day-boundary"],
            sourceID: sourceID
        )
    }

    private func selfFact(answer: String, translation: String) -> SelfFact {
        SelfFact(
            id: "core-self-knowledge:called",
            questionID: "called",
            question: "What do you like to be called?",
            answer: answer,
            bookTranslation: translation,
            sensitivity: .identity,
            usePermission: .quoteAllowed,
            tags: ["name", "identity"],
            createdAt: date(day: 1, hour: 12),
            updatedAt: date(day: 1, hour: 12)
        )
    }
}
