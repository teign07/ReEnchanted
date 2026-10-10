import XCTest
@testable import InsideCoverCore

final class WeeklyTaleReadingTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }

    private func date(_ day: Int, month: Int = 10, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func page(_ id: String, _ text: String, day: Int, month: Int = 10,
                      type: BookPageType = .diary, origin: BookPageOrigin? = nil) -> BookPage {
        BookPage(id: id, type: type, createdAt: date(day, month: month), promptText: "One true thing",
                 userInput: text, origin: origin)
    }

    private func issue(_ pages: [BookPage], start: Date? = nil) -> WeeklyIssue {
        let first = start ?? calendar.startOfDay(for: date(8))
        return WeeklyIssue(number: 41, startDate: first, endDate: calendar.date(byAdding: .day, value: 7, to: first)!,
                           dateRange: "Reader week", keptCount: pages.count,
                           highlights: ["An invented golden dragon spun a lesson out of the Reader's life."],
                           setAsideLine: nil, pages: pages)
    }

    func testOpeningAndClosingUseActualDatedWordsNotGeneratedHighlights() throws {
        let reading = WeeklyTaleReading(issue: issue([
            page("roof", "The low grey sky makes the street feel like a room.", day: 8),
            page("plate", "The brass plate is worn silver in exactly the shape of a thumb.", day: 14)
        ]), calendar: calendar)
        XCTAssertTrue(reading.note(at: .opening).contains("Thursday, you wrote"))
        XCTAssertTrue(reading.note(at: .closing).contains("Wednesday, you wrote"))
        XCTAssertTrue(reading.note(at: .closing).contains("exactly the shape of a thumb."))
        XCTAssertFalse(reading.note(at: .opening).contains("dragon"))
        XCTAssertFalse(reading.note(at: .closing).contains("lesson"))
    }

    func testReaderSubjectsAndNegationAreKeptVerbatim() {
        let text = "The heron moved its head. I did not wave."
        let reading = WeeklyTaleReading(issue: issue([page("heron", text, day: 8)]), calendar: calendar)
        XCTAssertTrue(reading.note(at: .opening).contains("“The heron moved its head. I did not wave.”"))
        XCTAssertFalse(reading.note(at: .opening).contains("You moved"))
    }

    func testPrivateLogsGeneratedPagesAndOtherWeeksNeverReachTheEditorialDesk() {
        let reading = WeeklyTaleReading(issue: issue([
            page("real", "The sparrow was arguing with the fence.", day: 9),
            page("private", "My body hurts and the doctor called.", day: 10, type: .body),
            page("generated", "You flew through a silver door.", day: 11, type: .bookOfYou, origin: .generated),
            page("other-week", "My secret elephant.", day: 15),
            page("prompt", "The prepared waterfall spoke.", day: 12, type: .bookNotices, origin: .generated)
        ]), calendar: calendar)
        XCTAssertEqual(reading.moments.map(\.pageID), ["real"])
        XCTAssertFalse(reading.prompt(at: .opening).contains("doctor"))
        XCTAssertFalse(reading.prompt(at: .opening).contains("elephant"))
    }

    func testSameThingOnDifferentDaysConnectsButRepeatedWordsOnOneDayDoNot() {
        let reading = WeeklyTaleReading(issue: issue([
            page("a", "The heron stood by the canal.", day: 8),
            page("b", "The heron was gone from the canal.", day: 11),
            page("c", "The kettle kettle kettle went quiet.", day: 14)
        ]), calendar: calendar)
        XCTAssertTrue(reading.returns.contains { $0.word == "heron" })
        XCTAssertFalse(reading.returns.contains { $0.word == "kettle" })
        XCTAssertTrue(reading.note(at: .opening).contains("On Thursday, you wrote"))
        XCTAssertTrue(reading.note(at: .opening).contains("Then on Sunday, you wrote"))
        XCTAssertFalse(reading.note(at: .opening).contains("changed your life"))
    }

    func testSharedVerbsDoNotBecomeFalseReturns() {
        let reading = WeeklyTaleReading(issue: issue([
            page("a", "I bought a recorder.", day: 8),
            page("b", "I bought apples.", day: 9)
        ]), calendar: calendar)
        XCTAssertTrue(reading.returns.isEmpty)
        let neighbour = WeeklyTaleReading(issue: issue([
            page("a", "I walked the dog from next door.", day: 8),
            page("b", "The back door has a brass plate.", day: 9)
        ]), calendar: calendar)
        XCTAssertTrue(neighbour.returns.isEmpty, "A neighbour and a physical door are different things.")
    }

    func testSparseWeekDoesNotPretendTheReaderRecordedEveryDay() {
        let reading = WeeklyTaleReading(issue: issue([page("only", "I miss Dad.", day: 10)]), calendar: calendar)
        XCTAssertEqual(reading.moments.count, 1)
        XCTAssertTrue(reading.note(at: .opening).contains("I miss Dad."))
        XCTAssertFalse(reading.note(at: .closing).contains("seven days"))
        XCTAssertFalse(reading.note(at: .closing).contains("whole"))
        let empty = WeeklyTaleReading(issue: issue([]), calendar: calendar)
        XCTAssertTrue(empty.note(at: .closing).contains("won't make up"))
        XCTAssertNil(empty.title)
    }

    func testEveryMonthUsesItsOwnWeekAndNoDateIsHardcoded() {
        for month in [1, 2, 5, 7, 11, 12] {
            let start = calendar.startOfDay(for: date(8, month: month))
            let text = "The chipped yellow bowl is still on the table."
            let reading = WeeklyTaleReading(issue: issue([page("\(month)", text, day: 8, month: month)], start: start), calendar: calendar)
            XCTAssertEqual(reading.focus(for: .opening)?.text, text)
            XCTAssertTrue(reading.note(at: .opening).contains(text))
        }
    }

    func testExcerptEndsWholeIncludingClockAbbreviationsAndQuotedPunctuation() {
        XCTAssertEqual(WeeklyTaleReading.excerpt("At 7:52 a.m. the bakery remembered my bread. I went home."),
                       "At 7:52 a.m. the bakery remembered my bread.")
        let long = "I kept " + String(repeating: "the small blue stone and ", count: 35) + "the red feather."
        XCTAssertEqual(WeeklyTaleReading.excerpt(long), long)
    }

    func testModelWritesBookJoinsButCannotChangeAReaderFactOrInventAMoral() throws {
        let reading = WeeklyTaleReading(issue: issue([page("a", "The heron moved its head.", day: 8)]), calendar: calendar)
        let raw = "BOOK I want to start with the heron.\nBOOK I'll keep the pages open for you."
        let lines = try XCTUnwrap(reading.acceptedBookLines(raw, at: .opening))
        let note = reading.note(at: .opening, bookLines: lines)
        XCTAssertTrue(note.contains("“The heron moved its head.”"))
        XCTAssertTrue(note.contains("I'll keep the pages open for you."))
        for bad in [
            "BOOK I watched you move the heron's head.\nBOOK I kept it.",
            "BOOK I know you felt afraid.\nBOOK I kept it.",
            "BOOK I want to open the secret castle.\nBOOK I kept it.",
            "BOOK I think this represents your growth.\nBOOK I kept it.",
            "BOOK I turned the heron into a feather.\nBOOK I kept it.",
            "BOOK I want to start here.",
            "BOOK I want to start here. A dragon arrived.\nBOOK I kept it."
        ] {
            XCTAssertNil(reading.acceptedBookLines(bad, at: .opening), bad)
        }
    }

    func testTitleCannotImportAPromptOrMadeUpObject() {
        let reading = WeeklyTaleReading(issue: issue([page("a", "The chipped yellow bowl is still on the table.", day: 8)]), calendar: calendar)
        XCTAssertEqual(reading.acceptedTitle("The Chipped Yellow Bowl"), "The Chipped Yellow Bowl")
        XCTAssertNil(reading.acceptedTitle("The Secret Castle"))
        XCTAssertNil(reading.acceptedTitle("Yellow Chipped Bowl"), "A bag of source words isn't a phrase.")
    }

    func testGemmaCanChooseBookVoiceButCannotInventAChoice() throws {
        let reading = WeeklyTaleReading(issue: issue([page("a", "The chipped yellow bowl is still on the table.", day: 8)]), calendar: calendar)
        let lines = try XCTUnwrap(reading.acceptedBookLines("START3\nEND2", at: .opening))
        let choices = reading.bookLineChoices(at: .opening)
        XCTAssertEqual(lines, [choices.first[2], choices.last[1]])
        XCTAssertTrue(reading.note(at: .opening, bookLines: lines).contains("“The chipped yellow bowl is still on the table.”"))
        XCTAssertNil(reading.acceptedBookLines("START99\nEND2", at: .opening))
        XCTAssertNil(reading.acceptedBookLines("START3\nEND2\nYou cried.", at: .opening))
    }

    func testChapterNamesAndReturnsComeFromRealDays() throws {
        XCTAssertNotEqual(WeeklyTaleReading.heading(for: "Wore odd socks all day."), "Wore odd socks all")
        XCTAssertNotEqual(WeeklyTaleReading.heading(for: "Low grey sky sitting on the roofs."), "Low grey sky sitting")
        let pages = [
            page("a", "The heron stood by the canal.", day: 8),
            page("b", "The bakery remembered the end piece.", day: 9),
            page("c", "The heron was gone from the canal.", day: 11)
        ]
        let book = try XCTUnwrap(BoundDayBookBuilder.make(pages: pages, receipts: .empty, castActs: [],
                                           startDate: calendar.startOfDay(for: date(8)),
                                           endDate: calendar.startOfDay(for: date(15)), calendar: calendar))
        let chapters = WeeklyTaleBuilder.chapters(of: book, from: date(8, hour: 0), to: date(15, hour: 0).addingTimeInterval(-1), calendar: calendar)
        XCTAssertEqual(Set(chapters.map(\.heading)).count, chapters.count)
        XCTAssertTrue(chapters[1].heading.lowercased().contains("piece") || chapters[1].heading.lowercased().contains("bakery"))
        XCTAssertNil(chapters[0].returnNote)
        XCTAssertTrue(chapters[2].returnNote?.contains("Thursday") ?? false)
        XCTAssertFalse(chapters[2].opener.contains("the week finished"), "The last kept day needn't be the week's last day.")
    }
}
