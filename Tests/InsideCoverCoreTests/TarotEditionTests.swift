import XCTest
@testable import InsideCoverCore

final class TarotEditionTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }

    private func date(_ day: Int, month: Int = 10, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func event(_ id: String, card: String = "major-00", day: Int = 3,
                       source: TarotEditionEncounter.Source = .interleaf) -> TarotEditionEncounter {
        .init(id: id, cardID: card, source: source, date: date(day))
    }

    private func summary(_ events: [TarotEditionEncounter], pages: [BookPage] = []) -> TarotEditionKeepsake? {
        TarotEditionKeepsake.make(encounters: events, pages: pages,
                                 start: date(1, hour: 0), end: date(1, month: 11, hour: 0), calendar: calendar)
    }

    private func savedPage(_ reading: TarotReadingArtifact, id: String = "saved") throws -> BookPage {
        let encoded = String(decoding: try JSONEncoder().encode(reading), as: UTF8.self)
        return BookPage(id: id, type: .tarot, createdAt: date(15), promptText: "Tarot", userInput: "",
                        metadata: [TarotReadingArtifact.metadataKey: encoded])
    }

    func testInterleafAndReadingReceiptsCountTogetherWithoutRecountingSavedReading() throws {
        let card = TarotDrawnCard(cardID: "major-00", position: .single, isReversed: false)
        let reading = TarotReadingArtifact(id: "reading-a", spread: .oneCard, drawnAt: date(8), cards: [card])
        let page = try savedPage(reading)
        let repeated = TarotEditionEncounter.reading(reading, card: card)
        let result = try XCTUnwrap(summary([event("leaf-a"), repeated, repeated], pages: [page, page]))
        XCTAssertEqual(result.cards.count, 1)
        XCTAssertEqual(result.cards[0].interleafCount, 1)
        XCTAssertEqual(result.cards[0].readingCount, 1)
        XCTAssertEqual(result.cards[0].count, 2)
        XCTAssertEqual(result.cards[0].dates, [date(3), date(8)])
        XCTAssertEqual(result.timeZoneID, calendar.timeZone.identifier)
    }

    func testEmptySingleAndUnknownCardsEarnNoPrintedLeaf() {
        XCTAssertNil(summary([]))
        XCTAssertNil(summary([event("one")]))
        XCTAssertNil(summary([event("one", card: "unknown"), event("two", card: "unknown")]))
        XCTAssertNil(summary([event("same"), event("same")]))
    }

    func testMonthBoundsAreHalfOpenAndUseTheReadingDateRatherThanSaveDate() throws {
        let card = TarotDrawnCard(cardID: "major-00", position: .single, isReversed: false)
        let before = TarotReadingArtifact(id: "before", spread: .oneCard,
                                         drawnAt: date(30, month: 9), cards: [card])
        let after = TarotReadingArtifact(id: "after", spread: .oneCard,
                                        drawnAt: date(1, month: 11, hour: 0), cards: [card])
        var first = event("start")
        first.date = date(1, hour: 0)
        var outside = event("end")
        outside.date = date(1, month: 11, hour: 0)
        XCTAssertNil(summary([first, outside], pages: [try savedPage(before), try savedPage(after)]))
        let result = try XCTUnwrap(summary([first, event("last", day: 31)]))
        XCTAssertEqual(result.cards[0].count, 2)
    }

    func testTopThreeAreDeterministicAndRankByActualAppearances() throws {
        var events: [TarotEditionEncounter] = []
        for (card, count) in [("major-00", 2), ("major-01", 4), ("major-02", 3), ("major-03", 3)] {
            for index in 0..<count { events.append(event("\(card)-\(index)", card: card, day: index + 1)) }
        }
        let result = try XCTUnwrap(summary(events))
        XCTAssertEqual(result.cards.map(\.cardID), ["major-01", "major-02", "major-03"])
        XCTAssertEqual(result, summary(Array(events.reversed())))
    }

    func testSameInterleafSameDayDeduplicatesButAnotherBoundaryOrDayDoesNot() throws {
        let asset = try XCTUnwrap(TarotDeck.card(id: "major-00")).assetName
        let first = try XCTUnwrap(TarotEditionEncounter.interleaf(assetName: asset, leafID: "boundary-a", date: date(3), calendar: calendar))
        let reflow = try XCTUnwrap(TarotEditionEncounter.interleaf(assetName: asset, leafID: "boundary-a", date: date(3, hour: 22), calendar: calendar))
        let another = try XCTUnwrap(TarotEditionEncounter.interleaf(assetName: asset, leafID: "boundary-b", date: date(3), calendar: calendar))
        let nextDay = try XCTUnwrap(TarotEditionEncounter.interleaf(assetName: asset, leafID: "boundary-a", date: date(4), calendar: calendar))
        XCTAssertEqual(first.id, reflow.id)
        XCTAssertNotEqual(first.id, another.id)
        XCTAssertNotEqual(first.id, nextDay.id)
        XCTAssertFalse(first.id.contains("boundary-a"), "Raw boundary identifiers are not needed in the receipt")
        XCTAssertNil(TarotEditionEncounter.interleaf(assetName: "botanical", leafID: "a", date: date(3)))
    }

    func testLocalStorePersistsWithoutRecountingDuplicateVisibilityReceipts() throws {
        let name = "TarotEditionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let queue = DispatchQueue(label: name)
        let store = TarotEditionEncounterStore(defaults: defaults, queue: queue)
        store.record(event("visible"))
        store.record(event("visible"))
        store.record(event("unknown", card: "unknown"))
        XCTAssertEqual(store.snapshot().count, 1)
        queue.sync {}
        XCTAssertEqual(TarotEditionEncounterStore(defaults: defaults).snapshot(), store.snapshot())
    }

    func testOlderKeepsakesDecodeAndNewKeepsakeFreezesWithTheEdition() throws {
        let old = try JSONDecoder().decode(HandbookKeepsakes.self, from: Data("{}".utf8))
        XCTAssertNil(old.tarot)
        XCTAssertTrue(old.isEmpty)
        var keepsakes = old
        keepsakes.tarot = try XCTUnwrap(summary([event("a"), event("b", source: .reading)]))
        let copy = try JSONDecoder().decode(HandbookKeepsakes.self, from: JSONEncoder().encode(keepsakes))
        XCTAssertEqual(copy, keepsakes)
        XCTAssertFalse(copy.isEmpty)
        XCTAssertTrue(keepsakes.removeExtra())
        XCTAssertTrue(keepsakes.isEmpty)
    }

    func testMonthlyTarotIsRemovedBeforeReaderDaysAndDoesNotEnterWeeklyHandbook() throws {
        var edition = MonthlyEditionBuilder.edition(from: [], startDate: date(1), endDate: date(31), calendar: calendar)
        var handbook = Handbook(lessons: [], lore: [], compass: [], dossiers: [], bestiary: [], spells: [])
        var keepsakes = HandbookKeepsakes()
        keepsakes.tarot = try XCTUnwrap(summary([event("a"), event("b")]))
        handbook.keepsakes = keepsakes
        edition.handbook = handbook
        let thinner = try XCTUnwrap(edition.trimmedForPrint())
        XCTAssertNil(thinner.handbook?.keepsakes?.tarot)
        XCTAssertEqual(thinner.sections, edition.sections)
        XCTAssertEqual(thinner.dayBook, edition.dayBook)
        for level in Handbook.weeklyLevelRange {
            XCTAssertNil(handbook.weeklySlice(issueNumber: 1, level: level).keepsakes)
        }
        XCTAssertEqual(PrintSpec.pageCap(for: .weekly), 48)
        XCTAssertEqual(PrintSpec.pageCap(for: .monthly), 160)
    }

    func testWeeklyCanKeepOneActualAppearanceWithoutWeakeningMonthlyRecurrence() throws {
        let events = [event("only-one")]
        let card = try XCTUnwrap(TarotEditionKeepsake.weeklyCard(
            encounters: events, pages: [], start: date(1, hour: 0), end: date(8, hour: 0), calendar: calendar))
        XCTAssertEqual(card.cardID, "major-00")
        XCTAssertEqual(card.count, 1)
        XCTAssertNil(summary(events), "The monthly page still needs a recurring card")
        XCTAssertNil(TarotEditionKeepsake.weeklyCard(
            encounters: [], pages: [], start: date(1), end: date(8), calendar: calendar))
    }

    func testWeeklyChoosesOneCardAcrossBothSourcesAndDeduplicatesSavedReading() throws {
        let drawn = TarotDrawnCard(cardID: "major-01", position: .single, isReversed: false)
        let reading = TarotReadingArtifact(id: "week-reading", spread: .oneCard, drawnAt: date(4), cards: [drawn])
        let events = [event("other"), event("returned", card: "major-01"),
                      TarotEditionEncounter.reading(reading, card: drawn)]
        let card = try XCTUnwrap(TarotEditionKeepsake.weeklyCard(
            encounters: events, pages: [try savedPage(reading)],
            start: date(1, hour: 0), end: date(8, hour: 0), calendar: calendar))
        XCTAssertEqual(card.cardID, "major-01")
        XCTAssertEqual(card.interleafCount, 1)
        XCTAssertEqual(card.readingCount, 1)
    }

    func testWeeklyWindowCanCrossMonthBoundaryAndExcludesTheFollowingWeek() throws {
        var lastMonth = event("before", card: "major-00", day: 25)
        lastMonth.date = date(25)
        let inOctober = event("october", card: "major-01", day: 31)
        var inNovember = event("november", card: "major-01")
        inNovember.date = date(1, month: 11)
        var followingWeek = event("after", card: "major-00")
        followingWeek.date = date(2, month: 11, hour: 0)
        let result = try XCTUnwrap(TarotEditionKeepsake.weeklyCard(
            encounters: [lastMonth, inOctober, inNovember, followingWeek], pages: [],
            start: date(26, hour: 0), end: date(2, month: 11, hour: 0), calendar: calendar))
        XCTAssertEqual(result.cardID, "major-01")
        XCTAssertEqual(result.count, 2)
    }

    func testWeeklyCardIsFrozenInTheIssueAndOlderIssuesDecodeWithoutIt() throws {
        var issue = WeeklyIssue(number: 1, startDate: date(1), endDate: date(8), dateRange: "Oct 1–7",
                                keptCount: 1, highlights: [], setAsideLine: nil)
        let older = try JSONDecoder().decode(WeeklyIssue.self, from: JSONEncoder().encode(issue))
        XCTAssertNil(older.tarotCard)
        issue.tarotCard = try XCTUnwrap(TarotEditionKeepsake.weeklyCard(
            encounters: [event("one")], pages: [], start: date(1), end: date(8), calendar: calendar))
        let frozen = try JSONDecoder().decode(WeeklyIssue.self, from: JSONEncoder().encode(issue))
        XCTAssertEqual(frozen.tarotCard, issue.tarotCard)
        XCTAssertNotEqual(frozen, older, "The weekly cache must notice a changed Tarot inset")
        XCTAssertEqual(frozen.pages, older.pages)
        XCTAssertEqual(frozen.playLeaves, older.playLeaves)
    }
}
