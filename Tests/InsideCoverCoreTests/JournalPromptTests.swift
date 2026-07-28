import XCTest
@testable import InsideCoverCore

final class JournalPromptTests: XCTestCase {
    private struct FixedSemanticScorer: StacksSemanticScoring {
        let modelID = "journal-test"
        var matchingPhrase: String

        func similarity(between query: String, and document: String) -> Double? {
            document.localizedCaseInsensitiveContains(matchingPhrase) ? 0.92 : 0.02
        }
    }

    func testJournalCatalogHasVarietyAndMostlyBookAuthorship() {
        let entries = JournalPromptCatalog.entries
        XCTAssertGreaterThanOrEqual(entries.count, 36)
        XCTAssertEqual(Set(entries.map(\.family)), Set(JournalPromptFamily.allCases))
        XCTAssertGreaterThan(
            entries.filter { !$0.isCastAuthored }.count,
            entries.filter(\.isCastAuthored).count * 4
        )
        XCTAssertTrue(entries.allSatisfy { !$0.question.isEmpty && !$0.deeperQuestion.isEmpty })
    }

    func testSemanticSelectorCanChooseARelevantPromptWithoutInventingContext() {
        let now = makeDate(hour: 19)
        let page = BookPage(
            id: "rain-page",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-600),
            promptText: "Keep one detail",
            userInput: "Rain tapped the fire escape while the room turned blue.",
            tags: ["rain", "sound", "room"],
            sourceID: "one-sentence-souvenir"
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [page])
        let selection = JournalPromptSelector.select(
            day: day,
            inputs: .empty,
            context: .make(for: day),
            now: now,
            scorer: FixedSemanticScorer(matchingPhrase: "sound served")
        )

        XCTAssertEqual(selection.entry.id, "sound-punctuation")
        XCTAssertEqual(selection.selector, "context-semantic-lexical")
        XCTAssertNil(selection.contextLabel)
    }

    func testContextualPromptUsesOnlySuppliedPageEvidence() {
        let now = makeDate(hour: 20)
        let page = BookPage(
            id: "kept-line",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-300),
            promptText: "One sentence",
            userInput: "The grocery cart squeaked like a tiny disappointed ghost.",
            tags: ["sound", "funny"],
            sourceID: "one-sentence-souvenir"
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [page])
        let selection = JournalPromptSelector.select(
            day: day,
            inputs: .empty,
            context: .make(for: day),
            now: now,
            scorer: FixedSemanticScorer(matchingPhrase: "page left out")
        )

        XCTAssertEqual(selection.entry.id, "page-left-out")
        XCTAssertEqual(selection.evidencePageID, page.id)
        XCTAssertTrue(selection.question.contains("grocery cart"))
        XCTAssertFalse(selection.question.contains("{excerpt}"))
    }

    func testLateNightSelectionAvoidsShadowAuthorshipAndMischief() {
        let now = makeDate(hour: 23)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let selection = JournalPromptSelector.select(
            day: day,
            inputs: .empty,
            context: .make(for: day),
            now: now
        )

        XCTAssertFalse(selection.entry.isCastAuthored)
        let lateNightExcluded: Set<JournalPromptFamily> = [.shadow, .authorship, .mischief]
        XCTAssertFalse(lateNightExcluded.contains(selection.entry.family))
    }

    func testJournalSurfaceCarriesPromptProvenanceAndEveningWeight() {
        let now = makeDate(hour: 19)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let surface = DiaryPageSourceAdapter()
            .candidates(for: day, context: .make(for: day), inputs: .empty, now: now)
            .first

        XCTAssertEqual(surface?.type, .diary)
        XCTAssertEqual(surface?.payload.metadata["journalSemanticallyAware"], "true")
        XCTAssertNotNil(surface?.payload.metadata["journalPromptID"])
        XCTAssertNotNil(surface?.payload.metadata["journalDeeperQuestion"])
        XCTAssertNotNil(surface?.payload.metadata["journalResponseInvitation"])
        XCTAssertEqual(surface?.payload.metadata["journalSelector"], "context-lexical")
        XCTAssertEqual(surface?.score, 70)
        XCTAssertGreaterThan(CuratorTimeAffinity.boost(for: .diary, at: now), 0)
    }

    private func makeDate(hour: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 17, hour: hour)
        )!
    }
}
