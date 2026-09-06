import XCTest
@testable import InsideCoverCore

/// The accumulated body, as a leaf of the Margins Atlas.
///
/// One Notice is a clever remark. The reason this page exists is that a body of
/// laws *with its erasures* is a different object — so the checks here are
/// mostly about what it refuses to become: a dashboard, a wall of everything,
/// or a tidy record with the mistakes swept out.
final class GrimoireFolioTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// A Book that has held some rules, is betting on one, and has been wrong.
    private func livedLedger() -> GrimoireLedger {
        var ledger = GrimoireLedger()
        let hour = LoomFeatureRef(
            id: "hour:night", domain: "hour", label: "night",
            conditionClause: "it was night", outcomeClause: "you came at night",
            role: .conditionOnly, rank: 15
        )
        var observations: [LoomObservation] = []
        for day in 4_000..<4_160 {
            var features: [LoomFeatureRef] = [hour]
            // Three separate rules, each on its own rhythm.
            if day % 4 == 0 {
                features.append(condition("weather:rain", "weather", "raining"))
                if day % 20 != 0 { features.append(outcome("word:lantern", "word", "lantern")) }
            }
            if day % 5 == 0 {
                features.append(condition("place:harbour", "place", "the harbour"))
                if day % 25 != 0 { features.append(outcome("kept:photo", "media", "kept a photograph")) }
            }
            if day % 7 == 0 {
                features.append(condition("weather:fog", "weather", "foggy"))
                if day % 21 != 0 { features.append(outcome("word:quiet", "word", "quiet")) }
            }
            // A fourth rule the Book never gets round to saying, so there is
            // something genuinely half-formed for it to be chewing on.
            if day % 6 == 0 {
                features.append(condition("place:kitchen", "place", "the kitchen"))
                if day % 24 != 0 { features.append(outcome("word:bread", "word", "bread")) }
            }
            observations.append(LoomObservation(
                id: "day-\(day)", day: day,
                occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "page-\(day)", evidenceLine: ""
            ))
        }
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 4_161, calendar: calendar),
                                      budget: 1_500, calendar: calendar)
            passes += 1
            if report.finished || passes > 120 { break }
        }
        // Only some get said. A real Book speaks a handful and keeps chewing on
        // the rest, so a fixture that speaks everything hides the whole
        // turning-over half of the page.
        let now = GrimoireDay.date(for: 4_161, calendar: calendar)
        for (condition, outcome) in [
            ("weather:fog", "word:quiet"),
            ("place:harbour", "kept:photo"),
            ("weather:rain", "word:lantern")
        ] {
            guard let id = rowID(condition, outcome, in: ledger) else { continue }
            ledger.markSpoken(id, now: now, calendar: calendar)
        }
        // States assigned by *claim*, not by position in a sorted key list, so
        // the fixture keeps meaning the same thing when the engine changes what
        // it finds. Two held, one still a bet, and the rain rule left for the
        // crossing-out.
        promote("weather:fog", "word:quiet", to: .standing, in: &ledger)
        promote("place:harbour", "kept:photo", to: .standing, in: &ledger)
        return ledger
    }

    /// The row for one claim, whatever shape found it first.
    private func rowID(_ condition: String, _ outcome: String, in ledger: GrimoireLedger) -> String? {
        ledger.rows.values
            .filter { $0.conditionID == condition && $0.outcomeID == outcome }
            .sorted { $0.id < $1.id }
            .first?.id
    }

    private func promote(
        _ condition: String, _ outcome: String,
        to state: GrimoireClaimState, in ledger: inout GrimoireLedger
    ) {
        guard let id = rowID(condition, outcome, in: ledger) else { return }
        ledger.rows[id]?.state = state
    }

    private func condition(_ id: String, _ domain: String, _ label: String) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: label,
            conditionClause: label == "the harbour" ? "you were at the harbour" : "it was \(label)",
            outcomeClause: "it was \(label)",
            role: .conditionOnly, rank: 10
        )
    }

    private func outcome(_ id: String, _ domain: String, _ label: String) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: label,
            conditionClause: "you had \(label)",
            outcomeClause: label.hasPrefix("kept") ? "you \(label)" : "you wrote the word \(label)",
            role: .outcomeOnly, provenance: .readerAuthored, rank: 70
        )
    }

    /// Cross out every reading of one claim, the way the sweep would.
    private func crossOut(
        _ condition: String, _ outcome: String, in ledger: inout GrimoireLedger
    ) {
        let now = GrimoireDay.date(for: 4_162, calendar: calendar)
        for row in ledger.rows.values
        where row.conditionID == condition && row.outcomeID == outcome {
            ledger.rows[row.id]?.state = .crossedOut
            ledger.rows[row.id]?.revisions.append(GrimoireRevision(
                at: now, from: .spoken, to: .crossedOut, because: "it stopped happening"
            ))
        }
    }

    private func crossOutEverything(in ledger: inout GrimoireLedger) {
        let now = GrimoireDay.date(for: 4_162, calendar: calendar)
        for row in ledger.rows.values {
            ledger.rows[row.id]?.state = .crossedOut
            ledger.rows[row.id]?.revisions.append(GrimoireRevision(
                at: now, from: .spoken, to: .crossedOut, because: "it stopped happening"
            ))
        }
    }

    // MARK: What it is

    func testTheThreeSectionsArriveInOrder() throws {
        var ledger = livedLedger()
        // Cross out one of the *held* rules, so the bet survives and all three
        // sections are on the page at once.
        crossOut("weather:fog", "word:quiet", in: &ledger)
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: ledger, calendar: calendar))
        print("\n────────────────────────────────────────\n\(body)\n────────────────────────────────────────\n")

        // What it holds, then what it is risking, then what it got wrong. A
        // grimoire that led with its mistakes would read as an apology; one
        // that buried them would read as a dashboard.
        let held = try XCTUnwrap(body.range(of: "Sure of these:"))
        let bet = try XCTUnwrap(body.range(of: "Still betting on this one:"))
        let crossed = try XCTUnwrap(body.range(of: "Wrong about this one:"))
        XCTAssertTrue(held.lowerBound < bet.lowerBound)
        XCTAssertTrue(bet.lowerBound < crossed.lowerBound)

        // And no claim is both held and taken back on the same page.
        let bullets = body.split(separator: "\n").filter { $0.hasPrefix("• ") }
        let claims = bullets.map { $0.split(separator: ".").first.map(String.init) ?? "" }
        XCTAssertEqual(Set(claims).count, claims.count, "the folio said the same thing twice: \(bullets)")
    }

    func testAYoungBookHasNoFolioYet() {
        XCTAssertNil(GrimoireVoice.folio(ledger: GrimoireLedger()))
    }

    func testTheFolioOpensBySayingTheKnowledgeWasEarned() throws {
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: livedLedger()))
        XCTAssertTrue(body.hasPrefix("Things I worked out about you."), body)
        XCTAssertTrue(body.contains("Nobody told me any of it"), body)
    }

    func testItShowsAHandfulAndCountsTheRest() throws {
        let ledger = livedLedger()
        let standing = ledger.rows.values.filter { $0.state == .standing }.count
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: ledger))
        let listed = body.split(separator: "\n").filter { $0.hasPrefix("• ") }.count
        // A page that lists forty laws is a database.
        XCTAssertLessThanOrEqual(listed, GrimoireVoice.folioStandingShown + 1 + GrimoireVoice.folioCrossedShown)
        if standing > GrimoireVoice.folioStandingShown {
            XCTAssertTrue(body.contains("tucked behind"), body)
        }
    }

    func testEveryLawCarriesItsCountAndWhenItStarted() throws {
        let ledger = livedLedger()
        let row = try XCTUnwrap(ledger.rows.values.first { $0.state == .standing })
        let line = try XCTUnwrap(GrimoireVoice.law(row: row, ledger: ledger, calendar: calendar))
        XCTAssertTrue(line.contains("times out of"), line)
        XCTAssertTrue(line.contains("sure since"), line)
    }

    /// The point of the page: a body of laws *with its erasures*.
    func testTheCrossingsOutAreKeptAndNeverTheSectionThatGetsDropped() throws {
        var ledger = livedLedger()
        crossOut("weather:rain", "word:lantern", in: &ledger)
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: ledger, calendar: calendar))
        XCTAssertTrue(body.contains("Wrong about this one:"), body)
        XCTAssertTrue(body.contains("it stopped happening"), body)
        XCTAssertTrue(body.contains("The pencil is fond of them"), body)
    }

    func testABookThatHasOnlyEverBeenWrongStillHasAFolio() throws {
        var ledger = livedLedger()
        crossOutEverything(in: &ledger)
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: ledger, calendar: calendar))
        XCTAssertTrue(body.contains("Wrong about this one:"), body)
        XCTAssertFalse(body.contains("Sure of these:"), body)
    }

    func testTheBetCarriesThePromiseThatWouldBreakIt() throws {
        let ledger = livedLedger()
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: ledger, calendar: calendar))
        XCTAssertTrue(body.contains("Still betting on this one:"), body)
        XCTAssertTrue(
            body.contains("gets crossed out")
                || body.contains("the pencil comes out")
                || body.contains("I was wrong"),
            body
        )
    }

    /// A rule the Book is still betting on has not been sure of anything, and
    /// a page that says both about the same claim contradicts itself.
    func testABetIsNeverDescribedAsSomethingTheBookIsSureOf() throws {
        let ledger = livedLedger()
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: ledger, calendar: calendar))
        let lines = body.split(separator: "\n").map(String.init)
        let betIndex = try XCTUnwrap(lines.firstIndex(of: "Still betting on this one:"))
        let bet = lines[betIndex + 1]
        XCTAssertTrue(bet.contains("counting since"), bet)
        XCTAssertFalse(bet.contains("sure since"), bet)
    }

    /// Until now the Book kept every half-formed thing to itself and only ever
    /// showed conclusions, so convictions appeared out of nowhere. This is the
    /// working-out being visible.
    func testTheBookShowsWhatItIsStillChewingOn() throws {
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: livedLedger(), calendar: calendar))
        XCTAssertTrue(body.contains("Turning this one over:"), body)
        XCTAssertTrue(body.contains("Not enough for me yet"), body)
        // How often, not how long: a day count off `firstObservedAt` reads as
        // "258 days now", which sounds like staring at a wall.
        XCTAssertFalse(body.contains("days now"), body)
    }

    func testAHalfFormedThingIsNeverDescribedAsSettled() throws {
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: livedLedger(), calendar: calendar))
        let lines = body.split(separator: "\n").map(String.init)
        let index = try XCTUnwrap(lines.firstIndex(of: "Turning this one over:"))
        let chewing = lines[index + 1]
        XCTAssertFalse(chewing.contains("sure since"), chewing)
        XCTAssertFalse(chewing.contains("counting since"), chewing)
    }

    func testItIsProseAndNeverADashboard() throws {
        let body = try XCTUnwrap(GrimoireVoice.folio(ledger: livedLedger(), calendar: calendar))
        for word in ["data", "correlat", "statistic", "metric", "score", "%", "confidence"] {
            XCTAssertFalse(body.lowercased().contains(word), "clerical voice “\(word)”: \(body)")
        }
        for hedge in ["may ", "perhaps", "might ", "tends to", "seems"] {
            XCTAssertFalse(body.lowercased().contains(hedge), "hedged with “\(hedge)”: \(body)")
        }
    }

    // MARK: The quiet leaf

    /// The sweep genuinely runs on idle, so this is a receipt rather than a
    /// flourish: proof the room carried on being lived in.
    func testTheBookLeavesAMarkOfWhatItDidWhileNobodyWasThere() throws {
        var ledger = livedLedger()
        ledger.lastTending = GrimoireTendingMark(
            at: Date(), found: 2, crossedOut: 1,
            line: "The pencil got at the harbour one and crossed it out",
            shownAt: nil
        )
        let residue = try XCTUnwrap(ledger.quietLeafResidue)
        print("\n── quiet leaf ──\n\(residue)\n────────────────\n")
        XCTAssertTrue(residue.contains("while you were out"), residue)
        // The absence is the timing, never the subject: a mark that opens on
        // the reader leaving makes it something to answer for.
        XCTAssertFalse(residue.hasPrefix("While you"), residue)
        XCTAssertFalse(residue.hasPrefix("You were"), residue)
        // And it never counts the days or asks for anything.
        for scold in ["days since", "haven't", "have not been", "come back", "missed you"] {
            XCTAssertFalse(residue.lowercased().contains(scold), residue)
        }
    }

    func testTheMarkIsLeftOnceAndThenLetGo() throws {
        var ledger = livedLedger()
        ledger.lastTending = GrimoireTendingMark(
            at: Date(), found: 1, crossedOut: 0, line: nil, shownAt: nil
        )
        XCTAssertNotNil(ledger.quietLeafResidue)
        ledger.markResidueShown()
        // A residue that repeats stops being evidence that anything happened.
        XCTAssertNil(ledger.quietLeafResidue)
    }

    func testAQuietTendLeavesNoMark() {
        var ledger = livedLedger()
        ledger.lastTending = GrimoireTendingMark(
            at: Date(), found: 0, crossedOut: 0, line: nil, shownAt: nil
        )
        XCTAssertNil(ledger.quietLeafResidue, "nothing happened, so there is nothing to show")
        ledger.lastTending = nil
        XCTAssertNil(ledger.quietLeafResidue)
    }

    func testTakingSomethingBackOutranksFindingSomething() throws {
        let ledger = livedLedger()
        let crossed = try XCTUnwrap(ledger.rows.values.first { $0.outcomeID != nil })
        let line = try XCTUnwrap(GrimoireVoice.tendingLine(
            found: [crossed.id], crossedOut: [crossed.id], in: ledger
        ))
        // The Book owing a correction is more interesting than the Book being
        // pleased with itself.
        XCTAssertTrue(line.contains("crossed it out"), line)
    }

    /// Only settled rules are offered to an answer. A half-formed thing is not
    /// something to answer a reader's question with.
    func testOnlyWhatTheBookIsSureOfIsOfferedToAnAnswer() throws {
        var ledger = livedLedger()
        let lines = ledger.standingLawLines(calendar: calendar)
        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(lines.count, ledger.rows.values.filter { $0.state == .standing }.count)

        // Nothing it is still chewing on, and nothing it has taken back.
        crossOut("weather:fog", "word:quiet", in: &ledger)
        let after = ledger.standingLawLines(calendar: calendar)
        XCTAssertLessThan(after.count, lines.count)
        for line in after { XCTAssertTrue(line.contains("sure since"), line) }
    }

    // MARK: Where it lives

    private func atlasPages(_ ledger: GrimoireLedger) -> [SurfacePage] {
        var inputs = BookSourceInputs.empty
        inputs.grimoire = ledger
        let today = BookDay(id: "today", date: Date(), pages: [])
        return MarginsAtlasPageSourceAdapter().candidates(
            for: today, context: CuratorContext.make(for: today), inputs: inputs, now: Date()
        )
    }

    func testTheLawsArriveAsALeafOfTheAtlasAndNotANewPlace() throws {
        let page = try XCTUnwrap(
            atlasPages(livedLedger()).first { $0.payload.metadata["grimoireFolio"] == "true" }
        )
        // Same Page type, same source, same anchor as the maps it sits beside.
        XCTAssertEqual(page.type, .marginsAtlas)
        XCTAssertEqual(page.payload.metadata["graphVariant"], MarginsAtlasVariant.laws.rawValue)
        XCTAssertEqual(page.payload.headline, "The Rules I Worked Out")
        // Prose, not dots and lines.
        XCTAssertEqual(page.renderStyle, .loreLetter)
        XCTAssertNil(page.payload.metadata["graphEdges"])
    }

    func testTheLawsOutrankTheDrawings() throws {
        let pages = atlasPages(livedLedger())
        let laws = try XCTUnwrap(pages.first { $0.payload.metadata["grimoireFolio"] == "true" })
        for map in pages where map.payload.metadata["grimoireFolio"] != "true" {
            XCTAssertGreaterThan(laws.score, map.score, "a drawing outranked a held rule")
        }
    }

    /// Correcting a reading is a conversation about one claim. The page that
    /// lists them all must not offer to correct all of them at once.
    func testTheFolioDoesNotOfferToCorrectEverythingAtOnce() throws {
        let page = try XCTUnwrap(
            atlasPages(livedLedger()).first { $0.payload.metadata["grimoireFolio"] == "true" }
        )
        XCTAssertNil(page.payload.metadata["observationKey"])
        XCTAssertNil(BookObservationLedger.key(for: page))
    }

    func testNoFolioLeafUntilThereIsSomethingToShow() {
        XCTAssertFalse(
            atlasPages(GrimoireLedger()).contains { $0.payload.metadata["grimoireFolio"] == "true" }
        )
    }
}
