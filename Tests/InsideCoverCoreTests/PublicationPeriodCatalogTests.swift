import XCTest
@testable import InsideCoverCore

final class PublicationPeriodCatalogTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    /// Each page carries its own line unless the caller says otherwise.
    ///
    /// `EditionCurator` deliberately collapses the same text bound twice, so a
    /// fixture that gave every page the identical body was handing the counting
    /// tests one piece of material and asking them to find three.
    private func page(_ id: String, _ year: Int, _ month: Int, _ day: Int, text: String? = nil) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: date(year, month, day),
            promptText: "Souvenir",
            userInput: text ?? "Kept ink, and the particular light of \(id).",
            origin: .userAuthored
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages, by: { BookDay.id(for: $0.createdAt, calendar: calendar) })
            .map { id, pages in
                BookDay(
                    id: id,
                    date: calendar.startOfDay(for: pages[0].createdAt),
                    pages: pages
                )
            }
            .sorted { $0.date < $1.date }
    }

    func testReaderWeeksRemainBindableAfterInvitationFreshnessEnds() throws {
        let archive = days([
            page("w1-a", 2026, 7, 1),
            page("w1-b", 2026, 7, 4),
            page("w2-a", 2026, 7, 9)
        ])

        let candidates = PublicationPeriodCatalog.readerWeeks(
            days: archive,
            now: date(2026, 7, 20),
            calendar: calendar
        )

        XCTAssertEqual(candidates.map { $0.period.ordinal }, [3, 2, 1])
        XCTAssertEqual(candidates[0].materialStatus, .gathering)
        XCTAssertFalse(candidates[0].isBindable)

        let quietSecondWeek = try XCTUnwrap(candidates.first { $0.period.ordinal == 2 })
        XCTAssertEqual(quietSecondWeek.materialStatus, .quiet)
        XCTAssertTrue(quietSecondWeek.isBindable, "one honest page is permission enough when the reader asks")
        XCTAssertFalse(quietSecondWeek.isRecommended)

        let firstWeek = try XCTUnwrap(candidates.first { $0.period.ordinal == 1 })
        XCTAssertEqual(firstWeek.materialStatus, .ready)
        XCTAssertTrue(firstWeek.isBindable, "eligibility does not expire with the four-day invitation")
    }

    func testCalendarMonthsKeepGatheringSeparateFromCompletedChoices() throws {
        let archive = days([
            page("jun-a", 2026, 6, 2),
            page("jun-b", 2026, 6, 9),
            page("jun-c", 2026, 6, 21),
            page("jul-a", 2026, 7, 7),
            page("aug-a", 2026, 8, 3)
        ])

        let candidates = PublicationPeriodCatalog.calendarMonths(
            days: archive,
            now: date(2026, 8, 23),
            calendar: calendar
        )

        XCTAssertEqual(candidates.map { $0.period.id.startDayID }, ["2026-08-01", "2026-07-01", "2026-06-01"])
        XCTAssertEqual(candidates[0].materialStatus, .gathering)
        XCTAssertFalse(candidates[0].isBindable)

        let july = try XCTUnwrap(candidates.first { $0.period.id.startDayID == "2026-07-01" })
        XCTAssertEqual(july.materialStatus, .quiet)
        XCTAssertTrue(july.isBindable)

        let june = try XCTUnwrap(candidates.first { $0.period.id.startDayID == "2026-06-01" })
        XCTAssertEqual(june.materialStatus, .ready)
        XCTAssertTrue(june.isRecommended)
    }

    func testCalendarSeasonsAreFixedNonOverlappingBlocks() {
        let archive = days([page("feb", 2026, 2, 10)])
        let candidates = PublicationPeriodCatalog.calendarSeasons(
            days: archive,
            now: date(2026, 8, 23),
            calendar: calendar
        )

        XCTAssertEqual(candidates.map { $0.period.id.startDayID }, ["2026-07-01", "2026-04-01", "2026-01-01"])
        XCTAssertEqual(candidates.map { $0.period.id.endDayID }, ["2026-09-30", "2026-06-30", "2026-03-31"])
        XCTAssertEqual(candidates.map(\.materialStatus), [.gathering, .empty, .ready])
    }

    func testCalendarAnnualRequiresTheYearToClose() throws {
        let archive = days([
            page("old", 2025, 9, 12),
            page("current", 2026, 2, 5)
        ])
        let candidates = PublicationPeriodCatalog.calendarYears(
            days: archive,
            now: date(2026, 8, 23),
            calendar: calendar
        )

        XCTAssertEqual(candidates.map { $0.period.id.startDayID }, ["2026-01-01", "2025-01-01"])
        XCTAssertEqual(candidates[0].materialStatus, .gathering)
        XCTAssertFalse(candidates[0].isBindable)
        XCTAssertTrue(try XCTUnwrap(candidates.last).isBindable)
    }

    func testBoundArtifactsAndBookOfYouDoNotCreatePublicationPeriods() {
        let braid = BookPage(
            id: "braid",
            type: .bookOfYou,
            createdAt: date(2026, 7, 7),
            promptText: "The Book of You",
            userInput: "The Book bound a night.",
            usedInBookOfYou: true,
            origin: .generated
        )
        let weeklyArtifact = BookPage(
            id: "artifact",
            type: .bindery,
            createdAt: date(2026, 7, 8),
            promptText: "Issue",
            userInput: "Already bound",
            sourceID: "weekly-issue",
            origin: .generated
        )
        let archive = days([braid, weeklyArtifact])

        XCTAssertTrue(PublicationPeriodCatalog.readerWeeks(
            days: archive,
            now: date(2026, 8, 23),
            calendar: calendar
        ).isEmpty)
        XCTAssertTrue(PublicationPeriodCatalog.calendarMonths(
            days: archive,
            now: date(2026, 8, 23),
            calendar: calendar
        ).isEmpty)
    }

    func testBoundYearAnnualHasItsOwnTwelveMonthIdentity() throws {
        let membership = BoundYearMembership(
            cadence: .annual,
            status: .active,
            startedAt: date(2026, 2, 14),
            paidThrough: date(2027, 2, 14),
            endedAt: nil
        )
        let archive = days([page("member", 2026, 2, 20)])
        let candidates = PublicationPeriodCatalog.boundYearVolumes(
            membership: membership,
            days: archive,
            now: date(2027, 2, 15),
            calendar: calendar
        )

        let annual = try XCTUnwrap(candidates.first { $0.period.recipe == .boundYearAnnual })
        XCTAssertEqual(annual.period.id.startDayID, "2026-02-01")
        XCTAssertEqual(annual.period.id.endDayID, "2027-01-31")
        XCTAssertEqual(annual.period.ordinal, 4)
        XCTAssertTrue(annual.isBindable)
    }

    func testBoundRevisionCountDoesNotChangeEligibility() throws {
        let archive = days([page("july", 2026, 7, 7)])
        let unbound = PublicationPeriodCatalog.calendarMonths(
            days: archive,
            now: date(2026, 8, 23),
            calendar: calendar
        )
        let july = try XCTUnwrap(unbound.first { $0.period.id.startDayID == "2026-07-01" })

        let rebound = PublicationPeriodCatalog.calendarMonths(
            days: archive,
            boundRevisionCounts: [july.id: 2],
            now: date(2026, 8, 23),
            calendar: calendar
        )
        let sameJuly = try XCTUnwrap(rebound.first { $0.id == july.id })

        XCTAssertEqual(sameJuly.boundRevisionCount, 2)
        XCTAssertTrue(sameJuly.hasBoundEdition)
        XCTAssertEqual(sameJuly.materialStatus, july.materialStatus)
        XCTAssertTrue(sameJuly.isBindable)
    }

    func testFrozenReaderWeekEpochSurvivesAnOlderImport() throws {
        let original = days([page("first", 2026, 7, 10)])
        let epoch = try XCTUnwrap(BookPublicationEpoch.seeded(
            from: original,
            now: date(2026, 7, 10),
            calendar: calendar
        ))
        XCTAssertEqual(epoch.readerWeekAnchorDayID, "2026-07-10")

        let afterImport = original + days([page("imported-old", 2026, 6, 1)])
        let frozen = PublicationPeriodCatalog.readerWeeks(
            days: afterImport,
            frozenAnchor: epoch.readerWeekAnchor(calendar: calendar),
            now: date(2026, 7, 25),
            calendar: calendar
        )
        let issueOne = try XCTUnwrap(frozen.first { $0.period.ordinal == 1 })

        XCTAssertEqual(issueOne.period.id.startDayID, "2026-07-10")
        XCTAssertEqual(epoch.readerWeekAnchorDayID, "2026-07-10")
    }
}
