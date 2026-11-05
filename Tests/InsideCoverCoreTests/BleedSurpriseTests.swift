import XCTest
@testable import InsideCoverCore

/// The paper's surprise columns: new rooms on the map, sightings, the sky, the
/// Chapters' weather, the margins, the paper's own corrections, the archive, the
/// pirate signal, and the Cast's errands posted as situations vacant.
final class BleedSurpriseTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 9, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func bookDay(_ date: Date, _ pages: [BookPage] = []) -> BookDay {
        BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: pages)
    }

    private func printed(_ at: Date, _ items: [BleedPrintRecord.Item] = []) -> BleedPrintRecord {
        BleedPrintRecord(slotID: "slot-\(at.timeIntervalSince1970)", printedAt: at, items: items)
    }

    func testTheMapReportsRoomsPushedInAndDoorsShutSinceTheLastPaper() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let pack = try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: Data(contentsOf:
            root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
        let event = try XCTUnwrap(pack.events.first)
        let interval = try XCTUnwrap(event.calendar.scheduledInterval(near: date(10, 15), calendar: calendar))
        func at(_ progress: Double) -> Date { interval.start.addingTimeInterval(progress * interval.duration) }
        func column(now: Date, lastPaper: Date) -> BleedColumnBrief? {
            BleedAlmanacDesk.newOnTheMap(day: bookDay(now), inputs: .empty, now: now, calendar: calendar,
                                         history: [printed(lastPaper)], events: [event])
        }
        // The phase that shuts the East Stacks.
        let shut = try XCTUnwrap(column(now: at(0.24), lastPaper: at(0.21)))
        XCTAssertTrue(shut.composedBody.contains("SHUT · the East Stacks"), shut.composedBody)
        // The phase that pushes in rooms from other books.
        let pushed = try XCTUnwrap(column(now: at(0.69), lastPaper: at(0.66)))
        XCTAssertTrue(pushed.composedBody.contains("NEW ON THE MAP · the Wrong Castle")
                      || pushed.composedBody.contains("NEW ON THE MAP · the Borrowed Ballroom"), pushed.composedBody)
        // Nothing moved between papers: no column.
        XCTAssertNil(column(now: at(0.5), lastPaper: at(0.45)))
    }

    func testANewPlaceOpensADoorInTheOuterStacksOnce() throws {
        let now = date(10, 20, 7)
        let anchor = AnchorRecord(id: "canal", name: "the canal bench", latitude: 0, longitude: 0, radiusMeters: 50,
                                  kind: .notice, belief: 1, created: "2026-10-19", weather: "", moon: "", season: "",
                                  playerWords: "", academyEcho: "", outerStacksRoom: "The Heron Annex", fae: "", miniStory: "", localRule: "", visitCount: 1, lastVisited: "2026-10-19")
        var inputs = BookSourceInputs.empty
        inputs.anchors = [anchor]
        let column = try XCTUnwrap(BleedAlmanacDesk.newOnTheMap(day: bookDay(now), inputs: inputs, now: now, calendar: calendar,
                                                                history: [printed(now.addingTimeInterval(-12 * 3_600))], events: []))
        XCTAssertTrue(column.composedBody.contains("NEW IN THE OUTER STACKS · a door to the canal bench\nThe Heron Annex."), column.composedBody)
        XCTAssertNil(column.composedBody.range(of: #"\d+\s*(km|mile|metre|meter)"#, options: .regularExpression))
        let ran = printed(now.addingTimeInterval(-3_600), [.init(storyID: BleedAlmanacDesk.mapID, revision: "x", title: "", body: "",
                                                                 sourcePageIDs: [], snapshot: column.snapshot)])
        XCTAssertNil(BleedAlmanacDesk.newOnTheMap(day: bookDay(now), inputs: inputs, now: now, calendar: calendar,
                                                  history: [ran], events: []))
    }

    func testSightingsCountTheWeeksCreaturesAndMarkTheNewOnes() throws {
        let now = date(10, 20, 7)
        func photo(_ id: String, _ creature: String, daysAgo: Double) -> BookPage {
            var page = BookPage(id: id, type: .illuminatedPhoto, createdAt: now.addingTimeInterval(-daysAgo * 86_400),
                                promptText: "Photo", userInput: "")
            page.creatureSightings = [CreatureSighting(creature: creature, certainty: .clear)]
            return page
        }
        var inputs = BookSourceInputs.empty
        let pages = [photo("a", "heron", daysAgo: 1), photo("b", "heron", daysAgo: 2), photo("c", "moth", daysAgo: 3),
                     photo("d", "moth", daysAgo: 40)]
        inputs.days = pages.map { bookDay($0.createdAt, [$0]) }
        let column = try XCTUnwrap(BleedAlmanacDesk.sightings(day: bookDay(now), inputs: inputs, now: now, calendar: calendar))
        XCTAssertTrue(column.composedBody.contains("Heron · 2, new to the Bestiary"), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Moth · 1\n") || column.composedBody.hasSuffix("Moth · 1"), column.composedBody)
    }

    func testTheSkyWatchSpeaksOnlyWhenTheSkyIsWorthIt() throws {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(phrase: "Clear", source: "test")
        XCTAssertNil(BleedAlmanacDesk.skyWatch(kind: .morning, inputs: inputs))
        inputs.weather?.kpIndex = 6
        let column = try XCTUnwrap(BleedAlmanacDesk.skyWatch(kind: .morning, inputs: inputs))
        XCTAssertTrue(column.composedBody.hasPrefix("AURORA · possible tonight"), column.composedBody)
        XCTAssertEqual(column.urgency, BleedAlmanacDesk.urgent)
    }

    func testTheChaptersGetHoroscopesAndTheReadersChapterIsMarked() throws {
        let chapters = AcademyChapterRegistry.chapters.filter { !$0.isHidden }
        let mine = try XCTUnwrap(chapters.first)
        var war = PactWarState()
        war.adjust(mine.talismanID, "shelf-care", by: 40)
        var inputs = BookSourceInputs.empty
        inputs.pactWar = war
        inputs.selfFacts = [SelfFact(id: "bound", questionID: "chapter-binding", question: "Chapter?", answer: mine.name,
                                     bookTranslation: mine.name, sensitivity: .identity, usePermission: .quoteAllowed,
                                     tags: [], createdAt: Date(), updatedAt: Date())]
        let column = try XCTUnwrap(BleedAlmanacDesk.chapterWeather(inputs: inputs, history: []))
        XCTAssertTrue(column.composedBody.contains("\(mine.name) ★ · "), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Holding the Care Shelf."), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("never the people in them"), column.composedBody)
    }

    func testThePixieIsSeenWhereTheReaderLastWandered() throws {
        let now = date(10, 20, 21)
        var wear = ReaderWearLedger()
        wear.opened(.labyrinthMap, at: now.addingTimeInterval(-3_600), calendar: calendar)
        var inputs = BookSourceInputs.empty
        inputs.readerWear = wear
        let column = try XCTUnwrap(BleedAlmanacDesk.overheard(inputs: inputs, now: now, calendar: calendar, history: []))
        XCTAssertTrue(column.composedBody.contains("seen over the Book's map of the Labyrinth at"), column.composedBody)
    }

    func testThePaperCorrectsTheOddsItGotWrong() throws {
        let now = date(10, 16, 7)
        let stages = (0..<5).map { CastUndertakingStage(id: "s\($0)", line: "Step \($0).", trace: "", tags: []) }
        let zara = CastUndertaking(id: "zara-maps", actorID: "zara", title: "The Lost Map", pursuit: "Find it", why: "Because",
                                   stages: stages, stageIndex: 1, status: .active, startedAt: date(10, 1),
                                   lastAdvancedAt: date(10, 10), nextEligibleAt: now.addingTimeInterval(86_400), ladderID: "test")
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [zara]
        let lost = Int(date(10, 15, 23).timeIntervalSince1970)
        let history = [printed(date(10, 15, 18), [.init(storyID: BleedDataDesk.oddsID, revision: "x", title: "", body: "",
                                                         sourcePageIDs: [], snapshot: ["odds:u:zara-maps": "1|3|1|\(lost)"])])]
        let column = try XCTUnwrap(BleedAlmanacDesk.corrections(kind: .morning, day: bookDay(now), inputs: inputs, now: now,
                                                                calendar: calendar, history: history))
        XCTAssertTrue(column.composedBody.contains("3–1 on the next step. This was optimistic. The paper regrets its optimism."),
                      column.composedBody)
    }

    func testTheArchivesReprintAYearAgoTodayOnceAndNeverAHardDay() throws {
        let now = date(10, 20, 7)
        let then = date(10, 20, 10, year: 2025)
        let line = "The kettle sang before it boiled and the cat left the room."
        let old = BookPage(id: "old", type: .souvenir, createdAt: then, promptText: "One true sentence", userInput: line)
        var inputs = BookSourceInputs.empty
        inputs.days = [bookDay(then, [old])]
        inputs.selfFacts = [SelfFact(id: "name", questionID: "onboarding-name", question: "Your name?", answer: "Wren",
                                     bookTranslation: "Wren", sensitivity: .identity, usePermission: .quoteAllowed,
                                     tags: ["name"], createdAt: then, updatedAt: then)]
        let column = try XCTUnwrap(BleedAlmanacDesk.fromOurArchives(day: bookDay(now), inputs: inputs, now: now, calendar: calendar, history: []))
        XCTAssertTrue(column.composedBody.hasPrefix("“\(line)”\n— Wren, one year ago today"), column.composedBody)
        XCTAssertEqual(column.sourcePageIDs, ["old"])
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .readerLetter)
        let ran = printed(now.addingTimeInterval(-3_600), [.init(storyID: "from-our-archives", revision: "x", title: "",
                                                                 body: "", sourcePageIDs: ["old"])])
        XCTAssertNil(BleedAlmanacDesk.fromOurArchives(day: bookDay(now), inputs: inputs, now: now, calendar: calendar, history: [ran]))
        inputs.days = [bookDay(then, [old, BookPage(id: "hard", type: .diary, createdAt: then, promptText: "Diary",
                                                    userInput: "An honest line.", tags: ["distress"])])]
        XCTAssertNil(BleedAlmanacDesk.fromOurArchives(day: bookDay(now), inputs: inputs, now: now, calendar: calendar, history: []))
    }

    func testThePirateSignalReachesOnlyAMarginWalkerAndRarely() throws {
        let now = date(10, 20, 21)
        var inputs = BookSourceInputs.empty
        XCTAssertNil(BleedAlmanacDesk.intercept(inputs: inputs, now: now, calendar: calendar, history: []))
        var wear = ReaderWearLedger()
        let rooms = BookRoom.allCases.filter(\.isGathering)
        for back in 0..<16 {
            for room in rooms.prefix(back < 8 ? 7 : 3) {
                wear.opened(room, at: now.addingTimeInterval(-Double(back) * 86_400 - 3_600), calendar: calendar)
            }
        }
        XCTAssertTrue(wear.isMarginWalker(now: now, calendar: calendar))
        inputs.readerWear = wear
        let column = try XCTUnwrap(BleedAlmanacDesk.intercept(inputs: inputs, now: now, calendar: calendar, history: []))
        XCTAssertTrue(column.composedBody.hasPrefix("…"), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("▒▒▒"), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("[signal lost at 97.3]"), column.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .intercept)
        let heard = printed(now.addingTimeInterval(-24 * 3_600), [.init(storyID: BleedAlmanacDesk.staticID, revision: "x", title: "",
                                                                        body: "", sourcePageIDs: [], snapshot: column.snapshot)])
        XCTAssertNil(BleedAlmanacDesk.intercept(inputs: inputs, now: now, calendar: calendar, history: [heard]))
    }

    func testAnOpenErrandIsPostedInTheMorningClassifieds() throws {
        let ladder = try XCTUnwrap(CastUndertakingRegistry.coreLadders.first { $0.stages.contains { $0.door != nil } })
        let index = try XCTUnwrap(ladder.stages.firstIndex { $0.door != nil })
        let door = try XCTUnwrap(ladder.stages[index].door)
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [CastUndertaking(
            id: "u", actorID: ladder.actorID, title: ladder.title, pursuit: ladder.pursuit, why: ladder.why,
            stages: ladder.stages, stageIndex: index, status: .active, startedAt: date(10, 1), lastAdvancedAt: date(10, 10),
            nextEligibleAt: date(10, 30), ladderID: ladder.id)]
        inputs.undertakingSerial.rememberedStoryBeats = [UndertakingSerial.storyBeatKey(actorID: ladder.actorID, stageID: ladder.stages[index].id)]
        let column = try XCTUnwrap(BleedDayDesk.castClassified(kind: .morning, now: date(10, 20, 7), calendar: calendar,
                                                               history: [], inputs: inputs))
        XCTAssertTrue(column.composedBody.contains("SITUATIONS VACANT\nWANTED: \(door.title)."), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Apply to \(BleedDayDesk.castName(ladder.actorID))."), column.composedBody)
        // The evening answers the morning's ad; it posts no jobs.
        let evening = BleedDayDesk.castClassified(kind: .evening, now: date(10, 20, 18), calendar: calendar, history: [], inputs: inputs)
        XCTAssertFalse(evening?.composedBody.contains("SITUATIONS VACANT") ?? false)
    }
}
