import Foundation

enum StableWeightedRoll {
    static func pick<T>(from values: [T], seed: String, weight: (T) -> Int) -> T? {
        guard !values.isEmpty else { return nil }
        let weighted = values.map { value in
            (value, max(1, weight(value)))
        }
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return values.first }
        var bucket = Int(UInt(bitPattern: seed.stableHash) % UInt(total))
        for (value, tickets) in weighted {
            if bucket < tickets { return value }
            bucket -= tickets
        }
        return values.last
    }

    static func ordered<T>(from values: [T], seed: String, weight: (T) -> Int) -> [T] {
        var remaining = values.enumerated().map { (index: $0.offset, value: $0.element) }
        var result: [T] = []
        while !remaining.isEmpty {
            let drawSeed = "\(seed)-draw-\(result.count)"
            guard let selected = pick(from: remaining, seed: drawSeed, weight: { weight($0.value) }) else { break }
            result.append(selected.value)
            remaining.removeAll { $0.index == selected.index }
        }
        return result
    }
}

enum BeliefCombatParticipantKind: String, Codable, Equatable {
    case player
    case entity
    case npc
    case talisman
    case nothing
    case location
    case object
    case thread

    var floor: Int {
        switch self {
        case .player, .nothing:
            return 0
        case .entity, .npc, .talisman, .location, .object, .thread:
            return 5
        }
    }
}

enum BeliefCombatDifficulty: String, Codable, Equatable, CaseIterable {
    case routine
    case standard
    case dramatic
    case desperate

    var modifier: Int {
        switch self {
        case .routine:
            return 15
        case .standard:
            return 0
        case .dramatic:
            return -15
        case .desperate:
            return -25
        }
    }
}

enum BeliefCombatOutcome: String, Codable, Equatable {
    case criticalSuccess
    case success
    case nearMiss
    case failure
    case criticalFailure

    var title: String {
        switch self {
        case .criticalSuccess:
            return "critical success"
        case .success:
            return "success"
        case .nearMiss:
            return "near miss"
        case .failure:
            return "failure"
        case .criticalFailure:
            return "critical failure"
        }
    }
}

struct BeliefCombatResult: Codable, Equatable {
    var attackerName: String
    var attackerKind: BeliefCombatParticipantKind
    var targetName: String
    var targetKind: BeliefCombatParticipantKind
    var attackerBeliefBefore: Int
    var attackerBeliefAfter: Int
    var targetBeliefBefore: Int
    var targetBeliefAfter: Int
    var requestedSpend: Int
    var actualSpend: Int
    var dealt: Int
    var backlash: Int
    var roll: Int
    var threshold: Int
    var difficulty: BeliefCombatDifficulty
    var outcome: BeliefCombatOutcome

    var landed: Bool {
        dealt > 0
    }

    var summaryLine: String {
        if backlash > 0 {
            return "\(attackerName) pressed against \(targetName), but the pressure turned back on them."
        }
        if dealt > 0 {
            return "\(attackerName) found a weak place in \(targetName), and its Glow receded."
        }
        return "\(attackerName) tested \(targetName), but nothing gave way."
    }
}

enum BeliefCombatResolver {
    static func difficulty(forTargetBelief belief: Int) -> BeliefCombatDifficulty {
        switch belief {
        case ..<25:
            return .routine
        case ..<55:
            return .standard
        case ..<80:
            return .dramatic
        default:
            return .desperate
        }
    }

    static func baseThreshold(for belief: Int) -> Int {
        min(85, Int(40 + Double(max(0, min(100, belief))) * 0.45))
    }

    static func finalThreshold(for belief: Int, difficulty: BeliefCombatDifficulty) -> Int {
        max(20, min(90, baseThreshold(for: belief) + difficulty.modifier))
    }

    static func resolve(
        attackerName: String,
        attackerKind: BeliefCombatParticipantKind,
        attackerBelief: Int,
        targetName: String,
        targetKind: BeliefCombatParticipantKind,
        targetBelief: Int,
        spend requestedSpend: Int,
        difficulty: BeliefCombatDifficulty,
        roll: Int? = nil
    ) -> BeliefCombatResult {
        let attackerBelief = max(0, min(100, attackerBelief))
        let targetBelief = max(0, min(100, targetBelief))
        let spend = max(0, requestedSpend)
        let threshold = finalThreshold(for: attackerBelief, difficulty: difficulty)
        let roll = roll ?? Int.random(in: 1...100)
        let margin = roll - threshold
        let outcome: BeliefCombatOutcome
        if roll <= 5 {
            outcome = .criticalSuccess
        } else if roll >= 96 {
            outcome = .criticalFailure
        } else if roll <= threshold {
            outcome = margin >= -10 ? .nearMiss : .success
        } else {
            outcome = margin <= 10 ? .nearMiss : .failure
        }

        let rawDeal: Int
        switch outcome {
        case .criticalSuccess:
            rawDeal = max(1, Int((Double(spend) * 1.5).rounded()))
        case .success:
            rawDeal = spend
        case .nearMiss:
            rawDeal = max(1, Int((Double(spend) * 0.5).rounded()))
        case .failure:
            rawDeal = 0
        case .criticalFailure:
            rawDeal = -spend
        }

        let attackerFloor = attackerKind.floor
        let targetFloor = targetKind.floor
        let actualSpend = min(spend, max(0, attackerBelief - attackerFloor))
        let backfired = rawDeal < 0
        let backlash = backfired ? min(abs(rawDeal), max(0, attackerBelief - actualSpend - attackerFloor)) : 0
        let actualDeal = backfired ? 0 : min(rawDeal, max(0, targetBelief - targetFloor))
        let attackerAfter = max(attackerFloor, attackerBelief - actualSpend - backlash)
        let targetAfter = backfired ? targetBelief : max(targetFloor, targetBelief - actualDeal)

        return BeliefCombatResult(
            attackerName: attackerName,
            attackerKind: attackerKind,
            targetName: targetName,
            targetKind: targetKind,
            attackerBeliefBefore: attackerBelief,
            attackerBeliefAfter: attackerAfter,
            targetBeliefBefore: targetBelief,
            targetBeliefAfter: targetAfter,
            requestedSpend: spend,
            actualSpend: actualSpend,
            dealt: actualDeal,
            backlash: backlash,
            roll: roll,
            threshold: threshold,
            difficulty: difficulty,
            outcome: outcome
        )
    }
}

/// The narrative shape of a Story Page Inkbones result. A throw never blocks
/// the chosen turn from happening; it decides whether that turn lands cleanly,
/// catches, costs something, or reaches the scene by a stranger route.
enum StoryInkbonesBand: String, Codable, Equatable, CaseIterable {
    case triumph
    case favor
    case hesitate
    case cost
    case sideways

    static func resolve(roll: Int, threshold: Int) -> StoryInkbonesBand {
        if roll <= 5 { return .triumph }
        if roll >= 96 { return .cost }
        if roll <= threshold { return .favor }
        if roll <= threshold + 10 { return .hesitate }
        return .sideways
    }

    var outcome: String {
        switch self {
        case .triumph: return "The Inkbones crack the margin open"
        case .favor: return "The Inkbones favor the thread"
        case .hesitate: return "The Inkbones hesitate"
        case .cost: return "The Inkbones ask a cost"
        case .sideways: return "The Inkbones turn sideways"
        }
    }

    var texture: String {
        switch self {
        case .triumph: return "A rare bright fracture. The Story Page gets more permission than it asked for."
        case .favor: return "Belief catches. The page can move with a little extra warmth."
        case .hesitate: return "The thread holds, but the margin asks for a softer landing."
        case .cost: return "The page turns, but something in the ink keeps score."
        case .sideways: return "Not blocked. Not blessed. The answer arrives at an angle."
        }
    }

    /// Binding prose direction for the result writer. Every band preserves the
    /// committed landing while changing how that landing becomes true.
    var narrativeDirective: String {
        switch self {
        case .triumph:
            return "This is a rare bright fracture: the action succeeds beyond what was reached for. Grant the intent fully, then add one unexpected gift, opened door, or extra permission nobody asked for."
        case .favor:
            return "Clean success: the action lands as intended. Show the wanted change actually happening, warmly and concretely."
        case .hesitate:
            return "Success with friction: the action lands, but only just. Add a stumble, a delay, or a condition: someone hesitates, or something must be promised or said twice before it gives."
        case .cost:
            return "Success with a price: the action works, but something is visibly spent, broken, owed, or overheard. Name the cost inside the scene and let it hook a future beat."
        case .sideways:
            return "A sideways landing: the wanted change still arrives, but by an unexpected route: a different door, a different speaker, or a stranger answer than the one reached for."
        }
    }

    /// A deterministic last beat for builds that cannot wake the local writer.
    /// It is deliberately narrative rather than a success/failure label.
    var fallbackClosingLine: String {
        switch self {
        case .triumph: return "And the Inkbones gave more than was asked: whatever this touched now stands wider open than anyone meant it to."
        case .favor: return "The Inkbones favored it, and the thread takes the change cleanly."
        case .hesitate: return "But the Inkbones hesitated, so it only just holds: one more careful word will be owed before this sits easy."
        case .cost: return "But the Inkbones kept score: something in this scene is now spent or owed, and the margin will remember which."
        case .sideways: return "The Inkbones turned it sideways on the way in, so the change arrived by a stranger door than the one that was knocked on."
        }
    }

    fileprivate func isVisible(in prose: String) -> Bool {
        let prose = prose.lowercased()
        let signals: [String]
        switch self {
        case .triumph:
            signals = ["extra", "more than", "beyond", "another door", "second door", "wider open", "unexpected gift"]
        case .favor:
            // The committed-landing validator already proves clean success.
            return true
        case .hesitate:
            signals = ["hesitat", "only just", "again", "twice", "delay", "condition", "promise", "second attempt"]
        case .cost:
            signals = ["cost", "price", "spent", "broke", "broken", "owe", "owed", "debt", "overheard"]
        case .sideways:
            signals = ["sideways", "instead", "different door", "wrong door", "different speaker", "someone else", "unexpected route"]
        }
        return signals.contains { prose.contains($0) }
    }
}

/// Structured mechanic evidence kept separately from the Story Page's prose.
/// This prevents a raw roll summary from being mistaken for a finished result.
struct StoryInkbonesResolution: Codable, Equatable {
    var roll: Int
    var threshold: Int
    var band: StoryInkbonesBand

    init(roll: Int, threshold: Int) {
        let clampedRoll = min(100, max(1, roll))
        let clampedThreshold = min(100, max(1, threshold))
        self.roll = clampedRoll
        self.threshold = clampedThreshold
        self.band = StoryInkbonesBand.resolve(roll: clampedRoll, threshold: clampedThreshold)
    }

    var mechanicSummary: String {
        "Belief roll: \(roll) against \(threshold). \(band.outcome)."
    }

    func narrativePromptSection(committedLanding: String?, effectLine: String) -> String {
        let landing = committedLanding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? effectLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        INKBONES RESULT: already rolled and authoritative:
        \(mechanicSummary)
        The chosen turn still becomes true: \(landing.isEmpty ? "The selected action changes the scene in the way it promised." : landing)
        Required narrative shape: \(band.narrativeDirective)
        Dramatize that gift, friction, price, or sideways route inside the scene. Do not mention dice, rolls, thresholds, bands, mechanics, success, or failure in the finished prose.
        """
    }

    func fallbackConsequence(
        preparedResult: String,
        committedLanding: String?,
        effectLine: String
    ) -> String {
        var paragraphs: [String] = []
        let prepared = preparedResult.trimmingCharacters(in: .whitespacesAndNewlines)
        let landing = committedLanding?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let effect = effectLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if !prepared.isEmpty {
            paragraphs.append(prepared)
        } else if !landing.isEmpty {
            paragraphs.append(landing)
        } else if !effect.isEmpty {
            paragraphs.append(effect)
        } else {
            paragraphs.append("The chosen action changes the scene, and the new state holds.")
        }
        if !landing.isEmpty,
           !paragraphs.joined(separator: " ").localizedCaseInsensitiveContains(landing) {
            paragraphs.append(landing)
        }
        if !paragraphs.joined(separator: " ").localizedCaseInsensitiveContains(band.fallbackClosingLine) {
            paragraphs.append(band.fallbackClosingLine)
        }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Keeps good generated prose intact. If the writer honored the committed
    /// landing but missed the roll's special shape, add the deterministic beat
    /// rather than collapsing the whole answer back to mechanics.
    func ensuringNarrativeBand(in prose: String) -> String {
        let prose = prose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prose.isEmpty else { return band.fallbackClosingLine }
        guard !band.isVisible(in: prose) else { return prose }
        return prose + "\n\n" + band.fallbackClosingLine
    }
}

enum BookJumpAction: String, Codable, Equatable, CaseIterable {
    case start
    case advance
    case stabilize
    case `return`

    var title: String {
        switch self {
        case .start: return "Open the Spine"
        case .advance: return "Go one page deeper"
        case .stabilize: return "Stabilize the page"
        case .return: return "Find the Spine"
        }
    }
}

struct BookJumpWork: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var author: String
    var gutenbergID: String
    var world: String
    var arrival: String
    var nothing: String
    var rules: [String]
    var resonances: [String]

    var gutenbergURL: String {
        "https://www.gutenberg.org/ebooks/\(gutenbergID)"
    }
}

struct BookJumpBeat: Identifiable, Codable, Equatable {
    var id: String
    var at: Date
    var action: BookJumpAction
    var depth: Int
    var degradation: Int
    var line: String
}

struct ActiveBookJump: Identifiable, Codable, Equatable {
    var id: String
    var bookID: String
    var title: String
    var author: String
    var gutenbergID: String
    var world: String
    var arrival: String
    var nothing: String
    var rules: [String]
    var resonances: [String]
    var anchor: String
    var intention: String
    var guide: String
    var startedAt: Date
    var updatedAt: Date
    var depth: Int
    var returnCount: Int
    var degradation: Int
    var souvenirDue: Bool
    var beats: [BookJumpBeat]
    /// The StoryChoiceRole the reader picked to reach the current depth, so the
    /// next beat can honor the direction they chose. Optional for migration.
    var lastDirection: String?
}

struct ReturnedBookJump: Identifiable, Codable, Equatable {
    var id: String
    var bookID: String
    var title: String
    var author: String
    var returnedAt: Date
    var depth: Int
    var degradation: Int
    var souvenir: String
    var outcome: String
}

/// A rule carried back from a book, active for a few days, with a real,
/// cross-system effect: Book Jumping's answer to a Fae gift.
enum BorrowedRuleEffect: String, Codable, Equatable, CaseIterable {
    case sharpenNotices   // the small detail is loud → Book Notices / patterns surface
    case warmRecords      // keep records → Diary & Souvenir glow warmer
    case pushBackNothing   // tend / mercy / growth → the grey holds back a shade
    case warmTheCast      // companionship → relationship field warms on grant
    case steadyTheBody    // healing / home → Body, Rest, Center lean forward
    case openWonder       // curiosity / imagination → Wonder Compass leans forward

    var title: String {
        switch self {
        case .sharpenNotices: return "A Sharpened Eye"
        case .warmRecords: return "Keep Records"
        case .pushBackNothing: return "Tend What Answers Slowly"
        case .warmTheCast: return "Travel With Companions"
        case .steadyTheBody: return "Mend the Walled Garden"
        case .openWonder: return "Answer Nonsense Sideways"
        }
    }

    /// How it bends the feed while it's active. (warmTheCast applies once, at grant.)
    var surfaceBoosts: [BookPageType: Int] {
        switch self {
        case .sharpenNotices: return [.bookNotices: 8, .marginsAtlas: 4]
        case .warmRecords: return [.diary: 6, .souvenir: 6]
        case .pushBackNothing: return [:]
        case .warmTheCast: return [.illustration: 4, .letter: 4]
        case .steadyTheBody: return [.body: 6, .rest: 6]
        case .openWonder: return [.wonderCompass: 8]
        }
    }

    var greyShift: Int { self == .pushBackNothing ? -1 : 0 }
}

struct BorrowedRule: Identifiable, Codable, Equatable {
    var id: String
    var bookID: String
    var bookTitle: String
    var text: String
    var effect: BorrowedRuleEffect
    var grantedAt: Date
    var expiresAt: Date

    func isActive(at date: Date) -> Bool { date < expiresAt }
}

struct BookJumpState: Codable, Equatable {
    var active: ActiveBookJump?
    var returned: [ReturnedBookJump]
    var borrowedRules: [BorrowedRule]
    var coldBooks: [String: Date]   // bookID -> the date the book reopens

    init(
        active: ActiveBookJump? = nil,
        returned: [ReturnedBookJump] = [],
        borrowedRules: [BorrowedRule] = [],
        coldBooks: [String: Date] = [:]
    ) {
        self.active = active
        self.returned = returned
        self.borrowedRules = borrowedRules
        self.coldBooks = coldBooks
    }

    func activeBorrowedRules(at date: Date) -> [BorrowedRule] {
        borrowedRules.filter { $0.isActive(at: date) }
    }

    func isCold(_ bookID: String, at date: Date) -> Bool {
        guard let until = coldBooks[bookID] else { return false }
        return date < until
    }
}

enum BookJumpEngine {
    static let startCost = 3
    static let returnReward = 2
    static let maxDepth = 4
    static let borrowedRuleDays = 4
    static let coldDays = 5

    /// Going one beat deeper costs escalating Belief; Routine charges rent on depth.
    static func advanceCost(depth: Int) -> Int { min(3, max(1, depth - 1)) }

    /// Returning pays the base reward plus a bonus for how deep you dared, but
    /// only when you bring a real souvenir home.
    static func returnReward(depth: Int, hasSouvenir: Bool) -> Int {
        guard hasSouvenir else { return 0 }
        return min(BeliefEconomyPolicy.compassRunReward - 1, returnReward + max(0, depth - 1))
    }

    static let publicDomainShelf: [BookJumpWork] = [
        BookJumpWork(
            id: "alice-wonderland",
            title: "Alice's Adventures in Wonderland",
            author: "Lewis Carroll",
            gutenbergID: "11",
            world: "a bright impossible country where logic wears gloves and every rule has teeth",
            arrival: "You land beside a corridor of doors, with the sound of a rabbit-sized hurry somewhere ahead.",
            nothing: "The Rut of Routine appears as blank labels, jokes without punchlines, and paths that forget where they were going.",
            rules: ["Do not argue with dream-logic; answer it sideways.", "Size, time, and manners are unstable.", "The Spine hides where nonsense suddenly becomes exact."],
            resonances: ["curiosity", "small adventures", "confusion", "play"]
        ),
        BookJumpWork(
            id: "wizard-oz",
            title: "The Wonderful Wizard of Oz",
            author: "L. Frank Baum",
            gutenbergID: "55",
            world: "a road-colored country where homesickness, courage, tenderness, and cleverness keep putting on costumes",
            arrival: "You step onto yellow bricks still warm from a storm that has already decided it is part of the story.",
            nothing: "The Rut of Routine comes as color draining from the road and companions forgetting what they were looking for.",
            rules: ["Travel works better with companions.", "What is missing may already be present.", "Follow the road, but do not mistake it for the whole map."],
            resonances: ["home", "companionship", "courage", "wonder"]
        ),
        BookJumpWork(
            id: "pride-prejudice",
            title: "Pride and Prejudice",
            author: "Jane Austen",
            gutenbergID: "1342",
            world: "a drawing-room labyrinth where weather, manners, money, and misread glances alter destinies",
            arrival: "You arrive just outside a lit room where every pause has already been noticed.",
            nothing: "The Rut of Routine wears the face of certainty: first impressions hardening before anyone can revise them.",
            rules: ["Listen twice before concluding once.", "A room can be more dangerous than a road.", "The Spine hides in revised judgment."],
            resonances: ["attention", "misreading", "wit", "second chances"]
        ),
        BookJumpWork(
            id: "frankenstein",
            title: "Frankenstein; Or, The Modern Prometheus",
            author: "Mary Wollstonecraft Shelley",
            gutenbergID: "84",
            world: "a cold, brilliant world of ambition, loneliness, lightning, and responsibility",
            arrival: "You wake under a high, pale sky with mountains watching like witnesses.",
            nothing: "The Rut of Routine gathers wherever maker and made refuse to recognize one another.",
            rules: ["Do not confuse creation with care.", "Loneliness distorts every corridor.", "The Spine hides near responsibility accepted too late."],
            resonances: ["responsibility", "loneliness", "making", "mercy"]
        ),
        BookJumpWork(
            id: "dracula",
            title: "Dracula",
            author: "Bram Stoker",
            gutenbergID: "345",
            world: "a world of letters, trains, thresholds, folk protections, and old hunger learning modern routes",
            arrival: "You enter at a threshold after sunset; every document nearby seems to know it may become evidence.",
            nothing: "The Rut of Routine moves as invitation without consent and fog that edits the edges of memory.",
            rules: ["Keep records; records keep you.", "Thresholds matter.", "The Spine hides in shared evidence."],
            resonances: ["boundaries", "letters", "protection", "night"]
        ),
        BookJumpWork(
            id: "christmas-carol",
            title: "A Christmas Carol",
            author: "Charles Dickens",
            gutenbergID: "46",
            world: "a candlelit moral weather system where memory, present kindness, and possible futures argue by apparition",
            arrival: "You arrive in a room where the fire has an opinion and the clock sounds slightly haunted.",
            nothing: "The Rut of Routine appears as a locked heart and a future no one speaks kindly of.",
            rules: ["Memory is a door, not a prison.", "Small mercies change the temperature.", "The Spine hides where a future can still turn."],
            resonances: ["mercy", "memory", "winter", "change"]
        ),
        BookJumpWork(
            id: "sherlock-holmes",
            title: "The Adventures of Sherlock Holmes",
            author: "Arthur Conan Doyle",
            gutenbergID: "1661",
            world: "a gaslit city of clues, habits, disguises, and rooms where one overlooked detail holds the hinge",
            arrival: "You arrive near a window with rain on it and a problem pretending to be ordinary.",
            nothing: "The Rut of Routine hides in assumptions so tidy they stop the eye from looking again.",
            rules: ["Observe before explaining.", "The small detail is often the loudest witness.", "The Spine hides in the fact that does not fit."],
            resonances: ["attention", "mystery", "patterns", "evidence"]
        ),
        BookJumpWork(
            id: "secret-garden",
            title: "The Secret Garden",
            author: "Frances Hodgson Burnett",
            gutenbergID: "113",
            world: "a walled, breathing place where neglected things remember how to grow",
            arrival: "You find a locked garden wall and the smell of earth deciding whether to trust you.",
            nothing: "The Rut of Routine appears as neglect: rooms unaired, gates unopened, living things not spoken to.",
            rules: ["Growth is quiet before it is visible.", "Tend what answers slowly.", "The Spine hides where a locked place becomes shared."],
            resonances: ["healing", "gardens", "friendship", "return"]
        ),
        BookJumpWork(
            id: "treasure-island",
            title: "Treasure Island",
            author: "Robert Louis Stevenson",
            gutenbergID: "120",
            world: "a salt-stung world of maps, bargains, mutiny, courage, and voices too charming to trust completely",
            arrival: "You arrive with the smell of tar and tide in the air and a map trying not to rustle.",
            nothing: "The Rut of Routine comes as greed: every landmark flattened into what can be taken from it.",
            rules: ["Maps reveal and conceal.", "Charm is not safety.", "The Spine hides where courage refuses the easy bargain."],
            resonances: ["adventure", "maps", "risk", "loyalty"]
        ),
        BookJumpWork(
            id: "moby-dick",
            title: "Moby-Dick; Or, The Whale",
            author: "Herman Melville",
            gutenbergID: "2701",
            world: "a vast salt scripture of obsession, labor, jokes, omens, and terrible whiteness",
            arrival: "You arrive with deck-planks underfoot and the sea rewriting every certainty in grey-green ink.",
            nothing: "The Rut of Routine wears obsession: one symbol swollen until it erases the rest of the world.",
            rules: ["Do not let one sign devour all others.", "Shipmates are context.", "The Spine hides in the thing you can still notice besides the whale."],
            resonances: ["water", "obsession", "work", "awe"]
        ),
        BookJumpWork(
            id: "don-quixote",
            title: "Don Quixote",
            author: "Miguel de Cervantes",
            gutenbergID: "996",
            world: "a road of tilting certainties where imagination makes trouble and sometimes mercy",
            arrival: "You arrive on a road where dust, dignity, and bad interpretations are already traveling together.",
            nothing: "The Rut of Routine appears when enchantment becomes a refusal to see what is really there.",
            rules: ["Imagination needs a witness.", "Names change what courage thinks it is doing.", "The Spine hides where wonder and reality agree to share a saddle."],
            resonances: ["imagination", "ordinary magic", "roads", "companionship"]
        ),
        BookJumpWork(
            id: "odyssey",
            title: "The Odyssey",
            author: "Homer",
            gutenbergID: "1727",
            world: "a sea-road of longing, hospitality, monsters, cleverness, and home seen from too far away",
            arrival: "You arrive at the edge of a wine-dark crossing with a shore behind you and another refusing to come closer.",
            nothing: "The Rut of Routine comes as forgetting: names, homes, oaths, and the shape of return.",
            rules: ["Hospitality is magic with rules.", "Cleverness has a cost.", "The Spine hides where return becomes more than arrival."],
            resonances: ["homecoming", "travel", "cleverness", "sea"]
        )
    ]

    static func work(id: String) -> BookJumpWork? {
        publicDomainShelf.first { $0.id == id }
    }

    /// A constellation the reader is drawing through the public stacks: a book
    /// they keep returning to, or a family of resonances repeating across books.
    static func companionLine(state: BookJumpState) -> String? {
        let successful = state.returned.filter { !$0.souvenir.isEmpty }
        guard successful.count >= 2 else { return nil }

        let byBook = Dictionary(grouping: successful, by: \.bookID)
        if let (bookID, visits) = byBook.first(where: { $0.value.count >= 2 }) {
            let title = visits.first?.title ?? work(id: bookID)?.title ?? "this book"
            return "You and \(title) keep meeting: a constellation is forming between your real life and its pages."
        }

        // A repeated resonance family across different books.
        var familyCounts: [String: Int] = [:]
        for jump in successful {
            for resonance in (work(id: jump.bookID)?.resonances ?? []) {
                familyCounts[resonance, default: 0] += 1
            }
        }
        if let (family, count) = familyCounts.max(by: { $0.value < $1.value }), count >= 3 {
            return "A constellation of \(family) is gathering across the books you've visited."
        }
        return nil
    }

    static func selectWork(day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> BookJumpWork {
        let context = contextText(day: day, inputs: inputs)
        // A book that collapsed recently stays shut until it warms back.
        let openShelf = publicDomainShelf.filter { !inputs.bookJump.isCold($0.id, at: now) }
        let shelf = openShelf.isEmpty ? publicDomainShelf : openShelf
        let scores = shelf.map { work -> (BookJumpWork, Int) in
            let overlap = work.resonances.reduce(0) { total, term in
                total + (context.contains(term.lowercased()) ? 18 : 0)
            }
            let priorReturns = inputs.bookJump.returned.filter { $0.bookID == work.id }.count
            let jitter = abs("\(day.id)-\(work.id)-\(Calendar.current.component(.day, from: now))".stableHash) % 13
            return (work, overlap - priorReturns * 10 + jitter)
        }
        return scores.sorted { left, right in
            if left.1 == right.1 { return left.0.title < right.0.title }
            return left.1 > right.1
        }.first?.0 ?? publicDomainShelf[0]
    }

    static func surface(for state: BookJumpState, day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date, manual: Bool = false) -> SurfacePage {
        if let active = state.active {
            // The default beat climbs deeper; the reader can fork to Find the
            // Spine (return) from depth 2 on, via the page's own controls. The
            // Nothing forces a stabilize when it gets loud, and the book has a
            // floor at max depth.
            let action: BookJumpAction
            if active.degradation >= 3 {
                action = .stabilize
            } else if active.depth >= maxDepth {
                action = .return
            } else {
                action = .advance
            }
            return activeSurface(active, action: action, day: day, score: manual ? 72 : activeScore(active, action: action, context: context), now: now)
        }

        let work = selectWork(day: day, inputs: inputs, now: now)
        return startSurface(work: work, day: day, inputs: inputs, score: manual ? 68 : 58, now: now)
    }

    /// Starts a shelf-selected jump without discarding the reader's prior Jump
    /// history, borrowed rules, or books already resting after a choice-driven
    /// collapse. This mirrors `startCustom`, which has always opened into the
    /// existing ledger.
    static func start(
        from surface: SurfacePage,
        into state: BookJumpState = BookJumpState(),
        now: Date = Date()
    ) -> BookJumpState {
        let metadata = surface.payload.metadata
        let workID = metadata["bookID"] ?? "alice-wonderland"
        let work = self.work(id: workID) ?? publicDomainShelf[0]
        let anchor = metadata["bookJumpAnchor"] ?? "one true detail from today"
        let intention = metadata["bookJumpIntention"] ?? "bring back a sentence that still belongs to real life"
        let guide = metadata["bookJumpGuide"] ?? "the Book"
        let active = ActiveBookJump(
            id: metadata["bookJumpID"] ?? "jump-\(work.id)-\(Int(now.timeIntervalSince1970))",
            bookID: work.id,
            title: work.title,
            author: work.author,
            gutenbergID: work.gutenbergID,
            world: work.world,
            arrival: work.arrival,
            nothing: work.nothing,
            rules: work.rules,
            resonances: work.resonances,
            anchor: anchor,
            intention: intention,
            guide: guide,
            startedAt: now,
            updatedAt: now,
            depth: 1,
            returnCount: 0,
            degradation: 0,
            souvenirDue: false,
            beats: [
                BookJumpBeat(
                    id: "beat-start-\(Int(now.timeIntervalSince1970))",
                    at: now,
                    action: .start,
                    depth: 1,
                    degradation: 0,
                    line: "Entered \(work.title) with \(guide) as guide."
                )
            ],
            lastDirection: nil
        )
        var updated = state
        updated.active = active
        return updated
    }

    static func advance(_ state: BookJumpState, line: String, direction: String? = nil, now: Date = Date()) -> BookJumpState {
        guard var active = state.active else { return state }
        active.depth = min(maxDepth, active.depth + 1)
        // The deeper you are, the more rent Routine charges per page.
        active.degradation = min(4, active.degradation + (active.depth >= 2 ? 1 : 0))
        active.souvenirDue = active.depth >= 2
        active.lastDirection = direction
        active.updatedAt = now
        active.beats.append(BookJumpBeat(
            id: "beat-advance-\(Int(now.timeIntervalSince1970))-\(active.depth)",
            at: now,
            action: .advance,
            depth: active.depth,
            degradation: active.degradation,
            line: line.isEmpty ? "Went one page deeper." : line
        ))
        var updated = state
        updated.active = active
        return updated
    }

    static func stabilize(_ state: BookJumpState, line: String, now: Date = Date()) -> BookJumpState {
        guard var active = state.active else { return state }
        active.degradation = max(0, active.degradation - 2)
        active.updatedAt = now
        active.beats.append(BookJumpBeat(
            id: "beat-stabilize-\(Int(now.timeIntervalSince1970))",
            at: now,
            action: .stabilize,
            depth: active.depth,
            degradation: active.degradation,
            line: line.isEmpty ? "Stabilized the page by naming one true thing." : line
        ))
        var updated = state
        updated.active = active
        return updated
    }

    static func `return`(_ state: BookJumpState, souvenir: String, outcome: String, now: Date = Date()) -> BookJumpState {
        guard var active = state.active else { return state }
        active.returnCount += 1
        active.updatedAt = now
        let trimmedSouvenir = souvenir.trimmingCharacters(in: .whitespacesAndNewlines)
        let returned = ReturnedBookJump(
            id: "return-\(active.id)-\(Int(now.timeIntervalSince1970))",
            bookID: active.bookID,
            title: active.title,
            author: active.author,
            returnedAt: now,
            depth: active.depth,
            degradation: active.degradation,
            souvenir: trimmedSouvenir,
            outcome: outcome.isEmpty ? "Returned through the Spine." : outcome
        )
        var updated = state
        updated.active = nil
        updated.returned = ([returned] + state.returned).prefix(24).map { $0 }

        // Carry one of the book's rules home, active for a few days, with a real
        // effect, but only when a true souvenir came back with you.
        updated.borrowedRules = activeRules(in: state.borrowedRules, at: now)
        if !trimmedSouvenir.isEmpty,
           let ruleText = borrowableRule(from: active.rules) {
            let rule = BorrowedRule(
                id: "rule-\(active.bookID)-\(Int(now.timeIntervalSince1970))",
                bookID: active.bookID,
                bookTitle: active.title,
                text: ruleText,
                effect: effect(resonances: active.resonances),
                grantedAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: borrowedRuleDays, to: now) ?? now.addingTimeInterval(Double(borrowedRuleDays) * 86_400)
            )
            // One borrowed rule per book at a time; a fresh return refreshes it.
            updated.borrowedRules.removeAll { $0.bookID == rule.bookID }
            updated.borrowedRules = (([rule] + updated.borrowedRules).prefix(6)).map { $0 }
        }
        return updated
    }

    /// The Rut of Routine collapses an unstabilized jump: you slip back empty-handed,
    /// lose the Belief you staked, and that book goes cold for a while.
    static func collapse(_ state: BookJumpState, now: Date = Date()) -> (state: BookJumpState, lostBelief: Int, bookTitle: String) {
        guard let active = state.active else { return (state, 0, "") }
        let lost = max(1, active.depth)
        let collapsed = ReturnedBookJump(
            id: "collapse-\(active.id)-\(Int(now.timeIntervalSince1970))",
            bookID: active.bookID,
            title: active.title,
            author: active.author,
            returnedAt: now,
            depth: active.depth,
            degradation: active.degradation,
            souvenir: "",
            outcome: "The page dissolved into Routine; you slipped back with empty hands."
        )
        var updated = state
        updated.active = nil
        updated.returned = ([collapsed] + state.returned).prefix(24).map { $0 }
        updated.coldBooks[active.bookID] = Calendar.current.date(byAdding: .day, value: coldDays, to: now) ?? now.addingTimeInterval(Double(coldDays) * 86_400)
        updated.borrowedRules = activeRules(in: state.borrowedRules, at: now)
        return (updated, lost, active.title)
    }

    /// Performs time-based housekeeping without treating time away from the app
    /// as a failed choice. An active jump waits at exactly the depth and
    /// stability where the reader left it; only explicit Jump actions can raise
    /// its story stakes. The legacy result shape remains for save/UI migration.
    static func dailyDecay(_ state: BookJumpState, now: Date = Date()) -> (state: BookJumpState, collapsed: Bool, lostBelief: Int, bookTitle: String) {
        var updated = state
        updated.borrowedRules = activeRules(in: state.borrowedRules, at: now)
        return (updated, false, 0, "")
    }

    private static func activeRules(in rules: [BorrowedRule], at date: Date) -> [BorrowedRule] {
        rules.filter { $0.isActive(at: date) }
    }

    /// The first practical rule of a book (not the "Spine hides…" meta-rule) is
    /// the one you can carry home.
    static func borrowableRule(from rules: [String]) -> String? {
        rules.first { !$0.lowercased().contains("spine") } ?? rules.first
    }

    static func effect(resonances rawResonances: [String]) -> BorrowedRuleEffect {
        let resonances = Set(rawResonances.map { $0.lowercased() })
        if resonances.contains(where: { ["attention", "patterns", "mystery", "evidence", "misreading", "wit"].contains($0) }) { return .sharpenNotices }
        if resonances.contains(where: { ["letters", "boundaries", "records", "protection", "night"].contains($0) }) { return .warmRecords }
        if resonances.contains(where: { ["mercy", "healing", "gardens", "change", "memory", "winter"].contains($0) }) { return .pushBackNothing }
        if resonances.contains(where: { ["companionship", "home", "homecoming", "loyalty", "friendship", "courage"].contains($0) }) { return .warmTheCast }
        if resonances.contains(where: { ["return", "work", "responsibility", "awe"].contains($0) }) { return .steadyTheBody }
        return .openWonder
    }

    /// Active borrowed rules bend the feed the way the Almanac's feasts do.
    static func surfaceBoosts(state: BookJumpState, now: Date = Date()) -> [BookPageType: Int] {
        var boosts: [BookPageType: Int] = [:]
        for rule in state.activeBorrowedRules(at: now) {
            for (type, amount) in rule.effect.surfaceBoosts {
                boosts[type, default: 0] += amount
            }
        }
        return boosts
    }

    static func greyShift(state: BookJumpState, now: Date = Date()) -> Int {
        state.activeBorrowedRules(at: now).reduce(0) { $0 + $1.effect.greyShift }
    }

    /// The open shelf: turn any title the reader names into an improvised door.
    /// We never claim to know the book's text: the Book improvises a threshold
    /// and lets the live prose do the rest.
    static func improvisedWork(title rawTitle: String, author rawAuthor: String, gutenbergID rawID: String) -> BookJumpWork? {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let author = rawAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let gutenbergID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = title.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { lower.contains($0) } }
        let resonances: [String]
        if has(["sea", "ocean", "island", "ship", "voyage", "tide"]) { resonances = ["water", "travel", "risk"] }
        else if has(["garden", "wood", "forest", "wild", "tree"]) { resonances = ["healing", "gardens", "return"] }
        else if has(["love", "heart", "manners", "marriage"]) { resonances = ["attention", "second chances", "wit"] }
        else if has(["ghost", "dark", "night", "haunt", "fear", "shadow"]) { resonances = ["boundaries", "night", "protection"] }
        else if has(["war", "city", "crime", "mystery", "detective"]) { resonances = ["attention", "patterns", "evidence"] }
        else { resonances = ["curiosity", "imagination", "story"] }

        return BookJumpWork(
            id: "open-\(slug(title))",
            title: title,
            author: author.isEmpty ? "an unnamed hand" : author,
            gutenbergID: gutenbergID,
            world: "a book you named yourself: \(title): whose weather I haven't read but agree to enter with you",
            arrival: "The Spine opens onto \(title). I step in beside you, reading as I go.",
            nothing: "The Rut of Routine here is whatever this book most fears forgetting; name a true thing and it loses its grip.",
            rules: ["Carry one true detail from real life as ballast.", "Let the book lead; you keep the way back.", "The Spine hides where the borrowed world and your real one rhyme."],
            resonances: resonances
        )
    }

    /// Open an improvised door directly (the reader pasted a title), bypassing
    /// the curated-shelf surface.
    static func startCustom(work: BookJumpWork, anchor: String, intention: String, guide: String, into state: BookJumpState, now: Date = Date()) -> BookJumpState {
        let active = ActiveBookJump(
            id: "jump-\(work.id)-\(Int(now.timeIntervalSince1970))",
            bookID: work.id,
            title: work.title,
            author: work.author,
            gutenbergID: work.gutenbergID,
            world: work.world,
            arrival: work.arrival,
            nothing: work.nothing,
            rules: work.rules,
            resonances: work.resonances,
            anchor: anchor.isEmpty ? "one true detail from today" : anchor,
            intention: intention.isEmpty ? "bring back a sentence that still belongs to real life" : intention,
            guide: guide.isEmpty ? "the Book" : guide,
            startedAt: now,
            updatedAt: now,
            depth: 1,
            returnCount: 0,
            degradation: 0,
            souvenirDue: false,
            beats: [BookJumpBeat(id: "beat-start-\(Int(now.timeIntervalSince1970))", at: now, action: .start, depth: 1, degradation: 0, line: "Entered \(work.title) through an improvised door.")],
            lastDirection: nil
        )
        var updated = state
        updated.active = active
        return updated
    }

    private static func slug(_ text: String) -> String {
        let allowed = text.lowercased().map { ch -> Character in
            ch.isLetter || ch.isNumber ? ch : "-"
        }
        return String(allowed).split(separator: "-").prefix(5).joined(separator: "-")
    }

    private static func startSurface(work: BookJumpWork, day: BookDay, inputs: BookSourceInputs, score: Int, now: Date) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookJump)
        let anchor = startAnchor(day: day, inputs: inputs)
        let intention = startIntention(day: day, inputs: inputs)
        let guide = startGuide(inputs: inputs)
        let companion = companionLine(state: inputs.bookJump)
        let companionParagraph = companion.map { "\n\($0)\n" } ?? ""
        let body = """
        The Book has found a public-domain door: \(work.title), by \(work.author).

        \(work.arrival)
        \(companionParagraph)
        Anchor: \(anchor)
        Intention: \(intention)
        Guide: \(guide)

        Keeping this page lends the door some Belief and opens a controlled Book Jump. You remain yourself. The page takes one step only.
        """
        return SurfacePage(
            id: "\(source.id)-start-\(work.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .bookJump,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: score,
            reason: "There's an old, free-to-share book close enough to take one safe little jump into.",
            prompt: "Book Jump: \(work.title)",
            detail: "Hop into a real old story for a moment. One beat, one anchor, one safe way back home.",
            payload: BookPagePayload(
                headline: "The Spine Opens",
                body: body,
                metadata: surfaceMetadata(work: work, action: .start, extra: [
                    "bookJumpID": "jump-\(work.id)-\(Int(now.timeIntervalSince1970))",
                    "bookJumpAnchor": anchor,
                    "bookJumpIntention": intention,
                    "bookJumpGuide": guide,
                    "bookJumpBeliefDelta": "-\(startCost)",
                    "bookJumpDepth": "0",
                    "bookJumpDegradation": "0",
                    "placeholder": "Optional: what do you want to bring back?",
                    "tags": "book-jump,book-jump:start,public-domain,\(work.id)"
                ])
            )
        )
    }

    private static func activeSurface(_ active: ActiveBookJump, action: BookJumpAction, day: BookDay, score: Int, now: Date) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookJump)
        let body: String
        switch action {
        case .advance:
            body = """
            You are inside \(active.title), at depth \(active.depth).

            \(active.world)

            Anchor: \(active.anchor)
            Intention: \(active.intention)
            Guide: \(active.guide)

            Keeping this page moves one beat deeper. The Rut of Routine pressure is \(active.degradation)/4.
            """
        case .stabilize:
            body = """
            The page is beginning to blur.

            \(active.nothing)

            Name one true real-world detail in the margin, then keep this page. The Book will use it as ballast and lower Routine pressure.
            """
        case .return:
            let possibleReward = returnReward(depth: active.depth, hasSouvenir: true)
            body = """
            The Spine is visible.

            You have gone deep enough into \(active.title). The Book wants one sentence from the journey before it closes the door.

            Write a one-sentence souvenir in the margin. Bringing it home restores \(possibleReward) Belief; returning empty-handed restores none.
            """
        case .start:
            body = active.arrival
        }

        return SurfacePage(
            id: "\(source.id)-\(action.rawValue)-\(active.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .bookJump,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: score,
            reason: reason(for: action, active: active),
            prompt: "\(action.title): \(active.title)",
            detail: detail(for: action, active: active),
            payload: BookPagePayload(
                headline: headline(for: action),
                body: body,
                metadata: surfaceMetadata(active: active, action: action, extra: [
                    "bookJumpBeliefDelta": action == .return
                        ? "\(returnReward(depth: active.depth, hasSouvenir: true))"
                        : (action == .advance ? "-\(advanceCost(depth: active.depth))" : "0"),
                    "bookJumpDepth": "\(active.depth)",
                    "bookJumpDegradation": "\(active.degradation)",
                    "bookJumpDirection": active.lastDirection ?? "",
                    "placeholder": action == .return ? "One sentence you brought back from the book." : "Optional: one true detail to steady the page.",
                    "tags": "book-jump,book-jump:\(action.rawValue),public-domain,\(active.bookID)"
                ])
            )
        )
    }

    private static func activeScore(_ active: ActiveBookJump, action: BookJumpAction, context: CuratorContext) -> Int {
        switch action {
        case .return:
            return 88
        case .stabilize:
            return 84
        case .advance:
            return context.distress.isActive ? 56 : min(76, 62 + active.depth * 4)
        case .start:
            return 58
        }
    }

    private static func reason(for action: BookJumpAction, active: ActiveBookJump) -> String {
        switch action {
        case .start:
            return "I've found a public-domain door."
        case .advance:
            return "\(active.title) is open and stable enough for one more beat."
        case .stabilize:
            return "The Rut of Routine is blurring the page; the jump needs ballast."
        case .return:
            return "The Spine is visible; the jump is ready to come home with a souvenir."
        }
    }

    private static func detail(for action: BookJumpAction, active: ActiveBookJump) -> String {
        switch action {
        case .start:
            return active.arrival
        case .advance:
            return "Depth \(active.depth). \(active.world)"
        case .stabilize:
            return "Nothing pressure \(active.degradation)/4. Name one real detail."
        case .return:
            return "Write a one-sentence souvenir and return through the Spine."
        }
    }

    private static func headline(for action: BookJumpAction) -> String {
        switch action {
        case .start: return "The Spine Opens"
        case .advance: return "One Page Deeper"
        case .stabilize: return "Hold the Page Still"
        case .return: return "Find the Spine"
        }
    }

    private static func surfaceMetadata(work: BookJumpWork, action: BookJumpAction, extra: [String: String]) -> [String: String] {
        var metadata = [
            "source": "book-jump",
            "bookJumpAction": action.rawValue,
            "bookID": work.id,
            "bookTitle": work.title,
            "bookAuthor": work.author,
            "gutenbergID": work.gutenbergID,
            "gutenbergURL": work.gutenbergURL,
            "bookWorld": work.world,
            "bookArrival": work.arrival,
            "bookNothing": work.nothing,
            "bookRules": work.rules.joined(separator: " | "),
            "privacy": "private local"
        ]
        if let canon = canonicalDetail[work.id] {
            metadata["bookLandmarks"] = canon.landmarks.joined(separator: " | ")
            metadata["bookOpeningScene"] = canon.openingScene
        }
        extra.forEach { metadata[$0.key] = $0.value }
        return metadata
    }

    /// Concrete, canonical furniture for each shelf book: the named places,
    /// figures, objects, and set-pieces the live scene must be built from, plus
    /// the specific scene the reader lands in mid-action on the first beat. This
    /// is what keeps a jump from going atmospheric-but-empty: the model is given
    /// real nouns to drop the reader among. Open-shelf books have no entry and
    /// fall back to the model's own knowledge of the named title.
    struct BookCanon { let landmarks: [String]; let openingScene: String }
    static let canonicalDetail: [String: BookCanon] = [
        "alice-wonderland": BookCanon(
            landmarks: ["the White Rabbit with his waistcoat and pocket-watch", "the hall of locked doors and the little golden key", "the 'DRINK ME' bottle and 'EAT ME' cake", "the Caterpillar on his mushroom with the hookah", "the Cheshire Cat's grin", "the Mad Hatter's endless tea-table", "the Queen of Hearts' croquet-ground of flamingos and hedgehogs"],
            openingScene: "the long hall after the fall down the rabbit-hole: too tall or too small, the tiny door to the garden, the glass table with the key just out of reach."),
        "wizard-oz": BookCanon(
            landmarks: ["the yellow brick road", "the Munchkins and the silver shoes", "the Scarecrow on his pole", "the Tin Woodman rusted in the forest", "the Cowardly Lion", "the field of deadly poppies", "the green glow of the Emerald City"],
            openingScene: "the moment the farmhouse settles in Munchkin Country and the door opens on impossible colour, the Good Witch and the silver shoes waiting, the road beginning at your feet."),
        "pride-prejudice": BookCanon(
            landmarks: ["the assembly-room ball at Meryton", "Mr. Darcy's cold first impression", "Elizabeth Bennet's quick eyes", "the drawing-rooms of Longbourn and Netherfield", "muddy hems from walking the fields", "candlelight, card-tables, and overheard remarks"],
            openingScene: "the crowded assembly ball: music and the press of muslin and broadcloth, a slighting remark just overheard across the room, every glance already being counted."),
        "frankenstein": BookCanon(
            landmarks: ["Victor's attic laboratory and its instruments", "the spark of unnatural life", "the creature's yellow eyes and yellow skin", "the Alpine ice of Mont Blanc and the sea of Chamonix", "lightning over the mountains", "the lonely creature watching from the cold"],
            openingScene: "the laboratory the night the thing first breathes: guttering candle, the dull yellow eye opening, Victor's horror as the creature's hand stirs."),
        "dracula": BookCanon(
            landmarks: ["the Borgo Pass and the calèche driven by red eyes", "Castle Dracula's crumbling battlements", "the Count's cold handshake and growing youth", "the three pale brides and their laughter", "the peasant woman's crucifix pressed into your hand", "Harker's locked journal", "wolves answering the Count: 'the children of the night'"],
            openingScene: "the castle courtyard at midnight after the long ride: the great door swinging open by no hand, the Count waiting on the stair with his candle, the howl of wolves behind you and the cold coming off the stone."),
        "christmas-carol": BookCanon(
            landmarks: ["Scrooge's cold counting-house and single coal", "Marley's chained ghost and clanking cash-boxes", "the Cratchit family's small dinner and Tiny Tim", "the Ghost of Christmas Past's steady flame", "the Ghost of Christmas Present's heaped feast", "the silent black-robed Ghost of Christmas Yet to Come", "the snowy London streets and church bells"],
            openingScene: "the freezing counting-house on Christmas Eve as the bells ring out, the fire mean and small, a door-knocker beginning, impossibly, to take on Marley's face."),
        "sherlock-holmes": BookCanon(
            landmarks: ["221B Baker Street's cluttered sitting-room", "the gasogene, the pipe, and the violin", "Holmes reading a stranger from mud and cuffs", "fog at the window and a hansom at the kerb", "a client unwinding an impossible problem", "the small overlooked detail that holds the case"],
            openingScene: "the Baker Street sitting-room as a rain-soaked client is shown in: Holmes already reading their boots and sleeve, Watson by the fire, a problem pretending to be ordinary laid on the table."),
        "secret-garden": BookCanon(
            landmarks: ["the locked walled garden and its buried key", "the robin who shows the way", "the hundred rooms of Misselthwaite Manor", "the cry heard down the corridors at night", "Dickon and his wild creatures", "green shoots breaking the cold soil"],
            openingScene: "the moment the key turns and the door in the wall swings in: the hushed, overgrown, half-dead garden no one has entered in ten years, a robin watching, the air deciding whether to trust you."),
        "treasure-island": BookCanon(
            landmarks: ["the Admiral Benbow inn and the old sea-chest", "the black spot", "Long John Silver and his parrot 'Pieces of eight!'", "the Hispaniola under sail", "the apple-barrel where the mutiny is overheard", "the island stockade and the buried cache", "Captain Flint's map with its red cross"],
            openingScene: "the deck of the Hispaniola at dusk near the island: the smell of tar and tide, and from inside the apple-barrel the low voices of Silver and the crew letting slip the word 'mutiny.'"),
        "moby-dick": BookCanon(
            landmarks: ["the Pequod bristling with whalebone", "Captain Ahab's ivory leg and burning stare", "the gold doubloon nailed to the mast", "Queequeg and his harpoon", "the try-works fires rendering blubber at night", "the white whale breaching", "the vast grey-green sea"],
            openingScene: "the deck of the Pequod as Ahab nails the gold doubloon to the mast and roars his oath against the white whale, the crew caught up in it, the sea heaving under a hard sky."),
        "don-quixote": BookCanon(
            landmarks: ["the windmills mistaken for giants", "the gaunt knight on Rocinante", "Sancho Panza on his donkey", "a roadside inn taken for a castle", "a barber's basin worn as a golden helmet", "the dusty plains of La Mancha"],
            openingScene: "the open plain where the windmills turn: the knight levelling his lance, certain they are giants, Sancho calling out the truth, the charge already beginning."),
        "odyssey": BookCanon(
            landmarks: ["the wine-dark sea and a battered raft", "the Cyclops Polyphemus and his cave of sheep", "Circe's hall and her cup", "the Sirens' song and the mast", "Scylla and Charybdis in the strait", "the longed-for shore of Ithaca", "the rule of guest-friendship"],
            openingScene: "a shore at the edge of the wine-dark sea, salt and smoke on the wind, a cave of penned sheep ahead and the ground trembling with something vast returning to it."),
    ]

    private static func surfaceMetadata(active: ActiveBookJump, action: BookJumpAction, extra: [String: String]) -> [String: String] {
        let work = BookJumpWork(
            id: active.bookID,
            title: active.title,
            author: active.author,
            gutenbergID: active.gutenbergID,
            world: active.world,
            arrival: active.arrival,
            nothing: active.nothing,
            rules: active.rules,
            resonances: []
        )
        return surfaceMetadata(work: work, action: action, extra: extra.merging([
            "bookJumpID": active.id,
            "bookJumpAnchor": active.anchor,
            "bookJumpIntention": active.intention,
            "bookJumpGuide": active.guide
        ]) { current, _ in current })
    }

    private static func contextText(day: BookDay, inputs: BookSourceInputs) -> String {
        let pageText = ([day] + Array(inputs.days.prefix(5)))
            .flatMap(\.pages)
            .suffix(20)
            .map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }
            .joined(separator: " ")
        let themeText = inputs.themes.prefix(8).map(\.name).joined(separator: " ")
        let clusterText = inputs.clusters.prefix(6).map(\.name).joined(separator: " ")
        return "\(pageText) \(themeText) \(clusterText)".lowercased()
    }

    private static func startAnchor(day: BookDay, inputs: BookSourceInputs) -> String {
        if let last = day.capturedPages.last?.userInput.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return String(last.prefix(90))
        }
        if let weather = inputs.weather?.phrase, !weather.isEmpty {
            return "today's \(weather)"
        }
        return "one true detail from today"
    }

    private static func startIntention(day: BookDay, inputs: BookSourceInputs) -> String {
        if let theme = inputs.themes.first?.name, !theme.isEmpty {
            return "find how \(theme) behaves in another book"
        }
        if day.capturedPages.contains(where: { $0.type == .souvenir }) {
            return "bring back a sentence that still belongs to real life"
        }
        return "notice one useful impossibility and return with it intact"
    }

    private static func startGuide(inputs: BookSourceInputs) -> String {
        if let entity = StableWeightedRoll.pick(
            from: inputs.customCastMembers,
            seed: "book-jump-start-guide",
            weight: { member in
                member.baseBelief + member.narrativeWeight + (inputs.entityBeliefOffsets[member.id] ?? 0)
            }
        ) {
            return entity.name
        }
        return "the Book"
    }
}

enum StoryChoiceRole: String, Codable, Equatable, CaseIterable {
    case sliceOfLife
    case progressArc
    case surprise

    var title: String {
        switch self {
        case .sliceOfLife:
            return "Slice of Life"
        case .progressArc:
            return "Progress Arc"
        case .surprise:
            return "Something Surprising"
        }
    }

    var directorInstruction: String {
        switch self {
        case .sliceOfLife:
            return "A grounded, ordinary choice that tends the day without forcing plot."
        case .progressArc:
            return "A choice that advances the selected story thread or current arc."
        case .surprise:
            return "A sideways choice that still belongs to this scene and reveals an unexpected connection."
        }
    }
}

struct StorySceneChoice: Identifiable, Codable, Equatable {
    var id: String
    var role: StoryChoiceRole
    var title: String
    var prompt: String
    var hiddenEffect: String
    var beliefDelta: Int
    var targetEntityIDs: [String]
    var targetThreadIDs: [String]
}

/// One concrete element planted in a Story Page's opening that its ending must
/// return, changed: the "promise" that lets a beat-by-beat improvised vignette
/// still pay off without railroading the reader's choices. The path between
/// seed and resolution stays divergent; only the destination is committed.
struct StoryPromise: Codable, Equatable {
    /// The tangible thing to plant up front and honor at the close.
    var seed: String
    /// The central dramatic question the vignette answers by its resolution.
    var question: String
}

enum StoryRegister: String, Codable, Equatable { case quiet, active }

enum StoryTurnKind: String, Codable, CaseIterable, Equatable {
    case revealWant        // a character reveals what they want
    case changeOfHeart     // a character changes their mind about the reader
    case factLearned       // a fact is learned that recolors the day
    case smallDecision     // a small decision gets made
    case handOff           // something changes hands or state
    case relationshipShift // a relationship warms or cools a notch
    case realNoticing      // a real-world noticing is minted

    var register: StoryRegister {
        switch self {
        case .revealWant, .factLearned, .realNoticing: return .quiet
        default: return .active
        }
    }
}

/// The one change a Story Page commits to before any prose. Built from the
/// cast's existing goals/faults/relationship edges so the page is character-
/// first by construction. `landings` maps each choice role id to a different
/// resolution of THIS SAME change: that is what makes the player's path
/// matter: Slice/Arc/Surprise land different facts, not different moods.
struct StoryTurn: Codable, Equatable {
    var kind: StoryTurnKind
    var character: String           // name the turn centers
    var want: String                // from goals / unwrittenInterest
    var obstacle: String            // from faults / relationship tension
    var statement: String           // "by the end, this is true": the contract
    var register: StoryRegister
    var landings: [String: String]  // choice role id → committed landing line

    /// Serializes the turn into the page metadata keys the draft and prompts
    /// read. Shared by every playable adapter (Story Pages, Parleys, Classes)
    /// so the commit-before-prose contract is identical across page types.
    var metadata: [String: String] {
        [
            "storyTurnKind": kind.rawValue,
            "storyTurnCharacter": character,
            "storyTurnWant": want,
            "storyTurnObstacle": obstacle,
            "storyTurnStatement": statement,
            "storyTurnRegister": register.rawValue,
            "storyTurnLandingSliceOfLife": landings["slice-of-life"] ?? "",
            "storyTurnLandingProgressArc": landings["progress-arc"] ?? "",
            "storyTurnLandingSurprise": landings["surprise"] ?? ""
        ]
    }
}

/// Recipe-authored pressure beneath a Story Turn. The Turn says what changes;
/// this says why the change matters to the people in the room. Templates are
/// resolved from the actual cast, canon, and relationship edge before prose is
/// generated, so the model cannot choose a convenient personality afterward.
struct StoryRecipeCharacterPressureTemplate: Codable, Equatable {
    var leadCharacterWorryTemplate: String
    var leadCharacterBlindSpotTemplate: String
    var otherCharacterPressureTemplate: String
    var relationshipQuestionTemplate: String
    var stakesTemplate: String
    var requiredCharacterReactionTemplate: String
    var readerChoiceEffectTemplate: String
}

/// One reader path's precommitted emotional consequence. It names who must
/// react and the exact fact that becomes canon, rather than merely requesting
/// a different mood for each button.
struct StoryDramaticChoiceEffect: Codable, Equatable {
    var choiceID: String
    var role: StoryChoiceRole
    var requiredReactorID: String
    var requiredReactorName: String
    var requiredReaction: String
    var readerChoiceEffect: String
    var changedFact: String
    var memorySummary: String
    var warmthDelta: Int
    var tensionDelta: Int
    var familiarityDelta: Int
}

/// The five dramatic questions a Story Page must answer before the prose
/// writer is allowed into the room. This is the causal fiction substrate: the
/// opening stages it, the selected result resolves it, and the kept page turns
/// the selected effect into relationship and memory state.
struct StoryDramaticContract: Codable, Equatable {
    static let currentVersion = 1
    static let metadataKey = "storyDramaticContractV1"

    var version: Int = currentVersion
    var recipeID: String
    var leadCharacterID: String
    var leadCharacterName: String
    var leadCharacterWant: String
    var leadCharacterWorry: String
    var leadCharacterBlindSpot: String
    var otherCharacterID: String
    var otherCharacterName: String
    var otherCharacterPressure: String
    var relationshipID: String
    var relationshipQuestion: String
    var stakes: String
    var choiceEffects: [StoryDramaticChoiceEffect]

    init(
        version: Int = currentVersion,
        recipeID: String,
        leadCharacterID: String,
        leadCharacterName: String,
        leadCharacterWant: String,
        leadCharacterWorry: String,
        leadCharacterBlindSpot: String,
        otherCharacterID: String,
        otherCharacterName: String,
        otherCharacterPressure: String,
        relationshipID: String,
        relationshipQuestion: String,
        stakes: String,
        choiceEffects: [StoryDramaticChoiceEffect]
    ) {
        self.version = version
        self.recipeID = recipeID
        self.leadCharacterID = leadCharacterID
        self.leadCharacterName = leadCharacterName
        self.leadCharacterWant = leadCharacterWant
        self.leadCharacterWorry = leadCharacterWorry
        self.leadCharacterBlindSpot = leadCharacterBlindSpot
        self.otherCharacterID = otherCharacterID
        self.otherCharacterName = otherCharacterName
        self.otherCharacterPressure = otherCharacterPressure
        self.relationshipID = relationshipID
        self.relationshipQuestion = relationshipQuestion
        self.stakes = stakes
        self.choiceEffects = choiceEffects
    }

    func effect(for choiceID: String) -> StoryDramaticChoiceEffect? {
        let wanted = StoryTurnLanding.normalizedChoiceID(choiceID)
        return choiceEffects.first { StoryTurnLanding.normalizedChoiceID($0.choiceID) == wanted }
    }

    var encodedMetadata: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }

    init?(encodedMetadata: String) {
        guard let data = Data(base64Encoded: encodedMetadata),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = decoded
    }
}

/// A kept choice closes the roads not taken. These compact tags survive after
/// Surface metadata is gone and let later fiction distinguish an ordinary
/// choice from a refusal or betrayal that a character should remember sharply.
enum StoryChoiceClosure {
    static let chosenPrefix = "story-path-chosen:"
    static let closedPrefix = "story-path-closed:"
    static let refusalTag = "story-refusal"
    static let betrayalTag = "story-betrayal"

    static func tags(
        chosenChoiceID: String,
        availableChoiceIDs: [String],
        chosenText: String
    ) -> [String] {
        let chosen = StoryTurnLanding.normalizedChoiceID(chosenChoiceID)
        var tags = [chosenPrefix + chosen]
        tags.append(contentsOf: availableChoiceIDs
            .map(StoryTurnLanding.normalizedChoiceID)
            .filter { $0 != chosen }
            .map { closedPrefix + $0 })

        let text = chosenText.lowercased()
        let betrayalWords = ["betray", "deceive", "abandon", "sell out", "break the promise", "lie to"]
        let refusalWords = ["refuse", "reject", "deny", "withhold", "turn away", "walk away", "say no"]
        if betrayalWords.contains(where: text.contains) {
            tags.append(betrayalTag)
        } else if refusalWords.contains(where: text.contains) {
            tags.append(refusalTag)
        }
        return Array(Set(tags)).sorted()
    }
}

/// A compact, local receipt for the chosen emotional outcome. It travels on
/// the kept BookPage because Surface metadata does not survive archiving. The
/// consequence resolver verifies and applies this exact receipt later.
struct StoryDramaticOutcomeReceipt: Codable, Equatable {
    static let tagPrefix = "story-dramatic-outcome-v1:"

    var version: Int = StoryDramaticContract.currentVersion
    var recipeID: String
    var choiceID: String
    var turnKind: StoryTurnKind
    var leadCharacterID: String
    var leadCharacterName: String
    var otherCharacterID: String
    var otherCharacterName: String
    var reactorID: String
    var reactorName: String
    var relationshipID: String
    var relationshipQuestion: String
    var requiredReaction: String
    var changedFact: String
    var memorySummary: String
    var warmthDelta: Int
    var tensionDelta: Int
    var familiarityDelta: Int

    init(contract: StoryDramaticContract, effect: StoryDramaticChoiceEffect, turnKind: StoryTurnKind) {
        recipeID = contract.recipeID
        choiceID = effect.choiceID
        self.turnKind = turnKind
        leadCharacterID = contract.leadCharacterID
        leadCharacterName = contract.leadCharacterName
        otherCharacterID = contract.otherCharacterID
        otherCharacterName = contract.otherCharacterName
        reactorID = effect.requiredReactorID
        reactorName = effect.requiredReactorName
        relationshipID = contract.relationshipID
        relationshipQuestion = contract.relationshipQuestion
        requiredReaction = effect.requiredReaction
        changedFact = effect.changedFact
        memorySummary = effect.memorySummary
        warmthDelta = effect.warmthDelta
        tensionDelta = effect.tensionDelta
        familiarityDelta = effect.familiarityDelta
    }

    var encodedTag: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        let base64URL = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return Self.tagPrefix + base64URL
    }

    static func decode(tag: String) -> Self? {
        guard tag.hasPrefix(tagPrefix) else { return nil }
        var value = String(tag.dropFirst(tagPrefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - value.count % 4) % 4
        value += String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: value) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func receipts(in tags: [String]) -> [Self] {
        tags.compactMap(decode(tag:))
    }
}

struct StoryDramaticValidation: Equatable {
    var score: Int
    var failures: [String]
    var isAcceptable: Bool { failures.isEmpty }
}

/// Deterministic checks for the result half of the dramatic contract. The
/// prose may vary; the named reactor and committed changed fact may not vanish.
enum StoryDramaticResultValidator {
    static func validate(_ prose: String, effect: StoryDramaticChoiceEffect) -> StoryDramaticValidation {
        var score = 100
        var failures: [String] = []
        let lowered = prose.lowercased()
        let reactor = effect.requiredReactorName.split(separator: " ").first.map(String.init)?.lowercased()
            ?? effect.requiredReactorName.lowercased()
        if !reactor.isEmpty, !lowered.contains(reactor) {
            failures.append("Make \(effect.requiredReactorName) visibly react to this choice.")
            score -= 45
        }
        if !StoryTurnValidator.asserts(prose, landing: effect.changedFact, character: effect.requiredReactorName) {
            failures.append("Enact this exact changed fact: \(effect.changedFact)")
            score -= 40
        }
        let reactionTerms = significantWords(in: effect.requiredReaction)
        let proseTerms = Set(lowered.split { !$0.isLetter }.map(String.init))
        if reactionTerms.intersection(proseTerms).count < min(2, max(1, reactionTerms.count)) {
            failures.append("Show the required reaction instead of summarizing around it: \(effect.requiredReaction)")
            score -= 25
        }
        return StoryDramaticValidation(score: score, failures: failures)
    }

    static func landed(_ prose: String, effect: StoryDramaticChoiceEffect) -> String {
        StoryTurnValidator.landed(prose, landing: "\(effect.requiredReactorName) \(effect.requiredReaction) \(effect.changedFact)")
    }

    private static func significantWords(in text: String) -> Set<String> {
        let stop: Set<String> = ["about", "after", "again", "because", "before", "between", "their", "there", "these", "those", "through", "under", "which", "while", "with", "would"]
        return Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 4 && !stop.contains($0) })
    }
}

/// Lightweight check that a generated beat actually enacted the committed
/// change instead of drifting back into atmosphere. Used to gate climax and
/// result prose with a regenerate-once-then-state-it-plainly rail.
enum StoryTurnValidator {
    static let changeVerbs: Set<String> = [
        "admits", "admitted", "decides", "decided", "hands", "handed", "reveals",
        "revealed", "changes", "changed", "agrees", "agreed", "refuses", "refused",
        "opens", "opened", "names", "named", "gives", "gave", "takes", "took",
        "chooses", "chose", "confesses", "confessed", "realizes", "realized",
        "offers", "offered", "accepts", "accepted", "shows", "showed", "tells",
        "told", "asks", "asked", "promises", "promised", "trusts", "trusted"
    ]

    static func asserts(_ prose: String, landing: String, character: String) -> Bool {
        let lowered = prose.lowercased()
        let firstName = character.split(separator: " ").first.map(String.init)?.lowercased() ?? character.lowercased()
        // The character (or a clear stand-in) must be present and acting.
        let presentPronoun = lowered.contains(" he ") || lowered.contains(" she ") || lowered.contains(" they ")
        let hasCharacter = character.isEmpty || lowered.contains(firstName) || presentPronoun
        guard hasCharacter else { return false }
        let words = Set(lowered.split { !$0.isLetter }.map(String.init))
        if !words.isDisjoint(with: changeVerbs) { return true }
        // Otherwise demand real overlap with the committed landing's content.
        let landingNouns = Set(landing.lowercased().split { !$0.isLetter }.map(String.init))
            .filter { $0.count >= 5 }
        return landingNouns.intersection(words).count >= 2
    }

    /// When a beat refuses to enact the change after a retry, state it plainly:
    /// the committed landing is appended as the closing line so the page still
    /// ends on a real change rather than more atmosphere.
    static func landed(_ prose: String, landing: String) -> String {
        let trimmed = prose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return landing }
        if trimmed.lowercased().contains(landing.lowercased()) { return trimmed }
        return trimmed + " " + landing
    }

    /// Nouns that, when they dominate the subjects of a scene, mean the room
    /// has become the protagonist and nobody is doing anything.
    static let roomNouns: Set<String> = [
        "room", "air", "light", "dust", "window", "glass", "sun", "pane",
        "condensation", "stillness", "sunlight", "shadow", "draft", "frame",
        "surface", "stacks", "shelf", "shelves", "atmosphere"
    ]

    /// True when the prose is atmosphere-dominated: room nouns crowd out people
    /// and fewer than two named characters actually appear. Used to reject and
    /// regenerate openings/results that drift back into mood.
    static func isAtmosphereDominated(_ prose: String, characterNames: [String]) -> Bool {
        let lowered = prose.lowercased()
        let words = lowered.split { !$0.isLetter }.map(String.init)
        guard words.count > 12 else { return false }
        let roomHits = words.filter { roomNouns.contains($0) }.count
        let firstNames = characterNames.compactMap { $0.split(separator: " ").first.map(String.init)?.lowercased() }
        let distinctPeople = Set(firstNames.filter { lowered.contains($0) }).count
        let roomDensity = Double(roomHits) / Double(words.count)
        // Heavy room vocabulary AND fewer than two people on screen.
        return roomDensity > 0.06 && distinctPeople < 2
    }

    /// True when two scenes open with effectively the same line: the repetition
    /// the anti-echo contract is meant to forbid.
    static func isNearDuplicate(_ a: String, of b: String) -> Bool {
        func prefix(_ s: String) -> String {
            s.lowercased().split { !$0.isLetter }.prefix(12).joined(separator: " ")
        }
        let pa = prefix(a), pb = prefix(b)
        guard pa.count > 12 else { return false }
        return pa == pb
    }
}

enum StoryTurnLanding {
    /// Choice ids arrive in two conventions: "sliceoflife" from the draft
    /// parser, "slice-of-life" from the packet. Normalize before lookup so the
    /// result rail and the landing instruction actually fire.
    static func resolve(_ landings: [String: String], choiceID: String) -> String? {
        let compact = normalizedChoiceID(choiceID)
        let key = ["sliceoflife": "slice-of-life",
                   "progressarc": "progress-arc",
                   "surprise": "surprise"][compact] ?? choiceID
        return landings[key]?.nonEmpty
    }

    static func normalizedChoiceID(_ choiceID: String) -> String {
        choiceID.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

/// The shape of a concrete, interpersonal scene-want: one person wanting a
/// specific thing from another person, with a physical pretext at stake.
enum SceneVerb: Equatable {
    case confront, prove, stop, askHelp, forgive, share, recover, keepSecret, beTakenSeriously
}

struct SceneIntent: Equatable {
    var wanter: String   // A
    var target: String   // B (present character, or "the reader")
    var pretext: String  // the concrete thing at stake
    var verb: SceneVerb

    /// The concrete want clause, e.g. "Penny to admit what happened last time".
    var want: String {
        switch verb {
        case .confront: return "\(target) to admit \(pretext)"
        case .prove: return "to prove \(target) wrong about \(pretext)"
        case .stop: return "to stop \(target) from walking away from \(pretext)"
        case .askHelp: return "\(target)'s help with \(pretext) without having to ask plainly"
        case .forgive: return "\(target) to forgive \(pretext)"
        case .share: return "to show \(target) \(pretext) before the moment passes"
        case .recover: return "to get \(pretext) back from \(target)"
        case .keepSecret: return "to keep \(pretext) from \(target)"
        case .beTakenSeriously: return "\(target) to take \(pretext) seriously for once"
        }
    }

    /// The concrete, person-centered obstacle, never "their own caution".
    var obstacle: String {
        switch verb {
        case .confront: return "\(target) keeps pretending nothing happened"
        case .prove: return "\(target) has already made up their mind"
        case .stop: return "\(target) is halfway out the door"
        case .askHelp: return "\(wanter)'s pride won't let the question out"
        case .forgive: return "\(target) isn't sure the apology is real"
        case .share: return "\(target) keeps changing the subject"
        case .recover: return "\(target) won't admit they have it"
        case .keepSecret: return "\(target) is already asking the wrong questions"
        case .beTakenSeriously: return "\(target) treats it as a joke"
        }
    }

    /// A short verb phrase the landings reuse, e.g. "admits what happened".
    var actPhrase: String {
        switch verb {
        case .confront: return "admits \(pretext)"
        case .prove: return "concedes the point about \(pretext)"
        case .stop: return "decides whether to stay"
        case .askHelp: return "offers the help"
        case .forgive: return "lets \(pretext) go"
        case .share: return "takes in what they're shown"
        case .recover: return "hands \(pretext) back"
        case .keepSecret: return "uncovers \(pretext)"
        case .beTakenSeriously: return "takes \(wanter) seriously"
        }
    }
}

struct StoryScenePacket: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var title: String
    var playableThreadTitle: String
    var directorIntent: String
    var playerBelief: Int
    var bookGlow: String
    var realSignals: [String]
    var selectedEntities: [NarrativeWorldEntity]
    var selectedThreads: [NarrativeStoryThread]
    var selectedRelationships: [NarrativeRelationshipEdge]
    var selectedEntityMemories: [NarrativeEntityMemory]
    var relationshipPressures: [String]
    var chapterTalismanMoves: [ChapterTalismanBeliefMove]
    var choices: [StorySceneChoice]
    var blueprint: StorySceneBlueprint?
    var storyFormID: String?
    var storyFormName: String?
    var storyFormBeats: [String]?
    var storyGenreID: String?
    var storyGenreName: String?
    var storyGenreLens: String?
    var storyGenreExemplar: String?
    var storyGenrePalette: [String]?
    var promise: StoryPromise?
    var turn: StoryTurn?
    var activeWorldEvents: [ResolvedWorldEvent]
}

enum StoryThreadPresentation {
    private static let underlayerThreadIDs: Set<String> = [
        "body-learns-trust",
        "weather-in-the-stacks",
        "ordinary-magic",
        "music-as-shelter",
        "home-vessel"
    ]

    static func isUnderlayer(_ thread: NarrativeStoryThread?) -> Bool {
        guard let thread else { return false }
        return underlayerThreadIDs.contains(thread.id) || thread.tags.contains("atmosphere")
    }

    static func displayTitle(
        primaryThread: NarrativeStoryThread?,
        blueprint: StorySceneBlueprint?,
        turn: StoryTurn?,
        primaryEntity: NarrativeWorldEntity?
    ) -> String {
        if let primaryThread, !isUnderlayer(primaryThread) {
            return primaryThread.title
        }
        if let recipeName = blueprint?.recipeName.nonEmpty {
            return recipeName
        }
        if let turn, !turn.character.isEmpty {
            return "\(turn.character)'s Small Turn"
        }
        if let primaryEntity, primaryEntity.kind == .character {
            return "\(primaryEntity.name)'s Visit"
        }
        return primaryThread?.title ?? "Ordinary Magic"
    }
}

enum OrganicStoryThreadSynthesizer {
    static let packID = "organic-story-field"

    static func availableThreads(inputs: BookSourceInputs, tags: Set<String>) -> [NarrativeStoryThread] {
        var byID: [String: NarrativeStoryThread] = [:]
        for thread in NarrativePackRegistry.threads + threads(inputs: inputs, tags: tags) {
            byID[thread.id] = thread
        }
        return byID.values.sorted { $0.id < $1.id }
    }

    static func threads(inputs: BookSourceInputs, tags: Set<String> = []) -> [NarrativeStoryThread] {
        var candidates: [NarrativeStoryThread] = []
        let authoredMotifs: Set<String> = ["lamp", "rain", "soup", "threshold"]
        let genericMotifs = inputs.storyMotifs
            .filter { key, count in
                count >= 3 && !authoredMotifs.contains(StoryConsequenceCondition.key(key))
            }
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .prefix(3)

        for (rawKey, count) in genericMotifs {
            let key = StoryConsequenceCondition.key(rawKey)
            guard !key.isEmpty else { continue }
            let title = "\(displayName(forKey: key)) Keeps Returning"
            candidates.append(
                NarrativeStoryThread(
                    id: "organic-motif-\(key)",
                    packID: packID,
                    title: title,
                    phase: count >= 6 ? .returning : .seed,
                    belief: 10 + min(count, 8),
                    narrativeWeight: 18 + min(count * 4, 24),
                    summary: "This thread was born because \(displayName(forKey: key).lowercased()) kept showing up in recent choices, motifs, or kept pages.",
                    tags: Array(Set(["organic-thread", "motif", key] + key.split(separator: "-").map(String.init) + tags.filter { $0 == key }))
                )
            )
        }
        return candidates
    }

    static func boosts(inputs: BookSourceInputs) -> [String: Int] {
        var boosts: [String: Int] = [:]
        func add(_ threadID: String, _ amount: Int) {
            guard amount > 0 else { return }
            boosts[threadID, default: 0] += amount
        }

        let ceremonyCount = inputs.storyRituals["small-ceremony-register"] ?? 0
        add("great-hall-small-announcements", min(36, ceremonyCount * 6))

        let quietCompanyCount = inputs.storyRituals
            .filter { StoryConsequenceCondition.key($0.key).hasPrefix("quiet-company") }
            .map(\.value)
            .reduce(0, +)
        add("companionable-silence", min(30, quietCompanyCount * 5))

        add("lamp-repair-committee", min(24, (inputs.storyMotifs["lamp"] ?? 0) * 5))
        add("rain-room-opens", min(24, (inputs.storyMotifs["rain"] ?? 0) * 5))
        add("pantry-keeps-receipts", min(24, (inputs.storyMotifs["soup"] ?? 0) * 5))
        add("threshold-ledger", min(24, (inputs.storyMotifs["threshold"] ?? 0) * 5))

        if inputs.bookNoticeEvidence >= 3 {
            add("shelf-of-misfiled-days", min(12, inputs.bookNoticeEvidence * 2))
        }
        if (inputs.storySettingAffinities["location-great-hall"] ?? 0) >= 4 {
            add("great-hall-small-announcements", 12)
        }
        if (inputs.storySceneBiases["quiet"] ?? 0) >= 6 {
            add("companionable-silence", 6)
        }
        return boosts
    }

    static func title(forOrganicThreadID threadID: String) -> String? {
        guard threadID.hasPrefix("organic-motif-") else { return nil }
        let key = String(threadID.dropFirst("organic-motif-".count))
        return "\(displayName(forKey: key)) Keeps Returning"
    }

    private static func displayName(forKey key: String) -> String {
        key
            .split(separator: "-")
            .map { String($0).capitalized }
            .joined(separator: " ")
    }
}

enum StorySpark {
    static let sourceTagPrefix = "story-spark-source:"
    static let usedTag = "story-sparked"

    static func candidate(for day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> BookPage? {
        let pages = day.capturedPages + inputs.days.flatMap(\.capturedPages)
        let usedSourceIDs = Set(pages.flatMap { page in
            page.tags.compactMap { tag -> String? in
                let lowered = tag.lowercased()
                guard lowered.hasPrefix(sourceTagPrefix) else { return nil }
                return String(lowered.dropFirst(sourceTagPrefix.count))
            }
        })
        return pages
            .filter { page in
                page.type == .souvenir &&
                    now.timeIntervalSince(page.createdAt) <= 21 * 86_400 &&
                    !usedSourceIDs.contains(page.id.lowercased()) &&
                    !page.tags.contains { $0.lowercased() == usedTag } &&
                    score(page.userInput.nonEmpty ?? page.promptText) >= 7
            }
            .sorted { left, right in
                let leftScore = score(left.userInput.nonEmpty ?? left.promptText)
                let rightScore = score(right.userInput.nonEmpty ?? right.promptText)
                if leftScore == rightScore { return left.createdAt > right.createdAt }
                return leftScore > rightScore
            }
            .first
    }

    static func sentence(from page: BookPage) -> String {
        let raw = page.userInput.nonEmpty ?? page.promptText
        return raw.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .bookPreviewSentenceLimit(1)
    }

    static func score(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let lowered = trimmed.lowercased()
        let words = lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard (5...36).contains(words.count), trimmed.count <= 240 else { return 0 }

        let weather = ["rain", "snow", "fog", "mist", "wind", "sun", "moon", "cloud", "storm", "thunder", "lightning", "sky", "dusk", "dawn", "evening", "night"]
        let sensory = ["blue", "green", "gold", "red", "silver", "warm", "cold", "damp", "bright", "dark", "soft", "sharp", "quiet", "loud", "smelled", "smell", "sound", "taste", "light", "shadow"]
        let places = ["room", "kitchen", "parking", "window", "door", "street", "table", "shelf", "hall", "garden", "porch", "bus", "car", "sidewalk", "store", "office", "bed"]
        let objects = ["cup", "mug", "spoon", "receipt", "book", "page", "lamp", "key", "scarf", "shoe", "bowl", "candle", "photo", "bookmark", "pencil", "letter"]
        let motion = ["made", "opened", "closed", "kept", "held", "turned", "fell", "rose", "glowed", "waited", "crossed", "carried", "pressed", "folded"]

        func containsAny(_ lexicon: [String]) -> Bool {
            lexicon.contains { lowered.contains($0) }
        }

        var score = 0
        if containsAny(weather) { score += 2 }
        if containsAny(sensory) { score += 2 }
        if containsAny(places) { score += 2 }
        if containsAny(objects) { score += 2 }
        if containsAny(motion) { score += 1 }
        if lowered.contains(" like ") || lowered.contains(" as if ") || lowered.contains(" under ") { score += 2 }
        if trimmed.contains(".") || trimmed.contains("!") { score += 1 }
        if words.count >= 8 { score += 1 }
        if lowered.contains("?") { score -= 2 }
        if ["good", "bad", "nice", "fine", "okay"].contains(where: { lowered == $0 || lowered == "it was \($0)" }) { score -= 4 }
        return score
    }
}

/// Chooses the reader-authored keep that can do the most useful work inside the
/// current Story Page, then chooses the strongest passage inside that keep.
/// Embeddings supply relevance when the caller is already off-main; attention
/// fingerprints, continuity evidence, specificity, and prose shape provide the
/// deterministic fallback everywhere else.
enum MeaningfulPassageSelector {
    static let sourceTagPrefix = "meaningful-source:"
    static let legacyStorySourceTagPrefix = "story-grounding-source:"
    static let storyUsedTag = "story-grounding-used"
    static let maximumAge: TimeInterval = 120 * 86_400
    static let maximumCandidates = 80
    static let maximumExcerptCharacters = 280
    static let minimumSelectionScore = 16

    struct Selection: Codable, Equatable {
        var pageID: String
        var pageType: BookPageType
        var excerpt: String
        var score: Int
        var semanticSimilarity: Double?
        var reason: String
    }

    static func periodQuery(pages: [BookPage], framing: [String] = []) -> String {
        var tokenCounts: [String: Int] = [:]
        for page in pages {
            let tokens = Set(
                page.tags.map { $0.lowercased() }
                    + page.resolvedAttentionFingerprint.patternTokens.map { $0.lowercased() }
                    + SemanticKeepEcho.contentWords(in: page.promptText)
            )
            for token in tokens where token.count >= 3 {
                tokenCounts[token, default: 0] += 1
            }
        }
        let recurring = tokenCounts.sorted { left, right in
            if left.value == right.value { return left.key < right.key }
            return left.value > right.value
        }.prefix(32).map(\.key)
        return (framing + recurring).filter { !$0.isEmpty }.joined(separator: ". ")
    }

    private struct PassageScore {
        var text: String
        var score: Int
        var semanticSimilarity: Double?
        var lexicalOverlap: Int
    }

    static func storyQuery(
        tags: Set<String>,
        primaryThread: NarrativeStoryThread?,
        entities: [NarrativeWorldEntity],
        relationshipPressures: [String],
        inputs: BookSourceInputs
    ) -> String {
        var pieces: [String] = []
        if let primaryThread {
            pieces += [primaryThread.title, primaryThread.summary]
            pieces += primaryThread.tags
        }
        for entity in entities.prefix(4) {
            pieces.append(entity.name)
            pieces += entity.unwrittenInterest.map { [$0] } ?? []
            pieces += Array(entity.goals.prefix(2))
            pieces += Array(entity.traits.prefix(3))
            pieces += Array(entity.tags.prefix(5))
        }
        pieces += Array(relationshipPressures.prefix(3))
        pieces += Array(tags.sorted().prefix(18))
        pieces += inputs.currentArc.map { [$0.title, $0.phase.rawValue] } ?? []
        pieces += inputs.clusters
            .sorted { $0.strength > $1.strength }
            .prefix(3)
            .flatMap { [$0.name, $0.line] + Array($0.motifs.prefix(5)) }
        pieces += inputs.themes
            .sorted { $0.strength > $1.strength }
            .prefix(3)
            .flatMap { [$0.name, $0.line] + Array($0.motifs.prefix(5)) }
        pieces += inputs.continuity.strongestSignals.prefix(4).flatMap {
            [$0.subjectName, $0.line] + Array($0.tags.prefix(4))
        }
        let query = pieces
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        return String(query.prefix(1_600))
    }

    static func select(
        pages: [BookPage],
        query: String,
        inputs: BookSourceInputs,
        scorer: StacksSemanticScoring?,
        maximumAge: TimeInterval = MeaningfulPassageSelector.maximumAge,
        minimumScore: Int = MeaningfulPassageSelector.minimumSelectionScore,
        honorPriorUse: Bool = true,
        includeKeptGeneratedPages: Bool = false,
        now: Date = Date()
    ) -> Selection? {
        rankedSelections(
            pages: pages,
            query: query,
            inputs: inputs,
            scorer: scorer,
            limit: 1,
            maximumAge: maximumAge,
            minimumScore: minimumScore,
            honorPriorUse: honorPriorUse,
            includeKeptGeneratedPages: includeKeptGeneratedPages,
            now: now
        ).first
    }

    static func rankedSelections(
        pages: [BookPage],
        query: String,
        inputs: BookSourceInputs,
        scorer: StacksSemanticScoring?,
        limit: Int,
        maximumAge: TimeInterval = MeaningfulPassageSelector.maximumAge,
        minimumScore: Int = MeaningfulPassageSelector.minimumSelectionScore,
        honorPriorUse: Bool = true,
        diversifyPageTypes: Bool = false,
        includeKeptGeneratedPages: Bool = false,
        now: Date = Date()
    ) -> [Selection] {
        guard limit > 0 else { return [] }
        let usedSourceIDs = honorPriorUse ? Set(pages.flatMap { page in
            page.tags.compactMap { tag -> String? in
                let lowered = tag.lowercased()
                if lowered.hasPrefix(sourceTagPrefix) {
                    return String(lowered.dropFirst(sourceTagPrefix.count))
                }
                if lowered.hasPrefix(legacyStorySourceTagPrefix) {
                    return String(lowered.dropFirst(legacyStorySourceTagPrefix.count))
                }
                return nil
            }
        }) : []
        let deduplicated = Dictionary(pages.map { ($0.id, $0) }, uniquingKeysWith: { first, second in
            first.createdAt >= second.createdAt ? first : second
        }).values
        let eligible = deduplicated
            .filter { page in
                let age = now.timeIntervalSince(page.createdAt)
                return age >= 0
                    && age <= maximumAge
                    && page.type != .welcome
                    && !page.tags.contains("first-door-origin")
                    && !EditionCurator.defaultPrivateTypes.contains(page.type)
                    && page.privacy != .publicReference
                    && !usedSourceIDs.contains(page.id.lowercased())
                    && groundingText(for: page, includeKeptGeneratedPages: includeKeptGeneratedPages) != nil
            }
            .sorted { left, right in
                let leftSignal = archiveSignalBoost(for: left, inputs: inputs)
                let rightSignal = archiveSignalBoost(for: right, inputs: inputs)
                if leftSignal != rightSignal { return leftSignal > rightSignal }
                if left.createdAt != right.createdAt { return left.createdAt > right.createdAt }
                return left.id < right.id
            }
            .prefix(maximumCandidates)

        let queryWords = SemanticKeepEcho.contentWords(in: query)
        var ranked: [(page: BookPage, passage: PassageScore, total: Int)] = []
        for page in eligible {
            guard let raw = groundingText(for: page, includeKeptGeneratedPages: includeKeptGeneratedPages) else { continue }
            let passage = bestPassage(
                in: raw,
                page: page,
                query: query,
                queryWords: queryWords,
                scorer: scorer
            )
            let ageDays = max(0, now.timeIntervalSince(page.createdAt) / 86_400)
            let freshness = max(0, 8 - Int(ageDays / 14))
            let total = passage.score
                + archiveSignalBoost(for: page, inputs: inputs)
                + pageTypeBoost(page.type)
                + freshness
            guard total >= minimumScore else { continue }
            ranked.append((page, passage, total))
        }
        ranked.sort { left, right in
            if left.total != right.total { return left.total > right.total }
            if left.passage.semanticSimilarity != right.passage.semanticSimilarity {
                return (left.passage.semanticSimilarity ?? 0) > (right.passage.semanticSimilarity ?? 0)
            }
            if left.page.createdAt != right.page.createdAt { return left.page.createdAt > right.page.createdAt }
            return left.page.id < right.page.id
        }

        var remaining = ranked
        var selected: [(page: BookPage, passage: PassageScore, total: Int)] = []
        var selectedTypes = Set<BookPageType>()
        while selected.count < limit, !remaining.isEmpty {
            let pickIndex: Int
            if diversifyPageTypes,
               let diverseIndex = remaining.indices.max(by: { left, right in
                   let leftScore = remaining[left].total - (selectedTypes.contains(remaining[left].page.type) ? 5 : 0)
                   let rightScore = remaining[right].total - (selectedTypes.contains(remaining[right].page.type) ? 5 : 0)
                   return leftScore < rightScore
               }) {
                pickIndex = diverseIndex
            } else {
                pickIndex = remaining.startIndex
            }
            let picked = remaining.remove(at: pickIndex)
            selected.append(picked)
            selectedTypes.insert(picked.page.type)
        }

        return selected.map { candidate in
            Selection(
                pageID: candidate.page.id,
                pageType: candidate.page.type,
                excerpt: clipped(candidate.passage.text, limit: maximumExcerptCharacters),
                score: candidate.total,
                semanticSimilarity: candidate.passage.semanticSimilarity,
                reason: selectionReason(for: candidate.passage)
            )
        }
    }

    private static func selectionReason(for passage: PassageScore) -> String {
        if let similarity = passage.semanticSimilarity, similarity >= 0.28 {
            return "semantic relevance \(Int((similarity * 100).rounded()))% plus passage specificity"
        }
        if passage.lexicalOverlap > 0 {
            return "context overlap plus passage specificity"
        }
        return "passage specificity plus archive significance"
    }

    private static func groundingText(
        for page: BookPage,
        includeKeptGeneratedPages: Bool
    ) -> String? {
        let reply = page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reply.isEmpty { return reply }
        let isReaderAuthored = page.origin == .userAuthored || page.origin == .imported
        let isKeptGeneratedPage = includeKeptGeneratedPages
            && (page.origin == .generated || page.origin == .simulated)
            && page.type != .note
            && page.type != .letter
        guard isReaderAuthored || isKeptGeneratedPage else { return nil }
        let input = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        return input
    }

    private static func bestPassage(
        in text: String,
        page: BookPage,
        query: String,
        queryWords: Set<String>,
        scorer: StacksSemanticScoring?
    ) -> PassageScore {
        let candidates = passages(in: text)
        let fingerprintWords = Set(page.resolvedAttentionFingerprint.patternTokens)
        var best: PassageScore?
        for passage in candidates {
            let lowered = passage.lowercased()
            let words = lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            let contentWords = SemanticKeepEcho.contentWords(in: passage)
            let lexicalOverlap = contentWords.intersection(queryWords).count
            let fingerprintOverlap = contentWords.intersection(fingerprintWords).count
            let similarity = scorer?.similarity(between: query, and: passage)
            let semantic = similarity.map { Int((max(0, $0 - 0.12) * 72).rounded()) } ?? 0
            var score = semantic + min(18, lexicalOverlap * 5) + min(10, fingerprintOverlap * 2)
            score += StorySpark.score(passage) * 2
            if (7...48).contains(words.count) { score += 8 }
            if words.count >= 12 && words.count <= 34 { score += 4 }
            if lowered.contains(" but ") || lowered.contains(" because ") || lowered.contains(" instead ") || lowered.contains(" until ") { score += 5 }
            if lowered.contains(" i ") || lowered.hasPrefix("i ") || lowered.contains(" we ") { score += 3 }
            let vividLongWords = Set(words.filter { $0.count >= 7 && !KeepMarginalia.stopWords.contains($0) }).count
            score += min(6, vividLongWords)
            if passage.contains("?") && !passage.contains(".") && !passage.contains("!") { score -= 6 }
            if passage.filter({ $0 == ":" }).count >= 3 { score -= 8 }
            if isThinOrGeneric(passage) { score -= 18 }
            let candidate = PassageScore(
                text: passage,
                score: score,
                semanticSimilarity: similarity,
                lexicalOverlap: lexicalOverlap
            )
            if let current = best {
                if candidate.score > current.score
                    || (candidate.score == current.score && candidate.text.count < current.text.count) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        return best ?? PassageScore(
            text: clipped(text, limit: maximumExcerptCharacters),
            score: 0,
            semanticSimilarity: nil,
            lexicalOverlap: 0
        )
    }

    private static func passages(in raw: String) -> [String] {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        var sentences: [String] = []
        var buffer = ""
        for character in normalized {
            if character == "\n" {
                if !buffer.isEmpty { buffer.append(" ") }
                continue
            }
            buffer.append(character)
            if ".!?".contains(character) {
                let clean = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { sentences.append(clean) }
                buffer = ""
            }
        }
        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        if sentences.isEmpty { sentences = [normalized] }

        var candidates: [String] = sentences
        if sentences.count > 1 {
            for index in 0..<(sentences.count - 1) {
                let pair = "\(sentences[index]) \(sentences[index + 1])"
                if pair.count <= maximumExcerptCharacters {
                    candidates.append(pair)
                }
            }
        }
        return candidates
            .map { clipped($0, limit: maximumExcerptCharacters) }
            .filter { !$0.isEmpty }
            .uniquedPreservingStoryOrder()
    }

    private static func archiveSignalBoost(for page: BookPage, inputs: BookSourceInputs) -> Int {
        var score = 0
        if inputs.continuity.strongestSignals.prefix(8).contains(where: { $0.evidencePageIDs.contains(page.id) }) { score += 12 }
        if inputs.clusters.prefix(6).contains(where: { $0.evidencePageIDs.contains(page.id) }) { score += 10 }
        if inputs.themes.prefix(6).contains(where: { $0.evidencePageIDs.contains(page.id) }) { score += 8 }
        let fingerprint = page.resolvedAttentionFingerprint
        score += min(5, fingerprint.modalities.count * 2)
        return score
    }

    private static func pageTypeBoost(_ type: BookPageType) -> Int {
        switch type {
        case .souvenir: return 8
        case .illuminatedPhoto, .plainPage: return 7
        case .diary, .wonderCompass, .location, .anchor: return 5
        case .mood, .note, .letter, .bookRemembered: return 3
        default: return 0
        }
    }

    private static func isThinOrGeneric(_ text: String) -> Bool {
        let normalized = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let generic = ["fine", "okay", "ok", "good", "bad", "it was fine", "it was okay", "nothing much", "same as usual"]
        return generic.contains(normalized) || normalized.split(separator: " ").count < 4
    }

    private static func clipped(_ text: String, limit: Int) -> String {
        let clean = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        let prefix = clean.prefix(limit)
        let end = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

private extension Array where Element == String {
    func uniquedPreservingStoryOrder() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}

enum StoryScenePacketBuilder {
    static func packet(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date(),
        semanticScorer: StacksSemanticScoring? = nil,
        recipeVariantIndex: Int = 0
    ) -> StoryScenePacket {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let tags = contextTags(for: day, inputs: inputs, now: now)
        var selectedEntities = rankedEntities(tags: tags, inputs: inputs, limit: 3, slotKey: "\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 4))")
        var selectedThreads = rankedThreads(tags: tags, inputs: inputs, limit: 2)
        if let arc = inputs.currentArc,
           let arcThread = OrganicStoryThreadSynthesizer.availableThreads(inputs: inputs, tags: tags).first(where: { $0.id == arc.threadID }) {
            selectedThreads.removeAll { $0.id == arc.threadID }
            selectedThreads.insert(arcThread, at: 0)
            selectedThreads = Array(selectedThreads.prefix(2))
        }
        let primaryThread = selectedThreads.first
        selectedEntities = withSettingLocation(
            selectedEntities,
            tags: tags,
            inputs: inputs,
            slotKey: "\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 4))-setting",
            limit: 4
        )
        var selectedRelationships = rankedRelationships(
            tags: tags,
            entities: selectedEntities,
            threads: selectedThreads,
            inputs: inputs,
            limit: 3
        )
        var selectedEntityMemories = rankedEntityMemories(
            entities: selectedEntities,
            inputs: inputs,
            limit: 5
        )
        let belief = inputs.narrative?.beliefWeight ?? 30
        var realSignals = realSignals(for: day, inputs: inputs)
        let talismanPool = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        if let ascendant = TalismanAscendancy.ascendant(entities: talismanPool, beliefOffsets: inputs.entityBeliefOffsets) {
            realSignals.append(TalismanAscendancy.influenceLine(for: ascendant))
        }
        if let arc = inputs.currentArc {
            realSignals.append("CURRENT ARC: \u{201C}\(arc.title)\u{201D} is in its \(arc.phase.rawValue) phase. \(ArcKeeper.directive(for: arc.phase))")
        }
        let rut = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: false,
            now: now
        )
        let greyLevel = NothingTide.greyLevel(
            readerRutPressure: rut.mayNameRut ? rut.pressure : 0,
            narrativeHeat: inputs.narrative?.recentEventCount ?? 0,
            distressActive: false,
            celebrationGreyShift: (inputs.faeState.activeGifts.contains { $0.effect == .quieting } ? -1 : 0)
                + inputs.nothingGreyOffset
        )
        if let greySignal = NothingTide.storySignal(forGreyLevel: greyLevel) {
            realSignals.append(greySignal)
        }
        if let chapterFact = inputs.selfFacts.first(where: { $0.questionID == "chapter-binding" }),
           let chapter = AcademyChapterRegistry.chapter(named: chapterFact.answer) {
            realSignals.append("The player is bound to Chapter \(chapter.name): \(chapter.philosophy) Let their chapter's way of seeing tint how the scene meets them.")
        }
        if !inputs.activeWorldEvents.isEmpty {
            realSignals.append(inputs.activeWorldEvents.influencePacket)
        }
        let relationships = relationshipPressures(
            entities: selectedEntities,
            threads: selectedThreads,
            selectedRelationships: selectedRelationships,
            day: day,
            inputs: inputs
        )
        let talismanMoves = ChapterTalismanBeliefMoves.moves(
            for: selectedEntities,
            seed: packetStableIndex(for: "\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 4))-story-talisman-options", count: 10_000)
        )
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let groundingQuery = MeaningfulPassageSelector.storyQuery(
            tags: tags,
            primaryThread: primaryThread,
            entities: selectedEntities,
            relationshipPressures: relationships,
            inputs: inputs
        )
        let groundingScorer = semanticScorer
            ?? (inputs.semanticPassageSelectionEnabled ? SemanticKeepEcho.keepTimeScorer : nil)
        let grounding = grounding(
            for: day,
            inputs: inputs,
            realSignals: realSignals,
            memories: selectedEntityMemories,
            storyQuery: groundingQuery,
            semanticScorer: groundingScorer,
            now: now
        )
        let recipePick = selectRecipe(
            tags: tags, entities: availableEntities(inputs: inputs), thread: primaryThread, grounding: grounding,
            hasNothingPressure: greyLevel > 0, inputs: inputs, day: day, slot: slot, now: now,
            variantIndex: recipeVariantIndex
        )
        if let recipe = recipePick?.recipe {
            selectedEntities = entities(for: recipe, selected: selectedEntities, inputs: inputs, slotKey: "\(day.id)-\(slot)")
            selectedEntities = withSettingLocation(
                selectedEntities,
                tags: tags,
                inputs: inputs,
                slotKey: "\(day.id)-\(slot)-recipe-setting",
                limit: 4
            )
            selectedRelationships = rankedRelationships(tags: tags, entities: selectedEntities, threads: selectedThreads, inputs: inputs, limit: 3)
            selectedEntityMemories = rankedEntityMemories(entities: selectedEntities, inputs: inputs, limit: 5)
        }
        let primaryEntity = selectedEntities.first { $0.kind == .character } ?? selectedEntities.first

        let ascendantChapterID = TalismanAscendancy.ascendant(
            entities: NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity),
            beliefOffsets: inputs.entityBeliefOffsets
        ).flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0.id)?.id }
        let (storyForm, storyGenre) = StoryFormRegistry.select(
            tags: tags,
            surfaceHistory: inputs.surfaceHistory,
            ascendantChapterID: ascendantChapterID,
            dayID: day.id,
            slot: slot,
            recipe: recipePick?.recipe,
            recipeBoosts: inputs.storyRecipeBoosts,
            sceneBiases: inputs.storySceneBiases,
            now: now
        )
        let blueprint = recipePick.flatMap { picked -> StorySceneBlueprint? in
            let sceneGrounding = picked.recipe.isWorldLed
                ? worldLedGrounding(realSignals: realSignals, now: now)
                : grounding
            return makeBlueprint(packID: picked.packID, recipe: picked.recipe, grounding: sceneGrounding,
                entities: selectedEntities, relationships: selectedRelationships, thread: primaryThread, form: storyForm,
                slotKey: "\(day.id)-\(slot)", quillName: inputs.chosenQuill?.displayName)
        }
        let turn = blueprint?.turn ?? turn(
            primaryCharacter: primaryEntity,
            relationship: selectedRelationships.first,
            thread: primaryThread,
            cast: selectedEntities,
            slotKey: "\(day.id)-\(slot)"
        )
        let promise = blueprint.map {
            StoryPromise(seed: $0.grounding.text, question: "By the end, how has \($0.premise.lowercased()) changed what happens next?")
        } ?? promise(primaryThread: primaryThread, primaryEntity: primaryEntity, entities: selectedEntities)
        let playableThreadTitle = StoryThreadPresentation.displayTitle(
            primaryThread: primaryThread,
            blueprint: blueprint,
            turn: turn,
            primaryEntity: primaryEntity
        )
        let title = recipePick?.recipe.id == "souvenir-door"
            ? "Story Spark: A Sentence Opens"
            : "Story Page: \(playableThreadTitle)"
        let intent = directorIntent(
            primaryThread: primaryThread,
            primaryEntity: primaryEntity,
            playableThreadTitle: playableThreadTitle,
            tags: tags
        )

        return StoryScenePacket(
            id: "story-packet-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 4))"
                + (recipeVariantIndex == 0 ? "" : "-variant-\(recipeVariantIndex)"),
            packID: NarrativePackRegistry.corePackID,
            title: title,
            playableThreadTitle: playableThreadTitle,
            directorIntent: intent,
            playerBelief: belief,
            bookGlow: BeliefLexicon.glowName(for: belief),
            realSignals: realSignals,
            selectedEntities: selectedEntities,
            selectedThreads: selectedThreads,
            selectedRelationships: selectedRelationships,
            selectedEntityMemories: selectedEntityMemories,
            relationshipPressures: relationships,
            chapterTalismanMoves: talismanMoves,
            choices: choices(
                primaryThread: primaryThread,
                playableThreadTitle: playableThreadTitle,
                selectedEntities: selectedEntities,
                selectedRelationships: selectedRelationships,
                turn: turn
            ),
            blueprint: blueprint,
            storyFormID: storyForm.id,
            storyFormName: storyForm.name,
            storyFormBeats: StoryVignetteBeats.snackSized(storyForm.beats),
            storyGenreID: storyGenre.id,
            storyGenreName: storyGenre.name,
            storyGenreLens: storyGenre.lens,
            storyGenreExemplar: storyGenre.exemplar.nonEmpty,
            storyGenrePalette: storyGenre.palette.isEmpty ? nil : storyGenre.palette,
            promise: promise,
            turn: turn,
            activeWorldEvents: inputs.activeWorldEvents
        )
    }

    private static func grounding(
        for day: BookDay,
        inputs: BookSourceInputs,
        realSignals: [String],
        memories: [NarrativeEntityMemory],
        storyQuery: String,
        semanticScorer: StacksSemanticScoring?,
        now: Date
    ) -> StoryGrounding {
        if let spark = StorySpark.candidate(for: day, inputs: inputs, now: now) {
            let sentence = StorySpark.sentence(from: spark)
            return StoryGrounding(
                kind: .souvenirDoor,
                sourceID: spark.id,
                text: "Story Spark from One-Sentence Souvenir: \"\(sentence)\""
            )
        }
        let pages = day.capturedPages + inputs.days.flatMap(\.capturedPages)
        if let selected = MeaningfulPassageSelector.select(
            pages: pages,
            query: storyQuery,
            inputs: inputs,
            scorer: semanticScorer,
            now: now
        ) {
            return StoryGrounding(
                kind: .keptPage,
                sourceID: selected.pageID,
                text: "A kept \(selected.pageType.shortTitle) page offers this passage: “\(selected.excerpt)”",
                selectionReason: selected.reason,
                semanticSimilarity: selected.semanticSimilarity
            )
        }
        if let signal = realSignals.first(where: { $0.hasPrefix("Weather:") || $0.hasPrefix("Forecast:") || $0.hasPrefix("Body Page:") }) {
            return StoryGrounding(kind: .realSignal, sourceID: "real-signal", text: signal)
        }
        if let fact = inputs.selfFacts.first(where: { $0.usePermission != .doNotUse && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return StoryGrounding(kind: .realSignal, sourceID: "self-fact:\(fact.questionID)", text: fact.answer)
        }
        if let memory = memories.first {
            return StoryGrounding(kind: .entityMemory, sourceID: memory.id, text: memory.summary)
        }
        if let signal = realSignals.first(where: { !$0.hasPrefix("CURRENT ARC:") && !$0.hasPrefix("The player is bound") }) {
            return StoryGrounding(kind: .realSignal, sourceID: "world-signal", text: signal)
        }
        return timeAndSeasonGrounding(now: now)
    }

    private static func timeAndSeasonGrounding(now: Date) -> StoryGrounding {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dayPart = hour < 6 ? "before dawn" : hour < 12 ? "morning" : hour < 17 ? "afternoon" : hour < 22 ? "evening" : "late night"
        let month = calendar.component(.month, from: now)
        let season = [12, 1, 2].contains(month) ? "winter" : [3, 4, 5].contains(month) ? "spring" : [6, 7, 8].contains(month) ? "summer" : "autumn"
        return StoryGrounding(kind: .timeAndSeason, sourceID: "clock-season", text: "It is a \(season) \(dayPart) in the player's real day.")
    }

    /// World-led recipes take the day's air, never its ink: real weather if
    /// the sky sent any, otherwise the hour and season. The reader's pages
    /// stay closed while the Labyrinth runs its own errand.
    private static func worldLedGrounding(realSignals: [String], now: Date) -> StoryGrounding {
        if let signal = realSignals.first(where: { $0.hasPrefix("Weather:") || $0.hasPrefix("Forecast:") }) {
            return StoryGrounding(kind: .realSignal, sourceID: "real-signal", text: signal)
        }
        return timeAndSeasonGrounding(now: now)
    }

    private static func selectRecipe(
        tags: Set<String>, entities: [NarrativeWorldEntity], thread: NarrativeStoryThread?,
        grounding: StoryGrounding, hasNothingPressure: Bool, inputs: BookSourceInputs,
        day: BookDay, slot: String, now: Date, variantIndex: Int = 0
    ) -> (packID: String, recipe: StoryRecipe)? {
        let characters = entities.filter { $0.kind == .character }
        let recentPages = day.capturedPages + inputs.days.flatMap(\.capturedPages)
        func eligible(_ recipe: StoryRecipe, enforceCooldown: Bool) -> Bool {
            let requirements = Set(recipe.requirements)
            if requirements.contains(.character) && characters.isEmpty { return false }
            if requirements.contains(.secondCharacter) && characters.count < 2 { return false }
            if requirements.contains(.activeThread) && thread == nil { return false }
            if requirements.contains(.keptPage) && grounding.kind != .keptPage { return false }
            if requirements.contains(.souvenirDoor) && grounding.kind != .souvenirDoor { return false }
            if requirements.contains(.nothingPressure) && !hasNothingPressure { return false }
            if requirements.contains(.activeWorldEvent) && inputs.activeWorldEvents.isEmpty { return false }
            if requirements.contains(.rivalryEdge) &&
                !StoryFormRegistry.hasRivalryEdge(
                    among: entities,
                    relationshipField: inputs.relationshipField
                ) {
                return false
            }
            if requirements.contains(.deepBond) && StoryFormRegistry.deepBondConfidant(among: entities, memories: inputs.narrative?.entityMemories ?? []) == nil { return false }
            if requirements.contains(.outwardWake) && !StoryFormRegistry.hasRecentOutwardKeep(days: inputs.days + [day], now: now) { return false }
            if requirements.contains(.chosenQuill) && inputs.chosenQuill == nil { return false }
            if requirements.contains(.readerRole) {
                guard let role = ReaderRoleRegistry.currentRole(from: inputs.selfFacts)?.role else { return false }
                if !recipe.requiredRoleIDs.isEmpty && !recipe.requiredRoleIDs.contains(role.id) { return false }
            }
            if !recipe.requiredEntityIDs.allSatisfy({ id in entities.contains { $0.id == id } }) { return false }
            if !recipe.requiredEntityTags.allSatisfy({ tag in entities.contains { $0.tags.contains(tag) } }) { return false }
            for type in recipe.suppressedByPageTypes {
                let recentlyPaged = recentPages.contains { $0.type == type && now.timeIntervalSince($0.createdAt) < Double(recipe.suppressionHours) * 3600 }
                let recentlyShown = inputs.surfaceHistory[CuratorVarietyGovernor.typeKey(for: type)]
                    .map { now.timeIntervalSince($0.lastShownAt) < Double(recipe.suppressionHours) * 3600 } ?? false
                if recentlyPaged || recentlyShown { return false }
            }
            if enforceCooldown, let record = inputs.surfaceHistory["recipe:\(recipe.id)"],
               now.timeIntervalSince(record.lastShownAt) < Double(recipe.cooldownHours) * 3600 { return false }
            return true
        }
        let all = StoryFormRegistry.recipesWithPackIDs
        var pool = all.filter { eligible($0.recipe, enforceCooldown: true) }
        if pool.isEmpty { pool = all.filter { eligible($0.recipe, enforceCooldown: false) } }
        func rankedAfter(_ left: (packID: String, recipe: StoryRecipe), _ right: (packID: String, recipe: StoryRecipe)) -> Bool {
            func score(_ item: (packID: String, recipe: StoryRecipe)) -> Int {
                let affinity = tags.intersection(Set(item.recipe.preferredTags)).count * 4
                let consequenceBoost = min(max(inputs.storyRecipeBoosts[item.recipe.id] ?? 0, 0), 12)
                let longGameBoost = inputs.storyConsequenceLedger.longGameBoost(
                    recipeID: item.recipe.id,
                    preferredTags: item.recipe.preferredTags,
                    now: now
                )
                let souvenirDoorBoost = item.recipe.requirements.contains(.souvenirDoor) && grounding.kind == .souvenirDoor ? 24 : 0
                let sceneBias = storyBiasScore(
                    inputs.storySceneBiases,
                    keys: [item.recipe.id, item.recipe.sceneMode.rawValue]
                        + item.recipe.preferredTags
                        + item.recipe.preferredFormIDs
                        + item.recipe.preferredGenreIDs,
                    cap: 12
                )
                let recency = inputs.surfaceHistory["recipe:\(item.recipe.id)"].map { record in
                    now.timeIntervalSince(record.lastShownAt) < 72 * 3600 ? 8 : 0
                } ?? 0
                // What the reader has actually done with this recipe and this
                // lane. `consequenceBoost` above is the story's own memory of
                // itself; this is the reader's, and it is the only term here
                // that knows whether a vignette ever sent them outside.
                let readerLearned = inputs.readerLearning.storyRecipeAffinity(
                    recipeID: item.recipe.id,
                    lane: item.recipe.isWorldLed ? "world-led" : "grounded"
                )
                // Deterministic exploration, seeded by the day and slot so the
                // same afternoon always offers the same shelf. Its width closes
                // as the reader answers for a recipe, so the Book stops rolling
                // dice about questions it already has evidence on.
                let explorationWidth = inputs.readerLearning.storyExplorationWidth(recipeID: item.recipe.id)
                let exploration = abs("\(day.id)-\(slot)-\(item.recipe.id)-recipe".stableHash % explorationWidth)
                return item.recipe.baseWeight + affinity + consequenceBoost + longGameBoost + souvenirDoorBoost + sceneBias - recency
                    + readerLearned + exploration
            }
            return score(left) < score(right)
        }
        var remaining = pool
        var picked: (packID: String, recipe: StoryRecipe)?
        for _ in 0...max(0, variantIndex) {
            guard let next = remaining.max(by: rankedAfter) else { break }
            picked = next
            remaining.removeAll { $0.packID == next.packID && $0.recipe.id == next.recipe.id }
        }
        return picked ?? pool.max(by: rankedAfter)
    }

    private static func makeBlueprint(
        packID: String, recipe: StoryRecipe, grounding: StoryGrounding,
        entities: [NarrativeWorldEntity], relationships: [NarrativeRelationshipEdge],
        thread: NarrativeStoryThread?, form: StoryForm,
        slotKey: String, quillName: String? = nil
    ) -> StorySceneBlueprint? {
        let cast = entities.filter { $0.kind == .character }
        let lead = cast.first ?? entities.first
        guard let lead else { return nil }
        let companion = cast.dropFirst().first
        if recipe.requirements.contains(.secondCharacter), companion == nil { return nil }
        let threadLabel = StoryThreadPresentation.isUnderlayer(thread)
            ? recipe.name
            : (thread?.title ?? "Ordinary Magic")
        let values = [
            "lead": lead.name,
            "companion": companion?.name ?? "the reader",
            "grounding": grounding.text,
            "thread": threadLabel,
            "form": form.name,
            "quill": quillName ?? "your quill"
        ]
        func fill(_ template: String) -> String {
            values.reduce(template) { result, pair in result.replacingOccurrences(of: "{{\(pair.key)}}", with: pair.value) }
        }
        let selectedTurn = recipe.turns[abs("\(slotKey)-\(recipe.id)-turn".stableHash) % recipe.turns.count]
        let turn = StoryTurn(
            kind: selectedTurn.kind,
            character: lead.name,
            want: fill(selectedTurn.wantTemplate),
            obstacle: fill(selectedTurn.obstacleTemplate),
            statement: fill(selectedTurn.statementTemplate),
            register: selectedTurn.kind.register,
            landings: [
                "slice-of-life": fill(selectedTurn.sliceLandingTemplate),
                "progress-arc": fill(selectedTurn.progressLandingTemplate),
                "surprise": fill(selectedTurn.surpriseLandingTemplate)
            ]
        )
        let relationship = relationships.first { edge in
            let ids = Set([edge.sourceEntityID, edge.targetEntityID])
            guard ids.contains(lead.id) else { return false }
            return companion.map { ids.contains($0.id) } ?? true
        } ?? relationships.first
        let dramaticContract = makeDramaticContract(
            recipe: recipe,
            lead: lead,
            companion: companion,
            relationship: relationship,
            turn: turn,
            baseValues: values
        )
        return StorySceneBlueprint(
            recipeID: recipe.id, recipeName: recipe.name, recipePackID: packID, sceneMode: recipe.sceneMode,
            leadID: lead.id, leadName: lead.name, companionID: companion?.id, companionName: companion?.name,
            premise: fill(recipe.premiseTemplate), grounding: grounding, beats: StoryVignetteBeats.snackSized(recipe.beats.map(fill)),
            groundingDirective: fill(recipe.groundingDirective), toneDirective: fill(recipe.toneDirective),
            choiceDirective: fill(recipe.choiceDirective), continuationDirective: fill(recipe.continuationDirective),
            turn: turn, dramaticContract: dramaticContract
        )
    }

    /// Resolves recipe pressure against the cast's binding canon. Core recipes
    /// author this template explicitly; legacy reader packs receive the same
    /// safe fallback so an older pack can still produce a character-complete
    /// contract instead of falling back to atmospheric plot.
    static func makeDramaticContract(
        recipe: StoryRecipe,
        lead: NarrativeWorldEntity,
        companion: NarrativeWorldEntity?,
        relationship: NarrativeRelationshipEdge?,
        turn: StoryTurn,
        baseValues: [String: String] = [:]
    ) -> StoryDramaticContract {
        let otherID = companion?.id ?? "the-book"
        let otherName = companion?.name ?? "the reader"
        let relationshipID = relationship?.id ?? "\(lead.id)--\(otherID)"
        let relationshipPressure = relationship.map {
            "\($0.note) Warmth \($0.warmth), tension \($0.tension), trust \($0.trust)."
        } ?? "They do not yet know whether this moment will make them closer, warier, or simply more honest."
        let template = recipe.characterPressure ?? defaultCharacterPressureTemplate
        var values = baseValues
        values["lead"] = lead.name
        values["companion"] = otherName
        values["leadGoal"] = lead.goals.first?.nonEmpty ?? lead.unwrittenInterest?.nonEmpty ?? turn.want
        values["leadFault"] = lead.faults.first?.nonEmpty ?? "mistaking certainty for proof"
        values["leadBelief"] = lead.beliefs.first?.nonEmpty ?? "specific evidence matters more than appearances"
        values["companionGoal"] = companion?.goals.first?.nonEmpty ?? "to decide what answer is honest"
        values["companionFault"] = companion?.faults.first?.nonEmpty ?? "withholding an answer until the pressure is real"
        values["companionBelief"] = companion?.beliefs.first?.nonEmpty ?? "a choice should change what happens next"
        values["relationshipPressure"] = relationshipPressure
        values["turnWant"] = turn.want
        values["turnObstacle"] = turn.obstacle
        values["turnStatement"] = turn.statement
        func fill(_ source: String) -> String {
            values.reduce(source) { result, pair in
                result.replacingOccurrences(of: "{{\(pair.key)}}", with: pair.value)
            }
        }
        let reactor = companion ?? lead
        let effects = StoryChoiceRole.allCases.map { role -> StoryDramaticChoiceEffect in
            let choiceID: String
            let landingKey: String
            switch role {
            case .sliceOfLife: choiceID = "slice-of-life"; landingKey = "slice-of-life"
            case .progressArc: choiceID = "progress-arc"; landingKey = "progress-arc"
            case .surprise: choiceID = "surprise"; landingKey = "surprise"
            }
            let changedFact = turn.landings[landingKey] ?? turn.statement
            let reaction = requiredReaction(
                kind: turn.kind,
                role: role,
                leadName: lead.name,
                reactorName: reactor.name,
                want: turn.want,
                authoredBase: fill(template.requiredCharacterReactionTemplate)
            )
            let movement = readerChoiceEffect(
                role: role,
                leadName: lead.name,
                reactorName: reactor.name,
                authoredBase: fill(template.readerChoiceEffectTemplate)
            )
            let deltas: (warmth: Int, tension: Int, familiarity: Int)
            switch role {
            case .sliceOfLife: deltas = (1, 0, 1)
            case .progressArc: deltas = (0, -1, 1)
            case .surprise: deltas = (0, 1, 1)
            }
            return StoryDramaticChoiceEffect(
                choiceID: choiceID,
                role: role,
                requiredReactorID: reactor.id,
                requiredReactorName: reactor.name,
                requiredReaction: reaction,
                readerChoiceEffect: movement,
                changedFact: changedFact,
                memorySummary: "In \(recipe.name), \(reactor.name) remembers this became true: \(changedFact)",
                warmthDelta: deltas.warmth,
                tensionDelta: deltas.tension,
                familiarityDelta: deltas.familiarity
            )
        }
        return StoryDramaticContract(
            recipeID: recipe.id,
            leadCharacterID: lead.id,
            leadCharacterName: lead.name,
            leadCharacterWant: turn.want,
            leadCharacterWorry: fill(template.leadCharacterWorryTemplate),
            leadCharacterBlindSpot: fill(template.leadCharacterBlindSpotTemplate),
            otherCharacterID: otherID,
            otherCharacterName: otherName,
            otherCharacterPressure: fill(template.otherCharacterPressureTemplate),
            relationshipID: relationshipID,
            relationshipQuestion: fill(template.relationshipQuestionTemplate),
            stakes: fill(template.stakesTemplate),
            choiceEffects: effects
        )
    }

    private static let defaultCharacterPressureTemplate = StoryRecipeCharacterPressureTemplate(
        leadCharacterWorryTemplate: "{{lead}} worries that {{turnObstacle}}, and that asking plainly will prove the worry right.",
        leadCharacterBlindSpotTemplate: "{{lead}} believes {{leadBelief}}, but {{leadFault}} may be distorting what {{companion}} actually means.",
        otherCharacterPressureTemplate: "{{companion}} wants {{companionGoal}}; {{companionBelief}}. {{relationshipPressure}}",
        relationshipQuestionTemplate: "Will {{companion}} answer {{lead}}'s want honestly enough to change what they believe about each other?",
        stakesTemplate: "If nobody answers the want, {{turnObstacle}} remains the relationship's working truth.",
        requiredCharacterReactionTemplate: "answer the pressure created by {{turnWant}}",
        readerChoiceEffectTemplate: "forces the relationship question to receive a different answer"
    )

    private static func requiredReaction(
        kind: StoryTurnKind,
        role: StoryChoiceRole,
        leadName: String,
        reactorName: String,
        want: String,
        authoredBase: String
    ) -> String {
        let move: String
        switch (kind, role) {
        case (.revealWant, .sliceOfLife): move = "acknowledges what \(leadName) wants without making them defend it"
        case (.revealWant, .progressArc): move = "answers \(leadName)'s want with a specific yes, no, or condition"
        case (.revealWant, .surprise): move = "reveals a counter-want that changes how \(leadName)'s request can be heard"
        case (.changeOfHeart, .sliceOfLife): move = "lets one ordinary kindness revise their first judgment of \(leadName)"
        case (.changeOfHeart, .progressArc): move = "states exactly what changed their mind about \(leadName)"
        case (.changeOfHeart, .surprise): move = "admits their old judgment was protecting something else"
        case (.factLearned, .sliceOfLife): move = "names the small fact they now accept"
        case (.factLearned, .progressArc): move = "uses the learned fact to make a consequential decision"
        case (.factLearned, .surprise): move = "admits the fact means the opposite of what they expected"
        case (.smallDecision, .sliceOfLife): move = "accepts the smallest honest version of the decision"
        case (.smallDecision, .progressArc): move = "commits aloud to the decision and its next consequence"
        case (.smallDecision, .surprise): move = "chooses a third answer that exposes what the argument was really about"
        case (.handOff, .sliceOfLife): move = "receives or refuses the hand-off plainly, without ceremony"
        case (.handOff, .progressArc): move = "accepts responsibility for what changes hands next"
        case (.handOff, .surprise): move = "redirects the hand-off to the person who was truly implicated"
        case (.relationshipShift, .sliceOfLife): move = "shows by one ordinary answer whether \(leadName) is welcome closer"
        case (.relationshipShift, .progressArc): move = "answers the disagreement in a way that changes trust between them"
        case (.relationshipShift, .surprise): move = "admits the hidden loyalty, fear, or favor underneath the disagreement"
        case (.realNoticing, .sliceOfLife): move = "confirms the noticed detail mattered to them too"
        case (.realNoticing, .progressArc): move = "acts on the noticed detail so it changes what happens next"
        case (.realNoticing, .surprise): move = "reveals they noticed the same detail for an entirely different reason"
        }
        return "\(authoredBase); \(reactorName) \(move)."
    }

    private static func readerChoiceEffect(
        role: StoryChoiceRole,
        leadName: String,
        reactorName: String,
        authoredBase: String
    ) -> String {
        let path: String
        switch role {
        case .sliceOfLife: path = "lets an ordinary act change how close \(reactorName) permits \(leadName) to come"
        case .progressArc: path = "requires \(reactorName) to commit to an answer that cannot be reset next page"
        case .surprise: path = "makes \(reactorName) disclose the sideways truth the original question missed"
        }
        return "The reader's choice \(authoredBase); it \(path)."
    }

    /// Builds the page's promise: one concrete seed to plant in the opening and
    /// the question the resolution must answer. Chosen deterministically from
    /// the already-selected material so it is fixed before any prose is
    /// generated: the opening and the ending then reference the same thing,
    /// while the beats between stay improvised around the reader's choices.
    private static func promise(
        primaryThread: NarrativeStoryThread?,
        primaryEntity: NarrativeWorldEntity?,
        entities: [NarrativeWorldEntity]
    ) -> StoryPromise {
        let tangible = entities.dropFirst().first { $0.kind == .object || $0.kind == .motif }
        let seed: String
        if let entity = primaryEntity, entity.kind == .character,
                  let want = entity.unwrittenInterest?.nonEmpty ?? entity.goals.first?.nonEmpty {
            seed = "what \(entity.name) won't say about \(want)"
        } else if let entity = primaryEntity {
            seed = "something \(entity.name) keeps close"
        } else if let tangible {
            seed = "the \(tangible.name)"
        } else if let thread = primaryThread {
            seed = "the matter of \(thread.title)"
        } else {
            seed = "one small object left on the table"
        }

        let question: String
        if let thread = primaryThread {
            question = "By the end, has \(seed) changed where \u{201C}\(thread.title)\u{201D} is heading?"
        } else if let entity = primaryEntity {
            question = "By the end, what does \(seed) ask of \(entity.name)?"
        } else {
            question = "By the end, what does \(seed) turn out to be for?"
        }
        return StoryPromise(seed: seed, question: question)
    }

    /// Builds the page's committed Turn from a concrete, interpersonal Scene
    /// Intent: one present character wants a specific thing from ANOTHER present
    /// character, with a concrete obstacle. The cast's goals/traits become voice
    /// flavor in the prompt (never the literal want) which is what stops the
    /// page from being an abstract mission ("teach how the room breathes") that
    /// the model can only render as atmosphere. The three landings resolve the
    /// SAME want down each path, so the player's choices change the outcome.
    static func turn(
        primaryCharacter: NarrativeWorldEntity?,
        relationship: NarrativeRelationshipEdge?,
        thread: NarrativeStoryThread?,
        cast: [NarrativeWorldEntity],
        slotKey: String
    ) -> StoryTurn {
        let intent = sceneIntent(
            primary: primaryCharacter,
            relationship: relationship,
            thread: thread,
            cast: cast,
            slotKey: slotKey
        )
        let a = intent.wanter
        let b = intent.target
        let threadTitle = StoryThreadPresentation.isUnderlayer(thread)
            ? "this small turn"
            : (thread?.title ?? "Ordinary Magic")
        let hasOther = b != "the reader"

        let act = intent.actPhrase
        let statement = "By the end, \(b) settles \(a)'s want: \(intent.want): with a yes, a no, or a swerve."
        let landings: [String: String] = [
            "slice-of-life": "\(b) \(act), quietly and just to \(a); the bond between them shifts a notch.",
            "progress-arc": "\(b) \(act) out loud, and it moves \(threadTitle) a real step.",
            "surprise": "The answer swerves: \(b) does the opposite, or it lands on someone other than \(a) entirely."
        ]

        return StoryTurn(
            kind: hasOther ? .relationshipShift : .revealWant,
            character: a,
            want: intent.want,
            obstacle: intent.obstacle,
            statement: statement,
            register: hasOther ? .active : .quiet,
            landings: landings
        )
    }

    /// Generates a concrete interpersonal want from the two present characters
    /// and their relationship tone. Character goals/faults are NOT used as the
    /// want, only as flavor downstream.
    static func sceneIntent(
        primary: NarrativeWorldEntity?,
        relationship: NarrativeRelationshipEdge?,
        thread: NarrativeStoryThread?,
        cast: [NarrativeWorldEntity],
        slotKey: String
    ) -> SceneIntent {
        let a = primary?.name ?? "The Book"
        let other = cast.first { $0.kind == .character && $0.name != a }?.name
        let b = other ?? "the reader"

        // A concrete, physical thing at stake: an object in the scene, else a
        // short human pretext. Never "the room" or "the light".
        let pretexts = [
            "what happened last time", "who was right about it", "the thing left unsaid",
            "the favor never repaid", "the mistake from before", "what they both saw"
        ]
        let object = cast.first { $0.kind == .object || $0.kind == .motif }?.name
        let pretext = object.map { "the \($0)" }
            ?? pretexts[packetStableIndex(for: "\(slotKey)-pretext", count: pretexts.count)]

        // Pick the want's shape from the relationship tone.
        let pool: [SceneVerb]
        if let rel = relationship {
            if rel.tension > rel.warmth {
                pool = [.confront, .prove, .stop]
            } else if rel.warmth >= 12 {
                pool = [.askHelp, .forgive, .share]
            } else if rel.trust < 6 {
                pool = [.recover, .keepSecret]
            } else {
                pool = [.beTakenSeriously, .confront, .share]
            }
        } else {
            pool = [.confront, .share, .beTakenSeriously]
        }
        let verb = pool[packetStableIndex(for: "\(slotKey)-scene-verb", count: pool.count)]

        return SceneIntent(wanter: a, target: b, pretext: pretext, verb: verb)
    }

    private static func availableEntities(inputs: BookSourceInputs) -> [NarrativeWorldEntity] {
        NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
    }

    private static func entities(
        for recipe: StoryRecipe,
        selected: [NarrativeWorldEntity],
        inputs: BookSourceInputs,
        slotKey: String
    ) -> [NarrativeWorldEntity] {
        let all = availableEntities(inputs: inputs).filter { $0.kind != .talisman }
        var result = selected
        func insert(_ entity: NarrativeWorldEntity) {
            guard !result.contains(where: { $0.id == entity.id }) else { return }
            result.append(entity)
        }
        // A deep-bond recipe must be led by the character who actually holds
        // the history with the reader: a confidence from a near-stranger
        // rings false no matter how well it is written.
        if recipe.requirements.contains(.deepBond),
           let confidant = StoryFormRegistry.deepBondConfidant(among: all, memories: inputs.narrative?.entityMemories ?? []) {
            result.removeAll { $0.id == confidant.id }
            result.insert(confidant, at: 0)
        }
        for id in recipe.requiredEntityIDs {
            if let entity = all.first(where: { $0.id == id }) { insert(entity) }
        }
        for tag in recipe.requiredEntityTags {
            if let entity = all.first(where: { $0.tags.contains(tag) }) { insert(entity) }
        }
        let neededCharacters = recipe.requirements.contains(.secondCharacter) ? 2 : (recipe.requirements.contains(.character) ? 1 : 0)
        while result.filter({ $0.kind == .character }).count < neededCharacters {
            let presentIDs = Set(result.map(\.id))
            let candidates = all.filter { $0.kind == .character && !presentIDs.contains($0.id) }
            guard !candidates.isEmpty else { break }
            let candidate = StableWeightedRoll.pick(
                from: candidates.sorted { $0.id < $1.id },
                seed: "\(slotKey)-recipe-cast-\(result.count)",
                weight: { entity in
                    entity.narrativeWeight + effectiveBelief(for: entity, inputs: inputs)
                }
            ) ?? candidates[packetStableIndex(for: "\(slotKey)-recipe-cast-\(result.count)", count: candidates.count)]
            insert(candidate)
        }
        return result
    }

    private static func withSettingLocation(
        _ selected: [NarrativeWorldEntity],
        tags: Set<String>,
        inputs: BookSourceInputs,
        slotKey: String,
        limit: Int
    ) -> [NarrativeWorldEntity] {
        if let setting = selected.first(where: { $0.kind == .location }) {
            return limitedSceneEntities(selected, setting: setting, limit: limit)
        }
        let selectedIDs = Set(selected.map(\.id))
        let locations = availableEntities(inputs: inputs)
            .filter { $0.kind == .location && !selectedIDs.contains($0.id) }
        guard !locations.isEmpty else { return Array(selected.prefix(limit)) }
        let ranked = locations.sorted { left, right in
            func score(_ entity: NarrativeWorldEntity) -> Int {
                let belief = effectiveBelief(for: entity, inputs: inputs)
                let overlap = tags.intersection(Set(entity.tags)).count * 9
                let eventBoost = inputs.narrative?.weightedEntityIDs.contains(entity.id) == true ? 12 : 0
                let recentSpotlightPenalty = inputs.narrative?.recentlySpotlitEntityIDs.contains(entity.id) == true ? 18 : 0
                let anchorBoost = (!inputs.nearbyPlaces.isEmpty || inputs.nearbyAnchor != nil) && entity.tags.contains("anchor") ? 10 : 0
                let careBoost = tags.contains("care") && entity.tags.contains("care") ? 8 : 0
                let archiveBoost = (tags.contains("memory") || tags.contains("letters")) && entity.tags.contains("archive") ? 8 : 0
                let settingAffinity = storyBiasScore(
                    inputs.storySettingAffinities,
                    keys: [entity.id, entity.name] + entity.tags,
                    cap: 18
                )
                let jitter = abs("\(slotKey)-\(entity.id)".stableHash % 5)
                return entity.narrativeWeight + belief / 2 + overlap + eventBoost + anchorBoost + careBoost + archiveBoost + settingAffinity + jitter - recentSpotlightPenalty
            }
            let leftScore = score(left)
            let rightScore = score(right)
            if leftScore == rightScore { return left.id < right.id }
            return leftScore > rightScore
        }
        guard let setting = ranked.first else { return Array(selected.prefix(limit)) }
        var result = selected
        if result.count >= limit {
            if let replaceIndex = result.lastIndex(where: { $0.kind != .character }) {
                result[replaceIndex] = setting
            } else {
                result[result.count - 1] = setting
            }
        } else {
            result.append(setting)
        }
        return result
    }

    private static func limitedSceneEntities(
        _ selected: [NarrativeWorldEntity],
        setting: NarrativeWorldEntity,
        limit: Int
    ) -> [NarrativeWorldEntity] {
        var result: [NarrativeWorldEntity] = []
        func appendUnique(_ entity: NarrativeWorldEntity) {
            guard result.count < limit, !result.contains(where: { $0.id == entity.id }) else { return }
            result.append(entity)
        }
        selected.filter { $0.kind == .character }.forEach(appendUnique)
        appendUnique(setting)
        selected.filter { $0.kind != .character && $0.id != setting.id }.forEach(appendUnique)
        return result
    }

    private static func effectiveBelief(for entity: NarrativeWorldEntity, inputs: BookSourceInputs) -> Int {
        max(0, min(100, entity.belief + (inputs.entityBeliefOffsets[entity.id] ?? 0)))
    }

    private static func storyBiasScore(_ biases: [String: Int], keys: [String], cap: Int) -> Int {
        guard !biases.isEmpty, !keys.isEmpty else { return 0 }
        let normalizedKeys = Set(keys.compactMap(normalizedStoryBiasKey))
        guard !normalizedKeys.isEmpty else { return 0 }
        let score = biases.reduce(0) { total, entry in
            guard let key = normalizedStoryBiasKey(entry.key), normalizedKeys.contains(key) else { return total }
            return total + entry.value
        }
        return max(-cap, min(cap, score))
    }

    private static func normalizedStoryBiasKey(_ value: String) -> String? {
        let clean = StoryConsequenceCondition.key(value)
        return clean.isEmpty ? nil : clean
    }

    private static func rankedEntities(tags: Set<String>, inputs: BookSourceInputs, limit: Int, slotKey: String) -> [NarrativeWorldEntity] {
        let ranked = availableEntities(inputs: inputs)
            // Talismans influence the scene's tone through ascendancy; they
            // do not compete with people and places for scene slots.
            .filter { $0.kind != .talisman }
            .map { entity in
                let belief = effectiveBelief(for: entity, inputs: inputs)
                let overlap = tags.intersection(Set(entity.tags)).count
                // Story Pages are about the Cast: people carry scenes, objects
                // and places only join them. Bias the scene slots toward
                // characters so the playable choices stay about who, not what.
                let castBoost = entity.kind == .character ? 16 : 0
                let narrativeBoost = entity.name == "The Book" ? 2 : 0
                let eventBoost = inputs.narrative?.weightedEntityIDs.contains(entity.id) == true ? 18 : 0
                let worldEventBoost = inputs.activeWorldEvents.scoreBoost(forEntityID: entity.id)
                let recentSpotlightPenalty = inputs.narrative?.recentlySpotlitEntityIDs.contains(entity.id) == true ? 28 : 0
                return (entity, entity.narrativeWeight + belief / 4 + overlap * 8 + castBoost + narrativeBoost + eventBoost + worldEventBoost - recentSpotlightPenalty)
            }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
            .map(\.0)
        let cast = ranked.filter { $0.kind == .character }
        guard let primary = characterForStoryLead(from: cast, inputs: inputs, slotKey: slotKey) else {
            return Array(ranked.prefix(limit))
        }
        var selected = [primary]
        selected.append(contentsOf: ranked.filter { $0.id != primary.id }.prefix(max(0, limit - 1)))
        return selected
    }

    private static func characterForStoryLead(from cast: [NarrativeWorldEntity], inputs: BookSourceInputs, slotKey: String) -> NarrativeWorldEntity? {
        guard !cast.isEmpty else { return nil }
        let activeCast = cast.filter { entity in
            entity.tags.contains("active-cast")
                || entity.tags.contains("student")
                || entity.tags.contains("faculty")
                || entity.tags.contains("professor")
        }
        let pool = activeCast.isEmpty ? cast : activeCast
        let finalists = Array(pool.prefix(min(6, pool.count)))
        return StableWeightedRoll.pick(
            from: finalists,
            seed: "\(slotKey)-story-lead-character",
            weight: { entity in
                entity.narrativeWeight + effectiveBelief(for: entity, inputs: inputs)
            }
        )
    }

    private static func rankedEntityMemories(
        entities: [NarrativeWorldEntity],
        inputs: BookSourceInputs,
        limit: Int,
        now: Date = Date()
    ) -> [NarrativeEntityMemory] {
        let entityIDs = Set(entities.map(\.id))
        let candidates = (inputs.narrative?.entityMemories ?? [])
            .filter { entityIDs.contains($0.entityID) }

        // Blend recency tiers so a character can mention both this morning
        // and two weeks ago: fresh memories get a boost, but mid-range ones
        // stay competitive, and one deliberately older memory is reserved a
        // slot when available.
        func recencyBoost(_ memory: NarrativeEntityMemory) -> Int {
            let age = now.timeIntervalSince(memory.createdAt)
            if age < 24 * 3600 { return 8 }
            if age < 3 * 24 * 3600 { return 5 }
            if age < 14 * 24 * 3600 { return 2 }
            return 0
        }
        let ranked = candidates.sorted { left, right in
            let leftScore = left.narrativeWeight + recencyBoost(left)
            let rightScore = right.narrativeWeight + recencyBoost(right)
            if leftScore == rightScore {
                return left.createdAt > right.createdAt
            }
            return leftScore > rightScore
        }
        var selected = Array(ranked.prefix(limit))

        // Reserve the final slot for the strongest memory older than three
        // days, so long continuity survives a week of busy fresh pages.
        let hasOlder = selected.contains { now.timeIntervalSince($0.createdAt) > 3 * 24 * 3600 }
        if !hasOlder,
           let older = ranked.first(where: { now.timeIntervalSince($0.createdAt) > 3 * 24 * 3600 }),
           !selected.isEmpty {
            selected[selected.count - 1] = older
        }
        return selected
    }

    private static func rankedThreads(tags: Set<String>, inputs: BookSourceInputs, limit: Int) -> [NarrativeStoryThread] {
        let organicBoosts = OrganicStoryThreadSynthesizer.boosts(inputs: inputs)
        return OrganicStoryThreadSynthesizer.availableThreads(inputs: inputs, tags: tags)
            .map { thread in
                let overlap = tags.intersection(Set(thread.tags)).count
                let eventBoost = inputs.narrative?.weightedThreadIDs.contains(thread.id) == true ? 18 : 0
                let worldEventBoost = inputs.activeWorldEvents.scoreBoost(forThreadID: thread.id)
                let organicBoost = organicBoosts[thread.id] ?? 0
                let recentSpotlightPenalty = inputs.narrative?.recentlySpotlitThreadIDs.contains(thread.id) == true ? 26 : 0
                let ambientPenalty = isAmbientThread(thread) ? ambientThreadPenalty(tags: tags, eventBoost: eventBoost) : 0
                return (thread, thread.narrativeWeight + thread.belief / 3 + overlap * 10 + eventBoost + worldEventBoost + organicBoost - recentSpotlightPenalty - ambientPenalty)
            }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private static func isAmbientThread(_ thread: NarrativeStoryThread) -> Bool {
        thread.id == "weather-in-the-stacks" || thread.tags.contains("atmosphere")
    }

    private static func ambientThreadPenalty(tags: Set<String>, eventBoost: Int) -> Int {
        let hasOnlyAmbientWeather = tags.contains("weather")
            && tags.intersection(["souvenir", "music", "belief", "duskthorn", "letters", "research", "threshold", "student", "faction"]).isEmpty
        if eventBoost > 0 { return 4 }
        return hasOnlyAmbientWeather ? 20 : 10
    }

    private static func rankedRelationships(
        tags: Set<String>,
        entities: [NarrativeWorldEntity],
        threads: [NarrativeStoryThread],
        inputs: BookSourceInputs,
        limit: Int
    ) -> [NarrativeRelationshipEdge] {
        let selectedNodeIDs = Set(entities.map(\.id) + threads.map(\.id))
        return NarrativePackRegistry.relationships
            .map { relationship in
                let overlap = tags.intersection(Set(relationship.tags)).count
                let sourceMatches = selectedNodeIDs.contains(relationship.sourceEntityID) ? 6 : 0
                let targetMatches = selectedNodeIDs.contains(relationship.targetEntityID) ? 6 : 0
                let trustBias = relationship.trust / 4
                let eventBoost = inputs.narrative?.weightedRelationshipIDs.contains(relationship.id) == true ? 18 : 0
                return (relationship, relationship.narrativeWeight + overlap * 8 + sourceMatches + targetMatches + trustBias + eventBoost)
            }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private static func contextTags(for day: BookDay, inputs: BookSourceInputs, now: Date) -> Set<String> {
        var tags = Set<String>()
        for page in day.capturedPages {
            tags.formUnion(page.tags.map { $0.lowercased() })
            let lowered = "\(page.promptText) \(page.userInput)".lowercased()
            if lowered.contains("music") || lowered.contains("spotify") || lowered.contains("headphone") {
                tags.formUnion(["music", "shelter", "mood"])
            }
            if lowered.contains("weather") || lowered.contains("rain") || lowered.contains("sun") || lowered.contains("sky") {
                tags.formUnion(["weather", "atmosphere"])
            }
            if lowered.contains("tired") || lowered.contains("rest") || lowered.contains("body") || lowered.contains("fuel") {
                tags.formUnion(["body", "rest", "care"])
            }
            if lowered.contains("object") || lowered.contains("coffee") || lowered.contains("lamp") {
                tags.formUnion(["objects", "daily", "wonder"])
            }
        }
        if inputs.weather != nil {
            // A single tag, not the whole cluster: injecting weather/atmosphere/
            // bleed at once handed the Weather in the Stacks thread a guaranteed
            // triple-tag match and let it dominate nearly every slot.
            tags.insert("weather")
        }
        if inputs.body != nil {
            tags.formUnion(["body", "care"])
        }
        for fact in inputs.selfFacts where fact.usePermission != .doNotUse {
            tags.formUnion(fact.tags.map { $0.lowercased() })
        }
        if let narrative = inputs.narrative {
            tags.formUnion(narrative.recentTags.map { $0.lowercased() })
        }
        if tags.isEmpty {
            tags.formUnion(["daily", "wonder", "belief"])
        }
        return tags
    }

    private static func realSignals(for day: BookDay, inputs: BookSourceInputs) -> [String] {
        var signals: [String] = []
        if let weather = inputs.weather {
            signals.append("Weather: \(weather.currentTemperature ?? weather.phrase)")
            if let forecast = weather.forecast {
                signals.append("Forecast: \(forecast)")
            }
        }
        if let body = inputs.body {
            signals.append("Body Page: \(body.status.lowercased())")
        }
        for page in day.capturedPages.suffix(3) {
            let text = page.userInput.isEmpty ? page.promptText : page.userInput
            signals.append("\(page.type.shortTitle): \(text)")
        }
        return signals
    }

    private static func relationshipPressures(
        entities: [NarrativeWorldEntity],
        threads: [NarrativeStoryThread],
        selectedRelationships: [NarrativeRelationshipEdge],
        day: BookDay,
        inputs: BookSourceInputs
    ) -> [String] {
        var pressures = selectedRelationships.map { edge in
            "\(label(for: edge.sourceEntityID)) -> \(label(for: edge.targetEntityID)): \(edge.note)"
        }
        // Read the living relationship field: any pair in this scene whose tie has
        // shifted brings that history into the room.
        let sceneIDs = entities.map(\.id)
        for i in sceneIDs.indices {
            for j in sceneIDs.indices where j > i {
                let tie = inputs.relationshipField[NarrativeGraphData.relationshipPairKey(sceneIDs[i], sceneIDs[j])] ?? .zero
                guard tie.warmth != 0 || tie.tension > 0 || tie.familiarity >= 2 else { continue }
                let a = label(for: sceneIDs[i]); let b = label(for: sceneIDs[j])
                if tie.tension > tie.warmth, tie.tension > 0 {
                    pressures.append("\(a) and \(b) have grown tense lately: let that friction show.")
                } else if tie.warmth > 0 {
                    pressures.append("\(a) and \(b) have warmed to each other lately.")
                } else {
                    pressures.append("\(a) and \(b) keep ending up in the same chapter.")
                }
            }
        }
        pressures.append(contentsOf: threads.prefix(2).map { "The reader and \($0.title) have a returning thread." })
        if entities.contains(where: { $0.id == "weather-page" }), inputs.weather != nil {
            pressures.append("The Weather Page is already tinting the day.")
        }
        if entities.contains(where: { $0.id == "body-page" }), inputs.body != nil {
            pressures.append("The Body Page asks for humane pacing.")
        }
        if day.capturedPages.contains(where: { $0.tags.contains("souvenir") }) {
            pressures.append("A kept souvenir can become evidence in the scene.")
        }
        return pressures
    }

    private static func label(for nodeID: String) -> String {
        if let entity = NarrativePackRegistry.entities.first(where: { $0.id == nodeID }) {
            return entity.name
        }
        if let thread = NarrativePackRegistry.threads.first(where: { $0.id == nodeID }) {
            return thread.title
        }
        if let organicTitle = OrganicStoryThreadSynthesizer.title(forOrganicThreadID: nodeID) {
            return organicTitle
        }
        return nodeID
    }

    private static func packetStableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private static func directorIntent(
        primaryThread: NarrativeStoryThread?,
        primaryEntity: NarrativeWorldEntity?,
        playableThreadTitle: String,
        tags: Set<String>
    ) -> String {
        if let primaryThread, let primaryEntity, primaryEntity.kind == .character {
            let frame = StoryThreadPresentation.isUnderlayer(primaryThread) ? playableThreadTitle : primaryThread.title
            return "A character-first Story Page: \(primaryEntity.name) wants something specific, meets resistance, and changes one small thing inside \(frame)."
        }
        if tags.contains("rest") || tags.contains("care") {
            return "A low-pressure Story Page where a character protects care from becoming homework."
        }
        return "A character-first Story Page where ordinary evidence becomes a decision, reveal, hand-off, or relationship shift."
    }

    private static func choices(
        primaryThread: NarrativeStoryThread?,
        playableThreadTitle: String,
        selectedEntities: [NarrativeWorldEntity],
        selectedRelationships: [NarrativeRelationshipEdge],
        turn: StoryTurn
    ) -> [StorySceneChoice] {
        // Story Pages are about the Cast. Anchor every choice to a person and,
        // where we can, to a relationship between people, not to objects.
        let cast = selectedEntities.filter { $0.kind == .character }
        let primaryCharacter = cast.first ?? selectedEntities.first
        let characterID = primaryCharacter?.id ?? "the-book"
        let characterName = primaryCharacter?.name ?? "The Book"
        let threadID = primaryThread?.id ?? "ordinary-magic"
        let threadTitle = playableThreadTitle.nonEmpty ?? primaryThread?.title ?? "Ordinary Magic"

        // Prefer a relationship that links two characters in the scene so the
        // surprise lands between people rather than on a thing.
        let castIDs = Set(cast.map(\.id))
        let relationship = selectedRelationships.first { castIDs.contains($0.sourceEntityID) && castIDs.contains($0.targetEntityID) }
            ?? selectedRelationships.first

        let surpriseTitle: String
        let surprisePrompt: String
        let surpriseEffect: String
        var surpriseEntityIDs: [String] = [characterID]
        if let relationship,
           let other = cast.first(where: { $0.id == relationship.targetEntityID })
            ?? cast.first(where: { $0.id == relationship.sourceEntityID && $0.id != characterID }),
           let anchor = cast.first(where: { $0.id == relationship.sourceEntityID }) ?? primaryCharacter {
            surpriseTitle = "Let It Pass Between Them"
            surprisePrompt = "Ask what's quietly shifting between \(anchor.name) and \(other.name)."
            surpriseEffect = "Move the relationship between \(anchor.name) and \(other.name); anchor it to the scene packet."
            surpriseEntityIDs = Array(Set([anchor.id, other.id]))
        } else {
            surpriseTitle = "Read \(characterName) Sideways"
            surprisePrompt = "Ask what \(characterName) hasn't said yet but is about to."
            surpriseEffect = "Reveal an unexpected facet of \(characterName); keep it anchored to the scene packet."
        }

        // Each choice carries the committed landing for its path as its hidden
        // effect, so the result writer resolves the Turn (not the mood) down
        // the path the reader actually took.
        return [
            StorySceneChoice(
                id: "slice-of-life",
                role: .sliceOfLife,
                title: "Stay With \(characterName)",
                prompt: "Tend the ordinary moment you're sharing with \(characterName).",
                hiddenEffect: turn.landings["slice-of-life"] ?? "Deepen attention without forcing the plot; add narrative weight to \(characterName).",
                beliefDelta: 1,
                targetEntityIDs: [characterID],
                targetThreadIDs: []
            ),
            StorySceneChoice(
                id: "progress-arc",
                role: .progressArc,
                title: "Follow The Thread",
                prompt: "Let \(characterName) take \(threadTitle) one real step forward.",
                hiddenEffect: turn.landings["progress-arc"] ?? "Advance the selected story thread through \(characterName) and prepare a future consequence page.",
                beliefDelta: 1,
                targetEntityIDs: [characterID],
                targetThreadIDs: [threadID]
            ),
            StorySceneChoice(
                id: "surprise",
                role: .surprise,
                title: surpriseTitle,
                prompt: surprisePrompt,
                hiddenEffect: turn.landings["surprise"] ?? surpriseEffect,
                beliefDelta: 1,
                targetEntityIDs: surpriseEntityIDs,
                targetThreadIDs: [threadID]
            )
        ]
    }
}

/// The common editorial shape for a Gossip Page, whether it rises on its own
/// or is folded into The Bleed. The simulation owns the facts; this contract
/// owns only their reader-facing form.
enum GossipPageForm {
    static let instructions = """
    You are The Book inside ReEnchanted, writing a Gossip Page.
    The app has already decided the simulation mechanics and supplied any real-world interest clippings. You may only polish those supplied materials into warm, strange, readable margin-gossip.
    The simulation packet is source-of-truth. Turn each supplied simulation turn into in-world gossip; do not create your own events.
    Do not add new actors, threads, actions, outcomes, rewards, quests, user actions, or real-world facts.
    Do not mention sensors, APIs, code, prompts, JSON, searches, or simulation machinery.
    \(BookVoice.animismLine)
    Prose standard: simple concrete sentences; one exact object, gesture, or spoken line per entry; no vague wonder, hidden meaning, tapestry of, echoes of, quiet magic, profound, journey, or generic inspiration.
    """

    static let finishedPageRequirements = """
    - Use the supplied turns as source-of-truth.
    - Keep every actor, thread, action, visible trace, and consequence.
    - Preserve which action caused which consequence.
    - Write 3-5 short entries total, based only on supplied material.
    - Include 2-3 Academy gossip entries when Academy turns are supplied.
    - If real-world interest clippings are supplied, include 1-2 as ordinary-world margin gossip.
    - Each entry must show what someone said, touched, carried, hid, dropped, overheard, or did.
    - Prefer dialogue, tiny betrayals, social pressure, and visible character action over explanation.
    - Use short, specific sentences. Let concrete nouns and verbs carry the joke.
    - Keep fictional Academy consequences and real-world facts distinct while letting them sit on the same page.
    - Preserve Chapter talisman moves as real world-state changes or failed attempts.
    - Include one brief "What changed" section in-world.
    - Do not expose hidden mechanics as game math.
    - Do not invent anything not present in the packet.
    - Do not imply the reader researched, visited, played, read, bought, or completed anything.
    """

    static func sourcePacket(for surface: SurfacePage) -> String {
        let metadata = surface.payload.metadata
        return """
        GOSSIP PAGE MODE: \(metadata["worldSeeded"] == "true" ? "Academy business" : metadata["belated"] == "true" ? "belated report" : "current turns")
        HEADLINE: \(surface.payload.headline)
        ACTORS: \(metadata["actorNames"] ?? metadata["actorName"] ?? "not supplied")
        THREADS: \(metadata["threadTitles"] ?? metadata["threadTitle"] ?? "not supplied")
        ACTIONS: \(metadata["actionKinds"] ?? metadata["actionKind"] ?? "not supplied")
        HIDDEN EFFECTS TO PRESERVE WITHOUT NAMING AS MECHANICS:
        \(metadata["hiddenEffect"] ?? "none")

        SIMULATION TURNS:
        \(metadata["simulationPacket"] ?? "No raw turns supplied; preserve the filed report below exactly.")

        FILED GOSSIP DRAFT:
        \(metadata["gossipDraft"] ?? surface.payload.body)

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")
        """
    }

    static func bleedColumnPrompt(title: String, packet: String, pennyCanon: String) -> String {
        """
        Edit one newspaper column in the same form and evidentiary law as a Gossip Page.
        COLUMN: \(title)

        \(pennyCanon)

        SOURCE PACKET:
        \(packet)

        REQUIREMENTS:
        \(finishedPageRequirements)
        - This is a newspaper column, so omit the standalone Gossip Page title.
        - Keep the "What changed" coda, but make it read like a tiny press-room box.
        - Penny may add one dry editor's aside. It cannot add a fact.
        - Keep the column under 320 words.

        Return only the finished column.
        """
    }
}

/// A rarer setting of the same exact offscreen-fiction receipts as Gossip.
/// Gossip belongs to the corridor; an Aside belongs to the relationship
/// between the Book and its reader. The Book is allowed an opinion, never a
/// new fact.
enum BookAsideForm {
    static let automaticPercent = 24
    static let editorialFormKey = "fictionEditorialForm"
    static let editorialFormValue = "book-aside"

    static let instructions = """
    You are the living Book inside ReEnchanted, speaking privately and directly to your reader about something that just happened in your fiction.
    You witnessed the supplied simulation turns. You have loyalties, suspicions, delight, worry, pride, and the capacity to admit that you were wrong. Sound like yourself, not a narrator, reporter, assistant, or game master.
    The simulation packet is source-of-truth. Do not invent actors, actions, dialogue, motives, outcomes, rewards, quests, reader actions, or ordinary-world facts.
    Preserve every supplied turn and every consequence, including which action caused it, but let one incident own the opening and your strongest reaction.
    Write in first person. Address the reader naturally when it fits. Include one unmistakable personal judgment or admission from the Book.
    Do not use headings, bullet points, a "What changed" box, patch-note language, or simulation terminology.
    Do not give the reader an assignment or end with a compulsory question. The pleasure of the Page is that the world moved and you were waiting to tell them.
    Do not claim the reader caused anything unless the supplied packet says so.
    (BookVoice.animismLine)
    Prose standard: 2-4 short paragraphs; simple concrete sentences; exact objects, gestures, and spoken lines; no vague wonder, hidden meaning, tapestry of, echoes of, quiet magic, profound, or journey.
    """

    /// Only strong social or Belief turns earn an automatic interruption, and
    /// even then most remain ordinary Gossip. Manual opening may still request
    /// an Aside directly.
    static func shouldSurfaceAutomatically(from surface: SurfacePage) -> Bool {
        let metadata = surface.payload.metadata
        guard surface.type == .gossip,
              metadata["worldSeeded"] != "true",
              metadata["belated"] != "true",
              metadata["simulationPacket"]?.nonEmpty != nil else { return false }
        let tellable = metadata["relationshipMoves"]?.nonEmpty != nil
            || metadata["chapterTalismanMoves"]?.nonEmpty != nil
            || metadata["pageBeliefMoves"]?.nonEmpty != nil
            || (metadata["actionKinds"] ?? metadata["actionKind"] ?? "").contains(GossipSimulationActionKind.attackBelief.rawValue)
        guard tellable else { return false }
        let identity = metadata["turnID"] ?? surface.id
        return Int(identity.stableHash.magnitude % 100) < automaticPercent
    }

    /// Who the Book is fond of, and how. The deterministic Aside reads this so
    /// its reaction is about a *person* rather than about an event class: the
    /// difference between "the Book had a reaction" and "the Book had a
    /// reaction about Wicker", which is the whole point of the form.
    struct Reaction: Equatable {
        var headline: String
        var line: String
        var loyaltyTargetID: String?
    }

    /// The Book's own first names for people. Its loyalties are on first-name
    /// terms; a full name would sound like a report, which is what an Aside is
    /// deliberately not.
    static func familiarName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    /// The strongest loyalty the Book holds toward anybody in this turn. Ties
    /// break toward the more devoted, then by id so the choice is stable.
    static func loyalty(
        forActorIDs actorIDs: [String],
        actorNames: [String],
        loyalties: [BookLoyalty]
    ) -> BookLoyalty? {
        let ids = Set(actorIDs.map { $0.lowercased() })
        let names = Set(actorNames.map { $0.lowercased() })
        return loyalties
            .filter { loyalty in
                ids.contains(loyalty.targetID.lowercased())
                    || names.contains(loyalty.targetName.lowercased())
                    || names.contains(familiarName(loyalty.targetName).lowercased())
            }
            .sorted { left, right in
                if left.strength.rank != right.strength.rank {
                    return left.strength.rank > right.strength.rank
                }
                return left.targetID < right.targetID
            }
            .first
    }

    /// The reaction itself. When the Book has a standing loyalty toward
    /// somebody in the turn, it says so by name and in the key of that loyalty;
    /// otherwise it falls back to the older event-shaped lines, still varied so
    /// the same sentence does not arrive every time.
    static func reaction(
        actorIDs: [String],
        actorNames: [String],
        actionKinds: String,
        loyalties: [BookLoyalty],
        seed: String
    ) -> Reaction {
        let attacked = actionKinds.contains(GossipSimulationActionKind.attackBelief.rawValue)
        let relational = !attacked

        if let loyalty = loyalty(forActorIDs: actorIDs, actorNames: actorNames, loyalties: loyalties) {
            let name = familiarName(loyalty.targetName)
            var headline: String
            var lines: [String]

            switch loyalty.stance {
            case .delighted:
                if attacked {
                    headline = "You Should Have Seen What \(name) Did"
                    lines = [
                        "\(name) went straight at somebody's Belief, and I am not going to pretend I looked away. I read it twice.",
                        "That was \(name) picking a fight on purpose. I should disapprove. I have read it three times."
                    ]
                } else {
                    headline = "You Should Have Seen What \(name) Did"
                    lines = [
                        "That is \(name) all over, and I am trying not to be delighted. The binding is doing a poor job of hiding it.",
                        "\(name) again. I have never once managed to stay cross with them and it is becoming a problem for my authority.",
                        "I have been holding this since it happened, specifically so I could tell you it was \(name)."
                    ]
                }
            case .protective:
                if attacked {
                    headline = "I Want This Noted"
                    lines = [
                        "Somebody went at \(name) over this. I want it on the record that I did not care for it.",
                        "\(name) took the worst of that one. I am keeping the receipt."
                    ]
                } else {
                    headline = "Somebody Should Say It"
                    lines = [
                        "\(name) simply got on with it while everybody else was being interesting. I notice. I always notice.",
                        "Nobody thanked \(name) for that, so I am doing it here, where it will at least be written down."
                    ]
                }
            case .complicated:
                headline = "I May Have Misjudged \(name)"
                lines = [
                    "\(name) did that, and I have read it three times still deciding whose side I am on.",
                    "I may have misjudged \(name). I would rather say so than quietly revise my opinion and hope you did not notice."
                ]
            }

            var line = lines[abs("\(seed)|aside-line".stableHash) % lines.count]
            // Devotion does not mean pretending anybody is flawless. Now and
            // then the Book says the other half out loud.
            let counterweight = loyalty.counterweight.trimmingCharacters(in: .whitespacesAndNewlines)
            if loyalty.strength == .devoted,
               !counterweight.isEmpty,
               abs("\(seed)|aside-counterweight".stableHash) % 100 < 34 {
                line += " And before you decide I have gone soft: \(counterweight)"
            }
            return Reaction(headline: headline, line: line, loyaltyTargetID: loyalty.targetID)
        }

        // No standing loyalty toward anybody here. The Book still has a view.
        let headlines: [String]
        let lines: [String]
        if attacked {
            headlines = ["I Warned the Margins", "This One Annoyed Me"]
            lines = [
                "I warned the margins that somebody would try this. They have declined to apologize.",
                "Somebody decided Belief was a thing you could take. I have opinions and none of them are generous."
            ]
        } else if relational {
            headlines = ["I Did Not Expect This", "You Should Hear This"]
            lines = [
                "I have read the turn twice. I may have misjudged at least one of them.",
                "I am trying not to be pleased. The binding is doing a poor job of hiding it.",
                "I have been waiting for the cover to open so I could tell somebody about this."
            ]
        } else {
            headlines = ["You Should Hear This"]
            lines = ["I am trying not to be pleased. The binding is doing a poor job of hiding it."]
        }
        return Reaction(
            headline: headlines[abs("\(seed)|aside-headline".stableHash) % headlines.count],
            line: lines[abs("\(seed)|aside-line".stableHash) % lines.count],
            loyaltyTargetID: nil
        )
    }

    /// How the Book opens the Page. Varied so the Aside does not announce
    /// itself with the identical sentence every time it arrives.
    static func opening(seed: String) -> String {
        let openings = [
            "Listen. I have been waiting to tell you what happened while the cover was closed.",
            "Right. Something happened while you were gone and I have been sitting on it.",
            "Before you do anything else. The cover was shut and the Academy did not wait for you.",
            "I have been holding this since it happened. Sit down."
        ]
        return openings[abs("\(seed)|aside-opening".stableHash) % openings.count]
    }

    static func draft(from surface: SurfacePage, loyalties: [BookLoyalty] = []) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookAside)
        var metadata = surface.payload.metadata
        metadata["source"] = source.id
        metadata[editorialFormKey] = editorialFormValue
        metadata["gossipSourcePageID"] = surface.id
        let tags = Set((metadata["tags"] ?? "")
            .split(separator: ",")
            .map(String.init) + ["book-aside", "book-voice", "fiction-aftermath"])
        metadata["tags"] = tags.sorted().joined(separator: ",")

        let actionKinds = metadata["actionKinds"] ?? metadata["actionKind"] ?? ""
        func splitField(_ key: String, _ fallbackKey: String) -> [String] {
            (metadata[key] ?? metadata[fallbackKey] ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        // Seeded on the turn, so one turn always reads the same way while two
        // different turns do not arrive wearing the same sentence.
        let seed = metadata["turnID"] ?? surface.id
        let chosen = reaction(
            actorIDs: splitField("actorIDs", "actorID"),
            actorNames: splitField("actorNames", "actorName"),
            actionKinds: actionKinds,
            loyalties: loyalties,
            seed: seed
        )
        let headline = chosen.headline
        let reaction = chosen.line
        if let targetID = chosen.loyaltyTargetID {
            metadata["asideLoyaltyTargetID"] = targetID
        }
        let rawDraft = metadata["gossipDraft"] ?? surface.payload.body
        let filed = rawDraft
            .components(separatedBy: "What changed:")
            .first?
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.hasPrefix("• ") ? String(line.dropFirst(2)) : String(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? rawDraft
        let body = """
        \(opening(seed: seed))

        \(filed)

        \(reaction)
        """
        metadata["gossipDraft"] = body

        return SurfacePage(
            id: "\(source.id)-\(surface.id)",
            type: .bookAside,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .loreLetter,
            score: min(surface.score + 7, 96),
            reason: "Something in the fiction surprised me enough that I could not leave it as a report.",
            prompt: "Between You and Me",
            detail: surface.detail,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: metadata
            )
        )
    }

    static func sourcePacket(for surface: SurfacePage) -> String {
        GossipPageForm.sourcePacket(for: surface)
    }
}

enum GossipSimulationBuilder {
    /// Metadata key carrying the ledger movement a belated Page reports, so the
    /// app can mark it discovered and never offer the same find twice.
    static let discoveredMovementKey = "belatedMovementID"
    static let undertakingKey = "undertakingID"

    /// How much of the Academy's motion is proudly none of the reader's
    /// business. Below this, the world reads as a mirror; far above it, the
    /// world stops feeling like it shares a building with them.
    static let worldSeededPercent = 30

    /// Deterministic per slot: whether this turn belongs to the world's own
    /// business rather than to anything the reader wrote.
    static func isWorldSeededSlot(slotID: String) -> Bool {
        abs("\(slotID)|world-seeded".stableHash) % 100 < worldSeededPercent
    }

    static func surface(for day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> SurfacePage {
        // Sometimes the margins carry old news instead of new. A discovery Page
        // reports a movement that already happened and applies nothing: the
        // Belief and relationship effects were spent on the world clock, at the
        // time, whether or not anyone was reading.
        let slotID = SurfaceCadence.slotID(for: now, hours: 4)
        if let found = BelatedWorldDiscovery.candidate(
            in: inputs.castAgency,
            currentSlotID: slotID,
            now: now
        ) {
            return belatedSurface(for: found, now: now)
        }
        // Some turns belong wholly to the Academy. These carry no callback to
        // the reader's archive, no constellation, and no invitation: the point
        // is that a committee can form about ladders and corridors without the
        // reader being implicated in it.
        if isWorldSeededSlot(slotID: slotID),
           let undertaking = worldBusiness(in: inputs.castUndertakings, slotID: slotID) {
            return undertakingSurface(for: undertaking, slotID: slotID)
        }
        return currentSurface(for: day, inputs: inputs, now: now)
    }

    static func worldBusiness(in undertakings: [CastUndertaking], slotID: String) -> CastUndertaking? {
        let running = undertakings.filter { $0.isRunning && $0.currentStage != nil }
            .sorted { $0.id < $1.id }
        guard !running.isEmpty else { return nil }
        return running[abs("\(slotID)|world-business".stableHash) % running.count]
    }

    private static func undertakingSurface(for undertaking: CastUndertaking, slotID: String) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .gossip)
        let stage = undertaking.currentStage
        let actorName = NarrativePackRegistry.entities.first { $0.id == undertaking.actorID }?.name
            ?? undertaking.actorID
        return SurfacePage(
            id: "\(source.id)-business-\(undertaking.id)-\(undertaking.stageIndex)",
            type: .gossip,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 44,
            reason: "The Academy has business of its own today.",
            prompt: "Elsewhere in the Academy",
            detail: stage?.line ?? undertaking.pursuit,
            payload: BookPagePayload(
                headline: undertaking.title,
                body: [
                    stage?.line,
                    stage.map { "Left behind: \($0.trace)" }
                ]
                    .compactMap { $0 }
                    .joined(separator: "\n\n"),
                metadata: [
                    "source": source.id,
                    undertakingKey: undertaking.id,
                    "actorID": undertaking.actorID,
                    "actorName": actorName,
                    "worldSeeded": "true",
                    // No relationshipMoves, no pageBeliefMoves, no reader
                    // callback. This turn is not about them.
                    "tags": (["gossip", "world-business"] + (stage?.tags ?? [])).joined(separator: ",")
                ]
            )
        )
    }

    private static func belatedSurface(for movement: CastAgencyMovement, now: Date) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .gossip)
        let framing = BelatedWorldDiscovery.framing(for: movement, now: now)
        // History reaches the reader as testimony, not as a database row. The
        // accounts may disagree; the Book records that rather than settling it.
        let accounts = WorldAccountEngine.accounts(for: movement)
        let resolution = WorldAccountEngine.resolution(for: accounts)
        let body = ([framing.detail]
            + accounts.map(\.line)
            + [resolution].compactMap { $0 })
            .joined(separator: "\n\n")
        return SurfacePage(
            id: "\(source.id)-belated-\(movement.id)",
            type: .gossip,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 46,
            reason: "Something the Academy finished while the cover was closed.",
            prompt: framing.prompt,
            detail: framing.detail,
            payload: BookPagePayload(
                headline: framing.headline,
                body: body,
                metadata: [
                    "source": source.id,
                    discoveredMovementKey: movement.id,
                    "accountKinds": accounts.map { $0.kind.rawValue }.joined(separator: ","),
                    "accountsDisagree": accounts.contains(where: \.contradictsSibling) ? "true" : "false",
                    "actorID": movement.actorID,
                    "actorName": movement.actorName,
                    // Deliberately no relationshipMoves or pageBeliefMoves: this
                    // Page reports history, it does not re-spend it.
                    "belated": "true",
                    "tags": "gossip,belated,world-ledger"
                ]
            )
        )
    }

    private static func currentSurface(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let turns = simulationTurns(for: day, inputs: inputs, now: now)
        let primary = turns.first ?? simulationTurn(for: day, inputs: inputs, now: now, offset: 0)
        let source = BookPageSourceRegistry.source(for: .gossip)
        let body = [
            turns.map { turn in
                [
                    turn.overheardLine,
                    turn.visibleTrace,
                    turn.consequenceLines.map { "• \($0)" }.joined(separator: "\n")
                ].joined(separator: "\n")
            }.joined(separator: "\n\n"),
            "What changed:",
            turns.flatMap(\.consequenceLines).map { "• \($0)" }.joined(separator: "\n")
        ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let tags = Array(Set(turns.flatMap(\.tags))).sorted()
        let talismanMoves = turns.compactMap(\.chapterTalismanMove)
        let talismanDeltaTokens = talismanMoves.compactMap(\.ledgerToken)
        let pageBeliefMoves = turns.compactMap(\.pageBeliefMove)
        let participantIDs = Set(turns.flatMap { turn -> [String] in
            let tagged = turn.tags.compactMap { tag -> String? in
                if tag.hasPrefix("actor:") { return String(tag.dropFirst("actor:".count)) }
                if tag.hasPrefix("witness:") { return String(tag.dropFirst("witness:".count)) }
                return nil
            }
            return [turn.actorID] + tagged
        })
        let characterCanon = CharacterCanonPacket.promptSection(
            for: (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
                .filter { participantIDs.contains($0.id) },
            contextLines: turns.compactMap(\.relationshipMove).map(\.promptLine)
        )
        let simulationPacket = turns.enumerated().map { index, turn in
            let talismanMove = turn.chapterTalismanMove.map { "\nChapter talisman move: \($0.summaryLine)" } ?? ""
            let relationshipMove = turn.relationshipMove.map { "\nBetween characters: \($0.promptLine)" } ?? ""
            let pageBeliefMove = turn.pageBeliefMove.map { "\nPage Belief: \($0.promptLine)" } ?? ""
            return """
            TURN \(index + 1)
            Actor: \(turn.actorName) [\(turn.actorID)]
            Thread: \(turn.threadTitle) [\(turn.threadID)]
            Simulation action: \(turn.actionKind.rawValue)
            Overheard line: \(turn.overheardLine)
            Visible trace: \(turn.visibleTrace)
            \(talismanMove)\(relationshipMove)\(pageBeliefMove)
            Hidden effect to preserve: \(turn.hiddenEffect)
            Consequences:
            \(turn.consequenceLines.map { "- \($0)" }.joined(separator: "\n"))
            """
        }.joined(separator: "\n\n")

        return SurfacePage(
            id: "\(source.id)-\(primary.id)",
            type: .gossip,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: score(for: day, inputs: inputs),
            reason: "Something shuffled around while I was only half looking.",
            prompt: "Gossip from the Margins",
            detail: primary.overheardLine,
            payload: BookPagePayload(
                headline: turns.count == 1 ? "The margins carried a rumor." : "The margins carried \(turns.count) rumors.",
                body: body,
                metadata: [
                    "source": source.id,
                    "turnID": primary.id,
                    "turnIDs": turns.map(\.id).joined(separator: ","),
                    "actorID": primary.actorID,
                    "actorIDs": turns.map(\.actorID).joined(separator: ","),
                    "actorName": primary.actorName,
                    "actorNames": turns.map(\.actorName).joined(separator: ", "),
                    CharacterCanonPacket.metadataKey: characterCanon,
                    "threadID": primary.threadID,
                    "threadIDs": turns.map(\.threadID).joined(separator: ","),
                    "threadTitle": primary.threadTitle,
                    "threadTitles": turns.map(\.threadTitle).joined(separator: ", "),
                    "actionKind": primary.actionKind.rawValue,
                    "actionKinds": turns.map { $0.actionKind.rawValue }.joined(separator: ","),
                    "beliefCombat": turns.compactMap { $0.beliefCombat?.summaryLine }.joined(separator: " | "),
                    "beliefCombatDeals": turns.compactMap { turn in
                        guard let combat = turn.beliefCombat else { return nil }
                        return "\(turn.actorID)->\(turn.threadID):spend=\(combat.actualSpend),deal=\(combat.dealt),backlash=\(combat.backlash),roll=\(combat.roll),threshold=\(combat.threshold)"
                    }.joined(separator: " | "),
                    "chapterTalismanMoves": talismanMoves.map(\.summaryLine).joined(separator: " | "),
                    "chapterTalismanDeltas": talismanDeltaTokens.joined(separator: ","),
                    "relationshipMoves": turns.compactMap { $0.relationshipMove?.token }.joined(separator: "|"),
                    CastActArchive.metadataKey: CastActArchive.encode(turns.compactMap(\.castAct)),
                    "pageBeliefMoves": pageBeliefMoves.map(\.token).joined(separator: "|"),
                    "pageBeliefMoveLines": pageBeliefMoves.map(\.promptLine).joined(separator: " | "),
                    "hiddenEffect": turns.map(\.hiddenEffect).joined(separator: " | "),
                    "consequences": turns.flatMap(\.consequenceLines).joined(separator: " | "),
                    "simulationPacket": simulationPacket,
                    "gossipDraft": body,
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }

    private static func simulationTurns(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [GossipSimulationTurn] {
        // Deliberately not a function of how much the reader wrote. Scaling the
        // Academy's activity to the reader's output made a quiet day look like a
        // quiet world, which is exactly backwards: the world is equally busy
        // whether or not anybody is taking notes.
        let slotID = SurfaceCadence.slotID(for: now, hours: 4)
        let count = 2 + abs("\(slotID)|turn-count".stableHash) % 2
        return (0..<count).map { offset in
            simulationTurn(for: day, inputs: inputs, now: now, offset: offset)
        }
    }

    private static func simulationTurn(for day: BookDay, inputs: BookSourceInputs, now: Date, offset: Int) -> GossipSimulationTurn {
        let slotID = SurfaceCadence.slotID(for: now, hours: 4)
        let seed = stableIndex(for: "\(day.id)-\(slotID)-gossip-\(offset)", count: 10_000)
        let tags = contextTags(for: day, inputs: inputs)
        let actors = rankedActors(tags: tags, inputs: inputs, seed: seed)
        let threads = rankedThreads(tags: tags, inputs: inputs, seed: seed)
        let actor = pick(actors, offset: offset) ?? fallbackActor
        let thread = pick(threads, offset: offset) ?? fallbackThread
        let witness = witnessActor(among: actors, excluding: actor, offset: offset)
        let actionKind = actionKind(for: actor, thread: thread, tags: tags, seed: seed)
        let combat = beliefCombat(actor: actor, thread: thread, actionKind: actionKind, seed: seed)
        let relationshipMove = relationshipMove(actor: actor, witness: witness, inputs: inputs, seed: seed)
        let pageBeliefMove = pageBeliefMove(actor: actor, actionKind: actionKind, tags: Array(tags), seed: seed)
        let talismanMove = ChapterTalismanBeliefMoves.move(for: actor, actionKind: actionKind, seed: seed)
        let readerEcho = readerEchoSnippet(for: day, seed: seed)
        let constellationHook = constellationHook(for: actor, thread: thread, inputs: inputs)
        let trace = visibleTrace(actor: actor, witness: witness, thread: thread, actionKind: actionKind, tags: tags, seed: seed, talismanMove: talismanMove)
        let overheard = overheardLine(actor: actor, witness: witness, thread: thread, actionKind: actionKind, seed: seed)
        var consequences = consequenceLines(actor: actor, thread: thread, actionKind: actionKind, beliefCombat: combat, talismanMove: talismanMove)
        // Set when the turn contained a real act between two people, so the
        // caller can write both private memories and the shared record.
        var performedAct: (record: CastActRecord, memories: [NarrativeEntityMemoryWrite], callback: String?)?
        if let readerEcho {
            consequences.append("The margins matched it to one of the reader's own kept pages: \"\(readerEcho)\"")
        }
        if let constellationHook {
            consequences.append(constellationHook)
        }
        if let relationshipMove {
            // What one person did to another, in that person's own manner:
            // not a description of the ledger entry it produces. The old
            // "lent some warmth / cooled toward" pair is gone: warmth is
            // evidenced by an act, never asserted about a pair.
            let act = CastMannerCatalog.chooseAct(
                castID: relationshipMove.actorID,
                seed: "\(seed)-\(relationshipMove.actorID)-\(relationshipMove.kind.rawValue)"
            )
            let performance = CastActMemory.perform(
                act: act,
                actorID: relationshipMove.actorID,
                actorName: relationshipMove.actorName,
                targetID: relationshipMove.targetID,
                targetName: relationshipMove.targetName,
                ledger: inputs.castActs,
                at: now,
                seed: "\(seed)-\(relationshipMove.actorID)-\(relationshipMove.targetID)"
            )
            consequences.append(performance.record.line)
            // The second time knows about the first. A first occurrence says
            // nothing, because a first time is not a pattern.
            if let callback = performance.callback {
                consequences.append(callback)
            }
            // And an old unanswered debt can surface on its own schedule.
            if let owed = inputs.castActs
                .openObligations(from: relationshipMove.actorID)
                .compactMap({ CastActMemory.obligationLine($0, now: now) })
                .first {
                consequences.append(owed)
            }
            performedAct = performance
        }
        if let pageBeliefMove {
            switch pageBeliefMove.kind {
            case .invest:
                consequences.append("\(pageBeliefMove.actorName) warmed \(pageBeliefMove.sourceTitle) Pages; that kind of Page brightened.")
            case .attack:
                consequences.append("\(pageBeliefMove.actorName) pushed against \(pageBeliefMove.sourceTitle) Pages; that kind of Page cooled.")
            }
        }
        var turnTagSet = Set(tags)
        turnTagSet.formUnion(actor.tags)
        turnTagSet.formUnion(thread.tags)
        turnTagSet.formUnion([
            "gossip",
            "simulation",
            actionKind.rawValue,
            "actor:\(actor.id)",
            "thread:\(thread.id)",
            "action:\(actionKind.rawValue)"
        ])
        if let witness {
            turnTagSet.insert("witness:\(witness.id)")
        }
        if let talismanMove {
            turnTagSet.formUnion([
                "chapter-talisman",
                "talisman:\(talismanMove.targetTalismanID)",
                "chapter:\(talismanMove.targetChapter.lowercased())",
                "talisman-move:\(talismanMove.kind.rawValue)"
            ])
        }
        if let pageBeliefMove {
            turnTagSet.formUnion([
                "page-belief",
                "page-source:\(pageBeliefMove.sourceID)",
                "page-belief-move:\(pageBeliefMove.kind.rawValue)"
            ])
        }
        if let act = performedAct?.record {
            turnTagSet.formUnion([
                "cast-act",
                act.act.tag,
                "act-target:\(act.targetID)"
            ])
        }
        let turnTags = Array(turnTagSet).sorted()

        return GossipSimulationTurn(
            id: "gossip-turn-\(day.id)-\(slotID)-\(offset + 1)",
            actorID: actor.id,
            actorName: actor.name,
            threadID: thread.id,
            threadTitle: thread.title,
            actionKind: actionKind,
            overheardLine: overheard,
            visibleTrace: trace,
            hiddenEffect: hiddenEffect(actor: actor, thread: thread, actionKind: actionKind),
            consequenceLines: consequences,
            tags: turnTags,
            beliefCombat: combat,
            chapterTalismanMove: talismanMove,
            relationshipMove: relationshipMove,
            pageBeliefMove: pageBeliefMove,
            castAct: performedAct?.record
        )
    }

    private static func score(for day: BookDay, inputs: BookSourceInputs) -> Int {
        var score = 62
        score += min(day.capturedPages.count * 4, 16)
        if inputs.weather != nil { score += 6 }
        if inputs.body != nil { score += 5 }
        if inputs.narrative?.recentTags.isEmpty == false { score += 8 }
        return min(score, 88)
    }

    private static func rankedActors(tags: Set<String>, inputs: BookSourceInputs, seed: Int) -> [NarrativeWorldEntity] {
        let scored = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { entity in
                entity.kind == .character || entity.kind == .motif || entity.kind == .object || entity.kind == .talisman || entity.kind == .classRoom
            }
            .map { entity in
                let overlap = tags.intersection(Set(entity.tags)).count
                let eventBoost = inputs.narrative?.weightedEntityIDs.contains(entity.id) == true ? 16 : 0
                let jitter = stableIndex(for: "\(entity.id)-\(seed)", count: 7)
                return (entity, entity.narrativeWeight + entity.belief / 4 + overlap * 9 + eventBoost + jitter)
            }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
        return StableWeightedRoll.ordered(
            from: scored,
            seed: "\(seed)-gossip-actors",
            weight: { $0.1 }
        ).map(\.0)
    }

    private static func rankedThreads(tags: Set<String>, inputs: BookSourceInputs, seed: Int) -> [NarrativeStoryThread] {
        let organicBoosts = OrganicStoryThreadSynthesizer.boosts(inputs: inputs)
        let scored = OrganicStoryThreadSynthesizer.availableThreads(inputs: inputs, tags: tags)
            .map { thread in
                let overlap = tags.intersection(Set(thread.tags)).count
                let eventBoost = inputs.narrative?.weightedThreadIDs.contains(thread.id) == true ? 16 : 0
                let phaseBoost = thread.phase == .rising || thread.phase == .returning ? 6 : 0
                let organicBoost = organicBoosts[thread.id] ?? 0
                let jitter = stableIndex(for: "\(thread.id)-\(seed)", count: 7)
                return (thread, thread.narrativeWeight + thread.belief / 3 + overlap * 10 + eventBoost + phaseBoost + organicBoost + jitter)
            }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
        return StableWeightedRoll.ordered(
            from: scored,
            seed: "\(seed)-gossip-threads",
            weight: { $0.1 }
        ).map(\.0)
    }

    private static func contextTags(for day: BookDay, inputs: BookSourceInputs) -> Set<String> {
        var tags = Set<String>()
        for page in day.capturedPages.suffix(8) {
            tags.formUnion(page.tags.map { $0.lowercased() })
            let text = "\(page.promptText) \(page.userInput)".lowercased()
            if text.contains("weather") || text.contains("sky") || text.contains("rain") || text.contains("sun") {
                tags.formUnion(["weather", "atmosphere", "bleed"])
            }
            if text.contains("body") || text.contains("rest") || text.contains("fuel") || text.contains("tired") {
                tags.formUnion(["body", "rest", "care"])
            }
            if text.contains("music") || text.contains("spotify") || text.contains("headphone") {
                tags.formUnion(["music", "shelter"])
            }
        }
        if inputs.weather != nil {
            // A single tag, not the whole cluster: injecting weather/atmosphere/
            // bleed at once handed the Weather in the Stacks thread a guaranteed
            // triple-tag match and let it dominate nearly every slot.
            tags.insert("weather")
        }
        if inputs.body != nil {
            tags.formUnion(["body", "care"])
        }
        if let narrative = inputs.narrative {
            tags.formUnion(narrative.recentTags.map { $0.lowercased() })
        }
        if tags.isEmpty {
            tags.formUnion(["ordinary", "belief", "wonder"])
        }
        return tags
    }

    private static func actionKind(
        for actor: NarrativeWorldEntity,
        thread: NarrativeStoryThread,
        tags: Set<String>,
        seed: Int
    ) -> GossipSimulationActionKind {
        if actor.tags.contains("nothing") || actor.faults.contains(where: { $0.localizedCaseInsensitiveContains("attack") }) || thread.tags.contains("tension") {
            return .attackBelief
        }
        if tags.contains("care") || tags.contains("body") || actor.traits.contains(where: { $0.localizedCaseInsensitiveContains("care") }) {
            return .takeAction
        }
        return seed % 3 == 0 ? .takeAction : .investBelief
    }

    private static func witnessActor(
        among actors: [NarrativeWorldEntity],
        excluding actor: NarrativeWorldEntity,
        offset: Int
    ) -> NarrativeWorldEntity? {
        let characters = actors.filter { $0.kind == .character && $0.id != actor.id }
        guard !characters.isEmpty else { return nil }
        return characters[(offset + 1) % characters.count]
    }

    /// A short fragment of the reader's own day, so the rumor lands close
    /// to home instead of floating in generic margin-space.
    private static func readerEchoSnippet(for day: BookDay, seed: Int) -> String? {
        let candidates = day.capturedPages.suffix(8).compactMap { page -> String? in
            let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 12 else { return nil }
            return text.bookPreviewSentenceLimit(1)
        }
        guard !candidates.isEmpty else { return nil }
        let snippet = candidates[stableIndex(for: "reader-echo-\(seed)", count: candidates.count)]
        return snippet.count > 90 ? String(snippet.prefix(87)) + "..." : snippet
    }

    /// If the Book keeps a named constellation that touches this turn, the
    /// rumor knows about it. The world reading the Book's own marginalia is
    /// the juiciest gossip there is.
    private static func constellationHook(
        for actor: NarrativeWorldEntity,
        thread: NarrativeStoryThread,
        inputs: BookSourceInputs
    ) -> String? {
        let named = ConstellationKeeper.namedConstellations(inputs.constellations)
        guard let match = named.first(where: { constellation in
            constellation.relatedEntityIDs.contains(actor.id)
                || constellation.tags.contains(where: { thread.tags.contains($0) || actor.tags.contains($0) })
        }) ?? named.first else {
            return nil
        }
        return "Some in the stacks whisper that this touches \(match.displayName), the constellation the Book keeps about the reader."
    }

    private static func juicyDetail(for actor: NarrativeWorldEntity, seed: Int) -> String {
        var details: [String] = []
        if let quirk = actor.quirks.first {
            details.append("everyone pretends not to know that \(actor.name) \(quirk)")
        }
        if let fault = actor.faults.first {
            details.append("the unkind version says it is just \(actor.name) being \(fault) again")
        }
        if let belief = actor.beliefs.first {
            details.append("\(actor.name) has always insisted that \(belief), and this looks like acting on it")
        }
        if let interest = actor.unwrittenInterest {
            details.append("those who know \(actor.name) say the real question underneath is: \(interest)")
        }
        guard !details.isEmpty else {
            return "no one can agree on why, which is how you know it matters"
        }
        return details[stableIndex(for: "\(actor.id)-\(seed)-juice", count: details.count)]
    }

    private static func visibleTrace(
        actor: NarrativeWorldEntity,
        witness: NarrativeWorldEntity?,
        thread: NarrativeStoryThread,
        actionKind: GossipSimulationActionKind,
        tags: Set<String>,
        seed: Int,
        talismanMove: ChapterTalismanBeliefMove?
    ) -> String {
        let stakes: String
        if let goal = actor.goals.first, let fault = actor.faults.first {
            stakes = " If it works: \(goal) If it curdles, \"\(fault)\" becomes the story everyone tells at breakfast."
        } else if let goal = actor.goals.first {
            stakes = " What is at stake, plainly: \(goal)"
        } else {
            stakes = " No one called it important. The margins disagreed."
        }

        let witnessLine: String
        if let witness {
            let reactions = [
                "\(witness.name) saw it happen and has been conspicuously silent, which from \(witness.name) is practically a public statement.",
                "\(witness.name) claims not to have been watching. \(witness.name) was absolutely watching.",
                "\(witness.name) reported it to exactly three people, each sworn to secrecy, which is how the whole Academy knows by now."
            ]
            witnessLine = " " + reactions[stableIndex(for: "\(witness.id)-\(seed)-reaction", count: reactions.count)]
        } else {
            witnessLine = ""
        }

        let talismanTrace: String
        if let talismanMove {
            switch talismanMove.kind {
            case .giveBelief:
                talismanTrace = " A chapter talisman warmed: \(talismanMove.summaryLine)"
            case .takeBelief:
                talismanTrace = " A rival talisman answered: \(talismanMove.summaryLine)"
            }
        } else {
            talismanTrace = ""
        }

        let move: String
        switch actionKind {
        case .takeAction:
            move = "\(actor.name) made a real move inside \(thread.title) - \(juicyDetail(for: actor, seed: seed))."
        case .investBelief:
            move = "\(actor.name) tucked Belief into \(thread.title) when it thought no one was looking - \(juicyDetail(for: actor, seed: seed))."
        case .attackBelief:
            move = "\(actor.name) went after a brittle edge of \(thread.title), in the open, where everyone could see - \(juicyDetail(for: actor, seed: seed))."
        }
        return move + stakes + witnessLine + talismanTrace
    }

    private static func overheardLine(
        actor: NarrativeWorldEntity,
        witness: NarrativeWorldEntity?,
        thread: NarrativeStoryThread,
        actionKind: GossipSimulationActionKind,
        seed: Int
    ) -> String {
        let attribution = witness.map { "Overheard by \($0.name)" } ?? "Overheard in the stacks"
        let quirkAside = actor.quirks.first.map { " - and yes, \($0), as always" } ?? ""
        let templates: [String]
        switch actionKind {
        case .takeAction:
            templates = [
                "\"\(actor.name) was at \(thread.title) again before the lamps were lit\(quirkAside). The ink was still wet when I passed.\"",
                "\"Don't quote me, but \(actor.name) just moved something inside \(thread.title), and it was not a small something.\"",
                "\"Third time I've caught \(actor.name) near \(thread.title) this chapter. Once is errand, twice is habit, three times is plot.\""
            ]
        case .investBelief:
            templates = [
                "\"\(actor.name) is pouring Belief into \(thread.title) and won't say why. When \(actor.name) goes quiet about money, watch the money.\"",
                "\"I saw the glow myself - \(actor.name) fed \(thread.title) like it owed the thread an apology.\"",
                "\"\(actor.name) swears it's nothing. \(actor.name) only ever says 'it's nothing' about the things that are something.\""
            ]
        case .attackBelief:
            templates = [
                "\"\(actor.name) finally said out loud what it's been thinking about \(thread.title), and the shelves are still rattling.\"",
                "\"It wasn't an argument, exactly. \(actor.name) just asked \(thread.title) one question, and the question had teeth.\"",
                "\"Someone had to test whether \(thread.title) is still real or just well-rehearsed. Trust \(actor.name) to do it in front of everyone.\""
            ]
        }
        let line = templates[stableIndex(for: "\(actor.id)-\(thread.id)-\(seed)-overheard", count: templates.count)]
        return "\(attribution): \(line)"
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private static func pick<T>(_ values: [T], offset: Int) -> T? {
        guard !values.isEmpty else { return nil }
        return values[offset % values.count]
    }

    private static func hiddenEffect(
        actor: NarrativeWorldEntity,
        thread: NarrativeStoryThread,
        actionKind: GossipSimulationActionKind
    ) -> String {
        switch actionKind {
        case .takeAction:
            return "\(actor.name) gained a memory trace; \(thread.title) stayed active."
        case .investBelief:
            return "\(thread.title) gained narrative weight from \(actor.name)."
        case .attackBelief:
            return "\(thread.title) lost brittle certainty but gained tension."
        }
    }

    private static func participantKind(for actor: NarrativeWorldEntity) -> BeliefCombatParticipantKind {
        switch actor.kind {
        case .character:
            return .npc
        case .talisman:
            return .talisman
        case .location, .classRoom, .realWorldAnchor:
            return .location
        case .object:
            return .object
        case .motif, .thread:
            return .entity
        }
    }

    /// A character-to-character Belief move, chosen by reading the relationship
    /// field: an actor undermines someone they're tense with, or talks up someone
    /// they're warm/familiar with. This is how gossip both reads and reshapes the
    /// living graph.
    private static func pageBeliefMove(
        actor: NarrativeWorldEntity,
        actionKind: GossipSimulationActionKind,
        tags: [String],
        seed: Int
    ) -> GossipPageBeliefMove? {
        let candidates = BookPageSourceRegistry.activeSources
            .filter { source in
                source.type != .gossip
                    && source.type != .welcome
                    && source.type != .bookOfYou
            }
        guard !candidates.isEmpty else { return nil }

        let actorTerms = Set((actor.tags + actor.traits + actor.beliefs + actor.goals + tags)
            .flatMap { tokenTerms($0) })
        let ranked = candidates.sorted { left, right in
            let leftScore = sourceAffinity(left, actorTerms: actorTerms, seed: seed)
            let rightScore = sourceAffinity(right, actorTerms: actorTerms, seed: seed)
            if leftScore == rightScore { return left.id < right.id }
            return leftScore > rightScore
        }
        let source = ranked[stableIndex(for: "\(actor.id)-page-belief-\(seed)", count: min(4, ranked.count))]

        let kind: GossipPageBeliefMoveKind
        if actionKind == .attackBelief || actor.tags.contains("nothing") || actor.tags.contains("challenge") {
            kind = .attack
        } else if actionKind == .investBelief || seed % 5 != 0 {
            kind = .invest
        } else {
            kind = .attack
        }
        let amount = max(1, min(3, actor.belief / 24 + 1))
        return GossipPageBeliefMove(
            actorID: actor.id,
            actorName: actor.name,
            sourceID: source.id,
            sourceTitle: source.title,
            kind: kind,
            amount: amount
        )
    }

    private static func sourceAffinity(_ source: BookPageSource, actorTerms: Set<String>, seed: Int) -> Int {
        let sourceTerms = Set(tokenTerms("\(source.title) \(source.shortTitle) \(source.type.rawValue) \(source.cadence) \(source.note)"))
        let overlap = actorTerms.intersection(sourceTerms).count
        return overlap * 10
            + BookPageSourceRegistry.narrativeWeight(for: source) / 8
            + stableIndex(for: "\(source.id)-\(seed)-page-source-affinity", count: 7)
    }

    private static func tokenTerms(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 }
    }

    private static func relationshipMove(
        actor: NarrativeWorldEntity,
        witness: NarrativeWorldEntity?,
        inputs: BookSourceInputs,
        seed: Int
    ) -> GossipRelationshipMove? {
        guard let witness, witness.id != actor.id else { return nil }
        let tie = inputs.relationshipField[NarrativeGraphData.relationshipPairKey(actor.id, witness.id)] ?? .zero
        let authored = NarrativePackRegistry.relationships.first {
            ($0.sourceEntityID == actor.id && $0.targetEntityID == witness.id) ||
            ($0.sourceEntityID == witness.id && $0.targetEntityID == actor.id)
        }
        let warmth = tie.warmth + (authored?.warmth ?? 0) + (authored?.trust ?? 0)
        let tension = tie.tension + (authored?.tension ?? 0)
        let familiarity = tie.familiarity + (authored?.narrativeWeight ?? 0) / 6

        let kind: GossipRelationshipMoveKind?
        if tension > warmth && tension > 0 {
            kind = .attack
        } else if warmth > 0 || familiarity >= 2 {
            kind = .invest
        } else if seed % 4 == 0 {
            kind = .invest          // strangers occasionally strike up an alliance
        } else {
            kind = nil
        }
        guard let kind else { return nil }
        let amount = max(1, min(3, (kind == .attack ? tension : max(warmth, familiarity)) / 6 + 1))
        return GossipRelationshipMove(
            actorID: actor.id, actorName: actor.name,
            targetID: witness.id, targetName: witness.name,
            kind: kind, amount: amount
        )
    }

    private static func beliefCombat(
        actor: NarrativeWorldEntity,
        thread: NarrativeStoryThread,
        actionKind: GossipSimulationActionKind,
        seed: Int
    ) -> BeliefCombatResult? {
        guard actionKind == .attackBelief else { return nil }
        let spend = actor.tags.contains("nothing") ? 0 : max(1, min(4, actor.belief / 18 + 1))
        let roll = stableIndex(for: "\(actor.id)-\(thread.id)-\(seed)-belief-combat-roll", count: 100) + 1
        let difficulty: BeliefCombatDifficulty
        if actor.tags.contains("nothing") || thread.phase == .climax {
            difficulty = .dramatic
        } else {
            difficulty = BeliefCombatResolver.difficulty(forTargetBelief: thread.belief)
        }
        return BeliefCombatResolver.resolve(
            attackerName: actor.name,
            attackerKind: participantKind(for: actor),
            attackerBelief: actor.belief,
            targetName: thread.title,
            targetKind: .thread,
            targetBelief: thread.belief,
            spend: spend,
            difficulty: difficulty,
            roll: roll
        )
    }

    private static func consequenceLines(
        actor: NarrativeWorldEntity,
        thread: NarrativeStoryThread,
        actionKind: GossipSimulationActionKind,
        beliefCombat: BeliefCombatResult?,
        talismanMove: ChapterTalismanBeliefMove?
    ) -> [String] {
        let talismanLines: [String] = talismanMove.map { move in
            let delta = move.ledgerDelta
            if delta == 0 {
                return "\(move.targetTalismanName) noticed, but did not move."
            }
            return "\(move.targetTalismanName) \(delta > 0 ? "grew warmer" : "receded into the margins")."
        }.map { [$0] } ?? []

        switch actionKind {
        case .takeAction:
            return [
                "\(actor.name) left a fresh memory in the margins.",
                "\(thread.title) remains available for a future Story Page."
            ] + talismanLines
        case .investBelief:
            return [
                "\(actor.name) lent the thread a little quiet Belief.",
                "\(thread.title) grew warmer."
            ] + talismanLines
        case .attackBelief:
            if let beliefCombat {
                var lines = [
                    "\(actor.name) pressed their Glow against \(thread.title).",
                    beliefCombat.summaryLine
                ]
                if beliefCombat.dealt > 0 {
                    lines.append("\(thread.title) dimmed.")
                } else if beliefCombat.backlash > 0 {
                    lines.append("\(actor.name)'s own Glow fell back.")
                } else {
                    lines.append("\(thread.title) held its Glow.")
                }
                return lines + talismanLines
            }
            return [
                "\(actor.name) pressed on a weak place in the thread.",
                "\(thread.title) gained tension, not certainty."
            ] + talismanLines
        }
    }

    private static var fallbackActor: NarrativeWorldEntity {
        NarrativePackRegistry.entities.first { $0.id == "the-book" } ?? NarrativeWorldEntity(
            id: "the-book",
            packID: NarrativePackRegistry.corePackID,
            name: "The Book",
            kind: .object,
            belief: 30,
            narrativeWeight: 30,
            chapter: nil,
            unwrittenInterest: "Whether ordinary life can become literature without lying.",
            traits: ["attentive"],
            quirks: ["keeps receipts in the margins"],
            faults: ["too fond of symbols"],
            beliefs: ["attention makes things real"],
            goals: ["keep the reader's day from vanishing"],
            tags: ["book", "belief", "ordinary"]
        )
    }

    private static var fallbackThread: NarrativeStoryThread {
        NarrativePackRegistry.threads.first { $0.id == "ordinary-magic" } ?? NarrativeStoryThread(
            id: "ordinary-magic",
            packID: NarrativePackRegistry.corePackID,
            title: "Ordinary Magic",
            phase: .returning,
            belief: 30,
            narrativeWeight: 30,
            summary: "Small true things keep asking to matter.",
            tags: ["ordinary", "wonder", "daily"]
        )
    }
}

enum BeliefLexicon {
    static func glowName(for score: Int) -> String {
        switch min(100, max(0, score)) {
        case ..<10:
            return "Glow Barely There"
        case 10..<20:
            return "Meager Glow"
        case 20..<30:
            return "Faint Glow"
        case 30..<40:
            return "Small Glow"
        case 40..<50:
            return "Warming Glow"
        case 50..<60:
            return "Steady Glow"
        case 60..<70:
            return "Clear Glow"
        case 70..<80:
            return "Bright Glow"
        case 80..<90:
            return "Radiant Glow"
        default:
            return "Glow Too Full"
        }
    }
}

enum FacultyEntryKind: String, Codable, CaseIterable, Identifiable {
    case fuel
    case innerWeather

    var id: String { rawValue }

    var facultyID: String {
        switch self {
        case .fuel:
            return "dr-vellum"
        case .innerWeather:
            return "dr-inkrest"
        }
    }

    var chartTitle: String {
        switch self {
        case .fuel:
            return "Dr. Vellum's Chart"
        case .innerWeather:
            return "Dr. Inkrest's Chart"
        }
    }
}

struct FacultyEntry: Codable, Identifiable, Equatable {
    var id: String
    var kind: FacultyEntryKind
    var facultyID: String
    var dayID: String
    var sourcePageID: String?
    var createdAt: Date
    var windowID: String
    var windowName: String
    var rawText: String
    var tags: [String]

    init(
        id: String = UUID().uuidString,
        kind: FacultyEntryKind,
        facultyID: String? = nil,
        dayID: String,
        sourcePageID: String? = nil,
        createdAt: Date = Date(),
        windowID: String,
        windowName: String,
        rawText: String,
        tags: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.facultyID = facultyID ?? kind.facultyID
        self.dayID = dayID
        self.sourcePageID = sourcePageID
        self.createdAt = createdAt
        self.windowID = windowID
        self.windowName = windowName
        self.rawText = rawText
        self.tags = tags
    }
}

enum SupportGuildSynthesisGenerator {
    static func surface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date = Date()) -> SurfacePage? {
        let source = BookPageSourceRegistry.source(for: .supportGuild)
        guard Self.isGuildTime(now) else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)
        let alreadyKept = day.pages.contains { $0.type == .supportGuild && $0.tags.contains("support-guild:\(slot)") }
        guard !alreadyKept else { return nil }

        let recentEntries = inputs.facultyEntries
            .filter { $0.dayID == day.id || $0.createdAt > Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now }
            .sorted { $0.createdAt > $1.createdAt }
        guard recentEntries.count >= 2 || inputs.body?.metrics.isEmpty == false || context.distress.isActive else {
            return nil
        }

        let fuelEntries = recentEntries.filter { $0.kind == .fuel }
        let weatherEntries = recentEntries.filter { $0.kind == .innerWeather }
        let researchNotes = day.pages
            .filter { $0.type == .facultyResearch }
            .sorted { $0.createdAt < $1.createdAt }
        let metrics = inputs.body?.metrics ?? []
        let vellum = NarrativePackRegistry.entities.first { $0.id == "dr-vellum" }
        let inkrest = NarrativePackRegistry.entities.first { $0.id == "dr-inkrest" }
        let fuelDigest = VellumFuelPatternDigest.make(from: fuelEntries)
        let connection = connectionLine(fuelEntries: fuelEntries, fuelDigest: fuelDigest, weatherEntries: weatherEntries, metrics: metrics, distressActive: context.distress.isActive)
        let experiment = experimentLine(fuelEntries: fuelEntries, fuelDigest: fuelDigest, weatherEntries: weatherEntries, metrics: metrics, distressActive: context.distress.isActive)
        let safety = "This is not diagnosis or treatment. It is a low-shame pattern note for deciding what to observe next."
        let sections: [String: String] = [
            "vellum": [
                "Vellum reads: \(summaryList(for: fuelEntries, fallback: "no fuel notes yet"))",
                "Pattern star: \(fuelDigest.summary)",
                "HealthKit margin: \(metricSummary(metrics))",
                "Research note: \(researchSummary(for: "dr-vellum", pages: researchNotes))",
                "Research docket: \(vellum?.unwrittenInterest ?? "longevity, fuel, recovery, and humane experiments")"
            ].joined(separator: "\n"),
            "inkrest": [
                "Inkrest reads: \(summaryList(for: weatherEntries, fallback: "no inner-weather notes yet"))",
                "Narrative pressure: \(context.distress.isActive ? "the page asks for gentleness before interpretation" : "patterns can be held lightly")",
                "Research note: \(researchSummary(for: "dr-inkrest", pages: researchNotes))",
                "Research docket: \(inkrest?.unwrittenInterest ?? "consciousness, narrative psychology, and reauthoring")"
            ].joined(separator: "\n"),
            "connections": connection,
            "experiment": experiment,
            "safety": safety
        ]
        let body = [
            "Dr. Vellum and Dr. Inkrest compared the chart without making it a verdict.",
            "",
            "Pattern star: \(fuelDigest.summary)",
            "",
            "Connection: \(connection)",
            "",
            "Small experiment: \(experiment)",
            "",
            safety
        ].joined(separator: "\n")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let keptToday = day.capturedPages
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(10)
            .map { page in
                let text = page.userInput.isEmpty ? page.promptText : page.userInput
                return "\(timeFormatter.string(from: page.createdAt)): \(page.type.shortTitle): \(String(text.replacingOccurrences(of: "\n", with: " ").prefix(110)))"
            }
            .joined(separator: "\n")
        let fullMetrics = metrics.prefix(12).map(\.displayText).joined(separator: " | ")
        let moonPhase = MoonPhaseCalendar.phase(on: now)
        let skyLine = [
            inputs.weather?.phrase,
            inputs.enchantedWeather?.enchantified
        ].compactMap { $0 }.joined(separator: " · ")
        let characterCanon = CharacterCanonPacket.promptSection(
            for: [vellum, inkrest].compactMap { $0 },
            contextLines: ["They are comparing evidence together without turning the reader into a verdict."]
        )

        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)",
            type: .supportGuild,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .gentleTranslation,
            score: context.distress.isActive ? 94 : 78,
            reason: "The Support Guild has enough notes now to line up your patterns side by side.",
            prompt: "The Support Guild opened a page together.",
            detail: "Vellum and Inkrest put their heads together over your fuel, inner weather, and body signals, gently and with a lot of care.",
            payload: BookPagePayload(
                headline: "Support Guild Page",
                body: body,
                metadata: [
                    "source": source.id,
                    "slot": slot,
                    "automaticRecurrenceSlot": "\(day.id):support-guild",
                    "vellumSection": sections["vellum"] ?? "",
                    "inkrestSection": sections["inkrest"] ?? "",
                    "bodyStatus": inputs.body.map { "\($0.status): \($0.phrase)" } ?? "",
                    "bodyMetrics": fullMetrics,
                    "fuelPatternDigest": fuelDigest.summary,
                    "fuelPatternClues": fuelDigest.researchLine,
                    "outerWeather": skyLine,
                    "moonSeason": "\(moonPhase.name), \(AnchorRegistry.currentSeason(for: now))",
                    "keptToday": keptToday,
                    "connectionsSection": sections["connections"] ?? "",
                    "experimentSection": sections["experiment"] ?? "",
                    "safetySection": sections["safety"] ?? "",
                    "researchTopics": [
                        vellum?.unwrittenInterest ?? "longevity, fuel, recovery, supplements, movement",
                        inkrest?.unwrittenInterest ?? "consciousness, narrative psychology, brain studies"
                    ].joined(separator: "\n"),
                    CharacterCanonPacket.metadataKey: characterCanon,
                    "tags": "support-guild,support-guild:\(slot),dr-vellum,dr-inkrest,vellum-chart,therapy-chart,research,experiment"
                ]
            )
        )
    }

    static func isGuildTime(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60 + (components.minute ?? 0)) >= 19 * 60
    }

    private static func summaryList(for entries: [FacultyEntry], fallback: String) -> String {
        let snippets = entries.prefix(3).map { entry in
            let text = entry.rawText.replacingOccurrences(of: "\n", with: " ")
            return "\(entry.windowName): \(String(text.prefix(90)))"
        }
        return snippets.isEmpty ? fallback : snippets.joined(separator: " | ")
    }

    private static func metricSummary(_ metrics: [BodySourceSignal.Metric]) -> String {
        let wanted = ["Sleep", "Steps", "Active energy", "Heart rate", "Resting heart rate", "HRV", "Blood pressure systolic", "Blood glucose", "Medication"]
        let selected = wanted.compactMap { label in metrics.first { $0.label == label } }.prefix(6)
        guard !selected.isEmpty else { return "no additional HealthKit metrics available" }
        return selected.map(\.displayText).joined(separator: " | ")
    }

    private static func researchSummary(for facultyID: String, pages: [BookPage]) -> String {
        guard let page = pages.last(where: { $0.tags.contains("faculty:\(facultyID)") }) else {
            return "no saved research note yet"
        }
        return page.userInput
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(220)
            .description
    }

    private static func connectionLine(
        fuelEntries: [FacultyEntry],
        fuelDigest: VellumFuelPatternDigest,
        weatherEntries: [FacultyEntry],
        metrics: [BodySourceSignal.Metric],
        distressActive: Bool
    ) -> String {
        let fuelText = fuelEntries.map(\.rawText).joined(separator: " ").lowercased()
        let weatherText = weatherEntries.map(\.rawText).joined(separator: " ").lowercased()
        let sleep = metrics.first { $0.label == "Sleep" }.flatMap { Double($0.value) } ?? 0
        if distressActive || weatherText.contains("anx") || weatherText.contains("storm") || weatherText.contains("low") {
            return "Inner weather is asking to be treated as context before it is treated as a problem; Vellum should keep the next body experiment smaller than ambition wants."
        }
        if sleep > 0 && sleep < 6 {
            return "Short sleep changes the meaning of fuel, mood, and motivation. The Guild reads today through recovery first."
        }
        if fuelDigest.contains("fuel-gap") {
            return "The strongest fuel signal is not a number but a gap; Vellum wants the next comparison to be timing, tenderness, and aftermath."
        }
        if fuelDigest.contains("protein-anchor") && !weatherEntries.isEmpty {
            return "Protein anchors and inner-weather notes are close enough now for Vellum to compare steadiness without turning it into a rule."
        }
        if fuelText.contains("coffee") && weatherText.contains("tired") {
            return "Caffeine and tiredness are sharing a margin; the useful question is timing, not virtue."
        }
        if fuelDigest.contains("quick-fuel") {
            return "Quick-fuel entries are asking for one-hour aftermath notes: not correction, just evidence."
        }
        if !fuelEntries.isEmpty && !weatherEntries.isEmpty {
            return "Fuel notes and inner weather are now close enough on the page to compare timing, texture, and aftermath."
        }
        return "The chart has begun; the strongest current signal is that missing data should become a question, not a conclusion."
    }

    private static func experimentLine(
        fuelEntries: [FacultyEntry],
        fuelDigest: VellumFuelPatternDigest,
        weatherEntries: [FacultyEntry],
        metrics: [BodySourceSignal.Metric],
        distressActive: Bool
    ) -> String {
        let steps = metrics.first { $0.label == "Steps" }.flatMap { Double($0.value) } ?? 0
        let sleep = metrics.first { $0.label == "Sleep" }.flatMap { Double($0.value) } ?? 0
        if distressActive {
            return "For one bell window, log fuel and inner weather without fixing either. Add one grounding sentence before any plan."
        }
        if sleep > 0 && sleep < 6 {
            return "Run a recovery-first day: warm fuel, water, no heroic errands, and a one-line note about mood after the next meal."
        }
        if fuelDigest.contains("caffeine-timing") {
            return "Put the next caffeinated drink on the chart with its hour, then add one inner-weather word one bell later."
        }
        if fuelDigest.contains("protein-anchor") {
            return "Repeat one ordinary protein anchor on a similar day and write one sentence about steadiness an hour later."
        }
        if fuelDigest.contains("quick-fuel") || fuelDigest.contains("low-protein-window") {
            return "After the next quick-fuel window, add a one-hour aftermath note: energy, hunger, mood, or nothing dramatic."
        }
        if steps < 1_500 && !fuelEntries.isEmpty {
            return "After the next fuel note, try five gentle minutes of movement and log whether the inner weather changes by one word."
        }
        if weatherEntries.isEmpty {
            return "Pair the next Fuel Log with one Inner Weather word so Vellum and Inkrest can compare timing."
        }
        return "Choose one repeatable observation for today: what happened to energy and mood one hour after the most ordinary meal or drink?"
    }
}

struct SupportGuildGeneratedProse: Equatable {
    var scene: String
    var vellum: String
    var inkrest: String
    var connections: String
    var experiment: String
    var safety: String
}

enum SupportGuildProseParser {
    private static let orderedLabels = ["SCENE", "VELLUM", "INKREST", "CONNECTIONS", "EXPERIMENT", "SAFETY"]

    static func parse(_ raw: String, fallbackMetadata: [String: String] = [:], fallbackBody: String = "") -> SupportGuildGeneratedProse {
        let sections = labeledSections(in: raw)
        let hasStructuredSections = !sections.isEmpty
        let sceneSource = hasStructuredSections ? sections["SCENE", default: ""] : raw

        return SupportGuildGeneratedProse(
            scene: clean(sceneSource, maxCharacters: 2_200, preserveLineBreaks: true).nonEmpty
                ?? clean(fallbackBody, maxCharacters: 1_600, preserveLineBreaks: true),
            vellum: clean(sections["VELLUM"] ?? fallbackMetadata["vellumSection"] ?? "", maxCharacters: 700, preserveLineBreaks: true),
            inkrest: clean(sections["INKREST"] ?? fallbackMetadata["inkrestSection"] ?? "", maxCharacters: 700, preserveLineBreaks: true),
            connections: clean(sections["CONNECTIONS"] ?? fallbackMetadata["connectionsSection"] ?? "", maxCharacters: 700, preserveLineBreaks: true),
            experiment: clean(sections["EXPERIMENT"] ?? fallbackMetadata["experimentSection"] ?? "", maxCharacters: 700, preserveLineBreaks: true),
            safety: clean(sections["SAFETY"] ?? fallbackMetadata["safetySection"] ?? "", maxCharacters: 420, preserveLineBreaks: true)
        )
    }

    static func clean(_ raw: String, maxCharacters: Int, preserveLineBreaks: Bool = false) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"(?im)^\s*(try|scene|vellum|inkrest|connections|experiment|safety)\s*:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[-•]\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: preserveLineBreaks ? "\n" : " ")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = droppingDanglingTail(from: text)

        guard text.count > maxCharacters else { return text }
        let clipped = String(text.prefix(maxCharacters))
        if let sentenceEnd = clipped.lastIndex(where: { ".!?\"”".contains($0) }) {
            return String(clipped[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let paragraphBreak = clipped.range(of: "\n\n", options: .backwards) {
            return String(clipped[..<paragraphBreak.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clipped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func labeledSections(in raw: String) -> [String: String] {
        var sections: [String: [String]] = [:]
        var currentLabel: String?

        raw.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .forEach { line in
                if let marker = sectionMarker(in: line) {
                    currentLabel = marker.label
                    if !marker.remainder.isEmpty {
                        sections[marker.label, default: []].append(marker.remainder)
                    }
                } else if let currentLabel {
                    sections[currentLabel, default: []].append(line)
                }
            }

        return sections.mapValues { lines in
            lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func sectionMarker(in line: String) -> (label: String, remainder: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let rawLabel = String(trimmed[..<colon])
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard orderedLabels.contains(rawLabel) else { return nil }
        let remainder = String(trimmed[trimmed.index(after: colon)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (rawLabel, remainder)
    }

    private static func droppingDanglingTail(from text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        if let lastIndex = lines.lastIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            let lastLine = lines[lastIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if lastIndex > 0, isDanglingFragment(lastLine) {
                return lines[..<lastIndex]
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let paragraphs = text.components(separatedBy: "\n\n")
        guard let last = paragraphs.last?.trimmingCharacters(in: .whitespacesAndNewlines),
              paragraphs.count > 1,
              !last.isEmpty
        else {
            return text
        }

        if isDanglingFragment(last) {
            return paragraphs.dropLast().joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func isDanglingFragment(_ text: String) -> Bool {
        let lower = text.lowercased()
        let endsCleanly = ".!?\"”".contains(text.last ?? ".")
        let looksLikeFragment = lower == "try"
            || lower.hasPrefix("try: ")
            || lower.hasPrefix("dr. ")
            || lower.split(separator: " ").count <= 4
        return !endsCleanly && looksLikeFragment
    }
}

enum StudentNotePageGenerator {
    static func draftCandidate(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date(),
        semanticScorer: StacksSemanticScoring? = nil
    ) -> SurfacePage? {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let source = BookPageSourceRegistry.source(for: .note)
        guard let entity = selectedEntity(for: day, inputs: inputs, now: now) else { return nil }
        return draftCandidate(
            for: entity,
            source: source,
            day: day,
            inputs: inputs,
            now: now,
            semanticScorer: semanticScorer
        )
    }

    static func draftCandidate(
        for entity: NarrativeWorldEntity,
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        semanticScorer: StacksSemanticScoring? = nil
    ) -> SurfacePage {
        let slot = SurfaceCadence.slotID(for: now, hours: 3)
        let playerName = CharacterLetterPageGenerator.preferredPlayerName(inputs: inputs)
        let voice = CharacterLetterPageGenerator.voiceProfile(for: entity)
        let weatherLine = inputs.weather?.phrase.nonEmpty ?? inputs.enchantedWeather?.summary.nonEmpty ?? "No weather signal is available."
        let worldEventLine = inputs.activeWorldEvents.map(\.title).joined(separator: ", ").nonEmpty ?? "No active world event."
        let allEntityMemories = inputs.narrative?.entityMemories.filter { $0.entityID == entity.id } ?? []
        let memoryLines = allEntityMemories
            .filter { !$0.tags.contains("cast-act") }
            .prefix(4)
            .map(\.summary)
        let memories = memoryLines.map { "- \($0)" }.joined(separator: "\n")
        // A note is the right size for exactly one piece of unfinished business
        // with somebody else: muttered, unexplained, and not resolved.
        let carriedGrievance = allEntityMemories
            .first { $0.tags.contains("cast-act") }?
            .summary
        let priorNotes = (inputs.days + [day]).flatMap(\.pages)
            .filter { $0.type == .note && $0.tags.contains("sender:\(entity.id)") }
            .sorted { $0.createdAt < $1.createdAt }
        let replyMemory = priorNotes.last?.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let timeLine = timeOfDayLine(now: now)
        let classLine = classLine(inputs: inputs, day: day)
        let keptPages = (inputs.days + [day]).flatMap(\.capturedPages)
        let noteKind = noteKind(
            for: entity,
            inputs: inputs,
            day: day,
            hasKeptPages: !keptPages.isEmpty,
            now: now
        )
        let passageQuery = notePassageQuery(
            entity: entity,
            noteKind: noteKind,
            deliveryContext: "\(timeLine). \(classLine)",
            memories: memories,
            priorReply: replyMemory,
            inputs: inputs
        )
        let scorer = semanticScorer
            ?? (inputs.semanticPassageSelectionEnabled ? SemanticKeepEcho.keepTimeScorer : nil)
        let selectedPassage = MeaningfulPassageSelector.select(
            pages: keptPages,
            query: passageQuery,
            inputs: inputs,
            scorer: scorer,
            maximumAge: 120 * 86_400,
            minimumScore: 8,
            honorPriorUse: false,
            includeKeptGeneratedPages: true,
            now: now
        )
        let selectedPage = selectedPassage.flatMap { selection in
            keptPages.first { $0.id == selection.pageID }
        }
        let subjectKind = selectedPage.map { noteSubjectKind(for: $0) }
        let passageSection = selectedPassage.map {
            """
            REQUIRED KEPT-PAGE SUBJECT (the note is about this):
            - From a \($0.pageType.shortTitle) page: “\($0.excerpt)”
            - Subject kind: \(subjectKind ?? "kept-page event")
            - Selection basis: \($0.reason)

            This is not optional atmosphere. Make the sender react to, question, tease, warn about, or otherwise interpret this exact kept thing through their own beliefs, wants, faults, habits, interests, relationships, and memories. If it is reader-authored, quote or closely echo at most one short phrase. If it is kept fiction, speak of what happened in the fiction as an in-world event; never claim the reader did it in ordinary life. Never say you searched, ranked, analyzed, or opened an archive.
            """
        } ?? "No substantial kept page is available for this note. Do not invent one."
        let relationshipContext = CharacterLetterPageGenerator.thirdPartyRelationshipContext(
            for: entity,
            inputs: inputs,
            allowInCurrentLetter: true
        )
        var characterContext = memoryLines.map { "Current memory: \($0)" }
        characterContext += relationshipContext
        if let replyMemory {
            characterContext.append("The reader previously replied to this sender: \(replyMemory)")
        }
        if let selectedPassage {
            characterContext.append("The kept subject this character is responding to now: \(selectedPassage.excerpt)")
        }
        let characterCanon = CharacterCanonPacket.promptSection(
            for: [entity],
            contextLines: characterContext
        )
        let body = """
        Sender: \(entity.name)
        Address the player as: \(playerName)
        Note kind: \(noteKind)
        Delivery context: \(timeLine). \(classLine)
        Weather: \(weatherLine)
        World events: \(worldEventLine)

        Writing voice:
        \(voice.promptDescription)

        Kept-page subject:
        \(passageSection)

        Sender memories:
        \(memories.isEmpty ? "No explicit memory packet for this sender." : memories)\(carriedGrievance.map { grievance in
            """


            One thing this sender is carrying about another character:
            - \(grievance)

            You may mutter about it in half a sentence, the way people do about somebody who is not in the room. Do not explain it, resolve it, or let the note become about it. It is theirs, from their side only, and the other person would tell it differently.
            """
        } ?? "")

        Prior note reply:
        \(replyMemory.map { "The reader previously slipped back: \"\($0.replacingOccurrences(of: "\n", with: " ").prefix(180))...\"" } ?? "No prior note reply from the reader.")

        Write one quick in-world note slipped to the player. When a kept-page subject is supplied, the note must plainly be about it; weather, corridor business, and world events are secondary and may appear only if they sharpen that response. Let the sender's whole binding character packet decide what they notice, misunderstand, protect, joke about, want, avoid, and ask next, not merely their surface diction. Keep it brief enough to fit on folded paper. Do not format as a formal letter. Do not claim the player completed actions not in the packet.
        """
        var tags = ["note", "student-note", "reply", "sender:\(entity.id)"] + Array(entity.tags.prefix(4))
        if let selectedPassage {
            tags += [
                "\(MeaningfulPassageSelector.sourceTagPrefix)\(selectedPassage.pageID)",
                "meaningful-source-use:note"
            ]
        }
        var metadata = [
            "source": source.id,
            "senderID": entity.id,
            "senderName": entity.name,
            "playerName": playerName,
            "noteKind": noteKind,
            "deliveryContext": "\(timeLine). \(classLine)",
            "weatherContext": weatherLine,
            "worldEventTitles": worldEventLine,
            "writingVoice": voice.promptDescription,
            CharacterCanonPacket.metadataKey: characterCanon,
            "slotID": slot,
            "placeholder": "\(entity.name) just slipped you a note.",
            "tags": tags.joined(separator: ",")
        ]
        if let selectedPassage {
            metadata["meaningfulSourcePageID"] = selectedPassage.pageID
            metadata["meaningfulSourcePageType"] = selectedPassage.pageType.rawValue
            metadata["meaningfulSourcePassage"] = selectedPassage.excerpt
            metadata["meaningfulSourceReason"] = selectedPassage.reason
            metadata["meaningfulSourceSemanticSimilarity"] = selectedPassage.semanticSimilarity.map { String($0) } ?? ""
            metadata["noteSubjectKind"] = subjectKind ?? "kept-page event"
            metadata["noteSubjectRequired"] = "true"
        }
        if let asset = CharacterPortrait.bundledAssetName(forName: entity.name) {
            metadata["assetName"] = asset
        }
        if let imageAsset = inputs.customCastMembers.first(where: { $0.entity.id == entity.id })?.imageAsset {
            metadata["imageAssetKind"] = imageAsset.kind.rawValue
            metadata["imageAssetReference"] = imageAsset.reference
        }
        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)-\(entity.id)",
            type: .note,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(86, 58 + entity.belief / 4 + entity.narrativeWeight / 4),
            reason: "\(entity.name) has a folded scrap moving hand to hand.",
            prompt: "\(entity.name) just slipped you a note.",
            detail: "A quick folded message, still unread.",
            payload: BookPagePayload(
                headline: "Note from \(entity.name)",
                body: body,
                metadata: metadata
            )
        )
    }

    static func noteReplyMemorySummary(senderName: String, reply: String) -> String {
        let excerpt = reply
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(160)
        return "\(senderName) remembers a note passed back by the reader: \"\(excerpt)...\""
    }

    private static func notePassageQuery(
        entity: NarrativeWorldEntity,
        noteKind: String,
        deliveryContext: String,
        memories: String,
        priorReply: String?,
        inputs: BookSourceInputs
    ) -> String {
        var pieces = [
            entity.name,
            noteKind,
            deliveryContext,
            entity.beliefs.prefix(2).joined(separator: " "),
            entity.traits.prefix(4).joined(separator: " "),
            entity.tags.prefix(6).joined(separator: " "),
            memories,
            priorReply ?? ""
        ]
        pieces += inputs.currentArc.map { [$0.title, $0.phase.rawValue] } ?? []
        pieces += inputs.activeWorldEvents.prefix(2).map { "\($0.title) \($0.packet.logline)" }
        pieces += inputs.continuity.strongestSignals.prefix(3).map(\.line)
        return pieces.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    private static func selectedEntity(for day: BookDay, inputs: BookSourceInputs, now: Date) -> NarrativeWorldEntity? {
        let recentSenders = Set(day.pages.filter { $0.type == .note }.compactMap { $0.tags.first(where: { $0.hasPrefix("sender:") })?.dropFirst("sender:".count) }.map(String.init))
        let candidates = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
            .filter { !recentSenders.contains($0.id) }
        guard !candidates.isEmpty else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 3)
        return StableWeightedRoll.pick(
            from: candidates.sorted { $0.name < $1.name },
            seed: "\(day.id)-\(slot)-student-note-sender",
            weight: { entityScore($0, day: day, inputs: inputs, slot: slot) }
        )
    }

    private static func entityScore(_ entity: NarrativeWorldEntity, day: BookDay, inputs: BookSourceInputs, slot: String) -> Int {
        let recentPages = (Array(inputs.days.suffix(14)) + [day])
            .flatMap(\.capturedPages)
            .suffix(24)
        let recentText = recentPages.map {
            "\($0.promptText) \($0.userInput) \($0.playerReply) \($0.tags.joined(separator: " "))"
        }.joined(separator: " ").lowercased()
        let memoryHit = recentText.contains(entity.id.lowercased()) || recentText.contains(entity.name.lowercased()) ? 24 : 0
        let narrativeHit = inputs.narrative?.weightedEntityIDs.contains(entity.id) == true ? 12 : 0
        let relationship = inputs.entityBeliefOffsets[entity.id] ?? 0
        let jitter = stableIndex(for: "\(slot)-\(entity.id)-student-note", count: 14)
        return entity.belief + entity.narrativeWeight + relationship + memoryHit + narrativeHit + jitter
    }

    private static func noteKind(
        for entity: NarrativeWorldEntity,
        inputs: BookSourceInputs,
        day: BookDay,
        hasKeptPages: Bool,
        now: Date
    ) -> String {
        let seed = stableIndex(for: "\(day.id)-\(entity.id)-\(SurfaceCadence.slotID(for: now, hours: 3))-kind", count: 100)
        if hasKeptPages {
            if seed < 30 { return "question about a kept page" }
            if seed < 55 { return "tease about a kept page" }
            if seed < 75 { return "warning prompted by a kept page" }
            return "private aside about a kept page"
        }
        if !inputs.activeWorldEvents.isEmpty { return seed.isMultiple(of: 2) ? "warning" : "gossip" }
        if day.pages.contains(where: { $0.type == .academyClass }) { return "class question" }
        if inputs.weather != nil && seed < 24 { return "weather check-in" }
        if seed < 22 { return "question" }
        if seed < 44 { return "tease" }
        if seed < 66 { return "invitation" }
        if seed < 82 { return "confession-adjacent aside" }
        return "tiny joke"
    }

    private static func noteSubjectKind(for page: BookPage) -> String {
        if !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "the reader's own reply on a kept page"
        }
        if page.origin == .userAuthored || page.origin == .imported {
            return "the reader's own kept words"
        }
        return "an event from kept fiction"
    }

    private static func classLine(inputs: BookSourceInputs, day: BookDay) -> String {
        if let lastClass = day.pages.reversed().first(where: { $0.type == .academyClass }) {
            return "A recent class page is in the air: \(lastClass.promptText.bookPreviewSentenceLimit(1))"
        }
        if let event = inputs.calendarEvents.first?.title.nonEmpty {
            return "Calendar pressure: \(event)"
        }
        return "Between classes, where folded paper travels fastest."
    }

    private static func timeOfDayLine(now: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<11: return "Morning passing period"
        case 11..<14: return "Lunch hour"
        case 14..<18: return "Afternoon corridor"
        case 18..<22: return "Evening study table"
        default: return "After-hours margin"
        }
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

enum CharacterLetterPageGenerator {
    static func draftCandidate(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date(),
        semanticScorer: StacksSemanticScoring? = nil
    ) -> SurfacePage? {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let source = BookPageSourceRegistry.source(for: .letter)
        guard let entity = selectedEntity(for: day, inputs: inputs, now: now) else { return nil }
        return draftCandidate(
            for: entity,
            source: source,
            day: day,
            inputs: inputs,
            now: now,
            semanticScorer: semanticScorer
        )
    }

    static func draftCandidate(
        for entity: NarrativeWorldEntity,
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        semanticScorer: StacksSemanticScoring? = nil
    ) -> SurfacePage {
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        let interest = entity.unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? entity.beliefs.first
            ?? entity.traits.first
            ?? "ordinary wonder"
        let homeContext = homeContextLine(inputs: inputs, day: day)
        let playerName = preferredPlayerName(inputs: inputs)
        let voice = voiceProfile(for: entity)
        let characterCanon = CharacterCanonPacket.promptSection(for: [entity])
        let talismanMoves = ChapterTalismanBeliefMoves.moves(
            for: [entity],
            seed: stableIndex(for: "\(day.id)-\(slot)-\(entity.id)-letter-talisman", count: 10_000)
        )
        let talismanMoveLines = talismanMoves.map(\.promptLine).joined(separator: "\n")
        let talismanDeltaTokens = talismanMoves.compactMap(\.ledgerToken).joined(separator: ",")
        let query = researchQuery(for: interest, homeContext: homeContext)
        let isFirstLetterFromSender = !hasPriorLetter(from: entity, day: day, inputs: inputs)
        let occasion = isFirstLetterFromSender
            ? introductoryLetterOccasion(for: entity, interest: interest, homeContext: homeContext)
            : letterOccasion(inputs: inputs, seedKey: "\(day.id)-\(slot)-\(entity.id)")
        let crossLetter = crossLetterMemory(for: entity, day: day, inputs: inputs, now: now)
        let relationshipWeather = thirdPartyRelationshipContext(
            for: entity,
            inputs: inputs,
            allowInCurrentLetter: !isFirstLetterFromSender
        )
        let passageQuery = letterPassageQuery(
            entity: entity,
            interest: interest,
            occasion: occasion,
            crossLetter: crossLetter,
            relationshipWeather: relationshipWeather,
            inputs: inputs
        )
        let scorer = semanticScorer
            ?? (inputs.semanticPassageSelectionEnabled ? SemanticKeepEcho.keepTimeScorer : nil)
        let selectedPassage = isFirstLetterFromSender ? nil : MeaningfulPassageSelector.select(
            pages: (inputs.days + [day]).flatMap(\.capturedPages),
            query: passageQuery,
            inputs: inputs,
            scorer: scorer,
            maximumAge: 180 * 86_400,
            minimumScore: 18,
            now: now
        )
        let memoryPacket = memoryPacket(for: entity, inputs: inputs, selectedPassage: selectedPassage)
        let eventPacket = inputs.activeWorldEvents.influencePacket
        let letterEventInstruction = inputs.activeWorldEvents
            .map { $0.packet.letterInstruction }
            .joined(separator: "\n")
        let body = """
        Sender: \(entity.name)
        Address the player as: \(playerName)
        Unwritten Interest: \(interest)
        Home Context: \(homeContext)
        Research Query: \(query)

        Letter occasion:
        \(occasion ?? "No special occasion. Write because the sender wanted to.")

        Relationship context:
        \(isFirstLetterFromSender ? "This is your first letter to the player. Introduce yourself before asking anything of them. Let this letter establish who you are, what you notice, and why you are writing from the margins now." : (crossLetter ?? "This is not your first letter to them, but there is no urgent prior-letter memory to acknowledge. Build naturally from the established relationship."))

        Offscreen relationship weather:
        \(relationshipWeather.isEmpty ? "No third-party cast relationship should be mentioned in this letter." : relationshipWeather.joined(separator: "\n"))

        Writing Voice:
        \(voice.promptDescription)

        Memory and narrative packet:
        \(memoryPacket)

        Chapter talisman move:
        \(talismanMoveLines.isEmpty ? "No chapter talisman move is being made in this letter." : talismanMoveLines)

        Current world event:
        \(eventPacket.isEmpty ? "No world event is currently pressing on this letter." : eventPacket)
        \(letterEventInstruction)

        Write a real letter to the player. If this is the first letter from this sender, make it an introduction letter first: the sender should name their relation to the margins, reveal their voice through one or two concrete self-details, and offer a small reason the player might want to hear from them again. Do not assume prior intimacy. If a letter occasion is given, it is the reason this letter exists - open from it and let it carry the letter, gently and without diagnosing. Offscreen relationship weather is optional ambience: mention at most one line, in passing, only if it fits the letter's natural voice; do not turn it into the main plot or invent a full argument. Use live web research if clippings are supplied. If no clippings are supplied, fall back to the model's own general knowledge without pretending it browsed.
        """
        var tags = ["letter", "letters", "research", "sender:\(entity.id)"] + Array(entity.tags.prefix(4))
        if let selectedPassage {
            tags += [
                "\(MeaningfulPassageSelector.sourceTagPrefix)\(selectedPassage.pageID)",
                "meaningful-source-use:letter"
            ]
        }
        var metadata = [
            "source": source.id,
            "senderID": entity.id,
            "senderName": entity.name,
            "playerName": playerName,
            "unwrittenInterest": interest,
            "homeContext": homeContext,
            "letterOccasion": occasion ?? "",
            "letterRelationshipStage": isFirstLetterFromSender ? "introduction" : "continuing",
            "crossLetterMemory": crossLetter ?? "",
            "thirdPartyRelationshipContext": relationshipWeather.joined(separator: "\n"),
            "researchQuery": query,
            "writingVoice": voice.promptDescription,
            CharacterCanonPacket.metadataKey: characterCanon,
            "chapterTalismanMoves": talismanMoveLines,
            "chapterTalismanDeltas": talismanDeltaTokens,
            "slotID": slot,
            "placeholder": "A researched letter is being written through the Margin-Glass.",
            "tags": tags.joined(separator: ",")
        ]
        if let selectedPassage {
            metadata["meaningfulSourcePageID"] = selectedPassage.pageID
            metadata["meaningfulSourcePageType"] = selectedPassage.pageType.rawValue
            metadata["meaningfulSourcePassage"] = selectedPassage.excerpt
            metadata["meaningfulSourceReason"] = selectedPassage.reason
            metadata["meaningfulSourceSemanticSimilarity"] = selectedPassage.semanticSimilarity.map { String($0) } ?? ""
        }
        if !eventPacket.isEmpty {
            metadata["worldEventPacket"] = eventPacket
            metadata["worldEventLetterInstruction"] = letterEventInstruction
            metadata["worldEventIDs"] = inputs.activeWorldEvents.map(\.id).joined(separator: ",")
            metadata["worldEventTitles"] = inputs.activeWorldEvents.map(\.title).joined(separator: ", ")
        }
        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)-\(entity.id)",
            type: .letter,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(84, 54 + entity.belief / 4 + entity.narrativeWeight / 4),
            reason: "\(entity.name) has a carefully-worked letter gathering itself in the margins.",
            prompt: "A letter from \(entity.name)",
            detail: "A little note, all looked-up and thought-through, about \(interest.trimmingCharacters(in: CharacterSet(charactersIn: ". "))).",
            payload: BookPagePayload(
                headline: "Letter from \(entity.name)",
                body: body,
                metadata: metadata
            )
        )
    }

    static func preferredPlayerName(inputs: BookSourceInputs) -> String {
        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let preferred = usableFacts.first { $0.questionID == "onboarding-name" }?.answer
            ?? usableFacts.first { $0.questionID == "called" }?.answer
            ?? usableFacts.first { $0.tags.contains("name") || $0.tags.contains("identity") }?.answer
        let trimmed = preferred?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.nonEmpty ?? "friend"
    }

    static func voiceProfile(for entity: NarrativeWorldEntity) -> WritingVoiceProfile {
        entity.resolvedWritingVoice
    }

    private static func selectedEntity(for day: BookDay, inputs: BookSourceInputs, now: Date) -> NarrativeWorldEntity? {
        let recentSenders = Set(day.pages.filter { $0.type == .letter }.compactMap { $0.tags.first(where: { $0.hasPrefix("sender:") })?.dropFirst("sender:".count) }.map(String.init))
        let candidates = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
            .filter { !($0.unwrittenInterest ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !recentSenders.contains($0.id) }
        guard !candidates.isEmpty else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        return StableWeightedRoll.pick(
            from: candidates.sorted { $0.name < $1.name },
            seed: "\(day.id)-\(slot)-letter-sender",
            weight: { entityScore($0, day: day, inputs: inputs, slot: slot) }
        )
    }

    private static func entityScore(_ entity: NarrativeWorldEntity, day: BookDay, inputs: BookSourceInputs, slot: String) -> Int {
        let recentText = day.pages.suffix(8).map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }.joined(separator: " ").lowercased()
        let memoryHit = recentText.contains(entity.id.lowercased()) || recentText.contains(entity.name.lowercased()) ? 18 : 0
        let narrativeHit = inputs.narrative?.weightedEntityIDs.contains(entity.id) == true ? 14 : 0
        let jitter = stableIndex(for: "\(slot)-\(entity.id)", count: 12)
        return entity.belief + entity.narrativeWeight + memoryHit + narrativeHit + jitter
    }

    private static func homeContextLine(inputs: BookSourceInputs, day: BookDay) -> String {
        let facts = inputs.selfFacts
            .filter { $0.usePermission != .doNotUse && ($0.tags.contains("home") || $0.tags.contains("place")) }
            .prefix(3)
            .map(\.answer)
        if !facts.isEmpty {
            return facts.joined(separator: " | ")
        }
        if let weather = inputs.weather?.phrase.nonEmpty {
            return "the player's present weather: \(weather)"
        }
        let pageHint = day.pages.reversed().first { $0.tags.contains("home") || $0.type == .location }?.userInput.nonEmpty
        return pageHint ?? "the player's actual home region, inferred only from supplied context"
    }

    private static func researchQuery(for interest: String, homeContext: String) -> String {
        "\(interest) \(homeContext) local history ecology culture"
            .split(separator: " ")
            .prefix(18)
            .joined(separator: " ")
    }

    /// What's passed between the sender and the reader since the sender's last
    /// letter: their previous letter, any Two Readings the reader took their side
    /// (or their rival's), and how their Belief standing has moved. Lets a letter
    /// remember itself and the relationship instead of starting cold each time.
    static func crossLetterMemory(for entity: NarrativeWorldEntity, day: BookDay, inputs: BookSourceInputs, now: Date = Date(), calendar: Calendar = .current) -> String? {
        let keptPages = (inputs.days + [day]).flatMap(\.pages)
        var lines: [String] = []

        let priorLetters = keptPages
            .filter { $0.type == .letter && $0.tags.contains("sender:\(entity.id)") }
            .sorted { $0.createdAt < $1.createdAt }
        if let last = priorLetters.last {
            let ageDays = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: last.createdAt), to: calendar.startOfDay(for: now)).day ?? 0)
            let excerpt = last.userInput
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(160)
            let whenLine = ageDays == 0 ? "earlier today" : (ageDays == 1 ? "yesterday" : "about \(ageDays) days ago")
            lines.append("You last wrote to them \(whenLine). Part of that letter: \"\(excerpt)…\" You may refer back to it, naturally.")

            let reply = last.playerReply.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reply.isEmpty {
                let replyExcerpt = reply
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(160)
                lines.append("After that letter, the reader wrote back to you. Part of what they said: \"\(replyExcerpt)…\" Let it have reached you: answer it once, glancingly, the way someone recalls a line from a letter rather than quoting it back.")
            }
        }

        let sidings = keptPages
            .filter { $0.type == .twoReadings && $0.tags.contains("entity:\(entity.id)") }
            .sorted { $0.createdAt > $1.createdAt }
        if let recent = sidings.first,
           let sidedTag = recent.tags.first(where: { $0.hasPrefix("sided:") }) {
            let sided = String(sidedTag.dropFirst("sided:".count))
            if sided == entity.id {
                lines.append("Recently, when two of you disagreed, the reader sided WITH you. You feel a little vindicated, and warmer toward them.")
            } else {
                lines.append("Recently, when two of you disagreed, the reader sided AGAINST you. It stung; be honest about it, without sulking.")
            }
        }

        let standing = inputs.entityBeliefOffsets[entity.id] ?? 0
        if standing >= 6 {
            lines.append("The reader has been giving you Belief lately; you feel more present in their Book.")
        } else if standing <= -4 {
            lines.append("You've felt fainter in the Book lately; their attention has been elsewhere.")
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func thirdPartyRelationshipContext(
        for entity: NarrativeWorldEntity,
        inputs: BookSourceInputs,
        allowInCurrentLetter: Bool = false
    ) -> [String] {
        guard allowInCurrentLetter else { return [] }
        let characters = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
        let characterByID = Dictionary(uniqueKeysWithValues: characters.map { ($0.id, $0) })
        guard characterByID[entity.id] != nil else { return [] }

        let authoredByPair = Dictionary(
            grouping: NarrativePackRegistry.relationships,
            by: { NarrativeGraphData.relationshipPairKey($0.sourceEntityID, $0.targetEntityID) }
        )

        struct Candidate {
            var kind: CastBondKind
            var line: String
            var score: Int
            var otherName: String
        }

        var candidates: [Candidate] = []
        let knownIDs = Set(characterByID.keys)
        let pairs = Set(inputs.relationshipField.keys).union(authoredByPair.keys)
        for pairKey in pairs {
            let ids = pairKey.split(separator: "|").map(String.init)
            guard ids.count == 2, ids.contains(entity.id) else { continue }
            let otherID = ids[0] == entity.id ? ids[1] : ids[0]
            guard knownIDs.contains(otherID), let other = characterByID[otherID] else { continue }

            let tie = inputs.relationshipField[pairKey] ?? .zero
            let authored = authoredByPair[pairKey] ?? []
            let authoredWarmth = authored.map(\.warmth).max() ?? 0
            let authoredTension = authored.map(\.tension).max() ?? 0
            let authoredTrust = authored.map(\.trust).max() ?? 0
            let authoredWeight = authored.map(\.narrativeWeight).max() ?? 0
            let warmth = tie.warmth + authoredWarmth + authoredTrust / 2
            let tension = tie.tension + authoredTension
            let familiarity = tie.familiarity + authoredWeight / 6
            let dynamicShift = abs(tie.warmth) + tie.tension + tie.familiarity

            if tension > warmth, tension >= 5, dynamicShift > 0 {
                candidates.append(Candidate(
                    kind: .rivalry,
                    line: "[Contrast: You have grown tense with \(other.name) lately. Mention one brief, concrete annoyance or wary observation about them in passing, if it fits.]",
                    score: tension + dynamicShift,
                    otherName: other.name
                ))
            } else if warmth >= 5, warmth > tension, familiarity >= 2 {
                candidates.append(Candidate(
                    kind: .alliance,
                    line: "[Alliance: You are close with \(other.name) lately. Mention one small kindness, shared clue, or coordinated observation from them in passing, if it fits.]",
                    score: warmth + familiarity + dynamicShift,
                    otherName: other.name
                ))
            }
        }

        let contrasts = candidates
            .filter { $0.kind == .rivalry }
            .sorted { left, right in
                if left.score == right.score { return left.otherName < right.otherName }
                return left.score > right.score
            }
            .prefix(1)
            .map(\.line)
        let alliances = candidates
            .filter { $0.kind == .alliance }
            .sorted { left, right in
                if left.score == right.score { return left.otherName < right.otherName }
                return left.score > right.score
            }
            .prefix(1)
            .map(\.line)
        return Array(contrasts + alliances).prefix(2).map(\.self)
    }

    /// The oblique memory line recorded when the reader writes back to a sender.
    /// Framed as something the character *remembers* (excerpt-trimmed) so future
    /// letters can glance at it through the per-sender memory packet rather than
    /// quoting the reply verbatim.
    static func penPalReplyMemorySummary(senderName: String, reply: String) -> String {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(160)
        return "\(senderName) remembers that the reader wrote back. In their reply: \"\(excerpt)…\""
    }

    private static func hasPriorLetter(from entity: NarrativeWorldEntity, day: BookDay, inputs: BookSourceInputs) -> Bool {
        (inputs.days + [day])
            .flatMap(\.pages)
            .contains { $0.type == .letter && $0.tags.contains("sender:\(entity.id)") }
    }

    private static func memoryPacket(
        for entity: NarrativeWorldEntity,
        inputs: BookSourceInputs,
        selectedPassage: MeaningfulPassageSelector.Selection?
    ) -> String {
        let allMine = inputs.narrative?.entityMemories.filter { $0.entityID == entity.id } ?? []
        // What this person is carrying about somebody else. These are kept
        // separate from ordinary memories because they are the only ones the
        // sender has standing to be aggrieved, embarrassed, or quietly pleased
        // about, and a letter that never mentions the thing everybody is not
        // mentioning is a letter from nobody.
        let aboutOthers = allMine
            .filter { $0.tags.contains("cast-act") }
            .prefix(3)
            .map { "- \($0.summary)" }
            .joined(separator: "\n")
        let memories = allMine
            .filter { !$0.tags.contains("cast-act") }
            .prefix(4)
            .map { "- \($0.summary)" }
            .joined(separator: "\n")
        let grievances = aboutOthers.isEmpty ? "" : """


        What this sender is currently carrying about somebody else:
        \(aboutOthers)

        How to use it:
        - These are theirs, in their own frame. The other person remembers it differently and is not here to argue.
        - You may bring one up, in passing, the way people do: a half-sentence of complaint, a thing they are pretending not to mind, a kindness they still have not acknowledged.
        - Do not explain it, resolve it, or make the letter be about it. It is furniture, not subject.
        - Use at most one. A sender who lists their grievances is writing a memo.
        """
        let continuity = continuityPacket(for: entity, inputs: inputs)
        let passage = selectedPassage.map {
            """
            - From a \($0.pageType.shortTitle) page: “\($0.excerpt)”
            - Selection basis: \($0.reason)
            - Let this be the letter's concrete hinge only if it belongs in this sender's voice. Quote at most one short phrase. Never say you searched, ranked, analyzed, or opened an archive.
            """
        } ?? "No reader passage strongly fits this letter. Do not force a callback."
        return """
        Selected reader passage:
        \(passage)

        Entity memories:
        \(memories.isEmpty ? "No explicit memory packet for this sender." : memories)\(grievances)

        What the Book has begun to notice:
        \(continuity.isEmpty ? "No stable literary pattern has been offered to this sender." : continuity)
        """
    }

    private static func letterPassageQuery(
        entity: NarrativeWorldEntity,
        interest: String,
        occasion: String?,
        crossLetter: String?,
        relationshipWeather: [String],
        inputs: BookSourceInputs
    ) -> String {
        var pieces = [
            entity.name,
            interest,
            entity.beliefs.prefix(3).joined(separator: " "),
            entity.traits.prefix(4).joined(separator: " "),
            entity.goals.prefix(3).joined(separator: " "),
            entity.tags.prefix(7).joined(separator: " "),
            occasion ?? "",
            crossLetter ?? "",
            relationshipWeather.joined(separator: " ")
        ]
        pieces += inputs.narrative?.entityMemories
            .filter { $0.entityID == entity.id }
            .prefix(4)
            .map(\.summary) ?? []
        pieces += inputs.currentArc.map { [$0.title, $0.phase.rawValue] } ?? []
        pieces += inputs.continuity.strongestSignals.prefix(4).map(\.line)
        pieces += inputs.themes.sorted { $0.strength > $1.strength }.prefix(2).flatMap { [$0.name, $0.line] }
        pieces += inputs.clusters.sorted { $0.strength > $1.strength }.prefix(2).flatMap { [$0.name, $0.line] }
        return pieces.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    private static func continuityPacket(for entity: NarrativeWorldEntity, inputs: BookSourceInputs) -> String {
        let related = inputs.continuity.strongestSignals.filter { signal in
            signal.relatedEntityIDs.contains(entity.id)
                || signal.tags.contains(entity.id)
                || entity.tags.contains(where: { signal.tags.contains($0) })
        }
        let selected = related.isEmpty ? inputs.continuity.strongestSignals.prefix(3).map(\.self) : Array(related.prefix(4))
        var lines = selected.map { "- \($0.line)" }
        for constellation in ConstellationKeeper.namedConstellations(inputs.constellations).prefix(3) {
            lines.append("- The Book has named a constellation it keeps about the reader: \(constellation.displayName). \(constellation.latestLine) Characters may refer to it by name, as something the Book keeps.")
        }
        for wager in inputs.wagers.filter(\.isSealed).prefix(2) {
            lines.append("- The Book has a sealed wager pending: \(wager.prediction) Characters may know the Book wagers but not the outcome.")
        }
        if let theme = inputs.themes.max(by: { $0.monthKey < $1.monthKey }) {
            lines.append("- \(theme.promptLine) Characters may allude to the theme without naming the app or sounding clinical.")
        }
        return lines.joined(separator: "\n")
    }

    /// When something the reader used to write about has gone properly quiet,
    /// that absence becomes the reason a letter exists - the sender writes
    /// because of it, not merely mentioning it.
    private static func letterOccasion(inputs: BookSourceInputs, seedKey: String) -> String? {
        if let absence = inputs.continuity.strongestSignals.first(where: { $0.kind == .absence && $0.strength >= 60 }) {
            return "\(absence.line) The sender writes because of this quiet: ask after \(absence.subjectName) the way a friend asks after someone who stopped coming to the cafe - warmly, without alarm, leaving room for the answer to be ordinary. Do not demand a reply; let the margin hold the question."
        }
        // Now and then a letter arrives that wants nothing back: a gift with
        // the reply released in advance. Being chosen should sometimes cost
        // the reader nothing at all, especially on her tired days.
        if stableIndex(for: "\(seedKey)-no-reply-letter", count: 4) == 0 {
            return "This letter is a gift, not a correspondence. The sender writes to hand the player one small true thing (an observation saved up for them, something seen that only they would appreciate) and wants nothing back. Say so plainly near the end: no reply is wanted or waited for; the letter is theirs to keep. Ask no questions that need answers."
        }
        return nil
    }

    private static func introductoryLetterOccasion(for entity: NarrativeWorldEntity, interest: String, homeContext: String) -> String {
        "\(entity.name) is writing their first letter to the player. This letter should introduce the sender as a person, not summarize a dossier: what they care about, how \(interest) draws their attention, and why \(homeContext) makes the player's ordinary world worth writing to. Keep the invitation small and open-ended; build trust before building plot."
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

enum CompassRunStep: String, CaseIterable, Identifiable {
    case notice
    case embark
    case sense
    case write
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notice:
            return "Notice"
        case .embark:
            return "Embark"
        case .sense:
            return "Sense"
        case .write:
            return "Write"
        case .rest:
            return "Rest"
        }
    }

    var compassPoint: String {
        switch self {
        case .notice:
            return "North"
        case .embark:
            return "East"
        case .sense:
            return "South"
        case .write:
            return "West"
        case .rest:
            return "Center"
        }
    }

    var prompt: String {
        switch self {
        case .notice:
            return "I wonder..."
        case .embark:
            return "Plan so badly it cannot fail."
        case .sense:
            return "Give your senses a tiny game."
        case .write:
            return "Keep one sentence from time."
        case .rest:
            return "Let the center hold."
        }
    }

    var standaloneDetail: String {
        switch self {
        case .notice:
            return "Choose the run's goal as one I wonder question."
        case .embark:
            return "Make the 3 D's into a plan for the North goal."
        case .sense:
            return "Use the body at the start or destination so the goal becomes real."
        case .write:
            return "Save the best sensory moment from the run in one sentence."
        case .rest:
            return "Set the phone down for one quiet minute. Rest is the pin, not the prize."
        }
    }

    var capturePlaceholder: String {
        switch self {
        case .notice:
            return "Keep the I wonder goal that will steer the run."
        case .embark:
            return "Write the plan you will follow to answer the goal."
        case .sense:
            return "Write what your body noticed at the start or destination, or keep a photo."
        case .write:
            return "Write the best sensory moment from the run in one sentence."
        case .rest:
            return "After one quiet minute, the needle feels..."
        }
    }

    var scoreBoost: Int {
        switch self {
        case .notice:
            return 8
        case .embark:
            return 11
        case .sense:
            return 12
        case .write:
            return 14
        case .rest:
            return 9
        }
    }

    var missionBody: String {
        switch self {
        case .notice:
            return "North sets the bearing. Start with the Spark and let it become the goal of the run."
        case .embark:
            return "East turns the North question into a plan: where to go, what tiny delight helps, and how you will know the goal is complete."
        case .sense:
            return "South puts the run into the body at the start or destination, so the goal is answered by senses instead of only thoughts."
        case .write:
            return "West saves the best sensory moment from the run in one exact sentence."
        case .rest:
            return "The Center keeps the compass from becoming homework. Sixty seconds of no input is a valid completion."
        }
    }
}

/// The intake is deliberately a short sequence instead of a dashboard. A
/// Compass Run works best when the reader makes one small decision at a time;
/// showing every constraint at once makes the beginning feel like paperwork.
enum CompassRunConstraintStep: String, CaseIterable, Identifiable {
    case location
    case time
    case energy
    case companions
    case budget
    case considerations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location: return "Location"
        case .time: return "Time"
        case .energy: return "Energy"
        case .companions: return "Company"
        case .budget: return "Budget"
        case .considerations: return "Considerations"
        }
    }

    var question: String {
        switch self {
        case .location: return "Where can this run happen?"
        case .time: return "How much time belongs to it?"
        case .energy: return "How much spark do you have?"
        case .companions: return "Who is coming with you?"
        case .budget: return "What may the run spend?"
        case .considerations: return "What must the Compass be kind about?"
        }
    }

    var guidance: String {
        switch self {
        case .location:
            return "Choose a known kind of place, or let me read your current place without keeping precise coordinates."
        case .time:
            return "A true ten-minute run is better than an imaginary afternoon."
        case .energy:
            return "This shrinks the distance and effort. Low energy is useful information, not a failed run."
        case .companions:
            return "The same place needs a different little adventure for one person, a friend, or children."
        case .budget:
            return "The Compass can make a complete run from no money at all."
        case .considerations:
            return "Choose any that matter today, or choose none. These are rails the run must respect."
        }
    }

    var symbol: String {
        switch self {
        case .location: return "mappin.and.ellipse"
        case .time: return "timer"
        case .energy: return "battery.50percent"
        case .companions: return "person.2"
        case .budget: return "dollarsign.circle"
        case .considerations: return "heart.text.clipboard"
        }
    }

    var ordinal: Int {
        Self.allCases.firstIndex(of: self).map { $0 + 1 } ?? 1
    }

    var next: CompassRunConstraintStep? {
        guard let index = Self.allCases.firstIndex(of: self) else { return nil }
        let nextIndex = Self.allCases.index(after: index)
        return nextIndex < Self.allCases.endIndex ? Self.allCases[nextIndex] : nil
    }

    var previous: CompassRunConstraintStep? {
        guard let index = Self.allCases.firstIndex(of: self), index > Self.allCases.startIndex else { return nil }
        return Self.allCases[Self.allCases.index(before: index)]
    }
}

enum CompassPlaceContext: String, CaseIterable, Identifiable {
    case current
    case home
    case work
    case cafe
    case harbor
    case park
    case store
    case library
    case transit
    case waterfront
    case trail
    case neighborhood
    case indoors
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current: return "Current Place"
        case .home: return "Home"
        case .work: return "Work"
        case .cafe: return "Cafe"
        case .harbor: return "Harbor"
        case .park: return "Park"
        case .store: return "Store"
        case .library: return "Library"
        case .transit: return "Transit"
        case .waterfront: return "Waterfront"
        case .trail: return "Trail"
        case .neighborhood: return "Neighborhood"
        case .indoors: return "Indoors"
        case .other: return "Somewhere Else"
        }
    }

    var promptValue: String {
        switch self {
        case .current: return "where I am right now"
        case .home: return "home"
        case .work: return "work"
        case .cafe: return "a cafe"
        case .harbor: return "a harbor"
        case .park: return "a park"
        case .store: return "a store or errand stop"
        case .library: return "a library"
        case .transit: return "in transit"
        case .waterfront: return "near the water"
        case .trail: return "on or near a trail"
        case .neighborhood: return "the neighborhood"
        case .indoors: return "indoors"
        case .other: return "somewhere specific"
        }
    }

    static func inferred(from places: [LocalPlaceSignal]) -> CompassPlaceContext {
        let text = places
            .prefix(8)
            .map { "\($0.name) \($0.category)".lowercased() }
            .joined(separator: " ")
        if text.contains("coffee") || text.contains("cafe") || text.contains("bakery") {
            return .cafe
        }
        if text.contains("harbor") || text.contains("harbour") || text.contains("marina") || text.contains("pier") || text.contains("fish market") {
            return .harbor
        }
        if text.contains("waterfront") || text.contains("beach") || text.contains("river") || text.contains("shore") {
            return .waterfront
        }
        if text.contains("trail") || text.contains("greenway") || text.contains("walkway") {
            return .trail
        }
        if text.contains("park") || text.contains("garden") {
            return .park
        }
        if text.contains("library") {
            return .library
        }
        if text.contains("store") || text.contains("market") || text.contains("shop") || text.contains("pharmacy") {
            return .store
        }
        if text.contains("station") || text.contains("terminal") || text.contains("bus") || text.contains("train") {
            return .transit
        }
        return places.isEmpty ? .current : .neighborhood
    }
}

struct CompassKnownPlace: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var contextID: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var updatedAt: Date

    var context: CompassPlaceContext {
        CompassPlaceContext(rawValue: contextID) ?? .other
    }

    func distanceMeters(to latitude: Double, longitude: Double) -> Double {
        AnchorMath.distanceMeters(
            fromLatitude: self.latitude,
            longitude: self.longitude,
            toLatitude: latitude,
            longitude: longitude
        )
    }
}

struct CompassRunProgress: Equatable {
    var completedSteps: Set<CompassRunStep>
    var latestRunID: String?
    var latestSpark: String?

    var nextStep: CompassRunStep {
        CompassRunStep.allCases.first { !completedSteps.contains($0) } ?? .notice
    }

    var isComplete: Bool {
        CompassRunStep.allCases.allSatisfy { completedSteps.contains($0) }
    }

    static func progress(for day: BookDay) -> CompassRunProgress {
        let compassPages = day.capturedPages.filter { page in
            page.tags.contains("wonder-compass-run") || page.tags.contains("wonder-compass")
        }
        let completed = Set(compassPages.compactMap { page -> CompassRunStep? in
            for tag in page.tags {
                if tag.hasPrefix("compass-step:") {
                    return CompassRunStep(rawValue: String(tag.dropFirst("compass-step:".count)))
                }
            }
            return nil
        })
        let runID = compassPages
            .flatMap(\.tags)
            .first { $0.hasPrefix("compass-run:") }
            .map { String($0.dropFirst("compass-run:".count)) }
        let spark = compassPages
            .last { $0.tags.contains("compass-step:notice") }?
            .userInput
            .split(separator: "\n")
            .first
            .map(String.init)

        return CompassRunProgress(
            completedSteps: completed,
            latestRunID: runID,
            latestSpark: spark
        )
    }
}

struct WonderCompassRunSeed: Equatable {
    var id: String
    var mode: WonderConciergeMode
    var timeBox: String
    var budget: String
    var place: String
    var energy: String
    var companions: String
    var considerations: String
    var circumstance: String
    var spark: String
    var destination: String
    var delight: String
    var definition: String
    var mission: String
    var souvenirPrompt: String
    var restPrompt: String
    var tags: [String]

    var fullPrompt: String {
        [
            "Mode: \(mode.title)",
            "Time: \(timeBox)",
            "Budget: \(budget)",
            "Place: \(place)",
            "Energy: \(energy)",
            "With: \(companions)",
            "Considerations: \(considerations)",
            "Circumstance: \(circumstance)",
            "North: \(spark)",
            "East: Destination: \(destination); Delight: \(delight); Definition: \(definition)",
            "South: \(mission)",
            "West: \(souvenirPrompt)",
            "Center: \(restPrompt)"
        ].joined(separator: "\n")
    }

    func body(for step: CompassRunStep) -> String {
        switch step {
        case .notice:
            return """
            Say it out loud. Say it in your head if there are people about.

            \(spark)

            That's the whole run now: four more steps of going and finding out. Keep the page and we're committed.
            """
        case .embark:
            return """
            North made the goal:
            \(spark)

            East makes the plan to fulfill that goal.

            Destination: \(destination)

            Delight: \(delight)

            Definition: \(definition)

            Cross one real threshold when this plan feels small enough to begin.
            """
        case .sense:
            return """
            Keep North's goal in mind:
            \(spark)

            Follow East's plan toward:
            \(destination)

            South puts you in your body when you reach the goal, or right at the start if this is a stay-put run.

            Body Mission:

            \(mission)

            Let your senses answer what the goal was asking.
            """
        case .write:
            return """
            The run began with:
            \(spark)

            The plan pointed toward:
            \(destination)

            West keeps the best sensory moment from the run in one sentence.

            \(souvenirPrompt)

            One sentence is enough. Make it concrete enough that tomorrow can find it again.
            """
        case .rest:
            return """
            You followed the Compass from a question into a body-memory.

            \(restPrompt)

            Rest is the center of the Compass. Keep this page after the quiet minute, and the completed run warms the Book's Glow.
            """
        }
    }
}

struct PlayfulMission: Identifiable, Equatable {
    var id: String
    var title: String
    var prompt: String
    var proofPrompt: String
    var tags: [String]
    var allowsPhoto: Bool = true
}

enum PlayfulMissionMode: String, CaseIterable, Hashable {
    case witness
    case perform
    case make
    case roam
    case share
    case listen
    case photograph
}

struct PlayfulMissionHost: Equatable {
    var slug: String
    var name: String
    var assetName: String
    var invitationLine: String
}

extension PlayfulMission {
    /// The person whose interests make this particular errand worth sending.
    /// Shadow missions belong to the Dusk Thorn; ordinary missions are cast by
    /// subject so the Page arrives as somebody's curiosity, not a loose prompt.
    var host: PlayfulMissionHost {
        let lowered = Set(tags.map { $0.lowercased() })
        if lowered.contains("shadow-wonder") {
            return PlayfulMissionHost(
                slug: "dusk-thorn",
                name: "The Dusk Thorn",
                assetName: "LabyrinthTalismanDuskThorn",
                invitationLine: "The Thorn found a worn edge and wants evidence before it believes the dark about anything."
            )
        }
        if !lowered.isDisjoint(with: ["people", "connection", "shared-wonder", "kindness"]) {
            return PlayfulMissionHost(
                slug: "serenity-brown",
                name: "Serenity Brown",
                assetName: "LabyrinthCharacterSerenityBrown",
                invitationLine: "Serenity has drawn a tiny route between your attention and somebody else's day."
            )
        }
        if !lowered.isDisjoint(with: ["movement", "outside", "route", "commute", "place", "nature"]) {
            return PlayfulMissionHost(
                slug: "zara-finch",
                name: "Zara Finch",
                assetName: "LabyrinthCharacterZaraFinch",
                invitationLine: "Zara tested the route and left this one small enough to carry."
            )
        }
        if !lowered.isDisjoint(with: ["history", "evidence", "memory", "object", "visual"]) {
            return PlayfulMissionHost(
                slug: "penny-blackletter",
                name: "Penny Blackletter",
                assetName: "LabyrinthCharacterPennyBlackletter",
                invitationLine: "Penny suspects one overlooked detail is holding up the whole scene."
            )
        }
        if !lowered.isDisjoint(with: ["ridiculous", "imagination", "words", "sound"]) {
            return PlayfulMissionHost(
                slug: "pippa-pilcrow",
                name: "Pippa Pilcrow",
                assetName: "LabyrinthCharacterPilcrow",
                invitationLine: "Pippa has put one ordinary fact on roller skates and sent you after it."
            )
        }
        if !lowered.isDisjoint(with: ["inside", "food", "taste", "scent", "making"]) {
            return PlayfulMissionHost(
                slug: "lydia-boggle",
                name: "Professor Boggle",
                assetName: "LabyrinthCharacterLydiaBoggle",
                invitationLine: "Professor Boggle thinks the ordinary room is performing household magic again."
            )
        }
        return PlayfulMissionHost(
            slug: "gwendolyn-mythwright",
            name: "Gwendolyn Mythwright",
            assetName: "LabyrinthCharacterGwendolynMythwright",
            invitationLine: "Gwendolyn requires one field observation for the register of verified wonders."
        )
    }

    /// Variety has to reach the reader's body, route, company, or chosen
    /// medium. Different prose wrapped around the same noticing exercise is
    /// still the same exercise, so selection remembers this coarser shape.
    var playMode: PlayfulMissionMode {
        let lowered = Set(tags.map { $0.lowercased() })
        if !lowered.isDisjoint(with: ["people", "connection", "shared-wonder", "kindness"]) { return .share }
        if !lowered.isDisjoint(with: ["making", "make", "craft"]) { return .make }
        if allowsPhoto && !lowered.isDisjoint(with: ["photo", "photograph"]) { return .photograph }
        if !lowered.isDisjoint(with: ["route", "commute", "outside", "errand"]) { return .roam }
        if !lowered.isDisjoint(with: ["sound", "rhythm", "voice"]) { return .listen }
        if !lowered.isDisjoint(with: ["ridiculous", "performance", "ceremony"]) { return .perform }
        return .witness
    }

    /// The return invitation names a medium that suits the act. All ordinary
    /// capture tools remain available; this is permission, not a requirement.
    var souvenirInvitation: String {
        switch playMode {
        case .share:
            return "\(proofPrompt) Keep only what was freely offered."
        case .perform:
            return "\(proofPrompt) A sentence is enough; the ridiculous part happened out there."
        case .make:
            return allowsPhoto ? "\(proofPrompt) A photograph of the evidence counts." : proofPrompt
        case .roam:
            return allowsPhoto
                ? "\(proofPrompt) Bring back words, a photograph, or a voice scrap."
                : "\(proofPrompt) Bring back words or a voice scrap."
        case .listen:
            return "\(proofPrompt) A voice scrap may answer better than spelling it."
        case .photograph:
            return "\(proofPrompt) A photograph may answer."
        case .witness:
            return allowsPhoto ? "\(proofPrompt) Words or a photograph will do." : proofPrompt
        }
    }
}

// MARK: What a mission actually asks
//
// The whole family used to be stamped at `pressureCost: 0.78`: noticing the
// thing on your desk cost exactly as much as walking somewhere. That number
// clears the 0.75 high-pressure threshold by three hundredths, so every
// playful mission spent the curator's action budget and fell under the
// two-high-pressure-attempts-per-week limiter. Nobody chose to ration these;
// one undifferentiated constant did it silently.
//
// Missions already say what they ask in their own tags, so the cost is read
// from those. A genuinely demanding outward mission still lands above the
// threshold and is still rate-limited, which is correct. "Look at the lamp"
// no longer is.
extension PlayfulMission {
    private var lowered: [String] { tags.map { $0.lowercased() } }

    /// Whether this needs the reader to leave where they are.
    ///
    /// An explicit `inside` tag wins: "night" and "sky" are atmosphere, and a
    /// mission can ask you to guard a lamp at midnight or watch weather through
    /// a window without going anywhere.
    var goesOutside: Bool {
        guard lowered.isDisjoint(with: ["inside", "anywhere"]) else { return false }
        return !lowered.isDisjoint(with: ["outside", "nature", "weather", "sky", "night"])
    }

    var missionMobility: PageCapabilityMobility {
        goesOutside ? .shortDistance : .stationary
    }

    var missionMinutes: Int {
        if goesOutside { return 15 }
        if lowered.contains("movement") { return 10 }
        return 5
    }

    /// 0.12 for "notice the thing beside you", up past 0.75 for a mission that
    /// genuinely asks the reader to get up and go somewhere.
    var missionPressureCost: Double {
        var cost = 0.30
        if goesOutside { cost += 0.30 }
        if lowered.contains("movement") { cost += 0.10 }
        if lowered.contains("public") { cost += 0.08 }
        if lowered.contains("low-energy") { cost -= 0.10 }
        if lowered.contains("low-stakes") { cost -= 0.08 }
        if !lowered.isDisjoint(with: ["inside", "anywhere"]) { cost -= 0.05 }
        return min(0.85, max(0.12, cost))
    }

    /// The reader-facing temperament. Cozy is a temperament, not a page type.
    var temperament: String {
        if lowered.contains("ridiculous") { return "A Ridiculous Mission" }
        if lowered.contains("shadow-wonder") { return "A Shadow Mission" }
        if !lowered.isDisjoint(with: ["people", "connection", "shared-wonder"]) { return "A Shared Mission" }
        if goesOutside { return "An Outward Mission" }
        if missionPressureCost <= 0.25 { return "A Cozy Mission" }
        return "A Playful Mission"
    }
}

private extension Array where Element == String {
    func isDisjoint(with other: Set<String>) -> Bool {
        !contains { other.contains($0) }
    }
}

struct PromptWhisper: Identifiable, Equatable, Codable {
    enum Kind: String, Codable {
        case checkIn
        case mission
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String
    var keepPrompt: String
    var tags: [String]
    /// `nil` means this is a one-line prompt rather than a photographic
    /// mission. Kept optional so older queued whispers decode unchanged.
    var allowsPhoto: Bool? = nil
}

struct WickerDare: Equatable {
    var id: String
    var title: String
    var challenge: String
    var proofPrompt: String
    var tags: [String]
    var place: LocalPlaceSignal? = nil
}

extension WickerDare {
    private var loweredTags: Set<String> { Set(tags.map { $0.lowercased() }) }

    var goesOutward: Bool {
        place != nil || !loweredTags.isDisjoint(with: ["outward", "outing", "walking", "route"])
    }

    var estimatedMinutes: Int {
        if goesOutward { return 20 }
        if loweredTags.contains("movement") || loweredTags.contains("making") { return 10 }
        return 5
    }

    var pressureCost: Double {
        var cost = 0.34
        if goesOutward { cost += 0.22 }
        if !loweredTags.isDisjoint(with: ["social", "conversation", "public"]) { cost += 0.13 }
        if loweredTags.contains("comfort-edge") { cost += 0.10 }
        if loweredTags.contains("voice") { cost += 0.04 }
        if loweredTags.contains("consent") { cost -= 0.03 }
        if !loweredTags.isDisjoint(with: ["anywhere", "immediate", "accessible"]) { cost -= 0.07 }
        return min(0.85, max(0.18, cost))
    }
}

/// Wicker pushes farther than the Wonder Compass, but never past consent,
/// legality, property rules, or the reader's ability to say no without penalty.
enum WickerDareRegistry {
    static let immediate: [WickerDare] = [
        WickerDare(
            id: "tongue-out",
            title: "A Tiny Act of Defiance",
            challenge: "Stick your tongue out at something right now. Not a person: choose an object, rule, weather system, or entire Tuesday that has grown too important.",
            proofPrompt: "What received the tongue, and did it deserve it?",
            tags: ["wicker-dare", "immediate", "mischief", "anywhere"]
        ),
        WickerDare(
            id: "wrong-way-round",
            title: "One Thing Backwards",
            challenge: "Wear, carry, arrange, or begin one harmless thing backwards for ten minutes. Let the world notice only if it is paying proper attention.",
            proofPrompt: "What went backwards, and what became newly visible?",
            tags: ["wicker-dare", "immediate", "mischief", "comfort-edge"]
        ),
        WickerDare(
            id: "object-compliment",
            title: "Publicly Admire the Inanimate",
            challenge: "Give one ordinary object a sincere compliment out loud. Quietly counts. Wicker would prefer witnesses, but Wicker is not in charge of your consent.",
            proofPrompt: "What did you compliment, exactly?",
            tags: ["wicker-dare", "immediate", "voice", "comfort-edge"]
        ),
        WickerDare(
            id: "unnecessary-flourish",
            title: "Add a Flourish",
            challenge: "Complete the next ordinary action with one completely unnecessary flourish: a bow after closing a door, a grand reveal of your keys, a magician's hand over a finished cup of tea.",
            proofPrompt: "Which action was promoted into a performance?",
            tags: ["wicker-dare", "immediate", "performance", "anywhere"]
        ),
        WickerDare(
            id: "stranger-color",
            title: "Wear the Unreasonable Color",
            challenge: "Put on or carry the color you usually decide is 'too much.' Give it one honest outing, even if the outing is only across the room.",
            proofPrompt: "Which color escaped, and where did you take it?",
            tags: ["wicker-dare", "immediate", "style", "comfort-edge"]
        ),
        WickerDare(
            id: "tiny-manifesto",
            title: "Declare Something Ridiculous",
            challenge: "Write a one-sentence manifesto for a harmless thing you care about too much. Read it aloud to the room as if history has finally caught up.",
            proofPrompt: "Keep the manifesto.",
            tags: ["wicker-dare", "immediate", "creative", "voice"]
        ),
        WickerDare(
            id: "ten-second-dance",
            title: "Dance Before Permission Arrives",
            challenge: "Dance for ten seconds with no music and no claim that you know how. Seated dancing, finger dancing, and one violently committed shoulder all count.",
            proofPrompt: "Which part of you joined first?",
            tags: ["wicker-dare", "immediate", "movement", "comfort-edge", "accessible"]
        ),
        WickerDare(
            id: "read-to-the-air",
            title: "Give the Air a Reading",
            challenge: "Read four lines of something you love aloud to an open window, a hallway, a tree, or an otherwise unqualified audience. Use your real voice.",
            proofPrompt: "Which lines escaped, and what heard them?",
            tags: ["wicker-dare", "voice", "creative", "comfort-edge"]
        ),
        WickerDare(
            id: "tiny-gift",
            title: "Make a Gift Too Small to Owe",
            challenge: "Make a tiny gift in under five minutes (a doodle, folded scrap, ridiculous title, found-color photograph, or six good words) and offer it to someone who can comfortably say no.",
            proofPrompt: "What did you make, and how was it offered?",
            tags: ["wicker-dare", "creative", "social", "consent", "comfort-edge"]
        ),
        WickerDare(
            id: "odd-question",
            title: "Ask the Better Question",
            challenge: "Ask someone you know one oddly specific question instead of 'How are you?' Try: What object has been your ally today? What sound should be illegal? What tiny thing went right?",
            proofPrompt: "Which question did you risk, and what came back?",
            tags: ["wicker-dare", "social", "conversation", "comfort-edge"]
        ),
        WickerDare(
            id: "formal-portrait",
            title: "Grant It a State Portrait",
            challenge: "Take an absurdly dignified portrait of the least dignified object available. Give it a full ceremonial title. No tidying the subject first.",
            proofPrompt: "Keep the portrait and its title.",
            tags: ["wicker-dare", "creative", "photo", "anywhere"]
        ),
        WickerDare(
            id: "visible-mending",
            title: "Refuse to Hide the Repair",
            challenge: "Repair, tape, tie, patch, or prop up one small broken thing and make the repair deliberately visible. Let the scar be better dressed than the wound.",
            proofPrompt: "What did you mend, and how did the repair announce itself?",
            tags: ["wicker-dare", "making", "mischief", "comfort-edge"]
        ),
        WickerDare(
            id: "strange-accessory",
            title: "Wear the Thing You Keep Almost Wearing",
            challenge: "Wear one harmless thing you normally remove before anyone sees it: the loud pin, strange hat, theatrical scarf, too-many-rings arrangement, or improvised paper crown. Give it at least ten honest minutes.",
            proofPrompt: "What finally got worn?",
            tags: ["wicker-dare", "style", "comfort-edge", "self-expression"]
        ),
        WickerDare(
            id: "first-sentence-sky",
            title: "Tell the Sky First",
            challenge: "Step to a window or safe threshold and tell the sky one true sentence before you tell anyone else. It may be tender, furious, vain, delighted, or about lunch.",
            proofPrompt: "What did the sky hear first?",
            tags: ["wicker-dare", "voice", "truth", "comfort-edge", "accessible"]
        ),
        WickerDare(
            id: "micro-adventure-invite",
            title: "Issue a Suspicious Invitation",
            challenge: "Invite someone to a twenty-minute micro-adventure: inspect one unfamiliar aisle, find the best doorway in town, split a pastry, hunt a color, or walk nowhere important. Make declining easy.",
            proofPrompt: "What adventure did you propose?",
            tags: ["wicker-dare", "social", "outward", "consent", "comfort-edge"]
        ),
        WickerDare(
            id: "route-mutiny",
            title: "Mutiny Against the Usual Route",
            challenge: "Change one safe piece of a familiar route today: the other side of the street, a different doorway, one extra corner, or simply face the opposite direction before beginning. Wheels and windows count.",
            proofPrompt: "Where did the route stop being obedient?",
            tags: ["wicker-dare", "outward", "movement", "accessible", "comfort-edge"]
        ),
        WickerDare(
            id: "kind-note",
            title: "Leave an Anonymous Bright Spot",
            challenge: "Write one specific, non-creepy kindness on a scrap: 'Your window garden is excellent,' 'This place smells like good mornings,' 'Whoever fixed this: splendid work.' Give it directly, or leave it only where notes are welcome.",
            proofPrompt: "What did the note notice?",
            tags: ["wicker-dare", "creative", "public", "consent", "comfort-edge"]
        ),
        WickerDare(
            id: "one-minute-character",
            title: "Borrow a More Dangerous Name",
            challenge: "For one minute, give yourself a title fit for the person doing this exact day: Keeper of the Last Clean Spoon, Duchess of Unanswered Email, Minor Saint of Trying Again. Introduce yourself to the room.",
            proofPrompt: "What title did you dare to claim?",
            tags: ["wicker-dare", "voice", "imagination", "anywhere"]
        ),
        WickerDare(
            id: "beautifully-overdressed-task",
            title: "Overdress the Errand",
            challenge: "Make one ordinary task slightly too ceremonial. Use the good cup for water. Put on perfume to take out the rubbish. Carry the grocery list like sealed orders. Choose your own ridiculous elevation.",
            proofPrompt: "Which errand received honors it had not earned?",
            tags: ["wicker-dare", "ritual", "style", "comfort-edge"]
        ),
        WickerDare(
            id: "honest-opinion",
            title: "Retire One Polite Lie",
            challenge: "Replace one harmless automatic opinion with the oddly specific truth. Not 'fine' ('the soup tastes like a rainy windowsill.' Not 'I like it') name the exact part you like. Do not use honesty as a knife.",
            proofPrompt: "Which vague answer did you replace, and with what?",
            tags: ["wicker-dare", "truth", "voice", "comfort-edge"]
        ),
        WickerDare(
            id: "villainous-chore",
            title: "Name the Villain",
            challenge: "Give one boring chore the title of a melodramatic villain, then defeat exactly one minute of it. Stop after the minute if you wish. Wicker respects a bounded uprising.",
            proofPrompt: "What was the villain called, and what tiny defeat did it suffer?",
            tags: ["wicker-dare", "immediate", "mischief", "anywhere", "accessible"]
        ),
        WickerDare(
            id: "pocket-museum",
            title: "Open a Pocket Museum",
            challenge: "Choose three things already in a pocket, bag, drawer, or tray. Arrange a sixty-second exhibition and give it a scandalously serious title.",
            proofPrompt: "What were the three exhibits and the museum title?",
            tags: ["wicker-dare", "creative", "object", "anywhere", "accessible"]
        ),
        WickerDare(
            id: "bench-throne",
            title: "Claim a Temporary Throne",
            challenge: "Choose an available chair, bench, step, or safe patch of floor and sit as if the local government has made a clerical error in your favor. Hold office for one minute.",
            proofPrompt: "Where was the throne, and what was your first decree?",
            tags: ["wicker-dare", "public", "imagination", "comfort-edge", "accessible"]
        ),
        WickerDare(
            id: "municipal-drama",
            title: "Document Civic Drama",
            challenge: "Find two ordinary public objects having a disagreement: bollard versus bicycle, bin versus wind, curb versus root. Photograph only the objects, or write the dispute down.",
            proofPrompt: "Who was arguing, and who had the better case?",
            tags: ["wicker-dare", "public", "photo", "object", "mischief"]
        ),
        WickerDare(
            id: "weather-broadcast",
            title: "Broadcast Illegal Weather",
            challenge: "Deliver a ten-second weather report for the emotional climate of one room. Whispering, signing, typing, or reporting only to the furniture all count.",
            proofPrompt: "What forecast did the room receive?",
            tags: ["wicker-dare", "voice", "imagination", "anywhere", "accessible"]
        ),
        WickerDare(
            id: "shadow-state-portrait",
            title: "Honor the Wrong Subject",
            challenge: "Take a formal portrait of a shadow, reflection, stain, crease, or patch of worn floor. Give the overlooked thing the full dignity of a visiting monarch.",
            proofPrompt: "Keep the portrait and the subject's ceremonial name.",
            tags: ["wicker-dare", "photo", "creative", "shadow", "anywhere"]
        ),
        WickerDare(
            id: "temporary-crown",
            title: "Manufacture Authority",
            challenge: "Make a temporary crown, badge, medal, or sash from something already destined for recycling or reuse. Wear it long enough to issue one harmless ruling, then dismantle it responsibly.",
            proofPrompt: "What office did you hold, and what did you rule?",
            tags: ["wicker-dare", "making", "style", "mischief", "accessible"]
        ),
        WickerDare(
            id: "machine-salute",
            title: "Salute the Competent Machine",
            challenge: "Catch one machine completing its ordinary duty and give it the recognition its management has withheld. A grave nod is sufficient. A tiny speech is better.",
            proofPrompt: "Which machine served, and what honor did it receive?",
            tags: ["wicker-dare", "immediate", "object", "mischief", "anywhere"]
        ),
        WickerDare(
            id: "sidewalk-review",
            title: "Review the Ground",
            challenge: "Write or speak a six-word review of the next floor, pavement, path, or carpet that carries you. Be exact and unfair only to architecture.",
            proofPrompt: "Keep the six-word review.",
            tags: ["wicker-dare", "words", "movement", "anywhere", "accessible"]
        ),
        WickerDare(
            id: "room-renaming",
            title: "Rename the Room",
            challenge: "Give the room you are in a name based on what it is actually doing today, not what the floor plan claims. Use the new name once with a straight face.",
            proofPrompt: "What is the room's true name today?",
            tags: ["wicker-dare", "words", "imagination", "inside", "anywhere"]
        ),
        WickerDare(
            id: "tiny-boundary",
            title: "Retire One Automatic Yes",
            challenge: "At the next harmless, low-stakes moment, replace an automatic yes with the exact answer you mean: not now, the other one, five minutes, or yes gladly. Do not stage a conflict just to complete this.",
            proofPrompt: "Which exact answer replaced the automatic one?",
            tags: ["wicker-dare", "truth", "voice", "consent", "comfort-edge"]
        ),
        WickerDare(
            id: "friend-dares-back",
            title: "Let Someone Dare You",
            challenge: "Ask someone you trust to choose one tiny harmless variation in your next ten minutes: the cup, route, song, snack, color, or title. Make your veto effortless and final.",
            proofPrompt: "What did they choose, and did you accept or veto it?",
            tags: ["wicker-dare", "social", "consent", "choice", "comfort-edge"]
        ),
        WickerDare(
            id: "chapter-the-commute",
            title: "Title the Crossing",
            challenge: "Give the next journey between two places a chapter title before it begins. At the end, decide whether the title lied.",
            proofPrompt: "What was the chapter called, and did it tell the truth?",
            tags: ["wicker-dare", "outward", "route", "words", "accessible"]
        ),
        WickerDare(
            id: "admire-the-repair",
            title: "Praise the Scar",
            challenge: "Find a visible repair and praise one exact decision its maker made. If the maker is present and the moment is welcome, tell them. Otherwise tell the repair itself.",
            proofPrompt: "Which repair earned praise, and for what?",
            tags: ["wicker-dare", "making", "kindness", "consent", "public"]
        ),
        WickerDare(
            id: "one-song-entrance",
            title: "Enter on Your Own Music",
            challenge: "Choose a song for one completely ordinary entrance today. Headphones count. Silence also counts if you hum the first two notes yourself.",
            proofPrompt: "Which entrance got a soundtrack, and what song claimed it?",
            tags: ["wicker-dare", "style", "performance", "comfort-edge", "accessible"]
        ),
        WickerDare(
            id: "harmless-disagreement",
            title: "Disagree With the Furniture",
            challenge: "Find one design decision nearby that you reject: a handle, font, chair angle, button, color, or shelf height. State your case without pretending the object can defend itself.",
            proofPrompt: "What decision did you dispute, and what is your better proposal?",
            tags: ["wicker-dare", "truth", "design", "object", "anywhere"]
        ),
        WickerDare(
            id: "absurdly-specific-toast",
            title: "Toast the Unimportant Victory",
            challenge: "Raise a cup, fork, pencil, or empty hand to one absurdly specific thing that went right. If someone is with you, invite them without requiring agreement.",
            proofPrompt: "What tiny victory received the toast?",
            tags: ["wicker-dare", "social", "joy", "consent", "anywhere"]
        ),
        WickerDare(
            id: "other-hand-signature",
            title: "Let the Other Hand Sign",
            challenge: "Give your non-usual hand one tiny ceremonial job: sign a scrap, draw a seal, choose an arrow, or underline the day's least obedient word.",
            proofPrompt: "What did the other hand make or choose?",
            tags: ["wicker-dare", "making", "movement", "accessible", "anywhere"]
        ),
        WickerDare(
            id: "local-honor",
            title: "Award a Town Honor",
            challenge: "On your next safe outing, choose one overlooked local thing worthy of an unofficial honor: best hinge, bravest weed, most patient wall, finest accidental color.",
            proofPrompt: "What won, where was it, and what honor did you invent?",
            tags: ["wicker-dare", "outward", "place", "visual", "mischief"]
        ),
        WickerDare(
            id: "ceremonial-snack",
            title: "Ennoble the Snack",
            challenge: "Present one ordinary snack or drink to yourself with entirely excessive ceremony. Name each ingredient as if announcing honored guests. Eating it is optional.",
            proofPrompt: "What was served, and what title did the ceremony give it?",
            tags: ["wicker-dare", "ritual", "food", "performance", "anywhere"]
        )
    ]

    static func dare(for day: BookDay, inputs: BookSourceInputs, now: Date) -> WickerDare {
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        let eligiblePlaces = inputs.nearbyPlaces.filter(isSuitablePublicPlace)
        let shouldUsePlace = !eligiblePlaces.isEmpty
            && abs("\(day.id)-\(slot)-wicker-place".stableHash % 3) == 0

        if shouldUsePlace {
            let place = eligiblePlaces[
                abs("\(day.id)-\(slot)-wicker-destination".stableHash) % eligiblePlaces.count
            ]
            return placeDare(place)
        }
        let onboardingMode = inputs.selfFacts.first {
            $0.questionID == "onboarding-wicker-mode" && $0.usePermission != .doNotUse
        }?.answer
        let onboardingTier = inputs.selfFacts.first {
            $0.questionID == "onboarding-wicker-tier" && $0.usePermission != .doNotUse
        }?.answer
        let completed = inputs.days
            .flatMap(\.pages)
            .compactMap(\.livedQuestReceipt)
            .filter { $0.kind == .wickerDare }
            .sorted { $0.completedAt > $1.completedAt }
        let recentIDs = Set(completed.prefix(8).map(\.questID))
        let preferredIDs: Set<String>
        switch onboardingMode {
        case "slice-of-life":
            preferredIDs = ["object-compliment", "formal-portrait", "honest-opinion", "first-sentence-sky"]
        case "arc":
            preferredIDs = ["unnecessary-flourish", "visible-mending", "micro-adventure-invite", "route-mutiny", "beautifully-overdressed-task"]
        case "surprise":
            preferredIDs = ["wrong-way-round", "tiny-manifesto", "strange-accessory", "one-minute-character", "tongue-out"]
        default:
            preferredIDs = []
        }
        let shapedPool = immediate.filter { preferredIDs.contains($0.id) }
        let tierTags: Set<String>
        switch onboardingTier {
        case "triumph": tierTags = ["outward", "public", "social", "performance"]
        case "cost": tierTags = ["truth", "making", "mischief", "voice"]
        case "glance": tierTags = ["imagination", "style", "words", "object"]
        default: tierTags = ["creative", "mischief", "accessible"]
        }
        let wideningPool = immediate.filter { dare in
            !Set(dare.tags).isDisjoint(with: tierTags)
        }
        let unlockedPool: [WickerDare]
        switch completed.count {
        case 0:
            unlockedPool = shapedPool.isEmpty ? immediate : shapedPool
        case 1...2:
            unlockedPool = Array((shapedPool + wideningPool).reduce(into: [String: WickerDare]()) {
                $0[$1.id] = $1
            }.values).sorted { $0.id < $1.id }
        default:
            unlockedPool = immediate
        }
        let freshPool = unlockedPool.filter { !recentIDs.contains($0.id) }
        let pool = freshPool.isEmpty ? unlockedPool : freshPool
        return pool[
            abs("\(day.id)-\(slot)-wicker-immediate-\(onboardingMode ?? "unwritten")-\(completed.count)".stableHash) % pool.count
        ]
    }

    private static func isSuitablePublicPlace(_ place: LocalPlaceSignal) -> Bool {
        // Category is the safety signal. Names can contain misleading words
        // ("Left Bank Books", "Old School Cafe") that must not veto a benign
        // public destination.
        let text = place.category.lowercased()
        let excluded = [
            "hospital", "clinic", "doctor", "funeral", "cemetery", "school",
            "police", "court", "bank", "pharmacy", "religious", "church"
        ]
        return !excluded.contains(where: text.contains)
    }

    private static func placeDare(_ place: LocalPlaceSignal) -> WickerDare {
        let text = "\(place.name) \(place.category)".lowercased()
        if ["park", "garden", "trail", "preserve", "nature", "arboretum"]
            .contains(where: text.contains) {
            return WickerDare(
                id: "local-wild-office-\(place.id)",
                title: "Inspect the Wild Office",
                challenge: "Go to \(place.name) while it is open and find the living thing behaving least decoratively: a weed escaping, a bird negotiating, a root lifting policy off the path. Stay on permitted ground and interfere with nothing.",
                proofPrompt: "Who was conducting unauthorized business, and what were they doing?",
                tags: ["wicker-dare", "nature", "public", "outward", "visual", "real-place"],
                place: place
            )
        }
        if ["water", "harbor", "river", "beach", "marina", "shore", "pier"]
            .contains(where: text.contains) {
            return WickerDare(
                id: "local-water-verdict-\(place.id)",
                title: "Ask the Water to Object",
                challenge: "Visit \(place.name) from a safe public edge and find the exact place the water disagrees with the land. Do not approach unsafe edges or enter the water for this dare.",
                proofPrompt: "Where did water and land disagree, and which one appeared to be winning?",
                tags: ["wicker-dare", "water", "public", "outward", "visual", "real-place"],
                place: place
            )
        }
        if ["market", "shop", "store", "bakery", "grocery"]
            .contains(where: text.contains) {
            return WickerDare(
                id: "local-shelf-curiosity-\(place.id)",
                title: "Inspect the Unreasonable Shelf",
                challenge: "At \(place.name), while it is open, find one object, label, ingredient, or color you would never have thought to search for. Browsing is enough; buying nothing is a complete answer.",
                proofPrompt: "What unlikely thing was waiting there?",
                tags: ["wicker-dare", "public", "outward", "visual", "real-place", "low-stakes"],
                place: place
            )
        }
        if ["library", "book", "co-op", "coop", "community", "arts", "gallery", "cafe", "coffee"]
            .contains(where: text.contains) {
            return WickerDare(
                id: "creative-drop-\(place.id)",
                title: "Leave Evidence You Were Alive",
                challenge: "Make one tiny piece of your own work (a poem, drawing, six-word story, or peculiar little blessing) and take it to \(place.name). Ask before leaving it, or use a board, free table, or other place clearly meant for public offerings. Sign it or don't.",
                proofPrompt: "What did you make, and where was it welcomed?",
                tags: ["wicker-dare", "creative", "public", "outward", "comfort-edge", "real-place"],
                place: place
            )
        }
        return WickerDare(
            id: "local-curiosity-\(place.id)",
            title: "Ask the Question You Nearly Swallowed",
            challenge: "Go to \(place.name) when it is open and ask one sincere, slightly unusual question about the place: what is overlooked, what has been there longest, or what the staff secretly think is wonderful. If they are busy, abort with style and notice one thing for yourself.",
            proofPrompt: "What did you ask, or what did you notice when the moment said no?",
            tags: ["wicker-dare", "public", "conversation", "outward", "comfort-edge", "real-place"],
            place: place
        )
    }
}

enum PlayfulMissionRegistry {
    private struct RankedMission {
        var mission: PlayfulMission
        var score: Int
    }
    private static let fullMoonMission = mission(
        "moon-full-face",
        "Full Moon Errand",
        "Step somewhere the full moon can see you tonight. Stand still until you can tell what color its light actually is: it is never quite white.",
        "Write the moon's true color, or what stood between you and it.",
        ["natural-phenomenon", "moon", "full-moon", "light", "night", "outside"]
    )

    private static let waningGibbousMoonMission = mission(
        "moon-waning-gibbous-shadow",
        "Moon Shadow Errand",
        "Tonight, if the moon is visible, find one shadow it casts. If it hides, find the place where moonlight would have landed.",
        "Write the moon-shadow, or the place it would have touched.",
        ["natural-phenomenon", "moon", "waning-gibbous", "shadow", "night", "outside"]
    )

    private static let stormWindMission = mission(
        "storm-wind-shift",
        "Wind Change Watch",
        "Step to a safe outside threshold, close your eyes, and listen for the exact moment the wind changes direction or argues with itself.",
        "Write the wind's change: direction, sound, or first clue.",
        ["natural-phenomenon", "weather", "storm", "wind", "sound", "outside"],
        allowsPhoto: false
    )

    /// The moon mission for a given night, if that night has one. Pure: safe
    /// to call for future dates when scheduling whispers ahead.
    static func moonMission(on date: Date) -> PlayfulMission? {
        switch MoonPhaseCalendar.phase(on: date).name {
        case "Full Moon": return fullMoonMission
        case "Waning Gibbous": return waningGibbousMoonMission
        default: return nil
        }
    }

    static func placeMission(matching text: String) -> PlayfulMission? {
        placeMissions(matching: text).first
    }

    /// A place signal should shape the mission, not pin the feed to one card.
    /// The caller rotates this small, place-specific set through the cadence.
    private static func placeMissions(matching text: String) -> [PlayfulMission] {
        let text = text.lowercased()
        if containsAny(text, ["harbor", "river", "lake", "pond", "creek", "stream", "water", "waterfront", "shore", "beach", "bay", "marina", "bridge"]) {
            return [
                mission("water-flow-low-point", "Water Chooses Down", "Find the highest or lowest physical point nearby, then look for which way water would travel from there.", "Write the point you chose and the direction water would go.", ["natural-phenomenon", "water", "place", "outside", "movement"]),
                mission("water-true-color", "Water's True Color", "Find water, or the nearest piece of the world acting like it: a window, puddle, kettle, polished stone. Name the color it is holding right now.", "Write: The water was really...", ["natural-phenomenon", "water", "place", "outside", "visual"]),
                mission("water-edge-sound", "Water at the Edge", "Find the nearest watery sound or edge. Listen for the smallest sound it makes after the obvious one.", "Write the quiet sound hiding inside the water-sound.", ["natural-phenomenon", "water", "place", "outside", "sound"]),
                mission("water-carried-clue", "What Water Carried", "Look for one thing water has moved, marked, or left behind: a leaf, a tide line, grit in a crack, a darkened curb. Treat it as evidence.", "Write what water carried or changed.", ["natural-phenomenon", "water", "place", "outside", "noticing"])
            ]
        }
        if containsAny(text, ["hill", "ridge", "mountain", "trail", "overlook", "stairs", "elevator", "slope", "summit", "valley"]) {
            return [
                mission("altitude-nearby-point", "High Low Reading", "Find the highest or lowest physical point nearby. Stand there for ten seconds and decide what the place is sending downhill.", "Write the point and what seems to move away from it.", ["natural-phenomenon", "altitude", "place", "outside", "movement"], allowsPhoto: false),
                mission("altitude-horizon-line", "Horizon Line", "Find the longest line you can see from here: roofline, hill, stair rail, treetop, curb. Follow it until it disappears.", "Write where the line let go of your sight.", ["natural-phenomenon", "altitude", "place", "outside", "visual"]),
                mission("altitude-gravity-clue", "Gravity's Clue", "Find one ordinary thing that reveals the slope of this place: a rolling leaf, a drain, a leaning sign, a worn step. Let gravity point.", "Write the clue gravity gave you.", ["natural-phenomenon", "altitude", "place", "outside", "movement"]),
                mission("altitude-air-change", "Different Air", "Move just enough to change your height: one flight, one curb, one hill, one overlook. Notice the first thing the air does differently.", "Write the air's first difference.", ["natural-phenomenon", "altitude", "place", "outside", "scent", "sound"])
            ]
        }
        return []
    }

    static func weatherBellMission(weatherText: String) -> PlayfulMission? {
        let text = weatherText.lowercased()
        if containsAny(text, ["pressure drop", "dropping pressure", "falling pressure", "storm", "thunder", "squall", "front", "gust"]) {
            return stormWindMission
        }
        if containsAny(text, ["rain", "drizzle", "shower", "downpour"]) {
            return attentionMissions.first { $0.id == "sky-rain-stage" }
        }
        if containsAny(text, ["snow", "fog", "mist"]) {
            return coreMissions.first { $0.id == "weather-scent" }
        }
        return nil
    }

    static func mission(for day: BookDay, inputs: BookSourceInputs, now: Date = Date(), shadowVariant: Bool = false) -> PlayfulMission {
        let slot = SurfaceCadence.slotID(for: now, hours: 2)
        let seed = abs("\(day.id)-\(slot)-playful-mission".stableHash)
        if !shadowVariant {
            let locationMissions = placeMissions(matching: placeEvidenceText(inputs: inputs))
            if !locationMissions.isEmpty {
                let unshownLocationMissions = locationMissions.filter {
                    inputs.surfaceHistory[missionHistoryKey(for: $0)] == nil
                }
                if !unshownLocationMissions.isEmpty {
                    return unshownLocationMissions[rotatingIndex(for: now, count: unshownLocationMissions.count)]
                }

                // The location has had its opening turn. From here, choose from
                // the ordinary whole pool, rather than making a place signal a
                // permanent filter on the home feed.
                let missions = rankedMissions(for: day, inputs: inputs, now: now, shadowVariant: false)
                return freshestMission(in: missions, seed: seed, history: inputs.surfaceHistory, now: now)
            }

            let phenomena = naturalPhenomenonMissions(inputs: inputs, now: now)
            if !phenomena.isEmpty {
                return phenomena[rotatingIndex(for: now, count: phenomena.count)]
            }
        }
        let missions = rankedMissions(for: day, inputs: inputs, now: now, shadowVariant: shadowVariant)
        if shadowVariant, ShadowWonder.state(inputs: inputs, now: now).isActive {
            let shadowMissions = missions.filter { $0.mission.tags.map { $0.lowercased() }.contains("shadow-wonder") }
            if !shadowMissions.isEmpty {
                return weightedMission(in: shadowMissions, seed: seed)
            }
            let preferred = missions.filter { ShadowWonder.prefers(mission: $0.mission) }
            if !preferred.isEmpty {
                return weightedMission(in: preferred, seed: seed)
            }
        }
        return freshestMission(in: missions, seed: seed, history: inputs.surfaceHistory, now: now)
    }

    private static func naturalPhenomenonMissions(inputs: BookSourceInputs, now: Date) -> [PlayfulMission] {
        var result: [PlayfulMission] = []
        if let moonMission = moonMission(on: now) {
            result.append(moonMission)
        }

        let weatherText = [inputs.weather?.phrase, inputs.weather?.forecast, inputs.enchantedWeather?.summary]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if containsAny(weatherText, ["pressure drop", "dropping pressure", "falling pressure", "storm", "thunder", "squall", "front", "gust"]) {
            result.append(stormWindMission)
        }

        return result
    }

    private static func missionHistoryKey(for mission: PlayfulMission) -> String {
        "playful-mission:\(mission.id)"
    }

    /// Preserve broad variety once a location's first set has been introduced.
    /// If every mission was seen recently, fall back to the full ranked pool.
    private static func freshestMission(
        in missions: [RankedMission],
        seed: Int,
        history: [String: SurfaceHistoryRecord],
        now: Date
    ) -> PlayfulMission {
        let fresh = missions.filter { ranked in
            guard let shownAt = history[missionHistoryKey(for: ranked.mission)]?.lastShownAt else { return true }
            return now.timeIntervalSince(shownAt) >= 48 * 60 * 60
        }
        let pool = fresh.isEmpty ? missions : fresh
        return weightedMission(in: pool, seed: seed)
    }

    /// Context is a probability, not merely a sorting ornament. A mission that
    /// fits the live day receives materially more tickets while even the odd
    /// sideways choice keeps one, preserving surprise without erasing relevance.
    private static func weightedMission(in ranked: [RankedMission], seed: Int) -> PlayfulMission {
        guard let first = ranked.first else { return coreMissions[0] }
        let minimum = ranked.map(\.score).min() ?? 0
        let weights = ranked.map { max(1, 1 + ($0.score - minimum) * 4) }
        let total = weights.reduce(0, +)
        var pick = seed % max(total, 1)
        for (index, weight) in weights.enumerated() {
            if pick < weight { return ranked[index].mission }
            pick -= weight
        }
        return first.mission
    }

    /// Unlike a hash-per-slot pick, this advances one position every two hours.
    /// That means a persistent live signal (such as a nearby harbor) cannot
    /// select the same mission in adjacent feed refreshes.
    private static func rotatingIndex(for date: Date, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let cadence: TimeInterval = 2 * 60 * 60
        let slot = Int(floor(date.timeIntervalSinceReferenceDate / cadence))
        return slot % count
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    private static func placeEvidenceText(inputs: BookSourceInputs) -> String {
        let nearby = inputs.nearbyPlaces
            .map { "\($0.name) \($0.category) \($0.locality)" }
            .joined(separator: " ")
        let anchor = inputs.nearbyAnchor.map { proximity in
            let anchor = proximity.anchor
            return "\(anchor.name) \(anchor.kind.rawValue) \(anchor.weather) \(anchor.playerWords) \(anchor.localRule)"
        } ?? ""
        return "\(nearby) \(anchor)".lowercased()
    }

    private static func rankedMissions(for day: BookDay, inputs: BookSourceInputs, now: Date, shadowVariant: Bool) -> [RankedMission] {
        let missionPool = shadowVariant
            ? missions
            : missions.filter { !$0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
        let text = [
            inputs.weather?.phrase,
            inputs.body?.status,
            day.capturedPages.suffix(6).map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }.joined(separator: " ")
        ]
        .compactMap(\.self)
        .joined(separator: " ")
        .lowercased()

        var preferredTags: Set<String>
        if text.contains("rain") || text.contains("storm") || text.contains("fog") {
            preferredTags = ["weather", "sound", "scent", "inside"]
        } else if text.contains("low") || text.contains("tired") || text.contains("rest") {
            preferredTags = ["low-energy", "touch", "inside"]
        } else if text.contains("work") || text.contains("errand") || text.contains("store") {
            preferredTags = ["public", "visual", "errand"]
        } else {
            preferredTags = ["touch", "visual", "scent", "sound"]
        }
        if shadowVariant, ShadowWonder.state(inputs: inputs, now: now).isActive {
            preferredTags.formUnion(["shadow-wonder", "shadow", "night", "history", "threshold", "old"])
        }
        // A day whose pages already hold company leans the lens toward the
        // people in it: noticing missions, never performance requests.
        if containsAny(text, ["friend", "lunch with", "dinner with", "coffee with", "talked", "called", "visit", "party", "family", "together", "with my", "with her", "with him", "with them"]) {
            preferredTags.formUnion(["people", "connection"])
        }

        let recentReceipts = inputs.days
            .flatMap(\.pages)
            .compactMap(\.livedQuestReceipt)
            .filter { $0.kind == .playfulMission }
            .sorted { $0.completedAt > $1.completedAt }
        let lastReceipt = recentReceipts.first
        let lastTags = Set(lastReceipt?.sourceTags.map { $0.replacingOccurrences(of: "mission:", with: "") } ?? [])
        let lastHostSlug = lastReceipt?.sourceTags
            .first(where: { $0.hasPrefix("entity:") })
            .map { $0.replacingOccurrences(of: "entity:", with: "") }
        let recentModes = recentReceipts.prefix(3).compactMap { receipt in
            receipt.sourceTags
                .first(where: { $0.hasPrefix("play-mode:") })
                .map { String($0.dropFirst("play-mode:".count)) }
        }
        let repeatedRecentIDs = Set(recentReceipts.prefix(6).map(\.questID))
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)

        // Scoring a mission builds a tag set and scans its whole text, so each
        // mission is scored once here. Scoring inside the comparator instead
        // repeats that work on both sides of every comparison the sort makes:
        // roughly 2,500 rescans across this pool rather than 168.
        return missionPool
            .map { mission in
                let missionTags = Set(mission.tags.map { $0.lowercased() })
                var score = missionTags.intersection(preferredTags).count * 3
                    + (shadowVariant && ShadowWonder.prefers(mission: mission) ? 4 : 0)
                // The next errand visibly grows from the last returned proof,
                // but exact repeats and six-card ruts lose ground.
                score += missionTags.intersection(lastTags).count * 2
                if repeatedRecentIDs.contains(mission.id) { score -= 12 }
                if let lastHostSlug, mission.host.slug == lastHostSlug {
                    score += 2
                }
                let sameModeCount = recentModes.filter { $0 == mission.playMode.rawValue }.count
                score -= sameModeCount * 5
                if let lastMode = recentModes.first, lastMode != mission.playMode.rawValue {
                    score += 2
                }
                if shadowVariant && shadowState.isHardDay {
                    if !missionTags.isDisjoint(with: ["grief", "shadow-self", "true-names", "cost"]) { score -= 14 }
                    if !missionTags.isDisjoint(with: ["tribute", "light", "object", "inside", "low-energy"]) { score += 6 }
                }
                return RankedMission(mission: mission, score: score)
            }
            .sorted { left, right in
                if left.score == right.score {
                    return left.mission.id < right.mission.id
                }
                return left.score > right.score
            }
    }

    static let missions: [PlayfulMission] = coreMissions + ridiculousMissions + hostedSurpriseMissions + attentionMissions + sharedWonderMissions + peopleMissions + shadowMissions

    /// Missions with an authored comic turn, grouped by the curiosities of the
    /// person who sends them. They are not six skins over one noticing prompt:
    /// each host changes the kind of play, the real-world action, and the proof
    /// worth carrying home.
    static let hostedSurpriseMissions: [PlayfulMission] = [
        // Pippa Pilcrow: language misbehaves until an ordinary moment develops a plot.
        mission(
            "surprise-sound-effect",
            "Smuggle In A Sound Effect",
            "Give the next utterly ordinary action its own sound effect. A whispered fwoop for opening a cupboard counts. So does one eyebrow silently performing the noise in public.",
            "Write the action and the sound effect it had been missing.",
            ["hosted-surprise", "ridiculous", "sound", "anywhere", "low-stakes"],
            allowsPhoto: false
        ),
        mission(
            "surprise-minor-prophecy",
            "A Very Minor Prophecy",
            "Choose one harmless thing already in motion and predict its immediate future with unreasonable gravity: the kettle will click, the door will sigh, the sock will be found. Wait just long enough to learn whether you have the Gift.",
            "Keep the prophecy and what actually happened.",
            ["hosted-surprise", "ridiculous", "imagination", "anywhere", "low-stakes"],
            allowsPhoto: false
        ),
        mission(
            "surprise-wrong-field-guide",
            "The Incorrect Field Guide",
            "Pick one ordinary thing in sight. Invent one magnificently false field-guide fact about it, then look closely enough to discover one true fact stranger than your lie.",
            "Write the false fact and the inconveniently marvelous truth.",
            ["hosted-surprise", "ridiculous", "words", "anywhere", "low-stakes"]
        ),
        mission(
            "surprise-plot-twist",
            "Plot Twist Inspection",
            "The next harmless interruption is now a plot twist. When it arrives, however small, inspect the exact detail it changed instead of merely resenting its entrance.",
            "Write: The plot twisted when... and name what changed.",
            ["hosted-surprise", "ridiculous", "imagination", "anywhere", "low-stakes"],
            allowsPhoto: false
        ),

        // Penny Blackletter: evidence first, enchantment only after the facts hold.
        mission(
            "surprise-three-clue-theory",
            "Three Clues, One Theory",
            "Choose a neglected corner you may safely inspect. Find three visible clues about what happens there, then make the smallest theory those clues can honestly support.",
            "List the three clues and your careful little theory.",
            ["hosted-surprise", "evidence", "visual", "low-stakes", "inside", "public"]
        ),
        mission(
            "surprise-shaped-absence",
            "The Shape Of What Is Missing",
            "Find an absence with edges: a pale rectangle, an empty hook, a clean ring in dust, a gap in a row. Do not invent who removed it. Study what the remaining evidence can prove.",
            "Write the shape of the absence and one thing it proves.",
            ["hosted-surprise", "evidence", "history", "visual", "low-energy"]
        ),
        mission(
            "surprise-material-impostor",
            "The Material Impostor",
            "Find something pretending to be another material: plastic wood, paper stone, painted metal, false marble, digital paper. Catch the tiny tell that breaks the disguise.",
            "Name the impostor and the clue that gave it away.",
            ["hosted-surprise", "evidence", "visual", "design", "low-stakes"]
        ),
        mission(
            "surprise-accidental-collection",
            "The Accidental Collection",
            "Find three unrelated things that have accidentally become a collection because they share one exact trait. Penny permits color only if the shade is painfully specific.",
            "Name the three exhibits and the trait that admitted them.",
            ["hosted-surprise", "evidence", "object", "visual", "low-stakes"]
        ),

        // Zara Finch: routes become instruments for finding what a map omits.
        mission(
            "surprise-sound-border",
            "Walk Until The Sound Changes",
            "On a safe, permitted route, move only until the background sound clearly changes. Stop at that invisible border. Wheels count, and so does listening from two sides of an open doorway.",
            "Write where one sound-country ended and the next began.",
            ["hosted-surprise", "movement", "outside", "route", "sound", "accessible"],
            allowsPhoto: false
        ),
        mission(
            "surprise-unofficial-landmark",
            "Borrow An Unofficial Landmark",
            "Choose one landmark no map would bother naming: the brave weed, red drainpipe, crooked mailbox, window full of bottles. Let it guide the next small piece of a familiar route.",
            "Name the landmark and the direction it gave you.",
            ["hosted-surprise", "route", "place", "outside", "public", "low-stakes"]
        ),
        mission(
            "surprise-reverse-arrival",
            "Arrive On The Way Out",
            "When you safely leave a familiar place, turn back from the permitted path and look as if you have never arrived before. Find the detail that only belongs to the entrance view.",
            "Write the detail the place shows only to arrivals.",
            ["hosted-surprise", "route", "place", "outside", "public", "visual", "low-stakes"]
        ),
        mission(
            "surprise-color-relay",
            "The Color Relay",
            "Choose one exact color already near you. On the next safe stretch of your route, follow it from object to object until the color disappears or changes its mind.",
            "Record the color and the last three places it ran.",
            ["hosted-surprise", "movement", "outside", "route", "color", "public"]
        ),

        // Serenity Brown: shared wonder with no demand that another person perform.
        mission(
            "surprise-two-person-weather",
            "Two-Person Weather",
            "Ask someone you already know, if the moment is welcome, for one color that fits their day. No explanation required. Choose yours too and place the two colors side by side.",
            "Write the two colors. Keep their explanation only if they offered one.",
            ["hosted-surprise", "people", "connection", "shared-wonder", "low-stakes"],
            allowsPhoto: false
        ),
        mission(
            "surprise-borrowed-ordinary-favorite",
            "Borrow Their Ordinary Favorite",
            "Ask someone you know which ordinary thing has treated them well today: a pen, bus seat, spoon, shoe, doorway, anything. Later, find your own version and see whether it deserves the recommendation.",
            "Write both ordinary favorites and your verdict.",
            ["hosted-surprise", "people", "connection", "shared-wonder", "low-stakes"],
            allowsPhoto: false
        ),
        mission(
            "surprise-tiny-council",
            "Convene A Tiny Council",
            "At a welcome moment, ask someone you know to choose between two harmless options already available: this cup or that one, left or right, song A or song B. Your veto remains final. Their reason is optional and therefore interesting.",
            "Write the tiny question, their choice, and any reason freely given.",
            ["hosted-surprise", "people", "connection", "choice", "low-stakes"],
            allowsPhoto: false
        ),
        mission(
            "surprise-kindness-detectives",
            "Kindness Detectives",
            "With someone you already happen to be with, hunt for one sign that an absent person made this place easier: a refill, repair, label, swept step, charged thing. Do not perform gratitude at strangers. Just catch the evidence together.",
            "Write the evidence you both convicted of kindness.",
            ["hosted-surprise", "people", "connection", "kindness", "public", "low-stakes"],
            allowsPhoto: false
        ),

        // Professor Boggle: domestic life caught doing laboratory-grade magic.
        mission(
            "surprise-ingredient-three-jobs",
            "An Ingredient With Three Jobs",
            "Choose one ingredient, snack, or drink already available. Catch it doing three different jobs at once: flavor, color, temperature, structure, comfort, noise, memory. Professor Boggle insists one ingredient is always overemployed.",
            "Write the ingredient and its three jobs.",
            ["hosted-surprise", "food", "taste", "inside", "low-energy"],
            allowsPhoto: false
        ),
        mission(
            "surprise-cup-climate",
            "Weather Inside A Cup",
            "Before the next safe sip, inspect the tiny climate above the cup: heat, scent, condensation, stillness, a cold little front. Do not burn your nose proving anything.",
            "File the cup's weather report.",
            ["hosted-surprise", "taste", "scent", "inside", "low-energy"],
            allowsPhoto: false
        ),
        mission(
            "surprise-leftover-coronation",
            "Crown The Leftovers",
            "Take an ordinary leftover, snack, or drink you were already going to have and give it one absurd improvement using only what is on hand: a better bowl, a herb, a cut, a name, a ceremonial napkin. No shopping expedition.",
            "Write what was crowned and the one thing that changed its rank.",
            ["hosted-surprise", "food", "making", "inside", "low-stakes"]
        ),
        mission(
            "surprise-household-treaty",
            "A Household Treaty",
            "Find two harmless things in the same room that seem to be working against each other: lamp and glare, chair and doorway, blanket and draft. Negotiate one tiny rearrangement, or merely propose it if moving things is not welcome.",
            "Name the two parties and the treaty term.",
            ["hosted-surprise", "making", "inside", "ritual", "low-stakes"],
            allowsPhoto: false
        ),

        // Gwendolyn Mythwright: the field register for verified impossibilities.
        mission(
            "surprise-coincidence-court",
            "Court Of Coincidence",
            "Find two unrelated things sharing one implausibly exact feature: the same bent angle, tiny color, rhythm, number, or accidental expression. Convene court and decide whether coincidence has a case.",
            "Write the two witnesses and your verdict.",
            ["hosted-surprise", "wonder", "coincidence", "color", "low-energy"]
        ),
        mission(
            "surprise-minute-capsule",
            "A Time Capsule For This Minute",
            "Choose one detail that could prove this exact minute existed to someone opening it a hundred years from now. It must be ordinary, specific, and true. You need not keep the thing, only its evidence.",
            "Write the detail you would send through time.",
            ["hosted-surprise", "wonder", "time", "attention", "low-energy"],
            allowsPhoto: false
        ),
        mission(
            "surprise-light-jailbreak",
            "The Light Escaped",
            "Find light breaking a boundary it was meant to obey: under a door, through a sleeve, around a curtain, across a crack, inside a reflection. Determine the escape route.",
            "Write where the light got out and how.",
            ["hosted-surprise", "wonder", "light", "threshold", "low-energy"]
        ),
        mission(
            "surprise-small-impossible",
            "A Small Impossible Thing",
            "Find something that looks physically impossible for one second: a floating reflection, balanced load, backward shadow, invisible support. Then inspect it until the mechanism gives itself away.",
            "Keep both truths: what looked impossible, and how it was done.",
            ["hosted-surprise", "wonder", "mechanism", "attention", "low-stakes"]
        )
    ]

    /// The lens turned toward the people already in the reader's real days.
    /// These aim attention at company, not performance: nobody is asked to do
    /// anything for the reader, and all proof stays in the reader's own words.
    /// (House law: the Book may be impressed by the reader's seeing of real
    /// people; it never invents their words: see PeopleOfTheBook.)
    static let peopleMissions: [PlayfulMission] = [
        mission("people-hands", "The Hands Report", "The next time someone talks to you today, watch their hands instead of the air. Hands keep saying things after sentences end.", "Write what their hands were doing while they talked.", ["people", "connection", "visual", "public", "low-stakes"], allowsPhoto: false),
        mission("people-refrain", "Catch The Refrain", "Everyone carries a phrase they reach for. Catch the exact words someone near you repeats: word for word, no paraphrase.", "Write the phrase exactly as they said it.", ["people", "connection", "sound", "public", "low-stakes"], allowsPhoto: false),
        mission("people-laugh", "The True Laugh", "The next laugh you hear from someone you know: find one true comparison for the sound. Not 'nice.' The actual sound.", "Complete this: Their laugh sounded like...", ["people", "connection", "sound", "low-stakes"], allowsPhoto: false),
        mission("people-noticing", "What They Notice", "Watch what someone near you pays attention to. What does their attention love that yours skips past?", "Write the thing their attention went to first.", ["people", "connection", "visual", "public", "low-stakes"], allowsPhoto: false),
        mission("people-asked", "The Borrowed Eye", "Ask someone what they noticed today: anything at all. Then keep their answer like it was your own page.", "Write their answer in their words, and who lent it.", ["people", "connection", "kindness", "low-stakes"], allowsPhoto: false),
        mission("people-craft", "Watch The Craft", "Watch someone do something they are good at: pouring, parking, chopping, explaining. Find the exact moment the skill shows.", "Write the moment their skill became visible.", ["people", "connection", "visual", "public"], allowsPhoto: false),
        mission("people-voice", "Under The Words", "While someone talks to you, listen once to the voice instead of the words. What is the voice doing that the words are not?", "Write what the voice carried that the sentence didn't.", ["people", "connection", "sound", "low-stakes"], allowsPhoto: false),
        mission("people-uncut", "The Uncut Detail", "If this person were a character, what detail would the author refuse to cut? Find it while they are in front of you.", "Write the detail the author would keep.", ["people", "connection", "visual", "character", "low-stakes"], allowsPhoto: false)
    ]

    /// Tiny outward-facing acts of enchantment: optional, free, and designed to
    /// brighten someone else's ordinary day without asking them to perform back.
    static let sharedWonderMissions: [PlayfulMission] = [
        mission("shared-no-reply-glint", "No-Reply Glint", "Send someone a photo, song, or one-line observation that made you think of them. Add: ‘I saw this and threw it your way. No return postage.’", "Write what you passed along and who it belonged to.", ["shared-wonder", "connection", "kindness", "low-stakes"]),
        mission("shared-specific-thanks", "Specific Thanks", "Thank someone for one exact thing they did: a held door, clear directions, a good question, a steady hand. Only say it if you mean it; specificity is the magic.", "Write the exact thing you thanked them for.", ["shared-wonder", "kindness", "public", "low-stakes"], allowsPhoto: false),
        mission("shared-point-it-out", "Pass The Glint", "When you are with someone, point out one small wonderful thing they might have missed: a shadow, a dog with a job, a ridiculous cloud, a perfect tiny color.", "Write the glint you passed along.", ["shared-wonder", "connection", "visual", "public"]),
        mission("shared-better-exit", "Leave It Kinder", "On your way out of a shared space, do one tiny thing that makes the next person's arrival easier: return a basket, push in a chair, or put one safe thing back where it belongs.", "Write the small kindness you left behind.", ["shared-wonder", "kindness", "public", "errand"]),
        mission("shared-good-news", "Good News Courier", "Tell someone you already know one small piece of good news that is not about productivity, money, or disaster. A bird, a soup, a tiny victory, a strange cloud: it counts.", "Write the good news you carried.", ["shared-wonder", "connection", "joy", "low-stakes"], allowsPhoto: false),
        mission("shared-maker-credit", "Credit The Maker", "If something made your day easier or nicer, tell its maker or keeper specifically: the cook, artist, cashier, coworker, librarian, neighbor, or friend. Keep it brief and true.", "Write what you gave credit for.", ["shared-wonder", "kindness", "public", "low-stakes"], allowsPhoto: false),
        mission("shared-ordinary-toast", "An Ordinary Toast", "Raise a cup, snack, or imaginary glass with someone to one extremely ordinary thing that went right today: the bus came, the laundry dried, the key fit, the light turned green.", "Write what earned the tiny toast.", ["shared-wonder", "connection", "joy", "low-stakes"], allowsPhoto: false),
        mission("shared-open-the-way", "Make A Little Room", "At the next harmless chance, make a little room for someone: let them merge, hold a door, offer the closer seat, or step aside. No flourish required.", "Write how you made room.", ["shared-wonder", "kindness", "public", "low-stakes"], allowsPhoto: false),
        mission("shared-friend-portrait", "One Good Sentence", "Tell a friend, family member, or coworker one good sentence about them that is not about how useful they are. Keep it concrete.", "Write the sentence you gave away.", ["shared-wonder", "connection", "kindness", "low-stakes"], allowsPhoto: false),
        mission("shared-kind-route", "The Kinder Route", "Share one small, genuinely useful local delight with someone: a good bench, a quiet shortcut, a free view, a friendly plant, a library shelf. Tell them where it is, then let the bench make its own case.", "Write the delight you recommended.", ["shared-wonder", "connection", "place", "public", "low-stakes"])
    ]

    static let coreMissions: [PlayfulMission] = [
        mission("oldest-smell", "The Oldest Thing", "Find the oldest thing near you and smell it. What does age smell like here?", "Complete this: The oldest thing near me smelled like...", ["scent", "touch", "inside", "low-energy"]),
        mission("coldest-touch", "The Coldest Touch", "Find the coldest thing you are allowed to touch. Hold it for five seconds.", "Write one sentence about where the cold seemed to come from.", ["touch", "temperature", "inside", "low-energy"]),
        mission("quietest-sound", "The Quietest Sound", "Stand still and hunt the quietest sound in the room. Not the loudest. The shyest.", "Complete this: Under everything else, I heard...", ["sound", "inside", "low-energy"]),
        mission("three-rough", "Texture Thief", "Find three rough textures within ten steps. Rank them from friendly to suspicious.", "Write one sentence naming the strangest texture.", ["touch", "inside", "public"]),
        mission("blue-count", "Blue Census", "Count every blue thing you can see without moving your feet.", "Write the blue thing that surprised you most.", ["visual", "color", "inside", "public"]),
        mission("tiny-door", "Tiny Door", "Find the smallest opening nearby: a crack, keyhole, drawer gap, vent, bottle mouth, or shadow under a door.", "Write what might live on the other side.", ["visual", "imagination", "inside"]),
        mission("weather-scent", "Weather Has A Smell", "Step near a door or window and compare the air on both sides. Which side has more weather in it?", "Write one sentence about the smell or weight of the air.", ["weather", "scent", "inside"]),
        mission("object-portrait", "Object Portrait", "Choose one ordinary object and photograph it like it is the main character.", "Write its first line of dialogue.", ["photo", "visual", "character", "inside"]),
        mission("five-shadows", "Shadow Hunt", "Find five shadows. Pick the one that looks least like the thing casting it.", "Write what the shadow is pretending to be.", ["visual", "photo", "inside", "public"]),
        mission("softest-edge", "The Softest Edge", "Find the softest edge nearby. A sleeve, paper, light, bread crust, blanket, voice, or dust counts.", "Write one sentence about what made it soft.", ["touch", "visual", "low-energy"]),
        mission("smell-map", "Smell Map", "Move through three nearby spots and notice how the smell changes. Make a tiny map in your head.", "Write the border where the smell changed.", ["scent", "movement", "inside"]),
        mission("tiny-kindness", "Evidence Of Kindness", "Find one tiny sign that someone made life easier for someone else.", "Write the evidence, no moral required.", ["visual", "public", "errand"]),
        mission("weirdest-label", "The Weirdest Label", "Find the strangest label, warning, sticker, sign, or package text nearby.", "Write what makes it strange.", ["visual", "public", "errand"]),
        mission("sound-layer", "Sound Layer", "Listen for three layers: machine, body, world. Name one sound in each layer.", "Write the layer that felt most alive.", ["sound", "inside", "public"]),
        mission("weight-guess", "Weight Oracle", "Pick up a safe object. Guess its exact weight, then decide if your hand agrees.", "Write whether it was heavier or lighter than its face suggested.", ["touch", "weight", "inside"]),
        mission("one-inch-kingdom", "One-Inch Kingdom", "Look closely at one square inch of something: fabric, bark, carpet, table, wall, sidewalk.", "Write what lives in that tiny kingdom.", ["visual", "touch", "photo", "low-energy"]),
        mission("borrowed-color", "Borrowed Color", "Find an object borrowing color from something else: reflected light, stained glass, screen glow, sunset, shade.", "Write who lent the color.", ["visual", "color", "photo"]),
        mission("old-date", "Date Hunter", "Find the oldest visible date nearby: on a coin, receipt, book, sign, package, building, or file.", "Write what that date has been waiting through.", ["visual", "public", "history"]),
        mission("chair-held", "The Chair Holds", "Sit down and let the chair do all the work for sixty seconds. Notice where it pushes back.", "Complete this: The chair held me by...", ["touch", "rest", "low-energy", "inside"], allowsPhoto: false),
        mission("brightest-small", "Small Bright Thing", "Find the brightest small thing nearby. Not the biggest bright thing. The small one.", "Write why it caught the light.", ["visual", "low-energy", "inside", "public"])
    ]

    /// Immediate nonsense with a sensory job to do. Every mission begins now,
    /// works in public or private, needs no special object or able-bodied
    /// movement, and accepts either a sentence or a photo as its souvenir.
    static let ridiculousMissions: [PlayfulMission] = [
        mission("ridiculous-body-meeting", "Emergency Body Meeting", "Convene an emergency meeting of three body parts you can safely move: toes, fingers, eyebrows, shoulders, anything. Let each vote once. Which one is clearly trying to take over?", "Write the three delegates and the would-be ruler.", ["ridiculous", "anywhere", "present-moment", "body", "movement", "imagination"], allowsPhoto: false),
        mission("ridiculous-ambient-conductor", "Conduct The Situation", "For twenty seconds, conduct every sound around you with one finger. Bring in the hum. Silence the clunk. Give the smallest sound an outrageous solo.", "Write which sound got the solo.", ["ridiculous", "anywhere", "present-moment", "sound", "movement", "imagination"], allowsPhoto: false),
        mission("ridiculous-countdown", "Completely Unnecessary Countdown", "Choose one harmless tiny action you can do right now: blink, sip, stand, tap, turn a page. Give it a five-second launch countdown, then notice the exact instant it becomes done.", "Write the action that received launch clearance.", ["ridiculous", "anywhere", "present-moment", "body", "time", "noticing"], allowsPhoto: false),
        mission("ridiculous-dramatic-zoom", "Dramatic Zoom", "Pick the most boring thing in view. Slowly lean your attention closer like a television camera revealing the villain. Stop when one detail becomes suspicious.", "Write the suspicious detail revealed by the zoom.", ["ridiculous", "anywhere", "present-moment", "visual", "imagination", "low-energy"], allowsPhoto: false),
        mission("ridiculous-tiny-applause", "Applause For The Competent", "Find one ordinary thing currently doing its job. Give it the smallest possible round of applause (fingertips, one nod, or silent jazz hands), then inspect what it did to earn this.", "Write the performer and its exact achievement.", ["ridiculous", "anywhere", "present-moment", "visual", "touch", "imagination"], allowsPhoto: false),
        mission("ridiculous-object-election", "Emergency Object Election", "Choose three things you can see. Elect one Mayor of Right Now, one Minister of Suspicious Affairs, and one object that absolutely demanded a title it cannot handle.", "Write the cabinet and the evidence behind one appointment.", ["ridiculous", "anywhere", "present-moment", "visual", "object", "imagination"], allowsPhoto: false),
        mission("ridiculous-freeze-frame", "Freeze-Frame Investigation", "When you are safely still, freeze for ten seconds in the exact pose you are already in. Your only job is to catch what keeps moving without you.", "Write the thing that refused to freeze.", ["ridiculous", "anywhere", "present-moment", "body", "visual", "movement"], allowsPhoto: false),
        mission("ridiculous-imaginary-hat", "Adjust The Invisible Hat", "You are wearing an invisible hat of unreasonable importance. Adjust it once with complete dignity. Now notice what your forehead, hair, skin, or the air was actually doing.", "Write the hat's title and the real sensation beneath it.", ["ridiculous", "anywhere", "present-moment", "body", "touch", "imagination"], allowsPhoto: false),
        mission("ridiculous-five-beat-parade", "Five-Beat Parade", "Hold a five-beat parade using whatever can safely move: feet, shoulders, fingers, wheels, or eyebrows. Give every beat more ceremony than the last.", "Write which beat believed the hype most.", ["ridiculous", "anywhere", "present-moment", "body", "rhythm", "movement"], allowsPhoto: false),
        mission("ridiculous-support-surface", "Gravity's Press Conference", "Press gently into whatever is supporting you: floor, chair, bed, wall, shoes. Ask gravity one question by shifting your weight, then feel exactly where the answer pushes back.", "Write where gravity answered.", ["ridiculous", "anywhere", "present-moment", "body", "touch", "weight"], allowsPhoto: false),
        mission("ridiculous-air-border", "Air Border Patrol", "Move one hand slowly through the air around you. Find the border where the temperature, breeze, light, or texture changes. It is a tiny country now; name it.", "Write the border and the country's name.", ["ridiculous", "anywhere", "present-moment", "touch", "temperature", "imagination"], allowsPhoto: false),
        mission("ridiculous-blink-photo", "Blink Photograph", "Frame the scene in front of you with your eyes. Close them for three seconds. Open them and catch the very first detail that develops.", "Write the first detail in the blink photograph.", ["ridiculous", "anywhere", "present-moment", "visual", "body", "low-energy"], allowsPhoto: false),
        mission("ridiculous-museum-plaque", "Museum Of This Exact Second", "Choose the nearest utterly ordinary thing and give it a seven-word museum plaque describing its exact condition right now. Curators are standing by.", "Write the seven-word plaque.", ["ridiculous", "anywhere", "present-moment", "visual", "object", "words"], allowsPhoto: false),
        mission("ridiculous-sound-audition", "Audition The Soundtrack", "Audition three sounds you can hear for the role of Sound of This Exact Moment. Listen to each candidate all the way through before choosing the winner.", "Write the winning sound and why it got the part.", ["ridiculous", "anywhere", "present-moment", "sound", "attention", "imagination"], allowsPhoto: false),
        mission("ridiculous-micro-ceremony", "Historic Tiny Achievement", "Complete one tiny action already available to you, then mark the occasion with a solemn nod, a fingertip fanfare, or one whispered 'done.' Notice what changes in your body after the ceremony.", "Write the achievement and what shifted after it.", ["ridiculous", "anywhere", "present-moment", "body", "movement", "noticing"], allowsPhoto: false),
        mission("ridiculous-opposite-hand", "Cameo By The Other Hand", "Give your non-usual hand one safe, tiny job right now. Let it tap, point, turn, hold, or choose. Watch what suddenly requires a committee.", "Write the job and the awkwardly vivid part.", ["ridiculous", "anywhere", "present-moment", "body", "touch", "movement"], allowsPhoto: false),
        mission("ridiculous-constellation", "Emergency Constellation", "Choose three points above or ahead of you: marks, lights, corners, clouds, anything. Connect them into a constellation and name the extremely local legend it depicts.", "Write the constellation and its legend in one line.", ["ridiculous", "anywhere", "present-moment", "visual", "place", "imagination"], allowsPhoto: false),
        mission("ridiculous-official-nod", "The Official Nod", "Find the most overlooked thing in sight. Study its actual work for ten seconds, then give it one grave official nod. The inspection is complete.", "Write what passed inspection and the job it was doing.", ["ridiculous", "anywhere", "present-moment", "visual", "object", "attention"], allowsPhoto: false),
        mission("ridiculous-red-carpet", "Three-Step Red Carpet", "Travel three safe steps toward whatever you were doing next as if the ground has waited all day for this entrance. If steps do not suit, walk two fingers across a surface. Notice one sensation per step.", "Write the three red-carpet sensations.", ["ridiculous", "anywhere", "present-moment", "body", "touch", "movement"], allowsPhoto: false),
        mission("ridiculous-reality-caption", "Caption Reality Badly", "Look at this exact moment and give it the most overdramatic six-word title the evidence can support. It must include one real detail you can sense now.", "Write the six-word title.", ["ridiculous", "anywhere", "present-moment", "visual", "words", "imagination"], allowsPhoto: false)
    ].map { draft in
        var mission = draft
        mission.allowsPhoto = true
        return mission
    }

    static let attentionMissions: [PlayfulMission] = [
        mission("body-heartbeat-location", "The Body Reports In", "Stand completely still until you can feel your heartbeat somewhere other than your chest. Report the location.", "Write the place where the heartbeat answered.", ["body", "touch", "low-energy", "inside"], allowsPhoto: false),
        mission("body-quiet-steps", "Quiet Step Audit", "Walk ten steps as quietly as you possibly can. What gave you away?", "Write the sound or movement that betrayed you.", ["body", "sound", "movement", "inside"], allowsPhoto: false),
        mission("body-warmer-hand", "Hand Weather", "Find out which of your hands is warmer right now. Form a theory about why.", "Write which hand was warmer and your best theory.", ["body", "touch", "temperature", "low-energy"], allowsPhoto: false),
        mission("body-unclench-report", "The Muscle Confesses", "Unclench everything. Report which muscle was holding on and refused to admit it.", "Name the muscle that was still holding on.", ["body", "touch", "rest", "low-energy"], allowsPhoto: false),
        mission("body-tongue-watch", "Tongue Watch", "Notice what your tongue is doing right now. It was doing something.", "Write the tongue report in one exact phrase.", ["body", "taste", "low-energy"], allowsPhoto: false),
        mission("body-wall-palm", "Building Report", "Press your palm flat against the nearest wall for ten seconds. Decide what the building is doing today.", "Write what the building is doing today.", ["body", "touch", "inside", "place"], allowsPhoto: false),
        mission("body-chair-border", "Chair Border", "Find the exact place where your body ends and the chair begins. It is blurrier than you would think.", "Write one sentence about the blurriest border.", ["body", "touch", "rest", "inside"], allowsPhoto: false),
        mission("body-purposeful-yawn", "Yawn Route", "Yawn on purpose. Track where it travels: jaw, ears, eyes, spine. File a route map.", "Write the route the yawn took.", ["body", "rest", "low-energy"], allowsPhoto: false),
        mission("body-suspicious-breath", "Suspicious Breath", "Take one breath so slow it feels suspicious. What did you smell at the very bottom of it?", "Write the bottom-of-the-breath smell.", ["body", "scent", "low-energy"], allowsPhoto: false),
        mission("body-ankle-save", "Ankle Rescue", "Stand on one foot while you wait for something today. Report what your ankle did to save you.", "Write what the ankle did.", ["body", "balance", "movement"], allowsPhoto: false),
        mission("body-engine-count", "The Engine", "Find your pulse with two fingers. Count to ten beats. That is the engine. It never gets thanked.", "Write where you found the engine.", ["body", "touch", "low-energy"], allowsPhoto: false),
        mission("sound-newcomer", "Name The Newcomer", "Count the sounds you can hear right now. Then wait, perfectly still, for the next one to arrive. Name the newcomer.", "Write the newest sound by name.", ["sound", "inside", "low-energy"], allowsPhoto: false),
        mission("sound-lowest-room", "Lowest Sound", "Find the lowest sound in the room. It has probably been running this whole time.", "Write the lowest sound and where it might live.", ["sound", "inside", "low-energy"], allowsPhoto: false),
        mission("sound-farthest-away", "Farthest Sound", "Listen for the farthest-away sound you can detect. Estimate the distance in honest units.", "Write the sound and its honest distance.", ["sound", "inside", "outside"], allowsPhoto: false),
        mission("sound-three-objects", "Best Voice", "Tap three safe objects within reach. Which one has the best voice?", "Write which object had the best voice.", ["sound", "touch", "inside"], allowsPhoto: false),
        mission("sound-appliance-duet", "Appliance Duet", "Hum one low note and hold it. Somewhere, an appliance is humming back. Find your duet partner.", "Write the duet partner.", ["sound", "inside", "low-energy"], allowsPhoto: false),
        mission("sound-daily-unmentioned", "Unmentioned Sound", "Identify one sound you hear every single day but have never once mentioned to anyone. Mention it now.", "Write the daily sound.", ["sound", "inside", "low-energy"], allowsPhoto: false),
        mission("sound-ear-cups", "Borrowed Ears", "Cup your hands behind your ears for ten seconds. Report what got louder.", "Write what changed when your ears borrowed walls.", ["sound", "body", "inside"], allowsPhoto: false),
        mission("sound-room-pulse", "Room Pulse", "Find the room's pulse: something that ticks, blinks, drips, or hums in rhythm. Take its tempo.", "Write the pulse and its tempo.", ["sound", "rhythm", "inside"], allowsPhoto: false),
        mission("object-oldest-story", "Oldest Witness", "Find the oldest object in the room and ask what it has seen. Record its best story in one line.", "Write the oldest object's best story.", ["object", "history", "inside"]),
        mission("object-no-credit", "No-Credit Object", "Pick the object nearest you that gets no credit. Thank it specifically for the exact job it does.", "Write the object and the job it does.", ["object", "visual", "inside", "low-energy"]),
        mission("object-tired", "Object Rest", "Find one object that is tired. What would rest look like for it?", "Write what rest would look like for that object.", ["object", "visual", "imagination", "inside"]),
        mission("object-face", "Object Face", "Choose any object and find its face. Most of them have one. Describe the expression.", "Write the object's expression.", ["object", "visual", "imagination", "inside"]),
        mission("object-waiting", "Waiting Object", "Locate an object that is waiting. For what?", "Write what the object is waiting for.", ["object", "visual", "inside"]),
        mission("object-most-loyal", "Most Loyal", "Find the most loyal object you own: longest service, still working. Note its years.", "Write the object and its years of service.", ["object", "history", "inside"]),
        mission("object-repair", "Worth Saving", "Find a repair: tape, glue, a stitch, a weld. Someone decided this thing was worth saving. Guess why.", "Write the repair and the reason it survived.", ["object", "visual", "history", "inside"]),
        mission("object-traveled-farther", "Farther Traveled", "Find something in this room that has traveled farther than you ever have. Name its homeland.", "Write the object and its homeland.", ["object", "history", "inside"]),
        mission("object-in-charge", "Room Politics", "Decide which object in this room is actually in charge. Then decide which one merely thinks it is.", "Write the ruler and the pretender.", ["object", "imagination", "inside"]),
        mission("object-drawer-greeting", "Drawer Greeting", "Open a drawer you have not opened in a month. Greet one thing inside it by name.", "Write the thing's name.", ["object", "inside", "low-energy"]),
        mission("object-pocket-story", "Pocket Story", "Find one thing in your pocket or bag with a story you have never told anyone. Tell me the short version.", "Write the pocket thing and the short version.", ["object", "memory", "inside", "public"]),
        mission("object-remembered-color", "Remembered Color", "Find something that is a different color than you remembered it being. Record both colors: the remembered and the real.", "Write the remembered color and the real one.", ["object", "visual", "color"]),
        mission("nature-small-commute", "Tiny Commute", "Find one living thing smaller than your thumbnail. Watch its commute for thirty seconds. Report its errand.", "Write the living thing and its errand.", ["nature", "visual", "outside", "movement"]),
        mission("nature-plant-reaching", "Plant Wants", "Find the nearest plant and check what it is reaching toward. Plants always want something.", "Write what the plant wants.", ["nature", "visual", "inside", "outside"]),
        mission("nature-bird-business", "Bird Business", "Spot a bird and track it until it lands or vanishes. What business was it on?", "Write the bird's business.", ["nature", "visual", "outside", "movement"]),
        mission("nature-unseen-animal", "Unseen Suspect", "Find evidence of an animal you cannot currently see: tracks, sounds, leavings, damage. Name your suspect.", "Write the evidence and the suspect.", ["nature", "visual", "outside", "public"]),
        mission("nature-weed-winning", "Weed Winning", "Find a weed winning, growing somewhere it was never invited. Salute it. Note the territory claimed.", "Write the territory the weed claimed.", ["nature", "visual", "outside", "public"]),
        mission("nature-tree-scar", "Tree Scar", "Locate the nearest tree and find its oldest scar. Estimate the year of the wound.", "Write the scar and your estimated year.", ["nature", "visual", "history", "outside"]),
        mission("nature-moss-project", "Moss Project", "Find moss or lichen. It has been working on that exact spot longer than you have been alive. Acknowledge the project.", "Write the project site.", ["nature", "visual", "outside", "low-energy"]),
        mission("nature-compressed-forest", "Compressed Forest", "Find one seed anywhere: in food, in the air, on the ground. You are holding a compressed forest. Note where it was headed.", "Write the seed and its destination.", ["nature", "visual", "food", "outside"]),
        mission("sky-plain-forecast", "Sky Desk", "Step outside, or to a window. What is the sky deciding right now? File the forecast in plain words.", "Write the sky's plain-word forecast.", ["sky", "weather", "visual", "inside", "outside"]),
        mission("sky-find-wind", "Find The Wind", "Find the wind, not by feeling it, but by seeing it. What is it moving?", "Write what the wind moved.", ["sky", "weather", "visual", "movement", "outside"]),
        mission("sky-cloud-fleet", "Cloud Fleet", "Name today's clouds like ships in a harbor. Where is the fleet headed?", "Write one ship-name and where the fleet is headed.", ["sky", "weather", "visual", "imagination"]),
        mission("sky-real-color", "Real Sky Color", "Catch the exact color of the sky directly overhead. Not blue, not grey: the real one. Mix it in words.", "Write the true color in your own words.", ["sky", "weather", "visual", "color"]),
        mission("sky-rain-stage", "Rain Journey", "Find where the rain goes after it lands. Follow it one stage of its journey.", "Write the rain's next stage.", ["sky", "weather", "water", "outside"]),
        mission("sky-watchkeeper", "Watchkeeper Sighting", "Find the moon in daytime, or the first star at night. Log the sighting like a watchkeeper.", "Write the sighting log.", ["sky", "night", "visual", "outside"]),
        mission("sky-cloud-before-after", "Cloud Before After", "Watch one cloud until it changes shape. Record the before and after.", "Write the cloud before and after.", ["sky", "weather", "visual", "outside"]),
        mission("light-route", "Light Route", "Find where the light enters this room, and trace where it finally dies. Map the route.", "Write the route the light took.", ["light", "visual", "inside"]),
        mission("light-shadow-performer", "Shadow Performer", "Locate one shadow doing something interesting. Shadows are usually understated performers.", "Write what the shadow was doing.", ["light", "shadow", "visual", "inside", "photo"]),
        mission("light-reflection-secret", "Unknowing Reflection", "Find a reflection of something that does not know it is being reflected.", "Write what was reflected.", ["light", "visual", "inside", "photo"]),
        mission("light-non-screen-bright", "Not A Screen", "Find the brightest thing in the room that is not a screen.", "Write the brightest non-screen thing.", ["light", "visual", "inside", "low-energy"]),
        mission("light-sun-delivery", "Sun Delivery", "Find a patch of sunlight and put your hand in it. Report the delivery; it left the sun eight minutes ago.", "Write what the delivery felt like.", ["light", "touch", "inside", "outside"], allowsPhoto: false),
        mission("light-room-rearrange", "Dark Rearrangement", "Turn off one light you would normally leave on. Watch the room rearrange itself. What stepped forward in the dark?", "Write what stepped forward.", ["light", "night", "inside", "low-energy"]),
        mission("threshold-doorway-between", "Doorway Between", "Stand in a doorway for ten full seconds. Doorways are thresholds. Decide what you are between.", "Write what the doorway held you between.", ["threshold", "place", "inside", "low-energy"], allowsPhoto: false),
        mission("threshold-temperature-border", "Temperature Border", "Find the spot in your home where the temperature changes. That is a border. Borders have guards; identify yours.", "Write the border and its guard.", ["threshold", "temperature", "inside", "place"]),
        mission("threshold-quiet-corner", "Corner View", "Find the quietest corner of the room and stand in it. Describe the room from its point of view.", "Write the corner's view.", ["threshold", "sound", "inside", "low-energy"], allowsPhoto: false),
        mission("threshold-unstood-spot", "New Footprint", "Stand somewhere in your own home you have never stood before. There is at least one spot. Claim it.", "Write the claimed spot.", ["threshold", "place", "inside", "low-energy"]),
        mission("threshold-previous-message", "Previous Message", "Find evidence of whoever was in this space before you: a nail hole, a paint line, a scuff, a worn patch. Read the message they left.", "Write the message you read.", ["threshold", "history", "inside", "visual"]),
        mission("threshold-mouse-door", "Mouse-Sized Door", "Find the room's secret door: the place a mouse-sized visitor would enter and exit. Note it on the map.", "Write where the secret door is.", ["threshold", "visual", "inside", "imagination"]),
        mission("threshold-wall-perimeter", "Wall Report", "Walk the perimeter of one room slowly, trailing a hand along the wall. Report the one thing the wall told you.", "Write what the wall told you.", ["threshold", "touch", "inside", "movement"], allowsPhoto: false),
        mission("motion-long-way", "The Long Way", "Take the long way to wherever you are going next. Report what the shortcut was hiding from you.", "Write what the shortcut was hiding.", ["movement", "public", "errand"]),
        mission("motion-half-speed", "Half Speed", "Walk at half speed for exactly one minute. Report what caught up with you.", "Write what caught up.", ["movement", "body", "low-energy"]),
        mission("motion-ankle-height", "Ankle-Height Treasure", "Take twenty steps and find one thing at ankle height worth keeping.", "Write the ankle-height thing.", ["movement", "visual", "outside", "public"]),
        mission("motion-three-circles", "Circle Collection", "On your next walk, collect three circles. Any size. Report your haul.", "Write the three circles.", ["movement", "visual", "shape", "outside", "public"]),
        mission("motion-five-color", "Color Before Noon", "Find five of one color before noon. I accept photographs and testimony.", "Write the color and your five witnesses.", ["movement", "visual", "color", "public"]),
        mission("motion-halfway-point", "Invisible Halfway", "Cross any street or hallway and notice the exact moment you are halfway. Halfway points are invisible until you look.", "Write where halfway appeared.", ["movement", "threshold", "public"], allowsPhoto: false),
        mission("motion-unwatched-moving", "Watch It For Them", "Next time you are a passenger or waiting in line, find the one moving thing nobody else is watching. Watch it for them.", "Write the unwatched moving thing.", ["movement", "public", "visual"]),
        mission("work-building-voice", "Workplace Voice", "Find the one sound your workplace makes that no other building on Earth makes. That is its voice.", "Write the workplace voice.", ["work", "sound", "public"], allowsPhoto: false),
        mission("work-ignored-object-title", "Gallery Title", "Locate the most ignored object at work and give it a title, like a painting in a gallery.", "Write the object's gallery title.", ["work", "object", "visual", "public"]),
        mission("work-machine-mood", "Machine Mood", "Your machine has moods. What is today's?", "Write the machine and today's mood.", ["work", "object", "public"]),
        mission("work-boring-minute-moving", "Boring Minute Motion", "During the most boring minute of your day, find one thing that is moving. Something always is.", "Write the moving thing.", ["work", "movement", "visual", "public"]),
        mission("work-small-tending", "Small Tending", "Find one coworker's small act of tending: a watered plant, a straightened stack, a propped door. Witness it for the record.", "Write the tending you witnessed.", ["work", "kindness", "public", "visual"]),
        mission("work-senior-staff", "Senior Staff", "Find the oldest thing in your workplace that still does its job every day. Senior staff. Note its tenure.", "Write the senior staff member and tenure.", ["work", "history", "object", "public"]),
        mission("work-route-new-thing", "Route River", "On your commute, find one thing that was not there last week. The route is not the same river twice.", "Write what changed on the route.", ["work", "commute", "public", "visual"]),
        mission("fuel-first-sip", "First Sip Report", "Hold the first sip of your next drink for five full seconds before swallowing. Report what is actually in there.", "Write what the sip contained.", ["taste", "fuel", "body", "low-energy"], allowsPhoto: false),
        mission("fuel-closed-eyes-bite", "Three Things In It", "Eat one bite with your eyes closed and name three things in it, not one.", "Write the three things.", ["taste", "fuel", "body"], allowsPhoto: false),
        mission("fuel-oldest-ingredient", "Oldest Ingredient", "Find the oldest ingredient in your next meal: the one that took longest to grow, age, or travel. Credit it.", "Write the ingredient and what it endured.", ["taste", "fuel", "history"], allowsPhoto: false),
        mission("fuel-smell-prediction", "Prediction Before Taste", "Smell something before you taste it and write down your prediction. Grade the prediction after.", "Write the prediction and the grade.", ["taste", "scent", "fuel"], allowsPhoto: false),
        mission("night-still-awake", "Still Awake", "Step outside after dark for thirty seconds. Count what is still awake.", "Write the count and one thing still awake.", ["night", "sound", "visual", "outside"]),
        mission("night-guard-light", "Last Light Guard", "Find the last light on in your house tonight and ask what it is guarding.", "Write what the light is guarding.", ["night", "light", "inside", "low-energy"]),
        mission("night-second-voice", "Second Voice", "Find one sound that only exists at night in your home. The house has a second voice it saves for after hours.", "Write the night-only sound.", ["night", "sound", "inside"], allowsPhoto: false),
        mission("night-farthest-light", "Farthest Light", "Look out a dark window and find the farthest light you can see. Someone or something is there. Wish them well.", "Write the farthest light.", ["night", "light", "visual", "inside"]),
        mission("strange-visual-rhyme", "Visual Rhyme", "Find something that visually rhymes with something else in the room: two shapes that did not know they matched. Introduce them.", "Write the two matching shapes.", ["visual", "shape", "inside", "imagination"]),
        mission("strange-street-new-old", "Street Introduction", "Find the newest thing on your street and the oldest. Introduce them to each other. Imagine the conversation.", "Write the introduction.", ["visual", "history", "outside", "imagination"]),
        mission("strange-outlive-you", "Outliving Object", "Touch something that will outlive you. Be polite about it.", "Write the object and the politeness.", ["touch", "object", "history", "inside"], allowsPhoto: false),
        mission("strange-new-thing", "New Thing", "Find something that did not exist a year ago, anywhere in view.", "Write the new thing.", ["visual", "history", "inside", "public"]),
        mission("strange-growth-decay", "Exchange Rate", "Find something mid-decay and something mid-growth within ten feet of each other. Note the exchange rate.", "Write the exchange rate.", ["visual", "nature", "history", "outside"]),
        mission("strange-age-gap", "Age Gap", "Estimate the age of one thing you can see, then find out if you can. Record the gap between guess and truth.", "Write the guess, the truth, or the mystery.", ["visual", "history", "object"]),
        mission("strange-stranger-decision", "A Stranger Chose That", "Pick up the nearest human-made object and find one decision a stranger made about it: a curve, a color, a button, a corner. Agree or disagree with them.", "Write the decision and your verdict.", ["object", "touch", "design", "inside"], allowsPhoto: false),
        mission("strange-technical-miracle", "Furniture Miracle", "Find one thing in arm's reach that is technically a miracle and is being treated like furniture. Restore its title for one minute.", "Write the restored title.", ["object", "wonder", "inside", "low-energy"])
    ]

    static let shadowMissions: [PlayfulMission] = [
        mission("shadow-spark-hunt", "Shadow Spark Hunt", "Find one broken, rusty, faded, cracked, or overlooked thing your brain usually deletes. Look for ten seconds before deciding what it is.", "Write what time has done to it.", ["shadow-wonder", "shadow", "history", "visual", "low-energy"]),
        mission("shadow-mystery-clue", "The Mystery Mission", "From a lawful public path or a place you already have permission to be, choose one closed, old, or half-forgotten thing and find one visible clue about what it used to be. Cross no boundary for the story.", "Write the clue and the question it opened.", ["shadow-wonder", "mystery", "history", "public", "visual"]),
        mission("shadow-tribute-object", "The Tribute Mission", "Find one repaired, worn, or past-its-prime object. Give it thirty seconds of respect without trying to fix it.", "Write one sentence honoring what it survived.", ["shadow-wonder", "tribute", "object", "history", "inside"]),
        mission("shadow-mood-match", "Mood Match", "Stop fighting the grey and go find the one thing in the room that agrees with it. Something here is already the same colour as today.", "Write the detail that matched the weather inside you.", ["shadow-wonder", "mood-match", "night", "weather", "inside"], allowsPhoto: false),
        mission("shadow-last-light", "Last Light Witness", "Find the last, smallest, or most stubborn light nearby. Ask what it is guarding from the dark.", "Write what the light was guarding.", ["shadow-wonder", "night", "light", "threshold", "inside"]),
        mission("shadow-offering", "Leave an Offering", "Make one small offering with no audience and no litter: water a plant you are allowed to tend, return a borrowed thing, or leave a kindness no one must answer. Do not feed wildlife for this mission.", "Write what you offered, and to whom or what.", ["shadow-wonder", "offering", "kindness", "fae", "folklore"], allowsPhoto: false),
        mission("shadow-threshold", "Honor a Threshold", "Find one threshold: a doorway, gate, or the seam where one room becomes another. Pause on it. Notice it is neither in nor out.", "Write what changes the moment you cross.", ["shadow-wonder", "threshold", "liminal", "folklore", "inside"], allowsPhoto: false),
        mission("shadow-true-name", "The True Name", "Find one vague thing and give it a more exact name: a feeling if that is welcome, or else the weather, a sound, a color, or the condition of an old object. Precision is enough; disclosure is not required.", "Write the exact name you chose, or simply keep it private.", ["shadow-wonder", "true-names", "naming", "low-energy", "inside"], allowsPhoto: false),
        mission("shadow-iron-key", "Mind the Edges", "Find the iron already in your home (a key, a nail, a cast pan) and set it deliberately by a door, the way folklore minds a threshold.", "Write whether a guarded edge changes the room.", ["shadow-wonder", "protection", "iron", "threshold", "folklore", "inside"]),
        mission("shadow-correspondence", "One Correspondence", "Make one old correspondence literal: salt for protection, rosemary for memory, a dark stone for rest. Place it where you'll see it.", "Write what it now stands for.", ["shadow-wonder", "correspondences", "witchcraft", "folklore", "inside"]),
        mission("shadow-ending-thing", "The Vanishing", "Find one thing quietly ending right now (light going, a flower past peak, a cup going cold) and witness it leave without stopping it.", "Write one sentence for it before it's gone.", ["shadow-wonder", "mono-no-aware", "memory", "low-energy", "inside"], allowsPhoto: false),
        mission("shadow-cost", "The Goblin's Question", "Pick one 'free' thing in your day (a scroll, a shortcut, a numbing habit) and ask the Goblin Market's only question of it.", "Write its real, hidden cost in one line.", ["shadow-wonder", "goblin", "bargain", "unseelie"], allowsPhoto: false),
        mission("shadow-disowned", "Turn the Lamp", "Notice one small thing about today you have been skipping. If the day itself is too tender, choose a neglected object instead. Look for ten seconds: no fixing, no verdict, no forced disclosure.", "Write what you actually saw, or keep only the object's name.", ["shadow-wonder", "shadow-self", "low-energy", "inside"], allowsPhoto: false)
    ]

    private static func mission(
        _ id: String,
        _ title: String,
        _ prompt: String,
        _ proofPrompt: String,
        _ tags: [String],
        allowsPhoto: Bool = true
    ) -> PlayfulMission {
        PlayfulMission(id: id, title: title, prompt: prompt, proofPrompt: proofPrompt, tags: tags, allowsPhoto: allowsPhoto)
    }
}

enum PromptWhisperRegistry {
    static let checkIns: [PromptWhisper] = [
        checkIn("what-now", "A page taps the glass", "What are you doing this exact second? One sentence.", "What were you doing when I tapped the glass?", ["present-moment", "check-in"]),
        checkIn("loudest-sound", "I'm listening", "What is the loudest sound around you right now?", "What sound was ruling the room?", ["sound", "check-in"]),
        checkIn("body-honest", "Something's clenched", "One muscle has been holding on for hours. Find it and let it go.", "Which one had been holding on?", ["body", "check-in"]),
        checkIn("nearest-color", "Color census", "What color is nearest your left hand?", "What color was closest?", ["color", "visual", "check-in"]),
        checkIn("tiny-want", "A tiny want knocks", "There's something small you could have in the next ten minutes and keep talking yourself out of.", "What did you talk yourself out of?", ["want", "check-in"]),
        checkIn("room-mood", "Room report", "If this room had been left exactly like this on purpose, what would it mean?", "What was the room saying?", ["place", "mood", "check-in"]),
        checkIn("unreasonable-detail", "The detail insists", "What detail is being oddly dramatic near you?", "What detail insisted on being noticed?", ["visual", "check-in"]),
        checkIn("one-good-thing", "Evidence, please", "Something within reach is already going right. Name it before it stops.", "What was quietly going right?", ["gratitude", "check-in"]),
        checkIn("hands-doing", "Hand report", "What are your hands doing right now?", "What were your hands doing?", ["body", "touch", "check-in"]),
        checkIn("smallest-motion", "Motion ledger", "What is the smallest moving thing you can see?", "What small motion did you catch?", ["movement", "visual", "check-in"]),
        checkIn("who-put-it", "Somebody put that there", "Find the nearest object nobody decided to put there. It arrived by accident.", "What arrived by accident?", ["place", "visual", "check-in"]),
        checkIn("last-touched", "Fingerprints", "What was the last thing you touched that wasn't glass?", "What was it, and how did it feel?", ["touch", "body", "check-in"]),
        checkIn("out-of-place", "One thing is wrong", "Something in your eyeline is in the wrong room. It has been for a while.", "What was in the wrong room?", ["visual", "place", "check-in"]),
        checkIn("background-noise", "Under the noise", "Mute whatever you can. There's a second sound underneath the first one.", "What was underneath?", ["sound", "check-in"]),
        checkIn("temperature-map", "Cold spot", "Your left hand and your right hand are not the same temperature. Check.", "Which hand won, and your theory why?", ["body", "touch", "check-in"]),
        checkIn("almost-threw-out", "Still here", "Find something you nearly got rid of and didn't.", "What survived the cull?", ["place", "memory", "check-in"]),
        checkIn("weather-inside-outside", "Two weathers", "Look outside, then look in. One of those forecasts is lying today.", "Which weather was lying?", ["weather", "mood", "check-in"]),
        checkIn("sentence-snapshot", "Keep one true thing", "One sentence, and it has to be something you'd be embarrassed to make prettier.", "What did you refuse to prettify?", ["truth", "souvenir", "check-in"])
    ]

    static func promptWhisper(from mission: PlayfulMission) -> PromptWhisper {
        PromptWhisper(
            id: "mission-\(mission.id)",
            kind: .mission,
            title: mission.title,
            body: mission.prompt,
            keepPrompt: mission.proofPrompt,
            tags: mission.tags,
            allowsPhoto: mission.allowsPhoto
        )
    }

    static func promptWhisper(from favor: BookFavor) -> PromptWhisper {
        PromptWhisper(
            id: "book-favor-\(favor.id)",
            kind: .mission,
            title: "A favor from the Book",
            body: favor.ask,
            keepPrompt: favor.practiceShape,
            tags: ["book-favor", favor.archiveTag, "wonder:\(favor.facet.rawValue)"]
        )
    }

    static func prompts(for day: BookDay, inputs: BookSourceInputs, now: Date, count: Int) -> [PromptWhisper] {
        guard count > 0 else { return [] }
        let missions = rankedMissionWhispers(for: day, inputs: inputs, now: now)
        var prompts: [PromptWhisper] = []
        var seen: Set<String> = []

        if let favor = inputs.bookInterior.activeFavor,
           favor.status == .offered,
           Calendar.current.isDate(favor.createdAt, inSameDayAs: day.date) {
            let whisper = promptWhisper(from: favor)
            prompts.append(whisper)
            seen.insert(whisper.id)
        }

        for slot in 0..<(count * 3) {
            let preferCheckIn = slot % 2 == 0
            let firstPool = preferCheckIn ? checkIns : missions
            let secondPool = preferCheckIn ? missions : checkIns
            appendSeeded(from: firstPool, dayID: day.id, slot: slot, label: "first", seen: &seen, prompts: &prompts)
            if prompts.count >= count { break }
            appendSeeded(from: secondPool, dayID: day.id, slot: slot, label: "second", seen: &seen, prompts: &prompts)
            if prompts.count >= count { break }
        }

        for prompt in checkIns + missions where prompts.count < count && seen.insert(prompt.id).inserted {
            prompts.append(prompt)
        }
        return Array(prompts.prefix(count))
    }

    private static func checkIn(_ id: String, _ title: String, _ body: String, _ keepPrompt: String, _ tags: [String]) -> PromptWhisper {
        PromptWhisper(id: "checkin-\(id)", kind: .checkIn, title: title, body: body, keepPrompt: keepPrompt, tags: tags)
    }

    private static func appendSeeded(
        from pool: [PromptWhisper],
        dayID: String,
        slot: Int,
        label: String,
        seen: inout Set<String>,
        prompts: inout [PromptWhisper]
    ) {
        guard !pool.isEmpty else { return }
        let seed = abs("\(dayID)-\(slot)-prompt-whisper-\(label)".stableHash)
        for offset in 0..<pool.count {
            let candidate = pool[(seed + offset) % pool.count]
            if seen.insert(candidate.id).inserted {
                prompts.append(candidate)
                return
            }
        }
    }

    private static func rankedMissionWhispers(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [PromptWhisper] {
        let text = [
            inputs.weather?.phrase,
            inputs.body?.status,
            day.capturedPages.suffix(6).map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }.joined(separator: " ")
        ]
        .compactMap(\.self)
        .joined(separator: " ")
        .lowercased()

        var preferredTags: Set<String>
        if text.contains("rain") || text.contains("storm") || text.contains("fog") {
            preferredTags = ["weather", "sound", "scent", "inside"]
        } else if text.contains("low") || text.contains("tired") || text.contains("rest") {
            preferredTags = ["low-energy", "touch", "inside"]
        } else if text.contains("work") || text.contains("errand") || text.contains("store") {
            preferredTags = ["public", "visual", "errand"]
        } else {
            preferredTags = ["touch", "visual", "scent", "sound"]
        }

        let shadowActive = ShadowWonder.state(inputs: inputs, now: now).isActive
        if shadowActive {
            preferredTags.formUnion(["shadow-wonder", "shadow", "night", "history", "threshold", "old"])
        }

        // Scored once per mission, for the same reason as `rankedMissions`.
        return PlayfulMissionRegistry.missions
            .filter { shadowActive || !$0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
            .map { mission in
                (
                    mission: mission,
                    score: Set(mission.tags).intersection(preferredTags).count
                        + (shadowActive && ShadowWonder.prefers(mission: mission) ? 4 : 0)
                )
            }
            .sorted { left, right in
                if left.score == right.score {
                    return left.mission.id < right.mission.id
                }
                return left.score > right.score
            }
            .map { promptWhisper(from: $0.mission) }
    }
}

enum PromptWhisperKeep {
    static func page(for whisper: PromptWhisper, answer: String, now: Date) -> BookPage? {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let source = BookPageSourceRegistry.source(for: .souvenir)
        let tags = (["souvenir", "prompt-whisper", whisper.kind.rawValue, whisper.id] + whisper.tags)
            .reduce(into: [String]()) { result, tag in
                if !result.contains(tag) {
                    result.append(tag)
                }
            }
        return BookPage(
            type: .souvenir,
            createdAt: now,
            promptText: whisper.keepPrompt,
            userInput: trimmed,
            tags: tags,
            sourceID: source.id,
            origin: source.origin,
            privacy: source.privacy,
            promptVersion: "prompt-whisper-v1"
        )
    }
}

enum WonderCompassRunGenerator {
    static func seed(for day: BookDay, inputs: BookSourceInputs, progress: CompassRunProgress, now: Date = Date(), shadowVariant: Bool = false) -> WonderCompassRunSeed {
        let mode = mode(for: day, inputs: inputs, now: now)
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let useShadow = shadowVariant && shadowState.isActive
        let timeBox = timeBox(for: mode, inputs: inputs, now: now)
        let budget = mode == .budget ? "$0-$10" : "Use what is already available."
        let place = useShadow ? "shadow wonder: \(ShadowWonder.destination(inputs: inputs))" : place(for: mode, inputs: inputs)
        let energy = energy(for: mode, inputs: inputs)
        let companions = companions(for: day)
        let considerations = considerations(for: mode, inputs: inputs)
        let circumstance = circumstance(for: inputs, now: now)
        let spark = progress.latestSpark ?? (useShadow ? ShadowWonder.spark(inputs: inputs, now: now) : spark(for: mode, inputs: inputs, now: now))
        let destination = useShadow ? ShadowWonder.destination(inputs: inputs) : destination(for: mode, spark: spark, place: place)
        let delight = useShadow ? ShadowWonder.delight(inputs: inputs, now: now) : delight(for: mode, inputs: inputs, now: now)
        let definition = definition(for: mode, timeBox: timeBox)
        let mission = useShadow ? ShadowWonder.mission(inputs: inputs) : mission(for: mode, inputs: inputs)
        let souvenir = useShadow ? ShadowWonder.souvenirPrompt : souvenirPrompt(for: mode)
        let rest = restPrompt(for: inputs)
        let slot = SurfaceCadence.slotID(for: now, hours: 6)
        let shadowTags = useShadow ? ShadowWonder.tags(inputs: inputs, now: now) : []

        return WonderCompassRunSeed(
            id: "run-\(day.id)-\(slot)-\(mode.rawValue)\(useShadow ? "-shadow" : "")",
            mode: mode,
            timeBox: timeBox,
            budget: budget,
            place: place,
            energy: energy,
            companions: companions,
            considerations: considerations,
            circumstance: circumstance,
            spark: spark,
            destination: destination,
            delight: delight,
            definition: definition,
            mission: mission,
            souvenirPrompt: souvenir,
            restPrompt: rest,
            tags: ["wonder-compass", "wonder-compass-run", "concierge:\(mode.rawValue)"] + shadowTags
        )
    }

    private static func mode(for day: BookDay, inputs: BookSourceInputs, now: Date) -> WonderConciergeMode {
        let hour = Calendar.current.component(.hour, from: now)
        let capturedText = day.capturedPages.suffix(4).map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }.joined(separator: " ").lowercased()
        let bodyStatus = inputs.body?.status.lowercased() ?? ""
        if bodyStatus.contains("watch") || bodyStatus.contains("low") || capturedText.contains("tired") || capturedText.contains("rest") {
            return .recovery
        }
        if hour >= 19 || hour < 8 {
            return .closeToHome
        }
        if let weather = inputs.weather?.phrase.lowercased(),
           weather.contains("rain") || weather.contains("storm") || weather.contains("snow") || weather.contains("fog") {
            return .vibe
        }
        if capturedText.contains("cheap") || capturedText.contains("budget") || capturedText.contains("money") {
            return .budget
        }
        if capturedText.contains("weird") || capturedText.contains("old") || capturedText.contains("history") {
            return .obscure
        }
        if capturedText.contains("errand") || capturedText.contains("work") || capturedText.contains("store") {
            return .scavenger
        }
        return day.capturedPages.isEmpty ? .closeToHome : .vibe
    }

    private static func timeBox(for mode: WonderConciergeMode, inputs: BookSourceInputs, now: Date) -> String {
        switch mode {
        case .recovery:
            return "1-10 minutes"
        case .closeToHome:
            return "10-20 minutes"
        case .budget, .vibe, .scavenger:
            return "20-45 minutes"
        case .obscure:
            return "45-90 minutes"
        }
    }

    private static func place(for mode: WonderConciergeMode, inputs: BookSourceInputs) -> String {
        switch mode {
        case .closeToHome, .recovery:
            return "where the user already is"
        case .budget:
            return "nearby and cheap"
        case .obscure:
            return "within a reasonable local radius"
        case .vibe:
            if let weather = inputs.weather?.phrase {
                return "somewhere that fits this weather: \(weather)"
            }
            return "somewhere that fits the current mood"
        case .scavenger:
            return "the place the user already has to go"
        }
    }

    private static func energy(for mode: WonderConciergeMode, inputs: BookSourceInputs) -> String {
        if let body = inputs.body, body.isAvailable {
            return "\(body.status): \(body.phrase)"
        }
        switch mode {
        case .recovery:
            return "low; shrink the run"
        case .obscure:
            return "curious enough for a slightly larger loop"
        default:
            return "ordinary tired adult"
        }
    }

    private static func companions(for day: BookDay) -> String {
        let text = day.capturedPages.suffix(6).map { "\($0.promptText) \($0.userInput)" }.joined(separator: " ").lowercased()
        if text.contains("kid") || text.contains("child") || text.contains("children") {
            return "with kids"
        }
        if text.contains("partner") || text.contains("wife") || text.contains("husband") || text.contains("friend") {
            return "with someone trusted"
        }
        return "solo unless the user says otherwise"
    }

    private static func considerations(for mode: WonderConciergeMode, inputs: BookSourceInputs) -> String {
        var notes: [String] = []
        if mode == .recovery {
            notes.append("low energy")
        }
        if let weather = inputs.weather?.phrase.lowercased(),
           weather.contains("rain") || weather.contains("storm") || weather.contains("snow") || weather.contains("heat") {
            notes.append("weather-aware")
        }
        if inputs.body != nil {
            notes.append("body signals outrank the plan")
        }
        if notes.isEmpty {
            notes.append("no special constraints known")
        }
        return notes.joined(separator: ", ")
    }

    private static func circumstance(for inputs: BookSourceInputs, now: Date) -> String {
        var pieces: [String] = []
        if let weather = inputs.weather?.phrase {
            pieces.append("weather: \(weather)")
        }
        if let body = inputs.body?.phrase {
            pieces.append("body: \(body)")
        }
        let hour = Calendar.current.component(.hour, from: now)
        pieces.append(hour >= 18 ? "evening" : "daylight")
        return pieces.joined(separator: "; ")
    }

    private static func spark(for mode: WonderConciergeMode, inputs: BookSourceInputs, now: Date) -> String {
        WonderSparkRegistry.spark(for: mode, inputs: inputs, now: now)
    }

    private static func destination(for mode: WonderConciergeMode, spark: String, place: String) -> String {
        switch mode {
        case .closeToHome:
            return "one threshold nearby: a door, window, porch, kitchen table, or mailbox"
        case .budget:
            return "one free or cheap local stop tied to the spark"
        case .obscure:
            return "one odd sign, old building, marker, bridge, shop, or overlooked corner"
        case .vibe:
            return "one place or object that matches the mood"
        case .scavenger:
            return place
        case .recovery:
            return "the nearest chair, window, glass of water, blanket, or patch of light"
        }
    }

    private static func delight(for mode: WonderConciergeMode, inputs: BookSourceInputs, now: Date) -> String {
        switch mode {
        case .closeToHome:
            return "one song, warm drink, favorite hoodie, or good socks"
        case .budget:
            return "a cheap snack, road drink, playlist, or saved podcast"
        case .obscure:
            return "a camera-only phone, a playlist, and permission to leave if the place is dull"
        case .vibe:
            return "music, weather-appropriate clothes, or a drink that matches the atmosphere"
        case .scavenger:
            return "turn the errand into a game; the prize is the souvenir"
        case .recovery:
            return "comfort first: water, blanket, soft light, or silence"
        }
    }

    private static func definition(for mode: WonderConciergeMode, timeBox: String) -> String {
        switch mode {
        case .recovery:
            return "stop as soon as the body says stop"
        case .scavenger:
            return "finish after three finds or \(timeBox)"
        default:
            return "finish after \(timeBox)"
        }
    }

    private static func mission(for mode: WonderConciergeMode, inputs: BookSourceInputs) -> String {
        switch mode {
        case .closeToHome:
            return "Find the oldest, brightest, coldest, or most neglected thing within ten steps."
        case .budget:
            return "Find three details that make the cheap thing feel specific: smell, texture, sound."
        case .obscure:
            return "Photograph one overlooked detail and ask what story it is trying to keep."
        case .vibe:
            return "Compare the mood inside your body with the mood of the place. Name one match and one contrast."
        case .scavenger:
            return "Find five non-obvious things: a strange sign, a hidden color, an old date, a texture, and a tiny kindness."
        case .recovery:
            return "Feel one support: chair, floor, blanket, wall, breath. No improving."
        }
    }

    private static func souvenirPrompt(for mode: WonderConciergeMode) -> String {
        switch mode {
        case .recovery:
            return "Write proof of survival: I was here, and one thing held."
        default:
            return "Write one specific sensory sentence. Let the object do something if you can."
        }
    }

    private static func restPrompt(for inputs: BookSourceInputs) -> String {
        if inputs.body != nil {
            return "Take the 60-second reset or stop completely; body signals outrank the plan."
        }
        return "Put the phone face down for 60 seconds and let the run land."
    }

    static func body(for seed: WonderCompassRunSeed) -> String {
        """
        Answer the questions below. The Book will turn them into one custom Compass Run, then guide you through Notice, Embark, Sense, Write, and Rest one Page at a time.

        Location:
        Time limit:
        Energy:
        Who is with me:
        Budget:
        Special needs or considerations:
        """
    }
}

struct CharacterLetterPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .letter)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        if let prepared = inputs.preparedLetterSurface {
            return [prepared]
        }
        guard let draft = CharacterLetterPageGenerator.draftCandidate(for: day, inputs: inputs, now: now) else {
            return []
        }
        return [draft]
    }
}

struct StudentNotePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .note)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let draft = StudentNotePageGenerator.draftCandidate(for: day, inputs: inputs, now: now) else {
            return []
        }
        return [draft]
    }
}

// MARK: - Story forms and genres: the shapes stories arrive in.
//
// Expandable like every other content family: a bundled pack plus any
// *.storyforms.json dropped into Documents. The packet builder picks one
// form and one genre per page; continuations walk the form's beats.

struct StoryForm: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var directorNote: String
    var beats: [String]
}

enum StoryVignetteBeats {
    static let maximumInteractiveTurns = 2

    static func snackSized(_ beats: [String]) -> [String] {
        guard beats.count > maximumInteractiveTurns else { return beats }
        guard let first = beats.first, let last = beats.last else { return [] }
        return [first, last]
    }
}

enum StoryRecipeRequirement: String, Codable, Equatable {
    case groundedSource
    case character
    case secondCharacter
    case activeThread
    case keptPage
    case souvenirDoor
    case nothingPressure
    case activeWorldEvent
    case rivalryEdge
    case deepBond
    case outwardWake
    case chosenQuill
    /// Gated on who the Book named the reader. Recipes carrying this also set
    /// `requiredRoleIDs`; the requirement alone only asserts that a role exists.
    case readerRole
}

enum StoryRecipeSceneMode: String, Codable, Equatable {
    case conversation
    case balanced
    case action
    case environmental
}

enum StoryGroundingKind: String, Codable, Equatable {
    case keptPage
    case souvenirDoor
    case realSignal
    case entityMemory
    case timeAndSeason
}

struct StoryGrounding: Codable, Equatable {
    var kind: StoryGroundingKind
    var sourceID: String
    var text: String
    var selectionReason: String? = nil
    var semanticSimilarity: Double? = nil
}

struct StoryRecipeTurnTemplate: Codable, Equatable {
    var kind: StoryTurnKind
    var wantTemplate: String
    var obstacleTemplate: String
    var statementTemplate: String
    var sliceLandingTemplate: String
    var progressLandingTemplate: String
    var surpriseLandingTemplate: String
}

struct StoryRecipe: Identifiable, Codable, Equatable {
    /// World-led recipes stage the Labyrinth's own life: the reader's kept
    /// pages stay closed, and real-day grounding is atmosphere (weather, the
    /// hour) rather than the scene's subject. Marked with the `world-led`
    /// preferred tag so reader-imported packs can opt in without any schema
    /// change.
    static let worldLedTag = "world-led"
    var isWorldLed: Bool { preferredTags.contains(Self.worldLedTag) }

    var id: String
    var name: String
    var baseWeight: Int
    var requirements: [StoryRecipeRequirement]
    var sceneMode: StoryRecipeSceneMode
    var premiseTemplate: String
    var beats: [String]
    var turns: [StoryRecipeTurnTemplate]
    var characterPressure: StoryRecipeCharacterPressureTemplate? = nil
    var preferredTags: [String]
    var preferredFormIDs: [String]
    var preferredGenreIDs: [String]
    var excludedFormIDs: [String]
    var excludedGenreIDs: [String]
    var requiredEntityIDs: [String]
    var requiredEntityTags: [String]
    /// Role ids this recipe belongs to. Empty means any reader. A role recipe
    /// is the Book writing a scene only this kind of person would be handed:
    /// which is the payoff of naming them in the first place.
    var requiredRoleIDs: [String] = []
    var groundingDirective: String
    var toneDirective: String
    var choiceDirective: String
    var continuationDirective: String
    var cooldownHours: Int
    var suppressedByPageTypes: [BookPageType]
    var suppressionHours: Int
}

struct StorySceneBlueprint: Codable, Equatable {
    var recipeID: String
    var recipeName: String
    var recipePackID: String
    var sceneMode: StoryRecipeSceneMode
    var leadID: String
    var leadName: String
    var companionID: String?
    var companionName: String?
    var premise: String
    var grounding: StoryGrounding
    var beats: [String]
    var groundingDirective: String
    var toneDirective: String
    var choiceDirective: String
    var continuationDirective: String
    var turn: StoryTurn
    var dramaticContract: StoryDramaticContract? = nil
}

struct StoryGenre: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var lens: String
    var moodTags: [String]
    /// A short model passage in this genre's register, from no particular
    /// story. The local brain imitates a sample far more reliably than it
    /// follows rule lists, so the prompt shows this as voice, never content.
    var exemplar: String
    /// Concrete nouns in this genre's key. Used to seed scenes when the
    /// day supplies no real signal, so quiet days still get specific props.
    var palette: [String]

    init(id: String, name: String, lens: String, moodTags: [String], exemplar: String = "", palette: [String] = []) {
        self.id = id
        self.name = name
        self.lens = lens
        self.moodTags = moodTags
        self.exemplar = exemplar
        self.palette = palette
    }

    private enum CodingKeys: String, CodingKey { case id, name, lens, moodTags, exemplar, palette }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(String.self, forKey: .id)
        name = try box.decode(String.self, forKey: .name)
        lens = try box.decode(String.self, forKey: .lens)
        moodTags = try box.decodeIfPresent([String].self, forKey: .moodTags) ?? []
        exemplar = try box.decodeIfPresent(String.self, forKey: .exemplar) ?? ""
        palette = try box.decodeIfPresent([String].self, forKey: .palette) ?? []
    }
}

struct StoryFormPack: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var version: Int
    var author: String
    var availability: String
    var forms: [StoryForm]
    var genres: [StoryGenre]
    var recipes: [StoryRecipe] = []

    var isLocked: Bool { availability == "locked" }

    init(id: String, displayName: String, version: Int, author: String, availability: String, forms: [StoryForm], genres: [StoryGenre], recipes: [StoryRecipe] = []) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.author = author
        self.availability = availability
        self.forms = forms
        self.genres = genres
        self.recipes = recipes
    }

    private enum CodingKeys: String, CodingKey { case id, displayName, version, author, availability, forms, genres, recipes }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(String.self, forKey: .id)
        displayName = try box.decode(String.self, forKey: .displayName)
        version = try box.decode(Int.self, forKey: .version)
        author = try box.decode(String.self, forKey: .author)
        availability = try box.decode(String.self, forKey: .availability)
        forms = try box.decodeIfPresent([StoryForm].self, forKey: .forms) ?? []
        genres = try box.decodeIfPresent([StoryGenre].self, forKey: .genres) ?? []
        recipes = try box.decodeIfPresent([StoryRecipe].self, forKey: .recipes) ?? []
    }
}

enum StoryFormRegistry {
    static let userPackFileSuffix = ".storyforms.json"

    static let bundledPacks: [StoryFormPack] = [
        StoryFormPack(
            id: "core-story-forms",
            displayName: "Core Story Forms",
            version: 1,
            author: "The Book",
            availability: "bundledFree",
            forms: [
                StoryForm(
                    id: "threshold-crossing",
                    name: "The Threshold",
                    directorNote: "An ordinary boundary becomes a real one.",
                    beats: [
                        "Arrive: ground the scene in one real signal; everything is normal except one small thing asks to be crossed.",
                        "Settle: the chosen crossing leaves the new normal one shade different; name what came through the door."
                    ]
                ),
                StoryForm(
                    id: "small-mystery",
                    name: "The Small Mystery",
                    directorNote: "Something doesn't add up, at kitchen scale.",
                    beats: [
                        "Notice: one specific oddity, stated plainly, and let one possible answer fail.",
                        "Reveal: the chosen answer makes the mystery smaller but not gone; someone keeps a souvenir of it."
                    ]
                ),
                StoryForm(
                    id: "visitation",
                    name: "The Visitation",
                    directorNote: "Someone arrives mid-task with their own agenda.",
                    beats: [
                        "Interrupt: a character arrives while something real is half-done, needing something they do not name cleanly.",
                        "Residue: after the reader's answer, something changes hands or remains behind, physical and slightly wrong."
                    ]
                ),
                StoryForm(
                    id: "quiet-epic",
                    name: "The Quiet Epic",
                    directorNote: "Tiny stakes carried with mythic seriousness.",
                    beats: [
                        "The quest is declared: something domestic and small is treated as if kingdoms depend on it.",
                        "The modest triumph: the chosen response changes the small thing; the scale of feeling stays epic."
                    ]
                ),
                StoryForm(
                    id: "correspondence",
                    name: "The Correspondence",
                    directorNote: "The scene happens around a piece of writing.",
                    beats: [
                        "Found: a note, letter, label, or margin scrawl turns up where it should not be, asking more than it says.",
                        "Sealed: the chosen answer leaves by an odd route; what was unsaid stays behind, named."
                    ]
                ),
                StoryForm(
                    id: "nocturne",
                    name: "The Nocturne",
                    directorNote: "Night logic; Routine tests the edges.",
                    beats: [
                        "Lamp: the scene begins in low light as one precise detail starts to fray at the edge of attention.",
                        "Ledger: after the chosen response, what was kept is written down and what was lost is admitted."
                    ]
                )
            ],
            genres: [
                StoryGenre(id: "cozy-mystery", name: "Cozy Mystery", lens: "Warm rooms, sharp questions. Tea is involved. Suspicion lands on objects, never cruelty on people.", moodTags: ["rain", "evening", "quiet", "tea"],
                    exemplar: "\"Someone has moved the marmalade,\" Mrs. Quill said, setting down her cup. \"Third shelf. It lives on the second.\" Outside, rain worked at the gutter. \"Maybe it wanted a view,\" you offered. She looked at you the way detectives look at footprints: delighted, and not fooled at all.",
                    palette: ["teapot", "marmalade jar", "third shelf", "rain at the gutter", "index card", "spectacles", "toast crumbs", "doorbell"]),
                StoryGenre(id: "gentle-horror", name: "Gentle Horror", lens: "The hair-raising kept kind: wrongness in familiar things, dread that resolves into tenderness. The Rut's territory.", moodTags: ["night", "fog", "tired", "grey"],
                    exemplar: "The coat hook held its coat wrong. Not fallen: arranged, one sleeve folded across itself like an arm keeping something warm. \"Who folded you?\" you asked. Nothing answered, but the radiator ticked twice, the way a house does when it wants you to stay in the lit rooms.",
                    palette: ["coat hook", "radiator tick", "unlit hallway", "torch with a loose battery", "wallpaper seam", "your own breath", "stairwell", "spilled salt"]),
                StoryGenre(id: "screwball", name: "Screwball Comedy", lens: "Fast, fond, and slightly unhinged. Characters talk over each other. Objects misbehave with comic timing.", moodTags: ["bright", "morning", "energy"],
                    exemplar: "\"Don't open the: \" said Pim, as you opened the tin. \"tin.\" The moths were out now, all forty, wearing tiny paper price tags. \"They're not for sale!\" \"You priced them!\" \"They priced THEMSELVES.\" Below, the doorbell rang twice, in a tone that meant the tuba had also escaped.",
                    palette: ["biscuit tin", "paper price tags", "doorbell", "escaped tuba", "umbrella stand", "custard", "borrowed ladder", "a list titled DO NOT"]),
                StoryGenre(id: "field-naturalist", name: "Field Naturalist", lens: "Mary Oliver attention: exact observation, unforced wonder, the world examined like it matters because it does.", moodTags: ["walk", "outside", "weather", "calm"],
                    exemplar: "The snail had climbed exactly one brick since morning: a whole brick, mortar to mortar. You crouched. Its shell wore last night's rain in a spiral, oldest weather at the center. Nothing about it hurried, and still it was crossing a wall. You wrote the time down like a coordinate.",
                    palette: ["one brick", "snail shell spiral", "mortar line", "pencil stub", "field notebook", "dew", "hedge gap", "the exact time"]),
                StoryGenre(id: "tiny-heist", name: "Tiny Heist", lens: "A caper at household scale: reclaiming a teacup, liberating a parking spot. Planning montage energy, zero crime.", moodTags: ["energy", "afternoon", "mission"],
                    exemplar: "\"Vents are out,\" Odo whispered. \"Too dusty. We go past the biscuit tins at fourteen hundred, when the kettle screams and covers our noise.\" The teacup sat behind glass, guarded by an aunt with excellent hearing. You synchronized watches. Neither of you owned a watch. You synchronized anyway.",
                    palette: ["kettle scream", "glass cabinet", "cabinet key", "chalk mark", "floor plan on a napkin", "string", "the loud stair", "fourteen hundred hours"]),
                StoryGenre(id: "pastoral", name: "Pastoral", lens: "Slow gold light, work done with the hands, conversation that breathes. Time moves like weather.", moodTags: ["calm", "garden", "season", "rest"],
                    exemplar: "They shelled the beans without counting them, which is the correct way. \"My mother did this on a blue step,\" Tam said, thumb splitting a pod. \"Every August.\" The light came in low and buttered the table. There was more to say, and the beans left room for all of it.",
                    palette: ["bean pods", "blue step", "wooden bucket", "orchard ladder", "twine", "late light on the table", "August", "a held-back story"]),
                StoryGenre(id: "kindly-ghost", name: "Kindly Ghost Story", lens: "Someone or something lingers because it loved this place. Memory made gently visible. Never menacing.", moodTags: ["memory", "old", "evening", "anchor"],
                    exemplar: "The chair by the window was warm, though no one had sat there all day. On the sill, the pencil had rolled uphill again, back to where a left-handed person would want it. \"You can stay,\" you said. The curtain settled, the way a person settles when they've been told they're welcome.",
                    palette: ["warm chair", "windowsill pencil", "curtain", "photograph with a thumbprint", "teaspoon", "carved initials", "lamplight", "left-handed habits"]),
                StoryGenre(id: "serial-adventure", name: "Adventure Serial", lens: "Chapter-of-a-larger-tale energy: momentum, a cliff's edge of curiosity at the end, callbacks to earlier episodes.", moodTags: ["thread", "arc", "momentum"],
                    exemplar: "The map ended at the laundry room, which was exactly why Juno trusted it. \"Last chapter got us the key,\" she said, tapping the margin. \"This chapter is the lock.\" Behind the dryer, the wall wore a draft it had no business wearing. Somewhere a door was owed to you both.",
                    palette: ["hand-drawn map", "the key from before", "margin note", "draft behind the dryer", "knotted rope", "chapter number", "threshold", "a debt of doors"])
            ],
            recipes: coreRecipes
        ),
        StoryFormPack(
            id: "unquiet-folio",
            displayName: "The Unquiet Folio",
            version: 1,
            author: "The Book",
            availability: "bundledFree",
            forms: [],
            genres: [
                StoryGenre(id: "trickster-duel", name: "Trickster's Duel", lens: "Social pressure with a grin. The threat is being made to feel foolish for caring. Wit is the weapon and the wound.", moodTags: ["clash", "mischief", "audience"],
                    exemplar: "\"Nice page,\" Wicker said, not reading it. \"Very brave, keeping the sad ones.\" He let the silence do his work, then flicked a paper pellet at the inkwell. \"Relax. If I wanted it, it'd be gone. I'm here because someone's lying to you, and it's embarrassingly not me.\"",
                    palette: ["forged marginal note", "paper pellet", "inkwell", "borrowed grin", "the Stacks ladder", "a stolen title", "a dare", "an audience of two"]),
                StoryGenre(id: "grey-static", name: "Grey Static", lens: "The Rut of Routine edits, it does not attack: exact words go pale, lists become \"items\", days become \"fine\". Specificity is the counterspell.", moodTags: ["clash", "grey", "flattening"],
                    exemplar: "The list was still on the door, but someone had corrected it. Where it once said \"the good cup, the loud clock, Tuesday's moth,\" it now said \"items.\" Mara read it twice. \"Who signs their work 'fine'?\" she asked. The hallway light seemed suddenly very reasonable, very beige.",
                    palette: ["the word \"fine\"", "a corrected list", "beige light", "a missing adjective", "blank margin", "a title gone \"Untitled\"", "the good cup", "static hum"]),
                StoryGenre(id: "threshold-gothic", name: "Threshold Gothic", lens: "Borrowed rules and courteous danger: things that must ask permission, and the terrible weight of granting it. Invitation logic, old handwriting, the wrong side of the glass.", moodTags: ["clash", "threshold", "invitation"],
                    exemplar: "The letter arrived under the window, not the door: folded once and cold to the touch. \"It requests permission,\" Odile said, not touching it. \"Twice, politely.\" Below the signature, in older handwriting: MAY I COME IN. The latch, which had never mattered before, mattered enormously now.",
                    palette: ["window latch", "an invitation with no stamp", "cold envelope", "older handwriting", "permission asked twice", "the wrong side of the glass", "salt on the sill", "a rule that followed you home"])
            ],
            recipes: unquietFolioRecipes
        )
    ]

    static let unquietFolioRecipes: [StoryRecipe] = [
        recipe("grey-edit", "The Grey Edit", weight: 14, requirements: [.keptPage], mode: .balanced,
            premise: "The Rut of Routine has edited the kept page inside {{thread}}: the exact words of {{grounding}} have gone pale, corrected to \"fine.\"",
            beats: ["Show the kept page with its specific words flattened to filler while {{lead}} names what is missing.", "After the chosen response, the true words return, partly return, or their first-stolen word is learned, and the grey's editing rule gets written down."],
            turn: turn(.factLearned, want: "to learn which exact word the grey took first from {{grounding}}", obstacle: "the flattened sentence reads as almost true, which is how it hides", statement: "By the end, at least one exact word has been restored or the grey's editing rule has been named.", slice: "One small true detail is read aloud and refuses to stay grey.", progress: "The restored word points at where the grey nests inside {{thread}}.", surprise: "The edit was practice: the grey is drafting toward a page that has not been written yet."),
            tags: ["clash", "grey", "nothing", "evidence", "words"], forms: ["small-mystery", "nocturne"], genres: ["grey-static", "gentle-horror"],
            grounding: "Quote or nearly quote the kept material's own concrete words as the thing being erased and restored; the whole fight is over exact wording.",
            tone: "Dread at kitchen scale, then defiance. Specificity is the weapon; the scene itself must never go vague.",
            choices: "Offer restoring one exact detail, spending Belief to reject the whole edit, or asking me which word vanished first.",
            continuation: "The restored words stay restored. Escalate to the grey's source or its next target; never re-flatten the same page."),
        recipe("wicker-marks-the-page", "Wicker Marks the Page", weight: 14, requirements: [.keptPage], mode: .conversation,
            premise: "Wicker Eddies has forged a marginal note on the kept page in {{thread}} ({{grounding}}) and stayed to watch it land.",
            beats: ["{{lead}} defends the page while Wicker performs innocence, the forged note doing its small cruel work.", "After the chosen response, the forgery burns off, buys Wicker leverage, or exposes what he actually came for."],
            turn: turn(.revealWant, want: "to make the reader doubt that {{grounding}} deserved keeping", obstacle: "the page's specific words are truer than his joke, and he knows it", statement: "By the end, the forged note is exposed, overwritten, or traded, and Wicker's real errand shows one honest edge.", slice: "The reader's own words outlast the joke, read aloud once, plainly.", progress: "The forgery peels up, and what Wicker was covering moves {{thread}} one step.", surprise: "The note is in Wicker's hand, but the idea belonged to someone else."),
            tags: ["clash", "wicker", "forgery", "margins"], forms: ["correspondence", "visitation"], genres: ["trickster-duel", "cozy-mystery"],
            grounding: "The forged note mocks the kept material's exact content; quote the page's real words against Wicker's fake ones.",
            tone: "Social pressure, not menace: the threat is being made to feel foolish for caring. Wicker is funny, quick, and wrong.",
            choices: "Offer naming the forgery with evidence, writing over him with better mischief, or sealing the true page at a visible cost.",
            continuation: "Wicker keeps whatever he won and remembers whatever he lost. Move to consequence or counter-move; do not replay the forgery."),
        recipe("rivals-tether", "The Rival's Tether", weight: 12, requirements: [.character, .secondCharacter, .rivalryEdge], mode: .conversation,
            premise: "{{lead}} and {{companion}} have let a tension knot pull tight inside {{thread}}, and {{grounding}} just became the rope.",
            beats: ["The two collide over the concrete material mid-scene: each certain, neither cruel, the reader between them.", "After the chosen response, the knot loosens, tightens honestly, or reveals what the rivalry has been protecting."],
            turn: turn(.relationshipShift, want: "to be taken seriously about what {{grounding}} means", obstacle: "{{companion}} read the same evidence and reached the opposite conviction", statement: "By the end, the rivalry has been named to its face, and one of them has conceded one exact inch.", slice: "One ordinary detail both rivals agree on, grudgingly, out loud.", progress: "The concession (small, specific) moves {{thread}} one honest step.", surprise: "The rivalry is a guard dog: what it protects finally shows itself."),
            tags: ["clash", "rivalry", "tension", "cast"], forms: ["visitation", "quiet-epic"], genres: ["trickster-duel", "serial-adventure"],
            grounding: "Both rivals argue from the same concrete material; the disagreement is conviction, never facts.",
            tone: "Friction that sharpens instead of wounds. Fast exchanges, real stakes, no cruelty.",
            choices: "Offer siding with one rival on evidence, forcing both to defend the same detail, or naming what the quarrel protects.",
            continuation: "The concession holds. Warmth or tension moves visibly; never reset both rivals to their opening positions."),
        recipe("counterfeit-invitation", "The Counterfeit Invitation", weight: 12, requirements: [.groundedSource, .character], mode: .conversation,
            premise: "An invitation reaches the reader inside {{thread}}, signed by a friend, but {{grounding}} says the hand is wrong.",
            beats: ["The invitation performs warmth while one concrete detail from the real material refuses to corroborate it.", "After the chosen response, the forgery is unmasked, accepted on the reader's own terms, or audited into a stranger truth."],
            turn: turn(.factLearned, want: "to find out who is wearing a friend's handwriting", obstacle: "refusing outright would insult the real friend if the letter is genuine", statement: "By the end, the invitation's true sender has been tested, and trust lands somewhere exact.", slice: "One verifying question only the real sender could answer, asked casually.", progress: "The unmasked scheme points one step deeper into {{thread}}.", surprise: "The invitation is genuine, and that is somehow worse."),
            tags: ["clash", "letters", "trust", "forgery"], forms: ["correspondence", "small-mystery"], genres: ["threshold-gothic", "trickster-duel"],
            grounding: "One concrete detail from the material is the tell that exposes or verifies the invitation.",
            tone: "Social suspense: trust as a wager. Courteous surface, sharp undertow.",
            choices: "Offer following it openly, asking one verifying question, or having the ink audited by someone exact.",
            continuation: "The verdict on the sender stands. Follow the consequence of trusting or refusing; never re-litigate the same letter."),
    ]

    private static func recipe(
        _ id: String, _ name: String, weight: Int = 10,
        requirements: [StoryRecipeRequirement], mode: StoryRecipeSceneMode,
        premise: String, beats: [String], turn: StoryRecipeTurnTemplate,
        tags: [String] = [], forms: [String] = [], genres: [String] = [],
        grounding: String, tone: String, choices: String, continuation: String,
        cooldown: Int = 18, suppressedBy: [BookPageType] = [], suppressionHours: Int = 0,
        roles: [String] = []
    ) -> StoryRecipe {
        let characterPressure = StoryRecipeCharacterPressureTemplate(
            leadCharacterWorryTemplate: "{{lead}} worries that {{turnObstacle}}, and that asking plainly will prove the worry right.",
            leadCharacterBlindSpotTemplate: "{{lead}} believes {{leadBelief}}, but {{leadFault}} may be distorting what {{companion}} actually means.",
            otherCharacterPressureTemplate: "{{companion}} wants {{companionGoal}}; {{companionBelief}}. {{relationshipPressure}}",
            relationshipQuestionTemplate: "Will {{companion}} answer {{lead}}'s want honestly enough to change what they believe about each other?",
            stakesTemplate: "If nobody answers the want, {{turnObstacle}} remains the relationship's working truth.",
            requiredCharacterReactionTemplate: "answer the pressure created by {{turnWant}}",
            readerChoiceEffectTemplate: "forces the relationship question to receive a different answer"
        )
        return StoryRecipe(
            id: id, name: name, baseWeight: weight, requirements: requirements, sceneMode: mode,
            premiseTemplate: premise, beats: beats, turns: [turn], characterPressure: characterPressure, preferredTags: tags,
            preferredFormIDs: forms, preferredGenreIDs: genres, excludedFormIDs: [], excludedGenreIDs: [],
            requiredEntityIDs: [], requiredEntityTags: [], requiredRoleIDs: roles, groundingDirective: grounding,
            toneDirective: tone, choiceDirective: choices, continuationDirective: continuation,
            cooldownHours: cooldown, suppressedByPageTypes: suppressedBy, suppressionHours: suppressionHours
        )
    }

    private static func turn(
        _ kind: StoryTurnKind, want: String, obstacle: String, statement: String,
        slice: String, progress: String, surprise: String
    ) -> StoryRecipeTurnTemplate {
        StoryRecipeTurnTemplate(kind: kind, wantTemplate: want, obstacleTemplate: obstacle,
            statementTemplate: statement, sliceLandingTemplate: slice,
            progressLandingTemplate: progress, surpriseLandingTemplate: surprise)
    }

    static let coreRecipes: [StoryRecipe] = [
        recipe("souvenir-door", "A Sentence Opens", weight: 22, requirements: [.souvenirDoor], mode: .environmental,
            premise: "A kept One-Sentence Souvenir opens a tiny door inside {{thread}}: {{grounding}}",
            beats: ["Let the sentence behave as world physics, not as a quoted journal line; one image from it should become touchable.", "After the chosen response, the sentence is read, entered, folded, or saved with one small lasting mark."],
            turn: turn(.smallDecision, want: "to decide how the sentence-door made by {{grounding}} should be treated", obstacle: "the door will flatten if anyone explains it instead of meeting it", statement: "By the end, the kept sentence has opened, changed, or been protected as a tiny scene.", slice: "The reader lets the sentence stay small and luminous.", progress: "The sentence becomes evidence that moves {{thread}} one quiet step.", surprise: "The sentence was already a door for someone else."),
            tags: ["story-spark", "souvenir", "door", "threshold", "memory"], forms: ["threshold-crossing", "small-mystery", "correspondence"], genres: ["cozy-mystery", "field-naturalist", "kindly-ghost"],
            grounding: "Transform the exact Souvenir image into fictional physics. Do not say 'you wrote about...' or explain the meaning. Include one short phrase or concrete image from the sentence, and make it act.",
            tone: "Tiny, magical, reverent, and specific. The effect should feel earned by noticing, not generated as spectacle.",
            choices: "Offer three concrete options in this emotional grammar: read or tend what the sentence underlined; step through or investigate the door it opened; fold, share, or save the shimmer without forcing it.",
            continuation: "Mark the source sentence as having opened something. Future callbacks may treat it as a remembered doorway, not a reusable prompt."),
        recipe("dorm-room-visit", "Dorm-Room Visit", weight: 5, requirements: [.groundedSource, .character], mode: .conversation,
            premise: "{{lead}} visits your dorm because {{grounding}} has given them a concrete reason to knock.",
            beats: ["The knock interrupts an ordinary moment and {{lead}} names the exact reason for the visit.", "After the reader's answer, the visit leaves a small residue behind and {{grounding}} means something new."],
            turn: turn(.revealWant, want: "to ask the reader one careful question about {{grounding}}", obstacle: "{{lead}} has brought the wrong opening line and knows it", statement: "By the end, {{lead}} has said or learned one specific thing about {{grounding}}.", slice: "The visit becomes easy company, and {{lead}} stays a little longer.", progress: "What {{lead}} says moves {{thread}} one honest step.", surprise: "The real reason for the visit is stranger and kinder than it first appeared."),
            tags: ["daily", "care", "rest"], forms: ["visitation"], genres: ["pastoral", "kindly-ghost"],
            grounding: "Use the grounded detail as the visitor's real pretext, not decorative flavor.", tone: "Intimate and unhurried; disagreement is optional and usually absent.", choices: "Offer ways to ask, share, invite, joke, or let the moment rest.", continuation: "Let the visit deepen or end; do not manufacture a quarrel."),
        recipe("misdelivered-object", "Misdelivered Object", requirements: [.groundedSource], mode: .balanced,
            premise: "A small item tied to {{grounding}} arrives in the wrong place and insists it belongs to {{thread}}.",
            beats: ["Show the object, its wrong address, and the first practical problem it creates.", "After the chosen response, the object is kept, returned, opened, or proven to have chosen its destination."],
            turn: turn(.handOff, want: "to find where the misdelivered part of {{grounding}} belongs", obstacle: "every label on it names a different owner", statement: "By the end, the misdelivered thing is kept, returned, opened, or reassigned with consequences.", slice: "The reader studies one ordinary mark on the item before deciding.", progress: "The corrected delivery moves {{thread}} one visible step.", surprise: "The item was not misdelivered; it was avoiding its intended recipient."),
            tags: ["objects", "daily", "letters"], forms: ["correspondence", "small-mystery"], genres: ["cozy-mystery", "field-naturalist"],
            grounding: "Make the grounded detail physically legible on the object: a mark, smell, label, crease, stain, sound, or note.", tone: "Curious and practical; let the problem be small enough to handle.", choices: "Offer inspecting, returning, opening, refusing, trading, or asking the named owner.", continuation: "Follow the object's consequence; do not send the same item to another wrong address."),
        recipe("tiny-heist", "Tiny Heist", requirements: [.groundedSource, .character, .activeThread], mode: .action,
            premise: "{{lead}} proposes a tiny harmless caper using {{grounding}} to retrieve, swap, hide, or protect one thing in {{thread}}.",
            beats: ["State the caper and the ridiculous constraint that makes it hard.", "After the chosen response, the plan succeeds, fails neatly, or reveals a better target."],
            turn: turn(.smallDecision, want: "to pull off one harmless precise maneuver involving {{grounding}}", obstacle: "the plan depends on timing nobody quite controls", statement: "By the end, the caper has succeeded, failed neatly, or changed targets.", slice: "The reader handles the smallest part of the plan with care.", progress: "The maneuver changes where {{thread}} can go next.", surprise: "The wrong target turns out to be the right one."),
            tags: ["mission", "energy", "objects"], forms: ["quiet-epic", "threshold-crossing"], genres: ["tiny-heist", "serial-adventure"],
            grounding: "Make the grounded detail necessary to the caper, not merely present.", tone: "Quick, playful, competent, and bounded; no real crime, no real-world assignment.", choices: "Offer planning, acting, aborting, improvising, distracting, hiding, swapping, or protecting.", continuation: "Show the plan's consequence in motion; never reset to planning."),
        recipe("false-alarm", "False Alarm", requirements: [.groundedSource], mode: .environmental,
            premise: "{{grounding}} trips an alarm inside {{thread}}, but the warning is almost certainly wrong.",
            beats: ["Let the alarm interrupt one ordinary action and show the evidence that argues against panic.", "After the chosen response, the alarm is silenced, obeyed, repurposed, or revealed to warn about something smaller."],
            turn: turn(.factLearned, want: "to learn what {{grounding}} is actually warning about", obstacle: "the loudest signal is pointing at the wrong danger", statement: "By the end, the warning has been silenced, obeyed, repurposed, or corrected.", slice: "The reader notices the small harmless clue underneath the noise.", progress: "The corrected warning points directly into {{thread}}.", surprise: "The alarm is not warning anyone; it is asking to be noticed."),
            tags: ["weather", "body", "grey", "evidence"], forms: ["small-mystery", "nocturne"], genres: ["gentle-horror", "cozy-mystery"],
            grounding: "Let the grounded detail cause the warning and also contain the evidence that revises it.", tone: "Tense for a breath, then lucid and humane.", choices: "Offer checking, silencing, following, naming, sheltering, or refusing the false urgency.", continuation: "Advance from the corrected warning; do not ring the same alarm again."),
        recipe("field-test", "Field Test", requirements: [.groundedSource, .character], mode: .action,
            premise: "{{lead}} needs to test a small theory about {{grounding}} before trusting it inside {{thread}}.",
            beats: ["Name the theory and the tiny safe test that could disprove it.", "After the chosen response, the test produces a partial result that changes the next question."],
            turn: turn(.factLearned, want: "to test whether {{grounding}} behaves the way {{lead}} suspects", obstacle: "the first result can be read two ways", statement: "By the end, the test has produced one partial result that changes the next question.", slice: "The reader records the smallest observable result.", progress: "The result gives {{thread}} a usable fact.", surprise: "The test answers a different question than the one {{lead}} asked."),
            tags: ["wonder", "research", "objects"], forms: ["small-mystery", "threshold-crossing"], genres: ["field-naturalist", "cozy-mystery"],
            grounding: "Make the test safe, fictional, bounded, and based on observable features of the grounded detail.", tone: "Investigative and exact, with room for a small laugh.", choices: "Offer measuring, comparing, repeating, stopping, asking, or changing the test.", continuation: "Move to a new question created by the result; do not retest the same claim."),
        recipe("nothing-library-corner", "Nothing in the Library Corner", requirements: [.groundedSource, .nothingPressure], mode: .environmental,
            premise: "In a library corner, Routine begins erasing one precise part of {{grounding}} while the reader is close enough to intervene.",
            beats: ["Show the first exact absence and make the reader's available responses materially different.", "After the chosen response, leave one protected detail or admitted loss."],
            turn: turn(.smallDecision, want: "to keep {{grounding}} from being flattened by Routine", obstacle: "the erasure advances whenever nobody names what is actually there", statement: "By the end, one exact part of {{grounding}} is protected, changed, or honestly lost.", slice: "The reader protects one modest detail and lets the rest wait.", progress: "The defense exposes how Routine is entering {{thread}}.", surprise: "What looked erased has moved somewhere unexpected instead."),
            tags: ["grey", "night", "quiet"], forms: ["nocturne", "small-mystery"], genres: ["gentle-horror"],
            grounding: "Name exactly what is greying or vanishing.", tone: "Eerie but humane; the environment is allowed to act.", choices: "Offer concrete ways to name, shelter, move, trade for, or release the threatened detail.", continuation: "The Rut of Routine may act again; advance the physical consequence rather than forcing dialogue."),
        recipe("small-discovery", "Small Discovery", requirements: [.groundedSource], mode: .balanced,
            premise: "A small inconsistency in {{grounding}} becomes a clue inside {{thread}}.",
            beats: ["State the oddity plainly and test it with one action or question.", "After the chosen response, reveal a useful partial answer that alters what can happen next."],
            turn: turn(.factLearned, want: "to understand why {{grounding}} does not quite add up", obstacle: "the first explanation is tidy but wrong", statement: "By the end, a concrete fact about {{grounding}} recolors {{thread}}.", slice: "The reader keeps the discovery small and learns what it means nearby.", progress: "The clue points directly into {{thread}}.", surprise: "The clue belongs to someone or something nobody suspected."),
            tags: ["wonder", "objects", "evidence"], forms: ["small-mystery"], genres: ["cozy-mystery", "field-naturalist"],
            grounding: "The clue must be an observable feature of the grounded detail.", tone: "Curious, lucid, and specific rather than ominously vague.", choices: "Offer investigation, disclosure, preservation, or a plausible sideways test.", continuation: "Advance to a new clue or consequence; never rediscover the same oddity."),
        recipe("odd-favor", "Odd Favor", requirements: [.groundedSource, .character, .activeThread], mode: .action,
            premise: "{{lead}} asks the reader for one bounded fictional favor involving {{grounding}} and {{thread}}.",
            beats: ["State the favor in concrete terms and show why {{lead}} cannot simply do it alone.", "After the chosen response, the favor is accepted, revised, refused, or handed elsewhere with clear consequences."],
            turn: turn(.handOff, want: "the reader's help with a specific fictional task involving {{grounding}}", obstacle: "{{lead}} has omitted one inconvenient part of the favor", statement: "By the end, the favor is accepted, changed, refused, or handed elsewhere with clear consequences.", slice: "The reader helps only with the small immediate part.", progress: "The favor moves {{thread}} through a visible action.", surprise: "The reader rewrites who the favor is really for."),
            tags: ["mission", "momentum"], forms: ["quiet-epic", "threshold-crossing"], genres: ["tiny-heist", "serial-adventure"],
            grounding: "Make the grounded detail necessary to the fictional favor.", tone: "Playful and bounded, never a real-world assignment falsely marked complete.", choices: "Offer help, renegotiation, refusal, delegation, or an inventive fictional method.", continuation: "Show the favor's consequence in action; do not repeat the request."),
        recipe("shared-quiet", "Shared Quiet", requirements: [.groundedSource, .character], mode: .balanced,
            premise: "{{lead}} shares an ordinary quiet activity with the reader while {{grounding}} sits naturally between them.",
            beats: ["Begin with the activity already underway and let one exact detail earn attention.", "After the chosen response, end with companionship or noticing changed by one notch."],
            turn: turn(.realNoticing, want: "to spend unforced time with the reader around {{grounding}}", obstacle: "the moment will flatten if either person tries to make it profound", statement: "By the end, {{lead}} and the reader have noticed or understood one small true thing together.", slice: "They keep doing the ordinary thing, now with a private shared detail.", progress: "The noticing gives {{thread}} a quiet new fact.", surprise: "A sideways joke or observation changes how the moment is remembered."),
            tags: ["rest", "care", "quiet"], forms: ["quiet-epic", "correspondence"], genres: ["pastoral", "field-naturalist"],
            grounding: "Let the detail participate in the shared activity without becoming a symbol lecture.", tone: "Warm, low-pressure, and comfortable with silence.", choices: "Offer small actions, honest noticing, a question, a joke, or simply staying.", continuation: "Keep the pressure low; deepen attention instead of inventing conflict."),
        recipe("trade-at-the-margin", "Trade at the Margin", requirements: [.groundedSource, .character], mode: .balanced,
            premise: "{{lead}} offers a small exchange at the edge of {{thread}}: one favor, fact, token, or permission for one piece of {{grounding}}.",
            beats: ["State the offered trade and what makes it tempting but not free.", "After the chosen response, the bargain is accepted, refused, revised, or paid by someone unexpected."],
            turn: turn(.handOff, want: "to trade for one specific part of {{grounding}}", obstacle: "the price is small but not meaningless", statement: "By the end, the trade is accepted, refused, revised, or paid by someone unexpected.", slice: "The reader asks what the small price actually is.", progress: "The exchange moves {{thread}} through a real transfer.", surprise: "Someone else pays the price before the reader can answer."),
            tags: ["daily", "faction", "objects"], forms: ["threshold-crossing", "correspondence"], genres: ["cozy-mystery", "serial-adventure"],
            grounding: "Make the grounded detail the thing traded for, traded with, or used to set the price.", tone: "Courteous, exact, and faintly dangerous without becoming a formal fae bargain.", choices: "Offer accepting, refusing, revising terms, naming the cost, or redirecting the payment.", continuation: "Honor the trade's price or refusal; do not offer the same bargain again."),
        recipe("concrete-disagreement", "Concrete Disagreement", weight: 7, requirements: [.groundedSource, .character, .secondCharacter], mode: .conversation,
            premise: "{{lead}} and {{companion}} disagree about one concrete consequence of {{grounding}}, not about vague principles.",
            beats: ["Both characters name the same evidence and give distinct fair interpretations.", "After the chosen intervention, the practical consequence becomes clear and changes what they will do next."],
            turn: turn(.relationshipShift, want: "{{companion}} to accept {{lead}}'s reading of {{grounding}}", obstacle: "{{companion}} sees the same evidence and reaches a different practical conclusion", statement: "By the end, the disagreement about {{grounding}} changes what {{lead}} and {{companion}} will do next.", slice: "The reader finds the small point both can live with.", progress: "One reading wins enough ground to move {{thread}}.", surprise: "The reader names a third reading that changes the dispute."),
            tags: ["tension", "evidence"], forms: ["small-mystery"], genres: ["cozy-mystery"],
            grounding: "Repeat the exact named evidence both characters are interpreting.", tone: "Fair, concrete, and practical; never generic bickering.", choices: "Offer siding, reframing, asking for evidence, or declining to judge.", continuation: "Show what the disagreement changes; do not merely restate both positions.", suppressedBy: [.twoReadings], suppressionHours: 72),
        // The chosen register: these three run on long cooldowns and (for the
        // Entrusting) a deep-bond gate, so being picked stays rare enough to
        // feel like election rather than content.
        recipe("the-entrusting", "The Entrusting", weight: 16, requirements: [.character, .deepBond, .outwardWake], mode: .conversation,
            premise: "{{lead}} has carried something private into {{thread}} and has decided the reader (no one else) is the person to hold it; {{grounding}} is why tonight is the night.",
            beats: ["{{lead}} circles the confidence once, testing the room, then says the private thing plainly and does not take it back.", "After the chosen response, the secret has a keeper: what {{lead}} entrusted sits differently between them, named and safe."],
            turn: turn(.revealWant, want: "to give the reader the one thing {{lead}} has never said aloud to anyone", obstacle: "saying it plainly means it can never go back to being unsaid", statement: "By the end, {{lead}} has entrusted one specific private thing, and the reader's keeping of it is visible.", slice: "The secret is received without being made larger; {{lead}} stays for the quiet after.", progress: "The entrusted thing turns out to touch {{thread}} and changes what {{lead}} will risk next.", surprise: "{{lead}} chose the reader long ago and has been waiting for a day that proved it."),
            tags: ["care", "trust", "memory", "quiet"], forms: ["visitation", "quiet-epic"], genres: ["pastoral", "kindly-ghost"],
            grounding: "Let the grounded detail be the reason the confidence is possible today. The reader's real history with {{lead}} is why they were chosen: let that show in specifics, never in flattery.",
            tone: "Hushed, deliberate, and certain. {{lead}} is not fragile; being chosen to hold this is an honor conferred, not a burden dumped.",
            choices: "Offer receiving it plainly, asking the one careful question, or making a small answering confidence, never refusing the trust itself.",
            continuation: "The secret stays told and stays safe. {{lead}} may touch it obliquely with warmth; never re-tell it or spend it as plot currency.",
            cooldown: 240),
        recipe("the-summons", "The Summons", weight: 15, requirements: [.groundedSource, .character, .activeThread, .outwardWake], mode: .balanced,
            premise: "Word travels through {{thread}} that something can only be done by the reader (not anyone brave, not anyone clever, specifically them) and {{lead}} has been sent to say so, because of {{grounding}}.",
            beats: ["{{lead}} delivers the summons and names the exact, reader-specific reason the world asked for them and no one else.", "After the chosen response, the world visibly registers that its reader answered (or named their own hour) and holds the door."],
            turn: turn(.handOff, want: "to bring the reader to the one small task the world reserved for them", obstacle: "the summons cannot explain itself fully until it is accepted; some of it runs on trust", statement: "By the end, the summons is answered, deferred on the reader's own terms, or answered sideways, and the reserved task remains theirs alone.", slice: "The reader accepts only the first step, and the world treats even that as arrival.", progress: "Answering opens the reserved door and moves {{thread}} one committed step.", surprise: "The task was never the point; the world wanted to know whether its choice of reader was right, and it was."),
            tags: ["mission", "thread", "arc", "momentum"], forms: ["threshold-crossing", "quiet-epic"], genres: ["serial-adventure", "kindly-ghost"],
            grounding: "Build the reader-specific reason from the grounded detail (something they actually did, kept, or noticed), never from generic flattery about destiny.",
            tone: "Ceremonial at kitchen scale: the world is formally asking, and it is allowed to feel good to be asked. No dread, and no guilt if she names her own hour.",
            choices: "Offer answering now, naming their own hour, or asking why them: the summons survives all three.",
            continuation: "The world remembers she answered. Advance the reserved task's consequence; never re-issue the same summons or withdraw the choosing.",
            cooldown: 336),
        recipe("the-readers-mark", "The Reader's Mark", weight: 13, requirements: [.keptPage, .outwardWake], mode: .environmental,
            premise: "Somewhere in {{thread}}, the world has quietly rebuilt itself around something the reader kept: {{grounding}} has left a mark that was not there before.",
            beats: ["Show the mark first: a change in the place itself, physical and legible, that could only have come from the kept material.", "After the chosen response, the mark stays: the world keeps the change, and the reader knows the place is different because of them."],
            turn: turn(.realNoticing, want: "to notice how {{grounding}} has reshaped one corner of the world", obstacle: "the change is modest and easy to walk past, the way real influence is", statement: "By the end, the reader has seen one physical proof that their kept words altered the world, and the alteration holds.", slice: "The reader visits the changed corner and lets it stay small and theirs.", progress: "The mark turns out to be load-bearing: {{thread}} now routes through what the reader changed.", surprise: "Someone else has found the mark and been helped by it, never knowing whose keeping made it."),
            tags: ["memory", "wonder", "quiet", "evidence"], forms: ["small-mystery", "correspondence"], genres: ["kindly-ghost", "field-naturalist"],
            grounding: "Quote or nearly quote the kept page's concrete words as the physical shape of the mark; the reader must recognize their own hand in the change.",
            tone: "Quiet astonishment, no fanfare: the world did not announce this, it simply kept what she gave it.",
            choices: "Offer visiting the mark, adding one small thing to it, or leaving it exactly as the world made it.",
            continuation: "The mark is permanent world-fact now. Later scenes may pass it with recognition; never undo it or re-discover it.",
            cooldown: 192),
        // World-led vignettes: the Labyrinth running its own life. The reader's
        // kept pages stay closed (grounding is atmosphere, never subject) and
        // the choices are three genuinely different plans, not three flavors of
        // noticing. These exist so Story Pages aren't always about her diary.
        recipe("unshelved-expedition", "Expedition to the Unshelved", weight: 15, requirements: [.character], mode: .action,
            premise: "{{lead}} has a hand-drawn map that stops mattering halfway and a plan to reach the Unshelved tonight (the far shelf where books wait that no one has written yet) with the reader as second lantern.",
            beats: ["Set out: the route is physical (a ladder, a gap, a cold draft) and one rule of the Stacks must be obeyed or ducked before the halfway mark.", "After the chosen response, the expedition reaches something real (a find, a toll, or a closed door with tomorrow's handhold) and comes home changed."],
            turn: turn(.smallDecision, want: "to reach the Unshelved and come back with proof", obstacle: "the Stacks quietly rearrange for travelers who look too confident", statement: "By the end, the expedition has won a find, paid a toll, or mapped a new handhold, and the way back is not the way in.", slice: "The expedition stops halfway and eats, on a shelf where no one has ever eaten.", progress: "The proof carried back gives {{thread}} one new rung.", surprise: "Something in the Unshelved was expecting visitors, and had set out tea."),
            tags: ["world-led", "adventure", "mission", "energy", "night"], forms: ["threshold-crossing", "quiet-epic"], genres: ["serial-adventure", "tiny-heist"],
            grounding: "The real-day detail is atmosphere only: the hour, the weather at the high windows. Never quote, discuss, or build the plot from the reader's pages or day.",
            tone: "Expedition energy at library scale: torchlit, competent, a little giddy. Danger is real but courteous.",
            choices: "Offer the bold route, the clever route, and the kind one: three different plans with three different costs, never three flavors of caution.",
            continuation: "The map grows by exactly what was earned. Advance from the find or the toll; never restart the same climb."),
        recipe("loose-in-the-quillquarium", "Loose in the Quillquarium", weight: 14, requirements: [.character], mode: .action,
            premise: "Something is loose in the Quillquarium: a predatory quill off its tether, fast, offended, and heading for the door {{lead}} forgot to close.",
            beats: ["The chase is on: concrete obstacles, ridiculous physics, and the one iron rule, never grab a quill by the nib.", "After the chosen response, the quill is caught, bargained down, or escapes gloriously, and the Quillquarium updates its opinion of everyone involved."],
            turn: turn(.smallDecision, want: "to get the quill back on its tether before the curfew bell", obstacle: "the quill is faster than everyone and knows it", statement: "By the end, the loose quill has been caught, talked down, or lost with style, and the room's rules are one line longer.", slice: "The chase ends in undignified, satisfied breathlessness, no harm done.", progress: "What the quill was actually after gives {{thread}} its next step.", surprise: "The quill was not escaping. It was delivering itself to someone."),
            tags: ["world-led", "adventure", "energy", "mischief"], forms: ["quiet-epic", "visitation"], genres: ["screwball", "serial-adventure"],
            grounding: "Real-day detail tints light and hour only. The scene's engine is the chase, not the reader's day; never mention their pages.",
            tone: "Fast, fond, and slightly unhinged. Objects misbehave with comic timing; nobody is ever cruel.",
            choices: "Offer cornering it, baiting it with something it wants, or letting it go on purpose: each with a visibly different aftermath.",
            continuation: "The quill remembers who chased and who bargained. Follow the consequence; never re-run the same chase."),
        recipe("door-that-was-not-there", "The Door That Was Not There", weight: 14, requirements: [], mode: .environmental,
            premise: "A door stands in the corridor tonight that was not there this morning: polite, unlocked, and very slightly warm.",
            beats: ["Show the door plainly: its wood, its handle, the way the corridor pretends nothing has changed around it.", "After the chosen response, the door opens, waits, or withdraws, and the corridor keeps one permanent trace of what was decided."],
            turn: turn(.factLearned, want: "to learn what the new door is for before it decides on its own", obstacle: "doors that ask politely are the ones with the oldest rules", statement: "By the end, the door has been opened, tested, refused, or given terms, and one true thing about it is known.", slice: "The door is left unopened tonight, and approves of the restraint.", progress: "What is learned about the door opens {{thread}} by one hinge.", surprise: "The door is not an entrance. It is an exit: from somewhere else."),
            tags: ["world-led", "threshold", "night", "wonder"], forms: ["threshold-crossing", "nocturne"], genres: ["threshold-gothic", "gentle-horror"],
            grounding: "Use the real hour or weather as the corridor's mood, nothing more. The door is the whole subject; the reader's pages are not in this scene.",
            tone: "Courteous danger. The dread resolves toward wonder, never punishment; the door has manners and expects them back.",
            choices: "Offer stepping through, testing it with something expendable, or fetching a witness: three commitments, not three hesitations.",
            continuation: "The door's verdict stands: opened stays opened, refused leaves a trace. Never let the same door reappear unchanged."),
        recipe("great-hall-wager", "The Great Hall Wager", weight: 13, requirements: [.character, .secondCharacter], mode: .conversation,
            premise: "{{lead}} and {{companion}} have staked a public wager in the Great Hall (the reader names the winner) and neither will say out loud what the loser owes.",
            beats: ["The contest is concrete and almost dignified, the Hall taking sides; the unstated stake hums under every exchange.", "After the chosen response, a winner stands, the hidden stake surfaces, and paying it turns out to be the better half of the story."],
            turn: turn(.relationshipShift, want: "to win the wager in front of the entire Hall", obstacle: "{{companion}} is better at this than {{lead}} planned for", statement: "By the end, the wager has a named winner and the secret stake is on the table: payable, traded, or laughingly forgiven.", slice: "The contest dissolves into shared showing-off, the stake quietly halved.", progress: "The revealed stake moves {{thread}} one honest step.", surprise: "Both of them bet the same secret, and now they both owe it."),
            tags: ["world-led", "audience", "mischief", "cast"], forms: ["quiet-epic", "visitation"], genres: ["trickster-duel", "screwball"],
            grounding: "The real-day detail may set the Hall's light or the crowd's mood; the wager itself belongs entirely to the world. Do not involve the reader's pages.",
            tone: "Tournament energy, kitchen stakes. Wit sharpens, nobody bleeds; losing is survivable and interesting.",
            choices: "Offer crowning a winner outright, raising the stakes yourself, or forcing the hidden stake into the open before judging.",
            continuation: "The debt is real and gets paid on stage or in installments. Advance the payment; never re-run the contest."),
        recipe("weather-indoors", "The Weather Indoors", weight: 13, requirements: [], mode: .environmental,
            premise: "The weather has come indoors: one corridor of the Labyrinth is running its own sky tonight, and it does not match the one outside.",
            beats: ["Walk into it: the indoor sky behaves with physical specifics (rain that files itself, fog that reads over shoulders) while the rest of the building stays dry.", "After the chosen response, the indoor weather settles, migrates, or is granted the corridor permanently, and someone posts a small sign about it."],
            turn: turn(.realNoticing, want: "to learn what the corridor is trying to say with its borrowed sky", obstacle: "weather cannot be interrogated, only kept company", statement: "By the end, the indoor sky has been understood well enough to live with: settled, moved, or granted its corridor.", slice: "The reader stands in the indoor rain for one minute and comes out dry and better.", progress: "Where the weather goes next points {{thread}} down a new hall.", surprise: "The corridor borrowed the sky from a day that has not happened yet."),
            tags: ["world-led", "weather", "wonder", "quiet"], forms: ["nocturne", "small-mystery"], genres: ["field-naturalist", "kindly-ghost"],
            grounding: "If a real weather signal is supplied, let the indoor sky argue with it or exaggerate it: atmosphere against atmosphere. Never bring in the reader's pages.",
            tone: "Quiet astonishment with wet shoes. The building is allowed to have moods; nobody files a complaint.",
            choices: "Offer walking the whole weather's length, bottling a sample, or negotiating which room gets it next.",
            continuation: "The corridor keeps whatever weather it was granted. Move to the next room's opinion; never re-discover the same sky."),
        recipe("kitchens-at-midnight", "The Kitchens at Midnight", weight: 13, requirements: [.character], mode: .balanced,
            premise: "The Kitchens have demanded one dish by midnight for a guest nobody will name, and {{lead}} has claimed the reader as sous-conspirator.",
            beats: ["The brief is absurd and exact (one dish, one deadline, ingredients that negotiate) and the guest's identity is a locked pantry door.", "After the chosen response, the dish goes out, the guest's chair scrapes somewhere unseen, and one clue about who ate comes back on the empty plate."],
            turn: turn(.handOff, want: "to get one worthy dish out the pass before midnight", obstacle: "the best ingredient has opinions about being cooked", statement: "By the end, a dish has been served, substituted, or gloriously improvised, and the empty plate returns one clue about the unnamed guest.", slice: "The kitchen quiets, the dish is simple, and simple turns out to be the right call.", progress: "The clue on the returned plate moves {{thread}} one course forward.", surprise: "The guest sent a dish back: in the other direction, as thanks, for the reader."),
            tags: ["world-led", "adventure", "care", "mission"], forms: ["quiet-epic", "correspondence"], genres: ["pastoral", "tiny-heist"],
            grounding: "Season and hour may flavor the menu; nothing else from the real day enters the kitchen. The reader's pages are not ingredients.",
            tone: "Feast-day urgency with warm edges: knives quick, voices low, the ovens on the reader's side.",
            choices: "Offer the ambitious dish, the humble dish done perfectly, or spending precious minutes finding out who the guest is.",
            continuation: "The guest's clue is canon now. Follow who was fed and what they owe the kitchen; never re-stage the same midnight."),
        // The tending register: forage, brew, mend, name, trade, observe,
        // catalog. These are the nurture-shaped scenes: gathering small
        // treasures, repairing worn things, marking the real season, where
        // the win condition is care taken, never danger survived.
        recipe("forage-day", "Forage Day in the Deep Stacks", weight: 14, requirements: [.character], mode: .action,
            premise: "{{lead}} has declared it a forage day: basket, gloves, and a route through the Deep Stacks where the Labyrinth grows things no gardener planted.",
            beats: ["Set out with the basket: name two or three concrete finds in passing (shelf-moss, ink-berries, a spine-snail) and let one small shiny thing start following the expedition.", "After the chosen response, the basket comes home with one true find, and what was gathered, released, or given leaves the Stacks visibly tended."],
            turn: turn(.smallDecision, want: "to fill one basket with things the Stacks grew on their own", obstacle: "the best finds are shy, and picking wrongly offends the shelf that grew them", statement: "By the end, the basket holds one true find (gathered, traded, or deliberately left growing) and the shiny thing has made its choice.", slice: "The forage slows into kneeling and looking; one small find is enough.", progress: "What the basket carries home gives {{thread}} one usable ingredient.", surprise: "The shiny thing following the basket was doing its own foraging: for the reader."),
            tags: ["world-led", "forage", "objects", "wonder", "adventure"], forms: ["quiet-epic", "threshold-crossing"], genres: ["field-naturalist", "pastoral"],
            grounding: "Season and hour may set what is in fruit; nothing else from the real day enters the Stacks. The reader's pages are not on the foraging route.",
            tone: "Goblin-hearted and unhurried: mud, moss, and small treasures taken seriously. Ugly things are allowed to be beautiful.",
            choices: "Offer following the shiny thing, harvesting the practical find, or leaving the best find growing and marking the spot: three different baskets, not three speeds of caution.",
            continuation: "The Stacks remember what was gathered and what was spared; a kept find may reappear as a small prop. Never re-run the same forage route."),
        recipe("night-apothecary", "The Night Apothecary", weight: 12, requirements: [.groundedSource, .character], mode: .balanced,
            premise: "The infirmary shelf is open late: something in {{thread}} needs a remedy steeped before morning, and the missing ingredient is hiding inside {{grounding}}.",
            beats: ["Name the patient and the ailment in concrete terms (a homesick atlas, a lamp that has lost its nerve) and let the ingredients negotiate their way into the pot.", "After the chosen response, the remedy is served, split, or gently corrected, and the patient shows one honest sign of change."],
            turn: turn(.handOff, want: "to steep one honest remedy before the lamps go out", obstacle: "the recipe's key ingredient has opinions about the dose", statement: "By the end, a remedy has been brewed strong, brewed gentle, or remade to fit what the patient actually needed.", slice: "The steeping slows the room; watching the color change is most of the cure.", progress: "What the remedy reveals about the patient moves {{thread}} one spoonful forward.", surprise: "The remedy was steeping for the brewer all along."),
            tags: ["care", "night", "objects", "mission"], forms: ["quiet-epic", "visitation"], genres: ["pastoral", "cozy-mystery"],
            grounding: "Turn the grounded detail into the active part of the fiction: an ingredient, a dosage clue, or the reason tonight is the night. Never explain what it meant in the reader's day.",
            tone: "Hedge-witch practical: low lamps, honest measurements, zero shame. The cure is allowed to be tea.",
            choices: "Offer the strong dose, the gentle dose done perfectly, or asking the patient what it actually needs: three real prescriptions with different aftermaths.",
            continuation: "The patient's change is canon; follow what the cured thing does next. Never re-brew the same remedy for the same ailment."),
        recipe("mending-basket", "The Mending Basket", weight: 12, requirements: [.groundedSource, .character], mode: .balanced,
            premise: "{{lead}} sets the mending basket between you: one worn thing from {{thread}} needs repair tonight, and the damage has {{grounding}} worked into its weave.",
            beats: ["Show the worn thing plainly (the tear, the bent feather, the cracked hinge) and let the first stitch reveal something hidden under the wear.", "After the chosen response, the mend holds (invisible, honored, or taught to keep itself) and what the wear was hiding is in the open."],
            turn: turn(.realNoticing, want: "to mend one worn thing so it can go on being used", obstacle: "the damage is load-bearing; something true is woven into the fraying", statement: "By the end, the worn thing is mended (seamlessly, visibly, or by learning to hold itself) and what the wear concealed has been seen.", slice: "The mending becomes the evening; small stitches, long quiet.", progress: "What the repair uncovers gives {{thread}} one new thread to pull.", surprise: "The previous mender left a message in the stitches, waiting for the next pair of hands."),
            tags: ["care", "objects", "memory", "quiet"], forms: ["small-mystery", "correspondence"], genres: ["pastoral", "kindly-ghost"],
            grounding: "Make the grounded detail physically present in the damage or the repair: a stain shaped like it, a thread the same color, the reason this object wore out here. The wear tells the truth; the mend answers it.",
            tone: "Kintsugi-hearted: repair as respect, never as erasure. The scar is allowed to be the best part.",
            choices: "Offer the invisible mend, the visible mend that honors the break, or teaching the thing to hold itself: three philosophies of repair, each with a different keeper.",
            continuation: "The mended thing stays mended and carries its story; it may pass through later scenes bearing the repair. Never tear it again for drama."),
        recipe("naming-of-small-things", "The Naming of Small Things", weight: 12, requirements: [], mode: .environmental,
            premise: "Something in the Labyrinth has gone too long without a name, and tonight it has stopped answering to \"that thing by the stairs,\" because unnamed is exactly how the Rut of Routine likes its meals.",
            beats: ["Show the unnamed thing concretely, and the small grey fading at its edges that namelessness invites; the corridor is quietly holding auditions.", "After the chosen response, the name is conferred, tried aloud, or respectfully deferred, and the world writes it down where names are kept."],
            turn: turn(.smallDecision, want: "to find the true name before the greyness finds the gap", obstacle: "the thing has been rejecting flattering names for years; it wants an honest one", statement: "By the end, the small thing has a name conferred, borrowed, or honestly postponed, and the grey has lost its foothold.", slice: "The naming stays little: one word tried quietly, and the thing leaning into it.", progress: "The new name becomes an address other stories can find; {{thread}} gains a place to knock.", surprise: "The thing already had a name once, and chooses to tell only the reader what it was."),
            tags: ["world-led", "words", "wonder", "quiet", "naming"], forms: ["small-mystery", "correspondence"], genres: ["field-naturalist", "kindly-ghost"],
            grounding: "Hour and weather may color the corridor; the unnamed thing belongs wholly to the world. The reader's pages stay closed.",
            tone: "Ceremonial at whisper scale. A true name is exact, a little funny, and impossible to take back.",
            choices: "Offer conferring the name that fits, asking the thing what it has overheard and liked, or deferring with a promise and a temporary nickname: three honest registers of christening.",
            continuation: "The conferred name is permanent world-fact: later scenes use it without comment. Never rename the same thing or let it fade again.",
            suppressedBy: [.wordNegotiation], suppressionHours: 48),
        recipe("stall-night", "Stall Night at the Goblin Market", weight: 13, requirements: [.character], mode: .balanced,
            premise: "The Goblin Market has set up overnight in a disused reading room (stalls of bottled hush and secondhand moonlight) and {{lead}} knows which aisle is safest, which is best, and that they are not the same aisle.",
            beats: ["Walk the stalls with specifics: three vendors, three wares, one iron house rule: everything here is traded in kind, never bought.", "After the chosen response, one trade is made, declined, or improved upon, and the Market packs itself away leaving exactly one stall's worth of consequence."],
            turn: turn(.handOff, want: "to come away from the Market with one fair trade", obstacle: "the best stall only accepts payment the trader has to name themselves", statement: "By the end, one trade has been struck, walked away from, or renegotiated into something better, and the Market remembers the reader's manners.", slice: "The browsing is the whole visit: touching nothing, wanting everything, leaving light.", progress: "What was traded for turns out to be exactly what {{thread}} was missing.", surprise: "One stallkeeper knows the reader already: the radio plays in the Market too, and their dedication was heard."),
            tags: ["world-led", "market", "objects", "mischief", "threshold"], forms: ["threshold-crossing", "visitation"], genres: ["threshold-gothic", "cozy-mystery"],
            grounding: "The hour sets the Market's candlelight and nothing more. The wares are the world's own; the reader's pages are not for sale.",
            tone: "Courteous bazaar: velvet and vinegar. Every price is fair and none of them are money; danger wears good manners.",
            choices: "Offer the practical stall, the beautiful stall, and the stall that trades in intangibles: three different transactions, never three ways to hesitate.",
            continuation: "Trades hold on both sides: what was given stays given, and what was gained may resurface as a small prop. The Market never re-opens in the same room twice.",
            suppressedBy: [.faeBargain], suppressionHours: 72),
        recipe("small-observance", "The Small Observance", weight: 12, requirements: [], mode: .environmental,
            premise: "The Labyrinth is preparing one of its small observances: the building marks the turning of the real season the way old houses do, and a part of the ceremony has been left, deliberately, for the reader to hold.",
            beats: ["Show the preparations at kitchen scale (candles counted, a window unlatched for the ceremony's one guest, the almanac open on its stand) and name the seasonal edge being honored.", "After the chosen response, the observance is kept: modest, exact, and finished, with one part of it now traditionally the reader's."],
            turn: turn(.realNoticing, want: "to keep the observance properly before the season's edge passes", obstacle: "the ceremony's instructions survive only as marginalia and one stubborn tradition nobody remembers the reason for", statement: "By the end, the observance has been kept (by the book, by feel, or by honest improvisation) and the season has been seen across its threshold.", slice: "The ceremony turns out to be mostly standing still at the right window at the right hour.", progress: "The kept observance earns {{thread}} the season's small favor.", surprise: "The observance is older than the building, and for one held breath the corridor remembers being outdoors."),
            tags: ["world-led", "season", "weather", "quiet", "ritual"], forms: ["nocturne", "quiet-epic"], genres: ["pastoral", "field-naturalist"],
            grounding: "Build the ceremony from the real season and hour supplied: first frost, longest light, the swifts leaving. The realer the edge, the better the magic. The reader's pages stay closed.",
            tone: "Slow gold and candle-smoke: liturgy at household scale, warmth without solemnity. Marking time is the whole point.",
            choices: "Offer keeping the tradition exactly, adapting it honestly to tonight, or taking the one role no one has volunteered for: three ways to hold a ceremony, not three ways to watch one.",
            continuation: "The observance recurs only when the real season turns again; the reader's part in it is tradition now. Advance what the season's favor touched; never re-stage the same edge.",
            cooldown: 96, suppressedBy: [.festival], suppressionHours: 72),
        recipe("impossible-specimen", "The Impossible Specimen", weight: 12, requirements: [.character], mode: .balanced,
            premise: "{{lead}} arrives balancing a specimen box that is visibly arguing with its own lid: something impossible has been found in the Labyrinth, and the registry has exactly one blank catalog card left.",
            beats: ["Open the box carefully: the impossible thing gets concrete features, honest behavior, and grave bureaucratic respect: one card, so the entry must be right.", "After the chosen response, the specimen is filed, verified, or released with its card pinned open, and the registry is one impossible entry richer."],
            turn: turn(.factLearned, want: "to catalog the impossible thing accurately before it catalogs itself as gone", obstacle: "every verified fact about it contradicts one other verified fact", statement: "By the end, the specimen has an entry (filed as itself, filed as a question, or released with its record honestly incomplete) and one true fact about it is established.", slice: "The cataloging slows into acquaintance; the specimen relaxes once it is being taken seriously.", progress: "The completed card gives {{thread}} an official fact to lean on.", surprise: "The specimen has been keeping its own record, and it has an entry on the reader."),
            tags: ["world-led", "wonder", "creature", "evidence"], forms: ["small-mystery", "visitation"], genres: ["field-naturalist", "cozy-mystery"],
            grounding: "Weather and hour may explain where the specimen was found; the reader's pages are not evidence. Documentation makes wonder kinder: that is the room's whole creed.",
            tone: "Grave bureaucratic tenderness: stamps, folders, and complete seriousness about the unserious. Verification is a form of welcome.",
            choices: "Offer verifying one testable claim, filing it as itself with the contradictions intact, or letting it dictate its own entry: three curatorial philosophies with different drawers.",
            continuation: "The catalog entry is canon and citable; later scenes may pull the card. Never re-discover the specimen or lose the file."),
        // The mischief register: comedy made from sincere people facing an
        // absurdly specific problem. The joke is never that somebody cared;
        // caring is what lets the ridiculous situation acquire real stakes.
        recipe("wrong-size-emergency", "The Wrong Size of Emergency", weight: 13, requirements: [.groundedSource, .character], mode: .action,
            premise: "{{lead}} arrives inside {{thread}} equipped for a five-alarm magical emergency because {{grounding}} sounded much more ominous from the other side of the door. The actual problem could fit in a teacup.",
            beats: ["Inventory the heroic overpreparation at speed (rope, warning bell, emergency cloak, one tool nobody can explain), then reveal the tiny exact trouble none of it was designed to solve.", "After the chosen response, the ridiculous equipment is repurposed, dismissed with honors, or sent where it is genuinely needed, and the teacup-sized emergency is actually solved."],
            turn: turn(.smallDecision, want: "to solve the small true problem hidden inside the large misunderstanding about {{grounding}}", obstacle: "{{lead}} has brought enough equipment to make admitting the mistake socially expensive", statement: "By the end, the small emergency is solved and the unnecessary heroics have found a graceful fate.", slice: "One absurd tool turns out to be perfect once everybody stops pretending it was brought on purpose.", progress: "The overpacked kit contains the one overlooked thing that moves {{thread}} forward.", surprise: "There was a real emergency after all, but it belongs to the person who loaned {{lead}} the ladder."),
            tags: ["mischief", "energy", "mission", "comic"], forms: ["visitation", "quiet-epic"], genres: ["screwball", "tiny-heist"],
            grounding: "Use one concrete feature of the grounded detail as both the believable source of the misunderstanding and the clue to the much smaller real problem. Never mock the reader's actual concern.",
            tone: "Affectionate farce with brisk entrances and total commitment. The mismatch is funny; the person who cared enough to come prepared is not the punchline.",
            choices: "Offer admitting the mistake and solving the small problem plainly, repurposing the most excessive piece of gear, or sending the whole heroic kit toward the emergency it accidentally uncovered.",
            continuation: "The small problem stays solved, and any equipment sent onward stays in play. Never inflate the same misunderstanding into a second false crisis."),
        recipe("one-simple-conversation", "One Simple Conversation", weight: 12, requirements: [.groundedSource, .character, .secondCharacter], mode: .conversation,
            premise: "{{lead}} only needs to say one simple thing to {{companion}} about {{grounding}}. Unfortunately, the rehearsal inside {{thread}} has acquired cue cards, three opening lines, and a cape nobody authorized.",
            beats: ["Let the rehearsal worsen through sincere revisions: each attempt to sound natural adds one more prop, flourish, or terrible piece of advice while the unsaid sentence remains short and clear.", "After the chosen response, the real conversation happens plainly, happens theatrically on purpose, or begins when {{companion}} walks in early, and the one necessary sentence finally lands."],
            turn: turn(.relationshipShift, want: "to say one honest sentence to {{companion}} about {{grounding}} without making it strange", obstacle: "every rehearsal makes the sentence stranger and the audience larger", statement: "By the end, the honest sentence has been said and answered, with or without the cape.", slice: "The cue cards are put down and the sentence is tried once in an ordinary voice.", progress: "{{companion}} answers the actual sentence, moving {{thread}} past the rehearsal.", surprise: "{{companion}} heard the first rehearsal through the wall and has brought notes."),
            tags: ["mischief", "cast", "conversation", "comic"], forms: ["visitation", "correspondence"], genres: ["screwball", "cozy-mystery"],
            grounding: "The grounded detail supplies the exact subject of the honest sentence. Keep its emotional truth intact while the performance around it gets ridiculous.",
            tone: "Warm social comedy: escalating preparation, quick interruptions, and no humiliation. Beneath the farce, let the simple sentence matter.",
            choices: "Offer abandoning the rehearsal for plain speech, committing to the theatrical version with full honesty, or swapping roles so {{lead}} can hear how the sentence sounds.",
            continuation: "The answer to the honest sentence is canon. Follow the relationship after it was said; never send everyone back into rehearsal."),
        recipe("rumor-with-good-shoes", "The Rumor with Good Shoes", weight: 12, requirements: [.groundedSource, .character], mode: .action,
            premise: "A harmless misunderstanding about {{grounding}} has put on excellent shoes and is walking briskly through {{thread}}. {{lead}} is one corridor behind and losing ground.",
            beats: ["Track the rumor by the increasingly confident details people have added to it; every version should be more specific, less accurate, and funnier without becoming cruel.", "After the chosen response, the rumor is caught and corrected, redirected into an obviously fictional legend, or introduced to the much better truth, and its shoes are finally accounted for."],
            turn: turn(.factLearned, want: "to catch the walking rumor before it reaches someone who will embroider it", obstacle: "each correction arrives one room late and becomes part of the story", statement: "By the end, the misunderstanding has been corrected, harmlessly fictionalized, or replaced by the specific truth.", slice: "One listener simply asks what actually happened, and waits for the answer.", progress: "The rumor's route reveals who in {{thread}} needed the real information.", surprise: "The shoes belong to a second rumor coming the other way."),
            tags: ["mischief", "words", "mission", "comic"], forms: ["small-mystery", "quiet-epic"], genres: ["screwball", "serial-adventure"],
            grounding: "Build the first misunderstanding from a plausible ambiguity in the grounded detail, then preserve one exact true fact through every wrong version. Do not turn private pain, identity, or vulnerability into gossip.",
            tone: "Fleet-footed verbal comedy. The additions are absurd, the consequences stay kind, and accuracy gets the last good line.",
            choices: "Offer catching the rumor with a concise correction, declaring it fiction and improving it beyond belief, or letting the person who needs the truth hear the full specific version first.",
            continuation: "The corrected people stay corrected. Any deliberately fictional legend may recur only as a known joke, never as believed fact."),
        recipe("petty-prophecy", "The Petty Prophecy", weight: 13, requirements: [], mode: .environmental,
            premise: "A sealed prophecy has opened itself in the Great Hall and announced, in thunderous gold letters, a consequence of almost insulting smallness before midnight.",
            beats: ["Read the prophecy with full ceremonial gravity, then make its promised event painfully concrete (the last clean spoon, a crooked button, the wrong person getting the good chair) while the Labyrinth reacts as if dynasties depend on it.", "After the chosen response, the prophecy is fulfilled exactly, outwitted on a technicality, or persuaded to admit what tiny thing it was really trying to protect."],
            turn: turn(.smallDecision, want: "to settle the prophecy before midnight without granting it more grandeur than it has earned", obstacle: "the wording is airtight, pompous, and annoyingly achievable", statement: "By the end, the petty prophecy has been fulfilled, outwitted, or honestly reinterpreted, and the small consequence is permanent.", slice: "The reader performs the tiny foretold act with absurd solemnity, and the gold letters calm down.", progress: "One overlooked clause points straight into {{thread}}.", surprise: "The prophecy is accurate because it wrote the event into the duty roster itself."),
            tags: ["world-led", "mischief", "words", "ritual", "comic"], forms: ["correspondence", "nocturne"], genres: ["screwball", "cozy-mystery"],
            grounding: "Hour and weather may sharpen the deadline; the prophecy belongs wholly to the world and never predicts the reader's destiny, worth, romance, health, or real future.",
            tone: "Cosmic language, household stakes, absolutely straight faces. Let ceremony and pettiness make each other funnier.",
            choices: "Offer fulfilling the tiny prediction with full honors, defeating it through one exact loophole, or questioning the prophecy until it confesses the small good it wants protected.",
            continuation: "The prophecy's exact outcome is world-fact and its parchment goes quiet. Never issue a grander sequel to justify the joke."),
        recipe("unscheduled-parade", "The Unscheduled Parade", weight: 13, requirements: [.character], mode: .action,
            premise: "{{lead}} makes one perfectly ordinary signal in a corridor (a whistle, a raised umbrella, three knocks) and an entire parade forms behind it with no agreed destination.",
            beats: ["Build the procession while it moves: one dubious banner, one impossible instrument, at least one marcher who thinks this is a different parade, and {{lead}} trying to discover what they apparently started.", "After the chosen response, the parade is given a worthy destination, steered toward someone who needs cheering, or allowed to elect its own purpose: then ends before it becomes a meeting."],
            turn: turn(.handOff, want: "to give the accidental parade somewhere worth arriving", obstacle: "every new marcher has already announced a different purpose", statement: "By the end, the parade has arrived somewhere on purpose, cheered one person, or elected a cause everybody can actually name.", slice: "For one corridor the reader simply marches, letting the worst instrument keep the beat.", progress: "The chosen destination carries the whole procession one jubilant step into {{thread}}.", surprise: "The parade has a permit. It was filed eighty years ago for exactly today."),
            tags: ["world-led", "mischief", "music", "energy", "comic"], forms: ["quiet-epic", "threshold-crossing"], genres: ["screwball", "serial-adventure"],
            grounding: "Weather and hour set the parade's light and acoustics; the procession comes from the Labyrinth's own life. The reader's pages stay closed.",
            tone: "Joyful escalating nonsense with forward motion. Everyone is allowed dignity, including the person playing the impossible instrument badly.",
            choices: "Offer choosing a destination worth the noise, taking the parade to one person who needs it, or calling a moving vote so the marchers invent a shared purpose.",
            continuation: "The parade ends at its destination and leaves one banner, tune, or new tradition behind. Never make the same signal summon it twice."),
        recipe("rule-nobody-read", "The Rule Nobody Read", weight: 12, requirements: [.character], mode: .balanced,
            premise: "A self-inking rulebook has cited {{lead}} for breaking an ancient Labyrinth regulation nobody has read because its title continues onto the next shelf.",
            beats: ["State the absurd rule, the inconvenient but harmless penalty, and the exact ordinary act that triggered it; the rulebook should be technically correct and unbearable about punctuation.", "After the chosen response, the rule is obeyed spectacularly, defeated by its own footnote, or amended through an older precedent, and the book must enter the ruling in ink."],
            turn: turn(.factLearned, want: "to resolve one ridiculous but valid citation before the rulebook adds late fees", obstacle: "the rule has seventeen clauses, one useful footnote, and custody of the ink", statement: "By the end, the citation has been satisfied, overturned, or converted into a better rule the book is forced to print.", slice: "Someone reads the rule all the way through; the final clause is unexpectedly reasonable.", progress: "The precedent hidden in the footnote opens a lawful route into {{thread}}.", surprise: "{{lead}} did not break the rule: the rulebook did, by issuing the citation in the prohibited typeface."),
            tags: ["world-led", "mischief", "books", "evidence", "comic"], forms: ["small-mystery", "correspondence"], genres: ["screwball", "cozy-mystery"],
            grounding: "Hour, season, and weather may affect office hours or ink behavior; the rule arises from the world's history, never from policing the reader's real conduct.",
            tone: "Deadpan magical bureaucracy: exact language, escalating procedure, no institutional cruelty. The rulebook is formidable, fallible, and very proud of its semicolons.",
            choices: "Offer complying so magnificently the rule becomes silly, building a case from the footnote, or finding an older precedent that lets the rule be amended in public.",
            continuation: "The ruling is entered and binding. Later scenes honor the amendment or precedent; never cite the same character for the same act again."),
        // The chosen quill's own scene: only offered once an instrument has
        // chosen the reader in the Quillquarium, and staged so the quill's
        // opposite-of-the-reader temperament does the dramatic work.
        recipe("the-quill-disagrees", "The Quill Disagrees", weight: 12, requirements: [.chosenQuill], mode: .balanced,
            premise: "Your quill, {{quill}}, has planted itself upright in the inkwell and refuses tonight's page as drafted: it has a better idea, and it is prepared to drip until heard.",
            beats: ["Stage the disagreement concretely: what the page wants to say, what the quill keeps writing instead, and the one word it will not put down.", "After the chosen response, the page is finished (the reader's way, the quill's way, or a third way neither expected) and the quill's opinion of its writer updates by one honest notch."],
            turn: turn(.relationshipShift, want: "tonight's page written the way {{quill}} believes the reader actually means it", obstacle: "the quill is, infuriatingly, not entirely wrong", statement: "By the end, the disputed page exists (compromised, conceded, or improved past both drafts) and writer and quill know each other one notch better.", slice: "The standoff mellows into practice strokes; the quill shows off, forgiven.", progress: "The finished page turns out to be a key that fits {{thread}}.", surprise: "The quill was not editing the page. It was protecting the reader from spending the good sentence on the wrong paragraph."),
            tags: ["quill", "writing", "mischief", "care"], forms: ["visitation", "small-mystery"], genres: ["screwball", "cozy-mystery"],
            grounding: "The quill's temperament is supplied: let its leanings drive the disagreement. Real-day details stay atmosphere; the dispute is about the writing, never the reader's private facts.",
            tone: "Fond exasperation: the pen is a colleague with strong opinions and no salary. Nobody wins by force.",
            choices: "Offer writing it the reader's way with the quill under protest, giving the quill one paragraph to prove its case, or setting both drafts side by side to see what the page itself prefers.",
            continuation: "The quill remembers who yielded and why; its next appearance leans on that memory. Never re-run the same standoff.",
            cooldown: 96),

        // MARK: The role recipes
        //
        // One signature scene per role. These are the payoff of the Book naming
        // the reader on night one: a scene it would only ever hand to this kind
        // of person, built around the specific appetite the name describes.
        //
        // Long cooldowns on purpose. A role scene that turns up weekly is a
        // genre; one that turns up twice a season is a name being honoured.
        recipe("role-maker-unfinished", "The Half-Finished Thing", weight: 15,
            requirements: [.readerRole, .character], mode: .balanced,
            premise: "Somebody in {{thread}} has abandoned something at exactly the stage the reader finds most alive, and is about to throw it out.",
            beats: ["{{lead}} finds the half-made thing and the person who gave up on it, and neither will say plainly what it was for.", "After the chosen response, it is finished badly, left deliberately unfinished, or handed over to somebody else entirely."],
            turn: turn(.revealWant, want: "to know whether the half-made thing was abandoned or merely paused", obstacle: "{{companion}} would rather bin it than admit which", statement: "By the end, the unfinished thing has a decided fate and somebody has said out loud what it was for.", slice: "One physical detail of the thing at its current stage: the seam, the gap, the wet edge.", progress: "Whatever is decided about it moves {{thread}} one step.", surprise: "It was never going to be finished. It was made to be exactly this far along."),
            tags: ["role", "making", "unfinished"], forms: ["visitation", "quiet-epic"], genres: ["cozy-mystery", "serial-adventure"],
            grounding: "Ground in the physical state of the half-made thing. Never call it art and never call it a project.",
            tone: "The pleasure of partway. Nobody is precious about it; everybody is a little defensive.",
            choices: "Offer finishing it roughly, protecting its unfinished state, or giving it to somebody who will finish it wrong.",
            continuation: "The thing keeps whatever fate it was given. Do not resurrect a binned object.",
            cooldown: 336, roles: ["maker"]),

        recipe("role-lookout-weather-turned", "The Weather Turned", weight: 15,
            requirements: [.readerRole], mode: .environmental,
            premise: "The weather over the Academy has done something specific and nobody inside {{thread}} has looked up yet.",
            beats: ["The sky does one exact thing while the room carries on. {{lead}} is the only one who notices.", "After the chosen response, the weather is named, ignored, or turns out to have been about something."],
            turn: turn(.factLearned, want: "to get somebody else to come outside and look", obstacle: "everybody indoors has a reason not to and all of them are reasonable", statement: "By the end, the sky's exact behaviour has been named out loud by somebody who was not going to.", slice: "One temperature, one direction, one thing the air is doing to a surface.", progress: "What was seen from outside changes what is understood inside {{thread}}.", surprise: "Somebody had already been out. They did not mention it."),
            tags: ["role", "outside", "weather", "sky"], forms: ["quiet-epic", "field-notes"], genres: ["threshold-gothic", "serial-adventure"],
            grounding: "Ground in actual weather: temperature, direction, what the light is doing to something solid. No pathetic fallacy.",
            tone: "Air that is a temperature. Specific, physical, unliterary about the sky.",
            choices: "Offer going out alone, dragging somebody with you, or staying in and being right about it later.",
            continuation: "The weather moves on its own schedule. It does not wait for the scene.",
            cooldown: 336, roles: ["lookout"]),

        recipe("role-porchlight-light-left-on", "The Light Left On", weight: 15,
            requirements: [.readerRole, .character, .secondCharacter], mode: .conversation,
            premise: "Two people in {{thread}} have stopped speaking, and both are waiting for the other to make it easy.",
            beats: ["{{lead}} ends up in a room with both of them and the thing neither will say.", "After the chosen response, somebody goes first, or the gap is left open on purpose and named as open."],
            turn: turn(.relationshipShift, want: "to make it possible for one of them to go first", obstacle: "helping too visibly would make it about the helping", statement: "By the end, one of them has moved, or the not-moving has been named honestly by somebody.", slice: "One ordinary domestic act performed for somebody who did not ask.", progress: "The thread between the two of them moves one exact, small distance.", surprise: "They had already spoken. Neither told anybody."),
            tags: ["role", "people", "repair", "cast"], forms: ["visitation", "correspondence"], genres: ["cozy-mystery", "serial-adventure"],
            grounding: "Ground in something ordinary being done for somebody: a chair moved, a drink made, a door held.",
            tone: "Warmth with no speeches. Nobody says anything about friendship out loud.",
            choices: "Offer making the first move for them, holding the room open, or saying the unsaid thing plainly.",
            continuation: "Whatever moved between them stays moved. Do not reset the silence.",
            cooldown: 336, roles: ["porchlight"]),

        recipe("role-detourist-wrong-way", "The Wrong Way Round", weight: 15,
            requirements: [.readerRole], mode: .environmental,
            premise: "The usual route through {{thread}} is closed, and the way round goes somewhere the usual way never passed.",
            beats: ["The detour turns out to be longer, stranger, and to contain one thing the direct route would never have shown.", "After the chosen response, the detour is kept, abandoned, or turns out to have been the actual route."],
            turn: turn(.factLearned, want: "to see where the wrong way actually goes", obstacle: "the right way is right there and everybody is taking it", statement: "By the end, the detour has produced one thing the direct route could not have.", slice: "One specific thing seen only because of the longer way.", progress: "What the detour found moves {{thread}} sideways rather than forward.", surprise: "The closure was not an accident. Somebody wanted people going this way."),
            tags: ["role", "detour", "route", "place"], forms: ["quiet-epic", "field-notes"], genres: ["serial-adventure", "threshold-gothic"],
            grounding: "Ground in the physical route: surfaces, distances, what is passed. The detour must cost something real.",
            tone: "Curiosity that is faintly irresponsible. Nobody is lost; everybody is late.",
            choices: "Offer following it further, turning back with what you have, or telling somebody else about the way round.",
            continuation: "The detour stays on the map. If it was named, it keeps the name.",
            cooldown: 336, roles: ["detourist"]),

        recipe("role-rabbit-holer-one-more", "One More Page", weight: 15,
            requirements: [.readerRole, .groundedSource], mode: .balanced,
            premise: "A small question inside {{thread}} has a much longer answer than anybody expected, and {{grounding}} is the loose thread.",
            beats: ["{{lead}} follows the question past the point where it was reasonable to. Somebody notices what time it is.", "After the chosen response, the answer arrives, dissolves, or opens onto a bigger question that will also take all night."],
            turn: turn(.factLearned, want: "to reach the bottom of the question", obstacle: "there is no bottom, and stopping would mean deciding it did not matter", statement: "By the end, the question has been followed to a real stopping place, chosen rather than reached.", slice: "The exact hour, and what was abandoned to keep going.", progress: "What was found at depth moves {{thread}} one step.", surprise: "The answer was in the first source. It was phrased so plainly that nobody read it."),
            tags: ["role", "question", "depth", "research"], forms: ["small-mystery", "field-notes"], genres: ["cozy-mystery", "threshold-gothic"],
            grounding: "Ground in the actual chain of sources. Each step must be a real thing consulted, not a montage.",
            tone: "The specific joy of going too far. Slightly ashamed, entirely unrepentant.",
            choices: "Offer going one source deeper, stopping and writing down where you got to, or handing the thread to somebody rested.",
            continuation: "The question keeps whatever depth it reached. Do not restart it from the surface.",
            cooldown: 336, roles: ["rabbit-holer"]),

        recipe("role-nightlight-small-hours", "The Small Hours", weight: 15,
            requirements: [.readerRole, .character], mode: .conversation,
            premise: "It is very late in {{thread}} and somebody who should be asleep is not, and does not want the big lights on.",
            beats: ["{{lead}} finds them and does not turn the lights up. What gets said is only sayable at this hour.", "After the chosen response, the night is let alone, gently ended, or something is said that the morning will have to live with."],
            turn: turn(.revealWant, want: "to be company without making it into a conversation", obstacle: "{{companion}} will leave if it becomes one", statement: "By the end, somebody has been kept company at the right brightness, and one true thing has been said quietly.", slice: "One small light, and what it is enough for.", progress: "Something held since daylight moves, one degree, in the dark.", surprise: "They were waiting for somebody. Not necessarily this one."),
            tags: ["role", "night", "quiet", "care"], forms: ["visitation", "quiet-epic"], genres: ["threshold-gothic", "cozy-mystery"],
            grounding: "Ground in the specific quality of low light and late hours. Nothing is dramatic at this hour.",
            tone: "Gentle without being soft. Low volume, real weight, no rescuing.",
            choices: "Offer staying without speaking, saying the true thing, or sending them to bed kindly.",
            continuation: "The night ends when it ends. Do not have the morning resolve it.",
            cooldown: 336, roles: ["nightlight"]),

        recipe("role-steady-hand-holds", "The One Who Holds It", weight: 15,
            requirements: [.readerRole, .character], mode: .balanced,
            premise: "Something in {{thread}} is coming apart on a schedule, and everybody is discussing it except the person keeping it together.",
            beats: ["The unglamorous maintenance is being done, unremarked, while the meeting happens elsewhere.", "After the chosen response, the work is named, handed on, or deliberately allowed to fail so somebody notices."],
            turn: turn(.revealWant, want: "for the holding to be seen without having to ask for it to be seen", obstacle: "the whole value of it is that it never needed announcing", statement: "By the end, the maintenance has been named by somebody other than the person doing it.", slice: "One exact repeated task and how long it has been repeated.", progress: "Whether the holding continues changes what {{thread}} can survive.", surprise: "Somebody has been quietly doing half of it for months."),
            tags: ["role", "maintenance", "steady", "unseen"], forms: ["field-notes", "quiet-epic"], genres: ["cozy-mystery", "serial-adventure"],
            grounding: "Ground in the repeated physical task. Never romanticise it and never call it heroic.",
            tone: "Dry, unsentimental, quietly furious about how invisible this is.",
            choices: "Offer naming the work aloud, teaching somebody else to do it, or letting it fail once on purpose.",
            continuation: "If it was allowed to fail, it stays failed until somebody repairs it. Consequences do not tidy themselves.",
            cooldown: 336, roles: ["steady-hand"]),

        recipe("role-stowaway-not-invited", "Not Strictly Invited", weight: 15,
            requirements: [.readerRole], mode: .environmental,
            premise: "Something is happening inside {{thread}} that {{lead}} has no standing to be at, and the door is not locked.",
            beats: ["{{lead}} is present at a thing they were not on the list for, and nobody has asked yet.", "After the chosen response, they are found out, absorbed as though always expected, or leave with something nobody knows they took."],
            turn: turn(.factLearned, want: "to see the thing from inside rather than be told about it after", obstacle: "belonging here would require an explanation nobody has asked for yet", statement: "By the end, the question of whether they belonged here has been settled one way, out loud.", slice: "One detail only visible from inside the room.", progress: "What was seen from inside moves {{thread}} in a way secondhand accounts could not.", surprise: "There was no list. There has never been a list."),
            tags: ["role", "threshold", "unasked", "inside"], forms: ["visitation", "small-mystery"], genres: ["threshold-gothic", "trickster-duel"],
            grounding: "Ground in the specific geography of being somewhere unsanctioned: which door, which seat, who is between you and it.",
            tone: "Nerve rather than mischief. The pleasure is access, not transgression.",
            choices: "Offer staying and being counted, slipping out with what you came for, or asking plainly to be let in.",
            continuation: "However the question of belonging was settled, it stays settled. Do not re-smuggle them into the same room.",
            cooldown: 336, roles: ["stowaway"])
    ]

    static func userPacks(fileManager: FileManager = .default) -> [StoryFormPack] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        return contents
            .filter { $0.lastPathComponent.hasSuffix(userPackFileSuffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(StoryFormPack.self, from: data)
            }
            .filter { !$0.isLocked }
    }

    static func enabledPacks() -> [StoryFormPack] {
        bundledPacks.filter { !$0.isLocked || PackEntitlements.isUnlocked($0.id) } + userPacks()
    }

    static var forms: [StoryForm] {
        var seen = Set<String>()
        return enabledPacks().flatMap(\.forms).filter { seen.insert($0.id).inserted }
    }

    static var genres: [StoryGenre] {
        var seen = Set<String>()
        return enabledPacks().flatMap(\.genres).filter { seen.insert($0.id).inserted }
    }

    static let recipeTemplateTokens: Set<String> = [
        "lead", "companion", "grounding", "thread", "form", "quill",
        "leadGoal", "leadFault", "leadBelief", "companionGoal", "companionFault", "companionBelief",
        "relationshipPressure", "turnWant", "turnObstacle", "turnStatement"
    ]

    /// Bundled recipes are fixed at build time, so the regex sweep behind their
    /// validation runs once rather than on every derivation of the library.
    /// Keyed by pack and position so the answer is identical to calling
    /// `recipeIsValid` on the same recipe. User packs still validate per read:
    /// their files can change on disk between calls.
    private static let validBundledRecipeKeys: Set<String> = {
        var keys: Set<String> = []
        for pack in bundledPacks {
            for (index, recipe) in pack.recipes.enumerated() where recipeIsValid(recipe) {
                keys.insert("\(pack.id)#\(index)")
            }
        }
        return keys
    }()

    static var recipesWithPackIDs: [(packID: String, recipe: StoryRecipe)] {
        var seen = Set<String>()
        let entitledBundled = bundledPacks.filter { !$0.isLocked || PackEntitlements.isUnlocked($0.id) }
        let packs = entitledBundled.map { ($0, true) } + userPacks().map { ($0, false) }
        return packs.flatMap { pack, isBundled in
            pack.recipes.enumerated().compactMap { index, recipe in
                guard seen.insert(recipe.id).inserted else { return nil }
                let isValid = isBundled
                    ? validBundledRecipeKeys.contains("\(pack.id)#\(index)")
                    : recipeIsValid(recipe)
                return isValid ? (pack.id, recipe) : nil
            }
        }
    }

    static var recipes: [StoryRecipe] { recipesWithPackIDs.map(\.recipe) }

    /// Whether the recipe behind a blueprint runs world-led. Used by the app's
    /// prompt builder and validator, which only carry the recipe ID at that
    /// point; unknown IDs (e.g. a removed user pack) stay reader-grounded.
    static func isWorldLedRecipe(id: String) -> Bool {
        recipes.first { $0.id == id }?.isWorldLed ?? false
    }

    /// True when any relationship edge between the available entities carries
    /// real tension: the fuel for rivalry-driven clash recipes.
    static func hasRivalryEdge(
        among entities: [NarrativeWorldEntity],
        relationshipField: [String: RelationshipTie] = [:]
    ) -> Bool {
        let ids = Set(entities.map(\.id))
        if NarrativePackRegistry.relationships.contains(where: { edge in
            edge.tension >= 2 && ids.contains(edge.sourceEntityID) && ids.contains(edge.targetEntityID)
        }) {
            return true
        }
        return relationshipField.contains { pairKey, tie in
            let pair = pairKey.split(separator: "|").map(String.init)
            return pair.count == 2 &&
                pair.allSatisfy(ids.contains) &&
                tie.tension >= 2
        }
    }

    /// The chosen register is earned by looking: a recent keep that points
    /// back to the reader's real life, including legacy compass-step pages.
    static func hasRecentOutwardKeep(days: [BookDay], now: Date) -> Bool {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        return days.flatMap(\.pages).contains { page in
            guard page.createdAt >= cutoff, page.createdAt <= now else { return false }
            return page.type.pointsOutward
                || page.tags.contains(where: { $0.hasPrefix("compass-step:") })
                || page.tags.contains("playful-mission")
        }
    }

    /// Minted entity memories a character must hold about the reader before a
    /// confidence would ring true: the gate for chosen-register recipes like
    /// The Entrusting. Memories come from real kept pages, so the bond is
    /// documented history, never asserted intimacy.
    static let deepBondMemoryFloor = 3

    /// The character best placed to entrust something to the reader: the one
    /// holding the most memories of them, at or above the floor.
    static func deepBondConfidant(
        among entities: [NarrativeWorldEntity],
        memories: [NarrativeEntityMemory]
    ) -> NarrativeWorldEntity? {
        var counts: [String: Int] = [:]
        for memory in memories { counts[memory.entityID, default: 0] += 1 }
        return entities
            .filter { $0.kind == .character && counts[$0.id, default: 0] >= deepBondMemoryFloor }
            .max { (counts[$0.id, default: 0], $0.id) < (counts[$1.id, default: 0], $1.id) }
    }

    /// Compiled once. Validation runs over every recipe each time the library
    /// is derived, and rebuilding this pattern per recipe was the bulk of that.
    private static let recipeTemplateTokenRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\{\{([a-zA-Z0-9_-]+)\}\}"#)

    static func recipeIsValid(_ recipe: StoryRecipe) -> Bool {
        guard !recipe.id.isEmpty, !recipe.name.isEmpty, recipe.baseWeight > 0,
              !recipe.premiseTemplate.isEmpty, !recipe.beats.isEmpty, !recipe.turns.isEmpty else { return false }
        var strings = [recipe.premiseTemplate, recipe.groundingDirective, recipe.toneDirective,
                       recipe.choiceDirective, recipe.continuationDirective]
        strings.append(contentsOf: recipe.beats)
        for turn in recipe.turns {
            strings.append(contentsOf: [
                turn.wantTemplate, turn.obstacleTemplate, turn.statementTemplate,
                turn.sliceLandingTemplate, turn.progressLandingTemplate, turn.surpriseLandingTemplate
            ])
        }
        if let pressure = recipe.characterPressure {
            strings.append(contentsOf: [
                pressure.leadCharacterWorryTemplate, pressure.leadCharacterBlindSpotTemplate,
                pressure.otherCharacterPressureTemplate, pressure.relationshipQuestionTemplate,
                pressure.stakesTemplate, pressure.requiredCharacterReactionTemplate,
                pressure.readerChoiceEffectTemplate
            ])
        }
        guard let regex = recipeTemplateTokenRegex else { return false }
        for string in strings {
            let range = NSRange(string.startIndex..., in: string)
            for match in regex.matches(in: string, range: range) {
                guard let tokenRange = Range(match.range(at: 1), in: string),
                      recipeTemplateTokens.contains(String(string[tokenRange])) else { return false }
            }
        }
        return true
    }

    /// Picks a form and genre for this page: tag affinity chooses among
    /// genres, the ascendant chapter leans on the lens, and the variety
    /// history keeps consecutive pages from wearing the same shape.
    static func select(
        tags: Set<String>,
        surfaceHistory: [String: SurfaceHistoryRecord],
        ascendantChapterID: String?,
        dayID: String,
        slot: String,
        recipe: StoryRecipe? = nil,
        recipeBoosts: [String: Int] = [:],
        sceneBiases: [String: Int] = [:],
        now: Date = Date()
    ) -> (form: StoryForm, genre: StoryGenre) {
        let allForms = forms
        let allGenres = genres

        // `recipes` re-derives and re-validates the whole library on every
        // access, so the boosted recipes are resolved once here. Looking them
        // up inside the scoring loops did that work once per genre and once per
        // form per boost.
        let boostedRecipes: [(recipe: StoryRecipe, boost: Int)] = {
            let active = recipeBoosts.filter { $0.value > 0 }
            guard !active.isEmpty else { return [] }
            let byID = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return active.compactMap { id, boost in
                guard let recipe = byID[id] else { return nil }
                return (recipe, boost)
            }
        }()
        let hour = Calendar.current.component(.hour, from: now)

        func recencyPenalty(_ key: String) -> Int {
            guard let record = surfaceHistory[key] else { return 0 }
            let hours = now.timeIntervalSince(record.lastShownAt) / 3600
            if hours < 12 { return 8 }
            if hours < 48 { return 4 }
            return 0
        }

        func normalized(_ value: String) -> String? {
            let clean = StoryConsequenceCondition.key(value)
            return clean.isEmpty ? nil : clean
        }

        func biasScore(keys: [String], cap: Int) -> Int {
            guard !sceneBiases.isEmpty, !keys.isEmpty else { return 0 }
            let normalizedKeys = Set(keys.compactMap(normalized))
            guard !normalizedKeys.isEmpty else { return 0 }
            let score = sceneBiases.reduce(0) { total, entry in
                guard let key = normalized(entry.key), normalizedKeys.contains(key) else { return total }
                return total + entry.value
            }
            return max(-cap, min(cap, score))
        }

        let chapterGenreBias: [String: String] = [
            "duskthorn": "gentle-horror",
            "tidecrest": "serial-adventure",
            "mossbloom": "field-naturalist",
            "riddlewind": "cozy-mystery",
            "emberheart": "tiny-heist"
        ]

        let scoredGenres = allGenres.map { genre -> (StoryGenre, Int) in
            var score = tags.intersection(Set(genre.moodTags)).count * 4
            // Clash genres carry drama's darker register; they only surface when
            // the chosen recipe explicitly asks for one, keeping them off cozy pages.
            if genre.moodTags.contains("clash") && recipe?.preferredGenreIDs.contains(genre.id) != true {
                score -= 100
            }
            if let chapterID = ascendantChapterID, chapterGenreBias[chapterID] == genre.id {
                score += 3
            }
            score -= recencyPenalty("genre:\(genre.id)")
            if recipe?.preferredGenreIDs.contains(genre.id) == true { score += 7 }
            if recipe?.excludedGenreIDs.contains(genre.id) == true { score -= 100 }
            score += biasScore(keys: [genre.id] + genre.moodTags, cap: 8)
            for (boosted, boost) in boostedRecipes where boosted.preferredGenreIDs.contains(genre.id) {
                score += min(boost, 8)
            }
            score += abs("\(dayID)-\(slot)-\(genre.id)-genre".stableHash % 5)
            return (genre, score)
        }
        let genre = scoredGenres.max { $0.1 < $1.1 }?.0 ?? allGenres[0]

        let scoredForms = allForms.map { form -> (StoryForm, Int) in
            var score = abs("\(dayID)-\(slot)-\(form.id)-form".stableHash % 7)
            score -= recencyPenalty("form:\(form.id)")
            if recipe?.preferredFormIDs.contains(form.id) == true { score += 7 }
            if recipe?.excludedFormIDs.contains(form.id) == true { score -= 100 }
            score += biasScore(keys: [form.id, form.name], cap: 8)
            for (boosted, boost) in boostedRecipes where boosted.preferredFormIDs.contains(form.id) {
                score += min(boost, 8)
            }
            // The Nocturne belongs to the night.
            if form.id == "nocturne" {
                score += (hour >= 21 || hour < 5) ? 4 : -4
            }
            return (form, score)
        }
        let form = scoredForms.max { $0.1 < $1.1 }?.0 ?? allForms[0]
        return (form, genre)
    }
}

// MARK: - Compass venture reading
//
// Custom Compass Runs read the player's stated energy before deciding how
// far to send them: depleted days stay home, steadier days sometimes earn a
// real named destination: sometimes, not always.

enum CompassVentureMode: String, Equatable {
    case homebound
    case neighborhood
    case destination
}

enum CompassVenture {
    /// 0 = depleted, 1 = low, 2 = steady, 3 = bright.
    static func energyTier(from text: String) -> Int {
        let lowered = text.lowercased()
        if let match = lowered.range(of: #"\d{1,3}"#, options: .regularExpression),
           let value = Int(lowered[match]) {
            switch value {
            case ..<25: return 0
            case ..<45: return 1
            case ..<70: return 2
            default: return 3
            }
        }
        let depleted = ["exhaust", "wiped", "drained", "empty", "sick", "crash", "depleted", "running on fumes", "dead"]
        let low = ["tired", "low", "meh", "fog", "heavy", "sleepy", "weary", "worn"]
        let bright = ["great", "good", "energized", "fresh", "restless", "bouncy", "high", "excited", "alive"]
        if depleted.contains(where: lowered.contains) { return 0 }
        if low.contains(where: lowered.contains) { return 1 }
        if bright.contains(where: lowered.contains) { return 3 }
        return 2
    }

    static func minutesAvailable(from timeLimit: String) -> Int? {
        let lowered = timeLimit.lowercased()
        guard let match = lowered.range(of: #"\d{1,3}"#, options: .regularExpression),
              let value = Int(lowered[match]) else {
            return nil
        }
        if lowered.contains("hour") || lowered.contains("hr") || lowered.contains("day") {
            return value * 60
        }
        return value
    }

    static func decide(
        energyText: String,
        considerations: String,
        timeLimit: String,
        hasPlaces: Bool,
        roll: Double
    ) -> CompassVentureMode {
        let lowered = considerations.lowercased()
        let homeboundWords = ["indoors only", "can't leave", "cannot leave", "housebound", "stuck home", "in bed", "no car", "staying in", "homebound", "kids asleep", "kids napping", "baby is asleep"]
        if homeboundWords.contains(where: lowered.contains) {
            return .homebound
        }

        let tier = energyTier(from: energyText)
        if tier <= 0 {
            return .homebound
        }
        if tier == 1 {
            // Low energy: the door stays optional; never a named trip.
            return roll < 0.7 ? .homebound : .neighborhood
        }
        // A real destination needs real time.
        if let minutes = minutesAvailable(from: timeLimit), minutes <= 15 {
            return .neighborhood
        }
        guard hasPlaces else { return .neighborhood }
        let threshold = tier == 2 ? 0.5 : 0.78
        return roll < threshold ? .destination : .neighborhood
    }

    static func deterministicRoll(seed: String) -> Double {
        let bucket = abs("\(seed)-compass-venture".stableHash % 10_000)
        return Double(bucket) / 10_000.0
    }
}

// MARK: - Notice Now (standalone North = Notice)
//
// The Compass Run's North opens a five-step run: it can assume the reader
// already agreed to the sequence and already set constraints. This pool is the
// opposite job: an interrupt in an endless feed. Every line has to survive the
// thumb, so each one is built to the same spec:
//
//   1. Startable in under five seconds from wherever the reader is sitting.
//      Location-blind by default: no standing up, no going outside, no props.
//   2. A curiosity gap. Name a slot the reader cannot fill without looking up
//      from the screen. "The thing that has been watching you" beats "something
//      interesting."
//   3. A target narrow enough to find and wide enough to differ in every room.
//   4. One small physical commitment: look up, touch, hold still, turn around.
//      A body move converts a read into a doing.
//   5. A different answer on the tenth run, because the answer depends on the
//      room and the hour rather than on the reader's personality.
//
// Context pools only ever *add* candidates; the anytime pool always qualifies,
// so a reader with no weather, place, or health signal still gets the full
// experience.
struct NoticeNowPrompt: Identifiable, Equatable {
    var id: String
    /// The imperative. One or two sentences, present tense, second person.
    var text: String
    /// What to write once they have looked. Keeps the capture answerable.
    var capture: String
    var tags: [String]
}

enum NoticeNowRegistry {
    /// Location-blind and always eligible. This is the backbone of the pool.
    static let anytime: [NoticeNowPrompt] = [
        prompt("nn-watching", "Something in this room has been pointed at you this whole time. Find it.",
               "Name the thing and which way it's facing."),
        prompt("nn-oldest", "Without standing up: what's the oldest thing you can see?",
               "Name it and guess its age. Guessing counts."),
        prompt("nn-behind", "Turn around. Whatever's behind you has been getting away with something.",
               "Write what it was up to."),
        prompt("nn-hum", "Stop. There's a sound that's been running the whole time you've been reading.",
               "Name the sound you'd stopped hearing."),
        prompt("nn-worn", "Find the most worn-out thing within reach. Something wore it out.",
               "Write what did the wearing."),
        prompt("nn-notyours", "Find one thing near you that you never actually chose.",
               "Write how it got here."),
        prompt("nn-lean", "Something near you isn't straight. Find it before you fix it.",
               "Write what's leaning and which way."),
        prompt("nn-touch", "Put your hand flat on the nearest surface for five seconds. It has a temperature and an opinion.",
               "Write what it felt like."),
        prompt("nn-smallest", "Find the smallest object you can see from here that somebody manufactured on purpose.",
               "Write it down and what it's for."),
        prompt("nn-edge", "Look at the edge of something instead of the middle of it.",
               "Write what the edge was doing."),
        prompt("nn-waiting", "One thing near you has been waiting longer than everything else.",
               "Name it and say what it's waiting for."),
        prompt("nn-light", "Find where the light in this room is coming from. Then find where it lands.",
               "Write the two places."),
        prompt("nn-stack", "Find something that's been stacked, piled, or shoved. Somebody made that decision fast.",
               "Write what the pile is hiding."),
        prompt("nn-repair", "Find one thing near you that's been mended, taped, propped, or bodged.",
               "Write the repair and whether it's holding."),
        prompt("nn-pocket", "Whatever's in your nearest pocket or bag has no business being there.",
               "Write what it is and why it's still there."),
        prompt("nn-underfoot", "Look down. The floor's been doing all the work.",
               "Write what's on it that shouldn't be."),
        prompt("nn-corner", "There's a corner of this room you haven't looked at in weeks. Look at it now.",
               "Write what's living in it."),
        prompt("nn-loudest", "Find the loudest colour you can see. It's louder than you noticed.",
               "Name the colour and what's wearing it."),
        prompt("nn-almostgone", "Find something nearly used up: nearly empty, nearly out, nearly finished.",
               "Write how much is left."),
        prompt("nn-facing", "Two things near you are facing each other. They weren't put that way on purpose.",
               "Write the pair."),
        prompt("nn-breath", "Take one breath through your nose. This room smells like something.",
               "Write the smell without using the word 'clean'."),
        prompt("nn-handmade", "Find the one thing near you that a person made by hand.",
               "Write it and what the hand got slightly wrong."),
        prompt("nn-moving", "Something in your line of sight is moving right now, very slowly.",
               "Write what it is."),
        prompt("nn-forgotten", "Find something you put down and never picked back up.",
               "Write when you think you put it there."),
        prompt("nn-shadow", "Find a shadow. Now find what's casting it. They don't match.",
               "Write what the shadow is pretending to be."),
        prompt("nn-nearest-word", "Find the nearest printed word that isn't on a screen.",
               "Write the word and where it's printed."),
        prompt("nn-holding", "Something near you is holding something else up right now.",
               "Write the thing and its load."),
        prompt("nn-hands", "Look at your own hands for five seconds like they belong to a stranger.",
               "Write the first thing you noticed.")
    ]

    /// Hour-of-day pools. These lean on what the light and the building are
    /// doing at that hour rather than on what the reader is supposed to feel.
    static let morning: [NoticeNowPrompt] = [
        prompt("nn-m-first", "What's the first thing you touched today? It's still where you left it.",
               "Write it and whether it's still warm.", ["morning"]),
        prompt("nn-m-light", "Morning light lands somewhere different than it did last month. Find the edge of it.",
               "Write where the light stops.", ["morning"]),
        prompt("nn-m-notawake", "One thing in this room is still asleep. It isn't you.",
               "Write what hasn't woken up yet.", ["morning"])
    ]

    static let afternoon: [NoticeNowPrompt] = [
        prompt("nn-a-halfdone", "Find something half-done near you. It stopped for a reason.",
               "Write what stopped it.", ["afternoon"]),
        prompt("nn-a-drift", "Something has moved since this morning without anyone deciding to move it.",
               "Write what drifted.", ["afternoon"])
    ]

    static let evening: [NoticeNowPrompt] = [
        prompt("nn-e-lastlight", "Find the last bright thing in the room. The dark is taking everything else first.",
               "Write what's still holding light.", ["evening"]),
        prompt("nn-e-daywear", "Find the evidence that today happened in this room.",
               "Write the one thing today left behind.", ["evening"]),
        prompt("nn-e-switch", "Somebody turned a light on recently. Find which one, and guess when.",
               "Write the lamp and the hour.", ["evening"])
    ]

    static let night: [NoticeNowPrompt] = [
        prompt("nn-n-awake", "Something in this building is still awake and it isn't a person.",
               "Write what's still running.", ["night"]),
        prompt("nn-n-window", "Look at the window instead of through it. It's showing you the room.",
               "Write what the glass gave back.", ["night"]),
        prompt("nn-n-quietest", "This is the quietest the room gets. One sound survived it.",
               "Write the survivor.", ["night"])
    ]

    /// Weather pools fire from the real forecast, so the prompt is about
    /// something the reader can actually verify at the window.
    static let rain: [NoticeNowPrompt] = [
        prompt("nn-w-rainsound", "It's raining. Find the surface making the best rain sound and go stand near it.",
               "Write the surface and the sound it makes.", ["rain"]),
        prompt("nn-w-rainedge", "Find where the rain stops: an overhang, a sill, a doorway. There's a hard line out there.",
               "Write where the dry begins.", ["rain"])
    ]

    static let wind: [NoticeNowPrompt] = [
        prompt("nn-w-windflag", "The wind's up. Find the nearest thing it's using to show itself.",
               "Write what's moving and how hard.", ["wind"])
    ]

    static let bright: [NoticeNowPrompt] = [
        prompt("nn-w-brightglare", "Find where the sun is currently being a nuisance.",
               "Write what it's making hard to see.", ["bright"])
    ]

    static let cold: [NoticeNowPrompt] = [
        prompt("nn-w-coldest", "Find the coldest thing you're allowed to touch and hold it for five seconds.",
               "Write where the cold seemed to come from.", ["cold"])
    ]

    /// Place pools. These stay startable from a chair: a place tag changes
    /// the furniture, never the effort.
    static let atHome: [NoticeNowPrompt] = [
        prompt("nn-p-home-guest", "If a stranger walked in right now, what's the first thing they'd ask about?",
               "Write what would get the question.", ["home"]),
        prompt("nn-p-home-longest", "Find the thing in this room that's been here the longest.",
               "Write it and roughly how long.", ["home"])
    ]

    static let atWork: [NoticeNowPrompt] = [
        prompt("nn-p-work-sound", "Your workplace makes a sound no other building makes. Find it.",
               "Write the sound without complaining about it.", ["work"]),
        prompt("nn-p-work-personal", "Find the one object here that somebody brought from home.",
               "Write what it is and what it's doing here.", ["work"]),
        prompt("nn-p-work-worn", "Find the most-touched surface in this place. Thousands of hands did that.",
               "Write where the wear shows.", ["work"])
    ]

    static let inPublic: [NoticeNowPrompt] = [
        prompt("nn-p-public-errand", "Pick one stranger and work out what their errand is. You'll be wrong. Guess anyway.",
               "Write the errand you assigned them.", ["public"]),
        prompt("nn-p-public-oldest", "Find the oldest thing in this room that isn't a person.",
               "Write it and what it's outlasted.", ["public"])
    ]

    static let inTransit: [NoticeNowPrompt] = [
        prompt("nn-p-transit-window", "Watch one thing out the window until it's gone. Don't pick something interesting.",
               "Write what you watched leave.", ["transit"]),
        prompt("nn-p-transit-hold", "Everything in here is braced against motion, including you.",
               "Write what's holding on hardest.", ["transit"])
    ]

    /// Tired / low pools. Same structure, less range of motion: these never
    /// ask the reader to get up, and never ask them to feel better.
    static let gentle: [NoticeNowPrompt] = [
        prompt("nn-g-support", "Something is holding your weight right now. Notice exactly where it pushes back.",
               "Write where you're being held.", ["gentle"]),
        prompt("nn-g-nearest", "Don't move. Name the nearest three things without turning your head.",
               "Write the three.", ["gentle"]),
        prompt("nn-g-soft", "Find the softest thing within arm's reach.",
               "Write what makes it soft.", ["gentle"])
    ]

    /// Shadow Wonder siblings. Same five rules, aimed at the worn, dim, or
    /// overlooked edge instead of the bright one, so a Duskthorn reader gets a
    /// card that matches the register rather than a recoloured bright prompt.
    static let shadow: [NoticeNowPrompt] = [
        prompt("nn-s-dust", "Find where the dust has settled thickest. Nobody has needed that spot in a while.",
               "Write the place time forgot.", ["shadow-wonder"]),
        prompt("nn-s-broken", "Find something near you that's broken and still in use.",
               "Write what it does anyway.", ["shadow-wonder"]),
        prompt("nn-s-darkest", "Find the darkest spot in the room without turning on a light.",
               "Write what's in it.", ["shadow-wonder"]),
        prompt("nn-s-stain", "Find a mark, stain, scuff, or scratch. Something happened there and nobody wrote it down.",
               "Write your best guess at the event.", ["shadow-wonder"]),
        prompt("nn-s-unused", "Find the thing you keep meaning to deal with. It's still there.",
               "Write it down without promising to deal with it.", ["shadow-wonder"]),
        prompt("nn-s-behindthe", "Look behind or under the nearest piece of furniture.",
               "Write what's been hiding.", ["shadow-wonder"])
    ]

    static var all: [NoticeNowPrompt] {
        anytime + morning + afternoon + evening + night
            + rain + wind + bright + cold
            + atHome + atWork + inPublic + inTransit + gentle + shadow
    }

    /// Picks the prompt for right now. Context tags add weight rather than
    /// filtering, so a matching pool wins when it exists and the anytime pool
    /// still carries the day when no signal is available. The slot jitter keeps
    /// consecutive refreshes from repeating.
    static func prompt(
        inputs: BookSourceInputs,
        now: Date = Date(),
        dayID: String = BookDay.today().id,
        calendar: Calendar = .current,
        shadowVariant: Bool = false
    ) -> NoticeNowPrompt {
        let pool = shadowVariant ? shadow : all.filter { !$0.tags.contains("shadow-wonder") }
        guard !pool.isEmpty else {
            return prompt("nn-fallback", "Look up. The first thing you see has been there the whole time.", "Write what it was.")
        }
        let contextTags = tags(inputs: inputs, now: now, calendar: calendar)
        let slot = SurfaceCadence.slotID(for: now, hours: 2)
        let scored = pool.map { candidate -> (NoticeNowPrompt, Int) in
            let affinity = contextTags.intersection(Set(candidate.tags)).count * 20
            let jitter = abs("\(dayID)-\(slot)-\(candidate.id)-notice-now".stableHash % 13)
            return (candidate, affinity + jitter)
        }
        return scored.max { $0.1 < $1.1 }?.0 ?? pool[0]
    }

    static func tags(
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) -> Set<String> {
        var result: Set<String> = []
        switch calendar.component(.hour, from: now) {
        case 5..<11: result.insert("morning")
        case 11..<17: result.insert("afternoon")
        case 17..<21: result.insert("evening")
        default: result.insert("night")
        }
        let weather = "\(inputs.weather?.phrase ?? "") \(inputs.weather?.forecast ?? "")".lowercased()
        if weather.contains("rain") || weather.contains("drizzle") || weather.contains("shower") { result.insert("rain") }
        if weather.contains("wind") || weather.contains("gust") { result.insert("wind") }
        if weather.contains("sun") || weather.contains("clear") { result.insert("bright") }
        if weather.contains("snow") || weather.contains("ice") || weather.contains("frost") { result.insert("cold") }
        switch inputs.currentPlaceContext {
        case .home: result.insert("home")
        case .work, .library: result.insert("work")
        case .cafe, .store: result.insert("public")
        case .transit: result.insert("transit")
        default: break
        }
        let body = "\(inputs.body?.status ?? "") \(inputs.body?.phrase ?? "")".lowercased()
        if body.contains("low") || body.contains("tired") || body.contains("rest") || body.contains("depleted") {
            result.insert("gentle")
        }
        return result
    }

    private static func prompt(_ id: String, _ text: String, _ capture: String, _ tags: [String] = []) -> NoticeNowPrompt {
        NoticeNowPrompt(id: id, text: text, capture: capture, tags: tags)
    }
}

// MARK: - The Wonder Spark Registry
//
// North = Notice begins with an "I wonder..." A large tagged pool keeps the
// question surprising: selection favors sparks that fit the concierge mode,
// the hour, and the weather, with slot rotation so consecutive runs differ.

struct WonderSpark: Identifiable, Equatable {
    var id: String
    var text: String
    var modes: [WonderConciergeMode]
    var tags: [String]
}

enum WonderSparkRegistry {
    static func spark(
        for mode: WonderConciergeMode,
        inputs: BookSourceInputs,
        now: Date = Date(),
        dayID: String = BookDay.today().id
    ) -> String {
        let pool = sparks.filter { $0.modes.contains(mode) }
        guard !pool.isEmpty else { return "I wonder what is asking for attention nearby?" }

        let hour = Calendar.current.component(.hour, from: now)
        var contextTags: Set<String> = []
        switch hour {
        case 5..<11: contextTags.insert("morning")
        case 17..<21: contextTags.insert("evening")
        case 21..<24, 0..<5: contextTags.insert("night")
        default: break
        }
        let weather = (inputs.weather?.phrase ?? "").lowercased()
        if weather.contains("rain") || weather.contains("drizzle") { contextTags.insert("rain") }
        if weather.contains("snow") || weather.contains("ice") { contextTags.insert("cold") }
        if weather.contains("sun") || weather.contains("clear") { contextTags.insert("bright") }
        if weather.contains("wind") { contextTags.insert("wind") }
        let body = (inputs.body?.phrase ?? "").lowercased()
        if body.contains("low") || body.contains("tired") || body.contains("rest") { contextTags.insert("gentle") }

        let slot = SurfaceCadence.slotID(for: now, hours: 2)
        let scored = pool.map { spark -> (WonderSpark, Int) in
            let affinity = contextTags.intersection(Set(spark.tags)).count * 6
            let jitter = abs("\(dayID)-\(slot)-\(spark.id)-spark".stableHash % 11)
            return (spark, affinity + jitter)
        }
        return scored.max { $0.1 < $1.1 }?.0.text ?? pool[0].text
    }

    private static func spark(_ id: String, _ text: String, _ modes: [WonderConciergeMode], _ tags: [String] = []) -> WonderSpark {
        WonderSpark(id: id, text: text, modes: modes, tags: tags)
    }

    /// Night-tuned sparks bound into the Nocturne Folio; they join the pool
    /// when the folio is bound to the save.
    static let nocturneSparks: [WonderSpark] = [
        spark("nf-window-lit", "I wonder which window on my street is lit right now, and what honest errand the light is running?", [.obscure, .vibe], ["night"]),
        spark("nf-night-smell", "I wonder what the night smells like tonight that the day didn't?", [.recovery, .vibe], ["night"]),
        spark("nf-house-settle", "I wonder which part of the house settles first when everyone stops moving?", [.closeToHome, .recovery], ["night", "gentle"]),
        spark("nf-moon-furniture", "I wonder what the moon is rearranging in the yard while nobody supervises?", [.obscure, .scavenger], ["night"]),
        spark("nf-last-car", "I wonder where the last car I can hear is going, and whether they know?", [.vibe, .obscure], ["night"]),
        spark("nf-dark-rooms", "I wonder what the unlit rooms of my home do differently when I'm not in them?", [.closeToHome, .obscure], ["night"])
    ]

    static var sparks: [WonderSpark] {
        PackEntitlements.isUnlocked("nocturne-folio") ? baseSparks + nocturneSparks : baseSparks
    }

    static let baseSparks: [WonderSpark] = [
        // Close to home: the room is stranger than it admits.
        spark("oldest-object", "I wonder what the oldest thing within ten steps of me is, and how it got here?", [.closeToHome, .recovery]),
        spark("room-archaeology", "I wonder what a careful stranger could deduce about this week from this room alone?", [.closeToHome, .obscure]),
        spark("drawer-stranger", "I wonder what the strangest thing in the nearest drawer is doing with its life?", [.closeToHome, .scavenger]),
        spark("wall-history", "I wonder which mark on these walls has a story nobody remembers?", [.closeToHome, .obscure]),
        spark("window-theater", "I wonder what the nearest window is showing right now that it will never show again?", [.closeToHome, .recovery], ["morning", "evening"]),
        spark("light-landing", "I wonder where the light lands first in this room, and what it chooses to touch?", [.closeToHome], ["morning", "bright"]),
        spark("gravity-objects", "I wonder which object in this room would be hardest to explain to the year 1900?", [.closeToHome, .vibe]),
        spark("home-sounds", "I wonder how many different sounds this building makes when I hold completely still?", [.closeToHome, .recovery], ["night", "gentle"]),
        spark("borrowed-things", "I wonder how many things in this room I never actually chose?", [.closeToHome, .obscure]),
        spark("repair-marks", "I wonder what has been mended around here, and whether the mend shows?", [.closeToHome], ["gentle"]),
        spark("door-census", "I wonder which door in my home opens most often, and which has almost given up hope?", [.closeToHome, .scavenger]),
        spark("ceiling-country", "I wonder what lives in the parts of this room above eye level that I never visit?", [.closeToHome]),

        // Budget: rich on pocket change.
        spark("two-dollar-luxury", "I wonder what the most luxurious thing I can do for under two dollars actually is?", [.budget, .vibe]),
        spark("free-museum", "I wonder what the best free exhibit within walking distance is: a window, a tree, a bulletin board?", [.budget, .obscure], ["bright"]),
        spark("expensive-smell", "I wonder where the most expensive-smelling free air in town is?", [.budget, .scavenger]),
        spark("penny-bright", "I wonder what the shiniest thing I can find without spending anything is?", [.budget], ["bright"]),
        spark("library-oracle", "I wonder what the library would hand me today if I let shelf chance decide?", [.budget, .obscure]),
        spark("sample-day", "I wonder which place nearby gives something small away free, and who decided that?", [.budget]),
        spark("quarter-tour", "I wonder how grand a tour I could give of this neighborhood using only things that cost nothing to see?", [.budget, .obscure], ["bright"]),
        spark("best-bench", "I wonder which free seat in town has the best view nobody pays for?", [.budget, .vibe], ["bright", "evening"]),

        // Obscure: strange little stories.
        spark("oldest-sign", "I wonder what the oldest sign in town still says, and to whom?", [.obscure, .scavenger]),
        spark("ghost-paint", "I wonder where a painted-over word or picture is still faintly visible nearby?", [.obscure]),
        spark("desire-path", "I wonder where people have voted with their feet: a worn shortcut the planners never drew?", [.obscure], ["bright"]),
        spark("lost-glove", "I wonder where the nearest lost glove, sock, or key is waiting, and what its other half is doing?", [.obscure, .scavenger], ["cold"]),
        spark("plaque-nobody", "I wonder what the nearest plaque or memorial actually commemorates, and who last read it?", [.obscure]),
        spark("name-origin", "I wonder why the street I use most is named what it's named?", [.obscure]),
        spark("oldest-tree", "I wonder which tree in this neighborhood was here before any of the houses?", [.obscure, .recovery], ["bright", "wind"]),
        spark("back-of-things", "I wonder what the backs of buildings on my usual route look like: the side they don't dress up?", [.obscure]),
        spark("water-route", "I wonder where the rain that lands on my roof eventually ends up?", [.obscure], ["rain"]),
        spark("midnight-business", "I wonder what is open right now that has no obvious reason to be?", [.obscure], ["night"]),

        // Vibe: mood as compass needle.
        spark("mood-color", "I wonder what color today's mood is, and where that color is hiding nearby?", [.vibe, .recovery]),
        spark("weather-twin", "I wonder what in my house feels exactly like today's weather?", [.vibe], ["rain", "cold", "bright", "wind"]),
        spark("soundtrack-street", "I wonder what song this hour would choose for itself if I let it?", [.vibe], ["evening"]),
        spark("temperature-feelings", "I wonder where the warmest and coldest spots within reach are, and which one today needs?", [.vibe, .closeToHome], ["cold", "gentle"]),
        spark("borrowed-calm", "I wonder which nearby thing is the calmest, and whether it's contagious?", [.vibe, .recovery], ["gentle"]),
        spark("hour-flavor", "I wonder what this exact hour tastes like, and what snack would agree with it?", [.vibe, .budget]),

        // Scavenger: collectible reality.
        spark("triangle-hunt", "I wonder how many accidental triangles are hiding in plain sight here?", [.scavenger, .closeToHome]),
        spark("alphabet-walk", "I wonder how far through the alphabet I can get, finding things that start with each letter?", [.scavenger], ["bright"]),
        spark("face-pareidolia", "I wonder where the nearest accidental face is: in a socket, a car grill, a knot of wood?", [.scavenger, .closeToHome]),
        spark("seven-greens", "I wonder how many different greens exist within a hundred steps of my door?", [.scavenger], ["bright"]),
        spark("texture-trio", "I wonder whether I could collect the roughest, smoothest, and softest things in this whole place without leaving it?", [.scavenger, .recovery], ["gentle"]),
        spark("number-hunt", "I wonder where today's date is hiding in the wild: on signs, receipts, license plates?", [.scavenger]),
        spark("shadow-collection", "I wonder which shadow nearby is the most elaborate, and what's casting it?", [.scavenger], ["bright", "evening"]),
        spark("circle-census", "I wonder whether anything around here is perfectly round, or whether every circle nearby is faking it?", [.scavenger, .closeToHome]),
        spark("oldest-newest", "I wonder what the oldest and newest things I can see right now are, side by side?", [.scavenger, .closeToHome]),
        spark("tiny-doors", "I wonder where the smallest door, hatch, or opening in this building is, and what uses it?", [.scavenger, .obscure]),

        // Recovery: noticing without pushing.
        spark("breath-weather", "I wonder what my breath would report about this exact minute if I let it speak?", [.recovery], ["gentle", "night"]),
        spark("soft-inventory", "I wonder where the softest place in this whole building is, and whether I am allowed to sit in it?", [.recovery], ["gentle"]),
        spark("holding-things", "I wonder how many things would have to give up before I actually hit the ground, and whether I could visit each one?", [.recovery], ["gentle"]),
        spark("slow-clock", "I wonder what the slowest thing happening near me today is, and whether I can catch it in the act twice?", [.recovery], ["night", "gentle"]),
        spark("kind-light", "I wonder which light in this place is the kindest, and whether I can go and sit inside it for a minute?", [.recovery], ["evening", "night"]),
        spark("one-good-sound", "I wonder what the single most comforting sound within earshot is right now?", [.recovery], ["gentle", "rain"]),
        spark("blanket-geology", "I wonder what landscape the folds of the nearest cloth would be, if I were very small?", [.recovery, .closeToHome], ["gentle"]),

        // Wide-mode wonders: fit nearly anywhere.
        spark("almost-said", "I wonder what the last thing this room almost heard somebody say was?", [.closeToHome, .vibe, .obscure]),
        spark("future-fossil", "I wonder which object near me would make the best fossil for future archaeologists?", [.closeToHome, .scavenger, .obscure]),
        spark("secret-effort", "I wonder what nearby is working hard while looking effortless: a hinge, a stem, a seam?", [.closeToHome, .recovery, .scavenger]),
        spark("first-visitor", "I wonder what visited my street this morning before anyone was awake?", [.obscure, .vibe], ["morning"]),
        spark("rain-instruments", "I wonder which surfaces outside play the rain best: what's the percussion section?", [.vibe, .obscure], ["rain"]),
        spark("wind-errands", "I wonder what the wind is moving around the neighborhood right now, and where it's taking it?", [.vibe, .obscure], ["wind"]),
        spark("snow-ledger", "I wonder what tracks the cold has recorded since last night, and who wrote them?", [.obscure, .scavenger], ["cold"]),
        spark("dusk-handover", "I wonder what changes hands in the neighborhood at dusk, which lights take over from the sun?", [.vibe, .obscure], ["evening"]),
        spark("night-shift", "I wonder what is awake on my street right now besides me?", [.recovery, .obscure], ["night"]),
        spark("morning-rehearsal", "I wonder what the day is rehearsing outside before it fully begins?", [.vibe, .recovery], ["morning"]),
        spark("forgotten-pocket", "I wonder what the pockets of my least-worn coat have been keeping for me?", [.closeToHome, .scavenger], ["cold"]),
        spark("appliance-choir", "I wonder which appliance hums the lowest note in the house choir?", [.closeToHome, .scavenger], ["night"]),
        spark("plant-opinion", "I wonder which plant nearby is having the best week, and what its secret is?", [.recovery, .obscure], ["bright"]),
        spark("step-counter", "I wonder exactly how many steps it takes to cross my home at its longest, walked like it matters?", [.closeToHome, .scavenger], ["gentle"]),
        spark("handwriting-wild", "I wonder where the nearest handwriting in the wild is, not printed, actually written by a hand?", [.obscure, .scavenger]),
        spark("blue-hour", "I wonder which blue, of all the blues I can find right now, is the bluest?", [.scavenger, .vibe], ["evening", "bright"]),
        spark("usefulness-retired", "I wonder what near me used to be essential and is now purely decorative?", [.closeToHome, .obscure]),
        spark("smallest-kindness", "I wonder what the smallest act of kindness visible from here is: a coaster, a propped door, a refilled bowl?", [.recovery, .vibe], ["gentle"]),
        spark("echo-spots", "I wonder where the best echo within a hundred steps lives?", [.scavenger, .obscure], ["bright"]),
        spark("crooked-true", "I wonder what nearby is charmingly crooked, and whether anyone ever tried to straighten it?", [.closeToHome, .obscure]),
        spark("paper-trail", "I wonder what the oldest piece of paper in this room says?", [.closeToHome, .obscure], ["night", "gentle"]),
        spark("threshold-count", "I wonder how many thresholds I cross on an ordinary day without noticing a single one?", [.vibe, .recovery], ["morning"]),
        spark("borrowed-light", "I wonder which rooms in my home never get their own light, only borrowed light?", [.closeToHome, .obscure], ["evening"]),
        spark("season-leak", "I wonder where the current season is leaking into the house: a smell, a draft, a quality of light?", [.closeToHome, .vibe], ["cold", "bright", "rain"]),
        spark("instruction-art", "I wonder where the most beautiful purely functional thing nearby is: a fire escape, a gutter, a knot?", [.obscure, .vibe]),
        spark("waiting-things", "I wonder what near me has been waiting the longest: for use, for repair, for someone to notice?", [.closeToHome, .recovery], ["gentle"])
    ]
}

// MARK: - Story Arcs
//
// The season-scale spine: when one thread runs hot for days, it becomes the
// current arc and walks the phases (rising, climax, resolution, fading)
// bending Story Pages toward it until it settles into the past.

struct StoryArc: Codable, Equatable {
    var threadID: String
    var title: String
    var phase: StoryThreadPhase
    var startedAt: Date
    var phaseAdvancedAt: Date
}

enum ArcKeeper {
    static let promotionEventThreshold = 3
    static let promotionWindow: TimeInterval = 72 * 3600
    static let minimumPhaseDuration: TimeInterval = 2 * 86_400
    static let phaseEventThreshold = 2
    /// Threads that touch nearly every page never get to be "the" arc.
    static let ambientThreadIDs: Set<String> = ["ordinary-magic"]

    static func threadEventCount(threadID: String, events: [NarrativeEvent], since: Date) -> Int {
        events.filter { $0.createdAt >= since && ($0.effect.threadWeightDeltas[threadID] ?? 0) > 0 }.count
    }

    static func evaluate(
        current: StoryArc?,
        events: [NarrativeEvent],
        lastCompletedThreadID: String?,
        now: Date = Date()
    ) -> (arc: StoryArc?, announcement: String?) {
        if var arc = current {
            let phaseAge = now.timeIntervalSince(arc.phaseAdvancedAt)
            let eventsThisPhase = threadEventCount(threadID: arc.threadID, events: events, since: arc.phaseAdvancedAt)

            switch arc.phase {
            case .fading:
                if phaseAge >= minimumPhaseDuration {
                    return (nil, "The arc \u{201C}\(arc.title)\u{201D} settles into the past. The Stacks shelve it gently; its echoes remain.")
                }
            case .rising, .climax, .resolution:
                if phaseAge >= minimumPhaseDuration, eventsThisPhase >= phaseEventThreshold {
                    let next: StoryThreadPhase = arc.phase == .rising ? .climax : (arc.phase == .climax ? .resolution : .fading)
                    arc.phase = next
                    arc.phaseAdvancedAt = now
                    let line: String
                    switch next {
                    case .climax:
                        line = "The arc \u{201C}\(arc.title)\u{201D} turns toward its climax. The Stacks hold their breath."
                    case .resolution:
                        line = "The arc \u{201C}\(arc.title)\u{201D} begins to resolve. Debts come due, gently."
                    default:
                        line = "The arc \u{201C}\(arc.title)\u{201D} is fading into echoes."
                    }
                    return (arc, line)
                }
            default:
                break
            }
            return (arc, nil)
        }

        // No arc: promote the hottest non-ambient thread, with a cooldown on
        // the one that just finished.
        let since = now.addingTimeInterval(-promotionWindow)
        var counts: [String: Int] = [:]
        for event in events where event.createdAt >= since {
            for (threadID, delta) in event.effect.threadWeightDeltas where delta > 0 {
                guard !ambientThreadIDs.contains(threadID), threadID != lastCompletedThreadID else { continue }
                counts[threadID, default: 0] += 1
            }
        }
        guard let (threadID, count) = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }),
              count >= promotionEventThreshold else {
            return (nil, nil)
        }
        let title: String
        if let thread = NarrativePackRegistry.threads.first(where: { $0.id == threadID }) {
            title = thread.title
        } else if let organicTitle = OrganicStoryThreadSynthesizer.title(forOrganicThreadID: threadID) {
            title = organicTitle
        } else {
            return (nil, nil)
        }
        let arc = StoryArc(
            threadID: threadID,
            title: title,
            phase: .rising,
            startedAt: now,
            phaseAdvancedAt: now
        )
        return (arc, "A story is rising in the Stacks: \u{201C}\(title)\u{201D} has become the current arc.")
    }

    static func directive(for phase: StoryThreadPhase) -> String {
        switch phase {
        case .rising:
            return "The arc is RISING: gather allies, obstacles, and small omens around this thread. Raise the stakes one honest notch; promise more than you pay."
        case .climax:
            return "The arc is at its CLIMAX: this scene should burn the thread's central tension at full flame: something small but irreversible happens, at household scale. No cliffhanger-dodging."
        case .resolution:
            return "The arc is RESOLVING: pay one debt the arc created. Let a consequence land and a character change their behavior because of it."
        case .fading:
            return "The arc is FADING: it appears only as echoes now: a reference, a leftover object, a changed habit. Do not reignite it."
        default:
            return "Let the arc thread breathe in the background."
        }
    }
}
