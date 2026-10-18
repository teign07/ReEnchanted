import XCTest
@testable import InsideCoverCore

final class BleedNewsroomTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int = 10, _ hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
    }

    private var day: BookDay { BookDay(id: "2026-06-10", date: date(10, 0), pages: []) }

    private func business(line: String = "Penny found a changed comma.", movedAt: Date? = nil) -> CastUndertaking {
        CastUndertaking(
            id: "test-headline-case", actorID: "penny-blackletter", title: "The changed headline",
            pursuit: "Find the original", why: "It was altered",
            stages: [CastUndertakingStage(id: "test-commas", line: line,
                trace: "A red circle on page four.", tags: [], scene: nil, deniability: nil, door: nil)],
            stageIndex: 0, status: .active, startedAt: date(9),
            lastAdvancedAt: movedAt ?? date(), nextEligibleAt: date(11), ladderID: "test-ladder"
        )
    }

    private func briefs(_ inputs: BookSourceInputs = .empty, kind: BleedEditionKind = .morning) -> [BleedColumnBrief] {
        TheBleedEditionBuilder.columnBriefs(
            kind: kind, day: day, inputs: inputs, interest: nil,
            now: date(10, kind == .morning ? 8 : 18), calendar: calendar
        )
    }

    private func record(_ brief: BleedColumnBrief, body: String? = nil) -> BleedPrintRecord {
        BleedPrintRecord(slotID: "bleed-2026-06-10-morning", printedAt: date(), items: [
            .init(storyID: brief.storyID!, revision: brief.revision!, title: brief.title,
                  body: body ?? brief.composedBody, sourcePageIDs: brief.sourcePageIDs ?? [])
        ])
    }

    func testQuietPaperHasAuthoredPleasureWithoutManufacturingReaderMeaning() {
        let copy = briefs()
        XCTAssertFalse(copy.contains { ["front-page", "theme-desk", "corridor-whispers"].contains($0.id) })
        XCTAssertTrue(copy.contains { $0.id == "small-ad" && !$0.needsLocalBrain })
        XCTAssertTrue(copy.contains { $0.id == "diversion" && !$0.needsLocalBrain })
        XCTAssertFalse(copy.contains(where: \.needsLocalBrain))
        let body = TheBleedEditionBuilder.compositedBody(
            kind: .morning, issueNumber: 1, columns: copy.map { ($0, $0.composedBody) },
            now: date(), calendar: calendar
        )
        XCTAssertFalse(body.contains("— At the window —"))
        XCTAssertFalse(body.contains("— Today's appointments —"))
        XCTAssertFalse(body.contains("no pages"))
        // The Academy's own small ads, when one is due; otherwise the house ones.
        XCTAssertTrue(body.contains("— Classified —") || body.contains("— The small ads —"))
    }

    func testEveningOmitsUnchangedAcademyStoryButFollowsAnActualChange() throws {
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [business()]
        let morning = try XCTUnwrap(briefs(inputs).first { $0.id == "academy-report" })
        inputs.bleedPrintHistory = [record(morning, body: "Penny found a changed comma.")]
        XCTAssertFalse(briefs(inputs, kind: .evening).contains { $0.id == "academy-report" })

        inputs.castUndertakings = [business(line: "Penny found the original headline in a second copy.", movedAt: date(10, 15))]
        let evening = try XCTUnwrap(briefs(inputs, kind: .evening).first { $0.id == "academy-report" })
        XCTAssertEqual(evening.storyID, morning.storyID)
        XCTAssertNotEqual(evening.revision, morning.revision)
        XCTAssertTrue(evening.title.hasPrefix("Further to:"))
        XCTAssertTrue(evening.packet.contains("PREVIOUSLY PRINTED"))
        XCTAssertTrue(evening.packet.contains("second copy"))
    }

    func testUnchangedAuthoredArticleIsNotRepublishedButNewBytesAre() {
        let article = BleedColumnBrief(id: "authored-incident", title: "An exact report", byline: "Penny",
            composedBody: "The source is closed.", packet: "", maxTokens: 0,
            storyID: "authored-incident", revision: BleedNewsroom.revision("The source is closed."))
        var inputs = BookSourceInputs.empty
        inputs.bleedPrintHistory = [record(article)]
        let unchanged = BleedNewsroom.briefs(kind: .evening, day: day, inputs: inputs, interest: nil,
            now: date(10, 18), calendar: calendar, authored: [article])
        XCTAssertFalse(unchanged.contains { $0.id == article.id })
        var revised = article
        revised.composedBody = "The source is open again."
        let changed = BleedNewsroom.briefs(kind: .evening, day: day, inputs: inputs, interest: nil,
            now: date(10, 18), calendar: calendar, authored: [revised])
        // The day's own front page leads the paper; the revised article follows it.
        XCTAssertEqual(changed.first { $0.id == article.id }?.composedBody, revised.composedBody)
    }

    func testReportingDoesNotRevealFuturePrivateOrStaleBusiness() {
        var privateBusiness = business()
        privateBusiness.stages[0].surface = .letter
        var stale = business(movedAt: date().addingTimeInterval(-15 * 86_400))
        stale.id = "stale"
        var future = business(movedAt: date(11))
        future.id = "future"
        var inputs = BookSourceInputs.empty
        inputs.castUndertakings = [privateBusiness, stale, future]
        XCTAssertFalse(briefs(inputs).contains { $0.id == "academy-report" })
    }

    func testCompletedBusinessCanStillMakeThePaper() {
        var inputs = BookSourceInputs.empty
        var completed = business()
        completed.status = .concluded
        inputs.castUndertakings = [completed]
        XCTAssertTrue(briefs(inputs).contains { $0.id == "academy-report" })
    }

    func testDisputedAccountsStayAttributedAndSilentPositionsStayPrivate() throws {
        var inputs = BookSourceInputs.empty
        inputs.contestedQuestions = [ContestedQuestion(
            id: "test-argument", question: "Who moved the bench?", aboutMovementIDs: [],
            positions: [
                ContestedPosition(id: "public", holderID: "penny-blackletter", holderName: "Penny",
                    claim: "The blue paint is fresh.", groundedInIDs: [], confidence: 60, silence: .none, formedAt: date()),
                ContestedPosition(id: "private", holderID: "other", holderName: "Other",
                    claim: "A secret not for publication.", groundedInIDs: [], confidence: 80,
                    silence: .notTheirBusiness, formedAt: date())
            ], bookPosition: "The Book has a private guess.", status: .complicated,
            openedAt: date(), lastMovedAt: date(), contradictingEvidence: "The old photograph already shows blue paint."
        )]
        let report = try XCTUnwrap(briefs(inputs).first { $0.id == "academy-report" })
        XCTAssertTrue(report.fallbackBody?.contains("Penny's account:") == true)
        XCTAssertTrue(report.fallbackBody?.contains("Later evidence:") == true)
        XCTAssertFalse(report.packet.contains("secret not for publication"))
        XCTAssertFalse(report.packet.contains("private guess"))
    }

    func testAnOrdinaryDiaryIsNotCorrespondence() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: day.id, date: day.date, pages: [
            BookPage(id: "private-diary", type: .diary, createdAt: date(10, 12),
                     promptText: "Diary", userInput: "The station looked different today.")
        ])]
        XCTAssertFalse(briefs(inputs, kind: .evening).contains { $0.id == "correspondence" })
    }

    func testExplicitSubmissionUsesOnlyReaderWordsAndOnlyOnce() throws {
        var inputs = BookSourceInputs.empty
        let letter = BookPage(id: "letter-to-penny", type: .plainPage, createdAt: date(10, 12),
            promptText: "Plain Page", userInput: "For Penny: The bench had been repaired with a blue plank.")
        inputs.days = [BookDay(id: day.id, date: day.date, pages: [letter])]
        XCTAssertFalse(briefs(inputs).contains { $0.id == "correspondence" })
        let item = try XCTUnwrap(briefs(inputs, kind: .evening).first { $0.id == "correspondence" })
        XCTAssertEqual(item.sourcePageIDs, [letter.id])
        XCTAssertTrue(item.packet.contains("blue plank"))
        inputs.bleedPrintHistory = [record(item)]
        XCTAssertFalse(briefs(inputs, kind: .evening).contains { $0.id == "correspondence" })
    }

    func testSensitiveAndGeneratedTextCannotBecomeASubmission() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: day.id, date: day.date, pages: [
            BookPage(id: "sensitive", type: .plainPage, createdAt: date(10, 12), promptText: "For Penny",
                     userInput: "Private material", privacy: .localSensitive),
            BookPage(id: "generated", type: .plainPage, createdAt: date(10, 12), promptText: "For Penny",
                     userInput: "Words the model wrote", origin: .generated)
        ])]
        XCTAssertFalse(briefs(inputs, kind: .evening).contains { $0.id == "correspondence" })
    }

    func testEveningAnswersThePuzzleTheMorningActuallyPrinted() throws {
        let puzzle = try XCTUnwrap(briefs().first { $0.id == "diversion" })
        var inputs = BookSourceInputs.empty
        inputs.bleedPrintHistory = [record(puzzle)]
        let answer = try XCTUnwrap(briefs(inputs, kind: .evening).first { $0.id == "diversion" })
        XCTAssertEqual(answer.storyID, puzzle.storyID?.replacingOccurrences(of: "question:", with: "answer:"))
        XCTAssertFalse(answer.composedBody.contains("Answer in the evening paper."))
    }

    func testEveningWithoutMorningIncludesTheQuestionAndAnswer() {
        let answer = BleedDiversions.selection(kind: .evening, now: date(10, 18), calendar: calendar, history: [])
        let pair = BleedDiversions.pairs.first { answer.storyID == "diversion-answer:\($0.id)" }
        XCTAssertTrue(pair.map { answer.composedBody.contains($0.question) && answer.composedBody.contains($0.answer) } == true)
    }

    func testPreparedPaperRecordsOnlyItemsActuallyPrinted() throws {
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day, inputs: .empty, now: date(), calendar: calendar))
        let puzzle = try XCTUnwrap(briefs().first { $0.id == "diversion" })
        let prepared = TheBleedEditionBuilder.preparedCopy(of: announcement, body: "The paper", interestSources: "",
            columns: [(puzzle, puzzle.composedBody), (puzzle, "  ")], printedAt: date())
        let receipt = try XCTUnwrap(BleedPrintRecord.decode(prepared.payload.metadata[BleedPrintRecord.metadataKey]))
        XCTAssertEqual(receipt.items.count, 1)
        XCTAssertEqual(receipt.items[0].storyID, puzzle.storyID)
        XCTAssertEqual(receipt.printedAt, date())
    }

    func testPressMemoryDoesNotDuplicateReaderHandwritingAndIsBounded() {
        let letter = BleedPrintRecord(slotID: "new", printedAt: date(), items: [
            .init(storyID: "reader-page:one", revision: "1", title: "A note", body: "Private handwriting", sourcePageIDs: ["one"])
        ])
        let older = (0..<60).map { index in
            BleedPrintRecord(slotID: "old-\(index)", printedAt: date().addingTimeInterval(-Double(index + 1) * 3600), items: [])
        }
        let history = BleedPrintRecord.remembering(letter, in: older)
        XCTAssertEqual(history.count, 40)
        XCTAssertEqual(history.first?.items.first?.body, "")
        XCTAssertEqual(history.first?.items.first?.sourcePageIDs, ["one"])
        XCTAssertEqual(BleedPrintRecord.remembering(letter, in: history).filter { $0.slotID == "new" }.count, 1)
    }

    func testPressHistorySurvivesAKeepAndIgnoresFutureReceipts() {
        let item = BleedDiversions.selection(kind: .morning, now: date(), calendar: calendar, history: [])
        let receipt = record(item)
        var keptDay = day
        keptDay.pages = [BookPage(type: .theBleed, createdAt: date(), promptText: "Paper",
                                 metadata: [BleedPrintRecord.metadataKey: receipt.encoded])]
        var inputs = BookSourceInputs.empty
        inputs.bleedPrintHistory = [BleedPrintRecord(slotID: "future", printedAt: date(11), items: [])]
        XCTAssertEqual(BleedNewsroom.history(day: keptDay, inputs: inputs, now: date(10, 18)), [receipt])
    }

    func testOldColumnBriefsAndVaultsStillDecode() throws {
        let legacy = #"[{"id":"front-page","title":"Ledger","byline":"Penny","composedBody":"","packet":"Old packet","maxTokens":480}]"#
        let decoded = TheBleedEditionBuilder.decodedBriefs(legacy)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded[0].storyID)
        let vault = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(PlayerVaultData()))
        XCTAssertNil(vault.bleedPrintHistory)
    }

    func testResearchPermissionIsCheckedWhenThePaperOpens() throws {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [SelfFact(id: "interest", questionID: "interest-01", question: "An interest?",
            answer: "drawing", bookTranslation: "", sensitivity: .delight, usePermission: .quoteAllowed,
            tags: [], createdAt: date(), updatedAt: date())]
        inputs.allowsPersonalizedWebResearch = true
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day, inputs: inputs, now: date(), calendar: calendar))
        inputs.allowsPersonalizedWebResearch = false
        let opened = TheBleedEditionBuilder.settingTheType(
            for: announcement, day: day, inputs: inputs, now: date(), calendar: calendar)
        XCTAssertFalse(opened.contains { $0.id == "interest-desk" })
    }

    func testCorrespondenceQuotationMustActuallyBeInTheSubmission() {
        let brief = BleedColumnBrief(id: "correspondence", title: "A note", byline: "Penny", composedBody: "",
            packet: "Reader words", maxTokens: 200, quoteSource: "The bench had a blue plank.")
        XCTAssertFalse(BleedCopyDesk.feedback(prose: "“The bench made you happy.” That sounds lovely.", brief: brief).isEmpty)
        XCTAssertTrue(BleedCopyDesk.feedback(prose: "“The bench had a blue plank.” What a precise repair.", brief: brief).isEmpty)
    }

    func testCalendarFetchWindowIncludesTheWholeLocalDayAndTomorrow() {
        let window = CalendarEventSignal.readingWindow(now: date(10, 18), horizonDays: 2, calendar: calendar)
        XCTAssertEqual(window.start, date(10, 0))
        XCTAssertEqual(window.end, date(12, 0))
        let earlier = CalendarEventSignal(id: "earlier", title: "Breakfast meeting", startsAt: date(10, 7), isAllDay: false)
        let tomorrow = CalendarEventSignal(id: "tomorrow", title: "Holiday", startsAt: date(11, 0),
                                          endsAt: date(12, 0), isAllDay: true)
        XCTAssertTrue(earlier.overlaps(window))
        XCTAssertTrue(tomorrow.overlaps(window))
    }

    func testCalendarWindowUsesDayBoundariesAcrossDaylightSaving() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(local.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0)))
        let evening = try XCTUnwrap(local.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 18)))
        let end = try XCTUnwrap(local.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 0)))
        let window = CalendarEventSignal.readingWindow(now: evening, horizonDays: 2, calendar: local)
        XCTAssertEqual(window.start, start)
        XCTAssertEqual(window.end, end)
        XCTAssertEqual(window.duration, 47 * 3600)
    }

    func testEveningIncludesTomorrowsAllDayAndOverlappingEventsButNotEndedOnes() {
        var inputs = BookSourceInputs.empty
        inputs.calendarEvents = [
            CalendarEventSignal(id: "multi", title: "Festival", startsAt: date(9, 0), endsAt: date(12, 0), isAllDay: true),
            CalendarEventSignal(id: "tomorrow", title: "Holiday", startsAt: date(11, 0), endsAt: date(12, 0), isAllDay: true),
            CalendarEventSignal(id: "ended", title: "Already over", startsAt: date(10, 0), endsAt: date(11, 0), isAllDay: true),
            CalendarEventSignal(id: "overnight", title: "Night train", startsAt: date(10, 23), endsAt: date(11, 7), isAllDay: false)
        ]
        let strip = TheBleedEditionBuilder.almanacColumn(kind: .evening, inputs: inputs, now: date(10, 18), calendar: calendar)
        XCTAssertTrue(strip.contains("All day - Festival"))
        XCTAssertTrue(strip.contains("All day - Holiday"))
        XCTAssertTrue(strip.contains("Continuing - Night train"))
        XCTAssertFalse(strip.contains("Already over"))
    }

    func testDeniedCalendarIsNotAnEmptyCalendar() {
        var inputs = BookSourceInputs.empty
        inputs.calendarAccessProblem = "Calendar access is off. Allow full access in Settings."
        XCTAssertEqual(TheBleedEditionBuilder.almanacColumn(kind: .morning, inputs: inputs, now: date(), calendar: calendar),
                       inputs.calendarAccessProblem)
        inputs.calendarIntegrationEnabled = false
        XCTAssertTrue(TheBleedEditionBuilder.almanacColumn(kind: .morning, inputs: inputs, now: date(), calendar: calendar).isEmpty)
    }

    func testCachedPaperRefreshesCalendarWithoutRewritingItsArticles() throws {
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day, inputs: .empty, now: date(), calendar: calendar))
        let originalColumns = briefs().map { (brief: $0, body: $0.composedBody) }
        let originalBody = TheBleedEditionBuilder.compositedBody(kind: .morning, issueNumber: 1,
            columns: originalColumns, now: date(), calendar: calendar)
        let prepared = TheBleedEditionBuilder.preparedCopy(of: announcement, body: originalBody, interestSources: "",
            columns: originalColumns, printedAt: date())
        var inputs = BookSourceInputs.empty
        inputs.calendarEvents = [CalendarEventSignal(id: "new", title: "Changed appointment", startsAt: date(10, 12), isAllDay: false)]
        let refreshed = TheBleedEditionBuilder.refreshingPracticalStrips(of: prepared, inputs: inputs,
            now: date(10, 10), calendar: calendar)
        XCTAssertTrue(refreshed.payload.body.contains("Changed appointment"))
        for column in originalColumns where column.brief.id == "small-ad" || column.brief.id == "diversion" {
            XCTAssertTrue(refreshed.payload.body.contains(column.body))
        }
        XCTAssertEqual(BleedPrintRecord.decode(refreshed.payload.metadata[BleedPrintRecord.metadataKey])?.printedAt, date())
        inputs.calendarIntegrationEnabled = false
        let disconnected = TheBleedEditionBuilder.refreshingPracticalStrips(of: refreshed, inputs: inputs,
            now: date(10, 10), calendar: calendar)
        XCTAssertFalse(disconnected.payload.body.contains("Changed appointment"))
    }

    func testReopeningUnkeptSlotDoesNotEraseItsEarlierPrintedStories() throws {
        let puzzle = try XCTUnwrap(briefs().first { $0.id == "diversion" })
        let first = record(puzzle)
        let emptyReprint = BleedPrintRecord(slotID: first.slotID, printedAt: date(10, 10), items: [])
        let memory = BleedPrintRecord.remembering(emptyReprint, in: [first])
        XCTAssertEqual(memory.count, 1)
        XCTAssertEqual(memory[0].items.first?.storyID, puzzle.storyID)
    }

    func testReaderLayoutSeparatesHeadlinesBylinesAndSafeSourceLinks() throws {
        let column = BleedColumnBrief(id: "interest-desk", title: "A useful finding", byline: "Penny",
            composedBody: "A particular discovery.\n\nSources:\nhttps://example.com/discovery\njavascript:bad", packet: "", maxTokens: 0)
        let body = TheBleedEditionBuilder.compositedBody(kind: .morning, issueNumber: 4,
            columns: [(column, column.composedBody)], now: date(), calendar: calendar)
        let paper = try XCTUnwrap(BleedReadingCopy.parse(body))
        XCTAssertTrue(paper.issueLine.contains("Issue #4"))
        XCTAssertEqual(paper.articles.count, 1)
        XCTAssertEqual(paper.articles[0].title, "A useful finding")
        XCTAssertEqual(paper.articles[0].byline, "Penny")
        XCTAssertEqual(paper.articles[0].body, "A particular discovery.")
        XCTAssertEqual(paper.articles[0].sources.map(\.absoluteString), ["https://example.com/discovery"])
        XCTAssertTrue(paper.colophon?.contains("Corrections welcome") == true)
        XCTAssertNil(BleedReadingCopy.parse("An old unstructured edition."))
    }

    func testCopyDeskRejectsPaddingAndInternalLabels() {
        let brief = BleedColumnBrief(id: "academy-report", title: "Report", byline: "Penny", composedBody: "", packet: "Facts", maxTokens: 240)
        XCTAssertFalse(BleedCopyDesk.feedback(prose: "The clerk notes that your journey is a testament to quiet magic.", brief: brief).isEmpty)
        XCTAssertFalse(BleedCopyDesk.feedback(prose: "CURRENT REPORTABLE FACTS: [page internal-id]", brief: brief).isEmpty)
        XCTAssertTrue(BleedCopyDesk.feedback(prose: "Penny found a changed comma. The original is on page four.", brief: brief).isEmpty)
    }
}
