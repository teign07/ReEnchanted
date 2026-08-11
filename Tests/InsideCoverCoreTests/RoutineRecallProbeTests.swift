import XCTest
@testable import InsideCoverCore

/// The Book's opening argument. A vague "replay it for me" gets flattered
/// answers; "was there a bumper sticker" gets an honest one. These pin the
/// properties that make the beat work.
final class RoutineRecallProbeTests: XCTestCase {

    func testEveryScenarioCanBeAskedWithoutRepeatingItself() {
        for scenario in RoutineRecallProbe.scenarios {
            let asked = RoutineRecallProbe.questions(scenarioID: scenario.id, seed: "reader-one")
            XCTAssertEqual(asked.count, RoutineRecallProbe.askedCount, scenario.id)
            XCTAssertEqual(Set(asked).count, asked.count, "\(scenario.id) asked the same thing twice")
            XCTAssertTrue(Set(asked).isSubset(of: Set(scenario.questions)), scenario.id)
        }
    }

    func testTheSameReaderIsAlwaysAskedTheSameThree() {
        // Backing up and returning must not reshuffle the questions: different
        // questions on a second look would expose the machinery.
        for scenario in RoutineRecallProbe.scenarios {
            let first = RoutineRecallProbe.questions(scenarioID: scenario.id, seed: "seed-abc")
            let again = RoutineRecallProbe.questions(scenarioID: scenario.id, seed: "seed-abc")
            XCTAssertEqual(first, again, scenario.id)
        }
    }

    func testDifferentReadersGetDifferentDraws() {
        // Not guaranteed per-pair, but across many seeds the pool must actually
        // be used rather than collapsing to one favourite trio.
        var seen: Set<[String]> = []
        for index in 0..<40 {
            seen.insert(RoutineRecallProbe.questions(scenarioID: "drove", seed: "reader-\(index)"))
        }
        XCTAssertGreaterThan(seen.count, 1, "every reader gets an identical draw")
    }

    func testThePoolIsBiggerThanTheAskSoTwoReadersCanDiffer() {
        for scenario in RoutineRecallProbe.scenarios {
            XCTAssertGreaterThan(scenario.questions.count, RoutineRecallProbe.askedCount, scenario.id)
        }
    }

    func testAnUnknownScenarioAsksNothingRatherThanCrashing() {
        XCTAssertTrue(RoutineRecallProbe.questions(scenarioID: "teleported", seed: "x").isEmpty)
        XCTAssertNil(RoutineRecallProbe.scenario(id: "teleported"))
    }

    // MARK: The register

    func testTheVerdictNeverConsolesAndNeverScolds() {
        let banned = ["don't feel", "it's okay", "it's not your fault", "sorry",
                      "you should", "try to", "unfortunately", "sadly"]
        for scenario in RoutineRecallProbe.scenarios {
            for remembered in 0...3 {
                let verdict = RoutineRecallProbe.verdict(remembered: remembered, scenario: scenario).lowercased()
                for phrase in banned {
                    XCTAssertFalse(verdict.contains(phrase), "\(scenario.id)/\(remembered): '\(phrase)'")
                }
            }
        }
    }

    /// An attentive reader must not be told they are cursed when they have just
    /// demonstrated they aren't: that would be the beat's worst failure.
    func testAReaderWhoRemembersEverythingIsNotToldTheyLostIt() {
        for scenario in RoutineRecallProbe.scenarios {
            let verdict = RoutineRecallProbe.verdict(remembered: 3, scenario: scenario)
            XCTAssertFalse(verdict.contains("left you nothing"), scenario.id)
            XCTAssertTrue(verdict.contains("actually there"), scenario.id)
        }
    }

    func testTheProbesAskForSensesRatherThanFeelings() {
        // Feelings can be confabulated on the spot; a bumper sticker cannot.
        let evaluative = ["how did it feel", "were you happy", "did you enjoy", "what did it mean"]
        for scenario in RoutineRecallProbe.scenarios {
            for question in scenario.questions {
                let lowered = question.lowercased()
                for phrase in evaluative {
                    XCTAssertFalse(lowered.contains(phrase), "\(scenario.id): \(question)")
                }
                XCTAssertTrue(question.hasSuffix("?"), "\(scenario.id): \(question)")
            }
        }
    }
}
