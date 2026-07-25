import Foundation

/// Something that happened in a room, remembered by the room.
struct PlaceIncident: Codable, Equatable, Identifiable {
    var id: String
    var line: String
    var participantIDs: [String]
    var tags: [String]
    var occurredAt: Date
}

/// Durable state layered onto an authored `.location` entity.
///
/// The `coreLocations` already have traits, quirks, faults, beliefs, and goals —
/// they are written as characters. What they lacked was history. This is the
/// same durable-state law the Book applies to itself, applied to its rooms.
///
/// Nothing here asserts that a building is alive. Ambiguity is the point: the
/// cast may disagree about whether a corridor is behaving strangely, and the
/// Book does not adjudicate.
struct PlaceState: Codable, Equatable, Identifiable {
    static let maximumIncidents = 12
    /// Enough repetition that a room's character is earned rather than declared.
    static let reputationThreshold = 3
    static let loyaltyThreshold = 3

    var id: String
    var condition: String?
    var incidents: [PlaceIncident]
    var favoredOccupantIDs: [String]
    var disputedPurpose: String?
    /// One physical detail that changes slowly across seasons.
    var slowChange: String?
    /// Something the room has begun refusing to do. Never resolves into a rule.
    var refusal: String?

    init(
        id: String,
        condition: String? = nil,
        incidents: [PlaceIncident] = [],
        favoredOccupantIDs: [String] = [],
        disputedPurpose: String? = nil,
        slowChange: String? = nil,
        refusal: String? = nil
    ) {
        self.id = id
        self.condition = condition
        self.incidents = incidents
        self.favoredOccupantIDs = favoredOccupantIDs
        self.disputedPurpose = disputedPurpose
        self.slowChange = slowChange
        self.refusal = refusal
    }

    /// A room that has hosted the same kind of scene often enough to have got a
    /// name for it. Reputation is earned from incidents, never authored.
    func reputation(for tag: String) -> Int {
        incidents.filter { $0.tags.contains(tag) }.count
    }

    var hasReputation: Bool {
        incidentTagCounts.contains { $0.value >= Self.reputationThreshold }
    }

    var strongestReputationTag: String? {
        incidentTagCounts
            .filter { $0.value >= Self.reputationThreshold }
            .sorted { left, right in
                left.value == right.value ? left.key < right.key : left.value > right.value
            }
            .first?.key
    }

    private var incidentTagCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for incident in incidents {
            for tag in incident.tags { counts[tag, default: 0] += 1 }
        }
        return counts
    }

    /// A room that has become an actor rather than a setting can be cast in
    /// gossip in its own right.
    var mayActInsteadOfHost: Bool { hasReputation && refusal != nil }
}

enum PlaceMemoryEngine {
    /// Which room an incident belongs in, when more than one could claim it.
    ///
    /// The other half of opportunistic convergence: a room that already has
    /// history pulls ambiguous incidents toward itself, so a corridor known for
    /// arguments keeps collecting them and eventually becomes the place where
    /// the argument happens. Rooms with no history are still reachable — this
    /// breaks ties, it does not close the door.
    static func preferredPlace(
        among candidates: [String],
        states: [String: PlaceState],
        tags: [String]
    ) -> String? {
        guard !candidates.isEmpty else { return nil }
        return candidates.max { left, right in
            let leftHeat = heat(of: states[left], tags: tags)
            let rightHeat = heat(of: states[right], tags: tags)
            return leftHeat == rightHeat ? left > right : leftHeat < rightHeat
        }
    }

    private static func heat(of state: PlaceState?, tags: [String]) -> Int {
        guard let state else { return 0 }
        let matching = tags.map { state.reputation(for: $0) }.max() ?? 0
        return matching * 2 + (state.refusal == nil ? 0 : 3) + min(4, state.incidents.count)
    }

    /// Places accumulate from world movements that name them, so place memory is
    /// downstream of the world clock rather than a parallel system.
    static func recording(
        _ states: [String: PlaceState],
        incident: PlaceIncident,
        placeID: String
    ) -> [String: PlaceState] {
        var result = states
        var state = result[placeID] ?? PlaceState(id: placeID)
        guard !state.incidents.contains(where: { $0.id == incident.id }) else { return result }

        state.incidents = Array((state.incidents + [incident])
            .sorted { $0.occurredAt < $1.occurredAt }
            .suffix(PlaceState.maximumIncidents))

        // Somebody who keeps turning up in a room's history becomes one of its
        // people. This is association, not affection: the room does not score them.
        var appearances: [String: Int] = [:]
        for past in state.incidents {
            for participant in past.participantIDs { appearances[participant, default: 0] += 1 }
        }
        state.favoredOccupantIDs = appearances
            .filter { $0.value >= PlaceState.loyaltyThreshold }
            .keys.sorted()

        if state.refusal == nil, let tag = state.strongestReputationTag {
            state.refusal = refusal(for: tag, placeID: placeID)
        }
        result[placeID] = state
        return result
    }

    /// What a room has begun declining to do. Deliberately unexplained — the
    /// cast can argue about whether it means anything.
    static func refusal(for tag: String, placeID: String) -> String {
        let options: [String]
        switch tag {
        case "argument", "rivalry", "unsettled":
            options = [
                "has stopped carrying raised voices past the second window",
                "no longer amplifies speeches, only interruptions",
                "returns arguments to the people who started them, slightly rearranged"
            ]
        case "food", "care", "kindness":
            options = [
                "will not let a pot go cold before somebody has eaten",
                "has stopped echoing, which makes it harder to leave quickly",
                "keeps one chair warm regardless of who last sat in it"
            ]
        case "memory", "archive", "record":
            options = [
                "has misplaced the same category of book three times and denies involvement",
                "will not surrender anything filed under a name nobody uses now",
                "keeps returning one shelf to an order nobody chose"
            ]
        default:
            options = [
                "has begun declining to be walked through in a hurry",
                "no longer looks the same size on the way out as on the way in",
                "has stopped being a shortcut"
            ]
        }
        return options[abs("\(placeID)|\(tag)|refusal".stableHash) % options.count]
    }

    /// The two readings of the same room, offered together and never resolved.
    /// One says the building is behaving strangely; one says buildings do not.
    static func disagreement(about state: PlaceState, placeName: String) -> (strange: String, ordinary: String)? {
        guard let refusal = state.refusal else { return nil }
        return (
            strange: "\(placeName) \(refusal). Some of the Academy considers this settled.",
            ordinary: "Others point out that old buildings settle, that people notice patterns, and that nobody has actually measured anything."
        )
    }
}
