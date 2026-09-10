import XCTest
@testable import InsideCoverCore

/// The marks the reader leaves on the Book, and what the Book is allowed to
/// make of them.
///
/// Two rules carry most of these tests. The Book may only be moved by wear it
/// did not cause, and it may not claim a mark it could not point at.
final class ReadersWearTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    /// 2026-08-29.
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func daysAgo(_ count: Int) -> Date {
        calendar.date(byAdding: .day, value: -count, to: now) ?? now
    }

    /// A ledger with `room` opened by hand on each of the given days back.
    private func worn(_ room: BookRoom, daysAgo offsets: [Int]) -> ReaderWearLedger {
        var ledger = ReaderWearLedger()
        for offset in offsets.sorted(by: >) {
            ledger.opened(room, at: daysAgo(offset), calendar: calendar)
        }
        return ledger
    }

    private func ledger(_ entries: [(BookRoom, [Int])]) -> ReaderWearLedger {
        var ledger = ReaderWearLedger()
        for (room, offsets) in entries {
            for offset in offsets.sorted(by: >) {
                ledger.opened(room, at: daysAgo(offset), calendar: calendar)
            }
        }
        return ledger
    }

    /// A Page carrying nothing but the tag a wear notice leaves behind, which
    /// is the shape one takes once it lands back in the archive.
    private func spoken(_ tags: [String]) -> [BookDay] {
        [BookDay(
            id: "spoken",
            date: daysAgo(1),
            pages: [BookPage(
                id: "p-spoken", type: .bookNotices, createdAt: daysAgo(1),
                promptText: "", userInput: "", tags: tags,
                sourceID: ReadersWearPageSourceAdapter.sourceID
            )]
        )]
    }

    // MARK: The rule that makes the ledger worth having

    func testBeingSentSomewhereLeavesNoMark() {
        var ledger = ReaderWearLedger()
        for offset in 0..<10 {
            ledger.opened(.bookToday, arrival: .sent, at: daysAgo(offset), calendar: calendar)
        }
        XCTAssertFalse(ledger[.bookToday].isCut)
        XCTAssertEqual(ledger[.bookToday].days.count, 0)
        XCTAssertNil(ledger.fallsOpen(now: now, calendar: calendar))
        XCTAssertEqual(ledger.condition(of: .bookToday, now: now, calendar: calendar), .uncut)
    }

    func testWanderingAndBeingSentToTheSameRoomCountsOnlyTheWandering() {
        var ledger = ReaderWearLedger()
        ledger.opened(.atlas, arrival: .byHand, at: daysAgo(3), calendar: calendar)
        for offset in 0..<9 {
            ledger.opened(.atlas, arrival: .sent, at: daysAgo(offset), calendar: calendar)
        }
        XCTAssertEqual(ledger[.atlas].days.count, 1)
        XCTAssertEqual(ledger.condition(of: .atlas, now: now, calendar: calendar), .cut)
    }

    // MARK: Cutting

    func testFirstOpeningReturnsTheCutAndTheRestDoNot() {
        var ledger = ReaderWearLedger()
        let cut = ledger.opened(.gazetteer, at: daysAgo(2), calendar: calendar)
        XCTAssertEqual(cut?.room, .gazetteer)
        XCTAssertNil(ledger.opened(.gazetteer, at: daysAgo(1), calendar: calendar))
    }

    func testACutCountsWhatIsStillFoldedAfterIt() {
        var ledger = ReaderWearLedger()
        let gatherings = BookRoom.allCases.filter(\.isGathering)
        let cut = ledger.opened(gatherings[0], at: now, calendar: calendar)
        XCTAssertEqual(cut?.stillFolded, gatherings.count - 1)
        XCTAssertEqual(cut?.isTheLastOne, false)
    }

    func testTheLastFoldKnowsItIsTheLastOne() {
        var ledger = ReaderWearLedger()
        let gatherings = BookRoom.allCases.filter(\.isGathering)
        for room in gatherings.dropLast() {
            ledger.opened(room, at: daysAgo(5), calendar: calendar)
        }
        let cut = ledger.opened(gatherings.last!, at: now, calendar: calendar)
        XCTAssertEqual(cut?.stillFolded, 0)
        XCTAssertEqual(cut?.isTheLastOne, true)
    }

    /// A charm hangs on the outside where anybody can see it. Nothing about it
    /// was ever folded, so opening one is not a cut.
    func testAFittingIsNeverCutOpen() {
        var ledger = ReaderWearLedger()
        XCTAssertNil(ledger.opened(.search, at: now, calendar: calendar))
        XCTAssertTrue(ledger[.search].isCut)
    }

    // MARK: Condition

    func testTwiceInOneDayIsOneDayOfWear() {
        var ledger = ReaderWearLedger()
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: daysAgo(1))!
        let evening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: daysAgo(1))!
        ledger.opened(.bestiary, at: morning, calendar: calendar)
        ledger.opened(.bestiary, at: evening, calendar: calendar)
        XCTAssertEqual(ledger[.bestiary].days.count, 1)
    }

    func testThreeSeparateDaysIsThumbed() {
        let two = worn(.bestiary, daysAgo: [1, 3])
        XCTAssertEqual(two.condition(of: .bestiary, now: now, calendar: calendar), .cut)
        let three = worn(.bestiary, daysAgo: [1, 3, 5])
        XCTAssertEqual(three.condition(of: .bestiary, now: now, calendar: calendar), .thumbed)
    }

    func testAWornRoomLeftAloneGoesQuiet() {
        let ledger = worn(.atlas, daysAgo: [60, 70, 80])
        XCTAssertEqual(ledger.condition(of: .atlas, now: now, calendar: calendar), .quiet(days: 60))
        XCTAssertEqual(ledger.quietRooms(now: now, calendar: calendar), [.atlas])
    }

    /// A room opened twice and abandoned is not a loss. Quiet is a thing that
    /// happens to somewhere that was worn in.
    func testARoomThatWasNeverWornInDoesNotGoQuiet() {
        let ledger = worn(.atlas, daysAgo: [80, 90])
        XCTAssertEqual(ledger.condition(of: .atlas, now: now, calendar: calendar), .cut)
        XCTAssertTrue(ledger.quietRooms(now: now, calendar: calendar).isEmpty)
    }

    // MARK: Falling open

    func testTheSpineTakesTheShapeOfTheMostReadGathering() {
        let ledger = self.ledger([
            (.bestiary, [1, 2, 3, 4, 5, 6, 7]),
            (.atlas, [1, 2, 3])
        ])
        XCTAssertEqual(ledger.fallsOpen(now: now, calendar: calendar), .bestiary)
    }

    /// The lead is the whole rule. Without it the Book announces a crack in its
    /// spine over a one-visit difference, which any reader could correctly call
    /// a lie about their own hands.
    func testNoCrackWithoutAClearLead() {
        let ledger = self.ledger([
            (.bestiary, [1, 2, 3, 4, 5, 6]),
            (.atlas, [1, 2, 3, 4, 5])
        ])
        XCTAssertNil(ledger.fallsOpen(now: now, calendar: calendar))
    }

    func testABookDoesNotFallOpenAtSomewhereNobodyGoesAnyMore() {
        let ledger = worn(.atlas, daysAgo: [60, 61, 62, 63, 64, 65, 66])
        XCTAssertNil(ledger.fallsOpen(now: now, calendar: calendar))
    }

    func testACharmIsNeverWhereTheBookFallsOpen() {
        let ledger = worn(.search, daysAgo: Array(1...9))
        XCTAssertNil(ledger.fallsOpen(now: now, calendar: calendar))
    }

    // MARK: Soiling

    func testSoilingRisesWithHandlingAndThenStops() {
        XCTAssertEqual(ReaderWearLedger().soiling(of: .atlas), 0)
        let light = worn(.atlas, daysAgo: [1, 2, 3])
        let heavy = worn(.atlas, daysAgo: Array(1...12))
        let saturated = worn(.atlas, daysAgo: Array(1...40))
        XCTAssertLessThan(light.soiling(of: .atlas), heavy.soiling(of: .atlas))
        XCTAssertEqual(saturated.soiling(of: .atlas), 1)
    }

    // MARK: Merging a sealed copy

    func testMergingTwoBooksAddsTheirWearRatherThanReplacingIt() {
        let old = worn(.atlas, daysAgo: [40, 41, 42])
        let new = worn(.atlas, daysAgo: [1, 2])
        let merged = old.merging(new)
        XCTAssertEqual(merged[.atlas].days.count, 5)
        XCTAssertEqual(merged[.atlas].cutAt, old[.atlas].cutAt)
        XCTAssertEqual(merged[.atlas].lastOpenedAt, new[.atlas].lastOpenedAt)
    }

    func testMergingKeepsRoomsOnlyOneSideKnowsAbout() {
        let merged = worn(.atlas, daysAgo: [3]).merging(worn(.bestiary, daysAgo: [3]))
        XCTAssertTrue(merged[.atlas].isCut)
        XCTAssertTrue(merged[.bestiary].isCut)
    }

    func testTheLedgerSurvivesARoundTrip() throws {
        let original = ledger([(.atlas, [1, 4, 9]), (.search, [2])])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ReaderWearLedger.self, from: data), original)
    }

    /// A room retired tomorrow must not take four years of thumbprints with it.
    func testAnUnknownRoomInTheFileDoesNotBreakTheDecode() throws {
        let json = #"{"rooms":{"a-room-that-was-removed":{"days":{"wordOffset":0,"words":"AQ=="}}}}"#
        XCTAssertNoThrow(try JSONDecoder().decode(ReaderWearLedger.self, from: Data(json.utf8)))
    }

    // MARK: What the Book says

    func testABookNobodyHasWanderedInSaysNothing() {
        XCTAssertNil(ReadersWearNoticing.notice(
            ledger: ReaderWearLedger(), days: [], now: now, calendar: calendar
        ))
    }

    func testAFreshCutIsTheFirstThingItMentions() {
        let ledger = worn(.gazetteer, daysAgo: [1])
        let notice = ReadersWearNoticing.notice(ledger: ledger, days: [], now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .cutOpen)
        XCTAssertEqual(notice?.room, .gazetteer)
        XCTAssertEqual(notice?.restTag, "wear-cut:gazetteer")
    }

    func testAnOldCutIsNoLongerNews() {
        let ledger = worn(.gazetteer, daysAgo: [30])
        let notice = ReadersWearNoticing.notice(ledger: ledger, days: [], now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .cutOpen)
    }

    func testTheBookNeverSaysTheSameThingTwice() {
        let ledger = worn(.gazetteer, daysAgo: [1])
        let notice = ReadersWearNoticing.notice(
            ledger: ledger, days: spoken(["wear-cut:gazetteer"]), now: now, calendar: calendar
        )
        XCTAssertNotEqual(notice?.kind, .cutOpen)
    }

    func testWalkingBackIntoAQuietRoomIsWorthSaying() {
        let ledger = worn(.atlas, daysAgo: [1, 70, 80, 90])
        let notice = ReadersWearNoticing.notice(ledger: ledger, days: [], now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .returned)
        XCTAssertEqual(notice?.room, .atlas)
    }

    func testEveryGatheringOpenedIsSaidOnce() {
        var ledger = ReaderWearLedger()
        for room in BookRoom.allCases.filter(\.isGathering) {
            ledger.opened(room, at: daysAgo(20), calendar: calendar)
        }
        let notice = ReadersWearNoticing.notice(ledger: ledger, days: [], now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .allCut)
        XCTAssertNil(ReadersWearNoticing.notice(
            ledger: ledger, days: spoken(["wear-allCut"]), now: now, calendar: calendar
        ))
    }

    func testTheDareCountsTheFoldedOnesAndNamesNoneOfThem() {
        var ledger = ReaderWearLedger()
        let gatherings = BookRoom.allCases.filter(\.isGathering)
        for room in gatherings.dropLast(2) {
            ledger.opened(room, at: daysAgo(20), calendar: calendar)
        }
        // The named invitation goes first and has to be spoken already before
        // the withheld one is reachable.
        let said = gatherings.suffix(2).map { "wear-invitation:\($0.rawValue)" }
        let notice = ReadersWearNoticing.notice(
            ledger: ledger, days: spoken(said), now: now, calendar: calendar
        )
        XCTAssertEqual(notice?.kind, .theUncut)
        XCTAssertNil(notice?.room)
        for room in gatherings.suffix(2) {
            XCTAssertFalse(notice!.body.contains(room.plainName))
            XCTAssertFalse(notice!.headline.contains(room.plainName))
        }
    }

    /// The dare keys on the number still folded, so cutting one open makes the
    /// same sentence sayable again with a smaller number in it. That is the
    /// only repetition in here that is the point rather than a failure.
    func testTheDareComesBackWithASmallerNumber() {
        var ledger = ReaderWearLedger()
        let gatherings = BookRoom.allCases.filter(\.isGathering)
        for room in gatherings.dropLast(3) {
            ledger.opened(room, at: daysAgo(20), calendar: calendar)
        }
        var said = gatherings.suffix(3).map { "wear-invitation:\($0.rawValue)" }
        said.append("wear-uncut:3")
        XCTAssertNil(ReadersWearNoticing.notice(
            ledger: ledger, days: spoken(said), now: now, calendar: calendar
        ))
        ledger.opened(gatherings[gatherings.count - 3], at: daysAgo(20), calendar: calendar)
        let again = ReadersWearNoticing.notice(
            ledger: ledger, days: spoken(said), now: now, calendar: calendar
        )
        XCTAssertEqual(again?.kind, .theUncut)
        XCTAssertEqual(again?.restTag, "wear-uncut:2")
    }

    /// A stranger who has not yet learned that a gathering opens must not be
    /// told off for leaving them shut.
    func testTheBookDoesNotDareAReaderWhoHasNotLearnedTheGesture() {
        let ledger = worn(.atlas, daysAgo: [20])
        let notice = ReadersWearNoticing.notice(ledger: ledger, days: [], now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .theUncut)
        XCTAssertNotEqual(notice?.kind, .invitation)
    }

    func testTheInvitationNamesOneRoomAndSaysWhatIsInIt() {
        var ledger = ReaderWearLedger()
        for room in [BookRoom.atlas, .gazetteer, .cast, .bestiary] {
            ledger.opened(room, at: daysAgo(20), calendar: calendar)
        }
        let notice = ReadersWearNoticing.notice(ledger: ledger, days: [], now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .invitation)
        let room = try? XCTUnwrap(notice?.room)
        XCTAssertEqual(room.map { ledger[$0].isCut }, false)
        XCTAssertTrue(notice!.headline.contains(room!.plainName))
    }

    // MARK: The frequency

    func testTheFrequencyGoesOnlyToAReaderWhoWentLooking() {
        let idle = ledger([(.atlas, [1, 2])])
        XCTAssertFalse(idle.isMarginWalker(now: now, calendar: calendar))

        let walker = ledger([
            (.atlas, [1, 2, 3]), (.gazetteer, [4, 5, 6]), (.bestiary, [7, 8, 9]),
            (.cast, [10]), (.correspondences, [11]), (.colophon, [12]),
            (.returned, [13]), (.pagesIndex, [14])
        ])
        XCTAssertTrue(walker.isMarginWalker(now: now, calendar: calendar))
    }

    func testTheFrequencyIsHandedOverOnceAndCarriesTheRealDialStep() throws {
        let walker = ledger([
            (.atlas, [1, 2, 3]), (.gazetteer, [4, 5, 6]), (.bestiary, [7, 8, 9]),
            (.cast, [10]), (.correspondences, [11]), (.colophon, [12]),
            (.returned, [13]), (.pagesIndex, [14])
        ])
        // The fresh cut and the return both outrank it, so they are said first.
        let said = BookRoom.allCases.map { "wear-cut:\($0.rawValue)" }
        let notice = try XCTUnwrap(ReadersWearNoticing.notice(
            ledger: walker, days: spoken(said), now: now, calendar: calendar
        ))
        XCTAssertEqual(notice.kind, .frequency)
        let station = try XCTUnwrap(RadioStationRegistry.rumouredStation)
        XCTAssertTrue(notice.headline.contains(station.displayFrequency))
        // The Book still has other things to say; it just never says this one
        // again.
        XCTAssertNotEqual(
            ReadersWearNoticing.notice(
                ledger: walker, days: spoken(said + ["wear-frequency"]),
                now: now, calendar: calendar
            )?.kind,
            .frequency
        )
    }

    /// The whole reward is knowing where to point the dial, so the number the
    /// Book gives out has to be the number the receiver actually locks on.
    func testTheRumouredNumberIsTheOneThatLocks() throws {
        let station = try XCTUnwrap(RadioStationRegistry.rumouredStation)
        XCTAssertEqual(station.rule, .hiddenFrequency)
        XCTAssertEqual(
            RadioStationRegistry.tunedStation(to: station.frequency)?.id,
            station.id
        )
        XCTAssertFalse(RadioStationRegistry.stations().contains { $0.id == station.id })
    }

    func testAnUnknownUnlockRuleReadsAsAnOrdinaryStation() {
        let stations = RadioStationRegistry.stations()
        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations.allSatisfy { $0.rule != .hiddenFrequency })
    }

    /// The number is the whole reward and a number is easy to lose, so the
    /// receiver keeps the mark once the Book has passed it on — and never
    /// before, or the scratch would be pointing at a station nobody has been
    /// told about.
    func testTheDialIsUnmarkedUntilTheBookHasGivenOutTheNumber() throws {
        let adapter = RadioPageSourceAdapter()
        let day = BookDay(id: "today", date: now, pages: [])
        var inputs = BookSourceInputs()

        let before = adapter.manualSurface(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
        XCTAssertNil(before.payload.metadata["radioScratchedFrequency"])

        inputs.days = spoken(["wear-frequency"])
        let after = adapter.manualSurface(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
        let station = try XCTUnwrap(RadioStationRegistry.rumouredStation)
        XCTAssertEqual(after.payload.metadata["radioScratchedFrequency"], station.displayFrequency)
    }

    // MARK: The Page

    func testThePageCarriesItsRestTagAndItsShutDoor() {
        let ledger = worn(.gazetteer, daysAgo: [1])
        var inputs = BookSourceInputs()
        inputs.readerWear = ledger
        let day = BookDay(id: "today", date: now, pages: [])
        let pages = ReadersWearPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
        let page = pages.first
        XCTAssertEqual(page?.type, .bookNotices)
        XCTAssertEqual(page?.sourceID, ReadersWearPageSourceAdapter.sourceID)
        XCTAssertEqual(page?.payload.metadata["observationKey"], "wear:wear-cut:gazetteer")
        XCTAssertEqual(page?.payload.metadata["wearRoom"], "gazetteer")
        XCTAssertTrue(page?.payload.metadata["tags"]?.contains("wear-cut:gazetteer") == true)
    }

    func testAShutBoundaryStopsTheSameNoticeComingBack() {
        var inputs = BookSourceInputs()
        inputs.readerWear = worn(.gazetteer, daysAgo: [1])
        inputs.bookReadingBoundaries = [
            BookReadingBoundary(id: "wear:wear-cut:gazetteer", createdAt: now)
        ]
        let day = BookDay(id: "today", date: now, pages: [])
        XCTAssertTrue(ReadersWearPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ).isEmpty)
    }

    /// A Page about where the reader has been walking is a Page about the Book,
    /// so it has to take a self-talk slot rather than sneaking past the ration.
    func testTheWearSpeaksOfTheBookItself() {
        XCTAssertTrue(BookPageType.bookNotices.speaksOfItself)
    }

    func testTheSourceIsRegisteredUnderItsOwnID() {
        let source = BookPageSourceRegistry.source(
            id: ReadersWearPageSourceAdapter.sourceID, fallbackType: .bookNotices
        )
        XCTAssertEqual(source.id, ReadersWearPageSourceAdapter.sourceID)
        XCTAssertEqual(source.type, .bookNotices)
    }

    // MARK: Voice

    /// Every line the Book can say about its own paper, run past the pencil
    /// that catches assistant register, declared moods, and absence framed as
    /// the reader's fault.
    func testEveryWearNoticeSurvivesTheCharacterLint() {
        var findings: [BookCharacterLintFinding] = []
        for surface in everyWearSurface() {
            findings += BookCharacterLint.inspect(surface)
        }
        XCTAssertTrue(
            findings.filter { $0.severity == .error }.isEmpty,
            BookCharacterLint.report(everyWearSurface())
        )
    }

    /// A worn room going still is a fact about the room. Saying it in a way the
    /// reader could hear as a charge would make the one Page about their own
    /// curiosity the one Page that tells them off for running out of it.
    func testTheQuietNoticeNeverBillsTheReaderForTheSilence() throws {
        let ledger = worn(.atlas, daysAgo: [60, 70, 80])
        // The return outranks it, so the archive has to have heard that first.
        let notice = try XCTUnwrap(ReadersWearNoticing.notice(
            ledger: ledger, days: spoken(["wear-returned:atlas"]), now: now, calendar: calendar
        ))
        XCTAssertEqual(notice.kind, .goneQuiet)
        let text = [notice.headline, notice.detail, notice.body].joined(separator: " ").lowercased()
        for charge in ["you haven't", "you have not", "where have you been", "you stopped", "you left"] {
            XCTAssertFalse(text.contains(charge), charge)
        }
    }

    /// Every room the Book might name has to be nameable in a sentence and have
    /// something to say for itself, or the invitation reaches the reader with a
    /// hole in the middle of it.
    func testEveryRoomCanBeSpokenAbout() {
        for room in BookRoom.allCases {
            XCTAssertFalse(room.plainName.isEmpty, room.rawValue)
            XCTAssertFalse(room.lure.isEmpty, room.rawValue)
            // It has to drop into the middle of a sentence, so it starts
            // lowercase and `GrimoireVoice.opening` lifts it when it leads.
            XCTAssertEqual(room.plainName.first?.isLowercase, true, room.rawValue)
        }
    }

    /// One surface per notice kind, built from a ledger shaped to produce it.
    private func everyWearSurface() -> [SurfacePage] {
        let adapter = ReadersWearPageSourceAdapter()
        let day = BookDay(id: "today", date: now, pages: [])
        let context = CuratorContext.make(for: day)
        var surfaces: [SurfacePage] = []
        var said: [String] = []

        // Walk the whole ladder: take whatever the Book says, record it as
        // said, and ask again, until it runs out of things to say.
        var ledger = ledger([
            (.atlas, [1, 2, 3]), (.gazetteer, [4, 5, 6]), (.bestiary, [7, 8, 9]),
            (.cast, [10]), (.correspondences, [11]), (.colophon, [12]),
            (.returned, [13]), (.pagesIndex, [14])
        ])
        ledger.opened(.atlas, at: daysAgo(70), calendar: calendar)
        ledger.opened(.bestiary, at: daysAgo(10), calendar: calendar)
        ledger.opened(.bestiary, at: daysAgo(11), calendar: calendar)
        ledger.opened(.bestiary, at: daysAgo(12), calendar: calendar)

        for _ in 0..<24 {
            var inputs = BookSourceInputs()
            inputs.readerWear = ledger
            inputs.days = spoken(said)
            guard let surface = adapter.candidates(
                for: day, context: context, inputs: inputs, now: now
            ).first else { break }
            surfaces.append(surface)
            said.append(contentsOf: surface.payload.metadata["tags"]?
                .split(separator: ",").map(String.init) ?? [])
        }

        // And the two the ladder above cannot reach: every fold cut, and a
        // worn room that has gone still without a return under it.
        var everything = ReaderWearLedger()
        for room in BookRoom.allCases.filter(\.isGathering) {
            everything.opened(room, at: daysAgo(20), calendar: calendar)
        }
        var quiet = worn(.atlas, daysAgo: [60, 70, 80])
        quiet.opened(.gazetteer, at: daysAgo(2), calendar: calendar)
        for extra in [everything, quiet] {
            var inputs = BookSourceInputs()
            inputs.readerWear = extra
            inputs.days = spoken(["wear-returned:atlas"])
            surfaces += adapter.candidates(for: day, context: context, inputs: inputs, now: now)
        }
        return surfaces
    }
}
