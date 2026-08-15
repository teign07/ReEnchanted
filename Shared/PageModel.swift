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
    case tarot
    case lore
    case patreon
    case illustration
    case illuminatedPhoto
    case narrativeOS
    case gossip
    case bookAside
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
    case wickerDare
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
    case frontMatter
    /// A finished fairy tale, bound whole. The Book only makes one of these
    /// after the fact, when it has worked out that the reader was inside a
    /// shape older than the app is. See `TaleGrammar`.
    case taleBound
    /// The sacred dumb door: a promptless "just write" page. Never surfaced by
    /// the curator: it exists only when the reader opens it by hand. Enters the
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
            return "Ink for Today"
        case .souvenir:
            return "One-Sentence Souvenir"
        case .rest:
            return "Center Page"
        case .body:
            return "What the Body Knows"
        case .fuel:
            return "The Little Furnace"
        case .weather:
            return "What the Sky Is Doing"
        case .location:
            return "Where the World Put You"
        case .quip:
            return "A Loose Remark"
        case .quotes:
            return "A Quote to Keep"
        case .affirmations:
            return "I Believe"
        case .aboutYou:
            return "About You"
        case .wonderCompass:
            return "From the Wonder Compass Book"
        case .tarot:
            return "Tarot Pages"
        case .lore:
            return "From the Deeper Stacks"
        case .patreon:
            return "Creator Notes"
        case .illustration:
            return "An Illustration from the Labyrinth of Stories"
        case .illuminatedPhoto:
            return "Illuminated Photos"
        case .narrativeOS:
            return "The Story Stirred"
        case .gossip:
            return "Someone Has Been Talking"
        case .bookAside:
            return "An Aside"
        case .note:
            return "Notes"
        case .facultyResearch:
            return "A Note from the Faculty"
        case .letter:
            return "A Letter Arrived"
        case .supportGuild:
            return "Keep My Lamps Lit"
        case .bookOfYou:
            return "Book of You"
        case .askTheBook:
            return "Let’s Chat"
        case .inkrestOfficeHours:
            return "Dr. Inkrest's Office Hours"
        case .faeBargain:
            return "A Fae Bargain"
        case .bookFae:
            return "A Fae in My Margins"
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
            return "The Page Jumps"
        case .enchantment:
            return "Cast an Enchantment"
        case .anchor:
            return "Outer Stacks"
        case .academyClass:
            return "Rooms with Lessons"
        case .elective:
            return "An Unwritten Elective"
        case .wickerDare:
            return "Wicker's Dares"
        case .packPage:
            return "A New Sheaf"
        case .wordNegotiation:
            return "Word Negotiation"
        case .gamePage:
            return "A Page That Plays Back"
        case .calendar:
            return "The Hour Has Teeth"
        case .helpTips:
            return "How I Like to Be Read"
        case .welcome:
            return "I Open"
        case .marginsAtlas:
            return "The Margins Atlas"
        case .bookConnections:
            return "What Keeps Finding What"
        case .bookRemembered:
            return "I Remembered"
        case .bookNotices:
            return "I Notice"
        case .glowInvitation:
            return "Spend Glow"
        case .theBleed:
            return "The Bleed"
        case .inventory:
            return "The Inventory"
        case .bindery:
            return "The Bindery"
        case .taleBound:
            return "A Tale, Bound"
        case .bookPocket:
            return "My Pocket"
        case .frontMatter:
            return "The Front Matter"
        case .plainPage:
            return "A Loose Page"
        }
    }

    var shortTitle: String {
        switch self {
        case .mood:
            return "Weather"
        case .diary:
            return "Journal"
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
        case .tarot:
            return "Tarot"
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
        case .bookAside:
            return "Aside"
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
            return "Closer"
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
        case .wickerDare:
            return "Dare"
        case .packPage:
            return "Pack"
        case .wordNegotiation:
            return "Word"
        case .gamePage:
            return "Game"
        case .calendar:
            return "Hour"
        case .helpTips:
            return "My Habits"
        case .welcome:
            return "I Open"
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
        case .taleBound:
            return "Tale"
        case .bookPocket:
            return "Pocket"
        case .frontMatter:
            return "Front Matter"
        case .plainPage:
            return "Loose"
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
        case .tarot:
            return "rectangle.stack.fill"
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
        case .bookAside:
            return "text.book.closed"
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
        case .wickerDare:
            return "flame"
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
        case .taleBound:
            return "book.closed.circle.fill"
        case .bookPocket:
            return "bag.fill"
        case .frontMatter:
            return "text.book.closed.fill"
        case .plainPage:
            return "square.and.pencil"
        }
    }

    /// What the writing box at the bottom of this Page is actually for.
    ///
    /// Nearly every Page ends in the same text field, and for a long time that
    /// field said "Margin note / Add one true thing I should keep" no matter
    /// what the Page above it had just asked for. A reader who opened a Dare, a
    /// Fuel Log, and a Word Negotiation got the same shrug three times and had
    /// to guess. This names the job on every single Page.
    ///
    /// Rules for writing one: say the actual action, in the Book's mouth, in
    /// words a tired person can follow on the first read. No "let it", no "the
    /// hour", no "if one arrives". A Page-authored `placeholder` in metadata
    /// still wins over this: it can be more specific because it knows the
    /// particular dare, feast, or question.
    var marginAsk: (label: String, placeholder: String) {
        switch self {
        case .mood:
            return ("How it is in there", "Rainy, flat, buzzing, fine. However it actually is — I'm not going to try to fix it.")
        case .diary:
            return ("Your answer", "Answer the question up there. One sentence is a whole answer. I'm not grading it.")
        case .souvenir:
            return ("The souvenir", "One sentence from today you'd hate to lose. The exact thing, not the summary of it.")
        case .rest:
            return ("Only if you want to", "You don't have to write here. If a line turned up anyway, put it down.")
        case .body:
            return ("Where it's sitting", "Shoulders, jaw, stomach, feet. Just where — no diagnosis, nothing to fix.")
        case .fuel:
            return ("What you ran on", "What you ate and drank. Rough is fine. Nobody is counting anything.")
        case .weather:
            return ("The sky from where you are", "What it's doing outside your window, and whether you liked it.")
        case .location:
            return ("This place", "One thing about where you were that only someone standing there would know.")
        case .quip:
            return ("What you make of it", "Agree, argue, or say what it reminded you of.")
        case .quotes:
            return ("Why this one", "What this line does to you, or where you'd want to be when you read it again.")
        case .affirmations:
            return ("Your version", "Keep mine, cross it out, or write the truer one underneath. I'd rather have yours.")
        case .aboutYou:
            return ("Your answer", "Tell me. Dull facts are welcome — I'd much rather know than guess.")
        case .wonderCompass:
            return ("What you noticed", "The exact detail. What it looked like, sounded like, smelled like.")
        case .tarot:
            return ("What the cards got right", "What lands and what doesn't. Arguing with a card is allowed.")
        case .lore:
            return ("Your margin note", "What you want to remember from this, or the question it left you holding.")
        case .patreon:
            return ("Your note", "Anything you want to say back.")
        case .illustration:
            return ("What you see in it", "What's happening in this picture, to you. There's no right answer here.")
        case .illuminatedPhoto:
            return ("About this photo", "What was actually going on when this was taken.")
        case .narrativeOS:
            return ("Your margin note", "One private line about this before I file it.")
        case .gossip:
            return ("What you think", "Whose side you're on, or what you think really happened.")
        case .bookAside:
            return ("Back to me", "Say something back. I'm right here.")
        case .note:
            return ("Your reply", "Write back to them. They'll remember what you said.")
        case .facultyResearch:
            return ("Your margin note", "What of this is true about you, and what they've got wrong.")
        case .letter:
            return ("Your reply", "Write back. One line counts as a whole letter.")
        case .supportGuild:
            return ("Your margin note", "What you want them to know before they carry on arguing about you.")
        case .bookOfYou:
            return ("Your note on today", "What I missed, or the part of today I read wrong.")
        case .askTheBook:
            return ("Say something", "Ask me anything, or just start talking. No question required.")
        case .inkrestOfficeHours:
            return ("Your answer", "However it actually was. Small is fine.")
        case .faeBargain:
            return ("What you're offering", "Be exact. They hold you to the words, not the intention.")
        case .bookFae:
            return ("Your side of it", "What you want, or what you'll give. Say it plainly — they take words literally.")
        case .pactDispatch:
            return ("Your margin note", "What you make of the news.")
        case .pactVerdict:
            return ("Your ruling", "Say which reading is right and why. This is yours to decide, not mine.")
        case .pactErrand:
            return ("Proof", "What you actually did, in one line.")
        case .festival:
            return ("Keep the day", "One sentence about how this day went for you.")
        case .twoReadings:
            return ("Why you chose that", "Which of them read you right, and how you know.")
        case .castBond:
            return ("Your margin note", "What you make of the two of them now.")
        case .todaysSky:
            return ("Looking up", "Whether you went out and looked, and what you saw if you did.")
        case .radio:
            return ("What the music did", "What the room was like with this playing in it.")
        case .bookJump:
            return ("Souvenir from inside", "One line you're carrying back out with you.")
        case .enchantment:
            return ("About the photo", "What this photo really is, before I get my hands on it.")
        case .anchor:
            return ("This place", "What this place is to you. One line.")
        case .academyClass:
            return ("Your work for the class", "Do the small thing the class asked, then write what happened.")
        case .elective:
            return ("How it went", "What you actually did, and how it went. Badly is a real answer.")
        case .wickerDare:
            return ("Proof", "Did you do it? Say what happened. Chickening out counts as an answer.")
        case .packPage:
            return ("Your margin note", "Whatever this page asked you for.")
        case .wordNegotiation:
            return ("Your ruling", "Say what this word is allowed to mean in here. Your call is the final one.")
        case .gamePage:
            return ("What you kept", "One line about the run, or leave what the game handed you.")
        case .calendar:
            return ("Before and after", "What you want from this hour, and afterwards, what it was actually like.")
        case .helpTips:
            return ("Your margin note", "Tell me how you'd rather be read. I'll change.")
        case .welcome:
            return ("Your answer", "Anything at all. I've got nothing on you yet.")
        case .marginsAtlas:
            return ("Your margin note", "What you can see in this map that I can't.")
        case .bookConnections:
            return ("Your margin note", "Whether this connection is real, or whether I'm seeing things.")
        case .bookRemembered:
            return ("From here", "What this looks like from where you're standing today.")
        case .bookNotices:
            return ("Your margin note", "Tell me I'm right. Tell me I'm wrong. Both are useful to me.")
        case .glowInvitation:
            return ("Where the Glow goes", "Name what you're spending it on, and why them.")
        case .theBleed:
            return ("Your margin note", "What in this paper is worth cutting out and keeping.")
        case .inventory:
            return ("Your margin note", "What you want to do with one of these.")
        case .bindery:
            return ("A line for the front", "One sentence to open this chapter with.")
        case .taleBound:
            return ("Your margin note", "What it's like to see it laid out as a tale.")
        case .bookPocket:
            return ("About this", "What this thing is to you.")
        case .frontMatter:
            return ("Correct me", "If I've got something about you wrong, write over it here.")
        case .plainPage:
            return ("The page", "Anything. No question, no point, no consequence.")
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

// MARK: - Public Margins

/// The Public Margins are deliberately not an account or a sync service. The
/// two permissions are separate doors, both closed by default, and neither one
/// is allowed to imply the other.
struct PublicMarginsPreferences: Codable, Equatable {
    var acceptsIncomingPages = false
    var offersOutgoingContributions = false
}

enum PublicMarginsContributionKind: String, Codable, CaseIterable, Equatable {
    case souvenir
    case spark
    case choice
    case detail
}

struct PublicMarginsBroadcast: Codable, Identifiable, Equatable {
    var id: String
    var text: String
    var authorName: String
    var authorUsername: String
    var authorAvatarURL: String?
    var permalink: String
    var createdAt: String
}

struct PublicMarginsSouvenir: Codable, Identifiable, Equatable {
    var id: String
    var text: String
    var kind: PublicMarginsContributionKind
    var createdAt: String
}

struct PublicMarginsTally: Codable, Identifiable, Equatable {
    var id: String { choiceID }
    var choiceID: String
    var label: String
    var count: Int
}

struct PublicMarginsChoiceOption: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var count: Int
}

struct PublicMarginsChoicePoll: Codable, Identifiable, Equatable {
    var id: String
    var question: String
    var options: [PublicMarginsChoiceOption]
}

struct PublicMarginsSnapshot: Codable, Equatable {
    var generatedAt: String
    var contributionCount: Int
    var broadcasts: [PublicMarginsBroadcast]
    var creatorPosts: [PublicMarginsBroadcast]
    var souvenirs: [PublicMarginsSouvenir]
    var tallies: [PublicMarginsTally]
    var choicePoll: PublicMarginsChoicePoll? = nil
}

struct PublicMarginsContributionRequest: Codable, Equatable {
    var requestID: String
    var eventID: String
    var kind: PublicMarginsContributionKind
    var text: String?
    var category: String?
    var choiceID: String?
    var confirmedAt: String
    var consent: Consent

    struct Consent: Codable, Equatable {
        var publicDisplay: Bool
        var moderation: Bool
    }
}

struct PublicMarginsContributionReceipt: Codable, Equatable {
    var id: String
    var status: String
    var deletionToken: String
}

enum PublicMarginsText {
    static let maximumCharacters = 220

    /// Produces the exact one-sentence preview used for an explicit public
    /// contribution. It never reads or appends archive context.
    static func preparedSentence(from rawValue: String) -> String? {
        let collapsed = rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty, collapsed.count <= maximumCharacters else { return nil }
        guard URLDetector.containsURL(in: collapsed) == false else { return nil }
        return collapsed
    }

    private enum URLDetector {
        static func containsURL(in value: String) -> Bool {
            let lowercased = value.lowercased()
            return lowercased.contains("://")
                || lowercased.contains("www.")
                || lowercased.contains("x.com/")
                || lowercased.contains("twitter.com/")
        }
    }
}

enum BookPageRenderStyle: String, Codable, Equatable {
    case promptCard
    case gentleTranslation
    case quoteCard
    case loreLetter
    case illustrationPlate
    case illuminatedPhoto
    case graphEvent
    /// A beat of the Academy's own business, dramatised: one place, one turn,
    /// and a closing image that is never explained. Distinct from `graphEvent`,
    /// which reports that something happened.
    case witnessedScene
    case archiveReturn
    case tarotReading
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
            title: "Journal Page",
            shortTitle: "Journal",
            symbolName: "book.pages",
            origin: .userAuthored,
            privacy: .privateLocal,
            isActive: true,
            cadence: "usually in the evening; always available by hand",
            note: "One semantically aware question from me, with occasional questions from the cast."
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
            // The Center Page's body is written by the Book. A reader may add
            // a margin note, but keeping the Page does not make the essay
            // theirs.
            origin: .generated,
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
            title: "Let’s Chat",
            shortTitle: "Closer",
            symbolName: "text.bubble",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "manual",
            note: "Start a private conversation with me."
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
            title: "What Keeps Finding What",
            shortTitle: "Threads",
            symbolName: "sparkles.rectangle.stack",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when clusters gather",
            note: "My visible map of clusters, constellations, themes, and evidence pages."
        ),
        BookPageSource(
            id: "the-book-remembered",
            type: .bookRemembered,
            title: "I Remembered",
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
            title: "I Notice",
            shortTitle: "Notices",
            symbolName: "sparkle.magnifyingglass",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when patterns gather",
            note: "I surface literary patterns, absences, living Beliefs, and duration."
        ),
        BookPageSource(
            id: BookFoundGiftEngine.sourceID,
            type: .bookNotices,
            title: "Found Beyond the Casement",
            shortTitle: "Found for You",
            symbolName: "safari.fill",
            origin: .imported,
            privacy: .publicReference,
            isActive: false,
            cadence: "occasionally, when the Long Game commissions a broad public-web search",
            note: "A sourced public-web finding selected for the re-enchantment mission. Private Page text is never used as its search query."
        ),
        BookPageSource(
            id: BookFoundGiftEngine.jSpaceSourceID,
            type: .bookNotices,
            title: "Found in J-space",
            shortTitle: "A Strange Gift",
            symbolName: "shippingbox.and.arrow.backward.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: false,
            cadence: "occasionally, sharing a fourteen-to-twenty-eight-day irregular window with public-web finds",
            note: "A deterministic fictional artifact from my authored J-space catalog. It uses no network request and no daytime model call."
        ),
        BookPageSource(
            id: "book-reenchantment-director",
            type: .bookNotices,
            title: "My Long Game",
            shortTitle: "A Small Door",
            symbolName: "door.left.hand.open",
            origin: .generated,
            privacy: .privateLocal,
            isActive: false,
            cadence: "event-driven; finite campaigns separated by silence",
            note: "Notices, invites, and proportional real-world experiments chosen by my persistent re-enchantment director."
        ),
        BookPageSource(
            id: "the-book-pocket",
            type: .bookPocket,
            title: "My Pocket",
            shortTitle: "Pocket",
            symbolName: "bag.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "when the pocket fills",
            note: "Real fragments pressed loose by meaningful attention, emptied onto the desk now and then."
        ),
        BookPageSource(
            id: "the-front-matter",
            type: .frontMatter,
            title: "The Front Matter",
            shortTitle: "Front Matter",
            symbolName: "text.book.closed.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "seldom; when enough of you has been written down",
            note: "The pages at the front of a book that say what the book is. Everything I actually hold about you: your name in the story, what you are owed, what a finished tale left behind. If I have any of it wrong, write over me."
        ),
        BookPageSource(
            id: "tale-bound",
            type: .taleBound,
            title: "A Tale, Bound",
            shortTitle: "Tale",
            symbolName: "book.closed.circle.fill",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "only when one finishes; rare by nature",
            note: "When receipts I already hold turn out to have made the shape of a fairy tale, I bind it whole and hand it over. I ask nothing back."
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
            note: "A pressure valve for investing Belief in cast members, page sources, and other living parts of me."
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
            id: "book-aside",
            type: .bookAside,
            title: "An Aside",
            shortTitle: "Aside",
            symbolName: "text.book.closed",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "occasionally, when one fictional turn is too good for me to keep to myself",
            note: "I interrupt with my own delighted, worried, or indignant account of what just happened in the fiction."
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
            note: "A sabbat, a full moon, or a falling-star night: the world is keeping a feast."
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
            note: "I read the night overhead: the Moon's phase and sign, the Sun's sign, and the nearest reason to look up."
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
            id: "public-margins-creators",
            type: .quotes,
            title: "Elsewhere, Someone Noticed",
            shortTitle: "Elsewhere",
            symbolName: "person.2.wave.2",
            origin: .imported,
            privacy: .publicReference,
            isActive: false,
            cadence: "dormant",
            note: "A retired X adapter retained only for reversibility. Outside voices should return through durable, editorially reviewed sources rather than a social feed."
        ),
        BookPageSource(
            id: "public-margins-community",
            type: .quotes,
            title: "From the Public Margins",
            shortTitle: "Public Margins",
            symbolName: "text.bubble.fill",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "occasionally, only when the Public Margins doorway is open",
            note: "A moderated one-sentence souvenir offered deliberately by another reader."
        ),
        BookPageSource(
            id: "affirmations-page",
            type: .affirmations,
            title: "I Believe",
            shortTitle: "Believing",
            symbolName: "heart.text.square",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "mornings, mostly",
            note: "Small believings in my own voice. Some ask for a countersigned agreement: an 'I will,' kept."
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
            note: "One question at a time, so I learn with consent."
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
            id: "wickers-dares",
            type: .wickerDare,
            title: "Wicker's Dares",
            shortTitle: "Dares",
            symbolName: "flame",
            origin: .generated,
            privacy: .localSensitive,
            isActive: true,
            cadence: "one rotating dare available; the Curator paces its arrival",
            note: "A primary lived invitation: mischievous, voluntary dares that make ordinary life feel more alive. Real places are named only from fresh local signals."
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
            title: "How I Like to Be Read",
            shortTitle: "My Habits",
            symbolName: "questionmark.circle",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "helpful rotation",
            note: "The habits I have acquired, the doors I keep, and what the eraser is allowed to correct."
        ),
        BookPageSource(
            id: "labyrinth-welcome",
            type: .welcome,
            title: "I Open",
            shortTitle: "First Opening",
            symbolName: "sparkles.rectangle.stack",
            origin: .imported,
            privacy: .publicReference,
            isActive: true,
            cadence: "first run",
            note: "The first time I open far enough for the Labyrinth to look back."
        ),
        BookPageSource(
            id: "first-door-origin",
            type: .welcome,
            title: "The Inscription",
            shortTitle: "Inscription",
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
            title: "Inscription Apprenticeship",
            shortTitle: "First Week",
            symbolName: "sparkles.rectangle.stack",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "daily for seven days",
            note: "Seven small doors I hold open during our first week."
        ),
        BookPageSource(
            id: "local-brain-awake",
            type: .welcome,
            title: "I Think Again",
            shortTitle: "Awake",
            symbolName: "brain.head.profile",
            origin: .generated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "after local brain install",
            note: "I notice when my local brain is installed and say so with relief."
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
            note: "Pages supplied by installed Page Packs: games, rituals, utilities, Routine, whatever fits the world."
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
        ),
        BookPageSource(
            id: "tarot-pages",
            type: .tarot,
            title: "Tarot Pages",
            shortTitle: "Tarot",
            symbolName: "rectangle.stack.fill",
            origin: .simulated,
            privacy: .privateLocal,
            isActive: true,
            cadence: "daily; one kept reading per calendar day",
            note: "A one-card pull or a Root / Weather / Door spread, drawn locally from a real 78-card deck."
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
        case "wickers-dares":
            // Wicker is one half of the Book's primary lived invitation loop,
            // not a low-confidence novelty hiding behind imported reference.
            return 40
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
        case .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .glowInvitation, .inventory, .bindery, .bookPocket, .taleBound, .frontMatter:
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
        case .weather, .gossip, .bookAside, .note, .facultyResearch, .letter, .academyClass, .elective:
            return 26
        case .wickerDare:
            return 28
        case .theBleed:
            return 30
        case .aboutYou, .rest, .helpTips, .tarot:
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
        case .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices, .glowInvitation, .inventory, .bindery, .bookPocket, .taleBound, .frontMatter:
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
        case .weather, .gossip, .bookAside, .note, .facultyResearch, .letter, .askTheBook, .enchantment, .academyClass, .elective:
            return 22
        case .wickerDare:
            return 28
        case .theBleed:
            return 26
        case .aboutYou, .rest, .helpTips, .tarot:
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
    case questioned
    case forbidden

    /// The Book's immediate answer to feedback. Keeping this on the durable
    /// status prevents a positive tap from falling through to generic
    /// "correction" copy in one renderer while another reacts correctly.
    var feedbackReactionLine: String {
        switch self {
        case .confirmed:
            return "Yes! I knew those Pages were touching. Keep the underline. The ink is strutting."
        case .notQuite, .questioned:
            return "Ha. Crooked reading. I lifted the pencil. Now I am watching for a truer shape."
        case .doNotRead, .forbidden:
            return "That path is shut. I will not read you that way again. The pencil is chewing a different corner."
        case .asked:
            return "The question is still open. The pencil is waiting. It hates waiting."
        }
    }
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

/// The Book's larger surprises are earned by meaningful attention, never by
/// reopening the app. The persisted field names retain their original
/// session-based spelling so existing saves decode without migration.
struct MagicMomentState: Codable, Equatable {
    var sessionCount: Int = 0
    var sessionsSinceMoment: Int = 0
    var isArmed: Bool = false
    var lastSessionAt: Date?
    var lastMomentAt: Date?
    var lastMomentKey: String?
    var lastMeaningfulActionKey: String?
}

enum MagicMomentGovernor {
    static let livedDaysToArm = 3

    /// Source-compatible tombstone for the old in-app action counter. Page
    /// actions are not lived evidence, so this path can never warm a reveal.
    static func recordingMeaningfulAction(
        _ state: MagicMomentState,
        key: String,
        now: Date = Date()
    ) -> MagicMomentState {
        state
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

    /// Reconciles the legacy persisted counter with actual Long Game receipts.
    /// The old names stay for save compatibility; only distinct qualifying lived
    /// days after the last reveal can arm a new moment.
    static func reconcilingLivedEvidence(
        _ state: MagicMomentState,
        evidence: [BookLongGameEvidence],
        now: Date = Date()
    ) -> MagicMomentState {
        var updated = state
        guard !updated.isArmed else { return updated } // grandfather an already armed save
        let qualifying: Set<BookLongGameEvidenceKind> = [.spontaneousKeep, .explicitFieldNote, .completedExperiment, .spontaneousPattern, .readerDeclaration]
        let days = Set(evidence.filter { receipt in
            qualifying.contains(receipt.kind)
                && receipt.happenedAt <= now
                && (updated.lastMomentAt.map { receipt.happenedAt > $0 } ?? true)
        }.map { BookDay.id(for: $0.happenedAt) })
        updated.sessionsSinceMoment = days.count
        updated.isArmed = days.count >= livedDaysToArm
        return updated
    }
}

/// The exact outside-the-covers agreement made in the Inscription. Morning is a
/// keepable prompt, evening is the braid's return, both is one of each, and
/// inside means the Book never schedules an ordinary call.
enum BookWhisperCadence: String, Codable, CaseIterable, Equatable {
    case morning
    case evening
    case both
    case inside

    var allowsMorning: Bool { self == .morning || self == .both }
    var allowsEvening: Bool { self == .evening || self == .both }

    var enablesBookWhispers: Bool { allowsEvening }
    var enablesPromptWhispers: Bool { allowsMorning }

    static func resolved(bookWhispersEnabled: Bool, promptWhispersEnabled: Bool) -> BookWhisperCadence {
        switch (bookWhispersEnabled, promptWhispersEnabled) {
        case (true, true): return .both
        case (true, false): return .evening
        case (false, true): return .morning
        case (false, false): return .inside
        }
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
    /// A Book-sized claim, not a restatement of the deterministic finding.
    /// Optional preserves every draft written before the interpretation forge.
    var thesis: String? = nil
    /// The strongest honest rival reading supplied in the same model turn.
    var counterReading: String? = nil
    /// One observable future receipt that would make the Book revise.
    var falsifier: String? = nil
    /// The human stakes: why this might alter how the reader sees the life,
    /// without diagnosing what the reader feels or who they are.
    var whyItMatters: String? = nil
    /// A rare cross-history reframe composed overnight from exact supplied
    /// ingredients. The prose may surprise; the IDs are the receipts.
    var surpriseHeadline: String? = nil
    var surpriseSynthesis: String? = nil
    var surpriseWhyUnexpected: String? = nil
    var surpriseIngredientIDs: [String]? = nil
    /// Frozen exact ingredients that passed the synthesis audit. Keeping the
    /// snapshot prevents a delayed surprise from losing its receipts merely
    /// because the Book acquired a newer memory before the Page surfaced.
    var surpriseIngredients: [BookInterpretationIngredient]? = nil
    var surpriseConfidence: Int? = nil
}

/// One compact, attributable piece of shared history offered to the overnight
/// interpretation forge. The local model may connect these pieces; it may not
/// invent an extra ingredient or rewrite their source authority.
struct BookInterpretationIngredient: Codable, Equatable, Identifiable {
    var id: String
    var kind: String
    var line: String
    var evidencePageIDs: [String]
}

/// A deliberately coarse snapshot of the real-world context in which a page
/// was kept. It travels with the page so later observations compare the
/// weather/body/calendar that was true *then*, never whatever happens to be
/// current when the archive is reread.
///
/// The snapshot contains no coordinates, calendar titles, raw Health data, or
/// copied chart prose. A location is a reader-approved label/Anchor, while Fuel
/// and Inner Weather are references to their private chart entries. It is
/// private page context, not a second activity log.
struct BookPageContextSnapshot: Codable, Equatable {
    var timeZoneIdentifier: String
    var utcOffsetSeconds: Int
    var dayPart: String
    var weatherTags: [String]
    var bodyScore: Int?
    var calendarEventCount: Int?
    var nearbyAnchorID: String?
    var locationLabel: String?
    var innerWeatherEntryID: String?
    var fuelEntryID: String?
    /// Split body metrics, carried beside the composite `bodyScore` so a page
    /// can later be related to the night behind it rather than only to a banded
    /// "tired or lively". Each stays nil when the reader has not shared it.
    var sleepHours: Double?
    var steps: Int?
    var restingHeartRate: Int?
    var heartRateVariability: Double?

    init(
        at date: Date = Date(),
        calendar: Calendar = .current,
        weatherTags: [String] = [],
        bodyScore: Int? = nil,
        calendarEventCount: Int? = nil,
        nearbyAnchorID: String? = nil,
        locationLabel: String? = nil,
        innerWeatherEntryID: String? = nil,
        fuelEntryID: String? = nil,
        sleepHours: Double? = nil,
        steps: Int? = nil,
        restingHeartRate: Int? = nil,
        heartRateVariability: Double? = nil
    ) {
        let timeZone = calendar.timeZone
        self.timeZoneIdentifier = timeZone.identifier
        self.utcOffsetSeconds = timeZone.secondsFromGMT(for: date)
        self.dayPart = Self.dayPart(for: date, calendar: calendar)
        self.weatherTags = Array(Set(weatherTags.map(Self.normalizedWeatherTag).filter { !$0.isEmpty })).sorted()
        self.bodyScore = bodyScore.map { min(100, max(0, $0)) }
        self.calendarEventCount = calendarEventCount.map { max(0, $0) }
        self.nearbyAnchorID = nearbyAnchorID?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.locationLabel = locationLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.innerWeatherEntryID = innerWeatherEntryID?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.fuelEntryID = fuelEntryID?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        // A negative or absurd reading is a missing reading. Sleep is clamped to
        // a day so a mis-scoped HealthKit query can't teach the Book that the
        // reader slept for forty hours.
        self.sleepHours = sleepHours.flatMap { $0 > 0 && $0 <= 24 ? $0 : nil }
        self.steps = steps.flatMap { $0 > 0 ? $0 : nil }
        self.restingHeartRate = restingHeartRate.flatMap { $0 > 0 ? $0 : nil }
        self.heartRateVariability = heartRateVariability.flatMap { $0 > 0 ? $0 : nil }
    }

    private enum CodingKeys: String, CodingKey {
        case timeZoneIdentifier
        case utcOffsetSeconds
        case dayPart
        case weatherTags
        case bodyScore
        case calendarEventCount
        case nearbyAnchorID
        case locationLabel
        case innerWeatherEntryID
        case fuelEntryID
        case sleepHours
        case steps
        case restingHeartRate
        case heartRateVariability
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
        locationLabel = try container.decodeIfPresent(String.self, forKey: .locationLabel)
        innerWeatherEntryID = try container.decodeIfPresent(String.self, forKey: .innerWeatherEntryID)
        fuelEntryID = try container.decodeIfPresent(String.self, forKey: .fuelEntryID)
        // Absent from every snapshot written before Phase 1, which is the
        // honest answer for those days rather than a reconstructed one.
        sleepHours = try container.decodeIfPresent(Double.self, forKey: .sleepHours)
        steps = try container.decodeIfPresent(Int.self, forKey: .steps)
        restingHeartRate = try container.decodeIfPresent(Int.self, forKey: .restingHeartRate)
        heartRateVariability = try container.decodeIfPresent(Double.self, forKey: .heartRateVariability)
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

/// Legacy decoding support for pages kept before the cross-page lens system was
/// retired. New pages never create this value; keeping it optional preserves
/// existing private archives without letting the old interaction back into UI.
struct HiddenMagicFinding: Codable, Equatable {
    var lensID: String
    var sense: HiddenMagicSense
    var action: String
    var proofPrompt: String
    var expressionModes: [HiddenMagicExpressionMode]
    var foundAt: Date
}

/// The kinds of lived work that can leave a receipt in the archive.
///
/// This is intentionally smaller than the Book's full page taxonomy. A receipt
/// means the Page asked for something outside its own interface and the reader
/// brought back evidence. The receipt gives continuity, achievements, and the
/// Long Game one typed object to read without turning every kept Page into a
/// quest completion.
enum LivedQuestKind: String, Codable, CaseIterable, Equatable {
    /// Compatibility case for an outward Page that is not one of the older
    /// named quest families. The containing receipt type keeps its historical
    /// name so existing private archives remain source- and migration-safe.
    case livedEncounter
    case playfulMission
    case wickerDare
    case wonderCompass
    case academyFieldwork
    case pactErrand
    case faeBargain
    case bookCampaign
    case bookWorking
    case elective

    var title: String {
        switch self {
        case .livedEncounter: return "Lived Encounter"
        case .playfulMission: return "Playful Mission"
        case .wickerDare: return "Wicker Dare"
        case .wonderCompass: return "Wonder Compass"
        case .academyFieldwork: return "Academy Fieldwork"
        case .pactErrand: return "Pact Errand"
        case .faeBargain: return "Fae Bargain"
        case .bookCampaign: return "A Small Experiment"
        case .bookWorking: return "A Working"
        case .elective: return "Unwritten Elective"
        }
    }
}

/// Observable capacities a lived quest may practice. These mirror the Long
/// Game's human meanings without importing its strategic machinery into the
/// archive model, which is also read by lighter-weight app targets.
enum LivedWonderFacet: String, Codable, CaseIterable, Equatable {
    case exactAttention
    case worldOtherness
    case scriptFreedom
    case selfAuthorship
    case personalLanguage
    case livingConnection
    case deliberateReturn

    var title: String {
        switch self {
        case .exactAttention: return "Exact Attention"
        case .worldOtherness: return "A World With Its Own Business"
        case .scriptFreedom: return "Freedom From the Default Script"
        case .selfAuthorship: return "Self-Authored Magic"
        case .personalLanguage: return "Language of Your Own"
        case .livingConnection: return "Wonder With Another Life"
        case .deliberateReturn: return "Return With a Difference"
        }
    }
}

/// Typed proof that a Page escaped the screen.
///
/// The reader's evidence remains on the containing `BookPage`; this receipt
/// preserves the invitation, the requested proof, and the kind of lived
/// capacity involved. That is enough for a later Page to say why this mattered
/// without copying private media or pretending completion proved a permanent
/// transformation.
struct LivedQuestReceipt: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var kind: LivedQuestKind
    var questID: String
    var title: String
    var invitation: String
    var proofPrompt: String
    var facets: [LivedWonderFacet]
    var sourceTags: [String]
    var hasWrittenProof: Bool
    var hasVisualProof: Bool
    var completedAt: Date
    var wasPromptedByBook: Bool
    /// New universal contracts preserve the exact evidence shapes that were
    /// returned. Optional fields keep version-one private archives decodable.
    var evidenceModes: [PageCapabilityProofMode]? = nil
    var encounterContractSignature: String? = nil
    var followUpDueAt: Date? = nil

    var resolvedEvidenceModes: [PageCapabilityProofMode] {
        if let evidenceModes { return evidenceModes }
        var modes: [PageCapabilityProofMode] = []
        if hasWrittenProof { modes.append(.observation) }
        if hasVisualProof { modes.append(.photograph) }
        return modes
    }

    var hasAnyProof: Bool {
        hasWrittenProof || hasVisualProof || !resolvedEvidenceModes.isEmpty
    }

    static func from(
        surface: SurfacePage,
        readerInput: String,
        mediaAssets: [BookPageMediaAsset],
        completedAt: Date
    ) -> LivedQuestReceipt? {
        let metadata = surface.payload.metadata
        let contract = surface.livedEncounterContract
        let archiveTags = metadata["tags"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        // A measurement object for one thing only: what the reader contributed.
        //
        // `readerInput` arrives in two different shapes and they need opposite
        // treatment. On a prepared Page the app hands back the Book's own body,
        // with any reader addition appended under a label — so the probe must
        // stay Book-authored and let the labelled-block parser find the reader's
        // part, or an untouched body would mint proof of nothing. On a Page the
        // reader simply wrote into, the input is theirs entire and carries no
        // labels at all; inheriting the surface's origin there sent their
        // sentence down the same parser, which found no labels and concluded
        // they had written nothing, so an outward invitation could never mint
        // the observation it had just been given.
        //
        // Which shape it is, is decided by whether the prepared body is still
        // in it. The stored reply is deliberately not carried in: it belongs to
        // the Page being answered, not to this contribution.
        let preparedBody = surface.payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let carriesPreparedBody = !preparedBody.isEmpty
            && readerInput.contains(preparedBody)
        let provenanceProbe = BookPage(
            type: surface.type,
            createdAt: completedAt,
            promptText: surface.prompt,
            userInput: readerInput,
            tags: archiveTags,
            sourceID: surface.sourceID,
            origin: carriesPreparedBody ? surface.origin : .userAuthored,
            privacy: surface.privacy,
            mediaAssets: mediaAssets
        )
        let readerWroteProof = provenanceProbe.readerAuthoredTextForAnalysis != nil
        let readerBroughtVisualProof = provenanceProbe.hasReaderPhotograph
        let contractEvidence = contract.acceptedEvidenceModes(
            readerInput: readerInput,
            mediaAssets: mediaAssets
        )
        let resolved: (kind: LivedQuestKind, id: String)?

        if let id = metadata["playfulMissionID"]?.nonEmpty {
            resolved = (.playfulMission, id)
        } else if let id = metadata["wickerDareID"]?.nonEmpty {
            resolved = (.wickerDare, id)
        } else if let id = metadata["runID"]?.nonEmpty,
                  metadata["compassStep"]?.nonEmpty != nil || surface.type == .wonderCompass {
            resolved = (.wonderCompass, id)
        } else if let id = metadata["academyActivityID"]?.nonEmpty
                    ?? metadata["academyActivity"]?.nonEmpty {
            resolved = (.academyFieldwork, id)
        } else if let id = metadata["pactErrandID"]?.nonEmpty
                    ?? metadata["errandID"]?.nonEmpty
                    ?? metadata["pactErrand"]?.nonEmpty {
            resolved = (.pactErrand, id)
        } else if let id = metadata["faeBargainID"]?.nonEmpty
                    ?? metadata["bargainID"]?.nonEmpty {
            resolved = (.faeBargain, id)
        } else if let id = metadata["bookWorkingID"]?.nonEmpty {
            resolved = (.bookWorking, id)
        } else if let id = metadata["bookCampaignID"]?.nonEmpty {
            resolved = (.bookCampaign, id)
        } else if let id = metadata["electiveID"]?.nonEmpty {
            resolved = (.elective, id)
        } else if contract.mayMintLivedReceipt, !contractEvidence.isEmpty {
            resolved = (.livedEncounter, contract.encounterID)
        } else {
            resolved = nil
        }

        guard let resolved else { return nil }

        let sourceTags = normalizedTags(metadata["tags"], additional: [
            metadata["missionTags"],
            metadata["wickerDareTags"],
            metadata["bookCampaignOutcomeTag"],
            surface.sourceID,
            surface.type.rawValue
        ])
        let title = metadata["playfulMissionTitle"]?.nonEmpty
            ?? metadata["wickerDareTitle"]?.nonEmpty
            ?? metadata["electiveTitle"]?.nonEmpty
            ?? metadata["academyActivityTitle"]?.nonEmpty
            ?? (resolved.kind == .livedEncounter ? surface.payload.headline.nonEmpty : nil)
            ?? surface.payload.headline.nonEmpty
            ?? resolved.kind.title
        let invitation = metadata["missionPrompt"]?.nonEmpty
            ?? metadata["mission"]?.nonEmpty
            ?? metadata["wickerDarePrompt"]?.nonEmpty
            ?? metadata["electiveAsk"]?.nonEmpty
            ?? metadata["academyActivityInvitation"]?.nonEmpty
            ?? metadata["terms"]?.nonEmpty
            ?? metadata["bookCampaignIntendedEffect"]?.nonEmpty
            ?? (resolved.kind == .livedEncounter ? contract.invitation.nonEmpty : nil)
            ?? surface.payload.body.nonEmpty
            ?? surface.prompt
        let proofPrompt = metadata["souvenirPrompt"]?.nonEmpty
            ?? metadata["placeholder"]?.nonEmpty
            ?? metadata["electivePractice"]?.nonEmpty
            ?? metadata["proofPrompt"]?.nonEmpty
            ?? metadata["terms"]?.nonEmpty
            ?? (resolved.kind == .livedEncounter ? contract.returnPrompt.nonEmpty : nil)
            ?? "Bring back one exact thing."
        let facetSignals = normalizedTags(
            nil,
            additional: [title, invitation, proofPrompt] + sourceTags.map(Optional.some)
        )
        let facets = resolved.kind == .livedEncounter && !contract.facets.isEmpty
            ? contract.facets
            : facets(for: facetSignals, kind: resolved.kind)
        let hasVisualProof = readerBroughtVisualProof
        var evidenceModes = contractEvidence.filter { mode in
            switch mode {
            case .response, .observation, .place, .person:
                return readerWroteProof
            case .photograph:
                return hasVisualProof
            case .voice:
                return provenanceProbe.hasReaderAudioRecording
            }
        }
        if resolved.kind != .livedEncounter {
            if readerWroteProof,
               !evidenceModes.contains(where: { [.observation, .place, .person].contains($0) }) {
                evidenceModes.append(.observation)
            }
            if hasVisualProof, !evidenceModes.contains(.photograph) {
                evidenceModes.append(.photograph)
            }
            if provenanceProbe.hasReaderAudioRecording,
               !evidenceModes.contains(.voice) {
                evidenceModes.append(.voice)
            }
        }
        evidenceModes.sort { $0.rawValue < $1.rawValue }
        let followUpDueAt = contract.earliestFollowUpHours.map {
            completedAt.addingTimeInterval(Double($0) * 3_600)
        }

        return LivedQuestReceipt(
            kind: resolved.kind,
            questID: resolved.id,
            title: title,
            invitation: invitation,
            proofPrompt: proofPrompt,
            facets: facets,
            sourceTags: sourceTags,
            hasWrittenProof: readerWroteProof,
            hasVisualProof: hasVisualProof,
            completedAt: completedAt,
            wasPromptedByBook: true,
            evidenceModes: evidenceModes,
            encounterContractSignature: contract.signature,
            followUpDueAt: followUpDueAt
        )
    }

    /// Builds the same receipt for a Flyleaf quest, whose proof is written
    /// directly into `UnwrittenElective` rather than passing through the
    /// ordinary SurfacePage keep path.
    static func from(
        elective: UnwrittenElective,
        completedAt: Date
    ) -> LivedQuestReceipt {
        var sourceTags = [
            "elective",
            "entity:\(elective.characterID)"
        ]
        if elective.bookFavorID != nil {
            sourceTags.append("book-favor")
        }
        if elective.proofPhotoURL?.nonEmpty != nil {
            sourceTags.append("photo")
        }
        if elective.proofLocationSummary?.nonEmpty != nil {
            sourceTags.append("place")
        }
        let facetSignals = normalizedTags(
            nil,
            additional: sourceTags.map(Optional.some) + [
                elective.title,
                elective.ask,
                elective.whyItMatters,
                elective.practiceShape
            ]
        )

        return LivedQuestReceipt(
            kind: .elective,
            questID: elective.id,
            title: elective.title,
            invitation: elective.ask,
            proofPrompt: elective.practiceShape,
            facets: facets(for: facetSignals, kind: .elective),
            sourceTags: sourceTags.sorted(),
            hasWrittenProof: elective.proof?.nonEmpty != nil
                || elective.proofLocationSummary?.nonEmpty != nil,
            hasVisualProof: elective.proofPhotoURL?.nonEmpty != nil,
            completedAt: completedAt,
            wasPromptedByBook: true
        )
    }

    private static func normalizedTags(
        _ raw: String?,
        additional: [String?]
    ) -> [String] {
        let values = ([raw] + additional)
            .compactMap { $0 }
            .flatMap { value in
                value
                    .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            }
        return Array(Set(values)).sorted()
    }

    private static func facets(
        for tags: [String],
        kind: LivedQuestKind
    ) -> [LivedWonderFacet] {
        let text = tags.joined(separator: " ")
        var result: [LivedWonderFacet] = []

        func include(_ facet: LivedWonderFacet, when terms: [String]) {
            guard terms.contains(where: text.contains), !result.contains(facet) else { return }
            result.append(facet)
        }

        include(.worldOtherness, when: [
            "animal", "bird", "creature", "plant", "nature", "weather", "sky",
            "world-otherness", "not-a-message", "history", "decay", "growth"
        ])
        include(.scriptFreedom, when: [
            "defiance", "borrowed-rule", "default", "rule", "routine", "goblin",
            "cost", "shadow-cost", "permission", "dehabituation"
        ])
        include(.selfAuthorship, when: [
            "make", "making", "mischief", "invent", "repair", "gift", "offering",
            "route", "detour", "self-authored", "reader-ritual"
        ])
        include(.personalLanguage, when: [
            "word", "name", "naming", "title", "definition", "language",
            "true-name", "sentence", "punctuation"
        ])
        include(.livingConnection, when: [
            "person", "people", "kindness", "coworker", "stranger", "share",
            "shared-wonder", "relationship", "witness", "offering"
        ])
        include(.deliberateReturn, when: [
            "return", "revisit", "anchor", "again", "difference", "remember"
        ])

        if result.isEmpty || kind == .playfulMission || kind == .wonderCompass || kind == .wickerDare {
            result.insert(.exactAttention, at: 0)
        }
        return Array(result.prefix(3))
    }
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

// MARK: - The Sensory Loom

/// One typed, inspectable fact the Book learned while a Page was being kept.
/// Observations remain beside the vectors so a similarity can always be
/// translated back into a human-readable receipt.
struct SensoryObservation: Codable, Equatable, Hashable {
    enum Dimension: String, Codable, Equatable {
        case modality
        case subject
        case palette
        case brightness
        case composition
        case visibleText
        case voiceDuration
        case voiceRate
        case voicePause
        case voicePitchRange
        case voiceCadence
        case voiceEnergy
        case weather
        case dayPart
        case place
        case innerWeather
    }

    var dimension: Dimension
    var value: String
    var confidence: Float
    var extractorID: String
}

/// A vector kept in its own semantic lane. The Loom deliberately does not
/// flatten image, language, voice, and context into one number-cloud: the Book
/// must be able to say which senses recognized each other.
struct SensoryVector: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case languageSemantic
        case visualSemantic
        case voiceSemantic
        case contextSemantic
        case visualFeaturePrint
        case acousticProsody
    }

    var kind: Kind
    var modelID: String
    var values: [Float]

    init(kind: Kind, modelID: String, values: [Float]) {
        self.kind = kind
        self.modelID = modelID
        self.values = Self.normalized(values)
    }

    func cosineSimilarity(to other: SensoryVector) -> Double? {
        guard kind != .visualFeaturePrint,
              modelID == other.modelID,
              values.count == other.values.count,
              !values.isEmpty else { return nil }
        let dot = zip(values, other.values).reduce(Float.zero) { $0 + $1.0 * $1.1 }
        guard dot.isFinite else { return nil }
        return Double(max(-1, min(1, dot)))
    }

    private static func normalized(_ input: [Float]) -> [Float] {
        let magnitudeSquared = input.reduce(Float.zero) { $0 + $1 * $1 }
        guard magnitudeSquared.isFinite, magnitudeSquared > 0 else { return [] }
        let magnitude = sqrt(magnitudeSquared)
        return input.map { $0 / magnitude }
    }
}

/// The durable multi-vector folio attached to a kept Page. Extractor/model IDs
/// make re-embedding explicit when the Loom improves; older saves simply have
/// no folio and continue to decode normally.
struct SensoryFolio: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var observations: [SensoryObservation]
    var vectors: [SensoryVector]

    init(
        schemaVersion: Int = currentSchemaVersion,
        observations: [SensoryObservation] = [],
        vectors: [SensoryVector] = []
    ) {
        self.schemaVersion = schemaVersion
        self.observations = observations
        self.vectors = vectors
    }

    func vector(_ kind: SensoryVector.Kind) -> SensoryVector? {
        vectors.first { $0.kind == kind }
    }

    func values(for dimension: SensoryObservation.Dimension) -> [String] {
        observations
            .filter { $0.dimension == dimension }
            .map(\.value)
    }

    var modalities: Set<String> {
        Set(values(for: .modality))
    }
}

/// A compact, inspectable reading of the amplitude envelope captured while a
/// kept voice note is recorded. It is deliberately not speech recognition and
/// never attempts to infer emotion: it records only audible activity, pauses,
/// phrase shape, and dynamic range. The human-readable labels travel beside
/// the scalar receipt in the Page's media metadata.
struct VoiceCadenceReceipt: Codable, Equatable {
    static let modelID = "sensory-loom-prosody-v1"

    var durationSeconds: Double
    var sampleCount: Int
    var activeRatio: Double
    var pauseCount: Int
    var meanPauseSeconds: Double
    var meanPhraseSeconds: Double
    var meanPowerDB: Double
    var dynamicRangeDB: Double
    var cadenceLabel: String
    var pauseLabel: String
    var energyLabel: String

    static func analyze(
        decibels: [Float],
        sampleInterval: TimeInterval,
        duration: TimeInterval
    ) -> VoiceCadenceReceipt? {
        let samples = decibels.filter(\.isFinite).map { min(0, max(-80, Double($0))) }
        guard samples.count >= 4, sampleInterval > 0, duration > 0 else { return nil }

        let sorted = samples.sorted()
        let noiseFloor = sorted[min(sorted.count - 1, sorted.count / 5)]
        // An adaptive floor tolerates a fan or a café, while the caps keep a
        // very quiet room from treating recorder hiss as a spoken phrase.
        let activeThreshold = min(-30, max(-48, noiseFloor + 8))
        let active = samples.map { $0 >= activeThreshold }
        let activeSamples = zip(samples, active).compactMap { value, isActive in isActive ? value : nil }
        guard !activeSamples.isEmpty else { return nil }

        let runs = booleanRuns(active)
        let phraseDurations = runs
            .filter(\.value)
            .map { Double($0.count) * sampleInterval }
        let pauseDurations = runs.enumerated().compactMap { index, run -> Double? in
            guard !run.value, index > 0, index < runs.count - 1 else { return nil }
            let seconds = Double(run.count) * sampleInterval
            return seconds >= 0.35 ? seconds : nil
        }

        let activeRatio = Double(active.filter { $0 }.count) / Double(active.count)
        let meanPause = mean(pauseDurations)
        let meanPhrase = mean(phraseDurations)
        let meanPower = mean(activeSamples)
        let lower = percentile(activeSamples, fraction: 0.15)
        let upper = percentile(activeSamples, fraction: 0.85)
        let dynamicRange = max(0, upper - lower)

        let cadence: String
        if activeRatio < 0.28 {
            cadence = "sparse fragments"
        } else if phraseDurations.count >= 3, meanPhrase < 1.4 {
            cadence = "short bursts"
        } else if meanPause >= 1.2 {
            cadence = "long-paused phrases"
        } else if meanPhrase >= 3.0, activeRatio >= 0.62 {
            cadence = "continuous flow"
        } else {
            cadence = "measured phrases"
        }

        let pause: String
        if pauseDurations.isEmpty {
            pause = "nearly continuous"
        } else if meanPause >= 1.2 {
            pause = "long pauses"
        } else if meanPause >= 0.6 {
            pause = "clear pauses"
        } else {
            pause = "brief pauses"
        }

        let energy: String
        if meanPower < -30 {
            energy = "hushed"
        } else if dynamicRange >= 16 {
            energy = "high contrast"
        } else if dynamicRange >= 8 {
            energy = "varied"
        } else {
            energy = "even"
        }

        return VoiceCadenceReceipt(
            durationSeconds: duration,
            sampleCount: samples.count,
            activeRatio: activeRatio,
            pauseCount: pauseDurations.count,
            meanPauseSeconds: meanPause,
            meanPhraseSeconds: meanPhrase,
            meanPowerDB: meanPower,
            dynamicRangeDB: dynamicRange,
            cadenceLabel: cadence,
            pauseLabel: pause,
            energyLabel: energy
        )
    }

    var metadata: [String: String] {
        [
            "voiceAnalysisModel": Self.modelID,
            "durationSeconds": String(format: "%.3f", durationSeconds),
            "voiceCadence": cadenceLabel,
            "voicePause": pauseLabel,
            "voiceEnergy": energyLabel,
            "voiceActiveRatio": String(format: "%.3f", activeRatio),
            "voicePauseCount": "\(pauseCount)",
            "voiceMeanPauseSeconds": String(format: "%.3f", meanPauseSeconds),
            "voiceMeanPhraseSeconds": String(format: "%.3f", meanPhraseSeconds),
            "voiceMeanPowerDB": String(format: "%.3f", meanPowerDB),
            "voiceDynamicRangeDB": String(format: "%.3f", dynamicRangeDB)
        ]
    }

    var vectorValues: [Float] {
        let pausesPerMinute = durationSeconds > 0 ? Double(pauseCount) * 60 / durationSeconds : 0
        return [
            Float(min(1, max(0, activeRatio))),
            Float(min(1, pausesPerMinute / 12)),
            Float(min(1, meanPauseSeconds / 3)),
            Float(min(1, meanPhraseSeconds / 6)),
            Float(min(1, dynamicRangeDB / 30)),
            Float(min(1, max(0, (meanPowerDB + 60) / 60)))
        ]
    }

    private struct BooleanRun {
        var value: Bool
        var count: Int
    }

    private static func booleanRuns(_ values: [Bool]) -> [BooleanRun] {
        var result: [BooleanRun] = []
        for value in values {
            if result.last?.value == value {
                result[result.count - 1].count += 1
            } else {
                result.append(BooleanRun(value: value, count: 1))
            }
        }
        return result
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * min(1, max(0, fraction))).rounded())
        return sorted[index]
    }
}

/// A public source that entered a kept Page through an explicit Book window.
/// Keeping this as typed provenance prevents later bindings from presenting a
/// generated summary as if it were the source itself.
struct BookPageExternalAttachment: Codable, Equatable, Identifiable {
    var id: String
    var kind: String
    var filePath: String
    var typeIdentifier: String
    var originalFilename: String?
}

struct BookPageExternalReference: Codable, Equatable {
    var title: String
    var sourceName: String
    var url: String
    var fetchedAt: Date?
    var provenance: String
    /// Present for receipts written by the Share Extension. Optional fields
    /// keep older public-reference Pages migration-safe.
    var captureID: String?
    var wasPromptedByBook: Bool?
    var learningAllowed: Bool?
    var weavingAllowed: Bool?
    /// Durable app-group paths for non-image documents as well as the original
    /// image files. Optional keeps pre-extension archives migration-safe.
    var attachments: [BookPageExternalAttachment]?

    var allowsLearning: Bool { learningAllowed != false }
    var allowsWeaving: Bool { weavingAllowed != false }

    static func from(surface: SurfacePage) -> BookPageExternalReference? {
        let metadata = surface.payload.metadata
        guard let rawURL = metadata["url"],
              let url = URL(string: rawURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        let fetchedAt = metadata["fetchedAt"].flatMap { ISO8601DateFormatter().date(from: $0) }
        return BookPageExternalReference(
            title: metadata["sourceTitle"]?.nonEmpty ?? surface.payload.headline,
            sourceName: metadata["sourceName"]?.nonEmpty ?? url.host ?? "the public web",
            url: rawURL,
            fetchedAt: fetchedAt,
            provenance: metadata["provenance"]?.nonEmpty ?? "public-reference",
            captureID: nil,
            wasPromptedByBook: nil,
            learningAllowed: nil,
            weavingAllowed: nil,
            attachments: nil
        )
    }
}

/// The receipt joining a kept Page to one real person's thread. It records the
/// Book's offer and the reader's own aftermath separately; it never records an
/// invented response or an inferred feeling for the other person.
struct RelationshipPageReceipt: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case foundGift
        case favor
        case witness
    }

    var personID: String
    var personName: String
    var kind: Kind
    var bookOffer: String
    var readerAftermath: String?
    var sharedInterest: String?
    var relationshipMode: String?
    var evidenceAuthority: String

    static func from(surface: SurfacePage, readerInput: String) -> RelationshipPageReceipt? {
        let metadata = surface.payload.metadata
        guard let personID = metadata["personID"]?.nonEmpty,
              let personName = metadata["personName"]?.nonEmpty else {
            return nil
        }
        let kind: Kind
        if metadata["relationshipFoundGift"] == "true" {
            kind = .foundGift
        } else if metadata["playfulMissionID"] != nil || metadata["personCharge"] == "true" {
            kind = .favor
        } else {
            kind = .witness
        }
        let trimmed = readerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let marker = "\n\nMargin note: "
        let aftermath: String?
        if let range = trimmed.range(of: marker, options: .backwards) {
            aftermath = String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
        } else if kind == .favor, !trimmed.isEmpty, trimmed != surface.payload.body {
            aftermath = trimmed
        } else {
            aftermath = nil
        }
        return RelationshipPageReceipt(
            personID: personID,
            personName: personName,
            kind: kind,
            bookOffer: surface.prompt,
            readerAftermath: aftermath,
            sharedInterest: metadata["sharedInterest"]?.nonEmpty,
            relationshipMode: metadata["relationshipMode"]?.nonEmpty,
            evidenceAuthority: aftermath == nil ? "book-offer-only" : "reader-authored-aftermath"
        )
    }
}

struct BookPage: Codable, Identifiable, Equatable {
    var id: String
    var type: BookPageType
    var createdAt: Date
    var promptText: String
    /// Legacy archive body slot. Despite its name, generated Pages also store
    /// the Book's prose here. Never infer authorship from this field; use
    /// `readerContributions`, `readerAuthoredTextForAnalysis`, or
    /// `bookAuthoredText`.
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
    /// The richer, versioned successor to `attentionFingerprint`. The compact
    /// fingerprint remains for migration and cheap lexical fallbacks; this
    /// folio preserves separate semantic lanes for the Sensory Loom.
    var sensoryFolio: SensoryFolio?
    /// Legacy save-file field. New pages leave this nil.
    var hiddenMagicFinding: HiddenMagicFinding?
    /// Present when this archive page is a fully-bound weekly issue. Optional
    /// keeps older archives source-compatible and avoids flattening a whole
    /// magazine into tags that cannot reconstruct its reader.
    var weeklyIssueArtifact: KeptWeeklyIssueArtifact?
    /// Present when this archive page is a fully-bound monthly edition. Optional
    /// for the same reasons as `weeklyIssueArtifact`: older archives decode
    /// without it, and a whole edition can't be flattened into tags.
    var monthlyEditionArtifact: KeptMonthlyEditionArtifact?
    /// The exact locally-drawn cards and the reader's own observations.
    var tarotReadingArtifact: TarotReadingArtifact?
    /// Typed public provenance retained beyond transient Surface metadata.
    var externalReference: BookPageExternalReference?
    /// Typed relational receipt used by The Company You Kept.
    var relationshipReceipt: RelationshipPageReceipt?
    /// Typed proof that a Page commissioned something in ordinary life and the
    /// reader brought evidence back.
    var livedQuestReceipt: LivedQuestReceipt?

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
        sensoryFolio: SensoryFolio? = nil,
        hiddenMagicFinding: HiddenMagicFinding? = nil,
        weeklyIssueArtifact: KeptWeeklyIssueArtifact? = nil,
        monthlyEditionArtifact: KeptMonthlyEditionArtifact? = nil,
        tarotReadingArtifact: TarotReadingArtifact? = nil,
        externalReference: BookPageExternalReference? = nil,
        relationshipReceipt: RelationshipPageReceipt? = nil,
        livedQuestReceipt: LivedQuestReceipt? = nil
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
        self.sensoryFolio = sensoryFolio
        self.hiddenMagicFinding = hiddenMagicFinding
        self.weeklyIssueArtifact = weeklyIssueArtifact
        self.monthlyEditionArtifact = monthlyEditionArtifact
        self.tarotReadingArtifact = tarotReadingArtifact
        self.externalReference = externalReference
        self.relationshipReceipt = relationshipReceipt
        self.livedQuestReceipt = livedQuestReceipt
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
        case sensoryFolio
        case hiddenMagicFinding
        case weeklyIssueArtifact
        case monthlyEditionArtifact
        case tarotReadingArtifact
        case externalReference
        case relationshipReceipt
        case livedQuestReceipt
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
        sensoryFolio = try container.decodeIfPresent(SensoryFolio.self, forKey: .sensoryFolio)
        hiddenMagicFinding = try container.decodeIfPresent(HiddenMagicFinding.self, forKey: .hiddenMagicFinding)
        weeklyIssueArtifact = try container.decodeIfPresent(KeptWeeklyIssueArtifact.self, forKey: .weeklyIssueArtifact)
        monthlyEditionArtifact = try container.decodeIfPresent(KeptMonthlyEditionArtifact.self, forKey: .monthlyEditionArtifact)
        tarotReadingArtifact = try container.decodeIfPresent(TarotReadingArtifact.self, forKey: .tarotReadingArtifact)
        externalReference = try container.decodeIfPresent(BookPageExternalReference.self, forKey: .externalReference)
        relationshipReceipt = try container.decodeIfPresent(RelationshipPageReceipt.self, forKey: .relationshipReceipt)
        livedQuestReceipt = try container.decodeIfPresent(LivedQuestReceipt.self, forKey: .livedQuestReceipt)
    }
}

// MARK: - Who wrote what
//
// Everything below answers one question — which parts of this Page are the
// reader's — and they are not interchangeable. Reaching for the wrong one is
// how the Book ends up quoting its own prose back as evidence that it read
// somebody, which is the single most damaging thing it can get wrong: the
// reader is the one person guaranteed to notice.
//
// Pick by what you are about to do:
//
//   Showing the Page its own text        `archivePreviewText`
//     Display only. Falls back to `promptText`, so it will happily hand you the
//     Book's writing. Never use it to make a claim about the reader.
//
//   Quoting the reader back at them      `reflectiveMaterial`
//     Their words, or failing that the choices they actually made, rendered as
//     prose. Nil when the Page holds neither — which is the correct answer for
//     a Page the Book wrote by itself.
//
//   Measuring their language             `readerAuthoredTextForAnalysis`
//     Their sentences only, joined. Excludes choices, because "You chose the
//     blue door" is the Book's phrasing of a decision, not the reader's diction.
//     Use this for word counts, echoes, manner, and rut detection.
//
//   Asking whether a Page may be used    `canSupplyReflectiveMaterial`
//     Deliberately wider than `reflectiveMaterial`: a photograph the reader
//     took is unmistakably theirs and has nothing to put in quotation marks.
//
//   The other side of the line           `bookAuthoredText`
//
// The relationships between them are invariants, not coincidences, and
// `ReflectiveMaterialProvenanceTests` pins them so a later change cannot
// quietly break one:
//
//   readerAuthoredTextForAnalysis != nil  ⟹  reflectiveMaterial == it
//   reflectiveMaterial != nil             ⟹  canSupplyReflectiveMaterial
//   canSupplyReflectiveMaterial           ⟺  hasReaderContribution
//
// All of them derive from `readerContributions`, which is the ground truth and
// the only place that decides what an atom is.

extension BookPage {
    /// One atomic thing the reader actually contributed to a kept Page.
    ///
    /// A kept Page is not an authorship unit. Generated Story Pages, letters,
    /// readings, and other prepared Pages commonly store the Book's prose in
    /// `userInput`, sometimes with a reply appended to the same string. These
    /// atoms are the only parts later systems may call the reader's own.
    struct ReaderContribution: Equatable {
        enum Kind: String, Equatable {
            case sentence
            case fictionChoice
            case photograph
            case audioRecording
        }

        var kind: Kind
        var text: String?
        var mediaAssetID: String?
    }

    private static let embeddedReaderSentencePrefixes = [
        "Margin note:", "Reader:", "You:", "Your note:",
        "Your field report:", "Souvenir:"
    ]

    private var hasEmbeddedReaderContributionLabels: Bool {
        userInput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { line in
                Self.embeddedReaderSentencePrefixes.contains(where: { line.hasPrefix($0) })
                    || line.hasPrefix("Listening note:")
                    || line.hasPrefix("Filed sentence (")
                    || line.hasPrefix("Chosen path:")
                    || line.hasPrefix("You sided with ")
            }
    }

    /// Prose authored by the Book or its Cast. A reader keeping it does not
    /// transfer authorship to them.
    var bookAuthoredText: String? {
        let dynamicallyBookWritten = tags.contains("earned-label")
            || tags.contains("sentence-mastery")
            // Symmetric with `readerContributions`: a page the reader replied to
            // was written by the Book, so its prose belongs on this side of the
            // boundary rather than falling through as nobody's.
            || !playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard origin == .generated
                || origin == .simulated
                || dynamicallyBookWritten
                || (origin == .userAuthored && hasEmbeddedReaderContributionLabels)
        else { return nil }
        let readerLinePrefixes = [
            "Margin note:", "Reader:", "You:", "Your note:",
            "Your field report:", "Souvenir:", "Listening note:",
            "Chosen path:", "You sided with "
        ]
        let lines = userInput
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var skipReaderBlock = false
        var readerBlockHasContent = false
        let bookLines = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if skipReaderBlock {
                if trimmed.isEmpty {
                    if readerBlockHasContent {
                        skipReaderBlock = false
                        readerBlockHasContent = false
                    }
                    return line
                }
                readerBlockHasContent = true
                return nil
            }
            if trimmed.hasPrefix("Filed sentence (") {
                skipReaderBlock = true
                readerBlockHasContent = false
                return nil
            }
            if readerLinePrefixes.contains(where: { trimmed.hasPrefix($0) }) {
                if Self.embeddedReaderSentencePrefixes.contains(where: { trimmed.hasPrefix($0) })
                    || trimmed.hasPrefix("Listening note:") {
                    skipReaderBlock = true
                    readerBlockHasContent = true
                }
                return nil
            }
            return line
        }
        return bookLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    /// Reader contributions recovered from both current storage and older
    /// compound `userInput` records. The latter used stable visible labels such
    /// as `Margin note:` and `Reader:`, so they can be separated without
    /// guessing from the prose itself.
    var readerContributions: [ReaderContribution] {
        var contributions: [ReaderContribution] = []
        var seen = Set<String>()

        func append(_ kind: ReaderContribution.Kind, text raw: String? = nil, mediaAssetID: String? = nil) {
            let text = raw?
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
            guard text != nil || mediaAssetID != nil else { return }
            let key = "\(kind.rawValue)|\(text?.lowercased() ?? "")|\(mediaAssetID ?? "")"
            guard seen.insert(key).inserted else { return }
            contributions.append(ReaderContribution(kind: kind, text: text, mediaAssetID: mediaAssetID))
        }

        let reply = playerReply.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reply.isEmpty {
            append(.sentence, text: reply)
        }

        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEmbeddedLabels = hasEmbeddedReaderContributionLabels
        let dynamicallyBookWritten = tags.contains("earned-label")
            || tags.contains("sentence-mastery")
            // A reply is what a reader gives to something already written. Its
            // presence is the tell that `userInput` is the Book's prose and not
            // theirs, whatever `origin` happens to say — letters and readings
            // are frequently stored with the default origin. Without this, a
            // generated letter's own words come back as the reader's language,
            // and the Book ends up quoting its fiction to them as if they had
            // written it.
            || !reply.isEmpty
        if origin == .userAuthored, !hasEmbeddedLabels, !dynamicallyBookWritten, !input.isEmpty {
            append(.sentence, text: input)
        } else if hasEmbeddedLabels || origin == .generated || origin == .simulated {
            let lines = userInput
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            func readerBlock(startingAt index: Int, initial: String? = nil) -> String? {
                var parts: [String] = []
                if let initial = initial?.nonEmpty {
                    parts.append(initial)
                }
                var cursor = index + 1
                if parts.isEmpty {
                    while cursor < lines.count, lines[cursor].isEmpty { cursor += 1 }
                }
                while cursor < lines.count, !lines[cursor].isEmpty {
                    parts.append(lines[cursor])
                    cursor += 1
                }
                return parts.joined(separator: " ").nonEmpty
            }

            for (index, line) in lines.enumerated() where !line.isEmpty {
                if let prefix = Self.embeddedReaderSentencePrefixes.first(where: { line.hasPrefix($0) }) {
                    append(.sentence, text: readerBlock(
                        startingAt: index,
                        initial: String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    continue
                }
                if line.hasPrefix("Listening note:") {
                    let value = String(line.dropFirst("Listening note:".count))
                    if !value.lowercased().hasPrefix("no margin note") {
                        append(.sentence, text: readerBlock(startingAt: index, initial: value))
                    }
                    continue
                }
                if line.hasPrefix("Filed sentence (") {
                    append(.sentence, text: readerBlock(startingAt: index))
                    continue
                }
                if line.hasPrefix("Chosen path:") {
                    let value = String(line.dropFirst("Chosen path:".count))
                    if value.lowercased() != "unresolved" {
                        append(.fictionChoice, text: value)
                    }
                    continue
                }
                if line.hasPrefix("You sided with ") {
                    append(.fictionChoice, text: String(line.dropFirst("You sided with ".count)).trimmingCharacters(in: CharacterSet(charactersIn: ".")))
                }
            }
        }

        if !contributions.contains(where: { $0.kind == .fictionChoice }) {
            let choiceTitles = [
                "sliceoflife": "Slice of Life",
                "progressarc": "Progress Arc",
                "surprise": "Something Surprising"
            ]
            let choiceIDs = tags.compactMap { tag -> String? in
                let lower = tag.lowercased()
                if lower.hasPrefix("story-path-chosen:") {
                    return String(lower.dropFirst("story-path-chosen:".count))
                }
                if lower.hasPrefix("choice:") {
                    return String(lower.dropFirst("choice:".count))
                }
                return nil
            }
            for choiceID in choiceIDs {
                let normalized = choiceID.filter { $0.isLetter || $0.isNumber }
                append(.fictionChoice, text: choiceTitles[normalized] ?? choiceID.replacingOccurrences(of: "-", with: " "))
            }
        }

        for asset in mediaAssets {
            switch asset.kind {
            case .audioFile:
                append(.audioRecording, mediaAssetID: asset.id)
            case .photoLibraryAsset:
                append(.photograph, mediaAssetID: asset.id)
            case .renderedImageFile:
                let isReaderProvided = origin == .imported
                    || tags.contains("plain-photo")
                    || tags.contains("unedited-photo")
                    || asset.metadata["proofImagePath"] != nil
                    || asset.metadata["externalCaptureID"] != nil
                    || asset.metadata["assetLocalIdentifier"] != nil
                    || asset.metadata["proofPhoto"] == "true"
                    || asset.metadata["uneditedPhoto"] == "true"
                if isReaderProvided {
                    append(.photograph, mediaAssetID: asset.id)
                }
            case .bundledImage:
                break
            }
        }
        return contributions
    }

    var readerAuthoredTexts: [String] {
        readerContributions.compactMap { contribution in
            contribution.kind == .sentence ? contribution.text : nil
        }
    }

    var readerFictionChoices: [String] {
        readerContributions.compactMap { contribution in
            contribution.kind == .fictionChoice ? contribution.text : nil
        }
    }

    var hasReaderPhotograph: Bool {
        readerContributions.contains { $0.kind == .photograph }
    }

    var hasReaderAudioRecording: Bool {
        readerContributions.contains { $0.kind == .audioRecording }
    }

    var hasReaderContribution: Bool {
        !readerContributions.isEmpty
    }

    /// Legacy archives may contain a receipt minted merely because a prepared
    /// Book Page had body text. Treat it as lived proof only when an atomic
    /// reader contribution actually accompanies it.
    var attributableLivedQuestReceipt: LivedQuestReceipt? {
        livedQuestReceipt.flatMap { receipt in
            hasReaderContribution && receipt.hasAnyProof ? receipt : nil
        }
    }

    /// A compact prose-only view for systems that make claims about the
    /// reader's language, rather than about the Page as a whole.
    var readerAuthoredTextForAnalysis: String? {
        readerAuthoredTexts.joined(separator: "\n").nonEmpty
    }

    /// What a reflective Page may quote back at the reader: their own writing,
    /// or failing that the choices they actually made. Nil when the Page holds
    /// neither, which is the correct answer for a Page the Book wrote by itself.
    ///
    /// `archivePreviewText` is not a substitute. It exists to show a Page its
    /// own text and falls back to `promptText`, so a Notice built on it would
    /// quote the Book's own prose back as though the reader had written it —
    /// which is how the Welcome's "You picked up this Page on…" kept turning up
    /// as evidence in Notices and Remembers.
    ///
    /// The distinction is not cosmetic. A reflective Page's whole claim is that
    /// it read the reader; illustrating that claim with generated prose makes
    /// the claim false, and the reader is the one person guaranteed to notice.
    var reflectiveMaterial: String? {
        if let written = readerAuthoredTextForAnalysis {
            return written
        }
        let choices = readerFictionChoices.filter { !$0.isEmpty }
        guard !choices.isEmpty else { return nil }
        return choices.count == 1
            ? "You chose \(choices[0])."
            : "You chose \(choices.joined(separator: ", then "))."
    }

    /// Whether a reflective Page may draw on this one at all.
    ///
    /// Deliberately wider than `reflectiveMaterial`, because being *material*
    /// and being *quotable* are different questions and collapsing them costs
    /// real Pages: a photograph the reader took is unmistakably theirs and has
    /// nothing to put in quotation marks, so a single gate silently made those
    /// Pages unrememberable.
    ///
    /// What it still refuses is a Page the reader put nothing into. Keeping a
    /// Page is a disposition the archive records elsewhere; it is not, on its
    /// own, something the reader said, and treating it as such is what let the
    /// Book quote its own Welcome back as evidence.
    ///
    /// Currently the same test as `hasReaderContribution`, and deliberately
    /// kept as its own name: the two ask different questions of the same fact,
    /// and the call sites read as what they mean. If the answers ever need to
    /// diverge, this is the one to change — `hasReaderContribution` is a
    /// statement about the Page, this is a policy about reflective surfaces.
    var canSupplyReflectiveMaterial: Bool {
        hasReaderContribution
    }

    var resolvedAttentionFingerprint: AttentionFingerprint {
        attentionFingerprint ?? AttentionFingerprint.make(from: self)
    }

    var resolvedSensoryFolio: SensoryFolio {
        sensoryFolio ?? SensoryFolioProjector.structuredFolio(from: self)
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
