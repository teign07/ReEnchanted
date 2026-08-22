import XCTest
@testable import InsideCoverCore

final class SavedPageRibbonTests: XCTestCase {
    func testRibbonKeepsAnExactPageSnapshotAndReadingOffset() throws {
        let page = SurfacePage(
            id: "letter-from-pippa",
            type: .letter,
            prompt: "A letter with a bent corner",
            detail: "Pippa wrote this one in violet ink."
        )
        let ribbon = SavedPageRibbon(
            surface: page,
            documentID: "pages-rising::letter-from-pippa",
            textOffset: 84,
            title: "A letter with a bent corner",
            savedAt: Date(timeIntervalSince1970: 1_760_000_000)
        )

        XCTAssertTrue(ribbon.marks(
            documentID: "pages-rising::letter-from-pippa",
            textRange: 60...110
        ))
        XCTAssertFalse(ribbon.marks(
            documentID: "pages-rising::letter-from-pippa",
            textRange: 0...59
        ))
        XCTAssertEqual(ribbon.surfaceForFolio.id, page.id)
        XCTAssertEqual(
            ribbon.surfaceForFolio.payload.metadata["pagesRisingFolioDocumentID"],
            ribbon.documentID
        )
        XCTAssertEqual(ribbon.surfaceForFolio.payload.metadata["savedPageRibbon"], "true")
    }

    func testVaultRoundTripPreservesRibbonForAnyPageType() throws {
        let mission = SurfacePage(
            id: "mission-pocket-museum",
            type: .wonderCompass,
            prompt: "Build a pocket museum",
            detail: "Find three tiny exhibits."
        ).withMetadata(["playfulMissionID": "pocket-museum"])
        var vault = PlayerVaultData()
        vault.savedPageRibbon = SavedPageRibbon(
            surface: mission,
            documentID: mission.id,
            textOffset: 0,
            title: mission.prompt,
            savedAt: Date(timeIntervalSince1970: 1_760_000_100)
        )

        let decoded = try JSONDecoder().decode(
            PlayerVaultData.self,
            from: JSONEncoder().encode(vault)
        )

        XCTAssertEqual(decoded.savedPageRibbon, vault.savedPageRibbon)
        XCTAssertEqual(
            decoded.savedPageRibbon?.surface.payload.metadata["playfulMissionID"],
            "pocket-museum"
        )
    }
}
