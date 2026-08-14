import Foundation

// MARK: - Model

/// Unfinished business a beat leaves with the reader's actual day.
///
/// This is deliberately not a new ask channel. It mints as a Playful Mission —
/// the errand the Book already sends, with the freshness history, proof prompt,
/// and receipt path missions already have — hosted by the character whose
/// business it is. Two ask systems that do not know about each other's
/// cooldowns will eventually both fire on the same evening, and the reader
/// experiences that as the Book nagging.
///
/// A door is never required and never gated. The scene that opens it does not
/// mention it, the ladder advances whether or not it is answered, and declining
/// costs nothing, which is why nothing anywhere records a refusal.
struct UndertakingDoor: Codable, Equatable {
    var id: String
    var title: String
    /// What to go and notice. This one is allowed to address the reader: it is
    /// an errand, and errands ask. The scene it came from still may not.
    var ask: String
    var proofPrompt: String
    var tags: [String]
}

/// How a beat wants to arrive.
///
/// A beat used to have exactly one way of reaching the reader: a scene on the
/// Gossip channel. That is right for most of them and wrong for some — a
/// character who writes to you is not gossip, and a beat that hands you a
/// choice is a Story Page. Declaring it per beat is better than a global
/// percentage, because the author knows which beat has earned a choice and a
/// percentage never does.
///
/// Unknown values decode to `.witnessedScene`, so a pack authored against a
/// later version of the app degrades to a readable Page instead of vanishing.
enum UndertakingBeatSurface: String, Codable, Equatable, CaseIterable {
    /// The default: dropped into late, cut early, no choice.
    case witnessedScene
    /// The character writes to the reader directly.
    case letter
    /// Something found rather than witnessed — a notice, a list, a torn page.
    case note
    /// A scene the reader is inside, carrying exactly one choice.
    case storyPage

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UndertakingBeatSurface(rawValue: raw) ?? .witnessedScene
    }
}

/// One beat of a character's own business.
///
/// Three registers, and they are not interchangeable:
///
/// - `line` is the ledger voice. It states what happened in one sentence, and
///   it is what the Academy's dispatch, a room's incident record, and a world
///   pressure's summary all quote. Summary is correct there.
/// - `trace` is the residue: the thing left behind somewhere the reader might
///   later stumble across, which is how a beat outlives its own page.
/// - `scene` is the beat dramatised — dropped into late, in one place, with the
///   turn landing near the end and no line after it explaining what it meant.
///   It is what a Page prints. Optional, because a stage without one still
///   works: the ledger sentence stands in, and reads as a report, which is what
///   every beat read as before scenes existed.
///
/// `deniability` is the character's public position on the beat, for the surface
/// where somebody is asked about it on the record. It is the joke that makes a
/// small event feel like it had witnesses.
struct CastUndertakingStage: Codable, Equatable, Identifiable {
    var id: String
    var line: String
    var trace: String
    var tags: [String]
    /// The beat as a scene. Nil falls back to `line`.
    var scene: String?
    /// What this character says about it when it is put to them directly.
    var deniability: String?
    /// Occasionally, business this beat leaves with the reader's own day.
    var door: UndertakingDoor?
    /// Which fictional surface this beat should arrive on. Nil is a witnessed
    /// scene, which is what every beat did before the field existed.
    var surface: UndertakingBeatSurface?
    /// Narrow this beat to one phase of its ladder's world event.
    ///
    /// A hold, not a lock. While the event is genuinely live the beat waits for
    /// its phase, so it lands in the right week. Outside a live run — an archive
    /// reader, or an event that never came round — the hold lifts and the beat
    /// is ordinary, because stranding somebody permanently partway up a ladder
    /// would be a worse failure than a beat arriving out of season.
    var phaseID: String?
    /// Who else is in the scene. The ladder's owner is implied and need not be
    /// repeated. This is what lets a crossing be visible to the consequence
    /// systems instead of being a cameo only the prose knows about.
    var castIDs: [String]?

    /// What a Page should print: the scene if it was authored, the ledger
    /// sentence if it was not.
    var dramatised: String { scene ?? line }

    var arrivesAs: UndertakingBeatSurface { surface ?? .witnessedScene }
}

/// A piece of authored business, whole and shippable.
///
/// This is deliberately plain data with no behaviour, because it is the unit a
/// content pack posts: a ladder in a `*.reenchantedpack.json` is the same
/// object as one compiled into the app, so a pack ladder gets the serial, the
/// world pressure fingerprints, the doors, and the monthly binding for free
/// rather than needing a parallel path.
struct UndertakingLadder: Codable, Equatable, Identifiable {
    var id: String
    /// Whose business this primarily is. The world clock rests *this* character
    /// after it concludes, and the Page is cast from them.
    var actorID: String
    var title: String
    var pursuit: String
    var why: String
    var stages: [CastUndertakingStage]
    /// Everyone who appears anywhere in the ladder, owner included. Derived
    /// when a pack does not state it.
    var castIDs: [String]?
    /// Bind this business to a monthly world event. While that event is live,
    /// the ladder is preferred; outside it, it behaves like any other. Beats may
    /// narrow further to a single phase.
    var eventID: String?
    var phaseID: String?

    var participantIDs: [String] {
        if let castIDs, !castIDs.isEmpty { return castIDs }
        var found = [actorID]
        for stage in stages {
            for id in stage.castIDs ?? [] where !found.contains(id) {
                found.append(id)
            }
        }
        return found
    }
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
/// alternative seed: business that is already underway and would have advanced
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
    /// Which authored ladder this is running. Absent in vaults written before
    /// packs could post business, where a character had exactly one piece of it.
    var ladderID: String?

    /// The ladder this came from, with the pre-pack default filled in.
    var resolvedLadderID: String { ladderID ?? "core-\(actorID)" }

    var currentStage: CastUndertakingStage? {
        stages.indices.contains(stageIndex) ? stages[stageIndex] : nil
    }

    /// The current stage with its prose resolved against the authored registry.
    /// Use this anywhere the words are about to be printed; use `currentStage`
    /// for position, tags, and anything mechanical.
    var currentBeat: CastUndertakingStage? {
        currentStage.map { CastUndertakingRegistry.authored($0, actorID: actorID) }
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
    /// The core season, compiled in. Ladder IDs are stable and prefixed so that
    /// a vault seeded before packs existed still resolves: an undertaking with
    /// no recorded ladder falls back to `core-<actorID>`.
    static let coreLadders: [UndertakingLadder] = authoredLadders
        .map { actorID, authored in
            UndertakingLadder(
                id: "core-\(actorID)",
                actorID: actorID,
                title: authored.title,
                pursuit: authored.pursuit,
                why: authored.why,
                stages: authored.stages
            )
        }
        .sorted { $0.actorID < $1.actorID }

    /// Ladders posted by installed content packs.
    ///
    /// Held statically rather than threaded through every call site because
    /// `authored(_:actorID:)` is reached from deep inside pure prose resolution
    /// that has no access to the app's inputs. Set once at launch. Deliberately
    /// not `@MainActor`: a main-actor static pins work to the main thread even
    /// from a detached task, which is how the archive froze the app before.
    private static var packLadders: [UndertakingLadder] = []

    /// Replace the pack-supplied ladders. Later packs win on ID collision, and
    /// a pack may never overwrite a core ladder — a paid folio must not be able
    /// to rewrite the free season out from under a reader mid-arc.
    static func install(_ ladders: [UndertakingLadder]) {
        var byID: [String: UndertakingLadder] = [:]
        let reserved = Set(coreLadders.map(\.id))
        for ladder in ladders where !reserved.contains(ladder.id) {
            byID[ladder.id] = ladder
        }
        packLadders = byID.values.sorted { $0.id < $1.id }
    }

    static var installedLadders: [UndertakingLadder] { packLadders }

    /// Every ladder currently in play, core first.
    static var allLadders: [UndertakingLadder] { coreLadders + packLadders }

    static func ladder(withID id: String) -> UndertakingLadder? {
        allLadders.first { $0.id == id }
    }

    /// The first ladder belonging to a character. Retained because the world
    /// clock rests characters, not ladders; where a character has more than one
    /// piece of business, prefer `ladders(for:)`.
    static func ladder(for actorID: String) -> UndertakingLadder? {
        allLadders.first { $0.actorID == actorID }
    }

    static func ladders(for actorID: String) -> [UndertakingLadder] {
        allLadders.filter { $0.actorID == actorID }
    }

    static var actorIDs: [String] {
        var seen = Set<String>()
        return allLadders.map(\.actorID).filter { seen.insert($0).inserted }.sorted()
    }

    /// The authored beat, looked up rather than read out of whatever an old
    /// vault happens to be carrying.
    ///
    /// Stages are stored inside each `CastUndertaking`, so a reader whose
    /// undertaking began before a beat was rewritten would otherwise keep the
    /// prose it was seeded with until the whole ladder concluded. Resolving
    /// against the registry makes authored prose upgradeable with no migration:
    /// the vault keeps the *position* in the ladder, and the registry keeps the
    /// words. It is also what lets an installed pack correct its own typo.
    static func authored(_ stage: CastUndertakingStage, actorID: String) -> CastUndertakingStage {
        for ladder in allLadders where ladder.actorID == actorID {
            if let fresh = ladder.stages.first(where: { $0.id == stage.id }) { return fresh }
        }
        return stage
    }

    private static func stage(
        _ id: String,
        _ line: String,
        _ trace: String,
        _ tags: [String],
        castIDs: [String]? = nil,
        scene: String? = nil,
        deniability: String? = nil,
        door: UndertakingDoor? = nil,
        surface: UndertakingBeatSurface? = nil
    ) -> CastUndertakingStage {
        CastUndertakingStage(
            id: id,
            line: line,
            trace: trace,
            tags: tags,
            scene: scene,
            deniability: deniability,
            door: door,
            surface: surface,
            castIDs: castIDs
        )
    }

    private static func door(
        _ id: String,
        _ title: String,
        _ ask: String,
        _ proofPrompt: String,
        _ tags: [String]
    ) -> UndertakingDoor {
        UndertakingDoor(id: id, title: title, ask: ask, proofPrompt: proofPrompt, tags: tags)
    }

    /// The authored core, kept in its original readable shape. `coreLadders`
    /// projects it into the shippable `UndertakingLadder` form; nothing outside
    /// this file should read it directly.
    private static let authoredLadders: [String: (title: String, pursuit: String, why: String, stages: [CastUndertakingStage])] = [
        "penny-blackletter": (
            title: "The Corrected Record",
            pursuit: "Prove that somebody is altering archived headlines.",
            why: "Penny can forgive a lie. She cannot forgive a quiet edit.",
            stages: [
                stage(
                    "punctuation",
                    "Penny notices the punctuation in a forty-year-old headline is not the punctuation that paper used.",
                    "A back issue left open to page four, one comma circled in red.",
                    ["archive", "words", "suspicion"],
                    scene: """
                        Penny has had the same back issue open for eleven minutes and has not turned the page.

                        "That's a serial comma," she says, to nobody in particular. "This paper did not hold with serial commas. This paper wrote letters about serial commas."

                        She checks the masthead. She checks the date. She checks the masthead again.

                        Then she goes very still, and takes out a red pencil, and circles one comma, and does not write anything next to it.
                        """,
                    deniability: "I circled a comma. It's a pencil, not an accusation.",
                    door: door(
                        "penny-wrong-mark",
                        "One Mark in the Wrong Place",
                        "Somewhere near you there is something printed in public — a sign, a menu, a notice, a receipt — with one mark in the wrong place. Penny would like to know it exists.",
                        "What was printed, and what was wrong with it?",
                        ["undertaking-door", "words", "evidence", "outside", "anywhere"]
                    )
                ),
                stage(
                    "witnesses",
                    "She interviews three people who were there. Their accounts agree too closely.",
                    "A list of names in the margin, the third crossed out and rewritten.",
                    ["archive", "people", "record"],
                    scene: """
                        The third interview is going well, which is the problem.

                        "Warm," the man says. "It was warm that day. Unseasonably."

                        Penny turns back a page. "That's what Halloran said."

                        "Well. It was warm."

                        "He said unseasonably."

                        The man's tea stops halfway up. Penny writes his name in the margin, crosses it out, and writes it again underneath, slightly larger.
                        """,
                    deniability: "Three people remembering the same weather is not a conspiracy. It's a Tuesday."
                ),
                stage(
                    "wrong-name",
                    "She prints an accusation. It names the wrong person.",
                    "A pinned notice, then the same notice with a line through it.",
                    ["mistake", "print", "fault"],
                    scene: """
                        The run is ninety copies and forty of them are already out of the building when the door opens.

                        "It's Halloran with two Ls," says Halloran with two Ls. "There's another one. In the annex."

                        Penny looks at the sheet in her hand for a long moment.

                        "How many did you print," he says.

                        She is already moving.
                        """,
                    deniability: "I got it wrong. Print that, and print it the same size."
                ),
                stage(
                    "retraction",
                    "The retraction is longer than the accusation was, and she sets it in the same size type.",
                    "A retraction nailed to the noticeboard at eye level, refusing to be small.",
                    ["repair", "print", "honesty"],
                    scene: """
                        "Smaller," the compositor says. "Retractions go smaller. That's the convention."

                        "Same size."

                        "It'll run to four inches."

                        "Then it runs to four inches."

                        He sets it at four inches. She reads it twice, carries it out to the board herself, and puts the nail in at the exact height of an average person's eye.

                        Somebody in the corridor stops to read it, and then keeps stopping.
                        """,
                    deniability: "The convention is smaller. The convention is also how it happens twice."
                ),
                stage(
                    "the-word",
                    "The alterations are being made by a word that does not want to be recalled.",
                    "One headline that reads differently depending on how long you look at it.",
                    ["words", "rebellion", "strange"],
                    scene: """
                        She has the same headline in front of her four times, printed four different years, and they are identical.

                        She reads the first one again.

                        It is not identical anymore.

                        Penny does not move. She keeps her eyes exactly where they are and says, quite calmly, to the page: "No. Go back."

                        The ink stays where it is, which is not the same as going back.
                        """,
                    deniability: "I'd rather not be quoted on the ink."
                )
            ]
        ),
        "wicker-eddies": (
            title: "Technically Not Entering",
            pursuit: "Get into a sealed room without technically entering it.",
            why: "Wicker is not interested in the room. Wicker is interested in the word 'sealed'.",
            stages: [
                stage(
                    "survey",
                    "Wicker measures the sealed door and finds it four inches narrower than its frame.",
                    "Chalk marks on a doorframe, and an arrow pointing at nothing.",
                    ["mischief", "threshold", "rules"],
                    castIDs: ["serenity-brown"],
                    scene: """
                        Wicker has been on the floor with a tape measure for some time.

                        "Four inches," he says.

                        Serenity, passing: "Four inches of what?"

                        "Door. There's four inches of door that isn't there." He chalks a line up the frame, then another, then an arrow pointing into the gap between them.

                        "That's a wall, Wicker."

                        "That's four inches of wall that used to be door," he says, "which is a completely different animal."
                        """,
                    deniability: "I measured a doorframe. There's no rule about that. I checked the rules.",
                    door: door(
                        "wicker-unlooked-door",
                        "A Door You Have Never Looked At",
                        "There is a door you have walked past so often you have stopped seeing it. A service door, a cupboard, a gate, a hatch. Go and look at it properly, the way you would look at a door you had never met.",
                        "Which door was it, and what had you never noticed about it?",
                        ["undertaking-door", "threshold", "outside", "place", "anywhere"]
                    )
                ),
                stage(
                    "definition",
                    "He spends an afternoon arguing that a room is defined by its floor, not its air.",
                    "A borrowed dictionary, returned with one definition underlined twice.",
                    ["rules", "words", "argument"],
                    scene: """
                        "A room," Wicker says, "is a floor with opinions."

                        Professor Mook does not look up. "A room is an enclosed space."

                        "Enclosed by what."

                        "Walls."

                        "Air's not a wall." Wicker leans across the desk and turns the dictionary round. "Go on. Read it out. Show me where it says air."

                        Mook reads it. There is quite a long pause. Then Mook takes the pencil out of Wicker's hand, before Wicker can get to it, and underlines the definition twice himself.
                        """,
                    deniability: "I have been advised that a room is an enclosed space. I am appealing."
                ),
                stage(
                    "mirror",
                    "He gets a mirror inside. He maintains this counts as looking, not entering.",
                    "A hand mirror on a long stick, left leaning in a corridor.",
                    ["mischief", "trick", "threshold"],
                    scene: """
                        The stick is six feet of curtain rail and the mirror is off somebody's dressing table, and the two are held together with a great deal of tape.

                        He feeds it under the door and squints.

                        "Anything?" says Pippa.

                        "Chair. Table. Something with a cloth over it." The mirror turns a few degrees. He stops squinting.

                        "Wicker."

                        "It's a chair," he says, much too quickly, and hauls the whole apparatus out, and leaves it leaning in the corridor, and walks off at a speed that is not quite running.
                        """,
                    deniability: "A mirror went in. I stayed out. Ask the mirror."
                ),
                stage(
                    "caught",
                    "Serenity catches him and does not stop him, which he finds far more alarming.",
                    "Two mugs of tea gone cold outside a door nobody opened.",
                    ["care", "friendship", "unsettled"],
                    castIDs: ["serenity-brown"],
                    scene: """
                        Serenity is sitting on the floor beside the sealed door with two mugs of tea when he comes round the corner.

                        Wicker stops.

                        "One's yours," she says.

                        He does not take it. "You're going to tell me to stop."

                        "No."

                        "You're going to fetch somebody."

                        "No." She blows on hers. "I'd quite like to see it too."

                        Wicker stands there holding six feet of curtain rail and looks, for the first time in the whole business, genuinely unwell.
                        """,
                    deniability: "Serenity was present. Serenity was sitting down. Draw your own conclusions."
                ),
                stage(
                    "already-open",
                    "The room was never sealed. Somebody sealed the corridor instead, and nobody noticed for a decade.",
                    "A seal on the wrong side of a wall, old enough to have set.",
                    ["strange", "reversal", "threshold"],
                    castIDs: ["serenity-brown"],
                    scene: """
                        The door opens on the first pull.

                        Wicker looks at his hand on the handle, and then at the room, which is a room, with a chair in it.

                        "It's not locked," he says.

                        Serenity is not looking at the room. She is looking back the way they came, at the seal across the mouth of the corridor — grey, cracked, set hard, the kind of old that takes ten years.

                        "Wicker," she says. "Which side of that were we on."
                        """,
                    deniability: "The room was open the entire time. I want that on the record, in the same size type as the rest."
                )
            ]
        ),
        "serenity-brown": (
            title: "The Unofficial Way",
            pursuit: "Establish a detour that becomes more useful than the official corridor.",
            why: "Serenity believes the kindest route is rarely the sanctioned one.",
            stages: [
                stage(
                    "worn-line",
                    "She notices the grass has already chosen a path the architects did not.",
                    "A worn line across a lawn, ignoring two perfectly good paths.",
                    ["place", "kindness", "route"],
                    scene: """
                        Serenity is standing on the lawn in the rain, not crossing it.

                        "There's a path," says a passing student, helpfully, pointing at the path.

                        "There are two," she says. "Nobody's using either."

                        He looks. There is a line worn brown through the grass from the corner of the library to the kitchen door, dead straight, ignoring both of them.

                        "That's just where people walk."

                        "Yes," says Serenity, and writes something down, and gets wetter.
                        """,
                    deniability: "Grass doesn't take sides. Grass keeps a record.",
                    door: door(
                        "serenity-worn-route",
                        "The Route Nobody Drew",
                        "Near you, people have worn a way through somewhere they were not meant to walk — across a corner of grass, through a gap in a hedge, over a kerb. Serenity collects these.",
                        "Where did it go, and which official route was it ignoring?",
                        ["undertaking-door", "place", "route", "outside", "walking"]
                    )
                ),
                stage(
                    "lamp",
                    "She puts a lamp where the detour is darkest and tells nobody she did it.",
                    "One lamp that is not on any maintenance list.",
                    ["care", "place", "quiet"],
                    scene: """
                        It is nearly midnight and Serenity is up a borrowed ladder with a lamp under one arm.

                        The bracket is not a bracket. It is a nail somebody put in for something else, years ago. It holds.

                        She climbs down, walks to the far end of the worn line, and looks back.

                        The dark part is not dark anymore.

                        She returns the ladder to where she found it, does not write the lamp down anywhere, and goes to bed.
                        """
                ),
                stage(
                    "adoption",
                    "People start giving directions by her detour instead of the corridor.",
                    "Directions chalked by a stranger, using her route as the landmark.",
                    ["place", "people", "route"],
                    scene: """
                        "Kitchen door, then the lit bit," the porter is saying. "You'll see a lamp. Left at the lamp."

                        The visitor writes it down.

                        "There's a corridor," Serenity says, from behind them.

                        The porter waves a hand. "Nobody goes that way."

                        Somebody has chalked it on the flagstones by the gate, arrow and all: LEFT AT THE LAMP.

                        It is not her handwriting. She has no idea whose it is.
                        """,
                    deniability: "I put up one lamp. The chalk is a separate matter entirely."
                ),
                stage(
                    "objection",
                    "The corridor's defenders object. They are, technically, correct.",
                    "A memo about 'unsanctioned wayfinding', already ignored.",
                    ["rules", "argument", "place"],
                    scene: """
                        The memo uses the phrase unsanctioned wayfinding three times.

                        "It's a lawn," Serenity says.

                        "It's a thoroughfare now," says the Bursar, "which is a different classification, with drainage implications."

                        "Is it damaging the grass?"

                        "Yes."

                        "Is the corridor damaging anything?"

                        "The corridor," says the Bursar, with the patience of a man who is right, "is a corridor. It cannot be damaged by being used correctly."

                        Serenity has no answer to this, and says so.
                        """,
                    deniability: "The Bursar is correct. I'd like that minuted, and I'd like the lamp left alone."
                ),
                stage(
                    "on-the-map",
                    "The detour appears on the new map. The lamp is still not on any list.",
                    "A printed map with one route drawn in a different hand.",
                    ["place", "victory", "quiet"],
                    scene: """
                        The new map goes up on Thursday and the line across the lawn is on it.

                        Serenity finds the draughtsman at lunch. "Who told you to put it in?"

                        "Nobody," he says. "It's where people walk."

                        She looks at the map for a while. The route is there in proper printed ink, named and everything. The lamp is not on it. The lamp is not on anything.

                        "Leave it off," she says.

                        "Leave what off?"

                        "Good," says Serenity.
                        """
                )
            ]
        ),
        "ambrose-trencher": (
            title: "The Unsigned Recipe",
            pursuit: "Cook the one page in a water-damaged book he cannot read.",
            why: "He buys the handwriting of the dead at estate sales. This one was loved harder than the rest.",
            stages: [
                stage(
                    "estate-sale",
                    "Trencher buys a swollen, water-damaged volume in a language he does not read, because one page is grease-thumbed almost transparent.",
                    "A cookbook drying on a radiator, spine mended with tape.",
                    ["food", "books", "memory"],
                    scene: """
                        The book costs him ninety pence and it is not really a book anymore, more a brick that used to be one.

                        "It's ruined," the woman says. "It's all ruined. It was under the window."

                        Trencher is not listening. He has it open at a page in the middle and he is holding it up to the window, and the corner of that page is so thumbed that the light comes through it.

                        He cannot read a word of it.

                        "I'll take it," he says.
                        """,
                    deniability: "It cost ninety pence. There's no story in ninety pence."
                ),
                stage(
                    "wrong-first",
                    "He cooks the loved page from guesswork and gets it wrong. He eats the whole plate anyway.",
                    "A chalked menu reading only: *an attempt, and rain*.",
                    ["food", "mistake", "attempt"],
                    scene: """
                        It comes out grey.

                        Trencher stands over it with the wooden spoon still in his hand and looks at it for a while.

                        Then he plates all of it, and sits down at the end of the long table where nobody sits, and eats the entire thing.

                        Afterwards he goes out and rubs the board clean and chalks up, for the evening: an attempt, and rain.

                        Somebody asks what's in it. He says he'll know next time.
                        """,
                    deniability: "It was fine. It was grey and it was fine."
                ),
                stage(
                    "three-asks",
                    "He asks three people who might know the language. Two decline. One lies, kindly.",
                    "Three cups of tea made, two untouched.",
                    ["people", "language", "kindness"],
                    scene: """
                        The third one takes the page and holds it at arm's length for a long time.

                        "Flour," she says. "Flour, and something, and a quantity of butter."

                        "And that word?"

                        "That's the butter."

                        "You said the other one was the butter."

                        She hands the page back and picks up her tea, which she has not touched, and drinks all of it at once. "It's a very old dialect," she says. "You'd want somebody older."

                        There is nobody older.
                        """,
                    deniability: "Three people looked at it. That's a consultation."
                ),
                stage(
                    "served-wrong",
                    "He serves the wrong version to the lunch line. Somebody at the far table stops eating and cannot say why.",
                    "One tray returned to the kitchen with nothing left on it and no thank-you delivered.",
                    ["food", "feeling", "unsaid"],
                    scene: """
                        It is still not right. He serves it anyway, ninety portions, because ninety people have to eat.

                        Halfway down the far table a woman puts her fork down.

                        She does not say anything. She sits with her hands in her lap and the plate in front of her and looks at the middle of the table for as long as it takes the room to get loud again.

                        Then she finishes it. All of it. And carries the tray back herself, and sets it down on the counter, and leaves without a word.
                        """
                ),
                stage(
                    "a-letter",
                    "It was never a recipe. It is a letter with quantities in it, written to somebody who did not come home.",
                    "A translated page pinned inside a cupboard door, where only he will see it.",
                    ["memory", "grief", "food", "unsaid"],
                    scene: """
                        The visiting archivist reads it twice before she says anything.

                        "This isn't a method," she says.

                        "There's weights in it."

                        "Yes." She turns the page round for him and points, though he cannot read it. "But it's addressed. There — that's a name. And this at the end isn't an instruction, it's — " She stops. "It says: it will keep until you are back."

                        Trencher takes the page and holds it. Behind him the kitchen goes on being loud, the way kitchens are.
                        """
                )
            ]
        ),
        "lydia-boggle": (
            title: "The Unglamorous Inventory",
            pursuit: "Catalogue every piece of Academy magic that nobody considers magic.",
            why: "Lydia is tired of wonder getting all the credit and none of the maintenance.",
            stages: [
                stage(
                    "first-entry",
                    "Entry one: the hinge on the east door that has never once needed oil.",
                    "A ledger begun in a hand too neat for its subject.",
                    ["objects", "ordinary", "record"],
                    scene: """
                        Lydia has been standing at the east door opening and closing it for four minutes.

                        "Is it broken?" somebody asks.

                        "It's ninety years old and it has never been oiled." She swings it again. It makes no sound whatsoever. "There's no oil in the log. There's no oil in any log. Somebody would have written it down."

                        She takes out a new ledger, rules a margin, and writes at the top, in handwriting far too good for the subject: ENTRY ONE. HINGE, EAST DOOR.
                        """,
                    deniability: "It's a hinge. I'm aware that it's a hinge.",
                    door: door(
                        "lydia-never-broken",
                        "Entry One, Your Building",
                        "Something near you has worked every single day for years and has never once been mended, oiled, replaced, or thanked. A catch, a hinge, a tap, a stair. Lydia is keeping an inventory of these and yours is not in it.",
                        "What is it, and how long has it been getting away with that?",
                        ["undertaking-door", "objects", "ordinary", "anywhere", "immediate"]
                    )
                ),
                stage(
                    "resistance",
                    "Three faculty tell her these things are not magic. She writes down their names too.",
                    "A page headed 'Objections', longer than the entries.",
                    ["argument", "record", "faculty"],
                    scene: """
                        "That is maintenance," says the third one. "Not magic. Maintenance."

                        "Nothing's been maintained."

                        "Then it's a well-made hinge."

                        "Made by whom?"

                        He makes the face of a man declining to be drawn, and goes back to his soup.

                        Lydia turns to the back of the ledger, where she has ruled a fresh page and headed it OBJECTIONS, and writes his name under the other two. The objections now run longer than the entries.
                        """,
                    deniability: "Three people have told me it isn't magic. None of them would say what it is."
                ),
                stage(
                    "trade",
                    "Trencher trades her a cookbook for the entry on the soup vat that is always exactly enough.",
                    "Two books swapped on a kitchen counter, neither party thanking the other.",
                    ["food", "friendship", "objects"],
                    castIDs: ["ambrose-trencher"],
                    scene: """
                        "It's never once run out," Lydia says. "Not in the record. Not once."

                        Trencher wipes his hands. "It's a big vat."

                        "It's the wrong size for ninety. I've measured it." She has the ledger open on the counter at entry nineteen. "I want it written down properly. I want to know how you fill it."

                        He looks at the ledger for a moment. Then he goes away, and comes back with a water-damaged cookbook, and sets it on the counter beside it.

                        Neither of them says thank you. Both books change hands.
                        """,
                    deniability: "The vat is the right size. Ask the vat."
                ),
                stage(
                    "lost-page",
                    "The page on the hinge goes missing. The hinge stops working the same week.",
                    "A gap in a numbered ledger, and a door that now creaks.",
                    ["strange", "loss", "objects"],
                    scene: """
                        Entry one is gone.

                        Not torn out — the ledger is sewn, and the stitching is whole, and the numbering runs one, two, three without interruption in her own handwriting. There is simply no hinge in it.

                        Lydia walks to the east door and opens it.

                        It shrieks.

                        She stands holding it open, and the sound goes on longer than the movement does, and she writes nothing down, because there is now nowhere to write it.
                        """,
                    deniability: "A page is mislaid. Pages are mislaid. The door is a coincidence."
                ),
                stage(
                    "maintenance",
                    "She concludes that the unglamorous magic works because somebody was quietly maintaining it. She does not name who.",
                    "A ledger closed, and a fresh oil can appearing where it is needed.",
                    ["ordinary", "care", "conclusion"],
                    scene: """
                        She works it out at the bottom of a column of things that never break: every one of them is a thing nobody has ever been seen looking after.

                        "So who oils them," she says, out loud, in an empty corridor.

                        The corridor does not answer.

                        Lydia closes the ledger. On her way out she leaves a new oil can on the sill by the east door, label facing out, where it can be seen.

                        In the morning it has been moved four inches and used.
                        """,
                    deniability: "I keep an inventory. I don't keep the building."
                )
            ]
        ),
        "dr-inkrest": (
            title: "Premature Conclusions",
            pursuit: "Collect the Academy's confident readings and check them a year later.",
            why: "Inkrest suspects that most insight is only impatience wearing a good coat.",
            stages: [
                stage(
                    "gather",
                    "She starts a drawer of confident statements, each dated, each sealed.",
                    "A drawer labelled only with a year, already too full.",
                    ["record", "patience", "judgement"],
                    scene: """
                        "Say that again," says Inkrest.

                        "I said it's obvious." The young man is enjoying himself. "It's completely obvious what it means."

                        "Write it down."

                        He writes it down. She holds out an envelope; he puts it in; she seals it in front of him and writes the date on the front and nothing else.

                        "When do you open it?"

                        "Not soon," says Inkrest, and puts it in the drawer, which does not close on the first try.
                        """,
                    deniability: "It's a drawer of envelopes. Nobody is on trial."
                ),
                stage(
                    "first-open",
                    "The first envelope is opened. The confident reading was wrong in an interesting way.",
                    "An envelope reopened and annotated in a second, later ink.",
                    ["record", "mistake", "time"],
                    scene: """
                        The date on the front has come round, so she opens it.

                        She reads it. Then she reads it again with her head on one side.

                        It is wrong. Not wrong in the ordinary way, where somebody guessed and missed — wrong in the shape of the thing it missed. You could take the sentence and turn it over and have something true.

                        Inkrest finds a different pen, a darker one, and writes underneath: *nearly, and from the wrong end.*
                        """
                ),
                stage(
                    "own-hand",
                    "She finds one of the envelopes is in her own handwriting.",
                    "A sealed envelope set aside, unopened for a long while.",
                    ["fault", "honesty", "self"],
                    scene: """
                        She is working through the drawer by date when she reaches one where the writing on the front is hers.

                        She turns it over. Sealed. Her seal.

                        She does not remember it, which is not the same as it not having happened, and she knows that difference better than anyone in the building.

                        Inkrest sets it on the corner of the desk, squared to the edge, and does not open it. A fortnight later it is still there. It is still squared to the edge.
                        """,
                    deniability: "There is an envelope on my desk. I am aware of the envelope."
                ),
                stage(
                    "opened-anyway",
                    "She opens it anyway, in front of a witness, and reads it aloud.",
                    "A witness leaving an office quieter than they entered.",
                    ["repair", "honesty", "witness"],
                    castIDs: ["zara-finch"],
                    scene: """
                        "Why me?" says Zara.

                        "Because you'll let me finish." Inkrest breaks the seal.

                        She reads it out, all of it. It takes under a minute. It is a confident statement about a person, made eleven years ago, in her own hand, and it was wrong about them in a way that cost them something.

                        She puts it down.

                        "Do you want me to say anything," Zara says.

                        "No," says Inkrest. "I want you to have heard it."

                        Zara goes out considerably more quietly than she came in.
                        """
                ),
                stage(
                    "later-drawer",
                    "She starts a second drawer. This one is for things she is not sure about.",
                    "Two drawers now, the uncertain one filling faster.",
                    ["patience", "conclusion", "humility"],
                    scene: """
                        The label takes her a while, because all the obvious words are wrong.

                        She settles on: NOT YET.

                        Within a month the second drawer is fuller than the first, and it is only ever her own handwriting going into it, and she has stopped sealing those.

                        A student asks what the difference between the drawers is.

                        "That one's what people were sure of," says Inkrest. "This one's the useful one."
                        """,
                    deniability: "Two drawers. One is larger. That is all that has happened."
                )
            ]
        ),
        "dr-vellum": (
            title: "The Unmeasured Variable",
            pursuit: "Find the thing that keeps ruining otherwise excellent data.",
            why: "Vellum's models are correct, which is why their failures are so interesting.",
            stages: [
                stage(
                    "residual",
                    "A residual keeps appearing in the Tuesday figures and refuses to be noise.",
                    "A chart with one Tuesday circled, four weeks running.",
                    ["data", "pattern", "puzzle"],
                    scene: """
                        "Noise," says Vellum, to the chart.

                        The chart has four Tuesdays on it and all four are wrong in the same direction by roughly the same amount, which is not what noise does.

                        They circle the fourth one. Then, after a moment, they go back and circle the other three as well, so that anybody passing the desk can see the shape of it without being told.

                        Nobody passes the desk. The chart stays up for eleven days.
                        """,
                    deniability: "It's a residual. Residuals happen. This one happens on Tuesdays."
                ),
                stage(
                    "controls",
                    "Every control is added. The residual gets larger, which should not be possible.",
                    "A whiteboard with more crossings-out than equations.",
                    ["data", "puzzle", "frustration"],
                    scene: """
                        Weather in. Attendance in. Term week, room temperature, who was teaching, whether it rained before eleven.

                        The residual gets bigger.

                        Vellum stops with the marker held up and does not write the next thing.

                        "That's not how controls work," says the postgraduate, from the doorway.

                        "No," says Vellum.

                        They both look at the board, which is now more crossings-out than equations, and neither of them offers a next step.
                        """,
                    deniability: "The model is sound. I'd like that said first."
                ),
                stage(
                    "lunch",
                    "The residual is lunch. Specifically, it is whether Trencher made soup.",
                    "A dataset with a new column titled, tersely, SOUP.",
                    ["food", "data", "discovery"],
                    scene: """
                        It is the postgraduate who says it, and she says it as a joke.

                        "It's Tuesdays. Soup's Tuesdays."

                        Vellum does not laugh. Vellum goes very quiet, and pulls up the kitchen board photographs by date, all of them, and lines them against the Tuesdays.

                        Soup. Soup. No soup — and there, the one Tuesday the residual behaves itself.

                        They add a column to a dataset that has been running for four years, and title it, because there is nothing else to title it: SOUP.
                        """,
                    deniability: "There is a column. I am not going to pretend there isn't a column."
                ),
                stage(
                    "refusal",
                    "Vellum refuses to publish a finding that reduces a meal to a coefficient.",
                    "An unfinished paper left face-down on a desk for weeks.",
                    ["ethics", "data", "refusal"],
                    scene: """
                        The number is 0.31 and it is the strongest thing in the model.

                        "Publish it," says the postgraduate. "It's the finding."

                        Vellum reads their own sentence back aloud: *the provision of a hot midday meal accounts for* —

                        They stop reading. They turn the page face-down on the desk.

                        "It's true," she says.

                        "It's true," Vellum agrees, and does not turn it back over, and it is still face-down on that desk the following month.
                        """
                ),
                stage(
                    "both-true",
                    "The finding is published with the coefficient and the sentence 'this is not what it meant to them'.",
                    "A published table with one footnote longer than the table.",
                    ["data", "meaning", "conclusion"],
                    scene: """
                        The compositor calls it a problem. "Footnotes go under the table. This one's longer than the table."

                        "Then the table is short," says Vellum.

                        It goes out with the coefficient in it, 0.31, and underneath, set in the same size type, a footnote of some length which ends: *this is not what it meant to them.*

                        The paper is cited fourteen times in its first year. Twelve of them use the number. Two of them quote the footnote.
                        """,
                    deniability: "The number is the number. The footnote is also the paper."
                )
            ]
        ),
        "zara-finch": (
            title: "The Chapter That Will Not Start",
            pursuit: "Write the first line of the Great Unwritten Chapter herself.",
            why: "Zara has guided a hundred readers to the threshold and has never once crossed it.",
            stages: [
                stage(
                    "blank",
                    "She sits down to write the first line and writes the date instead.",
                    "A page with only a date on it, kept anyway.",
                    ["words", "threshold", "fear"],
                    scene: """
                        Zara has been sitting with the pen touching the paper long enough that the ink has made a small dark bloom where it rests.

                        She has brought a hundred and six readers to this exact table and told every one of them to simply begin.

                        She writes the date.

                        She looks at the date.

                        She does not tear the page out. She squares it, and puts it at the bottom of the drawer face up, and goes to teach a class on beginnings.
                        """
                ),
                stage(
                    "borrowed",
                    "She tries starting with somebody else's sentence. It will not hold her weight.",
                    "A quotation copied out and then heavily scored through.",
                    ["words", "borrowed", "attempt"],
                    scene: """
                        She copies it out in full — somebody else's first line, the best one she knows — to see whether it will get her moving.

                        It sits there on the page being magnificent and having nothing whatever to do with her.

                        She writes her own second sentence underneath it. The join shows. She writes it again. The join shows.

                        Zara puts the pen down, picks it up, and scores the borrowed line out so thoroughly that the nib goes through the paper in two places.
                        """,
                    deniability: "I copy things out. It's a recognised exercise."
                ),
                stage(
                    "ordinary",
                    "She writes about a bus she missed. It is the first thing that stays on the page.",
                    "A short paragraph about a bus, folded small.",
                    ["ordinary", "words", "honesty"],
                    scene: """
                        What she writes, at twenty past eleven, having given up, is that she missed the 4 and stood there nineteen minutes and it was fine.

                        Then she writes what the light was doing on the shelter.

                        Then she writes that a man asked her whether the 4 had gone, and she said yes, and he said well, and stayed anyway.

                        She reads it back, and her hand stops on the way to scoring it out.

                        She folds it very small and puts it in her pocket instead.
                        """
                ),
                stage(
                    "shown",
                    "She shows it to nobody, then shows it to Trencher, who reads it and puts food down.",
                    "A folded paper left on a kitchen counter overnight and returned unmentioned.",
                    ["friendship", "unsaid", "words"],
                    castIDs: ["ambrose-trencher"],
                    scene: """
                        She does not intend to show anyone. She goes to the kitchen at half nine because the kitchen is empty at half nine, and Trencher is in it.

                        She puts the folded paper on the counter without saying what it is.

                        He dries his hands first. He reads it standing up, all the way through, twice.

                        Then he sets it back down on the counter, and puts a bowl beside it, and turns round and carries on with the pans.

                        Neither of them mentions the paper. She eats all of it.
                        """
                ),
                stage(
                    "second-line",
                    "She writes the second line. This turns out to have been the hard one all along.",
                    "A page with two lines on it, and room left underneath.",
                    ["words", "threshold", "beginning"],
                    scene: """
                        The first line goes down at last, and it is not magnificent. It is about a bus.

                        She sits back, pleased, and reaches for the next one, and finds nothing there at all.

                        An hour goes by.

                        What she eventually writes is six words long and it makes the first line mean something it did not mean on its own.

                        Zara reads the two of them together. Then she leaves the rest of the page empty, and closes the book on it, and goes to bed while it is still true.
                        """,
                    deniability: "Two lines. I'd rather not discuss the ratio."
                )
            ]
        ),
        "orion-blackthorn": (
            title: "The Instrument That Disagrees",
            pursuit: "Find out why one instrument in the observatory reads differently from all the others.",
            why: "Orion would rather have one honest disagreement than nine agreeable confirmations.",
            stages: [
                stage(
                    "outlier",
                    "The old brass instrument reads two degrees off. It has read two degrees off since before anyone here was born.",
                    "A logbook with the same correction written a thousand times.",
                    ["sky", "instrument", "record"],
                    scene: """
                        Orion reads all nine of them off in order and writes the numbers up, and the ninth is two degrees out, as it has been every night this month.

                        He goes back through the logbook. 1974: minus two. 1953: minus two. 1911, in an ink gone brown: minus two.

                        A thousand people have written the same correction in the same margin and not one of them wrote down why.

                        "Well," Orion says to the brass one. "You've been consistent."
                        """,
                    deniability: "The instrument disagrees. Disagreement is not an error.",
                    door: door(
                        "orion-two-degrees",
                        "Two Things That Disagree",
                        "Two things near you measure the same quantity and do not agree: a clock against a phone, an oven against a thermometer, a forecast against a window. Orion would like to know which one you believe.",
                        "Which two disagreed, and which did you trust?",
                        ["undertaking-door", "instrument", "ordinary", "anywhere", "immediate"]
                    )
                ),
                stage(
                    "calibrate",
                    "He calibrates it correctly. It goes back to being wrong within a week.",
                    "A calibration certificate, and beneath it, the old correction resumed.",
                    ["instrument", "stubborn", "puzzle"],
                    scene: """
                        It takes two days and a man from the county, and at the end of it the brass instrument agrees with the other eight exactly.

                        Orion pins the certificate up over the desk.

                        On the Thursday it is off by half a degree. On the Saturday, one and a half.

                        On the Monday he writes minus two in the margin, in his own hand, directly beneath a certificate stating that the instrument is correct, and leaves both of them where they are.
                        """,
                    deniability: "It was calibrated. There is paper. The paper has not changed."
                ),
                stage(
                    "older-map",
                    "An older map shows the observatory two degrees from where it stands now.",
                    "A map with a building in the wrong place, and no record of a move.",
                    ["place", "strange", "history"],
                    scene: """
                        The map is 1840 and it lives in a drawer of maps nobody opens.

                        Orion holds it up against the current survey, and the observatory is not where the observatory is.

                        He measures the difference twice, because the first answer is absurd.

                        It is two degrees.

                        He sits down on the floor of the map room with both sheets across his knees and stays there long enough that somebody comes to ask whether he is unwell.
                        """
                ),
                stage(
                    "nobody-moved",
                    "Nothing was moved. He checks this four times and then stops checking.",
                    "A set of measurements abandoned mid-column.",
                    ["strange", "unease", "instrument"],
                    scene: """
                        The foundations are original. The stone is original. The bolt holes have one set of bolts in them and always have.

                        He checks the ledger of works: nothing. He checks the minutes: nothing. He checks the ledger again in case he missed it, and he has not missed it.

                        The fourth column of measurements stops halfway down the page.

                        Orion sets the pencil beside it and does not pick it up again that night. The column is still unfinished a year later.
                        """,
                    deniability: "Nothing was moved. I have checked. I would rather leave it there."
                ),
                stage(
                    "keeps-it",
                    "He stops correcting it. He writes 'the instrument is not the thing that is wrong' in the log.",
                    "A logbook where the corrections simply stop, one day, without explanation.",
                    ["sky", "acceptance", "strange"],
                    scene: """
                        The eight agree with each other and the ninth does not, and Orion has stopped assuming that is nine against one.

                        He writes the nine readings down as they came.

                        Then, where a hundred years of margin says minus two, he writes: *the instrument is not the thing that is wrong.*

                        He does not explain it. He rules the page off and starts the next night's readings underneath, and the margin stays empty from there on.
                        """,
                    deniability: "I have stopped correcting it. That is not the same as agreeing with it."
                )
            ]
        ),
        "headmistress-thorne": (
            title: "The Unlisted Room",
            pursuit: "Remove one room from the Academy's official plan without removing the room.",
            why: "Thorne has her reasons. She does not offer them, and nobody has yet been rude enough to ask.",
            stages: [
                stage(
                    "plan",
                    "A new floor plan is issued. It is correct in every respect but one.",
                    "A floor plan with a corridor that runs slightly too long.",
                    ["rules", "place", "quiet"],
                    scene: """
                        "Sign here, Headmistress, and here."

                        Thorne reads the plan properly, which the Bursar has not seen anybody do before.

                        She stops at the second floor. Her finger comes to rest on a corridor.

                        "This is right?"

                        "Surveyed twice."

                        "Mm," says Thorne, and signs, and hands it back — and the corridor on the second floor runs eleven feet longer on paper than a corridor with those rooms off it could possibly run.
                        """,
                    deniability: "The plan was surveyed twice. I signed what I was given."
                ),
                stage(
                    "noticed",
                    "One student notices. The plan is reissued, and the student is thanked warmly.",
                    "A revised plan, and a note of thanks that answers nothing.",
                    ["authority", "quiet", "unsettling"],
                    scene: """
                        The girl has done the arithmetic in the margin of the plan itself, in pencil, and brought it to the office.

                        "Eleven feet," she says. "There's eleven feet that isn't anything."

                        Thorne looks at the pencil for slightly too long.

                        "How clever of you," she says warmly, and means it. "That is exactly the sort of thing we want noticed."

                        A revised plan goes up on Friday with the corridor the right length. The girl receives a note of thanks on headed paper, which thanks her and says nothing else at all.
                        """,
                    deniability: "A student found an error. The error was corrected. I thanked her."
                ),
                stage(
                    "key",
                    "A key exists for a door that the plan says is a wall.",
                    "A key on the board with no label, which nobody takes down.",
                    ["strange", "authority", "threshold"],
                    scene: """
                        The key board by the porter's desk has eighty-one hooks and eighty of them are labelled.

                        "That one?" the new porter asks.

                        The old porter does not look up. "Leave it."

                        "What's it for?"

                        "It's been there longer than me."

                        The new porter takes it down, because he is new. It is heavy and quite plain, and the shaft is worn bright, which is what happens to a key that gets used.

                        He puts it back. He does not mention it to anybody, and neither does the old porter.
                        """
                ),
                stage(
                    "dust",
                    "The dust outside that wall is disturbed on a regular schedule.",
                    "Clean floor in a shape nobody can account for.",
                    ["strange", "place", "evidence"],
                    castIDs: ["wicker-eddies"],
                    scene: """
                        Wicker has been lying on the second-floor corridor with a candle at floor level for most of the afternoon.

                        "There," he says. "Get your eye along it."

                        Pippa lies down.

                        Dust everywhere, evenly, wall to wall — except for a rectangle at the far end, swept clean, about the width of a door, the sweep marks running the wrong way for anybody standing in the corridor.

                        "Something opens," says Wicker.

                        "Something closes," says Pippa.
                        """,
                    deniability: "The floors are cleaned. I employ people to clean the floors."
                ),
                stage(
                    "unasked",
                    "The room stays off the plan. It is now the only room everybody knows about.",
                    "A wall that people walk around rather than past.",
                    ["authority", "strange", "open-secret"],
                    scene: """
                        Nobody has asked her. Three hundred people in this building know, and not one of them has come and asked her.

                        Thorne stands at the end of the second-floor corridor with her hands behind her back and watches two students come round the corner, see the end wall, and take the long way to the stairs without appearing to decide to.

                        She waits until they are gone.

                        Then she says, to the wall, pleasantly: "You are becoming conspicuous."
                        """,
                    deniability: "There is no room. I would have it on the plan."
                )
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
    /// A concluded ladder keeps a short aftermath date for existing world
    /// pressure, but the authored scenes themselves are one-shot.
    static let restDaysAfterConcluding = 9
    /// A trail can go cold rather than marching neatly to its conclusion.
    static let stallChancePercent = 14

    static func seeded(existing: [CastUndertaking], now: Date) -> [CastUndertaking] {
        var result = existing
        for ladder in CastUndertakingRegistry.allLadders {
            // A ladder's scenes are a finite piece of history, not a renewable
            // template. Each one seeds once, ever: a new internal generation ID
            // must never make the same prose look new. A successor arrives as
            // genuinely new authored business with new beat identities, either
            // in the registry or posted by a pack.
            guard !result.contains(where: { $0.resolvedLadderID == ladder.id }) else { continue }
            // Installing a pack must not backdate business onto a reader who
            // has already finished that character's story; it simply begins.
            result.append(CastUndertaking(
                id: "undertaking-\(ladder.id)",
                actorID: ladder.actorID,
                title: ladder.title,
                pursuit: ladder.pursuit,
                why: ladder.why,
                stages: ladder.stages,
                stageIndex: 0,
                status: .active,
                startedAt: now,
                lastAdvancedAt: now,
                nextEligibleAt: nextEligible(after: now, seed: "\(ladder.id)-start"),
                ladderID: ladder.id
            ))
        }
        return result
    }

    /// How strongly the world steers toward where things are already happening.
    /// This is the whole convergence mechanism: rather than waiting for three
    /// independent threads to coincide by chance, which, measured over 180
    /// simulated days, happens never: the world simply prefers to advance
    /// business that is adjacent to business already underway. Institutions
    /// behave this way. Things pile up where things are already piling up.
    static let heatBias = 3

    /// The same trick as `heatBias`, for business bound to a running event.
    static let eventHeatBias = 3

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
        hotActorIDs: Set<String> = [],
        events: UndertakingEventContext = .none
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

        // While an event is running, the business bound to it moves faster. The
        // month should look like it reached the whole Academy rather than only
        // the event's own Pages.
        if !events.isEmpty {
            let bound = eligible.filter { index in
                events.isLive(
                    CastUndertakingRegistry.ladder(withID: result[index].resolvedLadderID)?.eventID
                )
            }
            if !bound.isEmpty, bound.count < eligible.count {
                eligible += Array(repeating: bound, count: max(0, eventHeatBias - 1)).flatMap { $0 }
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

// MARK: - What the reader has actually met
//
// Undertakings advanced on the world clock long before this existed, and beats
// reached the desk by picking uniformly from every running thread. With ten
// threads running and a beat advancing every one to four days, that meant a
// reader met beat one of a thread and then, statistically, beat four: the
// Academy had business, but it never had episodes. Nothing about the simulation
// was wrong; the selection simply had no memory of what the reader had seen.
//
// This is that memory, and it is deliberately about *witness* rather than
// occurrence. It records nothing when a beat is minted during world-clock
// catch-up. It
// records only when a beat actually reached a reader, which is why a run can
// continue at all: continuation is defined against what they saw, not against
// what happened while the app was shut.

/// Which of the Academy's threads the reader has been following, and how far.
struct UndertakingSerial: Codable, Equatable {
    static let currentVersion = 2

    /// After this long, resuming mid-ladder stops being a continuation and
    /// starts being a stranger halfway through a sentence.
    static let continuationWindowDays: Double = 10

    /// Enough to keep a season's worth of beats from repeating, bounded so the
    /// vault does not accumulate a life's history of the Academy.
    static let rememberedBeatLimit = 80

    var version: Int = currentVersion
    /// The thread whose beat the reader most recently met.
    var lastThreadID: String?
    var lastStageIndex: Int?
    var lastMetAt: Date?
    /// Beats already presented, so the same one is never served twice. Ordered
    /// oldest-first; trimmed from the front.
    var rememberedBeats: [String] = []
    /// Authored scene identities already presented. This is separate from an
    /// undertaking occurrence ID so a legacy duplicate generation cannot make
    /// identical prose appear new.
    var rememberedStoryBeats: [String] = []
    /// How many beats of the current thread the reader has met in a row. Kept
    /// for the record and for tests; nothing gates on it, because the ladder's
    /// own pacing already spaces a run out over days.
    var runLength: Int = 0

    init() {}

    /// Tolerate a payload written before any given field existed. The serial is
    /// bookkeeping about witness: a missing field means the reader had not met
    /// anything yet, which is a perfectly good starting state and never a reason
    /// to fail a whole vault load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        lastThreadID = try container.decodeIfPresent(String.self, forKey: .lastThreadID)
        lastStageIndex = try container.decodeIfPresent(Int.self, forKey: .lastStageIndex)
        lastMetAt = try container.decodeIfPresent(Date.self, forKey: .lastMetAt)
        rememberedBeats = try container.decodeIfPresent([String].self, forKey: .rememberedBeats) ?? []
        rememberedStoryBeats = try container.decodeIfPresent([String].self, forKey: .rememberedStoryBeats) ?? []
        runLength = try container.decodeIfPresent(Int.self, forKey: .runLength) ?? 0
    }

    static func beatKey(undertakingID: String, stageIndex: Int) -> String {
        "\(undertakingID)#\(stageIndex)"
    }

    func hasMet(undertakingID: String, stageIndex: Int) -> Bool {
        rememberedBeats.contains(Self.beatKey(undertakingID: undertakingID, stageIndex: stageIndex))
    }

    func hasMetAnyBeat(ofThread undertakingID: String) -> Bool {
        rememberedBeats.contains { $0.hasPrefix("\(undertakingID)#") }
    }

    static func storyBeatKey(actorID: String, stageID: String) -> String {
        "\(actorID)#\(stageID)"
    }

    func hasMetStoryBeat(_ storyBeatID: String) -> Bool {
        rememberedStoryBeats.contains(storyBeatID)
    }

    func isWithinContinuationWindow(of now: Date) -> Bool {
        guard let lastMetAt else { return false }
        return now.timeIntervalSince(lastMetAt) <= Self.continuationWindowDays * 86_400
    }

    /// The reader met a beat. This is the only thing that writes the serial.
    mutating func met(
        undertakingID: String,
        stageIndex: Int,
        storyBeatID: String? = nil,
        at date: Date
    ) {
        let key = Self.beatKey(undertakingID: undertakingID, stageIndex: stageIndex)
        if !rememberedBeats.contains(key) {
            rememberedBeats.append(key)
            if rememberedBeats.count > Self.rememberedBeatLimit {
                rememberedBeats.removeFirst(rememberedBeats.count - Self.rememberedBeatLimit)
            }
        }
        if let storyBeatID, !rememberedStoryBeats.contains(storyBeatID) {
            rememberedStoryBeats.append(storyBeatID)
            if rememberedStoryBeats.count > Self.rememberedBeatLimit {
                rememberedStoryBeats.removeFirst(rememberedStoryBeats.count - Self.rememberedBeatLimit)
            }
        }
        // A run is consecutive beats of the same thread, in order, close enough
        // together to still read as the same story.
        let continues = lastThreadID == undertakingID && isWithinContinuationWindow(of: date)
        runLength = continues ? runLength + 1 : 1
        lastThreadID = undertakingID
        lastStageIndex = stageIndex
        lastMetAt = date
    }
}

/// Which world events are running right now, and how far through.
///
/// Small on purpose: the Academy's own business and the monthly events stay
/// separate systems that one field connects. An event never owns a ladder and a
/// ladder never drives an event — the affinity only tilts what the world
/// advances and what the desk chooses, which is the whole integration.
struct UndertakingEventContext: Equatable {
    /// Event ID to the phase it is currently in.
    var phaseByEventID: [String: String]

    static let none = UndertakingEventContext(phaseByEventID: [:])

    init(phaseByEventID: [String: String] = [:]) {
        self.phaseByEventID = phaseByEventID
    }

    /// Built from whatever the world is actually running right now.
    init(activeWorldEvents: [ResolvedWorldEvent]) {
        phaseByEventID = Dictionary(
            activeWorldEvents.map { ($0.id, $0.phase.id) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var isEmpty: Bool { phaseByEventID.isEmpty }

    func isLive(_ eventID: String?) -> Bool {
        guard let eventID else { return false }
        return phaseByEventID[eventID] != nil
    }

    func phase(of eventID: String?) -> String? {
        guard let eventID else { return nil }
        return phaseByEventID[eventID]
    }

    /// Whether a beat is being held back for its phase. Only ever true while its
    /// event is actually running.
    func holdsBack(stage: CastUndertakingStage, eventID: String?) -> Bool {
        guard let wanted = stage.phaseID, let current = phase(of: eventID) else { return false }
        return wanted != current
    }
}

enum UndertakingSerialEngine {
    /// How strongly the desk prefers a thread the reader already knows over one
    /// they have never met. Expressed as repetition rather than score so the
    /// pick stays a single deterministic modulo and every candidate remains
    /// reachable — the same trick `CastUndertakingEngine.heatBias` uses.
    static let recognitionWeight = 3

    /// A thread the reader has never met is easier to join near its beginning.
    /// The world itself may already be much farther on: this weight affects only
    /// which scene the Book opens, never occurrence or sideways consequences.
    static let openingStageIndex = 1
    static let openingWeight = 2

    /// Which beat of the Academy's own business this slot should carry.
    ///
    /// Order of preference:
    /// 1. The next unseen available scene from the thread the reader is already
    ///    following, if it has not gone stale. This is the run.
    /// 2. A weighted pick that leans toward threads they recognise and toward
    ///    beats near the start of a ladder.
    /// 3. Nothing. A reader who has met every available beat gets no
    ///    world-business page this slot, and the desk goes back to being about
    ///    them — which is correct: the Academy has nothing new to report.
    /// How strongly a live world event pulls the desk toward business bound to
    /// it. A season should feel like it is happening to the whole Academy, not
    /// only in the event's own Pages.
    static let eventAffinityWeight = 4

    static func nextBeat(
        among undertakings: [CastUndertaking],
        serial: UndertakingSerial,
        slotID: String,
        now: Date,
        events: UndertakingEventContext = .none
    ) -> CastUndertaking? {
        // Recover story identities from v1 occurrence keys without rewriting
        // the vault. This also collapses any duplicate generations an older
        // build may already have seeded.
        var metStoryBeats = Set(serial.rememberedStoryBeats)
        for undertaking in undertakings {
            for index in undertaking.stages.indices
                where serial.hasMet(undertakingID: undertaking.id, stageIndex: index) {
                metStoryBeats.insert(UndertakingSerial.storyBeatKey(
                    actorID: undertaking.actorID,
                    stageID: undertaking.stages[index].id
                ))
            }
        }

        // The world clock remains authoritative. A projection may only open a
        // scene that has already happened, and it never mutates the undertaking
        // backwards. Consequences can therefore reach letters, the Bleed, radio,
        // shops, or notes before the scene itself. The reader simply discovers
        // the next piece when the Book has room for it; no unread count or
        // missed badge. A larger middle gap may be gathered later into one
        // ordinary Gossip Page, but that is a presentation choice downstream.
        let projected = undertakings.compactMap { undertaking -> CastUndertaking? in
            guard !undertaking.stages.isEmpty else { return nil }
            // Most business belongs to no event at all, which is not a reason
            // to withhold it.
            let eventID = CastUndertakingRegistry
                .ladder(withID: undertaking.resolvedLadderID)?.eventID
            let upperBound = min(undertaking.stageIndex, undertaking.stages.count - 1)
            guard upperBound >= 0,
                  let index = (0...upperBound).first(where: { stageIndex in
                      let stage = undertaking.stages[stageIndex]
                      // A beat waiting for its phase is not offered yet.
                      if events.holdsBack(stage: stage, eventID: eventID) { return false }
                      let storyBeatID = UndertakingSerial.storyBeatKey(
                          actorID: undertaking.actorID,
                          stageID: stage.id
                      )
                      return !metStoryBeats.contains(storyBeatID)
                          && !serial.hasMet(undertakingID: undertaking.id, stageIndex: stageIndex)
                  }) else { return nil }
            var copy = undertaking
            copy.stageIndex = index
            return copy
        }

        // Prefer the earliest occurrence if a legacy vault already contains
        // duplicate generations of the same authored ladder. Story identity,
        // not occurrence ID, is what makes prose new.
        var uniqueByStoryBeat: [String: CastUndertaking] = [:]
        for undertaking in projected {
            guard let stage = undertaking.currentStage else { continue }
            let storyBeatID = UndertakingSerial.storyBeatKey(
                actorID: undertaking.actorID,
                stageID: stage.id
            )
            if let existing = uniqueByStoryBeat[storyBeatID],
               existing.startedAt <= undertaking.startedAt {
                continue
            }
            uniqueByStoryBeat[storyBeatID] = undertaking
        }
        let unmet = uniqueByStoryBeat.values.sorted { $0.id < $1.id }
        guard !unmet.isEmpty else { return nil }

        if let followed = serial.lastThreadID,
           serial.isWithinContinuationWindow(of: now),
           let next = unmet.first(where: { $0.id == followed }) {
            return next
        }

        var weighted: [CastUndertaking] = []
        for undertaking in unmet {
            var weight = 1
            if serial.hasMetAnyBeat(ofThread: undertaking.id) { weight += recognitionWeight }
            if undertaking.stageIndex <= openingStageIndex { weight += openingWeight }
            // Business bound to a running event belongs to this month.
            let eventID = CastUndertakingRegistry
                .ladder(withID: undertaking.resolvedLadderID)?.eventID
            if events.isLive(eventID) { weight += eventAffinityWeight }
            weighted += Array(repeating: undertaking, count: weight)
        }
        return weighted[abs("\(slotID)|world-business".stableHash) % weighted.count]
    }
}

// MARK: - Doors through the covers

/// Which of the Academy's unfinished business is currently standing open to the
/// reader's own day.
///
/// A door opens only after its beat has actually reached them. That ordering is
/// the whole effect: the fiction has to have happened first, or the errand is
/// just a prompt with a costume on. It also means a door can never arrive for a
/// scene the reader has not read, and never arrives on the same Page as the
/// scene — the scene stays a scene.
enum UndertakingDoorEngine {
    struct OpenDoor: Equatable {
        var actorID: String
        var door: UndertakingDoor
    }

    /// Doors whose beat the reader has met, newest business first.
    ///
    /// Nothing here tracks refusal. A door the reader ignores simply stays open
    /// and takes its turn in the mission pool like anything else, which is what
    /// "declining costs nothing" has to mean mechanically as well as tonally.
    static func open(
        in undertakings: [CastUndertaking],
        serial: UndertakingSerial
    ) -> [OpenDoor] {
        var found: [OpenDoor] = []
        var seen = Set<String>()
        for undertaking in undertakings.sorted(by: { $0.id < $1.id }) {
            for index in undertaking.stages.indices {
                let stage = CastUndertakingRegistry.authored(
                    undertaking.stages[index],
                    actorID: undertaking.actorID
                )
                guard let door = stage.door else { continue }
                // Story identity, not occurrence: a re-seeded ladder must not
                // reopen a door the reader already answered.
                let storyBeat = UndertakingSerial.storyBeatKey(
                    actorID: undertaking.actorID,
                    stageID: stage.id
                )
                let met = serial.rememberedStoryBeats.contains(storyBeat)
                    || serial.hasMet(undertakingID: undertaking.id, stageIndex: index)
                guard met, seen.insert(door.id).inserted else { continue }
                found.append(OpenDoor(actorID: undertaking.actorID, door: door))
            }
        }
        return found
    }
}

// MARK: - What the cast actually did
//
// The Academy's entire action vocabulary used to be three verbs and two
// relationship moves: act, invest, attack: warmed, cooled. That is a scoring
// system wearing character names, and it produced sentences like "Wicker lent
// some warmth to Penny; they grew closer," which describes a ledger entry
// rather than a thing a person did.
//
// An act is the thing a person did. The mechanical deltas ride underneath it
// unchanged, so nothing downstream has to be rewritten, but the page now says
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

    /// Whether the act moves Belief, and which way. Only a few acts do: most
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

    /// Acts that are genuinely ambiguous: kind and unkind at once, depending
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
/// the verbs are richer: it is that the same verb means something different in
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
    /// simulation wants: character holds against convenience.
    var refuses: Set<CastAct>
    /// The specific rendering, with `{target}` for the other person. This is
    /// the sentence that reaches the page.
    var renderings: [CastAct: String]
}

enum CastMannerCatalog {
    /// Hand-authored for the cast the reader actually meets. Everybody else
    /// falls back to the plain phrase, which is serviceable and unremarkable:
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

    /// The Cast Ledger's one-line entry for a relationship movement.
    ///
    /// It prefers the act already rendered for this turn: the ledger and the
    /// Gossip Page must describe the same event in the same words, and only
    /// invents one when the movement happened on the world clock with no page
    /// attached to it.
    static func ledgerLine(
        actorID: String,
        actorName: String,
        targetID: String,
        targetName: String,
        warming: Bool,
        alreadyPerformed: [CastActRecord],
        seed: String
    ) -> String {
        if let existing = alreadyPerformed.first(where: {
            $0.actorID == actorID && $0.targetID == targetID
        }) {
            return existing.line
        }
        let act = chooseAct(castID: actorID, seed: seed, warming: warming)
        return render(act: act, actorID: actorID, actorName: actorName, targetName: targetName)
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
    ///
    /// `warming` narrows the repertoire to acts that move the thread the right
    /// way, so a ledger entry that recorded warmth does not get illustrated by
    /// somebody taking credit for another person's work. Nil accepts anything.
    static func chooseAct(castID: String, seed: String, warming: Bool? = nil) -> CastAct {
        let directional = CastAct.allCases.filter { act in
            guard let warming else { return true }
            return warming ? act.relationshipDelta > 0 : act.relationshipDelta < 0
        }
        let candidates = directional
            .map { (act: $0, weight: weight($0, castID: castID)) }
            .filter { $0.weight > 0 }
            .sorted { $0.act.rawValue < $1.act.rawValue }
        guard !candidates.isEmpty else {
            // Everyone this person would do in that direction is refused. Fall
            // back to the mildest move that still points the right way.
            return warming == false ? .refuseToConcede : .concede
        }
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
//   1. `NarrativeEntityMemory`: what one character carries, in their own
//      frame. Private to them.
//   2. `CastActLedger`: the shared record of what happened. Objective, and
//      the same from either side.
//   3. the relationship field: the weighted edge, which is arithmetic.
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
    /// the target's is about what it cost or left them holding, which is
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
