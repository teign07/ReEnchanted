import XCTest
@testable import InsideCoverCore

/// Errands are the driver of the whole book, and they kept getting rationed by
/// accident. First every playful mission was stamped `pressureCost: 0.78`,
/// three hundredths over the high-pressure threshold, so the entire family
/// spent the curator's action budget. That was fixed by making individual
/// missions cheaper — which left the rations themselves standing: two outward
/// attempts a rolling week, one action Page per three leaves, and a `.play`
/// desk job whose own documentation called it "the spice".
///
/// These tests guard the second fix. Nobody ever *decided* to meter the thing
/// that sends the reader out into their day; a handful of constants did it, and
/// constants grow back. If one of these fails, read
/// `gentle-register-is-an-injection` before "correcting" the number.
final class MissionNerveTests: XCTestCase {

    private var all: [PlayfulMission] { PlayfulMissionRegistry.missions }

    func testTheFamilyIsNotUniformlyHighPressureAnyMore() {
        let highPressure = all.filter { $0.missionNerve >= 0.75 }
        XCTAssertLessThan(
            Double(highPressure.count) / Double(all.count), 0.25,
            "most of the family is still rated as a high-pressure experiment"
        )
    }

    /// The thing the reader can do without standing up must be cheap enough to
    /// arrive as often as the Book likes.
    func testAnIndoorLowEnergyMissionIsNearlyFree() {
        let cozy = all.filter {
            let t = $0.tags.map { $0.lowercased() }
            return t.contains("inside") && t.contains("low-energy")
        }
        XCTAssertFalse(cozy.isEmpty, "no indoor low-energy missions to check")
        for mission in cozy {
            XCTAssertLessThan(mission.missionNerve, 0.75, mission.id)
            XCTAssertEqual(mission.missionMobility, .stationary, mission.id)
        }
    }

    /// Nerve is an honest description of an errand, so leaving the house has to
    /// rate higher than noticing the thing beside you. This is about picking the
    /// right mission for the day — never about whether the reader has earned one.
    func testGoingOutsideTakesMoreNerve() {
        let outward = all.filter(\.goesOutside)
        XCTAssertFalse(outward.isEmpty)
        for mission in outward {
            XCTAssertGreaterThan(mission.missionNerve, 0.4, mission.id)
            XCTAssertEqual(mission.missionMobility, .shortDistance, mission.id)
        }
    }

    func testNerveStaysInsideItsBounds() {
        for mission in all {
            XCTAssertGreaterThanOrEqual(mission.missionNerve, 0.12, mission.id)
            XCTAssertLessThanOrEqual(mission.missionNerve, 0.85, mission.id)
            XCTAssertGreaterThan(mission.missionMinutes, 0, mission.id)
        }
    }

    /// Cozy is a temperament, not another Page family.
    func testCozyIsATemperamentAndSomeMissionsHaveIt() {
        let temperaments = Set(all.map(\.temperament))
        XCTAssertTrue(temperaments.contains("A Cozy Mission"), "nothing reads as cozy")
        XCTAssertGreaterThan(temperaments.count, 2, "every mission reads the same way")
        for name in temperaments {
            XCTAssertTrue(name.hasPrefix("A ") || name.hasPrefix("An "), name)
        }
    }

    func testEveryMissionHasACharacterWhoseInterestsExplainIt() {
        for mission in all {
            XCTAssertFalse(mission.host.slug.isEmpty, mission.id)
            XCTAssertFalse(mission.host.name.isEmpty, mission.id)
            XCTAssertFalse(mission.host.assetName.isEmpty, mission.id)
            XCTAssertFalse(mission.host.invitationLine.isEmpty, mission.id)
        }

        let peopleMission = PlayfulMission(
            id: "host-people",
            title: "Shared glint",
            prompt: "Pass one glint onward.",
            proofPrompt: "What came back?",
            tags: ["people", "kindness"]
        )
        let shadowMission = PlayfulMission(
            id: "host-shadow",
            title: "Worn edge",
            prompt: "Inspect one worn edge.",
            proofPrompt: "What held?",
            tags: ["shadow-wonder"]
        )

        XCTAssertEqual(peopleMission.host.slug, "serenity-brown")
        XCTAssertEqual(shadowMission.host.slug, "dusk-thorn")
    }
}

// MARK: - The rations themselves

/// Guards on the constants that quietly did the metering. Each of these was a
/// defensible-looking number that added up to a Book which never asks for
/// anything.
final class ErrandRationTests: XCTestCase {

    /// Two outward errands a rolling week is not a book that re-enchants a life.
    /// The ceiling exists only so the causal estimator keeps some unasked days
    /// to compare against; it is not a dignity rule.
    func testTheRollingWeekLeavesRoomForRoughlyOneErrandADay() {
        XCTAssertGreaterThanOrEqual(
            CausalCurationLedger.outwardErrandsPerWeek, 6,
            "outward errands are rationed below one a day again"
        )
    }
}

// Distress is the real safety valve and is deliberately untouched by this work:
// the adapters guard on `context.distress.isActive` and withdraw errands
// entirely rather than metering them. Anything that wants to protect the reader
// belongs there, where it is legible, and not in a curator cap that also quietly
// suppresses the reader's best day.
