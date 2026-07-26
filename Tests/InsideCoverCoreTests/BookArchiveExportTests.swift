import XCTest
@testable import InsideCoverCore

final class BookArchiveExportTests: XCTestCase {
    func testArchiveExportNormalizesMetadataAndSortOrder() throws {
        let export = BookArchiveExport(
            generatedAt: date(day: 4, hour: 12),
            days: [
                day(id: "wrong-later", day: 3, pageIDs: ["c", "b"]),
                day(id: "wrong-earlier", day: 1, pageIDs: ["a"])
            ],
            calendar: calendar
        )

        XCTAssertEqual(export.schemaVersion, BookArchiveExport.schemaVersion)
        XCTAssertEqual(export.dayCount, 2)
        XCTAssertEqual(export.pageCount, 3)
        XCTAssertEqual(export.days.map(\.id), ["2026-06-01", "2026-06-03"])
        XCTAssertEqual(export.days[1].pages.map(\.id), ["b", "c"])
    }

    func testArchiveExportRoundTripsThroughJSON() throws {
        let export = BookArchiveExport(
            generatedAt: date(day: 4, hour: 12),
            days: [day(id: "wrong", day: 2, pageIDs: ["a", "b"])],
            calendar: calendar
        )

        let decoded = try BookArchiveExport.decoded(from: try export.encodedData())

        XCTAssertEqual(decoded, export)
    }

    func testArchiveExportMergesDuplicateCalendarDaysBeforeBackup() throws {
        let export = BookArchiveExport(
            generatedAt: date(day: 4, hour: 12),
            days: [
                day(id: "wrong-a", day: 2, pageIDs: ["a"]),
                day(id: "wrong-b", day: 2, pageIDs: ["b"]),
                day(id: "wrong-c", day: 1, pageIDs: ["c"])
            ],
            calendar: calendar
        )

        XCTAssertEqual(export.days.map(\.id), ["2026-06-01", "2026-06-02"])
        XCTAssertEqual(export.days[0].pages.map(\.id), ["c"])
        XCTAssertEqual(export.days[1].pages.map(\.id), ["a", "b"])
        XCTAssertEqual(export.pageCount, 3)
    }

    func testMonthlyEditionPreviousMonthCuratesExpectedSections() {
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 12,
            hour: 12
        ))!
        let may = BookDay(
            id: "2026-05-31",
            date: calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 31))!,
            pages: [
                BookPage(id: "may", type: .souvenir, createdAt: calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 31, hour: 9))!, promptText: "Old", userInput: "Too early")
            ]
        )
        let june = BookDay(
            id: "2026-06-03",
            date: date(day: 3, hour: 0),
            pages: [
                BookPage(id: "braid", type: .bookOfYou, createdAt: date(day: 3, hour: 22), promptText: "Braid", userInput: "The day braided itself."),
                BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 3, hour: 12), promptText: "Souvenir", userInput: "The harbor kept its minutes.", tags: ["harbor"]),
                BookPage(id: "letter", type: .letter, createdAt: date(day: 3, hour: 13), promptText: "Letter", userInput: "Dear keeper, the margins are listening."),
                BookPage(id: "image", type: .illuminatedPhoto, createdAt: date(day: 3, hour: 14), promptText: "Photo", userInput: "A plate of light.", mediaAssets: [
                    BookPageMediaAsset(kind: .renderedImageFile, reference: "/tmp/fake.png", caption: "Fake", sourceID: "test")
                ])
            ]
        )
        let july = BookDay(
            id: "2026-07-01",
            date: calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 7, day: 1))!,
            pages: [
                BookPage(id: "july", type: .souvenir, createdAt: calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 7, day: 1, hour: 9))!, promptText: "New", userInput: "Too late")
            ]
        )

        let edition = MonthlyEditionBuilder.previousMonth(
            from: [may, june, july],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(edition.title, "Book of You: June 2026")
        XCTAssertEqual(edition.dayCount, 1)
        XCTAssertEqual(edition.pageCount, 4)
        XCTAssertTrue(edition.sections.contains { $0.id == "daily-braids" })
        XCTAssertTrue(edition.sections.contains { $0.id == "souvenirs" })
        XCTAssertTrue(edition.sections.contains { $0.id == "letters" })
        XCTAssertTrue(edition.sections.contains { $0.id == "images" })
        XCTAssertFalse(edition.sections.flatMap(\.items).contains { $0.id == "may" || $0.id == "july" })
    }

    func testMonthlyEditionCarriesScrapbookPagesInOwnSection() {
        let scrapbook = BookPage(
            id: "scrapbook",
            type: .plainPage,
            createdAt: date(day: 6, hour: 16),
            promptText: "Harbor Scrap",
            userInput: """
            A composed scrapbook page.

            Scraps bound here:
            Souvenir: The harbor fog came in.
            """,
            tags: ["pagewright", "scrapbook", "format:scrapPage", "source-page:souvenir"],
            sourceID: "pagewright",
            origin: .userAuthored,
            privacy: .privateLocal,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: "/tmp/harbor-scrap.png",
                    caption: "Harbor Scrap",
                    sourceID: "pagewright"
                )
            ]
        )
        let souvenir = BookPage(
            id: "souvenir",
            type: .souvenir,
            createdAt: date(day: 6, hour: 12),
            promptText: "Souvenir",
            userInput: "The harbor fog came in without a sound."
        )

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-06", date: date(day: 6, hour: 0), pages: [souvenir, scrapbook])],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let section = edition.sections.first { $0.id == "scrapbook-pages" }
        XCTAssertEqual(section?.title, "Scrapbook Pages")
        XCTAssertEqual(section?.items.map(\.id), ["scrapbook"])
        XCTAssertEqual(section?.items.first?.title, "Harbor Scrap")
        XCTAssertEqual(section?.items.first?.kind, .image)
        XCTAssertFalse(edition.sections.first { $0.id == "images" }?.items.contains { $0.id == "scrapbook" } ?? false)
        XCTAssertFalse(edition.sections.first { $0.id == "other-kept-pages" }?.items.contains { $0.id == "scrapbook" } ?? false)
    }

    func testMonthlyEditionCarriesBookMemorySpineFromBraids() {
        let braid = BraidPageDetails.annotated(
            BookPage(
                id: "braid-rain",
                type: .bookOfYou,
                createdAt: date(day: 3, hour: 22),
                promptText: "Book of You",
                userInput: """
                Rain At The Window

                The lamp waited by the window while rain tapped the glass.

                The Book kept the page: rain made the lamp brave.
                """,
                tags: ["braid"]
            ),
            context: .empty
        )
        let days = [
            BookDay(id: "2026-06-03", date: date(day: 3, hour: 0), pages: [
                BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 3, hour: 12), promptText: "Souvenir", userInput: "Rain at the kitchen window."),
                braid
            ])
        ]

        let edition = MonthlyEditionBuilder.edition(
            from: days,
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let spine = edition.sections.first { $0.id == "book-memory-spine" }
        XCTAssertEqual(spine?.title, "Book Memory Spine")
        XCTAssertTrue(spine?.items.contains { $0.id == "memory-spine-cover-story" && $0.body.contains("Rain At The Window") } == true)
        XCTAssertTrue(spine?.items.contains { $0.id == "memory-spine-refrain" && $0.body.contains("rain") } == true)
        XCTAssertTrue(spine?.items.contains { $0.id == "memory-spine-callbacks" && $0.body.contains("rain made the lamp brave") } == true)
        XCTAssertTrue(edition.memorySpinePromptLines.contains { $0.contains("Cover Story") && $0.contains("Rain At The Window") })
    }

    func testMonthlyEditionGroupsRepeatedWordSignals() {
        let pages = (1...3).map { dayNumber in
            BookPage(
                id: "harbor-\(dayNumber)",
                type: .souvenir,
                createdAt: date(day: dayNumber, hour: 12),
                promptText: "Souvenir",
                userInput: "The harbor lantern waited by the moss and the harbor light held."
            )
        }
        let days = pages.map { page in
            BookDay(id: "day-\(page.id)", date: page.createdAt, pages: [page])
        }

        let edition = MonthlyEditionBuilder.edition(
            from: days,
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let notices = edition.sections.first { $0.id == "the-book-notices" }
        let returning = notices?.items.first { $0.id == "returning-language" }
        XCTAssertNotNil(returning)
        XCTAssertTrue(returning?.body.contains("Certain words kept finding their way back") == true)
        XCTAssertFalse(returning?.body.contains("kept pages") == true)
        XCTAssertFalse(notices?.items.contains { $0.body.contains("The word ") } == true)
    }

    func testMonthlyEditionExcerptsLongSavedPages() {
        let longText = (1...30)
            .map { "Paragraph \($0) keeps describing the same welcome page in enough detail that the monthly binding should quote it selectively instead of pouring the whole source page onto the leaf." }
            .joined(separator: "\n\n")
        let page = BookPage(
            id: "welcome",
            type: .welcome,
            createdAt: date(day: 4, hour: 9),
            promptText: "Welcome",
            userInput: longText
        )

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: [page])],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let item = edition.sections.flatMap(\.items).first { $0.id == "welcome" }
        XCTAssertNotNil(item)
        XCTAssertLessThan(item?.body.count ?? longText.count, longText.count)
        XCTAssertTrue(item?.body.contains("[Excerpted for the monthly binding.]") == true)
    }

    func testMonthlyEditionCleansMarkdownBeforeBinding() {
        let page = BookPage(
            id: "faculty",
            type: .facultyResearch,
            createdAt: date(day: 4, hour: 9),
            promptText: "Research",
            userInput: """
            ## Research Note for Support Guild
            **Faculty:** Dr. Elowen Vellum
            ***
            **Field Finding:** The rain made the page useful.
            """
        )

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: [page])],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let item = edition.sections.flatMap(\.items).first { $0.id == "faculty" }
        XCTAssertNotNil(item)
        XCTAssertFalse(item?.body.contains("##") == true)
        XCTAssertFalse(item?.body.contains("**") == true)
        XCTAssertFalse(item?.body.contains("***") == true)
        XCTAssertTrue(item?.body.contains("Field Finding: The rain made the page useful.") == true)
    }

    func testMonthlyEditionOmitsDebugThemeExcerpts() {
        let theme = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Rain and Notes",
            motifs: ["rain", "notes"],
            line: "Rain and notes kept tapping.",
            strength: 40,
            evidencePageIDs: [],
            excerptLines: [
                "## Research Note for Support Guild **Faculty:** Dr.",
                "A pocket is a tiny private museum."
            ],
            discoveredAt: date(day: 30, hour: 12)
        )
        let page = BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 4, hour: 9), promptText: "One line", userInput: "A pocket is a tiny private museum.")

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: [page])],
            themes: [theme],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let themeItems = edition.sections.first { $0.id == "the-months-theme" }?.items ?? []
        XCTAssertFalse(themeItems.contains { $0.body.contains("Research Note for Support Guild") })
        XCTAssertTrue(themeItems.contains { $0.body.contains("A pocket is a tiny private museum.") })
    }

    func testThinMonthlyEditionNamesItselfAsFirstBinding() {
        let page = BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 4, hour: 9), promptText: "One line", userInput: "Rain on the window.")

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: [page])],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        XCTAssertTrue(edition.isThinBinding)
        // The thin-month greeting varies by month, so assert the promise rather
        // than one of its phrasings: a short chapter must announce that it is
        // early, and must not claim to have read the whole weather.
        let thinOpenings = ["first binding", "barely a month", "A short chapter"]
        XCTAssertTrue(
            thinOpenings.contains { edition.foreword.contains($0) },
            "thin binding should name itself as early: \(edition.foreword)"
        )
        let thinClosings = ["not calling this the whole sky yet", "Too early to call it the weather"]
        XCTAssertTrue(
            thinClosings.contains { edition.closing?.contains($0) == true },
            "thin closing should decline to generalise: \(edition.closing ?? "")"
        )
    }

    func testMonthlyEditionForewordAndClosingUseTheBooksOwnVoice() {
        let page = BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 4, hour: 9), promptText: "One line", userInput: "Rain on the window.")

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: [page])],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        // The exact sentences rotate per month by design; what must hold is that
        // the Book speaks in first person, states why it binds at all, and signs.
        XCTAssertTrue(edition.foreword.hasSuffix("- The Book"))
        XCTAssertTrue(edition.closing?.hasSuffix("- The Book") == true)
        XCTAssertTrue(edition.foreword.contains(" I "))
        XCTAssertTrue(edition.closing?.contains(" I ") == true)
    }

    func testMonthlyEditionKeepsBodyAndFuelOutOfDefaultBinding() {
        let fuel = BookPage(id: "fuel", type: .fuel, createdAt: date(day: 4, hour: 9), promptText: "Fuel", userInput: "Four coffees.")
        let body = BookPage(id: "body", type: .body, createdAt: date(day: 4, hour: 10), promptText: "Body", userInput: "A sensitive body note.")
        let souvenir = BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 4, hour: 11), promptText: "One line", userInput: "The cup steamed.")

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: [fuel, body, souvenir])],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar
        )

        let boundIDs = Set(edition.sections.flatMap(\.items).map(\.id))
        XCTAssertTrue(boundIDs.contains("souvenir"))
        XCTAssertFalse(boundIDs.contains("fuel"))
        XCTAssertFalse(boundIDs.contains("body"))
        let setAside = edition.sections.flatMap(\.items).first { $0.id == "kept-not-bound" }?.body
        XCTAssertTrue(setAside?.contains("one body page") == true)
        XCTAssertTrue(setAside?.contains("one fuel log") == true)
    }

    func testMonthlyEditionCanIncludePrivateWeatherSummaryWithoutRawLogs() {
        let pages = [
            BookPage(id: "fuel-1", type: .fuel, createdAt: date(day: 4, hour: 9), promptText: "Fuel", userInput: "Coffee and toast. Energy felt steady."),
            BookPage(id: "body-1", type: .body, createdAt: date(day: 4, hour: 10), promptText: "Body", userInput: "Inner weather was steady but tender."),
            BookPage(id: "fuel-2", type: .fuel, createdAt: date(day: 5, hour: 20), promptText: "Fuel", userInput: "Soup. Steady evening, tender appetite."),
            BookPage(id: "souvenir", type: .souvenir, createdAt: date(day: 5, hour: 21), promptText: "One line", userInput: "The bowl warmed both hands.")
        ]

        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-06-04", date: date(day: 4, hour: 0), pages: Array(pages.prefix(2))),
                   BookDay(id: "2026-06-05", date: date(day: 5, hour: 0), pages: Array(pages.suffix(2)))],
            readerName: "bj",
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 30, hour: 23),
            generatedAt: date(day: 30, hour: 23),
            calendar: calendar,
            includePrivateWeatherSummary: true
        )

        let section = edition.sections.first { $0.id == "fuel-and-inner-weather" }
        XCTAssertEqual(section?.title, "Fuel & Inner Weather")
        let text = section?.items.map(\.body).joined(separator: "\n") ?? ""
        XCTAssertTrue(text.contains("pattern-weather, not diagnosis"))
        XCTAssertTrue(text.contains("fuel and inner weather were both kept"))
        XCTAssertTrue(text.contains("steady"))
        XCTAssertFalse(text.contains("Coffee and toast"))
        XCTAssertFalse(text.contains("Soup."))
        let boundIDs = Set(edition.sections.flatMap(\.items).map(\.id))
        XCTAssertFalse(boundIDs.contains("fuel-1"))
        XCTAssertFalse(boundIDs.contains("body-1"))
        XCTAssertTrue(boundIDs.contains("souvenir"))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func day(id: String, day: Int, pageIDs: [String]) -> BookDay {
        BookDay(
            id: id,
            date: date(day: day, hour: 9),
            pages: pageIDs.enumerated().map { offset, id in
                BookPage(
                    id: id,
                    type: .souvenir,
                    createdAt: date(day: day, hour: 12 - offset),
                    promptText: "Prompt \(id)",
                    userInput: "Page \(id)",
                    tags: ["export"],
                    sourceID: "one-sentence-souvenir"
                )
            }
        )
    }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: day,
            hour: hour
        )) ?? Date()
    }
}
