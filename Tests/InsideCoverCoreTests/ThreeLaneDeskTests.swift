import XCTest
@testable import InsideCoverCore

/// The home desk is balanced across three lanes — one page that reads the
/// reader's real life (outward), one from the living Academy world (fiction),
/// and one from everything else (other) — with milestone pages pinned above
/// the lanes and never evicted. These exercise `BookCurator.rankedPages`
/// directly with constructed candidates so the balancing is tested in
/// isolation from the live source adapters.
final class ThreeLaneDeskTests: XCTestCase {

    // MARK: - Fixtures

    private func candidate(
        _ type: BookPageType,
        score: Int,
        id: String? = nil,
        sourceID: String? = nil,
        copy: String? = nil,
        metadata: [String: String] = [:]
    ) -> SurfacePage {
        let visibleCopy = copy ?? type.title
        return SurfacePage(
            id: id ?? "cand-\(type.rawValue)",
            type: type,
            sourceID: sourceID ?? "cand-\(type.rawValue)",
            score: score,
            prompt: visibleCopy,
            detail: "Candidate for \(visibleCopy).",
            payload: BookPagePayload(
                headline: visibleCopy,
                body: "Candidate for \(visibleCopy).",
                metadata: metadata
            )
        )
    }

    private func milestoneCandidate(score: Int = 80) -> SurfacePage {
        candidate(
            .bookNotices,
            score: score,
            id: "cand-milestone",
            metadata: ["milestone": "true", "firstReading": "true"]
        )
    }

    private func fixedDate(hour: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 7
        comps.day = 1
        comps.hour = hour
        comps.minute = 0
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    /// A mood that unlocks every supplied candidate type — marking each as
    /// already debuted and past the maturity ladder — so these tests exercise
    /// lane balancing rather than the Introduction Season. Fatigue is keyed by
    /// variety key (not type key), so seeding the type keys adds no score
    /// penalty and only clears the debut/lock gates.
    private func openMood(
        types: [BookPageType],
        distress: Bool = false,
        hour: Int = 12
    ) -> CuratorMood {
        var history: [String: SurfaceHistoryRecord] = [:]
        for type in types {
            history[CuratorVarietyGovernor.typeKey(for: type)] =
                SurfaceHistoryRecord(lastShownAt: fixedDate(hour: hour), recentShowCount: 1)
        }
        var mood = CuratorMood()
        mood.surfaceHistory = history
        mood.distressActive = distress
        mood.keptPageCount = 60
        mood.hour = hour
        return mood
    }

    // MARK: - Coverage

    func testDeskCoversAllThreeLanesWhenFictionScoresHighest() {
        let types: [BookPageType] = [.letter, .gossip, .lore, .fuel]
        let candidates = [
            candidate(.letter, score: 90),   // fiction
            candidate(.gossip, score: 88),   // fiction
            candidate(.lore, score: 86),     // other
            candidate(.fuel, score: 10)      // outward (lowest)
        ]

        // All-hours: the partition is not gated on time of day.
        for hour in [7, 13, 20] {
            let pages = BookCurator.rankedPages(
                from: candidates,
                limit: 3,
                mood: openMood(types: types, hour: hour),
                now: fixedDate(hour: hour)
            ).map(\.page)

            XCTAssertEqual(pages.count, 3, "hour \(hour)")
            XCTAssertEqual(
                Set(pages.map(\.type.deskLane)),
                Set(DeskLane.allCases),
                "hour \(hour): the desk should hold exactly one page per lane"
            )
        }
    }

    // MARK: - Milestones

    func testMilestoneIsPinnedAlongsideOutwardAndFiction() {
        let types: [BookPageType] = [.bookNotices, .letter, .gossip, .lore, .fuel]
        let candidates = [
            milestoneCandidate(score: 80),   // other lane, but pinned
            candidate(.letter, score: 90),   // fiction
            candidate(.gossip, score: 88),   // fiction
            candidate(.lore, score: 70),     // other
            candidate(.fuel, score: 10)      // outward
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: openMood(types: types),
            now: fixedDate(hour: 12)
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
        XCTAssertTrue(pages.contains { $0.isDeskMilestone }, "the milestone must be pinned")

        // The milestone covers its own (other) lane; the remaining two slots
        // are the outward and fiction lanes.
        let nonMilestone = pages.filter { !$0.isDeskMilestone }
        XCTAssertEqual(Set(nonMilestone.map(\.type.deskLane)), [.outward, .fiction])
    }

    // MARK: - Distress

    func testDistressStillKeepsAllThreeLanesWhenCandidatesExist() {
        let types: [BookPageType] = [.letter, .gossip, .narrativeOS, .lore, .fuel]
        let candidates = [
            candidate(.letter, score: 90),
            candidate(.gossip, score: 88),
            candidate(.narrativeOS, score: 86),
            candidate(.lore, score: 84),
            candidate(.fuel, score: 10)  // the only outward page, low-scored
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: openMood(types: types, distress: true),
            now: fixedDate(hour: 12)
        ).map(\.page)

        // Distress shapes scores, but a complete home desk still holds one
        // page that points back to the reader's real life.
        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(Set(pages.map(\.type.deskLane)), Set(DeskLane.allCases))
    }

    // MARK: - No starvation

    func testSingleLaneDeskStillFillsSlots() {
        let types: [BookPageType] = [.lore, .quip, .radio]
        let candidates = [
            candidate(.lore, score: 90),
            candidate(.quip, score: 88),
            candidate(.radio, score: 86)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: openMood(types: types),
            now: fixedDate(hour: 12)
        ).map(\.page)

        // With candidates in only one lane, the desk fills from that lane
        // rather than starving.
        XCTAssertEqual(pages.count, 3)
        XCTAssertTrue(pages.allSatisfy { $0.type.deskLane == .other })
    }

    // MARK: - Composition rule

    func testAtMostOneCompositionPromptAcrossLanes() {
        // diary is an outward composition prompt; aboutYou is an other-lane
        // composition prompt. The desk must never show both.
        let types: [BookPageType] = [.diary, .aboutYou, .letter, .lore]
        let candidates = [
            candidate(.diary, score: 90),     // outward, composition
            candidate(.aboutYou, score: 88),  // other, composition
            candidate(.letter, score: 86),    // fiction
            candidate(.lore, score: 84)       // other
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: openMood(types: types),
            now: fixedDate(hour: 12)
        ).map(\.page)

        let compositionCount = pages.filter { $0.type.isCompositionPrompt }.count
        XCTAssertLessThanOrEqual(compositionCount, 1)
    }

    func testVisibleDeskDoesNotStackAMissionWithASecondFeltAsk() {
        let mission = candidate(
            .wonderCompass,
            score: 96,
            id: "mission",
            sourceID: "mission",
            copy: "Find the lowest sound",
            metadata: ["curatorActionCommission": "true"]
        )
        let moodQuestion = candidate(
            .mood,
            score: 94,
            id: "mood-question",
            sourceID: "mood-question",
            copy: "What's the weather like inside you?"
        )
        let candidates = [
            mission,
            moodQuestion,
            candidate(.letter, score: 80),
            candidate(.lore, score: 70),
            candidate(.weather, score: 60)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: openMood(types: candidates.map(\.type)),
            now: fixedDate(hour: 12)
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(pages.filter(\.isReaderFacingAsk).count, 1)
    }

    // MARK: - Wide queries

    func testWideQueryBalancesVisiblePrefixThenKeepsADeepBench() {
        let types: [BookPageType] = [
            .letter, .gossip, .narrativeOS, .castBond, .twoReadings, .lore, .quip, .fuel
        ]
        let candidates = [
            candidate(.letter, score: 90),
            candidate(.gossip, score: 88),
            candidate(.narrativeOS, score: 86),
            candidate(.castBond, score: 84),
            candidate(.twoReadings, score: 82),
            candidate(.lore, score: 80),
            candidate(.quip, score: 78),
            candidate(.fuel, score: 10)  // outward, far below the top 6
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 6,
            mood: openMood(types: types),
            now: fixedDate(hour: 12)
        ).map(\.page)

        // Launch asks for a deep bench and then displays prefix(3), so the
        // visible prefix must honor the home-desk contract even though later
        // candidates continue in ordinary rank order.
        XCTAssertEqual(pages.count, 6)
        XCTAssertEqual(Set(pages.prefix(3).map { $0.type.deskLane }), Set(DeskLane.allCases))
        XCTAssertTrue(pages.dropFirst(3).contains { $0.type == .gossip })
    }

    // MARK: - Determinism

    func testDeskIsDeterministic() {
        let types: [BookPageType] = [.letter, .gossip, .lore, .fuel]
        let candidates = [
            candidate(.letter, score: 90),
            candidate(.gossip, score: 88),
            candidate(.lore, score: 86),
            candidate(.fuel, score: 10)
        ]
        let mood = openMood(types: types)
        let now = fixedDate(hour: 12)

        let first = BookCurator.rankedPages(from: candidates, limit: 3, mood: mood, now: now).map { $0.page.id }
        let second = BookCurator.rankedPages(from: candidates, limit: 3, mood: mood, now: now).map { $0.page.id }

        XCTAssertEqual(first, second)
    }

    // MARK: - Discovery law

    func testExactRepeatRestsLongerAtLowBeliefButNewActualPageDoesNot() {
        let now = fixedDate(hour: 12)
        let repeated = candidate(.letter, score: 96, sourceID: "letters", copy: "The same old letter")
        let fresh = candidate(.letter, score: 24, id: "fresh-letter", sourceID: "letters", copy: "A genuinely different letter")
        var mood = openMood(types: [.letter])
        mood.surfaceHistory[repeated.curatorContentNoveltyKey] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-25 * 3600),
            recentShowCount: 1
        )
        mood.surfaceHistory["source:letters"] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-25 * 3600),
            recentShowCount: 1
        )

        let pages = BookCurator.rankedPages(
            from: [repeated, fresh],
            limit: 3,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.map(\.id), ["fresh-letter"])
    }

    func testInvestedBeliefShortensAnExactPagesRest() {
        let now = fixedDate(hour: 12)
        let repeated = candidate(.letter, score: 40, sourceID: "letters", copy: "A beloved letter")
        var mood = openMood(types: [.letter])
        let old = SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-25 * 3600), recentShowCount: 1)
        mood.surfaceHistory[repeated.curatorContentNoveltyKey] = old
        mood.surfaceHistory["source:letters"] = old
        let profile = PageBeliefProfile(
            sourceID: "letters",
            type: .letter,
            title: "Letters",
            belief: CuratorNoveltyPolicy.repeatBeliefThreshold,
            narrativeWeight: 22,
            cadence: "when believed",
            note: "test"
        )
        let preferences = CuratorSurfacePreferences(pageBeliefProfiles: ["letters": profile])

        let pages = BookCurator.rankedPages(
            from: [repeated],
            limit: 3,
            preferences: preferences,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.map(\.id), [repeated.id])
    }

    func testBeliefPermittedRepeatStillPreservesAllThreeLanes() {
        let now = fixedDate(hour: 12)
        let outward = candidate(.fuel, score: 30, copy: "A new outward page")
        let fiction = candidate(.letter, score: 80, sourceID: "letters", copy: "A beloved returning letter")
        let other = candidate(.gamePage, score: 30, copy: "A new surprise game")
        var mood = openMood(types: [.fuel, .letter, .gamePage])
        let old = SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-25 * 3600), recentShowCount: 1)
        mood.surfaceHistory[fiction.curatorContentNoveltyKey] = old
        mood.surfaceHistory["source:letters"] = old
        let profile = PageBeliefProfile(
            sourceID: "letters",
            type: .letter,
            title: "Letters",
            belief: 80,
            narrativeWeight: 22,
            cadence: "when believed",
            note: "test"
        )

        let pages = BookCurator.rankedPages(
            from: [fiction, other, outward],
            limit: 3,
            preferences: CuratorSurfacePreferences(pageBeliefProfiles: ["letters": profile]),
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertEqual(Set(pages.map(\.type.deskLane)), Set(DeskLane.allCases))
    }

    // MARK: - The mirror floor

    /// A week without a page about the reader promotes the best reflective
    /// candidate, even when louder world pages outscore it.
    func testQuietWeekPromotesAPageThatReflectsTheReader() {
        let now = fixedDate(hour: 12)
        let types: [BookPageType] = [.bookRemembered, .letter, .gossip, .lore, .fuel]
        let candidates = [
            candidate(.letter, score: 95),          // fiction
            candidate(.gossip, score: 93),          // fiction
            candidate(.lore, score: 91),            // other — would win the grab bag
            candidate(.fuel, score: 40),            // outward
            candidate(.bookRemembered, score: 30)   // other, and losing badly
        ]

        var mood = openMood(types: types, hour: 12)
        // The reflective page last surfaced eight days ago; everything else is
        // current. Nothing about the scores says it should appear today.
        mood.surfaceHistory[CuratorVarietyGovernor.typeKey(for: .bookRemembered)] =
            SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-8 * 86_400), recentShowCount: 1)

        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: mood, now: now).map(\.page)

        XCTAssertTrue(
            pages.contains { $0.type.reflectsTheReader },
            "after a quiet week the desk owes the reader a page about them"
        )
    }

    /// The floor is a floor, not a quota: a desk that already turned toward the
    /// reader this week composes exactly as before.
    func testRecentReflectionLeavesTheDeskUnchanged() {
        let now = fixedDate(hour: 12)
        let types: [BookPageType] = [.bookRemembered, .letter, .gossip, .lore, .fuel]
        let candidates = [
            candidate(.letter, score: 95),
            candidate(.gossip, score: 93),
            candidate(.lore, score: 91),
            candidate(.fuel, score: 40),
            candidate(.bookRemembered, score: 30)
        ]

        // Every type has to sit *off* the type-refresh cooldown, or the desk is
        // testing suppression rather than the floor: `openMood` marks its types
        // as shown at this instant, which correctly suppresses them and leaves
        // whichever page is stale enough to qualify alone on the shelf.
        var mood = openMood(types: types, hour: 12)
        for type in types {
            mood.surfaceHistory[CuratorVarietyGovernor.typeKey(for: type)] =
                SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-4 * 86_400), recentShowCount: 1)
        }
        // Reflective page seen two days ago: inside the seven-day window, so the
        // floor owes nothing and this composes like any other low-scoring card.
        mood.surfaceHistory[CuratorVarietyGovernor.typeKey(for: .bookRemembered)] =
            SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-2 * 86_400), recentShowCount: 1)

        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: mood, now: now).map(\.page)

        XCTAssertFalse(
            pages.contains { $0.type == .bookRemembered },
            "a page seen two days ago is not owed again"
        )
        XCTAssertEqual(Set(pages.map(\.type.deskLane)), Set(DeskLane.allCases))
    }

    /// The floor can only promote what the adapters already offered. A young
    /// library produces no reflective candidates, and the desk is untouched.
    func testFloorPromotesNothingWhenNoReflectiveCandidateExists() {
        let now = fixedDate(hour: 12)
        let types: [BookPageType] = [.letter, .gossip, .lore, .fuel]
        let candidates = [
            candidate(.letter, score: 95),
            candidate(.gossip, score: 93),
            candidate(.lore, score: 91),
            candidate(.fuel, score: 40)
        ]

        // No reflective page has ever surfaced: the floor is owed and still
        // has nothing to give.
        XCTAssertTrue(CuratorMirrorFloor.isOwed(history: [:], now: now))

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: openMood(types: types, hour: 12),
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(Set(pages.map(\.type.deskLane)), Set(DeskLane.allCases))
    }

    func testCuratorTraceExplainsRestingExactRepeat() throws {
        let now = fixedDate(hour: 12)
        let repeated = candidate(.lore, score: 80, sourceID: "lore", copy: "The same lore")
        var mood = openMood(types: [.lore])
        mood.surfaceHistory[repeated.curatorContentNoveltyKey] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-25 * 3600),
            recentShowCount: 1
        )

        let trace = try XCTUnwrap(BookCurator.candidateTrace(from: [repeated], mood: mood, now: now).first)

        XCTAssertFalse(trace.isNewContent)
        XCTAssertEqual(trace.lane, .other)
        XCTAssertEqual(trace.rejection, "exact-repeat-resting")
    }
}
