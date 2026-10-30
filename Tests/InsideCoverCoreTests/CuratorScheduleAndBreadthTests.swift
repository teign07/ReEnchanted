import XCTest
@testable import InsideCoverCore

final class CuratorScheduleAndBreadthTests: XCTestCase {
    private func date(_ hour: Int, day: Int = 20, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(
            year: 2026, month: 7, day: day, hour: hour, minute: minute
        ))!
    }

    private func page(_ type: BookPageType, score: Int = 80, id: String? = nil) -> SurfacePage {
        let key = id ?? type.rawValue
        return SurfacePage(
            id: key, type: type, sourceID: "fixture-\(type.rawValue)", score: score,
            prompt: key, detail: key,
            payload: BookPagePayload(headline: key, body: key)
        )
    }

    private func mood() -> CuratorMood {
        var result = CuratorMood.neutral
        result.keptPageCount = 200
        result.isFirstHours = false
        return result
    }

    func testThreeDailyBellsAndNoNewBellAtMidnight() {
        XCTAssertEqual(FacultyLogCadence.windows.map(\.id), ["morning", "midday", "evening"])
        XCTAssertEqual([8, 12, 18, 23].map {
            FacultyLogCadence.currentWindow(for: date($0)).id
        }, ["morning", "midday", "evening", "evening"])
        let evening = date(23)
        let afterMidnight = date(3, day: 21)
        XCTAssertEqual(FacultyLogCadence.dayID(for: evening), FacultyLogCadence.dayID(for: afterMidnight))
        for adapter in [FuelLogPageSourceAdapter() as BookPageSourceAdapter, MoodPageSourceAdapter()] {
            func occurrence(_ when: Date) -> String? {
                let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
                return adapter.candidates(for: day, context: .make(for: day), inputs: .empty, now: when)
                    .first?.curatorAutomaticRecurrenceHistoryKey
            }
            XCTAssertEqual(occurrence(evening), occurrence(afterMidnight), adapter.source.id)
        }
    }

    func testBothLogsReachEachOfTheThreeBellsWithoutAFourthOffer() {
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        let oldDate = date(8, day: 1)
        inputs.days = [BookDay(id: BookDay.id(for: oldDate), date: oldDate, pages: [
            BookPage(type: .souvenir, createdAt: oldDate, promptText: "A line", userInput: "The kettle clicked.")
        ])]
        for hour in [8, 12, 18, 23] {
            let when = date(hour)
            let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
            let desk = Array(BookCurator.surfacedPages(
                for: day, inputs: inputs, now: when, limit: BookDeskRound.candidateBenchCapacity
            ).prefix(BookDeskRound.reserveCapacity))
            for type in [BookPageType.fuel, .mood] {
                XCTAssertEqual(desk.contains { $0.type == type }, hour != 23, "\(type) at \(hour)")
            }
            inputs.surfaceHistory = CuratorVarietyGovernor.recordingServed(
                keys: desk.flatMap(\.curatorServedHistoryKeys), into: inputs.surfaceHistory, now: when
            )
        }
    }

    func testAClassAndAClubArriveEvenBeforeTheirOrdinaryDebutGate() throws {
        for hour in [9, 13, 19] { // Monday has two classes and a club.
            let when = date(hour)
            let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
            let session = try XCTUnwrap(AcademyClassPageSourceAdapter().candidates(
                for: day, context: .make(for: day), inputs: .empty, now: when
            ).first)
            var youngMood = CuratorMood.neutral
            youngMood.isFirstHours = true
            youngMood.surfaceHistory[CuratorVarietyGovernor.typeKey(for: .academyClass)] =
                SurfaceHistoryRecord(lastShownAt: when.addingTimeInterval(-60), recentShowCount: 1)
            XCTAssertTrue(youngMood.allows(session))
            XCTAssertTrue(youngMood.allowsTypeRefresh(for: session, now: when))
            let desk = BookCurator.rankedPages(
                from: [page(.lore), page(.quotes), page(.weather), page(.body), page(.rest),
                       page(.illustration), page(.affirmations), page(.wonderCompass),
                       session],
                limit: BookDeskRound.candidateBenchCapacity, mood: youngMood, now: when
            ).prefix(BookDeskRound.reserveCapacity).map(\.page)
            XCTAssertTrue(desk.contains { $0.id == session.id }, "Missing session at \(hour)")
            let served = CuratorVarietyGovernor.recordingServed(
                keys: session.curatorServedHistoryKeys, into: [:], now: when
            )
            XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
                session, history: served, preferences: .none, now: when.addingTimeInterval(60)
            ))
        }
        let between = date(15, minute: 1)
        let day = BookDay(id: BookDay.id(for: between), date: between, pages: [])
        XCTAssertTrue(AcademyClassPageSourceAdapter().candidates(
            for: day, context: .make(for: day), inputs: .empty, now: between
        ).isEmpty)
    }

    func testTimedArrivalEntersAFullPublishedFolioWithoutTakingTheReadLeaf() throws {
        let when = date(19)
        let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
        let club = try XCTUnwrap(AcademyClassPageSourceAdapter().candidates(
            for: day, context: .make(for: day), inputs: .empty, now: when
        ).first)
        let desk = (0..<9).map { page(.weather, id: "existing-\($0)") }
        let renewed = BookDeskRound.renewingScheduledPages(
            in: desk, from: [club], protecting: ["existing-8"], now: when
        )
        XCTAssertEqual(renewed.count, 9)
        XCTAssertTrue(renewed.contains { $0.id == club.id })
        XCTAssertTrue(renewed.contains { $0.id == "existing-8" })
        XCTAssertFalse(renewed.contains { $0.id == "existing-7" })
        let afterClub = BookDeskRound.renewingScheduledPages(in: renewed, from: [], now: date(22))
        XCTAssertFalse(afterClub.contains { $0.id == club.id })
        XCTAssertEqual(BookDeskRound.renewingScheduledPages(
            in: renewed, from: [], protecting: [club.id], now: date(22)
        ), renewed)
    }

    func testSpellsHaveNoReservationOrConditionalChairProtection() {
        let spell = page(.spell, score: 1).withMetadata(["spellConditional": "true"])
        XCTAssertFalse(BookCurator.holdsItsChair(spell))
        let ordinary = [BookPageType.wonderCompass, .enchantment, .wickerDare, .pactErrand,
                        .calendar, .location, .souvenir, .lore, .quotes, .gossip,
                        .letter, .facultyResearch, .illustration, .weather].map { page($0) }
        let desk = BookCurator.rankedPages(
            from: ordinary + [spell], limit: 9, mood: mood(), now: date(12)
        ).map(\.page)
        XCTAssertEqual(desk.count, 9)
        XCTAssertFalse(desk.contains { $0.type == .spell })
    }

    func testLaterActsConsiderMoreThanThreeTypesAndTheirExactPageVariants() {
        let types = BookPageType.allCases.filter {
            !$0.isCompositionPrompt && !$0.speaksOfItself && $0 != .festival
                && $0 != .academyClass && $0 != .bookOfYou
        }
        let pool = types.flatMap { type in
            (0..<2).map { page(type, score: 65, id: "\(type.rawValue)-\($0)") }
        }
        var widestAlternativeTypeCount = 0
        var tailTypes = Set<BookPageType>()
        for round in 0..<80 {
            let seed = "full-folio-\(round)"
            let intention = BookSessionIntention(
                id: seed, dayID: BookDay.id(for: date(12)), movement: .freshSight, ambition: .glint,
                evidencePageIDs: [], evidenceReason: "Breadth regression", createdAt: date(12),
                expiresAt: date(18), seed: seed
            )
            let block = BookCurator.rankedPages(
                from: pool, limit: 9, mood: mood(), now: date(12),
                intention: intention, selectionSeed: seed
            ).map(\.page)
            for page in block.dropFirst(3) {
                tailTypes.insert(page.type)
                if let receipt = CausalCurationReceipt.read(from: page) {
                    widestAlternativeTypeCount = max(
                        // Each fixture type owns exactly one source family.
                        widestAlternativeTypeCount, Set(receipt.candidates.map(\.sourceID)).count
                    )
                }
            }
        }
        XCTAssertGreaterThan(widestAlternativeTypeCount, 3)
        XCTAssertGreaterThan(tailTypes.count, 9, "The tail keeps returning to one fixed shortlist")
    }

    func testAnUnseenSiblingEarnsPatienceWhenItsTypeHasBeenAbsent() {
        let unseen = page(.gamePage)
        let old = date(12, day: 1)
        let history = [
            CuratorVarietyGovernor.typeKey(for: unseen.type):
                SurfaceHistoryRecord(lastShownAt: old, recentShowCount: 1),
            "source:\(unseen.sourceID)": SurfaceHistoryRecord(lastShownAt: old, recentShowCount: 1)
        ]
        XCTAssertGreaterThan(CuratorNoveltyPolicy.patienceBonus(for: unseen, history: history, now: date(12)), 0)
        var recentlyActive = history
        recentlyActive[CuratorVarietyGovernor.typeKey(for: unseen.type)] =
            SurfaceHistoryRecord(lastShownAt: date(12), recentShowCount: 1)
        XCTAssertEqual(CuratorNoveltyPolicy.patienceBonus(for: unseen, history: recentlyActive, now: date(12)), 0)
    }

    func testNewlyUnlockedStoryNodesHaveIndependentDeliveryClaims() {
        func claim(_ content: String, _ node: String, run: String = "current") -> String {
            MonthlyIssuePageMetadata.storyClaimHistoryKey(
                issueID: "issue", runID: run, dayID: BookDay.id(for: date(12)),
                contentID: content, nodeID: node, now: date(12)
            )
        }
        XCTAssertEqual(claim("scene", "door"), claim("scene", "door"))
        XCTAssertNotEqual(claim("scene", "door"), claim("scene", "inside"))
        XCTAssertNotEqual(claim("scene", "door"), claim("next-scene", "door"))
        XCTAssertNotEqual(claim("scene", "door"), claim("scene", "door", run: "next-run"))

        let when = date(12)
        let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
        let unlocked = page(.narrativeOS, id: "inside").withMetadata([
            MonthlyIssuePageMetadata.issueID: "issue",
            MonthlyIssuePageMetadata.authoredStoryScene: "true",
            MonthlyIssuePageMetadata.mayReserve: "true",
            MonthlyIssuePageMetadata.priority: "spine",
            MonthlyIssuePageMetadata.claimHistoryKey: claim("scene", "inside"),
            "automaticRecurrenceSlot": "inside-current-slot"
        ])
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.surfaceHistory[claim("scene", "door")] =
            SurfaceHistoryRecord(lastShownAt: when, recentShowCount: 1)
        let reserved = BookCurator.reservingAuthoredIssuePageIfOwed(
            in: [page(.weather), page(.quotes), page(.lore)], candidates: [unlocked],
            day: day, inputs: inputs, context: .make(for: day), preferences: .none,
            mood: CuratorMood.make(inputs: inputs, now: when), now: when, limit: 9
        )
        XCTAssertTrue(reserved.contains { $0.id == unlocked.id })
        let monthlyClass = page(.academyClass).withMetadata([
            "sessionID": "current-class", "automaticRecurrenceSlot": "class-current-slot",
            MonthlyIssuePageMetadata.issueID: "issue"
        ])
        let sharedBlock = BookCurator.reservingAuthoredIssuePageIfOwed(
            in: [monthlyClass, page(.weather), page(.quotes)], candidates: [unlocked],
            day: day, inputs: inputs, context: .make(for: day), preferences: .none,
            mood: CuratorMood.make(inputs: inputs, now: when), now: when, limit: 9
        )
        XCTAssertTrue(sharedBlock.contains { $0.id == monthlyClass.id })
        XCTAssertTrue(sharedBlock.contains { $0.id == unlocked.id })
        inputs.surfaceHistory = CuratorVarietyGovernor.recordingServed(
            keys: unlocked.curatorServedHistoryKeys, into: inputs.surfaceHistory, now: when
        )
        let alreadyDelivered = BookCurator.reservingAuthoredIssuePageIfOwed(
            in: [], candidates: [unlocked], day: day, inputs: inputs,
            context: .make(for: day), preferences: .none,
            mood: CuratorMood.make(inputs: inputs, now: when), now: when, limit: 9
        )
        XCTAssertTrue(alreadyDelivered.isEmpty)
    }
}
