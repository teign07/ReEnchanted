import XCTest
@testable import InsideCoverCore

/// The Book is the narrator, so the braid closes "I kept the page:". Braids
/// archived before 2026-10-17 close "The Book kept the page:" and must still
/// read as closed, print as the colophon, and never leak into the telling.
final class BraidColophonTests: XCTestCase {
    func testNewBraidsCloseInTheBooksOwnVoice() {
        XCTAssertEqual(BraidColophon.stem, "I kept the page:")
        let finished = BraidNarrativeOutput.finished(
            "You carried the plums home in your coat pocket.",
            reachedCeiling: false,
            keeperColophon: "I kept the page: the plums stayed cold."
        )
        XCTAssertTrue(finished.hasSuffix("I kept the page: the plums stayed cold."), finished)
        XCTAssertFalse(finished.contains("The Book kept"), finished)
    }

    func testArchivedLegacyColophonStillReadsAsTheEnding() {
        let archived = "You carried the plums home.\n\nThe Book kept the page: the plums stayed cold."
        XCTAssertTrue(BraidNarrativeOutput.hasLandedColophon(archived))
        XCTAssertFalse(BraidNarrativeOutput.isMalformedColophon("The Book kept the page: the plums stayed cold."))
        XCTAssertTrue(BraidNarrativeOutput.isIncompleteColophon("The Book kept the page:"))

        let (telling, kept) = WeeklyTaleBuilder.split(braid: archived)
        XCTAssertEqual(telling, "You carried the plums home.")
        XCTAssertEqual(kept, "I kept the page: the plums stayed cold.", "printed editions say it the new way")
        XCTAssertEqual(BoundNightLine.keptLine(from: archived), "the plums stayed cold.")
    }

    func testCleaningModernizesALegacyStemFromTheModel() {
        let cleaned = BraidNarrativeOutput.cleaned(
            "You carried the plums home. The Book kept the page: the plums stayed cold."
        )
        XCTAssertTrue(cleaned.hasSuffix("\n\nI kept the page: the plums stayed cold."), cleaned)
    }

    func testAnOrdinarySentenceEndingInKeptThePageIsNotEaten() {
        let cleaned = BraidNarrativeOutput.cleaned(
            "The wind took the receipt off the table, and I kept the page.\n\nI kept the page: the receipt flew."
        )
        XCTAssertTrue(cleaned.contains("and I kept the page."), cleaned)
        XCTAssertTrue(cleaned.hasSuffix("I kept the page: the receipt flew."), cleaned)
    }
}
