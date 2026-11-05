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
                       "Low Grey Sky")
        XCTAssertEqual(BleedDayDesk.headline(fromHeading: "In which the card came home with your name still on it", subject: "Wren"),
                       "The Card Came Home with Wren's Name Still on It")
        XCTAssertEqual(BleedDayDesk.headline(fromHeading: "In which you kept a photograph", subject: "Local Reader"),
                       "Local Reader Kept a Photograph")
    }

    func testAFirstPersonFragmentNeverBecomesAThing() {
        // Without the tagger's assets this was "In which there was a you like",
        // and the front page printed "You Like Reported".
        let heading = WeeklyTaleBuilder.readerThingHeading("I like being called the night light")
        XCTAssertFalse(heading?.lowercased().contains("you like") ?? false, heading ?? "")
        XCTAssertNil(WeeklyTaleBuilder.readerThingHeading("I like it"))
    }

    // MARK: The front page

    func testADayWithNoStoryInItQuotesTheReader() throws {
        let line = "I like being called the night light."
        let day = bookDay(10, 15, [BookPage(id: "light", type: .souvenir, createdAt: date(10, 15, 9),
                                            promptText: "One true sentence", userInput: line)])
        let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [day]), now: date(10, 16, 7), calendar: calendar))
        XCTAssertEqual(page.title, "“I like being called the night light,” says Wren")
        XCTAssertTrue(page.byline.hasPrefix("In their own words"), page.byline)
    }

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

    func testTodaysPaperOpensTheAssignmentItPrintedEvenAfterTheDeskMovesOn() throws {
        let inputs = inputs(days: [yesterday()])
        let today = bookDay(10, 16, [])
        let paper = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(for: today, inputs: inputs,
            now: date(10, 16, 7), calendar: calendar, settingTheType: true))
        let dareID = try XCTUnwrap(BleedDayDesk.assignedDareID(in: paper))
        XCTAssertTrue(BleedDayDesk.assignmentIsOpen(in: paper, now: date(10, 16, 15), calendar: calendar))
        XCTAssertFalse(BleedDayDesk.assignmentIsOpen(in: paper, now: date(10, 17, 9), calendar: calendar))
        // The afternoon desk rotates; the paper retains its exact assignment family and ask.
        let opened = try XCTUnwrap(BleedDayDesk.assignmentSurface(for: paper, day: today, inputs: inputs, now: date(10, 16, 15)))
        XCTAssertEqual(BleedDayDesk.assignmentDetails(opened).id, dareID)
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

// MARK: - Real headlines, a real lead, and the numbers

extension BleedDailyEditionTests {
    /// A day as the phone braided it without the tagger: the braid titled from
    /// the first four words, and a plain sentence the Reader wrote.
    private func untaggedBraid(title: String) -> BookDay {
        bookDay(10, 15, [
            BookPage(id: "hangout", type: .souvenir, createdAt: date(10, 15, 9), promptText: "One true sentence",
                     userInput: "Sunday hangout days are my favorite."),
            BookPage(id: "braid", type: .bookOfYou, createdAt: date(10, 15, 22), promptText: "Tonight",
                     userInput: "\(title)\n\nThe afternoon went long and nobody minded.")
        ])
    }

    func testTheFallbackFragmentRefusesPronounsAndVerbs() {
        XCTAssertNil(BraidScenePlan.printableFallback(["You", "like", "being", "called"]))
        XCTAssertNil(BraidScenePlan.printableFallback(["Me", "also", "watching", "YouTube"]))
        XCTAssertNil(BraidScenePlan.printableFallback(["You", "like"]))
        XCTAssertNil(BraidScenePlan.printableFallback(["Like"]))
        XCTAssertEqual(BraidScenePlan.printableFallback(["Risk"]), "Risk")
        XCTAssertEqual(BraidScenePlan.printableFallback(["Brass", "lamp", "by", "window"]), "Brass lamp by window")
    }

    func testOnlyAThingIsAPrintableHeadline() {
        XCTAssertFalse(BleedDayDesk.isPrintableHeadline("You Like"))
        XCTAssertFalse(BleedDayDesk.isPrintableHeadline("You Also Watching YouTube"))
        XCTAssertFalse(BleedDayDesk.isPrintableHeadline("A Quiet Night"))
        XCTAssertFalse(BleedDayDesk.isPrintableHeadline("Moth"))
        XCTAssertTrue(BleedDayDesk.isPrintableHeadline("The Lampshade Tenant"))
    }

    func testABraidTitledFromThePronounNeverLeads() throws {
        for title in ["You like", "You also watching YouTube", "Me also watching YouTube"] {
            let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []),
                inputs: inputs(days: [untaggedBraid(title: title)]), now: date(10, 16, 7), calendar: calendar))
            XCTAssertFalse(page.title.lowercased().contains(title.lowercased()), page.title)
            // The Reader's own whole sentence leads instead, the way a paper quotes a witness.
            XCTAssertEqual(page.title, "“Sunday hangout days are my favorite,” says Wren")
            XCTAssertTrue(page.byline.hasPrefix("In their own words"), page.byline)
        }
    }

    func testTheLastResortHeadingIsNeverAHeadline() throws {
        let day = bookDay(10, 15, [BookPage(id: "fine", type: .souvenir, createdAt: date(10, 15, 9),
                                            promptText: "One true sentence", userInput: "Fine.")])
        let page = try XCTUnwrap(BleedDayDesk.frontPage(kind: .morning, day: bookDay(10, 16, []),
            inputs: inputs(days: [day]), now: date(10, 16, 7), calendar: calendar))
        XCTAssertFalse(page.title.localizedCaseInsensitiveContains("small things"), page.title)
        XCTAssertEqual(page.dayStrength, 0)
    }

    // MARK: The lead

    private func greyThreat(hoursLeft: Double, now: Date) -> GreyPageThreatLedger {
        GreyPageThreatLedger(threats: [GreyPageThreat(
            id: "grey-page-moth", pageID: "moth", pageTitle: "One true sentence", pageExcerpt: moth,
            markedAt: now.addingTimeInterval(-86_400), deadline: now.addingTimeInterval(hoursLeft * 3_600),
            status: .fading, resolvedAt: nil, rescueLine: nil)], lastMarkedAt: now.addingTimeInterval(-86_400))
    }

    private func argument(movedAt: Date, embarrassed: Bool = false) -> ContestedQuestion {
        ContestedQuestion(
            id: "heron", question: "Who frightened the heron off the canal?", aboutMovementIDs: [],
            positions: [
                ContestedPosition(id: "a", holderID: "penny-blackletter", holderName: "Penny", claim: "The bell did it.",
                                  groundedInIDs: [], confidence: 60, silence: .none, formedAt: movedAt),
                ContestedPosition(id: "b", holderID: "wicker", holderName: "Wicker", claim: "Nobody did. It was bored.",
                                  groundedInIDs: [], confidence: 30, silence: .none, formedAt: movedAt)
            ],
            bookPosition: "A private guess about the bell.", bookBackedHolderID: "penny-blackletter",
            status: .open, openedAt: movedAt, lastMovedAt: movedAt,
            embarrassedHolderID: embarrassed ? "penny-blackletter" : nil)
    }

    private func pool(_ inputs: BookSourceInputs, kind: BleedEditionKind = .morning, hour: Int = 7) -> [BleedColumnBrief] {
        BleedNewsroom.briefs(kind: kind, day: bookDay(10, 16, []), inputs: inputs, interest: nil,
                             now: date(10, 16, hour), calendar: calendar, authored: [])
    }

    func testAGreyPageBeatsYourDayAndYourDayGoesInTheBox() throws {
        var inputs = inputs(days: [yesterday()])
        inputs.greyPageThreats = greyThreat(hoursLeft: 31, now: date(10, 16, 7))
        let briefs = pool(inputs)
        let lead = try XCTUnwrap(briefs.first)
        XCTAssertEqual(lead.id, "front-page")
        XCTAssertEqual(lead.title, "Thursday's Page Has Gone Grey")
        XCTAssertTrue(lead.byline.hasPrefix("Grey Page Watch"), lead.byline)
        XCTAssertTrue(lead.composedBody.contains("31 hours"), lead.composedBody)
        // The Reader's excerpt is never copied into the paper.
        XCTAssertFalse(lead.composedBody.contains("lampshade"), lead.composedBody)
        XCTAssertEqual(BleedLeadDesk.subject(ofStory: lead.storyID ?? ""), "grey-page:grey-page-moth")
        let note = try XCTUnwrap(briefs.dropFirst().first)
        XCTAssertEqual(note.id, BleedLeadDesk.noteID)
        XCTAssertTrue(note.composedBody.contains("“\(moth)”"), note.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: note.title, byline: note.byline), .note)
        // The month's front pages still find a lead that wasn't the day.
        XCTAssertNotNil(BleedFrontPageRecord.from(columns: briefs, kind: .morning, issueNumber: 3, printedAt: date(10, 16, 7)))
    }

    func testAStrongDayBeatsTheAcademyArgumentAndALeftoverDayDoesNot() throws {
        var strong = inputs(days: [yesterday()])
        strong.contestedQuestions = [argument(movedAt: date(10, 16, 6))]
        XCTAssertEqual(pool(strong).first?.title, "The Moth Kept the Light On")

        let leftovers = bookDay(10, 15, [BookPage(id: "fine", type: .souvenir, createdAt: date(10, 15, 9),
                                                  promptText: "One true sentence", userInput: "Fine.")])
        var weak = inputs(days: [leftovers])
        weak.contestedQuestions = [argument(movedAt: date(10, 16, 6))]
        let lead = try XCTUnwrap(pool(weak).first)
        XCTAssertEqual(lead.title, "Who Frightened the Heron off the Canal?")
        // An argument is written as a feature: its facts are the packet, its own telling the fallback.
        let told = lead.fallbackBody ?? ""
        XCTAssertTrue(told.contains("Wicker says: Nobody did."), told)
        XCTAssertFalse(told.contains("private guess"), told)
        XCTAssertFalse(lead.packet.contains("private guess"), lead.packet)
        XCTAssertFalse(pool(weak).contains { $0.storyID == "academy-question:heron" })
    }

    func testTheBookCaughtOutLeadsAsACorrection() throws {
        var inputs = inputs(days: [])
        inputs.contestedQuestions = [argument(movedAt: date(10, 16, 6), embarrassed: true)]
        let lead = try XCTUnwrap(pool(inputs).first)
        XCTAssertEqual(lead.title, "The Book Was Wrong About the Heron")
        XCTAssertTrue(lead.byline.hasPrefix("The Book stands corrected"), lead.byline)
    }

    func testNoStoryLeadsTwoPapersRunning() throws {
        var inputs = inputs(days: [yesterday()])
        let now = date(10, 16, 7)
        inputs.greyPageThreats = greyThreat(hoursLeft: 31, now: now)
        inputs.bleedPrintHistory = [BleedPrintRecord(slotID: "evening-15", printedAt: date(10, 15, 18), items: [
            .init(storyID: "front-page:2026-10-15:evening:grey-page:grey-page-moth", revision: "x",
                  title: "Thursday's Page Has Gone Grey", body: "", sourcePageIDs: [])
        ])]
        let lead = try XCTUnwrap(pool(inputs).first)
        XCTAssertNil(BleedLeadDesk.subject(ofStory: lead.storyID ?? ""), lead.title)
        XCTAssertEqual(lead.title, "The Moth Kept the Light On")
    }

    // MARK: The numbers

    func testAShelfThatChangedHandsIsFoundFromTheLastSnapshot() throws {
        var war = PactWarState()
        war.adjust("moss-clasp", "shelf-care", by: 40)
        war.adjust("ember-seal", "shelf-care", by: 25)
        war.adjust("tide-glass", "shelf-story", by: 12)
        war.adjust("dusk-thorn", "shelf-story", by: 10)
        let history = [BleedPrintRecord(slotID: "evening-15", printedAt: date(10, 15, 18), items: [
            .init(storyID: BleedDataDesk.warID, revision: "x", title: "The Pact War Report", body: "", sourcePageIDs: [],
                  snapshot: ["pact:shelf-care": "ember-seal", "pact:shelf-story": "tide-glass"])
        ])]
        let flips = BleedDataDesk.flips(war: war, history: history)
        XCTAssertEqual(flips.map(\.territory), ["shelf-care"])
        XCTAssertEqual(flips.first?.to, "moss-clasp")
        // No snapshot, no claim.
        XCTAssertTrue(BleedDataDesk.flips(war: war, history: []).isEmpty)

        var inputs = BookSourceInputs.empty
        inputs.pactWar = war
        let report = try XCTUnwrap(BleedDataDesk.pactWarReport(inputs: inputs, now: date(10, 16, 7), calendar: calendar, history: history))
        XCTAssertTrue(report.composedBody.hasPrefix("TERRITORY · HELD BY · CONTROL"), report.composedBody)
        XCTAssertTrue(report.composedBody.contains("Care Shelf · Moss Clasp · 40 (+15)"), report.composedBody)
        XCTAssertTrue(report.composedBody.contains("Changed hands since the last paper: The Moss Clasp took the Care Shelf from the Ember Seal."),
                      report.composedBody)
        XCTAssertTrue(report.composedBody.contains("Closest fight: the Story Shelf, where the Tide Glass leads the Dusk Thorn by 2."), report.composedBody)
        XCTAssertEqual(report.snapshot?["pact:shelf-care"], "moss-clasp")
        XCTAssertEqual(BleedPrintDesign.piece(title: report.title, byline: report.byline), .warReport)
        XCTAssertNil(BleedDataDesk.pactWarReport(inputs: .empty, now: date(10, 16, 7), calendar: calendar, history: []))
    }

    func testOddsAreChalkedLikeABookmakersAndYesterdaysBetsSettle() throws {
        XCTAssertEqual(BleedDataDesk.formatted(BleedDataDesk.price(for: 0.5)), "Evens")
        XCTAssertEqual(BleedDataDesk.formatted(BleedDataDesk.price(for: 0.25)), "3–1")
        XCTAssertEqual(BleedDataDesk.formatted(BleedDataDesk.price(for: 0.09)), "10–1")
        XCTAssertEqual(BleedDataDesk.formatted(BleedDataDesk.price(for: 0.67)), "1–2")

        let now = date(10, 16, 7)
        let stages = (0..<5).map { CastUndertakingStage(id: "s\($0)", line: "Step \($0).", trace: "", tags: []) }
        let zara = CastUndertaking(id: "zara-maps", actorID: "zara", title: "The Lost Map", pursuit: "Find it", why: "Because",
                                   stages: stages, stageIndex: 2, status: .active, startedAt: date(10, 1),
                                   lastAdvancedAt: date(10, 15, 20), nextEligibleAt: now.addingTimeInterval(3_600), ladderID: "test")
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [zara]
        let deadline = Int(date(10, 15, 23).timeIntervalSince1970)
        let history = [BleedPrintRecord(slotID: "evening-15", printedAt: date(10, 15, 18), items: [
            .init(storyID: BleedDataDesk.oddsID, revision: "x", title: "Story Odds", body: "", sourcePageIDs: [],
                  snapshot: ["odds:u:zara-maps": "1|3|1|\(deadline)"])
        ])]
        let odds = try XCTUnwrap(BleedDataDesk.storyOdds(inputs: inputs, now: now, calendar: calendar, history: history))
        XCTAssertTrue(odds.composedBody.contains("Settled: the last paper gave"), odds.composedBody)
        XCTAssertTrue(odds.composedBody.contains("3–1 on the next step. It came in."), odds.composedBody)
        XCTAssertTrue(odds.composedBody.contains("reach the next step of the Lost Map by"), odds.composedBody)
        XCTAssertNotNil(odds.snapshot?["odds:u:zara-maps"])
        XCTAssertEqual(BleedPrintDesign.piece(title: odds.title, byline: odds.byline), .odds)
        // The paper never guesses a pronoun for a Cast member.
        XCTAssertFalse(odds.composedBody.contains(" She ") || odds.composedBody.contains(" He "), odds.composedBody)
    }

    func testTheWordMarketTradesWordsNotStopWordsOrSadOnes() throws {
        func diary(_ m: Int, _ d: Int, _ text: String) -> BookDay {
            bookDay(m, d, [BookPage(id: "d-\(m)-\(d)", type: .diary, createdAt: date(m, d, 9), promptText: "Diary", userInput: text)])
        }
        // Last week the hospital came up every day; this week moss did.
        // A verb going quiet isn't a word leaving the market: it trades in things.
        let lastWeek = (6...9).map { diary(10, $0, "Really long day. Had to stop at the hospital again. Really.") }
        let thisWeek = (12...15).map { diary(10, $0, "Moss on the wall by the gate. Really green moss.") }
        let older = [diary(9, 20, "Kettle and a quiet porch.")]
        let market = try XCTUnwrap(BleedDataDesk.wordMarket(day: bookDay(10, 16, []), inputs: inputs(days: older + lastWeek + thisWeek),
                                                            now: date(10, 16, 7), calendar: calendar, history: []))
        XCTAssertTrue(market.composedBody.contains("MOSS ▲ · 4 days running"), market.composedBody)
        XCTAssertFalse(market.composedBody.contains("HOSPITAL"), market.composedBody)
        XCTAssertFalse(market.composedBody.contains("REALLY"), market.composedBody)
        XCTAssertFalse(market.composedBody.contains("STOP"), market.composedBody)
        XCTAssertTrue(market.composedBody.contains("Moss keeps coming back") || market.composedBody.contains("Moss is up again"),
                      market.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: market.title, byline: market.byline), .market)
        // Fewer than three kept days: no market.
        XCTAssertNil(BleedDataDesk.wordMarket(day: bookDay(10, 16, []), inputs: inputs(days: Array(thisWeek.prefix(2))),
                                              now: date(10, 16, 7), calendar: calendar, history: []))
    }

    func testAHardDayPrintsNoLeadStoryAndNoNumbers() {
        var hardDay = yesterday()
        hardDay.pages.append(BookPage(id: "hard", type: .diary, createdAt: date(10, 15, 12), promptText: "Diary",
                                      userInput: "An honest line.", tags: ["distress"]))
        var inputs = inputs(days: [hardDay])
        inputs.greyPageThreats = greyThreat(hoursLeft: 31, now: date(10, 16, 7))
        var war = PactWarState()
        war.adjust("moss-clasp", "shelf-care", by: 40)
        inputs.pactWar = war
        let briefs = pool(inputs)
        XCTAssertEqual(briefs.first?.title, "Thursday, Kept")
        XCTAssertFalse(briefs.contains { BleedDataDesk.ids.contains($0.id) || $0.id == BleedLeadDesk.noteID || $0.id == BleedFeatureDesk.id })
    }

    func testAPrintRecordFromBeforeSnapshotsStillDecodes() throws {
        let old = #"{"slotID":"s","printedAt":0,"items":[{"storyID":"a","revision":"r","title":"t","body":"b","sourcePageIDs":[]}]}"#
        let record = try XCTUnwrap(BleedPrintRecord.decode(old))
        XCTAssertNil(record.items.first?.snapshot)
        XCTAssertNil(BleedNewsroom.lastSnapshot("pact:", in: [record]))
    }
}

// MARK: - Follow-ups, features and mergers

extension BleedDailyEditionTests {
    private func settledThreat(_ status: GreyPageThreatStatus, resolvedAt: Date, line: String? = nil) -> GreyPageThreatLedger {
        GreyPageThreatLedger(threats: [GreyPageThreat(
            id: "grey-page-moth", pageID: "moth", pageTitle: "One true sentence", pageExcerpt: moth,
            markedAt: resolvedAt.addingTimeInterval(-3 * 86_400), deadline: resolvedAt.addingTimeInterval(3_600),
            status: status, resolvedAt: resolvedAt, rescueLine: line)])
    }

    private func briefs(_ inputs: BookSourceInputs) -> [BleedColumnBrief] {
        BleedNewsroom.briefs(kind: .morning, day: bookDay(10, 16, []), inputs: inputs, interest: nil,
                             now: date(10, 16, 7), calendar: calendar, authored: [])
    }

    func testTheNextPaperReportsThatTheGreyPageHeld() throws {
        var inputs = inputs(days: [yesterday()])
        inputs.greyPageThreats = settledThreat(.rescued, resolvedAt: date(10, 16, 1), line: "The moth moved to the window by morning.")
        let lead = try XCTUnwrap(briefs(inputs).first)
        XCTAssertEqual(lead.title, "Thursday's Page Held")
        XCTAssertTrue(lead.composedBody.contains("“The moth moved to the window by morning.”"), lead.composedBody)
        // The rescue line is the Reader's writing: the press remembers the page, not a copy.
        XCTAssertEqual(lead.sourcePageIDs, ["moth"])
        // Reported once: a paper printed after the rescue already carried it.
        inputs.bleedPrintHistory = [BleedPrintRecord(slotID: "earlier", printedAt: date(10, 16, 2), items: [])]
        XCTAssertNotEqual(briefs(inputs).first?.title, "Thursday's Page Held")
    }

    func testAFadedPageIsReportedPlainlyAndNeverOverAStrongDay() throws {
        var strong = inputs(days: [yesterday()])
        strong.greyPageThreats = settledThreat(.erased, resolvedAt: date(10, 16, 1))
        XCTAssertEqual(briefs(strong).first?.title, "The Moth Kept the Light On")
        var quiet = inputs(days: [])
        quiet.greyPageThreats = settledThreat(.erased, resolvedAt: date(10, 16, 1))
        let lead = try XCTUnwrap(briefs(quiet).first)
        XCTAssertEqual(lead.title, "The Grey Page Has Faded")
        XCTAssertTrue(lead.composedBody.contains("Nothing was deleted."), lead.composedBody)
    }

    func testTheFeatureTakesTurnsAndNeverRunsTheSameSubjectTwice() throws {
        var inputs = BookSourceInputs.empty
        let opened = date(10, 6)
        inputs.contestedQuestions = [ContestedQuestion(
            id: "bench", question: "Who repainted the bench?", aboutMovementIDs: [],
            positions: [
                ContestedPosition(id: "a", holderID: "penny-blackletter", holderName: "Penny", claim: "The paint is fresh.",
                                  groundedInIDs: [], confidence: 60, silence: .none, formedAt: opened),
                ContestedPosition(id: "b", holderID: "wicker", holderName: "Wicker", claim: "It was always blue.",
                                  groundedInIDs: [], confidence: 40, silence: .none, formedAt: opened),
                ContestedPosition(id: "c", holderID: "other", holderName: "Other", claim: "A secret not for print.",
                                  groundedInIDs: [], confidence: 80, silence: .notTheirBusiness, formedAt: opened)
            ],
            bookPosition: "A private guess.", bookBackedHolderID: "penny-blackletter",
            status: .open, openedAt: opened, lastMovedAt: opened)]
        let incidents = (1...3).map { PlaceIncident(id: "i\($0)", line: "The lamps went out for the \($0) time.",
                                                     participantIDs: [], tags: ["dark"], occurredAt: date(10, $0 + 1)) }
        inputs.placeStates = ["location-great-hall": PlaceState(id: "location-great-hall", incidents: incidents,
                                                                 slowChange: "The rug is wearing to the boards.")]
        func feature(_ day: Int, _ kind: BleedEditionKind, history: [BleedPrintRecord] = []) -> BleedColumnBrief? {
            BleedFeatureDesk.feature(kind: kind, inputs: inputs, now: date(10, day, kind == .morning ? 7 : 18),
                                     calendar: calendar, history: history, lead: nil)
        }
        let first = try XCTUnwrap(feature(16, .morning))
        let second = try XCTUnwrap(feature(16, .evening))
        XCTAssertNotEqual(first.storyID, second.storyID)
        let fight = try XCTUnwrap([first, second].first { $0.title == "The Long Argument" })
        XCTAssertTrue(fight.fallbackBody?.contains("argued for 10 days") == true, fight.fallbackBody ?? "")
        XCTAssertFalse(fight.packet.contains("secret not for print") || fight.packet.contains("private guess"), fight.packet)
        let place = try XCTUnwrap([first, second].first { $0.storyID == "feature:place:location-great-hall" })
        XCTAssertTrue(place.title.hasPrefix("A History of"), place.title)
        XCTAssertTrue(place.fallbackBody?.contains("The rug is wearing to the boards.") == true)
        // Whatever ran in the last paper stands down for this one.
        let ran = BleedPrintRecord(slotID: "last", printedAt: date(10, 16, 7), items: [
            .init(storyID: first.storyID!, revision: "x", title: first.title, body: "", sourcePageIDs: [])
        ])
        XCTAssertNotEqual(feature(16, .morning, history: [ran])?.storyID, first.storyID)
    }

    func testStandingCorrespondencesTradeAsMergers() throws {
        var grimoire = Calendar(identifier: .gregorian)
        grimoire.timeZone = TimeZone(identifier: "UTC")!
        let days = (0..<61).map { index -> BookDay in
            let date = grimoire.date(byAdding: .hour, value: 20, to: GrimoireDay.date(for: index, calendar: grimoire))!
            let rainy = index % 3 == 0
            return BookDay(id: BookDay.id(for: date, calendar: grimoire), date: grimoire.startOfDay(for: date), pages: [BookPage(
                id: "page-\(index)", type: .diary, createdAt: date, promptText: "p",
                userInput: rainy ? "The lantern outside was swinging in the wet." : "Bread, errands, the usual list.",
                origin: .userAuthored,
                context: BookPageContextSnapshot(at: date, calendar: grimoire, weatherTags: rainy ? ["rain"] : ["clear"]))])
        }
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(from: GrimoireSlice(days: days, calendar: grimoire)))
        let now = GrimoireDay.date(for: 62, calendar: grimoire)
        var passes = 0
        while !ledger.sweep(now: now, budget: 2_000, calendar: grimoire).finished, passes < 200 { passes += 1 }
        XCTAssertTrue(BleedDataDesk.mergers(ledger).isEmpty, "nothing is a merger until it stands")
        for row in ledger.rows.values where row.isAlive {
            ledger.markSpoken(row.id, now: now, calendar: grimoire)
            ledger.rows[row.id]?.state = .standing
        }
        let merger = try XCTUnwrap(BleedDataDesk.mergers(ledger).first)
        XCTAssertTrue(merger.clause.hasPrefix("When "), merger.clause)
        // The Reader pushed back: it doesn't trade.
        for id in ledger.rows.keys { ledger.rows[id]?.readerStatus = .notQuite }
        XCTAssertTrue(BleedDataDesk.mergers(ledger).isEmpty)
    }
}
