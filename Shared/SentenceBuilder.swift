import Foundation

enum SentenceBuilderStepKind: String, Codable, Equatable, CaseIterable {
    case anchor
    case sense
    case motion
    case crossing
    case cutMist
    case groundGlow
}

struct SentenceBuilderStep: Identifiable, Codable, Equatable {
    var id: String
    var kind: SentenceBuilderStepKind
    var title: String
    var question: String
    var helper: String
    var chips: [String]
}

struct SentenceBuilderPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var ritualTitle: String
    var replayPrompt: String
    var replayHelper: String
    var vagueWords: [String]
    var avoidWords: [String]
    var concreteWords: [String]
    var sensoryWords: [String]
    var animateVerbs: [String]
    var crossingWords: [String]
    var steps: [SentenceBuilderStep]

    static let core = SentenceBuilderPack(
        id: "core.faerie-real",
        displayName: "The Ink Helps",
        ritualTitle: "Wake the sentence",
        replayPrompt: "Close your eyes for one breath. What part of the moment comes back first?",
        replayHelper: "Do not explain it yet. Catch the image, sound, smell, pressure, color, or small object that returns on its own.",
        vagueWords: [
            "nice", "fine", "good", "bad", "okay", "ok", "tired", "busy",
            "sad", "happy", "weird", "interesting", "beautiful", "great"
        ],
        avoidWords: [
            "ethereal", "cosmic", "whimsical", "magical", "enchanted",
            "shimmering", "luminous", "tapestry", "realm"
        ],
        concreteWords: [
            "bag", "bed", "bench", "book", "bowl", "car", "chair", "coat",
            "coffee", "counter", "cup", "door", "floor", "glass", "hand",
            "hands", "jacket", "kettle", "key", "kitchen", "lamp", "light",
            "mug", "phone", "porch", "rain", "receipt", "road", "room",
            "shirt", "shoe", "sink", "sky", "spoon", "street", "table",
            "tea", "tree", "wall", "window", "wind"
        ],
        sensoryWords: [
            "blue", "bright", "bitter", "cold", "dim", "dusty", "green",
            "gold", "grainy", "heavy", "hot", "loud", "metallic", "rough",
            "salt", "sharp", "soft", "sour", "sticky", "sweet", "tinny",
            "warm", "wet", "white", "yellow"
        ],
        animateVerbs: [
            "breathed", "clicked", "counted", "crouched", "held", "hummed",
            "leaned", "listened", "refused", "remembered", "waited",
            "wanted", "watched", "worried"
        ],
        crossingWords: [
            "blue sound", "cold green", "paper quiet", "tin taste",
            "wool tired", "yellow hush"
        ],
        steps: [
            SentenceBuilderStep(
                id: "anchor",
                kind: .anchor,
                title: "Find the object",
                question: "What real thing remembers this best?",
                helper: "Name one object, place, body detail, or bit of weather. One noun is enough.",
                chips: ["glass", "door", "chair", "rain", "hands", "window", "floor", "coat"]
            ),
            SentenceBuilderStep(
                id: "sense",
                kind: .sense,
                title: "Give it a sense",
                question: "What did your body notice?",
                helper: "Add a smell, sound, texture, temperature, taste, or quality of light.",
                chips: ["cold", "warm", "tinny", "wet", "dusty", "sharp", "dim", "green"]
            ),
            SentenceBuilderStep(
                id: "motion",
                kind: .motion,
                title: "Let it move",
                question: "What verb makes the real thing feel alive?",
                helper: "Let one nonhuman thing act without turning it fake.",
                chips: ["waited", "leaned", "clicked", "held", "refused", "counted", "listened", "worried"]
            ),
            SentenceBuilderStep(
                id: "crossing",
                kind: .crossing,
                title: "Cross the wires",
                question: "If one sense borrowed from another, what would it become?",
                helper: "A sound can have a color. A mood can have a texture. Keep it small.",
                chips: ["blue sound", "paper quiet", "tin taste", "wool tired", "yellow light", "cold green"]
            )
        ]
    )

    static let souvenir = SentenceBuilderPack(
        id: "pack.souvenir",
        displayName: "Souvenir Sentence",
        ritualTitle: "Steal the diamond",
        replayPrompt: "What was the single best feeling, moment, or thing from the last hour?",
        replayHelper: "Replay the moment before you write. The first real detail that returns is the door back in.",
        vagueWords: [],
        avoidWords: [],
        concreteWords: ["ticket", "receipt", "pocket", "curb", "cloud", "handle", "mirror", "napkin"],
        sensoryWords: ["creased", "damp", "faded", "silver", "smoky", "stale"],
        animateVerbs: ["followed", "kept", "pulled", "stayed", "tugged"],
        crossingWords: ["gray taste", "coin-bright quiet", "cotton silence"],
        steps: [
            SentenceBuilderStep(
                id: "souvenir-anchor",
                kind: .anchor,
                title: "Choose the witness",
                question: "What small thing came back with the moment?",
                helper: "Pick the object, mark, smell, or scrap that could prove the memory happened.",
                chips: ["receipt", "key", "cloud", "handle", "mirror", "napkin", "curb", "pocket"]
            ),
            SentenceBuilderStep(
                id: "souvenir-sense",
                kind: .sense,
                title: "Press the sense",
                question: "What did it feel like before your mind named it?",
                helper: "Let the body answer before the explanation arrives.",
                chips: ["creased", "damp", "faded", "silver", "stale", "smoky"]
            ),
            SentenceBuilderStep(
                id: "souvenir-motion",
                kind: .motion,
                title: "Let it keep",
                question: "What did the thing seem to do with the memory?",
                helper: "A souvenir does not need to speak. It can tug, stay, follow, or hold.",
                chips: ["kept", "stayed", "followed", "pulled", "tugged"]
            )
        ]
    )

    func merged(with overlay: SentenceBuilderPack) -> SentenceBuilderPack {
        SentenceBuilderPack(
            id: "\(id)+\(overlay.id)",
            displayName: overlay.displayName.isEmpty ? displayName : overlay.displayName,
            ritualTitle: overlay.ritualTitle.isEmpty ? ritualTitle : overlay.ritualTitle,
            replayPrompt: overlay.replayPrompt.isEmpty ? replayPrompt : overlay.replayPrompt,
            replayHelper: overlay.replayHelper.isEmpty ? replayHelper : overlay.replayHelper,
            vagueWords: unique(vagueWords + overlay.vagueWords),
            avoidWords: unique(avoidWords + overlay.avoidWords),
            concreteWords: unique(concreteWords + overlay.concreteWords),
            sensoryWords: unique(sensoryWords + overlay.sensoryWords),
            animateVerbs: unique(animateVerbs + overlay.animateVerbs),
            crossingWords: unique(crossingWords + overlay.crossingWords),
            steps: mergedSteps(with: overlay.steps)
        )
    }

    private func mergedSteps(with overlaySteps: [SentenceBuilderStep]) -> [SentenceBuilderStep] {
        var merged = steps
        for step in overlaySteps {
            if let index = merged.firstIndex(where: { $0.kind == step.kind }) {
                merged[index] = step
            } else {
                merged.append(step)
            }
        }
        return merged
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            let key = value.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

struct SentenceBuilderNudge: Equatable {
    var step: SentenceBuilderStep
    var highlightedWord: String?
    var canStandAsComplete: Bool
}

struct SentenceBuilderCraftMark: Identifiable, Equatable {
    var id: SentenceBuilderStepKind
    var title: String
    var isPresent: Bool
    var hint: String
}

struct SentenceBuilderDiagnostic: Identifiable, Equatable {
    enum Severity: Equatable {
        case prompt
        case warning
    }

    var id: String
    var severity: Severity
    var title: String
    var message: String
    var word: String?
}

struct SentenceBuilderAnalysis: Equatable {
    var wordCount: Int
    var hasConcreteAnchor: Bool
    var hasSensoryDetail: Bool
    var hasLivingMotion: Bool
    var hasCrossedSense: Bool
    var memoryStrength: Int
    var craftMarks: [SentenceBuilderCraftMark]
    var diagnostics: [SentenceBuilderDiagnostic]

    var canStandAsComplete: Bool {
        wordCount >= 4 && (hasConcreteAnchor || hasSensoryDetail || hasLivingMotion)
    }

    var isVivid: Bool {
        memoryStrength >= 3
    }
}

struct SentenceBuilderAlchemyLevel: Identifiable, Equatable {
    var id: String
    var title: String
    var example: String
    var isCurrent: Bool
}

struct SentenceBuilderEngine {
    var pack: SentenceBuilderPack

    init(pack: SentenceBuilderPack = .core) {
        self.pack = pack
    }

    func nudge(for text: String, completedKinds: Set<SentenceBuilderStepKind> = []) -> SentenceBuilderNudge {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = analyze(trimmed)
        if let avoidWord = hasAvoidWord(trimmed),
           !completedKinds.contains(.groundGlow) {
            return SentenceBuilderNudge(
                step: glowStep(for: avoidWord),
                highlightedWord: avoidWord,
                canStandAsComplete: analysis.canStandAsComplete
            )
        }

        if let vagueWord = firstMatchedWord(in: trimmed, words: pack.vagueWords),
           !completedKinds.contains(.cutMist) {
            return SentenceBuilderNudge(
                step: mistStep(for: vagueWord),
                highlightedWord: vagueWord,
                canStandAsComplete: analysis.canStandAsComplete
            )
        }

        let orderedKinds: [SentenceBuilderStepKind] = [.anchor, .sense, .motion, .crossing]
        let nextKind = orderedKinds.first { kind in
            guard !completedKinds.contains(kind) else { return false }
            switch kind {
            case .anchor:
                return !analysis.hasConcreteAnchor
            case .sense:
                return !analysis.hasSensoryDetail
            case .motion:
                return !analysis.hasLivingMotion
            case .crossing:
                return analysis.memoryStrength >= 2 && !analysis.hasCrossedSense
            case .cutMist, .groundGlow:
                return false
            }
        } ?? orderedKinds.first { !completedKinds.contains($0) } ?? .anchor
        let step = pack.steps.first { $0.kind == nextKind } ?? pack.steps[0]
        return SentenceBuilderNudge(
            step: step,
            highlightedWord: nil,
            canStandAsComplete: analysis.canStandAsComplete
        )
    }

    func analyze(_ text: String) -> SentenceBuilderAnalysis {
        let normalizedWords = words(in: text)
        let wordCount = normalizedWords.count
        let wordSet = Set(normalizedWords)
        let lower = text.lowercased()

        let hasConcreteAnchor = containsAnyWord(from: pack.concreteWords, in: wordSet)
        let hasSensoryDetail = containsAnyWord(from: pack.sensoryWords, in: wordSet)
        let hasLivingMotion = containsAnyWord(from: pack.animateVerbs, in: wordSet)
        let hasCrossedSense = pack.crossingWords.contains { lower.contains($0.lowercased()) }
            || (hasSensoryDetail && lower.contains(" sound"))
            || (hasSensoryDetail && lower.contains(" taste"))
            || (hasSensoryDetail && lower.contains(" quiet"))

        let marks = [
            SentenceBuilderCraftMark(
                id: .anchor,
                title: "Thing",
                isPresent: hasConcreteAnchor,
                hint: "Name the object, place, body part, or weather."
            ),
            SentenceBuilderCraftMark(
                id: .sense,
                title: "Body",
                isPresent: hasSensoryDetail,
                hint: "Add temperature, texture, color, taste, sound, or smell."
            ),
            SentenceBuilderCraftMark(
                id: .motion,
                title: "Will",
                isPresent: hasLivingMotion,
                hint: "Let a nonhuman thing act with a plain verb."
            ),
            SentenceBuilderCraftMark(
                id: .crossing,
                title: "Cross",
                isPresent: hasCrossedSense,
                hint: "Let one sense borrow from another."
            )
        ]
        let memoryStrength = marks.filter(\.isPresent).count

        var diagnostics: [SentenceBuilderDiagnostic] = []
        if let avoidWord = hasAvoidWord(text) {
            diagnostics.append(SentenceBuilderDiagnostic(
                id: "avoid-\(avoidWord)",
                severity: .warning,
                title: "Too much stage smoke",
                message: "Try giving '\(avoidWord)' a physical job in the room.",
                word: avoidWord
            ))
        }
        if let vagueWord = firstMatchedWord(in: text, words: pack.vagueWords) {
            diagnostics.append(SentenceBuilderDiagnostic(
                id: "vague-\(vagueWord)",
                severity: .prompt,
                title: "Mist word",
                message: "'\(vagueWord)' may be true. What did it feel like in matter?",
                word: vagueWord
            ))
        }
        if wordCount >= 5 && !hasConcreteAnchor {
            diagnostics.append(SentenceBuilderDiagnostic(
                id: "missing-anchor",
                severity: .prompt,
                title: "Give it a witness",
                message: "One real noun will help the memory know where to land.",
                word: nil
            ))
        }

        return SentenceBuilderAnalysis(
            wordCount: wordCount,
            hasConcreteAnchor: hasConcreteAnchor,
            hasSensoryDetail: hasSensoryDetail,
            hasLivingMotion: hasLivingMotion,
            hasCrossedSense: hasCrossedSense,
            memoryStrength: memoryStrength,
            craftMarks: marks,
            diagnostics: diagnostics
        )
    }

    func chips(for step: SentenceBuilderStep, text: String) -> [String] {
        let lower = text.lowercased()
        let unused = step.chips.filter { !lower.contains($0.lowercased()) }
        return unused.isEmpty ? step.chips : unused
    }

    func alchemyLevels(for text: String) -> [SentenceBuilderAlchemyLevel] {
        let analysis = analyze(text)
        return [
            SentenceBuilderAlchemyLevel(
                id: "label",
                title: "Label",
                example: "Dinner was good.",
                isCurrent: !analysis.hasConcreteAnchor && !analysis.hasSensoryDetail && !analysis.hasLivingMotion
            ),
            SentenceBuilderAlchemyLevel(
                id: "hook",
                title: "Hook",
                example: "The garlic hit the oil and made the kitchen warm.",
                isCurrent: analysis.canStandAsComplete && !analysis.isVivid
            ),
            SentenceBuilderAlchemyLevel(
                id: "spell",
                title: "Tiny spell",
                example: "The garlic woke up in the pan and the kitchen turned gold.",
                isCurrent: analysis.isVivid
            )
        ]
    }

    func souvenirShareText(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "\(trimmed)\n\n— One-Sentence Souvenir"
    }

    func phrase(for chip: String, step: SentenceBuilderStep) -> String {
        switch step.kind {
        case .anchor:
            return chip
        case .sense:
            return chip
        case .motion:
            return chip
        case .crossing:
            return chip
        case .cutMist:
            return chip
        case .groundGlow:
            return chip
        }
    }

    func append(_ phrase: String, to text: String) -> String {
        let cleanPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPhrase.isEmpty else { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cleanPhrase }

        if trimmed.hasSuffix(" ") || trimmed.hasSuffix("\n") {
            return text + cleanPhrase
        }
        if trimmed.hasSuffix(",") || trimmed.hasSuffix(";") || trimmed.hasSuffix(":") {
            return text + " " + cleanPhrase
        }
        return text + " " + cleanPhrase
    }

    func hasAvoidWord(_ text: String) -> String? {
        firstMatchedWord(in: text, words: pack.avoidWords)
    }

    private func mistStep(for word: String) -> SentenceBuilderStep {
        SentenceBuilderStep(
            id: "cut-mist-\(word)",
            kind: .cutMist,
            title: "Cut the mist",
            question: "Can '\(word)' become a texture, temperature, object, or gesture?",
            helper: "Keep the feeling, but give it a body.",
            chips: alternatives(for: word)
        )
    }

    private func glowStep(for word: String) -> SentenceBuilderStep {
        SentenceBuilderStep(
            id: "ground-glow-\(word)",
            kind: .groundGlow,
            title: "Ground the glow",
            question: "What ordinary thing could carry '\(word)' without saying it?",
            helper: "Let the magic arrive through matter: light on a wall, a cup, a hinge, a smell, a pressure in the hand.",
            chips: ["lamp", "hinge", "smell", "shadow", "pulse", "dust", "weight", "ring"]
        )
    }

    private func alternatives(for word: String) -> [String] {
        switch word.lowercased() {
        case "tired", "busy":
            return ["heavy", "grainy", "stale", "frayed", "slow"]
        case "sad":
            return ["hollow", "cold", "thin", "bruised", "quiet"]
        case "happy", "good", "great":
            return ["warm", "bright", "loose", "gold", "open"]
        case "bad", "weird":
            return ["sour", "crooked", "static", "sharp", "wrong"]
        default:
            return ["warm", "cold", "rough", "dim", "sharp"]
        }
    }

    private func firstMatchedWord(in text: String, words: [String]) -> String? {
        let lower = text.lowercased()
        for word in words {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word.lowercased()))\\b"
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return word
            }
        }
        return nil
    }

    private func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func containsAnyWord(from words: [String], in wordSet: Set<String>) -> Bool {
        words.contains { wordSet.contains($0.lowercased()) }
    }
}
