import XCTest
@testable import InsideCoverCore

final class HiddenMagicPracticeTests: XCTestCase {
    func testCuratedPagesKeepTheirOwnOutcomeWithoutCrossPageLensMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let pages = BookCurator.surfacedPages(
            for: day,
            inputs: .empty,
            now: now,
            limit: 12
        )

        XCTAssertFalse(pages.isEmpty)
        XCTAssertTrue(pages.allSatisfy { page in
            page.payload.metadata.keys.allSatisfy { !$0.hasPrefix("hiddenMagicLens") }
        })
    }

    func testLegacyLensFindingStillRoundTripsWithoutDrivingNewPages() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let legacyPage = findingPage(
            id: "sound-legacy",
            sense: .sound,
            date: now,
            text: "The room kept a different quiet sound."
        )

        let data = try JSONEncoder().encode(legacyPage)
        let decoded = try JSONDecoder().decode(BookPage.self, from: data)

        XCTAssertEqual(decoded.hiddenMagicFinding, legacyPage.hiddenMagicFinding)
    }

    private func surface(_ type: BookPageType, id: String) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: type.rawValue,
            intent: .capture,
            renderStyle: .promptCard,
            score: 60,
            reason: "test",
            prompt: type.title,
            detail: "A page in its own voice.",
            payload: BookPagePayload(headline: type.title, body: "A page in its own voice.")
        )
    }

    private func findingPage(
        id: String,
        sense: HiddenMagicSense,
        date: Date,
        text: String
    ) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: date,
            promptText: "Find it.",
            userInput: text,
            tags: ["hidden-magic", "hidden-magic-finding", "hidden-magic-sense:\(sense.rawValue)"],
            hiddenMagicFinding: HiddenMagicFinding(
                lensID: "test:\(sense.rawValue)",
                sense: sense,
                action: "Notice something real.",
                proofPrompt: "Keep one detail.",
                expressionModes: [.words],
                foundAt: date
            )
        )
    }
}
