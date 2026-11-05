import Foundation

/// Why a character will not say what they know.
///
/// This is the mechanic that turns an authored fault into an epistemic one: a
/// character's flaw decides what they will testify to, not just how they behave.
/// Trencher will not answer while anybody is thanking him.
enum ContestedSilenceReason: String, Codable, Equatable {
    case none
    case faultPreventsIt
    case notTheirBusiness
    case wouldHaveToAdmitSomething
}

/// One character's position on a disputed event.
struct ContestedPosition: Codable, Equatable, Identifiable {
    var id: String
    var holderID: String
    var holderName: String
    var claim: String
    /// What they are reasoning from. Never invented: it points at real ledger
    /// movements or place incidents.
    var groundedInIDs: [String]
    var confidence: Int
    var silence: ContestedSilenceReason
    var formedAt: Date

    /// A character who is holding out is still a participant: the shape of
    /// their refusal is information.
    var isSpeaking: Bool { silence == .none }
}

enum ContestedQuestionStatus: String, Codable, Equatable {
    case open
    /// Evidence arrived that favours one position. The question does not close;
    /// the Academy simply has a most-embarrassed party.
    case complicated
    case restingUnresolved
}

/// A disputed event several characters read differently, and about which the
/// Book itself may be wrong.
///
/// This is the multi-party generalisation of the pairwise `DisagreementEngine`.
/// The point is not a debate minigame: it is that the relationship field becomes
/// a *culture of interpretation* rather than only a network of fondness and
/// friction. The Book holds a provisional opinion, and later physical evidence
/// is allowed to embarrass it.
struct ContestedQuestion: Codable, Equatable, Identifiable {
    /// 2: readings come from each person's own lens and name the topic.
    static let currentVersion = 2
    static let minimumPositions = 3
    static let maximumPositions = 5
    /// One live argument at a time. A society with four simultaneous scandals is
    /// a soap opera.
    static let maximumOpen = 1

    var version: Int = currentVersion
    var id: String
    var question: String
    var aboutMovementIDs: [String]
    var placeID: String?
    var positions: [ContestedPosition]
    /// The Book's own reading. It is a participant here, not the referee.
    var bookPosition: String
    var bookBackedHolderID: String?
    var status: ContestedQuestionStatus
    var openedAt: Date
    var lastMovedAt: Date
    /// Set when physical evidence contradicted whoever the Book backed. This is
    /// what becomes a `BookFaultEpisode`.
    var embarrassedHolderID: String?
    var contradictingEvidence: String?

    var speakingPositions: [ContestedPosition] { positions.filter(\.isSpeaking) }
    var isLive: Bool { status == .open || status == .complicated }
}

enum ContestedQuestionEngine {
    /// A question needs a real event and enough people with enough shape to
    /// disagree about it.
    static func opening(
        movements: [CastAgencyMovement],
        undertakings: [CastUndertaking],
        places: [String: PlaceState],
        entities: [NarrativeWorldEntity],
        existing: [ContestedQuestion],
        now: Date
    ) -> ContestedQuestion? {
        guard existing.filter(\.isLive).count < ContestedQuestion.maximumOpen else { return nil }
        // Ground it in an undertaking that is actually underway: the Academy
        // argues about its own business, not about abstractions.
        let running = undertakings.filter { $0.isRunning && $0.currentStage != nil }
            .sorted { $0.id < $1.id }
        guard let subject = running.first(where: { undertaking in
            !existing.contains { $0.id.contains(undertaking.actorID) && $0.isLive }
        }) ?? running.first else { return nil }
        guard let stage = subject.currentStage else { return nil }

        let holders = DisagreementEngine.eligible(from: entities)
            .filter { $0.id != subject.actorID }
            .sorted { $0.id < $1.id }
        guard holders.count >= ContestedQuestion.minimumPositions - 1 else { return nil }

        let seed = "\(subject.id)|\(subject.stageIndex)|contested"
        let count = min(
            ContestedQuestion.maximumPositions,
            ContestedQuestion.minimumPositions + abs("\(seed)|count".stableHash) % 2
        )
        let offset = abs("\(seed)|offset".stableHash) % holders.count
        let chosen = (0..<(count - 1)).map { holders[(offset + $0) % holders.count] }

        var positions: [ContestedPosition] = [
            position(for: entityLike(subject.actorID, in: entities), claim: stage.line,
                     grounded: [subject.id], seed: seed, now: now, isSubject: true)
        ]
        let topic = subject.title.lowercased()
        positions += chosen.map {
            position(for: $0, claim: nil, grounded: [subject.id], seed: seed, now: now, isSubject: false, topic: topic)
        }

        let place = places.values.first { $0.mayActInsteadOfHost }
        let speaking = positions.filter(\.isSpeaking)
        return ContestedQuestion(
            id: "contested-\(subject.actorID)-\(subject.stageIndex)",
            question: question(for: subject, stage: stage),
            aboutMovementIDs: movements.suffix(3).map(\.id),
            placeID: place?.id,
            positions: positions,
            bookPosition: "My provisional reading is that \(speaking.first?.holderName ?? "somebody") has it closest to right. I'd like the record to show that this is a guess.",
            bookBackedHolderID: speaking.first?.holderID,
            status: .open,
            openedAt: now,
            lastMovedAt: now,
            embarrassedHolderID: nil,
            contradictingEvidence: nil
        )
    }

    /// Opens a multi-party reading from a compiled fictional consequence. The
    /// receipt is the shared fact; characters may disagree only about what it
    /// meant. This lets a pairwise Story turn become Academy-wide culture
    /// without allowing any observer to rewrite the originating scene.
    static func opening(
        consequence: StoryConsequenceReceipt,
        entities: [NarrativeWorldEntity],
        existing: [ContestedQuestion],
        now: Date
    ) -> ContestedQuestion? {
        guard existing.filter(\.isLive).count < ContestedQuestion.maximumOpen,
              consequence.characterIDs.count >= 2,
              consequence.isRelationshipPressure,
              let changedFact = consequence.changedFact?.nonEmpty else {
            return nil
        }
        let byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        let principalIDs = Array(consequence.characterIDs.prefix(2))
        guard let first = byID[principalIDs[0]], let second = byID[principalIDs[1]] else {
            return nil
        }
        let witnesses = DisagreementEngine.eligible(from: entities)
            .filter { !Set(principalIDs).contains($0.id) }
            .sorted { left, right in
                let leftScore = abs("\(consequence.id)|\(left.id)|witness".stableHash)
                let rightScore = abs("\(consequence.id)|\(right.id)|witness".stableHash)
                if leftScore == rightScore { return left.id < right.id }
                return leftScore < rightScore
            }
            .prefix(max(1, ContestedQuestion.minimumPositions - 2))
        let participants = [first, second] + Array(witnesses)
        guard participants.count >= ContestedQuestion.minimumPositions else { return nil }

        let positions = participants.enumerated().map { index, entity in
            let silence = silenceReason(
                for: entity,
                seed: consequence.id,
                isSubject: index < 2
            )
            let claim: String
            if silence != .none {
                claim = withheld(for: entity, reason: silence)
            } else if index == 0 {
                claim = "\(entity.name) says the fact must be taken at face value: \(changedFact)"
            } else if index == 1 {
                claim = "\(entity.name) says the fact is true, but its meaning has been badly misread."
            } else {
                claim = reading(for: entity, seed: consequence.id)
            }
            return ContestedPosition(
                id: "position-\(consequence.id)-\(entity.id)",
                holderID: entity.id,
                holderName: entity.name,
                claim: claim,
                groundedInIDs: [consequence.id],
                confidence: 45 + abs("\(consequence.id)|\(entity.id)|confidence".stableHash) % 45,
                silence: silence,
                formedAt: now
            )
        }
        let speaking = positions.filter(\.isSpeaking)
        let fact = String(changedFact.prefix(150))
        return ContestedQuestion(
            id: "contested-\(consequence.id)",
            question: "What did it mean when \(fact)?",
            aboutMovementIDs: [consequence.id],
            placeID: consequence.settingIDs.first,
            positions: positions,
            bookPosition: "I provisionally suspect \(speaking.first?.holderName ?? first.name) has the nearest reading. It's a guess, and I'm saying so.",
            bookBackedHolderID: speaking.first?.holderID,
            status: .open,
            openedAt: now,
            lastMovedAt: now,
            embarrassedHolderID: nil,
            contradictingEvidence: nil
        )
    }

    /// Physical evidence turns up and does not agree with whoever the Book
    /// backed. The question does not resolve: it acquires an embarrassment.
    static func complicating(
        _ question: ContestedQuestion,
        withTrace trace: String,
        now: Date
    ) -> ContestedQuestion {
        guard question.status == .open, let backed = question.bookBackedHolderID else { return question }
        var result = question
        result.status = .complicated
        result.embarrassedHolderID = backed
        result.contradictingEvidence = trace
        result.lastMovedAt = now
        return result
    }

    /// The stock readings older questions were saved with, which said the same
    /// thing for every person and every topic.
    private static let stockReadingEndings = [
        " thinks it was deliberate, and says so in those words.",
        " thinks the whole thing is being misread, and that several events have been collapsed into one.",
        " thinks nobody did it: that the situation is doing it to itself.",
        " thinks the answer is boring and everyone is enjoying the mystery too much.",
        ", which convinces nobody but them."
    ]

    /// A question saved before version 2 gets its stock readings re-voiced once,
    /// through each person's own lens. Authored claims are left exactly as they are.
    static func revoiced(_ question: ContestedQuestion, entities: [NarrativeWorldEntity]) -> ContestedQuestion {
        guard question.version < ContestedQuestion.currentVersion else { return question }
        var result = question
        result.version = ContestedQuestion.currentVersion
        let topic = question.question.range(of: "going on with ").map {
            question.question[$0.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "?. "))
        } ?? "it"
        for index in result.positions.indices where result.positions[index].isSpeaking {
            let claim = result.positions[index].claim
            guard stockReadingEndings.contains(where: { claim.hasSuffix($0) }),
                  let entity = entities.first(where: { $0.id == result.positions[index].holderID }) else { continue }
            result.positions[index].claim = reading(for: entity, seed: question.id, topic: topic.isEmpty ? "it" : topic)
        }
        return result
    }

    static func resting(_ question: ContestedQuestion, now: Date, afterDays: Double = 21) -> ContestedQuestion {
        guard question.isLive,
              now.timeIntervalSince(question.lastMovedAt) > afterDays * 86_400 else { return question }
        var result = question
        result.status = .restingUnresolved
        return result
    }

    /// The Book was wrong in public. That is exactly the existing fault-and-repair
    /// shape, so it reuses it rather than inventing a second correction path.
    static func faultEpisode(from question: ContestedQuestion, now: Date) -> BookFaultEpisode? {
        guard question.status == .complicated,
              let trace = question.contradictingEvidence,
              let backedID = question.embarrassedHolderID,
              let backed = question.positions.first(where: { $0.holderID == backedID }) else { return nil }
        return BookFaultEpisode(
            id: "fault-\(question.id)",
            kind: .prematurePattern,
            admission: "I took \(backed.holderName)'s side on this, and said so. \(trace)",
            repair: "I am leaving both readings standing. The Academy has not settled it, and I should not have sounded as though it had.",
            evidencePageIDs: question.aboutMovementIDs,
            recognizedAt: now,
            presentedAt: nil
        )
    }

    // MARK: - Authoring

    private static func entityLike(_ id: String, in entities: [NarrativeWorldEntity]) -> NarrativeWorldEntity {
        entities.first { $0.id == id }
            ?? NarrativeWorldEntity(id: id, packID: "core-narrative-os", name: id, kind: .character,
                                    belief: 10, narrativeWeight: 10)
    }

    private static func position(
        for entity: NarrativeWorldEntity,
        claim: String?,
        grounded: [String],
        seed: String,
        now: Date,
        isSubject: Bool,
        topic: String = "it"
    ) -> ContestedPosition {
        let silence = silenceReason(for: entity, seed: seed, isSubject: isSubject)
        return ContestedPosition(
            id: "position-\(seed)-\(entity.id)",
            holderID: entity.id,
            holderName: entity.name,
            claim: silence == .none
                ? (claim ?? reading(for: entity, seed: seed, topic: topic))
                : withheld(for: entity, reason: silence),
            groundedInIDs: grounded,
            confidence: 40 + abs("\(seed)|\(entity.id)|confidence".stableHash) % 50,
            silence: silence,
            formedAt: now
        )
    }

    /// A fault can stop somebody testifying. Trencher's is the clearest case:
    /// he will not let anyone finish thanking him, so he will not speak while
    /// he is being thanked.
    static func silenceReason(for entity: NarrativeWorldEntity, seed: String, isSubject: Bool) -> ContestedSilenceReason {
        guard !isSubject else { return .none }
        let faults = entity.faults.joined(separator: " ").lowercased()
        if faults.contains("thank") { return .faultPreventsIt }
        if faults.contains("instead of talking") || faults.contains("unsaid") { return .faultPreventsIt }
        // Most people simply have an opinion.
        return abs("\(seed)|\(entity.id)|silence".stableHash) % 100 < 12
            ? .wouldHaveToAdmitSomething
            : .none
    }

    private static func withheld(for entity: NarrativeWorldEntity, reason: ContestedSilenceReason) -> String {
        switch reason {
        case .faultPreventsIt:
            return "\(entity.name) knows something and will not say it. The shape of the refusal is itself information."
        case .wouldHaveToAdmitSomething:
            return "\(entity.name) has declined to comment, at slightly too much length."
        case .notTheirBusiness:
            return "\(entity.name) considers the whole question none of their business, loudly."
        case .none:
            return ""
        }
    }

    /// How each of the Cast reads any question, from their own belief and fault:
    /// `{n}` is their name, `{t}` the thing in question. Two each, so the same
    /// person doesn't say the same thing about every argument.
    static let readings: [String: [String]] = [
        "professor-thaddeus-mook": ["{n} insists {t} is a matter of definition, and has issued a written decree about it.",
                                    "{n} says {t} only looks mysterious to people who haven't looked it up."],
        "pippa-pilcrow": ["{n} says {t} is obviously trying to become something else, and would like to help.",
                          "{n} thinks {t} is the most fun the Academy's had all week, and hopes nobody solves it."],
        "penny-blackletter": ["{n} says there's a receipt for {t} somewhere, and intends to find it.",
                              "{n} thinks one honest detail would settle {t}. Nobody's brought one yet."],
        "dr-inkrest": ["{n} thinks {t} is about somebody who's tired, and says the room should go easier on them.",
                       "{n} says {t} deserves a chair and a lamp before it deserves a verdict."],
        "dr-vellum": ["{n} says {t} wants an experiment more than an argument, and has offered to run one.",
                      "{n} thinks {t} has a simple cause that nobody's bothered to measure."],
        "headmistress-thorne": ["{n} says {t} is being handled, and declines to say by whom.",
                                "{n} thinks {t} is prettier left alone, and says so in the voice that ends conversations."],
        "orion-blackthorn": ["{n} thinks {t} needs a better system around it, and has already drawn one.",
                             "{n} says {t} is a building problem pretending to be a mystery."],
        "zara-finch": ["{n} says to watch who keeps coming back to {t}, because that's where the answer is.",
                       "{n} reckons {t} comes down to who can be trusted with a key."],
        "wicker-eddies": ["{n} thinks {t} is a fake, and wants it on the record that Wicker said so first.",
                          "{n} says {t} won't survive one good question, and has several ready."],
        "serenity-brown": ["{n} says {t} is lovely, and everyone's being far too serious about it.",
                           "{n} thinks {t} wants celebrating before anybody explains it."],
        "finn-bridges": ["{n} says the only way to settle {t} is to go and do the thing.",
                         "{n} reckons whoever's behind {t} hasn't earned an opinion yet."],
        "lysander-mosswood": ["{n} thinks {t} makes sense if you walk up to it slowly.",
                              "{n} says {t} will explain itself to anyone patient enough to follow it."],
        "damien-nights": ["{n} says there's more to {t} than anyone's admitting, and then says nothing else.",
                          "{n} suspects {t} is cover for something quieter."],
        "melisande-blackwood": ["{n} says somebody knows exactly what {t} is, and it isn't anyone in this argument.",
                                "{n} thinks {t} is a move in a game the rest of the Academy hasn't noticed."],
        "min-seo-kim": ["{n} says whoever's in the middle of {t} could use a friend more than a theory.",
                        "{n} thinks {t} would be easier if somebody just asked."],
        "gwendolyn-mythwright": ["{n} says {t} should be written down properly before anyone decides what it means.",
                                 "{n} believes {t} is improbable, which is usually a sign it's true."],
        "lydia-boggle": ["{n} thinks {t} is a household matter, and would clear up with a good tidy.",
                         "{n} says {t} is what happens when nobody puts things back."],
        "ambrose-trencher": ["{n} says {t} would make more sense on a full stomach.",
                             "{n} thinks somebody behind {t} is hungry and won't say so."],
        "soren-ng": ["{n} says {t} has a pattern, points at where it goes, and won't finish the line.",
                     "{n} thinks {t} is a map of something, and the interesting bit is what's been left off it."],
        "professor-kyle-momort": ["{n} says {t} needs one step, taken now, and the whole thing will move.",
                                  "{n} reckons the arguing over {t} is good for everyone. No conflict, no story."],
        "professor-eleanor-euphony": ["{n} says {t} sounds wrong, and she means that exactly.",
                                      "{n} thinks the answer to {t} is in a smell or a sound nobody's noticed."],
        "professor-vivian-villanelle": ["{n} says {t} should be written down exactly before anyone tells it again.",
                                        "{n} thinks {t} has been told so many ways that nobody can see it any more."],
        "professor-cedric-stonebrook": ["{n} says {t} will settle if everyone sits down for a minute.",
                                        "{n} thinks {t} isn't urgent, and says so very slowly."],
        "professor-luna-wispwood": ["{n} thinks {t} is something ordinary trying to get the Academy's attention.",
                                    "{n} says {t} is the best accident of the term, and wants to see it happen again."],
        "professor-permancer": ["{n} says nobody should go near {t} until he's checked how to get back out.",
                                "{n} thinks {t} opened something, and wants to know who's going to close it."]
    ]

    static func reading(for entity: NarrativeWorldEntity, seed: String, topic: String = "it") -> String {
        let lens = entity.beliefs.first ?? entity.traits.first ?? "the obvious explanation"
        let frames = readings[entity.id] ?? [
            "{n} thinks {t} was deliberate, and says so in those words.",
            "{n} thinks {t} is being misread, and that several things have been squashed into one.",
            "{n} thinks nobody did {t}, and the situation is doing it to itself.",
            "{n} reads {t} through \(lens), which convinces nobody but {n}."
        ]
        return frames[abs("\(seed)|\(entity.id)|frame".stableHash) % frames.count]
            .replacingOccurrences(of: "{n}", with: entity.name)
            .replacingOccurrences(of: "{t}", with: topic)
    }

    private static func question(for undertaking: CastUndertaking, stage: CastUndertakingStage) -> String {
        let subject = undertaking.title.lowercased()
        return "What is actually going on with \(subject)?"
    }
}
