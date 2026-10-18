import XCTest
@testable import InsideCoverCore

/// The Bleed is the daily edition: the morning paper reports yesterday, the evening paper
/// today so far, and both are set from the Reader's own kept pages. These guard the front
/// page, the assignment, the stop press and the puzzle made from the Reader's own week.
final class BleedDailyEditionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func bookDay(_ month: Int, _ day: Int, _ pages: [BookPage]) -> BookDay {
        let start = calendar.startOfDay(for: date(month, day))
        return BookDay(id: BookDay.id(for: start, calendar: calendar), date: start, pages: pages)
    }

    private let moth = "Found a moth asleep inside the lampshade. I left it there."

    private func yesterday() -> BookDay {
        bookDay(10, 15, [
            BookPage(id: "moth", type: .souvenir, createdAt: date(10, 15, 9), promptText: "One true sentence", userInput: moth),
            BookPage(id: "braid", type: .bookOfYou, createdAt: date(10, 15, 22), promptText: "Tonight",
                     userInput: "The Lampshade Tenant\n\nA moth had taken the lampshade for the winter.\n\nI kept the page: the moth kept the light on.")
        ])
    }

    private func inputs(name: String? = "Wren", days: [BookDay]) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = days
        if let name {
            inputs.selfFacts = [SelfFact(id: "name", questionID: "onboarding-name", question: "Your name?", answer: name,
                                         bookTranslation: name, sensitivity: .identity, usePermission: .quoteAllowed,
                                         tags: ["name"], createdAt: date(10, 1), updatedAt: date(10, 1))]
        }
        return inputs
    }

    // MARK: Headlines

    func testTheStorybookHeadingBecomesANewspaperHeadline() {
        XCTAssertEqual(BleedDayDesk.headline(fromHeading: "In which you found a moth asleep inside the lampshade", subject: "Wren"),
                       "Wren Found a Moth Asleep Inside the Lampshade")
        XCTAssertEqual(BleedDayDesk.headline(fromHeading: "In which there was a low grey sky", subject: "Wren"),
                       "Low Grey Sky Reported")
        XCTAssertEqual(BleedDayDesk.headline(fromHeading: "In which the card came home with your name still on it", subject: "Wren"),
                       "The Card Came Home with Wren's Name Still on It")
        XCTAssertEqual(BleedDayDesk.headline(fromHeading: "In which you kept a photograph", subject: "Local Reader"),
                       "Local Reader Kept a Photograph")
    }

    // MARK: The front page

    func testTheMorningFrontPageReportsYesterdayInTheReadersOwnWords() throws {
        let today = bookDay(10, 16, [])
        let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .morning, day: today,
            inputs: inputs(days: [yesterday()]), now: date(10, 16, 7), calendar: calendar))
        XCTAssertEqual(page.id, "front-page")
        XCTAssertTrue(page.byline.contains(BleedDayDesk.frontPageMark))
        // The night's kept line makes the headline, and isn't printed a second time below it.
        XCTAssertEqual(page.title, "The Moth Kept the Light On")
        XCTAssertFalse(page.composedBody.contains("I kept the page:"))
        XCTAssertTrue(page.composedBody.hasPrefix("THURSDAY — Wren's Thursday is on the record")
            || page.composedBody.hasPrefix("THURSDAY — "), page.composedBody)
        XCTAssertTrue(page.composedBody.contains("a night's braid"), page.composedBody)
        // The Reader's sentence prints whole, byte for byte, as the paper's source.
        XCTAssertTrue(page.composedBody.contains("“\(moth)”"), page.composedBody)
        XCTAssertTrue(page.composedBody.contains("The Lampshade Tenant"))
        XCTAssertTrue(page.composedBody.contains("The whole story is in the Book of You."))
        XCTAssertEqual(page.sourcePageIDs, ["moth"])
    }

    func testAQuietYesterdayLetsTheAcademyTakeTheTop() {
        let page = BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: []), now: date(10, 16, 7), calendar: calendar)
        XCTAssertNil(page)
    }

    func testAnEveningWithNothingKeptHoldsTheColumn() throws {
        let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .evening, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), now: date(10, 16, 18), calendar: calendar))
        XCTAssertEqual(page.title, "Our Correspondent Has Not Filed")
        XCTAssertTrue(page.composedBody.contains("holding the column"))
    }

    func testAReaderWithNoNameIsTheLocalReader() throws {
        // Without a braid the headline comes from the Reader's own detail, so it names them.
        let unbraided = bookDay(10, 15, yesterday().pages.filter { $0.type != .bookOfYou })
        let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(name: nil, days: [unbraided]), now: date(10, 16, 7), calendar: calendar))
        XCTAssertTrue(page.title.hasPrefix("Local Reader"), page.title)
    }

    func testTheFrontPageLeadsThePaper() {
        let briefs = BleedNewsroom.briefs(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), interest: nil, now: date(10, 16, 7), calendar: calendar, authored: [])
        XCTAssertEqual(briefs.first?.id, "front-page")
        // Its sentence is the paper's; no other desk prints the same page again.
        let reprinted = briefs.dropFirst().filter { ($0.sourcePageIDs ?? []).contains("moth") }
        XCTAssertTrue(reprinted.isEmpty)
    }

    // MARK: The assignment and the stop press

    func testTheMorningPaperSendsTheReaderOutAndTheEveningHandsTheDayToTheBraid() {
        let morning = BleedNewsroom.briefs(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), interest: nil, now: date(10, 16, 7), calendar: calendar, authored: [])
        XCTAssertTrue(morning.contains { $0.id == "assignment" })
        XCTAssertFalse(morning.contains { $0.id == "stop-press" })

        let evening = BleedNewsroom.briefs(kind: .evening, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), interest: nil, now: date(10, 16, 18), calendar: calendar, authored: [])
        XCTAssertFalse(evening.contains { $0.id == "assignment" })
        XCTAssertEqual(evening.last?.id, "stop-press")
    }

    // MARK: The puzzle from your own week

    func testTheMorningScramblesAreAnsweredInTheEveningFromTheSameWeek() throws {
        var week: [BookDay] = []
        let words = ["Lanterns glowing beside the harbour wall", "Pancakes burning while the kettle sang",
                     "Starlings gathered above the chimneys", "Marigolds flattened after the thunder"]
        for (offset, line) in words.enumerated() {
            week.append(bookDay(10, 12 + offset, [
                BookPage(id: "w\(offset)", type: .souvenir, createdAt: date(10, 12 + offset, 10),
                         promptText: "One true sentence", userInput: line)
            ]))
        }
        let today = bookDay(10, 16, [])
        let source = inputs(days: week)
        let question = try XCTUnwrap(BleedDayDesk.wordPuzzle(kind: .morning, day: today, inputs: source,
            now: date(10, 16, 7), calendar: calendar, history: []))
        XCTAssertEqual(question.title, "Scrambled from your week")
        let record = BleedPrintRecord(slotID: "bleed-\(today.id)-morning", printedAt: date(10, 16, 7), items: [
            .init(storyID: question.storyID!, revision: question.revision!, title: question.title,
                  body: question.composedBody, sourcePageIDs: [])
        ])
        let answer = try XCTUnwrap(BleedDayDesk.wordPuzzle(kind: .evening, day: today, inputs: source,
            now: date(10, 16, 18), calendar: calendar, history: [record]))
        let puzzle = try XCTUnwrap(BleedDayDesk.weekScrambles(day: today, inputs: source, calendar: calendar))
        for item in puzzle.items {
            XCTAssertTrue(question.composedBody.contains(item.scrambled))
            XCTAssertTrue(answer.composedBody.contains("\(item.scrambled) → \(item.answer)"))
        }
    }

    func testNoAnswerIsPrintedForAPuzzleNobodyWasAsked() {
        let answer = BleedDayDesk.wordPuzzle(kind: .evening, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), now: date(10, 16, 18), calendar: calendar, history: [])
        XCTAssertNil(answer)
    }

    // MARK: The rest of the paper

    func testTheEveningLeadsWithTheDispatchInTheReadersOwnWords() throws {
        var dare = BookPage(id: "dare", type: .wickerDare, createdAt: date(10, 16, 16),
                            promptText: "Lose a staring contest to a pigeon.", userInput: "The pigeon won. It knew it won.")
        dare.livedQuestReceipt = LivedQuestReceipt(
            kind: .wickerDare, questID: "pigeon", title: "The staring contest", invitation: "Lose a staring contest.",
            proofPrompt: "Who blinked?", facets: [], sourceTags: [], hasWrittenProof: true, hasVisualProof: false,
            completedAt: dare.createdAt, wasPromptedByBook: true)
        let today = bookDay(10, 16, [dare])
        let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .evening, day: today, inputs: inputs(days: [yesterday()]),
                                                        now: date(10, 16, 18), calendar: calendar))
        XCTAssertEqual(page.title, "Assignment Complete: The Staring Contest")
        XCTAssertTrue(page.byline.hasPrefix("Our correspondent returns"))
        XCTAssertTrue(page.composedBody.contains("“The pigeon won. It knew it won.”\n— Wren, filing from the field at 4:00 p.m."),
                      page.composedBody)
        XCTAssertEqual(page.sourcePageIDs?.first, "dare")
    }

    func testTheAcademyWritesInAboutWhatTheFrontPagePrinted() throws {
        let front = BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []), inputs: inputs(days: [yesterday()]),
                                           now: date(10, 16, 7), calendar: calendar)
        let letters = try XCTUnwrap(BleedDayDesk.lettersToTheEditor(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), now: date(10, 16, 7), calendar: calendar, history: [], front: front))
        XCTAssertEqual(letters.title, "The Academy Writes In")
        XCTAssertTrue(letters.composedBody.hasPrefix("Dear Editor,\n"), letters.composedBody)
        XCTAssertFalse(letters.composedBody.contains("{"), letters.composedBody)
        XCTAssertTrue(letters.storyID?.hasPrefix("cast-letter:") == true)
        // Printed once, a letter rests: the same letter never runs again within the month.
        let record = BleedPrintRecord(slotID: "yesterday", printedAt: date(10, 15, 7), items: [
            .init(storyID: letters.storyID ?? "", revision: letters.revision ?? "", title: letters.title,
                  body: letters.composedBody, sourcePageIDs: [])])
        let again = BleedDayDesk.lettersToTheEditor(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [yesterday()]), now: date(10, 16, 7), calendar: calendar, history: [record])
        XCTAssertNotEqual(again?.storyID, letters.storyID)
    }

    func testALetterNeverPlaysWithANameOrAWordTheFrontPageDidNotPrint() throws {
        let day = bookDay(10, 15, [BookPage(id: "amanda", type: .souvenir, createdAt: date(10, 15, 9),
                                            promptText: "One true sentence", userInput: "Walked the dog with Amanda before breakfast.")])
        for seed in 0..<12 {
            var inputs = inputs(days: [day])
            inputs.entityBeliefOffsets = ["professor-thaddeus-mook": seed * 40]
            let front = BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []), inputs: inputs,
                                               now: date(10, 16, 7), calendar: calendar)
            let letters = BleedDayDesk.lettersToTheEditor(kind: .morning, day: bookDay(10, 16, []), inputs: inputs,
                                                          now: date(10, 16, 7), calendar: calendar, history: [], front: front)
            XCTAssertFalse(letters?.composedBody.contains("Amanda") ?? false, letters?.composedBody ?? "")
            // Without the front page's quotations, no letter claims a word appeared there.
            let blind = BleedDayDesk.lettersToTheEditor(kind: .morning, day: bookDay(10, 16, []), inputs: inputs,
                                                        now: date(10, 16, 7), calendar: calendar, history: [])
            XCTAssertFalse(blind?.composedBody.contains("appears on your front page") ?? false)
        }
    }

    func testEveryCastLetterFillsAllItsSlots() {
        let slots = ["subject": "Wren", "possessive": "Wren's", "weekday": "Friday", "word": "heron",
                     "sky": "drizzle", "Sky": "Drizzle", "braid": "The Lampshade Tenant", "spell": "A Small Kindling"]
        for letter in BleedDayDesk.castLetters {
            var text = letter.text
            for (key, value) in slots { text = text.replacingOccurrences(of: "{\(key)}", with: value) }
            XCTAssertFalse(text.contains("{"), letter.text)
            XCTAssertFalse(text.lowercased().contains("hinge"))
            XCTAssertFalse(text.lowercased().contains("ritual"))
        }
    }

    func testAMarginLetterPrintsInTheNextPaperWithPennysReply() throws {
        // A kept paper saves the whole printed paper, then the margin.
        var kept = BookPage(id: "paper", type: .theBleed, createdAt: date(10, 15, 19),
                            promptText: "The Evening Edition, unfolded.",
                            userInput: "THE BLEED - EVENING EDITION\n\n— Wren Fed the Heron —\nLate final\n\nThe whole paper.\n\nMargin note: Is the heron by the canal the same heron?")
        kept.metadata = ["bleedEditionKind": "evening"]
        let diary = BookPage(id: "diary", type: .souvenir, createdAt: date(10, 15, 9), promptText: "One true sentence",
                             userInput: "A private thought about the canal.")
        let letter = try XCTUnwrap(BleedNewsroom.correspondence(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [bookDay(10, 15, [diary, kept])]), history: [], now: date(10, 16, 7), calendar: calendar))
        XCTAssertEqual(letter.sourcePageIDs, ["paper"])
        let fallback = try XCTUnwrap(letter.fallbackBody)
        XCTAssertTrue(fallback.hasPrefix("“Is the heron by the canal the same heron?”\n— Wren, written in the margin of Thursday's evening paper"), fallback)
        XCTAssertTrue(fallback.contains("The editor replies: "))
    }

    func testWhispersPrintWhatTheAcademyWasToldOnlyOnce() throws {
        var inputs = inputs(days: [])
        inputs.castStoryMemories = CastStoryMemoryLedger(memories: [CastStoryMemory(
            id: "run|bread|zara-finch", entityID: "zara-finch", key: "bread", memory: "Wicker shared the bread.",
            aside: "Pippa says Wicker gave Serenity the bigger half of the bread.", witness: .heard,
            storyTitle: "The Count Unbound", momentTitle: "Lunch", runID: "run", sourceID: "x",
            happenedAt: date(10, 15, 13), frozenAt: date(10, 15, 13), heardFromID: "pippa-pilcrow", heardFromName: "Pippa")])
        let whispers = try XCTUnwrap(BleedDayDesk.whispers(day: bookDay(10, 16, []), inputs: inputs, now: date(10, 16, 7), history: []))
        XCTAssertTrue(whispers.composedBody.hasPrefix("“Pippa says Wicker gave Serenity the bigger half of the bread.”\n— Zara, overheard"),
                      whispers.composedBody)
        let record = BleedPrintRecord(slotID: "m", printedAt: date(10, 16, 7), items: [
            .init(storyID: whispers.storyID ?? "", revision: "", title: whispers.title, body: whispers.composedBody,
                  sourcePageIDs: whispers.sourcePageIDs ?? [])])
        XCTAssertNil(BleedDayDesk.whispers(day: bookDay(10, 16, []), inputs: inputs, now: date(10, 16, 18), history: [record]))
    }

    func testTheMorningTheWeekIsBoundPrintsItsFrontPages() throws {
        var inputs = inputs(days: (9...15).map { day in
            bookDay(10, day, [BookPage(id: "p\(day)", type: .souvenir, createdAt: date(10, day, 9),
                                       promptText: "One true sentence", userInput: "Found a blue button on the stairs number \(day).")])
        })
        inputs.publicationEpoch = BookPublicationEpoch(readerWeekAnchorDayID: BookDay.id(for: date(10, 9), calendar: calendar),
                                                       timeZoneIdentifier: calendar.timeZone.identifier, establishedAt: date(10, 9))
        let bound = try XCTUnwrap(BleedDayDesk.weekBound(kind: .morning, day: bookDay(10, 16, []), inputs: inputs,
                                                          now: date(10, 16, 7), calendar: calendar))
        XCTAssertEqual(bound.title, "This Week's Tale Is Bound")
        XCTAssertEqual(bound.composedBody.components(separatedBy: "\n").filter { $0.contains(" · ") }.count, 7)
        XCTAssertNil(BleedDayDesk.weekBound(kind: .morning, day: bookDay(10, 17, []), inputs: inputs,
                                            now: date(10, 17, 7), calendar: calendar))
    }

    func testTheEveningAnswersOnlyTheClassifiedTheMorningPlaced() throws {
        let morning = try XCTUnwrap(BleedDayDesk.castClassified(kind: .morning, now: date(10, 16, 7), calendar: calendar, history: []))
        XCTAssertNil(BleedDayDesk.castClassified(kind: .evening, now: date(10, 16, 18), calendar: calendar, history: []))
        let record = BleedPrintRecord(slotID: "m", printedAt: date(10, 16, 7), items: [
            .init(storyID: morning.storyID ?? "", revision: "", title: morning.title, body: morning.composedBody, sourcePageIDs: [])])
        let evening = try XCTUnwrap(BleedDayDesk.castClassified(kind: .evening, now: date(10, 16, 18), calendar: calendar, history: [record]))
        let id = morning.storyID?.components(separatedBy: ":").last
        XCTAssertEqual(evening.storyID, "cast-classified-evening:\(id ?? "")")
        XCTAssertEqual(BleedPrintDesign.piece(title: evening.title, byline: evening.byline), .classifieds)
    }

    func testAMonthsPackPlacesItsOwnClassifiedsAndLettersOnlyWhileItRuns() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let pack = try ContentPackFileLocator.decoder().decode(WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
        let event = try XCTUnwrap(pack.events.first)
        let live = ResolvedWorldEvent(id: event.id, packID: pack.id, title: event.title, subtitle: event.subtitle,
            phase: try XCTUnwrap(event.phases.first), startedAt: date(10, 1), endsAt: date(10, 31), progress: 0.5,
            playerTouchCount: 0, playerTouchCounts: nil, outcome: nil, effects: [], packet: event.packet)
        var inputs = inputs(days: [yesterday()])
        inputs.authoredBleedArticles = [
            AuthoredBleedArticle(id: "ad-quill", packID: pack.id, eventID: event.id, title: "Classified", byline: "",
                                 body: "LOST: One quill, answers to Feathers.", tags: ["classified"],
                                 reply: "FOUND: Feathers, in the Kitchens, writing a menu."),
            AuthoredBleedArticle(id: "letter-wicker", packID: pack.id, eventID: event.id, title: "Letter",
                                 byline: "W. Eddies, still in the Vault", body: "I read your front page in the dark. It glowed. I'm told that's normal.",
                                 tags: ["cast-letter", "cast:wicker-eddies", "cue:quiet"])
        ]
        // Not the month's: nothing from the pack prints.
        let idle = try XCTUnwrap(BleedDayDesk.castClassified(kind: .morning, now: date(10, 16, 7), calendar: calendar,
                                                              history: [], inputs: inputs))
        XCTAssertNotEqual(idle.storyID, "cast-classified-morning:ad-quill")
        inputs.activeWorldEvents = [live]
        let ad = try XCTUnwrap(BleedDayDesk.castClassified(kind: .morning, now: date(10, 16, 7), calendar: calendar,
                                                            history: [], inputs: inputs))
        XCTAssertEqual(ad.composedBody, "LOST: One quill, answers to Feathers.")
        let record = BleedPrintRecord(slotID: "m", printedAt: date(10, 16, 7), items: [
            .init(storyID: ad.storyID ?? "", revision: "", title: ad.title, body: ad.composedBody, sourcePageIDs: [])])
        XCTAssertEqual(BleedDayDesk.castClassified(kind: .evening, now: date(10, 16, 18), calendar: calendar,
                                                   history: [record], inputs: inputs)?.composedBody,
                       "FOUND: Feathers, in the Kitchens, writing a menu.")
        XCTAssertEqual(BleedDayDesk.packLetters(inputs: inputs).map(\.signature), ["W. Eddies, still in the Vault"])
        // A desk piece never prints as a standalone feature.
        XCTAssertTrue(inputs.authoredBleedArticles.allSatisfy(\.isDeskPiece))
    }

    func testTheMonthsFrontPagesKeepOnePerDayAndSkipUnfiledDays() {
        func record(_ day: Int, _ kind: BleedEditionKind, _ headline: String, printed: Int, month: Int = 10) -> BleedFrontPageRecord {
            BleedFrontPageRecord(reportedDayID: BookDay.id(for: date(month, day), calendar: calendar), kind: kind,
                                 printedAt: date(month, printed, kind == .morning ? 7 : 18), issueNumber: nil,
                                 kicker: "Exclusive", headline: headline)
        }
        var ledger: [BleedFrontPageRecord] = []
        for item in [record(5, .evening, "Today, so far", printed: 5), record(5, .morning, "The Moth Kept the Light On", printed: 6),
                     record(6, .evening, BleedDayDesk.unfiledHeadline, printed: 6), record(7, .evening, "Wren Fed the Heron", printed: 7),
                     record(30, .morning, "September Thing", printed: 30, month: 9)] {
            ledger = BleedFrontPageRecord.remembering(item, in: ledger)
        }
        // A reprint of the same slot replaces itself.
        ledger = BleedFrontPageRecord.remembering(record(5, .morning, "The Moth Kept the Light On", printed: 6), in: ledger)
        XCTAssertEqual(ledger.count, 5)
        let october = BleedFrontPageRecord.month(of: date(10, 1), in: ledger, calendar: calendar)
        XCTAssertEqual(october.map(\.headline), ["The Moth Kept the Light On", "Wren Fed the Heron"])
    }

    func testTodaysPaperOpensTheDareItPrintedEvenAfterTheDeskMovesOn() throws {
        let inputs = inputs(days: [yesterday()])
        let today = bookDay(10, 16, [])
        let paper = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(for: today, inputs: inputs,
            now: date(10, 16, 7), calendar: calendar, settingTheType: true))
        let dareID = try XCTUnwrap(BleedDayDesk.assignedDareID(in: paper))
        XCTAssertTrue(BleedDayDesk.assignmentIsOpen(in: paper, now: date(10, 16, 15), calendar: calendar))
        XCTAssertFalse(BleedDayDesk.assignmentIsOpen(in: paper, now: date(10, 17, 9), calendar: calendar))
        // The afternoon desk rotates its dare; the paper's door still opens the one it printed.
        let opened = try XCTUnwrap(BleedDayDesk.assignmentSurface(for: paper, day: today, inputs: inputs, now: date(10, 16, 15)))
        XCTAssertEqual(opened.payload.metadata["wickerDareID"], dareID)
        XCTAssertNotNil(opened.payload.metadata["bleedAssignment"])
    }

    func testAKeptPaperWithNothingInItsMarginIsNeverALetter() {
        let kept = BookPage(id: "paper", type: .theBleed, createdAt: date(10, 15, 19), promptText: "The Evening Edition, unfolded.",
                            userInput: "THE BLEED - EVENING EDITION\n\n— Wren Fed the Heron —\nLate final\n\nThe whole paper.")
        XCTAssertFalse(BleedNewsroom.isCorrespondence(kept))
        XCTAssertNil(BleedNewsroom.correspondence(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [bookDay(10, 15, [kept])]), history: [], now: date(10, 16, 7), calendar: calendar))
    }
}
