import Foundation
import XCTest

@testable import InsideCoverCore

/// Where the Story Page brief and the rail underneath it disagreed.
///
/// A rail must not refuse what the brief asked for. Three places did.
final class StoryVoiceAndRailTests: XCTestCase {
    private let landing = "The lamp gives up its corner of the room."

    // MARK: - The voice

    /// `animismLine` is written for the Book talking *to* the reader - "you are
    /// I/me/my", "address the reader as you" - and Story Pages handed it
    /// verbatim to a writer producing third-person fiction, while the rail
    /// underneath required third person. Told to do both, a model does neither.
    func testStoryNarrationDoesNotAskForReaderAddress() {
        let voice = BookVoice.storyNarration.lowercased()
        XCTAssertFalse(voice.contains("address the reader as"), BookVoice.storyNarration)
        XCTAssertTrue(voice.contains("not talking to the reader"), BookVoice.storyNarration)
    }

    /// What must survive the change: the temperament, the animism mandate, and
    /// the carve-out that keeps characters sounding like themselves.
    func testStoryNarrationKeepsTheFeralEyeAndTheCharactersOwnVoices() {
        let voice = BookVoice.storyNarration.lowercased()
        XCTAssertTrue(voice.contains("half-feral"), BookVoice.storyNarration)
        XCTAssertTrue(voice.contains("act on its own"), BookVoice.storyNarration)
        XCTAssertTrue(voice.contains("named characters keep their own voices"), BookVoice.storyNarration)
        XCTAssertTrue(voice.contains("never soothe"), BookVoice.storyNarration)
    }

    // MARK: - The rails

    /// An environmental recipe is told "the place, object, weather, or Nothing
    /// may act and change; dialogue is optional" - and was then failed for
    /// having no person in it.
    func testAnEnvironmentalSceneMayHaveNoPersonInIt() {
        let prose = "The lamp gave up its corner of the room and let the dark have it."
        XCTAssertFalse(
            StoryTurnValidator.asserts(prose, landing: landing, character: "Mara"))
        XCTAssertTrue(
            StoryTurnValidator.asserts(
                prose, landing: landing, character: "Mara", sceneMode: .environmental))
    }

    /// And it may let the room act, which is the entire point of the mode.
    func testAnEnvironmentalSceneIsNotAtmosphereDominated() {
        let prose = """
            The room took the light back. Dust held still on the glass, and the \
            window kept the shadow where the frame wanted it, and the air did \
            not move at all across the cold surface of the sill.
            """
        XCTAssertTrue(
            StoryTurnValidator.isAtmosphereDominated(prose, characterNames: ["Mara", "Tobias"]))
        XCTAssertFalse(
            StoryTurnValidator.isAtmosphereDominated(
                prose, characterNames: ["Mara", "Tobias"], sceneMode: .environmental))
    }

    /// A conversation scene still owes us people.
    func testAConversationSceneStillOwesPeople() {
        let prose = """
            The room took the light back. Dust held still on the glass, and the \
            window kept the shadow where the frame wanted it, and the air did \
            not move at all across the cold surface of the sill.
            """
        XCTAssertTrue(
            StoryTurnValidator.isAtmosphereDominated(
                prose, characterNames: ["Mara", "Tobias"], sceneMode: .conversation))
    }

    /// The scene half exempted only conversation scenes, so balanced and action
    /// scenes escaped a check they should face. Both halves read one rule now.
    func testBalancedAndActionScenesAreHeldToIt() {
        for mode in [StoryRecipeSceneMode.balanced, .action, .conversation] {
            XCTAssertTrue(StoryTurnValidator.rejectsAtmosphere(mode), "\(mode)")
        }
        XCTAssertFalse(StoryTurnValidator.rejectsAtmosphere(.environmental))
        // No recipe at all keeps the strict default.
        XCTAssertTrue(StoryTurnValidator.rejectsAtmosphere(nil))
    }
}
