import Foundation

/// Where a pressure came from. Every origin is an *emergent* state transition:
/// something the simulation did, rather than an authored calendar event.
enum WorldPressureOrigin: String, Codable, Equatable, CaseIterable {
    case rivalry
    case alliance
    case undertakingStage
    case placeRefusal
}

/// Which existing surface a fingerprint colours. There is deliberately no
/// `page` case: a pressure may never mint a Page, claim a desk slot, or spend
/// an interruption seat. It modifies things the reader was going to see anyway.
enum WorldFingerprintSurface: String, Codable, Equatable, CaseIterable {
    case bleedCopy
    case radioMargin
    case letterFootnote
    case classDescription
    case portraitMark
    case shopItem
    case bystanderComplaint
}

struct WorldFingerprint: Codable, Equatable, Identifiable {
    var id: String
    var surface: WorldFingerprintSurface
    var subjectID: String
    var line: String
}

/// One emergent state transition, leaving several small marks in places the
/// reader does not expect, for about a week.
///
/// This generalises the world-event envelope, where one authored event already
/// reaches the Bleed, Radio, widgets, letters, and braids: from authored
/// events to things the simulation did on its own.
struct WorldPressure: Codable, Equatable, Identifiable {
    static let currentVersion = 1
    /// Seasoning, not weather. Two at once is already a lot of world.
    static let maximumActive = 2
    static let durationDays = 7

    var version: Int = currentVersion
    var id: String
    var origin: WorldPressureOrigin
    var subjectIDs: [String]
    var summary: String
    var fingerprints: [WorldFingerprint]
    var beganAt: Date
    var expiresAt: Date

    func isActive(at now: Date) -> Bool { now < expiresAt }
}

enum WorldPressureEngine {
    /// A rivalry has to actually be a rivalry, not a bad afternoon.
    static let rivalryTensionThreshold = 12
    static let allianceWarmthThreshold = 14

    static func active(_ pressures: [WorldPressure], now: Date) -> [WorldPressure] {
        pressures.filter { $0.isActive(at: now) }
            .sorted { $0.beganAt < $1.beganAt }
    }

    /// Mint at most one new pressure, and only if there is room. Nothing here
    /// escalates: an unmet pressure simply expires.
    static func minting(
        into existing: [WorldPressure],
        relationshipField: [String: RelationshipTie],
        advancedUndertaking: CastUndertaking?,
        castName: (String) -> String,
        now: Date
    ) -> [WorldPressure] {
        var result = active(existing, now: now)
        guard result.count < WorldPressure.maximumActive else { return result }

        if let candidate = rivalryOrAlliance(in: relationshipField, castName: castName, now: now),
           !result.contains(where: { $0.id == candidate.id }) {
            result.append(candidate)
            return result
        }
        if let undertaking = advancedUndertaking,
           let candidate = undertakingPressure(for: undertaking, castName: castName, now: now),
           !result.contains(where: { $0.id == candidate.id }) {
            result.append(candidate)
        }
        return result
    }

    private static func rivalryOrAlliance(
        in field: [String: RelationshipTie],
        castName: (String) -> String,
        now: Date
    ) -> WorldPressure? {
        // Deterministic: strongest qualifying tie wins, ties broken by key.
        let candidates = field.compactMap { key, tie -> (String, RelationshipTie, WorldPressureOrigin)? in
            if tie.tension >= rivalryTensionThreshold { return (key, tie, .rivalry) }
            if tie.warmth >= allianceWarmthThreshold { return (key, tie, .alliance) }
            return nil
        }
        .sorted { left, right in
            let leftScore = max(left.1.tension, left.1.warmth)
            let rightScore = max(right.1.tension, right.1.warmth)
            if leftScore != rightScore { return leftScore > rightScore }
            return left.0 < right.0
        }
        guard let (key, _, origin) = candidates.first else { return nil }

        let ids = key.split(separator: "|").map(String.init)
        guard ids.count == 2 else { return nil }
        let names = ids.map(castName)
        return WorldPressure(
            id: "pressure-\(origin.rawValue)-\(key)",
            origin: origin,
            subjectIDs: ids,
            summary: origin == .rivalry
                ? "\(names[0]) and \(names[1]) have stopped pretending to agree."
                : "\(names[0]) and \(names[1]) have started arriving places together.",
            fingerprints: fingerprints(origin: origin, ids: ids, names: names),
            beganAt: now,
            expiresAt: now.addingTimeInterval(Double(WorldPressure.durationDays) * 86_400)
        )
    }

    private static func undertakingPressure(
        for undertaking: CastUndertaking,
        castName: (String) -> String,
        now: Date
    ) -> WorldPressure? {
        guard let stage = undertaking.currentBeat else { return nil }
        let name = castName(undertaking.actorID)
        let key = "\(undertaking.id)-\(undertaking.stageIndex)"

        // A beat used to leave two marks where a rivalry left seven, which made
        // the Academy's own business the quietest thing in it. The trace and the
        // bystander stay required; the rest are the sideways return — the reader
        // meets the same event again somewhere that does not know it is evidence.
        var fingerprints = [
            WorldFingerprint(
                id: "fp-\(key)-trace",
                surface: .bleedCopy,
                subjectID: undertaking.actorID,
                line: stage.trace
            ),
            WorldFingerprint(
                id: "fp-\(key)-bystander",
                surface: .bystanderComplaint,
                subjectID: undertaking.actorID,
                line: "Somebody uninvolved has started going the long way around because of \(name)."
            )
        ]

        // Put on the record, characters do not confess. This is the funniest
        // surface the Academy has and it was not reachable from a beat at all.
        if let deniability = stage.deniability {
            fingerprints.append(WorldFingerprint(
                id: "fp-\(key)-radio",
                surface: .radioMargin,
                subjectID: undertaking.actorID,
                line: "Asked about it on the margin band, \(name) said only: \u{201C}\(deniability)\u{201D}"
            ))
        }

        fingerprints.append(WorldFingerprint(
            id: "fp-\(key)-shop",
            surface: .shopItem,
            subjectID: undertaking.actorID,
            line: shopItem(for: stage)
        ))
        fingerprints.append(WorldFingerprint(
            id: "fp-\(key)-notice",
            surface: .classDescription,
            subjectID: undertaking.actorID,
            line: classNotice(for: stage, name: name)
        ))

        // Everybody who was actually in the beat, not only whose ladder it is.
        // `hotActorIDs` unions these, so a crossing makes the world busy around
        // both people and their independently running threads start wandering
        // into the same rooms — which is the point of recording a crossing at
        // all rather than leaving it in the prose.
        let subjects = ([undertaking.actorID] + (stage.castIDs ?? []))
            .reduce(into: [String]()) { found, id in
                if !found.contains(id) { found.append(id) }
            }

        return WorldPressure(
            id: "pressure-undertaking-\(undertaking.id)-\(undertaking.stageIndex)",
            origin: .undertakingStage,
            subjectIDs: subjects,
            summary: "\(name): \(stage.line)",
            fingerprints: fingerprints,
            beganAt: now,
            expiresAt: now.addingTimeInterval(Double(WorldPressure.durationDays) * 86_400)
        )
    }

    /// The Goblin Market has no idea why this is suddenly worth stocking, which
    /// is the point: the shelf reacts to the week without understanding it.
    /// Keyed off the beat's own tags so the object is at least adjacent to what
    /// happened, and deterministic so a week does not reshuffle its own shelf.
    static func shopItem(for stage: CastUndertakingStage) -> String {
        let byTag: [String: [String]] = [
            "archive": ["A back issue with one comma circled. Sold as read.",
                        "Somebody's index cards, alphabetical up to F."],
            "words": ["A dictionary missing exactly one definition. Priced accordingly.",
                      "Loose punctuation, mixed, by weight."],
            "threshold": ["A doorstop with a strong opinion about doors.",
                          "One hinge, barely used, no questions."],
            "food": ["A cooking pot that has been listened to.",
                     "Half a jar of something that was labelled once."],
            "objects": ["An inventory tag with nothing left attached to it.",
                        "A can of oil, three-quarters full, no shelf of its own."],
            "sky": ["A brass instrument, honest, two degrees off.",
                    "A logbook with the corrections crossed out."],
            "data": ["A ruled ledger with one column headed SOUP.",
                     "A chart with one Tuesday circled four times."],
            "place": ["A lamp that is on no maintenance list.",
                      "A map with one route drawn in a second hand."],
            "record": ["An envelope, sealed, dated a year from now.",
                       "A ledger with one page missing and no gap in the numbering."],
            "rules": ["A memo about unsanctioned wayfinding. Unread.",
                      "A floor plan with a corridor slightly too long."]
        ]
        for tag in stage.tags {
            guard let options = byTag[tag] else { continue }
            return options[abs("\(stage.id)|shop".stableHash) % options.count]
        }
        return "Something that turned up this week and nobody has claimed."
    }

    /// A notice on a door, written by somebody who was not there and is working
    /// from the same rumour as everyone else.
    static func classNotice(for stage: CastUndertakingStage, name: String) -> String {
        let options = [
            "This week's session will avoid, by request, the subject everybody arrived wanting to discuss.",
            "The notice says attendance is being audited. It does not say by whom.",
            "Somebody has added a line to the reading list in a hand that is not the tutor's.",
            "The session has been moved one room along, for reasons given as \u{201C}ongoing\u{201D}.",
            "A note on the door: \(name) is not expected, and the room has been arranged as though they are."
        ]
        return options[abs("\(stage.id)|notice".stableHash) % options.count]
    }

    /// One transition, several small marks. The bystander complaint is required,
    /// not decorative: collateral inconvenience is what makes a dispute feel like
    /// it happened inside a society rather than in a vacuum between two people.
    static func fingerprints(origin: WorldPressureOrigin, ids: [String], names: [String]) -> [WorldFingerprint] {
        let key = ids.joined(separator: "-")
        switch origin {
        case .rivalry:
            return [
                WorldFingerprint(id: "fp-\(key)-bleed", surface: .bleedCopy, subjectID: ids[0],
                                 line: "\(names[0])'s copy has become aggressively sourced this week."),
                WorldFingerprint(id: "fp-\(key)-radio", surface: .radioMargin, subjectID: ids[0],
                                 line: "An anonymous correction was broadcast on the margin band. Nobody claimed it."),
                WorldFingerprint(id: "fp-\(key)-letter", surface: .letterFootnote, subjectID: ids[1],
                                 line: "\(names[1])'s letters have acquired footnotes of a distinctly suspicious character."),
                WorldFingerprint(id: "fp-\(key)-class", surface: .classDescription, subjectID: ids[0],
                                 line: "Attendance this week is being, the notice says, unexpectedly audited."),
                WorldFingerprint(id: "fp-\(key)-portrait", surface: .portraitMark, subjectID: ids[1],
                                 line: "Somebody has pencilled a small mark in the corner of the portrait."),
                WorldFingerprint(id: "fp-\(key)-shop", surface: .shopItem, subjectID: ids[0],
                                 line: "Officially Unrelated Red Pencil: sold as-is, no explanation offered."),
                WorldFingerprint(id: "fp-\(key)-bystander", surface: .bystanderComplaint, subjectID: ids[1],
                                 line: "A third party would like it known that they have nothing to do with any of this, and that their tea has gone cold twice.")
            ]
        case .alliance:
            return [
                WorldFingerprint(id: "fp-\(key)-bleed", surface: .bleedCopy, subjectID: ids[0],
                                 line: "Two sets of handwriting have started appearing on the same notices."),
                WorldFingerprint(id: "fp-\(key)-letter", surface: .letterFootnote, subjectID: ids[1],
                                 line: "\(names[1])'s letters now assume you already heard it from \(names[0])."),
                WorldFingerprint(id: "fp-\(key)-shop", surface: .shopItem, subjectID: ids[0],
                                 line: "A second-hand kettle, listed under both their names."),
                WorldFingerprint(id: "fp-\(key)-bystander", surface: .bystanderComplaint, subjectID: ids[1],
                                 line: "Somebody has pointed out, without being asked, that it used to be easier to get a word in.")
            ]
        case .undertakingStage, .placeRefusal:
            return []
        }
    }
}
