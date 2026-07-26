import XCTest
@testable import InsideCoverCore

/// The curator's taste model used to record crossings and then throw them
/// away: a Page that sent the reader outside and brought them back with a
/// keepsake scored zero, while a tapped heart scored six. These pin the
/// corrected hierarchy, which now matches the one the causal layer already
/// used for lived outcomes.
final class ReaderLearningCrossingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func now() -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))!
    }

    private func event(
        _ action: ReaderLearningAction,
        at date: Date,
        surfaceID: String = "surface-1",
        sourceID: String = "source-1",
        type: BookPageType = .souvenir,
        tags: [String] = []
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: "\(action.rawValue)-\(date.timeIntervalSince1970)-\(surfaceID)",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: action,
            surfaceID: surfaceID,
            sourceID: sourceID,
            type: type,
            varietyKey: "variety-\(sourceID)",
            hour: calendar.component(.hour, from: date),
            tags: tags
        )
    }

    private func affinity(_ actions: [ReaderLearningAction]) -> ReaderLearningAffinity {
        var affinity = ReaderLearningAffinity()
        for (index, action) in actions.enumerated() {
            affinity.record(event(action, at: now().addingTimeInterval(Double(index) * 60)))
        }
        return affinity
    }

    // MARK: - The hierarchy

    func testCrossingsOutrankAppraisalsMadeInsideTheBook() {
        let keepsake = affinity([.keepsakeEarned]).rawScore
        let returned = affinity([.followedThread]).rawScore
        let loved = affinity([.loved]).rawScore
        let kept = affinity([.kept]).rawScore
        let acted = affinity([.acted]).rawScore

        XCTAssertGreaterThan(keepsake, returned)
        XCTAssertGreaterThan(returned, loved, "a later return must outrank a tapped heart")
        XCTAssertGreaterThan(loved, kept)
        XCTAssertGreaterThan(kept, acted)
        XCTAssertGreaterThan(acted, 0)
    }

    /// The ordering here must not disagree with the one the causal layer uses
    /// when it scores the very same actions as lived outcomes. Those two
    /// layers contradicting each other is the bug this file exists for.
    func testTasteModelOrderingMatchesTheCausalLayer() {
        let tasteOrder: [ReaderLearningAction] = [.keepsakeEarned, .followedThread, .loved, .kept, .acted]
        let scores = tasteOrder.map { affinity([$0]).rawScore }
        XCTAssertEqual(scores, scores.sorted(by: >), "taste ordering drifted from the causal hierarchy")
    }

    func testDismissalsAndMissesStillCool() {
        XCTAssertLessThan(affinity([.dismissed]).rawScore, 0)
        XCTAssertLessThan(affinity([.missed]).rawScore, affinity([.dismissed]).rawScore)
    }

    func testBeingShownAPageOrGlancingAtItTeachesNothing() {
        for action in [ReaderLearningAction.surfaced, .opened, .recognized] {
            let affinity = affinity([action])
            XCTAssertEqual(affinity.rawScore, 0, "\(action) must not warm the taste model")
            XCTAssertEqual(affinity.meaningfulSignals, 0, "\(action) must not count as confidence")
        }
    }

    func testKeepFallbackRemainsMomentumOnlyAndDoesNotWarmTaste() {
        var model = ReaderLearningModel()
        let openedAt = now()
        model.record(event(.opened, at: openedAt))
        model.record(event(
            .acted,
            at: openedAt.addingTimeInterval(10),
            tags: [ReaderLearningEvent.momentumOnlyTag]
        ))
        model.record(event(.kept, at: openedAt.addingTimeInterval(11)))

        XCTAssertEqual(model.momentumMetrics().acted, 1)
        XCTAssertEqual(model.momentumMetrics().actionsWithinThirtySeconds, 1)
        XCTAssertEqual(model.sourceAffinities["source-1"]?.acted, 0)
        XCTAssertEqual(model.sourceAffinities["source-1"]?.kept, 1)
        XCTAssertEqual(model.sourceAffinities["source-1"]?.rawScore, 3)
    }

    func testOnlyBeyondSessionCrossingsReceiveTheCrossingLabel() {
        let affinity = affinity([.followedThread, .keepsakeEarned, .acted])
        XCTAssertEqual(affinity.meaningfulSignals, 3)
        XCTAssertEqual(affinity.crossingSignals, 2)
        XCTAssertEqual(affinity.crossingScore, 5)
        XCTAssertGreaterThan(affinity.curationAdjustment(scale: 5, maximum: 12), 0)
    }

    func testAPageThatMovedTheReaderOutranksOneTheyOnlyAdmired() {
        let admired = affinity([.opened, .loved, .loved, .loved])
        let moved = affinity([.opened, .followedThread, .followedThread, .followedThread])
        XCTAssertGreaterThan(
            moved.curationAdjustment(scale: 5, maximum: 12),
            admired.curationAdjustment(scale: 5, maximum: 12)
        )
    }

    // MARK: - Ranking actually shifts

    func testCuratorRankingFavoursTheFamilyThatCrossedIntoLife() {
        var model = ReaderLearningModel()
        let start = now()
        // One family the reader kept looking at; one that took them outside.
        for index in 0..<3 {
            let at = start.addingTimeInterval(Double(index) * 3600)
            model.record(event(.loved, at: at, surfaceID: "admired-\(index)", sourceID: "admired", type: .lore))
        }
        for index in 0..<3 {
            let at = start.addingTimeInterval(Double(index) * 3600)
            model.record(event(.followedThread, at: at, surfaceID: "crossed-\(index)", sourceID: "crossed", type: .wonderCompass))
        }

        let admired = SurfacePage(
            id: "admired-next",
            type: .lore,
            sourceID: "admired",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 50,
            reason: "r",
            prompt: "p",
            detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: [:])
        )
        let crossed = SurfacePage(
            id: "crossed-next",
            type: .wonderCompass,
            sourceID: "crossed",
            intent: .capture,
            renderStyle: .loreLetter,
            score: 50,
            reason: "r",
            prompt: "p",
            detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: [:])
        )

        XCTAssertGreaterThan(
            model.scoreAdjustment(for: crossed),
            model.scoreAdjustment(for: admired),
            "the desk must lean toward what took the reader out of the app"
        )
        // Loving a family repeatedly pegs it at the taste ceiling; the crossed
        // family clears that ceiling on evidence the Book cannot award itself.
        XCTAssertLessThanOrEqual(model.scoreAdjustment(for: admired), 12)
        XCTAssertGreaterThan(model.scoreAdjustment(for: crossed), 12)
        XCTAssertLessThanOrEqual(model.scoreAdjustment(for: crossed), ReaderLearningModel.maximumAdjustment)
    }

    func testNoAmountOfInAppApprovalReachesTheCrossingCeiling() {
        var model = ReaderLearningModel()
        let start = now()
        for index in 0..<40 {
            let at = start.addingTimeInterval(Double(index) * 600)
            model.record(event(.loved, at: at, surfaceID: "loved-\(index)", sourceID: "admired", type: .lore))
            model.record(event(.kept, at: at.addingTimeInterval(60), surfaceID: "kept-\(index)", sourceID: "admired", type: .lore))
            model.record(event(.acted, at: at.addingTimeInterval(120), surfaceID: "acted-\(index)", sourceID: "admired", type: .lore))
        }
        let admired = SurfacePage(
            id: "admired-next",
            type: .lore,
            sourceID: "admired",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 50,
            reason: "r",
            prompt: "p",
            detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: [:])
        )
        XCTAssertLessThanOrEqual(
            model.scoreAdjustment(for: admired),
            12,
            "in-app approval must top out at the taste cap, however much of it there is"
        )
        XCTAssertLessThan(
            model.scoreAdjustment(for: admired),
            ReaderLearningModel.maximumAdjustment,
            "the points above the taste cap must stay unreachable without a crossing"
        )
    }

    // MARK: - Migration

    func testOlderLedgerRecoversItsCrossingsFromTheEventLog() throws {
        var model = ReaderLearningModel()
        let start = now()
        model.record(event(.keepsakeEarned, at: start, surfaceID: "s1", sourceID: "walks"))
        model.record(event(.followedThread, at: start.addingTimeInterval(60), surfaceID: "s2", sourceID: "walks"))

        // Simulate a ledger written before crossings were scored: the events
        // survived, the counters never existed.
        var stale = model
        stale.version = 2
        stale.sourceAffinities["walks"]?.keepsakeEarned = 0
        stale.sourceAffinities["walks"]?.followedThread = 0
        XCTAssertEqual(stale.sourceAffinities["walks"]?.rawScore, 0)

        let data = try JSONEncoder().encode(stale)
        let migrated = try JSONDecoder().decode(ReaderLearningModel.self, from: data)

        XCTAssertEqual(migrated.version, ReaderLearningModel.currentVersion)
        XCTAssertEqual(migrated.sourceAffinities["walks"]?.keepsakeEarned, 1)
        XCTAssertEqual(migrated.sourceAffinities["walks"]?.followedThread, 1)
        XCTAssertEqual(migrated.sourceAffinities["walks"]?.rawScore, model.sourceAffinities["walks"]?.rawScore)
    }

    func testACurrentLedgerIsNotRebuiltOnDecode() throws {
        var model = ReaderLearningModel()
        model.record(event(.kept, at: now()))
        // Events are capped; a current-version ledger whose history has rolled
        // past the window must keep its counters rather than lose them.
        let before = model.sourceAffinities["source-1"]
        model.events = []

        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(ReaderLearningModel.self, from: data)

        XCTAssertEqual(decoded.sourceAffinities["source-1"], before)
    }

    func testAffinityWrittenWithoutCrossingKeysDecodesAsZeroes() throws {
        let legacy = """
        {"surfaced":4,"kept":2,"dismissed":1,"loved":1,"missed":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ReaderLearningAffinity.self, from: legacy)
        XCTAssertEqual(decoded.kept, 2)
        XCTAssertEqual(decoded.acted, 0)
        XCTAssertEqual(decoded.followedThread, 0)
        XCTAssertEqual(decoded.keepsakeEarned, 0)
    }

    // MARK: - The transfer indicator

    func testUnpromptedCapturesAreCountedSeparatelyFromPromptedOnes() {
        var model = ReaderLearningModel()
        let start = now()

        // The Book laid out a desk, and the reader answered it.
        model.record(event(.surfaced, at: start, surfaceID: "desk-1"))
        model.record(event(.kept, at: start.addingTimeInterval(300), surfaceID: "desk-1"))

        // Two days later the reader opened the Book and gave it something with
        // no desk in front of them.
        let later = start.addingTimeInterval(2 * 86_400)
        model.record(event(.kept, at: later, surfaceID: "own-1"))
        model.record(event(.keepsakeEarned, at: later.addingTimeInterval(60), surfaceID: "own-2"))

        let metrics = model.momentumMetrics()
        XCTAssertEqual(metrics.promptedCaptures, 1)
        XCTAssertEqual(metrics.unpromptedCaptures, 2)
        XCTAssertEqual(metrics.unpromptedCaptureRatePercent, 67)
    }

    func testPushingHarderCannotInflateTheUnpromptedRate() {
        var model = ReaderLearningModel()
        let start = now()
        model.record(event(.kept, at: start, surfaceID: "own-1"))
        let baseline = model.momentumMetrics().unpromptedCaptures

        // The Book surfaces a great deal more, and the reader answers each one.
        for index in 1...10 {
            let at = start.addingTimeInterval(Double(index) * 7200)
            model.record(event(.surfaced, at: at, surfaceID: "push-\(index)"))
            model.record(event(.kept, at: at.addingTimeInterval(120), surfaceID: "push-\(index)"))
        }

        let metrics = model.momentumMetrics()
        XCTAssertEqual(metrics.unpromptedCaptures, baseline, "prompting must not add to the unprompted count")
        XCTAssertEqual(metrics.promptedCaptures, 10)
        XCTAssertLessThan(metrics.unpromptedCaptureRatePercent, 50, "the rate should fall as the Book leans harder")
    }

    func testNoCapturesReportsZeroRatherThanDividingByZero() {
        let model = ReaderLearningModel()
        XCTAssertEqual(model.momentumMetrics().unpromptedCaptureRatePercent, 0)
    }

    func testOutsideSharesEnterTheUnpromptedMetricWithoutBeingConfusedByAppUse() {
        var model = ReaderLearningModel()
        let start = now()
        model.record(event(.surfaced, at: start, surfaceID: "ordinary-desk"))
        model.record(event(
            .broughtFromElsewhere,
            at: start.addingTimeInterval(60),
            surfaceID: "outside-1",
            tags: ["external-share", "unprompted-capture"]
        ))
        model.record(event(
            .broughtFromElsewhere,
            at: start.addingTimeInterval(120),
            surfaceID: "outside-2",
            tags: ["external-share", "prompted-capture"]
        ))

        let metrics = model.momentumMetrics()
        XCTAssertEqual(metrics.unpromptedCaptures, 1)
        XCTAssertEqual(metrics.promptedCaptures, 1)
        XCTAssertEqual(metrics.unpromptedCaptureRatePercent, 50)
    }

    func testAnUnrelatedSurfaceCannotMakeAnIndependentCaptureLookPrompted() {
        var model = ReaderLearningModel()
        let start = now()
        model.record(event(.surfaced, at: start, surfaceID: "ordinary-desk"))
        model.record(event(.kept, at: start.addingTimeInterval(60), surfaceID: "reader-started-page"))

        let metrics = model.momentumMetrics()
        XCTAssertEqual(metrics.promptedCaptures, 0)
        XCTAssertEqual(metrics.unpromptedCaptures, 1)
    }

    func testLaterOpeningFindsTheOriginalThreadAcrossSurfaceIDs() {
        var model = ReaderLearningModel()
        let later = now()
        var first = event(.opened, at: later.addingTimeInterval(-86_400), surfaceID: "old-card")
        first.contentKey = "person:maya"
        model.record(first)

        XCTAssertEqual(
            model.followedThreadOrigin(
                surfaceID: "new-card",
                contentKey: "person:maya",
                now: later,
                calendar: calendar
            )?.id,
            first.id
        )
    }

    func testBeingSurfacedDoesNotBeginAThread() {
        var model = ReaderLearningModel()
        let later = now()
        var first = event(.surfaced, at: later.addingTimeInterval(-86_400))
        first.contentKey = "place:harbor"
        model.record(first)

        XCTAssertNil(model.followedThreadOrigin(
            surfaceID: "another-card",
            contentKey: "place:harbor",
            now: later,
            calendar: calendar
        ))
    }

    func testAThreadEarnsAtMostOneReturnPerDay() {
        var model = ReaderLearningModel()
        let later = now()
        var first = event(.opened, at: later.addingTimeInterval(-86_400))
        first.contentKey = "practice:draw"
        model.record(first)
        var returned = event(.followedThread, at: later, surfaceID: "new-card")
        returned.contentKey = "practice:draw"
        model.record(returned)

        XCTAssertNil(model.followedThreadOrigin(
            surfaceID: "third-card",
            contentKey: "practice:draw",
            now: later.addingTimeInterval(60),
            calendar: calendar
        ))
    }
}
