import XCTest
@testable import InsideCoverCore

/// Reported from a real first session: after onboarding and the local-brain
/// download, the desk returned a single "write one sentence" card, over and
/// over, with the other slots empty. Restarting cleared it.
///
/// Cause: two separate rules cap reader-facing asks on the visible desk: the
/// composition limit and the ask budget, and both were hard caps with no
/// floor. A young library whose only eligible families are the write-one-thing
/// families therefore produced a one-card desk. Both rules are right; they just
/// have to yield rather than starve.
final class FreshDeskStarvationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)

    private func candidate(_ type: BookPageType, score: Int) -> SurfacePage {
        SurfacePage(
            id: "cand-\(type.rawValue)", type: type, sourceID: "src-\(type.rawValue)",
            score: score, prompt: type.title, detail: "Candidate.",
            payload: BookPagePayload(headline: type.title, body: "b", metadata: [:])
        )
    }

    private func freshMood() -> CuratorMood {
        var mood = CuratorMood.neutral
        mood.keptPageCount = 2
        mood.isFirstHours = true
        mood.surfaceHistory = [:]
        mood.hour = 10
        return mood
    }

    /// The reported failure.
    func testADeskOfOnlyWritingPromptsStillFillsItsSlots() {
        let candidates = [
            candidate(.souvenir, score: 90), candidate(.diary, score: 88),
            candidate(.mood, score: 86), candidate(.aboutYou, score: 84)
        ]
        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: freshMood(), now: now).map(\.page)
        XCTAssertGreaterThan(pages.count, 1, "the desk starved down to a single card again")
        XCTAssertEqual(Set(pages.map(\.type)).count, pages.count, "and it repeated a type doing it")
    }

    /// The rule it must not have broken: when the desk *can* be furnished from
    /// other families, one blank-page prompt is still the limit. Three cards
    /// all asking the reader to write something is a chore, not a desk.
    func testOneWritingPromptIsStillTheLimitWhenThereIsAnythingElse() {
        let candidates = [
            candidate(.souvenir, score: 96), candidate(.diary, score: 94),
            candidate(.mood, score: 92), candidate(.aboutYou, score: 90),
            candidate(.rest, score: 70), candidate(.weather, score: 68),
            candidate(.wonderCompass, score: 66)
        ]
        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: freshMood(), now: now).map(\.page)
        XCTAssertEqual(pages.count, 3)
        let prompts = pages.filter(\.type.isCompositionPrompt)
        XCTAssertLessThanOrEqual(prompts.count, 1, "the visible desk stacked writing prompts")
    }

    /// A desk with nothing to show is allowed to be short; it is not allowed to
    /// be short *because of its own caps*.
    func testAThinPoolIsNotPaddedWithRepeats() {
        let pages = BookCurator.rankedPages(
            from: [candidate(.souvenir, score: 90)], limit: 3, mood: freshMood(), now: now
        ).map(\.page)
        XCTAssertEqual(pages.count, 1)
    }
}
