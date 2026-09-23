import XCTest
@testable import InsideCoverCore

final class EditionPlayContentTests: StandingOrderGatedTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func page(_ id: String, _ when: Date, phase: String? = nil) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: when,
            promptText: "One true sentence",
            userInput: "The ink got out.",
            tags: ["event:dictionary-rebellion"] + (phase.map { ["event-phase:\($0)"] } ?? [])
        )
    }

    private func period(
        _ recipe: PublicationPeriodRecipe,
        start: Date,
        end: Date,
        ordinal: Int? = nil
    ) -> PublicationPeriod {
        PublicationPeriodCatalog.period(
            recipe: recipe,
            startDate: start,
            endDate: end,
            ordinal: ordinal,
            calendar: calendar
        )
    }

    func testSeptemberMonthChoosesTwoDifferentForms() {
        let month = period(.calendarMonth, start: date(2026, 9, 1), end: date(2026, 10, 1))
        let leaves = EditionPlayCatalogue.boundLeaves(
            for: month,
            cadence: .monthly,
            pages: [page("assembly", date(2026, 9, 18), phase: "assembly")],
            ownedPackIDs: ["dictionary-rebellion"],
            calendar: calendar
        )

        XCTAssertEqual(leaves.count, 2)
        XCTAssertEqual(Set(leaves.map { $0.definition.form }).count, 2)
        XCTAssertTrue(leaves.allSatisfy { $0.definition.cadence == .monthly })
        XCTAssertEqual(
            leaves.map { $0.definition.templateSlot.bindingOrder },
            leaves.map { $0.definition.templateSlot.bindingOrder }.sorted()
        )
    }

    func testLockedPackContributesNoLeaves() {
        let month = period(.calendarMonth, start: date(2026, 9, 1), end: date(2026, 10, 1))
        XCTAssertTrue(EditionPlayCatalogue.boundLeaves(
            for: month,
            cadence: .monthly,
            pages: [],
            ownedPackIDs: [],
            calendar: calendar
        ).isEmpty)
    }

    func testMonthlyPoolPrefersAnOutcomeTheReaderActuallyReached() {
        let month = period(.calendarMonth, start: date(2026, 9, 1), end: date(2026, 10, 1))
        var outcomePage = page("ally", date(2026, 9, 22))
        outcomePage.tags.append("event-outcome:lexical-ally")

        let leaves = EditionPlayCatalogue.boundLeaves(
            for: month,
            cadence: .monthly,
            pages: [outcomePage],
            ownedPackIDs: ["dictionary-rebellion"],
            calendar: calendar
        )

        XCTAssertTrue(leaves.contains { $0.id == "amendment-to-the-seventeenth-edition" })
    }

    func testColoringPageBelongsOnlyToFirstEligibleOverlappingReaderWeek() {
        let second = period(
            .readerWeek,
            start: date(2026, 9, 8),
            end: date(2026, 9, 15),
            ordinal: 2
        )
        let third = period(
            .readerWeek,
            start: date(2026, 9, 15),
            end: date(2026, 9, 22),
            ordinal: 3
        )
        let pages = [
            page("first", date(2026, 9, 9)),
            page("second", date(2026, 9, 16))
        ]

        let premiere = EditionPlayCatalogue.boundLeaves(
            for: second,
            cadence: .weekly,
            pages: pages,
            ownedPackIDs: ["dictionary-rebellion"],
            calendar: calendar
        )
        let repeatAttempt = EditionPlayCatalogue.boundLeaves(
            for: third,
            cadence: .weekly,
            pages: pages,
            ownedPackIDs: ["dictionary-rebellion"],
            calendar: calendar
        )

        XCTAssertEqual(premiere.map(\.id), ["dictionary-rebellion-coloring-page"])
        XCTAssertEqual(repeatAttempt.count, 1)
        XCTAssertNotEqual(repeatAttempt.first?.id, "dictionary-rebellion-coloring-page")
        XCTAssertTrue(repeatAttempt.first?.contentPackID == "core-weekly-press-drawer")
    }

    func testSeptemberReaderWeeksTurnToADifferentWorktableLeaf() {
        let starts = [
            date(2026, 8, 31),
            date(2026, 9, 7),
            date(2026, 9, 14),
            date(2026, 9, 21)
        ]
        let ids = starts.enumerated().compactMap { offset, start -> String? in
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return EditionPlayCatalogue.boundLeaves(
                for: period(.readerWeek, start: start, end: end, ordinal: offset + 1),
                cadence: .weekly,
                pages: [],
                ownedPackIDs: [],
                calendar: calendar
            ).first?.id
        }

        XCTAssertEqual(ids.count, 4)
        XCTAssertEqual(Set(ids).count, 4)
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("september-") })
    }

    func testEveryOrdinaryReaderWeekGetsExactlyOnePrivateTwoPageLeaf() {
        let week = period(
            .readerWeek,
            start: date(2026, 11, 2),
            end: date(2026, 11, 9),
            ordinal: 12
        )
        let leaves = EditionPlayCatalogue.boundLeaves(
            for: week,
            cadence: .weekly,
            pages: [],
            ownedPackIDs: [],
            calendar: calendar
        )

        XCTAssertEqual(leaves.count, 1)
        XCTAssertEqual(leaves[0].definition.footprint.pageCount, 2)
        XCTAssertTrue(leaves[0].definition.footprint.hasBlankReverse)
        XCTAssertTrue(leaves[0].selectionReason.contains("changes with Reader Week"))
    }

    func testSeasonAndYearReceiveTheirOwnScaleOfPlay() {
        let season = period(.calendarSeason, start: date(2026, 7, 1), end: date(2026, 10, 1))
        let year = period(.calendarYear, start: date(2026, 1, 1), end: date(2027, 1, 1))
        let owned: Set<String> = ["dictionary-rebellion"]

        let seasonLeaves = EditionPlayCatalogue.boundLeaves(
            for: season,
            cadence: .seasonal,
            pages: [],
            ownedPackIDs: owned,
            calendar: calendar
        )
        XCTAssertEqual(seasonLeaves.map(\.id), ["atlas-of-one-escaped-word"])
        XCTAssertTrue(seasonLeaves[0].definition.body?.contains("JULY  ·  AUGUST  ·  SEPTEMBER") == true)
        XCTAssertEqual(EditionPlayCatalogue.boundLeaves(
            for: year,
            cadence: .annual,
            pages: [],
            ownedPackIDs: owned,
            calendar: calendar
        ).map(\.id), ["the-word-the-year-changed"])
    }

    func testFootprintsReservePaperRatherThanAppState() {
        XCTAssertEqual(EditionPlayFootprint.singlePage.pageCount, 1)
        XCTAssertEqual(EditionPlayFootprint.rectoWithBlankReverse.pageCount, 2)
        XCTAssertTrue(EditionPlayFootprint.rectoWithBlankReverse.hasBlankReverse)
        XCTAssertEqual(EditionPlayFootprint.facingSpread.pageCount, 2)
        XCTAssertTrue(EditionPlayFootprint.facingSpread.isFacingSpread)
    }

    func testBoundLeafSnapshotRoundTripsWithoutCatalogueLookup() throws {
        let month = period(.calendarMonth, start: date(2026, 9, 1), end: date(2026, 10, 1))
        let leaves = EditionPlayCatalogue.boundLeaves(
            for: month,
            cadence: .monthly,
            pages: [],
            ownedPackIDs: ["dictionary-rebellion"],
            calendar: calendar
        )
        let data = try JSONEncoder().encode(leaves)
        XCTAssertEqual(try JSONDecoder().decode([BoundEditionPlayLeaf].self, from: data), leaves)
    }
}
