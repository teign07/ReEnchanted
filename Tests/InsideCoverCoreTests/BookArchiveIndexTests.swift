import XCTest
@testable import InsideCoverCore

final class BookArchiveIndexTests: XCTestCase {
    func testPagesFilterByTypeSourceTagPrivacyAndDateWindow() {
        let days = archiveDays()
        let results = BookArchiveIndex.pages(
            in: days,
            matching: BookPageQuery(
                type: .wonderCompass,
                sourceID: "wonder-compass",
                tag: "Rest",
                privacy: .publicReference,
                startDate: date(day: 2, hour: 0),
                endDate: date(day: 3, hour: 0),
                limit: 10
            )
        )

        XCTAssertEqual(results.map(\.id), ["wonder-2"])
    }

    func testPagesSortNewestFirstAndHonorLimit() {
        let results = BookArchiveIndex.pages(
            in: archiveDays(),
            matching: BookPageQuery(sourceID: "one-sentence-souvenir", limit: 2)
        )

        XCTAssertEqual(results.map(\.id), ["souvenir-3", "souvenir-2"])
    }

    func testResurfacingCandidatesReturnMeaningfulOlderPagesNewestFirst() {
        let results = BookArchiveIndex.resurfacingCandidates(
            in: archiveDays(),
            before: date(day: 3, hour: 12),
            calendar: calendar,
            limit: 10
        )

        XCTAssertEqual(results.map(\.id), ["wonder-2", "souvenir-2", "souvenir-1"])
    }

    func testLimitZeroReturnsNoPages() {
        let results = BookArchiveIndex.pages(
            in: archiveDays(),
            matching: BookPageQuery(limit: 0)
        )

        XCTAssertTrue(results.isEmpty)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func archiveDays() -> [BookDay] {
        [
            BookDay(
                id: "2026-06-01",
                date: date(day: 1, hour: 0),
                pages: [
                    page(
                        id: "souvenir-1",
                        type: .souvenir,
                        sourceID: "one-sentence-souvenir",
                        createdAt: date(day: 1, hour: 8),
                        tags: ["morning"],
                        usedInBookOfYou: true
                    ),
                    page(
                        id: "body-1",
                        type: .body,
                        sourceID: "body-page",
                        createdAt: date(day: 1, hour: 9),
                        tags: ["low"],
                        privacy: .localSensitive
                    )
                ]
            ),
            BookDay(
                id: "2026-06-02",
                date: date(day: 2, hour: 0),
                pages: [
                    page(
                        id: "souvenir-2",
                        type: .souvenir,
                        sourceID: "one-sentence-souvenir",
                        createdAt: date(day: 2, hour: 20),
                        tags: ["evening"],
                        usedInBookOfYou: true
                    ),
                    page(
                        id: "wonder-2",
                        type: .wonderCompass,
                        sourceID: "wonder-compass",
                        createdAt: date(day: 2, hour: 21),
                        tags: ["rest", "practice"],
                        privacy: .publicReference
                    )
                ]
            ),
            BookDay(
                id: "2026-06-03",
                date: date(day: 3, hour: 0),
                pages: [
                    page(
                        id: "souvenir-3",
                        type: .souvenir,
                        sourceID: "one-sentence-souvenir",
                        createdAt: date(day: 3, hour: 10),
                        tags: ["today"],
                        usedInBookOfYou: true
                    ),
                    page(
                        id: "lore-3",
                        type: .lore,
                        sourceID: "labyrinth-lore",
                        createdAt: date(day: 3, hour: 11),
                        tags: ["story"],
                        privacy: .publicReference
                    )
                ]
            )
        ]
    }

    private func page(
        id: String,
        type: BookPageType,
        sourceID: String,
        createdAt: Date,
        tags: [String],
        usedInBookOfYou: Bool = false,
        privacy: BookPagePrivacy = .privateLocal
    ) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: createdAt,
            promptText: "Prompt",
            userInput: "A stored page.",
            tags: tags,
            usedInBookOfYou: usedInBookOfYou,
            sourceID: sourceID,
            privacy: privacy
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
