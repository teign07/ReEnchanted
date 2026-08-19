import XCTest
@testable import InsideCoverCore

/// The folio publishes `reserveCapacity` Pages as consecutive leaves. Acts 1
/// and 2 used to be `.afterKeep` and `.afterDismissal` — two mutually exclusive
/// answers to what the reader did — so the reader turned through the current
/// act, then the "if you kept it" answer, then the "if you refused it" answer,
/// whichever they had actually done. A decision tree laid end to end.
final class BookPublishedBlockIsSequentialTests: XCTestCase {
    func testNothingInsideThePublishedBlockIsACounterfactual() {
        for actIndex in 0..<BookPreparedExperimentScore.sequentialActCount {
            XCTAssertEqual(
                BookPreparedExperimentScore.branch(forActIndex: actIndex),
                .current,
                "Act \(actIndex) is inside the block the reader turns through."
            )
        }
    }

    /// The counterfactual machinery still exists — it just applies past the
    /// sequence, where BookCurator.preparedReplacementOrder draws the branch
    /// matching what the reader actually did.
    func testBranchingResumesImmediatelyPastTheBlock() {
        let firstBranching = BookPreparedExperimentScore.sequentialActCount
        XCTAssertEqual(BookPreparedExperimentScore.branch(forActIndex: firstBranching), .afterKeep)
        XCTAssertEqual(BookPreparedExperimentScore.branch(forActIndex: firstBranching + 1), .afterDismissal)
        XCTAssertEqual(BookPreparedExperimentScore.branch(forActIndex: firstBranching + 2), .adaptive)
    }

    /// The sequence must cover the whole published block. If the block ever
    /// grows past the acts kept sequential, counterfactuals start arriving as
    /// reading again — which is the bug this exists to prevent.
    func testTheSequenceCoversEveryPublishedLeaf() {
        let sequentialPages = BookPreparedExperimentScore.sequentialActCount
            * BookSessionRole.allCases.count
        XCTAssertGreaterThanOrEqual(
            sequentialPages,
            BookDeskRound.reserveCapacity,
            "Every Page in a published block must be part of the sequence."
        )
    }

    /// Only branches that answer an outcome should claim one; a sequential Page
    /// must never match a Keep or a refusal and be drawn as a reply.
    func testSequentialPagesAnswerNoOutcome() {
        let current = BookPreparedExperimentBranch.current
        XCTAssertFalse(current.matches(.kept))
        XCTAssertFalse(current.matches(.dismissed))
        XCTAssertFalse(current.matches(.acted))
    }
}
