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
