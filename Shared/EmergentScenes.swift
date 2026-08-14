import Foundation

// MARK: - Purpose
//
// The authored ladders are a finite season: fifty scenes, hand-written, each
// with a turn somebody thought of. This file is the other supply, and it is not
// finite — the simulation has been generating incidents the whole time and
// printing them as ledger sentences.
//
// The thing that makes a beat worth thirty seconds is the *turn*: new
// information that changes what you thought you were watching. A model cannot
// invent those reliably, and one flat beat costs more trust than one good beat
// earns. So nothing here invents a turn. Every turn is lifted from state the
// world already holds — two accounts that disagree, a room that has hosted this
// before, a debt still open, a character doing the opposite of what they did
// last time.
//
// Which gives the governing law:
//
//     No turn, no scene.
//
// An incident the world has produced no turn for stays a report on the ordinary
// Gossip path. That is the whole quality gate, and it is deliberately strict:
// the supply is infinite, so the filter is what carries the form.

/// Where the turn came from. Never invented, never composed — each case names
/// the world state that produced it, so a scene can always be traced back to
/// the thing that justified telling it.
enum EmergentTurn: Equatable {
    /// Two tellings of the same event do not agree. The purest turn the world
    /// makes on its own: the reader learns the record is not settled.
    case contradiction(filed: String, other: String)
    /// This room has hosted this before, often enough to have a character.
    case precedent(placeID: String, tag: String, count: Int)
    /// These two already have something open between them.
    case debt(line: String)
    /// Last time, this character did the opposite. The ledger remembers.
    case reversal(callback: String)
    /// The room itself has begun declining to do something.
    case refusal(placeID: String, refusal: String)

    /// Ranked, so a scene takes the strongest turn available rather than the
    /// first one found. A contradiction beats a pattern; a pattern beats a
    /// mood.
    var rank: Int {
        switch self {
        case .contradiction: return 5
        case .reversal: return 4
        case .debt: return 3
        case .precedent: return 2
        case .refusal: return 1
        }
    }
}

/// Everything the world knows about one thing that happened. Assembled from
/// existing ledgers; nothing here is new canon.
struct EmergentIncident: Equatable {
    var record: CastActRecord
    var place: PlaceState?
    var tie: RelationshipTie
    /// The last time these two were in the ledger together.
    var priorAct: CastActRecord?
    /// Tellings of this event, which may disagree.
    var accounts: [WorldAccount]
    /// A callback line the act ledger already knows how to write.
    var callback: String?
    /// An obligation this act opened or closed.
    var obligation: String?

    init(
        record: CastActRecord,
        place: PlaceState? = nil,
        tie: RelationshipTie = .zero,
        priorAct: CastActRecord? = nil,
        accounts: [WorldAccount] = [],
        callback: String? = nil,
        obligation: String? = nil
    ) {
        self.record = record
        self.place = place
        self.tie = tie
        self.priorAct = priorAct
        self.accounts = accounts
        self.callback = callback
        self.obligation = obligation
    }
}

// MARK: - Which acts behave alike

extension CastAct {
    /// The four things people do to each other in this Academy. Used only to
    /// pick a register — the act itself still supplies the facts.
    enum Family: String, Equatable, CaseIterable {
        /// Taking a side, or refusing to.
        case standing
        /// Owing, repaying, forgiving.
        case debt
        /// Remembering, forgetting, telling, withholding.
        case memory
        /// Work done, abandoned, or claimed.
        case work
    }

    var family: Family {
        switch self {
        case .defend, .coverFor, .concede, .refuseToConcede,
             .correctInPublic, .correctInPrivate, .include, .exclude:
            return .standing
        case .owe, .repayEarly, .repayLate, .forgiveADebt:
            return .debt
        case .forgetDeliberately, .rememberUnasked, .withhold, .confide:
            return .memory
        case .finishSomeoneElsesWork, .abandonJointWork, .takeCredit, .apologiseBadly:
            return .work
        }
    }
}

// MARK: - Finding the turn

enum EmergentTurnFinder {
    /// A room needs real history before its history is a turn.
    static let precedentThreshold = PlaceState.reputationThreshold

    /// The strongest turn the world has produced for this incident, or nil.
    ///
    /// Nil is the common and correct answer. Most of what happens in a building
    /// is just what happened.
    static func turn(for incident: EmergentIncident) -> EmergentTurn? {
        candidates(for: incident).max { $0.rank < $1.rank }
    }

    static func candidates(for incident: EmergentIncident) -> [EmergentTurn] {
        var found: [EmergentTurn] = []

        // Testimony that disagrees with itself. `contradictsSibling` is already
        // set by the account engine; this only notices it.
        let disputed = incident.accounts.filter(\.contradictsSibling)
        if let first = disputed.first,
           let second = incident.accounts.first(where: { $0.id != first.id }) {
            found.append(.contradiction(filed: first.line, other: second.line))
        }

        if let callback = incident.callback?.nonEmpty {
            found.append(.reversal(callback: callback))
        }

        if let obligation = incident.obligation?.nonEmpty {
            found.append(.debt(line: obligation))
        }

        if let place = incident.place {
            if let tag = place.strongestReputationTag,
               place.reputation(for: tag) >= precedentThreshold {
                found.append(.precedent(
                    placeID: place.id,
                    tag: tag,
                    count: place.reputation(for: tag)
                ))
            }
            if let refusal = place.refusal?.nonEmpty {
                found.append(.refusal(placeID: place.id, refusal: refusal))
            }
        }

        return found
    }
}

// MARK: - Assembling one from the ledgers

enum EmergentIncidentAssembler {
    /// How far back an act can be and still be worth dramatising. Older than
    /// this and the world has moved on; the archive keeps it either way.
    static let recentWindowDays: Double = 21

    /// Gather what the world knows about each recent act, newest first.
    ///
    /// Nothing is minted here and nothing is mutated. Every field is read from a
    /// ledger that was already being written whether or not anybody looked.
    static func incidents(
        acts: CastActLedger,
        places: [String: PlaceState],
        relationshipField: [String: RelationshipTie],
        now: Date,
        calendar: Calendar = .current
    ) -> [EmergentIncident] {
        let cutoff = now.addingTimeInterval(-recentWindowDays * 86_400)
        let recent = acts.records
            .filter { $0.occurredAt >= cutoff }
            .sorted { $0.occurredAt > $1.occurredAt }

        return recent.map { record in
            // How often this exact thing has happened between these two before.
            let priors = acts.records.filter {
                $0.id != record.id
                    && $0.pairKey == record.pairKey
                    && $0.act == record.act
                    && $0.occurredAt < record.occurredAt
            }
            let callback = CastActMemory.callback(
                for: record.act,
                actorName: record.actorName,
                targetName: record.targetName,
                priorCount: priors.count,
                lastLine: priors.last?.line
            )
            // An obligation only speaks up once it has been ignored a while.
            let openDebt = acts.records
                .filter { $0.pairKey == record.pairKey && $0.act == .owe }
                .sorted { $0.occurredAt < $1.occurredAt }
                .last
            let obligation = openDebt.flatMap {
                CastActMemory.obligationLine($0, now: now, calendar: calendar)
            }

            return EmergentIncident(
                record: record,
                place: place(for: record, in: places),
                tie: relationshipField[record.pairKey] ?? .zero,
                priorAct: priors.last,
                accounts: [],
                callback: callback,
                obligation: obligation
            )
        }
    }

    /// The room this act belongs to: the one whose history already claims its
    /// tags, so incidents keep piling up where incidents pile up.
    static func place(
        for record: CastActRecord,
        in places: [String: PlaceState]
    ) -> PlaceState? {
        let tags = Set(record.tags)
        let claimed = places.values
            .filter { state in
                state.incidents.contains { !Set($0.tags).isDisjoint(with: tags) }
            }
            .sorted { $0.incidents.count > $1.incidents.count }
        return claimed.first
            ?? places.values.first { $0.favoredOccupantIDs.contains(record.actorID) }
    }

    /// Every incident the world has produced a turn for, strongest first.
    static func dramatisable(
        acts: CastActLedger,
        places: [String: PlaceState],
        relationshipField: [String: RelationshipTie],
        now: Date,
        calendar: Calendar = .current
    ) -> [EmergentScene] {
        incidents(
            acts: acts,
            places: places,
            relationshipField: relationshipField,
            now: now,
            calendar: calendar
        )
        .compactMap(EmergentSceneComposer.scene)
        .sorted { $0.turn.rank > $1.turn.rank }
    }
}

// MARK: - The scene

/// One rendered incident. Same three registers the authored beats use, for the
/// same reason: the ledger keeps its sentence, the Page prints the scene, and
/// the residue goes somewhere else entirely.
struct EmergentScene: Equatable {
    var incidentID: String
    /// The ledger's own sentence, untouched.
    var line: String
    /// The dramatised version.
    var scene: String
    /// What it left behind, unlabelled.
    var residue: String
    var participantIDs: [String]
    var placeID: String?
    var turn: EmergentTurn
    var tags: [String]
}

enum EmergentSceneComposer {
    /// Compose, or decline. Declining is not a failure — see the law at the top
    /// of this file.
    static func scene(for incident: EmergentIncident) -> EmergentScene? {
        guard let turn = EmergentTurnFinder.turn(for: incident) else { return nil }
        let record = incident.record
        let seed = record.id

        let paragraphs = [
            opening(incident, seed: seed),
            collision(incident, seed: seed),
            turnParagraph(turn, incident, seed: seed)
        ].compactMap { $0 }

        return EmergentScene(
            incidentID: record.id,
            line: record.line,
            scene: paragraphs.joined(separator: "\n\n"),
            residue: residue(incident, turn: turn, seed: seed),
            participantIDs: [record.actorID, record.targetID],
            placeID: incident.place?.id,
            turn: turn,
            tags: (["world-business", "emergent", record.act.family.rawValue] + record.tags)
                .reduce(into: [String]()) { found, tag in
                    if !found.contains(tag) { found.append(tag) }
                }
        )
    }

    // MARK: Drop in late

    /// No setup. The scene starts after the interesting thing has begun, which
    /// is the single most reliable compression trick the form has.
    static func opening(_ incident: EmergentIncident, seed: String) -> String {
        let record = incident.record
        let here = placeClause(incident.place)
        let pools: [String]
        switch record.act.family {
        case .standing:
            pools = [
                "\(record.actorName) has already said it\(here), and the room has already heard it.",
                "It is too late to take back, and \(record.actorName) does not look like somebody trying to.",
                "\(record.targetName) has stopped writing. \(record.actorName) has not stopped talking.",
                "Whatever was said\(here) was said at normal volume, which is somehow worse."
            ]
        case .debt:
            pools = [
                "The sum is small enough that neither of them has said a number out loud.",
                "\(record.actorName) is counting something out\(here) and getting it wrong twice.",
                "It has been settled, apparently, and neither of them looks settled.",
                "There is a ledger open\(here) and both of them are pretending not to read it."
            ]
        case .memory:
            pools = [
                "\(record.actorName) remembers it exactly, which is the problem.",
                "\(record.targetName) has just realised \(record.actorName) knew all along.",
                "The sentence stops halfway\(here) and does not start again.",
                "\(record.actorName) has been sitting on this long enough to have chosen the words."
            ]
        case .work:
            pools = [
                "The work is finished. Nobody has said by whom.",
                "\(record.actorName) is holding the finished thing\(here) and not putting it down.",
                "Half of it is done and the half that is done is not \(record.actorName)'s half.",
                "It has been left where it will be found, which is not the same as being given."
            ]
        }
        return pick(pools, seed: "\(seed)|open")
    }

    // MARK: The collision

    /// Somebody or something prevents the want. Drawn from the tie, so two
    /// people who cannot stand each other collide differently from two people
    /// who cannot afford to fall out.
    static func collision(_ incident: EmergentIncident, seed: String) -> String? {
        let record = incident.record
        let phrase = record.act.plainPhrase
            .replacingOccurrences(of: "{target}", with: record.targetName)
        let tie = incident.tie

        if tie.tension >= 12 {
            return pick([
                "\(record.actorName) \(phrase). Neither of them pretends this is the first time.",
                "\(record.actorName) \(phrase), and does it in the tone they have been saving.",
                "\(record.actorName) \(phrase). \(record.targetName) had already braced for it."
            ], seed: "\(seed)|collide-tense")
        }
        if tie.warmth >= 12 {
            return pick([
                "\(record.actorName) \(phrase), which from anybody else would have ended it.",
                "\(record.actorName) \(phrase). It lands harder for being unusual.",
                "\(record.actorName) \(phrase), and only somebody who was owed the benefit of the doubt could."
            ], seed: "\(seed)|collide-warm")
        }
        return pick([
            "\(record.actorName) \(phrase).",
            "What happens is this: \(record.actorName) \(phrase).",
            "\(record.actorName) \(phrase), without appearing to decide to."
        ], seed: "\(seed)|collide")
    }

    // MARK: The turn

    /// The only paragraph that carries new information, and every word of it is
    /// something the world already recorded.
    static func turnParagraph(_ turn: EmergentTurn, _ incident: EmergentIncident, seed: String) -> String {
        let record = incident.record
        switch turn {
        case let .contradiction(filed, other):
            return pick([
                "There are two accounts of this by the evening. One says: \(filed) The other says: \(other) Nobody has offered to reconcile them.",
                "Written down, it went: \(filed) Told aloud, it went: \(other) Both versions have witnesses.",
                "The filed version reads: \(filed) The version going round the building reads: \(other)"
            ], seed: "\(seed)|turn-contradiction")
        case let .reversal(callback):
            return pick([
                "\(callback) Nobody in the room says so, and everybody in the room is thinking it.",
                "Which is not what happened last time. \(callback)",
                "\(callback) \(record.actorName) does not appear to have noticed the shape of it."
            ], seed: "\(seed)|turn-reversal")
        case let .debt(line):
            return pick([
                "\(line) That was not what anybody thought this was about.",
                "And then the older thing surfaces: \(line)",
                "\(line) It has been sitting under the whole conversation."
            ], seed: "\(seed)|turn-debt")
        case let .precedent(placeID, tag, count):
            let room = placeName(placeID)
            return pick([
                "It is the \(ordinal(count)) time \(room) has hosted one of these. Somebody has started counting.",
                "\(room) has seen \(count) of these now. The room is developing a reputation it did not ask for.",
                "This is what \(room) is for, apparently. Nobody planned that; it is simply where \(tag) happens."
            ], seed: "\(seed)|turn-precedent")
        case let .refusal(placeID, refusal):
            let room = placeName(placeID)
            return pick([
                "\(room) \(refusal), which it has been doing for a while now, and which nobody has yet put in writing.",
                "Then \(room) \(refusal). Both of them notice. Neither mentions it.",
                "\(room) \(refusal). The conversation continues around the fact."
            ], seed: "\(seed)|turn-refusal")
        }
    }

    // MARK: Residue

    /// One object, left where somebody could stumble on it. Never labelled and
    /// never explained — the same rule the authored beats keep.
    static func residue(_ incident: EmergentIncident, turn: EmergentTurn, seed: String) -> String {
        if case .contradiction = turn {
            return pick([
                "Two versions of the same notice, pinned a foot apart.",
                "A page in the record with a second hand underneath it, disagreeing politely.",
                "One account filed, one account repeated, and no note saying which came first."
            ], seed: "\(seed)|residue-contradiction")
        }
        let record = incident.record
        switch record.act.family {
        case .standing:
            return pick([
                "Two chairs pushed back from the same table at different angles.",
                "A door held open slightly too long by somebody leaving.",
                "A name on a list, still there, in a slightly different ink."
            ], seed: "\(seed)|residue-standing")
        case .debt:
            return pick([
                "A figure written on the back of something else, and circled once.",
                "A cup returned washed, which nobody asked for.",
                "An envelope on a desk with nothing written on the front."
            ], seed: "\(seed)|residue-debt")
        case .memory:
            return pick([
                "A note folded twice and kept, rather than folded once and posted.",
                "A page turned down at the corner by somebody who does not turn corners.",
                "A drawer left very slightly open."
            ], seed: "\(seed)|residue-memory")
        case .work:
            return pick([
                "A finished piece of work with no name on it.",
                "Two sets of handwriting on one page, one of them stopping abruptly.",
                "A tool cleaned and put back in the wrong place."
            ], seed: "\(seed)|residue-work")
        }
    }

    // MARK: Helpers

    /// Deterministic: the same incident always composes to the same scene, so a
    /// reader who meets it twice is not told two different stories.
    static func pick(_ options: [String], seed: String) -> String {
        guard !options.isEmpty else { return "" }
        return options[abs(seed.stableHash) % options.count]
    }

    static func placeName(_ placeID: String) -> String {
        placeID
            .replacingOccurrences(of: "location-", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    static func placeClause(_ place: PlaceState?) -> String {
        guard let place else { return "" }
        return " in \(placeName(place.id))"
    }

    static func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "first"
        case 2: return "second"
        case 3: return "third"
        case 4: return "fourth"
        case 5: return "fifth"
        case 6: return "sixth"
        case 7: return "seventh"
        default: return "\(value)th"
        }
    }
}
