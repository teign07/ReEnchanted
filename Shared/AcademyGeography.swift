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

    static let rooms: [AcademyRoom] = [
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
            note: "The common room. Low ceiling, lots of blankets. The armchairs shuffle over to whoever needs company.",
            form: .room, size: .init(0.2, 0.06)
        ),
        AcademyRoom(
            id: dormID, name: "The Dorm", zone: .warm, compass: nil,
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

    // MARK: - The ways between them

    static let passages: [AcademyPassage] = [
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
}

// MARK: - What the Book has drawn

/// Why a room is on the Book's map.
enum AcademyRoomSighting: Equatable, Sendable {
    /// Every reader has stood in it.
    case fromTheStart
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
    /// Who's in there right now. Empty for a blank room: the Book can't see
    /// into rooms it hasn't drawn.
    var people: [AcademyWhereabout] = []
    /// Kept Pages that mention the room, newest first.
    var pages: [BookPage] = []

    var id: String { room.id }
    var isDrawn: Bool { sighting != nil }
}

struct AcademyChart: Equatable {
    var rooms: [AcademyChartRoom]
    /// Only passages with at least one drawn end. A path to a blank room is
    /// drawn as far as the paper that's been walked.
    var passages: [AcademyPassage]

    var drawnCount: Int { rooms.filter(\.isDrawn).count }

    func room(_ id: String) -> AcademyChartRoom? { rooms.first { $0.id == id } }

    func isDrawn(_ id: String) -> Bool { room(id)?.isDrawn ?? false }

    /// Cast members who are somewhere the Book hasn't drawn, in timetable
    /// order. The Book notices them go, and can't follow.
    var unseen: [AcademyWhereabout] = []
    /// Rooms the month's story has shut.
    var closedRoomIDs: Set<String> = []
    /// Every way between rooms in play, drawn or not.
    var allPassages: [AcademyPassage] = AcademyGeography.passages
    /// People whose room changed this minute, and where they were before.
    /// They're on their way, and the map shows them walking.
    var arrivals: [String: AcademyArrival] = [:]

    /// The Book's line under the whole map.
    var footer: String {
        "I've drawn \(drawnCount) rooms so far. The blank bits are where I haven't been yet."
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

struct AcademyChartInputs {
    var days: [BookDay] = []
    var placeStates: [String: PlaceState] = [:]
    var storySettingAffinities: [String: Int] = [:]
    /// The real sky right now, when the Book can honestly claim it.
    var sky: SkyCondition?
    /// The reader's own places, by name. Each is a door in the Outer Stacks.
    var anchorNames: [String] = []
    /// Pages on the desk right now. Whatever they're about is happening now.
    var deskScenes: [AcademyScene] = []
    /// What the live month's story says about the Academy.
    var events = AcademyEventStaging()
    /// The month's events themselves. When they're here, the chart works out
    /// `events` from them at its own moment, so it keeps up as time passes.
    var worldEvents: [WorldEvent]? = nil
    var now: Date = Date()
    var calendar: Calendar = .current

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
        let staging = inputs.events
        let mentions = mentions(in: inputs.days)
        let session = AcademyScheduleRegistry.sessionInProgress(at: inputs.now, calendar: inputs.calendar)?.session
        let everyone = AcademyWhereabouts.everyone(
            at: inputs.now,
            calendar: inputs.calendar,
            scenes: inputs.deskScenes + recentScenes(inputs),
            staging: staging
        )
        let staged = Set(staging.staging.map(\.roomID))
            .union(staging.closedRoomIDs)
            .union(staging.roomNotes.keys)
            .union(staging.borrowedRooms.map(\.id))

        let rooms = staging.rooms.map { room -> AcademyChartRoom in
            let sighting = sighting(of: room, inputs: inputs, named: mentions[room.id]?.firstNamed)
                ?? (staged.contains(room.id) && room.id != AcademyGeography.dormID ? .theMonthSaysSo : nil)
            guard sighting != nil else {
                return AcademyChartRoom(
                    room: room, sighting: nil,
                    point: AcademyGeography.point(of: room, on: inputs.now, calendar: inputs.calendar),
                    lines: []
                )
            }
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
        // Who moved this minute: everyone as they were a minute ago, against
        // everyone now. The walk starts on the minute and takes a while.
        let minute = inputs.calendar.dateInterval(of: .minute, for: inputs.now)?.start ?? inputs.now
        var before = inputs.at(minute.addingTimeInterval(-60))
        if let worldEvents = before.worldEvents {
            before.events = AcademyEventStaging.from(events: worldEvents, now: before.now, calendar: before.calendar)
        }
        let earlier = Dictionary(
            AcademyWhereabouts.everyone(
                at: before.now, calendar: before.calendar,
                scenes: inputs.deskScenes + recentScenes(before), staging: before.events
            ).map { ($0.characterID, $0.roomID) },
            uniquingKeysWith: { first, _ in first }
        )
        var arrivals: [String: AcademyArrival] = [:]
        for person in everyone {
            if let from = earlier[person.characterID], from != person.roomID {
                arrivals[person.characterID] = AcademyArrival(fromRoomID: from, startedAt: minute)
            }
        }

        let drawn = Set(rooms.filter(\.isDrawn).map(\.id))
        let allPassages = AcademyGeography.passages + staging.borrowedPassages
        let passages = allPassages.filter { drawn.contains($0.from) || drawn.contains($0.to) }
        return AcademyChart(
            rooms: rooms,
            passages: passages,
            unseen: everyone.filter { !drawn.contains($0.roomID) },
            closedRoomIDs: staging.closedRoomIDs,
            allPassages: allPassages,
            arrivals: arrivals
        )
    }

    /// Scenes from Pages kept in the last few hours, and from things the
    /// rooms remember happening in them just now.
    static func recentScenes(_ inputs: AcademyChartInputs) -> [AcademyScene] {
        let since = inputs.now.addingTimeInterval(-AcademyWhereabouts.sceneLingers)
        let kept = inputs.days
            .filter { $0.date >= inputs.calendar.startOfDay(for: since) }
            .flatMap(\.pages)
            .filter { $0.createdAt >= since }
            .compactMap(\.academyScene)
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
        // A weather room is there when the weather is, however well the Book
        // knows it. On a dry day it's blank paper again.
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
    /// Only Pages the Book wrote count, so a reader's own pantry never draws
    /// the Academy's. A generated Page often keeps the Book's prose in
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

        if room.id == "location-outer-stacks" {
            for name in inputs.anchorNames.prefix(anchorDoorsShown) {
                lines.append("There's a door here that opens onto \(name).")
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
    init?(metadata: [String: String], at: Date, pageID: String? = nil) {
        let room = [
            metadata[Self.roomKey],
            metadata["storySettingID"],
            metadata["placeID"],
            metadata["sessionRoom"].flatMap { AcademyGeography.room(forTimetableName: $0)?.id }
        ]
        .compactMap { $0?.nonEmpty }
        .first { AcademyGeography.room(id: $0) != nil }
        guard let room else { return nil }

        let listed = [metadata[Self.castKey], metadata["selectedEntityIDs"], metadata["undertakingCast"], metadata["actorIDs"]]
            .compactMap { $0?.nonEmpty }
            .first
            .map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } } ?? []
        let single = [metadata["actorID"], metadata["characterID"], metadata["sessionLeaderEntityID"], metadata["storyRecipeLeadID"]]
            .compactMap { $0?.nonEmpty }
        let companions = (metadata["sessionCompanions"] ?? "")
            .split(separator: ",")
            .compactMap { AcademyWhereabouts.id(forName: $0.trimmingCharacters(in: .whitespaces)) }
        var seen: Set<String> = []
        let cast = (listed + single + companions).filter { AcademyWhereabouts.haunt($0) != nil && seen.insert($0).inserted }
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
        /// Most people are asleep somewhere the Book hasn't drawn. Empty
        /// means off the map for the night.
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
        staging: AcademyEventStaging = AcademyEventStaging()
    ) -> [AcademyWhereabout] {
        let hour = calendar.component(.hour, from: date)
        let dayIndex = GrimoireDay.index(for: date, calendar: calendar)
        let session = AcademyScheduleRegistry.sessionInProgress(at: date, calendar: calendar)?.session
        let closed = staging.closedRoomIDs
        // A class held in a shut room moves to the Great Hall. Everybody
        // squeezes in.
        let sessionRoom = session
            .flatMap { AcademyGeography.room(forTimetableName: $0.room)?.id }
            .map { closed.contains($0) ? greatHall : $0 }

        var storyRoom: [String: (room: String, why: AcademyWhereabout.Why, note: String?)] = [:]
        let recent = (scenes + staging.scenes)
            .filter { date.timeIntervalSince($0.at) < sceneLingers && $0.at.timeIntervalSince(date) < 60 }
            .sorted { $0.at < $1.at }
        for scene in recent {
            for id in scene.castIDs { storyRoom[id] = (scene.roomID, .scene, nil) }
        }
        // Staging outranks a passing scene: it's the month's whole story.
        for staged in staging.staging where staging.room(id: staged.roomID) != nil {
            storyRoom[staged.castID] = (staged.roomID, .staged, staged.note?.nonEmpty)
        }
        // People out of other books. They only go where the story puts them.
        var seenVisitors: Set<String> = []
        let visitors = staging.staging
            .filter { hauntsByID[$0.castID] == nil && staging.room(id: $0.roomID) != nil && $0.roomID != AcademyGeography.dormID }
            .reversed()
            .filter { seenVisitors.insert($0.castID).inserted }
            .map { staged in
                AcademyWhereabout(characterID: staged.castID, name: staged.name ?? staged.castID,
                                  mapName: staged.name ?? staged.castID, roomID: staged.roomID,
                                  why: .staged, note: staged.note?.nonEmpty, isVisitor: true)
            }

        return visitors + haunts.compactMap { haunt in
            let name = castNames[haunt.characterID] ?? haunt.mapName
            func here(_ room: String, _ why: AcademyWhereabout.Why, _ note: String? = nil) -> AcademyWhereabout {
                AcademyWhereabout(characterID: haunt.characterID, name: name, mapName: haunt.mapName,
                                  roomID: room, why: why, note: note)
            }
            if let story = storyRoom[haunt.characterID], story.room != AcademyGeography.dormID {
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
            return routine(for: haunt, hour: hour, dayIndex: dayIndex, closed: closed)
                .map { here($0.room, $0.why) }
        }
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
        let pick = abs("\(haunt.characterID)|\(dayIndex)|\(slot)".stableHash) % open.count
        return (open[pick], .haunt)
    }
}

// MARK: - How people move

/// Somebody on their way to where they are now.
struct AcademyArrival: Equatable, Sendable {
    var fromRoomID: String
    var startedAt: Date
}

enum AcademyMotion: Equatable, Sendable {
    /// Standing about. Now and then they shift their weight.
    case stationary
    /// Up and down the room.
    case pacing

    /// How long a walk from one room to another takes on the map.
    static let walkSeconds: TimeInterval = 45

    /// The people who can't keep still.
    static let restless: Set<String> = [
        "wicker-eddies", "orion-blackthorn", "professor-kyle-momort", "finn-bridges",
        "professor-permancer", "serenity-brown", "lydia-boggle", "melisande-blackwood"
    ]

    static func of(_ person: AcademyWhereabout) -> AcademyMotion {
        switch person.why {
        case .teaching, .scene:
            return .pacing
        case .eating:
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
