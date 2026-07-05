import XCTest
@testable import InsideCoverCore

/// The Book's Pocket page: once a few keepsakes have gathered from swiped-away
/// pages, a page surfaces that empties the pocket onto the desk. It waits for the
/// pocket to fill (a minimum count), keys its id to the count so a handled
/// pocketful never re-surfaces, and stands down once today already holds one.
final class BookPocketAdapterTests: XCTestCase {
    private let adapter = BookPocketPageSourceAdapter()

    private func keepsake(_ index: Int) -> PocketKeepsake {
        PocketKeepsake(
            id: "k-\(index)",
            dayID: "2026-07-04",
            pageType: .diary,
            object: "a pressed petal",
            glyph: "leaf",
            foundAt: Date(timeIntervalSince1970: 1_000_000 + Double(index))
        )
    }

    private func inputs(keepsakeCount: Int) -> BookSourceInputs {
        var pocket = PocketLedger()
        for index in 0..<keepsakeCount {
            pocket.press(keepsake(index))
        }
        var inputs = BookSourceInputs.empty
        inputs.pocket = pocket
        return inputs
    }

    private func candidates(inputs: BookSourceInputs, day: BookDay? = nil) -> [SurfacePage] {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let day = day ?? BookDay(id: "today", date: now, pages: [])
        return adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
    }

    func testDoesNotSurfaceBelowMinimum() {
        XCTAssertTrue(candidates(inputs: inputs(keepsakeCount: 0)).isEmpty)
        XCTAssertTrue(candidates(inputs: inputs(keepsakeCount: BookPocketPageSourceAdapter.minimumKeepsakes - 1)).isEmpty)
    }

    func testSurfacesAtMinimumWithPocketMetadata() {
        let surfaced = candidates(inputs: inputs(keepsakeCount: BookPocketPageSourceAdapter.minimumKeepsakes))
        let page = surfaced.first
        XCTAssertEqual(page?.type, .bookPocket)
        XCTAssertEqual(page?.payload.metadata["pocketTotal"], "\(BookPocketPageSourceAdapter.minimumKeepsakes)")
        XCTAssertFalse((page?.payload.metadata["pocketItems"] ?? "").isEmpty)
    }

    func testSurfaceIDIsKeyedToKeepsakeCount() {
        let two = candidates(inputs: inputs(keepsakeCount: 2)).first
        let three = candidates(inputs: inputs(keepsakeCount: 3)).first
        XCTAssertNotNil(two)
        XCTAssertNotNil(three)
        XCTAssertNotEqual(two?.id, three?.id, "A new keepsake should mint a fresh, re-surfaceable page id.")
    }

    func testShowsAtMostTheCapAndReportsRemainder() {
        let count = BookPocketPageSourceAdapter.shownKeepsakes + 5
        let page = candidates(inputs: inputs(keepsakeCount: count)).first
        let items = (page?.payload.metadata["pocketItems"] ?? "").split(separator: "\n")
        XCTAssertEqual(items.count, BookPocketPageSourceAdapter.shownKeepsakes)
        XCTAssertEqual(page?.payload.metadata["pocketTotal"], "\(count)")
    }

    func testDoesNotSurfaceWhenTodayAlreadyHoldsAPocketPage() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let day = BookDay(id: "today", date: now, pages: [
            BookPage(type: .bookPocket, promptText: "The Book turns out its Pocket.", userInput: "kept")
        ])
        XCTAssertTrue(candidates(inputs: inputs(keepsakeCount: 5), day: day).isEmpty)
    }
}
