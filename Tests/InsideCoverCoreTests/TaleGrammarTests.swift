import XCTest
@testable import InsideCoverCore

/// The Tale Grammar's one hard rule is that it invents nothing: every beat must
/// point at a receipt that already exists. Its second rule is that it would
/// rather say nothing than tell the reader what their life meant. Most of these
/// are about the silence.
final class TaleGrammarTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start)!
    }

    private func page(_ offset: Int, type: BookPageType, tags: [String], text: String) -> BookPage {
        BookPage(
            id: "page-\(offset)-\(type.rawValue)",
            type: type,
            createdAt: day(offset),
            promptText: "p",
            userInput: text,
            tags: tags,
            origin: .userAuthored
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .map { BookDay(id: $0.key, date: $0.value[0].createdAt, pages: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func mark(_ offset: Int, id: String, kind: String, line: String, tags: [String] = []) -> TaleSignals.Mark {
        TaleSignals.Mark(id: id, kind: kind, line: line, at: day(offset), tags: tags)
    }

    // MARK: Inventing nothing

    func testEveryWitnessPointsAtARealReceipt() {
        let pages = [
            page(0, type: .mood, tags: ["hard"], text: "Everything the same again."),
            page(2, type: .faeBargain, tags: ["fae", "bargain"], text: "I took the gift.")
        ]
        var signals = TaleSignals.none
        signals.faeMarks = [mark(4, id: "bargain-1", kind: "fae-lapsed", line: "The gift went cold.", tags: ["fae"])]

        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), signals: signals, now: day(6))
        XCTAssertFalse(witnesses.isEmpty)
        let receiptIDs = Set(witnesses.map(\.receiptID))
        let realIDs = Set(pages.map(\.id) + ["bargain-1"])
        XCTAssertTrue(receiptIDs.isSubset(of: realIDs),
                      "A witness pointed at something that does not exist: \(receiptIDs.subtracting(realIDs))")
    }

    func testOneReceiptWitnessesOnlyOneBeat() {
        let pages = [page(0, type: .mood, tags: ["hard", "boundary"], text: "A line I said I wouldn't cross.")]
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(1))
        XCTAssertEqual(witnesses.filter { $0.receiptID == pages[0].id }.count, 1)
    }

    func testTheReadersOwnWordsAreCarriedVerbatim() {
        let line = "The kettle was still warm when I got back."
        let pages = [page(0, type: .mood, tags: ["hard"], text: line)]
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(1))
        XCTAssertEqual(witnesses.first?.evidence, line)
        XCTAssertTrue(witnesses.first?.isReaderAuthored == true)
    }

    // MARK: The silence

    func testThinEvidenceNamesNoTale() {
        let pages = [page(0, type: .mood, tags: ["hard"], text: "A hard day.")]
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(1))
        XCTAssertNil(TaleGrammar.recognize(witnesses: witnesses, now: day(1), calendar: calendar))
    }

    func testOneIntenseAfternoonIsASceneNotATale() {
        // Four beats, all on the same day.
        let pages = [
            page(0, type: .mood, tags: ["hard"], text: "Everything grey again today honestly."),
            page(0, type: .faeBargain, tags: ["fae", "bargain"], text: "I accepted the offered gift."),
            page(0, type: .letter, tags: ["stranger"], text: "A letter came from nobody I know."),
            page(0, type: .wonderCompass, tags: ["boundary"], text: "I went past the fence on purpose.")
        ]
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(1))
        XCTAssertNil(
            TaleGrammar.recognize(witnesses: witnesses, now: day(1), calendar: calendar),
            "Four beats in one afternoon should not be a tale"
        )
    }

    /// Pages spread over days that share no thing are not a tale, however
    /// they might be framed.
    func testUnrelatedPagesAreNotATale() {
        let pages = [
            page(0, type: .diary, tags: [], text: "Rain all afternoon on the roof."),
            page(2, type: .diary, tags: [], text: "The bus was late again."),
            page(4, type: .diary, tags: [], text: "Found a feather on the step."),
            page(6, type: .diary, tags: [], text: "Soup for dinner, too much salt."),
            page(8, type: .diary, tags: [], text: "A dog barked at the postman.")
        ]
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(9))
        XCTAssertNil(TaleGrammar.recognize(witnesses: witnesses, now: day(9), calendar: calendar))
    }

    // MARK: Threads
    //
    // A tale is one thing followed through the reader's own pages: a
    // beginning, a middle and an end that are about the same kettle.

    private func kettlePages() -> [BookPage] {
        [
            page(0, type: .diary, tags: [], text: "The kettle was still warm when I got back."),
            page(1, type: .diary, tags: [], text: "Rain all afternoon on the roof."),
            page(3, type: .souvenir, tags: [], text: "Burnt my thumb on the kettle, like an idiot, and laughed about it all the way to the bus."),
            page(5, type: .diary, tags: [], text: "The bus was late again."),
            page(7, type: .diary, tags: [], text: "Made tea in the kettle nobody else likes.")
        ]
    }

    private func kettleWitnesses(extra: [BookPage] = [], now offset: Int = 8) -> [TaleWitness] {
        TaleGrammar.witnesses(events: [], days: days(kettlePages() + extra), now: day(offset))
    }

    func testThreePagesAboutTheSameThingAreATale() {
        let recognized = TaleGrammar.recognize(witnesses: kettleWitnesses(), now: day(8), calendar: calendar)
        XCTAssertEqual(recognized?.thread?.id, "word:kettle")
        XCTAssertEqual(recognized?.thread?.title, "The Tale of the Kettle")
        XCTAssertEqual(recognized?.witnesses.count, 3, "only the pages about the kettle are in its tale")
    }

    func testRecognitionIsStableForTheSameEvidence() {
        let first = TaleGrammar.recognize(witnesses: kettleWitnesses(), now: day(8), calendar: calendar)
        let second = TaleGrammar.recognize(witnesses: kettleWitnesses(), now: day(8), calendar: calendar)
        XCTAssertEqual(first, second, "The same evidence named two different tales")
    }

    /// A place the reader anchored is a thread, called by the reader's own name.
    func testAPlaceTheReaderAnchoredIsAThread() {
        let texts = ["Sat and watched the ducks.", "Cold, but I stayed an hour.", "A heron, finally."]
        let pages = texts.enumerated().map { index, text in
            BookPage(
                id: "bench-\(index)", type: .diary, createdAt: day(index * 3), promptText: "p",
                userInput: text, tags: [], origin: .userAuthored,
                context: BookPageContextSnapshot(at: day(index * 3), calendar: calendar, nearbyAnchorID: "a1")
            )
        }
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(8))
        let named = TaleGrammar.recognize(
            witnesses: witnesses, names: ["anchor:a1": "Riverside Bench"], now: day(8), calendar: calendar
        )
        XCTAssertEqual(named?.thread?.kind, .place)
        XCTAssertEqual(named?.thread?.title, "The Tale of Riverside Bench")
        // A place the reader never named is not something the Book can call it.
        XCTAssertNil(TaleGrammar.recognize(witnesses: witnesses, now: day(8), calendar: calendar))
    }

    /// Real people are the reader's to speak of. A name is never a thread.
    func testANameIsNotAThing() {
        let pages = [
            page(0, type: .diary, tags: [], text: "Saw Margaret at the station."),
            page(3, type: .diary, tags: [], text: "Rang Margaret back."),
            page(6, type: .diary, tags: [], text: "Margaret laughed at my coat.")
        ]
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(7))
        let recognized = TaleGrammar.recognize(witnesses: witnesses, now: day(7), calendar: calendar)
        XCTAssertFalse(recognized?.thread?.id.contains("margaret") ?? false)
    }

    /// A word in nearly every page is the furniture of the reader's life.
    func testAWordInEveryPageIsFurnitureNotATale() {
        let pages = (0..<12).map { page($0 * 2, type: .diary, tags: [], text: "Coffee again, number \($0).") }
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(30))
        XCTAssertNil(TaleGrammar.recognize(witnesses: witnesses, now: day(30), calendar: calendar))
    }

    func testARefusedThreadIsNotToldAgain() {
        XCTAssertNil(TaleGrammar.recognize(
            witnesses: kettleWitnesses(), barredThreadIDs: ["word:kettle"], now: day(8), calendar: calendar
        ))
    }

    // MARK: Opening, growing, ending

    private func openKettleTale() -> LivingTale {
        TaleGrammar.tend(current: nil, witnesses: kettleWitnesses(), now: day(8), calendar: calendar).opened!
    }

    func testATaleGrowsOnlyWithItsOwnThread() {
        let tale = openKettleTale()
        let more = kettleWitnesses(extra: [
            page(9, type: .diary, tags: [], text: "Descaled the kettle at last."),
            page(9, type: .mood, tags: [], text: "The bus was late, again, obviously.")
        ], now: 10)
        let grown = TaleGrammar.tend(current: tale, witnesses: more, now: day(10), calendar: calendar)
        XCTAssertEqual(grown.updated?.witnesses.count, tale.witnesses.count + 1)
        XCTAssertNil(grown.closed)
    }

    func testATaleEndsWhenItsThreadGoesQuiet() {
        let tale = openKettleTale()
        let verdict = TaleGrammar.tend(current: tale, witnesses: kettleWitnesses(), now: day(13), calendar: calendar)
        XCTAssertEqual(verdict.closed?.ending, .stillHere)
        XCTAssertFalse(verdict.closed?.isOpen ?? true)
    }

    func testATaleEndsOnceItHasPlenty() {
        let tale = openKettleTale()
        let more = kettleWitnesses(extra: [
            page(8, type: .diary, tags: [], text: "The kettle whistled like a train."),
            page(9, type: .diary, tags: [], text: "Descaled the kettle at last.")
        ], now: 9)
        XCTAssertNotNil(TaleGrammar.tend(current: tale, witnesses: more, now: day(9), calendar: calendar).closed)
    }

    func testAThingThatWentMissingEndsThatWay() {
        let tale = openKettleTale()
        let more = kettleWitnesses(extra: [
            page(9, type: .diary, tags: [], text: "The kettle broke. Boiling water in a pan like a pioneer.")
        ], now: 9)
        let grown = TaleGrammar.tend(current: tale, witnesses: more, now: day(9), calendar: calendar).updated!
        let closed = TaleGrammar.tend(current: grown, witnesses: more, now: day(15), calendar: calendar).closed
        XCTAssertEqual(closed?.ending, .returnedEmpty)
        XCTAssertTrue(TaleBinding.body(for: closed!).contains("In the end, the kettle wasn't there any more."))
    }

    /// "No heron today" is the heron not being there, not the heron still there.
    func testTheThingNotBeingThereIsHowItEnds() {
        let tale = openKettleTale()
        let more = kettleWitnesses(extra: [
            page(9, type: .diary, tags: [], text: "No kettle this morning. Somebody borrowed it.")
        ], now: 9)
        let grown = TaleGrammar.tend(current: tale, witnesses: more, now: day(9), calendar: calendar).updated!
        XCTAssertEqual(TaleGrammar.ending(for: grown), .returnedEmpty)
    }

    func testOnlyOneTaleIsOpenAtATime() {
        let tale = openKettleTale()
        let verdict = TaleGrammar.tend(current: tale, witnesses: kettleWitnesses(), now: day(8), calendar: calendar)
        XCTAssertNil(verdict.opened, "A second tale opened while one was already running")
    }

    /// A tale from the old grammar has no thread. It is put down, not bound.
    func testAnOldTaleWithNoThreadIsPutDownQuietly() {
        let old = LivingTale(
            id: "old", shape: .forbiddenDoor, title: "The Forbidden Door",
            witnesses: [], openedAt: day(0), lastWitnessedAt: day(1),
            closedAt: nil, ending: nil, boundAt: nil
        )
        let verdict = TaleGrammar.tend(current: old, witnesses: kettleWitnesses(), now: day(8), calendar: calendar)
        XCTAssertTrue(verdict.dropped)
        XCTAssertNil(verdict.closed)
        XCTAssertNil(verdict.scar)
    }

    // MARK: The telling

    private func closedKettleTale() -> LivingTale {
        TaleGrammar.tend(current: openKettleTale(), witnesses: kettleWitnesses(), now: day(13), calendar: calendar).closed!
    }

    func testTheBoundTaleIsOneThingInThreeMoments() {
        let body = TaleBinding.body(for: closedKettleTale())
        let beats = [
            "Once upon a time, there was a kettle.",
            "The kettle was still warm when I got back.",
            "Then the kettle came back.",
            "Burnt my thumb on the kettle",
            "In the end, the kettle was still there.",
            "Made tea in the kettle nobody else likes."
        ]
        let positions = beats.map { body.range(of: $0)?.lowerBound }
        XCTAssertFalse(positions.contains(where: { $0 == nil }), "missing a moment: \(body)")
        XCTAssertEqual(positions.compactMap { $0 }, positions.compactMap { $0 }.sorted(), "told out of order")
        XCTAssertFalse(body.contains("bus was late"), "a page about something else got into the tale")
        XCTAssertEqual(TaleBinding.headline(for: closedKettleTale()), "The Tale of the Kettle")
    }

    /// With more than three, the middle is the fullest page in between.
    func testTheMiddleIsTheFullestPageInBetween() {
        var tale = closedKettleTale()
        tale.witnesses.append(TaleWitness(
            id: "w-short", beat: .test, receiptID: "short", receiptKind: "reader-page",
            evidence: "Kettle.", witnessedAt: day(4), tags: [], subjects: ["word:kettle"]
        ))
        let moments = TaleBinding.threadMoments(tale)
        XCTAssertTrue(moments?.middle.evidence.hasPrefix("Burnt my thumb") == true)
        XCTAssertTrue(TaleBinding.body(for: tale).contains("Then the kettle kept coming back."))
    }

    /// A tale without a thread is never handed over: it was a row of pages.
    func testATaleWithoutAThreadIsNeverBound() {
        var tale = closedKettleTale()
        tale.thread = nil
        var inputs = BookSourceInputs()
        inputs.boundTales = [tale]
        let archiveDay = BookDay(id: "today", date: day(14), pages: [])
        XCTAssertTrue(TaleBoundPageSourceAdapter().candidates(
            for: archiveDay, context: .make(for: archiveDay), inputs: inputs, now: day(14)
        ).isEmpty)
    }

    /// Every line the old telling uses reads after its opener without a
    /// capital in the middle of a sentence.
    func testEveryActLineFollowsItsOpener() {
        for shape in TaleShape.allCases {
            for line in [shape.once, shape.then, shape.climax] {
                XCTAssertFalse(line.isEmpty)
                XCTAssertTrue(line.first!.isLowercase || line.hasPrefix("I "), "\(shape): \(line)")
            }
        }
        for ending in TaleEnding.allCases {
            XCTAssertTrue(ending.closingLine.first!.isLowercase, "\(ending): \(ending.closingLine)")
        }
    }

    // MARK: Bound Page handoff

    func testManualBoundTaleDoesNotManufactureABlankWritingPage() {
        let day = BookDay(id: "empty", date: start, pages: [])
        let surface = TaleBoundPageSourceAdapter().manualSurface(
            for: day,
            context: .make(for: day),
            inputs: BookSourceInputs(),
            now: start
        )

        XCTAssertEqual(surface.renderStyle, .loreLetter)
        XCTAssertEqual(surface.payload.metadata["taleUnavailable"], "true")
        XCTAssertEqual(surface.payload.metadata["readOnly"], "true")
        XCTAssertEqual(surface.payload.body, TaleBoundPageSourceAdapter.waitingLine)
        XCTAssertNil(surface.payload.metadata["placeholder"])
        XCTAssertFalse(surface.payload.body.isEmpty)
    }

    func testManualBoundTaleHandsOverTheFinishedTaleWhole() {
        let tale = closedKettleTale()
        var inputs = BookSourceInputs()
        // `boundTales` is what the adapter reads; `unboundTale` is derived from
        // it at the app layer and only carries the scar lookup.
        inputs.boundTales = [tale]
        inputs.unboundTale = tale
        let archiveDay = BookDay(id: "today", date: day(14), pages: [])

        let surface = TaleBoundPageSourceAdapter().manualSurface(
            for: archiveDay,
            context: .make(for: archiveDay),
            inputs: inputs,
            now: day(14)
        )

        XCTAssertEqual(surface.id, "tale-bound-\(tale.id)")
        XCTAssertEqual(surface.renderStyle, .loreLetter)
        XCTAssertEqual(surface.payload.metadata["taleID"], tale.id)
        XCTAssertEqual(surface.payload.metadata["taleThreadID"], "word:kettle")
        XCTAssertNil(surface.payload.metadata["taleUnavailable"])
        XCTAssertNil(surface.payload.metadata["placeholder"])
        XCTAssertTrue(surface.payload.body.contains("The kettle was still warm when I got back."))
        XCTAssertEqual(surface.payload.headline, "The Tale of the Kettle")
    }

    func testAlreadyHandedOverTaleCannotSurfaceAgain() {
        let tale = LivingTale(
            id: "already-bound",
            shape: .helpfulStranger,
            title: "The Helpful Stranger",
            witnesses: [],
            openedAt: day(0),
            lastWitnessedAt: day(1),
            closedAt: day(2),
            ending: .paid,
            boundAt: day(3)
        )
        var inputs = BookSourceInputs()
        inputs.unboundTale = tale
        let archiveDay = BookDay(id: "today", date: day(4), pages: [])

        let surfaces = TaleBoundPageSourceAdapter().candidates(
            for: archiveDay,
            context: .make(for: archiveDay),
            inputs: inputs,
            now: day(4)
        )

        XCTAssertTrue(surfaces.isEmpty)
    }

    func testTheReaderIsAllowedToBeOutOfAStory() {
        let verdict = TaleGrammar.tend(
            current: nil,
            witnesses: kettleWitnesses(now: 10),
            lastClosedAt: day(9),
            now: day(10),
            calendar: calendar
        )
        XCTAssertNil(verdict.opened, "A new tale opened the day after the last one closed")
    }

    // MARK: Endings and scars

    /// First person in any of its forms. The Book says "I", but it also says
    /// "in my experience" and "it did not ask me first", and those are just as
    /// much the Book speaking.
    private func speaksAsItself(_ text: String) -> Bool {
        text.contains("I ") || text.contains("I'") || text.contains("my ")
            || text.contains(" me ") || text.contains(" me.") || text.contains(" me,")
    }

    func testEveryShapeAndEndingHasALaw() {
        for shape in TaleShape.allCases {
            for ending in TaleEnding.allCases {
                let law = TaleGrammar.law(for: shape, ending: ending, subjectName: "that place")
                XCTAssertFalse(law.isEmpty, "\(shape)/\(ending) has no law")
                XCTAssertTrue(speaksAsItself(law),
                              "\(shape)/\(ending) lost the Book's voice: \(law)")
            }
        }
    }

    func testAScarSurvivesAndCanBeConsulted() {
        var tale = LivingTale(
            id: "t1", shape: .houseUnderObligation, title: "t",
            witnesses: (0..<6).map { index in
                TaleWitness(id: "w\(index)", beat: .consequence, receiptID: "place-7",
                            receiptKind: "place-refused", evidence: "e",
                            witnessedAt: day(index), tags: [])
            },
            openedAt: day(0), lastWitnessedAt: day(5), closedAt: day(6),
            ending: .imperfect, boundAt: nil
        )
        tale.ending = .imperfect
        guard let scar = TaleGrammar.scar(for: tale, ending: .imperfect, now: day(6)) else {
            return XCTFail("No scar minted")
        }
        let book = TaleScarBook(scars: [scar])
        XCTAssertTrue(book.placeIsKeepingADoorShut("place-7", at: day(7)))
        XCTAssertFalse(book.standingLaws(at: day(7)).isEmpty)
    }

    func testASeasonalScarLiftsAndAPermanentOneDoesNot() {
        let seasonal = TaleScar(
            id: "s1", taleID: "t1", shape: .houseUnderObligation, ending: .imperfect,
            law: "l", subjectID: "p", subjectKind: .place, formedAt: day(0),
            expiresAt: day(120)
        )
        let permanent = TaleScar(
            id: "s2", taleID: "t2", shape: .falseName, ending: .transformed,
            law: "l", subjectID: "r", subjectKind: .role, formedAt: day(0), expiresAt: nil
        )
        let book = TaleScarBook(scars: [seasonal, permanent])
        XCTAssertEqual(book.active(at: day(10)).count, 2)
        XCTAssertEqual(book.active(at: day(200)).count, 1)
        XCTAssertTrue(permanent.isPermanent)
        XCTAssertFalse(book.mayReassertRoleFreely(at: day(200)))
    }

    func testATaleBarelyBegunAndAbandonedLeavesNoMark() {
        let thin = LivingTale(
            id: "t", shape: .helpfulStranger, title: "t",
            witnesses: (0..<4).map { index in
                TaleWitness(id: "w\(index)", beat: .donor, receiptID: "r\(index)",
                            receiptKind: "page", evidence: "e", witnessedAt: day(index), tags: [])
            },
            openedAt: day(0), lastWitnessedAt: day(3), closedAt: day(30),
            ending: .abandoned, boundAt: nil
        )
        XCTAssertNil(TaleGrammar.scar(for: thin, ending: .abandoned, now: day(30)))
    }

    // MARK: Triads

    func testTheBookSaysNothingTheFirstTime() {
        let triad = TaleTriad(id: "t", subject: "place:orchard", appearances: [
            TaleWitness(id: "a", beat: .ret, receiptID: "r1", receiptKind: "page",
                        evidence: "e", witnessedAt: day(0), tags: ["place:orchard"])
        ], completedAt: nil)
        XCTAssertEqual(triad.standing, .establishing)
        XCTAssertNil(TaleTriadKeeper.line(for: triad))
    }

    func testThirdTimeNamesThePattern() {
        let witnesses = (0..<3).map { index in
            TaleWitness(id: "a\(index)", beat: .ret, receiptID: "r\(index)", receiptKind: "page",
                        evidence: "e", witnessedAt: day(index * 4), tags: ["place:orchard"])
        }
        let triads = TaleTriadKeeper.triads(from: witnesses, calendar: calendar)
        guard let triad = triads.first else { return XCTFail("No triad") }
        XCTAssertTrue(triad.isComplete)
        XCTAssertEqual(triad.standing, .revealing)
        XCTAssertNotNil(TaleTriadKeeper.line(for: triad))
    }

    func testTwoReceiptsInOneAfternoonAreOneAppearance() {
        let witnesses = [
            TaleWitness(id: "a", beat: .ret, receiptID: "r1", receiptKind: "page",
                        evidence: "e", witnessedAt: day(0), tags: ["place:orchard"]),
            TaleWitness(id: "b", beat: .ret, receiptID: "r2", receiptKind: "page",
                        evidence: "e", witnessedAt: day(0).addingTimeInterval(3600),
                        tags: ["place:orchard"]),
            TaleWitness(id: "c", beat: .ret, receiptID: "r3", receiptKind: "page",
                        evidence: "e", witnessedAt: day(5), tags: ["place:orchard"])
        ]
        let triads = TaleTriadKeeper.triads(from: witnesses, calendar: calendar)
        XCTAssertEqual(triads.first?.count, 2, "Same-afternoon receipts were counted twice")
    }

    // MARK: Transformation

    func testATransformationNeedsAnOverreachAndAContradiction() {
        // A tale that simply finished: no transgression, no contradiction.
        let easy = LivingTale(
            id: "t", shape: .helpfulStranger, title: "t",
            witnesses: [
                TaleWitness(id: "w1", beat: .donor, receiptID: "r1", receiptKind: "page",
                            evidence: "e", witnessedAt: day(0), tags: [])
            ],
            openedAt: day(0), lastWitnessedAt: day(1), closedAt: day(2),
            ending: .paid, boundAt: nil
        )
        XCTAssertNil(
            RoleTransformationKeeper.transformation(from: easy, roleID: "lookout", roleVerb: "watches"),
            "A role transformed without costing anything"
        )
    }

    func testAnEarnedTransformationTakesASecondHalf() {
        let hard = LivingTale(
            id: "t", shape: .threeEncounters, title: "t",
            witnesses: [
                // `reader-page`, not `page`: a transformation quotes the reader's
                // own line, and `readerLines` deliberately refuses to hand back
                // anything the Book wrote. Tagging these as generic pages asked
                // for an earned clause with nothing of the reader's in it.
                TaleWitness(id: "w1", beat: .transgression, receiptID: "r1", receiptKind: "reader-page",
                            evidence: "I got it wrong.", witnessedAt: day(0), tags: []),
                TaleWitness(id: "w2", beat: .transformation, receiptID: "r2", receiptKind: "reader-page",
                            evidence: "I said the thing out loud.", witnessedAt: day(3), tags: [])
            ],
            openedAt: day(0), lastWitnessedAt: day(3), closedAt: day(4),
            ending: .transformed, boundAt: nil
        )
        guard let transformation = RoleTransformationKeeper.transformation(
            from: hard, roleID: "lookout", roleVerb: "watches"
        ) else { return XCTFail("No transformation earned") }

        XCTAssertEqual(transformation.earnedClause, "Who Was Finally Seen")
        XCTAssertEqual(transformation.fullName(baseName: "The Lookout"), "The Lookout Who Was Finally Seen")
        XCTAssertEqual(transformation.evidence, "I said the thing out loud.")
    }

    func testEveryShapeCanEarnAClause() {
        for shape in TaleShape.allCases {
            for ending in TaleEnding.allCases {
                XCTAssertNotNil(
                    RoleTransformationKeeper.clause(for: shape, ending: ending, roleVerb: "watches"),
                    "\(shape)/\(ending) earns no clause"
                )
            }
        }
    }

    // MARK: Voice

    /// The Book uses contractions. Writing it formally: "I have never", "it is
    /// not", "did not", turns the Book into a Victorian narrator, which is
    /// the specific drift this codebase keeps having to correct.
    func testTheBookTalksLikeItselfAndNotLikeANarrator() {
        var stiff: [String] = []
        var contracted = 0
        var total = 0

        var lines: [String] = TaleShape.allCases.map(\.recognitionLine)
        lines += TaleEnding.allCases.map(\.closingLine)
        for shape in TaleShape.allCases {
            for ending in TaleEnding.allCases {
                lines.append(TaleGrammar.law(for: shape, ending: ending, subjectName: "that place"))
            }
        }

        for line in Set(lines) {
            total += 1
            if line.range(of: #"\w'(s|t|re|ve|ll|d|m)\b"#, options: .regularExpression) != nil {
                contracted += 1
            }
            // The formal constructions specifically.
            for formal in ["I have never", "I have read", "I am not going", "I would rather",
                           "it is not ", "does not ", "did not ", "cannot ", "will not "] {
                if line.contains(formal) { stiff.append("\(formal): \(line.prefix(60))") }
            }
        }

        XCTAssertTrue(stiff.isEmpty, "Stiff constructions: \(stiff.prefix(4).joined(separator: " | "))")
        XCTAssertGreaterThan(
            Double(contracted) / Double(total), 0.5,
            "Only \(contracted)/\(total) lines use a contraction: the Book has gone formal"
        )
    }

    func testEveryShapeAdmitsWhatItSawInTheBooksVoice() {
        for shape in TaleShape.allCases {
            let line = shape.recognitionLine
            XCTAssertTrue(speaksAsItself(line), "\(shape) lost the Book: \(line)")
            XCTAssertFalse(line.hasSuffix("?"), "\(shape) ended on a question")
        }
        for ending in TaleEnding.allCases {
            XCTAssertFalse(ending.closingLine.isEmpty)
            XCTAssertFalse(ending.closingLine.lowercased().contains("congratul"),
                           "\(ending) congratulated the reader")
        }
    }
}

/// The triad exemption. The app's de-repetition machinery exists specifically
/// to stop things recurring, so a deliberate three-beat pattern has to be
/// excused from it by name: otherwise the second and third appearances are
/// suppressed as reruns and the pattern can never complete.
final class TaleTriadExemptionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start)!
    }

    private func spokenPage(_ offset: Int, signalID: String, exempt: Bool) -> BookDay {
        var tags = ["book-notices", "spoke:\(signalID)"]
        if exempt { tags.append(TaleTriadKeeper.exemptionTag) }
        let page = BookPage(
            id: "p-\(offset)-\(exempt)",
            type: .bookNotices,
            createdAt: day(offset),
            promptText: "p",
            userInput: "noticed",
            tags: tags,
            origin: .generated
        )
        return BookDay(id: BookDay.id(for: page.createdAt), date: page.createdAt, pages: [page])
    }

    func testAnOrdinaryNoticeStaysRestedInsideTheWindow() {
        let days = [spokenPage(0, signalID: "orchard", exempt: false)]
        let resting = BookNoticesPageSourceAdapter.spokenSignalIDs(
            days: days, within: BookNoticesPageSourceAdapter.noticeRestDays, now: day(3)
        )
        XCTAssertTrue(resting.contains("orchard"), "A spoken signal should rest")
    }

    func testATriadAppearanceIsExcusedFromTheRest() {
        let days = [spokenPage(0, signalID: "orchard", exempt: true)]
        let resting = BookNoticesPageSourceAdapter.spokenSignalIDs(
            days: days, within: BookNoticesPageSourceAdapter.noticeRestDays, now: day(3)
        )
        XCTAssertFalse(
            resting.contains("orchard"),
            "The triad exemption did not survive the rest gate; the third time can never arrive"
        )
    }

    func testTheExemptionIsNarrowAndDoesNotFreeEverythingElse() {
        let days = [
            spokenPage(0, signalID: "orchard", exempt: true),
            spokenPage(1, signalID: "kitchen", exempt: false)
        ]
        let resting = BookNoticesPageSourceAdapter.spokenSignalIDs(
            days: days, within: BookNoticesPageSourceAdapter.noticeRestDays, now: day(3)
        )
        XCTAssertFalse(resting.contains("orchard"))
        XCTAssertTrue(resting.contains("kitchen"), "The exemption leaked onto an ordinary notice")
    }
}
