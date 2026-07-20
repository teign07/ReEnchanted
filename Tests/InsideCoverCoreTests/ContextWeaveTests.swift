import XCTest
@testable import InsideCoverCore

/// The Context Weave — the general relationship finder. It may only claim a
/// connection between how the reader writes and the world the pages were kept
/// in when both sides of the comparison exist, the evidence spans real days,
/// and the context was recorded at keep time rather than guessed later.
final class ContextWeaveTests: XCTestCase {

    // A Monday, so daysAgo arithmetic lands on predictable weekdays.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 12))!

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func page(
        _ text: String,
        at date: Date,
        id: String = UUID().uuidString,
        weather: [String]? = nil,
        bodyScore: Int? = nil,
        events: Int? = nil
    ) -> BookPage {
        var context: BookPageContextSnapshot?
        if weather != nil || bodyScore != nil || events != nil {
            context = BookPageContextSnapshot(
                at: date,
                weatherTags: weather ?? [],
                bodyScore: bodyScore,
                calendarEventCount: events
            )
        }
        return BookPage(
            id: id,
            type: .diary,
            createdAt: date,
            promptText: "Prompt",
            userInput: text,
            origin: .userAuthored,
            context: context
        )
    }

    /// A BookDay whose id matches its pages' calendar day — `capturedPages`
    /// windows on the parsed id, so a mislabeled day hides its pages.
    private func day(pages: [BookPage]) -> BookDay {
        let anchor = pages.first?.createdAt ?? now
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: anchor)
        let id = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
        return BookDay(id: id, date: Calendar.current.startOfDay(for: anchor), pages: pages)
    }

    private func days(from pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .values
            .map { day(pages: $0.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.id < $1.id }
    }

    private let heavyLine = "The kitchen felt lonely tonight and the tea went cold while I sat tired."
    private let plainLine = "The counter held three oranges and the window showed the neighbor's ladder."

    /// Five rainy heavy pages across five days against eight plain bright-sky
    /// pages — the canonical "sadder sentences on rain days" archive.
    private func rainArchive(dryWeather: [String]? = ["bright"]) -> [BookDay] {
        let rainy = (0..<5).map { index in
            page(heavyLine, at: daysAgo(2 + index * 2), id: "rain-\(index)", weather: ["rain"])
        }
        let dry = (0..<8).map { index in
            page(plainLine, at: daysAgo(3 + index * 2), id: "dry-\(index)", weather: dryWeather)
        }
        return days(from: rainy + dry)
    }

    // MARK: - Tone

    func testToneReadsBrightAndHeavyInk() {
        XCTAssertEqual(ContextWeave.tone(of: "We laughed until the grateful kettle joined in."), .bright)
        XCTAssertEqual(ContextWeave.tone(of: heavyLine), .heavy)
        XCTAssertNil(ContextWeave.tone(of: plainLine), "Neutral prose carries no tone verdict.")
        XCTAssertNil(ContextWeave.tone(of: "A happy morning, then a lonely evening."), "Ties are never broken on the reader's behalf.")
    }

    func testToneLexiconsExcludeWeatherAndHourWords() {
        // If "bright" or "dark" counted as tone, a clear sky or a late hour
        // could predict its own connection and the reading would be circular.
        let forbidden = ["rain", "rainy", "storm", "snow", "fog", "wind", "cloud",
                         "bright", "sun", "sunny", "hot", "cold", "warm", "grey",
                         "gray", "dark", "night", "morning"]
        for word in forbidden {
            XCTAssertFalse(ContextWeave.brightInkWords.contains(word), "\(word) must not read as bright ink")
            XCTAssertFalse(ContextWeave.heavyInkWords.contains(word), "\(word) must not read as heavy ink")
        }
    }

    // MARK: - Manner × context connections

    func testFindsHeavierInkInTheRain() throws {
        let connections = ContextWeave.connections(days: rainArchive())
        let rainHeavy = try XCTUnwrap(
            connections.first { $0.facetID == "weather:rain" && $0.id.contains("heavy-ink") }
        )
        XCTAssertEqual(rainHeavy.kind, .manner)
        XCTAssertTrue(rainHeavy.line.contains("while it was raining"), rainHeavy.line)
        XCTAssertTrue(rainHeavy.line.contains("five"), "Counts are spelled into the claim: \(rainHeavy.line)")
        XCTAssertEqual(rainHeavy.inHits, 5)
        XCTAssertEqual(rainHeavy.outHits, 0)
        XCTAssertFalse(rainHeavy.evidencePageIDs.isEmpty)
    }

    func testWeatherConnectionNeedsWeatherRecordedOnBothSides() {
        // The dry pages carry no snapshot at all: there is no honest
        // out-group, so the rain claim must stay unspoken.
        let connections = ContextWeave.connections(days: rainArchive(dryWeather: nil))
        XCTAssertFalse(
            connections.contains { $0.facetID.hasPrefix("weather:") },
            "No weather connection without weather recorded on both sides."
        )
    }

    func testStaysQuietWithoutEnoughEvidence() {
        let rainy = (0..<3).map { index in
            page(heavyLine, at: daysAgo(2 + index * 2), id: "rain-\(index)", weather: ["rain"])
        }
        let dry = (0..<8).map { index in
            page(plainLine, at: daysAgo(3 + index * 2), id: "dry-\(index)", weather: ["bright"])
        }
        let connections = ContextWeave.connections(days: days(from: rainy + dry))
        XCTAssertFalse(
            connections.contains { $0.facetID == "weather:rain" },
            "Three pages are a coincidence, not a connection."
        )
    }

    func testFindsQuestionsAfterDarkWithoutAnySnapshots() throws {
        // Hour connections read createdAt, so the whole archive qualifies
        // even before any context snapshots exist.
        let night = (0..<5).map { index in
            page("Why does the house hum louder when everyone sleeps?", at: daysAgo(1 + index * 2, hour: 22), id: "night-\(index)")
        }
        let daytime = (0..<8).map { index in
            page(plainLine, at: daysAgo(2 + index * 2, hour: 9), id: "day-\(index)")
        }
        let connections = ContextWeave.connections(days: days(from: night + daytime))
        let asking = try XCTUnwrap(
            connections.first { $0.facetID == "hour:night" && $0.id.contains("asking") }
        )
        XCTAssertTrue(asking.line.contains("after dark"), asking.line)
    }

    // MARK: - Subject × context connections

    func testFindsSubjectThatOnlyVisitsOnWeekends() throws {
        // now is a Monday: daysAgo(1)/daysAgo(2) are Sunday/Saturday, and a
        // week earlier daysAgo(8)/daysAgo(9) are again.
        let weekend = [1, 2, 8, 9].enumerated().map { index, back in
            page(
                index < 3 ? "The harbor kept its boats folded like letters." : plainLine,
                at: daysAgo(back),
                id: "weekend-\(index)"
            )
        }
        let weekdays = [3, 4, 5, 6, 10, 11, 12].enumerated().map { index, back in
            page(plainLine, at: daysAgo(back, hour: 9 + index % 3), id: "weekday-\(index)")
        }
        let connections = ContextWeave.connections(days: days(from: weekend + weekdays))
        let harbor = try XCTUnwrap(
            connections.first { $0.kind == .subject && $0.facetID == "week:weekend" && $0.id.contains("harbor") }
        )
        XCTAssertTrue(harbor.line.contains("Harbor"), harbor.line)
        XCTAssertTrue(harbor.line.contains("on weekends"), harbor.line)
        XCTAssertTrue(harbor.line.contains("never"), harbor.line)
    }

    func testSubjectSpokenOnWeekdaysTooStaysUnclaimed() {
        let weekend = [1, 2, 8, 9].map { back in
            page("The harbor kept its boats folded like letters.", at: daysAgo(back), id: "weekend-\(back)")
        }
        let weekdays = [3, 4, 5, 6, 10, 11, 12].enumerated().map { index, back in
            page(
                index == 0 ? "Past the harbor on the way to the dentist." : plainLine,
                at: daysAgo(back),
                id: "weekday-\(index)"
            )
        }
        let connections = ContextWeave.connections(days: days(from: weekend + weekdays))
        XCTAssertFalse(
            connections.contains { $0.kind == .subject && $0.id.contains("harbor") },
            "One weekday mention breaks the 'only ever' claim."
        )
    }

    // MARK: - Surfacing through Book Notices

    private func noticeInputs(days: [BookDay]) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = days
        return inputs
    }

    func testNoticesAdapterSpeaksTheConnectionWithReceipts() throws {
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: noticeInputs(days: rainArchive()),
            now: now
        )
        let surface = try XCTUnwrap(surfaces.first { $0.payload.metadata["connectionKind"] == "context" })
        XCTAssertTrue(surface.payload.body.contains("while it was raining"), surface.payload.body)
        XCTAssertTrue(surface.payload.body.contains("not diagnosing"), "Observation, never a verdict: \(surface.payload.body)")
        let tags = try XCTUnwrap(surface.payload.metadata["tags"])
        XCTAssertTrue(tags.contains("connection-spoke:context-weather:rain-heavy-ink"), tags)
        XCTAssertNotNil(surface.payload.metadata["tinyPatternCards"], "Evidence cards travel with the claim.")
    }

    func testSpokenConnectionRestsInsteadOfRepeating() throws {
        var archive = rainArchive()
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: []),
            context: CuratorContext.make(for: BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])),
            inputs: noticeInputs(days: archive),
            now: now
        )
        let surface = try XCTUnwrap(surfaces.first { $0.payload.metadata["connectionKind"] == "context" })
        let spokeTag = try XCTUnwrap(
            surface.payload.metadata["tags"]?
                .split(separator: ",")
                .map(String.init)
                .first { $0.hasPrefix("connection-spoke:") }
        )

        // The reader keeps the notice; the spoke tag now lives in the archive.
        let keptNotice = BookPage(
            id: "kept-context-notice",
            type: .bookNotices,
            createdAt: daysAgo(1, hour: 18),
            promptText: "The Book Notices",
            userInput: "",
            tags: ["book-notices", spokeTag]
        )
        if let index = archive.firstIndex(where: { $0.id == BookDay.id(for: keptNotice.createdAt) }) {
            archive[index].pages.append(keptNotice)
        } else {
            archive.append(day(pages: [keptNotice]))
        }

        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let repeated = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: noticeInputs(days: archive),
            now: now
        ).filter { surface in
            surface.payload.metadata["connectionKind"] == "context"
                && (surface.payload.metadata["tags"] ?? "").contains(spokeTag)
        }
        XCTAssertTrue(repeated.isEmpty, "A spoken connection rests; silence beats a rerun.")
    }

    func testKeptPageContextRoundTripsPlaceAndPrivateChartReferences() throws {
        let context = BookPageContextSnapshot(
            at: now,
            weatherTags: ["Rain", "wind"],
            bodyScore: 74,
            calendarEventCount: 3,
            nearbyAnchorID: "front-porch",
            locationLabel: "Home",
            innerWeatherEntryID: "mood-entry-1",
            fuelEntryID: "fuel-entry-1"
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: data
        )

        XCTAssertEqual(decoded.weatherTags, ["rain", "wind"])
        XCTAssertEqual(decoded.locationLabel, "Home")
        XCTAssertEqual(decoded.nearbyAnchorID, "front-porch")
        XCTAssertEqual(decoded.innerWeatherEntryID, "mood-entry-1")
        XCTAssertEqual(decoded.fuelEntryID, "fuel-entry-1")
        XCTAssertEqual(decoded.bodyScore, 74)
        XCTAssertEqual(decoded.calendarEventCount, 3)
    }
}
