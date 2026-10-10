import Foundation

// MARK: - The Cast remember the month
//
// A monthly story happens *to* the Cast. Wicker writes a verb into Dracula,
// Serenity is bitten, Ambrose carries her to the Kitchens, and a reader sits
// beside her map at lunch. Until now none of it stuck: a kept scene is a
// `.narrativeOS` Page with no `entity:` tags, so nobody in it remembered a
// thing, and the per-character store that letters, notes and Story Pages read
// never heard of October.
//
// Three rules hold the design together:
//
// 1. **Authored, not inferred.** A memory is written beside the moment in the
//    pack: on a scene, a node, a choice, or a dated record entry. The month's
//    author knows what happened to whom; the device only notices which of it
//    the reader was there for.
// 2. **Frozen at the moment it's earned.** The pack retires at residue end and
//    the Cast don't forget with it. `CastStoryMemoryLedger` lives in the vault
//    and is never rewritten by a later pack, the same promise the receipts'
//    `printedBody` makes to a bound volume.
// 3. **Two witnesses.** What the reader lived with them (a committed choice, a
//    finished node) is `withReader`. What happened in the story whether or not
//    the reader came is `lived`, released from the dated record no earlier than
//    the day it's public. Both are true; the reader's version of a moment
//    replaces the rumour of it when they share a key.
// 4. **And gossip.** The month's news gets round. A moment authored with a
//    `gossip` line is told on, a day or two later, to Cast members who weren't
//    there, chosen by who's close to whoever was. That's the third witness,
//    `heard`, and it's worked out from the ledger alone, so it still spreads
//    after the pack has gone.

/// What one Cast member carries away from a moment of a monthly story.
struct AuthoredCastMemory: Codable, Equatable {
    /// The Cast member, by entity id.
    var entityID: String
    /// Stable within a story. The same key on a scene and on a record entry
    /// names the same moment, and later scenes recall it by this key.
    var key: String
    /// What happened to them, plainly: third person, past tense. Prompts read
    /// this, and the Cast page prints it under their own words.
    var memory: String
    /// The same thing in their own mouth, said some days later in the margins.
    /// Optional: not everyone talks about everything.
    var aside: String? = nil
    /// How it's told second-hand, by any Cast member who wasn't there. May say
    /// `{teller}` for whoever told them. Only moments with a gossip line spread.
    var gossip: String? = nil
}

/// A sentence in a later scene that's only there if somebody remembers.
///
/// The node's body carries `marker` once. At render time the first option
/// whose key is remembered replaces it; with none, `fallback` does (which may
/// be empty, so the paragraph simply isn't there for a reader who wasn't).
struct AuthoredCastRecall: Codable, Equatable {
    struct Option: Codable, Equatable {
        var key: String
        var line: String
    }

    var marker: String
    /// Who has to remember it. Nil means anyone in the Cast will do.
    var entityID: String? = nil
    var options: [Option]
    var fallback: String = ""
}

/// One memory, frozen in the vault. Never rewritten by a later pack.
struct CastStoryMemory: Codable, Equatable, Identifiable {
    enum Witness: String, Codable, Equatable {
        /// The reader was there: they chose, or finished, the moment.
        case withReader
        /// It happened in the story; the reader learned it, or will, as news.
        case lived
        /// Somebody told them. They weren't there.
        case heard

        var tag: String {
            switch self {
            case .withReader: return "with-reader"
            case .lived: return "lived"
            case .heard: return "heard"
            }
        }

        /// The better witness keeps the memory: being there beats the record,
        /// and the record beats hearsay.
        var standing: Int {
            switch self {
            case .withReader: return 3
            case .lived: return 2
            case .heard: return 1
            }
        }
    }

    var id: String
    var entityID: String
    var key: String
    var memory: String
    var aside: String?
    var witness: Witness
    /// "The Count Unbound".
    var storyTitle: String
    /// The scene or record entry it came from: "The chair that gets there first".
    var momentTitle: String
    var runID: String
    var sourceID: String
    var happenedAt: Date
    var frozenAt: Date
    /// When the aside was said aloud in the margins. Each aside is said once.
    var spokenAt: Date? = nil
    /// The second-hand telling, frozen with the moment so it can still spread
    /// after the pack retires.
    var gossip: String? = nil
    /// Who else was there, so nobody's told about their own afternoon.
    var presentIDs: [String]? = nil
    /// For a `heard` memory: who told them.
    var heardFromID: String? = nil
    var heardFromName: String? = nil

    static func id(runID: String, key: String, entityID: String) -> String {
        "\(runID)|\(key)|\(entityID)"
    }
}

struct CastStoryMemoryLedger: Codable, Equatable {
    var memories: [CastStoryMemory] = []

    static let empty = CastStoryMemoryLedger()

    /// Adds what's new. A memory already frozen keeps its words; it gives way
    /// only to a better witness of the same moment (the reader's own version
    /// over the record's, the record's over hearsay).
    func absorbing(_ incoming: [CastStoryMemory]) -> Self {
        var byID = Dictionary(memories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var order = memories.map(\.id)
        for memory in incoming {
            if let existing = byID[memory.id] {
                guard memory.witness.standing > existing.witness.standing else { continue }
                var upgraded = memory
                upgraded.spokenAt = existing.spokenAt
                upgraded.frozenAt = existing.frozenAt
                byID[memory.id] = upgraded
            } else {
                byID[memory.id] = memory
                order.append(memory.id)
            }
        }
        let next = Self(memories: order.compactMap { byID[$0] })
        return next == self ? self : next
    }

    /// Everything one Cast member carries, most recent first.
    func memories(of entityID: String) -> [CastStoryMemory] {
        memories
            .filter { $0.entityID == entityID }
            .sorted { $0.happenedAt == $1.happenedAt ? $0.id < $1.id : $0.happenedAt > $1.happenedAt }
    }

    func remembers(key: String, entityID: String? = nil) -> Bool {
        memories.contains { $0.key == key && (entityID == nil || $0.entityID == entityID) }
    }

    func markingSpoken(_ id: String, at moment: Date) -> Self {
        guard let index = memories.firstIndex(where: { $0.id == id }),
              memories[index].spokenAt == nil else { return self }
        var copy = self
        copy.memories[index].spokenAt = moment
        return copy
    }
}

// MARK: - Where the memories are written

/// The installed packs' memories, indexed so a receipt can find its moment.
/// Built off the main thread beside the runtime catalog.
struct CastStoryMemorySource {
    fileprivate struct SceneEntry {
        var scene: AuthoredStoryScene
        var storyTitle: String
    }

    fileprivate var scenes: [String: SceneEntry] = [:]
    fileprivate var events: [(packID: String, event: WorldEvent)] = []

    static let empty = CastStoryMemorySource()

    private init() {}

    init(packs: [WorldEventPack]) {
        for pack in packs {
            let sceneByID = Dictionary((pack.storyScenes ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for manifest in pack.authoringManifests ?? [] {
                guard let event = pack.events.first(where: { $0.id == manifest.eventID }) else { continue }
                for atom in manifest.content where atom.reference.kind == .storyScene {
                    guard let scene = sceneByID[atom.reference.id],
                          scene.eventID == manifest.eventID,
                          Self.carriesMemories(scene) else { continue }
                    scenes[Self.key(issueID: manifest.id, contentID: atom.id)] = SceneEntry(scene: scene, storyTitle: event.title)
                }
            }
            for event in pack.events where (event.record?.entries ?? []).contains(where: { !($0.castMemories ?? []).isEmpty }) {
                events.append((pack.id, event))
            }
        }
    }

    var isEmpty: Bool { scenes.isEmpty && events.isEmpty }

    fileprivate func scene(issueID: String, contentID: String) -> SceneEntry? {
        scenes[Self.key(issueID: issueID, contentID: contentID)]
    }

    private static func key(issueID: String, contentID: String) -> String {
        "\(issueID.utf8.count):\(issueID)\(contentID)"
    }

    private static func carriesMemories(_ scene: AuthoredStoryScene) -> Bool {
        !(scene.castMemories ?? []).isEmpty
            || scene.choices.contains { !($0.castMemories ?? []).isEmpty }
            || (scene.nodes ?? []).contains { node in
                !(node.castMemories ?? []).isEmpty || node.choices.contains { !($0.castMemories ?? []).isEmpty }
            }
    }
}

/// Reads the receipts and the dated record for what the Cast now carry. Pure
/// and idempotent: run it on every Keep and every catalog load, and absorb.
enum CastStoryMemoryHarvest {
    static func memories(
        source: CastStoryMemorySource,
        receipts: AuthoredContentReceiptLedger,
        lifecycle: WorldEventLifecycleLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> [CastStoryMemory] {
        guard !source.isEmpty else { return [] }
        var found: [String: CastStoryMemory] = [:]
        func offer(_ memory: CastStoryMemory) {
            if let existing = found[memory.id] {
                let better = memory.witness.standing > existing.witness.standing
                    || (existing.witness == memory.witness && memory.happenedAt < existing.happenedAt)
                if better { found[memory.id] = memory }
            } else {
                found[memory.id] = memory
            }
        }

        // What the reader was there for.
        for receipt in receipts.receipts where receipt.channel == .storyScene && receipt.recordedAt <= now {
            guard receipt.state == .nodeCompleted || receipt.state == .completed,
                  let issueID = receipt.scope.scopeID, let runID = receipt.scope.runID,
                  let entry = source.scene(issueID: issueID, contentID: receipt.contentID) else { continue }
            let scene = entry.scene
            var authored: [AuthoredCastMemory] = []
            if receipt.state == .nodeCompleted {
                guard let node = scene.nodes?.first(where: { $0.id == receipt.nodeID }) else { continue }
                authored += node.castMemories ?? []
                if let choiceID = receipt.choiceID, let choice = node.choices.first(where: { $0.id == choiceID }) {
                    authored += choice.castMemories ?? []
                }
            } else {
                authored += scene.castMemories ?? []
                if (scene.nodes ?? []).isEmpty, let choiceID = receipt.choiceID,
                   let choice = scene.choices.first(where: { $0.id == choiceID }) {
                    authored += choice.castMemories ?? []
                }
            }
            let present = Array(Set((scene.castIDs ?? []) + authored.map(\.entityID))).sorted()
            for memory in authored {
                offer(frozen(memory, witness: .withReader, storyTitle: entry.storyTitle, momentTitle: scene.title,
                             runID: runID, sourceID: scene.id, happenedAt: receipt.recordedAt, present: present, now: now))
            }
        }

        // What happened whether or not the reader came, once it's public.
        for (packID, event) in source.events {
            guard let snapshot = WorldEventResolver.lifecycleSnapshot(
                packID: packID, event: event, now: now, ledger: lifecycle, calendar: calendar) else { continue }
            let publicThrough: Int
            switch snapshot.stage {
            case .foreshadow: continue
            case .live: publicThrough = snapshot.liveDay ?? -1
            case .residue, .sealed: publicThrough = Int.max
            }
            for entry in event.record?.entries ?? [] {
                guard let memories = entry.castMemories, !memories.isEmpty else { continue }
                // An undated entry belongs to The Record alone: the Cast carry
                // it once the month is over.
                let publicDay = entry.publicFromDay ?? Int.max - 1
                guard publicDay <= publicThrough else { continue }
                let happenedAt = calendar.date(byAdding: .day, value: entry.onDay ?? 0, to: snapshot.liveInterval.start)
                    ?? snapshot.liveInterval.start
                let present = Array(Set(memories.map(\.entityID))).sorted()
                for memory in memories {
                    offer(frozen(memory, witness: .lived, storyTitle: event.title, momentTitle: entry.title,
                                 runID: snapshot.runID, sourceID: entry.id, happenedAt: min(happenedAt, now),
                                 present: present, now: now))
                }
            }
        }

        return found.values.sorted { $0.happenedAt == $1.happenedAt ? $0.id < $1.id : $0.happenedAt < $1.happenedAt }
    }

    private static func frozen(
        _ memory: AuthoredCastMemory,
        witness: CastStoryMemory.Witness,
        storyTitle: String,
        momentTitle: String,
        runID: String,
        sourceID: String,
        happenedAt: Date,
        present: [String],
        now: Date
    ) -> CastStoryMemory {
        CastStoryMemory(
            id: CastStoryMemory.id(runID: runID, key: memory.key, entityID: memory.entityID),
            entityID: memory.entityID,
            key: memory.key,
            memory: memory.memory.trimmingCharacters(in: .whitespacesAndNewlines),
            aside: memory.aside?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            witness: witness,
            storyTitle: storyTitle,
            momentTitle: momentTitle,
            runID: runID,
            sourceID: sourceID,
            happenedAt: happenedAt,
            frozenAt: now,
            gossip: memory.gossip?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            presentIDs: present
        )
    }
}

// MARK: - Where the memories come out

/// Story memories as ordinary per-character memories, so every reader of the
/// Cast's memory (letters, notes, Story Pages, deep-bond gating) hears them
/// without learning a new store. Projected at read time, never written to the
/// archive, so the 240-row recency cap can't push October out.
enum CastStoryMemoryProjection {
    static let tag = "cast-story"

    static func entityMemories(_ ledger: CastStoryMemoryLedger?) -> [NarrativeEntityMemory] {
        (ledger?.memories ?? []).map { memory in
            NarrativeEntityMemory(
                id: "cast-story-\(memory.id)",
                entityID: memory.entityID,
                sourceEventID: "cast-story:\(memory.runID):\(memory.key)",
                sourcePageID: nil,
                summary: memory.witness == .heard
                    ? "\(memory.storyTitle), heard from \(memory.heardFromName ?? "talk going round"): \(memory.memory)"
                    : "\(memory.storyTitle): \(memory.memory)",
                tags: [tag, "monthly-story", memory.witness.tag,
                       "story-key:\(memory.key)", "story-run:\(memory.runID)"],
                // Something that happened to them outweighs a kept page that
                // merely mentioned them; something the reader was there for,
                // more again. Hearsay is news, not a scar.
                narrativeWeight: [CastStoryMemory.Witness.withReader: 8, .lived: 6, .heard: 4][memory.witness] ?? 4,
                createdAt: memory.happenedAt
            )
        }
    }

    /// The archive's memories with the story's folded in, most recent first.
    static func merged(_ base: [NarrativeEntityMemory], ledger: CastStoryMemoryLedger?) -> [NarrativeEntityMemory] {
        let projected = entityMemories(ledger)
        guard !projected.isEmpty else { return base }
        let existing = Set(base.map(\.id))
        return (base + projected.filter { !existing.contains($0.id) })
            .sorted { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt > $1.createdAt }
    }
}

enum CastStoryRecall {
    /// Fills a node's recall markers from what the Cast remember.
    static func render(_ text: String, recalls: [AuthoredCastRecall]?, ledger: CastStoryMemoryLedger) -> String {
        guard let recalls, !recalls.isEmpty else { return text }
        var result = text
        for recall in recalls where !recall.marker.isEmpty {
            let line = recall.options.first { ledger.remembers(key: $0.key, entityID: recall.entityID) }?.line
                ?? recall.fallback
            result = result.replacingOccurrences(of: recall.marker, with: line)
        }
        // An empty fallback leaves a hole where a paragraph was; close it.
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A Cast member says, in the margin, something that happened to them.
///
/// Rationed hard: one a day, each aside once, only after the moment has had a
/// night to settle (the scene itself already spoke when it happened), and only
/// while it's still this season's news. A Cast member on the Page being kept
/// goes first; the reader's own moments before the ones they heard about.
enum CastStoryAside {
    static let settleHours: Double = 18
    static let freshDays: Double = 21

    static func pick(
        ledger: CastStoryMemoryLedger?,
        now: Date,
        speakers: Set<String>,
        preferring entityIDs: [String] = [],
        calendar: Calendar = .current
    ) -> CastStoryMemory? {
        guard let ledger, !ledger.memories.isEmpty else { return nil }
        if ledger.memories.contains(where: { $0.spokenAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false }) {
            return nil
        }
        let preferred = Set(entityIDs)
        return ledger.memories
            .filter { memory in
                guard memory.aside != nil, memory.spokenAt == nil, speakers.contains(memory.entityID) else { return false }
                let age = now.timeIntervalSince(memory.happenedAt)
                return age >= settleHours * 3_600 && age <= freshDays * 86_400
            }
            .min { left, right in
                let leftRank = (preferred.contains(left.entityID) ? 0 : 3) + (3 - left.witness.standing)
                let rightRank = (preferred.contains(right.entityID) ? 0 : 3) + (3 - right.witness.standing)
                if leftRank != rightRank { return leftRank < rightRank }
                if left.happenedAt != right.happenedAt { return left.happenedAt > right.happenedAt }
                return left.id < right.id
            }
    }

    /// The portrait for any Cast member, by the plates' naming.
    static func plateAssetName(for entityID: String) -> String {
        let pascal = entityID
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
        return "LabyrinthCharacter\(pascal)"
    }
}

// MARK: - Second-hand

/// How the Cast are named in each other's mouths.
enum CastStoryNames {
    private static let titles: Set<String> = ["professor", "dr", "dr.", "headmistress", "headmaster", "madame", "sir"]

    /// "Wicker", "Professor Permancer", "Professor Villanelle".
    static func short(_ fullName: String) -> String {
        let words = fullName.split(separator: " ").map(String.init)
        guard let first = words.first else { return fullName }
        if titles.contains(first.lowercased()), let last = words.last, words.count > 1 {
            return "\(first) \(last)"
        }
        return first
    }

    /// Whether the text speaks of this person by any of their own names.
    static func mentions(_ text: String, name: String) -> Bool {
        let words = Set(text.lowercased().split { !$0.isLetter && $0 != "'" }.map {
            $0.hasSuffix("'s") ? String($0.dropLast(2)) : String($0)
        })
        return name.lowercased().split(separator: " ").map(String.init)
            .filter { $0.count >= 4 && !titles.contains($0) }
            .contains { words.contains($0) }
    }

    /// FNV-1a. Swift's `hashValue` changes every launch, and gossip must
    /// reach the same ears every time it's worked out.
    static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

/// The month's news getting round the Academy.
///
/// Only a moment authored with a `gossip` line spreads. Whoever was there (the
/// best witness of it) tells it, a day or two later, to at most two Cast
/// members who weren't there and aren't in it, closest to the teller first
/// with a little luck mixed in so it isn't always the same two ears. One hop:
/// hearsay isn't passed on again. Pure and idempotent like the harvest.
enum CastStoryGossip {
    static let hearersPerMoment = 2

    struct Listener: Equatable {
        var id: String
        var name: String
    }

    /// How near two people are, for passing news: the authored ties plus
    /// whatever the relationship field has grown since. Tension doesn't stop
    /// gossip; it only stops it being kind.
    static func closeness(
        authored: [NarrativeRelationshipEdge],
        field: [String: RelationshipTie]
    ) -> (String, String) -> Int {
        var table: [String: Int] = [:]
        for edge in authored {
            let key = NarrativeGraphData.relationshipPairKey(edge.sourceEntityID, edge.targetEntityID)
            table[key, default: 0] += max(0, edge.warmth + edge.trust)
        }
        for (key, tie) in field {
            table[key, default: 0] += max(0, tie.warmth + tie.familiarity)
        }
        return { a, b in table[NarrativeGraphData.relationshipPairKey(a, b)] ?? 0 }
    }

    /// Everyone in the Cast who can hear news: characters, not objects.
    static func listeners(from entities: [NarrativeWorldEntity]) -> [Listener] {
        entities.filter { $0.kind == .character }.map { Listener(id: $0.id, name: $0.name) }
    }

    static func spread(
        ledger: CastStoryMemoryLedger,
        listeners: [Listener],
        closeness: (String, String) -> Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [CastStoryMemory] {
        let names = Dictionary(listeners.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let moments = Dictionary(grouping: ledger.memories) { "\($0.runID)|\($0.key)" }
        // Load-balancing: the same two ears shouldn't hear the whole month.
        var earful = Dictionary(grouping: ledger.memories.filter { $0.witness == .heard }, by: \.entityID)
            .mapValues(\.count)
        var told: [CastStoryMemory] = []
        for (moment, holders) in moments.sorted(by: { $0.key < $1.key }) {
            let firsthand = holders.filter { $0.witness != .heard }
            guard let source = firsthand.filter({ $0.gossip != nil }).min(by: { left, right in
                if left.witness.standing != right.witness.standing { return left.witness.standing > right.witness.standing }
                if left.happenedAt != right.happenedAt { return left.happenedAt < right.happenedAt }
                return left.id < right.id
            }), let line = source.gossip else { continue }
            let alreadyTold = holders.filter { $0.witness == .heard }.count
            let room = hearersPerMoment - alreadyTold
            guard room > 0 else { continue }

            // Who was there; only they can tell it. Whoever has merely heard it
            // is out of the running to hear it again, but doesn't pass it on.
            let witnesses = Set(firsthand.map(\.entityID)).union(firsthand.flatMap { $0.presentIDs ?? [] })
            let present = witnesses.union(holders.map(\.entityID))
            let story = source.memory + " " + line
            // News is told by a bystander: somebody who was there and isn't in
            // it. Wicker doesn't go round telling people what Wicker did. With
            // no bystander, it's just going round.
            let teller = witnesses
                .filter { names[$0] != nil && !CastStoryNames.mentions(story, name: names[$0] ?? "") }
                .min { CastStoryNames.stableHash(moment + $0) < CastStoryNames.stableHash(moment + $1) }
            let tellerName = teller.flatMap { names[$0] }.map(CastStoryNames.short)
            let near = teller ?? source.entityID

            let eligible = listeners.filter { listener in
                !present.contains(listener.id) && !CastStoryNames.mentions(story, name: listener.name)
            }
            var scores: [String: Int] = [:]
            for listener in eligible {
                let luck = Int(CastStoryNames.stableHash(moment + "|" + listener.id) % 6)
                let tie = min(6, max(0, closeness(near, listener.id)) / 2)
                scores[listener.id] = tie + luck - 2 * (earful[listener.id] ?? 0)
            }
            let ranked: [Listener] = eligible.sorted { left, right in
                let a = scores[left.id] ?? 0
                let b = scores[right.id] ?? 0
                return a == b ? left.id < right.id : a > b
            }

            for (index, hearer) in ranked.prefix(room).enumerated() {
                let spread = Int(CastStoryNames.stableHash(moment + hearer.id) % 2)
                let delay = 1 + alreadyTold + index + spread
                guard let heardAt = calendar.date(byAdding: .day, value: delay, to: source.happenedAt),
                      heardAt <= now else { continue }
                earful[hearer.id, default: 0] += 1
                told.append(CastStoryMemory(
                    id: CastStoryMemory.id(runID: source.runID, key: source.key, entityID: hearer.id),
                    entityID: hearer.id,
                    key: source.key,
                    memory: source.memory,
                    aside: line.replacingOccurrences(of: "{teller}", with: tellerName ?? "Everyone"),
                    witness: .heard,
                    storyTitle: source.storyTitle,
                    momentTitle: source.momentTitle,
                    runID: source.runID,
                    sourceID: source.sourceID,
                    happenedAt: heardAt,
                    frozenAt: now,
                    heardFromID: teller,
                    heardFromName: tellerName
                ))
            }
        }
        return told
    }
}

// MARK: - Asking the Book about them

/// Let's Chat reads the ledger. A message that names a Cast member brings
/// what they remember into the prompt, in their own frame; a plain "what does
/// Wicker remember?" is answered straight from it, in the Book's voice, with
/// no model and nothing invented.
enum LetsChatCastMemory {
    struct Recall: Equatable {
        var entityID: String
        var name: String
        var memories: [CastStoryMemory]

        var shortName: String { CastStoryNames.short(name) }
    }

    static let memoriesPerPerson = 4

    private static let rememberCues = [
        "remember", "recall", "what happened to", "what's happened to", "whats happened to",
        "been up to", "been through", "heard about", "has heard", "have heard", "know about the story",
        "tell me about the story"
    ]

    /// The Cast members the message names, with what they carry, at most two.
    static func recalls(
        for message: String,
        ledger: CastStoryMemoryLedger,
        cast: [(id: String, name: String)],
        now: Date = Date()
    ) -> [Recall] {
        cast
            .filter { CastStoryNames.mentions(message, name: $0.name) }
            .prefix(2)
            .map { member in
                Recall(
                    entityID: member.id,
                    name: member.name,
                    memories: Array(ledger.memories(of: member.id).filter { $0.happenedAt <= now }.prefix(memoriesPerPerson))
                )
            }
    }

    static func asksWhatTheyRemember(_ message: String) -> Bool {
        let text = message.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return rememberCues.contains { text.contains($0) }
    }

    /// The prompt section. Empty when nobody named carries anything.
    static func promptSection(_ recalls: [Recall]) -> String {
        recalls.filter { !$0.memories.isEmpty }.map { recall in
            let lines = recall.memories.map { memory -> String in
                var line = "- (\(witnessNote(memory, reader: "the reader"))) \(memory.memory)"
                if let aside = memory.aside { line += " In \(recall.shortName)'s words: \u{201C}\(aside)\u{201D}" }
                return line
            }
            return """
            WHAT \(recall.name.uppercased()) REMEMBERS FROM THE STORY (theirs, in their own frame, newest first):
            \(lines.joined(separator: "\n"))
            These are \(recall.shortName)'s to tell. You can pass them on in your own words, but don't add to them, and don't say \(recall.shortName) remembers anything that isn't here. If they ask about something that isn't here, say \(recall.shortName) hasn't told you.
            """
        }.joined(separator: "\n\n")
    }

    /// A straight answer to "what does Wicker remember?", or nil when the
    /// message isn't that question or names nobody.
    static func answer(to message: String, recalls: [Recall]) -> String? {
        guard asksWhatTheyRemember(message), let recall = recalls.first else { return nil }
        let name = recall.shortName
        guard !recall.memories.isEmpty else {
            return "\(name) hasn't told me anything from the story yet. Give it a few days. People in the Labyrinth talk eventually, mostly at lunch."
        }
        let shown = recall.memories.prefix(3)
        var paragraphs = [shown.count == 1
            ? "\(name)'s carrying one thing from the story. I've been watching."
            : "\(name)'s carrying a few things from the story. I've been watching."]
        for memory in shown {
            var paragraph = memory.memory
            if let aside = memory.aside { paragraph += " In \(name)'s words: \u{201C}\(aside)\u{201D}" }
            switch memory.witness {
            case .withReader: paragraph += " You were there for that one."
            case .heard:
                paragraph += " \(name) wasn't there. " + (memory.heardFromName.map { "\($0) told." } ?? "It's going round.")
            case .lived: break
            }
            paragraphs.append(paragraph)
        }
        if recall.memories.count > shown.count {
            paragraphs.append("There's more. That's the bit that shows.")
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func witnessNote(_ memory: CastStoryMemory, reader: String) -> String {
        switch memory.witness {
        case .withReader: return "\(reader) was there"
        case .lived: return "it happened in the story"
        case .heard: return memory.heardFromName.map { "heard it from \($0)" } ?? "heard it going round"
        }
    }
}

// MARK: - Holding the pack to it

/// The authoring contract, checked by tests and the release validator.
enum CastStoryMemoryAudit {
    /// Words that name the shape of Serenity's month instead of letting it be
    /// found, and the house's banned register.
    static let bannedWords = [
        "triangle", "romance", "romantic", "love interest", "rival", "suitor", "crush", "in love",
        "hinge", "ritual", "forgive"
    ]

    /// Uncontracted pairs a Cast member wouldn't say out loud.
    static let stiffPairs = [
        "i am ", "i have not", "i will ", "i would ", "do not", "does not", "did not", "is not", "are not",
        "was not", "were not", "cannot", "could not", "would not", "will not", "it is ", "that is ",
        "you are ", "we are ", "they are ", "he is ", "she is ", "there is ", "let us "
    ]

    static func problems(in pack: WorldEventPack, knownEntityIDs: Set<String>) -> [String] {
        var found: [String] = []
        func check(_ memory: AuthoredCastMemory, at place: String, allowed: Set<String>?) {
            let label = "\(place)/\(memory.entityID)/\(memory.key)"
            if !knownEntityIDs.contains(memory.entityID) { found.append("unknown cast member: \(label)") }
            if let allowed, !allowed.contains(memory.entityID) { found.append("not in the scene: \(label)") }
            if memory.key.trimmingCharacters(in: .whitespaces).isEmpty { found.append("empty key: \(label)") }
            let words = memory.memory.split(whereSeparator: \.isWhitespace).count
            if words < 5 || words > 45 { found.append("memory length \(words): \(label)") }
            if memory.memory.lowercased().contains("you ") || memory.memory.hasPrefix("You") {
                found.append("memory addresses the reader (say \"the reader\"): \(label)")
            }
            let text = (memory.memory + " " + (memory.aside ?? "")).lowercased()
            for word in bannedWords where text.contains(word) { found.append("'\(word)': \(label)") }
            if let gossip = memory.gossip {
                let gossipWords = gossip.split(whereSeparator: \.isWhitespace).count
                if gossipWords < 6 || gossipWords > 30 { found.append("gossip length \(gossipWords): \(label)") }
                let spoken = " " + gossip.lowercased().replacingOccurrences(of: "\u{2019}", with: "'") + " "
                for pair in stiffPairs where spoken.contains(" " + pair) { found.append("uncontracted '\(pair)' in gossip: \(label)") }
                for word in bannedWords where spoken.contains(word) { found.append("'\(word)' in gossip: \(label)") }
                if gossip.contains("{") && gossip.replacingOccurrences(of: "{teller}", with: "").contains("{") {
                    found.append("gossip has an unknown placeholder: \(label)")
                }
            }
            if let aside = memory.aside {
                let asideWords = aside.split(whereSeparator: \.isWhitespace).count
                if asideWords < 4 || asideWords > 34 { found.append("aside length \(asideWords): \(label)") }
                let spoken = " " + aside.lowercased().replacingOccurrences(of: "\u{2019}", with: "'") + " "
                for pair in stiffPairs where spoken.contains(" " + pair) { found.append("uncontracted '\(pair)': \(label)") }
            }
        }

        for scene in pack.storyScenes ?? [] {
            let cast = Set(scene.castIDs ?? [])
            for memory in scene.castMemories ?? [] { check(memory, at: scene.id, allowed: cast) }
            for choice in scene.choices {
                for memory in choice.castMemories ?? [] { check(memory, at: "\(scene.id)#\(choice.id)", allowed: cast) }
            }
            for node in scene.nodes ?? [] {
                for memory in node.castMemories ?? [] { check(memory, at: node.id, allowed: cast) }
                for choice in node.choices {
                    for memory in choice.castMemories ?? [] { check(memory, at: "\(node.id)#\(choice.id)", allowed: cast) }
                }
                for recall in node.recalls ?? [] {
                    if node.body.components(separatedBy: recall.marker).count != 2 {
                        found.append("recall marker \(recall.marker) must appear once in \(node.id)")
                    }
                    if recall.options.isEmpty || recall.options.contains(where: { $0.key.isEmpty || $0.line.isEmpty }) {
                        found.append("incomplete recall \(recall.marker) in \(node.id)")
                    }
                }
            }
        }
        for event in pack.events {
            for entry in event.record?.entries ?? [] {
                for memory in entry.castMemories ?? [] {
                    check(memory, at: entry.id, allowed: nil)
                    // A record memory belongs to somebody the account names.
                    let first = memory.entityID.split(separator: "-")
                        .first { !["professor", "dr"].contains($0) }.map(String.init) ?? memory.entityID
                    if !entry.account.lowercased().contains(first.lowercased()) {
                        found.append("record memory for someone the account doesn't name: \(entry.id)/\(memory.entityID)")
                    }
                }
            }
        }
        return found
    }
}
