import XCTest
@testable import InsideCoverCore

/// Long-horizon contract tests for the Book as one creature rather than a
/// collection of prompt dispensers. These deliberately simulate a quiet reader:
/// the Book may make finite attempts, but silence must produce withdrawal,
/// widening quiet, and varied tactics instead of escalating pressure.
final class BookReenchantmentSimulationTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    func testThirtyDaysContainMoreQuietThanCampaignSurfaces() {
        let result = simulate(days: 30)

        XCTAssertLessThanOrEqual(result.visibleSurfaceIDs.count, 6)
        XCTAssertLessThanOrEqual(result.campaignIDs.count, 3)
        XCTAssertGreaterThan(30 - result.visibleDays.count, result.visibleDays.count)
        XCTAssertTrue(result.pressures.allSatisfy {
            $0.rank <= BookCampaignPressure.invite.rank
        })
    }

    func testNinetyDaysRotateTacticsWithoutTurningSilenceIntoDefiance() {
        let result = simulate(days: 90)

        XCTAssertLessThanOrEqual(result.visibleSurfaceIDs.count, 16)
        XCTAssertGreaterThanOrEqual(Set(result.tactics).count, 3)
        XCTAssertFalse(result.tactics.windows(ofCount: 3).contains { window in
            Set(window).count == 1
        })
        XCTAssertTrue(result.completedCampaigns.allSatisfy {
            $0.rejectionCount == 0 && $0.status == .completed
        })
    }

    func testAFullYearStaysBoundedAndLeavesTheReaderRoom() {
        let result = simulate(days: 365)

        XCTAssertLessThanOrEqual(result.visibleSurfaceIDs.count, 64)
        XCTAssertLessThanOrEqual(result.campaignHistoryCount, 24)
        XCTAssertGreaterThan(365 - result.visibleDays.count, result.visibleDays.count * 3)
        XCTAssertTrue(result.pressures.allSatisfy {
            $0.rank <= BookCampaignPressure.invite.rank
        })
    }

    func testAFullYearOfGiftsFeelsIrregularAndNeverBecomesAFeed() throws {
        let hypothesis = BookLongGameHypothesis(
            id: "simulation-found-gifts",
            capacity: .worldOtherness,
            statement: "The autonomous world has not had enough room.",
            nextHonestTest: "Bring back one honest surprise.",
            evidenceIDs: [],
            formedAt: start,
            lastRevisedAt: start
        )
        let interior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-100 * day),
            longGame: BookLongGame(
                phase: .estrangeTheFamiliar,
                strategy: "Let the world exceed its use.",
                startedAt: start.addingTimeInterval(-90 * day),
                lastAdvancedAt: start,
                phasePresentedAt: start,
                milestones: [],
                hypotheses: [hypothesis]
            )
        )
        var history: [String: SurfaceHistoryRecord] = [:]
        var giftDates: [Date] = []
        var realms = Set<BookFoundGiftRealm>()

        for offset in 0..<365 {
            let now = start.addingTimeInterval(Double(offset) * day)
            let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])
            guard let plan = BookFoundGiftEngine.plan(
                for: today,
                interior: interior,
                surfaceHistory: history,
                keptPageCount: 3,
                now: now
            ) else { continue }

            giftDates.append(now)
            realms.insert(plan.realm)
            let sourceID = plan.realm == .publicWeb
                ? BookFoundGiftEngine.sourceID
                : BookFoundGiftEngine.jSpaceSourceID
            history["source:\(sourceID)"] = SurfaceHistoryRecord(
                lastShownAt: now,
                recentShowCount: 1
            )
        }

        let gaps = zip(giftDates, giftDates.dropFirst()).map { $1.timeIntervalSince($0) }
        XCTAssertGreaterThanOrEqual(giftDates.count, 13)
        XCTAssertLessThanOrEqual(giftDates.count, 27)
        XCTAssertTrue(gaps.allSatisfy { $0 >= BookFoundGiftEngine.minimumReturnInterval })
        XCTAssertTrue(gaps.allSatisfy { $0 <= BookFoundGiftEngine.maximumReturnInterval })
        XCTAssertGreaterThan(Set(gaps.map { Int($0 / day) }).count, 1, "The gift rhythm must not become a metronome.")
        XCTAssertEqual(realms, Set(BookFoundGiftRealm.allCases))
    }

    func testAFullYearOfEnactedPersonalityStaysVariedAndDoesNotBecomeWallpaper() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "character-archive",
            date: start.addingTimeInterval(-30 * day),
            pages: (0..<5).map { keptPage($0) }
        )]
        let quirks = BookQuirkKind.allCases.map { kind in
            BookQuirk(
                id: "book-quirk-\(kind.rawValue)",
                kind: kind,
                title: kind.rawValue,
                confession: "A stable confession.",
                manifestation: "A stable manifestation.",
                maturity: .beloved,
                bornAt: start.addingTimeInterval(-40 * day),
                revealedAt: start.addingTimeInterval(-35 * day),
                firstPresentedAt: start.addingTimeInterval(-34 * day),
                exerciseCount: 3
            )
        }
        var interior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-40 * day),
            quirks: quirks
        )
        var enactedKinds: [BookQuirkKind] = []

        for offset in 0..<365 {
            let now = start.addingTimeInterval(Double(offset) * day)
            inputs.bookInterior = interior
            interior = BookInteriorEngine.reconciled(interior, inputs: inputs, now: now)
            if let behavior = interior.pendingBehavior {
                enactedKinds.append(behavior.quirkKind)
                interior = BookInteriorEngine.recordingSurfaceOpened(
                    interior,
                    behaviorID: behavior.id,
                    now: now.addingTimeInterval(60)
                )
            }
        }

        XCTAssertLessThanOrEqual(enactedKinds.count, 74)
        XCTAssertGreaterThanOrEqual(Set(enactedKinds).count, 4)
        XCTAssertFalse(enactedKinds.windows(ofCount: 2).contains { $0.first == $0.last })
        XCTAssertLessThanOrEqual(interior.behaviorHistory.count, 48)
        XCTAssertLessThanOrEqual(interior.projectHistory.count, 12)
    }

    func testTwoYearsOfBookAutobiographyRemainRareBoundedAndCausal() {
        let oldFaults = (0..<80).map { index in
            BookFaultEpisode(
                id: "simulation-old-fault-\(index)",
                kind: .prematurePattern,
                admission: "I was too neat about case \(index).",
                repair: "The uncertainty returned to case \(index).",
                evidencePageIDs: ["simulation-kept-\(index % 5)"],
                recognizedAt: start.addingTimeInterval(Double(-200 - index) * day),
                presentedAt: start.addingTimeInterval(Double(-199 - index) * day)
            )
        }
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "autobiographical-archive",
            date: start,
            pages: (0..<5).map { keptPage($0) }
        )]
        var interior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-300 * day),
            faultHistory: oldFaults
        )
        var recalledAt: [Date] = []

        for offset in 0..<730 {
            let now = start.addingTimeInterval(Double(offset) * day)
            inputs.bookInterior = interior
            interior = BookInteriorEngine.reconciled(interior, inputs: inputs, now: now)
            if let reminiscence = interior.pendingReminiscence {
                recalledAt.append(now)
                interior = BookInteriorEngine.recordingSurfaceOpened(
                    interior,
                    reminiscenceID: reminiscence.id,
                    now: now.addingTimeInterval(60)
                )
            }
        }

        XCTAssertLessThanOrEqual(interior.autobiography.count, 64)
        XCTAssertLessThanOrEqual(interior.privateTraditions.count, 8)
        XCTAssertLessThanOrEqual(interior.reminiscenceHistory.count, 32)
        XCTAssertLessThanOrEqual(interior.acquiredTastes.count, 6)
        XCTAssertLessThanOrEqual(recalledAt.count, 35)
        XCTAssertTrue(zip(recalledAt, recalledAt.dropFirst()).allSatisfy {
            $1.timeIntervalSince($0) >= 20 * day
        })
        XCTAssertTrue(interior.reminiscenceHistory.allSatisfy { reminiscence in
            interior.autobiography.contains(where: { $0.id == reminiscence.memoryID })
        })
    }

    func testTwoYearsOfUnansweredBookInitiativesStayRareVariedAndPressureFree() {
        var inputs = BookSourceInputs.empty
        var interior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-30 * day)
        )
        var seenIDs = Set<String>()
        var seenModes = Set<BookInitiativeMode>()

        for offset in 0..<730 {
            let now = start.addingTimeInterval(Double(offset) * day)
            inputs.bookInterior = interior
            interior = BookInteriorEngine.reconciled(interior, inputs: inputs, now: now)
            if let initiative = interior.currentInitiative,
               seenIDs.insert(initiative.id).inserted {
                seenModes.insert(initiative.mode)
            }
        }

        XCTAssertGreaterThanOrEqual(seenIDs.count, 12)
        XCTAssertLessThanOrEqual(seenIDs.count, 32)
        XCTAssertEqual(seenModes, Set(BookInitiativeMode.allCases))
        XCTAssertLessThanOrEqual(interior.initiativeHistory.count, 32)
        XCTAssertLessThanOrEqual(interior.wantHistory.count, 24)
        XCTAssertTrue(interior.initiativeHistory.allSatisfy {
            $0.status == .released && $0.answeredAt == nil && $0.readerReplyExcerpt == nil
        })
        XCTAssertTrue(interior.wantHistory.allSatisfy { $0.status == .released })
    }

    func testFiveYearsOfCharacteristicSurprisesStayRareReceiptBoundAndModelFree() {
        let memory = BookAutobiographicalMemory(
            id: "simulation-compound-memory",
            kind: .conversationAnswered,
            title: "The Book Spoke First",
            line: "The kitchen light once answered a question nobody had formally asked.",
            whatItChanged: "Company entered the Book's history.",
            evidencePageIDs: ["simulation-kept-0"],
            happenedAt: start.addingTimeInterval(-500 * day),
            firstRecalledAt: nil,
            lastRecalledAt: nil,
            recallCount: 0
        )
        let taste = BookAcquiredTaste(
            id: "simulation-compound-taste",
            kind: .exactLanguage,
            subject: "exact language",
            statement: "I prefer the peculiar phrase to its respectable summary.",
            strength: .devoted,
            evidencePageIDs: ["simulation-kept-0"],
            acquiredAt: start.addingTimeInterval(-400 * day),
            lastDeepenedAt: start.addingTimeInterval(-200 * day),
            firstPresentedAt: start.addingTimeInterval(-190 * day)
        )
        let project = BookProject(
            id: "simulation-compound-project",
            kind: .exactLanguage,
            title: "The Cabinet of Unnecessarily Exact Words",
            question: "Which phrases belong to this life and no generic life?",
            whyItCares: "Ready-made language arrives too early.",
            subject: "ordinary light",
            status: .resting,
            entries: [BookProjectEntry(
                id: "simulation-compound-entry",
                line: "The kitchen light was called tired gold.",
                evidencePageIDs: ["simulation-kept-0"],
                recordedAt: start.addingTimeInterval(-100 * day)
            )],
            startedAt: start.addingTimeInterval(-300 * day),
            lastWorkedAt: start.addingTimeInterval(-100 * day),
            nextEligibleAt: .distantFuture,
            lastPresentedProgress: 1
        )
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [SelfFact(
            id: "simulation-compound-reader",
            questionID: "favorite-hour",
            question: "Which hour feels most yours?",
            answer: "The blue hour after dinner.",
            bookTranslation: "The reader keeps a private fondness for the blue hour after dinner.",
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: ["time", "delight"],
            createdAt: start.addingTimeInterval(-200 * day),
            updatedAt: start.addingTimeInterval(-100 * day)
        )]
        var interior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-1_000 * day),
            currentProject: project,
            autobiography: [memory],
            acquiredTastes: [taste]
        )
        var surpriseDates: [Date] = []
        var receipts: [[String]] = []

        for offset in 0..<(365 * 5) {
            let now = start.addingTimeInterval(Double(offset) * day)
            if interior.currentWant == nil {
                interior.currentWant = BookWant(
                    id: "simulation-want-\(offset)",
                    kind: .tellTheReader,
                    line: "I want to tell the reader a thought that belongs to this Book.",
                    why: "History, taste, work, and knowledge briefly made one shape.",
                    evidencePageIDs: [],
                    bornAt: now,
                    status: .stirring,
                    resolvedAt: nil
                )
            }
            inputs.bookInterior = interior
            interior = BookInteriorEngine.reconciled(interior, inputs: inputs, now: now)
            if let initiative = interior.currentInitiative {
                if initiative.kind == .characteristicSurprise {
                    surpriseDates.append(now)
                    receipts.append(initiative.ingredientReceipts ?? [])
                    XCTAssertEqual(initiative.mode, .sayOnly)
                    XCTAssertNil(initiative.answeredAt)
                    XCTAssertNil(initiative.readerReplyExcerpt)
                    XCTAssertTrue(initiative.openingLine.contains("No assignment"))
                }
                interior = BookInteriorEngine.recordingSurfaceOpened(
                    interior,
                    initiativeID: initiative.id,
                    now: now.addingTimeInterval(60)
                )
            }
        }

        XCTAssertGreaterThanOrEqual(surpriseDates.count, 10)
        XCTAssertLessThanOrEqual(surpriseDates.count, 16)
        XCTAssertTrue(receipts.allSatisfy { $0.count >= 5 })
        XCTAssertTrue(receipts.allSatisfy { receipt in
            receipt.contains(where: { $0.hasPrefix("memory:") })
                && receipt.contains(where: { $0.hasPrefix("taste:") })
                && receipt.contains(where: { $0.hasPrefix("project:") })
                && receipt.contains(where: { $0.hasPrefix("loyalty:") })
                && receipt.contains(where: { $0.hasPrefix("self-fact:") })
        })
        XCTAssertTrue(zip(surpriseDates, surpriseDates.dropFirst()).allSatisfy {
            $1.timeIntervalSince($0) >= 120 * day
        })
    }

    func testFourYearsLetARevealedSecretBecomeEchoArgumentAndInheritanceOnceEach() {
        let secret = BookSecret(
            id: "simulation-long-secret",
            family: .hope,
            tease: "I have a hope I dislike displaying.",
            revelation: "I hope ordinary life can remain stranger than its summaries.",
            sealedAt: start.addingTimeInterval(-30 * day),
            status: .revealed,
            revealedAt: start
        )
        var interior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-500 * day),
            secretHistory: [secret]
        )
        var presentedStages: [BookSecretLegacyStage] = []
        var presentedDates: [Date] = []

        for offset in 0..<(365 * 4) {
            let now = start.addingTimeInterval(Double(offset) * day)
            interior = BookInteriorEngine.reconciled(interior, inputs: .empty, now: now)
            if let legacy = interior.secretLegacies.first, legacy.hasUnpresentedChange {
                presentedStages.append(legacy.stage)
                presentedDates.append(now)
                interior = BookInteriorEngine.recordingSurfaceOpened(
                    interior,
                    secretLegacyID: legacy.id,
                    now: now.addingTimeInterval(60)
                )
            }
        }

        XCTAssertEqual(presentedStages, [.echo, .argument, .inheritance])
        XCTAssertEqual(interior.secretLegacies.first?.stage, .inheritance)
        XCTAssertEqual(interior.autobiography.filter { $0.kind == .secretConsequence }.count, 3)
        XCTAssertGreaterThanOrEqual(presentedDates[1].timeIntervalSince(presentedDates[0]), 365 * day)
        XCTAssertGreaterThanOrEqual(presentedDates[2].timeIntervalSince(presentedDates[1]), 730 * day)
    }

    func testLongGameOwnsTheOnlyForcedInterventionSlot() {
        let hypothesis = BookLongGameHypothesis(
            id: "simulation-desk-sovereignty",
            capacity: .worldOtherness,
            statement: "The autonomous world has not had enough room.",
            nextHonestTest: "Keep one purpose that is not about the reader.",
            evidenceIDs: [],
            formedAt: start,
            lastRevisedAt: start
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "mature-archive",
            date: start.addingTimeInterval(-day),
            pages: (0..<4).map { keptPage($0) }
        )]
        inputs.bookInterior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-20 * day),
            longGame: BookLongGame(
                phase: .estrangeTheFamiliar,
                strategy: "Let the world exceed the reader's scene.",
                startedAt: start.addingTimeInterval(-10 * day),
                lastAdvancedAt: start,
                phasePresentedAt: start,
                milestones: [],
                hypotheses: [hypothesis]
            )
        )

        let shelf = BookCurator.surfacedPages(
            for: BookDay(id: BookDay.id(for: start), date: start, pages: []),
            inputs: inputs,
            now: start,
            limit: 1
        )

        XCTAssertEqual(shelf.count, 1)
        XCTAssertEqual(
            shelf.first?.payload.metadata["bookCurationDirectiveID"],
            BookCurationDirective.make(from: hypothesis).id
        )
        XCTAssertNotEqual(shelf.first?.type, .tarot)
    }

    private struct SimulationResult {
        var visibleSurfaceIDs: Set<String>
        var visibleDays: Set<String>
        var campaignIDs: Set<String>
        var tactics: [BookCampaignTactic]
        var pressures: [BookCampaignPressure]
        var completedCampaigns: [BookReenchantmentCampaign]
        var campaignHistoryCount: Int
    }

    private func simulate(days horizon: Int) -> SimulationResult {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "archive",
            date: start.addingTimeInterval(-20 * day),
            pages: (0..<3).map { keptPage($0) }
        )]
        inputs.selfFacts = [SelfFact(
            id: "simulation-pressure-ceiling",
            questionID: "simulation-pressure-ceiling",
            question: "How sharp should the Book get?",
            answer: "gentle",
            bookTranslation: "Invite me.",
            sensitivity: .comfort,
            usePermission: .privateContext,
            tags: ["simulation"],
            createdAt: start,
            updatedAt: start
        )]

        var game = BookLongGame(
            phase: .wakeTheSenses,
            strategy: "Interrupt automatic seeing, then withdraw.",
            startedAt: start.addingTimeInterval(-10 * day),
            lastAdvancedAt: start,
            phasePresentedAt: start,
            milestones: [],
            hypotheses: [BookLongGameHypothesis(
                id: "simulation-world-otherness",
                capacity: .worldOtherness,
                statement: "The autonomous world has not had enough room.",
                nextHonestTest: "Keep one purpose that is not about the reader.",
                evidenceIDs: [],
                formedAt: start,
                lastRevisedAt: start
            )]
        )

        var visibleSurfaceIDs = Set<String>()
        var visibleDays = Set<String>()
        var campaignIDs = Set<String>()
        var tactics: [BookCampaignTactic] = []
        var pressures: [BookCampaignPressure] = []

        for offset in 0..<horizon {
            let now = start.addingTimeInterval(Double(offset) * day)
            BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)

            guard let campaign = game.currentCampaign else { continue }
            if campaignIDs.insert(campaign.id).inserted {
                tactics.append(campaign.tactic)
                pressures.append(campaign.pressure)
            }
            guard campaign.mayClaimDeskSlot else { continue }

            let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])
            guard let surface = BookReenchantmentDirector.surface(
                for: campaign,
                day: today,
                inputs: inputs
            ), visibleSurfaceIDs.insert(surface.id).inserted else { continue }

            visibleDays.insert(today.id)
            inputs.readerLearning.record(ReaderLearningEvent(
                dayID: today.id,
                occurredAt: now.addingTimeInterval(60),
                action: .surfaced,
                surfaceID: surface.id,
                sourceID: surface.sourceID,
                type: surface.type,
                varietyKey: campaign.id,
                hour: 12,
                tags: [campaign.receiptTag]
            ))
        }

        return SimulationResult(
            visibleSurfaceIDs: visibleSurfaceIDs,
            visibleDays: visibleDays,
            campaignIDs: campaignIDs,
            tactics: tactics,
            pressures: pressures,
            completedCampaigns: game.campaignHistory,
            campaignHistoryCount: game.campaignHistory.count
        )
    }

    private func keptPage(_ index: Int) -> BookPage {
        BookPage(
            id: "simulation-kept-\(index)",
            type: .souvenir,
            createdAt: start.addingTimeInterval(Double(-20 - index) * day),
            promptText: "Keep one exact thing.",
            userInput: "A literal detail from the ordinary world.",
            origin: .userAuthored
        )
    }
}

private extension Array {
    func windows(ofCount count: Int) -> [ArraySlice<Element>] {
        guard count > 0, self.count >= count else { return [] }
        return (0...(self.count - count)).map { self[$0..<($0 + count)] }
    }
}
