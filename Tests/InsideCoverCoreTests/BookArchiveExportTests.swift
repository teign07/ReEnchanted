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
