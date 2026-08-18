import Foundation
import XCTest

@testable import InsideCoverCore

/// Signals a beat can earn, rather than only rules it can break.
///
/// Every rail on Story Pages was negative - no atmosphere, no echo, no
/// invention, no contradiction - and negative rails asymptote at "not bad". A
/// beat cleared the gate by not failing, so a merely adequate paragraph and a
/// genuinely good one were indistinguishable, and nothing preferred the good one.
final class StoryBeatTasteTests: XCTestCase {
    private func brief(owesPayoff: Bool = false, seed: String = "") -> StoryBeatTaste.Brief {
        StoryBeatTaste.Brief(
            landing: "Mara admits she kept the second key.",
            character: "Mara",
            otherCharacterNames: ["Mara", "Tobias"],
            sceneMode: .conversation,
            promiseSeed: seed,
            owesPromisePayoff: owesPayoff)
    }

    /// The whole reason the beat exists.
    func testEnactingTheLandingIsWorthMoreThanAnythingElse() {
        let enacted = """
            "I kept it," Mara said. She put the second key on the table between \
            them and did not take her hand off it. Tobias looked at the key.
            """
        let evasive = """
            The afternoon went on. Tobias waited, and the kitchen held its breath, \
            and neither of them said the thing that was sitting in the room.
            """
        XCTAssertGreaterThan(
            StoryBeatTaste.read(enacted, brief: brief()).score,
            StoryBeatTaste.read(evasive, brief: brief()).score)
    }

    /// The promise is planted by the prompt and was checked by nobody, which is
    /// exactly how a vignette ends up evocative and hollow.
    func testAPromiseThatComesBackScoresHigherThanOneThatDoesNot() {
        let seed = "the chipped enamel jug on the sill"
        let paysOff = """
            "I kept it," Mara said, and set the second key inside the chipped \
            enamel jug where it had been all along. Tobias laughed once.
            """
        let abandons = """
            "I kept it," Mara said, and put the second key in her pocket. \
            Tobias laughed once, and let it go at that.
            """
        let owed = brief(owesPayoff: true, seed: seed)
        XCTAssertGreaterThan(
            StoryBeatTaste.read(paysOff, brief: owed).score,
            StoryBeatTaste.read(abandons, brief: owed).score)
    }

    /// A promise is only owed at the end. An opening beat is not punished for
    /// keeping its seed unresolved - that is what a seed is for.
    func testAnOpeningBeatIsNotPunishedForHoldingItsSeed() {
        let seed = "the chipped enamel jug on the sill"
        let opening = """
            "I kept it," Mara said, and put the second key in her pocket. \
            Tobias laughed once, and let it go at that.
            """
        XCTAssertEqual(
            StoryBeatTaste.read(opening, brief: brief(owesPayoff: false, seed: seed)).score,
            StoryBeatTaste.read(opening, brief: brief(owesPayoff: false, seed: "")).score)
    }

    /// The Book's most important rule, which no check has ever looked for.
    func testAnObjectDoingSomethingOfItsOwnIsRewarded() {
        XCTAssertEqual(ProseTaste.objectThatActs(in: "The kettle's sulking again."), "kettle")
        XCTAssertEqual(ProseTaste.objectThatActs(in: "The door gave up halfway."), "door")
        XCTAssertNil(ProseTaste.objectThatActs(in: "The kettle was on the stove."))
    }

    /// The voice bans hedges outright and nothing checked.
    func testHedgingIsPenalised() {
        let hedged = """
            "I kept it," Mara said, as if the key had asked her to, and Tobias \
            seemed to understand what she meant by it.
            """
        let plain = """
            "I kept it," Mara said. The key stayed where she put it. Tobias \
            understood her exactly.
            """
        XCTAssertGreaterThan(
            StoryBeatTaste.read(plain, brief: brief()).score,
            StoryBeatTaste.read(hedged, brief: brief()).score)
    }

    /// The commonest way a good beat goes slack in its last sentence.
    func testAnEndingThatExplainsItselfIsPenalised() {
        let lands = """
            "I kept it," Mara said, and put the second key on the table. \
            Tobias picked it up.
            """
        let explains = """
            "I kept it," Mara said, and put the second key on the table. \
            In the end she realized that trust meant telling him the truth.
            """
        XCTAssertGreaterThan(
            StoryBeatTaste.read(lands, brief: brief()).score,
            StoryBeatTaste.read(explains, brief: brief()).score)
    }

    /// A conversation scene with nobody speaking is the failure the mode exists
    /// to prevent.
    func testATalkingSceneWithNoTalkingLosesPoints() {
        let silent = "Mara put the second key on the table. Tobias picked it up and kept it."
        let taste = StoryBeatTaste.read(silent, brief: brief())
        XCTAssertTrue(
            taste.signals.contains { $0.name.contains("no dialogue") }, taste.summary)
    }

    /// The score is readable, because a number nobody can explain is a number
    /// nobody should tune.
    func testTheScoreExplainsItself() {
        let taste = StoryBeatTaste.read(
            "\"I kept it,\" Mara said, and the door gave up halfway behind Tobias.",
            brief: brief())
        XCTAssertFalse(taste.summary.isEmpty)
        XCTAssertEqual(taste.score, taste.signals.reduce(0) { $0 + $1.points })
    }
}

/// The half of taste that means the same thing wherever the Book is writing.
///
/// Two engines grew up separately with half a palate each: the braid could see
/// concrete magic, a prior echo returning changed, amplitude and repetition;
/// Story Pages could see an object acting, a hedge, an abstraction pile-up and
/// an ending that explains itself. Neither could see the other's half, and both
/// were judging the same Book's prose.
final class ProseTasteTests: XCTestCase {
    private func points(_ prose: String) -> Int {
        ProseTaste.signals(in: prose).reduce(0) { $0 + $1.points }
    }

    /// The loudest line in the Book's own voice - "MOST IMPORTANT: at least one
    /// ordinary thing must act on its own" - and until now nothing anywhere
    /// checked whether it happened.
    func testAnOrdinaryThingActingIsWorthSomething() {
        XCTAssertEqual(ProseTaste.objectThatActs(in: "The kettle's sulking again."), "kettle")
        XCTAssertEqual(ProseTaste.objectThatActs(in: "The door gave up halfway."), "door")
        XCTAssertNil(ProseTaste.objectThatActs(in: "The kettle was on the stove."))
    }

    func testHedgingAndSelfExplainingCost() {
        XCTAssertLessThan(points("The lamp leaned in as if it were listening."), 0)
        XCTAssertLessThan(
            points("She put the key down. He picked it up. Which is why it mattered."), 0)
    }

    /// Both engines must read the same prose the same way, or the Book is being
    /// judged by two different rulebooks depending on which surface it wrote on.
    func testBothEnginesReadTheSameProseTheSameWay() {
        let prose = "The kettle's sulking. She put the second key on the table and left it there."
        let shared = points(prose)
        let story = StoryBeatTaste.read(prose, brief: .init()).signals
            .filter { signal in ProseTaste.signals(in: prose).contains { $0.name == signal.name } }
            .reduce(0) { $0 + $1.points }
        XCTAssertEqual(shared, story)
    }
}
