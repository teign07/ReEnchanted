import XCTest
@testable import InsideCoverCore

/// The first Welcome gets the desk to itself so waking Gemma is the first real
/// action after onboarding. Once the Welcome is engaged, later guidance may
/// lead the open living shelf without hiding the reader's real day.
final class FirstRunDeskOpeningTests: XCTestCase {

    private func page(
        _ id: String,
        type: BookPageType,
        source: String,
        step: String? = nil
    ) -> SurfacePage {
        var metadata: [String: String] = ["source": source]
        if let step { metadata["firstRunStep"] = step }
        return SurfacePage(
            id: id,
            type: type,
            sourceID: source,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 80,
            reason: "r",
            prompt: "p",
            detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: metadata)
        )
    }

    private var feed: [SurfacePage] {
        [
            page("f1", type: .mood, source: "mood"),
            page("f2", type: .diary, source: "diary"),
            page("f3", type: .quotes, source: "quotes")
        ]
    }

    // MARK: The Welcome gets the room to itself

    func testTheWelcomeOwnsTheWholeDesk() {
        let welcome = page("w", type: .welcome, source: "welcome", step: "first-door-welcome")
        let desk = FirstRunPageSequence.mergingCurrentStep([welcome], into: feed, limit: 3)
        XCTAssertEqual(desk.count, 1, "The Gemma Welcome should not compete with unrelated Pages")
        XCTAssertEqual(desk.first?.id, "w")
    }

    // MARK: Every later step leads instead

    func testALaterStepLeadsAFullDesk() {
        let brain = page("b", type: .plainPage, source: "local-brain-awake", step: "local-brain-awake")
        let desk = FirstRunPageSequence.mergingCurrentStep([brain], into: feed, limit: 3)

        XCTAssertEqual(desk.count, 3, "The desk should be open by the second ceremony card")
        XCTAssertEqual(desk.first?.id, "b", "The step must still lead: it is not to be buried")
    }

    func testTheStepIsAlwaysFirstNeverBuried() {
        for step in ["first-door-origin", "local-brain-setup", "local-brain-awake"] {
            let card = page("s-\(step)", type: .plainPage, source: "src-\(step)", step: step)
            let desk = FirstRunPageSequence.mergingCurrentStep([card], into: feed, limit: 3)
            XCTAssertEqual(desk.first?.id, card.id, "\(step) lost the top slot")
        }
    }

    func testAConflictingFeedCardStepsAsideRatherThanSittingBeside() {
        let step = page("s", type: .mood, source: "mood", step: "local-brain-awake")
        let desk = FirstRunPageSequence.mergingCurrentStep([step], into: feed, limit: 3)

        XCTAssertEqual(desk.first?.id, "s")
        XCTAssertFalse(desk.dropFirst().contains { $0.type == .mood },
                       "A duplicate of the step's own type was left on the desk")
        XCTAssertFalse(desk.dropFirst().contains { $0.sourceID == "mood" })
    }

    func testTheDeskNeverExceedsItsLimit() {
        let step = page("s", type: .plainPage, source: "src", step: "local-brain-awake")
        for limit in 0...3 {
            let desk = FirstRunPageSequence.mergingCurrentStep([step], into: feed, limit: limit)
            XCTAssertLessThanOrEqual(desk.count, max(0, limit), "limit \(limit) overflowed")
        }
    }

    func testNoCeremonyMeansAnOrdinaryDesk() {
        let desk = FirstRunPageSequence.mergingCurrentStep(nil, into: feed, limit: 3)
        XCTAssertEqual(desk.count, 3)
        XCTAssertEqual(desk.map(\.id), ["f1", "f2", "f3"])
    }

    func testAThinFeedDoesNotPadItselfBehindTheStep() {
        let step = page("s", type: .plainPage, source: "src", step: "local-brain-awake")
        let desk = FirstRunPageSequence.mergingCurrentStep(
            [step], into: [page("f1", type: .mood, source: "mood")], limit: 3
        )
        XCTAssertEqual(desk.count, 2, "The desk should be as long as its material allows, no longer")
    }

    // MARK: Only the Welcome owns the desk

    func testOnlyTheWelcomeOwnsTheDesk() {
        let welcome = page("w", type: .welcome, source: "welcome", step: "first-door-welcome")
        let leading = ["first-door-welcome", "first-door-origin", "local-brain-setup", "local-brain-awake", "first-mission"]

        XCTAssertTrue(FirstRunPageSequence.stepOwnsWholeDesk(welcome))
        for step in leading where step != "first-door-welcome" {
            let card = page("l", type: .plainPage, source: "s", step: step)
            XCTAssertFalse(FirstRunPageSequence.stepOwnsWholeDesk(card), "\(step) should only lead")
        }
    }

    func testAnOrdinaryPageNeverOwnsTheDesk() {
        XCTAssertFalse(FirstRunPageSequence.stepOwnsWholeDesk(page("f", type: .mood, source: "mood")))
    }
}

/// Letting the ceremony *lead* the desk instead of owning it opened a hole the
/// Curator's own caps could not see: it enforces "at most one reader-facing ask
/// on a visible desk" while building the feed, and the ceremony step is
/// prepended afterwards. A reader in the First Door got the step asking for a
/// sentence and an ordinary page asking for another one right beneath it.
final class FirstRunDeskAskBudgetTests: XCTestCase {

    private func page(
        _ id: String,
        type: BookPageType,
        source: String,
        step: String? = nil,
        asks: Bool = false
    ) -> SurfacePage {
        var metadata: [String: String] = ["source": source]
        if let step { metadata["firstRunStep"] = step }
        // A page is a reader-facing ask when it opens with an imperative: the
        // same rule the Curator uses. "Write one sentence" is the real case
        // this test is about.
        return SurfacePage(
            id: id,
            type: type,
            sourceID: source,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 80,
            reason: "r",
            prompt: asks ? "Write one true sentence" : "Something to read",
            detail: asks ? "Write it down before it goes." : "No answer needed.",
            payload: BookPagePayload(headline: "h", body: "b", metadata: metadata)
        )
    }

    func testAnAskingStepIsNeverStackedOnAnotherAsk() {
        let step = page("s", type: .plainPage, source: "first-door", step: "first-door-origin", asks: true)
        XCTAssertTrue(step.spendsCuratorAskBudget, "Test setup: the step should be an ask")

        let feed = [
            page("f1", type: .souvenir, source: "souvenir", asks: true),
            page("f2", type: .diary, source: "diary", asks: true),
            page("f3", type: .quotes, source: "quotes", asks: false)
        ]
        let desk = FirstRunPageSequence.mergingCurrentStep([step], into: feed, limit: 3)

        XCTAssertEqual(desk.first?.id, "s")
        let asks = desk.filter(\.spendsCuratorAskBudget)
        XCTAssertEqual(asks.count, 1, "Two sentence pages in a row: \(desk.map(\.id))")
        XCTAssertTrue(desk.contains { $0.id == "f3" }, "The non-asking page should still fill a slot")
    }

    func testANonAskingStepStillAllowsOneAskBeneathIt() {
        let step = page("s", type: .plainPage, source: "first-door", step: "local-brain-awake", asks: false)
        let feed = [page("f1", type: .souvenir, source: "souvenir", asks: true)]
        let desk = FirstRunPageSequence.mergingCurrentStep([step], into: feed, limit: 3)
        XCTAssertEqual(desk.count, 2, "A quiet step should not block the desk's one ask")
    }

    func testAnAskingWelcomeStillRespectsTheSingleAskBudget() {
        let welcome = page("w", type: .welcome, source: "welcome", step: "first-door-welcome", asks: true)
        let feed = [page("f1", type: .souvenir, source: "souvenir", asks: true)]
        let desk = FirstRunPageSequence.mergingCurrentStep([welcome], into: feed, limit: 3)
        XCTAssertEqual(desk.count, 1)
    }
}
