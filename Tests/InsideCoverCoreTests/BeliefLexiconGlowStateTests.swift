import XCTest
@testable import InsideCoverCore

/// The Glow panel once printed one fixed sentence under every rung of the
/// ladder, so the lowest Glow was described as "steady and gently luminous" —
/// borrowing the name of a rung five steps above it. These guard the pairing.
final class BeliefLexiconGlowStateTests: XCTestCase {
    func testEveryRungHasItsOwnDescription() {
        let byName = Dictionary(
            grouping: stride(from: 0, through: 100, by: 1).map {
                (BeliefLexicon.glowName(for: $0), BeliefLexicon.glowState(for: $0))
            },
            by: { $0.0 }
        )

        XCTAssertEqual(byName.count, 10, "The ladder should still have ten rungs.")

        for (name, pairs) in byName {
            let states = Set(pairs.map(\.1))
            XCTAssertEqual(states.count, 1, "\(name) should describe itself one way.")
        }

        let allStates = Set(byName.values.compactMap { $0.first?.1 })
        XCTAssertEqual(allStates.count, 10, "No two rungs may share a description.")
    }

    /// The specific bug: a rung must not describe itself using another rung's
    /// adjective, which is how "Glow Barely There" came to read as "steady".
    func testNoRungBorrowsAnotherRungsAdjective() {
        let adjectives = ["meager", "faint", "small", "warming", "steady", "clear", "bright", "radiant"]

        for score in 0...100 {
            let name = BeliefLexicon.glowName(for: score).lowercased()
            let state = BeliefLexicon.glowState(for: score).lowercased()

            for adjective in adjectives where !name.contains(adjective) {
                XCTAssertFalse(
                    state.contains(adjective),
                    "\(BeliefLexicon.glowName(for: score)) describes itself as '\(adjective)', which names a different rung."
                )
            }
        }
    }

    func testEveryScoreIsDescribed() {
        for score in -20...140 {
            XCTAssertFalse(
                BeliefLexicon.glowState(for: score).isEmpty,
                "Score \(score) should still clamp to a described rung."
            )
        }
    }
}
