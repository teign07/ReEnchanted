import XCTest
@testable import InsideCoverCore

/// Monthly packs are subscription-only until their archive window opens.
///
/// The reason is arithmetic, and it is the thing these tests exist to stop
/// anybody quietly undoing. The Standing Order promises twelve packs a year. At
/// $4.99 each that came to $59.88 against a $79.99 annual — **buying every pack
/// individually was cheaper than subscribing**, and every new pack widened the
/// gap. No amount of extra content fixes a structure where the à la carte shelf
/// undercuts the subscription by construction.
///
/// So the sub sells timeliness and the archive sells access. A pack stops being
/// this month's chapter after two months and becomes something you missed,
/// which is a different product and can be priced like one.
final class ArchiveWindowTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? Date()
    }

    private func monthlyDrop(released year: Int, _ month: Int) -> BookShopListing {
        BookShopListing(
            id: "listing-test-drop",
            packID: "test-drop",
            family: .eventPack,
            title: "A Month's Pack",
            goblinPitch: "Fresh off the press.",
            contents: "This month's authored pack.",
            productID: "com.example.pack.test-drop",
            fallbackDisplayPrice: "$4.99",
            subscriptionReleasedAt: BookShopCatalog.releaseMonth(year, month)
        )
    }

    // MARK: The window

    func testAMonthlyPackIsSubscriptionOnlyWhileItIsCurrent() {
        let pack = monthlyDrop(released: 2026, 9)
        XCTAssertFalse(pack.isPurchasableAlone(now: date(2026, 9, 15), calendar: calendar))
        XCTAssertFalse(
            pack.isPurchasableAlone(now: date(2026, 10, 15), calendar: calendar),
            "A one-month window would make the Standing Order a rental — there would never be more than a single chapter out of reach."
        )
    }

    func testItJoinsTheArchiveShelfAfterTwoMonths() {
        let pack = monthlyDrop(released: 2026, 9)
        XCTAssertTrue(pack.isPurchasableAlone(now: date(2026, 11, 1), calendar: calendar))
        XCTAssertTrue(pack.isPurchasableAlone(now: date(2027, 3, 1), calendar: calendar))
    }

    func testTheWindowIsTwoMonths() {
        XCTAssertEqual(BookShopCatalog.archiveWindowMonths, 2)
        let pack = monthlyDrop(released: 2026, 9)
        XCTAssertEqual(
            pack.archiveOpensAt(calendar: calendar),
            BookShopCatalog.releaseMonth(2026, 11)
        )
    }

    /// Free gifts, evergreen folios and retired events were never a monthly
    /// drop, so nothing holds them back.
    func testAListingThatWasNeverAMonthlyDropSellsFromDayOne() {
        let evergreen = BookShopListing(
            id: "listing-evergreen",
            packID: "evergreen",
            family: .pagePack,
            title: "An Evergreen Folio",
            goblinPitch: "Always been here.",
            contents: "Not a monthly drop.",
            productID: "com.example.pack.evergreen",
            fallbackDisplayPrice: "$2.99"
        )
        XCTAssertNil(evergreen.subscriptionReleasedAt)
        XCTAssertTrue(evergreen.isPurchasableAlone(now: date(2026, 9, 1), calendar: calendar))
    }

    // MARK: The catalogue as shipped

    func testTheLaunchSeasonPackIsWindowed() {
        guard let rebellion = BookShopCatalog.listings.first(where: { $0.packID == "dictionary-rebellion" }) else {
            return XCTFail("The Dictionary Rebellion should still be on the shelf.")
        }
        XCTAssertNotNil(rebellion.subscriptionReleasedAt, "September's drop is a monthly pack.")
        XCTAssertFalse(rebellion.isPurchasableAlone(now: date(2026, 9, 25), calendar: calendar))
        XCTAssertTrue(rebellion.isPurchasableAlone(now: date(2026, 11, 5), calendar: calendar))
    }

    func testArchivedEventsStayBuyable() {
        guard let archive = BookShopCatalog.listings.first(where: { $0.packID == "starlit-paper-trial-archive" }) else {
            return XCTFail("The archived event should still be on the shelf.")
        }
        XCTAssertTrue(archive.isPurchasableAlone(now: date(2026, 9, 25), calendar: calendar))
    }

    /// The Standing Order itself is never windowed — it is the thing that
    /// opens the window for everything else.
    func testTheStandingOrderIsAlwaysBuyable() {
        let passes = BookShopCatalog.listings.filter { $0.family == .standingOrder }
        XCTAssertFalse(passes.isEmpty)
        XCTAssertTrue(passes.allSatisfy { $0.isPurchasableAlone(now: date(2026, 9, 25), calendar: calendar) })
    }

    // MARK: The arithmetic that caused all this

    /// **The floor.** Twelve packs at the archive price must cost more than a
    /// year of the Standing Order, or the shelf undercuts the subscription and
    /// no amount of extra content can fix it — each new pack would add to both
    /// sides of the ledger.
    ///
    /// The sub hands over twelve packs a year, so break-even is
    /// `annual ÷ packPrice`. At $4.99 that was sixteen packs and at $5.99 it is
    /// 13.4 — both more than the sub delivers, so it could never win. $6.99 is
    /// the first price where it does.
    func testAYearOfArchivePacksCostsMoreThanAYearOfTheStandingOrder() {
        func cents(_ text: String?) -> Int? {
            guard let text else { return nil }
            let digits = text.filter { $0.isNumber || $0 == "." }
            guard let value = Double(digits) else { return nil }
            return Int((value * 100).rounded())
        }
        guard let annual = BookShopCatalog.standingOrderTiers.first(where: { $0.cadence == .annual }),
              let annualCents = cents(annual.fallbackDisplayPrice),
              let packCents = cents(BookShopCatalog.archivePackPrice) else {
            return XCTFail("Both the annual and the archive price should be set.")
        }
        let packsPerYear = 12
        XCTAssertGreaterThan(
            packCents * packsPerYear,
            annualCents,
            "Buying a year of packs individually is cheaper than subscribing. That is the bug the archive window exists to close."
        )
        let breakEven = Double(annualCents) / Double(packCents)
        XCTAssertLessThan(
            breakEven,
            Double(packsPerYear),
            "Break-even must fall below the twelve packs the Standing Order actually delivers."
        )
    }

    /// Every purchasable pack sits at or above the floor.
    func testNoPackIsPricedBelowTheArchiveFloor() {
        func cents(_ text: String?) -> Int? {
            guard let text else { return nil }
            let digits = text.filter { $0.isNumber || $0 == "." }
            guard let value = Double(digits) else { return nil }
            return Int((value * 100).rounded())
        }
        guard let floor = cents(BookShopCatalog.archivePackPrice) else {
            return XCTFail("The archive floor should be set.")
        }
        let packs = BookShopCatalog.listings.filter { $0.family != .standingOrder }
        XCTAssertFalse(packs.isEmpty)
        for pack in packs {
            guard let price = cents(pack.fallbackDisplayPrice) else { continue }
            XCTAssertGreaterThanOrEqual(
                price, floor,
                "\(pack.title) at \(pack.fallbackDisplayPrice ?? "?") sits under the floor and starts undercutting the subscription."
            )
        }
    }

    /// Monthly drops must still be marked, or the window protects nothing.
    func testMonthlyDropsAreMarkedAndWindowed() {
        let windowedDrops = BookShopCatalog.listings.filter { $0.subscriptionReleasedAt != nil }
        XCTAssertFalse(windowedDrops.isEmpty)
        XCTAssertTrue(
            windowedDrops.allSatisfy { !$0.isPurchasableAlone(now: $0.subscriptionReleasedAt ?? Date(), calendar: calendar) },
            "A monthly drop on sale the month it lands recreates the basket that was cheaper than subscribing."
        )
    }
}
