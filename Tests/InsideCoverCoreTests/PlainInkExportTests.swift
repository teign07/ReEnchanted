import XCTest
@testable import InsideCoverCore

final class PlainInkExportTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return calendar.date(from: comps)!
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, pages: [BookPage]) -> BookDay {
        let start = date(y, m, d)
        return BookDay(id: AlmanacModel.dayID(for: start, calendar: calendar), date: start, pages: pages)
    }

    func testMarkdownHasHeadingsBodiesTagsInOrder() {
        let days = [
            day(2027, 3, 3, pages: [
                BookPage(id: "a", type: .diary, createdAt: date(2027, 3, 3, 9),
                         promptText: "What did you notice?", userInput: "The kettle sang twice.",
                         tags: ["kitchen", "morning"]),
                BookPage(id: "b", type: .diary, createdAt: date(2027, 3, 3, 18),
                         promptText: "", userInput: "Rain all evening."),
            ]),
            day(2027, 3, 5, pages: [
                BookPage(id: "c", type: .diary, createdAt: date(2027, 3, 5, 10),
                         promptText: "", userInput: "A good walk."),
            ]),
        ]
        let md = PlainInkExport.markdown(days: days, calendar: calendar, title: "My Book")

        XCTAssertTrue(md.hasPrefix("# My Book"))
        XCTAssertTrue(md.contains("## Wednesday, March 3, 2027"))
        XCTAssertTrue(md.contains("## Friday, March 5, 2027"))
        XCTAssertTrue(md.contains("> What did you notice?"))
        XCTAssertTrue(md.contains("The kettle sang twice."))
        XCTAssertTrue(md.contains("Rain all evening."))
        XCTAssertTrue(md.contains("_#kitchen #morning_"))

        // Bodies appear in chronological order.
        let kettle = try! XCTUnwrap(md.range(of: "The kettle sang twice."))
        let rain = try! XCTUnwrap(md.range(of: "Rain all evening."))
        let walk = try! XCTUnwrap(md.range(of: "A good walk."))
        XCTAssertTrue(kettle.lowerBound < rain.lowerBound)
        XCTAssertTrue(rain.lowerBound < walk.lowerBound)
    }

    func testEmptyDaysAreSkipped() {
        let days = [
            day(2027, 3, 3, pages: []), // no captured pages
            day(2027, 3, 4, pages: [
                BookPage(id: "x", type: .diary, createdAt: date(2027, 3, 4), promptText: "", userInput: "Something."),
            ]),
        ]
        let md = PlainInkExport.markdown(days: days, calendar: calendar)
        XCTAssertFalse(md.contains("March 3, 2027"))
        XCTAssertTrue(md.contains("March 4, 2027"))
    }
}
