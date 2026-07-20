import XCTest
@testable import InsideCoverCore

final class AskTheBookMemoryTests: XCTestCase {
    private func retrieve(
        _ query: String,
        dataset: StacksSearchDataset,
        previousTurns: [AskTheBookTurn] = []
    ) -> AskTheBookMemoryPacket {
        AskTheBookMemoryRetriever.retrieve(
            query: query,
            previousTurns: previousTurns,
            from: dataset,
            semanticScorer: nil
        )
    }

    func testReaderMessageFromOldChatIsSearchableButOldBookAnswerIsNot() {
        let chat = BookPage(
            id: "chat-page",
            type: .askTheBook,
            promptText: "Chat with the Book",
            userInput: """
            Chat with the Book Page 1

            Reader: The cobalt lantern belonged to my grandmother.

            Answer: An obsidian raven carried it through the moon.
            """,
            sourceID: "ask-the-book",
            origin: .generated,
            privacy: .privateLocal
        )
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "2026-07-01", date: Date(), pages: [chat])]

        let readerMatch = retrieve("cobalt lantern", dataset: dataset)
        let evidence = readerMatch.evidence.first { $0.result.referenceID == chat.id }
        XCTAssertEqual(evidence?.authority, .priorConversation)
        XCTAssertTrue(evidence?.excerpt.contains("cobalt lantern") == true)
        XCTAssertFalse(evidence?.excerpt.contains("obsidian raven") == true)

        let answerMatch = retrieve("obsidian raven", dataset: dataset)
        XCTAssertFalse(answerMatch.evidence.contains { $0.result.referenceID == chat.id })
    }

    func testStoryOnlyAndDoNotUseFactsAreInvisibleToChat() {
        let now = Date()
        let facts = [
            SelfFact(
                id: "story-only",
                questionID: "story",
                question: "What belongs only in stories?",
                answer: "The silver turnip.",
                bookTranslation: "A silver turnip waits offstage.",
                sensitivity: .story,
                usePermission: .storyOnly,
                tags: ["turnip"],
                createdAt: now,
                updatedAt: now
            ),
            SelfFact(
                id: "never-use",
                questionID: "never",
                question: "What should stay shut?",
                answer: "The violet trapdoor.",
                bookTranslation: "A violet trapdoor is sealed.",
                sensitivity: .identity,
                usePermission: .doNotUse,
                tags: ["trapdoor"],
                createdAt: now,
                updatedAt: now
            )
        ]
        var dataset = StacksSearchDataset()
        dataset.selfFacts = facts

        let storyPacket = retrieve("silver turnip", dataset: dataset)
        XCTAssertFalse(storyPacket.evidence.contains { $0.result.referenceID == "story-only" })

        let sealedPacket = retrieve("violet trapdoor", dataset: dataset)
        XCTAssertFalse(sealedPacket.evidence.contains { $0.result.referenceID == "never-use" })
    }

    func testPrivateContextFactUsesTranslationAndForbidsQuotation() {
        let now = Date()
        let fact = SelfFact(
            id: "private-context",
            questionID: "comfort",
            question: "What place feels safe?",
            answer: "The blue room behind the kitchen.",
            bookTranslation: "A familiar room near the kitchen is a place of comfort.",
            sensitivity: .comfort,
            usePermission: .privateContext,
            tags: ["room", "comfort"],
            createdAt: now,
            updatedAt: now
        )
        var dataset = StacksSearchDataset()
        dataset.selfFacts = [fact]

        let packet = retrieve("Which blue room feels safe?", dataset: dataset)
        let evidence = packet.evidence.first { $0.result.referenceID == fact.id }

        XCTAssertEqual(evidence?.authority, .recordedFact)
        XCTAssertEqual(evidence?.mayQuote, false)
        XCTAssertEqual(evidence?.excerpt, fact.bookTranslation)
        XCTAssertFalse(evidence?.excerpt.contains("blue room") == true)
    }

    func testSensitiveSupportPageRequiresARelevantDirectQuestion() {
        let page = BookPage(
            id: "sensitive-page",
            type: .body,
            promptText: "Body Page",
            userInput: "A sharp ache in my left elbow.",
            tags: ["elbow"],
            sourceID: "body",
            origin: .userAuthored,
            privacy: .localSensitive
        )
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "2026-07-02", date: Date(), pages: [page])]

        let unrelated = retrieve("What patterns do you see in my Book?", dataset: dataset)
        XCTAssertFalse(unrelated.evidence.contains { $0.result.referenceID == page.id })

        let direct = retrieve("What did I write about pain in my elbow?", dataset: dataset)
        XCTAssertTrue(direct.evidence.contains { $0.result.referenceID == page.id })
    }

    func testGeneratedPageIsLabeledAsCreatedPageRatherThanReaderEvidence() {
        let story = BookPage(
            id: "story-page",
            type: .narrativeOS,
            promptText: "The Clockmaker's Visit",
            userInput: "Wicker traded a brass moon for a key.",
            tags: ["clockmaker"],
            sourceID: "narrative-os",
            origin: .generated,
            privacy: .privateLocal
        )
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "2026-07-03", date: Date(), pages: [story])]

        let packet = retrieve("What happened with the brass moon?", dataset: dataset)
        let evidence = packet.evidence.first { $0.result.referenceID == story.id }

        XCTAssertEqual(evidence?.authority, .createdPage)
        XCTAssertEqual(evidence?.mayQuote, false)
        XCTAssertTrue(packet.promptSection.contains("not proof that their fictional events happened"))
        XCTAssertTrue(packet.promptSection.contains("genuine narrative continuity inside the Book"))
        XCTAssertTrue(packet.promptSection.contains("rhymes with a Story Page"))
    }

    func testPatternQuestionIsMarkedForMultiDateCaution() {
        let first = BookPage(
            id: "first",
            type: .diary,
            createdAt: Date(timeIntervalSince1970: 100),
            promptText: "Diary",
            userInput: "The station clock made waiting feel gentle.",
            origin: .userAuthored
        )
        let second = BookPage(
            id: "second",
            type: .souvenir,
            createdAt: Date(timeIntervalSince1970: 200_000),
            promptText: "Souvenir",
            userInput: "Another station clock watched me wait.",
            origin: .userAuthored
        )
        var dataset = StacksSearchDataset()
        dataset.days = [
            BookDay(id: "1970-01-01", date: first.createdAt, pages: [first]),
            BookDay(id: "1970-01-03", date: second.createdAt, pages: [second])
        ]

        let packet = retrieve("What pattern keeps happening around station clocks?", dataset: dataset)

        XCTAssertEqual(packet.inquiryKind, .pattern)
        XCTAssertGreaterThanOrEqual(packet.evidence.count, 2)
        XCTAssertTrue(packet.promptSection.contains("fewer than two independent dates"))
    }

    func testSunnyDayCountUsesDistinctRecordedDaysSinceFirstChat() {
        let firstChatDate = Date(timeIntervalSince1970: 1_720_000_000)
        let sunnyOne = firstChatDate.addingTimeInterval(86_400)
        let sunnyTwo = firstChatDate.addingTimeInterval(2 * 86_400)
        let rainy = firstChatDate.addingTimeInterval(3 * 86_400)
        let chat = BookPage(
            id: "first-chat",
            type: .askTheBook,
            createdAt: firstChatDate,
            promptText: "Chat with the Book",
            userInput: "Reader: Hello, Book.",
            sourceID: "ask-the-book",
            origin: .generated
        )
        let firstSunnyPage = BookPage(
            id: "sunny-one",
            type: .diary,
            createdAt: sunnyOne,
            promptText: "Diary",
            userInput: "A bright ordinary day.",
            context: BookPageContextSnapshot(at: sunnyOne, weatherTags: ["bright"])
        )
        let secondSunnyPage = BookPage(
            id: "sunny-two-a",
            type: .souvenir,
            createdAt: sunnyTwo,
            promptText: "Souvenir",
            userInput: "The pavement glittered.",
            context: BookPageContextSnapshot(at: sunnyTwo, weatherTags: ["bright"])
        )
        let duplicateSameDay = BookPage(
            id: "sunny-two-b",
            type: .plainPage,
            createdAt: sunnyTwo.addingTimeInterval(60),
            promptText: "",
            userInput: "Still the same day.",
            context: BookPageContextSnapshot(at: sunnyTwo, weatherTags: ["bright"])
        )
        let rainyPage = BookPage(
            id: "rainy",
            type: .weather,
            createdAt: rainy,
            promptText: "Rain at the window.",
            origin: .imported,
            context: BookPageContextSnapshot(at: rainy, weatherTags: ["rain"])
        )
        var dataset = StacksSearchDataset()
        dataset.days = [
            BookDay(id: "chat", date: firstChatDate, pages: [chat]),
            BookDay(id: "sun-1", date: sunnyOne, pages: [firstSunnyPage]),
            BookDay(id: "sun-2", date: sunnyTwo, pages: [secondSunnyPage, duplicateSameDay]),
            BookDay(id: "rain", date: rainy, pages: [rainyPage])
        ]

        let packet = retrieve(
            "How many days have been sunny since we started talking?",
            dataset: dataset
        )
        let finding = packet.evidence.first { $0.result.id == "finding-weather-count-bright" }

        XCTAssertEqual(packet.inquiryKind, .calculation)
        XCTAssertEqual(finding?.authority, .computedFinding)
        XCTAssertTrue(finding?.excerpt.contains("2 recorded sunny days") == true)
        XCTAssertTrue(finding?.excerpt.contains("Weather evidence exists on 3 distinct days") == true)
        XCTAssertTrue(finding?.excerpt.contains("Unrecorded days are not counted") == true)
        XCTAssertTrue(packet.promptSection.contains("Do not replace the calculation with an estimate"))
        XCTAssertTrue(packet.evidence.contains { $0.result.referenceID == firstSunnyPage.id })
        XCTAssertTrue(packet.evidence.first {
            $0.result.referenceID == firstSunnyPage.id
        }?.fullText.contains("Recorded outer weather: bright") == true)
    }

    func testRainyDayFeelingQuestionPairsDatedInnerWeatherWithoutClaimingCause() {
        let first = Date(timeIntervalSince1970: 1_720_100_000)
        let second = first.addingTimeInterval(86_400)
        let third = second.addingTimeInterval(86_400)
        func weatherPage(_ id: String, date: Date, tag: String) -> BookPage {
            BookPage(
                id: id,
                type: .weather,
                createdAt: date,
                promptText: tag == "rain" ? "Rain outside." : "Clear outside.",
                origin: .imported,
                context: BookPageContextSnapshot(at: date, weatherTags: [tag])
            )
        }
        var dataset = StacksSearchDataset()
        dataset.days = [
            BookDay(id: "rain-one", date: first, pages: [weatherPage("w1", date: first, tag: "rain")]),
            BookDay(id: "rain-two", date: second, pages: [weatherPage("w2", date: second, tag: "rain")]),
            BookDay(id: "sun", date: third, pages: [weatherPage("w3", date: third, tag: "bright")])
        ]
        dataset.facultyEntries = [
            FacultyEntry(
                id: "mood-one",
                kind: .innerWeather,
                dayID: "rain-one",
                createdAt: first.addingTimeInterval(3_600),
                windowID: "morning",
                windowName: "Morning Bell",
                rawText: "Heavy and tired."
            ),
            FacultyEntry(
                id: "mood-two",
                kind: .innerWeather,
                dayID: "rain-two",
                createdAt: second.addingTimeInterval(3_600),
                windowID: "morning",
                windowName: "Morning Bell",
                rawText: "Quiet and calm."
            ),
            FacultyEntry(
                id: "mood-sunny",
                kind: .innerWeather,
                dayID: "sun",
                createdAt: third.addingTimeInterval(3_600),
                windowID: "morning",
                windowName: "Morning Bell",
                rawText: "Restless."
            )
        ]

        let packet = retrieve("How do I feel on rainy days?", dataset: dataset)
        let finding = packet.evidence.first { $0.result.id == "finding-weather-mood-rain" }

        XCTAssertEqual(packet.inquiryKind, .pattern)
        XCTAssertEqual(finding?.authority, .computedFinding)
        XCTAssertEqual(finding?.mayQuote, false)
        XCTAssertTrue(finding?.excerpt.contains("Inner Weather was also logged on 2") == true)
        XCTAssertTrue(finding?.excerpt.contains("Heavy and tired") == true)
        XCTAssertTrue(finding?.excerpt.contains("Quiet and calm") == true)
        XCTAssertFalse(finding?.excerpt.contains("Restless") == true)
        XCTAssertTrue(finding?.excerpt.contains("not evidence that the outer weather caused") == true)
    }

    func testFuelQuestionSurfacesDatedChartButUnrelatedQuestionDoesNot() {
        let date = Date(timeIntervalSince1970: 1_720_200_000)
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "fuel-day", date: date, pages: [])]
        dataset.facultyEntries = [
            FacultyEntry(
                id: "fuel-entry",
                kind: .fuel,
                dayID: "fuel-day",
                createdAt: date,
                windowID: "midday",
                windowName: "Midday Bell",
                rawText: "Coffee, toast, and two eggs."
            )
        ]

        let direct = retrieve("What did I eat and drink lately?", dataset: dataset)
        let finding = direct.evidence.first { $0.result.id == "finding-log-overview-fuel" }
        XCTAssertEqual(finding?.authority, .computedFinding)
        XCTAssertEqual(finding?.mayQuote, false)
        XCTAssertTrue(finding?.excerpt.contains("Coffee, toast, and two eggs") == true)

        let unrelated = retrieve("What is Wicker doing?", dataset: dataset)
        XCTAssertFalse(unrelated.evidence.contains { $0.result.referenceID == "fuel-entry" })
        XCTAssertFalse(unrelated.evidence.contains { $0.result.id.contains("fuel") })
    }

    func testLocationMoodFindingUsesNamedPlaceWithoutCoordinateTrail() {
        let date = Date(timeIntervalSince1970: 1_720_300_000)
        let page = BookPage(
            id: "home-page",
            type: .bookOfYou,
            createdAt: date,
            promptText: "A day at home.",
            userInput: "The kettle kept watch.",
            tags: ["braid-location:Home"],
            origin: .generated
        )
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "home-day", date: date, pages: [page])]
        dataset.facultyEntries = [
            FacultyEntry(
                id: "home-mood",
                kind: .innerWeather,
                dayID: "home-day",
                createdAt: date.addingTimeInterval(1_800),
                windowID: "evening",
                windowName: "Evening Bell",
                rawText: "Settled and soft."
            )
        ]

        let packet = retrieve("How do I feel at home?", dataset: dataset)
        let finding = packet.evidence.first { $0.result.id == "finding-location-inner-weather" }

        XCTAssertEqual(finding?.authority, .computedFinding)
        XCTAssertTrue(finding?.excerpt.contains("Home: 1 recorded day") == true)
        XCTAssertTrue(finding?.excerpt.contains("Settled and soft") == true)
        XCTAssertTrue(finding?.excerpt.contains("does not expose a coordinate trail") == true)
    }

    func testCalculatedArchiveAnswerDoesNotDependOnGemmaSupplyingTheCount() throws {
        let first = Date(timeIntervalSince1970: 1_720_400_000)
        let second = first.addingTimeInterval(86_400)
        func sunnyPage(_ id: String, _ date: Date) -> BookPage {
            BookPage(
                id: id,
                type: .weather,
                createdAt: date,
                promptText: "Clear sky.",
                origin: .imported,
                context: BookPageContextSnapshot(at: date, weatherTags: ["bright"])
            )
        }
        var dataset = StacksSearchDataset()
        dataset.days = [
            BookDay(id: "sun-a", date: first, pages: [sunnyPage("sun-a-page", first)]),
            BookDay(id: "sun-b", date: second, pages: [sunnyPage("sun-b-page", second)])
        ]

        let packet = retrieve("How many sunny days are recorded?", dataset: dataset)
        let answer = try XCTUnwrap(
            AskTheBookAnswerGrounder.deterministicAnswer(for: packet)
        )

        XCTAssertGreaterThan(packet.searchedRecordCount, 0)
        XCTAssertTrue(answer.contains("2 recorded sunny days"))
        XCTAssertTrue(answer.contains("counted twice"))
    }

    func testGeneratedPatternAnswerIsRepairedWhenGemmaIgnoresComputedEvidence() {
        let date = Date(timeIntervalSince1970: 1_720_500_000)
        let weather = BookPage(
            id: "rain-record",
            type: .weather,
            createdAt: date,
            promptText: "Rain.",
            origin: .imported,
            context: BookPageContextSnapshot(at: date, weatherTags: ["rain"])
        )
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "rain-day", date: date, pages: [weather])]
        dataset.facultyEntries = [
            FacultyEntry(
                id: "rain-mood",
                kind: .innerWeather,
                dayID: "rain-day",
                createdAt: date.addingTimeInterval(900),
                windowID: "morning",
                windowName: "Morning Bell",
                rawText: "Low and quiet."
            )
        ]
        let prompt = "How do I feel on rainy days?"
        let packet = retrieve(prompt, dataset: dataset)

        let repaired = AskTheBookAnswerGrounder.finalizeGenerated(
            "Rain can make people feel all sorts of things.",
            prompt: prompt,
            memory: packet
        )

        XCTAssertTrue(repaired.contains("1 recorded rainy day"))
        XCTAssertTrue(repaired.contains("dated records before answering"))
        XCTAssertTrue(repaired.contains("Rain can make people"))
    }

    func testKeptPageContextLinksPrivateChartsOnlyForDirectQuestions() {
        let date = Date(timeIntervalSince1970: 1_720_600_000)
        let page = BookPage(
            id: "lantern-page",
            type: .diary,
            createdAt: date,
            promptText: "What did the room keep?",
            userInput: "The copper lantern stayed lit.",
            origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: date,
                weatherTags: ["rain"],
                locationLabel: "Home",
                innerWeatherEntryID: "linked-mood",
                fuelEntryID: "linked-fuel"
            )
        )
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "linked-day", date: date, pages: [page])]
        dataset.facultyEntries = [
            FacultyEntry(
                id: "linked-mood",
                kind: .innerWeather,
                dayID: "linked-day",
                createdAt: date,
                windowID: "evening",
                windowName: "Evening Bell",
                rawText: "Soft but restless."
            ),
            FacultyEntry(
                id: "linked-fuel",
                kind: .fuel,
                dayID: "linked-day",
                createdAt: date,
                windowID: "evening",
                windowName: "Evening Bell",
                rawText: "Soup and water."
            )
        ]

        let direct = retrieve(
            "What mood and fuel had I logged when I kept the copper lantern?",
            dataset: dataset
        )
        let directEvidence = direct.evidence.first {
            $0.result.referenceID == page.id
        }
        XCTAssertEqual(directEvidence?.mayQuote, false)
        XCTAssertTrue(directEvidence?.fullText.contains("Soft but restless") == true)
        XCTAssertTrue(directEvidence?.fullText.contains("Soup and water") == true)

        let unrelated = retrieve(
            "What did I write about the copper lantern?",
            dataset: dataset
        )
        let unrelatedEvidence = unrelated.evidence.first {
            $0.result.referenceID == page.id
        }
        XCTAssertEqual(unrelatedEvidence?.mayQuote, true)
        XCTAssertFalse(unrelatedEvidence?.fullText.contains("Soft but restless") == true)
        XCTAssertFalse(unrelatedEvidence?.fullText.contains("Soup and water") == true)

        let place = retrieve(
            "Where was I when I kept the copper lantern at home?",
            dataset: dataset
        )
        XCTAssertTrue(place.evidence.first {
            $0.result.referenceID == page.id
        }?.fullText.contains("Recorded place: Home") == true)
    }

}
