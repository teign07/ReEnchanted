import XCTest
@testable import InsideCoverCore

/// The register, as a test rather than a note in a document.
///
/// The Book states its correspondences flat and pays for that with a promise it
/// keeps. The failure mode this guards against is the slow return of hedging —
/// a "may", a "perhaps", a "tends to" creeping into a pool at a time until the
/// Book sounds like a weather forecast again.
final class GrimoireVoiceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// Words that turn a claim into mush. The Book may be wrong; it may not be
    /// vague.
    private let hedges = [
        "may ", "maybe", "perhaps", "possibly", "might ", "tends to", "seems",
        "appears to", "somewhat", "arguably", "it is likely", "suggests that",
        "could indicate", "potentially", "in some cases"
    ]

    /// Report-speak. The Book is a character, not a dashboard.
    private let clerical = [
        "data", "correlat", "statistic", "metric", "analysis", "p-value",
        "significant", "sample size", "variable", "dataset"
    ]

    private func ledgerWithEveryShape() -> GrimoireLedger {
        var ledger = GrimoireLedger()
        let night = LoomFeatureRef(
            id: "hour:night", domain: "hour", label: "night",
            conditionClause: "it was night", outcomeClause: "you came at night",
            role: .conditionOnly, rank: 15
        )
        let rain = LoomFeatureRef(
            id: "weather:rain", domain: "weather", label: "rain",
            conditionClause: "it was raining", outcomeClause: "the sky was raining",
            role: .conditionOnly, rank: 10
        )
        let fae = LoomFeatureRef(
            id: "fae:met", domain: "fae", label: "the Fae",
            conditionClause: "the Fae were about", outcomeClause: "you met a Fae",
            role: .either, provenance: .readerAuthored, rank: 60
        )
        let photo = LoomFeatureRef(
            id: "media:photograph", domain: "media", label: "a photograph",
            conditionClause: "you had taken a photograph", outcomeClause: "you kept a photograph",
            role: .either, provenance: .readerAuthored, rank: 72
        )

        var observations: [LoomObservation] = []
        // Four years, so the seasonal shape has something to say too.
        for day in 0..<1_200 {
            var features: [LoomFeatureRef] = [night]
            if day % 7 == 0 {
                features.append(rain)
                if day % 21 != 0 { features.append(fae) }
            }
            if day % 7 == 2 { features.append(photo) }
            if GrimoireDay.season(of: day) == 1, day % 11 == 0 {
                features.append(LoomFeatureRef(
                    id: "fae:salamanders", domain: "ritual", label: "the Sentence Salamanders",
                    conditionClause: "the Salamanders were calling",
                    outcomeClause: "you answered the Salamanders",
                    role: .either, provenance: .readerAuthored
                ))
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
            let report = ledger.sweep(now: GrimoireDay.date(for: 1_201, calendar: calendar),
                                      budget: 900, calendar: calendar)
            passes += 1
            if report.finished || passes > 80 { break }
        }
        return ledger
    }

    private func everyLine(_ ledger: GrimoireLedger) -> [String] {
        ledger.rows.values.flatMap { row -> [String] in
            guard let stats = ledger.currentStats(for: row, calendar: calendar) else { return [] }
            let lines = [
                GrimoireVoice.claim(row: row, stats: stats, ledger: ledger, calendar: calendar),
                GrimoireVoice.evidence(row: row, stats: stats, ledger: ledger, calendar: calendar),
                GrimoireVoice.promise(row: row, stats: stats, ledger: ledger),
                GrimoireVoice.crossingOut(row: row, ledger: ledger, calendar: calendar),
                GrimoireVoice.noticeTitle(row: row),
                GrimoireVoice.editionTitle(row: row, ledger: ledger),
                GrimoireVoice.entry(row: row, ledger: ledger, calendar: calendar),
                GrimoireVoice.prediction(row: row, ledger: ledger, calendar: calendar),
                GrimoireVoice.experimentSummons(row: row, ledger: ledger, calendar: calendar)
            ] + GrimoireExperiment.Verdict.allCases.flatMap { verdict -> [String] in
                // The Book's own tests speak on the same Pages as everything
                // else, so they answer to the same voice rules.
                var experiment = GrimoireExperiment(
                    id: "e", rowID: row.id, recipeID: "r", outcomeID: row.outcomeID ?? "",
                    predictedAt: Date(), windowDays: 3, verdict: verdict, prediction: ""
                )
                experiment.verdict = verdict
                return [
                    GrimoireVoice.experimentResult(experiment, row: row, ledger: ledger, calendar: calendar),
                    GrimoireVoice.experimentTitle(experiment)
                ]
            }
            return lines.filter { !$0.isEmpty }
        }
    }

    /// Weather tags are nouns and adjectives in one list. Both end up inside a
    /// claim the reader is being asked to check, so both have to be sentences.
    func testEveryWeatherWordMakesASentence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let tags = [
            "rain", "snow", "fog", "wind", "storm", "hail", "sleet", "mist", "sun",
            "clouds", "ice", "frost", "drizzle", "clear", "cloudy", "overcast",
            "cold", "warm", "humid", "grey", "freezing", "fogbow"
        ]
        for tag in tags {
            let context = BookPageContextSnapshot(
                at: Date(), calendar: calendar, weatherTags: [tag]
            )
            let refs = WorldConditionsProjector.features(for: context)
            guard let weather = refs.first(where: { $0.domain == "weather" }) else {
                XCTFail("\(tag) produced no weather feature"); continue
            }
            // The two shapes these clauses actually get dropped into.
            let condition = "When \(weather.conditionClause), you wrote longer."
            let outcome = "It happens, and then \(weather.outcomeClause)."
            // "The sky was clear" is a sentence; "the sky was rain" is not.
            // Only the nouns are barred from sitting where an adjective goes.
            let nouns = [
                "rain", "snow", "fog", "wind", "storm", "hail", "sleet", "mist",
                "sun", "clouds", "ice", "frost", "drizzle", "fogbow"
            ]
            if nouns.contains(tag) {
                for line in [condition, outcome] {
                    XCTAssertFalse(
                        line.contains("was \(tag) ") || line.contains("was \(tag)."),
                        "bare noun dropped into a sentence: \(line)"
                    )
                }
            }
            // No clause is left as a bare noun phrase with no verb in it.
            XCTAssertTrue(
                ["was", "were", "came", "is", "out"].contains(where: {
                    weather.conditionClause.contains($0)
                }),
                "no verb in: \(weather.conditionClause)"
            )
            XCTAssertTrue(
                ["was", "were", "came", "is", "out"].contains(where: {
                    weather.outcomeClause.contains($0)
                }),
                "no verb in: \(weather.outcomeClause)"
            )
        }
    }

    /// The Book talks like a child who lives here, not like a report.
    ///
    /// Contractions by default. Not a blanket ban on the long forms — a few
    /// lines earn them, and those are listed here by hand so that keeping one
    /// is a decision somebody made rather than a line nobody contracted.
    func testTheBookUsesContractions() {
        // Kept long, on purpose:
        //   "I will say so out loud" — the falsifier. It is a vow, and a vow
        //      said in full is heavier than one said quickly.
        //   "I have to take something back" — "I've to" is not English.
        let deliberatelyLong = ["I will say so out loud", "I have to take something back"]
        let longForms = [
            "I am ", "I have ", "I will ", "I would ", "do not", "does not", "did not",
            "is not", "was not", "it is ", "It is ", "that is ", "That is ",
            "there is ", "There is ", "you are ", "cannot", "will not", "has not", "are not"
        ]
        for line in everyLine(ledgerWithEveryShape()) {
            var remaining = line
            for kept in deliberatelyLong {
                remaining = remaining.replacingOccurrences(of: kept, with: "")
            }
            for form in longForms {
                XCTAssertFalse(
                    remaining.contains(form),
                    "“\(form.trimmingCharacters(in: .whitespaces))” wants contracting: \(line)"
                )
            }
        }
    }

    func testTheBookNeverHedgesACorrespondence() {
        let lines = everyLine(ledgerWithEveryShape())
        XCTAssertFalse(lines.isEmpty, "nothing to check")
        for line in lines {
            let lower = line.lowercased()
            for hedge in hedges {
                XCTAssertFalse(lower.contains(hedge), "hedged with “\(hedge)”: \(line)")
            }
        }
    }

    func testTheBookNeverSoundsLikeADashboard() {
        for line in everyLine(ledgerWithEveryShape()) {
            let lower = line.lowercased()
            for word in clerical {
                XCTAssertFalse(lower.contains(word), "clerical voice “\(word)”: \(line)")
            }
        }
    }

    func testEveryShapeHasSomethingToSay() {
        let ledger = ledgerWithEveryShape()
        var shapesSeen = Set<GrimoireShape>()
        for row in ledger.rows.values {
            guard let stats = ledger.currentStats(for: row, calendar: calendar) else { continue }
            let claim = GrimoireVoice.claim(row: row, stats: stats, ledger: ledger, calendar: calendar)
            XCTAssertFalse(claim.isEmpty, "\(row.shape) had no words for itself")
            shapesSeen.insert(row.shape)
        }
        XCTAssertTrue(shapesSeen.contains(.conditional))
        XCTAssertTrue(shapesSeen.contains(.sequential))
        XCTAssertTrue(shapesSeen.contains(.seasonal))
    }

    func testSentencesAreShortEnoughToBeSpoken() {
        // Not a style preference: a correspondence lands in a margin, and a
        // 40-word sentence in a margin is a wall.
        for line in everyLine(ledgerWithEveryShape()) {
            for sentence in line.split(separator: ".") {
                let words = sentence.split(separator: " ").count
                XCTAssertLessThanOrEqual(words, 34, "a sentence ran long: \(sentence)")
            }
        }
    }

    func testEveryPromiseNamesWhatWouldBreakIt() {
        let ledger = ledgerWithEveryShape()
        for row in ledger.rows.values {
            guard let stats = ledger.currentStats(for: row, calendar: calendar) else { continue }
            let promise = GrimoireVoice.promise(row: row, stats: stats, ledger: ledger)
            XCTAssertFalse(promise.isEmpty)
            // A promise is only a promise if it says what taking it back looks
            // like. Adding a new phrasing to the pool means adding its marker
            // here on purpose — that is what this test is for.
            let forfeits = ["gets crossed out", "the pencil comes out and this goes", "I was wrong"]
            XCTAssertTrue(
                forfeits.contains(where: promise.contains),
                "a promise with no forfeit: \(promise)"
            )
        }
    }

    func testAReversalAlwaysRestatesWhatItTakesBack() {
        var ledger = ledgerWithEveryShape()
        guard let target = ledger.rows.values.first(where: { $0.shape == .conditional }) else {
            return XCTFail("no correspondence to reverse")
        }
        ledger.markSpoken(target.id, calendar: calendar)
        var row = ledger.rows[target.id]!
        row.state = .crossedOut
        row.revisions.append(GrimoireRevision(
            at: Date(), from: .spoken, to: .crossedOut, because: "it stopped happening"
        ))
        ledger.rows[target.id] = row

        let line = GrimoireVoice.crossingOut(row: row, ledger: ledger, calendar: calendar)
        XCTAssertTrue(line.hasPrefix("I said"), "got: \(line)")
        XCTAssertTrue(line.contains("it stopped happening"), "the reason went missing: \(line)")
        // The reversal is content, not an apology.
        XCTAssertFalse(line.lowercased().contains("sorry"))
        XCTAssertEqual(GrimoireVoice.entry(row: row, ledger: ledger, calendar: calendar), line)
    }

    /// `outcomeClause` is a finished statement — "you wrote the word lantern" —
    /// so a promise that drops it in where a noun belongs reads as nonsense:
    /// "if you wrote the word lantern stops following". The promise is the most
    /// load-bearing sentence in the whole design; it has to survive any clause.
    func testAPromiseNeverSwallowsTheOutcomeClauseWhole() throws {
        let ledger = ledgerWithEveryShape()
        for row in ledger.rows.values {
            guard let stats = ledger.currentStats(for: row, calendar: calendar) else { continue }
            guard let outcome = row.outcomeID.flatMap({ ledger.ref($0) }) else { continue }
            let promise = GrimoireVoice.promise(row: row, stats: stats, ledger: ledger)
            XCTAssertFalse(
                promise.contains(outcome.outcomeClause),
                "the promise embedded the outcome clause: \(promise)"
            )
        }
    }

    func testTheBookAnswersTheReaderInItsOwnEstablishedWords() {
        // Reuses the wording the rest of the Book already uses, so a reader who
        // corrects a correspondence never meets a second Book.
        XCTAssertEqual(
            GrimoireVoice.answer(to: .confirmed),
            BookObservationStatus.confirmed.feedbackReactionLine
        )
        XCTAssertEqual(
            GrimoireVoice.answer(to: .doNotRead),
            BookObservationStatus.doNotRead.feedbackReactionLine
        )
    }
}
