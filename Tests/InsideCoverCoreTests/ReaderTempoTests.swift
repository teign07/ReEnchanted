import XCTest
@testable import InsideCoverCore

/// Every clock in the Curator used to be somebody else's: instruments rested
/// 3.5 hours, a kept sentence stayed owed for 72, a Page waited 6–10 hours per
/// sibling. All of it was written for an imagined reader who opens the Book
/// about three times a day — and the bursty reader in the fortnight simulation
/// is exactly who those numbers fail.
final class ReaderTempoTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func history(sittingsPerDay: Int, days: Int) -> [String: SurfaceHistoryRecord] {
        var history: [String: SurfaceHistoryRecord] = [:]
        for day in 0..<days {
            for sitting in 0..<sittingsPerDay {
                let at = now.addingTimeInterval(
                    -Double(day) * 86_400 - Double(sitting) * (86_400 / Double(max(1, sittingsPerDay)))
                )
                history["key-\(day)-\(sitting)"] = SurfaceHistoryRecord(lastShownAt: at, recentShowCount: 1)
            }
        }
        return history
    }

    func testAFrequentReaderGetsTighterClocksThanAnOccasionalOne() {
        let frequent = ReaderTempo.measured(history: history(sittingsPerDay: 6, days: 14), now: now)
        let occasional = ReaderTempo.measured(history: history(sittingsPerDay: 1, days: 14), now: now)

        XCTAssertGreaterThan(frequent.sittingsPerDay, occasional.sittingsPerDay)
        XCTAssertLessThan(frequent.hoursBetweenSittings, occasional.hoursBetweenSittings)
        XCTAssertLessThan(
            frequent.instrumentSpacingHours, occasional.instrumentSpacingHours,
            "a tool should be within reach each sitting, whatever a sitting means to this reader"
        )
        XCTAssertLessThan(
            frequent.answerWindowHours, occasional.answerWindowHours,
            "a reader who comes back twice a week must not have their sentence go stale first"
        )
    }

    /// Three sittings is not a rhythm. Below that the Book keeps its assumption
    /// rather than tuning itself to noise, so a first week behaves as before.
    func testANewReaderKeepsTheAssumedTempo() {
        var sparse: [String: SurfaceHistoryRecord] = [:]
        sparse["a"] = SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3600), recentShowCount: 1)

        XCTAssertEqual(ReaderTempo.measured(history: sparse, now: now), .assumed)
        XCTAssertEqual(ReaderTempo.measured(history: [:], now: now), .assumed)
    }

    /// Pages served eleven minutes apart are one sitting, not two.
    func testOneSittingIsNotCountedTwice() {
        var burst: [String: SurfaceHistoryRecord] = [:]
        for index in 0..<12 {
            burst["k\(index)"] = SurfaceHistoryRecord(
                lastShownAt: now.addingTimeInterval(-Double(index) * 60),
                recentShowCount: 1
            )
        }
        // Twelve served Pages inside twelve minutes is one sitting, which is
        // not a rhythm, so the Book should decline to tune on it.
        XCTAssertEqual(ReaderTempo.measured(history: burst, now: now), .assumed)
    }

    /// The clocks that read the tempo have to actually move with it.
    func testTheDeckClockIsMeasuredInThisReadersSittings() {
        let frequent = ReaderTempo.measured(history: history(sittingsPerDay: 6, days: 14), now: now)
        let occasional = ReaderTempo.measured(history: history(sittingsPerDay: 1, days: 14), now: now)

        let frequentRest = CuratorNoveltyPolicy.deckAwareBaseHours(belief: 50, deckSize: 5, tempo: frequent)
        let occasionalRest = CuratorNoveltyPolicy.deckAwareBaseHours(belief: 50, deckSize: 5, tempo: occasional)

        XCTAssertLessThan(
            frequentRest, occasionalRest,
            "a Page waits for its siblings, and a sitting is however long this reader's sittings are"
        )
    }
}
