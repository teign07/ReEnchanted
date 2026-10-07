import XCTest
@testable import InsideCoverCore

/// The same Believing, the same journal prompt, the same Pages in the same
/// order, on every launch and every "Explore deeper".
///
/// Three separate causes, each pinned here:
///   1. Believings and Journal prompts picked the same four on fit alone for as
///      long as the sky held: tag overlap was worth 22 points, the jitter 0-16.
///   2. The bench behind the published block held 16-17 Pages, because one Page
///      per type is a rule about nine leaves, not the reserve; a reader went
///      deeper once and met the end of it.
///   3. Whatever was short was topped up from a cupboard of thirteen fixed Pages
///      in a fixed order, and its dedupe key carried a time slot, so it never
///      recognised what it had already served.
final class ContentRepeatTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func fortnight(phrase: String) -> (believings: [String], benchSizes: [Int]) {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8, minute: 10))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: start.addingTimeInterval(-30 * 86_400))
        inputs.localBrainIsReady = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 46
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.weather = WeatherSourceSignal(
            phrase: phrase, source: "test", currentTemperature: "60F",
            forecast: nil, conditionSymbolName: "sun.max"
        )
        var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
        var believings: [String] = []
        var benchSizes: [Int] = []
        for dayOffset in 0..<14 {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            let today = BookDay(
                id: BookDay.id(for: dayStart, calendar: calendar),
                date: calendar.startOfDay(for: dayStart),
                pages: []
            )
            for hour in [8, 13, 20] {
                let now = calendar.date(bySettingHour: hour, minute: 15, second: 0, of: dayStart)!
                inputs.days = [today]
                inputs.surfaceHistory = surfaceHistory
                let full = BookCurator.surfacedPages(
                    for: today, inputs: inputs, now: now,
                    limit: BookDeskRound.candidateBenchCapacity
                )
                benchSizes.append(full.count)
                let desk = Array(full.prefix(BookDeskRound.reserveCapacity))
                believings += desk.filter { $0.type == .affirmations }
                    .compactMap { $0.payload.metadata["affirmationID"] }
                surfaceHistory = CuratorVarietyGovernor.recordingServed(
                    keys: desk.flatMap(\.curatorServedHistoryKeys), into: surfaceHistory, now: now
                )
            }
        }
        return (believings, benchSizes)
    }

    /// The sky that used to lock the shelf: 19 showings, 5 distinct Believings.
    func testAStableSkyDoesNotLockTheBelievingsToFour() {
        let run = fortnight(phrase: "Clear and warm sunny morning")
        XCTAssertGreaterThan(run.believings.count, 10)
        XCTAssertGreaterThanOrEqual(
            Set(run.believings).count * 10, run.believings.count * 9,
            "\(Set(run.believings).count) distinct in \(run.believings.count): \(run.believings)"
        )
    }

    func testTheBenchBehindTheBlockIsFull() {
        let run = fortnight(phrase: "Cloudy and cold")
        // It used to be 16-17 on most sessions. An occasional session can still
        // run short when rest empties the pool, which is what the cupboard is
        // for; what must not happen is a bench that is short as a matter of course.
        let full = run.benchSizes.filter { $0 >= 20 }.count
        XCTAssertGreaterThanOrEqual(
            full * 10, run.benchSizes.count * 9,
            "the bench ran short: \(run.benchSizes)"
        )
    }

    func testTheReserveRepeatsATypeOnlyAsDifferentContent() {
        let run = fortnight(phrase: "Cloudy and cold")
        XCTAssertFalse(run.benchSizes.isEmpty)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 9))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: now.addingTimeInterval(-30 * 86_400))
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: [])
        inputs.days = [day]
        let bench = BookCurator.surfacedPages(
            for: day, inputs: inputs, now: now, limit: BookDeskRound.candidateBenchCapacity
        )
        let counts = Dictionary(grouping: bench, by: \.type).mapValues(\.count)
        XCTAssertLessThanOrEqual(counts.values.max() ?? 0, BookCurator.reserveSiblingsPerType)
        XCTAssertEqual(
            Set(bench.map(\.curatorContentNoveltyKey)).count, bench.count,
            "the same content appeared twice on one bench"
        )
        // The published block itself is still one Page per type.
        let block = bench.prefix(BookDeskRound.reserveCapacity)
        XCTAssertEqual(Set(block.map(\.type)).count, block.count)
    }

    // MARK: Explore deeper

    private func page(_ id: String, prompt: String, evergreen: Bool = false) -> SurfacePage {
        SurfacePage(
            id: id, type: .affirmations, sourceID: "src-\(prompt)", prompt: prompt,
            detail: "detail",
            payload: BookPagePayload(
                headline: prompt, body: "body",
                metadata: evergreen ? ["evergreenPlayReserve": "true", "noveltyKey": prompt] : [:]
            )
        )
    }

    func testADeeperPullSkipsContentTheFolioAlreadyHoldsUnderAnyId() {
        let shown = [page("believing-slot-1", prompt: "same words")]
        let next = BookCurator.freshDeeperPages(
            from: [page("believing-slot-2", prompt: "same words"), page("other", prompt: "new words")],
            alreadyShown: shown, history: [:], now: Date(), limit: 9
        )
        XCTAssertEqual(next.map(\.id), ["other"])
    }

    func testTheCupboardIsNotHandedOverTwiceInARow() {
        let now = Date()
        let cupboard = page("evergreen-g1", prompt: "cupboard words", evergreen: true)
        let first = BookCurator.freshDeeperPages(
            from: [cupboard], alreadyShown: [], history: [:], now: now, limit: 9
        )
        XCTAssertEqual(first.count, 1)
        let served = CuratorVarietyGovernor.recordingServed(
            keys: first.flatMap(\.curatorServedHistoryKeys), into: [:], now: now
        )
        let again = BookCurator.freshDeeperPages(
            from: [page("evergreen-g2", prompt: "cupboard words", evergreen: true)],
            alreadyShown: [], history: served, now: now.addingTimeInterval(3_600), limit: 9
        )
        XCTAssertTrue(again.isEmpty)
        let later = BookCurator.freshDeeperPages(
            from: [page("evergreen-g3", prompt: "cupboard words", evergreen: true)],
            alreadyShown: [], history: served,
            now: now.addingTimeInterval(4 * 86_400), limit: 9
        )
        XCTAssertEqual(later.count, 1)
    }

    // MARK: Explore deeper never runs out

    /// Nine pages, then nine more, then nine more, for as long as the reader
    /// keeps asking. The Curator's bench is empty here on purpose: this is what
    /// the reader meets after the first couple of pulls.
    private func pulls(count: Int, keptPageCount: Int = 30) -> [[SurfacePage]] {
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 9))!
        var shown: [SurfacePage] = []
        var history: [String: SurfaceHistoryRecord] = [:]
        var result: [[SurfacePage]] = []
        for pull in 0..<count {
            let generation = shown.count + 1
            let next = BookCurator.deeperPull(
                bench: [], alreadyShown: shown, history: history,
                now: now.addingTimeInterval(Double(pull) * 20),
                limit: BookDeskRound.reserveCapacity
            ) { variants, rests, tier in
                BookEvergreenPlayReserve.pages(
                    now: now, generation: generation * 10 + tier,
                    keptPageCount: keptPageCount, history: history,
                    variantsPerCatalogue: variants, restsFixedSeeds: rests
                )
            }
            result.append(next)
            shown += next
            history = CuratorVarietyGovernor.recordingServed(
                keys: next.flatMap(\.curatorServedHistoryKeys), into: history,
                now: now.addingTimeInterval(Double(pull) * 20)
            )
        }
        return result
    }

    func testExploreDeeperAlwaysComesBackWithANineAndNeverRunsOut() {
        let run = pulls(count: 100)
        XCTAssertEqual(run.map(\.count), Array(repeating: BookDeskRound.reserveCapacity, count: 100))
        let ids = run.flatMap { $0.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count, "a page id was handed out twice")
    }

    func testTheCupboardAloneIsFreshForItsFirstPulls() {
        let run = pulls(count: 3)
        let content = run.flatMap { $0.map(\.curatorContentNoveltyKey) }
        XCTAssertEqual(Set(content).count, content.count, "content repeated inside the first three pulls")
    }

    func testExploreDeeperDoesNotRepeatWithinTheLastTwoPulls() {
        let run = pulls(count: 100)
        for index in 2..<run.count {
            let recent = Set(run[(index - 2)..<index].flatMap { $0.map(\.curatorContentNoveltyKey) })
            let overlap = run[index].filter { recent.contains($0.curatorContentNoveltyKey) }
            XCTAssertTrue(overlap.isEmpty, "pull \(index) repeated \(overlap.map(\.prompt))")
        }
    }

    /// A bench with eight of one type and a few of others: a pull takes at most
    /// three of the heavy one and fills the rest with what else there is.
    func testNoOneTypeSwampsAPullWhileThereIsAnythingElse() {
        func page(_ type: BookPageType, _ n: Int) -> SurfacePage {
            SurfacePage(
                id: "\(type.rawValue)-\(n)", type: type, sourceID: "src-\(type.rawValue)-\(n)",
                prompt: "\(type.rawValue) \(n)", detail: "d",
                payload: BookPagePayload(headline: "h", body: "b", metadata: [:])
            )
        }
        let bench = (0..<8).map { page(.quotes, $0) }
            + (0..<3).map { page(.diary, $0) } + (0..<3).map { page(.lore, $0) }
            + [page(.weather, 0), page(.fuel, 0), page(.rest, 0)]
        let next = BookCurator.deeperPull(
            bench: bench, alreadyShown: [], history: [:], now: Date(),
            limit: BookDeskRound.reserveCapacity
        ) { _, _, _ in [] }
        XCTAssertEqual(next.count, BookDeskRound.reserveCapacity)
        let counts = Dictionary(grouping: next, by: \.type).mapValues(\.count)
        XCTAssertLessThanOrEqual(counts[.quotes] ?? 0, 3, "\(counts)")
        XCTAssertGreaterThanOrEqual(counts.count, 4, "\(counts)")
    }

    // MARK: Rounds

    /// What the app does as the reader keeps going: curate a round of 27, show
    /// it nine at a time, and when the folio has shown it all, curate the next,
    /// told what has been shown. Measured on a Book with twelve days of ink.
    func testSuccessiveRoundsNeverRunDryAndStayVaried() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 15))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: start.addingTimeInterval(-30 * 86_400))
        inputs.localBrainIsReady = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 46
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.weather = WeatherSourceSignal(
            phrase: "Cloudy and cold", source: "t", currentTemperature: "50F",
            forecast: nil, conditionSymbolName: "cloud"
        )
        let lines = [
            "The kettle clicked off before the frost left the window.",
            "Down at the harbour a lantern kept swinging.",
            "A kestrel over the reservoir holding still.",
            "Bread going stale beside the kettle."
        ]
        var days: [BookDay] = []
        for offset in 1...12 {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: start)!
            days.append(BookDay(
                id: BookDay.id(for: dayStart, calendar: calendar),
                date: calendar.startOfDay(for: dayStart),
                pages: [BookPage(
                    id: "kept-\(offset)", type: .souvenir, createdAt: dayStart, promptText: "p",
                    userInput: lines[offset % lines.count], origin: .userAuthored
                )]
            ))
        }
        let today = BookDay(id: BookDay.id(for: start, calendar: calendar), date: calendar.startOfDay(for: start), pages: [])
        inputs.days = days.reversed() + [today]

        var history: [String: SurfaceHistoryRecord] = [:]
        var shown = Set<String>()
        for round in 0..<12 {
            inputs.surfaceHistory = history
            inputs.deckRound = round
            inputs.shownContentKeys = shown
            let now = start.addingTimeInterval(Double(round) * 60)
            let bench = BookCurator.surfacedPages(
                for: today, inputs: inputs, now: now, limit: BookDeskRound.candidateBenchCapacity
            )
            let counts = Dictionary(grouping: bench, by: \.type).mapValues(\.count)
            // Always at least one full pull in hand, however deep the reader
            // has gone. It used to fall to four or eight Pages by round two.
            XCTAssertGreaterThanOrEqual(
                bench.count, BookDeskRound.reserveCapacity * 3 / 2,
                "round \(round) came back with \(bench.count): \(counts)"
            )
            XCTAssertLessThanOrEqual(counts.values.max() ?? 0, BookCurator.reserveSiblingsPerType, "round \(round): \(counts)")
            XCTAssertGreaterThanOrEqual(counts.count, 4, "round \(round) was too narrow: \(counts)")
            let repeats = bench.filter { shown.contains($0.curatorContentNoveltyKey) }
            XCTAssertTrue(
                repeats.isEmpty,
                "round \(round) offered something the folio had already shown: \(repeats.map { "\($0.type.rawValue)/\($0.sourceID)" })"
            )
            for page in bench { shown.insert(page.curatorContentNoveltyKey) }
            history = CuratorVarietyGovernor.recordingServed(
                keys: bench.flatMap(\.curatorServedHistoryKeys), into: history, now: now
            )
        }
    }

    func testExploreDeeperStaysFullForAYoungReaderToo() {
        let run = pulls(count: 30, keptPageCount: 0)
        XCTAssertEqual(run.map(\.count), Array(repeating: BookDeskRound.reserveCapacity, count: 30))
    }

    // MARK: The cupboard

    private func cupboard(at hour: Int, history: [String: SurfaceHistoryRecord] = [:]) -> [SurfacePage] {
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: hour))!
        return BookEvergreenPlayReserve.pages(now: now, history: history)
    }

    func testTheCupboardDoesNotHandOverTheSameBelievingAndJournalEveryTime() {
        let believings = Set([6, 8, 10, 12, 14, 16].compactMap { hour in
            cupboard(at: hour).first { $0.type == .affirmations }?.payload.metadata["affirmationID"]
        })
        let journals = Set([6, 8, 10, 12, 14, 16].compactMap { hour in
            cupboard(at: hour).first { $0.type == .diary }?.payload.metadata["journalPromptID"]
        })
        XCTAssertGreaterThan(believings.count, 3, "\(believings)")
        XCTAssertGreaterThan(journals.count, 3, "\(journals)")
    }

    func testTheCupboardsOrderMovesWithTheSlot() {
        let orders = Set([6, 8, 10, 12].map { hour in cupboard(at: hour).map(\.type.rawValue).joined(separator: ",") })
        XCTAssertGreaterThan(orders.count, 1)
    }

    func testTheCupboardRestsWhatItServed() {
        let pages = cupboard(at: 9)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 9))!
        let served = CuratorVarietyGovernor.recordingServed(
            keys: pages.flatMap(\.curatorServedHistoryKeys), into: [:], now: now
        )
        let after = BookEvergreenPlayReserve.pages(now: now.addingTimeInterval(3_600), history: served)
        let servedContent = Set(pages.map(\.curatorContentNoveltyKey))
        XCTAssertTrue(after.allSatisfy { !servedContent.contains($0.curatorContentNoveltyKey) })
    }

    func testCupboardBelievingsAndJournalPromptsStillWorkAsPages() throws {
        let pages = cupboard(at: 9)
        let believing = try XCTUnwrap(pages.first { $0.type == .affirmations })
        XCTAssertFalse(believing.prompt.isEmpty)
        XCTAssertNotNil(believing.payload.metadata["countersigns"]?.nonEmpty)
        XCTAssertEqual(believing.payload.metadata["surfaceLabel"], "Believing")
        let journal = try XCTUnwrap(pages.first { $0.type == .diary })
        XCTAssertFalse(journal.prompt.contains("{"))
        XCTAssertNotNil(journal.payload.metadata["journalPromptID"]?.nonEmpty)
    }
}
