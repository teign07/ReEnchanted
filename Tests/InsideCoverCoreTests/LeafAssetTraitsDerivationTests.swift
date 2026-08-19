import XCTest
@testable import InsideCoverCore

/// The folio reads `leafTraits` in six places, and every one of them was
/// reading nil: the cabinet declared the contract and no asset filled it, so all
/// 79 marks rendered at the same saturation, the same blend, and landed wherever
/// the collision checker happened to allow.
final class LeafAssetTraitsDerivationTests: XCTestCase {
    func testEveryMarkInTheCabinetNowCarriesArtDirection() {
        let assets = IlluminationPackRegistry.installedPacks.flatMap(\.allAssets)
        XCTAssertGreaterThan(assets.count, 50, "Precondition: the cabinet is populated.")

        for asset in assets {
            XCTAssertNotNil(
                asset.leafTraits?.semanticRole,
                "\(asset.id) still has nothing to say about what it is."
            )
            XCTAssertFalse(
                asset.leafTraits?.preferredAnchors?.isEmpty ?? true,
                "\(asset.id) has no opinion about where it belongs."
            )
        }
    }

    /// Subject beats medium: a botanical stamp is a botanical before it is a seal.
    func testSubjectTagsWinOverKind() {
        XCTAssertEqual(
            LeafAssetTraits.derived(kind: .stamp, tags: ["botanical", "home"]).semanticRole,
            .botanical
        )
        XCTAssertEqual(
            LeafAssetTraits.derived(kind: .paperScrap, tags: ["torn", "blank", "map"]).semanticRole,
            .map
        )
        XCTAssertEqual(
            LeafAssetTraits.derived(kind: .stamp, tags: ["bee", "wonder", "round"]).semanticRole,
            .sigil
        )
    }

    /// The rule that protects prose: only a watermark may sit under text.
    func testOnlyTextureMayRunUnderProse() {
        for kind in [IlluminationAssetKind.background, .overlay] {
            let traits = LeafAssetTraits.derived(kind: kind, tags: [])
            XCTAssertEqual(traits.semanticRole, .texture)
            XCTAssertEqual(traits.allowsTextOverlap, true)
            XCTAssertEqual(traits.preferredAnchors, [.watermark])
        }

        for kind in [IlluminationAssetKind.doodle, .stamp, .tape, .paperScrap] {
            let traits = LeafAssetTraits.derived(kind: kind, tags: [])
            XCTAssertNotEqual(traits.allowsTextOverlap, true, "\(kind) is an object on the page, not a wash under it.")
            XCTAssertFalse(traits.preferredAnchors?.contains(.watermark) ?? false)
        }
    }

    /// Tape belongs on corners, because that is what tape is for.
    func testMarksPreferWhereTheirRealCounterpartWouldLand() {
        XCTAssertEqual(
            LeafAssetTraits.derived(kind: .tape, tags: ["tape"]).semanticRole,
            .fastener
        )
        XCTAssertTrue(
            LeafAssetTraits.derived(kind: .tape, tags: ["tape"])
                .preferredAnchors?.contains(.upperTrailing) ?? false
        )
        // A pencilled aside lives in the outer margin beside the text.
        XCTAssertTrue(
            LeafAssetTraits.derived(kind: .doodle, tags: ["marginalia"])
                .preferredAnchors?.contains(.middleTrailing) ?? false
        )
    }

    /// A marginal note must stay smaller than a laid-on scrap, or the aside
    /// starts reading as an illustration.
    func testAnAsideStaysSmallerThanAnObject() {
        let scribble = LeafAssetTraits.derived(kind: .doodle, tags: ["marginalia"]).visualWeight ?? 1
        let scrap = LeafAssetTraits.derived(kind: .paperScrap, tags: ["scrap"]).visualWeight ?? 1
        let wash = LeafAssetTraits.derived(kind: .background, tags: []).visualWeight ?? 1
        XCTAssertLessThan(scribble, scrap)
        XCTAssertLessThan(scrap, wash)
    }

    /// Narrowing dialects on guesswork would starve leaves of decoration long
    /// before it improved one. nil means "any" to the filter, and that is intent.
    func testDerivedTraitsDoNotRestrictDialects() {
        XCTAssertNil(LeafAssetTraits.derived(kind: .doodle, tags: ["marginalia"]).supportedDialects)
    }
}
