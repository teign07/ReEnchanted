import XCTest
@testable import InsideCoverCore

final class InventoryTests: XCTestCase {
    func testPurchasedQuietingGiftWaitsUntilInvoked() {
        let gift = FaeGift(
            id: "coal",
            faeKind: .goblin,
            name: "a pocket of banked dusk",
            descriptionText: "Quiet for a day.",
            effect: .quieting,
            isCold: false,
            acquiredAt: Date(),
            chargesRemaining: nil,
            boundSourceID: nil
        )

        XCTAssertFalse(gift.isActive)
        XCTAssertTrue(gift.isReady)
    }

    func testQuietingGiftExpiresAfterItsDay() {
        var gift = FaeGift(
            id: "coal",
            faeKind: .sentenceSalamander,
            name: "the borrowed coal",
            descriptionText: "Quiet for a day.",
            effect: .quieting,
            isCold: false,
            acquiredAt: Date(),
            chargesRemaining: nil,
            boundSourceID: nil
        )
        gift.activatedAt = Date().addingTimeInterval(-25 * 3_600)
        gift.expiresAt = Date().addingTimeInterval(-3_600)

        XCTAssertFalse(gift.isActive)
        XCTAssertTrue(gift.isReady)
    }

    func testLongMemoryNeedsAChosenKeptPage() {
        var gift = FaeGift(
            id: "quill",
            faeKind: .literaryElf,
            name: "the silver quill",
            descriptionText: "It refuses forgetting.",
            effect: .longMemory,
            isCold: false,
            acquiredAt: Date(),
            chargesRemaining: nil,
            boundSourceID: nil
        )

        XCTAssertFalse(gift.isActive)
        XCTAssertTrue(gift.isReady)
        gift.boundSourceID = "kept-page-id"
        XCTAssertTrue(gift.isActive)
        XCTAssertFalse(gift.isReady)
    }

    func testInventoryPageIsAlwaysAvailableManually() {
        let day = BookDay.today()
        let page = InventoryPageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: Date()
        )

        XCTAssertEqual(page.type, .inventory)
        XCTAssertEqual(page.sourceID, "the-inventory")
        XCTAssertEqual(page.intent, .reflect)
    }

    func testBookShopPreviewOpensTheShopDirectly() throws {
        let now = Date(timeIntervalSince1970: 1_781_500_000)
        let page = try XCTUnwrap(BookShopPreviewPageSourceAdapter().candidates(
            for: BookDay.today(),
            context: CuratorContext.make(for: BookDay.today()),
            inputs: .empty,
            now: now
        ).first)

        XCTAssertEqual(page.sourceID, "bookshop-preview")
        XCTAssertEqual(page.payload.metadata["opensBookShop"], "true")
        XCTAssertEqual(page.prompt, "The BookShop")
    }

    func testBookShopPreviewRespectsItsWeeklyCooldown() {
        let now = Date(timeIntervalSince1970: 1_781_500_000)
        var inputs = BookSourceInputs.empty
        inputs.surfaceHistory["source:bookshop-preview"] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-6 * 86_400),
            recentShowCount: 1
        )

        let pages = BookShopPreviewPageSourceAdapter().candidates(
            for: BookDay.today(),
            context: CuratorContext.make(for: BookDay.today()),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(pages.isEmpty)
    }
}
