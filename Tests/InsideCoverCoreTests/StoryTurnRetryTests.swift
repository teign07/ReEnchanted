import Foundation
import XCTest

@testable import InsideCoverCore

/// What happens when a story beat is rejected.
final class StoryTurnRetryTests: XCTestCase {
    private let landing = "Mara admits she kept the second key."

    /// A rejected beat used to be answered by calling the writer again with an
    /// identical context - a second roll of the same dice, which had no reason
    /// to fix anything and no reason to follow on from the beat before it.
    func testTheRetryIsToldWhatWentWrong() {
        let atmosphere = """
            The room held its light. Dust moved across the window glass and the \
            air went still against the shelf, and the shadow on the surface of \
            the frame did not move at all.
            """
        let note = StoryTurnValidator.correction(
            for: atmosphere, landing: landing, character: "Mara", names: ["Mara", "Tobias"])
        XCTAssertTrue(note.lowercased().contains("landing") || note.contains(landing), note)
        XCTAssertTrue(note.lowercased().contains("protagonist"), note)
        XCTAssertFalse(note.isEmpty)
    }

    /// A correction always says something, even when the rail cannot name which
    /// rule broke - an empty note would put us back to rolling blind.
    func testACorrectionIsNeverEmpty() {
        let note = StoryTurnValidator.correction(
            for: "Mara decided.", landing: landing, character: "Mara", names: ["Mara"])
        XCTAssertFalse(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// The bug the reader actually saw: a long first beat thrown away for a
    /// short second one, purely for being first.
    func testAFailedRetryDoesNotDiscardABetterFirstDraft() {
        let long = """
            Mara set both mugs down and did not sit. Tobias asked again, quieter \
            this time, and she turned the smaller key over twice in her hand \
            before she answered him.
            """
        let short = "The room was quiet."
        XCTAssertEqual(StoryTurnValidator.preferred(first: long, second: short), long)
    }

    /// And a genuinely fuller retry still wins.
    func testAFullerRetryIsPreferred() {
        let thin = "She said nothing."
        let fuller = """
            Mara set both mugs down and did not sit. Tobias asked again, and she \
            turned the key over twice before she answered.
            """
        XCTAssertEqual(StoryTurnValidator.preferred(first: thin, second: fuller), fuller)
    }

    /// A beat cut off before its landing was being rejected for lacking an
    /// ending it was never allowed to write - a budget failure judged as a
    /// content failure, which is what made the rail reject longer generations.
    func testACutOffBeatIsRecognisedAsTruncated() {
        let cut = String(repeating: "Mara turned the key over and said nothing more about it. ", count: 5)
            + "Tobias started to answer and then"
        XCTAssertTrue(StoryTurnValidator.looksTruncated(cut))
        let note = StoryTurnValidator.correction(
            for: cut, landing: landing, character: "Mara", names: ["Mara", "Tobias"])
        XCTAssertTrue(note.lowercased().contains("cut off"), note)
    }

    /// A finished beat is never mistaken for a cut-off one, however short.
    func testAFinishedBeatIsNotTruncated() {
        XCTAssertFalse(StoryTurnValidator.looksTruncated("Mara admitted she kept the second key."))
        XCTAssertFalse(
            StoryTurnValidator.looksTruncated("\"I kept it,\" she said, and did not look away."))
    }

    /// And a short fragment is a thin answer, not a cut-off one.
    func testAShortFragmentIsNotCalledTruncated() {
        XCTAssertFalse(StoryTurnValidator.looksTruncated("She said nothing"))
    }

    /// An empty retry is not a draft at all.
    func testAnEmptyRetryNeverWins() {
        XCTAssertEqual(
            StoryTurnValidator.preferred(first: "Mara admitted it.", second: "   "),
            "Mara admitted it.")
    }
}
