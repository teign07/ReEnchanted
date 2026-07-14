import Foundation


enum BookPageType: String, Codable, CaseIterable, Identifiable {
    case mood
    case diary
    case souvenir
    case rest
    case body
    case fuel
    case weather
    case location
    case quip
    case quotes
    case affirmations
    case aboutYou
    case wonderCompass
    case lore
    case patreon
    case illustration
    case illuminatedPhoto
    case narrativeOS
    case gossip
    case note
    case facultyResearch
    case letter
    case supportGuild
    case bookOfYou
    case askTheBook
    case inkrestOfficeHours
    case faeBargain
    case bookFae
    case pactDispatch
    case pactVerdict
    case pactErrand
    case festival
    case twoReadings
    case castBond
    case todaysSky
    case radio
    case bookJump
    case enchantment
    case anchor
    case academyClass
    case elective
    case packPage
    case wordNegotiation
    case gamePage
    case calendar
    case helpTips
    case welcome
    case marginsAtlas
    case bookConnections
    case bookRemembered
    case bookNotices
    case glowInvitation
    case theBleed
    case inventory
    case bindery
    case bookPocket
    /// The sacred dumb door: a promptless "just write" page. Never surfaced by
    /// the curator — it exists only when the reader opens it by hand. Enters the
    /// archive unprocessed; the magic can find it later, if ever.
    case plainPage

    var id: String { rawValue }

    static func legacyCompatible(rawValue: String) -> BookPageType? {
        rawValue == "castMember" ? .illustration : Self(rawValue: rawValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let type = Self.legacyCompatible(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown book page type: \(rawValue)"
            )
        }
        self = type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var title: String {
        switch self {
        case .mood:
            return "Inner Weather"
        case .diary:
            return "Diary Page"
        case .souvenir:
            return "One-Sentence Souvenir"
        case .rest:
            return "Center Page"
        case .body:
            return "Body Page"
        case .fuel:
            return "Fuel Log"
        case .weather:
            return "Weather Page"
        case .location:
            return "Location Page"
        case .quip:
            return "Quip Page"
        case .quotes:
            return "A Quote to Keep"
        case .affirmations:
            return "The Book Believes"
        case .aboutYou:
            return "About You"
        case .wonderCompass:
            return "From the Wonder Compass Book"
        case .lore:
            return "Lore Page"
        case .patreon:
            return "Creator Notes"
        case .illustration:
            return "An Illustration from the Labyrinth of Stories"
        case .illuminatedPhoto:
            return "Illuminated Photos"
        case .narrativeOS:
            return "Story Page"
        case .gossip:
            return "Gossip Page"
        case .note:
            return "Notes"
        case .facultyResearch:
            return "Faculty Research Note"
        case .letter:
            return "Letter Page"
        case .supportGuild:
            return "Support Guild Page"
        case .bookOfYou:
            return "Book of You"
        case .askTheBook:
            return "Chat with the Book"
        case .inkrestOfficeHours:
            return "Dr. Inkrest's Office Hours"
        case .faeBargain:
            return "A Fae Bargain"
        case .bookFae:
            return "Book Fae Page"
        case .pactDispatch:
            return "A Pact Dispatch"
        case .pactVerdict:
            return "The Pact War Report"
        case .pactErrand:
            return "A Talisman's Errand"
        case .festival:
            return "A Festival of the Wheel"
        case .twoReadings:
            return "The Two Readings"
        case .castBond:
            return "A Turn in the Cast"
        case .todaysSky:
            return "Today's Sky"
        case .radio:
            return "ReEnchanted Radio"
        case .bookJump:
            return "Book Jump"
        case .enchantment:
            return "Cast an Enchantment"
        case .anchor:
            return "Outer Stacks"
        case .academyClass:
            return "Classes & Clubs"
        case .elective:
            return "Quests"
        case .packPage:
            return "Pack Page"
        case .wordNegotiation:
            return "Word Negotiation"
        case .gamePage:
            return "Game Page"
        case .calendar:
            return "Hour Page"
        case .helpTips:
            return "Help and Tips"
        case .welcome:
            return "Welcome Page"
        case .marginsAtlas:
            return "The Margins Atlas"
        case .bookConnections:
            return "Book Connections"
        case .bookRemembered:
            return "The Book Remembered"
        case .bookNotices:
            return "The Book Notices"
        case .glowInvitation:
            return "Spend Glow"
        case .theBleed:
            return "The Bleed"
        case .inventory:
            return "The Inventory"
        case .bindery:
            return "The Bindery"
        case .bookPocket:
            return "The Book's Pocket"
        case .plainPage:
            return "Plain Page"
        }
    }

    var shortTitle: String {
        switch self {
        case .mood:
            return "Weather"
        case .diary:
            return "Diary"
        case .souvenir:
            return "Souvenir"
        case .rest:
            return "Rest"
        case .body:
            return "Body"
        case .fuel:
            return "Fuel"
        case .weather:
            return "Weather"
        case .location:
            return "Place"
        case .quip:
            return "Quip"
        case .quotes:
            return "Quote"
        case .affirmations:
            return "Believing"
        case .aboutYou:
            return "You"
        case .wonderCompass:
            return "Wonder Book"
        case .lore:
            return "Lore"
        case .patreon:
            return "Notes"
        case .illustration:
            return "Illustration"
        case .illuminatedPhoto:
            return "Illuminated"
        case .narrativeOS:
            return "Story"
        case .gossip:
            return "Gossip"
        case .note:
            return "Note"
        case .facultyResearch:
            return "Research"
        case .letter:
            return "Letter"
        case .supportGuild:
            return "Guild"
        case .bookOfYou:
            return "Braid"
        case .askTheBook:
            return "Ask"
        case .inkrestOfficeHours:
            return "Office Hours"
        case .faeBargain:
            return "Bargain"
        case .bookFae:
            return "Book Fae"
        case .pactDispatch:
            return "Dispatch"
        case .pactVerdict:
            return "Reading"
        case .pactErrand:
            return "Errand"
        case .festival:
            return "Festival"
        case .twoReadings:
            return "Readings"
        case .castBond:
            return "Cast"
        case .todaysSky:
            return "Sky"
        case .radio:
            return "Radio"
        case .bookJump:
            return "Jump"
        case .enchantment:
            return "Spell"
        case .anchor:
            return "Anchor"
        case .academyClass:
            return "Class"
        case .elective:
            return "Elective"
        case .packPage:
            return "Pack"
        case .wordNegotiation:
            return "Word"
        case .gamePage:
            return "Game"
        case .calendar:
            return "Hour"
        case .helpTips:
            return "Tips"
        case .welcome:
            return "Welcome"
        case .marginsAtlas:
            return "Atlas"
        case .bookConnections:
            return "Connections"
        case .bookRemembered:
            return "Remembered"
        case .bookNotices:
            return "Notices"
        case .glowInvitation:
            return "Glow"
        case .theBleed:
            return "Bleed"
        case .inventory:
            return "Inventory"
        case .bindery:
            return "Bindery"
        case .bookPocket:
            return "Pocket"
        case .plainPage:
            return "Plain"
        }
    }

    var symbolName: String {
        switch self {
        case .mood:
            return "cloud.sun"
        case .diary:
            return "book.pages"
        case .souvenir:
            return "quote.opening"
        case .rest:
            return "moon.stars"
        case .body:
            return "figure.mind.and.body"
        case .fuel:
            return "fork.knife"
        case .weather:
            return "cloud.rain"
        case .location:
            return "map"
        case .quip:
            return "sparkles"
        case .quotes:
            return "quote.bubble"
        case .affirmations:
            return "heart.text.square"
        case .aboutYou:
            return "person.text.rectangle"
        case .wonderCompass:
            return "safari"
        case .lore:
            return "books.vertical"
        case .patreon:
            return "shippingbox"
        case .illustration:
            return "photo.artframe"
        case .illuminatedPhoto:
            return "photo.on.rectangle.angled"
        case .narrativeOS:
            return "point.3.connected.trianglepath.dotted"
        case .gossip:
            return "bubble.left.and.text.bubble.right"
        case .note:
            return "note.text"
        case .facultyResearch:
            return "doc.text.magnifyingglass"
        case .letter:
            return "envelope.open"
        case .supportGuild:
            return "cross.case"
        case .bookOfYou:
            return "book.closed"
        case .askTheBook:
            return "text.bubble"
        case .inkrestOfficeHours:
            return "lamp.desk"
        case .faeBargain:
            return "hands.sparkles"
        case .bookFae:
            return "wand.and.stars"
        case .pactDispatch:
            return "flag.2.crossed"
        case .pactVerdict:
            return "scalemass"
        case .pactErrand:
            return "figure.walk"
        case .festival:
            return "moon.stars.fill"
        case .twoReadings:
            return "person.2.fill"
        case .castBond:
            return "person.2.wave.2"
        case .todaysSky:
            return "moon.stars"
        case .radio:
            return "radio"
        case .bookJump:
            return "book.closed.fill"
        case .enchantment:
            return "wand.and.sparkles"
        case .anchor:
            return "mappin.and.ellipse"
        case .academyClass:
            return "graduationcap"
        case .elective:
            return "envelope.badge"
        case .packPage:
            return "puzzlepiece.extension"
        case .wordNegotiation:
            return "textformat.abc.dottedunderline"
        case .gamePage:
            return "gamecontroller"
        case .calendar:
            return "calendar"
        case .helpTips:
            return "questionmark.circle"
        case .welcome:
            return "sparkles.rectangle.stack"
        case .marginsAtlas:
            return "point.3.filled.connected.trianglepath.dotted"
        case .bookConnections:
            return "sparkles.rectangle.stack"
        case .bookRemembered:
            return "clock.arrow.circlepath"
        case .bookNotices:
            return "sparkle.magnifyingglass"
        case .glowInvitation:
            return "sparkle"
        case .theBleed:
            return "newspaper"
        case .inventory:
            return "shippingbox.fill"
        case .bindery:
            return "books.vertical.fill"
        case .bookPocket:
            return "bag.fill"
        case .plainPage:
            return "square.and.pencil"
        }
    }
}

enum BookPageOrigin: String, Codable, Equatable {
    case userAuthored
    case generated
    case imported
    case simulated
}

enum BookPagePrivacy: String, Codable, Equatable {
    case privateLocal
    case localSensitive
    case publicReference
}

enum BookPageIntent: String, Codable, Equatable {
    case capture
    case reflect
    case rest
    case braid
    case importReference
    case resurface
    case simulate
}

enum BookPageRenderStyle: String, Codable, Equatable {
    case promptCard
    case gentleTranslation
    case quoteCard
    case loreLetter
    case illustrationPlate
    case illuminatedPhoto
    case graphEvent
    case archiveReturn
}

struct BookPagePayload: Codable, Equatable {
    var headline: String
    var body: String
    var metadata: [String: String]

    init(headline: String, body: String, metadata: [String: String] = [:]) {
        self.headline = headline
        self.body = body
        self.metadata = metadata
    }
}

struct BookPageSource: Codable, Identifiable, Equatable {
    var id: String
    var type: BookPageType
    var title: String
    var shortTitle: String
    var symbolName: String
    var origin: BookPageOrigin
    var privacy: BookPagePrivacy
    var isActive: Bool
    var cadence: String
    var note: String
}

enum BookPageSourceRegistry {
    static let wonderCompassSourceID = "wonder-compass"
    static let wonderCompassNoticeSourceID = "wonder-compass-notice"
    static let wonderCompassPlayfulMissionSourceID = "wonder-compass-playful-mission"

    static let sources: [BookPageSource] = [
        BookPageSource(
            id: "the-inventory",
            type: .inventory,
            title: "The Inventory",
            shortTitle: "Inventory",
            symbolName: "shippingbox.fill",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "always available; rises when something changes",
            note: "Fae gifts, Goblin wares, bound objects, and installed folios."
        ),
        BookPageSource(
            id: "bindery-call",
            type: .bindery,
            title: "The Bindery",
            shortTitle: "Bindery",
            symbolName: "books.vertical.fill",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "at the turn of a month, when the last one is ready to bind",
            note: "Sews a finished month into a chapter you can keep, share, or print."
        ),
        BookPageSource(
            id: "weekly-issue",
            type: .bindery,
            title: "Weekly Issue",
            shortTitle: "Issue",
            symbolName: "doc.richtext",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "weekly, once the week has closed",
            note: "Gathers the most recently completed week into a small issue you can keep or share."
        ),
        BookPageSource(
            id: "inner-weather",
            type: .mood,
            title: "Inner Weather",
            shortTitle: "Mood",
            symbolName: "cloud.sun",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "daily",
            note: "Named by you."
        ),
        BookPageSource(
            id: "diary-page",
            type: .diary,
            title: "Diary Page",
            shortTitle: "Diary",
            symbolName: "book.pages",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "What is happening inside this exact moment."
        ),
        BookPageSource(
            id: "plain-page",
            type: .plainPage,
            title: "Plain Page",
            shortTitle: "Plain",
            symbolName: "square.and.pencil",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Write anything. No prompt. No consequence."
        ),
        BookPageSource(
            id: "one-sentence-souvenir",
            type: .souvenir,
            title: "One-Sentence Souvenir",
            shortTitle: "Souvenir",
            symbolName: "quote.opening",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "evening",
            note: "A moment worth keeping."
        ),
        BookPageSource(
            id: "center-page",
            type: .rest,
            title: "Center Page",
            shortTitle: "Rest",
            symbolName: "moon.stars",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "as needed",
            note: "Low and gentle."
        ),
        BookPageSource(
            id: "book-of-you",
            type: .bookOfYou,
            title: "Book of You",
            shortTitle: "Braid",
            symbolName: "book.closed",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "daily",
            note: "Today, braided."
        ),
        BookPageSource(
            id: "ask-the-book",
            type: .askTheBook,
            title: "Chat with the Book",
            shortTitle: "Chat",
            symbolName: "text.bubble",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Start a private conversation with the Book."
        ),
        BookPageSource(
            id: "cast-enchantment",
            type: .enchantment,
            title: "Cast an Enchantment",
            shortTitle: "Spell",
            symbolName: "wand.and.sparkles",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Choose a spell, add a real photo, and keep the illuminated result."
        ),
        BookPageSource(
            id: "outer-stacks-anchor",
            type: .anchor,
            title: "Outer Stacks",
            shortTitle: "Anchor",
            symbolName: "mappin.and.ellipse",
            origin: .generated,
            privacy: .localSensitive,
            isActive: true,
            cadence: "nearby",
            note: "Opens when a known Anchor is close enough to light."
        ),
        BookPageSource(
            id: "narrative-os",
            type: .narrativeOS,
            title: "Story Page",
            shortTitle: "Story",
            symbolName: "point.3.connected.trianglepath.dotted",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "simulation",
            note: "Characters, belief, threads."
        ),
        BookPageSource(
            id: "margins-atlas",
            type: .marginsAtlas,
            title: "The Margins Atlas",
            shortTitle: "Atlas",
            symbolName: "point.3.filled.connected.trianglepath.dotted",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "whenever the threads thicken",
            note: "The Loom and the Constellation, drawn from relationships and Belief."
        ),
        BookPageSource(
            id: "book-connections",
            type: .bookConnections,
            title: "Book Connections",
            shortTitle: "Connections",
            symbolName: "sparkles.rectangle.stack",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when clusters gather",
            note: "The Book's visible map of clusters, constellations, themes, and evidence pages."
        ),
        BookPageSource(
            id: "the-book-remembered",
            type: .bookRemembered,
            title: "The Book Remembered",
            shortTitle: "Remembered",
            symbolName: "clock.arrow.circlepath",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "quiet visitation",
            note: "Old kept pages return when today rhymes with them."
        ),
        BookPageSource(
            id: "the-book-notices",
            type: .bookNotices,
            title: "The Book Notices",
            shortTitle: "Notices",
            symbolName: "sparkle.magnifyingglass",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when patterns gather",
            note: "The Book surfaces literary patterns, absences, living Beliefs, and duration."
        ),
        BookPageSource(
            id: "the-book-pocket",
            type: .bookPocket,
            title: "The Book's Pocket",
            shortTitle: "Pocket",
            symbolName: "bag.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when the pocket fills",
            note: "The little things swiped-away pages leave behind, emptied onto the desk now and then."
        ),
        BookPageSource(
            id: "spend-glow",
            type: .glowInvitation,
            title: "Spend Glow",
            shortTitle: "Glow",
            symbolName: "sparkle",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when the reader's Glow runs high",
            note: "A pressure valve for investing Belief in cast members, page sources, and other living parts of the Book."
        ),
        BookPageSource(
            id: "the-bleed",
            type: .theBleed,
            title: "The Bleed",
            shortTitle: "Bleed",
            symbolName: "newspaper",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "morning and evening editions",
            note: "Penny Blackletter's pocket newspaper. The interest column knowingly uses live web lookups (Reddit and the open web)."
        ),
        BookPageSource(
            id: "gossip-page",
            type: .gossip,
            title: "Gossip Page",
            shortTitle: "Gossip",
            symbolName: "bubble.left.and.text.bubble.right",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "four-hour turn",
            note: "What moved while you were elsewhere."
        ),
        BookPageSource(
            id: "student-notes",
            type: .note,
            title: "Notes",
            shortTitle: "Note",
            symbolName: "note.text",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "passing periods, classes, weather, and relationship turns",
            note: "Quick character notes slipped to you by students, with replies they remember."
        ),
        BookPageSource(
            id: "letter-page",
            type: .letter,
            title: "Letter Page",
            shortTitle: "Letter",
            symbolName: "envelope.open",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "character research",
            note: "NPCs write researched letters through the margins."
        ),
        BookPageSource(
            id: "support-guild",
            type: .supportGuild,
            title: "Support Guild Page",
            shortTitle: "Guild",
            symbolName: "cross.case",
            origin: .generated,
            privacy: .localSensitive,
            isActive: true,
            cadence: "daily synthesis",
            note: "Vellum and Inkrest compare charts."
        ),
        BookPageSource(
            id: "inkrest-office-hours",
            type: .inkrestOfficeHours,
            title: "Dr. Inkrest's Office Hours",
            shortTitle: "Office Hours",
            symbolName: "lamp.desk",
            origin: .generated,
            privacy: .localSensitive,
            isActive: true,
            cadence: "evening",
            note: "A short, distilled narrative-therapy sitting with Dr. Inkrest."
        ),
        BookPageSource(
            id: "fae-bargain",
            type: .faeBargain,
            title: "A Fae Bargain",
            shortTitle: "Bargain",
            symbolName: "hands.sparkles",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "fae",
            note: "A Book Fae gave first. Now a sensory return is owed."
        ),
        BookPageSource(
            id: "book-fae-page",
            type: .bookFae,
            title: "Book Fae Page",
            shortTitle: "Book Fae",
            symbolName: "wand.and.stars",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "fae",
            note: "A keepable parley with the old-law Fae of the margins."
        ),
        BookPageSource(
            id: "pact-dispatch",
            type: .pactDispatch,
            title: "A Pact Dispatch",
            shortTitle: "Dispatch",
            symbolName: "flag.2.crossed",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "pact",
            note: "Word from the Pact War: a shelf or door has changed hands."
        ),
        BookPageSource(
            id: "festival",
            type: .festival,
            title: "A Festival of the Wheel",
            shortTitle: "Festival",
            symbolName: "moon.stars.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "almanac",
            note: "A sabbat, a full moon, or a falling-star night — the world is keeping a feast."
        ),
        BookPageSource(
            id: "two-readings",
            type: .twoReadings,
            title: "The Two Readings",
            shortTitle: "Readings",
            symbolName: "person.2.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "responsive",
            note: "Two of the cast read your recent pages differently. You decide."
        ),
        BookPageSource(
            id: "cast-bond",
            type: .castBond,
            title: "A Turn in the Cast",
            shortTitle: "Cast",
            symbolName: "person.2.wave.2",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "emergent",
            note: "The web shifted on its own: a rivalry erupted, or an alliance formed."
        ),
        BookPageSource(
            id: "todays-sky",
            type: .todaysSky,
            title: "Today's Sky",
            shortTitle: "Sky",
            symbolName: "moon.stars",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "almanac",
            note: "The Book reads the night overhead: the Moon's phase and sign, the Sun's sign, and the nearest reason to look up."
        ),
        BookPageSource(
            id: "reenchanted-radio",
            type: .radio,
            title: "ReEnchanted Radio",
            shortTitle: "Radio",
            symbolName: "radio",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "tuned signal",
            note: "An analog station from the Academy. What you tune can tint which pages rise."
        ),
        BookPageSource(
            id: "book-jump",
            type: .bookJump,
            title: "Book Jump",
            shortTitle: "Jump",
            symbolName: "book.closed.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "expedition",
            note: "Step into a public-domain text, one controlled beat at a time, and return with a souvenir."
        ),
        BookPageSource(
            id: "faculty-research",
            type: .facultyResearch,
            title: "Faculty Research Notes",
            shortTitle: "Research",
            symbolName: "doc.text.magnifyingglass",
            origin: .generated,
            privacy: .localSensitive,
            isActive: true,
            cadence: "before guild meeting",
            note: "Vellum and Inkrest prepare private research."
        ),
        BookPageSource(
            id: "body-page",
            type: .body,
            title: "Body Page",
            shortTitle: "Body",
            symbolName: "figure.mind.and.body",
            origin: .generated,
            privacy: .localSensitive,
            isActive: true,
            cadence: "responsive",
            note: "Care without naming sensors."
        ),
        BookPageSource(
            id: "fuel-log",
            type: .fuel,
            title: "Fuel Log",
            shortTitle: "Fuel",
            symbolName: "fork.knife",
            origin: .userAuthored,
            privacy: .localSensitive,
            isActive: true,
            cadence: "bell windows",
            note: "Dr. Vellum's plate notes."
        ),
        BookPageSource(
            id: "weather-page",
            type: .weather,
            title: "Weather Page",
            shortTitle: "Weather",
            symbolName: "cloud.rain",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "ambient",
            note: "The world outside."
        ),
        BookPageSource(
            id: "location-page",
            type: .location,
            title: "Location Page",
            shortTitle: "Place",
            symbolName: "map",
            origin: .generated,
            privacy: .localSensitive,
            isActive: false,
            cadence: "place",
            note: "Maps, anchors, Outer Stacks."
        ),
        BookPageSource(
            id: "quip-page",
            type: .quip,
            title: "Quip Page",
            shortTitle: "Quip",
            symbolName: "sparkles",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "throughout the day",
            note: "Odd facts and small perspective sparks."
        ),
        BookPageSource(
            id: "quotes-page",
            type: .quotes,
            title: "A Quote to Keep",
            shortTitle: "Quote",
            symbolName: "quote.bubble",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "a few times a day",
            note: "Lines from poets, scientists, and quiet noticers on wonder, attention, and this one precious life."
        ),
        BookPageSource(
            id: "affirmations-page",
            type: .affirmations,
            title: "The Book Believes",
            shortTitle: "Believing",
            symbolName: "heart.text.square",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "mornings, mostly",
            note: "Small believings in the Book's own voice. Some ask for a countersigned agreement — an 'I will,' kept."
        ),
        BookPageSource(
            id: "about-you",
            type: .aboutYou,
            title: "About You",
            shortTitle: "You",
            symbolName: "person.text.rectangle",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "gradual",
            note: "One question at a time, so the Book learns with consent."
        ),
        BookPageSource(
            id: wonderCompassSourceID,
            type: .wonderCompass,
            title: "From the Wonder Compass Book",
            shortTitle: "Wonder Book",
            symbolName: "safari",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "practice",
            note: "Gemma-chosen book passages."
        ),
        BookPageSource(
            id: wonderCompassNoticeSourceID,
            type: .wonderCompass,
            title: "North = Notice",
            shortTitle: "Notice",
            symbolName: "sparkle.magnifyingglass",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "common",
            note: "A standalone I-wonder page for noticing one true detail."
        ),
        BookPageSource(
            id: wonderCompassPlayfulMissionSourceID,
            type: .wonderCompass,
            title: "South = Sense",
            shortTitle: "Sense",
            symbolName: "hand.draw",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "common",
            note: "A playful sensory mission that turns the real world into proof."
        ),
        BookPageSource(
            id: "labyrinth-lore",
            type: .lore,
            title: "Labyrinth Lore",
            shortTitle: "Lore",
            symbolName: "books.vertical",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "story",
            note: "Characters, rooms, classes, history, and living margins."
        ),
        BookPageSource(
            id: "patreon-packet",
            type: .patreon,
            title: "Creator Notes",
            shortTitle: "Notes",
            symbolName: "shippingbox",
            origin: .imported,
            privacy: .publicReference,
            isActive: false,
            cadence: "retired",
            note: "Retired creator/support surface kept only for older archives."
        ),
        BookPageSource(
            id: "labyrinth-illustrations",
            type: .illustration,
            title: "An Illustration from the Labyrinth of Stories",
            shortTitle: "Illustration",
            symbolName: "photo.artframe",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "hourly",
            note: "Bundled field-journal plates."
        ),
        BookPageSource(
            id: "illuminated-photos",
            type: .illuminatedPhoto,
            title: "Illuminated Photos",
            shortTitle: "Photos",
            symbolName: "photo.on.rectangle.angled",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "proposed",
            note: "Choose a photo, or let Penny find one, then illuminate it with Gemma."
        ),
        BookPageSource(
            id: "academy-class",
            type: .academyClass,
            title: "Classes & Clubs",
            shortTitle: "Classes",
            symbolName: "graduationcap",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "schedule",
            note: "Academy classes and clubs, in session at their real times."
        ),
        BookPageSource(
            id: "unwritten-elective",
            type: .elective,
            title: "Quests",
            shortTitle: "Quests",
            symbolName: "envelope.badge",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "occasional",
            note: "Characters ask small real-world quests tied to their unwritten interests. Five at most fit the flyleaf."
        ),
        BookPageSource(
            id: "game-page",
            type: .gamePage,
            title: "Game Page",
            shortTitle: "Game",
            symbolName: "gamecontroller",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when kept words want to move",
            note: "Small playable pages whose results become real archive material."
        ),
        BookPageSource(
            id: "calendar-page",
            type: .calendar,
            title: "The Inked Hour",
            shortTitle: "Hours",
            symbolName: "calendar",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "before events",
            note: "Real calendar hinges, folded into the margins before they arrive."
        ),
        BookPageSource(
            id: "help-and-tips",
            type: .helpTips,
            title: "Help and Tips",
            shortTitle: "Tips",
            symbolName: "questionmark.circle",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "helpful rotation",
            note: "Practical guidance, tricks, and ideas for using the Book well."
        ),
        BookPageSource(
            id: "labyrinth-welcome",
            type: .welcome,
            title: "Welcome Page",
            shortTitle: "Welcome",
            symbolName: "sparkles.rectangle.stack",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "first run",
            note: "The Labyrinth of Stories introduces itself and the daily loop."
        ),
        BookPageSource(
            id: "first-door-origin",
            type: .welcome,
            title: "The First Door",
            shortTitle: "First Door",
            symbolName: "door.left.hand.open",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "first run",
            note: "A private origin page made from the reader's first answers."
        ),
        BookPageSource(
            id: "first-door-apprenticeship",
            type: .helpTips,
            title: "First Door Apprenticeship",
            shortTitle: "First Week",
            symbolName: "sparkles.rectangle.stack",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "daily for seven days",
            note: "A gentle first-week path that turns the Book's core loop into habit."
        ),
        BookPageSource(
            id: "local-brain-awake",
            type: .welcome,
            title: "The Book Thinks Again",
            shortTitle: "Awake",
            symbolName: "brain.head.profile",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "after local brain install",
            note: "The Book notices when its local brain is installed and speaks with relief."
        ),
        BookPageSource(
            id: "pack-page",
            type: .packPage,
            title: "Installed Page Packs",
            shortTitle: "Packs",
            symbolName: "puzzlepiece.extension",
            origin: .imported,
            privacy: .privateLocal,
            isActive: true,
            cadence: "per pack",
            note: "Pages supplied by installed Page Packs — games, rituals, utilities, Routine, whatever fits the world."
        ),
        BookPageSource(
            id: "word-negotiation",
            type: .wordNegotiation,
            title: "Word Negotiation",
            shortTitle: "Words",
            symbolName: "textformat.abc.dottedunderline",
            origin: .imported,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when an event or pack gives a word agency",
            note: "A living word asks the reader to rule on what it may mean in this Book."
        )
    ]

    static let activeSources = sources.filter(\.isActive)
    static let plannedSources = sources.filter { !$0.isActive }

    static let automagicSourceIDs: Set<String> = [
        "inner-weather",
        "fuel-log"
    ]

    static func beliefProfiles(ledger: [String: Int] = [:]) -> [PageBeliefProfile] {
        sources.map { source in
            beliefProfile(for: source, ledger: ledger)
        }
    }

    static func beliefProfile(for type: BookPageType, ledger: [String: Int] = [:]) -> PageBeliefProfile {
        beliefProfile(for: source(for: type), ledger: ledger)
    }

    static func beliefProfile(for source: BookPageSource, ledger: [String: Int] = [:]) -> PageBeliefProfile {
        let defaultBelief = defaultBelief(for: source)
        let belief = max(0, min(100, defaultBelief + (ledger[source.id] ?? 0)))
        return PageBeliefProfile(
            sourceID: source.id,
            type: source.type,
            title: source.title,
            belief: belief,
            narrativeWeight: narrativeWeight(for: source),
            cadence: source.cadence,
            note: source.note
        )
    }

    static func defaultBelief(for source: BookPageSource) -> Int {
        switch source.id {
        case wonderCompassNoticeSourceID, wonderCompassPlayfulMissionSourceID:
            return 36
        default:
            break
        }

        switch source.type {
        case .mood, .fuel:
            return 36
        case .body, .supportGuild, .bookOfYou, .inkrestOfficeHours:
            return 32
        case .narrativeOS, .bookFae, .wonderCompass, .anchor, .welcome:
            return 30
        case .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .glowInvitation, .inventory, .bindery, .bookPocket:
            return 22
        case .diary, .souvenir, .askTheBook, .enchantment, .faeBargain:
            return 28
        case .pactDispatch:
            return 26
        case .pactVerdict:
            return 26
        case .pactErrand:
            return 26
        case .festival:
            return 34
        case .twoReadings:
            return 30
        case .castBond:
            return 30
        case .todaysSky, .bookJump, .radio:
            return 30
        case .weather, .gossip, .note, .facultyResearch, .letter, .academyClass, .elective:
            return 26
        case .theBleed:
            return 30
        case .aboutYou, .rest, .helpTips:
            return 24
        case .lore, .illustration, .illuminatedPhoto, .packPage, .wordNegotiation:
            return 22
        case .gamePage:
            return 28
        case .calendar:
            return 26
        case .quotes:
            return 26
        case .affirmations:
            return 28
        case .quip, .location, .patreon:
            return 18
        case .plainPage:
            return 18
        }
    }

    static func narrativeWeight(for source: BookPageSource) -> Int {
        switch source.type {
        case .narrativeOS, .bookFae:
            return 34
        case .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .glowInvitation, .inventory, .bindery, .bookPocket:
            return 18
        case .mood, .fuel:
            return 30
        case .wonderCompass, .bookOfYou, .anchor, .welcome:
            return 28
        case .body, .supportGuild, .inkrestOfficeHours:
            return 26
        case .diary, .souvenir, .faeBargain:
            return 24
        case .pactDispatch:
            return 22
        case .pactVerdict:
            return 22
        case .pactErrand:
            return 22
        case .festival:
            return 30
        case .twoReadings:
            return 26
        case .castBond:
            return 28
        case .todaysSky, .radio:
            return 24
        case .bookJump:
            return 30
        case .weather, .gossip, .note, .facultyResearch, .letter, .askTheBook, .enchantment, .academyClass, .elective:
            return 22
        case .theBleed:
            return 26
        case .aboutYou, .rest, .helpTips:
            return 20
        case .lore, .illustration, .illuminatedPhoto, .packPage, .wordNegotiation:
            return 18
        case .gamePage:
            return 26
        case .calendar:
            return 22
        case .quotes:
            return 20
        case .affirmations:
            return 22
        case .quip, .location, .patreon:
            return 14
        case .plainPage:
            return 14
        }
    }

    static func source(for type: BookPageType) -> BookPageSource {
        sources.first { $0.type == type } ?? BookPageSource(
            id: type.rawValue,
            type: type,
            title: type.title,
            shortTitle: type.shortTitle,
            symbolName: type.symbolName,
            origin: type == .bookOfYou ? .generated : .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Local page."
        )
    }

    static func source(id: String, fallbackType: BookPageType? = nil) -> BookPageSource {
        if let source = sources.first(where: { $0.id == id }) {
            return source
        }
        if let fallbackType {
            var source = Self.source(for: fallbackType)
            source.id = id
            return source
        }
        return BookPageSource(
            id: id,
            type: .souvenir,
            title: id,
            shortTitle: id,
            symbolName: "doc.text",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Local page source."
        )
    }
}

struct BookPageMediaAsset: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case bundledImage
        case renderedImageFile
        case photoLibraryAsset
        /// A kept voice recording (.m4a) stored in the app-group container by
        /// absolute path, alongside a dictated transcript.
        case audioFile
    }

    var id: String
    var kind: Kind
    var reference: String
    var caption: String
    var sourceID: String
    var metadata: [String: String]

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        reference: String,
        caption: String = "",
        sourceID: String = "",
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.reference = reference
        self.caption = caption
        self.sourceID = sourceID
        self.metadata = metadata
    }
}

// MARK: - Earned-reading memory

enum BookObservationStatus: String, Codable, Equatable {
    case asked
    case confirmed
    case notQuite
    case doNotRead
}

struct BookObservationRecord: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var status: BookObservationStatus
    var evidencePageIDs: [String]
    var firstPresentedAt: Date
    var updatedAt: Date
}

/// A hard, exact boundary. Unlike ordinary feedback this prevents the same
/// reading key from being proposed again until the reader explicitly changes
/// it; broad guesses about adjacent subjects remain possible.
struct BookReadingBoundary: Codable, Identifiable, Equatable {
    var id: String
    var createdAt: Date
}

/// A variable-ratio governor for the Book's larger surprises. Sessions warm
/// the possibility rather than scheduling a reveal on a calendar.
struct MagicMomentState: Codable, Equatable {
    var sessionCount: Int = 0
    var sessionsSinceMoment: Int = 0
    var isArmed: Bool = false
    var lastSessionAt: Date?
    var lastMomentAt: Date?
    var lastMomentKey: String?
}

enum MagicMomentGovernor {
    static let meaningfulSessionGap: TimeInterval = 20 * 60

    static func enteringSession(
        _ state: MagicMomentState,
        now: Date = Date(),
        roll: Int = Int.random(in: 0...99)
    ) -> MagicMomentState {
        var updated = state
        if let last = state.lastSessionAt,
           now.timeIntervalSince(last) < meaningfulSessionGap {
            return updated
        }
        updated.lastSessionAt = now
        updated.sessionCount += 1
        updated.sessionsSinceMoment += 1
        guard !updated.isArmed else { return updated }
        let chance: Int
        switch updated.sessionsSinceMoment {
        case ..<2: chance = 0
        case 2: chance = 18
        case 3: chance = 45
        case 4: chance = 72
        default: chance = 100
        }
        updated.isArmed = roll < chance
        return updated
    }

    static func consuming(
        _ state: MagicMomentState,
        key: String,
        now: Date = Date()
    ) -> MagicMomentState {
        var updated = state
        updated.isArmed = false
        updated.sessionsSinceMoment = 0
        updated.lastMomentAt = now
        updated.lastMomentKey = key
        return updated
    }
}

struct OvernightConnectionCandidate: Codable, Identifiable, Equatable {
    var id: String
    var observationKey: String
    var kind: String
    var deterministicFinding: String
    var evidencePageIDs: [String]
    var evidenceCards: String
}

struct OvernightConnectionDraft: Codable, Equatable {
    var observationKey: String
    var candidateID: String
    var evidenceSignature: String
    var kind: String
    var headline: String
    var interpretation: String
    var question: String
    var confidence: Int
    var evidencePageIDs: [String]
    var evidenceCards: String
    var generatedAt: Date
}

/// A deliberately coarse snapshot of the real-world context in which a page
/// was kept. It travels with the page so later observations compare the
/// weather/body/calendar that was true *then*, never whatever happens to be
/// current when the archive is reread.
///
/// The snapshot contains no coordinates, place names, calendar titles, or raw
/// Health data. It is private page context, not a second activity log.
struct BookPageContextSnapshot: Codable, Equatable {
    var timeZoneIdentifier: String
    var utcOffsetSeconds: Int
    var dayPart: String
    var weatherTags: [String]
    var bodyScore: Int?
    var calendarEventCount: Int?
    var nearbyAnchorID: String?

    init(
        at date: Date = Date(),
        calendar: Calendar = .current,
        weatherTags: [String] = [],
        bodyScore: Int? = nil,
        calendarEventCount: Int? = nil,
        nearbyAnchorID: String? = nil
    ) {
        let timeZone = calendar.timeZone
        self.timeZoneIdentifier = timeZone.identifier
        self.utcOffsetSeconds = timeZone.secondsFromGMT(for: date)
        self.dayPart = Self.dayPart(for: date, calendar: calendar)
        self.weatherTags = Array(Set(weatherTags.map(Self.normalizedWeatherTag).filter { !$0.isEmpty })).sorted()
        self.bodyScore = bodyScore.map { min(100, max(0, $0)) }
        self.calendarEventCount = calendarEventCount.map { max(0, $0) }
        self.nearbyAnchorID = nearbyAnchorID?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case timeZoneIdentifier
        case utcOffsetSeconds
        case dayPart
        case weatherTags
        case bodyScore
        case calendarEventCount
        case nearbyAnchorID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) ?? TimeZone.current.identifier
        utcOffsetSeconds = try container.decodeIfPresent(Int.self, forKey: .utcOffsetSeconds) ?? 0
        dayPart = try container.decodeIfPresent(String.self, forKey: .dayPart) ?? "unknown"
        weatherTags = try container.decodeIfPresent([String].self, forKey: .weatherTags) ?? []
        bodyScore = try container.decodeIfPresent(Int.self, forKey: .bodyScore)
        calendarEventCount = try container.decodeIfPresent(Int.self, forKey: .calendarEventCount)
        nearbyAnchorID = try container.decodeIfPresent(String.self, forKey: .nearbyAnchorID)
    }

    private static func dayPart(for date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...20: return "evening"
        default: return "night"
        }
    }

    private static func normalizedWeatherTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// The part of attention a real-world Page asks the reader to borrow. These
/// are deliberately broader than the five senses: place, people, kindness,
/// time, and imagination are ways of directing perception too.
enum HiddenMagicSense: String, Codable, CaseIterable, Equatable {
    case sight
    case sound
    case touch
    case scent
    case taste
    case body
    case weather
    case place
    case people
    case kindness
    case time
    case imagination

    var title: String {
        switch self {
        case .sight: return "Sight"
        case .sound: return "Sound"
        case .touch: return "Touch"
        case .scent: return "Scent"
        case .taste: return "Taste"
        case .body: return "Body"
        case .weather: return "Weather"
        case .place: return "Place"
        case .people: return "People"
        case .kindness: return "Kindness"
        case .time: return "Time"
        case .imagination: return "Imagination"
        }
    }

    var symbolName: String {
        switch self {
        case .sight: return "eye"
        case .sound: return "ear"
        case .touch: return "hand.raised"
        case .scent: return "wind"
        case .taste: return "mouth"
        case .body: return "figure.mind.and.body"
        case .weather: return "cloud.sun"
        case .place: return "mappin.and.ellipse"
        case .people: return "person.2"
        case .kindness: return "hands.sparkles"
        case .time: return "clock"
        case .imagination: return "sparkles"
        }
    }
}

enum HiddenMagicExpressionMode: String, Codable, CaseIterable, Equatable {
    case words
    case photograph
    case voice
}

/// A small real-world instruction carried by any outward-facing Page. The
/// Page keeps its own type, prose, and mechanics; this is only the common
/// grammar that lets the app guide action and recognize proof consistently.
struct HiddenMagicLens: Codable, Equatable {
    var id: String
    var sense: HiddenMagicSense
    var voice: String
    var action: String
    var proofPrompt: String
    var durationSeconds: Int
    var expressionModes: [HiddenMagicExpressionMode]
}

/// Durable proof that a reader used a lens in the real world. The page itself
/// remains the source of truth for the sentence, photograph, or recording; the
/// finding stores only the practice context needed to develop future lenses.
struct HiddenMagicFinding: Codable, Equatable {
    var lensID: String
    var sense: HiddenMagicSense
    var action: String
    var proofPrompt: String
    var expressionModes: [HiddenMagicExpressionMode]
    var foundAt: Date
}

/// A compact, private vocabulary of what a kept page actually contained and
/// the conditions under which it was kept. It lets the continuity layer notice
/// across prose, photographs, voice attachments, and real-world context without
/// retaining a second copy of the source media or exporting an embedding.
struct AttentionFingerprint: Codable, Equatable {
    var subjectTokens: [String]
    var visualTokens: [String]
    var voiceTokens: [String]
    var contextTokens: [String]
    var modalities: [String]

    var patternTokens: [String] {
        Array(Set(subjectTokens + visualTokens + voiceTokens + contextTokens)).sorted()
    }

    var patternText: String { patternTokens.joined(separator: " ") }

    static func make(from page: BookPage) -> AttentionFingerprint {
        var subjectText = "\(page.userInput) \(page.playerReply) \(page.tags.joined(separator: " "))"
        var visualText = ""
        var voiceText = ""
        var modalities = Set<String>()

        for asset in page.mediaAssets {
            let metadataText = asset.metadata
                .filter { key, _ in
                    let lowered = key.lowercased()
                    return !lowered.contains("path") && !lowered.contains("identifier")
                }
                .map(\.value)
                .joined(separator: " ")
            switch asset.kind {
            case .bundledImage, .renderedImageFile, .photoLibraryAsset:
                modalities.insert("photo")
                visualText += " \(asset.caption) \(metadataText)"
            case .audioFile:
                modalities.insert("voice")
                voiceText += " \(asset.caption) \(metadataText)"
            }
        }

        if page.userInput.nonEmpty != nil || page.playerReply.nonEmpty != nil {
            modalities.insert("words")
        }
        if page.type == .location || page.type == .anchor { modalities.insert("place") }
        if page.type == .weather { modalities.insert("weather") }

        var contextTokens: [String] = []
        if let context = page.context {
            contextTokens += context.weatherTags.map { "weather-\($0)" }
            if context.dayPart != "unknown" { contextTokens.append("hour-\(context.dayPart)") }
            if let score = context.bodyScore {
                if score <= 40 { contextTokens.append("body-low") }
                if score >= 70 { contextTokens.append("body-high") }
            }
            if let count = context.calendarEventCount {
                if count == 0 { contextTokens.append("tempo-open") }
                if count >= 3 { contextTokens.append("tempo-crowded") }
            }
            if let anchor = context.nearbyAnchorID {
                contextTokens.append("anchor-\(normalized(anchor))")
            }
        }

        // Prompt text is intentionally excluded. A generated prompt is what the
        // Book asked, not evidence of what the reader noticed.
        subjectText += page.origin == .userAuthored ? "" : " \(page.promptText)"
        return AttentionFingerprint(
            subjectTokens: tokens(in: subjectText),
            visualTokens: tokens(in: visualText),
            voiceTokens: tokens(in: voiceText),
            contextTokens: Array(Set(contextTokens)).sorted(),
            modalities: modalities.sorted()
        )
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "because", "book", "could", "from", "have",
        "into", "kept", "page", "pages", "photo", "that", "their", "there",
        "these", "they", "this", "today", "voice", "were", "what", "when",
        "where", "which", "with", "would", "your"
    ]

    private static func tokens(in text: String) -> [String] {
        Array(Set(text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .map(normalized)
            .filter { $0.count >= 4 && !stopWords.contains($0) && !$0.contains(where: \.isNumber) }
        )).sorted()
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}

struct BookPage: Codable, Identifiable, Equatable {
    var id: String
    var type: BookPageType
    var createdAt: Date
    var promptText: String
    var userInput: String
    var playerReply: String
    var tags: [String]
    var usedInBookOfYou: Bool
    var sourceID: String
    var origin: BookPageOrigin
    var privacy: BookPagePrivacy
    var promptVersion: String?
    var mediaAssets: [BookPageMediaAsset]
    var context: BookPageContextSnapshot?
    var attentionFingerprint: AttentionFingerprint?
    var hiddenMagicFinding: HiddenMagicFinding?
    /// Present when this archive page is a fully-bound weekly issue. Optional
    /// keeps older archives source-compatible and avoids flattening a whole
    /// magazine into tags that cannot reconstruct its reader.
    var weeklyIssueArtifact: KeptWeeklyIssueArtifact?
    /// Present when this archive page is a fully-bound monthly edition. Optional
    /// for the same reasons as `weeklyIssueArtifact` — older archives decode
    /// without it, and a whole edition can't be flattened into tags.
    var monthlyEditionArtifact: KeptMonthlyEditionArtifact?

    init(
        id: String = UUID().uuidString,
        type: BookPageType,
        createdAt: Date = Date(),
        promptText: String,
        userInput: String = "",
        playerReply: String = "",
        tags: [String] = [],
        usedInBookOfYou: Bool = false,
        sourceID: String? = nil,
        origin: BookPageOrigin? = nil,
        privacy: BookPagePrivacy = .privateLocal,
        promptVersion: String? = nil,
        mediaAssets: [BookPageMediaAsset] = [],
        context: BookPageContextSnapshot? = nil,
        attentionFingerprint: AttentionFingerprint? = nil,
        hiddenMagicFinding: HiddenMagicFinding? = nil,
        weeklyIssueArtifact: KeptWeeklyIssueArtifact? = nil,
        monthlyEditionArtifact: KeptMonthlyEditionArtifact? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.promptText = promptText
        self.userInput = userInput
        self.playerReply = playerReply
        self.tags = tags
        self.usedInBookOfYou = usedInBookOfYou
        self.sourceID = sourceID ?? type.rawValue
        self.origin = origin ?? (type == .bookOfYou ? .generated : .userAuthored)
        self.privacy = privacy
        self.promptVersion = promptVersion
        self.mediaAssets = mediaAssets
        self.context = context
        self.attentionFingerprint = attentionFingerprint
        self.hiddenMagicFinding = hiddenMagicFinding
        self.weeklyIssueArtifact = weeklyIssueArtifact
        self.monthlyEditionArtifact = monthlyEditionArtifact
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case createdAt
        case promptText
        case userInput
        case playerReply
        case tags
        case usedInBookOfYou
        case sourceID
        case origin
        case privacy
        case promptVersion
        case mediaAssets
        case context
        case attentionFingerprint
        case hiddenMagicFinding
        case weeklyIssueArtifact
        case monthlyEditionArtifact
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(BookPageType.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        promptText = try container.decode(String.self, forKey: .promptText)
        userInput = try container.decodeIfPresent(String.self, forKey: .userInput) ?? ""
        playerReply = try container.decodeIfPresent(String.self, forKey: .playerReply) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        usedInBookOfYou = try container.decodeIfPresent(Bool.self, forKey: .usedInBookOfYou) ?? false
        sourceID = try container.decodeIfPresent(String.self, forKey: .sourceID) ?? type.rawValue
        origin = try container.decodeIfPresent(BookPageOrigin.self, forKey: .origin) ?? (type == .bookOfYou ? .generated : .userAuthored)
        privacy = try container.decodeIfPresent(BookPagePrivacy.self, forKey: .privacy) ?? .privateLocal
        promptVersion = try container.decodeIfPresent(String.self, forKey: .promptVersion)
        mediaAssets = try container.decodeIfPresent([BookPageMediaAsset].self, forKey: .mediaAssets) ?? []
        context = try container.decodeIfPresent(BookPageContextSnapshot.self, forKey: .context)
        attentionFingerprint = try container.decodeIfPresent(AttentionFingerprint.self, forKey: .attentionFingerprint)
        hiddenMagicFinding = try container.decodeIfPresent(HiddenMagicFinding.self, forKey: .hiddenMagicFinding)
        weeklyIssueArtifact = try container.decodeIfPresent(KeptWeeklyIssueArtifact.self, forKey: .weeklyIssueArtifact)
        monthlyEditionArtifact = try container.decodeIfPresent(KeptMonthlyEditionArtifact.self, forKey: .monthlyEditionArtifact)
    }
}

extension BookPage {
    var resolvedAttentionFingerprint: AttentionFingerprint {
        attentionFingerprint ?? AttentionFingerprint.make(from: self)
    }

    /// The meaningful text archive previews should begin with. A kept letter's
    /// full prose remains untouched in `userInput`; only this derived preview
    /// skips its salutation when a body follows. Quote pages use a split storage
    /// shape, so their quotation and attribution are reunited here as well.
    var archivePreviewText: String? {
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let reply = playerReply.trimmingCharacters(in: .whitespacesAndNewlines)

        if type == .quotes {
            let attribution = input.isEmpty ? reply : input
            let parts = [prompt, attribution].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
        }

        // A letter's prose can live in `promptText` on older/onboarding pages;
        // `playerReply` is the reader's response and is only a last resort.
        let candidates = type == .letter ? [input, prompt, reply] : [input, reply, prompt]
        guard let storedText = candidates.first(where: { !$0.isEmpty }) else {
            return nil
        }
        guard type == .letter else { return storedText }
        return Self.letterTextDroppingLeadingSalutation(storedText)
    }

    /// The text Pagewright should place on a new scrap before the reader edits
    /// its pull quote.
    var pagewrightDefaultScrapText: String? {
        archivePreviewText
    }

    private static func letterTextDroppingLeadingSalutation(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return text }

        let firstLineEnd = normalized.firstIndex(of: "\n") ?? normalized.endIndex
        let firstLine = String(normalized[..<firstLineEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let laterText = firstLineEnd == normalized.endIndex
            ? ""
            : String(normalized[normalized.index(after: firstLineEnd)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

        // This also handles compact legacy letters such as
        // "Dear friend, I found ..." where the body begins on the same line.
        let explicitGreeting = #"^(?:dear(?:est)?|hello|hi|hey|my dear),?\s+[^,\n:!—–]{1,48}[,:!—–]\s*"#
        if let greetingRange = firstLine.range(
            of: explicitGreeting,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let inlineBody = String(firstLine[greetingRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let body = [inlineBody, laterText]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            if !body.isEmpty { return body }
        }

        guard isStandaloneLetterGreeting(firstLine), !laterText.isEmpty else {
            return normalized
        }
        return laterText
    }

    private static func isStandaloneLetterGreeting(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return false }

        let lowercased = trimmed.lowercased()
        let explicitOpenings = ["dearest", "dear", "hello", "hi", "hey", "my dear"]
        if explicitOpenings.contains(where: { opening in
            lowercased == opening
                || lowercased.hasPrefix("\(opening) ")
                || lowercased.hasPrefix("\(opening),")
                || lowercased.hasPrefix("\(opening):")
        }) {
            return true
        }

        // Some generated letters use only the reader's saved name as the
        // greeting, preserving its casing exactly (including "bj"). Accept a
        // short, name-shaped isolated line, but not sentence punctuation or a
        // sentence-length opening.
        let greetingPunctuation = CharacterSet(charactersIn: ",:.!—–")
        let finalIsPunctuation = trimmed.unicodeScalars.last.map(greetingPunctuation.contains) == true
        let name = (finalIsPunctuation ? String(trimmed.dropLast()) : trimmed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: CharacterSet(charactersIn: ",:;!?—–")) == nil else {
            return false
        }
        let words = name.split(whereSeparator: \Character.isWhitespace)
        let letterCount = name.unicodeScalars.filter(CharacterSet.letters.contains).count
        guard (1...4).contains(words.count), letterCount >= 2 else { return false }
        if trimmed.last == ".", words.count > 1 { return false }
        let allowedNamePunctuation = CharacterSet(charactersIn: "'’.-")
        return words.allSatisfy { word in
            word.unicodeScalars.allSatisfy {
                CharacterSet.letters.contains($0)
                    || CharacterSet.nonBaseCharacters.contains($0)
                    || allowedNamePunctuation.contains($0)
            }
        }
    }
}

struct BookDay: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var pages: [BookPage]

    var hasMood: Bool {
        pages.contains { $0.type == .mood }
    }

    var hasSouvenir: Bool {
        pages.contains { $0.type == .souvenir }
    }

    var hasRest: Bool {
        pages.contains { $0.type == .rest }
    }

    var bookOfYou: BookPage? {
        pages.last { $0.type == .bookOfYou }
    }

    var capturedPages: [BookPage] {
        let calendar = Calendar.current
        let start = Self.startDate(for: id, fallback: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return pages.filter { page in
            page.type != .bookOfYou
                && page.createdAt >= start
                && page.createdAt < end
        }
    }

    static func today(calendar: Calendar = .current) -> BookDay {
        day(containing: Date(), calendar: calendar)
    }

    static func day(containing date: Date, calendar: Calendar = .current) -> BookDay {
        let start = calendar.startOfDay(for: date)
        return BookDay(id: Self.id(for: start), date: start, pages: [])
    }

    static func id(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    static func startDate(for id: String, fallback date: Date, calendar: Calendar = .current) -> Date {
        let parts = id.split(separator: "-").compactMap { Int($0) }
        if parts.count == 3,
           let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
            return start
        }
        return calendar.startOfDay(for: date)
    }
}
