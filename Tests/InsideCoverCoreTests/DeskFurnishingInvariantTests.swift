import XCTest
@testable import InsideCoverCore

/// One invariant, standing in for four bugs that each had the same shape:
///
///     The desk is never shorter than its material allows for reasons that are
///     only preferences.
///
/// The cooldown fallback that only fired at zero; the mirror floor that
/// outranked kindness under distress; the composition limit and the one-ask cap
/// starving a young library; the evergreen identity that reset on the very
/// action meant to suppress it. Each was individually sensible and each handed
/// a reader a one-card desk. This asserts the outcome rather than any one
/// mechanism, so the fifth version fails here instead of in somebody's hands.
final class DeskFurnishingInvariantTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)

    /// Types with no capability requirements, no memory gate and no staged
    /// debut, so anything excluded is excluded by taste, not by eligibility.
    private let plainTypes: [BookPageType] = [
        .souvenir, .diary, .mood, .aboutYou, .rest, .body, .fuel, .note, .quotes
    ]

    private func candidate(_ type: BookPageType, score: Int, source: String? = nil) -> SurfacePage {
        SurfacePage(
            id: "c-\(type.rawValue)-\(score)", type: type,
            sourceID: source ?? "src-\(type.rawValue)", score: score,
            prompt: type.title, detail: "d",
            payload: BookPagePayload(headline: type.title, body: "b", metadata: [:])
        )
    }

    /// The invariant, over many shapes of reader and shelf.
    func testTheDeskIsNeverShorterThanItsMaterialAllows() {
        var checked = 0
        for typeCount in 1...plainTypes.count {
            let types = Array(plainTypes.prefix(typeCount))
            for keptPageCount in [0, 2, 5, 14, 40] {
                for firstHours in [true, false] {
                    for staleHours in [0, 1, 30, 200] {
                        var mood = CuratorMood.neutral
                        mood.keptPageCount = keptPageCount
                        mood.isFirstHours = firstHours
                        mood.hour = 10
                        mood.surfaceHistory = Dictionary(
                            uniqueKeysWithValues: types.map {
                                (
                                    CuratorVarietyGovernor.typeKey(for: $0),
                                    SurfaceHistoryRecord(
                                        lastShownAt: now.addingTimeInterval(-Double(staleHours) * 3600),
                                        recentShowCount: 1
                                    )
                                )
                            }
                        )
                        let candidates = types.enumerated().map { candidate($1, score: 90 - $0 * 3) }
                        let pages = BookCurator.rankedPages(
                            from: candidates, limit: 3, mood: mood, now: now
                        ).map(\.page)

                        let expected = min(3, types.count)
                        XCTAssertEqual(
                            pages.count, expected,
                            "types=\(types.count) kept=\(keptPageCount) firstHours=\(firstHours) stale=\(staleHours)h "
                                + "-> \(pages.count) cards, expected \(expected)"
                        )
                        XCTAssertEqual(
                            Set(pages.map(\.type)).count, pages.count,
                            "the desk repeated a type to fill itself"
                        )
                        checked += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 300, "the sweep did not actually run")
    }

    /// The relaxation must not become an excuse to break correctness.
    func testFurnishingNeverDuplicatesATypeOrASourceFamily() {
        var mood = CuratorMood.neutral
        mood.keptPageCount = 1
        mood.isFirstHours = true
        mood.hour = 10
        // Four cards, one shared source family, two shared types.
        let candidates = [
            candidate(.souvenir, score: 90, source: "shared"),
            candidate(.diary, score: 88, source: "shared"),
            candidate(.mood, score: 86, source: "other"),
            candidate(.mood, score: 84, source: "another")
        ]
        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: mood, now: now).map(\.page)
        XCTAssertEqual(Set(pages.map(\.type)).count, pages.count, "duplicate type on the desk")
        XCTAssertEqual(Set(pages.map(\.sourceID)).count, pages.count, "duplicate source family on the desk")
    }

    /// An honestly thin shelf is still allowed to be short. The invariant is
    /// about preferences, not about inventing material.
    func testAThinShelfStaysShortRatherThanBeingPadded() {
        var mood = CuratorMood.neutral
        mood.keptPageCount = 1
        mood.hour = 10
        let pages = BookCurator.rankedPages(
            from: [candidate(.souvenir, score: 90)], limit: 3, mood: mood, now: now
        ).map(\.page)
        XCTAssertEqual(pages.count, 1)
    }
}
