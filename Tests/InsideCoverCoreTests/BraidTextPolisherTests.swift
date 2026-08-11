import XCTest
@testable import InsideCoverCore

final class BraidTextPolisherTests: XCTestCase {
    /// A well-formed braid must survive the polisher intact. The absence
    /// vocabulary includes ordinary prepositions ("without", "near", "alone"),
    /// and second-person past tense (which the braid prompt mandates) opens
    /// most sentences with "You" or "It". Together those once deleted the day's
    /// actual turn out of healthy prose and left non-sequitur fragments behind.
    func testPolisherLeavesWellFormedBraidIntact() {
        let braid = """
        The Coat That Would Not Dry

        You woke before the alarm and the rain had already started without you. The kettle sulked on the back burner, taking its time, and you stood at the window with your hands flat on the cold sill.

        Marguerite called near noon and you let it ring twice before answering. She wanted to know whether you were coming Sunday.

        You took the bins out without a jacket and got wet for eleven seconds, which was the most decisive thing you did all day. It went sideways under the streetlight and you laughed at nothing, alone, in the dark.

        You touched the shoulder, found it cold, and left it hanging rather than move it near the heat where it would have dried by morning.

        The Book kept the page: a coat left wet on purpose, and a Sunday not yet refused.
        """

        let polished = BraidTextPolisher.polishedBookOfYou(braid)

        XCTAssertEqual(polished, braid, "The polisher deleted a sentence from a clean braid.")
    }

    func testPolisherKeepsOrdinaryPrepositionsAcrossSentences() {
        let braid = """
        You sat near the window without turning the lamp on.

        The chair stood near the door and the coat hung without company beside it.

        The Book kept the page: two quiet things left where they were.
        """

        let polished = BraidTextPolisher.polishedBookOfYou(braid)

        XCTAssertTrue(polished.contains("The chair stood near the door and the coat hung without company beside it."))
    }

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
