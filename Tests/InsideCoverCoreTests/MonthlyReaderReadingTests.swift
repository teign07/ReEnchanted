import XCTest
@testable import InsideCoverCore

final class MonthlyReaderReadingTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }

    private func page(_ id: String, _ day: Int, _ text: String,
                      type: BookPageType = .diary, origin: BookPageOrigin = .userAuthored) -> BookPage {
        BookPage(id: id, type: type, createdAt: date(day), promptText: "What happened?", userInput: text, origin: origin)
    }

    private let reflection = "I read back through the month on the bus and there's more in it than I thought. The heron. The stair. The bees. The woodsmoke. None of it's anything, and all of it's the month. I want to remember that it was a month where I started looking up."

    func testTheReadersReflectionLeadsEvenWithASavedAutomaticTheme() throws {
        let pages = [
            page("heron", 2, "I watched a heron by the river. It moved its head once."),
            page("bread", 15, "The man at the bakery remembered I liked the end piece."),
            page("account", 30, reflection),
            page("braid", 30, "You moved the heron's head. The hour and weather returned.", type: .bookOfYou, origin: .generated)
        ]
        let old = BookTheme(id: "theme-2026-10", monthKey: "2026-10", name: "Hour and Weather", motifs: ["hour", "weather"],
                            line: "Hour and weather returned.", strength: 60, evidencePageIDs: ["braid"],
                            excerptLines: [], discoveredAt: date(29))
        let edition = MonthlyEditionBuilder.edition(
            from: pages.map { BookDay(id: BookDay.id(for: $0.createdAt, calendar: calendar), date: $0.createdAt, pages: [$0]) },
            themes: [old], readerName: "Wren", startDate: date(1), endDate: date(31), generatedAt: date(31), calendar: calendar
        )
        let theme = try XCTUnwrap(edition.theme)
        XCTAssertEqual(theme.name, "I started looking up")
        XCTAssertEqual(theme.evidencePageIDs, ["account"])
        XCTAssertTrue(edition.foreword.contains("I watched a heron by the river."))
        XCTAssertTrue(edition.closing?.contains(reflection) == true)
        XCTAssertFalse(edition.foreword.contains("You moved the heron's head"))
        XCTAssertFalse(edition.closing?.contains("Hour and Weather") == true)
        let shape = try XCTUnwrap(edition.sections.first { $0.id == "what-this-was" })
        XCTAssertFalse(shape.items.contains { $0.body.contains("Nothing in this month") })
        XCTAssertTrue(shape.items.contains { $0.body.contains("I started looking up") })
    }

    func testGeneratedAndPrivateTextCantStandInForTheReadersAccount() {
        let fake = "I want to remember that this month I found a secret palace."
        let pages = [
            page("fiction", 30, fake, origin: .generated),
            // Old braids sometimes retained the default userAuthored origin.
            page("old-braid", 30, fake, type: .bookOfYou),
            page("private-body", 30, fake, type: .body),
            page("private-fuel", 30, fake, type: .fuel),
            page("actual", 2, "The bakery remembered my favorite bread.")
        ]
        XCTAssertNil(MonthlyReaderReading.reflection(in: pages))
        XCTAssertEqual(MonthlyReaderReading.moments(in: pages).map(\.pageID), ["actual"])
        XCTAssertNil(MonthlyReaderReading.theme(in: pages, monthKey: "2026-10", now: date(31), calendar: calendar))
    }

    func testAnExplicitMonthAccountOutranksIncidentalWordCounts() throws {
        let pages = (1...4).map { page("work-\($0)", $0, "I walked home after work and stopped at the bakery.") }
            + [page("heron", 5, "I watched a heron beside the river."), page("account", 30, reflection)]
        XCTAssertTrue(BindingRevelations.find(pages: pages, now: date(31), calendar: calendar, limit: 6)
            .contains { $0.kind == .recurringWord })
        let edition = MonthlyEditionBuilder.edition(
            from: pages.map { BookDay(id: BookDay.id(for: $0.createdAt, calendar: calendar), date: $0.createdAt, pages: [$0]) },
            readerName: "Wren", startDate: date(1), endDate: date(31), generatedAt: date(31), calendar: calendar)
        XCTAssertFalse(edition.sections.flatMap(\.items).contains { $0.tags.contains("recurringWord") })
        XCTAssertTrue(edition.sections.flatMap(\.items).contains { $0.title == "The heron" })
    }

    func testAReaderReplyIsEvidenceButTheBooksQuestionIsnt() {
        var reply = page("reply", 30, "This month was all about my palace.", type: .bookOfYou, origin: .generated)
        reply.playerReply = reflection
        XCTAssertEqual(MonthlyReaderReading.reflection(in: [reply])?.text, reflection)
        XCTAssertFalse(MonthlyReaderReading.themePages(in: [reply]).contains { $0.userInput.contains("my palace") })
    }

    func testThemeNamingDoesNotClipALongReflectionIntoAFakeQuote() {
        let long = page("long", 30, "I want to remember that this month " + String(repeating: "held a different small thing ", count: 12) + ".")
        XCTAssertNil(MonthlyReaderReading.theme(in: [long], monthKey: "2026-10", now: date(31), calendar: calendar))
        XCTAssertEqual(MonthlyReaderReading.reflection(in: [long])?.text, long.userInput)
    }

    func testTheReadersNamedThingsLeadBackToRealDatedEntries() {
        let pages = [
            page("heron", 4, "Long walk. I saw a heron standing in the shallows. It moved its head."),
            page("stair", 5, "The stair creaks only on the way down."),
            page("fake-bees", 19, "The bees sang to a crown.", type: .bookOfYou, origin: .generated),
            page("account", 30, reflection)
        ]
        let named = MonthlyReaderReading.namedMoments(in: pages)
        XCTAssertEqual(named.map(\.name), ["The heron", "The stair"])
        XCTAssertEqual(named.map { $0.moment.pageID }, ["heron", "stair"])
        XCTAssertEqual(named[0].moment.text, "I saw a heron standing in the shallows.")
        XCTAssertEqual(named[0].moment.date, date(4))
    }

    func testTheOpeningMovesPastADateLabelWithoutClippingTheReader() {
        let first = MonthlyReaderReading.Moment(pageID: "first", date: date(1), text: "First of the month. I waited for the kettle instead of rushing out again.")
        XCTAssertEqual(MonthlyReaderReading.openingExcerpt(first), "I waited for the kettle instead of rushing out again.")
    }

    func testDifferentMonthsReadTheirOwnLifeAndTheirOwnReflection() throws {
        let cases = [
            (2, "The thaw", "I watched the thaw uncover the path beside the river.", "I started walking again"),
            (7, "The lantern", "I carried the lantern home after the last bus went.", "I began taking the long way home"),
            (12, "The train", "I met my sister when her train finally came in.", "I made room for people")
        ]
        for (month, name, detail, meaning) in cases {
            let start = calendar.date(from: DateComponents(year: 2026, month: month, day: 1))!
            let lastDay = calendar.range(of: .day, in: .month, for: start)!.count
            let end = calendar.date(from: DateComponents(year: 2026, month: month, day: lastDay, hour: 23))!
            let keptAt = calendar.date(from: DateComponents(year: 2026, month: month, day: 2, hour: 12))!
            let account = "I read back through the month. \(name). I want to remember that it was a month where \(meaning)."
            let pages = [
                BookPage(id: "detail-\(month)", type: .diary, createdAt: keptAt, promptText: "?", userInput: detail, origin: .userAuthored),
                BookPage(id: "account-\(month)", type: .diary, createdAt: end, promptText: "?", userInput: account, origin: .userAuthored)
            ]
            let edition = MonthlyEditionBuilder.edition(
                from: pages.map { BookDay(id: BookDay.id(for: $0.createdAt, calendar: calendar), date: $0.createdAt, pages: [$0]) },
                readerName: "Reader", startDate: start, endDate: end, generatedAt: end, calendar: calendar)
            XCTAssertEqual(edition.theme?.name, meaning, "month \(month)")
            XCTAssertTrue(edition.foreword.contains(detail), "month \(month)")
            XCTAssertTrue(edition.closing?.contains(account) == true, "month \(month)")
            let named = try XCTUnwrap(edition.sections.first { $0.id == "the-book-notices" }?.items.first { $0.title == name })
            XCTAssertEqual(named.date, keptAt)
            XCTAssertTrue(named.body.contains(detail))
            XCTAssertFalse(edition.foreword.contains("I started looking up"))
        }
    }

    func testMonthsWithoutAReflectionKeepTheirOwnSmallBeginning() {
        for month in [1, 5, 11] {
            let start = calendar.date(from: DateComponents(year: 2026, month: month, day: 1))!
            let keptAt = start.addingTimeInterval(12 * 3600)
            let detail = "I waited with my neighbour until the bus finally came."
            let kept = BookPage(id: "small-\(month)", type: .diary, createdAt: keptAt, promptText: "?", userInput: detail, origin: .userAuthored)
            let edition = MonthlyEditionBuilder.edition(
                from: [BookDay(id: BookDay.id(for: keptAt, calendar: calendar), date: keptAt, pages: [kept])],
                readerName: "Reader", startDate: start, endDate: start.addingTimeInterval(86_399), generatedAt: keptAt, calendar: calendar)
            XCTAssertTrue(edition.foreword.contains(detail))
            XCTAssertTrue(edition.closing?.contains(detail) == true)
            XCTAssertNil(MonthlyReaderReading.reflection(in: [kept]))
            XCTAssertFalse(edition.foreword.contains("I started looking up"))
        }
    }

    func testPrintedMemoriesRestoreWholeSentencesFromShortPromptTags() throws {
        let line = "The table kept the small dent where my brother used to put his cup, through three changes of paint and a move across town, and I found it again when I finally sat down beside the window."
        let braid = BraidPageDetails.annotated(page("long-braid", 12, "The Table\n\n\(line)\n\nThe Book kept the page: \(line)", type: .bookOfYou, origin: .generated), context: .empty)
        let edition = MonthlyEditionBuilder.edition(
            from: [BookDay(id: "2026-10-12", date: date(12), pages: [braid])],
            readerName: "Reader", startDate: date(1), endDate: date(31), generatedAt: date(31), calendar: calendar)
        let callbacks = try XCTUnwrap(edition.sections.first { $0.id == "book-memory-spine" }?.items.first { $0.id == "memory-spine-callbacks" })
        XCTAssertTrue(callbacks.body.contains(line), callbacks.body)
    }
}
