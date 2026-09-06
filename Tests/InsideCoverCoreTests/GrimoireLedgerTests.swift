import XCTest
@testable import InsideCoverCore

/// The acceptance tests for the private grimoire.
///
/// Nothing in here codes a rule like "rain brings the Fae". The archives are
/// built by hand with a pattern hidden inside them, and the engine either finds
/// it from ordinary receipts or it does not.
final class GrimoireLedgerTests: XCTestCase {

    // MARK: Fixtures

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func condition(_ id: String, domain: String, label: String? = nil) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: label ?? id,
            conditionClause: "it was \(label ?? id)",
            outcomeClause: "it was \(label ?? id)",
            role: .conditionOnly, rank: 10
        )
    }

    private func outcome(_ id: String, domain: String, label: String? = nil) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: label ?? id,
            conditionClause: "\(label ?? id) had happened",
            outcomeClause: "you \(label ?? id)",
            role: .outcomeOnly, provenance: .readerAuthored, rank: 70
        )
    }

    private func observation(day: Int, _ features: [LoomFeatureRef], page: String? = nil) -> LoomObservation {
        LoomObservation(
            id: "day-\(day)-\(features.map(\.id).joined(separator: "-"))",
            day: day,
            occurredAt: GrimoireDay.date(for: day, calendar: calendar),
            features: features,
            evidencePageID: page,
            evidenceLine: "day \(day)"
        )
    }

    /// A Book where rainy nights bring the Fae out, and nothing says so.
    private func rainyNightArchive() -> GrimoireLedger {
        let rain = condition("weather:rain", domain: "weather", label: "raining")
        let hour = condition("hour:night", domain: "hour", label: "night")
        let fae = outcome("fae:met", domain: "fae", label: "met a Fae")
        let wrote = outcome("wrote:page", domain: "writing", label: "wrote a Page")

        var ledger = GrimoireLedger()
        var observations: [LoomObservation] = []
        for day in 0..<60 {
            var features: [LoomFeatureRef] = [hour]
            let isRainy = day % 10 == 0 && day <= 50          // 6 rainy nights
            if isRainy {
                features.append(rain)
                if day != 30 { features.append(fae) }          // 5 of 6 bring Fae
            } else if day % 17 == 0 {
                features.append(fae)                           // 3 Fae elsewhere
            }
            if day % 3 == 0 { features.append(wrote) }
            observations.append(observation(day: day, features, page: "page-\(day)"))
        }
        ledger.ingest(observations, now: GrimoireDay.date(for: 60, calendar: calendar))
        return ledger
    }

    private func sweepAll(_ ledger: inout GrimoireLedger, now: Date? = nil) {
        let stamp = now ?? GrimoireDay.date(for: 61, calendar: calendar)
        var guardRail = 0
        while true {
            let report = ledger.sweep(now: stamp, budget: 500, calendar: calendar)
            guardRail += 1
            if report.finished || guardRail > 50 { break }
        }
    }

    // MARK: Discovery

    func testFindsRainyNightFaeWithoutAnyoneCodingTheRule() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)

        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        guard let row = ledger.row(id) else {
            return XCTFail("the Book did not notice the rain")
        }
        XCTAssertTrue(row.isAlive)
        let stats = ledger.currentStats(for: row, calendar: calendar)!
        XCTAssertEqual(stats.inCount, 6)
        XCTAssertEqual(stats.inHits, 5)
        XCTAssertGreaterThan(stats.lift, 5)
    }

    func testTheBookCanShowTheDaysItDidNotHappenToo() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        let stats = ledger.currentStats(for: ledger.row(id)!, calendar: calendar)!
        // The contrast group is what makes the claim mean anything.
        XCTAssertEqual(stats.outCount, 54)
        XCTAssertEqual(stats.outHits, 3)
        XCTAssertLessThan(stats.outRate, 0.1)
    }

    func testAPlainCoincidenceStaysQuiet() {
        // Two things that land together three times in an archive where the
        // outcome is common anyway. Nothing here has earned a sentence.
        let dusk = condition("hour:dusk", domain: "hour", label: "dusk")
        let tea = outcome("drank:tea", domain: "habit", label: "drank tea")
        var ledger = GrimoireLedger()
        var observations: [LoomObservation] = []
        for day in 0..<40 {
            var features: [LoomFeatureRef] = [condition("hour:any", domain: "clock", label: "a day")]
            if day < 5 { features.append(dusk) }
            if day % 2 == 0 { features.append(tea) }          // tea everywhere
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "hour:dusk", outcome: "drank:tea")
        XCTAssertNil(ledger.row(id), "a coincidence became a claim")
    }

    func testNoClaimWhenTheOutcomeHappensJustAsMuchWithoutTheCondition() {
        let fog = condition("weather:fog", domain: "weather", label: "foggy")
        let wrote = outcome("wrote:page", domain: "writing", label: "wrote")
        var ledger = GrimoireLedger()
        var observations: [LoomObservation] = []
        for day in 0..<40 {
            var features: [LoomFeatureRef] = [condition("hour:day", domain: "hour", label: "daytime")]
            if day % 5 == 0 { features.append(fog) }
            features.append(wrote)                             // writing every single day
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:fog", outcome: "wrote:page")
        XCTAssertNil(ledger.row(id), "no contrast, but the Book claimed anyway")
    }

    func testFindsOneThingFollowingAnotherAFewDaysLater() {
        let invitation = condition("wicker:invite", domain: "cast", label: "Wicker asked")
        let photograph = outcome("kept:photo", domain: "media", label: "kept a photograph")
        var ledger = GrimoireLedger()
        var observations: [LoomObservation] = []
        for day in 0..<60 {
            var features: [LoomFeatureRef] = [condition("hour:day", domain: "hour", label: "daytime")]
            if day % 10 == 0 { features.append(invitation) }
            // A photograph two days after each invitation, and almost never else.
            if day % 10 == 2 { features.append(photograph) }
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .sequential, condition: "wicker:invite", outcome: "kept:photo")
        XCTAssertNotNil(ledger.row(id), "the Book missed a sequence")
        // And the same-day reading should not have fired, because it is not true.
        let sameDay = GrimoireCorrespondence.key(shape: .conditional, condition: "wicker:invite", outcome: "kept:photo")
        XCTAssertNil(ledger.row(sameDay))
    }

    // MARK: Seasons and absence

    func testNoticesAThingThatComesBackEverySpringAndTheSpringItMissed() {
        let salamanders = LoomFeatureRef(
            id: "fae:salamanders", domain: "fae", label: "the Sentence Salamanders",
            conditionClause: "the Salamanders were about", outcomeClause: "you answered the Salamanders",
            role: .either, provenance: .readerAuthored
        )
        let daily = condition("hour:day", domain: "hour", label: "daytime")
        var ledger = GrimoireLedger()
        var observations: [LoomObservation] = []
        // Four years of Book, open all year round.
        for year in 2022...2025 {
            for month in 1...12 {
                for dayOfMonth in [5, 15, 25] {
                    let date = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
                    let index = GrimoireDay.index(for: date, calendar: calendar)
                    var features: [LoomFeatureRef] = [daily]
                    // Answered every spring except 2024.
                    if (3...5).contains(month), year != 2024 { features.append(salamanders) }
                    observations.append(observation(day: index, features))
                }
            }
        }
        ledger.ingest(observations)
        sweepAll(&ledger, now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)

        let id = GrimoireCorrespondence.key(
            shape: .seasonal, condition: "fae:salamanders", outcome: nil, season: 1
        )
        guard let row = ledger.row(id) else { return XCTFail("no seasonal correspondence") }
        XCTAssertEqual(row.season, 1)
        let standing = ledger.seasonalStanding(of: ledger.days(of: "fae:salamanders"), calendar: calendar)!
        XCTAssertEqual(standing.season, 1, "should have landed on spring")
        XCTAssertEqual(standing.present, 3)
        XCTAssertEqual(standing.missed, 1)

        let line = GrimoireVoice.claim(
            row: row,
            stats: ledger.currentStats(for: row, calendar: calendar)!,
            ledger: ledger,
            calendar: calendar
        )
        XCTAssertTrue(line.contains("Every spring but one"), "got: \(line)")
    }

    func testAThingThatHappensAllYearIsNotCalledSeasonal() {
        let lantern = LoomFeatureRef(
            id: "ritual:lantern", domain: "ritual", label: "the lantern",
            conditionClause: "the lantern was lit", outcomeClause: "you lit the lantern",
            role: .either, provenance: .readerAuthored
        )
        let daily = condition("hour:day", domain: "hour", label: "daytime")
        var observations: [LoomObservation] = []
        for year in 2022...2025 {
            for month in 1...12 {
                let date = calendar.date(from: DateComponents(year: year, month: month, day: 15))!
                observations.append(observation(
                    day: GrimoireDay.index(for: date, calendar: calendar),
                    [daily, lantern]
                ))
            }
        }

        var ledger = GrimoireLedger()
        ledger.ingest(observations)
        sweepAll(&ledger, now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)

        XCTAssertFalse(
            ledger.rows.values.contains { $0.shape == .seasonal && $0.conditionID == lantern.id },
            "a year-round occurrence was assigned an arbitrary season"
        )
    }

    func testASeasonalClaimIsCrossedOutInsteadOfSilentlyChangingSeasons() throws {
        let observance = LoomFeatureRef(
            id: "observance:first-snow", domain: "observance", label: "the first snow",
            conditionClause: "the first snow came", outcomeClause: "you marked the first snow",
            role: .either, provenance: .readerAuthored
        )
        let daily = condition("hour:day", domain: "hour", label: "daytime")
        func archive(observanceMonth: Int) -> [LoomObservation] {
            var observations: [LoomObservation] = []
            for year in 2022...2025 {
                for month in 1...12 {
                    let date = calendar.date(from: DateComponents(year: year, month: month, day: 15))!
                    var features = [daily]
                    if month == observanceMonth { features.append(observance) }
                    observations.append(observation(
                        day: GrimoireDay.index(for: date, calendar: calendar), features
                    ))
                }
            }
            return observations
        }

        let springID = GrimoireCorrespondence.key(
            shape: .seasonal, condition: observance.id, outcome: nil, season: 1
        )
        var ledger = GrimoireLedger()
        ledger.ingest(archive(observanceMonth: 4))
        sweepAll(&ledger, now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)
        ledger.markSpoken(
            springID,
            now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            calendar: calendar
        )

        ledger.reconcile(
            archive(observanceMonth: 10),
            now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        )
        sweepAll(&ledger, now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!)

        XCTAssertEqual(ledger.row(springID)?.state, .crossedOut)
        let autumnID = GrimoireCorrespondence.key(
            shape: .seasonal, condition: observance.id, outcome: nil, season: 3
        )
        let autumn = try XCTUnwrap(ledger.row(autumnID))
        XCTAssertEqual(autumn.season, 3)
        XCTAssertNotEqual(springID, autumnID)
    }

    // MARK: Being wrong

    func testCrossesItselfOutWhenThePatternCollapses() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)
        XCTAssertEqual(ledger.row(id)?.state, .spoken)
        XCTAssertNotNil(ledger.row(id)?.falsifier)

        // Ten more rainy nights and not one Fae — and deliberately *after* the
        // week the Book's own telling covers, because it will not judge itself
        // on days that heard it.
        let rain = condition("weather:rain", domain: "weather", label: "raining")
        let hour = condition("hour:night", domain: "hour", label: "night")
        var later: [LoomObservation] = []
        for day in 70..<80 { later.append(observation(day: day, [hour, rain])) }
        ledger.ingest(later)
        sweepAll(&ledger, now: GrimoireDay.date(for: 81, calendar: calendar))

        XCTAssertEqual(ledger.row(id)?.state, .crossedOut)
        XCTAssertTrue(ledger.row(id)?.revisions.contains { $0.to == .crossedOut } ?? false)
    }

    func testTheFalsifierBitesWhileTheRunningAverageStillLooksFine() {
        // The interesting case: cumulative numbers still clear every bar, but
        // the claim has stopped working *lately*. A Book that only watched the
        // average would keep saying it for months.
        let rain = condition("weather:rain", domain: "weather", label: "raining")
        let hour = condition("hour:night", domain: "hour", label: "night")
        let fae = outcome("fae:met", domain: "fae", label: "met a Fae")
        var ledger = GrimoireLedger()

        // Twenty rainy nights, twenty Fae. Perfect.
        var observations: [LoomObservation] = []
        for day in 0..<40 {
            var features: [LoomFeatureRef] = [hour]
            if day % 2 == 0 { features.append(rain); features.append(fae) }
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        XCTAssertNotNil(ledger.row(id))
        ledger.markSpoken(id, now: GrimoireDay.date(for: 41, calendar: calendar), calendar: calendar)

        // More rainy nights, one Fae. Cumulative is 21 of 35 — still over every
        // bar the Book uses. The recent stretch is 1 in 15, and enough of it
        // falls outside the week the Book's own telling covers.
        var later: [LoomObservation] = []
        for day in 40..<70 {
            var features: [LoomFeatureRef] = [hour]
            if day % 2 == 0 {
                features.append(rain)
                if day == 40 { features.append(fae) }
            }
            later.append(observation(day: day, features))
        }
        ledger.ingest(later)
        sweepAll(&ledger, now: GrimoireDay.date(for: 71, calendar: calendar))

        let row = ledger.row(id)!
        let stats = ledger.currentStats(for: row, calendar: calendar)!
        XCTAssertEqual(stats.inCount, 35)
        XCTAssertEqual(stats.inHits, 21)
        XCTAssertGreaterThan(stats.inRate, GrimoireLedger.Bars.minimumInRate, "the average should still look healthy")
        XCTAssertTrue(
            GrimoireLedger.clearsBar(stats, universeCount: ledger.universe.count),
            "the cumulative counts should still pass, or this test proves nothing"
        )
        XCTAssertEqual(row.state, .crossedOut, "the promise should have bitten anyway")
    }

    /// The Book does not mark its own homework.
    ///
    /// A falsifier is measured only on days after the Book spoke — which is
    /// exactly the stretch its own telling has coloured. Tell somebody rain
    /// brings out a word and they notice the word in the rain. Counted, that
    /// belief would confirm itself and pass its own honesty test, which is
    /// worse than having no test at all.
    func testTheBookWillNotJudgeItselfOnTheDaysThatHeardIt() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)

        let rain = condition("weather:rain", domain: "weather", label: "raining")
        let hour = condition("hour:night", domain: "hour", label: "night")
        // Every one of these falls inside the week after the telling.
        ledger.ingest((61..<68).map { observation(day: $0, [hour, rain]) })
        sweepAll(&ledger, now: GrimoireDay.date(for: 68, calendar: calendar))

        XCTAssertEqual(ledger.row(id)?.state, .spoken, "it judged itself on coached days")
        XCTAssertNil(
            ledger.promiseEvidence(for: ledger.row(id)!, calendar: calendar).map(\.chances),
            "no chance should count while the telling is still in the air"
        )

        // Past the shadow, the same collapse is fair game.
        ledger.ingest((70..<80).map { observation(day: $0, [hour, rain]) })
        sweepAll(&ledger, now: GrimoireDay.date(for: 81, calendar: calendar))
        XCTAssertEqual(ledger.row(id)?.state, .crossedOut)
    }

    func testTheDayTheBookSpeaksIsRemembered() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        XCTAssertTrue(ledger.row(id)!.promptedDays.isEmpty)
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)
        XCTAssertTrue(ledger.row(id)!.promptedDays.contains(61))

        // The shadow is clipped to days the Book was actually open, so it only
        // covers a day once that day exists.
        let hour = condition("hour:night", domain: "hour", label: "night")
        ledger.ingest((60..<75).map { observation(day: $0, [hour]) })
        let shadow = ledger.promptedWindow(for: ledger.row(id)!)
        XCTAssertTrue(shadow.contains(61))
        XCTAssertTrue(shadow.contains(65))
        XCTAssertFalse(shadow.contains(70), "the week passes and the days are the reader's again")
    }

    func testACrossedOutClaimIsKeptNotDeleted() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        // Dated on the fixture's clock, not today's: a promise is judged on the
        // days that came after it, so `now` has to belong to the same timeline.
        ledger.markSpoken(id, now: GrimoireDay.date(for: 61, calendar: calendar), calendar: calendar)
        let rain = condition("weather:rain", domain: "weather", label: "raining")
        let hour = condition("hour:night", domain: "hour", label: "night")
        ledger.ingest((70..<80).map { observation(day: $0, [hour, rain]) })
        sweepAll(&ledger, now: GrimoireDay.date(for: 81, calendar: calendar))

        XCTAssertNotNil(ledger.row(id), "the Book tidied away its own mistake")
        XCTAssertEqual(ledger.crossedOut.count, 1)
        let line = GrimoireVoice.crossingOut(row: ledger.row(id)!, ledger: ledger, calendar: calendar)
        XCTAssertTrue(line.hasPrefix("I said"), "a reversal must restate the claim it takes back. got: \(line)")
        XCTAssertTrue(line.contains("chances came"), "and show the counts that broke it. got: \(line)")
    }

    // MARK: Boundaries

    func testAForbiddenReadingNeverComesBack() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        ledger.record(.doNotRead, for: id)
        XCTAssertEqual(ledger.row(id)?.state, .forbidden)

        // More perfect evidence must not reopen the door.
        let rain = condition("weather:rain", domain: "weather", label: "raining")
        let hour = condition("hour:night", domain: "hour", label: "night")
        let fae = outcome("fae:met", domain: "fae", label: "met a Fae")
        ledger.ingest((61..<80).map { observation(day: $0, [hour, rain, fae]) })
        sweepAll(&ledger, now: GrimoireDay.date(for: 81, calendar: calendar))
        XCTAssertEqual(ledger.row(id)?.state, .forbidden)
        XCTAssertFalse(ledger.speakable(calendar: calendar).contains { $0.id == id })
    }

    func testFictionCanSetTheSceneButNeverBeTheClaim() {
        let scene = LoomFeatureRef(
            id: "story:tower", domain: "story", label: "the tower",
            conditionClause: "the tower was in the story", outcomeClause: "the tower appeared",
            role: .either, provenance: .generatedFiction
        )
        let weather = condition("weather:rain", domain: "weather", label: "raining")
        XCTAssertFalse(GrimoireLedger.canPair(weather, scene), "fiction became a claim about the reader")
        XCTAssertTrue(GrimoireLedger.canPair(scene, condition("x", domain: "other")) == false)
        let wrote = outcome("wrote:page", domain: "writing", label: "wrote")
        XCTAssertTrue(GrimoireLedger.canPair(scene, wrote), "fiction should still be allowed to set the scene")
    }

    func testRolesAndFamiliesKeepNonsenseOut() {
        let rain = condition("weather:rain", domain: "weather")
        let fog = condition("weather:fog", domain: "weather")
        let wrote = outcome("wrote:page", domain: "writing")
        XCTAssertFalse(GrimoireLedger.canPair(wrote, rain), "an outcome cannot cause the weather")
        XCTAssertFalse(GrimoireLedger.canPair(rain, fog), "two members of one family is the trivial pairing")
        XCTAssertFalse(GrimoireLedger.canPair(rain, rain))
        XCTAssertTrue(GrimoireLedger.canPair(rain, wrote))
    }

    func testSensitiveFeaturesStayOutOfOrdinarySpeech() {
        var ledger = GrimoireLedger()
        let rain = condition("weather:rain", domain: "weather", label: "raining")
        var mood = outcome("inner:low", domain: "inner", label: "felt low")
        mood.sensitivity = .innerState
        var observations: [LoomObservation] = []
        for day in 0..<40 {
            var features: [LoomFeatureRef] = [condition("hour:night", domain: "hour", label: "night")]
            if day % 6 == 0 { features.append(rain); features.append(mood) }
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "inner:low")
        XCTAssertNotNil(ledger.row(id), "it may still be counted")
        XCTAssertFalse(
            ledger.speakable(calendar: calendar).contains { $0.id == id },
            "but it must not be said without care"
        )
        XCTAssertTrue(
            ledger.speakable(calendar: calendar, allowingSensitive: true).contains { $0.id == id }
        )
    }

    // MARK: Choosing what to say

    func testTheSameThingIsNotSaidTwiceInARow() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        guard let first = ledger.speakable(limit: 1, calendar: calendar).first else {
            return XCTFail("nothing to say")
        }
        let now = GrimoireDay.date(for: 61, calendar: calendar)
        ledger.markSpoken(first.id, now: now, calendar: calendar)
        let again = ledger.speakable(limit: 1, now: now, calendar: calendar)
        XCTAssertNotEqual(again.first?.id, first.id, "the Book repeated itself immediately")
    }

    func testAFamiliarPairingIsWorthLessThanAStrangeOne() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let rain = ledger.ref("weather:rain")!
        let fae = ledger.ref("fae:met")!
        let fresh = GrimoireInterest.unexpectedness(condition: rain, outcome: fae, in: ledger)

        // Say it, so weather-to-Fae becomes a road the Book has walked.
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        ledger.markSpoken(id, calendar: calendar)
        let worn = GrimoireInterest.unexpectedness(condition: rain, outcome: fae, in: ledger)
        XCTAssertLessThan(worn, fresh, "surprise should wear out with use")
    }

    // MARK: Storage

    func testTheWholeLedgerSurvivesBeingSavedAndOpenedAgain() throws {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "fae:met")
        ledger.markSpoken(id, calendar: calendar)

        let data = try JSONEncoder().encode(ledger)
        let restored = try JSONDecoder().decode(GrimoireLedger.self, from: data)

        XCTAssertEqual(restored.featureCount, ledger.featureCount)
        XCTAssertEqual(restored.pairCount, ledger.pairCount)
        XCTAssertEqual(restored.rows.count, ledger.rows.count)
        XCTAssertEqual(restored.row(id)?.state, .spoken)
        XCTAssertFalse(restored.evidencePageIDs(for: restored.row(id)!).isEmpty)
        // The index is not stored; if it did not rebuild, this returns nothing.
        XCTAssertEqual(restored.days(of: "weather:rain").count, 6)
        XCTAssertNotNil(restored.ref("fae:met"))
        XCTAssertEqual(restored.currentStats(for: restored.row(id)!, calendar: calendar)?.inHits, 5)
    }


    // MARK: Work done

    func testASweepWithNothingNewToLookAtDoesAlmostNothing() {
        var ledger = rainyNightArchive()
        sweepAll(&ledger)
        let quiet = ledger.sweep(now: GrimoireDay.date(for: 62, calendar: calendar), calendar: calendar)
        XCTAssertEqual(quiet.pairsExamined, 0, "the sweep re-examined pairs nothing had touched")
        XCTAssertTrue(quiet.finished)
    }

    func testOnlyPairsThatActuallyLandedTogetherAreEverRemembered() {
        let ledger = rainyNightArchive()
        // Six features in the fixture. The cross product would be 30 ordered
        // pairs; only the ones that co-occurred, in allowed directions, exist.
        XCTAssertLessThan(ledger.pairCount, 20)
        XCTAssertGreaterThan(ledger.pairCount, 0)
    }
}

/// A Book that can be sure of everything is sure of nothing.
///
/// The cabinet holds a fixed number of convictions. Getting in means being
/// steadier than the weakest thing already there, and that one is let go — a
/// change of mind about what the Book is *sure of*, not about what is true.
final class GrimoireConvictionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func feature(
        _ id: String, _ domain: String, role: LoomFeatureRole
    ) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: id,
            conditionClause: "it was \(id)", outcomeClause: "you \(id)",
            role: role, provenance: .readerAuthored
        )
    }

    /// Many rules, all strong enough to be held, so the cabinet has to choose.
    private func crowdedObservations() -> [LoomObservation] {
        var observations: [LoomObservation] = []
        let hour = feature("hour:night", "hour", role: .conditionOnly)
        for day in 0..<300 {
            var features: [LoomFeatureRef] = [hour]
            // Deliberately muddy: each word also turns up on days its weather
            // did not. Every rule in the earlier fixture was perfect, so every
            // one scored exactly 100 — and `strength > weakest` is never true
            // among equals. The cabinet filled in queue order and let nothing
            // go, which the displacement tests below could only "pass" because
            // that order used to be hash-random.
            for rule in 0..<8 {
                let condition = day % (rule + 3) == 0
                if condition {
                    features.append(feature("weather:w\(rule)", "weather-\(rule)", role: .conditionOnly))
                }
                let follows = condition && (day / (rule + 3)) % 10 < 7
                let anyway = day % 2 == 0 && day % (rule + 5) != 0
                if follows || anyway {
                    features.append(feature("word:w\(rule)", "word-\(rule)", role: .outcomeOnly))
                }
            }
            // A late bloomer, and a clean one: nearly absent while the cabinet
            // fills, then constant. This is the newcomer worth making room for.
            if day % 23 == 0 || day >= 150 {
                features.append(feature("weather:late", "weather-late", role: .conditionOnly))
                features.append(feature("word:late", "word-late", role: .outcomeOnly))
            }
            observations.append(LoomObservation(
                id: "day-\(day)", day: day,
                occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "page-\(day)", evidenceLine: ""
            ))
        }
        return observations
    }

    private func crowdedLedger() -> GrimoireLedger {
        var ledger = GrimoireLedger()
        let observations = crowdedObservations()
        // In two halves, the way a Book actually lives: it finds things, says
        // them, and then more days arrive. Speaking does not dirty a pair, so a
        // fixture that ingests everything and *then* speaks would never run the
        // promotion path at all — and every assertion below would pass while
        // testing nothing.
        let now = GrimoireDay.date(for: 301, calendar: calendar)
        func drain() {
            var passes = 0
            while true {
                let report = ledger.sweep(now: now, budget: 2_000, calendar: calendar)
                passes += 1
                if report.finished || passes > 200 { break }
            }
        }
        ledger.ingest(observations.filter { $0.day < 150 })
        drain()
        // Sorted, because `rows.values` comes out in a different order every
        // process. Which rules get spoken first decides which ones are eligible
        // for the cabinet later, so an unsorted fixture made the displacement
        // assertions below fail roughly one run in six.
        for id in ledger.rows.values.filter({ $0.isAlive }).map(\.id).sorted() {
            ledger.markSpoken(id, now: now, calendar: calendar)
        }
        ledger.ingest(observations.filter { $0.day >= 150 })
        drain()
        return ledger
    }

    func testTheBookIsNeverSureOfMoreThanItCanHold() {
        let ledger = crowdedLedger()
        let held = ledger.rows.values.filter { $0.state == .standing }.count
        XCTAssertGreaterThan(ledger.rows.count, GrimoireLedger.Bars.maximumHeld,
                             "the fixture needs more candidates than the cabinet holds")
        // Not vacuous: it must actually be holding things, at the cap.
        XCTAssertEqual(held, GrimoireLedger.Bars.maximumHeld)
    }

    /// The same archive must make the same Book.
    ///
    /// Handed the same days in two different batch orders, the ledger has to
    /// end up sure of the same things. It did not: the candidate queue was
    /// rebuilt with `Array(Set<UInt64>)`, whose order Swift seeds per process,
    /// and the conviction cabinet is capped — so the order pairs were examined
    /// in decided which rules got in. Roughly one run in six, a different Book.
    func testTheSameArchiveMakesTheSameConvictions() {
        func held(shuffledBy seed: Int) -> [String] {
            var ledger = GrimoireLedger()
            let now = GrimoireDay.date(for: 301, calendar: calendar)
            var all = crowdedObservations()
            // A different insertion order gives the set a different layout,
            // which is the same thing a fresh process does to it.
            if seed > 0 {
                all = all.enumerated()
                    .sorted { ($0.offset * seed) % 97 < ($1.offset * seed) % 97 }
                    .map(\.element)
            }
            func drain() {
                var passes = 0
                while !ledger.sweep(now: now, budget: 2_000, calendar: calendar).finished, passes < 200 {
                    passes += 1
                }
            }
            ledger.ingest(all.filter { $0.day < 150 })
            drain()
            for id in ledger.rows.values.filter({ $0.isAlive }).map(\.id).sorted() {
                ledger.markSpoken(id, now: now, calendar: calendar)
            }
            ledger.ingest(all.filter { $0.day >= 150 })
            drain()
            return ledger.rows.values.filter { $0.state == .standing }.map(\.id).sorted()
        }
        let first = held(shuffledBy: 0)
        XCTAssertFalse(first.isEmpty, "the fixture held nothing")
        for seed in [7, 31, 53] {
            XCTAssertEqual(first, held(shuffledBy: seed), "a different order made a different Book")
        }
    }

    func testLettingOneGoIsRecordedAndNotSilent() {
        let ledger = crowdedLedger()
        let released = ledger.rows.values.filter { row in
            row.revisions.contains { $0.to == .spoken && $0.because.contains("made room") }
        }
        XCTAssertFalse(released.isEmpty, "the cabinet filled without anything being let go")
        // Let go, not thrown away: still something the Book has said.
        for row in released { XCTAssertTrue(row.isAlive) }
    }

    /// Nothing is let go in favour of something weaker.
    ///
    /// This used to compare the weakest held rule against the strongest rule
    /// the Book had merely said, which is not a promise the cabinet makes. A
    /// rule is only weighed against the cabinet on a day its own evidence
    /// moved; one that goes quiet keeps the strength it had and is never
    /// reconsidered, so it can sit outside while being steadier than something
    /// inside. That is the Book holding what it was sure of when it last
    /// looked. What it must never do is trade down.
    func testNothingIsLetGoForSomethingWeaker() throws {
        let ledger = crowdedLedger()
        let steadiestHeld = try XCTUnwrap(
            ledger.rows.values.filter { $0.state == .standing }.map(\.strengthPeak).max()
        )
        let displaced = ledger.rows.values.filter { row in
            row.revisions.contains { $0.to == .spoken && $0.because.contains("made room") }
        }
        XCTAssertFalse(displaced.isEmpty, "nothing was displaced in this fixture")
        for row in displaced {
            XCTAssertLessThanOrEqual(
                row.strengthPeak, steadiestHeld,
                "let go of something steadier than anything it kept: \(row.id)"
            )
        }
    }
}
