import XCTest
@testable import InsideCoverCore

/// The Cast's business, said by them: interviews and op-eds turn what was
/// written about a character into what they'd say themselves.
final class BleedFirstPersonTests: XCTestCase {
    private func speak(_ text: String, _ actor: String) -> String { BleedFirstPerson.speak(text, actorID: actor) }

    func testTheirOwnReasonsInTheirOwnVoice() {
        XCTAssertEqual(speak("He buys the handwriting of the dead at estate sales. This one was loved harder than the rest.", "ambrose-trencher"),
                       "I buy the handwriting of the dead at estate sales. This one was loved harder than the rest.")
        XCTAssertEqual(speak("Penny can forgive a lie. She cannot forgive a quiet edit.", "penny-blackletter"),
                       "I can forgive a lie. I cannot forgive a quiet edit.")
        XCTAssertEqual(speak("Wicker is not interested in the room. Wicker is interested in the word 'sealed'.", "wicker-eddies"),
                       "I am not interested in the room. I am interested in the word 'sealed'.")
        XCTAssertEqual(speak("Inkrest suspects that most insight is only impatience wearing a good coat.", "dr-inkrest"),
                       "I suspect that most insight is only impatience wearing a good coat.")
        XCTAssertEqual(speak("Zara has guided a hundred readers to the threshold and has never once crossed it.", "zara-finch"),
                       "I have guided a hundred readers to the threshold and have never once crossed it.")
        XCTAssertEqual(speak("Thorne has her reasons. She does not offer them, and nobody has yet been rude enough to ask.", "headmistress-thorne"),
                       "I have my reasons. I do not offer them, and nobody has yet been rude enough to ask.")
    }

    func testTheSecondVerbAndTheObjectPronounFollow() {
        XCTAssertEqual(speak("Wicker measures the sealed door and finds it four inches narrower than its frame.", "wicker-eddies"),
                       "I measure the sealed door and find it four inches narrower than its frame.")
        XCTAssertEqual(speak("Three faculty tell her these things are not magic. She writes down their names too.", "lydia-boggle"),
                       "Three faculty tell me these things are not magic. I write down their names too.")
        XCTAssertEqual(speak("Lydia is tired of wonder getting all the credit and none of the maintenance.", "lydia-boggle"),
                       "I am tired of wonder getting all the credit and none of the maintenance.")
    }

    func testAPronounKeepsItsVerbAndARelativeClauseKeepsItsOwn() {
        XCTAssertEqual(speak("Trencher buys a swollen volume in a language he does not read.", "ambrose-trencher"),
                       "I buy a swollen volume in a language I do not read.")
        XCTAssertEqual(speak("Zara shows it to nobody, then shows it to Trencher, who reads it and puts food down.", "zara-finch"),
                       "I show it to nobody, then show it to Trencher, who reads it and puts food down.")
        XCTAssertEqual(speak("Orion checks this four times and then stops checking.", "orion-blackthorn"),
                       "I check this four times and then stop checking.")
    }

    func testTheirStaysWithWhatItBelongsTo() {
        XCTAssertEqual(speak("Vellum's models are correct, which is why their failures are so interesting.", "dr-vellum"),
                       "My models are correct, which is why their failures are so interesting.")
    }

    func testAnInstructionBecomesWhatTheyAreTryingToDo() {
        XCTAssertEqual(BleedFirstPerson.pursuit("Cook the one page in a water-damaged book he cannot read.", actorID: "ambrose-trencher"),
                       "I'm trying to cook the one page in a water-damaged book I cannot read.")
        XCTAssertEqual(BleedFirstPerson.pursuit("Write the first line of the Great Unwritten Chapter herself.", actorID: "zara-finch"),
                       "I'm trying to write the first line of the Great Unwritten Chapter myself.")
    }
}
