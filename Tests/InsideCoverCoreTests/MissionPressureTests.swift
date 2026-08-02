import XCTest
@testable import InsideCoverCore

/// Every playful mission used to be stamped `pressureCost: 0.78` — three
/// hundredths over the high-pressure threshold — so the whole family spent the
/// curator's action budget and fell under a limiter that allows two attempts a
/// rolling week. Nobody chose to ration playful missions; one constant did it.
final class MissionPressureTests: XCTestCase {

    private var all: [PlayfulMission] { PlayfulMissionRegistry.missions }

    func testTheFamilyIsNotUniformlyHighPressureAnyMore() {
        let highPressure = all.filter { $0.missionPressureCost >= 0.75 }
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
            XCTAssertLessThan(mission.missionPressureCost, 0.75, mission.id)
            XCTAssertEqual(mission.missionMobility, .stationary, mission.id)
        }
    }

    /// The limiter is right for missions that genuinely ask something. It must
    /// keep working for those.
    func testGoingOutsideStillCostsSomething() {
        let outward = all.filter(\.goesOutside)
        XCTAssertFalse(outward.isEmpty)
        for mission in outward {
            XCTAssertGreaterThan(mission.missionPressureCost, 0.4, mission.id)
            XCTAssertEqual(mission.missionMobility, .shortDistance, mission.id)
        }
    }

    func testPressureStaysInsideItsBounds() {
        for mission in all {
            XCTAssertGreaterThanOrEqual(mission.missionPressureCost, 0.12, mission.id)
            XCTAssertLessThanOrEqual(mission.missionPressureCost, 0.85, mission.id)
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
}
