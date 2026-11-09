import XCTest
@testable import InsideCoverCore

/// The Reader's Sheet (the `.frontMatter` Page): the reader's standing in one
/// place, and the Curse's file read off the Knocks.
final class ReaderSheetTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_783_484_800)

    private func context(at date: Date, place: String? = nil, weather: [String] = [],
                         sleep: Double? = nil) -> BookPageContextSnapshot {
        BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: weather, locationLabel: place,
                                sleepHours: sleep)
    }

    /// Ten days of two Knocks: mornings at the library come back "here", and
    /// afternoons in the kitchen in the rain mostly go grey, with words.
    private func foggyAfternoons() -> AttentionProbeLedger {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-12 * 86_400))
        for day in 0..<10 {
            let base = start.addingTimeInterval(Double(day) * 86_400)
            let morning = base.addingTimeInterval(9 * 3600)
            ledger.record(id: "here-\(day)", scheduledAt: morning, answeredAt: morning.addingTimeInterval(60),
                          answer: .here, cycle: 0,
                          context: context(at: morning, place: "the library", weather: ["clear"]))
            let afternoon = base.addingTimeInterval(15 * 3600)
            let isGrey = day % 5 != 0
            ledger.record(id: "pm-\(day)", scheduledAt: afternoon,
                          answeredAt: afternoon.addingTimeInterval(isGrey ? 20 * 60 : 60),
                          answer: isGrey ? .elsewhere : .here, cycle: 0,
                          sentence: isGrey ? "Scrolling the phone in the kitchen again, day \(day)" : nil,
                          context: context(at: afternoon, place: "the kitchen", weather: ["rain"]))
        }
        return ledger
    }

    // MARK: Standing

    func testTheSheetCarriesEveryStatInOnePlace() {
        let standing = ReaderSheetStanding.build(
            belief: 41,
            roleName: "The Lamplighter",
            roleGloss: "You notice what's lit.",
            attention: foggyAfternoons(),
            ribbons: [],
            inkbones: [],
            greyThreats: .empty,
            now: now,
            calendar: calendar
        )
        let ids = standing.rows.map(\.id)
        XCTAssertEqual(ids.first, "belief", "Belief leads the sheet")
        for id in ["belief", "role", "fight", "curse-hour", "ribbons", "inkbones"] {
            XCTAssertTrue(ids.contains(id), "missing \(id)")
        }
        XCTAssertEqual(standing.rows.first?.value, "41")
        XCTAssertEqual(standing.rows.first { $0.id == "role" }?.value, "The Lamplighter")
        XCTAssertEqual(standing.rows.first { $0.id == "ribbons" }?.value, "0 of 3")
        XCTAssertEqual(standing.rows.first { $0.id == "curse-hour" }?.value, "three in the afternoon")
        XCTAssertFalse(standing.rows.contains { $0.id == "grey" }, "no Grey row without a Grey Page")
    }

    func testAnUnnamedReaderIsToldHowToGetANameAndNothingSaysGlow() {
        let standing = ReaderSheetStanding.build(
            belief: 30, roleName: nil, roleGloss: nil,
            attention: .empty, ribbons: [], inkbones: [], greyThreats: .empty,
            now: now, calendar: calendar
        )
        XCTAssertEqual(standing.rows.first { $0.id == "role" }?.value, "Not named yet")
        XCTAssertEqual(standing.rows.first { $0.id == "fight" }?.value, "You 0 · Curse 0")
        let text = standing.rows.map { "\($0.label) \($0.value) \($0.line)" }.joined(separator: " ")
        XCTAssertFalse(text.lowercased().contains("glow"))
        XCTAssertFalse(ReaderSheetStanding.howItWorks.lowercased().contains("glow"))
    }

    func testTheLastThrowIsTheReadersOwn() {
        let log = [
            InkbonesThrowRecord(id: "a", at: now, thrower: .reader, roll: 23, target: 58, subject: "Q", outcome: "favor"),
            InkbonesThrowRecord(id: "b", at: now, thrower: .curse, roll: 91, target: 80, subject: "P", outcome: "took")
        ]
        let row = ReaderSheetStanding.inkbonesRow(log)
        XCTAssertEqual(row.value, "23")
        XCTAssertTrue(row.line.contains("58"))
        XCTAssertTrue(row.line.contains("favoured"))
    }

    // MARK: The Curse's file

    func testTheCursesFileWaitsUntilThereIsSomethingTrueToSay() {
        let empty = CurseDossier.build(.empty, calendar: calendar)
        XCTAssertFalse(empty.isReady)
        XCTAssertTrue(empty.findings.isEmpty)
        XCTAssertTrue(empty.waitingLine.contains("file on the Curse"))
    }

    func testTheCursesFileFindsItsTimeItsPlaceItsWeatherAndItsWords() throws {
        let dossier = CurseDossier.build(foggyAfternoons(), calendar: calendar)
        XCTAssertTrue(dossier.isReady)
        XCTAssertEqual(dossier.answered, 20)
        XCTAssertEqual(dossier.grey, 8)

        func finding(_ id: String) -> CurseDossier.Finding? { dossier.findings.first { $0.id == id } }
        XCTAssertEqual(finding("take")?.value, "40%")
        XCTAssertEqual(finding("day-part")?.value, "Afternoon")
        XCTAssertEqual(finding("place")?.value, "the kitchen")
        XCTAssertEqual(finding("weather")?.value, "Rain")
        let words = try XCTUnwrap(finding("words")?.value)
        XCTAssertTrue(words.contains("kitchen"), words)
        XCTAssertTrue(words.contains("scrolling"), words)
        XCTAssertEqual(finding("speed")?.value, "19 min slower")
        XCTAssertNotNil(finding("last-words"))
        // The library is where it never wins: never named as one of its places.
        XCTAssertFalse(dossier.findings.contains { $0.value == "the library" })
    }

    /// The Curse joined to the rest of the reader's life: after short nights
    /// it wins, after long ones it doesn't.
    func testTheCursesFileConnectsToTheNightBefore() {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-12 * 86_400))
        for day in 0..<10 {
            let at = start.addingTimeInterval(Double(day) * 86_400 + 11 * 3600)
            let shortNight = day.isMultiple(of: 2)
            let grey = shortNight && day != 0
            ledger.record(id: "k\(day)", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: grey ? .elsewhere : .here, cycle: 0,
                          context: context(at: at, sleep: shortNight ? 5 : 8.5))
        }
        let dossier = CurseDossier.build(ledger, calendar: calendar)
        XCTAssertEqual(dossier.findings.first { $0.id == "feeds-on" }?.value, "After a short night")
    }

    func testTheFileIsReadALittleEachDay() {
        let dossier = CurseDossier.build(foggyAfternoons(), calendar: calendar)
        let today = dossier.featured(on: now, count: 2, calendar: calendar)
        let tomorrow = dossier.featured(on: now.addingTimeInterval(86_400), count: 2, calendar: calendar)
        XCTAssertEqual(today.count, 2)
        XCTAssertFalse(today.contains { $0.id == "take" }, "the column prints its own counts")
        XCTAssertEqual(tomorrow.first, today.last, "the file turns one finding a day")
        XCTAssertTrue(today[0].printed.hasPrefix(today[0].label + ": "))
    }

    func testABucketIsOnlyNamedWhenTheCurseBeatsItsOwnAverageThere() {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-10 * 86_400))
        // Grey half the time, everywhere alike: nowhere stands out.
        for index in 0..<8 {
            let at = start.addingTimeInterval(Double(index) * 86_400 + 10 * 3600)
            ledger.record(id: "k\(index)", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: index.isMultiple(of: 2) ? .elsewhere : .here, cycle: 0,
                          context: context(at: at, place: "home"))
        }
        let dossier = CurseDossier.build(ledger, calendar: calendar)
        XCTAssertTrue(dossier.isReady)
        XCTAssertNil(dossier.findings.first { $0.id == "place" })
        XCTAssertNil(dossier.findings.first { $0.id == "day-part" })
    }
}
