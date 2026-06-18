import XCTest
@testable import InsideCoverCore

final class BraidTextPolisherTests: XCTestCase {
    func testPolisherRemovesRepeatedSentenceIdeasBeyondKnownMotifs() {
        let braid = """
        The glass caught condensation by the lamp. The coffee stood beside it.

        Condensation caught on the glass near the lamp. The spoon clicked once and settled.

        The Book kept the page: morning kept one clear edge.
        """

        let polished = BraidTextPolisher.polishedBookOfYou(braid)

        XCTAssertTrue(polished.contains("The glass caught condensation by the lamp."))
        XCTAssertFalse(polished.contains("Condensation caught on the glass near the lamp."))
        XCTAssertTrue(polished.contains("The spoon clicked once and settled."))
        XCTAssertTrue(polished.contains("The Book kept the page:"))
    }

    func testPolisherRemovesRepeatedAbsenceMotifForSamePerson() {
        let braid = """
        The lamps dropped low in the stacks. This felt like a day for small thresholds. Warm fuel demanded no heroic errands. You felt the silence. It was lonely without Morgan near.

        The pen rested on the desk. It was a leprechaun. You did not notice it first. Hard to believe. The silence felt lonely without Morgan.

        The silence held a lonely weight. It lacked Morgan's presence. The silence felt thin.

        The Book kept the page: The light caught the condensation forming on the glass.
        """

        let polished = BraidTextPolisher.polishedBookOfYou(braid)

        XCTAssertTrue(polished.contains("It was lonely without Morgan near."))
        XCTAssertFalse(polished.contains("The silence felt lonely without Morgan."))
        XCTAssertFalse(polished.contains("It lacked Morgan's presence."))
        XCTAssertTrue(polished.contains("The Book kept the page:"))
    }

    func testPolisherLimitsParagraphsButPreservesClosing() {
        let braid = """
        One.

        Two.

        Three.

        Four.

        Five.

        Six.

        The Book kept the page: seven.
        """

        let polished = BraidTextPolisher.polishedBookOfYou(braid, maxParagraphs: 5, maxWords: 100)
        let paragraphs = polished.components(separatedBy: "\n\n")

        XCTAssertEqual(paragraphs.count, 5)
        XCTAssertEqual(paragraphs.last, "The Book kept the page: seven.")
    }
}
