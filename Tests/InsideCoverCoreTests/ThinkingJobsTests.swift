import XCTest
@testable import InsideCoverCore

/// The second batch of thinking jobs (docs/noticing-and-writing-sessions-plan.md
/// §12): sealed predictions the world opens, joined findings that may only use
/// numbers they were given, and the Book's journal.
final class ThinkingJobsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_900_000)

    private func page(_ id: String, daysAgo: Double, weather: String, heart: Int) -> BookPage {
        let at = now.addingTimeInterval(-daysAgo * 86_400)
        return BookPage(
            id: id, type: .diary, createdAt: at, promptText: "",
            userInput: "Walked past the bakery and the gulls were loud about something.", origin: .userAuthored,
            context: BookPageContextSnapshot(at: at, weatherTags: [weather], restingHeartRate: heart)
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { Calendar.current.startOfDay(for: $0.createdAt) }
            .map { BookDay(id: BookDay.id(for: $0.key), date: $0.key, pages: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private var rainHeart: Noticing {
        Noticing(
            id: "crossing-weather-rain-restingHeart", kind: .crossing,
            headline: "Rain and Your Heart",
            line: "On rain days, your heart goes slower. I counted. Five of six rain days went that way.",
            counted: "Rain days: 57 beats a minute. Other days: 64 beats a minute.",
            falsifier: nil, errand: nil, receipts: [], sources: [.weather, .body], rank: 100,
            test: Noticing.Test(categoryID: "weather", value: "rain", numberID: "restingHeart", rises: false, threshold: 61)
        )
    }

    // MARK: Crossing wagers, in the one wager ledger

    func testAKeptNoticingSealsAWagerInTheExistingLedger() throws {
        let wager = try XCTUnwrap(CrossingWagers.wager(from: rainHeart, existing: [], now: now))
        XCTAssertEqual(wager.prediction, "The next three rain days: your heart goes slower, under 61 beats a minute.")
        XCTAssertEqual(wager.subjectName, "rain days and your heart")
        XCTAssertEqual(wager.basisLine, rainHeart.line)
        XCTAssertTrue(wager.isSealed)
        XCTAssertNotNil(wager.test)

        // Same limits as every other sealed margin.
        let full = (0..<SealedMarginEngine.maximumSealed).map { index -> BookWager in
            var other = wager
            other.id = "other-\(index)"
            other.subjectID = "other-\(index)"
            return other
        }
        XCTAssertNil(CrossingWagers.wager(from: rainHeart, existing: full, now: now), "the margin only holds so many")
        XCTAssertNil(CrossingWagers.wager(from: rainHeart, existing: [wager], now: now), "one bet per subject at a time")
    }

    func testTheEngineGradesACrossingWagerOnItsTestingDays() throws {
        let wager = try XCTUnwrap(CrossingWagers.wager(from: rainHeart, existing: [], now: now.addingTimeInterval(-10 * 86_400)))
        let before = [page("old-rain", daysAgo: 12, weather: "rain", heart: 80)]
        XCTAssertTrue(SealedMarginEngine.resolved([wager], against: days(before), now: now)[0].isSealed,
                      "days before the seal don't count, and the deadline isn't here yet")

        let right = before + [
            page("r1", daysAgo: 8, weather: "rain", heart: 58),
            page("dry", daysAgo: 7, weather: "bright", heart: 50),
            page("r2", daysAgo: 5, weather: "rain", heart: 66),
            page("r3", daysAgo: 2, weather: "rain", heart: 59)
        ]
        let opened = SealedMarginEngine.resolved([wager], against: days(right), now: now)[0]
        XCTAssertEqual(opened.status, .right, "graded early: it doesn't wait for opensAt")
        XCTAssertEqual(opened.resolutionLine,
                       "The next three rain days: 58 beats a minute, 66 beats a minute and 59 beats a minute. Two of three went the way I said.")

        let wrong = before + [
            page("w1", daysAgo: 8, weather: "rain", heart: 70),
            page("w2", daysAgo: 5, weather: "rain", heart: 60),
            page("w3", daysAgo: 2, weather: "rain", heart: 68)
        ]
        let broken = SealedMarginEngine.resolved([wager], against: days(wrong), now: now)[0]
        XCTAssertEqual(broken.status, .wrong)
        XCTAssertTrue(broken.resolutionLine?.hasSuffix("I'm leaving the seal broken where you can see it.") == true)
    }

    func testAnUntestedCrossingWagerOpensAtItsDeadline() throws {
        let wager = try XCTUnwrap(CrossingWagers.wager(from: rainHeart, existing: [], now: now.addingTimeInterval(-61 * 86_400)))
        let dry = (1...20).map { page("dry\($0)", daysAgo: Double($0), weather: "bright", heart: 60) }
        let opened = SealedMarginEngine.resolved([wager], against: days(dry), now: now)[0]
        XCTAssertEqual(opened.status, .wrong)
        XCTAssertEqual(opened.resolutionLine,
                       "There weren't three rain days before the seal's date, so nothing tested it. A bet the world never tests is one I lose.")
    }

    func testOlderWagersStillOpenAndStillGradeByTheirWord() throws {
        let old = #"{"id":"w","subjectID":"harbor","subjectName":"Harbor","kind":"pattern","prediction":"Harbor will return.","sealedAt":0,"opensAt":0,"status":"sealed","basisSignalID":"s","basisLine":"Harbor kept returning."}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let wager = try decoder.decode(BookWager.self, from: Data(old.utf8))
        XCTAssertNil(wager.test)
        XCTAssertNotEqual(SealedMarginEngine.resolved([wager], against: [], now: now)[0].status, .sealed)
    }

    // MARK: Joined findings

    func testAJoinedFindingMayOnlyUseNumbersItWasGiven() {
        let shorter = Noticing(
            id: "crossing-weather-rain-words", kind: .crossing, headline: "Rain and Your Words",
            line: "On rain days, your pages come out shorter. I counted.",
            counted: "Rain days: 40 words. Other days: 95 words.",
            falsifier: nil, errand: nil, receipts: [], sources: [.weather, .writing], rank: 90,
            test: Noticing.Test(categoryID: "weather", value: "rain", numberID: "words", rises: false, threshold: 90)
        )
        let honest = "When it rains your heart goes slow and your pages go short. Fifty-seven beats, forty words. It's like the whole of you is listening to the roof."
        XCTAssertNotNil(JoinedFindings.accept(honest, evidence: [rainHeart, shorter]))
        let invented = "When it rains your heart drops to 52 and your pages go short. It's like you're listening to the roof."
        XCTAssertNil(JoinedFindings.accept(invented, evidence: [rainHeart, shorter]), "52 was never counted")
        let spelledInvention = "When it rains your heart drops to fifty-two and your pages go short. You listen to the roof."
        XCTAssertNil(JoinedFindings.accept(spelledInvention, evidence: [rainHeart, shorter]), "not in words either")
        XCTAssertNil(JoinedFindings.accept("You should rest more when it rains, the Book thinks.", evidence: [rainHeart]))

        let surface = JoinedFindings.surface(text: honest, noticings: [rainHeart, shorter], key: "weather|rain")
        XCTAssertEqual(surface.payload.headline, "I've Been Thinking About Rain Days")
        let tags = surface.payload.metadata["tags"] ?? ""
        XCTAssertTrue(tags.contains("crossing-spoke:crossing-weather-rain-restingHeart"), "its parts retire with it")
        XCTAssertTrue(tags.contains("crossing-spoke:crossing-weather-rain-words"))
        XCTAssertTrue(tags.contains("private-body"))
    }

    func testOnlyKeptNoticingsAboutOneConditionAreJoined() {
        var other = rainHeart
        other.id = "crossing-weather-rain-words"
        var lonely = rainHeart
        lonely.id = "crossing-weekday-Thursday-sleep"
        lonely.test = Noticing.Test(categoryID: "weekday", value: "Thursday", numberID: "sleep", rises: false, threshold: 7)
        let keep = NoticingVerdict(keep: true, reason: "ok", judgedAt: now)
        let groups = JoinedFindings.groups(
            [rainHeart, other, lonely],
            verdicts: [rainHeart.id: keep, other.id: keep, lonely.id: keep],
            spoken: []
        )
        XCTAssertEqual(groups.map(\.key), ["weather|rain"])
        XCTAssertTrue(JoinedFindings.groups([rainHeart, other], verdicts: [rainHeart.id: keep], spoken: []).isEmpty,
                      "an unjudged noticing isn't joined")
    }

    // MARK: The journal

    func testTheJournalKeepsToWhatHappened() {
        let log = ["Decided not to tell the reader this, because it was obvious.", "Reread something folded for the reader. It still fits."]
        XCTAssertNotNil(BookJournal.accept("I nearly said something obvious and didn't. Then I reread a thing I folded. It held.", session: log))
        XCTAssertNil(BookJournal.accept("Dear diary, I judged 14 things today.", session: log))
        XCTAssertNil(BookJournal.accept("The Book worked hard today and is proud of it.", session: log))
    }

    func testTheJournalTurnsUpOnceThreeEntriesAreUnreadAndThenRests() throws {
        let entries = (0..<4).map { BookJournalEntry(id: "e\($0)", writtenAt: now.addingTimeInterval(Double($0 - 4) * 86_400), text: "Entry \($0).") }
        XCTAssertNil(BookJournal.surface(Array(entries.prefix(2)), days: [], now: now), "two isn't enough")
        let shown = try XCTUnwrap(BookJournal.surface(entries, days: [], now: now))
        XCTAssertEqual(shown.payload.headline, "From My Journal")
        XCTAssertTrue(shown.payload.body.contains("Entry 3."))

        var kept = BookPage(id: "journal", type: .bookNotices, createdAt: now.addingTimeInterval(-86_400), promptText: "")
        kept.tags = (shown.payload.metadata["tags"] ?? "").split(separator: ",").map(String.init)
        let more = entries + (4..<7).map { BookJournalEntry(id: "e\($0)", writtenAt: now.addingTimeInterval(Double($0) * 3_600), text: "Entry \($0).") }
        XCTAssertNil(BookJournal.surface(more, days: days([kept]), now: now), "a week's rest after showing")
        let nextWeek = now.addingTimeInterval(8 * 86_400)
        let next = try XCTUnwrap(BookJournal.surface(more, days: days([kept]), now: nextWeek))
        XCTAssertFalse(next.payload.body.contains("Entry 3."), "only what's unread")
        XCTAssertTrue(next.payload.body.contains("Entry 6."))
    }

    func testADeskWithoutTheseFieldsStillOpens() throws {
        let desk = try JSONDecoder().decode(WritingDesk.self, from: Data(#"{"wants":[],"drawer":[]}"#.utf8))
        XCTAssertNil(desk.journal)
    }

    // MARK: Dreams and wonderings

    private func written(_ id: String, hoursAgo: Double, _ text: String) -> BookPage {
        BookPage(id: id, type: .souvenir, createdAt: now.addingTimeInterval(-hoursAgo * 3_600),
                 promptText: "", userInput: text, origin: .userAuthored)
    }

    private var recentPages: [BookPage] {
        [
            written("kettle", hoursAgo: 5, "The kettle clicked off before it boiled and the whole kitchen went quiet."),
            written("gulls", hoursAgo: 20, "Gulls on the harbor wall fighting over a paper bag of chips."),
            written("umbrella", hoursAgo: 30, "Found an umbrella blown inside out in the hedge by the bus stop.")
        ]
    }

    func testADreamMustBeMadeOfTheReadersOwnThings() {
        let material = ThinkingMaterials.recent(days: days(recentPages), now: now)
        XCTAssertEqual(material.map(\.pageID), ["kettle", "gulls", "umbrella"])

        let theirs = "I was a kitchen and the kettle would not stop clicking. Gulls came in through the window carrying an umbrella like a boat. Nobody boiled anything. I didn't mind."
        XCTAssertNotNil(BookDreams.accept(theirs, material: material))
        let anyone = "I was flying over a city of glass and everything was singing. The sky turned to silk and I woke up happy."
        XCTAssertNil(BookDreams.accept(anyone, material: material), "a dream about none of their things isn't theirs")
        XCTAssertNil(BookDreams.accept(theirs + " It symbolizes your need for quiet.", material: material), "never explained")
        XCTAssertNil(BookDreams.accept("I dreamed of 3 kettles and gulls, and an umbrella the size of the harbor, all clicking.", material: material),
                     "no numbers in a dream")

        let surface = BookDreams.surface(theirs, material: material)
        XCTAssertEqual(surface.payload.headline, "I Had a Dream")
        XCTAssertTrue(surface.payload.metadata["tinyPatternCards"]?.contains("What it was made of") == true)
    }

    func testAWonderingIsOneRealQuestionAboutOneRealThing() throws {
        let material = ThinkingMaterials.recent(days: days(recentPages), now: now)
        let asked = try XCTUnwrap(BookWonderings.accept("Did the umbrella want to be found, or was it hiding in that hedge?", material: material))
        XCTAssertEqual(asked.about.pageID, "umbrella")
        XCTAssertNil(BookWonderings.accept("How did that make you feel?", material: material), "not a therapist")
        XCTAssertNil(BookWonderings.accept("What is the meaning of life?", material: material), "about something actually there")
        XCTAssertNil(BookWonderings.accept("The umbrella was in the hedge.", material: material), "a question")

        let surface = BookWonderings.surface(question: asked.question, about: asked.about)
        XCTAssertEqual(surface.payload.headline, "I've Been Wondering")
        XCTAssertEqual(surface.payload.metadata["evidencePageIDs"], "umbrella")
    }

    func testTheBookWantsToDreamAndWonderOnlyWithFreshPagesAndRest() {
        let desk = WritingDeskPlanner.refreshed(WritingDesk(), days: days(recentPages), now: now)
        XCTAssertTrue(desk.wants.contains { $0.kind == .dream })
        XCTAssertTrue(desk.wants.contains { $0.kind == .wondering })
        XCTAssertEqual(WritingDeskPlanner.refreshed(desk, days: days(recentPages), now: now).wants.filter { $0.kind == .dream }.count, 1,
                       "one dream at a time")
        let thin = WritingDeskPlanner.refreshed(WritingDesk(), days: days([recentPages[0]]), now: now)
        XCTAssertFalse(thin.wants.contains { $0.kind == .dream }, "a dream needs three fresh pages")
    }
}
