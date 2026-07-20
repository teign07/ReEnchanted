import XCTest
@testable import InsideCoverCore

private struct MeaningfulSurfaceTestScorer: StacksSemanticScoring {
    var modelID: String { "meaningful-surface-test" }
    var phrase: String
    var match: Double = 0.92

    func similarity(between query: String, and document: String) -> Double? {
        document.localizedCaseInsensitiveContains(phrase) ? match : 0.04
    }
}

final class MeaningfulPassageSurfaceTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let sender = NarrativeWorldEntity(
        id: "penny-blackletter",
        packID: "core",
        name: "Penny Blackletter",
        kind: .character,
        belief: 42,
        narrativeWeight: 28,
        traits: ["observant", "archival"],
        beliefs: ["honest details matter"],
        tags: ["records", "margins"]
    )

    private func authoredPage(id: String = "reader-keep", daysAgo: Double = 0.001) -> BookPage {
        BookPage(
            id: id,
            type: .diary,
            createdAt: now.addingTimeInterval(-daysAgo * 86_400),
            promptText: "What stayed with you?",
            userInput: "I washed the cups before bed. I left the porch light on because coming home should not require bravery. The cat stole my chair afterward.",
            origin: .userAuthored
        )
    }

    func testQuickNoteUsesSelectedMiddlePassageInsteadOfRecentPageOpenings() throws {
        let kept = authoredPage()
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [kept])
        let surface = StudentNotePageGenerator.draftCandidate(
            for: sender,
            source: BookPageSourceRegistry.source(for: .note),
            day: day,
            inputs: .empty,
            now: now,
            semanticScorer: MeaningfulSurfaceTestScorer(phrase: "porch light")
        )

        XCTAssertEqual(surface.payload.metadata["meaningfulSourcePageID"], kept.id)
        XCTAssertTrue(surface.payload.metadata["meaningfulSourcePassage"]?.contains("porch light") == true)
        XCTAssertEqual(surface.payload.metadata["noteSubjectKind"], "the reader's own kept words")
        XCTAssertEqual(surface.payload.metadata["noteSubjectRequired"], "true")
        XCTAssertTrue(surface.payload.body.contains("REQUIRED KEPT-PAGE SUBJECT"))
        XCTAssertTrue(surface.payload.body.contains("the note must plainly be about it"))
        XCTAssertFalse(surface.payload.body.contains("Recent kept pages:"))
    }

    func testQuickNoteCanUseWhatHappenedInKeptFictionEvenAfterThatPageWasPreviouslyEchoed() throws {
        let story = BookPage(
            id: "kept-story",
            type: .narrativeOS,
            createdAt: now.addingTimeInterval(-300),
            promptText: "Story Page",
            userInput: "Penny caught the runaway index card beneath the west stair and promised not to file its secret name.",
            tags: ["story-page", "entity:penny-blackletter"],
            origin: .simulated
        )
        let earlierEcho = BookPage(
            id: "earlier-echo",
            type: .bookRemembered,
            createdAt: now.addingTimeInterval(-120),
            promptText: "The Book Remembered",
            userInput: "The west stair returned to the margin.",
            tags: ["meaningful-source:\(story.id)"],
            origin: .generated
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [story, earlierEcho])
        let surface = StudentNotePageGenerator.draftCandidate(
            for: sender,
            source: BookPageSourceRegistry.source(for: .note),
            day: day,
            inputs: .empty,
            now: now,
            semanticScorer: MeaningfulSurfaceTestScorer(phrase: "runaway index card")
        )

        XCTAssertEqual(surface.payload.metadata["meaningfulSourcePageID"], story.id)
        XCTAssertEqual(surface.payload.metadata["meaningfulSourcePageType"], BookPageType.narrativeOS.rawValue)
        XCTAssertEqual(surface.payload.metadata["noteSubjectKind"], "an event from kept fiction")
        XCTAssertTrue(surface.payload.metadata["meaningfulSourcePassage"]?.contains("runaway index card") == true)
        XCTAssertTrue(surface.payload.body.contains("speak of what happened in the fiction as an in-world event"))
    }

    func testContinuingLetterUsesSelectedPassageButIntroductionDoesNot() {
        let kept = authoredPage()
        let priorLetter = BookPage(
            id: "prior-letter",
            type: .letter,
            createdAt: now.addingTimeInterval(-2 * 86_400),
            promptText: "Letter from Penny",
            userInput: "Dear friend, I filed the rain by brightness.",
            tags: ["letter", "sender:penny-blackletter"],
            origin: .generated
        )
        var continuingInputs = BookSourceInputs.empty
        continuingInputs.days = [
            BookDay(id: BookDay.id(for: priorLetter.createdAt), date: priorLetter.createdAt, pages: [priorLetter]),
            BookDay(id: BookDay.id(for: kept.createdAt), date: kept.createdAt, pages: [kept])
        ]
        let continuing = CharacterLetterPageGenerator.draftCandidate(
            for: sender,
            source: BookPageSourceRegistry.source(for: .letter),
            day: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            inputs: continuingInputs,
            now: now,
            semanticScorer: MeaningfulSurfaceTestScorer(phrase: "porch light")
        )

        XCTAssertEqual(continuing.payload.metadata["letterRelationshipStage"], "continuing")
        XCTAssertEqual(continuing.payload.metadata["meaningfulSourcePageID"], kept.id)
        XCTAssertTrue(continuing.payload.body.contains("porch light"))

        var introductionInputs = BookSourceInputs.empty
        introductionInputs.days = [BookDay(id: BookDay.id(for: kept.createdAt), date: kept.createdAt, pages: [kept])]
        let introduction = CharacterLetterPageGenerator.draftCandidate(
            for: sender,
            source: BookPageSourceRegistry.source(for: .letter),
            day: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            inputs: introductionInputs,
            now: now,
            semanticScorer: MeaningfulSurfaceTestScorer(phrase: "porch light")
        )

        XCTAssertEqual(introduction.payload.metadata["letterRelationshipStage"], "introduction")
        XCTAssertNil(introduction.payload.metadata["meaningfulSourcePageID"])
        XCTAssertFalse(introduction.payload.body.contains("porch light"))
    }

    func testDailyBraidGetsPassageCompassWithoutDroppingFullDayEvidence() {
        let kept = authoredPage(daysAgo: 0)
        let other = BookPage(
            id: "other-keep",
            type: .souvenir,
            createdAt: now.addingTimeInterval(60),
            promptText: "One sentence",
            userInput: "The blue cup waited beside the window.",
            origin: .userAuthored
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [kept, other])
        let context = BraidPromptBuilder.context(
            for: day,
            days: [],
            semanticScorer: MeaningfulSurfaceTestScorer(phrase: "porch light"),
            now: now.addingTimeInterval(120)
        )
        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("MEANINGFUL PASSAGE COMPASS:"))
        XCTAssertTrue(prompt.contains("porch light"))
        XCTAssertTrue(prompt.contains("The blue cup waited beside the window."))
        XCTAssertTrue(prompt.contains("This compass chooses emphasis; it does not erase the other pages."))
    }

    func testMonthlyBraidCarriesInnerPassageCompassAndExcludesPrivateLogs() throws {
        let vivid = BookPage(
            id: "vivid-month-keep",
            type: .diary,
            createdAt: now.addingTimeInterval(-5 * 86_400),
            promptText: "What stayed?",
            userInput: "I put away the dishes. The wet red mitten on the bus seat kept pointing toward the empty door. I carried that small accusation home.",
            origin: .userAuthored
        )
        let braid = BraidPageDetails.annotated(
            BookPage(
                id: "month-braid",
                type: .bookOfYou,
                createdAt: now.addingTimeInterval(-4 * 86_400),
                promptText: "Book of You",
                userInput: "The Empty Seat\n\nThe bus carried one unanswered shape.\n\nThe Book kept the page: the door stayed possible.",
                tags: ["braid"],
                origin: .generated
            ),
            context: .empty
        )
        let privateFuel = BookPage(
            id: "private-fuel",
            type: .fuel,
            createdAt: now.addingTimeInterval(-3 * 86_400),
            promptText: "Fuel",
            userInput: "SENTINEL PRIVATE FUEL",
            origin: .userAuthored
        )
        let days = [vivid, braid, privateFuel].map { page in
            BookDay(id: BookDay.id(for: page.createdAt), date: page.createdAt, pages: [page])
        }
        let edition = MonthlyEditionBuilder.edition(
            from: days,
            readerName: "Reader",
            startDate: now.addingTimeInterval(-30 * 86_400),
            endDate: now,
            generatedAt: now
        )
        let prompt = try XCTUnwrap(BindingStoryPromptBuilder.monthly(for: edition)).prompt

        XCTAssertTrue(edition.passageCompass?.contains { $0.excerpt.contains("mitten") } == true)
        XCTAssertTrue(prompt.contains("READER-AUTHORED PASSAGE COMPASS:"))
        XCTAssertTrue(prompt.contains("mitten"))
        XCTAssertFalse(prompt.contains("SENTINEL PRIVATE FUEL"))
    }

    func testWeeklyIssueCarriesSelectedReaderPassageIntoBindingStory() throws {
        let firstKeepDate = now.addingTimeInterval(-8 * 86_400)
        let vivid = BookPage(
            id: "vivid-week-keep",
            type: .diary,
            createdAt: firstKeepDate,
            promptText: "What stayed?",
            userInput: "I put away the dishes. The wet red mitten on the bus seat kept pointing toward the empty door. I carried that small accusation home.",
            origin: .userAuthored
        )
        let braid = BraidPageDetails.annotated(
            BookPage(
                id: "week-braid",
                type: .bookOfYou,
                createdAt: firstKeepDate.addingTimeInterval(2 * 86_400),
                promptText: "Book of You",
                userInput: "The Empty Seat\n\nThe bus carried one unanswered shape.\n\nThe Book kept the page: the door stayed possible.",
                tags: ["braid"],
                origin: .generated
            ),
            context: .empty
        )
        let other = BookPage(
            id: "other-week-keep",
            type: .souvenir,
            createdAt: firstKeepDate.addingTimeInterval(86_400),
            promptText: "One sentence",
            userInput: "The bus window held a coin of afternoon light.",
            origin: .userAuthored
        )
        let days = [vivid, other, braid].map { page in
            BookDay(id: BookDay.id(for: page.createdAt), date: page.createdAt, pages: [page])
        }
        let issue = try XCTUnwrap(WeeklyIssue.current(days: days, now: now))
        let prompt = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue)).prompt

        XCTAssertTrue(issue.passageCompass?.contains { $0.excerpt.contains("mitten") } == true)
        XCTAssertTrue(prompt.contains("READER-AUTHORED PASSAGE COMPASS:"))
        XCTAssertTrue(prompt.contains("mitten"))
    }
}
