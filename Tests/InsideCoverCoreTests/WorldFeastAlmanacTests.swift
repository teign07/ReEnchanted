import XCTest
@testable import InsideCoverCore

/// Religious dates are the one place in this app where being wrong is worse
/// than being silent, so these check the computed days against published
/// dates rather than against the implementation.
final class WorldFeastAlmanacTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func ids(on date: Date) -> Set<String> {
        Set(WorldFeastAlmanac.celebrations(on: date, calendar: calendar).map(\.id))
    }

    private func assertFalls(
        _ id: String,
        on year: Int, _ month: Int, _ day: Int,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            ids(on: date(year, month, day)).contains(id),
            "\(id) should fall on \(year)-\(month)-\(day)",
            file: file, line: line
        )
        // And nowhere adjacent, so an off-by-one cannot pass.
        for offset in [-1, 1] {
            let neighbour = calendar.date(byAdding: .day, value: offset, to: date(year, month, day))!
            XCTAssertFalse(
                ids(on: neighbour).contains(id),
                "\(id) also fired \(offset) day(s) from \(year)-\(month)-\(day)",
                file: file, line: line
            )
        }
    }

    // MARK: Islamic

    func testIslamicFeastsLandOnPublishedDates() {
        assertFalls("world-ramadan", on: 2026, 2, 18)
        assertFalls("world-ramadan", on: 2027, 2, 8)
        assertFalls("world-eid-fitr", on: 2026, 3, 20)
        assertFalls("world-eid-fitr", on: 2027, 3, 9)
        assertFalls("world-eid-adha", on: 2026, 5, 27)
        assertFalls("world-eid-adha", on: 2027, 5, 16)
        assertFalls("world-hijri-new-year", on: 2026, 6, 16)
        assertFalls("world-ashura", on: 2026, 6, 25)
        assertFalls("world-mawlid", on: 2026, 8, 25)
    }

    // MARK: Jewish
    //
    // ICU keeps Adar I as a permanent month slot, so Nisan is always month 8
    // and Adar always month 7 — in leap years and out of them alike. Getting
    // this wrong puts Passover a month early, so both cases are checked.

    func testJewishFeastsLandOnPublishedDates() {
        assertFalls("world-rosh-hashanah", on: 2026, 9, 12)
        assertFalls("world-yom-kippur", on: 2026, 9, 21)
        assertFalls("world-sukkot", on: 2026, 9, 26)
        assertFalls("world-hanukkah", on: 2026, 12, 5)
        assertFalls("world-shavuot", on: 2026, 5, 22)
    }

    func testPassoverAndPurimSurviveTheHebrewLeapYear() {
        // 2026 and 2028 are ordinary; 2027 and 2030 carry Adar I.
        assertFalls("world-passover", on: 2026, 4, 2)
        assertFalls("world-passover", on: 2027, 4, 22)
        assertFalls("world-passover", on: 2028, 4, 11)
        assertFalls("world-passover", on: 2029, 3, 31)

        assertFalls("world-purim", on: 2026, 3, 3)
        assertFalls("world-purim", on: 2027, 3, 23)
        assertFalls("world-purim", on: 2030, 3, 19)

        // Purim Katan, a month earlier in leap years, is not Purim.
        XCTAssertFalse(ids(on: date(2027, 2, 21)).contains("world-purim"))
        XCTAssertFalse(ids(on: date(2030, 2, 17)).contains("world-purim"))
    }

    // MARK: Christian

    func testEasterAndItsSatellites() {
        // Easter: 5 April 2026, 28 March 2027, 16 April 2028.
        assertFalls("world-easter", on: 2026, 4, 5)
        assertFalls("world-easter", on: 2027, 3, 28)
        assertFalls("world-easter", on: 2028, 4, 16)

        assertFalls("world-good-friday", on: 2026, 4, 3)
        assertFalls("world-ash-wednesday", on: 2026, 2, 18)
        assertFalls("world-mardi-gras", on: 2026, 2, 17)
        assertFalls("world-pentecost", on: 2026, 5, 24)
    }

    func testFixedChristianDays() {
        assertFalls("world-christmas", on: 2026, 12, 25)
        assertFalls("world-epiphany", on: 2027, 1, 6)
        assertFalls("world-all-saints", on: 2026, 11, 1)
    }

    func testOrthodoxDaysRunOnTheOlderCalendar() {
        // Orthodox Christmas: 7 January, drifting to the 8th in 2028.
        assertFalls("world-orthodox-christmas", on: 2026, 1, 7)
        assertFalls("world-orthodox-christmas", on: 2027, 1, 7)
        // Orthodox Easter 2026: 12 April. 2027: 2 May.
        assertFalls("world-orthodox-easter", on: 2026, 4, 12)
        assertFalls("world-orthodox-easter", on: 2027, 5, 2)
    }

    // MARK: East Asian, Persian, Hindu, Buddhist

    func testEastAsianFeastsLandOnPublishedDates() {
        assertFalls("world-lunar-new-year", on: 2026, 2, 17)
        assertFalls("world-lunar-new-year", on: 2027, 2, 6)
        assertFalls("world-lantern", on: 2026, 3, 3)
        assertFalls("world-dragon-boat", on: 2026, 6, 19)
        assertFalls("world-hungry-ghost", on: 2026, 8, 27)
        assertFalls("world-mid-autumn", on: 2026, 9, 25)
        assertFalls("world-double-ninth", on: 2026, 10, 18)
    }

    func testNowruzAndYalda() {
        assertFalls("world-nowruz", on: 2026, 3, 21)
        assertFalls("world-nowruz", on: 2028, 3, 20)
        assertFalls("world-yalda", on: 2026, 12, 21)
    }

    func testHinduTableDates() {
        assertFalls("world-diwali", on: 2026, 11, 8)
        assertFalls("world-diwali", on: 2027, 10, 29)
        assertFalls("world-diwali", on: 2028, 10, 17)
        assertFalls("world-holi", on: 2027, 3, 22)
        assertFalls("world-holi", on: 2028, 3, 10)
    }

    /// Past the end of the verified table the Book says nothing at all, rather
    /// than inventing a date for somebody's holiday.
    func testTabledFeastsGoSilentRatherThanGuess() {
        for month in 1...12 {
            for day in [1, 8, 15, 22, 28] {
                let found = ids(on: date(2050, month, day))
                XCTAssertFalse(found.contains("world-diwali"), "Diwali guessed a date in 2050")
                XCTAssertFalse(found.contains("world-holi"), "Holi guessed a date in 2050")
            }
        }
    }

    func testVesakUsesTheFullMoonOfTheFourthLunarMonth() {
        assertFalls("world-vesak", on: 2026, 5, 31)
        assertFalls("world-vesak", on: 2027, 5, 20)
        assertFalls("world-bodhi", on: 2026, 12, 8)
    }

    // MARK: The odder corners

    func testFloatingFolkFestivals() {
        // La Tomatina: last Wednesday of August. 2026: the 26th.
        assertFalls("world-la-tomatina", on: 2026, 8, 26)
        // Up Helly Aa: last Tuesday of January. 2027: the 26th.
        assertFalls("world-up-helly-aa", on: 2027, 1, 26)
        // Cheese-rolling: late-May bank holiday Monday. 2026: the 25th.
        assertFalls("world-cheese-rolling", on: 2026, 5, 25)
        // Monkey Buffet: last Sunday of November. 2026: the 29th.
        assertFalls("world-monkey-buffet", on: 2026, 11, 29)
    }

    func testFixedFolkFestivals() {
        assertFalls("world-dia-muertos", on: 2026, 11, 2)
        assertFalls("world-noche-rabanos", on: 2026, 12, 23)
        assertFalls("world-groundhog", on: 2027, 2, 2)
        assertFalls("world-sinterklaas", on: 2026, 12, 5)
        assertFalls("world-st-lucia", on: 2026, 12, 13)
        assertFalls("world-walpurgis", on: 2026, 4, 30)
        assertFalls("world-setsubun", on: 2027, 2, 3)
        assertFalls("world-tanabata", on: 2026, 7, 7)
        assertFalls("world-inti-raymi", on: 2026, 6, 24)
        assertFalls("world-vaisakhi", on: 2026, 4, 14)
    }

    // MARK: Promises

    func testEveryFeastCanBeRestedForever() {
        var seen: Set<String> = []
        for offset in 0..<800 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            for feast in WorldFeastAlmanac.celebrations(on: day, calendar: calendar) {
                seen.insert(feast.id)
                XCTAssertTrue(feast.canBeRested, "\(feast.id) has no door out")
                XCTAssertEqual(feast.greyShift, 0, "\(feast.id) leans on the reader's grey")
                XCTAssertEqual(feast.kind, .family)
            }
        }
        XCTAssertGreaterThan(seen.count, 30, "Only \(seen.count) feasts ever fired across two years")

        // And resting one actually silences it.
        let rested = WorldFeastAlmanac.celebrations(
            on: date(2026, 12, 25), restedIDs: ["world-christmas"], calendar: calendar
        )
        XCTAssertFalse(rested.contains { $0.id == "world-christmas" })
    }

    /// The Book is a feral child, not an encyclopedia. Every one of these is a
    /// day it has opinions about.
    func testEveryBlurbKeepsTheBooksVoice() {
        var checked = 0
        var voiceless: [String] = []
        var seen: Set<String> = []

        for offset in 0..<800 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            for feast in WorldFeastAlmanac.celebrations(on: day, calendar: calendar) {
                guard seen.insert(feast.id).inserted else { continue }
                checked += 1
                let text = feast.blurb
                let speaks = text.contains("I ") || text.contains("I'") || text.contains("I,")
                    || text.contains("my ") || text.contains("me ") || text.contains("me.")
                if !speaks { voiceless.append(feast.id) }

                XCTAssertFalse(text.contains("Please"), "\(feast.id) says please")
                XCTAssertFalse(text.lowercased().contains("feel free"), "\(feast.id) is servant speak")
                XCTAssertFalse(feast.invitation.isEmpty, "\(feast.id) invites nothing")
            }
        }
        XCTAssertGreaterThan(checked, 30)
        XCTAssertTrue(voiceless.isEmpty, "The Book vanished from: \(voiceless.joined(separator: ", "))")
    }

    /// Days of mourning must be able to stand down on a hard day.
    func testTheMourningDaysCarryTheGriefFlag() {
        let griefDays = ["world-ashura", "world-yom-kippur", "world-good-friday",
                         "world-obon", "world-dia-muertos", "world-hungry-ghost",
                         "world-all-saints", "world-christmas"]
        var found: Set<String> = []
        for offset in 0..<400 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            for feast in WorldFeastAlmanac.celebrations(on: day, calendar: calendar)
            where griefDays.contains(feast.id) {
                found.insert(feast.id)
                XCTAssertTrue(feast.carriesGrief, "\(feast.id) should carry the grief flag")
            }
        }
        XCTAssertGreaterThan(found.count, 5, "Only found \(found)")
    }

    func testTraditionsAreAllRepresented() {
        var traditions: Set<WorldFeastAlmanac.Tradition> = []
        for offset in 0..<800 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            for feast in WorldFeastAlmanac.celebrations(on: day, calendar: calendar) {
                if let tradition = WorldFeastAlmanac.tradition(of: feast.id) {
                    traditions.insert(tradition)
                }
            }
        }
        XCTAssertEqual(
            traditions.count, WorldFeastAlmanac.Tradition.allCases.count,
            "Missing: \(Set(WorldFeastAlmanac.Tradition.allCases).subtracting(traditions))"
        )
    }
}
