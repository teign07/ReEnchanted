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
    /// What they are reasoning from. Never invented — it points at real ledger
    /// movements or place incidents.
    var groundedInIDs: [String]
    var confidence: Int
    var silence: ContestedSilenceReason
    var formedAt: Date

    /// A character who is holding out is still a participant — the shape of
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

/// A disputed event several characters read differently — and about which the
/// Book itself may be wrong.
///
/// This is the multi-party generalisation of the pairwise `DisagreementEngine`.
/// The point is not a debate minigame: it is that the relationship field becomes
/// a *culture of interpretation* rather than only a network of fondness and
/// friction. The Book holds a provisional opinion, and later physical evidence
/// is allowed to embarrass it.
struct ContestedQuestion: Codable, Equatable, Identifiable {
    static let currentVersion = 1
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
        // Ground it in an undertaking that is actually underway — the Academy
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
        positions += chosen.map {
            position(for: $0, claim: nil, grounded: [subject.id], seed: seed, now: now, isSubject: false)
        }

        let place = places.values.first { $0.mayActInsteadOfHost }
        let speaking = positions.filter(\.isSpeaking)
        return ContestedQuestion(
            id: "contested-\(subject.actorID)-\(subject.stageIndex)",
            question: question(for: subject, stage: stage),
            aboutMovementIDs: movements.suffix(3).map(\.id),
            placeID: place?.id,
            positions: positions,
            bookPosition: "The Book's provisional reading is that \(speaking.first?.holderName ?? "somebody") has it closest to right. It would like the record to show that this is a guess.",
            bookBackedHolderID: speaking.first?.holderID,
            status: .open,
            openedAt: now,
            lastMovedAt: now,
            embarrassedHolderID: nil,
            contradictingEvidence: nil
        )
    }

    /// Physical evidence turns up and does not agree with whoever the Book
    /// backed. The question does not resolve — it acquires an embarrassment.
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
        isSubject: Bool
    ) -> ContestedPosition {
        let silence = silenceReason(for: entity, seed: seed, isSubject: isSubject)
        return ContestedPosition(
            id: "position-\(seed)-\(entity.id)",
            holderID: entity.id,
            holderName: entity.name,
            claim: silence == .none
                ? (claim ?? reading(for: entity, seed: seed))
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

    private static func reading(for entity: NarrativeWorldEntity, seed: String) -> String {
        let lens = entity.beliefs.first ?? entity.traits.first ?? "the obvious explanation"
        let frames = [
            "\(entity.name) thinks it was deliberate, and says so in those words.",
            "\(entity.name) thinks the whole thing is being misread, and that several events have been collapsed into one.",
            "\(entity.name) thinks nobody did it — that the situation is doing it to itself.",
            "\(entity.name) thinks the answer is boring and everyone is enjoying the mystery too much.",
            "\(entity.name) reads it through \(lens), which convinces nobody but them."
        ]
        return frames[abs("\(seed)|\(entity.id)|frame".stableHash) % frames.count]
    }

    private static func question(for undertaking: CastUndertaking, stage: CastUndertakingStage) -> String {
        let subject = undertaking.title.lowercased()
        return "What is actually going on with \(subject)?"
    }
}
