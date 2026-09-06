import XCTest
@testable import InsideCoverCore

/// A projector that exists only in this file.
///
/// It is the proof of the whole extension point: nothing in the ledger, the
/// sweep, the scoring or the voice knows tea exists, and none of them had to
/// change for the Book to start noticing it.
private enum TeaProjector: LoomProjector {
    static let id = "tea"
    static let domains = ["drink"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        guard index % 4 == 0 else { return [] }
        return [LoomFeatureRef(
            id: "drink:tea", domain: "drink", label: "tea",
            conditionClause: "there had been tea",
            outcomeClause: "you made tea",
            symbolName: "cup.and.saucer", role: .either,
            provenance: .observedContext, rank: 26
        )]
    }
}

final class LoomProjectorTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func page(
        _ id: String,
        on date: Date,
        text: String,
        weather: [String] = [],
        type: BookPageType = .diary,
        tags: [String] = []
    ) -> BookPage {
        BookPage(
            id: id, type: type, createdAt: date,
            promptText: "Prompt", userInput: text,
            tags: tags, origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: weather)
        )
    }

    private func day(_ index: Int, pages: [BookPage]) -> BookDay {
        let date = GrimoireDay.date(for: index, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return BookDay(
            id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
            date: calendar.startOfDay(for: date),
            pages: pages
        )
    }

    /// Sixty days in which the reader writes the word "lantern" mostly when it
    /// rains. Nothing anywhere says so.
    private func lanternArchive() -> [BookDay] {
        (0..<60).map { index in
            let date = calendar.date(
                byAdding: .hour, value: 20,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 5 == 0
            let text: String
            if rainy && index != 25 {
                text = "The lantern outside was swinging in the wet."
            } else {
                text = "Quiet enough. Bread, errands, nothing worth marking."
            }
            return day(index, pages: [
                page("page-\(index)", on: date, text: text, weather: rainy ? ["rain"] : ["clear"])
            ])
        }
    }

    private func swept(_ days: [BookDay], projectors: [any LoomProjector.Type]? = nil) -> GrimoireLedger {
        let slice = GrimoireSlice(days: days, calendar: calendar)
        let observations = projectors.map {
            GrimoireProjection.observations(from: slice, projectors: $0)
        } ?? GrimoireProjection.observations(from: slice)
        var ledger = GrimoireLedger()
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 61, calendar: calendar),
                                      budget: 800, calendar: calendar)
            passes += 1
            if report.finished || passes > 60 { break }
        }
        return ledger
    }

    // MARK: The pipeline

    func testProjectorsTurnRealDaysIntoObservations() {
        let slice = GrimoireSlice(days: lanternArchive(), calendar: calendar)
        let observations = GrimoireProjection.observations(from: slice)
        XCTAssertEqual(observations.count, 120)
        let first = observations.first { $0.evidencePageID == "page-0" }!
        XCTAssertTrue(first.features.contains { $0.domain == "weather" })
        XCTAssertTrue(first.features.contains { $0.domain == "hour" })
        XCTAssertTrue(first.features.contains { $0.domain == "pageKind" })
        XCTAssertTrue(first.features.contains { $0.domain == "word" })
        XCTAssertTrue(first.features.contains { $0.domain == "season" })
    }

    func testSeveralPageReceiptsStillCountAsOneDayOfEvidence() {
        let date = calendar.date(
            byAdding: .hour, value: 12,
            to: GrimoireDay.date(for: 5, calendar: calendar)
        )!
        let busy = day(5, pages: [
            page("a", on: date, text: "First thought about the harbour."),
            page("b", on: date, text: "Second thought about the harbour."),
            page("c", on: date, text: "Third thought about the harbour.")
        ])
        let observations = GrimoireProjection.observations(
            from: GrimoireSlice(days: [busy], calendar: calendar)
        )
        XCTAssertEqual(observations.filter { $0.evidencePageID != nil }.count, 3)
        var ledger = GrimoireLedger()
        ledger.ingest(observations)
        XCTAssertEqual(ledger.universe.count, 1)
        XCTAssertEqual(ledger.days(of: "word:harbour").count, 1)
    }

    func testFindsTheReadersOwnWordUnderTheRightWeather() {
        let ledger = swept(lanternArchive())
        let id = GrimoireCorrespondence.key(
            shape: .conditional, condition: "weather:rain", outcome: "word:lantern"
        )
        guard let row = ledger.row(id) else {
            return XCTFail("the Book missed the lantern")
        }
        let stats = ledger.currentStats(for: row, calendar: calendar)!
        XCTAssertEqual(stats.inCount, 12)
        XCTAssertEqual(stats.inHits, 11)
        XCTAssertEqual(stats.outHits, 0)
    }

    func testTwoPagesOnOneDayDoNotBorrowEachOthersContext() {
        let days = (0..<60).map { index -> BookDay in
            let base = GrimoireDay.date(for: index, calendar: calendar)
            let morning = calendar.date(byAdding: .hour, value: 9, to: base)!
            let night = calendar.date(byAdding: .hour, value: 22, to: base)!
            let fae = page(
                "fae-\(index)", on: morning, text: "A small encounter.",
                weather: ["clear"], type: .faeBargain,
                tags: index % 5 == 0 ? ["fae:sentenceSalamander"] : []
            )
            let weather = page(
                "rain-\(index)", on: night, text: "Rain at the window.",
                weather: index % 5 == 0 ? ["rain"] : ["clear"]
            )
            return day(index, pages: [fae, weather])
        }
        let ledger = swept(days)
        let id = GrimoireCorrespondence.key(
            shape: .conditional, condition: "weather:rain", outcome: "fae:sentenceSalamander"
        )
        XCTAssertNil(ledger.row(id), "separate events on one date became a false encounter context")
    }

    func testEvidencePointsToThePageThatCarriedTheFeatures() throws {
        let days = (0..<60).map { index -> BookDay in
            let base = GrimoireDay.date(for: index, calendar: calendar)
            let unrelated = page(
                "unrelated-\(index)",
                on: calendar.date(byAdding: .hour, value: 10, to: base)!,
                text: "Bread and errands.", weather: ["clear"]
            )
            let rainy = index % 5 == 0
            let signal = page(
                "signal-\(index)",
                on: calendar.date(byAdding: .hour, value: 20, to: base)!,
                text: rainy && index != 25 ? "The lantern was swinging." : "A quiet window.",
                weather: rainy ? ["rain"] : ["clear"]
            )
            return day(index, pages: [unrelated, signal])
        }
        let ledger = swept(days)
        let id = GrimoireCorrespondence.key(
            shape: .conditional, condition: "weather:rain", outcome: "word:lantern"
        )
        let row = try XCTUnwrap(ledger.row(id))
        let evidence = ledger.evidencePageIDs(for: row)
        XCTAssertFalse(evidence.isEmpty)
        XCTAssertTrue(evidence.allSatisfy { $0.hasPrefix("signal-") }, "got \(evidence)")
    }

    // MARK: The extension point

    func testANewSourceNeedsNothingButItsOwnFile() {
        // Tea every fourth day; the reader writes at length on those days too.
        let days = (0..<60).map { index -> BookDay in
            let date = calendar.date(
                byAdding: .hour, value: 20,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let text = index % 4 == 0
                ? String(repeating: "The kettle and the window and the long grey afternoon. ", count: 4)
                : "Short."
            return day(index, pages: [page("page-\(index)", on: date, text: text)])
        }
        let ledger = swept(days, projectors: GrimoireProjection.registered + [TeaProjector.self])

        let found = ledger.rows.values.filter { $0.conditionID == "drink:tea" }
        XCTAssertFalse(found.isEmpty, "a brand new source produced nothing")

        // And it speaks in the same voice as everything else, with no case
        // anywhere in the engine that mentions tea.
        guard let row = found.first(where: { $0.shape == .conditional }) else {
            return XCTFail("no ordinary correspondence for the new source")
        }
        let line = GrimoireVoice.entry(row: row, ledger: ledger, calendar: calendar)
        XCTAssertTrue(line.contains("tea"), "got: \(line)")
        XCTAssertFalse(line.isEmpty)
    }

    // MARK: Provenance and care

    func testTheBooksOwnProseNeverBecomesEvidenceAboutTheReader() {
        // A Page the Book wrote, with the Book's words in it.
        let date = GrimoireDay.date(for: 3, calendar: calendar)
        let generated = BookPage(
            id: "generated", type: .narrativeOS, createdAt: date,
            promptText: "The Book wrote this", userInput: "A lantern swinging in the wet.",
            origin: .generated,
            context: BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: ["rain"])
        )
        let features = ReaderWordsProjector.features(
            forPage: generated,
            in: GrimoireSlice(days: [], calendar: calendar)
        )
        XCTAssertTrue(features.isEmpty, "the Book quoted itself as evidence about the reader")
    }

    func testEveryWordFeatureIsMarkedAsTheReadersOwnHand() {
        let date = GrimoireDay.date(for: 3, calendar: calendar)
        let written = page("written", on: date, text: "Lantern, harbour, weather, kettle, morning.")
        let features = ReaderWordsProjector.features(
            forPage: written, in: GrimoireSlice(days: [], calendar: calendar)
        )
        XCTAssertFalse(features.isEmpty)
        XCTAssertTrue(features.allSatisfy { $0.provenance == .readerAuthored })
        XCTAssertLessThanOrEqual(features.count, ReaderWordsProjector.perPage)
    }

    func testBodyAndSleepAreCountedButNeverSpokenCasually() {
        let date = GrimoireDay.date(for: 3, calendar: calendar)
        let context = BookPageContextSnapshot(
            at: date, calendar: calendar, weatherTags: ["rain"],
            bodyScore: 20, sleepHours: 4.5
        )
        let page = BookPage(
            id: "body", type: .diary, createdAt: date, promptText: "p",
            userInput: "A short night.", origin: .userAuthored, context: context
        )
        let features = InnerWeatherProjector.features(
            forPage: page, in: GrimoireSlice(days: [], calendar: calendar)
        )
        XCTAssertEqual(features.count, 2)
        XCTAssertTrue(features.allSatisfy { $0.sensitivity == .innerState })
        XCTAssertTrue(features.allSatisfy { $0.role == .conditionOnly })
    }

    func testCastAndChoicesAreActsAndMayBeCountedAsSuch() {
        let date = GrimoireDay.date(for: 3, calendar: calendar)
        let tagged = page("tagged", on: date, text: "", type: .narrativeOS,
                          tags: ["entity:wicker", "choice:the-long-way", "genre:mystery"])
        let features = StoryTagProjector.features(
            forPage: tagged, in: GrimoireSlice(days: [], calendar: calendar)
        )
        XCTAssertEqual(features.count, 3)
        // The observable act is admissible; only generated prose is not.
        XCTAssertTrue(features.allSatisfy { $0.provenance == .systemEvent })
        XCTAssertTrue(features.contains { $0.id == "cast:wicker" })
    }

    func testTheQuietDaysAreCountedToo() {
        // A day with nothing kept still produces a row, which is the only way
        // absence is ever expressible.
        let empty = day(9, pages: [])
        let features = DayShapeProjector.features(
            forDay: empty, in: GrimoireSlice(days: [empty], calendar: calendar)
        )
        XCTAssertTrue(features.contains { $0.id == "writing:quiet" })
    }

    func testEveryRegisteredProjectorDeclaresWhatItProduces() {
        for projector in GrimoireProjection.registered {
            XCTAssertFalse(projector.id.isEmpty)
            XCTAssertFalse(projector.domains.isEmpty, "\(projector.id) declares no domains")
        }
        // Explicit closure, not `map(\.id)`: a key path over an array of
        // `any LoomProjector.Type` crashes SILGen on Swift 6.3.3. Do not tidy.
        let ids = GrimoireProjection.registered.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "two projectors share an id")
    }
}

/// The sources that make the pitch's own examples askable.
final class GrimoireWorldSourceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func day(_ index: Int, weather: [String], tags: [String] = []) -> BookDay {
        let date = calendar.date(
            byAdding: .hour, value: 22,
            to: GrimoireDay.date(for: index, calendar: calendar)
        )!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let page = BookPage(
            id: "page-\(index)", type: .diary, createdAt: date,
            promptText: "p", userInput: "An ordinary evening, written down.", tags: tags,
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: weather)
        )
        return BookDay(
            id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
            date: calendar.startOfDay(for: date),
            pages: [page]
        )
    }

    private func bargain(_ id: String, kind: FaeKind, offered: Int, delivered: Int? = nil) -> FaeBargain {
        FaeBargain(
            id: id, faeKind: kind, slot: "test", giftID: "g", giftName: "A Gift",
            giftEffectLine: "It hums.", openingGesture: "A thread appears.",
            terms: "Notice one thing.",
            offeredAt: GrimoireDay.date(for: offered, calendar: calendar),
            deadline: GrimoireDay.date(for: offered + 2, calendar: calendar),
            status: delivered == nil ? .owed : .delivered,
            fieldReport: nil, faeResponse: nil, rewardText: nil,
            deliveredAt: delivered.map { GrimoireDay.date(for: $0, calendar: calendar) }
        )
    }

    private func swept(_ slice: GrimoireSlice) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(from: slice))
        var passes = 0
        while true {
            let report = ledger.sweep(
                now: GrimoireDay.date(for: 90, calendar: calendar),
                budget: 900,
                calendar: calendar
            )
            passes += 1
            if report.finished || passes > 80 { break }
        }
        return ledger
    }

    /// "The Fae come out more when it rains at night." Nothing codes this.
    func testFaeSpeciesCanBeRelatedToTheWeatherItArrivesIn() throws {
        var days: [BookDay] = []
        var bargains: [FaeBargain] = []
        for index in 0..<60 {
            let rainy = index % 5 == 0
            days.append(day(
                index,
                weather: rainy ? ["rain"] : ["clear"],
                tags: rainy && index != 30 ? ["fae:sentenceSalamander"] : []
            ))
            // The Salamanders answer rain, and almost nothing else.
            if rainy && index != 30 {
                bargains.append(bargain("b-\(index)", kind: .sentenceSalamander, offered: index))
            }
        }
        let slice = GrimoireSlice(days: days, faeBargains: bargains, calendar: calendar)
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(from: slice))
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 61, calendar: calendar),
                                      budget: 800, calendar: calendar)
            passes += 1
            if report.finished || passes > 60 { break }
        }

        let id = GrimoireCorrespondence.key(
            shape: .conditional, condition: "weather:rain", outcome: "fae:sentenceSalamander"
        )
        let row = try XCTUnwrap(ledger.row(id), "the Book missed the Salamanders in the rain")
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        XCTAssertEqual(stats.inCount, 12)
        XCTAssertEqual(stats.inHits, 11)
        XCTAssertEqual(stats.outHits, 0)

        let line = GrimoireVoice.claim(row: row, stats: stats, ledger: ledger, calendar: calendar)
        XCTAssertTrue(line.contains("Sentence Salamander") || line.contains("Salamander"), line)
    }

    func testAFaeBargainKeptIsAnOutcomeAndBeingAboutIsNot() {
        let met = FaeEncounterProjector.features(
            forDay: day(4, weather: []),
            in: GrimoireSlice(
                days: [], faeBargains: [bargain("b", kind: .goblin, offered: 4, delivered: 4)],
                calendar: calendar
            )
        )
        XCTAssertEqual(met.count, 2)
        let appearance = met.first { $0.domain == "fae" }
        let kept = met.first { $0.domain == "faeKept" }
        // A Fae turning up is circumstance; keeping your side of it is a choice.
        XCTAssertEqual(appearance?.role, .either)
        XCTAssertEqual(appearance?.provenance, .systemEvent)
        XCTAssertEqual(kept?.role, .outcomeOnly)
        XCTAssertEqual(kept?.provenance, .readerAuthored)
    }

    func testAWorkingSeparatesBeingSetFromBeingComeBackFrom() {
        let working = BookWorking(
            id: "w1", recipeID: "unnecessary-route",
            initiatorKind: .character, initiatorID: "wicker", initiatorName: "Wicker",
            title: "The Long Way", summons: "s", invitation: "i", returnPrompt: "r",
            createdAt: GrimoireDay.date(for: 10, calendar: calendar),
            startsAt: GrimoireDay.date(for: 10, calendar: calendar),
            endsAt: GrimoireDay.date(for: 12, calendar: calendar),
            status: .returned, effects: [],
            returnedAt: GrimoireDay.date(for: 12, calendar: calendar)
        )
        let slice = GrimoireSlice(days: [], workings: [working], calendar: calendar)

        // Setting one is its own day, and carries no outcome.
        let setDay = WorkingProjector.features(forDay: day(10, weather: []), in: slice)
        XCTAssertTrue(setDay.contains { $0.id == "working:unnecessary-route" })
        XCTAssertTrue(setDay.contains { $0.id == "working-by:wicker" })
        XCTAssertFalse(setDay.contains { $0.domain == "workingOutcome" })
        XCTAssertFalse(setDay.contains { $0.domain == "workingEpisode" })

        // The day it resolves carries both halves at once — which is the whole
        // point, because that is the only way two kinds can be compared.
        let endDay = WorkingProjector.features(forDay: day(12, weather: []), in: slice)
        XCTAssertTrue(endDay.contains { $0.id == "working-episode:unnecessary-route" })
        XCTAssertTrue(endDay.contains { $0.id == "working-outcome:returned" })
        XCTAssertTrue(endDay.contains { $0.id == "working-by:wicker" })
    }

    /// "Indoor Compass Runs bring back the word *fun*." Nobody coded it.
    func testACompassRunKindCanBeRelatedToTheReadersOwnWord() throws {
        var observations: [LoomObservation] = []
        var ledger = GrimoireLedger()
        let daily = LoomFeatureRef(
            id: "hour:day", domain: "hour", label: "daytime",
            conditionClause: "it was daytime", outcomeClause: "it was daytime",
            role: .conditionOnly
        )
        for index in 0..<80 {
            // Midday, not midnight. `capturedPages` windows on the BookDay id
            // parsed in the *local* calendar, so a UTC-midnight page falls on
            // the previous local day and the whole day reads as empty.
            let date = calendar.date(
                byAdding: .hour, value: 12,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            var pageTags: [String] = ["wonder-compass", "wonder-compass-run"]
            var text = "An ordinary day, written down plainly."
            if index % 6 == 0 {
                pageTags.append("compass-place:indoors")
                if index != 36 { text = "That was unreasonably fun, start to finish." }
            }
            let page = BookPage(
                id: "page-\(index)", type: .wonderCompass, createdAt: date,
                promptText: "p", userInput: text, tags: pageTags, origin: .userAuthored,
                context: BookPageContextSnapshot(at: date, calendar: calendar)
            )
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let day = BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date), pages: [page]
            )
            var features = GrimoireProjection.observations(
                from: GrimoireSlice(days: [day], calendar: calendar)
            ).first(where: { $0.evidencePageID == page.id })?.features ?? []
            features.append(daily)
            observations.append(LoomObservation(
                id: "day-\(index)", day: index, occurredAt: date,
                features: features, evidencePageID: page.id, evidenceLine: ""
            ))
        }
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 81, calendar: calendar),
                                      budget: 900, calendar: calendar)
            passes += 1
            if report.finished || passes > 60 { break }
        }

        let id = GrimoireCorrespondence.key(
            shape: .conditional, condition: "compass-place:indoors", outcome: "word:fun"
        )
        let row = try XCTUnwrap(ledger.row(id), "the Book missed what the run brought back")
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        XCTAssertEqual(stats.inHits, 13)
        XCTAssertEqual(stats.outHits, 0)
    }

    func testACompassPageWithoutAModeContributesNothing() {
        let date = GrimoireDay.date(for: 3, calendar: calendar)
        let bare = BookPage(
            id: "bare", type: .wonderCompass, createdAt: date,
            promptText: "p", userInput: "Out and back.", tags: ["wonder-compass"],
            origin: .userAuthored
        )
        XCTAssertTrue(
            CompassRunProjector.features(forPage: bare, in: GrimoireSlice(days: [], calendar: calendar)).isEmpty
        )
    }

    func testWaterCanBecomeThisReadersAlivenessCondition() throws {
        let rows = (0..<60).map { index -> DaybookEntry in
            let date = GrimoireDay.date(for: index, calendar: calendar)
            var entry = DaybookEntry(
                dayID: BookDay.id(for: date), date: date, fidelity: .live,
                calendar: calendar, writtenAt: date
            )
            let waterDay = index % 5 == 0
            entry.placeLabel = waterDay ? "East Harbor" : "Office"
            entry.alivenessScore = waterDay && index != 25 ? 9 : 3
            entry.keptPageCount = index % 2
            entry.medianWordsWritten = entry.keptPageCount > 0 ? 12 : 0
            return entry
        }
        let ledger = swept(GrimoireSlice(days: [], daybookRows: rows, calendar: calendar))
        let id = GrimoireCorrespondence.key(
            shape: .conditional,
            condition: "place-kind:water",
            outcome: "reader-state:alive"
        )
        let row = try XCTUnwrap(ledger.row(id), "the Book missed water and aliveness")
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        XCTAssertEqual(stats.inCount, 12)
        XCTAssertEqual(stats.inHits, 11)
        XCTAssertEqual(stats.outHits, 0)
        XCTAssertTrue(ledger.speakable(calendar: calendar).contains { $0.id == id })
    }

    func testSerenityCanPrecedeExplicitlyBrightMoments() throws {
        var days: [BookDay] = []
        var pulses: [ReaderStatePulseRecord] = []
        for index in 0..<60 {
            let base = GrimoireDay.date(for: index, calendar: calendar)
            let date = calendar.date(byAdding: .hour, value: 18, to: base)!
            let serenityDay = index % 5 == 0
            let pageID = "page-\(index)"
            let page = BookPage(
                id: pageID, type: .narrativeOS, createdAt: date,
                promptText: "p", userInput: "", tags: serenityDay ? ["entity:serenity"] : [],
                origin: .generated,
                context: BookPageContextSnapshot(at: date, calendar: calendar)
            )
            days.append(day(index, weather: []).withPages([page]))
            if serenityDay {
                let answeredAt = calendar.date(byAdding: .day, value: 1, to: date)!
                pulses.append(ReaderStatePulseRecord(
                    id: "pulse-\(index)", dimension: .delayedOutcome, score: 9,
                    answerCode: "bright", answerLine: "That stayed bright.", note: nil,
                    askedAt: answeredAt, answeredAt: answeredAt,
                    dayID: BookDay.id(for: answeredAt), context: nil, facets: [],
                    target: ReaderStatePulseTarget(
                        sessionID: "session-\(index)", movement: .livingWorld, role: .door,
                        sourceID: "story", pageID: pageID,
                        causalOpportunityID: nil, causalMovementOpportunityID: nil,
                        happenedAt: date
                    )
                ))
            }
        }
        let ledger = swept(GrimoireSlice(
            days: days, readerStatePulses: pulses, calendar: calendar
        ))
        let id = GrimoireCorrespondence.key(
            shape: .sequential,
            condition: "cast:serenity",
            outcome: "reader-state:bright-moment"
        )
        let row = try XCTUnwrap(ledger.row(id), "the Book missed Serenity preceding bright reports")
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        XCTAssertEqual(stats.inHits, 12)
        XCTAssertEqual(stats.inRate, 1, accuracy: 0.001)
        XCTAssertGreaterThan(stats.lift, GrimoireLedger.Bars.minimumLift)
    }

    private func working(
        _ id: String, recipe: String, set: Int, ends: Int,
        status: BookWorkingStatus, returned: Int? = nil
    ) -> BookWorking {
        BookWorking(
            id: id, recipeID: recipe,
            initiatorKind: .character, initiatorID: "wicker", initiatorName: "Wicker",
            title: "A Working", summons: "s", invitation: "i", returnPrompt: "r",
            createdAt: GrimoireDay.date(for: set, calendar: calendar),
            startsAt: GrimoireDay.date(for: set, calendar: calendar),
            endsAt: GrimoireDay.date(for: ends, calendar: calendar),
            status: status, effects: [],
            returnedAt: returned.map { GrimoireDay.date(for: $0, calendar: calendar) }
        )
    }

    /// "Wicker's unnecessary routes bring something back. His object hunts don't."
    ///
    /// This is the test the earlier one only *looked* like. That one built the
    /// ledger by hand with an outcome the live projector never emits, so it
    /// proved the engine and not the wiring — the comparison could not fire on
    /// real Workings at all. This one goes through `GrimoireProjection`, and the
    /// two halves of each episode are ten days apart on purpose.
    func testTwoKindsOfWorkingAreComparedOnRealReceipts() throws {
        var workings: [BookWorking] = []
        for slot in 0..<12 {
            let set = slot * 8
            workings.append(working(
                "route-\(slot)", recipe: "unnecessary-route", set: set, ends: set + 10,
                status: slot == 7 ? .elapsed : .returned,
                returned: slot == 7 ? nil : set + 10
            ))
            workings.append(working(
                "hunt-\(slot)", recipe: "object-hunt", set: set + 3, ends: set + 13,
                status: slot == 4 ? .returned : .elapsed,
                returned: slot == 4 ? set + 13 : nil
            ))
        }
        let days = (0..<200).map { index -> BookDay in
            let date = calendar.date(
                byAdding: .hour, value: 12,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date),
                pages: [BookPage(
                    id: "page-\(index)", type: .diary, createdAt: date,
                    promptText: "p", userInput: "An ordinary day, written down.",
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(at: date, calendar: calendar)
                )]
            )
        }

        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(
            from: GrimoireSlice(days: days, workings: workings, calendar: calendar)
        ))
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 201, calendar: calendar),
                                      budget: 1_500, calendar: calendar)
            passes += 1
            if report.finished || passes > 150 { break }
        }

        // The two halves of an episode now meet, so the plain claim forms.
        let plain = GrimoireCorrespondence.key(
            shape: .conditional,
            condition: "working-episode:unnecessary-route",
            outcome: "working-outcome:returned"
        )
        let route = try XCTUnwrap(ledger.row(plain), "the route episodes never met their own outcome")
        let stats = try XCTUnwrap(ledger.currentStats(for: route, calendar: calendar))
        XCTAssertEqual(stats.inCount, 12)
        XCTAssertEqual(stats.inHits, 11)

        // And the comparison the engine exists for actually fires on real data.
        let comparison = try XCTUnwrap(
            ledger.rows.values.first {
                $0.shape == .sibling
                    && $0.conditionID == "working-episode:unnecessary-route"
                    && $0.rivalID == "working-episode:object-hunt"
            },
            "the two kinds of Working were never compared"
        )
        let line = GrimoireVoice.claim(
            row: comparison,
            stats: try XCTUnwrap(ledger.currentStats(for: comparison, calendar: calendar)),
            ledger: ledger, calendar: calendar
        )
        XCTAssertTrue(line.localizedCaseInsensitiveContains("unnecessary route"), line)
        XCTAssertTrue(line.localizedCaseInsensitiveContains("object hunt"), line)
    }

    func testAWorkingThatIsStillRunningHasNoOutcomeYet() {
        let open = working("open", recipe: "unnecessary-route", set: 3, ends: 20, status: .arranged)
        let onEndDay = WorkingProjector.features(
            forDay: day(20, weather: []),
            in: GrimoireSlice(days: [], workings: [open], calendar: calendar)
        )
        // Nothing has been settled, so nothing is claimed.
        XCTAssertFalse(onEndDay.contains { $0.domain == "workingOutcome" })
        XCTAssertFalse(onEndDay.contains { $0.domain == "workingEpisode" })
    }

    func testComingBackIsTheReadersActAndLapsingIsTheCalendars() throws {
        let slice = GrimoireSlice(
            days: [],
            workings: [
                working("a", recipe: "unnecessary-route", set: 1, ends: 9, status: .returned, returned: 9),
                working("b", recipe: "object-hunt", set: 1, ends: 9, status: .elapsed)
            ],
            calendar: calendar
        )
        let features = WorkingProjector.features(forDay: day(9, weather: []), in: slice)
        let returned = try XCTUnwrap(features.first { $0.id == "working-outcome:returned" })
        let lapsed = try XCTUnwrap(features.first { $0.id == "working-outcome:lapsed" })
        XCTAssertEqual(returned.provenance, .readerAuthored)
        XCTAssertEqual(lapsed.provenance, .systemEvent)
        XCTAssertEqual(returned.role, .outcomeOnly)
    }

    /// The moon needs no receipt at all — it is a function of the date — which
    /// makes it the cheapest honest condition the Book will ever have.
    func testTheMoonIsACondition() throws {
        let features = MoonProjector.features(
            forDay: day(400, weather: []), in: GrimoireSlice(days: [], calendar: calendar)
        )
        let moon = try XCTUnwrap(features.first)
        XCTAssertEqual(moon.domain, "moon")
        XCTAssertEqual(moon.role, .conditionOnly, "the reader does not cause the moon")
        // Four bands over a cycle, not an ephemeris.
        let bands = Set((0..<40).flatMap {
            MoonProjector.features(forDay: day(400 + $0, weather: []),
                                   in: GrimoireSlice(days: [], calendar: calendar))
        }.map(\.id))
        XCTAssertGreaterThan(bands.count, 1)
        XCTAssertLessThanOrEqual(bands.count, 4)
    }

    /// Paying a talisman means leaving the Book and noticing something real,
    /// which makes it one of the strongest outcomes there is. Letting it lapse
    /// is the calendar's doing.
    func testPayingAnErrandIsTheReadersActAndLapsingIsNot() throws {
        let base = GrimoireDay.date(for: 30, calendar: calendar)
        let paid = PactErrand(
            id: "paid", talismanID: "ember-seal", territoryID: "t",
            openingLine: "o", terms: "t",
            offeredAt: base.addingTimeInterval(-86_400 * 3),
            deadline: base.addingTimeInterval(86_400),
            status: .delivered, fieldReport: nil, talismanResponse: nil, deliveredAt: base
        )
        let lapsed = PactErrand(
            id: "lapsed", talismanID: "ember-seal", territoryID: "t",
            openingLine: "o", terms: "t",
            offeredAt: base.addingTimeInterval(-86_400 * 3),
            deadline: base, status: .lapsed,
            fieldReport: nil, talismanResponse: nil, deliveredAt: nil
        )
        let features = PactErrandProjector.features(
            forDay: day(30, weather: []),
            in: GrimoireSlice(days: [], pactErrands: [paid, lapsed], calendar: calendar)
        )
        let paidFeature = try XCTUnwrap(features.first { $0.id == "errand-outcome:paid" })
        let lapsedFeature = try XCTUnwrap(features.first { $0.id == "errand-outcome:lapsed" })
        XCTAssertEqual(paidFeature.provenance, .readerAuthored)
        XCTAssertEqual(paidFeature.role, .outcomeOnly)
        XCTAssertEqual(lapsedFeature.provenance, .systemEvent)
        XCTAssertTrue(features.contains { $0.id == "talisman:ember-seal" })
    }

    func testAnErrandStillOwedIsNotAnOutcome() {
        let base = GrimoireDay.date(for: 30, calendar: calendar)
        let owed = PactErrand(
            id: "owed", talismanID: "ember-seal", territoryID: "t",
            openingLine: "o", terms: "t", offeredAt: base, deadline: base,
            status: .owed, fieldReport: nil, talismanResponse: nil, deliveredAt: nil
        )
        XCTAssertTrue(PactErrandProjector.features(
            forDay: day(30, weather: []),
            in: GrimoireSlice(days: [], pactErrands: [owed], calendar: calendar)
        ).isEmpty)
    }

    /// The Book speaking is not evidence about the reader. The reader
    /// *answering* is.
    func testOnlyAnAnsweredAsideCounts() throws {
        let base = GrimoireDay.date(for: 30, calendar: calendar)
        var answered = BookAsideReceipt(
            id: "a", servedAt: base, surfaceID: "s", sourceID: "src",
            intention: "i", thoughtKey: "t", wordingKey: "w"
        )
        answered.response = .goOn
        answered.respondedAt = base
        let ignored = BookAsideReceipt(
            id: "b", servedAt: base, surfaceID: "s", sourceID: "src",
            intention: "i", thoughtKey: "t", wordingKey: "w"
        )
        let slice = GrimoireSlice(days: [], asideReceipts: [answered, ignored], calendar: calendar)
        let features = AsideReplyProjector.features(forDay: day(30, weather: []), in: slice)
        XCTAssertEqual(features.count, 1)
        XCTAssertEqual(features[0].id, "aside:answered")
        XCTAssertEqual(features[0].provenance, .readerAuthored)

        // An aside the reader never answered leaves no trace about them.
        let quiet = GrimoireSlice(days: [], asideReceipts: [ignored], calendar: calendar)
        XCTAssertTrue(AsideReplyProjector.features(forDay: day(30, weather: []), in: quiet).isEmpty)
    }

    /// Keeping a thing takes reaching for it. Nobody presses a ticket stub into
    /// a book by accident, which is what makes this an outcome.
    func testPressingSomethingIntoThePocketIsTheReadersAct() throws {
        let date = GrimoireDay.date(for: 40, calendar: calendar)
        let keepsake = PocketKeepsake(
            id: "k", dayID: "d", pageType: .souvenir, object: "a ticket stub",
            glyph: "ticket", foundAt: date, sourceSurfaceID: nil,
            title: nil, excerpt: nil, reason: nil, mediaAssets: nil
        )
        let features = PocketProjector.features(
            forDay: day(40, weather: []),
            in: GrimoireSlice(days: [], pocketKeepsakes: [keepsake], calendar: calendar)
        )
        let kept = try XCTUnwrap(features.first)
        XCTAssertEqual(kept.provenance, .readerAuthored)
        XCTAssertFalse(PocketProjector.bookAsked(
            forDay: day(40, weather: []),
            in: GrimoireSlice(days: [], pocketKeepsakes: [keepsake], calendar: calendar)
        ), "the reader reached for it")
    }

    /// The Book opened the door, so a jump is something it arranged — but what
    /// the reader carried back out is theirs.
    func testAJumpIsArrangedAndItsSouvenirIsNot() throws {
        let date = GrimoireDay.date(for: 40, calendar: calendar)
        func jump(_ id: String, souvenir: String) -> ReturnedBookJump {
            ReturnedBookJump(
                id: id, bookID: "carroll", title: "Wonderland", author: "Carroll",
                returnedAt: date, depth: 2, degradation: 0,
                souvenir: souvenir, outcome: "returned"
            )
        }
        let carried = GrimoireSlice(
            days: [], returnedJumps: [jump("a", souvenir: "A tin key.")], calendar: calendar
        )
        let features = BookJumpProjector.features(forDay: day(40, weather: []), in: carried)
        XCTAssertTrue(features.contains { $0.id == "jump-outcome:carried" })
        let outcome = try XCTUnwrap(features.first { $0.domain == "jumpOutcome" })
        XCTAssertEqual(outcome.provenance, .readerAuthored)
        XCTAssertEqual(outcome.role, .outcomeOnly)
        // The Book set the door up, so the day is not free evidence.
        XCTAssertTrue(BookJumpProjector.bookAsked(forDay: day(40, weather: []), in: carried))

        let empty = GrimoireSlice(
            days: [], returnedJumps: [jump("b", souvenir: "  ")], calendar: calendar
        )
        XCTAssertTrue(
            BookJumpProjector.features(forDay: day(40, weather: []), in: empty)
                .contains { $0.id == "jump-outcome:empty-handed" }
        )
    }

    /// Only the most recent keeping carries a date, so the Book counts what it
    /// can honestly see and says nothing about the rest.
    func testAnObservanceIsCountedOnlyOnTheDayItCanBeSeen() {
        let date = GrimoireDay.date(for: 40, calendar: calendar)
        var tradition = BookPrivateTradition(
            id: "t", kind: .dogEarDay, title: "Dog-Ear Day",
            observance: "Fold one corner.", originMemoryID: "m",
            evidencePageIDs: [], foundedAt: date.addingTimeInterval(-86_400 * 400),
            cadenceDays: 365, nextDueAt: date, observanceCount: 3
        )
        tradition.lastObservedAt = date
        let slice = GrimoireSlice(days: [], traditions: [tradition], calendar: calendar)
        XCTAssertFalse(ObservanceProjector.features(forDay: day(40, weather: []), in: slice).isEmpty)
        // Not on the days it cannot vouch for.
        XCTAssertTrue(ObservanceProjector.features(forDay: day(39, weather: []), in: slice).isEmpty)

        var never = tradition
        never.lastObservedAt = nil
        XCTAssertTrue(ObservanceProjector.features(
            forDay: day(40, weather: []),
            in: GrimoireSlice(days: [], traditions: [never], calendar: calendar)
        ).isEmpty)
    }

    func testWorldSourcesAreSilentWhenTheBookHasNoneOfThem() {
        let empty = GrimoireSlice(days: [], calendar: calendar)
        XCTAssertTrue(FaeEncounterProjector.features(forDay: day(1, weather: []), in: empty).isEmpty)
        XCTAssertTrue(WorkingProjector.features(forDay: day(1, weather: []), in: empty).isEmpty)
        XCTAssertTrue(CompassRunProjector.features(forDay: day(1, weather: []), in: empty).isEmpty)
        XCTAssertTrue(PactErrandProjector.features(forDay: day(1, weather: []), in: empty).isEmpty)
        XCTAssertTrue(AsideReplyProjector.features(forDay: day(1, weather: []), in: empty).isEmpty)
    }
}

private extension BookDay {
    func withPages(_ pages: [BookPage]) -> BookDay {
        BookDay(id: id, date: date, pages: pages)
    }
}
