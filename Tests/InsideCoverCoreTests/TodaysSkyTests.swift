import XCTest
@testable import InsideCoverCore

final class TodaysSkyTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 21) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    func testZodiacSignBoundaries() {
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: 0).name, "Aries")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: 29).name, "Aries")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: 30).name, "Taurus")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: 359).name, "Pisces")
        // Wraps cleanly past 360 and below 0.
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: 360).name, "Aries")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: -1).name, "Pisces")
    }

    func testSunSignTracksTheCalendar() {
        // The Sun's tropical sign on familiar dates (mid-sign, away from cusps).
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: SkyEphemeris.sunLongitude(on: date(2026, 1, 15))).name, "Capricorn")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: SkyEphemeris.sunLongitude(on: date(2026, 4, 15))).name, "Aries")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: SkyEphemeris.sunLongitude(on: date(2026, 7, 15))).name, "Cancer")
        XCTAssertEqual(Zodiac.sign(forEclipticLongitude: SkyEphemeris.sunLongitude(on: date(2026, 11, 15))).name, "Scorpio")
    }

    func testMoonCyclesThroughEverySignInAMonth() {
        var seen = Set<String>()
        var probe = date(2026, 3, 1)
        for _ in 0..<28 {
            seen.insert(Zodiac.sign(forEclipticLongitude: SkyEphemeris.moonLongitude(on: probe)).name)
            probe = probe.addingTimeInterval(86_400)
        }
        // The Moon laps the zodiac in ~27.3 days; it should touch all twelve.
        XCTAssertEqual(seen.count, 12, "the Moon visits every sign within a month")
    }

    func testLightTrendAroundSolsticesAndEquinoxes() {
        // Northern: lengthening after the winter solstice, drawing in after the summer one.
        XCTAssertEqual(SkyAlmanac.lightTrend(on: date(2026, 2, 1), hemisphere: .northern), .lengthening)
        XCTAssertEqual(SkyAlmanac.lightTrend(on: date(2026, 8, 1), hemisphere: .northern), .shortening)
        // The southern hemisphere mirrors the same dates.
        XCTAssertEqual(SkyAlmanac.lightTrend(on: date(2026, 2, 1), hemisphere: .southern), .shortening)
        // Near an equinox the year is in balance.
        XCTAssertEqual(SkyAlmanac.lightTrend(on: date(2026, 3, 20), hemisphere: .northern), .nearBalance)
    }

    func testNextEventIsInTheFutureAndNamed() {
        let event = SkyAlmanac.nextEvent(on: date(2026, 7, 7))
        XCTAssertGreaterThanOrEqual(event.daysAway, 0)
        XCTAssertFalse(event.name.isEmpty)
        XCTAssertTrue(["full moon", "new moon", "meteor shower"].contains(event.kind))
        XCTAssertGreaterThanOrEqual(event.date, Calendar.current.startOfDay(for: date(2026, 7, 7)))
    }

    func testReadingCarriesEveryFieldAndHemisphereMatters() {
        let north = SkyAlmanac.reading(on: date(2026, 7, 7), hemisphere: .northern)
        XCTAssertFalse(north.notes.isEmpty)
        XCTAssertFalse(north.openingLine.isEmpty)
        XCTAssertEqual(north.hemisphere, .northern)
        let south = SkyAlmanac.reading(on: date(2026, 7, 7), hemisphere: .southern)
        // Same night, opposite turning of the light.
        XCTAssertNotEqual(north.lightTrend, south.lightTrend)
    }

    func testSkyAdapterSurfacesOnceInTheEvening() {
        let day = BookDay(id: BookDay.id(for: date(2026, 7, 7)), date: Calendar.current.startOfDay(for: date(2026, 7, 7)), pages: [])
        let context = CuratorContext.make(for: day)
        let inputs = BookSourceInputs()
        let adapter = TodaysSkyPageSourceAdapter()

        let evening = adapter.candidates(for: day, context: context, inputs: inputs, now: date(2026, 7, 7, 21))
        XCTAssertEqual(evening.count, 1, "the sky page surfaces in the evening")
        XCTAssertEqual(evening.first?.type, .todaysSky)
        XCTAssertFalse(evening.first?.payload.metadata["moonSign"]?.isEmpty ?? true)

        let noon = adapter.candidates(for: day, context: context, inputs: inputs, now: date(2026, 7, 7, 12))
        XCTAssertTrue(noon.isEmpty, "the sky page waits for evening")
    }
}
