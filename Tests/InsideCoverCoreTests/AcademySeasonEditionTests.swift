import XCTest
@testable import InsideCoverCore

/// The Academy had a season too. Literary matter, not a status report.
final class AcademySeasonEditionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private var end: Date { start.addingTimeInterval(30 * 86_400) }

    private func movement(_ index: Int, witnessed: Bool) -> CastAgencyMovement {
        CastAgencyMovement(
            slotID: "slot-\(index)",
            kind: .relationship,
            actorID: "penny-blackletter",
            actorName: "Penny Blackletter",
            targetID: "wicker-eddies",
            targetName: "Wicker Eddies",
            amount: 1,
            line: "Penny Blackletter chipped 1 Belief from Wicker Eddies.",
            createdAt: start.addingTimeInterval(Double(index) * 86_400),
            witnessed: witnessed
        )
    }

    private func fullSeason() -> AcademySeasonEdition.Inputs {
        var undertakings = CastUndertakingEngine.seeded(existing: [], now: start)
        undertakings[0].status = .concluded
        undertakings[1].status = .stalled

        var pressure = WorldPressureEngine.minting(
            into: [],
            relationshipField: ["penny-blackletter|wicker-eddies": {
                var tie = RelationshipTie(); tie.add(tension: 20); return tie
            }()],
            advancedUndertaking: nil,
            castName: { $0 },
            now: start
        )
        pressure = WorldPressureEngine.active(pressure, now: start)

        var places: [String: PlaceState] = [:]
        for index in 0..<PlaceState.reputationThreshold {
            places = PlaceMemoryEngine.recording(
                places,
                incident: PlaceIncident(
                    id: "i-\(index)", line: "An argument.",
                    participantIDs: ["penny-blackletter"], tags: ["argument"],
                    occurredAt: start
                ),
                placeID: "location-great-hall"
            )
        }

        return AcademySeasonEdition.Inputs(
            movements: (0..<6).map { movement($0, witnessed: $0 < 2) },
            undertakings: undertakings,
            pressures: pressure,
            placeStates: places,
            castName: ["penny-blackletter": "Penny Blackletter", "wicker-eddies": "Wicker Eddies"]
        )
    }

    // MARK: - Building

    func testASeasonBuildsFromTheLedger() {
        let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end)
        XCTAssertNotNil(section)
        XCTAssertEqual(section?.id, AcademySeasonEdition.sectionID)
        XCTAssertFalse(section?.items.isEmpty ?? true)
    }

    func testAQuietSeasonProducesNoSectionRatherThanAnEmptyOne() {
        let section = AcademySeasonEdition.section(
            for: AcademySeasonEdition.Inputs(), start: start, end: end
        )
        XCTAssertNil(section, "An empty season should be absent, not blank")
    }

    func testUnwitnessedWorkAppearsInTheEdition() {
        let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end)
        let item = section?.items.first { $0.id.contains("unwitnessed") }
        XCTAssertNotNil(item, "Projects that continued without witnesses are the point")
        XCTAssertTrue(item?.tags.contains("unwitnessed") ?? false)
    }

    func testUnresolvedBusinessAppearsAndIsNotPresentedAsFinished() {
        let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end)
        let item = section?.items.first { $0.id.contains("unresolved") }
        XCTAssertNotNil(item)
        XCTAssertTrue(item?.body.contains("still") ?? false)
    }

    func testMovementsOutsideTheWindowAreExcluded() {
        var inputs = fullSeason()
        inputs.movements = [movement(400, witnessed: false)]
        let section = AcademySeasonEdition.section(for: inputs, start: start, end: end)
        let unwitnessed = section?.items.first { $0.id.contains("unwitnessed") }
        XCTAssertNil(unwitnessed, "A movement from outside the season is not this season's news")
    }

    // MARK: - The admitted mystery

    func testTheUnexplainedEntryIsAlwaysPresentAndAlwaysLast() {
        let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end)
        XCTAssertEqual(section?.items.last?.id, "\(AcademySeasonEdition.sectionID)-unexplained")
        XCTAssertFalse(section?.items.last?.body.isEmpty ?? true)
    }

    func testTheUnexplainedEntryIsDeterministic() {
        let inputs = fullSeason()
        let a = AcademySeasonEdition.section(for: inputs, start: start, end: end)?.items.last?.body
        let b = AcademySeasonEdition.section(for: inputs, start: start, end: end)?.items.last?.body
        XCTAssertEqual(a, b)
    }

    func testTheUnexplainedEntryNeverExplainsItself() {
        // An edition that explains everything is a report. This entry must stay
        // a thing that does not add up, not foreshadowing, not a teaser.
        let forbidden = ["because", "which means", "this suggests", "will be revealed",
                         "next month", "stay tuned", "the answer", "turns out"]
        for index in 0..<40 {
            var inputs = fullSeason()
            inputs.movements = [movement(index, witnessed: false)]
            let body = AcademySeasonEdition.unexplained(
                movements: inputs.movements, inputs: inputs, name: { $0 }
            ).lowercased()
            for phrase in forbidden {
                XCTAssertFalse(body.contains(phrase), "The mystery explained itself: '\(phrase)'")
            }
        }
    }

    // MARK: - Invariants

    func testTheSectionNeverReadsAsAStatusReport() {
        guard let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end) else {
            return XCTFail("Expected a season")
        }
        let text = ([section.title, section.note] + section.items.flatMap { [$0.title, $0.body] })
            .joined(separator: " ").lowercased()
        for metric in ["total:", "count:", "progress", "completion", "score", "%", "streak", "you missed"] {
            XCTAssertFalse(text.contains(metric), "Edition matter must not read as metrics: '\(metric)'")
        }
    }

    func testTheSectionContainsNoReaderEvidence() {
        // The Academy's season is the world's history, never a claim about the
        // reader's life.
        guard let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end) else {
            return XCTFail("Expected a season")
        }
        for item in section.items {
            XCTAssertEqual(item.kind, .continuity)
            XCTAssertNil(item.pageType, "A season item is not a reader page")
            XCTAssertTrue(item.mediaAssets.isEmpty)
        }
    }

    func testSectionRoundTrips() throws {
        guard let section = AcademySeasonEdition.section(for: fullSeason(), start: start, end: end) else {
            return XCTFail("Expected a season")
        }
        let data = try JSONEncoder().encode(section)
        XCTAssertEqual(try JSONDecoder().decode(MonthlyEditionSection.self, from: data), section)
    }
}
