import XCTest
@testable import InsideCoverCore

/// The Curator curates a loop, not a shelf:
///
///     a prompt sends the reader into their life; they write one sentence about
///     what happened; the Book makes that sentence into content in the fiction;
///     the fiction sends them back out again.
///
/// Lane balance sorts Pages by subject matter, so it could hand back a
/// perfectly balanced desk that never once sent the reader anywhere. These are
/// the rules that replaced it. See docs/curator-loop-jobs.md.
final class CuratorLoopJobsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)

    private func candidate(
        _ type: BookPageType,
        score: Int,
        metadata: [String: String] = [:]
    ) -> SurfacePage {
        SurfacePage(
            id: "c-\(type.rawValue)-\(score)", type: type,
            sourceID: "src-\(type.rawValue)", score: score,
            prompt: type.title, detail: "d",
            payload: BookPagePayload(headline: type.title, body: "b", metadata: metadata)
        )
    }

    private func settledMood() -> CuratorMood {
        var mood = CuratorMood.neutral
        mood.keptPageCount = 60
        mood.isFirstHours = false
        mood.hour = 13
        return mood
    }

    // MARK: - The taxonomy

    func testTheSendOutsAreErrandsAndCarryTheirOwnWritingStep() {
        // A mission and a one-sentence souvenir are the same shape: they put the
        // reader in their day and take the sentence when they come back. The
        // errand and the writing are not two Pages.
        for type in [BookPageType.wonderCompass, .souvenir, .enchantment, .anchor,
                     .pactErrand, .wickerDare, .calendar, .location] {
            XCTAssertEqual(type.deskJob, .errand, "\(type.rawValue)")
        }
        for type in [BookPageType.mood, .fuel, .body, .diary, .plainPage] {
            XCTAssertEqual(type.deskJob, .instrument, "\(type.rawValue)")
        }
        for type in [BookPageType.narrativeOS, .bookNotices, .bookRemembered, .twoReadings] {
            XCTAssertEqual(type.deskJob, .reprise, "\(type.rawValue)")
        }
        XCTAssertEqual(BookPageType.rest.deskJob, .quiet)
        XCTAssertEqual(BookPageType.tarot.deskJob, .play, "spice is the default")
    }

    /// One adapter can emit two jobs from one type: the compass source produces
    /// both the mission that sends the reader outdoors and the field-guide card
    /// that quotes a book at them, and the desk has to tell them apart.
    func testAnIndividualPageMayCorrectItsTypesJob() {
        let quotation = candidate(.wonderCompass, score: 66, metadata: ["deskJob": DeskJob.play.rawValue])
        XCTAssertEqual(quotation.deskJob, .play)
        XCTAssertEqual(candidate(.wonderCompass, score: 64).deskJob, .errand)
    }

    // MARK: - A floor under the way out

    func testTheDeskOffersAWayOutEvenWhenNothingOutwardOutranksTheBook() {
        let candidates = [
            candidate(.letter, score: 99),
            candidate(.gossip, score: 98),
            candidate(.lore, score: 97),
            candidate(.wonderCompass, score: 60)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
        XCTAssertTrue(
            pages.contains { $0.deskJob == .errand },
            "desk was \(pages.map { $0.type.rawValue })"
        )
    }

    /// The floor takes the spice's chair, never a promise the Book already made.
    func testTheWayOutNeverEvictsAMilestone() {
        let milestone = SurfacePage(
            id: "c-milestone", type: .bindery, sourceID: "src-bindery", score: 99,
            prompt: "m", detail: "d",
            payload: BookPagePayload(headline: "m", body: "b", metadata: ["milestone": "true"])
        )
        let candidates = [
            milestone,
            candidate(.letter, score: 98),
            candidate(.gossip, score: 97),
            candidate(.wonderCompass, score: 60)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertTrue(pages.contains { $0.type == .bindery }, "the milestone kept its chair")
        XCTAssertTrue(pages.contains { $0.deskJob == .errand })
    }

    /// An errand drops its own score to the floor when the pressure budget is
    /// closed or the reader is tired. That is the adapter asking not to be
    /// seated, and a floor must not overrule it.
    func testAQuietedErrandIsNotResurrected() {
        // `.body` covers the outward lane and the non-spice chair, so nothing
        // but the floor could seat the errand — and the floor must not.
        let candidates = [
            candidate(.body, score: 100),
            candidate(.letter, score: 99),
            candidate(.lore, score: 98),
            candidate(.wonderCompass, score: 1)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertFalse(pages.contains { $0.type == .wonderCompass })
    }

    /// A hard day is not the moment to send anybody anywhere.
    func testTheWayOutStandsDownUnderDistress() {
        let candidates = [
            candidate(.body, score: 99),
            candidate(.letter, score: 98),
            candidate(.lore, score: 97),
            candidate(.wonderCompass, score: 60)
        ]
        var mood = settledMood()
        mood.distressActive = true

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: mood, now: now
        ).map(\.page)

        XCTAssertFalse(pages.contains { $0.deskJob == .errand })
    }

    // MARK: - Spice

    func testSpiceNeverTakesEveryChairOnTheVisibleDesk() {
        let candidates = [
            candidate(.letter, score: 99),
            candidate(.gossip, score: 98),
            candidate(.lore, score: 97),
            candidate(.quotes, score: 96),
            candidate(.bookRemembered, score: 40)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
        XCTAssertLessThan(
            pages.filter { $0.deskJob == .play }.count, 3,
            "desk was \(pages.map { $0.type.rawValue })"
        )
    }

    /// The cap is a preference. When spice is genuinely all there is, a shorter
    /// desk is not the honest answer.
    func testTheSpiceCapYieldsRatherThanStarveTheDesk() {
        let candidates = [
            candidate(.letter, score: 99),
            candidate(.gossip, score: 98),
            candidate(.lore, score: 97)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
    }

    // MARK: - Rest, per job

    /// A tool being reached for twice in a day is the Book working, not the
    /// Book repeating itself.
    func testInstrumentsAreSpacedByTheClockRatherThanRested() {
        let fuel = candidate(.fuel, score: 70)
        let history = CuratorVarietyGovernor.recordingServed(
            keys: fuel.curatorServedHistoryKeys, into: [:], now: now
        )

        XCTAssertFalse(
            CuratorNoveltyPolicy.allowsAutomaticSurface(
                fuel, history: history, preferences: .none, now: now.addingTimeInterval(1800)
            ),
            "half an hour later is the same sitting"
        )
        XCTAssertTrue(
            CuratorNoveltyPolicy.allowsAutomaticSurface(
                fuel, history: history, preferences: .none, now: now.addingTimeInterval(5 * 3600)
            ),
            "five hours later is a different part of the day"
        )
    }

    /// A flat cooldown says the fifth showing is as welcome as the first, which
    /// is how fourteen Pages came to take fifty-two of a fortnight's slots.
    func testRestWidensEachTimeAPageIsShown() {
        let once = CuratorNoveltyPolicy.wideningRestHours(base: 24, shownCount: 1)
        let twice = CuratorNoveltyPolicy.wideningRestHours(base: 24, shownCount: 2)
        let fiveTimes = CuratorNoveltyPolicy.wideningRestHours(base: 24, shownCount: 5)

        XCTAssertEqual(once, 24)
        XCTAssertEqual(twice, 48)
        XCTAssertGreaterThan(fiveTimes, twice * 2)
        XCTAssertLessThanOrEqual(
            CuratorNoveltyPolicy.wideningRestHours(base: 24, shownCount: 500),
            CuratorNoveltyPolicy.wideningRestCapHours,
            "rest widens, but a Page is never retired for good"
        )
    }

    /// A bell whose prose is deliberately familiar may still advance daily —
    /// the morning edition of The Bleed relies on exactly that. A ritual that
    /// declares a rest gets one.
    func testARitualMayDeclareHowLongItsContentRests() {
        func ritual(day: String, restDays: String?) -> SurfacePage {
            var metadata = ["automaticRecurrenceSlot": "\(day):ritual"]
            if let restDays { metadata["automaticRepeatRestDays"] = restDays }
            return SurfacePage(
                id: "ritual-\(day)", type: .tarot, sourceID: "ritual", score: 70,
                prompt: "p", detail: "d",
                payload: BookPagePayload(headline: "h", body: "unchanging", metadata: metadata)
            )
        }
        let tomorrow = now.addingTimeInterval(86_400)

        let undeclared = ritual(day: "day-1", restDays: nil)
        let undeclaredHistory = CuratorVarietyGovernor.recordingServed(
            keys: undeclared.curatorServedHistoryKeys, into: [:], now: now
        )
        XCTAssertTrue(CuratorNoveltyPolicy.allowsAutomaticSurface(
            ritual(day: "day-2", restDays: nil),
            history: undeclaredHistory, preferences: .none, now: tomorrow
        ))

        let declared = ritual(day: "day-1", restDays: "3")
        let declaredHistory = CuratorVarietyGovernor.recordingServed(
            keys: declared.curatorServedHistoryKeys, into: [:], now: now
        )
        XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
            ritual(day: "day-2", restDays: "3"),
            history: declaredHistory, preferences: .none, now: tomorrow
        ))
        XCTAssertTrue(CuratorNoveltyPolicy.allowsAutomaticSurface(
            ritual(day: "day-5", restDays: "3"),
            history: declaredHistory, preferences: .none, now: now.addingTimeInterval(4 * 86_400)
        ))
    }

    // MARK: - Errand supply

    /// The Curator can only rotate what it is offered, and it used to be offered
    /// exactly one errand per candidate build out of a catalog of 180.
    func testTheRegistryOffersSeveralDistinctErrands() {
        var inputs = BookSourceInputs.empty
        inputs.readerBeliefScore = 40
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let offered = PlayfulMissionRegistry.missions(for: day, inputs: inputs, now: now, limit: 5)

        XCTAssertEqual(offered.count, 5)
        XCTAssertEqual(Set(offered.map(\.id)).count, 5, "the same errand was offered twice")
        XCTAssertEqual(
            offered.first?.id,
            PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now).id,
            "the primary errand must not change: every existing caller depends on it"
        )
    }

    /// Two different errands are two different Pages. Every compass card carries
    /// `compassFamily`, so filing missions under it gave 180 errands one shared
    /// identity — rest, fatigue and de-duplication all saw a single Page that had
    /// been shown constantly.
    func testTwoErrandsAreTwoPages() {
        let first = candidate(.wonderCompass, score: 64, metadata: [
            "compassFamily": "wonder-compass", "playfulMissionID": "moon-full-face"
        ])
        let second = candidate(.wonderCompass, score: 64, metadata: [
            "compassFamily": "wonder-compass", "playfulMissionID": "water-true-color"
        ])

        XCTAssertNotEqual(first.varietyKey, second.varietyKey)
    }

    // MARK: - The block the reader turns through

    /// The folio publishes nine leaves. The Curator used to compose only the
    /// first three deliberately — every density cap was written against the
    /// opening trio — so six of the nine the reader really turns through were
    /// arranged by rank and role alone. The block is the unit now, and it reads
    /// as three turns of the loop rather than one.
    func testTheBlockIsRationedByTheThreeLeavesRatherThanTheWholeShelf() {
        var candidates: [SurfacePage] = []
        // Enough spice to fill a block twice over, if nothing stopped it.
        for (index, type) in [BookPageType.letter, .gossip, .lore, .quotes, .quip, .radio,
                              .festival, .academyClass, .elective, .facultyResearch].enumerated() {
            candidates.append(candidate(type, score: 90 - index))
        }
        for (index, type) in [BookPageType.wonderCompass, .enchantment, .wickerDare, .anchor].enumerated() {
            candidates.append(candidate(type, score: 70 - index))
        }
        for (index, type) in [BookPageType.body, .fuel, .diary].enumerated() {
            candidates.append(candidate(type, score: 60 - index))
        }

        let block = BookCurator.rankedPages(
            from: candidates,
            limit: BookDeskRound.reserveCapacity,
            mood: settledMood(),
            now: now
        ).map(\.page)

        XCTAssertGreaterThan(block.count, 6, "the block came back short: \(block.map { $0.type.rawValue })")
        // The visible desk keeps one chair for something that is not the
        // Academy performing. Deeper in the block there is deliberately no play
        // cap: this assertion used to run over all nine leaves, which meant a
        // rule written about three cards seen at a glance was rationing six
        // leaves nobody had decided to ration.
        let visible = block.prefix(3)
        XCTAssertLessThanOrEqual(
            visible.filter { $0.deskJob == .play }.count, 2,
            "the visible desk was all play: \(visible.map { $0.type.rawValue })"
        )
        // And the loop turns repeatedly. Errands are the driver, so a block of
        // nine that offers one way out is a failure, not restraint. See
        // `MissionNerveTests` for the rations this replaced.
        //
        // Two, not three, because this fixture has a feast in it. The festival
        // floor guarantees a feast a chair on the day it happens — a full moon
        // has no tomorrow to be deferred to — and on those forty-odd days a
        // year it costs the block one way out. That is the trade, made
        // deliberately. The ordinary-day version of this assertion is below and
        // still demands three.
        XCTAssertGreaterThanOrEqual(
            block.filter { $0.deskJob == .errand }.count, 2,
            "the block barely sent the reader anywhere: \(block.map { $0.type.rawValue })"
        )
        XCTAssertTrue(
            block.contains { $0.type == .festival },
            "the feast lost its chair: \(block.map { $0.type.rawValue })"
        )
    }

    /// The same block on an ordinary day, which is three hundred and twenty of
    /// them a year. With no feast competing, the loop's way out is unchanged:
    /// three of nine leaves send the reader somewhere.
    func testAnOrdinaryBlockStillTurnsTheLoopThreeTimes() {
        var candidates: [SurfacePage] = []
        for (index, type) in [BookPageType.letter, .gossip, .lore, .quotes, .quip, .radio,
                              .academyClass, .elective, .facultyResearch].enumerated() {
            candidates.append(candidate(type, score: 90 - index))
        }
        for (index, type) in [BookPageType.wonderCompass, .enchantment, .wickerDare, .anchor].enumerated() {
            candidates.append(candidate(type, score: 70 - index))
        }
        for (index, type) in [BookPageType.body, .fuel, .diary].enumerated() {
            candidates.append(candidate(type, score: 60 - index))
        }

        let block = BookCurator.rankedPages(
            from: candidates,
            limit: BookDeskRound.reserveCapacity,
            mood: settledMood(),
            now: now
        ).map(\.page)

        XCTAssertGreaterThanOrEqual(
            block.filter { $0.deskJob == .errand }.count, 3,
            "the block barely sent the reader anywhere: \(block.map { $0.type.rawValue })"
        )
    }

    /// The opening trio keeps its old rule exactly: at `limit` three, a density
    /// of one per three leaves *is* one per desk.
    func testTheOldThreeCardRulesAreUnchangedAtThatSize() {
        let candidates = [
            candidate(.diary, score: 100),
            candidate(.mood, score: 95),
            candidate(.aboutYou, score: 90),
            candidate(.lore, score: 40),
            candidate(.quip, score: 39)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(
            pages.filter { $0.type.isCompositionPrompt }.count, 1,
            "desk was \(pages.map { $0.type.rawValue })"
        )
    }

    // MARK: - The return beat

    private func keptPage(_ id: String, at date: Date, text: String = "The kettle clicked off before dawn.") -> BookPage {
        BookPage(
            id: id, type: .souvenir, createdAt: date,
            promptText: "Souvenir", userInput: text, origin: .userAuthored
        )
    }

    private func archive(_ pages: [BookPage]) -> [BookDay] {
        [BookDay(id: BookDay.id(for: pages[0].createdAt), date: pages[0].createdAt, pages: pages)]
    }

    func testAFreshKeepTheBookHasNotAnsweredIsADebt() {
        let keep = keptPage("k1", at: now.addingTimeInterval(-2 * 3600))
        let owed = CuratorReturnBeat.unansweredKeep(days: archive([keep]), history: [:], now: now)

        XCTAssertEqual(owed?.pageID, "k1")
    }

    /// Serving a return settles the debt on its own: serving stamps that kind's
    /// history forward past the keep, so nothing new has to be persisted.
    func testAReturnServedAfterTheKeepSettlesTheDebt() {
        let keep = keptPage("k1", at: now.addingTimeInterval(-2 * 3600))
        let answered = [
            CuratorVarietyGovernor.typeKey(for: .bookRemembered):
                SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3600), recentShowCount: 1)
        ]
        let stale = [
            CuratorVarietyGovernor.typeKey(for: .bookRemembered):
                SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-5 * 3600), recentShowCount: 1)
        ]

        XCTAssertNil(CuratorReturnBeat.unansweredKeep(days: archive([keep]), history: answered, now: now))
        XCTAssertNotNil(
            CuratorReturnBeat.unansweredKeep(days: archive([keep]), history: stale, now: now),
            "a return served *before* the keep answered something else"
        )
    }

    /// A week-late answer is not the loop closing, it is the archive talking.
    func testAColdKeepIsNoLongerALiveDebt() {
        let old = keptPage("k1", at: now.addingTimeInterval(-8 * 86_400))

        XCTAssertNil(CuratorReturnBeat.unansweredKeep(days: archive([old]), history: [:], now: now))
    }

    func testTheBooksOwnBraidIsNotTheReaderWriting() {
        let braid = BookPage(
            id: "braid", type: .bookOfYou, createdAt: now.addingTimeInterval(-3600),
            promptText: "The Book of You", userInput: "The Book bound a night.",
            usedInBookOfYou: true, origin: .generated
        )
        let blank = BookPage(
            id: "blank", type: .souvenir, createdAt: now.addingTimeInterval(-3600),
            promptText: "Souvenir", userInput: "  ", origin: .userAuthored
        )

        XCTAssertNil(CuratorReturnBeat.unansweredKeep(days: archive([braid, blank]), history: [:], now: now))
    }

    /// `CuratorMirrorFloor` seats a reflective Page when the desk has not turned
    /// toward the reader in a week, and every reflective Page is a return — so
    /// an empty history makes the mirror floor, not the return beat, the thing
    /// under test. This settles that older debt so only the new one is live.
    private func moodWithTheMirrorFloorSatisfied() -> CuratorMood {
        var mood = settledMood()
        mood.surfaceHistory[CuratorVarietyGovernor.typeKey(for: .marginsAtlas)] =
            SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3600), recentShowCount: 1)
        return mood
    }

    /// `.body`, `.letter` and `.quotes` cover all three lanes and both spice
    /// chairs between them, so ordinary composition has no reason to reach the
    /// return — only the floor does.
    private func deskWithNoReasonToReturn() -> [SurfacePage] {
        [
            candidate(.body, score: 70),
            candidate(.letter, score: 68),
            candidate(.quotes, score: 66),
            // Comfortably above the floor's "do not resurrect a Page that has
            // quieted itself" line, and still last in rank.
            candidate(.bookRemembered, score: 60)
        ]
    }

    func testTheDeskAnswersASentenceTheReaderJustWrote() {
        let candidates = deskWithNoReasonToReturn()
        var mood = moodWithTheMirrorFloorSatisfied()
        mood.unansweredKeep = UnansweredKeep(pageID: "k1", keptAt: now.addingTimeInterval(-2 * 3600))

        let answered = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: mood, now: now
        ).map(\.page)
        XCTAssertTrue(
            answered.contains { $0.deskJob == .reprise },
            "desk was \(answered.map { $0.type.rawValue })"
        )

        let unowed = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: moodWithTheMirrorFloorSatisfied(), now: now
        ).map(\.page)
        XCTAssertFalse(
            unowed.contains { $0.deskJob == .reprise },
            "nothing was owed, so nothing should have been seated: \(unowed.map { $0.type.rawValue })"
        )
    }

    /// A Page that answers the reader's own sentence beats one that merely
    /// shares its job.
    func testTheAnswerPrefersTheReturnThatCitesTheKeep() {
        let candidates = [
            candidate(.body, score: 70),
            candidate(.letter, score: 68),
            candidate(.quotes, score: 66),
            candidate(.bookNotices, score: 62),
            candidate(.bookRemembered, score: 60, metadata: ["evidencePageIDs": "k1"])
        ]
        var mood = moodWithTheMirrorFloorSatisfied()
        mood.unansweredKeep = UnansweredKeep(pageID: "k1", keptAt: now.addingTimeInterval(-2 * 3600))

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: mood, now: now
        ).map(\.page)

        XCTAssertTrue(
            pages.contains { $0.type == .bookRemembered },
            "the lower-scoring Page that cites the keep should win the beat: \(pages.map { $0.type.rawValue })"
        )
    }

    /// A hard day is never the moment to hand somebody a map of themselves. The
    /// debt is deferred, not cancelled.
    func testTheReturnBeatDefersUnderDistress() {
        let candidates = deskWithNoReasonToReturn()
        var mood = moodWithTheMirrorFloorSatisfied()
        mood.distressActive = true
        mood.unansweredKeep = UnansweredKeep(pageID: "k1", keptAt: now.addingTimeInterval(-2 * 3600))

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: mood, now: now
        ).map(\.page)

        XCTAssertFalse(pages.contains { $0.deskJob == .reprise })
    }

    // MARK: - Turning through the block

    func testTheBlockSpacesJobsAndNotOnlyLanes() {
        func page(_ id: String, _ type: BookPageType) -> SurfacePage {
            SurfacePage(
                id: id, type: type, sourceID: id, score: 50,
                prompt: id, detail: id, payload: BookPagePayload(headline: id, body: id)
            )
        }
        // Three errands then three pieces of spice: a monotony lane balance
        // cannot see, because an errand and a quotation can share a lane.
        let block = [
            page("e1", .wonderCompass), page("e2", .enchantment), page("e3", .wickerDare),
            page("p1", .quotes), page("p2", .letter), page("p3", .lore)
        ]

        let sequenced = BookCurator.readingSequence(block)

        XCTAssertEqual(Set(sequenced.map(\.id)), Set(block.map(\.id)))
        var run = 0
        var job: DeskJob?
        for page in sequenced {
            run = page.deskJob == job ? run + 1 : 1
            job = page.deskJob
            XCTAssertLessThanOrEqual(run, 2, "sequence was \(sequenced.map(\.id))")
        }
    }
}
