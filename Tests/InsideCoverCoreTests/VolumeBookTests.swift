import XCTest
@testable import InsideCoverCore

/// Seasons and years are books in three parts now: the days, the pictures, the Academy. These
/// guard the data each part prints from: the term's Handbook, its Register, and the connections
/// the Book worked out about the reader.
final class VolumeBookTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? Date()
    }

    private func sitting(_ id: String, _ session: String, lesson: String, month: Int, day: Int, answer: String? = nil) -> BookPage {
        var page = BookPage(id: id, type: .academyClass, createdAt: date(month, day, hour: 16), promptText: "Class", userInput: "Sat")
        var meta = ["sessionID": session, "lessonModuleID": lesson]
        if let answer { meta["academyActivityOutcome"] = answer }
        page.metadata = meta
        return page
    }

    // MARK: The Register

    func testTheRegisterListsEverySittingInOrderWithTheLessonItWas() {
        let pages = [
            sitting("c", "art-of-the-glint", lesson: "glint-filter-003", month: 11, day: 10, answer: "Three kept things."),
            sitting("a", "art-of-the-glint", lesson: "glint-specificity-001", month: 9, day: 9),
            sitting("b", "wayfinding-kineticism", lesson: "wayfinding-ticket-002", month: 10, day: 15, answer: "The bench by the water.")
        ]
        let register = HandbookBuilder.transcript(from: pages, calendar: calendar)
        XCTAssertEqual(register.map(\.sessionID), ["art-of-the-glint", "wayfinding-kineticism", "art-of-the-glint"])
        XCTAssertEqual(register.map(\.lessonNumber), [1, 2, 3])
        XCTAssertEqual(register.first?.lessonTitle, "The Doorknob Test")
        XCTAssertNil(register.first?.answer, "No answer is invented for a sitting the reader brought nothing back from")
        XCTAssertEqual(register.last?.answer, "Three kept things.")
    }

    func testTheSameLessonSatTwiceIsOneLineKeepingTheLastAnswer() {
        let pages = [
            sitting("a", "art-of-the-glint", lesson: "glint-specificity-001", month: 9, day: 9, answer: "First go."),
            sitting("b", "art-of-the-glint", lesson: "glint-specificity-001", month: 9, day: 16, answer: "Second go.")
        ]
        let register = HandbookBuilder.transcript(from: pages, calendar: calendar)
        XCTAssertEqual(register.count, 1)
        XCTAssertEqual(register.first?.answer, "Second go.")
    }

    // MARK: The season's Handbook

    private func seasonDays() -> [BookDay] {
        var days: [BookDay] = []
        for offset in stride(from: 0, to: 90, by: 2) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date(9, 1)) else { continue }
            let id = BookDay.id(for: day, calendar: calendar)
            days.append(BookDay(id: id, date: calendar.startOfDay(for: day), pages: [
                BookPage(id: "s-\(id)", type: .souvenir, createdAt: day, promptText: "One true sentence",
                         userInput: "The kettle rattled again on \(id)."),
                BookPage(id: "b-\(id)", type: .bookOfYou, createdAt: day.addingTimeInterval(36_000),
                         promptText: "Tonight", userInput: "The night kept the kettle on \(id).")
            ]))
        }
        days[3].pages.append(sitting("g1", "art-of-the-glint", lesson: "glint-specificity-001", month: 9, day: 7, answer: "A dent on the lid."))
        days[20].pages.append(sitting("g2", "art-of-the-glint", lesson: "glint-gorilla-002", month: 10, day: 11))
        return days
    }

    func testASeasonCarriesOneHandbookForTheTermWithItsRegister() throws {
        let season = MonthlyEditionBuilder.seasonal(from: seasonDays(), startingMonth: date(9, 1),
                                                    readerName: "Reader", now: date(12, 2), calendar: calendar)
        let handbook = try XCTUnwrap(season.handbook, "A season is a term: it binds one Handbook across its months")
        XCTAssertEqual(handbook.transcript?.count, 2)
        XCTAssertNil(handbook.keepsakes, "A month's at-a-glance keepsakes don't belong in a term")
        XCTAssertLessThanOrEqual(handbook.ruinCount ?? 0, 2)
        for question in handbook.workbook?.exam?.questions ?? [] {
            XCTAssertFalse(question.prompt.contains("this month"), question.prompt)
        }
        XCTAssertTrue(season.chapters.allSatisfy { $0.handbook == nil }, "The term's Handbook is bound once, not per chapter")
    }

    func testTheMergedDayBookCountsTheWholeTerm() {
        let season = MonthlyEditionBuilder.seasonal(from: seasonDays(), startingMonth: date(9, 1),
                                                    readerName: "Reader", now: date(12, 2), calendar: calendar)
        let merged = MonthlyEditionBuilder.mergedDayBook(season.chapters)
        XCTAssertEqual(merged?.days.count, season.chapters.compactMap(\.dayBook).reduce(0) { $0 + $1.days.count })
        XCTAssertEqual(merged?.days.map(\.date), merged?.days.map(\.date).sorted())
    }

    // MARK: Connections

    func testConnectionsCarryTheirEvidenceAndNeverRepeatALine() {
        // "kettle" on most written days: a word leant on.
        let connections = EditionConnections.make(days: seasonDays(), now: date(12, 2), calendar: calendar, limit: 6)
        XCTAssertFalse(connections.isEmpty)
        for connection in connections {
            XCTAssertFalse(connection.reading.isEmpty, connection.id)
            let excerpts = connection.evidence.map { $0.excerpt.lowercased() }
            if !connection.title.contains("twice") {
                XCTAssertEqual(excerpts.count, Set(excerpts).count, "The same sentence twice isn't two pieces of evidence")
            }
        }
        XCTAssertEqual(connections.map(\.strength), connections.map(\.strength).sorted(by: >), "Strongest first")
    }

    func testConnectionsAreTheSameEveryTimeTheyreAskedFor() {
        let first = EditionConnections.make(days: seasonDays(), now: date(12, 2), calendar: calendar)
        let second = EditionConnections.make(days: seasonDays(), now: date(12, 2), calendar: calendar)
        XCTAssertEqual(first, second)
    }
}
