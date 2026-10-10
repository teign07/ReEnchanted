import XCTest
@testable import InsideCoverCore

final class AcademyGeographyTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// A Wednesday at noon: no class and no club is in session, so no room
    /// grows a timetable line the test didn't ask for.
    private var quietNoon: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!
    }

    private func page(_ id: String, prose: String, origin: BookPageOrigin = .generated, daysAgo: Int = 1) -> BookPage {
        BookPage(
            id: id,
            type: .note,
            createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: quietNoon)!,
            promptText: prose,
            userInput: "",
            tags: [],
            sourceID: "test",
            origin: origin
        )
    }

    private func chart(
        pages: [BookPage] = [],
        placeStates: [String: PlaceState] = [:],
        affinities: [String: Int] = [:],
        sky: SkyCondition? = nil,
        anchors: [String] = [],
        now: Date? = nil
    ) -> AcademyChart {
        AcademyCartographer.chart(AcademyChartInputs(
            days: pages.isEmpty ? [] : [BookDay(id: "d", date: quietNoon, pages: pages)],
            placeStates: placeStates,
            storySettingAffinities: affinities,
            sky: sky,
            anchorNames: anchors,
            now: now ?? quietNoon,
            calendar: calendar
        ))
    }

    // MARK: - The floor plan holds together

    func testEveryRoomHasItsOwnID() {
        let ids = AcademyGeography.rooms.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        for id in ids { XCTAssertTrue(id.hasPrefix("location-"), id) }
    }

    func testEveryPassageJoinsTwoRealRoomsOnce() {
        let ids = Set(AcademyGeography.rooms.map(\.id))
        var seen: Set<String> = []
        for passage in AcademyGeography.passages {
            XCTAssertTrue(ids.contains(passage.from), passage.from)
            XCTAssertTrue(ids.contains(passage.to), passage.to)
            XCTAssertNotEqual(passage.from, passage.to)
            let key = [passage.from, passage.to].sorted().joined(separator: "|")
            XCTAssertFalse(seen.contains(key), "two passages between \(key)")
            seen.insert(key)
        }
    }

    /// Whatever the Book draws, the reader could walk to it from their own room.
    func testEveryRoomCanBeWalkedToFromTheDorm() {
        var reached: Set<String> = [AcademyGeography.dormID]
        var frontier = [AcademyGeography.dormID]
        while let here = frontier.popLast() {
            for passage in AcademyGeography.passages(touching: here) {
                if let next = passage.other(than: here), reached.insert(next).inserted {
                    frontier.append(next)
                }
            }
        }
        let unreachable = Set(AcademyGeography.rooms.map(\.id)).subtracting(reached)
        XCTAssertTrue(unreachable.isEmpty, "can't walk to \(unreachable.sorted())")
    }

    /// The timetable names rooms in free text. Every one of them has to be
    /// somewhere on the map, or a class is being held in a room with no floor.
    func testEveryTimetableRoomIsOnTheMap() {
        let sessions = Array(AcademyScheduleRegistry.classes.values) + Array(AcademyScheduleRegistry.clubs.values)
        XCTAssertFalse(sessions.isEmpty)
        for session in sessions {
            XCTAssertNotNil(AcademyGeography.room(forTimetableName: session.room), session.room)
        }
    }

    /// The story's authored locations and the map's rooms are the same rooms.
    func testEveryAuthoredLocationIsOnTheMap() {
        let locations = NarrativePackRegistry.bundledPacks
            .flatMap(\.entities)
            .filter { $0.kind == .location }
        XCTAssertFalse(locations.isEmpty)
        for location in locations {
            XCTAssertNotNil(AcademyGeography.room(id: location.id), location.id)
        }
    }

    /// The school is built on the Compass.
    func testTheWingsSitOnTheirCompassPoints() {
        func point(_ id: String) -> AcademyMapPoint { AcademyGeography.room(id: id)!.point }
        let centre = point("location-great-hall")
        XCTAssertLessThan(point("location-glint-hall").y, centre.y)
        XCTAssertGreaterThan(point("location-momentum-yard").x, centre.x)
        XCTAssertGreaterThan(point("location-resonance-chamber").y, centre.y)
        XCTAssertLessThan(point("location-inkworks").x, centre.x)
        XCTAssertEqual(AcademyGeography.room(id: "location-glint-hall")?.compass, .north)
        XCTAssertEqual(AcademyGeography.room(id: "location-still-room")?.compass, .center)
    }

    func testEveryPointIsOnThePaper() {
        for room in AcademyGeography.rooms {
            var points = [room.point]
            if case .drifting(let spots) = room.stability { points += spots }
            for point in points {
                XCTAssertTrue((0...1).contains(point.x) && (0...1).contains(point.y), room.id)
            }
        }
    }

    // MARK: - Surveyed walls and remembered events

    func testTheWholeAcademyHasWallsBeforeTheFirstStory() {
        let surveyed = chart()
        XCTAssertEqual(Set(surveyed.rooms.filter(\.isDrawn).map(\.id)), Set(AcademyGeography.rooms.map(\.id)))
        XCTAssertTrue(surveyed.isDrawn("location-vault-of-doors"))
        XCTAssertEqual(surveyed.room("location-vault-of-doors")?.sighting, .charted)
        XCTAssertTrue(surveyed.unseen.isEmpty)
    }

    func testAPageTheBookWroteDrawsTheRoomItNamed() {
        let chart = chart(pages: [page("p", prose: "Permancer kept the class late in the Vault of Doors.", daysAgo: 3)])
        let vault = chart.room("location-vault-of-doors")
        XCTAssertTrue(vault?.isDrawn ?? false)
        if case .namedOnAPage(let date) = vault?.sighting {
            XCTAssertEqual(date, calendar.date(byAdding: .day, value: -3, to: quietNoon))
        } else {
            XCTFail("expected the Page to have drawn it")
        }
    }

    /// The reader's own words never draw the Academy. Their pantry is theirs.
    func testTheReadersOwnPantryIsNotAnAcademyVisit() {
        let surveyed = chart(pages: [page("mine", prose: "Cleaned out the Pantry at last.", origin: .userAuthored)])
        XCTAssertEqual(surveyed.room("location-pantry")?.sighting, .charted)
        XCTAssertEqual(surveyed.room("location-pantry")?.pages, [])
    }

    func testAStorySetInARoomDrawsIt() {
        XCTAssertEqual(chart(affinities: ["location-quillquarium": 1]).room("location-quillquarium")?.sighting, .storyWentThere)
    }

    func testARoomThatRemembersSomethingIsDrawnWithIt() {
        let incident = PlaceIncident(
            id: "i", line: "Somebody left a lamp burning on the third shelf.",
            participantIDs: [], tags: [], occurredAt: quietNoon
        )
        let state = PlaceState(id: "location-still-room", incidents: [incident], refusal: "has stopped being a shortcut")
        let room = chart(placeStates: ["location-still-room": state]).room("location-still-room")
        XCTAssertEqual(room?.sighting, .somethingHappened)
        XCTAssertTrue(room?.lines.contains("It has stopped being a shortcut.") ?? false)
        XCTAssertTrue(room?.lines.contains(incident.line) ?? false)
    }

    func testTheRainRoomKeepsItsWallsButTheRealSkyOpensItsDoor() {
        for sky in [nil, SkyCondition.clear, .rain, .storm] {
            let surveyed = chart(sky: sky)
            XCTAssertTrue(surveyed.isDrawn("location-rain-room"))
            XCTAssertEqual(surveyed.closedRoomIDs.contains("location-rain-room"), sky != .rain && sky != .storm)
        }
        let named = chart(pages: [page("p", prose: "The Rain Room opened for an hour.")], sky: .clear)
        XCTAssertTrue(named.closedRoomIDs.contains("location-rain-room"))
        XCTAssertTrue(named.room("location-rain-room")?.lines.contains("The door's shut. It wants rain.") ?? false)
    }

    func testTheShelfOfMisfiledDaysMovesOvernight() {
        let shelf = AcademyGeography.room(id: "location-shelf-misfiled-days")!
        let today = AcademyGeography.point(of: shelf, on: quietNoon, calendar: calendar)
        let tomorrow = AcademyGeography.point(
            of: shelf, on: calendar.date(byAdding: .day, value: 1, to: quietNoon)!, calendar: calendar
        )
        XCTAssertNotEqual(today, tomorrow)
        let greatHall = AcademyGeography.room(id: "location-great-hall")!
        XCTAssertEqual(AcademyGeography.point(of: greatHall, on: quietNoon), greatHall.point)
    }

    /// Physical connections remain legible before a scene visits them.
    func testEveryPermanentPassageHasTwoDrawnEnds() {
        let surveyed = chart()
        XCTAssertEqual(surveyed.passages, surveyed.allPassages)
        for passage in surveyed.passages {
            XCTAssertTrue(surveyed.isDrawn(passage.from) && surveyed.isDrawn(passage.to))
        }
        XCTAssertTrue(surveyed.passages.contains { $0.touches("location-secret-garden-prose") })
    }

    // MARK: - What the Book writes beside a room

    func testTheReadersPlacesAreDoorsInTheOuterStacks() {
        let lines = chart(anchors: ["the allotment", "Nan's", "the bus stop", "the pier"])
            .room("location-outer-stacks")?.lines ?? []
        XCTAssertTrue(lines.contains("There's a door here that opens onto the allotment."))
        XCTAssertEqual(lines.filter { $0.hasPrefix("There's a door here") }.count, AcademyCartographer.anchorDoorsShown)
    }

    private func anchorRecord(_ id: String, name: String = "The little cafe") -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: 44.31, longitude: -69.78, radiusMeters: 200,
            kind: .write, belief: 10, created: "2026-09-23", weather: "clear", moon: "full",
            season: "Autumn", playerWords: "The kettle rattles.", academyEcho: "The Inkworks",
            outerStacksRoom: "A room with a kettle that rattles.", fae: "The Kettle Keeper",
            miniStory: "The kettle spoke first.", localRule: "Leave one sentence.",
            visitCount: 1, lastVisited: "2026-09-23"
        )
    }

    func testAllLedgerAnchorsDrawRoomsWithoutChangingTheCastFloorPlan() {
        let anchors = (0..<12).map { anchorRecord("anchor-\($0)") }
        let original = chart()
        let expanded = AcademyCartographer.chart(AcademyChartInputs(anchors: anchors, now: quietNoon, calendar: calendar))
        XCTAssertEqual(expanded.anchorRooms.count, 12)
        XCTAssertEqual(expanded.rooms.map(\.room), original.rooms.map(\.room))
        XCTAssertEqual(expanded.rooms.map(\.point), original.rooms.map(\.point))
        XCTAssertEqual(expanded.rooms.map(\.people), original.rooms.map(\.people))
        XCTAssertEqual(expanded.allPassages, original.allPassages)
        XCTAssertEqual(expanded.arrivals, original.arrivals)
        XCTAssertEqual(expanded.anchorRooms.first?.anchor.outerStacksRoom, anchors.first?.outerStacksRoom)
    }

    func testReturningAndAddingASameDayAnchorLeaveExistingDoorsInLedgerOrder() {
        let first = anchorRecord("z-first")
        let second = anchorRecord("a-second")
        let initial = AcademyAnchorRoom.project(anchors: [first, second], days: [])
        var returned = first
        returned.visitCount = 27
        let third = anchorRecord("0-newest")
        let expanded = AcademyAnchorRoom.project(anchors: [returned, second, third], days: [])
        XCTAssertEqual(Array(expanded.prefix(2)).map(\.id), initial.map(\.id))
        XCTAssertEqual(expanded.first?.anchor.visitCount, 27)
    }

    func testAnchorPagesFollowTheirRecordedIDNotAPlaceNameInProse() {
        let first = anchorRecord("first", name: "The Pantry")
        let second = anchorRecord("second", name: "The Pantry")
        var kept = page("kept", prose: "No place named here.", origin: .userAuthored)
        kept.context = BookPageContextSnapshot(at: kept.createdAt, calendar: calendar, nearbyAnchorID: first.id)
        let merelyNamed = page("named", prose: "The Pantry", origin: .userAuthored)
        let days = [BookDay(id: "d", date: quietNoon, pages: [kept, kept, merelyNamed])]
        let rooms = AcademyAnchorRoom.project(anchors: [first, second], days: days)
        XCTAssertEqual(rooms[0].pages.map(\.id), ["kept"])
        XCTAssertTrue(rooms[1].pages.isEmpty)
        XCTAssertNotEqual(rooms[0].id, rooms[1].id)
    }

    func testAnchorProjectionSkipsBlankAndDuplicateRecordsAndUsesGazetteerVeiling() {
        var veiled = anchorRecord("veiled", name: "My corner")
        veiled.place = AnchorPlaceIdentity(
            name: "Private business name", category: "cafe", locality: "Private town",
            latitude: veiled.latitude, longitude: veiled.longitude, matchDistanceMeters: 10,
            usesRealNameInStory: false
        )
        let rooms = AcademyAnchorRoom.project(anchors: [veiled, veiled, anchorRecord("blank", name: "")], days: [])
        XCTAssertEqual(rooms.count, 1)
        XCTAssertEqual(rooms[0].entry.name, "My corner")
        XCTAssertEqual(rooms[0].entry.plate?.isLoosened, true)
        XCTAssertFalse(rooms[0].entry.kindLine?.contains("Private") ?? false)
    }

    func testFoldedWordsUseOnlyReaderSentenceAtomsFromAMixedPage() {
        let anchor = anchorRecord("here")
        var mixed = page("mixed", prose: "The Book invented a silver river.")
        mixed.userInput = "The Book invented a silver river.\nReader: The kettle is louder than the rain."
        mixed.context = BookPageContextSnapshot(at: mixed.createdAt, calendar: calendar, nearbyAnchorID: anchor.id)
        let room = AcademyAnchorRoom.project(anchors: [anchor], days: [BookDay(id: "d", date: quietNoon, pages: [mixed])])[0]
        XCTAssertEqual(room.foldedWords?.text, "The kettle is louder than the rain.")
        XCTAssertEqual(room.foldedWords?.page?.id, mixed.id)
    }

    func testBookOnlyPagesCannotHideAnOlderReaderSentenceBehindThePageLimit() {
        let anchor = anchorRecord("here")
        var reader = page("reader", prose: "", origin: .userAuthored, daysAgo: 12)
        reader.userInput = "The cup was chipped. I liked it."
        reader.context = BookPageContextSnapshot(at: reader.createdAt, calendar: calendar, nearbyAnchorID: anchor.id)
        let generated = (0..<8).map { index -> BookPage in
            var p = page("book-\(index)", prose: "A wholly fictional cup.", daysAgo: index)
            p.userInput = "A wholly fictional cup."
            p.context = BookPageContextSnapshot(at: p.createdAt, calendar: calendar, nearbyAnchorID: anchor.id)
            return p
        }
        let room = AcademyAnchorRoom.project(anchors: [anchor], days: [BookDay(id: "d", date: quietNoon, pages: generated + [reader])])[0]
        XCTAssertEqual(room.pages.count, AcademyCartographer.pagesShown)
        XCTAssertFalse(room.pages.contains(where: { $0.id == reader.id }))
        XCTAssertEqual(room.foldedWords?.text, reader.userInput)
        XCTAssertEqual(room.foldedWords?.page?.id, reader.id)
    }

    func testFoldedWordsFallBackToActualAnchoringWordsAndNeverInventAnEmptyMemory() {
        let anchor = anchorRecord("words")
        var empty = anchorRecord("empty")
        empty.playerWords = " \n "
        let rooms = AcademyAnchorRoom.project(anchors: [anchor, empty], days: [])
        XCTAssertEqual(rooms[0].foldedWords?.text, anchor.playerWords)
        XCTAssertNil(rooms[0].foldedWords?.page)
        XCTAssertNil(rooms[1].foldedWords)
    }

    func testBookProseAndAChosenFictionPathNeverBecomeAReaderSentence() {
        var anchor = anchorRecord("empty")
        anchor.playerWords = ""
        var book = page("book", prose: "A fictional bridge.")
        book.userInput = "A fictional bridge.\nChosen path: Cross the silver bridge"
        book.context = BookPageContextSnapshot(at: book.createdAt, calendar: calendar, nearbyAnchorID: anchor.id)
        let room = AcademyAnchorRoom.project(anchors: [anchor], days: [BookDay(id: "d", date: quietNoon, pages: [book])])[0]
        XCTAssertFalse(book.readerFictionChoices.isEmpty)
        XCTAssertNil(room.foldedWords)
        XCTAssertEqual(room.pages.map(\.id), [book.id])
    }

    func testRoomImprintsPreferReaderWordsAndMatchWholeWords() {
        var anchor = anchorRecord("motif", name: "My corner")
        anchor.playerWords = "The river curled under the bridge."
        XCTAssertEqual(AcademyAnchorImprint.from(anchor), AcademyAnchorImprint(motif: .water, source: .reader))
        anchor.playerWords = "Facebook seashore starling"
        anchor.outerStacksRoom = "A room full of books."
        XCTAssertEqual(AcademyAnchorImprint.from(anchor), AcademyAnchorImprint(motif: .library, source: .book))
        anchor.outerStacksRoom = "A room with a door."
        XCTAssertEqual(AcademyAnchorImprint.from(anchor), AcademyAnchorImprint(motif: .threshold, source: .spell))
        anchor.playerWords = "A CAFÉ with good coffee."
        XCTAssertEqual(AcademyAnchorImprint.from(anchor).motif, .hearth)
    }

    func testRoomImprintsUsePlaceCategoryWithoutMiningItsVeiledNameOrLocality() {
        var anchor = anchorRecord("private", name: "My corner")
        anchor.playerWords = "I sat here."
        anchor.outerStacksRoom = "A room with a door."
        anchor.place = AnchorPlaceIdentity(
            name: "River Library", category: "bakery", locality: "Forest Park",
            latitude: anchor.latitude, longitude: anchor.longitude, matchDistanceMeters: 10,
            usesRealNameInStory: false
        )
        XCTAssertEqual(AcademyAnchorImprint.from(anchor), AcademyAnchorImprint(motif: .hearth, source: .place))
        anchor.place?.category = "shop"
        XCTAssertEqual(AcademyAnchorImprint.from(anchor), AcademyAnchorImprint(motif: .threshold, source: .spell))
    }

    func testRoomDustFollowsRecordedCheckInsAndClearsOnReturn() {
        var anchor = anchorRecord("quiet")
        anchor.lastVisited = "2026-07-01"
        let quiet = AcademyAnchorRoom.project(anchors: [anchor], days: [], now: quietNoon, calendar: calendar)[0]
        XCTAssertNotNil(quiet.quietDays)
        XCTAssertGreaterThanOrEqual(quiet.quietDays ?? 0, Gazetteer.goneQuietDays)
        anchor.lastVisited = "2026-09-23"
        XCTAssertNil(AcademyAnchorRoom.project(anchors: [anchor], days: [], now: quietNoon, calendar: calendar)[0].quietDays)
        anchor.lastVisited = "2026-10-01"
        XCTAssertNil(AcademyAnchorRoom.project(anchors: [anchor], days: [], now: quietNoon, calendar: calendar)[0].quietDays)
        anchor.lastVisited = "not a date"
        XCTAssertNil(AcademyAnchorRoom.project(anchors: [anchor], days: [], now: quietNoon, calendar: calendar)[0].quietDays)
    }

    func testARoomWithAClassOnSaysWhosTeaching() {
        // Monday, half nine: the Art of the Glint, with Boggle.
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 9, minute: 30))!
        let lines = chart(affinities: ["location-glint-hall": 1], now: monday).room("location-glint-hall")?.lines ?? []
        XCTAssertTrue(lines.contains("Boggle's teaching The Art of the Glint in here right now."), "\(lines)")
    }

    func testASurveyedRoomHasItsNoteWithoutInventingAVisit() {
        let vault = chart().room("location-vault-of-doors")
        XCTAssertEqual(vault?.sighting, .charted)
        XCTAssertEqual(vault?.lines.first, AcademyGeography.room(id: "location-vault-of-doors")?.note)
        XCTAssertEqual(vault?.pages, [])
    }

    /// The Book contracts. Nothing on its map talks like a form.
    func testTheNotesSoundLikeTheBook() {
        let stiff = [" it is ", " i am ", " do not ", " does not ", " is not ", " there is ", " that is ", " i have ", " has been "]
        for room in AcademyGeography.rooms {
            let note = " " + room.note.lowercased() + " "
            for phrase in stiff {
                XCTAssertFalse(note.contains(phrase), "\(room.id): \(phrase)")
            }
            XCTAssertFalse(room.note.isEmpty, room.id)
        }
        let surveyed = chart()
        XCTAssertEqual(surveyed.footer, "\(surveyed.drawnCount) rooms. \(surveyed.rooms.flatMap(\.people).count) names. The walls stay. The feet don't.")
    }

    func testWaysOutNameTheActualNeighbouringRooms() {
        let chart = chart()
        XCTAssertEqual(
            chart.waysOut(from: "location-kitchens"),
            "From here you can get to the Great Hall, the Pantry and the Book Burrow."
        )
        XCTAssertEqual(chart.waysOut(from: AcademyGeography.dormID), "From here you can get to the Book Burrow.")
    }

    /// A surveyed secret door stays part of the physical geography.
    func testTheSurveyIncludesTheGardenAndItsHiddenDoor() {
        let surveyed = chart()
        XCTAssertTrue(surveyed.waysOut(from: "location-walled-garden")?.contains("the Secret Garden of Prose") ?? false)
        XCTAssertTrue(surveyed.waysOut(from: "location-walled-garden")?.contains("the Open Field Gate") ?? false)
    }

    // MARK: - The Stacks

    func testTheBookBurrowHasAWayIntoTheStacks() {
        XCTAssertTrue(AcademyGeography.passages.contains {
            $0.touches("location-book-burrow") && $0.touches("location-stacks")
        })
        XCTAssertTrue(chart().waysOut(from: "location-book-burrow")?.contains("the Stacks") ?? false)
    }

    // MARK: - Who's where

    private func at(weekday day: Int, hour: Int, minute: Int = 0) -> Date {
        // 2026-09-20 is a Sunday; Calendar weekday 1.
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 19 + day, hour: hour, minute: minute))!
    }

    func testEveryHauntIsARealCastMemberInRealRooms() {
        let cast = Set(NarrativePackRegistry.bundledPacks.flatMap(\.entities).filter { $0.kind == .character }.map(\.id))
        var seen: Set<String> = []
        for haunt in AcademyWhereabouts.haunts {
            XCTAssertTrue(cast.contains(haunt.characterID), haunt.characterID)
            XCTAssertTrue(seen.insert(haunt.characterID).inserted, "twice: \(haunt.characterID)")
            XCTAssertFalse(haunt.day.isEmpty, haunt.characterID)
            for room in haunt.day + haunt.evening + haunt.night {
                XCTAssertNotNil(AcademyGeography.room(id: room), "\(haunt.characterID) → \(room)")
            }
        }
    }

    /// The Dorm is the reader's. Nobody else is ever in it, at any hour.
    func testNobodyIsEverInTheReadersRoom() {
        for hour in 0..<24 {
            for day in 1...7 {
                let here = AcademyWhereabouts.everyone(at: at(weekday: day, hour: hour), calendar: calendar)
                XCTAssertFalse(here.contains { $0.roomID == AcademyGeography.dormID }, "day \(day) \(hour):00")
            }
        }
    }

    /// Canon: Wicker's banned from the North Staircase.
    func testWickerIsNeverOnTheNorthStaircase() {
        for hour in 0..<24 {
            for day in 1...7 {
                let wicker = AcademyWhereabouts.everyone(at: at(weekday: day, hour: hour), calendar: calendar)
                    .first { $0.characterID == "wicker-eddies" }
                XCTAssertNotEqual(wicker?.roomID, "location-north-staircase")
            }
        }
    }

    func testTheTimetableBeatsHabit() {
        // Monday, half nine: the Art of the Glint. Boggle teaches, Zara's in it.
        let everyone = AcademyWhereabouts.everyone(at: at(weekday: 2, hour: 9, minute: 30), calendar: calendar)
        let boggle = everyone.first { $0.characterID == "lydia-boggle" }
        XCTAssertEqual(boggle?.roomID, "location-glint-hall")
        XCTAssertEqual(boggle?.why, .teaching)
        let zara = everyone.first { $0.characterID == "zara-finch" }
        XCTAssertEqual(zara?.roomID, "location-glint-hall")
        XCTAssertEqual(zara?.why, .attending)
    }

    func testTheWholeCastHasAnAddressAtNight() {
        let night = AcademyWhereabouts.everyone(at: at(weekday: 3, hour: 3), calendar: calendar)
        let roster = NarrativePackRegistry.entities.filter { $0.kind == .character }
        XCTAssertEqual(Set(night.map(\.characterID)), Set(roster.map(\.id)))
        let zara = whereIs("zara-finch", in: night)
        XCTAssertEqual(zara?.roomID, AcademyGeography.dormitoriesID("riddlewind"))
        XCTAssertEqual(zara?.why, .sleeping)
        if let zara { XCTAssertEqual(AcademyMotion.of(zara), .stationary) }
        XCTAssertEqual(whereIs("headmistress-thorne", in: night)?.roomID, "location-headmistress-tower")
        XCTAssertEqual(whereIs("penny-blackletter", in: night)?.roomID, "location-stacks")
        XCTAssertEqual(whereIs("ambrose-trencher", in: night)?.roomID, AcademyGeography.facultyID, "staff do not become Chapter pupils")
    }

    func testTheSameHourPutsEveryoneInTheSamePlace() {
        let one = AcademyWhereabouts.everyone(at: at(weekday: 4, hour: 14), calendar: calendar)
        let again = AcademyWhereabouts.everyone(at: at(weekday: 4, hour: 14, minute: 40), calendar: calendar)
        XCTAssertEqual(one, again)
    }

    func testPeopleOnlyShowInRoomsTheBookHasDrawn() {
        let chart = chart(now: at(weekday: 4, hour: 14))
        for room in chart.rooms where !room.isDrawn {
            XCTAssertTrue(room.people.isEmpty, room.id)
        }
        let placed = chart.rooms.flatMap(\.people).count + chart.unseen.count
        XCTAssertEqual(placed, AcademyWhereabouts.everyone(at: at(weekday: 4, hour: 14), calendar: calendar).count)
    }

    func testTheNoteSaysWhosInTheRoom() {
        XCTAssertEqual(AcademyCartographer.whosHere([]), [])
        let penny = AcademyWhereabout(characterID: "penny-blackletter", name: "Penny Blackletter",
                                      mapName: "Penny", roomID: "location-stacks", why: .haunt)
        var wicker = penny
        wicker.characterID = "wicker-eddies"
        wicker.mapName = "Wicker"
        XCTAssertEqual(AcademyCartographer.whosHere([penny]), ["Penny's in here right now."])
        XCTAssertEqual(AcademyCartographer.whosHere([penny, wicker]), ["Penny and Wicker are in here right now."])
        var eating = penny
        eating.why = .eating
        XCTAssertEqual(AcademyCartographer.whosHere([eating], hour: 12), ["Penny's having lunch in here."])
        var scene = wicker
        scene.why = .scene
        XCTAssertEqual(AcademyCartographer.whosHere([scene]), ["Wicker's here because of today's Page."])
        var staged = penny
        staged.why = .staged
        staged.note = "Penny's sorting the East Stacks' post and won't say why."
        XCTAssertEqual(AcademyCartographer.whosHere([staged]), [staged.note!])

        // A crowd isn't a register.
        let crowd = (0..<9).map { index -> AcademyWhereabout in
            var person = penny
            person.characterID = "p\(index)"
            person.mapName = "P\(index)"
            person.why = .eating
            return person
        }
        XCTAssertEqual(AcademyCartographer.whosHere(crowd, hour: 12), ["P0, P1, P2 and 6 others are having lunch in here."])
    }

    func testTheUnseenLine() {
        var chart = AcademyChart(rooms: [], passages: [])
        XCTAssertNil(chart.unseenLine)
        chart.unseen = [AcademyWhereabout(characterID: "wicker-eddies", name: "Wicker Eddies",
                                          mapName: "Wicker", roomID: "location-vault-of-doors", why: .haunt)]
        XCTAssertEqual(chart.unseenLine, "Wicker's somewhere I haven't drawn yet.")
    }

    // MARK: - A complete inhabited school

    func testEveryRegisteredCharacterHasExactlyOneVisibleAddressEveryHourOfTheWeek() {
        let roster = NarrativePackRegistry.entities.filter { $0.kind == .character }
        let expected = Set(roster.map(\.id))
        for day in 1...7 {
            for hour in 0..<24 {
                let surveyed = chart(now: at(weekday: day, hour: hour))
                let people = surveyed.rooms.flatMap(\.people)
                XCTAssertEqual(Set(people.map(\.characterID)), expected, "day \(day), hour \(hour)")
                XCTAssertEqual(people.count, expected.count, "no duplicate feet")
                XCTAssertTrue(surveyed.unseen.isEmpty)
                XCTAssertFalse(people.contains { $0.roomID == AcademyGeography.dormID })
                XCTAssertFalse(people.contains { surveyed.closedRoomIDs.contains($0.roomID) })
            }
        }
    }

    func testEveryChapterHasACommonRoomAndDormitoryStair() {
        XCTAssertEqual(AcademyChapterRegistry.chapters.count, 5)
        for chapter in AcademyChapterRegistry.chapters {
            let common = AcademyGeography.commonRoomID(chapter.id)
            let dorms = AcademyGeography.dormitoriesID(chapter.id)
            XCTAssertNotNil(AcademyGeography.room(id: common))
            XCTAssertNotNil(AcademyGeography.room(id: dorms))
            XCTAssertTrue(AcademyGeography.passages.contains { $0.touches("location-book-burrow") && $0.touches(common) })
            XCTAssertTrue(AcademyGeography.passages.contains { $0.touches(common) && $0.touches(dorms) && $0.kind == .stair })
        }
    }

    func testMyDormJoinsOnlyTheBoundReadersChapter() {
        for chapter in AcademyChapterRegistry.chapters {
            let inputs = AcademyChartInputs(now: quietNoon, calendar: calendar, readerChapterID: chapter.id)
            let surveyed = AcademyCartographer.chart(inputs)
            let home = surveyed.room(AcademyGeography.dormID)
            let dorms = surveyed.room(AcademyGeography.dormitoriesID(chapter.id))!
            XCTAssertEqual(home?.room.name, "My Dorm")
            XCTAssertEqual(home?.point.x, dorms.point.x)
            let doors = surveyed.allPassages.filter { $0.touches(AcademyGeography.dormID) }
            XCTAssertEqual(doors.count, 1)
            XCTAssertTrue(doors[0].touches(dorms.id))
            XCTAssertTrue(home?.people.isEmpty ?? false)
            XCTAssertNotNil(AcademyRoute.rooms(from: AcademyGeography.dormID, to: "location-great-hall", passages: surveyed.allPassages))
        }
        XCTAssertEqual(AcademyGeography.homeRoom(chapterID: nil), AcademyGeography.homeRoom(chapterID: "unknown"))
        XCTAssertEqual(AcademyGeography.homePassages(chapterID: nil), AcademyGeography.homePassages(chapterID: "unknown"))
    }

    func testACustomCharacterLivesInTheAcademyAndItsSceneBeatsBedtime() {
        let custom = NarrativeWorldEntity(id: "custom-lark", packID: "reader", name: "Lark Underleaf", kind: .character,
                                          belief: 10, narrativeWeight: 10, chapter: "Mossbloom")
        let now = at(weekday: 4, hour: 23)
        let inputs = AcademyChartInputs(now: now, calendar: calendar, cast: [custom, custom])
        let sleeping = AcademyCartographer.chart(inputs).rooms.flatMap(\.people)
        XCTAssertEqual(sleeping.count, 1)
        XCTAssertEqual(sleeping.first?.roomID, AcademyGeography.dormitoriesID("mossbloom"))
        XCTAssertEqual(sleeping.first?.why, .sleeping)
        XCTAssertEqual(sleeping.first?.isVisitor, false)
        var awake = inputs
        awake.deskScenes = [AcademyScene(roomID: "location-vault-of-doors", castIDs: [custom.id], at: now)]
        let scene = AcademyCartographer.chart(awake).rooms.flatMap(\.people).first
        XCTAssertEqual(scene?.roomID, "location-vault-of-doors")
        XCTAssertEqual(scene?.why, .scene)
    }

    func testKeptMetadataMovesCustomCastAndScenesCanUseBorrowedRooms() {
        let custom = NarrativeWorldEntity(id: "custom-lark", packID: "reader", name: "Lark Underleaf", kind: .character,
                                          belief: 10, narrativeWeight: 10, chapter: "Mossbloom")
        let now = at(weekday: 4, hour: 23)
        var kept = page("lark-page", prose: "The lamp fell over.", daysAgo: 0)
        kept.createdAt = now.addingTimeInterval(-1800)
        kept.metadata = [AcademyScene.roomKey: "location-inkworks", AcademyScene.castKey: custom.id]
        let inputs = AcademyChartInputs(days: [BookDay(id: "d", date: now, pages: [kept])],
                                        now: now, calendar: calendar, cast: [custom])
        let scene = AcademyCartographer.chart(inputs).rooms.flatMap(\.people).first
        XCTAssertEqual(scene?.roomID, "location-inkworks")
        XCTAssertEqual(scene?.why, .scene)
        var borrowed = AcademyGeography.room(id: "location-great-hall")!
        borrowed.id = "borrowed-lark-room"
        borrowed.isBorrowed = true
        let metadata = [AcademyScene.roomKey: borrowed.id, AcademyScene.castKey: custom.id]
        XCTAssertNil(AcademyScene(metadata: metadata, at: now, cast: [custom]))
        XCTAssertEqual(AcademyScene(metadata: metadata, at: now, cast: [custom], rooms: [borrowed])?.castIDs, [custom.id])
    }

    func testNewFacultyAndUnplacedGuestsHaveNightAddresses() {
        let professor = NarrativeWorldEntity(id: "new-professor", packID: "new", name: "Professor Lantern", kind: .character,
                                             belief: 10, narrativeWeight: 10, chapter: "Tidecrest", tags: ["faculty"])
        let guest = NarrativeWorldEntity(id: "new-guest", packID: "new", name: "A Visitor", kind: .character,
                                        belief: 10, narrativeWeight: 10, chapter: "An Unknown Chapter")
        let people = AcademyWhereabouts.everyone(at: at(weekday: 5, hour: 3), calendar: calendar, cast: [professor, guest])
        XCTAssertEqual(whereIs(professor.id, in: people)?.roomID, AcademyGeography.facultyID)
        XCTAssertEqual(whereIs(guest.id, in: people)?.roomID, AcademyGeography.guestID)
        XCTAssertTrue(people.allSatisfy { $0.why == .sleeping && !$0.isVisitor })
    }

    func testAnInvalidOrShutStoryAddressCannotLoseACharacter() {
        let now = at(weekday: 4, hour: 23)
        for room in ["no-such-room", "location-vault-of-doors", AcademyGeography.dormID] {
            var inputs = AcademyChartInputs(now: now, calendar: calendar)
            inputs.events.closedRoomIDs = ["location-vault-of-doors"]
            inputs.events.staging = [AcademyStaging(castID: "zara-finch", roomID: room)]
            inputs.deskScenes = [AcademyScene(roomID: room, castIDs: ["zara-finch"], at: now)]
            let surveyed = AcademyCartographer.chart(inputs)
            XCTAssertEqual(person("zara-finch", in: surveyed)?.roomID, AcademyGeography.dormitoriesID("riddlewind"))
            XCTAssertTrue(surveyed.unseen.isEmpty)
        }
    }

    func testEveningStudentsReturnToTheirChapterCommonRooms() {
        let roster = NarrativePackRegistry.entities.filter { $0.kind == .character }
        let everyone = AcademyWhereabouts.everyone(at: at(weekday: 4, hour: 21), calendar: calendar)
        for entity in roster where AcademyWhereabouts.residence(for: entity).hasPrefix("location-dorms-") {
            let chapter = AcademyChapterRegistry.chapter(named: entity.chapter)!
            XCTAssertEqual(whereIs(entity.id, in: everyone)?.roomID, AcademyGeography.commonRoomID(chapter.id), entity.id)
        }
    }

    func testBorrowedRoomsFindFreePaperWithoutLosingTheirConnections() throws {
        let event = try countUnbound()
        let surveyed = octoberChart(10, 26, 15, event: event)
        let borrowed = surveyed.rooms.filter { $0.room.isBorrowed }
        XCTAssertEqual(borrowed.count, 2)
        for room in borrowed {
            XCTAssertTrue(surveyed.allPassages.contains { $0.touches(room.id) })
            for other in surveyed.rooms where other.id != room.id && other.room.form != .ring {
                let overlaps = abs(room.point.x - other.point.x) < (room.room.size.x + other.room.size.x) / 2
                    && abs(room.point.y - other.point.y) < (room.room.size.y + other.room.size.y) / 2
                XCTAssertFalse(overlaps, "\(room.id) overlaps \(other.id)")
            }
        }
        XCTAssertEqual(person("professor-permancer", in: surveyed)?.roomID, "borrowed-wrong-castle")
        let ballroom = surveyed.room("borrowed-ballroom")!
        let hall = surveyed.room("location-great-hall")!
        XCTAssertLessThan(abs(ballroom.point.y - hall.point.y), 0.15, "the borrowed supper hall belongs beside the tables")
        XCTAssertLessThan(abs(ballroom.point.x - hall.point.x), 0.16)
        XCTAssertTrue(surveyed.unseen.isEmpty)
    }

    // MARK: - Pages about a room

    func testARoomLinksThePagesThatMentionIt() {
        let pages = (0..<7).map { page("p\($0)", prose: "Something rattled in the Great Hall.", daysAgo: $0 + 1) }
        let hall = chart(pages: pages).room("location-great-hall")
        XCTAssertEqual(hall?.pages.count, AcademyCartographer.pagesShown)
        XCTAssertEqual(hall?.pages.first?.id, "p0", "newest first")
    }

    /// Generated Pages often keep the Book's prose in `userInput`.
    func testTheBooksProseInUserInputCountsToo() {
        let story = BookPage(
            id: "story", type: .note, createdAt: quietNoon, promptText: "",
            userInput: "Serenity found the Spark Annex door unlocked.", origin: .generated
        )
        XCTAssertEqual(chart(pages: [story]).room("location-spark-annex")?.pages.map(\.id), ["story"])
    }

    // MARK: - The living map

    private func whereIs(_ id: String, in everyone: [AcademyWhereabout]) -> AcademyWhereabout? {
        everyone.first { $0.characterID == id }
    }

    func testAStoryPagesMetadataIsAScene() {
        let scene = AcademyScene(metadata: [
            "storySettingID": "location-kitchens",
            "selectedEntityIDs": "serenity-brown,location-kitchens,somebody-invented,penny-blackletter"
        ], at: quietNoon)
        XCTAssertEqual(scene?.roomID, "location-kitchens")
        XCTAssertEqual(scene?.castIDs, ["serenity-brown", "penny-blackletter"])
    }

    func testTheExplicitKeysWin() {
        let scene = AcademyScene(metadata: [
            AcademyScene.roomKey: "location-vault-of-doors",
            AcademyScene.castKey: "wicker-eddies",
            "storySettingID": "location-kitchens",
            "selectedEntityIDs": "serenity-brown"
        ], at: quietNoon)
        XCTAssertEqual(scene?.roomID, "location-vault-of-doors")
        XCTAssertEqual(scene?.castIDs, ["wicker-eddies"])
    }

    func testAClassPageIsASceneInItsRoom() {
        let scene = AcademyScene(metadata: [
            "sessionRoom": "Wing 4: The Glint Hall",
            "sessionLeaderEntityID": "lydia-boggle",
            "sessionCompanions": "Zara Finch, Aria Silverthorn"
        ], at: quietNoon)
        XCTAssertEqual(scene?.roomID, "location-glint-hall")
        XCTAssertEqual(Set(scene?.castIDs ?? []), ["lydia-boggle", "zara-finch"])
    }

    func testMetadataWithNoRoomOrNobodyIsNoScene() {
        XCTAssertNil(AcademyScene(metadata: ["selectedEntityIDs": "serenity-brown"], at: quietNoon))
        XCTAssertNil(AcademyScene(metadata: ["storySettingID": "location-kitchens"], at: quietNoon))
        XCTAssertNil(AcademyScene(metadata: ["storySettingID": "somewhere-else", "actorID": "serenity-brown"], at: quietNoon))
    }

    /// The point of keeping metadata: a kept Page still knows where it happened.
    func testAKeptPageKeepsItsMetadata() throws {
        var kept = page("kept", prose: "Serenity burned the toast.")
        kept.metadata = ["storySettingID": "location-kitchens", "selectedEntityIDs": "serenity-brown"]
        let decoded = try JSONDecoder().decode(BookPage.self, from: JSONEncoder().encode(kept))
        XCTAssertEqual(decoded.metadata, kept.metadata)
        XCTAssertEqual(decoded.academyScene?.roomID, "location-kitchens")

        // Pages kept before this carried nothing, and still open.
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(kept)) as! [String: Any]
        old.removeValue(forKey: "metadata")
        let legacy = try JSONDecoder().decode(BookPage.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(legacy.metadata)
        XCTAssertNil(legacy.academyScene)
    }

    func testAPageKeptThisMorningMovesPeopleUntilItWearsOff() {
        var kept = page("kept", prose: "", daysAgo: 0)
        kept.createdAt = at(weekday: 4, hour: 10)
        kept.metadata = ["storySettingID": "location-kitchens", "selectedEntityIDs": "wicker-eddies"]
        func wicker(at hour: Int) -> AcademyWhereabout? {
            chart(pages: [kept], now: at(weekday: 4, hour: hour)).rooms
                .flatMap(\.people).first { $0.characterID == "wicker-eddies" }
        }
        XCTAssertEqual(wicker(at: 11)?.roomID, "location-kitchens")
        XCTAssertEqual(wicker(at: 11)?.why, .scene)
        XCTAssertNotEqual(wicker(at: 14)?.why, .scene)
    }

    func testTheStoryBeatsTheTimetable() {
        // Monday, half nine, Boggle should be teaching. The desk says otherwise.
        let now = at(weekday: 2, hour: 9, minute: 30)
        let desk = AcademyScene(roomID: "location-vault-of-doors", castIDs: ["lydia-boggle"], at: now)
        let boggle = whereIs("lydia-boggle", in: AcademyWhereabouts.everyone(at: now, calendar: calendar, scenes: [desk]))
        XCTAssertEqual(boggle?.roomID, "location-vault-of-doors")
        XCTAssertEqual(boggle?.why, .scene)
    }

    func testTheMonthsStagingBeatsEverything() {
        let now = at(weekday: 2, hour: 9, minute: 30)
        var staging = AcademyEventStaging()
        staging.staging = [AcademyStaging(castID: "serenity-brown", roomID: "location-kitchens", note: "Serenity's awake.")]
        let desk = AcademyScene(roomID: "location-quillquarium", castIDs: ["serenity-brown"], at: now)
        let serenity = whereIs("serenity-brown", in: AcademyWhereabouts.everyone(
            at: now, calendar: calendar, scenes: [desk], staging: staging
        ))
        XCTAssertEqual(serenity?.roomID, "location-kitchens")
        XCTAssertEqual(serenity?.why, .staged)
        XCTAssertEqual(serenity?.note, "Serenity's awake.")
    }

    /// Not even the story puts somebody in the reader's room.
    func testTheStoryCantPutAnyoneInTheDorm() {
        var staging = AcademyEventStaging()
        staging.staging = [AcademyStaging(castID: "wicker-eddies", roomID: AcademyGeography.dormID)]
        let everyone = AcademyWhereabouts.everyone(at: at(weekday: 4, hour: 14), calendar: calendar, staging: staging)
        XCTAssertNotEqual(whereIs("wicker-eddies", in: everyone)?.roomID, AcademyGeography.dormID)
    }

    func testEverybodyEatsAtMealtimes() {
        let lunch = AcademyWhereabouts.everyone(at: at(weekday: 4, hour: 12, minute: 15), calendar: calendar)
        XCTAssertEqual(whereIs("serenity-brown", in: lunch)?.roomID, "location-great-hall")
        XCTAssertEqual(whereIs("serenity-brown", in: lunch)?.why, .eating)
        XCTAssertEqual(whereIs("ambrose-trencher", in: lunch)?.roomID, "location-kitchens")
        XCTAssertNotEqual(whereIs("ambrose-trencher", in: lunch)?.why, .eating, "he's cooking it")
        XCTAssertNotEqual(whereIs("penny-blackletter", in: lunch)?.why, .eating, "Penny doesn't stop")
    }

    func testPeopleMoveThroughTheDay() {
        let hours = [8, 10, 14, 16, 20]
        var rooms: Set<String> = []
        for hour in hours {
            for id in ["soren-ng", "serenity-brown", "wicker-eddies"] {
                if let room = whereIs(id, in: AcademyWhereabouts.everyone(at: at(weekday: 4, hour: hour), calendar: calendar))?.roomID {
                    rooms.insert("\(id)|\(room)")
                }
            }
        }
        XCTAssertGreaterThan(rooms.count, 5, "three people over five hours ought to have been more than a couple of places")
    }

    func testAShutRoomEmptiesAndItsClassMoves() {
        var staging = AcademyEventStaging()
        staging.closedRoomIDs = ["location-glint-hall", "location-east-stacks", "location-vault-of-doors"]
        for hour in 0..<24 {
            let everyone = AcademyWhereabouts.everyone(at: at(weekday: 3, hour: hour), calendar: calendar, staging: staging)
            XCTAssertFalse(everyone.contains { staging.closedRoomIDs.contains($0.roomID) }, "\(hour):00")
        }
        // Monday's Art of the Glint happens in the Great Hall instead.
        let monday = AcademyWhereabouts.everyone(at: at(weekday: 2, hour: 9, minute: 30), calendar: calendar, staging: staging)
        XCTAssertEqual(whereIs("lydia-boggle", in: monday)?.roomID, "location-great-hall")
        XCTAssertEqual(whereIs("lydia-boggle", in: monday)?.why, .teaching)
    }

    func testClosingHabitAndSupperRoomsDoesNotMakePeopleDisappear() {
        var staging = AcademyEventStaging()
        staging.closedRoomIDs = Set(AcademyWhereabouts.haunts.flatMap { $0.day + $0.evening + $0.night })
            .union(["location-great-hall", AcademyGeography.facultyID])
        let roster = NarrativePackRegistry.entities.filter { $0.kind == .character }
        for hour in [3, 12, 21] {
            let everyone = AcademyWhereabouts.everyone(at: at(weekday: 4, hour: hour), calendar: calendar,
                                                       staging: staging, cast: roster)
            XCTAssertEqual(Set(everyone.map(\.characterID)), Set(roster.map(\.id)))
            XCTAssertFalse(everyone.contains { staging.closedRoomIDs.contains($0.roomID) })
            XCTAssertFalse(everyone.contains { $0.roomID == AcademyGeography.dormID })
        }
    }

    func testAShutRoomSaysSo() {
        var inputs = AcademyChartInputs(storySettingAffinities: ["location-east-stacks": 1], now: quietNoon, calendar: calendar)
        inputs.events.closedRoomIDs = ["location-east-stacks"]
        let chart = AcademyCartographer.chart(inputs)
        XCTAssertTrue(chart.room("location-east-stacks")?.lines.contains("It's shut. Nobody's allowed in.") ?? false)
        XCTAssertEqual(chart.closedRoomIDs, ["location-east-stacks", "location-rain-room"])
    }

    /// October's real pack, with staging written into it the way an author would.
    func testAMonthlyEventStagesTheAcademyByPhaseAndBeat() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")
        var event = try XCTUnwrap(JSONDecoder().decode(WorldEventPack.self, from: Data(contentsOf: url)).events.first)
        let uninvited = try XCTUnwrap(event.phases.firstIndex { $0.id == "uninvited" })
        event.phases[uninvited].staging = [AcademyStaging(castID: "serenity-brown", roomID: "location-kitchens", note: "Serenity's awake in here.")]
        event.phases[uninvited].closedRoomIDs = ["location-east-stacks"]
        var beat = try XCTUnwrap(event.beats?.first { $0.phaseID == "uninvited" })
        beat.roomID = "location-great-hall"
        beat.castIDs = ["professor-permancer"]
        beat.lifecycleStage = nil
        event.beats = [beat]

        let start = try XCTUnwrap(event.calendar.interval(containing: calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!, calendar: calendar)).start
        let onBeatDay = calendar.date(byAdding: .day, value: beat.opensOnDay, to: start)!.addingTimeInterval(10 * 3600)
        let staging = AcademyEventStaging.from(events: [event], now: onBeatDay, calendar: calendar)
        let inUninvited = calendar.date(byAdding: .day, value: 10, to: start)!
        let phaseStaging = AcademyEventStaging.from(events: [event], now: inUninvited, calendar: calendar)
        XCTAssertEqual(phaseStaging.staging.first?.roomID, "location-kitchens")
        XCTAssertEqual(phaseStaging.closedRoomIDs, ["location-east-stacks"])
        // An open beat doesn't pin anybody for its whole window; its Page does.
        XCTAssertTrue(staging.scenes.isEmpty)

        // Before the phase, nothing's staged.
        let early = AcademyEventStaging.from(events: [event], now: start.addingTimeInterval(3600), calendar: calendar)
        XCTAssertTrue(early.staging.isEmpty)
    }

    /// A beat that names a room puts it on its Page, so the Page still knows
    /// where it happened once it's kept.
    func testABeatWithARoomStampsItsPage() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")
        let event = try XCTUnwrap(JSONDecoder().decode(WorldEventPack.self, from: Data(contentsOf: url)).events.first)
        let beat = WorldEventBeat(
            id: "b", phaseID: "uninvited", role: .buildup, opensOnDay: 0, expiresAfterDay: 3,
            title: "Something at supper", body: "A stair came up through the tables.", report: "A stair came up.",
            roomID: "location-great-hall", castIDs: ["serenity-brown", "wicker-eddies"]
        )
        let snapshot = WorldEventLifecycleSnapshot(
            eventID: event.id, packID: "count-unbound", runID: "run", stage: .live,
            phaseID: "uninvited", phaseRole: .buildup, liveDay: 1,
            liveInterval: DateInterval(start: quietNoon, duration: 86_400 * 31),
            foreshadowStartsAt: quietNoon, residueEndsAt: quietNoon,
            participated: false
        )
        let surface = WorldEventPageSourceAdapter.beatSurface(
            event: event, beat: beat, snapshot: snapshot, day: BookDay(id: "d", date: quietNoon, pages: [])
        )
        let scene = AcademyScene(metadata: surface.payload.metadata, at: quietNoon)
        XCTAssertEqual(scene?.roomID, "location-great-hall")
        XCTAssertEqual(scene?.castIDs, ["serenity-brown", "wicker-eddies"])
    }

    // MARK: - The Count Unbound, all the way through

    private func countUnbound() throws -> WorldEvent {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")
        return try XCTUnwrap(JSONDecoder().decode(WorldEventPack.self, from: Data(contentsOf: url)).events.first)
    }

    private func octoberChart(_ month: Int, _ day: Int, _ hour: Int, event: WorldEvent) -> AcademyChart {
        AcademyCartographer.chart(AcademyChartInputs(
            worldEvents: [event],
            now: calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: 10))!,
            calendar: calendar
        ))
    }

    private func person(_ id: String, in chart: AcademyChart) -> AcademyWhereabout? {
        (chart.rooms.flatMap(\.people) + chart.unseen).first { $0.characterID == id }
    }

    func testTheWeekBeforeHasPermancerGettingReady() throws {
        let event = try countUnbound()
        let chart = octoberChart(9, 27, 17, event: event)
        XCTAssertEqual(person("professor-permancer", in: chart)?.roomID, "location-vault-of-doors")
        XCTAssertTrue(chart.room("location-vault-of-doors")?.isDrawn ?? false, "the month draws the room it stages")
        XCTAssertTrue(chart.room("location-east-stacks")?.lines.contains { $0.contains("turning its own pages") } ?? false)
    }

    func testSundaysJumpFillsTheVault() throws {
        let chart = octoberChart(10, 4, 10, event: try countUnbound())
        for id in ["professor-permancer", "wicker-eddies", "penny-blackletter", "serenity-brown"] {
            XCTAssertEqual(person(id, in: chart)?.roomID, "location-vault-of-doors", id)
        }
    }

    func testAfterTheIncidentTheEastStacksAreShutAndSerenitysInTheKitchens() throws {
        let chart = octoberChart(10, 12, 14, event: try countUnbound())
        XCTAssertEqual(chart.closedRoomIDs, ["location-east-stacks", "location-rain-room"])
        XCTAssertTrue(chart.room("location-east-stacks")?.isDrawn ?? false)
        XCTAssertEqual(person("serenity-brown", in: chart)?.roomID, "location-kitchens")
        XCTAssertTrue(chart.room("location-kitchens")?.lines.contains { $0.contains("go through Ambrose") } ?? false)
    }

    func testTheCountReadsAtNight() throws {
        let event = try countUnbound()
        let night = octoberChart(10, 16, 23, event: event)
        let count = person("count-dracula", in: night)
        XCTAssertEqual(count?.roomID, "location-old-reading-room")
        XCTAssertEqual(count?.isVisitor, true)
        XCTAssertEqual(count?.mapName, "The Count")
        XCTAssertNil(person("count-dracula", in: octoberChart(10, 16, 14, event: event)), "not in the daytime")
        XCTAssertNil(person("count-dracula", in: octoberChart(10, 10, 23, event: event)), "not before the reader can meet him")
    }

    func testTheWrongCastleGrowsAndGoesHome() throws {
        let event = try countUnbound()
        let during = octoberChart(10, 23, 15, event: event)
        let castle = during.room("borrowed-wrong-castle")
        XCTAssertTrue(castle?.isDrawn ?? false)
        XCTAssertEqual(castle?.room.isBorrowed, true)
        XCTAssertTrue(during.passages.contains { $0.touches("borrowed-wrong-castle") && $0.kind == .drawbridge })
        XCTAssertEqual(person("serenity-brown", in: during)?.roomID, "borrowed-wrong-castle")
        XCTAssertNil(during.room("borrowed-ballroom"), "the ballroom comes later")
        XCTAssertNotNil(octoberChart(10, 26, 15, event: event).room("borrowed-ballroom"))

        let after = octoberChart(10, 30, 15, event: event)
        XCTAssertNil(after.room("borrowed-wrong-castle"))
        XCTAssertFalse(after.closedRoomIDs.contains("location-east-stacks"), "the East Stacks open again")
    }

    func testSupperWithTheCount() throws {
        let chart = octoberChart(10, 28, 19, event: try countUnbound())
        XCTAssertEqual(person("count-dracula", in: chart)?.roomID, "location-great-hall")
        XCTAssertEqual(person("serenity-brown", in: chart)?.roomID, "location-great-hall")
    }

    func testTheWeekAfterRemembers() throws {
        let chart = octoberChart(11, 3, 8, event: try countUnbound())
        XCTAssertTrue(chart.room("location-east-stacks")?.lines.contains { $0.contains("red chair") } ?? false)
        XCTAssertEqual(person("serenity-brown", in: chart)?.roomID, "location-kitchens")
        XCTAssertNil(person("count-dracula", in: chart))
    }

    /// Everything the pack stages points at somewhere real and somebody real,
    /// and says it like the Book.
    func testTheSeasonsStagingIsWellFormed() throws {
        let event = try countUnbound()
        let sets = event.phases.map(\.academy) + [event.foreshadowAcademy, event.residueAcademy].compactMap { $0 }
        for set in sets {
            let borrowed = Set((set.borrowedRooms ?? []).map(\.id))
            func real(_ room: String) -> Bool { AcademyGeography.room(id: room) != nil || borrowed.contains(room) }
            for staged in set.staging ?? [] {
                XCTAssertTrue(real(staged.roomID), staged.roomID)
                XCTAssertNotEqual(staged.roomID, AcademyGeography.dormID)
                XCTAssertTrue(AcademyWhereabouts.haunt(staged.castID) != nil || staged.name != nil, staged.castID)
            }
            for room in (set.closedRoomIDs ?? []) + (set.roomNotes ?? []).map(\.roomID) {
                XCTAssertTrue(real(room), room)
            }
            for room in set.borrowedRooms ?? [] {
                for join in room.joins { XCTAssertNotNil(AcademyGeography.room(id: join.roomID), join.roomID) }
            }
            let prose = (set.staging ?? []).compactMap(\.note) + (set.roomNotes ?? []).map(\.note)
                + (set.borrowedRooms ?? []).map(\.note)
            for line in prose {
                let padded = " " + line.lowercased() + " "
                for stiff in [" it is ", " do not ", " does not ", " is not ", " there is ", " that is ", " has been "] {
                    XCTAssertFalse(padded.contains(stiff), "\(stiff) in: \(line)")
                }
            }
        }
    }

    func testEverySceneInThePackNamesARealRoomAndRealCast() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")
        let pack = try JSONDecoder().decode(WorldEventPack.self, from: Data(contentsOf: url))
        let scenes = pack.storyScenes ?? []
        XCTAssertGreaterThan(scenes.filter { $0.roomID != nil }.count, 10)
        for scene in scenes where scene.roomID != nil {
            XCTAssertNotNil(AcademyGeography.room(id: scene.roomID!), scene.id)
            for id in scene.castIDs ?? [] { XCTAssertNotNil(AcademyWhereabouts.haunt(id), "\(scene.id): \(id)") }
        }
        for beat in pack.events.flatMap({ $0.beats ?? [] }) where beat.roomID != nil {
            XCTAssertNotNil(AcademyGeography.room(id: beat.roomID!), beat.id)
        }
    }

    // MARK: - Moving about

    func testTheWayFromTheDormToTheGreatHall() {
        let route = AcademyRoute.rooms(from: AcademyGeography.dormID, to: "location-great-hall", passages: AcademyGeography.passages)
        XCTAssertEqual(route, [AcademyGeography.dormID, "location-book-burrow", "location-kitchens", "location-great-hall"])
    }

    func testAShutRoomIsWalkedAround() {
        let passages = AcademyGeography.passages
        let direct = AcademyRoute.rooms(from: "location-vault-of-doors", to: "location-quillquarium", passages: passages)
        XCTAssertEqual(direct?.contains("location-east-stacks"), true)
        let around = AcademyRoute.rooms(from: "location-vault-of-doors", to: "location-quillquarium",
                                        passages: passages, avoiding: ["location-east-stacks"])
        XCTAssertNotNil(around)
        XCTAssertEqual(around?.contains("location-east-stacks"), false)
    }

    func testEveryRoomCanBeWalkedBetween() {
        for from in AcademyGeography.rooms {
            for to in AcademyGeography.rooms {
                XCTAssertNotNil(AcademyRoute.rooms(from: from.id, to: to.id, passages: AcademyGeography.passages), "\(from.id) → \(to.id)")
            }
        }
    }

    /// At noon everybody heads for lunch, and the map knows where they came from.
    func testOnTheHourPeopleSetOff() {
        let noon = at(weekday: 4, hour: 12, minute: 0).addingTimeInterval(20)
        let lunch = chart(affinities: Dictionary(uniqueKeysWithValues: AcademyGeography.rooms.map { ($0.id, 1) }), now: noon)
        XCTAssertFalse(lunch.arrivals.isEmpty)
        let serenity = lunch.arrivals["serenity-brown"]
        XCTAssertNotNil(serenity)
        XCTAssertEqual(serenity?.startedAt, at(weekday: 4, hour: 12, minute: 0))
        XCTAssertNotEqual(serenity?.fromRoomID, "location-great-hall")

        if let serenity {
            let reopened = chart(now: serenity.startedAt.addingTimeInterval(serenity.duration / 2))
            XCTAssertEqual(reopened.arrivals["serenity-brown"], serenity, "opening midway through lunch's walk catches the same feet")
            let arrived = chart(now: serenity.startedAt.addingTimeInterval(serenity.duration))
            XCTAssertNil(arrived.arrivals["serenity-brown"], "she's arrived")
        }
    }

    func testWhoPacesAndWhoStandsStill() {
        let base = AcademyWhereabout(characterID: "dr-inkrest", name: "Dr. Selene Inkrest", mapName: "Dr. Inkrest",
                                     roomID: "location-still-room", why: .haunt)
        XCTAssertEqual(AcademyMotion.of(base), .stationary)
        var wicker = base
        wicker.characterID = "wicker-eddies"
        XCTAssertEqual(AcademyMotion.of(wicker), .pacing)
        wicker.why = .eating
        XCTAssertEqual(AcademyMotion.of(wicker), .stationary, "nobody paces through lunch")
        var teacher = base
        teacher.why = .teaching
        XCTAssertEqual(AcademyMotion.of(teacher), .pacing)
    }

    func testTheMapLabelDropsTheWingNumber() {
        XCTAssertEqual(AcademyGeography.room(id: "location-glint-hall")?.mapLabel, "The Glint Hall")
        XCTAssertEqual(AcademyGeography.room(id: "location-kitchens")?.mapLabel, "The Kitchens")
    }
}

extension AcademyGeographyTests {
    // MARK: - Illustrated leaves preserve the living Academy

    func testIllustratedAtlasHasOneFloorForEveryPermanentRoom() {
        XCTAssertEqual(Set(AcademyIllustratedAtlas.floors.keys), Set(AcademyGeography.rooms.map(\.id)))
        let source = chart()
        let leaves = AcademyMapLevel.allCases.map { AcademyIllustratedAtlas.chart(source, on: $0) }
        let ids = leaves.flatMap { $0.rooms.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(Set(ids), Set(source.rooms.map(\.id)))
        XCTAssertEqual(source.allPassages, AcademyGeography.passages)
    }

    func testIllustratedLeavesKeepEveryCastAddressAcrossTheWeek() {
        for day in 0..<7 {
            for hour in 0..<24 {
                let now = calendar.date(byAdding: .hour, value: day * 24 + hour, to: quietNoon)!
                let source = chart(now: now)
                let people = AcademyMapLevel.allCases.flatMap { AcademyIllustratedAtlas.chart(source, on: $0).rooms.flatMap(\.people) }
                XCTAssertEqual(Set(people.map(\.characterID)), Set(source.rooms.flatMap(\.people).map(\.characterID)))
                XCTAssertEqual(people.count, source.rooms.flatMap(\.people).count)
                for person in people {
                    let leaf = AcademyIllustratedAtlas.chart(source, on: AcademyIllustratedAtlas.level(of: person.roomID, in: source))
                    XCTAssertTrue(leaf.isDrawn(person.roomID), person.name)
                }
            }
        }
    }

    func testPrivateIllustratedDormFollowsAllFiveBindings() throws {
        for chapter in AcademyChapterRegistry.chapters {
            let source = AcademyCartographer.chart(AcademyChartInputs(now: quietNoon, calendar: calendar, readerChapterID: chapter.id))
            let upper = AcademyIllustratedAtlas.chart(source, on: .upper)
            let home = try XCTUnwrap(upper.room(AcademyGeography.dormID))
            let dorms = try XCTUnwrap(upper.room(AcademyGeography.dormitoriesID(chapter.id)))
            XCTAssertEqual(home.point.x, dorms.point.x, accuracy: 0.00001)
            XCTAssertGreaterThan(home.point.y, dorms.point.y)
            XCTAssertTrue(home.people.isEmpty)
            XCTAssertEqual(home.room.mapLabel, "My Dorm")
            XCTAssertEqual(home.lines, source.room(home.id)?.lines)
        }
    }

    func testReaderDoorsOnlyUnfoldOnTheStacksLeaf() {
        let source = AcademyCartographer.chart(AcademyChartInputs(anchors: (0..<20).map { anchorRecord("a-\($0)") }, now: quietNoon, calendar: calendar))
        for level in AcademyMapLevel.allCases {
            let leaf = AcademyIllustratedAtlas.chart(source, on: level)
            XCTAssertEqual(leaf.anchorRooms, level == .labyrinth ? source.anchorRooms : [])
            XCTAssertEqual(leaf.allPassages, source.allPassages, "Reader places cannot become Cast destinations")
        }
    }

    func testIllustratedStairsKeepBothEndsOfEveryCrossLevelPassage() {
        let source = chart()
        let stairs = AcademyMapLevel.allCases.flatMap { AcademyIllustratedAtlas.doors(in: source, on: $0) }
        for passage in source.allPassages {
            let from = AcademyIllustratedAtlas.level(of: passage.from, in: source)
            let to = AcademyIllustratedAtlas.level(of: passage.to, in: source)
            let pair = stairs.filter { Set([$0.from, $0.to]) == Set([passage.from, passage.to]) }
            XCTAssertEqual(pair.count, from == to ? 0 : 2)
            for door in pair {
                XCTAssertEqual(door.level, AcademyIllustratedAtlas.level(of: door.to, in: source))
            }
        }
    }

    func testBorrowedChambersUnfoldBelowTheCorrectIllustratedLeaf() throws {
        let source = octoberChart(10, 26, 15, event: try countUnbound())
        XCTAssertEqual(AcademyIllustratedAtlas.level(of: "borrowed-ballroom", in: source), .ground)
        XCTAssertEqual(AcademyIllustratedAtlas.level(of: "borrowed-wrong-castle", in: source), .labyrinth)
        for room in source.rooms where room.room.isBorrowed {
            let floor = AcademyIllustratedAtlas.floor(of: room, in: source)
            XCTAssertGreaterThan(floor.center.y - floor.size.y / 2, 1)
            let leaf = AcademyIllustratedAtlas.chart(source, on: floor.level)
            XCTAssertEqual(leaf.room(room.id)?.people, room.people)
            XCTAssertEqual(leaf.allPassages, source.allPassages)
        }
    }

    func testAllIllustratedJourneysPartitionTheCanonicalWalkAndClock() throws {
        let source = chart()
        for start in source.rooms {
            for goal in source.rooms where goal.id != start.id {
                let path = try XCTUnwrap(AcademyRoute.rooms(from: start.id, to: goal.id, passages: source.allPassages, avoiding: source.closedRoomIDs))
                let parts = AcademyMapLevel.allCases.flatMap { AcademyIllustratedAtlas.journey(from: start.id, to: goal.id, in: source, on: $0) }
                    .sorted { $0.starts < $1.starts }
                XCTAssertEqual(parts.flatMap(\.rooms), path, "\(start.id) → \(goal.id)")
                XCTAssertEqual(parts.first?.starts, 0)
                XCTAssertEqual(parts.last?.finishes, 1)
                for (a, b) in zip(parts, parts.dropFirst()) { XCTAssertEqual(a.finishes, b.starts, accuracy: 0.000001) }
                for part in parts { XCTAssertGreaterThan(part.finishes, part.starts) }
            }
        }
    }

    func testReturnToTheSameLeafHasSeparateDepartureAndArrivalStretches() {
        let source = chart()
        // The only real way from Emberheart to Riddlewind's bedrooms runs
        // down through their common rooms and back upstairs.
        let parts = AcademyIllustratedAtlas.journey(from: "location-dorms-emberheart", to: "location-dorms-riddlewind", in: source, on: .upper)
        XCTAssertEqual(parts.count, 2)
        guard parts.count == 2 else { return }
        XCTAssertEqual(parts.first?.enters, false)
        XCTAssertEqual(parts.first?.leaves, true)
        XCTAssertEqual(parts.last?.enters, true)
        XCTAssertEqual(parts.last?.leaves, false)
        XCTAssertLessThan(parts[0].finishes, parts[1].starts)
    }

    func testIllustratedMisfiledShelfStillHasThreeDailyAlcoves() throws {
        var positions: [AcademyMapPoint] = []
        for day in 0..<3 {
            let source = chart(now: calendar.date(byAdding: .day, value: day, to: quietNoon)!)
            let room = try XCTUnwrap(source.room("location-shelf-misfiled-days"))
            let floor = AcademyIllustratedAtlas.floor(of: room, in: source)
            XCTAssertEqual(floor.level, .labyrinth)
            XCTAssertFalse(positions.contains(floor.center))
            positions.append(floor.center)
        }
    }
}

extension AcademyGeographyTests {
    // MARK: - Corridors are occupied by real journeys

    private var corridorDeparture: Date { at(weekday: 4, hour: 14, minute: 11).addingTimeInterval(23) }

    private func corridorInputs() -> AcademyChartInputs {
        AcademyChartInputs(deskScenes: [
            AcademyScene(roomID: "location-pantry", castIDs: ["serenity-brown"], at: corridorDeparture.addingTimeInterval(-600)),
            AcademyScene(roomID: "location-spark-annex", castIDs: ["serenity-brown"], at: corridorDeparture)
        ], now: corridorDeparture.addingTimeInterval(80), calendar: calendar,
           cast: NarrativePackRegistry.entities.filter { $0.id == "serenity-brown" })
    }

    func testReopeningTheMapAfterTheFirstMinuteStillCatchesAWalker() throws {
        let inputs = corridorInputs()
        let opened = AcademyCartographer.chart(inputs)
        let arrival = try XCTUnwrap(opened.arrivals["serenity-brown"])
        XCTAssertEqual(arrival.fromRoomID, "location-pantry")
        XCTAssertEqual(arrival.startedAt, corridorDeparture, "a story's departure keeps its actual seconds")
        XCTAssertTrue(arrival.isUnderway(at: inputs.now))
        XCTAssertEqual(opened.rooms.flatMap(\.people).count, 1)
        XCTAssertEqual(AcademyCartographer.chart(inputs).arrivals, opened.arrivals, "reopening never restarts the walk")
        XCTAssertNil(AcademyCartographer.chart(inputs.at(corridorDeparture.addingTimeInterval(arrival.duration))).arrivals["serenity-brown"])
    }

    func testQuietHoursDoNotPutRandomCastInCorridors() {
        XCTAssertTrue(chart(now: at(weekday: 4, hour: 14, minute: 17)).arrivals.isEmpty)
        XCTAssertTrue(chart(now: at(weekday: 4, hour: 23, minute: 17)).arrivals.isEmpty)
    }

    func testAFutureStoryDoesNotMoveSomebodyEarly() {
        let before = AcademyCartographer.chart(corridorInputs().at(corridorDeparture.addingTimeInterval(-10)))
        XCTAssertEqual(before.rooms.flatMap(\.people).first?.roomID, "location-pantry")
        XCTAssertNil(before.arrivals["serenity-brown"])
    }

    func testLeavingALingeringSceneAlsoProducesAWalk() throws {
        let release = corridorDeparture.addingTimeInterval(AcademyWhereabouts.sceneLingers)
        let baseline = AcademyCartographer.chart(AcademyChartInputs(now: release, calendar: calendar,
            cast: NarrativePackRegistry.entities.filter { $0.id == "serenity-brown" }))
        let destination = try XCTUnwrap(baseline.rooms.flatMap(\.people).first?.roomID)
        let origin = destination == "location-pantry" ? "location-spark-annex" : "location-pantry"
        let inputs = AcademyChartInputs(deskScenes: [AcademyScene(roomID: origin, castIDs: ["serenity-brown"], at: corridorDeparture)],
                                       now: release.addingTimeInterval(10), calendar: calendar,
                                       cast: NarrativePackRegistry.entities.filter { $0.id == "serenity-brown" })
        let arrival = try XCTUnwrap(AcademyCartographer.chart(inputs).arrivals["serenity-brown"])
        XCTAssertEqual(arrival.fromRoomID, origin)
        XCTAssertEqual(arrival.startedAt, release)
    }

    func testLongerRoutesTakeLongerAndDisconnectedRoomsCannotInventAWalk() throws {
        let person = AcademyWhereabout(characterID: "serenity-brown", name: "Serenity Brown", mapName: "Serenity",
                                       roomID: "location-spark-annex", why: .haunt)
        let short = try XCTUnwrap(AcademyArrival.departing(person, from: "location-glint-hall", at: corridorDeparture, passages: AcademyGeography.passages))
        let long = try XCTUnwrap(AcademyArrival.departing(person, from: "location-pantry", at: corridorDeparture, passages: AcademyGeography.passages))
        XCTAssertGreaterThan(long.duration, short.duration)
        XCTAssertLessThanOrEqual(long.duration, AcademyArrival.longestWalk)
        XCTAssertNil(AcademyArrival.departing(person, from: person.roomID, at: corridorDeparture, passages: AcademyGeography.passages))
        XCTAssertNil(AcademyArrival.departing(person, from: "location-pantry", at: corridorDeparture, passages: []))
        XCTAssertNil(AcademyArrival.departing(person, from: "location-pantry", at: corridorDeparture,
                                             passages: AcademyGeography.passages, closedRoomIDs: ["location-kitchens"]),
                     "a shut kitchen blocks the pantry's only way out")
    }

    func testFindingAWalkerUsesTheLeafWithTheirCurrentFootsteps() throws {
        let source = AcademyCartographer.chart(corridorInputs())
        let person = try XCTUnwrap(source.rooms.flatMap(\.people).first)
        let arrival = try XCTUnwrap(source.arrivals[person.characterID])
        var visited: Set<AcademyMapLevel> = []
        for leaf in AcademyMapLevel.allCases {
            for segment in AcademyIllustratedAtlas.journey(from: arrival.fromRoomID, to: person.roomID, in: source, on: leaf) {
                visited.insert(leaf)
                let moment = arrival.startedAt.addingTimeInterval((segment.starts + segment.finishes) / 2 * arrival.duration)
                XCTAssertEqual(AcademyIllustratedAtlas.level(of: person, at: moment, in: source), leaf)
            }
        }
        XCTAssertGreaterThan(visited.count, 1, "the pantry-to-annex walk passes through other levels")
    }
}
