import XCTest
@testable import InsideCoverCore

final class BookTodayTests: XCTestCase {
    func testWeatherBecomesAtmosphereRatherThanDashboardData() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T14:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Fog along the harbor. 61°F.",
            source: "test"
        )

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(edition.form, .weatherMap)
        XCTAssertTrue(edition.headline.contains("Fog along the harbor"))
        XCTAssertEqual(edition.beats.first?.kind, .atTheWindows)
        XCTAssertEqual(edition.beats.first?.symbolName, "cloud.fog")
        XCTAssertFalse(edition.reading.localizedCaseInsensitiveContains("score"))
        XCTAssertFalse(edition.reading.localizedCaseInsensitiveContains("page ready"))
    }

    func testActiveSessionIntentionIsTranslatedIntoBookLanguage() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T09:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.activeBookSessionIntention = BookSessionIntention(
            id: "session",
            dayID: day.id,
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: [],
            evidenceReason: "private test evidence",
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            seed: "stable"
        )

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(edition.form, .observatoryWindow)
        XCTAssertTrue(edition.reading.contains("familiar thing visible again"))
        XCTAssertTrue(edition.reading.contains("A glint is enough"))
        XCTAssertFalse(edition.reading.contains("private test evidence"))
        XCTAssertEqual(edition.beats.last?.kind, .byNightfall)
    }

    func testQuietEditionRefusesToManufactureSignificance() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T15:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: .empty,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(edition.form, .almanacLeaf)
        XCTAssertTrue(edition.reading.contains("paying attention"))
        XCTAssertTrue(edition.beats.isEmpty)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
