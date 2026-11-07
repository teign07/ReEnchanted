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

    // MARK: - Three strands (docs/the-knock-plan.md §4)

    private func ribbon(_ id: String, kept: String? = nil) -> SavedPageRibbon {
        var page = SurfacePage(id: id, type: .letter, prompt: "Page \(id)", detail: "")
        if let kept { page = page.withMetadata(["keptPageID": kept]) }
        return SavedPageRibbon(surface: page, documentID: "doc-\(id)", textOffset: 0, title: "Page \(id)",
                               savedAt: Date(timeIntervalSince1970: 1_760_000_000))
    }

    func testThreeStrandsFillInOrderAndAFourthWaitsForAChoice() throws {
        var ribbons: [SavedPageRibbon] = []
        for id in ["a", "b", "c"] {
            ribbons = try XCTUnwrap(BookRibbons.tucking(ribbon(id), into: ribbons))
        }
        XCTAssertEqual(ribbons.map(\.strand), [0, 1, 2])
        XCTAssertNil(BookRibbons.tucking(ribbon("d"), into: ribbons), "all three hold something; the reader chooses")

        let moved = try XCTUnwrap(BookRibbons.tucking(ribbon("d"), into: ribbons, movingStrand: 1))
        XCTAssertEqual(BookRibbons.ordered(moved).map(\.documentID), ["doc-a", "doc-d", "doc-c"])
        XCTAssertEqual(moved.first { $0.documentID == "doc-d" }?.strand, 1)
    }

    func testRetuckingAPageKeepsItsStrand() throws {
        let ribbons = try XCTUnwrap(BookRibbons.tucking(ribbon("a"), into: [ribbon("b")].map { var r = $0; r.strand = 2; return r }))
        var again = ribbon("b")
        again.textOffset = 40
        let retucked = try XCTUnwrap(BookRibbons.tucking(again, into: ribbons))
        XCTAssertEqual(retucked.count, 2)
        XCTAssertEqual(retucked.first { $0.documentID == "doc-b" }?.strand, 2)
        XCTAssertEqual(retucked.first { $0.documentID == "doc-b" }?.textOffset, 40)
    }

    func testLiftingFreesAStrandForTheNextPage() throws {
        var ribbons: [SavedPageRibbon] = []
        for id in ["a", "b", "c"] { ribbons = try XCTUnwrap(BookRibbons.tucking(ribbon(id), into: ribbons)) }
        ribbons = BookRibbons.lifting(documentID: "doc-b", from: ribbons)
        let next = try XCTUnwrap(BookRibbons.tucking(ribbon("d"), into: ribbons))
        XCTAssertEqual(next.first { $0.documentID == "doc-d" }?.strand, 1, "the free strand is the one let go")
    }

    /// A Book from before the three strands keeps its one ribbon, on the first.
    func testTheOldSingleRibbonBecomesTheFirstStrand() throws {
        var vault = PlayerVaultData()
        vault.savedPageRibbon = ribbon("old")
        XCTAssertEqual(vault.ribbons.map(\.documentID), ["doc-old"])
        vault.ribbons = try XCTUnwrap(BookRibbons.tucking(ribbon("new"), into: vault.ribbons))
        XCTAssertNil(vault.savedPageRibbon)
        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(vault))
        XCTAssertEqual(decoded.ribbons.map(\.documentID), ["doc-old", "doc-new"])
    }

    func testARibbonGuardsTheKeptPageBehindAVisitingLeaf() {
        XCTAssertEqual(ribbon("visit", kept: "archive-42").protectedPageID, "archive-42")
        XCTAssertEqual(ribbon("plain").protectedPageID, "plain")
    }
}
