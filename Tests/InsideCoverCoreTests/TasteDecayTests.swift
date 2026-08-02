import XCTest
@testable import InsideCoverCore

/// The taste model used to hold every preference at full strength forever. Its
/// counters only ever went up, so a family the reader loved in their first month
/// argued exactly as hard in year three — and because the tables were folded
/// incrementally while the event log was capped, they also kept scoring answers
/// the log itself had long since dropped. A reader who changed had no way to say
/// so except by contradicting themselves more times than they had ever agreed.
///
/// Taste now fades, and it fades in the reader's own answering time rather than
/// the calendar. These pin what that must and must not cost them.
final class TasteDecayTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func start() -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 9))!
    }

    // MARK: - Fading

    func testAThinTasteStopsSteeringOnceItHasGoneQuiet() {
        let base = start()
        var fresh = ReaderLearningModel()
        for index in 0..<3 {
            fresh.record(event(.loved, at: base.addingTimeInterval(Double(index) * 3_600)))
        }
        let whileWarm = fresh.scoreAdjustment(for: page())

        // The reader keeps reading for the best part of a year, but never answers
        // for this family again.
        var cooled = fresh
        for index in 0..<40 {
            cooled.record(event(
                .kept,
                at: base.addingTimeInterval(Double(index + 1) * 9 * 86_400),
                sourceID: "elsewhere",
                type: .lore
            ))
        }
        let whenStale = cooled.scoreAdjustment(for: page())

        XCTAssertGreaterThan(whileWarm, 0)
        XCTAssertLessThan(
            whenStale,
            whileWarm / 2,
            "Three loves from a year of answers ago still argued at nearly full strength."
        )
    }

    /// Fading must not become forgetting. A preference the reader established
    /// thoroughly should survive a long quiet stretch — it is thin evidence that
    /// is perishable, not everything.
    func testAWellEstablishedTasteSurvivesTheSameSilence() {
        let base = start()
        var model = ReaderLearningModel()
        for index in 0..<20 {
            model.record(event(.loved, at: base.addingTimeInterval(Double(index) * 3_600)))
        }
        for index in 0..<40 {
            model.record(event(
                .kept,
                at: base.addingTimeInterval(Double(index + 1) * 9 * 86_400),
                sourceID: "elsewhere",
                type: .lore
            ))
        }

        XCTAssertGreaterThan(
            model.scoreAdjustment(for: page()),
            0,
            "A thoroughly established preference was forgotten wholesale."
        )
    }

    func testAFreshContradictionOutweighsAnOldEnthusiasm() {
        let base = start()
        var model = ReaderLearningModel()
        for index in 0..<4 {
            model.record(event(.loved, at: base.addingTimeInterval(Double(index) * 3_600)))
        }
        let whileLoved = model.scoreAdjustment(for: page())

        // Half a year of answering later, the reader turns the same family down.
        for index in 0..<3 {
            model.record(event(
                .dismissed,
                at: base.addingTimeInterval(180 * 86_400 + Double(index) * 3_600)
            ))
        }

        XCTAssertGreaterThan(whileLoved, 0)
        XCTAssertLessThan(
            model.scoreAdjustment(for: page()),
            0,
            "An old enthusiasm outvoted the reader's most recent answer."
        )
    }

    /// Exploration should reopen on a question whose answer has gone stale, or a
    /// conversation neither party remembers goes on closing it.
    func testExplorationReopensOnceASettledQuestionGoesStale() {
        let base = start()
        var model = ReaderLearningModel()
        let recipeTag = "recipe:night-errand"
        for index in 0..<5 {
            model.record(event(
                .kept,
                at: base.addingTimeInterval(Double(index) * 3_600),
                tags: [recipeTag]
            ))
        }
        let whileSettled = model.storyExplorationWidth(recipeID: "night-errand")

        for index in 0..<40 {
            model.record(event(
                .kept,
                at: base.addingTimeInterval(Double(index + 1) * 9 * 86_400),
                sourceID: "elsewhere",
                type: .lore
            ))
        }

        XCTAssertEqual(whileSettled, 1, "Five answers should have closed the question.")
        XCTAssertGreaterThan(
            model.storyExplorationWidth(recipeID: "night-errand"),
            whileSettled,
            "A question answered long ago stayed closed forever."
        )
    }

    // MARK: - What fading must not cost

    /// Staleness means "many answers ago", never "long ago". A reader who simply
    /// lived their life for six months and came back must find the Book exactly
    /// where they left it — the same rule the Book already holds elsewhere, that
    /// time away cannot be counted against a reader.
    func testTimeAwayFromTheBookCostsTheReaderNothing() {
        func model(startingAt base: Date) -> ReaderLearningModel {
            var model = ReaderLearningModel()
            for index in 0..<5 {
                model.record(event(.loved, at: base.addingTimeInterval(Double(index) * 3_600)))
                model.record(event(
                    .keepsakeEarned,
                    at: base.addingTimeInterval(Double(index) * 3_600 + 60)
                ))
            }
            return model
        }
        let recent = model(startingAt: start())
        let longAgo = model(startingAt: start().addingTimeInterval(-5 * 365 * 86_400))

        XCTAssertGreaterThan(recent.scoreAdjustment(for: page()), 0)
        XCTAssertEqual(
            longAgo.scoreAdjustment(for: page()),
            recent.scoreAdjustment(for: page()),
            "Being away from the Book cost the reader taste they had taught it."
        )
    }

    /// Fading governs what the desk does next. It must never edit the record of
    /// what actually happened, which receipts and metrics are built from.
    func testTheLifetimeRecordIsNeverRewritten() {
        let base = start()
        var model = ReaderLearningModel()
        for index in 0..<3 {
            model.record(event(.keepsakeEarned, at: base.addingTimeInterval(Double(index) * 3_600)))
        }
        for index in 0..<40 {
            model.record(event(
                .kept,
                at: base.addingTimeInterval(Double(index + 1) * 9 * 86_400),
                sourceID: "elsewhere",
                type: .lore
            ))
        }
        let affinity = model.sourceAffinities["source-1"]

        XCTAssertEqual(affinity?.keepsakeEarned, 3)
        XCTAssertEqual(affinity?.crossingSignals, 3)
        XCTAssertEqual(affinity?.rawScore, 30)
        XCTAssertEqual(affinity?.meaningfulSignals, 3)
        XCTAssertLessThan(
            affinity?.crossingScore(asOf: base.addingTimeInterval(360 * 86_400)) ?? 0,
            affinity?.crossingScore ?? 0,
            "The faded reading should sit below the lifetime one after a long silence."
        )
    }

    // MARK: - Migration

    /// A ledger saved before taste faded carries counters but no faded totals.
    /// The version bump has to replay its retained log, or every existing reader
    /// would open the Book to a Curator that had forgotten them.
    func testALedgerSavedBeforeFadingRelearnsItselfFromItsLog() throws {
        let base = start()
        var model = ReaderLearningModel()
        for index in 0..<6 {
            model.record(event(.loved, at: base.addingTimeInterval(Double(index) * 3_600)))
        }
        XCTAssertGreaterThan(model.scoreAdjustment(for: page()), 0)

        // Rewrite it as a version-6 ledger: counters and events intact, faded
        // totals absent, exactly as an older build would have left it.
        var json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any]
        )
        json["version"] = 6
        for table in ["sourceAffinities", "typeAffinities", "tagAffinities", "contentAffinities"] {
            guard var affinities = json[table] as? [String: Any] else { continue }
            for (key, value) in affinities {
                guard var affinity = value as? [String: Any] else { continue }
                affinity["fadedTaste"] = nil
                affinity["fadedCrossing"] = nil
                affinity["fadedSignals"] = nil
                affinities[key] = affinity
            }
            json[table] = affinities
        }
        let legacy = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(ReaderLearningModel.self, from: legacy)

        XCTAssertEqual(decoded.version, ReaderLearningModel.currentVersion)
        XCTAssertEqual(
            decoded.scoreAdjustment(for: page()),
            model.scoreAdjustment(for: page()),
            "An older ledger did not recover its taste from its own event log."
        )
    }

    // MARK: - Fixtures

    private func event(
        _ action: ReaderLearningAction,
        at date: Date,
        sourceID: String = "source-1",
        type: BookPageType = .souvenir,
        tags: [String] = []
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: "\(action.rawValue)-\(date.timeIntervalSince1970)-\(sourceID)",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: action,
            surfaceID: "surface-\(sourceID)",
            sourceID: sourceID,
            type: type,
            varietyKey: "variety-\(sourceID)",
            hour: calendar.component(.hour, from: date),
            tags: tags
        )
    }

    private func page(
        sourceID: String = "source-1",
        type: BookPageType = .souvenir
    ) -> SurfacePage {
        SurfacePage(
            id: "decay-\(sourceID)",
            type: type,
            sourceID: sourceID,
            intent: .capture,
            score: 60,
            prompt: type.title,
            detail: "A decay fixture.",
            payload: BookPagePayload(headline: type.title, body: "b", metadata: [:])
        )
    }
}
