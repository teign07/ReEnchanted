import XCTest
@testable import InsideCoverCore

/// A hand-opened Page is a leaf the reader deliberately fetched, not a
/// catalogue card and not a curation receipt. The folio prints its visible
/// fields together, so each one has to do a different job.
final class HandOpenedPageCopyTests: XCTestCase {
    func testEveryPageTypeHasDistinctDeckAndBody() {
        for type in BookPageType.allCases {
            let copy = type.handOpened
            XCTAssertFalse(copy.deck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(copy.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertNotEqual(
                normalized(copy.deck),
                normalized(copy.body),
                "\(type.rawValue) repeats the same hand-opened copy twice"
            )
        }
    }

    func testHandOpenedCopyAvoidsCatalogueAndAssistantRegister() {
        let banned = [
            "opened directly", "glow menu", "manual", "cadence",
            "semantically", "responsive", "event-driven", "simulation",
            "meaningful", "personalized", "invitation", "journey",
            "no pressure", "when you're ready", "feel free to",
            "voluntary", "refusable", "designed to", "allows you to"
        ]

        for type in BookPageType.allCases {
            let copy = type.handOpened
            let visible = "\(copy.deck)\n\(copy.body)".lowercased()
            for phrase in banned {
                XCTAssertFalse(
                    visible.contains(phrase),
                    "\(type.rawValue)'s hand-opened Page says ‘\(phrase)’"
                )
            }
        }
    }

    func testHandOpenedSurfaceDoesNotPrintTheRegistryNoteOrMenuReceipt() {
        let now = Date(timeIntervalSince1970: 1_755_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        for type in BookPageType.allCases {
            let source = BookPageSourceRegistry.source(for: type)
            let copy = source.handOpened
            let surface = SurfacePage.handOpened(source: source, day: day, now: now)

            XCTAssertEqual(surface.prompt, source.title)
            XCTAssertEqual(surface.detail, copy.deck)
            XCTAssertEqual(surface.payload.body, copy.body)
            XCTAssertEqual(surface.reason, "")
            XCTAssertEqual(surface.payload.metadata["handOpened"], "true")
            XCTAssertNotEqual(normalized(surface.detail), normalized(source.note))
            XCTAssertNotEqual(normalized(surface.payload.body), normalized(source.note))
        }
    }

    func testSharedTypeSourcesKeepTheirOwnVoices() {
        let sources = [
            BookShopPreviewPageSourceAdapter().source,
            GreyPageThreatSourceAdapter().source,
            WorldEventPageSourceAdapter().source,
            QuillChoosingPageSourceAdapter().source
        ]

        for source in sources {
            XCTAssertNotEqual(source.handOpened.deck, source.type.handOpened.deck)
            XCTAssertNotEqual(source.handOpened.body, source.type.handOpened.body)
            XCTAssertNotEqual(normalized(source.handOpened.deck), normalized(source.note))
            XCTAssertNotEqual(normalized(source.handOpened.body), normalized(source.note))
        }
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
