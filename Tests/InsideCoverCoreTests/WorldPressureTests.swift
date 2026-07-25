import XCTest
@testable import InsideCoverCore

/// One emergent transition, several small marks, no new Pages.
final class WorldPressureTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private func days(_ count: Double) -> Date { start.addingTimeInterval(count * 86_400) }
    private func name(_ id: String) -> String { id.replacingOccurrences(of: "-", with: " ").capitalized }

    private func field(tension: Int = 0, warmth: Int = 0) -> [String: RelationshipTie] {
        var tie = RelationshipTie()
        tie.add(warmth: warmth, tension: tension)
        return ["penny-blackletter|wicker-eddies": tie]
    }

    // MARK: - Minting

    func testARivalryMintsAPressure() {
        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        XCTAssertEqual(pressures.count, 1)
        XCTAssertEqual(pressures.first?.origin, .rivalry)
        XCTAssertEqual(pressures.first?.subjectIDs.count, 2)
    }

    func testAnOrdinaryDisagreementIsNotARivalry() {
        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 3),
            advancedUndertaking: nil, castName: name, now: start
        )
        XCTAssertTrue(pressures.isEmpty, "A bad afternoon is not a state transition")
    }

    func testWarmthMintsAnAlliance() {
        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: field(warmth: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        XCTAssertEqual(pressures.first?.origin, .alliance)
    }

    func testAtMostTwoPressuresAreEverActive() {
        var pressures: [WorldPressure] = []
        var relationships = field(tension: 30)
        var extra = RelationshipTie(); extra.add(warmth: 30)
        relationships["zara-finch|orion-blackthorn"] = extra
        var third = RelationshipTie(); third.add(tension: 25)
        relationships["dr-vellum|lydia-boggle"] = third

        for _ in 0..<10 {
            pressures = WorldPressureEngine.minting(
                into: pressures, relationshipField: relationships,
                advancedUndertaking: nil, castName: name, now: start
            )
        }
        XCTAssertLessThanOrEqual(pressures.count, WorldPressure.maximumActive)
    }

    func testMintingIsIdempotentForTheSameTransition() {
        let once = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        let twice = WorldPressureEngine.minting(
            into: once, relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        XCTAssertEqual(once.map(\.id), twice.map(\.id))
    }

    func testAnUndertakingStageCanMintItsOwnPressure() {
        let undertaking = CastUndertakingEngine.seeded(existing: [], now: start).first
        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: [:],
            advancedUndertaking: undertaking, castName: name, now: start
        )
        XCTAssertEqual(pressures.first?.origin, .undertakingStage)
    }

    // MARK: - Expiry

    func testPressuresExpireOnTheirOwnAndLeaveNothingToClear() {
        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        XCTAssertEqual(WorldPressureEngine.active(pressures, now: days(3)).count, 1)
        XCTAssertTrue(WorldPressureEngine.active(pressures, now: days(30)).isEmpty)
    }

    func testAnExpiredPressureFreesItsSlot() {
        var pressures = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        pressures = WorldPressureEngine.minting(
            into: pressures, relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: days(30)
        )
        XCTAssertEqual(pressures.count, 1, "The old one expired; a fresh one may take its place")
        XCTAssertEqual(pressures.first?.beganAt, days(30))
    }

    // MARK: - Invariants

    func testAPressureNeverTargetsAPageOrDeskSlot() {
        // The enum itself is the guarantee: there is no page/desk/notification
        // surface to target. If one is ever added, this test must be revisited
        // deliberately rather than by accident.
        let surfaces = Set(WorldFingerprintSurface.allCases.map(\.rawValue))
        for forbidden in ["page", "desk", "deskSlot", "notification", "interruption", "whisper"] {
            XCTAssertFalse(surfaces.contains(forbidden), "A pressure may not claim \(forbidden)")
        }
    }

    func testARivalryLeavesSeveralMarksAcrossDifferentSurfaces() {
        let pressure = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        ).first

        guard let pressure else { return XCTFail("Expected a rivalry") }
        XCTAssertGreaterThanOrEqual(pressure.fingerprints.count, 5, "One transition, many small marks")
        let surfaces = Set(pressure.fingerprints.map(\.surface))
        XCTAssertGreaterThanOrEqual(surfaces.count, 5, "Marks should be spread, not stacked on one surface")
    }

    func testEveryDisputeInconveniencesSomebodyUninvolved() {
        // Collateral inconvenience is what makes a dispute feel like it happened
        // inside a society rather than in a vacuum between two people.
        for origin in [WorldPressureOrigin.rivalry, .alliance] {
            let prints = WorldPressureEngine.fingerprints(
                origin: origin,
                ids: ["penny-blackletter", "wicker-eddies"],
                names: ["Penny", "Wicker"]
            )
            XCTAssertTrue(prints.contains { $0.surface == .bystanderComplaint },
                          "\(origin.rawValue) needs a bystander")
        }
    }

    func testFingerprintIDsAreUnique() {
        let prints = WorldPressureEngine.fingerprints(
            origin: .rivalry, ids: ["a", "b"], names: ["A", "B"]
        )
        XCTAssertEqual(Set(prints.map(\.id)).count, prints.count)
    }

    // MARK: - Persistence

    func testPressureRoundTrips() throws {
        let pressures = WorldPressureEngine.minting(
            into: [], relationshipField: field(tension: 20),
            advancedUndertaking: nil, castName: name, now: start
        )
        let data = try JSONEncoder().encode(pressures)
        XCTAssertEqual(try JSONDecoder().decode([WorldPressure].self, from: data), pressures)
    }
}
