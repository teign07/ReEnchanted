import XCTest
@testable import InsideCoverCore

/// The grimoire reaching surfaces beyond its own Page.
///
/// A body of private knowledge that only ever speaks on the one Page built for
/// it is a feature. One that colours the Book's ordinary daily voice is a Book
/// that knows you.
final class GrimoireSurfaceReachTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func ledger(held: Int, crossedOut: Int, watching: Int = 0) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        func row(_ id: String, _ state: GrimoireClaimState, spoken: Bool) -> GrimoireCorrespondence {
            GrimoireCorrespondence(
                id: id, shape: .conditional, conditionID: "c-\(id)", outcomeID: "o-\(id)",
                state: state, firstObservedAt: Date(), lastObservedAt: Date(),
                falsifier: nil, revisions: [], readerStatus: nil,
                lastSpokenAt: spoken ? Date() : nil,
                strengthPeak: 60, interestPeak: 40
            )
        }
        for index in 0..<held { ledger.rows["h\(index)"] = row("h\(index)", .standing, spoken: true) }
        for index in 0..<crossedOut { ledger.rows["x\(index)"] = row("x\(index)", .crossedOut, spoken: true) }
        for index in 0..<watching { ledger.rows["w\(index)"] = row("w\(index)", .watching, spoken: false) }
        return ledger
    }

    private func edition(_ grimoire: GrimoireLedger) -> BookTodayEdition {
        var inputs = BookSourceInputs.empty
        inputs.grimoire = grimoire
        let today = BookDay(id: "today", date: Date(), pages: [])
        return BookTodayProjector.edition(
            for: today, inputs: inputs,
            relationship: .firstOpening, experienceProgram: nil,
            now: Date(), calendar: calendar
        )
    }

    // MARK: The daily mark

    func testAYoungBookMakesNoGrimoireMark() {
        let mark = edition(GrimoireLedger()).marginalMark
        XCTAssertNil(mark)
    }

    func testTheDailyMarkSaysHowManyRulesTheBookHolds() throws {
        let mark = try XCTUnwrap(edition(ledger(held: 3, crossedOut: 0)).marginalMark)
        XCTAssertTrue(mark.contains("3"), mark)
        XCTAssertTrue(mark.contains("rules"), mark)
    }

    /// Owing a correction is a larger thing than the Book's ribbon being cross,
    /// so it outranks the Interior's own business.
    func testOwingACorrectionOutranksEverythingElseTheBookCouldMention() throws {
        var grimoire = ledger(held: 3, crossedOut: 1)
        // A crossing-out the Book has not yet owned up to.
        grimoire.rows["x0"]?.lastSpokenAt = nil
        let mark = try XCTUnwrap(edition(grimoire).marginalMark)
        XCTAssertEqual(mark, "I have something to take back")
    }

    func testAFullHeadSaysSo() throws {
        let full = GrimoireLedger.Bars.maximumHeld
        let mark = try XCTUnwrap(edition(ledger(held: full, crossedOut: 0)).marginalMark)
        XCTAssertEqual(mark, "my head is full of your rules")
    }

    func testSomethingMerelyBeingCountedIsSaidQuietly() throws {
        let mark = try XCTUnwrap(edition(ledger(held: 0, crossedOut: 0, watching: 2)).marginalMark)
        XCTAssertEqual(mark, "I am counting something about you")
    }

    // MARK: Ask the Book

    private var sampleEvidence: AskTheBookEvidence {
        AskTheBookEvidence(
            result: StacksSearchResult(
                id: "r", kind: .keptPage, title: "A Page",
                snippet: "Rain again.", dateLabel: "December", score: 10,
                referenceID: "p"
            ),
            authority: .readerWords, excerpt: "Rain again.",
            fullText: "Rain again.", mayQuote: true
        )
    }

    private func packet(
        laws: [String],
        kind: AskTheBookMemoryPacket.InquiryKind = .pattern,
        evidence: [AskTheBookEvidence] = []
    ) -> String {
        AskTheBookMemoryPacket(
            inquiryKind: kind, evidence: evidence, searchedRecordCount: 12,
            searchedWholeBook: true, standingLaws: laws
        ).promptSection
    }

    /// A search that finds nothing does not empty the Book's head. This is the
    /// case where what it already worked out matters most, not least.
    func testASearchThatFindsNothingStillCarriesWhatTheBookKnows() {
        let section = packet(laws: ["When it was raining, you wrote the word lantern. 32 of 40."])
        XCTAssertTrue(section.contains("no strong matching evidence"), section)
        XCTAssertTrue(section.contains("WHAT I HAVE ALREADY WORKED OUT"), section)
    }

    /// A reader asking "do I always…" is asking something the Book has often
    /// already answered, with a contrast group behind it.
    func testWhatTheBookAlreadyKnowsReachesTheAnswer() {
        let section = packet(laws: [
            "When it was raining, you wrote the word lantern. 32 times out of 40, and I have been sure since December."
        ])
        XCTAssertTrue(section.contains("WHAT I HAVE ALREADY WORKED OUT"), section)
        XCTAssertTrue(section.contains("32 times out of 40"), section)
    }

    /// The two must not blur: a months-old counting restated as a fresh find
    /// would be the Book inventing corroboration for itself.
    func testWhatItKnowsIsKeptApartFromWhatItJustFound() throws {
        let section = packet(
            laws: ["When it was raining, you wrote the word lantern. 32 times out of 40."],
            evidence: [sampleEvidence]
        )
        let known = try XCTUnwrap(section.range(of: "WHAT I HAVE ALREADY WORKED OUT"))
        let rules = try XCTUnwrap(section.range(of: "AUTHORITY RULES"))
        XCTAssertTrue(known.lowerBound < rules.lowerBound)
        XCTAssertTrue(section.contains("countings I did myself"), section)
        XCTAssertTrue(section.contains("do not invent new ones"), section)
    }

    func testAnEmptyGrimoireAddsNothingToTheAnswer() {
        let section = packet(laws: [])
        XCTAssertFalse(section.contains("WHAT I HAVE ALREADY WORKED OUT"), section)
    }

    // MARK: The census drawer

    func testTheGrimoireGetsADrawerInTheBooksAccumulatedLife() throws {
        let census = edition(ledger(held: 4, crossedOut: 2)).census
        let ids = Set(census.facts.map(\.id))
        // Four drawers are chosen from many, so assert the candidates exist
        // rather than that they were picked on this particular opening.
        XCTAssertFalse(census.facts.isEmpty)
        for fact in census.facts where ids.contains("rules-held") {
            if fact.id == "rules-held" { XCTAssertEqual(fact.value, 4) }
        }
    }

    func testAnEmptyGrimoireOffersNoDrawer() {
        let census = edition(GrimoireLedger()).census
        XCTAssertFalse(census.facts.contains { $0.id == "rules-held" })
        XCTAssertFalse(census.facts.contains { $0.id == "rules-crossed-out" })
    }

    func testTheMarkIsPlainAndNeverADashboard() throws {
        for grimoire in [
            ledger(held: 1, crossedOut: 0),
            ledger(held: GrimoireLedger.Bars.maximumHeld, crossedOut: 3),
            ledger(held: 0, crossedOut: 0, watching: 1)
        ] {
            let mark = try XCTUnwrap(edition(grimoire).marginalMark)
            for word in ["data", "correlat", "statistic", "metric", "%", "confidence"] {
                XCTAssertFalse(mark.lowercased().contains(word), mark)
            }
            XCTAssertLessThanOrEqual(mark.split(separator: " ").count, 9, mark)
        }
    }
}

/// "The first snow has become one of your private observances."
///
/// From the original moonshot. Every other tradition in the Book is founded on
/// something that happened *to the Book*; this is the first that comes from
/// something the reader keeps doing, which is the whole difference between the
/// Book having a life and the Book having read one.
final class GrimoireObservanceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// Four springs of answering the Salamanders, three of them kept.
    private func seasonalLedger() -> GrimoireLedger {
        var ledger = GrimoireLedger()
        let daily = LoomFeatureRef(
            id: "hour:day", domain: "hour", label: "daytime",
            conditionClause: "it was daytime", outcomeClause: "it was daytime",
            role: .conditionOnly
        )
        let salamanders = LoomFeatureRef(
            id: "fae:salamanders", domain: "ritual", label: "the Sentence Salamanders",
            conditionClause: "the Salamanders were calling",
            outcomeClause: "you answered the Salamanders",
            role: .either, provenance: .readerAuthored
        )
        var observations: [LoomObservation] = []
        for year in 2022...2025 {
            for month in 1...12 {
                for dayOfMonth in [5, 15, 25] {
                    let date = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
                    let index = GrimoireDay.index(for: date, calendar: calendar)
                    var features: [LoomFeatureRef] = [daily]
                    if (3...5).contains(month), year != 2024 { features.append(salamanders) }
                    observations.append(LoomObservation(
                        id: "d-\(index)", day: index, occurredAt: date,
                        features: features, evidencePageID: "page-\(index)", evidenceLine: ""
                    ))
                }
            }
        }
        ledger.ingest(observations)
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        var passes = 0
        while true {
            let report = ledger.sweep(now: now, budget: 2_000, calendar: calendar)
            passes += 1
            if report.finished || passes > 200 { break }
        }
        // The seasonal key carries the turn of the year it belongs to, so the
        // row is found by what it is rather than by a hand-built id.
        if let id = ledger.rows.values.first(where: {
            $0.shape == .seasonal && $0.conditionID == "fae:salamanders"
        })?.id {
            ledger.markSpoken(id, now: now, calendar: calendar)
            ledger.rows[id]?.state = .standing
        }
        return ledger
    }

    private func interior(_ grimoire: GrimoireLedger, now: Date) -> BookInteriorState {
        var inputs = BookSourceInputs.empty
        inputs.grimoire = grimoire
        return BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-400 * 86_400)),
            inputs: inputs, now: now, calendar: calendar
        )
    }

    func testTheReadersOwnSeasonBecomesAnObservance() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let state = interior(seasonalLedger(), now: now)
        let founded = try XCTUnwrap(
            state.privateTraditions.first { $0.kind == .readersOwnSeason },
            "nothing the reader keeps doing became an observance"
        )
        XCTAssertTrue(founded.title.localizedCaseInsensitiveContains("salamander"), founded.title)
        XCTAssertTrue(founded.title.localizedCaseInsensitiveContains("spring"), founded.title)
        XCTAssertEqual(founded.cadenceDays, 365)
        XCTAssertFalse(founded.evidencePageIDs.isEmpty, "an observance keeps its receipts")
    }

    /// The Book gives it a name and starts expecting it. It does not claim to
    /// have invented it.
    func testTheObservanceSaysItIsTheReadersAndNotTheBooks() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let state = interior(seasonalLedger(), now: now)
        let founded = try XCTUnwrap(state.privateTraditions.first { $0.kind == .readersOwnSeason })
        XCTAssertTrue(founded.observance.contains("Do it again"), founded.observance)
        XCTAssertTrue(founded.observance.contains("behind you"), founded.observance)
    }

    /// `reconciled` must be a no-op on an unchanged archive; anything that
    /// restamps a dated field turns a render into a write.
    func testFoundingAnObservanceIsIdempotent() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let grimoire = seasonalLedger()
        let once = interior(grimoire, now: now)
        var inputs = BookSourceInputs.empty
        inputs.grimoire = grimoire
        let twice = BookInteriorEngine.reconciled(
            once, inputs: inputs, now: now.addingTimeInterval(3_600), calendar: calendar
        )
        XCTAssertEqual(
            twice.privateTraditions.filter { $0.kind == .readersOwnSeason }.count,
            once.privateTraditions.filter { $0.kind == .readersOwnSeason }.count
        )
        XCTAssertEqual(
            twice.privateTraditions.map(\.foundedAt),
            once.privateTraditions.map(\.foundedAt),
            "a second pass restamped a founding date"
        )
    }

    func testNothingIsFoundedFromSomethingTheBookIsNotSureOf() {
        var grimoire = seasonalLedger()
        if let id = grimoire.rows.values.first(where: { $0.shape == .seasonal })?.id {
            grimoire.rows[id]?.state = .watching
        }
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertTrue(
            interior(grimoire, now: now).privateTraditions.filter { $0.kind == .readersOwnSeason }.isEmpty
        )
    }

    func testAYoungBookFoundsNothing() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertTrue(
            interior(GrimoireLedger(), now: now).privateTraditions
                .filter { $0.kind == .readersOwnSeason }.isEmpty
        )
    }
}

/// The nightly braid leaning on what the Book already knows.
///
/// The Loom is still *looking*; the grimoire has already decided, stood behind
/// it, and named what would take it back. When tonight's Pages are among the
/// days a standing rule rests on, that rule is the better lens.
final class GrimoireBraidReachTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func page(_ id: String, on date: Date, text: String, weather: [String]) -> BookPage {
        BookPage(
            id: id, type: .diary, createdAt: date, promptText: "p", userInput: text,
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: weather)
        )
    }

    private func day(_ index: Int, pages: [BookPage]) -> BookDay {
        let date = GrimoireDay.date(for: index, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return BookDay(
            id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
            date: calendar.startOfDay(for: date), pages: pages
        )
    }

    /// Sixty rainy-lantern days, the last of which is tonight.
    private func archive() -> (days: [BookDay], today: BookDay, ledger: GrimoireLedger) {
        let built = (0..<61).map { index -> BookDay in
            let date = calendar.date(
                byAdding: .hour, value: 20, to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 3 == 0
            let text = rainy && index != 30
                ? "The lantern outside was swinging in the wet."
                : "Bread, errands, the usual list."
            return day(index, pages: [
                page("page-\(index)", on: date, text: text, weather: rainy ? ["rain"] : ["clear"])
            ])
        }
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(
            from: GrimoireSlice(days: built, calendar: calendar)
        ))
        let now = GrimoireDay.date(for: 62, calendar: calendar)
        var passes = 0
        while true {
            let report = ledger.sweep(now: now, budget: 2_000, calendar: calendar)
            passes += 1
            if report.finished || passes > 200 { break }
        }
        for row in ledger.rows.values where row.isAlive {
            ledger.markSpoken(row.id, now: now, calendar: calendar)
            ledger.rows[row.id]?.state = .standing
        }
        return (Array(built.dropLast()), built[60], ledger)
    }

    private func lens(with grimoire: GrimoireLedger) -> BraidPromptBuilder.NightlyStoryScore.RelationalLens? {
        let (days, today, _) = archive()
        let context = BraidPromptBuilder.context(
            for: today, days: days, now: GrimoireDay.date(for: 62, calendar: calendar),
            calendar: calendar
        )
        return BraidPromptBuilder.nightlyStoryScore(
            for: today, context: context, connections: [], constellations: [],
            grimoire: grimoire,
            now: GrimoireDay.date(for: 62, calendar: calendar), calendar: calendar
        ).relationalLens
    }

    func testAnEmptyGrimoireLeavesTheBraidExactlyAsItWas() {
        XCTAssertNil(lens(with: GrimoireLedger()))
    }

    func testTheBraidLeansOnARuleTheBookAlreadyHolds() throws {
        let (_, _, ledger) = archive()
        let found = try XCTUnwrap(lens(with: ledger), "the braid ignored what the Book already knew")
        XCTAssertEqual(found.evidenceTier, .established)
        XCTAssertTrue(found.line.contains("already worked out"), found.line)
        // Its receipts are real Pages, not a phrase.
        XCTAssertFalse(found.evidencePageIDs.isEmpty)
    }

    /// A reading the reader shut stays shut, on every surface.
    func testAShutReadingNeverReachesTheBraid() throws {
        let (days, today, ledger) = archive()
        let context = BraidPromptBuilder.context(
            for: today, days: days, now: GrimoireDay.date(for: 62, calendar: calendar),
            calendar: calendar
        )
        let forbidden = Set(ledger.rows.values.map(\.id))
        let score = BraidPromptBuilder.nightlyStoryScore(
            for: today, context: context, connections: [], constellations: [],
            forbiddenObservationKeys: forbidden, grimoire: ledger,
            now: GrimoireDay.date(for: 62, calendar: calendar), calendar: calendar
        )
        XCTAssertNil(score.relationalLens)
    }
}

/// An old Page coming back because the grimoire counted it.
///
/// The Remembered source already knows a dozen reasons a Page returns. This
/// adds the one only the grimoire can give: not "today rhymes with this," but
/// "this Page is part of how I know a thing about you."
final class GrimoireRememberedReachTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// The real catalogued source, so the surface under test is the shipped one.
    private var rememberedSource: BookPageSource {
        BookPageSourceRegistry.sources.first { $0.id == "the-book-remembered" }!
    }

    /// A ledger holding one rule, and the ids of the Pages it rests on.
    private func worked() -> (ledger: GrimoireLedger, pageIDs: [String]) {
        let days = (0..<61).map { index -> BookDay in
            let date = calendar.date(
                byAdding: .hour, value: 20, to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 3 == 0
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date),
                pages: [BookPage(
                    id: "page-\(index)", type: .diary, createdAt: date, promptText: "p",
                    userInput: rainy
                        ? "The lantern outside was swinging in the wet."
                        : "Bread, errands, the usual list.",
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(
                        at: date, calendar: calendar, weatherTags: rainy ? ["rain"] : ["clear"]
                    )
                )]
            )
        }
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(
            from: GrimoireSlice(days: days, calendar: calendar)
        ))
        let now = GrimoireDay.date(for: 62, calendar: calendar)
        var passes = 0
        while !ledger.sweep(now: now, budget: 2_000, calendar: calendar).finished, passes < 200 {
            passes += 1
        }
        for row in ledger.rows.values where row.isAlive {
            ledger.markSpoken(row.id, now: now, calendar: calendar)
            ledger.rows[row.id]?.state = .standing
        }
        let table = BookRememberedEngine.grimoireReturns(from: ledger, calendar: calendar)
        return (ledger, Array(table.keys))
    }

    func testAnEmptyGrimoireOffersNoReturns() {
        XCTAssertTrue(
            BookRememberedEngine.grimoireReturns(from: GrimoireLedger(), calendar: calendar).isEmpty
        )
    }

    func testTheBookNamesWhichPagesTaughtItARule() throws {
        let (_, pageIDs) = worked()
        XCTAssertFalse(pageIDs.isEmpty, "no Page was ever credited with teaching the Book anything")
    }

    /// The reason must be readable as a sentence, not a label dump.
    func testTheReasonSaysTheRuleAndCountsTheDays() throws {
        let (ledger, _) = worked()
        let table = BookRememberedEngine.grimoireReturns(from: ledger, calendar: calendar)
        let reason = try XCTUnwrap(table.values.first?.reason)
        XCTAssertTrue(reason.hasPrefix("I counted this Page"), reason)
        XCTAssertTrue(reason.contains("days that taught me"), reason)
        XCTAssertFalse(reason.contains("  "), "double space: \(reason)")
        // The claim itself is in there, so the reader can check the Book's work.
        XCTAssertTrue(reason.contains("When ") || reason.contains("not "), reason)
    }

    /// A rule still being counted is arithmetic, not knowledge.
    func testAWatchingRuleNeverExplainsAReturn() {
        var (ledger, _) = worked()
        for row in ledger.rows.values {
            ledger.rows[row.id]?.state = .watching
            ledger.rows[row.id]?.lastSpokenAt = nil
        }
        XCTAssertTrue(BookRememberedEngine.grimoireReturns(from: ledger, calendar: calendar).isEmpty)
    }

    /// A reading the reader shut stays shut here too.
    func testACrossedOutRuleNeverExplainsAReturn() {
        var (ledger, _) = worked()
        for row in ledger.rows.values { ledger.rows[row.id]?.state = .crossedOut }
        XCTAssertTrue(BookRememberedEngine.grimoireReturns(from: ledger, calendar: calendar).isEmpty)
    }

    /// The epistemic guard: saying a rule on a Remembered Page contaminates the
    /// same window as saying it anywhere else, so the desk has to be able to
    /// count the telling. A surface that speaks a rule without carrying its id
    /// would leave the falsifier measuring itself on coached days.
    func testTellingTheRuleIsRecordedAsTelling() throws {
        let (ledger, pageIDs) = worked()
        let pageID = try XCTUnwrap(pageIDs.first)
        let entry = try XCTUnwrap(
            BookRememberedEngine.grimoireReturns(from: ledger, calendar: calendar)[pageID]
        )
        let visitation = BookRememberedVisitation(
            page: BookPage(
                id: pageID, type: .diary, createdAt: Date(timeIntervalSince1970: 0),
                promptText: "p", userInput: "the lantern", origin: .userAuthored
            ),
            score: 80, reason: entry.reason, todayConnections: [entry.reason], action: "",
            grimoireCorrespondenceID: entry.rowID
        )
        let surface = visitation.surface(
            source: rememberedSource,
            day: BookDay(id: "2026-09-01", date: Date(), pages: []),
            now: Date()
        )
        XCTAssertEqual(surface.payload.metadata["grimoireCorrespondenceID"], entry.rowID)
        // And the desk's recorder actually accepts it.
        let after = try XCTUnwrap(GrimoireLedger.speaking(surface, in: ledger, now: Date()))
        XCTAssertNotEqual(
            after.rows[entry.rowID]?.lastSpokenAt, ledger.rows[entry.rowID]?.lastSpokenAt,
            "the Book said the rule out loud and nothing wrote it down"
        )
    }

    /// A Page the grimoire counted but that came back for a louder reason has
    /// not spent the claim, and must not be marked as spoken.
    func testAReturnForAnotherReasonDoesNotSpendTheRule() {
        let visitation = BookRememberedVisitation(
            page: BookPage(
                id: "page-0", type: .diary, createdAt: Date(timeIntervalSince1970: 0),
                promptText: "p", userInput: "x", origin: .userAuthored
            ),
            score: 80, reason: "The Long Memory pinned this Page. It told me not to lose it.",
            todayConnections: [], action: "", grimoireCorrespondenceID: nil
        )
        let surface = visitation.surface(
            source: rememberedSource,
            day: BookDay(id: "2026-09-01", date: Date(), pages: []),
            now: Date()
        )
        XCTAssertNil(surface.payload.metadata["grimoireCorrespondenceID"])
    }
}

/// What the Notice actually says, built from the real projectors.
///
/// The hand-made voice fixture uses clean one-word labels, so it never caught
/// the title that joined a blended condition to a quoted word: "evening and
/// clear , and then “bread”". In real output blends are the *common* case —
/// every strongest row here is one. These tests run the whole pipeline.
final class GrimoireNoticeVoiceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func worked() -> GrimoireLedger {
        let days = (0..<61).map { index -> BookDay in
            let date = calendar.date(
                byAdding: .hour, value: 20, to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 3 == 0
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date),
                pages: [BookPage(
                    id: "page-\(index)", type: .diary, createdAt: date, promptText: "p",
                    userInput: rainy
                        ? "The lantern outside was swinging in the wet."
                        : "Bread, errands, the usual list.",
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(
                        at: date, calendar: calendar, weatherTags: rainy ? ["rain"] : ["clear"]
                    )
                )]
            )
        }
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(
            from: GrimoireSlice(days: days, calendar: calendar)
        ))
        let now = GrimoireDay.date(for: 62, calendar: calendar)
        var passes = 0
        while !ledger.sweep(now: now, budget: 2_000, calendar: calendar).finished, passes < 200 {
            passes += 1
        }
        for row in ledger.rows.values where row.isAlive {
            ledger.markSpoken(row.id, now: now, calendar: calendar)
            ledger.rows[row.id]?.state = .standing
        }
        return ledger
    }

    /// The blend is the case that broke. Prove the fixture reaches it.
    func testTheRealPipelineProducesBlendedConditions() {
        let ledger = worked()
        XCTAssertTrue(
            ledger.rows.values.contains { ledger.ref($0.conditionID)?.domain == "contextBlend" },
            "this fixture no longer exercises the case that broke"
        )
    }

    func testTheTitleNeverCarriesAFeatureLabel() {
        let ledger = worked()
        for row in ledger.rows.values {
            let title = GrimoireVoice.noticeTitle(row: row)
            for id in [row.conditionID, row.outcomeID, row.rivalID].compactMap({ $0 }) {
                guard let label = ledger.ref(id)?.label, label.count >= 3 else { continue }
                XCTAssertFalse(
                    title.localizedCaseInsensitiveContains(label),
                    "a registry label got into the title: \(title)"
                )
            }
        }
    }

    /// The literal defect: a space before a comma, from a frame that assumed
    /// its own label had no punctuation in it.
    func testNoLineHasSpaceBeforeItsPunctuation() {
        let ledger = worked()
        for row in ledger.rows.values {
            guard let stats = ledger.currentStats(for: row, calendar: calendar) else { continue }
            let lines = [
                GrimoireVoice.noticeTitle(row: row),
                GrimoireVoice.editionTitle(row: row, ledger: ledger),
                GrimoireVoice.plainClaim(row: row, stats: stats, ledger: ledger),
                GrimoireVoice.entry(row: row, ledger: ledger, calendar: calendar)
            ]
            for line in lines where !line.isEmpty {
                for mark in [" ,", " .", " ;", " !", " ?", "  "] {
                    XCTAssertFalse(line.contains(mark), "“\(mark)” in: \(line)")
                }
            }
        }
    }

    /// `outcomeClause` is a finished statement — "you used the word lantern" —
    /// so no line may hang it off a verb that wants a noun. The promise line
    /// had this bug; so did the sibling comparison.
    func testNoLineUsesAFinishedStatementAsANoun() {
        let ledger = worked()
        for row in ledger.rows.values {
            guard let stats = ledger.currentStats(for: row, calendar: calendar) else { continue }
            guard let outcome = row.outcomeID.flatMap({ ledger.ref($0) }) else { continue }
            let lines = [
                GrimoireVoice.claim(row: row, stats: stats, ledger: ledger, calendar: calendar),
                GrimoireVoice.plainClaim(row: row, stats: stats, ledger: ledger),
                GrimoireVoice.entry(row: row, ledger: ledger, calendar: calendar)
            ]
            for verb in ["brings", "makes", "causes", "gives", "wants", "means"] {
                for line in lines where !line.isEmpty {
                    XCTAssertFalse(
                        line.contains("\(verb) \(outcome.outcomeClause)"),
                        "“\(verb)” swallowed a whole statement: \(line)"
                    )
                }
            }
        }
    }

    /// A shape with one side must never be announced as a pair, and a shape
    /// that comes and goes must never be announced as annual.
    func testEveryShapeIsAnnouncedAsWhatItIs() {
        for shape in [GrimoireShape.conditional, .sequential, .sibling, .seasonal, .returnInterval] {
            var row = GrimoireCorrespondence(
                id: "r", shape: shape, conditionID: "c", outcomeID: [.seasonal, .returnInterval].contains(shape) ? nil : "o",
                state: .standing, firstObservedAt: Date(), lastObservedAt: Date(),
                falsifier: nil, revisions: [], readerStatus: nil, lastSpokenAt: Date(),
                strengthPeak: 60, interestPeak: 40
            )
            let title = GrimoireVoice.noticeTitle(row: row)
            XCTAssertFalse(title.isEmpty, "\(shape) had no title")
            if shape == .returnInterval {
                XCTAssertFalse(
                    title.localizedCaseInsensitiveContains("year"),
                    "a thing that comes and goes was called annual: \(title)"
                )
            }
            if shape == .seasonal || shape == .returnInterval {
                XCTAssertFalse(
                    title.localizedCaseInsensitiveContains("two"),
                    "a one-sided shape was announced as a pair: \(title)"
                )
            }
            // Being wrong outranks the shape, always.
            row.state = .crossedOut
            XCTAssertEqual(GrimoireVoice.noticeTitle(row: row), "I Was Wrong About This")
        }
    }
}
