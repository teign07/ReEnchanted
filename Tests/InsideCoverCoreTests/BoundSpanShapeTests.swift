import Foundation
import XCTest

@testable import InsideCoverCore

/// What a week, a month or a year says it was.
///
/// The volume reads structure, never prose. These tests are mostly about what
/// it refuses to say.
final class BoundSpanShapeTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func braid(_ day: String, moveKey: String, kept: String) -> BookDay {
        let at = date("\(day)T21:00:00Z")
        var page = BookPage(
            id: "braid-\(day)",
            type: .bookOfYou,
            createdAt: at,
            promptText: "Book of You: A Night",
            userInput: "A Night\n\nSomething happened.\n\n\(kept)",
            tags: ["braid-move:\(moveKey)"],
            origin: .generated
        )
        page.tags.append(BookOfYouResidue.markerTag)
        page.tags.append(BookOfYouResidue.keptPrefix + kept)
        return BookDay(id: day, date: at, pages: [page])
    }

    private func tale(closed: Bool, ending: TaleEnding? = nil, title: String) -> LivingTale {
        LivingTale(
            id: "t1",
            shape: .forbiddenDoor,
            title: title,
            witnesses: [],
            openedAt: date("2026-09-02T21:00:00Z"),
            lastWitnessedAt: date("2026-09-20T21:00:00Z"),
            closedAt: closed ? date("2026-09-25T21:00:00Z") : nil,
            ending: ending
        )
    }

    private func read(_ days: [BookDay], tales: [LivingTale] = []) -> BoundSpanShape.Reading {
        BoundSpanShape.read(
            days: days, tales: tales,
            from: date("2026-09-01T00:00:00Z"), to: date("2026-09-30T23:59:59Z"))
    }

    // MARK: - Reading

    func testHouseThreadsAreWeatherAndNotStory() {
        let reading = read([
            braid("2026-09-03", moveKey: "tale:moth", kept: "The Book kept the page: the bowl."),
            braid("2026-09-04", moveKey: "tale:bell", kept: "The Book kept the page: the lamp.")
        ])
        XCTAssertTrue(reading.isQuiet, "a paper moth is not a plot point")
    }

    func testBeatThreadsAreReadAsStructure() {
        let reading = read([
            braid("2026-09-03", moveKey: "tale:lack", kept: "The Book kept the page: the gap."),
            braid("2026-09-10", moveKey: "tale:crossing", kept: "The Book kept the page: the door.")
        ])
        XCTAssertEqual(reading.beats.map(\.beat), [.lack, .crossing])
        XCTAssertEqual(reading.beats.first?.line, "The Book kept the page: the gap.")
    }

    func testBeatsComeBackInTheOrderTheyHappened() {
        let reading = read([
            braid("2026-09-20", moveKey: "tale:price", kept: "b"),
            braid("2026-09-05", moveKey: "tale:lack", kept: "a")
        ])
        XCTAssertEqual(reading.beats.map(\.beat), [.lack, .price])
    }

    func testDaysOutsideTheSpanAreNotCounted() {
        let reading = read([braid("2026-08-15", moveKey: "tale:lack", kept: "x")])
        XCTAssertTrue(reading.isQuiet)
    }

    /// A tale the reader denied is not a story the volume gets to tell.
    func testARefusedTaleIsNotCountedAsFinished() {
        let reading = read([], tales: [tale(closed: true, ending: .abandoned, title: "The Door")])
        XCTAssertTrue(reading.closed.isEmpty)
    }

    // MARK: - What it says

    func testAQuietSpanSaysSoWithoutApologising() {
        let line = BoundSpanShape.colophon(for: read([]), span: "month")
        XCTAssertTrue(line.contains("not going to invent one"), line)
        XCTAssertFalse(line.lowercased().contains("sorry"), line)
    }

    /// A bound tale's title came from the reader's own words, so naming it is
    /// quoting them - not the Book announcing what their life meant.
    func testAFinishedTaleIsNamedBecauseTheReaderNamedIt() {
        let reading = read([], tales: [tale(closed: true, ending: .imperfect, title: "The Spare Room")])
        let line = BoundSpanShape.colophon(for: reading, span: "month")
        XCTAssertTrue(line.contains("The Spare Room"), line)
        XCTAssertTrue(line.contains("kept the receipts"), line)
    }

    /// A shape that is still running is never named, at any scale. This is the
    /// same law the nightly page is held to.
    func testARunningShapeIsNeverNamedInAVolume() {
        let reading = read([
            braid("2026-09-03", moveKey: "tale:transgression", kept: "x")
        ], tales: [tale(closed: false, title: "The Spare Room")])
        let line = BoundSpanShape.colophon(for: reading, span: "month")
        XCTAssertTrue(line.contains("Something has been running"), line)
        XCTAssertFalse(line.contains("The Spare Room"), line)
        XCTAssertFalse(line.contains("Forbidden Door"), line)
    }

    func testTheColophonCountsNothingOutLoud() {
        let reading = read([
            braid("2026-09-03", moveKey: "tale:lack", kept: "x"),
            braid("2026-09-04", moveKey: "tale:price", kept: "y"),
            braid("2026-09-05", moveKey: "tale:test", kept: "z")
        ])
        let line = BoundSpanShape.colophon(for: reading, span: "month")
        for naked in ["3", "three", "beats", "pages"] {
            XCTAssertFalse(line.lowercased().contains(naked), naked)
        }
    }

    func testEveryBeatHasSomethingToSay() {
        for beat in TaleBeat.allCases {
            let reading = BoundSpanShape.Reading(
                beats: [.init(beat: beat, day: date("2026-09-03T21:00:00Z"), line: "x")],
                opened: [], closed: [])
            let line = BoundSpanShape.colophon(for: reading, span: "week")
            XCTAssertFalse(line.isEmpty)
            XCTAssertTrue(line.contains("Something has been running"), "\(beat)")
        }
    }

    // MARK: - The rungs

    /// One builder makes every rung, so the span has to be read off the range.
    /// Without this an annual hardcover opened by telling you what "this
    /// month" was.
    func testEachRungCallsItselfByItsOwnName() {
        let calendar = Calendar(identifier: .gregorian)
        func word(_ days: Int) -> String {
            MonthlyEditionBuilder.spanWord(
                from: date("2026-01-01T00:00:00Z"),
                to: date("2026-01-01T00:00:00Z").addingTimeInterval(Double(days) * 86_400),
                calendar: calendar)
        }
        XCTAssertEqual(word(6), "week")
        XCTAssertEqual(word(30), "month")
        XCTAssertEqual(word(90), "season")
        XCTAssertEqual(word(364), "year")
    }
}
