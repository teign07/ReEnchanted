import XCTest
@testable import InsideCoverCore

final class LetsChatTests: XCTestCase {
    // MARK: Router

    func testGreetingNeverTouchesTheArchive() {
        for message in ["hi", "Hello!", "good evening", "How are you today?", "hey book", "what's up",
                        "Hey, good morning. How are you?", "Hi book, how's it going?"] {
            let route = LetsChatRouter.route(message)
            XCTAssertEqual(route.intent, .greeting, message)
            XCTAssertFalse(route.needsArchive, message)
            XCTAssertEqual(route.knowledgeLimit, 0, message)
            XCTAssertLessThanOrEqual(route.maxReplyTokens, 100, message)
        }
    }

    func testAGreetingWithARealQuestionAfterItIsNotJustAGreeting() {
        XCTAssertNotEqual(LetsChatRouter.route("Hey, can you tell me about my week").intent, .greeting)
        XCTAssertNotEqual(LetsChatRouter.route("hi I bought a very ugly lamp today").intent, .greeting)
    }

    func testHistoryQuestionsPayForTheSearchAndNothingElseDoes() {
        for message in [
            "What did I write about my grandmother?",
            "Do you remember the day I got lost?",
            "How many sunny days have I kept?",
            "When did I last go to the harbour?",
            "Do I always write more when it rains?"
        ] {
            let route = LetsChatRouter.route(message)
            XCTAssertEqual(route.intent, .aboutReader, message)
            XCTAssertTrue(route.needsArchive, message)
        }
        for message in [
            "My sister's wedding is on Saturday and I'm nervous",
            "I bought a very ugly lamp today",
            "tell me something strange"
        ] {
            let route = LetsChatRouter.route(message)
            XCTAssertFalse(route.needsArchive, message)
        }
    }

    func testAnOpinionAboutTheReadersSubjectIsNotAQuestionAboutTheBook() {
        // The interior grounder used to substring-match "what do you think
        // about" and answer with the Book's own opinion statement.
        let route = LetsChatRouter.route("What do you think about my sister's wedding?")
        XCTAssertNotEqual(route.intent, .aboutBook)
        XCTAssertFalse(route.mayAnswerFromInterior)

        XCTAssertEqual(LetsChatRouter.route("What do you want from me?").intent, .aboutBook)
        XCTAssertEqual(LetsChatRouter.route("What are your quirks?").intent, .aboutBook)
        XCTAssertTrue(LetsChatRouter.route("What is your long-term goal?").mayAnswerFromInterior)
        XCTAssertTrue(LetsChatRouter.route("Have I changed?").mayAnswerFromInterior)
        // Things a reader says about themselves are not questions to the Book.
        XCTAssertFalse(LetsChatRouter.route("I can't decide whether to move").mayAnswerFromInterior)
        XCTAssertFalse(LetsChatRouter.route("I'm working on a novel about bees").mayAnswerFromInterior)
    }

    func testWorldQuestionsGetLoreAndSmallTalkGetsNone() {
        let world = LetsChatRouter.route("Who is Wicker Eddies, really?")
        XCTAssertEqual(world.intent, .aboutWorld)
        XCTAssertGreaterThan(world.knowledgeLimit, 2)
        XCTAssertFalse(world.needsArchive)

        XCTAssertEqual(LetsChatRouter.route("I had a strange dream about a lighthouse").knowledgeLimit, 0)
    }

    func testAShortFollowUpKeepsTheThreadAndWhetherItNeededTheArchive() {
        let earlier = [AskTheBookTurn(
            prompt: "What did I write about the harbour last autumn?",
            answer: "You wrote about gulls."
        )]
        let route = LetsChatRouter.route("why?", previousTurns: earlier)
        XCTAssertTrue(route.needsArchive)
        XCTAssertGreaterThanOrEqual(route.historyTurns, 3)

        // With nothing before it, "why?" is just small talk.
        XCTAssertFalse(LetsChatRouter.route("why?").needsArchive)
    }

    func testRememberAndKeepAreActionsOnlyWhenTheyAreRequests() {
        XCTAssertEqual(
            LetsChatRouter.route("Remember that my dog is called Biscuit").action,
            .remember("my dog is called Biscuit")
        )
        XCTAssertEqual(LetsChatRouter.route("remember: I hate cilantro").action, .remember("I hate cilantro"))
        XCTAssertEqual(LetsChatRouter.route("keep this chat").action, .keepChat)

        // Asking whether the Book remembers is a history question, not a command.
        let recall = LetsChatRouter.route("Do you remember my dog?")
        XCTAssertNil(recall.action)
        XCTAssertEqual(recall.intent, .aboutReader)
        // A figure of speech is not a request to keep a Page.
        XCTAssertNil(LetsChatRouter.route("keep this in mind while we talk").action)
        // Nothing after the lead is nothing to remember.
        XCTAssertNil(LetsChatRouter.route("remember that").action)
    }

    // MARK: Echo guard

    func testAReplyThatSaysTheReaderBackIsCaughtAndARealReplyIsNot() {
        let message = "I keep thinking about the walk to the harbour at dusk with the gulls"
        XCTAssertTrue(LetsChatEchoGuard.repeats(
            reader: message,
            in: "You keep thinking about the walk to the harbour at dusk with the gulls."
        ))
        XCTAssertFalse(LetsChatEchoGuard.repeats(
            reader: message,
            in: "Gulls! They steal chips and stare at you while they do it. Which gull was boldest?"
        ))
        // A short message cannot be "echoed": there's nothing to copy.
        XCTAssertFalse(LetsChatEchoGuard.repeats(reader: "hello there", in: "Hello there, you."))
    }

    func testRepeatingItsOwnLastAnswerIsCaught() {
        let earlier = "The cobalt lantern sat on your grandmother's shelf and you kept it by the door."
        XCTAssertTrue(LetsChatEchoGuard.repeats(
            earlier: [earlier],
            in: "The cobalt lantern sat on your grandmother's shelf and you kept it by the door."
        ))
        XCTAssertFalse(LetsChatEchoGuard.repeats(
            earlier: [earlier],
            in: "I like that lantern. Did it ever have a candle in it, or was it only ever for looking at?"
        ))
    }

    func testEchoedSentencesAreCutButAReplyIsNeverEmptied() {
        let message = "I keep thinking about the walk to the harbour at dusk with the gulls"
        let reply = "You keep thinking about the walk to the harbour at dusk with the gulls. I'd have stolen a chip. Did you?"
        let cut = LetsChatEchoGuard.removingEcho(from: reply, reader: message)
        XCTAssertFalse(cut.contains("walk to the harbour"))
        XCTAssertTrue(cut.contains("stolen a chip"))

        let onlyEcho = "You keep thinking about the walk to the harbour at dusk with the gulls."
        XCTAssertEqual(LetsChatEchoGuard.removingEcho(from: onlyEcho, reader: message), onlyEcho)
    }

    // MARK: Retrieval no longer feeds the reader their own words

    private func dataset(with pages: [BookPage]) -> StacksSearchDataset {
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "2026-09-01", date: Date(timeIntervalSince1970: 1_788_000_000), pages: pages)]
        return dataset
    }

    func testSecondTurnDoesNotRetrieveTheReadersOwnEarlierMessageAsEvidence() {
        let line = "I keep thinking about the walk to the harbour at dusk with the gulls"
        let keptChat = BookPage(
            id: "kept-chat",
            type: .askTheBook,
            promptText: "Let’s Chat",
            userInput: "Reader: \(line)\n\nAnswer: Gulls are loud.",
            sourceID: "ask-the-book",
            origin: .generated,
            privacy: .privateLocal
        )
        let entry = BookPage(
            id: "same-words",
            type: .diary,
            promptText: "Diary",
            userInput: line,
            sourceID: "diary",
            origin: .userAuthored,
            privacy: .privateLocal
        )
        let unrelated = BookPage(
            id: "bread",
            type: .diary,
            promptText: "Diary",
            userInput: "I baked a loaf and the crust sang when it cooled.",
            sourceID: "diary",
            origin: .userAuthored,
            privacy: .privateLocal
        )
        let previous = [AskTheBookTurn(prompt: line, answer: "Gulls are loud.")]

        let packet = AskTheBookMemoryRetriever.retrieve(
            query: "Tell me more about the harbour at dusk",
            previousTurns: previous,
            from: dataset(with: [keptChat, entry, unrelated]),
            semanticScorer: nil
        )

        XCTAssertFalse(packet.evidence.contains { $0.result.referenceID == "kept-chat" })
        XCTAssertFalse(packet.evidence.contains { $0.result.referenceID == "same-words" })
    }

    func testAnOldPageThatIsNotTheCurrentChatIsStillFound() {
        let old = BookPage(
            id: "harbour-old",
            type: .diary,
            promptText: "Diary",
            userInput: "Stood on the harbour wall until the lamps came on, and the tide smelled of rope and diesel.",
            sourceID: "diary",
            origin: .userAuthored,
            privacy: .privateLocal
        )
        let packet = AskTheBookMemoryRetriever.retrieve(
            query: "What did I write about the harbour wall?",
            previousTurns: [AskTheBookTurn(prompt: "hello", answer: "Hello.")],
            from: dataset(with: [old]),
            semanticScorer: nil
        )
        XCTAssertTrue(packet.evidence.contains { $0.result.referenceID == "harbour-old" })
    }

    func testRepairLineNamesTheLeafButNeverQuotesTheReaderBackToThemself() {
        let page = BookPage(
            id: "lamp",
            type: .diary,
            promptText: "Diary",
            userInput: "The ugly green lamp in the hallway hums when it rains.",
            sourceID: "diary",
            origin: .userAuthored,
            privacy: .privateLocal
        )
        let prompt = "Do you remember the ugly green lamp?"
        let packet = AskTheBookMemoryRetriever.retrieve(
            query: prompt,
            previousTurns: [],
            from: dataset(with: [page]),
            semanticScorer: nil
        )
        XCTAssertFalse(packet.evidence.isEmpty)

        let repaired = AskTheBookAnswerGrounder.finalizeGenerated(
            "Honestly I'd have thrown it out.",
            prompt: prompt,
            memory: packet
        )
        XCTAssertTrue(repaired.contains("I opened"))
        XCTAssertFalse(repaired.contains("hums when it rains"))
        XCTAssertTrue(repaired.contains("thrown it out"))
    }

    // MARK: Prompt

    private func inputs(
        _ message: String,
        turns: [AskTheBookTurn] = [],
        memory: AskTheBookMemoryPacket = .empty,
        recent: [String] = []
    ) -> LetsChatPrompt.Inputs {
        let route = LetsChatRouter.route(message, previousTurns: turns)
        return LetsChatPrompt.Inputs(
            message: message,
            route: route,
            previousTurns: turns,
            memory: memory,
            recentPages: recent,
            knowledgeNotes: BookKnowledgePromptBuilder.relevantNotes(for: message, limit: max(route.knowledgeLimit, 1))
        )
    }

    func testAGreetingPromptCarriesNoKnowledgeHeaderNoSearchAndStaysSmall() {
        let composed = LetsChatPrompt.compose(inputs("hi"), maxCharacters: 9_000)
        XCTAssertTrue(composed.fits)
        XCTAssertFalse(composed.prompt.contains("APP + BOOK KNOWLEDGE"))
        XCTAssertFalse(composed.prompt.contains("THINGS YOU KNOW"))
        XCTAssertFalse(composed.prompt.contains("WHAT YOU FOUND"))
        XCTAssertFalse(composed.prompt.contains("theatrical"))
        XCTAssertTrue(composed.prompt.contains("THEIR MESSAGE NOW:\nhi"))
        XCTAssertLessThan(composed.prompt.count, 5_500)
    }

    func testHistoryIsLabelledSoTheModelDoesNotCopyIt() {
        let turns = [AskTheBookTurn(prompt: "I bought a lamp", answer: "What kind of lamp?")]
        let composed = LetsChatPrompt.compose(inputs("a green one", turns: turns), maxCharacters: 9_000)
        XCTAssertTrue(composed.prompt.contains("never repeat any of it"))
        XCTAssertTrue(composed.prompt.contains("They said: I bought a lamp"))
        XCTAssertTrue(composed.prompt.contains("You said: What kind of lamp?"))
        XCTAssertFalse(composed.prompt.contains("TURN 1"))
    }

    func testAnArchiveAnswerContractNeverTellsTheModelToReadTheReaderBack() {
        let evidence = AskTheBookEvidence(
            result: StacksSearchResult(
                id: "page:harbour",
                kind: .keptPage,
                title: "Harbour wall",
                snippet: "Stood on the harbour wall",
                dateLabel: "Sep 1, 2026",
                score: 80,
                referenceID: "harbour"
            ),
            authority: .readerWords,
            excerpt: "Stood on the harbour wall until the lamps came on.",
            fullText: "Stood on the harbour wall until the lamps came on.",
            mayQuote: true
        )
        let memory = AskTheBookMemoryPacket(
            inquiryKind: .recall,
            evidence: [evidence],
            searchedRecordCount: 412,
            searchedWholeBook: true
        )
        let composed = LetsChatPrompt.compose(
            inputs("What did I write about the harbour wall?", memory: memory),
            maxCharacters: 9_000
        )
        XCTAssertTrue(composed.prompt.contains("searched 412 records"))
        XCTAssertTrue(composed.prompt.contains("don't read their sentence back"))
        XCTAssertFalse(composed.prompt.contains("You MUST use the strongest"))
    }

    func testComposeGivesUpTheWeakestIngredientsFirstAndKeepsTheRules() {
        let turns = (0..<6).map {
            AskTheBookTurn(prompt: "message \($0) " + String(repeating: "word ", count: 40), answer: String(repeating: "reply ", count: 40))
        }
        let roomy = LetsChatPrompt.compose(inputs("tell me about my lamp", turns: turns), maxCharacters: 20_000)
        let tight = LetsChatPrompt.compose(inputs("tell me about my lamp", turns: turns), maxCharacters: 4_200)

        XCTAssertTrue(roomy.fits)
        XCTAssertTrue(tight.fits)
        XCTAssertLessThan(tight.prompt.count, roomy.prompt.count)
        XCTAssertLessThan(tight.budget.historyTurns, roomy.budget.historyTurns)
        XCTAssertTrue(tight.prompt.contains("HOW YOU TALK:"))
        XCTAssertTrue(tight.prompt.contains("THEIR MESSAGE NOW:"))
    }
}

final class LetsChatSuggestionsTests: XCTestCase {
    func testStartersLeadWithTheBooksOwnPromptsAndNeverRepeat() {
        let starters = LetsChatSuggestions.starters(
            initiativePrompts: ["Tell me about the lamp.", "What are you thinking about?"],
            seed: 3
        )
        XCTAssertEqual(starters.first, "Tell me about the lamp.")
        XCTAssertEqual(starters.count, Set(starters).count)
        XCTAssertLessThanOrEqual(starters.count, 5)
    }

    func testFollowUpsRouteWhereTheyShouldGo() {
        for chip in ["Do you remember more about that?", "Ask me something instead."] {
            let route = LetsChatRouter.route(chip)
            XCTAssertFalse(route.action != nil, chip)
        }
        XCTAssertTrue(LetsChatRouter.route("Do you remember more about that?").needsArchive)
        XCTAssertFalse(LetsChatRouter.route("Ask me something instead.").needsArchive)
    }
}

final class LetsChatStatusCopyTests: XCTestCase {
    private func evidence(_ title: String) -> AskTheBookEvidence {
        AskTheBookEvidence(
            result: StacksSearchResult(
                id: "page:\(title)",
                kind: .keptPage,
                title: title,
                snippet: "",
                dateLabel: "",
                score: 1,
                referenceID: title
            ),
            authority: .readerWords,
            excerpt: "",
            fullText: "",
            mayQuote: true
        )
    }

    func testSearchReceiptCountsAndTheLeavesAreListedOneByOne() {
        XCTAssertEqual(
            LetsChatStatusCopy.searchedLine(records: 1412, evidence: []),
            "I went through 1,412 records. Nothing fit."
        )
        XCTAssertEqual(
            LetsChatStatusCopy.searchedLine(records: 9, evidence: [evidence("Harbour wall")]),
            "I went through 9 records. One fit:"
        )
        XCTAssertTrue(LetsChatStatusCopy.searchedLine(
            records: 9,
            evidence: [evidence("A"), evidence("B"), evidence("C")]
        ).hasSuffix("3 fit:"))
        let leaf = LetsChatStatusCopy.leafLine(for: evidence("Harbour wall"))
        XCTAssertEqual(leaf.title, "Harbour wall")
        XCTAssertTrue(leaf.detail.contains("Your words"))
    }

    func testLookingLineNamesTheWordsItSearchesWith() {
        let line = LetsChatStatusCopy.lookingLine(for: "What did I write about the harbour wall?")
        XCTAssertTrue(line.contains("“harbour”"))
        XCTAssertTrue(line.contains("“wall”"))
        XCTAssertFalse(line.contains("“the”"))
        XCTAssertEqual(LetsChatStatusCopy.lookingLine(for: "hi"), LetsChatStatusCopy.looking)
    }

    func testALongTitleIsShortened() {
        let long = String(repeating: "lantern ", count: 10)
        let leaf = LetsChatStatusCopy.leafLine(for: evidence(long))
        XCTAssertTrue(leaf.title.hasSuffix("…"))
        XCTAssertLessThanOrEqual(leaf.title.count, 31)
    }

    func testEveryStageHasALine() {
        for stage in [LetsChatStage.waking, .reading, .retrying] {
            XCTAssertFalse(LetsChatStatusCopy.line(for: stage).isEmpty)
        }
    }
}

final class LetsChatSelfTalkTests: XCTestCase {
    private func interiorWithFascination() -> BookInteriorState {
        var interior = BookInteriorState(awakenedAt: Date(timeIntervalSince1970: 1_700_000_000))
        interior.fascination = BookFascination(
            id: "f",
            facet: .notice,
            subject: "the kettle",
            line: "One exact ordinary detail has refused to become background.",
            evidencePageIDs: [],
            bornAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastDeepenedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        return interior
    }

    func testAGreetingPromptCarriesNoInnerLifeSoTheBookDoesNotTalkAboutItself() {
        let route = LetsChatRouter.route("Hey, good morning. How are you?")
        XCTAssertEqual(route.intent, .greeting)
        let composed = LetsChatPrompt.compose(
            LetsChatPrompt.Inputs(
                message: "Hey, good morning. How are you?",
                route: route,
                interior: interiorWithFascination(),
                now: Date(timeIntervalSince1970: 1_790_000_000),
                calendar: Calendar(identifier: .gregorian)
            ),
            maxCharacters: 9_000
        )
        XCTAssertFalse(composed.prompt.contains("refused to become background"))
        XCTAssertTrue(composed.prompt.contains("RIGHT NOW: it's "))
        XCTAssertTrue(composed.prompt.contains("They're greeting you."))
        XCTAssertTrue(composed.prompt.contains("Be specific."))
        XCTAssertFalse(composed.prompt.contains("RELATIONSHIP LAW"))
    }

    func testAQuestionAboutTheBookStillGetsItsInnerLife() {
        let route = LetsChatRouter.route("What are you thinking about?")
        XCTAssertEqual(route.intent, .aboutBook)
        let composed = LetsChatPrompt.compose(
            LetsChatPrompt.Inputs(
                message: "What are you thinking about?",
                route: route,
                interior: interiorWithFascination()
            ),
            maxCharacters: 9_000
        )
        XCTAssertTrue(composed.prompt.contains("the kettle"))
    }

    func testWhatDoYouThinkAboutMeIsAPortraitOfTheReaderNotTheBook() {
        for message in ["What do you think about me", "who am i to you?", "What have you noticed about me?"] {
            let route = LetsChatRouter.route(message)
            XCTAssertEqual(route.intent, .aboutReader, message)
            XCTAssertTrue(route.needsArchive, message)
            XCTAssertTrue(route.isPortrait, message)
        }
        XCTAssertFalse(LetsChatRouter.route("What do you think about my sister's wedding?").isPortrait)
    }

    func testPortraitDrawsOnTheReadersOwnRecentPagesAndFacts() {
        let base = Date(timeIntervalSince1970: 1_788_000_000)
        func page(_ id: String, _ type: BookPageType, _ text: String, _ days: Double) -> BookPage {
            BookPage(
                id: id,
                type: type,
                createdAt: base.addingTimeInterval(-days * 86_400),
                promptText: "p",
                userInput: text,
                sourceID: id,
                origin: .userAuthored,
                privacy: .privateLocal
            )
        }
        var dataset = StacksSearchDataset()
        dataset.days = [BookDay(id: "d", date: base, pages: [
            page("a", .diary, "Walked the long way home to keep the light a little longer.", 1),
            page("b", .diary, "Made soup from the three things left in the cupboard.", 2),
            page("c", .diary, "Read the same paragraph four times and loved it each time.", 3),
            page("d", .souvenir, "A heron stood in the car park like it owned the lease.", 4)
        ])]
        dataset.selfFacts = [SelfFact(
            id: "sf", questionID: "q", question: "What do you keep?",
            answer: "Tea tins.", bookTranslation: "They keep tea tins.",
            sensitivity: .delight, usePermission: .quoteAllowed, tags: [],
            createdAt: base, updatedAt: base
        )]

        let packet = AskTheBookMemoryRetriever.retrieve(
            query: "What do you think about me",
            previousTurns: [],
            from: dataset,
            semanticScorer: nil
        )
        XCTAssertEqual(packet.inquiryKind, .pattern)
        XCTAssertTrue(packet.evidence.contains { $0.result.referenceID == "sf" })
        XCTAssertTrue(packet.evidence.contains { $0.result.referenceID == "d" })
        // No more than two of one kind of page stands for the whole person.
        XCTAssertLessThanOrEqual(packet.evidence.filter { $0.result.title == "Diary" }.count, 2)
        // The portrait contract tells the model to say what it noticed.
        let contract = LetsChatPrompt.contract(for: packet, portrait: true)
        XCTAssertTrue(contract.contains("two or three specific things"))
    }
}

final class LetsChatPersonalityTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func interior() -> BookInteriorState {
        var state = BookInteriorState(awakenedAt: t0)
        state.fascination = BookFascination(
            id: "f", facet: .notice, subject: "the kettle",
            line: "One exact ordinary detail has refused to become background.",
            evidencePageIDs: [], bornAt: t0, lastDeepenedAt: t0
        )
        state.sharedJoke = "The ribbon denies everything."
        return state
    }

    func testThereIsSomethingToSayWhenTheBookHasAnInnerLifeAndNothingWhenItDoesNot() {
        XCTAssertFalse(LetsChatPersonality.candidates(from: interior()).isEmpty)
        XCTAssertTrue(LetsChatPersonality.candidates(from: BookInteriorState.unawakened).isEmpty)
        XCTAssertTrue(LetsChatPersonality.candidates(from: interior()).first?.line.contains("the kettle") == true)
    }

    func testItNeverSpeaksOverTheReadersMoment() {
        for message in ["What do you think about me", "remember that my dog is Biscuit"] {
            let route = LetsChatRouter.route(message)
            for turn in 0..<40 {
                XCTAssertNil(LetsChatPersonality.pick(
                    interior: interior(), route: route, message: message + "\(turn)",
                    turnCount: turn, turnsSinceLast: nil
                ), message)
            }
        }
    }

    func testItAppearsSometimesNotAlwaysAndMoreOftenInAHello() {
        func rate(_ message: String) -> Int {
            let route = LetsChatRouter.route(message)
            return (0..<200).filter {
                LetsChatPersonality.pick(
                    interior: interior(), route: route, message: message + " \($0)",
                    turnCount: $0 % 6, turnsSinceLast: nil
                ) != nil
            }.count
        }
        let hello = rate("hello there")
        let talk = rate("I bought a very ugly lamp today")
        XCTAssertGreaterThan(hello, 80)
        XCTAssertLessThan(hello, 190)
        XCTAssertGreaterThan(talk, 20)
        XCTAssertLessThan(talk, hello)
    }

    func testItRestsBetweenAppearances() {
        let route = LetsChatRouter.route("hello there")
        for turn in 0..<60 {
            XCTAssertNil(LetsChatPersonality.pick(
                interior: interior(), route: route, message: "hello there \(turn)",
                turnCount: turn, turnsSinceLast: LetsChatPersonality.restTurns - 1
            ))
        }
    }

    func testThePromptOffersOneThingNotTheWholeInnerLife() {
        let route = LetsChatRouter.route("hello there")
        let thought = LetsChatPersonality.candidates(from: interior()).first
        let withThought = LetsChatPrompt.compose(
            LetsChatPrompt.Inputs(message: "hello there", route: route, interior: interior(), onMyMind: thought),
            maxCharacters: 9_000
        )
        XCTAssertTrue(withThought.prompt.contains("ON YOUR MIND TODAY: You keep thinking about the kettle"))
        XCTAssertFalse(withThought.prompt.contains("Authored quirks"))

        let without = LetsChatPrompt.compose(
            LetsChatPrompt.Inputs(message: "hello there", route: route, interior: interior()),
            maxCharacters: 9_000
        )
        XCTAssertFalse(without.prompt.contains("ON YOUR MIND"))
        XCTAssertTrue(without.prompt.contains("You've got opinions."))
    }
}

final class LetsChatInvitationTests: XCTestCase {
    func testTheDeskLeafIsNotAlwaysAboutAsking() {
        let invitations = AskTheBookPageSourceAdapter.invitations
        XCTAssertGreaterThanOrEqual(invitations.count, 5)
        // Only one of them is the "ask me about your Pages" leaf.
        XCTAssertEqual(invitations.filter { $0.title.localizedCaseInsensitiveContains("ask me") }.count, 1)
        XCTAssertEqual(Set(invitations.map(\.title)).count, invitations.count)
    }

    func testEachDayPicksOneStablyAndDaysVary() {
        XCTAssertEqual(
            AskTheBookPageSourceAdapter.invitation(for: "2026-10-04"),
            AskTheBookPageSourceAdapter.invitation(for: "2026-10-04")
        )
        let titles = Set((1...28).map { AskTheBookPageSourceAdapter.invitation(for: "2026-10-\($0)").title })
        XCTAssertGreaterThan(titles.count, 3)
    }

    func testNoInvitationBansOrUsesTheWordsTheBookDoesNotSay() {
        for invitation in AskTheBookPageSourceAdapter.invitations {
            let text = (invitation.title + invitation.detail + invitation.body).lowercased()
            XCTAssertFalse(text.contains("hinge"))
            XCTAssertFalse(text.contains("ritual"))
        }
    }
}
