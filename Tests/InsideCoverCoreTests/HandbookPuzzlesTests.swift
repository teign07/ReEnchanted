import XCTest
@testable import InsideCoverCore

final class HandbookPuzzlesTests: XCTestCase {
    private func day(_ n: Int, braid: String? = nil, words: [String] = []) -> BoundDay {
        let date = Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400)
        let items = braid.map {
            [MonthlyEditionItem(id: "b\(n)", kind: .page, title: $0, body: "Body", date: date, pageType: .bookOfYou, sourceID: nil, mediaAssets: [], tags: [])]
        } ?? []
        return BoundDay(
            id: "d\(n)", date: date,
            almanac: BoundDayAlmanac(moonName: "Waxing Gibbous", moonIlluminated: 0.7, moonAgeDays: 10, skyWords: [], feast: nil),
            scenes: [], clippings: [], castLines: [], braids: items, photos: [], words: words, keeps: [], specimens: []
        )
    }

    private func cast(_ names: [String]) -> [BoundCastPresence] {
        names.map { BoundCastPresence(slug: $0.lowercased(), name: $0, plateAssetName: nil, daysPresent: 2, sceneCount: 2, actCount: 1, rooms: []) }
    }

    private lazy var book: BoundDayBook = {
        let days = [
            day(1, braid: "The Lantern Gate", words: ["The plastic lemon seltzer bottle was cool in the hand and the evening went on quietly."]),
            day(2, braid: "Hallway of Marmalade", words: ["Amanda made the coffee and we talked about nothing important at all this morning."]),
            day(3, braid: "A Sideways Tuesday", words: ["The photograph of the dog on the porch had somehow become the best part of the week."]),
            day(4, braid: "Wonder Compass Notes", words: ["Walking to the office I noticed the thinnest sliver of moon sitting over the car park."])
        ]
        return BoundDayBook(
            days: days, weeks: [],
            chart: LabyrinthMonthChart(roomVisits: ["location-stacks": 3, "location-east-stacks": 2, "location-vault-of-doors": 1, "location-old-reading-room": 1], route: [],
                                       cast: cast(["Penny Blackletter", "Ambrose Trencher", "Wicker Eddies", "Mook"]), timetableOnly: false),
            quietDates: []
        )
    }()

    // MARK: The chairs

    func testTheChairsHaveExactlyOneAnswerAndItIsTheOneWeKeep() throws {
        for seed in ["week-6", "week-7", "october"] {
            let sudoku = try XCTUnwrap(HandbookWorkbookBuilder.sudoku(terms: ["labyrinth"], dayBook: nil, seed: seed))
            XCTAssertEqual(Set(sudoku.symbols).count, sudoku.size, "six different symbols")
            XCTAssertEqual(HandbookWorkbookBuilder.solutionCount(sudoku.given, size: sudoku.size, boxRows: sudoku.boxRows, boxCols: sudoku.boxCols, limit: 2), 1, seed)
            for (cell, value) in sudoku.given.enumerated() where value >= 0 { XCTAssertEqual(value, sudoku.solution[cell]) }
            XCTAssertLessThan(sudoku.given.filter { $0 >= 0 }.count, sudoku.size * sudoku.size - 10, "it is a puzzle, not a finished grid")
            // The solution obeys rows, columns and boxes.
            let n = sudoku.size
            for i in 0..<n {
                XCTAssertEqual(Set((0..<n).map { sudoku.solution[i * n + $0] }).count, n)
                XCTAssertEqual(Set((0..<n).map { sudoku.solution[$0 * n + i] }).count, n)
            }
            for br in stride(from: 0, to: n, by: sudoku.boxRows) {
                for bc in stride(from: 0, to: n, by: sudoku.boxCols) {
                    var box = Set<Int>()
                    for dr in 0..<sudoku.boxRows { for dc in 0..<sudoku.boxCols { box.insert(sudoku.solution[(br + dr) * n + bc + dc]) } }
                    XCTAssertEqual(box.count, n)
                }
            }
        }
    }

    func testTheChairsAreTheSameOnAReprintAndDifferentNextWeek() throws {
        let a = HandbookWorkbookBuilder.sudoku(terms: ["labyrinth"], dayBook: nil, seed: "week-6")
        XCTAssertEqual(a, HandbookWorkbookBuilder.sudoku(terms: ["labyrinth"], dayBook: nil, seed: "week-6"))
        XCTAssertNotEqual(a?.given, HandbookWorkbookBuilder.sudoku(terms: ["labyrinth"], dayBook: nil, seed: "week-7")?.given)
    }

    func testTheChairsUseTheReadersLettersWhenAWordHasSix() throws {
        let sudoku = try XCTUnwrap(HandbookWorkbookBuilder.sudoku(terms: ["lantern"], dayBook: nil, seed: "s"))
        XCTAssertEqual(Set(sudoku.symbols), Set(["L", "A", "N", "T", "E", "R"]))
    }

    // MARK: Made of the reader's days

    func testMissingWordsAreTheReadersOwnWordsAndTheBankHoldsThemAll() throws {
        let cloze = try XCTUnwrap(HandbookWorkbookBuilder.cloze(days: book.days, seed: "week-6"))
        XCTAssertGreaterThanOrEqual(cloze.sentences.count, 2)
        XCTAssertEqual(cloze.answers.count, cloze.sentences.count)
        for (sentence, answer) in zip(cloze.sentences, cloze.answers) {
            XCTAssertTrue(sentence.contains(HandbookCloze.blank))
            XCTAssertFalse(sentence.lowercased().contains(answer.lowercased()), "the answer is not left in the sentence")
            XCTAssertTrue(cloze.bank.contains(answer))
            let restored = sentence.replacingOccurrences(of: HandbookCloze.blank, with: answer)
            XCTAssertTrue(book.days.flatMap(\.words).contains { $0.contains(restored) || restored.contains($0) || $0 == restored }, restored)
        }
        XCTAssertGreaterThan(cloze.bank.count, cloze.answers.count, "decoys")
    }

    func testTheScrambledCastIsReallyScrambled() throws {
        let set = try XCTUnwrap(HandbookWorkbookBuilder.anagrams(terms: ["lantern", "threshold", "marmalade"], dayBook: book, seed: "week-6"))
        XCTAssertGreaterThanOrEqual(set.items.count, 4)
        for item in set.items {
            XCTAssertNotEqual(item.scrambled, item.answer)
            XCTAssertEqual(item.scrambled.sorted(), item.answer.sorted())
        }
        XCTAssertEqual(Set(set.items.map(\.answer)).count, set.items.count)
    }

    func testVowelsFledCanBePutBack() throws {
        let set = try XCTUnwrap(HandbookWorkbookBuilder.vowels(dayBook: book, seed: "week-6"))
        XCTAssertGreaterThanOrEqual(set.items.count, 4)
        for item in set.items {
            XCTAssertFalse(item.stripped.contains(where: { "AEIOU".contains($0) }), item.stripped)
            XCTAssertEqual(item.stripped.filter { $0 != " " }, item.answer.uppercased().filter { !"AEIOU ".contains($0) })
        }
    }

    func testOddOneOutHasOneAnswerAndSaysWhy() throws {
        let odd = try XCTUnwrap(HandbookWorkbookBuilder.oddOne(dayBook: book, seed: "week-6"))
        XCTAssertGreaterThanOrEqual(odd.rounds.count, 3)
        for round in odd.rounds {
            XCTAssertEqual(round.options.count, 4)
            XCTAssertEqual(Set(round.options).count, 4)
            XCTAssertTrue(round.reason.contains(round.options[round.answer]), round.reason)
        }
    }

    func testAThinWeekMakesWhatItCanAndNothingElse() {
        let thin = BoundDayBook(days: [day(1)], weeks: [], chart: LabyrinthMonthChart(roomVisits: [:], route: [], cast: [], timetableOnly: true), quietDates: [])
        XCTAssertNil(HandbookWorkbookBuilder.cloze(days: thin.days, seed: "s"))
        XCTAssertNil(HandbookWorkbookBuilder.vowels(dayBook: thin, seed: "s"))
        XCTAssertNil(HandbookWorkbookBuilder.oddOne(dayBook: thin, seed: "s"))
    }

    // MARK: Rotation

    private func fullWorkbook() -> HandbookWorkbook {
        HandbookWorkbook(
            wordSearch: nil, maze: HandbookMaze.make(seed: "x"),
            cipher: HandbookCipher(plain: "a", cipher: "b", hints: []),
            matching: HandbookMatching(lines: [], speakers: [], answer: []),
            ordering: HandbookOrdering(events: [], rank: []),
            exam: nil, reportCard: nil,
            cloze: HandbookCloze(sentences: [], bank: [], answers: []),
            anagrams: HandbookAnagrams(items: []),
            vowels: HandbookVowels(items: []),
            sudoku: HandbookWorkbookBuilder.sudoku(terms: [], dayBook: nil, seed: "x"),
            oddOne: HandbookOddOne(rounds: [])
        )
    }

    func testEachWeekCarriesThreeKindsAndNotAlwaysTheSameThree() {
        var seen = Set<Set<HandbookWorkbook.PuzzleKind>>()
        for issue in 1...12 {
            var workbook = fullWorkbook()
            workbook.rotate(seed: "week-\(issue)", keep: 3)
            XCTAssertEqual(workbook.presentKinds.count, 3)
            seen.insert(Set(workbook.presentKinds))
        }
        XCTAssertGreaterThanOrEqual(seen.count, 6, "twelve issues, at least six different mixes")
        var again = fullWorkbook(); again.rotate(seed: "week-4", keep: 3)
        var same = fullWorkbook(); same.rotate(seed: "week-4", keep: 3)
        XCTAssertEqual(again.presentKinds, same.presentKinds, "a reprint is the same book")
    }

    func testAThinWeekMayOnlyDrawOnTheLightKinds() {
        var workbook = fullWorkbook()
        workbook.rotate(seed: "week-3", keep: 6, allowed: { !$0.needsFullWeek })
        XCTAssertNil(workbook.matching)
        XCTAssertNil(workbook.ordering)
        XCTAssertEqual(workbook.presentKinds.count, 6)
    }

    func testTheWeeklySliceRotatesAndTrimsTheNewKindsFirst() {
        var handbook = Handbook(lessons: [], lore: [], compass: [], dossiers: [], bestiary: [], spells: [], workbook: fullWorkbook(), ruinCount: nil)
        let slice = handbook.weeklySlice(issueNumber: 6, level: 9)
        XCTAssertEqual(slice.workbook?.presentKinds.count, 3)
        XCTAssertEqual(handbook.weeklySlice(issueNumber: 6, level: 1).workbook?.presentKinds.count, 0)
        handbook.workbook = fullWorkbook()
        let trimmed = handbook.trimmedOnce()
        XCTAssertNotNil(trimmed?.workbook?.cipher, "the older puzzles outlast the newer ones")
        XCTAssertNil(trimmed?.workbook?.oddOne)
    }
}

final class NotePromptsTests: XCTestCase {
    func testAPackIsDealtBeforeTheBundledBankAndNothingRepeatsInABook() throws {
        let delivered = [NotePrompts.Delivered(id: "oct-1", kind: "day", text: "What did the dark come early for tonight?")]
        var used = Set<String>()
        let first = try XCTUnwrap(NotePrompts.pick(kind: .day, seed: "d1", avoiding: used, delivered: delivered))
        XCTAssertEqual(first.id, "oct-1", "the month's own prompt comes first")
        used.insert(first.id)
        var asked: [String] = [first.id]
        for day in 2...12 {
            let next = try XCTUnwrap(NotePrompts.pick(kind: .day, seed: "d\(day)", avoiding: used, delivered: delivered))
            XCTAssertFalse(asked.contains(next.id), "\(next.id) asked twice")
            asked.append(next.id); used.insert(next.id)
        }
    }

    func testAPuzzleLeafGetsAPuzzlePromptNotADayOne() throws {
        for seed in ["a", "b", "c", "d"] {
            let row = try XCTUnwrap(NotePrompts.pick(kind: .puzzle, seed: seed, avoiding: []))
            XCTAssertTrue(row.kind == .puzzle || row.kind == .any, row.id)
        }
    }

    func testSameIdReplacesAndRetiredLeaves() {
        let bank = NotePrompts.bank(
            delivered: [NotePrompts.Delivered(id: "np-d01", kind: "day", text: "A fresh way to ask for one sentence today.")],
            retiring: ["np-d02"])
        XCTAssertFalse(bank.bundled.contains { $0.id == "np-d01" })
        XCTAssertFalse(bank.bundled.contains { $0.id == "np-d02" })
        XCTAssertEqual(bank.delivered.map(\.id), ["np-d01"])
    }

    func testABadDeliveredPromptIsDroppedNotFatal() {
        let bad = [
            NotePrompts.Delivered(id: "", kind: nil, text: "Write something down today."),
            NotePrompts.Delivered(id: "x1", kind: "nonsense", text: "Write something down today."),
            NotePrompts.Delivered(id: "x2", kind: nil, text: "No full stop here at all"),
            NotePrompts.Delivered(id: "x3", kind: nil, text: "A ritual for the evening, written down."),
            NotePrompts.Delivered(id: "x4", kind: nil, text: "Hi.")
        ]
        XCTAssertTrue(bad.allSatisfy { !NotePrompts.acceptable($0) })
        XCTAssertTrue(NotePrompts.acceptable(NotePrompts.Delivered(id: "ok", kind: "puzzle", text: "Write a riddle whose answer is a pumpkin.")))
        XCTAssertTrue(NotePrompts.bank(delivered: bad).delivered.isEmpty)
    }

    func testAMonthsLessonsAreNotAskedTheSameMarginTwice() throws {
        var used = Set<String>()
        for lesson in 1...24 {
            let row = try XCTUnwrap(NotePrompts.pick(kind: .margin, seed: "lesson-\(lesson)", avoiding: used))
            XCTAssertTrue(row.kind == .margin || row.kind == .any)
            XCTAssertFalse(used.contains(row.id), "lesson \(lesson) repeated \(row.id)")
            used.insert(row.id)
        }
    }

    func testTheBundledBankKeepsItsOwnPromises() {
        XCTAssertEqual(Set(NotePrompts.bundled.map(\.id)).count, NotePrompts.bundled.count)
        for row in NotePrompts.bundled {
            XCTAssertTrue(NotePrompts.acceptable(NotePrompts.Delivered(id: row.id, kind: row.kind.rawValue, text: row.text)), row.id)
        }
    }

    func testOlderPacksDecodeAndNewOnesCarryPrompts() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json"))
        ) as? [String: Any])
        object["notePrompts"] = nil
        object["retiredNotePromptIDs"] = nil
        let old = try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.notePrompts)
        object["notePrompts"] = [["id": "o1", "kind": "day", "text": "What did the dark come early for tonight?"]]
        object["retiredNotePromptIDs"] = ["np-d04"]
        let new = try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(new.notePrompts?.first?.id, "o1")
        XCTAssertEqual(new.retiredNotePromptIDs, ["np-d04"])
    }

    func testOctobersOwnPromptsAllClearTheBarAndDealFirst() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let pack = try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
        let prompts = try XCTUnwrap(pack.notePrompts)
        XCTAssertGreaterThanOrEqual(prompts.count, 12)
        XCTAssertTrue(prompts.allSatisfy(NotePrompts.acceptable), "every October prompt must survive the app's own check")
        XCTAssertEqual(NotePrompts.bank(delivered: prompts).delivered.count, prompts.count)
        let first = try XCTUnwrap(NotePrompts.pick(kind: .day, seed: "d1", avoiding: [], delivered: prompts))
        XCTAssertTrue(first.id.hasPrefix("oct26-"))
    }
}

final class ChosenLessonsTests: XCTestCase {
    private func lesson(_ id: String, attended: Int = 0) -> HandbookLesson {
        HandbookLesson(id: id, kind: "class", name: id, leader: "L", leaderSlug: nil, room: "R", title: "T", realSubject: "S",
                       concept: "C", beats: [], demonstration: "", interaction: "", realWorldPractice: "P", practiceTitle: "PT",
                       invitation: "I", fields: [], readerEntry: nil, attendedCount: attended)
    }

    func testALightMonthPrintsFewRoomsAndAFullOneAll() {
        let all = (1...12).map { lesson("c\($0)") }
        XCTAssertEqual(HandbookBuilder.chosenLessons(all, keptPages: 20, seed: "2026-10").count, 4)
        XCTAssertEqual(HandbookBuilder.chosenLessons(all, keptPages: 39, seed: "2026-10").count, 6)
        XCTAssertEqual(HandbookBuilder.chosenLessons(all, keptPages: 200, seed: "2026-10").count, 12)
    }

    func testEveryRoomTheReaderSatIsPrintedAndTheRestRotateByMonth() {
        var all = (1...12).map { lesson("c\($0)") }
        all[10] = lesson("c11", attended: 2)
        all[11] = lesson("c12", attended: 1)
        let october = HandbookBuilder.chosenLessons(all, keptPages: 20, seed: "2026-10")
        XCTAssertTrue(october.contains { $0.id == "c11" } && october.contains { $0.id == "c12" }, "sat rooms always come")
        XCTAssertEqual(october.map(\.id), HandbookBuilder.chosenLessons(all, keptPages: 20, seed: "2026-10").map(\.id), "a reprint is the same book")
        let others = (11...20).map { HandbookBuilder.chosenLessons(all, keptPages: 20, seed: "2026-\($0)").map(\.id) }
        XCTAssertGreaterThan(Set(others.map { $0.joined() }).count, 3, "different months teach different rooms")
        XCTAssertEqual(HandbookBuilder.chosenLessons(all, keptPages: 0, seed: "x").count, 4)
    }

    func testTheGenericRoomsAreGivenUpBeforeTheReadersPuzzles() {
        let lessons = (1...6).map { lesson("c\($0)") }
        var handbook = Handbook(lessons: lessons, lore: [], compass: [], dossiers: [], bestiary: [], spells: [],
                                workbook: HandbookWorkbook(wordSearch: nil, maze: HandbookMaze.make(seed: "x"), cipher: nil, matching: nil, ordering: nil,
                                                           exam: nil, reportCard: nil, cloze: nil, anagrams: nil, vowels: nil,
                                                           sudoku: HandbookWorkbookBuilder.sudoku(terms: [], dayBook: nil, seed: "x"), oddOne: nil),
                                ruinCount: nil)
        var steps = 0
        while handbook.lessons.count > Handbook.minimumLessons, let thinner = handbook.trimmedOnce() {
            handbook = thinner
            XCTAssertNotNil(handbook.workbook?.sudoku, "the puzzle outlasts the rooms it was weighed against")
            steps += 1
            XCTAssertLessThan(steps, 20)
        }
        XCTAssertEqual(handbook.lessons.count, Handbook.minimumLessons)
        XCTAssertNotNil(handbook.workbook?.sudoku)
    }
}
