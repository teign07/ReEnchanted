import XCTest
@testable import InsideCoverCore

/// Every new Bound Year member gets their first full week bound and posted,
/// free. The Book waits for a week worth holding, never sends twice, and
/// keeps trying quietly when the print desk balks.
final class WelcomeWeeklyTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func membership(_ status: BoundYearMembership.Status = .active, verified: Bool? = true) -> BoundYearMembership {
        BoundYearMembership(
            cadence: .monthly,
            status: status,
            startedAt: date(10, 1, hour: 12),
            paidThrough: date(11, 1, hour: 12),
            digitalPaymentVerified: verified
        )
    }

    private func welcome(joined: Date = Date()) -> BoundYearWelcomeWeekly {
        BoundYearWelcomeWeekly(membershipID: "sub_member", joinedAt: joined)
    }

    /// Reader weeks starting `firstWeekStart`, each with its own kept-day count.
    private func weeks(from start: Date, keptDays: [Int]) -> [WelcomeWeeklyPolicy.WeekTally] {
        keptDays.enumerated().map { index, kept in
            let weekStart = calendar.date(byAdding: .day, value: index * 7, to: calendar.startOfDay(for: start))!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return WelcomeWeeklyPolicy.WeekTally(
                period: PublicationPeriod(
                    id: PublicationPeriodID(recipe: .readerWeek, startDayID: "w\(index)-start", endDayID: "w\(index)-end"),
                    startDate: weekStart,
                    endDate: weekEnd,
                    ordinal: index + 1
                ),
                keptDays: kept,
                eligiblePageCount: kept * 2
            )
        }
    }

    private func decide(
        _ welcome: BoundYearWelcomeWeekly,
        _ weeks: [WelcomeWeeklyPolicy.WeekTally],
        now: Date,
        membership: BoundYearMembership? = nil
    ) -> WelcomeWeeklyPolicy.Decision {
        WelcomeWeeklyPolicy.decide(
            welcome: welcome,
            membership: membership ?? self.membership(),
            weeks: weeks,
            now: now,
            calendar: calendar
        )
    }

    private func sentOrdinal(_ decision: WelcomeWeeklyPolicy.Decision) -> Int? {
        if case .send(let period) = decision { return period.ordinal }
        return nil
    }

    // MARK: Which week

    func testTheWeekTheReaderJoinedInDoesNotCount() {
        // Weeks start Oct 5, 12, 19. Joined Oct 8: the Oct 5 week was half
        // before the membership, however full it was.
        let tallies = weeks(from: date(10, 5), keptDays: [7, 4, 5])
        let joined = welcome(joined: date(10, 8))
        XCTAssertEqual(sentOrdinal(decide(joined, tallies, now: date(10, 20))), 2)
    }

    func testItWaitsForTheFirstFullWeekToClose() {
        let tallies = weeks(from: date(10, 12), keptDays: [5])
        let joined = welcome(joined: date(10, 11))
        XCTAssertEqual(decide(joined, tallies, now: date(10, 18, hour: 23)), .wait)
        XCTAssertEqual(sentOrdinal(decide(joined, tallies, now: date(10, 19, hour: 1))), 1)
    }

    func testAWeekStartingOnTheJoinDayCounts() {
        let tallies = weeks(from: date(10, 12), keptDays: [3])
        XCTAssertEqual(sentOrdinal(decide(welcome(joined: date(10, 12, hour: 21)), tallies, now: date(10, 20))), 1)
    }

    func testAThinWeekWaitsForTheNextOne() {
        let tallies = weeks(from: date(10, 12), keptDays: [2, 1, 3])
        let joined = welcome(joined: date(10, 12))
        XCTAssertEqual(decide(joined, tallies, now: date(10, 27)), .wait, "two thin weeks and the third still open")
        XCTAssertEqual(sentOrdinal(decide(joined, tallies, now: date(11, 2, hour: 9))), 3)
    }

    func testThreeKeptDaysIsTheFloor() {
        XCTAssertEqual(WelcomeWeeklyPolicy.minimumKeptDays, 3)
        let joined = welcome(joined: date(10, 12))
        XCTAssertEqual(decide(joined, weeks(from: date(10, 12), keptDays: [2]), now: date(10, 20)), .wait)
        XCTAssertEqual(sentOrdinal(decide(joined, weeks(from: date(10, 12), keptDays: [3]), now: date(10, 20))), 1)
    }

    func testAfterFourThinWeeksTheFullestOneGoes() {
        let tallies = weeks(from: date(10, 12), keptDays: [1, 2, 0, 2, 6])
        let joined = welcome(joined: date(10, 12))
        XCTAssertEqual(decide(joined, tallies, now: date(11, 8)), .wait, "the fourth week hasn't closed")
        XCTAssertEqual(sentOrdinal(decide(joined, tallies, now: date(11, 9, hour: 9))), 2,
                       "the fullest of the first four, the earliest of a tie, never the fifth")
    }

    func testFourEmptyWeeksWaitForTheFirstWeekWithAnythingInIt() {
        let tallies = weeks(from: date(10, 12), keptDays: [0, 0, 0, 0, 0, 1])
        let joined = welcome(joined: date(10, 12))
        XCTAssertEqual(decide(joined, tallies, now: date(11, 17)), .wait)
        XCTAssertEqual(sentOrdinal(decide(joined, tallies, now: date(11, 23, hour: 9))), 6)
    }

    func testAWeekTooSmallToBeAnIssueIsSkipped() {
        var tallies = weeks(from: date(10, 12), keptDays: [3, 4])
        tallies[0].eligiblePageCount = WeeklyIssue.minimumIssuePages - 1
        XCTAssertEqual(sentOrdinal(decide(welcome(joined: date(10, 12)), tallies, now: date(10, 27))), 2)
    }

    // MARK: Never twice, never for a lapsed member

    func testAPostedWelcomeIsNeverSentAgain() {
        var posted = welcome(joined: date(10, 12))
        posted.postedAt = date(10, 20)
        posted.announcedAt = date(10, 20)
        XCTAssertEqual(decide(posted, weeks(from: date(10, 12), keptDays: [5, 5, 5]), now: date(11, 5)), .posted)
    }

    func testOnlyACurrentPaidMembershipSends() {
        let tallies = weeks(from: date(10, 12), keptDays: [5])
        let joined = welcome(joined: date(10, 12))
        for status in [BoundYearMembership.Status.lapsed, .cancelled] {
            XCTAssertEqual(decide(joined, tallies, now: date(10, 20), membership: membership(status)), .wait, "\(status)")
        }
        XCTAssertEqual(decide(joined, tallies, now: date(10, 20), membership: membership(verified: false)), .wait,
                       "a payment the Worker refused to verify")
    }

    // MARK: Quiet retries

    func testAFailedAttemptRestsBeforeTryingAgain() {
        let tallies = weeks(from: date(10, 12), keptDays: [5])
        var failing = welcome(joined: date(10, 12))
        failing.lastAttemptAt = date(10, 20, hour: 9)
        failing.failedAttempts = 1
        XCTAssertEqual(decide(failing, tallies, now: date(10, 20, hour: 9).addingTimeInterval(1_800)), .wait)
        XCTAssertNotNil(sentOrdinal(decide(failing, tallies, now: date(10, 20, hour: 10).addingTimeInterval(60))))
        failing.failedAttempts = 5
        XCTAssertEqual(decide(failing, tallies, now: date(10, 20, hour: 21)), .wait, "a day at most between tries")
        XCTAssertNotNil(sentOrdinal(decide(failing, tallies, now: date(10, 21, hour: 10))))
    }

    func testAnAttemptUnderWayIsNotStartedTwice() {
        var inFlight = welcome(joined: date(10, 12))
        inFlight.lastAttemptAt = date(10, 20, hour: 9)
        let tallies = weeks(from: date(10, 12), keptDays: [5])
        XCTAssertEqual(decide(inFlight, tallies, now: date(10, 20, hour: 9).addingTimeInterval(120)), .wait)
        XCTAssertNotNil(sentOrdinal(decide(inFlight, tallies, now: date(10, 20, hour: 9).addingTimeInterval(700))),
                       "an app closed mid-attempt tries again")
    }

    // MARK: The record

    func testTrackingStartsOnceForACurrentMembership() {
        let now = date(10, 12)
        XCTAssertNil(BoundYearWelcomeWeekly.tracking(nil, membershipID: nil, membership: membership(), now: now))
        XCTAssertNil(BoundYearWelcomeWeekly.tracking(nil, membershipID: "sub_member", membership: membership(.lapsed), now: now))
        let started = BoundYearWelcomeWeekly.tracking(nil, membershipID: "sub_member", membership: membership(), now: now)
        XCTAssertEqual(started?.joinedAt, now)
        let later = BoundYearWelcomeWeekly.tracking(started, membershipID: "sub_member", membership: membership(), now: date(11, 1))
        XCTAssertEqual(later, started, "seeing the same membership again doesn't move the join")
        let rejoined = BoundYearWelcomeWeekly.tracking(started, membershipID: "sub_new", membership: membership(), now: date(12, 1))
        XCTAssertEqual(rejoined?.membershipID, "sub_new")
        XCTAssertEqual(rejoined?.joinedAt, date(12, 1))
        XCTAssertNil(rejoined?.postedAt)
    }

    func testAServerClaimMarksItPostedAndOnlyOwesTheLineToTheBookThatSentIt() {
        var elsewhere = welcome(joined: date(10, 12))
        elsewhere.adoptServerClaim(luluPrintJobID: "print-job-1", at: date(10, 21))
        XCTAssertTrue(elsewhere.hasPosted)
        XCTAssertFalse(elsewhere.owesAnnouncement, "another device already said it")

        var lostReply = welcome(joined: date(10, 12))
        lostReply.lastAttemptAt = date(10, 20)
        lostReply.failedAttempts = 1
        lostReply.adoptServerClaim(luluPrintJobID: "print-job-2", at: date(10, 21))
        XCTAssertTrue(lostReply.owesAnnouncement, "this Book sent it and never heard back")
        XCTAssertEqual(lostReply.luluPrintJobID, "print-job-2")
    }

    func testOlderSavesDecodeWithoutAWelcome() throws {
        let data = try JSONEncoder().encode(PlayerVaultData())
        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: data)
        XCTAssertNil(decoded.boundYearWelcomeWeekly)
        var record = welcome(joined: date(10, 12))
        record.failedAttempts = nil
        let round = try JSONDecoder().decode(BoundYearWelcomeWeekly.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(round, record)
    }

    // MARK: Counting kept days

    func testKeptDaysCountDaysNotPagesFromTheRealArchive() {
        func page(_ id: String, _ when: Date) -> BookPage {
            BookPage(
                id: id, type: .souvenir, createdAt: when, promptText: "Souvenir",
                userInput: "The kettle sang at \(id).", origin: .userAuthored
            )
        }
        // Reader weeks anchor on the first keep: Oct 12.
        let busyEvening = (0..<5).map { page("busy-\($0)", date(10, 12, hour: 18 + $0 % 4)) }
        let days = [
            BookDay(id: "2026-10-12", date: date(10, 12), pages: busyEvening),
            BookDay(id: "2026-10-20", date: date(10, 20), pages: [page("a", date(10, 20))]),
            BookDay(id: "2026-10-22", date: date(10, 22), pages: [page("b", date(10, 22))]),
            BookDay(id: "2026-10-24", date: date(10, 24), pages: [page("c", date(10, 24))]),
        ]
        let now = date(10, 27)
        let candidates = PublicationPeriodCatalog.readerWeeks(days: days, now: now, calendar: calendar)
        let tallies = PublicationPeriodCatalog.welcomeWeeklyTallies(candidates: candidates, days: days, calendar: calendar)
        let byOrdinal = Dictionary(uniqueKeysWithValues: tallies.map { ($0.period.ordinal ?? 0, $0.keptDays) })
        XCTAssertEqual(byOrdinal[1], 1, "five pages in one evening is one kept day")
        XCTAssertEqual(byOrdinal[2], 3)

        let decision = WelcomeWeeklyPolicy.decide(
            welcome: welcome(joined: date(10, 12, hour: 8)),
            membership: membership(),
            weeks: tallies,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(sentOrdinal(decision), 2, "the busy evening wasn't a week; the next one was")
    }

    // MARK: Voice

    func testTheWelcomeKeepsTheBooksVoice() {
        let lines = [EditionOfferCopy.boundYearWelcomeLine, EditionOfferCopy.welcomeWeeklyDeskLine]
        for line in lines {
            let lower = line.lowercased()
            for stiff in [" is on its way", " do not ", " cannot ", " it is ", " you will ", " i will ", "free gift", "complimentary"] {
                XCTAssertFalse(lower.contains(stiff), "\(stiff) in: \(line)")
            }
        }
        XCTAssertTrue(EditionOfferCopy.seasonBody(label: "July to September", pageCount: 40, isMember: false)
            .contains(EditionOfferCopy.boundYearWelcomeLine))
        XCTAssertFalse(EditionOfferCopy.seasonBody(label: "July to September", pageCount: 40, isMember: true)
            .contains(EditionOfferCopy.boundYearWelcomeLine), "a member already has theirs")
    }
}
