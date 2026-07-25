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

    /// At most one undertaking advances per world slot. The Academy has many
    /// people in it; they do not all have a development on the same afternoon.
    static func advancing(
        _ undertakings: [CastUndertaking],
        now: Date,
        slotID: String
    ) -> (undertakings: [CastUndertaking], advanced: CastUndertaking?) {
        var result = undertakings
        let eligible = result.indices
            .filter { result[$0].isRunning && now >= result[$0].nextEligibleAt }
            .sorted { result[$0].nextEligibleAt < result[$1].nextEligibleAt }
        guard !eligible.isEmpty else { return (result, nil) }

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

    private static func nextEligible(after now: Date, seed: String) -> Date {
        let span = maximumDaysBetweenStages - minimumDaysBetweenStages + 1
        let days = minimumDaysBetweenStages + abs(seed.stableHash) % max(1, span)
        return now.addingTimeInterval(Double(days) * 86_400)
    }
}
