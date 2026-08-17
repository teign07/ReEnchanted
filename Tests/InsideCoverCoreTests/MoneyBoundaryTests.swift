import Foundation
import XCTest

@testable import InsideCoverCore

/// The reader is asked in onboarding whether money is a boundary. This is the
/// test that the answer does anything.
///
/// Two mechanisms were built to honour it - the capability contract's `cost` and
/// a direct scoring demotion - and both keyed off tags (`spend`, `shopping`,
/// `purchase`, `paid`) that **nothing in the app has ever produced**. A reader
/// who asked to be kept away from spending was shown the BookShop and the
/// Bindery ranked exactly as if they were free.
final class MoneyBoundaryTests: XCTestCase {
    private func surface(metadata: [String: String]) -> SurfacePage {
        SurfacePage(
            type: .bindery,
            sourceID: "bindery",
            intent: .reflect,
            score: 50,
            reason: "r",
            prompt: "The Bindery Is Open",
            detail: "d",
            payload: BookPagePayload(
                headline: "October Wants a Cover", body: "b", metadata: metadata)
        )
    }

    func testASurfaceThatOpensTheShopCostsMoney() {
        let shop = surface(metadata: ["opensBookShop": "true"])
        XCTAssertEqual(PageCapabilityContract.inferred(for: shop).cost, .optionalSpend)
    }

    func testTheBinderyShelfCostsMoney() {
        let bindery = surface(metadata: ["binderyShelf": "true"])
        XCTAssertEqual(PageCapabilityContract.inferred(for: bindery).cost, .optionalSpend)
    }

    /// And an ordinary Page is still free, so the boundary does not swallow the
    /// whole desk.
    func testAnOrdinaryPageIsFree() {
        let plain = surface(metadata: ["tags": "diary,evening"])
        XCTAssertEqual(PageCapabilityContract.inferred(for: plain).cost, .free)
    }

    /// The contract is what the money boundary actually reads, so a reader who
    /// said "free by default" gets a commerce Page demoted rather than ranked
    /// as if it cost nothing.
    func testTheBoundaryDemotesWhatCostsMoney() {
        var mood = CuratorMood()
        mood.declaredCuration.moneyBoundary = "free by default"
        let paid = PageCapabilityContract
            .inferred(for: surface(metadata: ["opensBookShop": "true"]))
            .selectionMultiplier(mood: mood, movement: nil, role: nil)
        let free = PageCapabilityContract
            .inferred(for: surface(metadata: ["tags": "diary"]))
            .selectionMultiplier(mood: mood, movement: nil, role: nil)
        XCTAssertLessThan(
            paid, free,
            "a reader who asked for free-by-default saw the shop ranked as if it were free")
    }
}
