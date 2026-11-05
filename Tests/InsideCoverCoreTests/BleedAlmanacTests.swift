import XCTest
@testable import InsideCoverCore

/// The paper's rotating number columns beyond the war, the odds and the market:
/// Serenity's cards, the Book's forecast and obituaries, who's where, the rumour
/// mill, the state of the Book's paper, the map's wanted posters, and how they
/// take turns for the seats.
final class BleedAlmanacTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func bookDay(_ date: Date, _ pages: [BookPage] = []) -> BookDay {
        BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: pages)
    }

    // MARK: Serenity reads the cards

    private func cards(at now: Date, ledger: WorldEventLifecycleLedger = .empty,
                       history: [BleedPrintRecord] = []) throws -> BleedColumnBrief? {
        let event = WorldEventRegistry.dictionaryRebellion
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: "dictionary-rebellion", event: event, now: now, ledger: ledger, calendar: calendar))
        var inputs = BookSourceInputs.empty
        inputs.worldEventLifecycle = ledger
        return BleedAlmanacDesk.serenityCards(event: event, snapshot: snapshot, inputs: inputs,
                                              now: now, calendar: calendar, history: history)
    }

    func testSerenityWarnsOfADoorAboutToShutAndCardsTheNextBeatWithoutSpoilingIt() throws {
        // Day five of the Rebellion: roll call's door shuts on day six, and the
        // negotiation opens on day seven.
        let now = date(2027, 9, 6, 10)
        let column = try XCTUnwrap(cards(at: now))
        let body = column.composedBody
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .oracle)
        XCTAssertTrue(body.contains("still face up"), body)
        XCTAssertTrue(body.contains("it's over tomorrow"), body)
        XCTAssertGreaterThanOrEqual(column.urgency ?? 0, BleedAlmanacDesk.urgent)
        XCTAssertNotNil(column.snapshot?["oracle:beat:first-negotiation"])
        // A card and an omen, never the beat itself.
        for beat in WorldEventRegistry.dictionaryRebellion.beats ?? [] {
            XCTAssertFalse(body.contains(beat.title), beat.title)
            XCTAssertFalse(body.contains(beat.body), beat.body)
        }
        // The card as the deck prints it: its own margin note, word for word.
        let next = try XCTUnwrap((WorldEventRegistry.dictionaryRebellion.beats ?? []).first { $0.id == "first-negotiation" })
        let drawn = try XCTUnwrap(BleedAlmanacDesk.card(for: next))
        let note = try XCTUnwrap(TarotDeck.marginalia(for: drawn.id)?.note)
        XCTAssertTrue(body.contains("a note beside it: “\(note)”"), body)
        // Serenity reads for the building, never the Reader's fortune.
        XCTAssertFalse(body.lowercased().contains("your future"), body)
    }

    /// Every month pack in the repository, as it ships. A new month is checked the
    /// day its pack lands: nothing about Serenity's column is written by hand.
    private func monthPacks() throws -> [WorldEventPack] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("ContentPacks")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .flatMap { (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
            .filter { $0.lastPathComponent.hasSuffix(".reenchantedevents.json") }
            .sorted { $0.path < $1.path }
        return try files.map { try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: Data(contentsOf: $0)) }
            .filter { !($0.authoringManifests ?? []).isEmpty }
    }

    func testEveryMonthGivesSerenityItsNextBigThingAndAGlimpseButNeverTheScene() throws {
        let packs = try monthPacks()
        XCTAssertGreaterThanOrEqual(packs.count, 2, "October and November at least")
        for pack in packs {
            let event = try XCTUnwrap(pack.events.first, pack.id)
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = pack.authoringManifests ?? []
            inputs.authoredStoryScenes = pack.storyScenes ?? []
            let liveStart = try XCTUnwrap(event.calendar.scheduledInterval(near: date(event.calendar.startYear ?? 2026, event.calendar.startMonth, 10), calendar: calendar)).start

            // Every big scene gives her something to see.
            let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: pack.id, event: event, now: liveStart.addingTimeInterval(3_600), calendar: calendar))
            for turn in BleedAlmanacDesk.turns(event: event, snapshot: snapshot, inputs: inputs, now: liveStart, calendar: calendar) where turn.isBig {
                XCTAssertFalse(BleedAlmanacDesk.glimpse(turn).isEmpty, "\(pack.id): \(turn.id) has no room, Cast or thing for Serenity to see")
            }

            // The foreshadow days already name the month's first big scene.
            let eve = liveStart.addingTimeInterval(-20 * 3_600)
            if let foreshadow = WorldEventResolver.lifecycleSnapshot(packID: pack.id, event: event, now: eve, calendar: calendar),
               foreshadow.stage == .foreshadow {
                let column = try XCTUnwrap(BleedAlmanacDesk.serenityCards(event: event, snapshot: foreshadow, inputs: inputs,
                                                                          now: eve, calendar: calendar, history: []), pack.id)
                XCTAssertTrue(column.composedBody.contains("THE MONTH TURNS · tomorrow"), column.composedBody)
                XCTAssertTrue(column.composedBody.contains("THE NEXT BIG THING · "), column.composedBody)
            }

            var weeksWithNews = Set<Int>()
            for day in 0..<(event.calendar.durationDays - 3) {
                let now = liveStart.addingTimeInterval(Double(day) * 86_400 + 7 * 3_600)
                guard let snapshot = WorldEventResolver.lifecycleSnapshot(packID: pack.id, event: event, now: now, calendar: calendar),
                      let column = BleedAlmanacDesk.serenityCards(event: event, snapshot: snapshot, inputs: inputs,
                                                                  now: now, calendar: calendar, history: []) else { continue }
                let body = column.composedBody
                if body.contains("THE NEXT BIG THING · ") { weeksWithNews.insert(day / 7) }
                // A glimpse is never the scene: no title, no opening sentence.
                for scene in pack.storyScenes ?? [] {
                    XCTAssertFalse(body.contains(scene.title), "\(pack.id) day \(day): \(scene.title)")
                    let firstSentence = WonderBraid.sentences(scene.opening).first ?? ""
                    if firstSentence.count > 30 { XCTAssertFalse(body.contains(firstSentence), "\(pack.id) day \(day): \(firstSentence)") }
                }
                // What she sees is a thing, never one turned to face the Reader.
                for line in body.components(separatedBy: "\n") {
                    guard let seen = line.range(of: "I see ") else { continue }
                    let glimpse = line[seen.upperBound...].prefix { $0 != "." }.lowercased()
                    XCTAssertFalse(glimpse.contains("your") || glimpse.contains(" you "), "\(pack.id) day \(day): \(glimpse)")
                }
                // A pulse heard early never speaks of Serenity in the third person.
                XCTAssertFalse(body.contains("“Serenity"), body)
            }
            XCTAssertGreaterThanOrEqual(weeksWithNews.count, 3, "\(pack.id): most weeks should have a next big thing to announce")
        }
    }

    func testACardNamesWhoOfTheCastIsPicturedOnIt() throws {
        let chariot = try XCTUnwrap(TarotDeck.card(id: "major-07"))
        let line = BleedAlmanacDesk.onTheCard(chariot)
        XCTAssertTrue(line.contains("Permancer"), line)
        XCTAssertTrue(line.contains("“Which way, then?”"), line)
    }

    func testTheNextPaperGradesTheCards() throws {
        let first = try XCTUnwrap(cards(at: date(2027, 9, 6, 10)))
        let printed = BleedPrintRecord(slotID: "earlier", printedAt: date(2027, 9, 6, 10), items: [
            .init(storyID: first.storyID!, revision: first.revision!, title: first.title, body: "", sourcePageIDs: [],
                  snapshot: first.snapshot)
        ])
        let later = try XCTUnwrap(cards(at: date(2027, 9, 9, 10), history: [printed]))
        XCTAssertTrue(later.composedBody.contains("and so did the thing it was for"), later.composedBody)
        XCTAssertTrue(later.composedBody.contains("1 for 1"), later.composedBody)
        XCTAssertEqual(later.snapshot?["oracle:tally"], "1")
    }

    // MARK: The Book's forecast and its obituaries

    /// Two months of days: rain on every third one, with the same small line kept.
    private func worked() -> (GrimoireLedger, [BookDay], Calendar) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let days = (0..<61).map { index -> BookDay in
            let date = utc.date(byAdding: .hour, value: 20, to: GrimoireDay.date(for: index, calendar: utc))!
            let rainy = index % 3 == 0
            return BookDay(id: BookDay.id(for: date, calendar: utc), date: utc.startOfDay(for: date), pages: [BookPage(
                id: "page-\(index)", type: .diary, createdAt: date, promptText: "p",
                userInput: rainy ? "The lantern outside was swinging in the wet." : "Bread, errands, the usual list.",
                origin: .userAuthored,
                context: BookPageContextSnapshot(at: date, calendar: utc, weatherTags: rainy ? ["rain"] : ["clear"]))])
        }
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(from: GrimoireSlice(days: days, calendar: utc)))
        let now = GrimoireDay.date(for: 62, calendar: utc)
        var passes = 0
        while !ledger.sweep(now: now, budget: 2_000, calendar: utc).finished, passes < 200 { passes += 1 }
        for row in ledger.rows.values where row.isAlive {
            ledger.markSpoken(row.id, now: now, calendar: utc)
            ledger.rows[row.id]?.state = .standing
        }
        return (ledger, days, utc)
    }

    func testTheBookBetsOnTheRainAndSettlesTheBetNextPaper() throws {
        let (ledger, days, utc) = worked()
        var inputs = BookSourceInputs.empty
        inputs.grimoire = ledger
        inputs.days = days
        inputs.weather = WeatherSourceSignal(phrase: "Current: Rain, 52F", source: "test")
        let now = utc.date(byAdding: .hour, value: 7, to: GrimoireDay.date(for: 62, calendar: utc))!
        let today = BookDay(id: BookDay.id(for: now, calendar: utc), date: utc.startOfDay(for: now), pages: [])
        let forecast = try XCTUnwrap(BleedAlmanacDesk.forecast(kind: .morning, day: today, inputs: inputs, now: now,
                                                               calendar: utc, history: []))
        XCTAssertTrue(forecast.composedBody.hasPrefix("Rain today."), forecast.composedBody)
        XCTAssertTrue(forecast.composedBody.contains("I'm betting on it."), forecast.composedBody)
        let bet = try XCTUnwrap(forecast.snapshot?.first { $0.key.hasPrefix("forecast:") })
        XCTAssertEqual(BleedPrintDesign.piece(title: forecast.title, byline: forecast.byline), .ledger)

        // The day goes by with nothing kept: the next paper says so.
        let history = [BleedPrintRecord(slotID: "morning", printedAt: now, items: [
            .init(storyID: forecast.storyID!, revision: "x", title: forecast.title, body: "", sourcePageIDs: [],
                  snapshot: [bet.key: bet.value])
        ])]
        let tomorrow = now.addingTimeInterval(86_400)
        inputs.weather = nil
        let settled = try XCTUnwrap(BleedAlmanacDesk.forecast(
            kind: .evening, day: BookDay(id: BookDay.id(for: tomorrow, calendar: utc), date: utc.startOfDay(for: tomorrow), pages: []),
            inputs: inputs, now: tomorrow, calendar: utc, history: history))
        XCTAssertTrue(settled.composedBody.contains("and it didn't. I'm writing that down too."), settled.composedBody)
    }

    func testACrossedOutBeliefGetsOneObituary() throws {
        var (ledger, _, utc) = worked()
        let now = GrimoireDay.date(for: 63, calendar: utc)
        let row = try XCTUnwrap(ledger.rows.values.sorted { $0.id < $1.id }.first {
            $0.shape == .conditional && ledger.ref($0.conditionID)?.sensitivity == .ordinary
                && $0.outcomeID.flatMap { ledger.ref($0)?.sensitivity } == .ordinary
        })
        ledger.rows[row.id]?.state = .crossedOut
        ledger.rows[row.id]?.revisions.append(GrimoireRevision(at: now.addingTimeInterval(-3_600), from: .standing,
                                                               to: .crossedOut, because: "the counts stopped holding it up"))
        var inputs = BookSourceInputs.empty
        inputs.grimoire = ledger
        let obituary = try XCTUnwrap(BleedAlmanacDesk.obituaries(inputs: inputs, now: now, calendar: utc, history: []))
        XCTAssertTrue(obituary.composedBody.contains("Died "), obituary.composedBody)
        XCTAssertTrue(obituary.composedBody.contains("Cause of death: the counts stopped holding it up."), obituary.composedBody)
        XCTAssertTrue(obituary.composedBody.contains("still standing"), obituary.composedBody)
        let printed = BleedPrintRecord(slotID: "s", printedAt: now, items: [
            .init(storyID: obituary.storyID!, revision: "x", title: "Obituaries", body: "", sourcePageIDs: [], snapshot: obituary.snapshot)
        ])
        XCTAssertNil(BleedAlmanacDesk.obituaries(inputs: inputs, now: now, calendar: utc, history: [printed]))
    }

    // MARK: The Academy's comings and goings

    func testWhereIsWhoNamesRoomsNotIDs() throws {
        let column = try XCTUnwrap(BleedAlmanacDesk.whereabouts(kind: .morning, now: date(2026, 10, 20, 7), calendar: calendar))
        let rows = column.composedBody.components(separatedBy: "\n").filter { $0.contains(" · ") }
        XCTAssertGreaterThanOrEqual(rows.count, 3, column.composedBody)
        XCTAssertFalse(column.composedBody.contains("location-"), column.composedBody)
        XCTAssertNil(column.composedBody.range(of: #"Wing \d+:"#, options: .regularExpression), column.composedBody)
        // A different paper, a different four.
        let evening = try XCTUnwrap(BleedAlmanacDesk.whereabouts(kind: .evening, now: date(2026, 10, 20, 18), calendar: calendar))
        XCTAssertNotEqual(rows, evening.composedBody.components(separatedBy: "\n").filter { $0.contains(" · ") })
    }

    func testTheRumourMillTracesTheRouteNotTheRumour() throws {
        let now = date(2026, 10, 20, 7)
        func memory(_ who: String, from: String?, fromName: String?, hours: Double) -> CastStoryMemory {
            CastStoryMemory(id: "run|bread|\(who)", entityID: who, key: "bread", memory: "The bigger half of the loaf.",
                            aside: nil, witness: from == nil ? .lived : .heard, storyTitle: "The Count Unbound", momentTitle: "Lunch",
                            runID: "run", sourceID: "test", happenedAt: now.addingTimeInterval(-30 * 3600),
                            frozenAt: now.addingTimeInterval(-hours * 3600), gossip: "A secret about bread.",
                            heardFromID: from, heardFromName: fromName)
        }
        var inputs = BookSourceInputs.empty
        inputs.castStoryMemories = CastStoryMemoryLedger(memories: [
            memory("pippa-pilcrow", from: nil, fromName: nil, hours: 20),
            memory("zara-finch", from: "pippa-pilcrow", fromName: "Pippa", hours: 10),
            memory("wicker", from: "zara-finch", fromName: "Zara", hours: 5)
        ])
        let column = try XCTUnwrap(BleedAlmanacDesk.rumourMill(inputs: inputs, now: now, calendar: calendar))
        XCTAssertTrue(column.composedBody.contains("LUNCH · Three know. Pippa told "), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Zara told "), column.composedBody)
        XCTAssertFalse(column.composedBody.contains("secret about bread"), column.composedBody)
        XCTAssertFalse(column.composedBody.contains("bigger half"), column.composedBody)
    }

    func testTheStateOfThePaperSpeaksInPaperNotCounts() throws {
        var wear = ReaderWearLedger()
        let now = date(2026, 10, 20, 7)
        for back in 1...7 { wear.opened(.labyrinthMap, at: now.addingTimeInterval(-Double(back) * 86_400), calendar: calendar) }
        for back in 1...3 { wear.opened(.almanac, at: now.addingTimeInterval(-Double(back) * 86_400), calendar: calendar) }
        var inputs = BookSourceInputs.empty
        inputs.readerWear = wear
        let column = try XCTUnwrap(BleedAlmanacDesk.wear(inputs: inputs, now: now, calendar: calendar))
        XCTAssertTrue(column.composedBody.contains("FALLS OPEN AT · the Book's map of the Labyrinth"), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("THUMBED · "), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("STILL UNCUT · "), column.composedBody)
        XCTAssertNil(column.composedBody.range(of: #"\d"#, options: .regularExpression), "wear is paper, not a count")
    }

    func testTheMapPostsOnlyAnErrandTheReaderTookOn() throws {
        let now = date(2026, 10, 20, 7)
        XCTAssertNil(BleedAlmanacDesk.wanted(day: bookDay(now), inputs: .empty, now: now))
        let kept = BookPage(id: "errand", type: .bookNotices, createdAt: now.addingTimeInterval(-2 * 86_400),
                            promptText: "Water", userInput: "", tags: ["gazetteer-errand:water", "gazetteer-edge:900"])
        var inputs = BookSourceInputs.empty
        inputs.days = [bookDay(kept.createdAt, [kept])]
        let wanted = try XCTUnwrap(BleedAlmanacDesk.wanted(day: bookDay(now), inputs: inputs, now: now))
        XCTAssertTrue(wanted.composedBody.hasPrefix("WANTED: anywhere beside water."), wanted.composedBody)
        XCTAssertTrue(wanted.composedBody.contains("No deadline."), wanted.composedBody)
        XCTAssertNil(wanted.composedBody.range(of: #"\d+\s*(km|mile|metre|meter)"#, options: .regularExpression))
        let went = BookPage(id: "went", type: .bookNotices, createdAt: now.addingTimeInterval(-3_600),
                            promptText: "Water", userInput: "", tags: ["gazetteer-went:water"])
        inputs.days.append(bookDay(went.createdAt, [went]))
        let found = try XCTUnwrap(BleedAlmanacDesk.wanted(day: bookDay(now), inputs: inputs, now: now))
        XCTAssertEqual(found.title, "Found")
        XCTAssertEqual(found.urgency, BleedAlmanacDesk.urgent)
    }

    // MARK: Taking turns

    private func column(_ id: String, urgency: Int? = nil) -> BleedColumnBrief {
        var brief = BleedAlmanacDesk.brief(id, id, "the Academy, by the hour", ["A · B"])
        brief.urgency = urgency
        return brief
    }

    func testTwoNumberSeatsAPaperAThirdForOneThatCantWaitAndRecentOnesStandBack() {
        let pool = [column(BleedAlmanacDesk.cardsID), column(BleedAlmanacDesk.forecastID),
                    column(BleedAlmanacDesk.whereaboutsID), column(BleedAlmanacDesk.rumourID)]
        let data = { (picked: [BleedColumnBrief]) in picked.filter { BleedIssueCurator.desk($0) == .data }.map(\.id) }
        XCTAssertEqual(data(BleedIssueCurator.select(from: pool, kind: .morning, history: [])).count, 2)

        let urgent = pool + [column(BleedAlmanacDesk.wantedID, urgency: BleedAlmanacDesk.urgent)]
        let picked = data(BleedIssueCurator.select(from: urgent, kind: .morning, history: []))
        XCTAssertEqual(picked.count, 3)
        XCTAssertEqual(picked.first, BleedAlmanacDesk.wantedID)

        let ran = BleedPrintRecord(slotID: "last", printedAt: Date(), items: [
            .init(storyID: BleedAlmanacDesk.cardsID, revision: "x", title: "", body: "", sourcePageIDs: []),
            .init(storyID: BleedAlmanacDesk.forecastID, revision: "x", title: "", body: "", sourcePageIDs: [])
        ])
        XCTAssertEqual(Set(data(BleedIssueCurator.select(from: pool, kind: .morning, history: [ran]))),
                       [BleedAlmanacDesk.whereaboutsID, BleedAlmanacDesk.rumourID])
    }

    func testANumberColumnSitsOutThePaperAfterItRunsUnlessItHasNews() {
        func ran(_ id: String, hoursAgo: Double) -> BleedPrintRecord {
            BleedPrintRecord(slotID: "slot-\(hoursAgo)", printedAt: Date().addingTimeInterval(-hoursAgo * 3_600), items: [
                .init(storyID: id, revision: "x", title: "", body: "", sourcePageIDs: [])
            ])
        }
        let data = { (picked: [BleedColumnBrief]) in Set(picked.filter { BleedIssueCurator.desk($0) == .data }.map(\.id)) }
        let cards = BleedAlmanacDesk.cardsID, forecast = BleedAlmanacDesk.forecastID
        // Even with a seat free, last paper's column sits this one out.
        XCTAssertEqual(data(BleedIssueCurator.select(from: [column(cards), column(forecast)], kind: .morning,
                                                     history: [ran(cards, hoursAgo: 12)])), [forecast])
        // Two papers ago: back only with news.
        let twoAgo = [ran(forecast, hoursAgo: 12), ran(cards, hoursAgo: 24)]
        XCTAssertEqual(data(BleedIssueCurator.select(from: [column(cards)], kind: .morning, history: twoAgo)), [])
        XCTAssertEqual(data(BleedIssueCurator.select(from: [column(cards, urgency: BleedAlmanacDesk.news)], kind: .morning,
                                                     history: twoAgo)), [cards])
        // A door about to shut can't wait at all.
        XCTAssertEqual(data(BleedIssueCurator.select(from: [column(cards, urgency: BleedAlmanacDesk.urgent)], kind: .morning,
                                                     history: [ran(cards, hoursAgo: 12)])), [cards])
    }

    // MARK: The standings

    func testCastBeliefStandingsMoveAndTheTipsSettle() throws {
        let cast = NarrativePackRegistry.entities.filter { $0.kind == .character }.sorted { $0.id < $1.id }
        let riser = try XCTUnwrap(cast.first)
        var inputs = BookSourceInputs.empty
        let first = try XCTUnwrap(BleedAlmanacDesk.castBelief(inputs: inputs, history: []))
        XCTAssertTrue(first.composedBody.hasPrefix("RANK · BELIEF\n1. "), first.composedBody)
        XCTAssertEqual(first.composedBody.components(separatedBy: "\n").filter { $0.first?.isNumber == true }.count, 7)
        XCTAssertTrue(first.composedBody.contains("TIPS FOR THE NEXT PAPER"), first.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: first.title, byline: first.byline), .ledger)

        // Tipped to rise, and it rose: the next paper pays out.
        var snapshot = first.snapshot ?? [:]
        snapshot = snapshot.filter { !$0.key.hasPrefix("belief:tip:") }
        snapshot["belief:tip:\(riser.id)"] = "rise"
        let printed = BleedPrintRecord(slotID: "last", printedAt: Date(), items: [
            .init(storyID: first.storyID!, revision: "x", title: "", body: "", sourcePageIDs: [], snapshot: snapshot)
        ])
        inputs.entityBeliefOffsets = [riser.id: 100]
        let next = try XCTUnwrap(BleedAlmanacDesk.castBelief(inputs: inputs, history: [printed]))
        let name = BleedDayDesk.castName(riser.id)
        XCTAssertTrue(next.composedBody.contains("1. \(name) · 100\u{00A0}▲"), next.composedBody)
        XCTAssertTrue(next.composedBody.contains("tipped \(name) to rise. \(name) rose. Paid."), next.composedBody)
        XCTAssertEqual(next.urgency, BleedAlmanacDesk.news)
    }

    func testThePageExchangeReadsTheCuratorsOwnBook() throws {
        var learning = ReaderLearningModel()
        for (type, kept) in [(BookPageType.souvenir, 6), (.diary, 4), (.mood, 3), (.body, 2)] {
            var affinity = ReaderLearningAffinity()
            affinity.surfaced = kept + 2
            affinity.kept = kept
            affinity.loved = kept / 2
            learning.typeAffinities[type] = affinity
        }
        var inputs = BookSourceInputs.empty
        inputs.readerLearning = learning
        let column = try XCTUnwrap(BleedAlmanacDesk.pageExchange(inputs: inputs, now: Date(), history: []))
        XCTAssertTrue(column.composedBody.contains("1. \(BookPageType.souvenir.title) · "), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Most kept of all: \(BookPageType.souvenir.title)."), column.composedBody)
        XCTAssertFalse(column.composedBody.lowercased().contains("dismiss"), column.composedBody)
        // Too little learned yet: no exchange.
        inputs.readerLearning = ReaderLearningModel()
        XCTAssertNil(BleedAlmanacDesk.pageExchange(inputs: inputs, now: Date(), history: []))
    }

    func testAHardDayPrintsNoAlmanac() {
        let now = date(2026, 10, 20, 7)
        var hard = bookDay(now.addingTimeInterval(-86_400), [BookPage(
            id: "hard", type: .diary, createdAt: now.addingTimeInterval(-80_000), promptText: "Diary",
            userInput: "An honest line.", tags: ["distress"])])
        hard.pages.append(BookPage(id: "errand", type: .bookNotices, createdAt: now.addingTimeInterval(-80_000),
                                   promptText: "Water", userInput: "", tags: ["gazetteer-errand:water"]))
        var inputs = BookSourceInputs.empty
        inputs.days = [hard]
        let briefs = BleedNewsroom.briefs(kind: .morning, day: bookDay(now), inputs: inputs, interest: nil,
                                          now: now, calendar: calendar, authored: [])
        XCTAssertFalse(briefs.contains { BleedAlmanacDesk.ids.contains($0.id) })
    }
}
