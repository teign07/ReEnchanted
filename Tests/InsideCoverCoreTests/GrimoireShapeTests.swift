import XCTest
@testable import InsideCoverCore

/// The two shapes that finish the set: a comparison inside one family, and a
/// rule the Book can watch coming loose.
final class GrimoireShapeTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func feature(
        _ id: String, _ domain: String, _ label: String,
        role: LoomFeatureRole, provenance: LoomProvenance = .observedContext,
        outcomeClause: String? = nil
    ) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: label,
            conditionClause: "you had taken \(label)",
            outcomeClause: outcomeClause ?? "you took \(label)",
            role: role, provenance: provenance
        )
    }

    private func observation(day: Int, _ features: [LoomFeatureRef]) -> LoomObservation {
        LoomObservation(
            id: "day-\(day)", day: day,
            occurredAt: GrimoireDay.date(for: day, calendar: calendar),
            features: features, evidencePageID: "page-\(day)", evidenceLine: ""
        )
    }

    private func swept(_ observations: [LoomObservation], now: Int = 200) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(
                now: GrimoireDay.date(for: now, calendar: calendar),
                budget: 800, calendar: calendar
            )
            passes += 1
            if report.finished || passes > 80 { break }
        }
        return ledger
    }

    // MARK: Siblings

    /// Wicker sets two kinds of Working. Only one of them brings anything back.
    private func routesAndHuntsLedger() -> GrimoireLedger {
        let route = feature("working:unnecessary-route", "working", "the unnecessary route", role: .either)
        let hunt = feature("working:object-hunt", "working", "the object hunt", role: .either)
        let souvenir = feature(
            "working-returned:any", "workingReturn", "coming back with something",
            role: .outcomeOnly, provenance: .readerAuthored,
            outcomeClause: "you came back with something"
        )
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)

        var observations: [LoomObservation] = []
        for day in 0..<80 {
            var features: [LoomFeatureRef] = [hour]
            if day % 4 == 0 {
                features.append(route)
                if day % 20 != 0 { features.append(souvenir) }   // routes nearly always return
            } else if day % 4 == 2 {
                features.append(hunt)                            // hunts never do
            }
            observations.append(observation(day: day, features))
        }
        return swept(observations)
    }

    func testTheBookComparesTwoMembersOfOneFamily() throws {
        let ledger = routesAndHuntsLedger()
        let id = GrimoireCorrespondence.key(
            shape: .sibling,
            condition: "working:unnecessary-route",
            outcome: "working-returned:any",
            rival: "working:object-hunt"
        )
        let row = try XCTUnwrap(ledger.row(id), "the Book never compared the two Workings")
        XCTAssertEqual(row.shape, .sibling)
        XCTAssertEqual(row.rivalID, "working:object-hunt")

        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        let line = GrimoireVoice.claim(row: row, stats: stats, ledger: ledger, calendar: calendar)
        // A comparison that does not name what lost is not a comparison.
        XCTAssertTrue(line.localizedCaseInsensitiveContains("the unnecessary route"), line)
        XCTAssertTrue(line.localizedCaseInsensitiveContains("the object hunt"), line)
        XCTAssertTrue(line.contains("you came back with something"), line)
    }

    func testNoComparisonWhenBothMembersDoTheSameThing() {
        let route = feature("working:unnecessary-route", "working", "the unnecessary route", role: .either)
        let hunt = feature("working:object-hunt", "working", "the object hunt", role: .either)
        let souvenir = feature(
            "working-returned:any", "workingReturn", "coming back with something",
            role: .outcomeOnly, provenance: .readerAuthored,
            outcomeClause: "you came back with something"
        )
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<80 {
            var features: [LoomFeatureRef] = [hour]
            if day % 4 == 0 { features.append(route); features.append(souvenir) }
            else if day % 4 == 2 { features.append(hunt); features.append(souvenir) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations)
        XCTAssertTrue(
            ledger.rows.values.filter { $0.shape == .sibling }.isEmpty,
            "two members that behave alike are not a comparison"
        )
    }

    func testAComparisonNeedsTheRivalToHaveHadRealChances() {
        let route = feature("working:unnecessary-route", "working", "the unnecessary route", role: .either)
        let rare = feature("working:rare-errand", "working", "the rare errand", role: .either)
        let souvenir = feature(
            "working-returned:any", "workingReturn", "coming back with something",
            role: .outcomeOnly, provenance: .readerAuthored,
            outcomeClause: "you came back with something"
        )
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<80 {
            var features: [LoomFeatureRef] = [hour]
            if day % 4 == 0 { features.append(route); features.append(souvenir) }
            // The rival happens twice in eighty days: too thin to lose a contest.
            if day == 5 || day == 41 { features.append(rare) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations)
        XCTAssertFalse(
            ledger.rows.values.contains { $0.rivalID == "working:rare-errand" },
            "a rival with two chances has not lost anything"
        )
    }

    func testASpokenSiblingComparisonIsCrossedOutWhenTheRivalCatchesUp() throws {
        var ledger = routesAndHuntsLedger()
        let id = GrimoireCorrespondence.key(
            shape: .sibling,
            condition: "working:unnecessary-route",
            outcome: "working-returned:any",
            rival: "working:object-hunt"
        )
        ledger.markSpoken(id, now: GrimoireDay.date(for: 80, calendar: calendar), calendar: calendar)

        let hunt = feature("working:object-hunt", "working", "the object hunt", role: .either)
        let souvenir = feature(
            "working-returned:any", "workingReturn", "coming back with something",
            role: .outcomeOnly, provenance: .readerAuthored,
            outcomeClause: "you came back with something"
        )
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        ledger.ingest((80..<160).map { day in
            observation(day: day, day.isMultiple(of: 2) ? [hour, hunt, souvenir] : [hour])
        })

        var passes = 0
        while true {
            let report = ledger.sweep(
                now: GrimoireDay.date(for: 161, calendar: calendar),
                budget: 800, calendar: calendar
            )
            passes += 1
            if report.finished || passes > 80 { break }
        }

        XCTAssertEqual(ledger.row(id)?.state, .crossedOut)
        XCTAssertTrue(
            ledger.row(id)?.revisions.contains { $0.to == .crossedOut } == true,
            "the comparison stayed alive after the named rival caught up"
        )
    }

    // MARK: Compound conditions

    /// "For you, parking lots after rain keep opening something."
    ///
    /// Neither the place nor the weather explains it on its own — only the two
    /// together — so this is the case a strictly pairwise engine cannot state.
    func testAPlaceAndAWeatherTogetherSayWhatNeitherSaysAlone() throws {
        var calendarLocal = calendar
        calendarLocal.timeZone = TimeZone(identifier: "UTC") ?? .current
        var days: [BookDay] = []
        for index in 0..<120 {
            let date = calendarLocal.date(
                byAdding: .hour, value: 14,
                to: GrimoireDay.date(for: index, calendar: calendarLocal)
            )!
            // Rain and the car park each happen often on their own; together,
            // rarely — and almost always with the word.
            let rainy = index % 3 == 0
            let carPark = index % 4 == 0
            let both = rainy && carPark
            let text = both && index != 60
                ? "Something cracked open in me, standing there."
                : "Bread, errands, the usual list."
            let page = BookPage(
                id: "page-\(index)", type: .diary, createdAt: date,
                promptText: "p", userInput: text, origin: .userAuthored,
                context: BookPageContextSnapshot(
                    at: date, calendar: calendarLocal,
                    weatherTags: rainy ? ["rain"] : ["clear"],
                    nearbyAnchorID: carPark ? "the car park" : "the kitchen"
                )
            )
            let parts = calendarLocal.dateComponents([.year, .month, .day], from: date)
            days.append(BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendarLocal.startOfDay(for: date), pages: [page]
            ))
        }
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(
            from: GrimoireSlice(days: days, calendar: calendarLocal)
        ))
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 121, calendar: calendarLocal),
                                      budget: 1_500, calendar: calendarLocal)
            passes += 1
            if report.finished || passes > 120 { break }
        }

        let blend = try XCTUnwrap(
            ledger.rows.values.first { row in
                row.conditionID.hasPrefix("blend:")
                    && row.conditionID.contains("weather:rain")
                    && row.conditionID.contains("place:the car park")
                    && row.outcomeID == "word:cracked"
            },
            "the compound condition never formed"
        )
        let stats = try XCTUnwrap(ledger.currentStats(for: blend, calendar: calendarLocal))
        XCTAssertGreaterThanOrEqual(stats.inHits, 8)
        XCTAssertEqual(stats.outHits, 0)

        // And the claim names both halves, because either alone is not the rule.
        let line = GrimoireVoice.claim(row: blend, stats: stats, ledger: ledger, calendar: calendarLocal)
        XCTAssertTrue(line.localizedCaseInsensitiveContains("rain"), line)
        XCTAssertTrue(line.localizedCaseInsensitiveContains("car park"), line)
    }

    func testABlendIsAlwaysACircumstanceAndNeverAnOutcome() {
        let weather = LoomFeatureRef(
            id: "weather:rain", domain: "weather", label: "rain",
            conditionClause: "it was raining", outcomeClause: "the sky was raining",
            role: .conditionOnly
        )
        let place = LoomFeatureRef(
            id: "place:harbour", domain: "place", label: "the harbour",
            conditionClause: "you were at the harbour", outcomeClause: "you went to the harbour",
            role: .either
        )
        let blends = GrimoireProjection.blends(from: [weather, place])
        XCTAssertEqual(blends.count, 1)
        XCTAssertEqual(blends[0].role, .conditionOnly)
        XCTAssertEqual(blends[0].domain, "contextBlend")
    }

    func testTwoAmbientFactsDoNotBlend() {
        let hour = LoomFeatureRef(
            id: "hour:night", domain: "hour", label: "night",
            conditionClause: "it was night", outcomeClause: "it was night", role: .conditionOnly
        )
        let season = LoomFeatureRef(
            id: "season:spring", domain: "season", label: "spring",
            conditionClause: "it was spring", outcomeClause: "it was spring", role: .conditionOnly
        )
        // "A weekday in spring" is two ambient facts and describes nothing.
        XCTAssertTrue(GrimoireProjection.blends(from: [hour, season]).isEmpty)
    }

    // MARK: Coming back

    /// "The harbour goes quiet for months, then comes back."
    ///
    /// The last shape, and the only one about the *shape of an absence*. A
    /// subject that turns up weekly has a rhythm; one that vanishes for a
    /// season and reappears has a habit of leaving, which is a stranger and
    /// better thing for the Book to be able to say.
    func testAThingThatGoesQuietAndComesBack() throws {
        let harbour = feature("subject:harbour", "subject", "the harbour", role: .either)
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        var observations: [LoomObservation] = []
        // Four visits, each separated by a long silence.
        let visits = Set([0, 1, 2, 60, 61, 130, 131, 132, 200, 201])
        for day in 0..<240 {
            var features: [LoomFeatureRef] = [hour]
            if visits.contains(day) { features.append(harbour) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations, now: 241)
        let row = try XCTUnwrap(
            ledger.rows.values.first { $0.shape == .returnInterval && $0.conditionID == "subject:harbour" },
            "the Book never noticed it kept leaving"
        )
        let standing = try XCTUnwrap(ledger.returnStanding(of: ledger.days(of: "subject:harbour")))
        XCTAssertEqual(standing.returns, 3)
        XCTAssertGreaterThan(standing.longestGap, 55)

        let line = GrimoireVoice.claim(
            row: row,
            stats: try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar)),
            ledger: ledger, calendar: calendar
        )
        XCTAssertTrue(line.localizedCaseInsensitiveContains("harbour"), line)
        XCTAssertTrue(
            line.contains("comes back") || line.contains("pick it up again") || line.contains("returns"),
            line
        )
    }

    func testSomethingSteadyIsNotAHabitOfLeaving() {
        let kettle = feature("subject:kettle", "subject", "the kettle", role: .either)
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<240 {
            var features: [LoomFeatureRef] = [hour]
            if day % 3 == 0 { features.append(kettle) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations, now: 241)
        // A rhythm is not a return.
        XCTAssertNil(ledger.returnStanding(of: ledger.days(of: "subject:kettle")))
        XCTAssertFalse(ledger.rows.values.contains {
            $0.shape == .returnInterval && $0.conditionID == "subject:kettle"
        })
    }

    func testTwoAbsencesAreACoincidenceWithALongMiddle() {
        let harbour = feature("subject:harbour", "subject", "the harbour", role: .either)
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        var observations: [LoomObservation] = []
        let visits = Set([0, 1, 80, 81, 170])
        for day in 0..<240 {
            var features: [LoomFeatureRef] = [hour]
            if visits.contains(day) { features.append(harbour) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations, now: 241)
        XCTAssertNil(ledger.returnStanding(of: ledger.days(of: "subject:harbour")))
    }

    /// The weather is not choosing to visit. Only a thing that could be said to
    /// leave may be said to come back.
    func testACircumstanceCannotComeBack() {
        let rain = feature("weather:rain", "weather", "rain", role: .conditionOnly)
        let hour = feature("hour:day", "hour", "daytime", role: .conditionOnly)
        var observations: [LoomObservation] = []
        let spells = Set([0, 1, 2, 60, 61, 130, 131, 200, 201])
        for day in 0..<240 {
            var features: [LoomFeatureRef] = [hour]
            if spells.contains(day) { features.append(rain) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations, now: 241)
        XCTAssertFalse(ledger.rows.values.contains {
            $0.shape == .returnInterval && $0.conditionID == "weather:rain"
        })
    }

    // MARK: Drift

    func testTheBookNoticesARuleComingLoose() throws {
        let rain = feature("weather:rain", "weather", "rain", role: .conditionOnly)
        let fae = feature("fae:met", "fae", "a Fae", role: .outcomeOnly, provenance: .readerAuthored)
        let hour = feature("hour:night", "hour", "night", role: .conditionOnly)

        var observations: [LoomObservation] = []
        for day in 0..<120 {
            var features: [LoomFeatureRef] = [hour]
            if day % 3 == 0 {
                features.append(rain)
                // Reliable in the first half, patchy in the second.
                let reliable = day < 60 ? true : (day % 15 == 0)
                if reliable { features.append(fae) }
            }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations, now: 121)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        let row = try XCTUnwrap(ledger.row(id))
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))

        XCTAssertGreaterThan(stats.earlyRate, stats.lateRate)
        let drift = try XCTUnwrap(
            GrimoireVoice.drift(row: row, stats: stats),
            "a rule that halved should be worth mentioning"
        )
        XCTAssertFalse(drift.isEmpty)
        XCTAssertTrue(
            GrimoireVoice.entry(row: row, ledger: ledger, calendar: calendar).contains(drift),
            "the whole entry should carry it"
        )
    }

    func testASteadyRuleIsNotDescribedAsDrifting() throws {
        let rain = feature("weather:rain", "weather", "rain", role: .conditionOnly)
        let fae = feature("fae:met", "fae", "a Fae", role: .outcomeOnly, provenance: .readerAuthored)
        let hour = feature("hour:night", "hour", "night", role: .conditionOnly)
        var observations: [LoomObservation] = []
        for day in 0..<120 {
            var features: [LoomFeatureRef] = [hour]
            if day % 3 == 0 { features.append(rain); features.append(fae) }
            observations.append(observation(day: day, features))
        }
        let ledger = swept(observations, now: 121)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        let row = try XCTUnwrap(ledger.row(id))
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        XCTAssertNil(GrimoireVoice.drift(row: row, stats: stats))
    }

    func testDriftStaysQuietOnThinEvidence() throws {
        var stats = GrimoireStats()
        stats.inCount = 5
        stats.inHits = 4
        stats.earlyRate = 1.0
        stats.lateRate = 0.0
        let row = GrimoireCorrespondence(
            id: "x", shape: .conditional, conditionID: "a", outcomeID: "b",
            state: .watching, firstObservedAt: Date(), lastObservedAt: Date(),
            falsifier: nil, revisions: [],
            readerStatus: nil, lastSpokenAt: nil, strengthPeak: 0, interestPeak: 0
        )
        XCTAssertNil(GrimoireVoice.drift(row: row, stats: stats), "four hits is not a trend")
    }

    func testASiblingRowSurvivesTheVault() throws {
        let ledger = routesAndHuntsLedger()
        let data = try JSONEncoder().encode(ledger)
        let restored = try JSONDecoder().decode(GrimoireLedger.self, from: data)
        let sibling = try XCTUnwrap(restored.rows.values.first { $0.shape == .sibling })
        XCTAssertEqual(sibling.rivalID, "working:object-hunt")
    }
}
