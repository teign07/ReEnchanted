import XCTest

@testable import InsideCoverCore

/// The verifier's job is to make a rewrite safe. It was only ever stopping the
/// model from *adding* words: every offered word had to exist in the original,
/// but only nouns and numbers were required to survive. Everything else could
/// be dropped, including the word that said the thing did not happen.
final class BraidTruthPreservationTests: XCTestCase {
    private func accepts(_ candidate: String, of original: String) -> Bool {
        BraidRevisionVerifier.preservesFacts(candidate, of: original)
    }

    /// Every one of these was accepted before the polarity check existed, and
    /// this is the path that ships: the sentence-aligned Gemma revision.
    func testAReversedNegationIsRefused() {
        XCTAssertFalse(accepts("You called Sam.", of: "I did not call Sam."))
        XCTAssertFalse(accepts("One came to the door.", of: "No one came to the door."))
        XCTAssertFalse(accepts("You finished the letter.", of: "I never finished the letter."))
        XCTAssertFalse(accepts("You went outside today.", of: "I did not go outside today."))
    }

    func testContractedNegationIsRefused() {
        XCTAssertFalse(accepts("You rang your brother.", of: "I didn't ring my brother."))
        XCTAssertFalse(accepts("You could sleep.", of: "I couldn't sleep."))
    }

    /// A hedge is not a denial, but losing one still tells the reader something
    /// they did not say.
    func testALostHedgeIsRefused() {
        XCTAssertFalse(accepts("You slept.", of: "I barely slept."))
        XCTAssertFalse(accepts("You go out.", of: "I rarely go out."))
    }

    /// And a negation may not be invented either.
    func testAnInventedNegationIsRefused() {
        XCTAssertFalse(accepts("You did not call Sam.", of: "I called Sam."))
    }

    /// Two negations must both survive: dropping one changes a fact.
    func testBothNegationsMustSurvive() {
        XCTAssertFalse(
            accepts("I never called, and wrote.", of: "I never called and never wrote."))
    }

    /// The point is a verifier that still permits real rewriting.
    func testAnHonestRewriteIsStillAllowed() {
        XCTAssertTrue(accepts("You called Sam.", of: "I called Sam."))
        XCTAssertTrue(accepts("Sam was called.", of: "I called Sam."))
        XCTAssertTrue(accepts("You did not call Sam.", of: "I did not call Sam."))
        XCTAssertTrue(accepts("You never finished the letter.", of: "I never finished the letter."))
    }
}
