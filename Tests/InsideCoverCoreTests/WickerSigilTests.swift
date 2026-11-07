import XCTest
@testable import InsideCoverCore

final class WickerSigilTests: XCTestCase {
    private var sigils: [IlluminationAsset] {
        CoreMarginsPack.pack.doodles.filter { $0.tags.contains("wicker-sigil") }
    }

    func testTheWholeSetIsReachableInTheCabinetAndPrintDeck() {
        XCTAssertEqual(sigils.count, 14)
        let expected = Set(sigils.map(\.assetName))
        XCTAssertEqual(expected.count, sigils.count)
        let cabinet = IlluminationPackRegistry.marks(on: .wickerSigils)
        XCTAssertEqual(Set(cabinet.map { $0.asset.assetName }), expected)
        XCTAssertTrue(expected.isSubset(of: Set(MarginaliaDeck.regular)))
        XCTAssertTrue(MarkShelf.permanentShelves.contains(.wickerSigils))
    }

    func testTheMarksStayFreeToPlaceAcrossTemplatesAndDoNotCoverText() {
        for mark in sigils {
            XCTAssertNil(mark.placementTrigger)
            XCTAssertFalse(mark.directedOnly)
            XCTAssertEqual(Set(mark.supportedTemplates), Set(IlluminatedTemplateID.allCases))
            XCTAssertEqual(mark.leafTraits?.semanticRole, .sigil)
            XCTAssertEqual(mark.leafTraits?.allowsTextOverlap, false)
            XCTAssertEqual(mark.markShelf, .wickerSigils)
        }
    }

    func testWickerAndTheCurseAreUnderstoodByAutomaticMarginalia() {
        let named = LeafDecorationLibrary.semanticMotifs(in: "Wicker drew chaos sigils beside the rule.")
        XCTAssertTrue(named.contains("wicker-eddies"))
        XCTAssertTrue(named.contains("chaos-sigil"))
        let curse = LeafDecorationLibrary.semanticMotifs(in: "The Curse's grey makes the day easy to miss.")
        XCTAssertTrue(curse.contains("curse"))
        XCTAssertTrue(curse.contains("grey"))
        let dare = LeafDecorationLibrary.resolvedMotifs(
            pageType: .wickerDare, metadata: [:], semanticText: "Try the handle."
        )
        XCTAssertTrue(dare.contains("wicker-eddies"))
    }

    func testOrdinaryLeavesAndMarginaliaInterleavesCanBothUseTheSigils() {
        let expected = Set(sigils.map(\.assetName))
        for interleaf in [false, true] {
            var seen = Set<String>()
            for index in 0..<80 {
                let recipe = LeafDecorationLibrary.recipe(
                    pageType: .wickerDare,
                    metadata: ["marginaliaTags": "wicker-sigil,chaos-sigil,wicker-eddies"],
                    semanticText: "Wicker's pen tested the rule.",
                    documentID: "wicker-reading-\(index)",
                    leafIndex: 0,
                    decorationPlate: interleaf,
                    densityOverride: .rich
                )
                let marks = [recipe.primaryAsset, recipe.secondaryAsset, recipe.supportAsset]
                    .compactMap { $0 } + recipe.companionAssets
                seen.formUnion(marks.map(\.assetName))
            }
            XCTAssertFalse(expected.intersection(seen).isEmpty, "No sigils reached interleaf=\(interleaf)")
        }
    }

    func testIlluminatedPhotoPlansCanRetainAndExportTheSameSigils() throws {
        let expected = Set(sigils.map(\.assetName))
        var used = Set<String>()
        for seed in 0..<24 {
            var analysis = PhotoAnalysis.academyFallback
            analysis.motifs = ["wicker-sigil", "chaos-sigil", "wicker-eddies"]
            let draft = IlluminatedPageComposer.compose(
                analysis: analysis, sourceAssetName: "test-photo", seed: seed
            )
            let restored = try JSONDecoder().decode(
                IlluminatedCompositionPlan.self,
                from: JSONEncoder().encode(draft.compositionPlan)
            )
            XCTAssertEqual(restored, draft.compositionPlan)
            used.formUnion(restored.decorations.map(\.assetName))
        }
        XCTAssertFalse(expected.intersection(used).isEmpty)
    }
}
