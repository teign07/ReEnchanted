import XCTest
@testable import InsideCoverCore

final class TheBleedTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 6, day: day, hour: hour))!
    }

    private func septemberDate(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 9, day: day, hour: hour))!
    }

    private func interestFact(_ id: String, _ answer: String) -> SelfFact {
        SelfFact(
            id: "fact-\(id)",
            questionID: id,
            question: "What's an interest of yours?",
            answer: answer,
            bookTranslation: "",
            sensitivity: .delight,
            usePermission: .quoteAllowed,
            tags: ["interest"],
            createdAt: date(1, hour: 9),
            updatedAt: date(1, hour: 9)
        )
    }

    private var day: BookDay {
        BookDay(id: "2026-06-10", date: date(10, hour: 0), pages: [])
    }

    func testEditionKindFollowsTheClock() {
        XCTAssertEqual(TheBleedEditionBuilder.editionKind(for: date(10, hour: 7), calendar: calendar), .morning)
        XCTAssertEqual(TheBleedEditionBuilder.editionKind(for: date(10, hour: 12), calendar: calendar), .morning)
        XCTAssertNil(TheBleedEditionBuilder.editionKind(for: date(10, hour: 14), calendar: calendar))
        XCTAssertEqual(TheBleedEditionBuilder.editionKind(for: date(10, hour: 18), calendar: calendar), .evening)
    }

    func testAnnouncementCarriesBriefsAndInterest() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing"), interestFact("interest-02", "weird history")]
        inputs.bleedIssueNumber = 12
        let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: date(10, hour: 8), calendar: calendar)
        XCTAssertNotNil(announcement)
        XCTAssertEqual(announcement?.type, .theBleed)
        XCTAssertTrue(announcement?.payload.headline.contains("Issue #12") == true)
        XCTAssertTrue(announcement?.prompt.contains("The newest edition") == true)
        let briefs = TheBleedEditionBuilder.decodedBriefs(announcement?.payload.metadata["bleedBriefs"] ?? "")
        XCTAssertTrue(briefs.contains { $0.id == "front-page" && $0.needsLocalBrain })
        XCTAssertTrue(briefs.contains { $0.id == "weather-desk" && !$0.needsLocalBrain })
        XCTAssertTrue(briefs.contains { $0.id == "interest-desk" })
        XCTAssertFalse((announcement?.payload.metadata["bleedInterest"] ?? "").isEmpty)
    }

    func testAnnouncementCarriesActiveWorldEventPacket() {
        var inputs = BookSourceInputs.empty
        inputs.bleedIssueNumber = 13
        let september = BookDay(id: "2026-09-10", date: septemberDate(10, hour: 0), pages: [])
        let announcement = TheBleedEditionBuilder.announcementSurface(for: september, inputs: inputs, now: septemberDate(10, hour: 8), calendar: calendar)

        XCTAssertEqual(announcement?.payload.metadata["worldEventIDs"], "dictionary-rebellion")
        XCTAssertTrue(announcement?.payload.metadata["worldEventBleedPacket"]?.contains("Treat the rebellion as live campus news") == true)
        XCTAssertTrue(announcement?.payload.metadata["tags"]?.contains("event:dictionary-rebellion") == true)
        XCTAssertTrue(announcement?.payload.body.contains("Special bulletin: The Dictionary Rebellion") == true)
    }

    func testMorningAndEveningPickDifferentInterests() {
        let facts = [interestFact("interest-01", "sailing"), interestFact("interest-02", "weird history")]
        let morning = TheBleedEditionBuilder.selectedInterest(from: facts, dayID: "2026-06-10", kind: .morning)
        let evening = TheBleedEditionBuilder.selectedInterest(from: facts, dayID: "2026-06-10", kind: .evening)
        XCTAssertNotNil(morning)
        XCTAssertNotNil(evening)
        XCTAssertNotEqual(morning, evening)
    }

    func testKeptEditionSuppressesAnnouncementForThatSlot() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing")]
        let slot = TheBleedEditionBuilder.slotID(for: .morning, day: day)
        var keptDay = day
        keptDay.pages = [
            BookPage(id: "kept-bleed", type: .theBleed, createdAt: date(10, hour: 9), promptText: "The Bleed", userInput: "Edition body", tags: [slot])
        ]
        XCTAssertNil(TheBleedEditionBuilder.announcementSurface(for: keptDay, inputs: inputs, now: date(10, hour: 10), calendar: calendar))
        // Evening still publishes.
        XCTAssertNotNil(TheBleedEditionBuilder.announcementSurface(for: keptDay, inputs: inputs, now: date(10, hour: 18), calendar: calendar))
    }

    func testAlmanacUsesTodayInTheMorningAndTomorrowInTheEvening() {
        var inputs = BookSourceInputs.empty
        inputs.calendarEvents = [
            CalendarEventSignal(id: "today", title: "Harbor walk", startsAt: date(10, hour: 15), isAllDay: false),
            CalendarEventSignal(id: "tomorrow", title: "Ferry to town", startsAt: date(11, hour: 9), isAllDay: false)
        ]
        let morning = TheBleedEditionBuilder.almanacColumn(kind: .morning, inputs: inputs, now: date(10, hour: 8), calendar: calendar)
        XCTAssertTrue(morning.contains("Harbor walk"))
        XCTAssertFalse(morning.contains("Ferry to town"))
        let evening = TheBleedEditionBuilder.almanacColumn(kind: .evening, inputs: inputs, now: date(10, hour: 18), calendar: calendar)
        XCTAssertTrue(evening.contains("Ferry to town"))
        XCTAssertFalse(evening.contains("Harbor walk"))
        XCTAssertTrue(evening.hasPrefix("Tomorrow"))
    }

    func testWeatherBriefCanRefreshFromPlainForecastAtPressTime() throws {
        let staleBriefs = TheBleedEditionBuilder.columnBriefs(
            kind: .morning,
            day: day,
            inputs: .empty,
            interest: nil,
            now: date(10, hour: 8),
            calendar: calendar
        )
        let staleWeather = try XCTUnwrap(staleBriefs.first { $0.id == "weather-desk" })
        XCTAssertTrue(staleWeather.composedBody.contains("sky declined to file"))

        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Current: Rain, 64 F | Forecast: showers later",
            source: "Open-Meteo",
            currentTemperature: "64 F",
            forecast: "showers later",
            conditionSymbolName: "cloud.rain"
        )

        let refreshed = TheBleedEditionBuilder.refreshingWeatherBriefs(staleBriefs, kind: .morning, inputs: inputs)
        let weather = try XCTUnwrap(refreshed.first { $0.id == "weather-desk" })

        XCTAssertTrue(weather.composedBody.contains("Current: Rain, 64 F"))
        XCTAssertFalse(weather.composedBody.contains("Academy's own translation"))
    }

    func testWeatherBriefStillUsesGeneratedEnchantedForecastWhenAvailable() throws {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Current: Fog, 55 F | Forecast: mist through noon",
            source: "Open-Meteo",
            currentTemperature: "55 F",
            forecast: "mist through noon",
            conditionSymbolName: "cloud.fog"
        )
        inputs.enchantedWeather = EnchantedWeatherSignal(
            summary: "Fog, 55 F",
            enchantified: "The world is speaking in pencil.",
            selector: "gemma-weather",
            symbolName: "cloud.fog"
        )

        let briefs = TheBleedEditionBuilder.columnBriefs(
            kind: .evening,
            day: day,
            inputs: .empty,
            interest: nil,
            now: date(10, hour: 18),
            calendar: calendar
        )
        let refreshed = TheBleedEditionBuilder.refreshingWeatherBriefs(briefs, kind: .evening, inputs: inputs)
        let weather = try XCTUnwrap(refreshed.first { $0.id == "weather-desk" })

        XCTAssertTrue(weather.composedBody.contains("Current: Fog, 55 F"))
        XCTAssertTrue(weather.composedBody.contains("The Academy's own translation: The world is speaking in pencil."))
    }

    func testCompositedBodyReadsLikeAPaper() {
        let briefs = TheBleedEditionBuilder.columnBriefs(
            kind: .morning,
            day: day,
            inputs: .empty,
            interest: "sailing",
            now: date(10, hour: 8),
            calendar: calendar
        )
        let columns = briefs.map { brief in
            (brief: brief, body: brief.needsLocalBrain ? "Column text for \(brief.id)." : brief.composedBody)
        }
        let body = TheBleedEditionBuilder.compositedBody(kind: .morning, issueNumber: 7, columns: columns, now: date(10, hour: 8), calendar: calendar)
        XCTAssertTrue(body.contains("THE BLEED - MORNING EDITION"))
        XCTAssertTrue(body.contains("Issue #7"))
        XCTAssertTrue(body.contains("CASEMENT WEATHER"))
        XCTAssertTrue(body.contains("THE READER'S SHELF: SAILING"))
        XCTAssertTrue(body.contains("P. Blackletter"))
    }

    func testFrontPagePacketIncludesWorldEventDesk() {
        let september = BookDay(id: "2026-09-10", date: septemberDate(10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs = inputs.resolvingWorldEvents(for: september, now: septemberDate(10, hour: 8))

        let packet = TheBleedEditionBuilder.frontPagePacket(kind: .morning, day: september, inputs: inputs)

        XCTAssertTrue(packet.contains("Active world-event desk"))
        XCTAssertTrue(packet.contains("The Dictionary Rebellion"))
        XCTAssertTrue(packet.contains("Treat the rebellion as live campus news"))
    }

    func testPreparedCopyCarriesProseAndDropsPlaceholder() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing")]
        let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: date(10, hour: 8), calendar: calendar)!
        let prepared = TheBleedEditionBuilder.preparedCopy(of: announcement, body: "THE PAPER", interestSources: "https://example.com")
        XCTAssertEqual(prepared.payload.metadata["bleedProse"], "THE PAPER")
        XCTAssertNil(prepared.payload.metadata["placeholder"])
        XCTAssertEqual(prepared.payload.body, "THE PAPER")
        XCTAssertEqual(prepared.id, announcement.id)
        XCTAssertFalse(SurfaceReadinessState(surface: prepared).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(surface: announcement).needsLocalBrainToOpen)
    }

    func testAdapterPrefersPreparedEdition() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing")]
        let now = date(10, hour: 8)
        let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: now, calendar: calendar)!
        inputs.preparedBleedEditionSurface = TheBleedEditionBuilder.preparedCopy(of: announcement, body: "THE PAPER", interestSources: "")
        let pages = TheBleedPageSourceAdapter().candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].payload.metadata["bleedProse"], "THE PAPER")
    }
}
