import XCTest
@testable import InsideCoverCore

/// Week one: every day opens with the Book doing something to the reader, at
/// most one new door opens a day, and the Academy's own business waits until
/// the reader has kept enough Pages to care about it.
final class FirstWeekTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func onboardingFact(on day: Int) -> SelfFact {
        SelfFact(
            id: "test:onboarding-name", questionID: "onboarding-name", question: "Name",
            answer: "Wren", bookTranslation: "", sensitivity: .identity,
            usePermission: .privateContext, tags: ["onboarding"],
            createdAt: date(day, hour: 9), updatedAt: date(day, hour: 9)
        )
    }

    private func page(_ text: String, on day: Int, hour: Int = 12) -> BookPage {
        BookPage(type: .souvenir, createdAt: date(day, hour: hour), promptText: "Souvenir", userInput: text)
    }

    private func surface(_ id: String, sourceID: String, type: BookPageType = .souvenir,
                         metadata: [String: String] = [:]) -> SurfacePage {
        SurfacePage(
            id: id, type: type, sourceID: sourceID, intent: .capture, renderStyle: .promptCard,
            score: 50, reason: "test", prompt: id, detail: "",
            payload: BookPagePayload(headline: id, body: "", metadata: metadata)
        )
    }

    private func inputs(startedOn day: Int, pages: [BookPage] = []) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [onboardingFact(on: day)]
        inputs.days = Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { id, pages in BookDay(id: id, date: pages[0].createdAt, pages: pages) }
        return inputs
    }

    // MARK: - The reader's day

    func testTheWeekIsCountedFromTheFirstAnswers() {
        let inputs = inputs(startedOn: 3)
        XCTAssertEqual(FirstWeek.readerDay(inputs: inputs, now: date(3, hour: 23)), 0)
        XCTAssertEqual(FirstWeek.readerDay(inputs: inputs, now: date(9)), 6)
        XCTAssertNil(FirstWeek.readerDay(inputs: inputs, now: date(10)), "the eighth day is past the week")
        XCTAssertNil(FirstWeek.readerDay(inputs: .empty, now: date(3)), "no first answers, no first week")
    }

    // MARK: - The first leaf is a move

    func testADoorStepsBackBehindTheFirstMove() {
        let calendarDoor = surface("calendar", sourceID: BookPageSourceRegistry.source(for: .calendar).id, type: .calendar)
        let quiet = surface("quiet", sourceID: "plain")
        let dare = surface("dare", sourceID: "dares", metadata: ["curatorActionCommission": "true"])
        let ordered = FirstWeek.ordered([calendarDoor, quiet, dare])
        XCTAssertEqual(ordered.map(\.id), ["dare", "calendar", "quiet"], "a dare is a move; the door waits")
    }

    func testARevealOutranksADareForTheFirstLeaf() {
        let pagewright = surface("pagewright", sourceID: FirstRunPageSequence.pagewrightIntroSourceID,
                                 metadata: ["opensPagewright": "true"])
        let dare = surface("dare", sourceID: "dares", metadata: ["curatorActionCommission": "true"])
        let reading = surface("reading", sourceID: "notices", metadata: ["milestone": "true"])
        XCTAssertEqual(FirstWeek.ordered([pagewright, dare, reading]).first?.id, "reading")
    }

    func testADeskThatAlreadyLeadsWithAMoveIsLeftAlone() {
        let dare = surface("dare", sourceID: "dares", metadata: ["curatorActionCommission": "true"])
        let door = surface("compass", sourceID: FirstRunPageSequence.compassIntroductionSourceID)
        XCTAssertEqual(FirstWeek.ordered([dare, door]).map(\.id), ["dare", "compass"])
        XCTAssertEqual(FirstWeek.ordered([door]).map(\.id), ["compass"], "a desk of only a door stays as it is")
    }

    // MARK: - One new door a day

    func testHeldDoorsDoNotShortenTheDesk() {
        let doors = [FirstRunPageSequence.compassIntroductionSourceID,
                     FirstRunPageSequence.pagewrightIntroSourceID,
                     BookPageSourceRegistry.source(for: .calendar).id].map { surface($0, sourceID: $0) }
        let pages = (0..<10).map { surface("page-\($0)", sourceID: "source-\($0)") }
        let bench = Array(doors.prefix(2)) + pages + [doors[2]]
        let desk = Array(FirstWeek.oneDoor(bench, doorsShownToday: []).prefix(9))
        XCTAssertEqual(desk.count, 9, "the desk refills from the bench behind the held doors")
        XCTAssertEqual(desk.filter(FirstWeek.isDoor).count, 1)
    }

    func testTheDeskShowsOneNewDoorADay() {
        let dare = surface("dare", sourceID: "dares", metadata: ["curatorActionCommission": "true"])
        let calendar = surface("calendar", sourceID: BookPageSourceRegistry.source(for: .calendar).id, type: .calendar)
        let compass = surface("compass", sourceID: FirstRunPageSequence.compassIntroductionSourceID)
        XCTAssertEqual(FirstWeek.ordered([dare, calendar, compass]).map(\.id), ["dare", "calendar"],
                       "a fresh day opens the first door it's offered")
        XCTAssertEqual(FirstWeek.ordered([dare, calendar, compass],
                                          doorsShownToday: [FirstRunPageSequence.compassIntroductionSourceID]).map(\.id),
                       ["dare", "compass"], "today's door stays open; another waits for tomorrow")
    }

    func testOnlyOneNewDoorOpensADay() {
        var inputs = inputs(startedOn: 3)
        // Day one: the Welcome (with the brain) was the door; the mission is done.
        inputs.surfaceHistory = [
            "source:\(BookPageSourceRegistry.source(for: .welcome).id)": SurfaceHistoryRecord(lastShownAt: date(3, hour: 10), recentShowCount: 1),
            "source:\(FirstRunPageSequence.firstMissionSourceID)": SurfaceHistoryRecord(lastShownAt: date(3, hour: 11), recentShowCount: 1)
        ]
        let sameDay = BookDay(id: BookDay.id(for: date(3)), date: date(3), pages: [])
        XCTAssertNil(FirstRunPageSequence.guidedRider(
            for: sameDay, context: CuratorContext.make(for: sameDay), inputs: inputs, now: date(3, hour: 15)
        ), "the Pagewright waits for tomorrow")

        let nextDay = BookDay(id: BookDay.id(for: date(4)), date: date(4), pages: [])
        XCTAssertEqual(FirstRunPageSequence.guidedRider(
            for: nextDay, context: CuratorContext.make(for: nextDay), inputs: inputs, now: date(4, hour: 10)
        )?.sourceID, FirstRunPageSequence.pagewrightIntroSourceID)
    }

    // MARK: - The Academy waits for the reader

    func testTheAcademyOpensAfterEnoughKeptPages() {
        let few = (0..<3).map { page("A kept sentence with some substance number \($0).", on: 3, hour: 10 + $0) }
        XCTAssertFalse(FirstWeek.academyIsOpen(inputs: inputs(startedOn: 3, pages: few), today: nil, now: date(4)))

        let enough = (0..<FirstWeek.academyKeepThreshold).map {
            page("A kept sentence with some substance number \($0).", on: 3 + $0 / 3, hour: 10 + $0 % 3)
        }
        let open = inputs(startedOn: 3, pages: enough)
        XCTAssertTrue(FirstWeek.academyIsOpen(inputs: open, today: nil, now: date(6)))
        let opened = enough.last!.createdAt
        XCTAssertTrue(FirstWeek.academyJustOpened(inputs: open, today: nil, now: opened.addingTimeInterval(3_600)))
        XCTAssertFalse(FirstWeek.academyJustOpened(inputs: open, today: nil, now: opened.addingTimeInterval(3 * 86_400)),
                       "the news is told once, around the day it happens")
    }

    func testAReaderWhoSkippedTheQuestionsStillHasAFirstWeek() {
        var inputs = BookSourceInputs.empty
        let first = page("The kettle clicked off just as the rain started.", on: 3)
        inputs.days = [BookDay(id: BookDay.id(for: first.createdAt), date: first.createdAt, pages: [first])]
        XCTAssertEqual(FirstWeek.readerDay(inputs: inputs, now: date(4)), 1, "counted from the first kept Page")
        XCTAssertFalse(FirstWeek.academyIsOpen(inputs: inputs, today: nil, now: date(4)))
    }

    func testAQuietReaderIsLetInAfterTheWeek() {
        let one = inputs(startedOn: 3, pages: [page("A kept sentence with some substance.", on: 3)])
        XCTAssertFalse(FirstWeek.academyIsOpen(inputs: one, today: nil, now: date(9)))
        XCTAssertTrue(FirstWeek.academyIsOpen(inputs: one, today: nil, now: date(10)))
        XCTAssertTrue(FirstWeek.academyJustOpened(inputs: one, today: nil, now: date(10)),
                      "the Academy still announces itself when the week opens the doors")
        XCTAssertFalse(FirstWeek.academyJustOpened(inputs: one, today: nil, now: date(13)))
    }

    func testTheCensusCountsTheReaderBeforeTheCast() {
        var inputs = inputs(startedOn: 3, pages: [page("The kettle clicked off just as the rain started.", on: 3)])
        inputs.relationshipField = ["a|b": RelationshipTie(warmth: 1)]
        let today = BookDay(id: BookDay.id(for: date(4)), date: date(4), pages: [])
        let census = BookTodayCensusProjector.census(for: today, inputs: inputs, relationship: BookRelationshipSnapshot.firstOpening, now: date(4))
        let held = BookTodayCensusProjector.academyCensusFactIDs.union(["changed-relationships", "relationship-receipts"])
        XCTAssertTrue(census.facts.allSatisfy { !held.contains($0.id) }, "\(census.facts.map { $0.id })")
    }

    func testABookThatHasNotBegunIsOpen() {
        XCTAssertTrue(FirstWeek.academyIsOpen(inputs: .empty, today: nil))
    }
}
