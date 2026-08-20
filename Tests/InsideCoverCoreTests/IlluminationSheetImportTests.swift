import XCTest
@testable import InsideCoverCore

/// Two hand-painted sheets cut into individual marks. They enter the one shared
/// cabinet, so Pages Rising, Pagewright, and illuminated photos all see them —
/// there is deliberately no surface-specific decoration registry.
final class IlluminationSheetImportTests: XCTestCase {
    private var imported: [IlluminationAsset] {
        IlluminationPackRegistry.installedPacks
            .flatMap(\.allAssets)
            .filter { $0.assetName.hasPrefix("IlluminationStain") || $0.assetName.hasPrefix("IlluminationFlourish") }
    }

    func testBothSheetsReachedTheSharedCabinet() {
        let stains = imported.filter { $0.assetName.hasPrefix("IlluminationStain") }
        let flourishes = imported.filter { $0.assetName.hasPrefix("IlluminationFlourish") }
        XCTAssertEqual(stains.count, 43)
        XCTAssertEqual(flourishes.count, 49)
    }

    func testEveryImportedMarkStatesItsOwnArtDirection() {
        for asset in imported {
            guard let traits = asset.leafTraits else {
                return XCTFail("\(asset.assetName) carries no art direction.")
            }
            XCTAssertNotNil(traits.semanticRole, "\(asset.assetName) does not say what it is.")
            XCTAssertFalse(traits.preferredAnchors?.isEmpty ?? true, "\(asset.assetName) has no opinion about where it sits.")
            XCTAssertNotNil(traits.aspectRatio, "\(asset.assetName) needs its real proportions to be sized.")
        }
    }

    /// The rule that protects legibility: a mark may only lie under prose if it
    /// is pale enough to read through, and then only as a watermark.
    func testOnlyPaleStainsMayLieUnderProse() {
        for asset in imported {
            let traits = asset.leafTraits
            guard traits?.allowsTextOverlap == true else { continue }
            XCTAssertTrue(
                asset.assetName.hasPrefix("IlluminationStain"),
                "\(asset.assetName): only a stain should ever sit under text."
            )
            XCTAssertEqual(traits?.semanticRole, .texture)
            XCTAssertEqual(traits?.preferredAnchors, [.watermark])
        }

        // Line art is opaque and must never run beneath reading matter.
        for asset in imported where asset.assetName.hasPrefix("IlluminationFlourish") {
            XCTAssertNotEqual(asset.leafTraits?.allowsTextOverlap, true, "\(asset.assetName)")
        }
    }

    func testMarksAreUniquelyIdentifiedAndNamed() {
        let ids = imported.map(\.id)
        let names = imported.map(\.assetName)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate asset ids would make selection ambiguous.")
        XCTAssertEqual(Set(names).count, names.count)
    }
}

extension IlluminationSheetImportTests {
    /// Registering a mark is not the same as it ever being chosen. The recipe
    /// picks from the cabinet by kind and motif, so run it across many leaves
    /// and confirm the imported sheets actually reach the page.
    func testImportedMarksAreActuallySelectable() {
        var seenStain = 0
        var seenFlourish = 0
        var drew = 0

        for i in 0..<400 {
            let recipe = LeafDecorationLibrary.recipe(
                pageType: i.isMultiple(of: 2) ? BookPageType.diary : BookPageType.letter,
                metadata: [:],
                documentID: "import-probe-\(i)",
                leafIndex: i % 3
            )
            let names: [String] = [recipe.primaryAsset, recipe.secondaryAsset, recipe.supportAsset, recipe.fasteningAsset, recipe.textureOverlay]
                    .compactMap { $0?.assetName }
            if !names.isEmpty { drew += 1 }
            if names.contains(where: { $0.hasPrefix("IlluminationStain") }) { seenStain += 1 }
            if names.contains(where: { $0.hasPrefix("IlluminationFlourish") }) { seenFlourish += 1 }
        }

        XCTAssertGreaterThan(drew, 0, "Precondition: the recipe draws marks at all.")
        XCTAssertGreaterThan(seenStain, 0, "No imported stain was ever selected across 400 leaves.")
        XCTAssertGreaterThan(seenFlourish, 0, "No imported flourish was ever selected across 400 leaves.")
    }
}
