import XCTest
@testable import InsideCoverCore

/// Phase 3: deals, finished. The Book answers back when a deal is called in
/// and answered, the old return visits ride the due tier, and the Reader's
/// Sheet counts what's still standing.
final class DealsFinishedTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date { calendar.date(from: DateComponents(year: 2027, month: 3, day: 10, hour: 12))! }

    private func spell(_ id: String = "name-a-tree", words: String = "The tree is called Gerald.", daysAgo: Int,
                       pageID: String = "tree-page") -> BookPage {
        BookPage(id: pageID, type: .spell, createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
                 promptText: "A spell", userInput: words, tags: ["spell", "spell:\(id)"])
    }

    private func surface(tags: [String], id: String = "answered") -> SurfacePage {
        SurfacePage(
            id: id, type: .wonderCompass, sourceID: "wonder-compass", intent: .capture, renderStyle: .promptCard,
            score: 60, reason: "", prompt: "", detail: "",
            payload: BookPagePayload(headline: "", body: "", metadata: [
                "playfulMissionID": "x", "tags": tags.joined(separator: ",")
            ])
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] { [BookDay(id: "archive", date: now, pages: pages)] }

    // MARK: The reply

    func testAnAnsweredCallInGetsTheBooksReplyAndItNeverJudges() throws {
        let note = try XCTUnwrap(DealReplyMarginalia.note(
            for: surface(tags: ["playful-mission", "mission:promise-call:tree-page:d30"]),
            readerInput: "I forgot twice and then said it three times to make up.",
            priorDays: days([spell(daysAgo: 30)])))
        XCTAssertEqual(note.castSlug, "the-book")
        XCTAssertTrue(note.line.contains("a month on"), note.line)
        for judgement in ["well done", "good", "proud", "shame", "should", "kept your side", "broke"] {
            XCTAssertFalse(note.line.lowercased().contains(judgement), "\(judgement) in \(note.line)")
        }
        XCTAssertFalse(note.line.contains("the Book"))
    }

    func testTheReplyUsesTheNeighboursNameWhenTheDealFoundedOne() throws {
        let page = spell(daysAgo: 7)
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([page]), calendar: calendar).first)
        let record = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days([page]), now: now))
        let note = try XCTUnwrap(DealReplyMarginalia.note(
            for: surface(tags: ["mission:promise-call:tree-page:d7"]),
            readerInput: "Said hello to Gerald every morning.",
            priorDays: days([page, record])))
        XCTAssertTrue(note.line.contains("Gerald"), note.line)
        XCTAssertTrue(note.line.contains("a week on"), note.line)
    }

    func testTheReplyGoesThroughTheOrdinaryReturnMarginalia() throws {
        let note = try XCTUnwrap(LivedMissionReturnMarginalia.note(
            for: surface(tags: ["mission:promise-call:tree-page:y2"]),
            readerInput: "Still saying hello.", priorDays: days([spell(daysAgo: 730)])))
        XCTAssertEqual(note.castSlug, "the-book")
        XCTAssertTrue(note.line.contains("two years on"), note.line)
    }

    func testAnEmptyAnswerOrAnOrdinaryMissionGetsNoDealReply() {
        XCTAssertNil(DealReplyMarginalia.note(for: surface(tags: ["mission:promise-call:tree-page:d7"]),
                                              readerInput: "  ", priorDays: []))
        XCTAssertNil(DealReplyMarginalia.note(for: surface(tags: ["playful-mission", "mission:object"]),
                                              readerInput: "A spoon.", priorDays: []))
    }

    func testAVisitAnswerIsFiledOnTheNeighboursPage() throws {
        let page = spell(daysAgo: 20)
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([page]), calendar: calendar).first)
        let record = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days([page]), now: now))
        let note = try XCTUnwrap(DealReplyMarginalia.note(
            for: surface(tags: ["mission:neighbour-of:gerald", "mission:neighbour-visit:gerald:v0"]),
            readerInput: "A pigeon had been at it.", priorDays: days([page, record])))
        XCTAssertTrue(note.line.contains("Gerald"), note.line)

        // And the kept answer becomes one of Gerald's Pages even though it
        // never says his name.
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "neighbour-visit-gerald-v0", title: "x", invitation: "x",
            proofPrompt: "One sentence.", facets: [.exactAttention],
            sourceTags: ["mission:neighbour-of:gerald", "mission:neighbour-visit:gerald:v0"],
            hasWrittenProof: true, hasVisualProof: false, completedAt: now, wasPromptedByBook: true)
        let answer = BookPage(id: "visit", type: .wonderCompass, createdAt: now, promptText: "x",
                              userInput: "A pigeon had been at it.", livedQuestReceipt: receipt)
        let gerald = try XCTUnwrap(Neighbours.register(days: days([page, record, answer])).first)
        XCTAssertEqual(gerald.pageIDs.last, "visit")
    }

    // MARK: Return visits on the due tier

    func testAReturnVisitNowTakesTheMissionSeatOnAlternateTurns() {
        let at = now.addingTimeInterval(-12 * 3_600)
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "faerie-name-earned", title: "Give It a Name", invitation: "Name it.",
            proofPrompt: "What did you name?", facets: [.exactAttention], sourceTags: [],
            hasWrittenProof: true, hasVisualProof: false, completedAt: at.addingTimeInterval(-2 * 86_400),
            wasPromptedByBook: true)
        let source = BookPage(id: "dribble", type: .wonderCompass, createdAt: at.addingTimeInterval(-2 * 86_400),
                              promptText: "Give It a Name", userInput: "The blue thermos is Dribble. It leaks.",
                              livedQuestReceipt: receipt)
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "archive", date: at, pages: [source])]
        let today = BookDay(id: "today", date: at, pages: [])
        var returned = 0
        var ordinary = 0
        for slot in 0..<12 {
            let mission = PlayfulMissionRegistry.mission(for: today, inputs: inputs, now: at.addingTimeInterval(Double(slot) * 7_200))
            if mission.id.hasPrefix("faerie-return-") { returned += 1 } else { ordinary += 1 }
        }
        XCTAssertGreaterThan(returned, 0, "the return visit never reached the mission seat")
        XCTAssertGreaterThan(ordinary, 0, "the return visit crowded out every ordinary errand")
    }

    func testANeighboursOwnVisitsSupersedeTheNamelessReturn() throws {
        let at = now.addingTimeInterval(-2 * 86_400)
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "faerie-name-earned", title: "Give It a Name", invitation: "Name it.",
            proofPrompt: "What did you name?", facets: [.exactAttention], sourceTags: [],
            hasWrittenProof: true, hasVisualProof: false, completedAt: at, wasPromptedByBook: true)
        let source = BookPage(id: "dribble", type: .wonderCompass, createdAt: at, promptText: "Give It a Name",
                              userInput: "The blue thermos is Dribble. It leaks.", livedQuestReceipt: receipt)
        let today = BookDay(id: "today", date: now, pages: [])
        let returns = PlayfulMissionRegistry.returnMissions(for: today, inputs: { var i = BookSourceInputs.empty; i.days = days([source]); return i }(), now: now)
        XCTAssertEqual(returns.count, 1)
        XCTAssertEqual(Neighbours.supersedingVisits(returns, days: days([source])).count, 1, "no Neighbour yet")
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([source]), calendar: calendar).first)
        XCTAssertEqual(proposal.name, "Dribble")
        let record = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days([source]), now: now))
        XCTAssertTrue(Neighbours.supersedingVisits(returns, days: days([source, record])).isEmpty)
    }

    // MARK: The Reader's Sheet

    func testTheSheetCountsStandingDealsAndNotOnesThatWereOverThatDay() {
        var inputs = BookSourceInputs.empty
        inputs.days = days([
            spell(daysAgo: 40),
            spell("first-star", words: "I wished.", daysAgo: 3, pageID: "star"),
            spell("leave-a-gift", words: "A marble.", daysAgo: 8, pageID: "gift"),
            spell("bibliomancy", words: "Soup.", daysAgo: 2, pageID: "book")
        ])
        let sheet = ReadersSheetBuilder.build(inputs: inputs, now: now)
        XCTAssertEqual(sheet.standingDealCount, 2)
        let standing = sheet.readerFacingSections.first { $0.id == "standing" }?.text ?? ""
        XCTAssertTrue(standing.contains("You've got 2 deals standing. I come back for every one."), standing)
    }

    func testALostNeighboursDealNoLongerStands() throws {
        let page = spell(daysAgo: 40)
        var pages = [page]
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        pages.append(try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days(pages), now: now)))
        XCTAssertEqual(PlayfulMissionRegistry.standingDeals(days: days(pages)).count, 1)
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.goneRecord(gerald, now: now, calendar: calendar)))
        XCTAssertTrue(PlayfulMissionRegistry.standingDeals(days: days(pages)).isEmpty)
    }

    func testTheSheetNamesTheLivingNeighbours() throws {
        let page = spell(daysAgo: 40)
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([page]), calendar: calendar).first)
        var inputs = BookSourceInputs.empty
        inputs.days = days([page, try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days([page]), now: now))])
        let sheet = ReadersSheetBuilder.build(inputs: inputs, now: now)
        XCTAssertEqual(sheet.neighbourNames, ["Gerald"])
        let company = sheet.readerFacingSections.first { $0.id == "company" }?.text ?? ""
        XCTAssertTrue(company.contains("Your Neighbours: Gerald."), company)
    }
}
