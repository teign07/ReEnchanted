import XCTest
@testable import InsideCoverCore

/// Belief is the reader's own investment, and an investment has to buy
/// something they can feel.
///
/// It was quietly devalued once already. The first deck-aware rest let Belief
/// scale only the per-sibling appetite while deck size multiplied on top, so a
/// beloved Page in a ten-card family went from waiting eighteen hours to
/// waiting forty-two — Belief still "worked", and had stopped mattering. These
/// hold the line at the size the reader would notice.
final class BeliefStaysALeverTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testABelovedPageComesBackMarkedlySoonerThanAnUninvestedOne() {
        for deckSize in [1, 3, 10, 25] {
            let uninvested = CuratorNoveltyPolicy.deckAwareBaseHours(belief: 0, deckSize: deckSize)
            let beloved = CuratorNoveltyPolicy.deckAwareBaseHours(belief: 100, deckSize: deckSize)
            XCTAssertLessThan(
                beloved, uninvested,
                "deck \(deckSize): Belief bought nothing"
            )
        }
    }

    /// The exact regression. In a large family, deck size must not swallow the
    /// investment: a believed Page skips most of the queue rather than a
    /// rounding error of it.
    func testDeckSizeDoesNotSwallowBeliefInALargeFamily() {
        let uninvested = CuratorNoveltyPolicy.deckAwareBaseHours(belief: 0, deckSize: 10)
        let beloved = CuratorNoveltyPolicy.deckAwareBaseHours(belief: 100, deckSize: 10)

        XCTAssertLessThan(
            beloved * 2, uninvested,
            "a beloved Page waited \(Int(beloved))h against \(Int(uninvested))h — Belief should more than halve the queue"
        )
    }

    /// Belief buys a shorter wait, never no wait. An exact repeat still owes
    /// the reader the better part of a day however loved it is.
    func testBeliefNeverBuysAnInstantRepeat() {
        for deckSize in [1, 3, 10] {
            XCTAssertGreaterThanOrEqual(
                CuratorNoveltyPolicy.deckAwareBaseHours(belief: 100, deckSize: deckSize), 18,
                "deck \(deckSize)"
            )
        }
    }

    /// Belief scales smoothly rather than switching on at some threshold, so
    /// spending a little is worth a little.
    func testBeliefIsAGradientNotASwitch() {
        let steps = [0, 25, 50, 75, 100].map {
            CuratorNoveltyPolicy.deckAwareBaseHours(belief: $0, deckSize: 12)
        }
        for (higher, lower) in zip(steps, steps.dropFirst()) {
            XCTAssertGreaterThan(higher, lower, "rest should fall with every step of Belief: \(steps)")
        }
    }

    /// A Loose Remark has a catalogue and its own identity per quip, so the
    /// *kind* returning with different words is not a repeat. It used to be
    /// banned for 72 hours alongside the radio and the inventory, which are
    /// genuinely one card each.
    func testAQuipIsNoLongerThrottledLikeASingleCardUtility() {
        XCTAssertFalse(CuratorMood.slowDeskTypes.contains(.quip))
        for single in [BookPageType.radio, .inventory, .helpTips, .patreon] {
            XCTAssertTrue(
                CuratorMood.slowDeskTypes.contains(single),
                "\(single.rawValue) is one card and should still rest by kind"
            )
        }

        var mood = CuratorMood.neutral
        mood.surfaceHistory[CuratorVarietyGovernor.typeKey(for: .quip)] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-6 * 3600), recentShowCount: 1
        )
        let quip = SurfacePage(
            id: "q", type: .quip, sourceID: "quips", score: 50,
            prompt: "A Loose Remark", detail: "d",
            payload: BookPagePayload(headline: "A Loose Remark", body: "b", metadata: ["quipID": "q-2"])
        )
        XCTAssertTrue(
            mood.allowsTypeRefresh(for: quip, now: now),
            "a different quip six hours later is not the same remark twice"
        )
    }
}
