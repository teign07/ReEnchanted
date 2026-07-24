import XCTest
@testable import InsideCoverCore

final class IlluminationPaperVariationTests: XCTestCase {
    func testComposerVariesPaperWithinOneIlluminatedPage() {
        let draft = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 4_271
        )

        let paperNames = draft.compositionPlan.textSlots.map(\.paperAssetName)

        XCTAssertGreaterThanOrEqual(Set(paperNames).count, 6)
        XCTAssertTrue(paperNames.contains { $0.hasPrefix("IlluminationPaper") })
    }

    func testPaperSelectionIsStableForACompositionSeed() {
        let first = IlluminatedPageComposer.compose(
            analysis: .goodCompanyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 9_102
        )
        let second = IlluminatedPageComposer.compose(
            analysis: .goodCompanyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 9_102
        )

        XCTAssertEqual(
            first.compositionPlan.textSlots.map(\.paperAssetName),
            second.compositionPlan.textSlots.map(\.paperAssetName)
        )
    }

    func testDifferentSeedsShufflePaperAssignments() {
        let first = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 101
        )
        let second = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 9_901
        )

        XCTAssertNotEqual(
            first.compositionPlan.textSlots.map(\.paperAssetName),
            second.compositionPlan.textSlots.map(\.paperAssetName)
        )
    }

    func testDifferentSeedsChooseAndPlaceDifferentMarginalia() {
        let first = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 101
        )
        let second = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 9_901
        )

        let firstMarginalia = first.compositionPlan.textSlots
            .filter { $0.slotId.hasPrefix("marginalia-") }
        let secondMarginalia = second.compositionPlan.textSlots
            .filter { $0.slotId.hasPrefix("marginalia-") }

        XCTAssertNotEqual(firstMarginalia.map(\.body), secondMarginalia.map(\.body))
        XCTAssertNotEqual(firstMarginalia.map(\.position), secondMarginalia.map(\.position))
    }
}
