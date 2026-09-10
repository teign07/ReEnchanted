import XCTest
@testable import InsideCoverCore

/// The Standing Order ships as two cadences (monthly/annual) that both
/// grant the same all-packs entitlement. These pin the resolver the paywall and
/// StoreKit restore rely on: any cadence's receipt must map to the Standing
/// Order pack, and owning it must satisfy any gated pack.
final class StandingOrderTierTests: XCTestCase {
    func testMonthlyAccessRequiresEitherSubscriptionRatherThanAnIndividualPack() {
        XCTAssertFalse(PackEntitlements.hasMonthlyContentPackAccess(in: []))
        XCTAssertFalse(PackEntitlements.hasMonthlyContentPackAccess(in: ["count-unbound"]))
        XCTAssertTrue(PackEntitlements.hasMonthlyContentPackAccess(in: [PackEntitlements.standingOrderPackID]))
        XCTAssertTrue(PackEntitlements.hasMonthlyContentPackAccess(in: [PackEntitlements.boundYearDigitalPackID]))
        XCTAssertTrue(PackEntitlements.hasMonthlyContentPackAccess(in: [
            PackEntitlements.standingOrderPackID, PackEntitlements.boundYearDigitalPackID]))
    }

    func testBoundYearDigitalGrantEndsAtPaidBoundaryEvenWithCachedActiveStatus() {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 200)
        var membership = BoundYearMembership(cadence: .monthly, status: .active,
            startedAt: start, paidThrough: end, endedAt: nil)
        XCTAssertTrue(membership.hasMonthlyContentAccess(at: start))
        XCTAssertTrue(membership.hasMonthlyContentAccess(at: end.addingTimeInterval(-1)))
        XCTAssertFalse(membership.hasMonthlyContentAccess(at: end))
        XCTAssertFalse(membership.hasMonthlyContentAccess(at: start.addingTimeInterval(-1)))
        membership.endedAt = Date(timeIntervalSince1970: 150)
        XCTAssertTrue(membership.hasMonthlyContentAccess(at: Date(timeIntervalSince1970: 149)))
        XCTAssertFalse(membership.hasMonthlyContentAccess(at: Date(timeIntervalSince1970: 150)))
        membership.status = .lapsed
        XCTAssertFalse(membership.hasMonthlyContentAccess(at: start))
    }

    func testServerDenialSurvivesSaveReloadAndVerifiedRecovery() throws {
        var member = BoundYearMembership(cadence: .monthly, status: .active,
            startedAt: Date(timeIntervalSince1970: 100), paidThrough: Date(timeIntervalSince1970: 200))
        var remote = BoundYearMembershipStatus(membershipID: "sub_test", status: "active",
            cancelAtPeriodEnd: false, currentPeriodEnd: 300, paymentVerified: false)
        member.reconcile(remote)
        XCTAssertEqual(member.paidThrough, Date(timeIntervalSince1970: 200))
        member = try JSONDecoder().decode(BoundYearMembership.self, from: JSONEncoder().encode(member))
        XCTAssertFalse(member.hasMonthlyContentAccess(at: Date(timeIntervalSince1970: 150)))
        remote.paymentVerified = true
        member.reconcile(remote)
        XCTAssertTrue(member.hasMonthlyContentAccess(at: Date(timeIntervalSince1970: 250)))
        XCTAssertEqual(member.paidThrough, Date(timeIntervalSince1970: 300))
    }

    func testTerminalCancellationCannotBecomeActiveFromScheduledCancellationFlag() {
        var member = BoundYearMembership(cadence: .annual, status: .active,
            startedAt: Date(timeIntervalSince1970: 100), paidThrough: Date(timeIntervalSince1970: 300))
        member.reconcile(BoundYearMembershipStatus(membershipID: "sub_test", status: "canceled",
            cancelAtPeriodEnd: true, currentPeriodEnd: 300, paymentVerified: true))
        XCTAssertEqual(member.status, .cancelled)
        XCTAssertFalse(member.hasMonthlyContentAccess(at: Date(timeIntervalSince1970: 150)))
    }

    func testTrialReminderFiresExactlyOneDayBeforeVerifiedEnd() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 24, hour: 15))
        )
        let trialEndsAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 15))
        )

        let plan = try XCTUnwrap(StandingOrderTrialReminderPlan.make(
            trialEndsAt: trialEndsAt,
            price: "$44.99",
            periodUnit: "year",
            now: now,
            calendar: calendar
        ))

        XCTAssertEqual(
            plan.fireDate,
            calendar.date(byAdding: .day, value: -1, to: trialEndsAt)
        )
        XCTAssertEqual(plan.title, "Your free trial ends tomorrow")
        XCTAssertTrue(plan.body.contains("If it is still set to renew"))
        XCTAssertTrue(plan.body.contains("every page you made stays yours"))
    }

    func testTrialReminderRefusesAOneDayWarningAfterWindowPassed() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 16))
        )
        let trialEndsAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 15))
        )

        XCTAssertNil(StandingOrderTrialReminderPlan.make(
            trialEndsAt: trialEndsAt,
            price: "$7.99",
            periodUnit: "month",
            now: now,
            calendar: calendar
        ))
    }

    func testTwoCadencesExistWithDevelopmentTrialPreview() {
        let tiers = BookShopCatalog.standingOrderTiers
        XCTAssertEqual(Set(tiers.map(\.cadence)), [.monthly, .annual])
        XCTAssertTrue(
            tiers.allSatisfy { $0.freeTrialDays == 30 },
            "The local counter should preview the intended 30-day trial."
        )
        XCTAssertTrue(tiers.allSatisfy { !$0.fallbackDisplayPrice.isEmpty })
    }

    func testCatalogFallbackPricesMatchTheIntendedStandingOrderPricePoint() {
        let tiers = Dictionary(
            uniqueKeysWithValues: BookShopCatalog.standingOrderTiers.map { ($0.cadence, $0) }
        )
        XCTAssertEqual(tiers[.monthly]?.fallbackDisplayPrice, "$9.99")
        XCTAssertEqual(tiers[.annual]?.fallbackDisplayPrice, "$79.99")

        let standingOrderListings = Dictionary(
            uniqueKeysWithValues: BookShopCatalog.listings
                .filter { $0.family == .standingOrder }
                .map { ($0.productID, $0) }
        )
        for tier in BookShopCatalog.standingOrderTiers {
            XCTAssertEqual(
                standingOrderListings[tier.productID]?.fallbackDisplayPrice,
                tier.fallbackDisplayPrice
            )
        }
    }

    func testRetiredWeeklyProductStillRestoresTheStandingOrder() {
        XCTAssertEqual(
            BookShopCatalog.packID(
                forProductID: "com.openclaw.enchantify.insidecover.pass.standing-order.weekly"
            ),
            PackEntitlements.standingOrderPackID
        )
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

    func testEveryOfferedCadenceAppearsInTheGoblinMarket() {
        let marketProductIDs = Set(
            BookShopCatalog.listings
                .filter { $0.family == .standingOrder }
                .map(\.productID)
        )
        XCTAssertEqual(marketProductIDs, Set(BookShopCatalog.standingOrderTiers.map(\.productID)))
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
