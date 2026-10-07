import XCTest
@testable import InsideCoverCore

/// Reported twice from real sessions: one desk slot ping-ponging between two
/// evergreen cards forever. Dismissing either one brought it straight back.
///
/// The reserve mints its pages with a `generation` taken from the reader's
/// dismissal count, and that generation was folded into `noveltyKey`. Since
/// `allowsAutomaticSurface` keys its rest interval on exactly that value, every
/// dismissal produced a Page the Book had never seen before, so the one action
/// available to the reader for putting a card down was the action that
/// resurrected it.
final class EvergreenReserveRestTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)

    func testDismissingAReserveCardDoesNotChangeWhatItIs() {
        let before = BookEvergreenPlayReserve.pages(now: now, generation: 0)
        let after = BookEvergreenPlayReserve.pages(now: now, generation: 7)
        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(before.count, after.count)

        for (old, new) in zip(before, after) {
            XCTAssertEqual(
                old.curatorContentNoveltyKey, new.curatorContentNoveltyKey,
                "\(old.prompt) changed identity when the reader dismissed something"
            )
            // The desk still needs a distinct id to seat a replacement card.
            XCTAssertNotEqual(old.id, new.id)
        }
    }

    /// The consequence that mattered: once shown, a reserve card must be able
    /// to rest like anything else.
    func testAShownReserveCardCanActuallyRest() throws {
        let page = try XCTUnwrap(BookEvergreenPlayReserve.pages(now: now, generation: 0).first)
        let history = [
            page.curatorContentNoveltyKey: SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1)
        ]

        // The same seed, re-minted after the reader dismissed something.
        let laterPage = try XCTUnwrap(BookEvergreenPlayReserve.pages(now: now, generation: 4).first)
        XCTAssertFalse(
            CuratorNoveltyPolicy.allowsAutomaticSurface(
                laterPage, history: history, preferences: .init(), now: now.addingTimeInterval(60)
            ),
            "the card came straight back after being dismissed"
        )
    }

    /// A reserve card has to be a working Page, not an empty frame. The
    /// Believing seed used to put a title where the believing goes and offer
    /// nothing to react to, so opening it did nothing at all.
    func testTheEvergreenBelievingActuallyOffersABelieving() throws {
        let page = try XCTUnwrap(
            BookEvergreenPlayReserve.pages(now: now, generation: 0)
                .first { $0.type == .affirmations }
        )
        // The believing itself is the prompt, as on a real Believing page.
        XCTAssertFalse(page.prompt.hasPrefix("A Believing"), "the prompt is still a title")
        XCTAssertGreaterThan(page.prompt.count, 40, "no actual believing offered")
        // And it can be answered without the reader inventing the whole thing.
        let countersigns = page.payload.metadata["countersigns"] ?? ""
        XCTAssertFalse(countersigns.isEmpty, "nothing to countersign")
        XCTAssertTrue(countersigns.contains("||"), "only one way to answer")
        XCTAssertFalse((page.payload.metadata["placeholder"] ?? "").isEmpty)
        // An honest hedge is always available; agreement is never extracted.
        XCTAssertTrue(countersigns.lowercased().contains("we'll see"))
    }

    /// The structural markers must survive a seed carrying its own metadata.
    func testSeedMetadataCannotOverrideTheReserveSStructuralMarkers() {
        for page in BookEvergreenPlayReserve.pages(now: now, generation: 0) {
            XCTAssertEqual(page.payload.metadata["evergreenPlayReserve"], "true", page.prompt)
            XCTAssertEqual(page.payload.metadata["curationLearning"], "forbidden", page.prompt)
        }
    }

    func testEachSeedStillHasItsOwnIdentity() {
        let pages = BookEvergreenPlayReserve.pages(now: now, generation: 0)
        let keys = pages.map(\.curatorContentNoveltyKey)
        XCTAssertEqual(Set(keys).count, keys.count, "two reserve seeds share one identity")
    }
}

/// A `.note` Page is a note a Cast member writes *to* the reader: it carries no
/// text of its own and asks to be generated. The cupboard once seated a
/// reader-written "note to tomorrow" as a `.note`, so the reader was asked to
/// write, then offered "Let me write", and got a note from Soren Ng.
final class EvergreenReserveNoteTypeTests: XCTestCase {
    func testNoCupboardCardIsTypedAsACastWrittenNote() {
        for hours in stride(from: 0, to: 24 * 6, by: 2) {
            let now = Date(timeIntervalSince1970: 1_784_000_000 + Double(hours) * 3_600)
            for page in BookEvergreenPlayReserve.pages(now: now, variantsPerCatalogue: 3, restsFixedSeeds: false) {
                XCTAssertNotEqual(page.type, .note, "\(page.prompt) would ask for a generated Cast note")
            }
        }
    }

    func testTheNoteToTomorrowIsAReaderWrittenLoosePage() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let pages = BookEvergreenPlayReserve.pages(now: now, variantsPerCatalogue: 1, restsFixedSeeds: false)
        let tomorrow = try XCTUnwrap(pages.first { $0.prompt == "Leave A Note Where Tomorrow Can Find It" })
        XCTAssertEqual(tomorrow.type, .plainPage)
    }
}
