import XCTest
@testable import InsideCoverCore

/// The sealed margin's bets on the days ahead: tomorrow (one of the Cast takes
/// the other side), against the Curse, and dares. Each is settled by the same
/// day-by-day facts the grimoire counts.
final class BookBetsTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(_ day: Int) -> Date {
        GrimoireDay.date(for: day, calendar: calendar).addingTimeInterval(12 * 3_600)
    }

    private func word(_ word: String) -> LoomFeatureRef {
        LoomFeatureRef(
            id: "word:\(word)", domain: "word", label: "the word “\(word)”",
            conditionClause: "you used the word “\(word)”", outcomeClause: "you used the word “\(word)”",
            role: .either, provenance: .readerAuthored, rank: 60
        )
    }

    private let wrote = LoomFeatureRef(
        id: "writing:kept", domain: "writing", label: "days you wrote",
        conditionClause: "you wrote something", outcomeClause: "you wrote something",
        role: .either, provenance: .readerAuthored, rank: 68
    )

    private func ledger(_ days: [Int: [LoomFeatureRef]]) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.ingest(days.keys.sorted().map { day in
            LoomObservation(
                id: "d\(day)", day: day, occurredAt: date(day),
                features: days[day] ?? [], evidencePageID: "p\(day)", evidenceLine: ""
            )
        })
        return ledger
    }

    private func everyLine(of wager: BookWager) -> [String] {
        [wager.prediction, wager.basisLine]
    }

    // MARK: Against the Curse

    func testTheCurseBetsOnSomethingThatWentQuiet() throws {
        var days: [Int: [LoomFeatureRef]] = [:]
        for day in stride(from: 0, through: 40, by: 3) { days[day] = [word("lantern"), wrote] }
        for day in 41...70 { days[day] = [wrote] }
        let ledger = ledger(days)
        let bet = try XCTUnwrap(BookBets.curseBet(grimoire: ledger, now: date(70), calendar: calendar))
        XCTAssertEqual(bet.bet?.kind, .curse)
        XCTAssertEqual(bet.bet?.featureID, "word:lantern")
        XCTAssertTrue(bet.prediction.hasPrefix("The last time you used the word “lantern” was 31 days ago."), bet.prediction)
        XCTAssertTrue(bet.prediction.contains("I bet the Curse is wrong."), bet.prediction)
    }

    func testTheCurseNeverBetsOnSomethingThatIsStillHappening() {
        var days: [Int: [LoomFeatureRef]] = [:]
        for day in stride(from: 0, through: 70, by: 3) { days[day] = [word("lantern"), wrote] }
        XCTAssertNil(BookBets.curseBet(grimoire: ledger(days), now: date(70), calendar: calendar))
    }

    // MARK: Dares

    func testTheBookDaresYouToGoWithoutAWordYouKeepUsing() throws {
        var days: [Int: [LoomFeatureRef]] = [:]
        for day in 0..<14 { days[day] = day % 4 == 3 ? [wrote] : [word("honestly"), wrote] }
        let bet = try XCTUnwrap(BookBets.dare(grimoire: ledger(days), now: date(13), calendar: calendar))
        XCTAssertEqual(bet.bet?.kind, .dare)
        XCTAssertEqual(bet.bet?.opponent, "you")
        XCTAssertTrue(bet.prediction.contains("the word “honestly”"), bet.prediction)
        XCTAssertTrue(bet.prediction.hasSuffix("Go on. Prove me wrong."), bet.prediction)
    }

    func testATenderWordIsNeverDared() {
        var days: [Int: [LoomFeatureRef]] = [:]
        for day in 0..<14 { days[day] = [word("grief"), wrote] }
        XCTAssertNil(BookBets.dare(grimoire: ledger(days), now: date(13), calendar: calendar))
    }

    // MARK: Tomorrow

    func testTomorrowsBetIsOnAKindOfDayTheBookAlreadyKnows() throws {
        let slice = GrimoireSlice(days: [], calendar: calendar)
        let ink = LoomFeatureRef(
            id: "ink:heavy", domain: "ink", label: "lots of ink",
            conditionClause: "you used lots of my ink", outcomeClause: "you used lots of my ink",
            role: .outcomeOnly, provenance: .readerAuthored, rank: 69
        )
        var days: [Int: [LoomFeatureRef]] = [:]
        for day in 0..<200 {
            var features = DayShapeProjector.temporalFeatures(at: date(day), in: slice)
            let weekday = calendar.component(.weekday, from: date(day))
            if weekday == 1 || weekday == 7 || day % 13 == 0 { features.append(ink) }
            days[day] = features
        }
        var ledger = ledger(days)
        for _ in 0..<80 {
            if ledger.sweep(now: date(200), budget: 1_500, calendar: calendar).finished { break }
        }
        let rowID = try XCTUnwrap(ledger.rows.values.first {
            $0.shape == .conditional && $0.conditionID == "week:the weekend" && $0.outcomeID == "ink:heavy"
        }?.id)
        ledger.rows[rowID]?.state = .standing

        // A Friday, so tomorrow is the weekend.
        let friday = try XCTUnwrap((200..<207).first { calendar.component(.weekday, from: date($0)) == 6 })
        let bet = try XCTUnwrap(BookBets.tomorrowBet(grimoire: ledger, now: date(friday), calendar: calendar))
        XCTAssertEqual(bet.bet?.kind, .tomorrow)
        XCTAssertEqual(bet.bet?.fromDay, friday + 1)
        XCTAssertTrue(bet.prediction.hasPrefix("Tomorrow's one of your weekends. On days like that, you used lots of my ink,"), bet.prediction)
        XCTAssertTrue(BookBets.takers.contains { bet.prediction.contains("\($0.name) bet me \($0.stake)") }, bet.prediction)

        // And on a Tuesday there's nothing to bet on.
        let monday = try XCTUnwrap((200..<207).first { calendar.component(.weekday, from: date($0)) == 2 })
        XCTAssertNil(BookBets.tomorrowBet(grimoire: ledger, now: date(monday), calendar: calendar))
    }

    // MARK: Settling

    private func sealed(_ kind: FeatureBet.Kind, from: Int, until: Int, needed: Int? = nil) -> BookWager {
        BookWager(
            id: "b", subjectID: "word:lantern", subjectName: "the word “lantern”", kind: .pattern,
            prediction: "p", sealedAt: date(from - 1), opensAt: date(until + 1), status: .sealed,
            basisSignalID: "b", basisLine: "b",
            bet: FeatureBet(
                kind: kind, featureID: "word:lantern", fromDay: from, untilDay: until,
                opponent: kind == .tomorrow ? "Wicker Eddies" : (kind == .curse ? "the Curse" : "you"),
                stake: kind == .tomorrow ? "a button" : nil,
                clause: "you used the word “lantern”", writingDaysNeeded: needed
            )
        )
    }

    func testABetIsWonTheMomentItHappens() {
        let wager = sealed(.curse, from: 10, until: 17)
        let opened = BookBets.resolved(wager, featureDays: [12: ["word:lantern"]], now: date(12), calendar: calendar)
        XCTAssertEqual(opened.status, .right)
        XCTAssertEqual(opened.resolutionLine, "You used the word “lantern” again. The Curse lost this one, and I watched it lose.")
    }

    func testABetIsOnlyLostOnceItsDaysAreOver() {
        let wager = sealed(.tomorrow, from: 10, until: 10)
        XCTAssertTrue(BookBets.resolved(wager, featureDays: [:], now: date(10), calendar: calendar).isSealed,
                      "tomorrow isn't over yet")
        let lost = BookBets.resolved(wager, featureDays: [:], now: date(11), calendar: calendar)
        XCTAssertEqual(lost.status, .wrong)
        XCTAssertEqual(lost.resolutionLine, "It didn't happen. Wicker Eddies won a button off me and hasn't stopped grinning.")
    }

    func testADareCountsOnlyTheDaysYouWrote() {
        let wager = sealed(.dare, from: 10, until: 31, needed: 3)
        // Three writing days without the word, the last of them today: not over yet.
        var days: [Int: Set<String>] = [10: ["writing:kept"], 13: ["writing:kept"], 15: ["writing:kept"]]
        XCTAssertTrue(BookBets.resolved(wager, featureDays: days, now: date(15), calendar: calendar).isSealed)
        let won = BookBets.resolved(wager, featureDays: days, now: date(16), calendar: calendar)
        XCTAssertEqual(won.status, .wrong, "the reader won the dare")
        XCTAssertEqual(won.resolutionLine, "Three days of writing and not one “lantern”. You won. I lost, and I'm glad. The word's sulking.")

        days[13]?.insert("word:lantern")
        let lost = BookBets.resolved(wager, featureDays: days, now: date(13), calendar: calendar)
        XCTAssertEqual(lost.status, .right)
        XCTAssertEqual(lost.resolutionLine, "You used “lantern” again. I knew you couldn't help it. The word's very pleased with itself.")
    }

    func testADareNobodyWroteForIsADrawThatGoesToTheReader() {
        let wager = sealed(.dare, from: 10, until: 31, needed: 3)
        let draw = BookBets.resolved(wager, featureDays: [12: ["writing:kept"]], now: date(32), calendar: calendar)
        XCTAssertEqual(draw.status, .wrong)
        XCTAssertTrue(draw.resolutionLine?.hasSuffix("A draw goes to you.") == true, draw.resolutionLine ?? "")
    }

    // MARK: Turn-taking

    func testOnlyOneBetIsSealedAtATimeAndTheyRest() {
        var days: [Int: [LoomFeatureRef]] = [:]
        for day in stride(from: 0, through: 40, by: 3) { days[day] = [word("lantern"), wrote] }
        for day in 41...70 { days[day] = [wrote] }
        let ledger = ledger(days)
        let first = BookBets.mint(grimoire: ledger, existing: [], now: date(70), calendar: calendar)
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(BookBets.mint(grimoire: ledger, existing: first, now: date(71), calendar: calendar).isEmpty,
                      "a bet is still sealed")
        var settled = first
        settled[0].status = .wrong
        settled[0].resolvedAt = date(71)
        XCTAssertTrue(BookBets.mint(grimoire: ledger, existing: settled, now: date(71), calendar: calendar).isEmpty,
                      "the Book rests between bets")
    }

    /// A bet is something the Book says. It answers to the Book's voice rules.
    func testEveryBetSpeaksInTheBooksVoice() {
        let lines = [
            BookBets.settledLine(sealed(.tomorrow, from: 1, until: 1).bet!, bookWon: true),
            BookBets.settledLine(sealed(.tomorrow, from: 1, until: 1).bet!, bookWon: false),
            BookBets.settledLine(sealed(.curse, from: 1, until: 7).bet!, bookWon: true),
            BookBets.settledLine(sealed(.curse, from: 1, until: 7).bet!, bookWon: false),
            BookBets.settledLine(sealed(.dare, from: 1, until: 21, needed: 3).bet!, bookWon: true),
            BookBets.settledLine(sealed(.dare, from: 1, until: 21, needed: 3).bet!, bookWon: false)
        ]
        for line in lines {
            XCTAssertFalse(line.lowercased().contains("the book"), line)
            for long in ["I am ", "I will ", "do not", "did not", "It is ", "is not", "cannot"] {
                XCTAssertFalse(line.contains(long), "“\(long)” wants contracting: \(line)")
            }
        }
    }
}
