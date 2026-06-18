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
