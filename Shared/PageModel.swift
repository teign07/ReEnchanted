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
    case aboutYou
    case wonderCompass
    case lore
    case patreon
    case illustration
    case illuminatedPhoto
    case narrativeOS
    case gossip
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
        case .facultyResearch:
            return "Faculty Research Note"
        case .letter:
            return "Letter Page"
        case .supportGuild:
            return "Support Guild Page"
        case .bookOfYou:
            return "Book of You"
        case .askTheBook:
            return "Ask the Book"
        case .inkrestOfficeHours:
            return "Dr. Inkrest's Office Hours"
        case .faeBargain:
            return "A Fae Bargain"
        case .bookFae:
            return "Book Fae Page"
        case .pactDispatch:
            return "A Pact Dispatch"
        case .pactVerdict:
            return "The Reading"
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
            return "Unwritten Electives"
        case .packPage:
            return "Pack Page"
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
            title: "Ask the Book",
            shortTitle: "Ask",
            symbolName: "text.bubble",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Ask one clear question. Get one useful answer."
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
            id: "wonder-compass",
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
            title: "Unwritten Electives",
            shortTitle: "Electives",
            symbolName: "envelope.badge",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "occasional",
            note: "Characters ask small real-world favors tied to their unwritten interests. Five at most fit the flyleaf."
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
            note: "Pages supplied by installed Page Packs — games, rituals, utilities, the Nothing, whatever fits the world."
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
        switch source.type {
        case .mood, .fuel:
            return 36
        case .body, .supportGuild, .bookOfYou, .inkrestOfficeHours:
            return 32
        case .narrativeOS, .bookFae, .wonderCompass, .anchor, .welcome:
            return 30
        case .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .glowInvitation, .inventory:
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
        case .weather, .gossip, .facultyResearch, .letter, .academyClass, .elective:
            return 26
        case .theBleed:
            return 30
        case .aboutYou, .rest, .helpTips:
            return 24
        case .lore, .illustration, .illuminatedPhoto, .packPage:
            return 22
        case .gamePage:
            return 28
        case .calendar:
            return 26
        case .quip, .location, .patreon:
            return 18
        }
    }

    static func narrativeWeight(for source: BookPageSource) -> Int {
        switch source.type {
        case .narrativeOS, .bookFae:
            return 34
        case .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .glowInvitation, .inventory:
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
        case .weather, .gossip, .facultyResearch, .letter, .askTheBook, .enchantment, .academyClass, .elective:
            return 22
        case .theBleed:
            return 26
        case .aboutYou, .rest, .helpTips:
            return 20
        case .lore, .illustration, .illuminatedPhoto, .packPage:
            return 18
        case .gamePage:
            return 26
        case .calendar:
            return 22
        case .quip, .location, .patreon:
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

struct BookPage: Codable, Identifiable, Equatable {
    var id: String
    var type: BookPageType
    var createdAt: Date
    var promptText: String
    var userInput: String
    var tags: [String]
    var usedInBookOfYou: Bool
    var sourceID: String
    var origin: BookPageOrigin
    var privacy: BookPagePrivacy
    var promptVersion: String?
    var mediaAssets: [BookPageMediaAsset]

    init(
        id: String = UUID().uuidString,
        type: BookPageType,
        createdAt: Date = Date(),
        promptText: String,
        userInput: String = "",
        tags: [String] = [],
        usedInBookOfYou: Bool = false,
        sourceID: String? = nil,
        origin: BookPageOrigin? = nil,
        privacy: BookPagePrivacy = .privateLocal,
        promptVersion: String? = nil,
        mediaAssets: [BookPageMediaAsset] = []
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.promptText = promptText
        self.userInput = userInput
        self.tags = tags
        self.usedInBookOfYou = usedInBookOfYou
        self.sourceID = sourceID ?? type.rawValue
        self.origin = origin ?? (type == .bookOfYou ? .generated : .userAuthored)
        self.privacy = privacy
        self.promptVersion = promptVersion
        self.mediaAssets = mediaAssets
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case createdAt
        case promptText
        case userInput
        case tags
        case usedInBookOfYou
        case sourceID
        case origin
        case privacy
        case promptVersion
        case mediaAssets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(BookPageType.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        promptText = try container.decode(String.self, forKey: .promptText)
        userInput = try container.decodeIfPresent(String.self, forKey: .userInput) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        usedInBookOfYou = try container.decodeIfPresent(Bool.self, forKey: .usedInBookOfYou) ?? false
        sourceID = try container.decodeIfPresent(String.self, forKey: .sourceID) ?? type.rawValue
        origin = try container.decodeIfPresent(BookPageOrigin.self, forKey: .origin) ?? (type == .bookOfYou ? .generated : .userAuthored)
        privacy = try container.decodeIfPresent(BookPagePrivacy.self, forKey: .privacy) ?? .privateLocal
        promptVersion = try container.decodeIfPresent(String.self, forKey: .promptVersion)
        mediaAssets = try container.decodeIfPresent([BookPageMediaAsset].self, forKey: .mediaAssets) ?? []
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

    private static func startDate(for id: String, fallback date: Date, calendar: Calendar = .current) -> Date {
        let parts = id.split(separator: "-").compactMap { Int($0) }
        if parts.count == 3,
           let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
            return start
        }
        return calendar.startOfDay(for: date)
    }
}
