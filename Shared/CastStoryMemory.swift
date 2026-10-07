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

    static func id(runID: String, key: String, entityID: String) -> String {
        "\(runID)|\(key)|\(entityID)"
    }
}

struct CastStoryMemoryLedger: Codable, Equatable {
    var memories: [CastStoryMemory] = []

    static let empty = CastStoryMemoryLedger()

    /// Adds what's new. A memory already frozen keeps its words; only a
    /// `lived` memory gives way, to the reader's own version of that moment.
    func absorbing(_ incoming: [CastStoryMemory]) -> Self {
        var byID = Dictionary(memories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var order = memories.map(\.id)
        for memory in incoming {
            if let existing = byID[memory.id] {
                guard existing.witness == .lived, memory.witness == .withReader else { continue }
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
                let better = (existing.witness == .lived && memory.witness == .withReader)
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
            for memory in authored {
                offer(frozen(memory, witness: .withReader, storyTitle: entry.storyTitle, momentTitle: scene.title,
                             runID: runID, sourceID: scene.id, happenedAt: receipt.recordedAt, now: now))
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
                for memory in memories {
                    offer(frozen(memory, witness: .lived, storyTitle: event.title, momentTitle: entry.title,
                                 runID: snapshot.runID, sourceID: entry.id, happenedAt: min(happenedAt, now), now: now))
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
            frozenAt: now
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
                summary: "\(memory.storyTitle): \(memory.memory)",
                tags: [tag, "monthly-story", memory.witness == .withReader ? "with-reader" : "lived",
                       "story-key:\(memory.key)", "story-run:\(memory.runID)"],
                // Something that happened to them outweighs a kept page that
                // merely mentioned them; something the reader was there for,
                // more again.
                narrativeWeight: memory.witness == .withReader ? 8 : 6,
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
                let leftRank = (preferred.contains(left.entityID) ? 0 : 2) + (left.witness == .withReader ? 0 : 1)
                let rightRank = (preferred.contains(right.entityID) ? 0 : 2) + (right.witness == .withReader ? 0 : 1)
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
