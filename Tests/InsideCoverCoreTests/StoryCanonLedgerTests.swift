import Foundation
import XCTest

@testable import InsideCoverCore

/// What a vignette has established, carried forward as facts.
///
/// Prior turns reached the writer as clipped prose - four sentences of the last
/// scene, three of its result - deliberately, because whatever prose the model
/// sees it echoes. Both branches of that trade lose: show prose and it parrots,
/// clip prose and the story forgets itself. A fact cannot be echoed as prose.
final class StoryCanonLedgerTests: XCTestCase {
    private func effect(
        reactor: String = "Mara",
        reaction: String = "sets both mugs down without sitting",
        changed: String,
        warmth: Int = 0,
        tension: Int = 0,
        familiarity: Int = 0
    ) -> StoryDramaticChoiceEffect {
        StoryDramaticChoiceEffect(
            choiceID: "c1",
            role: .progressArc,
            requiredReactorID: reactor.lowercased(),
            requiredReactorName: reactor,
            requiredReaction: reaction,
            readerChoiceEffect: "you asked instead of waiting",
            changedFact: changed,
            memorySummary: "the key was admitted",
            warmthDelta: warmth,
            tensionDelta: tension,
            familiarityDelta: familiarity)
    }

    // MARK: - Accumulating

    /// The material existed per turn and was simply never gathered: the contract
    /// belongs to the draft, so a continuation built a fresh one and the
    /// previous turn's canon was dropped.
    func testAResolvedTurnBecomesCanon() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down. She did not sit.")
        XCTAssertEqual(ledger.establishedFacts, ["Mara kept the second key."])
        XCTAssertEqual(ledger.namedReactors, ["Mara"])
    }

    /// A turn contributes once. Re-folding the same turn would let the page
    /// count one admission twice and drift its own standing.
    func testTheSameTurnIsNeverRecordedTwice() {
        var ledger = StoryCanonLedger()
        for _ in 0..<3 {
            ledger.record(
                turnNumber: 1,
                chosenTitle: "Ask her outright",
                effect: effect(changed: "Mara kept the second key.", tension: 2),
                prose: "Mara set the mugs down.")
        }
        XCTAssertEqual(ledger.entries.count, 1)
        XCTAssertEqual(ledger.tension, 2)
    }

    // MARK: - Telling the writer

    /// Facts are given as constraints, never as material to reuse.
    func testTheLedgerTellsTheWriterWhatIsAlreadyTrue() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down. The mugs went cold.")
        let section = ledger.promptSection()
        XCTAssertTrue(section.contains("Mara kept the second key."), section)
        XCTAssertTrue(section.lowercased().contains("do not re-establish"), section)
        // And what the page has already spent, so the anti-echo contract can be
        // stated from data rather than by starving the writer of context.
        XCTAssertTrue(section.contains("mugs"), section)
    }

    /// An empty ledger says nothing at all rather than an empty heading.
    func testAnUnstartedVignetteSaysNothing() {
        XCTAssertTrue(StoryCanonLedger().promptSection().isEmpty)
    }

    /// The reader never sees a stat, and neither does the prose.
    func testStandingIsDescribedNeverCounted() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Push",
            effect: effect(changed: "Mara kept the second key.", tension: 3),
            prose: "She said nothing for a while.")
        let section = ledger.promptSection()
        XCTAssertTrue(section.lowercased().contains("unresolved"), section)
        XCTAssertFalse(section.contains("3"), section)
    }

    // MARK: - Outliving the vignette

    /// The ledger lives for a session; the people in it do not. Canon becomes
    /// their memory, in the store the Book already keeps - not a second ledger
    /// beside it.
    func testCanonBecomesTheMemoryOfThePeopleItHappenedTo() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down.")
        let writes = ledger.memoryWrites()
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.first?.entityID, "mara")
        XCTAssertTrue(writes.first?.tags.contains("story-canon") ?? false)
        XCTAssertFalse(writes.first?.summary.isEmpty ?? true)
    }

    /// One definition for both ends of the seam: what the sheet stamps on the
    /// kept page is what the keep path reads back.
    func testCanonSurvivesTheRoundTripThroughPageTags() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down.")
        ledger.record(
            turnNumber: 2,
            chosenTitle: "Let it go",
            effect: effect(reactor: "Tobias", changed: "Tobias stopped asking about the key."),
            prose: "Tobias let the subject alone.")

        let recovered = StoryCanonLedger.memoryWrites(fromTags: ledger.canonTags())
        XCTAssertEqual(recovered.map(\.entityID), ["mara", "tobias"])
        XCTAssertEqual(recovered.count, ledger.memoryWrites().count)
    }

    /// Ordinary page tags are not canon and must not become somebody's memory.
    func testUnrelatedTagsAreIgnored() {
        XCTAssertTrue(
            StoryCanonLedger.memoryWrites(fromTags: ["story-page", "keep", "diary"]).isEmpty)
        XCTAssertTrue(
            StoryCanonLedger.memoryWrites(fromTags: ["story-canon:malformed"]).isEmpty)
    }

    // MARK: - Holding a beat to it

    /// The contradiction a reader actually notices: something un-happening.
    func testABeatThatReversesAnEstablishedFactIsCaught() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down.")
        let reversal = "Mara never kept the second key, and said so plainly."
        XCTAssertEqual(ledger.contradiction(in: reversal), "Mara kept the second key.")
    }

    /// A Story Page may invent freely inside its fiction. Only reversal is
    /// refused, or the ledger would start rejecting every new sentence.
    func testOrdinaryInventionIsNotAContradiction() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down.")
        XCTAssertNil(ledger.contradiction(in: "Mara turned the key over twice and put it in her pocket."))
        XCTAssertNil(ledger.contradiction(in: "Tobias asked about the window instead."))
    }

    /// A fact the beat never touches cannot be contradicted by it.
    func testAnUnrelatedBeatIsLeftAlone() {
        var ledger = StoryCanonLedger()
        ledger.record(
            turnNumber: 1,
            chosenTitle: "Ask her outright",
            effect: effect(changed: "Mara kept the second key."),
            prose: "Mara set the mugs down.")
        XCTAssertNil(ledger.contradiction(in: "The rain did not stop before dark."))
    }
}
