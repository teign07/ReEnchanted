import XCTest
@testable import InsideCoverCore

/// The grimoire's arithmetic all happens in here, so these are the tests that
/// decide whether any correspondence the Book ever states is true.
final class DayBitsetTests: XCTestCase {

    func testInsertAndCountAcrossWordBoundaries() {
        var set = DayBitset()
        for day in [0, 63, 64, 65, 127, 128, 4000] { set.insert(day) }
        XCTAssertEqual(set.count, 7)
        XCTAssertEqual(set.days, [0, 63, 64, 65, 127, 128, 4000])
        XCTAssertTrue(set.contains(64))
        XCTAssertFalse(set.contains(66))
        XCTAssertEqual(set.firstDay, 0)
        XCTAssertEqual(set.lastDay, 4000)
    }

    func testGrowsInBothDirections() {
        var set = DayBitset()
        set.insert(1000)
        set.insert(10)
        set.insert(5000)
        XCTAssertEqual(set.days, [10, 1000, 5000])
        XCTAssertEqual(set.count, 3)
    }

    func testStoredFormIsIndependentOfInsertOrder() {
        let forward = DayBitset(days: [7, 300, 301, 900])
        let backward = DayBitset(days: [900, 301, 300, 7])
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(forward.wordOffset, backward.wordOffset)
    }

    func testTrimmingKeepsAFortnightCheapInAnOldBook() {
        // A feature met over two weeks four years in should still cost about
        // one word: this is the whole reason the archive can be compared
        // against itself without the cost growing with its age.
        let late = DayBitset(days: Array(1400...1410))
        XCTAssertLessThanOrEqual(late.words.count, 2)
    }

    func testEmptySetHasNoDays() {
        let set = DayBitset()
        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.count, 0)
        XCTAssertNil(set.firstDay)
        XCTAssertNil(set.lastDay)
        XCTAssertEqual(set.days, [])
    }

    // MARK: Set algebra

    func testIntersectionUnionAndDifference() {
        let left = DayBitset(days: [1, 2, 3, 100, 200])
        let right = DayBitset(days: [2, 3, 4, 200, 300])
        XCTAssertEqual(left.intersection(right).days, [2, 3, 200])
        XCTAssertEqual(left.union(right).days, [1, 2, 3, 4, 100, 200, 300])
        XCTAssertEqual(left.subtracting(right).days, [1, 100])
    }

    func testIntersectionCountMatchesTheBuiltIntersection() {
        let left = DayBitset(days: [0, 5, 64, 65, 300, 1200])
        let right = DayBitset(days: [5, 65, 66, 1200, 4000])
        XCTAssertEqual(left.intersectionCount(right), left.intersection(right).count)
        XCTAssertEqual(left.intersectionCount(right), 3)
    }

    func testDisjointSetsIntersectToNothing() {
        let early = DayBitset(days: [1, 2, 3])
        let late = DayBitset(days: [900, 901])
        XCTAssertTrue(early.intersection(late).isEmpty)
        XCTAssertEqual(early.intersectionCount(late), 0)
        XCTAssertEqual(early.subtracting(late).days, [1, 2, 3])
    }

    func testEmptyOperandsBehave() {
        let set = DayBitset(days: [4, 8])
        XCTAssertEqual(set.union(DayBitset()).days, [4, 8])
        XCTAssertEqual(DayBitset().union(set).days, [4, 8])
        XCTAssertTrue(set.intersection(DayBitset()).isEmpty)
        XCTAssertEqual(set.subtracting(DayBitset()).days, [4, 8])
        XCTAssertTrue(DayBitset().subtracting(set).isEmpty)
    }

    // MARK: Time shapes

    func testShiftForwardMovesDaysLater() {
        let set = DayBitset(days: [0, 10, 63, 64])
        XCTAssertEqual(set.shiftedForward(by: 1).days, [1, 11, 64, 65])
        XCTAssertEqual(set.shiftedForward(by: 64).days, [64, 74, 127, 128])
        XCTAssertEqual(set.shiftedForward(by: 100).days, [100, 110, 163, 164])
    }

    func testShiftAcrossAWordBoundaryKeepsEveryDay() {
        let set = DayBitset(days: [60, 61, 62, 63])
        XCTAssertEqual(set.shiftedForward(by: 5).days, [65, 66, 67, 68])
        XCTAssertEqual(set.shiftedForward(by: 5).count, 4)
    }

    func testWindowIsTheDaysFollowing() {
        let set = DayBitset(days: [10, 50])
        XCTAssertEqual(set.window(after: 1, through: 3).days, [11, 12, 13, 51, 52, 53])
    }

    func testSequenceIsAShiftAndAnIntersection() {
        // Wicker invites on day 10 and day 50; a photograph lands on 12 and 80.
        // Only the first is "within three days".
        let invitations = DayBitset(days: [10, 50])
        let photographs = DayBitset(days: [12, 80])
        let followed = invitations.window(after: 1, through: 3).intersection(photographs)
        XCTAssertEqual(followed.days, [12])
    }

    func testMaskBuildsFromAPredicate() {
        let evens = DayBitset.mask(from: 0, through: 10) { $0 % 2 == 0 }
        XCTAssertEqual(evens.days, [0, 2, 4, 6, 8, 10])
        XCTAssertTrue(DayBitset.mask(from: 5, through: 1) { _ in true }.isEmpty)
    }

    // MARK: Storage

    func testRoundTripsThroughCoding() throws {
        let original = DayBitset(days: [0, 1, 63, 64, 1000, 1461, 4000])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(DayBitset.self, from: data)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.days, original.days)
    }

    func testEmptyRoundTrips() throws {
        let data = try JSONEncoder().encode(DayBitset())
        XCTAssertEqual(try JSONDecoder().decode(DayBitset.self, from: data), DayBitset())
    }

    func testFourYearsStaysSmallOnDisk() throws {
        // Every day of four years set: the point is that this is bytes, not
        // kilobytes, because the desk will hold thousands of these.
        let everyDay = DayBitset(days: Array(0...1460))
        XCTAssertEqual(everyDay.count, 1461)
        XCTAssertEqual(everyDay.words.count, 23)
        let data = try JSONEncoder().encode(everyDay)
        // ~500 bytes encoded: about a third of a byte per day, base64 included.
        XCTAssertLessThan(data.count, 600)
        XCTAssertLessThan(Double(data.count) / 1461.0, 1.0)
    }

    // MARK: Day numbering

    func testDayIndexIsStableAndOrdered() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let first = GrimoireDay.index(for: Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let next = GrimoireDay.index(
            for: Date(timeIntervalSince1970: 1_700_000_000 + 86_400),
            calendar: calendar
        )
        XCTAssertEqual(next, first + 1)
        XCTAssertGreaterThan(first, 0)
    }

    func testTwoMomentsInOneDayShareAnIndex() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let morning = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 8))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 22))!
        XCTAssertEqual(
            GrimoireDay.index(for: morning, calendar: calendar),
            GrimoireDay.index(for: evening, calendar: calendar)
        )
        let nextMorning = calendar.date(from: DateComponents(year: 2026, month: 4, day: 11, hour: 8))!
        XCTAssertEqual(
            GrimoireDay.index(for: nextMorning, calendar: calendar),
            GrimoireDay.index(for: morning, calendar: calendar) + 1
        )
    }

    func testDatesBeforeTheReferenceDayClampRatherThanCrash() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        XCTAssertEqual(GrimoireDay.index(for: Date(timeIntervalSince1970: 0), calendar: calendar), 0)
    }

    func testSeasonsAndYearsReadBackFromADayNumber() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let april = GrimoireDay.index(
            for: calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!,
            calendar: calendar
        )
        XCTAssertEqual(GrimoireDay.season(of: april, calendar: calendar), 1)
        XCTAssertEqual(GrimoireDay.year(of: april, calendar: calendar), 2026)
    }
}

/// The backward half of sequence. Split out because it is the operation that
/// keeps "did this follow that" honest, and it is easy to get off by a day.
final class DayBitsetBackwardShiftTests: XCTestCase {

    func testShiftBackwardMovesDaysEarlier() {
        let set = DayBitset(days: [10, 64, 65, 200])
        XCTAssertEqual(set.shiftedBackward(by: 1).days, [9, 63, 64, 199])
        XCTAssertEqual(set.shiftedBackward(by: 64).days, [0, 1, 136])
        XCTAssertEqual(set.shiftedBackward(by: 10).days, [0, 54, 55, 190])
    }

    func testDaysPushedBeforeTheBeginningFallOff() {
        let set = DayBitset(days: [0, 1, 2, 100])
        XCTAssertEqual(set.shiftedBackward(by: 3).days, [97])
        XCTAssertTrue(DayBitset(days: [0, 1]).shiftedBackward(by: 5).isEmpty)
        XCTAssertTrue(DayBitset(days: [5]).shiftedBackward(by: 200).isEmpty)
    }

    func testForwardThenBackwardIsWhereItStarted() {
        let set = DayBitset(days: [3, 70, 71, 500, 1400])
        for step in [1, 2, 7, 63, 64, 65, 130] {
            XCTAssertEqual(
                set.shiftedForward(by: step).shiftedBackward(by: step).days,
                set.days,
                "round trip failed at \(step)"
            )
        }
    }

    func testPrecedingWindowIsTheDaysBefore() {
        let set = DayBitset(days: [10, 50])
        XCTAssertEqual(set.precedingWindow(from: 1, through: 3).days, [7, 8, 9, 47, 48, 49])
    }

    func testTheSequenceDenominatorIsTheNumberOfCauses() {
        // Six invitations, each followed two days later by a photograph.
        let invitations = DayBitset(days: [0, 10, 20, 30, 40, 50])
        let photographs = DayBitset(days: [2, 12, 22, 32, 42, 52])
        let followed = invitations.intersection(photographs.precedingWindow(from: 1, through: 3))
        // Six of six, not six of eighteen. That difference is the whole point.
        XCTAssertEqual(followed.count, 6)
        XCTAssertEqual(invitations.count, 6)
    }
}
