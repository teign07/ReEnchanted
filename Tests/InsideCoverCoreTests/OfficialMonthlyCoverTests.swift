import XCTest
@testable import InsideCoverCore

final class OfficialMonthlyCoverTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 15))!
    }

    func testKnown2026MonthsWearTheirOfficialCovers() {
        XCTAssertEqual(
            PublicationCoverCatalogue.officialMonthlyCovers(
                for: date(year: 2026, month: 8),
                calendar: calendar
            ).map(\.id),
            ["labyrinth-of-stories"]
        )
        XCTAssertEqual(
            PublicationCoverCatalogue.officialMonthlyCovers(
                for: date(year: 2026, month: 9),
                calendar: calendar
            ).map(\.id),
            ["dictionary-rebellion-september-2026"]
        )
        XCTAssertEqual(
            PublicationCoverCatalogue.officialMonthlyCovers(
                for: date(year: 2026, month: 10),
                calendar: calendar
            ).map(\.id),
            ["count-unbound-october-2026"]
        )
        XCTAssertEqual(
            PublicationCoverCatalogue.officialMonthlyCovers(
                for: date(year: 2027, month: 9),
                calendar: calendar
            ).map(\.id),
            ["dictionary-rebellion-september-2027"]
        )
        XCTAssertTrue(
            PublicationCoverCatalogue.dictionaryRebellion.artworkIncludesCoverMatter == true,
            "September's imported cover already owns its lettering."
        )
        XCTAssertFalse(
            PublicationCoverCatalogue.countUnbound.artworkIncludesCoverMatter == true,
            "October's landing artwork still needs the Book to typeset its title and date."
        )
        XCTAssertEqual(
            PublicationCoverCatalogue.rotating.count,
            4,
            "Official monthly faces must not replace the four optional Bindery plates."
        )
    }

    func testAReaderCanChooseAmongSeveralOfficialFaces() {
        let first = PublicationOfficialMonthlyCover(
            year: 2027,
            month: 1,
            plate: .init(id: "first", title: "First Face", assetName: "First"),
            subtitle: "First"
        )
        let second = PublicationOfficialMonthlyCover(
            year: 2027,
            month: 1,
            plate: .init(id: "second", title: "Second Face", assetName: "Second"),
            subtitle: "Second"
        )

        XCTAssertEqual(
            PublicationCoverCatalogue.resolveOfficialMonthlyCover(
                in: [first, second],
                preferredID: "second"
            )?.id,
            "second"
        )
        XCTAssertEqual(
            PublicationCoverCatalogue.resolveOfficialMonthlyCover(
                in: [first, second],
                preferredID: "retired"
            )?.id,
            "first",
            "A missing or retired choice must fall back to the month's first official cover."
        )
    }

    func testCoverChoiceIsStoredOnlyForItsOwnMonth() {
        let september = date(year: 2026, month: 9)
        let october = date(year: 2026, month: 10)
        var ledger = PublicationMonthlyCoverSelectionLedger()

        ledger.select(
            coverID: "dictionary-rebellion-september-2026",
            for: september,
            calendar: calendar
        )

        XCTAssertEqual(
            ledger.preferredCoverID(for: september, calendar: calendar),
            "dictionary-rebellion-september-2026"
        )
        XCTAssertNil(ledger.preferredCoverID(for: october, calendar: calendar))
        XCTAssertEqual(
            PublicationMonthlyCoverSelectionLedger.decode(ledger.encoded()),
            ledger
        )
    }
}
