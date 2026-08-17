import XCTest
@testable import InsideCoverCore

/// Monthly Content Packs belong to the Digital Standing Order. Old product
/// identifiers remain recognizable for receipt restoration, but the catalogue
/// must never reopen an à-la-carte purchase path.
final class ArchiveWindowTests: XCTestCase {
    func testMonthlyContentPacksAreAlwaysSubscriptionOnly() {
        let dates = [
            BookShopCatalog.releaseMonth(2026, 9),
            BookShopCatalog.releaseMonth(2027, 9)
        ]
        let packs = BookShopCatalog.listings.filter { $0.family != .standingOrder }

        XCTAssertFalse(packs.isEmpty)
        for pack in packs {
            for date in dates {
                XCTAssertFalse(
                    pack.isPurchasableAlone(now: date),
                    "\(pack.title) must stay inside the Digital Standing Order."
                )
            }
            XCTAssertNil(pack.archiveOpensAt())
        }
    }

    func testMonthlyContentPacksHaveNoCurrentSalePrice() {
        let packs = BookShopCatalog.listings.filter { $0.family != .standingOrder }
        XCTAssertTrue(packs.allSatisfy { $0.fallbackDisplayPrice == nil })
    }

    func testStandingOrderRemainsPurchasable() {
        let orders = BookShopCatalog.listings.filter { $0.family == .standingOrder }
        XCTAssertFalse(orders.isEmpty)
        XCTAssertTrue(orders.allSatisfy { $0.isPurchasableAlone() })
    }

    func testStandingOrderUnlocksCurrentAndEarlierPacks() {
        let saved = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = saved }

        PackEntitlements.ownedPackIDs = [PackEntitlements.standingOrderPackID]
        let packs = BookShopCatalog.listings.filter { $0.family != .standingOrder }
        XCTAssertFalse(packs.isEmpty)
        XCTAssertTrue(packs.allSatisfy { PackEntitlements.isUnlocked($0.packID) })
    }
}
