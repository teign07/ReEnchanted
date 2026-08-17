import Foundation

/// What makes one telling of a beat better than another.
///
/// Every rail on Story Pages was negative - no atmosphere, no echo, no
/// invention, no contradiction - and negative rails asymptote at "not bad". A
/// beat cleared the gate by not failing, so a merely adequate paragraph and a
/// genuinely good one were indistinguishable to the machine, and nothing
/// anywhere preferred the good one.
///
/// This is the other half: signals a beat can *earn*. It is a comparator, not a
/// gate. Nothing is refused for scoring low - the rails still decide what may
/// ship - but when two tellings exist, the better one wins, which is the
/// mechanism the nightly braid has always used and Story Pages never had.
///
/// Deliberately mechanical. It cannot tell whether prose is beautiful; it can
/// tell whether the landing actually happened, whether the promise came back,
/// whether an object did something of its own, and whether the writing hedged.
/// Those are checkable, and they are what kept going wrong.
struct StoryBeatTaste: Equatable {
    struct Signal: Equatable {
        var name: String
        var points: Int
    }

    var score: Int
    var signals: [Signal]

    var summary: String {
        signals
            .sorted { abs($0.points) > abs($1.points) }
            .map { "\($0.points > 0 ? "+" : "")\($0.points) \($0.name)" }
            .joined(separator: ", ")
    }

    /// What a beat is being read for.
    struct Brief: Equatable {
        var landing: String
        var character: String
        var otherCharacterNames: [String]
        var sceneMode: StoryRecipeSceneMode?
        /// The ordinary charged detail planted in the opening, which the ending
        /// is supposed to return, changed.
        var promiseSeed: String
        /// True for the beat that closes the vignette, where the promise is owed.
        var owesPromisePayoff: Bool

        init(
            landing: String = "",
            character: String = "",
            otherCharacterNames: [String] = [],
            sceneMode: StoryRecipeSceneMode? = nil,
            promiseSeed: String = "",
            owesPromisePayoff: Bool = false
        ) {
            self.landing = landing
            self.character = character
            self.otherCharacterNames = otherCharacterNames
            self.sceneMode = sceneMode
            self.promiseSeed = promiseSeed
            self.owesPromisePayoff = owesPromisePayoff
        }
    }

    static func read(_ prose: String, brief: Brief) -> StoryBeatTaste {
        var signals: [Signal] = []
        let lowered = prose.lowercased()
        let words = lowered.split { !$0.isLetter }.map(String.init)
        let wordSet = Set(words)

        // The landing is the whole reason the beat exists.
        if StoryTurnValidator.asserts(
            prose, landing: brief.landing, character: brief.character, sceneMode: brief.sceneMode) {
            signals.append(Signal(name: "landing enacted", points: 30))
        }

        // The promise: an ordinary charged detail planted in the opening, which
        // the ending is supposed to return, changed. It was handed to the writer
        // and then checked by nobody, which is exactly how a vignette ends up
        // evocative and hollow.
        if brief.owesPromisePayoff, !brief.promiseSeed.isEmpty {
            let seed = distinctive(in: brief.promiseSeed)
            let returned = seed.filter { word in wordSet.contains { $0.hasPrefix(String(word.prefix(5))) } }
            if !seed.isEmpty, returned.count * 2 >= seed.count {
                signals.append(Signal(name: "promise paid off", points: 25))
            }
        }

        // An ordinary thing doing something of its own, which the Book's voice
        // calls its most important rule and no check has ever looked for.
        if let thing = objectWithAWant(in: prose) {
            signals.append(Signal(name: "object acts (\(thing))", points: 18))
        }

        // People talking, where the recipe wanted talking.
        let spoken = prose.contains("\"") || prose.contains("“")
        switch brief.sceneMode {
        case .conversation:
            signals.append(Signal(name: spoken ? "dialogue carries it" : "no dialogue in a talking scene",
                                  points: spoken ? 15 : -20))
        case .balanced, .none:
            if spoken { signals.append(Signal(name: "dialogue present", points: 8)) }
        case .action, .environmental:
            break
        }

        // Two people actually on the page, rather than one and a room.
        let present = ([brief.character] + brief.otherCharacterNames)
            .compactMap { $0.split(separator: " ").first.map(String.init)?.lowercased() }
            .filter { !$0.isEmpty && lowered.contains($0) }
        if Set(present).count >= 2 {
            signals.append(Signal(name: "both people on the page", points: 12))
        }

        // Hedging. The voice bans these outright, and nothing checked.
        let hedges = ["as if", "as though", "seems to", "seemed to", "almost as if"]
        let hedgeCount = hedges.reduce(0) { $0 + lowered.components(separatedBy: $1).count - 1 }
        if hedgeCount > 0 {
            signals.append(Signal(name: "hedged \(hedgeCount)x", points: -12 * hedgeCount))
        }

        // The words the Book is forbidden to reach for.
        let banned = ["tapestry", "journey", "profound", "quiet magic", "echoes",
                      "symbol", "represents", "essence", "testament"]
        let bannedHits = banned.filter { lowered.contains($0) }
        if !bannedHits.isEmpty {
            signals.append(
                Signal(name: "reached for \(bannedHits.joined(separator: "/"))", points: -15 * bannedHits.count))
        }

        // Assistant voice draining a scene.
        let drained = BookVoice.drainedPhrases.filter { lowered.contains($0) }
        if !drained.isEmpty {
            signals.append(Signal(name: "assistant voice", points: -20 * drained.count))
        }

        // Concreteness: a beat made of specific things beats a beat made of
        // abstractions. Measured as the share of long words that are not the
        // usual mush.
        let abstractions = ["something", "everything", "nothing", "somehow", "feeling",
                            "emotion", "moment", "sense", "presence", "silence"]
        let abstractHits = words.filter { abstractions.contains($0) }.count
        if words.count > 40 {
            let density = Double(abstractHits) / Double(words.count)
            if density > 0.035 {
                signals.append(Signal(name: "abstraction-heavy", points: -14))
            } else if abstractHits == 0 {
                signals.append(Signal(name: "stayed concrete", points: 10))
            }
        }

        // An ending that explains itself is the commonest way a good beat goes
        // slack in its last sentence.
        if let last = sentences(in: prose).last?.lowercased() {
            let explainers = ["which is why", "and that is what", "meant that", "in the end",
                              "she realized", "he realized", "they realized", "understood that"]
            if explainers.contains(where: last.contains) {
                signals.append(Signal(name: "ending explains itself", points: -16))
            }
        }

        return StoryBeatTaste(score: signals.reduce(0) { $0 + $1.points }, signals: signals)
    }

    /// An ordinary thing doing something of its own.
    ///
    /// Shallow on purpose: a household noun followed within a few words by an
    /// active verb. It is looking for "the kettle's sulking", not building a
    /// model of the scene, and a cleverer version would start scoring metaphor.
    static func objectWithAWant(in prose: String) -> String? {
        let things = [
            "kettle", "door", "cup", "mug", "sock", "lamp", "stair", "stairs",
            "charger", "fridge", "rain", "chair", "coat", "key", "keys", "clock",
            "curtain", "kitchen", "gate", "book", "letter", "spoon", "bowl",
            "window", "lock", "shoe", "shoes", "bell", "ribbon", "hinge"
        ]
        let verbs = [
            "sulk", "sulks", "sulking", "wants", "refuses", "refused", "gave",
            "gives", "hid", "hides", "hiding", "waits", "waited", "keeps", "kept",
            "insists", "insisted", "argues", "argued", "won", "wins", "lost",
            "decided", "decides", "forgot", "forgets", "holds", "held", "took",
            "takes", "let", "lets", "changed", "changes", "minds", "minded",
            "complains", "complained", "leaned", "leans", "pretends", "pretended"
        ]
        let words = prose.lowercased().split { !$0.isLetter }.map(String.init)
        for (index, word) in words.enumerated() where things.contains(word) {
            let window = words[index..<min(index + 4, words.count)]
            if window.dropFirst().contains(where: { verbs.contains($0) }) { return word }
        }
        return nil
    }

    private static func distinctive(in text: String) -> [String] {
        let stop: Set<String> = [
            "that", "this", "with", "from", "into", "then", "than", "them", "they",
            "were", "have", "been", "about", "after", "before", "your", "yours",
            "which", "while", "would", "could", "should", "there", "where"
        ]
        return Array(
            Set(
                text.lowercased()
                    .split { !$0.isLetter }
                    .map(String.init)
                    .filter { $0.count >= 4 && !stop.contains($0) }))
            .sorted()
    }

    private static func sentences(in text: String) -> [String] {
        text.split { ".!?".contains($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 3 }
    }
}
