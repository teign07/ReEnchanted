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

    func testShadowJournalHasSeveralWaysToAskForTheDarkHalfOfADay() {
        let shadow = JournalPromptCatalog.entries.filter { $0.family == .shadow && !$0.isCastAuthored }
        let questions = shadow.map(\.question)

        XCTAssertGreaterThanOrEqual(shadow.count, 7)
        XCTAssertTrue(questions.contains("What was the worst thing that happened to you today?"))
        XCTAssertTrue(questions.contains("What fought you today?"))
        XCTAssertTrue(questions.contains { $0.contains("took more from you") })
        XCTAssertTrue(questions.contains { $0.contains("push back today") })
    }

    func testReaderCorrectedOpenThreadCanShapeAContextualJournalQuestion() {
        let now = makeDate(hour: 19)
        var inputs = BookSourceInputs.empty
        inputs.readerStory.openThreads = [
            OpenThread(
                id: "thread-red-door",
                line: "the red door remained unanswered",
                shelf: .light,
                openedAt: now.addingTimeInterval(-3 * 86_400),
                lastTouchedAt: now.addingTimeInterval(-86_400),
                movement: .deepened,
                sourcePageID: "page-red-door",
                touchCount: 2,
                closedAt: nil
            )
        ]
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let selection = JournalPromptSelector.select(
            day: day,
            inputs: inputs,
            context: .make(for: day),
            now: now,
            scorer: FixedSemanticScorer(matchingPhrase: "thread that keeps pulling")
        )

        XCTAssertEqual(selection.entry.id, "thread-keeps-pulling")
        XCTAssertTrue(selection.question.contains("red door remained unanswered"))
        XCTAssertEqual(selection.contextLabel, "the red door remained unanswered")
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
            scorer: FixedSemanticScorer(matchingPhrase: "full stop")
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

    func testContextualPromptDoesNotQuoteAnUntouchedBookQuestionAsReaderEvidence() throws {
        let now = makeDate(hour: 20)
        let bookQuestion = "What did the room notice after everybody left?"
        let copiedPromptPage = BookPage(
            id: "legacy-copied-prompt",
            type: .diary,
            createdAt: now.addingTimeInterval(-120),
            promptText: bookQuestion,
            userInput: "  What did the room notice   after everybody left?  ",
            tags: ["journal", "journal-page", "journal-prompt:room-witness"],
            sourceID: "diary-page",
            origin: .userAuthored
        )
        let readerPage = BookPage(
            id: "reader-answer",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-300),
            promptText: "Keep one detail",
            userInput: "The radiator knocked twice after the hallway went quiet.",
            tags: ["sound", "room"],
            sourceID: "one-sentence-souvenir",
            origin: .userAuthored
        )
        let day = BookDay(
            id: BookDay.id(for: now),
            date: now,
            pages: [copiedPromptPage, readerPage]
        )

        let selections = JournalPromptSelector.rankedSelections(
            day: day,
            inputs: .empty,
            context: .make(for: day),
            now: now,
            limit: JournalPromptCatalog.entries.count
        )
        let contextual = try XCTUnwrap(selections.first { $0.entry.id == "routine-cross-examination" })

        XCTAssertEqual(contextual.evidencePageID, readerPage.id)
        XCTAssertEqual(contextual.evidenceExcerpt, "The radiator knocked twice after the hallway went quiet.")
        XCTAssertFalse(contextual.question.contains(bookQuestion))
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

/// The voice pass on journal questions (2026-09-27). A journal question is
/// read at the end of a day by someone tired. It has to be plain enough to
/// answer before the reader has worked out what it means.
final class JournalPromptVoiceTests: XCTestCase {

    private var entries: [JournalPromptEntry] { JournalPromptCatalog.entries }

    func testQuestionsAreSaidPlainly() {
        // The shapes that made questions hard to answer: therapy words,
        // essayist words, and asides that comment on themselves.
        let tells = ["avoidance", "interrupted the default", "supplied the explanation", "supposedly",
                     "honestly take", "indignity", "brought it to you", "abstractions", "survives the indignity",
                     // Childlike honesty (docs/childlike-honesty.md): no soothing
                     // the reader, no therapy "look like", no hedging the premise.
                     "that's allowed", "look like?", "if it could", "kind and completely true"]
        for entry in entries {
            for text in [entry.question, entry.deeperQuestion, entry.title] {
                for tell in tells {
                    XCTAssertFalse(text.lowercased().contains(tell), "\(entry.id): \(tell)")
                }
                XCTAssertFalse(text.contains(";"), "\(entry.id) balances a clause instead of stopping")
                XCTAssertFalse(text.contains(", which "), "\(entry.id) remarks on its own sentence")
            }
            XCTAssertLessThanOrEqual(entry.question.split(separator: " ").count, 32,
                                     "\(entry.id) asks too much in one breath")
        }
    }

    func testEveryTitleIsItsOwn() {
        XCTAssertEqual(Set(entries.map(\.title)).count, entries.count)
        XCTAssertEqual(Set(entries.map(\.question)).count, entries.count)
    }
}
