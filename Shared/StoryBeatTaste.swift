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

        // People talking, where the recipe wanted talking.
        let spoken = prose.contains("\"") || prose.contains("\u{201C}")
        switch brief.sceneMode {
        case .conversation:
            signals.append(
                Signal(
                    name: spoken ? "dialogue carries it" : "no dialogue in a talking scene",
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

        // Everything that means the same thing wherever the Book writes -
        // an object acting, hedging, abstraction pile-up, an ending that
        // explains itself - comes from the shared vocabulary, so the braid and
        // a vignette cannot drift into judging prose by different rules.
        signals += ProseTaste.signals(in: prose).map { Signal(name: $0.name, points: $0.points) }

        return StoryBeatTaste(score: signals.reduce(0) { $0 + $1.points }, signals: signals)
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
