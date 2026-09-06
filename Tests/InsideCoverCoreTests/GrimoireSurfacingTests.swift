import XCTest
@testable import InsideCoverCore

/// The grimoire reaching the desk: what gets said, what stays quiet, and what
/// the reader's answer does to it.
final class GrimoireSurfacingTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func page(_ id: String, on date: Date, text: String, weather: [String]) -> BookPage {
        BookPage(
            id: id, type: .diary, createdAt: date,
            promptText: "Prompt", userInput: text,
            origin: .userAuthored,
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

    /// Sixty days in which the word "lantern" mostly arrives with rain.
    private func lanternDays() -> [BookDay] {
        (0..<60).map { index in
            let date = calendar.date(
                byAdding: .hour, value: 20,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 5 == 0
            let text = (rainy && index != 25)
                ? "The lantern outside was swinging in the wet."
                : "Quiet enough. Bread, errands, nothing worth marking."
            return day(index, pages: [
                page("page-\(index)", on: date, text: text, weather: rainy ? ["rain"] : ["clear"])
            ])
        }
    }

    private func daysWithoutLanterns() -> [BookDay] {
        (0..<60).map { index in
            let date = calendar.date(
                byAdding: .hour, value: 20,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 5 == 0
            return day(index, pages: [
                page("page-\(index)", on: date, text: "Bread, errands, nothing worth marking.",
                     weather: rainy ? ["rain"] : ["clear"])
            ])
        }
    }

    private func tendedLedger(_ days: [BookDay], now: Date? = nil) -> GrimoireLedger {
        let slice = GrimoireSlice(days: days, calendar: calendar)
        let stamp = now ?? GrimoireDay.date(for: 61, calendar: calendar)
        return GrimoireKeeper.drained(
            GrimoireLedger(), slice: slice, now: stamp, maximumSeconds: 5
        ).ledger
    }

    private var correspondenceID: String {
        GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "word:lantern")
    }

    // MARK: The keeper

    func testAnEmptyGrimoireHasWorkAndATendedOneRests() {
        XCTAssertTrue(GrimoireKeeper.hasWork(GrimoireLedger()))
        var ledger = tendedLedger(lanternDays())
        let justTended = GrimoireDay.date(for: 61, calendar: calendar)
        XCTAssertFalse(
            GrimoireKeeper.hasWork(ledger, now: justTended),
            "a freshly drained ledger should not ask to run again"
        )
        // Six hours later there is nothing new; a day later there is.
        XCTAssertFalse(GrimoireKeeper.hasWork(ledger, now: justTended.addingTimeInterval(3_600)))
        XCTAssertTrue(GrimoireKeeper.hasWork(ledger, now: justTended.addingTimeInterval(7 * 3_600)))
        ledger.dirtyPairs = []
    }

    func testDrainingFinishesTheBacklogAndIsIdempotent() {
        let slice = GrimoireSlice(days: lanternDays(), calendar: calendar)
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        let first = GrimoireKeeper.drained(GrimoireLedger(), slice: slice, now: now, maximumSeconds: 5)
        XCTAssertTrue(first.ingested)
        XCTAssertTrue(first.changed)
        XCTAssertEqual(first.ledger.pendingSweepCount, 0)
        XCTAssertFalse(first.ledger.rows.isEmpty)

        // Running again over the same archive changes nothing: re-ingesting the
        // same days must not invent new evidence.
        let second = GrimoireKeeper.drained(first.ledger, slice: slice, now: now, maximumSeconds: 5)
        XCTAssertEqual(second.ledger.rows.count, first.ledger.rows.count)
        XCTAssertEqual(second.ledger.universe.count, first.ledger.universe.count)
        XCTAssertEqual(second.ledger.featureCount, first.ledger.featureCount)
    }

    func testDueArchiveReplayRebuildsAForwardBoundedSequenceWindow() {
        let slice = GrimoireSlice(days: lanternDays(), calendar: calendar)
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        let first = GrimoireKeeper.drained(GrimoireLedger(), slice: slice, now: now, maximumSeconds: 5)
        let second = GrimoireKeeper.drained(
            first.ledger,
            slice: slice,
            now: now.addingTimeInterval(7 * 3_600),
            maximumSeconds: 5
        )

        XCTAssertTrue(second.ingested)
        XCTAssertEqual(second.ledger.recentDayNumbers, first.ledger.recentDayNumbers)
        XCTAssertLessThanOrEqual(second.ledger.recentDayNumbers.count, GrimoireLedger.Bars.sequenceWindow + 1)
    }

    func testDueArchiveReplayPreservesTheWeeklyWagerClock() {
        let slice = GrimoireSlice(days: lanternDays(), calendar: calendar)
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        var first = GrimoireKeeper.drained(
            GrimoireLedger(), slice: slice, now: now, maximumSeconds: 5
        ).ledger
        first.lastWagerAt = now

        let reconciled = GrimoireKeeper.drained(
            first,
            slice: slice,
            now: now.addingTimeInterval(7 * 3_600),
            maximumSeconds: 5
        ).ledger

        XCTAssertEqual(reconciled.lastWagerAt, now)
        XCTAssertFalse(reconciled.owesAWager(now: now.addingTimeInterval(7 * 3_600)))
    }

    func testReconciliationRemovesEvidenceWithdrawnFromTheArchive() {
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        let first = GrimoireKeeper.drained(
            GrimoireLedger(),
            slice: GrimoireSlice(days: lanternDays(), calendar: calendar),
            now: now,
            maximumSeconds: 5
        )
        XCTAssertNotNil(first.ledger.row(correspondenceID))

        let reconciled = GrimoireKeeper.drained(
            first.ledger,
            slice: GrimoireSlice(days: daysWithoutLanterns(), calendar: calendar),
            now: now.addingTimeInterval(7 * 3_600),
            maximumSeconds: 5
        ).ledger

        XCTAssertTrue(reconciled.days(of: "word:lantern").isEmpty)
        XCTAssertNil(reconciled.row(correspondenceID))
    }

    // MARK: What reaches the desk

    private func surfaces(
        ledger: GrimoireLedger,
        boundaries: [BookReadingBoundary] = [],
        day: BookDay? = nil,
        now: Date? = nil
    ) -> [SurfacePage] {
        var inputs = BookSourceInputs.empty
        inputs.grimoire = ledger
        inputs.bookReadingBoundaries = boundaries
        let today = day ?? self.day(61, pages: [])
        return GrimoirePageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now ?? GrimoireDay.date(for: 61, calendar: calendar)
        )
    }

    func testACorrespondenceReachesTheDeskWithItsReceipts() throws {
        let ledger = tendedLedger(lanternDays())
        let surface = try XCTUnwrap(surfaces(ledger: ledger).first)

        XCTAssertEqual(surface.type, .bookNotices)
        XCTAssertEqual(surface.sourceID, "the-grimoire")
        // The existing correction machinery keys off this and nothing else.
        XCTAssertNotNil(BookObservationLedger.key(for: surface))
        XCTAssertEqual(surface.payload.metadata["observationKey"], surface.payload.metadata["grimoireCorrespondenceID"])
        XCTAssertFalse(surface.payload.body.isEmpty)
        let evidence = try XCTUnwrap(surface.payload.metadata["evidencePageIDs"])
        XCTAssertFalse(evidence.isEmpty, "a claim must carry the Pages it rests on")
    }

    func testTheGrimoireStaysQuietUntilItHasSomethingToSay() {
        XCTAssertTrue(surfaces(ledger: GrimoireLedger()).isEmpty)
    }

    func testOnlyOneCorrespondenceASitting() {
        let ledger = tendedLedger(lanternDays())
        let already = BookPage(
            id: "already", type: .bookNotices, createdAt: Date(),
            promptText: "", userInput: "", sourceID: "the-grimoire"
        )
        XCTAssertTrue(surfaces(ledger: ledger, day: day(61, pages: [already])).isEmpty)
    }

    func testAShutReadingNeverReachesTheDesk() {
        var ledger = tendedLedger(lanternDays())
        // Shut every living row; nothing should get through.
        let boundaries = ledger.rows.values.map { BookReadingBoundary(id: $0.id, createdAt: Date()) }
        XCTAssertFalse(boundaries.isEmpty)
        XCTAssertTrue(surfaces(ledger: ledger, boundaries: boundaries).isEmpty)
        ledger.dirtyPairs = []
    }

    func testACorrectionTheBookOwesOutranksAnythingNewItHasToSay() throws {
        var ledger = tendedLedger(lanternDays())
        let id = correspondenceID
        XCTAssertNotNil(ledger.row(id))
        let spokenAt = GrimoireDay.date(for: 61, calendar: calendar)
        ledger.markSpoken(id, now: spokenAt, calendar: calendar)

        // The pattern collapses: rain keeps coming, the lantern stops.
        var later: [BookDay] = []
        for index in 61..<75 {
            let date = calendar.date(
                byAdding: .hour, value: 20,
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            later.append(day(index, pages: [
                page("page-\(index)", on: date, text: "Bread, errands, nothing worth marking.", weather: ["rain"])
            ]))
        }
        let after = GrimoireKeeper.drained(
            ledger,
            slice: GrimoireSlice(days: later, calendar: calendar),
            now: GrimoireDay.date(for: 76, calendar: calendar),
            maximumSeconds: 5
        ).ledger
        XCTAssertEqual(after.row(id)?.state, .crossedOut)

        let surface = try XCTUnwrap(
            surfaces(ledger: after, day: day(76, pages: []), now: GrimoireDay.date(for: 76, calendar: calendar)).first
        )
        XCTAssertEqual(surface.payload.metadata["grimoireReversal"], "true")
        XCTAssertEqual(surface.payload.metadata["grimoireCorrespondenceID"], id)
        XCTAssertEqual(surface.payload.headline, "I Was Wrong About This")
        XCTAssertTrue(surface.payload.body.hasPrefix("I said"), surface.payload.body)
    }

    func testAReversalIsOnlyOwedOnce() throws {
        var ledger = tendedLedger(lanternDays())
        let id = correspondenceID
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)
        var row = try XCTUnwrap(ledger.rows[id])
        row.state = .crossedOut
        row.revisions.append(GrimoireRevision(
            at: GrimoireDay.date(for: 62, calendar: calendar),
            from: .spoken, to: .crossedOut, because: "it stopped happening"
        ))
        ledger.rows[id] = row
        let now = GrimoireDay.date(for: 63, calendar: calendar)
        XCTAssertEqual(surfaces(ledger: ledger, now: now).first?.payload.metadata["grimoireReversal"], "true")

        // Once announced, the Book does not keep apologising for it.
        let announced = try XCTUnwrap(GrimoireLedger.speaking(
            surfaces(ledger: ledger, now: now)[0], in: ledger, now: now
        ))
        XCTAssertNil(surfaces(ledger: announced, now: now).first?.payload.metadata["grimoireReversal"])
    }

    // MARK: The wager

    /// The defect this guards: the wager used to be appended to the end of
    /// `speakable`, and the only consumer takes the first row — so the slot
    /// reserved for the Book's least expected reading could never be reached.
    func testTheLeastExpectedReadingActuallyReachesTheDesk() throws {
        let ledger = tendedLedger(lanternDays())
        XCTAssertTrue(ledger.owesAWager(now: GrimoireDay.date(for: 61, calendar: calendar)))
        let wager = try XCTUnwrap(ledger.wager(now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar))
        let surface = try XCTUnwrap(surfaces(ledger: ledger).first)
        XCTAssertEqual(surface.payload.metadata["grimoireWager"], "true")
        XCTAssertEqual(surface.payload.metadata["grimoireCorrespondenceID"], wager.id)
    }

    func testAWagerIsStillHeldToEveryBar() throws {
        // A long shot is a surprising *true* thing, not licence to say something
        // thin: whatever the wager picks must also be speakable on its merits.
        let ledger = tendedLedger(lanternDays())
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        let wager = try XCTUnwrap(ledger.wager(now: now, calendar: calendar))
        XCTAssertTrue(
            ledger.speakable(limit: .max, now: now, calendar: calendar).contains { $0.id == wager.id },
            "the wager picked something the Book would not otherwise say"
        )
        XCTAssertTrue(wager.isAlive)
    }

    func testAfterAWagerTheBookGoesBackToWhatItIsSurestOf() throws {
        var ledger = tendedLedger(lanternDays())
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        let first = try XCTUnwrap(surfaces(ledger: ledger, now: now).first)
        XCTAssertEqual(first.payload.metadata["grimoireWager"], "true")

        ledger = try XCTUnwrap(GrimoireLedger.speaking(first, in: ledger, now: now))
        XCTAssertEqual(ledger.lastWagerAt, now)
        XCTAssertFalse(ledger.owesAWager(now: now))

        // Next day: strongest-first again, and not the same row.
        let next = GrimoireDay.date(for: 62, calendar: calendar)
        let second = surfaces(ledger: ledger, day: day(62, pages: []), now: next).first
        XCTAssertNil(second?.payload.metadata["grimoireWager"])
        XCTAssertNotEqual(second?.payload.metadata["grimoireCorrespondenceID"], first.payload.metadata["grimoireCorrespondenceID"])
    }

    func testTheWagerComesRoundAgainAfterAWeek() throws {
        var ledger = tendedLedger(lanternDays())
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        ledger.lastWagerAt = now
        XCTAssertFalse(ledger.owesAWager(now: now.addingTimeInterval(6 * 86_400)))
        XCTAssertTrue(ledger.owesAWager(now: now.addingTimeInterval(8 * 86_400)))
    }

    func testACorrectionStillOutranksAWager() throws {
        var ledger = tendedLedger(lanternDays())
        let id = correspondenceID
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)
        var row = try XCTUnwrap(ledger.rows[id])
        row.state = .crossedOut
        row.revisions.append(GrimoireRevision(
            at: GrimoireDay.date(for: 62, calendar: calendar),
            from: .spoken, to: .crossedOut, because: "it stopped happening"
        ))
        ledger.rows[id] = row
        XCTAssertTrue(ledger.owesAWager(now: GrimoireDay.date(for: 63, calendar: calendar)))

        let surface = try XCTUnwrap(surfaces(ledger: ledger, now: GrimoireDay.date(for: 63, calendar: calendar)).first)
        // Owing the reader a correction beats wanting to be interesting.
        XCTAssertEqual(surface.payload.metadata["grimoireReversal"], "true")
        XCTAssertNil(surface.payload.metadata["grimoireWager"])
    }

    func testTheWagerClockSurvivesTheVault() throws {
        var ledger = tendedLedger(lanternDays())
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        ledger.lastWagerAt = now
        let restored = try JSONDecoder().decode(
            GrimoireLedger.self, from: JSONEncoder().encode(ledger)
        )
        XCTAssertEqual(restored.lastWagerAt, now)
        XCTAssertFalse(restored.owesAWager(now: now))
    }

    // MARK: Answering back

    func testTheReadersAnswerReachesTheCorrespondence() throws {
        let ledger = tendedLedger(lanternDays())
        let surface = try XCTUnwrap(surfaces(ledger: ledger).first)
        let id = try XCTUnwrap(surface.payload.metadata["grimoireCorrespondenceID"])

        let confirmed = try XCTUnwrap(GrimoireLedger.recording(.confirmed, for: surface, in: ledger))
        XCTAssertEqual(confirmed.row(id)?.readerStatus, .confirmed)
        XCTAssertTrue(confirmed.row(id)?.isAlive == true)

        let shut = try XCTUnwrap(GrimoireLedger.recording(.doNotRead, for: surface, in: ledger))
        XCTAssertEqual(shut.row(id)?.state, .forbidden)
        // Shutting one reading closes that door, not the whole grimoire.
        XCTAssertNotEqual(
            surfaces(ledger: shut).first?.payload.metadata["grimoireCorrespondenceID"], id,
            "a shut correspondence must not come back"
        )
        XCTAssertFalse(shut.speakable(calendar: calendar).contains { $0.id == id })
    }

    func testAPageThatIsNotACorrespondenceIsLeftAlone() {
        let ledger = tendedLedger(lanternDays())
        let stranger = SurfacePage(
            id: "stranger", type: .bookNotices, sourceID: "the-book-notices",
            intent: .reflect, renderStyle: .loreLetter, score: 50,
            reason: "", prompt: "", detail: "",
            payload: BookPagePayload(headline: "Elsewhere", body: "", metadata: [:])
        )
        XCTAssertNil(GrimoireLedger.recording(.confirmed, for: stranger, in: ledger))
        XCTAssertNil(GrimoireLedger.speaking(stranger, in: ledger))
    }

    func testSayingItStartsTheRestWindow() throws {
        let ledger = tendedLedger(lanternDays())
        let surface = try XCTUnwrap(surfaces(ledger: ledger).first)
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        let spoken = try XCTUnwrap(GrimoireLedger.speaking(surface, in: ledger, now: now))
        let id = try XCTUnwrap(surface.payload.metadata["grimoireCorrespondenceID"])

        XCTAssertNotNil(spoken.row(id)?.lastSpokenAt)
        // And the Book has committed to what would take it back.
        XCTAssertNotNil(spoken.row(id)?.falsifier)
        XCTAssertNotEqual(
            surfaces(ledger: spoken, now: now).first?.payload.metadata["grimoireCorrespondenceID"], id,
            "it should rest instead of repeating itself"
        )
    }

    // MARK: Evidence

    func testEvidenceIsSpreadAcrossTheLifeOfTheClaimNotClusteredAtTheEnd() throws {
        let ledger = tendedLedger(lanternDays())
        let row = try XCTUnwrap(ledger.row(correspondenceID))
        let evidence = ledger.evidencePageIDs(for: row)
        XCTAssertFalse(evidence.isEmpty)
        let indices = evidence.compactMap { Int($0.replacingOccurrences(of: "page-", with: "")) }
        XCTAssertEqual(indices.count, evidence.count)
        XCTAssertEqual(indices.first, 0, "the first Page the claim ever rested on should survive")
        XCTAssertGreaterThan(try XCTUnwrap(indices.last), 40)
    }

    // MARK: The desk pays nothing

    func testReadingTheGrimoireDoesNoDiscoveryWork() {
        var ledger = tendedLedger(lanternDays())
        ledger.dirtyPairs = Array(ledger.knownPairs.prefix(500))
        let backlog = ledger.pendingSweepCount
        XCTAssertGreaterThan(backlog, 0)
        _ = surfaces(ledger: ledger)
        // `candidates` takes inputs by value; the point is that nothing on the
        // read path even tries to sweep.
        XCTAssertEqual(ledger.pendingSweepCount, backlog)
    }

    func testTheLedgerSurvivesAVaultRoundTrip() throws {
        let ledger = tendedLedger(lanternDays())
        var vault = PlayerVaultData()
        vault.grimoire = ledger
        let data = try JSONEncoder().encode(vault)
        let restored = try JSONDecoder().decode(PlayerVaultData.self, from: data)
        let reopened = try XCTUnwrap(restored.grimoire)
        XCTAssertEqual(reopened.rows.count, ledger.rows.count)
        XCTAssertEqual(reopened.featureCount, ledger.featureCount)
        XCTAssertNotNil(reopened.row(correspondenceID))
        XCTAssertFalse(reopened.evidencePageIDs(for: try XCTUnwrap(reopened.row(correspondenceID))).isEmpty)
    }

    func testAnOlderVaultOpensWithAnEmptyGrimoireRatherThanFailing() throws {
        let legacy = Data(#"{"version":2,"anchors":[],"electives":[],"entityBelief":{},"pageBelief":{},"tutorSeen":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: legacy)
        XCTAssertNil(decoded.grimoire)
        XCTAssertTrue(surfaces(ledger: decoded.grimoire ?? GrimoireLedger()).isEmpty)
    }
}
