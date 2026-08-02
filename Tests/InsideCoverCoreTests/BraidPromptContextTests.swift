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
        XCTAssertTrue(prompt.contains("TONIGHT'S TALE READING"))
        XCTAssertTrue(prompt.contains("Narrative motion:"))
        XCTAssertTrue(prompt.contains("Write in second-person past tense"))
        XCTAssertTrue(prompt.contains("Do not force Once/Because/Until beats"))
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

        XCTAssertTrue(prompt.contains("half-feral child, never cute"))
        XCTAssertTrue(prompt.contains("Short sentences, contractions"))
        XCTAssertTrue(prompt.contains("at least one ordinary thing must act on its own"))
        XCTAssertTrue(prompt.contains("The kettle's sulking."))
        XCTAssertTrue(prompt.contains("Never soothe, reassure, bless, lecture, moralize, give wisdom"))
        XCTAssertFalse(prompt.contains("wise underneath"))
        XCTAssertTrue(prompt.contains("exactly one object gets that agency"))
        XCTAssertTrue(prompt.contains("One live thing hits harder than a parade"))
    }

    func testBookOfYouBraidCarriesThisReadersPatinaWithoutReplacingBookCanon() {
        let now = date("2026-07-20T20:00:00Z")
        let pages = (0..<8).map { index in
            BookPage(
                id: "patina-\(index)",
                type: .souvenir,
                createdAt: now.addingTimeInterval(TimeInterval(-(60 + index * 4) * 86_400)),
                promptText: "Keep one true thing.",
                userInput: "The violet sprocket turned beside the copper observatory while the paper comet refused its appointment!"
            )
        }
        let patina = BookVoicePatina.derive(
            days: [BookDay(id: "archive", date: now, pages: pages)],
            now: now
        )
        let tonight = BookDay(
            id: "tonight",
            date: now,
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: now,
                    promptText: "One true thing",
                    userInput: "A red cup waited beside the open window."
                )
            ]
        )

        let prompt = BraidPromptBuilder.prompt(
            for: tonight,
            context: BraidPromptBuilder.Context(bookVoicePatina: patina)
        )

        XCTAssertTrue(prompt.contains("THE BOOK'S PATINA"))
        XCTAssertTrue(prompt.contains("attention returns to"))
        XCTAssertTrue(prompt.contains("sprocket"))
        XCTAssertTrue(prompt.contains("words that repeatedly keep company"))
        XCTAssertTrue(prompt.contains("You are still the Book described by THE BOOK AS A CHARACTER"))
        XCTAssertTrue(prompt.contains("Never insert any unsupplied object"))
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

    func testDailyLogsStayRequiredButCannotOwnBraidWhenOtherMaterialExists() {
        let day = BookDay(
            id: "2026-07-14",
            date: date("2026-07-14T20:30:00Z"),
            pages: [
                BookPage(
                    type: .weather,
                    createdAt: date("2026-07-14T07:00:00Z"),
                    promptText: "Weather Page",
                    userInput: "Rain leaned on the windows.",
                    origin: .imported,
                    privacy: .publicReference
                ),
                BookPage(
                    type: .body,
                    createdAt: date("2026-07-14T08:00:00Z"),
                    promptText: "Body Page",
                    userInput: "Low energy this morning.",
                    origin: .userAuthored,
                    privacy: .localSensitive
                ),
                BookPage(
                    type: .mood,
                    createdAt: date("2026-07-14T09:00:00Z"),
                    promptText: "Inner Weather",
                    userInput: "Restless, then clearing.",
                    origin: .userAuthored,
                    privacy: .localSensitive
                ),
                BookPage(
                    type: .diary,
                    createdAt: date("2026-07-14T18:00:00Z"),
                    promptText: "What happened?",
                    userInput: "I finally repaired the blue chair by the kitchen door.",
                    origin: .userAuthored
                )
            ]
        )

        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)

        XCTAssertTrue(prompt.contains("SUPPORTING DAILY LOGS (context, not required prose)"))
        XCTAssertTrue(prompt.contains("Present tonight: Weather, Body, Inner Weather."))
        XCTAssertTrue(prompt.contains("notice a log without repeating it"))
        XCTAssertTrue(prompt.contains("Mention a log only if it materially changes what happened"))
        XCTAssertTrue(prompt.contains("may not supply the title, spine, turn, or final kept image"))
        XCTAssertEqual(prompt.components(separatedBy: "supporting daily log; may remain invisible").count - 1, 3)
        XCTAssertEqual(prompt.components(separatedBy: "supporting context; required but deliberately lower gravity").count - 1, 3)
        XCTAssertTrue(prompt.contains("spine-eligible kept material"))
    }

    func testSupportingLogsDoNotEnterMeaningfulPassageCompass() {
        let day = BookDay(
            id: "2026-07-14",
            date: date("2026-07-14T20:30:00Z"),
            pages: [
                BookPage(
                    type: .mood,
                    createdAt: date("2026-07-14T09:00:00Z"),
                    promptText: "Inner Weather restless clearing restless clearing",
                    userInput: "Restless clearing restless clearing, with static under every thought and a long gray pause.",
                    tags: ["restless", "clearing", "static"],
                    origin: .userAuthored,
                    privacy: .localSensitive
                ),
                BookPage(
                    type: .diary,
                    createdAt: date("2026-07-14T18:00:00Z"),
                    promptText: "Blue chair kitchen repair",
                    userInput: "I repaired the blue chair beside the kitchen door and kept the loose brass screw in a saucer.",
                    tags: ["blue", "chair", "kitchen", "repair"],
                    origin: .userAuthored
                )
            ]
        )

        let context = BraidPromptBuilder.context(
            for: day,
            days: [day],
            now: date("2026-07-14T21:00:00Z")
        )

        XCTAssertFalse(context.meaningfulSpinePassages.contains { $0.pageType == .mood })
        XCTAssertTrue(context.meaningfulSpinePassages.allSatisfy { !BraidPromptBuilder.supportingLogTypes.contains($0.pageType) })
    }

    func testRoutineLogMotifsDoNotReinforceThemselvesThroughBraidMemory() {
        let residue = BookOfYouResidue(
            title: "Rain Again",
            spineLine: "Rain waited at the glass.",
            keptLine: "The Book kept the page: the lamp stayed on.",
            motifs: ["rain", "lamp"],
            semanticEchoIDs: [],
            openedQuestion: nil,
            callbackCandidate: nil
        )
        let digest = BindingMemoryDigest(
            braids: [
                BindingMemoryDigest.BraidMemory(
                    pageID: "prior-braid",
                    date: date("2026-07-13T20:30:00Z"),
                    residue: residue
                )
            ],
            motifCounts: [
                BindingMemoryDigest.MotifCount(motif: "rain", count: 7),
                BindingMemoryDigest.MotifCount(motif: "lamp", count: 2)
            ],
            strongestCallback: nil
        )
        let day = BookDay(id: "2026-07-14", date: date("2026-07-14T20:30:00Z"), pages: [
            BookPage(type: .diary, promptText: "Today", userInput: "I fixed the blue chair.", origin: .userAuthored)
        ])

        let prompt = BraidPromptBuilder.prompt(for: day, context: BraidPromptBuilder.Context(memoryDigest: digest))

        XCTAssertTrue(prompt.contains("Recurring braid motifs: lamp x2"))
        XCTAssertFalse(prompt.contains("rain x7"))
        XCTAssertTrue(prompt.contains("Repeated Weather, Body, and Inner Weather readings are routine context, not callbacks"))
    }

    func testFallbackBraidPartitionKeepsLogsOutOfTheStoryOpeningPool() {
        let day = BookDay(
            id: "2026-07-14",
            date: date("2026-07-14T20:30:00Z"),
            pages: [
                BookPage(type: .weather, createdAt: date("2026-07-14T07:00:00Z"), promptText: "Weather", userInput: "rain at the glass", origin: .imported),
                BookPage(type: .body, createdAt: date("2026-07-14T08:00:00Z"), promptText: "Body", userInput: "heavy shoulders", origin: .userAuthored),
                BookPage(type: .mood, createdAt: date("2026-07-14T09:00:00Z"), promptText: "Inner Weather", userInput: "restless static", origin: .userAuthored),
                BookPage(type: .diary, createdAt: date("2026-07-14T18:00:00Z"), promptText: "Today", userInput: "the blue chair was repaired", origin: .userAuthored)
            ]
        )

        let partition = BraidPromptBuilder.partitionedPagesForBraid(in: day)

        XCTAssertEqual(partition.story.map(\.type), [.diary])
        XCTAssertEqual(partition.story.first?.userInput, "the blue chair was repaired")
        XCTAssertEqual(partition.supportingLogs.map(\.type), [.weather, .body, .mood])
    }

    func testBraidEvidenceExcludesWelcomeAndHelpFurniture() {
        let day = BookDay(
            id: "2026-07-14",
            date: date("2026-07-14T20:30:00Z"),
            pages: [
                BookPage(
                    type: .welcome,
                    createdAt: date("2026-07-14T07:00:00Z"),
                    promptText: "Welcome",
                    userInput: "Hello, bj. The Labyrinth explains the Book.",
                    origin: .generated
                ),
                BookPage(
                    type: .helpTips,
                    createdAt: date("2026-07-14T08:00:00Z"),
                    promptText: "How the Book works",
                    userInput: "A useful setup margin note.",
                    origin: .generated
                ),
                BookPage(
                    type: .souvenir,
                    createdAt: date("2026-07-14T18:00:00Z"),
                    promptText: "Keep one sentence",
                    userInput: "I should have gone to the lake with her.",
                    origin: .userAuthored
                )
            ]
        )

        let partition = BraidPromptBuilder.partitionedPagesForBraid(in: day)
        let evidence = BraidPromptBuilder.evidenceLines(for: day).joined(separator: "\n")

        XCTAssertEqual(partition.story.map(\.type), [.souvenir])
        XCTAssertFalse(evidence.contains("The Labyrinth explains"))
        XCTAssertFalse(evidence.contains("setup margin note"))
        XCTAssertTrue(evidence.contains("I should have gone to the lake"))
    }

    /// The packet's character budget has to bind on exactly the days that
    /// threaten the prompt: heavy ones. A per-page floor stacked on top of the
    /// total used to win past roughly fifteen pages, so a busy day spent far
    /// more than its budget and the ceiling meant nothing where it mattered.
    func testEvidencePacketBudgetBindsOnAHeavyDay() {
        let body = String(
            repeating: "The rain kept tapping the window while the kettle sulked on the back burner. ",
            count: 8
        )
        let day = BookDay(
            id: "2026-07-14",
            date: date("2026-07-14T20:00:00Z"),
            pages: (0 ..< 25).map { index in
                BookPage(
                    type: .diary,
                    createdAt: date("2026-07-14T08:00:00Z").addingTimeInterval(Double(index) * 1800),
                    promptText: "What did the day hand you at this hour?",
                    userInput: body,
                    tags: ["kept", "rain"],
                    origin: .userAuthored
                )
            }
        )

        let tight = BraidPromptBuilder.evidenceLines(for: day, totalCharacterBudget: 3_600)
            .joined(separator: "\n\n")
        let generous = BraidPromptBuilder.evidenceLines(for: day, totalCharacterBudget: 7_200)
            .joined(separator: "\n\n")

        // The packet is a budget, not a guarantee of universal representation.
        // A day heavier than the budget can seat drops its weakest pages rather
        // than shrinking every slot until nobody's words survive clipping.
        let tightSlots = tight.components(separatedBy: "\n\n").count
        XCTAssertLessThanOrEqual(tightSlots, 25)
        XCTAssertEqual(
            tightSlots,
            BraidPromptBuilder.evidenceCapacity(totalCharacterBudget: 3_600),
            "A heavy day fills exactly the seats the budget can pay for."
        )
        XCTAssertLessThan(
            tight.count,
            generous.count,
            "A smaller packet budget must produce a smaller packet."
        )
        XCTAssertLessThan(tight.count, 6_000, "A 25-page day must not spend 8,000 characters again.")
    }

    /// Empty fields cost as much as full ones once every page carries nine
    /// labels, and "Reader reply: none" tells the Book nothing.
    func testEvidenceLinesOmitAbsentFieldsButKeepPresentOnes() {
        let day = BookDay(
            id: "2026-07-14",
            date: date("2026-07-14T20:00:00Z"),
            pages: [
                BookPage(
                    type: .diary,
                    createdAt: date("2026-07-14T08:00:00Z"),
                    promptText: "What did the day hand you?",
                    userInput: "The coat by the door stayed dark at the shoulders all morning.",
                    origin: .userAuthored
                )
            ]
        )

        let evidence = BraidPromptBuilder.evidenceLines(for: day).joined(separator: "\n")

        XCTAssertFalse(evidence.contains("Reader reply:"))
        XCTAssertFalse(evidence.contains("Visual evidence:"))
        XCTAssertFalse(evidence.contains("Tags:"))
        XCTAssertTrue(evidence.contains("Kept text: The coat by the door"))
        XCTAssertTrue(evidence.contains("Shelf: lived"))
    }

    func testFallbackExcerptRetreatsToAWholeWordBoundary() {
        let excerpt = BraidPromptBuilder.fallbackExcerpt(
            "the labyrinth welcoming the reader into the Book",
            limit: 20
        )

        XCTAssertEqual(excerpt, "the labyrinth…")
        XCTAssertFalse(excerpt.contains("welcom…"))
    }

    func testTaleCabinetReadsRepairAndSelectiveAgencyFromSuppliedDay() {
        let day = BookDay(
            id: "2026-07-18",
            date: date("2026-07-18T20:30:00Z"),
            pages: [
                BookPage(
                    type: .diary,
                    createdAt: date("2026-07-18T18:00:00Z"),
                    promptText: "What changed?",
                    userInput: "I repaired the blue chair by the kitchen door and put its loose brass screw in a saucer.",
                    origin: .userAuthored
                )
            ]
        )

        let reading = BraidPromptBuilder.taleReading(for: day)
        let prompt = BraidPromptBuilder.prompt(
            for: day,
            context: BraidPromptBuilder.Context(taleReading: reading)
        )

        XCTAssertEqual(reading.scale, .glimpse)
        XCTAssertEqual(reading.motion, .repair)
        XCTAssertEqual(reading.pressure, .agency)
        XCTAssertTrue(reading.anchor.contains("blue chair"))
        XCTAssertTrue(reading.turn?.contains("repaired") == true)
        XCTAssertTrue(prompt.contains("REPAIR — care altered"))
        XCTAssertTrue(prompt.contains("AGENCY — one supplied ordinary thing"))
        XCTAssertTrue(prompt.contains("Most things remain ordinary"))
    }

    func testTaleCabinetTreatsReaderChoiceAsBargainWithoutInventingPrice() {
        let day = BookDay(
            id: "2026-07-18",
            date: date("2026-07-18T20:30:00Z"),
            pages: [
                BookPage(
                    type: .narrativeOS,
                    createdAt: date("2026-07-18T18:00:00Z"),
                    promptText: "Three doors waited.",
                    userInput: "The corridor offered a red door and a blue door.",
                    playerReply: "I chose the blue door because it felt honest.",
                    origin: .generated
                )
            ]
        )

        let reading = BraidPromptBuilder.taleReading(for: day)

        XCTAssertEqual(reading.motion, .bargain)
        XCTAssertEqual(reading.pressure, .debt)
        XCTAssertEqual(reading.turn, "I chose the blue door because it felt honest.")
        XCTAssertTrue(reading.promptSection.contains("Never invent the price"))
        XCTAssertTrue(reading.promptSection.contains("price already present in the evidence"))
    }

    func testTaleCabinetLetsSparseUnresolvedDayBecomeAGlimpseOrVigil() {
        let day = BookDay(
            id: "2026-07-18",
            date: date("2026-07-18T20:30:00Z"),
            pages: [
                BookPage(
                    type: .note,
                    createdAt: date("2026-07-18T18:00:00Z"),
                    promptText: "A note from today",
                    userInput: "The form stayed unfinished beside the grocery bag.",
                    origin: .userAuthored
                )
            ]
        )

        let reading = BraidPromptBuilder.taleReading(for: day)

        XCTAssertEqual(reading.scale, .glimpse)
        XCTAssertEqual(reading.motion, .vigil)
        XCTAssertEqual(reading.pressure, .absence)
        XCTAssertNil(reading.turn)
        XCTAssertTrue(reading.promptSection.contains("Do not manufacture one"))
    }

    func testSupportingLogsCanShapeTheBraidWithoutVisibleRecital() {
        let day = BookDay(
            id: "2026-07-18",
            date: date("2026-07-18T20:30:00Z"),
            pages: [
                BookPage(
                    type: .weather,
                    createdAt: date("2026-07-18T08:00:00Z"),
                    promptText: "Weather",
                    userInput: "Rain at the glass.",
                    origin: .imported
                ),
                BookPage(
                    type: .body,
                    createdAt: date("2026-07-18T12:00:00Z"),
                    promptText: "Body",
                    userInput: "Heavy shoulders.",
                    origin: .userAuthored
                ),
                BookPage(
                    type: .diary,
                    createdAt: date("2026-07-18T18:00:00Z"),
                    promptText: "Today",
                    userInput: "I repaired the blue chair beside the grocery bag.",
                    origin: .userAuthored
                )
            ]
        )

        let reading = BraidPromptBuilder.taleReading(for: day)

        XCTAssertFalse(reading.visibleSupportingLogs)
        XCTAssertTrue(reading.promptSection.contains("shape pace or atmosphere invisibly"))
        XCTAssertTrue(BraidPromptBuilder.prompt(for: day, context: .empty).contains("notice a log without repeating it"))
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

    func testBraidTastingAllowsEarlierMotifToRemainSilent() {
        let context = BraidPromptBuilder.Context(
            recentBraids: ["The brass key waited beside a moth under the moon."]
        )
        let silent = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Blue Chair

            You repaired the blue chair beside the grocery bag.

            The Book kept the page: the chair held.
            """
        )
        let overEchoed = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Brass Key

            The brass key waited beside the moth under the moon.

            The Book kept the page: the brass key, moth, and moon returned.
            """
        )

        let silentScore = BraidTastingRoom.score(page: silent, context: context)
        let overEchoedScore = BraidTastingRoom.score(page: overEchoed, context: context)

        XCTAssertEqual(silentScore.priorEcho, 8)
        XCTAssertLessThan(overEchoedScore.priorEcho, silentScore.priorEcho)
    }

    func testBraidTastingPenalizesUnsupportedStockMagicClusters() {
        let reading = BraidPromptBuilder.TaleReading(
            scale: .glimpse,
            motion: .repair,
            pressure: .agency,
            anchorPageID: "chair",
            anchor: "the blue chair and its loose brass screw",
            turn: "the chair was repaired",
            visibleSupportingLogs: false
        )
        let context = BraidPromptBuilder.Context(taleReading: reading)
        let restrained = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Blue Chair

            You repaired the blue chair. The loose screw refused to leave the saucer until the seat held.

            The Book kept the page: the chair held.
            """
        )
        let stock = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: """
            Moonlit Threshold

            A glimmering moth crossed the moonlit threshold beside the blue chair.

            The Book kept the page: the lantern glimmered.
            """
        )

        let restrainedScore = BraidTastingRoom.score(page: restrained, context: context)
        let stockScore = BraidTastingRoom.score(page: stock, context: context)

        XCTAssertGreaterThan(stockScore.penalties, restrainedScore.penalties)
        XCTAssertGreaterThan(restrainedScore.concreteMagic, stockScore.concreteMagic)
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
        XCTAssertTrue(notes.contains("selected tale motion"))
        XCTAssertTrue(notes.contains("one supplied ordinary thing"))
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
        XCTAssertTrue(lesson.contains("I learned"))
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
        XCTAssertTrue(prompt.contains("govern the braid's emphasis"))
        XCTAssertTrue(prompt.contains("normally return transformed in \"The Book kept the page:\""))
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

    func testBusyDayPromptKeepsEveryPageInsideCompactEvidencePacket() {
        let pages = (1...15).map { index in
            BookPage(
                id: "busy-\(index)",
                type: .diary,
                createdAt: date("2026-07-18T\(String(format: "%02d", index + 4)):00:00Z"),
                promptText: "Notice the concrete hinge on page \(index).",
                userInput: "detail\(String(format: "%02d", index)) stayed on the table beside a deliberately long sentence that should be compacted without erasing this page.",
                origin: .userAuthored
            )
        }
        let day = BookDay(id: "busy-day", date: date("2026-07-18T20:30:00Z"), pages: pages)

        let prompt = BraidPromptBuilder.prompt(for: day, context: .empty)

        XCTAssertTrue(prompt.contains("COMPLETE COMPACT LEDGER (15 pages)"))
        for index in 1...15 {
            XCTAssertTrue(prompt.contains("detail\(String(format: "%02d", index))"), "missing page \(index)")
        }
        // Derived from the real budget rather than a round number: a hardcoded
        // 20,000 sat above what the local brain could actually attend to, so
        // the prompt drifted past the point of silent compaction unnoticed.
        XCTAssertLessThan(prompt.count, Self.braidPromptCharacterAllowance)
        XCTAssertTrue(prompt.contains("carry at least three distinct non-log details"))
    }

    /// What the braid may actually spend, in characters, before
    /// `LocalBrainPromptBudget.fit` starts clipping the middle of the prompt —
    /// a poor edit the Book logs as an error. Instructions are charged against
    /// the same allowance, so they come off the top.
    private static var braidPromptCharacterAllowance: Int {
        let inputBudget = LocalBrainPromptBudget.braidContextWindowTokens
            - LocalBrainPromptBudget.braidMaxOutputTokens
            - LocalBrainPromptBudget.safetyTokens
        return inputBudget * 3 - BraidInstructionsCharacterCount
    }

    /// `BraidInstructions.bookOfYou` lives in the app target; its length is
    /// pinned here so the core tests can charge for it.
    private static let BraidInstructionsCharacterCount = 1_230

    /// A heavy day must cost the local brain no more than an ordinary one. The
    /// evidence packet seats a day to its budget and drops the weakest pages,
    /// so the prompt stops growing with how much the reader keeps.
    func testEvidencePacketStopsGrowingOnceTheBudgetIsFull() {
        func prompt(pageCount: Int) -> String {
            let pages = (1...pageCount).map { index in
                BookPage(
                    id: "many-\(index)",
                    type: .diary,
                    createdAt: date("2026-07-18T04:00:00Z").addingTimeInterval(Double(index) * 900),
                    promptText: "Hinge \(index).",
                    userInput: "detail\(index) stayed on the table beside a deliberately long sentence that should be compacted without erasing this page.",
                    origin: .userAuthored
                )
            }
            let day = BookDay(id: "many-\(pageCount)", date: date("2026-07-18T20:30:00Z"), pages: pages)
            return BraidPromptBuilder.prompt(for: day, context: .empty)
        }

        let modest = prompt(pageCount: 15)
        let heavy = prompt(pageCount: 40)
        let absurd = prompt(pageCount: 120)

        XCTAssertLessThan(modest.count, Self.braidPromptCharacterAllowance)
        XCTAssertLessThan(heavy.count, Self.braidPromptCharacterAllowance)
        XCTAssertLessThan(absurd.count, Self.braidPromptCharacterAllowance)
        // Past the seat count the prompt is flat: three times the pages must not
        // buy meaningfully more context.
        XCTAssertEqual(heavy.count, absurd.count, "the packet still scales with page count")
        XCTAssertLessThan(heavy.count - modest.count, 900)
    }

    /// When the day outgrows the packet, the seats go to the pages that carry
    /// the story — reader-authored souvenirs before generated colour.
    func testEvidencePacketSeatsTheHeaviestPagesFirst() {
        var pages: [BookPage] = (1...40).map { index in
            BookPage(
                id: "filler-\(index)",
                type: .lore,
                createdAt: date("2026-07-18T04:00:00Z").addingTimeInterval(Double(index) * 600),
                promptText: "Filler \(index).",
                userInput: "filler\(index) is generated colour with no reader decision attached to it at all.",
                origin: .generated
            )
        }
        pages.append(
            BookPage(
                id: "the-souvenir",
                type: .souvenir,
                createdAt: date("2026-07-18T19:00:00Z"),
                promptText: "One sentence.",
                userInput: "souvenirmarker the kitchen window held the last of the light.",
                origin: .userAuthored
            )
        )
        let day = BookDay(id: "crowded", date: date("2026-07-18T20:30:00Z"), pages: pages)

        let lines = BraidPromptBuilder.evidenceLines(for: day, totalCharacterBudget: 3_600)

        XCTAssertTrue(
            lines.contains { $0.contains("souvenirmarker") },
            "the reader's own souvenir lost its seat to generated colour"
        )
    }

    func testBraidAuditRejectsOneParagraphDrizzleForBusyDay() {
        let objects = [
            "teacup", "saucer", "scarf", "envelope", "receipt", "boots", "screw", "chair",
            "seltzer", "notebook", "pencil", "tomato", "keyring", "postcard", "thimble"
        ]
        let pages = (1...15).map { index in
            BookPage(
                type: .diary,
                createdAt: date("2026-07-18T\(String(format: "%02d", index + 4)):00:00Z"),
                promptText: "Today",
                userInput: "The \(objects[index - 1]) changed position beside the distinct marker\(index) before evening.",
                origin: .userAuthored
            )
        }
        let day = BookDay(id: "busy-day", date: date("2026-07-18T20:30:00Z"), pages: pages)
        let context = BraidPromptBuilder.Context(taleReading: BraidPromptBuilder.taleReading(for: day))
        let draft = "Drizzle worried the glass all evening, and the gray weather made the room feel small. The Book kept the page: the rain stayed."

        let issues = BraidOutputAudit.issues(in: draft, for: day, context: context)

        XCTAssertTrue(issues.contains(.tooShort))
        XCTAssertTrue(issues.contains(.tooFewParagraphs))
        XCTAssertTrue(issues.contains(.tooFewEvidenceThreads))
        XCTAssertTrue(issues.contains(.supportingLogsTookOver))
    }

    func testBraidAuditAcceptsFullMultiThreadBraid() {
        let details = [
            "blue chair and brass screw", "lemon seltzer", "red scarf", "library receipt", "muddy boots", "green envelope"
        ]
        let pages = details.enumerated().map { index, detail in
            BookPage(
                type: .diary,
                createdAt: date("2026-07-18T\(String(format: "%02d", index + 9)):00:00Z"),
                promptText: "What remained?",
                userInput: "The \(detail) stayed specific while the rest of the afternoon moved around it, and you chose to keep that exact ordinary evidence.",
                origin: .userAuthored
            )
        }
        let day = BookDay(id: "full-day", date: date("2026-07-18T20:30:00Z"), pages: pages)
        let context = BraidPromptBuilder.Context(taleReading: BraidPromptBuilder.taleReading(for: day))
        let paragraph = "You let the blue chair keep its brass screw in a saucer while the lemon seltzer sweated beside it. Nothing announced itself as important, but the red scarf caught on the doorway and made you stop long enough to notice what the room had been carrying without complaint."
        let draft = [
            "The Green Envelope",
            paragraph,
            "The library receipt waited under the glass while your muddy boots dried near the door. You did not ask these things to become symbols. They only obeyed one quiet rule: anything named exactly could refuse to disappear before evening, and each ordinary object held its small ground.",
            "By dusk, the green envelope had become the day's last witness. It stayed sealed, not mysterious, simply unfinished. The chair, receipt, scarf, boots, and drink remained separate facts, but the Book set them close enough for the day's movement to become legible without turning into a list.",
            "You had not solved the room or earned a lesson from it. You had repaired one loose thing, carried several others, and left one envelope unopened. That was enough movement for the page, and enough restraint for the little law to remain strange without asking anyone to believe it.",
            "The Book kept the page: the green envelope could wait without vanishing."
        ].joined(separator: "\n\n")

        XCTAssertEqual(BraidOutputAudit.issues(in: draft, for: day, context: context), [])
    }

    func testNightlyStoryScoreKeepsLivedFactsAboveReaderChosenFiction() throws {
        let lived = BookPage(
            id: "lived-kettle",
            type: .souvenir,
            createdAt: date("2026-07-18T08:00:00Z"),
            promptText: "One true thing",
            userInput: "The blue kettle clicked off while the unopened letter waited beside it.",
            origin: .userAuthored
        )
        let fiction = BookPage(
            id: "fiction-choice",
            type: .narrativeOS,
            createdAt: date("2026-07-18T09:00:00Z"),
            promptText: "A Story Page",
            userInput: "The orchard door offered three paths.",
            tags: ["choice:stay-and-listen"],
            sourceID: "narrative-os",
            origin: .simulated
        )
        let day = BookDay(
            id: "2026-07-18",
            date: date("2026-07-18T20:30:00Z"),
            pages: [lived, fiction]
        )

        let score = BraidPromptBuilder.nightlyStoryScore(
            for: day,
            context: .empty,
            connections: [],
            constellations: [],
            now: day.date
        )
        var context = BraidPromptBuilder.Context()
        context.storyScore = score
        context.taleReading = score.taleReading
        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertEqual(score.livedBeats.map(\.pageID), ["lived-kettle"])
        XCTAssertEqual(score.fictionBeat?.pageID, "fiction-choice")
        XCTAssertTrue(prompt.contains("LIVED ANCHORS (facts; these own what happened)"))
        XCTAssertTrue(prompt.contains("Reader-made fictional choice"))
        XCTAssertTrue(prompt.contains("never a lived event"))
        XCTAssertTrue(prompt.contains("The blue kettle clicked off"))
        XCTAssertTrue(prompt.contains("stay and listen"))
    }

    func testNightlyStoryScoreHonorsRelationalBoundaryAndKeepsGlimmerTentative() throws {
        let page = BookPage(
            id: "rain-letter-tonight",
            type: .souvenir,
            createdAt: date("2026-07-18T20:00:00Z"),
            promptText: "One true thing",
            userInput: "Cold rain tapped the glass while I opened Wicker's letter.",
            origin: .userAuthored
        )
        let day = BookDay(id: "2026-07-18", date: date("2026-07-18T21:00:00Z"), pages: [page])
        let connection = relationalConnection(
            tier: .glimmer,
            evidencePageID: page.id,
            observationKey: "weather-rain-wicker"
        )

        let allowed = BraidPromptBuilder.nightlyStoryScore(
            for: day,
            context: .empty,
            connections: [connection],
            constellations: [],
            now: day.date
        )
        let refused = BraidPromptBuilder.nightlyStoryScore(
            for: day,
            context: .empty,
            connections: [connection],
            constellations: [],
            forbiddenObservationKeys: [connection.observationKey],
            now: day.date
        )

        XCTAssertEqual(allowed.relationalLens?.connectionID, connection.id)
        XCTAssertTrue(allowed.relationalLens?.line.contains("question") == true)
        XCTAssertTrue(allowed.forbiddenClaims.contains { $0.contains("settled truth") })
        XCTAssertNil(refused.relationalLens)
        XCTAssertNil(refused.arc)
    }

    func testNightlyArcPersistsReceiptsAndDeepensOnTheNextNight() throws {
        let firstPage = BookPage(
            id: "first-rain-letter",
            type: .souvenir,
            createdAt: date("2026-07-18T20:00:00Z"),
            promptText: "One true thing",
            userInput: "Cold rain tapped the glass while I opened Wicker's letter.",
            origin: .userAuthored
        )
        let firstDay = BookDay(id: "2026-07-18", date: date("2026-07-18T21:00:00Z"), pages: [firstPage])
        let firstConnection = relationalConnection(
            tier: .gathering,
            evidencePageID: firstPage.id,
            observationKey: "weather-rain-wicker"
        )
        let firstScore = BraidPromptBuilder.nightlyStoryScore(
            for: firstDay,
            context: .empty,
            connections: [firstConnection],
            constellations: [],
            now: firstDay.date
        )
        var firstContext = BraidPromptBuilder.Context()
        firstContext.storyScore = firstScore
        firstContext.taleReading = firstScore.taleReading
        let firstBraid = BraidPageDetails.annotated(
            BookPage(
                id: "first-braid",
                type: .bookOfYou,
                createdAt: date("2026-07-18T22:00:00Z"),
                promptText: "Book of You",
                userInput: "Rain Read The Letter\n\nThe cold glass waited beside Wicker's opened letter.\n\nThe Book kept the page: rain had found one letter worth reading.",
                tags: ["braid"]
            ),
            context: firstContext
        )
        let restored = try XCTUnwrap(BookOfYouResidue.fromTags(in: firstBraid))
        XCTAssertTrue(firstBraid.tags.contains("braid-story-score-v3"))
        XCTAssertEqual(restored.arcID, "weather-rain-wicker")
        XCTAssertEqual(restored.arcMovement, .began)
        XCTAssertTrue(restored.arcEvidencePageIDs.contains(firstPage.id))
        XCTAssertTrue(restored.relationalConnectionIDs.contains(firstConnection.id))

        let firstArchiveDay = BookDay(id: firstDay.id, date: firstDay.date, pages: [firstPage, firstBraid])
        let secondPage = BookPage(
            id: "second-rain-letter",
            type: .souvenir,
            createdAt: date("2026-07-19T20:00:00Z"),
            promptText: "One true thing",
            userInput: "Rain returned and I saved Wicker's last paragraph for after dinner.",
            origin: .userAuthored
        )
        let secondDay = BookDay(id: "2026-07-19", date: date("2026-07-19T21:00:00Z"), pages: [secondPage])
        var secondContext = BraidPromptBuilder.Context()
        secondContext.memoryDigest = BindingMemorySpine.digest(
            days: [firstArchiveDay],
            now: secondDay.date
        )
        let secondScore = BraidPromptBuilder.nightlyStoryScore(
            for: secondDay,
            context: secondContext,
            connections: [relationalConnection(
                tier: .gathering,
                evidencePageID: secondPage.id,
                observationKey: "weather-rain-wicker"
            )],
            constellations: [],
            now: secondDay.date
        )

        XCTAssertEqual(secondScore.arc?.id, firstScore.arc?.id)
        XCTAssertEqual(secondScore.arc?.movement, .deepened)
        XCTAssertNotNil(secondScore.arc?.priorState)
        XCTAssertTrue(secondScore.arc?.evidencePageIDs.contains(secondPage.id) == true)
    }

    func testTastingRoomRewardsStoryScoreFidelity() throws {
        let lived = BraidPromptBuilder.NightlyStoryScore.LivedBeat(
            pageID: "kettle-page",
            pageType: .souvenir,
            occurredAt: date("2026-07-18T08:00:00Z"),
            excerpt: "The blue kettle clicked beside the unopened letter.",
            role: "truth anchor"
        )
        let lens = BraidPromptBuilder.NightlyStoryScore.RelationalLens(
            connectionID: "rain-wicker-gathering",
            observationKey: "weather-rain-wicker",
            evidenceTier: .gathering,
            condition: "it was cold and raining",
            outcomes: ["you opened Wicker Eddies letters"],
            evidencePageIDs: ["kettle-page"],
            line: "Tonight is another receipt."
        )
        let day = BookDay(
            id: "2026-07-18",
            date: date("2026-07-18T20:30:00Z"),
            pages: [BookPage(
                id: lived.pageID,
                type: .souvenir,
                createdAt: lived.occurredAt,
                promptText: "One true thing",
                userInput: lived.excerpt,
                origin: .userAuthored
            )]
        )
        let reading = BraidPromptBuilder.taleReading(for: day)
        let score = BraidPromptBuilder.NightlyStoryScore(
            livedBeats: [lived],
            fictionBeat: nil,
            relationalLens: lens,
            arc: .init(
                id: lens.observationKey,
                movement: .deepened,
                priorState: "rain first gathered around one Wicker letter",
                tonightDelta: "the blue kettle waited beside a second Wicker letter in cold rain",
                evidencePageIDs: [lived.pageID],
                fictionChoicePageIDs: [],
                relationalConnectionIDs: [lens.connectionID]
            ),
            taleReading: reading,
            magicLicense: "Let the kettle wait.",
            endingDuty: "Return to the kettle and letter.",
            forbiddenClaims: []
        )
        var context = BraidPromptBuilder.Context()
        context.storyScore = score
        context.taleReading = reading
        let generic = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: "A Quiet Evening\n\nYou moved through a pleasant evening and noticed many things.\n\nThe Book kept the page: the day had hidden meaning."
        )
        let faithful = BookPage(
            type: .bookOfYou,
            promptText: "Book of You",
            userInput: "Kettle Beside The Letter\n\nCold rain touched the window while the blue kettle clicked beside Wicker's second unopened letter.\n\nThe Book kept the page: the kettle waited until Wicker's letter was ready."
        )

        let genericScore = BraidTastingRoom.score(page: generic, context: context)
        let faithfulScore = BraidTastingRoom.score(page: faithful, context: context)
        XCTAssertGreaterThan(faithfulScore.storyScoreFidelity, genericScore.storyScoreFidelity)
        XCTAssertEqual(BraidTastingRoom.taste([generic, faithful], context: context).winner?.page, faithful)
    }

    func testHardshipIsProofOfLifeButNotAutomaticRutEvidence() {
        let day = BookDay(
            id: "grief-day",
            date: date("2026-07-20T20:00:00Z"),
            pages: [
                BookPage(
                    id: "grief",
                    type: .diary,
                    createdAt: date("2026-07-20T15:00:00Z"),
                    promptText: "What happened?",
                    userInput: "My mother died. I sat with my sister and held her hand until the room went dark.",
                    tags: ["shadow", "grief"],
                    origin: .userAuthored
                )
            ]
        )

        let reading = BraidPromptBuilder.taleReading(for: day)

        XCTAssertEqual(reading.rutInfluence, .notInThisTelling)
        XCTAssertTrue(reading.rutEvidencePageIDs.isEmpty)
        XCTAssertEqual(reading.narrativeRegister, .tender)
        XCTAssertTrue(reading.promptSection.contains("Hardship is not automatically a Rut battle"))
    }

    func testExplicitAutopilotEvidenceCanShapeRutWithoutInventingVictory() {
        let day = BookDay(
            id: "rut-day",
            date: date("2026-07-20T20:00:00Z"),
            pages: [
                BookPage(
                    id: "drive",
                    type: .diary,
                    createdAt: date("2026-07-20T15:00:00Z"),
                    promptText: "What went missing?",
                    userInput: "I drove home on autopilot and don't remember doing it.",
                    tags: ["rut-battle", "routine-memory"],
                    origin: .userAuthored
                )
            ]
        )

        let reading = BraidPromptBuilder.taleReading(for: day)

        XCTAssertEqual(reading.rutInfluence, .tookSomething)
        XCTAssertEqual(reading.rutEvidencePageIDs, ["drive"])
        XCTAssertEqual(reading.narrativeRegister, .fierce)
    }

    func testStoryFormSelectionExercisesTheFullSmallGrammar() {
        func reading(_ id: String, pages: [BookPage]) -> BraidPromptBuilder.StoryForm {
            BraidPromptBuilder.taleReading(
                for: BookDay(id: id, date: date("2026-07-20T20:00:00Z"), pages: pages)
            ).storyForm
        }
        let forms: Set<BraidPromptBuilder.StoryForm> = [
            reading("slice", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "I repaired the blue chair.", origin: .userAuthored)
            ]),
            reading("mosaic", pages: (0..<4).map { index in
                BookPage(type: .diary, createdAt: date("2026-07-20T\(10 + index):00:00Z"), promptText: "What happened?", userInput: "Particular object \(index) sat on the table.", origin: .userAuthored)
            }),
            reading("portrait", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "I met Lara by the red wall.", tags: ["person:lara"], origin: .userAuthored)
            ]),
            reading("drama", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "I refused the easy answer.", origin: .userAuthored)
            ]),
            reading("crossing", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "I crossed the footbridge before noon.", origin: .userAuthored)
            ]),
            reading("vigil", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "I kept watch beside the sealed door.", origin: .userAuthored)
            ]),
            reading("return", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "I remembered the old coat and it came back.", origin: .userAuthored)
            ]),
            reading("comedy", pages: [
                BookPage(type: .diary, createdAt: date("2026-07-20T15:00:00Z"), promptText: "What happened?", userInput: "We laughed at the ridiculous burnt toast.", origin: .userAuthored)
            ])
        ]

        XCTAssertEqual(forms, Set(BraidPromptBuilder.StoryForm.allCases))
    }

    func testNarrativeMatrixDoesNotCollapseToAHandfulOfRecipes() {
        typealias Form = BraidPromptBuilder.StoryForm
        typealias Rut = BraidPromptBuilder.RutInfluence
        typealias Register = BraidPromptBuilder.NarrativeRegister

        func page(_ id: String, _ text: String, tags: [String] = []) -> BookPage {
            BookPage(
                id: id,
                type: .diary,
                createdAt: date("2026-07-20T15:00:00Z"),
                promptText: "What happened?",
                userInput: text,
                tags: tags,
                origin: .userAuthored
            )
        }

        let formSeeds: [(String, [BookPage])] = [
            ("slice", [page("slice", "I repaired the blue chair beside the window.")]),
            ("mosaic", (0..<4).map { page("mosaic-\($0)", "Particular object \($0) sat on its own shelf.") }),
            ("portrait", [page("portrait", "I met Lara by the red wall.", tags: ["person:lara"])]),
            ("drama", [page("drama", "I refused the easy answer and chose the costly one.")]),
            ("crossing", [page("crossing", "I crossed the footbridge before noon.")]),
            ("vigil", [page("vigil", "I kept watch beside the sealed door.")]),
            ("return", [page("return", "I remembered the old coat and it came back.")]),
            ("comedy", [page("comedy", "We laughed at the ridiculous burnt toast.")])
        ]
        let rutSeeds: [(String, String, [String])] = [
            ("none", "", []),
            ("pressing", " Routine pressed at the edge of the hour.", ["rut-battle"]),
            ("took", " I moved on autopilot and don't remember doing it.", ["rut-battle"]),
            ("resisted", " I noticed the routine and looked again.", ["rut-battle"]),
            ("mixed", " I moved on autopilot, caught myself, and looked again.", ["rut-battle"]),
            ("reopened", " The familiar thing opened again.", ["rut-reopened"])
        ]
        let registerSeeds: [(String, String)] = [
            ("plain", " The cup stayed red."),
            ("tender", " Grief and love sat together while I cared for her."),
            ("fierce", " I refused to let the cost be blurred."),
            ("wry", " Then we laughed at the absurd spoon."),
            ("uncanny", " The old sound returned and came back again."),
            ("luminous", " Bright wonder made one exact detail feel alive.")
        ]

        var readings: [BraidPromptBuilder.TaleReading] = []
        for (formID, basePages) in formSeeds {
            for (rutID, rutText, rutTags) in rutSeeds {
                for (registerID, registerText) in registerSeeds {
                    var pages = basePages
                    pages[0].id = "\(formID)-\(rutID)-\(registerID)"
                    pages[0].userInput += rutText + registerText
                    pages[0].tags.append(contentsOf: rutTags)
                    readings.append(BraidPromptBuilder.taleReading(
                        for: BookDay(
                            id: "\(formID)-\(rutID)-\(registerID)",
                            date: date("2026-07-20T20:00:00Z"),
                            pages: pages
                        )
                    ))
                }
            }
        }

        let forms = Set(readings.map(\.storyForm))
        let ruts = Set(readings.map(\.rutInfluence))
        let registers = Set(readings.map(\.narrativeRegister))
        let signatures = Dictionary(grouping: readings) {
            "\($0.storyForm.rawValue)|\($0.rutInfluence.rawValue)|\($0.narrativeRegister.rawValue)"
        }
        let dominantShare = Double(signatures.values.map(\.count).max() ?? 0)
            / Double(max(1, readings.count))

        XCTAssertEqual(forms, Set(Form.allCases))
        XCTAssertEqual(ruts, Set(Rut.allCases))
        XCTAssertEqual(registers, Set(Register.allCases))
        XCTAssertGreaterThanOrEqual(
            signatures.count,
            24,
            "the nominal 288-cell matrix may contain semantic correlations, but it must not collapse to a dozen recipes"
        )
        XCTAssertLessThan(
            dominantShare,
            0.20,
            "no single recipe should swallow a fifth of a balanced, evidence-varied corpus"
        )
    }

    func testAnnotatedBraidCarriesFormRutAndRegisterIntoBindingResidue() throws {
        let source = BookPage(
            id: "caught-rut",
            type: .diary,
            createdAt: date("2026-07-20T15:00:00Z"),
            promptText: "What fought you?",
            userInput: "I caught myself on autopilot, stopped, and looked again.",
            tags: ["rut-battle"],
            origin: .userAuthored
        )
        let day = BookDay(
            id: "2026-07-20",
            date: date("2026-07-20T20:00:00Z"),
            pages: [source]
        )
        let reading = BraidPromptBuilder.taleReading(for: day)
        let braid = BraidPageDetails.annotated(
            BookPage(
                type: .bookOfYou,
                promptText: "Book of You",
                userInput: "The Red Wall\n\nYou stopped and looked again.\n\nThe Book kept the page: the wall returned."
            ),
            context: BraidPromptBuilder.Context(taleReading: reading)
        )
        let residue = try XCTUnwrap(BookOfYouResidue.fromTags(in: braid))

        XCTAssertEqual(residue.storyForm, reading.storyForm)
        XCTAssertEqual(residue.rutInfluence, reading.rutInfluence)
        XCTAssertEqual(residue.narrativeRegister, reading.narrativeRegister)
        XCTAssertEqual(residue.rutEvidencePageIDs, ["caught-rut"])
    }

    private func relationalConnection(
        tier: RelationalLoomConnection.EvidenceTier,
        evidencePageID: String,
        observationKey: String
    ) -> RelationalLoomConnection {
        RelationalLoomConnection(
            id: "\(observationKey)-\(tier.rawValue)",
            observationKey: observationKey,
            headline: "Rain and Wicker",
            line: "When it was cold and raining, you opened Wicker Eddies letters.",
            condition: RelationalLoomFeature(
                id: "weather:cold+rain",
                family: .weather,
                label: "cold rain",
                conditionClause: "it was cold and raining",
                outcomeClause: "cold rain arrived",
                symbolName: "cloud.rain",
                carriesReaderSuppliedMeaning: false
            ),
            outcome: RelationalLoomFeature(
                id: "character:wicker-eddies",
                family: .character,
                label: "Wicker Eddies",
                conditionClause: "Wicker Eddies was present",
                outcomeClause: "you opened Wicker Eddies letters",
                symbolName: "envelope.open",
                carriesReaderSuppliedMeaning: true
            ),
            evidence: [],
            evidencePageIDs: [evidencePageID],
            inHits: tier == .glimmer ? 2 : 4,
            inCount: tier == .glimmer ? 2 : 5,
            outHits: 0,
            outCount: tier == .glimmer ? 3 : 5,
            evidenceTier: tier,
            strength: tier == .glimmer ? 55 : 78
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
