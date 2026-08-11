import XCTest
@testable import InsideCoverCore

/// The Bound Year: three seasonal softcovers and the annual hardcover, billed
/// monthly or annually.
///
/// The rule these tests exist to protect is the one about **debt in either
/// direction**. An annual member paid the year up front, so cancelling in month
/// seven cannot claw back a volume they already bought. A monthly member earns
/// volumes as they pay, so a season that closed after the money stopped does
/// not ship, and they are owed nothing for it, because they never paid for it.
/// Both halves matter: the same principle that removed the skip button.
final class BoundYearMembershipTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? Date()
    }

    private func membership(
        _ cadence: BoundYearMembership.Cadence,
        paidThrough: Date,
        status: BoundYearMembership.Status = .active
    ) -> BoundYearMembership {
        BoundYearMembership(
            cadence: cadence,
            status: status,
            startedAt: date(2026, 2, 14),
            paidThrough: paidThrough
        )
    }

    // MARK: Seasons run on the membership's clock

    /// Anchored to when they joined, not to the calendar quarter: the same way
    /// the weekly issue is anchored to the reader's first kept page. A February
    /// joiner should not get a two-week stub as their first season.
    func testSeasonsAreCountedFromTheMembershipStart() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let first = BoundYearCycle.seasonWindow(0, membership: member, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: first?.start ?? Date()), 2)
        let second = BoundYearCycle.seasonWindow(1, membership: member, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: second?.start ?? Date()), 5)
    }

    func testSeasonsDoNotOverlap() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let first = BoundYearCycle.seasonWindow(0, membership: member, calendar: calendar)
        let second = BoundYearCycle.seasonWindow(1, membership: member, calendar: calendar)
        XCTAssertLessThan(first?.end ?? Date.distantFuture, second?.start ?? Date.distantPast)
    }

    /// The year lands on the best object rather than opening with it.
    func testTheFourthVolumeOfEachYearIsTheHardcover() {
        XCTAssertFalse(BoundYearCycle.isAnnualVolume(0))
        XCTAssertFalse(BoundYearCycle.isAnnualVolume(2))
        XCTAssertTrue(BoundYearCycle.isAnnualVolume(3))
        XCTAssertTrue(BoundYearCycle.isAnnualVolume(7), "And again the following year.")
        XCTAssertEqual(BoundYearCycle.variantID(forSeasonIndex: 0), "perfect-bound-softcover-6x9")
        XCTAssertEqual(BoundYearCycle.variantID(forSeasonIndex: 3), "cloth-foil-hardcover-6x9")
    }

    // MARK: Annual: paid up front, owed regardless

    func testAnAnnualMemberIsOwedEveryVolumeInTheYearTheyBought() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        for index in 0..<4 {
            XCTAssertTrue(
                BoundYearCycle.seasonIsEarned(index, membership: member, calendar: calendar),
                "Season \(index) was paid for on day one."
            )
        }
    }

    /// Cancelling in month seven does not claw back a book they already bought.
    func testCancellingAnAnnualDoesNotUnbuyTheRestOfTheYear() {
        var member = membership(.annual, paidThrough: date(2027, 2, 14))
        member.status = .cancelled
        member.endedAt = date(2026, 9, 1)
        XCTAssertTrue(BoundYearCycle.seasonIsEarned(3, membership: member, calendar: calendar))
    }

    // MARK: Monthly: earned as they pay, and never a debt

    func testAMonthlyMemberEarnsASeasonOnlyOnceItsMonthsArePaid() {
        // Paid through mid-April: the first season runs Feb–Apr and has not
        // finished being paid for.
        let partway = membership(.monthly, paidThrough: date(2026, 4, 15))
        XCTAssertFalse(BoundYearCycle.seasonIsEarned(0, membership: partway, calendar: calendar))

        let paidUp = membership(.monthly, paidThrough: date(2026, 5, 20))
        XCTAssertTrue(BoundYearCycle.seasonIsEarned(0, membership: paidUp, calendar: calendar))
    }

    /// The other half of the no-debt rule: a season they did not pay for is not
    /// owed to them, so there is nothing to credit and nothing to argue about.
    func testALapsedMonthlyMemberIsOwedNothingFurther() {
        var member = membership(.monthly, paidThrough: date(2026, 5, 20))
        member.status = .lapsed
        XCTAssertTrue(BoundYearCycle.seasonIsEarned(0, membership: member, calendar: calendar),
                      "They paid for the first season and it is theirs.")
        XCTAssertFalse(BoundYearCycle.seasonIsEarned(1, membership: member, calendar: calendar),
                       "They never paid for the second, so no book and no credit.")
    }

    func testAMemberInGracePeriodIsStillAMember() {
        var member = membership(.monthly, paidThrough: date(2026, 5, 20))
        member.status = .inGracePeriod
        XCTAssertTrue(member.isCurrent)
        member.status = .lapsed
        XCTAssertFalse(member.isCurrent)
    }

    // MARK: What is due

    func testTheDueSeasonIsClosedPaidForAndUnsent() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let due = BoundYearCycle.seasonDue(
            membership: member,
            alreadyDispatchedKeys: [],
            now: date(2026, 5, 20),
            calendar: calendar
        )
        XCTAssertEqual(due?.index, 0, "February to April has closed; May has not.")
    }

    func testASeasonAlreadySentIsNotDueAgain() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let first = BoundYearCycle.seasonKey(0, membership: member, calendar: calendar)
        let due = BoundYearCycle.seasonDue(
            membership: member,
            alreadyDispatchedKeys: [first],
            now: date(2026, 5, 20),
            calendar: calendar
        )
        XCTAssertNil(due, "One dispatch per season, ever.")
    }

    func testNothingIsDueBeforeTheFirstSeasonCloses() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        XCTAssertNil(
            BoundYearCycle.seasonDue(
                membership: member,
                alreadyDispatchedKeys: [],
                now: date(2026, 3, 20),
                calendar: calendar
            )
        )
    }

    func testAnUnpaidSeasonIsNeverDueEvenAfterItCloses() {
        let lapsed = membership(.monthly, paidThrough: date(2026, 3, 1), status: .lapsed)
        XCTAssertNil(
            BoundYearCycle.seasonDue(
                membership: lapsed,
                alreadyDispatchedKeys: [],
                now: date(2026, 8, 1),
                calendar: calendar
            )
        )
    }

    func testSeasonKeysAreStableAndDistinct() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let keys = (0..<4).map { BoundYearCycle.seasonKey($0, membership: member, calendar: calendar) }
        XCTAssertEqual(Set(keys).count, 4)
        XCTAssertEqual(keys[0], BoundYearCycle.seasonKey(0, membership: member, calendar: calendar))
    }

    func testBothCadencesExistAndDifferInChargeCount() {
        XCTAssertEqual(BoundYearMembership.Cadence.monthly.chargesPerYear, 12)
        XCTAssertEqual(BoundYearMembership.Cadence.annual.chargesPerYear, 1)
        XCTAssertEqual(BoundYearMembership.Cadence.allCases.count, 2)
    }

    // MARK: The cycle, end to end

    private func seasonDays(from start: Date, months: Int = 3) -> [BookDay] {
        (0..<(months * 30)).compactMap { offset -> BookDay? in
            guard offset % 3 == 0,
                  let d = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayID = BookDay.id(for: d, calendar: calendar)
            return BookDay(
                id: dayID,
                date: calendar.startOfDay(for: d),
                pages: [
                    BookPage(id: "s-\(dayID)", type: .souvenir, createdAt: d,
                             promptText: "One true sentence", userInput: "The harbour kept \(dayID).")
                ]
            )
        }
    }

    func testAClosedPaidSeasonOpensADispatch() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let dispatch = BoundYearCycle.openDueDispatch(
            membership: member,
            days: seasonDays(from: date(2026, 2, 14)),
            existing: [],
            readerName: "Reader",
            now: date(2026, 5, 20),
            calendar: calendar
        )
        XCTAssertNotNil(dispatch)
        XCTAssertEqual(dispatch?.variantID, "perfect-bound-softcover-6x9")
        XCTAssertFalse(dispatch?.hasPosted ?? true)
    }

    func testAStoppedMonthlyMemberStillReceivesASeasonAlreadyEarned() {
        let member = membership(
            .monthly,
            paidThrough: date(2026, 5, 14),
            status: .cancelled
        )
        let dispatch = BoundYearCycle.openDueDispatch(
            membership: member,
            days: seasonDays(from: date(2026, 2, 14)),
            existing: [],
            readerName: "Reader",
            now: date(2026, 5, 20),
            calendar: calendar
        )
        XCTAssertNotNil(dispatch, "Stopping future charges must not swallow a fully paid season.")
    }

    func testTheSameSeasonNeverOpensTwice() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        let days = seasonDays(from: date(2026, 2, 14))
        let first = BoundYearCycle.openDueDispatch(
            membership: member, days: days, existing: [],
            readerName: "Reader", now: date(2026, 5, 20), calendar: calendar
        )
        let again = BoundYearCycle.openDueDispatch(
            membership: member, days: days, existing: [first!],
            readerName: "Reader", now: date(2026, 5, 20), calendar: calendar
        )
        XCTAssertNil(again)
    }

    /// Better to send nothing than to post someone a bound volume of three
    /// empty months.
    func testASeasonWithNothingInItIsNotABook() {
        let member = membership(.annual, paidThrough: date(2027, 2, 14))
        XCTAssertNil(
            BoundYearCycle.openDueDispatch(
                membership: member, days: [], existing: [],
                readerName: "Reader", now: date(2026, 5, 20), calendar: calendar
            )
        )
    }

    func testANonMemberIsNeverSentAnything() {
        XCTAssertNil(
            BoundYearCycle.openDueDispatch(
                membership: nil,
                days: seasonDays(from: date(2026, 2, 14)),
                existing: [],
                readerName: "Reader", now: date(2026, 5, 20), calendar: calendar
            )
        )
    }

    /// A lapsed monthly member gets nothing further, and is owed nothing.
    func testALapsedMonthlyMemberOpensNoFurtherDispatch() {
        let lapsed = membership(.monthly, paidThrough: date(2026, 3, 1), status: .lapsed)
        XCTAssertNil(
            BoundYearCycle.openDueDispatch(
                membership: lapsed,
                days: seasonDays(from: date(2026, 2, 14)),
                existing: [],
                readerName: "Reader", now: date(2026, 8, 1), calendar: calendar
            )
        )
    }

    /// The year lands on the hardcover.
    func testTheFourthDispatchOfAYearIsTheHardcover() {
        let member = membership(.annual, paidThrough: date(2028, 2, 14))
        let dispatched = (0..<3).map { BoundYearCycle.seasonKey($0, membership: member, calendar: calendar) }
        let fourth = BoundYearCycle.openDueDispatch(
            membership: member,
            days: seasonDays(from: date(2026, 2, 14), months: 14),
            existing: dispatched.map {
                SeasonalDispatch(id: $0, seasonKey: $0, coverLine: "x", boundAt: date(2026, 5, 1),
                                 shipsAt: nil, chapterCount: 3, pageCount: 10,
                                 variantID: "perfect-bound-softcover-6x9", postedAt: date(2026, 5, 8))
            },
            readerName: "Reader",
            now: date(2027, 3, 1),
            calendar: calendar
        )
        XCTAssertEqual(fourth?.variantID, "cloth-foil-hardcover-6x9")
        XCTAssertEqual(fourth?.chapterCount, 12)
        XCTAssertEqual(fourth?.publicationKind, .annual)
        XCTAssertTrue(fourth?.isAnnualVolume ?? false)
    }

    /// A quiet membership year may have ink in only two months. The binding is
    /// still the fourth, annual hardcover; chapter count is content, not press
    /// identity.
    func testASparseFourthDispatchStillRemainsTheAnnualHardcover() {
        let member = membership(.annual, paidThrough: date(2028, 2, 14))
        let dispatched = (0..<3).map { BoundYearCycle.seasonKey($0, membership: member, calendar: calendar) }
        let sparseDays = seasonDays(from: date(2026, 2, 14), months: 2)
        let fourth = BoundYearCycle.openDueDispatch(
            membership: member,
            days: sparseDays,
            existing: dispatched.map {
                SeasonalDispatch(id: $0, seasonKey: $0, coverLine: "x", boundAt: date(2026, 5, 1),
                                 shipsAt: nil, chapterCount: 3, pageCount: 10,
                                 variantID: "perfect-bound-softcover-6x9", postedAt: date(2026, 5, 8))
            },
            readerName: "Reader",
            now: date(2027, 3, 1),
            calendar: calendar
        )
        XCTAssertEqual(fourth?.chapterCount, 2)
        XCTAssertEqual(fourth?.publicationKind, .annual)
        XCTAssertTrue(fourth?.isAnnualVolume ?? false)
        XCTAssertEqual(fourth?.variantID, "cloth-foil-hardcover-6x9")
    }
}
