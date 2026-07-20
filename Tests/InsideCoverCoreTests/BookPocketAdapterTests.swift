import XCTest
@testable import InsideCoverCore

/// The Book's Pocket page: once a few attention-earned fragments have gathered,
/// a page surfaces that empties the pocket onto the desk. It waits for the
/// pocket to fill (a minimum count), keys its id to the count so a newly filled
/// pocket gets a fresh identity, and stands down once today already holds one.
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

    func testPocketSurfaceCarriesAndRevealsRealPageFragments() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        var pocket = PocketLedger()
        pocket.press(PocketKeepsake(
            id: "real-1",
            dayID: "today",
            pageType: .weather,
            object: "Fog at the Window",
            glyph: "cloud.fog",
            foundAt: now.addingTimeInterval(-20),
            sourceSurfaceID: "weather-fog",
            title: "Fog at the Window",
            excerpt: "The roofs disappeared one chimney at a time.",
            reason: "Fog was moving through the reader's morning.",
            mediaAssets: []
        ))
        pocket.press(PocketKeepsake(
            id: "real-2",
            dayID: "today",
            pageType: .illustration,
            object: "A Small Green Door",
            glyph: "photo",
            foundAt: now.addingTimeInterval(-10),
            sourceSurfaceID: "illustration-door",
            title: "A Small Green Door",
            excerpt: "The paint had worn away around a keyhole no one used.",
            reason: "The illustration rose from the archive.",
            mediaAssets: [BookPageMediaAsset(kind: .bundledImage, reference: "GreenDoor")]
        ))
        var richInputs = BookSourceInputs.empty
        richInputs.pocket = pocket

        let page = try XCTUnwrap(candidates(inputs: richInputs).first)
        let encoded = try XCTUnwrap(page.payload.metadata[PocketKeepsakeArchive.metadataKey])
        let revealed = PocketKeepsakeArchive.decode(encoded)

        XCTAssertEqual(revealed.map(\.title), ["A Small Green Door", "Fog at the Window"])
        XCTAssertTrue(page.payload.body.contains("The paint had worn away"))
        XCTAssertEqual(page.mediaAssets.first?.reference, "GreenDoor")
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
