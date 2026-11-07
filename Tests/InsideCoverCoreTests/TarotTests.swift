import XCTest
@testable import InsideCoverCore

final class TarotTests: XCTestCase {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return state
        }
    }

    func testDeckContainsACompleteUniqueRWSDeck() {
        XCTAssertEqual(TarotDeck.all.count, 78)
        XCTAssertEqual(Set(TarotDeck.all.map(\.id)).count, 78)
        XCTAssertEqual(Set(TarotDeck.all.map(\.assetName)).count, 78)
        XCTAssertEqual(TarotDeck.all.filter { $0.arcana == .major }.count, 22)

        for suit in TarotSuit.allCases {
            XCTAssertEqual(TarotDeck.all.filter { $0.suit == suit }.count, 14)
        }
    }

    func testThreeCardDrawHasUniqueCardsInPositionOrder() {
        var generator = SeededGenerator(state: 42)
        let reading = TarotDrawEngine.draw(spread: .hereHiddenPossible, using: &generator)

        XCTAssertEqual(reading.cards.map(\.position), [.here, .hiding, .possible])
        XCTAssertEqual(Set(reading.cards.map(\.cardID)).count, 3)
        XCTAssertTrue(reading.cards.allSatisfy { !$0.isReversed })
    }

    func testDrawConsumesTheShuffledPacketInItsExistingOrder() throws {
        var generator = SeededGenerator(state: 217)
        let packet = TarotDrawEngine.shuffledCardIDs(using: &generator)
        let one = try XCTUnwrap(TarotDrawEngine.draw(spread: .oneCard, fromShuffledCardIDs: packet))
        let three = try XCTUnwrap(TarotDrawEngine.draw(spread: .hereHiddenPossible, fromShuffledCardIDs: packet))

        XCTAssertEqual(Set(packet), Set(TarotDeck.all.map(\.id)))
        XCTAssertEqual(one.cards.map(\.cardID), Array(packet.prefix(1)))
        XCTAssertEqual(three.cards.map(\.cardID), Array(packet.prefix(3)))
        XCTAssertEqual(three.cards.map(\.position), [.here, .hiding, .possible])
        XCTAssertEqual(packet.count, 78)
    }

    func testDamagedPacketsCannotDealAnIncompleteOrRepeatedDeck() {
        let complete = TarotDeck.all.map(\.id)
        var repeated = complete
        repeated[1] = repeated[0]
        var unknown = complete
        unknown[0] = "not-a-card"
        for packet in [[], Array(complete.dropLast()), repeated, unknown] {
            XCTAssertNil(TarotDrawEngine.draw(spread: .hereHiddenPossible, fromShuffledCardIDs: packet))
        }
    }

    func testReadingArtifactSurvivesCodableRoundTrip() throws {
        var generator = SeededGenerator(state: 7)
        var reading = TarotDrawEngine.draw(spread: .oneCard, using: &generator)
        reading.question = "What deserves attention?"
        reading.firstLook = "The yellow sky."
        reading.reflection = "Begin before I feel perfectly ready."
        reading = TarotLocalInterpreter.fillReveals(in: reading)

        let data = try JSONEncoder().encode(reading)
        let decoded = try JSONDecoder().decode(TarotReadingArtifact.self, from: data)

        XCTAssertEqual(decoded, reading)
        XCTAssertEqual(decoded.readerID, "serenity-brown")
        XCTAssertEqual(decoded.readerName, "Serenity Brown")
        XCTAssertTrue(decoded.archiveText.contains("The yellow sky."))
        XCTAssertFalse(decoded.revealProse?.values.first?.isEmpty ?? true)
    }

    func testCurrentThreeCardSpreadKeepsItsRolesThroughSaving() throws {
        var generator = SeededGenerator(state: 391)
        let reading = TarotLocalInterpreter.fillReveals(in:
            TarotDrawEngine.draw(spread: .hereHiddenPossible, using: &generator)
        )
        let restored = try JSONDecoder().decode(
            TarotReadingArtifact.self, from: JSONEncoder().encode(reading)
        )

        XCTAssertEqual(TarotSpread.allCases, [.oneCard, .hereHiddenPossible])
        XCTAssertEqual(restored.spread, .hereHiddenPossible)
        XCTAssertEqual(restored.cards.map(\.position), [.here, .hiding, .possible])
        XCTAssertEqual(restored.revealProse, reading.revealProse)
        XCTAssertTrue(restored.archiveText.contains("What’s Hiding:"))
        let notes = restored.cards.map { TarotLocalInterpreter.reveal(for: $0, in: restored) }
        XCTAssertTrue(notes[0].contains("brought to the table"))
        XCTAssertTrue(notes[1].contains("overlooked detail"))
        XCTAssertTrue(notes[2].contains("make room for"))
    }

    func testKeptRootWeatherDoorReadingRetainsItsOriginalMeaning() throws {
        let json = """
        {
          "schemaVersion": 3,
          "id": "kept-original-spread",
          "deckVersion": "unwritten-v3.2",
          "spread": "rootWeatherDoor",
          "drawnAt": 0,
          "question": "What deserves a beginning?",
          "cards": [
            {"cardID":"major-00","position":"root","isReversed":false},
            {"cardID":"major-18","position":"weather","isReversed":false},
            {"cardID":"cups-page","position":"door","isReversed":false}
          ],
          "firstLook": "The dog noticed.",
          "reflection": "Take the letters with me.",
          "revealProse": {"root-major-00":"The exact old margin note."}
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode(TarotReadingArtifact.self, from: Data(json.utf8))

        XCTAssertEqual(restored.spread.title, "Root · Weather · Door")
        XCTAssertEqual(restored.cards.map(\.position.title), ["Root", "Weather", "Door"])
        XCTAssertEqual(restored.revealProse?["root-major-00"], "The exact old margin note.")
        XCTAssertEqual(restored.firstLook, "The dog noticed.")
        XCTAssertEqual(restored.reflection, "Take the letters with me.")
        XCTAssertTrue(restored.archiveText.contains("Root: The Fool"))
        XCTAssertFalse(TarotSpread.allCases.contains(restored.spread))
    }

    func testLocalRevealChangesWithPositionAndHeldQuestionWithoutGemma() {
        let card = TarotDrawnCard(cardID: "major-00", position: .root, isReversed: false)
        let root = TarotReadingArtifact(
            spread: .rootWeatherDoor,
            question: "What deserves a beginning?",
            cards: [card]
        )
        let single = TarotReadingArtifact(
            spread: .oneCard,
            question: "",
            cards: [TarotDrawnCard(cardID: "major-00", position: .single, isReversed: false)]
        )

        let rootProse = TarotLocalInterpreter.reveal(for: card, in: root)
        let singleProse = TarotLocalInterpreter.reveal(for: single.cards[0], in: single)

        XCTAssertTrue(rootProse.contains("root"))
        XCTAssertTrue(rootProse.contains("What deserves a beginning?"))
        XCTAssertNotEqual(rootProse, singleProse)
    }

    func testVersionOneArtifactStillDecodesWithoutMoonshotFields() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "old-reading",
          "deckVersion": "rws-temporary-v1",
          "spread": "oneCard",
          "drawnAt": 0,
          "question": "",
          "cards": [{"cardID":"major-00","position":"single","isReversed":false}],
          "firstLook": "",
          "reflection": ""
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(TarotReadingArtifact.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.id, "old-reading")
        XCTAssertNil(decoded.readerID)
        XCTAssertNil(decoded.readerName)
        XCTAssertNil(decoded.auroraReading)
        XCTAssertNil(decoded.contextReceipt)
        XCTAssertNil(decoded.revealProse)
    }

    func testSerenityReadingContractKeepsHerVoiceAndTheExactQuestion() {
        let question = "What will Jasper Beach hold for Amanda and I today?"
        let directive = TarotReadingGuide.questionDirective(for: question)

        XCTAssertEqual(TarotReadingGuide.readerID, "serenity-brown")
        XCTAssertTrue(TarotReadingGuide.voiceContract.contains("joy is not a distraction"))
        XCTAssertTrue(TarotReadingGuide.voiceContract.contains("name the real thorn plainly"))
        XCTAssertTrue(directive.contains(question))
        XCTAssertTrue(directive.contains("Every later passage must remain about that question"))
        XCTAssertTrue(directive.contains("people, places, and concrete subject"))
    }

    func testSourceOffersAReadingFromAnEmptyArchiveAndOnceEachCalendarDay() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let oldPages = (0..<4).map { index in
            BookPage(
                id: "kept-\(index)",
                type: .souvenir,
                createdAt: now.addingTimeInterval(TimeInterval(-10 * 86_400 - index)),
                promptText: "Keep something.",
                userInput: "Something worth keeping."
            )
        }
        let archiveDay = BookDay(id: "archive", date: now.addingTimeInterval(-10 * 86_400), pages: oldPages)
        let today = BookDay(id: "today", date: now, pages: [])
        let context = CuratorContext.make(for: today)
        let adapter = TarotPageSourceAdapter()

        XCTAssertFalse(adapter.candidates(
            for: today, context: context, inputs: .empty, now: now
        ).isEmpty)

        var readyInputs = BookSourceInputs.empty
        readyInputs.days = [archiveDay]
        let surfaced = adapter.candidates(for: today, context: context, inputs: readyInputs, now: now)
        XCTAssertEqual(surfaced.first?.type, .tarot)
        XCTAssertEqual(surfaced.first?.renderStyle, .tarotReading)

        readyInputs.days[0].pages.append(
            BookPage(
                type: .tarot,
                createdAt: now.addingTimeInterval(-3_600),
                promptText: "Tarot Pages",
                userInput: "A reading."
            )
        )
        XCTAssertTrue(adapter.candidates(for: today, context: context, inputs: readyInputs, now: now).isEmpty)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let tomorrowDay = BookDay(id: "tomorrow", date: tomorrow, pages: [])
        let tomorrowContext = CuratorContext.make(for: tomorrowDay)
        XCTAssertFalse(adapter.candidates(
            for: tomorrowDay,
            context: tomorrowContext,
            inputs: readyInputs,
            now: tomorrow
        ).isEmpty)
    }

    func testDailyTarotClaimsAnOrdinaryDeskSlot() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        var inputs = BookSourceInputs.empty
        // An ordinary desk has no outstanding first-reading or earned-reader
        // promise. Tarot itself needs no kept-page prerequisite.
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.bookInterior = BookInteriorState(awakenedAt: now.addingTimeInterval(-86_400))
        let today = BookDay(id: "today", date: now, pages: [])

        let shelf = BookCurator.surfacedPages(for: today, inputs: inputs, now: now, limit: 3)

        XCTAssertTrue(shelf.contains { $0.type == .tarot })
    }

    func testTarotSourceIsRegisteredAndAdapted() {
        let source = BookPageSourceRegistry.source(for: .tarot)
        XCTAssertEqual(source.id, "tarot-pages")
        XCTAssertTrue(source.isActive)
        XCTAssertNotNil(BookPageSourceAdapters.adapter(for: .tarot))
    }
}
