import XCTest
@testable import InsideCoverCore

final class CompassRunPlanPolicyTests: XCTestCase {
    private let response = """
    EXPERIENCE
    Follow the changing light across the kitchen table.
    NORTH (NOTICE)
    I wonder which shadows move while I sit at the kitchen table?
    EAST (EMBARK)
    Destination: The kitchen table beside the window.
    Delight: Sit on a comfortable cushion.
    Definition: Finish when one shadow has moved past a wood grain line.
    SOUTH (SENSE)
    Watch a shadow's edge travel across the wood grain.
    WEST (WRITE)
    Write about the smell of a distant beach.
    CENTER (REST)
    Stay seated for three quiet breaths.
    HINT
    The grain gives the shadow a finish line.
    """

    private func record(
        destination: String = "The kitchen table beside the window.",
        mission: String = "Watch a shadow's edge travel across the wood grain.",
        adventure: String = "",
        at date: Date = Date(timeIntervalSince1970: 1)
    ) -> CompassAdventureRecord {
        CompassAdventureRecord(plan: [
            "spark": "I wonder what is happening here?",
            "destination": destination, "mission": mission, "adventure": adventure
        ], createdAt: date)!
    }

    func testWestRemainsOpenToTheWholeExperienceDespiteUnrelatedModelPrompt() throws {
        let plan = try XCTUnwrap(CompassRunPlanPolicy.parse(response))
        XCTAssertEqual(plan["souvenirPrompt"], CompassRunPlanPolicy.souvenirPrompt)
        XCTAssertFalse(plan["souvenirPrompt"]!.contains("beach"))
        XCTAssertTrue(plan["souvenirPrompt"]!.contains("any part of the experience"))
        XCTAssertEqual(plan["destination"], "The kitchen table beside the window.")
    }

    func testIncompleteOrRepeatedSectionsRejectTheEntirePlan() {
        let missingFinish = response.replacingOccurrences(
            of: "Definition: Finish when one shadow has moved past a wood grain line.\n", with: ""
        )
        XCTAssertNil(CompassRunPlanPolicy.parse(missingFinish))
        XCTAssertNil(CompassRunPlanPolicy.parse(response.components(separatedBy: "CENTER (REST)")[0]))
        XCTAssertNil(CompassRunPlanPolicy.parse(response + "\nNORTH (NOTICE)\nAnother adventure."))
    }

    func testHeaderWordsWithinSentencesDoNotSplitSections() throws {
        let withHint = response.replacingOccurrences(
            of: "I wonder which shadows move", with: "I wonder what hint the shadows give as they move"
        )
        let plan = try XCTUnwrap(CompassRunPlanPolicy.parse(withHint))
        XCTAssertTrue(plan["spark"]!.contains("hint the shadows"))
    }

    func testSameActivityStaysRetiredRegardlessOfAgeOrNewDestination() {
        let old = record(at: Date(timeIntervalSince1970: 0))
        let candidate = record(destination: "The porch floor", at: Date(timeIntervalSince1970: 4_000_000_000))
        let history = CompassRunPlanPolicy.history([old], pages: [])
        XCTAssertEqual(CompassRunPlanPolicy.duplicate(of: candidate, in: history), old)
    }

    func testBookshelfSynonymsDoNotMakeANewAdventure() {
        let previous = record(destination: "bookshelf", mission: "Choose one book and feel the cover")
        let candidate = record(destination: "bookcase", mission: "Select a book and touch its cover")
        XCTAssertNotNil(CompassRunPlanPolicy.duplicate(of: candidate, in: [previous]))
    }

    func testDifferentAdventureInTheSamePlaceIsAllowed() {
        let candidate = record(mission: "Listen for the rhythm of rain against the glass.")
        XCTAssertNil(CompassRunPlanPolicy.duplicate(of: candidate, in: [record()]))
    }

    func testArchiveRecoveryAndVaultUnionKeepOldUnkeptOffers() {
        let unkept = record(destination: "porch", mission: "Listen for the nearest bird.")
        let kept = BookPage(
            type: .wonderCompass, promptText: "Compass Run", metadata: [
                "compassRunPrepared": "true", "spark": "I wonder which shadows move?",
                "destination": record().destination, "mission": record().mission
            ]
        )
        let memoryOnly = BookPage(type: .wonderCompass, promptText: "West", userInput: "The rough wood warmed my palm.")
        let history = CompassRunPlanPolicy.history([unkept], pages: [kept, kept, memoryOnly])
        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.contains(unkept))
        XCTAssertNotNil(CompassRunPlanPolicy.duplicate(of: record(), in: history))
    }

    func testPreparedTextFromBeforeMetadataArchivingCanSeedHistory() throws {
        let start = try XCTUnwrap(response.range(of: "NORTH (NOTICE)"))
        let finish = try XCTUnwrap(response.range(of: "HINT"))
        let printed = "Wonder Compass Run\nLocation: home\n" + String(response[start.lowerBound..<finish.lowerBound])
        let page = BookPage(type: .wonderCompass, promptText: "Run", userInput: printed, tags: ["wonder-compass-run"])
        let history = CompassRunPlanPolicy.history([], pages: [page])
        XCTAssertEqual(history.count, 1)
        XCTAssertNotNil(CompassRunPlanPolicy.duplicate(of: record(), in: history))
    }

    func testBoundedModelExamplesRetrieveRelatedOldAdventureWithoutTrimmingHistory() {
        let recent = (1...30).map {
            record(destination: "garden \($0)", mission: "Find a different flower \($0)", at: Date(timeIntervalSince1970: Double($0 + 100)))
        }
        let old = record()
        let history = CompassRunPlanPolicy.history(recent + [old], pages: [])
        let examples = CompassRunPlanPolicy.examples(from: history, relatedTo: old.summary, limit: 8)
        XCTAssertEqual(examples.count, 8)
        XCTAssertTrue(examples.contains(old))
        XCTAssertEqual(history.count, 31)
        XCTAssertTrue(CompassRunPlanPolicy.examples(from: history, relatedTo: old.summary, limit: 0).isEmpty)
    }

    func testVaultHistoryRoundTripsAndOlderVaultsDecodeWithoutIt() throws {
        var vault = PlayerVaultData()
        vault.compassAdventures = [record()]
        let encoded = try JSONEncoder().encode(vault)
        XCTAssertEqual(try JSONDecoder().decode(PlayerVaultData.self, from: encoded).compassAdventures, vault.compassAdventures)
        var older = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        older.removeValue(forKey: "compassAdventures")
        let olderBytes = try JSONSerialization.data(withJSONObject: older)
        XCTAssertNil(try JSONDecoder().decode(PlayerVaultData.self, from: olderBytes).compassAdventures)
    }
}
