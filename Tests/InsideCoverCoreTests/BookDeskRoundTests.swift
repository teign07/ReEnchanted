import XCTest
@testable import InsideCoverCore

final class BookDeskRoundTests: XCTestCase {
    private func page(_ source: String, _ type: BookPageType = .diary, id: String? = nil) -> SurfacePage {
        SurfacePage(id: id ?? source, type: type, sourceID: source, prompt: "p", detail: "d")
    }

    func testCapacityAndUniqueLogicalSlots() {
        var round = BookDeskRound()
        let pages = (0..<12).map { page("p-\($0)") }
        round.begin(with: [page("a"), page("a", .diary, id: "rotated")] + pages)
        XCTAssertEqual(round.resolutions.count, BookDeskRound.huntCapacity)
    }

    func testOpenIsIdempotentAndOutranksPass() {
        var round = BookDeskRound(); let item = page("a")
        round.begin(with: [item]); round.pass(item); round.open(item); round.pass(item)
        XCTAssertEqual(round.resolutions[item.deskSlotKey], .opened)
    }

    func testPassUndoAndRotatedID() {
        var round = BookDeskRound(); let original = page("a", id: "old")
        round.begin(with: [original]); round.pass(original)
        round.undoPass(page("a", id: "new"))
        XCTAssertEqual(round.resolutions[original.deskSlotKey], .waiting)
    }

    func testNineStraightPassesCompleteHuntAndOutsidePageIsIgnored() {
        var round = BookDeskRound()
        let pages = (0..<BookDeskRound.huntCapacity).map { page("p-\($0)") }
        round.begin(with: pages)
        round.open(page("outside"))
        for page in pages.dropLast() { round.pass(page) }
        XCTAssertFalse(round.isComplete)
        round.pass(pages.last!)
        XCTAssertTrue(round.isComplete)
    }

    func testOpeningCatchesVisibleTrioAndReturnsHiddenPagesToSleep() {
        var round = BookDeskRound()
        let pages = (0..<BookDeskRound.huntCapacity).map { page("p-\($0)") }
        round.begin(with: pages)
        round.catchPage(pages[1], visiblePages: Array(pages.prefix(BookDeskRound.visibleCapacity)))

        XCTAssertEqual(round.slotKeys, Set(pages.prefix(3).map(\.deskSlotKey)))
        XCTAssertEqual(round.resolutions[pages[1].deskSlotKey], .opened)
        XCTAssertFalse(round.isComplete)

        round.pass(pages[0])
        round.pass(pages[2])
        XCTAssertTrue(round.isComplete)
    }

    func testUntouchedEnrichmentRekeysRoundToVisiblePages() {
        var round = BookDeskRound()
        round.begin(with: [page("a"), page("b"), page("c")])
        let enriched = [page("magic"), page("a"), page("b")]
        round.reconcileUntouched(with: enriched)
        XCTAssertEqual(round.slotKeys, Set(enriched.map(\.deskSlotKey)))
    }

    func testTouchedRoundCannotBeRewrittenByEnrichment() {
        var round = BookDeskRound()
        let pages = [page("a"), page("b"), page("c")]
        round.begin(with: pages)
        round.open(pages[0])
        round.reconcileUntouched(with: [page("magic"), page("b"), page("c")])
        XCTAssertEqual(round.slotKeys, Set(pages.map(\.deskSlotKey)))
        XCTAssertEqual(round.resolutions[pages[0].deskSlotKey], .opened)
    }
}
