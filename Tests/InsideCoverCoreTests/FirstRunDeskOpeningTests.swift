import XCTest
@testable import InsideCoverCore

/// The First Door ceremony decides how much of the desk is open. It used to
/// hand the whole shelf to every step in turn, so a reader spent four solo
/// cards before three slots ever appeared — and because nothing rebuilt the
/// desk when the local brain finished downloading, the shelf could stay at one
/// card until the next launch.
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

    // MARK: The welcome still gets the room to itself

    func testTheWelcomeOwnsTheWholeDesk() {
        let welcome = page("w", type: .welcome, source: "welcome", step: "first-door-welcome")
        let desk = FirstRunPageSequence.mergingCurrentStep([welcome], into: feed, limit: 3)
        XCTAssertEqual(desk.count, 1, "The first card anybody sees should not have a crowd under it")
        XCTAssertEqual(desk.first?.id, "w")
    }

    // MARK: Every later step leads instead

    func testALaterStepLeadsAFullDesk() {
        let brain = page("b", type: .plainPage, source: "local-brain-awake", step: "local-brain-awake")
        let desk = FirstRunPageSequence.mergingCurrentStep([brain], into: feed, limit: 3)

        XCTAssertEqual(desk.count, 3, "The desk should be open by the second ceremony card")
        XCTAssertEqual(desk.first?.id, "b", "The step must still lead — it is not to be buried")
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

    // MARK: Only the welcome is privileged

    func testExactlyOneStepOwnsTheDesk() {
        let owning = ["first-door-welcome"]
        let leading = ["first-door-origin", "local-brain-setup", "local-brain-awake", "first-mission"]

        for step in owning {
            let card = page("o", type: .welcome, source: "s", step: step)
            XCTAssertTrue(FirstRunPageSequence.stepOwnsWholeDesk(card), "\(step) should own the desk")
        }
        for step in leading {
            let card = page("l", type: .plainPage, source: "s", step: step)
            XCTAssertFalse(FirstRunPageSequence.stepOwnsWholeDesk(card), "\(step) should only lead")
        }
    }

    func testAnOrdinaryPageNeverOwnsTheDesk() {
        XCTAssertFalse(FirstRunPageSequence.stepOwnsWholeDesk(page("f", type: .mood, source: "mood")))
    }
}
