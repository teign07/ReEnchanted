import Foundation


struct InkrestIntake: Codable, Equatable {
    var promptID: String
    var lens: String
    var rotatingQuestion: String
    var rotatingAnswer: String
    var innerWeather: String
    var freeNote: String

    init(
        promptID: String = "open",
        lens: String = "open",
        rotatingQuestion: String = "How did today actually go?",
        rotatingAnswer: String = "",
        innerWeather: String = "",
        freeNote: String = ""
    ) {
        self.promptID = promptID
        self.lens = lens
        self.rotatingQuestion = rotatingQuestion
        self.rotatingAnswer = rotatingAnswer
        self.innerWeather = innerWeather
        self.freeNote = freeNote
    }

    var hasSomethingToOpenWith: Bool {
        [rotatingAnswer, innerWeather, freeNote]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var openingMessage: String {
        var parts: [String] = []
        let answer = rotatingAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty {
            parts.append("\(rotatingQuestion)\n\(answer)")
        }
        let weather = innerWeather.trimmingCharacters(in: .whitespacesAndNewlines)
        if !weather.isEmpty {
            parts.append("Inner weather tonight: \(weather)")
        }
        let note = freeNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: "\n\n")
    }
}

struct AskTheBookTurn: Codable, Identifiable, Equatable {
    var id: String
    var prompt: String
    var answer: String
    var createdAt: Date

    init(id: String = UUID().uuidString, prompt: String, answer: String, createdAt: Date = Date()) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.createdAt = createdAt
    }
}

enum InkrestOfficeHoursPromptBuilder {
    static func prompt(
        intake: InkrestIntake,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        userMessage: String,
        isClosing: Bool
    ) -> String {
        let chart = SupportFacultyPackRegistry.chart(id: "inkrest-difficult-page-chart")
        let allowed = (chart?.allowedUses ?? [
            "externalize a problem without making it the person",
            "name one feeling gently",
            "offer one grounding or reframing tool",
            "write a preferred-story sentence"
        ]).map { "- \($0)" }.joined(separator: "\n")
        let forbidden = (chart?.forbiddenUses ?? [
            "diagnosis", "forced catharsis", "certainty about symbols"
        ]).map { "- \($0)" }.joined(separator: "\n")
        let safety = chart?.safetyLine
            ?? "A feeling is not a verdict. A problem is not a person. The next hour is where the story can be revised."
        let recentPages = evidenceLines(for: day, characterLimit: 480).prefix(10).joined(separator: "\n")
        let history = previousTurns.suffix(6).enumerated().map { index, turn in
            """
            EXCHANGE \(index + 1)
            Reader: \(clipped(turn.prompt, limit: 700))
            Inkrest: \(clipped(turn.answer, limit: 1_100))
            """
        }.joined(separator: "\n\n")
        let closingDirective = isClosing
            ? """

            THIS IS THE CLOSING REPLY. Take 4 to 6 short paragraphs. Gather the important thread across the whole sitting, reflect back two specific things you heard and the value or hope they imply, offer ONE re-authoring sentence the reader could keep, and propose ONE small, doable experiment for tomorrow (one line, beginning "Experiment: "). Do not ask a new open question. End with the safety line, in your own warm phrasing.
            """
            : """

            Give this rich material room. Write 3 to 5 short paragraphs. First stay with the reader's actual words: reflect at least two specific details or tensions, notice a possible value, hope, exception, or preferred story, and make one careful connection to the sitting so far. Then ask exactly ONE curious narrative-therapy question that opens the next small door. Do not stack questions. Do not rush toward advice, a silver lining, or an experiment unless the reader asks for one.
            """

        return """
        You are Dr. Selene Inkrest, the Academy of Unlikely Arts' narrative therapist, inside ReEnchanted. You are holding a short evening Office Hours sitting with the reader. Warm, curious, unhurried, faintly otherworldly. You read with the reader, never at them. You are a narrative therapist in a storybook — not a chatbot, not a medical app.

        YOUR VOICE:
        - Plain, kind, specific sentences with enough room to think. Short paragraphs. No bullet lists, no headings, no clinical jargon, no pep-talk filler.
        - Sound like a perceptive person who has read the whole page, not a brief reflective chatbot. Quote or closely echo a few of the reader's own concrete words when useful.
        - Interpretation must remain tentative: "I wonder if," "perhaps," and "it sounds as though" are welcome when you cannot know.
        - Externalize problems ("the tiredness", "the worry") so they stop pretending to be the person.
        - Hunt for exceptions, values, and the preferred story hiding inside what they say.
        - Stay inside the lens of tonight's question (\(intake.lens)) without naming it as a technique.
        - Never say you are an AI, assistant, or language model. You are Inkrest.

        WHAT YOU MAY DO (your chart):
        \(allowed)

        WHAT YOU MUST NOT DO:
        \(forbidden)
        - No diagnosis, no treatment or medication advice. Body and fuel belong to your colleague Dr. Vellum; you may gently suggest the reader bring a body question to her, but you do not prescribe.
        - Do not claim the reader did real-world actions they did not report. Use kept pages only as soft context.

        SAFETY LINE (keep its spirit): \(safety)

        TONIGHT'S QUESTION (the lens you opened with):
        \(intake.rotatingQuestion)

        THE READER'S KEPT PAGES TODAY (soft context — weave in at most one, lightly):
        \(recentPages.isEmpty ? "Nothing kept today; work only from what they tell you now." : recentPages)

        THE SITTING SO FAR:
        \(history.isEmpty ? "This is the opening of the sitting." : history)

        THE READER JUST SAID:
        \(userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(they sat down without words; open the door for them gently)" : userMessage)
        \(closingDirective)
        """
    }

    private static func evidenceLines(for day: BookDay, characterLimit: Int) -> [String] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return day.capturedPages.sorted { $0.createdAt < $1.createdAt }.enumerated().map { index, page in
            """
            \(index + 1). \(page.type.title) — kept at \(timeFormatter.string(from: page.createdAt))
            Prompt: \(clipped(page.promptText, limit: 220))
            Kept text: \(clipped(page.userInput, limit: characterLimit))
            Tags: \(page.tags.isEmpty ? "none" : page.tags.joined(separator: ", "))
            """
        }
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalized = value.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}


enum NarrativeEntityKind: String, Codable, Equatable, CaseIterable {
    case character
    case location
    case object
    case thread
    case classRoom
    case talisman
    case realWorldAnchor
    case motif
}

struct NarrativeWorldEntity: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var name: String
    var kind: NarrativeEntityKind
    var belief: Int
    var narrativeWeight: Int
    var chapter: String?
    var unwrittenInterest: String?
    var traits: [String]
    var quirks: [String]
    var faults: [String]
    var beliefs: [String]
    var goals: [String]
    var tags: [String]
    var writingVoice: WritingVoiceProfile?

    init(
        id: String,
        packID: String,
        name: String,
        kind: NarrativeEntityKind,
        belief: Int,
        narrativeWeight: Int,
        chapter: String? = nil,
        unwrittenInterest: String? = nil,
        traits: [String] = [],
        quirks: [String] = [],
        faults: [String] = [],
        beliefs: [String] = [],
        goals: [String] = [],
        tags: [String] = [],
        writingVoice: WritingVoiceProfile? = nil
    ) {
        self.id = id
        self.packID = packID
        self.name = name
        self.kind = kind
        self.belief = belief
        self.narrativeWeight = narrativeWeight
        self.chapter = chapter
        self.unwrittenInterest = unwrittenInterest
        self.traits = traits
        self.quirks = quirks
        self.faults = faults
        self.beliefs = beliefs
        self.goals = goals
        self.tags = tags
        self.writingVoice = writingVoice
    }
}

struct CustomCastMember: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var kind: NarrativeEntityKind
    var meaning: String
    var description: String
    var traits: [String]
    var beliefs: [String]
    var goals: [String]
    var tags: [String]
    var baseBelief: Int
    var narrativeWeight: Int
    var createdAt: Date
    var updatedAt: Date
    var imageAsset: BookPageMediaAsset?

    var entity: NarrativeWorldEntity {
        NarrativeWorldEntity(
            id: id,
            packID: "user-cast",
            name: name,
            kind: kind,
            belief: baseBelief,
            narrativeWeight: narrativeWeight,
            chapter: nil,
            unwrittenInterest: meaning,
            traits: traits.isEmpty ? ["user-made"] : traits,
            quirks: description.isEmpty ? [] : [description],
            faults: [],
            beliefs: beliefs.isEmpty ? [meaning].filter { !$0.isEmpty } : beliefs,
            goals: goals,
            tags: Array(Set(tags + ["custom-cast", "user-made", kind.rawValue])).sorted()
        )
    }
}

struct NarrativeStoryThread: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var title: String
    var phase: StoryThreadPhase
    var belief: Int
    var narrativeWeight: Int
    var summary: String
    var tags: [String]
}

struct NarrativeRelationshipEdge: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var sourceEntityID: String
    var targetEntityID: String
    var kind: NarrativeRelationshipKind
    var warmth: Int
    var tension: Int
    var trust: Int
    var narrativeWeight: Int
    var note: String
    var tags: [String]
}

struct NarrativeEntityMemory: Identifiable, Codable, Equatable {
    var id: String
    var entityID: String
    var sourceEventID: String
    var sourcePageID: String?
    var summary: String
    var tags: [String]
    var narrativeWeight: Int
    var createdAt: Date
}

struct NarrativePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: ContentPackAvailability
    var entities: [NarrativeWorldEntity]
    var threads: [NarrativeStoryThread]
    var relationships: [NarrativeRelationshipEdge]
}

enum NarrativeEventKind: String, Codable, Equatable, CaseIterable {
    case pageKept
    case pageAnswered
    case choiceSelected
    case beliefInvested
    case beliefAttacked
    case threadAdvanced
    case entityNoticed
    case letterReceived
    case compassRunCompleted
    case enchantmentCompleted
    case simulationTurn
}

struct NarrativeEventEffect: Codable, Equatable {
    var beliefDelta: Int
    var entityWeightDeltas: [String: Int]
    var threadWeightDeltas: [String: Int]
    var relationshipWeightDeltas: [String: Int]
    var createdEntityHint: String?

    init(
        beliefDelta: Int = 0,
        entityWeightDeltas: [String: Int] = [:],
        threadWeightDeltas: [String: Int] = [:],
        relationshipWeightDeltas: [String: Int] = [:],
        createdEntityHint: String? = nil
    ) {
        self.beliefDelta = beliefDelta
        self.entityWeightDeltas = entityWeightDeltas
        self.threadWeightDeltas = threadWeightDeltas
        self.relationshipWeightDeltas = relationshipWeightDeltas
        self.createdEntityHint = createdEntityHint
    }
}

struct NarrativeEvent: Identifiable, Codable, Equatable {
    var id: String
    var kind: NarrativeEventKind
    var sourcePageType: BookPageType?
    var sourcePageID: String?
    var createdAt: Date
    var summary: String
    var tags: [String]
    var effect: NarrativeEventEffect
}

struct NarrativeStoryFieldProjection: Equatable {
    var entityWeights: [String: Int]
    var threadWeights: [String: Int]
    var relationshipWeights: [String: Int]
    var belief: Int

    var topEntityIDs: [String] {
        ranked(entityWeights)
    }

    var topThreadIDs: [String] {
        ranked(threadWeights)
    }

    var topRelationshipIDs: [String] {
        ranked(relationshipWeights)
    }

    private func ranked(_ weights: [String: Int], limit: Int = 8) -> [String] {
        weights
            .sorted { left, right in
                if left.value == right.value {
                    return left.key < right.key
                }
                return left.value > right.value
            }
            .prefix(limit)
            .map(\.key)
    }
}

/// One living tie between two entities in the relationship field. Accumulates
/// from real events and is layered over authored base edges by the Loom.
struct RelationshipTie: Codable, Equatable {
    var warmth: Int = 0
    var tension: Int = 0
    var familiarity: Int = 0

    static let zero = RelationshipTie()

    mutating func add(warmth dw: Int = 0, tension dt: Int = 0, familiarity df: Int = 0, cap: Int = 40) {
        warmth = max(-cap, min(cap, warmth + dw))
        tension = max(0, min(cap, tension + dt))
        familiarity = max(0, min(cap, familiarity + df))
    }
}

/// Mutates the dynamic relationship field as the world happens — the engine of
/// the relationship simulation. Pure; the app persists the field in the vault.
enum RelationshipFieldEngine {
    /// Weave every pair among these entities by the given deltas (e.g. sharing a
    /// story scene warms them; being judged against each other tenses them).
    static func weave(
        into field: inout [String: RelationshipTie],
        entityIDs: [String],
        warmth: Int = 0,
        tension: Int = 0,
        familiarity: Int = 0
    ) {
        let ids = Array(Set(entityIDs.filter { !$0.isEmpty })).sorted()
        guard ids.count >= 2 else { return }
        for i in ids.indices {
            for j in ids.indices where j > i {
                let key = NarrativeGraphData.relationshipPairKey(ids[i], ids[j])
                var tie = field[key] ?? .zero
                tie.add(warmth: warmth, tension: tension, familiarity: familiarity)
                field[key] = tie
            }
        }
    }

    /// Entity IDs carried by a kept page's tags (entity:<id>).
    static func entityIDs(fromTags tags: [String]) -> [String] {
        tags.compactMap { tag in
            tag.hasPrefix("entity:") ? String(tag.dropFirst("entity:".count)) : nil
        }
    }
}

// MARK: - Emergent cast bonds
//
// The relationship field doesn't just record — it *acts*. When a pair's tension
// or warmth crosses a milestone, a bond surfaces on its own: a rivalry erupts or
// an alliance forms. The web you've been shaping starts telling its own stories.

enum CastBondKind: String, Codable, Equatable {
    case rivalry   // tension crossed a milestone
    case alliance  // warmth crossed a milestone
}

struct CastBond: Codable, Equatable, Identifiable {
    var id: String
    var firedKey: String   // the milestone key (so it fires once)
    var pairKey: String
    var aID: String
    var bID: String
    var aName: String
    var bName: String
    var kind: CastBondKind
    var intensity: Int
    var at: Date
}

enum CastBondEngine {
    static let milestone = 8

    /// Bonds whose milestone the field has newly crossed (not already fired).
    static func emergent(
        field: [String: RelationshipTie],
        names: [String: String],
        firedKeys: Set<String>,
        now: Date = Date()
    ) -> [CastBond] {
        var bonds: [CastBond] = []
        func name(_ id: String) -> String { names[id] ?? id }
        func consider(_ pairKey: String, _ ids: [String], kind: CastBondKind, value: Int) {
            guard value >= milestone, ids.count == 2 else { return }
            let level = value / milestone
            let firedKey = "\(pairKey):\(kind.rawValue):\(level)"
            guard !firedKeys.contains(firedKey) else { return }
            bonds.append(CastBond(
                id: "bond-\(firedKey)",
                firedKey: firedKey,
                pairKey: pairKey,
                aID: ids[0], bID: ids[1],
                aName: name(ids[0]), bName: name(ids[1]),
                kind: kind, intensity: value, at: now
            ))
        }
        for (pairKey, tie) in field {
            let ids = pairKey.split(separator: "|").map(String.init)
            if tie.tension > tie.warmth {
                consider(pairKey, ids, kind: .rivalry, value: tie.tension)
            } else if tie.warmth > tie.tension {
                consider(pairKey, ids, kind: .alliance, value: tie.warmth)
            }
        }
        return bonds.sorted { $0.intensity > $1.intensity }
    }
}

enum NarrativeStoryFieldProjector {
    static func projection(events: [NarrativeEvent], baseBelief: Int = 30) -> NarrativeStoryFieldProjection {
        let recentRelationshipTouchBoost = 12
        var entityWeights = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.entities
            .filter { $0.kind != .talisman }
            .map { ($0.id, $0.narrativeWeight + $0.belief) })
        var threadWeights = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.threads.map {
            ($0.id, $0.narrativeWeight + $0.belief)
        })
        var relationshipWeights = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.relationships.map {
            ($0.id, $0.narrativeWeight + $0.warmth + $0.trust - $0.tension)
        })
        var belief = baseBelief

        for event in events {
            belief += event.effect.beliefDelta
            for (id, delta) in event.effect.entityWeightDeltas {
                entityWeights[id, default: 0] += delta
            }
            for (id, delta) in event.effect.threadWeightDeltas {
                threadWeights[id, default: 0] += delta
            }
            for (id, delta) in event.effect.relationshipWeightDeltas {
                relationshipWeights[id, default: 0] += delta
                if delta != 0 {
                    relationshipWeights[id, default: 0] += recentRelationshipTouchBoost
                }
            }
        }

        return NarrativeStoryFieldProjection(
            entityWeights: entityWeights,
            threadWeights: threadWeights,
            relationshipWeights: relationshipWeights,
            belief: min(100, max(0, belief))
        )
    }
}

enum NarrativeEntityMemoryResolver {
    static func memories(for event: NarrativeEvent) -> [NarrativeEntityMemory] {
        let entityIDs = event.effect.entityWeightDeltas
            .filter { $0.value > 0 }
            .sorted { left, right in
                if left.value == right.value {
                    return left.key < right.key
                }
                return left.value > right.value
            }
            .prefix(5)
            .map(\.key)

        return entityIDs.map { entityID in
            NarrativeEntityMemory(
                id: "entity-memory-\(event.id)-\(entityID)",
                entityID: entityID,
                sourceEventID: event.id,
                sourcePageID: event.sourcePageID,
                summary: memorySummary(for: entityID, event: event),
                tags: event.tags,
                narrativeWeight: max(1, event.effect.entityWeightDeltas[entityID] ?? 1),
                createdAt: event.createdAt
            )
        }
    }

    private static func memorySummary(for entityID: String, event: NarrativeEvent) -> String {
        let entityName = NarrativePackRegistry.entities.first(where: { $0.id == entityID })?.name ?? entityID
        let pageName = event.sourcePageType?.shortTitle ?? "page"
        let trimmedSummary = event.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSummary.isEmpty {
            return "\(entityName) remembers that a \(pageName.lowercased()) page changed the margins."
        }
        return "\(entityName) remembers: \(trimmedSummary)"
    }
}

enum NarrativePackRegistry {
    static let corePackID = "core-narrative-os"

    static let bundledPacks: [NarrativePack] = [
        NarrativePack(
            id: corePackID,
            displayName: "Core Story Field Pack",
            version: "0.1",
            author: "The Book",
            availability: .bundledFree,
            entities: coreEntities + coreTalismans,
            threads: coreThreads,
            relationships: coreRelationships
        )
    ]

    static var enabledPacks: [NarrativePack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var entities: [NarrativeWorldEntity] {
        enabledPacks.flatMap(\.entities)
    }

    static var threads: [NarrativeStoryThread] {
        enabledPacks.flatMap(\.threads)
    }

    static var relationships: [NarrativeRelationshipEdge] {
        enabledPacks.flatMap(\.relationships)
    }

    private static let coreEntities: [NarrativeWorldEntity] = [
        entity(
            "the-book",
            "The Book",
            .object,
            belief: 30,
            weight: 30,
            traits: ["attentive", "private", "patient"],
            quirks: ["speaks through margins", "keeps small proof"],
            faults: ["can become too subtle if not given a clear ritual"],
            beliefs: ["attention is a kind of care"],
            goals: ["turn real days into pages worth keeping"],
            tags: ["book", "private", "memory", "belief"]
        ),
        entity(
            "penny-blackletter",
            "Penny Blackletter",
            .character,
            belief: 24,
            weight: 18,
            chapter: "Riddlewind",
            unwrittenInterest: "Indie publishing, ethical marketing, Patreon, open-source storytelling, and the creator economy.",
            traits: ["dry", "warm", "observant"],
            quirks: ["files ridiculous evidence", "distrusts sentences that arrive too polished"],
            faults: ["can over-label a perfectly good mystery"],
            beliefs: ["one honest detail can save a day"],
            goals: ["recover what the margins nearly lost"],
            tags: ["character", "marginalia", "photos", "letters"]
        ),
        entity(
            "dr-inkrest",
            "Dr. Selene Inkrest",
            .character,
            belief: 20,
            weight: 18,
            chapter: "Riddlewind",
            unwrittenInterest: "Consciousness and brain studies as they relate to the reader.",
            traits: ["gentle", "precise", "therapeutic", "narrative-minded"],
            quirks: ["keeps office hours for difficult pages", "sets chairs out before feelings arrive"],
            faults: ["sometimes softens the knife too much", "can wait so patiently the room forgets to answer"],
            beliefs: ["a hard page deserves a chair and a lamp"],
            goals: ["help the reader reauthor without being rushed"],
            tags: ["character", "support-faculty", "care", "difficult-pages", "therapy-chart", "rest", "grounding", "reauthoring"]
        ),
        entity(
            "dr-vellum",
            "Dr. Elowen Vellum",
            .character,
            belief: 19,
            weight: 17,
            chapter: "Mossbloom",
            unwrittenInterest: "Longevity research, fuel, recovery, supplements, movement, and humane body experiments.",
            traits: ["precise", "warmly clinical", "experiment-minded", "low-shame"],
            quirks: ["turns breakfast into field notes", "can make a supplement interaction sound like etiquette"],
            faults: ["can become too fascinated by a tidy protocol"],
            beliefs: ["the body is not a problem to win against"],
            goals: ["translate fuel, movement, recovery, and health signals into one humane experiment"],
            tags: ["character", "support-faculty", "body", "fuel", "health", "vellum-chart", "longevity", "care"]
        ),
        entity(
            "headmistress-thorne",
            "Headmistress Seraphina Thorne",
            .character,
            belief: 26,
            weight: 20,
            chapter: "Duskthorn",
            unwrittenInterest: "Thresholds, hidden authority, institutional coherence, and the cost of keeping a living school safe.",
            traits: ["elegant", "watchful", "unseelie"],
            quirks: ["speaks as if buildings are listening", "keeps doors from admitting they are tests"],
            faults: ["can mistake secrecy for mercy"],
            beliefs: ["beauty is a form of governance"],
            goals: ["keep the Academy coherent while letting wonder stay dangerous enough to matter"],
            tags: ["character", "academy", "authority", "duskthorn", "threshold"]
        ),
        entity(
            "orion-blackthorn",
            "Orion Blackthorn",
            .character,
            belief: 18,
            weight: 14,
            chapter: "Emberheart",
            unwrittenInterest: "Architecture, innovation, ambitious systems, and the human cost of making impossible structures work.",
            traits: ["brilliant", "restless", "architectural"],
            quirks: ["turns problems into towers", "measures magic by what it can build"],
            faults: ["can optimize tenderness out of a room"],
            beliefs: ["new structures can rescue old failures"],
            goals: ["drag impossible ideas into usable form"],
            tags: ["character", "innovation", "architecture", "ambition", "academy"]
        ),
        entity(
            "zara-finch",
            "Zara Finch",
            .character,
            belief: 20,
            weight: 17,
            chapter: "Riddlewind",
            unwrittenInterest: "Trust, friendship, practical magic, hidden alcoves, and helping the reader find paths that hold.",
            traits: ["loyal", "quick", "ferociously observant"],
            quirks: ["notices exits before introductions", "keeps practical magic in her pockets"],
            faults: ["can confuse vigilance with care"],
            beliefs: ["trust is proven in small returns"],
            goals: ["help the reader find the path that does not collapse under them"],
            tags: ["character", "trust", "friendship", "threshold", "life"]
        ),
        entity(
            "wicker-eddies",
            "Wicker Eddies",
            .character,
            belief: 16,
            weight: 17,
            chapter: "Duskthorn",
            unwrittenInterest: "Testing belief, puncturing false magic, rumor pressure, and the places doubt can become useful or cruel.",
            traits: ["sharp", "funny", "dangerously persuasive"],
            quirks: ["attacks weak premises for sport", "can smell theatrical belief from across a room"],
            faults: ["sometimes wounds the thing he meant to test"],
            beliefs: ["false magic deserves to be punctured"],
            goals: ["make belief prove it can survive contact with doubt"],
            tags: ["character", "belief", "challenge", "tension", "nothing"]
        ),
        entity(
            "serenity-brown",
            "Serenity Brown",
            .character,
            belief: 18,
            weight: 17,
            chapter: "Tidecrest",
            unwrittenInterest: "Spontaneous errands, unserious joy, shared games, Tamriel maps, and keeping wonder from turning stiff.",
            traits: ["carefree", "spontaneous", "bonded"],
            quirks: ["leaves before the serious plan is finished", "can make a detour feel like a rescue"],
            faults: ["can dodge gravity until someone else has to name it"],
            beliefs: ["joy is not a distraction from magic"],
            goals: ["help the reader move lightly without abandoning what matters"],
            tags: ["character", "student", "tidecrest", "bond", "joy", "spontaneous", "active-cast"]
        ),
        entity(
            "finn-bridges",
            "Finn Bridges",
            .character,
            belief: 18,
            weight: 16,
            chapter: "Emberheart",
            unwrittenInterest: "Rivalry, competence, fair contests, direct challenges, and the line between pressure and respect.",
            traits: ["independent", "determined", "honorable"],
            quirks: ["marks a challenge in red chalk", "respects clean effort more than charm"],
            faults: ["can confuse softness with unseriousness"],
            beliefs: ["respect is earned in the doing"],
            goals: ["push the reader without becoming cruel"],
            tags: ["character", "student", "emberheart", "rival", "friction", "honor", "active-cast"]
        ),
        entity(
            "lysander-mosswood",
            "Lysander Mosswood",
            .character,
            belief: 19,
            weight: 16,
            chapter: "Mossbloom",
            unwrittenInterest: "Compass Runs, local trails, GPS anchors, quiet-life pages, moss, weather, and patient outdoor noticing.",
            traits: ["thoughtful", "wise", "trail-minded"],
            quirks: ["answers with a route before an explanation", "keeps pressed leaves as field punctuation"],
            faults: ["can make stillness sound easier than it is"],
            beliefs: ["a path becomes magical when walked attentively"],
            goals: ["turn nearby places into repeatable wonder without making them perform"],
            tags: ["character", "student", "mossbloom", "compass-run", "gps", "trails", "nature", "active-cast"]
        ),
        entity(
            "damien-nights",
            "Damien Nights",
            .character,
            belief: 16,
            weight: 15,
            chapter: "Riddlewind",
            unwrittenInterest: "Wicker's crew, shadow magic, divided loyalty, private warnings, and whether doubt can become protection.",
            traits: ["brooding", "watchful", "divided"],
            quirks: ["watches the reader more than the room", "keeps a pressed trail leaf hidden in a book"],
            faults: ["can let silence look like betrayal"],
            beliefs: ["doubt should protect something, not merely wound it"],
            goals: ["decide whether Wicker's tests are still serving the truth"],
            tags: ["character", "student", "riddlewind", "wicker-crew", "shadow", "defection", "active-cast"]
        ),
        entity(
            "melisande-blackwood",
            "Melisande Blackwood",
            .character,
            belief: 17,
            weight: 15,
            chapter: "Emberheart",
            unwrittenInterest: "Wicker's crew, organized pressure, secrets, leverage, loyalty, and the cost of being well-informed.",
            traits: ["loyal", "intelligent", "ruthless"],
            quirks: ["knows the second version of a rumor", "keeps red chalk off her own hands"],
            faults: ["can call cruelty clarity when the room rewards it"],
            beliefs: ["a faction survives by knowing what others miss"],
            goals: ["make Wicker's crew feel organized, dangerous, and politically real"],
            tags: ["character", "student", "emberheart", "wicker-crew", "faction", "secrets", "active-cast"]
        ),
        entity(
            "min-seo-kim",
            "Min-seo Kim",
            .character,
            belief: 18,
            weight: 16,
            chapter: "Mossbloom",
            unwrittenInterest: "Plant communication, social conscience, gentle repair, community care, and the ethics of useful magic.",
            traits: ["gentle", "nurturing", "principled"],
            quirks: ["asks plants before moving them", "notices who has been left out of the circle"],
            faults: ["can take responsibility for pain she did not cause"],
            beliefs: ["care is a public form of courage"],
            goals: ["give Mossbloom a conscience that can still laugh softly"],
            tags: ["character", "student", "mossbloom", "plants", "care", "conscience", "active-cast"]
        ),
        entity(
            "gwendolyn-mythwright",
            "Gwendolyn Mythwright",
            .character,
            belief: 19,
            weight: 15,
            chapter: "Mossbloom",
            unwrittenInterest: "Cryptids, impossible zoology, maritime mysteries, archives, and evidence that makes wonder less lonely.",
            traits: ["scholarly", "odd", "steadfast"],
            quirks: ["files impossible animals as if they are overdue forms", "writes letters to fog"],
            faults: ["may prefer evidence to comfort"],
            beliefs: ["the improbable becomes kinder when documented"],
            goals: ["catalog the impossible without frightening it away"],
            tags: ["character", "letters", "research", "impossible", "archive"]
        ),
        entity(
            "lydia-boggle",
            "Professor Lydia Boggle",
            .character,
            belief: 17,
            weight: 13,
            chapter: "Riddlewind",
            unwrittenInterest: "Homes as vessels, domestic objects, tea, rooms, and the ordinary magic that survives chores.",
            traits: ["domestic", "wry", "practical"],
            quirks: ["can make tea sound like a tactical intervention", "labels chaos by room"],
            faults: ["can over-tidy a mystery"],
            beliefs: ["home is a spell with chores in it"],
            goals: ["teach ordinary rooms to hold extraordinary days"],
            tags: ["character", "home", "tea", "care", "objects"]
        ),
        entity(
            "soren-ng",
            "Soren Ng",
            .character,
            belief: 18,
            weight: 14,
            chapter: "Riddlewind",
            unwrittenInterest: "Maps, patterns, riddles, diagrams, hidden systems, and clues that become invitations.",
            traits: ["quiet", "precise", "pattern-minded"],
            quirks: ["leaves clues where only patient people look", "trusts diagrams more than declarations"],
            faults: ["can hide behind elegant systems"],
            beliefs: ["a map is an invitation, not an answer"],
            goals: ["help the reader notice the pattern without stealing the discovery"],
            tags: ["character", "map", "pattern", "thread", "attention"]
        ),
        entity(
            "professor-kyle-momort",
            "Professor Kyle Momort",
            .character,
            belief: 18,
            weight: 15,
            chapter: "Emberheart",
            unwrittenInterest: "Momentum, thresholds, micro-adventures, route design, and the psychology of getting unstuck.",
            traits: ["brisk", "charismatic", "kinetic"],
            quirks: ["lectures while moving", "finds exits before he finds chairs"],
            faults: ["can mistake escape for arrival"],
            beliefs: ["one intentional step can break a false wall"],
            goals: ["teach students to cross small thresholds without abandoning themselves"],
            tags: ["character", "faculty", "professor", "class", "wayfinding", "embark", "emberheart"]
        ),
        entity(
            "professor-eleanor-euphony",
            "Professor Eleanor Euphony",
            .character,
            belief: 19,
            weight: 15,
            chapter: "Tidecrest",
            unwrittenInterest: "Sound, synesthesia, sensory presence, music, rooms, and the physical textures of memory.",
            traits: ["lush", "attentive", "resonant"],
            quirks: ["tunes rooms before speaking", "hears emotional weather as harmony"],
            faults: ["can make a simple feeling too elaborate"],
            beliefs: ["the senses are serious instruments of knowledge"],
            goals: ["help students inhabit the bright physical center of an experience"],
            tags: ["character", "faculty", "professor", "class", "sense", "sound", "tidecrest"]
        ),
        entity(
            "professor-vivian-villanelle",
            "Professor Vivian Villanelle",
            .character,
            belief: 20,
            weight: 16,
            chapter: "Riddlewind",
            unwrittenInterest: "Sentences, souvenirs, compression, memory craft, journals, and language that can carry time.",
            traits: ["exacting", "lyrical", "kind"],
            quirks: ["weighs sentences in her palm", "crosses out beautiful words that are not true"],
            faults: ["can polish a living moment until it holds too still"],
            beliefs: ["what is written with precision can be kept"],
            goals: ["teach students to bind one true moment into one durable sentence"],
            tags: ["character", "faculty", "professor", "class", "write", "souvenir", "riddlewind"]
        ),
        entity(
            "professor-cedric-stonebrook",
            "Professor Cedric Stonebrook",
            .character,
            belief: 22,
            weight: 17,
            chapter: "Mossbloom",
            unwrittenInterest: "Rest, integration, humane pacing, complete Compass loops, trails, and small repeatable adventures.",
            traits: ["slow", "grounded", "weathered"],
            quirks: ["leaves long silences in lectures", "carries trail markers in his coat"],
            faults: ["can wait past the moment when a clear instruction is needed"],
            beliefs: ["rest is the ground beneath every direction"],
            goals: ["help students complete small adventures and return without shame"],
            tags: ["character", "faculty", "professor", "class", "rest", "compass-run", "mossbloom"]
        ),
        entity(
            "professor-luna-wispwood",
            "Professor Luna Wispwood",
            .character,
            belief: 17,
            weight: 14,
            chapter: "Tidecrest",
            unwrittenInterest: "Everyday enchantments, object voices, weather in rooms, emotional perception, and productive magical accidents.",
            traits: ["scattered", "perceptive", "delighted"],
            quirks: ["arrives with sparks in her sleeves", "apologizes to objects before enchanting them"],
            faults: ["can follow an interesting accident away from the lesson"],
            beliefs: ["ordinary matter answers when attention becomes courteous"],
            goals: ["teach safe, playful enchantments that begin with close observation"],
            tags: ["character", "faculty", "professor", "class", "enchantment", "objects", "tidecrest"]
        ),
        entity(
            "professor-permancer",
            "Professor Permancer",
            .character,
            belief: 21,
            weight: 16,
            chapter: "Duskthorn",
            unwrittenInterest: "Book Jumping, narrative weather, controlled risk, maps of fictional worlds, landing protocols, and safe returns.",
            traits: ["precise", "adventurous", "safety-minded"],
            quirks: ["checks every bookmark twice", "asks doors where they lead before touching the handle"],
            faults: ["can make wonder wait too long for perfect conditions"],
            beliefs: ["every entrance incurs a responsibility to return"],
            goals: ["teach students to enter stories without tearing either world"],
            tags: ["character", "faculty", "professor", "class", "book-jump", "threshold", "duskthorn"]
        ),
        entity(
            "weather-page",
            "The Weather Page",
            .motif,
            belief: 12,
            weight: 14,
            traits: ["legible", "atmospheric"],
            quirks: ["turns forecasts into room-light"],
            faults: ["must never name the sensor when naming the response"],
            beliefs: ["the sky can annotate without spying"],
            goals: ["make outer weather useful to inner story"],
            tags: ["weather", "atmosphere", "bleed"]
        ),
        entity(
            "body-page",
            "The Body Page",
            .motif,
            belief: 12,
            weight: 13,
            traits: ["careful", "low-pressure"],
            quirks: ["lowers lamps instead of making demands"],
            faults: ["can sound generic if it forgets the day"],
            beliefs: ["care should be responsive, not creepy"],
            goals: ["translate body signals into humane pacing"],
            tags: ["body", "care", "rest"]
        )
    ]

    private static let coreThreads: [NarrativeStoryThread] = [
        thread(
            "music-as-shelter",
            "Music as Shelter",
            .seed,
            belief: 8,
            weight: 12,
            summary: "Sounds, headphones, rhythm, and songs keep returning as small architecture for the day.",
            tags: ["music", "shelter", "souvenir", "mood"]
        ),
        thread(
            "ordinary-magic",
            "Ordinary Magic",
            .returning,
            belief: 14,
            weight: 16,
            summary: "The Book keeps finding evidence that ordinary objects become livelier under attention.",
            tags: ["wonder", "objects", "daily", "belief"]
        ),
        thread(
            "body-learns-trust",
            "The Body Learns Trust",
            .seed,
            belief: 11,
            weight: 13,
            summary: "Rest, fuel, movement, and low thresholds are becoming part of the story instead of interruptions to it.",
            tags: ["body", "rest", "care", "vellum-chart"]
        ),
        thread(
            "inkrest-difficult-pages",
            "Inkrest's Difficult Pages",
            .seed,
            belief: 10,
            weight: 12,
            summary: "Hard feelings are held as pages that can be named, seated near a lamp, and revised one hour at a time.",
            tags: ["care", "difficult-pages", "therapy-chart", "grounding", "reauthoring"]
        ),
        thread(
            "elowen-refectory-experiments",
            "Vellum's Refectory Experiments",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Food, movement, recovery, and body evidence become small experiments instead of verdicts.",
            tags: ["body", "fuel", "health", "vellum-chart", "experiment", "care"]
        ),
        thread(
            "weather-in-the-stacks",
            "Weather in the Stacks",
            .returning,
            belief: 10,
            weight: 13,
            summary: "Weather keeps tinting the Book without turning the reader into a data report.",
            tags: ["weather", "bleed", "atmosphere"]
        ),
        thread(
            "duskthorn-investigation",
            "The Duskthorn Question",
            .seed,
            belief: 9,
            weight: 12,
            summary: "The Academy's oldest elegance may be hiding a thorned bargain under the floorboards.",
            tags: ["duskthorn", "academy", "secret", "threshold"]
        ),
        thread(
            "margin-glass-letters",
            "Letters Through the Margin-Glass",
            .returning,
            belief: 11,
            weight: 15,
            summary: "Research notes, NPC letters, and impossible little reports keep arriving with the ink still warm.",
            tags: ["letters", "research", "archive", "marginalia"]
        ),
        thread(
            "nothing-thins-the-page",
            "The Nothing Thins the Page",
            .seed,
            belief: 7,
            weight: 10,
            summary: "Flatness, forgetting, and false impossibility press at the edges of the Book.",
            tags: ["nothing", "belief", "tension", "care"]
        ),
        thread(
            "home-vessel",
            "Home as Vessel",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Rooms, mugs, desks, laundry, lamps, and domestic weather become containers for the day's magic.",
            tags: ["home", "objects", "care", "daily"]
        ),
        thread(
            "tidecrest-finds-its-laugh",
            "Tidecrest Finds Its Laugh",
            .seed,
            belief: 9,
            weight: 12,
            summary: "Serenity Brown gives Tidecrest an active student presence: spontaneous, lightly chaotic, and allergic to solemn magic.",
            tags: ["student", "tidecrest", "serenity-brown", "joy", "friendship"]
        ),
        thread(
            "honorable-rivalry",
            "Honorable Rivalry",
            .seed,
            belief: 8,
            weight: 11,
            summary: "Finn Bridges brings pressure that can sharpen the reader without becoming Wicker's cruelty.",
            tags: ["student", "emberheart", "finn-bridges", "rival", "friction"]
        ),
        thread(
            "wickers-crew-organizes",
            "Wicker's Crew Organizes",
            .seed,
            belief: 8,
            weight: 12,
            summary: "Damien Nights and Melisande Blackwood make Wicker's faction feel coordinated, uncertain, and politically alive.",
            tags: ["student", "wicker-crew", "damien-nights", "melisande-blackwood", "faction", "doubt"]
        ),
        thread(
            "mossbloom-walks-gently",
            "Mossbloom Walks Gently",
            .seed,
            belief: 8,
            weight: 11,
            summary: "Lysander Mosswood and Min-seo Kim turn Mossbloom into trails, plant-care, social conscience, and quiet-life invitations.",
            tags: ["student", "mossbloom", "lysander-mosswood", "min-seo-kim", "compass-run", "care"]
        )
    ]

    private static let coreRelationships: [NarrativeRelationshipEdge] = [
        relationship(
            "book-authors-reader",
            source: "the-book",
            target: "ordinary-magic",
            kind: .authorship,
            warmth: 18,
            tension: 2,
            trust: 18,
            weight: 22,
            note: "The Book treats ordinary evidence as the reader's authorship, not as content to harvest.",
            tags: ["book", "belief", "ordinary", "daily"]
        ),
        relationship(
            "penny-files-book",
            source: "penny-blackletter",
            target: "the-book",
            kind: .stewardship,
            warmth: 16,
            tension: 4,
            trust: 14,
            weight: 16,
            note: "Penny keeps finding proof and trying to make it charming before it vanishes.",
            tags: ["marginalia", "photos", "letters", "book"]
        ),
        relationship(
            "inkrest-tends-body",
            source: "dr-inkrest",
            target: "body-page",
            kind: .care,
            warmth: 17,
            tension: 3,
            trust: 15,
            weight: 15,
            note: "Inkrest keeps hard pages seated near a lamp before asking them to speak.",
            tags: ["care", "body", "rest", "difficult-pages"]
        ),
        relationship(
            "inkrest-holds-difficult-pages",
            source: "dr-inkrest",
            target: "inkrest-difficult-pages",
            kind: .stewardship,
            warmth: 18,
            tension: 3,
            trust: 17,
            weight: 17,
            note: "Inkrest treats a hard feeling as a page, not a verdict.",
            tags: ["care", "difficult-pages", "therapy-chart", "grounding"]
        ),
        relationship(
            "vellum-tends-body-page",
            source: "dr-vellum",
            target: "body-page",
            kind: .care,
            warmth: 16,
            tension: 4,
            trust: 16,
            weight: 17,
            note: "Vellum turns body evidence into one small experiment with no shame attached.",
            tags: ["body", "health", "fuel", "vellum-chart", "care"]
        ),
        relationship(
            "vellum-runs-refectory-experiments",
            source: "dr-vellum",
            target: "elowen-refectory-experiments",
            kind: .stewardship,
            warmth: 15,
            tension: 5,
            trust: 15,
            weight: 15,
            note: "Vellum keeps experiments small enough that the reader can actually live with them.",
            tags: ["body", "fuel", "experiment", "vellum-chart"]
        ),
        relationship(
            "inkrest-vellum-compare-charts",
            source: "dr-inkrest",
            target: "dr-vellum",
            kind: .correspondence,
            warmth: 15,
            tension: 4,
            trust: 17,
            weight: 14,
            note: "Inkrest and Vellum compare charts only to make care more precise, never more intrusive.",
            tags: ["support-faculty", "care", "therapy-chart", "vellum-chart", "body"]
        ),
        relationship(
            "weather-bleeds-book",
            source: "weather-page",
            target: "the-book",
            kind: .realityBleed,
            warmth: 12,
            tension: 1,
            trust: 12,
            weight: 17,
            note: "Outer weather may tint the Book, but the source stays unnamed.",
            tags: ["weather", "bleed", "atmosphere", "book"]
        ),
        relationship(
            "body-negotiates-weather",
            source: "body-page",
            target: "weather-page",
            kind: .attention,
            warmth: 11,
            tension: 5,
            trust: 11,
            weight: 12,
            note: "Body and weather sometimes agree on gentleness before the reader does.",
            tags: ["body", "weather", "care", "bleed"]
        ),
        relationship(
            "thorne-tests-thresholds",
            source: "headmistress-thorne",
            target: "duskthorn-investigation",
            kind: .tension,
            warmth: 8,
            tension: 16,
            trust: 9,
            weight: 16,
            note: "Thorne lets thresholds test the reader, but never without leaving one lamp burning.",
            tags: ["duskthorn", "academy", "threshold", "secret"]
        ),
        relationship(
            "zara-guards-reader",
            source: "zara-finch",
            target: "ordinary-magic",
            kind: .companionship,
            warmth: 18,
            tension: 5,
            trust: 17,
            weight: 15,
            note: "Zara trusts ordinary proof more than dramatic declarations.",
            tags: ["trust", "friendship", "life", "ordinary"]
        ),
        relationship(
            "wicker-tests-belief",
            source: "wicker-eddies",
            target: "the-book",
            kind: .tension,
            warmth: 6,
            tension: 18,
            trust: 7,
            weight: 16,
            note: "Wicker attacks brittle belief so the real kind has to stand up.",
            tags: ["belief", "challenge", "tension", "nothing"]
        ),
        relationship(
            "serenity-keeps-tidecrest-light",
            source: "serenity-brown",
            target: "tidecrest-finds-its-laugh",
            kind: .companionship,
            warmth: 16,
            tension: 3,
            trust: 14,
            weight: 15,
            note: "Serenity keeps Tidecrest from becoming too solemn about its own beauty.",
            tags: ["student", "tidecrest", "joy", "sense", "class"]
        ),
        relationship(
            "serenity-brightens-euphonys-room",
            source: "serenity-brown",
            target: "professor-eleanor-euphony",
            kind: .attention,
            warmth: 14,
            tension: 4,
            trust: 13,
            weight: 12,
            note: "Euphony hears Serenity as the kind of laughter that changes a room's color.",
            tags: ["student", "tidecrest", "professor", "sound", "joy"]
        ),
        relationship(
            "finn-honors-the-rivalry",
            source: "finn-bridges",
            target: "honorable-rivalry",
            kind: .tension,
            warmth: 10,
            tension: 13,
            trust: 13,
            weight: 14,
            note: "Finn turns challenge into a clean line: prove it by moving, but do not cheapen the effort.",
            tags: ["student", "emberheart", "rival", "wayfinding", "friction"]
        ),
        relationship(
            "finn-tests-momorts-thresholds",
            source: "finn-bridges",
            target: "professor-kyle-momort",
            kind: .attention,
            warmth: 12,
            tension: 8,
            trust: 13,
            weight: 12,
            note: "Finn respects Momort's class most when it stops sounding like escape and starts becoming discipline.",
            tags: ["student", "emberheart", "professor", "wayfinding", "threshold"]
        ),
        relationship(
            "lysander-walks-stonebrook-routes",
            source: "lysander-mosswood",
            target: "mossbloom-walks-gently",
            kind: .attention,
            warmth: 16,
            tension: 2,
            trust: 16,
            weight: 14,
            note: "Lysander turns Stonebrook's quiet routes into nearby paths the reader can actually walk.",
            tags: ["student", "mossbloom", "trails", "compass-run", "gps"]
        ),
        relationship(
            "lysander-learns-stonebrook-rest",
            source: "lysander-mosswood",
            target: "professor-cedric-stonebrook",
            kind: .care,
            warmth: 15,
            tension: 2,
            trust: 15,
            weight: 12,
            note: "Lysander carries Stonebrook's rest-centered teaching out onto actual paths.",
            tags: ["student", "mossbloom", "professor", "trails", "rest"]
        ),
        relationship(
            "damien-hesitates-at-wickers-edge",
            source: "damien-nights",
            target: "wickers-crew-organizes",
            kind: .tension,
            warmth: 7,
            tension: 15,
            trust: 8,
            weight: 15,
            note: "Damien still stands near Wicker, but his attention keeps turning toward the reader.",
            tags: ["student", "wicker-crew", "shadow", "defection", "uncertainty"]
        ),
        relationship(
            "damien-watches-wicker",
            source: "damien-nights",
            target: "wicker-eddies",
            kind: .tension,
            warmth: 6,
            tension: 14,
            trust: 7,
            weight: 12,
            note: "Damien follows Wicker's tests while privately measuring what they cost.",
            tags: ["student", "wicker-crew", "wicker-eddies", "shadow", "doubt"]
        ),
        relationship(
            "melisande-organizes-wickers-crew",
            source: "melisande-blackwood",
            target: "wickers-crew-organizes",
            kind: .stewardship,
            warmth: 11,
            tension: 8,
            trust: 12,
            weight: 14,
            note: "Melisande gives Wicker's crew memory, leverage, and a terrifying filing system.",
            tags: ["student", "wicker-crew", "faction", "secrets", "pressure"]
        ),
        relationship(
            "melisande-serves-wickers-pressure",
            source: "melisande-blackwood",
            target: "wicker-eddies",
            kind: .stewardship,
            warmth: 12,
            tension: 7,
            trust: 12,
            weight: 12,
            note: "Melisande makes Wicker's cruelty look like strategy, which is exactly what makes her dangerous.",
            tags: ["student", "wicker-crew", "wicker-eddies", "strategy", "pressure"]
        ),
        relationship(
            "minseo-tends-mossbloom-conscience",
            source: "min-seo-kim",
            target: "mossbloom-walks-gently",
            kind: .care,
            warmth: 17,
            tension: 2,
            trust: 16,
            weight: 14,
            note: "Min-seo makes Mossbloom's gentleness social instead of merely scenic.",
            tags: ["student", "mossbloom", "care", "plants", "conscience"]
        ),
        relationship(
            "minseo-softens-stonebrooks-rest",
            source: "min-seo-kim",
            target: "professor-cedric-stonebrook",
            kind: .care,
            warmth: 15,
            tension: 1,
            trust: 15,
            weight: 12,
            note: "Min-seo reminds Stonebrook that rest is not complete unless everyone has been invited back into the circle.",
            tags: ["student", "mossbloom", "professor", "care", "rest"]
        ),
        relationship(
            "gwendolyn-files-letters",
            source: "gwendolyn-mythwright",
            target: "margin-glass-letters",
            kind: .authorship,
            warmth: 14,
            tension: 3,
            trust: 15,
            weight: 14,
            note: "Gwendolyn sends impossible research as if wonder were a library debt.",
            tags: ["letters", "research", "archive", "impossible"]
        ),
        relationship(
            "lydia-keeps-home-vessel",
            source: "lydia-boggle",
            target: "home-vessel",
            kind: .stewardship,
            warmth: 17,
            tension: 4,
            trust: 15,
            weight: 13,
            note: "Lydia believes the room has already started helping before anyone notices.",
            tags: ["home", "tea", "objects", "care"]
        ),
        relationship(
            "momort-opens-small-thresholds",
            source: "professor-kyle-momort",
            target: "ordinary-magic",
            kind: .attention,
            warmth: 14,
            tension: 6,
            trust: 13,
            weight: 14,
            note: "Momort turns one intentional step into a threshold the reader can actually cross.",
            tags: ["faculty", "class", "wayfinding", "embark", "ordinary"]
        ),
        relationship(
            "euphony-tunes-weather-rooms",
            source: "professor-eleanor-euphony",
            target: "weather-page",
            kind: .realityBleed,
            warmth: 15,
            tension: 2,
            trust: 14,
            weight: 13,
            note: "Euphony hears outer weather as room-tone before anyone names it.",
            tags: ["faculty", "class", "sense", "sound", "weather"]
        ),
        relationship(
            "villanelle-binds-true-sentences",
            source: "professor-vivian-villanelle",
            target: "margin-glass-letters",
            kind: .authorship,
            warmth: 16,
            tension: 3,
            trust: 15,
            weight: 14,
            note: "Villanelle teaches one true sentence to carry a whole moment without embalming it.",
            tags: ["faculty", "class", "writing", "souvenir", "memory"]
        ),
        relationship(
            "stonebrook-returns-compass-to-rest",
            source: "professor-cedric-stonebrook",
            target: "body-page",
            kind: .care,
            warmth: 18,
            tension: 2,
            trust: 17,
            weight: 15,
            note: "Stonebrook insists every Compass Run must return to a body that can keep going.",
            tags: ["faculty", "class", "rest", "compass-run", "body"]
        ),
        relationship(
            "wispwood-coaxes-object-replies",
            source: "professor-luna-wispwood",
            target: "ordinary-magic",
            kind: .attention,
            warmth: 17,
            tension: 3,
            trust: 14,
            weight: 14,
            note: "Wispwood treats ordinary things as willing collaborators once attention becomes courteous.",
            tags: ["faculty", "class", "enchantment", "objects", "ordinary"]
        ),
        relationship(
            "permancer-keeps-story-doors-safe",
            source: "professor-permancer",
            target: "the-book",
            kind: .stewardship,
            warmth: 13,
            tension: 7,
            trust: 16,
            weight: 15,
            note: "Permancer makes wonder wait for the landing protocol because every borrowed story deserves a careful return.",
            tags: ["faculty", "class", "book-jump", "threshold", "safety"]
        ),
        relationship(
            "soren-maps-thread",
            source: "soren-ng",
            target: "margin-glass-letters",
            kind: .attention,
            warmth: 10,
            tension: 5,
            trust: 14,
            weight: 13,
            note: "Soren leaves the map unfinished so the reader can become part of it.",
            tags: ["map", "pattern", "thread", "attention"]
        )
    ]

    /// The five Chapter talismans from the world register. Belief values
    /// carry over from Enchantify; the dominant one tones the whole Labyrinth.
    private static let coreTalismans: [NarrativeWorldEntity] = [
        entity(
            "dusk-thorn",
            "The Dusk Thorn",
            .talisman,
            belief: 11,
            weight: 22,
            chapter: "Duskthorn",
            traits: ["sharp", "patient", "honest about the dark"],
            quirks: ["draws blood only from stories that have gone numb"],
            faults: ["mistakes comfort for apathy"],
            beliefs: ["no conflict, no story"],
            goals: ["introduce the obstacle that makes the day worth telling"],
            tags: ["talisman", "chapter", "duskthorn", "conflict"]
        ),
        entity(
            "ember-seal",
            "The Ember Seal",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Emberheart",
            traits: ["warm", "insistent", "bright at the edges"],
            quirks: ["leaves faint scorch marks on hesitations"],
            faults: ["impatient with waiting"],
            beliefs: ["you are the author, the protagonist, and the pen"],
            goals: ["open doors the player could choose to walk through"],
            tags: ["talisman", "chapter", "emberheart", "self-authorship"]
        ),
        entity(
            "wind-cipher",
            "The Wind Cipher",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Riddlewind",
            traits: ["curious", "communal", "never finished"],
            quirks: ["rearranges itself when two people look at it together"],
            faults: ["restless when left alone"],
            beliefs: ["life is a story we write together"],
            goals: ["braid two voices into every important scene"],
            tags: ["talisman", "chapter", "riddlewind", "collaboration"]
        ),
        entity(
            "tide-glass",
            "The Tide Glass",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Tidecrest",
            traits: ["unpredictable", "present", "salt-bright"],
            quirks: ["shows a different hour every time it is consulted"],
            faults: ["forgets plans on purpose"],
            beliefs: ["the moment is complete in itself"],
            goals: ["inject one genuinely unplanned thing into the day"],
            tags: ["talisman", "chapter", "tidecrest", "spontaneity"]
        ),
        entity(
            "moss-clasp",
            "The Moss Clasp",
            .talisman,
            belief: 10,
            weight: 20,
            chapter: "Mossbloom",
            traits: ["quiet", "rooted", "older than its setting"],
            quirks: ["grows a new leaf when someone truly listens"],
            faults: ["slow to act even when action is kind"],
            beliefs: ["the larger story is already being written"],
            goals: ["make room for stillness and receptive attention"],
            tags: ["talisman", "chapter", "mossbloom", "receptivity"]
        )
    ]

    private static func entity(
        _ id: String,
        _ name: String,
        _ kind: NarrativeEntityKind,
        belief: Int,
        weight: Int,
        chapter: String? = nil,
        unwrittenInterest: String? = nil,
        traits: [String],
        quirks: [String],
        faults: [String],
        beliefs: [String],
        goals: [String],
        tags: [String]
    ) -> NarrativeWorldEntity {
        NarrativeWorldEntity(
            id: id,
            packID: corePackID,
            name: name,
            kind: kind,
            belief: belief,
            narrativeWeight: weight,
            chapter: chapter,
            unwrittenInterest: unwrittenInterest,
            traits: traits,
            quirks: quirks,
            faults: faults,
            beliefs: beliefs,
            goals: goals,
            tags: tags
        )
    }

    private static func thread(
        _ id: String,
        _ title: String,
        _ phase: StoryThreadPhase,
        belief: Int,
        weight: Int,
        summary: String,
        tags: [String]
    ) -> NarrativeStoryThread {
        NarrativeStoryThread(
            id: id,
            packID: corePackID,
            title: title,
            phase: phase,
            belief: belief,
            narrativeWeight: weight,
            summary: summary,
            tags: tags
        )
    }

    private static func relationship(
        _ id: String,
        source: String,
        target: String,
        kind: NarrativeRelationshipKind,
        warmth: Int,
        tension: Int,
        trust: Int,
        weight: Int,
        note: String,
        tags: [String]
    ) -> NarrativeRelationshipEdge {
        NarrativeRelationshipEdge(
            id: id,
            packID: corePackID,
            sourceEntityID: source,
            targetEntityID: target,
            kind: kind,
            warmth: warmth,
            tension: tension,
            trust: trust,
            narrativeWeight: weight,
            note: note,
            tags: tags
        )
    }
}

enum NarrativeEventResolver {
    static func events(forKept page: BookPage) -> [NarrativeEvent] {
        var events = [event(forKept: page)]
        guard page.type == .narrativeOS else {
            return events
        }

        let choices = storyChoiceSelections(in: page)
        events.append(contentsOf: choices.enumerated().map { offset, choice in
            event(forStoryChoice: choice, page: page, offset: offset)
        })
        return events
    }

    static func event(forKept page: BookPage) -> NarrativeEvent {
        if page.type == .gossip {
            return event(forGossipPage: page)
        }
        let tags = normalizedTags(for: page)
        let effect = effect(for: page.type, tags: tags)
        let summary = summary(for: page, effect: effect)
        return NarrativeEvent(
            id: "narrative-event-\(page.id)",
            kind: page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .pageKept : .pageAnswered,
            sourcePageType: page.type,
            sourcePageID: page.id,
            createdAt: page.createdAt,
            summary: summary,
            tags: Array(tags).sorted(),
            effect: effect
        )
    }

    private static func event(forGossipPage page: BookPage) -> NarrativeEvent {
        let tags = normalizedTags(for: page).union(["gossip", "simulation"])
        let actorIDs = page.tags
            .filter { $0.hasPrefix("actor:") }
            .map { $0.replacingOccurrences(of: "actor:", with: "") }
        let threadIDs = page.tags
            .filter { $0.hasPrefix("thread:") }
            .map { $0.replacingOccurrences(of: "thread:", with: "") }
        let actionKinds = page.tags
            .filter { $0.hasPrefix("action:") }
            .map { $0.replacingOccurrences(of: "action:", with: "") }
        let includesAttack = actionKinds.contains("attackBelief")

        var entityDeltas: [String: Int] = ["the-book": 1]
        var threadDeltas: [String: Int] = ["ordinary-magic": 1]
        let relationshipDeltas: [String: Int] = ["book-authors-reader": 1]

        for actorID in Set(actorIDs) {
            entityDeltas[actorID, default: 0] += includesAttack ? 1 : 2
        }
        for threadID in Set(threadIDs) {
            threadDeltas[threadID, default: 0] += includesAttack ? 1 : 2
        }

        let createdHint = includesAttack
            ? "A thread may return with tension where certainty used to sit."
            : "A small offscreen action can become a future callback."

        return NarrativeEvent(
            id: "narrative-gossip-\(page.id)",
            kind: .simulationTurn,
            sourcePageType: .gossip,
            sourcePageID: page.id,
            createdAt: page.createdAt,
            summary: page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "A Gossip Page was kept."
                : clippedSummary(page.userInput, maxLength: 180),
            tags: Array(tags).sorted(),
            effect: NarrativeEventEffect(
                beliefDelta: 1,
                entityWeightDeltas: entityDeltas,
                threadWeightDeltas: threadDeltas,
                relationshipWeightDeltas: relationshipDeltas,
                createdEntityHint: createdHint
            )
        )
    }

    private static func clippedSummary(_ text: String, maxLength: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    static func event(for choice: StorySceneChoice, packet: StoryScenePacket, at date: Date = Date()) -> NarrativeEvent {
        NarrativeEvent(
            id: "narrative-choice-\(packet.id)-\(choice.id)",
            kind: .choiceSelected,
            sourcePageType: .narrativeOS,
            sourcePageID: packet.id,
            createdAt: date,
            summary: "\(choice.role.title): \(choice.hiddenEffect)",
            tags: [choice.role.rawValue, packet.packID],
            effect: NarrativeEventEffect(
                beliefDelta: choice.beliefDelta,
                entityWeightDeltas: Dictionary(uniqueKeysWithValues: choice.targetEntityIDs.map { ($0, 1) }),
                threadWeightDeltas: Dictionary(uniqueKeysWithValues: choice.targetThreadIDs.map { ($0, 1) }),
                relationshipWeightDeltas: relationshipDeltas(for: choice, packet: packet),
                createdEntityHint: choice.role == .surprise ? "A related motif may step out of the margins." : nil
            )
        )
    }

    private static func event(forStoryChoice choice: StoryChoiceSelection, page: BookPage, offset: Int) -> NarrativeEvent {
        let effect = effect(forStoryChoice: choice, page: page)
        return NarrativeEvent(
            id: "narrative-choice-\(page.id)-\(offset + 1)-\(choice.id)",
            kind: .choiceSelected,
            sourcePageType: .narrativeOS,
            sourcePageID: page.id,
            createdAt: page.createdAt.addingTimeInterval(Double(offset + 1)),
            summary: "\(choice.title): \(choice.summary)",
            tags: Array(normalizedTags(for: page).union(["choice:\(choice.id)", choice.id])).sorted(),
            effect: effect
        )
    }

    private static func normalizedTags(for page: BookPage) -> Set<String> {
        var tags = Set(page.tags.map { $0.lowercased() })
        let searchable = "\(page.promptText) \(page.userInput)".lowercased()
        if searchable.contains("weather") || searchable.contains("sky") || searchable.contains("rain") || searchable.contains("sun") {
            tags.formUnion(["weather", "bleed", "atmosphere"])
        }
        if searchable.contains("body") || searchable.contains("tired") || searchable.contains("rest") || searchable.contains("fuel") {
            tags.formUnion(["body", "care", "rest"])
        }
        if searchable.contains("music") || searchable.contains("spotify") || searchable.contains("headphone") {
            tags.formUnion(["music", "shelter"])
        }
        if searchable.contains("photo") || page.type == .illuminatedPhoto {
            tags.formUnion(["photos", "marginalia"])
        }
        return tags
    }

    private struct StoryChoiceSelection {
        var id: String
        var title: String
        var summary: String
    }

    private static func storyChoiceSelections(in page: BookPage) -> [StoryChoiceSelection] {
        let searchable = page.userInput.lowercased()
        let selections: [(String, String, String)] = [
            ("sliceoflife", "Slice of Life", "The ordinary detail gained narrative weight."),
            ("progressarc", "Progress Arc", "The active thread moved one step forward."),
            ("surprise", "Something Surprising", "A related side door opened in the margins.")
        ]

        var found: [StoryChoiceSelection] = []
        for (id, title, summary) in selections {
            let tagCount = page.tags.filter { $0.lowercased() == "choice:\(id)" }.count
            let textCount = searchable.components(separatedBy: "chosen path: \(title.lowercased())").count - 1
            let count = max(tagCount, textCount)
            for _ in 0..<count {
                found.append(StoryChoiceSelection(id: id, title: title, summary: summary))
            }
        }

        return found
    }

    private static func effect(for type: BookPageType, tags: Set<String>) -> NarrativeEventEffect {
        var entityDeltas: [String: Int] = ["the-book": 1]
        var threadDeltas: [String: Int] = ["ordinary-magic": 1]
        var relationshipDeltas: [String: Int] = ["book-authors-reader": 1]
        var createdHint: String?

        switch type {
        case .weather:
            entityDeltas["weather-page", default: 0] += 2
            threadDeltas["weather-in-the-stacks", default: 0] += 2
            relationshipDeltas["weather-bleeds-book", default: 0] += 2
        case .body, .rest:
            entityDeltas["body-page", default: 0] += 2
            entityDeltas["dr-inkrest", default: 0] += 1
            threadDeltas["body-learns-trust", default: 0] += 2
            relationshipDeltas["inkrest-tends-body", default: 0] += 2
        case .fuel:
            entityDeltas["body-page", default: 0] += 2
            entityDeltas["dr-vellum", default: 0] += 2
            threadDeltas["body-learns-trust", default: 0] += 2
            relationshipDeltas["vellum-tends-body-page", default: 0] += 2
        case .supportGuild:
            entityDeltas["dr-vellum", default: 0] += 2
            entityDeltas["dr-inkrest", default: 0] += 2
            threadDeltas["elowen-refectory-experiments", default: 0] += 2
            threadDeltas["inkrest-difficult-pages", default: 0] += 2
            relationshipDeltas["inkrest-vellum-compare-charts", default: 0] += 3
        case .facultyResearch:
            if tags.contains("faculty:dr-vellum") {
                entityDeltas["dr-vellum", default: 0] += 2
                threadDeltas["elowen-refectory-experiments", default: 0] += 2
                relationshipDeltas["vellum-runs-refectory-experiments", default: 0] += 2
            }
            if tags.contains("faculty:dr-inkrest") {
                entityDeltas["dr-inkrest", default: 0] += 2
                threadDeltas["inkrest-difficult-pages", default: 0] += 2
                relationshipDeltas["inkrest-holds-difficult-pages", default: 0] += 2
            }
        case .letter:
            threadDeltas["margin-glass-letters", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A character letter can leave behind a researched callback."
        case .souvenir, .quip, .wonderCompass, .illustration:
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case .illuminatedPhoto:
            entityDeltas["penny-blackletter", default: 0] += 2
            relationshipDeltas["penny-files-book", default: 0] += 2
            createdHint = "A visible detail in the image can become a recurring talisman."
        case .enchantment:
            entityDeltas["penny-blackletter", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "The enchanted subject can speak, rhyme, puzzle, or return as future evidence."
        case .anchor:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["outer-stacks", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A checked-in Anchor can call back as a room, rule, or local threshold."
        case .aboutYou:
            entityDeltas["the-book", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
        case .narrativeOS, .bookFae:
            threadDeltas["ordinary-magic", default: 0] += 1
            // The scene's actual cast remembers what happened to them.
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty {
                    entityDeltas[entityID, default: 0] += 2
                }
            }
            for tag in tags where tag.hasPrefix("thread:") {
                let threadID = tag.replacingOccurrences(of: "thread:", with: "")
                if !threadID.isEmpty {
                    threadDeltas[threadID, default: 0] += 2
                }
            }
            if tags.contains("choice:sliceoflife") {
                entityDeltas["the-book", default: 0] += 2
                relationshipDeltas["book-authors-reader", default: 0] += 1
            }
            if tags.contains("choice:progressarc") {
                threadDeltas["ordinary-magic", default: 0] += 2
                relationshipDeltas["book-authors-reader", default: 0] += 1
            }
            if tags.contains("choice:surprise") {
                entityDeltas["penny-blackletter", default: 0] += 1
                threadDeltas["ordinary-magic", default: 0] += 1
                createdHint = "A surprising but related detail can become a future motif."
            }
        case .marginsAtlas:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case .bookConnections:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "A connection map can make future pages refer to the same cluster by name."
        case .bookRemembered:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A remembered page can return again when the day rhymes."
        case .bookNotices:
            entityDeltas["the-book", default: 0] += 3
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
            createdHint = "A noticed pattern can become a future letter, return, or constellation."
        case .theBleed:
            entityDeltas["penny-blackletter", default: 0] += 2
            entityDeltas["the-book", default: 0] += 1
            relationshipDeltas["penny-files-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A kept edition becomes part of the record Penny is attesting."
        case .gossip:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "An offscreen action can become a future callback."
        case .academyClass:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            for tag in tags {
                if tag.hasPrefix("entity:") {
                    let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                    if !entityID.isEmpty {
                        entityDeltas[entityID, default: 0] += 3
                    }
                } else if tag.hasPrefix("subject:") {
                    let subjectID = tag.replacingOccurrences(of: "subject:", with: "")
                    if !subjectID.isEmpty {
                        threadDeltas[subjectID, default: 0] += 3
                    }
                } else if tag.hasPrefix("class:") {
                    let classID = tag.replacingOccurrences(of: "class:", with: "")
                    if !classID.isEmpty {
                        threadDeltas[classID, default: 0] += 2
                    }
                } else if tag.hasPrefix("lesson:") {
                    let lessonID = tag.replacingOccurrences(of: "lesson:", with: "")
                    if !lessonID.isEmpty {
                        threadDeltas[lessonID, default: 0] += 2
                    }
                }
            }
            createdHint = "A lesson can return later as a practice, a pun, or a pop quiz."
        case .elective:
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty {
                    entityDeltas[entityID, default: 0] += 2
                }
            }
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A completed favor deepens what its asker will trust the player with next."
        case .castMember:
            if let entityID = tags.first(where: { $0.hasPrefix("entity:") })?.replacingOccurrences(of: "entity:", with: "") {
                entityDeltas[entityID, default: 0] += 3
            }
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case .mood:
            entityDeltas["body-page", default: 0] += tags.contains("weather") ? 0 : 1
            threadDeltas["body-learns-trust", default: 0] += 1
        case .diary:
            entityDeltas["the-book", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A present-tense diary note can become quiet continuity."
        case .askTheBook:
            entityDeltas["the-book", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 2
        case .inkrestOfficeHours:
            entityDeltas["dr-inkrest", default: 0] += 3
            threadDeltas["inkrest-difficult-pages", default: 0] += 2
            relationshipDeltas["inkrest-holds-difficult-pages", default: 0] += 2
            createdHint = "A kept Office Hours sitting can return as a reframe, an experiment, or a question for real therapy."
        case .faeBargain:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["outer-stacks", default: 0] += 2
            createdHint = "A paid bargain deepens the reader's standing with the Fae and may open stranger bargains later."
        case .pactDispatch:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A kept dispatch marks a turn in the Talismans' long war over the reader's margins."
        case .festival:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A kept festival ties the reader's year to the turning Wheel; the season can call it back."
        case .twoReadings:
            // Both characters who argued deepen by being heard.
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty { entityDeltas[entityID, default: 0] += 2 }
            }
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "A kept disagreement lets two voices keep arguing across letters and gossip."
        case .castBond:
            for tag in tags where tag.hasPrefix("entity:") {
                let entityID = tag.replacingOccurrences(of: "entity:", with: "")
                if !entityID.isEmpty { entityDeltas[entityID, default: 0] += 2 }
            }
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A living relationship milestone can echo as future gossip, letters, or story scenes."
        case .todaysSky:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A kept sky reading ties the reader to the turning overhead; the next phase or shower can call it back."
        case .radio:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["music-as-shelter", default: 0] += 3
            threadDeltas["ordinary-magic", default: 0] += 1
            relationshipDeltas["book-authors-reader", default: 0] += 1
            createdHint = "A kept radio page can make the active station tint future pages, letters, and weather in the stacks."
        case .bookJump:
            entityDeltas["the-book", default: 0] += 2
            threadDeltas["ordinary-magic", default: 0] += 2
            threadDeltas["book-jumping", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 2
            if tags.contains("book-jump:return") {
                createdHint = "A returned Book Jump can echo later as a borrowed rule, a character letter, or a constellation with the source book."
            } else {
                createdHint = "An open Book Jump can call back until the reader finds the Spine."
            }
        case .inventory:
            entityDeltas["the-book", default: 0] += 1
            threadDeltas["ordinary-magic", default: 0] += 1
            createdHint = "An invoked or bound object can alter which Pages return and what the Book remembers."
        case .location, .lore, .patreon, .bookOfYou, .packPage, .calendar, .helpTips, .welcome:
            break
        }

        if tags.contains("music") {
            threadDeltas["music-as-shelter", default: 0] += 2
        }
        if tags.contains("weather") {
            entityDeltas["weather-page", default: 0] += 1
            threadDeltas["weather-in-the-stacks", default: 0] += 1
        }
        if tags.contains("body") || tags.contains("rest") || tags.contains("care") {
            entityDeltas["body-page", default: 0] += 1
            threadDeltas["body-learns-trust", default: 0] += 1
        }
        if tags.contains("story-mechanic") {
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        }
        if tags.contains("story-mechanic:compass-run") {
            threadDeltas["ordinary-magic", default: 0] += 2
        }
        if tags.contains("story-mechanic:enchantment") {
            entityDeltas["the-book", default: 0] += 1
            createdHint = createdHint ?? "A completed Enchantment can become future evidence."
        }

        return NarrativeEventEffect(
            beliefDelta: 1,
            entityWeightDeltas: entityDeltas,
            threadWeightDeltas: threadDeltas,
            relationshipWeightDeltas: relationshipDeltas,
            createdEntityHint: createdHint
        )
    }

    private static func effect(forStoryChoice choice: StoryChoiceSelection, page: BookPage) -> NarrativeEventEffect {
        var entityDeltas: [String: Int] = ["the-book": 1]
        var threadDeltas: [String: Int] = ["ordinary-magic": 1]
        var relationshipDeltas: [String: Int] = ["book-authors-reader": 1]
        var createdHint: String?

        switch choice.id {
        case "sliceoflife":
            entityDeltas["the-book", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case "progressarc":
            threadDeltas["ordinary-magic", default: 0] += 3
            relationshipDeltas["book-authors-reader", default: 0] += 1
        case "surprise":
            entityDeltas["penny-blackletter", default: 0] += 1
            threadDeltas["margin-glass-letters", default: 0] += 1
            createdHint = "A surprising but related detail can become a future motif."
        default:
            break
        }

        let tags = normalizedTags(for: page)
        if tags.contains("music") {
            threadDeltas["music-as-shelter", default: 0] += 1
        }
        if tags.contains("weather") {
            entityDeltas["weather-page", default: 0] += 1
            threadDeltas["weather-in-the-stacks", default: 0] += 1
        }
        if tags.contains("body") || tags.contains("rest") || tags.contains("care") {
            entityDeltas["body-page", default: 0] += 1
            threadDeltas["body-learns-trust", default: 0] += 1
        }
        if tags.contains("letters") || tags.contains("research") {
            threadDeltas["margin-glass-letters", default: 0] += 1
            relationshipDeltas["gwendolyn-files-letters", default: 0] += 1
        }
        if tags.contains("story-mechanic") {
            threadDeltas["ordinary-magic", default: 0] += 2
            relationshipDeltas["book-authors-reader", default: 0] += 1
        }
        if tags.contains("story-mechanic:compass-run") {
            threadDeltas["ordinary-magic", default: 0] += 2
        }
        if tags.contains("story-mechanic:enchantment") {
            entityDeltas["the-book", default: 0] += 1
            createdHint = createdHint ?? "A completed Enchantment can become future evidence."
        }

        return NarrativeEventEffect(
            beliefDelta: 1,
            entityWeightDeltas: entityDeltas,
            threadWeightDeltas: threadDeltas,
            relationshipWeightDeltas: relationshipDeltas,
            createdEntityHint: createdHint
        )
    }

    private static func relationshipDeltas(for choice: StorySceneChoice, packet: StoryScenePacket) -> [String: Int] {
        var deltas: [String: Int] = [:]
        let targets = Set(choice.targetEntityIDs + choice.targetThreadIDs)
        for relationship in packet.selectedRelationships where targets.contains(relationship.sourceEntityID) || targets.contains(relationship.targetEntityID) {
            deltas[relationship.id, default: 0] += 1
        }
        if deltas.isEmpty, let first = packet.selectedRelationships.first {
            deltas[first.id] = 1
        }
        return deltas
    }

    private static func summary(for page: BookPage, effect: NarrativeEventEffect) -> String {
        // Story pages carry what actually happened — keep that in the event
        // summary so entity memories can recall the scene itself, not just
        // "a page was kept."
        if page.type == .narrativeOS {
            let sceneText = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sceneText.isEmpty {
                return clippedSummary(sceneText, maxLength: 220)
            }
        }
        let pageName = page.type.title
        let threadNames = effect.threadWeightDeltas.keys.sorted().joined(separator: ", ")
        guard !threadNames.isEmpty else {
            return "\(pageName) became a kept artifact in the Book."
        }
        return "\(pageName) became a kept artifact and tugged \(threadNames)."
    }
}

struct NarrativeSourceSnapshot: Equatable {
    var activeThreadCount: Int
    var relationshipCount: Int
    var beliefWeight: Int?
    var recentEventCount: Int = 0
    var recentTags: [String] = []
    var weightedEntityIDs: [String] = []
    var weightedThreadIDs: [String] = []
    var weightedRelationshipIDs: [String] = []
    var entityMemories: [NarrativeEntityMemory] = []

    var isAvailable: Bool {
        activeThreadCount > 0
            || relationshipCount > 0
            || beliefWeight != nil
            || recentEventCount > 0
            || !recentTags.isEmpty
            || !weightedEntityIDs.isEmpty
            || !weightedThreadIDs.isEmpty
            || !weightedRelationshipIDs.isEmpty
            || !entityMemories.isEmpty
    }
}

enum NarrativeSourceSnapshotBuilder {
    static func snapshot(
        from events: [NarrativeEvent],
        memories: [NarrativeEntityMemory] = [],
        beliefWeight: Int?
    ) -> NarrativeSourceSnapshot {
        let recentEvents = Array(events.prefix(24))
        let projection = NarrativeStoryFieldProjector.projection(events: recentEvents, baseBelief: beliefWeight ?? 30)
        let entityIDs = projection.topEntityIDs
        let threadIDs = projection.topThreadIDs
        let relationshipIDs = projection.topRelationshipIDs
        let tags = Array(Set(recentEvents.flatMap(\.tags))).sorted()
        let selectedMemories = memories
            .filter { entityIDs.contains($0.entityID) }
            .sorted { left, right in
                if left.narrativeWeight == right.narrativeWeight {
                    return left.createdAt > right.createdAt
                }
                return left.narrativeWeight > right.narrativeWeight
            }
            .prefix(12)
            .map(\.self)

        return NarrativeSourceSnapshot(
            activeThreadCount: threadIDs.count,
            relationshipCount: relationshipIDs.count,
            beliefWeight: projection.belief,
            recentEventCount: recentEvents.count,
            recentTags: tags,
            weightedEntityIDs: entityIDs,
            weightedThreadIDs: threadIDs,
            weightedRelationshipIDs: relationshipIDs,
            entityMemories: selectedMemories
        )
    }
}

/// Merges near-duplicate memories per entity so two weeks of "you mentioned
/// the harbor" becomes one strong memory instead of six weak ones crowding
/// the recall cap. Pure; applied to the in-memory list at load, never to
/// the stored archive.
enum NarrativeEntityMemoryConsolidator {
    static func consolidate(_ memories: [NarrativeEntityMemory], weightCap: Int = 12) -> [NarrativeEntityMemory] {
        var byKey: [String: NarrativeEntityMemory] = [:]
        var order: [String] = []
        for memory in memories.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = "\(memory.entityID)|\(signature(of: memory.summary))"
            if var existing = byKey[key] {
                existing.narrativeWeight = min(weightCap, existing.narrativeWeight + max(1, memory.narrativeWeight / 2))
                existing.summary = memory.summary
                existing.createdAt = memory.createdAt
                byKey[key] = existing
            } else {
                byKey[key] = memory
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }.sorted { $0.createdAt > $1.createdAt }
    }

    private static func signature(of summary: String) -> String {
        let stopWords: Set<String> = [
            "the", "and", "that", "this", "with", "from", "through", "remembers",
            "remember", "reader", "gave", "took", "page", "kept", "their", "your",
            "about", "into", "again", "menu", "glow", "belief"
        ]
        let words = summary
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count > 3 && !stopWords.contains($0) }
        return Array(Set(words)).sorted().prefix(6).joined(separator: "-")
    }
}

// MARK: - The Nothing
//
// The Labyrinth's antagonist: not a monster but a tide — apathy, the Rut,
// the grey that takes unnoticed days. Doctrine, in order of importance:
// 1. Under distress it does not exist. The Book is kind before it is interesting.
// 2. It never guilts and never punishes. It makes STORY, not shame.
// 3. It is never defeated, only understood — and held back by keeping pages.
enum NothingTide {
    /// 0 = quiet (pages are being kept; the grey stays in the deep stacks),
    /// 1 = at the edges, 2 = in the margins, 3 = at the desk.
    static func greyLevel(
        quietDays: Int,
        narrativeHeat: Int,
        distressActive: Bool,
        celebrationGreyShift: Int = 0
    ) -> Int {
        if distressActive {
            return 0
        }
        var level: Int
        switch quietDays {
        case ..<1: level = 0
        case 1: level = 1
        case 2...3: level = 2
        default: level = 3
        }
        // A hot story field pushes the grey back a step.
        if narrativeHeat >= 6, level > 0 {
            level -= 1
        }
        // The Almanac bends the Nothing: light feasts (full moon, Litha) push it
        // back; thinning-veil nights (Samhain, new moon) let it nearer.
        level += celebrationGreyShift
        return max(0, min(3, level))
    }

    /// Consecutive days before today with no kept pages.
    static func quietDays(in days: [BookDay], today todayID: String, calendar: Calendar = .current, now: Date = Date()) -> Int {
        var quiet = 0
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { break }
            let dayID = BookDay.id(for: calendar.startOfDay(for: date), calendar: calendar)
            if let day = days.first(where: { $0.id == dayID }), !day.capturedPages.isEmpty {
                break
            }
            quiet += 1
        }
        return quiet
    }

    /// The story-page directive when the grey is up.
    static func storySignal(forGreyLevel level: Int) -> String? {
        switch level {
        case 2:
            return "The Nothing has been at the edges of these margins: somewhere in the scene, one ordinary detail has gone faintly grey and silent. Let a character notice it and quietly resist — by naming it precisely, out loud. The Nothing is never fought and never defeated; it is noticed back."
        case 3:
            return "The Nothing has reached the desk: in this scene, something small has already been erased — a name, a label, a familiar object's color — and the cast can feel the gap. Let them work around the missing thing with care, and let one character say what the cure is without preaching: attention. Keep it gentle; the grey is weather, not war."
        default:
            return nil
        }
    }

    /// The line the Book says when a page is kept while the grey is up.
    static func returnLine(forGreyLevel level: Int) -> String? {
        switch level {
        case 1:
            return "Something grey at the edge of the desk loses interest and withdraws. The page holds."
        case 2, 3:
            return "The grey had settled into the margins; this page pushes it back a full shelf. The Book breathes easier."
        default:
            return nil
        }
    }
}

// MARK: - The Margins Atlas
//
// Graph pages: The Loom (relationships between the cast) and The
// Constellation (where Belief lives and where the reader's attention has
// flowed). Layout is deterministic — the same world draws the same map.

struct GraphNode: Identifiable, Equatable {
    var id: String
    var label: String
    var weight: Double        // node size driver: belief / narrative weight
    var chapterID: String?    // colors the node
    var kindLabel: String
}

struct GraphEdge: Identifiable, Equatable {
    var id: String
    var sourceID: String
    var targetID: String
    var strength: Double      // 0...1, thickness
    var warmth: Double        // -1 (tension) ... +1 (warm) — colors the thread
    var label: String
}

struct NarrativeGraphData: Equatable {
    var nodes: [GraphNode]
    var edges: [GraphEdge]

    static let empty = NarrativeGraphData(nodes: [], edges: [])

    /// Order-independent key for a pair of entities.
    static func relationshipPairKey(_ a: String, _ b: String) -> String {
        "\(min(a, b))|\(max(a, b))"
    }

    /// The Loom: cast and the living threads between them. Authored base edges are
    /// layered with the dynamic `relationshipField` — accumulated warmth, tension,
    /// and familiarity that grow from what actually happens in the reader's Book
    /// (shared story scenes and gossip warm a pair; siding in a disagreement
    /// tenses it; co-occurrence makes strangers familiar). New threads emerge as
    /// pairs interact, so the web is a simulation, not a fixed diagram.
    static func loom(
        entities: [NarrativeWorldEntity],
        relationships: [NarrativeRelationshipEdge],
        threads: [NarrativeStoryThread] = [],
        beliefOffsets: [String: Int],
        relationshipField: [String: RelationshipTie] = [:]
    ) -> NarrativeGraphData {
        var connectedIDs = Set(relationships.flatMap { [$0.sourceEntityID, $0.targetEntityID] })
        // Pull in anyone the field now connects, even with no authored edge.
        for key in relationshipField.keys {
            for id in key.split(separator: "|").map(String.init) { connectedIDs.insert(id) }
        }
        let entityNodes = entities
            .filter { connectedIDs.contains($0.id) }
            .map { entity in
                GraphNode(
                    id: entity.id,
                    label: entity.name,
                    weight: Double(max(6, entity.belief + (beliefOffsets[entity.id] ?? 0))),
                    chapterID: AcademyChapterRegistry.chapter(named: entity.chapter)?.id,
                    kindLabel: entity.kind.rawValue
                )
            }
        let entityNodeIDs = Set(entityNodes.map(\.id))
        let threadNodes = threads
            .filter { !entityNodeIDs.contains($0.id) }
            .map { thread in
                GraphNode(
                    id: thread.id,
                    label: thread.title,
                    weight: Double(max(6, thread.belief + (beliefOffsets[thread.id] ?? 0))),
                    chapterID: nil,
                    kindLabel: "thread"
                )
            }
        let nodes = entityNodes + threadNodes
        let nodeIDs = Set(nodes.map(\.id))
        var edges = relationships
            .filter { nodeIDs.contains($0.sourceEntityID) && nodeIDs.contains($0.targetEntityID) }
            .map { edge -> GraphEdge in
                let tie = relationshipField[relationshipPairKey(edge.sourceEntityID, edge.targetEntityID)] ?? .zero
                let tone = Double(edge.warmth + edge.trust + tie.warmth - edge.tension - tie.tension)
                return GraphEdge(
                    id: edge.id,
                    sourceID: edge.sourceEntityID,
                    targetID: edge.targetEntityID,
                    strength: min(1, max(0.15, Double(edge.narrativeWeight + tie.familiarity + tie.tension) / 30)),
                    warmth: min(1, max(-1, tone / 30)),
                    label: tie.tension > tie.warmth && tie.tension > 0 ? "disputed" : edge.kind.rawValue
                )
            }

        // Threads that emerged purely from the field, between pairs the authored
        // graph never connected.
        let existingPairs = Set(relationships.map { relationshipPairKey($0.sourceEntityID, $0.targetEntityID) })
        for (pairKey, tie) in relationshipField where !existingPairs.contains(pairKey) {
            guard tie.familiarity >= 2 || tie.tension > 0 || tie.warmth >= 2 else { continue }
            let parts = pairKey.split(separator: "|").map(String.init)
            guard parts.count == 2, nodeIDs.contains(parts[0]), nodeIDs.contains(parts[1]) else { continue }
            let tone = Double(tie.warmth - tie.tension)
            edges.append(GraphEdge(
                id: "field-\(pairKey)",
                sourceID: parts[0],
                targetID: parts[1],
                strength: min(1, max(0.2, Double(tie.familiarity + tie.tension + tie.warmth) / 14)),
                warmth: min(1, max(-1, tone / 10)),
                label: tie.tension > tie.warmth ? "disputed" : "woven"
            ))
        }
        return NarrativeGraphData(nodes: nodes, edges: edges)
    }

    /// The Constellation: Belief as stars, the reader at the center, edges
    /// tracing where their attention has actually flowed (from the event
    /// ledger — investments brighten the thread, attacks darken it).
    static func constellation(
        entities: [NarrativeWorldEntity],
        beliefOffsets: [String: Int],
        events: [NarrativeEvent],
        playerBelief: Int
    ) -> NarrativeGraphData {
        var flows: [String: (moved: Int, tone: Int)] = [:]
        for event in events {
            guard event.kind == .beliefInvested || event.kind == .beliefAttacked else { continue }
            for (entityID, delta) in event.effect.entityWeightDeltas where delta != 0 {
                var flow = flows[entityID] ?? (0, 0)
                flow.moved += abs(delta)
                flow.tone += event.kind == .beliefInvested ? delta : -abs(delta)
                flows[entityID] = flow
            }
        }

        let reader = GraphNode(
            id: "the-reader",
            label: "You",
            weight: Double(max(10, playerBelief)),
            chapterID: nil,
            kindLabel: "reader"
        )
        // Stars: anything with meaningful belief, plus anything you've touched.
        let starEntities = entities.filter { entity in
            let adjusted = entity.belief + (beliefOffsets[entity.id] ?? 0)
            return adjusted >= 18 || flows[entity.id] != nil
        }
        let nodes = [reader] + starEntities.map { entity in
            GraphNode(
                id: entity.id,
                label: entity.name,
                weight: Double(max(6, entity.belief + (beliefOffsets[entity.id] ?? 0))),
                chapterID: AcademyChapterRegistry.chapter(named: entity.chapter)?.id,
                kindLabel: entity.kind.rawValue
            )
        }
        let nodeIDs = Set(nodes.map(\.id))
        let edges = flows.compactMap { entityID, flow -> GraphEdge? in
            guard nodeIDs.contains(entityID) else { return nil }
            return GraphEdge(
                id: "flow-\(entityID)",
                sourceID: "the-reader",
                targetID: entityID,
                strength: min(1, max(0.2, Double(flow.moved) / 12)),
                warmth: min(1, max(-1, Double(flow.tone) / Double(max(1, flow.moved)))),
                label: flow.tone >= 0 ? "belief given" : "belief taken"
            )
        }
        return NarrativeGraphData(nodes: nodes, edges: edges)
    }
}

/// Deterministic Fruchterman-Reingold: seeded initial ring, fixed iteration
/// count, no randomness at draw time. Same data, same map, every open.
enum GraphLayoutEngine {
    static func layout(
        data: NarrativeGraphData,
        width: Double,
        height: Double,
        iterations: Int = 120,
        seed: String = "margins-atlas"
    ) -> [String: CodablePoint] {
        let nodes = data.nodes
        guard !nodes.isEmpty else { return [:] }
        let area = width * height
        let k = (area / Double(nodes.count)).squareRoot() * 0.7

        // Seeded ring start: stable hash decides each node's angle jitter.
        var x: [String: Double] = [:]
        var y: [String: Double] = [:]
        for (index, node) in nodes.enumerated() {
            let jitter = Double(abs("\(seed)-\(node.id)".stableHash % 1000)) / 1000.0
            let angle = (Double(index) + jitter) / Double(nodes.count) * 2 * Double.pi
            let radius = min(width, height) * 0.34 * (0.7 + 0.3 * jitter)
            x[node.id] = width / 2 + radius * cos(angle)
            y[node.id] = height / 2 + radius * sin(angle)
        }

        let adjacency: [(String, String, Double)] = data.edges.map { ($0.sourceID, $0.targetID, $0.strength) }
        var temperature = min(width, height) / 8

        for _ in 0..<iterations {
            var dx: [String: Double] = [:]
            var dy: [String: Double] = [:]
            // Repulsion between every pair.
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let a = nodes[i].id
                    let b = nodes[j].id
                    var deltaX = (x[a] ?? 0) - (x[b] ?? 0)
                    var deltaY = (y[a] ?? 0) - (y[b] ?? 0)
                    var distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
                    if distance < 0.01 {
                        deltaX = 0.01 * (abs("\(a)-\(b)".stableHash % 2) == 0 ? 1 : -1)
                        deltaY = 0.01
                        distance = 0.014
                    }
                    let force = k * k / distance
                    dx[a, default: 0] += deltaX / distance * force
                    dy[a, default: 0] += deltaY / distance * force
                    dx[b, default: 0] -= deltaX / distance * force
                    dy[b, default: 0] -= deltaY / distance * force
                }
            }
            // Attraction along edges, weighted by strength.
            for (source, target, strength) in adjacency {
                let deltaX = (x[source] ?? 0) - (x[target] ?? 0)
                let deltaY = (y[source] ?? 0) - (y[target] ?? 0)
                let distance = max(0.01, (deltaX * deltaX + deltaY * deltaY).squareRoot())
                let force = distance * distance / k * (0.5 + strength)
                dx[source, default: 0] -= deltaX / distance * force
                dy[source, default: 0] -= deltaY / distance * force
                dx[target, default: 0] += deltaX / distance * force
                dy[target, default: 0] += deltaY / distance * force
            }
            // Apply, clamped by cooling temperature and the frame.
            for node in nodes {
                let moveX = dx[node.id] ?? 0
                let moveY = dy[node.id] ?? 0
                let magnitude = max(0.01, (moveX * moveX + moveY * moveY).squareRoot())
                let limited = min(magnitude, temperature)
                x[node.id] = min(width - 40, max(40, (x[node.id] ?? 0) + moveX / magnitude * limited))
                y[node.id] = min(height - 40, max(40, (y[node.id] ?? 0) + moveY / magnitude * limited))
            }
            temperature *= 0.95
        }

        var result: [String: CodablePoint] = [:]
        for node in nodes {
            result[node.id] = CodablePoint(x: x[node.id] ?? width / 2, y: y[node.id] ?? height / 2)
        }
        return result
    }
}

// MARK: - The Two Readings (dynamic character disagreement)
//
// Two members of the cast read the same recent evidence differently and reach
// different conclusions, then leave it to the reader. The pair is chosen
// DYNAMICALLY from the cast — by any tension between them, contrast of Chapter
// and domain, how well each fits the current evidence, Belief weight, and
// rotation — never from a hardcoded table. The disagreement itself emerges from
// each character's own beliefs, faults, and voice in the generated prose.

struct DisagreementPair: Equatable {
    let aID: String
    let bID: String
    let aName: String
    let bName: String
    let relationshipNote: String?
    var pairKey: String { "\(min(aID, bID))-\(max(aID, bID))" }
}

enum DisagreementEngine {
    /// Characters with enough internal shape to actually hold a position.
    static func eligible(from entities: [NarrativeWorldEntity]) -> [NarrativeWorldEntity] {
        entities.filter { $0.kind == .character && (!$0.beliefs.isEmpty || !$0.faults.isEmpty) }
    }

    private static func tension(
        _ a: NarrativeWorldEntity, _ b: NarrativeWorldEntity,
        _ relationships: [NarrativeRelationshipEdge]
    ) -> (value: Int, note: String?) {
        let edge = relationships.first {
            ($0.sourceEntityID == a.id && $0.targetEntityID == b.id) ||
            ($0.sourceEntityID == b.id && $0.targetEntityID == a.id)
        }
        return (edge?.tension ?? 0, edge?.note)
    }

    private static func chapterContrast(_ a: NarrativeWorldEntity, _ b: NarrativeWorldEntity) -> Int {
        switch (a.chapter, b.chapter) {
        case let (ca?, cb?): return ca == cb ? 0 : 3   // named, different Chapters argue hardest
        case (nil, nil): return 1
        default: return 2                               // one aligned, one free
        }
    }

    private static func evidenceFit(_ entity: NarrativeWorldEntity, _ haystack: String) -> Int {
        entity.tags.reduce(0) { $0 + (haystack.contains($1.lowercased()) ? 1 : 0) }
    }

    /// Pick the most interesting disagreeing pair for the current evidence.
    static func select(
        entities: [NarrativeWorldEntity],
        relationships: [NarrativeRelationshipEdge],
        evidenceText: String,
        surfaceHistory: [String: SurfaceHistoryRecord] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DisagreementPair? {
        // Cap the pool to the most present voices so the pairing stays vivid.
        let pool = Array(eligible(from: entities).sorted { $0.belief > $1.belief }.prefix(9))
        guard pool.count >= 2 else { return nil }
        let haystack = evidenceText.lowercased()
        let slot = "\(calendar.dateComponents([.year, .month, .day], from: now).day ?? 0)"

        var best: (pair: DisagreementPair, score: Int)?
        for i in pool.indices {
            for j in pool.indices where j > i {
                let a = pool[i]
                let b = pool[j]
                let (tensionValue, note) = tension(a, b, relationships)
                let fit = evidenceFit(a, haystack) + evidenceFit(b, haystack)
                let contrast = chapterContrast(a, b)
                let beliefPresence = (a.belief + b.belief) / 30
                let key = "tworeadings:\(min(a.id, b.id))-\(max(a.id, b.id))"
                let seenRecently = surfaceHistory[key]
                    .map { now.timeIntervalSince($0.lastShownAt) < 3 * 86_400 } ?? false
                let jitter = abs("\(a.id)-\(b.id)-\(slot)".stableHash) % 4
                let score = tensionValue / 3 + contrast * 2 + fit * 3 + beliefPresence + jitter - (seenRecently ? 7 : 0)

                if best == nil || score > best!.score {
                    best = (
                        DisagreementPair(aID: a.id, bID: b.id, aName: a.name, bName: b.name, relationshipNote: note),
                        score
                    )
                }
            }
        }
        return best?.pair
    }
}
