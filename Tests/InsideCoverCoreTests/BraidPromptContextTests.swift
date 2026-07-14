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
        XCTAssertTrue(prompt.contains("Write the braid in second-person past tense"))
        XCTAssertTrue(prompt.contains("Do not write second-person present tense"))
        XCTAssertTrue(prompt.contains("MONTHLY THEME THREAD"))
        XCTAssertTrue(prompt.contains(theme.promptLine))
        XCTAssertTrue(prompt.contains("CHAPTER WEATHER"))
        XCTAssertTrue(prompt.contains("Chapter Mossbloom"))
        XCTAssertTrue(prompt.contains("EARLIER PAGES OF THE BOOK OF YOU"))
        XCTAssertTrue(prompt.contains("brass key cooling on the sill"))
        XCTAssertTrue(prompt.contains("At most one image or motif from an earlier braid may return today"))
    }

    func testBookOfYouBraidUsesTheBooksOwnVoice() {
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
                )
            ]
        )

        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)

        XCTAssertTrue(prompt.contains("THE BOOK'S OWN VOICE"))
        XCTAssertTrue(prompt.contains("child-like animism, never childish"))
        XCTAssertTrue(prompt.contains("Give objects, rooms, weather, and pages little feelings and wants"))
        XCTAssertTrue(prompt.contains("The Book may be a little vulnerable"))
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
        XCTAssertTrue(annotated.tags.contains(BookOfYouResidue.markerTag))
        XCTAssertTrue(annotated.tags.contains("residue-title:Rain At The Window"))
        XCTAssertTrue(annotated.tags.contains("residue-motif:rain"))
        XCTAssertTrue(annotated.tags.contains("residue-motif:window"))
        XCTAssertEqual(details.residue?.callbackCandidate, "rain made the ordinary visible")
        XCTAssertEqual(details.residue?.title, "Rain At The Window")
    }

    func testAnnotatedBraidAddsReadableContextTagsAtTop() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = BookDay(id: "2026-06-16", date: date("2026-06-16T12:00:00Z"), pages: [])
        let page = BookPage(
            type: .bookOfYou,
            createdAt: date("2026-06-16T20:30:00Z"),
            promptText: "Book of You",
            userInput: """
            Rain At The Window

            You watched the rain gather on the glass.
            """
        )
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(phrase: "Current: Rain, 61F", source: "test")
        inputs.currentLocationLabel = "Home"
        inputs.nearbyPlaces = [
            LocalPlaceSignal(id: "books", name: "Left Bank Books", category: "bookstore", distanceLabel: "nearby", locality: "Belfast")
        ]
        inputs.facultyEntries = [
            FacultyEntry(
                kind: .fuel,
                dayID: day.id,
                createdAt: date("2026-06-16T19:00:00Z"),
                windowID: "evening",
                windowName: "Evening",
                rawText: "eggs and toast\n≈ 410 kcal · P 22g · C 31g · F 19g (Vellum's rough arithmetic)"
            ),
            FacultyEntry(
                kind: .innerWeather,
                dayID: day.id,
                createdAt: date("2026-06-16T19:30:00Z"),
                windowID: "evening",
                windowName: "Evening",
                rawText: "Static and rain."
            )
        ]
        let header = BraidPageDetails.HeaderContext.make(for: page, day: day, inputs: inputs, calendar: calendar)

        let annotated = BraidPageDetails.annotated(page, context: .empty, headerContext: header)
        let details = BraidPageDetails.details(for: annotated)

        XCTAssertTrue(annotated.userInput.hasPrefix("Tags: Time 8:30 PM · Location Home · Weather rain · Moon"))
        XCTAssertTrue(annotated.userInput.contains("Fuel ≈ 410 kcal · P 22g · C 31g · F 19g"))
        XCTAssertTrue(annotated.userInput.contains("Inner weather Static and rain."))
        XCTAssertFalse(annotated.userInput.contains("eggs and toast"))
        XCTAssertEqual(details.title, "Rain At The Window")
        XCTAssertTrue(details.body.hasPrefix("Tags: Time 8:30 PM · Location Home · Weather rain · Moon"))
        XCTAssertTrue(annotated.tags.contains("braid-time:8:30 PM"))
        XCTAssertTrue(annotated.tags.contains("braid-location:Home"))
        XCTAssertTrue(annotated.tags.contains("braid-weather:rain"))
        XCTAssertTrue(annotated.tags.contains { $0.hasPrefix("braid-moon:") })
        XCTAssertTrue(annotated.tags.contains("braid-fuel:≈ 410 kcal · P 22g · C 31g · F 19g"))
        XCTAssertTrue(annotated.tags.contains("braid-inner-weather:Static and rain."))
    }

    func testBraidHeaderNeverTreatsNearbyDiscoveryPlaceAsCurrentLocation() {
        let day = BookDay(
            id: "2026-06-16",
            date: date("2026-06-16T12:00:00Z"),
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: date("2026-06-16T18:00:00Z"),
                    promptText: "One true thing",
                    userInput: "The window was open.",
                    context: BookPageContextSnapshot(weatherTags: ["cloud"])
                )
            ]
        )
        let page = BookPage(
            type: .bookOfYou,
            createdAt: date("2026-06-16T20:30:00Z"),
            promptText: "Book of You",
            userInput: "Window\n\nYou left it open."
        )
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(id: "books", name: "Left Bank Books", category: "bookstore", distanceLabel: "nearby", locality: "Belfast")
        ]

        let header = BraidPageDetails.HeaderContext.make(for: page, day: day, inputs: inputs)

        XCTAssertEqual(header.locationLabel, "Current place")
        XCTAssertEqual(header.weatherWord, "cloud")
        XCTAssertFalse(header.displayLine.localizedCaseInsensitiveContains("unknown"))
        XCTAssertFalse(header.displayLine.contains("Left Bank Books"))
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

    func testBraidContextCarriesPriorResidueIntoMemorySpine() {
        let currentDay = BookDay(id: "2026-06-16", date: date("2026-06-16T20:30:00Z"), pages: [
            BookPage(
                type: .souvenir,
                createdAt: date("2026-06-16T08:00:00Z"),
                promptText: "One true thing",
                userInput: "The rain came back to the kitchen window."
            )
        ])
        let priorPage = BraidPageDetails.annotated(
            BookPage(
                id: "braid-rain",
                type: .bookOfYou,
                createdAt: date("2026-06-15T22:00:00Z"),
                promptText: "Book of You",
                userInput: """
                Lamp By The Glass

                The lamp waited by the window while rain worried the glass.

                The Book kept the page: rain made the lamp brave.
                """,
                tags: ["braid"]
            ),
            context: .empty
        )
        let priorDay = BookDay(id: "2026-06-15", date: date("2026-06-15T12:00:00Z"), pages: [priorPage])

        let context = BraidPromptBuilder.context(for: currentDay, days: [priorDay, currentDay], now: currentDay.date)
        let prompt = BraidPromptBuilder.prompt(for: currentDay, context: context)

        XCTAssertEqual(context.memoryDigest.braids.first?.pageID, "braid-rain")
        XCTAssertEqual(context.memoryDigest.strongestCallback, "rain made the lamp brave")
        XCTAssertTrue(context.memoryDigest.motifCounts.contains { $0.motif == "rain" })
        XCTAssertTrue(prompt.contains("BOOK MEMORY SPINE"))
        XCTAssertTrue(prompt.contains("Lamp By The Glass"))
        XCTAssertTrue(prompt.contains("rain made the lamp brave"))
        XCTAssertTrue(prompt.contains("You may let one prior residue return only if today's kept pages honestly answer it."))
    }

    func testBraidContextCarriesSemanticEchoesIntoResidue() {
        let echoLine = "Somewhere back in May you wrote \"The kettle sang twice\". Today's page answers it."
        let echoTags = SemanticKeepEcho.tags(for: SemanticKeepEcho.Echo(
            sourcePageID: "old-kettle",
            excerpt: "The kettle sang twice",
            monthLine: "back in May",
            similarity: 0.82,
            line: echoLine
        ))
        let currentDay = BookDay(id: "2026-06-16", date: date("2026-06-16T20:30:00Z"), pages: [
            BookPage(
                type: .souvenir,
                createdAt: date("2026-06-16T08:00:00Z"),
                promptText: "One true thing",
                userInput: "Something small waited all evening for my attention.",
                tags: echoTags
            )
        ])

        let context = BraidPromptBuilder.context(for: currentDay, days: [currentDay], now: currentDay.date)
        let prompt = BraidPromptBuilder.prompt(for: currentDay, context: context)
        let annotated = BraidPageDetails.annotated(
            BookPage(
                type: .bookOfYou,
                createdAt: date("2026-06-16T22:00:00Z"),
                promptText: "Book of You",
                userInput: """
                Kettle Answer

                The room listened while a small waiting thing finally got a name.

                The Book kept the page: the old kettle had been answered without using its words.
                """,
                tags: ["braid"]
            ),
            context: context
        )

        XCTAssertEqual(context.semanticEchoSourceIDs, ["old-kettle"])
        XCTAssertEqual(context.semanticEchoLines, [echoLine])
        XCTAssertTrue(prompt.contains("SEMANTIC ECHOES FROM TODAY"))
        XCTAssertTrue(prompt.contains(echoLine))
        XCTAssertTrue(annotated.tags.contains("\(BookOfYouResidue.semanticEchoPrefix)old-kettle"))
        XCTAssertEqual(BraidPageDetails.details(for: annotated).residue?.semanticEchoIDs, ["old-kettle"])
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
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
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
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
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

    func testBraidPromptNamesRequiredSouvenirSpineFromAnyPage() throws {
        let hourPage = BookPage(
            id: "hour-souvenir",
            type: .calendar,
            createdAt: date("2026-07-01T17:30:00Z"),
            promptText: "Hour Page: after",
            userInput: "The lobby clock ticked while I found my coat.",
            tags: ["calendar", "hour-page", "one-sentence-souvenir", "real-day"],
            origin: .userAuthored
        )
        let day = BookDay(id: "spine-day", date: date("2026-07-01T20:30:00Z"), pages: [
            BookPage(
                type: .narrativeOS,
                createdAt: date("2026-07-01T18:00:00Z"),
                promptText: "Story Page",
                userInput: "Wicker leaned on the ladder.",
                origin: .generated
            ),
            hourPage
        ])

        let anchor = try XCTUnwrap(BraidPromptBuilder.souvenirAnchor(in: day))
        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)

        XCTAssertEqual(anchor.pageID, "hour-souvenir")
        XCTAssertEqual(anchor.keptText, "The lobby clock ticked while I found my coat.")
        XCTAssertEqual(anchor.reason, "one-sentence souvenir kept from another page")
        XCTAssertTrue(prompt.contains("SOUVENIR SPINE (required):"))
        XCTAssertTrue(prompt.contains("from Hour Page"))
        XCTAssertTrue(prompt.contains("The lobby clock ticked while I found my coat."))
        XCTAssertTrue(prompt.contains("must be visible in the braid's opening"))
        XCTAssertTrue(prompt.contains("must return transformed in \"The Book kept the page:\""))
    }

    func testBraidTastingRoomScoresSouvenirSpine() throws {
        let day = BookDay(id: "taste-spine-day", date: date("2026-07-01T20:30:00Z"), pages: [
            BookPage(
                id: "souvenir",
                type: .souvenir,
                createdAt: date("2026-07-01T08:00:00Z"),
                promptText: "One sentence",
                userInput: "The kettle clicked awake before the rain.",
                origin: .userAuthored
            )
        ])
        let anchor = try XCTUnwrap(BraidPromptBuilder.souvenirAnchor(in: day))
        let context = BraidPromptBuilder.Context(souvenirAnchor: anchor)
        let weak = BookPage(
            type: .bookOfYou,
            promptText: "Book of You: A Soft Evening",
            userInput: """
            A Soft Evening

            You moved through the day and it felt meaningful.

            The Book kept the page: the ordinary became something to remember.
            """
        )
        let strong = BookPage(
            type: .bookOfYou,
            promptText: "Book of You: Kettle Before Rain",
            userInput: """
            Kettle Before Rain

            The kettle clicked awake before the room had decided what morning was.

            Later, the rain came to the glass, and even the story pages lowered their voices.

            The Book kept the page: the kettle and the rain found one small beginning.
            """
        )

        let weakScore = BraidTastingRoom.score(page: weak, context: context)
        let strongScore = BraidTastingRoom.score(page: strong, context: context)

        XCTAssertEqual(weakScore.souvenirSpine, 0)
        XCTAssertGreaterThan(strongScore.souvenirSpine, weakScore.souvenirSpine)
        XCTAssertGreaterThan(strongScore.total, weakScore.total)
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

    func testBraidPromptCarriesReaderLearningContextAsGuidance() {
        let day = BookDay(id: "learning-day", date: date("2026-07-01T20:30:00Z"), pages: [
            BookPage(type: .souvenir, promptText: "One line", userInput: "The porch light clicked on.", origin: .userAuthored)
        ])
        let context = BraidPromptBuilder.Context(
            readerLearningPromptLines: [
                "One-Sentence Souvenir is warming in the margins. 3 positive signals, 0 cooling signals."
            ]
        )

        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("LEARNED READER CONTEXT:"))
        XCTAssertTrue(prompt.contains("Use them only to choose emphasis, pacing, and restraint."))
        XCTAssertTrue(prompt.contains("One-Sentence Souvenir is warming"))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
