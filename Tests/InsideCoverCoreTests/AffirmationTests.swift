import XCTest
@testable import InsideCoverCore

final class AffirmationTests: XCTestCase {
    func testOnlyRichBelievingsAdapterServesAffirmations() {
        let adapters = BookPageSourceAdapters.active.filter {
            $0.servedSourceIDs.contains("affirmations-page")
        }

        XCTAssertEqual(adapters.count, 1)
        XCTAssertTrue(adapters[0] is AffirmationsPageSourceAdapter)
    }

    func testBelievingsContainGiftsAndHonestlyHedgeablePacts() {
        let entries = AffirmationLibraryRegistry.allAffirmations
        let gifts = entries.filter { !$0.isPact }
        let pacts = entries.filter(\.isPact)

        XCTAssertFalse(gifts.isEmpty)
        XCTAssertFalse(pacts.isEmpty)
        XCTAssertTrue(entries.allSatisfy { !$0.countersigns.isEmpty })
        XCTAssertTrue(pacts.allSatisfy { pact in
            pact.countersigns.contains { countersign in
                let normalized = countersign.lowercased()
                return normalized.contains("might")
                    || normalized.contains("try")
                    || normalized.contains("maybe")
                    || normalized.contains("we'll see")
                    || normalized.contains("not today")
                    || normalized.contains("if i")
            }
        })
    }

    func testHardDayAlwaysReceivesGiftRatherThanPact() {
        let day = BookDay(
            id: "hard-day",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            pages: []
        )

        for offset in 0..<24 {
            let entry = AffirmationLibraryRegistry.affirmation(
                for: day,
                now: day.date.addingTimeInterval(Double(offset) * 3_600),
                tags: ["hard-day", "rest", "gentle"]
            )
            XCTAssertFalse(entry.isPact, "\(entry.id) turned a hard day into homework")
        }
    }

    func testManualBelievingCarriesKeepableResponseMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let surface = try XCTUnwrap(BookPageSourceAdapters.manualSurface(
            for: .affirmations,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: BookSourceInputs(),
            now: now
        ))

        XCTAssertEqual(surface.type, .affirmations)
        XCTAssertEqual(surface.renderStyle, .promptCard)
        XCTAssertNotNil(surface.payload.metadata["affirmationID"])
        XCTAssertNotNil(surface.payload.metadata["affirmationKind"])
        XCTAssertFalse(surface.payload.metadata["countersigns", default: ""].isEmpty)
        XCTAssertFalse(surface.payload.metadata["placeholder", default: ""].isEmpty)
    }
}
