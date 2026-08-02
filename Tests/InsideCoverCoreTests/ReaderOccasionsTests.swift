import XCTest
@testable import InsideCoverCore

/// Fairy tales care about the third night and the seventh time and the
/// anniversary of a promise. None of those are dates — they are shapes in the
/// reader's own record, and the Book may only mark ones they actually earned.
final class ReaderOccasionsTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ date: Date, pages: Int = 1) -> BookDay {
        BookDay(
            id: BookDay.id(for: date), date: date,
            pages: (0..<pages).map { index in
                BookPage(
                    id: "\(BookDay.id(for: date))-\(index)", type: .souvenir,
                    createdAt: date.addingTimeInterval(Double(index) * 60),
                    promptText: "p", userInput: "a kept line", origin: .userAuthored
                )
            }
        )
    }

    private func daysAgo(_ n: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now)!
    }

    func testAnEmptyRecordHasNoOccasions() {
        XCTAssertTrue(ReaderOccasions.celebrations(days: []).isEmpty)
    }

    // MARK: Returns

    func testAPageKeptAYearAgoTodayIsMarked() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        let found = ReaderOccasions.celebrations(days: [day(lastYear), day(now)], now: now)
        let anniversary = try XCTUnwrap(found.first { $0.id.hasPrefix("reader-anniversary") })
        // It is the reader's very first page, so the Book says so.
        XCTAssertEqual(anniversary.commonName, "The Day You Started")
        XCTAssertTrue(anniversary.blurb.contains("A year ago today"))
    }

    func testAPageKeptLastWeekIsNotAnAnniversary() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let found = ReaderOccasions.celebrations(days: [day(daysAgo(7, from: now)), day(now)], now: now)
        XCTAssertFalse(found.contains { $0.id.hasPrefix("reader-anniversary") })
    }

    // MARK: Tallies

    func testANotableTotalIsMarkedOnTheDayItIsReached() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        var days = (1...6).map { day(daysAgo($0, from: now)) }
        days.append(day(now))
        let found = ReaderOccasions.celebrations(days: days, now: now)
        let total = try XCTUnwrap(found.first { $0.id == "reader-total-7" })
        XCTAssertTrue(total.blurb.contains("Seven"))
    }

    /// The number is news on the day, not a status bar the reader walks past
    /// every morning afterwards.
    func testANotableTotalIsNotRepeatedTheFollowingDay() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let days = (1...7).map { day(daysAgo($0, from: now)) }
        let found = ReaderOccasions.celebrations(days: days, now: now)
        XCTAssertFalse(found.contains { $0.id.hasPrefix("reader-total") })
    }

    func testAnUnremarkableTotalIsNotMarked() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        var days = (1...4).map { day(daysAgo($0, from: now)) }
        days.append(day(now))
        let found = ReaderOccasions.celebrations(days: days, now: now)
        XCTAssertFalse(found.contains { $0.id.hasPrefix("reader-total") })
    }

    // MARK: Runs — observed, never demanded

    func testTheThirdNightRunningIsNoticed() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let days = [day(daysAgo(2, from: now)), day(daysAgo(1, from: now)), day(now)]
        let run = try XCTUnwrap(
            ReaderOccasions.celebrations(days: days, now: now).first { $0.id == "reader-run-3" }
        )
        XCTAssertTrue(run.blurb.contains("Third day running"))
    }

    /// The crucial one: a run that ends is never mentioned. No streaks means no
    /// day on which the Book tells the reader they lost something.
    func testABrokenRunIsNeverMentioned() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        // Three days running, then a gap, then today.
        let days = [day(daysAgo(5, from: now)), day(daysAgo(4, from: now)),
                    day(daysAgo(3, from: now)), day(now)]
        let found = ReaderOccasions.celebrations(days: days, now: now)
        XCTAssertFalse(found.contains { $0.id.hasPrefix("reader-run") })
        for celebration in found {
            let text = (celebration.blurb + celebration.invitation).lowercased()
            for shaming in ["broke", "missed", "lost", "again", "back on"] {
                XCTAssertFalse(text.contains(shaming), "\(celebration.id) mentions the gap: \(shaming)")
            }
        }
    }

    // MARK: Register and precedence

    func testNoReaderOccasionEverDemandsAnything() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        var days = (1...6).map { day(daysAgo($0, from: now)) }
        days.append(day(now))
        let found = ReaderOccasions.celebrations(days: days, now: now)
        XCTAssertFalse(found.isEmpty)
        for celebration in found {
            XCTAssertEqual(celebration.greyShift, 0, "\(celebration.id) moved the grey")
            XCTAssertGreaterThan(celebration.beliefBonus, 0, celebration.id)
        }
    }

    func testWhatTheReaderDidOutranksAnAuthorsBirthday() {
        XCTAssertGreaterThan(ReaderOccasions.priority, LiteraryAlmanac.priority)
    }
}
