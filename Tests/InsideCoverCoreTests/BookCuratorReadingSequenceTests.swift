import XCTest
@testable import InsideCoverCore

/// Lane variety used to be a property of the three-card desk: three Pages on
/// screen together, so a repeat was visible at a glance. The folio turns one
/// leaf at a time, so a repeat is felt across turns instead — and the old rule
/// only ever covered the first three of a nine-Page block.
final class BookCuratorReadingSequenceTests: XCTestCase {
    private func page(_ id: String, _ type: BookPageType, score: Int) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: id,
            score: score,
            prompt: id,
            detail: id,
            payload: BookPagePayload(headline: id, body: id)
        )
    }

    /// .diary is outward, .letter is fiction — one from each lane.
    private func outward(_ id: String, score: Int = 50) -> SurfacePage { page(id, .diary, score: score) }
    private func fiction(_ id: String, score: Int = 50) -> SurfacePage { page(id, .letter, score: score) }

    private func longestRun(_ pages: [SurfacePage]) -> Int {
        var longest = 0
        var run = 0
        var lane: DeskLane?
        for page in pages {
            if page.type.deskLane == lane {
                run += 1
            } else {
                lane = page.type.deskLane
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }

    func testABlockOfOneLaneIsBrokenUpWhenReliefExists() {
        let block = [
            outward("a"), outward("b"), outward("c"), outward("d"),
            fiction("e"), fiction("f")
        ]
        XCTAssertEqual(longestRun(block), 4, "Precondition: the input runs four deep.")

        let sequenced = BookCurator.readingSequence(block)

        XCTAssertLessThanOrEqual(longestRun(sequenced), 2)
        XCTAssertEqual(Set(sequenced.map(\.id)), Set(block.map(\.id)), "Spacing must not drop or invent Pages.")
        XCTAssertEqual(sequenced.count, block.count)
    }

    /// The opening Page is the reader's entire first impression now that only
    /// one leaf shows at a time. Rank chose it; spacing must not overrule it.
    func testTheOpeningPageIsNeverMoved() {
        let block = [outward("door", score: 100), outward("b"), outward("c"), fiction("d")]
        XCTAssertEqual(BookCurator.readingSequence(block).first?.id, "door")
    }

    /// Spacing reorders; it must never re-rank. Within a lane, the better-ranked
    /// Page still comes first.
    func testRankOrderSurvivesWithinALane() {
        let block = [
            outward("o1", score: 90), outward("o2", score: 80), outward("o3", score: 70),
            fiction("f1", score: 60), fiction("f2", score: 50)
        ]
        let sequenced = BookCurator.readingSequence(block)

        let outwardOrder = sequenced.filter { $0.type.deskLane == .outward }.map(\.id)
        let fictionOrder = sequenced.filter { $0.type.deskLane == .fiction }.map(\.id)
        XCTAssertEqual(outwardOrder, ["o1", "o2", "o3"])
        XCTAssertEqual(fictionOrder, ["f1", "f2"])
    }

    /// When every Page shares a lane there is no spacing to be had. Rank wins
    /// rather than the rule silently dropping anything.
    func testASingleLaneBlockIsReturnedIntact() {
        let block = [outward("a"), outward("b"), outward("c"), outward("d")]
        XCTAssertEqual(BookCurator.readingSequence(block).map(\.id), ["a", "b", "c", "d"])
    }

    func testShortBlocksAreUntouched() {
        let block = [outward("a"), outward("b")]
        XCTAssertEqual(BookCurator.readingSequence(block).map(\.id), ["a", "b"])
    }
}
