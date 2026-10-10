import Foundation

// MARK: - The Academy, as a place with a floor

/// Where the Academy's rooms are, and what connects to what.
///
/// Every other map in the Book draws the reader's own world. The rooms of the
/// Academy had characters (`NarrativeCore.coreLocations`) and history
/// (`PlaceState`) but no floor: nothing said the Kitchens were next to the
/// Book Burrow, so nothing could draw them there. This is that floor, laid out
/// once, so the Book's map and anything that later wants to walk the Academy
/// read the same rooms. The authored plan is `docs/academy-geography.md`.
///
/// The school is built on the Compass: the four Wings sit on the four points,
/// each teaching its own direction, and the Still Room is the centre.

enum AcademyZone: String, CaseIterable, Sendable {
    /// The living library the school sits inside. Its rooms may move.
    case labyrinth
    /// The middle of the school: the Great Hall and what opens off it.
    case heart
    /// The four teaching Wings, one per compass point, and their annexes.
    case wing
    /// Kitchens, common room, the reader's own room.
    case warm
    /// Outside the walls.
    case grounds
}

enum AcademyCompassPoint: String, Sendable {
    case north, east, south, west, center
}

/// How far a room can be trusted to be where the map says.
enum AcademyRoomStability: Equatable, Sendable {
    /// Walls. Always where it was.
    case fixed
    /// A Labyrinth room with somewhere else to be tomorrow. It moves between
    /// these spots, one a day.
    case drifting(spots: [AcademyMapPoint])
    /// There only while the real sky is doing one of these things.
    case weatherGated([SkyCondition])
}

/// A position on the Book's chart, in unit space: (0, 0) is the top-left of
/// the drawing and (1, 1) the bottom-right. Layout only; it means nothing
/// about distances inside the story.
struct AcademyMapPoint: Equatable, Sendable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

struct AcademyRoom: Identifiable, Equatable, Sendable {
    /// `location-*`, the same id a `NarrativeWorldEntity` for this room uses
    /// where one exists, so PlaceMemory and story settings land on it.
    var id: String
    var name: String
    var zone: AcademyZone
    var compass: AcademyCompassPoint?
    var stability: AcademyRoomStability
    var point: AcademyMapPoint
    /// Drawn from the first night: the rooms every reader has already stood in.
    var startsDrawn: Bool
    /// How the Book's own prose names it. Matched case-sensitively in a kept
    /// Page's `promptText` only, never in what the reader wrote, so a reader's
    /// own pantry never draws the Academy's.
    var names: [String]
    /// The timetable's spelling of this room, where it has one.
    var timetableName: String?
    /// The Book, about the room, once it's drawn.
    var note: String
    /// How the map draws it.
    var form: AcademyRoomForm = .room
    /// Its footprint on the chart, in the same unit space as `point`.
    var size = AcademyMapPoint(0.18, 0.06)
    /// Out of another book, and only here for a while.
    var isBorrowed = false

    /// What the map writes on the room: the name without its Wing number,
    /// which the Book says in the note instead.
    var mapLabel: String {
        guard name.hasPrefix("Wing "), let colon = name.firstIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }
}

/// What a room looks like from above, drawn in ink.
enum AcademyRoomForm: String, Sendable {
    /// Walls and a floor.
    case room
    /// The Stacks themselves: the ring of shelving the whole school sits inside.
    /// A way to the Stacks runs to whichever wall of shelves is nearest.
    case ring
    /// Rows of shelving.
    case shelving
    /// Round, with a thick wall.
    case tower
    /// Open ground with a low wall.
    case yard
    /// A hedge all round and things growing.
    case garden
    /// Long and thin.
    case corridor
    /// Steps.
    case stair
    /// A room lined with doors.
    case doors
}

enum AcademyPassageKind: String, Sendable {
    case door, stair, corridor, drawbridge, path
    /// Only there once you know it is.
    case hidden
}

/// A way between two rooms. Undirected: nothing in the Academy is one-way.
struct AcademyPassage: Equatable, Sendable {
    var from: String
    var to: String
    var kind: AcademyPassageKind

    func touches(_ roomID: String) -> Bool { from == roomID || to == roomID }
    func other(than roomID: String) -> String? {
        if from == roomID { return to }
        if to == roomID { return from }
        return nil
    }
}

enum AcademyGeography {
    static let dormID = "location-dorm"

    static func room(id: String) -> AcademyRoom? { rooms.first { $0.id == id } }

    /// The room a timetable entry is held in.
    static func room(forTimetableName name: String) -> AcademyRoom? {
        rooms.first { $0.timetableName == name }
    }

    static func passages(touching roomID: String) -> [AcademyPassage] {
        passages.filter { $0.touches(roomID) }
    }

    /// Where a room is drawn today. Drifting rooms take one of their spots a
    /// day, so the map is honest that it was somewhere else yesterday.
    static func point(of room: AcademyRoom, on date: Date, calendar: Calendar = .current) -> AcademyMapPoint {
        guard case .drifting(let spots) = room.stability, !spots.isEmpty else { return room.point }
        let day = GrimoireDay.index(for: date, calendar: calendar)
        return spots[((day % spots.count) + spots.count) % spots.count]
    }

    // MARK: - The rooms

    private static let foundingRooms: [AcademyRoom] = [
        // The Labyrinth
        AcademyRoom(
            id: "location-outer-stacks", name: "The Outer Stacks", zone: .labyrinth, compass: nil,
            stability: .fixed, point: .init(0.50, 0.025), startsDrawn: true,
            names: ["Outer Stacks"],
            note: "Where I come in from outside. The shelves remember whose feet went past.",
            form: .shelving, size: .init(0.30, 0.045)
        ),
        AcademyRoom(
            id: "location-stacks", name: "The Stacks", zone: .labyrinth, compass: nil,
            stability: .fixed, point: .init(0.50, 0.575), startsDrawn: true,
            names: [],
            note: "My archive. The catalog cards file things in the wrong place on purpose, and the ladders turn up before you've finished asking.",
            form: .ring, size: .init(0.96, 0.815)
        ),
        AcademyRoom(
            id: "location-east-stacks", name: "The East Stacks", zone: .labyrinth, compass: .east,
            stability: .fixed, point: .init(0.91, 0.25), startsDrawn: false,
            names: ["East Stacks"],
            note: "The far end of the Stacks, over by the pens. Things from other books come in this way when somebody leaves a door open.",
            form: .shelving, size: .init(0.12, 0.07)
        ),
        AcademyRoom(
            id: "location-vault-of-doors", name: "The Vault of Doors", zone: .labyrinth, compass: nil,
            stability: .fixed, point: .init(0.80, 0.09), startsDrawn: false,
            names: ["Vault of Doors"], timetableName: "The Vault of Doors",
            note: "Doors into other books, hundreds of them. Permancer says always know where your bookmark is. He says it a lot.",
            form: .doors, size: .init(0.18, 0.06)
        ),
        AcademyRoom(
            id: "location-bibliophonic-hall", name: "The Bibliophonic Hall", zone: .labyrinth, compass: nil,
            stability: .fixed, point: .init(0.16, 0.26), startsDrawn: false,
            names: ["Bibliophonic Hall"], timetableName: "The Bibliophonic Hall",
            note: "The Inkwrights read things out loud in here and then burn them. The smoke goes up into my ceiling. I can still taste some of it.",
            form: .room, size: .init(0.2, 0.065)
        ),
        AcademyRoom(
            id: "location-corridor-whispered", name: "The Corridor of Whispered Secrets", zone: .labyrinth, compass: nil,
            stability: .fixed, point: .init(0.32, 0.43), startsDrawn: false,
            names: ["Corridor of Whispered Secrets"], timetableName: "The Corridor of Whispered Secrets",
            note: "A long corridor with notes stuck all over the walls. People leave them for whoever comes next. I read every one.",
            form: .corridor, size: .init(0.26, 0.03)
        ),
        AcademyRoom(
            id: "location-old-reading-room", name: "The Old Reading Room", zone: .labyrinth, compass: nil,
            stability: .fixed, point: .init(0.72, 0.22), startsDrawn: false,
            names: ["old reading-room", "Old Reading Room", "old reading room"],
            note: "A reading room nobody uses. There's a green lamp in it that's always on, and I don't know who pays for that.",
            form: .room, size: .init(0.14, 0.05)
        ),
        AcademyRoom(
            id: "location-shelf-misfiled-days", name: "The Shelf of Misfiled Days", zone: .labyrinth, compass: nil,
            stability: .drifting(spots: [.init(0.19, 0.10), .init(0.64, 0.10), .init(0.32, 0.10)]),
            point: .init(0.19, 0.09), startsDrawn: false,
            names: ["Shelf of Misfiled Days"],
            note: "Ordinary days end up on this shelf, filed wrong. It wasn't here yesterday. It never is.",
            form: .shelving, size: .init(0.16, 0.035)
        ),
        AcademyRoom(
            id: "location-rain-room", name: "The Rain Room", zone: .labyrinth, compass: nil,
            stability: .weatherGated([.rain, .storm]), point: .init(0.15, 0.93), startsDrawn: false,
            names: ["Rain Room"],
            note: "It only opens when it's raining where you are. It's open now.",
            form: .room, size: .init(0.16, 0.05)
        ),

        // The heart
        AcademyRoom(
            id: "location-great-hall", name: "The Great Hall", zone: .heart, compass: .center,
            stability: .fixed, point: .init(0.50, 0.50), startsDrawn: true,
            names: ["Great Hall"],
            note: "Everybody's room. The banners change colour when the mood of the place moves, and gossip gets across it faster than anybody can walk.",
            form: .room, size: .init(0.28, 0.09)
        ),
        AcademyRoom(
            id: "location-still-room", name: "The Still Room", zone: .heart, compass: .center,
            stability: .fixed, point: .init(0.50, 0.64), startsDrawn: false,
            names: ["Still Room"], timetableName: "The Still Room",
            note: "Right under the Great Hall, and the quietest room I've got. Stonebrook teaches stopping in here. You go through it to get south.",
            form: .room, size: .init(0.16, 0.05)
        ),
        AcademyRoom(
            id: "location-binding-hall", name: "The Binding Hall", zone: .heart, compass: nil,
            stability: .fixed, point: .init(0.68, 0.67), startsDrawn: true,
            names: ["Binding Hall"],
            note: "Where you got bound to your Chapter. The candles went blue-white. I remember.",
            form: .room, size: .init(0.18, 0.05)
        ),
        AcademyRoom(
            id: "location-north-staircase", name: "The North Staircase", zone: .heart, compass: .north,
            stability: .fixed, point: .init(0.62, 0.42), startsDrawn: false,
            names: ["North Staircase"],
            note: "It goes up to the Glint Hall and then keeps going. Wicker isn't allowed on it. It's very still.",
            form: .stair, size: .init(0.12, 0.05)
        ),
        AcademyRoom(
            id: "location-headmistress-tower", name: "The Tower", zone: .heart, compass: .north,
            stability: .fixed, point: .init(0.50, 0.245), startsDrawn: false,
            names: ["Headmistress's office", "Headmistress's tower", "Headmistress's Tower", "Thorne's tower"],
            note: "Thorne's tower. Her inkwell's up there for safekeeping. That's what she says, anyway.",
            form: .tower, size: .init(0.12, 0.075)
        ),

        // The Wings
        AcademyRoom(
            id: "location-glint-hall", name: "Wing 4: The Glint Hall", zone: .wing, compass: .north,
            stability: .fixed, point: .init(0.50, 0.33), startsDrawn: false,
            names: ["Glint Hall"], timetableName: "Wing 4: The Glint Hall",
            note: "Wing Four, on the north side. Boggle teaches noticing in here. Everything in it's alive if you look at it properly.",
            form: .room, size: .init(0.22, 0.07)
        ),
        AcademyRoom(
            id: "location-momentum-yard", name: "Wing 2: The Momentum Yard", zone: .wing, compass: .east,
            stability: .fixed, point: .init(0.72, 0.56), startsDrawn: false,
            names: ["Momentum Yard"], timetableName: "Wing 2: The Momentum Yard",
            note: "Wing Two, on the east side. Momort teaches going places. He's a bit too fond of the way out.",
            form: .yard, size: .init(0.2, 0.09)
        ),
        AcademyRoom(
            id: "location-resonance-chamber", name: "Wing 3: The Resonance Chamber", zone: .wing, compass: .south,
            stability: .fixed, point: .init(0.50, 0.79), startsDrawn: false,
            names: ["Resonance Chamber"], timetableName: "Wing 3: The Resonance Chamber",
            note: "Wing Three, on the south side. Euphony teaches you to hear colours in here. The stones hum.",
            form: .room, size: .init(0.24, 0.07)
        ),
        AcademyRoom(
            id: "location-inkworks", name: "Wing 1: The Inkworks", zone: .wing, compass: .west,
            stability: .fixed, point: .init(0.14, 0.50), startsDrawn: false,
            names: ["Inkworks"], timetableName: "The Inkworks",
            note: "Wing One, on the west side. Villanelle teaches writing things down so they stay. What doesn't get written dissolves.",
            form: .room, size: .init(0.2, 0.08)
        ),
        AcademyRoom(
            id: "location-spark-annex", name: "The Spark Annex", zone: .wing, compass: nil,
            stability: .fixed, point: .init(0.75, 0.36), startsDrawn: false,
            names: ["Spark Annex"], timetableName: "The Spark Annex",
            note: "Wispwood's room. Everything in here talks if you ask it nicely. The teapot's rude.",
            form: .room, size: .init(0.18, 0.05)
        ),
        AcademyRoom(
            id: "location-quillquarium", name: "The Quillquarium", zone: .wing, compass: .east,
            stability: .fixed, point: .init(0.89, 0.50), startsDrawn: false,
            names: ["Quillquarium"],
            note: "Pens swim about in the air in here like fish, and the sharp ones circle anything badly written.",
            form: .tower, size: .init(0.15, 0.1)
        ),

        // The warm rooms
        AcademyRoom(
            id: "location-kitchens", name: "The Kitchens", zone: .warm, compass: nil,
            stability: .fixed, point: .init(0.27, 0.68), startsDrawn: true,
            names: ["the Kitchens", "The Kitchens"],
            note: "Ambrose's kitchens. The door opens quicker for anybody who needs looking after.",
            form: .room, size: .init(0.2, 0.065)
        ),
        AcademyRoom(
            id: "location-pantry", name: "The Pantry", zone: .warm, compass: nil,
            stability: .fixed, point: .init(0.10, 0.65), startsDrawn: false,
            names: ["the Pantry", "The Pantry"],
            note: "Off the Kitchens. The labels keep changing themselves to be nicer, and it keeps every receipt.",
            form: .room, size: .init(0.13, 0.045)
        ),
        AcademyRoom(
            id: "location-book-burrow", name: "The Book Burrow", zone: .warm, compass: nil,
            stability: .fixed, point: .init(0.15, 0.79), startsDrawn: true,
            names: ["Book Burrow"],
            note: "Everybody's common room. Low ceiling, lots of blankets. The armchairs shuffle over to whoever needs company.",
            form: .room, size: .init(0.2, 0.06)
        ),
        AcademyRoom(
            id: dormID, name: "My Dorm", zone: .warm, compass: nil,
            stability: .fixed, point: .init(0.35, 0.86), startsDrawn: true,
            names: [],
            note: "Your room. I don't draw what's in it. That's yours.",
            form: .room, size: .init(0.14, 0.05)
        ),

        // The grounds
        AcademyRoom(
            id: "location-open-field-gate", name: "The Open Field Gate", zone: .grounds, compass: .east,
            stability: .fixed, point: .init(0.87, 0.74), startsDrawn: false,
            names: ["Open Field Gate"], timetableName: "The Open Field Gate",
            note: "The way out onto the field. Compass Running's on Saturdays, out past the gate.",
            form: .yard, size: .init(0.18, 0.06)
        ),
        AcademyRoom(
            id: "location-walled-garden", name: "The Walled Garden", zone: .grounds, compass: nil,
            stability: .fixed, point: .init(0.73, 0.83), startsDrawn: false,
            names: ["Walled Garden"],
            note: "A garden with a wall all the way round it. It needs mending.",
            form: .garden, size: .init(0.22, 0.09)
        ),
        AcademyRoom(
            id: "location-secret-garden-prose", name: "The Secret Garden of Prose", zone: .grounds, compass: nil,
            stability: .fixed, point: .init(0.84, 0.94), startsDrawn: false,
            names: ["Secret Garden of Prose"], timetableName: "The Secret Garden of Prose",
            note: "There's a door in the Walled Garden that goes in here. The Compass Society reads sentences out loud and nobody's allowed to laugh.",
            form: .garden, size: .init(0.18, 0.06)
        )
    ]

    /// A surveyed campus, with the teaching school above its residential
    /// courts. The same coordinates are used by walls, doors and footprints.
    private static let campus: [String: (AcademyMapPoint, AcademyMapPoint)] = [
        "location-outer-stacks": (.init(0.5, 0.027), .init(0.4, 0.038)),
        "location-stacks": (.init(0.5, 0.54), .init(0.97, 0.97)),
        "location-east-stacks": (.init(0.935, 0.19), .init(0.105, 0.07)),
        "location-vault-of-doors": (.init(0.82, 0.075), .init(0.19, 0.048)),
        "location-bibliophonic-hall": (.init(0.15, 0.22), .init(0.2, 0.065)),
        "location-corridor-whispered": (.init(0.285, 0.311), .init(0.26, 0.022)),
        "location-old-reading-room": (.init(0.755, 0.19), .init(0.15, 0.045)),
        "location-shelf-misfiled-days": (.init(0.19, 0.09), .init(0.16, 0.026)),
        "location-rain-room": (.init(0.08, 0.745), .init(0.12, 0.045)),
        "location-great-hall": (.init(0.51, 0.405), .init(0.32, 0.14)),
        "location-still-room": (.init(0.5, 0.545), .init(0.16, 0.05)),
        "location-binding-hall": (.init(0.66, 0.565), .init(0.16, 0.048)),
        "location-north-staircase": (.init(0.74, 0.345), .init(0.1, 0.026)),
        "location-headmistress-tower": (.init(0.5, 0.13), .init(0.11, 0.066)),
        "location-glint-hall": (.init(0.5, 0.235), .init(0.25, 0.08)),
        "location-momentum-yard": (.init(0.77, 0.43), .init(0.15, 0.105)),
        "location-resonance-chamber": (.init(0.5, 0.65), .init(0.25, 0.075)),
        "location-inkworks": (.init(0.15, 0.405), .init(0.2, 0.11)),
        "location-spark-annex": (.init(0.75, 0.285), .init(0.18, 0.056)),
        "location-quillquarium": (.init(0.94, 0.37), .init(0.1, 0.075)),
        "location-kitchens": (.init(0.235, 0.55), .init(0.2, 0.078)),
        "location-pantry": (.init(0.08, 0.54), .init(0.1, 0.06)),
        "location-book-burrow": (.init(0.15, 0.66), .init(0.2, 0.07)),
        "location-dorm": (.init(0.25, 0.735), .init(0.1, 0.032)),
        "location-open-field-gate": (.init(0.9, 0.58), .init(0.16, 0.055)),
        "location-walled-garden": (.init(0.765, 0.655), .init(0.22, 0.085)),
        "location-secret-garden-prose": (.init(0.91, 0.725), .init(0.14, 0.05)),
    ]

    static let rooms: [AcademyRoom] = foundingRooms.map { original in
        var room = original
        if let layout = campus[room.id] { room.point = layout.0; room.size = layout.1 }
        if case .drifting = room.stability {
            room.stability = .drifting(spots: [.init(0.19, 0.09), .init(0.62, 0.07), .init(0.30, 0.125)])
        }
        return room
    } + residentialRooms

    static func commonRoomID(_ chapterID: String) -> String { "location-common-\(chapterID)" }
    static func dormitoriesID(_ chapterID: String) -> String { "location-dorms-\(chapterID)" }
    static let facultyID = "location-faculty-quarters"
    static let guestID = "location-guest-rooms"

    /// Residential architecture follows all five Chapters; it isn't another
    /// sorting system. Their established philosophies choose the fittings.
    private static let residentialRooms: [AcademyRoom] = {
        let chapters = AcademyChapterRegistry.chapters
        let notes: [String: String] = [
            "emberheart": "The hearth's impatient. People write things at the long tables and go out to try them.",
            "mossbloom": "Roots have got into the flagstones. Nobody minds. The chairs face the garden.",
            "tidecrest": "Round windows, a tide of cushions. The best seat changes while you're sitting in it.",
            "riddlewind": "One big table. Nothing gets finished by just one hand. Even the chairs are in an argument.",
            "duskthorn": "A thorn-dark study. The chairs don't let anybody get too comfortable with a lie."
        ]
        return chapters.enumerated().flatMap { index, chapter -> [AcademyRoom] in
            let x = 0.13 + Double(index) * 0.185
            let y = 0.82 + (index >= 2 ? 0.01 : 0)
            return [
                AcademyRoom(id: commonRoomID(chapter.id), name: "\(chapter.name) Common Room", zone: .warm, compass: nil,
                            stability: .fixed, point: .init(x, y), startsDrawn: true,
                            names: ["\(chapter.name) Common Room"], note: notes[chapter.id] ?? "A room for the Chapter to gather.",
                            form: .room, size: .init(0.15, 0.082)),
                AcademyRoom(id: dormitoriesID(chapter.id), name: "\(chapter.name) Dormitories", zone: .warm, compass: nil,
                            stability: .fixed, point: .init(x, y + 0.095), startsDrawn: true,
                            names: ["\(chapter.name) Dormitories"], note: "Up the stairs from \(chapter.name). The doors keep their own counsel.",
                            form: .room, size: .init(0.15, 0.048))
            ]
        } + [
            AcademyRoom(id: facultyID, name: "Faculty & Staff Quarters", zone: .warm, compass: nil,
                        stability: .fixed, point: .init(0.46, 0.735), startsDrawn: true,
                        names: ["Faculty Quarters", "Staff Quarters"], note: "Even professors go to bed. Some take their marking with them.",
                        form: .room, size: .init(0.32, 0.062)),
            AcademyRoom(id: guestID, name: "The Guest Rooms", zone: .warm, compass: nil,
                        stability: .fixed, point: .init(0.71, 0.745), startsDrawn: true,
                        names: ["Guest Rooms"], note: "For somebody who hasn't got a door of their own yet. I've left a lamp on.",
                        form: .room, size: .init(0.15, 0.038))
        ]
    }()

    /// My Dorm moves only when the Reader is bound. No Cast member's bedroom
    /// is ever substituted for it, and nothing is invented about its inside.
    static func homeRoom(chapterID: String?) -> AcademyRoom {
        var home = room(id: dormID)!
        if let chapterID, let dorms = room(id: dormitoriesID(chapterID)) {
            home.point = .init(dorms.point.x, dorms.point.y + 0.06)
        }
        return home
    }

    static func homePassages(chapterID: String?) -> [AcademyPassage] {
        guard let chapterID, room(id: dormitoriesID(chapterID)) != nil else { return passages }
        return passages.filter { !$0.touches(dormID) }
            + [.init(from: dormitoriesID(chapterID), to: dormID, kind: .door)]
    }

    /// A monthly room keeps its authored place when it fits. If the campus
    /// now occupies that paper, it finds free paper beside its joining rooms.
    /// Resolve this once per chart, before either walls or feet use it.
    static func surveyedBorrowedRooms(_ borrowed: [AcademyRoom], passages: [AcademyPassage], chapterID: String?) -> [AcademyRoom] {
        var occupied = rooms.filter { $0.form != .ring }.map {
            $0.id == dormID ? homeRoom(chapterID: chapterID) : $0
        }
        // Leave all three places of the moving shelf free, even between days.
        for room in rooms {
            if case .drifting(let spots) = room.stability {
                occupied += spots.map { point in var moved = room; moved.point = point; return moved }
            }
        }
        func fits(_ room: AcademyRoom, at point: AcademyMapPoint) -> Bool {
            guard point.x - room.size.x / 2 >= 0.025, point.x + room.size.x / 2 <= 0.975,
                  point.y - room.size.y / 2 >= 0.035, point.y + room.size.y / 2 <= 0.995 else { return false }
            return !occupied.contains { other in
                abs(point.x - other.point.x) < (room.size.x + other.size.x) / 2 + 0.01
                    && abs(point.y - other.point.y) < (room.size.y + other.size.y) / 2 + 0.007
            }
        }
        return borrowed.map { original in
            var room = original
            if !fits(room, at: room.point) {
                let neighbours = passages.filter { $0.touches(original.id) }
                    .compactMap { $0.other(than: original.id) }
                    .compactMap { id in occupied.first { $0.id == id }?.point }
                let desired = neighbours.isEmpty ? original.point : AcademyMapPoint(
                    neighbours.map(\.x).reduce(0, +) / Double(neighbours.count),
                    neighbours.map(\.y).reduce(0, +) / Double(neighbours.count))
                var nearest: AcademyMapPoint?
                var distance = Double.infinity
                // Test actual wall clearances, not a coarse coordinate grid:
                // a narrow opening can sit between two grid lines.
                let xs = Set([desired.x, original.point.x, 0.025 + room.size.x / 2, 0.975 - room.size.x / 2]
                    + occupied.flatMap { other in
                        let gap = (room.size.x + other.size.x) / 2 + 0.010001
                        return [other.point.x - gap, other.point.x + gap]
                    }).sorted()
                let ys = Set([desired.y, original.point.y, 0.035 + room.size.y / 2, 0.995 - room.size.y / 2]
                    + occupied.flatMap { other in
                        let gap = (room.size.y + other.size.y) / 2 + 0.007001
                        return [other.point.y - gap, other.point.y + gap]
                    }).sorted()
                for y in ys {
                    for x in xs {
                        let point = AcademyMapPoint(x, y)
                        let dx = point.x - desired.x, dy = (point.y - desired.y) * 1.6
                        let candidate = dx * dx + dy * dy
                        if candidate < distance, fits(room, at: point) {
                            nearest = point; distance = candidate
                        }
                    }
                }
                if let nearest { room.point = nearest }
            }
            occupied.append(room)
            return room
        }
    }

    // MARK: - The ways between them

    private static let foundingPassages: [AcademyPassage] = [
        .init(from: "location-outer-stacks", to: "location-stacks", kind: .corridor),
        .init(from: "location-stacks", to: "location-bibliophonic-hall", kind: .stair),
        .init(from: "location-stacks", to: "location-vault-of-doors", kind: .door),
        .init(from: "location-stacks", to: "location-shelf-misfiled-days", kind: .corridor),
        .init(from: "location-stacks", to: "location-headmistress-tower", kind: .stair),
        .init(from: "location-vault-of-doors", to: "location-east-stacks", kind: .door),
        .init(from: "location-east-stacks", to: "location-quillquarium", kind: .drawbridge),
        .init(from: "location-east-stacks", to: "location-old-reading-room", kind: .door),
        .init(from: "location-bibliophonic-hall", to: "location-inkworks", kind: .stair),

        .init(from: "location-great-hall", to: "location-north-staircase", kind: .stair),
        .init(from: "location-north-staircase", to: "location-glint-hall", kind: .stair),
        .init(from: "location-glint-hall", to: "location-headmistress-tower", kind: .stair),
        .init(from: "location-great-hall", to: "location-binding-hall", kind: .door),
        .init(from: "location-great-hall", to: "location-still-room", kind: .stair),
        .init(from: "location-great-hall", to: "location-corridor-whispered", kind: .corridor),
        .init(from: "location-corridor-whispered", to: "location-inkworks", kind: .corridor),
        .init(from: "location-great-hall", to: "location-momentum-yard", kind: .corridor),
        .init(from: "location-still-room", to: "location-resonance-chamber", kind: .stair),
        .init(from: "location-glint-hall", to: "location-spark-annex", kind: .door),
        .init(from: "location-spark-annex", to: "location-momentum-yard", kind: .door),
        .init(from: "location-momentum-yard", to: "location-quillquarium", kind: .door),

        .init(from: "location-great-hall", to: "location-kitchens", kind: .door),
        .init(from: "location-kitchens", to: "location-pantry", kind: .door),
        .init(from: "location-kitchens", to: "location-book-burrow", kind: .door),
        .init(from: "location-book-burrow", to: dormID, kind: .stair),
        .init(from: "location-book-burrow", to: "location-rain-room", kind: .door),
        .init(from: "location-book-burrow", to: "location-stacks", kind: .stair),

        .init(from: "location-momentum-yard", to: "location-open-field-gate", kind: .door),
        .init(from: "location-open-field-gate", to: "location-walled-garden", kind: .path),
        .init(from: "location-walled-garden", to: "location-secret-garden-prose", kind: .hidden)
    ]

    static let passages: [AcademyPassage] = foundingPassages
        + [.init(from: "location-book-burrow", to: facultyID, kind: .corridor),
           .init(from: facultyID, to: guestID, kind: .corridor)]
        + AcademyChapterRegistry.chapters.flatMap { chapter -> [AcademyPassage] in
            [.init(from: "location-book-burrow", to: commonRoomID(chapter.id), kind: .corridor),
             .init(from: commonRoomID(chapter.id), to: dormitoriesID(chapter.id), kind: .stair)]
        }

}

// MARK: - What the Book has drawn

/// Why a room is on the Book's map.
enum AcademyRoomSighting: Equatable, Sendable {
    /// Every reader has stood in it.
    case fromTheStart
    /// A surveyed room; knowing its walls does not claim a Reader visit.
    case charted
    /// A story was set there.
    case storyWentThere
    /// Something happened there that the room remembers.
    case somethingHappened
    /// The Book named it on a kept Page.
    case namedOnAPage(Date)
    /// The weather's let it in, just now.
    case theSkyOpenedIt
    /// This month's story has put something there: somebody, a notice, a
    /// shut door, or the room itself out of another book.
    case theMonthSaysSo
}

struct AcademyChartRoom: Identifiable, Equatable {
    var room: AcademyRoom
    /// Nil: still blank paper.
    var sighting: AcademyRoomSighting?
    var point: AcademyMapPoint
    /// Everything the Book writes beside the room, first line first.
    var lines: [String]
    /// Who's in there right now. All surveyed Academy rooms can hold Cast.
    var people: [AcademyWhereabout] = []
    /// Kept Pages that mention the room, newest first.
    var pages: [BookPage] = []

    var id: String { room.id }
    var isDrawn: Bool { sighting != nil }
}

struct AcademyChart: Equatable {
    var rooms: [AcademyChartRoom]
    /// Physical connections between the rooms currently on the paper.
    var passages: [AcademyPassage]

    var drawnCount: Int { rooms.filter(\.isDrawn).count }

    func room(_ id: String) -> AcademyChartRoom? { rooms.first { $0.id == id } }

    func isDrawn(_ id: String) -> Bool { room(id)?.isDrawn ?? false }

    /// Compatibility for charts supplied by other callers. The cartographer
    /// gives every current resident a drawn address, so its list stays empty.
    var unseen: [AcademyWhereabout] = []
    /// Rooms closed by the story or by their actual weather requirement.
    var closedRoomIDs: Set<String> = []
    /// Every way between rooms in play, drawn or not.
    var allPassages: [AcademyPassage] = AcademyGeography.passages
    /// People still walking after a recent change of room, and where they set off.
    /// They're on their way, and the map shows them walking.
    var arrivals: [String: AcademyArrival] = [:]
    /// The Reader's real Anchors open beyond the Outer Stacks. Kept apart
    /// from the Cast's route graph: a drawn door isn't a fictional visit.
    var anchorRooms: [AcademyAnchorRoom] = []

    /// The Book's line under the whole map.
    var footer: String {
        let count = rooms.flatMap(\.people).count
        let academy = "\(drawnCount) rooms. \(count) names. The walls stay. The feet don't."
        guard !anchorRooms.isEmpty else { return academy }
        let doors = anchorRooms.count == 1 ? "One door" : "\(anchorRooms.count) doors"
        return academy + " \(doors) in the Outer Stacks \(anchorRooms.count == 1 ? "opens" : "open") onto your places."
    }

    /// Somebody's gone somewhere off the map.
    var unseenLine: String? {
        switch unseen.count {
        case 0: return nil
        case 1: return "\(unseen[0].mapName)'s somewhere I haven't drawn yet."
        case 2: return "\(unseen[0].mapName) and \(unseen[1].mapName) are somewhere I haven't drawn yet."
        default: return "\(unseen[0].mapName) and \(unseen.count - 1) others are somewhere I haven't drawn yet."
        }
    }

    /// Where you can get to from a room: the drawn rooms by name, and the
    /// blank ones all together. A hidden way to a blank room isn't mentioned.
    /// That's what hidden means.
    func waysOut(from roomID: String) -> String? {
        var named: [String] = []
        var blank = 0
        for passage in allPassages where passage.touches(roomID) {
            guard let otherID = passage.other(than: roomID), let other = room(otherID) else { continue }
            if other.isDrawn {
                named.append(Self.inSentence(other.room.mapLabel))
            } else if passage.kind != .hidden {
                blank += 1
            }
        }
        let parts = named + (blank > 0 ? ["somewhere I haven't been yet"] : [])
        guard !parts.isEmpty else { return nil }
        return "From here you can get to \(Self.list(parts))."
    }

    /// "The Kitchens" as it sits in the middle of a sentence.
    static func inSentence(_ name: String) -> String {
        name.hasPrefix("The ") ? "the " + name.dropFirst(4) : name
    }

    static func list(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        default: return parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        }
    }
}

/// A room that already exists in the Anchor ledger, with its own kept Pages.
/// This is a projection for the map, not another store of Reader memories.
struct AcademyAnchorRoom: Identifiable, Equatable {
    var anchor: AnchorRecord
    var entry: GazetteerEntry
    var pages: [BookPage]
    var foldedWords: AcademyAnchorWords? = nil
    /// Days since the last recorded check-in, not a claim about where the
    /// Reader has actually been when the Book wasn't there.
    var quietDays: Int? = nil

    var id: String { "academy-anchor:\(anchor.id)" }
    var imprint: AcademyAnchorImprint { AcademyAnchorImprint.from(anchor) }

    static func project(anchors: [AnchorRecord], days: [BookDay], now: Date = Date(), calendar: Calendar = .current) -> [AcademyAnchorRoom] {
        var seen: Set<String> = []
        let anchors = anchors.filter {
            !$0.id.isEmpty && $0.name.nonEmpty != nil && seen.insert($0.id).inserted
        }
        // The existing ledger appends new Anchors. Preserve that order,
        // including two made on the same day; returns never move a door.
        guard !anchors.isEmpty else { return [] }
        let entries = Dictionary(uniqueKeysWithValues: Gazetteer.entries(anchors: anchors, days: days).map { ($0.id, $0) })
        var pages: [String: [BookPage]] = [:]
        for page in days.flatMap(\.pages) {
            guard let anchorID = page.context?.nearbyAnchorID?.nonEmpty else { continue }
            pages[anchorID, default: []].append(page)
        }
        return anchors.compactMap { anchor in
            guard let entry = entries[anchor.id] else { return nil }
            var pageIDs: Set<String> = []
            let kept = (pages[anchor.id] ?? []).sorted {
                $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt > $1.createdAt
            }.filter { pageIDs.insert($0.id).inserted }
            // A generated Page can contain both Book prose and a Reader's
            // reply. Only the Reader's sentence atoms go into the folded ink.
            let written = kept.compactMap { page -> AcademyAnchorWords? in
                guard let words = page.readerAuthoredTexts.first?.nonEmpty else { return nil }
                return AcademyAnchorWords(text: words, page: page)
            }.first ?? anchor.playerWords.nonEmpty.map { AcademyAnchorWords(text: $0, page: nil) }
            let elapsed = Gazetteer.daysSinceVisit(anchor, now: now, calendar: calendar)
            return AcademyAnchorRoom(
                anchor: anchor, entry: entry, pages: Array(kept.prefix(AcademyCartographer.pagesShown)),
                foldedWords: written,
                quietDays: elapsed.flatMap { $0 >= Gazetteer.goneQuietDays ? $0 : nil }
            )
        }
    }
}

struct AcademyAnchorWords: Equatable {
    var text: String
    /// Nil for the words given when the Anchor was made. A kept sentence
    /// carries its actual Page all the way to the map's opening callback.
    var page: BookPage?
}

/// Drawing instructions for the Book's fictional chamber. The noun comes
/// from material already kept for this Anchor; no new world facts are made.
struct AcademyAnchorImprint: Equatable {
    enum Motif: String, CaseIterable {
        case water, grove, hearth, library, way, lantern, threshold
    }
    enum Source: Equatable { case reader, place, book, spell }
    var motif: Motif
    var source: Source

    static func from(_ anchor: AnchorRecord) -> AcademyAnchorImprint {
        let cues: [(Motif, Set<String>)] = [
            (.water, ["river", "stream", "pond", "lake", "shore", "sea", "coast", "brook", "water", "rain", "beach"]),
            (.grove, ["tree", "trees", "forest", "woods", "garden", "orchard", "leaf", "leaves", "fern", "park", "allotment"]),
            (.hearth, ["kettle", "tea", "teapot", "teacup", "coffee", "cafe", "kitchen", "bakery", "stove", "hearth"]),
            (.library, ["book", "books", "bookshop", "bookstore", "library", "shelf", "shelves", "paper", "ink"]),
            (.way, ["path", "road", "lane", "bridge", "trail", "railway", "station", "train", "stairs"]),
            (.lantern, ["window", "lamp", "light", "candle", "lantern", "moon", "star", "stars", "sky", "sunset", "dawn"])
        ]
        func motif(in text: String) -> Motif? {
            let words = Set(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
            return cues.first { !$0.1.isDisjoint(with: words) }?.0
        }
        // Fixed material chooses the architecture. New kept sentences fill
        // its drawers; they do not rebuild the room around yesterday's mood.
        if let found = motif(in: anchor.playerWords + " " + anchor.name) {
            return AcademyAnchorImprint(motif: found, source: .reader)
        }
        if let found = anchor.place.flatMap({ motif(in: $0.category) }) {
            return AcademyAnchorImprint(motif: found, source: .place)
        }
        if let found = motif(in: anchor.outerStacksRoom) {
            return AcademyAnchorImprint(motif: found, source: .book)
        }
        return AcademyAnchorImprint(motif: .threshold, source: .spell)
    }
}

struct AcademyChartInputs {
    var days: [BookDay] = []
    var placeStates: [String: PlaceState] = [:]
    var storySettingAffinities: [String: Int] = [:]
    /// The real sky right now, when the Book can honestly claim it.
    var sky: SkyCondition?
    /// The reader's own places, by name. Each is a door in the Outer Stacks.
    var anchorNames: [String] = []
    /// The same ledger used by the Atlas and Gazetteer. Names alone remain
    /// supported for older callers, but only real records become drawn rooms.
    var anchors: [AnchorRecord] = []
    /// Pages on the desk right now. Whatever they're about is happening now.
    var deskScenes: [AcademyScene] = []
    /// What the live month's story says about the Academy.
    var events = AcademyEventStaging()
    /// The month's events themselves. When they're here, the chart works out
    /// `events` from them at its own moment, so it keeps up as time passes.
    var worldEvents: [WorldEvent]? = nil
    var now: Date = Date()
    var calendar: Calendar = .current

    /// Registered Cast, including the Reader's custom characters. Monthly
    /// visitors remain temporary guests rather than entering this roster.
    var cast: [NarrativeWorldEntity] = NarrativePackRegistry.entities.filter { $0.kind == .character }
    var readerChapterID: String? = nil

    /// The same inputs, at another moment.
    func at(_ date: Date) -> AcademyChartInputs {
        var moved = self
        moved.now = date
        return moved
    }
}

enum AcademyCartographer {
    /// Doors to the reader's places listed beside the Outer Stacks. More than
    /// this and the margin's a phone book.
    static let anchorDoorsShown = 3

    /// Kept Pages linked from a room. Enough to follow a thread back; more
    /// and the note turns into a filing cabinet.
    static let pagesShown = 5

    static func chart(_ inputs: AcademyChartInputs) -> AcademyChart {
        var inputs = inputs
        // Worked out afresh at this moment, so a staged hour or a new phase
        // arrives while the map's open.
        if let worldEvents = inputs.worldEvents {
            inputs.events = AcademyEventStaging.from(events: worldEvents, now: inputs.now, calendar: inputs.calendar)
        }
        // The Rain Room stays on the paper, with its door shut when the
        // actual sky hasn't opened it. Nobody is routed through a shut door.
        for room in AcademyGeography.rooms {
            if case .weatherGated(let skies) = room.stability,
               inputs.sky.map({ skies.contains($0) }) != true {
                inputs.events.closedRoomIDs.insert(room.id)
            }
        }
        inputs.events.borrowedRooms = AcademyGeography.surveyedBorrowedRooms(inputs.events.borrowedRooms, passages: inputs.events.borrowedPassages, chapterID: inputs.readerChapterID)
        let staging = inputs.events
        let mentions = mentions(in: inputs.days)
        let session = AcademyScheduleRegistry.sessionInProgress(at: inputs.now, calendar: inputs.calendar)?.session
        let everyone = AcademyWhereabouts.everyone(
            at: inputs.now,
            calendar: inputs.calendar,
            scenes: inputs.deskScenes + recentScenes(inputs),
            staging: staging, cast: inputs.cast
        )
        let staged = Set(staging.staging.map(\.roomID))
            .union(staging.closedRoomIDs)
            .union(staging.roomNotes.keys)
            .union(staging.borrowedRooms.map(\.id))

        let rooms = staging.rooms.map { original -> AcademyChartRoom in
            let room = original.id == AcademyGeography.dormID
                ? AcademyGeography.homeRoom(chapterID: inputs.readerChapterID) : original
            let sighting = sighting(of: room, inputs: inputs, named: mentions[room.id]?.firstNamed)
                ?? (staged.contains(room.id) && room.id != AcademyGeography.dormID ? .theMonthSaysSo : .charted)
            let people = everyone.filter { $0.roomID == room.id }
            return AcademyChartRoom(
                room: room,
                sighting: sighting,
                point: AcademyGeography.point(of: room, on: inputs.now, calendar: inputs.calendar),
                lines: notes(for: room, inputs: inputs, session: session, people: people),
                people: people,
                pages: mentions[room.id]?.recent ?? []
            )
        }
        let drawn = Set(rooms.filter(\.isDrawn).map(\.id))
        let allPassages = AcademyGeography.homePassages(chapterID: inputs.readerChapterID) + staging.borrowedPassages
        let passages = allPassages.filter { drawn.contains($0.from) || drawn.contains($0.to) }
        return AcademyChart(
            rooms: rooms,
            passages: passages,
            unseen: everyone.filter { !drawn.contains($0.roomID) },
            closedRoomIDs: staging.closedRoomIDs,
            allPassages: allPassages,
            arrivals: journeys(for: everyone, inputs: inputs, staging: staging, passages: allPassages),
            anchorRooms: AcademyAnchorRoom.project(anchors: inputs.anchors, days: inputs.days, now: inputs.now, calendar: inputs.calendar)
        )
    }

    /// Recover recent departures even when nobody had the map open. Each
    /// walk belongs to a real change of address, never a roll of the dice.
    private static func journeys(for everyone: [AcademyWhereabout], inputs: AcademyChartInputs,
                                 staging: AcademyEventStaging, passages: [AcademyPassage]) -> [String: AcademyArrival] {
        let since = inputs.now.addingTimeInterval(-AcademyArrival.longestWalk)
        let minute = inputs.calendar.dateInterval(of: .minute, for: inputs.now)?.start ?? inputs.now
        var boundaries = Set((0...Int(AcademyArrival.longestWalk / 60)).map {
            minute.addingTimeInterval(-Double($0) * 60)
        })
        // Story Pages may arrive between minute ticks, or release their Cast
        // when a scene stops lingering. Keep the actual story clock.
        let scenes = inputs.deskScenes + staging.scenes + recentScenes(inputs) + recentScenes(inputs.at(since))
        for scene in scenes {
            boundaries.insert(scene.at)
            boundaries.insert(scene.at.addingTimeInterval(AcademyWhereabouts.sceneLingers))
        }
        let roomIDs = Set(staging.rooms.map(\.id))
        var pending = Dictionary(everyone.map { ($0.characterID, $0) }, uniquingKeysWith: { first, _ in first })
        var arrivals: [String: AcademyArrival] = [:]
        for boundary in boundaries.filter({ $0 > since && $0 <= inputs.now }).sorted(by: >) {
            var before = inputs.at(boundary.addingTimeInterval(-0.001))
            if let worldEvents = before.worldEvents {
                before.events = AcademyEventStaging.from(events: worldEvents, now: before.now, calendar: before.calendar)
            }
            before.events.closedRoomIDs.formUnion(staging.closedRoomIDs.filter { id in
                guard let room = AcademyGeography.room(id: id) else { return false }
                if case .weatherGated = room.stability { return true }
                return false
            })
            let earlier = Dictionary(AcademyWhereabouts.everyone(
                at: before.now, calendar: before.calendar,
                scenes: inputs.deskScenes + recentScenes(before), staging: before.events, cast: inputs.cast
            ).map { ($0.characterID, $0.roomID) }, uniquingKeysWith: { first, _ in first })
            for (id, person) in pending {
                guard earlier[id] != person.roomID else { continue }
                // Stop at the latest move. A newly appearing visitor or a
                // vanished borrowed room has no walkable departure to invent.
                pending.removeValue(forKey: id)
                guard let from = earlier[id], roomIDs.contains(from), roomIDs.contains(person.roomID),
                      let arrival = AcademyArrival.departing(person, from: from, at: boundary,
                                                           passages: passages, closedRoomIDs: staging.closedRoomIDs),
                      arrival.isUnderway(at: inputs.now) else { continue }
                arrivals[id] = arrival
            }
            if pending.isEmpty { break }
        }
        return arrivals
    }

    /// Scenes from Pages kept in the last few hours, and from things the
    /// rooms remember happening in them just now.
    static func recentScenes(_ inputs: AcademyChartInputs) -> [AcademyScene] {
        let since = inputs.now.addingTimeInterval(-AcademyWhereabouts.sceneLingers)
        let kept = inputs.days
            .filter { $0.date >= inputs.calendar.startOfDay(for: since) }
            .flatMap(\.pages)
            .filter { $0.createdAt >= since }
            .compactMap { page in
                page.metadata.flatMap { AcademyScene(metadata: $0, at: page.createdAt, pageID: page.id,
                                                     cast: inputs.cast, rooms: inputs.events.rooms) }
            }
        let remembered = inputs.placeStates.values.flatMap { state in
            state.incidents
                .filter { $0.occurredAt >= since && !$0.participantIDs.isEmpty }
                .map { AcademyScene(roomID: state.id, castIDs: $0.participantIDs, at: $0.occurredAt) }
        }
        .filter { AcademyGeography.room(id: $0.roomID) != nil }
        return remembered + kept
    }

    static func sighting(
        of room: AcademyRoom,
        inputs: AcademyChartInputs,
        named: Date?
    ) -> AcademyRoomSighting? {
        // Weather records an open door. The surveyed walls remain charted
        // even when the actual sky has closed it.
        if case .weatherGated(let skies) = room.stability {
            guard let sky = inputs.sky, skies.contains(sky) else { return nil }
            return .theSkyOpenedIt
        }
        if room.startsDrawn { return .fromTheStart }
        if (inputs.storySettingAffinities[room.id] ?? 0) > 0 { return .storyWentThere }
        if let state = inputs.placeStates[room.id], !state.incidents.isEmpty { return .somethingHappened }
        if let named { return .namedOnAPage(named) }
        return nil
    }

    struct Mentions: Equatable {
        /// The first time the Book's own prose named the room.
        var firstNamed: Date
        /// The latest kept Pages that did, newest first.
        var recent: [BookPage]
    }

    /// Where the Book's own prose names each room, from the archive.
    ///
    /// Only Pages the Book wrote count as Academy references; the Reader's
    /// own pantry never becomes a visit to the Academy's. A generated Page often keeps the Book's prose in
    /// `userInput` rather than `promptText`, so both are read.
    /// Memoised: the whole archive is read, and only a kept Page changes it.
    static func mentions(in days: [BookDay]) -> [String: Mentions] {
        ArchiveMemo.value("academy.room-mentions", days: days) {
            let searchable = AcademyGeography.rooms.filter { !$0.names.isEmpty }
            var found: [String: Mentions] = [:]
            let pages = days.flatMap(\.pages)
                .filter { $0.origin != .userAuthored }
                .sorted { $0.createdAt > $1.createdAt }
            for page in pages {
                let prose = page.promptText + "\n" + page.userInput
                guard prose.count > 1 else { continue }
                for room in searchable where room.names.contains(where: { prose.contains($0) }) {
                    var mention = found[room.id] ?? Mentions(firstNamed: page.createdAt, recent: [])
                    mention.firstNamed = min(mention.firstNamed, page.createdAt)
                    if mention.recent.count < pagesShown { mention.recent.append(page) }
                    found[room.id] = mention
                }
            }
            return found
        }
    }

    static func notes(
        for room: AcademyRoom,
        inputs: AcademyChartInputs,
        session: AcademySession?,
        people: [AcademyWhereabout] = []
    ) -> [String] {
        var lines = [room.note]
        if case .weatherGated = room.stability, inputs.events.closedRoomIDs.contains(room.id) {
            lines = ["The door's shut. It wants rain."]
        }

        if room.id == "location-outer-stacks" {
            let names = inputs.anchors.isEmpty ? inputs.anchorNames : inputs.anchors.map(\.name)
            for name in names.prefix(anchorDoorsShown) {
                lines.append("There's a door here that opens onto \(name).")
            }
            if names.count > anchorDoorsShown {
                lines.append("There are more. Follow the shelves up the map.")
            }
        }

        if inputs.events.closedRoomIDs.contains(room.id) {
            lines.append("It's shut. Nobody's allowed in.")
        }
        lines += inputs.events.roomNotes[room.id] ?? []
        // Wherever the teacher is, the class is: a class in a shut room has
        // moved with them.
        if let session, people.contains(where: { $0.why == .teaching }) {
            lines.append(inSession(session))
        }
        lines += whosHere(people.filter { $0.why != .teaching }, hour: inputs.calendar.component(.hour, from: inputs.now))

        if let state = inputs.placeStates[room.id] {
            if let refusal = state.refusal?.nonEmpty {
                lines.append("It \(refusal).")
            }
            if let latest = state.incidents.last?.line.nonEmpty {
                lines.append(latest)
            }
        }
        return lines
    }

    /// More than this many and the Book stops naming everybody.
    static let crowdNamed = 5

    /// What the Book says about who's in a room, a line per reason they're
    /// there. The story's own notes are said as written.
    static func whosHere(_ people: [AcademyWhereabout], hour: Int = 10) -> [String] {
        var lines: [String] = []
        lines += people.compactMap { $0.why == .staged ? $0.note : nil }
        func say(_ group: [AcademyWhereabout], _ one: String, _ many: String) {
            let names = group.map(\.mapName)
            switch names.count {
            case 0: break
            case 1: lines.append("\(names[0])'s \(one)")
            case 2...crowdNamed: lines.append("\(AcademyChart.list(names)) are \(many)")
            default:
                let named = names.prefix(3).joined(separator: ", ")
                lines.append("\(named) and \(names.count - 3) others are \(many)")
            }
        }
        say(people.filter { $0.why == .staged && $0.note == nil }, "here, and it's to do with the story.", "here, and it's to do with the story.")
        say(people.filter { $0.why == .scene }, "here because of today's Page.", "here because of today's Page.")
        let meal = hour < 10 ? "breakfast" : hour < 16 ? "lunch" : "supper"
        say(people.filter { $0.why == .eating }, "having \(meal) in here.", "having \(meal) in here.")
        say(people.filter { $0.why == .sleeping }, "asleep. Mind your feet.", "asleep. Mind your feet.")
        say(people.filter { $0.why == .attending || $0.why == .haunt }, "in here right now.", "in here right now.")
        return lines
    }

    static func inSession(_ session: AcademySession) -> String {
        switch session.kind {
        case .classSession:
            let teacher = shortName(session.leader)
            return "\(teacher)'s teaching \(session.name) in here right now."
        case .club:
            return "\(session.name)'s meeting in here right now."
        }
    }

    /// "Professor Lydia Boggle (officially)" is Boggle to the Book.
    private static func shortName(_ leader: String) -> String {
        let bare = leader.components(separatedBy: " (").first ?? leader
        return bare.split(separator: " ").last.map(String.init) ?? bare
    }
}

// MARK: - Where everybody is

/// One Cast member, somewhere in the Academy, right now.
struct AcademyWhereabout: Equatable, Sendable {
    enum Why: Equatable, Sendable {
        /// The month's story has put them here, for as long as it lasts.
        case staged
        /// A Page happened here, today or on the desk right now.
        case scene
        /// Their class is on and they're teaching it.
        case teaching
        /// A class or club is on and they're in it.
        case attending
        /// It's a mealtime.
        case eating
        /// Their authored routine has taken them to their own quarters.
        case sleeping
        /// Nothing's on. This is just where they tend to be at this hour.
        case haunt
    }

    var characterID: String
    var name: String
    /// What the Book calls them on the map: first names for students,
    /// surnames for staff.
    var mapName: String
    var roomID: String
    var why: Why
    /// A line the story left about why they're here, if it left one.
    var note: String? = nil
    /// Not one of the Cast: somebody out of another book, with no page to open.
    var isVisitor = false
}

// MARK: - What the story says

/// A scene: a room, and the Cast in it, at a time.
///
/// Read straight from a Page's metadata, on the desk or kept. Producers can
/// name the room and Cast outright with `academyRoomID` / `academyCastIDs`;
/// older and differently-shaped Pages are read through the keys they already
/// carry (a Story Page's setting, a class's room, a gossip scene's place).
struct AcademyScene: Equatable, Sendable {
    static let roomKey = "academyRoomID"
    static let castKey = "academyCastIDs"

    var roomID: String
    var castIDs: [String]
    var at: Date
    var pageID: String?

    init(roomID: String, castIDs: [String], at: Date, pageID: String? = nil) {
        self.roomID = roomID
        self.castIDs = castIDs
        self.at = at
        self.pageID = pageID
    }

    /// Nil when the metadata doesn't name a room on the map, or names nobody.
    init?(metadata: [String: String], at: Date, pageID: String? = nil,
          cast roster: [NarrativeWorldEntity] = NarrativePackRegistry.entities.filter { $0.kind == .character },
          rooms: [AcademyRoom] = AcademyGeography.rooms) {
        let room = [
            metadata[Self.roomKey],
            metadata["storySettingID"],
            metadata["placeID"],
            metadata["sessionRoom"].flatMap { AcademyGeography.room(forTimetableName: $0)?.id }
        ]
        .compactMap { $0?.nonEmpty }
        .first { id in rooms.contains { $0.id == id } }
        guard let room else { return nil }

        let listed = [metadata[Self.castKey], metadata["selectedEntityIDs"], metadata["undertakingCast"], metadata["actorIDs"]]
            .compactMap { $0?.nonEmpty }
            .first
            .map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } } ?? []
        let single = [metadata["actorID"], metadata["characterID"], metadata["sessionLeaderEntityID"], metadata["storyRecipeLeadID"]]
            .compactMap { $0?.nonEmpty }
        let knownCast = Set(roster.filter { $0.kind == .character }.map(\.id))
        let names = Dictionary(roster.filter { $0.kind == .character }.map { ($0.name.lowercased(), $0.id) },
                               uniquingKeysWith: { first, _ in first })
        let companions = (metadata["sessionCompanions"] ?? "")
            .split(separator: ",")
            .compactMap { names[$0.trimmingCharacters(in: .whitespaces).lowercased()] }
        var seen: Set<String> = []
        let cast = (listed + single + companions).filter { knownCast.contains($0) && seen.insert($0).inserted }
        guard !cast.isEmpty else { return nil }
        self.init(roomID: room, castIDs: cast, at: at, pageID: pageID)
    }
}

extension BookPage {
    /// Where this Page happened and who was there, if it says.
    var academyScene: AcademyScene? {
        metadata.flatMap { AcademyScene(metadata: $0, at: createdAt, pageID: id) }
    }
}

/// Someone the month's story has put somewhere.
///
/// Day windows count from the start of the stage they belong to: live day 0
/// is the first day of the month's issue; for the foreshadow and residue
/// weeks, day 0 is the first day of that week. Hours are the reader's local
/// clock, `fromHour` inclusive and `untilHour` exclusive, and may wrap past
/// midnight (20 until 6).
struct AcademyStaging: Codable, Equatable, Sendable {
    var castID: String
    var roomID: String
    /// The Book, on why they're there. Shown in the room's note.
    var note: String? = nil
    /// Somebody who isn't one of the Cast: a visitor out of another book.
    /// Drawn with their name, and nothing to open.
    var name: String? = nil
    var fromDay: Int? = nil
    var throughDay: Int? = nil
    var fromHour: Int? = nil
    var untilHour: Int? = nil

    func applies(day: Int, hour: Int) -> Bool {
        AcademyStagingWindow.contains(day: day, hour: hour, fromDay: fromDay, throughDay: throughDay,
                                      fromHour: fromHour, untilHour: untilHour)
    }
}

/// A line the month's story writes beside a room.
struct AcademyStagedNote: Codable, Equatable, Sendable {
    var roomID: String
    var note: String
    var fromDay: Int? = nil
    var throughDay: Int? = nil

    func applies(day: Int) -> Bool {
        AcademyStagingWindow.contains(day: day, hour: 12, fromDay: fromDay, throughDay: throughDay, fromHour: nil, untilHour: nil)
    }
}

/// A room out of another book that's pushed its way into the Academy for a
/// while. Drawn in a different ink, and gone again when its window ends.
struct AcademyBorrowedRoom: Codable, Equatable, Sendable {
    struct Join: Codable, Equatable, Sendable {
        var roomID: String
        var kind: String? = nil
    }

    var id: String
    var name: String
    var note: String
    var x: Double
    var y: Double
    var width: Double = 0.14
    var height: Double = 0.05
    var form: String? = nil
    var joins: [Join]
    var fromDay: Int? = nil
    var throughDay: Int? = nil

    func applies(day: Int) -> Bool {
        AcademyStagingWindow.contains(day: day, hour: 12, fromDay: fromDay, throughDay: throughDay, fromHour: nil, untilHour: nil)
    }

    var room: AcademyRoom {
        AcademyRoom(
            id: id, name: name, zone: .labyrinth, compass: nil, stability: .fixed,
            point: AcademyMapPoint(x, y), startsDrawn: false, names: [name], note: note,
            form: form.flatMap(AcademyRoomForm.init(rawValue:)) ?? .room,
            size: AcademyMapPoint(width, height), isBorrowed: true
        )
    }

    var passages: [AcademyPassage] {
        joins.map { AcademyPassage(from: $0.roomID, to: id, kind: $0.kind.flatMap(AcademyPassageKind.init(rawValue:)) ?? .door) }
    }
}

/// Everything the month's story says about the Academy for one stretch of
/// it: a phase of the live issue, or the week before or after.
struct AcademyStagingSet: Codable, Equatable, Sendable {
    var staging: [AcademyStaging]? = nil
    var closedRoomIDs: [String]? = nil
    var roomNotes: [AcademyStagedNote]? = nil
    var borrowedRooms: [AcademyBorrowedRoom]? = nil
}

enum AcademyStagingWindow {
    static func contains(day: Int, hour: Int, fromDay: Int?, throughDay: Int?, fromHour: Int?, untilHour: Int?) -> Bool {
        if let fromDay, day < fromDay { return false }
        if let throughDay, day > throughDay { return false }
        guard let fromHour, let untilHour, fromHour != untilHour else { return true }
        return fromHour < untilHour
            ? (fromHour..<untilHour).contains(hour)
            : hour >= fromHour || hour < untilHour
    }
}

/// Everything the live month says about the Academy right now.
struct AcademyEventStaging: Equatable, Sendable {
    var staging: [AcademyStaging] = []
    var closedRoomIDs: Set<String> = []
    /// Scenes the story says are happening right now.
    var scenes: [AcademyScene] = []
    /// Lines the story's written beside rooms, by room.
    var roomNotes: [String: [String]] = [:]
    /// Rooms out of other books, in the Academy for now.
    var borrowedRooms: [AcademyRoom] = []
    var borrowedPassages: [AcademyPassage] = []

    /// Every room the map can have right now: the Academy's own, and any
    /// that have been borrowed.
    var rooms: [AcademyRoom] { AcademyGeography.rooms + borrowedRooms }

    func room(id: String) -> AcademyRoom? {
        AcademyGeography.room(id: id) ?? borrowedRooms.first { $0.id == id }
    }

    /// The enabled packs' events, read at `now`: the phase they're in and the
    /// beats that are open.
    static func live(now: Date, calendar: Calendar = .current) -> AcademyEventStaging {
        from(events: WorldEventRegistry.enabledEvents().map(\.event), now: now, calendar: calendar)
    }

    static func from(events: [WorldEvent], now: Date, calendar: Calendar = .current) -> AcademyEventStaging {
        var result = AcademyEventStaging()
        let hour = calendar.component(.hour, from: now)
        func days(from start: Date) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0
        }
        for event in events {
            guard let interval = event.calendar.scheduledInterval(near: now, calendar: calendar) else { continue }
            if interval.contains(now) {
                let progress = interval.duration > 0 ? now.timeIntervalSince(interval.start) / interval.duration : 0
                let day = days(from: interval.start)
                if let phase = event.phases
                    .filter({ $0.startsAtProgress <= progress })
                    .max(by: { $0.startsAtProgress < $1.startsAtProgress }) {
                    result.add(phase.academy, day: day, hour: hour)
                }
                // A beat's window runs for days, so it doesn't pin anybody
                // anywhere by itself. Its Page does, on the desk or once kept.
            } else if now < interval.start, now >= event.calendar.foreshadowStarts(for: interval, calendar: calendar),
                      let set = event.foreshadowAcademy {
                result.add(set, day: days(from: event.calendar.foreshadowStarts(for: interval, calendar: calendar)), hour: hour)
            } else if now >= interval.end, now < event.calendar.residueEnds(for: interval, calendar: calendar),
                      let set = event.residueAcademy {
                result.add(set, day: days(from: interval.end), hour: hour)
            }
        }
        return result
    }

    mutating func add(_ set: AcademyStagingSet, day: Int, hour: Int) {
        let borrowed = (set.borrowedRooms ?? []).filter { $0.applies(day: day) }
        borrowedRooms += borrowed.map(\.room)
        borrowedPassages += borrowed.flatMap(\.passages)
        staging += (set.staging ?? []).filter { $0.applies(day: day, hour: hour) }
        closedRoomIDs.formUnion(set.closedRoomIDs ?? [])
        for note in (set.roomNotes ?? []) where note.applies(day: day) {
            roomNotes[note.roomID, default: []].append(note.note)
        }
    }
}

extension WorldEventPhase {
    /// This phase's staging, gathered into one set.
    var academy: AcademyStagingSet {
        AcademyStagingSet(staging: staging, closedRoomIDs: closedRoomIDs, roomNotes: roomNotes, borrowedRooms: borrowedRooms)
    }
}

// MARK: - Everybody's day

/// Where the Cast are, worked out the way a school works it out. The story
/// comes first: the month's staging, then whatever's happening on the desk
/// or happened on a Page in the last few hours. Then the timetable. Then
/// everybody's own day: meals in the Great Hall, the places they drift to,
/// and bed.
///
/// Deterministic. The same inputs at the same time always put the same people
/// in the same rooms, so the map doesn't shuffle while it's being looked at,
/// and people move when the hour does.
enum AcademyWhereabouts {
    /// How long people stay where a Page left them.
    static let sceneLingers: TimeInterval = 3 * 60 * 60

    struct Haunt: Sendable {
        var characterID: String
        var mapName: String
        /// Where they drift in the day, outside class. Picked afresh every
        /// two hours.
        var day: [String]
        /// After supper.
        var evening: [String]
        /// Explicit night haunts for the people who stay awake. Empty means
        /// they go to their Chapter's dormitories or the faculty quarters.
        var night: [String] = []
        /// Where they eat. Nil means they don't stop for meals.
        var meals: String? = AcademyWhereabouts.greatHall
        /// False for whoever's cooking it: they're at the table's other end.
        var eatsAtMeals = true
    }

    static let greatHall = "location-great-hall"

    /// The hours meals are on.
    static let mealHours: Set<Int> = [7, 12, 18]

    /// Nobody but the reader is ever in the Dorm. It's theirs.
    static let haunts: [Haunt] = [
        Haunt(characterID: "penny-blackletter", mapName: "Penny",
              day: ["location-stacks", "location-corridor-whispered"],
              evening: ["location-stacks", "location-great-hall"],
              night: ["location-stacks"], meals: nil),
        Haunt(characterID: "headmistress-thorne", mapName: "Thorne",
              day: ["location-headmistress-tower"],
              evening: ["location-great-hall", "location-headmistress-tower"],
              night: ["location-headmistress-tower"], meals: "location-headmistress-tower"),
        Haunt(characterID: "wicker-eddies", mapName: "Wicker",
              day: ["location-spark-annex", "location-great-hall", "location-vault-of-doors"],
              evening: ["location-east-stacks", "location-bibliophonic-hall", "location-great-hall"],
              night: ["location-east-stacks", "location-vault-of-doors"]),
        Haunt(characterID: "serenity-brown", mapName: "Serenity",
              day: ["location-quillquarium", "location-open-field-gate", "location-kitchens"],
              evening: ["location-book-burrow"]),
        Haunt(characterID: "zara-finch", mapName: "Zara",
              day: ["location-glint-hall", "location-inkworks"],
              evening: ["location-secret-garden-prose", "location-book-burrow"]),
        Haunt(characterID: "finn-bridges", mapName: "Finn",
              day: ["location-momentum-yard", "location-open-field-gate"],
              evening: ["location-open-field-gate", "location-kitchens"]),
        Haunt(characterID: "lysander-mosswood", mapName: "Lysander",
              day: ["location-walled-garden", "location-open-field-gate"],
              evening: ["location-walled-garden"]),
        Haunt(characterID: "min-seo-kim", mapName: "Min-seo",
              day: ["location-walled-garden", "location-kitchens"],
              evening: ["location-book-burrow", "location-kitchens"]),
        Haunt(characterID: "damien-nights", mapName: "Damien",
              day: ["location-stacks", "location-corridor-whispered"],
              evening: ["location-corridor-whispered", "location-bibliophonic-hall"],
              night: ["location-corridor-whispered"]),
        Haunt(characterID: "melisande-blackwood", mapName: "Melisande",
              day: ["location-great-hall", "location-corridor-whispered"],
              evening: ["location-great-hall"]),
        Haunt(characterID: "orion-blackthorn", mapName: "Orion",
              day: ["location-north-staircase", "location-glint-hall", "location-east-stacks"],
              evening: ["location-north-staircase", "location-great-hall"]),
        Haunt(characterID: "gwendolyn-mythwright", mapName: "Gwendolyn",
              day: ["location-stacks", "location-walled-garden"],
              evening: ["location-bibliophonic-hall", "location-stacks"]),
        Haunt(characterID: "soren-ng", mapName: "Soren",
              day: ["location-stacks", "location-glint-hall", "location-corridor-whispered"],
              evening: ["location-book-burrow", "location-corridor-whispered"]),
        Haunt(characterID: "dr-inkrest", mapName: "Dr. Inkrest",
              day: ["location-still-room", "location-book-burrow"],
              evening: ["location-still-room"]),
        Haunt(characterID: "dr-vellum", mapName: "Dr. Vellum",
              day: ["location-kitchens", "location-open-field-gate"],
              evening: ["location-kitchens"]),
        Haunt(characterID: "ambrose-trencher", mapName: "Ambrose",
              day: ["location-kitchens", "location-pantry"],
              evening: ["location-kitchens"], meals: "location-kitchens", eatsAtMeals: false),
        Haunt(characterID: "lydia-boggle", mapName: "Boggle",
              day: ["location-glint-hall"],
              evening: ["location-corridor-whispered", "location-great-hall"]),
        Haunt(characterID: "professor-kyle-momort", mapName: "Momort",
              day: ["location-momentum-yard", "location-open-field-gate"],
              evening: ["location-great-hall"]),
        Haunt(characterID: "professor-eleanor-euphony", mapName: "Euphony",
              day: ["location-resonance-chamber"],
              evening: ["location-resonance-chamber", "location-great-hall"]),
        Haunt(characterID: "professor-vivian-villanelle", mapName: "Villanelle",
              day: ["location-inkworks"],
              evening: ["location-inkworks", "location-bibliophonic-hall"]),
        Haunt(characterID: "professor-cedric-stonebrook", mapName: "Stonebrook",
              day: ["location-still-room", "location-open-field-gate"],
              evening: ["location-still-room"]),
        Haunt(characterID: "professor-luna-wispwood", mapName: "Wispwood",
              day: ["location-spark-annex"],
              evening: ["location-spark-annex", "location-great-hall"]),
        Haunt(characterID: "professor-permancer", mapName: "Permancer",
              day: ["location-vault-of-doors"],
              evening: ["location-vault-of-doors", "location-great-hall"])
    ]

    private static let hauntsByID: [String: Haunt] = Dictionary(uniqueKeysWithValues: haunts.map { ($0.characterID, $0) })

    static func haunt(_ id: String) -> Haunt? { hauntsByID[id] }

    /// Full names from the bundled Cast, so lists that spell people out in
    /// full (the timetable's companions) can find them.
    static let castNames: [String: String] = {
        var names: [String: String] = [:]
        for entity in NarrativePackRegistry.bundledPacks.flatMap(\.entities) where entity.kind == .character {
            names[entity.id] = entity.name
        }
        return names
    }()

    private static let idsByName: [String: String] = Dictionary(
        castNames.map { ($0.value.lowercased(), $0.key) }, uniquingKeysWith: { first, _ in first }
    )

    static func id(forName name: String) -> String? { idsByName[name.lowercased()] }

    /// Everyone, right now.
    ///
    /// - Parameters:
    ///   - scenes: Pages on the desk now and Pages kept recently. Only the
    ///     last `sceneLingers` of them count, and the newest wins.
    ///   - staging: what the live month says.
    static func everyone(
        at date: Date,
        calendar: Calendar = .current,
        scenes: [AcademyScene] = [],
        staging: AcademyEventStaging = AcademyEventStaging(),
        cast: [NarrativeWorldEntity] = NarrativePackRegistry.entities.filter { $0.kind == .character }
    ) -> [AcademyWhereabout] {
        var rosterIDs: Set<String> = []
        let roster = cast.filter { $0.kind == .character && rosterIDs.insert($0.id).inserted }
        let hour = calendar.component(.hour, from: date)
        let dayIndex = GrimoireDay.index(for: date, calendar: calendar)
        let session = AcademyScheduleRegistry.sessionInProgress(at: date, calendar: calendar)?.session
        let closed = staging.closedRoomIDs
        let refuge = [greatHall, "location-book-burrow", "location-stacks"].first { !closed.contains($0) }
            ?? staging.rooms.first { $0.id != AcademyGeography.dormID && !closed.contains($0.id) }?.id
        // A class held in a shut room moves to the Great Hall. Everybody
        // squeezes in.
        let sessionRoom = session
            .flatMap { AcademyGeography.room(forTimetableName: $0.room)?.id }
            .flatMap { closed.contains($0) ? refuge : $0 }

        var storyRoom: [String: (room: String, why: AcademyWhereabout.Why, note: String?)] = [:]
        let recent = (scenes + staging.scenes)
            .filter { date.timeIntervalSince($0.at) >= 0 && date.timeIntervalSince($0.at) < sceneLingers }
            .sorted { $0.at < $1.at }
        for scene in recent where staging.room(id: scene.roomID) != nil && !closed.contains(scene.roomID) {
            for id in scene.castIDs { storyRoom[id] = (scene.roomID, .scene, nil) }
        }
        // Staging outranks a passing scene: it's the month's whole story.
        for staged in staging.staging where staging.room(id: staged.roomID) != nil && !closed.contains(staged.roomID) {
            storyRoom[staged.castID] = (staged.roomID, .staged, staged.note?.nonEmpty)
        }
        // People out of other books. They only go where the story puts them.
        var seenVisitors: Set<String> = []
        let visitors = staging.staging
            .filter { !rosterIDs.contains($0.castID) && staging.room(id: $0.roomID) != nil && !closed.contains($0.roomID) && $0.roomID != AcademyGeography.dormID }
            .reversed()
            .filter { seenVisitors.insert($0.castID).inserted }
            .map { staged in
                AcademyWhereabout(characterID: staged.castID, name: staged.name ?? staged.castID,
                                  mapName: staged.name ?? staged.castID, roomID: staged.roomID,
                                  why: .staged, note: staged.note?.nonEmpty, isVisitor: true)
            }

        return visitors + roster.compactMap { entity in
            let chapterID = AcademyChapterRegistry.chapter(named: entity.chapter)?.id
            let quarters = residence(for: entity)
            let common = chapterID.map(AcademyGeography.commonRoomID) ?? "location-book-burrow"
            var haunt = hauntsByID[entity.id] ?? Haunt(
                characterID: entity.id, mapName: shortName(entity), day: [common, "location-stacks"], evening: [common]
            )
            if haunt.night.isEmpty { haunt.night = [quarters] }
            // Supper is still supper. The quiet hours before bed belong to
            // the Chapter; professors can retreat to their own landing.
            if hour >= 19 && hour < 22 {
                haunt.evening = [isStaff(entity) ? quarters : common]
            }
            let name = entity.name
            func here(_ room: String, _ why: AcademyWhereabout.Why, _ note: String? = nil) -> AcademyWhereabout {
                AcademyWhereabout(characterID: haunt.characterID, name: name, mapName: haunt.mapName,
                                  roomID: room, why: why, note: note)
            }
            if let story = storyRoom[haunt.characterID], story.room != AcademyGeography.dormID, !closed.contains(story.room) {
                return here(story.room, story.why, story.note)
            }
            if let session, let sessionRoom {
                if session.leaderEntityID == haunt.characterID {
                    return here(sessionRoom, session.kind == .classSession ? .teaching : .attending)
                }
                if session.companions.contains(name) {
                    return here(sessionRoom, .attending)
                }
            }
            if let usual = routine(for: haunt, hour: hour, dayIndex: dayIndex, closed: closed) {
                return here(usual.room, (hour >= 22 || hour < 7) && usual.room == quarters ? .sleeping : usual.why)
            }
            // A month can shut both their usual rooms and the Great Hall.
            // They still have feet: find an open landing elsewhere.
            return ([quarters, common].first { !closed.contains($0) } ?? refuge).map { here($0, .haunt) }
        }
    }

    private static func isStaff(_ entity: NarrativeWorldEntity) -> Bool {
        entity.tags.contains { ["professor", "faculty", "support-faculty", "staff", "headmistress"].contains($0) }
            || entity.id.hasPrefix("professor-") || entity.id == "lydia-boggle"
    }

    static func residence(for entity: NarrativeWorldEntity) -> String {
        if isStaff(entity) { return AcademyGeography.facultyID }
        if let chapter = AcademyChapterRegistry.chapter(named: entity.chapter) {
            return AcademyGeography.dormitoriesID(chapter.id)
        }
        return AcademyGeography.guestID
    }

    private static func shortName(_ entity: NarrativeWorldEntity) -> String {
        let bare = entity.name.components(separatedBy: " (").first ?? entity.name
        let titles: Set<String> = ["Professor", "Dr.", "Headmistress", "The"]
        let parts = bare.split(separator: " ").map(String.init).filter { !titles.contains($0) }
        return (isStaff(entity) ? parts.last : parts.first) ?? entity.name
    }

    /// Where someone's own day puts them at this hour.
    static func routine(
        for haunt: Haunt,
        hour: Int,
        dayIndex: Int,
        closed: Set<String> = []
    ) -> (room: String, why: AcademyWhereabout.Why)? {
        let isNight = hour >= 22 || hour < 7
        if !isNight, mealHours.contains(hour), let table = haunt.meals, !closed.contains(table) {
            return (table, haunt.eatsAtMeals ? .eating : .haunt)
        }
        let rooms: [String]
        let slot: Int
        if isNight {
            rooms = haunt.night
            slot = 0
        } else if hour >= 17 {
            rooms = haunt.evening
            slot = hour / 2
        } else {
            rooms = haunt.day
            slot = hour / 2
        }
        let open = rooms.filter { !closed.contains($0) && $0 != AcademyGeography.dormID }
        guard !open.isEmpty else {
            // Everywhere they'd go is shut. They end up where everyone does.
            return rooms.isEmpty || closed.contains(greatHall) ? nil : (greatHall, .haunt)
        }
        let pick = Int(UInt64(truncatingIfNeeded: "\(haunt.characterID)|\(dayIndex)|\(slot)".stableHash) % UInt64(open.count))
        return (open[pick], .haunt)
    }
}

// MARK: - How people move

/// Somebody on their way to where they are now.
struct AcademyArrival: Equatable, Sendable {
    var fromRoomID: String
    var startedAt: Date
    var duration: TimeInterval = 45

    static let longestWalk: TimeInterval = 240

    func isUnderway(at date: Date) -> Bool {
        let elapsed = date.timeIntervalSince(startedAt)
        return elapsed >= 0 && elapsed < duration
    }

    /// A short passage takes less time than a journey across the Academy.
    /// Familiar feet keep their own pace, also after closing and reopening.
    static func departing(_ person: AcademyWhereabout, from roomID: String, at date: Date,
                          passages: [AcademyPassage], closedRoomIDs: Set<String> = []) -> AcademyArrival? {
        guard let route = AcademyRoute.rooms(from: roomID, to: person.roomID,
                                             passages: passages, avoiding: closedRoomIDs), route.count > 1 else { return nil }
        let pace: Double
        switch person.why {
        case .attending, .teaching: pace = 18
        case .scene, .staged: pace = 22
        case .eating, .haunt, .sleeping: pace = 30
        }
        let linger = Double(UInt64(truncatingIfNeeded: person.characterID.stableHash) % 41)
        return AcademyArrival(fromRoomID: roomID, startedAt: date,
                              duration: min(longestWalk, max(45, Double(route.count - 1) * pace + linger)))
    }
}

enum AcademyMotion: Equatable, Sendable {
    /// Standing about. Now and then they shift their weight.
    case stationary
    /// Up and down the room.
    case pacing

    /// The people who can't keep still.
    static let restless: Set<String> = [
        "wicker-eddies", "orion-blackthorn", "professor-kyle-momort", "finn-bridges",
        "professor-permancer", "serenity-brown", "lydia-boggle", "melisande-blackwood"
    ]

    static func of(_ person: AcademyWhereabout) -> AcademyMotion {
        switch person.why {
        case .teaching, .scene:
            return .pacing
        case .eating, .sleeping:
            return .stationary
        case .staged, .attending, .haunt:
            return restless.contains(person.characterID) ? .pacing : .stationary
        }
    }
}

enum AcademyRoute {
    /// The rooms somebody walks through, from one room to another, the short
    /// way round. Shut rooms are walked around, not through.
    static func rooms(
        from start: String,
        to goal: String,
        passages: [AcademyPassage],
        avoiding closed: Set<String> = []
    ) -> [String]? {
        guard start != goal else { return [start] }
        var previous: [String: String] = [start: start]
        var queue = [start]
        var index = 0
        while index < queue.count {
            let here = queue[index]
            index += 1
            for passage in passages where passage.touches(here) {
                guard let next = passage.other(than: here), previous[next] == nil else { continue }
                if closed.contains(next), next != goal { continue }
                previous[next] = here
                if next == goal {
                    var path = [goal]
                    var step = goal
                    while let back = previous[step], back != step {
                        path.append(back)
                        step = back
                    }
                    return path.reversed()
                }
                queue.append(next)
            }
        }
        return nil
    }
}

// MARK: - The illustrated, multi-level atlas

/// Leaves of one Academy, not four independent worlds. Story room IDs and
/// the canonical passage graph stay unchanged; only their paper addresses move.
enum AcademyMapLevel: String, CaseIterable, Identifiable, Hashable, Sendable {
    case undercroft, ground, upper, labyrinth
    var id: String { rawValue }
    var title: String {
        switch self {
        case .undercroft: return "The Undercroft"
        case .ground: return "School & Gardens"
        case .upper: return "The Upper Rooms"
        case .labyrinth: return "Tower & Stacks"
        }
    }
    var shortTitle: String {
        switch self {
        case .undercroft: return "Below"
        case .ground: return "Ground"
        case .upper: return "Above"
        case .labyrinth: return "Stacks"
        }
    }
    var assetName: String { "AcademyAtlas-\(rawValue)-v1" }
    var note: String {
        switch self {
        case .undercroft: return "The roots got here first."
        case .ground: return "The walls stay. The feet don't."
        case .upper: return "Mind the stair. It knows your name."
        case .labyrinth: return "The shelves have been moving again."
        }
    }
}

struct AcademyAtlasDoor: Identifiable, Equatable {
    var from: String
    var to: String
    var level: AcademyMapLevel
    var id: String { from + "|" + to }
}

struct AcademyAtlasJourneySegment: Equatable {
    var rooms: [String]
    var starts: Double
    var finishes: Double
    var enters: Bool
    var leaves: Bool
}

enum AcademyIllustratedAtlas {
    /// Door-to-door surveys of the illustrated passage floors. These curves
    /// follow the artwork, rather than laying a second CAD plan over it.
    static let walks: [String: [AcademyMapPoint]] = {
        var result: [String: [AcademyMapPoint]] = [:]
        func add(_ a: String, _ b: String, _ points: [(Double, Double)]) {
            result[a + "|" + b] = points.map { .init($0.0, $0.1) }
        }
        add("location-great-hall", "location-north-staircase", [(0.5,0.325),(0.5,0.25),(0.5,0.20),(0.5,0.14)])
        add("location-great-hall", "location-binding-hall", [(0.5,0.325),(0.5,0.387),(0.5,0.435),(0.5,0.50)])
        add("location-great-hall", "location-corridor-whispered", [(0.5,0.325),(0.35,0.32),(0.31,0.32)])
        add("location-corridor-whispered", "location-inkworks", [(0.31,0.32),(0.26,0.32),(0.17,0.31)])
        add("location-great-hall", "location-momentum-yard", [(0.5,0.325),(0.64,0.32),(0.695,0.32),(0.82,0.31)])
        add("location-book-burrow", "location-rain-room", [(0.17,0.507),(0.17,0.57),(0.15,0.64)])
        add("location-momentum-yard", "location-open-field-gate", [(0.82,0.31),(0.82,0.398),(0.74,0.415),(0.74,0.448),(0.91,0.448)])
        add("location-open-field-gate", "location-walled-garden", [(0.91,0.448),(0.89,0.475),(0.83,0.50)])
        add("location-walled-garden", "location-secret-garden-prose", [(0.83,0.50),(0.73,0.50),(0.73,0.57),(0.68,0.63),(0.69,0.68),(0.81,0.71),(0.86,0.78),(0.86,0.827)])
        let burrow = [(0.17,0.507),(0.343,0.507),(0.35,0.63),(0.42,0.636),(0.42,0.685),(0.42,0.756)]
        add("location-book-burrow", "location-common-emberheart", burrow + [(0.30,0.757)])
        add("location-book-burrow", "location-common-mossbloom", burrow + [(0.50,0.756)])
        add("location-book-burrow", "location-common-tidecrest", burrow + [(0.50,0.756),(0.60,0.756),(0.70,0.756)])
        add("location-book-burrow", "location-common-riddlewind", burrow + [(0.42,0.80),(0.39,0.817),(0.39,0.875)])
        add("location-book-burrow", "location-common-duskthorn", burrow + [(0.50,0.756),(0.505,0.82),(0.61,0.82),(0.61,0.882)])
        add("location-still-room", "location-resonance-chamber", [(0.50,0.215),(0.50,0.30),(0.50,0.38),(0.50,0.455),(0.49,0.61)])
        add("location-kitchens", "location-pantry", [(0.79,0.39),(0.66,0.45),(0.66,0.53),(0.72,0.585),(0.83,0.59),(0.81,0.70)])
        add("location-glint-hall", "location-spark-annex", [(0.51,0.25),(0.697,0.27),(0.752,0.27),(0.84,0.26)])
        add("location-faculty-quarters", "location-guest-rooms", [(0.26,0.46),(0.44,0.46),(0.51,0.412),(0.60,0.46),(0.77,0.46)])
        add("location-outer-stacks", "location-stacks", [(0.64,0.13),(0.61,0.206),(0.59,0.235),(0.55,0.275),(0.50,0.315),(0.49,0.35),(0.54,0.40),(0.55,0.48)])
        add("location-stacks", "location-vault-of-doors", [(0.55,0.48),(0.67,0.49),(0.75,0.545),(0.80,0.584),(0.82,0.70)])
        add("location-stacks", "location-shelf-misfiled-days", [(0.55,0.48),(0.39,0.448),(0.35,0.41),(0.28,0.37),(0.28,0.30)])
        add("location-stacks", "location-headmistress-tower", [(0.55,0.48),(0.37,0.49),(0.32,0.55),(0.27,0.61),(0.27,0.685)])
        add("location-vault-of-doors", "location-east-stacks", [(0.82,0.70),(0.82,0.585),(0.94,0.552),(0.94,0.47),(0.86,0.47)])
        add("location-east-stacks", "location-quillquarium", [(0.86,0.47),(0.94,0.55),(0.85,0.59),(0.68,0.62),(0.60,0.71),(0.56,0.75),(0.56,0.85)])
        return result
    }()

    static func walk(from a: String, to b: String) -> [AcademyMapPoint]? {
        if let points = walks[a + "|" + b] { return points }
        return walks[b + "|" + a].map { Array($0.reversed()) }
    }

    /// These are surveyed OPEN FLOORS in the generated plates, normalized to
    /// the full image. Illustration walls are never regenerated by the view.
    struct Floor: Equatable {
        var level: AcademyMapLevel
        var center: AcademyMapPoint
        var size: AcademyMapPoint
        init(_ level: AcademyMapLevel, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
            self.level = level; center = .init(x, y); size = .init(w, h)
        }
    }

    static let floors: [String: Floor] = [
        "location-great-hall": .init(.ground, 0.5, 0.325, 0.23, 0.09),
        "location-binding-hall": .init(.ground, 0.5, 0.5, 0.13, 0.08),
        "location-inkworks": .init(.ground, 0.17, 0.31, 0.14, 0.075),
        "location-momentum-yard": .init(.ground, 0.82, 0.31, 0.17, 0.1),
        "location-book-burrow": .init(.ground, 0.17, 0.507, 0.15, 0.065),
        "location-rain-room": .init(.ground, 0.15, 0.64, 0.17, 0.045),
        "location-north-staircase": .init(.ground, 0.5, 0.14, 0.08, 0.05),
        "location-open-field-gate": .init(.ground, 0.91, 0.448, 0.06, 0.026),
        "location-walled-garden": .init(.ground, 0.83, 0.5, 0.13, 0.065),
        "location-secret-garden-prose": .init(.ground, 0.86, 0.827, 0.095, 0.037),
        "location-corridor-whispered": .init(.ground, 0.31, 0.32, 0.06, 0.026),
        "location-common-emberheart": .init(.ground, 0.3, 0.757, 0.16, 0.055),
        "location-common-mossbloom": .init(.ground, 0.5, 0.756, 0.13, 0.06),
        "location-common-tidecrest": .init(.ground, 0.7, 0.756, 0.13, 0.06),
        "location-common-riddlewind": .init(.ground, 0.39, 0.875, 0.15, 0.04),
        "location-common-duskthorn": .init(.ground, 0.61, 0.882, 0.13, 0.055),
        "location-still-room": .init(.undercroft, 0.50, 0.215, 0.22, 0.10),
        "location-resonance-chamber": .init(.undercroft, 0.49, 0.61, 0.29, 0.115),
        "location-bibliophonic-hall": .init(.undercroft, 0.20, 0.375, 0.19, 0.115),
        "location-kitchens": .init(.undercroft, 0.79, 0.39, 0.21, 0.12),
        "location-pantry": .init(.undercroft, 0.81, 0.70, 0.13, 0.08),
        "location-glint-hall": .init(.upper, 0.51, 0.25, 0.23, 0.105),
        "location-spark-annex": .init(.upper, 0.84, 0.26, 0.13, 0.07),
        "location-old-reading-room": .init(.upper, 0.20, 0.26, 0.15, 0.075),
        "location-faculty-quarters": .init(.upper, 0.26, 0.46, 0.24, 0.07),
        "location-guest-rooms": .init(.upper, 0.77, 0.46, 0.23, 0.07),
        "location-dorms-emberheart": .init(.upper, 0.19, 0.65, 0.20, 0.065),
        "location-dorms-mossbloom": .init(.upper, 0.51, 0.655, 0.20, 0.065),
        "location-dorms-tidecrest": .init(.upper, 0.81, 0.655, 0.20, 0.065),
        "location-dorms-riddlewind": .init(.upper, 0.28, 0.845, 0.25, 0.07),
        "location-dorms-duskthorn": .init(.upper, 0.75, 0.845, 0.24, 0.07),
        "location-dorm": .init(.upper, 0.51, 0.54, 0.105, 0.026),
        "location-outer-stacks": .init(.labyrinth, 0.64, 0.13, 0.30, 0.09),
        "location-stacks": .init(.labyrinth, 0.55, 0.48, 0.30, 0.12),
        "location-east-stacks": .init(.labyrinth, 0.86, 0.47, 0.12, 0.10),
        "location-headmistress-tower": .init(.labyrinth, 0.27, 0.685, 0.17, 0.095),
        "location-vault-of-doors": .init(.labyrinth, 0.82, 0.70, 0.18, 0.105),
        "location-quillquarium": .init(.labyrinth, 0.56, 0.85, 0.18, 0.08),
        "location-shelf-misfiled-days": .init(.labyrinth, 0.28, 0.30, 0.16, 0.055),
    ]

    static func level(of id: String, in chart: AcademyChart) -> AcademyMapLevel {
        if let floor = floors[id] { return floor.level }
        // Temporary rooms grow onto the leaf of their authored entrance.
        // Prefer a permanent neighbour, so borrowed rooms cannot recursively
        // move one another between leaves.
        let neighbours = chart.allPassages.filter { $0.touches(id) }
            .compactMap { $0.other(than: id) }.compactMap { floors[$0]?.level }
        return neighbours.contains(.labyrinth) ? .labyrinth : neighbours.first ?? .ground
    }

    static func floor(of room: AcademyChartRoom, in chart: AcademyChart) -> Floor {
        if var floor = floors[room.id] {
            if room.id == "location-shelf-misfiled-days" {
                // Three genuinely different alcoves on this leaf. The daily
                // drift still comes from the canonical chart's moving shelf.
                if room.point.x > 0.5 { floor.center = .init(0.80, 0.24) }
                else if room.point.y > 0.1 { floor.center = .init(0.25, 0.17) }
            }
            if room.id == AcademyGeography.dormID,
               let entrance = chart.allPassages.first(where: { $0.touches(room.id) })?.other(than: room.id),
               entrance.hasPrefix("location-dorms-"), let dorms = floors[entrance] {
                floor.center = .init(dorms.center.x, dorms.center.y + 0.084)
            }
            return floor
        }
        let level = Self.level(of: room.id, in: chart)
        let borrowed = chart.rooms.filter { floors[$0.id] == nil && self.level(of: $0.id, in: chart) == level }
            .sorted { $0.id < $1.id }
        let index = borrowed.firstIndex(where: { $0.id == room.id }) ?? 0
        // Borrowed chambers extend onto fresh paper beneath the illustrated
        // leaf, never cover its architecture, and have no population cap.
        return Floor(level, index % 2 == 0 ? 0.28 : 0.72,
                     1.075 + Double(index / 2) * 0.15, 0.33, 0.11)
    }

    static func projectedRoom(_ original: AcademyChartRoom, in chart: AcademyChart) -> AcademyChartRoom {
        let floor = Self.floor(of: original, in: chart)
        var room = original
        room.point = .init((floor.center.x - 0.04) / 0.92, (floor.center.y - 0.03) / 0.88)
        room.room.size = .init(floor.size.x / 0.92, floor.size.y / 0.88)
        // The Stacks are an illustrated open library floor on their own leaf,
        // no longer a gigantic rectangular ring around every other room.
        if room.room.form == .ring { room.room.form = .room }
        return room
    }

    static func chart(_ source: AcademyChart, on level: AcademyMapLevel) -> AcademyChart {
        var chart = source
        chart.rooms = source.rooms.filter { self.level(of: $0.id, in: source) == level }
            .map { projectedRoom($0, in: source) }
        let ids = Set(chart.rooms.map(\.id))
        chart.passages = source.passages.filter { ids.contains($0.from) && ids.contains($0.to) }
        // Keep the whole graph for walking across stairs. The drawing knows
        // only this leaf's rooms, so it clips a journey at its stair landing.
        chart.unseen = source.rooms.flatMap(\.people).filter { person in
            guard let arrival = source.arrivals[person.characterID] else { return false }
            return journey(from: arrival.fromRoomID, to: person.roomID, in: source, on: level).contains { $0.leaves }
            }
        if level != .labyrinth { chart.anchorRooms = [] }
        return chart
    }

    /// The leaf carrying someone's feet now, including a departure gallery
    /// or intermediate landing before their destination comes into view.
    static func level(of person: AcademyWhereabout, at date: Date, in chart: AcademyChart) -> AcademyMapLevel {
        guard let arrival = chart.arrivals[person.characterID], arrival.isUnderway(at: date) else {
            return level(of: person.roomID, in: chart)
        }
        let progress = date.timeIntervalSince(arrival.startedAt) / arrival.duration
        return AcademyMapLevel.allCases.first { leaf in
            journey(from: arrival.fromRoomID, to: person.roomID, in: chart, on: leaf)
                .contains { progress >= $0.starts && progress < $0.finishes }
        } ?? level(of: person.roomID, in: chart)
    }

    static func doors(in chart: AcademyChart, on level: AcademyMapLevel) -> [AcademyAtlasDoor] {
        chart.allPassages.compactMap { passage in
            guard chart.room(passage.from) != nil, chart.room(passage.to) != nil else { return nil }
            let from = self.level(of: passage.from, in: chart), to = self.level(of: passage.to, in: chart)
            guard from != to else { return nil }
            if from == level { return AcademyAtlasDoor(from: passage.from, to: passage.to, level: to) }
            if to == level { return AcademyAtlasDoor(from: passage.to, to: passage.from, level: from) }
            return nil
        }.sorted { $0.id < $1.id }
    }

    static func borrowedRows(in chart: AcademyChart, on level: AcademyMapLevel) -> Int {
        let count = chart.rooms.filter { floors[$0.id] == nil && self.level(of: $0.id, in: chart) == level }.count
        return (count + 1) / 2
    }

    /// Split one canonical walk into its visible stretches on a leaf. Stair
    /// crossings divide the shared journey clock halfway between rooms,
    /// including walks that leave a leaf and later return to it.
    static func journey(from start: String, to goal: String, in chart: AcademyChart,
                        on level: AcademyMapLevel) -> [AcademyAtlasJourneySegment] {
        guard let path = AcademyRoute.rooms(from: start, to: goal, passages: chart.allPassages,
                                            avoiding: chart.closedRoomIDs), path.count > 1 else { return [] }
        let edges = Double(path.count - 1)
        var segments: [AcademyAtlasJourneySegment] = []
        var index = 0
        while index < path.count {
            guard self.level(of: path[index], in: chart) == level else { index += 1; continue }
            let first = index
            while index + 1 < path.count, self.level(of: path[index + 1], in: chart) == level { index += 1 }
            let last = index
            segments.append(AcademyAtlasJourneySegment(rooms: Array(path[first...last]),
                starts: max(0, (Double(first) - 0.5) / edges),
                finishes: min(1, (Double(last) + 0.5) / edges),
                enters: first > 0, leaves: last < path.count - 1))
            index += 1
        }
        return segments
    }
}
