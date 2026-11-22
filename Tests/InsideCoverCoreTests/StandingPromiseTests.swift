import XCTest
@testable import InsideCoverCore

/// A spell that sets a deal is asked after again: a week on, a month on,
/// three months on, and every year. The reader's own sentence comes back
/// with it, and an answered call-in is never asked twice.
final class StandingPromiseTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2027, month: 3, day: 10, hour: 12))!
    }

    private func spellPage(_ spellID: String, words: String, daysAgo: Int, id: String = "tree-page") -> BookPage {
        BookPage(
            id: id, type: .spell,
            createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
            promptText: "A spell", userInput: words, tags: ["spell", "spell:\(spellID)"]
        )
    }

    private func due(_ pages: [BookPage]) -> [PlayfulMission] {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "archive", date: now, pages: pages)]
        let today = BookDay(id: "today", date: now, pages: [])
        return PlayfulMissionRegistry.promiseMissions(for: today, inputs: inputs, now: now, calendar: calendar)
    }

    func testADealComesDueAWeekOnWithTheReadersOwnWords() throws {
        let mission = try XCTUnwrap(due([spellPage("name-a-tree", words: "The tree is called Gerald.", daysAgo: 7)]).first)
        XCTAssertTrue(mission.prompt.hasPrefix("A week ago you told a tree its name."))
        XCTAssertTrue(mission.prompt.contains("“The tree is called Gerald.”"))
        XCTAssertTrue(mission.prompt.contains("say hello every time you pass it"))
        XCTAssertEqual(mission.practice, .returnVisit)
        XCTAssertTrue(mission.proofPrompt.lowercased().contains("one sentence"))
    }

    func testADealIsQuietBetweenItsCallIns() {
        for daysAgo in [0, 3, 6, 10, 29, 45, 89, 200, 364] {
            XCTAssertTrue(
                due([spellPage("name-a-tree", words: "The tree is called Gerald.", daysAgo: daysAgo)]).isEmpty,
                "asked on day \(daysAgo)"
            )
        }
    }

    func testAStandingDealIsAskedAfterForYears() throws {
        let month = try XCTUnwrap(due([spellPage("name-a-tree", words: "Gerald, the big ash.", daysAgo: 31)]).first)
        XCTAssertTrue(month.prompt.hasPrefix("A month ago"))
        let year = try XCTUnwrap(due([spellPage("name-a-tree", words: "Gerald, the big ash.", daysAgo: 365)]).first)
        XCTAssertTrue(year.prompt.hasPrefix("A year ago you told a tree its name."))
        let three = try XCTUnwrap(due([spellPage("name-a-tree", words: "Gerald, the big ash.", daysAgo: 365 * 3 + 1)]).first)
        XCTAssertTrue(three.prompt.hasPrefix("Three years ago"))
    }

    func testADeedThatWasOverThatDayIsVisitedOnce() {
        XCTAssertEqual(due([spellPage("leave-a-gift", words: "A marble on the wall by the bus stop.", daysAgo: 8)]).count, 1)
        XCTAssertTrue(due([spellPage("leave-a-gift", words: "A marble on the wall by the bus stop.", daysAgo: 30)]).isEmpty)
        XCTAssertTrue(due([spellPage("leave-a-gift", words: "A marble on the wall by the bus stop.", daysAgo: 365)]).isEmpty)
    }

    func testAnAnsweredCallInIsNotAskedAgainButTheNextOneStillComes() {
        let spell = spellPage("name-a-tree", words: "The tree is called Gerald.", daysAgo: 8)
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "promise-tree-page-d7", title: "The Tree's Waiting",
            invitation: "Have you?", proofPrompt: "One sentence.",
            facets: [.exactAttention],
            sourceTags: ["mission:promise-source:tree-page", "mission:promise-call:tree-page:d7"],
            hasWrittenProof: true, hasVisualProof: false,
            completedAt: now.addingTimeInterval(-3_600), wasPromptedByBook: true
        )
        let answer = BookPage(
            id: "tree-answer", type: .wonderCompass, createdAt: now.addingTimeInterval(-3_600),
            promptText: receipt.title, userInput: "Said hello to Gerald twice and forgot once.",
            livedQuestReceipt: receipt
        )
        XCTAssertTrue(due([spell, answer]).isEmpty)

        let later = spellPage("name-a-tree", words: "The tree is called Gerald.", daysAgo: 30)
        XCTAssertEqual(due([later, answer]).first?.id, "promise-tree-page-d30")
    }

    func testASpellWithNoDealAndAPageThatIsNotASpellAskNothing() {
        XCTAssertTrue(due([spellPage("bibliomancy", words: "The line was about soup.", daysAgo: 7)]).isEmpty)
        var diary = spellPage("name-a-tree", words: "I thought about naming a tree.", daysAgo: 7)
        diary = BookPage(id: diary.id, type: .diary, createdAt: diary.createdAt, promptText: "Diary",
                         userInput: diary.userInput, tags: diary.tags)
        XCTAssertTrue(due([diary]).isEmpty)
    }

    func testALongPageKeepsItsDealAndLosesTheQuote() throws {
        let long = String(repeating: "the big ash by the gate ", count: 12)
        let mission = try XCTUnwrap(due([spellPage("name-a-tree", words: long, daysAgo: 7)]).first)
        XCTAssertFalse(mission.prompt.contains("You wrote"))
        XCTAssertTrue(mission.prompt.hasPrefix("A week ago you told a tree its name."))
    }

    func testEveryDealBelongsToARealSpellAndAsksForOneSentence() {
        let spells = Set(SpellRegistry.all.map(\.id))
        for (id, terms) in PlayfulMissionRegistry.promiseTerms {
            XCTAssertTrue(spells.contains(id), "\(id) is not a spell")
            XCTAssertTrue(terms.proof.hasPrefix("One sentence"), id)
        }
    }

    func testADueDealTakesTheMissionSeatOnAlternateTurns() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "archive", date: now, pages: [
            spellPage("name-a-tree", words: "The tree is called Gerald.", daysAgo: 7)
        ])]
        let today = BookDay(id: "today", date: now, pages: [])
        var promised = 0
        var ordinary = 0
        for slot in 0..<12 {
            let at = now.addingTimeInterval(Double(slot) * 2 * 3_600 - 12 * 3_600)
            guard calendar.isDate(at, inSameDayAs: now) else { continue }
            let mission = PlayfulMissionRegistry.mission(for: today, inputs: inputs, now: at)
            if mission.id.hasPrefix("promise-") { promised += 1 } else { ordinary += 1 }
        }
        XCTAssertGreaterThan(promised, 0, "a due deal never reached the mission seat")
        XCTAssertGreaterThan(ordinary, 0, "a due deal crowded out every ordinary errand")
    }
}
