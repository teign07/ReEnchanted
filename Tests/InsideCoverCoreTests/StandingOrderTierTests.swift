import XCTest
@testable import InsideCoverCore

/// The Standing Order ships as three cadences (weekly/monthly/annual) that all
/// grant the same all-packs entitlement. These pin the resolver the paywall and
/// StoreKit restore rely on: any cadence's receipt must map to the Standing
/// Order pack, and owning it must satisfy any gated pack.
final class StandingOrderTierTests: XCTestCase {
    func testThreeCadencesExistWithTrials() {
        let tiers = BookShopCatalog.standingOrderTiers
        XCTAssertEqual(Set(tiers.map(\.cadence)), [.weekly, .monthly, .annual])
        XCTAssertTrue(tiers.allSatisfy { $0.freeTrialDays == 10 }, "Every cadence carries the 10-day trial.")
        XCTAssertTrue(tiers.allSatisfy { !$0.fallbackDisplayPrice.isEmpty })
    }

    func testEveryCadenceProductGrantsTheStandingOrder() {
        for tier in BookShopCatalog.standingOrderTiers {
            XCTAssertEqual(
                BookShopCatalog.packID(forProductID: tier.productID),
                PackEntitlements.standingOrderPackID,
                "\(tier.cadence) receipt should grant the Standing Order pack."
            )
        }
    }

    func testLegacyAnnualListingStillResolves() {
        // The original goblin-market annual listing must keep granting the pass.
        let annualListing = BookShopCatalog.listings.first {
            $0.packID == PackEntitlements.standingOrderPackID
        }
        let productID = try? XCTUnwrap(annualListing?.productID)
        XCTAssertEqual(BookShopCatalog.packID(forProductID: productID ?? ""), PackEntitlements.standingOrderPackID)
    }

    func testUnrelatedPackResolvesToItself() {
        let pack = BookShopCatalog.listings.first { $0.packID != PackEntitlements.standingOrderPackID }
        XCTAssertNotNil(pack)
        if let pack {
            XCTAssertEqual(BookShopCatalog.packID(forProductID: pack.productID), pack.packID)
        }
    }

    func testOwningStandingOrderSatisfiesAnyGatedPack() {
        let owned: Set<String> = [PackEntitlements.standingOrderPackID]
        XCTAssertTrue(PackEntitlements.owns("dictionary-rebellion", in: owned))
        XCTAssertTrue(PackEntitlements.owns("any-future-pack", in: owned))
    }

    func testUnknownProductResolvesToNil() {
        XCTAssertNil(BookShopCatalog.packID(forProductID: "com.example.not.a.real.product"))
    }
}
