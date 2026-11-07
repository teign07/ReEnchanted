import XCTest
@testable import InsideCoverCore

/// The fight against the Curse (docs/the-knock-plan.md): counter-knocks,
/// the hush and the reverse knock, the Inkbones Page, and the month's leaf.
final class KnockFightTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_783_484_800)

    // MARK: The Curse's hours

    /// Once the Curse's favourite hour is known, every other day one Knock is
    /// sent right into it, and says so.
    func testCounterKnocksLandInTheCursesHour() throws {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-10 * 86_400))
        for day in 0..<8 {
            let base = start.addingTimeInterval(Double(day) * 86_400)
            let grey = base.addingTimeInterval(16 * 3600 + 600)
            ledger.record(id: "grey-\(day)", scheduledAt: grey, answeredAt: grey.addingTimeInterval(60),
                          answer: .elsewhere, cycle: 0)
            let morning = base.addingTimeInterval(9 * 3600)
            ledger.record(id: "here-\(day)", scheduledAt: morning, answeredAt: morning.addingTimeInterval(60),
                          answer: .here, cycle: 0)
        }
        XCTAssertEqual(CurseFight.strongestHour(ledger, calendar: calendar)?.hour, 16)

        let slots = AttentionProbeSchedule.slots(ledger: ledger, startingAt: calendar.startOfDay(for: now),
                                                 now: now, calendar: calendar)
        let watched = slots.filter { $0.id.hasSuffix("-watch") }
        XCTAssertFalse(watched.isEmpty)
        XCTAssertTrue(watched.allSatisfy { calendar.component(.hour, from: $0.fireAt) == 16 })
        let days = Set(slots.map(\.dayID)).count
        XCTAssertLessThanOrEqual(watched.count, days / 2 + 1, "every other day, not every day")
        XCTAssertEqual(Set(slots.map(\.id)).count, slots.count)
    }

    func testNoCounterKnocksBeforeTheCursesHourIsKnown() {
        let slots = AttentionProbeSchedule.slots(ledger: .empty, startingAt: calendar.startOfDay(for: now),
                                                 now: now, calendar: calendar)
        XCTAssertFalse(slots.contains { $0.id.hasSuffix("-watch") })
    }

    // MARK: The eucatastrophe

    func testWhenTheKnocksGoRoteTheBookGoesQuietUntilTheReaderKnocksBack() {
        var ledger = AttentionProbeLedger.empty
        XCTAssertEqual(KnockHushEngine.tend(&ledger, rote: true, distressActive: false, pages: [], now: now), .wentQuiet)
        XCTAssertTrue(AttentionProbeSchedule.slots(ledger: ledger, startingAt: calendar.startOfDay(for: now),
                                                   now: now, calendar: calendar).isEmpty, "a quiet Book doesn't knock")
        XCTAssertEqual(KnockHushEngine.line(for: ledger.hush!, now: now),
                       "I stopped knocking. I wanted to see if you'd notice.")

        // Keeping a Page with nothing written isn't a knock.
        let later = now.addingTimeInterval(86_400)
        let blank = BookPage(type: .diary, createdAt: later, promptText: "A prompt.", userInput: "  ")
        XCTAssertNil(KnockHushEngine.tend(&ledger, rote: true, distressActive: false, pages: [blank], now: later))

        let written = BookPage(type: .diary, createdAt: later, promptText: "", userInput: "Hello? Are you in there?")
        XCTAssertEqual(KnockHushEngine.tend(&ledger, rote: true, distressActive: false, pages: [written], now: later),
                       .wokenByReader)
        XCTAssertTrue(KnockHushEngine.line(for: ledger.hush!, now: later)?.contains("You knocked on me") == true)

        let slots = AttentionProbeSchedule.slots(ledger: ledger, startingAt: calendar.startOfDay(for: later),
                                                 now: later, calendar: calendar)
        XCTAssertFalse(slots.isEmpty)
        XCTAssertTrue(slots.contains { $0.id.hasSuffix("-turn") }, "the turn: new voices for a week")
        XCTAssertTrue(slots.filter { $0.fireAt.timeIntervalSince(later) > KnockHush.turnLasts + 86_400 }
            .allSatisfy { !$0.id.hasSuffix("-turn") })

        // It rests before it may go quiet again.
        let soon = later.addingTimeInterval(20 * 86_400)
        XCTAssertNil(KnockHushEngine.tend(&ledger, rote: true, distressActive: false, pages: [], now: soon))
    }

    func testNobodyKnocksAndTheBookComesBackAnyway() {
        var ledger = AttentionProbeLedger.empty
        _ = KnockHushEngine.tend(&ledger, rote: true, distressActive: false, pages: [], now: now)
        let week = now.addingTimeInterval(KnockHush.longest + 60)
        XCTAssertEqual(KnockHushEngine.tend(&ledger, rote: true, distressActive: false, pages: [], now: week), .cameBack)
        XCTAssertEqual(ledger.hush?.wokenBy, .time)
        XCTAssertFalse(AttentionProbeSchedule.slots(ledger: ledger, startingAt: calendar.startOfDay(for: week),
                                                    now: week, calendar: calendar).isEmpty)
    }

    func testAHardDayNeverStartsTheHush() {
        var ledger = AttentionProbeLedger.empty
        XCTAssertNil(KnockHushEngine.tend(&ledger, rote: true, distressActive: true, pages: [], now: now))
        XCTAssertNil(KnockHushEngine.tend(&ledger, rote: false, distressActive: false, pages: [], now: now))
        XCTAssertNil(ledger.hush)
    }

    func testOldLedgersWithoutAHushStillDecode() throws {
        let json = #"{"receipts":[],"currentCycle":2}"#
        let ledger = try JSONDecoder().decode(AttentionProbeLedger.self, from: Data(json.utf8))
        XCTAssertNil(ledger.hush)
        XCTAssertEqual(ledger.currentCycle, 2)
    }

    // MARK: The Inkbones Page

    func testTheInkbonesReplayFromTheirSeed() {
        let first = InkbonesReading.begin(seed: "day|page", question: " Should I call her? ", edge: 0)
        let again = InkbonesReading.begin(seed: "day|page", question: "Should I call her?", edge: 0)
        XCTAssertEqual(first, again)
        XCTAssertEqual(first.bones.count, InkbonesReading.boneCount)
        XCTAssertEqual(first.question, "Should I call her?")
        XCTAssertEqual(first.throwsLeft, 2)
    }

    func testKeptBonesStayPutAndTheGameEndsAfterThreeThrows() {
        for index in 0..<40 {
            var reading = InkbonesReading.begin(seed: "seed-\(index)", question: "", edge: 0)
            reading.toggleKeep(0)
            reading.toggleKeep(1)
            let held = reading.bones.prefix(2).map(\.face)
            reading.throwAgain()
            for bone in reading.bones.prefix(2) where !bone.greyed {
                XCTAssertEqual(bone.face, held[bone.id])
            }
            reading.throwAgain()
            XCTAssertTrue(reading.finished)
            XCTAssertEqual(reading.throwsLeft, 0)
            XCTAssertEqual(reading.curseRolls.count, 2)
            XCTAssertLessThanOrEqual(reading.bones.filter(\.greyed).count, 1, "the Curse greys one bone at most")
            if let greyed = reading.greyedBone {
                XCTAssertTrue(greyed.id < 2, "it only greys a bone you kept")
                XCTAssertTrue(reading.lines.last == greyed.face.shadowLine)
            }
            reading.throwAgain()
            XCTAssertEqual(reading.curseRolls.count, 2, "no throws after the third")
            XCTAssertFalse(reading.lines.isEmpty)
            XCTAssertTrue(reading.archiveText.hasPrefix("The Inkbones · The day"))
        }
    }

    func testTheFightMakesTheCurseMissMore() {
        func greyed(edge: Int) -> Int {
            (0..<400).filter { index in
                var reading = InkbonesReading.begin(seed: "fight-\(index)", question: "", edge: edge)
                for bone in reading.bones { reading.toggleKeep(bone.id) }
                reading.throwAgain()
                reading.throwAgain()
                return reading.greyedBone != nil
            }.count
        }
        XCTAssertLessThan(greyed(edge: 15), greyed(edge: 0))
        XCTAssertGreaterThan(greyed(edge: 0), 0)
    }

    func testEveryReadingLineIsAuthoredAndInVoice() {
        for face in InkbonesReading.Face.allCases {
            for line in (1...4).map(face.line(count:)) + [face.shadowLine] {
                XCTAssertTrue(line.hasSuffix(".") || line.hasSuffix("!"), line)
                XCTAssertFalse(line.lowercased().contains("the book"), line)
                XCTAssertFalse(line.lowercased().contains("door"), line)
                XCTAssertFalse(line.lowercased().contains("ritual"), line)
            }
        }
        var reading = InkbonesReading.begin(seed: "x", question: "", edge: 0)
        reading.read()
        XCTAssertEqual(reading.ask, "One sentence: what lands, or what misses?")
    }

    func testThreeOfAKindIsATriumph() {
        var reading = InkbonesReading.begin(seed: "t", question: "", edge: 0)
        for index in reading.bones.indices { reading.bones[index].face = index < 3 ? .moon : .coin }
        reading.read()
        XCTAssertTrue(reading.isTriumph)
        XCTAssertTrue(reading.lines.first?.contains("triumph") == true)
        XCTAssertTrue(reading.lines.contains(InkbonesReading.Face.moon.line(count: 3)))
        XCTAssertTrue(reading.lines.contains(InkbonesReading.Face.coin.line(count: 2)))
    }

    func testTheMorningBoneRetitlesOneCheckIn() throws {
        let whisper = try XCTUnwrap(PromptWhisperRegistry.thrownCheckIn(dayID: "2026-11-07"))
        XCTAssertTrue(whisper.title.hasPrefix("The bones fell on "))
        XCTAssertEqual(PromptWhisperRegistry.thrownCheckIn(dayID: "2026-11-07")?.id, whisper.id)
    }

    // MARK: The month's leaf

    func testTheMonthPrintsTheFight() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23))!
        var ledger = AttentionProbeLedger.empty
        for day in 0..<4 {
            let at = start.addingTimeInterval(Double(day) * 86_400 + 10 * 3600)
            ledger.record(id: "k\(day)-watch", scheduledAt: at, answeredAt: at.addingTimeInterval(30),
                          answer: day == 0 ? .elsewhere : .here, cycle: 0,
                          sentence: day == 1 ? "At the sink, watching the steam." : nil)
        }
        let throwAt = start.addingTimeInterval(2 * 86_400 + 20 * 3600)
        let log = [
            InkbonesThrowRecord(id: "curse-a", at: throwAt, thrower: .curse, roll: 91, target: 88,
                                subject: "The Red Kettle", outcome: "took"),
            InkbonesThrowRecord(id: "curse-b", at: throwAt.addingTimeInterval(86_400), thrower: .curse, roll: 12,
                                target: 88, subject: "", outcome: "missed")
        ]
        let section = MonthlyEditionBuilder.curseSection(
            attention: ledger, inkbonesLog: log, greyPageThreats: .empty,
            start: start, end: end, calendar: calendar
        )
        XCTAssertEqual(section.items.count, 2)
        let score = section.items[0].body
        XCTAssertTrue(score.contains("You answered 4 Knocks this month, and the Curse had 1 of them: 25%."), score)
        XCTAssertTrue(score.contains("1 sentence"), score)
        XCTAssertTrue(score.contains("Curse's own hour"), score)
        XCTAssertTrue(section.items[1].body.contains("The Curse threw 91 and 12. It took “The Red Kettle”."),
                      section.items[1].body)

        let quiet = MonthlyEditionBuilder.curseSection(
            attention: .empty, inkbonesLog: [], greyPageThreats: .empty, start: start, end: end, calendar: calendar
        )
        XCTAssertTrue(quiet.items.isEmpty)
    }

    // MARK: Throws in the margin

    func testThrowsAreInkedIntoTheMarginOfTheirPage() {
        let tags = ["choice:a", InkbonesMarginMark.tag(roll: 4, band: .triumph),
                    InkbonesMarginMark.curseTag(roll: 91, took: false), "inkbones-mark:nobody:7:x", "inkbones-mark:reader:400:favor"]
        let marks = InkbonesMarginMark.marks(in: tags)
        XCTAssertEqual(marks.map(\.label), ["4 · triumph!", "the Curse · 91"])
        XCTAssertEqual(InkbonesMarginMark.tag(roll: 37, band: .favor), "inkbones-mark:reader:37:favor")
    }

    // MARK: Did the bones come true?

    func testTheBookAsksAFewDaysLaterWhetherAReadingCameTrue() throws {
        var reading = InkbonesReading.begin(seed: "s", question: "Will it rain on Friday?", edge: 0)
        reading.read()
        let stored = String(data: try JSONEncoder().encode(reading), encoding: .utf8)!
        func kept(daysAgo: Double) -> BookPage {
            BookPage(id: "reading-\(daysAgo)", type: .gamePage, createdAt: now.addingTimeInterval(-daysAgo * 86_400),
                     promptText: "The Inkbones", userInput: reading.archiveText, tags: ["inkbones"],
                     metadata: ["gameID": "inkbones", "inkbonesReading": stored])
        }
        XCTAssertNil(InkbonesCameTrue.readingToAsk(in: [kept(daysAgo: 1)], now: now), "too soon")
        XCTAssertNil(InkbonesCameTrue.readingToAsk(in: [kept(daysAgo: 20)], now: now), "too late")
        XCTAssertEqual(InkbonesCameTrue.readingToAsk(in: [kept(daysAgo: 4), kept(daysAgo: 6)], now: now)?.id, "reading-4.0")

        let answered = BookPage(type: .gamePage, createdAt: now, promptText: "Did the Bones Come True?",
                                tags: ["inkbones", "\(InkbonesCameTrue.askedTag)reading-4.0", "inkbones-verdict:half"])
        XCTAssertEqual(InkbonesCameTrue.readingToAsk(in: [kept(daysAgo: 4), answered], now: now)?.id, nil)
        XCTAssertEqual(InkbonesCameTrue.verdicts(in: [answered]), [.half])

        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [kept(daysAgo: 4)])
        let surface = try XCTUnwrap(GamePageSourceAdapter().inkbonesCameTrueSurface(days: [day], now: now))
        XCTAssertEqual(surface.payload.metadata["gameID"], "inkbones-came-true")
        XCTAssertEqual(surface.payload.metadata["inkbonesOriginPageID"], "reading-4.0")
        XCTAssertTrue(surface.payload.body.contains("Will it rain on Friday?"))
        for verdict in InkbonesCameTrue.Verdict.allCases {
            XCTAssertFalse(verdict.line.lowercased().contains("the book"))
        }
    }

    // MARK: The season opens with its ribbons

    func testTheSeasonOpensWithItsRibbonedPages() {
        let early = BookPage(id: "early", type: .diary, createdAt: now.addingTimeInterval(-86_400), promptText: "p",
                             userInput: "The kettle sang flat.")
        let late = BookPage(id: "late", type: .diary, createdAt: now, promptText: "p", userInput: "Frost on the bins.")
        let other = BookPage(id: "other", type: .diary, createdAt: now, promptText: "p", userInput: "Nothing.")
        let days = [BookDay(id: BookDay.id(for: now), date: now, pages: [late, other, early])]
        let items = MonthlyEditionBuilder.ribbonedItems(days: days, ribbonedPageIDs: ["late", "early", "elsewhere"])
        XCTAssertEqual(items.map(\.id), ["early", "late"])
        XCTAssertTrue(items.allSatisfy { $0.tags.contains("ribboned") })
        XCTAssertTrue(MonthlyEditionBuilder.ribbonedItems(days: days, ribbonedPageIDs: []).isEmpty)
    }
}
