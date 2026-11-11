import XCTest
@testable import InsideCoverCore

/// The reader's acts that lived in other ledgers and fed nothing: where a Knock
/// found them, which station they put on, which rooms they went into, the
/// Inkbones, Grey Pages, electives and places named. Each test starts from the
/// raw records and goes through the real projection and sweep, because a test
/// that hand-builds a ledger proves the engine, not the wiring.
final class GrimoireReaderActsTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func at(_ index: Int, hour: Int = 10) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: GrimoireDay.date(for: index, calendar: calendar))!
    }

    private func day(_ index: Int, weather: [String] = []) -> BookDay {
        let date = at(index)
        let page = BookPage(
            id: "p\(index)", type: .diary, createdAt: date,
            promptText: "Prompt", userInput: "Walked the long way past the allotments.",
            tags: [], origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: weather)
        )
        return BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: [page])
    }

    private func swept(_ slice: GrimoireSlice) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(from: slice))
        var passes = 0
        while true {
            let report = ledger.sweep(now: at(70), budget: 900, calendar: calendar)
            passes += 1
            if report.finished || passes > 80 { break }
        }
        return ledger
    }

    private func row(_ ledger: GrimoireLedger, _ condition: String, _ outcome: String) -> GrimoireCorrespondence? {
        ledger.row(GrimoireCorrespondence.key(shape: .conditional, condition: condition, outcome: outcome))
    }

    func testTheKnocksLearnTheCursesHaunts() throws {
        // Work afternoons find the reader somewhere grey; the harbour doesn't.
        let knocks = (0..<40).map { index -> AttentionProbeReceipt in
            let atWork = index % 2 == 0
            let grey = atWork ? index % 10 != 0 : index % 9 == 1
            let date = at(index, hour: 15)
            return AttentionProbeReceipt(
                id: "k\(index)", scheduledAt: date, answeredAt: date,
                answer: grey ? .elsewhere : .here, cycle: 0,
                context: BookPageContextSnapshot(at: date, calendar: calendar, locationLabel: atWork ? "Work" : "Harbour")
            )
        }
        let ledger = swept(GrimoireSlice(days: [], knocks: knocks, calendar: calendar))
        let haunt = try XCTUnwrap(row(ledger, "place:work", "knock:grey"), "the Knocks never found where the grey lives")
        let stats = try XCTUnwrap(ledger.currentStats(for: haunt, calendar: calendar))
        XCTAssertGreaterThan(stats.inRate, stats.outRate)
        XCTAssertTrue(ledger.speakable(limit: .max, now: at(70), calendar: calendar).contains { $0.id == haunt.id })
    }

    func testTheRadioStationTheReaderPutsOnCanBeARule() {
        let days = (0..<60).map { index in day(index, weather: index % 3 == 0 ? ["rain"] : ["clear"]) }
        let rainy = Set(days.enumerated().filter { $0.offset % 3 == 0 && $0.offset != 30 }.map(\.element.id))
        let ledger = swept(GrimoireSlice(
            days: days,
            radioDays: [RadioListeningDays(stationID: "thornwave", title: "Thornwave", dayIDs: rainy)],
            calendar: calendar
        ))
        XCTAssertNotNil(row(ledger, "weather:rain", "radio:thornwave"), "rain never reached the radio dial")
    }

    func testTheRoomsTheReaderWandersIntoCanBeARule() {
        let days = (0..<60).map { index in day(index, weather: index % 4 == 0 ? ["fog"] : ["clear"]) }
        var wear = ReaderWearLedger()
        for index in stride(from: 0, to: 60, by: 4) where index != 28 {
            wear.opened(.atlas, at: at(index, hour: 20), calendar: calendar)
        }
        // Sent there by the Book: leaves no wear, so it can't be evidence.
        wear.opened(.atlas, arrival: .sent, at: at(1), calendar: calendar)
        let ledger = swept(GrimoireSlice(days: days, wear: wear, calendar: calendar))
        XCTAssertNotNil(row(ledger, "weather:fog", "wander:atlas"), "fog never sent the reader to the Atlas")
    }

    func testAnswersToTheBooksOwnAsksAreMarkedAsked() {
        let index = 5
        let date = at(index)
        let slice = GrimoireSlice(
            days: [day(index)],
            greyPages: [GreyPageThreat(
                id: "g", pageID: "p5", pageTitle: "t", pageExcerpt: "e", markedAt: at(index - 2),
                deadline: nil, status: .rescued, resolvedAt: date, rescueLine: nil
            )],
            electives: [UnwrittenElective(
                id: "e", characterID: "wicker", characterName: "Wicker", title: "t", ask: "a",
                whyItMatters: "w", practiceShape: "p", createdAt: at(index - 3), completedAt: date
            )],
            calendar: calendar
        )
        let observations = GrimoireProjection.observations(from: slice)
        let rescue = observations.first { $0.features.contains { $0.id == "grey-rescue:taken-back" } }
        let elective = observations.first { $0.features.contains { $0.id == "elective:wicker" } }
        XCTAssertEqual(rescue?.bookAsked, true, "taking back a Page the Curse marked was answering the mark")
        XCTAssertEqual(elective?.bookAsked, true, "an elective is a Cast member's ask")
    }

    func testOnlyTheReadersOwnThrowIsAnAct() {
        let date = at(3)
        let slice = GrimoireSlice(
            days: [day(3)],
            inkbones: [InkbonesThrowRecord(id: "c", at: date, thrower: .curse, roll: 2, target: 7, subject: "s", outcome: "took")],
            calendar: calendar
        )
        let features = GrimoireProjection.observations(from: slice).flatMap(\.features)
        let curse = features.first { $0.id == "curse-throw:any" }
        XCTAssertEqual(curse?.role, .conditionOnly, "the Curse's throw happens to the reader")
        XCTAssertFalse(features.contains { $0.id == "inkbones:thrown" })
    }

    func testOnlyNamedPlacesCountAsPlaceMaking() {
        let today = day(4)
        func anchor(_ id: String) -> AnchorRecord {
            AnchorRecord(
                id: id, name: "the quiet end", latitude: 0, longitude: 0, radiusMeters: 50,
                kind: .notice, belief: 1, created: today.id, weather: "", moon: "", season: "",
                playerWords: "", academyEcho: "", outerStacksRoom: "", fae: "", miniStory: "",
                localRule: "", visitCount: 1, lastVisited: today.id
            )
        }
        let slice = GrimoireSlice(days: [today], namedPlaces: [anchor("user-anchor-the-quiet-end-1a2b3c4d")], calendar: calendar)
        XCTAssertTrue(GrimoireProjection.observations(from: slice).flatMap(\.features).contains { $0.id == "place-made:new" })
    }
}
