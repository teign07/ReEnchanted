import XCTest
@testable import InsideCoverCore

/// The Neighbours: things, creatures and spots in the reader's life that have
/// become somebody. The Book proposes from the reader's own Pages, the reader
/// confirms, and the register is read back out of the archive.
final class NeighboursTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2027, month: 3, day: 10, hour: 12))!
    }

    private func ago(_ days: Int, from date: Date? = nil) -> Date {
        calendar.date(byAdding: .day, value: -days, to: date ?? now)!
    }

    private func spell(_ id: String = "name-a-tree", words: String, daysAgo: Int, pageID: String = "tree-page",
                       origin: BookPageOrigin? = nil) -> BookPage {
        BookPage(id: pageID, type: .spell, createdAt: ago(daysAgo), promptText: "A spell",
                 userInput: words, tags: ["spell", "spell:\(id)"], origin: origin)
    }

    private func mission(_ id: String, words: String, daysAgo: Int, pageID: String, kind: LivedQuestKind = .playfulMission) -> BookPage {
        let at = ago(daysAgo)
        let receipt = LivedQuestReceipt(
            kind: kind, questID: id, title: "An errand", invitation: "Go on.", proofPrompt: "One sentence.",
            facets: [.exactAttention], sourceTags: [], hasWrittenProof: true, hasVisualProof: false,
            completedAt: at, wasPromptedByBook: true
        )
        return BookPage(id: pageID, type: .wonderCompass, createdAt: at, promptText: "An errand",
                        userInput: words, livedQuestReceipt: receipt)
    }

    private func diary(_ words: String, daysAgo: Int, id: String) -> BookPage {
        BookPage(id: id, type: .diary, createdAt: ago(daysAgo), promptText: "Diary", userInput: words)
    }

    private func photo(_ creature: String, daysAgo: Int, id: String) -> BookPage {
        BookPage(id: id, type: .illuminatedPhoto, createdAt: ago(daysAgo), promptText: "A photograph",
                 creatureSightings: [CreatureSighting(creature: creature, certainty: .clear)])
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        [BookDay(id: "archive", date: now, pages: pages)]
    }

    /// Confirms the first proposal and returns the archive with its record.
    private func confirm(_ pages: [BookPage], name: String? = nil, at date: Date? = nil) throws -> [BookPage] {
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        let record = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, name: name, days: days(pages), now: date ?? now))
        return pages + [record]
    }

    // MARK: Proposals by naming

    func testANamingSpellProposesTheNameTheReaderGave() throws {
        let proposal = try XCTUnwrap(Neighbours.proposals(
            days: days([spell(words: "The tree is called Gerald.", daysAgo: 2)]), calendar: calendar).first)
        XCTAssertEqual(proposal.name, "Gerald")
        XCTAssertFalse(proposal.isEpithet)
        XCTAssertEqual(proposal.kind, .place)
        XCTAssertEqual(proposal.key, "page:tree-page")
        XCTAssertEqual(proposal.quote, "The tree is called Gerald.")
        XCTAssertEqual(proposal.working, "spell:name-a-tree")
    }

    func testAReplyThatIsOnlyANameCountsEvenThoughItOpensTheSentence() throws {
        for words in ["Gerald.", "Gerald, the big ash by the gate."] {
            let proposal = try XCTUnwrap(Neighbours.proposals(
                days: days([spell(words: words, daysAgo: 2)]), calendar: calendar).first, words)
            XCTAssertEqual(proposal.name, "Gerald", words)
        }
    }

    func testASentenceOpenerIsNeverTakenForAName() throws {
        let proposal = try XCTUnwrap(Neighbours.proposals(
            days: days([spell(words: "Yesterday, by the gate.", daysAgo: 2)]), calendar: calendar).first)
        XCTAssertEqual(proposal.name, "the tree")
        XCTAssertTrue(proposal.isEpithet)
    }

    func testANamingMissionProposesFromItsReceipt() throws {
        let page = mission("faerie-name-earned", words: "I named my kettle Huffer because it huffs.", daysAgo: 1, pageID: "kettle")
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([page]), calendar: calendar).first)
        XCTAssertEqual(proposal.name, "Huffer")
        XCTAssertEqual(proposal.kind, .thing)
        XCTAssertEqual(proposal.working, "mission:faerie-name-earned")
    }

    func testTheRoomDareKeepsAWholeName() throws {
        let page = mission("room-renaming", words: "It's the Hall of Aggressive Lighting now and my sister heard it.",
                           daysAgo: 1, pageID: "room", kind: .wickerDare)
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([page]), calendar: calendar).first)
        XCTAssertEqual(proposal.name, "Hall of Aggressive Lighting")
        XCTAssertEqual(proposal.kind, .place)
    }

    func testACommonNounWearingACapitalIsNotAName() throws {
        let pages = [
            mission("faerie-name-earned", words: "I named my mug Mug.", daysAgo: 3, pageID: "mug"),
            diary("My mug is chipped and the mug is cold.", daysAgo: 1, id: "d1")
        ]
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        XCTAssertNotEqual(proposal.name, "Mug")
        XCTAssertEqual(proposal.name, "the mug")
    }

    func testCastNamesTheReadersPeopleAndTheReaderNeverBecomeNeighbours() throws {
        var inputs = BookSourceInputs.empty
        inputs.people = PeopleLedger(threads: [PersonThread(
            id: "person:amanda", name: "Amanda", introducedDay: "2027-01-01", readerWords: "",
            firstMentionDay: "2027-01-01", lastMentionDay: "2027-01-01", mentionPageCount: 4)])
        let excluded = Neighbours.excludedNames(inputs: inputs)
        XCTAssertTrue(excluded.contains("Amanda"))
        XCTAssertTrue(excluded.contains { $0.hasPrefix("Wicker") }, "the Cast is excluded")

        for name in ["Amanda", "Wicker"] {
            let proposal = try XCTUnwrap(Neighbours.proposals(
                days: days([spell(words: "The tree is called \(name).", daysAgo: 2)]),
                excludedNames: excluded, calendar: calendar).first)
            XCTAssertEqual(proposal.name, "the tree", name)
        }
    }

    func testABookAuthoredPageIsNeverProposed() {
        let page = spell(words: "The tree is called Gerald.", daysAgo: 2, origin: .generated)
        XCTAssertNil(page.readerAuthoredTextForAnalysis)
        XCTAssertTrue(Neighbours.proposals(days: days([page]), calendar: calendar).isEmpty)
    }

    func testAnOrdinaryDiaryNameIsNotANamingProposal() {
        let pages = [diary("Saw Gerald at the shop.", daysAgo: 2, id: "d1")]
        XCTAssertTrue(Neighbours.proposals(days: days(pages), calendar: calendar).isEmpty)
    }

    // MARK: Proposals by coming back

    func testAThingOnThreePagesOnThreeDaysIsProposed() throws {
        let pages = [
            diary("The kettle screamed at me.", daysAgo: 9, id: "k1"),
            diary("My kettle sulked all morning.", daysAgo: 5, id: "k2"),
            diary("I put the kettle on twice.", daysAgo: 1, id: "k3")
        ]
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        XCTAssertEqual(proposal.key, "word:kettle")
        XCTAssertEqual(proposal.name, "the kettle")
        XCTAssertEqual(proposal.foundingPageID, "k1")
        XCTAssertTrue(proposal.isEpithet)
    }

    func testTwoDaysIsNotYetComingBack() {
        let pages = [
            diary("The kettle screamed at me.", daysAgo: 5, id: "k1"),
            diary("My kettle sulked all morning.", daysAgo: 5, id: "k2"),
            diary("I put the kettle on twice.", daysAgo: 1, id: "k3")
        ]
        XCTAssertFalse(Neighbours.proposals(days: days(pages), calendar: calendar).contains { $0.key == "word:kettle" })
    }

    func testTheWeatherOfADayIsNeverSomebody() {
        let pages = (0..<4).map { diary("The coffee was cold and the rain kept on.", daysAgo: $0 * 2, id: "c\($0)") }
        let keys = Neighbours.proposals(days: days(pages), calendar: calendar).map(\.key)
        XCTAssertFalse(keys.contains("word:coffee"))
        XCTAssertFalse(keys.contains("word:rain"))
    }

    func testACreaturePhotographedOnTwoDaysIsProposed() throws {
        XCTAssertTrue(Neighbours.proposals(days: days([photo("heron", daysAgo: 3, id: "h1")]), calendar: calendar).isEmpty)
        let pages = [photo("heron", daysAgo: 3, id: "h1"), photo("heron", daysAgo: 1, id: "h2")]
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        XCTAssertEqual(proposal.key, "creature:heron")
        XCTAssertEqual(proposal.kind, .creature)
        XCTAssertEqual(proposal.name, "the heron")
    }

    func testADeclinedProposalIsNeverAskedAgain() throws {
        let pages = [spell(words: "The tree is called Gerald.", daysAgo: 2)]
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first)
        XCTAssertTrue(Neighbours.proposals(days: days(pages), declinedKeys: [proposal.observationKey], calendar: calendar).isEmpty)
    }

    // MARK: Confirming

    func testConfirmingCreatesExactlyOneNeighbourAndIsIdempotent() throws {
        let pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 2)])
        let register = Neighbours.register(days: days(pages))
        XCTAssertEqual(register.count, 1)
        let gerald = try XCTUnwrap(register.first)
        XCTAssertEqual(gerald.id, "neighbour:gerald")
        XCTAssertEqual(gerald.name, "Gerald")
        XCTAssertEqual(gerald.status, .living)
        XCTAssertEqual(gerald.foundingPageID, "tree-page")
        XCTAssertEqual(gerald.foundingSentence, "The tree is called Gerald.")
        XCTAssertEqual(gerald.foundedAt, ago(2))

        // No second proposal, and a second confirm writes nothing.
        XCTAssertTrue(Neighbours.proposals(days: days(pages), calendar: calendar).isEmpty)
        let again = NeighbourProposal(
            key: "page:tree-page", name: "Gerald", isEpithet: false, kind: .place,
            foundingPageID: "tree-page", foundedAt: ago(2), working: nil, quote: nil, deed: "",
            match: "name:Gerald", evidencePageIDs: [])
        XCTAssertNil(Neighbours.foundingRecord(for: again, days: days(pages), now: now))
    }

    func testTwoRecordsForOneProposalStillMakeOneNeighbour() throws {
        let page = spell(words: "The tree is called Gerald.", daysAgo: 2)
        let proposal = try XCTUnwrap(Neighbours.proposals(days: days([page]), calendar: calendar).first)
        let first = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days([page]), now: now))
        let second = try XCTUnwrap(Neighbours.foundingRecord(for: proposal, days: days([page]), now: now.addingTimeInterval(5)))
        XCTAssertEqual(Neighbours.register(days: days([page, first, second])).count, 1)
    }

    func testTheReaderCanCorrectTheNameWhenConfirming() throws {
        let pages = try confirm([spell(words: "Yesterday, by the gate.", daysAgo: 2)], name: "Old Grumbly")
        let neighbour = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(neighbour.name, "Old Grumbly")
        XCTAssertFalse(neighbour.isEpithet)
        XCTAssertEqual(neighbour.slug, "old-grumbly")
    }

    func testTheFoundingRecordIsTheBooksAndNotTheReaders() throws {
        let pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 2)])
        let record = try XCTUnwrap(pages.last)
        XCTAssertNil(record.readerAuthoredTextForAnalysis)
        XCTAssertTrue(record.tags.contains("neighbour:gerald"))
        XCTAssertTrue(record.tags.contains("neighbour-kind:place"))
        XCTAssertTrue(record.tags.contains("neighbour-source:tree-page"))
        XCTAssertEqual(record.metadata?["neighbourName"], "Gerald")
        XCTAssertFalse(record.userInput.contains("the Book"))
    }

    // MARK: History

    func testHistoryFindsLaterPagesByNameOnly() throws {
        var pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 20)])
        pages += [
            diary("Gerald dropped a leaf on me.", daysAgo: 4, id: "later"),
            diary("Geraldine came round.", daysAgo: 3, id: "not-him"),
            diary("A gerald of geese, if that's a word.", daysAgo: 2, id: "lowercase")
        ]
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(gerald.pageIDs, ["tree-page", "later"])
        XCTAssertEqual(gerald.lastSeen, ago(4))
    }

    func testAThingNoticedComingBackGathersEveryPageItsWordIsOn() throws {
        var pages = [
            diary("The kettle screamed at me.", daysAgo: 9, id: "k1"),
            diary("My kettle sulked all morning.", daysAgo: 5, id: "k2"),
            diary("I put the kettle on twice.", daysAgo: 3, id: "k3")
        ]
        pages = try confirm(pages)
        pages.append(diary("Two kettles in the shop window, neither as good as mine.", daysAgo: 1, id: "k4"))
        let kettle = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(kettle.pageIDs, ["k1", "k2", "k3", "k4"])
    }

    func testAThrownAwayFoundingPageTakesTheNeighbourWithIt() throws {
        let pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 2)])
        XCTAssertEqual(Neighbours.register(days: days(pages)).count, 1)
        let without = pages.filter { $0.id != "tree-page" }
        XCTAssertTrue(Neighbours.register(days: days(without)).isEmpty)
        // And the reader isn't asked about it again either: the record says
        // this one was already answered.
        XCTAssertTrue(Neighbours.proposals(days: days(without), calendar: calendar).isEmpty)
    }

    func testAThrownAwayRecordTakesTheNeighbourWithIt() throws {
        let pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 2)])
        XCTAssertTrue(Neighbours.register(days: days(Array(pages.dropLast()))).isEmpty)
    }

    func testRenameKeepsHistoryAndTheOldName() throws {
        var pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 30)], at: ago(30))
        pages.append(diary("Gerald was full of starlings.", daysAgo: 20, id: "before"))
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.renameRecord(gerald, to: "Sir Gerald", now: ago(10))))
        pages.append(diary("Sir Gerald lost a branch in the wind.", daysAgo: 5, id: "after"))
        let renamed = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(renamed.name, "Sir Gerald")
        XCTAssertEqual(renamed.formerNames, ["Gerald"])
        XCTAssertEqual(renamed.slug, "gerald", "the id is stable through a rename")
        XCTAssertEqual(renamed.pageIDs, ["tree-page", "before", "after"])
    }

    func testAnEpithetThatGetsANameStartsMatchingIt() throws {
        var pages = try confirm([spell(words: "Yesterday, by the gate.", daysAgo: 30)], at: ago(30))
        let tree = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertTrue(tree.isEpithet)
        pages.append(try XCTUnwrap(Neighbours.renameRecord(tree, to: "Gerald", now: ago(10))))
        pages.append(diary("Gerald had a crow in it.", daysAgo: 5, id: "after"))
        let gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertFalse(gerald.isEpithet)
        XCTAssertEqual(gerald.formerNames, ["the tree"])
        XCTAssertEqual(gerald.pageIDs.last, "after")
    }

    func testRestingAndGoneAreRecordsAndGoneIsKept() throws {
        var pages = try confirm([spell(words: "The tree is called Gerald.", daysAgo: 40)], at: ago(40))
        var gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        pages.append(try XCTUnwrap(Neighbours.restRecord(gerald, now: ago(20))))
        gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(gerald.status, .resting)
        XCTAssertNil(Neighbours.restRecord(gerald, now: ago(19)))
        pages.append(try XCTUnwrap(Neighbours.wakeRecord(gerald, now: ago(15))))
        gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(gerald.status, .living)
        let gone = try XCTUnwrap(Neighbours.goneRecord(gerald, now: ago(1), calendar: calendar))
        XCTAssertEqual(gone.userInput, "Gerald's gone. It was in here from January 2027 to March 2027. That's written down now.")
        pages.append(gone)
        gerald = try XCTUnwrap(Neighbours.register(days: days(pages)).first)
        XCTAssertEqual(gerald.status, .gone)
        XCTAssertEqual(gerald.statusChangedAt, ago(1))
        XCTAssertNil(Neighbours.renameRecord(gerald, to: "Ghost", now: now), "a gone Neighbour isn't renamed")
    }

    // MARK: The desk

    private func desk(_ pages: [BookPage], today: [BookPage] = [], boundaries: [String] = []) -> [SurfacePage] {
        var inputs = BookSourceInputs.empty
        inputs.days = days(pages)
        inputs.bookReadingBoundaries = boundaries.map { BookReadingBoundary(id: $0, createdAt: now) }
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: today)
        return NeighboursPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
    }

    func testTheProposalPageAsksInTheBooksVoice() throws {
        let surface = try XCTUnwrap(desk([spell(words: "The tree is called Gerald.", daysAgo: 2)]).first)
        XCTAssertEqual(surface.type, .neighbours)
        XCTAssertEqual(surface.prompt, "Shall I give Gerald a page?")
        XCTAssertTrue(surface.payload.body.hasPrefix("You told a tree its name. Gerald."))
        XCTAssertTrue(surface.payload.body.contains("\u{201C}The tree is called Gerald.\u{201D}"))
        XCTAssertFalse(surface.payload.body.contains("the Book"))
        XCTAssertFalse(surface.payload.body.contains(";"))
        XCTAssertFalse(surface.payload.body.contains("\u{2014}"))
        XCTAssertEqual(surface.payload.metadata["adaptiveActions"], "giveNeighbourAPage\nnotANeighbour")
        XCTAssertEqual(surface.payload.metadata["observationKey"], "neighbour-propose:page:tree-page")

        // The tap reads the proposal back off the Page it was on.
        let back = try XCTUnwrap(Neighbours.proposal(fromMetadata: surface.payload.metadata))
        XCTAssertEqual(back.name, "Gerald")
        XCTAssertEqual(back.foundingPageID, "tree-page")
        XCTAssertNotNil(Neighbours.foundingRecord(for: back, days: days([spell(words: "The tree is called Gerald.", daysAgo: 2)]), now: now))
    }

    func testTheDeskStopsAskingOnceTurnedAway() throws {
        let pages = [spell(words: "The tree is called Gerald.", daysAgo: 2)]
        let surface = try XCTUnwrap(desk(pages).first)
        let key = try XCTUnwrap(surface.payload.metadata["observationKey"])
        XCTAssertTrue(desk(pages, boundaries: [key]).isEmpty)
    }

    func testOneNeighbourPageADay() throws {
        let pages = [spell(words: "The tree is called Gerald.", daysAgo: 2)]
        let record = try XCTUnwrap(Neighbours.foundingRecord(
            for: try XCTUnwrap(Neighbours.proposals(days: days(pages), calendar: calendar).first),
            days: days(pages), now: now))
        XCTAssertTrue(desk(pages, today: [record]).isEmpty)
    }
}
