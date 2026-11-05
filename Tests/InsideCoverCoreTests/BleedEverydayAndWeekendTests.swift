import XCTest
@testable import InsideCoverCore

/// The everyday rotating columns (the Blotter, Lost & Found, the Court Circular,
/// Announcements, Club Notices, Running Stories) and the weekend paper's own
/// section (the op-ed, the interview, the society pages, the agony column, the
/// funnies and the poll).
final class BleedEverydayAndWeekendTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// 31 October 2026 is a Saturday; 2 November a Monday.
    private func date(_ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func bookDay(_ date: Date, _ pages: [BookPage] = []) -> BookDay {
        BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: pages)
    }

    private func named(_ inputs: inout BookSourceInputs) {
        inputs.selfFacts = [SelfFact(id: "name", questionID: "onboarding-name", question: "Your name?", answer: "Wren",
                                     bookTranslation: "Wren", sensitivity: .identity, usePermission: .quoteAllowed,
                                     tags: ["name"], createdAt: date(10, 1), updatedAt: date(10, 1))]
    }

    private func act(_ id: String, _ actor: String, _ target: String, _ kind: CastAct, _ line: String, _ at: Date) -> CastActRecord {
        CastActRecord(id: id, actorID: actor, actorName: BleedDayDesk.castName(actor), targetID: target,
                      targetName: BleedDayDesk.castName(target), act: kind, line: line, occurredAt: at, tags: [])
    }

    // MARK: Everyday

    func testTheBlotterLogsTheRoomsAndTheCastWithTheTime() throws {
        let now = date(11, 2, 7)
        var inputs = BookSourceInputs.empty
        inputs.placeStates = ["location-pantry": PlaceState(id: "location-pantry", incidents: [
            PlaceIncident(id: "jar", line: "A jar was reported missing.", participantIDs: [], tags: [], occurredAt: date(11, 1, 15))])]
        inputs.castActs.record(act("a", "wicker-eddies", "penny-blackletter", .coverFor,
                                   "Wicker took the blame for a ledger that wasn't his.", date(11, 1, 16)))
        let column = try XCTUnwrap(BleedAlmanacDesk.blotter(inputs: inputs, now: now, calendar: calendar))
        XCTAssertTrue(column.composedBody.contains("the Pantry · A jar was reported missing."), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Wicker took the blame"), column.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .ledger)
    }

    func testLostAndFoundPostsTitlesNeverWhatWasInThem() throws {
        let now = date(11, 2, 7)
        var inputs = BookSourceInputs.empty
        inputs.pocket.press(PocketKeepsake(id: "k", dayID: "d", pageType: .souvenir, object: "a ribbon", glyph: "seal",
                                          foundAt: date(11, 1, 12), title: "The red umbrella", excerpt: "Something private."))
        let column = try XCTUnwrap(BleedAlmanacDesk.lostAndFound(inputs: inputs, now: now, calendar: calendar, history: []))
        XCTAssertTrue(column.composedBody.contains("FOUND · The red umbrella"), column.composedBody)
        XCTAssertFalse(column.composedBody.contains("Something private."), column.composedBody)
        let posted = BleedPrintRecord(slotID: "s", printedAt: now, items: [
            .init(storyID: BleedAlmanacDesk.lostID, revision: "x", title: "", body: "", sourcePageIDs: [], snapshot: column.snapshot)])
        XCTAssertNil(BleedAlmanacDesk.lostAndFound(inputs: inputs, now: now, calendar: calendar, history: [posted]))
    }

    func testTheCourtCircularListsOnlyBargainsTakenUp() throws {
        let now = date(11, 2, 7)
        var inputs = BookSourceInputs.empty
        func bargain(_ id: String, _ status: FaeBargainStatus) -> FaeBargain {
            FaeBargain(id: id, faeKind: .punctuationPixie, slot: "s", giftID: "g", giftName: "the wandering comma", giftEffectLine: "",
                       openingGesture: "", terms: "Notice a pause.", offeredAt: date(10, 30), deadline: date(11, 4),
                       status: status, fieldReport: nil, faeResponse: nil, rewardText: nil, deliveredAt: nil)
        }
        inputs.faeState.bargains = [bargain("offered", .offered)]
        XCTAssertNil(BleedAlmanacDesk.courtCircular(inputs: inputs, now: now, calendar: calendar))
        inputs.faeState.bargains.append(bargain("owed", .owed))
        let column = try XCTUnwrap(BleedAlmanacDesk.courtCircular(inputs: inputs, now: now, calendar: calendar))
        XCTAssertTrue(column.composedBody.contains("Punctuation Pixie · the wandering comma given; payment due"), column.composedBody)
        XCTAssertEqual(column.composedBody.components(separatedBy: "Punctuation Pixie").count - 1, 1, column.composedBody)
    }

    func testABirthdayIsAnnouncedAndCanJumpTheQueue() throws {
        let now = date(11, 2, 7)
        var inputs = BookSourceInputs.empty
        named(&inputs)
        inputs.readerBirthday = ReaderBirthday(month: 11, day: 2)
        let column = try XCTUnwrap(BleedAlmanacDesk.announcements(day: bookDay(now), inputs: inputs, now: now, calendar: calendar, history: []))
        XCTAssertTrue(column.composedBody.hasPrefix("BIRTHDAY · Wren."), column.composedBody)
        XCTAssertEqual(column.urgency, BleedAlmanacDesk.urgent)
    }

    func testClubNoticesPostTonightsClubFromTheTimetable() {
        let found = (1...7).compactMap { day in
            BleedAlmanacDesk.clubNotices(kind: .morning, now: date(11, day, 7), calendar: calendar)
        }
        XCTAssertFalse(found.isEmpty, "some night of the week has a club")
        XCTAssertTrue(found.allSatisfy { $0.composedBody.hasPrefix("TONIGHT · ") }, found.first?.composedBody ?? "")
    }

    // MARK: The weekend

    func testTheWeekendSectionRunsOnlyOnWeekendMornings() {
        XCTAssertTrue(BleedWeekendDesk.isWeekendMorning(kind: .morning, now: date(10, 31, 7), calendar: calendar))
        XCTAssertFalse(BleedWeekendDesk.isWeekendMorning(kind: .evening, now: date(10, 31, 18), calendar: calendar))
        XCTAssertFalse(BleedWeekendDesk.isWeekendMorning(kind: .morning, now: date(11, 2, 7), calendar: calendar))
    }

    func testAnOpEdArguesTheWritersOwnSideAndCarriesTheDisclaimer() throws {
        let now = date(10, 31, 7)
        var inputs = BookSourceInputs.empty
        inputs.contestedQuestions = [ContestedQuestion(
            id: "bench", question: "Who repainted the bench?", aboutMovementIDs: [],
            positions: [ContestedPosition(id: "a", holderID: "wicker-eddies", holderName: "Wicker", claim: "It was always blue.",
                                          groundedInIDs: [], confidence: 60, silence: .none, formedAt: now),
                        ContestedPosition(id: "b", holderID: "penny-blackletter", holderName: "Penny", claim: "The paint is fresh.",
                                          groundedInIDs: [], confidence: 40, silence: .none, formedAt: now)],
            bookPosition: "A private guess.", status: .open, openedAt: now, lastMovedAt: now)]
        let column = try XCTUnwrap(BleedWeekendDesk.opEd(inputs: inputs, now: now, history: []))
        XCTAssertTrue(column.needsLocalBrain)
        XCTAssertTrue(column.packet.contains("Your position: It was always blue."), column.packet)
        XCTAssertFalse(column.packet.contains("private guess"), column.packet)
        XCTAssertTrue(column.title.hasPrefix("Op-Ed: \(BleedDayDesk.castName("wicker-eddies")) on"), column.title)
        let finished = BleedReaderDesk.finishing("The bench was blue when I got here.", brief: column)
        XCTAssertTrue(finished.hasSuffix("The paper merely printed them."), finished)
        XCTAssertEqual(BleedIssueCurator.desk(column), .weekend)
    }

    func testFiveQuestionsUsesOnlyWhatTheCastSayWhenAskedAboutWhatTheReaderSaw() throws {
        let ladder = try XCTUnwrap(CastUndertakingRegistry.coreLadders.first { ladder in
            ladder.stages.prefix(3).contains { $0.deniability?.isEmpty == false }
        })
        let index = try XCTUnwrap(ladder.stages.indices.first { ladder.stages[$0].deniability?.isEmpty == false })
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [CastUndertaking(
            id: "u", actorID: ladder.actorID, title: ladder.title, pursuit: ladder.pursuit, why: ladder.why, stages: ladder.stages,
            stageIndex: index, status: .active, startedAt: date(10, 1), lastAdvancedAt: date(10, 20), nextEligibleAt: date(11, 9),
            ladderID: ladder.id)]
        // Not met yet: nothing to ask about.
        XCTAssertNil(BleedWeekendDesk.fiveQuestions(inputs: inputs, now: date(10, 31, 7), history: []))
        inputs.undertakingSerial.rememberedStoryBeats = [UndertakingSerial.storyBeatKey(actorID: ladder.actorID, stageID: ladder.stages[index].id)]
        let column = try XCTUnwrap(BleedWeekendDesk.fiveQuestions(inputs: inputs, now: date(10, 31, 7), history: []))
        let answer = try XCTUnwrap(CastUndertakingRegistry.authored(ladder.stages[index], actorID: ladder.actorID).deniability)
        XCTAssertTrue(column.composedBody.contains("A. \(answer)"), column.composedBody)
        XCTAssertTrue(column.composedBody.hasPrefix("Q. What are you working on?\nA. I"), column.composedBody)
        // Said by them, never about them.
        let surname = BleedFirstPerson.names(of: ladder.actorID).last ?? ""
        let answers = column.composedBody.components(separatedBy: "\n").filter { $0.hasPrefix("A. ") }
        XCTAssertFalse(answers.contains { $0.contains(" \(surname) ") || $0.hasPrefix("A. \(surname)") || $0.hasPrefix("A. He ") || $0.hasPrefix("A. She ") },
                       column.composedBody)
    }

    func testTheSocietyPagesReportWhoWasSeenWithWhom() throws {
        let now = date(10, 31, 7)
        var inputs = BookSourceInputs.empty
        inputs.castActs.record(act("1", "pippa-pilcrow", "zara-finch", .include, "Pippa brought Zara into the stamp business.", date(10, 28)))
        inputs.castActs.record(act("2", "zara-finch", "pippa-pilcrow", .defend, "Zara took Pippa's side out loud.", date(10, 29)))
        inputs.castActs.record(act("3", "wicker-eddies", "thaddeus-mook", .correctInPublic, "Wicker corrected Mook in front of everybody.", date(10, 30)))
        let column = try XCTUnwrap(BleedWeekendDesk.societyPages(inputs: inputs, now: now))
        XCTAssertTrue(column.composedBody.contains("SEEN TOGETHER · "), column.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .ledger)
    }

    func testTheAgonyColumnAnswersAQuestionAboutTheWorldNeverAboutTheReader() throws {
        let now = date(10, 31, 7)
        var inputs = BookSourceInputs.empty
        named(&inputs)
        let personal = BookPage(id: "p", type: .diary, createdAt: date(10, 29), promptText: "Diary", userInput: "Why do I always forget my keys?")
        inputs.days = [bookDay(personal.createdAt, [personal])]
        XCTAssertNil(BleedWeekendDesk.askTheAcademy(day: bookDay(now), inputs: inputs, now: now, calendar: calendar, history: []))
        let heron = BookPage(id: "h", type: .souvenir, createdAt: date(10, 30), promptText: "One true sentence",
                             userInput: "The heron was back. Is it the same heron every single time?")
        inputs.days.append(bookDay(heron.createdAt, [heron]))
        let column = try XCTUnwrap(BleedWeekendDesk.askTheAcademy(day: bookDay(now), inputs: inputs, now: now, calendar: calendar, history: []))
        XCTAssertEqual(column.readerQuotes, ["Is it the same heron every single time?"])
        XCTAssertEqual(column.sourcePageIDs, ["h"])
        let finished = BleedReaderDesk.finishing("Same heron, different mood.", brief: column)
        XCTAssertTrue(finished.hasPrefix("“Is it the same heron every single time?”\n— Wren asks\n\n"), finished)
        XCTAssertTrue(finished.contains(" replies:\nSame heron, different mood."), finished)
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .readerLetter)
    }

    func testThePollCountsTheReadersMarginAndTheCasts() throws {
        let opened = date(10, 31, 7)
        let poll = try XCTUnwrap(BleedWeekendDesk.poll(inputs: .empty, now: opened, history: []))
        let kept = BookPage(id: "kept", type: .theBleed, createdAt: date(10, 31, 20), promptText: "The Morning Edition, unfolded.",
                            userInput: "THE BLEED\n\n— The Poll —\nthe poll · the weekend paper\n\n\(poll.composedBody)\n\nMargin note: Yes, obviously.")
        XCTAssertFalse(BleedNewsroom.isCorrespondence(kept), "a ballot is not a letter to the editor")
        var inputs = BookSourceInputs.empty
        named(&inputs)
        inputs.days = [bookDay(kept.createdAt, [kept])]
        let history = [BleedPrintRecord(slotID: "sat", printedAt: opened, items: [
            .init(storyID: poll.storyID!, revision: "x", title: "", body: "", sourcePageIDs: [])])]
        let result = try XCTUnwrap(BleedWeekendDesk.pollResults(day: bookDay(date(11, 1, 7)), inputs: inputs, now: date(11, 1, 7), history: history))
        XCTAssertTrue(result.composedBody.contains("Wren voted yes"), result.composedBody)
        let yes = Int(result.composedBody.components(separatedBy: "YES · ")[1].prefix { $0.isNumber }) ?? 0
        let no = Int(result.composedBody.components(separatedBy: "NO · ")[1].prefix { $0.isNumber }) ?? 0
        XCTAssertEqual(yes + no, 6, "five of the Cast and the Reader")
    }

    func testRunningStoriesFollowAThingThatKeepsTurningUp() throws {
        let now = date(11, 2, 7)
        let lines = ["The heron stood by the canal again this morning.", "A heron on the canal wall, very still.",
                     "Saw the heron fishing under the bridge.", "The heron was gone, then back by noon."]
        var inputs = BookSourceInputs.empty
        inputs.days = lines.enumerated().map { index, line in
            let page = BookPage(id: "h\(index)", type: .souvenir, createdAt: date(10, 28 + index, 10),
                                promptText: "One true sentence", userInput: line)
            return bookDay(page.createdAt, [page])
        }
        let column = try XCTUnwrap(BleedAlmanacDesk.runningStories(day: bookDay(now), inputs: inputs, now: now, calendar: calendar))
        XCTAssertTrue(column.composedBody.lowercased().contains("heron"), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("Seen on 4 separate days."), column.composedBody)
    }

    func testTheFunniesDrawOneOfTheCastWithWhatTheyDid() throws {
        let bundled = BookReferenceCatalog.bundledCharacterIllustrationAssetNames
        let actor = try XCTUnwrap(NarrativePackRegistry.entities.filter { $0.kind == .character }.map(\.id).sorted().first {
            CastMarginalia.plateAssetName(forSlug: $0).map(bundled.contains) ?? false
        })
        var inputs = BookSourceInputs.empty
        inputs.castActs.record(act("f", actor, "penny-blackletter", .finishSomeoneElsesWork,
                                   "Finished Penny's crossword in pen.", date(10, 30)))
        let column = try XCTUnwrap(BleedWeekendDesk.funnies(inputs: inputs, now: date(10, 31, 7), history: []))
        XCTAssertTrue(column.composedBody.hasPrefix(BleedCaptionDesk.pictureMark), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("“Finished Penny's crossword in pen.”"), column.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .competition)
    }

    func testAnOpEdThatDescribesItsWriterIsRefusedAndTheFloorSpeaksForThem() throws {
        let now = date(10, 31, 7)
        var inputs = BookSourceInputs.empty
        let ladder = try XCTUnwrap(CastUndertakingRegistry.ladder(withID: "core-ambrose-trencher"))
        inputs.castUndertakings = [CastUndertaking(
            id: "u", actorID: ladder.actorID, title: ladder.title, pursuit: ladder.pursuit, why: ladder.why, stages: ladder.stages,
            stageIndex: 1, status: .active, startedAt: date(10, 1), lastAdvancedAt: date(10, 20), nextEligibleAt: date(11, 9),
            ladderID: ladder.id)]
        let column = try XCTUnwrap(BleedWeekendDesk.opEd(inputs: inputs, now: now, history: []))
        let thirdPerson = BleedReaderDesk.finishing("Trencher buys a swollen, water-damaged volume in a language he does not read.", brief: column)
        XCTAssertFalse(BleedCopyDesk.printable(prose: thirdPerson, brief: column), "one sentence about himself is not an op-ed")
        let floor = try XCTUnwrap(column.fallbackBody)
        XCTAssertTrue(floor.hasPrefix("I'm trying to cook the one page"), floor)
        XCTAssertTrue(floor.contains("I buy the handwriting of the dead"), floor)
        XCTAssertTrue(floor.hasSuffix("The paper merely printed them."), floor)
    }

    func testACastStepLeadIsAWholeStoryAndGivesWayToAStrongDay() throws {
        let ladder = try XCTUnwrap(CastUndertakingRegistry.ladder(withID: "core-dr-vellum"))
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [CastUndertaking(
            id: "v", actorID: ladder.actorID, title: ladder.title, pursuit: ladder.pursuit, why: ladder.why, stages: ladder.stages,
            stageIndex: 1, status: .active, startedAt: date(10, 3), lastAdvancedAt: date(10, 31, 20), nextEligibleAt: date(11, 4),
            ladderID: ladder.id)]
        let lead = try XCTUnwrap(BleedLeadDesk.castStep(inputs: inputs, now: date(11, 1, 7), since: date(10, 31, 18)))
        XCTAssertTrue(lead.body.contains("has been at this since October 3, trying to find"), lead.body)
        XCTAssertFalse(lead.body.contains("'s the "), lead.body)
        XCTAssertTrue(lead.body.contains("It's step 2 of \(ladder.stages.count)"), lead.body)
        XCTAssertGreaterThanOrEqual(lead.body.split(whereSeparator: \.isWhitespace).count, 40, lead.body)
        XCTAssertLessThan(lead.rank, 300, "a strong day of the Reader's own outranks a step in somebody's business")
    }

    func testTheSameAppointmentFromTwoCalendarsIsListedOnce() {
        var inputs = BookSourceInputs.empty
        inputs.calendarEvents = [
            CalendarEventSignal(id: "a", title: "Daylight Saving Time End", startsAt: calendar.startOfDay(for: date(11, 1)), isAllDay: true),
            CalendarEventSignal(id: "b", title: "Daylight Saving Time ends", startsAt: calendar.startOfDay(for: date(11, 1)), isAllDay: true),
            CalendarEventSignal(id: "c", title: "Rent", startsAt: date(11, 1, 10), isAllDay: false)
        ]
        let column = TheBleedEditionBuilder.almanacColumn(kind: .morning, inputs: inputs, now: date(11, 1, 7), calendar: calendar)
        XCTAssertEqual(column.components(separatedBy: "Daylight Saving").count - 1, 1, column)
        XCTAssertTrue(column.contains("Rent"), column)
    }

    func testTheWeekendSectionDoesNotTakeTheWeekdaysSeats() {
        func column(_ id: String) -> BleedColumnBrief {
            BleedColumnBrief(id: id, title: id, byline: "x", composedBody: "Body.", packet: "", maxTokens: 0,
                             storyID: id, revision: id)
        }
        let weekend = BleedWeekendDesk.ids.map(column)
        let features = ["academy-report", "correspondence", "reader-echo", "cast-letter", "whispers", "interest-desk"].map(column)
        let picked = BleedIssueCurator.select(from: weekend + features, kind: .morning, history: [])
        XCTAssertEqual(picked.filter { BleedIssueCurator.desk($0) == .weekend }.count, 4)
        XCTAssertEqual(picked.first { BleedIssueCurator.desk($0) == .weekend }?.id, BleedWeekendDesk.opEdID, "the op-ed leads the section")
    }
}
