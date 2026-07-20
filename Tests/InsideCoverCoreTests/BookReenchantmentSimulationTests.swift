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
