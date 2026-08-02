import Foundation

// MARK: - The Tale Grammar
//
// The Academy already simulates a world in which fairy tales can happen. It has
// the laws, the bargains, the prices, the sovereign cast, the places that
// remember, and a curse operating in both worlds. What it could not do was
// *recognise* that one had happened.
//
// This is not a plot generator. Nothing here decides what the reader will do,
// and nothing here invents an event. It is a witness: it watches receipts the
// app has already written — a bargain accepted, a Working authorised, a place
// that refused, a role outgrown, a page that came back — and works out whether
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
    /// A helper, tempter, rival, or donor arrives — with or without an invitation.
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
    /// requiring — real lives deliver these out of sequence all the time.
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

/// One beat, witnessed, with the receipt that proves it. `evidence` is the
/// reader's own words or the world's own record — never a paraphrase invented
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

    var isReaderAuthored: Bool {
        receiptKind == "page" || receiptKind == "keep"
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
    /// a consequence — something that could not simply be dismissed — because
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

    var commonName: String {
        switch self {
        case .forbiddenDoor: return "The Forbidden Door"
        case .unpaidGift: return "The Unpaid Gift"
        case .threeEncounters: return "The Three Encounters"
        case .falseName: return "The False Name"
        case .helpfulStranger: return "The Helpful Stranger"
        case .objectRefused: return "The Object That Refused Its Use"
        case .promiseMadeTooEasily: return "The Promise Made Too Easily"
        case .roadReturnsDifferently: return "The Road That Returns Differently"
        case .houseUnderObligation: return "The House Under an Obligation"
        case .lostThingNotWantingFound: return "The Lost Thing That Does Not Want Finding"
        }
    }

    /// What the Book says when it finally admits what it has been watching.
    /// First person, after the fact, and never smug about having known.
    var recognitionLine: String {
        switch self {
        case .forbiddenDoor:
            return "There was a door you had agreed not to open. I watched you stand in front of it for a while, and then I watched you not stand in front of it."
        case .unpaidGift:
            return "You were given something before you had paid for it. I have read that opening a thousand times and it has never once meant generosity, and I said nothing, because saying something is not what I am for at that stage."
        case .threeEncounters:
            return "Three times. I let the first one go, I made a note of the second, and by the third I had stopped pretending I had not been counting."
        case .falseName:
            return "I named you wrong. You knew before I did, and you were polite about it for longer than you needed to be."
        case .helpfulStranger:
            return "Somebody turned up who had no reason to. In my experience that is never free, and it is not always a trick either."
        case .objectRefused:
            return "A thing declined to be used the way it was meant to be used. I would like it on record that I did not put it up to this."
        case .promiseMadeTooEasily:
            return "You said yes very fast. I let you, because saying so at the time would have made me a different sort of book."
        case .roadReturnsDifferently:
            return "You went back. It was not the same, and I do not think it was the place that changed."
        case .houseUnderObligation:
            return "A place has been quietly running up an account in your name. Houses do that, and I only spotted it late, which I mention so you know I am not always ahead of this."
        case .lostThingNotWantingFound:
            return "Something came back that you had put down on purpose. I did not send it. It did not want finding and it turned up anyway, and I think that is the answer rather than the interruption."
        }
    }
}

/// How a tale ended. All six are real endings. The Book does not treat a tale
/// the reader walked away from as a failure — walking away is a thing that
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

    var label: String {
        switch self {
        case .paid: return "Paid"
        case .abandoned: return "Left"
        case .transformed: return "Changed"
        case .imperfect: return "Finished badly"
        case .returnedEmpty: return "Came back empty"
        case .refused: return "Refused"
        }
    }

    /// The Book's own last word on the tale. Never congratulatory, never
    /// disappointed — a tale is not a score.
    var closingLine: String {
        switch self {
        case .paid:
            return "It was paid. Not gracefully, but paid, which is the only part the old law actually checks."
        case .abandoned:
            return "You put it down and did not pick it back up. That is an ending. Most of the tales I know end this way and the tellers leave that part out."
        case .transformed:
            return "It turned into something else on the way through, and there is no version of this where it turns back."
        case .imperfect:
            return "It finished badly and it finished. I would rather have that than a thing left open forever out of tidiness."
        case .returnedEmpty:
            return "You went, and you came back with nothing, and I am writing the nothing down. Empty-handed is a real result. The tales that pretend otherwise are lying."
        case .refused:
            return "You said no and meant it. I have read a great many stories about people who could not do that."
        }
    }

    var isSettled: Bool {
        switch self {
        case .paid, .transformed, .imperfect, .refused: return true
        case .abandoned, .returnedEmpty: return false
        }
    }
}

/// A permanent mark left by a finished tale: some small law that is now true
/// and was not true before. This is the app's literary irreversibility — never
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

/// A tale the reader is currently inside, or has finished. Only one is ever
/// open: fairy tales are singular, and a reader inside three at once is inside
/// none of them.
struct LivingTale: Codable, Equatable, Identifiable {
    var id: String
    var shape: TaleShape
    /// Named by the Book from the reader's own material once there is enough
    /// of it. Empty until then — an unnamed tale is still a tale.
    var title: String
    var witnesses: [TaleWitness]
    var openedAt: Date
    var lastWitnessedAt: Date
    var closedAt: Date?
    var ending: TaleEnding?
    /// Set when the tale has been shown to the reader as a bound page, so it
    /// is never bound twice.
    var boundAt: Date?

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
/// The app fills these in from systems it already owns — the Fae ledger, the
/// Workings, the places, the role tenure — so the grammar stays free of a dozen
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
        let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let beat = beat(forPageType: page.type, tags: tags) else { return nil }
        return TaleWitness(
            id: "tale-witness-page-\(page.id)",
            beat: beat,
            receiptID: page.id,
            receiptKind: "page",
            evidence: text,
            witnessedAt: page.createdAt,
            tags: Array(tags)
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
            // *because* of something — otherwise it is weather.
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

// MARK: - Recognition
//
// Which shape, if any, these witnesses have. The Book prefers the shape whose
// signature the receipts actually carry, and refuses to name one at all when
// the evidence is thin — a wrong shape is worse than no shape, because it
// would make the Book a thing that tells you what your life meant.

extension TaleGrammar {
    struct Recognition: Equatable {
        var shape: TaleShape
        var confidence: Int
        var witnesses: [TaleWitness]
    }

    /// Scores every shape against the witnesses and returns the best, if any
    /// clears the floor. Score is deliberately simple and auditable: opening
    /// beats present, signature tags carried, spread across real days.
    static func recognize(
        witnesses: [TaleWitness],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recognition? {
        guard witnesses.count >= minimumWitnesses else { return nil }
        let days = Set(witnesses.map { calendar.startOfDay(for: $0.witnessedAt) })
        guard days.count >= minimumDistinctDays else { return nil }

        let beats = Set(witnesses.map(\.beat))
        let tags = Set(witnesses.flatMap(\.tags).map { $0.lowercased() })

        let scored: [Recognition] = TaleShape.allCases.compactMap { shape in
            guard shape.openingBeats.isSubset(of: beats) else { return nil }
            let signatureHits = shape.signatureTags.intersection(tags).count
            // A shape with no signature evidence is a coincidence of beats, not
            // a tale. The Helpful Stranger is the one shape thin enough to
            // stand on its beats alone, and it still needs the donor receipt.
            guard signatureHits > 0 || shape == .helpfulStranger else { return nil }

            let relevant = witnesses.filter { witness in
                shape.openingBeats.contains(witness.beat)
                    || !shape.signatureTags.isDisjoint(with: Set(witness.tags.map { $0.lowercased() }))
            }
            let confidence = signatureHits * 20
                + shape.openingBeats.count * 10
                + min(20, days.count * 4)
                + min(15, relevant.filter(\.isReaderAuthored).count * 5)
            return Recognition(shape: shape, confidence: confidence, witnesses: witnesses)
        }

        return scored
            .sorted { left, right in
                if left.confidence != right.confidence { return left.confidence > right.confidence }
                // Stable tie-break, so the same evidence always names the same
                // tale rather than flickering between two readings of it.
                return left.shape.rawValue < right.shape.rawValue
            }
            .first
    }

    /// Names the tale out of the reader's own material. The Book will not name
    /// a tale until the reader has written something inside it — a title
    /// invented from nothing would be the Book writing their life for them.
    static func title(for shape: TaleShape, witnesses: [TaleWitness]) -> String {
        let readerWords = witnesses
            .filter(\.isReaderAuthored)
            .map(\.evidence)
            .filter { $0.count >= 12 }
        guard let source = readerWords.last else { return shape.commonName }

        // The most concrete noun phrase available: the reader's own opening
        // clause, trimmed to something that fits on a spine.
        let clause = source
            .components(separatedBy: CharacterSet(charactersIn: ".,;:—-\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 8 } ?? source

        let words = clause.split(separator: " ")
        let spine = words.count > 8 ? words.prefix(8).joined(separator: " ") : clause
        let cleaned = spine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return shape.commonName }
        return "\(shape.commonName): \(cleaned)"
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

        static let quiet = Verdict(opened: nil, updated: nil, closed: nil, scar: nil)

        var isQuiet: Bool {
            opened == nil && updated == nil && closed == nil && scar == nil
        }
    }

    /// One pass. Takes the currently open tale (if any), the full witness
    /// stream, and decides whether anything happened.
    static func tend(
        current: LivingTale?,
        witnesses: [TaleWitness],
        lastClosedAt: Date? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Verdict {
        if let current, current.isOpen {
            return tendOpen(current, witnesses: witnesses, now: now, calendar: calendar)
        }

        // The reader is allowed to be out of a story. A new tale waits.
        if let lastClosedAt, now.timeIntervalSince(lastClosedAt) < restBetweenTales {
            return .quiet
        }
        guard let recognition = recognize(witnesses: witnesses, now: now, calendar: calendar) else {
            return .quiet
        }
        let relevant = recognition.witnesses
        let opened = LivingTale(
            id: "tale-\(recognition.shape.rawValue)-\(Int(now.timeIntervalSince1970))",
            shape: recognition.shape,
            title: title(for: recognition.shape, witnesses: relevant),
            witnesses: relevant,
            openedAt: relevant.map(\.witnessedAt).min() ?? now,
            lastWitnessedAt: relevant.map(\.witnessedAt).max() ?? now,
            closedAt: nil,
            ending: nil,
            boundAt: nil
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
        let known = Set(tale.witnesses.map(\.receiptID))
        let fresh = witnesses.filter { !known.contains($0.receiptID) && $0.witnessedAt >= tale.openedAt }

        if !fresh.isEmpty {
            tale.witnesses.append(contentsOf: fresh)
            tale.lastWitnessedAt = fresh.map(\.witnessedAt).max() ?? tale.lastWitnessedAt
            if tale.title == tale.shape.commonName {
                tale.title = title(for: tale.shape, witnesses: tale.witnesses)
            }
        }

        // Finished?
        if tale.shape.closingBeats.isSubset(of: tale.witnessedBeats) {
            let ending = ending(for: tale, now: now)
            tale.closedAt = now
            tale.ending = ending
            return Verdict(
                opened: nil, updated: nil, closed: tale,
                scar: scar(for: tale, ending: ending, now: now)
            )
        }

        // Walked away from? That is an ending too, and a common one.
        if now.timeIntervalSince(tale.lastWitnessedAt) >= staleInterval {
            tale.closedAt = now
            tale.ending = .abandoned
            return Verdict(
                opened: nil, updated: nil, closed: tale,
                scar: scar(for: tale, ending: .abandoned, now: now)
            )
        }

        return fresh.isEmpty ? .quiet : Verdict(opened: nil, updated: tale, closed: nil, scar: nil)
    }

    /// Reads the ending off what actually happened. Nothing here is a judgement
    /// of the reader; each branch points at a receipt.
    static func ending(for tale: LivingTale, now: Date = Date()) -> TaleEnding {
        let kinds = Set(tale.witnesses.map(\.receiptKind))
        let tags = Set(tale.witnesses.flatMap(\.tags).map { $0.lowercased() })

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
// punishment, never a locked feature, never harm — the whole register is
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
            return "That door is open now and will not shut again. I have stopped counting it as a boundary and started counting it as a room."
        case (.forbiddenDoor, .refused):
            return "You stood at that door and did not go through, on purpose. I will not offer it to you again in that shape — the offering was the thing you refused."
        case (.forbiddenDoor, _):
            return "There is a door in you I now know the location of. I am not going to keep pointing at it, but I am not going to forget where it is."

        case (.unpaidGift, .paid):
            return "The debt is settled and the gift came back looking different. I am not going to pretend it looks the way it did — repaired is its own finish and I would rather you saw the seam."
        case (.unpaidGift, .imperfect):
            return "That gift went cold on your watch. I have met the one who gave it: they remember the shape of what was agreed far better than the reason for it, and they always will."
        case (.unpaidGift, _):
            return "There is an old-law debt in your name that nobody is chasing. I have never seen one of those expire. They wait, and I will keep the wording of it for you."

        case (.threeEncounters, _):
            return "Three times is a law, not a coincidence. \(subjectName.capitalized) is now something I am allowed to notice out loud without being asked."

        case (.falseName, .transformed):
            return "The name I first gave you was wrong and the wrongness is part of the record. I do not get to quietly rewrite my first guess."
        case (.falseName, _):
            return "You have refused a name I gave you. It stays in the margin as a road not taken, and it may come back years from now as somebody you did not become."

        case (.helpfulStranger, .paid):
            return "Somebody helped you for no reason and was thanked properly. I have written that down as a thing this world does now, and I will let it happen again."
        case (.helpfulStranger, _):
            return "Somebody turned up unasked and left again unpaid. I am keeping that account open at their end rather than yours, which is my decision and not the old law's."

        case (.objectRefused, _):
            return "\(subjectName.capitalized) has refused once. Refusal is a habit in objects. I will not pretend the next request is the first one."

        case (.promiseMadeTooEasily, .paid), (.promiseMadeTooEasily, .imperfect):
            return "You made a promise fast and then had to live inside it. I will ask more slowly next time, and you should be suspicious of how fast I used to ask."
        case (.promiseMadeTooEasily, _):
            return "A promise was made too easily and never came due. I am keeping the wording. The wording is the part that lasts."

        case (.roadReturnsDifferently, _):
            return "You went back and it had changed. That road is now a returning road in my records, and I will offer it to you as one."

        case (.houseUnderObligation, .paid):
            return "The house is square with you. It opened a door it had been keeping shut, and it did that itself — I only watched."
        case (.houseUnderObligation, _):
            return "That place is owed something and has decided to be patient about it. It has closed one door for the season. It did not ask me first."

        case (.lostThingNotWantingFound, .returnedEmpty):
            return "You went looking and came back with nothing, and I wrote the nothing down. It counts. I am not going to send you back for it."
        case (.lostThingNotWantingFound, _):
            return "The thing that did not want finding has been found. I cannot put it back and neither can you, so I have stopped filing it under missing."
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

    /// Laws attached to one subject — a place about to be offered, a role about
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
    /// changing how it speaks. Capped, newest first — a Book reciting nine laws
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
// weather. The app's other machinery is built to *prevent* recurrence — spoke
// tags, fourteen-day rests, forty-five-day rests on Remembered pages — because
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
        /// Seen once. The Book keeps quiet — noticing aloud would be a lie.
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
    /// coarse — every tale has several crossings and that is not a triad.
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
            return "That is twice now. I am not saying it means anything. I am saying I noticed, and that I have written both of them down."
        case .revealing:
            return "Three times. In my experience that stops being a coincidence and starts being a law, and I would rather tell you than keep it to myself and look wise later."
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
// The payoff. The reader is told, afterwards, that they were inside a shape —
// and shown the receipts, in their own words, in the order the grammar tells
// them rather than the order they happened in.
//
// This page asks for nothing. It is the one place where the correct response is
// to read it and close the cover.

enum TaleBinding {
    /// The section headings the bound page uses. Beats without a witness are
    /// simply absent — the Book does not pad a tale out to nine parts.
    static func told(_ tale: LivingTale) -> [(beat: TaleBeat, witness: TaleWitness)] {
        var seen: Set<TaleBeat> = []
        return tale.told.compactMap { witness in
            guard seen.insert(witness.beat).inserted else { return nil }
            return (witness.beat, witness)
        }
    }

    /// The Book's opening: what it is about to do, and the admission that it
    /// only worked this out afterwards.
    static func opening(for tale: LivingTale) -> String {
        """
        I have been keeping something from you, though not on purpose. I did not know what it was until it finished.

        \(tale.shape.recognitionLine)
        """
    }

    /// The body: the tale in its own order, quoting the reader wherever the
    /// reader is the one who wrote it.
    static func body(for tale: LivingTale) -> String {
        var parts: [String] = [opening(for: tale)]

        let sections = told(tale).map { entry -> String in
            let evidence = entry.witness.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !evidence.isEmpty else { return "" }
            if entry.witness.isReaderAuthored {
                return "\(entry.beat.label.capitalized) — you wrote: \u{201C}\(evidence)\u{201D}"
            }
            return "\(entry.beat.label.capitalized) — \(evidence)"
        }.filter { !$0.isEmpty }

        if !sections.isEmpty {
            parts.append(sections.joined(separator: "\n\n"))
        }

        if let ending = tale.ending {
            parts.append(ending.closingLine)
        }

        parts.append("You were inside that the whole time. I am not going to ask you anything about it.")
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

    /// The headline. Uses the reader's own title when they gave the tale one by
    /// writing inside it.
    static func headline(for tale: LivingTale) -> String {
        tale.title.isEmpty ? tale.shape.commonName : tale.title
    }

    /// What the desk says about why this arrived.
    static func reason(for tale: LivingTale) -> String {
        "A tale finished. I only recognised it on the way out, which is how these things generally go."
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
    /// effort, or sincerity — those are human currencies.
    static func creed(for kind: FaeKind) -> String {
        switch kind {
        case .punctuationPixie:
            return "Form. It is reading the marks, not the meaning, and it will not be moved by a beautiful sentence that does not close."
        case .sentenceSalamander:
            return "Heat. One live verb will do. It cannot read anything cold, however true, and length bores it."
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
    /// deliberately mechanical — a law you can feel the edges of is a law.
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
                    : "The pixie will not take it. There is no full stop. It is not being difficult — to a pixie an unclosed sentence is a door left open in winter, and it will wait.",
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
                    : "The salamander turns it over twice. Nothing in it is hot. It accepts the delivery because it is short, and it does not thank you.",
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
                        ? "The sprite hands it back. Somewhere in there is one actual object and you have buried it under a cathedral. It will wait for the object."
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
                    : "The elf is not displeased. The elf is simply not going to accept this, because it is not what was named. It would like you to understand that these are different things.",
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
                        : "The dwarf sets it down. No place, no hour, no name — for all it can tell you found this in somebody else's pocket. It is not calling you a thief. It is declining to write it down."),
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
                    ? "The goblin's eyes go flat and businesslike. It can move this. It will not tell you to whom."
                    : "The goblin turns it over looking for the edge it could sell and does not find one. \u{201C}Lovely,\u{201D} it says, meaning worthless.",
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
            ? "\(objector.name) watched the whole exchange and does not agree that this was paid. It will not interfere. It will simply not be counting it."
            : "\(objector.name) thinks the refusal is nonsense and would have taken this without a second look. The two of them have had this argument before and neither has moved."
    }

    /// The full verdict, with the disagreement attached.
    static func verdict(report: String, kind: FaeKind, terms: String) -> FaeVerdict {
        var verdict = judge(report: report, kind: kind, terms: terms)
        verdict.dissent = dissent(report: report, accepted: kind, terms: terms)
        return verdict
    }
}
