import XCTest
@testable import InsideCoverCore

final class BraidPromptContextTests: XCTestCase {
    func testBraidPromptCarriesTitleStoryShapeThemeChapterAndEarlierBraid() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T20:30:00Z"),
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: date("2026-06-16T08:00:00Z"),
                    promptText: "One true thing",
                    userInput: "The coffee cup sat beside the laptop while rain tapped the window.",
                    tags: ["morning"]
                )
            ]
        )
        let theme = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Rain and Lamps",
            motifs: ["rain", "lamps"],
            line: "Rain and Lamps ran under the month like a watermark.",
            strength: 42,
            evidencePageIDs: [],
            excerptLines: [],
            discoveredAt: day.date
        )
        let context = BraidPromptBuilder.Context(
            recentBraids: ["Yesterday's braid left a brass key cooling on the sill."],
            theme: theme,
            chapter: AcademyChapterRegistry.chapter(id: "mossbloom")
        )

        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("Silently choose a short title for the day"))
        XCTAssertTrue(prompt.contains("Once, Because, Until, And so, Kept"))
        XCTAssertTrue(prompt.contains("MONTHLY THEME THREAD"))
        XCTAssertTrue(prompt.contains(theme.promptLine))
        XCTAssertTrue(prompt.contains("CHAPTER WEATHER"))
        XCTAssertTrue(prompt.contains("Chapter Mossbloom"))
        XCTAssertTrue(prompt.contains("EARLIER PAGES OF THE BOOK OF YOU"))
        XCTAssertTrue(prompt.contains("brass key cooling on the sill"))
        XCTAssertTrue(prompt.contains("At most one image or motif from an earlier braid may return today"))
    }

    func testRecentBraidTextsSelectNewestAndOlderEchoWithoutCurrentDay() {
        let currentDay = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let days = (1...6).map { index in
            BookDay(
                id: "2026-06-\(String(format: "%02d", index))",
                date: date("2026-06-\(String(format: "%02d", index))T12:00:00Z"),
                pages: [
                    BookPage(
                        id: "braid-\(index)",
                        type: .bookOfYou,
                        promptText: "Braid",
                        userInput: "Braid \(index) carried a distinct image.",
                        tags: ["braid"]
                    )
                ]
            )
        } + [
            BookDay(
                id: currentDay.id,
                date: currentDay.date,
                pages: [
                    BookPage(type: .bookOfYou, promptText: "Braid", userInput: "Current day should not return.")
                ]
            )
        ]

        let recent = BraidPromptBuilder.recentBraidTexts(excludingDayID: currentDay.id, days: days)

        XCTAssertEqual(recent.count, 2)
        XCTAssertTrue(recent[0].contains("Braid 6"))
        XCTAssertTrue(recent[1].contains("Braid 2"))
        XCTAssertFalse(recent.joined().contains("Current day"))
    }

    func testBraidPromptWeightsUserSouvenirsAboveGeneratedFiction() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T20:30:00Z"),
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: date("2026-06-16T08:00:00Z"),
                    promptText: "One true thing",
                    userInput: "The coffee cup sat beside the laptop while rain tapped the window.",
                    origin: .userAuthored
                ),
                BookPage(
                    type: .narrativeOS,
                    createdAt: date("2026-06-16T12:00:00Z"),
                    promptText: "Story choice",
                    userInput: "Wicker opened a green door under the stairs.",
                    origin: .generated
                )
            ]
        )

        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)

        XCTAssertTrue(prompt.contains("TWO SHELVES"))
        XCTAssertTrue(prompt.contains("One-Sentence Souvenirs remain the strongest single spine candidates"))
        XCTAssertTrue(prompt.contains("the lived shelf wins"))
        XCTAssertTrue(prompt.contains("reader-authored anchor; one-sentence souvenir; highest gravity"))
        XCTAssertTrue(prompt.contains("Shelf: lived"))
        XCTAssertTrue(prompt.contains("Shelf: fiction"))
        XCTAssertTrue(prompt.contains("generated fiction color; medium gravity"))
    }

    func testBraidPromptUpgradesGeneratedFictionWhenReaderReplies() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T20:30:00Z"),
            pages: [
                BookPage(
                    type: .narrativeOS,
                    createdAt: date("2026-06-16T12:00:00Z"),
                    promptText: "Story choice",
                    userInput: "The corridor offered three doors.",
                    playerReply: "I chose the blue door because it felt honest.",
                    origin: .generated
                )
            ]
        )

        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)

        XCTAssertTrue(prompt.contains("reader-endorsed fiction; high gravity - the reader made a real decision here"))
        XCTAssertTrue(prompt.contains("Reader reply: I chose the blue door because it felt honest."))
        XCTAssertTrue(prompt.contains("it may carry the spine when the day's truest turn happened there"))
    }

    func testAnnotatedBraidKeepsTitleAndContextTags() {
        let page = BookPage(
            type: .bookOfYou,
            promptText: "The Book braided today.",
            userInput: """
            Rain At The Window

            The cup waited beside the laptop while the room listened.

            The Book kept the page: rain made the ordinary visible.
            """,
            tags: ["braid"]
        )
        let theme = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Rain and Lamps",
            motifs: ["rain", "lamps"],
            line: "Rain and Lamps ran under the month like a watermark.",
            strength: 42,
            evidencePageIDs: [],
            excerptLines: [],
            discoveredAt: date("2026-06-16T12:00:00Z")
        )
        let context = BraidPromptBuilder.Context(
            recentBraids: ["Yesterday had a brass key."],
            theme: theme,
            chapter: AcademyChapterRegistry.chapter(id: "mossbloom")
        )

        let annotated = BraidPageDetails.annotated(page, context: context)
        let details = BraidPageDetails.details(for: annotated)

        XCTAssertEqual(details.title, "Rain At The Window")
        XCTAssertFalse(details.body.contains("Rain At The Window"))
        XCTAssertEqual(annotated.promptText, "Book of You: Rain At The Window")
        XCTAssertEqual(annotated.promptVersion, BraidPageDetails.promptVersion)
        XCTAssertTrue(annotated.tags.contains("braid-v2"))
        XCTAssertTrue(annotated.tags.contains("theme:Rain and Lamps"))
        XCTAssertTrue(annotated.tags.contains("chapter:Mossbloom"))
        XCTAssertTrue(annotated.tags.contains("yesterday-echo"))
    }

    func testBraidContextFindsThemeAndAscendantChapter() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let prior = BookDay(
            id: "2026-06-15",
            date: date("2026-06-15T12:00:00Z"),
            pages: [
                BookPage(type: .bookOfYou, promptText: "Braid", userInput: "A prior braid carried a window.")
            ]
        )
        let theme = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Windows and Keys",
            motifs: ["windows", "keys"],
            line: "Windows and Keys stood in the running head.",
            strength: 33,
            evidencePageIDs: [],
            excerptLines: [],
            discoveredAt: day.date
        )

        let context = BraidPromptBuilder.context(
            for: day,
            days: [prior, day],
            themes: [theme],
            entityBeliefOffsets: ["moss-clasp": 90]
        )

        XCTAssertEqual(context.recentBraids.count, 1)
        XCTAssertEqual(context.theme?.name, "Windows and Keys")
        XCTAssertEqual(context.chapter?.id, "mossbloom")
    }

    func testBraidTastingRoomRanksStrongerVariantFirst() {
        let theme = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Rain and Lamps",
            motifs: ["rain", "lamps"],
            line: "Rain and Lamps stood at the edge of the month.",
            strength: 42,
            evidencePageIDs: [],
            excerptLines: [],
            discoveredAt: date("2026-06-16T12:00:00Z")
        )
        let context = BraidPromptBuilder.Context(
            recentBraids: ["Yesterday left a brass key cooling on the sill."],
            theme: theme,
            chapter: AcademyChapterRegistry.chapter(id: "mossbloom")
        )
        let strong = BookPage(
            id: "strong",
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Rain At The Window

            Once, the coffee cup waited beside the laptop while rain tapped the window and made the room small enough to hold.

            Because the day wanted a gentler door, the charger, the lamp, and the old brass key on the sill became a little parliament of ordinary things.

            Until evening, the window kept returning the same answer in different light: carry one task, not the whole storm.

            And so the page did not crown the day or explain it. It let the small moss-bright patience remain where the hand could find it.

            The Book kept the page: a cup, a key, and rain taught the room to wait.
            """,
            tags: ["braid"]
        )
        let weak = BookPage(
            id: "weak",
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Today's Journey

            Today was a profound journey full of hidden meaning and magic.

            The day was meaningful and inspiring.

            The Book kept the page: everything mattered.
            """,
            tags: ["braid"]
        )

        let result = BraidTastingRoom.taste([weak, strong], context: context)

        XCTAssertEqual(result.winner?.page.id, "strong")
        XCTAssertGreaterThan(
            result.samples.first { $0.page.id == "strong" }!.score.total,
            result.samples.first { $0.page.id == "weak" }!.score.total
        )
    }

    func testBraidTastingRoomRewardsSubtleThemeAndChapterInfluence() {
        let theme = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Rain and Lamps",
            motifs: ["rain", "lamps"],
            line: "Rain and Lamps stood at the edge of the month.",
            strength: 42,
            evidencePageIDs: [],
            excerptLines: [],
            discoveredAt: date("2026-06-16T12:00:00Z")
        )
        let context = BraidPromptBuilder.Context(
            theme: theme,
            chapter: AcademyChapterRegistry.chapter(id: "mossbloom")
        )
        let subtle = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            The Patient Lamp

            Once, the lamp stayed on by the cup while the window kept its weather to itself.

            Because the day asked for a slower hand, the page noticed what could grow without being hurried.

            Until the last task moved, the room held its little threshold.

            And so the night left patience on the table.

            The Book kept the page: the lamp waited, and the hand did not rush.
            """
        )
        let explicit = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Rain And Lamps Lesson

            Chapter Mossbloom and the monthly theme Rain and Lamps influenced this braid.

            Because Rain and Lamps was the theme, rain and lamps were important.

            The Book kept the page: the chapter and theme were present.
            """
        )

        let subtleScore = BraidTastingRoom.score(page: subtle, context: context)
        let explicitScore = BraidTastingRoom.score(page: explicit, context: context)

        XCTAssertGreaterThan(subtleScore.themeAndChapter, explicitScore.themeAndChapter)
    }

    func testBraidLearningLoopTurnsWeakTastingIntoPromptGuidance() {
        let weak = BookPage(
            id: "weak",
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Today's Journey

            Today was a profound journey full of hidden meaning.

            The day mattered.
            """,
            tags: ["braid"]
        )
        let sample = BraidTastingRoom.taste([weak]).winner!
        let observation = BraidLearningLoop.Observation(
            selected: sample,
            acceptedByReader: false,
            editedText: """
            Cup Beside The Window

            Once, the cup waited by the window.

            Because the room needed one small thing to hold, the lamp stayed on.

            Until the rain stopped, the page kept its hand on the ordinary.

            The Book kept the page: a cup and window taught the room to wait.
            """
        )

        let guidance = BraidLearningLoop.guidance(from: [observation])
        let notes = guidance.promptLines.joined(separator: "\n")

        XCTAssertTrue(notes.contains("The Book kept the page"))
        XCTAssertTrue(notes.contains("old-tale turn"))
        XCTAssertTrue(notes.contains("ordinary enchanted objects"))
        XCTAssertTrue(notes.contains("clinical diction"))
    }

    func testBraidPromptCarriesLearnedGuidance() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T20:30:00Z"),
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: date("2026-06-16T08:00:00Z"),
                    promptText: "One true thing",
                    userInput: "The coffee cup sat beside the laptop while rain tapped the window."
                )
            ]
        )
        let guidance = BraidLearningGuidance(signals: [
            .init(
                dimension: "keeperSentence",
                weight: 12,
                note: "End with exactly one memorable sentence beginning 'The Book kept the page:'."
            )
        ])
        let context = BraidPromptBuilder.Context(learnedGuidance: guidance)

        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("LEARNED BRAID TASTE"))
        XCTAssertTrue(prompt.contains("End with exactly one memorable sentence"))
        XCTAssertTrue(prompt.contains("Treat these as local taste notes"))
    }

    func testBraidContextLearnsFromMissedMePriorPages() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let prior = BookDay(
            id: "2026-06-15",
            date: date("2026-06-15T12:00:00Z"),
            pages: [
                BookPage(
                    type: .bookOfYou,
                    promptText: "Book of You",
                    userInput: """
                    Today's Journey

                    Today was a profound journey full of hidden meaning.

                    The day mattered.
                    """,
                    tags: ["braid", BraidLearningLoop.missedMeTag]
                )
            ]
        )

        let context = BraidPromptBuilder.context(for: day, days: [prior, day])
        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertNotNil(context.learnedGuidance)
        XCTAssertTrue(prompt.contains("LEARNED BRAID TASTE"))
        XCTAssertTrue(prompt.contains("clinical diction"))
    }

    func testBraidContextDoesNotLearnPressureFromLovedPriorPages() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let prior = BookDay(
            id: "2026-06-15",
            date: date("2026-06-15T12:00:00Z"),
            pages: [
                BookPage(
                    type: .bookOfYou,
                    promptText: "Book of You",
                    userInput: """
                    Cup Beside The Window

                    Once, the cup waited by the window.

                    The Book kept the page: a cup and window taught the room to wait.
                    """,
                    tags: ["braid", BraidLearningLoop.lovedItTag]
                )
            ]
        )

        let context = BraidPromptBuilder.context(for: day, days: [prior, day])

        XCTAssertNil(context.learnedGuidance)
    }

    func testBraidLearningPublicLessonNamesWhatChanged() {
        let page = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Today's Journey

            Today was a profound journey full of hidden meaning.

            The day mattered.
            """,
            tags: ["braid", BraidLearningLoop.missedMeTag]
        )

        let lesson = BraidLearningLoop.publicLesson(for: page)

        XCTAssertFalse(lesson.contains("score"))
        XCTAssertTrue(lesson.contains("Book learned"))
        XCTAssertTrue(
            lesson.contains("truer details") ||
                lesson.contains("stronger final line") ||
                lesson.contains("clearer turn")
        )
    }

    // MARK: - Gemma in the loop

    func testReaderTaughtNotesLeadLearnedGuidanceInPrompt() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let prior = BookDay(
            id: "2026-06-15",
            date: date("2026-06-15T12:00:00Z"),
            pages: [
                BookPage(
                    type: .bookOfYou,
                    promptText: "Book of You",
                    userInput: "Today was a profound journey full of hidden meaning.",
                    tags: ["braid", BraidLearningLoop.missedMeTag]
                )
            ]
        )
        let notes = ["Stay closer to what my hands actually did.", "Let the evening hold the final line."]

        let context = BraidPromptBuilder.context(for: day, days: [prior, day], learnedNotes: notes)
        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        // The reader-taught notes are present and sort ahead of heuristics.
        XCTAssertTrue(prompt.contains("Stay closer to what my hands actually did."))
        XCTAssertEqual(context.learnedGuidance?.promptLines.first, "Let the evening hold the final line.")
    }

    func testReaderTaughtNotesIgnoreBlankEntries() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let context = BraidPromptBuilder.context(for: day, days: [day], learnedNotes: ["   ", ""])
        XCTAssertNil(context.learnedGuidance)
    }

    func testRewritePromptCarriesPriorDraftAndWeakNotes() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T20:30:00Z"),
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: date("2026-06-16T08:00:00Z"),
                    promptText: "One true thing",
                    userInput: "The coffee cup sat beside the laptop while rain tapped the window."
                )
            ]
        )
        let prior = "Today was a profound journey full of hidden meaning."
        let weak = ["Trade abstract wonder for ordinary enchanted objects: cups, keys, windows."]

        let prompt = BraidPromptBuilder.rewritePrompt(for: day, priorBraid: prior, weakNotes: weak, context: .empty)

        XCTAssertTrue(prompt.contains("Rewrite it truer"))
        XCTAssertTrue(prompt.contains(prior))
        XCTAssertTrue(prompt.contains("WHAT MISSED LAST TIME"))
        XCTAssertTrue(prompt.contains("ordinary enchanted objects"))
        // It reuses the full braid craft spec.
        XCTAssertTrue(prompt.contains("KEPT PAGES FROM TODAY"))
    }

    func testTasteNotePromptAsksForOneSecondPersonLine() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T20:30:00Z"),
            pages: [
                BookPage(
                    type: .diary,
                    createdAt: date("2026-06-16T09:00:00Z"),
                    promptText: "Diary",
                    userInput: "Walked to the harbor and watched the fog lift off the water."
                )
            ]
        )
        let prompt = BraidPromptBuilder.tasteNotePrompt(
            for: day, priorBraid: "A profound journey of hidden meaning.", weakNotes: [], context: .empty
        )

        XCTAssertTrue(prompt.contains("missed them"))
        XCTAssertTrue(prompt.contains("exactly one second-person instruction"))
        XCTAssertTrue(prompt.contains("harbor"))
    }

    func testWeakDimensionNotesNameGenericBraidsProblems() {
        let weakPage = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Today's Journey

            Today was a profound journey full of hidden meaning and a tapestry of echoes.

            The day mattered.
            """
        )

        let notes = BraidLearningLoop.weakDimensionNotes(for: weakPage)

        XCTAssertFalse(notes.isEmpty)
        XCTAssertTrue(notes.contains { $0.contains("generic") || $0.contains("ordinary enchanted objects") || $0.contains("memorable sentence") })
    }

    // MARK: - Radio atmosphere

    func testRadioAtmosphereSectionIsEmptyWhenSilent() {
        XCTAssertEqual(RadioAtmosphere.promptSection(nil), "")
        XCTAssertEqual(RadioAtmosphere.promptSection(""), "")
    }

    func testRadioAtmosphereSectionCarriesStationAndSoftRule() {
        let section = RadioAtmosphere.promptSection("Thornwave (103.7) — dark faerie lo-fi")
        XCTAssertTrue(section.contains("WHAT'S PLAYING"))
        XCTAssertTrue(section.contains("Thornwave (103.7)"))
        XCTAssertTrue(section.contains("faintly color"))
        XCTAssertTrue(section.contains("never as a thesis") || section.contains("Do not name the station"))
    }

    func testTunedStationProducesAtmosphereLine() {
        let line = RadioStationRegistry.atmosphereLine(state: RadioPlaybackState(activeStationID: "thornwave"))
        XCTAssertEqual(line, "Thornwave (103.7) — Bramble bass, broken-glass garage, and bargains struck in the low end after midnight.")
        XCTAssertNil(RadioStationRegistry.atmosphereLine(state: .off))
    }

    func testRadioAtmosphereLineCarriesWorldEventPressure() {
        let events = WorldEventResolver.activeEvents(now: date("2026-09-10T12:00:00Z"))

        let line = RadioStationRegistry.atmosphereLine(state: .off, worldEvents: events)

        XCTAssertTrue(line?.contains("The Dictionary Rebellion") == true)
        XCTAssertTrue(line?.contains("loose words are interrupting") == true)
    }

    func testBraidPromptCarriesNowPlaying() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T20:30:00Z"), pages: [])
        let context = BraidPromptBuilder.Context(nowPlaying: "Mothlight Beats (90.9) — wistful fae-fi")

        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("WHAT'S PLAYING"))
        XCTAssertTrue(prompt.contains("Mothlight Beats (90.9)"))
    }

    func testBraidPromptCarriesWorldEventPressure() {
        let day = BookDay(
            id: "2026-09-10",
            date: date("2026-09-10T20:30:00Z"),
            pages: [
                BookPage(
                    type: .souvenir,
                    promptText: "One true thing",
                    userInput: "The word ordinary felt different after dinner."
                )
            ]
        )
        let events = WorldEventResolver.activeEvents(now: date("2026-09-10T20:30:00Z"), day: day)
        let context = BraidPromptBuilder.Context(activeWorldEvents: events)

        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("WORLD EVENT PRESSURE"))
        XCTAssertTrue(prompt.contains("The Dictionary Rebellion"))
        XCTAssertTrue(prompt.contains("Let this pressure color the Book of You only when today's kept pages honestly invite it."))
    }

    func testBraidPromptOmitsAtmosphereWhenSilent() {
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T20:30:00Z"), pages: [])
        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)
        XCTAssertFalse(prompt.contains("WHAT'S PLAYING"))
    }

    func testBraidPromptCarriesTwoShelves() {
        let day = BookDay(id: "shelves-day", date: date("2026-07-01T20:30:00Z"), pages: [
            BookPage(type: .souvenir, createdAt: date("2026-07-01T08:00:00Z"), promptText: "One line", userInput: "The kettle sang early.", origin: .userAuthored),
            BookPage(type: .narrativeOS, createdAt: date("2026-07-01T18:00:00Z"), promptText: "Story Page", userInput: "Wicker leaned on the ladder.", playerReply: "Named the forgery", origin: .generated)
        ])
        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)
        XCTAssertTrue(prompt.contains("TWO SHELVES:"))
        XCTAssertFalse(prompt.contains("PROVENANCE GRAVITY"))
        XCTAssertTrue(prompt.contains("Shelf: lived"))
        XCTAssertTrue(prompt.contains("Shelf: fiction"))
        XCTAssertTrue(prompt.contains("reader-endorsed fiction; high gravity"))
    }

    func testBraidShelfClassification() {
        XCTAssertEqual(BraidPromptBuilder.braidShelf(for: BookPage(type: .souvenir, promptText: "p", origin: .userAuthored)), "lived")
        XCTAssertEqual(BraidPromptBuilder.braidShelf(for: BookPage(type: .diary, promptText: "p", origin: .imported)), "lived")
        XCTAssertEqual(BraidPromptBuilder.braidShelf(for: BookPage(type: .narrativeOS, promptText: "p", origin: .generated)), "fiction")
    }

    func testBraidPromptHingesOnClashPages() {
        let clashPage = BookPage(type: .narrativeOS, createdAt: date("2026-07-01T18:00:00Z"), promptText: "Clash", userInput: "The grey edited the list.",
                                 tags: ["clash", "clash:grey-edit", "choice:progressarc", "clash-outcome:costly-success"], origin: .generated)
        let day = BookDay(id: "clash-day", date: date("2026-07-01T20:30:00Z"), pages: [clashPage])
        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)
        XCTAssertTrue(prompt.contains("WHERE BELIEF WAS TESTED:"))
        XCTAssertTrue(prompt.contains("Clash digest: Belief was tested (grey-edit)"))

        let quietDay = BookDay(id: "quiet-day", date: date("2026-07-01T20:30:00Z"), pages: [
            BookPage(type: .souvenir, promptText: "One line", userInput: "The kettle sang.", origin: .userAuthored)
        ])
        XCTAssertFalse(BraidPromptBuilder.prompt(for: quietDay, context: .empty).contains("WHERE BELIEF WAS TESTED"))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
