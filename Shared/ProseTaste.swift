import Foundation

/// The signals that mean the same thing wherever the Book is writing.
///
/// Two taste engines grew up separately and learned different halves of the
/// same job. `StoryBeatTaste` could see an object doing something of its own,
/// a hedge, an abstraction pile-up, and an ending that explains itself.
/// `BraidTastingRoom` could see concrete magic, a prior echo returning changed,
/// amplitude and repetition - and none of the first four. Each was blind
/// exactly where the other could see.
///
/// These are the ones that transfer. A hedge is a hedge in a vignette and in a
/// nightly page; whether a *prior echo* returned changed is meaningless to a
/// vignette, and whether a *promise* paid off is meaningless to a night. So the
/// shared vocabulary lives here and each engine keeps its own dimensions on top.
///
/// Every signal is mechanical. None of it can tell whether prose is beautiful.
/// All of it can tell whether the writing reached for a lesson instead of a
/// thing, which is the failure that actually keeps happening.
enum ProseTaste {
    struct Signal: Equatable {
        var name: String
        var points: Int
    }

    /// Read the signals that apply to any Book prose.
    static func signals(in prose: String) -> [Signal] {
        var found: [Signal] = []
        let lowered = prose.lowercased()
        let words = lowered.split { !$0.isLetter }.map(String.init)

        // The animism mandate is the loudest line in the Book's own voice -
        // "MOST IMPORTANT: at least one ordinary thing must act on its own" -
        // and until now nothing anywhere checked whether it happened.
        if let thing = objectThatActs(in: prose) {
            found.append(Signal(name: "object acts (\(thing))", points: 18))
        }

        let hedgeCount = hedges.reduce(0) { total, hedge in
            total + lowered.components(separatedBy: hedge).count - 1
        }
        if hedgeCount > 0 {
            found.append(Signal(name: "hedged \(hedgeCount)x", points: -12 * hedgeCount))
        }

        let reached = bannedReaches.filter { lowered.contains($0) }
        if !reached.isEmpty {
            found.append(
                Signal(
                    name: "reached for \(reached.joined(separator: "/"))",
                    points: -15 * reached.count))
        }

        let drained = BookVoice.drainedPhrases.filter { lowered.contains($0) }
        if !drained.isEmpty {
            found.append(Signal(name: "assistant voice", points: -20 * drained.count))
        }

        // A page made of specific things beats a page made of abstractions.
        if words.count > 40 {
            let abstractHits = words.filter { abstractions.contains($0) }.count
            let density = Double(abstractHits) / Double(words.count)
            if density > 0.035 {
                found.append(Signal(name: "abstraction-heavy", points: -14))
            } else if abstractHits == 0 {
                found.append(Signal(name: "stayed concrete", points: 10))
            }
        }

        // The commonest way a good page goes slack in its last sentence.
        if let last = sentences(in: prose).last?.lowercased(),
           selfExplainers.contains(where: last.contains) {
            found.append(Signal(name: "ending explains itself", points: -16))
        }
        return found
    }

    /// An ordinary thing doing something of its own.
    ///
    /// Shallow on purpose: a household noun followed within a few words by an
    /// active verb. It is looking for "the kettle's sulking", not building a
    /// model of the scene, and anything cleverer would start scoring metaphor.
    static func objectThatActs(in prose: String) -> String? {
        // A hedged personification is not an object acting, it is a simile -
        // and it is the Book's own canonical wrong example: "The lamp leaned in
        // like an old friend" WRONG, "The lamp leaned in" RIGHT. Scored without
        // this, "the lamp leaned in as if it were listening" earned the animism
        // bonus and paid only the hedge penalty, coming out ahead. The doctrine
        // says the hedge cancels the thing.
        for sentence in sentences(in: prose) {
            let lowered = sentence.lowercased()
            guard !hedges.contains(where: lowered.contains) else { continue }
            let words = lowered.split { !$0.isLetter }.map(String.init)
            for (index, word) in words.enumerated() where things.contains(word) {
                let window = words[index..<min(index + 4, words.count)]
                if window.dropFirst().contains(where: { actions.contains($0) }) { return word }
            }
        }
        return nil
    }

    static let things: Set<String> = [
        "kettle", "door", "cup", "mug", "sock", "socks", "lamp", "stair", "stairs",
        "charger", "fridge", "rain", "chair", "coat", "key", "keys", "clock",
        "curtain", "kitchen", "gate", "book", "letter", "spoon", "bowl",
        "window", "lock", "shoe", "shoes", "bell", "ribbon", "hinge", "kerb",
        "bus", "bike", "towel", "plate", "bread", "milk", "post", "phone"
    ]

    static let actions: Set<String> = [
        "sulk", "sulks", "sulking", "wants", "wanted", "refuses", "refused",
        "gave", "gives", "hid", "hides", "hiding", "waits", "waited", "keeps",
        "kept", "insists", "insisted", "argues", "argued", "won", "wins", "lost",
        "decided", "decides", "forgot", "forgets", "holds", "held", "took",
        "takes", "let", "lets", "changed", "changes", "minds", "minded",
        "complains", "complained", "leaned", "leans", "pretends", "pretended",
        "sulked", "objected", "objects", "gave", "quit", "quits", "stopped"
    ]

    static let hedges = ["as if", "as though", "seems to", "seemed to", "almost as if"]

    static let bannedReaches = [
        "tapestry", "journey", "profound", "quiet magic", "echoes of",
        "symbolize", "symbolise", "represents", "essence", "testament"
    ]

    static let abstractions: Set<String> = [
        "something", "everything", "nothing", "somehow", "feeling", "feelings",
        "emotion", "emotions", "moment", "moments", "sense", "presence",
        "silence", "stillness", "existence", "reality"
    ]

    static let selfExplainers = [
        "which is why", "and that is what", "meant that", "in the end",
        "she realized", "he realized", "they realized", "understood that",
        "the point was", "what it meant"
    ]

    static func sentences(in text: String) -> [String] {
        text.split { ".!?".contains($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 3 }
    }
}
