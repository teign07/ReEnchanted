import XCTest
@testable import InsideCoverCore

/// The composer is the only path any of the new almanacs take to the desk, so
/// these cover the promises that live in it: ranking, the grief valve, the
/// permanent rest, and the fact that `ReaderOccasions` can now be reached at
/// all: it was built, tested, and unreachable before this existed.
final class FeastdayComposerTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    private func page(at moment: Date, weatherTags: [String] = []) -> BookPage {
        var page = BookPage(
            id: UUID().uuidString,
            type: .diary,
            createdAt: moment,
            promptText: "p",
            userInput: "something true",
            origin: .userAuthored
        )
        page.context = BookPageContextSnapshot(at: moment, calendar: calendar, weatherTags: weatherTags)
        return page
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { BookDay(id: $0.key, date: $0.value[0].createdAt, pages: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: Ranking

    func testTheReadersOwnBirthdayOutranksEverythingElse() {
        // 25 December 2026: Christmas, and a birthday.
        var context = FeastdayComposer.Context.empty
        context.readerBirthday = ReaderBirthday(month: 12, day: 25)

        let found = FeastdayComposer.celebrations(on: date(2026, 12, 25), context: context, calendar: calendar)
        XCTAssertEqual(found.first?.id, "birthday-reader",
                       "Got \(found.first?.id ?? "nothing"): the reader's own day must come first")
        XCTAssertTrue(found.contains { $0.id == "world-christmas" }, "Christmas should still be in the list")
    }

    func testAPersonsBirthdayOutranksTheSky() {
        var thread = PersonThread(
            id: "person:sam", name: "Sam", introducedDay: "2026-01-01",
            readerWords: "the one who calls", firstMentionDay: "2026-01-01",
            lastMentionDay: "2026-01-01", mentionPageCount: 3
        )
        var profile = PersonRelationshipProfile()
        profile.birthday = ReaderBirthday(month: 6, day: 21)
        thread.relationship = profile

        var context = FeastdayComposer.Context.empty
        context.people = PeopleLedger(threads: [thread])

        let found = FeastdayComposer.celebrations(on: date(2026, 6, 21), context: context, calendar: calendar)
        XCTAssertEqual(found.first?.id, "birthday-person:person:sam")
        XCTAssertTrue(found.first?.commonName.contains("Sam") == true)
    }

    func testARestingPersonKeepsTheirBirthdayQuiet() {
        var thread = PersonThread(
            id: "person:sam", name: "Sam", introducedDay: "2026-01-01",
            readerWords: "", firstMentionDay: "2026-01-01",
            lastMentionDay: "2026-01-01", mentionPageCount: 3
        )
        var profile = PersonRelationshipProfile()
        profile.birthday = ReaderBirthday(month: 6, day: 21)
        thread.relationship = profile
        thread.resting = true

        var context = FeastdayComposer.Context.empty
        context.people = PeopleLedger(threads: [thread])

        let found = FeastdayComposer.celebrations(on: date(2026, 6, 21), context: context, calendar: calendar)
        XCTAssertFalse(found.contains { $0.id.hasPrefix("birthday-person") })
    }

    // MARK: The grief valve

    func testAHardDaySilencesEveryGrievingFeast() {
        var context = FeastdayComposer.Context.empty
        context.readerBirthday = ReaderBirthday(month: 12, day: 25)
        context.distressActive = true

        let found = FeastdayComposer.celebrations(on: date(2026, 12, 25), context: context, calendar: calendar)
        XCTAssertFalse(found.contains { $0.carriesGrief },
                       "A hard day let through: \(found.filter(\.carriesGrief).map(\.id))")
        XCTAssertFalse(found.contains { $0.id == "birthday-reader" })
        XCTAssertFalse(found.contains { $0.id == "world-christmas" })
    }

    func testAGentleDayStillGetsItsFeasts() {
        var context = FeastdayComposer.Context.empty
        context.distressActive = false
        let found = FeastdayComposer.celebrations(on: date(2026, 12, 25), context: context, calendar: calendar)
        XCTAssertTrue(found.contains { $0.id == "world-christmas" })
    }

    // MARK: Rest

    func testARestedFeastNeverComesBack() {
        var context = FeastdayComposer.Context.empty
        context.restedIDs = ["world-christmas"]
        let found = FeastdayComposer.celebrations(on: date(2026, 12, 25), context: context, calendar: calendar)
        XCTAssertFalse(found.contains { $0.id == "world-christmas" })
    }

    func testTheReadersOwnBirthdayCanBeRestedToo() {
        var context = FeastdayComposer.Context.empty
        context.readerBirthday = ReaderBirthday(month: 3, day: 3)
        context.restedIDs = ["birthday-reader"]
        let found = FeastdayComposer.celebrations(on: date(2026, 3, 3), context: context, calendar: calendar)
        XCTAssertFalse(found.contains { $0.id == "birthday-reader" })
    }

    // MARK: ReaderOccasions finally has a route

    func testReaderOccasionsCanNowReachTheDesk() {
        // A hundred kept pages spread across a hundred days reaches a notable
        // total, which had no way of surfacing before the composer.
        var pages: [BookPage] = []
        let start = date(2026, 1, 1)
        for offset in 0..<100 {
            pages.append(page(at: calendar.date(byAdding: .day, value: offset, to: start)!))
        }
        var context = FeastdayComposer.Context.empty
        context.days = days(pages)

        let now = calendar.date(byAdding: .day, value: 99, to: start)!
        let found = FeastdayComposer.celebrations(on: now, context: context, calendar: calendar)
        XCTAssertTrue(found.contains { $0.id.hasPrefix("reader-") },
                      "No reader occasion surfaced from 100 kept pages: \(found.map(\.id))")
    }

    // MARK: Firsts

    func testFirstSnowNeedsTheBookToHaveBeenWatching() {
        // Ten days of kept pages in the season, none of them snowy, then snow.
        var pages: [BookPage] = []
        let start = date(2026, 10, 1)
        for offset in 0..<20 {
            pages.append(page(at: calendar.date(byAdding: .day, value: offset, to: start)!,
                              weatherTags: ["cloud"]))
        }
        var context = FeastdayComposer.Context.empty
        context.days = days(pages)
        context.currentWeatherTags = ["snow", "cold"]

        let now = calendar.date(byAdding: .day, value: 40, to: start)!
        let found = FeastdayComposer.celebrations(on: now, context: context, calendar: calendar)
        XCTAssertTrue(found.contains { $0.id == "first-snow" }, "Got \(found.map(\.id))")
    }

    func testABrandNewReaderIsNeverToldItIsTheFirstSnow() {
        // Three days of archive is not enough to know it hasn't snowed.
        var pages: [BookPage] = []
        let start = date(2026, 11, 1)
        for offset in 0..<3 {
            pages.append(page(at: calendar.date(byAdding: .day, value: offset, to: start)!))
        }
        var context = FeastdayComposer.Context.empty
        context.days = days(pages)
        context.currentWeatherTags = ["snow"]

        let found = FeastdayComposer.celebrations(
            on: calendar.date(byAdding: .day, value: 4, to: start)!,
            context: context, calendar: calendar
        )
        XCTAssertFalse(found.contains { $0.id == "first-snow" },
                       "The Book claimed a first snow it could not possibly know about")
    }

    func testItIsNotTheFirstSnowTwice() {
        var pages: [BookPage] = []
        let start = date(2026, 10, 1)
        for offset in 0..<20 {
            // Day 5 already saw snow, so a later snow is not a first.
            pages.append(page(at: calendar.date(byAdding: .day, value: offset, to: start)!,
                              weatherTags: offset == 5 ? ["snow"] : ["cloud"]))
        }
        var context = FeastdayComposer.Context.empty
        context.days = days(pages)
        context.currentWeatherTags = ["snow"]

        let found = FeastdayComposer.celebrations(
            on: calendar.date(byAdding: .day, value: 40, to: start)!,
            context: context, calendar: calendar
        )
        XCTAssertFalse(found.contains { $0.id == "first-snow" })
    }

    // MARK: Windows

    func testTheWindowsNeedACoordinateAndStayQuietWithoutOne() {
        var context = FeastdayComposer.Context.empty
        // 4pm on a mid-December afternoon in New York is inside the golden hour.
        let moment = date(2026, 12, 15, hour: 16)

        let withoutCoordinate = FeastdayComposer.celebrations(on: moment, context: context, calendar: calendar)
        XCTAssertFalse(withoutCoordinate.contains { $0.kind == .window })

        context.coordinate = ReaderCoordinate(latitude: 40.7, longitude: -74.0)
        let withCoordinate = FeastdayComposer.celebrations(on: moment, context: context, calendar: calendar)
        XCTAssertTrue(withCoordinate.contains { $0.id == "window-gilding" },
                      "Got \(withCoordinate.map(\.id))")
    }

    func testAWindowAboutToCloseIsNotOffered() {
        var context = FeastdayComposer.Context.empty
        context.coordinate = ReaderCoordinate(latitude: 40.7, longitude: -74.0)
        // Sunset in New York on 15 December is about 16:31. One minute out.
        let moment = date(2026, 12, 15, hour: 16).addingTimeInterval(30 * 60)
        let found = FeastdayComposer.celebrations(on: moment, context: context, calendar: calendar)
        XCTAssertFalse(found.contains { $0.id == "window-gilding" },
                       "A window with a minute left is a taunt, not an invitation")
    }

    // MARK: Birthday parsing

    func testTheBookReadsABirthdayOutOfOrdinaryWords() {
        XCTAssertEqual(ReaderBirthday.parse("March 3rd"), ReaderBirthday(month: 3, day: 3))
        XCTAssertEqual(ReaderBirthday.parse("14 August"), ReaderBirthday(month: 8, day: 14))
        XCTAssertEqual(ReaderBirthday.parse("the eleventh of November")?.month, 11)
        XCTAssertEqual(ReaderBirthday.parse("Sept 9"), ReaderBirthday(month: 9, day: 9))
        XCTAssertEqual(ReaderBirthday.parse("29 February"), ReaderBirthday(month: 2, day: 29))
    }

    func testTheYearIsThrownAway() {
        XCTAssertEqual(ReaderBirthday.parse("March 3rd, 1987"), ReaderBirthday(month: 3, day: 3))
        XCTAssertEqual(ReaderBirthday.parse("3 March 1987"), ReaderBirthday(month: 3, day: 3))
    }

    func testImpossibleDatesAreRefusedRatherThanStored() {
        XCTAssertNil(ReaderBirthday.parse("February 31st"))
        XCTAssertNil(ReaderBirthday.parse("the 45th of Smarch"))
        XCTAssertNil(ReaderBirthday.parse("I'd rather not say"))
        XCTAssertNil(ReaderBirthday.parse(""))
    }

    func testABirthdayKnowsItsOwnDay() {
        let birthday = ReaderBirthday(month: 7, day: 4)
        XCTAssertTrue(birthday.falls(on: date(2026, 7, 4), calendar: calendar))
        XCTAssertTrue(birthday.falls(on: date(2031, 7, 4), calendar: calendar))
        XCTAssertFalse(birthday.falls(on: date(2026, 7, 5), calendar: calendar))
        XCTAssertFalse(birthday.falls(on: date(2026, 4, 7), calendar: calendar))
    }

    // MARK: Family days

    func testFamilyDaysResolveAgainstTheReadersOwnRegion() {
        // US Mother's Day 2026: second Sunday in May, the 10th.
        let us = FamilyAlmanac.celebrations(
            on: date(2026, 5, 10), locale: Locale(identifier: "en_US"), calendar: calendar
        )
        XCTAssertTrue(us.contains { $0.id == "family-mothers" })

        // UK Mothering Sunday 2026 is three weeks before Easter (5 April), so
        // 15 March, and definitely not in May.
        let ukInMay = FamilyAlmanac.celebrations(
            on: date(2026, 5, 10), locale: Locale(identifier: "en_GB"), calendar: calendar
        )
        XCTAssertFalse(ukInMay.contains { $0.id == "family-mothers" },
                       "A British reader should not be handed the American date")

        let ukInMarch = FamilyAlmanac.celebrations(
            on: date(2026, 3, 15), locale: Locale(identifier: "en_GB"), calendar: calendar
        )
        XCTAssertTrue(ukInMarch.contains { $0.id == "family-mothers" })
    }

    func testThanksgivingKnowsWhichCountryItIsIn() {
        // US: fourth Thursday in November 2026 is the 26th.
        XCTAssertTrue(
            FamilyAlmanac.celebrations(on: date(2026, 11, 26), locale: Locale(identifier: "en_US"), calendar: calendar)
                .contains { $0.id == "family-thanksgiving" }
        )
        // Canada: second Monday in October 2026 is the 12th.
        XCTAssertTrue(
            FamilyAlmanac.celebrations(on: date(2026, 10, 12), locale: Locale(identifier: "en_CA"), calendar: calendar)
                .contains { $0.id == "family-thanksgiving" }
        )
        // And nowhere else claims it.
        XCTAssertTrue(
            FamilyAlmanac.celebrations(on: date(2026, 11, 26), locale: Locale(identifier: "en_GB"), calendar: calendar)
                .isEmpty
        )
    }

    /// The whole point of the warmer version: these are marked for everybody,
    /// and never assume the reader has the relationship.
    func testFamilyDaysNeverAssumeTheRelationship() {
        let all = ["2026-05-10", "2026-06-21", "2026-02-14", "2026-11-26"]
        var checked = 0
        for raw in all {
            let parts = raw.split(separator: "-").compactMap { Int($0) }
            let found = FamilyAlmanac.celebrations(
                on: date(parts[0], parts[1], parts[2]),
                locale: Locale(identifier: "en_US"), calendar: calendar
            )
            for feast in found {
                checked += 1
                let text = feast.blurb + " " + feast.invitation
                let lowered = text.lowercased()
                XCTAssertFalse(lowered.contains("call your"), "\(feast.id) tells the reader who to ring")
                XCTAssertFalse(lowered.contains("your mother"), "\(feast.id) assumes a mother")
                XCTAssertFalse(lowered.contains("your father"), "\(feast.id) assumes a father")
                XCTAssertFalse(lowered.contains("happy "), "\(feast.id) wishes a happy something")
                XCTAssertTrue(feast.carriesGrief, "\(feast.id) has no grief valve")
                XCTAssertTrue(feast.canBeRested, "\(feast.id) has no door out")
            }
        }
        XCTAssertEqual(checked, 4, "Expected all four family days, checked \(checked)")
    }
}
