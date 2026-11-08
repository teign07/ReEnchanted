import XCTest
@testable import InsideCoverCore

/// Belief is the one number the reader earns by noticing and spends in the
/// fiction. It used to hide behind light-names ("Small Glow"), so the Inkbones
/// line "Belief 34 gives you 55" pointed at a number the reader had never seen.
final class BeliefLexiconTests: XCTestCase {
    func testTheLabelIsTheNumber() {
        XCTAssertEqual(BeliefLexicon.label(for: 34), "Belief 34")
        XCTAssertEqual(BeliefLexicon.label(for: -5), "Belief 0")
        XCTAssertEqual(BeliefLexicon.label(for: 140), "Belief 100")
    }

    func testEveryRungHasItsOwnLine() {
        let lines = Set(stride(from: 0, through: 100, by: 10).map(BeliefLexicon.state(for:)))
        XCTAssertEqual(lines.count, 10, "No two rungs may share a line.")
        for score in -20...140 {
            XCTAssertFalse(BeliefLexicon.state(for: score).isEmpty, "Score \(score) should clamp to a described rung.")
        }
    }

    func testNoGlowLeftInTheWords() {
        for score in 0...100 {
            XCTAssertFalse(BeliefLexicon.label(for: score).lowercased().contains("glow"))
            XCTAssertFalse(BeliefLexicon.state(for: score).lowercased().contains("glow"))
        }
    }

    func testBandsCoverTheWholeRange() {
        XCTAssertEqual(BeliefLexicon.Band.of(0), .little)
        XCTAssertEqual(BeliefLexicon.Band.of(29), .little)
        XCTAssertEqual(BeliefLexicon.Band.of(30), .middling)
        XCTAssertEqual(BeliefLexicon.Band.of(59), .middling)
        XCTAssertEqual(BeliefLexicon.Band.of(60), .strong)
        XCTAssertEqual(BeliefLexicon.Band.of(100), .strong)
    }
}
