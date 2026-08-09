import Foundation

/// What a perception pass actually saw, before anyone puts a voice on it.
///
/// The Book's photo pages used to go straight from a handful of Vision labels to
/// Penny's marginalia, which meant her prose was the only surviving record of
/// what was in the picture. That is fine for a caption and ruinous for an
/// archive: once "blue light kept watch" is the stored fact, the Book can cite
/// it a year later as though it were an observation. So perception now stops at
/// plain statements — "gray cat, lower left, likely" — and the literary pass is
/// a separate step that reads them.
///
/// Everything here is pure data on purpose. It lives in the shared target with
/// no Vision or UIKit import so the grounding rules can be tested without a
/// device, and so a second perception backend can fill the same packet.

/// The kind of thing a fact is about. Kept deliberately coarse: this is what a
/// caption needs to know, not an ontology.
enum VisualFactKind: String, Codable, Equatable, CaseIterable {
    case subject
    case animal
    case person
    case object
    case setting
    case visibleText
    case light
    case colour
    case composition
}

/// Which pass produced a fact. Provenance is not bookkeeping here — when two
/// passes disagree we need to know whether the claim came from a dedicated
/// recognizer or from a permissive whole-image guess.
enum VisualFactSource: String, Codable, Equatable {
    case appleVisionClassifier
    case appleVisionAnimal
    case appleVisionFace
    case appleVisionHuman
    case appleVisionText
    case appleVisionSaliencyCrop
    case imageStatistics
    case localVisionModel
}

/// Confidence as the Book is allowed to speak it. Numeric confidence is kept on
/// the fact for ranking, but prose should never carry a decimal — the reader is
/// owed "probably" or "I think", not "0.41".
enum VisualCertainty: String, Codable, Equatable, Comparable {
    case possible
    case likely
    case clear

    init(confidence: Double) {
        switch confidence {
        case ..<0.35: self = .possible
        case ..<0.7: self = .likely
        default: self = .clear
        }
    }

    /// How the fact should be hedged when it reaches a prompt.
    var hedge: String {
        switch self {
        case .possible: return "maybe"
        case .likely: return "probably"
        case .clear: return "clearly"
        }
    }

    private var rank: Int {
        switch self {
        case .possible: return 0
        case .likely: return 1
        case .clear: return 2
        }
    }

    static func < (lhs: VisualCertainty, rhs: VisualCertainty) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Where in the frame something sits, in Vision's normalized coordinates
/// (origin bottom-left, 0...1 on both axes).
struct VisualRegion: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var area: Double { max(0, width) * max(0, height) }

    var centreX: Double { x + width / 2 }
    var centreY: Double { y + height / 2 }

    /// Plain placement words, so a caption can say "lower left" without the
    /// prompt ever seeing a coordinate.
    var placement: String {
        let horizontal: String
        switch centreX {
        case ..<0.34: horizontal = "left"
        case ..<0.67: horizontal = "centre"
        default: horizontal = "right"
        }
        let vertical: String
        switch centreY {
        case ..<0.34: vertical = "lower"
        case ..<0.67: vertical = "middle"
        default: vertical = "upper"
        }
        if horizontal == "centre" && vertical == "middle" { return "centre frame" }
        if horizontal == "centre" { return vertical }
        if vertical == "middle" { return horizontal }
        return "\(vertical) \(horizontal)"
    }

    /// Whether the thing is big enough in frame to be what the photo is *of*.
    var isProminent: Bool { area >= 0.12 }
}

/// One plain statement about the picture.
struct VisualFact: Codable, Equatable {
    var kind: VisualFactKind
    var label: String
    var confidence: Double
    var source: VisualFactSource
    var region: VisualRegion?

    init(
        kind: VisualFactKind,
        label: String,
        confidence: Double,
        source: VisualFactSource,
        region: VisualRegion? = nil
    ) {
        self.kind = kind
        // Recognised text is the one label copied onto the page as-is, so it
        // keeps its own case and spacing. Everything else is a tag and is
        // normalised so two passes naming the same thing collapse.
        self.label = kind == .visibleText
            ? label.trimmingCharacters(in: .whitespacesAndNewlines)
            : VisualFact.normalized(label)
        self.confidence = min(max(confidence, 0), 1)
        self.source = source
        self.region = region
    }

    var certainty: VisualCertainty { VisualCertainty(confidence: confidence) }

    /// How prominent this fact is for ranking: a dedicated recognizer beats a
    /// whole-image guess at equal confidence, and something large in frame
    /// beats something incidental.
    var weight: Double {
        let sourceBonus: Double
        switch source {
        case .appleVisionAnimal, .appleVisionFace, .appleVisionHuman, .appleVisionText:
            sourceBonus = 0.25
        case .localVisionModel, .appleVisionSaliencyCrop:
            sourceBonus = 0.15
        case .appleVisionClassifier, .imageStatistics:
            sourceBonus = 0
        }
        let sizeBonus = (region?.area ?? 0) * 0.2
        return confidence + sourceBonus + sizeBonus
    }

    static func normalized(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

/// Everything one perception pass is willing to claim about one photograph,
/// plus what it could not tell. The uncertainty list is not decoration: a
/// caption written from four vague labels should read differently from one
/// written over a clearly recognised animal, and the only way the literary pass
/// can know the difference is if perception says so.
struct VisualFactPacket: Codable, Equatable {
    /// Bumped when the shape changes, so archived packets stay readable.
    static let currentVersion = 1

    var facts: [VisualFact]
    var uncertainty: [String]
    var orientation: PhotoOrientation
    var backends: [String]
    var version: Int

    init(
        facts: [VisualFact] = [],
        uncertainty: [String] = [],
        orientation: PhotoOrientation = .square,
        backends: [String] = [],
        version: Int = VisualFactPacket.currentVersion
    ) {
        self.facts = VisualFactPacket.deduplicated(facts)
        self.uncertainty = uncertainty
        self.orientation = orientation
        self.backends = backends
        self.version = version
    }

    // MARK: - Reading the packet

    func facts(of kind: VisualFactKind) -> [VisualFact] {
        facts.filter { $0.kind == kind }.sorted { $0.weight > $1.weight }
    }

    /// The strongest claim about what the photo is *of*. Dedicated recognizers
    /// are preferred over classifier labels, which is the whole point of the
    /// ensemble: "cat" from the animal pass should win over "furniture" from a
    /// permissive whole-image guess even when the raw scores are close.
    var primarySubject: VisualFact? {
        let candidates = facts.filter {
            $0.kind == .subject || $0.kind == .animal || $0.kind == .person || $0.kind == .object
        }
        return candidates.max { $0.weight < $1.weight }
    }

    var animals: [VisualFact] { facts(of: .animal) }
    var people: [VisualFact] { facts(of: .person) }
    var visibleText: [VisualFact] { facts(of: .visibleText) }

    var peopleCount: Int { people.count }

    /// True when perception has nothing solid — no recognised subject and only
    /// weak labels. The literary pass uses this to write small rather than to
    /// write confidently about nothing.
    var isThin: Bool {
        guard let subject = primarySubject else { return true }
        return subject.certainty == .possible && facts.count < 4
    }

    var strongestCertainty: VisualCertainty {
        facts.map(\.certainty).max() ?? .possible
    }

    // MARK: - Merging

    /// Fold another pass's packet into this one. Later backends do not
    /// overwrite earlier ones; both claims survive and ranking sorts them out,
    /// because a disagreement between the VLM and the animal recognizer is
    /// information, not a conflict to be resolved by whoever ran last.
    func merging(_ other: VisualFactPacket) -> VisualFactPacket {
        VisualFactPacket(
            facts: facts + other.facts,
            uncertainty: Array(Set(uncertainty + other.uncertainty)).sorted(),
            orientation: orientation,
            backends: backends + other.backends.filter { !backends.contains($0) },
            version: max(version, other.version)
        )
    }

    // MARK: - Handing the facts to a writer

    /// One plain line per fact, hedged to its own certainty, with placement but
    /// never coordinates. This is the only thing the literary pass is allowed
    /// to build on, which is what keeps invented detail out of the archive: if
    /// a noun is not in these lines, it did not come from the photograph.
    var groundingLines: [String] {
        facts
            .sorted { $0.weight > $1.weight }
            .prefix(14)
            .map { fact in
                var line = "\(fact.certainty.hedge): \(fact.label)"
                switch fact.kind {
                case .animal, .person, .object, .subject:
                    if let region = fact.region {
                        line += ", \(region.placement)"
                        if region.isProminent { line += ", large in frame" }
                    }
                case .visibleText:
                    line = "\(fact.certainty.hedge) readable text: \"\(fact.label)\""
                case .light:
                    line = "light: \(fact.label)"
                case .colour:
                    line = "colour: \(fact.label)"
                case .setting, .composition:
                    break
                }
                return line
            }
    }

    /// The grounding block as it appears in a prompt, uncertainty included.
    /// Saying what perception failed at is not an apology — it is the
    /// instruction that stops a thin reading from being written up as a
    /// confident one.
    var promptGrounding: String {
        var block = "WHAT THE EYE ACTUALLY SAW (measurements, not moods):\n"
        if groundingLines.isEmpty {
            block += "- nothing legible\n"
        } else {
            block += groundingLines.map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        block += "- shape: \(orientation.rawValue)\n"

        if !uncertainty.isEmpty {
            block += "\nWHAT THE EYE COULD NOT TELL:\n"
            block += uncertainty.map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        return block
    }

    /// Keep the strongest instance of each label-within-kind. Two passes both
    /// spotting the cat should not make the caption mention it twice.
    private static func deduplicated(_ facts: [VisualFact]) -> [VisualFact] {
        var strongest: [String: VisualFact] = [:]
        for fact in facts where !fact.label.isEmpty {
            let key = "\(fact.kind.rawValue)|\(fact.label)"
            if let existing = strongest[key], existing.weight >= fact.weight { continue }
            strongest[key] = fact
        }
        return strongest.values.sorted { $0.weight > $1.weight }
    }
}
