import Foundation

// MARK: - The crossing, handed over
//
// The magic of the braid is the reader's own day and the Book's world meeting in
// one sentence. The plan has always picked a crossing, but Gemma was only ever
// told "the odd thing must cross the reader's day once", and a small model told
// that wrote it in 2 of 50 tellings (2026-10-03, Mac lab). Handed the two actual
// clauses and a plain sentence that joins them, it writes the crossing in 67 of
// 100 (90 with a single fixed bridge, which opened every telling the same way).
//
// So the brief names the two clauses and offers one of four bridges, rotated by
// night: a bridge is not a rule, and Gemma may bend it.
//
// A crossing is adjacency, never equivalence: the bridges say that two things
// happened, not that one explains the other. None is offered on a hard night,
// where the world may be beside what the reader is carrying and never about it.

enum BraidCrossing {
    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "at", "for", "with", "from", "by", "as",
        "is", "are", "was", "were", "it", "its", "that", "this", "then", "so", "if"
    ]
    private static let lowerableFirstWords: Set<String> = [
        "the", "a", "an", "every", "some", "one", "two", "three", "it", "there", "someone", "something",
        "no", "each", "all", "you", "rooms"
    ]
    private static let clauseBreaks = [
        ",", ";", ":", " \u{2014} ", " - ", " and ", " but ", " while ", " because ", " so ", " although ", " since ", " which "
    ]

    /// The first whole clause of the first sentence, short enough to quote.
    /// Nil when nothing usable is left.
    static func clause(_ text: String, maxWords: Int = 14) -> String? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stop = t.range(of: #"[.!?](?:\s|$)"#, options: .regularExpression) { t = String(t[..<stop.lowerBound]) }
        for separator in clauseBreaks {
            if let cut = t.range(of: separator) { t = String(t[..<cut.lowerBound]) }
        }
        var words = t.split(separator: " ").map(String.init)
        words = Array(words.prefix(maxWords))
        while let last = words.last, stopWords.contains(last.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            words.removeLast()
        }
        guard words.count >= 3 else { return nil }
        return words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
    }

    static func lowerFirst(_ clause: String) -> String {
        guard let first = clause.split(separator: " ").first?.lowercased(), lowerableFirstWords.contains(first),
              let initial = clause.first else { return clause }
        return initial.lowercased() + clause.dropFirst()
    }

    private static func upperFirst(_ clause: String) -> String {
        guard let initial = clause.first else { return clause }
        return initial.uppercased() + clause.dropFirst()
    }

    static let bridgeCount = 4

    static func bridge(lived: String, world: String, index: Int) -> String {
        let l = lowerFirst(lived), w = lowerFirst(world)
        switch ((index % bridgeCount) + bridgeCount) % bridgeCount {
        case 0: return "While \(l), \(w)."
        case 1: return "\(upperFirst(lived)), and all the while \(w)."
        case 2: return "The same afternoon \(l), \(w)."
        default: return "\(upperFirst(world)), and \(l) anyway."
        }
    }

    /// The line the brief carries, or nil when there is nothing honest to cross.
    static func handoff(lived: String?, world: String?, seed: String) -> String? {
        guard let lived, let world, let l = clause(lived), let w = clause(world) else { return nil }
        let index = Int(HandbookBuilder.stableHash("crossing|\(seed)") % UInt64(bridgeCount))
        return "Put these two in one sentence, side by side: \u{201C}\(l)\u{201D} and \u{201C}\(w)\u{201D}. "
            + "For example: \(bridge(lived: l, world: w, index: index))"
    }

    static let linePrefix = "Put these two in one sentence"
}
