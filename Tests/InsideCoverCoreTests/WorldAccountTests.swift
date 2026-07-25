import XCTest
@testable import InsideCoverCore

/// One event, several tellings, no adjudication. The ledger stays consistent;
/// what reaches the reader is testimony.
final class WorldAccountTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    private func movement(_ suffix: String = "a") -> CastAgencyMovement {
        CastAgencyMovement(
            slotID: "2026-07-20-s0\(suffix)",
            kind: .relationship,
            actorID: "wicker-eddies",
            actorName: "Wicker Eddies",
            targetID: "penny-blackletter",
            targetName: "Penny Blackletter",
            amount: 2,
            line: "Wicker Eddies chipped 2 Belief from Penny Blackletter.",
            createdAt: start
        )
    }

    // MARK: - Shape

    func testOneEventProducesSeveralButNotManyAccounts() {
        for index in 0..<40 {
            let accounts = WorldAccountEngine.accounts(for: movement("\(index)"))
            XCTAssertGreaterThanOrEqual(accounts.count, WorldAccountEngine.minimumAccounts)
            XCTAssertLessThanOrEqual(accounts.count, WorldAccountEngine.maximumAccounts,
                                     "Five simultaneous tellings is a dossier, not a rumour")
        }
    }

    func testAccountsAreDeterministicForTheSameMovement() {
        XCTAssertEqual(WorldAccountEngine.accounts(for: movement()), WorldAccountEngine.accounts(for: movement()))
    }

    func testAccountKindsAreDistinctWithinOneEvent() {
        for index in 0..<40 {
            let accounts = WorldAccountEngine.accounts(for: movement("\(index)"))
            XCTAssertEqual(Set(accounts.map(\.kind)).count, accounts.count)
        }
    }

    func testEveryAccountPointsBackAtTheSameSingleMovement() {
        let subject = movement()
        for account in WorldAccountEngine.accounts(for: subject) {
            XCTAssertEqual(account.movementID, subject.id)
            XCTAssertFalse(account.line.isEmpty)
        }
    }

    func testAllAccountKindsAreReachable() {
        var seen = Set<WorldAccountKind>()
        for index in 0..<200 {
            for account in WorldAccountEngine.accounts(for: movement("\(index)")) {
                seen.insert(account.kind)
            }
        }
        XCTAssertEqual(seen, Set(WorldAccountKind.allCases))
    }

    // MARK: - Contradiction

    func testAccountsSometimesDisagree() {
        let disagreeing = (0..<200).filter { index in
            WorldAccountEngine.accounts(for: movement("\(index)")).contains(where: \.contradictsSibling)
        }.count
        XCTAssertGreaterThan(disagreeing, 0, "Testimony that never conflicts is a database")
        XCTAssertLessThan(disagreeing, 200, "Testimony that always conflicts is noise")
    }

    func testTheFirstTellingIsNeverTheOneThatDrifts() {
        for index in 0..<60 {
            let accounts = WorldAccountEngine.accounts(for: movement("\(index)"))
            XCTAssertFalse(accounts.first?.contradictsSibling ?? true,
                           "The first account a thing gets is the confident one")
        }
    }

    func testTheBookRefusesToSettleAContradiction() {
        var sawResolution = false
        for index in 0..<200 {
            let accounts = WorldAccountEngine.accounts(for: movement("\(index)"))
            guard let resolution = WorldAccountEngine.resolution(for: accounts) else { continue }
            sawResolution = true
            let text = resolution.lowercased()
            for verdict in ["the truth is", "in fact", "actually happened", "was correct",
                            "was wrong", "we now know", "resolved", "confirmed"] {
                XCTAssertFalse(text.contains(verdict), "The Book must not adjudicate: found '\(verdict)'")
            }
        }
        XCTAssertTrue(sawResolution)
    }

    func testAgreeingAccountsNeedNoResolution() {
        let agreeing = (0..<200).lazy
            .map { WorldAccountEngine.accounts(for: self.movement("\($0)")) }
            .first { !$0.contains(where: \.contradictsSibling) }
        guard let agreeing else { return XCTFail("Expected some event where the tellings agree") }
        XCTAssertNil(WorldAccountEngine.resolution(for: agreeing))
    }

    // MARK: - Safety

    func testAccountsNeverInventAnEventThatDidNotHappen() {
        // Every account must be about the actual participants of the actual
        // movement. Testimony may be unreliable about order and blame; it may
        // not conjure a different cast.
        let subject = movement()
        for account in WorldAccountEngine.accounts(for: subject) {
            let mentionsSomeone = account.line.contains(subject.actorName)
                || account.line.contains(subject.targetName)
                || account.kind == .trace
            XCTAssertTrue(mentionsSomeone, "\(account.kind) drifted off the actual event")
        }
    }

    func testAccountsCarryNoBeliefOrRelationshipEffect() {
        // Accounts are views. The cost was already paid on the world clock.
        let mirror = Mirror(reflecting: WorldAccount(
            id: "a", movementID: "m", kind: .filed, line: "x", contradictsSibling: false
        ))
        let fields = Set(mirror.children.compactMap(\.label))
        for forbidden in ["amount", "warmth", "tension", "belief", "delta"] {
            XCTAssertFalse(fields.contains(forbidden), "An account must not carry an effect")
        }
    }

    // MARK: - On the surface

    func testABelatedPageArrivesAsTestimony() {
        var inputs = BookSourceInputs.empty
        var state = CastAgencyState()
        let slots = (0..<6).map { "2026-07-20-s0\($0)" }
        for (index, slot) in slots.enumerated() {
            state.remember(
                CastAgencyMovement(
                    slotID: slot, kind: .relationship,
                    actorID: "actor-\(index)", actorName: "Actor \(index)",
                    targetID: "target-\(index)", targetName: "Target \(index)",
                    amount: 1, line: "Actor \(index) did something.",
                    createdAt: start.addingTimeInterval(Double(index) * 3600)
                ),
                keepingRecentSlots: Set(slots)
            )
        }
        inputs.castAgency = state
        let day = BookDay(id: "2026-07-21", date: start, pages: [])

        var sawBelated = false
        for hour in stride(from: 24, to: 24 * 40, by: 4) {
            let probe = start.addingTimeInterval(Double(hour) * 3600)
            let surface = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: probe)
            guard surface.payload.metadata["belated"] == "true" else { continue }
            sawBelated = true
            let kinds = surface.payload.metadata["accountKinds"]?.split(separator: ",") ?? []
            XCTAssertGreaterThanOrEqual(kinds.count, WorldAccountEngine.minimumAccounts)
            XCTAssertNotNil(surface.payload.metadata["accountsDisagree"])
            break
        }
        XCTAssertTrue(sawBelated)
    }

    func testAccountRoundTrips() throws {
        let accounts = WorldAccountEngine.accounts(for: movement())
        let data = try JSONEncoder().encode(accounts)
        XCTAssertEqual(try JSONDecoder().decode([WorldAccount].self, from: data), accounts)
    }
}
