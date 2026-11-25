import XCTest
@testable import InsideCoverCore

/// Neighbours over time: name-days, gone quiet and come back, errands that
/// take a Neighbour by name, deals bound to one, and the Book's one line.
/// Each fires on its own dates, once, and never for a resting or gone one.
final class NeighboursOverTimeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private let founded = DateComponents(year: 2026, month: 5, day: 14)

    private var foundedAt: Date { date(2026, 5, 14) }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        [BookDay(id: "archive", date: foundedAt, pages: pages)]
    }

    private func treeSpell(_ words: String = "The tree is called Gerald.", at: Date? = nil) -> BookPage {
        BookPage(id: "tree-page", type: .spell, createdAt: at ?? foundedAt, promptText: "A spell",
                 userInput: words, tags: ["spell", "spell:name-a-tree"])
    }

    private func kettle(at: Date) -> BookPage {
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "faerie-name-earned", title: "Give It a Name",
            invitation: "Go on.", proofPrompt: "One sentence.", facets: [.exactAttention], sourceTags: [],
            hasWrittenProof: true, hasVisualProof: false, completedAt: at, wasPromptedByBook: true)
        return BookPage(id: "kettle-page", type: .wonderCompass, createdAt: at, promptText: "Give It a Name",
                        userInput: "I named my kettle Huffer.", livedQuestReceipt: receipt)
    }

    private func diary(_ words: String, at: Date, id: String) -> BookPage {
        BookPage(id: id, type: .diary, createdAt: at, promptText: "Diary", userInput: words)
    }

    private func founding(_ pages: [BookPage], at: Date? = nil) throws -> [BookPage] {
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        return pages + [try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days(pages), now: at ?? foundedAt))]
    }

    private func receipt(tag: String, at: Date, id: String) -> BookPage {
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "x", title: "x", invitation: "x", proofPrompt: "One sentence.",
            facets: [.exactAttention], sourceTags: [tag], hasWrittenProof: true, hasVisualProof: false,
            completedAt: at, wasPromptedByBook: true)
        return BookPage(id: id, type: .wonderCompass, createdAt: at, promptText: "x",
                        userInput: "Told it about the bus.", livedQuestReceipt: receipt)
    }

    // MARK: Name-days

    func testANameDayComesOnTheFoundingDateEachYearAndNoOtherDay() throws {
        let pages = try founding([treeSpell()])
        for day in [date(2026, 5, 14), date(2027, 5, 13), date(2027, 5, 15), date(2027, 11, 14)] {
            XCTAssertFalse(NeighbourNotices.timely(days: days(pages), now: day, calendar: calendar)
                .contains { $0.kind == .nameDay }, "\(day)")
        }
        let first = try XCTUnwrap(NeighbourNotices.timely(days: days(pages), now: date(2027, 5, 14), calendar: calendar).first)
        XCTAssertEqual(first.kind, .nameDay)
        XCTAssertEqual(first.years, 1)
        let third = try XCTUnwrap(NeighbourNotices.timely(days: days(pages), now: date(2029, 5, 14), calendar: calendar).first)
        XCTAssertEqual(third.years, 3)
    }

    func testANameDayIsSaidOnceAYear() throws {
        var pages = try founding([treeSpell()])
        let day = date(2027, 5, 14, hour: 9)
        let notice = try XCTUnwrap(NeighbourNotices.timely(days: days(pages), now: day, calendar: calendar).first)
        let source = BookPageSourceRegistry.source(id: Neighbours.sourceID, fallbackType: .neighbours)
        let surface = NeighbourNotices.surface(for: notice, source: source, day: BookDay.day(containing: day, calendar: calendar), calendar: calendar)
        XCTAssertEqual(surface.type, .wonderCompass)
        XCTAssertTrue(surface.payload.body.hasPrefix("It's Gerald's name-day. A year ago today you gave Gerald its name."))
        XCTAssertTrue(surface.payload.body.contains("\u{201C}The tree is called Gerald.\u{201D}"))
        XCTAssertEqual(surface.payload.metadata["souvenirPrompt"], "One sentence about what you gave Gerald for its name-day.")
        // Kept: the spoke tag rests it for good this year.
        let tags = (surface.payload.metadata["tags"] ?? "").split(separator: ",").map(String.init)
        pages.append(BookPage(id: "kept-nameday", type: .wonderCompass, createdAt: day, promptText: surface.prompt,
                              userInput: "A conker.", tags: tags))
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: day.addingTimeInterval(3_600), calendar: calendar).isEmpty)
        XCTAssertEqual(NeighbourNotices.timely(days: days(pages), now: date(2028, 5, 14), calendar: calendar).first?.years, 2)
    }

    func testALeapDayNeighbourKeepsItsNameDayOnTheTwentyEighth() throws {
        let leap = date(2028, 2, 29)
        let pages = try founding([treeSpell(at: leap)], at: leap)
        XCTAssertEqual(NeighbourNotices.timely(days: days(pages), now: date(2029, 2, 28), calendar: calendar).first?.kind, .nameDay)
        XCTAssertEqual(NeighbourNotices.timely(days: days(pages), now: date(2032, 2, 29), calendar: calendar).first?.years, 4)
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2032, 2, 28), calendar: calendar).isEmpty)
    }

    func testRestingAndGoneNeighboursHaveNoNameDay() throws {
        var pages = try founding([treeSpell()])
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.restRecord(gerald, now: date(2026, 8, 1))))
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2027, 5, 14), calendar: calendar).isEmpty)
    }

    // MARK: Gone quiet and come back

    private func withHistory(_ dates: [Date]) throws -> [BookPage] {
        try founding([treeSpell()]) + dates.enumerated().map { diary("Gerald waved at me.", at: $1, id: "g\($0)") }
    }

    func testANeighbourWithRealHistoryGoesQuietBetweenThirtyFiveAndTwoHundredFortyDays() throws {
        let pages = try withHistory([date(2026, 5, 20), date(2026, 6, 1)])
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2026, 7, 1), calendar: calendar).isEmpty)
        let quiet = try XCTUnwrap(NeighbourNotices.timely(days: days(pages), now: date(2026, 7, 10), calendar: calendar).first)
        XCTAssertEqual(quiet.kind, .goneQuiet)
        XCTAssertEqual(quiet.quietDays, 39)
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2027, 3, 1), calendar: calendar).isEmpty)
    }

    func testOnePageIsNotEnoughHistoryToMiss() throws {
        let pages = try founding([treeSpell()])
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2026, 7, 10), calendar: calendar).isEmpty)
    }

    func testAQuietNoticeRestsOnceSaid() throws {
        var pages = try withHistory([date(2026, 5, 20), date(2026, 6, 1)])
        let notice = try XCTUnwrap(NeighbourNotices.timely(days: days(pages), now: date(2026, 7, 10), calendar: calendar).first)
        pages.append(BookPage(id: "kept-quiet", type: .neighbours, createdAt: date(2026, 7, 10), promptText: "Gone Quiet",
                              tags: ["neighbours", "spoke:\(notice.restKey)"]))
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2026, 7, 20), calendar: calendar).isEmpty)
    }

    func testANeighbourComesBackAfterALongGap() throws {
        let pages = try withHistory([date(2026, 5, 20), date(2026, 6, 1), date(2026, 8, 1)])
        let back = try XCTUnwrap(NeighbourNotices.timely(days: days(pages), now: date(2026, 8, 3), calendar: calendar).first)
        XCTAssertEqual(back.kind, .cameBack)
        XCTAssertEqual(back.quietDays, 61)
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2026, 8, 20), calendar: calendar).isEmpty)
        let source = BookPageSourceRegistry.source(id: Neighbours.sourceID, fallbackType: .neighbours)
        let surface = NeighbourNotices.surface(for: back, source: source, day: BookDay.day(containing: date(2026, 8, 3)), calendar: calendar)
        XCTAssertTrue(surface.payload.body.hasPrefix("Gerald's back. Nothing about it in your Pages since June"))
    }

    func testRestingNeighboursAreNeverMissed() throws {
        var pages = try withHistory([date(2026, 5, 20), date(2026, 6, 1)])
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.restRecord(gerald, now: date(2026, 6, 2))))
        XCTAssertTrue(NeighbourNotices.timely(days: days(pages), now: date(2026, 7, 10), calendar: calendar).isEmpty)
    }

    // MARK: Addressed workings

    private func visits(_ pages: [BookPage], on day: Date, facts: [SelfFact] = []) -> [PlayfulMission] {
        Neighbours.visitMissions(days: days(pages), selfFacts: facts, now: day, calendar: calendar)
    }

    func testAVisitComesDueTenDaysOnThenEveryFourWeeks() throws {
        let pages = try founding([kettle(at: foundedAt)])
        for offset in [0, 5, 9, 13, 20, 37, 41] {
            XCTAssertTrue(visits(pages, on: calendar.date(byAdding: .day, value: offset, to: foundedAt)!).isEmpty, "day \(offset)")
        }
        let first = try XCTUnwrap(visits(pages, on: calendar.date(byAdding: .day, value: 10, to: foundedAt)!).first)
        XCTAssertEqual(first.id, "neighbour-visit-huffer-v0")
        XCTAssertTrue(first.prompt.contains("Huffer"))
        XCTAssertTrue(first.prompt.hasPrefix("You wrote this about Huffer: \u{201C}I named my kettle Huffer.\u{201D}"))
        XCTAssertTrue(first.proofPrompt.hasPrefix("One sentence"))
        XCTAssertTrue(first.tags.contains("neighbour-visit:huffer:v0"))
        XCTAssertEqual(visits(pages, on: calendar.date(byAdding: .day, value: 38, to: foundedAt)!).first?.id, "neighbour-visit-huffer-v1")
    }

    func testTheLatestShortSentenceRidesAlongWhole() throws {
        var pages = try founding([kettle(at: foundedAt)])
        pages.append(diary("Huffer boiled dry and I said sorry to it.", at: date(2026, 5, 20), id: "later"))
        let mission = try XCTUnwrap(visits(pages, on: date(2026, 5, 24)).first)
        XCTAssertTrue(mission.prompt.contains("\u{201C}Huffer boiled dry and I said sorry to it.\u{201D}"))
    }

    func testAnAnsweredVisitIsNotAskedAgain() throws {
        var pages = try founding([kettle(at: foundedAt)])
        let day = date(2026, 5, 24)
        XCTAssertFalse(visits(pages, on: day).isEmpty)
        pages.append(receipt(tag: "mission:neighbour-visit:huffer:v0", at: day, id: "answer"))
        XCTAssertTrue(visits(pages, on: day.addingTimeInterval(3_600)).isEmpty)
    }

    func testRestingAndGoneNeighboursAreNeverAddressed() throws {
        var pages = try founding([kettle(at: foundedAt)])
        let huffer = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.goneRecord(huffer, now: date(2026, 5, 20), calendar: calendar)))
        XCTAssertTrue(visits(pages, on: date(2026, 5, 24)).isEmpty)
        XCTAssertEqual(Neighbours.register(days: days(pages)).first?.status, .gone, "still in the register")
    }

    func testKeepWonderIndoorsLeavesRootedNeighboursAlone() throws {
        let pages = try founding([treeSpell()])
        let day = date(2026, 5, 24)
        XCTAssertFalse(visits(pages, on: day).isEmpty)
        let fact = SelfFact(id: "leaving", questionID: "leaving-home", question: "?", answer: "Keep wonder indoors",
                            bookTranslation: "", sensitivity: .comfort, usePermission: .privateContext, tags: [],
                            createdAt: foundedAt, updatedAt: foundedAt)
        XCTAssertTrue(visits(pages, on: day, facts: [fact]).isEmpty)
    }

    func testADueVisitLeavesOrdinaryErrandsOnAlternateTurns() throws {
        let pages = try founding([kettle(at: foundedAt)])
        let day = date(2026, 5, 24)
        var inputs = BookSourceInputs.empty
        inputs.days = days(pages)
        let today = BookDay(id: "today", date: day, pages: [])
        var addressed = 0
        var ordinary = 0
        for slot in 0..<12 {
            let at = day.addingTimeInterval(Double(slot) * 2 * 3_600 - 12 * 3_600)
            guard calendar.isDate(at, inSameDayAs: day) else { continue }
            let mission = PlayfulMissionRegistry.mission(for: today, inputs: inputs, now: at)
            if mission.id.hasPrefix("neighbour-visit-") { addressed += 1 } else { ordinary += 1 }
        }
        XCTAssertGreaterThan(addressed, 0, "a due visit never reached the mission seat")
        XCTAssertGreaterThan(ordinary, 0, "a due visit crowded out every ordinary errand")
    }

    // MARK: Deals bound to Neighbours

    private func promises(_ pages: [BookPage], on day: Date) -> [PlayfulMission] {
        var inputs = BookSourceInputs.empty
        inputs.days = days(pages)
        return PlayfulMissionRegistry.promiseMissions(
            for: BookDay(id: "today", date: day, pages: []), inputs: inputs, now: day, calendar: calendar)
    }

    func testADealWhoseSpellFoundedANeighbourUsesItsName() throws {
        let pages = try founding([treeSpell()])
        let month = try XCTUnwrap(promises(pages, on: date(2026, 6, 13)).first)
        XCTAssertTrue(month.prompt.hasPrefix("A month ago you told a tree it was called Gerald."), month.prompt)
        XCTAssertTrue(month.prompt.contains("Go past Gerald and say hello."))
        // Without a Neighbour the deal reads as it always did.
        let plain = try XCTUnwrap(promises([treeSpell()], on: date(2026, 6, 13)).first)
        XCTAssertTrue(plain.prompt.hasPrefix("A month ago you told a tree its name."))
    }

    func testADealWithARestingOrGoneNeighbourIsNotCalledIn() throws {
        var pages = try founding([treeSpell()])
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.goneRecord(gerald, now: date(2026, 6, 1), calendar: calendar)))
        XCTAssertTrue(promises(pages, on: date(2026, 6, 13)).isEmpty)
    }

    // MARK: The one line

    func testTheLineSaysOnlyWhatTheArchiveKnows() throws {
        var pages = try founding([treeSpell()])
        var gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(Neighbours.line(for: gerald, days: days(pages), now: date(2026, 5, 16), calendar: calendar),
                       "Gerald was in your Pages this week. There's a deal with it, and you haven't told me how it's going.")
        pages.append(receipt(tag: "mission:promise-call:tree-page:d7", at: date(2026, 5, 22), id: "answered"))
        gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(Neighbours.line(for: gerald, days: days(pages), now: date(2026, 8, 1), calendar: calendar),
                       "Gerald hasn't been in your Pages since May. You last told me about your deal with it in May.")
        pages.append(try XCTUnwrap(Neighbours.goneRecord(gerald, now: date(2026, 10, 2), calendar: calendar)))
        gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(Neighbours.line(for: gerald, days: days(pages), now: date(2026, 11, 1), calendar: calendar),
                       "Gerald's gone. It was in here from May 2026 to October 2026.")
    }

    func testAThingWithoutADealGetsItsFirstMonth() throws {
        let pages = try founding([kettle(at: foundedAt)])
        let huffer = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(Neighbours.line(for: huffer, days: days(pages), now: date(2026, 6, 20), calendar: calendar),
                       "Huffer hasn't been in your Pages since May. It's Huffer's first June in here.")
    }

    // MARK: On the map

    private func placedTreeSpell() -> BookPage {
        var page = treeSpell()
        page.context = BookPageContextSnapshot(latitude: 51.5, longitude: -0.12)
        return page
    }

    func testANeighbourWithCoordinatesIsOnTheMapByName() throws {
        let pages = try founding([placedTreeSpell()])
        let layers = AtlasProjection.layers(from: AtlasSources(days: days(pages), now: date(2026, 5, 20), calendar: calendar))
        let layer = try XCTUnwrap(layers.first(where: { $0.id == NeighboursAtlasLayer.layer }))
        XCTAssertTrue(layer.isOnByDefault)
        let mark = try XCTUnwrap(layer.marks.first)
        XCTAssertEqual(mark.title, "Gerald")
        XCTAssertEqual(mark.latitude, 51.5)
        XCTAssertEqual(mark.glyph, "signpost.right.fill")
        XCTAssertTrue(mark.detail.contains("\u{201C}The tree is called Gerald.\u{201D}"))
    }

    func testANeighbourWithoutCoordinatesIsNotGuessedOntoTheMap() throws {
        let pages = try founding([treeSpell()])
        let layers = AtlasProjection.layers(from: AtlasSources(days: days(pages), now: date(2026, 5, 20), calendar: calendar))
        XCTAssertNil(layers.first(where: { $0.id == NeighboursAtlasLayer.layer }))
    }

    func testAGoneNeighbourKeepsItsSpotWithADifferentMark() throws {
        var pages = try founding([placedTreeSpell()])
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.goneRecord(gerald, now: date(2026, 8, 1), calendar: calendar)))
        let layers = AtlasProjection.layers(from: AtlasSources(days: days(pages), now: date(2026, 9, 1), calendar: calendar))
        let mark = try XCTUnwrap(layers.first(where: { $0.id == NeighboursAtlasLayer.layer })?.marks.first)
        XCTAssertEqual(mark.glyph, "circle.dotted")
        XCTAssertEqual(mark.subtitle, "Gone")
    }

    // MARK: Who lives here

    func testTheRollSaysWhenItCameWhatYouDidAndQuotesYouWhole() throws {
        let pages = try founding([treeSpell()]) + [
            diary("Gerald dropped a branch on the car.", at: date(2026, 6, 2), id: "d1"),
            diary("Sat under Gerald with a sandwich.", at: date(2026, 6, 9), id: "d2")
        ]
        let roll = Neighbours.roll(days: days(pages), start: date(2026, 6, 1), end: date(2026, 6, 30), calendar: calendar)
        let gerald = try XCTUnwrap(roll.first)
        XCTAssertEqual(gerald.name, "Gerald")
        XCTAssertEqual(gerald.lines.first, "Came in May 2026. You told a tree its name.")
        XCTAssertTrue(gerald.lines.contains("On three of your Pages. The last was in June."), "\(gerald.lines)")
        XCTAssertEqual(gerald.lines.last, "You wrote: \u{201C}The tree is called Gerald.\u{201D}")
    }

    func testTheRollHoldsNobodyFromAfterTheBookAndNobodyAlreadySaidGoodbyeTo() throws {
        var pages = try founding([treeSpell()])
        XCTAssertTrue(Neighbours.roll(days: days(pages), start: date(2026, 4, 1), end: date(2026, 4, 30), calendar: calendar).isEmpty)
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.goneRecord(gerald, now: date(2026, 7, 10), calendar: calendar)))
        let july = Neighbours.roll(days: days(pages), start: date(2026, 7, 1), end: date(2026, 7, 31), calendar: calendar)
        XCTAssertEqual(july.first?.lines.contains("Gone in July 2026."), true)
        XCTAssertTrue(Neighbours.roll(days: days(pages), start: date(2026, 8, 1), end: date(2026, 8, 31), calendar: calendar).isEmpty)
    }

    func testABookBoundLateTellsThePeriodAsItWas() throws {
        var pages = try founding([treeSpell()])
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.goneRecord(gerald, now: date(2026, 7, 10), calendar: calendar)))
        let june = try XCTUnwrap(Neighbours.roll(days: days(pages), start: date(2026, 6, 1), end: date(2026, 6, 30), calendar: calendar).first)
        XCTAssertEqual(june.status, .living)
        XCTAssertFalse(june.lines.contains { $0.hasPrefix("Gone") })
    }

    func testTheMonthlyPrintsWhoLivesHereOnlyWhenSomebodyDoes() throws {
        let empty = MonthlyEditionBuilder.whoLivesHereSection(days: days([treeSpell()]), start: date(2026, 5, 1),
                                                             end: date(2026, 5, 31), calendar: calendar)
        XCTAssertTrue(empty.items.isEmpty)
        let pages = try founding([treeSpell()])
        let section = MonthlyEditionBuilder.whoLivesHereSection(days: days(pages), start: date(2026, 5, 1),
                                                               end: date(2026, 5, 31), calendar: calendar)
        XCTAssertEqual(section.id, MonthlyEditionBuilder.whoLivesHereID)
        XCTAssertEqual(section.title, "Who Lives Here")
        XCTAssertEqual(section.items.map(\.title), ["Gerald"])
    }

    // MARK: Elective titles (found on screen 11-25)

    func testAnElectiveTitleThatNamesItsSenderDoesNotSayTheNameTwice() {
        XCTAssertEqual(ElectiveOfferDraft.prompt(title: "A Field Note for Lysander Mosswood", sender: "Lysander Mosswood"),
                       "A Field Note for Lysander Mosswood")
        XCTAssertEqual(ElectiveOfferDraft.prompt(title: "A Visit to the Weir", sender: "Lysander Mosswood"),
                       "A Visit to the Weir: Lysander Mosswood")
        XCTAssertEqual(ElectiveOfferDraft.prompt(title: "A Quest", sender: nil), "A Quest: a character")
    }
}
