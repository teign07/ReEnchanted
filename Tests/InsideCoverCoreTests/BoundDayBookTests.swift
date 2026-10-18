import XCTest
@testable import InsideCoverCore

/// The Field Book's spine: a month told day by day, from what the reader
/// actually kept and actually read. Nothing in the day book may be invented to
/// fill a leaf.
final class BoundDayBookTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func page(_ id: String, _ type: BookPageType, day: Int, hour: Int = 20, text: String) -> BookPage {
        BookPage(id: id, type: type, createdAt: date(day, hour: hour), promptText: "Prompt", userInput: text)
    }

    private func receipt(
        _ content: String,
        occurrence: String,
        day: Int,
        state: AuthoredContentReceiptState = .opened,
        title: String = "A scene",
        body: String,
        choice: String? = nil,
        room: String? = "location-great-hall",
        cast: [String] = ["penny-blackletter", "wicker-eddies"]
    ) -> AuthoredContentReceipt {
        AuthoredContentReceipt(
            contentID: content,
            occurrenceID: occurrence,
            channel: .storyScene,
            state: state,
            recordedAt: date(day, hour: 10),
            printedTitle: title,
            printedBody: body,
            printedChoiceLabel: choice,
            roomID: room,
            castIDs: cast
        )
    }

    private func ledger(_ receipts: [AuthoredContentReceipt]) -> AuthoredContentReceiptLedger {
        receipts.reduce(AuthoredContentReceiptLedger.empty) { $0.recording($1) }
    }

    private func make(
        pages: [BookPage],
        receipts: [AuthoredContentReceipt] = [],
        acts: [CastActRecord] = []
    ) throws -> BoundDayBook {
        try XCTUnwrap(BoundDayBookBuilder.make(
            pages: pages,
            receipts: ledger(receipts),
            castActs: acts,
            startDate: date(1, hour: 0),
            endDate: date(31, hour: 23),
            calendar: calendar
        ))
    }

    // MARK: Days

    func testEveryDayWithSomethingEarnsALeafAndEmptyDaysDoNot() throws {
        let book = try make(pages: [
            page("b5", .bookOfYou, day: 5, text: "The night gathered."),
            page("b6", .bookOfYou, day: 6, text: "The night gathered again.")
        ])
        XCTAssertEqual(book.days.count, 2)
        XCTAssertEqual(book.quietDates.count, 29, "Every other day of October is open, not padded.")
        XCTAssertTrue(book.days.allSatisfy { $0.hasWorldSide || $0.hasYourSide })
    }

    func testAMonthWithNothingReadOrKeptBindsNoDays() {
        XCTAssertNil(BoundDayBookBuilder.make(
            pages: [], receipts: .empty, castActs: [],
            startDate: date(1, hour: 0), endDate: date(31, hour: 23), calendar: calendar
        ))
    }

    func testADayWithBothSidesIsASpreadAndOneSideIsALeaf() throws {
        let book = try make(
            pages: [
                page("b4", .bookOfYou, day: 4, text: "Sunday gathered itself."),
                page("b7", .bookOfYou, day: 7, text: "Only the reader was here.")
            ],
            receipts: [
                receipt("scene.jump", occurrence: "o1", day: 4, body: "Penny draws chalk."),
                receipt("scene.later", occurrence: "o2", day: 9, body: "A scene on a day nothing was kept.")
            ]
        )
        let byDay = Dictionary(uniqueKeysWithValues: book.days.map { (calendar.component(.day, from: $0.date), $0) })
        XCTAssertTrue(try XCTUnwrap(byDay[4]).isSpread)
        XCTAssertFalse(try XCTUnwrap(byDay[7]).hasWorldSide)
        XCTAssertTrue(try XCTUnwrap(byDay[7]).hasYourSide)
        XCTAssertTrue(try XCTUnwrap(byDay[9]).hasWorldSide)
        XCTAssertFalse(try XCTUnwrap(byDay[9]).hasYourSide)
    }

    func testTheAlmanacIsComputedAndNeverInvented() throws {
        let book = try make(pages: [page("b18", .bookOfYou, day: 18, text: "The blue door.")])
        let day = try XCTUnwrap(book.days.first)
        XCTAssertEqual(day.almanac.moonName, MoonPhaseCalendar.phase(on: date(18, hour: 12)).name)
        XCTAssertTrue((0.0...1.0).contains(day.almanac.moonIlluminated))
        XCTAssertTrue(day.almanac.skyWords.isEmpty, "No sky was kept, so no sky is printed.")
    }

    func testSkyWordsComeFromThePagesOwnContext() throws {
        var kept = page("d1", .diary, day: 12, text: "Walked the dog in the rain by the river.")
        kept.context = BookPageContextSnapshot(at: date(12), calendar: calendar, weatherTags: ["weather-rain", "weather-wind"])
        let book = try make(pages: [kept])
        XCTAssertEqual(try XCTUnwrap(book.days.first).almanac.skyWords, ["rain", "wind"])
    }

    func testReadersOwnWordsAndSpecimensAreCarried() throws {
        let book = try make(pages: [
            page("b", .bookOfYou, day: 18, hour: 21, text: "The night gathered."),
            page("s1", .souvenir, day: 18, hour: 8, text: "Planted garlic in the window box in the hallway."),
            page("d1", .diary, day: 18, hour: 12, text: "Wrote a list and then lost it at the library.")
        ])
        let day = try XCTUnwrap(book.days.first)
        XCTAssertTrue(day.words.contains("Planted garlic in the window box in the hallway."))
        // Both are printed whole as the day's entries, so neither is listed again as a specimen.
        XCTAssertEqual(day.entries.map(\.pageID), ["s1", "d1"])
        XCTAssertTrue(day.entries.allSatisfy { $0.clock != nil })
        XCTAssertTrue(day.specimens.isEmpty)
        XCTAssertEqual(day.braids.count, 1)
    }

    func testALongEntryIsKeptWholeAndEveryEntryOfTheDayPrints() throws {
        let long = String(repeating: "I sat on the back step until my hands were cold and watched the geese go over. ", count: 6)
        let book = try make(pages: [
            page("d1", .diary, day: 18, hour: 8, text: long),
            page("d2", .diary, day: 18, hour: 12, text: "The bakery remembered the end piece."),
            page("d3", .souvenir, day: 18, hour: 18, text: "Frost on the car roof like a map."),
            page("d4", .weather, day: 18, hour: 21, text: "Low grey sky sitting right on the roofs.")
        ])
        let day = try XCTUnwrap(book.days.first)
        XCTAssertEqual(day.entries.count, 4, "A day prints every entry, not the first two.")
        XCTAssertEqual(day.entries.first?.text, long.trimmingCharacters(in: .whitespaces), "Nothing is shortened.")
        XCTAssertGreaterThan(day.readerWordCount, 90)
        XCTAssertFalse(day.isThinYourSide, "A day with a real entry is never gathered as thin.")
    }

    func testAReplyOnAKeptLetterPrintsWithTheLetter() throws {
        var letter = page("l1", .letter, day: 12, text: "I have been meaning to write. What did it say?")
        letter.playerReply = "It said nothing, which was the problem."
        let book = try make(pages: [letter])
        let keep = try XCTUnwrap(book.days.first?.keeps.first)
        XCTAssertEqual(keep.kind, .letter)
        XCTAssertEqual(keep.readerReply, "It said nothing, which was the problem.")
        XCTAssertTrue(book.days.first?.entries.isEmpty ?? false, "A reply sits with its letter, not again among the entries.")
    }

    func testTheTaleNumbersEachSceneOnceInReadingOrder() throws {
        let book = try make(pages: [], receipts: [
            receipt("scene.a", occurrence: "a1", day: 3, title: "First", body: "One. Two three four five six seven."),
            receipt("scene.b", occurrence: "b1", day: 5, title: "Second", body: "Eight nine ten eleven twelve thirteen."),
            receipt("scene.a", occurrence: "a2", day: 6, title: "First, again", body: "More of the first scene, later.")
        ])
        let chapters = book.taleChapters
        XCTAssertEqual(chapters.map(\.contentID), ["scene.a", "scene.b"])
        XCTAssertEqual(chapters.map(\.number), [1, 2])
        XCTAssertEqual(chapters.first?.parts.count, 2)
    }

    func testAWeeklyChapterIsNamedForWhatTheBookKept() throws {
        let book = try make(pages: [
            page("b", .bookOfYou, day: 8, hour: 22, text: "The Kettle\n\nYou put the kettle on.\n\nI kept the page: the kettle got its whole speech."),
            page("d", .diary, day: 9, hour: 9, text: "Nothing much. Toast, standing up, and a long walk home.")
        ])
        let chapters = WeeklyTaleBuilder.chapters(of: book, from: date(8), to: date(14, hour: 23), calendar: calendar)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].heading, "In which the kettle got its whole speech")
        XCTAssertEqual(chapters[0].keptLine, "I kept the page: the kettle got its whole speech.")
        XCTAssertFalse(chapters[0].telling?.contains("I kept the page") ?? true, "The colophon closes the chapter, not the telling.")
        XCTAssertTrue(chapters[0].opener.hasPrefix("Once upon a "))
        XCTAssertFalse(chapters[1].heading.contains("Toast"), "A heading is never the reader's own sentence.")
    }

    // MARK: Scenes the reader read

    func testOnlyScenesActuallyOpenedArePrinted() throws {
        let delivered = receipt("scene.never", occurrence: "o0", day: 3, state: .delivered, body: "Never opened.")
        let read = receipt("scene.read", occurrence: "o1", day: 3, state: .opened, body: "Opened and read.")
        let book = try make(pages: [], receipts: [delivered, read])
        let scenes = book.scenes
        XCTAssertEqual(scenes.map(\.body), ["Opened and read."])
    }

    func testTheSameSceneShownInTwoHoursIsOneSceneAndKeepsTheChoice() throws {
        let book = try make(pages: [], receipts: [
            receipt("scene.s", occurrence: "hour-1", day: 18, state: .opened, body: "Three preparations are underway."),
            receipt("scene.s", occurrence: "hour-2", day: 18, state: .opened, body: "Three preparations are underway."),
            receipt("scene.s", occurrence: "hour-2", day: 18, state: .completed, body: "Three preparations are underway.", choice: "The Hunt")
        ])
        XCTAssertEqual(book.scenes.count, 1)
        XCTAssertEqual(book.scenes.first?.choiceLabel, "The Hunt")
    }

    func testScenesKeepTheirRoomAndCastAndRunInReadingOrder() throws {
        let book = try make(pages: [], receipts: [
            receipt("scene.b", occurrence: "o2", day: 8, body: "East Stacks.", room: "location-east-stacks", cast: ["serenity-brown"]),
            receipt("scene.a", occurrence: "o1", day: 4, body: "Vault of Doors.", room: "location-vault-of-doors", cast: ["wicker-eddies", "penny-blackletter"])
        ])
        XCTAssertEqual(book.scenes.map(\.roomID), ["location-vault-of-doors", "location-east-stacks"])
        XCTAssertEqual(book.scenes.first?.roomName, "The Vault of Doors")
        XCTAssertEqual(book.chart.route, ["location-vault-of-doors", "location-east-stacks"])
        XCTAssertFalse(book.chart.timetableOnly)
    }

    // MARK: Weeks

    func testWeeksGatherSevenDaysAndNameTheirStrongestNight() throws {
        let book = try make(pages: [
            page("b1", .bookOfYou, day: 2, text: "A small night."),
            page("b2", .bookOfYou, day: 9, text: "The door was a different blue and nobody on the street would say who did it; I think the door did it itself.")
        ])
        XCTAssertEqual(book.weeks.map(\.index), [0, 1])
        XCTAssertTrue(book.weeks.allSatisfy { $0.nightCount == 1 && $0.strongestNight != nil })
    }

    // MARK: The Labyrinth chart

    func testTheChartRanksTheCastTheMonthActuallyUsed() throws {
        let book = try make(pages: [], receipts: [
            receipt("scene.a", occurrence: "o1", day: 4, body: "One.", room: "location-vault-of-doors", cast: ["wicker-eddies", "penny-blackletter", "serenity-brown"]),
            receipt("scene.b", occurrence: "o2", day: 5, body: "Two.", room: "location-east-stacks", cast: ["wicker-eddies", "penny-blackletter"]),
            receipt("scene.c", occurrence: "o3", day: 6, body: "Three.", room: "location-east-stacks", cast: ["wicker-eddies"])
        ])
        let slugs = book.chart.cast.map(\.slug)
        XCTAssertEqual(slugs.first, "wicker-eddies")
        XCTAssertLessThanOrEqual(slugs.count, BoundDayBookBuilder.maximumCastShown)
        XCTAssertTrue(book.chart.cast.allSatisfy { $0.plateAssetName?.hasPrefix("LabyrinthCharacter") == true })
        XCTAssertEqual(book.chart.roomVisits["location-east-stacks"], 2)
        XCTAssertTrue(book.chart.drawnRoomIDs.contains("location-vault-of-doors"))
        XCTAssertFalse(book.chart.drawnRoomIDs.contains(AcademyGeography.dormID), "The Dorm is the reader's and is never charted.")
    }

    func testAMonthWithNoScenesSaysTheChartIsTheTimetable() throws {
        let book = try make(pages: [page("b", .bookOfYou, day: 5, text: "A night.")])
        XCTAssertTrue(book.chart.timetableOnly)
        XCTAssertTrue(book.chart.route.isEmpty)
        XCTAssertFalse(book.chart.cast.isEmpty, "The timetable still puts the Cast somewhere.")
    }

    // MARK: Freezing at the moment of showing

    func testReceiptsFreezeWhatTheReaderWasShown() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let issue = try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json"))
        )
        let now = date(4)
        let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.monthlyIssueAuthoringManifests = try XCTUnwrap(issue.authoringManifests)
        inputs.authoredStoryScenes = try XCTUnwrap(issue.storyScenes)
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: issue.id, event: try XCTUnwrap(issue.events.first), now: now, calendar: calendar
        ))
        let candidates = AuthoredStoryScenePageAdapter.candidates(
            for: day, inputs: inputs, now: now, lifecycleOverride: [snapshot]
        )
        let prepared = MonthlyIssuePageCuration.preparing(
            candidates, manifests: inputs.monthlyIssueAuthoringManifests,
            day: day, inputs: inputs, now: now, lifecycleOverride: [snapshot]
        )
        let surface = try XCTUnwrap(prepared.first {
            $0.payload.metadata[MonthlyIssuePageMetadata.contentID] == "count-unbound.scene.sunday-jump"
        })
        let frozen = try XCTUnwrap(
            surface.authoredContentReceipts(state: .opened, at: now).first { $0.channel == .storyScene }
        )
        XCTAssertEqual(frozen.printedTitle, surface.payload.headline)
        XCTAssertEqual(frozen.printedBody, surface.payload.body.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(frozen.roomID, "location-vault-of-doors")
        XCTAssertTrue(frozen.castIDs?.contains("wicker-eddies") == true)
        XCTAssertGreaterThan(frozen.printedBody?.count ?? 0, 100)

        // And a ledger that recorded it can bind it, with no pack in sight.
        let recorded = ledger([frozen])
        let book = try XCTUnwrap(BoundDayBookBuilder.make(
            pages: [], receipts: recorded, castActs: [],
            startDate: date(1, hour: 0), endDate: date(31, hour: 23), calendar: calendar
        ))
        XCTAssertEqual(book.scenes.first?.title, surface.payload.headline)
    }

    func testOlderReceiptsWithoutFrozenTextStillDecode() throws {
        let legacy = """
        {"id":"x","contentID":"c","occurrenceID":"o","channel":"storyScene","scope":{},"state":"opened","recordedAt":0,"evidencePageIDs":[]}
        """
        let decoded = try JSONDecoder().decode(AuthoredContentReceipt.self, from: Data(legacy.utf8))
        XCTAssertNil(decoded.printedBody)
        XCTAssertNil(decoded.roomID)
    }

    // MARK: The edition carries it

    func testTheMonthlyEditionCarriesTheDayBook() {
        let start = date(1, hour: 0)
        var days: [BookDay] = []
        for offset in [4, 5, 6, 18] {
            let d = date(offset)
            days.append(BookDay(id: BookDay.id(for: d, calendar: calendar), date: calendar.startOfDay(for: d), pages: [
                page("braid-\(offset)", .bookOfYou, day: offset, text: "The night of the \(offset)th gathered itself."),
                page("souv-\(offset)", .souvenir, day: offset, hour: 8, text: "A gull argued with a chimney on the \(offset)th.")
            ]))
        }
        let edition = MonthlyEditionBuilder.edition(
            from: days,
            readerName: "Reader",
            startDate: start,
            endDate: date(31, hour: 23),
            generatedAt: date(31, hour: 23),
            calendar: calendar,
            authoredReceipts: ledger([receipt("scene.s", occurrence: "o", day: 18, body: "Three preparations are underway.")])
        )
        let book = edition.dayBook
        XCTAssertNotNil(book)
        XCTAssertEqual(book?.braidCount, 4)
        XCTAssertEqual(book?.scenes.count, 1)
    }

    // MARK: Fitting

    func testTheDaysGiveUpWhatTheyCanSpareAndKeepTheNightsAndScenes() throws {
        var pages: [BookPage] = []
        for day in 1...14 {
            pages.append(page("b\(day)", .bookOfYou, day: day, text: "The night of the \(day)th gathered itself."))
            pages.append(page("s\(day)", .souvenir, day: day, hour: 9, text: "A small sentence kept on the \(day)th of the month."))
            pages.append(page("d\(day)", .diary, day: day, hour: 11, text: "A second thing worth writing down on day \(day) of it."))
        }
        // Days with only a sentence, and no night.
        for day in 16...20 {
            pages.append(page("t\(day)", .diary, day: day, hour: 11, text: "Only a sentence was kept on the \(day)th of the month."))
            pages.append(page("u\(day)", .weather, day: day, hour: 12, text: "Grey all afternoon."))
        }
        let book = try make(pages: pages, receipts: [
            receipt("scene.a", occurrence: "o1", day: 3, body: "A scene on the third."),
            receipt("scene.b", occurrence: "o2", day: 9, body: "A scene on the ninth.")
        ])
        func weight(_ b: BoundDayBook) -> Int {
            b.days.reduce(0) { $0 + $1.braids.count * 10 + $1.scenes.count * 10 + $1.photos.count + $1.specimens.count + $1.words.count + $1.clippings.count }
        }
        var current = book
        var steps = 0
        while let smaller = current.trimmedForPrint() {
            XCTAssertLessThan(weight(smaller), weight(current), "Every step must give something up.")
            current = smaller
            steps += 1
            XCTAssertLessThan(steps, 20, "Trimming must terminate.")
        }
        XCTAssertGreaterThan(steps, 0)
        XCTAssertEqual(current.scenes.count, 2, "The scenes the reader read are the last thing to go.")
        XCTAssertGreaterThan(current.braidCount, 0)
        XCTAssertTrue(current.days.allSatisfy { $0.hasWorldSide || $0.hasYourSide })
    }

    // MARK: The Ledger of Nights

    func testTheKeptLineIsTheNightsOwnClosing() {
        XCTAssertEqual(
            BoundNightLine.keptLine(from: "You found the card.\n\nI kept the page: the card came home from Portugal."),
            "the card came home from Portugal."
        )
        XCTAssertEqual(BoundNightLine.keptLine(from: ""), "")
        let long = "Word " + String(repeating: "and a long word ", count: 20)
        XCTAssertLessThanOrEqual(BoundNightLine.keptLine(from: long).count, 108)
    }

    func testAnAnnualNamesEveryNightEvenWhenThePrintedBookCannotHoldThemAll() {
        var days: [BookDay] = []
        for month in [1, 2, 3] {
            for day in [3, 9, 17, 24] {
                let d = calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 20))!
                days.append(BookDay(id: BookDay.id(for: d, calendar: calendar), date: calendar.startOfDay(for: d), pages: [
                    BookPage(id: "braid-\(month)-\(day)", type: .bookOfYou, createdAt: d, promptText: "Prompt",
                             userInput: "Night \(month)/\(day)\n\nIt happened.\n\nI kept the page: night \(month)/\(day) held.")
                ]))
            }
        }
        let annual = MonthlyEditionBuilder.annual(2026, from: days, readerName: "Reader", now: date(31, hour: 23), calendar: calendar)
        let ledger = annual.nightsLedger ?? []
        XCTAssertEqual(ledger.count, 12)
        XCTAssertEqual(ledger.map(\.date), ledger.map(\.date).sorted())
        XCTAssertTrue(ledger.allSatisfy { !$0.line.isEmpty })
        // Trimming the printed braids must not touch the ledger.
        if let trimmed = annual.trimmedForPrint() {
            XCTAssertEqual(trimmed.nightsLedger?.count, 12)
        }
    }

    // MARK: Privacy

    func testBodyAndFuelPagesStayOutOfAPrintedDayUnlessThatDrawerWasOpened() throws {
        let pages = [
            page("b", .bookOfYou, day: 6, text: "The night gathered."),
            page("fuel", .fuel, day: 6, hour: 12, text: "Ate very little today and slept badly last night."),
            page("body", .body, day: 6, hour: 13, text: "Heart rate was high all afternoon, felt dizzy.")
        ]
        let closed = try make(pages: pages)
        XCTAssertTrue(closed.days.flatMap(\.words).allSatisfy { !$0.contains("dizzy") && !$0.contains("slept badly") })
        XCTAssertTrue(closed.days.flatMap(\.specimens).isEmpty)
        let open = try XCTUnwrap(BoundDayBookBuilder.make(
            pages: pages, receipts: .empty, castActs: [], startDate: date(1, hour: 0), endDate: date(31, hour: 23),
            includesPrivateBody: true, calendar: calendar))
        XCTAssertFalse(open.days.flatMap(\.words).isEmpty)
    }

    // MARK: Typed keeps, reports, the dial

    func testEveryKindOfKeepIsDressedForItsLeafAndNotListedTwice() throws {
        var letter = page("l", .letter, day: 5, hour: 10, text: "I have been meaning to write to you about the wall.")
        letter.metadata = ["speakerName": "Zara Finch", "castID": "zara-finch"]
        var klass = page("c", .academyClass, day: 5, hour: 11, text: "You walked the yard blindfolded and found the knot by listening.")
        klass.metadata = ["sessionName": "Wayfinding", "sessionRoom": "Wing 2: The Momentum Yard", "sessionProfessor": "Professor Stonebrook"]
        let spell = page("e", .enchantment, day: 5, hour: 12, text: "The brass tap told you the story of every hand that turned it.")
        let story = page("s", .narrativeOS, day: 5, hour: 13, text: "There was once a coat that remembered a lighthouse.")
        var authored = page("a", .narrativeOS, day: 5, hour: 14, text: "A scene printed from its receipt instead.")
        authored.tags = ["authored-story-scene"]
        let book = try make(pages: [letter, klass, spell, story, authored, page("b", .bookOfYou, day: 5, text: "A night.")])
        let day = try XCTUnwrap(book.days.first)
        XCTAssertEqual(Set(day.keeps.map(\.kind)), [.letter, .classSession, .enchantment, .story])
        XCTAssertFalse(day.keeps.contains { $0.id == "a" }, "An authored scene is printed from its receipt, not as a keep.")
        let kept = Dictionary(uniqueKeysWithValues: day.keeps.map { ($0.kind, $0) })
        XCTAssertEqual(kept[.classSession]?.title, "Wayfinding")
        XCTAssertEqual(kept[.classSession]?.room, "Wing 2: The Momentum Yard")
        XCTAssertEqual(kept[.classSession]?.professor, "Professor Stonebrook")
        XCTAssertEqual(kept[.letter]?.speakerName, "Zara Finch")
        let listed = Set(day.specimens.map(\.id)).union(day.photos.map(\.id))
        XCTAssertTrue(listed.isDisjoint(with: Set(day.keeps.map(\.id))), "A kept letter is not also a line in the specimen list.")
        XCTAssertTrue(Set(day.printedPageIDs).isSuperset(of: Set(day.keeps.map(\.id))), "The archive must not print it a second time.")
        XCTAssertFalse(day.isThinYourSide)
    }

    func testAnUnreadSceneIsPrintedAsTheAcademysRecordNeverAsSomethingTheyDid() throws {
        let book = try make(pages: [], receipts: [
            receipt("scene.read", occurrence: "o1", day: 8, state: .opened, body: "You read this one."),
            receipt("scene.missed", occurrence: "report:1", day: 9, state: .reported, title: "A Future Tense", body: "Dracula returned to his source at the Great Hall.", room: "location-great-hall")
        ])
        let scenes = Dictionary(uniqueKeysWithValues: book.scenes.map { ($0.contentID, $0) })
        XCTAssertEqual(scenes["scene.read"]?.isReport, false)
        XCTAssertEqual(scenes["scene.missed"]?.isReport, true)
        XCTAssertNil(scenes["scene.missed"]?.choiceLabel)
    }

    func testTheDialIsPrintedByTheDayItPlayedAndNotTwice() throws {
        func radio(_ id: String, day: Int, hour: Int, _ line: String) -> AuthoredContentReceipt {
            AuthoredContentReceipt(contentID: id, occurrenceID: id, channel: .radioBanter, state: .played,
                                   recordedAt: date(day, hour: hour), printedTitle: "Thornwave", printedBody: line)
        }
        let book = try make(pages: [], receipts: [
            radio("r1", day: 3, hour: 8, "They've padded the corners again."),
            radio("r2", day: 3, hour: 20, "They've padded the corners again."),
            radio("r3", day: 9, hour: 12, "A word to the wise.")
        ])
        let byDay = Dictionary(uniqueKeysWithValues: book.days.map { (calendar.component(.day, from: $0.date), $0) })
        XCTAssertEqual(byDay[3]?.radio.count, 1)
        XCTAssertEqual(byDay[9]?.radio.first?.station, "Thornwave")
        XCTAssertTrue(byDay[3]?.hasWorldSide == true)
    }

    func testAShortCastNoteTheCuratorSetAsideStillGetsItsLeaf() throws {
        var note = page("n", .gossip, day: 6, hour: 15, text: "The kettle has opinions about you.")
        note.metadata = ["castID": "ambrose-trencher"]
        let braid = page("b", .bookOfYou, day: 6, text: "A night.")
        // Curation kept only the braid; the note is in the whole month.
        let book = try XCTUnwrap(BoundDayBookBuilder.make(
            pages: [braid], keepablePages: [braid, note], receipts: .empty, castActs: [],
            startDate: date(1, hour: 0), endDate: date(31, hour: 23), calendar: calendar))
        let keep = try XCTUnwrap(book.days.first?.keeps.first)
        XCTAssertEqual(keep.kind, .castNote)
        XCTAssertEqual(keep.speakerName, KeepMarginalia.voice(forSlug: "ambrose-trencher")?.name)
        // The same note kept twice is one note.
        var twin = note; twin.id = "n2"
        let again = try XCTUnwrap(BoundDayBookBuilder.make(
            pages: [braid], keepablePages: [braid, note, twin], receipts: .empty, castActs: [],
            startDate: date(1, hour: 0), endDate: date(31, hour: 23), calendar: calendar))
        XCTAssertEqual(again.days.first?.keeps.count, 1)
    }

    // MARK: The Tale's chapter titles and the reader's scrapbook

    func testAChapterRetellsTheReadersDetailInTheBooksVoice() {
        XCTAssertEqual(WeeklyTaleBuilder.readerDetailHeading("Found a moth asleep inside the lampshade. Left it there."),
                       "In which you found a moth asleep inside the lampshade")
        XCTAssertEqual(WeeklyTaleBuilder.readerDetailHeading("Clear and sharp. My breath showed at the bus stop."),
                       "In which your breath showed at the bus stop")
        XCTAssertEqual(WeeklyTaleBuilder.readerDetailHeading("Wrote a list and then lost it at the library."),
                       "In which you wrote a list and then lost it at the library")
        XCTAssertNil(WeeklyTaleBuilder.readerDetailHeading("I like it more than I should."),
                     "No thing in it, and nothing happened: not a title.")
        XCTAssertNil(WeeklyTaleBuilder.readerDetailHeading("Grey all day."))
    }

    func testAColophonThatAlreadyHasAVerbIsNotGivenAnother() {
        XCTAssertEqual(WeeklyTaleBuilder.colophonHeading("I kept the page: you heard the geese, even without seeing them.", readerWords: []),
                       "In which you heard the geese, even without seeing them")
        XCTAssertEqual(WeeklyTaleBuilder.colophonHeading("I kept the page: the cat on the long way.", readerWords: []),
                       "In which there was the cat on the long way")
    }

    private func pagewright(_ id: String, day: Int, title: String, note: String?, photos: Int) -> BookPage {
        var page = BookPage(id: id, type: .plainPage, createdAt: date(day, hour: 20), promptText: title,
                            userInput: note.map { "\($0)\n\nScraps bound here:\nPhotograph: the river" } ?? "Photograph: the river",
                            tags: ["pagewright", "scrapbook", "kept-page", "photo-count:\(photos)", "mark-count:1", "source-count:2"],
                            sourceID: "pagewright", origin: .userAuthored)
        page.mediaAssets = [BookPageMediaAsset(kind: .renderedImageFile, reference: "/tmp/\(id).png", caption: title, sourceID: "pagewright",
                                               metadata: ["mediaRole": "scrapbookPreview", "export": "png"])]
        return page
    }

    func testOnlyTheReadersNoteOnAScrapbookPageIsTheirWriting() {
        XCTAssertEqual(pagewright("p1", day: 10, title: "River", note: "I want this one on the wall.", photos: 1).readerAuthoredTexts,
                       ["I want this one on the wall."])
        XCTAssertTrue(pagewright("p2", day: 10, title: "River", note: nil, photos: 1).readerAuthoredTexts.isEmpty,
                      "The Pagewright's list of scraps is never the reader's sentence.")
    }

    func testScrapbookPagesKeepTheirDayAndTheMostMadeOverPrintFullSize() throws {
        let book = try XCTUnwrap(BoundDayBookBuilder.make(
            pages: [pagewright("a", day: 8, title: "A", note: "One.", photos: 3),
                    pagewright("b", day: 9, title: "B", note: nil, photos: 0),
                    pagewright("c", day: 10, title: "C", note: "Three.", photos: 2)],
            receipts: ledger([]), castActs: [], startDate: date(8, hour: 0), endDate: date(15, hour: 0), calendar: calendar))
        let pages = book.days.flatMap(\.scrapbook)
        XCTAssertEqual(pages.map(\.id), ["a", "b", "c"], "Every page the reader made is in the book.")
        XCTAssertEqual(Set(pages.filter(\.fullPage).map(\.id)), ["a", "c"], "A week prints its two most made-over pages full size.")
        XCTAssertTrue(book.days.allSatisfy { $0.entries.allSatisfy { !$0.text.contains("Scraps bound here") } })
        XCTAssertTrue(book.days.flatMap(\.printedPageIDs).contains("b"), "A small print is still printed, so the archive won't repeat it.")
    }
}
