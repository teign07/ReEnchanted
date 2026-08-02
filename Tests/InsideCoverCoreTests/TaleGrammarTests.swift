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

    func testBeatsWithoutASignatureAreACoincidenceNotAShape() {
        // Spread over days, but carrying no shape's signature tags at all.
        let pages = (0..<5).map { offset in
            page(offset * 2, type: .mood, tags: ["hard"], text: "Another flat one, number \(offset).")
        }
        let witnesses = TaleGrammar.witnesses(events: [], days: days(pages), now: day(12))
        let recognized = TaleGrammar.recognize(witnesses: witnesses, now: day(12), calendar: calendar)
        XCTAssertNil(recognized, "Got \(recognized?.shape.rawValue ?? "nil") from undifferentiated pages")
    }

    // MARK: Recognition

    private func unpaidGiftWitnesses() -> [TaleWitness] {
        let pages = [
            page(0, type: .mood, tags: ["hard"], text: "Nothing has felt like anything for a fortnight."),
            page(2, type: .faeBargain, tags: ["fae", "bargain", "gift"], text: "It gave me the thing before I paid."),
            page(5, type: .wonderCompass, tags: ["fae"], text: "I went to look for what it asked for.")
        ]
        var signals = TaleSignals.none
        signals.faeMarks = [
            mark(1, id: "fae-offer-1", kind: "fae-offered", line: "A gift was set down in front of you.", tags: ["fae", "gift"]),
            mark(3, id: "fae-accept-1", kind: "fae-accepted", line: "You took it under the old law.", tags: ["fae", "bargain"]),
            mark(8, id: "fae-lapse-1", kind: "fae-lapsed", line: "The gift went cold.", tags: ["fae", "lapsed"])
        ]
        return TaleGrammar.witnesses(events: [], days: days(pages), signals: signals, now: day(10))
    }

    func testAnUnpaidGiftIsRecognisedFromRealBargainReceipts() {
        let recognized = TaleGrammar.recognize(
            witnesses: unpaidGiftWitnesses(), now: day(10), calendar: calendar
        )
        XCTAssertEqual(recognized?.shape, .unpaidGift)
    }

    func testRecognitionIsStableForTheSameEvidence() {
        let witnesses = unpaidGiftWitnesses()
        let first = TaleGrammar.recognize(witnesses: witnesses, now: day(10), calendar: calendar)
        let second = TaleGrammar.recognize(witnesses: witnesses, now: day(10), calendar: calendar)
        XCTAssertEqual(first, second, "The same evidence named two different tales")
    }

    func testATaleIsNamedFromTheReadersOwnWords() {
        let witnesses = unpaidGiftWitnesses()
        let title = TaleGrammar.title(for: .unpaidGift, witnesses: witnesses)
        XCTAssertTrue(title.hasPrefix("The Unpaid Gift"))
        XCTAssertNotEqual(title, "The Unpaid Gift", "The reader wrote lines; the title ignored them")
    }

    func testATaleWithNoReaderWordsKeepsThePlainName() {
        var signals = TaleSignals.none
        signals.faeMarks = [
            mark(0, id: "m1", kind: "fae-offered", line: "A gift.", tags: ["fae"]),
            mark(2, id: "m2", kind: "fae-accepted", line: "Taken.", tags: ["fae"]),
            mark(4, id: "m3", kind: "fae-lapsed", line: "Cold.", tags: ["fae"]),
            mark(6, id: "m4", kind: "fae-repaired", line: "Mended.", tags: ["fae"])
        ]
        let witnesses = TaleGrammar.witnesses(events: [], days: [], signals: signals, now: day(7))
        XCTAssertEqual(TaleGrammar.title(for: .unpaidGift, witnesses: witnesses), "The Unpaid Gift")
    }

    // MARK: Opening, tending, closing

    func testATaleOpensAndThenAcceptsNewWitnesses() {
        let witnesses = unpaidGiftWitnesses()
        let opening = TaleGrammar.tend(current: nil, witnesses: witnesses, now: day(10), calendar: calendar)
        guard let tale = opening.opened else { return XCTFail("No tale opened") }
        XCTAssertEqual(tale.shape, .unpaidGift)
        XCTAssertTrue(tale.isOpen)

        var grown = witnesses
        grown.append(TaleWitness(
            id: "w-extra", beat: .test, receiptID: "extra-1", receiptKind: "page",
            evidence: "I went back to look again.", witnessedAt: day(11), tags: ["fae"]
        ))
        let tended = TaleGrammar.tend(current: tale, witnesses: grown, now: day(12), calendar: calendar)
        XCTAssertEqual(tended.updated?.witnesses.count, tale.witnesses.count + 1)
        XCTAssertNil(tended.closed)
    }

    func testATaleClosesWhenItsClosingBeatsAreWitnessed() {
        let witnesses = unpaidGiftWitnesses()
        guard let tale = TaleGrammar.tend(current: nil, witnesses: witnesses, now: day(10), calendar: calendar).opened else {
            return XCTFail("No tale opened")
        }
        // The Unpaid Gift closes on transgression + consequence.
        var grown = tale.witnesses
        grown.append(TaleWitness(
            id: "w-consequence", beat: .consequence, receiptID: "place-1",
            receiptKind: "place-refused", evidence: "The market shut its stall to you.",
            witnessedAt: day(11), tags: ["fae"]
        ))
        let verdict = TaleGrammar.tend(current: tale, witnesses: grown, now: day(12), calendar: calendar)
        XCTAssertNotNil(verdict.closed)
        XCTAssertNotNil(verdict.closed?.ending)
        XCTAssertFalse(verdict.closed?.isOpen ?? true)
    }

    func testWalkingAwayIsARealEnding() {
        guard let tale = TaleGrammar.tend(
            current: nil, witnesses: unpaidGiftWitnesses(), now: day(10), calendar: calendar
        ).opened else { return XCTFail("No tale opened") }

        let muchLater = day(10 + 25)
        let verdict = TaleGrammar.tend(
            current: tale, witnesses: tale.witnesses, now: muchLater, calendar: calendar
        )
        XCTAssertEqual(verdict.closed?.ending, .abandoned)
    }

    func testOnlyOneTaleIsOpenAtATime() {
        guard let tale = TaleGrammar.tend(
            current: nil, witnesses: unpaidGiftWitnesses(), now: day(10), calendar: calendar
        ).opened else { return XCTFail("No tale opened") }
        let verdict = TaleGrammar.tend(current: tale, witnesses: unpaidGiftWitnesses(), now: day(10), calendar: calendar)
        XCTAssertNil(verdict.opened, "A second tale opened while one was already running")
    }

    func testTheReaderIsAllowedToBeOutOfAStory() {
        let verdict = TaleGrammar.tend(
            current: nil,
            witnesses: unpaidGiftWitnesses(),
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
                TaleWitness(id: "w1", beat: .transgression, receiptID: "r1", receiptKind: "page",
                            evidence: "I got it wrong.", witnessedAt: day(0), tags: []),
                TaleWitness(id: "w2", beat: .transformation, receiptID: "r2", receiptKind: "page",
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
/// excused from it by name — otherwise the second and third appearances are
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
