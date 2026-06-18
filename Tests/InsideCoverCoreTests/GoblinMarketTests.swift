import XCTest
@testable import InsideCoverCore

final class GoblinMarketTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 21)) ?? Date()
    }

    private func callingCardState() -> FaePlayerState {
        var fae = FaePlayerState()
        fae.gifts = [FaeGift(
            id: "card", faeKind: .goblin, name: "calling card",
            descriptionText: "", effect: .callingCard, isCold: false,
            acquiredAt: Date(), chargesRemaining: 1, boundSourceID: nil
        )]
        return fae
    }

    func testMoneyShelfAlwaysBrowseableEvenWhenStallsAreDark() {
        // An ordinary date with an empty Fae state: the in-world stalls are shut,
        // but the coin shelf still lists unowned, shipping packs.
        let stall = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: FaePlayerState(),
                                             belief: 40, greyLevel: 0, calendar: cal)
        XCTAssertFalse(stall.open || !stall.wares.isEmpty, "closed stalls show no in-world wares")
        XCTAssertFalse(stall.packs.isEmpty, "money packs are always browseable")
        XCTAssertTrue(stall.packs.allSatisfy { !$0.comingSoon })
    }

    func testOwnedPacksDropOffTheCoinShelf() {
        let pack = BookShopCatalog.listings.first { !$0.comingSoon }!
        let stall = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: FaePlayerState(),
                                             belief: 40, greyLevel: 0,
                                             ownedPackIDs: [pack.packID], calendar: cal)
        XCTAssertFalse(stall.packs.contains { $0.packID == pack.packID })
    }

    func testCallingCardOpensAThinStall() {
        let stall = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: callingCardState(),
                                             belief: 40, greyLevel: 0, calendar: cal)
        XCTAssertTrue(stall.open, "a calling card props the side door open")
        XCTAssertFalse(stall.wares.isEmpty, "an open stall lays out in-world wares")
        XCTAssertTrue(stall.wares.allSatisfy { $0.rarity < 3 }, "rare wares stay under the counter")
    }

    func testHiddenShelfGatedByConditions() {
        let calm = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: callingCardState(),
                                            belief: 40, greyLevel: 0, calendar: cal)
        XCTAssertTrue(calm.hidden.isEmpty, "nothing under the counter on an ordinary calm night")

        let pressed = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: callingCardState(),
                                               belief: 40, greyLevel: 2, calendar: cal)
        XCTAssertFalse(pressed.hidden.isEmpty, "a grey night brings out the rare shelf")
        XCTAssertTrue(pressed.hidden.allSatisfy { $0.rarity >= 3 })

        let afterCollapse = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: callingCardState(),
                                                     belief: 40, greyLevel: 0,
                                                     recentBookJumpCollapse: true, calendar: cal)
        XCTAssertFalse(afterCollapse.hidden.isEmpty, "a recent collapse opens the under-the-counter shelf")
    }

    func testPricingMovesWithMoodAndWarmthButNeverBelowOne() {
        let ware = GoblinMarketEngine.beliefWares.first { $0.basePrice >= 8 }!
        let feverish = GoblinMarketEngine.price(ware, mood: .feverish, goblinWarmth: 0)
        let serious = GoblinMarketEngine.price(ware, mood: .serious, goblinWarmth: 0)
        XCTAssertGreaterThan(feverish, serious, "feverish marks up, serious deals")
        let warm = GoblinMarketEngine.price(ware, mood: .business, goblinWarmth: 12)
        let cold = GoblinMarketEngine.price(ware, mood: .business, goblinWarmth: 0)
        XCTAssertLessThan(warm, cold, "standing earns a discount")
        XCTAssertGreaterThanOrEqual(GoblinMarketEngine.price(ware, mood: .serious, goblinWarmth: 99), 1)
    }

    func testStockRotatesByDay() {
        let a = GoblinMarketEngine.stall(on: date(2026, 7, 7), fae: callingCardState(),
                                         belief: 40, greyLevel: 0, calendar: cal).wares.map(\.id)
        let b = GoblinMarketEngine.stall(on: date(2026, 7, 14), fae: callingCardState(),
                                         belief: 40, greyLevel: 0, calendar: cal).wares.map(\.id)
        XCTAssertNotEqual(a, b, "the shelf reshuffles across days")
    }
}
