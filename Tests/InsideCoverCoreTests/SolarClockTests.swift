import XCTest
@testable import InsideCoverCore

/// The Windows family is only worth having if the times are right, so these
/// check the NOAA equations against published sunrise/sunset values rather
/// than against themselves.
final class SolarClockTests: XCTestCase {

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func localClock(_ moment: Date, in calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: moment)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private func minutesIntoDay(_ moment: Date, in calendar: Calendar) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: moment)
        return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0)
    }

    /// Full precision. Around the earliest sunset a whole week of evenings sit
    /// inside the same clock minute, so anything coarser picks a tie at random.
    private func secondsIntoDay(_ moment: Date, in calendar: Calendar) -> Double {
        moment.timeIntervalSince(calendar.startOfDay(for: moment))
    }

    private func assertWithin(
        _ moment: Date?,
        of expected: String,
        minutes tolerance: Double,
        in calendar: Calendar,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let moment else {
            return XCTFail("\(label): no crossing computed", file: file, line: line)
        }
        let pieces = expected.split(separator: ":").compactMap { Double($0) }
        let target = pieces[0] * 60 + pieces[1]
        let actual = minutesIntoDay(moment, in: calendar)
        XCTAssertEqual(
            actual, target, accuracy: tolerance,
            "\(label): expected ~\(expected), got \(localClock(moment, in: calendar))",
            file: file, line: line
        )
    }

    // MARK: Against published times

    func testLondonMidsummer() {
        // London, 21 June 2026 (BST): sunrise 04:43, sunset 21:21.
        let calendar = calendar("Europe/London")
        let london = ReaderCoordinate(latitude: 51.5074, longitude: -0.1278)
        let day = date(2026, 6, 21, in: calendar)

        assertWithin(SolarClock.sunrise(on: day, at: london, calendar: calendar),
                     of: "04:43", minutes: 3, in: calendar, "London midsummer sunrise")
        assertWithin(SolarClock.sunset(on: day, at: london, calendar: calendar),
                     of: "21:21", minutes: 3, in: calendar, "London midsummer sunset")
    }

    func testNewYorkMidwinter() {
        // New York, 21 December 2026 (EST): sunrise 07:16, sunset 16:32.
        let calendar = calendar("America/New_York")
        let newYork = ReaderCoordinate(latitude: 40.7128, longitude: -74.0060)
        let day = date(2026, 12, 21, in: calendar)

        assertWithin(SolarClock.sunrise(on: day, at: newYork, calendar: calendar),
                     of: "07:16", minutes: 3, in: calendar, "New York midwinter sunrise")
        assertWithin(SolarClock.sunset(on: day, at: newYork, calendar: calendar),
                     of: "16:32", minutes: 3, in: calendar, "New York midwinter sunset")
    }

    func testSouthernHemisphereIsNotJustTheNorthUpsideDown() {
        // Sydney, 21 December 2026 (AEDT): sunrise 05:41, sunset 20:05.
        let calendar = calendar("Australia/Sydney")
        let sydney = ReaderCoordinate(latitude: -33.8688, longitude: 151.2093)
        let day = date(2026, 12, 21, in: calendar)

        assertWithin(SolarClock.sunrise(on: day, at: sydney, calendar: calendar),
                     of: "05:41", minutes: 4, in: calendar, "Sydney midsummer sunrise")
        assertWithin(SolarClock.sunset(on: day, at: sydney, calendar: calendar),
                     of: "20:05", minutes: 4, in: calendar, "Sydney midsummer sunset")
    }

    func testEquatorialDaysAreAlwaysAboutTwelveHours() {
        let calendar = calendar("Africa/Nairobi")
        let nairobi = ReaderCoordinate(latitude: -1.2921, longitude: 36.8219)
        for month in [1, 4, 7, 10] {
            let day = date(2026, month, 15, in: calendar)
            guard let rise = SolarClock.sunrise(on: day, at: nairobi, calendar: calendar),
                  let set = SolarClock.sunset(on: day, at: nairobi, calendar: calendar) else {
                return XCTFail("Nairobi should always have a sunrise and a sunset")
            }
            let hours = set.timeIntervalSince(rise) / 3600
            XCTAssertEqual(hours, 12.1, accuracy: 0.3, "Month \(month) ran \(hours)h")
        }
    }

    // MARK: Polar behaviour

    func testThePolarDayHasNoSunsetAndTheBookSaysNothing() {
        let calendar = calendar("Europe/Oslo")
        // Longyearbyen, well above the arctic circle.
        let svalbard = ReaderCoordinate(latitude: 78.2232, longitude: 15.6267)

        XCTAssertNil(SolarClock.sunset(on: date(2026, 6, 21, in: calendar), at: svalbard, calendar: calendar),
                     "Midsummer above the arctic circle has no sunset")
        XCTAssertNil(SolarClock.sunrise(on: date(2026, 12, 21, in: calendar), at: svalbard, calendar: calendar),
                     "Midwinter above the arctic circle has no sunrise")
        XCTAssertTrue(
            WindowAlmanac.celebrations(at: date(2026, 6, 21, in: calendar), coordinate: svalbard, calendar: calendar)
                .allSatisfy { $0.id != "window-gilding" && $0.id != "window-blue" },
            "No golden hour should be claimed where the sun does not set"
        )
    }

    // MARK: Ordering

    func testTheWindowsFallInTheRightOrder() {
        let calendar = calendar("America/Chicago")
        let chicago = ReaderCoordinate(latitude: 41.8781, longitude: -87.6298)
        let day = date(2026, 9, 15, in: calendar)

        let sunrise = SolarClock.sunrise(on: day, at: chicago, calendar: calendar)!
        let morningGold = SolarClock.ascending(through: SolarClock.Elevation.goldenHour, on: day, at: chicago, calendar: calendar)!
        let noon = SolarClock.solarNoon(on: day, at: chicago, calendar: calendar)
        let eveningGold = SolarClock.descending(through: SolarClock.Elevation.goldenHour, on: day, at: chicago, calendar: calendar)!
        let sunset = SolarClock.sunset(on: day, at: chicago, calendar: calendar)!
        let civil = SolarClock.descending(through: SolarClock.Elevation.civil, on: day, at: chicago, calendar: calendar)!

        XCTAssertLessThan(sunrise, morningGold)
        XCTAssertLessThan(morningGold, noon)
        XCTAssertLessThan(noon, eveningGold)
        XCTAssertLessThan(eveningGold, sunset)
        XCTAssertLessThan(sunset, civil)
    }

    /// Solar noon is the middle of the daylight, not twelve o'clock.
    func testSolarNoonSitsBetweenSunriseAndSunset() {
        let calendar = calendar("Europe/Madrid")
        let madrid = ReaderCoordinate(latitude: 40.4168, longitude: -3.7038)
        let day = date(2026, 3, 10, in: calendar)

        let sunrise = SolarClock.sunrise(on: day, at: madrid, calendar: calendar)!
        let sunset = SolarClock.sunset(on: day, at: madrid, calendar: calendar)!
        let noon = SolarClock.solarNoon(on: day, at: madrid, calendar: calendar)
        let midpoint = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) / 2)

        XCTAssertEqual(noon.timeIntervalSince(midpoint), 0, accuracy: 90, "Solar noon should bisect the day")
    }

    // MARK: The two scandals

    /// The earliest sunset lands in early December, well before the solstice.
    func testTheEarliestSunsetArrivesBeforeTheSolstice() {
        let calendar = calendar("America/New_York")
        let newYork = ReaderCoordinate(latitude: 40.7128, longitude: -74.0060)

        var earliest: (day: Int, minutes: Double)?
        for day in 25...45 {  // 25 Nov through 15 Dec
            let moment = calendar.date(byAdding: .day, value: day - 25, to: date(2026, 11, 25, in: calendar))!
            let sunset = SolarClock.sunset(on: moment, at: newYork, calendar: calendar)!
            let minutes = secondsIntoDay(sunset, in: calendar)
            if earliest == nil || minutes < earliest!.minutes {
                earliest = (day, minutes)
            }
        }
        let earliestDate = calendar.date(byAdding: .day, value: earliest!.day - 25, to: date(2026, 11, 25, in: calendar))!
        let parts = calendar.dateComponents([.month, .day], from: earliestDate)
        XCTAssertEqual(parts.month, 12)
        XCTAssertTrue((5...11).contains(parts.day ?? 0),
                      "Earliest New York sunset should fall around 7-8 December, got \(parts.day ?? 0)")
    }

    /// And the latest sunrise lands in early January, after it.
    func testTheLatestSunriseArrivesAfterTheSolstice() {
        let calendar = calendar("America/New_York")
        let newYork = ReaderCoordinate(latitude: 40.7128, longitude: -74.0060)

        var latest: (offset: Int, minutes: Double)?
        for offset in 0...30 {  // 22 Dec through 21 Jan
            let moment = calendar.date(byAdding: .day, value: offset, to: date(2026, 12, 22, in: calendar))!
            let sunrise = SolarClock.sunrise(on: moment, at: newYork, calendar: calendar)!
            let minutes = secondsIntoDay(sunrise, in: calendar)
            if latest == nil || minutes > latest!.minutes {
                latest = (offset, minutes)
            }
        }
        let latestDate = calendar.date(byAdding: .day, value: latest!.offset, to: date(2026, 12, 22, in: calendar))!
        let parts = calendar.dateComponents([.month, .day], from: latestDate)
        XCTAssertEqual(parts.month, 1)
        XCTAssertTrue((1...8).contains(parts.day ?? 0),
                      "Latest New York sunrise should fall in the first week of January, got \(parts.day ?? 0)")
    }
}
