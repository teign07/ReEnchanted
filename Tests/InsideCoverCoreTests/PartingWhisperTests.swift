import XCTest
@testable import InsideCoverCore

final class PartingWhisperTests: XCTestCase {
    private struct LegacyPocketKeepsake: Codable {
        let id: String
        let dayID: String
        let pageType: BookPageType
        let object: String
        let glyph: String
        let foundAt: Date
    }

    private func surface(_ type: BookPageType, id: String = UUID().uuidString) -> SurfacePage {
        SurfacePage(id: id, type: type, prompt: "prompt", detail: "detail")
    }

    func testDismissalClosingIsDeterministicForTheSamePage() {
        let leaving = surface(.diary, id: "same-page")
        XCTAssertEqual(
            PartingWhisper.closingLine(for: leaving),
            PartingWhisper.closingLine(for: leaving)
        )
    }

    func testDismissalClosingsVaryAcrossPagesWithoutRandomReward() {
        let lines = Set((0..<40).compactMap {
            PartingWhisper.closingLine(for: surface(.diary, id: "page-\($0)"))
        })
        XCTAssertGreaterThan(lines.count, 1)
    }

    func testDismissalClosingFillsThePagePlaceholder() throws {
        // Only one of the eight wink lines carries `{page}`, and which line a
        // Page gets is a hash of its id — so the old version of this test, which
        // let the id default to a fresh UUID, asserted on a one-in-eight roll
        // and failed most runs. Search the ids for the line under test instead
        // of gambling on one.
        let filled = try XCTUnwrap(
            (0..<64).lazy.compactMap { index -> String? in
                let line = PartingWhisper.closingLine(for: self.surface(.souvenir, id: "souvenir-\(index)"))
                return line?.contains("souvenir") == true ? line : nil
            }.first,
            "no id reached the wink line that carries {page}"
        )
        XCTAssertFalse(filled.contains("{page}"), "the placeholder was left unfilled")

        // And whichever line a Page lands on, the raw token never ships.
        for index in 0..<64 {
            let line = PartingWhisper.closingLine(for: surface(.souvenir, id: "leak-\(index)"))
            XCTAssertFalse(line?.contains("{page}") ?? false, "id leak-\(index) leaked the token")
        }
    }

    func testAttentionKeepsakePreservesThePagesRealContentVisualAndEvidence() {
        let attended = SurfacePage(
            type: .illustration,
            prompt: "Look closely",
            detail: "The smaller mark is the one worth keeping.",
            payload: BookPagePayload(
                headline: "Moth at the Reading Lamp",
                body: "A white moth settled beside the brass switch and made the whole desk look briefly inhabited.",
                metadata: ["assetName": "MothPlate"]
            )
        )
        let keepsake = PartingWhisper.keepsake(
            from: attended,
            evidence: "the brass switch"
        )

        XCTAssertEqual(keepsake.title, "Moth at the Reading Lamp")
        XCTAssertEqual(keepsake.object, "Moth at the Reading Lamp")
        XCTAssertEqual(keepsake.excerpt, "the brass switch")
        XCTAssertEqual(keepsake.mediaAssets.first?.reference, "MothPlate")
    }

    func testAttentionKeepsakeRequiresFourDistinctPagesAndResetsAfterAward() {
        var learning = ReaderLearningModel()
        for index in 0..<3 {
            learning.record(event(.acted, surfaceID: "surface-\(index)"))
        }
        learning.record(event(.acted, surfaceID: "surface-0"))
        XCTAssertFalse(AttentionKeepsakeGovernor.isEarned(in: learning))

        learning.record(event(.kept, surfaceID: "surface-3"))
        XCTAssertTrue(AttentionKeepsakeGovernor.isEarned(in: learning))

        learning.record(event(.keepsakeEarned, surfaceID: "surface-3"))
        XCTAssertFalse(AttentionKeepsakeGovernor.isEarned(in: learning))
    }

    func testOnlyAReleasedPageEverPaysTheEarnedKeepsake() {
        let leaving = surface(.diary, id: "leaving")
        XCTAssertNil(
            PartingWhisper.releaseKeepsake(for: leaving, learning: ReaderLearningModel()),
            "Nothing is owed until attention has been paid elsewhere."
        )
        XCTAssertNotNil(
            PartingWhisper.releaseKeepsake(for: leaving, learning: earnedLearning())
        )
    }

    func testSwipingPagesAwayNeverEarnsAKeepsake() {
        var learning = ReaderLearningModel()
        for index in 0..<12 {
            learning.record(event(.dismissed, surfaceID: "swiped-\(index)"))
        }
        XCTAssertNil(
            PartingWhisper.releaseKeepsake(for: surface(.diary), learning: learning),
            "Cycling the desk away must never pay the Pocket."
        )
    }

    func testWeightyCardsPayNoKeepsakeWhenTheyLeave() {
        for type in PartingWhisper.excludedTypes {
            XCTAssertNil(
                PartingWhisper.releaseKeepsake(for: surface(type), learning: earnedLearning())
            )
        }
    }

    func testReleasedKeepsakeIsTornFromTheDepartingPageItself() throws {
        let leaving = SurfacePage(
            type: .illustration,
            prompt: "Look closely",
            detail: "The smaller mark is the one worth keeping.",
            payload: BookPagePayload(
                headline: "Moth at the Reading Lamp",
                body: "A white moth settled beside the brass switch.",
                metadata: ["assetName": "MothPlate"]
            )
        )
        let keepsake = try XCTUnwrap(
            PartingWhisper.releaseKeepsake(for: leaving, learning: earnedLearning())
        )

        // A dismissed Page carries no reader input, so the fragment comes off
        // the Page's own words.
        XCTAssertEqual(keepsake.title, "Moth at the Reading Lamp")
        XCTAssertEqual(keepsake.excerpt, "A white moth settled beside the brass switch.")
        XCTAssertEqual(keepsake.mediaAssets.first?.reference, "MothPlate")
    }

    func testKeepsakePartingNamesTheObjectAndDiffersFromThePlainWink() throws {
        let leaving = surface(.souvenir, id: "leaving")
        let keepsake = try XCTUnwrap(
            PartingWhisper.releaseKeepsake(for: leaving, learning: earnedLearning())
        )
        let line = PartingWhisper.keepsakeClosingLine(for: leaving, keepsake: keepsake)

        XCTAssertFalse(line.contains("{page}"))
        XCTAssertFalse(line.contains("{object}"))
        XCTAssertTrue(line.contains("souvenir"))
        XCTAssertTrue(line.contains(keepsake.title))
        XCTAssertNotEqual(line, PartingWhisper.closingLine(for: leaving))
        XCTAssertEqual(line, PartingWhisper.keepsakeClosingLine(for: leaving, keepsake: keepsake))
    }

    private func earnedLearning() -> ReaderLearningModel {
        var learning = ReaderLearningModel()
        for index in 0..<AttentionKeepsakeGovernor.distinctActionsToEarn {
            learning.record(event(.acted, surfaceID: "attended-\(index)"))
        }
        return learning
    }

    func testPocketLedgerKeepsNewestAndHonoursCapacity() {
        var pocket = PocketLedger()
        let base = Date(timeIntervalSince1970: 1_000_000)
        for index in 0..<(PocketLedger.capacity + 10) {
            pocket.press(PocketKeepsake(
                id: "k-\(index)",
                dayID: "2026-07-04",
                pageType: .diary,
                object: "a pressed petal",
                glyph: "leaf",
                foundAt: base.addingTimeInterval(Double(index))
            ))
        }
        XCTAssertEqual(pocket.count, PocketLedger.capacity)
        // Newest first, and the very oldest were pushed out.
        XCTAssertEqual(pocket.newestFirst.first?.id, "k-\(PocketLedger.capacity + 9)")
        XCTAssertFalse(pocket.keepsakes.contains { $0.id == "k-0" })
    }

    func testPocketPressReplacesDuplicateIDs() {
        var pocket = PocketLedger()
        let stamp = Date(timeIntervalSince1970: 2_000_000)
        let make = { (object: String) in
            PocketKeepsake(id: "same", dayID: "d", pageType: .mood, object: object, glyph: "leaf", foundAt: stamp)
        }
        pocket.press(make("a pressed petal"))
        pocket.press(make("a coin of lamplight"))
        XCTAssertEqual(pocket.count, 1)
        XCTAssertEqual(pocket.keepsakes.first?.object, "a coin of lamplight")
    }

    func testPreviouslyStoredDecorativeKeepsakesStillDecode() throws {
        let old = LegacyPocketKeepsake(
            id: "old",
            dayID: "d",
            pageType: .mood,
            object: "a pressed petal",
            glyph: "leaf",
            foundAt: Date(timeIntervalSince1970: 2_000_000)
        )
        let data = try JSONEncoder().encode(old)

        let decoded = try JSONDecoder().decode(PocketKeepsake.self, from: data)

        XCTAssertEqual(decoded.object, "a pressed petal")
        XCTAssertNil(decoded.sourceSurfaceID)
        XCTAssertFalse(decoded.isRealPageFragment)
    }

    func testExcludedTypesNeverReceiveAGenericClosing() {
        for type in PartingWhisper.excludedTypes {
            XCTAssertNil(PartingWhisper.closingLine(for: surface(type)))
        }
    }

    func testPurchaseThankYouSurfaceNeverReceivesAGenericClosing() {
        let thankYou = SurfacePage(
            type: .diary,
            prompt: "prompt",
            detail: "detail",
            payload: BookPagePayload(headline: "h", body: "b", metadata: ["purchaseThankYou": "true"])
        )
        XCTAssertNil(PartingWhisper.closingLine(for: thankYou))
    }

    private func event(
        _ action: ReaderLearningAction,
        surfaceID: String
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            dayID: "2026-07-18",
            action: action,
            surfaceID: surfaceID,
            sourceID: "test-source",
            type: .diary,
            varietyKey: "test",
            hour: 12
        )
    }
}
