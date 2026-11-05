import XCTest
@testable import InsideCoverCore

/// An opened lore Page is a paragraph and a dare, so it ends early. The shelf
/// neighbours are what keep it from reading as empty, which only works if every
/// lore page can name some. The Compass Core page was the one noticed; this
/// holds the rest to the same floor.
final class LoreShelfNeighboursTests: XCTestCase {
    func testEveryLorePageHasNeighboursAndNeverListsItself() {
        let pool = BookReferenceCatalog.enchantifyLore
        XCTAssertGreaterThan(pool.count, 3)
        for snippet in pool {
            let neighbours = BookReferenceCatalog.shelfNeighbours(of: snippet)
            XCTAssertEqual(neighbours.count, 3, "\(snippet.id) has too few neighbours")
            XCTAssertFalse(neighbours.contains { $0.id == snippet.id }, "\(snippet.id) lists itself")
            XCTAssertEqual(Set(neighbours.map(\.id)).count, neighbours.count, "\(snippet.id) repeats a neighbour")
        }
    }

    func testNeighboursAreStable() {
        guard let snippet = BookReferenceCatalog.enchantifyLore.first else { return XCTFail("no lore") }
        XCTAssertEqual(
            BookReferenceCatalog.shelfNeighbours(of: snippet).map(\.id),
            BookReferenceCatalog.shelfNeighbours(of: snippet).map(\.id)
        )
    }

    func testNeighboursOfAnUnknownPageStillFillTheShelf() {
        let stranger = ReferenceSnippet(
            id: "labyrinth-lore-not-on-the-shelf", sourceID: "labyrinth-lore",
            title: "Stranger", prompt: "", body: "", tags: ["no-such-tag"]
        )
        XCTAssertEqual(BookReferenceCatalog.shelfNeighbours(of: stranger).count, 3)
    }

    func testShelfSurfaceKeepsTheIdentityTheCuratorGives() {
        guard let snippet = BookReferenceCatalog.enchantifyLore.first(where: { $0.practice != nil })
                ?? BookReferenceCatalog.enchantifyLore.first else { return XCTFail("no lore") }
        let surface = EnchantifyLorePageSourceAdapter().shelfSurface(for: snippet)
        XCTAssertEqual(surface.type, .lore)
        XCTAssertEqual(surface.id, "\(surface.sourceID)-\(snippet.id)")
        XCTAssertEqual(surface.payload.metadata["snippetID"], snippet.id)
        XCTAssertEqual(surface.payload.metadata["practice"], snippet.practice?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty)
        XCTAssertFalse(surface.spendsCuratorAskBudget)
    }
}
