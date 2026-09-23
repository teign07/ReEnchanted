import XCTest
@testable import InsideCoverCore

/// Tests written against the paid monthly gate run with the retired Digital
/// Standing Order switched back on, so the plumbing it used stays covered for
/// the day it returns.
class StandingOrderGatedTestCase: XCTestCase {
    private var wasOffered = false

    override func setUp() {
        super.setUp()
        wasOffered = DigitalStandingOrder.isOffered
        DigitalStandingOrder.isOffered = true
    }

    override func tearDown() {
        DigitalStandingOrder.isOffered = wasOffered
        super.tearDown()
    }
}

/// The Digital Standing Order is retired: monthly content is free for every
/// reader, nothing offers the subscription for sale, and a real receipt still
/// shows up so the reader holding it can find the way out.
final class DigitalStandingOrderRetirementTests: XCTestCase {
    private var savedOwned: Set<String> = []

    override func setUp() {
        super.setUp()
        savedOwned = PackEntitlements.ownedPackIDs
        DigitalStandingOrder.isOffered = false
    }

    override func tearDown() {
        PackEntitlements.ownedPackIDs = savedOwned
        DigitalStandingOrder.isOffered = false
        super.tearDown()
    }

    func testTheStandingOrderShipsRetired() {
        XCTAssertFalse(DigitalStandingOrder.isOffered)
    }

    func testAReaderWithNoReceiptsHoldsEveryMonthlyPack() {
        PackEntitlements.ownedPackIDs = []

        XCTAssertTrue(PackEntitlements.hasMonthlyContentPackAccess)
        XCTAssertTrue(PackEntitlements.hasMonthlyContentPackAccess(in: []))
        let packs = BookShopCatalog.listings.filter { $0.family != .standingOrder }
        XCTAssertFalse(packs.isEmpty)
        for pack in packs {
            XCTAssertTrue(PackEntitlements.isUnlocked(pack.packID), pack.title)
            XCTAssertTrue(PackEntitlements.owns(pack.packID, in: []), pack.title)
        }
    }

    func testTheMonthlyStoryReachesEveryReaderThroughEveryChannel() {
        PackEntitlements.ownedPackIDs = []

        XCTAssertTrue(WorldEventRegistry.enabledEvents().contains { $0.event.id == "dictionary-rebellion" })
        XCTAssertFalse(PageArchetypePackRegistry.wordNegotiations().filter { $0.eventID == "dictionary-rebellion" }.isEmpty)
        XCTAssertTrue(NarrativePackRegistry.entities.contains { $0.id == "professor-thaddeus-mook" })
        XCTAssertTrue(NarrativePackRegistry.entities.contains { $0.id == "pippa-pilcrow" })
    }

    func testNothingIsForSaleWhileRetired() {
        XCTAssertTrue(BookShopCatalog.listings.allSatisfy { !$0.isPurchasableAlone() })
    }

    func testFreeGiftsStillWaitForTheReadersChoice() {
        PackEntitlements.ownedPackIDs = []
        for packID in ["nocturne-folio", "margins-and-mysteries", "pack.night-and-garden"] {
            XCTAssertFalse(PackEntitlements.isUnlocked(packID), packID)
            PackEntitlements.ownedPackIDs.insert(packID)
            XCTAssertTrue(PackEntitlements.isUnlocked(packID), packID)
        }
    }

    func testReceiptsStillSayWhoIsActuallySubscribed() {
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(PackEntitlements.hasStandingOrder)

        PackEntitlements.ownedPackIDs = [PackEntitlements.standingOrderPackID]
        XCTAssertTrue(PackEntitlements.hasStandingOrder)
    }

    func testOfferingItAgainRestoresTheGate() {
        DigitalStandingOrder.isOffered = true
        PackEntitlements.ownedPackIDs = []
        let packs = BookShopCatalog.listings.filter { $0.family != .standingOrder }

        XCTAssertFalse(PackEntitlements.hasMonthlyContentPackAccess(in: []))
        XCTAssertTrue(packs.allSatisfy { !PackEntitlements.isUnlocked($0.packID) })
        XCTAssertTrue(BookShopCatalog.listings.filter { $0.family == .standingOrder }.allSatisfy { $0.isPurchasableAlone() })

        PackEntitlements.ownedPackIDs = [PackEntitlements.standingOrderPackID]
        XCTAssertTrue(packs.allSatisfy { PackEntitlements.isUnlocked($0.packID) })
    }
}
