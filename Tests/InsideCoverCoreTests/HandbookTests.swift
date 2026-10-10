import XCTest
@testable import InsideCoverCore

/// The Handbook is the Academy's side of the printed volume. It must be the
/// same book every time it is asked for, and it must never invent a reader's
/// hand on a worksheet they did not write.
final class HandbookTests: XCTestCase {
    private func classPage(_ id: String, session: String, outcome: String? = nil, day: Int = 5) -> BookPage {
        var metadata = ["sessionID": session]
        if let outcome { metadata["academyActivityOutcome"] = outcome }
        var page = BookPage(
            id: id, type: .academyClass,
            createdAt: Date(timeIntervalSince1970: 1_790_000_000 + Double(day) * 86_400),
            promptText: "Prompt", userInput: "Class"
        )
        page.metadata = metadata
        return page
    }

    private func make(pages: [BookPage] = [], terms: [String] = ["lantern", "threshold"]) -> Handbook {
        HandbookBuilder.make(pages: pages, castPresence: [], terms: terms, seed: "2026-10")
    }

    func testEveryClassAndClubHasALessonAndAWorksheet() {
        let handbook = make()
        XCTAssertFalse(handbook.classes.isEmpty)
        XCTAssertFalse(handbook.societies.isEmpty)
        for lesson in handbook.lessons {
            XCTAssertFalse(lesson.title.isEmpty, lesson.id)
            XCTAssertFalse(lesson.beats.isEmpty, lesson.id)
            XCTAssertFalse(lesson.invitation.isEmpty, lesson.id)
        }
        XCTAssertTrue(handbook.lessons.contains { !$0.fields.isEmpty })
    }

    func testReaderEntryAppearsOnlyForTheRoomTheySat() throws {
        let glint = "art-of-the-glint"
        let handbook = make(pages: [classPage("c1", session: glint, outcome: "A brass key, warm from my pocket.")])
        let lesson = try XCTUnwrap(handbook.lessons.first { $0.id == glint })
        XCTAssertTrue(lesson.attended)
        XCTAssertEqual(lesson.readerEntry, "A brass key, warm from my pocket.")
        XCTAssertTrue(handbook.lessons.filter { $0.id != glint }.allSatisfy { $0.readerEntry == nil && !$0.attended })
        XCTAssertEqual(handbook.attendedCount, 1)
    }

    func testLatestEntryWinsAndAttendanceCounts() throws {
        let glint = "art-of-the-glint"
        let handbook = make(pages: [
            classPage("c1", session: glint, outcome: "First", day: 3),
            classPage("c2", session: glint, outcome: "Second", day: 9),
            classPage("c3", session: glint, day: 12)
        ])
        let lesson = try XCTUnwrap(handbook.lessons.first { $0.id == glint })
        XCTAssertEqual(lesson.attendedCount, 3)
        XCTAssertEqual(lesson.readerEntry, "Second")
    }

    func testLoreIsDeterministicAndFavoursTheReadersWords() {
        let a = make(terms: ["hawthorn", "threshold", "iron"])
        let b = make(terms: ["hawthorn", "threshold", "iron"])
        XCTAssertEqual(a.lore, b.lore)
        XCTAssertEqual(a.compass, b.compass)
        XCTAssertFalse(a.lore.isEmpty)
        // Any entry that claims a reason must name a word the reader actually has.
        for entry in a.lore + a.compass {
            if let why = entry.why {
                XCTAssertTrue(["hawthorn", "threshold", "iron"].contains { why.contains($0) }, why)
            }
        }
    }

    func testNoTermsMeansNoFalseReasons() {
        let handbook = make(terms: [])
        XCTAssertFalse(handbook.lore.isEmpty)
        XCTAssertTrue(handbook.lore.allSatisfy { $0.why == nil })
    }

    func testExcerptsEndOnWholeSentences() {
        for entry in make().lore {
            let last = entry.body.trimmingCharacters(in: .whitespacesAndNewlines).last
            XCTAssertTrue(last.map { ".!?\"”)*".contains($0) } ?? false, entry.title)
        }
    }

    func testDossiersCoverOnlyCastWithBiosInPresenceOrder() {
        let presence = [
            BoundCastPresence(slug: "not-a-dossier", name: "Nobody", plateAssetName: nil, daysPresent: 9, sceneCount: 9, actCount: 0, rooms: []),
            BoundCastPresence(slug: "wicker-eddies", name: "Wicker Eddies", plateAssetName: nil, daysPresent: 5, sceneCount: 3, actCount: 0, rooms: []),
            BoundCastPresence(slug: "pippa-pilcrow", name: "Pippa Pilcrow", plateAssetName: nil, daysPresent: 2, sceneCount: 1, actCount: 0, rooms: [])
        ]
        let dossiers = HandbookBuilder.dossiers(from: presence, limit: 5)
        XCTAssertEqual(dossiers.map(\.slug), ["wicker-eddies", "pippa-pilcrow"])
        XCTAssertTrue(dossiers.allSatisfy { $0.paragraphs.count >= 2 })
    }

    func testTrimmingNeverDropsTheReadersOwnLessons() throws {
        var handbook = make(pages: [classPage("c1", session: "art-of-the-glint", outcome: "Mine")])
        var steps = 0
        while let thinner = handbook.trimmedOnce() {
            handbook = thinner
            steps += 1
            XCTAssertLessThan(steps, 200)
        }
        XCTAssertTrue(handbook.lessons.contains { $0.id == "art-of-the-glint" && $0.readerEntry == "Mine" })
        XCTAssertTrue(handbook.lessons.allSatisfy(\.attended))
        XCTAssertTrue(handbook.lore.isEmpty)
    }

    func testSpellSheetCountsCasts() {
        var cast = BookPage(id: "e1", type: .enchantment, createdAt: Date(), promptText: "p", userInput: "x")
        cast.metadata = ["spellID": "everything-speaks"]
        let spells = HandbookBuilder.spells(from: [cast])
        XCTAssertEqual(spells.first { $0.id == "everything-speaks" }?.timesCast, 1)
        XCTAssertEqual(spells.first { $0.id == "mirror-mirror" }?.timesCast, 0)
    }

    // MARK: Workbook

    private func day(_ n: Int, braid: String? = nil, words: [String] = [], lines: [BoundDayCastLine] = [], keeps: [BoundDayKeep] = []) -> BoundDay {
        let date = Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400)
        var item: [MonthlyEditionItem] = []
        if let braid {
            item = [MonthlyEditionItem(id: "b\(n)", kind: .page, title: braid, body: "Body", date: date, pageType: .bookOfYou, sourceID: nil, mediaAssets: [], tags: [])]
        }
        return BoundDay(
            id: "d\(n)", date: date,
            almanac: BoundDayAlmanac(moonName: "Waxing Gibbous", moonIlluminated: 0.7, moonAgeDays: 10, skyWords: [], feast: nil),
            scenes: [], clippings: [], castLines: lines, braids: item, photos: [], words: words,
            keeps: keeps, specimens: []
        )
    }

    func testWordSearchHidesEveryWordWhereItClaims() throws {
        let search = try XCTUnwrap(HandbookWordSearch.make(
            candidates: ["lantern", "threshold", "hawthorn", "ember", "margin", "labyrinth", "iron"], seed: "s"))
        XCTAssertEqual(search.rows.count, search.size)
        XCTAssertTrue(search.rows.allSatisfy { $0.count == search.size })
        for placed in search.words {
            let rows = search.rows.map(Array.init)
            let spelled = (0..<placed.word.count).map { rows[placed.row + placed.dRow * $0][placed.col + placed.dCol * $0] }
            XCTAssertEqual(String(spelled), placed.word)
        }
        XCTAssertEqual(search, HandbookWordSearch.make(
            candidates: ["lantern", "threshold", "hawthorn", "ember", "margin", "labyrinth", "iron"], seed: "s"))
    }

    func testMazeIsSolvableAndSolutionWalksOpenDoors() {
        let maze = HandbookMaze.make(seed: "m")
        XCTAssertEqual(maze.solution.first, 0)
        XCTAssertEqual(maze.solution.last, maze.width * maze.height - 1)
        for (a, b) in zip(maze.solution, maze.solution.dropFirst()) {
            let dx = b % maze.width - a % maze.width, dy = b / maze.width - a / maze.width
            let bit: UInt8 = dx == 1 ? HandbookMaze.east : dx == -1 ? HandbookMaze.west : dy == 1 ? HandbookMaze.south : HandbookMaze.north
            XCTAssertNotEqual(maze.open[a] & bit, 0)
        }
    }

    func testCipherDecodesBackToTheReadersOwnSentence() throws {
        let line = "I learned the name of the bakery cat after work today."
        let cipher = try XCTUnwrap(HandbookWorkbookBuilder.cipher(days: [day(1, words: [line])], seed: "c"))
        XCTAssertEqual(cipher.plain, line)
        XCTAssertNotEqual(cipher.cipher, line.uppercased())
        XCTAssertEqual(cipher.cipher.count, line.count)
        XCTAssertEqual(cipher.hints.count, 3)
    }

    func testNoWordsMeansNoCipher() {
        XCTAssertNil(HandbookWorkbookBuilder.cipher(days: [day(1, words: ["Too short."])], seed: "c"))
    }

    func testOrderingKeyIsAPermutation() throws {
        let days = (1...8).map { day($0, braid: "Night number \($0)") }
        let order = try XCTUnwrap(HandbookWorkbookBuilder.ordering(days: days, seed: "o"))
        XCTAssertEqual(order.rank.sorted(), Array(1...order.events.count))
        for (event, rank) in zip(order.events, order.rank) {
            XCTAssertTrue(event.hasSuffix("\(days.firstIndex { $0.braids.first?.title == event }! + 1)") || rank > 0)
        }
    }

    func testMatchingNeedsThreeVoices() {
        let line = { (id: String, name: String) in BoundDayCastLine(id: id, speakerID: id, speakerName: name, line: "A line long enough to be worth asking about.") }
        XCTAssertNil(HandbookWorkbookBuilder.matching(days: [day(1, lines: [line("a", "A"), line("b", "B")])], seed: "m"))
        let three = HandbookWorkbookBuilder.matching(days: [day(1, lines: [line("a", "A"), line("b", "B"), line("c", "C")])], seed: "m")
        XCTAssertEqual(three?.lines.count, 3)
        for (i, answer) in (three?.answer ?? []).enumerated() { XCTAssertTrue((three?.speakers.indices ?? 0..<0).contains(answer), "\(i)") }
    }

    func testMarksNeverPenaliseAbsence() {
        XCTAssertEqual(HandbookWorkbookBuilder.mark(count: 0, target: 10), .incomplete)
        XCTAssertEqual(HandbookWorkbookBuilder.mark(count: 1, target: 10), .resit)
        XCTAssertEqual(HandbookWorkbookBuilder.mark(count: 3, target: 10), .pass)
        XCTAssertEqual(HandbookWorkbookBuilder.mark(count: 6, target: 10), .merit)
        XCTAssertEqual(HandbookWorkbookBuilder.mark(count: 10, target: 10), .distinction)
    }

    func testReportCardResitCarriesAnErrandAndNothingElseDoes() throws {
        let braids = (1...2).map { day($0, braid: "Night \($0)") }
        let card = HandbookWorkbookBuilder.reportCard(
            pages: [], dayBook: BoundDayBook(days: braids, weeks: [], chart: LabyrinthMonthChart(roomVisits: [:], route: [], cast: [], timetableOnly: true), quietDates: []),
            dayCount: 30, proctorSlug: "nobody", onLeave: false)
        XCTAssertEqual(card.proctorSlug, HandbookReportCard.defaultProctorSlug)
        XCTAssertEqual(card.subjects.first { $0.id == "noticing" }?.mark, .resit)
        XCTAssertNotNil(card.subjects.first { $0.id == "noticing" }?.resitErrand)
        XCTAssertTrue(card.subjects.filter { $0.id != "noticing" }.allSatisfy { $0.mark == .incomplete && $0.resitErrand == nil })
        // A subject still open is a door with a note on it: one real thing waiting there.
        XCTAssertEqual(HandbookReportCard.Mark.incomplete.title, "Still open")
        let open = card.subjects.filter { $0.mark == .incomplete }
        XCTAssertTrue(open.allSatisfy { ($0.invitation ?? "").count > 20 })
        let curiosity = try XCTUnwrap(open.first { $0.id == "curiosity" }?.invitation)
        XCTAssertTrue(AcademyScheduleRegistry.classes.values.contains { curiosity.contains($0.name) && curiosity.contains($0.room) },
                      "The class it names is a real one, with its real room.")
        let initiative = try XCTUnwrap(open.first { $0.id == "initiative" }?.invitation)
        XCTAssertTrue(StoryEnchantmentCatalog.spells.contains { initiative.hasPrefix($0.title) })
    }

    func testOnLeaveMonthCarriesNoMarks() {
        let card = HandbookWorkbookBuilder.reportCard(pages: [], dayBook: nil, dayCount: 30, proctorSlug: "wicker-eddies", onLeave: true)
        XCTAssertTrue(card.onLeave)
        XCTAssertTrue(card.subjects.isEmpty)
        XCTAssertEqual(card.proctorName, "Wicker Eddies")
        XCTAssertTrue(card.verdict.contains("kept your place"))
    }

    func testHandbookTrimKeepsExamAndReportCardLast() {
        var handbook = make()
        handbook.workbook = HandbookWorkbook(
            wordSearch: nil, maze: HandbookMaze.make(seed: "x"), cipher: nil, matching: nil, ordering: nil,
            exam: HandbookExam(questions: [], shortAnswers: []),
            reportCard: HandbookReportCard(proctorSlug: "p", proctorName: "P", onLeave: false, subjects: [], verdict: "v"))
        while let thinner = handbook.trimmedOnce() { handbook = thinner }
        XCTAssertNotNil(handbook.workbook?.reportCard)
        XCTAssertNotNil(handbook.workbook?.exam)
    }

    // MARK: Titles

    private let magpie = BoundReaderRole(fullName: "The Magpie of the Blue Hour", signature: "s", gloss: "g", compassLine: "c")

    func testReaderNamingAlwaysWins() {
        let title = EditionTitler.monthly(readerNamed: "  Our Hard Autumn ", packTitle: "Count Unbound", role: magpie, theme: nil, monthTitle: "October 2026")
        XCTAssertEqual(title.line, "Our Hard Autumn")
        XCTAssertEqual(title.reason, "Named by you.")
    }

    func testPersonalTitleNamesTheRoleAndPrintsItsReason() throws {
        let title = EditionTitler.monthly(readerNamed: nil, packTitle: "Count Unbound", role: magpie, theme: nil, monthTitle: "October 2026")
        XCTAssertEqual(title.line, "The Magpie\u{2019}s Count Unbound")
        XCTAssertTrue(try XCTUnwrap(title.reason).contains("The Magpie of the Blue Hour"))
    }

    func testTitleFallsBackWithoutInventingAReason() {
        let plain = EditionTitler.monthly(readerNamed: nil, packTitle: nil, role: nil, theme: nil, monthTitle: "October 2026")
        XCTAssertEqual(plain.line, "October 2026")
        XCTAssertNil(plain.reason)
        let packOnly = EditionTitler.monthly(readerNamed: nil, packTitle: "Count Unbound", role: nil, theme: nil, monthTitle: "October 2026")
        XCTAssertEqual(packOnly.line, "Count Unbound: October 2026")
    }

    func testOverlongRoleNounIsNotUsed() {
        let long = BoundReaderRole(fullName: "The Extraordinarily Persistent Collector of Odd Keys", signature: "s", gloss: "g", compassLine: "c")
        let title = EditionTitler.monthly(readerNamed: nil, packTitle: "Count Unbound", role: long, theme: nil, monthTitle: "October 2026")
        XCTAssertEqual(title.line, "Count Unbound: October 2026")
    }

    // MARK: Thickness

    func testOnlyTiersTheContentCanFillAreOffered() {
        XCTAssertEqual(PrintThickness.available(for: .monthly, naturalPages: 40), [128])
        XCTAssertEqual(PrintThickness.available(for: .monthly, naturalPages: 100), [128])
        XCTAssertEqual(PrintThickness.available(for: .monthly, naturalPages: 128), [128])
        XCTAssertEqual(PrintThickness.available(for: .monthly, naturalPages: 158), [128, 160])
        XCTAssertEqual(PrintThickness.available(for: .weekly, naturalPages: 33), [24, 32, 40])
    }

    func testThinTierDropsTheLightestDayAndNeverTheFullest() throws {
        let days = (1...10).map { day($0, braid: $0 == 4 ? nil : "Night \($0)", words: $0 == 4 ? [] : ["I noticed the lamp."]) }
        let book = BoundDayBook(days: days, weeks: [], chart: LabyrinthMonthChart(roomVisits: [:], route: [], cast: [], timetableOnly: true), quietDates: [])
        let lighter = try XCTUnwrap(book.droppingLightestDay(floor: 8))
        XCTAssertEqual(lighter.days.count, 9)
        XCTAssertFalse(lighter.days.contains { $0.id == "d4" })
        let floored = try XCTUnwrap(lighter.droppingLightestDay(floor: 8))
        XCTAssertNil(floored.droppingLightestDay(floor: 8))
    }

    // MARK: Page addresses

    func testAddressesAreStableAndOnlyUseUnconfusableCharacters() {
        XCTAssertEqual(PageAddress.code(seed: "2026-10-x", page: 41), PageAddress.code(seed: "2026-10-x", page: 41))
        XCTAssertNotEqual(PageAddress.code(seed: "2026-10-x", page: 41), PageAddress.code(seed: "2026-10-x", page: 42))
        let allowed = Set(PageAddress.alphabet)
        for page in 1...400 {
            let code = PageAddress.code(seed: "s", page: page)
            XCTAssertEqual(code.count, PageAddress.codeLength)
            XCTAssertTrue(code.allSatisfy(allowed.contains), code)
        }
        XCTAssertTrue(Set("0O1ILS5B2Z8").isDisjoint(with: allowed))
    }

    func testAddressRoundTripsThroughMessyOCR() throws {
        let label = PageAddress.label(seed: "v", page: 41)
        let code = PageAddress.code(seed: "v", page: 41)
        XCTAssertEqual(PageAddress.parse("\u{2014} \(label) \u{2014}"), PageAddress.Reading(page: 41, code: code))
        XCTAssertEqual(PageAddress.parse("41 . \(code.lowercased())"), PageAddress.Reading(page: 41, code: code))
        XCTAssertEqual(PageAddress.parse("The Book of You 41 \(code) tea ring"), PageAddress.Reading(page: 41, code: code))
        XCTAssertNil(PageAddress.parse("page forty-one"))
        XCTAssertNil(PageAddress.parse("41 \u{00B7} 0OIL"))
    }

    func testRegistryRecognisesItsOwnPagesAndRefusesOthers() {
        let mine = BoundVolumeRegistry(seed: "mine", editionID: "e1", title: "T", boundAt: Date(), pageCount: 108)
        let other = BoundVolumeRegistry(seed: "other", editionID: "e2", title: "U", boundAt: Date(), pageCount: 108)
        let text = "\(PageAddress.label(seed: "mine", page: 41))"
        XCTAssertEqual(mine.identify(text), .page(41))
        XCTAssertEqual(other.identify(text), .wrongVolume)
        XCTAssertEqual(mine.identify("nothing here"), .unreadable)
        XCTAssertEqual(mine.identify(PageAddress.label(seed: "mine", page: 200)), .wrongVolume, "past the last page")
        XCTAssertEqual([other, mine].volume(for: text)?.volume.editionID, "e1")
        XCTAssertEqual([other, mine].volume(for: text)?.page, 41)
    }

    func testAPageOfProseDoesNotHideItsAddress() {
        let mine = BoundVolumeRegistry(seed: "mine", editionID: "e", title: "T", boundAt: Date(), pageCount: 32)
        let prose = "WHAT THE ROOM COVERED 1 Choose one book 2 Excitement is not a landing 3 Every participant needs a definition 4 A good exit \u{2014} 15 \u{00B7} \(PageAddress.code(seed: "mine", page: 15)) \u{2014}"
        XCTAssertEqual(mine.identify(prose), .page(15))
        XCTAssertGreaterThan(PageAddress.parseAll(prose).count, 1, "the lookalike is seen, and rejected by the registry")
    }

    // MARK: Ruin pages are off until switched on

    func testRuinLeavesAreOffByDefaultAndSizedByTheBookWhenOn() {
        let key = PrintFeatureFlags.ruinPagesKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { saved == nil ? UserDefaults.standard.removeObject(forKey: key) : UserDefaults.standard.set(saved, forKey: key) }

        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(PrintFeatureFlags.ruinLeaves(dayCount: 30), 0)
        XCTAssertEqual(PrintFeatureFlags.ruinLeaves(dayCount: 7), 0)
        let off = HandbookBuilder.make(pages: [], castPresence: [], terms: [], seed: "s", dayCount: 30)
        XCTAssertNil(off.ruinCount, "nothing prints unless asked for")

        PrintFeatureFlags.ruinPagesEnabled = true
        XCTAssertEqual(PrintFeatureFlags.ruinLeaves(dayCount: 30), 4)
        XCTAssertEqual(PrintFeatureFlags.ruinLeaves(dayCount: 7), 1)
        XCTAssertEqual(HandbookBuilder.make(pages: [], castPresence: [], terms: [], seed: "s", dayCount: 30).ruinCount, 4)
        XCTAssertEqual(HandbookBuilder.make(pages: [], castPresence: [], terms: [], seed: "s", dayCount: 7, ruinLeaves: 2).ruinCount, 2)
    }
}
