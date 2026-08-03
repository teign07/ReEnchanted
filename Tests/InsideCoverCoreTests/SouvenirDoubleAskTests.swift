import XCTest
@testable import InsideCoverCore

/// A reader coming through the First Door writes one true sentence, it is kept
/// as a souvenir, and the Book immediately asked for another one.
///
/// The suppression check tested only for the `check-in-window:` tag, which the
/// ordinary check-in path writes and nothing else does. The onboarding souvenir
/// carries its own tags and none of that one, so it was invisible.
final class SouvenirDoubleAskTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func moment(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 2
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func souvenir(at date: Date, tags: [String]) -> BookPage {
        BookPage(
            id: "souvenir-\(date.timeIntervalSince1970)",
            type: .souvenir,
            createdAt: date,
            promptText: "What did you notice before it disappeared into the ordinary?",
            userInput: "The kettle was still warm when I got back.",
            tags: tags,
            origin: .userAuthored
        )
    }

    // MARK: The window itself

    func testAWindowKnowsWhatFallsInsideIt() {
        guard let morning = DailyCheckInCadence.windows.first(where: { $0.id == "morning" }) else {
            return XCTFail("no morning window")
        }
        XCTAssertTrue(DailyCheckInCadence.window(morning, contains: moment(hour: 9), calendar: calendar))
        XCTAssertFalse(DailyCheckInCadence.window(morning, contains: moment(hour: 14), calendar: calendar))
        XCTAssertFalse(DailyCheckInCadence.window(morning, contains: moment(hour: 6), calendar: calendar))
    }

    func testTheWindowsDoNotOverlap() {
        for probeHour in 0..<24 {
            let at = moment(hour: probeHour, minute: 30)
            let containing = DailyCheckInCadence.windows.filter {
                DailyCheckInCadence.window($0, contains: at, calendar: calendar)
            }
            XCTAssertLessThanOrEqual(containing.count, 1,
                                     "Hour \(probeHour) sits in \(containing.map(\.id))")
        }
    }

    /// The specific regression: the onboarding souvenir has none of the
    /// check-in tags, and must still count.
    func testTheOnboardingSouvenirCountsAsThisWindowsSouvenir() {
        guard let morning = DailyCheckInCadence.windows.first(where: { $0.id == "morning" }) else {
            return XCTFail("no morning window")
        }
        let onboarding = souvenir(
            at: moment(hour: 9),
            tags: ["souvenir", "first-page", "first-run-souvenir", "onboarding", "onboarding-first-souvenir"]
        )
        XCTAssertFalse(
            onboarding.tags.contains { $0.hasPrefix("check-in-window:") },
            "Test setup: the onboarding souvenir should carry no check-in tag"
        )
        XCTAssertTrue(
            DailyCheckInCadence.window(morning, contains: onboarding.createdAt, calendar: calendar),
            "A souvenir kept at 9am is inside the morning window whatever it is tagged"
        )
    }

    func testASouvenirFromAnEarlierWindowDoesNotSuppressALaterOne() {
        guard let evening = DailyCheckInCadence.windows.first(where: { $0.id == "evening" }) else {
            return XCTFail("no evening window")
        }
        let morningKeep = souvenir(at: moment(hour: 9), tags: ["souvenir", "onboarding-first-souvenir"])
        XCTAssertFalse(
            DailyCheckInCadence.window(evening, contains: morningKeep.createdAt, calendar: calendar),
            "The morning's sentence should not close the evening's door"
        )
    }

    func testTheOldTagRouteStillWorks() {
        guard let midday = DailyCheckInCadence.windows.first(where: { $0.id == "midday" }) else {
            return XCTFail("no midday window")
        }
        // A page tagged for the window but created outside it — an edited or
        // migrated page — must still count, which is why the tag test stays.
        let tagged = souvenir(at: moment(hour: 22), tags: ["souvenir", "check-in-window:midday"])
        XCTAssertTrue(tagged.tags.contains("check-in-window:\(midday.id)"))
        XCTAssertFalse(DailyCheckInCadence.window(midday, contains: tagged.createdAt, calendar: calendar))
    }
}
