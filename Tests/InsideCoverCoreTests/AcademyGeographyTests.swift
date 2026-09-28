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

    // MARK: - The map grows

    func testTheFirstNightDrawsOnlyTheRoomsEveryoneHasStoodIn() {
        let drawn = Set(chart().rooms.filter(\.isDrawn).map(\.id))
        let expected = Set(AcademyGeography.rooms.filter(\.startsDrawn).map(\.id))
        XCTAssertEqual(drawn, expected)
        XCTAssertTrue(drawn.contains(AcademyGeography.dormID))
        XCTAssertFalse(drawn.contains("location-vault-of-doors"))
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
    func testTheReadersOwnWritingNeverDrawsARoom() {
        let chart = chart(pages: [page("mine", prose: "Cleaned out the Pantry at last.", origin: .userAuthored)])
        XCTAssertFalse(chart.isDrawn("location-pantry"))
    }

    func testAStorySetInARoomDrawsIt() {
        XCTAssertTrue(chart(affinities: ["location-quillquarium": 1]).isDrawn("location-quillquarium"))
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

    func testTheRainRoomIsOnlyThereInTheRain() {
        XCTAssertFalse(chart().isDrawn("location-rain-room"))
        XCTAssertFalse(chart(sky: .clear).isDrawn("location-rain-room"))
        XCTAssertTrue(chart(sky: .rain).isDrawn("location-rain-room"))
        XCTAssertTrue(chart(sky: .storm).isDrawn("location-rain-room"))
        // Having named it once doesn't keep the door open on a dry day.
        let named = chart(pages: [page("p", prose: "The Rain Room opened for an hour.")], sky: .clear)
        XCTAssertFalse(named.isDrawn("location-rain-room"))
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

    /// A path runs as far as the paper that's been walked, so a passage with
    /// both ends blank isn't drawn at all.
    func testOnlyPassagesWithADrawnEndAreDrawn() {
        let chart = chart()
        for passage in chart.passages {
            XCTAssertTrue(chart.isDrawn(passage.from) || chart.isDrawn(passage.to))
        }
        XCTAssertFalse(chart.passages.contains { $0.from == "location-walled-garden" && $0.to == "location-secret-garden-prose" })
    }

    // MARK: - What the Book writes beside a room

    func testTheReadersPlacesAreDoorsInTheOuterStacks() {
        let lines = chart(anchors: ["the allotment", "Nan's", "the bus stop", "the pier"])
            .room("location-outer-stacks")?.lines ?? []
        XCTAssertTrue(lines.contains("There's a door here that opens onto the allotment."))
        XCTAssertEqual(lines.filter { $0.hasPrefix("There's a door here") }.count, AcademyCartographer.anchorDoorsShown)
    }

    func testARoomWithAClassOnSaysWhosTeaching() {
        // Monday, half nine: the Art of the Glint, with Boggle.
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 9, minute: 30))!
        let lines = chart(affinities: ["location-glint-hall": 1], now: monday).room("location-glint-hall")?.lines ?? []
        XCTAssertTrue(lines.contains("Boggle's teaching The Art of the Glint in here right now."), "\(lines)")
    }

    func testABlankRoomSaysNothing() {
        XCTAssertEqual(chart().room("location-vault-of-doors")?.lines, [])
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
        XCTAssertEqual(chart().footer, "I've drawn \(chart().drawnCount) rooms so far. The blank bits are where I haven't been yet.")
    }

    func testWaysOutNameTheDrawnRoomsAndLumpTheBlankOnes() {
        let chart = chart()
        XCTAssertEqual(
            chart.waysOut(from: "location-kitchens"),
            "From here you can get to the Great Hall, the Book Burrow and somewhere I haven't been yet."
        )
        XCTAssertEqual(chart.waysOut(from: AcademyGeography.dormID), "From here you can get to the Book Burrow.")
    }

    /// A hidden door to a blank room isn't even hinted at.
    func testAHiddenWayStaysHiddenUntilBothEndsAreDrawn() {
        let garden = chart(affinities: ["location-walled-garden": 1])
        XCTAssertEqual(garden.waysOut(from: "location-walled-garden"), "From here you can get to somewhere I haven't been yet.")
        let both = chart(affinities: ["location-walled-garden": 1, "location-secret-garden-prose": 1])
        XCTAssertTrue(both.waysOut(from: "location-walled-garden")?.contains("the Secret Garden of Prose") ?? false)
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

    func testMostOfTheCastIsOffTheMapAtNight() {
        let night = AcademyWhereabouts.everyone(at: at(weekday: 3, hour: 3), calendar: calendar)
        XCTAssertLessThan(night.count, AcademyWhereabouts.haunts.count / 3)
        XCTAssertTrue(night.contains { $0.characterID == "headmistress-thorne" })
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
        XCTAssertTrue(chart(pages: [story]).isDrawn("location-spark-annex"))
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

    func testAShutRoomSaysSo() {
        var inputs = AcademyChartInputs(storySettingAffinities: ["location-east-stacks": 1], now: quietNoon, calendar: calendar)
        inputs.events.closedRoomIDs = ["location-east-stacks"]
        let chart = AcademyCartographer.chart(inputs)
        XCTAssertTrue(chart.room("location-east-stacks")?.lines.contains("It's shut. Nobody's allowed in.") ?? false)
        XCTAssertEqual(chart.closedRoomIDs, ["location-east-stacks"])
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
            foreshadowStartsAt: quietNoon, residueEndsAt: quietNoon, casebookAvailableAt: quietNoon,
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
        XCTAssertEqual(chart.closedRoomIDs, ["location-east-stacks"])
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
        XCTAssertTrue(after.closedRoomIDs.isEmpty, "the East Stacks open again")
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

        let aMinuteLater = chart(now: noon.addingTimeInterval(60))
        XCTAssertNil(aMinuteLater.arrivals["serenity-brown"], "she's arrived")
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
