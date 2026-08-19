import XCTest
@testable import InsideCoverCore

/// The Curator has always known a three-beat rhythm — Door (a way in), Echo
/// (the Book reflecting something back), Horizon (the world beyond). When three
/// cards sat on a desk the reader chose where to look, so order was a detail.
/// Turning one leaf at a time, order *is* the experience.
final class BookCuratorReadingArcTests: XCTestCase {
    private func page(
        _ id: String,
        _ type: BookPageType,
        role: BookSessionRole?,
        score: Int = 50
    ) -> SurfacePage {
        var metadata: [String: String] = [:]
        if let role {
            metadata[BookSessionIntention.metadataRole] = role.rawValue
        }
        return SurfacePage(
            id: id,
            type: type,
            sourceID: id,
            score: score,
            prompt: id,
            detail: id,
            payload: BookPagePayload(headline: id, body: id, metadata: metadata)
        )
    }

    private func roles(of pages: [SurfacePage]) -> [BookSessionRole?] {
        pages.map(\.preparedExperimentRole)
    }

    func testAStampedBlockComposesIntoDoorEchoHorizonActs() {
        // Deliberately clustered by role, the way a rank-ordered list arrives.
        let block = [
            page("d1", .diary, role: .door), page("d2", .diary, role: .door), page("d3", .diary, role: .door),
            page("e1", .bookNotices, role: .echo), page("e2", .bookNotices, role: .echo), page("e3", .bookNotices, role: .echo),
            page("h1", .letter, role: .horizon), page("h2", .letter, role: .horizon), page("h3", .letter, role: .horizon)
        ]

        let arc = BookCurator.readingArc(block)

        XCTAssertEqual(
            roles(of: arc),
            [.door, .echo, .horizon, .door, .echo, .horizon, .door, .echo, .horizon],
            "Nine Pages should read as three acts, not three clumps."
        )
        XCTAssertEqual(Set(arc.map(\.id)), Set(block.map(\.id)), "Composing must not drop or invent Pages.")
    }

    /// Reordering must never become a second ranking system: inside one beat the
    /// better-ranked Page still goes first.
    func testRankDecidesWithinABeat() {
        let block = [
            page("d-best", .diary, role: .door, score: 90),
            page("d-worst", .diary, role: .door, score: 10),
            page("e1", .bookNotices, role: .echo),
            page("h1", .letter, role: .horizon)
        ]

        let arc = BookCurator.readingArc(block)
        let doors = arc.filter { $0.preparedExperimentRole == .door }.map(\.id)
        XCTAssertEqual(doors, ["d-best", "d-worst"])
    }

    /// A thin block should still move through the rhythm rather than collapsing
    /// back into a ranked list.
    func testAnUnevenBlockStillAlternates() {
        let block = [
            page("d1", .diary, role: .door),
            page("d2", .diary, role: .door),
            page("e1", .bookNotices, role: .echo)
        ]

        let arc = BookCurator.readingArc(block)
        XCTAssertEqual(arc.first?.id, "d1", "The best-ranked Door still opens.")
        XCTAssertEqual(arc.count, 3)
        XCTAssertEqual(Set(arc.map(\.id)), Set(block.map(\.id)))
    }

    /// With no movement and nothing stamped there is no rhythm to compose, so
    /// the block should fall through to lane spacing rather than shuffle.
    func testAnUnstampedBlockFallsBackToLaneSpacing() {
        let block = [
            page("a", .diary, role: nil), page("b", .diary, role: nil),
            page("c", .diary, role: nil), page("d", .letter, role: nil)
        ]

        let arc = BookCurator.readingArc(block)
        XCTAssertEqual(arc, BookCurator.readingSequence(block))
        XCTAssertEqual(arc.first?.id, "a", "The opening Page still holds.")
    }

    func testShortBlocksAreUntouched() {
        let block = [page("a", .diary, role: .door), page("b", .letter, role: .horizon)]
        XCTAssertEqual(BookCurator.readingArc(block).map(\.id), ["a", "b"])
    }
}
