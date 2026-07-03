import Foundation


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
        let rollText = "rolled \(roll) against \(threshold)"
        if backlash > 0 {
            return "\(attackerName) \(rollText): \(outcome.title); the attack backfired for \(backlash) Belief."
        }
        if dealt > 0 {
            return "\(attackerName) \(rollText): \(outcome.title); \(targetName) lost \(dealt) Belief."
        }
        return "\(attackerName) \(rollText): \(outcome.title); nothing landed."
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
/// cross-system effect — Book Jumping's answer to a Fae gift.
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
    static let startCost = 1
    static let returnReward = 6
    static let maxDepth = 4
    static let borrowedRuleDays = 4
    static let coldDays = 5

    /// Going one beat deeper costs escalating Belief; the Nothing charges rent on depth.
    static func advanceCost(depth: Int) -> Int { max(0, depth - 1) }

    /// Returning pays the base reward plus a bonus for how deep you dared, but
    /// only when you bring a real souvenir home.
    static func returnReward(depth: Int, hasSouvenir: Bool) -> Int {
        guard hasSouvenir else { return 1 }
        return returnReward + max(0, depth - 1) * 2
    }

    static let publicDomainShelf: [BookJumpWork] = [
        BookJumpWork(
            id: "alice-wonderland",
            title: "Alice's Adventures in Wonderland",
            author: "Lewis Carroll",
            gutenbergID: "11",
            world: "a bright impossible country where logic wears gloves and every rule has teeth",
            arrival: "You land beside a corridor of doors, with the sound of a rabbit-sized hurry somewhere ahead.",
            nothing: "The Nothing appears as blank labels, jokes without punchlines, and paths that forget where they were going.",
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
            nothing: "The Nothing comes as color draining from the road and companions forgetting what they were looking for.",
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
            nothing: "The Nothing wears the face of certainty: first impressions hardening before anyone can revise them.",
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
            nothing: "The Nothing gathers wherever maker and made refuse to recognize one another.",
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
            nothing: "The Nothing moves as invitation without consent and fog that edits the edges of memory.",
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
            nothing: "The Nothing appears as a locked heart and a future no one speaks kindly of.",
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
            nothing: "The Nothing hides in assumptions so tidy they stop the eye from looking again.",
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
            nothing: "The Nothing appears as neglect: rooms unaired, gates unopened, living things not spoken to.",
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
            nothing: "The Nothing comes as greed: every landmark flattened into what can be taken from it.",
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
            nothing: "The Nothing wears obsession: one symbol swollen until it erases the rest of the world.",
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
            nothing: "The Nothing appears when enchantment becomes a refusal to see what is really there.",
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
            nothing: "The Nothing comes as forgetting: names, homes, oaths, and the shape of return.",
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
            return "You and \(title) keep meeting — a constellation is forming between your real life and its pages."
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

    static func start(from surface: SurfacePage, now: Date = Date()) -> BookJumpState {
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
        return BookJumpState(active: active, returned: [])
    }

    static func advance(_ state: BookJumpState, line: String, direction: String? = nil, now: Date = Date()) -> BookJumpState {
        guard var active = state.active else { return state }
        active.depth = min(maxDepth, active.depth + 1)
        // The deeper you are, the more rent the Nothing charges per page.
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
        // effect — but only when a true souvenir came back with you.
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

    /// The Nothing collapses an unstabilized jump: you slip back empty-handed,
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
            outcome: "The page dissolved into the Nothing; you slipped back with empty hands."
        )
        var updated = state
        updated.active = nil
        updated.returned = ([collapsed] + state.returned).prefix(24).map { $0 }
        updated.coldBooks[active.bookID] = Calendar.current.date(byAdding: .day, value: coldDays, to: now) ?? now.addingTimeInterval(Double(coldDays) * 86_400)
        updated.borrowedRules = activeRules(in: state.borrowedRules, at: now)
        return (updated, lost, active.title)
    }

    /// Overnight, an active jump left unstable lets the Nothing gain a margin.
    /// If it overruns, the jump collapses. Returns the new state and any loss.
    static func dailyDecay(_ state: BookJumpState, now: Date = Date()) -> (state: BookJumpState, collapsed: Bool, lostBelief: Int, bookTitle: String) {
        guard let active = state.active else {
            // No active jump: just prune expired rules.
            var pruned = state
            pruned.borrowedRules = activeRules(in: state.borrowedRules, at: now)
            return (pruned, false, 0, "")
        }
        let calendar = Calendar.current
        let dayGap = calendar.dateComponents([.day], from: active.updatedAt, to: now).day ?? 0
        guard dayGap >= 1 else {
            var pruned = state
            pruned.borrowedRules = activeRules(in: state.borrowedRules, at: now)
            return (pruned, false, 0, "")
        }
        var advanced = active
        advanced.degradation += 1
        if advanced.degradation > 4 {
            let result = collapse(state, now: now)
            return (result.state, true, result.lostBelief, result.bookTitle)
        }
        advanced.updatedAt = now
        advanced.beats.append(BookJumpBeat(
            id: "beat-decay-\(Int(now.timeIntervalSince1970))",
            at: now,
            action: .advance,
            depth: advanced.depth,
            degradation: advanced.degradation,
            line: "The page blurred a little further overnight."
        ))
        var updated = state
        updated.active = advanced
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
    /// We never claim to know the book's text — the Book improvises a threshold
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
            world: "a book you named yourself — \(title) — whose weather the Book has not read but agrees to enter with you",
            arrival: "The Spine opens onto \(title). The Book steps in beside you, reading as it goes.",
            nothing: "The Nothing here is whatever this book most fears forgetting; name a true thing and it loses its grip.",
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

        Keeping this page spends \(startCost) Belief and opens a controlled Book Jump. You remain yourself. The page takes one step only.
        """
        return SurfacePage(
            id: "\(source.id)-start-\(work.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .bookJump,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: score,
            reason: "A public-domain book is close enough for a safe one-page jump.",
            prompt: "Book Jump: \(work.title)",
            detail: "Step through a known public-domain text. One beat, one anchor, one safe way back.",
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

            Keeping this page moves one beat deeper. The Nothing pressure is \(active.degradation)/4.
            """
        case .stabilize:
            body = """
            The page is beginning to blur.

            \(active.nothing)

            Name one true real-world detail in the margin, then keep this page. The Book will use it as ballast and lower the Nothing pressure.
            """
        case .return:
            body = """
            The Spine is visible.

            You have gone deep enough into \(active.title). The Book wants one sentence from the journey before it closes the door.

            Write a one-sentence souvenir in the margin. Keeping this page returns you and restores \(returnReward) Belief.
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
                    "bookJumpBeliefDelta": action == .return ? "\(returnReward)" : "0",
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
            return "The Book has found a public-domain door."
        case .advance:
            return "\(active.title) is open and stable enough for one more beat."
        case .stabilize:
            return "The Nothing is blurring the page; the jump needs ballast."
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

    /// Concrete, canonical furniture for each shelf book — the named places,
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
            openingScene: "the laboratory the night the thing first breathes — guttering candle, the dull yellow eye opening, Victor's horror as the creature's hand stirs."),
        "dracula": BookCanon(
            landmarks: ["the Borgo Pass and the calèche driven by red eyes", "Castle Dracula's crumbling battlements", "the Count's cold handshake and growing youth", "the three pale brides and their laughter", "the peasant woman's crucifix pressed into your hand", "Harker's locked journal", "wolves answering the Count — 'the children of the night'"],
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
        if let entity = inputs.customCastMembers.max(by: { left, right in
            let leftBelief = left.baseBelief + (inputs.entityBeliefOffsets[left.id] ?? 0)
            let rightBelief = right.baseBelief + (inputs.entityBeliefOffsets[right.id] ?? 0)
            if leftBelief == rightBelief { return left.narrativeWeight < right.narrativeWeight }
            return leftBelief < rightBelief
        }) {
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
/// return, changed — the "promise" that lets a beat-by-beat improvised vignette
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
/// resolution of THIS SAME change — that is what makes the player's path
/// matter: Slice/Arc/Surprise land different facts, not different moods.
struct StoryTurn: Codable, Equatable {
    var kind: StoryTurnKind
    var character: String           // name the turn centers
    var want: String                // from goals / unwrittenInterest
    var obstacle: String            // from faults / relationship tension
    var statement: String           // "by the end, this is true" — the contract
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

    /// True when two scenes open with effectively the same line — the repetition
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
    /// Choice ids arrive in two conventions — "sliceoflife" from the draft
    /// parser, "slice-of-life" from the packet. Normalize before lookup so the
    /// result rail and the landing instruction actually fire.
    static func resolve(_ landings: [String: String], choiceID: String) -> String? {
        let compact = choiceID.lowercased().filter { $0.isLetter || $0.isNumber }
        let key = ["sliceoflife": "slice-of-life",
                   "progressarc": "progress-arc",
                   "surprise": "surprise"][compact] ?? choiceID
        return landings[key]?.nonEmpty
    }
}

/// The shape of a concrete, interpersonal scene-want — one person wanting a
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

    /// The concrete, person-centered obstacle — never "their own caution".
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

enum StoryScenePacketBuilder {
    static func packet(for day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> StoryScenePacket {
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
        let greyLevel = NothingTide.greyLevel(
            quietDays: inputs.quietDays,
            narrativeHeat: inputs.narrative?.recentEventCount ?? 0,
            distressActive: false,
            celebrationGreyShift: inputs.nothingGreyOffset
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
        let grounding = grounding(for: day, inputs: inputs, realSignals: realSignals, memories: selectedEntityMemories, now: now)
        let recipePick = selectRecipe(
            tags: tags, entities: availableEntities(inputs: inputs), thread: primaryThread, grounding: grounding,
            hasNothingPressure: greyLevel > 0, inputs: inputs, day: day, slot: slot, now: now
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
        let blueprint = recipePick.flatMap { picked in
            makeBlueprint(packID: picked.packID, recipe: picked.recipe, grounding: grounding,
                entities: selectedEntities, thread: primaryThread, form: storyForm,
                slotKey: "\(day.id)-\(slot)")
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
            id: "story-packet-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 4))",
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
        let kept = (day.capturedPages + inputs.days.flatMap(\.capturedPages))
            .sorted { $0.createdAt > $1.createdAt }
            .first {
                now.timeIntervalSince($0.createdAt) <= 45 * 86_400
                    && (!$0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.promptText.isEmpty)
            }
        if let kept {
            let text = kept.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? kept.promptText
            return StoryGrounding(kind: .keptPage, sourceID: kept.id,
                text: "A kept \(kept.type.shortTitle) page says: \(text.bookPreviewSentenceLimit(2))")
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
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dayPart = hour < 6 ? "before dawn" : hour < 12 ? "morning" : hour < 17 ? "afternoon" : hour < 22 ? "evening" : "late night"
        let month = calendar.component(.month, from: now)
        let season = [12, 1, 2].contains(month) ? "winter" : [3, 4, 5].contains(month) ? "spring" : [6, 7, 8].contains(month) ? "summer" : "autumn"
        return StoryGrounding(kind: .timeAndSeason, sourceID: "clock-season", text: "It is a \(season) \(dayPart) in the player's real day.")
    }

    private static func selectRecipe(
        tags: Set<String>, entities: [NarrativeWorldEntity], thread: NarrativeStoryThread?,
        grounding: StoryGrounding, hasNothingPressure: Bool, inputs: BookSourceInputs,
        day: BookDay, slot: String, now: Date
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
            if requirements.contains(.rivalryEdge) && !StoryFormRegistry.hasRivalryEdge(among: entities) { return false }
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
        return pool.max { left, right in
            func score(_ item: (packID: String, recipe: StoryRecipe)) -> Int {
                let affinity = tags.intersection(Set(item.recipe.preferredTags)).count * 4
                let consequenceBoost = min(max(inputs.storyRecipeBoosts[item.recipe.id] ?? 0, 0), 12)
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
                return item.recipe.baseWeight + affinity + consequenceBoost + souvenirDoorBoost + sceneBias - recency
                    + abs("\(day.id)-\(slot)-\(item.recipe.id)-recipe".stableHash % 5)
            }
            return score(left) < score(right)
        }
    }

    private static func makeBlueprint(
        packID: String, recipe: StoryRecipe, grounding: StoryGrounding,
        entities: [NarrativeWorldEntity], thread: NarrativeStoryThread?, form: StoryForm,
        slotKey: String
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
            "form": form.name
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
        return StorySceneBlueprint(
            recipeID: recipe.id, recipeName: recipe.name, recipePackID: packID, sceneMode: recipe.sceneMode,
            leadID: lead.id, leadName: lead.name, companionID: companion?.id, companionName: companion?.name,
            premise: fill(recipe.premiseTemplate), grounding: grounding, beats: StoryVignetteBeats.snackSized(recipe.beats.map(fill)),
            groundingDirective: fill(recipe.groundingDirective), toneDirective: fill(recipe.toneDirective),
            choiceDirective: fill(recipe.choiceDirective), continuationDirective: fill(recipe.continuationDirective),
            turn: turn
        )
    }

    /// Builds the page's promise: one concrete seed to plant in the opening and
    /// the question the resolution must answer. Chosen deterministically from
    /// the already-selected material so it is fixed before any prose is
    /// generated — the opening and the ending then reference the same thing,
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
    /// flavor in the prompt — never the literal want — which is what stops the
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
        let statement = "By the end, \(b) settles \(a)'s want — \(intent.want) — with a yes, a no, or a swerve."
        let landings: [String: String] = [
            "slice-of-life": "\(b) \(act), quietly and just to \(a); the bond between them shifts a notch.",
            "progress-arc": "\(b) \(act) out loud, and it moves \(threadTitle) a real step.",
            "surprise": "The answer swerves — \(b) does the opposite, or it lands on someone other than \(a) entirely."
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
    /// want — only as flavor downstream.
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

        // A concrete, physical thing at stake — an object in the scene, else a
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
            let candidate = candidates[packetStableIndex(for: "\(slotKey)-recipe-cast-\(result.count)", count: candidates.count)]
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
        let count = min(6, pool.count)
        let index = packetStableIndex(for: "\(slotKey)-story-lead-character", count: count)
        return pool[index]
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
                    pressures.append("\(a) and \(b) have grown tense lately — let that friction show.")
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
        // where we can, to a relationship between people — not to objects.
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
        // effect, so the result writer resolves the Turn — not the mood — down
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

enum GossipSimulationBuilder {
    static func surface(for day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> SurfacePage {
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
            reason: "The story field moved while the Book was half-open.",
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
        let count = min(3, max(2, 1 + day.capturedPages.count / 3))
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
        if let readerEcho {
            consequences.append("The margins matched it to one of the reader's own kept pages: \"\(readerEcho)\"")
        }
        if let constellationHook {
            consequences.append(constellationHook)
        }
        if let relationshipMove {
            switch relationshipMove.kind {
            case .invest:
                consequences.append("\(relationshipMove.actorName) invested \(relationshipMove.amount) Belief in \(relationshipMove.targetName); they grew warmer.")
            case .attack:
                consequences.append("\(relationshipMove.actorName) chipped \(relationshipMove.amount) Belief from \(relationshipMove.targetName); the air between them tightened.")
            }
        }
        if let pageBeliefMove {
            switch pageBeliefMove.kind {
            case .invest:
                consequences.append("\(pageBeliefMove.actorName) gave \(pageBeliefMove.amount) Belief to \(pageBeliefMove.sourceTitle) Pages; that kind of page brightened.")
            case .attack:
                consequences.append("\(pageBeliefMove.actorName) tried to take \(pageBeliefMove.amount) Belief from \(pageBeliefMove.sourceTitle) Pages; that kind of page cooled.")
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
            pageBeliefMove: pageBeliefMove
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
        (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
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
            .map(\.0)
    }

    private static func rankedThreads(tags: Set<String>, inputs: BookSourceInputs, seed: Int) -> [NarrativeStoryThread] {
        let organicBoosts = OrganicStoryThreadSynthesizer.boosts(inputs: inputs)
        return OrganicStoryThreadSynthesizer.availableThreads(inputs: inputs, tags: tags)
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
            .map(\.0)
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
                return "\(move.summaryLine) No talisman Belief changed."
            }
            return "\(move.summaryLine) \(move.targetTalismanName) \(delta > 0 ? "gained" : "lost") \(abs(delta)) Belief."
        }.map { [$0] } ?? []

        switch actionKind {
        case .takeAction:
            return [
                "\(actor.name) left a fresh memory in the margins.",
                "\(thread.title) remains available for a future Story Page."
            ] + talismanLines
        case .investBelief:
            return [
                "\(actor.name) spent one quiet Belief.",
                "\(thread.title) grew warmer by one line."
            ] + talismanLines
        case .attackBelief:
            if let beliefCombat {
                var lines = [
                    "\(actor.name) spent \(beliefCombat.actualSpend) Belief against \(thread.title).",
                    beliefCombat.summaryLine
                ]
                if beliefCombat.dealt > 0 {
                    lines.append("\(thread.title) dimmed from Glow \(beliefCombat.targetBeliefBefore) to \(beliefCombat.targetBeliefAfter).")
                } else if beliefCombat.backlash > 0 {
                    lines.append("\(actor.name)'s own Glow fell from \(beliefCombat.attackerBeliefBefore) to \(beliefCombat.attackerBeliefAfter).")
                } else {
                    lines.append("\(thread.title) held its Glow at \(beliefCombat.targetBeliefBefore).")
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
        let connection = connectionLine(fuelEntries: fuelEntries, weatherEntries: weatherEntries, metrics: metrics, distressActive: context.distress.isActive)
        let experiment = experimentLine(fuelEntries: fuelEntries, weatherEntries: weatherEntries, metrics: metrics, distressActive: context.distress.isActive)
        let safety = "This is not diagnosis or treatment. It is a low-shame pattern note for deciding what to observe next."
        let sections: [String: String] = [
            "vellum": [
                "Vellum reads: \(summaryList(for: fuelEntries, fallback: "no fuel notes yet"))",
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
                return "\(timeFormatter.string(from: page.createdAt)) — \(page.type.shortTitle): \(String(text.replacingOccurrences(of: "\n", with: " ").prefix(110)))"
            }
            .joined(separator: "\n")
        let fullMetrics = metrics.prefix(12).map(\.displayText).joined(separator: " | ")
        let moonPhase = MoonPhaseCalendar.phase(on: now)
        let skyLine = [
            inputs.weather?.phrase,
            inputs.enchantedWeather?.enchantified
        ].compactMap { $0 }.joined(separator: " · ")

        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)",
            type: .supportGuild,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .gentleTranslation,
            score: context.distress.isActive ? 94 : 78,
            reason: "The Support Guild has enough chart ink to compare patterns.",
            prompt: "The Support Guild has opened a joint page.",
            detail: "Vellum and Inkrest compare fuel, inner weather, body signals, and research dockets into one humane experiment.",
            payload: BookPagePayload(
                headline: "Support Guild Page",
                body: body,
                metadata: [
                    "source": source.id,
                    "slot": slot,
                    "vellumSection": sections["vellum"] ?? "",
                    "inkrestSection": sections["inkrest"] ?? "",
                    "bodyStatus": inputs.body.map { "\($0.status): \($0.phrase)" } ?? "",
                    "bodyMetrics": fullMetrics,
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
        if fuelText.contains("coffee") && weatherText.contains("tired") {
            return "Caffeine and tiredness are sharing a margin; the useful question is timing, not virtue."
        }
        if !fuelEntries.isEmpty && !weatherEntries.isEmpty {
            return "Fuel notes and inner weather are now close enough on the page to compare timing, texture, and aftermath."
        }
        return "The chart has begun; the strongest current signal is that missing data should become a question, not a conclusion."
    }

    private static func experimentLine(
        fuelEntries: [FacultyEntry],
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

enum CharacterLetterPageGenerator {
    static func draftCandidate(for day: BookDay, inputs: BookSourceInputs, now: Date = Date()) -> SurfacePage? {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let source = BookPageSourceRegistry.source(for: .letter)
        guard let entity = selectedEntity(for: day, inputs: inputs, now: now) else { return nil }
        return draftCandidate(for: entity, source: source, day: day, inputs: inputs, now: now)
    }

    static func draftCandidate(
        for entity: NarrativeWorldEntity,
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        let interest = entity.unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? entity.beliefs.first
            ?? entity.traits.first
            ?? "ordinary wonder"
        let homeContext = homeContextLine(inputs: inputs, day: day)
        let playerName = preferredPlayerName(inputs: inputs)
        let voice = voiceProfile(for: entity)
        let memoryPacket = memoryPacket(for: entity, day: day, inputs: inputs)
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
            : letterOccasion(inputs: inputs)
        let crossLetter = crossLetterMemory(for: entity, day: day, inputs: inputs, now: now)
        let relationshipWeather = thirdPartyRelationshipContext(
            for: entity,
            inputs: inputs,
            allowInCurrentLetter: !isFirstLetterFromSender
        )
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
            "chapterTalismanMoves": talismanMoveLines,
            "chapterTalismanDeltas": talismanDeltaTokens,
            "slotID": slot,
            "placeholder": "A researched letter is being written through the Margin-Glass.",
            "tags": "letter,letters,research,sender:\(entity.id),\(entity.tags.prefix(4).joined(separator: ","))"
        ]
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
            reason: "\(entity.name) has a researched letter gathering in the margins.",
            prompt: "A letter from \(entity.name)",
            detail: "A researched note about \(interest).",
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
        if let writingVoice = entity.writingVoice {
            return writingVoice
        }
        let traitLine = entity.traits.prefix(3).joined(separator: ", ")
        let quirkLine = entity.quirks.prefix(2).joined(separator: "; ")
        return WritingVoiceProfile(
            register: entity.kind == .character ? "personal, direct, and specific" : "observant and quietly animate",
            rhythm: "varied sentence lengths; one intimate turn near the end",
            diction: Array((entity.traits + entity.tags).prefix(5)),
            habits: [
                traitLine.isEmpty ? "write from what the character notices first" : "let these traits guide the hand: \(traitLine)",
                quirkLine.isEmpty ? "include one small concrete observation" : "one habit may surface: \(quirkLine)"
            ],
            avoid: [
                "generic assistant voice",
                "fake citations",
                "claiming the player did things not present in memory"
            ]
        )
    }

    private static func selectedEntity(for day: BookDay, inputs: BookSourceInputs, now: Date) -> NarrativeWorldEntity? {
        let recentSenders = Set(day.pages.filter { $0.type == .letter }.compactMap { $0.tags.first(where: { $0.hasPrefix("sender:") })?.dropFirst("sender:".count) }.map(String.init))
        let candidates = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
            .filter { !($0.unwrittenInterest ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !recentSenders.contains($0.id) }
        guard !candidates.isEmpty else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        return candidates.max { left, right in
            let leftScore = entityScore(left, day: day, inputs: inputs, slot: slot)
            let rightScore = entityScore(right, day: day, inputs: inputs, slot: slot)
            if leftScore == rightScore { return left.name > right.name }
            return leftScore < rightScore
        }
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
                lines.append("After that letter, the reader wrote back to you. Part of what they said: \"\(replyExcerpt)…\" Let it have reached you — answer it once, glancingly, the way someone recalls a line from a letter rather than quoting it back.")
            }
        }

        let sidings = keptPages
            .filter { $0.type == .twoReadings && $0.tags.contains("entity:\(entity.id)") }
            .sorted { $0.createdAt > $1.createdAt }
        if let recent = sidings.first,
           let sidedTag = recent.tags.first(where: { $0.hasPrefix("sided:") }) {
            let sided = String(sidedTag.dropFirst("sided:".count))
            if sided == entity.id {
                lines.append("Recently, when two of you disagreed, the reader sided WITH you. You feel a little vindicated — and warmer toward them.")
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

    private static func memoryPacket(for entity: NarrativeWorldEntity, day: BookDay, inputs: BookSourceInputs) -> String {
        let pages = day.pages.suffix(6).map { "- \($0.promptText): \($0.userInput.bookPreviewSentenceLimit(1))" }.joined(separator: "\n")
        let memories = inputs.narrative?.entityMemories
            .filter { $0.entityID == entity.id }
            .prefix(4)
            .map { "- \($0.summary)" }
            .joined(separator: "\n") ?? ""
        let continuity = continuityPacket(for: entity, inputs: inputs)
        return """
        Recent pages:
        \(pages.isEmpty ? "No kept pages yet today." : pages)

        Entity memories:
        \(memories.isEmpty ? "No explicit memory packet for this sender." : memories)

        What the Book has begun to notice:
        \(continuity.isEmpty ? "No stable literary pattern has been offered to this sender." : continuity)
        """
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
    private static func letterOccasion(inputs: BookSourceInputs) -> String? {
        guard let absence = inputs.continuity.strongestSignals.first(where: { $0.kind == .absence && $0.strength >= 60 }) else {
            return nil
        }
        return "\(absence.line) The sender writes because of this quiet: ask after \(absence.subjectName) the way a friend asks after someone who stopped coming to the cafe - warmly, without alarm, leaving room for the answer to be ordinary. Do not demand a reply; let the margin hold the question."
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
            Ask this Spark out loud or in your head:

            \(spark)

            Keep the page when you are ready to let this question become the goal of the run.
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

            Rest is the center of the Compass. Keep this page after the quiet minute, and the completed run adds 6 Belief.
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

enum PlayfulMissionRegistry {
    static func mission(for day: BookDay, inputs: BookSourceInputs, now: Date = Date(), shadowVariant: Bool = false) -> PlayfulMission {
        let slot = SurfaceCadence.slotID(for: now, hours: 2)
        let seed = abs("\(day.id)-\(slot)-playful-mission".stableHash)
        if !shadowVariant {
            let phenomena = naturalPhenomenonMissions(inputs: inputs, now: now)
            if !phenomena.isEmpty {
                return phenomena[seed % phenomena.count]
            }
        }
        let missions = rankedMissions(for: day, inputs: inputs, now: now, shadowVariant: shadowVariant)
        if shadowVariant, ShadowWonder.state(inputs: inputs, now: now).isActive {
            let shadowMissions = missions.filter { $0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
            if !shadowMissions.isEmpty {
                return shadowMissions[seed % shadowMissions.count]
            }
            let preferred = missions.filter(ShadowWonder.prefers(mission:))
            if !preferred.isEmpty {
                return preferred[seed % preferred.count]
            }
        }
        return missions[seed % missions.count]
    }

    private static func naturalPhenomenonMissions(inputs: BookSourceInputs, now: Date) -> [PlayfulMission] {
        var result: [PlayfulMission] = []
        let moon = MoonPhaseCalendar.phase(on: now)
        if moon.name == "Waning Gibbous" {
            result.append(mission(
                "moon-waning-gibbous-shadow",
                "Moon Shadow Errand",
                "Tonight, if the moon is visible, find one shadow it casts. If it hides, find the place where moonlight would have landed.",
                "Write the moon-shadow, or the place it would have touched.",
                ["natural-phenomenon", "moon", "waning-gibbous", "shadow", "night", "outside"]
            ))
        }

        let weatherText = [inputs.weather?.phrase, inputs.weather?.forecast, inputs.enchantedWeather?.summary]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if containsAny(weatherText, ["pressure drop", "dropping pressure", "falling pressure", "storm", "thunder", "squall", "front", "gust"]) {
            result.append(mission(
                "storm-wind-shift",
                "Wind Change Watch",
                "Step to a safe outside threshold, close your eyes, and listen for the exact moment the wind changes direction or argues with itself.",
                "Write the wind's change: direction, sound, or first clue.",
                ["natural-phenomenon", "weather", "storm", "wind", "sound", "outside"],
                allowsPhoto: false
            ))
        }

        let placeText = placeEvidenceText(inputs: inputs)
        if containsAny(placeText, ["harbor", "river", "lake", "pond", "creek", "stream", "water", "waterfront", "shore", "beach", "bay", "marina", "bridge"]) {
            result.append(mission(
                "water-flow-low-point",
                "Water Chooses Down",
                "Find the highest or lowest physical point nearby, then look for which way water would travel from there.",
                "Write the point you chose and the direction water would go.",
                ["natural-phenomenon", "water", "place", "outside", "movement"]
            ))
        } else if containsAny(placeText, ["hill", "ridge", "mountain", "trail", "overlook", "stairs", "elevator", "slope", "summit", "valley"]) {
            result.append(mission(
                "altitude-nearby-point",
                "High Low Reading",
                "Find the highest or lowest physical point nearby. Stand there for ten seconds and decide what the place is sending downhill.",
                "Write the point and what seems to move away from it.",
                ["natural-phenomenon", "altitude", "place", "outside", "movement"],
                allowsPhoto: false
            ))
        }

        return result
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

    private static func rankedMissions(for day: BookDay, inputs: BookSourceInputs, now: Date, shadowVariant: Bool) -> [PlayfulMission] {
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

        return missionPool.sorted { left, right in
            let leftScore = Set(left.tags).intersection(preferredTags).count + (shadowVariant && ShadowWonder.prefers(mission: left) ? 4 : 0)
            let rightScore = Set(right.tags).intersection(preferredTags).count + (shadowVariant && ShadowWonder.prefers(mission: right) ? 4 : 0)
            if leftScore == rightScore {
                return left.id < right.id
            }
            return leftScore > rightScore
        }
    }

    static let missions: [PlayfulMission] = coreMissions + attentionMissions + shadowMissions

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
        mission("object-pocket-story", "Pocket Story", "Find one thing in your pocket or bag with a story you have never told anyone. Tell the Book the short version.", "Write the pocket thing and the short version.", ["object", "memory", "inside", "public"]),
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
        mission("motion-five-color", "Color Before Noon", "Find five of one color before noon. The Book accepts photographs and testimony.", "Write the color and your five witnesses.", ["movement", "visual", "color", "public"]),
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
        mission("shadow-mystery-clue", "The Mystery Mission", "Choose one abandoned, closed, old, or half-forgotten thing and find one clue about what it used to be.", "Write the clue and the question it opened.", ["shadow-wonder", "mystery", "history", "public", "visual"]),
        mission("shadow-tribute-object", "The Tribute Mission", "Find one repaired, worn, or past-its-prime object. Give it thirty seconds of respect without trying to fix it.", "Write one sentence honoring what it survived.", ["shadow-wonder", "tribute", "object", "history", "inside"]),
        mission("shadow-mood-match", "Mood Match", "Let the grey mood, rain, dim room, or tired hour be the atmosphere instead of the enemy. Find one detail that harmonizes with it.", "Write the detail that matched the weather inside you.", ["shadow-wonder", "mood-match", "night", "weather", "inside"], allowsPhoto: false),
        mission("shadow-last-light", "Last Light Witness", "Find the last, smallest, or most stubborn light nearby. Ask what it is guarding from the dark.", "Write what the light was guarding.", ["shadow-wonder", "night", "light", "threshold", "inside"]),
        mission("shadow-offering", "Leave an Offering", "Set out one small, genuine offering with no audience: crumbs for the birds, a saucer on the sill, a kindness no one will trace to you.", "Write what you left, and for whom.", ["shadow-wonder", "offering", "kindness", "fae", "folklore"], allowsPhoto: false),
        mission("shadow-threshold", "Honor a Threshold", "Find one threshold — a doorway, gate, or the seam where one room becomes another. Pause on it. Notice it is neither in nor out.", "Write what changes the moment you cross.", ["shadow-wonder", "threshold", "liminal", "folklore", "inside"], allowsPhoto: false),
        mission("shadow-true-name", "The True Name", "Find one heavy, vague feeling and hunt for its exact true name — not 'bad,' but the precise word that fits.", "Write the true name and whether the weight shifted.", ["shadow-wonder", "true-names", "grief", "naming", "low-energy"], allowsPhoto: false),
        mission("shadow-iron-key", "Mind the Edges", "Find the iron already in your home — a key, a nail, a cast pan — and set it deliberately by a door, the way folklore minds a threshold.", "Write whether a guarded edge changes the room.", ["shadow-wonder", "protection", "iron", "threshold", "folklore", "inside"]),
        mission("shadow-correspondence", "One Correspondence", "Make one old correspondence literal: salt for protection, rosemary for memory, a dark stone for rest. Place it where you'll see it.", "Write what it now stands for.", ["shadow-wonder", "correspondences", "witchcraft", "folklore", "inside"]),
        mission("shadow-ending-thing", "The Vanishing", "Find one thing quietly ending right now — light going, a flower past peak, a cup going cold — and witness it leave without stopping it.", "Write one sentence for it before it's gone.", ["shadow-wonder", "mono-no-aware", "memory", "low-energy", "inside"], allowsPhoto: false),
        mission("shadow-cost", "The Goblin's Question", "Pick one 'free' thing in your day — a scroll, a shortcut, a numbing habit — and ask the Goblin Market's only question of it.", "Write its real, hidden cost in one line.", ["shadow-wonder", "goblin", "bargain", "unseelie"], allowsPhoto: false),
        mission("shadow-disowned", "Turn the Lamp", "Notice one small thing about today you'd rather not look at. Turn the lamp toward it for ten honest seconds — no fixing, no verdict.", "Write what you actually saw.", ["shadow-wonder", "shadow-self", "grief", "low-energy", "inside"], allowsPhoto: false)
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
    var id: String
    var name: String
    var baseWeight: Int
    var requirements: [StoryRecipeRequirement]
    var sceneMode: StoryRecipeSceneMode
    var premiseTemplate: String
    var beats: [String]
    var turns: [StoryRecipeTurnTemplate]
    var preferredTags: [String]
    var preferredFormIDs: [String]
    var preferredGenreIDs: [String]
    var excludedFormIDs: [String]
    var excludedGenreIDs: [String]
    var requiredEntityIDs: [String]
    var requiredEntityTags: [String]
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
                    directorNote: "Night logic; the Nothing tests the edges.",
                    beats: [
                        "Lamp: the scene begins in low light as one precise detail starts to fray at the edge of attention.",
                        "Ledger: after the chosen response, what was kept is written down and what was lost is admitted."
                    ]
                )
            ],
            genres: [
                StoryGenre(id: "cozy-mystery", name: "Cozy Mystery", lens: "Warm rooms, sharp questions. Tea is involved. Suspicion lands on objects, never cruelty on people.", moodTags: ["rain", "evening", "quiet", "tea"],
                    exemplar: "\"Someone has moved the marmalade,\" Mrs. Quill said, setting down her cup. \"Third shelf. It lives on the second.\" Outside, rain worked at the gutter. \"Maybe it wanted a view,\" you offered. She looked at you the way detectives look at footprints — delighted, and not fooled at all.",
                    palette: ["teapot", "marmalade jar", "third shelf", "rain at the gutter", "index card", "spectacles", "toast crumbs", "doorbell"]),
                StoryGenre(id: "gentle-horror", name: "Gentle Horror", lens: "The hair-raising kept kind: wrongness in familiar things, dread that resolves into tenderness. The Nothing's territory.", moodTags: ["night", "fog", "tired", "grey"],
                    exemplar: "The coat hook held its coat wrong. Not fallen — arranged, one sleeve folded across itself like an arm keeping something warm. \"Who folded you?\" you asked. Nothing answered, but the radiator ticked twice, the way a house does when it wants you to stay in the lit rooms.",
                    palette: ["coat hook", "radiator tick", "unlit hallway", "torch with a loose battery", "wallpaper seam", "your own breath", "stairwell", "spilled salt"]),
                StoryGenre(id: "screwball", name: "Screwball Comedy", lens: "Fast, fond, and slightly unhinged. Characters talk over each other. Objects misbehave with comic timing.", moodTags: ["bright", "morning", "energy"],
                    exemplar: "\"Don't open the—\" said Pim, as you opened the tin. \"—tin.\" The moths were out now, all forty, wearing tiny paper price tags. \"They're not for sale!\" \"You priced them!\" \"They priced THEMSELVES.\" Below, the doorbell rang twice, in a tone that meant the tuba had also escaped.",
                    palette: ["biscuit tin", "paper price tags", "doorbell", "escaped tuba", "umbrella stand", "custard", "borrowed ladder", "a list titled DO NOT"]),
                StoryGenre(id: "field-naturalist", name: "Field Naturalist", lens: "Mary Oliver attention: exact observation, unforced wonder, the world examined like it matters because it does.", moodTags: ["walk", "outside", "weather", "calm"],
                    exemplar: "The snail had climbed exactly one brick since morning — a whole brick, mortar to mortar. You crouched. Its shell wore last night's rain in a spiral, oldest weather at the center. Nothing about it hurried, and still it was crossing a wall. You wrote the time down like a coordinate.",
                    palette: ["one brick", "snail shell spiral", "mortar line", "pencil stub", "field notebook", "dew", "hedge gap", "the exact time"]),
                StoryGenre(id: "tiny-heist", name: "Tiny Heist", lens: "A caper at household scale — reclaiming a teacup, liberating a parking spot. Planning montage energy, zero crime.", moodTags: ["energy", "afternoon", "mission"],
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
                StoryGenre(id: "grey-static", name: "Grey Static", lens: "The Nothing edits, it does not attack: exact words go pale, lists become \"items\", days become \"fine\". Specificity is the counterspell.", moodTags: ["clash", "grey", "flattening"],
                    exemplar: "The list was still on the door, but someone had corrected it. Where it once said \"the good cup, the loud clock, Tuesday's moth,\" it now said \"items.\" Mara read it twice. \"Who signs their work 'fine'?\" she asked. The hallway light seemed suddenly very reasonable, very beige.",
                    palette: ["the word \"fine\"", "a corrected list", "beige light", "a missing adjective", "blank margin", "a title gone \"Untitled\"", "the good cup", "static hum"]),
                StoryGenre(id: "threshold-gothic", name: "Threshold Gothic", lens: "Borrowed rules and courteous danger: things that must ask permission, and the terrible weight of granting it. Invitation logic, old handwriting, the wrong side of the glass.", moodTags: ["clash", "threshold", "invitation"],
                    exemplar: "The letter arrived under the window, not the door — folded once and cold to the touch. \"It requests permission,\" Odile said, not touching it. \"Twice, politely.\" Below the signature, in older handwriting: MAY I COME IN. The latch, which had never mattered before, mattered enormously now.",
                    palette: ["window latch", "an invitation with no stamp", "cold envelope", "older handwriting", "permission asked twice", "the wrong side of the glass", "salt on the sill", "a rule that followed you home"])
            ],
            recipes: unquietFolioRecipes
        )
    ]

    static let unquietFolioRecipes: [StoryRecipe] = [
        recipe("grey-edit", "The Grey Edit", weight: 14, requirements: [.keptPage], mode: .balanced,
            premise: "The Nothing has edited the kept page inside {{thread}}: the exact words of {{grounding}} have gone pale, corrected to \"fine.\"",
            beats: ["Show the kept page with its specific words flattened to filler while {{lead}} names what is missing.", "After the chosen response, the true words return, partly return, or their first-stolen word is learned — and the grey's editing rule gets written down."],
            turn: turn(.factLearned, want: "to learn which exact word the grey took first from {{grounding}}", obstacle: "the flattened sentence reads as almost true, which is how it hides", statement: "By the end, at least one exact word has been restored or the grey's editing rule has been named.", slice: "One small true detail is read aloud and refuses to stay grey.", progress: "The restored word points at where the grey nests inside {{thread}}.", surprise: "The edit was practice: the grey is drafting toward a page that has not been written yet."),
            tags: ["clash", "grey", "nothing", "evidence", "words"], forms: ["small-mystery", "nocturne"], genres: ["grey-static", "gentle-horror"],
            grounding: "Quote or nearly quote the kept material's own concrete words as the thing being erased and restored; the whole fight is over exact wording.",
            tone: "Dread at kitchen scale, then defiance. Specificity is the weapon; the scene itself must never go vague.",
            choices: "Offer restoring one exact detail, spending Belief to reject the whole edit, or asking the Book which word vanished first.",
            continuation: "The restored words stay restored. Escalate to the grey's source or its next target; never re-flatten the same page."),
        recipe("wicker-marks-the-page", "Wicker Marks the Page", weight: 14, requirements: [.keptPage], mode: .conversation,
            premise: "Wicker Eddies has forged a marginal note on the kept page in {{thread}} — {{grounding}} — and stayed to watch it land.",
            beats: ["{{lead}} defends the page while Wicker performs innocence, the forged note doing its small cruel work.", "After the chosen response, the forgery burns off, buys Wicker leverage, or exposes what he actually came for."],
            turn: turn(.revealWant, want: "to make the reader doubt that {{grounding}} deserved keeping", obstacle: "the page's specific words are truer than his joke, and he knows it", statement: "By the end, the forged note is exposed, overwritten, or traded — and Wicker's real errand shows one honest edge.", slice: "The reader's own words outlast the joke, read aloud once, plainly.", progress: "The forgery peels up, and what Wicker was covering moves {{thread}} one step.", surprise: "The note is in Wicker's hand, but the idea belonged to someone else."),
            tags: ["clash", "wicker", "forgery", "margins"], forms: ["correspondence", "visitation"], genres: ["trickster-duel", "cozy-mystery"],
            grounding: "The forged note mocks the kept material's exact content; quote the page's real words against Wicker's fake ones.",
            tone: "Social pressure, not menace: the threat is being made to feel foolish for caring. Wicker is funny, quick, and wrong.",
            choices: "Offer naming the forgery with evidence, writing over him with better mischief, or sealing the true page at a visible cost.",
            continuation: "Wicker keeps whatever he won and remembers whatever he lost. Move to consequence or counter-move; do not replay the forgery."),
        recipe("rivals-tether", "The Rival's Tether", weight: 12, requirements: [.character, .secondCharacter, .rivalryEdge], mode: .conversation,
            premise: "{{lead}} and {{companion}} have let a tension knot pull tight inside {{thread}}, and {{grounding}} just became the rope.",
            beats: ["The two collide over the concrete material mid-scene — each certain, neither cruel, the reader between them.", "After the chosen response, the knot loosens, tightens honestly, or reveals what the rivalry has been protecting."],
            turn: turn(.relationshipShift, want: "to be taken seriously about what {{grounding}} means", obstacle: "{{companion}} read the same evidence and reached the opposite conviction", statement: "By the end, the rivalry has been named to its face, and one of them has conceded one exact inch.", slice: "One ordinary detail both rivals agree on, grudgingly, out loud.", progress: "The concession — small, specific — moves {{thread}} one honest step.", surprise: "The rivalry is a guard dog: what it protects finally shows itself."),
            tags: ["clash", "rivalry", "tension", "cast"], forms: ["visitation", "quiet-epic"], genres: ["trickster-duel", "serial-adventure"],
            grounding: "Both rivals argue from the same concrete material; the disagreement is conviction, never facts.",
            tone: "Friction that sharpens instead of wounds. Fast exchanges, real stakes, no cruelty.",
            choices: "Offer siding with one rival on evidence, forcing both to defend the same detail, or naming what the quarrel protects.",
            continuation: "The concession holds. Warmth or tension moves visibly; never reset both rivals to their opening positions."),
        recipe("counterfeit-invitation", "The Counterfeit Invitation", weight: 12, requirements: [.groundedSource, .character], mode: .conversation,
            premise: "An invitation reaches the reader inside {{thread}}, signed by a friend — but {{grounding}} says the hand is wrong.",
            beats: ["The invitation performs warmth while one concrete detail from the real material refuses to corroborate it.", "After the chosen response, the forgery is unmasked, accepted on the reader's own terms, or audited into a stranger truth."],
            turn: turn(.factLearned, want: "to find out who is wearing a friend's handwriting", obstacle: "refusing outright would insult the real friend if the letter is genuine", statement: "By the end, the invitation's true sender has been tested, and trust lands somewhere exact.", slice: "One verifying question only the real sender could answer, asked casually.", progress: "The unmasked scheme points one step deeper into {{thread}}.", surprise: "The invitation is genuine — and that is somehow worse."),
            tags: ["clash", "letters", "trust", "forgery"], forms: ["correspondence", "small-mystery"], genres: ["threshold-gothic", "trickster-duel"],
            grounding: "One concrete detail from the material is the tell that exposes or verifies the invitation.",
            tone: "Social suspense: trust as a wager. Courteous surface, sharp undertow.",
            choices: "Offer following it openly, asking one verifying question, or having the ink audited by someone exact.",
            continuation: "The verdict on the sender stands. Follow the consequence of trusting or refusing; never re-litigate the same letter.")
    ]

    private static func recipe(
        _ id: String, _ name: String, weight: Int = 10,
        requirements: [StoryRecipeRequirement], mode: StoryRecipeSceneMode,
        premise: String, beats: [String], turn: StoryRecipeTurnTemplate,
        tags: [String] = [], forms: [String] = [], genres: [String] = [],
        grounding: String, tone: String, choices: String, continuation: String,
        suppressedBy: [BookPageType] = [], suppressionHours: Int = 0
    ) -> StoryRecipe {
        StoryRecipe(
            id: id, name: name, baseWeight: weight, requirements: requirements, sceneMode: mode,
            premiseTemplate: premise, beats: beats, turns: [turn], preferredTags: tags,
            preferredFormIDs: forms, preferredGenreIDs: genres, excludedFormIDs: [], excludedGenreIDs: [],
            requiredEntityIDs: [], requiredEntityTags: [], groundingDirective: grounding,
            toneDirective: tone, choiceDirective: choices, continuationDirective: continuation,
            cooldownHours: 18, suppressedByPageTypes: suppressedBy, suppressionHours: suppressionHours
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
            premise: "In a library corner, the Nothing begins erasing one precise part of {{grounding}} while the reader is close enough to intervene.",
            beats: ["Show the first exact absence and make the reader's available responses materially different.", "After the chosen response, leave one protected detail or admitted loss."],
            turn: turn(.smallDecision, want: "to keep {{grounding}} from being flattened by the Nothing", obstacle: "the erasure advances whenever nobody names what is actually there", statement: "By the end, one exact part of {{grounding}} is protected, changed, or honestly lost.", slice: "The reader protects one modest detail and lets the rest wait.", progress: "The defense exposes how the Nothing is entering {{thread}}.", surprise: "What looked erased has moved somewhere unexpected instead."),
            tags: ["grey", "night", "quiet"], forms: ["nocturne", "small-mystery"], genres: ["gentle-horror"],
            grounding: "Name exactly what is greying or vanishing.", tone: "Eerie but humane; the environment is allowed to act.", choices: "Offer concrete ways to name, shelter, move, trade for, or release the threatened detail.", continuation: "The Nothing may act again; advance the physical consequence rather than forcing dialogue."),
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
            grounding: "Repeat the exact named evidence both characters are interpreting.", tone: "Fair, concrete, and practical; never generic bickering.", choices: "Offer siding, reframing, asking for evidence, or declining to judge.", continuation: "Show what the disagreement changes; do not merely restate both positions.", suppressedBy: [.twoReadings], suppressionHours: 72)
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

    static let recipeTemplateTokens: Set<String> = ["lead", "companion", "grounding", "thread", "form"]

    static var recipesWithPackIDs: [(packID: String, recipe: StoryRecipe)] {
        var seen = Set<String>()
        return enabledPacks().flatMap { pack in
            pack.recipes.compactMap { recipe in
                guard seen.insert(recipe.id).inserted, recipeIsValid(recipe) else { return nil }
                return (pack.id, recipe)
            }
        }
    }

    static var recipes: [StoryRecipe] { recipesWithPackIDs.map(\.recipe) }

    /// True when any relationship edge between the available entities carries
    /// real tension — the fuel for rivalry-driven clash recipes.
    static func hasRivalryEdge(among entities: [NarrativeWorldEntity]) -> Bool {
        let ids = Set(entities.map(\.id))
        return NarrativePackRegistry.relationships.contains { edge in
            edge.tension >= 2 && ids.contains(edge.sourceEntityID) && ids.contains(edge.targetEntityID)
        }
    }

    static func recipeIsValid(_ recipe: StoryRecipe) -> Bool {
        guard !recipe.id.isEmpty, !recipe.name.isEmpty, recipe.baseWeight > 0,
              !recipe.premiseTemplate.isEmpty, !recipe.beats.isEmpty, !recipe.turns.isEmpty else { return false }
        let strings = [recipe.premiseTemplate, recipe.groundingDirective, recipe.toneDirective,
                       recipe.choiceDirective, recipe.continuationDirective]
            + recipe.beats
            + recipe.turns.flatMap { [$0.wantTemplate, $0.obstacleTemplate, $0.statementTemplate,
                                      $0.sliceLandingTemplate, $0.progressLandingTemplate, $0.surpriseLandingTemplate] }
        let pattern = #"\{\{([a-zA-Z0-9_-]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
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
            for (recipeID, boost) in recipeBoosts where boost > 0 {
                if StoryFormRegistry.recipes.first(where: { $0.id == recipeID })?.preferredGenreIDs.contains(genre.id) == true {
                    score += min(boost, 8)
                }
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
            for (recipeID, boost) in recipeBoosts where boost > 0 {
                if StoryFormRegistry.recipes.first(where: { $0.id == recipeID })?.preferredFormIDs.contains(form.id) == true {
                    score += min(boost, 8)
                }
            }
            // The Nocturne belongs to the night.
            let hour = Calendar.current.component(.hour, from: now)
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
// real named destination — sometimes, not always.

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
        spark("free-museum", "I wonder what the best free exhibit within walking distance is — a window, a tree, a bulletin board?", [.budget, .obscure], ["bright"]),
        spark("expensive-smell", "I wonder where the most expensive-smelling free air in town is?", [.budget, .scavenger]),
        spark("penny-bright", "I wonder what the shiniest thing I can find without spending anything is?", [.budget], ["bright"]),
        spark("library-oracle", "I wonder what the library would hand me today if I let shelf chance decide?", [.budget, .obscure]),
        spark("sample-day", "I wonder which place nearby gives something small away free, and who decided that?", [.budget]),
        spark("quarter-tour", "I wonder how grand a tour I could give of this neighborhood using only things that cost nothing to see?", [.budget, .obscure], ["bright"]),
        spark("best-bench", "I wonder which free seat in town has the best view nobody pays for?", [.budget, .vibe], ["bright", "evening"]),

        // Obscure: strange little stories.
        spark("oldest-sign", "I wonder what the oldest sign in town still says, and to whom?", [.obscure, .scavenger]),
        spark("ghost-paint", "I wonder where a painted-over word or picture is still faintly visible nearby?", [.obscure]),
        spark("desire-path", "I wonder where people have voted with their feet — a worn shortcut the planners never drew?", [.obscure], ["bright"]),
        spark("lost-glove", "I wonder where the nearest lost glove, sock, or key is waiting, and what its other half is doing?", [.obscure, .scavenger], ["cold"]),
        spark("plaque-nobody", "I wonder what the nearest plaque or memorial actually commemorates — and who last read it?", [.obscure]),
        spark("name-origin", "I wonder why the street I use most is named what it's named?", [.obscure]),
        spark("oldest-tree", "I wonder which tree in this neighborhood was here before any of the houses?", [.obscure, .recovery], ["bright", "wind"]),
        spark("back-of-things", "I wonder what the backs of buildings on my usual route look like — the side they don't dress up?", [.obscure]),
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
        spark("face-pareidolia", "I wonder where the nearest accidental face is — in a socket, a car grill, a knot of wood?", [.scavenger, .closeToHome]),
        spark("seven-greens", "I wonder how many different greens exist within a hundred steps of my door?", [.scavenger], ["bright"]),
        spark("texture-trio", "I wonder what the roughest, smoothest, and softest things within arm's reach are?", [.scavenger, .recovery], ["gentle"]),
        spark("number-hunt", "I wonder where today's date is hiding in the wild — on signs, receipts, license plates?", [.scavenger]),
        spark("shadow-collection", "I wonder which shadow nearby is the most elaborate, and what's casting it?", [.scavenger], ["bright", "evening"]),
        spark("circle-census", "I wonder what the roundest thing in this room is, and whether anything is perfectly round at all?", [.scavenger, .closeToHome]),
        spark("oldest-newest", "I wonder what the oldest and newest things I can see right now are, side by side?", [.scavenger, .closeToHome]),
        spark("tiny-doors", "I wonder where the smallest door, hatch, or opening in this building is, and what uses it?", [.scavenger, .obscure]),

        // Recovery: noticing without pushing.
        spark("breath-weather", "I wonder what my breath would report about this exact minute if I let it speak?", [.recovery], ["gentle", "night"]),
        spark("soft-inventory", "I wonder what the softest thing I can see from here is, without moving?", [.recovery], ["gentle"]),
        spark("holding-things", "I wonder what is quietly holding weight for me right now — chair, floor, wall, cup?", [.recovery], ["gentle"]),
        spark("slow-clock", "I wonder what the slowest-moving thing in my field of view is?", [.recovery], ["night", "gentle"]),
        spark("kind-light", "I wonder which light in this room is the kindest, and what it's being kind to?", [.recovery], ["evening", "night"]),
        spark("one-good-sound", "I wonder what the single most comforting sound within earshot is right now?", [.recovery], ["gentle", "rain"]),
        spark("blanket-geology", "I wonder what landscape the folds of the nearest cloth would be, if I were very small?", [.recovery, .closeToHome], ["gentle"]),

        // Wide-mode wonders: fit nearly anywhere.
        spark("almost-said", "I wonder what the last thing this room almost heard somebody say was?", [.closeToHome, .vibe, .obscure]),
        spark("future-fossil", "I wonder which object near me would make the best fossil for future archaeologists?", [.closeToHome, .scavenger, .obscure]),
        spark("secret-effort", "I wonder what nearby is working hard while looking effortless — a hinge, a stem, a seam?", [.closeToHome, .recovery, .scavenger]),
        spark("first-visitor", "I wonder what visited my street this morning before anyone was awake?", [.obscure, .vibe], ["morning"]),
        spark("rain-instruments", "I wonder which surfaces outside play the rain best — what's the percussion section?", [.vibe, .obscure], ["rain"]),
        spark("wind-errands", "I wonder what the wind is moving around the neighborhood right now, and where it's taking it?", [.vibe, .obscure], ["wind"]),
        spark("snow-ledger", "I wonder what tracks the cold has recorded since last night, and who wrote them?", [.obscure, .scavenger], ["cold"]),
        spark("dusk-handover", "I wonder what changes hands in the neighborhood at dusk — which lights take over from the sun?", [.vibe, .obscure], ["evening"]),
        spark("night-shift", "I wonder what is awake on my street right now besides me?", [.recovery, .obscure], ["night"]),
        spark("morning-rehearsal", "I wonder what the day is rehearsing outside before it fully begins?", [.vibe, .recovery], ["morning"]),
        spark("forgotten-pocket", "I wonder what the pockets of my least-worn coat have been keeping for me?", [.closeToHome, .scavenger], ["cold"]),
        spark("appliance-choir", "I wonder which appliance hums the lowest note in the house choir?", [.closeToHome, .scavenger], ["night"]),
        spark("plant-opinion", "I wonder which plant nearby is having the best week, and what its secret is?", [.recovery, .obscure], ["bright"]),
        spark("step-counter", "I wonder exactly how many steps it takes to cross my home at its longest, walked like it matters?", [.closeToHome, .scavenger], ["gentle"]),
        spark("handwriting-wild", "I wonder where the nearest handwriting in the wild is — not printed, actually written by a hand?", [.obscure, .scavenger]),
        spark("blue-hour", "I wonder which blue, of all the blues I can find right now, is the bluest?", [.scavenger, .vibe], ["evening", "bright"]),
        spark("usefulness-retired", "I wonder what near me used to be essential and is now purely decorative?", [.closeToHome, .obscure]),
        spark("smallest-kindness", "I wonder what the smallest act of kindness visible from here is — a coaster, a propped door, a refilled bowl?", [.recovery, .vibe], ["gentle"]),
        spark("echo-spots", "I wonder where the best echo within a hundred steps lives?", [.scavenger, .obscure], ["bright"]),
        spark("crooked-true", "I wonder what nearby is charmingly crooked, and whether anyone ever tried to straighten it?", [.closeToHome, .obscure]),
        spark("paper-trail", "I wonder what the oldest piece of paper in this room says?", [.closeToHome, .obscure], ["night", "gentle"]),
        spark("threshold-count", "I wonder how many thresholds I cross on an ordinary day without noticing a single one?", [.vibe, .recovery], ["morning"]),
        spark("borrowed-light", "I wonder which rooms in my home never get their own light, only borrowed light?", [.closeToHome, .obscure], ["evening"]),
        spark("season-leak", "I wonder where the current season is leaking into the house — a smell, a draft, a quality of light?", [.closeToHome, .vibe], ["cold", "bright", "rain"]),
        spark("instruction-art", "I wonder where the most beautiful purely functional thing nearby is — a fire escape, a gutter, a knot?", [.obscure, .vibe]),
        spark("waiting-things", "I wonder what near me has been waiting the longest — for use, for repair, for someone to notice?", [.closeToHome, .recovery], ["gentle"])
    ]
}

// MARK: - Story Arcs
//
// The season-scale spine: when one thread runs hot for days, it becomes the
// current arc and walks the phases — rising, climax, resolution, fading —
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
            return "The arc is at its CLIMAX: this scene should burn the thread's central tension at full flame — something small but irreversible happens, at household scale. No cliffhanger-dodging."
        case .resolution:
            return "The arc is RESOLVING: pay one debt the arc created. Let a consequence land and a character change their behavior because of it."
        case .fading:
            return "The arc is FADING: it appears only as echoes now — a reference, a leftover object, a changed habit. Do not reignite it."
        default:
            return "Let the arc thread breathe in the background."
        }
    }
}
