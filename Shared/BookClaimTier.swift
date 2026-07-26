import Foundation

/// How large a claim the Book has earned the right to make.
///
/// The Book always speaks. What a thin archive changes is not *whether* it says
/// something but *how big a thing* it is willing to say. This is the
/// replacement for the count gates that used to hold whole page families back
/// until the fiftieth kept page: a new reader now gets a small true sentence
/// where they used to get silence, and the same page grows into a claim as the
/// evidence under it grows.
///
/// The three steps deliberately match `RelationalLoomConnection.EvidenceTier`,
/// which arrived at the same ladder independently. That one is the
/// specialization for contrast-tested relationships; this is the general form
/// every other page family can reach for. `init(loom:)` bridges them so the
/// Book only ever climbs one ladder.
enum BookClaimTier: String, Codable, CaseIterable, Comparable, Equatable {
    /// Noticed once or twice. The Book may point; it may not conclude.
    case glimmer
    /// It keeps happening. The Book may say so, and say that it is watching.
    case gathering
    /// Steady enough to name. The Book may make a claim about the reader.
    case established

    /// Evidence required to climb. `weight` is whatever the calling page
    /// counts as one piece of support — a cluster, a graph edge, a returning
    /// motif, a kept page. `days` is how many distinct calendar days that
    /// evidence is spread across, which is the part a single long session
    /// cannot manufacture.
    enum Thresholds {
        static let gatheringWeight = 4
        static let gatheringDays = 3
        static let establishedWeight = 8
        static let establishedDays = 5
    }

    var rank: Int {
        switch self {
        case .glimmer: return 0
        case .gathering: return 1
        case .established: return 2
        }
    }

    static func < (lhs: BookClaimTier, rhs: BookClaimTier) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Resolve a tier from the evidence a page actually holds. `distinctDays`
    /// is optional because some pages (a graph of the reader's people, say)
    /// have weight without a day spread; passing nil judges on weight alone.
    static func tier(evidenceWeight: Int, distinctDays: Int? = nil) -> BookClaimTier {
        let days = distinctDays ?? Int.max
        if evidenceWeight >= Thresholds.establishedWeight && days >= Thresholds.establishedDays {
            return .established
        }
        if evidenceWeight >= Thresholds.gatheringWeight && days >= Thresholds.gatheringDays {
            return .gathering
        }
        return .glimmer
    }

    init(loom: RelationalLoomConnection.EvidenceTier) {
        switch loom {
        case .glimmer: self = .glimmer
        case .gathering: self = .gathering
        case .established: self = .established
        }
    }

    /// How the Book opens a statement at this size. Mirrors the Loom's wording
    /// so a reader who meets both never hears two different Books.
    var opening: String {
        switch self {
        case .glimmer: return "A small glimmer, held lightly:"
        case .gathering: return "A connection is gathering:"
        case .established: return "The pattern has steadied:"
        }
    }

    var closing: String {
        switch self {
        case .glimmer: return "This is early. The Book is asking, not announcing."
        case .gathering: return "The lean is forming, but more Pages may still change its shape."
        case .established: return "The Book is naming a lean, not a cause."
        }
    }

    /// The verb the Book may use about itself at this size. Uncertainty belongs
    /// here — in what the Book claims to know — never in how it addresses the
    /// reader.
    var verb: String {
        switch self {
        case .glimmer: return "has noticed"
        case .gathering: return "keeps finding"
        case .established: return "is naming"
        }
    }

    /// A short, literal statement of what the claim rests on, so the hedge is
    /// carried by the evidence rather than by a vague "perhaps".
    func evidenceQualifier(weight: Int, distinctDays: Int? = nil) -> String {
        let pieces = weight == 1 ? "one thread" : "\(weight) threads"
        guard let days = distinctDays, days > 0 else { return "on \(pieces)" }
        let dayWord = days == 1 ? "one day" : "\(days) days"
        return "on \(pieces) across \(dayWord)"
    }

    /// A floor for a page's surface score. A bigger claim is worth more of the
    /// desk, but a glimmer still earns a slot — that is the whole point.
    var surfaceScoreBase: Int {
        switch self {
        case .glimmer: return 44
        case .gathering: return 54
        case .established: return 64
        }
    }

    /// Pick tier-appropriate prose. Each tier supplies its own pool so a young
    /// archive gets language sized to it instead of a mature page's wording
    /// with a "maybe" bolted on the front.
    static func prose(
        glimmer: [String],
        gathering: [String],
        established: [String],
        tier: BookClaimTier,
        seed: UInt64,
        salt: UInt64
    ) -> String {
        let pool: [String]
        switch tier {
        case .glimmer: pool = glimmer
        case .gathering: pool = gathering
        case .established: pool = established
        }
        guard !pool.isEmpty else { return "" }
        return ReflectiveProse.pick(pool, seed: seed, salt: salt)
    }
}
