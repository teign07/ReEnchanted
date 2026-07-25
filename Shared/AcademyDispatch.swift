import Foundation

/// A short line about something the Academy actually did.
///
/// This is deliberately *not* a variable-ratio reward. A slot machine's pull
/// comes from blanks and near-misses, which trains checking — the exact
/// behaviour this product exists to reverse. So there is no such thing as an
/// empty dispatch: if the Academy has done nothing worth mentioning, nothing is
/// said, and nothing hints that something was almost there.
///
/// The unpredictability is real but it comes from contingency rather than from
/// a randomiser: the reader cannot predict it because *the Book cannot either*.
/// Some days the world does three notable things; most days it does none. Which
/// one gets mentioned, and whether it is mentioned now or simply left in the
/// ledger to be found later, varies.
struct AcademyDispatch: Equatable, Identifiable {
    enum Kind: String, Equatable, CaseIterable {
        case business      // an undertaking moved
        case argument      // the Academy is disagreeing about something
        case embarrassment // the Book backed the wrong reading
        case room          // a place has started refusing something
        case collateral    // somebody uninvolved got caught in it
    }

    var id: String
    var kind: Kind
    var line: String
}

enum AcademyDispatchDesk {
    /// Long enough that it never becomes a drip feed. The ledger is always
    /// available for a reader who wants more; this is only the occasional
    /// remark in passing.
    static let minimumHoursBetween: Double = 5

    /// Even with something to say, the Book will often just... not. The
    /// withheld item is not lost — it stays in the ledger and stays eligible —
    /// so this creates no missed reward, only an irregular voice.
    static let speaksAnywayPercent = 55

    /// Everything the Academy could currently remark on, most recent first.
    /// Empty is a perfectly ordinary result.
    static func candidates(
        undertakings: [CastUndertaking],
        questions: [ContestedQuestion],
        places: [String: PlaceState],
        pressures: [WorldPressure],
        now: Date
    ) -> [AcademyDispatch] {
        var found: [AcademyDispatch] = []

        for question in questions where question.isLive {
            if question.status == .complicated,
               let trace = question.contradictingEvidence,
               let backed = question.positions.first(where: { $0.holderID == question.embarrassedHolderID }) {
                found.append(AcademyDispatch(
                    id: "dispatch-embarrassment-\(question.id)",
                    kind: .embarrassment,
                    line: "I took \(backed.holderName)'s side on \(question.question.lowercased()) \(trace)"
                ))
            } else {
                let voices = question.speakingPositions.prefix(2).map(\.holderName).joined(separator: " and ")
                found.append(AcademyDispatch(
                    id: "dispatch-argument-\(question.id)",
                    kind: .argument,
                    line: "\(voices) do not agree about \(question.question.lowercased()) Nobody has settled it."
                ))
            }
        }

        for undertaking in undertakings where undertaking.isRunning {
            guard let stage = undertaking.currentStage, undertaking.stageIndex > 0 else { continue }
            found.append(AcademyDispatch(
                id: "dispatch-business-\(undertaking.id)-\(undertaking.stageIndex)",
                kind: .business,
                line: stage.line
            ))
        }

        for place in places.values.sorted(by: { $0.id < $1.id }) {
            guard let refusal = place.refusal else { continue }
            let name = place.id
                .replacingOccurrences(of: "location-", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            found.append(AcademyDispatch(
                id: "dispatch-room-\(place.id)",
                kind: .room,
                line: "\(name) \(refusal). Opinions differ on whether that means anything."
            ))
        }

        for pressure in pressures where pressure.isActive(at: now) {
            guard let bystander = pressure.fingerprints.first(where: { $0.surface == .bystanderComplaint }) else { continue }
            found.append(AcademyDispatch(
                id: "dispatch-collateral-\(pressure.id)",
                kind: .collateral,
                line: bystander.line
            ))
        }

        return found
    }

    /// Pick something to say, or say nothing. Never invents, never pads, never
    /// reports that there was nothing to report.
    static func next(
        undertakings: [CastUndertaking],
        questions: [ContestedQuestion],
        places: [String: PlaceState],
        pressures: [WorldPressure],
        alreadySaidIDs: Set<String>,
        lastSpokeAt: Date?,
        now: Date
    ) -> AcademyDispatch? {
        if let lastSpokeAt,
           now.timeIntervalSince(lastSpokeAt) < minimumHoursBetween * 3600 {
            return nil
        }
        let unmet = candidates(
            undertakings: undertakings, questions: questions,
            places: places, pressures: pressures, now: now
        ).filter { !alreadySaidIDs.contains($0.id) }
        guard !unmet.isEmpty else { return nil }

        // Seeded on the hour, so the same moment always yields the same
        // decision: reopening the app cannot reroll for a better line.
        let seed = "\(SurfaceCadence.slotID(for: now, hours: 1))|academy-dispatch"
        guard abs("\(seed)|speaks".stableHash) % 100 < speaksAnywayPercent else { return nil }

        // Only two things genuinely outrank the rest: the Book being wrong in
        // public, and an argument nobody has settled. Everything else — rooms,
        // business, collateral — is one flat tier, because a strict ordering
        // would make the voice predictable as soon as the reader noticed it
        // always works through the rooms before it mentions anyone's work.
        let privileged: [AcademyDispatch.Kind] = [.embarrassment, .argument]
        let tier: [AcademyDispatch]
        if let leading = privileged.first(where: { kind in unmet.contains { $0.kind == kind } }) {
            tier = unmet.filter { $0.kind == leading }
        } else {
            tier = unmet
        }
        let ordered = tier.sorted { $0.id < $1.id }
        return ordered[abs("\(seed)|which".stableHash) % ordered.count]
    }
}
