import Foundation

/// The wear a reader leaves on the Book by reading it.
///
/// Everything else the Book knows arrives through the Pages it set out: what
/// was kept, what was let go, what was written back in the margin. All of that
/// is the Book asking and the reader answering. None of it says anything about
/// the nights the reader went looking on their own.
///
/// A real book keeps that record without being asked to. The spine cracks
/// where it was held open. The fore-edge darkens under a thumb. A gathering
/// nobody ever cut stays folded shut for thirty years and says so at a glance.
/// This is that record, and it is deliberately physical: the Book keeps no
/// visit count, it wears.
///
/// One rule makes the record worth having. **Only wandering wears the paper.**
/// A room the Book sent the reader to is the Book's own doing and leaves no
/// mark. What gathers here is the reader's curiosity with none of the Book's
/// arrangement mixed into it, which is why the Book is allowed to be moved by
/// what it finds here.

// MARK: - Arrival

/// How the reader got somewhere in the Book.
enum WearArrival: Equatable, Sendable {
    /// They went looking. The contents leaf, a charm on its cord, a seal, the
    /// Place seal fanned open. The only arrival that marks paper.
    case byHand
    /// The Book put them there: a Page's door, a notice followed through, a
    /// deep link from a widget. Recorded nowhere. Counting it would let the
    /// Book wear its own paper and then be impressed by the marks.
    case sent
}

// MARK: - The rooms

/// A part of the Book the reader can go to on purpose.
///
/// Raw values are the ids printed on the contents leaf, so a room and the row
/// that opens it cannot drift apart while nobody is looking.
enum BookRoom: String, CaseIterable, Codable, Sendable {
    // Gatherings. Sections of the block, printed in the contents. A gathering
    // nobody has opened is still folded shut along its head.
    case bookshop
    case pagewright
    case bookToday = "book-today"
    case cast
    case correspondences
    case bestiary
    case gazetteer
    case atlas
    case todaysMargins = "margins"
    case returned
    case bookOfYou = "book-of-you"
    case pagesIndex = "index"
    case colophon

    // Fittings. Hung on the outside where the reader can see them from the
    // first night. Nothing about a charm is folded shut, so these wear without
    // ever having been cut.
    case search
    case almanac
    case radio

    /// True for a section of the block. False for a thing hanging off it.
    ///
    /// The distinction earns its keep three times over: only a gathering can be
    /// uncut, only a gathering can be the place the Book falls open, and only
    /// gatherings are counted when the Book works out how much of itself the
    /// reader has actually been inside.
    var isGathering: Bool {
        switch self {
        case .search, .almanac, .radio: return false
        default: return true
        }
    }

    /// What the Book calls it out loud, ready to drop into a sentence.
    var plainName: String {
        switch self {
        case .bookshop: return "the Bookshop"
        case .pagewright: return "the Pagewright"
        case .bookToday: return "my own weather"
        case .cast: return "the Cast Ledger"
        case .correspondences: return "the Correspondences"
        case .bestiary: return "the Bestiary"
        case .gazetteer: return "the Gazetteer"
        case .atlas: return "the Atlas"
        case .todaysMargins: return "today's margins"
        case .returned: return "what came back from the stacks"
        case .bookOfYou: return "the Book of You"
        case .pagesIndex: return "my index"
        case .colophon: return "the colophon"
        case .search: return "the stacks"
        case .almanac: return "the almanac"
        case .radio: return "the receiver"
        }
    }

    /// The Book's own reason for keeping this part of itself, said as a
    /// half-sentence that can follow the name. Used when it wants to make
    /// somewhere sound worth the walk without describing a feature.
    var lure: String {
        switch self {
        case .bookshop: return "there are goblins behind the counter and they know you by now"
        case .pagewright: return "you can cut me up and make a Page back at me"
        case .bookToday: return "you can find out what sort of mood I woke up in"
        case .cast: return "everyone currently awake in my margins is standing in there"
        case .correspondences: return "every law I've worked out about you is written down in there"
        case .bestiary: return "everything alive I've found in your photographs is filed in there"
        case .gazetteer: return "every place you've stood long enough to name is in there"
        case .atlas: return "your whole world is drawn out in there, and it has a shape"
        case .todaysMargins: return "the loose ink of the last few hours is still wet in there"
        case .returned: return "things I sent back up and then thought better of are in there"
        case .bookOfYou: return "everything already sewn in is in there, and it's heavier than you think"
        case .pagesIndex: return "every kind of Page I know how to set is listed in there"
        case .colophon: return "how I'm made is in there, and I don't mind you knowing"
        case .search: return "the stacks answer if you ask them a straight question"
        case .almanac: return "the year is drawn out by its own days in there"
        case .radio: return "there's a whole band in there and most of it is other people"
        }
    }
}

// MARK: - Thresholds

/// How much reading makes a mark, said once so no rule is invented twice.
enum WearThreshold {
    /// Separate days before a room shows at the fore-edge. Two is a
    /// coincidence. Three is a habit starting.
    static let thumbed = 3

    /// Days without the reader before a worn room reads as quiet. The same
    /// mark the place noticings use, because it is the same feeling about a
    /// different kind of place.
    static let quiet = 45

    /// Days of wear before a spine will hold the Book open on its own, and how
    /// far ahead of the next room it has to be. A crack nobody could point to
    /// is not a crack.
    static let fallsOpen = 5
    static let fallsOpenLead = 2

    /// What makes a reader a margin-walker: gatherings opened, rooms worn in,
    /// and separate days spent wandering. All three, because any one of them
    /// alone is an afternoon rather than a habit.
    static let marginWalkerCuts = 6
    static let marginWalkerThumbed = 3
    static let marginWalkerDays = 14
}

// MARK: - One room's paper

struct RoomWear: Codable, Equatable, Sendable {
    /// The day the fold first parted. Nil while a gathering is still shut.
    var cutAt: Date?
    /// The last time the reader went there themselves.
    var lastOpenedAt: Date?
    /// Distinct days the reader went there by hand. Twice before lunch is one
    /// day's wear: paper does not care how excited anybody was.
    var days = DayBitset()

    var isCut: Bool { cutAt != nil }

    func daysSinceLastOpened(now: Date, calendar: Calendar = .current) -> Int? {
        guard let lastOpenedAt else { return nil }
        return max(0, GrimoireDay.index(for: now, calendar: calendar)
            - GrimoireDay.index(for: lastOpenedAt, calendar: calendar))
    }
}

/// What a room's paper looks like right now.
enum RoomCondition: Equatable, Sendable {
    /// Never opened. For a gathering this is literal: the head fold is intact.
    case uncut
    /// Opened, and still stiff.
    case cut
    /// Opened on enough separate days to show at the edge.
    case thumbed
    /// Worn, and then left alone long enough for the dust to settle. The
    /// reading is about the room, never about the reader: somewhere going
    /// quiet is a fact about a place, and the Book has no business turning it
    /// into a charge.
    case quiet(days: Int)

    /// True once the paper carries any mark at all.
    var isMarked: Bool { self != .uncut }
}

// MARK: - The ledger

/// Every room's paper, kept together.
///
/// Keyed by raw value rather than by case so a room retired tomorrow leaves its
/// wear sitting harmlessly in the file instead of failing the whole decode. A
/// reader's four years of thumbprints must not be destroyed by a rename.
struct ReaderWearLedger: Codable, Equatable, Sendable {
    var rooms: [String: RoomWear] = [:]

    init(rooms: [String: RoomWear] = [:]) {
        self.rooms = rooms
    }

    subscript(room: BookRoom) -> RoomWear {
        rooms[room.rawValue] ?? RoomWear()
    }
}

/// The moment a fold parted. Handed back by `opened` so the caller gets the
/// event without having to ask a second question about what just happened.
struct WearCut: Equatable, Sendable {
    var room: BookRoom
    var at: Date
    /// How many gatherings were still folded shut afterwards, this one no
    /// longer among them. Zero means the reader has now been everywhere.
    var stillFolded: Int

    var isTheLastOne: Bool { stillFolded == 0 }
}

extension ReaderWearLedger {
    /// Record that the reader went somewhere on their own.
    ///
    /// Returns a cut when this was the first time ever, and nil every time
    /// after. `.sent` arrivals return nil and change nothing.
    @discardableResult
    mutating func opened(
        _ room: BookRoom,
        arrival: WearArrival = .byHand,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> WearCut? {
        guard arrival == .byHand else { return nil }
        var wear = self[room]
        let isFirst = wear.cutAt == nil
        if isFirst { wear.cutAt = date }
        wear.lastOpenedAt = date
        wear.days.insert(GrimoireDay.index(for: date, calendar: calendar))
        rooms[room.rawValue] = wear
        guard isFirst, room.isGathering else { return nil }
        return WearCut(room: room, at: date, stillFolded: uncutGatherings.count)
    }

    func condition(
        of room: BookRoom,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RoomCondition {
        let wear = self[room]
        guard wear.isCut else { return .uncut }
        let worn = wear.days.count >= WearThreshold.thumbed
        if worn, let idle = wear.daysSinceLastOpened(now: now, calendar: calendar),
           idle >= WearThreshold.quiet {
            return .quiet(days: idle)
        }
        return worn ? .thumbed : .cut
    }

    /// How hard the fore-edge is soiled here, from nothing to fully handled.
    ///
    /// The compositor wants a dimension rather than a state so wear can darken
    /// continuously instead of stepping between three drawings. It saturates
    /// deliberately: past a fortnight of separate days the paper is as dark as
    /// paper gets and further reading has nothing left to say.
    func soiling(of room: BookRoom) -> Double {
        let days = Double(self[room].days.count)
        guard days > 0 else { return 0 }
        return min(1, days / 14)
    }

    var gatherings: [BookRoom] { BookRoom.allCases.filter(\.isGathering) }

    var uncutGatherings: [BookRoom] { gatherings.filter { !self[$0].isCut } }

    var cutGatherings: [BookRoom] { gatherings.filter { self[$0].isCut } }

    /// Every distinct day the reader went looking anywhere, counted once.
    /// A union of bitmaps, which is what the whole day-as-a-bit primitive was
    /// built to make free.
    var wanderingDays: DayBitset {
        rooms.values.reduce(into: DayBitset()) { $0 = $0.union($1.days) }
    }

    /// The gathering the Book has been opened at often enough, and clearly
    /// enough ahead of the rest, to fall open there when it is set down.
    ///
    /// The lead is the whole rule. Without it the Book would announce a crack
    /// in its spine over a two-visit lead, which any reader could correctly
    /// call a lie about their own hands.
    func fallsOpen(now: Date = Date(), calendar: Calendar = .current) -> BookRoom? {
        var ranked: [(room: BookRoom, days: Int)] = []
        for room in gatherings {
            let count = self[room].days.count
            guard count >= WearThreshold.fallsOpen else { continue }
            ranked.append((room: room, days: count))
        }
        ranked.sort { left, right in
            left.days == right.days
                ? left.room.rawValue < right.room.rawValue
                : left.days > right.days
        }
        guard let first = ranked.first else { return nil }
        let runnerUp = ranked.count > 1 ? ranked[1].days : 0
        guard first.days - runnerUp >= WearThreshold.fallsOpenLead else { return nil }
        // A crack the reader stopped using is a crack in a book on a shelf.
        if case .quiet = condition(of: first.room, now: now, calendar: calendar) { return nil }
        return first.room
    }

    /// A reader who goes looking without being sent.
    ///
    /// This is the standing the Book requires before it will pass on a
    /// frequency that was never cleared for broadcast. Being wandered in is the
    /// qualification: an unauthorized signal has no reason to trust anyone who
    /// only ever reads what they were handed.
    func isMarginWalker(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let thumbed = BookRoom.allCases.filter {
            switch condition(of: $0, now: now, calendar: calendar) {
            case .thumbed, .quiet: return true
            case .uncut, .cut: return false
            }
        }
        return cutGatherings.count >= WearThreshold.marginWalkerCuts
            && thumbed.count >= WearThreshold.marginWalkerThumbed
            && wanderingDays.count >= WearThreshold.marginWalkerDays
    }

    /// Two Books' worth of wear on the same object.
    ///
    /// A restore is the reader carrying their Book to a new phone, so the marks
    /// add rather than replace: the union of the days, the earliest cut, the
    /// latest opening. Wear is the one ledger here that cannot be worked out
    /// again from the archive, so an import that dropped half of it would
    /// destroy something with no way back.
    func merging(_ other: ReaderWearLedger) -> ReaderWearLedger {
        var merged = self
        for (key, incoming) in other.rooms {
            guard var mine = merged.rooms[key] else {
                merged.rooms[key] = incoming
                continue
            }
            mine.days = mine.days.union(incoming.days)
            mine.cutAt = [mine.cutAt, incoming.cutAt].compactMap { $0 }.min()
            mine.lastOpenedAt = [mine.lastOpenedAt, incoming.lastOpenedAt].compactMap { $0 }.max()
            merged.rooms[key] = mine
        }
        return merged
    }

    /// Rooms that were worn in and have since gone quiet, the stillest first.
    func quietRooms(now: Date = Date(), calendar: Calendar = .current) -> [BookRoom] {
        BookRoom.allCases.compactMap { room -> (BookRoom, Int)? in
            guard case let .quiet(days) = condition(of: room, now: now, calendar: calendar) else {
                return nil
            }
            return (room, days)
        }
        .sorted { $0.1 == $1.1 ? $0.0.rawValue < $1.0.rawValue : $0.1 > $1.1 }
        .map(\.0)
    }
}
