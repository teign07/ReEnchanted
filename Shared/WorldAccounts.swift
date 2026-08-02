import Foundation

/// Whose version of events this is.
enum WorldAccountKind: String, Codable, Equatable, CaseIterable {
    /// Penny's version of record. Confident, sourced, and not necessarily right.
    case filed
    /// Corridor talk. Fast, vivid, and structurally unreliable.
    case rumor
    /// A participant's own letter, which has an interest in the outcome.
    case selfServing
    /// A physical residue. Says nothing, implies plenty.
    case trace
    /// The Book's own hedged reading, which knows it is one voice among several.
    case cautious
}

struct WorldAccount: Codable, Equatable, Identifiable {
    var id: String
    var movementID: String
    var kind: WorldAccountKind
    var line: String
    /// Accounts of the same event may disagree. That is the feature.
    var contradictsSibling: Bool
}

/// Several tellings of one thing that happened.
///
/// Structured state protects continuity, but the reader-facing world should not
/// therefore sound omniscient. The ledger movement stays single and consistent;
/// what the reader receives is testimony. Nothing here mutates world state, and
/// nothing here is required to resolve.
enum WorldAccountEngine {
    /// A single event does not get five simultaneous tellings — that would be a
    /// dossier, not a rumour. Two or three is how a thing actually reaches you.
    static let minimumAccounts = 2
    static let maximumAccounts = 3

    static func accounts(for movement: CastAgencyMovement, placeName: String? = nil) -> [WorldAccount] {
        let seed = movement.id
        let ordered = WorldAccountKind.allCases
        let count = minimumAccounts + abs("\(seed)|count".stableHash) % (maximumAccounts - minimumAccounts + 1)
        let offset = abs("\(seed)|offset".stableHash) % ordered.count
        let chosen = (0..<count).map { ordered[(offset + $0) % ordered.count] }

        return chosen.enumerated().map { index, kind in
            // The later tellings are the ones that drift. The first account a
            // thing gets is usually the one that sounds most certain.
            let contradicts = index > 0 && abs("\(seed)|\(kind.rawValue)|drift".stableHash) % 100 < 45
            return WorldAccount(
                id: "account-\(seed)-\(kind.rawValue)",
                movementID: movement.id,
                kind: kind,
                line: line(kind: kind, movement: movement, placeName: placeName, contradicts: contradicts),
                contradictsSibling: contradicts
            )
        }
    }

    /// Whether the Book is willing to say which account was right. It is not.
    static func resolution(for accounts: [WorldAccount]) -> String? {
        guard accounts.contains(where: \.contradictsSibling) else { return nil }
        let options = [
            "Nobody has reconciled these two versions, and nobody seems in a hurry to.",
            "Both accounts are still in circulation. I've got no way to choose between them.",
            "These do not agree. The Book is recording that rather than settling it."
        ]
        let seed = accounts.map(\.id).joined()
        return options[abs(seed.stableHash) % options.count]
    }

    private static func line(
        kind: WorldAccountKind,
        movement: CastAgencyMovement,
        placeName: String?,
        contradicts: Bool
    ) -> String {
        let actor = movement.actorName
        let target = movement.targetName
        let place = placeName ?? "somewhere with poor acoustics"
        switch kind {
        case .filed:
            return contradicts
                ? "Filed: \(actor) acted first. Two sources, both named, both certain."
                : "Filed: \(movement.line) Sourced, dated, and set in type."
        case .rumor:
            return contradicts
                ? "The corridor version has \(target) starting it, and has acquired a slammed door that appears in no other telling."
                : "The corridor version is broadly this, with more shouting and an audience of nine."
        case .selfServing:
            return contradicts
                ? "\(actor)'s own letter describes the whole thing as a misunderstanding that they were, if anything, resolving."
                : "\(actor) wrote about it afterwards, at length, and mostly about the principle involved."
        case .trace:
            return contradicts
                ? "In \(place): two cups, one chair pushed back hard, and no sign anybody raised their voice at all."
                : "In \(place): the arrangement of the furniture afterwards suggested a conversation that went on longer than intended."
        case .cautious:
            return "The Book's reading, offered lightly: something between \(actor) and \(target) changed, and the Book is not certain it has the order right."
        }
    }
}
