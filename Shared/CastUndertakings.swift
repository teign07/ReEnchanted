import Foundation

// MARK: - Model

/// One beat of a character's own business. `line` is what happens; `trace` is
/// the residue it leaves somewhere the reader might later stumble across.
struct CastUndertakingStage: Codable, Equatable, Identifiable {
    var id: String
    var line: String
    var trace: String
    var tags: [String]
}

enum CastUndertakingStatus: String, Codable, Equatable {
    case active
    /// The trail went cold. A stalled undertaking can resume; it is not a
    /// failure the reader is meant to fix.
    case stalled
    case concluded
    /// It came to nothing. Characters are allowed to give up.
    case abandoned
}

/// Something a character was already in the middle of.
///
/// This is the Book's `BookProject` shape applied to the Cast, and it exists for
/// one structural reason: without it, every actor and thread in the Academy is
/// selected by matching tags against the reader's own kept pages, which quietly
/// makes the world a projection of the reader's day. An undertaking is the
/// alternative seed — business that is already underway and would have advanced
/// whether or not anyone opened the app.
///
/// It assigns the reader nothing. It is never a quest, an invitation, or an ask.
struct CastUndertaking: Codable, Equatable, Identifiable {
    var id: String
    var actorID: String
    var title: String
    var pursuit: String
    var why: String
    var stages: [CastUndertakingStage]
    var stageIndex: Int
    var status: CastUndertakingStatus
    var startedAt: Date
    var lastAdvancedAt: Date
    var nextEligibleAt: Date

    var currentStage: CastUndertakingStage? {
        stages.indices.contains(stageIndex) ? stages[stageIndex] : nil
    }

    var isRunning: Bool { status == .active || status == .stalled }

    /// Tags for actor/thread selection that owe nothing to the reader's archive.
    var seedTags: [String] {
        (currentStage?.tags ?? []) + ["undertaking", "world-business"]
    }
}

// MARK: - Authored ladders

/// The Cast's own business, authored rather than generated. Each ladder is five
/// beats and every beat leaves a trace, because an undertaking the reader can
/// never bump into is only bookkeeping.
enum CastUndertakingRegistry {
    static func ladder(for actorID: String) -> (title: String, pursuit: String, why: String, stages: [CastUndertakingStage])? {
        ladders[actorID]
    }

    static var actorIDs: [String] { ladders.keys.sorted() }

    private static func stage(_ id: String, _ line: String, _ trace: String, _ tags: [String]) -> CastUndertakingStage {
        CastUndertakingStage(id: id, line: line, trace: trace, tags: tags)
    }

    static let ladders: [String: (title: String, pursuit: String, why: String, stages: [CastUndertakingStage])] = [
        "penny-blackletter": (
            title: "The Corrected Record",
            pursuit: "Prove that somebody is altering archived headlines.",
            why: "Penny can forgive a lie. She cannot forgive a quiet edit.",
            stages: [
                stage("punctuation", "Penny notices the punctuation in a forty-year-old headline is not the punctuation that paper used.", "A back issue left open to page four, one comma circled in red.", ["archive", "words", "suspicion"]),
                stage("witnesses", "She interviews three people who were there. Their accounts agree too closely.", "A list of names in the margin, the third crossed out and rewritten.", ["archive", "people", "record"]),
                stage("wrong-name", "She prints an accusation. It names the wrong person.", "A pinned notice, then the same notice with a line through it.", ["mistake", "print", "fault"]),
                stage("retraction", "The retraction is longer than the accusation was, and she sets it in the same size type.", "A retraction nailed to the noticeboard at eye level, refusing to be small.", ["repair", "print", "honesty"]),
                stage("the-word", "The alterations are being made by a word that does not want to be recalled.", "One headline that reads differently depending on how long you look at it.", ["words", "rebellion", "strange"])
            ]
        ),
        "wicker-eddies": (
            title: "Technically Not Entering",
            pursuit: "Get into a sealed room without technically entering it.",
            why: "Wicker is not interested in the room. Wicker is interested in the word 'sealed'.",
            stages: [
                stage("survey", "Wicker measures the sealed door and finds it four inches narrower than its frame.", "Chalk marks on a doorframe, and an arrow pointing at nothing.", ["mischief", "threshold", "rules"]),
                stage("definition", "He spends an afternoon arguing that a room is defined by its floor, not its air.", "A borrowed dictionary, returned with one definition underlined twice.", ["rules", "words", "argument"]),
                stage("mirror", "He gets a mirror inside. He maintains this counts as looking, not entering.", "A hand mirror on a long stick, left leaning in a corridor.", ["mischief", "trick", "threshold"]),
                stage("caught", "Serenity catches him and does not stop him, which he finds far more alarming.", "Two mugs of tea gone cold outside a door nobody opened.", ["care", "friendship", "unsettled"]),
                stage("already-open", "The room was never sealed. Somebody sealed the corridor instead, and nobody noticed for a decade.", "A seal on the wrong side of a wall, old enough to have set.", ["strange", "reversal", "threshold"])
            ]
        ),
        "serenity-brown": (
            title: "The Unofficial Way",
            pursuit: "Establish a detour that becomes more useful than the official corridor.",
            why: "Serenity believes the kindest route is rarely the sanctioned one.",
            stages: [
                stage("worn-line", "She notices the grass has already chosen a path the architects did not.", "A worn line across a lawn, ignoring two perfectly good paths.", ["place", "kindness", "route"]),
                stage("lamp", "She puts a lamp where the detour is darkest and tells nobody she did it.", "One lamp that is not on any maintenance list.", ["care", "place", "quiet"]),
                stage("adoption", "People start giving directions by her detour instead of the corridor.", "Directions chalked by a stranger, using her route as the landmark.", ["place", "people", "route"]),
                stage("objection", "The corridor's defenders object. They are, technically, correct.", "A memo about 'unsanctioned wayfinding', already ignored.", ["rules", "argument", "place"]),
                stage("on-the-map", "The detour appears on the new map. The lamp is still not on any list.", "A printed map with one route drawn in a different hand.", ["place", "victory", "quiet"])
            ]
        ),
        "ambrose-trencher": (
            title: "The Unsigned Recipe",
            pursuit: "Cook the one page in a water-damaged book he cannot read.",
            why: "He buys the handwriting of the dead at estate sales. This one was loved harder than the rest.",
            stages: [
                stage("estate-sale", "Trencher buys a swollen, water-damaged volume in a language he does not read, because one page is grease-thumbed almost transparent.", "A cookbook drying on a radiator, spine mended with tape.", ["food", "books", "memory"]),
                stage("wrong-first", "He cooks the loved page from guesswork and gets it wrong. He eats the whole plate anyway.", "A chalked menu reading only: *an attempt, and rain*.", ["food", "mistake", "attempt"]),
                stage("three-asks", "He asks three people who might know the language. Two decline. One lies, kindly.", "Three cups of tea made, two untouched.", ["people", "language", "kindness"]),
                stage("served-wrong", "He serves the wrong version to the lunch line. Somebody at the far table stops eating and cannot say why.", "One tray returned to the kitchen with nothing left on it and no thank-you delivered.", ["food", "feeling", "unsaid"]),
                stage("a-letter", "It was never a recipe. It is a letter with quantities in it, written to somebody who did not come home.", "A translated page pinned inside a cupboard door, where only he will see it.", ["memory", "grief", "food", "unsaid"])
            ]
        ),
        "lydia-boggle": (
            title: "The Unglamorous Inventory",
            pursuit: "Catalogue every piece of Academy magic that nobody considers magic.",
            why: "Lydia is tired of wonder getting all the credit and none of the maintenance.",
            stages: [
                stage("first-entry", "Entry one: the hinge on the east door that has never once needed oil.", "A ledger begun in a hand too neat for its subject.", ["objects", "ordinary", "record"]),
                stage("resistance", "Three faculty tell her these things are not magic. She writes down their names too.", "A page headed 'Objections', longer than the entries.", ["argument", "record", "faculty"]),
                stage("trade", "Trencher trades her a cookbook for the entry on the soup vat that is always exactly enough.", "Two books swapped on a kitchen counter, neither party thanking the other.", ["food", "friendship", "objects"]),
                stage("lost-page", "The page on the hinge goes missing. The hinge stops working the same week.", "A gap in a numbered ledger, and a door that now creaks.", ["strange", "loss", "objects"]),
                stage("maintenance", "She concludes that the unglamorous magic works because somebody was quietly maintaining it. She does not name who.", "A ledger closed, and a fresh oil can appearing where it is needed.", ["ordinary", "care", "conclusion"])
            ]
        ),
        "dr-inkrest": (
            title: "Premature Conclusions",
            pursuit: "Collect the Academy's confident readings and check them a year later.",
            why: "Inkrest suspects that most insight is only impatience wearing a good coat.",
            stages: [
                stage("gather", "She starts a drawer of confident statements, each dated, each sealed.", "A drawer labelled only with a year, already too full.", ["record", "patience", "judgement"]),
                stage("first-open", "The first envelope is opened. The confident reading was wrong in an interesting way.", "An envelope reopened and annotated in a second, later ink.", ["record", "mistake", "time"]),
                stage("own-hand", "She finds one of the envelopes is in her own handwriting.", "A sealed envelope set aside, unopened for a long while.", ["fault", "honesty", "self"]),
                stage("opened-anyway", "She opens it anyway, in front of a witness, and reads it aloud.", "A witness leaving an office quieter than they entered.", ["repair", "honesty", "witness"]),
                stage("later-drawer", "She starts a second drawer. This one is for things she is not sure about.", "Two drawers now, the uncertain one filling faster.", ["patience", "conclusion", "humility"])
            ]
        ),
        "dr-vellum": (
            title: "The Unmeasured Variable",
            pursuit: "Find the thing that keeps ruining otherwise excellent data.",
            why: "Vellum's models are correct, which is why their failures are so interesting.",
            stages: [
                stage("residual", "A residual keeps appearing in the Tuesday figures and refuses to be noise.", "A chart with one Tuesday circled, four weeks running.", ["data", "pattern", "puzzle"]),
                stage("controls", "Every control is added. The residual gets larger, which should not be possible.", "A whiteboard with more crossings-out than equations.", ["data", "puzzle", "frustration"]),
                stage("lunch", "The residual is lunch. Specifically, it is whether Trencher made soup.", "A dataset with a new column titled, tersely, SOUP.", ["food", "data", "discovery"]),
                stage("refusal", "Vellum refuses to publish a finding that reduces a meal to a coefficient.", "An unfinished paper left face-down on a desk for weeks.", ["ethics", "data", "refusal"]),
                stage("both-true", "The finding is published with the coefficient and the sentence 'this is not what it meant to them'.", "A published table with one footnote longer than the table.", ["data", "meaning", "conclusion"])
            ]
        ),
        "zara-finch": (
            title: "The Chapter That Will Not Start",
            pursuit: "Write the first line of the Great Unwritten Chapter herself.",
            why: "Zara has guided a hundred readers to the threshold and has never once crossed it.",
            stages: [
                stage("blank", "She sits down to write the first line and writes the date instead.", "A page with only a date on it, kept anyway.", ["words", "threshold", "fear"]),
                stage("borrowed", "She tries starting with somebody else's sentence. It will not hold her weight.", "A quotation copied out and then heavily scored through.", ["words", "borrowed", "attempt"]),
                stage("ordinary", "She writes about a bus she missed. It is the first thing that stays on the page.", "A short paragraph about a bus, folded small.", ["ordinary", "words", "honesty"]),
                stage("shown", "She shows it to nobody, then shows it to Trencher, who reads it and puts food down.", "A folded paper left on a kitchen counter overnight and returned unmentioned.", ["friendship", "unsaid", "words"]),
                stage("second-line", "She writes the second line. This turns out to have been the hard one all along.", "A page with two lines on it, and room left underneath.", ["words", "threshold", "beginning"])
            ]
        ),
        "orion-blackthorn": (
            title: "The Instrument That Disagrees",
            pursuit: "Find out why one instrument in the observatory reads differently from all the others.",
            why: "Orion would rather have one honest disagreement than nine agreeable confirmations.",
            stages: [
                stage("outlier", "The old brass instrument reads two degrees off. It has read two degrees off since before anyone here was born.", "A logbook with the same correction written a thousand times.", ["sky", "instrument", "record"]),
                stage("calibrate", "He calibrates it correctly. It goes back to being wrong within a week.", "A calibration certificate, and beneath it, the old correction resumed.", ["instrument", "stubborn", "puzzle"]),
                stage("older-map", "An older map shows the observatory two degrees from where it stands now.", "A map with a building in the wrong place, and no record of a move.", ["place", "strange", "history"]),
                stage("nobody-moved", "Nothing was moved. He checks this four times and then stops checking.", "A set of measurements abandoned mid-column.", ["strange", "unease", "instrument"]),
                stage("keeps-it", "He stops correcting it. He writes 'the instrument is not the thing that is wrong' in the log.", "A logbook where the corrections simply stop, one day, without explanation.", ["sky", "acceptance", "strange"])
            ]
        ),
        "headmistress-thorne": (
            title: "The Unlisted Room",
            pursuit: "Remove one room from the Academy's official plan without removing the room.",
            why: "Thorne has her reasons. She does not offer them, and nobody has yet been rude enough to ask.",
            stages: [
                stage("plan", "A new floor plan is issued. It is correct in every respect but one.", "A floor plan with a corridor that runs slightly too long.", ["rules", "place", "quiet"]),
                stage("noticed", "One student notices. The plan is reissued, and the student is thanked warmly.", "A revised plan, and a note of thanks that answers nothing.", ["authority", "quiet", "unsettling"]),
                stage("key", "A key exists for a door that the plan says is a wall.", "A key on the board with no label, which nobody takes down.", ["strange", "authority", "threshold"]),
                stage("dust", "The dust outside that wall is disturbed on a regular schedule.", "Clean floor in a shape nobody can account for.", ["strange", "place", "evidence"]),
                stage("unasked", "The room stays off the plan. It is now the only room everybody knows about.", "A wall that people walk around rather than past.", ["authority", "strange", "open-secret"])
            ]
        )
    ]
}

// MARK: - Engine

/// Advances the Cast's own business on the world clock. Deterministic, bounded,
/// and entirely indifferent to whether the reader is present.
enum CastUndertakingEngine {
    /// Undertakings move at day scale, not slot scale. The Academy is busy, not
    /// frantic.
    static let minimumDaysBetweenStages = 1
    static let maximumDaysBetweenStages = 4
    /// After finishing, a character rests before taking up anything new.
    static let restDaysAfterConcluding = 9
    /// A trail can go cold rather than marching neatly to its conclusion.
    static let stallChancePercent = 14

    static func seeded(existing: [CastUndertaking], now: Date) -> [CastUndertaking] {
        var result = existing
        for actorID in CastUndertakingRegistry.actorIDs {
            guard !result.contains(where: { $0.actorID == actorID && $0.isRunning }) else { continue }
            // A character who just concluded something is still resting.
            if let last = result.filter({ $0.actorID == actorID }).max(by: { $0.lastAdvancedAt < $1.lastAdvancedAt }),
               last.status == .concluded || last.status == .abandoned,
               now < last.nextEligibleAt {
                continue
            }
            guard let ladder = CastUndertakingRegistry.ladder(for: actorID) else { continue }
            let generation = result.filter { $0.actorID == actorID }.count
            result.append(CastUndertaking(
                id: "undertaking-\(actorID)-\(generation)",
                actorID: actorID,
                title: ladder.title,
                pursuit: ladder.pursuit,
                why: ladder.why,
                stages: ladder.stages,
                stageIndex: 0,
                status: .active,
                startedAt: now,
                lastAdvancedAt: now,
                nextEligibleAt: nextEligible(after: now, seed: "\(actorID)-start")
            ))
        }
        return result
    }

    /// How strongly the world steers toward where things are already happening.
    /// This is the whole convergence mechanism: rather than waiting for three
    /// independent threads to coincide by chance — which, measured over 180
    /// simulated days, happens never — the world simply prefers to advance
    /// business that is adjacent to business already underway. Institutions
    /// behave this way. Things pile up where things are already piling up.
    static let heatBias = 3

    /// At most one undertaking advances per world slot. The Academy has many
    /// people in it; they do not all have a development on the same afternoon.
    ///
    /// `hotActorIDs` are people already involved in a live pressure, a mature
    /// room's history, or a recent movement. Passing none preserves the old
    /// uniform behaviour exactly.
    static func advancing(
        _ undertakings: [CastUndertaking],
        now: Date,
        slotID: String,
        hotActorIDs: Set<String> = []
    ) -> (undertakings: [CastUndertaking], advanced: CastUndertaking?) {
        var result = undertakings
        var eligible = result.indices
            .filter { result[$0].isRunning && now >= result[$0].nextEligibleAt }
            .sorted { result[$0].nextEligibleAt < result[$1].nextEligibleAt }
        guard !eligible.isEmpty else { return (result, nil) }

        // Weighting by repetition rather than by score keeps the selection a
        // single deterministic modulo and leaves every eligible thread reachable.
        if !hotActorIDs.isEmpty {
            let hot = eligible.filter { hotActorIDs.contains(result[$0].actorID) }
            if !hot.isEmpty, hot.count < eligible.count {
                eligible += Array(repeating: hot, count: max(0, heatBias - 1)).flatMap { $0 }
            }
        }

        let choice = eligible[abs("\(slotID)|undertaking-pick".stableHash) % eligible.count]
        var undertaking = result[choice]

        if abs("\(slotID)|\(undertaking.id)|stall".stableHash) % 100 < stallChancePercent {
            undertaking.status = .stalled
            undertaking.nextEligibleAt = nextEligible(after: now, seed: "\(undertaking.id)-stall")
            result[choice] = undertaking
            return (result, nil)
        }

        undertaking.status = .active
        undertaking.stageIndex += 1
        undertaking.lastAdvancedAt = now
        if undertaking.stageIndex >= undertaking.stages.count {
            undertaking.stageIndex = undertaking.stages.count - 1
            undertaking.status = .concluded
            undertaking.nextEligibleAt = now.addingTimeInterval(Double(restDaysAfterConcluding) * 86_400)
        } else {
            undertaking.nextEligibleAt = nextEligible(after: now, seed: "\(undertaking.id)-\(undertaking.stageIndex)")
        }
        result[choice] = undertaking
        return (result, undertaking)
    }

    /// Who the Academy is currently busy around: people in a live pressure,
    /// people a room has taken to, and people who moved recently. This is the
    /// input that lets independently advancing threads wander into the same
    /// room instead of politely avoiding each other.
    static func hotActorIDs(
        pressures: [WorldPressure],
        places: [String: PlaceState],
        recentMovements: [CastAgencyMovement],
        now: Date,
        recentWindowDays: Double = 3
    ) -> Set<String> {
        var hot = Set<String>()
        for pressure in pressures where pressure.isActive(at: now) {
            hot.formUnion(pressure.subjectIDs)
        }
        for place in places.values where place.mayActInsteadOfHost {
            hot.formUnion(place.favoredOccupantIDs)
        }
        let cutoff = now.addingTimeInterval(-recentWindowDays * 86_400)
        for movement in recentMovements where movement.createdAt >= cutoff {
            hot.insert(movement.actorID)
            hot.insert(movement.targetID)
        }
        return hot
    }

    private static func nextEligible(after now: Date, seed: String) -> Date {
        let span = maximumDaysBetweenStages - minimumDaysBetweenStages + 1
        let days = minimumDaysBetweenStages + abs(seed.stableHash) % max(1, span)
        return now.addingTimeInterval(Double(days) * 86_400)
    }
}

// MARK: - What the cast actually did
//
// The Academy's entire action vocabulary used to be three verbs and two
// relationship moves: act, invest, attack — warmed, cooled. That is a scoring
// system wearing character names, and it produced sentences like "Wicker lent
// some warmth to Penny; they grew closer," which describes a ledger entry
// rather than a thing a person did.
//
// An act is the thing a person did. The mechanical deltas ride underneath it
// unchanged, so nothing downstream has to be rewritten — but the page now says
// what happened instead of what changed.
//
// Warmth is not described. It is evidenced. "They grew closer" is a claim;
// "he took the blame for the mislaid ledger, which was not his, and she has not
// mentioned it since" is warmth, and it can be referred back to in six weeks.

enum CastAct: String, Codable, Equatable, CaseIterable {
    // Standing beside somebody, or not
    case defend
    case coverFor
    case concede
    case refuseToConcede
    case correctInPublic
    case correctInPrivate
    case include
    case exclude

    // Obligations
    case owe
    case repayEarly
    case repayLate
    case forgiveADebt

    // Attention, which is the Academy's real currency
    case forgetDeliberately
    case rememberUnasked
    case withhold
    case confide

    // Work
    case finishSomeoneElsesWork
    case abandonJointWork
    case takeCredit
    case apologiseBadly

    /// The neutral description, before anybody's manner is applied. Used only
    /// as a fallback for cast the catalogue has no card for.
    var plainPhrase: String {
        switch self {
        case .defend: return "took {target}'s side out loud"
        case .coverFor: return "took the blame for something that was {target}'s"
        case .concede: return "gave {target} the point"
        case .refuseToConcede: return "would not give {target} the point"
        case .correctInPublic: return "corrected {target} in front of everybody"
        case .correctInPrivate: return "corrected {target} quietly, afterwards"
        case .include: return "brought {target} into something they had no claim on"
        case .exclude: return "left {target} off something they had assumed they were on"
        case .owe: return "ended up owing {target} a favour"
        case .repayEarly: return "repaid {target} before it was due"
        case .repayLate: return "repaid {target} long after everybody had stopped counting"
        case .forgiveADebt: return "let {target}'s debt go without saying so"
        case .forgetDeliberately: return "forgot something of {target}'s on purpose"
        case .rememberUnasked: return "remembered something of {target}'s that nobody expected them to"
        case .withhold: return "knew something {target} needed and did not say it"
        case .confide: return "told {target} something they had not told anybody"
        case .finishSomeoneElsesWork: return "finished a piece of {target}'s work overnight"
        case .abandonJointWork: return "walked away from something they and {target} had started"
        case .takeCredit: return "let themselves be thanked for {target}'s work"
        case .apologiseBadly: return "apologised to {target} without quite managing it"
        }
    }

    /// Which way the thread between two people moves. The old `invest`/`attack`
    /// split survives here as the *consequence* of an act rather than as the
    /// vocabulary of one.
    var relationshipDelta: Int {
        switch self {
        case .defend, .coverFor, .include, .repayEarly, .forgiveADebt,
             .rememberUnasked, .confide, .finishSomeoneElsesWork:
            return 2
        case .concede, .correctInPrivate, .repayLate, .apologiseBadly:
            return 1
        case .owe:
            return 0
        case .refuseToConcede, .withhold, .abandonJointWork:
            return -1
        case .correctInPublic, .exclude, .forgetDeliberately, .takeCredit:
            return -2
        }
    }

    /// Whether the act moves Belief, and which way. Only a few acts do — most
    /// of what people do to each other is not about Belief at all, and pretending
    /// otherwise is what made the old system feel like a game.
    var beliefDelta: Int {
        switch self {
        case .defend, .finishSomeoneElsesWork: return 1
        case .takeCredit, .abandonJointWork: return -1
        default: return 0
        }
    }

    /// Acts that read as an obligation opening rather than a feeling. These are
    /// the ones the Tale Grammar witnesses as a price.
    var opensAnObligation: Bool {
        switch self {
        case .owe, .coverFor, .confide, .forgiveADebt: return true
        default: return false
        }
    }

    /// Acts that are genuinely ambiguous — kind and unkind at once, depending
    /// who you ask. The Book never adjudicates these.
    var isComplicated: Bool {
        switch self {
        case .coverFor, .forgetDeliberately, .withhold, .concede, .forgiveADebt,
             .correctInPrivate, .apologiseBadly:
            return true
        default:
            return false
        }
    }

    var requiresTarget: Bool { true }

    /// The tag the act carries into the archive, so later pages can find it.
    var tag: String { "act:\(rawValue)" }
}

/// How one particular person does a thing.
///
/// This is where "literary instead of game-like" actually lives. It is not that
/// the verbs are richer — it is that the same verb means something different in
/// different hands. Penny corrects in private, with a note, and files a copy.
/// Wicker corrects in public and enjoys it. Serenity concedes in a way that
/// leaves you convinced you won.
struct CastManner: Equatable {
    var castID: String
    /// One line on how this person operates, used when no specific rendering
    /// exists for the act they just performed.
    var signature: String
    /// The acts they reach for. Weighted up when the world picks an act.
    var favours: Set<CastAct>
    /// The acts they will not perform. Never selected for them, whatever the
    /// simulation wants — character holds against convenience.
    var refuses: Set<CastAct>
    /// The specific rendering, with `{target}` for the other person. This is
    /// the sentence that reaches the page.
    var renderings: [CastAct: String]
}

enum CastMannerCatalog {
    /// Hand-authored for the cast the reader actually meets. Everybody else
    /// falls back to the plain phrase, which is serviceable and unremarkable —
    /// exactly the right treatment for somebody the story has not invested in.
    static let manners: [CastManner] = [
        CastManner(
            castID: "penny-blackletter",
            signature: "Penny does things in writing, keeps a copy, and never mentions the copy.",
            favours: [.correctInPrivate, .rememberUnasked, .repayEarly, .refuseToConcede],
            refuses: [.takeCredit, .forgetDeliberately],
            renderings: [
                .correctInPrivate: "Penny left a note in {target}'s pigeonhole with the correct date and nothing else on it. She filed a copy, as she does, and mentioned it to nobody.",
                .correctInPublic: "Penny said it flatly, in the room, with the date. She was right, which did not make the next ten minutes easier for anybody.",
                .defend: "Penny produced the original, unfolded it on the table in front of everyone, and let it do the arguing for {target}.",
                .rememberUnasked: "Penny remembered which shelf {target} had been looking for eight months ago and put the book on their desk without a note.",
                .refuseToConcede: "Penny did not concede. She restated the fact in the same words, at the same volume, and waited.",
                .repayEarly: "Penny returned {target}'s book a week early, rebacked, with the tear mended in a colour that almost matches.",
                .withhold: "Penny knew and did not say. She wrote it down instead, dated it, and put it where she would have to look at it again.",
                .confide: "Penny told {target} one thing about herself, in a single sentence, and immediately changed the subject to the weather.",
                .apologiseBadly: "Penny apologised to {target} in writing, in the third person, and set it in the same size type as the original error."
            ]
        ),
        CastManner(
            castID: "wicker-eddies",
            signature: "Wicker does the technically permitted version of the thing you told him not to do, and wants an audience for it.",
            favours: [.correctInPublic, .takeCredit, .refuseToConcede, .exclude, .coverFor],
            refuses: [.apologiseBadly],
            renderings: [
                .correctInPublic: "Wicker corrected {target} halfway through their own sentence, then apologised for interrupting, then did it again.",
                .correctInPrivate: "Wicker caught {target} alone to correct them, which is so unlike him that {target} has been turning it over ever since.",
                .takeCredit: "Wicker did not claim {target}'s work. He simply failed, at length and with great warmth, to correct anybody who assumed.",
                .coverFor: "Wicker took the blame for {target} instantly and loudly, and made it so entertaining that nobody thought to check whether it was his.",
                .defend: "Wicker defended {target} by insulting everybody else in the room, which worked, and cost {target} two friendships.",
                .refuseToConcede: "Wicker refused the point on a technicality, was told the technicality did not apply, and refused it again on a second one.",
                .exclude: "Wicker left {target} off the list and, when asked, produced a rule that supported him. He had found the rule that morning.",
                .owe: "Wicker owes {target} a favour now, and has already begun describing it as a partnership.",
                .concede: "Wicker conceded, which nobody has ever seen him do, and then spent the rest of the afternoon being unbearable about how gracefully he had done it.",
                .confide: "Wicker told {target} something true about himself, disguised as a joke, at speed, and left before it could be answered."
            ]
        ),
        CastManner(
            castID: "serenity-brown",
            signature: "Serenity gives ground in a way that leaves you convinced you won, and does the useful thing without telling anybody.",
            favours: [.concede, .include, .finishSomeoneElsesWork, .forgiveADebt, .coverFor],
            refuses: [.exclude, .takeCredit, .correctInPublic],
            renderings: [
                .concede: "Serenity gave {target} the point so gracefully that {target} did not notice until that evening that she had not actually agreed.",
                .include: "Serenity added {target} to the thing without announcing it, so that by the time {target} arrived it looked as though they had always been on the list.",
                .finishSomeoneElsesWork: "Serenity finished {target}'s work overnight and left it exactly where they had left it, with nothing added and nothing said.",
                .forgiveADebt: "Serenity stopped mentioning what {target} owed her, which is how she cancels a debt. {target} has noticed and cannot raise it.",
                .coverFor: "Serenity said it had been her error. It had not. She said it in a tone that closed the subject.",
                .correctInPrivate: "Serenity walked {target} to the door and mentioned it on the step, where there was somewhere to look other than at each other.",
                .withhold: "Serenity knew, and judged that {target} could not carry it that week, and said nothing. She is not certain she was right.",
                .rememberUnasked: "Serenity remembered that {target} does not drink tea and made the other thing without being asked or thanked.",
                .abandonJointWork: "Serenity stepped away from the thing she and {target} had started, and was kind about it, and it was still leaving."
            ]
        ),
        CastManner(
            castID: "ambrose-trencher",
            signature: "Trencher answers with food and never with words, and is not to be thanked for it.",
            favours: [.include, .rememberUnasked, .forgiveADebt, .withhold],
            refuses: [.takeCredit, .correctInPublic, .exclude],
            renderings: [
                .include: "Trencher set a second plate down in front of {target} without being asked and went back to the pass before it could be discussed.",
                .rememberUnasked: "Trencher made the thing {target}'s grandmother used to make. He had asked about it once, months ago, and written nothing down.",
                .forgiveADebt: "Trencher took {target}'s name off the slate. He did not scrub it; he wrote the next name over it.",
                .withhold: "Trencher knew, and served lunch, and said nothing, and gave {target} the good end of the loaf.",
                .apologiseBadly: "Trencher apologised to {target} by cooking, badly and at length, the one dish {target} had once mentioned liking.",
                .confide: "Trencher told {target} about the letter in the cupboard door. Then he asked them to pass the salt, and that was the end of it."
            ]
        ),
        CastManner(
            castID: "lydia-boggle",
            signature: "Lydia writes it down, objects on the record, and maintains the thing nobody has thanked her for maintaining.",
            favours: [.correctInPrivate, .refuseToConcede, .finishSomeoneElsesWork, .rememberUnasked],
            refuses: [.forgetDeliberately, .abandonJointWork],
            renderings: [
                .refuseToConcede: "Lydia entered her objection in the ledger, in full, with the date, and then did the work anyway. Both facts are now permanent.",
                .finishSomeoneElsesWork: "Lydia fixed the thing of {target}'s that had been broken for a year and logged it under maintenance, where nobody reads.",
                .correctInPrivate: "Lydia told {target} what was wrong with it, precisely, once, and did not repeat herself when they argued.",
                .rememberUnasked: "Lydia had the spare. She has had the spare for two years. She has been waiting for somebody to need it.",
                .exclude: "Lydia left {target} off it, citing the rule, and the rule was real, and everybody could tell that was not the reason.",
                .correctInPublic: "Lydia corrected {target} in front of the room by reading the entry aloud. She did not editorialise. The entry did that."
            ]
        ),
        CastManner(
            castID: "professor-thaddeus-mook",
            signature: "Mook is enormous, alarming, and hands you the thing you needed before you have finished asking.",
            favours: [.defend, .coverFor, .include, .repayEarly],
            refuses: [.withhold, .takeCredit, .exclude],
            renderings: [
                .defend: "Mook stood up. That was all. The argument ended by itself and {target} was not required to say anything.",
                .coverFor: "Mook said it had been him. Nobody believed it and nobody was going to argue, which was the entire mechanism.",
                .include: "Mook moved his own chair over to make room for {target} and then talked loudly enough that nobody could comment on it.",
                .repayEarly: "Mook returned what he owed {target} in the first week, in person, and stayed exactly as long as it took.",
                .apologiseBadly: "Mook apologised to {target} at some length, made it considerably worse, saw that he had, and apologised for that too."
            ]
        ),
        CastManner(
            castID: "zara-finch",
            signature: "Zara says the thing everybody was thinking, three seconds before it would have been appropriate.",
            favours: [.correctInPublic, .confide, .defend, .refuseToConcede],
            refuses: [.withhold, .forgetDeliberately],
            renderings: [
                .correctInPublic: "Zara said it out loud in the seminar. She was right, and early, and neither of those helped {target} at the time.",
                .confide: "Zara told {target} the whole thing in one breath in a corridor, and then asked whether that had been too much, having already done it.",
                .defend: "Zara defended {target} before {target} had realised they were being attacked, which was both useful and a little frightening.",
                .refuseToConcede: "Zara did not let it go. She has not let anything go yet and shows no sign of beginning."
            ]
        ),
        CastManner(
            castID: "pippa-pilcrow",
            signature: "Pippa is small, fast, and helps in ways that are structurally unsound but arrive first.",
            favours: [.include, .finishSomeoneElsesWork, .rememberUnasked, .apologiseBadly],
            refuses: [.exclude, .withhold, .takeCredit],
            renderings: [
                .include: "Pippa turned up with {target} in tow before anybody had decided whether {target} was coming.",
                .finishSomeoneElsesWork: "Pippa finished {target}'s work enthusiastically and slightly wrong, and the wrongness turned out to be the interesting part.",
                .apologiseBadly: "Pippa apologised to {target} four times in a row, each one longer, until {target} had to stop her.",
                .rememberUnasked: "Pippa remembered {target}'s thing and brought it up at exactly the wrong moment, with enormous pride."
            ]
        ),
        CastManner(
            castID: "headmistress-thorne",
            signature: "Thorne does the correct thing in a way that leaves everybody certain something else has just happened.",
            favours: [.withhold, .concede, .exclude, .forgiveADebt],
            refuses: [.apologiseBadly, .confide],
            renderings: [
                .withhold: "The Headmistress knew. She has known for some time. She asked {target} an unrelated question and watched them answer it.",
                .concede: "Thorne conceded the point immediately and completely, which everybody present found considerably more worrying than a refusal.",
                .exclude: "{target} was not on the list. There was no reason given, and the absence of a reason was the message.",
                .forgiveADebt: "Thorne cancelled what {target} owed without comment, which means she is owed something larger now and has not named it.",
                .defend: "Thorne defended {target} in a sentence so brief and so final that the matter has not been raised again."
            ]
        ),
        CastManner(
            castID: "dr-inkrest",
            signature: "Inkrest is careful, procedural, and quietly on your side in ways that take a term to notice.",
            favours: [.correctInPrivate, .rememberUnasked, .repayLate, .confide],
            refuses: [.correctInPublic, .takeCredit],
            renderings: [
                .correctInPrivate: "Inkrest raised it with {target} at the end of the hour, framed as his own misunderstanding, which it was not.",
                .rememberUnasked: "Inkrest remembered what {target} had said in October and returned to it in March as though no time had passed.",
                .repayLate: "Inkrest repaid it a year late, with an apology for the delay that was longer than the original favour.",
                .confide: "Inkrest told {target} the thing he had not told anybody, and then asked, seriously, whether he should not have."
            ]
        )
    ]

    static func manner(for castID: String) -> CastManner? {
        manners.first { $0.castID == castID }
    }

    /// The sentence that reaches the page. Falls back through: the authored
    /// rendering, then the person's signature plus the plain phrase, then the
    /// plain phrase alone.
    static func render(
        act: CastAct,
        actorID: String,
        actorName: String,
        targetName: String
    ) -> String {
        if let rendering = manner(for: actorID)?.renderings[act] {
            return rendering.replacingOccurrences(of: "{target}", with: targetName)
        }
        let phrase = act.plainPhrase.replacingOccurrences(of: "{target}", with: targetName)
        return "\(actorName) \(phrase)."
    }

    /// Whether this person would do this at all. Character holds against
    /// whatever the simulation would find convenient.
    static func wouldPerform(_ act: CastAct, castID: String) -> Bool {
        guard let manner = manner(for: castID) else { return true }
        return !manner.refuses.contains(act)
    }

    /// Acts weighted for one person: what they reach for first.
    static func weight(_ act: CastAct, castID: String) -> Int {
        guard let manner = manner(for: castID) else { return 10 }
        if manner.refuses.contains(act) { return 0 }
        if manner.favours.contains(act) { return 30 }
        // An authored rendering means somebody thought about this combination,
        // even if it is not a favourite.
        return manner.renderings[act] != nil ? 18 : 8
    }

    /// Picks an act this person would actually perform, deterministically per
    /// slot so the same turn always reads the same way.
    static func chooseAct(castID: String, seed: String) -> CastAct {
        let candidates = CastAct.allCases
            .map { (act: $0, weight: weight($0, castID: castID)) }
            .filter { $0.weight > 0 }
            .sorted { $0.act.rawValue < $1.act.rawValue }
        guard !candidates.isEmpty else { return .concede }
        let total = candidates.reduce(0) { $0 + $1.weight }
        var roll = abs("\(seed)|cast-act".stableHash) % max(1, total)
        for candidate in candidates {
            roll -= candidate.weight
            if roll < 0 { return candidate.act }
        }
        return candidates[0].act
    }
}

/// One thing that happened between two people, kept whole.
///
/// This is what makes warmth evidenced rather than claimed. A relationship
/// weight of +6 says nothing; three of these say who they are to each other.
struct CastActRecord: Codable, Equatable, Identifiable {
    var id: String
    var actorID: String
    var actorName: String
    var targetID: String
    var targetName: String
    var act: CastAct
    /// The sentence that reached the page, kept so it can be quoted back
    /// exactly rather than re-derived into a paraphrase.
    var line: String
    var occurredAt: Date
    var tags: [String]

    /// The unordered pair, so "Wicker and Penny" finds the thread whichever
    /// way round it happened.
    var pairKey: String {
        [actorID, targetID].sorted().joined(separator: "|")
    }
}

/// The Academy's memory of itself, one act at a time.
struct CastActLedger: Codable, Equatable {
    private(set) var records: [CastActRecord] = []

    /// Bounded. A ledger that remembers everything is an archive, and the
    /// Academy is supposed to be a place, not a database.
    static let capacity = 240

    static let empty = CastActLedger()

    mutating func record(_ act: CastActRecord) {
        records.removeAll { $0.id == act.id }
        records.append(act)
        if records.count > Self.capacity {
            records.removeFirst(records.count - Self.capacity)
        }
    }

    /// Everything between these two, newest last.
    func between(_ a: String, _ b: String) -> [CastActRecord] {
        let key = [a, b].sorted().joined(separator: "|")
        return records.filter { $0.pairKey == key }.sorted { $0.occurredAt < $1.occurredAt }
    }

    /// Times this exact person has done this exact thing to this exact person.
    /// The count is what makes a second time recognisable and a third a law.
    func count(act: CastAct, by actorID: String, to targetID: String) -> Int {
        records.filter { $0.act == act && $0.actorID == actorID && $0.targetID == targetID }.count
    }

    func lastAct(by actorID: String, to targetID: String) -> CastActRecord? {
        records
            .filter { $0.actorID == actorID && $0.targetID == targetID }
            .max { $0.occurredAt < $1.occurredAt }
    }

    /// The standing of a pair, read off what actually happened rather than off
    /// a score. This is the honest replacement for "they grew closer."
    func standing(_ a: String, _ b: String) -> Int {
        between(a, b).reduce(0) { $0 + $1.act.relationshipDelta }
    }

    /// Debts that were opened and never answered. These are the threads the
    /// Academy can pull on months later.
    func openObligations(from actorID: String) -> [CastActRecord] {
        let repaid = Set(
            records
                .filter { [.repayEarly, .repayLate, .forgiveADebt].contains($0.act) }
                .map { [$0.actorID, $0.targetID].sorted().joined(separator: "|") }
        )
        return records.filter { $0.actorID == actorID && $0.act.opensAnObligation && !repaid.contains($0.pairKey) }
    }
}

enum CastActMemory {
    /// A line that refers back to the last time, if there was one. This is the
    /// whole point of keeping the ledger: the second time Wicker undermines
    /// Penny should know about the first.
    ///
    /// Returns nil on a first occurrence. A first time is not a pattern, and
    /// saying so would be the Book inventing continuity it does not have.
    static func callback(
        for act: CastAct,
        actorName: String,
        targetName: String,
        priorCount: Int,
        lastLine: String?
    ) -> String? {
        switch priorCount {
        case 0:
            return nil
        case 1:
            return "That is the second time. The first is still on the record and nobody has mentioned it."
        case 2:
            // Three times is a law. Same threshold the Tale Grammar's triads
            // use, and deliberately so.
            return "Three times now. \(actorName) does this to \(targetName). It has stopped being an incident and started being a habit, and I think they both know."
        default:
            return "\(actorName) has done this to \(targetName) \(priorCount + 1) times. I have stopped counting it as news."
        }
    }

    /// What an unanswered obligation sounds like when the world brings it back
    /// up. The Academy does not forget a debt merely because the reader did.
    static func obligationLine(_ record: CastActRecord, now: Date, calendar: Calendar = .current) -> String? {
        let days = calendar.dateComponents([.day], from: record.occurredAt, to: now).day ?? 0
        guard days >= 21 else { return nil }
        switch record.act {
        case .coverFor:
            return "\(record.targetName) still has not mentioned what \(record.actorName) took the blame for. It has been \(days) days and the not-mentioning has become its own object."
        case .owe:
            return "\(record.actorName) has owed \(record.targetName) since \(days) days ago. Neither has raised it. It is beginning to have furniture."
        case .confide:
            return "\(record.actorName) told \(record.targetName) something \(days) days ago and has been slightly careful around them ever since."
        case .forgiveADebt:
            return "\(record.actorName) let it go \(days) days ago without saying so, which means \(record.targetName) still does not know whether they are square."
        default:
            return nil
        }
    }
}

// MARK: - Two people, one act, two memories
//
// These are three different things and the app needs all of them:
//
//   1. `NarrativeEntityMemory` — what one character carries, in their own
//      frame. Private to them.
//   2. `CastActLedger` — the shared record of what happened. Objective, and
//      the same from either side.
//   3. the relationship field — the weighted edge, which is arithmetic.
//
// The third is the one that reads like a game, and it is the one that used to
// be doing all the work. The interesting layer is the first, because the two
// people do not remember it the same way. Wicker remembers taking the blame.
// Penny remembers not having thanked him. Neither is wrong, and the gap between
// them is where the next scene lives.

extension CastActMemory {
    /// What each of the two of them carries away. Deliberately asymmetric: the
    /// same act, framed from the inside of each person.
    static func memories(
        act: CastAct,
        actorID: String,
        actorName: String,
        targetID: String,
        targetName: String
    ) -> [NarrativeEntityMemoryWrite] {
        let (mine, theirs) = framings(act: act, actorName: actorName, targetName: targetName)
        let weight = abs(act.relationshipDelta) + (act.opensAnObligation ? 3 : 1)
        return [
            NarrativeEntityMemoryWrite(
                entityID: actorID,
                summary: mine,
                tags: [act.tag, "cast-act", "toward:\(targetID)"],
                narrativeWeight: weight
            ),
            NarrativeEntityMemoryWrite(
                entityID: targetID,
                summary: theirs,
                tags: [act.tag, "cast-act", "from:\(actorID)"],
                narrativeWeight: weight
            )
        ]
    }

    /// The two insides of one act. The actor's memory is about what they did;
    /// the target's is about what it cost or left them holding — which is
    /// usually a different sentence entirely.
    private static func framings(
        act: CastAct,
        actorName: String,
        targetName: String
    ) -> (actor: String, target: String) {
        switch act {
        case .defend:
            return ("I said it out loud for \(targetName). I would do it again and I would still rather not have had to.",
                    "\(actorName) spoke up for me before I could decide whether I wanted anyone to.")
        case .coverFor:
            return ("I took the blame for \(targetName). It has not come up since and I am not going to be the one to raise it.",
                    "\(actorName) took the blame for something of mine. I have not thanked them, and every day makes it harder to.")
        case .concede:
            return ("I gave \(targetName) the point. I am not certain I was wrong.",
                    "\(actorName) gave me the point so smoothly that I have been rechecking my working ever since.")
        case .refuseToConcede:
            return ("I did not give \(targetName) the point, because I was right.",
                    "\(actorName) would not move. I have stopped expecting them to and started planning around it.")
        case .correctInPublic:
            return ("I corrected \(targetName) in front of everybody. It needed saying. The timing was mine and I chose it.",
                    "\(actorName) corrected me in front of the room. They were right, which is the part I keep returning to.")
        case .correctInPrivate:
            return ("I took \(targetName) aside rather than say it in the room. Nobody knows I did that, including, possibly, them.",
                    "\(actorName) could have said it in front of everyone and did not.")
        case .include:
            return ("I brought \(targetName) in. Nobody asked me to and nobody has remarked on it.",
                    "I was in the room and I am still not sure how. \(actorName) had something to do with it.")
        case .exclude:
            return ("I left \(targetName) off it. I had a reason. The reason is not the whole of it.",
                    "I was not on the list. \(actorName) had a reason ready, which is how I knew there was another one.")
        case .owe:
            return ("I owe \(targetName) now. I have not decided how I feel about that.",
                    "\(actorName) owes me. I am not going to mention it, which I am aware is its own kind of pressure.")
        case .repayEarly:
            return ("I settled with \(targetName) early, because I wanted it off me.",
                    "\(actorName) repaid me before it was due. I had not started expecting it yet.")
        case .repayLate:
            return ("I finally repaid \(targetName). Far too late to be graceful about it.",
                    "\(actorName) came back and settled it, long after I had written it off. That is the part that landed.")
        case .forgiveADebt:
            return ("I stopped mentioning what \(targetName) owed me. That is how I close these.",
                    "\(actorName) has stopped bringing it up. I cannot tell whether that means it is finished.")
        case .forgetDeliberately:
            return ("I let \(targetName)'s thing slip on purpose, and I have been careful not to examine why.",
                    "\(actorName) forgot. They do not forget. I have decided not to make anything of it and I have not managed to.")
        case .rememberUnasked:
            return ("I remembered \(targetName)'s thing. It cost me nothing and I have not said anything about it.",
                    "\(actorName) remembered something about me that I had not told them twice.")
        case .withhold:
            return ("I knew and I did not tell \(targetName). I judged they could not carry it. I am not certain I was right.",
                    "\(actorName) knew before I did. I have not worked out yet whether that was kindness.")
        case .confide:
            return ("I told \(targetName) something I have not told anybody. I have been slightly careful around them since.",
                    "\(actorName) told me something they have not told anyone. I am carrying it and they have not asked how it is going.")
        case .finishSomeoneElsesWork:
            return ("I finished \(targetName)'s work overnight and left it where it was. Saying so would have spoiled it.",
                    "The work was done when I came back to it. \(actorName) has said nothing and neither have I.")
        case .abandonJointWork:
            return ("I walked away from the thing \(targetName) and I had started. I was kind about it. It was still leaving.",
                    "\(actorName) stepped away from our thing. They were gentle. It was still the two of us and then it was one.")
        case .takeCredit:
            return ("I did not correct anybody about \(targetName)'s work. That is not the same as claiming it, and I know how that sounds.",
                    "They thanked \(actorName) for my work and \(actorName) let them. I watched it happen and said nothing.")
        case .apologiseBadly:
            return ("I apologised to \(targetName) and made it worse. I could hear myself doing it.",
                    "\(actorName) apologised. It was a poor apology and it was clearly costing them something, which counted for more than the words.")
        }
    }

    /// Everything one act produces, in one place: the shared record, both
    /// private memories, and the mechanical deltas. Callers do not have to
    /// remember to write all four.
    static func perform(
        act: CastAct,
        actorID: String,
        actorName: String,
        targetID: String,
        targetName: String,
        ledger: CastActLedger,
        at moment: Date,
        seed: String
    ) -> (record: CastActRecord, memories: [NarrativeEntityMemoryWrite], callback: String?) {
        let line = CastMannerCatalog.render(
            act: act, actorID: actorID, actorName: actorName, targetName: targetName
        )
        let prior = ledger.count(act: act, by: actorID, to: targetID)
        let callback = CastActMemory.callback(
            for: act,
            actorName: actorName,
            targetName: targetName,
            priorCount: prior,
            lastLine: ledger.lastAct(by: actorID, to: targetID)?.line
        )
        let record = CastActRecord(
            id: "cast-act-\(seed)",
            actorID: actorID,
            actorName: actorName,
            targetID: targetID,
            targetName: targetName,
            act: act,
            line: line,
            occurredAt: moment,
            tags: [act.tag, "cast-act", "actor:\(actorID)", "target:\(targetID)"]
        )
        return (
            record,
            memories(act: act, actorID: actorID, actorName: actorName, targetID: targetID, targetName: targetName),
            callback
        )
    }
}

/// Acts ride through string-only surface metadata as base-64 JSON, same as the
/// Pocket's keepsakes. They carry too much structure for a token, and the
/// rendered line must survive verbatim rather than being re-derived.
enum CastActArchive {
    static let metadataKey = "castActs"

    static func encode(_ records: [CastActRecord]) -> String {
        guard !records.isEmpty, let data = try? JSONEncoder().encode(records) else { return "" }
        return data.base64EncodedString()
    }

    static func decode(_ encoded: String) -> [CastActRecord] {
        guard let data = Data(base64Encoded: encoded),
              let records = try? JSONDecoder().decode([CastActRecord].self, from: data) else {
            return []
        }
        return records
    }
}
