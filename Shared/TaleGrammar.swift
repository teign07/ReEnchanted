import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - The Tale Grammar
//
// The Academy already simulates a world in which fairy tales can happen. It has
// the laws, the bargains, the prices, the sovereign cast, the places that
// remember, and a curse operating in both worlds. What it could not do was
// *recognise* that one had happened.
//
// This is not a plot generator. Nothing here decides what the reader will do,
// and nothing here invents an event. It is a witness: it watches receipts the
// app has already written: a bargain accepted, a Working authorised, a place
// that refused, a role outgrown, a page that came back, and works out whether
// those receipts have quietly assembled themselves into a shape older than the
// app is.
//
// When they have, it says so, binds the tale whole, and lets the reader find
// out afterwards that they were inside one. Then it leaves a scar: some small
// law that is now true and was not true before, and which does not reset.
//
// The whole grammar rests on one rule. A beat may only be witnessed by a
// receipt that already exists. If the Book cannot point at the thing that
// happened, the beat did not happen.

/// The nine beats of the grammar. Almost every complete fairy tale contains
/// some version of these, in roughly this order, and the order is what makes a
/// sequence of events legible as a tale rather than as a list.
enum TaleBeat: String, Codable, Equatable, CaseIterable {
    /// A lack, a curse, a need, or a prohibition. The Rut is the standing one.
    case lack
    /// A crossing into uncertainty: a door opened, a key handed over, a road taken.
    case crossing
    /// A helper, tempter, rival, or donor arrives: with or without an invitation.
    case donor
    /// A test whose real meaning is not clear at the time it is set.
    case test
    /// A gift, a rule, a price, or an obligation. The old law.
    case price
    /// A transgression, or a choice that cost something.
    case transgression
    /// A consequence that cannot simply be dismissed.
    case consequence
    /// A transformation in identity, relationship, or world.
    case transformation
    /// A return, in which the ordinary world is not quite the same.
    case ret

    /// Where this beat sits in the telling. Used for ordering, never for
    /// requiring: real lives deliver these out of sequence all the time.
    var position: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var label: String {
        switch self {
        case .lack: return "the lack"
        case .crossing: return "the crossing"
        case .donor: return "the one who turned up"
        case .test: return "the test"
        case .price: return "the price"
        case .transgression: return "the cost"
        case .consequence: return "what followed"
        case .transformation: return "the change"
        case .ret: return "the return"
        }
    }
}

/// The three parts every fairy tale has. The nine beats are how the grammar
/// *sees*; the acts are how a tale is *told*. A tale needs a beginning and a
/// climax that comes after it, or it is a list of things that happened.
enum TaleAct: String, Codable, Equatable, CaseIterable {
    /// Something was missing, or a way was taken.
    case beginning
    /// Somebody turned up, a test was set, a price was named.
    case middle
    /// The part that can't be taken back: the cost, or what followed.
    case climax
    /// How it came out: a change, or a way home.
    case end
}

extension TaleBeat {
    var act: TaleAct {
        switch self {
        case .lack, .crossing: return .beginning
        case .donor, .test, .price: return .middle
        case .transgression, .consequence: return .climax
        case .transformation, .ret: return .end
        }
    }
}

extension TaleBeat {
    /// The braid thread that dramatises this beat on a nightly page.
    ///
    /// The braid names its moves in tags (`braid-move:tale:<key>`), so a kept
    /// page carries a record of which beat, if any, tonight leaned on. Editions
    /// read that rather than the prose: a month should be able to say what
    /// shape it had without re-parsing thirty pages of sentences.
    var braidThreadKey: String {
        switch self {
        case .lack: return "lack"
        case .crossing: return "crossing"
        case .donor: return "donor"
        case .test: return "test"
        case .price: return "price"
        case .transgression: return "transgression"
        case .consequence: return "consequence"
        case .transformation: return "transformation"
        case .ret: return "return"
        }
    }

    /// The beat a braid move key belongs to, if it belongs to one at all. Most
    /// keys are house threads - the moth, the bell, the shelves - and those are
    /// weather rather than story.
    static func forBraidThreadKey(_ key: String) -> TaleBeat? {
        var bare = key.hasPrefix("tale:") ? String(key.dropFirst("tale:".count)) : key
        while let last = bare.last, last == "+" || last == "!" { bare.removeLast() }
        // A tale that has taken the subject in is a change in the world, and
        // that is the beat it is evidence of.
        if bare == "taken-in" { return .transformation }
        return allCases.first { $0.braidThreadKey == bare }
    }
}

/// One beat, witnessed, with the receipt that proves it. `evidence` is the
/// reader's own words or the world's own record, never a paraphrase invented
/// for the tale.
struct TaleWitness: Codable, Equatable, Identifiable {
    var id: String
    var beat: TaleBeat
    /// The id of the thing that proves this: a page, a narrative event, a
    /// bargain, a Working, a place. The tale can always be audited back to it.
    var receiptID: String
    /// What kind of receipt it was, so the bound tale can say where it looked.
    var receiptKind: String
    /// The reader's own line, or the world's own record of what happened.
    var evidence: String
    var witnessedAt: Date
    /// Tags carried from the receipt, used for shape recognition.
    var tags: [String]
    /// What this receipt is *about*: `anchor:<id>` for a place the reader
    /// anchored, `word:<noun>` for a thing the reader wrote about. A tale is
    /// one of these followed through time. Optional so older vaults decode.
    var subjects: [String]? = nil

    var isReaderAuthored: Bool {
        receiptKind == "reader-page" || receiptKind == "keep"
    }

    var isReaderFictionChoice: Bool {
        receiptKind == "fiction-choice"
    }
}

/// The ten patterns. These are recognisers, not templates: each one describes a
/// shape that a set of real receipts either has or does not have.
enum TaleShape: String, Codable, Equatable, CaseIterable {
    case forbiddenDoor
    case unpaidGift
    case threeEncounters
    case falseName
    case helpfulStranger
    case objectRefused
    case promiseMadeTooEasily
    case roadReturnsDifferently
    case houseUnderObligation
    case lostThingNotWantingFound

    /// The beats that must be witnessed before the Book will say this shape is
    /// running at all. Deliberately small: a tale is recognised early and
    /// confirmed late, the way you only know what a story was about at the end.
    var openingBeats: Set<TaleBeat> {
        switch self {
        case .forbiddenDoor: return [.lack, .crossing]
        case .unpaidGift: return [.donor, .price]
        case .threeEncounters: return [.donor, .test]
        case .falseName: return [.lack, .transformation]
        case .helpfulStranger: return [.donor]
        case .objectRefused: return [.test, .consequence]
        case .promiseMadeTooEasily: return [.price]
        case .roadReturnsDifferently: return [.crossing, .ret]
        case .houseUnderObligation: return [.crossing, .price]
        case .lostThingNotWantingFound: return [.lack, .ret]
        }
    }

    /// What the tale needs before it can be called finished. Every shape needs
    /// a consequence (something that could not simply be dismissed) because
    /// that is the difference between a tale and an anecdote.
    var closingBeats: Set<TaleBeat> {
        switch self {
        case .forbiddenDoor: return [.transgression, .consequence]
        case .unpaidGift: return [.transgression, .consequence]
        case .threeEncounters: return [.consequence, .transformation]
        case .falseName: return [.consequence, .transformation]
        case .helpfulStranger: return [.price, .consequence]
        case .objectRefused: return [.consequence, .ret]
        case .promiseMadeTooEasily: return [.transgression, .consequence]
        case .roadReturnsDifferently: return [.consequence, .transformation]
        case .houseUnderObligation: return [.consequence, .ret]
        case .lostThingNotWantingFound: return [.consequence, .ret]
        }
    }

    /// The tag that distinguishes this shape from its neighbours. A receipt
    /// carrying it is strong evidence for this shape specifically.
    var signatureTags: Set<String> {
        switch self {
        case .forbiddenDoor: return ["boundary", "refusal", "shadow", "forbidden", "closed-door"]
        case .unpaidGift: return ["fae", "bargain", "gift", "owed", "lapsed"]
        case .threeEncounters: return ["triad", "recurrence", "third-time"]
        case .falseName: return ["role-refused", "renaming", "naming", "role"]
        case .helpfulStranger: return ["stranger", "letter", "unbidden", "cast-arrival"]
        case .objectRefused: return ["refusal", "instrument", "quill", "place-refusal", "object"]
        case .promiseMadeTooEasily: return ["countersign", "pact", "promise", "affirmation"]
        case .roadReturnsDifferently: return ["return", "revisit", "anchor", "place"]
        case .houseUnderObligation: return ["working", "anchor", "obligation", "house"]
        case .lostThingNotWantingFound: return ["resurfaced", "remembered", "avoided", "dismissed"]
        }
    }

    /// Plain enough for a child to say, the way the old tales are named.
    var commonName: String {
        switch self {
        case .forbiddenDoor: return "The Door You Weren't to Open"
        case .unpaidGift: return "The Gift Nobody Paid For"
        case .threeEncounters: return "Three Times"
        case .falseName: return "The Wrong Name"
        case .helpfulStranger: return "The Stranger Who Helped"
        case .objectRefused: return "The Thing That Wouldn't Work"
        case .promiseMadeTooEasily: return "The Promise Made Too Fast"
        case .roadReturnsDifferently: return "The Road That Came Back Different"
        case .houseUnderObligation: return "The House That Was Owed"
        case .lostThingNotWantingFound: return "The Lost Thing That Didn't Want Finding"
        }
    }

    /// How this tale begins, after "Once upon a time, ".
    var once: String {
        switch self {
        case .forbiddenDoor: return "there was a door you'd decided not to open."
        case .unpaidGift: return "somebody gave you something before you'd paid for it."
        case .threeEncounters: return "something turned up."
        case .falseName: return "I called you by a name."
        case .helpfulStranger: return "you were going along, needing something you didn't have a word for."
        case .objectRefused: return "there was a thing you meant to use."
        case .promiseMadeTooEasily: return "you said yes really fast."
        case .roadReturnsDifferently: return "you set off."
        case .houseUnderObligation: return "you went into a place."
        case .lostThingNotWantingFound: return "you put something down on purpose, and left it."
        }
    }

    /// The middle, after "Then ". Only said when the middle was witnessed.
    var then: String {
        switch self {
        case .forbiddenDoor: return "you kept ending up in front of it."
        case .unpaidGift: return "the gift sat there, and so did the price."
        case .threeEncounters: return "it turned up again."
        case .falseName: return "the name didn't fit. You knew before I did."
        case .helpfulStranger: return "somebody turned up who had no reason to."
        case .objectRefused: return "it wouldn't do what it was for."
        case .promiseMadeTooEasily: return "the yes sat there, waiting."
        case .roadReturnsDifferently: return "you went back the same way."
        case .houseUnderObligation: return "the place started keeping an account in your name."
        case .lostThingNotWantingFound: return "it came back anyway."
        }
    }

    /// The climax, after "And then ". Always said: a tale has one or it isn't
    /// a tale.
    var climax: String {
        switch self {
        case .forbiddenDoor: return "something happened at that door that can't be taken back."
        case .unpaidGift: return "the price came due."
        case .threeEncounters: return "it turned up a third time, and three is when it counts."
        case .falseName: return "the name broke."
        case .helpfulStranger: return "the help turned out to have a price. Help always does."
        case .objectRefused: return "it refused properly, and that changed things."
        case .promiseMadeTooEasily: return "the promise came to collect."
        case .roadReturnsDifferently: return "it wasn't the same road any more."
        case .houseUnderObligation: return "the account came due."
        case .lostThingNotWantingFound: return "it wouldn't be put down again."
        }
    }

    /// What the Book says when it finally admits what it has been watching.
    /// First person, after the fact, and never smug about having known.
    var recognitionLine: String {
        switch self {
        case .forbiddenDoor:
            return "There was a door. I watched you stand in front of it, and I didn't say a word."
        case .unpaidGift:
            return "You got given something before you'd paid. In the old tales that's never just being kind. I kept quiet."
        case .threeEncounters:
            return "Three times. I let the first one go. I wrote down the second. By the third I'd stopped pretending I wasn't counting."
        case .falseName:
            return "I called you the wrong name. You knew before I did, and you were polite about it for ages."
        case .helpfulStranger:
            return "Somebody turned up who didn't have to. I've never known that to be free. It isn't always a trick, either."
        case .objectRefused:
            return "A thing wouldn't do what it was for. I want it written down that I didn't put it up to that."
        case .promiseMadeTooEasily:
            return "You said yes really fast. I let you. Stopping you would've made me a different book."
        case .roadReturnsDifferently:
            return "You went back. It wasn't the same. I don't think the place was the thing that changed."
        case .houseUnderObligation:
            return "A place was keeping an account in your name. Places do that. I only spotted it late."
        case .lostThingNotWantingFound:
            return "Something came back that you'd put down on purpose. I didn't send it. It came anyway."
        }
    }
}

/// How a tale ended. All six are real endings. The Book does not treat a tale
/// the reader walked away from as a failure: walking away is a thing that
/// happens in folklore constantly, and it means something.
enum TaleEnding: String, Codable, Equatable, CaseIterable {
    /// The debt was settled, the door was entered, the word was freed.
    case paid
    /// The reader stopped, and the stopping was the end of it.
    case abandoned
    /// Something became something else and cannot go back.
    case transformed
    /// It was finished, but not well, and it still counts.
    case imperfect
    /// The reader went and came back with nothing, and nothing was accepted.
    case returnedEmpty
    /// The reader said no, deliberately, and the no held.
    case refused
    /// The thing was still there at the end. Most tales about a bench end
    /// this way, and it is a good ending.
    case stillHere

    var label: String {
        switch self {
        case .paid: return "Paid"
        case .abandoned: return "Left"
        case .transformed: return "Changed"
        case .imperfect: return "Finished badly"
        case .returnedEmpty: return "Came back empty"
        case .refused: return "Refused"
        case .stillHere: return "Still there"
        }
    }

    /// The Book's own last word on the tale. Never congratulatory, never
    /// disappointed: a tale is not a score. Each reads after "In the end, ".
    var closingLine: String {
        switch self {
        case .paid:
            return "it got paid. Not neatly, but paid. That's the only part the old law checks."
        case .abandoned:
            return "you put it down and walked away. That's an ending too. Lots of the old tales end that way, and the tellers leave it out."
        case .transformed:
            return "something turned into something else, and it can't turn back. I looked."
        case .imperfect:
            return "it finished badly. It still finished. I'll take that over a door left open forever."
        case .returnedEmpty:
            return "you went, and you came back with nothing. I'm writing the nothing down. Empty hands are a real ending."
        case .refused:
            return "you said no, and you meant it, and the no held."
        case .stillHere:
            return "it was still there. Lots of tales end with everybody going home. This one ended with it still in your days."
        }
    }

    var isSettled: Bool {
        switch self {
        case .paid, .transformed, .imperfect, .refused, .stillHere: return true
        case .abandoned, .returnedEmpty: return false
        }
    }
}

/// A permanent mark left by a finished tale: some small law that is now true
/// and was not true before. This is the app's literary irreversibility, never
/// harm, never a punishment, never a locked feature. A scar changes the *shape*
/// of what happens next, and it does not reset.
struct TaleScar: Codable, Equatable, Identifiable {
    var id: String
    var taleID: String
    var shape: TaleShape
    var ending: TaleEnding
    /// The law, in the Book's own words, written to be read back later.
    var law: String
    /// What the law attaches to: a place id, an entity id, a role id, a word.
    var subjectID: String
    var subjectKind: TaleScarSubject
    var formedAt: Date
    /// Some scars are for a season; some are for good. Neither can be undone
    /// by the reader, which is the point of them.
    var expiresAt: Date?

    func isActive(at moment: Date = Date()) -> Bool {
        guard let expiresAt else { return true }
        return moment < expiresAt
    }

    var isPermanent: Bool { expiresAt == nil }
}

enum TaleScarSubject: String, Codable, Equatable {
    case place
    case castMember
    case role
    case word
    case theBook
    case theReader
}

/// What a tale is about: one thing that kept turning up in the reader's own
/// pages, across real days. This is what makes three pages one story instead
/// of three pages: they are about the same bench, or the same kettle.
struct TaleThread: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        /// A place the reader anchored, called by the reader's own name for it.
        case place
        /// A thing the reader kept writing about, in their own word for it.
        case thing
    }

    /// `anchor:<id>` or `word:<noun>`.
    var id: String
    /// "Riverside Bench" (the reader's own name) or "kettle".
    var name: String
    var kind: Kind

    /// How the tale says it: "the kettle", or the place's own name.
    var spoken: String {
        kind == .thing ? "the \(name)" : name
    }

    var title: String {
        switch kind {
        case .thing: return "The Tale of the \(name.prefix(1).uppercased() + name.dropFirst())"
        case .place: return "The Tale of \(name)"
        }
    }
}

/// A tale the reader is currently inside, or has finished. Only one is ever
/// open: fairy tales are singular, and a reader inside three at once is inside
/// none of them.
struct LivingTale: Codable, Equatable, Identifiable {
    var id: String
    var shape: TaleShape
    /// Named by the Book from the reader's own material once there is enough
    /// of it. Empty until then: an unnamed tale is still a tale.
    var title: String
    var witnesses: [TaleWitness]
    var openedAt: Date
    var lastWitnessedAt: Date
    var closedAt: Date?
    var ending: TaleEnding?
    /// Set when the tale has been shown to the reader as a bound page, so it
    /// is never bound twice.
    var boundAt: Date?
    /// The one thing the tale is about. Tales without one were recognised by
    /// the old beat grammar and read as unrelated pages in a row; they are
    /// never bound.
    var thread: TaleThread? = nil

    var isOpen: Bool { closedAt == nil }

    var witnessedBeats: Set<TaleBeat> {
        Set(witnesses.map(\.beat))
    }

    /// Witnesses in the order the grammar tells them, which is not always the
    /// order they happened in.
    var told: [TaleWitness] {
        witnesses.sorted { left, right in
            if left.beat.position != right.beat.position {
                return left.beat.position < right.beat.position
            }
            return left.witnessedAt < right.witnessedAt
        }
    }

    /// The reader's own lines inside this tale. A bound tale leads with these,
    /// because the evidence that it happened to *them* is that they wrote it.
    var readerLines: [String] {
        told.filter(\.isReaderAuthored).map(\.evidence).filter { !$0.isEmpty }
    }

    func has(_ beat: TaleBeat) -> Bool {
        witnesses.contains { $0.beat == beat }
    }
}

// MARK: - Witnessing
//
// Everything below turns receipts the app already wrote into beats. Each
// witness carries the id of the thing that proves it, so a bound tale can
// always be audited back to real events. Nothing here creates an event, applies
// a consequence, or decides what the reader should do next.

/// The small set of world facts the grammar cannot read off a page or an event.
/// The app fills these in from systems it already owns: the Fae ledger, the
/// Workings, the places, the role tenure, so the grammar stays free of a dozen
/// concrete dependencies and stays testable.
struct TaleSignals: Equatable {
    struct Mark: Equatable {
        var id: String
        var kind: String
        var line: String
        var at: Date
        var tags: [String]

        init(id: String, kind: String, line: String, at: Date, tags: [String] = []) {
            self.id = id
            self.kind = kind
            self.line = line
            self.at = at
            self.tags = tags
        }
    }

    /// Bargains fronted, gifts taken, prices accepted.
    var faeMarks: [Mark] = []
    /// House keys granted and Workings that acted in the world.
    var workingMarks: [Mark] = []
    /// Places that refused, and places returned to.
    var placeMarks: [Mark] = []
    /// Roles named, refused, outgrown.
    var roleMarks: [Mark] = []
    /// Instruments and objects with an opinion.
    var objectMarks: [Mark] = []
    /// Anything else the world wrote down: pact dispatches, faults, loyalties.
    var worldMarks: [Mark] = []
    /// What to call a subject: `anchor:<id>` to the reader's name for it.
    var subjectNames: [String: String] = [:]

    var all: [Mark] {
        faeMarks + workingMarks + placeMarks + roleMarks + objectMarks + worldMarks
    }

    static let none = TaleSignals()
}

enum TaleGrammar {
    // MARK: Thresholds
    //
    // Same house style as everything else that makes a claim: real evidence,
    // across real days, or the Book says nothing.

    /// A tale needs beats from at least this many distinct days before the Book
    /// will call it a tale. One intense evening is a scene.
    static let minimumDistinctDays = 3
    /// And at least this many witnessed beats.
    static let minimumWitnesses = 4
    /// And at least this many in the reader's own hand.
    static let minimumReaderBeats = 2
    /// A thread needs this many of the reader's own pages: a beginning, a
    /// middle and an end.
    static let minimumAppearances = 3
    /// A running tale ends when its thread has gone quiet this long, or when it
    /// has this many appearances. Three is a tale. Five is plenty.
    static let quietInterval: TimeInterval = 5 * 86_400
    static let maximumAppearances = 5
    /// A tale with nothing added for this long has been walked away from.
    static let staleInterval: TimeInterval = 21 * 86_400
    /// How far back the witnessing looks. Older receipts belong to older tales.
    static let lookback: TimeInterval = 120 * 86_400
    /// A tale may not open again within this long of the last one closing, so
    /// the reader gets to be out of a story sometimes.
    static let restBetweenTales: TimeInterval = 4 * 86_400

    // MARK: The witness pass

    /// Reads every receipt in range and returns the beats they prove. Ordering
    /// is by time; deduplication is by receipt, so one page cannot witness the
    /// same beat twice.
    static func witnesses(
        events: [NarrativeEvent],
        days: [BookDay],
        signals: TaleSignals = .none,
        now: Date = Date()
    ) -> [TaleWitness] {
        let floor = now.addingTimeInterval(-lookback)
        var found: [TaleWitness] = []

        for page in days.flatMap(\.capturedPages) where page.createdAt >= floor {
            if let witness = witness(from: page) { found.append(witness) }
        }
        for event in events where event.createdAt >= floor {
            if let witness = witness(from: event) { found.append(witness) }
        }
        for mark in signals.all where mark.at >= floor {
            if let witness = witness(from: mark) { found.append(witness) }
        }

        // One receipt proves one beat. If two rules claim the same receipt the
        // earlier beat in the grammar wins, because a thing is a crossing
        // before it is a return.
        var seen: Set<String> = []
        return found
            .sorted { left, right in
                if left.receiptID != right.receiptID { return left.witnessedAt < right.witnessedAt }
                return left.beat.position < right.beat.position
            }
            .filter { seen.insert($0.receiptID).inserted }
            .sorted { $0.witnessedAt < $1.witnessedAt }
    }

    /// A kept page. The reader's own words are the strongest evidence there is,
    /// so these are the witnesses a bound tale leads with.
    static func witness(from page: BookPage) -> TaleWitness? {
        let tags = Set(page.tags.map { $0.lowercased() })
        let readerText = page.readerAuthoredTextForAnalysis
        // Any page in the reader's own words can carry a thread, whatever kind
        // of page it was. The beat only flavours the tale; the thread makes it.
        guard let beat = beat(forPageType: page.type, tags: tags)
            ?? (readerText == nil ? nil : .test) else { return nil }
        let fictionChoice = page.readerFictionChoices.first
        let text = readerText
            ?? fictionChoice
            ?? page.bookAuthoredText
            ?? page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? page.promptText
        let receiptKind: String
        if readerText != nil {
            receiptKind = "reader-page"
        } else if fictionChoice != nil {
            receiptKind = "fiction-choice"
        } else {
            receiptKind = "page"
        }
        return TaleWitness(
            id: "tale-witness-page-\(page.id)",
            beat: beat,
            receiptID: page.id,
            receiptKind: receiptKind,
            evidence: text,
            witnessedAt: page.createdAt,
            tags: Array(tags),
            subjects: TaleSubjects.subjects(of: page, readerText: readerText)
        )
    }

    private static func beat(forPageType type: BookPageType, tags: Set<String>) -> TaleBeat? {
        // Tags win over type: a page the reader tagged as hard is a lack,
        // whatever kind of page it happened to be.
        if !tags.isDisjoint(with: ["grief", "hard", "heavy", "distress", "numb", "low"]) { return .lack }
        if !tags.isDisjoint(with: ["boundary", "refusal", "forbidden", "shadow"]) { return .crossing }
        if !tags.isDisjoint(with: ["resurfaced", "remembered", "return", "revisit"]) { return .ret }
        if !tags.isDisjoint(with: ["countersign", "pact", "promise"]) { return .price }
        if !tags.isDisjoint(with: ["naming", "role", "renaming"]) { return .transformation }

        switch type {
        case .mood, .rest:
            return .lack
        case .wonderCompass, .pactErrand, .wickerDare:
            return .test
        case .faeBargain:
            return .price
        case .letter, .gossip, .bookAside:
            return .donor
        // A Story Page is a crossing: the reader is inside the fiction and a
        // path is taken. The choice is the reader's even though the prose is
        // the Book's, which is exactly the distinction `readerFictionChoices`
        // preserves — so the tale may quote the decision without ever claiming
        // the sentences around it.
        case .narrativeOS:
            return .crossing
        case .bookRemembered, .bookConnections:
            return .ret
        case .affirmations:
            return .price
        case .bookPocket, .bindery:
            return .transformation
        default:
            return nil
        }
    }

    /// A narrative event. These are the world's own record of what a page did.
    static func witness(from event: NarrativeEvent) -> TaleWitness? {
        let tags = Set(event.tags.map { $0.lowercased() })
        let beat: TaleBeat
        switch event.kind {
        case .beliefAttacked:
            beat = .transgression
        case .beliefInvested:
            beat = .price
        case .letterReceived, .entityNoticed:
            beat = .donor
        case .compassRunCompleted, .enchantmentCompleted:
            beat = .test
        case .choiceSelected:
            beat = .crossing
        case .threadAdvanced:
            beat = .consequence
        case .simulationTurn:
            // The world moving on its own is only a beat when it moved
            // *because* of something: otherwise it is weather.
            guard !event.effect.relationshipWeightDeltas.isEmpty
                || event.effect.beliefDelta != 0 else { return nil }
            beat = .consequence
        case .pageKept, .pageAnswered:
            return nil  // Already witnessed through the page itself.
        }
        return TaleWitness(
            id: "tale-witness-event-\(event.id)",
            beat: beat,
            receiptID: event.id,
            receiptKind: "event",
            evidence: event.summary,
            witnessedAt: event.createdAt,
            tags: Array(tags)
        )
    }

    /// A world fact the app handed over: a bargain, a Working, a refusal.
    static func witness(from mark: TaleSignals.Mark) -> TaleWitness? {
        let beat: TaleBeat
        switch mark.kind {
        case "fae-offered": beat = .donor
        case "fae-accepted": beat = .price
        case "fae-lapsed": beat = .transgression
        case "fae-repaired": beat = .ret
        case "working-authorized": beat = .crossing
        case "working-acted": beat = .consequence
        case "place-refused": beat = .consequence
        case "place-returned": beat = .ret
        case "role-named": beat = .transformation
        case "role-refused": beat = .transgression
        case "role-outgrown": beat = .transformation
        case "object-refused": beat = .consequence
        case "pact-lost", "fault": beat = .consequence
        case "loyalty-revised": beat = .transformation
        default: return nil
        }
        return TaleWitness(
            id: "tale-witness-mark-\(mark.id)",
            beat: beat,
            receiptID: mark.id,
            receiptKind: mark.kind,
            evidence: mark.line,
            witnessedAt: mark.at,
            tags: mark.tags
        )
    }
}

// MARK: - Threads
//
// What a page is about, in the only two ways the Book can know without
// guessing: the place the reader anchored it near, and the things they named
// in their own words. Nouns only. "I went back" and "I went out" share a verb,
// not a thing; "the kettle" and "the kettle again" share a kettle.

enum TaleSubjects {
    static func subjects(of page: BookPage, readerText: String?) -> [String] {
        var found: [String] = []
        if let anchor = page.context?.nearbyAnchorID?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            found.append("anchor:\(anchor)")
        }
        if let readerText {
            found += things(in: readerText, cacheKey: page.id).map { "word:\($0)" }
        }
        return found
    }

    /// The things in a line of the reader's: common nouns, in their base form,
    /// never a name. Real people are the reader's to speak of, and a tale is
    /// no place to make them a character.
    ///
    /// Cached by page, because tending runs after every keep and the archive
    /// does not change underneath a page that is already kept.
    static func things(in text: String, cacheKey: String? = nil) -> [String] {
        let key = cacheKey.map { "\($0)|\(text.count)|\(text.hashValue)" }
        if let key {
            lock.lock()
            let hit = cache[key]
            lock.unlock()
            if let hit { return hit }
        }
        let result = extract(from: text)
        if let key {
            lock.lock()
            if cache.count > 4_000 { cache.removeAll(keepingCapacity: true) }
            cache[key] = result
            lock.unlock()
        }
        return result
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: [String]] = [:]

    private static func extract(from text: String) -> [String] {
        var found = Set<String>()
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            guard tag == .noun else { return true }
            let token = String(text[range])
            // Names are not things.
            let (nameTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType)
            if let nameTag, [.personalName, .placeName, .organizationName].contains(nameTag) { return true }
            // A capital in the middle of a sentence is a name the tagger missed.
            if let first = token.first, first.isUppercase, !startsSentence(range.lowerBound, in: text) { return true }
            let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
            let word = (lemmaTag?.rawValue ?? token).lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            if word.count >= 3, word.allSatisfy(\.isLetter), !stopwords.contains(word) {
                found.insert(word)
            }
            return true
        }
        #endif
        return found.sorted()
    }

    private static func startsSentence(_ index: String.Index, in text: String) -> Bool {
        var cursor = index
        while cursor > text.startIndex {
            cursor = text.index(before: cursor)
            let character = text[cursor]
            if character.isWhitespace || character == "\"" || character == "\u{201C}" { continue }
            return ".!?\n".contains(character)
        }
        return true
    }

    /// Nouns that are the weather of anybody's days, not a thing in them.
    static let stopwords: Set<String> = [
        "day", "days", "today", "tonight", "tomorrow", "yesterday", "morning", "afternoon",
        "evening", "night", "week", "weekend", "month", "year", "hour", "minute", "time",
        "moment", "while", "lot", "bit", "thing", "stuff", "way", "kind", "sort", "part",
        "life", "world", "people", "person", "everyone", "someone", "anyone", "nobody",
        "somebody", "anything", "something", "nothing", "everything", "one", "number",
        "work", "home", "place", "feeling", "mood", "idea", "thought", "fact", "reason",
        "point", "end", "start", "side", "lot", "need", "want", "fine", "okay", "yes",
        "page", "book", "word", "line", "sentence", "note", "story", "tale", "question",
        "answer", "list", "plan", "problem", "job", "task", "use", "try", "sense",
        "self", "mind", "head", "body", "energy", "stress", "tired", "sleep",
        "week", "hand", "eye", "face", "voice", "name", "course", "case", "question"
    ]
}

// MARK: - Recognition
//
// Which shape, if any, these witnesses have. The Book prefers the shape whose
// signature the receipts actually carry, and refuses to name one at all when
// the evidence is thin: a wrong shape is worse than no shape, because it
// would make the Book a thing that tells you what your life meant.

extension TaleGrammar {
    struct Recognition: Equatable {
        var shape: TaleShape
        var confidence: Int
        var witnesses: [TaleWitness]
        var thread: TaleThread? = nil
    }

    /// Finds the one thing that has been turning up in the reader's own pages
    /// across real days, and follows it. No thread, no tale: three unrelated
    /// pages in a row are not a story however well they are framed.
    ///
    /// The shape is the flavour, read off what the thread's pages carry. When
    /// nothing more particular shows, a thing that came back three times is the
    /// oldest shape there is.
    static func recognize(
        witnesses: [TaleWitness],
        names: [String: String] = [:],
        barredThreadIDs: Set<String> = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recognition? {
        let own = witnesses.filter(\.isReaderAuthored)
        guard own.count >= minimumAppearances else { return nil }

        var bySubject: [String: [TaleWitness]] = [:]
        for witness in own {
            for subject in Set(witness.subjects ?? []) where !barredThreadIDs.contains(subject) {
                bySubject[subject, default: []].append(witness)
            }
        }

        var best: (thread: TaleThread, witnesses: [TaleWitness], score: Int)?
        for (key, found) in bySubject {
            let days = Set(found.map { calendar.startOfDay(for: $0.witnessedAt) })
            guard days.count >= minimumDistinctDays, found.count >= minimumAppearances else { continue }
            // A word in nearly every page is the furniture of the reader's
            // life, not a thing that happened in it.
            if key.hasPrefix("word:"), own.count >= 10,
               Double(found.count) / Double(own.count) > 0.4 { continue }
            guard let thread = thread(for: key, names: names) else { continue }
            let span = (found.map(\.witnessedAt).max() ?? now).timeIntervalSince(found.map(\.witnessedAt).min() ?? now)
            let score = days.count * 10
                + min(found.count, maximumAppearances) * 3
                + (thread.kind == .place ? 12 : 0)
                + min(30, Int(span / 86_400))
            if let current = best {
                if score > current.score || (score == current.score && key < current.thread.id) {
                    best = (thread, found, score)
                }
            } else {
                best = (thread, found, score)
            }
        }
        guard let chosen = best else { return nil }
        let sorted = chosen.witnesses.sorted { $0.witnessedAt < $1.witnessedAt }
        return Recognition(
            shape: shape(for: sorted),
            confidence: chosen.score,
            witnesses: sorted,
            thread: chosen.thread
        )
    }

    static func thread(for key: String, names: [String: String]) -> TaleThread? {
        if key.hasPrefix("anchor:") {
            guard let name = names[key]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else { return nil }
            return TaleThread(id: key, name: name, kind: .place)
        }
        if key.hasPrefix("word:") {
            let word = String(key.dropFirst("word:".count))
            guard !word.isEmpty else { return nil }
            return TaleThread(id: key, name: word, kind: .thing)
        }
        return nil
    }

    /// The shape whose signature the thread's own pages carry most, or Three
    /// Times when none does.
    static func shape(for witnesses: [TaleWitness]) -> TaleShape {
        let tags: Set<String> = Set(witnesses.flatMap(\.tags).map { $0.lowercased() })
        // Written out rather than chained: the fluent version is too much for
        // CI's type-checker budget.
        var best: TaleShape = .threeEncounters
        var bestHits = 0
        for shape in TaleShape.allCases {
            let hits: Int = shape.signatureTags.intersection(tags).count
            if hits > bestHits || (hits == bestHits && hits > 0 && shape.rawValue < best.rawValue) {
                best = shape
                bestHits = hits
            }
        }
        return best
    }

    /// A tale is called by its shape, the way the old ones are: "The Wrong
    /// Name", not the first clause of whatever the reader wrote last. The
    /// reader's own words are inside the tale, where they make sense.
    static func title(for shape: TaleShape, witnesses: [TaleWitness]) -> String {
        shape.commonName
    }
}

// MARK: - Opening, tending, and closing

extension TaleGrammar {
    /// What a tending pass decided. Returning `nil` for everything is the
    /// commonest and most correct outcome: most days are not inside a tale.
    struct Verdict: Equatable {
        var opened: LivingTale?
        var updated: LivingTale?
        var closed: LivingTale?
        var scar: TaleScar?
        /// An open tale put down without being told: it had no thread.
        var dropped: Bool = false

        static let quiet = Verdict(opened: nil, updated: nil, closed: nil, scar: nil)

        var isQuiet: Bool {
            opened == nil && updated == nil && closed == nil && scar == nil && !dropped
        }
    }

    /// One pass. Takes the currently open tale (if any), the full witness
    /// stream, and decides whether anything happened.
    static func tend(
        current: LivingTale?,
        witnesses: [TaleWitness],
        lastClosedAt: Date? = nil,
        refusedShapes: Set<TaleShape> = [],
        names: [String: String] = [:],
        barredThreadIDs: Set<String> = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Verdict {
        if let current, current.isOpen {
            // A tale from the old grammar has no thread and would bind as a row
            // of unrelated pages. Put it down quietly: no page, no scar.
            guard current.thread != nil else {
                return Verdict(opened: nil, updated: nil, closed: nil, scar: nil, dropped: true)
            }
            return tendOpen(current, witnesses: witnesses, now: now, calendar: calendar)
        }

        // The reader is allowed to be out of a story. A new tale waits.
        if let lastClosedAt, now.timeIntervalSince(lastClosedAt) < restBetweenTales {
            return .quiet
        }
        guard let recognition = recognize(
            witnesses: witnesses,
            names: names,
            barredThreadIDs: barredThreadIDs,
            now: now,
            calendar: calendar
        ) else {
            return .quiet
        }
        // A shape the reader has denied does not come back under a new id.
        //
        // Refusal used to close one `LivingTale`, and the same receipts would
        // recognise the same shape again after the rest window with a fresh
        // id - so the Book would lean on it again, and could ask about it
        // again, having been told once that it was wrong. Barring the shape is
        // what makes "no" mean no.
        guard !refusedShapes.contains(recognition.shape) else { return .quiet }
        let relevant = recognition.witnesses
        let opened = LivingTale(
            id: "tale-\(recognition.shape.rawValue)-\(Int(now.timeIntervalSince1970))",
            shape: recognition.shape,
            title: recognition.thread?.title ?? title(for: recognition.shape, witnesses: relevant),
            witnesses: relevant,
            openedAt: relevant.map(\.witnessedAt).min() ?? now,
            lastWitnessedAt: relevant.map(\.witnessedAt).max() ?? now,
            closedAt: nil,
            ending: nil,
            boundAt: nil,
            thread: recognition.thread
        )
        return Verdict(opened: opened, updated: nil, closed: nil, scar: nil)
    }

    private static func tendOpen(
        _ tale: LivingTale,
        witnesses: [TaleWitness],
        now: Date,
        calendar: Calendar
    ) -> Verdict {
        var tale = tale
        guard let thread = tale.thread else {
            return Verdict(opened: nil, updated: nil, closed: nil, scar: nil, dropped: true)
        }
        let known = Set(tale.witnesses.map(\.receiptID))
        // Only the reader's own pages about this same thing join the tale.
        let fresh = witnesses.filter {
            !known.contains($0.receiptID)
                && $0.isReaderAuthored
                && ($0.subjects ?? []).contains(thread.id)
        }

        if !fresh.isEmpty {
            tale.witnesses.append(contentsOf: fresh)
            tale.witnesses.sort { $0.witnessedAt < $1.witnessedAt }
            tale.lastWitnessedAt = fresh.map(\.witnessedAt).max() ?? tale.lastWitnessedAt
        }

        // Finished when the thread has gone quiet, or when it has plenty.
        let appearances = tale.witnesses.filter(\.isReaderAuthored).count
        if appearances >= maximumAppearances
            || now.timeIntervalSince(tale.lastWitnessedAt) >= quietInterval {
            let ending = ending(for: tale, now: now)
            tale.closedAt = now
            tale.ending = ending
            return Verdict(
                opened: nil, updated: nil, closed: tale,
                scar: scar(for: tale, ending: ending, now: now)
            )
        }

        return fresh.isEmpty ? .quiet : Verdict(opened: nil, updated: tale, closed: nil, scar: nil)
    }

    /// A beginning, and a climax that happened after it.
    static func hasAnArc(_ tale: LivingTale) -> Bool {
        guard let start = tale.witnesses.filter({ $0.beat.act == .beginning }).map(\.witnessedAt).min(),
              let peak = tale.witnesses.filter({ $0.beat.act == .climax }).map(\.witnessedAt).max()
        else { return false }
        return peak >= start
    }

    /// Reads the ending off what actually happened. Nothing here is a judgement
    /// of the reader; each branch points at a receipt.
    static func ending(for tale: LivingTale, now: Date = Date()) -> TaleEnding {
        let kinds = Set(tale.witnesses.map(\.receiptKind))
        let tags = Set(tale.witnesses.flatMap(\.tags).map { $0.lowercased() })

        if let thread = tale.thread {
            // Read off the last thing the reader wrote about it.
            let last = tale.witnesses.filter(\.isReaderAuthored)
                .max { $0.witnessedAt < $1.witnessedAt }?.evidence.lowercased() ?? ""
            var absent = ["gone", "couldn't find", "could not find", "lost it", "broke", "threw it", "thrown out", "missing"]
            if thread.kind == .thing {
                let word = thread.name.lowercased()
                absent += ["no \(word)", "not a \(word)", "\(word) wasn't", "\(word) was not", "without the \(word)", "didn't see the \(word)"]
            }
            if absent.contains(where: last.contains) {
                return .returnedEmpty
            }
            if tags.contains("refused") || tags.contains("refusal") { return .refused }
            return .stillHere
        }

        if kinds.contains("fae-repaired") || tags.contains("paid") { return .paid }
        if kinds.contains("role-outgrown") || tale.has(.transformation) && tale.has(.consequence)
            && kinds.contains("loyalty-revised") { return .transformed }
        if tags.contains("refused") || kinds.contains("role-refused") { return .refused }
        if kinds.contains("fae-lapsed") { return .imperfect }
        // The reader turned up and had nothing, and said so. The archive knows
        // the difference between silence and an honest empty hand.
        if tale.has(.ret), tale.readerLines.contains(where: { line in
            let lowered = line.lowercased()
            return lowered.contains("nothing") || lowered.contains("couldn't find")
                || lowered.contains("could not find") || lowered.contains("empty")
        }) { return .returnedEmpty }
        if tale.has(.transformation) { return .transformed }
        return .imperfect
    }
}

// MARK: - Scars
//
// The part that does not reset.
//
// A scar is a small law that is true now and was not true before. It is never a
// punishment, never a locked feature, never harm: the whole register is
// *literary* irreversibility. A repaired gift does not look the way it looked.
// A place keeps one door shut until the season turns. The Book cannot use a
// particular word about the reader the easy way any more.
//
// Scars are the reason a tale matters after it is over, and the reason the
// world accumulates a history rather than a log.

extension TaleGrammar {
    /// Mints the law a finished tale leaves behind. Every scar names a subject
    /// the app can actually look up, so the law has somewhere to bite.
    static func scar(for tale: LivingTale, ending: TaleEnding, now: Date = Date()) -> TaleScar? {
        // A tale that was walked away from early leaves nothing. Not every
        // ending is a mark; that would cheapen the ones that are.
        if ending == .abandoned, tale.witnesses.count < minimumWitnesses + 2 { return nil }

        let subject = subject(for: tale)
        let law = law(for: tale.shape, ending: ending, subjectName: subject.name)
        // A season, or forever. The shapes about identity and refusal leave
        // permanent marks; the ones about places and objects lift with the year.
        let seasonal: Set<TaleShape> = [.objectRefused, .houseUnderObligation, .roadReturnsDifferently, .helpfulStranger]
        let expires = seasonal.contains(tale.shape)
            ? Calendar.current.date(byAdding: .day, value: 120, to: now)
            : nil

        return TaleScar(
            id: "scar-\(tale.id)",
            taleID: tale.id,
            shape: tale.shape,
            ending: ending,
            law: law,
            subjectID: subject.id,
            subjectKind: subject.kind,
            formedAt: now,
            expiresAt: expires
        )
    }

    private static func subject(for tale: LivingTale) -> (id: String, kind: TaleScarSubject, name: String) {
        // Prefer the most concrete thing the tale actually touched.
        for witness in tale.told.reversed() {
            switch witness.receiptKind {
            case "place-refused", "place-returned":
                return (witness.receiptID, .place, "that place")
            case "role-named", "role-refused", "role-outgrown":
                return (witness.receiptID, .role, "the name I gave you")
            case "fae-offered", "fae-accepted", "fae-lapsed", "fae-repaired":
                return (witness.receiptID, .castMember, "the one who gave it to you")
            case "object-refused":
                return (witness.receiptID, .word, "that thing")
            default:
                continue
            }
        }
        return (tale.id, .theBook, "me")
    }

    /// The law itself, in the Book's voice, written to be read back months
    /// later without any of the surrounding context.
    static func law(for shape: TaleShape, ending: TaleEnding, subjectName: String) -> String {
        switch (shape, ending) {
        case (.forbiddenDoor, .paid), (.forbiddenDoor, .transformed):
            return "That door is open now and won't shut again. I've stopped counting it as a boundary and started counting it as a room."
        case (.forbiddenDoor, .refused):
            return "You stood at that door and didn't go through, on purpose. I won't offer it to you again in that shape: the offering was the thing you refused."
        case (.forbiddenDoor, _):
            return "There is a door in you I now know the location of. I'm not going to keep pointing at it, but I'm not going to forget where it is."

        case (.unpaidGift, .paid):
            return "The debt is settled and the gift came back looking different. I'm not going to pretend it looks the way it did: repaired is its own finish and I'd rather you saw the seam."
        case (.unpaidGift, .imperfect):
            return "That gift went cold on your watch. I've met the one who gave it: they remember the shape of what was agreed far better than the reason for it, and they always will."
        case (.unpaidGift, _):
            return "There is an old-law debt in your name that nobody is chasing. I've never seen one of those expire. They wait, and I will keep the wording of it for you."

        case (.threeEncounters, _):
            return "I saw it three times. That is a law, not a coincidence. \(subjectName.capitalized) has climbed onto the desk and demanded to be noticed out loud."

        case (.falseName, .transformed):
            return "The name I first gave you was wrong and the wrongness is part of the record. I don't get to quietly rewrite my first guess."
        case (.falseName, _):
            return "You have refused a name I gave you. It stays in the margin as a road not taken, and it may come back years from now as somebody you didn't become."

        case (.helpfulStranger, .paid):
            return "Somebody helped you for no reason and was thanked properly. I've written that down as a thing this world does now, and I will let it happen again."
        case (.helpfulStranger, _):
            return "Somebody turned up unasked and left again unpaid. I'm keeping that account open at their end rather than yours, which is my decision and not the old law's."

        case (.objectRefused, _):
            return "\(subjectName.capitalized) has refused once. Refusal is a habit in objects. I won't pretend the next request is the first one."

        case (.promiseMadeTooEasily, .paid), (.promiseMadeTooEasily, .imperfect):
            return "You made a promise fast and then had to live inside it. I will ask more slowly next time, and you should be suspicious of how fast I used to ask."
        case (.promiseMadeTooEasily, _):
            return "A promise was made too easily and never came due. I'm keeping the wording. The wording is the part that lasts."

        case (.roadReturnsDifferently, _):
            return "You went back and it had changed. That road is now a returning road in my records, and I will offer it to you as one."

        case (.houseUnderObligation, .paid):
            return "The house is square with you. It opened a door it had been keeping shut, and it did that itself: I only watched."
        case (.houseUnderObligation, _):
            return "That place is owed something and has decided to be patient about it. It has closed one door for the season. It didn't ask me first."

        case (.lostThingNotWantingFound, .returnedEmpty):
            return "You went looking and came back with nothing, and I wrote the nothing down. It counts. I'm not going to send you back for it."
        case (.lostThingNotWantingFound, _):
            return "The thing that didn't want finding has been found. I can't put it back and neither can you, so I've stopped filing it under missing."
        }
    }
}

/// The active laws, ready to be read by whatever is about to speak. This is the
/// half that makes a scar real: something has to *consult* it.
struct TaleScarBook: Equatable {
    var scars: [TaleScar]

    static let empty = TaleScarBook(scars: [])

    func active(at moment: Date = Date()) -> [TaleScar] {
        scars.filter { $0.isActive(at: moment) }
    }

    /// Laws attached to one subject: a place about to be offered, a role about
    /// to be spoken, an object about to be asked for something.
    func laws(forSubjectID id: String, at moment: Date = Date()) -> [TaleScar] {
        active(at: moment).filter { $0.subjectID == id }
    }

    func laws(ofKind kind: TaleScarSubject, at moment: Date = Date()) -> [TaleScar] {
        active(at: moment).filter { $0.subjectKind == kind }
    }

    /// Whether a place is currently keeping a door shut because of a tale. The
    /// curator asks this before offering that place as somewhere to go.
    func placeIsKeepingADoorShut(_ placeID: String, at moment: Date = Date()) -> Bool {
        laws(forSubjectID: placeID, at: moment).contains { scar in
            scar.shape == .houseUnderObligation && scar.ending != .paid
        }
    }

    /// Whether the Book has lost the easy version of a word about the reader.
    /// After a False Name, it may not simply re-assert the first naming.
    func mayReassertRoleFreely(at moment: Date = Date()) -> Bool {
        !laws(ofKind: .role, at: moment).contains { $0.shape == .falseName }
    }

    /// The lines the Book carries into its own prose, so a finished tale keeps
    /// changing how it speaks. Capped, newest first: a Book reciting nine laws
    /// is a Book that has stopped being a companion.
    func standingLaws(limit: Int = 3, at moment: Date = Date()) -> [String] {
        active(at: moment)
            .sorted { $0.formedAt > $1.formedAt }
            .prefix(limit)
            .map(\.law)
    }
}

// MARK: - Triads
//
// Fairy tales get enormous power from repetition with variation: three
// attempts, three gifts, three crossings, the same place in three kinds of
// weather. The app's other machinery is built to *prevent* recurrence: spoke
// tags, fourteen-day rests, forty-five-day rests on Remembered pages, because
// unintentional repetition is what makes an app feel like a loop.
//
// So a triad has to be a deliberate exemption, and it has to be legible as one.
// A recurrence carrying `TaleTriad.exemptionTag` is the Book repeating itself
// on purpose, and the de-repetition machinery is told to let it through.

struct TaleTriad: Codable, Equatable, Identifiable {
    /// What is recurring: an entity, a place, a question, a phrase.
    var id: String
    var subject: String
    /// The receipts, in order. Three is the whole point; a fourth is a rut.
    var appearances: [TaleWitness]
    var completedAt: Date?

    var count: Int { appearances.count }
    var isComplete: Bool { appearances.count >= 3 }

    /// What the Book is allowed to say at each turn. The first time it says
    /// nothing at all, because a first time is not a pattern.
    var standing: Standing {
        switch appearances.count {
        case 0, 1: return .establishing
        case 2: return .recognising
        default: return .revealing
        }
    }

    enum Standing: String, Codable, Equatable {
        /// Seen once. The Book keeps quiet: noticing aloud would be a lie.
        case establishing
        /// Seen twice. The Book may admit it noticed.
        case recognising
        /// Seen three times. The Book names the pattern, or breaks it.
        case revealing
    }
}

enum TaleTriadKeeper {
    /// Recurrences the de-repetition machinery must let through. Anything
    /// carrying this tag is repeating on purpose, and the rest cadence does not
    /// apply to it.
    static let exemptionTag = "tale-triad-exempt"

    /// A recurrence must span real days, or it is one afternoon of the same
    /// thing rather than a pattern.
    static let minimumDaysBetween: TimeInterval = 2 * 86_400

    /// Groups witnesses into triads by subject. A subject is the concrete thing
    /// that came back: a place, an entity, or the tale beat itself.
    static func triads(from witnesses: [TaleWitness], calendar: Calendar = .current) -> [TaleTriad] {
        var grouped: [String: [TaleWitness]] = [:]
        for witness in witnesses {
            guard let subject = subject(of: witness) else { continue }
            grouped[subject, default: []].append(witness)
        }

        return grouped.compactMap { subject, all -> TaleTriad? in
            // Spread them out: two receipts on the same afternoon are one
            // appearance, not two.
            var spaced: [TaleWitness] = []
            for witness in all.sorted(by: { $0.witnessedAt < $1.witnessedAt }) {
                if let last = spaced.last,
                   witness.witnessedAt.timeIntervalSince(last.witnessedAt) < minimumDaysBetween {
                    continue
                }
                spaced.append(witness)
            }
            guard spaced.count >= 2 else { return nil }
            return TaleTriad(
                id: "triad-\(subject)",
                subject: subject,
                appearances: Array(spaced.prefix(3)),
                completedAt: spaced.count >= 3 ? spaced[2].witnessedAt : nil
            )
        }
        .sorted { left, right in
            if left.count != right.count { return left.count > right.count }
            return left.id < right.id
        }
    }

    /// The concrete recurring thing, if there is one. Beats alone are too
    /// coarse: every tale has several crossings and that is not a triad.
    private static func subject(of witness: TaleWitness) -> String? {
        let interesting = witness.tags
            .map { $0.lowercased() }
            .filter { tag in
                tag.hasPrefix("entity:") || tag.hasPrefix("place:")
                    || tag.hasPrefix("anchor:") || tag.hasPrefix("thread:")
            }
        return interesting.sorted().first
    }

    /// What the Book says, if anything. Silence at one appearance is not a gap
    /// in the feature; it is the feature.
    static func line(for triad: TaleTriad) -> String? {
        switch triad.standing {
        case .establishing:
            return nil
        case .recognising:
            return "That is twice now. I am not saying it means anything. I am saying I noticed, and that I've written both of them down."
        case .revealing:
            return "Three times. In my experience that stops being a coincidence and starts being a law, and I'd rather tell you than keep it to myself and look wise later."
        }
    }
}

// MARK: - Transformation
//
// The Book names the reader on night one. A fairy tale is about becoming, so
// the first naming must not be the last word.
//
// A transformation is not a level-up and cannot be earned by volume. It needs
// an initial identity, repeated behaviour, a failure or overreach, and then a
// choice that contradicts the easy version of the identity. Only then does the
// role take a second half.

struct RoleTransformation: Codable, Equatable, Identifiable {
    var id: String
    /// The role id the reader was named, which does not change.
    var roleID: String
    /// The earned second half: "Who Was Finally Seen".
    var earnedClause: String
    /// The tale that did it.
    var taleID: String
    var shape: TaleShape
    var ending: TaleEnding
    var earnedAt: Date
    /// The receipt: the reader's own line at the moment of the contradiction.
    var evidence: String

    func fullName(baseName: String) -> String {
        "\(baseName) \(earnedClause)"
    }
}

enum RoleTransformationKeeper {
    /// A transformation needs the tale to have actually cost something. Without
    /// an overreach and a contradiction it is a title, not a becoming.
    static func transformation(
        from tale: LivingTale,
        roleID: String,
        roleVerb: String,
        now: Date = Date()
    ) -> RoleTransformation? {
        guard let ending = tale.ending, tale.closedAt != nil else { return nil }
        // The failure or overreach.
        guard tale.has(.transgression) || ending == .imperfect || ending == .returnedEmpty else { return nil }
        // The contradiction: the reader did something the easy version of their
        // role would not have done.
        guard tale.has(.transformation) || ending == .refused || ending == .transformed else { return nil }

        let evidence = tale.readerLines.last ?? ""
        guard let clause = clause(for: tale.shape, ending: ending, roleVerb: roleVerb) else { return nil }

        return RoleTransformation(
            id: "role-transformation-\(tale.id)",
            roleID: roleID,
            earnedClause: clause,
            taleID: tale.id,
            shape: tale.shape,
            ending: ending,
            earnedAt: now,
            evidence: evidence
        )
    }

    /// The earned half. Each one is the role's own habit turned against itself,
    /// which is what a transformation is.
    static func clause(for shape: TaleShape, ending: TaleEnding, roleVerb: String) -> String? {
        switch (shape, ending) {
        case (.forbiddenDoor, .refused): return "Who Stopped at the Door"
        case (.forbiddenDoor, _): return "Who Went Through Anyway"
        case (.unpaidGift, .paid): return "Who Paid What Was Owed"
        case (.unpaidGift, _): return "Who Owes the Fae a Favour"
        case (.threeEncounters, _): return "Who Was Finally Seen"
        case (.falseName, _): return "Who Was Named Wrong Once"
        case (.helpfulStranger, _): return "Who Was Helped for Nothing"
        case (.objectRefused, _): return "Whose Tools Have Opinions"
        case (.promiseMadeTooEasily, .paid): return "Who Kept a Bad Promise"
        case (.promiseMadeTooEasily, _): return "Who Learned to Answer Slowly"
        case (.roadReturnsDifferently, _): return "Who Found a Road Home"
        case (.houseUnderObligation, _): return "Whom a House Is Waiting For"
        case (.lostThingNotWantingFound, .returnedEmpty): return "Who Came Back Empty and Said So"
        case (.lostThingNotWantingFound, _): return "Who Found What Hid"
        }
    }
}

// MARK: - Binding a tale whole
//
// The payoff. The reader is told, afterwards, that they were inside a shape:
// and shown the receipts, in their own words, in the order the grammar tells
// them rather than the order they happened in.
//
// This page asks for nothing. It is the one place where the correct response is
// to read it and close the cover.

enum TaleBinding {
    /// One receipt per act, the best one: the reader's own words first, then
    /// a choice they made, then the world's short record, and the Book's own
    /// prose last. The beginning is the earliest, the climax the latest.
    static func acts(_ tale: LivingTale) -> [TaleAct: TaleWitness] {
        func rank(_ witness: TaleWitness) -> Int {
            if witness.isReaderAuthored { return 0 }
            if witness.isReaderFictionChoice { return 1 }
            if witness.receiptKind != "page" && witness.receiptKind != "event" { return 2 }
            if witness.receiptKind == "event" { return 3 }
            return 4
        }
        var chosen: [TaleAct: TaleWitness] = [:]
        for act in TaleAct.allCases {
            let pool = tale.witnesses.filter {
                $0.beat.act == act && !$0.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            chosen[act] = pool.min { left, right in
                if rank(left) != rank(right) { return rank(left) < rank(right) }
                switch act {
                case .beginning, .middle: return left.witnessedAt < right.witnessedAt
                case .climax, .end: return left.witnessedAt > right.witnessedAt
                }
            }
        }
        return chosen
    }

    /// Beginning, middle and end of a thread tale: the reader's own first page
    /// about it, their last, and the fullest one in between.
    static func threadMoments(_ tale: LivingTale) -> (beginning: TaleWitness, middle: TaleWitness, end: TaleWitness)? {
        let own = tale.witnesses
            .filter { $0.isReaderAuthored && !$0.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.witnessedAt < $1.witnessedAt }
        guard own.count >= 3, let first = own.first, let last = own.last else { return nil }
        let inner = own.dropFirst().dropLast()
        let middle = inner.max { left, right in
            left.evidence.count != right.evidence.count
                ? left.evidence.count < right.evidence.count
                : left.witnessedAt > right.witnessedAt
        } ?? own[own.count / 2]
        return (first, middle, last)
    }

    static func day(of witness: TaleWitness) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: witness.witnessedAt)
    }

    /// One thing, three times, in the reader's own words. The Book says only
    /// what the receipts prove: the thing was there, it came back, and how it
    /// stood at the end.
    static func threadBody(for tale: LivingTale, thread: TaleThread) -> String {
        guard let moments = threadMoments(tale) else { return tale.shape.recognitionLine }
        let appearances = tale.witnesses.filter(\.isReaderAuthored).count
        let name = thread.spoken
        let Name = name.prefix(1).uppercased() + name.dropFirst()

        func quote(_ witness: TaleWitness) -> String {
            "On \(day(of: witness)) you wrote: \u{201C}\(witness.evidence.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}"
        }

        let opening: String
        let once: String
        let then: String
        let stillHere: String
        let gone: String
        switch thread.kind {
        case .place:
            opening = "You kept going back to \(name). I kept count. I didn't say anything until I could see how it came out."
            once = "Once upon a time, there was a place you called \(name)."
            then = appearances > 3 ? "Then you kept going back." : "Then you went back."
            stillHere = "you were still going back."
            gone = "you went back, and it wasn't the same place any more."
        case .thing:
            opening = "\(Name) kept turning up in your pages. I kept count. I didn't say anything until I could see how it came out."
            let article = "aeiou".contains(thread.name.prefix(1).lowercased()) ? "an" : "a"
            once = "Once upon a time, there was \(article) \(thread.name)."
            then = appearances > 3 ? "Then \(name) kept coming back." : "Then \(name) came back."
            stillHere = "\(name) was still there."
            gone = "\(name) wasn't there any more. Things in tales do that. It was there, and you wrote it down, and that part stays."
        }
        let ending: String
        switch tale.ending {
        case .stillHere?, nil: ending = "In the end, " + stillHere
        case .returnedEmpty?: ending = "In the end, " + gone
        case let other?: ending = "In the end, " + other.closingLine
        }

        return [
            opening,
            once + "\n" + quote(moments.beginning),
            then + "\n" + quote(moments.middle),
            ending + "\n" + quote(moments.end),
            "Things in tales come in threes. You were inside this one the whole time."
        ].joined(separator: "\n\n")
    }

    /// Kept for the metadata and editions: the beats the telling rests on.
    static func told(_ tale: LivingTale) -> [(beat: TaleBeat, witness: TaleWitness)] {
        let chosen = acts(tale)
        return TaleAct.allCases.compactMap { act in
            chosen[act].map { ($0.beat, $0) }
        }
    }

    /// How the receipt is said inside the tale. The reader's words are quoted
    /// exactly. Anything else is cut to its first sentence, so a kept letter
    /// is one line of the tale and not the whole letter pasted in.
    static func said(_ witness: TaleWitness) -> String {
        let evidence = witness.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        if witness.isReaderAuthored { return "You wrote: \u{201C}\(evidence)\u{201D}" }
        if witness.isReaderFictionChoice { return "You chose: \u{201C}\(evidence)\u{201D}" }
        return firstSentence(of: evidence)
    }

    static func firstSentence(of text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        if let end = flat.firstIndex(where: { ".!?".contains($0) }) {
            return String(flat[...end])
        }
        return flat.count > 140 ? String(flat.prefix(140)) + "\u{2026}" : flat
    }

    /// The tale, told the way tales are told. Once upon a time, then, and then,
    /// in the end. An act with no receipt is left out rather than made up,
    /// except the ending, which is always true because the tale is over.
    static func body(for tale: LivingTale) -> String {
        if let thread = tale.thread {
            return threadBody(for: tale, thread: thread)
        }
        let chosen = acts(tale)
        var parts: [String] = [tale.shape.recognitionLine]

        func act(_ opener: String, _ line: String, _ witness: TaleWitness?) -> String {
            [opener + line, witness.map(said)].compactMap { $0 }.joined(separator: "\n")
        }

        parts.append(act("Once upon a time, ", tale.shape.once, chosen[.beginning]))
        if let middle = chosen[.middle] {
            parts.append(act("Then ", tale.shape.then, middle))
        }
        if let climax = chosen[.climax] {
            parts.append(act("And then ", tale.shape.climax, climax))
        }
        if let ending = tale.ending {
            parts.append(act("In the end, ", ending.closingLine, chosen[.end]))
        } else if let end = chosen[.end] {
            parts.append(said(end))
        }

        parts.append("You were inside a tale the whole time. I'm not going to ask you anything about it.")
        return parts.joined(separator: "\n\n")
    }

    /// Everything the page carries, as flat metadata. Nothing here is generated
    /// prose: it is the tale's own record, so the page can be rebuilt or
    /// audited without the Book being asked to remember what it meant.
    static func metadata(for tale: LivingTale, scar: TaleScar?, sourceID: String) -> [String: String] {
        var metadata: [String: String] = [
            "source": sourceID,
            "taleID": tale.id,
            "taleShape": tale.shape.rawValue,
            "taleShapeName": tale.shape.commonName,
            "taleTitle": tale.title,
            "taleWitnessCount": "\(tale.witnesses.count)",
            "taleOpenedAt": "\(tale.openedAt.timeIntervalSince1970)",
            "taleBeats": told(tale).map(\.beat.rawValue).joined(separator: ","),
            "taleThreadID": tale.thread?.id ?? "",
            "taleThreadName": tale.thread?.name ?? "",
            "noBeliefReward": "false",
            "tags": [
                "tale-bound",
                "tale:\(tale.id)",
                "tale-shape:\(tale.shape.rawValue)",
                "fiction-aftermath"
            ].joined(separator: ",")
        ]
        if let ending = tale.ending {
            metadata["taleEnding"] = ending.rawValue
            metadata["taleEndingLabel"] = ending.label
            metadata["taleSettled"] = ending.isSettled ? "true" : "false"
        }
        if let scar {
            metadata["taleScarLaw"] = scar.law
            metadata["taleScarSubject"] = scar.subjectKind.rawValue
            metadata["taleScarPermanent"] = scar.isPermanent ? "true" : "false"
        }
        // The reader's own lines, so a share card or an edition can lead with
        // them without re-deriving the tale.
        let lines = tale.readerLines
        if !lines.isEmpty {
            metadata["taleReaderLines"] = lines.joined(separator: "||")
        }
        return metadata
    }

    /// The headline is the tale's own name. Older tales stored a title built
    /// from the reader's last clause; it read as nonsense, so it is not used.
    static func headline(for tale: LivingTale) -> String {
        tale.thread?.title ?? tale.shape.commonName
    }

    /// What the desk says about why this arrived.
    static func reason(for tale: LivingTale) -> String {
        "A tale finished. I only knew it was one at the end. That's how it goes with tales."
    }
}

// MARK: - The old law, six ways
//
// The Fae economy was mechanically sound and morally uniform: every species
// wanted roughly the same thing and differed only in how it said so. That makes
// them task-givers in costume.
//
// Folklore's fae are frightening because their logic is *coherent and not
// yours*. They keep the letter of an agreement against its obvious spirit, care
// enormously about a detail nobody would think to specify, and repay a trivial
// kindness out of all proportion.
//
// So each species reads the same delivered report by its own law and can reach
// a different verdict on it. That is the whole design requirement: the laws must
// genuinely disagree, or they are flavour text.

/// What one species made of a delivery.
struct FaeVerdict: Equatable {
    /// Did the letter of this species' law get met.
    var accepted: Bool
    /// Did the spirit get met, by this species' lights. Letter without spirit
    /// is the classic fae outcome: paid, and not forgiven.
    var wholehearted: Bool
    /// What the creature says.
    var response: String
    /// What another species would say about the identical delivery. This is
    /// where the reader learns the laws are not one law.
    var dissent: String?

    var isTechnicallyCorrectButSpirituallyWrong: Bool {
        accepted && !wholehearted
    }
}

enum FaeLaw {
    /// What this species is actually measuring. None of these is politeness,
    /// effort, or sincerity: those are human currencies.
    static func creed(for kind: FaeKind) -> String {
        switch kind {
        case .punctuationPixie:
            return "Form. It is reading the marks, not the meaning, and it won't be moved by a beautiful sentence that doesn't close."
        case .sentenceSalamander:
            return "Heat. One live verb will do. It can't read anything cold, however true, and length bores it."
        case .bookSprite:
            return "Smallness. It wants a thing that would fit in a pocket. Grandeur reads to it as somebody hiding."
        case .literaryElf:
            return "The exact noun that was named. Not a better one. Substitution is the insult, however generous the substitute."
        case .deepLoreDwarf:
            return "Provenance. Where, when, whose. A detail without an origin is, to a dwarf, a thing somebody has stolen."
        case .goblin:
            return "Trade value. Could this be sold onward to somebody who wants it. Beauty is worthless to a goblin; leverage is everything."
        }
    }

    /// Judges the delivered report by one species' law. The measurements are
    /// deliberately mechanical: a law you can feel the edges of is a law.
    static func judge(report: String, kind: FaeKind, terms: String) -> FaeVerdict {
        let trimmed = report.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })

        switch kind {
        case .punctuationPixie:
            // Reads the marks. A moving report with no terminal punctuation
            // fails; a curt one with a full stop passes.
            let closed = trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
            let marks = trimmed.filter { ",;:—".contains($0) }.count
            return FaeVerdict(
                accepted: closed,
                wholehearted: closed && marks >= 1,
                response: closed
                    ? (marks >= 1
                        ? "The pixie runs a finger along the sentence, finds a comma doing honest work, and is satisfied in a way it would deny under questioning."
                        : "It closes. The pixie accepts it, visibly wishing there had been more furniture in the middle.")
                    : "The pixie won't take it. There is no full stop. It isn't being difficult: to a pixie an unclosed sentence is a door left open in winter, and it will wait.",
                dissent: nil
            )

        case .sentenceSalamander:
            // Wants heat. One live sensory verb anywhere will do, and nothing
            // else counts, including length or truth.
            let hot = ["burn", "crack", "hiss", "slam", "tore", "bit", "smashed", "flared",
                       "steam", "boil", "sting", "snap", "roar", "spat", "blaze", "scald"]
            let heat = hot.filter { lowered.contains($0) }.count
            return FaeVerdict(
                accepted: heat > 0 || words.count <= 12,
                wholehearted: heat > 0,
                response: heat > 0
                    ? "The salamander takes it straight off the page, still warm, and eats it without comment. That is the compliment."
                    : "The salamander turns it over twice. Nothing in it is hot. It accepts the delivery because it is short, and it doesn't thank you.",
                dissent: nil
            )

        case .bookSprite:
            // Smallness. Long or grand reads as evasion.
            let grand = ["everything", "always", "never", "the whole", "my life", "the world", "profound"]
            let inflated = grand.contains { lowered.contains($0) }
            // Nothing at all is not small, it is absent. A sprite is not
            // fooled by an empty hand held out neatly.
            let small = !words.isEmpty && words.count <= 30 && !inflated
            return FaeVerdict(
                accepted: !words.isEmpty && !inflated,
                wholehearted: small,
                response: small
                    ? "The sprite pockets it immediately, which is how you know it was the right size."
                    : (inflated
                        ? "The sprite hands it back. Somewhere in there's one actual object and you have buried it under a cathedral. It will wait for the object."
                        : "The sprite takes it, but holds it at arm's length, the way you hold something bigger than the shelf you meant it for."),
                dissent: nil
            )

        case .literaryElf:
            // The exact noun. Better is not the same as asked for.
            let asked = terms.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .filter { $0.count >= 4 }
                .map(String.init)
            let delivered = asked.contains { lowered.contains($0) }
            return FaeVerdict(
                accepted: delivered,
                wholehearted: delivered,
                response: delivered
                    ? "The elf checks the wording against its own copy, finds them identical, and inclines its head exactly once."
                    : "The elf isn't displeased. The elf is simply not going to accept this, because it isn't what was named. It would like you to understand that these are different things.",
                dissent: nil
            )

        case .deepLoreDwarf:
            // Provenance. Where, when, whose.
            let hasPlace = lowered.contains(" at ") || lowered.contains(" in ") || lowered.contains(" on ")
            let hasNumber = trimmed.contains { $0.isNumber }
            let hasNamed = trimmed.dropFirst().contains { $0.isUppercase }
            let sourced = [hasPlace, hasNumber, hasNamed].filter { $0 }.count
            return FaeVerdict(
                accepted: sourced >= 1,
                wholehearted: sourced >= 2,
                response: sourced >= 2
                    ? "The dwarf writes down where it came from before it looks at what it is, which is the correct order, and files it satisfied."
                    : (sourced == 1
                        ? "The dwarf accepts it and notes, without accusation, that half the provenance is missing. It will remember which half."
                        : "The dwarf sets it down. No place, no hour, no name: for all it can tell you found this in somebody else's pocket. It isn't calling you a thief. It is declining to write it down."),
                dissent: nil
            )

        case .goblin:
            // Trade value. Would somebody else want this.
            let tradeable = words.count >= 6 && (
                trimmed.contains { $0.isNumber }
                    || lowered.contains("nobody") || lowered.contains("no one")
                    || lowered.contains("still") || lowered.contains("left")
                    || trimmed.dropFirst().contains { $0.isUppercase }
            )
            return FaeVerdict(
                accepted: tradeable,
                wholehearted: tradeable,
                response: tradeable
                    ? "The goblin's eyes go flat and businesslike. It can move this. It won't tell you to whom."
                    : "The goblin turns it over looking for the edge it could sell and doesn't find one. \u{201C}Lovely,\u{201D} it says, meaning worthless.",
                dissent: nil
            )
        }
    }

    /// What a *different* species would say about the same delivery. This is
    /// the point of the whole system: two creatures reading one honest report
    /// and reaching incompatible conclusions about whether it was paid.
    static func dissent(report: String, accepted kind: FaeKind, terms: String) -> String? {
        let others = FaeKind.allCases.filter { $0 != kind }
        let mine = judge(report: report, kind: kind, terms: terms)
        // Somebody who disagrees with the verdict, not merely with the style.
        guard let objector = others.first(where: { other in
            judge(report: report, kind: other, terms: terms).accepted != mine.accepted
        }) else { return nil }

        return mine.accepted
            ? "\(objector.name) watched the whole exchange and doesn't agree that this was paid. It won't interfere. It will simply not be counting it."
            : "\(objector.name) thinks the refusal is nonsense and would have taken this without a second look. The two of them have had this argument before and neither has moved."
    }

    /// The full verdict, with the disagreement attached.
    static func verdict(report: String, kind: FaeKind, terms: String) -> FaeVerdict {
        var verdict = judge(report: report, kind: kind, terms: terms)
        verdict.dissent = dissent(report: report, accepted: kind, terms: terms)
        return verdict
    }
}

// MARK: - The ask
//
// The third register of the Book's relationship with a running tale.
//
// It *recognises* a shape from receipts, it *leans* — letting the shape bias
// only what tonight's page notices — and, rarely, it *asks*. Asking is the
// only route by which a shape reaches the reader in words, and even then the
// shape is never named: the Book puts the reader's own repetition back to
// them and invites them to say it is nothing.
//
// A Book that announces "you are in a Forbidden Door story" is a horoscope. A
// Book that asks can be wrong without being presumptuous, and a reader who
// says "yes, that keeps happening" has given better evidence than any
// recogniser can score on its own.

enum BraidTaleAsk {
    struct Ask: Equatable {
        var taleID: String
        /// The Book's question. Never contains the shape or the tale's title.
        var question: String
        var confirm: String
        var refuse: String
    }

    /// What the reader said back.
    enum Answer: String, Codable, Equatable {
        /// The reader recognised it. The strongest evidence available.
        case keepsHappening
        /// The reader did not. Worth more than silence, and the shape rests.
        case joiningDots
    }

    /// A tale must have been running for a while before the Book will risk a
    /// question about it. Two nights is a coincidence.
    static let minimumTaleAgeDays = 7
    /// And the reader must have written inside it more than once, in their own
    /// words. A shape assembled entirely from the Book's own pages is the Book
    /// asking about itself.
    static let minimumReaderLines = 2
    /// Between any two asks, whatever the tale. This is the scarcity that
    /// makes being asked mean something.
    static let restDaysBetweenAsks = 21

    /// Whether the Book may ask tonight, and what it would say.
    ///
    /// Returns nil far more often than not, on purpose. Every gate here is a
    /// reason not to speak.
    static func ask(
        for tale: LivingTale?,
        lastAskedAt: Date?,
        alreadyAskedTaleIDs: Set<String>,
        carriesShadow: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Ask? {
        // Never on a night holding hard material. A reader writing about a
        // funeral is not being invited to discuss narrative structure.
        guard !carriesShadow else { return nil }
        guard let tale, tale.isOpen else { return nil }
        guard !alreadyAskedTaleIDs.contains(tale.id) else { return nil }

        let readerLines = tale.readerLines
        guard readerLines.count >= minimumReaderLines else { return nil }

        let age = calendar.dateComponents([.day], from: tale.openedAt, to: now).day ?? 0
        guard age >= minimumTaleAgeDays else { return nil }

        if let lastAskedAt {
            let since = calendar.dateComponents([.day], from: lastAskedAt, to: now).day ?? 0
            guard since >= restDaysBetweenAsks else { return nil }
        }

        guard let line = readerLines.last?.trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else { return nil }

        return Ask(
            taleID: tale.id,
            // No count, no shape, no title, and the doubt is the Book's own.
            // "am I making a shape out of too little" is the sentence that
            // makes a no cost the reader nothing.
            question: "More than once now you have written your way toward the same thing. "
                + "This was one of them: \u{00AB}\(quoted(line))\u{00BB} "
                + "Does that keep happening, or am I making a shape out of too little?",
            confirm: "It keeps happening",
            refuse: "You are joining dots"
        )
    }

    /// The reader's own line, with the Book's quotation marks stepped down so a
    /// line that already contains them cannot close the quote early.
    private static func quoted(_ line: String) -> String {
        line
            .replacingOccurrences(of: "\u{00AB}", with: "\u{2039}")
            .replacingOccurrences(of: "\u{00BB}", with: "\u{203A}")
    }

    /// What the answer does to the tale.
    ///
    /// A confirmation is a witness in the reader's own hand, so it is recorded
    /// as one. A refusal closes the tale rather than merely pausing it: the
    /// Book was told it had the wrong shape, and carrying on leaning toward a
    /// shape the reader has denied is exactly the presumption asking was
    /// supposed to avoid.
    static func applying(_ answer: Answer, to tale: LivingTale, now: Date = Date()) -> LivingTale {
        var updated = tale
        switch answer {
        case .keepsHappening:
            updated.witnesses.append(
                TaleWitness(
                    id: "\(tale.id)-confirmed-\(Int(now.timeIntervalSince1970))",
                    beat: .test,
                    receiptID: tale.id,
                    receiptKind: "keep",
                    evidence: tale.readerLines.last ?? "",
                    witnessedAt: now,
                    tags: ["reader-confirmed"]
                )
            )
            updated.lastWitnessedAt = now
        case .joiningDots:
            updated.closedAt = now
            updated.ending = .abandoned
        }
        return updated
    }
}

// MARK: - The shape of a span
//
// What a week, a month, a season or a year was, read from structure rather
// than from prose.
//
// Editions used to be a stack of reprinted braids. That works at seven pages
// and fails at three hundred and sixty-five: a volume needs to be able to say
// what it was about, and thirty nightly pages cannot say it by being adjacent.
//
// Nothing here interprets. It reports which beats were witnessed, which tales
// opened and closed, and refuses to name a shape that did not bind. The Book
// is allowed to say "something was running here"; it is not allowed to say
// what it meant.

enum BoundSpanShape {
    struct WitnessedBeat: Equatable {
        var beat: TaleBeat
        var day: Date
        /// The kept line from the braid that carried it, so the volume can
        /// point at the evidence instead of asserting.
        var line: String
    }

    struct Reading: Equatable {
        var beats: [WitnessedBeat]
        var opened: [LivingTale]
        var closed: [LivingTale]

        /// A span with no story in it. Common, and not a failure.
        var isQuiet: Bool { beats.isEmpty && opened.isEmpty && closed.isEmpty }
    }

    /// Reads the span from kept braids and the tales that touched it.
    static func read(
        days: [BookDay],
        tales: [LivingTale],
        from start: Date,
        to end: Date
    ) -> Reading {
        read(
            pages: days.filter { $0.date >= start && $0.date <= end }.flatMap(\.pages),
            tales: tales,
            from: start,
            to: end
        )
    }

    /// The same reading from loose pages, which is the shape an edition holds
    /// its material in.
    static func read(
        pages: [BookPage],
        tales: [LivingTale],
        from start: Date,
        to end: Date
    ) -> Reading {
        var beats: [WitnessedBeat] = []
        do {
            for page in pages
            where page.type == .bookOfYou && page.createdAt >= start && page.createdAt <= end {
                let found = page.tags
                    .filter { $0.hasPrefix("braid-move:") }
                    .compactMap { TaleBeat.forBraidThreadKey(String($0.dropFirst("braid-move:".count))) }
                guard let beat = found.first else { continue }
                // Prefer the stamped residue; fall back to the page's own
                // closing line so braids kept before residue existed still
                // point at evidence rather than at nothing.
                let residue = BookOfYouResidue.fromTags(in: page)
                let line = residue?.keptLine.nonEmpty
                    ?? residue?.spineLine.nonEmpty
                    ?? page.userInput
                        .components(separatedBy: .newlines)
                        .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
                        .trimmingCharacters(in: .whitespaces)
                    ?? ""
                beats.append(WitnessedBeat(beat: beat, day: page.createdAt, line: line))
            }
        }
        beats.sort { $0.day < $1.day }
        return Reading(
            beats: beats,
            opened: tales.filter { $0.openedAt >= start && $0.openedAt <= end },
            closed: tales.filter {
                guard let closedAt = $0.closedAt else { return false }
                return closedAt >= start && closedAt <= end && $0.ending != .abandoned
            }
        )
    }

    /// What the Book says a span was, in one short paragraph.
    ///
    /// Three registers, and the quiet one is not a lesser one. A volume that
    /// admits nothing arranged itself into a story is telling the truth, and
    /// the reader can feel the difference between that and a Book straining to
    /// find meaning in a normal month.
    static func colophon(for reading: Reading, span: String) -> String {
        if let finished = reading.closed.last, !finished.title.isEmpty {
            return "This is the \(span) \u{201C}\(finished.title)\u{201D} finished. "
                + "I did not decide that. You wrote your way out of it and I kept the receipts."
        }

        guard let last = reading.beats.last else {
            return "Nothing in this \(span) arranged itself into a story, and I am not going to "
                + "invent one. It was a \(span). You were in it. That is already more than most "
                + "things manage."
        }

        return "Something has been running under this \(span). \(noticing(last.beat)) "
            + "I am not going to say what shape it is. I have been wrong before, and you would "
            + "be within your rights to tell me so."
    }

    /// What the Book noticed, per beat. Observation only: no beat is allowed a
    /// sentence that says what it meant for the reader.
    private static func noticing(_ beat: TaleBeat) -> String {
        switch beat {
        case .lack:
            return "Something was missing the whole way through, and neither of us named it."
        case .crossing:
            return "You went through something you had been standing beside for a while."
        case .donor:
            return "Somebody turned up who was not asked to."
        case .test:
            return "A question got set, and the answer was not written down anywhere."
        case .price:
            return "Something here cost, and the bill was itemised."
        case .transgression:
            return "A line got crossed. I noted where it had been."
        case .consequence:
            return "Something followed, and it did not have the manners to knock."
        case .transformation:
            return "What came out is not what went in. I have kept both."
        case .ret:
            return "You came back to something, and it had moved while you were gone."
        }
    }
}
