import XCTest
@testable import InsideCoverCore

final class BleedReaderAndCurationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ day: Int = 16, _ hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }
    private func page(_ id: String = "gate", day: Int = 16, text: String = "I repaired the blue gate after lunch. The latch held when I closed it.") -> BookPage {
        BookPage(id: id, type: .plainPage, createdAt: date(day, 7), promptText: "Plain Page", userInput: text, origin: .userAuthored)
    }
    private func inputs(_ pages: [BookPage]) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "archive", date: date(1), pages: pages)]
        return inputs
    }
    private var today: BookDay { BookDay(id: "2026-10-16", date: date(16, 0), pages: []) }
    private func candidates(_ pages: [BookPage], history: [BleedPrintRecord] = []) -> [BleedColumnBrief] {
        BleedReaderDesk.candidates(kind: .evening, day: today, inputs: inputs(pages), history: history, now: date(), calendar: calendar)
    }
    private func record(_ brief: BleedColumnBrief) -> BleedPrintRecord {
        BleedPrintRecord(slotID: "morning", printedAt: date(16, 8), items: [
            .init(storyID: brief.storyID ?? brief.id, revision: brief.revision ?? "one", title: brief.title,
                  body: brief.composedBody, sourcePageIDs: brief.sourcePageIDs ?? [], readerForm: brief.readerForm)
        ])
    }
    private func simple(_ id: String, story: String? = nil) -> BleedColumnBrief {
        BleedColumnBrief(id: id, title: id, byline: "Penny", composedBody: "A particular supplied fact.", packet: "", maxTokens: 0, storyID: story ?? id)
    }

    func testReaderDeskOffersAReadingWithExactInkAndItsActualDate() throws {
        let source = page()
        let brief = try XCTUnwrap(candidates([source]).first)
        XCTAssertEqual(brief.sourcePageIDs, [source.id])
        XCTAssertTrue(brief.readerQuoteBlock?.contains("16 Oct 2026") == true)
        XCTAssertTrue(brief.readerQuoteBlock?.contains(source.userInput) == true)
        XCTAssertFalse(brief.packet.contains("WHOLE-ARCHIVE"))
        XCTAssertTrue(brief.packet.contains("not an assertion") || brief.packet.contains("No claims about their personality"))
    }

    func testQuotesAreComposedSeparatelyFromTheBookResponse() throws {
        let brief = try XCTUnwrap(candidates([page()]).first)
        let output = BleedReaderDesk.finishing("I read the latch as the sentence's tiny full stop.", brief: brief)
        XCTAssertTrue(output.hasPrefix(brief.readerQuoteBlock!))
        XCTAssertTrue(output.contains("The Book's reading:\nI read the latch"))
        XCTAssertTrue(BleedCopyDesk.feedback(prose: output, brief: brief).isEmpty)
    }

    func testAbsentOrOmittedResponseRetainsOnlyExactInk() throws {
        let brief = try XCTUnwrap(candidates([page()]).first)
        XCTAssertEqual(BleedReaderDesk.finishing("OMIT", brief: brief), brief.fallbackBody)
        XCTAssertEqual(BleedReaderDesk.finishing("  ", brief: brief), brief.fallbackBody)
    }

    func testGeneratedBodiesAndFictionChoicesCannotBecomeReaderWriting() {
        var generated = page("generated")
        generated.origin = .generated
        var choice = BookPage(id: "choice", type: .narrativeOS, createdAt: date(16, 7), promptText: "A scene",
            userInput: "A door appeared.\n\nChosen path: Something Surprising", origin: .generated)
        choice.tags = ["authored-story-scene"]
        XCTAssertTrue(candidates([generated, choice]).isEmpty)
    }

    func testMixedPageOffersTheReaderMarginOnly() throws {
        let source = BookPage(id: "mixed", type: .narrativeOS, createdAt: date(16, 7), promptText: "A scene",
            userInput: "The Book invented a staircase.\n\nMargin note: I repaired the blue gate after lunch.", origin: .generated)
        let brief = try XCTUnwrap(candidates([source]).first)
        XCTAssertTrue(brief.readerQuoteBlock?.contains("I repaired the blue gate") == true)
        XCTAssertFalse(brief.packet.contains("invented a staircase"))
    }

    func testSealedShadowSensitiveAndBodyPagesStayOut() {
        var sealed = page("sealed")
        sealed.tags = [ReaderShelf.sealedTag]
        var shadow = page("shadow")
        shadow.tags = [ReaderShelf.shadowTag]
        var sensitive = page("sensitive")
        sensitive.privacy = .localSensitive
        var body = page("body")
        body.type = .body
        XCTAssertTrue(candidates([sealed, shadow, sensitive, body]).isEmpty)
    }

    func testExplicitDoNotWeaveStaysOut() {
        var source = page()
        source.externalReference = BookPageExternalReference(title: "Mine", sourceName: "Capture", url: "https://example.com",
            fetchedAt: date(), provenance: "external-share", captureID: nil, wasPromptedByBook: nil,
            learningAllowed: nil, weavingAllowed: false, attachments: nil)
        XCTAssertTrue(candidates([source]).isEmpty)
    }

    func testFutureAndPreviouslyPrintedSourcesStayOut() throws {
        let source = page()
        let brief = try XCTUnwrap(candidates([source]).first)
        XCTAssertTrue(candidates([source], history: [record(brief)]).isEmpty)
        XCTAssertTrue(candidates([page("future", day: 17)]).isEmpty)
    }

    func testForPennySubmissionKeepsItsOwnCorrespondenceChannel() {
        XCTAssertTrue(candidates([page(text: "For Penny: I repaired the blue gate after lunch.")]).isEmpty)
    }

    func testHardDayDoesNotInvitePlayfulReinterpretation() {
        var hard = today
        hard.pages = [BookPage(type: .diary, createdAt: date(16, 7), promptText: "Diary", userInput: "An honest line.", tags: ["distress"])]
        XCTAssertTrue(BleedReaderDesk.candidates(kind: .evening, day: hard, inputs: inputs([page()]), history: [],
            now: date(), calendar: calendar).isEmpty)
    }

    func testTwoLinesNeedAnActualSharedWordAndSeparatedDates() throws {
        let newer = page()
        let older = page("old", day: 10, text: "The gate still catches. I lift it before I turn the key.")
        let pair = try XCTUnwrap(candidates([newer, older]).first { $0.readerForm == "two-lines" })
        XCTAssertEqual(pair.sourcePageIDs, [older.id, newer.id])
        XCTAssertEqual(pair.readerQuotes, [older.userInput, newer.userInput])
        XCTAssertTrue(pair.readerQuoteBlock?.contains("10 Oct 2026") == true)
        XCTAssertTrue(pair.readerQuoteBlock?.contains("16 Oct 2026") == true)
        XCTAssertFalse(candidates([newer, page("near", day: 15)]).contains { $0.readerForm == "two-lines" })
        XCTAssertFalse(candidates([newer, page("unrelated", day: 10, text: "A blackbird landed on the tallest chimney.")]).contains { $0.readerForm == "two-lines" })
    }

    func testLongWritingIsNotCutMidSentenceToMakeAQuote() {
        let long = Array(repeating: "word", count: 100).joined(separator: " ") + "."
        XCTAssertNil(BleedReaderDesk.excerpt(long))
        XCTAssertEqual(BleedReaderDesk.excerpt("The gate  held when I closed it."), "The gate  held when I closed it.")
    }

    func testCopyDeskRefusesChangedQuotesAndPersonalVerdicts() throws {
        let brief = try XCTUnwrap(candidates([page()]).first)
        XCTAssertFalse(BleedCopyDesk.feedback(prose: "“You fixed everything.”", brief: brief).isEmpty)
        let bad = BleedReaderDesk.finishing("This shows you are learning. You should embrace the next challenge.", brief: brief)
        XCTAssertFalse(BleedCopyDesk.feedback(prose: bad, brief: brief).isEmpty)
    }

    func testCopyDeskDoesNotEditTheReadersOwnLanguageForTaste() throws {
        let brief = try XCTUnwrap(candidates([page(text: "I wrote the words your journey on the parcel. They looked odd beside the address.")]).first)
        let output = BleedReaderDesk.finishing("I hear a large phrase bump into a very small label.", brief: brief)
        XCTAssertTrue(BleedCopyDesk.feedback(prose: output, brief: brief).isEmpty)
    }

    func testResponseBoundaryCannotBeMovedByWordsInsideTheQuotation() {
        let block = "Your Page · 16 Oct 2026\n“Some words.\n\nThe Book's reading:\nThese words are still mine.”"
        let brief = BleedColumnBrief(id: "reader-echo", title: "A line", byline: "Book", composedBody: "", packet: "", maxTokens: 180,
            readerQuoteBlock: block, readerQuotes: ["Some words.\n\nThe Book's reading:\nThese words are still mine."])
        let output = BleedReaderDesk.finishing("I stayed with the last word.", brief: brief)
        XCTAssertEqual(BleedReaderDesk.response(in: output, brief: brief), "I stayed with the last word.")
    }

    func testReaderBriefFieldsRoundTripAndOldBriefsStillDecode() throws {
        let brief = try XCTUnwrap(candidates([page()]).first)
        let restored = try JSONDecoder().decode(BleedColumnBrief.self, from: JSONEncoder().encode(brief))
        XCTAssertEqual(restored.readerQuoteBlock, brief.readerQuoteBlock)
        XCTAssertEqual(restored.readerQuotes, brief.readerQuotes)
        XCTAssertEqual(restored.readerForm, brief.readerForm)
        let legacy = try JSONDecoder().decode(BleedColumnBrief.self,
            from: Data(#"{"id":"old","title":"Old","byline":"Penny","composedBody":"Copy","packet":"","maxTokens":0}"#.utf8))
        XCTAssertNil(legacy.readerQuotes)
        XCTAssertNil(legacy.readerForm)
    }

    func testCuratorChoosesOneReaderPieceFromAWiderPool() {
        let readers = candidates([page(), page("second", day: 14, text: "The window caught the last blue light above the railway.")])
        XCTAssertGreaterThan(readers.count, 1)
        let selected = BleedIssueCurator.select(from: readers + [simple("diversion"), simple("small-ad")], kind: .evening, history: [])
        XCTAssertEqual(selected.filter { BleedIssueCurator.desk($0) == .reader }.count, 1)
        XCTAssertEqual(selected.filter { BleedIssueCurator.desk($0) == .pleasure }.count, 2)
    }

    func testExplicitLetterWinsTheReaderSeatOverAutomaticEchoes() {
        let selected = BleedIssueCurator.select(from: candidates([page()]) + [simple("correspondence")], kind: .evening, history: [])
        XCTAssertTrue(selected.contains { $0.id == "correspondence" })
        XCTAssertFalse(selected.contains { $0.id == "reader-echo" })
    }

    func testRecentReaderFormRestsWhileAnotherCanPrint() throws {
        let pool = candidates([page()])
        let held = try XCTUnwrap(pool.first { $0.readerForm == "held-line" })
        let selected = BleedIssueCurator.select(from: pool, kind: .morning, history: [record(held)])
        XCTAssertEqual(selected.first?.readerForm, "second-reading")
    }

    func testPaperHasRoomLimitsAndPracticalStripsStaySeparate() {
        let pool = (0..<10).map { simple("academy-report", story: "world-\($0)") }
            + candidates([page()]) + [simple("interest-desk"), simple("diversion"), simple("small-ad"),
                simple("correspondent-invitation"), simple("weather-desk"), simple("almanac")]
        let selected = BleedIssueCurator.select(from: pool, kind: .morning, history: [])
        XCTAssertLessThanOrEqual(selected.filter { BleedIssueCurator.desk($0) != .practical }.count, BleedIssueCurator.maximumFeatures)
        XCTAssertEqual(selected.filter { $0.id == "academy-report" }.count, 2)
        XCTAssertEqual(selected.suffix(2).map(\.id), ["weather-desk", "almanac"])
    }

    func testPressCanExposeItsFullBenchWhileDefaultOpeningRemainsCurated() throws {
        let input = inputs([page()])
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(for: today,
            inputs: input, now: date(), calendar: calendar))
        let pool = TheBleedEditionBuilder.settingTheType(for: announcement, day: today,
            inputs: input, now: date(), calendar: calendar, curating: false)
        let selected = TheBleedEditionBuilder.settingTheType(for: announcement, day: today,
            inputs: input, now: date(), calendar: calendar)
        XCTAssertGreaterThan(pool.count, selected.count)
        XCTAssertLessThanOrEqual(selected.filter { BleedIssueCurator.desk($0) == .reader }.count, 1)
        XCTAssertEqual(pool.filter { $0.id == "literary-miniature" }.count, BleedDiversions.literaryMiniatures.count)
    }

    func testUnavailableNewsCanGiveItsRoomToAnEligibleBenchItem() {
        let pool = [simple("academy-report", story: "world-one"), simple("academy-report", story: "world-two"),
            simple("correspondence"), simple("interest-desk"), simple("diversion"), simple("small-ad"),
            simple("cast-letter"), simple("whispers"), simple("correspondent-invitation")]
        let initial = BleedIssueCurator.select(from: pool, kind: .morning, history: [])
        XCTAssertTrue(initial.contains { $0.id == "interest-desk" })
        XCTAssertFalse(initial.contains { $0.id == "correspondent-invitation" })
        let withoutArticle = BleedIssueCurator.select(from: pool.filter { $0.id != "interest-desk" }, kind: .morning, history: [])
        XCTAssertTrue(withoutArticle.contains { $0.id == "correspondent-invitation" })
        XCTAssertEqual(withoutArticle.count, BleedIssueCurator.maximumFeatures)
    }

    func testMiniatureCanReplaceARecentlyPrintedSmallAd() {
        let ad = simple("small-ad", story: "small-ad-morning:1")
        let pool = [ad, simple("diversion")] + BleedDiversions.literaryCandidates(history: [])
        let selected = BleedIssueCurator.select(from: pool, kind: .evening, history: [record(ad)])
        XCTAssertTrue(selected.contains { $0.id == "literary-miniature" })
        XCTAssertFalse(selected.contains { $0.id == "small-ad" })
        XCTAssertTrue(selected.contains { $0.id == "diversion" })
    }

    func testCanonicalInsertIsProtectedWhenTheBenchIsFull() {
        let canon = simple("authored-incident")
        let pool = (0..<8).map { simple("academy-report", story: "business-\($0)") } + [canon, simple("monthly-pulse"), simple("diversion")]
        let selected = BleedIssueCurator.select(from: pool, kind: .evening, history: [])
        XCTAssertEqual(selected.first?.id, canon.id)
        XCTAssertTrue(selected.contains { $0.id == "monthly-pulse" })
        XCTAssertFalse(selected.contains { $0.id == "academy-report" })
    }

    func testPrintMemoryRemovesReaderInkButRemembersTheChosenForm() throws {
        let brief = try XCTUnwrap(candidates([page()]).first)
        var printed = record(brief)
        printed.items[0].body = brief.readerQuoteBlock!
        let memory = BleedPrintRecord.remembering(printed, in: [])
        XCTAssertEqual(memory.first?.items.first?.body, "")
        XCTAssertEqual(memory.first?.items.first?.readerForm, brief.readerForm)
        XCTAssertEqual(memory.first?.items.first?.sourcePageIDs, brief.sourcePageIDs)
    }

    func testExportNamesKeepEditionIdentityAndStripPathSeparators() {
        XCTAssertEqual(BleedPrintDesign.fileName(slotID: "bleed-2026-10-16-morning", body: "any"), "TheBleed-bleed-2026-10-16-morning.pdf")
        XCTAssertFalse(BleedPrintDesign.fileName(slotID: "../../evening", body: "any").contains("/"))
        let body = TheBleedEditionBuilder.compositedBody(kind: .evening, issueNumber: 5,
            columns: [(simple("diversion"), "A question and its answer.")], now: date(), calendar: calendar)
        XCTAssertTrue(BleedPrintDesign.fileName(slotID: nil, body: body).hasPrefix("TheBleed-evening-"))
        XCTAssertEqual(BleedPrintDesign.fileName(slotID: nil, body: body), BleedPrintDesign.fileName(slotID: nil, body: body))
    }
}
